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
#if !defined(SCSISOFTUSB_GLOBAL_H) /* file used if not already included */
#define SCSISOFTUSB_GLOBAL_H
/*****************************************************************************
* $Id: global,v 1.9 2014-08-12 18:56:57 jlee Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): 
*
* ----------------------------------------------------------------------------
* Purpose: Global variables
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include <stdbool.h>
#include <stdint.h>

#include "tboxlibs/toolbox.h"


/*****************************************************************************
* Scope limiting
* if LIMITED_SCOPE is defined, then the module will only recognise
*  a limited subset of devices instead of anything which responds
*****************************************************************************/
//#define LIMITED_SCOPE 1

/*****************************************************************************
* MACROS
*****************************************************************************/
#ifndef IGNORE
#define IGNORE(x) do { (void)(x); } while(0)
#endif

#ifndef MIN
#define MIN(x,y) ((x)<(y)?(x):(y))
#endif

#ifndef MAX
#define MAX(x,y) ((x)>(y)?(x):(y))
#endif

#ifndef RETURN_ERROR
#define RETURN_ERROR(error_returning_statement) \
  { \
    _kernel_oserror *returnerror_error = (error_returning_statement); \
    if (returnerror_error != NULL) \
    { \
      return returnerror_error; \
    } \
  }
#endif

#define RTSTACK_SIZE 2048

/*****************************************************************************
* New type definitions
*****************************************************************************/
typedef struct
{
  char *start;
  size_t length;
}
scatter_entry_t;

typedef struct
{
  uint32_t handle;              /* FileSwitch handle */
  uint32_t buffer;              /* BufferManager internal buffer ID */
  uint32_t buffer_handle;       /* Buffer handle, as used by the upcalls */
  uint32_t devicedriverstreamhandle;
  bool write;                   /* direction */
  struct my_usb_device *device; /* for getting back to device handle */
  uint16_t maxpacket;           /* max packet size */
}
pipe_block_t;

typedef struct my_usb_device
{
  uint32_t padding; /* to get from quad-word alignment to start of RMA block */
  
  struct my_usb_device *next;
  
  bool dying;
  bool registered;
  
  uint8_t interface;
  uint8_t alternate;
  uint8_t subclass;
  uint8_t protocol;
  uint8_t bulk_in_endpoint;
  uint8_t bulk_out_endpoint;
  uint8_t interrupt_endpoint;
  uint16_t bulk_in_maxpacketsize;
  uint16_t bulk_out_maxpacketsize;
  uint16_t interrupt_maxpacketsize;
  uint16_t vendor;
  uint16_t product;
  uint32_t block_size;
  
  uint8_t maxlun;
  
  char devicefs_name[20];
  
  uint32_t scsi_driver_handle;
  
  void *softc;
  
  uint32_t current_fill;  
  pipe_block_t *current_pipe;
  pipe_block_t pipe[3 /* == UMASS_NEP */];
  scatter_entry_t fake_list;         /* for making a scatter list when there wan't one */
  
  struct my_usb_device *next_ticker; /* list of devices to poll from TickerV */
  uint32_t status;                   /* actually the usbd_status value */
  bool command_active;               /* active at any phase */
  bool ticker_semaphore;             /* paranoid ticker re-entrancy semaphore */
  bool background_transfer_active;   /* active and at a phase involving a bulk pipe */
  bool is_capacity;                  /* True if we're processing a CAPACITY command */
  scatter_entry_t *orig_scatterlist; /* scatterlist pointer st start of background xfer */
  size_t orig_transferlength;        /* to-do count at start of background xfer */
  scatter_entry_t *curr_scatterlist; /* working scatterlist pointer */
  size_t curr_offset;                /* offset into first entry in working scatterlist */
  size_t curr_transferlength;        /* working to-do count */
  size_t curr_padding;               /* how many padding bytes there are in this transfer */
  
  void (*callback)(void);    /* callback to SCSIDriver */
  void *callback_pw;         /* private word (R5) for the above */
  void *callback_wp;         /* workspace pointer (R12) for the above */
  _kernel_oserror *callback_error;
  uint32_t callback_status_byte;
  size_t callback_not_transferred;
}
my_usb_device_t;

typedef struct
{
  uint32_t flags;
  uint32_t *pollword;
  uint32_t timeout;
} rtsupport_routine_result;

/*****************************************************************************
* Constants
*****************************************************************************/
enum
{
  data_NONE  = 0 << 24,  /* By happy coincidence, these are the same */
  data_READ  = 1 << 24,  /* as the symbols used for the same purpose */
  data_WRITE = 2 << 24   /* by the BSD code (except for the shift).  */
};

typedef enum
{
  callback_NONE,
  callback_TickerV,
  callback_RTSupport
} callback_type;


/*****************************************************************************
* Global variables
*****************************************************************************/
extern void *global_PrivateWord; /* so we don't have to worry about passing pw around */
extern MessagesFD global_MessageFD; /* message file descriptor */
extern my_usb_device_t *global_DeviceList; /* list of usb device info */
extern my_usb_device_t *global_TickerList; /* list of devices using TickerV/RTSupport */
extern bool global_UseRTSupport; /* Use RTSupport module for scheduling, not TickerV */
extern int global_RTSupportPollword; /* RTSupport pollword */
extern int global_RTSupportHandle; /* RTSupport handle */
extern callback_type global_CallbackType; /* Type of our registered callback, if any */
extern uint32_t global_PopUpDelay; /* Delay before SCSIFS gets told about new devices */ 
#ifdef UMASS_DEBUG
extern char *states[];
#endif
/*****************************************************************************
* Function prototypes
*****************************************************************************/


#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
