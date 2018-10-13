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
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <limits.h>
#include <stddef.h>

#include "Global/RISCOS.h"
#include "Global/Services.h"
#include "Global/UpCall.h"
#include "Global/FSNumbers.h"
#include "Interface/DeviceFS.h"
#include "Interface/USBDriver.h"

#include "sys/callout.h"
#include "sys/ioctl.h"
#include "sys/time.h"

#include "dev/usb/usb.h"
#include "dev/usb/usbdi.h"
#include "dev/usb/usbdi_util.h"
#include "dev/usb/usbdivar.h"
#include "dev/usb/usbhid.h"
#include "dev/usb/usb_quirks.h"

#include "USBDriverHdr.h"
#include "swis.h"
#include "debuglib/debuglib.h"
#include "callx/callx.h"
#include "oslib/devicefs.h"
#ifndef BOOL
#define BOOL
#endif
#include "toolbox.h"

#include "bufman.h"
#include "usbmouse.h"
#include "usbkboard.h"
#include "USBDevFS.h"


/*---------------------------------------------------------------------------*/
/* structure definitions                                                     */
/*---------------------------------------------------------------------------*/

struct ugen_softc;

#define UAUDIO_NFRAMES 4

struct isoc_buffer {
    usbd_xfer_handle xfer;
    uint16_t sizes[UAUDIO_NFRAMES];
    uint16_t offsets[UAUDIO_NFRAMES];
    int size;
};

typedef enum {
    ReadStatus_Idle, /* Initial state, doing nothing */
    ReadStatus_Busy, /* Read is in progress. Note xfer may be idle if buffer has become full. */
    ReadStatus_Complete, /* Read has completed */
} ReadStatus;

struct devstream {
    /* HID needs to know the ugen */
    struct ugen_softc* ugen;

    int ep;
    int fs_stream;
    usbd_pipe_handle pipe;
    usbd_interface_handle iface;
    char* buf;
    int buffer;
    int buffer_id;
    usbd_xfer_handle xfer;
    int report;

    /* hid devices are all hung off the same endpoint, the chain is searched
       until the one with the correct report is found */
    struct devstream* next_hid;
    int count;
    int totalcount; /* transfer finishes when count it reaches totalcount */
    int timeout;
    int size;
    int bandwidth; /* isochronous bandwidth */
    int residue;
    int dying;
    int padded_bytes; /* only greater 0 in case of short packages */
    int flags; /* Flags altered by the GetSetOptions call */
#define FLAG_NOPAD 1
#define FLAG_SHORT 2
#define FLAG_VALIDMASK 3 /* Which bits can be modified */
    struct isoc_buffer * isoc;
    bool xfer_busy;
    bool delayed_read; /* Gets set if a read has been queued by RxWakeUp but hasn't actually been started yet (e.g. due to previous read still being in progress) */
    int nextcount; /* How long the next (i.e. delayed) read should be */
    ReadStatus read_status;
};

struct dev_struct {
    devicefs_device dev;
    int null;
    char name[32];
};

struct ugen_softc {
    USBBASEDEVICE sc_dev;               /* base device */
    usbd_device_handle sc_udev;
    struct dev_struct mydev;
    devicefs_device* sc_devfs;
    struct devstream* str[32];
};

/* used for generically matching keyboards and mice, and throwing them off */
struct iface_softc {
    USBBASEDEVICE sc_dev;
    usbd_device_handle sc_udev;
    usbd_interface_handle sc_iface;
};


/*---------------------------------------------------------------------------*/
/* variables definitions                                                     */
/*---------------------------------------------------------------------------*/

#define E_NoMem         "\x00\x90\x81\x00" "NoMem"
#define E_NoDevice      "\x01\x90\x81\x00" "NoDevice"
#define E_NoInterface   "\x02\x90\x81\x00" "NoInterface"
#define E_NoEndpoint    "\x03\x90\x81\x00" "NoEndpoint"
#define E_EndpointUsed  "\x04\x90\x81\x00" "EndpointUsed"
#define E_BadPipe       "\x05\x90\x81\x00" "BadPipe"
#define E_BadXfer       "\x06\x90\x81\x00" "BadXfer"
#define E_NoStream      "\x07\x90\x81\x00" "NoStream"
#define E_BadRequest    "\x08\x90\x81\x00" "BadRequest"
#define E_NotRootP      "\x09\x90\x81\x00" "NotRootP"
#define E_BadDevice     "\x0A\x90\x81\x00" "BadDevice"
#define E_MismatchVers  "\x0B\x90\x81\x00" "IncVers"
#define E_QuirkCmd      "\x0C\x90\x81\x00" "QuirkCmd"
#define E_NoSuchQuirk   "\x0D\x90\x81\x80" "NoSuchQuirk"
#define E_QuirkSlot     "\x0E\x90\x81\x80" "QuirkSlot"
#define E_XferFailed    "\x20\x90\x81\x00" "XferFailed"

#define USBDEV_MESSAGES "Resources:$.Resources.USBDriver.USBDevs"

MessagesFD mod_messages;
MessagesFD usbdev_messages;

_kernel_oserror* uerror (char* e)
{
    return _swix (MessageTrans_ErrorLookup, _INR(0,2), e, &mod_messages, 0);
}

/* this is defined in usb.c by the macro USB_DECLARE_DRIVER */
extern struct cfattach usb_ca;

extern struct cfattach uhub_uhub_ca;


/* for debugging */
#ifdef USB_DEBUG
extern int usbdebug, uhubdebug, uhidevdebug;
extern int total_sleep;
#endif
#ifdef DEBUGLIB
char* ccodes []= {
        "NORMAL_COMPLETION",
        "IN_PROGRESS",
        "PENDING_REQUESTS",
        "NOT_STARTED",
        "INVAL",
        "NOMEM",
        "CANCELLED",
        "BAD_ADDRESS",
        "IN_USE",
        "NO_ADDR",
        "SET_ADDR_FAILED",
        "NO_POWER",
        "TOO_DEEP",
        "IOERROR",
        "NOT_CONFIGURED",
        "TIMEOUT",
        "SHORT_XFER",
        "STALLED",
        "INTERRUPTED"};
#endif

extern int cold;
void* private_word = 0;

struct sysvar_callback {
    struct sysvar_callback* next;
    char com[];
}* sysvar_head = NULL;

static int usbbus_no = 1;       /* next number to use  */
static int usbdev_no = 1;       /* next number to use  */
static int maxdev_no = 0;       /* highest number found*/


struct devicelist allbuses = TAILQ_HEAD_INITIALIZER(allbuses);
struct devicelist allusbdevs = TAILQ_HEAD_INITIALIZER(allusbdevs);

/*---------------------------------------------------------------------------*/
/* static function declarations                                              */
/*---------------------------------------------------------------------------*/

struct device* attach_hub (struct device* parent, void* aux);
int detach_hub (struct device* hub);
struct device* attach_device (struct device* parent, struct usb_attach_arg* aux, int n);
int detach_device (struct device* dev, int);
bool sysvar_attach;
static int launch_system_variable (struct usb_attach_arg* aux, int unit);
void kill_system_variable (int unit);

extern int ugenioctl(int devt, int cmd, void* addr, int flag, void* p);
extern int usbioctl(int devt, u_long cmd, void* data, int flag, void *p);

struct device* get_usbdev (int unit);

extern char* usbd_get_string (usbd_device_handle, size_t, char*);
extern void microtime (struct timeval* tv);
extern void triggercbs(void);
extern uint32_t clock (void); // avoid header clash with sys/types.h

bool announce_attach;
static char* service_call (usbd_device_handle dev, int unit, int link);
_kernel_oserror* announce_device (_kernel_swi_regs* r, void* pw, void* sc);

extern void* resource_files (void);

/*---------------------------------------------------------------------------*/
/* functions       declarations                                              */
/*---------------------------------------------------------------------------*/
static _kernel_oserror *re_discover(_kernel_swi_regs *r, void *pw, void* h);

static _kernel_oserror *init_handler(_kernel_swi_regs *r, void *pw, void* h)
{
    /* issue a service call to request any latent HCDs to report themselves */
    _swix (OS_ServiceCall, _INR (0, 1),
        Service_USB_USBDriverStarting,
        Service_USB);
    return NULL;
}

_kernel_oserror *module_init(const char *cmd_tail, int podule_base, void *pw)
{
    _kernel_oserror* e;
    private_word = pw;
    /* set up debugging */
    debug_initialise ("USBDriver", "$.dbUSBD", 0);
//    debug_set_device(FILE_OUTPUT);
    debug_set_device(DADEBUG_OUTPUT);
//    debug_set_device(PRINTF_OUTPUT);
    debug_set_unbuffered_files (TRUE);
    /* Can't set debug_set_stamp_debug(TRUE) - Causes interrupts to be briefly enabled during debug output, which breaks all kinds of stuff */
/*    debug_set_stamp_debug (TRUE); */

    callx_init (pw);

#ifdef STANDALONE
    e = _swix (ResourceFS_RegisterFiles, _IN (0), resource_files ());
    if (e != NULL) return e;
#endif
    e = _swix (MessageTrans_OpenFile, _INR(0,2), &mod_messages, Module_MessagesFile, 0);
    if (e) goto error_dereg;
    e = _swix (MessageTrans_OpenFile, _INR(0,2), &usbdev_messages, USBDEV_MESSAGES, 0);
    if (e) goto error;

#ifdef USB_DEBUG
    const char *c;
    c = getenv("usbdebug"); usbdebug = (c?atoi(c):0);
    c = getenv("uhubdebug"); uhubdebug = (c?atoi(c):0);
    c = getenv("uhidevdebug"); uhidevdebug = (c?atoi(c):0);
#endif

    usbbus_no = 1;
    usbdev_no = 1;
    maxdev_no = 0;
    extra_quirks = NULL;

    /* do this in a callback so that clients can call our SWIs */
    callx_add_callback (init_handler, 0);

    /* set up a periodic call to re-discover anything lurking */
    callx_add_callevery(3000,re_discover,NULL);

    _swix (OS_Claim, _INR(0,2), PointerV, pointerv_entry, pw);

    return NULL;
    
error:
    _swix (MessageTrans_CloseFile, _IN(0), &mod_messages);
error_dereg:
#ifdef STANDALONE
    _swix (ResourceFS_DeregisterFiles, _IN(0), resource_files ());
#endif
    return e;
}

/*---------------------------------------------------------------------------*/

struct cfattach ugen_ca = {
    sizeof (struct ugen_softc), NULL, NULL, detach_device, NULL
};

_kernel_oserror *module_final(int fatal, int podule, void *pw)
{
    /* issue a service call to announce USBDriver is being finalised */
    _swix (OS_ServiceCall, _INR (0, 1),
        Service_USB_USBDriverDying, Service_USB);


    _swix (OS_Release, _INR(0,2), PointerV, pointerv_entry, pw);
    _swix (OS_Release, _INR(0,2), KEYV, keyv_entry, pw);

    /* devices will all get removed as buses remove themselves from the
       above service call */
    struct device *dev, *temp;
    TAILQ_FOREACH_SAFE(dev, &allbuses, dv_list, temp)
    {
        TAILQ_REMOVE(&allbuses, dev, dv_list);
        (*usb_ca.ca_detach)(dev, 0);
        free (dev);
    }


    /* get rid of the system variables */
    while (_swix (OS_SetVarVal, _INR(0,4), "USB$Device_*", 0, -1, 0, 0) == NULL)
    {
        /* do nothing */
    }

    callx_remove_all_calleverys ();
    callx_remove_all_callafters ();
    callx_remove_all_callbacks ();

    _swix (MessageTrans_CloseFile, _IN(0), &mod_messages);
    _swix (MessageTrans_CloseFile, _IN(0), &usbdev_messages);
    if (extra_quirks) free (extra_quirks);

#ifdef STANDALONE
    _swix (ResourceFS_DeregisterFiles, _IN (0), resource_files ());
#endif

    /* issue a service call to announce USBDriver has gone */
    _swix (OS_ServiceCall, _INR (0, 1),
        Service_USB_USBDriverDead, Service_USB);

    return NULL;
}

/*---------------------------------------------------------------------------*/

static const char *ltrim(const char *string)
{
    if (string == NULL) return "";
    while (*string == ' ')
    {
        string++;
    }
    return string;
}

/*---------------------------------------------------------------------------*/

