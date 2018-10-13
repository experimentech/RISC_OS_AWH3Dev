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
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>

#include "swis.h"

#include "scsiswitch.h"
#include "asm.h"
#include "module.h"
#include "debuglib/debuglib.h"
#include "callx/callx.h"
#include "header.h"

#ifdef DEBUGLIB
#define DEBUG
#endif
#ifdef DEBUG
#undef dprintf
#define dprintf(...) _dprintf("",__VA_ARGS__)  
#else
#undef dprintf
#define dprintf(...) (void) 0
#endif

_kernel_oserror *scsi_op_internal(Device *dev, Driver *driver,
                                  uint32_t flags, uint32_t devid,
                                  _kernel_swi_regs *r);
_kernel_oserror *calldriver(int id, int reason, _kernel_swi_regs *r);
void start_command(Driver *driver);

#define ROR(x,r) (((uint32_t) (x) >> r) | ((x) << (32-(r))))
static inline uint32_t revbytes(uint32_t x)
{
    /* The classic 3-instruction (+1 for the constant load) ARM endianness
     * swap. ARMv6 actually has an instruction to do it. (!?)
     */
    uint32_t t;
    t = x ^ ROR(x, 16);
    t = 0xFFFF00FF & (t >> 8);
    return t ^ ROR(x, 8);
}

static int operation_id; /* Unique operation ID counter */

static Bus *bustable[BUSCOUNT];

// Internally the device driver always runs SCSI transfers as background tasks
// that perform a callback on completion/error. The 'foreground' transfers are
// achieved by setting up an internal background handler and looping in the
// foreground until the callback handler indicates completion by writing to
// a block allocated on the stack. The format of this block is:-
typedef struct CallBkRec
{   /* Keep in sync with 'asm_callbackhandler' */
    int r[5];
    int stat;
} CallBkRec;

_kernel_oserror *scsi_devices(void)
{
    _kernel_oserror *e;
    char buffer[256];
    char *append;
    bool printed = false;
    int lastbus = 0;

    /* While we could be fancy and resize the columns based on the internationalised
     * column headings, there's bound to be someone looking at hardwired offsets
     * within the string returned by SCSI_Initialise 3, so instead just crop the
     * column headings at their original english widths.
     */
    append = buffer + sprintf(buffer, "%-7.6s", module_lookup("Dev"));
    append = append + sprintf(append, "%-18.17s", module_lookup("Typ"));
    append = append + sprintf(append, "%-12.11s", module_lookup("Cap"));
    append = append + sprintf(append, "%-9.8s", module_lookup("Ven"));
    append = append + sprintf(append, "%-17.16s", module_lookup("Prd"));
    sprintf(append, "%s", module_lookup("Rev"));
    e = _swix(OS_Write0, _IN(0), buffer);
    if (!e) e = _swix(OS_NewLine, 0);
    if (e) return e;

    for (int b = 0; b < BUSCOUNT && (!e || (e && e->errnum == SCSI_ErrorBase+SCSI_NoDevice)); b++)
    {
        if (bustable[b] == NULL) continue;
        for (int id = 0; id<bustable[b]->devices; id++)
        {
            for (int lun = 0; lun < 8; lun++)
            {
                e = _swix(SCSI_Initialise, _INR(0,3),
                          3, DEVID(b,id,lun), buffer, sizeof(buffer));

                if (e && e->errnum == SCSI_ErrorBase+SCSI_NoDevice)
                    break;
                if (lun == 0 || !e)
                {
                    _kernel_oserror *e2 = NULL;
                    if (printed && lastbus != b) e2 = _swix(OS_NewLine, 0);
                    if (!e2) e2 = _swix(OS_Write0, _IN(0), buffer);
                    if (!e2) e2 = _swix(OS_NewLine, 0);
                    if (e2) return e2;
                    lastbus = b;
                    printed = true;
                }
                if (e) break;
            }
        }
    }

    return NULL;
}

static int find_free_bus(void)
{
    for (int i = 0; i < BUSCOUNT; i++)
        if (!bustable[i])
            return i;

    return -1;
}

static int find_free_device_on_bus(int b)
{
    Bus *bus = bustable[b];

    if (bus && !bus->driver)
        for (int i = 0; i < bus->devices; i++)
            if (!bus->dev[i].driver)
                return i;

    return -1;
}

static Cmd *find_command(Driver *driver, uint32_t op)
{
    Cmd *cmd;
    for (cmd = driver->first_cmd; cmd; cmd = cmd->next)
        if (cmd->op_id == op)
            break;

    return cmd;
}

static _kernel_oserror *address_device(int id, Bus **bout, Device **dout)
{
    int b = BUS(id);
    int d = DEV(id);
    Bus *bus = bustable[b];
    if (!bus) return module_error(SCSI_BadDevID);
    if (d >= bus->devices) return module_error(SCSI_BadDevID);
    *bout = bus;
    *dout = &bus->dev[d];
    return NULL;
}

static _kernel_oserror *validate_id(int id)
{
    int b = BUS(id);
    int d = DEV(id);
    Bus *bus = bustable[b];
    if (!bus) return module_error(SCSI_BadDevID);
    if (d >= bus->devices) return module_error(SCSI_BadDevID);
    if (d == bus->hostid) return module_error(SCSI_BadDevID);
    return NULL;
}


static _kernel_oserror *check_access(Device *dev, _kernel_swi_regs *r)
{
    if (dev->accesskey == 0 || dev->accesskey == r->r[8] || r->r[8] == MAGIC_ACCESS_KEY)
        return NULL;
    else
        return module_error(SCSI_DevReserved);
}

#define BCD(x) ((((x)/100)<<8) + (((x)/10%10)<<4) + ((x)%10))

