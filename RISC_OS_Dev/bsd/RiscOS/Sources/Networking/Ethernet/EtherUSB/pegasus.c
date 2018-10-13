/* EtherUSB
 * (C) James Peacock, 2009.
 *
 * Backend for ADMtek pegasus devices.
 */

/*
 * Copyright (c) 1997, 1998, 1999, 2000
 *	Bill Paul <wpaul@ee.columbia.edu>.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Bill Paul.
 * 4. Neither the name of the author nor the names of any co-contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY Bill Paul AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL Bill Paul OR THE VOICES IN HIS HEAD
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

/*
 * Ported to NetBSD and somewhat rewritten by Lennart Augustsson.
 */

/*
 * Ripped out of NetBSD and reworked for EtherUSB by Jeffrey Lee.
 */

/* todo:
 - add code for handling interrupt endpoint
 - set interface type from MII info?
 - disable promiscuous mode, sort out other transmission modes
 */

#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <time.h>

#include "backends.h"
#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "net.h"
#include "products.h"
#include "mii.h"
#include "swis.h"

#define DEBUG_PEGASUS 0

#if TX_PREFIX_SIZE<2
#error "Unable to build pegasus backend - edit module.h"
#endif

typedef struct
{
  usb_pipe_t      pipe_rx;
  usb_pipe_t      pipe_tx;
  net_device_t*   dev;
  mii_t           mii;
  int             mii_phy;
  /* Previous state of MII regs so we can detect changes */
  uint16_t        mii_control;
  uint16_t        mii_status;
  int             pegasus_flags;
#define LSYS 1 /* Use Linksys reset */
#define PNA 2 /* Has Home PNA (Note: Currently does nothing - all the PNA relevant code in the NetBSD driver was commented out) */
#define PII 4 /* Pegasus II chip */
} ws_t;

/* Utility functions borrowed from NetBSD driver and adapted to fit */

#define AUE_UR_READREG		0xF0
#define AUE_UR_WRITEREG		0xF1

#define AUE_CTL0		0x00
#define AUE_CTL1		0x01
#define AUE_CTL2		0x02
#define AUE_MAR0		0x08
#define AUE_MAR1		0x09
#define AUE_MAR2		0x0A
#define AUE_MAR3		0x0B
#define AUE_MAR4		0x0C
#define AUE_MAR5		0x0D
#define AUE_MAR6		0x0E
#define AUE_MAR7		0x0F
#define AUE_MAR			AUE_MAR0
#define AUE_PAR0		0x10
#define AUE_PAR1		0x11
#define AUE_PAR2		0x12
#define AUE_PAR3		0x13
#define AUE_PAR4		0x14
#define AUE_PAR5		0x15
#define AUE_PAR			AUE_PAR0
#define AUE_PAUSE0		0x18
#define AUE_PAUSE1		0x19
#define AUE_PAUSE		AUE_PAUSE0
#define AUE_RX_FLOWCTL_CNT	0x1A
#define AUE_RX_FLOWCTL_FIFO	0x1B
#define AUE_REG_1D		0x1D
#define AUE_EE_REG		0x20
#define AUE_EE_DATA0		0x21
#define AUE_EE_DATA1		0x22
#define AUE_EE_DATA		AUE_EE_DATA0
#define AUE_EE_CTL		0x23
#define AUE_PHY_ADDR		0x25
#define AUE_PHY_DATA0		0x26
#define AUE_PHY_DATA1		0x27
#define AUE_PHY_DATA		AUE_PHY_DATA0
#define AUE_PHY_CTL		0x28
#define AUE_USB_STS		0x2A
#define AUE_TXSTAT0		0x2B
#define AUE_TXSTAT1		0x2C
#define AUE_TXSTAT		AUE_TXSTAT0
#define AUE_RXSTAT		0x2D
#define AUE_PKTLOST0		0x2E
#define AUE_PKTLOST1		0x2F
#define AUE_PKTLOST		AUE_PKTLOST0

#define AUE_REG_7B		0x7B
#define AUE_GPIO0		0x7E
#define AUE_GPIO1		0x7F
#define AUE_REG_81		0x81

#define AUE_EECTL_WRITE		0x01
#define AUE_EECTL_READ		0x02
#define AUE_EECTL_DONE		0x04

