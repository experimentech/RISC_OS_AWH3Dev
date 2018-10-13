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
/*
 * Title: txt.c
 * Purpose: Text display object.
 * Author: WRS
 * History:
 *   16 July 87 -- started
 *   30-Nov-87: WRS: converted into C.
 *   02-Mar-88: WRS: convertion complete.
 *   08-May-91: ECN: #ifndefed out unused ROM functions
 */

#define BOOL int
#define TRUE 1
#define FALSE 0

#include <stdlib.h>
#include <stdarg.h>
#include "txt.h"
#include "EditIntern/txtundo.h"
#include "EditIntern/txt1.h"
#include "EditIntern/txt3.h"
#include "EditIntern/txtar.h"
#include "werr.h"
#include "trace.h"

/* The type txt__str is actually provided by module txt1 */
/* ----------------------------------------------------- */

/* Module Structure of text implementation:
   =======================================
There are three key modules. There are recursive dependencies so that
the Texts module itself does not betray its implementation.

txt:    does the lock grabbing (if necessary), then calls txt1
        (buffer manipulation) or procedures installed by the window
        implementation (probably txt2).
        System-independent, uncontrovertial.
        h.txt is the only public part of this whole thing.
txt1:   the horrid but system-independent buffer manipulation
        and display calls.
        h.txt1 also has the main internal data structures declared.
        calls window procedures for system-dependent display primitives.
txt2:   the system-dependent stuff, installs window procedures in the
        text object. Other implementations are possible.
        Calls txt1 for editing operations provoked by user events.

*/
txt txt_new(char *title)
{
  txt t;

  t = malloc(sizeof(txt1_str));
  if (t == 0) {
    tracef0("txt_new fails.\n");
    return 0;
  };
  t->oaction = txt_EXTEND;
  t->charoptionset = txt_DISPLAY + txt_CARET;
  if (! txt1_inittextbuffer(t)) {
    free(t);
    return 0;
  };
  t->inbufhead = 0;
  t->inbuftail = 0;
  t->eventproc = (txt_event_proc) 0;
  t->eventprochandle = 0;
  t->eventnest = 0;
  t->disposepending = FALSE;
  txt3_inittxt(t); /* cannot fail. */
  if (! txtar_initwindow(t, title)) {
    txt1_disposetextbuffer(t);
    free(t);
    return 0;
  };
  t->undostate = txtundo_new();
  if (t->undostate == 0) {
    txt3_disposeallwindows(t);
    txt1_disposetextbuffer(t);
    free(t);
    return 0;
  };
  return t;
}

void txt_show(txt t)
{
  while (txt3_foreachwindow(t)) {
    t->w->doshow(t);
  }
}

void txt_hide(txt t)
{
  while (txt3_foreachwindow(t)) {
    t->w->dohide(t);
  }
}

void txt_settitle(txt t, char* title)
{
  while (txt3_foreachwindow(t)) {
    t->w->dosettitle(t, title);
  }
}

void txt_dispose(txt *t)
{
  if ((*t)->eventnest == 0) {
    txt1_disposetextbuffer(*t);
    txt3_disposeallwindows(*t);
    txtundo_dispose((*t)->undostate);
    free(*t);
  } else {
    (*t)->disposepending = TRUE;
  };
}

/* -------- General control operations. -------- */

#ifndef UROM
int txt_bufsize(txt t)
{
  return txt1_dobufsize(t);
}
#endif

#ifndef UROM
BOOL txt_setbufsize(txt t, int size)
{
  return txt1_dosetbufsize(t, size);
}
#endif

txt_charoption txt_charoptions(txt t)
{
  return t->charoptionset;
}

void txt_setcharoptions(txt t, txt_charoption affect, txt_charoption values)
{
  txt1_dosetcharoptions(t, affect, values);
}

void txt_setdisplayok(txt t) {
  txt1_dosetdisplayok(t);
}

int txt_lastref(txt t)
{
  return t->last_ref;
}

void txt_setlastref(txt t, int newvalue)
{
  t->last_ref = newvalue;
}

/* -------- Operations on the array of characters. -------- */

