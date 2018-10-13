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
/* mouse interface */
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "Global/RISCOS.h"
#include "Global/Keyboard.h"
#include "Global/Pointer.h"
#include "callx/callx.h"

#include "USBDriverHdr.h"
#include "swis.h"
#include "debuglib/debuglib.h"

#include <sys/callout.h>
#include <sys/ioctl.h>

#include "dev/usb/usb.h"
#include "dev/usb/usbdi.h"
#include "dev/usb/usbdi_util.h"
#include "dev/usb/usbdivar.h"
#include "dev/usb/usbhid.h"

#include "usbkboard.h"

#include "wimplib.h"

#define MagicNoDebounce 0x4e6f4b64

#define NUM_LOCK 0x01
#define CAPS_LOCK 0x02
#define SCROLL_LOCK 0x04

#define RSVD 0xFF     /* Reserved keys that have no mapping */
#define NEQV 0xFF     /* Keys in USB that have no RISC OS equivalent */
#define UDEF 0xFF     /* Keys that are undefined */

#define NKEYCODE 6

extern void* private_word;

void ukbd_intr(usbd_xfer_handle, usbd_private_handle, usbd_status);

struct ukbd_data {
    uint8_t modifiers;
    uint8_t reserved;
    uint8_t keycode[NKEYCODE];
};

struct ukbd_softc {
    USBBASEDEVICE           sc_dev;
    usbd_device_handle      sc_udev;
    usbd_interface_handle   sc_iface;       /* interface */
    usbd_pipe_handle        sc_intrpipe;    /* interrupt pipe */
    int                     sc_ep_addr;

    /* bits to keep track of keys currently depressed */
    uint32_t                status[8];

    struct ukbd_data        data, odata;

    /* LEDS */
    uint8_t                 res;

    /* list of ukbd softcs */
    TAILQ_ENTRY(ukbd_softc) link_kb;
};

TAILQ_HEAD(ukbdlist, ukbd_softc) allukbds = TAILQ_HEAD_INITIALIZER(allukbds);

/* Mapping table from USB keycodes to low-level internal key numbers - see PRM
 * 1-156.  The index into the table is the USB keycode, as defined in the HID
 * Usage tables.  The array starts off a-z, 1-0.
 */
