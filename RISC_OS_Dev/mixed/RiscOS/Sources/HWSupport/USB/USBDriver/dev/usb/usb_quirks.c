/*	$NetBSD: usb_quirks.c,v 1.81 2014/09/12 16:40:38 skrll Exp $	*/
/*	$FreeBSD: src/sys/dev/usb/usb_quirks.c,v 1.30 2003/01/02 04:15:55 imp Exp $	*/

/*
 * Copyright (c) 1998, 2004 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Lennart Augustsson (lennart@augustsson.net) at
 * Carlstedt Research & Technology.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <sys/cdefs.h>
#ifndef __riscos
__KERNEL_RCSID(0, "$NetBSD: usb_quirks.c,v 1.81 2014/09/12 16:40:38 skrll Exp $");

#ifdef _KERNEL_OPT
#include "opt_usb.h"
#endif
#endif

#include <sys/param.h>
#include <sys/systm.h>

#include <dev/usb/usb.h>
#include <dev/usb/usbdevs.h>
#include <dev/usb/usb_quirks.h>

#ifdef USB_DEBUG
extern int usbdebug;
#endif

#define ANY 0xffff

#ifdef __riscos
void *extra_quirks; /* Quirk list added to at runtime */
static const struct usbd_quirks *
usbd_find_builtin_quirk(usb_device_descriptor_t *, const struct usbd_quirk_entry *);

