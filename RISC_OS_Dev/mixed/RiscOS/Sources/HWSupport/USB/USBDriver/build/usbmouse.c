/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */

/*
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
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

/* mouse interface */
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "Global/RISCOS.h"
#include "Global/Keyboard.h"
#include "Global/Pointer.h"
#include "Global/VduExt.h"

#include "USBDriverHdr.h"
#include "swis.h"
#include "debuglib/debuglib.h"
#include "callx/callx.h"

#include <sys/callout.h>
#include <sys/ioctl.h>

#include "dev/usb/usb.h"
#include "dev/usb/usbhid.h"

#include "dev/usb/usbdi.h"
#include "dev/usb/usbdi_util.h"
#include "dev/usb/usbdivar.h"
#include <dev/usb/usbdevs.h>
#include <dev/usb/usb_quirks.h>
#include <dev/usb/hid.h>

#ifndef __riscos
#include <dev/wscons/wsconsio.h>
#include <dev/wscons/wsmousevar.h>
#endif

#include "usbmouse.h"

#include "wimplib.h"

#ifdef __riscos
#define printf logprintf
#define aprint_verbose logprintf
#define aprint_normal logprintf
#define aprint_error logprintf
#endif

#ifdef USB_DEBUG
#define DPRINTF(x)	if (umsdebug) logprintf x
#define DPRINTFN(n,x)	if (umsdebug>(n)) logprintf x
int	umsdebug = 10;
#else
#define DPRINTF(x)
#define DPRINTFN(n,x)
#endif

#ifdef __riscos
#define UMS_BUT(i) (i)
#else
#define UMS_BUT(i) ((i) == 1 || (i) == 2 ? 3 - (i) : i)
#endif

extern void ums_enable (void*);
extern void ums_disable (void*);

extern struct messages mod_messages;

extern struct cfattach ums_ca;

static int relx = 0, rely = 0, relz = 0, relw = 0, morebuttons = 0;
static bool enabled = false;

void ums_intr (usbd_xfer_handle xfer, usbd_private_handle addr, usbd_status status);

static int uhidev_maxrepid(void *buf, int len);

#define MAX_BUTTONS	31	/* must not exceed size of sc_buttons */

struct tsscale {
	int minx, maxx;
	int miny, maxy;
};

struct ums_softc {
	USBBASEDEVICE sc_dev;		/* base device */
	usbd_device_handle sc_udev;
	usbd_interface_handle sc_iface; /* interface */
	usbd_pipe_handle sc_intrpipe;	/* interrupt pipe */
	int sc_ep_addr;

	u_char *sc_ibuf;
	u_int8_t sc_iid;
	int sc_isize;
	struct hid_location sc_loc_x, sc_loc_y, sc_loc_z, sc_loc_w;
	struct hid_location *sc_loc_btn;
	struct tsscale sc_tsscale;

	int sc_enabled;

	int flags;		/* device configuration */
#define UMS_Z		0x01	/* z direction available */
#define UMS_SPUR_BUT_UP	0x02	/* spurious button up events */
#define UMS_REVZ	0x04	/* Z-axis is reversed */
#define UMS_W		0x08	/* w direction/tilt available */
#define UMS_ABS		0x10	/* absolute position, touchpanel */

	int nbuttons;

	u_int32_t sc_buttons;	/* mouse button status */

	char			sc_dying;

	/* list of ukbd softcs */
	TAILQ_ENTRY(ums_softc) link_ms;
};

#define MOUSE_FLAGS_MASK (HIO_CONST|HIO_RELATIVE)

TAILQ_HEAD(umslist, ums_softc) allums = TAILQ_HEAD_INITIALIZER(allums);

extern void remove_all_mice (void)
{
	struct ums_softc* sc;
	TAILQ_FOREACH(sc, &allums, link_ms)
	{
		detach_mouse ((struct device*) sc);
	}
}