#define AUE_CTL0_INCLUDE_RXCRC	0x01
#define AUE_CTL0_ALLMULTI	0x02
#define AUE_CTL0_STOP_BACKOFF	0x04
#define AUE_CTL0_RXSTAT_APPEND	0x08
#define AUE_CTL0_WAKEON_ENB	0x10
#define AUE_CTL0_RXPAUSE_ENB	0x20
#define AUE_CTL0_RX_ENB		0x40
#define AUE_CTL0_TX_ENB		0x80

#define AUE_CTL1_HOMELAN	0x04
#define AUE_CTL1_RESETMAC	0x08
#define AUE_CTL1_SPEEDSEL	0x10	/* 0 = 10mbps, 1 = 100mbps */
#define AUE_CTL1_DUPLEX		0x20	/* 0 = half, 1 = full */
#define AUE_CTL1_DELAYHOME	0x40

#define AUE_CTL2_EP3_CLR	0x01	/* reading EP3 clrs status regs */
#define AUE_CTL2_RX_BADFRAMES	0x02
#define AUE_CTL2_RX_PROMISC	0x04
#define AUE_CTL2_LOOPBACK	0x08
#define AUE_CTL2_EEPROMWR_ENB	0x10
#define AUE_CTL2_EEPROM_LOAD	0x20

#define AUE_PHYCTL_PHYREG	0x1F
#define AUE_PHYCTL_WRITE	0x20
#define AUE_PHYCTL_READ		0x40
#define AUE_PHYCTL_DONE		0x80

#define AUE_RXSTAT_MCAST	0x01
#define AUE_RXSTAT_GIANT	0x02
#define AUE_RXSTAT_RUNT		0x04
#define AUE_RXSTAT_CRCERR	0x08
#define AUE_RXSTAT_DRIBBLE	0x10
#define AUE_RXSTAT_MASK		0x1E

#define AUE_GPIO_IN0		0x01
#define AUE_GPIO_OUT0		0x02
#define AUE_GPIO_SEL0		0x04
#define AUE_GPIO_IN1		0x08
#define AUE_GPIO_OUT1		0x10
#define AUE_GPIO_SEL1		0x20

#define AUE_TIMEOUT		1000

static _kernel_oserror*
aue_csr_read_1(net_device_t *sc, int reg, int *val)
{
	*val=0;

	_kernel_oserror* err = usb_control(sc->name,USB_REQ_READ|USB_REQ_TP_VENDOR|USB_REQ_TO_DEVICE,AUE_UR_READREG,0,reg,1,val);

	if (err) {
		syslog("%s: aue_csr_read_1: reg=0x%x err=%s\n",
		    sc->name, reg, err->errmess);
	}

	return err;
}

static _kernel_oserror*
aue_csr_read_2(net_device_t *sc, int reg, int *val)
{
	*val=0;

	_kernel_oserror* err = usb_control(sc->name,USB_REQ_READ|USB_REQ_TP_VENDOR|USB_REQ_TO_DEVICE,AUE_UR_READREG,0,reg,2,val);

	if (err) {
		syslog("%s: aue_csr_read_2: reg=0x%x err=%s\n",
		    sc->name, reg, err->errmess);
	}

	return err;
}

static _kernel_oserror*
aue_csr_write_1(net_device_t *sc, int reg, int aval)
{
	int			val=aval;

	_kernel_oserror* err = usb_control(sc->name,USB_REQ_WRITE|USB_REQ_TP_VENDOR|USB_REQ_TO_DEVICE,AUE_UR_WRITEREG,aval,reg,1,&val);

	if (err) {
		syslog("%s: aue_csr_write_1: reg=0x%x err=%s\n",
		    sc->name, reg, err->errmess);
	}

	return err;
}

static _kernel_oserror*
aue_csr_write_2(net_device_t *sc, int reg, int aval)
{
	int			val=aval;

	_kernel_oserror* err = usb_control(sc->name,USB_REQ_WRITE|USB_REQ_TP_VENDOR|USB_REQ_TO_DEVICE,AUE_UR_WRITEREG,aval,reg,2,&val);

	if (err) {
		syslog("%s: aue_csr_write_2: reg=0x%x err=%s\n",
		    sc->name, reg, err->errmess);
	}

	return err;
}

static _kernel_oserror*
AUE_SETBIT(net_device_t *sc,int reg,int bit)
{
	int val=0;
	_kernel_oserror* e = aue_csr_read_1(sc,reg,&val);
	if(!e) e = aue_csr_write_1(sc,reg,val|bit);
	return e;
}

static _kernel_oserror*
AUE_CLRBIT(net_device_t *sc,int reg,int bit)
{
	int val=0;
	_kernel_oserror* e = aue_csr_read_1(sc,reg,&val);
	if(!e) e = aue_csr_write_1(sc,reg,val&~bit);
	return e;
}

