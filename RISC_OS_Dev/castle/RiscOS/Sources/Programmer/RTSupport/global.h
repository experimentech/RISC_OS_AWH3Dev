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
#if !defined(RTSUPPORT_GLOBAL_H) /* file used if not already included */
#define RTSUPPORT_GLOBAL_H
/*****************************************************************************
* $Id: global,v 1.2 2016-04-05 20:04:24 jlee Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): Rhenium
*
* ----------------------------------------------------------------------------
* Copyright © 2004 Castle Technology Ltd. All rights reserved.
*
* ----------------------------------------------------------------------------
* Purpose: Global variables etc
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include "kernel.h"

#include "tboxlibs/toolbox.h"


/*****************************************************************************
* Macros
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


/*****************************************************************************
* New type definitions
*****************************************************************************/


/*****************************************************************************
* Constants
*****************************************************************************/


/*****************************************************************************
* Global variables
*****************************************************************************/
extern MessagesFD global_MessageFD; /* message file descriptor */
extern MessagesFD global_PriorityMessageFD;


/*****************************************************************************
* Function prototypes
*****************************************************************************/

extern void asm_seriouserrorv_veneer(void);

#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
