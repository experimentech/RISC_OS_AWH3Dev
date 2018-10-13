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
#include "ehcireg.h"
#include "ehcivar.h"

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
#include "EHCIDriverHdr.h"
#include "DebugLib/DebugLib.h"

#define ErrorBase_EHCIDriver 0x820A40
#define ErrorBlock_EHCI_NoReinit    { (ErrorBase_EHCIDriver+0), "NumParm" }
#define ErrorBlock_EHCI_NoEHCI      { (ErrorBase_EHCIDriver+1), "E01"     }
#define ErrorBlock_EHCI_ClaimVeneer { (ErrorBase_EHCIDriver+2), "E02"     }
#define ErrorBlock_EHCI_USBTooOld   { (ErrorBase_EHCIDriver+3), "E03"     }
typedef struct
{
    int  errnum;
    char errtok[8];
} _kernel_tokerror;

/* for debugging */
#ifdef EHCI_DEBUG
extern int ehcidebug;
extern int usbdebug;

int irq_device;
char debugname[16];

int unhandled_irqs;
#endif

extern int * init_veneer (void);
extern void* resource_files (void);
#ifdef EHCI_DEBUG
extern uint64_t gettime (void);
extern void ehci_dump_regs (ehci_softc_t *);
#endif
extern void ehci_abort_xfer (void*, int);

static void *private_word;
static MessagesFD mod_messages;
volatile int* hci_base;
ehci_softc_t ehci_soft;
struct device * usb_soft = NULL;

int* magic = NULL;

int pci_device = -1;
int hal_device = -1;
int instance = 0;
int device_number;
int registers_32bit=0;
static bool registering=false; /* True/false for whether we're in the middle of registering. Avoids nested registration attempt during ROM init. */
static bool hal_portpower = false; /* Whether to use HAL_PortPower to control the port */

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
        static const _kernel_tokerror err_usbtooold = ErrorBlock_EHCI_USBTooOld;
    
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
                   &mod_messages, "UkRoot", ehci_soft.sc_vendor, sizeof(ehci_soft.sc_vendor));
        if (e) strcpy(ehci_soft.sc_vendor, " ");
    }
    else
    {
        char *v = NULL;
    
        _swix (PCI_ReadInfo, _INR(0,3), PCI_ReadInfo_Vendor, &v, sizeof(v), pci_device);
        if (v == NULL) v = " ";
        strncpy (ehci_soft.sc_vendor, v, sizeof ehci_soft.sc_vendor-1);
    }
}

