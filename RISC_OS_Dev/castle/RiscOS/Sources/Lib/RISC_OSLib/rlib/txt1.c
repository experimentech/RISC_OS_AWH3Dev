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
 * Title: c.txt1
 * Purpose: text display object, system-independent implementation part.
 * Author: WRS
 * Status: under development
 * History:
 *  18 July 87 -- started
 *  11-Jan-88: conversion to C started.
 *  13-Dec-89: WRS: msgs literal text put back in.
 *   1-Jun-90: NDR: reset txt->last_ref if txt->charoptionset & txt_UPDATED set
 *   1-Jun-90: NDR: removed definition of txt1__maxbi(), since it's not used
 *   8-May-91: ECN: #ifndefed out unused ROM functions
 */

  #define BOOL int
  #define TRUE 1
  #define FALSE 0
  #define NULL 0

#include <limits.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#include <stdarg.h>
#include "trace.h"
#include "werr.h"
#include "flex.h"
#include "msgs.h"
#include "txt.h"
#include "EditIntern/txtundo.h"
#include "EditIntern/txt1.h"
#include "EditIntern/txt3.h"
#include "VerIntern/messages.h"

#define GUARDBYTE 23
#define MINEXTENDEDTOP 20 /* 1024 in real life I think. */

/* -------- Forward References. -------- */

void txt1__assert(BOOL b, char *msg);
void txt1__assert2(BOOL b, char *msg1, char *msg2);
void txt1__assertcharbufindex(txt t, txt1_bufindex i, char *msg);
void txt1__yell(char *s1, char *s2);
BOOL txt1__lessoreqbi(txt t, txt1_bufindex a, txt1_bufindex b);
txt_index txt1__bufindextoindex(txt t, txt1_bufindex b);
txt1_bufindex txt1__indextobufindex(txt t, txt_index i);
txt1_bufindex txt1__firstchbi(txt t);
void txt1__incbi(txt t, txt1_bufindex *i /*inout*/, int n);
void txt1__incrawbi(txt t, txt1_bufindex *bi /*inout*/, int n);
void txt1__updatescrollbar(txt t);
txt1_bufindex txt1__termchbi(txt t);
void txt1__ensuredotvisible(txt t, int dotmove);
void txt1__showcaret(txt t);
void txt1__hidecaret(txt t);
txt1_zits txt1__spacewidth(txt t);
void txt1__displayreplace1(txt t, int n);
void txt1__displayreplace2(txt t, int n, int ndeleted);
void txt1_scrollbarmoveby(txt t, int by);
void txt1__measure(
  txt t,
  txt1_zits *x /*inout*/, txt1_zits *y /*inout*/,
  txt1_zits ylim,                  /* y>=ylim -> stop straight away. */
  txt1_bufindex *at /*inout*/,
  txt1_bufindex lim,               /* at==lim -> stop straight away. */
  BOOL generate);
BOOL txt1__measureback(
  txt t,
  txt1_zits *x /*inout*/,
  txt1_zits *y /*inout*/,
  txt1_zits ylim,                 /* y<=ylim -> stop straight away */
  txt1_bufindex *at /*inout*/,
  txt1_bufindex lim,              /* at==lim -> stop straight away */
  BOOL generate);
void txt1__cancelallcalls(txt t);
void txt1__horizmeasure(txt t,
  txt1_zits x, txt1_zits xlim, txt1_bufindex *at /*inout*/);
void txt1__redisplaytext(txt t, BOOL fresh);
BOOL txt1__dotatlinebreak(txt t);
void txt1__deletemarker(txt t, txt1_imarker *m);
void txt1__movemarker(txt t, txt1_imarker *m, txt1_bufindex newpos);
void txt1__cleartoendofline(txt t,
  txt1_zits *x /*inout*/, txt1_zits *y /*inout*/, BOOL generate);
void txt1__displayfrom(txt t, txt1_zits x, txt1_zits y, txt1_bufindex at);
void txt1__italicadjust(txt t);

/* -------- The text buffer structure. -------- */
/*
The traditional representation of the body of a text buffer (a la emacs)
consists of a contiguous area of memory, with the characters of the file
placed contiguously within it. at the) {t (= cursor) there is a gap, so that
insertion and deletion at) {t is quick. moving the) {t involves a (literal)
block move of characters. markers are implemented by a similar buffer of
pointers into the text buffer, they are kept in order within the buffer so
that movement/deletion only involve work if some markers are actually
involved. if the text gets too big to fit in the buffer then allocate a new
buffer and copy.

The buffer here is similar, with the additional complication that i wish
tty-style use to be efficient, i.e. adding things at the bottom and
removing corresponding things at the top. For this reason the whole thing
can actually circulate within the buffer.

The pointers into the buffer are as follows. in order to distinguish
the full and empty cases there's always a single extra 0c character
(called termch) in the buffer, after the last legal character.
"the array" refers to the abstract array the text object represents.
0:          base of the buffer.
top:        max possible legal value.
            t->buf[top] is a character in the buffer.
txtstart:   points to the first character in the array,
            or to termch if the array is empty.
gapstart:   points to the first character in the gap.
            never > top.
            can be equal to gapend, if no gap (i.e. array full).
            can be equal to t->txtstart, if) {t is at start of array.
gapend:     points to the first character after the gap.
            can point to termch, if) {t is at the end of the array.

Based on this, here are various predicates and invariants.

invariant:              top >= 1
                        txtstart <= top
                        gapstart <= top
                        gapend <= top
                        if gapstart <= gapend then (gap contiguous)
                          txtstart <= gapstart or txtstart > gapend
                        else
                          txtstart >= gapstart or txtstart < gapend
                        end
                        buf[(txtstart-1) % top] == 0c (termch)

buffer full:              gapstart == gapend

char "at") {t:            buf[gapend]

dot at start of array:    txtstart == gapstart

dot at end of array:      txtstart == (gapend + 1) % top

size of array:            (top - 1 - (gapend - gapstart)) % top

array is empty:          ) {t at start of array
                       ) {t at end of array
                        size of array == 0

Markers are held as two chains of markerrep, one before the dot in the array
and one at or beyond it.
*/

#if TRACE
void txt1__checkbufinvariant(txt t, char *msg)
{
    txt1_imarker *imarkerptr;

    txt1__assert2(t->top >= 1, msg, ":1");
    txt1__assert2(t->txtstart <= t->top, msg, ":2");
    txt1__assert2(t->gapstart <= t->top, msg, ":3");
    txt1__assert2(t->gapend <= t->top, msg, ":4");
    txt1__assert2(t->buf[t->top+1] == GUARDBYTE, msg, ":11");
    if (t->gapstart <= t->gapend) { /* gap contiguous */
      txt1__assert2(t->txtstart<=t->gapstart ||
                    t->txtstart>t->gapend, msg, ":5");
    } else {
      txt1__assert2(t->txtstart<=t->gapstart &&
                    t->txtstart>t->gapend, msg, ":6");
    };
    if (t->txtstart == 0) {
      txt1__assert2(t->buf[t->top] == 0, msg, ":7");
    } else {
      txt1__assert2(t->buf[t->txtstart-1] == 0, msg, ":8");
    };
    imarkerptr = t->marksbefore;
    while (imarkerptr != NULL) {
      txt1__assertcharbufindex(t, imarkerptr->pos, ":9"); /* msg lost */
      imarkerptr = imarkerptr->next;
    };
    imarkerptr = t->marksafter;
    while (imarkerptr != NULL) {
      txt1__assertcharbufindex(t, imarkerptr->pos, ":10"); /* msg lost */
      imarkerptr = imarkerptr->next;
    };
}
#else
#define txt1__checkbufinvariant(t,msg) ;
#endif

/* A "charbufindex" is a bufindex that does not point into the gap,
i.e. it points at a real char in the array, or at termch. */

#if TRACE
void txt1__assertcharbufindex(txt t, txt1_bufindex i, char *msg)
{
  txt1__assert2(i <= t->top, msg, ":1");
  if (t->gapend >= t->gapstart) { /* gap contiguous */
    txt1__assert2(i < t->gapstart || i >= t->gapend, msg, ":2");
  } else {
    txt1__assert2(i < t->gapstart && i >= t->gapend, msg, ":3");
  };
}
#else
#define txt1__assertcharbufindex(t,i,msg) ;
#endif

#if TRACE
void txt1__checkscreeninvariant(txt t, char *msg)
/* called after display update. */
{
    if (0 == (txt_DISPLAY & t->charoptionset)) return;
    if (! txt1__lessoreqbi(t, t->w->firstvis.pos, t->gapend)) {
      tracef("**firstvis problem: fv=%i dot=%i.\n",
        t->w->firstvis.pos, t->gapend);
      txt1__yell(msg, ":1");
    };
    if (! txt1__lessoreqbi(t, t->gapend, t->w->lastvis.pos)) {
      tracef("**lastvis problem: lv=%i dot=%i.\n",
        t->w->lastvis.pos, t->gapend);
      txt1__yell(msg, ":2");
    };
    txt1__assert2(txt1__lessoreqbi(t, t->w->firstvis.pos, t->gapend),
      msg, ":1");
    txt1__assert2(txt1__lessoreqbi(t, t->gapend, t->w->lastvis.pos),
      msg, ":2");

    if (t->w->lastvisy > t->w->limy + 2 * t->w->linesep) {
      tracef("**lastvisy problem, =%i (limy=%i).\n",
        t->w->lastvisy, t->w->limy);
    };
    if (t->w->firstvisy <= 0 || t->w->firstvisy > t->w->linesep) {
      tracef("**firstvisy problem, =%i.\n", t->w->firstvisy);
    };

    txt1__assert2(t->w->firstvisy > 0, msg, ":7");
    txt1__assert2(t->w->firstvisy <= t->w->linesep, msg, ":8");
    txt1__assert2(t->w->lastvisy <= t->w->limy + 2 * t->w->linesep, msg, ":9");
    /* the 2* is because a newlinech at the end of a partially visible
    line takes lastvisy to refer to the next char. */

    txt1__assert2(t->w->carety > 0, msg, ":3");
    txt1__assert2(t->w->carety < (t->w->linesep * t->w->limy) + t->w->linesep,
      msg, ":4");
    txt1__assert2(t->w->caretx >= 0, msg, ":5");
    if (TRUE /* >>>> (wrap in charoptionset) */) {
      txt1__assert2(t->w->caretx <= t->w->limx, msg, ":6"); /* inadequate test! */
      /* note that we are accepting the equal case, for when a line
      exactly fits. see the comment at the end of procedure measure. */
    };
}
#else
#define txt1__checkscreeninvariant(t,msg) ;
#endif

static int txt1__min(int a, int b) {return(a < b ? a : b);}

static int txt1__max(int a, int b) {return(a > b ? a : b);}

/* -------- checking and debugging. -------- */

#if TRACE
void txt1__writes(char *s)
{
  tracef(s);
}
/*>>>> this treatment of error cases in the "release" form is pretty
inadequate. some centralised "panic" formula should exist. */

void txt1__yell2(char *s1, char *s2, char *s3)
{
  txt1__writes("wrs internal error: ");
  txt1__writes(s1);
  txt1__writes(s2);
  txt1__writes(s3);
  txt1__writes("\n");
}

void txt1__yell(char *s1, char *s2)
{
  txt1__yell2(s1, s2, "");
}

void txt1__assert(int b, char *msg)
{
  if (! b) txt1__yell("assert fail: ", msg);
}

void txt1__assert2(int b, char *msg1, char *msg2)
{
  if (! b) txt1__yell2("assert fail: ", msg1, msg2);
}

void txt1__newline(void)
{
  tracef("\n");
}
#else

#define txt1__assert(t,msg) ;

#endif

/* -------- printing the text buffer. -------- */

#if TRACE

void txt1__safewrch(char c)
{
  if (c >= 32 && c < 127) {
    tracef("%c", c);
  } else if (c == 0) {
    tracef(".");
  } else if (c == '\n') {
    tracef("~");
  } else {
    tracef("?");
  };
}

void txt1__tab(int by)
{
  while (by-- > 0) tracef(" ");
}

void txt1__prmarkerchain(txt t, txt1_imarker *m)
{
  if (m == NULL) {tracef(" -> NULL\n");} else {
    tracef(" -> ");
    if (m == &(t->selstart)) {
      tracef("ss:");
    } else if (m == &t->selend) {
      tracef("se:");
    } else if (m == &t->w->firstvis) {
      tracef("fv:");
    } else if (m == &t->w->lastvis) {
      tracef("lv:");
    };
    tracef("%i", m->pos);
    txt1__prmarkerchain(t, m->next);
  };
}

void txt1__pr(txt t)
{
  int i;
  if (t->top > 300) {
    tracef(">>>>top=%i start=%i gstart=%i gend=%i\n",
      t->top, t->txtstart, t->gapstart, t->gapend);
  } else {
    /* zap the gap characters to make things clearer */
    if (t->gapend > t->gapstart) {
      for (i = t->gapstart; i <= t->gapend-1; i++) t->buf[i] = '*';
    } else if (t->gapend < t->gapstart) {
      for (i = t->gapstart; i <= t->top; i++) t->buf[i] = '*';
      for (i = 1; i <= t->gapend; i++) t->buf[i-1] = '*';
    };
    tracef("     [");
    for (i = 0; i <= t->top; i++) txt1__safewrch(t->buf[i]);
    tracef("]\n");
    txt1__tab(t->txtstart+1); tracef("start^ (%i)\n", t->txtstart);
    txt1__tab(t->gapstart); tracef("gstart^ (%i)\n", t->gapstart);
    txt1__tab(t->gapend+2); tracef("gend^ (%i)\n", t->gapend);
  };

  /* prettyprint markers. */
  tracef("marks before:");
  txt1__prmarkerchain(t, t->marksbefore);
  tracef("marks after:");
  txt1__prmarkerchain(t, t->marksafter);
  tracef("fvy=%i lvy=%i.\n", t->w->firstvisy, t->w->lastvisy);
}

#endif

/* -------- Creation and deletion. -------- */

