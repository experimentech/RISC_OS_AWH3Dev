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
/************************************************************************/
/* � Acorn Computers Ltd, 1992.                                         */
/*                                                                      */
/* This file forms part of an unsupported source release of RISC_OSLib. */
/*                                                                      */
/* It may be freely used to create executable images for saleable       */
/* products but cannot be sold in source form or as an object library   */
/* without the prior written consent of Acorn Computers Ltd.            */
/*                                                                      */
/* If this file is re-distributed (even if modified) it should retain   */
/* this copyright notice.                                               */
/*                                                                      */
/************************************************************************/

/*
 * Title  : c.werr
 * Purpose: provide error reporting in wimp programs
 * History: IDJ: 07-Feb-92: prepared for source release
 *
 */

#define BOOL int
#define TRUE 1
#define FALSE 0

#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "swis.h"

#include "os.h"
#include "wimp.h"
#include "werr.h"
#include "wimpt.h"

void werr(int fatal, char* format, ...)
{
  va_list va;
  os_error e;

  e.errnum = 0;
  va_start (va, format);
  vsprintf (e.errmess, format, va);
  va_end (va);

  if (fatal)
    os_swi1 (OS_GenerateError, (int) &e);
  else
    wimp_reporterror (&e, 0, wimpt_programname());
}

/* end */