_kernel_oserror* new_instance (_kernel_swi_regs* r, void* pw, void* h)
{
    _kernel_oserror * e;

    (void) r;
    (void) pw;
    
    /* fill in the device name in the callback so that our service call handler
       is threaded and there to respond to PCI calls */
    name_root_hub(pci_device);

    /* register with the usbdriver module if it's already resident */
    dprintf (("", "Registering with USB driver\n"));
    e = register_bus(&ehci_soft, &usb_soft);
    if (e)
    {
        dprintf (("", "Failed to register: %s\n", e->errmess));
    }
    else
    {
        if (hal_portpower)
        {
            for (int i = 0; i < ehci_soft.sc_noport; i++)
            {
                _swix(OS_Hardware, _INR(0,2) | _INR(8,9),
                      hal_device, i, 1, OSHW_CallHAL, EntryNo_HAL_USBPortPower);
            }
        }
        dprintf (("", "Registering with USB driver-done\n"));
    }


    // allow enough space for name, % and number, then space, device type,
    // and another number
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
    _kernel_oserror* e = 0;
    bool ettf = false;

    callx_init (pw);

    /* set up debugging */
#ifdef EHCI_DEBUG
    sprintf(debugname,"EHCIDrv-%d",podule_base);
#endif    
    debug_initialise (debugname, 0, 0);
//    debug_set_device(DEBUGIT_OUTPUT);
//    debug_set_device(PRINTF_OUTPUT);
    debug_set_device(DADEBUG_OUTPUT);
    debug_set_unbuffered_files (TRUE);
    /* cannot debug_set_stamp_debug (TRUE).. get stack overflow!!!
       Plus it causes interrupts to be briefly enabled during debug output, breaking all kinds of stuff  */
/*    debug_set_stamp_debug (TRUE);*/

    dprintf (("Main_0", "Starting driver\n"));

    /* simulate having one EHCI device attached.  This section has to
    communicate with HAL or podule manager to find out where it can read/write    to some EHCI registers */

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
            static const _kernel_tokerror err_noreinit = ErrorBlock_EHCI_NoReinit;

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
            0x0C0320,
            0xFFFFFF,
            pci_device,
            &pci_device);
        if(!e && pci_device)
        {
             dprintf (("", "Found EHCI controller on PCI device %d\n", pci_device));
            e = _swix(PCI_ReadInfo, _INR(0,3),
                PCI_ReadInfo_IntDeviceVector,
                &device_number,
                sizeof device_number,
                pci_device);
            if (e) goto error;
        
        
            e = _swix(PCI_HardwareAddress, _INR(0,1)|_IN(3)|_OUT(4),
                0, 0, pci_device, &hci_base);
            if (e) goto error;
        

            registers_32bit = 0;
        }
        else
        {
            /* Reached end of list */
            pci_device = -1;
            e = NULL;
        }
    }
    if(pci_device == -1)
    {
        /* Looking for HAL device */
        do {
            hal_device++;
            struct
            {
                int type;
                int flags;
                void *hw;
                int devno;
            } usbinfo;
            size_t usbinfolen;
    
            e = _swix(OS_Hardware, _INR(0,2)|_INR(8,9)|_OUT(0),
                                   hal_device, &usbinfo, sizeof usbinfo,
                                   OSHW_CallHAL, EntryNo_HAL_USBControllerInfo,
                                   &usbinfolen);
            if (!e && (usbinfolen == sizeof(usbinfo)) && (usbinfo.type == HALUSBControllerType_EHCI))
            {
                dprintf (("", "Found EHCI controller on HAL device %d\n", hal_device));
                device_number = usbinfo.devno;
                hci_base = usbinfo.hw;
                if(usbinfo.flags & HALUSBControllerFlag_32bit_Regs)
                    registers_32bit = 1;
                if(usbinfo.flags & HALUSBControllerFlag_EHCI_ETTF)
                    ettf = true;
                if(usbinfo.flags & HALUSBControllerFlag_HAL_Port_Power)
                    hal_portpower = true;
                break;
            }
            else if(e || !usbinfolen)
            {
                /* Reached end of list */
                static const _kernel_tokerror err_noehci = ErrorBlock_EHCI_NoEHCI;
            
                e = _swix (MessageTrans_ErrorLookup, _INR(0,2),
                           &err_noehci, &mod_messages, 0 /* Internal buffer */);
                goto error;
            }
        } while(1);
    }

    memset (&ehci_soft, 0, sizeof ehci_soft);

    sprintf (ehci_soft.sc_bus.bdev.dv_xname, "EHCI%d", instance);
    ehci_soft.sc_irqdevno = device_number;
    dprintf (("Main_0", "interrupt device %d\n", device_number));
    dprintf (("Main_0", "hardware address %p\n", hci_base));

    private_word = pw;

#ifdef EHCI_DEBUG
    const char *c = getenv("ehcidebug");
    usbdebug = ehcidebug = (c?atoi(c):0);
#endif

    if ((magic = init_veneer ()) == NULL)
    {
        static const _kernel_tokerror err_claimveneer = ErrorBlock_EHCI_ClaimVeneer;
    
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

    if (ettf)
    {
        ehci_soft.sc_flags |= EHCIF_ETTF;
    }

    /* fix n companions */
    ehci_soft.sc_ncomp = 2;

    /* in BSD this is called from sys/pci/ehci_pci.c */
    ehci_init (&ehci_soft);

    dprintf (("", "Finished module initialisation\n"));

    /* try and start a new instance to catch any more controllers on the bus,
       done in a callback so that this instance is threaded and the instance
       count goes up */
    /* also register with the usbdriver module if it's already resident */

    callx_add_callback (new_instance, 0);

    return NULL;

error:
    dprintf (("","Failed initialisation: %s\n", e->errmess));
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

    if (usb_soft != NULL)
    {
        _swix (USBDriver_DeregisterBus, _IN(0), usb_soft);
        usb_soft=NULL;
    }
// need to stop the controller
    EOWRITE4(&ehci_soft, EHCI_USBCMD, 0);
    EOWRITE4(&ehci_soft, EHCI_USBCMD, EHCI_CMD_HCRESET);
    EOREAD4(&ehci_soft, EHCI_USBCMD);/* flush the command */

    /* don't disable the interrupt since it is shared, the OS will disable it
       when noone is left responding */
//    _swix (OS_Hardware, _IN(0) | _INR(8,9),
//        device_number, OSHW_CallHAL, EntryNo_HAL_IRQDisable);
    callx_remove_all_callbacks ();
    callx_remove_all_callafters ();
    callx_remove_all_calleverys ();
    _swix (OS_ReleaseDeviceVector, _INR(0,2),
        device_number | ((pci_device == -1)?0:(1u<<31)),
        usb_irq_entry, pw);

    if (magic) _swix (OS_Module, _IN(0)|_IN(2), 7, magic);

    _swix (MessageTrans_CloseFile, _IN(0), &mod_messages);

#ifndef ROM
    /* only remove files for last instantiation */
    if (podule == 0)
    {
        _swix (ResourceFS_DeregisterFiles, _IN (0), resource_files ());
    }
#endif

    return NULL;
}