_kernel_oserror *scsi_version(_kernel_swi_regs *r)
{
    r->r[0] = BCD(Module_VersionNumber);
    r->r[1] = 0x1000FF9F;
    r->r[2] = 0x100;
    r->r[3] = 0x0000FFFF;
    return NULL;
}

static _kernel_oserror *scsi_reset_bus(Bus *bus, _kernel_swi_regs *r)
{
    ADDRESS_BUS_DRIVER

    calldriver(r->r[1], DRV_RESET_BUS, r);

    bus->hostid = DEV(r->r[1]);

    driver->first_cmd = NULL;
    driver->cmd_map = CMDBITS;

    for (int d = 0; d < bus->devices; d++)
    {
        Device *dev = &bus->dev[d];
        memset(dev, 0, sizeof *dev);
    }

    return NULL;
}

//static void scsi_message_internal(Device *dev, Driver *driver,
//                                  uint32_t reason, uint32_t devid)
//{
//    _kernel_swi_regs regs;
//    regs.r[1] = sizeof CDB_INQUIRY_NOTX;
//    regs.r[2] = (int) CDB_INQUIRY_NOTX;
//    regs.r[4] = 0;
//    regs.r[5] = 0;
//    regs.r[6] = 0;
//    regs.r[7] = 0;
//
//    reason |= CTL_INHIBITREQUESTSENSE;
//    if (driver->features & DF_BACKGROUND) reason |= CTL_BACKGROUND;
//
//    scsi_op_internal(dev, driver,
//                     reason,
//                     devid, &regs);
//}

static _kernel_oserror *scsi_reset_device(Bus *bus, _kernel_swi_regs *r)
{
    VALIDATE_ID(r->r[1])
    ADDRESS_DEVICE_FROM_BUS(bus, r->r[1])
    ADDRESS_DRIVER

    _kernel_oserror *e = check_access(dev, r); if (e) return e;

//    scsi_message_internal(dev, driver, CTL_DOINGRESET, r->r[1]);

    return NULL;
}

static _kernel_oserror *scsi_determine_device(Bus *bus, _kernel_swi_regs *r)
{
    VALIDATE_ID(r->r[1])
    ADDRESS_DEVICE_FROM_BUS(bus, r->r[1])
    ADDRESS_DRIVER
    _kernel_oserror *e;
    _kernel_swi_regs regs;
    uint32_t inq[CDB_INQUIRY_L_LEN/4];
    uint32_t cap[2];

    regs.r[1] = sizeof CDB_INQUIRY;
    regs.r[2] = (int) CDB_INQUIRY_L;
    regs.r[3] = (int) inq;
    regs.r[4] = (int) CDB_INQUIRY_L_LEN;
    regs.r[5] = 0;
    e = scsi_op_internal(dev, driver,
                         CTL_INHIBITDISCONNECTION|CTL_TXREAD,
                         r->r[1], &regs);
    if (e) return e;
#ifdef TEST_BEFORE_CAPACITY
    regs.r[1] = sizeof CDB_TEST_READY;
    regs.r[2] = (int) CDB_TEST_READY;
    regs.r[3] = 0;
    regs.r[4] = 0;
    regs.r[5] = 0;
    e = scsi_op_internal(dev, driver,
                         CTL_INHIBITDISCONNECTION,
                         r->r[1], &regs);
#endif
    if (!e)
    {
        regs.r[1] = sizeof CDB_CAPACITY;
        regs.r[2] = (int) CDB_CAPACITY;
        regs.r[3] = (int) cap;
        regs.r[4] = 8;
        regs.r[5] = 0;
        e = scsi_op_internal(dev, driver,
                             CTL_INHIBITDISCONNECTION|CTL_TXREAD,
                             r->r[1], &regs);
    }
    if (regs.r[4] != 0)
        cap[0] = cap[1] = 0xFFFFFFFF;

    uint32_t *out = (uint32_t *) r->r[2];
    out[0] = inq[0];
    out[1] = inq[1] & 0xFF;
    out[2] = revbytes(cap[0]);
    out[3] = revbytes(cap[1]);

    return e;
}

typedef struct cap_data
{
    uint32_t maxblock;
    uint32_t blocksize;
} cap_data;

typedef struct inq_data
{
    uint8_t type;
    uint8_t removable; // bit 7
    uint8_t version;
    uint8_t format;
    uint8_t add_length;
    uint8_t sccs;      // bit 7
    uint8_t flags1;
    uint8_t flags2;
    char vendor[8];
    char product[16];
    char revision[4];
} inq_data;

typedef struct det_data
{
    cap_data cap;
    inq_data inq;
} det_data;

static _kernel_oserror *determinedevice(Device *dev, Driver *driver,
                                        uint32_t devid,
                                        det_data *det,
                                        uint8_t **endptr)
{
    _kernel_oserror *e;
    _kernel_swi_regs regs;

    det->cap.maxblock = det->cap.blocksize = 0xFFFFFFFF;

#ifdef TEST_BEFORE_CAPACITY
    regs.r[1] = sizeof CDB_TEST_READY;
    regs.r[2] = (int) CDB_TEST_READY;
    regs.r[3] = 0;
    regs.r[4] = 0;
    regs.r[5] = 0;
    e = scsi_op_internal(dev, driver,
                         CTL_INHIBITDISCONNECTION,
                         devid, &regs);
#else
    e = NULL;
#endif
    if (!e)
    {
        regs.r[1] = sizeof CDB_CAPACITY;
        regs.r[2] = (int) CDB_CAPACITY;
        regs.r[3] = (int) &det->cap;
        regs.r[4] = 8;
        regs.r[5] = 0;
        e = scsi_op_internal(dev, driver,
                             CTL_INHIBITDISCONNECTION|CTL_TXREAD,
                             devid, &regs);
        if (regs.r[4] == 0)
        {
            det->cap.maxblock = revbytes(det->cap.maxblock);
            det->cap.blocksize = revbytes(det->cap.blocksize);
        }
    }

    regs.r[1] = sizeof CDB_INQUIRY_L;
    regs.r[2] = (int) CDB_INQUIRY_L;
    regs.r[3] = (int) &det->inq;
    regs.r[4] = (int) CDB_INQUIRY_L_LEN;
    regs.r[5] = 0;
    e = scsi_op_internal(dev, driver,
                         CTL_INHIBITDISCONNECTION|CTL_TXREAD,
                         devid, &regs);
    if (endptr) *endptr = (uint8_t *) regs.r[3];
    return e;
}