static const char *lookupmsg(const char *token, const char *arg0)
{
    static char buffer[128];
    _kernel_oserror *e;

    e = _swix (MessageTrans_Lookup, _INR(0,4),
               &mod_messages, token, buffer, sizeof(buffer), arg0);
    if (e) return "?";
    return buffer;
}

/*---------------------------------------------------------------------------*/

static void formatpair(const char *token, size_t width, const char *value)
{
    char fmt[16];

    sprintf (fmt, "%%-%ds : %%s", width);
    printf (fmt, lookupmsg (token, NULL), value);
}

/*---------------------------------------------------------------------------*/

static _kernel_oserror* RegisterNewDevice(struct ugen_softc * softc,int no)
{
    struct dev_struct * dev = &softc->mydev;
    sprintf (dev->name, "USB%d", no);
    strncpy (softc->sc_dev.dv_xname, dev->name,
        sizeof softc->sc_dev.dv_xname - 1)
            [sizeof softc->sc_dev.dv_xname - 1] = '\0';

    dev->dev.name_offset = dev->name - (char*) dev;
    dev->dev.flags = 3;
    dev->dev.tx_flags = 0x8;
    dev->dev.tx_buffer_size = 8192;
    dev->dev.rx_flags = 0x8;
    dev->dev.rx_buffer_size = 1024;

    _kernel_oserror* e = _swix (DeviceFS_Register, _INR (0, 7) | _OUT(0),
        6,
        dev,
        driver_entry,
        softc,
        private_word,
        "endpoint/Ninterface/Nalternate/Nreport/Ncontrol,isochronous,bulk,interrupt/Susbtimeout/Nsize/Nnopad/Sshort/S",
        -1,
        -1,
        &softc->sc_devfs);
    return e;
}

/*---------------------------------------------------------------------------*/

void module_services(int service_number, _kernel_swi_regs *r, void *pw)
{
    dprintf(("", "Service call reason %d\n", service_number));
    switch (service_number)
    {
#ifdef STANDALONE
    case Service_ResourceFSStarting:
        /* Re-register the messages */
        (*(void (*) (void*,void*,void*,void*)) r->r[2])
            (resource_files (), 0, 0, (void*) r->r[3]);
        break;
#endif
    case Service_DeviceFSStarting:/*attempt to register what we know about*/
        {
          usbdev_no = 1;
          maxdev_no = 0;
          struct device* dev;
          TAILQ_FOREACH(dev, &allusbdevs, dv_list)
          {
              if (dev)
              {
                  dev->dv_unit = maxdev_no = usbdev_no++;

                  dprintf(("","registering %d \n",dev->dv_unit));
                  RegisterNewDevice( ((struct ugen_softc*) dev),dev->dv_unit);
               }
           }
           break;
        }
    case Service_DeviceFSDying:   /*ensure we've forgotten any linkage*/
        {
          usbdev_no = 1;
          maxdev_no = 0;
          struct device* dev;
          TAILQ_FOREACH(dev, &allusbdevs, dv_list)
          {
              if (dev)
              {
                  dprintf(("","forgetting %d \n",dev->dv_unit));
                  dev->dv_unit = 0;
              }
          }
          break;
        }
    case Service_USB:
        switch (r->r[0]) {
        case Service_USB_Connected:
        {
            struct device* dev;
            USBServiceAnswer* serv;
            // to link to existing list
            USBServiceAnswer* lastserv = (USBServiceAnswer*) r->r[2];
            while (lastserv != NULL && lastserv->link != NULL)
            {
                lastserv = lastserv->link;
            }
            TAILQ_FOREACH(dev, &allusbdevs, dv_list)
            {
                struct ugen_softc * udev = (struct ugen_softc*) dev;
                serv = (USBServiceAnswer*)
                    service_call (udev->sc_udev, dev->dv_unit, 1);
                serv->link = NULL;
                if (lastserv == NULL)
                {
                    r->r[2] = (int) serv;
                }
                else
                {
                    lastserv->link = serv;
                }
                lastserv = serv;
            }
        }
            break;
        case Service_USB_Attach:
            break;
        case Service_USB_Detach:
            break;
        }
        break;
    case Service_PreReset:
      {
        /* Machine is about to be reset. We do not have time to shut the */
        /* system down cleanly. We MUST make sure our chip is 'muted'    */
//    /* issue a service call to request any running HCDs can object */
//    /* do this first in case other things still need to happen     */
//    _swix (OS_ServiceCall, _INR (0, 1),
//        Service_USB_USBDriverDying, Service_USB);
            callx_remove_all_calleverys ();
            callx_remove_all_callafters ();
            callx_remove_all_callbacks ();
            break;
        }
    }
}

/*---------------------------------------------------------------------------*/

static _kernel_oserror* command_enumerate_devices (void)
{
    size_t i, width;
    char   fmt[40], hdr[80], colfmt[20];
    const char *heading, *column;
    struct usb_device_info di;

    heading = lookupmsg ("DevHdr", NULL);
    *fmt = *hdr = '\0';
    for (i = 0; i < 5; i++)
    {
        column = strtok ((i == 0) ? (char *)heading : NULL, "_");
        width = strlen (column);
        strcat (hdr, column);
        switch (i)
        {
            /* eg. No. Bus Dev Class Description
             *       0   1   2     3 4
             *     123 123 123  8/FF Vend Prod
             */
            case 0: case 1: case 2:
                sprintf (colfmt, "%%%dd ", max (width, 3));
                strcat (fmt, colfmt);
                do { strcat (hdr, " "); width++; } while (width < 4);
                break;
            case 3:
                sprintf (colfmt, "%%%dX/%%2X ", max (width, 5) - 3);
                strcat (fmt, colfmt);
                do { strcat (hdr, " "); width++; } while (width < 6);
                break;
            case 4:
                strcat (fmt, "%s%s%s\n");
                break;
        }
    }
    printf ("%s\n", hdr);
    for (i = 1; i <= maxdev_no; ++i)
    {
        struct device* dev = get_usbdev (i);
        if (dev != NULL)
        {
            usbd_device_handle udev = ((struct ugen_softc*) dev)->sc_udev;
            usbd_fill_deviceinfo (udev, &di, 1);
            /* in case the vendor string is null, don't print a leading space */
            printf (fmt,
                i,
                di.udi_bus,
                di.udi_addr,
                di.udi_class,
                di.udi_subclass,
                di.udi_vendor,
                *di.udi_vendor ? " " : "",
                di.udi_product);
        }
    }
#ifdef USB_DEBUG
    printf ("usbdebug %d\n", usbdebug);
    printf ("uhidevdebug %d\n", uhidevdebug);
    printf ("uhubdebug %d\n", uhubdebug);
#endif
    return NULL;
}

/*---------------------------------------------------------------------------*/

static _kernel_oserror* command_enumerate_buses (void)
{
    size_t i, width;
    char   fmt[40], hdr[80], colfmt[20];
    const char *heading, *column;
    struct usb_device_stats stats;

    sprintf (hdr, "%d", usbbus_no-1);
    printf ("%s:\n", lookupmsg ("BusTxf", hdr));

    heading = lookupmsg ("BusHdr", NULL);
    *fmt = *hdr = '\0';
    for (i = 0; i < 5; i++)
    {
        column = strtok ((i == 0) ? (char *)heading : NULL, "_");
        width = strlen (column);
        switch (i)
        {
            /* eg. Bus    Control Isochronous       Bulk  Interrupt
             *       0          1           2          3          4
             *     123 2999888777  2999888777 2999888777 2999888777
             */
            case 0:
                sprintf (colfmt, "%%%dd ", max (width, 3));
                strcat (fmt, colfmt);
                strcat (hdr, column);
                do { strcat (hdr, " "); width++; } while (width < 4);
                break;
            case 1: case 2: case 3: case 4:
                sprintf (colfmt, "%%%dlu ", max (width, 10));
                strcat (fmt, colfmt);
                while (width < 10) { strcat (hdr, " "); width++; }
                strcat (hdr, column); strcat (hdr, " ");
                break;
        }
    }
    strcat (fmt, "\n");
    printf ("%s\n", hdr);
    for (i = 1; i < usbbus_no; ++i)
    {
        if (get_softc (i << 16) == NULL ||
            usbioctl (i << 16, USB_DEVICESTATS, &stats, 0, 0))
        {
            continue;
        }

        printf (fmt,
            i,
            stats.uds_requests[UE_CONTROL],
            stats.uds_requests[UE_ISOCHRONOUS],
            stats.uds_requests[UE_BULK],
            stats.uds_requests[UE_INTERRUPT]);
    }
    return 0;
}

/*---------------------------------------------------------------------------*/
static _kernel_oserror* command_discover (void)
{
#ifdef USB_DEBUG
    total_sleep = 0;
    dprintf (("", "discovering max of %d busses\n", usbbus_no-1));
#endif
    for (int i = 1; i < usbbus_no; i++)
    {
        if (get_softc (i << 16) != NULL)
            usbioctl (i << 16, USB_DISCOVER, 0, 0, 0);
    }
#ifdef USB_DEBUG
    dprintf (("", "total sleep = %d\n", total_sleep));
#endif
    return NULL;
}


/*---------------------------------------------------------------------------*/

static _kernel_oserror* command_reset (int n)
{
    struct device* dev = get_usbdev (n);
    if (dev == NULL)
    {
        return uerror (E_NoDevice);
    }

    /* pretend it's a ugen to get the udev */
    usbd_device_handle udev = ((struct ugen_softc*) dev)->sc_udev;
    struct usbd_port * port = udev->powersrc;
    usbd_device_handle parent = port?port->parent:NULL;
    if (parent == NULL)   // its a root hub..
    {
        return uerror (E_NotRootP);
    }

    usb_disconnect_port (port, (device_ptr_t) parent->hub);
    usbd_clear_port_feature(parent, port->portno, UHF_PORT_POWER);
    usbd_delay_ms(parent, /*USB_PORT_RESET_DELAY*/ USB_PORT_POWER_DOWN_TIME);
    usbd_set_port_feature(parent, port->portno, UHF_PORT_POWER);
    int pwrdly = parent->hub->hubdesc.bPwrOn2PwrGood
                                                     * UHD_PWRON_FACTOR
                                            + USB_EXTRA_POWER_UP_TIME;
                                        usbd_delay_ms(parent, pwrdly);
    return NULL;
}

/*---------------------------------------------------------------------------*/

static _kernel_oserror* command_dev_info (int n)
{
    char   string[USB_MAX_STRING_LEN], speed[8];
    struct device *dev = get_usbdev (n);
    size_t width;

    if (dev == NULL)
    {
        return uerror (E_NoDevice);
    }

    /* pretend it's a ugen to get the udev */
    usbd_device_handle udev = ((struct ugen_softc*) dev)->sc_udev;
    usb_device_descriptor_t * ddesc = &udev->ddesc;

    width = strlen (lookupmsg ("DILen", NULL));
    sprintf (string, "%04X\n", UGETW(ddesc->bcdUSB));     formatpair ("DIRel", width, string);
    sprintf (string, "%02X\n", ddesc->bDeviceClass);      formatpair ("DICls", width, string);
    sprintf (string, "%02X\n", ddesc->bDeviceSubClass);   formatpair ("DISub", width, string);
    sprintf (string, "%02X\n", ddesc->bDeviceProtocol);   formatpair ("DIPrt", width, string);
    sprintf (string, "%02X\n", ddesc->bMaxPacketSize);    formatpair ("DIMxP", width, string);
    sprintf (string, "%04X\n", UGETW(ddesc->idVendor));   formatpair ("DIVid", width, string);
    sprintf (string, "%04X\n", UGETW(ddesc->idProduct));  formatpair ("DIPid", width, string);
    sprintf (string, "%04X\n", UGETW(ddesc->bcdDevice));  formatpair ("DIDid", width, string);
    sprintf (string, "%d\n", ddesc->bNumConfigurations);  formatpair ("DICfg", width, string);

    *string = '\0';
    usbd_get_string (udev, ddesc->iManufacturer, string); formatpair ("DIMfg", width, "");
    printf ("'%s'\n", ltrim (string));

    *string = '\0';
    usbd_get_string (udev, ddesc->iProduct, string);      formatpair ("DIPrd", width, "");
    printf ("'%s'\n", ltrim (string));

    *string = '\0';
    usbd_get_string (udev, ddesc->iSerialNumber, string); formatpair ("DISer", width, "");
    printf ("'%s'\n", ltrim (string));

    sprintf (speed, "Spd%d", udev->speed);
    sprintf (string, "%s\n", lookupmsg (speed, NULL));    formatpair ("DISpd", width, string);

    return NULL;
}

