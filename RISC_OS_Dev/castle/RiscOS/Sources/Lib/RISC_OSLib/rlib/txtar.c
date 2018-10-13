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
 * Title: c.txtar
 * Purpose: system-dependent parts of text module
 *          arthur/wimp version
 * Author: WRS
 * Status: under development
 * History:
 *  4 august 87 -- split off from initial simple version
 *  16-Jan-88: WRS: conversion into C started.
 *  15-Mar-88: WRS: improvements for inverted 1-bpp fonts
 *  18-Mar-88: WRS: bug in non-TRACE form found.
 *  21-Jun-88: WRS: DATASAVE passed on with DATALOAD as a sh-F2 key.
 *  13-Dec-89: WRS: msgs literal text put back in.
 *  12-Feb-90: IDJ: added user-setting of work area (reset on mode change to max chars for
 *                  screen mode).
 *  21-Feb-90: IDJ: added use of txtopt_get_name for option setting
 *  12-Jun-91: IDJ: made buffer size large enough for reading edit$options
 *  13-Jun-91: IDJ: only write work are edit$option if set in menu
 *  17-Jun-91: IDJ: hourglass on around redraws, because it can be slow!
 *  28-Jun-91: IDJ: experiments with edit$options and wordwrap,overwrite,coltab
 *  01-Jul-91: IDJ: fixed txtar__readoptnum to read numbers properly!!!!!
 *  08-Aug-91: IDJ: 2 sec delay then hourglass around redraws
 *  10-Feb-94: WRS: fix in call to wimpt_checkmode for VIDC20 machines
 */

#define BOOL int
#define TRUE 1
#define FALSE 0
#define NULL 0

#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>

#include "os.h"
#include "swis.h"
#include "bbc.h"
#include "dbox.h"
#include "werr.h"
#include "akbd.h"
#include "wimp.h"
#include "wimpt.h"
#include "font.h"
#include "trace.h"
#include "win.h"
#include "menu.h"
#include "event.h"
#include "xferrecv.h"
#include "visdelay.h"
#include "msgs.h"

#include "txt.h"
#include "EditIntern/txtundo.h"
#include "EditIntern/txt1.h"
#include "EditIntern/txt3.h"
#include "EditIntern/txtar.h"
#include "txtscrap.h"
#ifdef SETOPTIONS
#include "txtopt.h"
#endif
#include "VerIntern/messages.h"

#define UNICODE
#define WIMPSETFONTCOLOUR TRUE
#define INVERTSELECTION TRUE

/*#ifdef UNICODE
#include "utf8.h"
#endif*/

/* -------- Forward references -------- */

static void txtar__redrawtext(txt t);

static void txtar__fontpaintseveral(txt, txt1_call *, wimp_box *, BOOL);

static void txtar__doopenevent(txt t, wimp_openstr *o /*in*/);

static void txtar__dobuttonevent(txt t, wimp_eventstr *e /*in*/);

static void txtar__docharevent(txt t, txt_eventcode e);

static void txtar__dodrag(txt t);

static void txtar__dothumb(txt t, int offset);

/* -------- Data for each window. -------- */

#define TITLEBUFMAX 260
#define MAXSYSVARSIZE 256

typedef struct txtar__sysdata {         /* state for an Arthur/Wimp text window. */
  txt t; /* back pointer, needed cos many windows per text */
  struct txtar__sysdata *next; /* list of them all, mainly for caret stuff bodge. */
  wimp_w w;
  wimp_winfo *d;
  BOOL showing;
  char titlebuf[TITLEBUFMAX+1];
  txtar_options o; /* font/colour stuff */
  font fh;
  int baselineoffset;
    /* In os coords, distance from the bottom of the loop of a "g" or
    "y" to where font characters should actually be painted. */
  int italicstripe;
    /* In os coords, the max that a char will overlap to the right
    (in the current font) of where the char claims it ends. e.g. the
    top scroll of an italic "f". */

  int screenmode; /* beeb screen mode */
  int sysfontwidth;  /* in OS-units: mode-dependent */
  int sysfontheight; /* in OS-units: mode-dependent */
  int windowwidth; /* in OS-units, incl scroll bar: mode-dependent */
  int scrollbarwidth; /* windowwidth - (d->info.box.x1 - d->info.box.x0) */

  int imagewidth; /* in os coords */

  int prevmousex;
  int prevmousey;   /* for spotting exact multi-clicks */
  int prevmousetime; /* centisecond count value. */
  BOOL freshredisplay;
} txtar__sysdata;
/* If a setextent happens (I think) after a window is zoomed, the wimp thinks
of this as ending the zoom so that an un-zoom causes no change. Thus, we have
to save the before-zoom box ourselves and synthesise things. See openevent
for this. */

/* the "imagewidth" field is concerned with horizontal scrolling of the
file within the window imagewidth excludes the left hand pixel border. */

/* -------- Static variables -------- */

static txtar__sysdata *all = NULL; /* list of all sysdata records. */

static BOOL txtar__withinredraw = FALSE;   /* see txtar__redrawwindow */
static BOOL txtar__redrawdone = FALSE;
static wimp_redrawstr txtar__redrawdata;
static BOOL txtar__setsizepending = FALSE;

static BOOL txtar__thumbing = FALSE;
static wimp_mousestr txtar__lastthumbmouse = {0, 100000, 0, 0, 0};
static int txtar__lastthumbdir = 0; /* >= 0 for forwards, <0 for back. */
/* With the continuous-thumbing addition to the wimp, there is a problem
in that continuous redrawing can be caused. We add this kludge: that if
a thumb event arrives, and the current mouse position is the same as the
previous thumb event, we ignore the thumb. */

/* Stuff about disposing of all font handles if the program dies suddenly. */
static BOOL txtar__closefontsregistered = FALSE;

/* -------- Creating and destroying windows. -------- */

#define INITSTARTY 0
static txt1_zits txtar__startx = 100;
static txt1_zits txtar__starty = INITSTARTY;
#define CREATESIZEX (1080-44)
#define CREATESIZEY 448

static int txtar__xppinch(void)
{
  return 180 / wimpt_dx();
}

static int txtar__yppinch(void)
{
  return 180 / wimpt_dy();
}

static int txtar__screenwidth(void)
{
  return (1 + bbc_vduvar(bbc_XWindLimit)) << bbc_vduvar(bbc_XEigFactor);
}

static int txtar__screenheight(void)
{
  return (1 + bbc_vduvar(bbc_YWindLimit)) << bbc_vduvar(bbc_YEigFactor);
}

static int txtar__max(int a, int b) {return(a > b ? a : b);}

static int txtar__min(int a, int b) {return(a < b ? a : b);}

static void txtar__setmode(txtar__sysdata *s) {
  txt t = s->t;
#ifdef BIG_WINDOWS
  int screenwidth = (1 + bbc_vduvar(bbc_XWindLimit)) << bbc_vduvar(bbc_XEigFactor);
#endif

  t->w->highlight_reversable = wimpt_bpp() <= 4;
  s->screenmode = wimpt_mode();
  s->sysfontwidth = wimpt_dx() * bbc_vduvar(bbc_GCharSpaceX);
  s->sysfontheight = wimpt_dy() * bbc_vduvar(bbc_GCharSpaceY);
#ifdef BIG_WINDOWS
  if (!s->o.big_windows)
      s->o.big_window_size = txtar__min(screenwidth/s->sysfontwidth - 3 /*scrollbar*/, BIG_WINDOW_SIZE_LIMIT);
#endif
}

static void txtar__settextlimits(txt t)
/* The window has changed shape or something, calculate text limits etc. in
preparation for a total redraw. this will in turn set things to do with
scroll bar, etc. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_winfo *d = s->d;
  wimp_redrawstr r;

    r.w = s->w;
    wimp_getwindowoutline(&r);
    s->windowwidth = r.box.x1 - r.box.x0;
    s->scrollbarwidth = s->windowwidth - (d->info.box.x1 - d->info.box.x0);
    s->imagewidth = d->info.box.x1 - d->info.box.x0 - wimpt_dx();
      /* the one pixel is the left hand border within the window. */

    if (! s->o.wraptowindow) {
#ifdef BIG_WINDOWS
       if (!s->o.big_windows)
#endif
          s->imagewidth = txtar__screenwidth() - (s->windowwidth - s->imagewidth);
#ifdef BIG_WINDOWS
       else
          s->imagewidth = s->o.big_window_size * s->sysfontwidth - wimpt_dx();
#endif
      /* if not wrapping at window, set width to screen - scroll bar. */
    };
    t->w->limx = wimpt_dx() + s->imagewidth;
    t->w->limy = d->info.box.y1 - d->info.box.y0;
    t->w->limx = (t->w->limx / wimpt_dx()) * (72000 / txtar__xppinch());
    tracef2("txtar__settextlimits -> t->w->limx=%i t->w->limy=%i.\n",
      t->w->limx, t->w->limy);
}

/* Verification of various things. */
#if TRACE
void txtar__checkwinfo(txt t)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_winfo d;
  d.w = s->w;
  wimpt_noerr(wimp_get_wind_info(&d));

    if ((s->d->info.box.x0 != d.info.box.x0) ||
       (s->d->info.box.y0 != d.info.box.y0) ||
       (s->d->info.box.x1 != d.info.box.x1) ||
       (s->d->info.box.y1 != d.info.box.y1)
    ) {
      tracef("**  screenbox:(%i,%i,%i,%i).\n",
        s->d->info.box.x0, s->d->info.box.y0, s->d->info.box.x1, s->d->info.box.y1);
      tracef("**          v:(%i,%i,%i,%i).\n",
        d.info.box.x0, d.info.box.y0,
        d.info.box.x1, d.info.box.y1);
    };
    if ((s->d->info.ex.x0 != d.info.ex.x0) ||
       (s->d->info.ex.y0 != d.info.ex.y0) ||
       (s->d->info.ex.x1 != d.info.ex.x1) ||
       (s->d->info.ex.y1 != d.info.ex.y1)
    ) {
      tracef("**  wbox:(%i,%i,%i,%i).\n",
        s->d->info.ex.x0, s->d->info.ex.y0, s->d->info.ex.x1, s->d->info.ex.y1);
      tracef("**     v:(%i,%i,%i,%i).\n",
        d.info.ex.x0, d.info.ex.y0,
        d.info.ex.x1, d.info.ex.y1);
    };
}
#endif

static void txtar__verify(txtar__sysdata *s) {
/* Check that the we agree with the wimp on the size etc of the window. If we do
not, force a total redraw. In any case, ensure that s->d is totally up to date. */

  wimp_winfo wi;
  BOOL sizechange;

  wi.w = s->w;

  /* Now read it back and, if the size is wrong, call settextlimits. */
  wimpt_noerr(wimp_get_wind_info(&wi));
  sizechange = (wi.info.box.x1 - wi.info.box.x0 !=
                s->d->info.box.x1 - s->d->info.box.x0) ||
               (wi.info.box.y1 - wi.info.box.y0 !=
                s->d->info.box.y1 - s->d->info.box.y0);
  *(s->d) = wi; /* Keep our copy up to date. */
  if (sizechange) {
    tracef0("size change in openandverify forces total redraw.\n");
    txtar__settextlimits(s->t);
    txtar__redrawtext(s->t);
  };
}