static int match_mouse (struct usb_attach_arg *uaa)
{
	usb_interface_descriptor_t *id;
	int size, ret, nrepid, repid;
	void *desc;
	usbd_status err;

	dprintf (("", "Trying ums attach\n"));
	if (uaa->iface == NULL)
		return (UMATCH_NONE);
	id = usbd_get_interface_descriptor(uaa->iface);
	if (id == NULL || id->bInterfaceClass != UICLASS_HID)
	{
		dprintf (("", "failed class match: id == %p\n", id));
		return (UMATCH_NONE);
	}

	/*
	 * Some (older) Griffin PowerMate knobs may masquerade as a
	 * mouse, avoid treating them as such, they have only one axis.
	 */
	if (uaa->vendor == USB_VENDOR_GRIFFIN &&
	    uaa->product == USB_PRODUCT_GRIFFIN_POWERMATE)
		return (UMATCH_NONE);

	err = usbd_read_report_desc(uaa->iface, &desc, &size, M_USBDEV);
	if (err)
	{
		dprintf (("", "failed to get report\n"));
		return (UMATCH_NONE);
	}

	nrepid = uhidev_maxrepid(desc, size);
	

	ret = UMATCH_NONE;
	for (repid = 0; repid <= nrepid; repid++)
	{
		if ((hid_is_collection(desc, size, repid,
			HID_USAGE2(HUP_GENERIC_DESKTOP, HUG_MOUSE)))
		 || (hid_is_collection(desc, size, repid,
			HID_USAGE2(HUP_GENERIC_DESKTOP, HUG_POINTER))))
		{
			ret = UMATCH_IFACECLASS;
		}
	}


	free(desc);
	dprintf (("", "ums attach returning: %d\n", ret));
	return (ret);
}

/* Report descriptor for a mouse in boot protocol mode, from the USB HID spec */
static const char boot_descriptor[] =
{
	0x05, 0x01,
	0x09, 0x02,
	0xa1, 0x01,
	0x09, 0x01,
	0xa1, 0x00,
	0x05, 0x09,
	0x19, 0x01,
	0x29, 0x03,
	0x15, 0x00,
	0x25, 0x01,
	0x95, 0x03,
	0x75, 0x01,
	0x81, 0x02,
	0x95, 0x01,
	0x75, 0x05,
	0x81, 0x01,
	0x05, 0x01,
	0x09, 0x30,
	0x09, 0x31,
	0x15, 0x81,
	0x25, 0x7f,
	0x75, 0x08,
	0x95, 0x02,
	0x81, 0x06,
	0xc0,
	0xc0
};