/*---------------------------------------------------------------------------*/

static _kernel_oserror* command_conf_info (int n)
{
    char   string[USB_MAX_STRING_LEN], pad[8];
    struct device* dev = get_usbdev (n);
    size_t width;
    int    i;
    bool   indent;

    if (dev == NULL)
    {
        return uerror (E_NoDevice);
    }

    usbd_device_handle udev = ((struct ugen_softc*) dev)->sc_udev;
    usb_config_descriptor_t * cdesc = udev->cdesc;

    width = strlen (lookupmsg ("CILen", NULL));
    sprintf (string, "%d\n", udev->config);
    formatpair ("CICur", width, string);
    if (udev->config == 0 || cdesc == NULL)
    {
        return NULL;
    }
    sprintf (string, "%d\n", cdesc->bNumInterface);
    formatpair ("CIQty", width, string);
    sprintf (string, "%d\n", cdesc->bConfigurationValue);
    formatpair ("CICfg", width, string);

    *string = '\0';
    usbd_get_string (udev, cdesc->iConfiguration, string);
    formatpair ("CINom", width, "");
    printf ("'%s'\n", ltrim (string));

    /* Attributes */
    indent = false;
    formatpair ("CIAtt", width, "");
    if (cdesc->bmAttributes & UC_BUS_POWERED)
    {
        printf ("%s\n", lookupmsg ("Att80", NULL));
        indent = true;
    }
    if (cdesc->bmAttributes & UC_SELF_POWERED)
    {
        if (indent) for (i = width + 3; i > 0; i--) putchar (' ');
        printf ("%s\n", lookupmsg ("Att40", NULL));
        indent = true;
    }
    if (cdesc->bmAttributes & UC_REMOTE_WAKEUP)
    {
        if (indent) for (i = width + 3; i > 0; i--) putchar (' ');
        printf ("%s\n", lookupmsg ("Att20", NULL));
        indent = true;
    }
    if (!(cdesc->bmAttributes & (UC_BUS_POWERED | UC_SELF_POWERED | UC_REMOTE_WAKEUP)))
    {
        puts ("\n");
    }

    /* Max power */
    sprintf (string, "%dmA\n", cdesc->bMaxPower * UC_POWER_FACTOR);
    formatpair ("CIPwr", width, string);

    /* Now list descriptor details */
    char* ptr = (char*) cdesc, *ptr_end = ptr + UGETW(cdesc->wTotalLength);
    ptr += cdesc->bLength;

    while (ptr < ptr_end)
    {
        const char *token;

        switch (ptr[1])
        {
            case UDESC_INTERFACE:
            {
                usb_interface_descriptor_t * d = (usb_interface_descriptor_t *) ptr;
    
                *string = '\0'; usbd_get_string (udev, d->iInterface, string);
                printf ("\n%s %d.%d ",
                    lookupmsg ("IFace", NULL),
                    d->bInterfaceNumber,
                    d->bAlternateSetting);
                printf ("%s %d.%d:%d '%s'\n",
                    lookupmsg ("UCls", NULL),
                    d->bInterfaceClass,
                    d->bInterfaceSubClass,
                    d->bInterfaceProtocol,
                    ltrim (string));
                break;
            }
            case UDESC_ENDPOINT:
            {
                usb_endpoint_descriptor_t * d = (usb_endpoint_descriptor_t *) ptr;
                printf ("%s %d, ", lookupmsg("IEndp", NULL),
                                   UE_GET_ADDR(d->bEndpointAddress));
                switch (d->bmAttributes & UE_XFERTYPE)
                {
                    case UE_CONTROL:
                        token = "ECtrl";
                        break;
                    case UE_ISOCHRONOUS:
                        switch (UE_GET_ISO_TYPE(d->bmAttributes))
                        {
                            case UE_ISO_ASYNC:
                                token = "EIsoY";
                                break;
                            case UE_ISO_ADAPT:
                                token = "EIsoA";
                                break;
                            case UE_ISO_SYNC:
                                token = "EIsoS";
                                break;
                        }
                        break;
                    case UE_BULK:
                        token = "EBulk";
                        break;
                    case UE_INTERRUPT:
                        token = "EIntr";
                        break;
                }
                printf ("%s %s, ", lookupmsg(token, NULL),
                                   UE_GET_DIR(d->bEndpointAddress) == UE_DIR_IN? "IN":"OUT");
                printf ("%d %s ", UGETW(d->wMaxPacketSize), lookupmsg("UByt", NULL));
                printf ("%d %s\n", d->bInterval, lookupmsg("UFrm", NULL));
                break;
            }
            case UDESC_HID:
            {
                usb_hid_descriptor_t * d = (usb_hid_descriptor_t *) ptr;
                ddumpbuf("", (void*) d, d->bLength, 0);
                ddumpbuf("", (void*) d, sizeof *d, 0);
                printf ("%s, HID%X.%02X, ", lookupmsg ("IHidd", NULL),
                                            UGETW(d->bcdHID) >> 8,
                                            UGETW(d->bcdHID) & 0xFF);
                printf ("%s %d\n", lookupmsg ("UCcd", NULL), d->bCountryCode);
                for (i = 0; i < d->bNumDescriptors; ++i)
                {
                    printf ("  %s %d, ", lookupmsg ("UDsc", NULL), i + 1);
#if defined(__CC_NORCROFT) && defined(DISABLE_PACKED)
                    /* Handle in a rather horrible way */
                    printf ("%s %X, ", lookupmsg ("UHTy", NULL),
                                       d->bHIDDescriptorType);
                    printf ("%s %d\n", lookupmsg ("ULen", NULL),
                                       UGETW (d->wDescriptorLength));
                    d = (usb_hid_descriptor_t *) (((char*) d) + 3);
#else
                    printf ("%s %X, ", lookupmsg ("UHTy", NULL),
                                       d->descrs[i].bHIDDescriptorType);
                    printf ("%s %d\n", lookupmsg ("ULen", NULL),
                                       UGETW (d->descrs[i].wDescriptorLength));
#endif
                }
                break;
            }
        }
        ptr += *ptr;
    }

    return NULL;
}

/*---------------------------------------------------------------------------*/

static _kernel_oserror* command_set_config (int device, int config)
{
    struct device* dev = get_usbdev (device);
    if (dev == NULL)
    {
        return uerror (E_NoDevice);
    }

    usbd_device_handle udev = ((struct ugen_softc*) dev)->sc_udev;

    usbd_set_config_no(udev, config, 0);
    return NULL;
}

/*---------------------------------------------------------------------------*/

static _kernel_oserror* command_set_interface (int device, int ifcn, int alt)
{
    struct device* dev = get_usbdev (device);
    if (dev == NULL)
    {
        return uerror (E_NoDevice);
    }

    usbd_device_handle udev = ((struct ugen_softc*) dev)->sc_udev;

    usbd_interface_handle ifc;
    int err = usbd_device2interface_handle (udev, ifcn, &ifc);
    if (err)
    {
        return uerror (E_NoInterface);
    }

    usbd_set_interface(ifc, alt);
    return NULL;
}

/*---------------------------------------------------------------------------*/

static _kernel_oserror* command_ListQuirks(void)
{
    size_t i, width;
    char   fmt[40], hdr[80], colfmt[20];
    const char *heading, *column;
    usbd_quirk_entry *t;

    heading = lookupmsg ("QrkHdr", NULL);
    *fmt = *hdr = '\0';
    for (i = 0; i < 4; i++)
    {
        column = strtok ((i == 0) ? (char *)heading : NULL, "_");
        width = strlen (column);
        strcat (hdr, column);
        switch (i)
        {
            /* eg. Vendor Product Device Flags
             *          0       1      2 3
             *       ABCD    ABCD   ABCD 1234ABCD
             */
            case 0: case 1: case 2:
                sprintf (colfmt, "%%%dx ", max (width, 4));
                strcat (fmt, colfmt);
                do { strcat (hdr, " "); width++; } while (width < 5);
                break;
            case 3:
                sprintf (colfmt, "%%0%dx\n", max (width, 8));
                strcat (fmt, colfmt);
                do { strcat (hdr, " "); width++; } while (width < 9);
                break;
        }
    }
    printf ("%s\n", hdr);
    if (extra_quirks != NULL)
    {
        for (i = 0, t = extra_quirks; i < MAX_EXTRA_QUIRKS; i++,t++)
        {
            if (t->idVendor)
                printf(fmt, t->idVendor, t->idProduct, t->bcdDevice, t->quirks.uq_flags);
        }
    }
    return NULL;
}

static _kernel_oserror* command_RemoveQuirk(unsigned vendor, unsigned product, unsigned device)
{
    int i;
    usbd_quirk_entry *t;
    
    if (extra_quirks)
    {
        for (i = 0, t = extra_quirks; i < MAX_EXTRA_QUIRKS; i++,t++)
        {
            if (t->idVendor  == vendor &&
                t->idProduct == product&&
                t->bcdDevice == device)
            {
                t->idVendor  = 0;
                t->idProduct = 0;
                t->bcdDevice = 0;
                t->quirks.uq_flags = 0;
                return NULL;
            }
        }
    }
    return uerror (E_NoSuchQuirk);
}

static _kernel_oserror* command_AddQuirk(unsigned vendor, unsigned product, unsigned device, unsigned quirk)
{
    int i;
    usbd_quirk_entry *t;

    if (extra_quirks == NULL) extra_quirks = calloc (MAX_EXTRA_QUIRKS, sizeof(usbd_quirk_entry));
    if (extra_quirks == NULL) return uerror (E_NoMem);
    for (i = 0, t = extra_quirks; i < MAX_EXTRA_QUIRKS; i++,t++)  /* existing? */
    {
        if (t->idVendor  == vendor &&
            t->idProduct == product&&
            t->bcdDevice == device)
        {
            t->quirks.uq_flags = quirk;
            return NULL;
        }
    }
    for (i = 0, t = extra_quirks; i < MAX_EXTRA_QUIRKS; i++,t++)  /* new */
    {
        if (!t->idVendor)
        {
            t->idVendor  = vendor ;
            t->idProduct = product;
            t->bcdDevice = device;
            t->quirks.uq_flags = quirk;
            return NULL;
        }
    }
    return uerror (E_QuirkSlot);
}


/*---------------------------------------------------------------------------*/

int tsleep (void* ident, int priority, const char* wmesg, int timo, int noblock);
void wakeup (void* ident);
_kernel_oserror *module_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
    switch (cmd_no) {
#ifdef USB_DEBUG
    case CMD_USBDebug:
        {
        char* ptr;
        usbdebug = (int) strtoul (arg_string, &ptr, 0);
        uhidevdebug = usbdebug;
        if (ptr) uhubdebug = (int) strtoul (ptr, &ptr, 0);
        }
        break;
#endif
    case CMD_USBDevices:
        return command_enumerate_devices ();
    case CMD_USBBuses:
        return command_enumerate_buses ();
    case CMD_USBDevInfo:
        return command_dev_info (atoi (arg_string));
    case CMD_USBConfInfo:
        return command_conf_info (atoi (arg_string));
    case CMD_USBSetConfig:
        {
            int d, c;
            char* p;
            d = (int) strtoul (arg_string, &p, 10);
            c = (int) strtoul (p, &p, 10);
            return command_set_config (d, c);
        }
        break;
    case CMD_USBSetInterface:
        {
            int b, c, d;
            char* p;
            b = (int) strtoul (arg_string, &p, 10);
            c = (int) strtoul (p, &p, 10);
            d = (int) strtoul (p, &p, 10);
            return command_set_interface (b, c, d);
        }
        break;

#ifdef USB_DEBUG
    case CMD_USBDiscover:
        return command_discover ();
#endif

    case CMD_USBReset:
        return command_reset ((int) strtoul (arg_string, 0, 10));

    case CMD_USBQuirk:
        {
            char *p, cmd = (*arg_string) & 0xDF; /* Cheap toupper() */
            unsigned long vendor, product = 0, device = 0, quirk = 0;

            if (cmd=='L') return command_ListQuirks ();
            vendor = (unsigned)strtoul (arg_string+1, &p, 16);
            if (p) product = (unsigned)strtoul (p, &p, 16);
            if (p) device  = (unsigned)strtoul (p, &p, 16);
            if (p) quirk   = (unsigned)strtoul (p, &p, 16);
            if (cmd=='R')
                 return command_RemoveQuirk (vendor,product,device);
            if (cmd=='A')
                 return command_AddQuirk (vendor,product,device,quirk);
            return uerror (E_QuirkCmd);
        }
    }

    return NULL;
}

