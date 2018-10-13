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
/*---------------------------------------------------------------------------*/
/* File:    common.c                                                         */
/* Purpose: Commonly used Wimp routines                                      */
/*---------------------------------------------------------------------------*/
#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "wimplib.h"
#include "toolbox.h"
#include "swis.h"
#include "common.h"

/* Global messages file descriptor and string pointer */
MessagesFD    *message_block;
char          *message_buffer;


/*---------------------------------------------------------------------------*
 * error_trap                                                                *
 *                                                                           *
 * Wrap around a function to report an error if one occurred eg.:            *
 *  error_trap(event_initialise(&idb), 0);                                   *
 *                                                                           *
 * In: err - a kernel_oserror block                                          *
 *     type - 0 means non-fatal, otherwise program will exit after reporting *
 *---------------------------------------------------------------------------*/

void error_trap(_kernel_oserror *err, int err_type)
{
    /* Report the appropriate error, has one occured */
    if (err != NULL)
    {
        wimp_report_error(err, 0, messages_lookup("_TaskName"), 0, 0, 0);
  
        /* Now, if it was a fatal error (type != 0), exit at once */
        if (err_type != 0) exit(0);
    }
}


/*---------------------------------------------------------------------------*
 * messages_register                                                         *
 *                                                                           *
 * Registers the message file descriptor with the library so that it knows   *
 * where to find the message block for lookups.                              *
 *                                                                           *
 * In:                                                                       *
 *---------------------------------------------------------------------------*/

void messages_register(MessagesFD *messagefd_point, char *messagebuff_point)
{
  message_block = messagefd_point;
  message_buffer = messagebuff_point;
}


/*---------------------------------------------------------------------------*
 * messages_lookup                                                           *
 *                                                                           *
 * Searches the 'messages' file for the text represented by the token string *
 * and returns a pointer to a buffer storing this text                       *
 *                                                                           *
 * In:                                                                       *
 *---------------------------------------------------------------------------*/

char *messages_lookup(const char *token_string)
{
  _kernel_swi_regs regs;

  regs.r[0] = (int)message_block;
  regs.r[1] = (int)token_string;
  regs.r[2] = (int)message_buffer;
  regs.r[3] = 255;
  _kernel_swi(MessageTrans_Lookup, &regs, &regs);
    
  return message_buffer;
}


char *messages_lookup_with_parameter(char *token_string, char *parameter)
{
  _kernel_swi_regs regs;

  regs.r[0] = (int)message_block;
  regs.r[1] = (int)token_string;
  regs.r[2] = (int)message_buffer;
  regs.r[3] = 255;
  regs.r[4] = (int)parameter;
  _kernel_swi(MessageTrans_Lookup, &regs, &regs);
    
  return message_buffer;
}


/*---------------------------------------------------------------------------*
 * common_read_screensize                                                    *
 *                                                                           *
 * Return the size of the screen in OS units                                 *
 *---------------------------------------------------------------------------*/

_kernel_oserror *common_read_screensize(int *x, int *y)
{
    _kernel_oserror *e;
    int              xeig, yeig, xpix, ypix;

    e=_swix(OS_ReadModeVariable, _INR(0,1)|_OUT(2), -1, 4, &xeig); if (e) return e;
    e=_swix(OS_ReadModeVariable, _INR(0,1)|_OUT(2), -1, 5, &yeig); if (e) return e;
    e=_swix(OS_ReadModeVariable, _INR(0,1)|_OUT(2), -1, 11, &xpix); if (e) return e;
    e=_swix(OS_ReadModeVariable, _INR(0,1)|_OUT(2), -1, 12, &ypix); if (e) return e;

    *x = xpix << xeig;
    *y = ypix << yeig;

    return NULL;
}
    

/*---------------------------------------------------------------------------*
 * common_error                                                              *
 *                                                                           *
 * Given a string, return a kernel_oserror compatible error.                 *
 *---------------------------------------------------------------------------*/

_kernel_oserror *common_error(char *s)
{
    static _kernel_oserror e;
    e.errnum=0;
    strcpy(e.errmess, s);
    
    return &e;
}


/*---------------------------------------------------------------------------*
 * strncmpa                                                                  *
 *                                                                           *
 * Compare n letters of a string, case insensitive.                          *
 *                                                                           *
 * In: str1 -> first string                                                  *
 *     str2 -> second string                                                 *
 *     size = number of characters to compare.                               *
 *                                                                           *
 * Returns: 0 if strings equal, otherwise number of characters they differ   *
 *          by.                                                              *
 *---------------------------------------------------------------------------*/
 
int strncmpa(char *str1, char *str2, int size)
{
    int n;
    int equal=size;
    
    for (n=0; n<size; n++)
    {
        if (str1[n]==str2[n]) equal--;
        else if (str1[n]==str2[n]-32) equal--;
        else if (str1[n]-32==str2[n]) equal--;
    }

    return equal;
}


/*---------------------------------------------------------------------------*
 * read_cmos_value                                                           *
 *                                                                           *
 * Read a byte of CMOS ram                                                   *
 *                                                                           *
 * In: location = CMOS location to read                                      *
 *                                                                           *
 * Returns: contents of location.                                            *
 *---------------------------------------------------------------------------*/

int read_cmos_value(int location)
{
    int result;
    _swix(OS_Byte, _INR(0,1)|_OUT(2), 161, location, &result);
    return result;
}
