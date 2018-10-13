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
#include "swis.h"

#include "sys/types.h"
#include "sys/callout.h"
#include "sys/time.h"
#include "sys/systm.h"

#include "machine/bus.h"

#include "dev/usb/usb.h"
#include "dev/usb/usbdi.h"
#include "dev/usb/usbdivar.h"
#include "ohcireg.h"
#include "ohcivar.h"

#include "Global/HALEntries.h"
#include "Interface/USBDriver.h"
#include "callx/callx.h"
#include "DebugLib/DebugLib.h"

extern void triggercbs (void);
extern uint32_t hal_veneer2(uint32_t (*)(void), void*, ...);
extern volatile int* hci_base;
extern int registers_32bit;
#ifdef DEBUGLIB
int usbdebug = 0;
#endif

/*---------------------------------------------------------------------------*/
/* Timeout and sleep functions                                               */
/*---------------------------------------------------------------------------*/
int hz = 1000;

static uint64_t gettime (void)
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

        /* conversion to ns, assume counter is for 1 cs */
        ns_factor = 10000000 / max_count;
    }

    _swix (OS_ReadMonotonicTime, _OUT(0), &cs);
    return (uint64_t) (max_count - hal_veneer2(readcode,ws)) * ns_factor +
        ((uint64_t) cs) * 10000000 /* 1e7 */;
}

void* t_handles[100];
int t_locks[100];
int nhandles = 0;
int total_sleep;
int tsleep (void* ident, int priority, const char* wmesg, int timo, int noblock)
{
    int i;
    int s = _kernel_irqs_disabled ();
    uint64_t t0, t1, t2;

    _kernel_irqs_off ();                       // lets play safe

    t1 = t0 = gettime();
    t1 += ((uint64_t) timo) * 1000000;

#ifdef DEBUGLIB
    char bbf[32];strncpy( bbf, wmesg, 31);bbf[31]=0;
    dprintf(("bsdfns_7","enter sleep:%s\n",bbf));
#endif

#ifdef DEBUGLIB
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
#ifdef DEBUGLIB
        t2 = gettime ();
#endif
    }
    _kernel_irqs_off ();

    t_handles[i] = 0;

#ifdef DEBUGLIB
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
    dprintf(("bsdfns_7","leave sleep:%s\n",bbf));

    if (s == 0) _kernel_irqs_on ();

    return 0;
}

