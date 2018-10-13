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
 * Backend for devices based on the ASIX AX88172 10/100Mb USB Ethernet
 * Adaptor chip.
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
#include "swis.h"

#include <stddef.h>
#include <assert.h>
#include <string.h>

// RX control register flags
#define RX_PROMISC       0x01    // Pass all packets seen on wire to host.
#define RX_ALLMULTI      0x02    // Pass all multicast packets to host.
#define RX_UNICAST       0x04    // Pass unicast packets to host?
#define RX_BROADCAST     0x08    // Pass all broadcast frames to host.
#define RX_MULTICAST     0x10    // Pass all MC address list frms to host.
#define RX_ENABLE        0x80    // Enable MAC

// Medium status flags. Need updating when link configuration changes.
#define MEDIUM_FULL_DUPLEX     0x02 // 1 => Full duplex, 0 => Half duplex.
#define MEDIUM_TX_ABORT_ALLOW  0x04 //
#define MEDIUM_FLOW_CONTROL    0x10 // Pause

// NULL PHY ID.
#define NULL_PHY         0xe0

// Device state
typedef struct
{
  usb_pipe_t      pipe_rx;
  usb_pipe_t      pipe_tx;
  mii_t           mii;
  uint8_t         phy_id;
  net_device_t*   dev;
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
  char blk[2048];
  size_t size = sizeof(blk);
  _kernel_oserror* e = usb_read(ws->pipe_rx, blk, &size);
  if (!e && size!=0) net_receive(ws->dev, blk, size, 0);
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

  uint16_t medium =  MEDIUM_TX_ABORT_ALLOW;
  if (status->duplex != net_duplex_half) medium |= MEDIUM_FULL_DUPLEX;
  if (status->tx_pause || status->rx_pause) medium |= MEDIUM_FLOW_CONTROL;

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
    uint16_t control = RX_BROADCAST | RX_UNICAST | RX_BROADCAST | RX_ENABLE;
    if (cfg->multicast) control |= RX_MULTICAST;
    if (cfg->promiscuous) control |= RX_PROMISC;
    e = usb_control(dev->name, 0x40, 0x10, control, 0x0000, 0x0000, 0);

    if (!e)
    {
      dev->status.broadcast   = true;
      dev->status.multicast   = cfg->multicast;
      dev->status.promiscuous = cfg->promiscuous;
    }
  }

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
  // Note: can't have two packets in the tx pipe's buffer at once because
  // it makes transmitting unreliable. Presumably this is because the USB
  // system ends up sending multiple packets to the device in one transfer
  // and as the device can't determine the packet boundries, it probably
  // just sends the whole lot as one packet.
  ws_t* ws = dev->private;
  int32_t start_time, time_now;
  
  _swix(OS_ReadMonotonicTime, _OUT(0), &start_time);
  
  while (usb_buffer_used(ws->pipe_tx)!=0)
  {
    // USB buffer should empty quickly if it doesn't something is wrong.
    _swix(OS_ReadMonotonicTime, _OUT(0), &time_now);
    if ((time_now - start_time) > 10) return err_translate(ERR_TX_BLOCKED);
  }
  
  size_t to_write = pkt->size;
  usb_write(ws->pipe_tx, (void*)&pkt->header, &to_write);
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

  // Read MAC address
  if (!e) e = usb_control(dev->name, 0xc0, 0x17, 0x0000, 0x0000,
                          ETHER_ADDR_LEN, dev->status.mac);

  // Read IPG registers and write them back again - need to do this to be
  // able to send packets
  uint8_t ipg[3];
  if (!e) e = usb_control(dev->name, 0xc0, 0x11, 0x0000, 0x0000,
                          0x0003, ipg);

  if (!e) e = usb_control(dev->name, 0x40, 0x12, ipg[0], 0x0000, 0, 0);
  if (!e) e = usb_control(dev->name, 0x40, 0x13, ipg[1], 0x0000, 0, 0);
  if (!e) e = usb_control(dev->name, 0x40, 0x14, ipg[2], 0x0000, 0, 0);

  // Open endpoints.
  if (!e) e = usb_open(dev->name,
                       &ws->pipe_rx,
                       USBRead,
                       &read_packet,
                       ws,
                       "Devices#bulk;size2049:$.%s",
                       dev->name);

  if (!e) e = usb_open(dev->name,
                       &ws->pipe_tx,
                       USBWrite,
                       &write_packet,
                       ws,
                       "Devices#bulk:$.%s",
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

  // Request initial packet.
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
  .name        = N_AX88172,
  .description = "DescAx1",
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
_kernel_oserror* ax88172_register(void)
{
  return net_register_backend(&s_backend);
}