/*
 * Read a word of data stored in the EEPROM at address 'addr.'
 */
static _kernel_oserror*
aue_eeprom_getword(net_device_t *sc, int addr,int *word)
{
	int		i;
	*word=0;

	aue_csr_write_1(sc, AUE_EE_REG, addr);
	aue_csr_write_1(sc, AUE_EE_CTL, AUE_EECTL_READ);

	for (i = 0; i < AUE_TIMEOUT; i++) {
		int val=0;
		_kernel_oserror *err = aue_csr_read_1(sc, AUE_EE_CTL, &val);
		if(err)
			return err;
		if (val & AUE_EECTL_DONE)
			break;
	}

	if (i == AUE_TIMEOUT) {
		syslog("%s: EEPROM read timed out\n",sc->name);
	}

	return (aue_csr_read_2(sc, AUE_EE_DATA, word));
}

/*
 * Read the MAC from the EEPROM.  It's at offset 0.
 */
static _kernel_oserror*
aue_read_mac(net_device_t *sc, uint8_t *dest)
{
	int			i;
	int			off = 0;
	int			word;

	for (i = 0; i < 3; i++) {
		_kernel_oserror *err = aue_eeprom_getword(sc, off + i, &word);
		if(err)
			return err;
		dest[2 * i] = (uint8_t)word;
		dest[2 * i + 1] = (uint8_t)(word >> 8);
	}
	return 0;
}

static _kernel_oserror*
aue_reset_pegasus_II(net_device_t *sc)
{
	_kernel_oserror *e;
	/* Magic constants taken from Linux driver. */
	e = aue_csr_write_1(sc, AUE_REG_1D, 0);
	if(!e) e = aue_csr_write_1(sc, AUE_REG_7B, 2);
	if(!e) e = aue_csr_write_1(sc, AUE_REG_81, 2);
	if(e) syslog("%s: aue_reset_pegasus_II: error %s\n",sc->name,e->errmess);
	return e;
}

static _kernel_oserror *
aue_reset(net_device_t *sc)
{
	int		i;

	syslog("%s: aue_reset: enter\n", sc->name);

	_kernel_oserror *e = AUE_SETBIT(sc,AUE_CTL1,AUE_CTL1_RESETMAC);
	if(e)
		return e;

	for (i = 0; i < AUE_TIMEOUT; i++) {
		int j=0;
		e = aue_csr_read_1(sc, AUE_CTL1, &j);
		if(e)
			return e;
		if (!(j & AUE_CTL1_RESETMAC))
			break;
	}

	if (i == AUE_TIMEOUT)
		syslog("%s: reset failed\n", sc->name);

	if(!e)
	{
	/*
	 * The PHY(s) attached to the Pegasus chip may be held
	 * in reset until we flip on the GPIO outputs. Make sure
	 * to set the GPIO pins high so that the PHY(s) will
	 * be enabled.
	 *
	 * Note: We force all of the GPIO pins low first, *then*
	 * enable the ones we want.
  	 */
	if (((ws_t *) sc->private)->pegasus_flags & LSYS) {
		/* Grrr. LinkSys has to be different from everyone else. */
		e = aue_csr_write_1(sc, AUE_GPIO0,
		    AUE_GPIO_SEL0 | AUE_GPIO_SEL1);
	} else {
		e = aue_csr_write_1(sc, AUE_GPIO0,
		    AUE_GPIO_OUT0 | AUE_GPIO_SEL0);
	}
	}
  	if(!e) e = aue_csr_write_1(sc, AUE_GPIO0,
	    AUE_GPIO_OUT0 | AUE_GPIO_SEL0 | AUE_GPIO_SEL1);

	if ((((ws_t *) sc->private)->pegasus_flags & PII) && (!e))
		e = aue_reset_pegasus_II(sc);

	if(e) syslog("%s: aue_reset: error %s\n",sc->name,e->errmess);

	/* Wait a little while for the chip to get its brains in order. */
//	delay(10000);		/* XXX */
	i = clock();
	while (clock()-i <= (CLOCKS_PER_SEC/100))
	{};
	return e;
}