static unsigned char mapping_table[256] = {
RSVD,               RSVD,            RSVD,             RSVD,             /*0*/
KeyNo_LetterA,      KeyNo_LetterB,   KeyNo_LetterC,    KeyNo_LetterD,
KeyNo_LetterE,      KeyNo_LetterF,   KeyNo_LetterG,    KeyNo_LetterH,
KeyNo_LetterI,      KeyNo_LetterJ,   KeyNo_LetterK,    KeyNo_LetterL,
KeyNo_LetterM,      KeyNo_LetterN,   KeyNo_LetterO,    KeyNo_LetterP,    /*1*/
KeyNo_LetterQ,      KeyNo_LetterR,   KeyNo_LetterS,    KeyNo_LetterT,
KeyNo_LetterU,      KeyNo_LetterV,   KeyNo_LetterW,    KeyNo_LetterX,
KeyNo_LetterY,      KeyNo_LetterZ,   KeyNo_Digit1,     KeyNo_Digit2,
KeyNo_Digit3,       KeyNo_Digit4,    KeyNo_Digit5,     KeyNo_Digit6,     /*2*/
KeyNo_Digit7,       KeyNo_Digit8,    KeyNo_Digit9,     KeyNo_Digit0,
KeyNo_Return,       KeyNo_Escape,    KeyNo_BackSpace,  KeyNo_Tab,
KeyNo_Space,        KeyNo_Minus,     KeyNo_Equals,     KeyNo_OpenSquare,
KeyNo_CloseSquare,  KeyNo_BackSlash, KeyNo_BackSlash,  KeyNo_SemiColon,  /*3*/
KeyNo_Tick,         KeyNo_BackTick,  KeyNo_Comma,      KeyNo_Dot,
KeyNo_Slash,        KeyNo_CapsLock,  KeyNo_Function1,  KeyNo_Function2,
KeyNo_Function3,    KeyNo_Function4, KeyNo_Function5,  KeyNo_Function6,
KeyNo_Function7,    KeyNo_Function8, KeyNo_Function9,  KeyNo_Function10, /*4*/
KeyNo_Function11,   KeyNo_Function12,KeyNo_Print,      KeyNo_ScrollLock,
KeyNo_Break,        KeyNo_Insert,    KeyNo_Home,       KeyNo_PageUp,
KeyNo_Delete,       KeyNo_Copy,      KeyNo_PageDown,   KeyNo_CursorRight,
KeyNo_CursorLeft,   KeyNo_CursorDown,KeyNo_CursorUp,   KeyNo_NumLock,    /*5*/
KeyNo_NumPadSlash,  KeyNo_NumPadStar,KeyNo_NumPadMinus,KeyNo_NumPadPlus,
KeyNo_NumPadEnter,  KeyNo_NumPad1,   KeyNo_NumPad2,    KeyNo_NumPad3,
KeyNo_NumPad4,      KeyNo_NumPad5,   KeyNo_NumPad6,    KeyNo_NumPad7,
KeyNo_NumPad8,      KeyNo_NumPad9,   KeyNo_NumPad0,    KeyNo_NumPadDot,  /*6*/
KeyNo_NotFittedLeft,KeyNo_Menu,      NEQV,             KeyNo_NumPadHash,
NEQV,               NEQV,            NEQV,             NEQV,
NEQV,               NEQV,            NEQV,             NEQV,
NEQV,               NEQV,            NEQV,             NEQV,             /*7*/
NEQV,               NEQV,            NEQV,             NEQV,
NEQV,               NEQV,            NEQV,             NEQV,
NEQV,               NEQV,            NEQV,             NEQV,
NEQV,               NEQV,            NEQV,             NEQV,             /*8*/
NEQV,               NEQV,            NEQV,             KeyNo_NotFittedRight,
KeyNo_Kana,         KeyNo_Pound,     KeyNo_Convert,    KeyNo_NoConvert,
NEQV,               NEQV,            NEQV,             NEQV,
NEQV,               NEQV,            NEQV,             NEQV,             /*9*/
NEQV,               NEQV,            NEQV,             NEQV,
NEQV,               NEQV,            NEQV,             NEQV,
NEQV,               NEQV,            NEQV,             NEQV,
NEQV,               NEQV,            NEQV,             NEQV,             /*a*/
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,             /*b*/
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,             /*c*/
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,             /*d*/
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
KeyNo_CtrlLeft,     KeyNo_ShiftLeft, KeyNo_AltLeft,    KeyNo_AcornLeft,  /*e*/
KeyNo_CtrlRight,    KeyNo_ShiftRight,KeyNo_AltRight,   KeyNo_AcornRight,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,             /*f*/
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD,
RSVD,               RSVD,            RSVD,             RSVD
};

extern void remove_all_keyboards (void)
{
    struct ukbd_softc* sc;
    TAILQ_FOREACH(sc, &allukbds, link_kb)
    {
        detach_keyboard ((struct device*) sc);
    }
}

struct device* attach_keyboard (struct device* parent, void* aux)
{
    struct ukbd_softc* softc;
    struct usb_attach_arg *uaa = aux;
    usb_interface_descriptor_t *id;
    usb_endpoint_descriptor_t *ed;

    dprintf (("", "Trying match on usb keyboard\n"));

    /* First see if we match */
    /* Check that this is a keyboard that speaks the boot protocol. */
    if (uaa->iface == NULL)
    {
       dprintf (("", "Failed to match\n"));
       return (UMATCH_NONE);
    }
    id = usbd_get_interface_descriptor(uaa->iface);
    if (id == NULL ||
        id->bInterfaceClass != UICLASS_HID ||
        id->bInterfaceSubClass != UISUBCLASS_BOOT ||
        id->bInterfaceProtocol != UIPROTO_BOOT_KEYBOARD)
    {
       dprintf (("", "Failed to match\n"));
       return (UMATCH_NONE);
    }