static void txtar__openandverify(txtar__sysdata *s)
/* Open the window described, and keep the windowdesc up to date. */
{
  wimp_openstr d;

  s->d->w = s->w;

  d.w = s->w;
  d.box = s->d->info.box;
  d.x = s->d->info.scx;
  d.y = s->d->info.scy;
  d.behind = (wimp_w) -1;

  wimpt_noerr(wimp_open_wind(&d));
  txtar__verify(s);
}

static void txtar__dohide(txt t)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  tracef0("textarthur.dohide\n");
  if (! s->showing) {
    tracef0("already hidden.\n");
  } else {
    s->showing = FALSE;
    win_activedec();
    wimpt_noerr(wimp_close_wind(s->w));
  };
}

static void txtar__doshow(txt t)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;

  tracef0("textarthur.doshow\n");
  if (s->showing) {
    tracef0("already showing\n");
  } else {
    s->showing = TRUE;
    win_activeinc();
    txtar__openandverify(s);
    txtar__settextlimits(t);
  };
  txtar__redrawtext(s->t);
  tracef0("doshow done.\n");
}

static void txtar__dosettitle(txt t, char *title)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_redrawstr r;

  tracef0("dosettitle.\n");
  strncpy(&s->titlebuf[0], title, TITLEBUFMAX);
  s->titlebuf[TITLEBUFMAX] = 0;
  r.w = (wimp_w) -1; /* redraw in absolute screen coords */
  r.box = s->d->info.box;
  r.box.y1 += 36;
  r.box.y0 = r.box.y1 - 36;
  wimpt_noerr(wimp_force_redraw(&r));
}

static void txtar__disposewindow(txt t)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_caretstr caret;
  BOOL havecaret;

  tracef0("txtar_disposewindow.\n");
  wimpt_noerr(wimp_get_caret_pos(&caret));
  havecaret = caret.w == s->w;
  win_register_event_handler(s->w, (win_event_handler) NULL, 0);
  tracef0("event handler registered.\n");
  wimpt_noerr(wimp_delete_wind(s->w));
  if (s->showing) win_activedec();
  if (! s->o.fixfont) wimpt_noerr(font_lose(s->fh));
  if (havecaret) win_give_away_caret();
  tracef0("window deleted.\n");

  {
    /* Delete s from the list of all such things. */
    txtar__sysdata **p = &all;
    while (1) {
      if (*p == 0) {
        werr(TRUE, msgs_lookup(MSGS_txt50));
      };
      if (*p == s) {
        *p = (*p)->next;  /* cut it out of the chain */
        break;
      };
      p = &((*p)->next);
    };
  };

  free(s->d);
  free(s);
  tracef0("disposewindow done.\n");
}

/* -------- Arthur-specific Public Operations. -------- */

static int txtar__dosyshandle(txt t)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  return (int) s->w; /* suitable for hanging menus on */
}

void txtar_getoptions(txt t, txtar_options *o /*out*/)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  *o = s->o;
}

static void txtar__trynofont(txt t)
/* >>>> messy split between this and setoptions */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  t->w->italic = FALSE;
  s->o.fixfont = TRUE;
  t->w->linesep = s->sysfontheight + (s->o.leading < 0 ? 0 : s->o.leading) * wimpt_dy();
  /* 20-Dec-88 WRS: negative line spacing ignored in system font. */
}

static void txtar__closefonts(void) {
  txtar__sysdata *p = all;
  while (p != 0) {
    if (! p->o.fixfont) {
      wimpt_noerr(font_lose(p->fh));
    };
    p = p->next;
  };
}

static BOOL txtar__tryfont(txt t, char *fontname, int width, int height)
{
  font f;
  font_info info;
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
#if TRACE
  int version;
  int cacheused;
  int cachesize;
  font_def d;
#endif
  os_error *e;

  if (! txtar__closefontsregistered) {
    atexit(txtar__closefonts);
    txtar__closefontsregistered = TRUE;
  };

#if TRACE
  font_cacheaddress(&version, &cacheused, &cachesize);
  tracef3(" font: %i %i %i.\n",
    version, cacheused, cachesize);
#endif
  e = font_find(fontname, width*16, height*16, 0, 0, &f);
  tracef1(" fonth=%i.\n", f);
  if (f == (font) NULL || e != NULL) {
    tracef0("font not found.\n");
    werr(FALSE, e->errmess);
    return FALSE;
  };

  s->o.fixfont = FALSE;

  s->fh = f;
#if TRACE
  font_readdef(f, &d);
  tracef4("font def: %i %i %i %i",
    d.xsize, d.ysize, d.xres, d.yres);
  tracef2(" %i %i.\n", d.usage, d.age);
#endif

  font_readinfo(f, &info);

#if TRACE
  tracef4(" minx=%i miny=%i maxx=%i maxy=%i.\n",
    info.minx, info.miny, info.maxx, info.maxy);
#endif

#if FALSE
  t->w->italic = info.minx < 0; /* >>>> bad fonts around */
#else
  t->w->italic = TRUE; /* 20-Dec-88 WRS: all fonts now italic. */
#endif

#if TRACE
    if (t->w->italic) {
      tracef("**this font looks italic.\n");
    };
#endif

  t->w->linesep = info.maxy - info.miny;

  if (t->w->linesep % wimpt_dy() != 0) {
#if FALSE
    werr(FALSE, "bad line separation in font");
#endif
    t->w->linesep = t->w->linesep - t->w->linesep % wimpt_dy();
    t->w->italic = TRUE;
  };
  s->baselineoffset = /* wimpt_dy() */ - info.miny;
  s->italicstripe = -info.minx;
  /* s->italicstripe = info.maxx / 3; */

#if FALSE
  /* some fonts seem to give this in pixels? */
  if (t->w->linesep < 2 * height) {
    /* guard against bad fonts */
    werr(FALSE, "bad height in font");
    t->w->italic = TRUE;
    t->w->linesep = 3 * height;
    s->baselineoffset = t->w->linesep / 3 - wimpt_dy(); /* in os coord units */
      /* >>>> why subtract the wimpt_dy()? */
      /*      seems to get it wrong if you don't! */
    s->italicstripe = 0;
  };
#endif

  t->w->linesep += s->o.leading * wimpt_dy();
  if (t->w->linesep < wimpt_dy()) t->w->linesep = wimpt_dy(); /* silly case! */
#if FALSE
  if (s->o.leading > 0) {
    s->baselineoffset += wimpt_dy() * (s->o.leading / 2);
  };
#else
  /* 19-Sep-89 - improvement of caret offset when leading is negative. */
  s->baselineoffset += wimpt_dy() * (s->o.leading / 2);
#endif

  t->w->linesep += 2 * wimpt_dy();
  s->baselineoffset += wimpt_dy();
  /* >>>> This is a kludge! - it appears to be necessary because either the
  fonts, or the fontmgr, are lying about the true possible height of chars. */

  return TRUE;
}

static void txtar__dosetoptions(txt t, txtar_options *o /*in*/)
/* Set s->o, and make the rest of the object follow it. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  txtar_options previous = s->o;
  font previousfont = s->fh;

  s->o = *o;
  if (s->o.fontwidth <= 0) s->o.fontwidth = 10;
  if (s->o.fontheight <= 0) s->o.fontheight = 10;
  if (s->o.fixfont) {
    txtar__trynofont(t);
  } else {
    if (! txtar__tryfont(t, &s->o.fontname[0],
                         s->o.fontwidth, s->o.fontheight)) {
      s->o = previous; /* restore existing state. */
      return; /* no need to redraw */
    };
  };
  if (! previous.fixfont) {
    wimpt_noerr(font_lose(previousfont));
  };
  txtar__settextlimits(t);
  txtar__setsizepending = TRUE;
}

void txtar_setoptions(txt t, txtar_options *o /*in*/)
{
  txtar__dosetoptions(t, o);
  {
    char a[MAXSYSVARSIZE];
    txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
#ifdef SETOPTIONS
    strcpy(a, "Set ");
    strncat(a, txtopt_get_name(), MAXSYSVARSIZE-1);
    strncat(a, "$Options", MAXSYSVARSIZE-1);
    sprintf(a+strlen(a), " f%i b%i l%i m%i h%i w%i%s",
      s->o.forecolour,
      s->o.backcolour,
      s->o.leading,
      s->o.margin,
      s->o.fontheight,
      s->o.fontwidth,
      (s->o.wraptowindow ? " r" : ""));
#else
    sprintf(a, "Set Edit$Options f%i b%i l%i m%i h%i w%i%s",
      s->o.forecolour,
      s->o.backcolour,
      s->o.leading,
      s->o.margin,
      s->o.fontheight,
      s->o.fontwidth,
      (s->o.wraptowindow ? " r" : ""));
#endif
#ifdef SET_MISC_OPTIONS
    if (s->o.overwrite) strcat(a, " O");
    if (!s->o.wordtab) strcat(a, " T");
    if (s->o.wordwrap) strcat(a, " D");
    if (s->o.undosize != 5000) sprintf(a+strlen(a), " u%i", s->o.undosize);
#endif
#ifdef BIG_WINDOWS
    if (s->o.big_windows)
    {
       sprintf(a+strlen(a), " a%i", s->o.big_window_size);
    }
#endif
    if (! s->o.fixfont) {
      strcat(a, " n");
      strcat(a, s->o.fontname);
    };

    wimpt_complain(os_cli(a));
  };
  txtar__redrawtext(t); /* in case of colour/font change */

}

/* -------- Painting. -------- */

#define PAINTBUFSIZE 484
#ifdef BIG_WINDOWS
#if (BIG_WINDOW_SIZE_LIMIT+4) > PAINTBUFSIZE
#error "Can't paint that window reliably"
#endif
#endif

static void txtar__rawsetsize(txt t)
/* We can count on t->s->d being accurate about the current state of
things. We must reset the extent of the work area so that arthur redraws
the scroll bars for us. */
/* >>>> Should optimise the case of no change, to not call wimp */
/* in cases where size < screen height, I provide a minimum size
so that drag-size-change works. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_redrawstr e;
  int vissize;
  int size;
  int offset;

    tracef2("textarthur.rawsetsize %i %i\n",
      t->w->ioffset, t->w->isize);
    if (txtar__withinredraw) {
      /* the wimp doesn't like you doing this in a redraw-> */
      /* redraw always ends with one of these with withinredraw==FALSE. */
      tracef0("  (setsize delayed).\n");
      txtar__setsizepending = TRUE;
      return;
    };
    if (t->w->isize == 0) {
      tracef0("  setsize ignored, size=0.\n");
      return;
    };
    if (t->w->isize + t->w->ioffset > 100) {
      t->w->ioffset = 100 - t->w->isize;
    };
#if TRACE
    txtar__checkwinfo(t);