static void do_attach_mouse (struct ums_softc* sc, struct usb_attach_arg *uaa)
{
	usbd_interface_handle iface = uaa->iface;
	usb_interface_descriptor_t *id;
	usb_endpoint_descriptor_t *ed;
	int size;
	void *desc;
	usbd_status err;
#ifdef USB_DEBUG
	char devinfo[1024];
#endif
	u_int32_t flags, quirks;
	int i, repid, nrepid;
	int hl;
	struct hid_location *zloc;
	struct hid_location loc_btn;

	sc->sc_udev = uaa->device;
	sc->sc_iface = iface;
	id = usbd_get_interface_descriptor(iface);
#ifdef USB_DEBUG
	usbd_devinfo(uaa->device, 0, devinfo, sizeof devinfo);
	USB_ATTACH_SETUP;
	dprintf(("%s: %s, iclass %d/%d\n", USBDEVNAME(sc->sc_dev),
	       devinfo, id->bInterfaceClass, id->bInterfaceSubClass));
#endif
	ed = usbd_interface2endpoint_descriptor(iface, 0);
	if (ed == NULL) {
		logprintf("%s: could not read endpoint descriptor\n",
		       USBDEVNAME(sc->sc_dev));
		USB_ATTACH_ERROR_RETURN;
	}

	dprintf(("", "ums_attach: bLength=%d bDescriptorType=%d "
		     "bEndpointAddress=%d-%s bmAttributes=%d wMaxPacketSize=%d"
		     " bInterval=%d\n",
		     ed->bLength, ed->bDescriptorType,
		     ed->bEndpointAddress & UE_ADDR,
		     UE_GET_DIR(ed->bEndpointAddress)==UE_DIR_IN? "in" : "out",
		     ed->bmAttributes & UE_XFERTYPE,
		     UGETW(ed->wMaxPacketSize), ed->bInterval));

	if (UE_GET_DIR(ed->bEndpointAddress) != UE_DIR_IN ||
	    (ed->bmAttributes & UE_XFERTYPE) != UE_INTERRUPT) {
		logprintf("%s: unexpected endpoint\n",
		       USBDEVNAME(sc->sc_dev));
		USB_ATTACH_ERROR_RETURN;
	}

	quirks = usbd_get_quirks(uaa->device)->uq_flags;
	if (quirks & UQ_MS_REVZ)
		sc->flags |= UMS_REVZ;
	if (quirks & UQ_SPUR_BUT_UP)
		sc->flags |= UMS_SPUR_BUT_UP;

	/*
	 * Deal with the broken behaviour of the touchpad of the TouchBook
	 * keyboard. Despite sending out a report descriptor containing
	 * multiple report IDs, the device only sends out data in a form that's
	 * consistent with the Boot report protocol. This is despite the fact
	 * that we explicitly switch devices into report protocol mode as part
	 * of our initialisation sequence (and the device happily accepts the
	 * command; in fact, sending a command to switch the device into Boot
	 * mode will fail). 
	 * So to cope with this we pretend the device returns a descriptor
	 * which is consistent with a boot mode mouse.
	 */
	if((uaa->vendor == USB_VENDOR_ALWAYSINNOVATING) &&
	   (uaa->product == USB_PRODUCT_ALWAYSINNOVATING_USBKBDTPAD)) {
		desc = (void *) boot_descriptor;
		size = sizeof(boot_descriptor);
	} else {
		err = usbd_read_report_desc(uaa->iface, &desc, &size, M_USBDEV);
		if (err)
			USB_ATTACH_ERROR_RETURN;
	}

	nrepid = uhidev_maxrepid(desc, size);

	for (repid = 0; repid <= nrepid; repid++)
	{
		if ((hid_is_collection(desc, size, repid,
			HID_USAGE2(HUP_GENERIC_DESKTOP, HUG_MOUSE)))
		 || (hid_is_collection(desc, size, repid,
				HID_USAGE2(HUP_GENERIC_DESKTOP, HUG_POINTER))))
		{
			sc->sc_iid = repid;
		}
	}

	if (!hid_locate(desc, size, HID_USAGE2(HUP_GENERIC_DESKTOP, HUG_X),
		       sc->sc_iid, hid_input, &sc->sc_loc_x, &flags)) {
		aprint_error("\n%s: mouse has no X report\n",
		       USBDEVNAME(sc->sc_dev));
		USB_ATTACH_ERROR_RETURN;
	}
	switch (flags & MOUSE_FLAGS_MASK) {
	case 0:
		sc->flags |= UMS_ABS;
		break;
	case HIO_RELATIVE:
		break;
	default:
		aprint_error("\n%s: X report 0x%04x not supported\n",
		       USBDEVNAME(sc->sc_dev), flags);
		USB_ATTACH_ERROR_RETURN;
	}

	if (!hid_locate(desc, size, HID_USAGE2(HUP_GENERIC_DESKTOP, HUG_Y),
		       sc->sc_iid, hid_input, &sc->sc_loc_y, &flags)) {
		aprint_error("\n%s: mouse has no Y report\n",
		       USBDEVNAME(sc->sc_dev));
		USB_ATTACH_ERROR_RETURN;
	}
	switch (flags & MOUSE_FLAGS_MASK) {
	case 0:
		sc->flags |= UMS_ABS;
		break;
	case HIO_RELATIVE:
		break;
	default:
		aprint_error("\n%s: Y report 0x%04x not supported\n",
		       USBDEVNAME(sc->sc_dev), flags);
		USB_ATTACH_ERROR_RETURN;
	}

	/* Try the wheel first as the Z activator since it's tradition. */
	hl = hid_locate(desc, 
			size, 
			HID_USAGE2(HUP_GENERIC_DESKTOP, HUG_WHEEL), 
			sc->sc_iid, 
			hid_input, 
			&sc->sc_loc_z, 
			&flags);

	zloc = &sc->sc_loc_z;
	if (hl) {
		if ((flags & MOUSE_FLAGS_MASK) != HIO_RELATIVE) {
			aprint_verbose("\n%s: Wheel report 0x%04x not "
			    "supported\n", USBDEVNAME(sc->sc_dev),
			    flags);
			sc->sc_loc_z.size = 0;	/* Bad Z coord, ignore it */
		} else {
			sc->flags |= UMS_Z;
			/* Wheels need the Z axis reversed. */
			sc->flags ^= UMS_REVZ;
			/* Put Z on the W coordinate */
			zloc = &sc->sc_loc_w;
		}
	}

	hl = hid_locate(desc, 
			size, 
			HID_USAGE2(HUP_GENERIC_DESKTOP, HUG_Z),
			sc->sc_iid,
			hid_input,
			zloc,
			&flags);

	/*
	 * The horizontal component of the scrollball can also be given by
	 * Application Control Pan in the Consumer page, so if we didnt see
	 * any Z then check that.
	 */
	if (!hl) {
		hl = hid_locate(desc, 
				size, 
				HID_USAGE2(HUP_CONSUMER, HUC_AC_PAN), 
				sc->sc_iid,
				hid_input,
				zloc,
				&flags);
	}

	if (hl) {
		if ((flags & MOUSE_FLAGS_MASK) != HIO_RELATIVE) {
			aprint_verbose("\n%s: Z report 0x%04x not supported\n",
			       USBDEVNAME(sc->sc_dev), flags);
			zloc->size = 0;	/* Bad Z coord, ignore it */
		} else {
			if (sc->flags & UMS_Z)
				sc->flags |= UMS_W;
			else
				sc->flags |= UMS_Z;
		}
	}

	/*
	 * The Microsoft Wireless Laser Mouse 6000 v2.0 reports a bad
	 * position for the wheel and wheel tilt controls -- should be
	 * in bytes 3 & 4 of the report.  Fix this if necessary.
	 */
	if (uaa->vendor == USB_VENDOR_MICROSOFT &&
	    (uaa->product == USB_PRODUCT_MICROSOFT_24GHZ_XCVR10 ||
	     uaa->product == USB_PRODUCT_MICROSOFT_24GHZ_XCVR20)) {
		if ((sc->flags & UMS_Z) && sc->sc_loc_z.pos == 0)
			sc->sc_loc_z.pos = 24;
		if ((sc->flags & UMS_W) && sc->sc_loc_w.pos == 0)
			sc->sc_loc_w.pos = sc->sc_loc_z.pos + 8;
	}

	/* Get coordinate range information for absolute pointing devices */
	if (sc->flags & UMS_ABS) {
		struct hid_item h;
		struct hid_data *d;
		d = hid_start_parse(desc, size, hid_input);
		while(hid_get_item(d, &h))
		{
			if ((h.kind != hid_input) || (HID_GET_USAGE_PAGE(h.usage) != HUP_GENERIC_DESKTOP)) {
				continue;
			}
			switch(HID_GET_USAGE(h.usage)) {
			case HUG_X:
				sc->sc_tsscale.minx = h.logical_minimum;
				sc->sc_tsscale.maxx = h.logical_maximum;
				break;
			case HUG_Y:
				sc->sc_tsscale.miny = h.logical_minimum;
				sc->sc_tsscale.maxy = h.logical_maximum;
				break;
			}
		}
		hid_end_parse(d);
		if ((sc->sc_tsscale.minx == sc->sc_tsscale.maxx) || (sc->sc_tsscale.miny == sc->sc_tsscale.maxy)) {
			aprint_verbose("\n%s: Invalid or incomplete min/max bounds\n", USBDEVNAME(sc->sc_dev));
			USB_ATTACH_ERROR_RETURN;
		}
	}

	/* figure out the number of buttons */
	for (i = 1; i <= MAX_BUTTONS; i++)
		if (!hid_locate(desc, size, HID_USAGE2(HUP_BUTTON, i),
				sc->sc_iid, hid_input, &loc_btn, 0))
			break;
	sc->nbuttons = i - 1;
	sc->sc_loc_btn = malloc(sizeof(struct hid_location)*sc->nbuttons);
	if (!sc->sc_loc_btn) {
		logprintf("%s: no memory\n", USBDEVNAME(sc->sc_dev));
		USB_ATTACH_ERROR_RETURN;
	}

	aprint_normal(": %d button%s%s%s%s\n",
	    sc->nbuttons, sc->nbuttons == 1 ? "" : "s",
	    sc->flags & UMS_W ? ", W" : "",
	    sc->flags & UMS_Z ? " and Z dir" : "",
	    sc->flags & UMS_W ? "s" : "");

	for (i = 1; i <= sc->nbuttons; i++)
		hid_locate(desc, size, HID_USAGE2(HUP_BUTTON, i),
			   sc->sc_iid, hid_input,
			   &sc->sc_loc_btn[i-1], 0);

	sc->sc_isize = hid_report_size(desc, size, hid_input, sc->sc_iid);

	sc->sc_isize += (nrepid != 0);
	sc->sc_ibuf = malloc(sc->sc_isize);
	if (sc->sc_ibuf == NULL) {
		logprintf("%s: no memory\n", USBDEVNAME(sc->sc_dev));
		free(sc->sc_loc_btn);
		USB_ATTACH_ERROR_RETURN;
	}

	sc->sc_ep_addr = ed->bEndpointAddress;
	if (desc != boot_descriptor) {
		free(desc);
	}
#ifdef USB_DEBUG
	DPRINTF(("ums_attach: sc=%p flags=%x\n", sc, sc->flags));
	DPRINTF(("ums_attach: X\t%d/%d\n",
		 sc->sc_loc_x.pos, sc->sc_loc_x.size));
	DPRINTF(("ums_attach: Y\t%d/%d\n",
		 sc->sc_loc_y.pos, sc->sc_loc_y.size));
	if (sc->flags & UMS_Z)
		DPRINTF(("ums_attach: Z\t%d/%d\n",
			 sc->sc_loc_z.pos, sc->sc_loc_z.size));
	if (sc->flags & UMS_W)
		DPRINTF(("ums_attach: W\t%d/%d\n",
			 sc->sc_loc_w.pos, sc->sc_loc_w.size));
	for (i = 1; i <= sc->nbuttons; i++) {
		DPRINTF(("ums_attach: B%d\t%d/%d\n",
			 i, sc->sc_loc_btn[i-1].pos,sc->sc_loc_btn[i-1].size));
	}
	DPRINTF(("ums_attach: size=%d, id=%d\n", sc->sc_isize, sc->sc_iid));
#endif

	usbd_add_drv_event(USB_EVENT_DRIVER_ATTACH, sc->sc_udev,
			   USBDEV(sc->sc_dev));

	USB_ATTACH_SUCCESS_RETURN;
}