static void cleantext(char *text, size_t len)
{
    while (len)
    {
        int c = *text;
        if (c < 32 || c == 127) *text = ' ';
        text++;
        len--;
    }
}

static _kernel_oserror *scsi_enumerate_device(Bus *bus, _kernel_swi_regs *r)
{
    _kernel_oserror *e;
    char *buffer = (char *) r->r[2];
    size_t bufsize = r->r[3];
    det_data det = { 0 };
    int len;

    r->r[3] = (int) buffer;

    if (bufsize == 0) return NULL;

    len = snprintf(buffer, bufsize, "%u:%u.%u  ",
                   BUS(r->r[1]), DEV(r->r[1]), LUN(r->r[1]));
    if (len >= bufsize) { r->r[3] = (int) buffer + bufsize; return NULL; }
    r->r[3] = (int) (buffer += len); bufsize -= len;

    if (DEV(r->r[1]) == bus->hostid)
    {
        _kernel_swi_regs regs;

        /* Host psuedo device */
        if (LUN(r->r[1]) != 0) return module_error(SCSI_CC_IllegalRequest);
        regs.r[0] = (int) &det.inq.vendor;
        regs.r[1] = r->r[1];
        calldriver(r->r[1], DRV_HOST_DESC, &regs);

        len = snprintf(buffer, bufsize, "%-30.17s", module_lookup("Hst")); 
    }
    else
    {
        VALIDATE_ID(r->r[1]);
        ADDRESS_DEVICE_FROM_BUS(bus, r->r[1]);
        ADDRESS_DRIVER

        e = determinedevice(dev, driver, r->r[1], &det, NULL);
        if (e) return e;

        uint8_t type = det.inq.type;
        char token[4];
        if (type == 0x7F) return module_error(SCSI_CC_IllegalRequest);
        sprintf(token, "T%02x", type);
        len = snprintf(buffer, bufsize, "%-18.17s", module_lookup(token));
        if (len >= bufsize) { r->r[3] = (int) buffer + bufsize; return NULL; }
        buffer += len; bufsize -= len;

        if (det.cap.maxblock == -1 && det.cap.blocksize == -1)
        {
            /* Capacity unknown */
            len = snprintf(buffer, bufsize, "%-12.11s", module_lookup("Unk"));
        }
        else
        {
            unsigned long long size = (det.cap.maxblock + 1ULL) * det.cap.blocksize;
            const char *suffix = " kMGTPE";

            while (size >= 4096)
            {
                unsigned carry = (unsigned) size & (1<<9);
                size >>= 10; if (carry) size++;
                suffix++;
            }

            unsigned s = (unsigned) size;

            len = snprintf(buffer, bufsize, "%4u %cbyte%c ",
                                            s, *suffix, s == 1 ? ' ' : 's');
        }
    }
    if (len >= bufsize) { r->r[3] = (int) buffer + bufsize; return NULL; }
    buffer += len; bufsize -= len;

    cleantext(det.inq.vendor, sizeof det.inq.vendor +
                              sizeof det.inq.product +
                              sizeof det.inq.revision);

    len = snprintf(buffer, bufsize, "%-9.8s%-17.16s%-4.4s",
                                    det.inq.vendor, det.inq.product,
                                    det.inq.revision);
    if (len >= bufsize) { r->r[3] = (int) buffer + bufsize; return NULL; }
    buffer += len; bufsize -= len;

    r->r[3] = (int) buffer;
    return NULL;
}

_kernel_oserror *scsi_initialise(_kernel_swi_regs *r)
{
    ADDRESS_BUS(r->r[1])

    switch (r->r[0])
    {
        case 0: return scsi_reset_bus(bus, r);
        case 1: return scsi_reset_device(bus, r);
        case 2: return scsi_determine_device(bus, r);
        case 3: return scsi_enumerate_device(bus, r);
        default: return module_error(SCSI_RCunkn);
    }
}

static void abort_op(Cmd *cmd, uint32_t reason)
{
    _kernel_swi_regs regs;
    regs.r[0] = reason;
    regs.r[1] = cmd->devid;
    regs.r[2] = cmd->driverhandle;
    calldriver(cmd->devid, DRV_CANCEL_OP, &regs);
}

static _kernel_oserror *abort_op_timeout(_kernel_swi_regs *r,void *pw,void *handle)
{
    (void)r;
    (void)pw;
    abort_op((Cmd *)handle, CTL_DOINGTIMEOUT);
    return NULL;
}

static _kernel_oserror *scsi_abort_op(Bus *bus, Device *dev, _kernel_swi_regs *r)
{
    ADDRESS_DRIVER
    _kernel_oserror *e = check_access(dev, r); if (e) return e;
    Cmd *cmd = find_command(driver, r->r[2]); if (!cmd) return NULL;
    abort_op(cmd, CTL_DOINGABORTOP);
    return NULL;
}

