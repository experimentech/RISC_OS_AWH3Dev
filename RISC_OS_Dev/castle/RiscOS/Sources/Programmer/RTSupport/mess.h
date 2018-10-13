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
#if !defined(RTSUPPORT_MESS_H) /* file used if not already included */
#define RTSUPPORT_MESS_H
/*****************************************************************************
* $Id: mess,v 1.1.1.1 2005-01-12 19:55:22 bavison Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): Ursula (originally)
*
* ----------------------------------------------------------------------------
* Copyright © 1997-2004 Castle Technology Ltd. All rights reserved.
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
* Macros
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
extern _kernel_oserror *mess_GenerateError(const char *token, uint32_t errno, size_t nparams, ...);
extern void mess_PrepareErrors(uint32_t range1lo, uint32_t range1hi, uint32_t range2lo, uint32_t range2hi);
extern void mess_DiscardErrors(void);
extern _kernel_oserror *mess_MakeError(uint32_t errno, size_t nparams, ...);
extern _kernel_oserror *mess_CacheError(const _kernel_oserror *err_in);
extern _kernel_oserror *mess_LookUp(const char *token, const char **result_ptr, size_t nparams, ...);
extern const char *mess_LookUpNoError(const char *token, size_t nparams, ...);
extern _kernel_oserror *mess_LookUpDirect(const char *token, const char **result_ptr, size_t *result_len);
extern _kernel_oserror *mess_LookUpBuffer(const char *token, char *buffer, size_t bufsize, size_t nparams, ...);


#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
