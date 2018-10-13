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
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#include "swis.h"

#include "sys/types.h"
#include "sys/systm.h"

#include "machine/bus.h"

#include "dev/usb/usb.h"
#include "dev/usb/usbdi.h"
#include "dev/usb/usbdivar.h"
#include "ohcireg.h"
#include "ohcivar.h"

#include "Global/RISCOS.h"
#include "Global/Services.h"
#include "Global/HALEntries.h"
#include "Global/OSRSI6.h"
#include "Global/OSMisc.h"
#include "Global/OsBytes.h"
#include "Interface/PCI.h"
#include "Interface/USBDriver.h"
#include "USB/USBDevFS.h"
#include "AsmUtils/callbacks.h"
#include "callx/callx.h"
#include "toolbox.h"
#include "OHCIDriverHdr.h"
#include "DebugLib/DebugLib.h"

#define ErrorBase_OHCIDriver 0x820A00
#define ErrorBlock_OHCI_NoReinit    { (ErrorBase_OHCIDriver+0), "NumParm" }
#define ErrorBlock_OHCI_NoOHCI      { (ErrorBase_OHCIDriver+1), "E01"     }
#define ErrorBlock_OHCI_ClaimVeneer { (ErrorBase_OHCIDriver+2), "E02"     }
#define ErrorBlock_OHCI_USBTooOld   { (ErrorBase_OHCIDriver+3), "E03"     }
typedef struct
{
    int  errnum;
    char errtok[8];
} _kernel_tokerror;

/* for debugging */
#ifdef OHCI_DEBUG
extern int ohcidebug;
extern int usbdebug;

/* debug for phase locking with vsync */
static int fm = 0;
static int target_fm = 11840;
static int vsync_count = 0;
static int print_fm = 0;
static int fm_interval = 11999;

char debugname[16];

int unhandled_irqs;
int irqs;
unsigned int irq_min = INT_MAX, irq_max = 0;
unsigned long long irq_tot;
#endif

extern int * init_veneer (void);
extern void* resource_files (void);
#ifdef OHCI_DEBUG
extern void ohci_dumpregs (ohci_softc_t *);
extern void ohci_dump_ed (ohci_soft_ed_t*);
#endif
extern void ohci_abort_xfer (void*, int);

static void *private_word;
static MessagesFD mod_messages;
volatile int* hci_base;
ohci_softc_t ohci_soft;
struct device * usb_soft=NULL;

extern char panic_string[255];

int* magic = NULL;

int pci_device = -1;
int hal_device = -1;
int instance = 0;
int device_number;
int registers_32bit=0;
static bool registering=false; /* True/false for whether we're in the middle of registering. Avoids nested registration attempt during ROM init. */

/*---------------------------------------------------------------------------*/
/* Port power controls - only used by HAL devices                            */
/*---------------------------------------------------------------------------*/
void (*ohci_ppower)(int port, int state);
int  (*ohci_error)(int port); /* Never gets used? */
void (*ohci_pirqclear)(int port);
static _kernel_oserror *ppower_statemachine(_kernel_swi_regs *, void *, void *);
static int hal_oc_device[15]; /* One over current device per port, max for OHCI is 15 */
static bool hal_oc_device_claimed[15];
typedef struct p_err_chk
{
    int unit;
    enum
    {
        P_none,
        P_on,
        P_off,
        P_going_on,
        P_going_on2,
        P_ready,
        P_retry
    } state;
} p_err_chk;
static p_err_chk pchk;

/* Read overcurrent state of port (1's based numbering).
 * Returns 0 if OK, non-0 if overcurrent
 */
static int do_hal_perror(int port)
{
    int r;
    _swix(OS_Hardware, _INR(0,1)|_INR(8,9)|_OUT(0),
                       hal_device, port - 1,
                       OSHW_CallHAL, EntryNo_HAL_USBPortIRQStatus,
                       &r);

    return r;
}

static int do_ohci_perror(int port)
{
    return hci_base[OHCI_RH_PORT_STATUS(port)/4] & UPS_OVERCURRENT_INDICATOR
             ? 1 : 0;
}                           

/* Clear the overcurrent interrupt for the port (1's based numbering) */
static void do_hal_pirqclear(int port)
{
    _swix(OS_Hardware, _INR(0,1)|_INR(8,9),
                       hal_device, port - 1,
                       OSHW_CallHAL, EntryNo_HAL_USBPortIRQClear);
}

static void do_ohci_pirqclear(int port)
{
    /* Not implemented */
}