static _kernel_oserror *scsi_set_timeout(Device *dev, _kernel_swi_regs *r)
{
    _kernel_oserror *e = check_access(dev, r); if (e) return e;
    uint32_t old = dev->control_timeout;
    dev->control_timeout = r->r[2];
    r->r[2] = old;
    return NULL;
}

static _kernel_oserror *scsi_control_errors(Device *dev, _kernel_swi_regs *r)
{
    uint32_t oldbits = dev->control_bits, bits;
    unsigned mode = r->r[2];
    if (mode != -1)
    {
        _kernel_oserror *e = check_access(dev, r); if (e) return e;
        if (mode > 2) return module_error(SCSI_RCunkn);
        bits = oldbits &~ (CTL_INHIBITREQUESTSENSE|CTL_REPORTUNITATTENTION);
        if (mode < 1) bits |= CTL_INHIBITREQUESTSENSE|CTL_REPORTUNITATTENTION;
        if (mode == 1) bits |= CTL_REPORTUNITATTENTION;
        dev->control_bits = bits;
    }
    mode = 2;
    if (oldbits & CTL_REPORTUNITATTENTION) mode = 1;
    if (oldbits & CTL_INHIBITREQUESTSENSE) mode = 0;
    r->r[2] = mode;

    return NULL;
}

static _kernel_oserror *scsi_control_queue(Device *dev, _kernel_swi_regs *r)
{
    uint32_t oldbits = dev->control_bits, bits;
    unsigned mode = r->r[2];
    if (mode != -1)
    {
        _kernel_oserror *e = check_access(dev, r); if (e) return e;
        if (mode > 3) return module_error(SCSI_RCunkn);
        bits = oldbits &~ (CTL_REJECTQUEUEFULL|CTL_REJECTDEVICEBUSY|CTL_REJECTDRIVERBUSY);
        if (mode >= 1) bits |= CTL_REJECTQUEUEFULL;
        if (mode > 1)  bits |= CTL_REJECTDEVICEBUSY;
        if (mode >= 3) bits |= CTL_REJECTDRIVERBUSY;
        dev->control_bits = bits;
    }
    mode = 0;
    if (oldbits & CTL_REJECTQUEUEFULL)  mode = 1;
    if (oldbits & CTL_REJECTDEVICEBUSY) mode = 2;
    if (oldbits & CTL_REJECTDRIVERBUSY) mode = 3;
    r->r[2] = mode;

    return NULL;
}

_kernel_oserror *scsi_control(_kernel_swi_regs *r)
{
    VALIDATE_ID(r->r[1])
    ADDRESS_DEVICE(r->r[1])

    switch (r->r[0])
    {
        //case 0: scsi_abort_device()
        case 1: return scsi_abort_op(bus, dev, r);
        case 3: return scsi_set_timeout(dev, r);
        case 4: return scsi_control_errors(dev, r);
        case 5: return scsi_control_queue(dev, r);
        //case 6: //scsi_control_disconnects(
        default: return module_error(SCSI_RCunkn);
    }
}

static _kernel_oserror *test_driver_busy(Driver *driver)
{
    if (driver->cmd_map == CMDBITS)
        return NULL;
    else
        return module_error(SCSI_QueueNotEmpty);
}

static _kernel_oserror *test_device_busy(Device *dev)
{
    if (dev->pending_cnt == 0)
        return NULL;
    else
        return module_error(SCSI_NotIdle);
}

static _kernel_oserror *test_queue_full(Driver *driver)
{
    if (driver->cmd_map != 0)
        return NULL;
    else
        return module_error(SCSI_QueueFull);
}

static Cmd *allocate_cmd_slot(Driver *driver, Device *dev)
{
    if (driver->cmd_map == 0)
        return NULL;

// There seems to be at least one slot free, so disable interrupts whilst
// trying to claim it.
    int irqsoff = _kernel_irqs_disabled();
    if (!irqsoff) _kernel_irqs_off();

    if (driver->cmd_map == 0)
    {
        if (!irqsoff) _kernel_irqs_on();
        return NULL;
    }

    Cmd *cmd = &driver->cmd[0];
    uint32_t bit;

    for (bit = 1; !(driver->cmd_map & bit); bit <<= 1, cmd++)
        ;

    driver->cmd_map &=~ bit;

    cmd->next = 0;
    dev->pending_cnt++;
    cmd->op_id = operation_id++;

    if (!irqsoff) _kernel_irqs_on();
    return cmd;
}

static void deallocate_cmd_slot(Driver *driver, Device *dev, Cmd *cmd)
{
    int n = cmd - driver->cmd;

    int irqsoff = _kernel_irqs_disabled();
    if (!irqsoff) _kernel_irqs_off();

    driver->cmd_map |= 1u << n;

    dev->pending_cnt--;

    if (!irqsoff) _kernel_irqs_on();
    return;
}

static void queue_cmd_slot(Driver *driver, Cmd *cmd)
{
    int irqsoff = _kernel_irqs_disabled();
    if (!irqsoff) _kernel_irqs_off();
    Cmd **prevptr = &driver->first_cmd;
    for (Cmd *p = *prevptr; p; prevptr = &p->next, p = *prevptr)
        ;
    *prevptr = cmd;
    if (!irqsoff) _kernel_irqs_on();
}

static void unqueue_cmd_slot(Driver *driver, Cmd *cmd)
{
    int irqsoff = _kernel_irqs_disabled();
    if (!irqsoff) _kernel_irqs_off();
    Cmd **prevptr = &driver->first_cmd;
    Cmd *p;
    for (p = *prevptr; p != cmd; prevptr = &p->next, p = *prevptr)
        ;
    if(p) *prevptr = p->next;
    if (!irqsoff) _kernel_irqs_on();
}

