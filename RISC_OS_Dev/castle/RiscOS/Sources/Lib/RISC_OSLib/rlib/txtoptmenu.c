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
  Purpose: provide a menu for simple cosmetic alterations to a Text
           Arthur version.
  Author: WRS
  History:
    25 August 87 -- started
    25-Feb-88: WRS: converted to C, new trace usage.
    02-Mar-88: WRS: dbox form removed.
 *  13-Dec-89: WRS: msgs literal text put back in.
    12-Feb-90: IDJ: added menu entry to set max size of work area
    13-Feb-90: IDJ: limited work area width to 256 chars (you get 'echos' of text
                    appearing if width is much bigger - probably another display bug)
    16-Feb-90: IDJ: changed limit to 192 chars (display bugs start > 196 chars)
    02-Dec-90: IDJ: changed Wrap to Window wrap
    08-Apr-91: PJC: added facility to use new font manager menus
    07-Jun-91: IDJ: no font change when just click on font name
    14-Jun-91: IDJ: changed font menu to what it used to be, and made edit read
                    new fonts every menu open (so we can catch new fonts loaded)
*/

#define BOOL int
#define TRUE 1
#define FALSE 0

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "txt.h"
#include "os.h"
#include "wimp.h"
#include "wimpt.h"
#include "menu.h"
#include "EditIntern/txtar.h"
#include "dbox.h"
#include "event.h"
#include "EditIntern/txtoptmenu.h"
#include "visdelay.h"
#include "font.h"
#include "trace.h"
#include "werr.h"
#include "colourmenu.h"
#include "msgs.h"
#include "txtwin.h"
#include "VerIntern/messages.h"

#define MFont 1
#define MFontSize 2
#define MFontHeight 3
#define MLeading 4
#define MMargin 5
#define MInvert 6
#define MWrap 7
#define MForeground 8
#define MBackground 9
#ifdef BIG_WINDOWS
#define MWorkArea 10
#endif

static menu tmsize; /* the size menu */
static menu tmheight; /* height menu */
static menu tmleading; /* leading menu */
static menu tmmargin; /* margin menu */
#ifdef BIG_WINDOWS
static menu tmworkarea; /* window width in chars */
#endif
static char leadingbuf[10];
static char marginbuf[10];
#ifdef BIG_WINDOWS
static char widthbuf[10];
#endif

static wimp_menustr *font_menu = 0;
static char *font_hit = 0;
static int padding3;
static int padding4;

#define txtoptmenu__max(a,b) (((a)>(b))?(a):(b))
#define txtoptmenu__min(a,b) (((a)>(b))?(b):(a))

static wimp_menustr* txtoptmenu__fontmenu(void) {

  /* always rebuild the font menu */
  wimpt_complain(font_makemenu(&font_menu, NULL, fontmenu_WithSystemFont));

  return(font_menu);
}

static int sizes[] = {8, 10, 12, 14, 20};

static void txtoptmenu__setfontmenuflags(txtar_options *current) {
  int i;

  if (current->fixfont) {
    wimpt_complain(font_makemenu(&font_menu, (char *)1, fontmenu_WithSystemFont));
  } else {
    wimpt_complain(font_makemenu(&font_menu, current->fontname, fontmenu_WithSystemFont));
  }
  for (i = 1; i <= 5; i++) {
    menu_setflags(tmsize, i, current->fontwidth == sizes[i-1], FALSE);
    menu_setflags(tmheight, i, current->fontheight == sizes[i-1], FALSE);
  };
}

/* -------- Colour Menu. -------- */

static menu txtoptmenu_makecolourmenu(void)
{
  return colourmenu_make(msgs_lookup(MSGS_txt55), FALSE);
}

/* -------- Entire Menu. -------- */

static menu tm = 0;
static menu tm3;
static menu tm4;