/* Turn on power to port (1's based numbering) */
static void do_hal_ppower(int port, int state)
{
    dprintf(("", "HAL port %d power state %d\n", port - 1, state));
    _swix(OS_Hardware, _INR(0,2)|_INR(8,9), hal_device, port - 1, state,
                                            OSHW_CallHAL, EntryNo_HAL_USBPortPower);
  
    /* Only allowed to monitor overcurrent status if port is on */
    if (hal_oc_device[port - 1] != -1)
    {
        if (state && !hal_oc_device_claimed[port - 1])
        {
            pchk.state = P_going_on;
            pchk.unit = port;
            /* Give it a little turn on time before grumbling */
            callx_add_callafter(USB_PORT_RESET_DELAY/10, ppower_statemachine, (void *)&pchk);
        }
        else
        {
            if (!state)
            {
                pchk.state = P_retry;
                pchk.unit = port;
                /* Try again after a delay of a second or so */  
                callx_add_callafter(100, ppower_statemachine, (void *)&pchk);
                if (hal_oc_device_claimed[port - 1])
                {
                    do_hal_pirqclear(port);
                    _swix(OS_ReleaseDeviceVector, _INR(0,2),
                                           hal_oc_device[port - 1],
                                           usb_overcurrent_entry, private_word);
                    hal_oc_device_claimed[port - 1] = false;
                }
            }
        }
    }
}

static void do_ohci_ppower(int port, int state)
{
    dprintf (("", "OHCI port %d power state %d\n", port, state));
    hci_base[OHCI_RH_PORT_STATUS(port)/4] =
        state ? UPS_PORT_POWER : UPS_LOW_SPEED;
}

static void do_dummy_ppower(int port, int state)
{
    /* Do nothing for PCI devices */
}

static _kernel_oserror *ppower_statemachine(_kernel_swi_regs *r, void *pw, void *v)
{
    p_err_chk *p = (p_err_chk *)v;
    switch(p->state)
    {
        case P_going_on:
            if (do_hal_perror(p->unit))
            {
                /* Power is not yet good, wait a little longer */
                p->state = P_going_on2;
                callx_add_callafter(USB_PORT_RESET_DELAY/10, ppower_statemachine, v);
                break;
            }
            /* Else fall through */
        case P_going_on2:
            if (do_hal_perror(p->unit))
            {
                /* Power is still not good, turn it off */
                p->state = P_off;
                do_hal_ppower(p->unit, 0);
                break;
            }
            /* Else fall through */
        case P_ready:
            /* Power on, and not overcurrent yet, monitor it normally */
            do_hal_pirqclear(p->unit);
            _swix(OS_ClaimDeviceVector, _INR(0,2),
                  hal_oc_device[p->unit - 1], usb_overcurrent_entry, private_word);
            _swix(OS_Hardware, _IN(0) | _INR(8,9), hal_oc_device[p->unit - 1],
                               OSHW_CallHAL, EntryNo_HAL_IRQEnable);
            hal_oc_device_claimed[p->unit - 1] = true;
            p->state = P_on;
            break;
        case P_retry:
            /* Try turning on again */ 
            do_hal_ppower(p->unit, 1);
            break;         
    }
    return NULL;
}

int usb_overcurrent_handler(_kernel_swi_regs *r, void *pw)
{
    size_t i;
    int    test, devno = r->r[0] & 0xFFFFFF; /* Knock out ClaimDeviceVector flags */

    /* This single handler is registered for all the port overcurrents, so
     * we need to match up the device number with a port in our table. Note,
     * the device numbers might be shared, in which case only the first hit
     * claims (any subsequent ones will come back here anyway).
     */
    for (i = 0; i < (sizeof(hal_oc_device) / sizeof(hal_oc_device[0])); i++)
    {
        test = hal_oc_device[i] & 0xFFFFFF; 
        if ((devno == test) && do_hal_perror(i + 1))
        {
            /* Claim this one, it's one of ours, and is interrupting */
            do_hal_pirqclear(i + 1);
            _swix(OS_Hardware, _IN(0)|_INR(8,9), test,
                                                 OSHW_CallHAL, EntryNo_HAL_IRQClear);
            do_hal_ppower(i + 1, 0); /* Power off please */
            return 0;
        }
    }
    return 1;
}

/*---------------------------------------------------------------------------*/
/* Driver instance creation                                                  */
/*---------------------------------------------------------------------------*/
void build_veneer (int* vn, int* st, size_t sz)
{
    int i;
    dprintf (("", "writing veneer from %p at %p\n", st, vn));
    int* entry_table = vn + sz / sizeof (void*);
    for (i = 0; i < sz / sizeof (void*); ++i) {
        int* entry = entry_table + 2 * i;

        /* if the method isn't implemented, don't veneer it */
        if (st[i] == NULL) continue;

        /* copy function pointer into veneer */
        vn[i] = st[i];

        /* copy new pointer into structure */
        st[i] = (int) entry;

        /* LDR ip, function[i] */
        entry[0] = 0xe51fC000       /* LDR ip, [pc, #-0] */
                  + 8               /* go back to current instruction */
                  + i * 8           /* go back to beginning of veneers */
                  + sz              /* go back to beginning of struct */
                  - i * 4;          /* go to func pointer */

        /* B common */
        entry[1] = 0xea000000       /* B here + 8 */
                  | ((magic - entry - 1) & 0x00ffffff);
                                    /* branch to diff */
    }
    _swix(OS_SynchroniseCodeAreas, _INR(0,2), 1,
                                   entry_table,
                                   entry_table + 2 * (sz / sizeof (void*)) - 1);
}