static Cmd *next_command(Driver *driver)
{
    for (Cmd *cmd = driver->first_cmd; cmd; cmd=cmd->next)
    {
        dprintf("considering command %p (status=%d)\n", (void*)cmd, cmd->status);
        if (cmd->status == INITIALISING) // if a command is initialising
            return NULL;                 // don't interrupt it
        //if (cmd->status == INITIALISED)
        //   return cmd;
        if (cmd->status == WAITING)
        {
            Bus *bus; Device *dev;
            address_device(cmd->devid, &bus, &dev);
            dprintf("device status = %d\n", dev->stat);
            if (dev->stat == IDLE)
                return cmd;
        }
    }
    return NULL;
}

static bool process_result(_kernel_oserror *error, Device *dev, Cmd *cmd,
                           const _kernel_swi_regs *rin, _kernel_swi_regs *rout)
{
    if (cmd->flags & CTL_DOINGREQUESTSENSE)
    {
        // completed an automatic request sense
        uint32_t flags = dev->sense_blk[0];
        unsigned errorclass = flags & 0x7F;
        uint32_t lba = (dev->sense_blk[1] << 8) | (dev->sense_blk[0] >> 24);
        flags = revbytes(flags);
        lba = revbytes(lba);
        if (error != NULL || (rin->r[0] & TARGET_Mask) != TARGET_GOOD)
        {
            lba = flags = 0;
            error = module_error(SCSI_CC_UnKn);
        }
        else if (errorclass < 0x70)
        {
            lba = flags & 0x001FFFFF;
            flags &=~ 0x001FFFFF;
            error = module_error(SCSI_CC_UnKn);
        }
        else if (errorclass == 0x70)
        {
            errorclass = 0xC0 + ((flags >> 8) & 0x0F);
            if (errorclass == SCSI_CC_UnitAttention &&
                !(cmd->flags & CTL_REPORTUNITATTENTION))
            {
                cmd->flags &=~ CTL_DOINGREQUESTSENSE;
                cmd->flags |= CTL_REPORTUNITATTENTION;
                cmd->status = WAITING;
                return true;
            }
            error = module_error(errorclass);
        }
        else // errorclass > 0x70
        {
            error = module_error(SCSI_CC_UnKn);
        }
        rout->r[0] = (int) error;
        rout->r[1] = (error->errnum << 24) | (flags >> 8);
        rout->r[2] = lba;
    }
    else
    {
        cmd->rt_r3 = (void *) rin->r[3];
        cmd->rt_r4 = rin->r[4];

        // do retry handling here

        if (!error)
        {
            int status = rin->r[0] & TARGET_Mask;
            if (status == TARGET_GOOD)
            {
                rout->r[0] = 0;
            }
            else if (status == TARGET_CHECK_CONDITION)
            {
                if (!(cmd->flags & CTL_INHIBITREQUESTSENSE))
                {
                    cmd->flags |= CTL_DOINGREQUESTSENSE;
                    cmd->status = WAITING;
                    return true;
                }
                rout->r[0] = (int) module_error(SCSI_CheckCondition);
            }
            else if (status == TARGET_BUSY)
                rout->r[0] = (int) module_error(SCSI_Busy);
            else
                rout->r[0] = (int) module_error(SCSI_StatusUnkn);
        }
        else
            rout->r[0] = (int) error;
    }

    if (!(cmd->flags & CTL_BACKGROUND) || cmd->callbackadr)
    {
        uint32_t nottx = rout->r[4] = cmd->rt_r4;
        uint32_t tx = cmd->xferlen - nottx;
        if (cmd->flags & CTL_SCATTER)
        {
            Scatter *scat = cmd->xferptr;
            do
            {
                uint32_t n = tx >= scat->len ? scat->len : tx;
                scat->ptr = (char *) scat->ptr + n;
                scat->len -= n;
                tx -= n;
                if (scat->len == 0) scat++;
            } while (tx);
            rout->r[3] = (int) scat;
        }
        else
        {
            rout->r[3] = (int) cmd->xferptr + tx;
        }
    }

    return false;
}

/* Handle the callback from the hardware driver */
static _kernel_oserror *driver_callback(_kernel_oserror *error, const _kernel_swi_regs *r)
{
    Cmd *cmd = (Cmd *) r->r[5];
    ADDRESS_DEVICE(cmd->devid)
    ADDRESS_DRIVER

    dprintf("Received callback(cmd=%p, ", (void*)cmd);
    if (error) dprintf("error=(%X,%s), ", error->errnum, error->errmess);
    dprintf("\n                  r0=%08X, r4=%08X)\n", r->r[0], r->r[4]);

    _kernel_swi_regs regs = { 0 };

    cmd->status = IDLE;

    if(cmd->timeout && (cmd->flags & CTL_BACKGROUND))
    {
        callx_remove_callafter(abort_op_timeout,cmd);
    }

    if (process_result(error, dev, cmd, r, &regs))
    {
        start_command(driver);
        return NULL;
    }

    if (cmd->callbackadr)
        asm_callcallback(cmd->callbackadr, cmd->callbackr12, &regs);

    unqueue_cmd_slot(driver, cmd);
    deallocate_cmd_slot(driver, dev, cmd);

    start_command(driver);
    return NULL;
}

_kernel_oserror *driver_callback_handler(_kernel_swi_regs *r,void *pw)
{
    (void) pw;
    return driver_callback(NULL, r);
}

_kernel_oserror *driver_error_handler(_kernel_swi_regs *r,void *pw)
{
    (void) pw;
    return driver_callback(module_error(r->r[0]), r);
}

