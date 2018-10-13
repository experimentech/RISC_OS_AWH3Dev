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
/**************************************************************************/
/* File:    printf.c                                                      */
/* Purpose: Routines for the Printf output method.                        */
/*                                                                        */
/* Copyright [1999-2001] Pace Micro Technology PLC.  All rights reserved. */
/*                                                                        */
/* The copyright in this material is owned by Pace Micro Technology PLC   */
/* ("Pace").  This material is regarded as a highly confidential trade    */
/* secret of Pace.  It may not be reproduced, used, sold or in any        */
/* other way exploited or transferred to any third party without the      */
/* prior written permission of Pace.                                      */
/**************************************************************************/


/* -------------------------------------- LIBRARY IMPORTS --------------------------------------- */
#include "include.h"
#include "misc.h"
#include "globals.h"
#include "printf.h"


/**********************/
/* Exported functions */


/************************************************************************/
/* debug_printf_output                                                  */
/*                                                                      */
/* Function outputs the data from the library to stdout.                */
/*                                                                      */
/* Parameters: buffer - text to output.                                 */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void debug_printf_output (const char *buffer, size_t len)
{
  size_t count;

  /* If we want "Screen cornering (TM)", do it. */
  if (debug_current_options.screen_cornering == 1)
  {
    _swix (OS_WriteC, _IN(0), 4);
    _swix (OS_WriteC, _IN(0), 26);
  }

  for (count = 0; count < len; count++)
  {
    _swix (OS_WriteC, _IN(0), (int) buffer[count]);

    /* Check to see if \n has been passed.  If so, add a CR */
    if (buffer[count] == '\n')
      _swix (OS_WriteC, _IN(0), '\r');
  }
}