_kernel_oserror* register_bus(void *in,struct device **out)
{
    *out = NULL;
    /* Check USBDriver is new enough */
    int version;
    _kernel_oserror *e = _swix(USBDriver_Version,_OUT(0),&version);
    if(e)
        return e;
    if(version < RISCOS_USBDRIVER_API_VERSION)
    {
        static const _kernel_tokerror err_usbtooold = ErrorBlock_OHCI_USBTooOld;
    
        return _swix (MessageTrans_ErrorLookup, _INR(0,2),
                      &err_usbtooold, &mod_messages, 0 /* Internal buffer */);
    }

    /* Now attempt to register */
    registering = true;
    e = _swix(USBDriver_RegisterBus, _INR(0,1)|_OUT(0),in,RISCOS_USBDRIVER_API_VERSION,out);
    if(e) *out = NULL;
    registering = false;
    return e;
}

static void name_root_hub(int pcidevice)
{
    if (pci_device == -1)
    {
        _kernel_oserror *e;

        e = _swix (MessageTrans_Lookup, _INR(0,3),
                   &mod_messages, "UkRoot", ohci_soft.sc_vendor, sizeof(ohci_soft.sc_vendor));
        if (e) strcpy(ohci_soft.sc_vendor, " ");
    }
    else
    {
        char *v = NULL;
    
        _swix (PCI_ReadInfo, _INR(0,3), PCI_ReadInfo_Vendor, &v, sizeof(v), pci_device);
        if (v == NULL) v = " ";
        strncpy (ohci_soft.sc_vendor, v, sizeof ohci_soft.sc_vendor-1);
    }
}

_kernel_oserror* new_instance (_kernel_swi_regs* r, void* pw, void* h)
{
    _kernel_oserror * e;

    (void) r;
    (void) pw;
    (void) h;

    /* fill in the device name in the callback so that our service call handler
       is threaded and there to respond to PCI calls */
    name_root_hub(pci_device);

    /* register with the usbdriver module if it's already resident */
    dprintf (("", "Registering with USB driver\n"));
    e = register_bus(&ohci_soft, &usb_soft);
    if (e)
    {
        dprintf (("", "Failed to register: %s\n", e->errmess));
    }
    else
    {
        dprintf (("", "Init-Registering with USB driver-done\n"));
    }

    /* allow enough space for name, % and number, then space, device type,
       and another number */
    char name[sizeof Module_Title + 1 + 12 + 1 + 1 + 12];
    sprintf (name, Module_Title"%%%d %c%d", instance + 1, (pci_device>=0?'P':'H'), (pci_device>=0?pci_device:hal_device));
    dprintf (("", "Trying to start %s\n", name));
    e = _swix (OS_Module, _INR(0,1), 14, name);

    if (e)
    {
        dprintf (("", "Failed to start %s: %s\n", name, e->errmess));
    }
    return NULL;
}