#endif
    vissize = s->d->info.box.y1 - s->d->info.box.y0;
    size = (vissize * 100) / t->w->isize; /* w->isize is a percentage */
    /* size / 100 is the amount of space taken up to represent
    one percent of the file. */
    offset = (size * t->w->ioffset) / 100;
    if (size - offset < vissize) {
      tracef3("bad setsize! size=%i offset=%i vissize=%i.",
        size, offset, vissize);
    };
/* >>>> partial fix, see improved one below->
    if (size < 1024) size = 1024;
*/
    if (offset-size > -txtar__screenheight()) {
      /* This is a danger in two ways. If size<1024 then the wimp won't
      allow a drag-size-change very big, and limits the size of zooms.
      If size>1024 but e.y0>-1024 then a large size increase can
      only generate an open event that moves the origin of the display
      area. This makes the world go generally screwy, with the inabilty
      to do open+setextent in one operation as the main problem. */
      size = txtar__screenheight() + offset;
    };
    tracef1("  size=%i.\n", size);
    e.w = s->w;
    e.box.x0 = 0;
    e.box.y0 = offset - size;
#ifdef BIG_WINDOWS
    if (s->o.big_windows && !s->o.wraptowindow)
      e.box.x1 = s->o.big_window_size*s->sysfontwidth + wimpt_dx();
    else
#endif
    e.box.x1 = txtar__screenwidth() - s->scrollbarwidth;
      /* imagewidth no good, because you can't then drag it wider. */
    e.box.y1 = offset;
    tracef2("  setting miny=%i maxy=%i.\n", e.box.y0, e.box.y1);
    s->d->info.ex = e.box;
    wimpt_noerr(wimp_set_extent(&e));
#ifdef BIG_WINDOWS
    /* IDJ 12-Feb-90: this seems necessary */
    if (s->o.big_windows)
    { wimp_wstate ws;
      wimp_get_wind_state(s->w, &ws);
      wimp_open_wind(&ws.o);
    }
#endif
}
/* >>>> If it's necessary to squeeze more performance out of the scrolling
display of text, it would be possible to delay calls to rawsetsize until
until a null event came along. this would reduce redrawing of the scroll bar.
An out counter would probably be necessary too, to force update every few
lines of output. avoid this for now. */

/* >>>> It would also be nice if, during a scroll, the size of the "blob"
did not change. Its current wobbling is rather disconcerting to the user,
and could be quietly minimised. e.g. only wobble if it changes in size by
more than a pixel. This is already fixed, to some extent, in txt1, but
the wimp can wobble the size by up to one pixel without me being able to
affect it. */

static char txtar__hexch(int c)
{
  c = c % 16;
  if (c < 10) {
    return '0' + c;
  } else {
    return 'a' + c - 10;
  };
}

static int txtar__charwidth(char c) {
/* Measure the width of a single character. */
/* The font must already be set up using font_setfont. */
  font_string str;
  char a[2];
  a[0] = c;
  a[1] = 0;
  str.s = &a[0];
  str.x = 10000000;
  str.y = 10000000;
  str.split = -1;
  str.term = 1;
  wimpt_noerr(font_strwidth(&str));
  return(str.x);
}

#if FALSE
static int txtar__UCScharwidth(UCS4 c) {
/* Measure the width of a UCS character. */
/* The font must already be set up using font_setfont. */
  os_regset regs;
  UCS4 a[2];

  a[0] = c;
  a[1] = 0;

  regs.r[1] = (int) a;
  regs.r[2] = font_32BIT | font_LENGTH;
  regs.r[3] = 10000000;
  regs.r[4] = 10000000;
  regs.r[7] = 4;
  wimpt_noerr(os_swix(Font_ScanString, &regs));
  return(regs.r[3]);
}
#endif

static void txtar__expandchars(
  txtar__sysdata *s,
  char *a,
  int n,                          /* number of chars */
  char *cbuf /*out*/,             /* where to put expanded chars */
  short *obuf /*out*/,            /* matching offset into original string */
  int bufsize,                    /* cbuf and obuf sizes */
  int *nchars /*inout*/)          /* no of output chars */
/* Expands the characters of the string out into the buffer, with funny
characters being replaced by [xx]. Expands out the string (zero-terminating
this) and builds a matching table of offsets so that, if measure stops
half-way through, you can tell instantly how far you got in the original
string. Buffer sizes within 5..255. */
/* If nchars!=0 on entry it implies that there are some characters already in
place. Thus, this can be used to combine strings from several sources. This
is what happens in fontpaintseveral, to improve drawing of italic fonts. */
{
  int srci = 0;
  int dsti = *nchars;
  char c;
#ifdef UNICODE
  int alphabet=127, dummy;

  os_byte(71, &alphabet, &dummy); /* Read current alphabet number */
#endif

  tracef2("expandchars ad=%i n=%i.\n", (int) a, n);
  while (1) {
    if (dsti >= bufsize - 4) break;
    if (srci >= n) break;
#ifdef UNICODEx
    if (alphabet == 111) {
      int l = UTF8_to_UCS4(a+srci, &c);
      if (c < 32 || c == 127 || (c>=256 && s->o.fixfont)
          || (c >= 127 && (! s->o.fixfont) && txtar__UCScharwidth(c) == 0)
      ) {
        /* funny character */
        cbuf[dsti] = '[';
        obuf[dsti++] = srci;
        if (c & 0xF0000000) {
          cbuf[dsti] = txtar__hexch(c >> 28);
          obuf[dsti++] = srci;
        }
        if (c & 0xFF000000) {
          cbuf[dsti] = txtar__hexch(c >> 24);
          obuf[dsti++] = srci;
        }
        if (c & 0xFFF00000) {
          cbuf[dsti] = txtar__hexch(c >> 20);
          obuf[dsti++] = srci;
        }
        if (c & 0xFFFF0000) {
          cbuf[dsti] = txtar__hexch(c >> 16);
          obuf[dsti++] = srci;
        }
        if (c & 0xFFFFF000) {
          cbuf[dsti] = txtar__hexch(c >> 12);
          obuf[dsti++] = srci;
        }
        if (c & 0xFFFFFF00) {
          cbuf[dsti] = txtar__hexch(c >> 8);
          obuf[dsti++] = srci;
        }
        if (c & 0xFFFFFFF0) {
          cbuf[dsti] = txtar__hexch(c >> 4);
          obuf[dsti++] = srci;
        }
        cbuf[dsti] = txtar__hexch(c);
        obuf[dsti++] = srci;

        cbuf[dsti] = ']';
        obuf[dsti++] = srci;
      }
      else {
        memcpy(cbuf+dsti, a+srci, l);
        memset(obuf+dsti, srci, l);
        dsti+=l;
      }
      srci+=l;
    }
    else {
#endif
    c = a[srci];
    if (c < 32 || c == 127
        || (c >= 127 /* && c < 128+32 */ && (! s->o.fixfont) && alphabet != 111 && txtar__charwidth(c) == 0)
    ) {
      /* funny character */
      cbuf[dsti] = '[';
      cbuf[dsti+1] = txtar__hexch(c >> 4);
      cbuf[dsti+2] = txtar__hexch(c);
      cbuf[dsti+3] = ']';
      obuf[dsti] = srci;
      obuf[dsti+1] = srci;
      obuf[dsti+2] = srci;
      obuf[dsti+3] = srci;
      dsti += 4;
    } else {
      cbuf[dsti] = c;
      obuf[dsti] = srci;
      dsti++;
    };
    srci++;
#ifdef UNICODEx
    }
#endif
  };
  *nchars = dsti;
  cbuf[dsti] = 0;
  obuf[dsti] = srci;
  tracef2("exit nchars=%i obuf[nchars]=%i.\n",
    *nchars, obuf[*nchars]);
}

#if TRACE
void txtar__safewrch(char c)
{
  if ((c >= 32) && (c < 127)) {
    tracef1("%c", c);
  } else {
    tracef1("(%i)", c);
  };
}
#endif

static void txtar__rawmeasure(
  txt t,
  char **ad /*inout*/,
  int *n /*inout*/,
  int *spacewidth /*inout*/) /* initially max allowed */
/* There is an annoying mismatch here between the arthur facilities and
the facilities that we require. The trouble is that control characters
in the text object must be expanded out in order to build [xx] sequences. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  char cbuf[PAINTBUFSIZE];
  short obuf[PAINTBUFSIZE];
  int nchars;
  int ncharsdone;
  int x;
  int nhalfdone;
#if TRACE
  int i;
#endif
  font_string str;

#if TRACE
  tracef3("fontmeasure %i %i %i (", (int) *ad, *n, *spacewidth);
  for (i=0; i<*n; i++) txtar__safewrch((*ad)[i]);
  tracef0(")\n");
#endif

  if (! s->o.fixfont) {
    /* Set current font. */
    /* >>>> Any way of optimising this? not particularly simple... */
    wimpt_noerr(font_setfont(s->fh));
  };

  while (TRUE) {
    ncharsdone = 0;
    txtar__expandchars(s, *ad, *n, &cbuf[0], &obuf[0], PAINTBUFSIZE, &ncharsdone);
    nchars = ncharsdone;
    x = *spacewidth;
    if (s->o.fixfont) {
      int fixfontw = 400 * s->sysfontwidth;
        /* width in millipoints: 400 == 72000/180 */
      if (nchars * fixfontw > x) {
        /* we are space limited */
        nchars = x / fixfontw;
        /* align to whole text char */
        while (nchars > 0 && obuf[nchars] == obuf[nchars-1]) nchars--;
      };
      x = nchars * fixfontw;
    } else {
      str.s = &cbuf[0];
      str.x = x;
      str.y = 10000000; /* no limits imposed on y space consumed */
      str.split = -1;
      str.term = nchars;
      wimpt_noerr(font_strwidth(&str));
      nchars = str.term;
      x = str.x;
    };
    *spacewidth -= x;
    if (nchars != ncharsdone  /* not enough space even for that much */
    || obuf[ncharsdone] == *n  /* finished all chars */
    ) {                       /* we'll be exiting soon */
      *ad += obuf[nchars];
      *n -= obuf[nchars];
      if (*n != 0) {
        nhalfdone = 0;
        while (nchars > 0
        && obuf[nchars] == obuf[nchars-1]
        ) {
          /* half-way through expanded char: see explanation below. */
          tracef0("half-way through expanded char.\n");
          nchars--;
          nhalfdone++;
        };
        if (nhalfdone != 0) {
          str.x = 10000000;
          str.y = 10000000;
          str.split = -1;
          str.term = nhalfdone;
          wimpt_noerr(font_strwidth(&str));
          tracef1("added %i back again\n", x);
          x = str.x;
          nhalfdone = str.term;
          *spacewidth += str.x;
        };
      };
      break;
    } else {                      /* we have to do another buffer-full */
      *ad += obuf[nchars];
      *n -= obuf[nchars];
      /* and loop */
    };
  };
  tracef3("        returning %i %i %i\n", (int) *ad, *n, *spacewidth);
}
/* >>>> If one character expands to many then the font stuff is not right at
the moment, if there's not enough room for the expanded character then our x
return currently deducts what display characters of the expanded character
did fit. */