static _kernel_oserror *
aue_setmulti(net_device_t *sc)
{
	syslog("%s: aue_setmulti: enter\n", sc->name);

#if 0
	_kernel_oserror *e = AUE_CLRBIT(sc, AUE_CTL0, AUE_CTL0_ALLMULTI);

	/* first, zot all the existing hash bits */
	for (int i = 0; i < 8; i++)
		if(!e) e = aue_csr_write_1(sc, AUE_MAR0 + i, 0);

#if 0
	/* now program new ones */
	ETHER_FIRST_MULTI(step, &sc->aue_ec, enm);
	while (enm != NULL) {
		if (memcmp(enm->enm_addrlo,
		    enm->enm_addrhi, ETHER_ADDR_LEN) != 0)
			goto allmulti;

		h = aue_crc(enm->enm_addrlo);
		AUE_SETBIT(sc, AUE_MAR + (h >> 3), 1 << (h & 0x7));
		ETHER_NEXT_MULTI(step, enm);
	}

	ifp->if_flags &= ~IFF_ALLMULTI;
#endif
#else
	// Set CTL0_ALLMULTI, because we work in promiscuous mode?
	_kernel_oserror *e = AUE_SETBIT(sc, AUE_CTL0, AUE_CTL0_ALLMULTI);
#endif
	if(e) syslog("%s: aue_setmulti: error %s\n",sc->name,e->errmess);
	return e;
}

static void read_packet(usb_pipe_t pipe, void* dev_pw)
{
  ws_t* ws = dev_pw;
  char blk[2048];
  size_t size = sizeof(blk);
  _kernel_oserror* e = usb_read(ws->pipe_rx, blk, &size);
#if DEBUG_PEGASUS
  syslog("read_packet: err %08x len %d RXSTAT %02x\n",(int) e,size,blk[size-2]);
#endif
  if (!e && size>4)
  {
    // last 4 bytes will be uWord packet length, uByte RXSTAT uByte ???
    // Check RXSTAT for errors, ignore length
    if(blk[size-2] & AUE_RXSTAT_MASK)
      ++ws->dev->packet_rx_errors;
    else
      net_receive(ws->dev, blk, size - 4, 0);
  }
  usb_start_read(ws->pipe_rx);
}

static void write_packet(usb_pipe_t pipe, void* dev_pw)
{
  ws_t* ws = dev_pw;
  net_attempt_transmit(ws->dev);
}

//---------------------------------------------------------------------------
// Reads a MII register from the device's PHY.
//---------------------------------------------------------------------------
static _kernel_oserror* pegasus_phy_read(void* handle, unsigned reg_no, uint16_t *value)
{
  ws_t* ws = handle;
  int i;
  int phy = ws->mii_phy;

  _kernel_oserror *e;

  e = aue_csr_write_1(ws->dev, AUE_PHY_ADDR, phy);
  if(!e) e = aue_csr_write_1(ws->dev, AUE_PHY_CTL, reg_no | AUE_PHYCTL_READ);

  for (i = 0; i < AUE_TIMEOUT; i++) {
    int j=0;
    if(!e) e = aue_csr_read_1(ws->dev,AUE_PHY_CTL,&j);
    if(!e && (j & AUE_PHYCTL_DONE))
      break;
  }

  if (i == AUE_TIMEOUT) {
    syslog("%s: MII read timed out\n", ws->dev->name);
  }

  int val = 0;
  if(!e) e = aue_csr_read_2(ws->dev, AUE_PHY_DATA,&val);
  if(e)
  {
    syslog("%s: MII read failed, reg=%d, err=%s\n",ws->dev->name,reg_no,e->errmess);
  }
  *value = val;
  return e;
}

//---------------------------------------------------------------------------
// Writes a MII register value to the device's PHY.
//---------------------------------------------------------------------------
static _kernel_oserror* pegasus_phy_write(void* handle, unsigned reg_no, uint16_t val)
{
  ws_t* ws = handle;
  int phy=ws->mii_phy;
  int i;

  _kernel_oserror *e;

  e = aue_csr_write_2(ws->dev, AUE_PHY_DATA, val);
  if(!e) e = aue_csr_write_1(ws->dev,AUE_PHY_ADDR, phy);
  if(!e) e = aue_csr_write_1(ws->dev,AUE_PHY_CTL, reg_no | AUE_PHYCTL_WRITE);

  for (i = 0; i < AUE_TIMEOUT; i++) {
    int j=0;
    if(!e) e = aue_csr_read_1(ws->dev,AUE_PHY_CTL,&j);
    if(!e && (j & AUE_PHYCTL_DONE))
      break;
  }

  if (i == AUE_TIMEOUT) {
    syslog("%s: MII write timed out\n", ws->dev->name);
  }

  if(e)
  {
    syslog("%s: MII write failed, reg=%d, err=%s\n",ws->dev->name,reg_no,e->errmess);
  }
  return e;
}

