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
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include "swis.h"

#include "global.h"
#include "mess.h"


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
* File scope Global variables
*****************************************************************************/
static _kernel_oserror static_ErrorBlockIn = { 0, "" };
static _kernel_oserror static_ErrorBlockOut = { 0, "" };
static char static_LookedUpText[256];


/*****************************************************************************
* Function prototypes - Private to this file
*****************************************************************************/


/*****************************************************************************
* Functions
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
_kernel_oserror *mess_GenerateError(const char *token, uint32_t errno, size_t nparams, ...)
{
  va_list ap;
  const char *p[4] = { NULL, NULL, NULL, NULL };
  size_t i;
  
  /* Set up tokenised error block */
  static_ErrorBlockIn.errnum = errno;
  strncpy((char *) &(static_ErrorBlockIn.errmess),
    token, sizeof(static_ErrorBlockIn.errmess));
  
  /* Determine parameter pointers */
  va_start(ap,nparams);
  nparams = MIN(nparams,4);
  for (i = 0; i < nparams; ++i)
  {
    p[i] = va_arg(ap,const char *);
  }
  va_end(ap);  
  
  /* Look up token using our buffer */
  return _swix(MessageTrans_ErrorLookup, _INR(0,7),
               &static_ErrorBlockIn,
               &global_MessageFD,
               &static_ErrorBlockOut,
               sizeof(static_ErrorBlockOut),
               p[0],
               p[1],
               p[2],
               p[3]);
}

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
_kernel_oserror *mess_MakeError(uint32_t errno, size_t nparams, ...)
{
  va_list ap;
  const char *p[4] = { NULL, NULL, NULL, NULL };
  size_t i;
  
  /* Set up tokenised error block */
  static_ErrorBlockIn.errnum = errno;
  sprintf(static_ErrorBlockIn.errmess, "E%02X", errno & 0xFF);
  
  /* Determine parameter pointers */
  va_start(ap,nparams);
  nparams = MIN(nparams,4);
  for (i = 0; i < nparams; ++i)
  {
    p[i] = va_arg(ap,const char *);
  }
  va_end(ap);  
  
  /* Look up token using our buffer */
  return _swix(MessageTrans_ErrorLookup, _INR(0,7),
               &static_ErrorBlockIn,
               &global_MessageFD,
               &static_ErrorBlockOut,
               sizeof(static_ErrorBlockOut),
               p[0],
               p[1],
               p[2],
               p[3]);
}

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
_kernel_oserror *mess_CacheError(const _kernel_oserror *err_in)
{
  if (err_in != NULL)
  {
    static_ErrorBlockOut.errnum = err_in->errnum;
    strncpy(&static_ErrorBlockOut.errmess[0],
      &err_in->errmess[0], sizeof(static_ErrorBlockOut.errmess));
  }
  return (err_in ? &static_ErrorBlockOut : NULL);
}

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
_kernel_oserror *mess_LookUp(const char *token, const char **result_ptr, size_t nparams, ...)
{
  va_list ap;
  const char *p[4] = { NULL, NULL, NULL, NULL };
  size_t i;
  
  /* Determine parameter pointers */
  va_start(ap,nparams);
  nparams = MIN(nparams,4);
  for (i = 0; i < nparams; ++i)
  {
    p[i] = va_arg(ap,const char *);
  }
  va_end(ap);  
  
  /* Look up token using our buffer */
  return _swix(MessageTrans_Lookup, _INR(0,7)|_OUT(2),
               &global_MessageFD,
               token,
               &static_LookedUpText,
               sizeof(static_LookedUpText),
               p[0],
               p[1],
               p[2],
               p[3],
               result_ptr);
}

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
_kernel_oserror *mess_LookUpDirect(const char *token, const char **result_ptr, size_t *result_len)
{
  if (result_len == NULL)
  {
    return _swix(MessageTrans_Lookup, _INR(0,2)|_OUT(2),
                 &global_MessageFD,
                 token,
                 0,
                 result_ptr);
  }
  else
  {
    return _swix(MessageTrans_Lookup, _INR(0,2)|_OUTR(2,3),
                 &global_MessageFD,
                 token,
                 0,
                 result_ptr,
                 result_len);
  }
}

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
_kernel_oserror *mess_LookUpBuffer(const char *token, char *buffer, size_t bufsize, size_t nparams, ...)
{
  va_list ap;
  const char *p[4] = { NULL, NULL, NULL, NULL };
  size_t i;
  
  /* Determine parameter pointers */
  va_start(ap,nparams);
  nparams = MIN(nparams,4);
  for (i = 0; i < nparams; ++i)
  {
    p[i] = va_arg(ap,const char *);
  }
  va_end(ap);  
  
  /* Look up token using our buffer */
  return _swix(MessageTrans_Lookup, _INR(0,7),
               &global_MessageFD,
               token,
               buffer,
               bufsize,
               p[0],
               p[1],
               p[2],
               p[3]);
}


/*****************************************************************************
* END OF FILE
*****************************************************************************/