/* If the thing is going to be space-limited and in fact is met very early,
we wastefully expand out bufmax characters. Could try to estimate things,
based on the width of a space or something. Not particularly important. */

/* >>>> Change to references to BBC. */

static void txtar__grmoveto(int x, int y)
{
  bbc_plot(4, x, y);
}

static void txtar__setgrcolour(int c)
{
  wimp_setcolour(c);
  /* colour in 0..3, gcol action in 4..6, fg/bg in 7 */
}

static void txtar__paintseveral(
  txt t,
  txt1_call *calls,
  wimp_box *grclip /*in*/,
  BOOL alreadycorrect)
/* As in measure, expandchars is used to handle control chars etc. in the
text. The one procedure paints several calls at once so that adjacent calls
that form part of the same line can be combined into a single call. This is
done here because it's where the characters have to be copied anyway. */
/* >>>> There is quite a lot duplicated between here and fontpaintseveral,
perhaps some work could be done to reduce this. */

{
 txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
 txt1_call thiscall;
#if TRACE
 int i;
#endif
 int scx;
 int scy;
 char cbuf[PAINTBUFSIZE];
 short obuf[PAINTBUFSIZE];
 int nchars;

  if (! s->o.fixfont) {
    txtar__fontpaintseveral(t, calls, grclip, alreadycorrect);
    return;
  };

  alreadycorrect &= (wimpt_bpp() <= 4);
  /* XORing doesn't work in 8-bpp modes. */

  while (calls != NULL) {

#if TRACE
    tracef3("paint at (%i,%i) %i:'", calls->x, calls->y, calls->n);
    for (i=0; i<calls->n; i++) txtar__safewrch(calls->ad[i]);
    tracef3("', %i, %i, %i\n",
      calls->width, calls->highlight, calls->callendopt);
    if (alreadycorrect) tracef("inverting display.\n");
#endif

    thiscall = *calls;
    calls = calls->next;

    nchars = 0;
    txtar__expandchars(s, thiscall.ad, thiscall.n,
      &cbuf[0], &obuf[0], PAINTBUFSIZE, &nchars);

    while ((calls != NULL)
    && (thiscall.y == calls->y)
    && (thiscall.x + thiscall.width == calls->x)
    && (thiscall.highlight == calls->highlight)
    ) {
      tracef0("merge with following paint call.\n");
      thiscall.width += calls->width;
      thiscall.callendopt = calls->callendopt;

      txtar__expandchars(
        s, calls->ad, calls->n, &cbuf[0], &obuf[0], PAINTBUFSIZE, &nchars);
          /* add to existing ones */
      calls = calls->next;
    };

    scx = s->d->info.box.x0 - s->d->info.scx +
      wimpt_dx() * (s->o.margin + (thiscall.x * txtar__xppinch()) / 72000);
    scy = (s->d->info.box.y1 /* >>>> - wimpt_dy() */ ) - thiscall.y;

    if (
      scy + t->w->linesep < grclip->y0 ||
      scy > grclip->y1
    ) {
      tracef0("clipped.\n");
      /* go round the loop */
    } else {

      /* mark out the blanking box. */
      /* we blank out the left hand pixel column too if
      in the left hand char position, as not doing this can leave blobs. */
      if (scx == s->o.margin * wimpt_dx() + s->d->info.box.x0) {/* left hand edge */
        txtar__grmoveto(scx - s->o.margin * wimpt_dx(), scy);
      } else {
        txtar__grmoveto(scx, scy);
      };

      if (alreadycorrect) {
        tracef0("invert text line.\n");
        if (thiscall.width > 0) {
          txtar__setgrcolour(
            (s->o.forecolour ^ s->o.backcolour) +        /* GCOL colour */
            + (3<<4)); /* XOR action. */
          bbc_plot(101,
            scx + wimpt_dx() *
              ((thiscall.width * txtar__xppinch()) / 72000 - 1),
            scy + t->w->linesep - 1);
        } else {
          tracef0("null width, already correct: do nothing.\n");
        };
      } else {
        /* fill in the background */
        if (thiscall.highlight) {
          txtar__setgrcolour(128 + s->o.forecolour); /* hilight background */
        } else {
          txtar__setgrcolour(128 + s->o.backcolour); /* normal background */
        };
        /* abs fill rectangle with background */
        if ((thiscall.callendopt != txt1_CECONTINUE) && (! thiscall.highlight)) {
          bbc_plot(103, s->d->info.box.x1,
                        scy + t->w->linesep - 1);
        } else {
          bbc_plot(103, scx + wimpt_dx() *
                             ((thiscall.width * txtar__xppinch()) / 72000),
                        scy + t->w->linesep - 1);
        };

        /* and write the characters */
        if (thiscall.highlight) {
          txtar__setgrcolour(s->o.backcolour); /* hilight background */
        } else {
          txtar__setgrcolour(s->o.forecolour); /* normal background */
        };
        txtar__grmoveto(scx, scy + t->w->linesep - 1);
        /* writing chars to the graphics cursor causes the top pixel of
        the letter to be visible at the cursor pixel level. */
        bbc_vdu(5);
        bbc_stringprint(&cbuf[0]);
        if ((thiscall.callendopt != txt1_CECONTINUE) && thiscall.highlight) {
          /* must blank out a second box in paper colour */
          txtar__setgrcolour(128 + s->o.backcolour); /* normal background */
          txtar__grmoveto(scx + s->sysfontwidth * nchars, scy);
          bbc_plot(103, s->d->info.box.x1,
                        scy + t->w->linesep - 1);
        };
      };

      /* >>>> the use of system calls in setting colours etc could probably
      be tightened up a little. never mind about this for now. */

    };
  };
  tracef0("paintseveral done.\n");
}

#if WIMPSETFONTCOLOUR
#else

static void txtar__fonthilight(char *cbuf, int *n /*inout*/)
/* The sequence to turn on highlighting. */
{
#if INVERTSELECTION
        int bpp = wimpt_bpp();
        int cols = bpp == 8 ? 8 : (bpp == 4 ? 8 : 1 << bpp);
        cbuf[(*n)++] = 18;
        cbuf[(*n)++] = cols-1;
        cbuf[(*n)++] = cols-2;
        cbuf[(*n)++] = (2-cols) & 0xff;
#else
    /* underline */
    cbuf[(*n)++] = 25;
    cbuf[(*n)++] = 234;
      /* -32, offset from base line in 1/256 of height */
    cbuf[(*n)++] = 16; /* width of underline in same units */
#endif
}

static void txtar__fontnohilight(char *cbuf, int *n)
/* The sequence to turn off highlighting. */
{
#if INVERTSELECTION
        int bpp = wimpt_bpp();
        int cols = bpp == 8 ? 8 : (bpp == 4 ? 8 : 1 << bpp);
        cbuf[(*n)++] = 18;
        cbuf[(*n)++] = 0;
        cbuf[(*n)++] = 1;
        cbuf[(*n)++] = cols-2;
#else
    /* no underline */
    cbuf[(*n)++] = 25;
    cbuf[(*n)++] = 234;
    cbuf[(*n)++] = 0; /* no underline */
#endif
}
#endif

#ifndef UROM
static int txtar__roundtoxpix(int s) {
  return (s / wimpt_dx()) * wimpt_dx();
}
#endif

static int txtar__font_paint_error = FALSE;
/* >>>> There's a bug in 1.2 such that chr(18) sequences in the middle of a
string do not work. invert really is better than underline. must be
severely fudged, and will flicker, in 1.2 os. also, will not work for
disjoint selection portions. */
#define CHAR18BUG TRUE
/* Could make these variable if I wanted. */
/* >>>> Char 18 turns out not to help. Changes at the leading edge of
the character, not at the actual start of the character. */

static void txtar__fontpaintseveral(
  txt t,
  txt1_call *calls,
  wimp_box *grclip /*in*/,
  BOOL alreadycorrect)