static void txtoptmenu__makevaluemenu(menu m) {
wimp_menuhdr *sizemenu;
wimp_menuitem *sizeitem;

sizemenu = (wimp_menuhdr*) menu_syshandle(m);
sizemenu->width = 160;
  /* fix because of long entry messing things up. */
  /* >>>> change when size-of-system-font becomes available. */
sizeitem = (wimp_menuitem*) (sizemenu+1); /* points at first item. */
sizeitem += 5; /* point at last item. */
sizeitem->data.indirecttext.buffer[0] = 0;
sizeitem->data.indirecttext.validstring = "a0-9";
sizeitem->data.indirecttext.bufflen = 3; /* >>> new, to prevent huge numbers. */
sizeitem->flags |= wimp_MWRITABLE;
sizeitem->iconflags &= ~(wimp_IBTYPE * 0xF); /* clear button type field */
sizeitem->iconflags |= (wimp_IBTYPE * wimp_BWRITABLE); /* and set writable */
}

static void txtoptmenu__makeoriginal(void)
{

#ifdef BIG_WINDOWS
tm = menu_new(
  msgs_lookup(MSGS_txt62),
  msgs_lookup(MSGS_txt63));
#else
tm = menu_new(
  msgs_lookup(MSGS_txt62),
  msgs_lookup(MSGS_txt63));
#endif

tmsize = menu_new(
  msgs_lookup(MSGS_txt56),
  msgs_lookup(MSGS_txt57));
tmheight = menu_new(
  msgs_lookup(MSGS_txt58),
  msgs_lookup(MSGS_txt59));

tmleading = menu_new(msgs_lookup(MSGS_txt60), msgs_lookup(MSGS_txt72));
menu_make_writeable(tmleading, 1, leadingbuf, 3, "a0-9\\-");
menu_submenu(tm, MLeading, tmleading);

tmmargin = menu_new(msgs_lookup(MSGS_txt61),msgs_lookup(MSGS_txt72));
menu_make_writeable(tmmargin, 1, marginbuf, 3, "a0-9");
menu_submenu(tm, MMargin, tmmargin);

#ifdef BIG_WINDOWS
tmworkarea = menu_new(msgs_lookup("txt71"), "foofoofoo");
menu_make_writeable(tmworkarea, 1, widthbuf, 4, "a0-9");
menu_submenu(tm, MWorkArea, tmworkarea);
#endif

/* The final option (a writable menu entry) is so large that he's forced
to make it indirect. */
txtoptmenu__makevaluemenu(tmsize);
txtoptmenu__makevaluemenu(tmheight);
menu_submenu(tm, MFontSize, tmsize);
menu_submenu(tm, MFontHeight, tmheight);

tm3 = txtoptmenu_makecolourmenu();
menu_submenu(tm, MForeground, tm3);

tm4 = txtoptmenu_makecolourmenu();
menu_submenu(tm, MBackground, tm4);
}

static void txtoptmenu__setflags(txt t) {
  txtar_options o;
  int i;

  txtar_getoptions(t, &o);
/*  menu_setflags(tm, MFont, ! o.fixfont, FALSE); */
  menu_setflags(tm, MWrap, o.wraptowindow, FALSE);
  for (i = 1; i <= 16; i++) {
    menu_setflags(tm3, i, i - 1 == o.forecolour, FALSE);
    menu_setflags(tm4, i, i - 1 == o.backcolour, FALSE);
  };
  menu_setflags(tm, MFontSize, FALSE, o.fixfont);
  menu_setflags(tm, MFontHeight, FALSE, o.fixfont);
  txtoptmenu__setfontmenuflags(&o);
  sprintf(leadingbuf, "%i", o.leading);
  sprintf(marginbuf, "%i", o.margin);
#ifdef BIG_WINDOWS
  menu_setflags(tm, MWorkArea, o.big_windows, FALSE);
  sprintf(widthbuf, "%i", o.big_window_size);
#endif
}

static int getint(char *a, int dft) {
  int n = 0;
  while (1) {
    int ch = *a++;
    tracef1("found char %i.\n", ch);
    if (ch == 0) return n;
    if (ch >= '0' && ch <= '9') {
      n = n * 10 + ch - '0';
    } else {
      return dft;
    };
  };
}