/*---------------------------------------------------------------------------*/
/* CMHG module initialisation                                                */
/*---------------------------------------------------------------------------*/
_kernel_oserror *module_init(const char *cmd_tail, int podule_base, void *pw) {
    size_t i;
    _kernel_oserror *e;
    struct
    {
        int type;
        int flags;
        void *hw;
        int devno;
    } usbinfo;

    *panic_string = '\0';

    callx_init (pw);

    /* set up debugging */
#ifdef OHCI_DEBUG
    sprintf(debugname,"OHCIDrv-%d",podule_base);
#endif
    debug_initialise (debugname, 0, 0);
    debug_set_device(DEBUGIT_OUTPUT);
    debug_set_unbuffered_files (TRUE);
    /* Can't set debug_set_stamp_debug(TRUE) - causes interrupts to be briefly enabled during debug output, which breaks all kinds of stuff */
/*    debug_set_stamp_debug (TRUE); */

    dprintf (("Main_0", "Starting driver\n"));

    /* simulate having one OHCI device attached.  This section has to
    communicate with HAL or podule manager to find out where it can read/write    to some OHCI registers */

    /* assume podule_base is actually instantiation number - how to do this
       in a HAL world?  If we're the first instance, then search for devices
       on the PCI bus */

    instance = podule_base;


    /* if we're the first instance, then start searching from device # 0,
       otherwise the device to start searching from was passed as a string
       in the command tail */

    if (podule_base != 0)
    {
        const char* endptr = cmd_tail;
        while(*endptr == ' ')
            endptr++;
        if(*endptr == 'P')
            pci_device = (int) strtol (endptr+1, NULL, 0);
        else if(*endptr == 'H')
            hal_device = (int) strtol (endptr+1, NULL, 0);
        else
        {
            static const _kernel_tokerror err_noreinit = ErrorBlock_OHCI_NoReinit;

            return _swix (MessageTrans_ErrorLookup, _INR(0,2),
                          &err_noreinit, 0 /* Global messages */, 0 /* Internal buffer */);
        }
    }
    else
    {
        pci_device = 0;
#ifndef ROM
        /* Only first instance registers the messages in ResourceFS */
        e = _swix (ResourceFS_RegisterFiles, _IN (0), resource_files ());
        if (e != NULL) return e;
#endif
    }

    e = _swix (MessageTrans_OpenFile, _INR(0,2),
        &mod_messages,
        Module_MessagesFile,
        0);
    if (e) goto error_dereg;

    /* find the next possible controller */
    if(pci_device >= 0)
    {
        /* Looking for PCI device */
        e = _swix(PCI_FindByClass, _INR(0,1)|_IN(3)|_OUT(3),
            0x0C0310,
            0xFFFFFF,
            pci_device,
            &pci_device);
        if(!e)
        {
             dprintf (("", "Found OHCI controller on PCI device %d\n", pci_device));
            e = _swix(PCI_ReadInfo, _INR(0,3),
                PCI_ReadInfo_IntDeviceVector,
                &device_number,
                sizeof device_number,
                pci_device);
            if (e) goto error;
        
            e = _swix(PCI_HardwareAddress, _INR(0,1)|_IN(3)|_OUT(4),
                0, 0, pci_device, &hci_base);
            if (e) goto error;
        
            ohci_ppower = do_dummy_ppower;
        }
        else
        {
            /* Reached end of list */
            pci_device = -1;
        }
    }
    if(pci_device == -1)
    {
        size_t usbinfolen;

        /* Looking for HAL device */
        do {
            hal_device++;

            e = _swix(OS_Hardware, _INR(0,2)|_INR(8,9)|_OUT(0),
                                   hal_device, &usbinfo, sizeof usbinfo,
                                   OSHW_CallHAL, EntryNo_HAL_USBControllerInfo,
                                   &usbinfolen);
            if (!e && (usbinfolen == sizeof(usbinfo)) && (usbinfo.type == HALUSBControllerType_OHCI))
            {
                dprintf (("", "Found OHCI controller on HAL device %d\n", hal_device));
                device_number = usbinfo.devno;
                hci_base = usbinfo.hw;
                
                if (usbinfo.flags & HALUSBControllerFlag_HAL_Port_Power)
                {
                    ohci_ppower = do_hal_ppower;
                }
                else
                {
                    ohci_ppower = do_ohci_ppower;
                }
                if (usbinfo.flags & HALUSBControllerFlag_HAL_Over_Current)
                {
                    ohci_error = do_hal_perror;
                    ohci_pirqclear = do_hal_pirqclear;
                }
                else
                {
                    ohci_error = do_ohci_perror;
                    ohci_pirqclear = do_ohci_pirqclear;
                }
                break;
            }
            else if(e || !usbinfolen)
            {
                /* Reached end of list */
                static const _kernel_tokerror err_noohci = ErrorBlock_OHCI_NoOHCI;
            
                e = _swix (MessageTrans_ErrorLookup, _INR(0,2),
                           &err_noohci, &mod_messages, 0 /* Internal buffer */);
                goto error;
            }
        } while(1);
    }

    dprintf (("Main_0", "interrupt device %d\n", device_number));
    dprintf (("Main_0", "hardware address %p\n", hci_base));

    /* Build a table of port overcurrent device numbers to ports */
    for (i = 0; i < (sizeof(hal_oc_device) / sizeof(hal_oc_device[0])); i++)
    {
        if (usbinfo.flags & HALUSBControllerFlag_HAL_Over_Current)
        {
            _swix(OS_Hardware, _INR(0,1)|_INR(8,9)|_OUT(0),
                               hal_device, i,
                               OSHW_CallHAL, EntryNo_HAL_USBPortDevice,
                               &hal_oc_device[i]);
            if (hal_oc_device[i] != -1)
            {
                dprintf(("", "HAL port %d is overcurrent device %d\n", i, hal_oc_device[i])); 
            }
        }
        else
        {
            hal_oc_device[i] = -1; /* Not used */
        }
        hal_oc_device_claimed[i] = false;
    }

    memset (&ohci_soft, 0, sizeof ohci_soft);

    sprintf (ohci_soft.sc_bus.bdev.dv_xname, "OHCI%d", instance);
    ohci_soft.sc_irqdevno = device_number;
    dprintf (("Main_0", "interrupt device %d\n", device_number));
    dprintf (("Main_0", "hardware address %p\n", hci_base));

    private_word = pw;

#ifdef OHCI_DEBUG
    const char *c = getenv("ohcidebug");
    usbdebug = ohcidebug = (c?atoi(c):0);
#endif

    if ((magic = init_veneer ()) == NULL)
    {
        static const _kernel_tokerror err_claimveneer = ErrorBlock_OHCI_ClaimVeneer;
    
        e = _swix (MessageTrans_ErrorLookup, _INR(0,2),
                   &err_claimveneer, &mod_messages, 0 /* Internal buffer */);
        goto error;
    }
    dprintf (("", "magic at %p", magic));

    _swix (OS_ClaimDeviceVector, _INR(0,2),
        device_number | ((pci_device == -1)?0:(1u<<31)),
        usb_irq_entry, pw);
    _swix (OS_Hardware, _IN(0) | _INR(8,9),
        device_number, OSHW_CallHAL, EntryNo_HAL_IRQEnable);

    /* for the L7205, clocks need to be started */
    /* in BSD this is called from sys/pci/ohci_pci.c */
    ohci_init (&ohci_soft);

    dprintf (("", "Finished module initialisation\n"));

#ifdef OHCI_DEBUG
    /* if we're sharing an interrupt with the video card */
    if (device_number == 62 && getenv("vsync"))
    {
        vsync_count++;
        _swix (OS_Claim, _INR(0, 2), EventV, vsync_entry, pw);
        _kernel_osbyte (OsByte_EnableEvent, Event_VSync, 0);
    }
#endif

    /* try and start a new instance to catch any more controllers on the bus,
       done in a callback so that this instance is threaded and the instance
       count goes up */
    /* also register with the usbdriver module if it's already resident */

    callx_add_callback (new_instance, 0);

    return NULL;

error:
    dprintf (("Failed initialisation: %s\n", e->errmess));
    _swix (MessageTrans_CloseFile, _IN(0), &mod_messages);
error_dereg:
#ifndef ROM
    if (podule_base == 0) _swix (ResourceFS_DeregisterFiles, _IN(0), resource_files ());
#endif
    return e;
}