BOOL txt1_inittextbuffer(txt t)
/* The buffer is initially set up as existing, but containing only termch. */
/* >>>> initial kludge: set up small buffer to prevent requirement
for extension. */
{
    t->top = 50;
    (void) flex_alloc((void**) &(t->buf), t->top+2);
    if (t->buf == 0) {
      tracef0("txt1_initt failed, no store.\n");
      return FALSE;
    };
    t->buf[t->top+1] = GUARDBYTE;

    t->gapstart = 0;
    t->gapend = t->top;
    t->txtstart = 0;
    t->buf[t->gapend] = 0; /* termch */

    /* use of donewmarker no good here because of invariant checks. */
    t->selstart.pos = t->gapend;
    t->selstart.next = NULL;
    t->selend.pos = t->gapend;
    t->selend.next = &t->selstart;
/*
    t->w->firstvis.pos = t->gapend;
    t->w->firstvis.next = &t->selend;
    t->w->lastvis.pos = t->gapend;
    t->w->lastvis.next = &t->w->firstvis;
    t->marksbefore = NULL;
    t->marksafter = &t->w->lastvis;

    t->w->firstvisy = 1;
    t->w->lastvisy = 1;
*/
    t->marksbefore = NULL;
    t->marksafter = &t->selend;

    t->calls = NULL;

    t->last_ref = 0;

    txt1__checkbufinvariant(t, "itb"); /*>*/

    return TRUE;
}
/* >>>> change things so that this routine cannot fail, e.g. doesn't call
flex. First buffer should be non-existent, or tiny at end of text
record. */

void txt1_disposetextbuffer(txt t)
{
    flex_free((flex_ptr) &t->buf);
}

static BOOL txt1__extendtextbuffer(txt t, txt1_bufindex newtop)
/* Based on a model whereby you don't have both available at the same
time, in case the underlying storage mechanisms improve... */
{
    txt1_imarker *m;

    if (newtop <= t->top) return TRUE;
    /* extendstorearea(t->buf, (t->top+2)*8, (newtop+2)*8); */
    if (! flex_extend((void**) &t->buf, newtop + 2)) {
      tracef0("txt1_extendtextbuffer: flex_extend fails.\n");
      return FALSE;
    };
    /* >>>> running-out-of-store case ignored. */
    if (t->gapstart <= t->gapend) {/* gap contiguous */
      memmove(
        /*to*/ &(t->buf[newtop - (t->top - t->gapend)]),
        /*from*/ &(t->buf[t->gapend]),
        1 + t->top - t->gapend);
      m = t->marksafter;
      while (m != NULL) {
        m->pos += newtop - t->top;
        m = m->next;
      };
      if (t->txtstart > t->gapend) t->txtstart += newtop - t->top;
      t->gapend += newtop - t->top;
    } else { /* gap discontiguous */
      /* no need to move things */
    };
    t->top = newtop;
    t->buf[t->top+1] = GUARDBYTE;
    txt1__checkbufinvariant(t, "etb");
    tracef0("buffer extended.");
#if TRACE
    txt1__pr(t);
#endif
    return TRUE;
}

/* >>>> if (we run out of store spuriously, what happens? this could
happen in any "insert" operation. hum. */

static int txt1__spaceavailable(txt t) /* size of gap */
{
    if (t->gapend >= t->gapstart) {
      return t->gapend - t->gapstart;
    } else {
      return 1 + t->top - (t->gapstart - t->gapend);
    };
}

static int txt1__ensurespace(txt t, int space)
/* Ensure that the gap leaves at least the specified amount of space,
extending if necessary. This may in fact not be possible, e.g. extension not
allowed and space required physically bigger than buffer. So, the return
value is equal to "space" if there's enough, else the amount of space there
actually is. */
{
  int gapsize;
  txt1_bufindex newtop;

    gapsize = txt1__spaceavailable(t);
    if (gapsize >= space) {
      return space;
    } else {
      if (t->oaction == txt_REFUSE) {
        /* take no action */
#if FALSE
      } else if (t->oaction == txt_CYCLE) {
        werr(TRUE, "Fatal: t1 cycle");
        txt1__deletefromfront(t, space-gapsize);
#endif
      } else { /* oaction == extend */
        if (t->top > 40000) /* increase by 20 percent, but cap at 8000 */
          newtop = t->top + 8000;
        else
          newtop = (t->top * 5) / 4;
        if (newtop < MINEXTENDEDTOP) newtop = MINEXTENDEDTOP;
        if (space > gapsize + (newtop - t->top)) {
          newtop = t->top + space - gapsize;
            /* >>>>? space - (t->top - gapsize); */
          if (newtop > 40000) /* increase by 20 percent, but cap at 8000 */
            newtop += 8000;
          else
            newtop = (newtop * 5) / 4;
        };
        txt1__extendtextbuffer(t, newtop);
      };
      return txt1__spaceavailable(t);
    };
}

/* -------- Option setting. -------- */

#ifndef UROM
int txt1_dobufsize(txt t)
{
  if (t->buf == 0) {return 0;} else {return t->top + 1;};
}
#endif

#ifndef UROM
BOOL txt1_dosetbufsize(txt t, int b) /* returns FALSE if can't. */
{
  return txt1__extendtextbuffer(t, b);
}
#endif

void txt1_dosetcharoptions(txt t,
  txt_charoption affect, txt_charoption values)
{
  txt_charoption prev;

    prev = t->charoptionset;
    t->charoptionset = (t->charoptionset & ~affect) | (affect & values);
    if ((affect & values) & txt_UPDATED) t->last_ref = 0;    /* buffer modified, so forget Message_DataSaved */
    if (0 != (txt_CARET & (prev ^ t->charoptionset))) {
      if (0 != (txt_CARET & t->charoptionset)) {
        t->w->rawshowcaret(t);
      } else {
        t->w->rawhidecaret(t);
      };
    };
    while (txt3_foreachwindow(t)) {
      t->w->donewcharoptions(t, prev);
      if (0 != (txt_DISPLAY & t->charoptionset) && 0 == (txt_DISPLAY & prev)) {
        txt1_redisplay(t, 1);
      };
    };
}

void txt1_dosetdisplayok(txt t) {
  /* We assume that the display is up to date. This is useful for swapping
  windows, for temporarily moving to the top/bot of the file to ensure
  that it's all one segment, etc. */
  t->charoptionset |= txt_DISPLAY;
}

/* -------- Iterators over segments of the array. -------- */

static BOOL txt1__segback(
  txt t,
  txt1_bufindex *start /*inout*/,
  int *n /*out*/)
/* "*start" is a charbufindex. If it's at the first char in the array then
leave *start,*n unchanged and return FALSE. otherwise, return TRUE and set
"*start" and "*n" with the biggest n such that segsize(*start)==*n, and
incbi(start, n) would get you back to the initial start. */
{
  txt1_bufindex newstart;

    txt1__assertcharbufindex(t, *start, "sb-1");
    if
      (*start==t->txtstart ||
        (*start==t->gapend && t->txtstart==t->gapstart)) {
      /* at start of array */
      return FALSE;
    } else {
      if (*start == t->gapend) *start = t->gapstart;
      if (*start == 0) *start = t->top+1;
      /* below start we could meet t->gapend or t->txtstart or 0 */
      newstart = 0;
      if (t->gapend < *start) newstart = t->gapend;
      if ((t->txtstart < *start) && (t->txtstart > newstart)) {
        newstart = t->txtstart;
      };
      /* newstart < start */
      *n = *start - newstart;
      *start = newstart;
      txt1__assertcharbufindex(t, *start, "sb-2");
      return TRUE;
    };
}

static BOOL txt1__segsize(txt t, txt1_bufindex start, int *n /*out*/)
/* "start" is a charbufindex. segsize returns the number of characters at and
beyond "start" in the buffer that are bona fide characters from the array.
Returns FALSE if "start" is at the end of the array. if it returns TRUE then
n>0. the resulting segment does not include termch. */
{
  txt1_bufindex seglim;

    txt1__assertcharbufindex(t, start, "sss");
    /* we could meet t->gapstart, or t->txtstart, or t->top. */
    if (start == txt1__termchbi(t)) {
      txt1__assert(t->buf[start] == 0, "sss-1");
      *n = 0;
      return FALSE;
    } else {
      seglim = t->top + 1; /* one beyond segment */
      if (t->txtstart == 0) {seglim = t->top;}; /* t->buf[t->top]==termch */
      if (t->gapstart > start) seglim = t->gapstart;
      if (t->txtstart > start && t->txtstart <= seglim) {
        seglim = t->txtstart-1; /* point at termch */
      };
      *n = seglim - start;
      return TRUE;
    };
}

void txt1_doarraysegment( /* public */
  txt t,
  txt_index at,
  char **a /*out*/,
  int *n /*out*/)
{
  txt1_bufindex b;

    b = txt1__indextobufindex(t, at);
    if (! txt1__segsize(t, b, n)) *n = 0;
    *a = &t->buf[b];
}

/* -------- Index and Bufindex arithmetic. -------- */

txt_index txt1__bufindextoindex(txt t, txt1_bufindex b)
/* the bufindex must be a charbufindex. */
{
  txt_index i;
  int segsize;

    /* last thing before b could be t->gapend, 0, t->txtstart */
    txt1__assertcharbufindex(t, b, "biti-1");
    i = 0;
    while (txt1__segback(t, &b, &segsize)) i += segsize;
    return i;
}

txt1_bufindex txt1__indextobufindex(txt t, txt_index i)
{
  txt1_bufindex at;
  int n;

  /* huge index possible (e.g. 0x7fffffff), seems ok. */
    /* start at bufstart, you could meet t->gapstart or t->top or i */
    at = txt1__firstchbi(t);
    while (txt1__segsize(t, at, &n)) {
      if (n > i) {/* got there */
        return at + i;
      } else { /* still going */
        i -= n;
        txt1__incbi(t, &at, n);
      };
    };
    /* got to the end of the array, didn't reach i. thus, return
    the maximum possible bufindex. */
    return at;

  txt1__checkbufinvariant(t, "itbi");
}

void txt1__incrawbi(txt t, txt1_bufindex *bi /*inout*/, int n)
/* Increment a bufindex, wrapping round at top but ignoring the
gap. */
{
    *bi += n;
    if (*bi > t->top) *bi -= t->top+1;

  /* The bufinvariants to not necessarily hold at this point.
  e.g. consider use within domovedot, dodelete. */
}

static void txt1__decrawbi(txt t, txt1_bufindex *bi /*inout*/, int n)
/* decrement bufindex, wrapping round at the bottom but ignoring
the gap. */
{
    if (*bi < n) bi += t->top+1;
    *bi -= n;

  /* the bufinvariants to not necessarily hold at this point.
  e.g. consider use within domovedot, dodelete. */
}

void txt1__incbi(txt t, txt1_bufindex *i /*inout*/, int n)
/* i is a charbufindex. increment it, keeping things that way. If you hit the
end of the array, stick there. */
{
  int segsize;

    txt1__assertcharbufindex(t, *i, "inbi-1");
    while ((n!=0) && txt1__segsize(t, *i, &segsize)) {
      if (n < segsize) {
        *i += n;
        txt1__assertcharbufindex(t, *i, "inbi-2");
        return;
      } else { /* more complex */
        *i += segsize; /* no longer bona fide */
        n -= segsize;
        if (*i > t->top) *i = 0;
        if (*i == t->txtstart) {/* we just overflowed! */
          *i = txt1__termchbi(t);
          n = 0;
        };
        if (*i == t->gapstart) *i = t->gapend;
      };
    };
    txt1__assertcharbufindex(t, *i, "inbi-3");
}

static void txt1__decbi(txt t, txt1_bufindex *i /*inout*/, int n)
{
  txt1_bufindex segstart;
  int segsize;

    while (1) {
      if (n == 0) break;
      segstart = *i;
      if (! txt1__segback(t, &segstart, &segsize)) {
        /* i is correct now */
        break;
      };
      if (segsize >= n) {
        *i = segstart + segsize - n;
        break;
      } else {
        n -= segsize;
        *i = segstart;
        /* and loop */
      };
    };
}

txt1_bufindex txt1__termchbi(txt t)
/* returns the bufindex of termch. */
{
    if (t->txtstart == 0) {return t->top;} else {return t->txtstart-1;};
}

txt1_bufindex txt1__firstchbi(txt t)
/* returns the bufindex of the first char in the array. */
{
    if (t->gapstart == t->txtstart) {
      return t->gapend;
    } else {
      return t->txtstart;
    };
}

static BOOL txt1__lessthanbi(txt t, txt1_bufindex a, txt1_bufindex b)
{
    if ((a < t->txtstart) == (b < t->txtstart)) {
      return a < b;
    } else {
      return b < a;
    };
}

BOOL txt1__lessoreqbi(txt t, txt1_bufindex a, txt1_bufindex b)
{
    if (a == b) {
      return TRUE;
    } else if ((a < t->txtstart) == (b < t->txtstart)) {
      return a < b;
    } else {
      return b < a;
    };
}

/* -------- Public operations on the array of characters. -------- */

txt_index txt1_dodot(txt t)
{
  int result;

    result = t->gapstart - t->txtstart;
    if (result < 0) result += t->top;
    return result;
}

txt_index txt1_dosize(txt t)
{
    if (t->gapend >= t->gapstart) {/* gap contiguous or null */
      return t->top - (t->gapend - t->gapstart);
    } else {
      return (t->gapstart - t->gapend) - 1;
    };
}

void txt1_dosetdot(txt t, txt_index to)
{
  if (to > 100000000) {/* problem with range conversion! */
    /* e.g. use of 0x7fffffff to get to end */
    to = 100000000;
  };
  txt1_domovedot(t, to - txt1__bufindextoindex(t, t->gapend));
}