/*---------------------------------------------------------------------------*/

static device_ptr_t register_bus (device_ptr_t bus)
{
    device_ptr_t softc;
    /* initialise device structure */
    softc = calloc (usb_ca.ca_devsize, 1);
    if (softc == NULL) return NULL;
    TAILQ_INSERT_TAIL (&allbuses, softc, dv_list);
    dprintf (("", "adding bus %p using %p size %x\n", bus,softc,usb_ca.ca_devsize));

    /* abuse the device structure a bit */
    bus->dv_unit = softc->dv_unit = (usbbus_no++);

    /* set the flag to make it explore immediately */
    softc->dv_cfdata = &(struct cfdata) { .cf_flags = 1 };;

    strncpy (softc->dv_xname, "USBDriver"Module_VersionString,
        sizeof softc->dv_xname - 1)[sizeof softc->dv_xname - 1] = '\0';
#ifdef USB_DEBUG
        total_sleep = 0;
#endif

    (*usb_ca.ca_attach)(0, softc, bus);
#ifdef USB_DEBUG
    dprintf (("", "total sleep = %d\n", total_sleep));
#endif

    return softc;
}

static void deregister_bus (device_ptr_t bus)
{
    dprintf (("", "removing bus %p\n", bus));
    (*usb_ca.ca_detach)(bus, 0);
    dprintf (("", "finished removing bus %p\n", bus));
    TAILQ_REMOVE (&allbuses, (device_ptr_t) bus, dv_list);
    free (bus);
}

_kernel_oserror *module_swis(int swi_offset, _kernel_swi_regs *r, void *pw)
{
    switch (swi_offset) {
    case USBDriver_RegisterBus - USBDriver_00:
        /* R1 now contains internal API version number
           This check should be made more permissive when appropriate */
        if(r->r[1] != RISCOS_USBDRIVER_API_VERSION)
            return uerror (E_MismatchVers);
        r->r[0] = (int) register_bus ((device_ptr_t) r->r[0]);
        break;

    case USBDriver_DeregisterBus - USBDriver_00:
        deregister_bus ((device_ptr_t) r->r[0]);
        break;
    case USBDriver_InsertTransfer - USBDriver_00:
        r->r[0] = usb_insert_transfer ((usbd_xfer_handle) r->r[0]);
        break;
    case USBDriver_TransferComplete - USBDriver_00:
        usb_transfer_complete ((usbd_xfer_handle) r->r[0]);
        break;
    case USBDriver_ScheduleSoftInterrupt - USBDriver_00:
        if (r->r[0] > usbbus_no)
            usb_schedsoftintr ((struct usbd_bus*) r->r[0]);
        else
        {
            struct device* bus = get_softc (r->r[0] << 16);
            if (bus != NULL)
                /* discustingly hacky */
                usb_schedsoftintr (*(void**) (bus + 1));
        }
        break;
    case USBDriver_Version - USBDriver_00:
        r->r[0] = Module_VersionNumber;
        break;
    default:
        return error_BAD_SWI;
    }

    return 0;
}

/*---------------------------------------------------------------------------*/

struct device* get_softc (int unit)
{
    struct device* dev;
    TAILQ_FOREACH(dev, &allbuses, dv_list)
    {
        if (dev->dv_unit == ((unit >> 16) & 0xff))
            return dev;
    }

    dprintf (("", "couldn't find unit %x\n", unit));
    return NULL;
}

/*---------------------------------------------------------------------------*/

struct device* get_usbdev (int unit)
{
    struct device* dev;
    TAILQ_FOREACH(dev, &allusbdevs, dv_list)
    {
        if (dev->dv_unit == unit)
        {
            return dev;
        }
    }
    dprintf (("", "couldn't find unit %x\n", unit));

    return NULL;
}

/*---------------------------------------------------------------------------*/
static _kernel_oserror *re_discover(_kernel_swi_regs *r, void *pw, void* h)
{
    static bool rd_active = false;

    if (rd_active) return NULL;
    rd_active = true;
    for (int i = 1; i < usbbus_no; i++)
    {
        if (get_softc (i << 16) != NULL)
        {
            dprintf(("","rediscover bus %d\n",i));
            usbioctl (i << 16, USB_DISCOVER, 0, 0, 0);
        }
    }
    rd_active = false;
    return NULL;
}

/*---------------------------------------------------------------------------*/
struct device* riscos_usb_attach
(
    void* dev,
    struct device*  parent,
    void* aux
) {
    struct device* ret;

    /* This function is called with:
     * 1. aux->usegeneric == 0 && aux->configno == UHUB_UNK_CONFIGURATION
     * 2. aux->usegeneric == 0 && aux->configno != UHUB_UNK_CONFIGURATION
     *    this is repeated for each device interface
     * 3. aux->usegeneric == 1 && aux->configno == UHUB_UNK_CONFIGURATION
     *    the device is registered and announced now
     *
     * Alias running only occurs when sysvar_attach == false.
     * Check specifically for case (1) so that only the first matching alias is run
     * and not repeatedly for each interface.
     */
    if ((((struct usb_attach_arg*) aux)->usegeneric == 0) &&
        (((struct usb_attach_arg*) aux)->configno == UHUB_UNK_CONFIGURATION))
    {
        sysvar_attach = false;
        announce_attach = false;
    }

    char str[sizeof "USB$Ignore_VVVV_PPPP"];
    sprintf (str, "USB$Ignore_%04X_%04X", ((struct usb_attach_arg*)aux)->vendor,
                                          ((struct usb_attach_arg*)aux)->product);
    const char *env = getenv(str);
    dprintf (("", "Check for '%s' got '%s'\n", str, (env ? env : "NULL")));
    if (!env)
    {
        /* No ignore variable, so try to look for it */
        typedef device_ptr_t pf (device_ptr_t, void*);
        pf* funcs[] = { attach_hub, attach_mouse, attach_keyboard, NULL };
        for (pf** f = funcs; *f != NULL; ++f)
        {
            if ((ret = (*f) (parent, aux)) != NULL)
            {
                return ret;
            }
        }
    }

    /* get a number.. dev->dvunit will be 0 if this is the first time through */
    if (((usbd_device_handle)dev)->dv_unit == 0)
    {
        int startnum = usbdev_no;
reloop:
        if (usbdev_no > 999) usbdev_no = 1;   /* cycle around mod 1000 */
        if (usbdev_no > maxdev_no) maxdev_no = usbdev_no;
        if (get_usbdev (usbdev_no) != NULL)
        {
            if (usbdev_no != startnum)
            {
                usbdev_no++;
                goto reloop;                  /* not looped yet .. try again */
            }
        }
        ((usbd_device_handle)dev)->dv_unit = usbdev_no++;
    }
    ret = attach_device (parent, aux, ((usbd_device_handle)dev)->dv_unit);
    if (ret != NULL)
    {
        ret->dv_unit = ((usbd_device_handle)dev)->dv_unit;
        dprintf (("", "first = %p, last = %p\n",
            allusbdevs.tqh_first, allusbdevs.tqh_last));
        /* insert at head, so that iteration starts with last added */
        TAILQ_INSERT_TAIL (&allusbdevs, ret, dv_list);

        /* now execute any * commands queued */
        struct sysvar_callback * sc = sysvar_head;
        _kernel_oserror* e;
        while (sc)
        {
            dprintf (("", "executing: %s\n", sc->com));
            if (NULL != (e = _swix (OS_CLI, _IN(0), sc->com)))
                dprintf (("", "error: %s\n", e->errmess));
            sc = sysvar_head->next;
            free (sysvar_head);
            sysvar_head = sc;
        }
    }

    return ret;
}

/*---------------------------------------------------------------------------*/

/* dummy - we don't do attachment like this */
void* (config_found) (struct device* dev, void* h, int (*f) (void*, const char*))
{
    (void) f;
    (void) dev;
    (void) h;
    return (void*) 1;
}

/*---------------------------------------------------------------------------*/

int config_detach (struct device* dev, int n)
{
    /* catch case of config_detach called from config_found above */
    if (dev == (void*) 1)
    {
        return 0;
    }

    dprintf (("", "config detach %p, %d, type %d\n",
        dev, n, (int) dev->dv_cfdata));

    /* only remove if a generic device or hub, others match as generic as well
        */
    switch ((int) (dev->dv_cfdata))
    {
    case 1:
    case 2:
        if (dev->dv_list.tqe_prev == NULL)
            dprintf (("", "not removing %p\n", dev));
        else
        {
            dprintf (("", "removing %p (prev=%p, next=%p)\n",
                          dev, dev->dv_list.tqe_prev, dev->dv_list.tqe_next));
            TAILQ_REMOVE (&allusbdevs, dev, dv_list);
            /* memory is free'd at the detach point later */
        }

        /* remove any system variables attached to this device and since we
           don't reuse numbers nuke the devicefs options variable too */
       kill_system_variable(dev->dv_unit);

    }

    switch ((int) (dev->dv_cfdata))
    {
    case 1: return detach_hub (dev);
    case 2: return detach_device (dev, n);
    case 3: return detach_mouse (dev);
    case 4: return detach_keyboard (dev);
    }

//    free (dev);
    return 0;
}

/*---------------------------------------------------------------------------*/

struct device* attach_hub (struct device* parent, void* aux)
{
    struct device* softc;
    struct usb_attach_arg* uaa = aux;

    /* don't match generic */
    if (uaa->usegeneric) return NULL;

    dprintf (("", "Trying match on usb hub\n"));

    /* First see if we match */
    if ((*uhub_uhub_ca.ca_match) (0, 0, aux) == UMATCH_NONE)
    {
       dprintf (("", "Failed to match\n"));
       return NULL;
    }

    /* If so, allocate memory for the device and attach ourselves. */
    softc = malloc (uhub_uhub_ca.ca_devsize);
    if (softc == NULL) {
        dprintf (("", "Couldn't allocate memory for hub device\n"));
        return NULL;
    }
    memset (softc, 0, uhub_uhub_ca.ca_devsize);
    strncpy (softc->dv_xname,
        "USBHub"Module_VersionString,
        sizeof softc->dv_xname - 1)[sizeof softc->dv_xname - 1] = '\0';
    softc->dv_cfdata = (void*) 1; // hub

    (*uhub_uhub_ca.ca_attach) (parent, softc, aux);

    dprintf (("", "Matched hub\n"));

    return softc;
}

/*---------------------------------------------------------------------------*/

int detach_hub (struct device* hub)
{
    (*uhub_uhub_ca.ca_detach) (hub, 0);
    free (hub);
    return 0;
}

/*---------------------------------------------------------------------------*/

/* returns non-zero if not handed */
char* service_call (usbd_device_handle dev, int unit, int link)
{
    size_t size =
        (link? sizeof (USBServiceCall*): 0) +
        sizeof (USBServiceCall) +
        UGETW(dev->cdesc->wTotalLength);

    char* real_serv = malloc (size);
    USBServiceCall* serv = (USBServiceCall*) (link? real_serv + sizeof (USBServiceCall*): real_serv);

    if (real_serv == NULL)
    {
        return 0;
    }
    memset (real_serv, 0, size);

    serv->sclen = size - (link? sizeof (USBServiceCall*): 0);
    serv->descoff = offsetof (USBServiceCall, ddesc);
    snprintf (serv->devname, sizeof serv->devname, "USB%d", unit);
    serv->bus = dev->bus->bdev.dv_unit;
    serv->devaddr = dev->address;
    serv->hostaddr = dev->powersrc->parent? dev->powersrc->parent->address: 0;
    serv->hostport = dev->powersrc->portno;
    serv->speed = dev->speed;

    memcpy ((void *)&serv->ddesc, (void *)&dev->ddesc, sizeof serv->ddesc);
    memcpy ((char*)(serv + 1) - 2, (void *)dev->cdesc, UGETW(dev->cdesc->wTotalLength));

    return real_serv;
}

/*---------------------------------------------------------------------------*/

#define USBALIAS "Alias$@USBDevice_"