/*---------------------------------------------------------------------------*/
/* CMHG module finalisation                                                  */
/*---------------------------------------------------------------------------*/
_kernel_oserror *module_final(int fatal, int podule, void *pw)
{
    int v;
    volatile int* ob = hci_base;

    dprintf (("", "OHCIDriver finalising\n"));

    if (usb_soft != NULL)
    {
        _swix (USBDriver_DeregisterBus, _IN(0), usb_soft);
        usb_soft=NULL;
    }

#ifdef OHCI_DEBUG
    module_commands (0, 0, CMD_OHCIEDS, pw);
#endif

    dprintf (("", "Bus deregistered\n"));

    /* reset the controller */
    ob[OHCI_COMMAND_STATUS / 4] = OHCI_HCR;
    v = ob[OHCI_COMMAND_STATUS]; // flush the write
    while (ob[OHCI_COMMAND_STATUS / 4] & OHCI_HCR);
    ob[OHCI_CONTROL / 4] = OHCI_HCFS_RESET;

    v = ob[OHCI_CONTROL / 4]; // flush the write

    callx_remove_all_callbacks ();
    callx_remove_all_callafters ();
    callx_remove_all_calleverys ();

    /* don't disable the interrupt since it is shared, the OS will disable it
       when noone is left responding */

    _swix (OS_ReleaseDeviceVector, _INR(0,2),
        device_number | ((pci_device == -1)?0:(1u<<31)),
        usb_irq_entry, pw);

    for (v = 0; v < (sizeof(hal_oc_device) / sizeof(hal_oc_device[0])); v++)
    {
        if (hal_oc_device_claimed[v] && (hal_oc_device[v] != -1))
        {
            _swix(OS_ReleaseDeviceVector, _INR(0,2),
                  hal_oc_device[v], usb_overcurrent_entry, private_word);
        }
    }                         

    if (magic) _swix (OS_Module, _IN(0)|_IN(2), 7, magic);

#ifdef OHCI_DEBUG
    /* if we're sharing an interrupt with the video card */
    if (device_number == 62 && vsync_count)
    {
        _kernel_osbyte (OsByte_DisableEvent, Event_VSync, 0);
        _swix (OS_Release, _INR(0, 2), EventV, vsync_entry, pw);
    }
#endif

    _swix (MessageTrans_CloseFile, _IN(0), &mod_messages);

#ifndef ROM
    /* only remove files for last instantiation */
    if (podule == 0)
    {
        _swix (ResourceFS_DeregisterFiles, _IN (0), resource_files ());
    }
#endif

// need to do something here eventually
//    ohci_detach (&ohci_soft, 0);


    return NULL;
}