/* As in measure, expandchars is used to handle control chars etc. in the
text. The one procedure paints several calls at once so that adjacent calls
that form part of the same line can be combined into a single call. This is
done here because it's where the characters have to be copied anyway. It
improves the display of italic characters. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  txt1_call thiscall;
#if TRACE
  int i;
#endif
  int scx;
  int scy;
  int mpx;       /* x,y in millipoints */
  int mpy;
  char cbuf[PAINTBUFSIZE];
  short obuf[PAINTBUFSIZE];
  int nchars;

  alreadycorrect &= (wimpt_bpp() <= 4);
  /* XORing doesn't work in 8-bpp modes. */

  if (s->o.forecolour <= 7
  && s->o.backcolour <= 7
  && s->o.forecolour + s->o.backcolour != 7)
  {
    /* anti-aliased grey scales that don't quite form an orderly
    sequence: XOR'ing won't work. */
    alreadycorrect = FALSE;
  };

  while (calls != NULL) {

  if (txtar__font_paint_error) return;

#if TRACE
    tracef3("fontpaint at (%i,%i) %i:'", calls->x,
      calls->y, calls->n);
    for (i=0; i<calls->n; i++) txtar__safewrch(calls->ad[i]);
    tracef3("', %i, %i, %i\n",
      calls->width, calls->highlight, calls->callendopt);
    if (alreadycorrect) tracef("inverting display.\n");
#endif

    thiscall = *calls;
    calls = calls->next;

    nchars = 0;
#if WIMPSETFONTCOLOUR
#else
    if ((thiscall.highlight != (s->o.forecolour < 4))) {
      txtar__fonthilight(&cbuf[0], &nchars);
    };
#endif
    txtar__expandchars(s, thiscall.ad, thiscall.n,
      &cbuf[0], &obuf[0], PAINTBUFSIZE, &nchars);

    while ((calls != NULL)
    && (thiscall.y == calls->y)
    && (thiscall.x + thiscall.width == calls->x)
/*  && (thiscall.highlight == calls->highlight) ( >>>> current restriction )*/
    &&
      ((thiscall.highlight == calls->highlight)
       ||
      (! INVERTSELECTION)
       ||
      (! CHAR18BUG))
   ) {
      tracef0("merge with following paint call.\n");
      thiscall.width += calls->width;
      thiscall.callendopt = calls->callendopt;

/* >>>> tried a colour change: seems to cause blank chars?
      cbuf[nchars++] = 17;
      cbuf[nchars++] = 0;
      cbuf[nchars++] = 17;
      cbuf[nchars++] = 128+7;
*/

#if WIMPSETFONTCOLOUR
#else
      if (thiscall.highlight != calls->highlight) {
        thiscall.highlight = calls->highlight;
        if ((thiscall.highlight != (s->o.forecolour < 4))) {
          txtar__fonthilight(&cbuf[0], &nchars);
        } else {
          txtar__fontnohilight(&cbuf[0], &nchars);
        };
      };
#endif

      txtar__expandchars(
        s, calls->ad, calls->n, &cbuf[0], &obuf[0], PAINTBUFSIZE, &nchars);
        /* add to existing ones */
      calls = calls->next;
    };

    scx = s->d->info.box.x0 - s->d->info.scx +
      wimpt_dx() * (s->o.margin + (thiscall.x * txtar__xppinch()) / 72000);
    scy = (s->d->info.box.y1 /* >>>> - wimpt_dy() */ ) - thiscall.y;
    mpx = ((s->d->info.box.x0 - s->d->info.scx) / wimpt_dx() + s->o.margin)
             * (72000 / txtar__xppinch())
           + thiscall.x;
    mpy =
      ((s->d->info.box.y1 + s->baselineoffset - thiscall.y) / wimpt_dy())
      * (72000 / txtar__yppinch());
    if (
      scy + t->w->linesep < grclip->y0 ||
      scy > grclip->y1
    ) {
      tracef0("clipped.\n");
      /* go round the loop */
    } else if (alreadycorrect) {
      tracef0("inverting display.\n");
      if (thiscall.width > 0) {
        bbc_vdu(18); bbc_vdu(3); bbc_vdu(s->o.forecolour ^ s->o.backcolour); /*  swap fore/back */
        if (scx == s->o.margin * wimpt_dx() + s->d->info.box.x0) {/* left hand edge */
          txtar__grmoveto(
            scx - s->o.margin * wimpt_dx(),
            (scy < 0 ? 0 : scy));
        } else {
          txtar__grmoveto(
            (scx < 0 ? 0 : scx),
            (scy < 0 ? 0 : scy));
        };
        bbc_plot(101,
               txtar__max(0,
/*
                 scx +
                   wimpt_dx() *
                     ((thiscall.width * txtar__xppinch()) / 72000) +
                   wimpt_dx() / 2,
*/
                 s->d->info.box.x0 - s->d->info.scx - 1 +
                   wimpt_dx() * (s->o.margin + ((thiscall.x + thiscall.width) * txtar__xppinch()) / 72000)),
                 scy + t->w->linesep - 1);
      };
    } else {

      if (thiscall.highlight
      && INVERTSELECTION
      && (thiscall.callendopt != txt1_CECONTINUE)
      ) {
        if (CHAR18BUG) {
          /* We must blank the tail of the line. done before painting rather
          than after, so that italic overhang still looks right. */
#if WIMPSETFONTCOLOUR
          txtar__setgrcolour(128 + s->o.backcolour);
#else
          if (s->o.forecolour < 4) {
            txtar__setgrcolour(128 + 7);
          } else {
            txtar__setgrcolour(128 + 0); /* normal background */
          };
#endif
          txtar__grmoveto(
            txtar__max(0,
/*
              scx + wimpt_dx() * (1 + (width * xppinch()) / 72000)),
*/
              s->d->info.box.x0 - s->d->info.scx +
                wimpt_dx() * (s->o.margin +
                ((thiscall.x + thiscall.width) * txtar__xppinch()) / 72000)),
            scy);
          bbc_plot(103, s->d->info.box.x1, scy + t->w->linesep - 1);
        } else {
          /* life is a lot easier without char18bug. change colour and
          keep going to end of line. */
#if WIMPSETFONTCOLOUR
#else
          txtar__fontnohilight(&cbuf[0], &nchars);
#endif
        };
      };

      cbuf[nchars] = 0;

      /* Mark out the blanking box. */
      /* We blank out the left hand margin too if
      in the left hand char position, as not doing this can leave blobs. */
      if (scx == s->o.margin * wimpt_dx() + s->d->info.box.x0) {/* left hand edge */
        txtar__grmoveto(scx - s->o.margin * wimpt_dx(), (scy < 0 ? 0 : scy));
      } else {
        txtar__grmoveto((scx < 0 ? 0 : scx), (scy < 0 ? 0 : scy));
      };
      /* Large letters near the bottom of the screen need the conditionals
      above, if their actual base line is at a negative coord or the origin
      is to the left of the screen. */

      /* Set the box to blank out when writing the chars */
      if ((thiscall.callendopt != txt1_CECONTINUE)
      && ! (thiscall.highlight && CHAR18BUG && INVERTSELECTION)
      ) {
        txtar__grmoveto(s->d->info.box.x1,
                 scy + t->w->linesep - 1);
      } else {
        txtar__grmoveto(
          txtar__max(
            0,
            s->d->info.box.x0 - s->d->info.scx - 1 +
              wimpt_dx() * (s->o.margin + ((thiscall.x + thiscall.width) * txtar__xppinch()) / 72000)),
          scy + t->w->linesep - 1);
      };

#if FALSE
      /* actual writing takes place with y increased a little, as the
      fonts are zero'd at the bottom of an "o" not a "g". */
      mpy = mpy + (s->baselineoffset * 72000) / (wimpt_dy() * txtar__yppinch);
#endif

      tracef2(" mpx=%i mpy=%i.\n", mpx, mpy);

      /* Set up colours and font */
      /* >>>> Only worth optimising this if we can cut out the
      setfont entirely from most calls. Move it to paintseveral? */

#if WIMPSETFONTCOLOUR
      {
        if (thiscall.highlight) {
          wimp_setfontcolours(s->o.backcolour, s->o.forecolour);
        } else {
          wimp_setfontcolours(s->o.forecolour, s->o.backcolour);
        };
      };
#else
      {
        int bpp = wimpt_bpp();
        int cols = bpp == 8 ? 8 : (bpp == 4 ? 8 : 1 << bpp);
        if (thiscall.highlight != (s->o.forecolour < 4)) {
          wimpt_noerr(font_setcolour(s->fh, cols-1, cols-2, 2-cols));
        } else {
          wimpt_noerr(font_setcolour(s->fh, 0, 1, cols-2));
        };
      };
#endif

#if TRACE
      tracef0("font_paintchars:\n");
      for (i=0; i<nchars; i++) txtar__safewrch(cbuf[i]);
      tracef0("\n");
#endif

/* alternative to the setfontcolour above.
      wimpt_noerr(font_setfont(s->fh));
*/
      /* at this point, output to the trace window seems to destroy
      the setting up of the colour map. */
      /* >>>> can optimise this a little?
        e.g. one call per fontpaintseveral */

      {
        os_error *e;
        e = wimpt_complain(font_paint(&cbuf[0], font_ABS + font_RUBOUT, mpx, mpy));
        if (e != 0) {
          /* He lost the floppy with the fonts on it. Convert to system font. */
          txtar__font_paint_error = TRUE;
        };
      };

    };

  };
  tracef0("fontpaint done.\n");
}
/* >>>> Things with changes in highlight should also be done as a single
string, as colour-change characters can be placed in the string. */

/* >>>> Unfortunately, you can't change the colours etc. that the wimp gives
you without destroying and creating the window, in the case where the user
changes the colours. Hum! an argument for window being not quite the same
as a literal wimp window handle... */

/* The raw rectangle operations are inclusive of their maximum coordinates.
this is the reason for the -1s in some of the calls above. */

static void txtar__rawpaintseveral(txt t, txt1_call *calls, BOOL alreadycorrect)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  BOOL r;

  if (txtar__withinredraw) {
    /* We are nested within performredraw below. */
    /* "redrawdata" is static, set by performredraw */
    if (! txtar__redrawdone) {
      txtar__redrawdone = TRUE;
      while (1) {
        txtar__paintseveral(t, calls,
          &txtar__redrawdata.g, alreadycorrect);
        wimpt_noerr(wimp_get_rectangle(&txtar__redrawdata, &r));
        if (! r) break;
      }
    };
  } else {
    /* This is direct painting, probably due to some client/user edit. */
    /* >>>> If before first show, just register repaint necessary? */
    tracef0("rawpaintseveral.\n");
    txtar__redrawdata.w = s->w;
      /* could use a local redrawdata: doesn't matter */
    txtar__redrawdata.box = s->d->info.ex;
    txtar__redrawdata.scx = s->d->info.scx;
    txtar__redrawdata.scy = s->d->info.scy;
    wimpt_noerr(wimp_update_wind(&txtar__redrawdata, &r));
    if (r) {
      while (1) {
        txtar__paintseveral(t, calls,
          &txtar__redrawdata.g, alreadycorrect);
        wimpt_noerr(wimp_get_rectangle(&txtar__redrawdata, &r));
        if (! r) break;
      }
    } else {
      tracef0("window totally invisible?\n");
    };
  };
  if (txtar__font_paint_error) {
    txtar_options o;
    txtar__font_paint_error = FALSE;
    o = s->o;
    o.fixfont = TRUE;
    txtar__dosetoptions(t, &o);
    txtar__redrawtext(t);
  };
}

static BOOL txtar__rawcopylines(txt t, txt1_zits srcy, txt1_zits dsty, txt1_zits size)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_winfo *d = s->d;
  wimp_box b;

  tracef3("textarthur.rawcopylines srcy=%i dsty=%i size=%i\n",
    srcy, dsty, size);

  b.x0 = d->info.ex.x0;
  b.y0 = - (srcy + size);
  b.x1 = d->info.ex.x1;
  b.y1 = - srcy;

  wimp_blockcopy(s->w, &b, b.x0, - (dsty + size));

  return TRUE;
}

static int txtar__setarthurcaret(txt t, BOOL visible)
/* Returns x coord of caret, just for rawshowcaret below. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_caretstr c;

    if (txtar__withinredraw) return 0;
    tracef3("textarthur.setarthurcaret (%i,%i) %i\n",
        t->w->caretx, t->w->carety, visible);
    c.w = s->w;
    c.i = (wimp_i) -1;
    c.y = - (t->w->carety + t->w->caretoffsety);
    c.height = (t->w->linesep * 4 ) / 3; /* 8 bits high */
    c.y -= c.height / 8;
    if (! visible) c.height |= (1<<25); /* invisible */
    c.index = 0;
    if (s->o.fixfont) c.height |= (1<<24); /* vdu-type caret */
    c.x = wimpt_dx() * (s->o.margin + ((t->w->caretx +
          t->w->caretoffsetx) * txtar__xppinch()) / 72000);
    wimpt_noerr(wimp_set_caret_pos(&c));

    if (visible) {
      /* position the caret on the screen */
      if (t->w->carety + t->w->caretoffsety <
          txtar__min(t->w->linesep, t->w->limy)) {
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
    };

  return c.x;
}
/* >>>> If performance is being sought, it would be possible to leave the
caret invisible until a null event comes along. This would prevent needless
drawing and undrawing of the caret, which might also be visually beneficial
(i.e. reduce flicker). Not done yet. */

static void txtar__rawhidecaret(txt t)
{
  (void) txtar__setarthurcaret(t, 0);
}

static void txtar__rawshowcaret(txt t)
/* Corrective horizontal scrolling only happens if the caret is shown
by the user. This means, for example, that clicking the scroll bar does
allow the caret to disappear. This is the correct behaviour, I think. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  int x;
  int viswidth;
  BOOL move;

#if TRUE
  /* Experiment: showing the caret clears the caret bit in all other
  windows. To help CLI windows. */
  /* Second version: caret in all other text objects (wasn't right
  when several windows on the same object. */
  {
    txtar__sysdata *p = all;
    while (p != 0) {
      if (p->t != s->t) {
        p->t->charoptionset &= ~txt_CARET;
      };
      p = p->next;
    };
  };