void txt1_domovedot(txt t, int by)
/* movedot involves (potentially) moving the gap in the buffer. It will not
affect the display, except (a) the caret could move, and (b) if we're
displaying and the result is off the display area then we must
redisplay/scroll. */
{
  int saveby;
  int n;
  int tomove;
  txt1_bufindex from;
  txt1_imarker *marker;

    tracef1("domovedot %i.\n", by);
    txt1__assert(t->w == t->windows[1], "md-3");

    /* If by==0, or other values which still cause nothing to happen
    (because of begin/end of array) we must still wiggle the caret,
    because of caretoffset. */

    /* save undo information */
    txtundo_putnumber(t->undostate, txt1__bufindextoindex(t, t->gapend));
    txtundo_putcode(t->undostate, 'm');

    /* update the text buffer, by moving the gap. */
    saveby = 0; /* dist actually moved, for display */
    if (by < 0) {
      /* we must move backwards to get to "to" */
      /* this means copying chars up, so that the gap moves down */
      from = t->gapend;
      tomove = -by;
      while ((tomove>0) && txt1__segback(t, &from, &n)) {
        if (n > tomove) {
          from += n-tomove;
          n = tomove;
        };
        if (t->gapend == 0) {t->gapend = t->top+1;};
        if (t->gapend < t->gapstart) {/* gap is discontiguous */
          if (n > t->gapend) {
            /* we can't move all that at once */
            from += n - t->gapend;
            n = t->gapend;
          };
        };
        if ((t->gapstart == 0) && (t->gapend > 0) && (n > t->gapend)) {
          /* the move jumps over the end, so gapsize is the maximum
          that we can move */
          /* >>>> rather a kludge, think through this. */
          /*      compare with deletefromfront, for instance. */
          n = t->gapend;
        };
        txt1__decrawbi(t, &t->gapstart, n);
        txt1__decrawbi(t, &t->gapend, n);
          /* will ensure t->gapend is normalised */
        memmove(
          /*to*/ &(t->buf[t->gapend]),
          /*from*/ &(t->buf[t->gapstart]),
          n);
        tomove -= n;
        saveby -= n;
        from = t->gapend;
        while (/* move markers */
          (t->marksbefore != NULL) &&
          (t->marksbefore->pos >= t->gapstart) &&
          (t->marksbefore->pos < t->gapstart+n)
        ) {
          /* move the marker from the before list to the after list */
          marker = t->marksbefore;
          t->marksbefore = marker->next;
          marker->next = t->marksafter;
          t->marksafter = marker;
          marker->pos -= t->gapstart; /* still +ve */
          marker->pos += t->gapend;
        };
        txt1__checkbufinvariant(t, "md-1");
      };
    } else {
      /* by >= 0 */
      /* we must move forwards to get to "to" */
      /* this means copying chars) {wn, so that the gap moves up */
      tomove = by;
      while (tomove>0 && txt1__segsize(t, t->gapend, &n)) {
        /* contiguous chunk at t->gapend, of n bytes */
        if (tomove < n) n = tomove;
        if (t->gapend < t->gapstart) { /* gap is discontiguous */
          /* >>>> && t->gapend!=0 extra exclusion, surely spurious? */
          if (n > (1+t->top-t->gapstart)) {/* can't fit that many */
            n = 1+t->top-t->gapstart;
          };
        };
        while (/* move markers */
          (t->marksafter != NULL) &&
          (t->marksafter->pos >= t->gapend) &&
          (t->marksafter->pos < t->gapend + n)
       ) {
          /* move the marker from the after list to the before list */
          marker = t->marksafter;
          t->marksafter = marker->next;
          marker->next = t->marksbefore;
          t->marksbefore = marker;
          marker->pos -= t->gapend; /* still +ve */
          marker->pos += t->gapstart;
        };
        memmove(
          /*to*/ &(t->buf[t->gapstart]),
          /*from*/ &(t->buf[t->gapend]),
          n);
        txt1__incrawbi(t, &t->gapstart, n);
        txt1__incrawbi(t, &t->gapend, n);
        tomove -= n;
        saveby += n;
        txt1__checkbufinvariant(t, "md-2");
      };
    };
    txt1_domovemarker(t, &(t->w->caret), txt1_dodot(t));
    txt1__ensuredotvisible(t, saveby);

  txt1__checkbufinvariant(t, "dmd");
}

void txt1_doinsertchar(txt t, char c)
{
  txt1_doreplacechars(t, 0, &c, 1);
}

void txt1_doinsertstring(txt t, char *s)
{
  txt1_doreplacechars(t, 0, s, strlen(s));
}

static void txt1__dodeletebufferstuff(txt t, int n)
/* Deletion causes the gap to get bigger. */
{
  txt1_imarker *m;
  txt1_bufindex oldgapend;
  int delsize;
  int segsize;

    /* For undoing the selection: if either endpoint of the selection
    is within the deleted portion, then we need to save the exact position
    of the selection in the undo buffer. */
    {
      txt_index selstart = txt1__bufindextoindex(t, t->selstart.pos);
      txt_index selend = txt1__bufindextoindex(t, t->selend.pos);
      txt_index dot = txt1_dodot(t);
      if (selstart != selend) { /* only important if selection set. */
        if ((selstart >= dot && selstart <= dot+n)
        || (selend >= dot && selend <= dot+n)) {
          txtundo_putnumber(t->undostate, selstart);
          txtundo_putnumber(t->undostate, selend);
          txtundo_putcode(t->undostate, 'l');
        };
      };
    };

    /* updates to the text buffer */
    while ((n>0) && txt1__segsize(t, t->gapend, &segsize)) {
      delsize = txt1__min(n, segsize);
      oldgapend = t->gapend;
      txtundo_putbytes(t->undostate, &(t->buf[t->gapend]), delsize);
      txtundo_putnumber(t->undostate, delsize);
      txtundo_putcode(t->undostate, 'i');
      txt1__incrawbi(t, &t->gapend, delsize);
      n -= delsize;
      m = t->marksafter;
      while (/* deal with markers */
        (m != NULL) &&
        (m->pos >= oldgapend) &&
        (m->pos < oldgapend + delsize)
      ) {
        m->pos = t->gapend;
        m = m->next;
      };
    };

  txt1__checkbufinvariant(t, "ddbs");
}

void txt1_doreplacechars(txt t, int ntodelete, char *a, int n)
/* Insertion of characters in the buffer causes the gap to reduce in size,
and can lead to extension being necessary. Display changes are generated
directly, to reduce redraw and flicker. */
/* KJB Oct 2002: Can now pass a null pointer to fill with spaces */
{
  txt1_bufindex gapsegbase;
  int gapsegsize;
  int n1;
  int saven;
#if TRACE
  BOOL dump;
#endif
  char *s;
  int nspaces;
  char *spaces;
  txt1_bufindex b;
  txt1_imarker *m;

    txt1__assert(t->w == t->windows[1], "drc-1");

    if ((ntodelete == 0) && (n == 0)) {
      if ((t->w->caretoffsetx != 0) || (t->w->caretoffsety != 0)) {
        txt1__hidecaret(t);
        t->w->caretoffsetx = 0;
        t->w->caretoffsety = 0;
        txt1__showcaret(t);
      };
      return;
    };

    if (t->w->caretoffsetx > 0
    && (t->gapend == txt1__termchbi(t) || t->buf[t->gapend] == '\n')
    && 0 != (txt_DISPLAY & t->charoptionset)
    ) {
      /* he is sticking out at the end of a line. */
      ntodelete = 0; /* deletion is ignored in this case */
      if (n == 0) return; /* teeny visual bug: should show caret */
      nspaces = t->w->caretoffsetx / txt1__spacewidth(t);
      tracef1("pad insertion with %i spaces.\n", nspaces);
      t->w->caretoffsetx = 0;
      t->w->caretoffsety = 0;
      spaces = "                                        "; /* 40 of them */
      while (nspaces > 0) {
        txt1_doreplacechars(t, 0, spaces, txt1__min(40, nspaces));
        txt1_domovedot(t, txt1__min(40, nspaces));
        nspaces -= 40;
      };
    } else {
      t->w->caretoffsetx = 0;
      /* t->w->caretoffsety is left as it is for now. This is picked up by
      displayreplace2, in order to catch the case where you insert/delete
      at the front of a split line. */
    };

#if TRACE
      /* debugging printout if inserting a lone ^q */
      s = a;
      dump = (n==1) && (s!=NULL) && (*s==17);
      if (dump) {txt1__pr(t); txtundo_pr(t->undostate); return;};
#endif

    /* the changes to the text buffer */
    t->charoptionset |= txt_UPDATED;
    t->last_ref = 0;                    /* ignore subsequent DataSaved message */

    /* Strip identical chars from end of insertion and deletion.
    Some of the displayreplace stuff assumes that both do not end in
    newlines. */
    if (ntodelete > 0) {
      b = t->gapend;
      txt1__incbi(t, &b, ntodelete-1); /* points at last char to be deleted */
      s = a;
      while (1) {
        if (ntodelete == 0) break;
        if (n == 0) break;
        if (t->buf[b] != (s==NULL) ? ' ' : s[n-1]) break;
        /* last inserted == last deleted: so, don't touch either. */
        txt1__decbi(t, &b, 1);
        n--;
        ntodelete--;
      };
    };

    /* measure the stuff to be deleted */
    while (txt3_foreachwindow(t)) {
      txt1__displayreplace1(t, ntodelete);
    };
    /* and delete it */
    txt1__dodeletebufferstuff(t, ntodelete);

    n1 = txt1__ensurespace(t, n);
    if (n1 < n) {
      /* there's not enough space. drop the first few chars,
      rather than the last few. */
      werr(FALSE, msgs_lookup(MSGS_txt48));
      if (a) a += n-n1;
      n = n1;
    };
    saven = n;

    /* insert the new chars into the text buffer. */
    while (n > 0) {
      if (t->gapend == 0) {
        t->gapend = t->top+1;
        m = t->marksafter;
        while ((m != NULL) && (m->pos == 0)) {
          m->pos = t->top+1;
          m = m->next;
        };
      };
      gapsegbase = 0;
      if (t->gapstart < t->gapend) gapsegbase = t->gapstart;
      gapsegsize = t->gapend - gapsegbase;
      if (gapsegsize > n) {
        gapsegsize = n;
      };
      m = t->marksafter;
      while ((m != NULL) && (m->pos == t->gapend)) {
        m->pos -= gapsegsize;
        m = m->next;
      };
      t->gapend -= gapsegsize;
      n -= gapsegsize;
      if (a)
        memmove(&(t->buf[t->gapend]), a, gapsegsize);
      else
        memset(&(t->buf[t->gapend]), ' ', gapsegsize);
      /* KJB - surely a should be incremented here? */
      txtundo_putnumber(t->undostate, gapsegsize);
      txtundo_putcode(t->undostate, 'd');
    };

    /* the changes to the display */
    while (txt3_foreachwindow(t)) {
      if (t->w->lastvis.pos == t->gapend) {
        txt1_domovemarker(
          t, &(t->w->lastvis), txt1__bufindextoindex(t, t->gapend) + saven);
      };
      txt1__displayreplace2(t, saven, ntodelete);
    };
    /* The lastvis adjustment above is definitely what is required for
    insertion at the end of the file. but, it's not correct in other
    curcumstances where the replace intersects lastvis. clearly, this
    could result in lastvis being anywhere within the replaced section.
    in such a case displayreplace2 ends up calling displayfrom, and
    all is well. */

  txt1__checkbufinvariant(t, "drc");

#if TRACE
    if (dump) txt1__pr(t);
#endif
}

void txt1_dodelete(txt t, int n)
{
  txt1_doreplacechars(t, n, NULL, 0);
}

char txt1_docharatdot(txt t)
{
    return t->buf[t->gapend];
}

char txt1_docharat(txt t, txt_index i)
{
    return t->buf[txt1__indextobufindex(t, i)];
}

#ifndef UROM
void txt1_docharsatdot(
  txt t,
  char *a,
  int *n /* inout */)
{
  txt1_bufindex from;
  int at;
  int todo;
  int segsize;
  int copysize;

    from = t->gapend;
    at = 0; /* index into a */
    todo = *n;
    while ((todo>0) && txt1__segsize(t, from, &segsize)) {
      copysize = txt1__min(segsize, todo);
      memmove(/*to*/ a, /*from*/ &(t->buf[from]), copysize);
      todo -= copysize;
      a += copysize;
      txt1__incbi(t, &from, segsize);
    };
    n -= todo;

  txt1__checkbufinvariant(t, "dcsa");
}
#endif

void txt1_doreplaceatend(txt t, int ntodelete, char *buffer, int n) {
  BOOL simple =(t->charoptionset && txt_DISPLAY) == 0;
  /* Not even displayed is the simplest case of all. */
  txt_index dot = txt1_dodot(t);
  if (ntodelete > txt1_dosize(t)) {
    ntodelete = txt1_dosize(t);
  };
  if (! simple) {
    while (txt3_foreachwindow(t)) {
      if (t->w->lastvis.pos == txt1__termchbi(t)) {
        simple = TRUE;
      };
    };
  };
  /* We take the !simple route only if displaying,
  but no window is displaying the tail of the file. */
  if (! simple) t->charoptionset &= ~txt_DISPLAY;
  txt1_dosetdot(t, txt1_dosize(t) - ntodelete);
  txt1_doreplacechars(t, ntodelete, buffer, n);
  txt1_dosetdot(t, dot);
  if (! simple) {
    t->charoptionset |= txt_DISPLAY;
    /* We assert that the display is already
    correct. */
    while (txt3_foreachwindow(t)) {
      txt1__updatescrollbar(t);
    };
  };
}

void txt1_domovevertical(txt t, int by, BOOL caretstill)
/* >>>> this is pretty rhunic, the stuff about caretoffset is a little out of
control. t->w->caretoffsety can only be 0 or t->w->linesep, the latter case
for when you're at a line break, and wish to display the cursor at the start
of the succuessor line rather than the end of the previous one. */
{
  txt1_zits x;
  txt1_zits y;
  txt1_zits y1;
  txt1_zits keepcaretx;
  txt1_bufindex at;
  BOOL caret;

    tracef2("domovevertical %i %i.\n", by, caretstill);

    if (caretstill) {txt1_scrollbarmoveby(t, by); return;};
    x = t->w->caretx;
    y = t->w->carety;
    if (t->w->caretoffsety != 0) {
      x += t->w->caretoffsetx;
      y += t->w->caretoffsety;
    };
    keepcaretx = t->w->caretx + t->w->caretoffsetx;
    at = t->gapend;
    y1 = y + by * t->w->linesep;
    if (by == 0) return;
    caret = 0 != (txt_CARET & t->charoptionset);
    txt1__hidecaret(t);
    t->charoptionset &= ~txt_CARET;
    if (by > 0) {
      txt1__measure(t, &x, &y, y1, &at, txt1__termchbi(t), FALSE);
    } else {
      if (! txt1__measureback(t, &x, &y, y1, &at, txt1__firstchbi(t), FALSE)) {
        tracef0("first measureback failed.\n");
        y -= t->w->caretoffsety;
        (void) txt1__measureback(t, &x, &y, y1, &at, txt1__firstchbi(t), FALSE);
      };
    };
    txt1__cancelallcalls(t); /* should be superfluous! */
    txt1__horizmeasure(t, x, t->w->caretx + t->w->caretoffsetx, &at);
    if (
       0 == (txt_DISPLAY & t->charoptionset)
    || (abs(by) < (3 * t->w->limy) / (4 * t->w->linesep))) {
      /* could end up doing on-screen block copies */
      tracef0("movevertical is near.\n");
      txt1_dosetdot(t, txt1__bufindextoindex(t, at));
    } else {
      /* Moving by almost a page, rather force a redraw and keep
      cursor in the same place. */
      tracef0("movevertical is far.\n");
      t->charoptionset &= ~txt_DISPLAY;
      txt1_dosetdot(t, txt1__bufindextoindex(t, at));
      t->charoptionset |= txt_DISPLAY;
      txt1__redisplaytext(t, TRUE);
    };
    if ((keepcaretx == 0)
    && txt1__dotatlinebreak(t)
    ) {
      /* He has landed at a linebreak, and placed himself at the end
      of the previous line. x will stay right (at the front of a line)
      but we must advance y. */
      t->w->caretoffsety = t->w->linesep;
    } else {
      t->w->caretoffsety = 0;
    };
    t->w->caretoffsetx = keepcaretx - t->w->caretx;
    tracef4("caretx/y=%i,%i caretoffsetx=%i,y=%i.\n",
      t->w->caretx, t->w->carety, t->w->caretoffsetx, t->w->caretoffsety);
    if (caret) t->charoptionset |= txt_CARET;
    txt1__showcaret(t);

  txt1__checkbufinvariant(t, "dmv");
}