/*---------------------------------------------------------------------------*/
/* CMHG module service calls                                                 */
/*---------------------------------------------------------------------------*/
static void service_pci (_kernel_swi_regs* r)
{
    dprintf (("", "Service PCI, r0 = %x, r1 = %x, r2 = %x\n",
        r->r[0], r->r[1], r->r[2]));
    char tok[10];
    unsigned int p;
    switch (r->r[2])
    {
    case 0:
        _swix (PCI_ReadInfo, _INR(0,3),
            PCI_ReadInfo_DeviceID,
            &p,
            sizeof p,
            r->r[3]);
        sprintf (tok, "D%04X%04X", p & 0xffff, p >> 16);
        break;
    case 1:
        sprintf (tok, "V%04X", r->r[0]);
        break;
    default:
        return;
    }

    /* claim service call if lookup was successful */
    if (NULL == _swix (MessageTrans_Lookup, _INR(0,2)|_OUT(2),
        &mod_messages,
        tok,
        0,
        r->r + 2))
    {
        r->r[1] = 0;
    }
    else
    {
        dprintf (("", "Couldn't find token %s\n", tok));
    }
}

void module_services(int service_number, _kernel_swi_regs *r, void *pw)
{
    switch (service_number) {
    case Service_PCI:
        service_pci (r);
        break;
    case Service_PreReset:
        /* reset the controller */
        hci_base[OHCI_COMMAND_STATUS / 4] = OHCI_HCR;
        magic = (int*) hci_base[OHCI_COMMAND_STATUS]; // flush the write
        while (hci_base[OHCI_COMMAND_STATUS / 4] & OHCI_HCR);
        hci_base[OHCI_CONTROL / 4] = OHCI_HCFS_RESET;

        magic = (int*) hci_base[OHCI_CONTROL]; // flush the write
        callx_remove_all_callbacks ();
        callx_remove_all_callafters ();
        callx_remove_all_calleverys ();
        _swix (OS_ReleaseDeviceVector, _INR(0,2),
            device_number | ((pci_device == -1)?0:(1u<<31)),
            usb_irq_entry, pw);
    
        for (int i = 0; i < (sizeof(hal_oc_device) / sizeof(hal_oc_device[0])); i++)
        {
            if (hal_oc_device_claimed[i] && (hal_oc_device[i] != -1))
            {
                _swix(OS_ReleaseDeviceVector, _INR(0,2),
                      hal_oc_device[i], usb_overcurrent_entry, private_word);
            }
        }                         
        break;
    case Service_USB:
        switch (r->r[0]) {
        case Service_USB_USBDriverStarting:
            if ((usb_soft == NULL) && !registering)
            {
                dprintf (("", "Registering with USB driver from svcecall\n"));
                _kernel_oserror *e = register_bus(&ohci_soft,&usb_soft);
                if(e)
                {
                    dprintf (("", "Failed to register: %s\n", e->errmess));
                }
                else
                {
                    dprintf (("", "Registering with USB driver from svcecall-done\n"));
                }
            }
            break;
        case Service_USB_USBDriverDying:
            dprintf (("", "Deregistering with USB driver\n"));
            /* USBDriver will do the deregistering at this point, since
               it's SWIs are not active anymore */
            usb_soft = NULL;
            memset (&ohci_soft, 0, sizeof ohci_soft);
            sprintf (ohci_soft.sc_bus.bdev.dv_xname, "OHCI%d", instance);
            name_root_hub (pci_device);
            ohci_init (&ohci_soft);
            break;
        }
        break;
#ifndef ROM
    case Service_ResourceFSStarting:
        /* Re-register the messages */
        (*(void (*)(void *, void *, void *, void *))r->r[2]) (resource_files (), 0, 0, (void *)r->r[3]);
        break;
#endif
    }
}

