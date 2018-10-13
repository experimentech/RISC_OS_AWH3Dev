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
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdarg.h>

#include "DebugLib/DebugLib.h"
#include "callx/callx.h"
#include "swis.h"
#include "sys/callout.h"
#include "sys/time.h"
#include "Global/HALEntries.h"
#include "Global/OSMisc.h"
#include <sys/types.h>
#include "dev/usb/usb_port.h"

#ifdef USB_DEBUG
extern int usbdebug;
int total_sleep;
#endif


extern void detach_hub (struct device*);
extern void detach_device (struct device*);

extern uint32_t hal_veneer2(uint32_t (*)(void), void*, ...);
extern uint64_t gettime (void);

uint64_t gettime (void)
{
    uint32_t cs;
    static uint32_t (*readcode) (void);
    static void* ws;
    static uint32_t ns_factor;
    static uint32_t max_count;
    if (readcode == NULL)
    {
        _swix (OS_Hardware, _INR(8,9)|_OUTR(0,1),
            1, EntryNo_HAL_CounterRead,
            &readcode, &ws);

        _swix (OS_Hardware, _INR(8,9)| _OUT(0),
            0, EntryNo_HAL_CounterPeriod,
            &max_count);

#if 0 // fixed in RISC OS 5.03
        /* bug here - force 2000000 */
        max_count = 2000000;
#endif

        /* conversion to ns, assume counter is for 1 cs */
        ns_factor = 10000000 / max_count;
    }

    _swix (OS_ReadMonotonicTime, _OUT(0), &cs);
    return (uint64_t) (max_count - hal_veneer2(readcode,ws)) * ns_factor +
        ((uint64_t) cs) * 10000000 /* 1e7 */;
}

/* turn off cold starting */
int cold = 0;

int hz = 1000;

/* disable interrupt for input */
int spltty (void)
{
    return _kernel_irqs_disabled ();
}

void splx (int s)
{
    if (s == 0) _kernel_irqs_on ();
//    dprintf (("", "int on\n"));
}

int splbio (void)
{
    int s = _kernel_irqs_disabled ();
    _kernel_irqs_off ();
//    dprintf (("", "int off\n"));
    return s;
}


char panic_string[255];

void panic (const char* str, ...)
{
    va_list p;
    va_start (p, str);
    /* aargh! */
    dprintf (("Port", "panicking:"));
    dvprintf (("Port", str, p));
    vsnprintf(panic_string, sizeof panic_string, str, p);
    va_end (p);
}

void
delay (int d)
{
#ifdef USB_DEBUG0
    if (usbdebug > 19)
    {
        time_t t;
        time (&t);
        dprintf (("Port", "wait for %dus at %s", d, ctime(&t)));
    }
#endif
    _swix (OS_Hardware, _IN(0)|_INR(8,9), d, 0, EntryNo_HAL_CounterDelay);
}

void
selrecord(struct proc *selector, struct selinfo *selinfo)
{
    dprintf (("Port", "selecting record\n"));
}

void
selwakeup(struct selinfo *selinfo)
{
    dprintf (("Port", "selwakeup called\n"));
}

typedef int devclass_t;

void*
devclass_get_softc (devclass_t dc, int unit)
{
    return 0; /* TODO make this return something that won't make it crash.. */
}

int
config_deactivate (struct device* dev)
{
    dprintf (("Port", "deactivating device\n"));
    return 0;
}

struct uio;

int
uiomove(caddr_t poo, int wobble, struct uio * fred)
{
    dprintf (("Port", "uiomove\n"));
    return 0;
}

void
psignal(unsigned sig, const char *s) {
    dprintf (("Port", "wow - we've received signal %d: %s\n", sig, s));
}

/*
 * Callouts
 */
extern int private_word;

void
callout_init (struct callout* c,int ignored)
{
    (void)ignored;
#ifdef USB_DEBUG0
    if (usbdebug > 15) dprintf (("Port", "callout init %p\n", c));
#endif
    memset (c, 0, sizeof (*c));
}

_kernel_oserror*
callout_handler (_kernel_swi_regs* r, void* pw, void* _c) {
    struct callout* c = _c;
#ifdef USB_DEBUG0
    if (usbdebug > 15) dprintf (("Port", "callout2 %p called\n", c));
#endif
    if(c->c_func)c->c_func (c->c_arg);
    return NULL;
}