static int launch_system_variable (struct usb_attach_arg* aux, int unit)
{
    usbd_interface_handle ifc = NULL;
    int class       = aux->iface?   aux->iface->idesc->bInterfaceClass:
                                    aux->device->ddesc.bDeviceClass;
    int subclass    = aux->iface?   aux->iface->idesc->bInterfaceSubClass:
                                    aux->device->ddesc.bDeviceSubClass;
    int protocol    = aux->iface?   aux->iface->idesc->bInterfaceProtocol:
                                    aux->device->ddesc.bDeviceProtocol;
    int vendor      = aux->vendor;
    int product     = aux->product;
    int config      = aux->configno;
    int interface   = aux->ifaceno;
    int release     = aux->release;
    const char* alias = USBALIAS;
    int len         = 0;
    char* name      = NULL;

    char str[sizeof "Alias$@USBDevice_LL_SS_TT_VVVV_PPPP_CC_II_RRRR_USBnnnnnn"];


    /* always set a usb$device variable */
    sprintf (str, "USB$Device_%02X_%02X_%02X_%04X_%04X_%02d_%02d_%04X_USB%d",
        class, subclass, protocol, vendor, product, config, interface, release,
        unit);

    if (aux->ifaceno != UHUB_UNK_INTERFACE)
    {
        usbd_device2interface_handle (aux->device, aux->ifaceno, &ifc);
    }

    char val[13];
    if (ifc)
    {
        sprintf (val, "%d %d %d", unit, aux->ifaceno, ifc->altindex);
    }
    else
    {
        sprintf (val, "%d", unit);
    }
    _kernel_setenv (str, val);

    if (sysvar_attach) return 0;

    for (int i = 0; i < 6; ++i)
    {
        if (aux->ifaceno == UHUB_UNK_INTERFACE)
        {
            switch (i)
            {
                case 0:
                    sprintf (str, "%s*_*_*_%04X_%04X___%04X_*",
                        alias, vendor, product, release);
                    break;
                case 1:
                    sprintf (str, "%s*_*_*_%04X_%04X___*_*",
                        alias, vendor, product);
                    break;
                case 2:
                    sprintf (str, "%s%02X_%02X_%02X_%04X_*___*_*",
                        alias, class, subclass, protocol, vendor);
                    break;
                case 3:
                    sprintf (str, "%s%02X_%02X_*_%04X_*___*_*",
                        alias, class, subclass, vendor);
                    break;
                case 4:
                    sprintf (str, "%s%02X_%02X_%02X_*_*___*_*",
                        alias, class, subclass, protocol);
                    break;
                case 5:
                    sprintf (str, "%s%02X_%02X_*_*_*___*_*",
                        alias, class, subclass);
                    break;
            }
        }
        else
        {
            switch (i)
            {
                case 0:
                    sprintf (str, "%s*_*_*_%04X_%04X_%02d_%02d_%04X_*",
                        alias, vendor, product, config, interface, release);
                    break;
                case 1:
                    sprintf (str, "%s*_*_*_%04X_%04X_%02d_%02d_*_*",
                        alias, vendor, product, config, interface);
                    break;
                case 2:
                    sprintf (str, "%s%02X_%02X_%02X_%04X_*_*_*_*_*",
                        alias, class, subclass, protocol, vendor);
                    break;
                case 3:
                    sprintf (str, "%s%02X_%02X_*_%04X_*_*_*_*_*",
                        alias, class, subclass, vendor);
                    break;
                case 4:
                    sprintf (str, "%s%02X_%02X_%02X_*_*_*_*_*_*",
                        alias, class, subclass, protocol);
                    break;
                case 5:
                    sprintf (str, "%s%02X_%02X_*_*_*_*_*_*_*",
                        alias, class, subclass);
                    break;
            }
        }
        _kernel_swi_regs r = {{ (int) str, 0, -1, 0, 0 }};
        _kernel_swi (OS_ReadVarVal, &r, &r);
        name = (char*) r.r[3];
        if (r.r[2]) goto match;
        dprintf (("", "Failed to match %s\n", str));
    }

    /* no match */
    return 0;

match:
    if (aux->ifaceno == UHUB_UNK_INTERFACE)
        sysvar_attach = true;

    len = strlen (name);

    dprintf (("", "Found match for %s\n", name));

    struct sysvar_callback* sc =
        malloc (sizeof *sc + len + strlen (val));

    if (sc != NULL)
    {
        sprintf (sc->com, "%.*s %s", len, name + sizeof "Alias$" - 1, val);
        sc->next = sysvar_head;
        sysvar_head = sc;
    }

    return 0;
}

// remove any sysvars that are linked to this device
void kill_system_variable (int unit)
{
  char str[sizeof "DeviceFS$USBnnnnnn$Options   "];

  sprintf (str,"USB$Device_*_USB%d",unit);
  while (_swix (OS_SetVarVal, _INR(0,4), str, 0, -1, 0, 0) == NULL)
  {
      /* do nothing */
  }
  sprintf (str,"DeviceFS$USB%d$Options",unit);
  while (_swix (OS_SetVarVal, _INR(0,4), str, 0, -1, 0, 0) == NULL)
  {
      /* do nothing */
  }

}

/*---------------------------------------------------------------------------*/

_kernel_oserror* announce_device (_kernel_swi_regs* r, void* pw, void* sc)
{
    /* make sure we only announce once per device */
    if (announce_attach) return NULL;
    announce_attach = true;

    struct ugen_softc* softc = sc;
    char* serv = service_call (softc->sc_udev, softc->sc_dev.dv_unit, 0);
    if (serv == NULL) return NULL;
    dprintf (("", "Send USBDriver_Attach service call\n"));
    _swix (OS_ServiceCall, _INR(0,2),
        Service_USB_Attach,
        Service_USB,
        serv);
    free (serv);

    return NULL;
}

/*---------------------------------------------------------------------------*/

struct device* attach_device (struct device* parent, struct usb_attach_arg* aux, int no)
{
    _kernel_oserror* e = NULL;
    struct ugen_softc * softc;

    launch_system_variable (aux, no);

    /* only latch onto generic device */
    if (aux->usegeneric == 0) return NULL;

    /* If so, allocate memory for the device and attach ourselves. */
    softc = calloc (sizeof *softc, 1);
    if (softc == NULL) {
        dprintf (("", "Couldn't allocate memory for device\n"));
        return NULL;
    }
    softc->sc_dev.dv_cfdata = (void*) 2; // device

    softc->sc_udev = ((struct usb_attach_arg*)aux)->device;

    e= RegisterNewDevice( softc,no);

    if (e != NULL)
    {
        dprintf (("", "failed to register: %s\n", e->errmess));
        free (softc);
        return NULL;
    }

    dprintf (("", "registered driver %p\n", softc->sc_devfs));


    callx_add_callback (announce_device, softc);

    return (struct device*) softc;
}

/*---------------------------------------------------------------------------*/

int detach_device (struct device* dev, int d)
{
    struct ugen_softc * udev = (struct ugen_softc*) dev;

    if (udev->sc_devfs)
    {
        _swix (DeviceFS_Deregister, _IN(0), udev->sc_devfs);
    dprintf (("", "deregistered driver %p\n", udev->sc_devfs));
    }
   /* Cancel any pending callbacks attached to this device */
   callx_remove_callback(announce_device,udev);
   free (udev);
   return 0;
}

/*---------------------------------------------------------------------------*/

void uhub_activate (void)
{}

/*---------------------------------------------------------------------------*/

extern void usb_discover (void*);

_kernel_oserror* discover_callback (_kernel_swi_regs* r, void* pw, void* sc)
{
    struct usbd_bus* bus = sc;
    struct device* dev;
    dprintf (("", "bus discover %p\n",bus));
    TAILQ_FOREACH(dev, &allbuses, dv_list)
    {
        /* XXX this is dodgy, because in the case where the OHCIDriver module
           has removed its memory, 'bus' is no longer a valid pointer, and
           could either cause an abort or accidentally contain a valid usbctl */
     dprintf(("","dev:%p uctl:%p \n",dev,bus->usbctl));
        if (dev == (struct device*) bus->usbctl)
            goto valid;
    }

    dprintf (("", "bus %p has been removed\n",bus));
    if(bus) bus->callbacks=0;
    return NULL;

valid:
#ifdef STANDALONE
    _swix (Hourglass_On, 0);
    _swix (Hourglass_LEDs, _INR(0,1), 1, 0);
#endif
    dprintf (("", "discovering %p\n",dev));
    do {
        usb_discover (bus->usbctl);
#ifdef STANDALONE
        _swix (Hourglass_LEDs, _INR(0,1), 3, 3);
#endif
    } while (--bus->callbacks);
    #ifdef USB_DEBUG
    dprintf (("", "finished callbacks, total sleep = %d\n", total_sleep));
    #else
    dprintf (("", "finished callbacks\n"));
    #endif
#ifdef STANDALONE
    _swix (Hourglass_Off, 0);
#endif
    return NULL;
}

/*---------------------------------------------------------------------------*/

void usb_needs_explore_callback (void* h) {
    struct usbd_bus* bus = h;
#ifdef USB_DEBUG
    total_sleep = 0;
#endif
    if (bus->callbacks>9) bus->callbacks=9;
    if (bus->callbacks++ == 0)
    {
        dprintf (("", "Adding explore callback on bus %p\n",h));
        callx_add_callback (discover_callback, h);
    }
    else
        dprintf (("", "deferring callback on bus %p - %d callbacks queued\n",bus, bus->callbacks));
}

/*---------------------------------------------------------------------------*/

void bufrem (void* dma, void* priv_id, int size)
{
    if (priv_id == NULL)
    {
        dprintf (("", "Stream has been closed\n"));
        return;
    }

    _kernel_swi_regs r;
    r.r[0] = BM_ExamineBlock;
    r.r[1] = (int) priv_id;
    r.r[2] = (int) dma;
    r.r[3] = size;
    CallBufMan (&r);
}

/*---------------------------------------------------------------------------*/

void bufins (void* dma, void* x)
{
    usbd_xfer_handle xfer = x;
    struct devstream* str = xfer->priv;
    int actlen = xfer->actlen;

    if (str->fs_stream == 0)
    {
        dprintf (("", "Stream has been closed\n"));
        return;
    }

    /* if we have a report setting, then search for the appropriate stream */
    if (str->report != 0xdeaddead)
    {
        /* buffer insert is always going to be an IN endpoint, so we always
           need to add 16 */
        int index = UE_GET_ADDR(str->ep) + 16;
        str = str->ugen->str[index];
        while (str->report != *(char*) dma)
        {
            str = str->next_hid;
            if (str == NULL)
            {
                dprintf (("", "*** run out of chained hids"));
                return;
            }
        }
        dma = ((char*) dma) + 1;
        actlen--;
    }

    str->count += actlen;
//    dprintf (("", "inserting %d bytes, total %d\n",
//        actlen, str->count));

    _kernel_swi_regs r;
    r.r[0] = BM_InsertBlock;
    r.r[1] = (int) str->buffer_id;
    r.r[2] = (int) dma;
    r.r[3] = actlen;
    CallBufMan (&r);
}

void usbd_devinfo_vp(usbd_device_handle dev, char* v, size_t vl, char* p, size_t pl, int usedev)
{
    _kernel_oserror* e = NULL;
    usb_device_descriptor_t *udd = &dev->ddesc;
    char *vendor = NULL, *product = NULL;

    if (dev == NULL) {
        v[0] = p[0] = '\0';
        return;
    }

    dprintf (("", "Looking up v = %x, p = %x\n",
        UGETW(udd->idVendor), UGETW(udd->idProduct)));

    if (usedev)
    {
        char string[USB_MAX_STRING_LEN];

        vendor = usbd_get_string(dev, udd->iManufacturer, string);
        strncpy(v, ltrim(string), vl);
        product = usbd_get_string(dev, udd->iProduct, string);
        strncpy(p, ltrim(string), pl);
    }

    if (vendor == NULL) {
        char str[10];
        sprintf (str, "V%04X",
            UGETW(udd->idVendor));
        e = _swix (MessageTrans_Lookup, _INR(0,3)|_OUT(2),
            &usbdev_messages,
            str,
            v,
            vl,
            &vendor);
        dprintf (("", "lookup '%s' returned '%s' e = %s\n",
            str, vendor? vendor: "(null)", e? e->errmess: "NULL"));
    }

    if (product == NULL) {
        char str[10];
        sprintf (str, "P%04X%04X",
            UGETW(udd->idVendor),
            UGETW(udd->idProduct));
        e = _swix (MessageTrans_Lookup, _INR(0,3)|_OUT(2),
            &usbdev_messages,
            str,
            p,
            pl,
            &product);
        dprintf (("", "lookup '%s' returned '%s' e = %s\n",
            str, product? product: "(null)", e? e->errmess: "NULL"));
    }

    if (vendor == NULL) {
        char id[5];
        sprintf(id, "%04X", UGETW(udd->idVendor));
        _swix (MessageTrans_Lookup, _INR(0,4), &mod_messages,
               "DefVID", v, vl, id);
    }

    if (product == NULL) {
        char id[5];
        sprintf(id, "%04X", UGETW(udd->idProduct));
        _swix (MessageTrans_Lookup, _INR(0,4), &mod_messages,
               "DefPID", p, pl, id);
    }
}