#ifdef OHCI_DEBUG
/*---------------------------------------------------------------------------*/
/* CMHG module commands - only used for debugging                            */
/*---------------------------------------------------------------------------*/
_kernel_oserror *module_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
#define OREAD(o) hci_base[o/4]

    switch (cmd_no) {
    case CMD_OHCIRegs:
        printf
        (
            "PCI device                %8d\n"
            "All IRQs                  %8d\n"
            "Unhandled IRQs            %8d\n"
            "(Handled IRQs)            %8d\n"
            "Min IRQ time              %8d\n"
            "Max IRQ time              %8d\n"
            "Ave IRQ time              %8d\n"
            "VSyncs                    %8d\n"
            "Registers at              %8X\n"
            "%2X Revision               %8.8X\n"
            "%2X Control                %8.8X\n"
            "%2X Command                %8.8X\n"
            "%2X IRQ status             %8.8X\n"
            "%2X IRQ enable             %8.8X\n"
            "%2X HCCA                   %8.8X\n"
            "%2X Periodic Current ED    %8.8X\n"
            "%2X Control Head           %8.8X\n"
            "%2X Control Current        %8.8X\n"
            "%2X Bulk Head              %8.8X\n"
            "%2X Bulk Current           %8.8X\n"
            "%2X OHCI done head         %8.8X\n"
            "%2X FM Interval            %8.8X\n"
            "%2X FM Remaining           %8.8X\n"
            "%2X FM Number              %8.8X\n"
            "%2X Periodic start         %8.8X\n"
            "%2X LS Threshold           %8.8X\n"
            "%2X RH descriptorA         %8.8X\n"
            "%2X RH descriptorB         %8.8X\n"
            "%2X Status                 %8.8X\n"
            "%2X Port 1                 %8.8X\n"
            "%2X Port 2                 %8.8X\n"
            "%2X (Port 3)               %8.8X\n"
            "Errors: %s\n",
            pci_device,
            irqs,
            unhandled_irqs,
            irqs - unhandled_irqs,
            irq_min,
            irq_max,
            (irqs - unhandled_irqs)?
                (unsigned int) (irq_tot / (irqs - unhandled_irqs)): 0,
            vsync_count,
            hci_base,
            OHCI_REVISION, OREAD(OHCI_REVISION),
            OHCI_CONTROL, OREAD(OHCI_CONTROL),
            OHCI_COMMAND_STATUS, OREAD(OHCI_COMMAND_STATUS),
            OHCI_INTERRUPT_STATUS, OREAD(OHCI_INTERRUPT_STATUS),
            OHCI_INTERRUPT_ENABLE, OREAD(OHCI_INTERRUPT_ENABLE),
            OHCI_HCCA, OREAD(OHCI_HCCA),
            OHCI_PERIOD_CURRENT_ED, OREAD(OHCI_PERIOD_CURRENT_ED),
            OHCI_CONTROL_HEAD_ED, OREAD(OHCI_CONTROL_HEAD_ED),
            OHCI_CONTROL_CURRENT_ED, OREAD(OHCI_CONTROL_CURRENT_ED),
            OHCI_BULK_HEAD_ED, OREAD(OHCI_BULK_HEAD_ED),
            OHCI_BULK_CURRENT_ED, OREAD(OHCI_BULK_CURRENT_ED),
            OHCI_DONE_HEAD, OREAD(OHCI_DONE_HEAD),
            OHCI_FM_INTERVAL, OREAD(OHCI_FM_INTERVAL),
            OHCI_FM_REMAINING, OREAD(OHCI_FM_REMAINING),
            OHCI_FM_NUMBER, OREAD(OHCI_FM_NUMBER),
            OHCI_PERIODIC_START, OREAD(OHCI_PERIODIC_START),
            OHCI_LS_THRESHOLD, OREAD(OHCI_LS_THRESHOLD),
            OHCI_RH_DESCRIPTOR_A, OREAD(OHCI_RH_DESCRIPTOR_A),
            OHCI_RH_DESCRIPTOR_B, OREAD(OHCI_RH_DESCRIPTOR_B),
            OHCI_RH_STATUS, OREAD(OHCI_RH_STATUS),
            OHCI_RH_PORT_STATUS(1), OREAD(OHCI_RH_PORT_STATUS(1)),
            OHCI_RH_PORT_STATUS(2), OREAD(OHCI_RH_PORT_STATUS(2)),
            OHCI_RH_PORT_STATUS(3), OREAD(OHCI_RH_PORT_STATUS(3)),
            panic_string
        );
        *panic_string = '\0';

        ohci_dumpregs (&ohci_soft);
        break;
    case CMD_OHCIEDS:
        {
            ohci_soft_ed_t* sed;
            sed = ohci_soft.sc_isoc_head;
            dprintf (("", "Isochronous endpoints\n"));
            while (sed != NULL) {
                ohci_dump_ed(sed);
                sed = sed->next;
            }
            sed = ohci_soft.sc_ctrl_head;
            dprintf (("", "\n\nControl endpoints\n"));
            while (sed != NULL) {

                ohci_dump_ed(sed);
                sed = sed->next;
            }
            sed = ohci_soft.sc_bulk_head;
            dprintf (("", "\n\nBulk endpoints\n"));
            while (sed != NULL) {
                ohci_dump_ed(sed);
                sed = sed->next;
            }
            break;
        }
    case CMD_OHCIWrite:
        {
        int a, b;
        char* ptr;
        a = (int) strtoul (arg_string, &ptr, 16);
        b = (int) strtoul (ptr, 0, 16);
        printf ("writing %x to %x\n", b, a);
        hci_base[a / 4] = b;
        }
        break;
    case CMD_OHCIDebug:
        {
        char* ptr;
        ohcidebug = (int) strtoul (arg_string, &ptr, 0);
        if (ptr) usbdebug = (int) strtoul (ptr, &ptr, 0);
        }
        break;
    case CMD_TargetFM:
        target_fm = (int) strtol (arg_string, NULL, 10);
        break;
    default:
        break;
    }

    return 0;
}
#endif

