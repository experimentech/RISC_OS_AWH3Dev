//
// Copyright (c) 2009-2011, James Peacock
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
 * Backend for MosChip MCS7830 devices
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

#define DEBUG_PHY 0

//---------------------------------------------------------------------------
// Vendor specific commands
//---------------------------------------------------------------------------
#define VENDOR_BURST_WRITE   13u
#define VENDOR_BURST_READ    14u
#define VENDOR_MASK_WRITE    15u
#define VENDOR_EEPROM_ENABLE 16u
#define VENDOR_EEPROM_WRITE  17u

//---------------------------------------------------------------------------
// Device registers
//---------------------------------------------------------------------------
#define REG_MC_FILTER_0        0x00
#define REG_MC_FILTER_1        0x01
#define REG_MC_FILTER_2        0x02
#define REG_MC_FILTER_3        0x03
#define REG_MC_FILTER_4        0x04
#define REG_MC_FILTER_5        0x05
#define REG_MC_FILTER_6        0x06
#define REG_MC_FILTER_7        0x07
#define REG_IPG                0x08
#define REG_IPG1               0x09
#define REG_PHY_DATA_LOW       0x0a
#define REG_PHY_DATA_HIGH      0x0b
#define REG_PHY_COMMAND        0x0c
#define REG_PHY_COMMAND_STATUS 0x0d
#define REG_CONFIG             0x0e
#define REG_MAC_0              0x0f
#define REG_MAC_1              0x10
#define REG_MAC_2              0x11
#define REG_MAC_3              0x12
#define REG_MAC_4              0x13
#define REG_MAC_5              0x14

//---------------------------------------------------------------------------
// Configuration register (REG_CONFIG) flags
//---------------------------------------------------------------------------
#define CONFIG_PROMISCUOUS (1u<<0)
#define CONFIG_MULTICAST   (1u<<1)
#define CONFIG_SLEEP       (1u<<2)
#define CONFIG_TX_ENABLE   (1u<<3)
#define CONFIG_RX_ENABLE   (1u<<4)
#define CONFIG_FULL_DUPLEX (1u<<5)
#define CONFIG_SPEED_100   (1u<<6)
#define CONFIG_OVERRIDE    (1u<<7)

//---------------------------------------------------------------------------
// PHY command register manipulation:
//
//  1) If writing write data to REG_PHY_DATA_LOW/REG_PHY_DATA_HIGH
//  2) Set REG_PHY_COMMAND to indicate read or write and PHY address
//  3) Set REG_PHY_COMMAND_STATUS b7(pending)=1, b6(ready)=0 and register
//  4) When REG_PHY_COMMAND_STATUS b6(ready)=1
//  5) If read, fetch result from REG_PHY_DATA_LOW/REG_PHY_DATA_HIGH
//---------------------------------------------------------------------------
#define PHY_COMMAND_READ(phyaddress)  ((1u<<6) | (phyaddress))
#define PHY_COMMAND_WRITE(phyaddress) ((1u<<5) | (phyaddress))
#define PHY_COMMAND_START(phyregister) ((1u<<7) | (phyregister))
#define PHY_COMMAND_COMPLETE(status) (((status) & (1u<<6))==(1u<<6))
#define PHY_COMMAND_TRIES 5
#define PHY_COMMAND_WAIT 1

//---------------------------------------------------------------------------
// Workspace
//---------------------------------------------------------------------------
typedef struct
{
  usb_pipe_t      pipe_rx;
  usb_pipe_t      pipe_tx;
  net_device_t*   dev;
  mii_t           mii;
  uint8_t         phy_id;
  uint8_t         config;
} ws_t;

//---------------------------------------------------------------------------
// Read/write device registers
//---------------------------------------------------------------------------
static _kernel_oserror* reg_read(const ws_t*    ws,
                                 uint8_t        first_reg,
                                 uint8_t        no_to_read,
                                 const uint8_t* out)
{
  return usb_control(ws->dev->name,
                     USB_REQ_VENDOR_READ,
                     VENDOR_BURST_READ,
                     0x0000,
                     first_reg,
                     no_to_read,
                     (uint8_t*)out);
}

static _kernel_oserror* reg_write(const ws_t* ws,
                                  uint8_t     first_reg,
                                  uint8_t     no_to_read,
                                  uint8_t*    out)
{
  return usb_control(ws->dev->name,
                     USB_REQ_VENDOR_WRITE,
                     VENDOR_BURST_WRITE,
                     0x0000,
                     first_reg,
                     no_to_read,
                     out);
}

//---------------------------------------------------------------------------
// Read/write a MII register from the device's PHY.
//---------------------------------------------------------------------------
static _kernel_oserror* phy_command(ws_t* ws, uint8_t command, unsigned reg)
{
  _kernel_oserror* e = reg_write(ws, REG_PHY_COMMAND, 1, &command);
  if (e) return e;

  uint8_t blk = PHY_COMMAND_START(reg);
  e = reg_write(ws, REG_PHY_COMMAND_STATUS, 1, &blk);

  int i=0;
  while(!e)
  {
    e = reg_read(ws, REG_PHY_COMMAND_STATUS, 1, &blk);
    if (e || PHY_COMMAND_COMPLETE(blk)) break;
    if (++i==PHY_COMMAND_TRIES)
    {
      syslog("%s: phy command timeout", ws->dev->name);
      return err_translate(ERR_BAD_DEVICE);
    }
    e = cs_wait(PHY_COMMAND_WAIT);
  }
  return e;
}