static txt1_zits txt1__measurechar(txt t, char c)
{
  char ar[4];
  char *a;
  int n;
  txt1_zits width;

    ar[0] = c;
    a = &(ar[0]);
    n = 1;
    width = INT_MAX;
    t->w->rawmeasure(t, &a, &n, &width);
    tracef1("charwidth = %i.\n", INT_MAX - width);
    return INT_MAX - width;
}

BOOL txt1__dotatlinebreak(txt t)
/* TRUE if caret is at the break of two display lines in the same text line. */
{
    return (t->buf[t->gapend] != '\n')
    && (t->gapend != txt1__termchbi(t))
    && (txt1__measurechar(t, t->buf[t->gapend]) > t->w->limx - t->w->caretx);
}

txt1_zits txt1__spacewidth(txt t)
{
  return txt1__measurechar(t, ' ');
}

void txt1_domovehorizontal(txt t, int by)
{
  int i;
  BOOL caret;
  txt1_zits spacewidth;

    txt1__hidecaret(t);
    caret = 0 != (txt_CARET & t->charoptionset);
    t->charoptionset &= ~txt_CARET;
    spacewidth = txt1__spacewidth(t);
    for (i = 1; i <= abs(by); i++) {
      if (((t->w->caretoffsetx > 0) || ((t->w->caretoffsetx == 0) && (by > 0)))
      && ((t->gapend == txt1__termchbi(t)) || (t->buf[t->gapend] == '\n'))
      && (t->w->caretoffsetx + t->w->caretx + by*spacewidth <= t->w->limx)
      ) {
        /* he is sticking out at the end of a line. */
        tracef0("horiz movement.\n");
        t->w->caretoffsetx = txt1__max(0, t->w->caretoffsetx + by*spacewidth);
        by = 0; /* prevent further looping. */
      } else {
        tracef0("no horiz movement.\n");
        /* domovedot, with one funny case. */
        if (by > 0) {
          txt1_domovedot(t, 1);
        } else {
          txt1_domovedot(t, -1);
          if (txt1__dotatlinebreak(t)) {
            /* retreat to line break: be at start of following line */
            t->w->caretoffsetx = - t->w->caretx;
            t->w->caretoffsety = t->w->linesep;
          };
        };
      };
    };
    if (caret) {
      t->charoptionset |= txt_CARET;
    };
    txt1__showcaret(t);
}
/* >>>> Slightly funny on the last line of the file. Some way of making
nothing happen if you're beyond the end of the file? or insert '\n's?
Hum, seems a lot of work to do it all properly. */

/* -------- Line operations. -------- */

static txt1_bufindex txt1__startofline(txt t, txt1_bufindex containing)
{
  txt1_bufindex from;
  txt1_bufindex i;
  int n;

    while (1) {
      from = containing;
      if (txt1__segback(t, &from, &n)) {
        if (t->buf[from+n-1] == '\n') {return containing;} else {
          for (i=n; i>=2; i--) {
            if (t->buf[from+i-2] == '\n') {return from+i-1;};
          };
          containing = from;
        };
      } else {
        return from;
      };
    };
}

static txt1_bufindex txt1__startofreasonableline(txt t, txt1_bufindex containing)
/* An attempt to prevent hassles about very long lines causing long
delays. after maxreasonableline we give up, and stop at the next multiple
of maxreasonableline within the file. this will give a constant stopping
point, e.g. if we move around a lot. */
/* Truely correct implementation is the same as startofline. */
{
  txt1_bufindex from;
  txt1_bufindex i;
  txt1_bufindex cutoff;
  int n;
  int count;
  txt_index index;
#define MAXREASONABLELINE 1024

    count = 0;
    cutoff = txt1__firstchbi(t);
    while (1) {
      from = containing;
      if (txt1__segback(t, &from, &n)) {
        if (t->buf[from+n-1] == '\n') {return containing;} else {
          for (i=n; i>=2; i--) {
            if (t->buf[from+i-2] == '\n') {return from+i-1;};
            if (from+i-1 == cutoff) {
              tracef0("startofreasonableline gave up.\n");
              return from+i-1;
            };
            count++;
            if (count > MAXREASONABLELINE) {
              /* get impatient */
              index = txt1__bufindextoindex(t, from+i-2);
                /* where we are now */
              index -= index % MAXREASONABLELINE;
              cutoff = txt1__indextobufindex(t, index);
            };
          };
          containing = from;
        };
      } else {
        return from;
      };
    };
}

static txt1_bufindex txt1__nextlineend(txt t, txt1_bufindex containing)
/* if pointing at a '\n', returns with the same value. Has to
be quite fast, so the critical part of the loop has no procedure
calls. */
{
  int n;

    txt1__assertcharbufindex(t, containing, "nle-1");
    if (! txt1__segsize(t, containing, &n)) return containing;
    while (1) {
      if (t->buf[containing] == '\n') return containing;
      if (n != 1) {
        containing++;
        n--;
      } else {
        txt1__incbi(t, &containing, 1);
        if (! txt1__segsize(t, containing, &n)) return containing;
      };
    };
}

/* -------- Operations on markers. -------- */

void txt1_donewmarker(txt t, txt1_imarker *addr)
{
    addr->next = t->marksafter;
    addr->pos = t->gapend;
    t->marksafter = addr;

  txt1__checkbufinvariant(t, "dnm");
}

#if TRACE
void txt1__badmarker(char *s)
{
  txt1__yell("bad marker: ", s);
}
#endif

void txt1_domovemarker(txt t, txt1_imarker *addr, txt_index to)
{
    txt1__movemarker(t, addr, txt1__indextobufindex(t, to));
}

void txt1_domovedottomarker(txt t, txt1_imarker *addr)
{
#if TRACE
    if (addr->pos > t->top) {/* simple consistency check */
      txt1__badmarker("movedottomarker");
    };
#endif
   txt1_dosetdot(t, txt1__bufindextoindex(t, addr->pos));

  txt1__checkbufinvariant(t, "ddtm");
}

txt_index txt1_doindexofmarker(txt t, txt1_imarker *addr)
{
#if TRACE
    if (addr->pos > t->top) txt1__badmarker("indexofmarker");
#endif
    return txt1__bufindextoindex(t, addr->pos);
}

void txt1_dodisposemarker(txt t, txt1_imarker *addr)
/* need to search down the marker chains to find this guy. */
{
  txt1__deletemarker(t, addr);
  addr->next = NULL;
  addr->pos = INT_MAX;

  txt1__checkbufinvariant(t, "ddm");
}

static txt1_imarker **txt1__findmarker(txt t, txt1_imarker *m, txt1_imarker **p)
{
    t=t;
    while (1) {
#if TRACE
      if (*p == NULL) {
        /* the marker isn't there: probably a client marker,
        moving/deleting a marker that isn't there. */
        txt1__badmarker("move/deletemarker");
      };
#endif
      if (*p == m) break;
      p = &((*p)->next);
    };
    return p;
}

void txt1__deletemarker(txt t, txt1_imarker *m)
{
  txt1_imarker **deleteat;

    /* decide where to delete */
    if (txt1__lessoreqbi(t, t->gapend, m->pos)) {
      deleteat = txt1__findmarker(t, m, &(t->marksafter));
    } else {
      deleteat = txt1__findmarker(t, m, &(t->marksbefore));
    };
    txt1__assert(*deleteat == m, "dm-1");

    *deleteat = m->next; /* perform the deletion */

    txt1__checkbufinvariant(t, "dm-2");
}

static txt1_imarker **txt1__findplacebefore(txt t, txt1_bufindex b, txt1_imarker **p)
/* find the right place to insert a marker that wishes to be at i. */
{
    while (1) {
      if (*p == NULL) break;
      if (txt1__lessoreqbi(t, (*p)->pos, b)) break;
      p = &((*p)->next);
    };
    return p;
}

static txt1_imarker **txt1__findplaceafter(txt t, txt1_bufindex b, txt1_imarker **p)
/* find the right place to insert a marker that wishes to be at b. */
{
    while (1) {
      if (*p == NULL) break;
      if (txt1__lessoreqbi(t, b, (*p)->pos)) break;
      p = &((*p)->next);
    };
    return p;
}

static void txt1__insertmarker(txt t, txt1_imarker *m)
{
  txt1_imarker **insertat;

    /* decide where to insert */
    if (txt1__lessoreqbi(t, t->gapend, m->pos)) {
      insertat = txt1__findplaceafter(t, m->pos, &(t->marksafter));
    } else {
      insertat = txt1__findplacebefore(t, m->pos, &(t->marksbefore));
    };

    m->next = *insertat; /* perform the insertion */
    *insertat = m;

    txt1__checkbufinvariant(t, "im-1");
}

void txt1__movemarker(txt t, txt1_imarker *m, txt1_bufindex newpos)
/* Move the marker from its current position, to the indicated new one. This
may involve moving it around in the chains of markers, as appropriate. This
is quite slow, but is necessary for keeping track of selection and scroll bar
stuff. */
{
  if (m->pos == newpos) return; /* shortcut */
  tracef2("movemarker from=%i to=%i\n", m->pos, newpos);

  txt1__deletemarker(t, m); /* cut out from the lists */
  m->pos = newpos; /* update the position */
  txt1__insertmarker(t, m); /* put back into the lists */

  txt1__checkbufinvariant(t, "mm-1");
}

/* -------- Operations on the selection. -------- */

BOOL txt1_doselectset(txt t)
{
    return t->selstart.pos != t->selend.pos;
}

txt_index txt1_doselectstart(txt t)
{
    return txt1__bufindextoindex(t, t->selstart.pos);
}

txt_index txt1_doselectend(txt t)
{
    return txt1__bufindextoindex(t, t->selend.pos);
}

void txt1__redisplayselectrange(txt t, txt1_bufindex from, txt1_bufindex to);
/* forward reference */

static void txt1__order(txt_index *a, txt_index *b)
{
  txt_index temp;
  if (*a > *b) {
    temp = *a;
    *a = *b;
    *b = temp;
  };
}

void txt1_dosetselect(txt t, txt_index start, txt_index end)
/* It turns out that we have four markers, giving the old and new positions
of the selection. Regardless of their identity we should redisplay the first
and last section defined by these. */
{
  txt_index a[5]; /* 1..4 used */

    txt1__order(&start, &end);
    a[1] = start;
    a[2] = end;
    a[3] = txt1__bufindextoindex(t, t->selstart.pos);
    a[4] = txt1__bufindextoindex(t, t->selend.pos);

    /* Spot obvious null calls, so as not to clog up the undo buffer. */
    {
      BOOL wasnull = a[3] == a[4];
      BOOL isnull = start == end;
      if ((wasnull && isnull)
      || (start == a[3] && end == a[4])) {
        tracef0("null setting of selection.\n");
        return;
      };
    };

    /* record the change in the undo buffer. */
    txtundo_putnumber(t->undostate, a[3]);
    txtundo_putnumber(t->undostate, a[4]);
    txtundo_putcode(t->undostate, 'l');

    txt1_domovemarker(t, &(t->selstart), start); /* no redisplay happens */
    txt1_domovemarker(t, &(t->selend), end);
    /* sort the pointers */
    txt1__order(&a[3], &a[4]);
    txt1__order(&a[2], &a[3]);
    txt1__order(&a[1], &a[2]);
    txt1__order(&a[3], &a[4]);
    txt1__order(&a[2], &a[3]);
    txt1__order(&a[3], &a[4]);
    /* and redisplay 1..2, 3..4 */
    while (txt3_foreachwindow(t)) {
      txt1__redisplayselectrange(t,
        txt1__indextobufindex(t, a[1]),
        txt1__indextobufindex(t, a[2]));
      txt1__redisplayselectrange(t,
        txt1__indextobufindex(t, a[3]),
        txt1__indextobufindex(t, a[4]));
    };

  txt1__checkbufinvariant(t, "dses");
}

static BOOL txt1__withinselect(txt t, txt1_bufindex at, int *n /*out*/)
/* Returns TRUE if the char at bufindex is within the selection, else FALSE.
In addition to this, tells you (at least) how many subsequent characters (>=
1 unless we are at termch) are the same as this one. */
{
    if (! txt1__segsize(t, at, n)) return FALSE; /* end of array */
    if (txt1__lessthanbi(t, at, t->selstart.pos)) { /* before select */
      if ((t->selstart.pos >= at) && (t->selstart.pos < at + *n)) {
        *n = t->selstart.pos - at;
      };
      return FALSE;
    } else if (txt1__lessthanbi(t, at, t->selend.pos)) {/* within select */
      if (t->selend.pos >= at && t->selend.pos < at + *n) {
        *n = t->selend.pos - at;
      };
      return TRUE;
    } else { /* after select */
      return FALSE;
    };
}

/* ======== Display. ======== */

/* the editing operations are written to update the display as they go along,
if (the display bit is set. a more general model providing an arbitrary
redisplay after arbitrary edits is (sadly) much more difficult to arrange. */

/* -------- Basic operations. -------- */

static void txt1__paintcall(
  txt t, txt1_zits x, txt1_zits y, char *ad, int n, txt1_zits width,
  BOOL highlight, txt1_callendopt callendopt)
/* Well don't actually do it, but add it to the list of pending calls. */
/* >>>> Limit the number of calls? to how many? 3*no of lines perhaps? */
{
  txt1_call *c = malloc(sizeof(txt1_call));
  if (c == NULL) {
    werr(TRUE, msgs_lookup(MSGS_txt49));
  }
  c->x = x;
  c->y = y;
  c->ad = ad;
  c->n = n;
  c->width = width;
  c->highlight = highlight;
  c->callendopt = callendopt;
  c->next = t->calls;
  t->calls = c;
}

