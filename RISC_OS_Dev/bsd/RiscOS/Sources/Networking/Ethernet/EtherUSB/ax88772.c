//
// Copyright (c) 2006-2011, James Peacock
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met: 
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of RISC OS Open Ltd nor the names of its contributors
//       may be used to endorse or promote products derived from this software
//       without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//

/*
 * Backend for ASIX AX88772 (10/100Mb) devices.
 *
 * Single ethernet packets are passed over Bulk IN and OUT endpoints at
 * a time. Each packet is prefixed with the following 4 byte header:
 *
 *  h[0] - <packet-size-lsb>
 *  h[1] - <packet-size-msb>
 *  h[2] - <packet-size-lsb> EOR &ff
 *  h[3] - <packet-size-msb> EOR &ff
 *
 * It appears that this device can handle multiple packets being sent to it
 * in one transfer, though this hasn't been well tested yet.
 *
 * Todo: multicast filtering.
 */

#include "backends.h"
#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "net.h"
#include "products.h"
#include "mii.h"

#include <stddef.h>
#include <assert.h>
#include <string.h>

#if TX_PREFIX_SIZE<4
#error "Unable to build AX88772 backend - edit module.h"
#endif

// RX control register flags
#define RX_CONTROL_READ  0x0f    // RX Control must only be modified (not set)
#define RX_CONTROL_WRITE 0x10    //     to cope with different 772 variants
#define RX_PROMISC       (1u<<0) // Pass all packets seen on wire to host.
#define RX_ALLMULTICAST  (1u<<1) // Pass all multicast packets to host.
#define RX_SAVE_ERR_PKTS (1u<<2) // Pass packets with CRC errors to host.
#define RX_BROADCAST     (1u<<3) // Pass broadcast packets to host.
#define RX_MULTICAST     (1u<<4) // Pass matching multicast packets to host.
#define RX_MULTIUNICAST  (1u<<5) // Pass unicast packets matching MC filter.
#define RX_ENABLE        (1u<<7) // Enable MAC.
// 772 and 772A
#define RX_USB_2048      (0u<<8) //}
#define RX_USB_4096      (1u<<8) // } Maximum frame burst on
#define RX_USB_8192      (2u<<8) // } USB BUS
#define RX_USB_16384     (3u<<8) //}
// 772B
#define RX_772B_HEADER_FORMAT1 (1u<<8)

// Medium status flags (16 bits)
#define MEDIUM_BASE            (1u<<2 ) // Must always be set.
#define MEDIUM_FULL_DUPLEX     (1u<<1 ) // Duplex: 1=>Full, 0=>Half
#define MEDIUM_RX_FLOW_CONTROL (1u<<4 ) // Enable flow control
#define MEDIUM_TX_FLOW_CONTROL (1u<<5 ) // Enable flow control
#define MEDIUM_PAUSE_LA        (1u<<7 ) // Only L/T for pause (default 0).
#define MEDIUM_RX_ENABLE       (1u<<8 ) // 1=>Enabled, 0=>Disabled
#define MEDIUM_MII_100         (1u<<9 ) // MII Speed: 1=>100Mb, 0=> 10Mb
#define MEDIUM_SBP             (1u<<11) // Half duplex stop back pressure
#define MEDIUM_SUPER_MAC       (1u<<12) // Shorten Tx retry exp. backoff.

// Software reset register
#define SW_RESET_CLR_FRAME_ERR  (1u<<0) // Clear BULK in frame error
#define SW_RESET_CLR_LEN_ERR    (1u<<1) // Clear BULK out frame length error
#define SW_RESET_EXT_PHY_MODE   (1u<<2) // Reset pin configuration
#define SW_RESET_EXT_PHY_LEVEL  (1u<<3) // Reset pin level
#define SW_RESET_FORCE_BULK_IN  (1u<<4) // Bulk IN can return empty packets
#define SW_RESET_INT_PHY_ENABLE (1u<<5) // 0 to reset internal PHY
#define SW_RESET_INT_PHY_PDOWN  (1u<<6) // Power down mode

// Software PHY select register
#define SW_PHY_EXTERNAL        (0u<<0) // Always use MII PHY
#define SW_PHY_EMBEDDED        (1u<<1) // Always use embedded PHY
#define SW_PHY_AUTO            (2u<<1) // Use link status

// NULL PHY ID.
#define NULL_PHY         0xe0

// Receive buffer registered with DeviceFS
// Must be set to this for burst mode
#define RX_BUF_SIZE      16384