static _kernel_oserror* phy_read(void* handle,
                                 unsigned reg_no,
                                 uint16_t *value)
{
  ws_t* ws = handle;
  _kernel_oserror* e = phy_command(ws, PHY_COMMAND_READ(ws->phy_id), reg_no);
  if (!e)
  {
    uint8_t blk[2];
    e = reg_read(ws, REG_PHY_DATA_LOW, 2, blk);
    if (!e)
    {
      *value = blk[0] + (blk[1]<<8);
      if (DEBUG_PHY) syslog("%s: phy_read (%u): %04hx",
                            ws->dev->name, reg_no, *value);
    }
  }
  return e;
}

static _kernel_oserror* phy_write(void* handle,
                                  unsigned reg_no,
                                  uint16_t val)
{
  ws_t* ws = handle;
  if (DEBUG_PHY) syslog("%s: phy_write(%u): %04hx",
                         ws->dev->name, reg_no, val);
  uint8_t blk[2];
  blk[1] = val >> 8;
  blk[0] = val & 0xff;
  _kernel_oserror* e = reg_write(ws, REG_PHY_DATA_LOW, 2, blk);
  if (!e) e = phy_command(ws, PHY_COMMAND_WRITE(ws->phy_id), reg_no);
  return e;
}

//---------------------------------------------------------------------------
// USB pipe handlers
//---------------------------------------------------------------------------
static void read_packet(usb_pipe_t pipe, void* dev_pw)
{
  ws_t* ws = dev_pw;
  char blk[2048];
  size_t size = sizeof(blk);
  _kernel_oserror* e = usb_read(ws->pipe_rx, blk, &size);
  if (!e && size>1)
  {
    //syslog("Rx: %0x %zi", blk[size-1], size-1);
    net_receive(ws->dev, blk, size - 1, 0);
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
  ws_t* ws = dev->private;
  uint8_t config = ws->config;
  if (dev->status.speed!=net_speed_10Mb) config |= CONFIG_SPEED_100;
  if (dev->status.duplex!=net_duplex_half) config |= CONFIG_FULL_DUPLEX;
  return reg_write(ws, REG_CONFIG, 1, &config);
}

//---------------------------------------------------------------------------
// Backend functions.
//---------------------------------------------------------------------------
static _kernel_oserror* device_configure(net_device_t*       dev,
                                         const net_config_t* cfg)
{
  ws_t* ws = dev->private;
  _kernel_oserror* e = mii_configure(&ws->mii, &dev->status, cfg);

  if (!e)
  {
    uint8_t config = CONFIG_TX_ENABLE | CONFIG_RX_ENABLE | CONFIG_OVERRIDE;
    if (cfg->multicast) config |= CONFIG_MULTICAST;
    if (cfg->promiscuous) config |= CONFIG_PROMISCUOUS;
    ws->config = config;

    dev->status.broadcast   = true;
    dev->status.multicast   = cfg->multicast;
    dev->status.promiscuous = cfg->promiscuous;
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
    if (time_now - start_time > 10) return err_translate(ERR_TX_BLOCKED);
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
  ws->dev        = NULL;
  ws->phy_id     = 0;
  ws->config     = 0;

  mii_initialise(&ws->mii, phy_read, phy_write, ws);

  *private = ws;
  return NULL;
}

static _kernel_oserror* device_start(net_device_t* dev, const char* options)
{
  _kernel_oserror* e = NULL;
  ws_t* ws = dev->private;
  ws->dev  = dev;

  // Attempt to find the PHY address, can't see any way to get it
  // directly, so this will have to do.
  while (ws->phy_id!=32)
  {
    e = mii_present(&ws->mii);
    if (!e) break;
    if (e!=err_translate(ERR_BAD_PHY)) return e;
    ws->phy_id += 1;
  }
  if (ws->phy_id==32)
  {
    syslog("Can't find PHY address");
    return err_translate(ERR_BAD_DEVICE);
  }

  // Read MAC address
  if (!e) e = reg_read(ws, REG_MAC_0, ETHER_ADDR_LEN, dev->status.mac);

  // Reset PHY and update abilities structure
  if (!e) e = mii_reset(&ws->mii);
  if (!e) e = mii_abilities(&ws->mii, &dev->abilities);
  dev->abilities.multicast   = true;
  dev->abilities.promiscuous = true;

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
                       "Devices#bulk;size2049:$.%s",
                       dev->name);

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
    uint8_t zero = 0;
    reg_write(ws, REG_CONFIG, 1, &zero);
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
  .name        = N_MCS7830,
  .description = "DescMos",
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
_kernel_oserror* mcs7830_register(void)
{
  return net_register_backend(&s_backend);
}