static void txt1__reverseorderofcalls(txt t)
/* standard reverse-in-place of a singly linked list. */
{
  txt1_call *forw;
  txt1_call *back;
  txt1_call *temp;

    forw = t->calls;
    back = NULL;
    while (forw != NULL) {
      temp = forw;
      forw = temp->next;
      temp->next = back;
      back = temp;
    };
    t->calls = back;
}

static void txt1__sortandreversecalls(txt t)
/* An in-place bubble-sort, on the assumption that things are already
pretty well sorted. */
{
  txt1_call *forw;
  txt1_call *back;
  txt1_call *temp;
  txt1_call *temp1;
  txt1_call *temp2;

  forw = t->calls;
  back = NULL;
  if (forw == NULL) return;
  while (1) {
    txt1__assert(forw != NULL, "sarc-1");
    /* assert: all on back and one on forw are sorted */

    /* move forward one call */
    temp = forw;
    forw = forw->next;
    temp->next = back;
    back = temp;

    txt1__assert(back != NULL, "sarc-2");
    /* assert: all calls on "back" are sorted */
    if (forw == NULL) break;

    while ((back != NULL)
    &&
      /* not in good order */
      ((back->y < forw->y) ||
       ((back->y == forw->y) && (back->x < forw->x)))
    ) {

      /* swap these two over */
      tracef0("sarc-swap.\n");
      temp1 = forw->next;
      temp2 = back->next;
      temp = forw;
      forw = back;
      back = temp;
      forw->next = temp1;
      back->next = temp2;

      /* move back one call */
      temp = back;
      back = back->next;
      temp->next = forw;
      forw = temp;

    };

  };
  t->calls = back;
}

static void txt1__paintallcalls(txt t)
/* Actually perform the stored-up paint calls. */
{
  txt1_call *c;

  txt1__sortandreversecalls(t); /* see comments below */
  t->w->rawpaintseveral(t, t->calls, FALSE); /* do the painting */
  /* and dispose of the call records */
  while (t->calls != NULL) {
    c = t->calls;
    t->calls = c->next;
    free(c);
  };
}
/* Calls tend to be built up from the cursor backwards, then from the cursor
forwards. If the former set of calls is reversed before the latter operation,
this brings the calls for the cursor line into one place. Reversing them
again means that the calls are encountered left->right on the cursor line.
This is a considerable help to sys-dep paint systems which wish to combine
such calls into a single one, for performance and to improve handling of
italic fonts. */

/* The sortandreversecalls handles any funny cases that mess this up, e.g. a
selection just before the cursor and multi-line text lines before the cursor.
this means we are absolutely sure that calls are generated in the right
order. The system-dependent stuff can use this in worrying about italics etc.
*/

static void txt1__invertallcalls(txt t)
/* Similar to the above, with alreadycorrect TRUE. */
/* >>>> Common them up instead of this duplication! */
{
  txt1_call *c;

    txt1__sortandreversecalls(t);
    t->w->rawpaintseveral(t, t->calls, TRUE);
    /* and dispose of the call records */
    while (t->calls != NULL) {
      c = t->calls;
      t->calls = c->next;
      free(c);
    };
}

static void txt1__movecalls(txt t, txt1_zits by, txt1_call *to)
/* Move the most recently planned calls in the y direction. */
{
  txt1_call *c = t->calls;

  while (1) {
    if (c == to) break;
    if (c == NULL) break;
    tracef2("moving paint call at y=%i to y=%i\n", c->y, c->y+by);
    c->y += by;
    c = c->next;
  };
}

static void txt1__cancelcalls(txt t, txt1_call *to)
/* cancel the n most recently planned calls. */
{
  txt1_call *c;

    while (1) {
      if (t->calls == to) break;
      if (t->calls == NULL) break;
      c = t->calls;
      t->calls = t->calls->next;
      free(c);
    };
}

void txt1__cancelallcalls(txt t)
{
  txt1__cancelcalls(t, NULL);
}

static void txt1__cancelcallswithylessthan(txt t, txt1_zits y, txt1_call *to)
/* >>>> Used in measureback when a long text line is partially visible. */
{
  txt1_call **p;
  txt1_call *c;

    p = &(t->calls);
    while (1) {
      c = *p;
      if (c == NULL) break;
      if (c == to) break;
      if (c->y < y) {/* delete */
        tracef2("cancelcallswithylessthan strikes, %i<%i.\n",
            c->y, y);
        *p = c->next;
        free(c);
      } else {
        p = &(c->next);
      };
    };
}

/* -------- Line measuring. -------- */

void txt1__measure(
  txt t,
  txt1_zits *x /*inout*/, txt1_zits *y /*inout*/,
  txt1_zits ylim,                  /* y>=ylim -> stop straight away. */
  txt1_bufindex *at /*inout*/,
  txt1_bufindex lim,               /* at==lim -> stop straight away. */
  BOOL generate)
/* This procedure adds to the list of pending calls the calls necessary to
display the specified segment of the array. It advances x and y as if the
calls were made. It generates calls to clear the ends of lines when
'\n's are found, and advances x and y to the start of the next line. If
it finds itself generating calls at or beyond ylim it stops. */

/* There is a subtlety concerning what happens if the result of a measure
lands you at the screen split of a long text line. If we stop because of ylim
then (x,y) is at the start of the new screen line. if we stop because of lim
then it's at the end of the previous one. */

/* >>>> If measure finds itself generating more calls than can possibly fit
in the window it should delete the early ones as it goes, this behaviour is
necessary in the case where the top thing in the window is the tail of an
incredibly long line (if we are not to bust store by saving up zillions of
useless calls). */
/* >>>> xlim form built in? */
/* >>>> no-calls flag built in? or static flag in state... */
{
  int segsize;
  int msize;
  txt1_zits spacewidth;
  char *addr;
  BOOL highlight = FALSE;
  int highlightno;
  txt1_bufindex nextlineend;

    tracef3("measure scr (%i,%i) ylim=%i", *x, *y, ylim);
    tracef2(" at=%i lim=%i\n", *at, lim);
    txt1__assertcharbufindex(t, *at, "m-1");
    nextlineend = txt1__nextlineend(t, *at);
    highlightno = 0;
    if (txt1__lessoreqbi(t, lim, *at)) {
      tracef3(" -- immediate exit at (%i,%i) at=%i\n", *x, *y, *at);
      return;
    };
    while (1) {
      txt1__assertcharbufindex(t, *at, "m-2");
      if (*y >= ylim) break;
      if (*at == lim) break;
      if (highlightno == 0) {
        highlight = txt1__withinselect(t, *at, &highlightno);
      };
      if (*at == nextlineend) {
        /* we're at a newlinech. */
        /* can't be termch because not (at=lim). */
        txt1__cleartoendofline(t, x, y, generate); /* advances x and y */
        txt1__incbi(t, at, 1);
        highlightno--;
        nextlineend = txt1__nextlineend(t, *at);
      } else {
        /* not a line end, normal characters. */
        if (! txt1__segsize(t, *at, &segsize)) break;
        /* >>>> needn't recalculate this every time? */
        if (lim > *at && lim < (*at + segsize)) {
          segsize = lim - *at;
        };
        if (nextlineend > *at && nextlineend < (*at + segsize)) {
          segsize = nextlineend - *at;
        };
        if (segsize > highlightno) {
          segsize = highlightno;
        };
        msize = segsize;
        addr = &(t->buf[*at]);
        spacewidth = t->w->limx - *x;
        t->w->rawmeasure(t, &addr, &msize, &spacewidth);
        if (*x == 0 && segsize == msize) {
          /* this window's so small, not even one char will fit.
          in order to prevent an infinite loop, we inist on at least
          one char per line. */
          tracef0("huge char case.\n");
          msize--;
        };
        addr = &(t->buf[*at]);
        txt1__incbi(t, at, segsize - msize);
        highlightno -= segsize - msize;
        if (msize == 0) {
          /* we finished all the characters, good. */
          if ((t->buf[*at] == '\n') && (*at != lim)) {
            /* optimise filling in of the rest of the rest of the line */
            if (generate) txt1__paintcall(
              t, *x, *y, addr, segsize,
              (t->w->limx - spacewidth) - *x, highlight, txt1_CETEXTLINE);
            *x = 0;
            *y += t->w->linesep;
            txt1__incbi(t, at, 1);
            if (highlightno != 0) highlightno--;
            /* don't care if we highlight a '\n' */
            nextlineend = txt1__nextlineend(t, *at);
          } else {
            /* t->buf[at] is probably termch. Careful to leave x, y in the
              right place. */
            if (t->buf[*at] == '\n') {
              if (generate) txt1__paintcall(
                t, *x, *y, addr, segsize,
                (t->w->limx - spacewidth) - *x, highlight, txt1_CETEXTLINE);
            } else {
              if (generate) txt1__paintcall(
                t, *x, *y, addr, segsize,
                (t->w->limx - spacewidth) - *x, highlight, txt1_CECONTINUE);
            };
            /* >>>> a bit bulky, use a separate variable. */
            *x = t->w->limx - spacewidth;
          };
        } else {
          /* we ran out of width on the line, with msize chars to spare */
          if (generate) txt1__paintcall(
            t, *x, *y, addr, segsize-msize,
            (t->w->limx - spacewidth) - *x, highlight, txt1_CEDISPLINE);
          *x = 0;
          *y += t->w->linesep;
        };
      };
    };
    tracef3(" -- exit at (%i,%i) at=%i\n", *x, *y, *at);
}

/* >>>> What happens in the case where the line exactly fits on the screen
line? At the moment, no line-wrap occurs in this case and the cursor will not
actually be visible. It would be possible to fix this around the "if (msize ==
0)" above, but I won't unless people complain. in an imprecise window world,
this case is less common than with VDUs. */

/* What is the position of the first character of a screen line that is the
continuation of a text line? It's at the right hand edge. this is not
intuitive for doing cursor-up from the line below! but, if you try to fudge
it here (based on deciding that the next char won't fit, even though you
didn't ask me to measure it, so I will advance to the next line) then you
have a situation where inserting a new (thinner) character at the cursor will
affect the line above. So, leave this horror until we tackle wordwrap. this
is also a problem for caching the positions of firstvis and lastvis, which
are assumed to have x=0. If they are at the continuation of a wrapped text
line domeasureback gets this wrong and returns FALSE. note from this slightly
devious code in decfirst/last. */

BOOL txt1__measureback(
  txt t,
  txt1_zits *x /*inout*/,
  txt1_zits *y /*inout*/,
  txt1_zits ylim,                 /* y<=ylim -> stop straight away */
  txt1_bufindex *at /*inout*/,
  txt1_bufindex lim,              /* at==lim -> stop straight away */
  BOOL generate)
/* Measure backwards through the array from "at" at (x,y), generating calls
as you go. Stop before generating calls with y<ylim, or for any characters
before lim. note y==ylim not an excuse to stop, keep going for all such
chars. */

/* This works by skipping backwards a whole text line, and measuring
forwards. If the line was more than one screen line long, the
calls are moved up a little after the event. */

/* The routine returns FALSE if the x coordinate given just doesn't match
what we find, in which case x returns with a more suitable value. This is
used in two cases. The first is when the initial x is a total guess, for
total redisplay of text. */

/* The second case involves the murky issue of the exact position of a split
between two screen lines forming a single text line. If measure stops at such
a point due to ylim then the start of the continuation line is returned. If
this position is given to this routine then it returns FALSE, it can't know
for sure that this is a split point except by measuring forwards too. This is
important with partial redisplays involving firstvis and lastvis, which are
kept as a y coordinate only with an implicit x==0. see incfirst/last etc. for
this. */

/* >>>> This whole area is unsatisfactory. deeper insight required!
Is this duality of the coordinates of a split point inevitable? */

{
  txt1_zits x1;
  txt1_zits y1;
  txt1_call *callsalready;
  txt1_bufindex lstart;
  txt1_bufindex at1;
  txt1_zits initialy;
  txt1_bufindex initialat;

    tracef3("measureback from (%i,%i) ylim=%i", *x, *y, ylim);
    tracef2(" at=%i lim=%i\n", *at, lim);
    lstart = txt1__startofreasonableline(t, *at);
    initialy = *y;
    initialat = *at;
    callsalready = t->calls;
    if (*at != lstart || *x != 0) {
      /* left hand part of line containing cursor. */
      if (*y < ylim /* >>>> y<=ylim */) {
        tracef3(" -- exit TRUE at (%i,%i) at=%i\n", *x, *y, *at);
        return TRUE;
      };
      if (txt1__lessoreqbi(t, *at, lim)) {
        tracef3(" -- exit TRUE at (%i,%i) at=%i\n", *x, *y, *at);
        return TRUE;
      };
      x1 = 0;
      y1 = *y;
      at1 = lstart;
      callsalready = t->calls;
      txt1__measure(t, &x1, &y1, INT_MAX, &at1, *at, generate);
      if (x1 != *x) {
        /* the x he gave us just doesn't work: tell him a better one,
        and return. the calls will not get used, it's up to him to
        cancel them. */
#if FALSE
        *y = y1;
          /* for inc/decfirst/last. has no effect for the case used by
          redisplaytext, as we never get t->w->caretx/y wrong unless y=y1. */
#endif
        *x = x1;
        tracef3(" -- exit FALSE at (%i,%i) at=%i\n", *x, *y, *at);
        return FALSE;
      };
      if (y1 == *y) {
        /* it's a single line, all is well */
      } else {
        /* this line is longer than one screen line. so, shift the
        calls you've just generated up a little. */
        txt1__movecalls(t, *y - y1, callsalready);
        *y += (*y - y1); /* *y-y1 is -ve */
      };
      *at = lstart;
      *x = 0;
    };
    while (1) { /* for each text line */
      if (txt1__lessoreqbi(t, *at, lim) || *y < ylim) {
        /* we have finished or gone too far back, we were only supposed
        to go to lim. so, track forwards again until we reach
        both this and ylim, and) {return. */
        /* >>>> could y<=ylim be better? better to cover the whole
        ground,) {go forwards. want min "at" with same y. */
        txt1__cancelcallswithylessthan(t, ylim, callsalready);
        callsalready = t->calls;
        txt1__measure(t, x, y, initialy+1, at, lim, FALSE);
        txt1__measure(t, x, y, ylim, at, initialat, FALSE);
        txt1__cancelcalls(t, callsalready); /* >>>> superfluous */
        break;
      };
      /* x==0. we're not at the start of the array. try the next line. */
      at1 = *at;
      txt1__decbi(t, &at1, 1);
      lstart = txt1__startofreasonableline(t, at1);
      at1 = lstart;
      x1 = 0;
      y1 = *y - t->w->linesep; /* guess at single line */
      callsalready = t->calls;
      txt1__measure(t, &x1, &y1, INT_MAX, &at1, *at, generate);
      /* we know the last character in there is a newline */
      txt1__assert(x1 == 0, "mb");
      if (y1 == *y) {
        /* it's a single line, usual case. */
        *y -= t->w->linesep;
      } else {
        /* it's a long line, so move it up a little. */
        txt1__movecalls(t, *y - y1, callsalready);
        *y = (*y - t->w->linesep) + (*y - y1); /* y-y1 is -ve */
      };
      *at = lstart;
    };
    tracef3(" -- exit TRUE at (%i,%i) at=%i\n", *x, *y, *at);
    return TRUE;
}
/* If the exit from measureback is at the screen split of a long text line,
there is an unpleasant mix of cases concerning where (x,y) end up pointing.
You can return with y<ylim in this case, this is delicate for decfirst/last.
>>>> This is far from satisfactory! a clearer model is sought. */

