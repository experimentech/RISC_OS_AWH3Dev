/*
 * Copyright (c) 2011 by Thomas Milius Stade, Germany
 *                       Raik Fischer Neuenhagen, Germany
 *                       Rainer Schubert Ammersbek, Germany
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of Thomas Milius Stade, Germany, Rainer Schubert Ammersbek, Germany,
 *       nor Rainer Schubert Ammersbek, Germany nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
/*
   Thanks to SMSC for providing the required information and support for queries.
   Note that SMSC documentation is now available from Microchip's website:
     http://www.microchip.com/wwwproducts/en/LAN9500A
     http://www.microchip.com/wwwproducts/en/LAN9512
*/
/* Created 07.12.2010 T. Milius   Based on the other drivers written by
                      with the    J. Peacock. Information taken from
                      help of     various sources like SMSC LAN9100 documentation
                      R. Schubert and SMSC developer information
                      R. Fischer
   Changed 14.01.2011 R. Schubert MAC by variable
   Changed 15.01.2011 T. Milius   General clean up of the first test version to a
                                  proper code.
   Changed 18.01.2011 T. Milius   moved link configuration into a separate function
   Changed 25.01.2011 T. Milius   moved pause depend setting into link configuration */

/* !!!!!!!!!! Libraries !!!!!!!!!! */
/* ---------- ANSI-C ---------- */
#include <stdio.h>

/* ---------- RISC OS ---------- */
#include "swis.h"

/* ---------- own ---------- */
#include "backends.h"
#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "net.h"
#include "products.h"
#include "mii.h"

#define CHIP_ID_9500     0x9500 /* LAN9500/LAN9500i */
#define CHIP_ID_9500A    0x9E00 /* LAN9500A/LAN9500Ai */
#define CHIP_ID_951x     0xEC00 /* LAN9512/LAN9513/LAN9514 plus 'i' variants */

/* Receive buffer registered with DeviceFS */
#define RX_BUF_SIZE      16384

//---------------------------------------------------------------------------
// Workspace
//---------------------------------------------------------------------------
typedef struct
{
  usb_pipe_t      pipe_rx;
  usb_pipe_t      pipe_tx;
  net_device_t*   dev;
  mii_t           mii;
  unsigned long   phy_address;
  unsigned long   chip_id;
  unsigned long   eeprom_size;
  uint32_t        rx_buf[RX_BUF_SIZE/sizeof(uint32_t)];
} ws_t;

//---------------------------------------------------------------------------
// Put arbitrary MAC address in an array so that we may have a chance to re-
// configure it. Reason: BeagleBoard(xM) comes without a default one.
// Idea is to set <EtherUSB$MAC_Configured> to a "recyled" MAC address to
// avoid clashes between all the BBxMs with the same MAC. R.S.
//
// (Above reasoning is obsolete now that we'll use the machine ID, but let's
//  keep this logic around for compatibility - JL)
//---------------------------------------------------------------------------

static void fill_arbitraryMAC(net_device_t* dev)
{
  char *p;
  unsigned long var_mac[ETHER_ADDR_LEN];
  int i;

  if ((p=getenv("EtherUSB$MAC_Configured")) != (char *) NULL) {
    if(sscanf(p,"%lx:%lx:%lx:%lx:%lx:%lx",
              &var_mac[0],
              &var_mac[1],
              &var_mac[2],
              &var_mac[3],
              &var_mac[4],
              &var_mac[5]) == ETHER_ADDR_LEN) {
      for(i=0;i<ETHER_ADDR_LEN;i++) {
         dev->status.mac[i] = (uint8_t)var_mac[i];
      }
      return;
    } else {
      syslog("MAC address %s is invalid\n",p);
    }
  }
}

//---------------------------------------------------------------------------
// Read/write device registers
//---------------------------------------------------------------------------
/* Little Endian 32 Bit on ARM and device so leave data unchanged */
static _kernel_oserror* reg_read(const ws_t*          ws,
                                 uint16_t             reg,
                                 unsigned long* data)
{
  _kernel_oserror* e;

  if ((e=usb_control(ws->dev->name,
                     USB_REQ_VENDOR_READ,
                     /* Read register */
                     0xA1,
                     0x0000,
                     reg,
                     4,
                     (void *) data)) != NULL) {
    syslog("smsc95xx reg read %s %x: %x %s", ws->dev->name, reg, e->errnum, e->errmess);
    return e;
    }
  syslog("smsc95xx reg read %s %x: %lx", ws->dev->name, reg, *data);
  return NULL;
}