#endif

  if (txtar__withinredraw) return;
  txt3_setprimarywindow(t, s);
  x = txtar__setarthurcaret(t, TRUE);
  move = FALSE;
  viswidth = s->d->info.box.x1 - s->d->info.box.x0;
  if (x < s->d->info.scx) {
    tracef2("force horiz: x=%i scroff.x=%i.\n", x,
      s->d->info.scx);
    wimpt_noerr(wimp_get_wind_info(s->d));
    /* ensure s->d up to date for forthcoming open. */
    s->d->info.scx = txtar__max(0, x - viswidth / 3);
    move = TRUE;
  } else if (x > s->d->info.scx + viswidth) {
    wimpt_noerr(wimp_get_wind_info(s->d));
    s->d->info.scx =
      txtar__min(s->d->info.ex.x1 - viswidth,
                 x - (3 * viswidth) / 4);
    move = TRUE;
  };
  if (move) {
    wimpt_noerr(wimp_open_wind((wimp_openstr*) s->d));
    txtar__verify(s);
  };
}

#ifndef UROM
static void txtar__redisplay(txt t)
/* Instead of calling txt1_redisplay right back, we invalidate the region.
It frequently happens that a major edit is the result of a menu or dialog box
interaction, in which case the unpainting of the menu/dbox is best combined
with the redrawing of the text object. */
{
  txtar__redrawtext(t);
}
#endif

static int txtar__dovisiblelinecount(txt t)
{
  return t->w->limy / t->w->linesep;
}

static int txtar__dovisiblecolcount(txt t)
{
  /* >>>> Should measure the width of a space character. Not done yet. */
  return t->w->limx / 16;
}

/* -------- Input from the user. -------- */

/* Manipulation of the input buffer. */

static BOOL txtar__insertevent(txt t, txt_eventcode e)
/* Insert the given eventcode into the buffer, behind everything currently
there. if (the buffer is full, throw away this new arrival and return FALSE.
Otherwise, return TRUE. */
{
    if (
      t->inbuftail + 1 == t->inbufhead ||
      ((t->inbuftail == txt1_INBUFMAX) && (t->inbufhead == 0))
    ) {
      /* full */
      return FALSE;
    } else {
      t->inbuf[t->inbuftail++] = e;
      if (t->inbuftail > txt1_INBUFMAX) t->inbuftail = 0;
      return TRUE;
    };
}

static void txtar__kbdchar(txt t, txt_eventcode e)
/* Put the char in the buffer, and call the eventproc to say that this
has happened. */
{
    if (txtar__insertevent(t, e)) {
      if (t->eventproc != NULL) {
        tracef0("calling eventproc with char...\n");
        t->eventnest++;
        t->eventproc(t, t->eventprochandle);
        t->eventnest--;
      };
    };
}

static void txtar__mouseevent(txt t, txt_eventcode flags, txt1_zits x, txt1_zits y)
/* Insert the given event into the buffer, if it will fit, and
call the event proc. */
{
  txt_index at;

    tracef3("mouseevent %i at (%i,%i).\n", flags, x, y);
    if (x < 0) {
      at = 0x0ffffff; /* "outside" */
      /* >>>> Does this happen? */
    } else {
      at = txt1_windowcoordstoindex(t, x, y);
    };
    txtar__kbdchar(t, 0x80000000 + flags + at);
}

static BOOL txtar__extractevent(txt t, txt_eventcode *e /*out*/)
/* get the next guy out of the text buffer. */
{
    if (t->inbuftail == t->inbufhead) {
      /* empty */
      return FALSE;
    } else {
      *e = t->inbuf[t->inbufhead++];
      if (t->inbufhead > txt1_INBUFMAX) t->inbufhead = 0;
      return TRUE;
    };
}

static txt_eventcode txtar__doget(txt t)
/* >>>> If nothing is waiting, should this call event_processevent? */
{
  txt_eventcode e;

  if (txtar__extractevent(t, &e)) {
    return e;
  } else {
    tracef0("doget with nothing to get!\n");
    return '?';
  };
}

static int txtar__doqueue(txt t)
{
    if (t->inbuftail >= t->inbufhead) {
      return t->inbuftail - t->inbufhead;
    } else {
      return txt1_INBUFMAX - (t->inbufhead - t->inbuftail);
    };
}

static void txtar__dounget(txt t, int code)
{
#if FALSE
  txtar__insertevent(t, code);
  if (t->inbufhead == 0) {
    if (t->inbuftail == txt1_INBUFMAX) return; /* full */
    t->inbufhead = txt1_INBUFMAX;
  } else {
    if (t->inbufhead - 1 == t->inbuftail) return; /* full */
    t->inbufhead--;
  };
  t->inbuf[t->inbufhead] = code;
#else
  /* Assume buffer can never be full before this event?? */
  if (t->inbufhead == 0) t->inbufhead = txt1_INBUFMAX; else t->inbufhead--;
  /* Point to where last character came from */
  t->inbuf[t->inbufhead] = code;
  /* Place the character */
  if (t->inbufhead == t->inbuftail)
  {
    /* Buffer now over full, don't think this should happen */
    if (t->inbuftail == 0) t->inbuftail = txt1_INBUFMAX; else t->inbuftail--;
    /* throw away last keyboard event */
  }; /* End if */
#endif
}

static void txtar__newcharoptions(txt t, txt_charoption prev)
{
  t=t;
  prev=prev;
  tracef0("textarthur.newcharoptions.\n");
}

/* -------- Redrawing the window. -------- */

/* There is quite a mess about this in order that, when given several
rectangles to redraw, texts1 only does the measuring once. This gets spotted
in the interactions with rawpaintseveral. The static variables are used for
communicating this, and for preventing the drawing of the caret or setting of
extent during a redraw. We try not to crash in the case where txt1 does
more than one rawpaintseveral from a performredraw, maybe this will be useful
if (in the future) we try to limit use of store in the redraw structure. */

static void txtar__refreshcaret(txt t)
/* txt1 and txt2 have delicately separate ideas of what the caret is,
because txt2 knows that there's really only one of it, while the text
objects think of having one each. Thus, there are times when the caret, even
though visible, should only be drawn if it is already owned. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_caretstr c;

  tracef0("set caret.\n");
  wimpt_noerr(wimp_get_caret_pos(&c));
  if (c.w == s->w) {
    (void) txtar__setarthurcaret(t, 0 != (txt_CARET & t->charoptionset));
  };
}

static void txtar__performredraw(txt t)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  BOOL vis;

  tracef0("performredraw.\n");
  txtar__withinredraw = TRUE; /* affects the behaviour of paint etc. */
  txtar__redrawdone = FALSE;
  txtar__redrawdata.w = s->w;
  txtar__redrawdata.box = s->d->info.box;
  txtar__redrawdata.scx = s->d->info.scx;
  txtar__redrawdata.scy = s->d->info.scy;

  wimpt_noerr(wimp_redraw_wind(&txtar__redrawdata, &vis));
  if (vis) {
    txt1_redisplay(t, s->freshredisplay);
    s->freshredisplay = FALSE;
      /* May call rawpaintseveral, setextent, rawsetcaret */
    if (! txtar__redrawdone) {
      while (1) {
        /* Throw away the other rectangles. */
        wimpt_noerr(wimp_get_rectangle(&txtar__redrawdata, &vis));
        if (! vis) break;
      }
    };
  };
  txtar__withinredraw = FALSE;
  tracef0("set size.\n");
  if (txtar__setsizepending) {
    tracef0("setting size.\n");
    txtar__setsizepending = FALSE;
    txtar__rawsetsize(t);
    /* A wimp_setextent appears to cause a blank call to performredraw,
    which is what "blank" is for: it used to set the caret twice. */
  };
  if (vis) txtar__refreshcaret(t);
#if TRACE
  txtar__checkwinfo(t);
#endif
  tracef0("performredraw done.\n");
}

/* -------- Processing events. -------- */

#define DELAY_BEFORE_HOURGLASS  200

static void txtar__visdelay_begin(void)
{
   os_regset r;

   r.r[0] = DELAY_BEFORE_HOURGLASS;
   os_swix(Hourglass_Start, &r);
}


static void txtar__visdelay_end(void)
{
   visdelay_end();
}


static void txtar__textwimpevent(wimp_eventstr *e, void *handle)
{
  txtar__sysdata *s = (txtar__sysdata*) handle;
  txt t = s->t;
/*  BOOL bottom; */

  txt3_settemporarywindow(t, s);
  switch (e->e) {
  case wimp_ENULL:
      if (t->w == t->windows[1]) {
        if (txtar__thumbing) {
          txtar__dothumb(t, 0);
        } else {
          txtar__dodrag(t);
        };
      };
      break;
  case wimp_EREDRAW:
      if (wimpt_checkmode() || wimpt_mode() != s->screenmode) {
        txtar__setmode(s);
        txtar__dosetoptions(t, &s->o);
      };
      txtar__visdelay_begin();
      txtar__performredraw(t);
      txtar__visdelay_end();
      break;
  case wimp_ECLOSE:
      txt3_setprimarywindow(t, s);
      txtar__docharevent(t, txt_EXTRACODE + akbd_Fn + 127);
      break;
  case wimp_EOPEN:
      txtar__visdelay_begin();
      txt3_setprimarywindow(t, s);
/*      bottom = e->data.o.behind == (wimp_w) -2; */
      txtar__doopenevent(t, &e->data.o);
      txtar__visdelay_end();
/*      if (bottom) win_give_away_caret(); */
      break;
  case wimp_EBUT:
      tracef0("mouse button event\n");
      txt3_setprimarywindow(t, s);
      txtar__dobuttonevent(t, e);
      break;
  case wimp_EKEY:
      txt3_setprimarywindow(t, s);
      tracef2("key for text %i, ch=%i\n", (int) t, e->data.key.chcode);
      txtar__docharevent(t, e->data.key.chcode);
      break;
  case wimp_ESCROLL:
      txtar__visdelay_begin();
      txt3_setprimarywindow(t, s);
      tracef1("scroll by %i.\n", e->data.scroll.y);
      if (e->data.scroll.y == -2) {
        txtar__docharevent(t, txt_EXTRACODE + akbd_Sh + akbd_DownK);
        /* turn into "move a page" */
      } else if (e->data.scroll.y == 2) {
        txtar__docharevent(t, txt_EXTRACODE + akbd_Sh + akbd_UpK);
      } else if (e->data.scroll.y == -1) {
        txtar__docharevent(t, txt_EXTRACODE + akbd_Sh + akbd_Ctl + akbd_DownK);
      } else if (e->data.scroll.y == 1) {
        txtar__docharevent(t, txt_EXTRACODE + akbd_Sh + akbd_Ctl + akbd_UpK);
      } else if (e->data.scroll.x == 2) {
        e->data.o.x += e->data.o.box.x1 - e->data.o.box.x0;
        txtar__doopenevent(t, &e->data.o);
      } else if (e->data.scroll.x == -2) {
        e->data.o.x -= e->data.o.box.x1 - e->data.o.box.x0;
        txtar__doopenevent(t, &e->data.o);
      } else if (e->data.scroll.x == 1) {/* small amount right */
        e->data.o.x += 16 * wimpt_dx();
        txtar__doopenevent(t, &e->data.o);
      } else if (e->data.scroll.x == -1) {/* small amount left */
        e->data.o.x -= 16 * wimpt_dx();
        txtar__doopenevent(t, &e->data.o);
      } else {
        tracef1("scroll event %i ignored.\n", e->data.scroll.y);
      };
      txtar__visdelay_end();
      break;
  case wimp_ESEND:
  case wimp_ESENDWANTACK:
    {
      switch (e->data.msg.hdr.action) {
        case wimp_MDATASAVE:
        case wimp_MDATALOAD:
        case wimp_MDATAOPEN:
          txtar__docharevent(t, txt_EXTRACODE + akbd_Fn + akbd_Sh + 2);
          break;
        case wimp_MHELPREQUEST:
          txtar__docharevent(t, txt_EXTRACODE + akbd_Fn + 1);
          break;
        default:
          tracef0("strange wimp message arrived at txtar, ignored.\n");
          break;
      };
    };
    break;
  default:; /* do nothing */
  }; /* case */
  if (t->disposepending && (t->eventnest == 0)) {
    tracef0("disposing of text in textwimpevent.\n");
    txt_dispose(&t); /* must be variable! */
  } else {
    txt3_resetprimarywindow(t);
  };
}