static _kernel_oserror *calldriver_op(Cmd *cmd, Device *dev, Driver *driver,
                                      _kernel_swi_regs *regs, bool bg)
{
    int op = bg ? DRV_BG_OP : DRV_FG_OP;
    regs->r[0] = (cmd->flags & 0xFFFF0000) | (cmd->devid & 0xFFFF);
    if (cmd->flags & CTL_DOINGREQUESTSENSE)
    {
        regs->r[0] &=~ (CTL_TXWRITE|CTL_SCATTER);
        regs->r[0] |= CTL_TXREAD;
        regs->r[1] = sizeof CDB_REQ_SENSE;
        regs->r[2] = (int) CDB_REQ_SENSE;
        regs->r[3] = (int) dev->sense_blk;
        regs->r[4] = sizeof dev->sense_blk;
    }
    /*else if (cmd->flags & CTL_SPECIAL_OP)
    {
        op = (int) cmd->cdb;
    }*/
    else
    {
        regs->r[1] = cmd->cdblen;
        regs->r[2] = (int) cmd->cdb;
        regs->r[3] = (int) cmd->xferptr;
        regs->r[4] = cmd->xferlen;
    }
    if ((driver->features & DF_SCATTER) && !(regs->r[0] & CTL_SCATTER))
    {
        dev->fake_scatter.ptr = (void *) regs->r[3];
        dev->fake_scatter.len = regs->r[4];
        regs->r[0] |= CTL_SCATTER;
        regs->r[3] = (int) &dev->fake_scatter;
    }

    if (bg)
    {
        regs->r[0] |= CTL_BACKGROUND;
        regs->r[5] = (int) cmd;
        regs->r[6] = (int) asm_driver_callback;
        regs->r[7] = (int) module_wsp;
    }
    else
    {
        regs->r[0] &=~ CTL_BACKGROUND;
        regs->r[5] = cmd->timeout;
    }

    return calldriver(cmd->devid, op, regs);
}

void start_command(Driver *driver)
{
    int old_irqs = _kernel_irqs_disabled();
    if (!old_irqs) _kernel_irqs_off();

    Cmd *cmd = next_command(driver);

    if (cmd)
    {
        ADDRESS_DEVICE_NOERR(cmd->devid)
        dev->cmd = cmd;
        cmd->status = INITIALISING;

        dprintf("Command %p ready\n", (void*)cmd);

        _kernel_swi_regs regs;
        _kernel_oserror *e;

        e = calldriver_op(cmd, dev, driver, &regs, true);

        if (e)
        {
            if (e->errnum == SCSI_ErrorBase + SCSI_QueueFull)
                cmd->status = WAITING;
            else
            {
                /* immediate error response */
                driver_error_handler(&regs,NULL);
            }
        }
        else if (regs.r[0] == -1)
        {
            cmd->status = RUNNING;
            cmd->driverhandle = regs.r[1];
            if(cmd->timeout && (cmd->flags & CTL_BACKGROUND))
            {
                /* Set up a callafter to trigger the timeout error */
                callx_add_callafter(cmd->timeout,abort_op_timeout,cmd);
            }
        }
        else
            driver_callback_handler(&regs,NULL);
    }

    if (!old_irqs) _kernel_irqs_on();
}

static _kernel_oserror *do_foreground_cmd(Driver *driver, Device *dev, Cmd *cmd,
                                   _kernel_swi_regs *r)
{
    dev->cmd = cmd;
    cmd->status = RUNNING;

    _kernel_swi_regs regs;
    _kernel_oserror *e;

    do
    {
        e = calldriver_op(cmd, dev, driver, &regs, false);
    }
    while (process_result(e, dev, cmd, &regs, &regs));

    /* take care with output registers */
    if (e)
    {
        r->r[1] = regs.r[1];
        r->r[2] = regs.r[2];
    }
    r->r[3] = regs.r[3];
    r->r[4] = regs.r[4];

    return e;
}