struct device* attach_mouse (struct device* parent, void* aux)
{
	struct device* softc;
	struct ums_softc* sc;

	dprintf (("", "Trying match on usb mouse\n"));

	/* First see if we match */
	if (match_mouse (aux) == UMATCH_NONE)
	{
		dprintf (("", "Failed to match\n"));
		return NULL;
	}

	/* If so, allocate memory for the device and attach ourselves. */
	softc = malloc (sizeof *sc);
	if (softc == NULL) {
		dprintf (("", "Couldn't allocate memory for mouse device\n"));
		return NULL;
	}
	memset (softc, 0, sizeof *sc);
	strcpy (softc->dv_xname, "USBMouse"Module_VersionString);
	softc->dv_cfdata = (void*) 3; // mouse

	/* enable */
	sc = (struct ums_softc*) softc;

	do_attach_mouse (sc, aux);
	dprintf (("", "Matched mouse\n"));


	sc->sc_enabled = 1;
	sc->sc_buttons = 0;

	/* set idle rate to 0 */
	usbd_set_idle (sc->sc_iface, 0, 0);

	/* make sure we're using the report protocol */
	if(usbd_set_protocol(sc->sc_iface, 1)) {
		dprintf(("", "Set protocol failed\n"));
		return NULL;
	}

	int err = usbd_open_pipe_intr(sc->sc_iface, sc->sc_ep_addr,
		  USBD_SHORT_XFER_OK, &sc->sc_intrpipe, sc,
		  sc->sc_ibuf, sc->sc_isize, ums_intr, USBD_DEFAULT_INTERVAL);

