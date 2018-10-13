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
#if !defined(BAVISON_MESS_H) /* file used if not already included */
#define BAVISON_MESS_H
/*****************************************************************************
* $Id: mess,v 1.1.1.1 2003-02-21 20:29:11 bavison Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): Tungsten
*
* ----------------------------------------------------------------------------
* Purpose: Message lookup and error handling routines
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include <stdint.h>
#include "kernel.h"


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
* mess_GenerateError
*
* Builds an error block from a message file token
*
* Assumptions
*  global_MessageFD is valid
*
* Inputs
*  token:   pointer to token
*  errno:   error number
*  nparams: parameter count
*  ...:     between 0 and 4 (const char *) parameter pointers
*
* Outputs
*  NONE
*
* Returns
*  pointer to error block
*****************************************************************************/
extern _kernel_oserror *mess_GenerateError(const char *token, uint32_t errno, size_t nparams, ...);

/*****************************************************************************
* mess_MakeError
*
* Builds an error block, generating the message token from the error number
*
* Assumptions
*  global_MessageFD is valid
*
* Inputs
*  errno:   error number
*  nparams: parameter count
*  ...:     between 0 and 4 (const char *) parameter pointers
*
* Outputs
*  NONE
*
* Returns
*  pointer to error block
*****************************************************************************/
extern _kernel_oserror *mess_MakeError(uint32_t errno, size_t nparams, ...);

/*****************************************************************************
* mess_CacheError
*
* Copies an error block where it won't be trampled on by MessageTrans
*
* Assumptions
*  NONE
*
* Inputs
*  err_in: pointer to MessageTrans error block
*
* Outputs
*  NONE
*
* Returns
*  pointer to static error block
*****************************************************************************/
extern _kernel_oserror *mess_CacheError(const _kernel_oserror *err_in);

/*****************************************************************************
* mess_LookUp
*
* Looks up text from a message file token
*
* Assumptions
*  global_MessageFD is valid
*
* Inputs
*  token:   pointer to token (0, 10 or 13 terminated)
*  nparams: parameter count
*  ...:     between 0 and 4 (const char *) parameter pointers
*
* Outputs
*  result_ptr: filled in with pointer to (volatile) result string
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
extern _kernel_oserror *mess_LookUp(const char *token, const char **result_ptr, size_t nparams, ...);

/*****************************************************************************
* mess_LookUpDirect
*
* Finds the address of text associated with a token in MessageTrans' static
* copy of the messages file
*
* Assumptions
*  global_MessageFD is valid
*
* Inputs
*  token:      pointer to token (0, 10 or 13 terminated)
*
* Outputs
*  result_ptr: filled in with pointer to result string
*  result_len: if nonzero, filled in with length of string
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
extern _kernel_oserror *mess_LookUpDirect(const char *token, const char **result_ptr, size_t *result_len);

/*****************************************************************************
* mess_LookUpBuffer
*
* Looks up text from a message file token, using the supplied buffer
*
* Assumptions
*  global_MessageFD is valid
*
* Inputs
*  token:   pointer to token (0, 10 or 13 terminated)
*  buffer:  pointer to buffer
*  bufsize: size of buffer
*  nparams: parameter count
*  ...:     between 0 and 4 (const char *) parameter pointers
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
extern _kernel_oserror *mess_LookUpBuffer(const char *token, char *buffer, size_t bufsize, size_t nparams, ...);


#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