//---------------------------------------------------------------------------
// Reads various bits of state info
//---------------------------------------------------------------------------

static _kernel_oserror* device_status(net_device_t* dev)
{
  ws_t* ws = dev->private;

  // We current run in promiscuous mode
  dev->status.promiscuous = true;
  _kernel_oserror *e = mii_link_status(&ws->mii, &dev->status);

  uint16_t control;
  if(!e && !pegasus_phy_read(ws,MII_CONTROL,&control))
  {
    // Update duplex state in controller
    // we do this whenever MII_CONTROL changes, because we can't be certain
    // the controller is in the right state to start with
    if(control != ws->mii_control)
    {
      syslog("mii control %04x -> %04x\n",ws->mii_control,control);
      ws->mii_control = control;
      AUE_CLRBIT(dev, AUE_CTL0, AUE_CTL0_RX_ENB | AUE_CTL0_TX_ENB);

      if(control & MII_CONTROL_FULL_DUPLEX)
        AUE_SETBIT(dev,AUE_CTL1,AUE_CTL1_DUPLEX);
      else
        AUE_CLRBIT(dev,AUE_CTL1,AUE_CTL1_DUPLEX);
      if(control & MII_CONTROL_SPEED100)
        AUE_SETBIT(dev,AUE_CTL1,AUE_CTL1_SPEEDSEL);
      else
        AUE_CLRBIT(dev,AUE_CTL1,AUE_CTL1_SPEEDSEL);

      AUE_SETBIT(dev, AUE_CTL0, AUE_CTL0_RX_ENB | AUE_CTL0_TX_ENB);

	/*
	 * Set the LED modes on the LinkSys adapter.
	 * This turns on the 'dual link LED' bin in the auxmode
	 * register of the Broadcom PHY.
	 */
	if (ws->pegasus_flags & LSYS) {
		uint16_t auxmode;
		int oldphy = ws->mii_phy; /* We need to temporarily talk to PHY 0, remember the old PHY */
		ws->mii_phy = 0;
		if(!pegasus_phy_read(dev,0x1b,&auxmode))
			pegasus_phy_write(dev,0x1b, auxmode | 0x04);
		ws->mii_phy = oldphy;
	}
    }
  }

//  static int oldstat = 0;
//  if((status != oldstat) || e)
//    syslog("read_state: status %x err %s\n",status,(e?e->errmess:""));
//  oldstat = status;

  dev->status.polarity_incorrect = false;
  return e;
}

static _kernel_oserror* device_configure(net_device_t* dev,
                                         const net_config_t* cfg)
{
  ws_t* ws = dev->private;
  _kernel_oserror* e = mii_configure(&ws->mii, &dev->status, cfg);
  if (e)
  {
    return e;
  }
  /* Update status */
  return device_status(dev);
}


static _kernel_oserror* device_transmit(net_device_t*   dev,
                                        const net_tx_t* pkt)
{
  ws_t* ws = dev->private;
  int32_t start_time, time_now;
  
  _swix(OS_ReadMonotonicTime, _OUT(0), &start_time);
  
  while (usb_buffer_used(ws->pipe_tx)!=0)
  {
    // USB buffer should empty quickly if it doesn't something is wrong.
    _swix(OS_ReadMonotonicTime, _OUT(0), &time_now);
    if (time_now - start_time > 10) return err_translate(ERR_TX_BLOCKED);
  }
  
  uint8_t* base = (void*)&pkt->header;
  *--base = (pkt->size >> 8) & 0xff;
  *--base = pkt->size & 0xff;
  size_t to_write = pkt->size + 2;
#if DEBUG_PEGASUS
  syslog("device_transmit: %d bytes\n",to_write);
  _kernel_oserror *e = usb_write(ws->pipe_tx, base, &to_write);
  syslog("device_transmit: to_write=%d err=%08x\n",to_write,(int) e);
#else
  usb_write(ws->pipe_tx, base, &to_write);
#endif
  return (to_write==0) ? err_translate(ERR_TX_BLOCKED) : NULL;
}