	if (err) {
			dprintf(("", "ums_enable: usbd_open_pipe_intr failed, error=%d\n",
					 err));
			sc->sc_enabled = 0;
	}
	else
		_swix (OS_Pointer, _INR(0,1), 1, PointerDevice_USB);

	TAILQ_INSERT_TAIL (&allums, sc, link_ms);

	return softc;
}

int detach_mouse (struct device* ms)
{
	struct ums_softc* sc= (struct ums_softc*) ms;
	if(!sc || !sc->sc_intrpipe)
	{
	  dprintf (("", "attempt to detach a NULL mouse 'sc'\n"));
	  return 0;
	}
	dprintf (("", "detaching mouse, buttons = %x\n", sc->sc_buttons));
	usbd_abort_pipe(sc->sc_intrpipe);
	usbd_close_pipe(sc->sc_intrpipe);
	dprintf (("", "aborted pipe\n"));


	if (sc->sc_buttons & 1) {
		dprintf (("", "releaseing 1\n"));
		_swix (OS_CallAVector, _INR(0,1) | _IN(9),
			KeyV_KeyUp, KeyNo_LeftMouse, KEYV);
	}
	if (sc->sc_buttons & 2)
	{
		dprintf (("", "releaseing 2\n"));
		_swix (OS_CallAVector, _INR(0,1) | _IN(9),
		KeyV_KeyUp, KeyNo_RightMouse, KEYV);
	}
	if (sc->sc_buttons & 4)
	{
		dprintf (("", "releaseing 4\n"));
		_swix (OS_CallAVector, _INR(0,1) | _IN(9),
			KeyV_KeyUp, KeyNo_CentreMouse, KEYV);
	}

	TAILQ_REMOVE (&allums, sc, link_ms);

	free(sc->sc_loc_btn);
	free(sc->sc_ibuf);
	free (ms);
	dprintf (("", "mouse detached\n"));
	return 0;
}

