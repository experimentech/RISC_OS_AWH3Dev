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
* $Id: debug,v 1.1.1.1 2005-01-12 19:55:22 bavison Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): Rhenium
*
* ----------------------------------------------------------------------------
* Copyright © 2005 Castle Technology Ltd. All rights reserved.
*
* ----------------------------------------------------------------------------
* Purpose: Debug library
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdbool.h>
#include "swis.h"

#include "debug.h"


/*****************************************************************************
* Macros
*****************************************************************************/


/*****************************************************************************
* New type definitions
*****************************************************************************/


/*****************************************************************************
* Constants
*****************************************************************************/
#define DADebug_GetWriteCAddress 0x531C0


/*****************************************************************************
* File scope global variables
*****************************************************************************/
extern void (*DADWriteC)(const char c);
extern void (*DADWriteC)(const char c) = NULL;


/*****************************************************************************
* Function prototypes - Private to this file
*****************************************************************************/


/*****************************************************************************
* Functions
*****************************************************************************/

#ifdef DEBUG

/*****************************************************************************
* dadprintf
*
* Debug function - a printf-style interface to DADebug
*
* Assumptions
*  NONE
*
* Inputs
*  printf-style format string and variadic parameters
*
* Outputs
*  NONE
*
* Returns
*  NULL if initialisation succeeds; otherwise pointer to error block
*****************************************************************************/
void dadprintf(const char * restrict format, ...)
{
  static bool init = false;
  if (!init++)
  {
    _swix(DADebug_GetWriteCAddress, _OUT(0), &DADWriteC);
  }
  if (DADWriteC)
  {
    static char string[256];
    va_list ap;
    va_start(ap, format);
    vsnprintf(string, sizeof string, format, ap);
    size_t n = strlen(string);
    for (size_t i = 0; i < n; i++)
    {
      DADWriteC(string[i]);
      if (string[i] == '\n') DADWriteC('\r');
    }
  }
}

#endif


/*****************************************************************************
* END OF FILE
*****************************************************************************/