Static const struct usbd_quirk_entry  usb_quirks[] = {
#else
Static const struct usbd_quirk_entry {
	u_int16_t idVendor;
	u_int16_t idProduct;
	u_int16_t bcdDevice;
	struct usbd_quirks quirks;
} usb_quirks[] = {
#endif
 /* Devices which should be ignored by uhid */
 { USB_VENDOR_APC, USB_PRODUCT_APC_UPS,		    ANY,   { UQ_HID_IGNORE }},
 { USB_VENDOR_CYBERPOWER, USB_PRODUCT_CYBERPOWER_UPS, ANY, { UQ_HID_IGNORE }},
 { USB_VENDOR_MGE, USB_PRODUCT_MGE_UPS1,	    ANY,   { UQ_HID_IGNORE }},
 { USB_VENDOR_MGE, USB_PRODUCT_MGE_UPS2,	    ANY,   { UQ_HID_IGNORE }},
 { USB_VENDOR_MICROCHIP,  USB_PRODUCT_MICROCHIP_PICKIT1,
	ANY,	{ UQ_HID_IGNORE }},
 { USB_VENDOR_TRIPPLITE2, ANY,			    ANY,   { UQ_HID_IGNORE }},
 { USB_VENDOR_MISC, USB_PRODUCT_MISC_WISPY_24X, ANY, { UQ_HID_IGNORE }},
 { USB_VENDOR_WELTREND, USB_PRODUCT_WELTREND_HID,   ANY,   { UQ_HID_IGNORE }},

 { USB_VENDOR_KYE, USB_PRODUCT_KYE_NICHE,	    0x100, { UQ_NO_SET_PROTO}},
 { USB_VENDOR_INSIDEOUT, USB_PRODUCT_INSIDEOUT_EDGEPORT4,
   						    0x094, { UQ_SWAP_UNICODE}},
 { USB_VENDOR_DALLAS, USB_PRODUCT_DALLAS_J6502,	    0x0a2, { UQ_BAD_ADC }},
 { USB_VENDOR_DALLAS, USB_PRODUCT_DALLAS_J6502,	    0x0a2, { UQ_AU_NO_XU }},
 { USB_VENDOR_ALTEC, USB_PRODUCT_ALTEC_ADA70,	    0x103, { UQ_BAD_ADC }},
 { USB_VENDOR_ALTEC, USB_PRODUCT_ALTEC_ASC495,      0x000, { UQ_BAD_AUDIO }},
 { USB_VENDOR_SONY, USB_PRODUCT_SONY_PS2EYETOY4,    0x000, { UQ_BAD_AUDIO }},
 { USB_VENDOR_SONY, USB_PRODUCT_SONY_PS2EYETOY5,    0x000, { UQ_BAD_AUDIO }},
 { USB_VENDOR_PHILIPS, USB_PRODUCT_PHILIPS_PCVC740K,  ANY, { UQ_BAD_AUDIO }},
 { USB_VENDOR_LOGITECH, USB_PRODUCT_LOGITECH_QUICKCAMPRONB,
	0x000, { UQ_BAD_AUDIO }},
 { USB_VENDOR_LOGITECH, USB_PRODUCT_LOGITECH_QUICKCAMPRO4K,
	0x000, { UQ_BAD_AUDIO }},
 { USB_VENDOR_LOGITECH, USB_PRODUCT_LOGITECH_QUICKCAMMESS,
	0x100, { UQ_BAD_ADC }},
 { USB_VENDOR_QTRONIX, USB_PRODUCT_QTRONIX_980N,    0x110, { UQ_SPUR_BUT_UP }},
 { USB_VENDOR_ALCOR2, USB_PRODUCT_ALCOR2_KBD_HUB,   0x001, { UQ_SPUR_BUT_UP }},
 { USB_VENDOR_METRICOM, USB_PRODUCT_METRICOM_RICOCHET_GS,
 	0x100, { UQ_ASSUME_CM_OVER_DATA }},
 { USB_VENDOR_SANYO, USB_PRODUCT_SANYO_SCP4900,
 	0x000, { UQ_ASSUME_CM_OVER_DATA }},
 { USB_VENDOR_MOTOROLA2, USB_PRODUCT_MOTOROLA2_T720C,
 	0x001, { UQ_ASSUME_CM_OVER_DATA }},
 { USB_VENDOR_EICON, USB_PRODUCT_EICON_DIVA852,
        0x100, { UQ_ASSUME_CM_OVER_DATA }},
 { USB_VENDOR_SIEMENS2, USB_PRODUCT_SIEMENS2_MC75,
        0x000, { UQ_ASSUME_CM_OVER_DATA }},
 { USB_VENDOR_TELEX, USB_PRODUCT_TELEX_MIC1,	    0x009, { UQ_AU_NO_FRAC }},
 { USB_VENDOR_SILICONPORTALS, USB_PRODUCT_SILICONPORTALS_YAPPHONE,
   						    0x100, { UQ_AU_INP_ASYNC }},
 { USB_VENDOR_AVANCELOGIC, USB_PRODUCT_AVANCELOGIC_USBAUDIO,
   						    0x101, { UQ_AU_INP_ASYNC }},
 { USB_VENDOR_PLANTRONICS, USB_PRODUCT_PLANTRONICS_HEADSET,
   						    0x004, { UQ_AU_INP_ASYNC }},
 /* XXX These should have a revision number, but I don't know what they are. */
 { USB_VENDOR_HP, USB_PRODUCT_HP_895C,		    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_HP, USB_PRODUCT_HP_880C,		    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_HP, USB_PRODUCT_HP_815C,		    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_HP, USB_PRODUCT_HP_810C,		    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_HP, USB_PRODUCT_HP_830C,		    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_HP, USB_PRODUCT_HP_885C,		    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_HP, USB_PRODUCT_HP_840C,		    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_HP, USB_PRODUCT_HP_816C,		    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_HP, USB_PRODUCT_HP_959C,		    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_MTK, USB_PRODUCT_MTK_GPS_RECEIVER,    ANY,   { UQ_NO_UNION_NRM }},
 { USB_VENDOR_NEC, USB_PRODUCT_NEC_PICTY900,	    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_NEC, USB_PRODUCT_NEC_PICTY760,	    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_NEC, USB_PRODUCT_NEC_PICTY920,	    ANY,   { UQ_BROKEN_BIDIR }},
 { USB_VENDOR_NEC, USB_PRODUCT_NEC_PICTY800,	    ANY,   { UQ_BROKEN_BIDIR }},

 { USB_VENDOR_HP, USB_PRODUCT_HP_1220C,		    ANY,   { UQ_BROKEN_BIDIR }},

#ifndef __riscos
 /* Apple internal notebook ISO keyboards have swapped keys */
 { USB_VENDOR_APPLE, USB_PRODUCT_APPLE_FOUNTAIN_ISO,
	ANY, { UQ_APPLE_ISO }},
 { USB_VENDOR_APPLE, USB_PRODUCT_APPLE_GEYSER_ISO,
	ANY, { UQ_APPLE_ISO }},
#endif

 /* HID and audio are both invalid on iPhone/iPod Touch */
 { USB_VENDOR_APPLE, USB_PRODUCT_APPLE_IPHONE,
	ANY, { UQ_HID_IGNORE | UQ_BAD_AUDIO }},
 { USB_VENDOR_APPLE, USB_PRODUCT_APPLE_IPOD_TOUCH,
	ANY, { UQ_HID_IGNORE | UQ_BAD_AUDIO }},
 { USB_VENDOR_APPLE, USB_PRODUCT_APPLE_IPOD_TOUCH_4G,
	ANY, { UQ_HID_IGNORE | UQ_BAD_AUDIO }},
 { USB_VENDOR_APPLE, USB_PRODUCT_APPLE_IPHONE_3G,
	ANY, { UQ_HID_IGNORE | UQ_BAD_AUDIO }},
 { USB_VENDOR_APPLE, USB_PRODUCT_APPLE_IPHONE_3GS,
	ANY, { UQ_HID_IGNORE | UQ_BAD_AUDIO }},

 { USB_VENDOR_QUALCOMM, USB_PRODUCT_QUALCOMM_CDMA_MSM,
	ANY, { UQ_ASSUME_CM_OVER_DATA }},
 { USB_VENDOR_QUALCOMM2, USB_PRODUCT_QUALCOMM2_CDMA_MSM,
	ANY, { UQ_ASSUME_CM_OVER_DATA }},
 { USB_VENDOR_HYUNDAI, USB_PRODUCT_HYUNDAI_UM175,
	ANY, { UQ_ASSUME_CM_OVER_DATA }},
 { USB_VENDOR_ZOOM, USB_PRODUCT_ZOOM_3095,
	ANY, { UQ_LOST_CS_DESC }},
#ifdef __riscos
 /* The power quirks have been obsoleted by NetBSD (see usb_quirks.c revision 1.55) */
 { USB_VENDOR_TI, USB_PRODUCT_TI_UTUSB41,	    0x110, { UQ_POWER_CLAIM }},
 { USB_VENDOR_NEC, USB_PRODUCT_NEC2_HUB2_0,	    0x100, { UQ_POWER_CLAIM }},
 { USB_VENDOR_MCT, USB_PRODUCT_MCT_HUB0100,         0x102, { UQ_BUS_POWERED }},
 { USB_VENDOR_MCT, USB_PRODUCT_MCT_USB232,          0x102, { UQ_BUS_POWERED }},
 { USB_VENDOR_OLYMPUS, USB_PRODUCT_OLYMPUS_C700,    ANY,   { UQ_BUS_POWERED }},

 /* The strings quirk has been obsoleted by NetBSD (see usb_quirks.c revision 1.50) */
 { USB_VENDOR_BTC, USB_PRODUCT_BTC_BTC7932,	    0x100, { UQ_NO_STRINGS }},
 { USB_VENDOR_ADS, USB_PRODUCT_ADS_UBS10BT,	    0x002, { UQ_NO_STRINGS }},
 { USB_VENDOR_PERACOM, USB_PRODUCT_PERACOM_SERIAL1, 0x101, { UQ_NO_STRINGS }},
 { USB_VENDOR_WACOM, USB_PRODUCT_WACOM_CT0405U,     0x101, { UQ_NO_STRINGS }},
 { USB_VENDOR_ACERP, USB_PRODUCT_ACERP_ACERSCAN_320U,
						    0x000, { UQ_NO_STRINGS }},
#endif
 { 0, 0, 0, { 0 } }
};

const struct usbd_quirks usbd_no_quirk = { 0 };

const struct usbd_quirks *
usbd_find_quirk(usb_device_descriptor_t *d)
{
#ifdef __riscos
	const struct usbd_quirks *q;
	if (extra_quirks) {
		q = usbd_find_builtin_quirk(d, extra_quirks);
		if (q) return q;
	}
	return usbd_find_builtin_quirk(d, usb_quirks); /* Try as a builtin one */
}

static const struct usbd_quirks *
usbd_find_builtin_quirk(usb_device_descriptor_t *d, const struct usbd_quirk_entry *t)
{
#else
	const struct usbd_quirk_entry *t;
#endif
	u_int16_t vendor = UGETW(d->idVendor);
	u_int16_t product = UGETW(d->idProduct);
	u_int16_t revision = UGETW(d->bcdDevice);

#ifdef __riscos
	for (; t->idVendor != 0; t++) {
#else
	for (t = usb_quirks; t->idVendor != 0; t++) {
#endif
		if (t->idVendor  == vendor &&
		    (t->idProduct == ANY || t->idProduct == product) &&
		    (t->bcdDevice == ANY || t->bcdDevice == revision))
			break;
	}
#ifdef USB_DEBUG
	if (usbdebug && t->quirks.uq_flags)
		printf("usbd_find_quirk 0x%04x/0x%04x/%x: %d\n",
			  UGETW(d->idVendor), UGETW(d->idProduct),
			  UGETW(d->bcdDevice), t->quirks.uq_flags);
#endif
	return (&t->quirks);
}