int pointerv (_kernel_swi_regs* r, void* pw)
{
	_kernel_oserror* e;
	(void) pw;

	switch (r->r[0]) {
	case PointerReason_Request:
		if (r->r[1] == PointerDevice_USB) {
			/* Turn off interrupts while updating */
			int irqs = _kernel_irqs_disabled();
			if(!irqs)
				_kernel_irqs_off ();
			r->r[2] = relx;
			r->r[3] = rely;
			relx = rely = 0;
			if(!irqs)
				_kernel_irqs_on ();
			return 0; /* PRM says we should intercept */
			}
		break;

	case PointerReason_Identify:
	{
		struct pointer_device {
			struct pointer_device *next;
			uint32_t flags;
			char typenname[32];
		} *p;
		e = _swix (OS_Module, _IN(0) | _IN(3) | _OUT(2), 6,
			sizeof *p, &p);

		if (!e) {
			p->next = (struct pointer_device *) r->r[1];
			p->flags = 0;
			p->typenname[0] = PointerDevice_USB;

			_swix (MessageTrans_Lookup, _INR(0,3),
				   &mod_messages, "Mouse:USB mouse", &p->typenname[1], 31);
			r->r[1] = (int) p;
		}
		break;
	}

	case PointerReason_Selected:
		if (r->r[1] == PointerDevice_USB) {
			relx = 0;	/* ensure the pointer doesnt jump */
			rely = 0;
			relz = 0;
			relw = 0;
			dprintf (("", "USB mouse enabled\n"));
			enabled = true;
		} else {
			dprintf (("", "USB mouse disabled\n"));
			enabled = false;
		}
		break;
	}

	return 1;
}