static _kernel_oserror* reg_write(const ws_t*   ws,
                                  uint16_t      reg,
                                  unsigned long data)
{
  _kernel_oserror* e;

  if ((e=usb_control(ws->dev->name,
                     USB_REQ_VENDOR_WRITE,
                     /* Write register */
                     0xA0,
                     0x0000,
                     reg,
                     4,
                     &data)) != NULL) {
    syslog("smsc95xx reg write %s %x %lx: %x %s", ws->dev->name, reg, data, e->errnum, e->errmess);
    return e;
    }
  syslog("smsc95xx reg write %s %x %lx", ws->dev->name, reg, data);
  return NULL;
}

static _kernel_oserror* reg_modify(const ws_t*  ws,
                                  uint16_t      reg,
                                  unsigned long bic,
                                  unsigned long eor)
{
  unsigned long data;
  
  _kernel_oserror* e=reg_read(ws,reg,&data);
  
  if (e == NULL) e=reg_write(ws,reg,((data & ~bic) ^ eor));
  
  return e;
}

#define SMSC95XX_MII_ACCESS_READ        0u
#define SMSC95XX_MII_ACCESS_BUSY        1u
static _kernel_oserror* phy_read(void*     handle,
                                 unsigned  reg,
                                 uint16_t* data)
{
  const ws_t* ws = (const ws_t *) handle;
  unsigned long reg_data;
  unsigned long start_time, actual_time;
  _kernel_swi_regs regs;
  _kernel_oserror* e;

  syslog("smsc95xx phy read %s %d", ws->dev->name, reg);
  /* Access to PHY indirects through MII registers. */
  /* Check that MII is not busy (MII_ADDR) */
  if((e=reg_read(ws,
                 0x0114,
                 &reg_data)) != NULL) {
    return e;
    }
  if ((reg_data & SMSC95XX_MII_ACCESS_BUSY) != 0) {
    return err_translate(ERR_MII_IN_USE);
    }

  /* Set the address, index & direction (read from PHY) by writing
     to MII_ADDR. */
  reg_data= ((ws->phy_address & 0x0000001FL)<<11) | ((reg & 0x001FL)<<6) | SMSC95XX_MII_ACCESS_READ | SMSC95XX_MII_ACCESS_BUSY;
  if((e=reg_write(ws,
                  0x0114,
                  reg_data)) != NULL) {
    return e;
    }
  /* Wait for completing by checking BUSY state */
  start_time=(unsigned long) regs.r[0];
  do {
    /* Get Busy info from MII (MII_ADRR). */
    if((e=reg_read(ws,
                   0x0114,
                   &reg_data)) != NULL) {
      return e;
      }
    if ((reg_data & 0x00000001) == 0) {
      /* Now obtain value from MII_DATA */
      if((e=reg_read(ws,
                     0x0118,
                     &reg_data)) != NULL) {
        return e;
        }
      *data=reg_data;
      syslog("smsc95xx phy read value %x", *data);
      return NULL;
      }
    if ((e=_kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL) {
      return e;
      }
    actual_time=(unsigned long) regs.r[0];
    }
  while(actual_time < (start_time + 10));
  return err_translate(ERR_TIMEOUT);
}

static _kernel_oserror* phy_write(void*    handle,
                                  unsigned reg,
                                  uint16_t data)
{
  const ws_t* ws = (const ws_t *) handle;
  unsigned long reg_data;
  unsigned long start_time, actual_time;
  _kernel_swi_regs regs;
  _kernel_oserror* e;

  syslog("smsc95xx phy write %s %d %lx",
                    ws->dev->name,
                    reg,
                    data);
  /* Check that MII is not busy */
  /* Get Busy info from MII (MII_ADRR). */
  if((e=reg_read(ws,
                 0x0114,
                 &reg_data)) != NULL) {
    return e;
    }
  if ((reg_data & 0x00000001) != 0) {
    return err_translate(ERR_MII_IN_USE);
    }

  /* Prepare data (MII_DATA)*/
  if((e=reg_write(ws,
                  0x0118,
                  data)) != NULL) {
    return e;
    }

  /* Set the address, index & direction (write to PHY) */
  reg_data= ((ws->phy_address & 0x0000001F)<<11) | ((reg & 0x001FL)<<6) | 2u | 1u;
  if((e=reg_write(ws,
                  0x0114,
                  reg_data)) != NULL) {
    return e;
    }
  /* Wait for completing by checking BUSY state */
  start_time=(unsigned long) regs.r[0];
  do {
    /* Get Busy info from MII (MII_ADRR). */
    if((e=reg_read(ws,
                   0x0114,
                   &reg_data)) != NULL) {
      return e;
      }
    if ((reg_data & 0x00000001) == 0) {
      return NULL;
      }
    if ((e=_kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL) {
      return e;
      }
    actual_time=(unsigned long) regs.r[0];
    }
  while(actual_time < (start_time + 10));
  return err_translate(ERR_TIMEOUT);
}

#define SMSC95XX_E2P_CMD                0x30
#define SMSC95XX_E2P_DATA               0x34
#define SMSC95XX_E2P_CMD_EPC_BSY        (1ul << 31)
#define SMSC95XX_E2P_CMD_EPC_DL         (1ul << 9)
#define SMSC95XX_E2P_CMD_READ           0ul
#define SMSC95XX_E2P_DATA_MASK          0xfful

static _kernel_oserror* read_eeprom_byte(const ws_t* ws, unsigned long offset, uint8_t* byteout)
{
  unsigned long reg_data;
  _kernel_oserror* e;
 
  if (byteout == NULL) return NULL;
  if (e = reg_read(ws, SMSC95XX_E2P_CMD, &reg_data), e) return e;
  if (reg_data & SMSC95XX_E2P_CMD_EPC_BSY) return err_translate(ERR_TIMEOUT);
  
  if (e = reg_write(ws, SMSC95XX_E2P_CMD, (SMSC95XX_E2P_CMD_EPC_BSY | SMSC95XX_E2P_CMD_READ | offset)), e) return e;
  do
  {
     if (e = reg_read(ws, SMSC95XX_E2P_CMD, &reg_data), e) return e;
  } while (reg_data & SMSC95XX_E2P_CMD_EPC_BSY);
  
  if ((reg_data & SMSC95XX_E2P_CMD_EPC_DL) == 0) return err_translate(ERR_TIMEOUT);
  
  if (reg_read(ws, SMSC95XX_E2P_DATA, &reg_data), e) return e;
  *byteout = (uint8_t)(reg_data & SMSC95XX_E2P_DATA_MASK);
  return NULL;
}

static _kernel_oserror* read_eeprom(const ws_t* ws, unsigned long offset, unsigned long length, uint8_t *data)
{
  uint8_t reg_data;
  _kernel_oserror* e;

  if (offset + length > ws->eeprom_size)  return err_translate(ERR_EEPROM_RANGE);
  
  /* If eeprom byte 0 isn't 0xA5 then the eeprom is invalid */
  if (e = read_eeprom_byte(ws, 0, &reg_data), e) return e;
  if (reg_data != 0xA5) return err_translate(ERR_TIMEOUT);
  
  for (unsigned long i = 0; i < length; i++)
  {
    if (e = read_eeprom_byte(ws, offset + i, data + i), e) return e;
  }
  
  return NULL;
}

static bool check_mac(uint8_t *mac)
{
  int i;
  bool match;
  
  match=true;
  /* 00 00 00 00 00 00 */
  i=0;
  while(i<ETHER_ADDR_LEN) {
    if (mac[i] != 0x00) {
      match=false;
      break;
      }
    i++;
  }
  if (match) return false;
  match=true;
  /* FF FF FF FF FF FF */
  i=0;
  while(i<ETHER_ADDR_LEN) {
    if (mac[i] != 0xFF) {
      match=false;
      break;
      }
    i++;
  }
  if (match) return false;
  return true;
}

static _kernel_oserror* update_medium(net_device_t *dev)
{
  ws_t* ws = dev->private;
  _kernel_oserror *e;
  unsigned long reg_data;

  /* Adapt MAC to PHY duplex settings (MAC_CR) */
  if((e=reg_read(ws,
                 0x0100,
                 &reg_data)) != NULL) {
    return e;
    }
  /* Clear duplex information */
  reg_data&=~(0x00100000);
  /* Set new duplex information */
  if(dev->status.duplex == net_duplex_full) {
    /* MAC_CR_FDPX_ */
    reg_data|=0x00100000;
    }
  if((e=reg_write(ws,
                  0x0100,
                  reg_data)) != NULL) {
    return e;
    }

  /* Cope with pause handling */
  /* Set flow (FLOW) */
  const unsigned long AFC_LO = 0x30; /* 3KB low threshold (in units of 64 bytes) */
  const unsigned long AFC_HI = 0xF8; /* 15.5KB high threshold */
  const unsigned long PAUSE_TIME = AFC_HI-AFC_LO; /* Pause time in units of 512 bits */
  /* Note that we're setting the pause time to how long it takes the FIFO to
     transition from the low threshold to the high threshold (at network RX
     speed), even though we should technically be able to empty the FIFO much
     quicker (480Mbps USB vs. 100Mbps network)
     This is a compromise because:
     (a) The chip only sends a pause frame when the RX FIFO level transitions
         from below AFC_LO to above AFC_HI. So if the timer expires before we
         empty the FIFO, the remote link will resume transmitting, potentially
         overflowing the FIFO and causing packets to be lost. 
     (b) Setting a time which is too high may hurt performance, because although
         the chip will send a zero-time pause frame once AFC_LO is reached,
         there's no guarantee the remote link will receive the frame.
     */
  reg_data=(PAUSE_TIME<<16) & 0xFFFF0000;
  if(dev->status.rx_pause || (dev->status.duplex == net_duplex_half)) {
    reg_data|=0x2; /* Enable PAUSE RX, or enable back pressure */
  }
  if((e=reg_write(ws,
                  0x011C,
                  reg_data)) != NULL) {
    return e;
    }
  /* Set Automatic flow control configuration (AFC_CFG) */
  reg_data=(AFC_HI<<16) | (AFC_LO<<8); /* Upper/lower RX FIFO bounds for PAUSE / backpressure */
  if(dev->status.tx_pause || (dev->status.duplex == net_duplex_half)) {
    reg_data|=0x1; /* Configure which frames trigger PAUSE TX / backpressure (all frames) */
  }
  if(dev->status.speed == net_speed_10Mb) {
    reg_data|=0xD0; /* 500uS backpressure duration */
  } else {
    reg_data|=0x40; /* 50uS backpressure duration */
  }
  if((e=reg_write(ws,
                  0x002C,
                  reg_data)) != NULL) {
    return e;
  }

  return NULL;
}

static _kernel_oserror* configure_link(net_device_t* dev,
                                       const net_config_t* cfg)
{
  ws_t* ws = dev->private;
  _kernel_oserror* e = mii_configure(&ws->mii, &dev->status, cfg);
  if (e)
  {
    return e;
  }

  /* PHY internal only */
  if (ws->phy_address == 1) {
    uint16_t reg_data;
    if (ws->chip_id != CHIP_ID_9500A) {
      /* Auto-MDIX only works reliably if link autonegotiation is enabled (a known limitation of the protocol).
         So make sure we force it off if link autonegotiation is disabled. */
      if((e=phy_read(ws,27,&reg_data)) != NULL) {
        return e;
      }
      reg_data &= ~0xE000;
      if (dev->status.autoneg == net_autoneg_none) {
        reg_data |= 0x8000;
      }
      if((e=phy_write(ws,27,reg_data)) != NULL) {
        return e;
      }
    } else {
      /* For the 9500A, instead of disabling Auto-MDIX we can extend the crossover time so that it will still operate correctly with manual link configuration */
      if((e=phy_read(ws,16,&reg_data)) != NULL) {
        return e;
      }
      if (dev->status.autoneg == net_autoneg_none) {
        reg_data|=0x0001;
      } else {
        reg_data&=~0x0001;
      }
      if((e=phy_write(ws,16,reg_data)) != NULL) {
        return e;
      }
    }
  }

  /* Update medium now if autonegotiation disabled. Else, wait for the status callback. */
  if (dev->status.autoneg == net_autoneg_none)
  {
    e = update_medium(dev);
  }
  return e;
}

//---------------------------------------------------------------------------
// USB pipe handlers
//---------------------------------------------------------------------------
static void read_packet(usb_pipe_t pipe, void* dev_pw)
{
  ws_t* ws = dev_pw;
  uint32_t* buf = ws->rx_buf;

  pipe = pipe;
    
  for (;;)
  {
    size_t size = sizeof(ws->rx_buf);
  
    _kernel_oserror* e = usb_read(ws->pipe_rx, buf, &size);

    if (e || size == 0) break;
    usb_start_read(ws->pipe_rx);
    
    if (size>4)
    {
      
      int off = 0;
      size = (size+3)/4;
      size_t packet_size;
      size_t next;
      for  (off = 0; off < size-1; off = next)
      {
          packet_size = (buf[off] >> 16) & 0x3fff;
          next = off + ((packet_size+7)/4);
          if (packet_size > 0 && packet_size <= ETHER_MAX_LEN && next <= size) 
                net_receive(ws->dev, &buf[off+1], packet_size, 0);
      }
    }
  }
  
  usb_start_read(ws->pipe_rx);
}

static void write_packet(usb_pipe_t pipe, void* dev_pw)
{
  ws_t* ws = dev_pw;
  net_attempt_transmit(ws->dev);
  UNUSED(pipe);
}

//---------------------------------------------------------------------------
// Backend functions.
//---------------------------------------------------------------------------
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

static _kernel_oserror* device_configure(net_device_t* dev,
                                         const net_config_t* cfg)
{
  _kernel_oserror *e = configure_link(dev,
                        (net_config_t*) cfg);
  return e;
}

static _kernel_oserror* device_transmit(net_device_t*   dev,
                                        const net_tx_t* pkt)
{
  ws_t* ws = dev->private;
  unsigned long *prefix;
  /* Requires two Words at beginning TX_CMD_A and TX_CMD_B
     (see SMSC AN1212.pdf for details) */
  size_t to_write = 2*4 + pkt->size;
  unsigned long alignment;

  /* If using more than one paket at a time pakets must be word aligned
     so a round to a multiple of 4 is necassary. */
  alignment=(pkt->size % 4lu);
  if (alignment != 0) {
    to_write+=(size_t)(4 - alignment);
    }

  prefix=(unsigned long *) &pkt->header;
  prefix-=2;
  /* Is first and last segment of a packet */
  prefix[0]=0x00002000L | 0x00001000L | pkt->size;
  /* May also contain an ID but we don't use this */
  prefix[1]=pkt->size;
  usb_write(ws->pipe_tx, (void*)prefix, &to_write);
  return (to_write==0) ? err_translate(ERR_TX_BLOCKED) : NULL;
}

static _kernel_oserror* device_open(const USBServiceCall* dev,
                                    const char*           options,
                                    void**                private)
{
  syslog("smsc95xx open");
  if (!options) return err_translate(ERR_UNSUPPORTED);

  ws_t* ws = xalloc(sizeof(ws_t));
  if (!ws) return err_translate(ERR_NO_MEMORY);

  ws->pipe_rx    = 0;
  ws->pipe_tx    = 0;
  ws->dev        = NULL;
  /* other values initialized during device_start */

  mii_initialise(&ws->mii, phy_read, phy_write, ws);

  *private = ws;
  UNUSED(dev);
  return NULL;
}

static _kernel_oserror* device_start(net_device_t* dev, const char* options)
{
  ws_t* ws = dev->private;
  unsigned long reg_data;
  int i;
  unsigned long start_time, actual_time;
  _kernel_swi_regs regs;
  _kernel_oserror* e;

  ws->dev  = dev;
  syslog("smsc95xx start");

  /* Reset */
  /* Set according Bit inside HW_CFG */
  if((e=reg_read(ws,
                 0x0014,
                 &reg_data)) != NULL) {
    return e;
    }
  reg_data|=0x00000008;
  if((e=reg_write(ws,
                  0x0014,
                  reg_data)) != NULL) {
    return e;
    }
  /* Wait for reset finished. */
  if ((e=_kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL) {
    return e;
    }
  start_time=(unsigned long) regs.r[0];
  do {
    /* Check whether Reset Bit still set */
    if((e=reg_read(ws,
                   0x0014,
                   &reg_data)) != NULL) {
      return e;
      }
    if ((e=_kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL) {
      return e;
      }
    actual_time=(unsigned long) regs.r[0];
    }
  while(((reg_data & 0x00000008) != 0) &&
        (actual_time < (start_time + 100)));
  if ((reg_data & 0x00000008) != 0) {
    return err_translate(ERR_TIMEOUT);
    }
  /* Determine chip type (ID_REV) to cope with certain special properties */
  syslog("Chip type");
  if((e=reg_read(ws,
                 0x0000,
                 &reg_data)) != NULL) {
    return e;
    }
  ws->chip_id=reg_data>>16;
  /* ??? EEPROM existence check still missing */
  ws->eeprom_size=512;

  dev->status.broadcast   = 1;
  dev->status.multicast   = 1;
  dev->status.promiscuous = 0;

  /* Reset the PHY */
  syslog("reset PHY");
  /* Set according Bit inside PM_CTRL */
  if((e=reg_read(ws,
                 0x0020,
                 &reg_data)) != NULL) {
    return e;
    }
  reg_data|=0x00000010;
  if((e=reg_write(ws,
                  0x0020,
                  reg_data)) != NULL) {
    return e;
    }
  /* Wait for reset finished. */
  if ((e=_kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL) {
    return e;
    }
  start_time=(unsigned long) regs.r[0];
  do {
    /* Check whether Reset Bit still set */
    if((e=reg_read(ws,
                   0x0020,
                   &reg_data)) != NULL) {
      return e;
      }
    if ((e=_kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL) {
      return e;
      }
    actual_time=(unsigned long) regs.r[0];
    }
  while(((reg_data & 0x00000010) != 0) &&
        (actual_time < (start_time + 100)));
  if ((reg_data & 0x00000010) != 0) {
    return err_translate(ERR_TIMEOUT);
    }
  /* Flush log */
  syslog_flush();

  /* MAC handling */
  syslog("mac handling");

  /* Obtain EUI48 from EEPROM - Starts at Position 1 */
  e = read_eeprom(ws, 1, ETHER_ADDR_LEN, dev->status.mac);
  
  if (e || !check_mac(dev->status.mac))
  {
    /* Default */
    for (i = 0; i < ETHER_ADDR_LEN; i++) dev->status.mac[i] = 0xFF;
    /* If MAC has been set by system variable, prefer that over the last-used
       MAC. This allows machines with EtherUSB in ROM to use a custom MAC by
       setting the variable and then reiniting the module. */
    fill_arbitraryMAC(dev);
  }
  if(!check_mac(dev->status.mac)) {
    /* If not given try to keep last MAC set
       Only valid if there was no reset. */
    /* Low (ADRRL) 4 Bytes */
    if((e=reg_read(ws,
                   0x0108,
                   &reg_data)) != NULL) {
      return e;
      }
    dev->status.mac[0]=(uint8_t)(reg_data >> 0);
    dev->status.mac[1]=(uint8_t)(reg_data >> 8);
    dev->status.mac[2]=(uint8_t)(reg_data >> 16);
    dev->status.mac[3]=(uint8_t)(reg_data >> 24);
    /* High (ADRRH) 2 Bytes */
    if((e=reg_read(ws,
                   0x0104,
                   &reg_data)) != NULL) {
      return e;
      }
    dev->status.mac[4]=(uint8_t)(reg_data >> 0);
    dev->status.mac[5]=(uint8_t)(reg_data >> 8);
    }
  if(!check_mac(dev->status.mac)) {
    /* Try the machines configured MAC (e.g. for builtin SMSC on Raspberry Pi) */
    net_machine_mac(dev->status.mac);
  }
  if(!check_mac(dev->status.mac)) {
    /* Try to construct a MAC from machine ID, or failing that, a hardcoded
       default */
    net_default_mac(dev->dib.dib_unit, dev->status.mac);
  }
  /* Set MAC */
  /* Low (ADRRL) 4 Bytes */
  reg_data = ((unsigned long)(dev->status.mac[3])<<24) |
             ((unsigned long)(dev->status.mac[2])<<16) |
             ((unsigned long)(dev->status.mac[1])<<8 ) |
             ((unsigned long)(dev->status.mac[0])<<0 ) ;

  if((e=reg_write(ws,
                  0x0108,
                  reg_data)) != NULL) {
    return e;
    }
  /* High (ADRRH) 2 Bytes */
  reg_data=((unsigned long)(dev->status.mac[5])<<8) |
           ((unsigned long)(dev->status.mac[4])   ) ;

  if((e=reg_write(ws,
                  0x0104,
                  reg_data)) != NULL) {
    return e;
    }
  /* Flush log */
  syslog_flush();

  /* Various setups */
  syslog("set up");
  /* Set to operational mode.
     Activate according Bit inside HW_CFG */
  if((e=reg_read(ws,
                 0x0014,
                 &reg_data)) != NULL) {
    return e;
    }
  reg_data|=0x00001000;
  if((e=reg_write(ws,
                  0x0014,
                  reg_data)) != NULL) {
     return e;
     }
  /* Flush log */
  syslog_flush();
  syslog("burst");
    
  /* Set multiple packets per frame, NAK empty input buffer, Burst cap enable */
  #define HW_CFG_BCE (1 << 1)
  #define HW_CFG_MEF (1 << 5)
  #define HW_CFG_BIR (1 << 12)
  #define HW_CFG_BITS (HW_CFG_BIR | HW_CFG_MEF | HW_CFG_BCE)
  if (e = reg_modify(ws, 0x14, HW_CFG_BITS, HW_CFG_BITS), e != NULL) return e;

  /* Set Burst cap (BURST_CAP) */
  if (dev->speed == USB_SPEED_HI) 
  {
    if (e = reg_write(ws, 0x38, (RX_BUF_SIZE -4096)/512), e != NULL) return e;
  }
  else 
  {
    if (e = reg_write(ws, 0x38, (RX_BUF_SIZE -4096)/64), e != NULL) return e;
  }
  
  /* burst delay */
  if (e = reg_write(ws,0x6C,0x800), e != NULL)  return e;

  syslog("set up 2");
  /* Clear all Information inside Interrupt Status (INT_STS) */
  if((e=reg_write(ws,
                  0x0008,
                  0xFFFFFFFF)) != NULL) {
    return e;
    }
  /* We don´t use the Interrupt Endpoint inside EtherUSB.
     So no need to set Interrupt Endpoint Control */
  /* Flush log */
  syslog_flush();

  /* Enable TX */
  syslog("enable TX");
  /* Now enable TX (MAC_CR). */
  if((e=reg_read(ws,
                 0x0100,
                 &reg_data)) != NULL) {
    return e;
    }
  reg_data|=0x00000008;
  if((e=reg_write(ws,
                  0x0100,
                  reg_data)) != NULL) {
    return e;
    }
  /* Also requires activation of transmission configuration (TX_CFG) */
  if((e=reg_write(ws,
                  0x0010,
                  0x00000004)) != NULL) {
    return e;
    }
  /* Flush log */
  syslog_flush();

  /* Enable RX */
  syslog("enable RX");
  /* Set up VLAN support (VLAN1). */
  if((e=reg_write(ws,
                  0x0120,
                  /* Which value is useful ???
                  0 ist default
                  1 could be useful according to MS documentation.
                  SMSC Softwaremanual tells about a special parameter.
                  VLANs are unusual under RISC OS. */
                  0)) != NULL) {
    return e;
    }
  /* Now enable RX (MAC_CR). */
  if((e=reg_read(ws,
                 0x0100,
                 &reg_data)) != NULL) {
    return e;
    }
  reg_data|=0x00000004;
  if((e=reg_write(ws,
                  0x0100,
                  reg_data)) != NULL) {
    return e;
    }
  /* Flush log */
  syslog_flush();

  /* Enable LEDs */
  syslog("LEDs");
  /* Clear according Bits inside LED configuration (LED_GPIO_CFG) and set them
     in such a way that they are indicating speed and activity. */
  if((e=reg_read(ws,
                 0x0024,
                 &reg_data)) != NULL) {
    return e;
    }
  reg_data&= ~0x03330000;
  reg_data|= 0x01110000;
  if((e=reg_write(ws,
                  0x0024,
                  reg_data)) != NULL) {
    return e;
    }
  if(ws->chip_id == CHIP_ID_9500A) {
    /* LAN9500A */
    /* Read from EEPROM configuration flags ??? */
    }
  /* Set filtering of incoming packages */
  syslog("filter RX");
  /* ??? Only ”all multicast” supported in the moment. */
    /* All multicast */
    /* Clear HASH (HASHH). */
    if((e=reg_write(ws,
                    0x010C,
                    0)) != NULL) {
      return e;
      }
    /* Clear HASH (HASHL). */
    if((e=reg_write(ws,
                    0x0110,
                    0)) != NULL) {
      return e;
      }
    /* Configure mode (MAC_CR) */
    if((e=reg_read(ws,
                   0x0100,
                   &reg_data)) != NULL) {
      return e;
      }
    /* Mulicast pass */
    reg_data|=0x00080000;
    /* No promiscuous and no hash pass filters */
    reg_data&=~(0x00040000 | 0x00002000);
    if((e=reg_write(ws,
                    0x0100,
                    reg_data)) != NULL) {
      return e;
      }
  /* Flush log */
  syslog_flush();

  /* Initialize PHY (HW_CFG) */
  syslog("set up PHY");
  if((e=reg_read(ws,
                 0x0014,
                 &reg_data)) != NULL) {
    return e;
    }

  if((reg_data & 0x00000004) != 0) {
    /* external PHY (HW_CFG_PSEL_) */
    /* ??? Auto detect as default */
    ws->phy_address = 32;
    if (ws->phy_address <= 31) {
      /* Given address (??? no point to be set yet) */
      unsigned long   phy_id;

      phy_id=ws->phy_address;
      /* Deactivate all PHYs available (PHY_BCR) */
      for (i=0; i<=31; i++) {
        ws->phy_address = i;
        if((e=phy_write(ws,
                        0,
                        /* Deactivation (PHY_BCR_ISOLATE) */
                        0x0400)) != NULL) {
          return e;
          }
        }
      /* Reactivate exactly the given one (PHY_BCR). */
      ws->phy_address=phy_id;
      if((e=phy_write(ws,
                      0,
                      0)) != NULL) {
        return e;
        }
      }
    else {
      /* Auto detect */
      ws->phy_address = 0;
      while(ws->phy_address <= 31) {
        uint16_t reg_data16;
        /* try to read PHY ID (PHY_ID_1) */
        if((e=phy_read(ws,
                       2,
                       &reg_data16)) != NULL) {
          return e;
          }
        /* Check whether a valid value has been found */
        if ((reg_data16 != 0x7FFF)&&
            (reg_data16 != 0xFFFF)&&
            (reg_data16 != 0x0000)) break;
        ws->phy_address++;
        }
      if (ws->phy_address > 31) {
        return err_translate(ERR_BAD_PHY);
        }
      }
    }
  else {
    /* internal PHY */
    ws->phy_address = 1;
    }

  /* Link setup and Status determined by EtherUSB after this procedure */

  /* Flush log */
  syslog_flush();

  /* RISC OS USB part */
  syslog("RISC OS USB");
  
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
                       "Devices#bulk;size16384:$.%s",
                       dev->name);

  /* Reset PHY and update abilities structure */
  if (!e) e = mii_reset(&ws->mii);
  if (!e) e = mii_abilities(&ws->mii, &dev->abilities);
  if (dev->speed != USB_SPEED_HI) {
    /* Only at USB high speed */
    dev->abilities.speed_100Mb = 0;
    }
  dev->abilities.multicast   = 1;
  dev->abilities.promiscuous = 0; /* ??? still to be implemented */
  dev->abilities.tx_rx_loopback = 0; /* ??? SMSC chips can. But where to configure. */
  dev->abilities.rx_pause = dev->abilities.tx_pause = dev->abilities.symmetric_pause = 1;

  if (e) {
    usb_close(&ws->pipe_tx);
    usb_close(&ws->pipe_rx);
    return e;
  }

  // Request initial packet.
  read_packet(ws->pipe_rx,ws);

  dev->status.ok = true;
  UNUSED(options);
  return NULL;
}

static _kernel_oserror* device_stop(net_device_t* dev)
{
  ws_t* ws = dev->private;
  unsigned long reg_data;
  _kernel_oserror* e;

  syslog("smsc95xx stop");

  if (!dev->gone) {
    /* Stop TX (TX_CFG) */
    if((e=reg_read(ws,
                   0x0010,
                   &reg_data)) != NULL) {
      return e;
      }
    reg_data|=0x00000002;
    if((e=reg_write(ws,
                    0x0010,
                    reg_data)) != NULL) {
      return e;
      }
    /* Stop RX (MAC_CR) */
    if((e=reg_read(ws,
                   0x0100,
                   &reg_data)) != NULL) {
      return e;
      }
    reg_data&=~0x00000004;
    if((e=reg_write(ws,
                    0x0100,
                    reg_data)) != NULL) {
      return e;
      }
    }
  /* RISC OS USB part */
  usb_close(&ws->pipe_tx);
  usb_close(&ws->pipe_rx);
  return NULL;
}

static _kernel_oserror* device_close(void** private)
{
  syslog("smsc95xx close");
  xfree(*private);
  return NULL;
}

/* Provides the driver functions for this kind of device.
   Must be declared here because all functions are known at here. */
static const net_backend_t s_backend = {
  .name        = N_SMSC95XX,
  .description = "DescSMC9",
  .open        = device_open,
  .start       = device_start,
  .stop        = device_stop,
  .close       = device_close,
  .transmit    = device_transmit,
  .info        = NULL,
  .config      = device_configure,
  .status      = device_status,
};

/* Registers device driver to general driver */
_kernel_oserror* smsc95xx_register(void)
{
  syslog("smsc95xx register");
  return net_register_backend(&s_backend);
}