static _kernel_oserror* device_open(const USBServiceCall* dev,
                                    const char*           options,
                                    void**                private)
{
  if (!options) return err_translate(ERR_UNSUPPORTED);

  ws_t* ws = xalloc(sizeof(ws_t));
  if (!ws) return err_translate(ERR_NO_MEMORY);

  ws->pipe_rx    = 0;
  ws->pipe_tx    = 0;
  ws->dev        = NULL;
  ws->mii_control = ws->mii_status = 0xffff;

  mii_initialise(&ws->mii, pegasus_phy_read, pegasus_phy_write, ws);

  /* Parse options */
  ws->pegasus_flags = 0;
  if(strstr(options,"LSYS"))
    ws->pegasus_flags |= LSYS;
  if(strstr(options,"PNA"))
    ws->pegasus_flags |= PNA;
  if(strstr(options,"PII"))
    ws->pegasus_flags |= PII;

  *private = ws;
  return NULL;
}

static _kernel_oserror* device_start(net_device_t* dev, const char* options)
{
  ws_t* ws = dev->private;
  ws->dev  = dev;

  _kernel_oserror* e = usb_set_config(dev->name, 1);

  dev->dib.dib_inquire |= ( INQ_HWADDRVALID |
                            INQ_MULTICAST |
                            INQ_PROMISCUOUS );

  if (!e) e = aue_reset(dev);

  // Read default MAC address from EEPROM
  if (!e) e = aue_read_mac(dev,dev->status.mac);

  // Program MAC address
  for(int i=0;i<ETHER_ADDR_LEN;i++)
    if (!e) e = aue_csr_write_1(dev, AUE_PAR0 + i, dev->status.mac[i]);

  // enable promiscuous mode
  if(!e) e = AUE_SETBIT(dev, AUE_CTL2, AUE_CTL2_RX_PROMISC);

  // reset multicast filter
  if(!e) e = aue_setmulti(dev);

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

  // Hunt for the correct phy
  if (e)
  {
    syslog("%s: error %s before MII init\n",dev->name,e->errmess);
  }
  else
  {
    for(ws->mii_phy=0;ws->mii_phy<256;ws->mii_phy++)
    {
      uint16_t val=0xffff;
      e = pegasus_phy_read(ws,MII_STATUS,&val);
      if (e)
        syslog("%s: error %s from MII PHY %d\n",dev->name,e->errmess,ws->mii_phy);
      else
      {
        syslog("%s: MII PHY %d status = %04x\n",dev->name,ws->mii_phy,val);
        if((val != 0xffff) && (val != 0))
          break;
      }
    }
  }

  // Start interface
  if (!e) e = mii_reset(&ws->mii);
  if (!e) e = mii_abilities(&ws->mii, &dev->abilities);

  // Enable RX & TX
  if (!e) e = aue_csr_write_1(dev,AUE_CTL0,AUE_CTL0_RXSTAT_APPEND | AUE_CTL0_RX_ENB);
  if (!e) e = AUE_SETBIT(dev, AUE_CTL0, AUE_CTL0_TX_ENB);
  if (!e) e = AUE_SETBIT(dev, AUE_CTL2, AUE_CTL2_EP3_CLR);

  if (e)
  {
    usb_close(&ws->pipe_tx);
    usb_close(&ws->pipe_rx);
    return e;
  }

  read_packet(ws->pipe_rx,ws);

  dev->status.ok = true;
  dev->status.up = false;
  dev->status.duplex = net_duplex_full;

  return NULL;
}

//---------------------------------------------------------------------------
// Shutdown device. Note, if the device was disconnected, dev->gone is true.
//---------------------------------------------------------------------------
static _kernel_oserror* device_stop(net_device_t* dev)
{
  ws_t* ws = dev->private;

  if (!dev->gone)
  {
    // Powerdown and isolate PHY
    mii_shutdown(&ws->mii);
  }
  usb_close(&ws->pipe_tx);
  usb_close(&ws->pipe_rx);
  return NULL;
}

//---------------------------------------------------------------------------
// Removing device, free any resources.
//---------------------------------------------------------------------------
static _kernel_oserror* device_close(void** private)
{
  xfree(*private);
  return NULL;
}

//---------------------------------------------------------------------------
// Backend description
//---------------------------------------------------------------------------
static const net_backend_t s_backend = {
  .name        = N_PEGASUS,
  .description = "DescPeg",
  .open        = device_open,
  .start       = device_start,
  .stop        = device_stop,
  .close       = device_close,
  .transmit    = device_transmit,
  .info        = NULL,
  .config      = device_configure,
  .status      = device_status,
};

//---------------------------------------------------------------------------
// Called during module initialisation.
//---------------------------------------------------------------------------
_kernel_oserror* pegasus_register(void)
{
  return net_register_backend(&s_backend);
}
