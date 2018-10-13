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
#if !defined(SCSISOFTUSB_GLUE_H) /* file used if not already included */
#define SCSISOFTUSB_GLUE_H
/*****************************************************************************
* $Id: glue,v 1.6 2012-06-03 14:25:59 jlee Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): 
*
* ----------------------------------------------------------------------------
* Purpose: Glue between RISC OS world and BSD code
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include <stdint.h>


/*****************************************************************************
* MACROS
*****************************************************************************/


/*****************************************************************************
* New type definitions
*****************************************************************************/


/*****************************************************************************
* Constants
*****************************************************************************/


/*****************************************************************************
* Global variables
*****************************************************************************/


/*****************************************************************************
* Function prototypes
*****************************************************************************/

/*****************************************************************************
* glue_AttachDevice
*
* Makes a mass storage USB interface ready for use.
*
* Assumptions
*  NONE
*
* Inputs
*  device: struct describing the interface to attach
*
* Outputs
*  maxlun: maximum USB logical unit number of device
*
* Returns
*  true if attached succesfully
*****************************************************************************/
extern bool glue_AttachDevice(my_usb_device_t *device, uint8_t *maxlun);

/*****************************************************************************
* glue_DetachDevice
*
* Closes down a mass storage USB interface.
*
* Assumptions
*  device is already delinked (so the stream closed service call won't re-open it)
*
* Inputs
*  device: struct describing the interface to detach
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
extern void glue_DetachDevice(my_usb_device_t *device);

/* extern void glue_ResetBus(my_usb_device_t *device); */

/*****************************************************************************
* glue_ResetDevice
*
* Initiates a reset of a mass storage USB interface.
* Callback is called for any active command.
* Might someday return before the reset is complete.
*
* Assumptions
*  NONE
*
* Inputs
*  device: struct describing the interface to reset
*  reason: 0 => timeout, 1 => escape, 2 => aborted
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
extern void glue_ResetDevice(my_usb_device_t *device, int reason);

/*****************************************************************************
* glue_DoCommand
*
* Initiates a SCSI command addressed to a mass storage USB interface.
* Can return before the command is complete.
*
* Assumptions
*  NONE
*
* Inputs
*  device:               struct describing the interface to address
*  lun:                  logical unit number (at the USB transport layer) to address
*  direction:            direction code in bits 24/25, as for SCSI_Op
*  control_block:        pointer to SCSI control block
*  control_block_length: length of SCSI control block
*  scatter_list:         pointer to scatter list describing data
*  transfer_length:      total amount of data to transfer
*  callback:             address of callback routine
*  callback_pw:          R5 (private word) for callback
*  callback_wp:          R12 (workspace pointer) for callback
*
* Outputs
*  NONE
*
* Returns
*  RISC OS error pointer (eg if previous command is still active) or NULL
*****************************************************************************/
extern _kernel_oserror *glue_DoCommand(my_usb_device_t *device, uint32_t lun, uint32_t data_direction, const char *control_block, size_t control_block_length, scatter_entry_t *scatter_list, size_t transfer_length, void (*callback)(void), void *callback_pw, void *callback_wp);

/*****************************************************************************
* glue_Tick
*
* Background processing entry point to handle a specific device.
*
* Assumptions
*  Interrupts are disabled
*
* Inputs
*  device: struct describing the interface to process
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
extern void glue_Tick(my_usb_device_t *device);

/*****************************************************************************
* glue_ReopenStream
*
* Try to cope with our streams having been closed
*
* Assumptions
*  NONE
*
* Inputs
*  file_handle: handle of stream which has been closed
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
extern void glue_ReopenStream(uint32_t file_handle);

/*****************************************************************************
* glue_BufferThresholdCheck
*
* Decide whether we should wake up glue_Tick
*
* Assumptions
*  NONE
*
* Inputs
*  buffer: Buffer handle that's sent a filling/emptying upcall
*  filling: True if it's a filling upcall, false if emptying
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
extern void glue_BufferThresholdCheck(uint32_t buffer,bool filling);

/*****************************************************************************
* RTSupportWrapper
*
* Wrapper function that sits between the RTSupport module and
* module_TickerVHandler
*
* Assumptions
*  NONE
*
* Inputs
*  NONE
*
* Outputs
*  NONE
*
* Returns
*  Time of next execution. May not return at all if the RTSupport callback is
*  no longer needed.
*****************************************************************************/
__value_in_regs rtsupport_routine_result RTSupportWrapper(void);


#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