// Device state
typedef struct
{
  usb_pipe_t      pipe_rx;
  usb_pipe_t      pipe_tx;
  mii_t           mii;
  uint8_t         phy_id;
  net_device_t*   dev;
  uint16_t        rx_buf[RX_BUF_SIZE];
} ws_t;

//---------------------------------------------------------------------------
// Reads a MII register from the device's PHY.
//---------------------------------------------------------------------------
static _kernel_oserror* phy_read(void* handle,
                                 unsigned reg_no,
                                 uint16_t *value)
{
  ws_t* ws = handle;
  uint8_t blk[2];

  // Switch to software MII operation
  _kernel_oserror* e = usb_control(ws->dev->name, 0x40, 0x06, 0, 0, 0, NULL);

  // Talk to PHY
  if (!e) e = usb_control(ws->dev->name, 0xc0, 0x07,
                          ws->phy_id,
                          reg_no,
                          0x0002,
                          blk);

  // Switch back to hardware MMI.
  if (!e) e = usb_control(ws->dev->name, 0x40, 0x0a, 0, 0, 0, NULL);

  if (e)
  {
    syslog("%s: PHY read failed: %s", ws->dev->name, e->errmess);
    return e;
  }

  *value = blk[0] + (blk[1]<<8);
  return NULL;
}

//---------------------------------------------------------------------------
// Writes a MII register value to the device's PHY.
//---------------------------------------------------------------------------
static _kernel_oserror* phy_write(void* handle,
                                  unsigned reg_no,
                                  uint16_t val)
{
  ws_t* ws = handle;

  uint8_t blk[2];
  blk[1] = val >> 8;
  blk[0] = val & 0xff;

  // Switch to software MII operation
  _kernel_oserror* e = usb_control(ws->dev->name, 0x40, 0x06, 0, 0, 0, NULL);

  // Talk to PHY
 if (!e) e = usb_control(ws->dev->name, 0x40, 0x08,
                         ws->phy_id,
                         reg_no,
                         0x0002,
                         &blk);

  // Switch back to hardware MMI.
  if (!e) e = usb_control(ws->dev->name, 0x40, 0x0a, 0, 0, 0, NULL);

  if (e) syslog("%s: PHY write failed: %s", ws->dev->name, e->errmess);

  return e;
}

//---------------------------------------------------------------------------
// Packet Tx and Rx to device.
//---------------------------------------------------------------------------

static void read_packet(usb_pipe_t pipe, void* dev_pw)
{
  ws_t* ws = dev_pw;

  uint16_t* buf = ws->rx_buf;
  
  for (;;)
  {
    size_t size = sizeof(ws->rx_buf);
  
    _kernel_oserror* e = usb_read(ws->pipe_rx, buf, &size);

    if (e || size == 0) break;

    usb_start_read(ws->pipe_rx);
    
    if (size>4)
    {
      int off = 0;
      size = (size+1)/2;
      size_t packet_size;
      for (off = 0; off < size-2 && (buf[off] ^ buf[off+1]) == 0xFFFF; off += (packet_size+5)/2)
      {
        packet_size = buf[off] & 0x7ff;
        if ((packet_size > 0) && (packet_size <= ETHER_MAX_LEN))
          net_receive(ws->dev, &buf[off+2], packet_size, 0);
      }
    }
  }
  usb_start_read(ws->pipe_rx);
}

static void write_packet(usb_pipe_t pipe, void* dev_pw)
{
  ws_t* ws = dev_pw;
  net_attempt_transmit(ws->dev);
}

//---------------------------------------------------------------------------
// Medium configuration. Needed after PHY configuration changed, either
// explicitly or by auto-negotiation.
//---------------------------------------------------------------------------
static _kernel_oserror* update_medium(net_device_t* dev)
{
  const net_status_t* status = &dev->status;

  uint16_t medium = MEDIUM_BASE | MEDIUM_RX_ENABLE;

  if (status->duplex!=net_duplex_half) medium |= MEDIUM_FULL_DUPLEX;
  if (status->speed ==net_speed_100Mb) medium |= MEDIUM_MII_100;

  if (status->tx_pause) medium |= MEDIUM_TX_FLOW_CONTROL;
  if (status->rx_pause) medium |= MEDIUM_RX_FLOW_CONTROL;

  if (status->duplex!=net_duplex_half) 
        medium |= (MEDIUM_RX_FLOW_CONTROL | MEDIUM_TX_FLOW_CONTROL);

  return usb_control(dev->name, 0x40, 0x1b, medium, 0x0000, 0, 0);
}

