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
/*	RISC OS port options
 */

#include "sys/device.h"
#include "errno.h"
#include <sys/ioccom.h>
#include <string.h>
#include <stdbool.h>

#ifdef USB_DEBUG
#define UHID_DEBUG 1
#define UHIDEV_DEBUG 1
#define UGEN_DEBUG 1
#define UHCI_DEBUG 1
#define UHUB_DEBUG 1
#define ULPT_DEBUG 1
#define UCOM_DEBUG 1
#define UMODEM_DEBUG 1
#define UAUDIO_DEBUG 1
#define AUE_DEBUG 1
#define CUE_DEBUG 1
#define KUE_DEBUG 1
#define UMASS_DEBUG 1
#define UPL_DEBUG 1
#define UZCOM_DEBUG 1
#define URIO_DEBUG 1
#define UFTDI_DEBUG 1
#endif

/* always define the functions as global because we access them from RISC OS
   module */
#define Static


/* make these do nothing for RISC OS */
#define	config_pending_incr()
#define	config_pending_decr()
#define le16toh(a) a
#define htole16(a) a
#define le32toh(a) (a)
#define htole32(a) (a)

/* XXX don't know what to do about locks yet */
#define lockinit(a,b,c,d,e)
#define lockmgr(a,b,c)
struct lock { int a; };

#define device_has_power(a) (true)

/* Module builds use bufferable memory and so may need synchronisation
   However, we only need to synchronise in some situations - use the BUS_DMASYNC
   hints to decide when. In many cases the if() will be optimised out.
 */
typedef void (*barrier_func)(void);
extern barrier_func barriers[3];
#define BARRIER_WRITE 1
#define BARRIER_READ 2
#define BUS_DMASYNC_PREREAD 0 /* Device is about to write to memory (e.g. about to read a packet from USB). Technically we need a write barrier here to ensure any buffered write to the area completes before the USB overwrites it, but there should be enough barriers elsewhere that we can get away without it (and having one here will really kill performance)  */
#define BUS_DMASYNC_PREWRITE BARRIER_WRITE /* Device is about to read from memory (e.g. about to write a packet to USB). */
#define BUS_DMASYNC_POSTREAD BARRIER_READ /* Device has finished writing to memory */
#define BUS_DMASYNC_POSTWRITE 0 /* Device has finished reading from memory */
#define usb_syncmem(a,b,c,d) do { int barrier = d; if (barrier) barriers[barrier-1](); } while(0)

extern int hz;

#define splhigh splbio
#define splsoftnet splbio
extern int splbio (void);
extern int spltty (void);
extern void splx (int);
extern int vtophys (void*);
extern void delay (int);
extern struct device* get_softc (int unit);
extern void callout_init (struct callout* c,int ignored);
extern void callout_stop (struct callout *c);
extern void callout_reset (struct callout *c, int i, void (*f)(void *), void *v);
extern int min (int a, int b);
extern struct device* riscos_usb_attach(void*, struct device*, void*);
extern void usb_needs_explore_callback (void*);
extern int config_detach (struct device*, int);
extern void* (config_found) (struct device*, void*, int (*) (void*, const char*));
extern void kill_system_variable (int unit);
extern void riscos_abort_pipe (void*);
extern void riscos_irqclear (int device);

extern int kthread_create (void (*) (void*), void*);
extern int kthread_create1 (void (*) (void*), void*, void*, char*, char*);
extern int kthread_exit (int);

/* copy data using private handle b into memory dma */
extern void bufrem (void* dma, void* b, int size);
extern void bufins (void* dma, void* xfer);

extern void* malloc_contig (int size, int alignment);
#define		usb_allocmem(t,s,a,p)	(*(p) = malloc_contig(s, a), (*(p) == NULL? USBD_NOMEM: USBD_NORMAL_COMPLETION))
extern void free_contig(void **mem);
#define usb_freemem(p, m) free_contig (m)
#define DMAADDR(dma, o)	(vtophys((void*) (((char*) *(dma)) + o)))
#define KERNADDR(dma, o)	((void*) (((char *) *(dma)) + (o)))

int ratecheck (void*, void*);

int config_deactivate (struct device* dev);