_kernel_oserror *scsi_op_internal(Device *dev, Driver *driver,
                                  uint32_t flags, uint32_t devid,
                                  _kernel_swi_regs *r)
{
    _kernel_oserror *e;
    int old_irqs = _kernel_irqs_disabled();

#ifdef DEBUGLIB               
    dprintf("scsi_op_internal(dev=%p, driver=%p, flags=%08X, devid=%02X,\n"
           "                 r1=%08X, r2=%08X, r3=%08X, r4=%08X,\n"
           "                 r5=%08X, r6=%08X, r7=%08X)\n",
           (void*)dev, (void*)driver, flags, devid, r->r[1], r->r[2], r->r[3], r->r[4],
           r->r[5], r->r[6], r->r[7]);
    dprintf("CBD= %02x %02x %02x %02x %02x %02x",
             *(char*)(r->r[2]),*(char*)(r->r[2]+1),*(char*)(r->r[2]+2), 
             *(char*)(r->r[2]+3),*(char*)(r->r[2]+4),*(char*)(r->r[2]+5));
    if(r->r[1]>6)
    {
    dprintf(" %02x %02x %02x %02x",
             *(char*)(r->r[2]+6),*(char*)(r->r[2]+7),
             *(char*)(r->r[2]+8),*(char*)(r->r[2]+9)); 
    
      if(r->r[1]>10)
      {
    dprintf(" %02x %02x",
             *(char*)(r->r[2]+10),*(char*)(r->r[2]+11)); 
      }

    }
    dprintf("\n");
#endif
    if (old_irqs) _kernel_irqs_on();

    if ((flags & CTL_SCATTER) && !(driver->features & DF_SCATTER))
        return module_error(SCSI_ParmError);

    if ((flags & CTL_BACKGROUND) && !(driver->features & DF_BACKGROUND))
        return module_error(SCSI_ParmError);

    if (flags & CTL_REJECTDRIVERBUSY)
    {   e = test_driver_busy(driver); if (e) goto out; }
    if (flags & CTL_REJECTDEVICEBUSY)
    {   e = test_device_busy(dev); if (e) goto out; }
    if (flags & CTL_REJECTQUEUEFULL)
    {   e = test_queue_full(driver); if (e) goto out; }

    Cmd *cmd;

    dprintf("allocating cmd slot\n");

    do
        cmd = allocate_cmd_slot(driver, dev);
    while (!cmd);

  {
    uint32_t xferlen = r->r[4];
    if (!(flags & (CTL_TXREAD|CTL_TXWRITE))) xferlen = 0;
    if (xferlen == 0) flags &=~ (CTL_TXREAD|CTL_TXWRITE);

    uint32_t timeout = r->r[5];
    if (timeout == 0) timeout = dev->control_timeout;

    cmd->devid = devid;
    cmd->flags = flags;
    memcpy(cmd->cdb, (void *) r->r[2], cmd->cdblen = r->r[1]);
    cmd->xferptr = (void *) r->r[3];
    cmd->xferlen = xferlen;
    cmd->timeout = timeout;
    cmd->callbackadr = (void (*)(void)) r->r[6];
    cmd->callbackr12 = (void *) r->r[7];
    cmd->status = WAITING;
  }


    if (!(driver->features & DF_BACKGROUND))
    {
        e = do_foreground_cmd(driver, dev, cmd, r);
        deallocate_cmd_slot(driver, dev, cmd);
    }
    else
    {
        CallBkRec callbackrecord;
        if (flags & CTL_BACKGROUND)
            r->r[0] = cmd->op_id;
        else
        {
            cmd->callbackadr = asm_callbackhandler;
            cmd->callbackr12 = &callbackrecord;
            callbackrecord.stat = RUNNING;
        }

        dprintf("queuing cmd slot\n");
        queue_cmd_slot(driver, cmd);

        dprintf("starting command\n");
        start_command(driver);

        e = NULL;
        if (!(flags & CTL_BACKGROUND))
        {
            dprintf("waiting for completion\n");
            uint32_t starttime;
            _swix(OS_ReadMonotonicTime,_OUT(0),&starttime);
            do
            {
                /* Let the CPU sleep for a while */
                _swix(Portable_Idle,0);
                /* Ensure any pending IRQs have triggered (don't trust the portable module to do this for us) */
                if(irqtrigger)
                  irqtrigger();
                /* Now check for any termination conditions */
                _kernel_irqs_off();
                if(callbackrecord.stat == RUNNING)
                {
                    if (!(flags & (CTL_NOESCAPE|CTL_DOINGESCAPE|CTL_DOINGTIMEOUT)))
                    {
                        int psr = 0;
                        _swix(OS_ReadEscapeState, _OUT(_FLAGS), &psr);
                        if (psr & _C)
                        {
                            abort_op(cmd, CTL_DOINGESCAPE);
                            flags |= CTL_DOINGESCAPE;
                        }
                    }
                    if (!(flags & (CTL_DOINGESCAPE|CTL_DOINGTIMEOUT)) && cmd->timeout)
                    {
                        uint32_t current;
                        _swix(OS_ReadMonotonicTime,_OUT(0),&current);
                        if(current-starttime >= cmd->timeout)
                        {
                            abort_op(cmd, CTL_DOINGTIMEOUT);
                            flags |= CTL_DOINGTIMEOUT;
                        }
                    }
                }
                _kernel_irqs_on();
            } while (callbackrecord.stat == RUNNING);
            r->r[3] = callbackrecord.r[3];
            r->r[4] = callbackrecord.r[4];
            if (callbackrecord.stat == ERROR)
            {
                e = (_kernel_oserror *) (r->r[0] = callbackrecord.r[0]);
                r->r[1] = callbackrecord.r[1];
                r->r[2] = callbackrecord.r[2];
            }
        }

    }
  out:
    dprintf("scsi_op_internal finished\n");
    if (old_irqs) _kernel_irqs_off();
    return e;
}

_kernel_oserror *scsi_op(_kernel_swi_regs *r)
{
    VALIDATE_ID(r->r[0] & 0xFFFFFF)
    ADDRESS_DEVICE(r->r[0] & 0xFFFFFF)
    ADDRESS_DRIVER

    e = check_access(dev, r);
    if (e) return e;

    if (r->r[1] < 3 || r->r[1] > CDBMAXLEN)
        return module_error(SCSI_ParmError);

    uint32_t flags = (r->r[0] & 0xFF000000) | dev->control_bits;

    return scsi_op_internal(dev, driver, flags, r->r[0] & 0xFFFFFF,
                            r);
}

static _kernel_oserror *scsi_status_check_device(Device *dev, _kernel_swi_regs *r)
{
    r->r[0] = dev->pending_cnt ? 2 : 1;
    return NULL;
}

_kernel_oserror *scsi_status(_kernel_swi_regs *r)
{
    VALIDATE_ID(r->r[1])
    ADDRESS_DEVICE(r->r[1])

    switch (r->r[0])
    {
        case 0: return scsi_status_check_device(dev, r);
        default: return module_error(SCSI_RCunkn);
    }
}

static _kernel_oserror *claim_device(Device *dev, _kernel_swi_regs *r)
{
    _kernel_oserror *e = check_access(dev, r);
    if (!e)
    {
        dev->releasecalladr = (void (*)(void)) r->r[2];
        dev->releasecallr12 = (void *) r->r[3];
        dev->accesskey = r->r[8];
    }
    return e;
}

static _kernel_oserror *force_claim_device(Device *dev, _kernel_swi_regs *r)
{
    if (dev->accesskey == 0 || dev->releasecalladr == 0)
        return claim_device(dev, r);

    _kernel_oserror *e = asm_callrelease(dev->releasecalladr, dev->releasecallr12, r);

    if (e) return e;

    return claim_device(dev, r);
}

