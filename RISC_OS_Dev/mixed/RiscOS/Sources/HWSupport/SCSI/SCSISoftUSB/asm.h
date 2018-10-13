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
#if !defined(SCSISOFTUSB_ASM_H) /* file used if not already included */
#define SCSISOFTUSB_ASM_H
/*****************************************************************************
* $Id: asm,v 1.5 2012-06-03 14:25:59 jlee Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): 
*
* ----------------------------------------------------------------------------
* Purpose: Assembler stubs
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include <stdlib.h>
#include <stdint.h>
#include "kernel.h"


/*****************************************************************************
* MACROS
*****************************************************************************/
#define INSERT_BLOCK(buffer_id, block, length) do { asm_CallBufferManager(1, buffer_id, block, length, static_BufManWS, static_BufManRout); } while(0)
#define REMOVE_BLOCK(buffer_id, block, length) do { asm_CallBufferManager(3, buffer_id, block, length, static_BufManWS, static_BufManRout); } while(0)
#define USED_SPACE(buffer_id) asm_CallBufferManager(6, buffer_id, 0, 0, static_BufManWS, static_BufManRout)
#define FREE_SPACE(buffer_id) asm_CallBufferManager(7, buffer_id, 0, 0, static_BufManWS, static_BufManRout)


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
* asm_DoTransferCompleteCallback
*
* Calls back to SCSIDriver when a transfer has finished.
*
* Assumptions
*  NONE
*
* Inputs
*  Various parameters required by the callback, and the address to call.
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
extern void asm_DoTransferCompleteCallback(_kernel_oserror *error, uint32_t status_byte, void (*callback)(void), size_t amount_not_transferred, void *priv, void *workspace);

/*****************************************************************************
* asm_CallBufferManager
*
* Wrapper to Buffer Manager direct-access routines. Use the above macros instead.
*
* Assumptions
*  NONE
*
* Inputs
*  Parameters to routine, and address of routine.
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
extern uint32_t asm_CallBufferManager(uint32_t reason, uint32_t buffer_id, void *block, size_t length, void *ws, void (*rout)(void));

/*****************************************************************************
* asm_UpCallHandler
*
* A transiently-installed routine to catch the registers in UpCall 10.
* Not designed to be called directly from C.
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
*  NOTHING
*****************************************************************************/
extern void asm_UpCallHandler(void);

/*****************************************************************************
* asm_RTSupportWrapper
*
* Wrapper for RTSupportWrapper, to get us out of SYS mode and into SVC mode
* (required so we can safely use the other asm calls)
*
* Assumptions
*  NONE
*
* Inputs
*  Pointer to relocation offsets
*
* Outputs
*  NONE
*
* Returns
*  Details of next call, from RTSupportWrapper
*****************************************************************************/
extern void asm_RTSupportWrapper(uint32_t *reloc);


#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
