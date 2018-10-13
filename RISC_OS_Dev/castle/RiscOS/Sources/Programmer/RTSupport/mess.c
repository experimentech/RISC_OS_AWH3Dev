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
* $Id: mess,v 1.1.1.1 2005-01-12 19:55:22 bavison Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): Ursula (originally)
*
* ----------------------------------------------------------------------------
* Copyright � 1997-2004 Castle Technology Ltd. All rights reserved.
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
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdbool.h>
#include "swis.h"

#include "global.h"
#include "mess.h"


/*****************************************************************************
* Macros
*****************************************************************************/


/*****************************************************************************
* New type definitions
*****************************************************************************/


/*****************************************************************************
* Constants
*****************************************************************************/


/*****************************************************************************
* File scope global variables
*****************************************************************************/
static _kernel_oserror static_ErrorBlock = { 0, "" };
static char static_LookedUpText[256];
static uint32_t static_Range1lo;
static uint32_t static_Range1hi;
static _kernel_oserror **static_Range1Errors;
static uint32_t static_Range2lo;
static uint32_t static_Range2hi;
static _kernel_oserror **static_Range2Errors;


/*****************************************************************************
* Function prototypes - Private to this file
*****************************************************************************/
static void PrepareErrorRange(uint32_t rangelo, uint32_t rangehi, _kernel_oserror ***errors, bool *error);


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
  char block[sizeof (int) + strlen(token) + 1];
  _kernel_oserror *error_block_in = (_kernel_oserror *) block;
  error_block_in->errnum = errno;
  strcpy(error_block_in->errmess, token);

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
               error_block_in,
               &global_MessageFD,
               &static_ErrorBlock,
               sizeof(static_ErrorBlock),
               p[0],
               p[1],
               p[2],
               p[3]);
}

/*****************************************************************************
* mess_PrepareErrors
*
* Looks up selected ranges of parameter-less errors to speed up mess_MakeError
*
* Assumptions
*  global_MessageFD is valid
*
* Inputs
*  range1lo: lowest error in first range to cache
*  range1hi: lowest error in first range to cache
*  range2lo: lowest error in second range to cache
*  range2hi: lowest error in second range to cache
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
void mess_PrepareErrors(uint32_t range1lo, uint32_t range1hi, uint32_t range2lo, uint32_t range2hi)
{
  bool error = false;
  static_Range1lo = range1lo;
  static_Range1hi = range1hi;
  PrepareErrorRange(range1lo, range1hi, &static_Range1Errors, &error);
  static_Range2lo = range2lo;
  static_Range2hi = range2hi;
  PrepareErrorRange(range2lo, range2hi, &static_Range2Errors, &error);
  if (error) mess_DiscardErrors();
}

static void PrepareErrorRange(uint32_t rangelo, uint32_t rangehi, _kernel_oserror ***errors, bool *error)
{
  if (!*error && NULL == (*errors = calloc(1, sizeof (_kernel_oserror *) * (rangehi - rangelo + 1))))
    *error = true;
  for (uint32_t errno = rangelo; !*error && errno <= rangehi; errno++)
  {
    char token[4];
    sprintf(token, "E%02X", errno & 0xFF);
    const char *string;
    _kernel_oserror *e = mess_LookUp(token, &string, 0);
    if (e)
    {
      string = e->errmess;
    }
    size_t stringlen = strlen(string);
    if (NULL == ((*errors)[errno - rangelo] = malloc(sizeof (int) + stringlen + 1)))
    {
      *error = true;
    }
    else
    {
      ((*errors)[errno - rangelo])->errnum = errno;
      strcpy(((*errors)[errno - rangelo])->errmess, string);
    }
  }
}

/*****************************************************************************
* mess_DiscardErrors
*
* Frees memory used by mess_PrepareErrors
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
void mess_DiscardErrors(void)
{
  if (static_Range1Errors)
  {
    for (uint32_t errno = static_Range1lo; errno <= static_Range1hi; errno++)
    {
      free(static_Range1Errors[errno - static_Range1lo]);
    }
    free(static_Range1Errors);
  }
  static_Range1lo = -1;
  static_Range1hi = -1;
  static_Range1Errors = NULL;
  if (static_Range2Errors)
  {
    for (uint32_t errno = static_Range2lo; errno <= static_Range2hi; errno++)
    {
      free(static_Range2Errors[errno - static_Range2lo]);
    }
    free(static_Range2Errors);
  }
  static_Range2lo = -1;
  static_Range2hi = -1;
  static_Range2Errors = NULL;
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
  if (nparams == 0)
  {
    if (errno >= static_Range1lo && errno <= static_Range1hi && static_Range1Errors)
    {
      return static_Range1Errors[errno - static_Range1lo];
    }
    if (errno >= static_Range2lo && errno <= static_Range2hi && static_Range2Errors)
    {
      return static_Range2Errors[errno - static_Range2lo];
    }
  }

  va_list ap;
  const char *p[4] = { NULL, NULL, NULL, NULL };
  size_t i;

  /* Set up tokenised error block */
  char block[8];
  _kernel_oserror *error_block_in = (_kernel_oserror *) block;
  error_block_in->errnum = errno;
  sprintf(error_block_in->errmess, "E%02X", errno & 0xFF);

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
               error_block_in,
               &global_MessageFD,
               &static_ErrorBlock,
               sizeof(static_ErrorBlock),
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
    static_ErrorBlock.errnum = err_in->errnum;
    strncpy(&static_ErrorBlock.errmess[0],
      &err_in->errmess[0], sizeof(static_ErrorBlock.errmess));
  }
  return (err_in ? &static_ErrorBlock : NULL);
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
* mess_LookUpNoError
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
*  NONE
*
* Returns
*  Pointer to string, of pointer to string part of error essage
*****************************************************************************/
const char *mess_LookUpNoError(const char *token, size_t nparams, ...)
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
  const char *string;
  _kernel_oserror *e = _swix(MessageTrans_Lookup, _INR(0,7)|_OUT(2),
                             &global_MessageFD,
                             token,
                             &static_LookedUpText,
                             sizeof(static_LookedUpText),
                             p[0],
                             p[1],
                             p[2],
                             p[3],
                             &string);
  if (e) return e->errmess; else return string;
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