static _kernel_oserror *zscroll_handler(_kernel_swi_regs *r, void *pw, void *h)
{
	int b[10];

	(void) r;
	(void) pw;
	(void) h;

	_swix (Wimp_GetPointerInfo, _IN(1), b);
	b[0] = b[3];
	if((relz || relw) && (b[0] != -1) && !_swix (Wimp_GetWindowState, _IN(1), b)) // valid window handle
	{
		/* does it do scroll requests? */
		if (b[8] & ((1<<8)|(1<<9)))
		{
			/* Only scroll if scrollbars are present */
			if(b[8] & (1<<31))
			{
				/* New format window flags word */
				if(!(b[8] & (1<<28)))
					relz = 0;
				if(!(b[8] & (1<<30)))
					relw = 0;
			}
			else
			{
				/* Old format window flags word */
				if(!(b[8] & (1<<2)))
					relz = 0;
				if(!(b[8] & (1<<3)))
					relw = 0;
			}
			relz*=5; // a bit more movement...
			relw*=5;
			while(relz || relw)
			{
				b[8] = (relw?(relw > 0? -1: 1):0);
				b[9] = (relz?(relz > 0? -1: 1):0);
				relw += b[8];
				relz += b[9];
				_swix (Wimp_SendMessage, _INR(0,2), 10, b, b[0]);
			}
		}
		else
		{     // give it to a wimpscroll module
#define PointerReason_WheelChange 9
			_swix (OS_CallAVector, _INR(0,3) | _IN(9),
				PointerReason_WheelChange,	// wheel change reason
				relz,				// main wheel value
				morebuttons,			// any additional buttons
				relw,				// extra wheel
				PointerV);
			relz=0;
			relw=0;
		}
	}
	return NULL;
}