int wakeup (void* ident) {
    int i;

    dprintf (("bsdfns_7", "waking up %p\n", ident));

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

void delay (int d)
{
    _swix (OS_Hardware, _IN(0)|_INR(8,9), d, 0, EntryNo_HAL_CounterDelay);
}

void usb_delay_ms(usbd_bus_handle h, u_int d)
{
    tsleep (&d, 0, "usbdly", d, 0);
}

/*---------------------------------------------------------------------------*/
/* Interrupts                                                                */
/*---------------------------------------------------------------------------*/
void splx (int s)
{
    if (s == 0) _kernel_irqs_on ();
}

int splbio (void)
{
    int s = _kernel_irqs_disabled ();
    _kernel_irqs_off ();
    return s;
}

/*---------------------------------------------------------------------------*/
/* Debugging                                                                 */
/*---------------------------------------------------------------------------*/
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

#if !defined(logprintf) && defined(DEBUGLIB)
void logprintf (char* format, ...)
{
    va_list p;
    va_start (p, format);
    dvprintf (("Log", format, p));
    va_end (p);
}
#endif

/*---------------------------------------------------------------------------*/
/* Callouts                                                                  */
/*---------------------------------------------------------------------------*/
void
callout_init (struct callout* c,int ignored)
{
    (void)ignored;

    dprintf (("bsdfns_6", "callout init %p\n", c));
    memset (c, 0, sizeof (*c));
}

_kernel_oserror*
callout_handler (_kernel_swi_regs* r, void* pw, void* _c)
{
    struct callout* c = _c;

    dprintf (("bsdfns_6", "callout2 %p called\n", c));
    if(c->c_func)c->c_func (c->c_arg);
    return NULL;
}

void
callout_stop (struct callout *c)
{
    dprintf (("bsdfns_6", "callout stop %p\n", c));
    callx_remove_callafter (callout_handler, c);
}

void
callout_reset (struct callout *c, int i, void (*f)(void *), void *v) {
    if (i <= 0) i = 1;
    c->c_arg = v;
    c->c_func = f;
    dprintf (("bsdfns_6", "callout %p reset %dms\n", c, i));
    callx_add_callafter ((i + 9) / 10, callout_handler, c);
}

/*---------------------------------------------------------------------------*/
/* Kernel virtual memory replacement functions                               */
/*---------------------------------------------------------------------------*/
int vtophys (void* v)
{
    struct {
        int     page;
        void*   logical;
        int     physical;
    } block;
    block.logical = v;
    _swix (OS_Memory, _INR (0, 2), (1<<9) + (1<<13), &block, 1);

    return block.physical;
}

/*---------------------------------------------------------------------------*/
/* Kernel memory allocation replacement functions                            */
/*---------------------------------------------------------------------------*/
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

/*---------------------------------------------------------------------------*/
/* Bus space access functions                                                */
/*---------------------------------------------------------------------------*/
void bus_space_write_4 (bus_space_tag_t iot, bus_space_handle_t ioh, int o, int x)
{
    dprintf (("bsdfns_8", "write4 %x to %p\n", x, (uintptr_t)hci_base + o));
    hci_base[o/4] = x;
}

int bus_space_read_4 (bus_space_tag_t iot, bus_space_handle_t ioh, int o)
{
    int ret = hci_base[o/4];
    dprintf (("bsdfns_8", "read4 %x from %p\n", ret, (uintptr_t)hci_base + o));
    return ret;
}

void bus_space_write_2 (bus_space_tag_t iot, bus_space_handle_t ioh, int o, int x)
{
    dprintf (("bsdfns_8", "write2 %x to %p\n", x, (uintptr_t)hci_base + o));
    if (registers_32bit)
    {
        x = (uint16_t)x;
        if (o & 2)
            hci_base[o>>2] = (hci_base[o>>2] & 0xFFFF) | (x << 16);
        else
            hci_base[o>>2] = (hci_base[o>>2] & 0xFFFF0000) | x;
    }
    else
    {
        volatile uint16_t *hci_halfwords = (volatile uint16_t *)hci_base;
        hci_halfwords[o>>1] = x;
    }
}

int bus_space_read_2 (bus_space_tag_t iot, bus_space_handle_t ioh, int o)
{
    uint32_t value;
    if (registers_32bit)
    {
        if (o & 2)
            value = hci_base[o>>2] >> 16;
        else
            value = hci_base[o>>2];
        value = (uint16_t)value;
    }
    else
    {
        volatile uint16_t *hci_halfwords = (volatile uint16_t *)hci_base;
        value = hci_halfwords[o>>1];
    }
    dprintf(("bsdfns_8", "read2 %x from %p\n", value, (uintptr_t)hci_base + o));
    return value;
}

void bus_space_write_1 (bus_space_tag_t iot, bus_space_handle_t ioh, int o, int x)
{
    dprintf (("bsdfns_8", "write1 %x to %p\n", x, (uintptr_t)hci_base + o));
    if (registers_32bit)
    {
        size_t shift = (o & 3) * 8; /* Bits */
        x = (uint8_t)x;
        hci_base[o>>2] = (hci_base[o>>2] & ~(0xFFuL << shift)) | (x << shift);
    }
    else
    {
        volatile uint8_t *hci_bytes = (volatile uint8_t *)hci_base;
        hci_bytes[o] = x;
    }
}

int bus_space_read_1 (bus_space_tag_t iot, bus_space_handle_t ioh, int o)
{
    uint32_t value;
    if (registers_32bit)
    {
        size_t shift = (o & 3) * 8; /* Bits */
        value = hci_base[o>>2] >> shift;
        value = (uint8_t)value;
    }
    else
    {
        volatile uint8_t *hci_bytes = (volatile uint8_t *)hci_base;
        value = hci_bytes[o];
    }
    dprintf(("bsdfns_8", "read1 %x from %p\n", value, (uintptr_t)hci_base + o));
    return value;
}

/*---------------------------------------------------------------------------*/
/* USB transfer state machine interactions passed to USBDriver               */
/*---------------------------------------------------------------------------*/
usbd_status
usb_insert_transfer(usbd_xfer_handle xfer)
{
    usbd_status status = USBD_CANCELLED; /* Should _swix() error */
    _swix (USBDriver_InsertTransfer, _IN (0) | _OUT (0), xfer, &status);
    return status;
}

void
usb_transfer_complete(usbd_xfer_handle xfer)
{
    _swix (USBDriver_TransferComplete, _IN (0), xfer);
}

void
usb_schedsoftintr (struct usbd_bus* sc)
{
    dprintf (("Main_0", "Scheduling soft interrupt\n"));
    _swix (USBDriver_ScheduleSoftInterrupt, _IN(0), sc);
}