//---------------------------------------------------------------------------
// Backend entry points
//---------------------------------------------------------------------------
static _kernel_oserror* device_configure(net_device_t*       dev,
                                         const net_config_t* cfg)
{
  ws_t* ws = dev->private;
  _kernel_oserror* e = mii_configure(&ws->mii, &dev->status, cfg);

  // Reconfigure control register and propagate settings to
  // net_status flags on success.
  if (!e)
  {
    uint16_t control;

    // Just modify - dont set - the RX Control register defaults to cope with different 772 variants
    e = usb_control(dev->name, 0xC0, RX_CONTROL_READ, 0x0000, 0x0000, 2, &control);
    control &= ~(RX_ALLMULTICAST | RX_PROMISC);
    control |= (RX_BROADCAST | RX_ENABLE);            // should be enabled already but just to make sure
    if (cfg->multicast) control |= RX_ALLMULTICAST;
    if (cfg->promiscuous) control |= RX_PROMISC;
    if (!e) e = usb_control(dev->name, 0x40, RX_CONTROL_WRITE, control, 0x0000, 0x0000, 0);

    if (!e)
    {
      dev->status.broadcast   = true;
      dev->status.multicast   = cfg->multicast;
      dev->status.promiscuous = cfg->promiscuous;
    }
  }

  // Configure PHY then update medium flags to match resulting
  // setup.
  if (!e) e = update_medium(dev);
  return e;
}

static _kernel_oserror* device_status(net_device_t* dev)
{
  ws_t* ws = dev->private;
  _kernel_oserror *e = mii_link_status(&ws->mii, &dev->status);

  if (!e && dev->status.autoneg == net_autoneg_reconfigure)
  {
    e = update_medium(dev);
    if (!e) dev->status.autoneg = net_autoneg_complete;
  }
  return e;
}

static _kernel_oserror* device_transmit(net_device_t*   dev,
                                        const net_tx_t* pkt)
{
  // Note this device can cope with multiple packets merged
  // into one USB transfer so we don't stop this happening.
  ws_t* ws = dev->private;
  size_t to_write = (((pkt->size+4) + 1) & ~1);
  uint32_t* ptr = (void*)&pkt->header;
  *--ptr = pkt->size | ((pkt->size<<16) ^ 0xffff0000);
  usb_write(ws->pipe_tx, ptr, &to_write);
  return (to_write==0) ? err_translate(ERR_TX_BLOCKED) : NULL;
}

static _kernel_oserror* device_open(const USBServiceCall* dev,
                                    const char*          options,
                                    void**               private)
{
  if (!options) return err_translate(ERR_UNSUPPORTED);

  ws_t* ws = xalloc(sizeof(ws_t));
  if (!ws) return err_translate(ERR_NO_MEMORY);

  ws->pipe_rx    = 0;
  ws->pipe_tx    = 0;
  ws->phy_id     = NULL_PHY;
  ws->dev        = NULL;

  mii_initialise(&ws->mii, phy_read, phy_write, ws);

  *private = ws;
  return NULL;
}

static bool check_mac(const uint8_t* mac)
{
  int i;
  bool match;

  match = true;
  for (i = 0; i < ETHER_ADDR_LEN; i++)
  {
    if (mac[i] != 0x00)
    {
      match = false;
      break;
    }
  }

  // 00 00 00 00 00 00 => unset mac
  if (match) return false;

  // 00 00 00 00 xx xx => fake mac
  if (i >= 4) return false;

  match = true;
  for (i = 0; i < ETHER_ADDR_LEN; i++)
  {
    if (mac[i] != 0xFF)
    {
      match = false;
      break;
    }
  }

  // FF FF FF FF FF FF => blank mac
  if (match) return false;

  return true;
}