void ums_intr
(
    usbd_xfer_handle	xfer,
    usbd_private_handle addr,
    usbd_status		status
)
{
	struct ums_softc *sc = addr;
	u_char *ibuf = sc->sc_ibuf;
	int dx, dy, dz, dw;
	u_int32_t buttons = 0;
	int i;
	uint8_t change;

	if (status == USBD_CANCELLED)
		return;

	if (status) {
		dprintf(("", "ums_intr: status=%d\n", status));
		usbd_clear_endpoint_stall_async(sc->sc_intrpipe);
		return;
	}

	/* only respond to our report, and skip the report number */
	if (sc->sc_iid && *ibuf++ != sc->sc_iid)
		return;

	dx =  hid_get_data(ibuf, &sc->sc_loc_x);
	if (sc->flags & UMS_ABS) {
		dy = hid_get_data(ibuf, &sc->sc_loc_y);
	} else {
		dy = -hid_get_data(ibuf, &sc->sc_loc_y);
	}
	dz =  hid_get_data(ibuf, &sc->sc_loc_z);
	dw =  hid_get_data(ibuf, &sc->sc_loc_w);

	if (sc->flags & UMS_REVZ)
		dz = -dz;
	for (i = 0; i < sc->nbuttons; i++)
		if (hid_get_data(ibuf, &sc->sc_loc_btn[i]))
			buttons |= (1 << UMS_BUT(i));

	relx += dx;
	rely += dy;
	relz += dz;
	relw += dw;

	if (enabled)
	{
		if(sc->flags & UMS_ABS)
		{
			static int oldx, oldy;
			if((dx != oldx) || (dy != oldy))
			{
				oldx = dx;
				oldy = dy;
				static const int vduin[5] = {
					VduExt_XEigFactor,
					VduExt_YEigFactor,
					VduExt_XWindLimit,
					VduExt_YWindLimit,
					-1
				};
				int vduout[5];
				_swix(OS_ReadVduVariables, _INR(0,1), vduin, vduout);
				int width = (vduout[2] + 1) << vduout[0];
				int height = (vduout[3] + 1) << vduout[1];
				dx = ((dx - sc->sc_tsscale.minx) * width) / (sc->sc_tsscale.maxx - sc->sc_tsscale.minx);
				dy = height - (((dy - sc->sc_tsscale.miny) * height) / (sc->sc_tsscale.maxy - sc->sc_tsscale.miny));
				_swix(OS_CallAVector, _INR(0,4) | _IN(9), PointerReason_Report, PointerDevice_USB, dx, dy, 0x6f736241 /* "Abso" */, PointerV);
			}
		}
		else if(dx || dy)
		{
			_swix(OS_CallAVector, _INR(0,4) | _IN(9),
				PointerReason_Report, PointerDevice_USB,
				dx, dy, 0,
				PointerV);
		}
		if (relz || relw)
		{
			morebuttons = buttons>>3;
			callx_add_callback (zscroll_handler, 0);
		}
	}


#ifdef USB_DEBUG
	if (umsdebug > 5) dprintf(("",
		"data.relx = %d, data.rely = %d, relx = %d, rely = %d, buttons = %x\n",
		dx, dy, relx, rely, buttons));
#endif
	if ((change = sc->sc_buttons ^ buttons) != 0) {
		sc->sc_buttons = buttons;
#ifdef USB_DEBUG
		if (umsdebug > 5) dprintf (("", "change = %x, enabled = %d\n", change,
			enabled));
#endif
		if (enabled) {
			if (change & 1) _swix (OS_CallAVector, _INR(0,1) | _IN(9),
				(buttons & 1)? KeyV_KeyDown: KeyV_KeyUp, KeyNo_LeftMouse, KEYV);

			if (change & 2) _swix (OS_CallAVector, _INR(0,1) | _IN(9),
				(buttons & 2)? KeyV_KeyDown: KeyV_KeyUp, KeyNo_RightMouse, KEYV);

			if (change & 4) _swix (OS_CallAVector, _INR(0,1) | _IN(9),
				(buttons & 4)? KeyV_KeyDown: KeyV_KeyUp, KeyNo_CentreMouse, KEYV);

			/* make the next button replicate menu */
			if (change & 8) _swix (OS_CallAVector, _INR(0,1) | _IN(9),
				(buttons & 8)? KeyV_KeyDown: KeyV_KeyUp, KeyNo_CentreMouse, KEYV);
		}
	}
}

int
uhidev_maxrepid(void *buf, int len)
{
	struct hid_data *d;
	struct hid_item h;
	int maxid;

	maxid = -1;
	h.report_ID = 0;
	for (d = hid_start_parse(buf, len, hid_none); hid_get_item(d, &h); )
	{
		if (h.report_ID > maxid)
			maxid = h.report_ID;
	}
	hid_end_parse(d);
	return (maxid);
}
