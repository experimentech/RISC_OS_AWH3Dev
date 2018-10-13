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
  Purpose: management of multiple windows on a Text object.
  Author: W. Stoye
  Status: experimental
          system-independent
  History:
    21-Feb-88: started
    02-Mar-88: WRS: C coding complete.
*/

#define BOOL int
#define TRUE 1
#define FALSE 0

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "trace.h"
#include "werr.h"
#include "txt.h"
#include "EditIntern/txtundo.h"
#include "EditIntern/txt1.h"
#include "EditIntern/txt3.h"

static void txt3_initw(txt t)
{
      txt1_donewmarker(t, &t->w->firstvis);
      txt1_donewmarker(t, &t->w->lastvis);
      txt1_donewmarker(t, &t->w->caret);
      t->w->firstvisy = 0; 
      t->w->lastvisy = 0;
      t->w->caretx = 0;
      t->w->carety = 0;
      t->w->caretoffsetx = 0;
      t->w->caretoffsety = 0;
      t->w->ioffset = 0;
      t->w->isize = 0;
}

BOOL txt3_inittxt(txt t)
{
  t->w = malloc(sizeof(txt1_window));
  if (t->w == 0) return FALSE;
  t->windows[1] = t->w;
  t->nwindows = 1;
  t->witer = 0;
  txt3_initw(t);
  return TRUE;
}

BOOL txt3_preparetoaddwindow(txt t)
{
  if (t->nwindows == txt1_MAXWINDOWSPERTEXT) {
    return FALSE;
  } else {
    txt1_window *parent = t->w;

    txt1_domovemarker(t, &t->windows[1]->caret, txt1_dodot(t));
    t->windows[++t->nwindows] = t->windows[1];
    t->w = malloc(sizeof(txt1_window));
    if (t->w == 0) {
      t->nwindows--;
      t->w = t->windows[1];
      return FALSE;
    };
    t->windows[1] = t->w;
    *t->w = *parent; /* initialise all fields similar to parent. */
    txt1_donewmarker(t, &t->w->firstvis);
    txt1_donewmarker(t, &t->w->lastvis);
    txt1_donewmarker(t, &t->w->caret);
    return TRUE;
  };
}

static txt1_windex txt3__findwindow(txt t, void *handle)
{
  txt1_windex i = 1;

  while (1) {
    if (handle == t->windows[i]->syshandle) {
      tracef1("findwindow returns %i.\n", i);
      return i;
    };
    i++;
#if TRACE
    if (i > txt1_MAXWINDOWSPERTEXT) werr(TRUE, "internal: t-3-1");
#endif
  };
}

BOOL txt3_foreachwindow(txt t)
{
  if (t->witer == t->nwindows) { /* finished */
    t->witer = 0;
    txt3_resetprimarywindow(t);
    tracef0("foreachwindow terminates.\n");
    return FALSE;
  } else {
    t->witer++;
    t->w = t->windows[t->witer];
    tracef1("foreachwindow, setting window %i.\n", (int) t->w);
    return TRUE;
  };
}

void txt3_disposeallwindows(txt t)
{
  while (txt3_foreachwindow(t)) {
    t->w->disposewindow(t);
    free(t->w);
  };
}

void txt3_disposewindow(txt t, txt1_windex wi)
{
  int i;

  tracef3("disposing of window %i %i %i.\n",
    wi, (int) t->windows[wi], (int) t->windows[wi]->syshandle);
  if (wi == 1) {
    txt3_setprimarywindow(t, t->windows[2]->syshandle);
    wi = 2;
  };
  txt1_dodisposemarker(t, &(t->windows[wi]->caret));
  t->w = t->windows[wi];
  t->w->disposewindow(t);
  txt3_resetprimarywindow(t);
  for (i = wi; i < t->nwindows; i++) t->windows[i] = t->windows[i+1];
  t->nwindows--;
  tracef4("windows now %i %i %i, nwindows=%i.\n",
    (int) t->windows[1],
    (int) t->windows[2],
    (int) t->windows[3],
    t->nwindows);
}

static void txt3__setprimarywindowno(txt t, txt1_windex wi)
{
  txt1_window *w2;

  w2 = t->windows[wi];
  t->windows[wi] = t->windows[1];
  t->windows[1] = w2;
  t->w = t->windows[1];
}

void txt3_setprimarywindow(txt t, void *handle)
{
  BOOL display;

  tracef1("set primary window to have %i.\n", (int) handle);
  if (handle == t->windows[1]->syshandle) {
    t->w = t->windows[1]; /* just clear any temporary window. */
    tracef0("window already set.\n");
  } else {
    txt1_domovemarker(t, &t->windows[1]->caret, txt1_dodot(t));
    txt3__setprimarywindowno(t, txt3__findwindow(t, handle));
    display = (0 != (t->charoptionset & txt_DISPLAY));
    t->charoptionset &= ~txt_DISPLAY; /* turn display off */
    txt1_domovedottomarker(t, &t->w->caret);
    if (display) t->charoptionset |= txt_DISPLAY;
    tracef0("set primary window done.\n");
  };
}
/* The move is "secret" in that, taking the change in window into account, no
display update is required for the screen to be entirely correct. The
supression of the simple case is quite important, because otherwise the undo
buffer gets clogged with meaningless movement. */

void txt3_settemporarywindow(txt t, void *handle)
{
  t->w = t->windows[txt3__findwindow(t, handle)];
}

void txt3_resetprimarywindow(txt t)
{
  t->w = t->windows[1];
}

/* end */