void softintr_schedule (void* p)
{
    *(void**)p = (void*) softintr_entry;
}

int softintr (_kernel_swi_regs* r, void* pw)
{
    static volatile int reentry = 0;

//    dprintf (("", "entering soft interrupt %d\n", reentry));
    _kernel_irqs_off ();
    if (reentry++ == 0)
        while (reentry > 0)
        {
            reentry--;
//            dprintf (("", "reentry now %d\n", reentry));
            _kernel_irqs_on ();
            struct usbd_bus* sc = (struct usbd_bus*) r->r[0];
            sc->methods->soft_intr (sc);
            _kernel_irqs_off ();
        }

    _kernel_irqs_on ();
//    dprintf (("", "leaving soft interrupt %d\n", reentry));

    return 0;
}

/*--------------------------------------------------------------------------*/

/* devicefs interface */

typedef struct device_valid {
    uint32_t    endpoint;
    uint32_t    interface;
    uint32_t    alternate;
    uint32_t    report;
    uint32_t    ep_type;
    uint32_t    timeout;
    uint32_t    size;
    uint32_t    nopad;
    uint32_t    shortflag;
} device_valid;

static void find_interface_and_endpoint
(
    usbd_device_handle  dev,
    device_valid *      valid,
    uint32_t            dir,
    int*                iface_return,
    int*                alternate_return,
    int*                endpoint_return
)
{
    int                             i, j;
    usb_interface_descriptor_t *    d;
    usb_endpoint_descriptor_t *     b;

   /* if neither the ep_type nor the endpoint number were given in the special
      fields, try to find first bulk endpoint */
    if ((valid->ep_type == 0xdeaddead) && (valid->endpoint == 0xdeaddead))
    {
        valid->ep_type = UE_BULK;
    }

    dprintf (("", "looking for %x, iface %d, alt %d, type %x, dir %x\n",
        valid->endpoint, valid->interface, valid->alternate,
        valid->ep_type, dir));

    usb_config_descriptor_t * cdesc = dev->cdesc;
    char* ptr = (char*) cdesc, *ptr_end = ptr + UGETW(cdesc->wTotalLength);
    ptr += cdesc->bLength;
    i = j = -1;
    while (ptr < ptr_end)
    {
        switch (ptr[1])
        {
        case UDESC_INTERFACE:
            d = (usb_interface_descriptor_t*) ptr;
            i = d->bInterfaceNumber;
            j = d->bAlternateSetting;
            dprintf (("", "interface %d\n", i));
            break;
        case UDESC_ENDPOINT:
            if (i == -1) break;
            b = (usb_endpoint_descriptor_t *) ptr;
            dprintf (("", "endpoint %x\n", b->bEndpointAddress));
            dprintf (("", "attributes %x\n", UE_GET_XFERTYPE(b->bmAttributes)));

            /* try to match as many of the fields that have been supplied as possible,
               but the direction flag must always be correct */
            if ((valid->interface == i || valid->interface == 0xdeaddead) &&
                (valid->alternate == j || valid->alternate == 0xdeaddead) &&
                (valid->endpoint == UE_GET_ADDR(b->bEndpointAddress) || valid->endpoint == 0xdeaddead) &&
                (valid->ep_type == UE_GET_XFERTYPE(b->bmAttributes) || valid->ep_type == 0xdeaddead) &&
                /* bit is set for TX, whereas USB is set for IN */
                (((dir & 1) << 7) != UE_GET_DIR(b->bEndpointAddress)))
            {
                *iface_return = i;
                *alternate_return = j;
                *endpoint_return = b->bEndpointAddress;
                valid->ep_type = UE_GET_XFERTYPE(b->bmAttributes);
                return;
            }
            break;
        }
        ptr += ptr[0];
    }
    dprintf (("", "couldn't find an endpoint\n"));
    *iface_return = (int) 0xdeaddead;
    *alternate_return = (int) 0xdeaddead;
    *endpoint_return = (int) 0xdeaddead;
    return;
}

/*---------------------------------------------------------------------------*/

static _kernel_oserror* device_initialise
(
    int                 devicefs_handle,
    uint32_t            flags,
    device_valid *      valid,
    struct ugen_softc * ugen,
    struct devstream ** stream_handle
)
{
    int ep;
    int err;
    int iface;
    int alt = 0;
    int index = -1;
    _kernel_oserror* e = NULL;
    dprintf (("", "device_initialise: flags = %x, fs_stream = %x\n",
        flags, devicefs_handle));

    struct devstream* str = malloc (sizeof *str);
    if (str == NULL)
    {
        return uerror (E_NoMem);
    }
    memset (str, 0, sizeof *str);
    str->size = valid->size;

    str->ugen = ugen;

    /* XXX we should validate the report at this point */
    str->report = valid->report;

    /* usb timeout, used for transfers */
    str->timeout = (valid->timeout==0xdeaddead?0:valid->timeout);

    /* New flags to work around deficencies in the DeviceFS interface */
    str->flags = (valid->nopad?0:FLAG_NOPAD)|(valid->shortflag?0:FLAG_SHORT);

    str->read_status = ReadStatus_Idle;

    /* The supplied endpoint may include the direction, but mask it off internally */
    if (valid->endpoint != 0xdeaddead) valid->endpoint = UE_GET_ADDR(valid->endpoint);

    /* see if an interface was specified, if not then look for the interface
       with the endpoint specified */
    find_interface_and_endpoint
    (
        ugen->sc_udev,
        valid,
        flags,
        &iface,
        &alt,
        &ep
    );
    dprintf (("", "init_dev: found interface %x, endpoint %x\n", iface, ep));

    if (iface == 0xdeaddead)
    {
        e = uerror (E_NoEndpoint);
        goto error;
    }

    err = usbd_device2interface_handle (ugen->sc_udev, iface, &str->iface);
    if (err)
    {
        e = uerror (E_NoInterface);
        goto error;
    }

    /* force an interface alternate */
    if (alt != 0)
        usbd_set_interface(str->iface, alt);


    str->ep = ep;


    /* remove an internally connected device to this interface */
    for (int n = 0; ugen->sc_udev->subdevs[n]; ++n)
    {
        struct iface_softc* ifc;
        /* throw off mice or keyboards */

        switch ((int) (ugen->sc_udev->subdevs[n]->dv_cfdata))
        {
        case 3:
        case 4:
            ifc = (struct iface_softc*) ugen->sc_udev->subdevs[n];
            if (ifc->sc_iface->index == iface)
            {
                dprintf (("", "throwing off subdevice %d\n", n));
                /* compact the list first  */
                do
                {
                    ugen->sc_udev->subdevs[n] = ugen->sc_udev->subdevs[n + 1];
                    n++;
                }
                while (ugen->sc_udev->subdevs[n] != 0);
                config_detach ((struct device*)ifc, 0);
                goto detach_done;
            }
            break;
        }

    }
detach_done:

    index = UE_GET_ADDR(ep) + (UE_GET_DIR(ep)? 16: 0);

    /* if the stream is already used, it might have been left open,
       we're opening a HID report descriptor, or it's a mistake */
    if (ugen->str[index] != NULL && ugen->str[index]->fs_stream != 0)
    {
        if (valid->report == 0xdeaddead)
        {
            dprintf (("", "Endpoint in use, fs_stream = %x\n",
                ugen->str[index]->fs_stream));
            e = uerror (E_EndpointUsed);
            goto error;
        }

        /* it's a HID report, so link to the chain, and don't bother opening
           the pipe - we need to remember to unlink properly when we close */
        str->next_hid = ugen->str[index];
        ugen->str[index] = str;
        str->fs_stream = devicefs_handle;
        str->pipe = str->next_hid->pipe; // record pipe so that we find endpoint description
        *stream_handle = str;
        return NULL;
    }
    else if (ugen->str[index] != NULL)
    {
        /* it is a previously used endpoint left open */
        str->pipe = ugen->str[index]->pipe;
        str->xfer = ugen->str[index]->xfer;
    }


    if (str->pipe == NULL) err = usbd_open_pipe(str->iface, ep, 0, &str->pipe);
    if (err)
    {
        dprintf (("", "Couldn't open pipe, err = %d", err));
        str->pipe = NULL;
        e = uerror (E_BadPipe);
        goto error;
    }

    if (str->xfer == NULL)
    {
        if ((str->pipe->endpoint->edesc->bmAttributes & UE_XFERTYPE) == UE_ISOCHRONOUS)
        {
            str->isoc = calloc (sizeof *str->isoc, 2);
            str->isoc[0].xfer = usbd_alloc_xfer (ugen->sc_udev);
            str->isoc[1].xfer = usbd_alloc_xfer (ugen->sc_udev);
            str->xfer = str->isoc[0].xfer;
        }
        else
        {
            str->xfer = usbd_alloc_xfer (ugen->sc_udev);
        }
    }

    dprintf(("","Got xfer %08x\n",str->xfer));

    if (str->xfer == NULL)
    {
        e = uerror (E_BadXfer);
        goto error;
    }

    if ((str->pipe->endpoint->edesc->bmAttributes & UE_XFERTYPE) == UE_INTERRUPT)
    {
        str->pipe->repeat = (UE_GET_DIR(str->ep) == UE_DIR_IN)?1:0;
    }

    str->fs_stream = devicefs_handle;
    *stream_handle = str;
    ugen->str[index] = str;
    return NULL;
error:
    if (str->pipe)
        usbd_close_pipe (str->pipe);
    if (str->xfer)
        usbd_free_xfer (str->xfer);
    if (str->isoc != NULL)
    {
        if (str->isoc[1].xfer)
        {
            usbd_free_xfer (str->isoc[1].xfer);
        }
        free (str->isoc);
    }
    free (str);
    return e;
}

/*---------------------------------------------------------------------------*/

void start_write (struct devstream* str);
void start_read (struct devstream* str);

static void write_cb(usbd_xfer_handle xfer, usbd_private_handle priv,
                      usbd_status status)
{
    struct devstream* str = priv;

    dprintf(("","%08x write_cb, status=%d, actlen=%d\n",xfer,status,xfer->actlen));

    str->xfer_busy = (status == USBD_IN_PROGRESS);

    if (status != USBD_NORMAL_COMPLETION)
    {
        dprintf (("", "Bad completion code: %d (%s), %d bytes written\n", status, ccodes[status], xfer->actlen));
        return;
    }

    if (str->fs_stream == 0)
    {
        dprintf (("", "Stream has been closed\n"));
        return;
    }

#ifndef DMA_FROM_BUFFER
    _kernel_swi_regs r;
    r.r[0] = BM_NextFilledBlock;
    r.r[1] = (int) str->buffer_id;
    r.r[3] = xfer->actlen;
    CallBufMan(&r);
#endif
    start_write (str);
}

/*---------------------------------------------------------------------------*/