    /* If so, allocate memory for the device and attach ourselves. */
    softc = calloc (sizeof *softc, 1);
    if (softc == NULL) {
        dprintf (("", "Couldn't allocate memory for keyboard device\n"));
        return NULL;
    }
    strcpy (softc->sc_dev.dv_xname, "USBK"Module_VersionString);
    softc->sc_dev.dv_cfdata = (void*) 4; // keyboard

    softc->sc_udev = uaa->device;
    softc->sc_iface = uaa->iface;

    ed = usbd_interface2endpoint_descriptor(uaa->iface, 0);
    if (ed == NULL) {
        dprintf(("", "Could not read endpoint descriptor\n"));
        free(softc);
        return NULL;
    }

    if (usbd_set_protocol(uaa->iface, 0)) {
        dprintf(("", "Set protocol failed\n"));
        free(softc);
        return NULL;
    }

    softc->sc_ep_addr = ed->bEndpointAddress;


    if (TAILQ_EMPTY(&allukbds))
        _swix (OS_Claim, _INR(0,2), KEYV, keyv_entry, private_word);

    TAILQ_INSERT_TAIL (&allukbds, softc, link_kb);

    _swix (OS_CallAVector, _INR(0, 2) | _IN(9),
        KeyV_KeyboardPresent, KeyboardID_PC , MagicNoDebounce, KEYV);
    dprintf (("", "USB keyboard enabled\n"));

    /* set idle rate to 0 */
    usbd_set_idle (softc->sc_iface, 0, 0);

    /* Set up interrupt pipe. */
    usbd_open_pipe_intr(softc->sc_iface, softc->sc_ep_addr,
        USBD_SHORT_XFER_OK, &softc->sc_intrpipe, softc,
        &softc->data, sizeof(softc->data), ukbd_intr,
        USBD_DEFAULT_INTERVAL);

    return (struct device*) softc;
}

int detach_keyboard (struct device* kb)
{
    struct ukbd_softc* sc = (struct ukbd_softc*) kb;
    if(!sc || !sc->sc_intrpipe)
    {
      dprintf (("", "attempt to detach a NULL keyboard 'sc'\n"));
      return 0;
    }

    uint32_t * status = sc->status;
    /* release any keys held down */
    for (int w = 0; w < sizeof sc->status / sizeof (int); ++w)
    {
        if (status[w] == 0) continue;
        int key = w * 32;
        for (uint32_t ww = status[w]; ww; ww >>= 1, key++)
        {
            if ((ww & 1) == 0) continue;

            _swix (OS_CallAVector,

                _INR(0,1) | _IN(9),

                KeyV_KeyUp,
                key,
                KEYV
            );
        }
    }

    usbd_abort_pipe(sc->sc_intrpipe);
    usbd_close_pipe(sc->sc_intrpipe);
    TAILQ_REMOVE (&allukbds, sc, link_kb);
    if (TAILQ_EMPTY(&allukbds))
    {
        _swix (OS_Release, _INR(0,2), KEYV, keyv_entry, private_word);
        /* Notify any other drivers (e.g. PandoraKey) that there (probably) aren't any PC keyboards connected anymore */
        _swix (OS_CallAVector, _INR(0,1)|_IN(9), KeyV_KeyboardRemoved, KeyboardID_PC, KEYV);
    }
    free (kb);
    return 0;
}

int keyv (_kernel_swi_regs* r, void* pw)
{
    (void) pw;

    struct ukbd_softc* sc;
    TAILQ_FOREACH(sc, &allukbds, link_kb)
    {
        uint8_t * res = &sc->res;

        switch (r->r[0]) {
        case KeyV_EnableDrivers:
            memset (&sc->status[0], 0, sizeof sc->status);
            break;
        case KeyV_NotifyLEDState:
            *res = 0;
            if (r->r[1] & KeyV_LED_ScrollLock) *res |= SCROLL_LOCK;
            if (r->r[1] & KeyV_LED_NumLock) *res |= NUM_LOCK;
            if (r->r[1] & KeyV_LED_CapsLock) *res |= CAPS_LOCK;
            usbd_set_report_async(sc->sc_iface, UHID_OUTPUT_REPORT,
                0, res, 1);
            break;
        }
    }

    return 1;
}