/*---------------------------------------------------------------------------*/
/* CMHG module service calls                                                 */
/*---------------------------------------------------------------------------*/
void module_services(int service_number, _kernel_swi_regs *r, void *pw)
{
    dprintf (("", "svce %x reason %x\n",service_number,r->r[0]));
    switch (service_number)
    {
      case Service_USB:
        switch (r->r[0])
        {
           case Service_USB_USBDriverStarting:
             if ((usb_soft == NULL) && !registering)
             {
                 dprintf (("", "Registering with USB driver from svcecall\n"));
                 _kernel_oserror *e = register_bus(&ehci_soft,&usb_soft);
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
           case Service_USB_USBDriverDead:
           {
             int   irqdevno, flags;
             u_int ncomp;
             
             dprintf (("", "USB driver is dead, shutting down\n"));
             /* USBDriver finalised - no more communication with USBDriver possible */
             ehci_detach (&ehci_soft,0);
             ehci_shutdown (&ehci_soft);
             usb_soft = NULL;
             /* Preserve members deduced in module_init(), wipe everything else */
             irqdevno = ehci_soft.sc_irqdevno;
             flags = ehci_soft.sc_flags;
             ncomp = ehci_soft.sc_ncomp;
             memset (&ehci_soft, 0, sizeof ehci_soft);
             sprintf (ehci_soft.sc_bus.bdev.dv_xname, "EHCI%d", instance);
             ehci_soft.sc_irqdevno = irqdevno; 
             ehci_soft.sc_flags = flags;
             ehci_soft.sc_ncomp = ncomp;
             name_root_hub (pci_device);
             ehci_init (&ehci_soft);
             break;
           }
           default:
             break;
         }
        break;
      case Service_PreReset:
        dprintf (("", "Svce prereset %x %x\n",Service_PreReset,service_number));
        /* reset the controller */
        EOWRITE4(&ehci_soft, EHCI_USBCMD, 0);
        EOWRITE4(&ehci_soft, EHCI_USBCMD, EHCI_CMD_HCRESET);
        EOREAD4(&ehci_soft, EHCI_USBCMD);/* flush the command */
        callx_remove_all_callbacks ();
        callx_remove_all_callafters ();
        callx_remove_all_calleverys ();
        _swix (OS_ReleaseDeviceVector, _INR(0,2),
            device_number | ((pci_device == -1)?0:(1u<<31)),
            usb_irq_entry, pw);
        break;
#ifndef ROM
      case Service_ResourceFSStarting:
        /* Re-register the messages */
        (*(void (*)(void *, void *, void *, void *))r->r[2]) (resource_files (), 0, 0, (void *)r->r[3]);
        break;
#endif
    }
}

#ifdef EHCI_DEBUG
/*---------------------------------------------------------------------------*/
/* CMHG module commands - only used for debugging                            */
/*---------------------------------------------------------------------------*/
_kernel_oserror *module_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
    ehci_softc_t* sc = &ehci_soft;



   switch (cmd_no) {
    case CMD_EHCIRegs:
        printf
        (
            "   PCI device             %8d\n"
            "   Unhandled IRQs         %8d\n"
            "%2X USB Command            %8.8X\n"
            "%2X USB Status             %8.8X\n"
            "%2X USB Interrupt Enable   %8.8X\n"
            "%2X USB Frame Index        %8.8X\n"
            "%2X 4G Segment Selector    %8.8X\n"
            "%2X Frame List Base Addres %8.8X\n"
            "%2X Next Asynch List       %8.8X\n"
//            "%2X Config flag            %8.8X\n"
            "%2X Port1                  %8.8X\n"
            "%2X Port2                  %8.8X\n"
            "%2X Port3                  %8.8X\n"
            "%2X Port4                  %8.8X\n"
            "%2X Port5                  %8.8X\n"
            "%2X Port6                  %8.8X\n",
               pci_device,
               unhandled_irqs,
	       EHCI_USBCMD, EOREAD4(sc, EHCI_USBCMD),
	       EHCI_USBSTS, EOREAD4(sc, EHCI_USBSTS),
	       EHCI_USBINTR, EOREAD4(sc, EHCI_USBINTR),
	       EHCI_FRINDEX, EOREAD4(sc, EHCI_FRINDEX),
	       EHCI_CTRLDSSEGMENT, EOREAD4(sc, EHCI_CTRLDSSEGMENT),
	       EHCI_PERIODICLISTBASE, EOREAD4(sc, EHCI_PERIODICLISTBASE),
	       EHCI_ASYNCLISTADDR, EOREAD4(sc, EHCI_ASYNCLISTADDR),
               EHCI_PORTSC(1), EOREAD4(sc, EHCI_PORTSC(1)),
               EHCI_PORTSC(2), EOREAD4(sc, EHCI_PORTSC(2)),
               EHCI_PORTSC(3), EOREAD4(sc, EHCI_PORTSC(3)),
               EHCI_PORTSC(4), EOREAD4(sc, EHCI_PORTSC(4)),
               EHCI_PORTSC(5), EOREAD4(sc, EHCI_PORTSC(5)),
               EHCI_PORTSC(6), EOREAD4(sc, EHCI_PORTSC(6))
        );

        ehci_dump_regs (&ehci_soft);
        break;
    case CMD_EHCIDebug:
        {
        char* ptr;
        ehcidebug = (int) strtoul (arg_string, &ptr, 0);
        if (ptr) usbdebug = (int) strtoul (ptr, &ptr, 0);
        }
        break;
//    case CMD_OHCIEDS:
//        {
//#ifdef EHCI_DEBUG
//            ehci_soft_ed_t* sed;
//            sed = ehci_soft.sc_isoc_head;
//            while (sed != NULL) {
//                ehci_dump_ed(sed);
//                sed = sed->next;
//            }
//            sed = ehci_soft.sc_ctrl_head;
//            while (sed != NULL) {
//
//                ehci_dump_ed(sed);
//                sed = sed->next;
//            }
//            sed = ehci_soft.sc_bulk_head;
//            while (sed != NULL) {
//                ehci_dump_ed(sed);
//                sed = sed->next;
//            }
//#endif
//            break;
//        }
//    case CMD_OHCIWrite:
//        {
//        int a, b;
//        char* ptr;
//        a = (int) strtoul (arg_string, &ptr, 16);
//        b = (int) strtoul (ptr, 0, 16);
//        printf ("writing %x to %x\n", b, a);
//        hci_base[a / 4] = b;
//        }
//        break;
//    default:
//        break;
    }

    return 0;
}
#endif

/*---------------------------------------------------------------------------*/
/* CMHG interrupt veneer handler                                             */
/*---------------------------------------------------------------------------*/
int usb_irq_handler(_kernel_swi_regs *r, void *pw)
{
    int ret;
    // ehci_intr returns 0 for failure, 1 for success, the inverse of what
    // we're expected to return

#ifdef EHCI_DEBUG
    int u2s, u2s1;
    _swix (OS_Hardware, _INR(8,9)|_OUT(0),
        OSHW_CallHAL, EntryNo_HAL_CounterRead, &u2s);
//    irqs++;
//    ehci_softc_t* sc = &ehci_soft;
//    if (ehcidebug > 1) dprintf (("", "Frame index: %x\n",
//            EOREAD4(sc, EHCI_FRINDEX)));
#endif

    ret = !ehci_intr (&ehci_soft);

#ifdef EHCI_DEBUG
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
        if (ehcidebug > 1) dprintf(("", "irq for: %d nsecs\n", t));
    }
#endif

    return ret;
}

int
softintr (_kernel_swi_regs* r, void* pw)
{
    ehci_softintr ((void*) r->r[0]);
    return 1; /* Pass on */
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
    ehci_abort_xfer (v, USBD_TIMEOUT);
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