void txt1__horizmeasure(txt t,
  txt1_zits x, txt1_zits xlim, txt1_bufindex *at /*inout*/)
/* Advance at until we are pointing at something in the xlim column.
Stop at end of line. */
{
  txt1_bufindex lineend;
  char *addr;
  int segsize;
  txt1_zits spacewidth;

    tracef3("horizmeasure x=%i xlim=%i at=%i.\n", x, xlim, *at);
    lineend = txt1__nextlineend(t, *at); /* or end of array */
    while (1) {
      if (*at == lineend) break;
      if (! txt1__segsize(t, *at, &segsize)) break; /* end of file */
      if (*at + segsize > lineend) {
        segsize = lineend - *at;
      };
      addr = &(t->buf[*at]);
      spacewidth = xlim - x;
      t->w->rawmeasure(t, &addr, &segsize, &spacewidth);
      x = xlim - spacewidth;
      txt1__incbi(t, at, addr - &(t->buf[*at]));
      if (segsize != 0) break; /* no room for any more */
    };
    if (*at != txt1__termchbi(t)
    && t->buf[*at] != '\n'
    && txt1__measurechar(t, t->buf[*at]) / 2 < xlim - x
    ) {
      tracef0("round up by 1.\n");
      txt1__incbi(t, at, 1);
    };
    tracef2("horizmeasure exit x=%i at=%i.\n", x, *at);
}

#if FALSE
 >>>> not needed, until fonts get better.

void txt1__measurepreviouschar(txt t,
  txt1_zits x, txt1_zits y, txt1_bufindex at)
/* Used for italic adjustment to things. if (x!=0) then measure (and generate
a call for) just one character before at. */
{
  txt1_bufindex prev;
  txt1_zits initialx;

    tracef0("measurepreviouschar.\n");
    if (x == 0) return; /* at start of line */
    initialx = x;
    prev = at;
    txt1__decbi(t, &prev, 1);
    assert(prev != at, "mpc-1"); /* x would have been 0 */
    assert(t->buf[prev] != '\n', "mpc-2"); /* ditto */
    measure(t, &x, &y, INT_MAX, &prev, at);
    /* will surely generate exactly one call. */
    assert(calls != NULL, "mpc-3");
    calls->x -= x - initialx;
}
#endif

void txt1__cleartoendofline(txt t,
  txt1_zits *x /*inout*/, txt1_zits *y /*inout*/, BOOL generate)
/* Generate the calls that perform blanking of the rest of the window
beyond the specified point. */
{
    tracef2("clear to end of line %i %i.\n", *x, *y);
    if (generate) txt1__paintcall(t, *x, *y, NULL, 0, 0, FALSE, txt1_CETEXTLINE);
    *x = 0;
    *y += t->w->linesep;
}

void txt1__updatescrollbar(txt t)
{
  int max;
  int first;
  int last;
  txt1_percent size;
  txt1_percent offset;

    max = txt1__bufindextoindex(t, txt1__termchbi(t)); /* >= 1 */
    first = txt1__bufindextoindex(t, t->w->firstvis.pos);
    last = txt1__bufindextoindex(t, t->w->lastvis.pos);
    tracef3("scrollbar: max=%i first=%i last=%i\n", max, first, last);
    if (last < first) last = first;
    if (max == 0) {
      size = 100;
      offset = 0;
    } else {
      size = ((last - first) * 100) / max;
      if (size == 0) size = 1; /* very big files. */
      offset = (first * 100) / max;
    };
    /* try not to keep fiddling the size by small amounts. */
    if (t->w->isize != 0 && abs(size - t->w->isize) < 3) {
      size = t->w->isize;
    };
    if (size != t->w->isize || offset != t->w->ioffset) {
      t->w->isize = size;
      t->w->ioffset = offset;
      t->w->rawsetsize(t);
    };
}

/* -------- Total redisplay. -------- */

void txt1__redisplaytext(txt t, BOOL fresh)
/* Redisplay the window, resetting t->w->caretx/y if necessary in order to
keep dot on the screen. Assume the caret is not painted, and do not paint it.
*/
{
  txt1_zits x;
  txt1_zits y;
  txt1_bufindex at;

    if (t->w->carety < t->w->linesep) t->w->carety = t->w->linesep;
    if (t->w->carety > t->w->limy) t->w->carety = t->w->limy;
    /* This is quite common on a change of font. */
    if (fresh && t->w->lastvisy < t->w->limy) {
      /* try to move things down a little. */
      t->w->carety += t->w->limy - t->w->lastvisy;
    };
    while (1) {
      x = t->w->caretx;
      y = t->w->carety;
      at = t->w->caret.pos;

      if (at == txt1__firstchbi(t)) {x = 0; t->w->caretx = 0;};
      /* 17-Nov-88: If this is true, the measureback will succeed vacuously and we
      won't get told about the wrong x. */

      if (txt1__measureback(t, &x, &y, 1, &at, txt1__firstchbi(t), TRUE)) {
        txt1__assert(
          txt1__lessoreqbi(t, at, t->w->caret.pos), "rt-1");
        txt1__assert(y <= t->w->carety, "rt-2");
        /* >>>> bug hunt: should always be TRUE after measureback... */
        /* ylim=1 means, any character which is at all visible on the
        top line must be taken into account. */
        if (y > t->w->linesep) {
          /* we didn't get to the beginning of the screen, so t->w->caretx/y
          must be wrong. must move t->w->carety up the screen. */
          txt1__cancelallcalls(t);
          t->w->carety = t->w->carety + t->w->linesep - y;
          /* and loop */
        } else {
          /* all is well, and calls before cursor planned. */
          txt1__movemarker(t, &(t->w->firstvis), at);
          t->w->firstvisy = y;
          tracef1("setting firstvis to %i.\n", at);
          txt1__reverseorderofcalls(t);
          txt1__displayfrom(t, t->w->caretx, t->w->carety, t->w->caret.pos);
            /* calls updatescrollbar */
          txt1__paintallcalls(t);
          break;
        };
      } else {
        /* t->w->caretx is wrong. we must adjust it, and go round again. */
        txt1__cancelallcalls(t);
        t->w->caretx = x;
        /* and loop */
      };
    };
}
/* The reverseorderofcalls above is somewhat tweaky, but it means that the
calls for the construction of the line with the cursor on it actually end up
very close to each other. The sorting in paintallcalls is optimised to
assume that things are almost in the right order already. */

/* Just before the loop, I tried going:
    if (t->w->lastvisy < t->w->limy) {
      t->w->carety += t->w->limy - t->w->lastvisy;
    };
in order to improve screen usage near the end of the file. Unfortunately
I cannot distinguish times when he's trying to redraw the whole thing,
rather than just repaint something. In the latter case, the above is
disastrous if I got to the non-normalised state somehow, e.g. by incremental
edits.
>>>> must change this so that it's only within this module that this
improvement is made. */

void txt1_checklastvis(txt t)
/* This is used by txtar when shinking/growing the size of
the window and avoiding a total repaint. */
{
          txt1__displayfrom(t, t->w->caretx, t->w->carety, t->w->caret.pos);
            /* calls updatescrollbar */
          txt1__cancelcalls(t, NULL);
}

void txt1__displayfrom(txt t, txt1_zits x, txt1_zits y, txt1_bufindex at)
/* Display the characters from at onwards in the window, starting at the
value of (x,y). Do not assume that at==bufend. If you reach the end
of the array, blank the rest of the window. */
{
  txt1_bufindex term;

    term = txt1__termchbi(t);
    txt1__measure(t, &x, &y, t->w->limy+t->w->linesep, &at, term, TRUE);
    txt1__movemarker(t, &(t->w->lastvis), at);
    t->w->lastvisy = y;
    if (x != 0) {
      /* if t->w->lastvis is at the split of a long line then we
      remember the y coord of the start of the continuation, because
      implicitly t->w->lastvisx==0. Here we have hit the end of file, without
      a '\n', and we act in a simialar way. */
      t->w->lastvisy += t->w->linesep;
    };
    if (at == term) {/* blank the rest of the screen */
      while (y < t->w->limy+t->w->linesep) txt1__cleartoendofline(t, &x, &y, TRUE);
    };
    tracef2("setting t->w->lastvis to %i, lastvisy to %i.\n", at, t->w->lastvisy);
    txt1__updatescrollbar(t);
}

void txt1__showcaret(txt t)
{
    if (0 != (txt_CARET & t->charoptionset) && (t->w == t->windows[1])) {
      t->w->rawshowcaret(t);
    };
/* Regardless of whether the caret is visible, force its position
to be so in the current window. Without this the display invariants
will not be maintained. This code is already executed by rawshowcaret
in the case where the caret is visible. */
      if (t->w->carety + t->w->caretoffsety <
          txt1__min(t->w->linesep, t->w->limy)) {
        tracef0("auto-shifting, carety<=0.\n");
        txt1_domovevertical(
          t,
          - (1 + (t->w->linesep-1 - (t->w->carety + t->w->caretoffsety)) / t->w->linesep),
          TRUE);
      } else if (t->w->carety + t->w->caretoffsety > t->w->limy) {
        tracef0("auto-shifting, carety > limy.\n");
        txt1_domovevertical(
          t,
          ((t->w->linesep-1 + t->w->carety + t->w->caretoffsety - t->w->limy)
             / t->w->linesep),
          TRUE);
      };
}

void txt1__hidecaret(txt t)
{
    if (0 != (txt_CARET & t->charoptionset) && (t->w == t->windows[1])) {
      t->w->rawhidecaret(t);
    };
}

/* -------- Incremental display update. -------- */

void txt1_redisplay(txt t, BOOL fresh)
/* Redisplay all, including the caret. */
{
    if (0 == (txt_DISPLAY & t->charoptionset)) return;
    txt1__hidecaret(t);
    txt1__redisplaytext(t, fresh);
    txt1__showcaret(t);
    txt1__checkscreeninvariant(t, "rd-1");
}

void txt1__redisplayselectrange(txt t, txt1_bufindex from, txt1_bufindex to)
/* The selection attribute of the given range has changed. Invert the
painting of the characters of that array. If inversion is not available,
repaint them. Copes with from/to being the wrong way round, if necessary. */
{
  txt1_bufindex temp;
  txt1_zits x;
  txt1_zits y;
  txt1_bufindex at;

    if (0 == (txt_DISPLAY & t->charoptionset)) return;
    if (from == to) return;
    if (txt1__lessthanbi(t, to, from)) {/* swap */
      temp = to; to = from; from = temp;
    };
    if (t->w->italic && ! t->w->highlight_reversable) {
      /* redisplay whole lines. */
      tracef0("redisplay whole lines.\n");
      from = txt1__startofline(t, from);
      to = txt1__nextlineend(t, to);
    };
/*      txt1__hidecaret(t); */
    x = t->w->caretx;
    y = t->w->carety;
    at = t->w->caret.pos;
    if (txt1__lessthanbi(t, from, t->w->caret.pos)) {
      (void) txt1__measureback(t, &x, &y, 0 /* INT_MIN */, &at, from, FALSE);
    } else {
      txt1__measure(t,
        &x, &y, t->w->limy+t->w->linesep /* INT_MAX */, &at, from, FALSE);
    };
    txt1__cancelallcalls(t);
    txt1__measure(t, &x, &y, t->w->limy+t->w->linesep, &at, to, TRUE);
    txt1__invertallcalls(t);
/*      txt1__showcaret(t); */
}

void txt1__ensuredotvisible(txt t, int dotmove)
/* The text has not changed and display is up to date and caret visible, but
the dot has moved. Thus, this only happens at the end of domovedot. If
dotmove is positive then the dot has just moved forward by that amount
compared to what is displayed on the screen and held by t->t->w->caretx/y. */

/* >>>> At the moment, only called on the primary window. */
{
  txt1_zits prevcarety;
  txt1_bufindex prevdot;

    if (0 == (txt_DISPLAY & t->charoptionset)) return;
    txt1__hidecaret(t);
    t->w->caretoffsetx = 0;
    t->w->caretoffsety = 0;
    prevcarety = t->w->carety;
    if (dotmove > 0) {/* We have moved forwards in the file. */
      /* We must measure what there is between prevdot and t->gapend. */
      prevdot = t->gapend;
      txt1__decbi(t, &prevdot, dotmove); /* set up prevdot */
      txt1__measure(t, &t->w->caretx, &t->w->carety,
        (3*t->w->limy) / 2, &prevdot, t->gapend, FALSE);
      txt1__cancelallcalls(t);
      if (prevdot != t->gapend) {
        /* We did not reach the new dot, so it must be several lines
        beyond the end of the window thus, a total repaint is required. */
        t->w->caretx = 0;
        if (t->gapend == txt1__termchbi(t)) {
          t->w->carety = t->w->limy;
        } else {
          t->w->carety = t->w->limy / 2;
          t->w->carety = (t->w->carety / t->w->linesep) * t->w->linesep;
        };
        txt1__redisplaytext(t, TRUE);
      } else {
        /* t->w->caretx/y have been updated ok. */
        /* The caret is either within the window, or just outside.
        If the latter dorawshowcaret will call domovevertical in
        order to correct things, so there's nothing more to be done
        here. */
      };
    } else if (dotmove < 0) {/* have moved backwards in the file. */
      prevdot = t->gapend;
      txt1__incbi(t, &prevdot, -dotmove);
      if (! txt1__measureback(t,
              &t->w->caretx, &t->w->carety, -(t->w->limy / 2),
              &prevdot, t->gapend, FALSE)
      ) {
        txt1__assert(FALSE, "edv-1");
      };
      txt1__cancelallcalls(t);
      if (prevdot != t->gapend) {
        /* we did not reach the new dot, so it must be several lines
        beyond the start of the window. Thus, a total repaint is
        required. */
        t->w->caretx = 0;
        if (t->gapend == txt1__termchbi(t)) {
          t->w->carety = t->w->limy;
        } else {
          t->w->carety = t->w->limy / 2;
          t->w->carety = (t->w->carety / t->w->linesep) * t->w->linesep;
        };
        txt1__redisplaytext(t, TRUE);
      } else { /* it's still visible. */
        txt1__assert(
          txt1__lessoreqbi(t, t->w->firstvis.pos, t->gapend), "edv-3");
        /* t->w->caretx/y have been updated ok. */
        /* The caret is either within the window, or just outside.
        The latter dorawshowcaret will call domovevertical in
        order to correct things, so there's nothing more to be done
        here. */
      };
    } else {
      /* moveby == 0. still important to wiggle the caret if display, because
      of t->w->caretoffset. */
    };
    txt1__showcaret(t);
    txt1__checkscreeninvariant(t, "edv-2");
}
/* I have experimented with making the "limy / 2" in the total redisplays
into just "limy". This helps if moving to the end of the file, but otherwise
keeps ending you up (after a long hop, e.g. a find operation) on the bottom
line of the display. */