#ifdef USB_USE_SOFTINTR
#define __HAVE_GENERIC_SOFT_INTERRUPTS
#define IPL_SOFTNET 0
void* softintr_establish(int, void (*) (void*), void*);
void softintr_schedule (void*);
void softintr_disestablish (void*);
#endif

typedef struct proc *usb_proc_ptr;

typedef struct device *device_ptr_t;
typedef struct device *device_t;
#define USBBASEDEVICE struct device
#define USBDEV(bdev) (&(bdev))
#define USBDEVNAME(bdev) ((bdev).dv_xname)
#define USBDEVUNIT(bdev) ((bdev).dv_unit)
#define USBDEVPTRNAME(bdevptr) ((bdevptr)->dv_xname)
#define USBGETSOFTC(d) ((void *)(d))


typedef struct callout usb_callout_t;
#define usb_callout_init(h)	callout_init(&(h), 0)
#define	usb_callout(h, t, f, d)	callout_reset(&(h), (t), (f), (d))
#define	usb_uncallout(h, f, d)	callout_stop(&(h))

#define clalloc(p, s, x) (clist_alloc_cblocks((p), (s), (s)), 0)
#define clfree(p) clist_free_cblocks((p))

#define usb_kthread_create1	kthread_create1
#define usb_kthread_create	kthread_create

typedef int usb_malloc_type;

#define Ether_ifattach ether_ifattach
#define IF_INPUT(ifp, m) (*(ifp)->if_input)((ifp), (m))

#ifdef USB_DEBUG
#pragma -v1
extern void logprintf(char* format, ...);
#else
#define logprintf(...) 0
#endif

#define USB_DECLARE_DRIVER(dname)  \
int __CONCAT(dname,_match)(struct device *, struct cfdata *, void *); \
void __CONCAT(dname,_attach)(struct device *, struct device *, void *); \
int __CONCAT(dname,_detach)(struct device *, int); \
int __CONCAT(dname,_activate)(struct device *, enum devact); \
\
extern struct cfdriver __CONCAT(dname,_cd); \
\
struct cfattach __CONCAT(dname,_ca) = { \
	sizeof(struct __CONCAT(dname,_softc)), \
	__CONCAT(dname,_match), \
	__CONCAT(dname,_attach), \
	__CONCAT(dname,_detach), \
	__CONCAT(dname,_activate), \
}; \
Static int __CONCAT(dname,_devclass)

#define USB_MATCH(dname) \
int __CONCAT(dname,_match)(struct device *parent, struct cfdata *match, void *aux)

#define USB_MATCH_START(dname, uaa) \
	struct usb_attach_arg *uaa = aux

#define USB_ATTACH(dname) \
void __CONCAT(dname,_attach)(struct device *parent, struct device *self, void *aux)

#define USB_ATTACH_START(dname, sc, uaa) \
	struct __CONCAT(dname,_softc) *sc = \
		(struct __CONCAT(dname,_softc) *)self; \
	struct usb_attach_arg *uaa = aux

/* Returns from attach */
#define USB_ATTACH_ERROR_RETURN	return
#define USB_ATTACH_SUCCESS_RETURN	return

#define USB_ATTACH_SETUP logprintf("Attach setup\n")

#define USB_DETACH(dname) \
int __CONCAT(dname,_detach)(struct device *self, int flags)

#define USB_DETACH_START(dname, sc) \
	struct __CONCAT(dname,_softc) *sc = \
		(struct __CONCAT(dname,_softc) *)self

#define USB_GET_SC_OPEN(dname, unit, sc) \
	sc = (void *) get_softc(unit); \
	if (!sc) \
		return (ENXIO)

#define USB_GET_SC(dname, unit, sc) \
	sc = (void *) get_softc(unit)

#define USB_DO_ATTACH(dev, bdev, parent, args, print, sub) \
        riscos_usb_attach (dev, parent, args)

/* so we don't have to worry about memory allocation types */
#define M_USB 0
#define M_USBDEV 0
#define M_ZERO 0

/* ioctl types */
#ifndef FIONBIO
#define FIONBIO 0
#define FIOASYNC 1
#endif


#ifndef max
#define max(a,b) ((a)>(b)?(a):(b))
#endif
#ifndef min
#define min(a,b) ((a)<(b)?(a):(b))
#endif