txt_index txt_dot(txt t)
{
  return txt1_dodot(t);
}

txt_index txt_size(txt t) /* max value that dot can take */
{
  return txt1_dosize(t);
}

void txt_setdot(txt t, txt_index i)
{
  txt1_dosetdot(t, i);
}

void txt_movedot(txt t, int by)
{
  txt1_domovedot(t, by);
}

void txt_insertchar(txt t, char c)
{
  txt1_doinsertchar(t, c);
}

void txt_insertstring(txt t, char* s)
{
  txt1_doinsertstring(t, s);
}

void txt_delete(txt t, int n)
{
  txt1_dodelete(t, n);
}

void txt_replacechars(txt t, int ntodelete, char* chars, int n)
{
  txt1_doreplacechars(t, ntodelete, chars, n);
}

char txt_charatdot(txt t)
{
  return txt1_docharatdot(t);
}

char txt_charat(txt t, txt_index i)
{
  return txt1_docharat(t, i);
}

#ifndef UROM
void txt_charsatdot(txt t, char/*out*/ *buffer, int /*inout*/ *n)
{
  txt1_docharsatdot(t, buffer, n);
}
#endif

void txt_replaceatend(txt t, int ntodelete, char *buffer, int n)
{
  txt1_doreplaceatend(t, ntodelete, buffer, n);
}

/* -------- Layout-dependent Operations. -------- */

void txt_movevertical(txt t, int by, int caretstill)
{
  txt1_domovevertical(t, by, caretstill);
}

void txt_movehorizontal(txt t, int by)
{
  txt1_domovehorizontal(t, by);
}

int txt_visiblelinecount(txt t)
{
  return t->w->dovisiblelinecount(t);
}

#ifndef UROM
int txt_visiblecolcount(txt t)
{
  return t->w->dovisiblecolcount(t);
}
#endif

/* -------- Operations on Markers. -------- */

void txt_newmarker(txt t, txt_marker* m)
{
  txt1_donewmarker(t, (txt1_imarker*) m);
}

void txt_movemarker(txt t, txt_marker* m, txt_index to)
{
  txt1_domovemarker(t, (txt1_imarker*) m, to);
}

void txt_movedottomarker(txt t, txt_marker* m)
{
  txt1_domovedottomarker(t, (txt1_imarker*) m);
}

txt_index txt_indexofmarker(txt t, txt_marker* m)
{
  return txt1_doindexofmarker(t, (txt1_imarker*) m);
}

void txt_disposemarker(txt t, txt_marker* m)
{
  txt1_dodisposemarker(t, (txt1_imarker*) m);
}

/* -------- Operations on the selection. -------- */

BOOL txt_selectset(txt t)
{
  return txt1_doselectset(t);
}

txt_index txt_selectstart(txt t)
{
  return txt1_doselectstart(t);
}

txt_index txt_selectend(txt t)
{
  return txt1_doselectend(t);
}

void txt_setselect(txt t, txt_index start, txt_index end)
{
  txt1_dosetselect(t, start, end);
}

/* -------- Input from the user -------- */

txt_eventcode txt_get(txt t)
{
  return t->w->doget(t);
}

#ifndef UROM
int txt_queue(txt t)
{
  return t->w->doqueue(t);
}
#endif

void txt_unget(txt t, txt_eventcode code)
{
  t->w->dounget(t, code);
}

void txt_eventhandler(txt t, txt_event_proc e, void* handle)
{
  t->eventproc = e;
  t->eventprochandle = handle;
}

void txt_readeventhandler(txt t, txt_event_proc *proc, void **handle)
{
  *proc = t->eventproc;
  *handle = t->eventprochandle;
}

/* -------- Direct Access to the array of characters. -------- */

void txt_arrayseg(txt t, txt_index at, char **a, int *n)
{
  txt1_doarraysegment(t, at, a, n);
}

/* -------- System hook. -------- */

int txt_syshandle(txt t)
{
  return t->w->dosyshandle(t);
}

void txt_init(void)
{
  return;   /* @@@ Do nothing for the moment (maybe one day) */
}

/* end */