static _kernel_oserror* device_start(net_device_t* dev, const char* options)
{
  if (!options) return err_translate(ERR_UNSUPPORTED);

  ws_t* ws = dev->private;
  ws->dev  = dev;

  _kernel_oserror* e = usb_set_config(dev->name, 1);

  // Read PHY IDs for MII
  uint8_t phy_id[2];
  if (!e) e = usb_control(dev->name, 0xc0, 0x19, 0x0000, 0x0000,
                          0x0002, phy_id);

  ws->phy_id = (phy_id[1]==NULL_PHY) ? phy_id[0] : phy_id[1];
  if (ws->phy_id==NULL_PHY)
  {
    syslog("%s: Device reports no PHY!",dev->name);
    return err_translate(ERR_BAD_DEVICE);
  }

  // Software reset
  if (!e) e = usb_control(dev->name, 0x40, 0x20,
                          SW_RESET_CLR_FRAME_ERR |
                          SW_RESET_CLR_LEN_ERR   |
                          SW_RESET_EXT_PHY_LEVEL |
                          SW_RESET_INT_PHY_ENABLE,
                          0x000, 0, 0);

  // Clear reset flags
  if (!e) e = usb_control(dev->name, 0x40, 0x20,
                          SW_RESET_EXT_PHY_LEVEL |
                          SW_RESET_INT_PHY_ENABLE,
                          0x000, 0, 0);

  // Write IPG registers to defaults.
  if (!e) e = usb_control(dev->name, 0x40, 0x12, 0x0c15, 0x0012, 0x000, 0);

  // Select PHY to use based on link status
  if (!e) e = usb_control(dev->name, 0x40, 0x22, 0x0002, 0, 0, 0);

  // Read MAC address
  if (!e) e = usb_control(dev->name, 0xc0, 0x13, 0x0000, 0x0000,
                          ETHER_ADDR_LEN, dev->status.mac);

  if (!e && !check_mac(dev->status.mac))
  {
    // Something wrong with the mac address
    net_machine_mac(dev->status.mac);
    if (!check_mac(dev->status.mac))
    {
      net_default_mac(dev->dib.dib_unit, dev->status.mac);
    }
    e = usb_control(dev->name, 0x40, 0x14, 0x0000, 0x0000, ETHER_ADDR_LEN, dev->status.mac);
  }

  // Set Rx flags - need to set RX_ENABLE at this point to get it
  // to work.
  uint16_t control;
  if (!e) e = usb_control(dev->name, 0xC0, RX_CONTROL_READ, 0x0000, 0x0000, 2, &control);
  control |= RX_ENABLE;
  if (!e) e = usb_control(dev->name, 0x40, RX_CONTROL_WRITE, control, 0x0000, 0x0000, 0);

  // Open endpoints.
  if (!e) e = usb_open(dev->name,
                       &ws->pipe_rx,
                       USBRead,
                       &read_packet,
                       ws,
                       "Devices#bulk;size" STR(RX_BUF_SIZE) ":$.%s",
                       dev->name);

  if (!e) e = usb_open(dev->name,
                       &ws->pipe_tx,
                       USBWrite,
                       &write_packet,
                       ws,
                       "Devices#bulk;size32768:$.%s",       
                       dev->name);

  // Reset PHY and update abilities structure
  if (!e) e = mii_reset(&ws->mii);
  if (!e) e = mii_abilities(&ws->mii, &dev->abilities);
  dev->abilities.multicast   = true;
  dev->abilities.promiscuous = true;

  if (e)
  {
    usb_close(&ws->pipe_tx);
    usb_close(&ws->pipe_rx);
    return e;
  }

  read_packet(ws->pipe_rx,ws);
  return NULL;
}

static _kernel_oserror* device_stop(net_device_t* dev)
{
  ws_t* ws = dev->private;

  if (!dev->gone)
  {
    // Disable Rx
    usb_control(dev->name, 0x40, 0x10, 0, 0x0000, 0x0000, 0);

    // Power down PHY
    usb_control(dev->name, 0x40, 0x20,
                SW_RESET_INT_PHY_PDOWN,
                0x000, 0, 0);

    // Powerdown and isolate PHY
    mii_shutdown(&ws->mii);
  }

  usb_close(&ws->pipe_tx);
  usb_close(&ws->pipe_rx);
  return NULL;
}

static _kernel_oserror* device_close(void** private)
{
  xfree(*private);
  return NULL;
}

//---------------------------------------------------------------------------
// Backend description
//---------------------------------------------------------------------------
static const net_backend_t s_backend = {
  .name        = N_AX88772,
  .description = "DescAx7",
  .open        = device_open,
  .start       = device_start,
  .stop        = device_stop,
  .close       = device_close,
  .transmit    = device_transmit,
  .info        = NULL,
  .config      = device_configure,
  .status      = device_status
};

//---------------------------------------------------------------------------
// Called during module initialisation.
//---------------------------------------------------------------------------
_kernel_oserror* ax88772_register(void)
{
  return net_register_backend(&s_backend);
}