static int txtoptmenu__fontmenuvalue(menu m, int item, int dft) {
  wimp_menuhdr *sizemenu;
  wimp_menuitem *sizeitem;

  switch (item) {
    default: return dft;
    case 1: return 8;
    case 2: return 10;
    case 3: return 12;
    case 4: return 14;
    case 5: return 20;
    case 6:
      tracef0("writable font size menu entry.\n");
      sizemenu = (wimp_menuhdr*) menu_syshandle(m);
      sizeitem = (wimp_menuitem*) (sizemenu+1); /* points at first item. */
      sizeitem += 5; /* point at last item. */
    return getint(sizeitem->data.indirecttext.buffer, dft);
  };
}

menu txtoptmenu_make(txt t) {
  if (tm == 0) txtoptmenu__makeoriginal();

 /* need to "magic" the font menu into the structure */
{ wimp_menuhdr *foo = (wimp_menuhdr*) menu_syshandle(tm);
  wimp_menuitem *item = (wimp_menuitem*) (foo+1);

  item += MFont-1;
  item->submenu = txtoptmenu__fontmenu();
}
  txtoptmenu__setflags(t);
  return tm;
}

void txtoptmenu_eventproc(txt t, char *s)
{

txtar_options o;
unsigned i;

if (s[0] == 0) {
  /* do nothing */
} else {
  txtar_getoptions(t, &o);

  if (s[0] == MFont) {
    if (s[1] == 1) {
      o.fixfont = TRUE;
    } else if (s[1] > 1) {
      /* we can't just copy the string 'cos it isn't linear any more */
      /* need to translate RISC_OSLib menu hits back into wimp menu hits */
      /* this is done by copying the chars back into ints, decrementing as we go */
      int selection[20];
      int i = 0;
      do {
       i++;
       selection[i-1] = s[i] - 1;
      } while (s[i] != 0);
      /* now get the string */
      wimpt_complain(font_decodemenu(font_menu, selection, &font_hit));
      o.fixfont = FALSE;
      strcpy(o.fontname, font_hit);
    };
    o.leading = 0; /* zeroed on any font change. */
  } else if (s[0] == MFontSize) {
    o.fixfont = FALSE;
    o.fontwidth = txtoptmenu__fontmenuvalue(tmsize, s[1], o.fontwidth);
    o.fontheight = o.fontwidth;
  } else if (s[0] == MFontHeight) {
    o.fixfont = FALSE;
    o.fontheight = txtoptmenu__fontmenuvalue(tmheight, s[1], o.fontheight);
  } else if (s[0] == MLeading) {
    if (leadingbuf[0] == '-') {
      o.leading = - getint(&leadingbuf[1], 0);
    } else {
      o.leading = getint(leadingbuf, 0);
    };
  } else if (s[0] == MMargin) {
    o.margin = getint(marginbuf, 0);
#ifdef BIG_WINDOWS
  } else if (s[0] == MWorkArea) {
    txtwin_setcurrentwindow(t);
    if (s[1] == 0) 
      o.big_windows = !o.big_windows;
    else
    { int i = getint(widthbuf, 0);
      if (i <= 0) i = 1;
      o.big_windows = TRUE;
      o.big_window_size = txtoptmenu__min(i, BIG_WINDOW_SIZE_LIMIT);
    }
#endif
  } else if (s[0] == MWrap) /* invert wrap bit */
     o.wraptowindow = !o.wraptowindow;

  else if (s[0] == MInvert) /* swap fore and back */

          {
          i = o.forecolour;
          o.forecolour = o.backcolour;
          o.backcolour = i;
          }

  else { /* foreground, background. */
    if (s[1] == 0)  /* he just clicked in main menu */
      ;    /* colours are fine */
    else if (s[0] == MForeground) {
      o.forecolour = s[1] - 1;
    } else if (s[0] == MBackground) {
      o.backcolour = s[1] - 1;
    };
  };

  txtar_setoptions(t, &o);

  }
}

/* If he's displaying in a font, he can go direct to the foreground colour
menu to set black-on-white or white-on-black. */

void txtoptmenu_init(void) {
  (void) txtoptmenu__fontmenu(); /* create the font menu */
}

/* end */