#ifdef PS2KLUDGE
_kernel_oserror* keyup (_kernel_swi_regs* r, void* pw, void* k)
{
    (void) r;
    (void) pw;

//    dprintf (("", "Key Up: %x\n", (int) k));
    return _swix (OS_CallAVector,

        _INR(0,1) | _IN(9),

        KeyV_KeyUp,
        k,
        KEYV
    );
}
#endif

void ukbd_intr
(
    usbd_xfer_handle    xfer,
    usbd_private_handle addr,
    usbd_status         ustatus
)
{
    struct ukbd_softc *sc = addr;
    struct ukbd_data * data = &sc->data;
    struct ukbd_data * odata = &sc->odata;
    uint32_t * status = sc->status;
    int i;
    int key;
    int bit;
    uint8_t mods;
    uint8_t omods = odata->modifiers;
    uint8_t moddiff;
    uint32_t newstatus[8];

//    if (ustatus == USBD_CANCELLED)
//        return;

    if (ustatus) {
        dprintf(("", "ukbd_intr: status=%d\n", ustatus));
        if (ustatus != USBD_CANCELLED)
        {
            usbd_clear_endpoint_stall_async(sc->sc_intrpipe);
        }
        return;
    }

    mods = data->modifiers;

    /* check for error condition */
    if (data->keycode[0] == 1) return;

//    dprintf (("", "%02x %02x %02x %02x %02x %02x %02x %02x\n",
//        data->modifiers,
//        data->reserved,
//        data->keycode[0],
//        data->keycode[1],
//        data->keycode[2],
//        data->keycode[3],
//        data->keycode[4],
//        data->keycode[5]));

    memset (&newstatus[0], 0, sizeof newstatus);

    /* check each bit of the modifier field, if it's changed state,
       report the new state */
    moddiff = mods ^ omods;
    for (i = 0; i < 8; ++i) {
        if (moddiff & (1 << i)) {
            _swix (OS_CallAVector,

                _INR(0,1) | _IN(9),

                (mods & (1 << i))? KeyV_KeyDown: KeyV_KeyUp,
                mapping_table[0xe0 + i],
                KEYV
            );
        }
    }

    /* Scan new keys for key down event.  We have to construct the
    newstatus before we can check for key down. */
    for (i = 0; i < NKEYCODE; ++i) {
        key = mapping_table[data->keycode[i]];
        if (key != RSVD && key != NEQV) {
            bit = 1 << (key % 32);
            newstatus[key / 32] |= bit;
            if ((status[key / 32] & bit) == 0)
            {
                _swix (OS_CallAVector,

                    _INR(0,1) | _IN(9),

                    KeyV_KeyDown,
                    key,
                    KEYV
                );
//                dprintf (("", "Key Down: %x\n", key));
            }
        }
    }

    /* Scan old keys for key up event */
    for (i = 0; i < NKEYCODE; ++i) {
        key = mapping_table[odata->keycode[i]];
        if (key != RSVD && key != NEQV) {
            bit = 1 << (key % 32);
            if ((newstatus[key / 32] & bit) == 0)
            {
#ifdef PS2KLUDGE
                callx_add_callafter (2, keyup, (void*) key);
#else
                _swix (OS_CallAVector,

                    _INR(0,1) | _IN(9),

                    KeyV_KeyUp,
                    key,
                    KEYV
                );
//                dprintf (("", "Key Up: %x\n", key));
#endif
            }
        }
    }

    memcpy (sc->status, newstatus, sizeof sc->status);
    sc->odata = *data;
}