void
callout_stop (struct callout *c) {
#ifdef USB_DEBUG0
    if (usbdebug > 15) dprintf (("Port", "callout stop %p\n", c));
#endif
    callx_remove_callafter (callout_handler, c);
}

void
callout_reset (struct callout *c, int i, void (*f)(void *), void *v) {
    if (i <= 0) i = 1;
    c->c_arg = v;
    c->c_func = f;
#ifdef USB_DEBUG0
    if (usbdebug > 15) dprintf (("Port", "callout %p reset %dms\n", c, i));
#endif
    callx_add_callafter ((i + 9) / 10, callout_handler, c);
}

int kthread_create (void (f) (void*), void* h) {
    (void) f;
    (void) h;
//    dprintf (("Port", "creating thread\n"));

    return 0;
}

int kthread_create1 (void (f) (void*), void* a, void* b, char* c, char* d)
{
    (void) f;
    (void) a;
    (void) b;
    (void) c;
    (void) d;

    return 0;
}

void* t_handles[100];
int t_locks[100];
int nhandles = 0;

extern void triggercbs (void);
extern int *get_ptr_IRQsema(void);

int tsleep (void* ident, int priority, const char* wmesg, int timo, int noblock)
{
    int i;
    int s = _kernel_irqs_disabled ();
    uint64_t t0, t1, t2;

    _kernel_irqs_off ();                       // lets play safe

    t1 = t0 = gettime();
    t1 += ((uint64_t) timo) * 1000000;
#ifdef USB_DEBUG

    int sema = *get_ptr_IRQsema();
    char bbf[32];strncpy( bbf, wmesg, 31);bbf[31]=0;
    dprintf(("","enter sleep:%s                  irqstate:%d\n",bbf,sema));
#endif

#ifdef USB_DEBUG0
    int cs0, cs1;
    _swix (OS_ReadMonotonicTime, _OUT(0), &cs0);
    if (usbdebug > 19)
        dprintf (("Port", "%s sleeping on %p at priority %d for %dms\n"
                      "from %lu.%.09lu\n"
                      "til  %lu.%.09lu\n",
            wmesg, ident, priority, timo,
            (uint32_t) (t0 / 1000000000), (uint32_t) (t0 % 1000000000),
            (uint32_t) (t1 / 1000000000), (uint32_t) (t1 % 1000000000)));
#endif

    for (i = 0; i < nhandles && t_handles[i] && t_handles[i] != ident; ++i);

    if (i == nhandles) {
        nhandles = i + 1;
        if (nhandles >= sizeof t_handles / sizeof *t_handles)
        {
            if (s == 0) _kernel_irqs_on ();
            panic ("run out of thread handles...");
            return 1;
        }
    }

    t_handles[i] = ident;
    t_locks[i] = 0;

    /* wait until the lock is free */
    _kernel_irqs_on ();

    if (timo) {
        do {
            triggercbs ();
            t2 = gettime ();
        }
        while ((t_locks[i] == 0) && (t2 < t1));
    }
    else
    {
        while (t_locks[i] == 0)
        {
            triggercbs ();
        }
#ifdef USB_DEBUG0
        t2 = gettime ();
#endif
    }
    _kernel_irqs_off ();

    t_handles[i] = 0;

#ifdef USB_DEBUG0
    if (usbdebug > 19)
      dprintf (("", "now  %lu.%09lu\n",
        (uint32_t) (t2 / 100000000), (uint32_t) (t2 % 1000000000)));
    t2 -= t0;
    _swix (OS_ReadMonotonicTime, _OUT(0), &cs1);
    total_sleep += cs1 - cs0;
    if (usbdebug > 10)
        dprintf (("", "slept for %lu.%.09lu seconds (timo = %dms), %d cs\n",
            (uint32_t) (t2 / 100000000), (uint32_t) (t2 % 1000000000),
            timo, cs1 - cs0));
#endif
#ifdef USB_DEBUG
    dprintf(("","leave sleep:%s                  irqstate:%d\n",bbf,sema));
#endif

    if (s == 0) _kernel_irqs_on ();

    return 0;
}

