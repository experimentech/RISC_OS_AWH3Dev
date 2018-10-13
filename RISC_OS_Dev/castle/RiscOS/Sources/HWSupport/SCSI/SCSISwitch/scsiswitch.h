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
#ifndef scsiswitch_H
#define scsiswitch_H

#include <stdint.h>
#include <stdbool.h>

#define Service_SCSIStarting 0x20100
#define Service_SCSIDying    0x20101
#define Service_SCSIAttached 0x20102
#define Service_SCSIDetached 0x20103

#define BUSCOUNT 4     /* Maximum number of buses */
#define DEVCOUNT 8     /* Maximum number of devices per bus */
#define CMDCOUNT 16    /* Commands queued per driver */
#define CMDBITS  0xFFFF
#define CDBMAXLEN 16   /* Maximum CDB length */

#define TARGET_Mask               0x9E
#define TARGET_GOOD               0x00
#define TARGET_CHECK_CONDITION    0x02
#define TARGET_BUSY               0x08

/* Array literal constants defining well-known SCSI commands */
#define CDB_TEST_READY   ((const uint8_t[6])  { 0x00 })
#define CDB_REQ_SENSE    ((const uint8_t[6])  { 0x03, 0, 0, 0, 8, 0 })
#define CDB_INQUIRY_NOTX ((const uint8_t[6])  { 0x12, 0, 0, 0, 0, 0 })
#define CDB_INQUIRY_LEN  5
#define CDB_INQUIRY      ((const uint8_t[6])  { 0x12, 0, 0, 0, CDB_INQUIRY_LEN, 0 })
#define CDB_INQUIRY_L_LEN 36
#define CDB_INQUIRY_L    ((const uint8_t[6])  { 0x12, 0, 0, 0, CDB_INQUIRY_L_LEN, 0 })
#define CDB_RESERVE      ((const uint8_t[6])  { 0x16 })
#define CDB_RELEASE      ((const uint8_t[6])  { 0x17 })
#define CDB_CAPACITY     ((const uint8_t[10]) { 0x25 })

/* Operation flags passed into SCSI_Op */
#define CTL_TXNONE               (0u<<24)
#define CTL_TXREAD               (1u<<24)
#define CTL_TXWRITE              (2u<<24)
#define CTL_TXRESERVED           (3u<<24)
#define CTL_SCATTER              (1u<<26)
#define CTL_NOESCAPE             (1u<<27)
#define CTL_RETRYONTIMEOUT       (1u<<28)
#define CTL_BACKGROUND           (1u<<29)
/* Flags set (per device) with SCSI_Control, noted when SCSI_Op called */
#define CTL_INHIBITREQUESTSENSE  (1u<<23)
#define CTL_REPORTUNITATTENTION  (1u<<22)
#define CTL_INHIBITDISCONNECTION (1u<<21)
#define CTL_INHIBITIDENTIFY      (1u<<20)
#define CTL_DOINGREQUESTSENSE    (1u<<19)
#define CTL_REJECTQUEUEFULL      (1u<<18)
#define CTL_REJECTDEVICEBUSY     (1u<<17)
#define CTL_REJECTDRIVERBUSY     (1u<<16)
/* Flags passed down to "cancel operation" */
#define CTL_DOINGABORTOP         (1u<<13)
#define CTL_DOINGESCAPE          (1u<<12)
#define CTL_DOINGTIMEOUT         (1u<<11)

/* Magic access key to bypass SCSI_Reservation (CARE!!) */
#define MAGIC_ACCESS_KEY         0xfc000003

/* Reason codes for driver calls */
#define DRV_FEATURES             0
#define DRV_RESET_BUS            1
#define DRV_FG_OP                4
#define DRV_BG_OP                5
#define DRV_CANCEL_OP            6
#define DRV_HOST_DESC            7

/* Driver features flags */
#define DF_SCATTER               (1u<<5)
#define DF_BACKGROUND            (1u<<1)

#define DEVID(b,d,l) (((b)<<3)+(d)+((l)<<5))
#define LUN(i) (((i) >> 5) & 7)
#define BUS(i) (((i) >> 3) & 3)
#define DEV(i) ((i) & 7)

#define ADDRESS_BUS(i) \
    Bus *bus = bustable[BUS(i)]; \
    if (!bus) return module_error(SCSI_BadDevID);

#define VALIDATE_ID(i) \
    { \
        _kernel_oserror *e = validate_id(i); \
        if (e) return e; \
    }

#define ADDRESS_DEVICE(i) \
    Bus *bus; Device *dev; \
    _kernel_oserror *e = address_device(i, &bus, &dev); \
    if (e) return e;

#define ADDRESS_DEVICE_NOERR(i) \
    Bus *bus; Device *dev; \
    address_device(i, &bus, &dev);