static void txtar__registernewtext(txt t)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  win_register_event_handler(s->w, txtar__textwimpevent, s);
}

#ifndef UROM
static void txtar__discardtext(txt t)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  win_register_event_handler(s->w, (win_event_handler) NULL, NULL);
}
#endif

static void txtar__docharevent(txt t, txt_eventcode e)
{
  txtar__kbdchar(t, e);
}

/*
ArcEdit's scroll bars are horrible.

Window extent is set in txtar__rawsetsize, based on isize and ioffset:
    vissize = s->d->info.box.y1 - y0;
    size = vissize*100 / t->w->isize;
    offset = (size * t->w->ioffset) / 100;
    if (offset-size > -txtar__screenheight())
      size = txtar__screenheight() + offset;
    e.box.y0 = offset - size;
    e.box.y1 = offset;
e.g. if offset=0 (top visible) then e.box.y0 = 0.
     if e.box.y0 will be less than screen size, increase it accordingly.
*/

static void txtar__dothumb(txt t, int offset)
/* offset==0 -> stay still.
 more -> go back in document
 less -> go forward
*/
/* There is considerable agony here caused by trying to make the
"continuous thumbing" mode look convincing: the moral is that,
if you're going to have to fix a scroll bar to an editor, don't
make it this sort of editor! Effectively, some buffering is added
to ensure that changes in direction of scrolling are only caused
by changes in direction of mouse. Null events are also involved,
in order to cancel this effect successfully. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  int vissize;
  int vispos;
  int size;
  int dist;

    tracef1("thumb to %i.\n", offset);


    { wimp_mousestr m;
      BOOL ignore = FALSE;

      wimp_get_point_info(&m);
      tracef1("mouse bbits=%i.\n", m.bbits);
      if (txtar__lastthumbmouse.bbits == 0) {
        tracef0("not already thumbing - no shortcuts.\n");
      } else if (m.y > txtar__lastthumbmouse.y
      && offset < 0) {
        tracef0("Mouse moved up, request scroll down: ignore.\n");
        ignore = TRUE;
      } else if (m.y < txtar__lastthumbmouse.y
      && offset > 0) {
        tracef0("Mouse moved down, request scroll up: ignore.\n");
        ignore = TRUE;
      } else if (m.y == txtar__lastthumbmouse.y
      && (offset >= 0) != (txtar__lastthumbdir >= 0)) {
        tracef0("Mouse not moved, request changes direction: ignore.\n");
        ignore = TRUE;
      };
      if (ignore) return;
      txtar__lastthumbmouse = m;
      txtar__lastthumbdir = offset;
      /* If a null event occurs, with button up, then any continuous thumbing
      effect must have finished. */
      if (m.bbits == 0) {
        txtar__thumbing = FALSE;
        win_claim_idle_events((wimp_w) -1);
        event_setmask(event_getmask() | wimp_EMNULL);
      } else {
        txtar__thumbing = TRUE;
        event_setmask(event_getmask() & ~wimp_EMNULL);
        win_claim_idle_events(s->w);
      };
    };

    size = s->d->info.ex.y1 - s->d->info.ex.y0;
    vissize = s->d->info.box.y1 - s->d->info.box.y0;
    tracef3("offset=%i size=%i vissize=%i.\n",
      offset, size, vissize);
    if (offset > 0) {
      tracef0("thumb backwards in text.\n");
      vispos = s->d->info.ex.y1;
      if (vispos <= 0) vispos = 1;
      dist = (offset * 100) / vispos;
      tracef1("  thumbback(t, by %i percent);\n", dist);
      if (dist > 100) dist = 100;
      txt1_thumbback(t, dist); /* that fraction of the distance to start of file. */
    } else if (offset < 0) {
      tracef0("thumb forwards in text.\n");
      offset = - offset;
      vispos = - s->d->info.ex.y0 - vissize;
      dist = (offset * 100) / vispos;
      tracef1("  thumbforw(t, %i percent);\n", dist);
      if (dist > 100) dist = 100;
      txt1_thumbforw(t, dist);
    /* else offset==0, do nothing */
    };
}

static void txtar__doopenevent(txt t, wimp_openstr *o /*in*/)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  BOOL sizechange;
  BOOL move;

  tracef4("open event: to (%i,%i,%i,%i).\n",
    o->box.x0, o->box.y0, o->box.x1, o->box.y1);
  tracef1("open event: behind=%i.\n", o->behind);

  sizechange =
    (s->d->info.box.x1 - s->d->info.box.x0 != o->box.x1 - o->box.x0) ||
    (s->d->info.box.y1 - s->d->info.box.y0 != o->box.y1 - o->box.y0);
  move = (s->d->info.box.x0 != o->box.x0) ||
          (s->d->info.box.y1 != o->box.y1);
  s->d->info.box = o->box;
  s->d->info.behind = o->behind;

  /* If it's just a move, I get scy as y1-y0. A thumb will
  have this value different, more for move upwards/backwards in file and
  less for downwards. */
  tracef3("scolloffset=%i y1=%i y0=%i.\n",
    o->y, o->box.y1, o->box.y0);

  if ((! move) &&
     (! sizechange) &&
     (o->y != 0)
  ) {
    txtar__dothumb(t, o->y);
  } else {
    /* >>>> horiz scroll... o.scrolloffset.x = 0; */
    o->y = 0;
    wimpt_noerr(wimp_open_wind(o));
    /* After doing this, one or two things may change such as the
    rounding of some coordinates. We maintain s->d as an accurate
    representation of what the wimp thinks is going on. */
    /* In the case of a "zoom", the wimp appears to give a somewhat
    curious initial "open" event. this puts things more ship-shape. */
    s->d->w = s->w;
    wimpt_noerr(wimp_get_wind_info(s->d));
#if TRACE
      if (s->d->info.scy != 0) {
        tracef("why is scy=%i?\n", s->d->info.scy); /* bug hunt */
      };
#endif
    if (sizechange) {
      /* If size changes at all, force a total redraw. We can't just
      leave this to the window system, as it will only invalidate portions
      of the window that actually become visible. */
      tracef0("forcing redraw.\n");
      txtar__settextlimits(t);
      /* ensure that a redraw of the scroll bars will be called. */
      t->w->isize = 100;
      t->w->ioffset = 0;
      txtar__setsizepending = TRUE; /* >>>> smell of bodge... */
      tracef3("whole redraw test: %i %i %i.\n",
        t->w->carety, t->w->caretoffsety,
        s->d->info.box.y1 - s->d->info.box.y0);
      if (s->o.wraptowindow
      || t->w->carety + t->w->caretoffsety >=
         s->d->info.box.y1 - s->d->info.box.y0) {
        /* This amusing test catches a lot of cases where an entire
        redraw is not necessary. The second part says, "if the caret
        is not moved vertically by the resize.". */
        tracef0("whole redraw necessary.\n");
        txtar__redrawtext(t);
      } else {
        /* The only thing that can go wrong is that our cached knowledge
        of the first inivisble character gets out of date. Fix this. */
        txt1_checklastvis(t);
      };
      /* A redraw forces a recalculation of scroll bar and cursor. */
    } else {

    };

  };
#if TRACE
  txtar__checkwinfo(t);
#endif
}

static void txtar__redrawtext(txt t)
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_redrawstr r;

  r.w = s->w;
  r.box = s->d->info.ex; /* whole of work area */
  wimpt_noerr(wimp_force_redraw(&r));
}

static int txtar__timestamp(void) {
  int t;
  wimpt_noerr(os_swi1r(os_X + 66, 0, &t)); /* OS_ReadMonotonicTime */
  tracef1("timestamp returns %i.\n", t);
  return t; /* centiseconds since power-on. */
}

static void txtar__dobuttonevent(txt t, wimp_eventstr *e /*in*/)
/* For a drag, you first receive notification of the initial click, then a
drag event. */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  int x;
  txt_eventcode m;
  int mousetime = txtar__timestamp();

  tracef1("mouse button event %i\n", e->data.but.m.bbits);
  if (e->data.but.m.bbits == wimp_BLEFT) {
    m = txt_MSELECT;
  } else if (e->data.but.m.bbits == wimp_BRIGHT) {
    m = txt_MEXTEND;
  } else if (e->data.but.m.bbits == wimp_BDRAGRIGHT) {
    event_setmask(event_getmask() & ~wimp_EMNULL);
    win_claim_idle_events(s->w);
    m = txt_MEXTEND + txt_MEXTOLD; /* and do an extend */
  } else if (e->data.but.m.bbits == wimp_BDRAGLEFT) {
    event_setmask(event_getmask() & ~wimp_EMNULL);
    win_claim_idle_events(s->w);
    m = txt_MSELECT + txt_MSELOLD; /* do a variable select. */
  } else {
    m = 0;
  };

  if ((abs(s->prevmousex - e->data.but.m.x) <= 2 * wimpt_dx())
  && (abs(s->prevmousey - e->data.but.m.y) <= 2 * wimpt_dy())
  && (mousetime - s->prevmousetime < 100)) {
    tracef0("mouse exact multi-click.\n");
    m |= txt_MEXACT;
  };
  s->prevmousex = e->data.but.m.x;
  s->prevmousey = e->data.but.m.y;
  s->prevmousetime = mousetime;

  /* work out x coord. */
  x = e->data.but.m.x - s->o.margin * wimpt_dx() - s->d->info.box.x0 + s->d->info.scx;
  x = x * (72000 / (wimpt_dx() * txtar__xppinch()));
  if (x < 0) x = 0; /* could be exactly in left hand margin. */

  txtar__mouseevent(
    t,
    m,
    x,
    s->d->info.box.y1 - wimpt_dy() - e->data.but.m.y);

}

