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

/* Title:   c.saveas
 * Purpose: generalised data transfer to a concurrent wimp program.
 * History: IDJ: 06-Feb-92: prepared for source release
 *
 */


#define BOOL int
#define TRUE 1
#define FALSE 0

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "trace.h"
#include "os.h"
#include "bbc.h"
#include "wimp.h"
#include "wimpt.h"
#include "win.h"
#include "dbox.h"
#include "saveas.h"
#include "fileicon.h"
#include "werr.h"
#include "menu.h"
#include "event.h"
#include "msgs.h"
#include "help.h"
#include "template.h"
#include "VerIntern/messages.h"

#define saveas_FOK     0           /* OK action button */
#define saveas_FName   2           /* name field */
#define saveas_FIcon   3           /* icon to drag. */

static int saveas__filetype;
static xfersend_saveproc  saveas__saveproc;
static xfersend_sendproc  saveas__sendproc;
static xfersend_printproc saveas__printproc;
static void *saveas__savehandle;
static int saveas__estsize = 0;
static char *filename;  /*[256]*/
static dbox saveas__d ;


static BOOL saveas__wimpevents(dbox d, void *ev, void *handle)
{
  wimp_eventstr *e = (wimp_eventstr*) ev;

  tracef1("saveas raw event %i.\n", e->e);
  /* werr(0, "foo! %i %i", e->e, wimpt_last_event()->e); */
  if (help_dboxrawevents(d, ev, "SAVEAS")) return TRUE; /* handle interactive help */

  switch (e->e) {
    case wimp_EBUT:
      tracef1("saveas ebut %x\n",e->data.but.m.bbits);
      if (e->data.but.m.bbits == wimp_BDRAGLEFT) {
        dbox_getfield(d, saveas_FName, filename, 256);
        xfersend(saveas__filetype, filename, saveas__estsize,
                      saveas__saveproc, saveas__sendproc,
                      saveas__printproc, e, handle);
        return TRUE;
      }
  }

  return FALSE;
}

BOOL saveas(int filetype, char *name, int estsize,
            xfersend_saveproc  saveproc,
            xfersend_sendproc  sendproc,
            xfersend_printproc printproc,
            void *handle)
{
  if (saveas__d) return FALSE;
  if (filename == 0) filename = malloc(256);
  saveas__d = dbox_new("xfer_send");
  if (saveas__d == 0) return FALSE;

  saveas__filetype   = filetype;
  saveas__saveproc   = saveproc;
  saveas__sendproc   = sendproc;
  saveas__printproc  = printproc;
  saveas__savehandle = handle;
  saveas__estsize    = estsize;

  dbox_show(saveas__d);

  xfersend_close_on_xfer(TRUE, dbox_syshandle(saveas__d));

  fileicon((wimp_w) dbox_syshandle(saveas__d), saveas_FIcon, filetype);

  dbox_raw_eventhandler(saveas__d, saveas__wimpevents, saveas__savehandle);
  dbox_setfield(saveas__d, saveas_FName, name);
  strncpy(filename, name, 256);

  while (dbox_fillin(saveas__d) == saveas_FOK)
  {
   dbox_getfield(saveas__d, saveas_FName, filename, 256);

   /* Check for name with no "." in it, and complain if so. */
   {
    int i = 0;
    BOOL dot = FALSE;
    while ((! dot) && filename[i] != 0) dot = filename[i++] == '.';

    if (! dot)
    {
     werr(FALSE, msgs_lookup(MSGS_saveas1));
     continue;
    }
   }

   xfersend_set_fileissafe(TRUE);

   if (saveas__saveproc(filename, saveas__savehandle) == TRUE &&
       !dbox_persist()) break;
  }
  /* Assert: !...FOK || saveas__saveproc() && !...adjust */

  tracef0("saveas loop done.\n");
  xfersend_close_on_xfer(FALSE, 0);
  xfersend_clear_unknowns();
  dbox_hide(saveas__d);
  dbox_dispose(&saveas__d);
  saveas__d = 0;

  return TRUE;
}

void saveas_read_leafname_during_send(char *name, int length)
{
 int i ;
 char filename[256];
 dbox_getfield(saveas__d, saveas_FName, filename, 256);

 i = strlen(filename)-1 ;
 while (i>=0 && filename[i] != '.') i-- ;

 strncpy(name, &filename[i+1], length) ;
}

/* end saveas.c */