#define ADDRESS_DEVICE_FROM_BUS(bus, i) \
    int d = DEV(i); \
    Device *dev; \
    if (d >= bus->devices) return module_error(SCSI_BadDevID); \
    dev = &bus->dev[d];

#define ADDRESS_BUS_DRIVER \
    Driver *driver = bus->driver; \
    if (!driver) return module_error(SCSI_NoDevice);

#define ADDRESS_DRIVER \
    Driver *driver; \
    if (bus->driver) \
        driver = bus->driver; \
    else \
        driver = dev->driver; \
    if (!driver) return module_error(SCSI_NoDevice);

typedef struct DevId
{
    int dev:3;
    int bus:2;
    int lun:3;
} DevId;

// Keep in sync with assembler
typedef enum CmdStat
{
    IDLE    = 0x00,       // not yet queued, or completed successfully
    RUNNING = 0x04,       // has been issued to driver
    WAITING = 0x10,       // queued, has not been issued to driver
    INITIALISING = 0x20,  // in the process of issuing to driver
    ERROR   = 0x80        // completed with error
} CmdStat;

typedef struct Scatter
{
    void *ptr;
    uint32_t len;
} Scatter;

typedef struct Cmd
{
    struct Cmd *next;
    /* SCSI_Op parameters */
    uint32_t flags;         /* flags from R0, SCSI_Control etc */
    uint32_t devid;         /* device ID from R0 */
    uint32_t cdblen;
    /* Copy of CDB */
    uint8_t  cdb[16];
    void    *xferptr;
    uint32_t xferlen;
    uint32_t timeout;
    void    (*callbackadr)(void);
    void    *callbackr12;
    CmdStat  status;
    /* Dummy scatter list */
 //   Scatter  scatter;
    int      op_id;
    uint32_t driverhandle;
    /* Return values */
    void    *rt_r3;
    uint32_t rt_r4;
    /* Padding to make sizeof Cmd = 64 */
    //char padding[4];
} Cmd;

typedef struct Driver
{
    void   (*handler)(void);
    void    *handlerr12;
    void    *handlerr8;
   // bool     bus:1;
    uint32_t features;
    uint32_t cmd_map;
    Cmd     *first_cmd;
    Cmd      cmd[CMDCOUNT];
} Driver;

typedef struct Device
{
    Driver *driver;
    uint32_t control_bits;
    uint32_t control_timeout;
    void   (*releasecalladr)(void);
    void   *releasecallr12;
    uint32_t accesskey;
    uint32_t sense_blk[2];
    Scatter  fake_scatter;
    Cmd     *cmd;
    int      pending_cnt;
    int      stat;
} Device;

typedef struct Bus
{
    int     devices;
    int     hostid;
    Driver *driver;
    Device  dev[];
} Bus;

#define SCSI_ErrorBase 0x20100
enum
{
   SCSI_NoRoom = 0x00,
   SCSI_SWIunkn,
   SCSI_RCunkn,
   SCSI_BadReset,
   SCSI_BadHostID,
   SCSI_BadDevID,
   SCSI_NoDevice,
   SCSI_Established,
   SCSI_NotEstablished,
   SCSI_NotIdle,
   SCSI_Timeout,
   SCSI_Timeout2,
   SCSI_QueueNotEmpty,
   SCSI_QueueFull,
   SCSI_DevReserved,
   SCSI_InvalidParms,
   SCSI_ParmError,
   SCSI_NotFromIRQ,
   SCSI_AbortOp,
   SCSI_Died,
   SCSI_WrongMEMC,

   SCSI_CheckCondition = 0x80,
   SCSI_Busy,
   SCSI_StatusUnkn,

   SCSI_CC_NoSense = 0xC0,
   SCSI_RecoveredError,
   SCSI_CC_NotReady,
   SCSI_CC_MediumError,
   SCSI_CC_HardwareError,
   SCSI_CC_IllegalRequest,
   SCSI_CC_UnitAttention,
   SCSI_CC_DataProtect,
   SCSI_CC_BlankCheck,
   SCSI_CC_VendorUnique,
   SCSI_CC_CopyAborted,
   SCSI_CC_AbortedCommand,
   SCSI_CC_Equal,
   SCSI_CC_VolumeOverflow,
   SCSI_CC_Miscompare,
   SCSI_CC_Reserved,
   SCSI_CC_UnKn,
};

typedef _kernel_oserror *swient(_kernel_swi_regs *);

swient scsi_version, scsi_initialise, scsi_control,
       scsi_op, scsi_status, scsi_reserve,
       scsi_register, scsi_deregister;

void scsi_deregister_all(void);

_kernel_oserror *scsi_devices(void);

#endif