static void txtar__dodrag(txt t)
/* >>>> duplication of code? */
{
  txtar__sysdata *s = (txtar__sysdata*) t->w->syshandle;
  wimp_mousestr mouse;
  txt1_zits x;
  txt1_zits y;

  tracef0("drag poll.\n");
  wimpt_noerr(wimp_get_point_info(&mouse));
  tracef3("mouse state: buts=%i at (%i,%i).\n",
    mouse.bbits, mouse.x, mouse.y);
  x = mouse.x - s->o.margin * wimpt_dx() - s->d->info.box.x0 + s->d->info.scx;
  x = x * (72000 / (wimpt_dx() * txtar__xppinch()));
  y = s->d->info.box.y1 - wimpt_dy() - mouse.y;
  if (x < 0) x = 0; /* could be exactly in left hand margin */
  if ((mouse.bbits == wimp_BDRAGRIGHT) ||
     (mouse.bbits == wimp_BRIGHT)
  ) {
    /* if (outside, do nothing. */
    if (mouse.w == s->w) {
      tracef0("fake mouse event.\n");
      txtar__mouseevent(t, txt_MEXTEND + txt_MEXTOLD, x, y);
    } else {
      tracef2("ignore, wh=%i not %i.\n", mouse.w, s->w);
    };
  } else if (mouse.bbits == wimp_BDRAGLEFT ||
             mouse.bbits == wimp_BLEFT
  ) {
    /* if (outside, do nothing. */
    if (mouse.w == s->w) {
      tracef0("fake mouse event.\n");
      txtar__mouseevent(t, txt_MSELECT + txt_MSELOLD, x, y);
    } else {
      tracef2("ignore, wh=%i not %i.\n", mouse.w, s->w);
    };
  } else {
    tracef0("relinquish.\n");
    win_claim_idle_events((wimp_w) -1);
    event_setmask(event_getmask() | wimp_EMNULL);
  };
}

static int txtar__readoptnum(char *buf, int *i)
{
  /* read a number from the option string. */
  int result = buf[*i] - '0';
  (*i)++;
  while (buf[*i] >= '0' && buf[*i] <= '9')
  {
     result *= 10;
     result += buf[*i] - '0';
     (*i)++;
  }

  return result;
}

static void txtar__defaultoptions(txtar_options *opt) {
#ifdef BIG_WINDOWS
  int screenwidth = (1 + bbc_vduvar(bbc_XWindLimit)) << bbc_vduvar(bbc_XEigFactor);
  int sysfontwidth = wimpt_dx() * bbc_vduvar(bbc_GCharSpaceX);
#endif
  opt->fixfont = TRUE;
  opt->forecolour = 7;
  opt->backcolour = 0;
  strcpy(&opt->fontname[0], "Homerton.Medium"); /* initial value. */
  opt->fontwidth = 12;
  opt->fontheight = 12;
  opt->margin = 2;
  opt->leading = 0;
  opt->wraptowindow = FALSE;
#ifdef BIG_WINDOWS
  opt->big_windows = FALSE;
  opt->big_window_size = txtar__min(screenwidth/sysfontwidth - 3 /*scrollbar*/, BIG_WINDOW_SIZE_LIMIT);
#endif
#ifdef SET_MISC_OPTIONS
  opt->overwrite = FALSE;
  opt->wordtab = TRUE;
  opt->wordwrap = FALSE;
  opt->undosize = 5000;
#endif

  /* Now read user preferences, if any. */
  {
    char buf[MAXSYSVARSIZE];
    int i = 0;
#ifdef SETOPTIONS
    char *optname;
    char sysvarname[30];

    optname = txtopt_get_name();
    strncpy(sysvarname, optname, 30);
    strncat(sysvarname, "$Options", 30);
    os_read_var_val(sysvarname, buf, MAXSYSVARSIZE-1);
#else
    os_read_var_val("Edit$Options", buf, MAXSYSVARSIZE-1);
#endif
    while (buf[i] != 0) {
      switch (buf[i++]) {
      case 'f':
      case 'F':
        opt->forecolour = txtar__readoptnum(buf, &i);
        break;
      case 'b':
      case 'B':
        opt->backcolour = txtar__readoptnum(buf, &i);
        break;
      case 'l':
      case 'L':
        {
          int neg = buf[i] == '-';
          if (neg) i++;
          opt->leading = txtar__readoptnum(buf, &i);
          if (neg) opt->leading = - opt->leading;
        };
        break;
      case 'm':
      case 'M':
        opt->margin = txtar__readoptnum(buf, &i);
        break;
      case 'h':
      case 'H':
        opt->fontheight = txtar__readoptnum(buf, &i);
        /* opt->fixfont = FALSE; */
        break;
      case 'w':
      case 'W':
        opt->fontwidth = txtar__readoptnum(buf, &i);
        /* opt->fixfont = FALSE; */
        break;
      case 'r':
      case 'R':
        opt->wraptowindow = TRUE;
        break;
      case 'a':
      case 'A':
        opt->big_windows = TRUE;
        opt->big_window_size = txtar__min(txtar__readoptnum(buf, &i), BIG_WINDOW_SIZE_LIMIT);
        break;
      case 'n':
      case 'N':
        strcpy(opt->fontname, &buf[i]);
        opt->fixfont = FALSE;
        buf[i] = 0; /* force end. */
        break;
#ifdef SET_MISC_OPTIONS
      case 'O':
      case 'o':
        opt->overwrite = TRUE;
        break;
      case 'T':
      case 't':
        opt->wordtab = FALSE;
        break;
      case 'D':
      case 'd':
        opt->wordwrap = TRUE;
        break;
      case 'U':
      case 'u':
        opt->undosize = txtar__readoptnum(buf, &i);
        if (opt->undosize < 100) opt->undosize = 100;
        break;
#endif
      default:
        break;
        /* Note that, if an unrecognised option comes along, a following
        signed number will be skipped over. Thus, other options not mentioned
        here will simply be ignored. */
        /* Also, spaces will be ignored too. */
      };
    };
  };
}

BOOL txtar_initwindow(txt t, char *title)
/* >>>> Make this a lot smaller using pre-prepared records. */
{
  txtar__sysdata *s;
  wimp_winfo *d; /* help code by removing use of s->d-> */
  txt1_window *w; /* ditto */
  dbox db = dbox_new("text");

  tracef0("creating window\n");
  if (db == 0) return FALSE;
  s = malloc(sizeof(txtar__sysdata));
  if (s == 0) return FALSE;
  s->d = malloc(sizeof(wimp_winfo)); /* no icons */
  if (s->d == 0) {
    free(s);
    return FALSE;
  };
  d = s->d;
  d->w = dbox_syshandle(db);
  wimp_get_wind_info(d); /* no space for any icons! */
  dbox_dispose(&db);

  tracef0("setting up window description.\n");
  strcpy(s->titlebuf, title);
  s->t = t;
  txtar__defaultoptions(&s->o);

  s->showing = FALSE;
  s->prevmousex = 0;
  s->prevmousey = 0;
  s->prevmousetime = -1;
  s->freshredisplay = TRUE;

  d->info.box.y0 += txtar__starty;
  d->info.box.y1 += txtar__starty;
  txtar__starty -= 48;
  if (txtar__starty < -200) {
    txtar__starty = 0;
  };
  d->info.ex.y0 = -txtar__screenheight() /*createsizey*/; /* entirely visible */
  d->info.ex.x1 = txtar__screenwidth();
    /* wide as possible */
  d->info.minsize = 0x00000001; /* 0; */
  d->info.titleflags |= wimp_INDIRECT;
  d->info.title.indirecttext.buffer = &(s->titlebuf[0]);
  d->info.title.indirecttext.validstring = (char*) -1;
  d->info.title.indirecttext.bufflen = TITLEBUFMAX;
  d->info.colours[wimp_WCWKAREABACK] = 255; /* do no filling of background */

  tracef0("creating window\n");
  tracef1("window desc is at %i\n", (int) s->d);
  { os_error *er;
    er = wimp_create_wind(&s->d->info, &s->w);
    if (er != 0) {
      tracef0("create window failed.\n");
      werr(FALSE, er->errmess);
      free(s->d);
      free(s);
      return FALSE;
    };
  };
  tracef1("window handle = %i\n.", s->w);

  w = t->w;
  w->syshandle = s;
    /* set up the text object paint environment */
    /* the real thing only appears when the window is made visible. */
  w->ioffset = 0;
  w->isize = 100;
  w->caretx = 0;
  w->carety = t->w->linesep;
  w->caretoffsetx = 0;
  w->caretoffsety = 0;
  w->highlight_reversable = TRUE;
/*      highlight_reversable = FALSE; */
  w->italic = FALSE;

  w->doshow = txtar__doshow;
  w->dohide = txtar__dohide;
  w->dosettitle = txtar__dosettitle;
  w->disposewindow = txtar__disposewindow;
  w->rawsetsize = txtar__rawsetsize;
  w->rawmeasure = txtar__rawmeasure;
  w->rawpaintseveral = txtar__rawpaintseveral;
  w->rawcopylines = txtar__rawcopylines;
  w->rawhidecaret = txtar__rawhidecaret;
  w->rawshowcaret = txtar__rawshowcaret;
  w->dovisiblelinecount = txtar__dovisiblelinecount;
  w->dovisiblecolcount = txtar__dovisiblecolcount;
  w->doget = txtar__doget;
  w->doqueue = txtar__doqueue;
  w->dounget = txtar__dounget;
  w->donewcharoptions = txtar__newcharoptions;
  w->dosyshandle = txtar__dosyshandle;

  txtar__setmode(s);
  txtar__settextlimits(t); /* sets limx/y, screenwidth */
  if (s->o.fixfont) {
    txtar__trynofont(t);
  } else {
    if (! txtar__tryfont(t, &s->o.fontname[0], s->o.fontwidth, s->o.fontheight)) {
      /* s->o.fixfont = TRUE; */
      txtar__trynofont(t);
    };
  };

  txtar__registernewtext(t);
#if TRACE
  txtar__checkwinfo(t);
#endif

  s->next = all; /* link onto list of all sysdata records. */
  all = s;

  return TRUE;
}
/* carety is because (0,0) is the exact top left hand corner of the screen,
and when a character is drawn you specify the coords of its bottom left hand
corner. the vdu case of each char being (1,1) in size is an accident. */

void txtar_clone_current_window(txt t)
/* >>>> Put in a check that this is really a textarthur window! If it
is not, do nothing. */
/* this routine is really quite a mess, as we try to inherit state
"nicely" from the parent window. */
{
  txtar_options o;
  txtar_getoptions(t, &o);

  if (txt3_preparetoaddwindow(t)) {
    if (txtar_initwindow(t, "")) {
      txt_show(t); /* will open/verify/set text limits on all windows */
      txtar__dosetoptions(t, &o);
      txtar__redrawtext(t);
      return;
    };
  };
}

/* end */