int wakeup (void* ident) {
    int i;
#ifdef USB_DEBUG0
    if (usbdebug > 10) dprintf (("", "waking up %p\n", ident));
#endif

    /* Find the index of the handle passed */
    for (i = 0; i < nhandles && t_handles[i] != ident; ++i);

    /* unlock it */
    if (t_handles[i] == ident)
    {
      t_locks[i] = 1;
      t_handles[i] =NULL;
    }  
    return 0;
}

int kthread_exit (int status) {
//    dprintf (("Port", "exit thread\n"));
    return 0;
}

void device_probe_and_attach (void) {
//    dprintf (("Port", "probing device\n"));
}

/*
 * usbd_ratecheck() can limit the number of error messages that occurs.
 * When a device is unplugged it may take up to 0.25s for the hub driver
 * to notice it.  If the driver continuosly tries to do I/O operations
 * this can generate a large number of messages.
 */
int
ratecheck (void* a, void* b)
{
    return 0;
}

void* usbd_print;

int vtophys (void* v)
{
#ifndef EMULATE
    struct {
        int     page;
        void*   logical;
        int     physical;
    } block;
    block.logical = v;
    _swix (OS_Memory, _INR (0, 2), (1<<9) + (1<<13), &block, 1);

    return block.physical;
#else
//    dprintf (("Port", "Converting physical address %p\n", *v));
    return v; // return actual address for the moment
#endif
}

void* malloc_contig(int len, int alignment)
{
    void* p;
    _kernel_oserror* e;

    e = _swix(PCI_RAMAlloc, _INR(0,2)|_OUT(0), len, alignment, 0, &p);
    if (e || !p)
    {
        dprintf (("", "failed to allocate %d bytes at %d alignment err = '%s'\n",
            len, alignment, e?e->errmess:""));

        return NULL;
    }

    memset(p, 0, len);

    return p;
}

void free_contig (void **mem)
{
    _swix(PCI_RAMFree, _IN(0), *mem);
}

char*
device_get_nameunit (void)
{
    return "Root device";
}

#ifdef logprintf
#undef logprintf
#endif
void logprintf (char* format, ...)
{
    va_list p;
    va_start (p, format);
    dvprintf (("Log", format, p));
    va_end (p);
}

#ifdef USB_USE_SOFTINTR
void* softintr_establish(int pri, void (*f) (void*), void* h)
{
    void** p = malloc (3 * sizeof *p);
    if (p == NULL) return p;

    p[0] = 0;
    p[1] = h;
    p[2] = (void*) f;

    _swix (CBAI_RegisterPollWord, _INR(0, 2), p, pri, private_word);
    return p;
}

//void softintr_schedule (void** p)
//{
//    dprintf (("", "Setting pollword to %p\n", p[2]));
//    p[0] = p[2];
//}

void softintr_disestablish (void* p)
{
    _swix (CBAI_DeregisterPollWord, _IN(0), p);
    free (p);
}
#endif

void riscos_irqclear(int devno)
{
    _swix(OS_Hardware, _IN(0)|_INR(8,9), devno, 0, EntryNo_HAL_IRQClear);
}

static void barriers_init(void);

barrier_func barriers[3] =
{
    barriers_init, /* Lazy approach to initialisation! */
    barriers_init,
    barriers_init,
};

static void barriers_null(void)
{
}

void barriers_init(void)
{
    /* Get the appropriate barrier ARMops */
    if (_swix(OS_MMUControl, _IN(0)|_OUT(0), MMUCReason_GetARMop + (ARMop_DMB_ReadWrite<<8), &barriers[BARRIER_READ+BARRIER_WRITE-1])
     || _swix(OS_MMUControl, _IN(0)|_OUT(0), MMUCReason_GetARMop + (ARMop_DMB_Write<<8), &barriers[BARRIER_WRITE-1])
     || _swix(OS_MMUControl, _IN(0)|_OUT(0), MMUCReason_GetARMop + (ARMop_DMB_Read<<8), &barriers[BARRIER_READ-1]))
    {
        /* Assume any error means we're running on an old OS version, where
           synchronisation isn't necessary */
        barriers[0] = barriers[1] = barriers[2] = barriers_null;
    }
    else
    {
        /* Make sure the initial call actually acts as a sync */
        (barriers[BARRIER_READ+BARRIER_WRITE-1])();
    }
}