/* the problem with suddenly setting carety to limy / 2 is that it suddenly
assumes that any value of zits is a bona fide line separation value.
Surprisingly, this assumption is made nowhere else. Thus the div mul by
t->w->linesep. (it's all a cheat: zits are os units in TextArthur in the y
direction, and I really think in pixels! Oh well.) */

static void txt1__incfirst(txt t, txt1_zits byy)
/* This procedure will generate calls and increment firstvis, for use when a
copylines has been successful. It is used in ensuredotvisible above, and also
when a scroll bar is clicked. It ignores the caret, so invariants etc. do not
hold during this procedure. */
{
  txt1_zits x;
  txt1_bufindex at;

    tracef0("increment firstvis.\n");
    x = 0;
    at = t->w->firstvis.pos;
    txt1__measure(t, &x, &t->w->firstvisy, byy + 1, &at, txt1__termchbi(t), FALSE);
    txt1__cancelallcalls(t);
    t->w->firstvisy -= byy;
    txt1__movemarker(t, &(t->w->firstvis), at);
    tracef3("firstvis moved to %i, ch=%i, t->w->firstvisy=%i.\n",
      t->w->firstvis.pos, t->buf[t->w->firstvis.pos], t->w->firstvisy);
}

static void txt1__inclast(txt t, txt1_zits byy)
/* This procedure will generate calls and increment lastvis, for use when a
copylines has been successful. It is used in ensuredotvisible above, and also
when a scroll bar is clicked. It ignores the caret, so invariants etc. do not
hold during this procedure. */
{
  txt1_zits x, savex;
  txt1_zits y;
  txt1_bufindex at;
  txt1_call *callssofar;

    tracef0("increment lastvis.\n");
    tracef4("byy=%i limy=%i lastvisy=%i linesep=%i\n",
      byy, t->w->limy, t->w->lastvisy, t->w->linesep);

    /* There may some characters partially visible, which are before
    lastvis. These must be repainted. spotting this is quite tricky,
    e.g. the case where lastvis == termch and there's no '\n'
    at the end of the file. We rely on measureback to do no work
    in such cases. */

    tracef0("repaint partial at bottom.\n");
    x = 0;
    savex = 0;
    y = t->w->lastvisy - byy;
    at = t->w->lastvis.pos;
    callssofar = t->calls;
    if (! txt1__measureback(t,
            &x, &y, y - t->w->linesep, &at, txt1__firstchbi(t), TRUE)
    ) {
      /* lastvis must be at the continuation of a long, wrapped line. */
      tracef0("lastvisy is on a continuation line.\n");
      y -= t->w->linesep;
      t->w->lastvisy -= t->w->linesep;
      savex = x;
      txt1__cancelcalls(t, callssofar);
      /* x and y now point to the end of the previous screen line, which is
      wrapped onto the one we started at. */
      if (! txt1__measureback(
               t, &x, &y, y - t->w->linesep, &at, txt1__firstchbi(t), TRUE)
      ) {
        tracef0("**lastvisy foul-up.\n");
      };
    };
    txt1__cancelcallswithylessthan(t, 1 + t->w->limy - byy, callssofar);
    /* done purely for the calls. */

    x = savex;
    /* x = 0; */
    y = t->w->lastvisy - byy;
    at = t->w->lastvis.pos;
    txt1__measure(t, &x, &y, t->w->limy+t->w->linesep, &at, txt1__termchbi(t), TRUE);
    txt1__movemarker(t, &(t->w->lastvis), at);
    tracef1("lastvis moved to %i.\n", t->w->lastvis.pos);
    t->w->lastvisy = y;
    if (x != 0) {
      /* we're at the end of array, no '\n' */
      t->w->lastvisy += t->w->linesep;
    };
    tracef1("lastvisy set to %i.\n", t->w->lastvisy);
    if (at == txt1__termchbi(t)) {/* blank the rest of the screen */
      while (y < t->w->limy+t->w->linesep) txt1__cleartoendofline(t, &x, &y, TRUE);
    };
}
/* The cancelcallswithylessthan handles tricky cases where characters are
repainted when in fact they were fully visible. it seems quite hard not to
generate these in the first place, maybe it's a bodge and should be done
neater... */

static BOOL txt1__decfirst(txt t, txt1_zits byy)
/* Similar to incfirst, but for moving towards the start of the array. */
/* Returns FALSE if you hit the start of the array without
being able to move back as far as you'd hoped. */
{
  txt1_zits x;
  txt1_zits y;
  txt1_bufindex at;
  txt1_call *callssofar;

    tracef0("decrement firstvis.\n");
    if (t->w->firstvisy < t->w->linesep) {
      /* the first line of the display was not totally visible, and
      must be repainted. */
      tracef0("repaint partial at top.\n");
      x = 0;
      y = t->w->firstvisy + byy;
      at = t->w->firstvis.pos;
      txt1__measure(t, &x, &y, y+t->w->linesep, &at, txt1__termchbi(t), TRUE);
      /* done purely for the calls. */
    };
    x = 0;
    y = t->w->firstvisy + byy;
    at = t->w->firstvis.pos;
    callssofar = t->calls;
    if (! txt1__measureback(t,
            &x, &y, 1 /* >>>> t->w->firstvisy */,
            &at, txt1__firstchbi(t), TRUE))
    {
      /* firstvis must be at the continuation of a long text line. */
      tracef0("firstvisy is on a continuation line.\n");
      txt1__cancelcalls(t, callssofar);
      y -= t->w->linesep;
      if (! txt1__measureback(t, &x, &y, 1, &at, txt1__firstchbi(t), TRUE)) {
        tracef0("**firstvisy foul-up.\n");
      };
    };
    if (y < 1) {
      /* Unpleasant case: we have come to rest at the split of a long
      text line, and measureback puts (x,y) at the end of the prev line.
      firstvis/lastvis always represent this case by assuming start
      of continuation line, so adjust things here. */
      y += t->w->linesep;
    };
    if (y > t->w->linesep) {
      /* Another unpleasant case: we are at the top of file. */
      /* He's going to have to redraw. */
      tracef0("start of file, need to redraw.\n");
      txt1__cancelallcalls(t);
      return FALSE;
    };
    txt1__movemarker(t, &(t->w->firstvis), at);
    t->w->firstvisy = y;
    tracef3("firstvis moved to %i, ch=%i, t->w->firstvisy=%i.\n",
      t->w->firstvis.pos, t->buf[t->w->firstvis.pos], t->w->firstvisy);
    return TRUE;
}

static void txt1__declast(txt t, txt1_zits byy)
/* similar to inclast, but for moving towards the start of the array. */
{
  txt1_zits x;
  txt1_zits y;
  txt1_bufindex at;
  txt1_call *callssofar;

    tracef0("decrement lastvis.\n");
    x = 0;
    y = t->w->lastvisy + byy;
    at = t->w->lastvis.pos;
    callssofar = t->calls;
    if (! txt1__measureback(t,
          &x, &y, t->w->limy + t->w->linesep, &at, txt1__firstchbi(t), TRUE)
    ) {
      /* lastvis must be at the continuation of a long, wrapped line. */
      tracef0("lastvisy is on a continuation line.\n");
      y -= t->w->linesep;
      /* x and y now point to the end of the previous screen line, which is
      wrapped onto the one we started at. */
      if (! txt1__measureback(t,
              &x, &y, t->w->limy + t->w->linesep, &at, txt1__firstchbi(t), TRUE)) {
        tracef0("**lastvisy foul-up.\n");
      };
    };
    t->w->lastvisy = y;
    txt1__movemarker(t, &(t->w->lastvis), at);
    if (at == txt1__termchbi(t) && x != 0) {
      t->w->lastvisy += t->w->linesep;
    };
    tracef1("lastvis moved to %i.\n", t->w->lastvis.pos);
    txt1__cancelcalls(t, callssofar);
}

void txt1__displayreplace1(txt t, int n)
/* We're about to replace the next n characters. Measure them up for this.
Return the end position of the characters you're about to delete. If this is
way beyond the end of the screen, don't bother. */

/* In the case of multiple windows, the deletion/insertion could be miles
away from this window. If t->gapend is after lastvis, or before the '\n'
before firstvis then we needn't do anything, except perhaps update the
scroll bar. This is the first thing to check. */

/* Otherwise, all we know (within this window) is that t->w->caret.pos is
accurately displayed at t->w->caretx and t->w->carety. We must calculate the
location of the gap, and then the location of the end of the deleted
passage. in the one-window case the former of these will be very trivial
indeed. */
{
  txt1_bufindex newdot;
  txt1_bufindex at;

    if (0 == (txt_DISPLAY & t->charoptionset)) {
      t->w->delendy = INT_MAX;
      return;
    };

    if (txt1__lessthanbi(t, t->w->lastvis.pos, t->gapend)) {
      tracef0("displayreplace1, update is beyond this window.\n");
      t->w->dotx = 0;
      t->w->doty = 0;
      t->w->delendx = 0;
      t->w->delendy = 0;
      return;
    };

    if (txt1__lessthanbi(t,
          t->gapend, txt1__startofline(t, t->w->firstvis.pos))) {
      tracef0("displayreplace1, update is before this window.\n");
      t->w->dotx = 0;
      t->w->doty = 0;
      t->w->delendx = 0;
      t->w->delendy = 0;
      return;
    };
    /* >>>> a little inefficient, common these two up. */

    t->w->dotx = t->w->caretx;
    t->w->doty = t->w->carety;
    at = t->w->caret.pos;
    if (txt1__lessthanbi(t, t->gapend, t->w->caret.pos)) {
      if (! txt1__measureback(t,
              &t->w->dotx, &t->w->doty, INT_MIN, &at, t->gapend, TRUE)) {
        tracef0("fail in measure1.\n");
      };
    } else {
      txt1__measure(t, &t->w->dotx, &t->w->doty, INT_MAX, &at, t->gapend, TRUE);
    };
    txt1__assert(t->gapend == at, "dr-1");
    /* t->w->dotx, t->w->doty now set up. */

    newdot = at;
    txt1__incbi(t, &newdot, n);
    t->w->delendx = t->w->dotx;
    t->w->delendy = t->w->doty;
    txt1__measure(t,
      &t->w->delendx, &t->w->delendy, (3*t->w->limy) / 2, &at, newdot, FALSE);
    txt1__cancelallcalls(t);
    tracef2("displayreplace1 x=%i y=%i\n", t->w->delendx, t->w->delendy);
}

void txt1__displayreplace2(txt t, int n, int ndeleted)
/* n characters have just been inserted, replacing ndeleted characters that
used to go from t->w->dotx/y to t->w->delendx/y. Do the necessary
replacement. move caretx/y if they are after this. */