static _kernel_oserror *free_device(Device *dev, _kernel_swi_regs *r)
{
    _kernel_oserror *e = check_access(dev, r);
    if (!e)
    {
        dev->releasecalladr = 0;
        dev->releasecallr12 = 0;
        dev->accesskey = 0;
    }
    return e;
}

_kernel_oserror *scsi_reserve(_kernel_swi_regs *r)
{
    VALIDATE_ID(r->r[1])
    ADDRESS_DEVICE(r->r[1])

    switch (r->r[0])
    {
        case 0: return claim_device(dev, r);
        case 1: return force_claim_device(dev, r);
        case 2: return free_device(dev, r);
        default: return module_error(SCSI_RCunkn);
    }
}

_kernel_oserror *scsi_register(_kernel_swi_regs *r)
{
    uint32_t flags = r->r[0];
    int b, d;
    Driver *driver = malloc(sizeof(Driver));

    if (!driver) goto nomem1;
    driver->handler = (void(*)(void)) r->r[1];
    driver->handlerr12 = (void *) r->r[2];
    driver->handlerr8 = (void *) r->r[3];
    driver->cmd_map = CMDBITS;
    driver->first_cmd = NULL;
    memset(driver->cmd, 0, sizeof driver->cmd);

    if (flags & 1)
    {   /* Bus */
        int devs = ((flags >> 8) & 0xFF)+1;
        if (devs > DEVCOUNT) devs = DEVCOUNT;
        b = find_free_bus();
        if (b < 0) goto nomem2;
        bustable[b] = malloc(sizeof(Bus) + devs*sizeof(Device));
        if (!bustable[b]) goto nomem2;
        bustable[b]->devices = devs;
        bustable[b]->driver = driver;
        bustable[b]->hostid = devs-1;
        memset(bustable[b]->dev, 0, devs*sizeof(Device));
        d = 0;
        dprintf("Registered bus %d\n", b);
    }
    else
    {   /* Device */
        dprintf("Trying to find slot for device\n");

        for (b = 0, d = -1; b < BUSCOUNT; b++)
            if ((d = find_free_device_on_bus(b)) >= 0)
                break;

        if (d < 0)
        {
            b = find_free_bus();
            if (b < 0) goto nomem2;

            bustable[b] = malloc(sizeof(Bus) + DEVCOUNT*sizeof(Device));
            if (!bustable[b]) goto nomem2;
            bustable[b]->devices = DEVCOUNT;
            bustable[b]->driver = NULL;
            bustable[b]->hostid = -1;
            memset(bustable[b]->dev, 0, DEVCOUNT*sizeof(Device));
            d = 0;
        }

        bustable[b]->dev[d].driver = driver;
        dprintf("Registered bus %d device %d\n", b, d);
    }

    r->r[0] = DEVID(b,d,0);

    _kernel_swi_regs regs;
    if (calldriver(r->r[0], DRV_FEATURES, &regs))
        driver->features = DF_SCATTER|DF_BACKGROUND;
    else
        driver->features = regs.r[1];

    _swix(OS_ServiceCall, _INR(0,2), r->r[0], Service_SCSIAttached,
                      flags & 1 ? DEVID(BUSCOUNT-1,0,0) :
                                  DEVID(BUSCOUNT-1,DEVCOUNT-1,0));

    return NULL;

  nomem2:
    free(driver);
  nomem1:
    return module_error(SCSI_NotEstablished);
}

_kernel_oserror *scsi_deregister(_kernel_swi_regs *r)
{
    ADDRESS_DEVICE(r->r[0])
    ADDRESS_DRIVER

    /* Should arrange for people with reservations to be thrown off */

    if (driver->handler != (void(*)(void)) r->r[1] ||
        driver->handlerr12 != (void *) r->r[2] ||
        driver->handlerr8 != (void *) r->r[3])
        return module_error(SCSI_NotEstablished);

    _swix(OS_ServiceCall, _INR(0,2), r->r[0], Service_SCSIDetached,
                    bus->driver != NULL ? DEVID(BUSCOUNT-1,0,0) :
                                          DEVID(BUSCOUNT-1,DEVCOUNT-1,0));

    if (bus->driver)
    {
        bustable[BUS(r->r[0])] = NULL;
        free(bus);
    }
    else
        dev->driver = NULL;

    free(driver);

    return NULL;
}

void scsi_deregister_all(void)
{
    for (int b = 0; b < BUSCOUNT; b++)
    {
        Bus *bus = bustable[b];
        if (!bus) continue;
        bustable[b] = NULL;

        for (int d = 0; d < bus->devices; d++)
            free(bus->dev[d].driver);

        free(bus->driver);
        free(bus);
    }
}

_kernel_oserror *calldriver(int id, int reason, _kernel_swi_regs *r)
{
    ADDRESS_DEVICE(id)
    ADDRESS_DRIVER

    if (!driver) return module_error(SCSI_NoDevice);

    dprintf("calldriver(driver=%p, reason=%d,\n"
            "           r0=%08X, r1=%08X, r2=%08X, r3=%08X,\n"
            "           r4=%08X, r5=%08X, r6=%08X, r7=%08X,\n"
            "           r8=%08X, r12=%08X, pc=%08X)\n",
            (void*)driver, reason, r->r[0], r->r[1], r->r[2], r->r[3],
            r->r[4], r->r[5], r->r[6], r->r[7],
            (uint32_t) driver->handlerr8, (uint32_t) driver->handlerr12,
            (uint32_t) driver->handler);

    return asm_calldriver(driver->handler,
                          driver->handlerr12, driver->handlerr8,
                          reason,
                          r);
}