void start_write (struct devstream* str)
{
    int s = _kernel_irqs_disabled ();
    _kernel_irqs_off ();

    dprintf(("","%08x start_write\n",str->xfer));

    if (str->xfer == NULL)
    {
        dprintf (("", "Non-head HID stream\n"));
        goto end;
    }

    if (str->xfer_busy)
    {
        dprintf (("", "Can't start, xfer still busy\n"));
        goto end;
    }

    if (str->xfer->status != USBD_NORMAL_COMPLETION)
    {
        dprintf (("", "Can't start, status = %d (%s)\n",
            str->xfer->status, ccodes[str->xfer->status]));
        goto end;
    }

    str->xfer_busy = true;

#ifdef DMA_FROM_BUFFER
    _kernel_swi_regs r;
    r.r[0] = BM_NextFilledBlock;
    r.r[1] = str->buffer_id;
    r.r[3] = str->xfer->actlen;
    CallBufMan(&r);
#else
    _kernel_swi_regs r;
    r.r[0] = BM_UsedSpace;
    r.r[1] = str->buffer_id;
    CallBufMan(&r);
#endif
    if (r.r[2] != 0)
    {
#ifdef DMA_FROM_BUFFER
        usbd_setup_xfer(str->xfer, str->pipe, str,
            (void*) r.r[2], r.r[3], USBD_NO_COPY | (str->flags & FLAG_SHORT?USBD_FORCE_SHORT_XFER:0), 500, write_cb);
#else
        usbd_setup_xfer(
            str->xfer,
            str->pipe,
            str,
            (void*) str->buffer_id,
            r.r[2],
            (str->flags & FLAG_SHORT?USBD_FORCE_SHORT_XFER:0),
            str->timeout,
            write_cb);

        str->xfer->rqflags |= URQ_RISCOS_BUF;
        dprintf (("", "transferring %d bytes\n", r.r[2]));
#endif
        str->xfer->status = usbd_transfer (str->xfer);

        str->xfer_busy = (str->xfer->status == USBD_IN_PROGRESS);

        /* this can either return in progress, or normal completion (if
           the pipe wasn't already running) */
        if (str->xfer->status != USBD_IN_PROGRESS &&
            str->xfer->status != USBD_NORMAL_COMPLETION)
        {
            dprintf (("", "Failed to insert transfer, status = %d (%s)\n",
                str->xfer->status, ccodes[str->xfer->status]));
        }
    }
    else
    {
        str->xfer->actlen = 0;
        str->xfer_busy = false;
        dprintf (("", "no more data to write\n"));
    }

end:
    if (s == 0) _kernel_irqs_on ();
}

/*---------------------------------------------------------------------------*/

static void read_cb(usbd_xfer_handle xfer, usbd_private_handle priv,
                      usbd_status status)
{
    struct devstream* str = priv;
    bool delayed_read = str->delayed_read && !xfer->pipe->repeat;

    dprintf(("","%08x read_cb, status=%d, actlen=%d, delayed_read=%d, read_status=%d\n",xfer,status,xfer->actlen,delayed_read,str->read_status));

    str->xfer_busy = false;

    if (status != USBD_NORMAL_COMPLETION)
    {
        dprintf (("", "Bad completion code: %d (%s) %d bytes read\n",
            status, ccodes[status], xfer->actlen));
        str->delayed_read = false;
        str->read_status = ReadStatus_Complete;
        return;
    }

    if (str->fs_stream == 0)
    {
        dprintf (("", "Stream has been closed\n"));
        str->delayed_read = false;
        str->read_status = ReadStatus_Complete;
        return;
    }

    if((str->flags & FLAG_NOPAD) || (str->count == str->totalcount))
    {
        str->read_status = ReadStatus_Complete;
        /* Handle any delayed read */
        if(delayed_read)
        {
            dprintf(("", "Starting delayed read from callback\n"));
            start_read(str);
        }
        return;
    }
    /* only start another transfer if we haven't finished the transfer and
       this is not a interrupt endpoint (the BSD framework restarts
       repeating transfers) */
    /* if we've got a number of bytes including a part packet, then
       transfer must have ended.. else.. try more */
    if (xfer->actlen % UGETW(xfer->pipe->endpoint->edesc->wMaxPacketSize))
    {
        str->read_status = ReadStatus_Complete;

        /* required due to DeviceFS concept. */
        char zero[ UGETW(xfer->pipe->endpoint->edesc->wMaxPacketSize)];

        /* Note difference for later correction by application */
        int remain = str->padded_bytes = str->totalcount - str->count;
        memset (zero, 0, sizeof zero);
        /* fill up the rest of the request with garbage! */
        _kernel_swi_regs r;
        r.r[0] = BM_InsertBlock;
        r.r[1] = (int) str->buffer_id;
        while(remain > 0)
        {
            r.r[2] = (int) zero;
            r.r[3] = min(remain,UGETW(xfer->pipe->endpoint->edesc->wMaxPacketSize));
            remain -= r.r[3];
            CallBufMan (&r);
            if(r.r[3])
                break; /* Buffer was full - what do we do here? Try and insert the extra padding as more space becomes available? For now, just do what the old code did and give up */
        }
        /* Handle any delayed read */
        if(delayed_read)
        {
            dprintf(("", "Starting delayed read from callback\n"));
            start_read(str);
        }
    }
    else if (!xfer->pipe->repeat)
    {
        dprintf (("", "Starting read from callback\n"));
        start_read (str);
    }
}

/*---------------------------------------------------------------------------*/

void fill_isoc_xfer (struct devstream* str, int maxpacket)
{
    str->size = maxpacket;
    str->xfer->actlen = 0;
    usbd_setup_isoc_xfer(
        str->xfer,
        str->pipe,
        str,
        (u_int16_t*) &str->size,         /* sizes */
        1,                  /* n frames */
        USBD_SHORT_XFER_OK,
        read_cb);
    str->xfer->buffer = (void*) str->buffer_id;
    str->xfer->length = maxpacket;
}

void start_read (struct devstream* str)
{
    int s = _kernel_irqs_disabled ();
    _kernel_irqs_off ();

    dprintf(("","%08x start_read busy %d delayed %d read_status %d\n",str->xfer,str->xfer_busy,str->delayed_read,str->read_status));
    if (str->xfer == NULL)
    {
        dprintf (("", "Non-head HID stream\n"));
        goto end;
    }

    if (str->xfer_busy)
    {
        dprintf (("", "Can't start, xfer still busy\n"));
        goto end;
    }

    if (str->xfer->status != USBD_NORMAL_COMPLETION)
    {
        dprintf (("", "Can't start, status = %d (%s)\n",
            str->xfer->status, ccodes[str->xfer->status]));
        goto end;
    }

    if ((str->read_status == ReadStatus_Busy) && (str->count >= str->totalcount) && !str->xfer->pipe->repeat)
    {
        dprintf (("", "Finished reading %d bytes\n", str->totalcount));
        str->read_status = ReadStatus_Complete;
        if(!str->delayed_read)
            goto end;
        dprintf (("", "Falling through to start delayed read\n"));
    }


    if(!str->pipe->repeat)
    {
        /* Only use this logic for non-repeating xfers (i.e. only for bulk) */
        if(str->read_status != ReadStatus_Busy)
        {
            /* Starting a new transfer queued by RxWakeUp */
            if(!str->delayed_read)
            {
                dprintf(("","Can't start, no wakeup reads queued\n"));
                goto end;
            }
            dprintf(("","Starting new read of %d bytes\n",str->nextcount));
            str->delayed_read = false;
            str->totalcount = str->nextcount;
            str->count = 0;
            str->padded_bytes = 0;
            str->read_status = ReadStatus_Busy;
        }
        else
        {
            dprintf(("","Continuing read of %d bytes\n",str->totalcount));
        }
    }
    str->xfer_busy = true;

#ifdef DMA_FROM_BUFFER
    // XXX this was copied from write probably wrong for read
    _kernel_swi_regs r;
    r.r[0] = BM_NextFilledBlock;
    r.r[1] = str->buffer_id;
    r.r[3] = str->xfer->actlen;
    CallBufMan(&r);
#else
    _kernel_swi_regs r;
    r.r[0] = BM_FreeSpace;
    r.r[1] = str->buffer_id;
    CallBufMan(&r);
#endif
    int actlen = r.r[2];
    int maxpacket = UGETW(str->pipe->endpoint->edesc->wMaxPacketSize);
    if (actlen >= maxpacket)
    {
        switch (str->pipe->endpoint->edesc->bmAttributes & UE_XFERTYPE)
        {
        case UE_INTERRUPT:
        case UE_ISOCHRONOUS:
            /* if an interrupt endpoint, ask for exactly max packet */
            actlen = maxpacket;
            break;

        case UE_BULK:
            /* only ask for multiple of maxpacket if bulk */
            actlen -= actlen % maxpacket;

            /* truncate at length requested */
            if (str->totalcount && actlen > str->totalcount - str->count)
                actlen = str->totalcount - str->count;
            if (actlen <= 0)
            {
                str->xfer_busy = false;
                goto end;
            }
            break;
        }

#ifdef DMA_FROM_BUFFER
        /* this almost definitely doesn't work any more */
        usbd_setup_xfer(
            str->xfer,
            str->pipe,
            str,
            (void*) r.r[2],
            r.r[3],
            USBD_NO_COPY|USBD_SHORT_XFER_OK,
            500,
            read_cb);
#else
        switch (str->pipe->endpoint->edesc->bmAttributes & UE_XFERTYPE) {
        case UE_BULK:
        case UE_INTERRUPT:
            usbd_setup_xfer(
                str->xfer,
                str->pipe,
                str,
                (void*) str->buffer_id,
                actlen,
                USBD_SHORT_XFER_OK,
                str->timeout,
                read_cb);
            dprintf (("", "starting (bulk/interrupt) transfer of %d bytes\n",
                actlen));
            break;
        case UE_ISOCHRONOUS:
            fill_isoc_xfer (str, maxpacket);
            dprintf (("", "starting (isoc) transfer of %d bytes\n", str->size));
            break;
        }

        str->xfer->rqflags |= URQ_RISCOS_BUF;
#endif
        str->xfer->status = usbd_transfer (str->xfer);

        str->xfer_busy = (str->xfer->status == USBD_IN_PROGRESS);

        /* this can either return in progress, or normal completion (if
           the pipe wasn't already running) */
        if (str->xfer->status != USBD_IN_PROGRESS &&
            str->xfer->status != USBD_NORMAL_COMPLETION)
        {
            dprintf (("", "Failed to insert transfer, status = %d (%s)\n",
                str->xfer->status, ccodes[str->xfer->status]));
        }
    }
    else
    {
        str->xfer_busy = false;
    }
end:
    if (s == 0) _kernel_irqs_on ();
}

/*---------------------------------------------------------------------------*/

void terminate_stream (struct ugen_softc* ugen, struct devstream * str, int kill)
{
    dprintf (("", "terminate stream %p, ep %x, kill = %d\n",
        str, str?str->ep:0, kill));

    if (str == NULL)
    {
        return;
    }

    int index = UE_GET_ADDR(str->ep) + (UE_GET_DIR(str->ep)? 16: 0);

    /* don't remove stream twice! */
    if (ugen->str[index] == NULL)
    {
      return;
    }

    /* in case we were a multiply linked HID reporter, don't close the pipe */
    if (ugen->str[index]->next_hid == NULL)
    {
        if (kill)
        {
            int status;
            if (str->dying || !str->pipe) return;
            str->dying = 1;
            /* only close these when the device is removed */
            status = usbd_abort_pipe(str->pipe);
            dprintf (("", "status1: %s\n", ccodes[status]));
            status = usbd_close_pipe(str->pipe);
            dprintf (("", "status2: %s\n", ccodes[status]));
//            usbd_free_buffer (str->xfer);    /* done in usbd_free_xfer
            status = usbd_free_xfer(str->xfer);
            dprintf (("", "status3: %s\n", ccodes[status]));
            ugen->str[index] = NULL;
        }
        else
        {
            /* normally just null these entries, so the same endpoint gets
               used next time and toggling carries on */
            str->fs_stream = 0;
            str->buffer = 0;
            str->buffer_id = 0;
            str->report = 0;
            dprintf (("", "fs_stream now 0\n"));

            /* return early so we don't free the stream */
            return;
        }
    }
    else
    {
        /* otherwise, make sure we don't lose the handles, and keep the chain
           going.   */
        dprintf (("", "delinking HID stream, ep=%x\n", str->ep));
        struct devstream* s = ugen->str[index];
        if (s != str)
        {
            while (s->next_hid != str)
            {
                s = s->next_hid;
                if (s == NULL)
                {
                    dprintf (("", "*** couldn't find HID stream"));
                    return;
                }
            }

            s->next_hid = str->next_hid;
        }
        else
        {
            /* special case replacing the head */
            s = ugen->str[index] = str->next_hid;
        }
        if (str->pipe)
        {
            s->pipe = str->pipe;
            s->xfer = str->xfer;
        }
    }
    free (str);
}

/*---------------------------------------------------------------------------*/