#ifdef OHCI_DEBUG
int vsync(_kernel_swi_regs *r, void *pw)
{
    vsync_count++;
//    if (print_fm == 0) return 1;
//    print_fm = 0;

    /* fm is the amount of ticks left in this frame.  we'd like it to be zero,
       so that we're hitting the vsync exactly.  to this end, if it's greater
       than half the interval, we subtract it from the interval to make give us
       a negative value which is ticks since the last frame */
    fm = hci_base[OHCI_FM_REMAINING/4] & ~OHCI_FIT;

    /* the pattern of vsyncs repeats every 3 */
    static int n = 1;
    if (++n == 4) n = 1;

    int f = (fm + 12000 - target_fm) % 4000;
    if (f > 2000) f = f - 4000;

    /* if fm was positive, then our frames aren't long enough, if fm was
       negative, then the frames too long */
    fm_interval = 11999;
    if (f < 0) fm_interval = 12000;
    if (f > 0) fm_interval = 11998;

    int ival = hci_base[OHCI_FM_INTERVAL / 4];
    hci_base[OHCI_FM_INTERVAL/4] =
        ((ival & OHCI_FIT) ^ OHCI_FIT) | OHCI_FSMPS(fm_interval) | fm_interval;

//    if (print_fm)
//        dprintf (("", "%08d, %08d, fm = %05d, fm_interval = %05d\n",
//            irqs, vsync_count, fm, fm_interval));
    print_fm = 0;

    return 1;
}
#endif

/*---------------------------------------------------------------------------*/
/* CMHG interrupt veneer handler                                             */
/*---------------------------------------------------------------------------*/
int usb_irq_handler(_kernel_swi_regs *r, void *pw)
{
    int ret;
#ifdef OHCI_DEBUG
    int u2s, u2s1;
    _swix (OS_Hardware, _INR(8,9)|_OUT(0),
        OSHW_CallHAL, EntryNo_HAL_CounterRead, &u2s);
    irqs++;
#endif


    // ohci_intr returns 0 for failure, 1 for success, the inverse of what
    // we're expected to return

    /* interrupts must be left off for the duration of this call, otherwise
       it hangs */
      ret = !ohci_intr (&ohci_soft);
      // the chip requires its interrupts cleared
      if (pci_device == -1)
         _swix(OS_Hardware, _IN(0)|_INR(8,9), device_number,
                                           OSHW_CallHAL, EntryNo_HAL_IRQClear);

#ifdef OHCI_DEBUG
    if (ret)
    {
        unhandled_irqs++;
    }
    else
    {
        _swix (OS_Hardware, _INR(8,9)|_OUT(0),
            OSHW_CallHAL, EntryNo_HAL_CounterRead, &u2s1);
        int t = (u2s - u2s1) * 5;
        if (t < 0) t += 10000000; /* it wrapped */
//        if (ohcidebug > 1) dprintf(("", "irq for: %d nsecs\n", t));
        irq_tot += t;
        if (t < irq_min) irq_min = t;
        if (t > irq_max) irq_max = t;
    }
#endif


    return ret;
}

int
softintr (_kernel_swi_regs* r, void* pw)
{
    ohci_softintr ((void*) r->r[0]);
    return 0; /* Claim */
}

/*---------------------------------------------------------------------------*/
/* RISC OS specific leaf functions                                           */
/*---------------------------------------------------------------------------*/
void triggercbs(void)
{
    static volatile int *IRQsema = NULL;

    if (IRQsema == NULL)
    {
        _swix(OS_ReadSysInfo, _INR(0,2) | _OUT(2),
              6, 0, OSRSI6_IRQsema, &IRQsema);
        if (IRQsema == NULL) IRQsema = (volatile int *)0x108; /* Legacy_IRQsema */
    }
    if (*IRQsema == 0)
    {
        /* Not threaded in an IRQ, OK to do callbacks */
        usermode_donothing();
    }
}

void riscos_irqclear(int devno)
{
    _swix(OS_Hardware, _IN(0)|_INR(8,9), devno, 0, EntryNo_HAL_IRQClear);
}

static _kernel_oserror *_riscos_abort_pipe (_kernel_swi_regs *r, void *pw, void *v)
{
    ohci_abort_xfer (v, USBD_TIMEOUT);
    return NULL;
}

void riscos_abort_pipe (void *v)
{
    callx_add_callback (_riscos_abort_pipe, v);
}

/*---------------------------------------------------------------------------*/
/* RISC OS data memory barrier implementation                                */
/*---------------------------------------------------------------------------*/
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

static void barriers_init(void)
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