/* A fairly general scheme is used that makes use of copylines when it can.
We measure the insertion, and if it is the same size as the deletion (and
font not italic) we just repaint that. We measure things as they are
now, discovering the next '\n' after/at end of the insertion. We then
measure things as they used to be, e.g. as they are on the screen, moving
(delendx,delendy) to the next '\n'. If there are any identical calls at
insline and delline then common them up, setting xs to 0. */
{
  txt1_zits insendx;
  txt1_zits insendy;
  txt1_bufindex at;
  txt1_bufindex lineend;
  txt1_bufindex atinsend;
  txt1_bufindex atdelend;
  txt1_call *callsinsend;
  BOOL giveup;

    ndeleted=ndeleted;

    if (0 == (txt_DISPLAY & t->charoptionset)
    || (n==0
        && t->w->delendx == t->w->dotx
        && t->w->delendy == t->w->doty)
    ) {
      return;
    };

    if (txt1__lessthanbi(t, t->w->lastvis.pos, t->gapend)) {
      tracef0("displayreplace2, update is beyond this window.\n");
      return;
    };
    if (txt1__lessthanbi(t, t->gapend,
                           txt1__startofline(t, t->w->firstvis.pos))) {
      tracef0("displayreplace2, update is before this window.\n");
      return;
    };

    if (t->w == t->windows[1]) txt1__hidecaret(t);

    txt1__italicadjust(t);

    insendx = t->w->dotx;
    insendy = t->w->doty;
    atinsend = t->gapend;
    at = atinsend;
    txt1__incbi(t, &at, n);
    txt1__measure(t, &insendx, &insendy, (3*t->w->limy) / 2, &atinsend, at, TRUE);

    if ((! t->w->italic)
    && (insendx == t->w->delendx)
    && (insendy == t->w->delendy)
    ) {
      /* exact replace: that's all we need to) { */
      tracef0("exact replace.\n");
    } else {
      giveup = FALSE;

      /* choose a common point up to which to do old/new measuring. */
      lineend = atinsend;
      if ((insendx != 0) || (t->w->delendx != 0)) {
        lineend = txt1__nextlineend(t, lineend);
        txt1__incbi(t, &lineend, 1);
        /* actually, start of following line. */
      };

      /* measure new case */
      at = lineend;
      txt1__measure(t, &insendx, &insendy, (3*t->w->limy) / 2, &atinsend, at, TRUE);
      if (insendx != 0) {
        /* end of array with no '\n' case. */
        txt1__cleartoendofline(t, &insendx, &insendy, TRUE);
      };
      callsinsend = t->calls;

      /* measure old case */
      atdelend = t->gapend;
      txt1__incbi(t, &atdelend, n);
      at = lineend;
      txt1__measure(t,
        &t->w->delendx, &t->w->delendy, (3*t->w->limy) / 2, &atdelend, at, TRUE);
      if (t->w->delendx != 0) {
        txt1__cleartoendofline(t, &t->w->delendx, &t->w->delendy, TRUE);
      };

#if FALSE
/* Seems to cause a bug if deleting a block which starts and ends
at exactly the same x-offset on different lines... See the note at
the bottom about only doing whole lines. */
      /* Should work without this. And does, I believe! */
      /* Cancel calls that are identical above insend and delend. The
      ordering of calls created above is quite important here. Everything
      created since callsinsend is going to be cancelled. */
      if (t->calls != callsinsend) {
        c = t->calls;
        while (txt1__callsequaloryshifted(
                 c, callsinsend, insendy - t->w->delendy)) {
          tracef0("cancel equal calls.\n");
          if (callsinsend->y <= insendy) {
            tracef0("dec ins/delendy in step.\n");
            /* we can decrement ins/delendy, in step. */
            insendy -= t->w->linesep;
            t->w->delendy -= t->w->linesep;
            insendx = 0;
            t->w->delendx = 0;
          };
          c = c->next;
          callsinsend = callsinsend->next;
        };
      };
      /* >>>> This should only delete whole lines of display, or italics
      will go wrong. I should check this, there may be some very unlikely
      cases around? With the symptoms being slight italic imperfections. */
#endif

      /* cancel superfluous calls. */
      txt1__cancelcalls(t, callsinsend);

      if (insendy == t->w->delendy) {
        /* we paint these calls: done. */
        tracef0("insendy == delendy.\n");
        /* >>>> could cancel the cleartoendofline if (insendx was < delendx */
        /* >>>> more stringent test needed if (italic,
          e.g. was "f" at end... */
        /* One last case to care about, where we're near the bottom of
        the window */
        if (insendy >= t->w->lastvisy) {
          /* must worry about updating lastvis. just give up, no great
          loss since we're near the bottom of the display anyway. */
          tracef0("near bottom.\n");
          giveup = TRUE;
        };
      } else {
        insendy -= t->w->linesep;
        t->w->delendy -= t->w->linesep;
        /* The y values now indicate the top of the subsequent line. This is
        so that the copylines calls get the indicated line itself too. It
        also removes confusion over cases where the inserted/deleted segment
        does, or does not, end in a '\n'. */
        if (insendy > t->w->delendy) {
          /* we are inserting some lines. */
          tracef2("insendy=%i > delendy=%i.\n", insendy, t->w->delendy);
          if (insendy > t->w->limy - 2 * t->w->linesep) {
            /* not worth any copy */
            giveup = TRUE;
          } else if (
            t->w->rawcopylines(t, t->w->delendy, insendy, t->w->limy - insendy)
         ) {
            txt1__declast(t, insendy - t->w->delendy);
          } else {
            /* copy didn't work */
            giveup = TRUE;
          };
        } else if (insendy < t->w->delendy) {
          /* we are deleting some lines. */
          tracef2("insendy=%i < delendy=%i.\n", insendy, t->w->delendy);
          if (t->w->delendy > t->w->limy - 2 * t->w->linesep) {
            /* not worth any copy */
            giveup = TRUE;
          } else if (
            t->w->rawcopylines(
              t, t->w->delendy, insendy, t->w->limy - t->w->delendy)
         ) {
            txt1__inclast(t, t->w->delendy - insendy);
          } else {
            /* copy didn't work */
            giveup = TRUE;
          };
        };
      };

      if (giveup) {
        txt1__cancelallcalls(t); /* slightly clumsy, not important. */
        txt1__italicadjust(t);
        txt1__displayfrom(t, t->w->dotx, t->w->doty, t->gapend);
      };
    };

    txt1__paintallcalls(t);

    /* finally, if we aren't the primary window then our caret could
    get moved by all of this. */
    if (txt1__lessthanbi(t, t->gapend, t->w->caret.pos)) {
      tracef0("repositioning subsidiary window caret.\n");
      t->w->caretx = t->w->dotx;
      t->w->carety = t->w->doty;
      at = t->gapend;
      txt1__measure(t,
        &t->w->caretx, &t->w->carety, INT_MAX, &at, t->w->caret.pos, FALSE);
      txt1__cancelallcalls(t);

      tracef3("new caret at %i = %i,%i.\n",
        t->w->caret.pos, t->w->caretx, t->w->carety);
    };

    t->w->caretoffsetx = 0;
    if (t->w == t->windows[1]) {
      /* this only applies to the primary window. */
      if (t->w->caretoffsety != 0) {
        /* we are sitting at a line break, at the start of the following
        line. in such a case it seems appropriate to continue the display
        there. note that in all of the above, this issue can safely be
        ignored. */
        t->w->caretoffsetx = - t->w->caretx;
      };
      txt1__showcaret(t);
    } else {
      t->w->caretoffsety = 0;
    };

    txt1__checkscreeninvariant(t, "dr2-1");
}

/* >>>> Note that the statement about this not affecting t->w->caretx/y
precludes breaking at word boundaries. What if you are close to the end of a
line, and you delete a space? This could cause you to advance t->w->caretx/y
to the start of the previous line. Could t->w->caretx/y move up the screen?
Yes, by inserting a space while close to the front of a wrapped line you
could find yourself shoot to the end of the previous one. This means that
word-broken layout needs constant remeasuring from the start of the current
line. Let's do the simpler form first! */

/* Some thought has gone into the wordwrap thing. the point that stays
unmoved is the next start of line before the cursor. what you do is:
  if new/old strings both end with '\n', decrement counts.
  measure old paragraph
  make change
  measure new paragraph
  note change in endpoint, copylines etc.
  knock out common call lines in the lists above
  perform whatever is left.
In addition we need changes to measure to actually do the wordwrap decisions.
*/

void txt1__italicadjust(txt t)
/* It would be quite safe for this procedure to have no effect. The purpose
is that, when inserting things before an italic "f" or something, the tail of
the "f" can get left behind. So, if using an italic font (signalled by
sys-dep stuff) this procedure ensures that the entire line is repainted every
time. */
{
  txt1_bufindex at;
  txt1_zits x;
  txt1_zits y;

    if (t->w->italic) {
      at = t->w->caret.pos;
      x = t->w->caretx;
      y = t->w->carety;
      if (txt1__measureback(t, &x, &y, y - 1 /*t->w->linesep*/ /*INT_MIN*/,
           &at, txt1__startofline(t, t->w->caret.pos), TRUE)) {
      };
      /* the calls have been created. */
    };
}
/* >>>> At this point I could remove from the calls generated any with
y!=t->w->carety: if inserting several (screen) lines on in a long (text) line,
this will currently repaint the whole (text) line. */

/* >>>> tried setting ylim... */

/* >>>> It can be done much neater: just paint one character before in the
italic case, but do not rub-out underneath that char. Hooray for specifying
the rub-out box separately! But, how is this to be presented in the interface
between texts1/2? perhaps this is a universal problem? how sure can I be that
the answer is universal, e.g. look at x-windows... */

/* -------- Public scroll bar operations. -------- */

void txt1_thumbforw(txt t, txt1_percent by)
/* Ideally, lastvis advances by "by" percent of the distance from it
to the end of the array. */
/* It's difficult to know exactly what he means by this. for the moment
a simple move is performed. This is slightly unsatisfactory for small
distances in that only the cursor will move: but, a better solution is
not really clear. */
{
   txt_index ci = txt1__bufindextoindex(t, t->gapend);
   txt_index end = txt1__bufindextoindex(t, txt1__termchbi(t));
   int moveamount = (by * (end - ci)) / 100;
   if (by > t->w->isize && moveamount * 20 > txt1_dosize(t)) { /* quite a long drag */

     /* Try counting backwards a little so that we tend to hit
     newlines. This will reduce sideways scrolling when thumbing with
     a narrow window. */
     int i = 0;
     while (i < 120 && i < moveamount) {
       if (txt_charat(t, txt_dot(t) + moveamount - i) == '\n') {
         moveamount -= i;
         moveamount++;
         break;
       };
       i++;
     };

     txt1_domovedot(t, moveamount);
   } else { /* short drag */
     txt1_scrollbarmoveby(t, 1);
   };
}

void txt1_thumbback(txt t, txt1_percent by)
/* Ideally, firstvis retreats by "by" percent of the distance from it
to the beginning of the array. */
{
   txt_index ci = txt1__bufindextoindex(t, t->gapend);
   int amount = (by * ci) / 100;
   if (by > t->w->isize && by > 5) {

     /* quite a long drag, or within 1% of touching top of file */
     /* if (by < 100) by++; */

     /* Try counting backwards a little so that we tend to hit
     newlines. This will reduce sideways scrolling when thumbing with
     a narrow window. */
     int i = 0;
     while (i < 120 && i < amount) {
       if (txt_charat(t, txt_dot(t) - amount - i) == '\n') {
         amount += i;
         amount++;
         break;
       };
       i++;
     };

     txt1_domovedot(t, - amount);
   } else {
     txt1_scrollbarmoveby(t, -1);
     ci = txt1__bufindextoindex(t, t->w->firstvis.pos);
     if (ci < txt1_dosize(t) / 50) {
       /* fix problems with scrolling close to
       top of buffer. */
       txt1_dosetdot(t, 0);
     };
   };
}
/* The fudge to "by" is because rounding seems to cause 99-percent
moves to get to the front of the array. */

void txt1_scrollbarmoveby(txt t, int by)
/* A click in the "move one line" arrow box of a scroll bar causes this
to be called. */
/* If by==1 then advance the minimum amount reasonable, e.g. one display line.
If by==-1 go backwards in a similar way. this is because the window can't know
what value of offset to suggest for a small movement using thumbforw/back.
For larger values, act in the obvious way: e.g. for movement by a whole page.
*/
/* If the caret is not quite visible at the moment then this call is taken
as a good time to take corrective action. The window application can call
this routine, for instance, if the caret goes (just) out of bounds due to
a move or replace. */
{
  txt1_zits byy;
  BOOL copyfirst;
  BOOL caret;
  BOOL caretinbounds;

    tracef1("scrollbarmoveby %i.\n", by);
    tracef3("limy=%i lastvisy=%i linesep=%i\n",
      t->w->limy, t->w->lastvisy, t->w->linesep);
    if (by == 0) return;
    byy = abs(by) * t->w->linesep;

/* >>>> replaced by stuff below
    if ((by > 0) && (t->w->lastvis.pos == txt1__termchbi(t))) {
      if (t->w->lastvisy < t->w->limy) {
        return;
      };
    };
    if ((by < 0) && (t->w->firstvis.pos == txt1__firstchbi(t))) {
      if (t->w->firstvisy < t->w->linesep) {
        byy = t->w->linesep - t->w->firstvisy;
        by = -1;
      } else {
        return;
      };
    };
*/

    /* Try to align things so that you are showing a whole line in the
    direction in which you're moving. This speeds up repeated scrolling
    by reducing the amount of repainting of partial lines. */
    if (by < 0) {
      if (t->w->firstvisy < txt1__min(t->w->linesep, t->w->limy)) {
        /* there's a partial line at the top. */
        byy -= t->w->firstvisy;
      } else if (t->w->firstvis.pos == txt1__firstchbi(t)) {
        return; /* nothing to be) {ne. */
      };
    };
    if (by > 0) {
      if (t->w->lastvisy > t->w->limy + t->w->linesep) {
        /* there's a partial line at the bottom. */
        byy += t->w->lastvisy - (t->w->limy + t->w->linesep + t->w->linesep);
      } else if (t->w->lastvisy < t->w->limy
             && t->w->lastvis.pos == txt1__termchbi(t)) {
        tracef0("exit sbmb 0.\n");
        return; /* nothing to be done. */
      };
    };

    caret = 0 != (txt_CARET & t->charoptionset);
    txt1__hidecaret(t);
    t->charoptionset &= ~txt_CARET;
    if (byy > (3*t->w->limy) / 4) {
      txt1_domovevertical(t, by, FALSE);
    } else {
      tracef2("scroll by %i %i.\n", by, byy);
      if (by > 0) {/* advance in the array */
        caretinbounds = t->w->carety + t->w->caretoffsety <= t->w->limy;
        copyfirst = t->w->carety + t->w->caretoffsety > byy + t->w->linesep;
        if (caretinbounds && (! copyfirst)) {
          txt1_domovevertical(t, by, FALSE);
        };
        if (t->w->rawcopylines(t, byy, 0, t->w->limy - byy)) {
          txt1__incfirst(t, byy);
          txt1__inclast(t, byy);
          /* position the caret */
          t->w->carety -= byy;
          txt1__paintallcalls(t);
        } else {
          t->w->carety -= byy;
          txt1__redisplaytext(t, TRUE);
        };
      } else { /* retreat in the array */
        caretinbounds =
          t->w->carety + t->w->caretoffsety
            >= txt1__min(t->w->linesep, t->w->limy);
        copyfirst = t->w->carety + t->w->caretoffsety < t->w->limy - byy;
        if (caretinbounds && (! copyfirst)) {
          txt1_domovevertical(t, by, FALSE);
        };
        if (t->w->rawcopylines(t, 0, byy, t->w->limy - byy)) {
          if (! txt1__decfirst(t, byy)) {
            t->w->carety += byy;
            txt1__redisplaytext(t, TRUE);
          } else {
            txt1__declast(t, byy);
            /* adjust caret */
            t->w->carety += byy;
            txt1__paintallcalls(t);
          };
        } else {
          t->w->carety += byy;
          txt1__redisplaytext(t, TRUE);
        };
      };
      if (caretinbounds && copyfirst) {txt1_domovevertical(t, by, FALSE);};
      txt1__updatescrollbar(t);
    };
    if (caret) t->charoptionset |= txt_CARET;
    txt1__showcaret(t);
}

txt_index txt1_windowcoordstoindex(txt t, txt1_zits x, txt1_zits y)
/* >>>> need an xlim arg on measure to do this! */
/*      need it for vertical movement, too. */
{
  txt1_zits x1;
  txt1_zits y1;
  txt1_bufindex at;
  txt_index i;

    x1 = t->w->caretx;
    y1 = t->w->carety;
    at = t->gapend;
    if
      (y > t->w->carety
    ||
      (y > t->w->carety-t->w->linesep && x >= t->w->caretx)
    ) {/* forwards of cursor */
      txt1__measure(t, &x1, &y1, y, &at, txt1__termchbi(t), FALSE);
    } else { /* backwards from cursor */
      (void) txt1__measureback(t, &x1, &y1, y, &at, txt1__firstchbi(t), FALSE);
    };
    txt1__cancelallcalls(t);
    txt1__horizmeasure(t, x1, x, &at);
    i = txt1__bufindextoindex(t, at);
    tracef3("windowcoordstoindex (%i,%i) = %i.\n", x, y, i);
    return i;
}
/* end */