_kernel_oserror* create_buffer
(
    struct devstream*   str,
    uint32_t            *flags,
    size_t              *size,
    uint32_t            *handle,
    size_t              *thresh
)
{
    _kernel_oserror* e = NULL;
    char* p;

    /* if we are a multiple HID device, this just return */
    if (str->xfer == NULL)
    {
        dprintf (("", "multiple HID device: str->xfer == NULL\n"));
        return NULL;
    }

    if (str->size != 0xdeaddead)
        *size = str->size;

    if ((str->pipe->endpoint->edesc->bmAttributes & UE_XFERTYPE) == UE_ISOCHRONOUS)
    {
        p = usbd_alloc_buffer (str->isoc[0].xfer, *size / 2);
        if (p == NULL) return uerror (E_NoMem);
        p = usbd_alloc_buffer (str->isoc[1].xfer, *size / 2);
        if (p == NULL) return uerror (E_NoMem);
    }
    else
    {
        p = usbd_alloc_buffer (str->xfer, *size);
        if (p == NULL) return uerror (E_NoMem);
#ifdef DMA_FROM_BUFFER
        e = _swix (Buffer_Register, _INR(0,3)|_OUT(0),
            *flags,
            p,
            p + *size,
            -1,
            handle);
#endif
    }
    *thresh = *size - UGETW(str->pipe->endpoint->edesc->wMaxPacketSize);
    return e;
}

/*---------------------------------------------------------------------------*/

_kernel_oserror* get_buffer_space
(
    struct ugen_softc*  udev,
    int                 fs,
    int*                size,
    int*                free
)
{
    int devfs;
    _kernel_oserror* e =
        _swix (OS_FSControl, _INR(0,1)|_OUT(1), 21, fs, &devfs);
    if (e) return e;

    for (int i = 0; i < sizeof (udev->str) / sizeof (udev->str[0]); ++i)
    {
        if (udev->str[i] && udev->str[i]->fs_stream == devfs)
        {
            int f;
            _kernel_swi_regs r;
            r.r[0] = BM_FreeSpace;
            r.r[1] = udev->str[i]->buffer_id;
            CallBufMan(&r);
            f = r.r[2];
            if (free) *free = f;

            r.r[0] = BM_UsedSpace;
            CallBufMan(&r);
            if (size) *size = *free + r.r[2];
            return NULL;
        }
    }

    return uerror (E_NoStream);
}

/*---------------------------------------------------------------------------*/

_kernel_oserror* get_handles
(
    struct ugen_softc*  udev,
    int                 fs,
    int*                buf,
    int*                dvfs,
    struct devstream ** str,
    devicefs_device**   sc_devfs
)
{
    int devfs;
    _kernel_oserror* e =
        _swix (OS_FSControl, _INR(0,1)|_OUT(1), 21, fs, &devfs);
    if (e) return e;

    for (int i = 0; i < sizeof (udev->str) / sizeof (udev->str[0]); ++i)
    {
        if (udev->str[i] && udev->str[i]->fs_stream == devfs)
        {
            if (dvfs) *dvfs = devfs;
            if (buf) *buf = udev->str[i]->buffer;
            if (str) *str=udev->str[i];
            if (sc_devfs) *sc_devfs=udev->sc_devfs;
            return NULL;
        }
    }

    return uerror (E_NoStream);
}

_kernel_oserror* get_location
(
    struct ugen_softc*  udev,
    char*               location
)
{
    if (location == NULL) return NULL;

    usbd_device_handle dev = udev->sc_udev;
    memset (location, 0, 6);
    while (dev->depth > 0) {
        dprintf (("main", "%d, %d\n", dev->powersrc->portno, dev->depth));
        location[dev->depth] = dev->powersrc->portno;
        dev = dev->powersrc->parent;
    };
    location[0] = dev->bus->bdev.dv_unit;

    return NULL;
}

_kernel_oserror* clear_endpoint_stall
(
    struct ugen_softc*  udev,
    int                 fs
)
{
    int devfs;
    _kernel_oserror* e =
        _swix (OS_FSControl, _INR(0,1)|_OUT(1), 21, fs, &devfs);
    if (e) return e;

    for (int i = 0; i < sizeof (udev->str) / sizeof (udev->str[0]); ++i)
    {
        if (udev->str[i] && udev->str[i]->fs_stream == devfs)
        {
            int err = usbd_clear_endpoint_stall (udev->str[i]->pipe);
#if 1
            if (err != 0) return uerror (E_BadRequest);
#else
            if (err != 0)
            {
                static _kernel_oserror e;
                char cc[5], *cp;
                sprintf (cc, "CC%02d", err);
                _swix (MessageTrans_Lookup, _INR(0,2)|_OUT(2),
                    &mod_messages, cc, 0, &cp);
                return _swix (MessageTrans_ErrorLookup, _INR(0,4),
                    E_BadRequest, &mod_messages, &e, sizeof e, cp);
            }
#endif

            udev->str[i]->xfer->status = USBD_NORMAL_COMPLETION;
            return NULL;
        }
    }

    return uerror (E_NoStream);
}

_kernel_oserror* get_transfer_info
(
    struct devstream*  str,
    int*               count,
    int*               totalcount,
    int*               status,
    int*               padded_buffer_bytes
)
{
    if (!str) {
      return uerror (E_NoStream);
      }
    *count=str->count;
    *totalcount=str->totalcount;
    switch(str->xfer->status) {
      case USBD_NORMAL_COMPLETION: {
        /* If we've got a delayed xfer, claim we're still running
           Matches old behaviour before the delayed xfer code was introduced */
        *status=(str->delayed_read?0:1);
        }
      break;
      case USBD_IN_PROGRESS: {
        *status=0;
        }
      break;
      default: {
        *status=-1;
        }
      }
    *padded_buffer_bytes=str->padded_bytes;
    return NULL;
}

_kernel_oserror* getset_options
(
    struct devstream*  str,
    int*               eor,
    int*               and
)
{
    if (!str) {
      return uerror (E_NoStream);
      }
    int new = ((str->flags & *and) ^ *eor) & FLAG_VALIDMASK;
    *eor = str->flags;
    str->flags = *and = new;
    return NULL;
}

/*---------------------------------------------------------------------------*/

_kernel_oserror* driver (_kernel_swi_regs* r, void* pw)
{
//    _kernel_oserror* e = NULL;
    struct ugen_softc* udev = (struct ugen_softc*) r->r[8];
//    int32_t ep;
    struct devstream * str = (struct devstream*) r->r[2];
    int s;

    (void) pw;

//    if (r->r[0] != 12) dprintf (("", "devfs driver reason %d, dev %p, str %p\n",
//        r->r[0], udev, str));
    switch ((uint32_t) r->r[0])
    {
    case DeviceCall_Initialise:
        return device_initialise
        (
            r->r[2],
            r->r[3],
            (device_valid *) r->r[6],
            udev,
            (struct devstream **) (r->r + 2)
        );
        break;

    case DeviceCall_Finalise:
        if (str == NULL)
        {
            for (struct devstream** str = udev->str;
                str < udev->str + sizeof udev->str / sizeof udev->str[0];
                ++str)
            {
                terminate_stream (udev, *str, 1);
            }
        }
        else
        {
            terminate_stream (udev, str, 1);
        }
        break;

    case DeviceCall_WakeUpTX:
        s = _kernel_irqs_disabled ();
        _kernel_irqs_off ();
        str->count = 0;
        dprintf (("main", "%08x wakeup write, resetting count to %d\n",
            str->xfer, str->count));
        start_write (str);
        if(s == 0) _kernel_irqs_on();
        break;
    case DeviceCall_WakeUpRX:
        if(!str->pipe->repeat && r->r[3])
        {
            s = _kernel_irqs_disabled ();
            _kernel_irqs_off ();
            /* Even if the read starts immediately, we still set the delayed_read flag, because that's what start_read checks for */
            str->delayed_read = true;
            /* total length has always been passed in R3, although not documented */
            str->nextcount = r->r[3];
            dprintf (("main", "%08x wakeup read, read_status %d, resetting nextcount to %d\n",
                str->xfer, str->read_status, str->nextcount));
            start_read (str);
            if(s == 0) _kernel_irqs_on();
        }
        break;
    case DeviceCall_SleepRX:
        break;
    case DeviceCall_EnumDir:
        break;
    case DeviceCall_CreateBufferTX:
    case DeviceCall_CreateBufferRX:
        return create_buffer (
            (struct devstream*) r->r[2],
            (uint32_t*)r->r + 3,
            (size_t*)r->r + 4,
            (uint32_t*)r->r + 5,
            (size_t*)r->r + 6);
        break;
    case DeviceCall_Halt:
        break;
    case DeviceCall_Resume:
        dprintf (("main", "%08x resume ep = %x\n", str->xfer, str->ep));
        /* if the top bit is set, this is an IN endpoint */
        if (UE_GET_DIR(str->ep) == UE_DIR_IN)
        {
            if (!str->pipe->repeat)
                start_read (str);
        }
        else start_write (str);
        break;
    case DeviceCall_EndOfData:
        /* this was to try and make bulk transfers finish neatly, but doesn't
           seem to achieve the desired effect */
        if (str->xfer->status == USBD_IN_PROGRESS)
            r->r[3] = 0;
        break;
    case DeviceCall_StreamCreated:
        str->buffer = r->r[3];
        _swix (Buffer_InternalInfo, _IN(0)|_OUTR(0,2),

            r->r[3],

            &str->buffer_id,
            &BuffManService,
            &BuffManWS);
        if (
            (str->pipe->endpoint->edesc->bmAttributes & UE_XFERTYPE) ==
                UE_INTERRUPT ||
            (str->pipe->endpoint->edesc->bmAttributes & UE_XFERTYPE) ==
                UE_ISOCHRONOUS
        )
        {
            /* obviously only do this if we're an in endpoint */
            if (UE_GET_DIR(str->ep) == UE_DIR_IN)
            {
              dprintf(("","%08x start_read from StreamCreated\n",str->xfer));
              start_read(str);
            }
        }
        break;
    case DeviceCall_MonitorTX:
    case DeviceCall_MonitorRX:
        {
            /* the xfer is NULL for case of HID not owning the xfer */
            if (str->xfer == NULL)
                return NULL;

            int status = str->xfer->status;
/* normal completion occurs when a transfer has finished */
            if (status == USBD_NORMAL_COMPLETION ||
                status == USBD_IN_PROGRESS)
                return NULL;


            _kernel_swi_regs r;

            /* empty the buffer so that we return */
            r.r[0] = BM_PurgeBuffer;
            r.r[1] = str->buffer_id;
            CallBufMan (&r);

            static _kernel_oserror err;
            char errtoken[sizeof E_XferFailed] = E_XferFailed, cc[5], *cp;
            ((_kernel_oserror *)errtoken)->errnum += status;
            sprintf (cc, "CC%02d", status);
            _swix (MessageTrans_Lookup, _INR(0,2)|_OUT(2),
                &mod_messages, cc, 0, &cp);
            return _swix (MessageTrans_ErrorLookup, _INR(0,4),
                errtoken, &mod_messages, &err, sizeof err, cp);
        }
        break;
    case DeviceCall_USB_USBRequest:
        {
            struct req { int a, b; } rq = (struct req) { r->r[3], r->r[4] };
            int err = usbd_do_request (udev->sc_udev, (void*) &rq, (char*)r->r[5]);
#if 1
            if (err != 0) return uerror (E_BadRequest);
#else
            if (err != 0)
            {
                static _kernel_oserror e;
                char cc[5], *cp;
                sprintf (cc, "CC%02d", err);
                _swix (MessageTrans_Lookup, _INR(0,2)|_OUT(2),
                    &mod_messages, cc, 0, &cp);
                return _swix (MessageTrans_ErrorLookup, _INR(0,4),
                    E_BadRequest, &mod_messages, &e, sizeof e, cp);
            }
#endif

            break;
        }
    case DeviceCall_USB_BufferSpace:
        return get_buffer_space (udev, r->r[2], r->r + 3, r->r + 4);
        break;
    case DeviceCall_USB_GetHandles:
        return get_handles (udev, r->r[2], r->r + 3, r->r + 4, NULL, NULL);
        break;
    case DeviceCall_USB_GetLocation:
        return get_location (udev, (char*) r->r[3]);
        break;
    case DeviceCall_USB_ClearStall:
        return clear_endpoint_stall (udev, r->r[2]);
        break;
    case DeviceCall_USB_TransferInfo:
        return get_transfer_info (str, r->r + 0, r->r + 1, r->r + 3, r->r + 4);
        break;
    case DeviceCall_USB_GetHandles2:
        return get_handles (udev, r->r[2], r->r + 3, r->r + 4, (struct devstream **) ((int *) r->r + 5), (devicefs_device**) ((int *) r->r + 6));
        break;
    case DeviceCall_USB_GetSetOptions:
        return getset_options (str, r->r + 3, r->r + 4);
        break;
    }

    return NULL;
}

/*--------------------------------------------------------------------------*/
