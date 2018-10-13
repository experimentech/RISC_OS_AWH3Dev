/*****************************************************************************
* $Id: umass_quirks,v 1.3 2011-07-24 22:09:38 jlee Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): 
*
* ----------------------------------------------------------------------------
* Purpose: USB mass storage quirks header file, adapted from BSD sources
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/

/*	$NetBSD: umass_quirks.h,v 1.3.4.1 2002/01/10 19:59:01 thorpej Exp $	*/

/*
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by MAEKAWA Masahide (gehenna@NetBSD.org).
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
 *	  This product includes software developed by the NetBSD
 *	  Foundation, Inc. and its contributors.
 * 4. Neither the name of The NetBSD Foundation nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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


#ifndef _DEV_USB_UMASS_QUIRKS_H_
#define _DEV_USB_UMASS_QUIRKS_H_

#ifdef __riscos /* dunno where these are really defined, but they're just flag bits */
#define PQUIRK_NOMODESENSE    0x01
#define PQUIRK_NOTUR          0x02
#define PQUIRK_NOSENSE        0x04
#define PQUIRK_NODOORLOCK     0x08
#define PQUIRK_NOBIGMODESENSE 0x10
#define PQUIRK_FORCELUNS      0x20
#endif

typedef usbd_status (*umass_init_quirk)(struct umass_softc *);
typedef void (*umass_fixup_quirk)(struct umass_softc *);

//#ifdef __riscos
//struct usb_devno {
//	u_int16_t		vendor;
//	u_int16_t		product;
//};
//#endif

struct umass_quirk {
	struct usb_devno	uq_dev;

	u_int8_t		uq_wire;
	u_int8_t		uq_cmd;
	u_int32_t		uq_flags;
	u_int32_t		uq_busquirks;
	int			uq_match;

	umass_init_quirk	uq_init;
	umass_fixup_quirk	uq_fixup;
};

const struct umass_quirk *umass_lookup(u_int16_t, u_int16_t);

#endif /* _DEV_USB_UMASS_QUIRKS_H_ */
