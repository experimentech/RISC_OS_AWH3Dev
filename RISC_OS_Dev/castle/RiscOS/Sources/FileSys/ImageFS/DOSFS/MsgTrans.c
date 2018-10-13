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
/*> c.MsgTrans <*/
/*-------------------------------------------------------------------------*/
/* Wrappers for MessageTrans SWIs                                          */
/*-------------------------------------------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include "kernel.h"
#include "swis.h"
#include "DebugLib/DebugLib.h"
#include "Global/FSNumbers.h"

#include "DOSFSHdr.h"
#include "MsgTrans.h"

/* Handle for MessageTrans. */
static int file_data[4];

/* Flag which specifies whether the Messages file is open or closed. */
static int file_closed = 1;

static _kernel_oserror *msgtrans_openfile(void)
{
  _kernel_swi_regs r;
  _kernel_oserror *err;
  if (!file_closed)
    return NULL;
  r.r[0] = (int)file_data;
  r.r[1] = (int)Module_MessagesFile;
  r.r[2] = 0;
  if ((err = _kernel_swi(MessageTrans_OpenFile, &r, &r)) != NULL)
    return err;
  file_closed = 0;
  return NULL;
}

/* Call from shutdown_fs() */
extern void msgtrans_closefile(void)
{
  _kernel_swi_regs r;
  if (file_closed)
    return;
  r.r[0] = (int)file_data;
  (void)_kernel_swi(MessageTrans_CloseFile, &r, &r);
  file_closed = 1;
}

extern _kernel_oserror *msgtrans_lookup(
  char *token,
  char **buf,
  int *bufsz,
  char *p1,
  char *p2,
  char *p3,
  char *p4
) {
  _kernel_swi_regs r;
  _kernel_oserror *err;
  if (file_closed)
    if ((err = msgtrans_openfile()) != NULL)
      return err;
  r.r[0] = (int)file_data;
  r.r[1] = (int)token;
  r.r[2] = (int)*buf;
  r.r[3] = *bufsz;
  r.r[4] = (int)p1;
  r.r[5] = (int)p2;
  r.r[6] = (int)p3;
  r.r[7] = (int)p4;
  if ((err = _kernel_swi(MessageTrans_Lookup, &r, &r)) != NULL)
    return err;
  *bufsz = r.r[3];
  if (*buf == NULL)
   *buf = (char *)r.r[2];
  return NULL;
}

/*-------------------------------------------------------------------------*/

_kernel_oserror *_syserr ;      /* global error pointer */

/*---------------------------------------------------------------------------*/

/* The following is used to construct MessageTrans tokens for errors. */
#define ERROR_FMT "ERR%2.2X"

_kernel_oserror  _gerror = {0} ; /* static error structure */
_kernel_oserror *_syserr ;       /* static pointer to the error structure */

/*---------------------------------------------------------------------------*/
/* global_error:
 * Return a RISC OS error block pointer for the given error number.
 */
_kernel_oserror *global_error(int number)
{
 /* return a pointer to the "_kernel_oserror" block for error "number" */
 char token[8];
 _kernel_oserror *err;
 char *buf = _gerror.errmess;
 int bufsz = 252;
 _gerror.errnum = ext_err(number) ;
 /* lookup Messages file for error text */
 sprintf(token, ERROR_FMT, number);
 if ((err = msgtrans_lookup(token, &buf, &bufsz, 0, 0, 0, 0)) != NULL)
  return err;
 dprintf(("", "DOSFS: global_error: &%08X \"%s\"\n",
              _gerror.errnum,_gerror.errmess));
 return(_syserr) ;
}

/*---------------------------------------------------------------------------*/
/* global_errorP:
 * Return a RISC OS error block pointer for the given error number. The
 * passed parameter is placed into the error message.
 */

_kernel_oserror *global_errorP(int number,char *par1)
{
 /* return a pointer to the "_kernel_oserror" block for error "number" */
 char token[8];
 _kernel_oserror *err;
 char *buf = _gerror.errmess;
 int bufsz = 252;
 _gerror.errnum = ext_err(number) ;
 /* lookup Messages file for error text */
 sprintf(token, ERROR_FMT, number);
 if ((err = msgtrans_lookup(token, &buf, &bufsz, par1, 0, 0, 0)) != NULL)
  return err;
 dprintf(("", "DOSFS: global_errorP: &%08X \"%s\"\n",
              _syserr->errnum,_syserr->errmess));
 return(_syserr) ;
}

/*---------------------------------------------------------------------------*/

void global_error0(int number)
{
 /* place error number and message into "_syserr" */
 global_error(number) ;
 return ;
}

/*---------------------------------------------------------------------------*/

void global_error1(int number,char *par1)
{
 /* place error number and message into "_syserr" */
 global_errorP(number, par1);
 return ;
}

/*---------------------------------------------------------------------------*/

void global_errorX(_kernel_oserror *errptr)
{
 _gerror.errnum = errptr->errnum ;
 sprintf(&(_gerror.errmess[0]),errptr->errmess) ;
 return ;
}

/*---------------------------------------------------------------------------*/

_kernel_oserror *global_errorT(int number,char *token,char *par1,char *par2)
{
 _kernel_oserror *err;
 char *buf = _gerror.errmess;
 int bufsz = 252;
 _gerror.errnum = ext_err(number) ;
 /* lookup Messages file for error text */
 if ((err = msgtrans_lookup(token, &buf, &bufsz, par1, par2, 0, 0)) != NULL)
  return err;
 dprintf(("", "DOSFS: global_errorT: &%08X \"%s\"\n",
              _syserr->errnum,_syserr->errmess));
 return(_syserr) ;
}
