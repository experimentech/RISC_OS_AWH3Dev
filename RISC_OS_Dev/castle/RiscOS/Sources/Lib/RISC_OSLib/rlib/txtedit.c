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
  Purpose: some general-purpose editing facilties for use with Texts
  Author: William Stoye
  History:
    4th August 87 -- started
    20th August 87 -- general overhaul in the light of demos
      this is still an experimental stab, and will undoubtedly
      be a mess. Objectives such as extensibility are dropped for the
      moment, this module is an editor rather than a component of
      an editor.
    02-Mar-88: WRS: changes to undo. Use of better trace.
    02-Mar-88: WRS: xfersend experiments.
    17-Mar-88: igj: new find, format, shell
    13-Dec-89: WRS: menu interactive help.
    14-Dec-89: WRS: msgs literal text put back in.
                    txtedit_menuevent will give menu interactive help
                      if the last wimp event was a help one. (to help help in c.message)
    05-Jan-90: WRS: donormalisepara, if at end of para then format THIS one not NEXT one.
    29-Jan-90: IDJ: changed to use new find technology
    31-Jan-90: IDJ: new dbox added for finding
    31-Jan-90: IDJ: got opening on find dbox small/large depending on 'magic'
     2-Feb-90: IDJ: added raw event handler for find dbox to cure opening problems
                    NB. must still pass things on to help_rawevents
     5-Feb-90: IDJ: changed find dialogue to call dbox_fillin_fixedcaret to stop
                    caret being moved to end of icon, when using magic buttons
     5-Feb-90: IDJ: caret now properly set to end of string after a 'previous' click
    15-Feb-90: IDJ: added up-call on creating new txtedit_state
    16-Feb-90: IDJ: added hex char stuff
    16-Feb-90: IDJ: added "Makefile" to set of default names in txtedit__dftname
    21-Feb-90: IDJ: added use of txtopt_get_name for setting options
    21-Feb-90: IDJ: folded in changes from WRS viz:
                    ctl-sh-left/right to move all windows together.
                    add a \n when sh-importing filename.
    05-Apr-90: IDJ: added optimisation when not using ? in replacement string
    31-May-90: NDR: removed bodge setting estsize=1 if was 0, as xfersend() now fixed
    31-May-90: NDR: deal with Message_DataSaved
     1-Jun-90: NDR: txtmisc routines moved into c.txtmisc
     7-Mar-91: PJC: support for BASIC files added
    29-Apr-91: IDJ: finish off printing support
    09-May-91: ECN: #ifndef out unused ROM functions
    16-May-91: IDJ: Quick hack to txtedit_saveas to get rid of 'data transfer failed'
    12-Jun-91: IDJ: increase buffer size for reading edit$options
    12-Jun-91: IDJ: made filename comparison case-insensitive
    12-Jun-91: IDJ: put window hand and icon no in dataload msg back to !printers
                    and report errors from !printers
    26-Jun-91: IDJ: fixed printing protocol to understand old and new printer mungers
    27-Jun-91: IDJ: experiments with not resetting filename on insert (abandoned)
    28-Jun-91: IDJ: experiments with edit$options and wordwrap,coltab,overwrite
    01-Jul-91: IDJ: close down menu after Sh-F3(Coltab), Sh-F1(Overwrite), Ctrl-F5(WordWrap)
    22-Jul-91: IDJ: stop pretending that all files are text when sending to !printers
    23-Jul-91: IDJ: some tracing inserted to chase interaction with email bug
    08-Aug-91: IDJ: put current type in set type menu, or null if untyped.
    09-Aug-91: IDJ: remove correct handler when error on print selection
    19-Aug-91: IDJ: set edit$options after Sh-F3(Coltab), Sh-F1(Overwrite), Ctrl-F5(WordWrap)
    22-Aug-91: IDJ: remove last string literals from code area
    30-Aug-91: IDJ: when printing send leafname <untitled> if untitled text
    04-Sep-91: IDJ: set correct options on Sh-F3,Sh-F1,Ctrl-F5
    :
    17-Jan-95: AMcC: updated txtedit_infoaboutprogram: Version/Date looked up in Messages file
*/

#define BOOL int
#define TRUE 1
#define FALSE 0

#define PRINT 1
/* 29-Apr-91: IDJ: support for printing */
#define BASIC 1
/* 7-Mar-91: PJC: support for BASIC files wanted */
#define OVERWRITE 1
/* 17-Nov-88: WRS: Overwrite feature - late spec extension. */
#define TAB1 1
/* 17-Nov-88: WRS: late spec change - tab by columns-of-8, user-settable. */
#define NEWDELETE 1
/* 30-Oct-02 KJB: Delete deletes right */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#include <signal.h>
#include <ctype.h>
#include "akbd.h"
#include "werr.h"
#include "menu.h"
#include "os.h"
#include "wimp.h"
#include "wimpt.h"
#include "txt.h"
#include "win.h"
#include "txtwin.h"
#include "flex.h"
#include "txtscrap.h"
#include "event.h"
#include "txtedit.h"
#include "EditIntern/txtfind.h"
#include "EditIntern/txtmisc.h"
#include "EditIntern/txtundo.h"
#include "EditIntern/txt1.h"
#include "EditIntern/txtar.h"    /* >>>> because of TextOptMen, Options */
#include "dboxquery.h"
#include "dboxfile.h"
#include "trace.h"
#include "dbox.h"
#include "EditIntern/txtoptmenu.h"
#include "xfersend.h"
#include "xferrecv.h"
#include "saveas.h"
#include "typdat.h"
#include "fileicon.h"
#include "visdelay.h"
#include "EditIntern/txtfile.h"
#include "EditIntern/txtregexp.h"
#include "swis.h"
#ifdef SETOPTIONS
#include "txtopt.h"
#endif

#include "msgs.h"
#include "help.h"
#include "template.h"
#include "VerIntern/messages.h"

txtedit_state *txtedit_newwithoptions(char *filename, int desired_filetype, txtar_options *o);
void txtedit_splitwindow(void *v);
void txtedit_swapcase(txt);
void txtedit__undomajor(txtedit_state *s);
static void txtedit_deleteselection(void);
static void txtedit_clearselection(txt);

#define txtedit_AMax 20


/* Offsets within the main menu tree for an editor window. */

#define txtedit_MMisc 1
#define txtedit_MFile 2
#define txtedit_MSel 3
#define txtedit_MEdit 4
#define txtedit_MDisplay 5

#define txtedit_MAboutProgram 1
#define txtedit_MAboutFile 2
#define txtedit_MNewType 3
#define txtedit_MSplit 4
#if PRINT
#define txtedit_MPrint 5

#define txtedit_MColTab 6
#define txtedit_MOverwrite 7
#define txtedit_MWordwrap 8
#define txtedit_MTrace 9
#define txtedit_MNoTrace 10

#else
/* no PRINT */

#define txtedit_MColTab 5
#define txtedit_MOverwrite 6
#define txtedit_MWordwrap 7
#define txtedit_MTrace 8
#define txtedit_MNoTrace 9

#endif    /* PRINT */

#if PRINT
#define txtedit_MSelSave 1
#define txtedit_MSelPrint 2
#define txtedit_MSelSwapCase 3
#define txtedit_MSelIndent 4
#define txtedit_MSelCut 5
#define txtedit_MSelCopy 6
#define txtedit_MSelPaste 7
#define txtedit_MSelDelete 8
#define txtedit_MSelSelAll 9
#define txtedit_MSelClear 10
#else
#define txtedit_MSelSave 1
#define txtedit_MSelSwapCase 2
#define txtedit_MSelIndent 3
#define txtedit_MSelCut 4
#define txtedit_MSelCopy 5
#define txtedit_MSelPaste 6
#define txtedit_MSelDelete 7
#define txtedit_MSelSelAll 8
#define txtedit_MSelClear 9
#endif  /* PRINT */

#define txtedit_MFind 1
#define txtedit_MGoto 2
#define txtedit_MUndo 3
#define txtedit_MRedo 4
#define txtedit_MExchangeCRLF 5
#define txtedit_MExpandTabs 6
#define txtedit_MFormatText 7

/* field offsets for the Find and Found DBoxes. */

/* IDJ 31-Jan-90 Size of extension to find dbox */
#define txtedit_small_findbox  0
#define txtedit_large_findbox  1

#define txtedit_FiGo 0
#define txtedit_FiPrevious 1
#define txtedit_FiFind 2
#define txtedit_FiReplace 3
#define txtedit_FiMsg 4      /* output, for saying "not found". */
/* 5, 6 are text for prompt - we don't use them */
#define txtedit_FiCount 7
#define txtedit_FiCase 8
#define txtedit_FiMagic 9
#define txtedit_FiRegularExpressions 10
#define txtedit_FiAny   11
#define txtedit_FiNewline 12
#define txtedit_FiAlphanum 13
#define txtedit_FiDigit 14
#define txtedit_FiCtrl 15
#define txtedit_FiNormal 16
#define txtedit_FiSetBra 17
#define txtedit_FiSetKet 18
#define txtedit_FiNot 19
#define txtedit_Fi0OrMore 20
#define txtedit_Fi1OrMore 21
#define txtedit_FiMost 22
#define txtedit_FiTo 23
#define txtedit_FiFound 24
#define txtedit_FiField 25
#define txtedit_FiHex 26

#define txtedit_FiBackGnd 27
#define txtedit_FiFoundString 36


#define txtedit_FoStop 0
#define txtedit_FoCont 1
#define txtedit_FoRep 2
#define txtedit_FoLastRep 3
#define txtedit_FoEndRep 4
#define txtedit_FoMsg 5      /* output, for saying how many done */
#define txtedit_FoUndo 6
#define txtedit_FoRedo 7


/* fields of Indent DBox */

#define txtedit_IndOK 0
#define txtedit_IndCancel 1
#define txtedit_IndBy 2


/* fields for Goto DBox. */

#define txtedit_GoGo 0
#define txtedit_GoCancel 1
#define txtedit_GoCurrentLine 2
#define txtedit_GoCurrentChar 3
#define txtedit_GoLine 4


#define txtedit_IFOK 0
#define txtedit_IFName 1       /* text output */
#define txtedit_IFModified 2   /* YES or NO text */
#define txtedit_IFType 3       /* output */
#define txtedit_IFSize 4       /* numeric output */
#define txtedit_IFLastUpdate 5 /* text output */
#define txtedit_IFIcon 6       /* icon output */

/* Standard tool for editors? */
/* could toggle update flag, change type/name */

/* The rest is just decoration. */
/* Is this a standard useful template for editors? */

/* -------- statics. -------- */

static void *clipboard_anchor = NULL;
static int   clipboard_ref = -1;
static txtedit_state *txtedits = NULL; /* list of them all */

/* -------- -------- */

typedef enum
{
  txtedit_SEL = 1, txtedit_EXT = 2, txtedit_CTLSEL = 4, txtedit_NONE = 8
} txtedit_SELACTION;

/* handlers and handles for update/close/save/shutdown */
static txtedit_update_handler txtedit__update_handler = 0;
static txtedit_save_handler txtedit__save_handler = 0;
static txtedit_close_handler txtedit__close_handler = 0;
static txtedit_shutdown_handler txtedit__shutdown_handler = 0;
static txtedit_undofail_handler txtedit__undofail_handler = 0;
static txtedit_open_handler txtedit__open_handler = 0;
static void *txtedit__update_handle = 0;
static void *txtedit__save_handle = 0;
static void *txtedit__close_handle = 0;
static void *txtedit__shutdown_handle = 0;
static void *txtedit__undofail_handle = 0;
static void *txtedit__open_handle = 0;

#if BASIC
static int txtedit__detokenise = -1;
static int txtedit__tokenise = -1;
static int txtedit__increment = 10;
static BOOL txtedit__strip = TRUE;
#endif

static int cistrcmp(const char *s1, const char *s2)
{
  int ch1, ch2;
  for (;;) {
    ch1 = *s1++;  ch2 = *s2++;
    /* care here for portability... don't rely on ANSI spec */
    if (isupper(ch1)) ch1 = tolower(ch1);
    if (isupper(ch2)) ch2 = tolower(ch2);
    if (ch1 != ch2) return ch1-ch2;
    if (ch1 == 0) return 0;
  }
}

static txtedit_state *txtedit__init(txt t)
{

txtedit_state  *s;
#ifdef SET_MISC_OPTIONS
txtar_options opts;
#endif

s = malloc(sizeof(txtedit_state));
if (s == 0) return 0;

s->t = t;
txt_newmarker(t, &s->selpivot);
s->seltype       = txtedit_CHARSEL;
s->selectrecent  = FALSE;
s->filename[0]   = 0;
s->ty.ex = -1;
s->ty.ld = -1;
txtfile_buildnewtimestamp(s->ty, &s->ty);
s->next          = txtedits;

#ifndef SET_MISC_OPTIONS

#if OVERWRITE
s->overwrite     = FALSE;
#endif

#if TAB1
s->wordtab       = TRUE;
#endif

#if WORDWRAP
s->wordwrap    = FALSE;
#endif

#else

txtar_getoptions(s->t, &opts);
s->overwrite = opts.overwrite;
s->wordtab = opts.wordtab;
s->wordwrap = opts.wordwrap;

#endif

txtedits         = s;

/* Force the creation of the menu tree early on.
This prevents embarassing cases of running out of memory. */
txtedit_menu(s);

return(s);

}

void txtedit_dispose(txtedit_state *s)
{

if (txtscrap_selectowner() == s->t)
   txtscrap_setselect(NULL, 0, 0); /* Relinquish since disposing */

txt_disposemarker(s->t, &(s->selpivot));
txt_dispose(&(s->t));

/* remove s from the list of all text editors. */
if (txtedits == s) {
  txtedits = s->next;
} else {
  txtedit_state *ptr = txtedits;
  while (ptr->next != s) {
    ptr = ptr->next;
  };
  ptr->next = s->next;
};

free(s);
}

static int txtedit__countupdated(void) {
  txtedit_state *ptr = txtedits;
  int count = 0;
  while (ptr != 0) {
    if ((txt_charoptions(ptr->t) & txt_UPDATED) != 0) count++;
    ptr = ptr->next;
  };
  return count;
}

BOOL txtedit_mayquit(void) {
  int count = txtedit__countupdated();
  if (count == 0) {
    return TRUE;
  } else {
    char a[80];
    if (count == 1) {
      sprintf(a, msgs_lookup(MSGS_txt6));
    } else {
      sprintf(a, msgs_lookup(MSGS_txt7), count);
    };
    return (dboxquery_quit(a) == dboxquery_quit_DISCARD);
  }
}

/* 14-Dec-88 WRS: can recurse in txtedit_mayquit! */

void txtedit_prequit(void) {
  int count = txtedit__countupdated();
  if (count != 0) {
    /* First, acknowledge the message. */
    wimp_eventstr *e = wimpt_last_event();
    if ((e->e == wimp_ESEND || e->e == wimp_ESENDWANTACK)
    && e->data.msg.hdr.action == wimp_MPREQUIT)
    {
      wimp_t taskmgr = e->data.msg.hdr.task;

      /* amg 8th August 1994 add awareness of flag word */
      int size_of_prequit = e->data.msg.hdr.size;
      int flags_of_prequit = e->data.msg.data.words[0];

      e->data.msg.hdr.your_ref = e->data.msg.hdr.my_ref;
      wimpt_noerr(wimp_sendmessage(wimp_EACK, &e->data.msg, e->data.msg.hdr.task));
      /* And then tell the user. */
      if (txtedit_mayquit()) {
        /* start up the closedown sequence again. */
        /* We assume that the sender is the Task Manager, and that sh-ctl-12
        is the closedown key sequence. */
        wimp_eventdata ee;
        if (txtedit__shutdown_handler != 0)
           txtedit__shutdown_handler(txtedit__shutdown_handle);

        if (size_of_prequit > sizeof(wimp_msghdr) && flags_of_prequit & 1)
        {
          /* we are being killed individually by the Task Manager */
          /* do NOT send back a C/S/F12 */
        }
        else
        {
          wimpt_noerr(wimp_get_caret_pos(&ee.key.c));
          ee.key.chcode = akbd_Sh + akbd_Ctl + akbd_Fn12;
          wimpt_noerr(wimp_sendmessage(wimp_EKEY, (wimp_msgstr*) &ee, taskmgr));
        }
        /* and stop. */
        while (txtedits != 0) txtedit_dispose(txtedits);
      };
    };
  };
}

static txtedit_state *txtedit_findnamedtxt(char *filename) {
  txtedit_state *ptr = txtedits;
  tracef1("txtedit_findnamedtext of '%s'.\n", (int) filename);
  while (ptr != 0 && cistrcmp(ptr->filename, filename) != 0) {
    ptr = ptr->next;
    tracef1("txtedit_findnamedtext try %i.\n", (int) ptr);
  };
  tracef1("txtedit_findnamedtext returns %i.\n", (int) ptr);
  return ptr;
}

static txtedit_state *txtedit__findtxt(txt t) {
  txtedit_state *ptr = txtedits;
  tracef0("txtedit_findtext'.\n");
  while (ptr != 0 && t != ptr->t) {
    ptr = ptr->next;
    tracef1("txtedit_findtext try %i.\n", (int) ptr);
  };
  tracef1("txtedit_findtext returns %i.\n", (int) ptr);
  return ptr;
}

/* PJC: I've had to made settexttitle public so that my code in txtfile
        can set the title
*/

void txtedit_settexttitle(txtedit_state *s)
{

char a[356];
char b[20];

int updated;
unsigned n;
char *name;

if (s->filename[0] == 0) {
  name = msgs_lookup(MSGS_txt65);
} else {
  name = s->filename;
};

updated = (txt_UPDATED & txt_charoptions(s->t)) !=0;
n = txtwin_number(s->t);

a[0] = 0;
strcat(a, name);
if (updated)
{
   if (txtedit__update_handler != 0)
      if (txtedit__update_handler(s->filename, s, txtedit__update_handle) == FALSE)
      {
            int i = 20;
            BOOL undo_failed = FALSE;
            txtundo_result res;

            if(txtundo_undo(s->t) == txtundo_RANOUT)
               undo_failed = TRUE;
            while ((res = txtundo_undo(s->t)) == txtundo_MINOR) {
                   i--;
                   if (i == 0) txt_setcharoptions(s->t, txt_DISPLAY, 0);
            };
            if (res == txtundo_RANOUT) undo_failed = TRUE;
            if (i <= 0) txt_setcharoptions(s->t, txt_DISPLAY, txt_DISPLAY);
           /*txtedit__undomajor(s);*/
           if(undo_failed == TRUE)
           {
              if(txtedit__undofail_handler != 0)
                 txtedit__undofail_handler(s->filename, s, txtedit__undofail_handle);
           }
           else
           {
              txt_setcharoptions(s->t, txt_UPDATED, 0);
              return;  /* ie don't modify text !!!! */
           }
      }
   strcat(a, " *");
}
if (n > 1) {
  sprintf(b, " %d", n);
  strcat(a, b);
};
if (! s->wordtab) strcat(a, msgs_lookup(MSGS_txt23));
if (s->overwrite) strcat(a, msgs_lookup(MSGS_txt24));
if (s->wordwrap) strcat(a, msgs_lookup(MSGS_txt25));

txt_settitle(s->t, a);

}



/* -------- The Menu. -------- */

static menu txtedit__menu = 0;
static menu m1;
/*static menu m2;*/
static menu m3;
static menu m4;
static menu m5;
static char fwidthbuf[10] = "76"; /* format width */
static char filetypebuff[10] = ""; /* new file type */

static void txtedit__menumaker(void *a)
{
  txtedit_state *s = (txtedit_state *) a;
  menu mt;

  txtedit__menu = menu_new(
    msgs_lookup(MSGS_txt10),
    msgs_lookup(MSGS_txt11));

  m1 = menu_new(
   msgs_lookup(MSGS_txt12),
   msgs_lookup(MSGS_txt13));

  mt = menu_new(msgs_lookup(MSGS_txt13a), "foo");
  menu_make_writeable(mt, 1, filetypebuff, sizeof(filetypebuff)-1, "a~.");
  menu_submenu(m1, txtedit_MNewType, mt);
  menu_submenu(txtedit__menu, txtedit_MMisc, m1);

  m3 = menu_new(
    msgs_lookup(MSGS_txt14),
    msgs_lookup(MSGS_txt15));
  menu_submenu(txtedit__menu, txtedit_MSel, m3);

  m4 = menu_new(
    msgs_lookup(MSGS_txt16),
    msgs_lookup(MSGS_txt17));
  mt = menu_new(msgs_lookup(MSGS_txt18), msgs_lookup(MSGS_txt72));
  menu_make_writeable(mt, 1, fwidthbuf, sizeof(fwidthbuf)-1, "a0-9");
  menu_submenu(m4, txtedit_MFormatText, mt);
  menu_submenu(txtedit__menu, txtedit_MEdit, m4);

  m5 = txtoptmenu_make(s->t);
  menu_submenu(txtedit__menu, txtedit_MDisplay, m5);
}

static void txtedit__help_handler(void *a, char *hit)
{
  txtedit_state *s = (txtedit_state *) a;

  s = s; /* to avoid compiler warning */
  if (help_genmessage("HELP", hit))
    ;
  else
  {
    hit[2] = 0; /* try truncated form */
    help_genmessage("HELPX", hit);
  }
}

static menu txtedit_menumaker(void *a) {
  txtedit_state *s = (txtedit_state *) a;
  char *p = filetypebuff;
  BOOL selection = txtscrap_selectowner() != s->t;

  /* IDJ: 30-Jul-91: insert current filetype */
  if (((unsigned int) s->ty.ld >> 20) == 0xfff)
  {
    os_swi4r(OS_FSControl, 18, 0, 0xfff & (s->ty.ld >> 8), 0,
             NULL, NULL, (int*) &filetypebuff[0], (int*) &filetypebuff[4]);
    while (*p > ' ' && p < filetypebuff + 8) p++;
  }
  *p = 0;

  txtwin_setcurrentwindow(s->t);
  if (txtedit__menu == 0) txtedit__menumaker(a);
  help_register_handler(txtedit__help_handler, s);
  menu_setflags(txtedit__menu, txtedit_MEdit, FALSE, FALSE);

  /* Place ticks where required */
  menu_setflags(m1, txtedit_MOverwrite, s->overwrite, FALSE);
  menu_setflags(m1, txtedit_MColTab, ! s->wordtab, FALSE);
  menu_setflags(m1, txtedit_MWordwrap, s->wordwrap, FALSE);
#if TRACE
  menu_setflags(m1, txtedit_MTrace, trace_is_on(), FALSE);
  menu_setflags(m1, txtedit_MNoTrace, ! trace_is_on(), FALSE);
#endif

  /* Shade selection menu as required (except Paste entry, done on menu warning) */
  menu_setflags(m3, txtedit_MSelSave,     FALSE, selection);
#if PRINT
  menu_setflags(m3, txtedit_MSelPrint,    FALSE, selection);
#endif
  menu_setflags(m3, txtedit_MSelSwapCase, FALSE, selection);
  menu_setflags(m3, txtedit_MSelIndent,   FALSE, selection);
  menu_setflags(m3, txtedit_MSelCopy,     FALSE, selection);
  menu_setflags(m3, txtedit_MSelCut,      FALSE, selection);
  menu_setflags(m3, txtedit_MSelDelete,   FALSE, selection);
  menu_setflags(m3, txtedit_MSelClear,    FALSE, selection);

  /* Adjust font/colour menu options */
  txtoptmenu_make(s->t);

  return txtedit__menu;
}

menu txtedit_menu(txtedit_state *s) {
  return txtedit_menumaker((void*) s);
}

static int txtedit_noticeseveral(int *c, unsigned *count)

/* Look for more characters like c. If there are no more, return FALSE with
count=1. If there are more, increase count on return. If you read ahead
a separate char then put it in c, and return TRUE. */

{

unsigned c1;

c1 = *c;
*count = 1;

while (c1 == *c)

     {
     if (akbd_pollkey(c))
       if (*c == c1)
         ++*count;
       else
         return 1;
     else
       return 0;
     }
return 0;
}

/* -------- Wordwrap. -------- */

#if WORDWRAP

static int txtedit__parawidth(txtedit_state *s) {
  int width;
  if (s->wordwrap && sscanf(fwidthbuf, "%i", &width) == 1) {
    return width;
  } else {
    return 0; /* means do no formatting. */
  };
}

static void txtedit_normalisepara(txtedit_state *s) {
  txtmisc_normalisepara(s->t, txtedit__parawidth(s));
}

static void txtedit_donormalisepara(txtedit_state *s) {
  BOOL waswrap = s->wordwrap;

  visdelay_begin();
  /* 05-Jan-90 - used to format next para if at end of para */
  #if FALSE
    while (txt_charatdot(s->t) == '\n' && txtmisc_paraend(s->t, txt_dot(s->t))) txt_movedot(s->t, 1);
  #else
    /* If between paragraphs, move to the start of the next one. */
    if (txt_dot(s->t) == 0 || txt_charat(s->t, txt_dot(s->t) -1) == '\n')
      while (txt_charatdot(s->t) == '\n') txt_movedot(s->t, 1);
  #endif

  s->wordwrap = TRUE;
  txtedit_normalisepara(s);
  s->wordwrap = waswrap;
#if FALSE
  txt_setdot(s->t, txtmisc_eop(s->t, 1 + txt_dot(s->t)));
#else
  txt_setdot(s->t, 1 + txtmisc_eop(s->t, txt_dot(s->t)));
#endif

  visdelay_end();
}

#endif

/* ---end of WordWrap stuff ----- */


static int txtedit_keyboardinput(txtedit_state *s, int *c)

/* c is a character code. Process this, and any following. If you have to
poll ahead and yet not use what you find, put it in c and return TRUE.
Otherwise, return FALSE. */

{

char a[txtedit_AMax];
unsigned count;
int result;

count = 0;
result = 0;

while (count < txtedit_AMax)
     {
     a[count++] = *c % 256;
     if (! akbd_pollkey(c))
       break;
     if (*c == 13) *c = 10; /* newlines etc. */
     if ((*c < 32 || *c >= 127) && *c != 10)

       /* This may mean that some funny chars get done individually:
       not important compared to normal chars. */

       {
       result = 1;
       break;
       }

     }

tracef1("KeyboardInput of %d chars.\n", count);

txt_setcharoptions(s->t, txt_CARET, 0);

/* Typing replaces selection */
if (txtscrap_selectowner() == s->t) txtedit_deleteselection();

#if OVERWRITE
/* Replace characters, until the next newline in the text. */
{
  int i = 0;
  if (s->overwrite && a[0] != '\n')
    while (i < count && txt_charat(s->t, txt_dot(s->t) + i) != '\n') i++;
  txt_replacechars(s->t, i, a, count);
};
#else
txt_replacechars(s->t, 0, a, count);
#endif

#if WORDWRAP
if (count > 1 || a[0] != '\n') {
  /* don't do it if he just hit RETURN. */
  txtedit_normalisepara(s);
}
#endif

txt_movedot(s->t, count);
txt_setcharoptions(s->t, txt_CARET, txt_CARET);

return(result);

}



/* -------- Mouse Manipulation. -------- */

static void txtedit_mouse(txtedit_state *s, txt_mouseeventflag mflags, txt_index at)

{

txtedit_SELACTION action;
BOOL selectwasrecent = s->selectrecent;
BOOL drag = (((mflags & txt_MSELOLD) != 0) ||
            ((mflags & txt_MEXTOLD) != 0));

s->selectrecent = FALSE;

tracef1("Mouse drag=%d.\n", drag);

if (!drag)
  {

  if ((mflags & txt_MEXACT) != 0)
    {
    /* Cycle round single->double->triple click */
    if (s->seltype == txtedit_CHARSEL)
      s->seltype = txtedit_WORDSEL;
    else if (s->seltype == txtedit_WORDSEL)
          s->seltype = txtedit_LINESEL;
    else
          s->seltype = txtedit_CHARSEL;
    }
  else
    {
    /* For SELECT, cancel any existing selection and start again */
    if (mflags & txt_MSELECT) txtedit_clearselection(s->t);
    /* and for both SELECT and ADJUST reset the click state machine */
    s->seltype = txtedit_CHARSEL;
    }
  }

tracef1("Mouse selType=%d.\n", s->seltype);

if ((mflags & txt_MEXTEND) != 0) action = txtedit_EXT;

else if ((mflags & txt_MSELECT) != 0)
       {
       action = txtedit_SEL;

       /* not set on multi-click, but that's OK because we'll be setting
       the selection anyway. */

       if (drag)
         {
           if (at != txt_dot(s->t))
             {
             /* Treat this case as an EXT, by popular demand. */
             action = txtedit_EXT; /* drag SEL -> make selection. */
             if (selectwasrecent) txtscrap_setselect(s->t, 0, 0); /* make a new selection. */
             }
         }
       else
         {
         s->selectrecent = TRUE;
         if (s->seltype == txtedit_CHARSEL) {
           txt_movemarker(s->t, &s->selpivot, at);
         } else if (s->seltype == txtedit_WORDSEL) {
           txt_movemarker(s->t, &s->selpivot, txtmisc_bow(s->t, at));
           txt_setcharoptions(s->t, txt_CARET, 0); /* Hide caret for non zero width sel */
         } else { /* s->seltype == txtedit_LINESEL */
           txt_movemarker(s->t, &s->selpivot, txtmisc_bol(s->t, at));
           txt_setcharoptions(s->t, txt_CARET, 0); /* Hide caret for non zero width sel */
         };
         }

       }

    /* This implies that multi-drag-select does a new trial selection, rather
          than a drag. I think that this is more consistent with the chosen model.
    */
else
  action = txtedit_NONE;

tracef1("Mouse action=%d.\n", action);

if (action == txtedit_NONE)
  action = action; /* do nothing */
else if (s->seltype == txtedit_WORDSEL)
  {
       if (s->selectrecent) txt_movemarker(s->t, &s->selpivot, at);
       txtmisc_selectpointandword(s->t, txt_indexofmarker(s->t, &s->selpivot), at);
       if (s->selectrecent) txt_movemarker(s->t, &s->selpivot, txt_selectstart(s->t));
  }
else if (s->seltype == txtedit_LINESEL)
       txtmisc_selectpointandline(s->t, txt_indexofmarker(s->t, &s->selpivot), at);
else if (action == txtedit_SEL) /* drag or not, don't care */
       {

         if (txt_dot(s->t) != at || !drag)
           /* not doing it reduces flicker: yuk, tweaky! */
           txt_setdot(s->t, at);
       }

else if (drag)
       {
         /* ext */
         txtscrap_setselect(s->t, txt_indexofmarker(s->t, &s->selpivot), at);
       }
else if (action == txtedit_EXT)
       {
       if (txt_selectset(s->t))
         txt_movemarker(s->t, &s->selpivot,
                        txtmisc_furthestaway(s->t, at, txt_selectstart(s->t), txt_selectend(s->t)));
       else
         txt_movemarker(s->t, &s->selpivot, txt_dot(s->t));
       txtscrap_setselect(s->t, txt_indexofmarker(s->t, &s->selpivot), at);
       }
}

static BOOL escflag = FALSE; /* for escaping from long searches. */

void txtedit__redomajor(txtedit_state *s, int harmless); /* forw ref */

static void eschandler(int type) {
  type=type;
  (void) signal(SIGINT, &eschandler);
  escflag = TRUE;
}


static void txtedit__extend_findbox(wimp_w whandle, int size)
{
   wimp_wstate state;
   wimp_icon magic_icon, found_icon;
   int growth;
   template *t;
   int small_size = 0;

   /* belt and braces code to ensure no probs, when dragging window, and pressing F5 */
   /* seems to cause probs, if we don't do the following */
   if ((t = template_find("find")) != 0)
      small_size = t->window.box.y1 - t->window.box.y0;

   /* get the window state */
   wimpt_noerr(wimp_get_wind_state(whandle, &state));

   /* use icon defs to set size of window */
   wimp_get_icon_info(whandle, txtedit_FiMagic, &magic_icon);
   wimp_get_icon_info(whandle, txtedit_FiFound, &found_icon);

   growth = magic_icon.box.y0 - found_icon.box.y0;

   /* change bottom of window */
   if (size == txtedit_small_findbox)
       state.o.box.y0 = state.o.box.y1 - small_size;
   else
       state.o.box.y0 = state.o.box.y1 - small_size - growth;

   /* open it again */
   wimpt_noerr(wimp_open_wind(&state.o));
}




static int txtedit_getnumeric(dbox d, dbox_field f)
{
    wimp_icon icon;
    wimpt_noerr(wimp_get_icon_info(dbox_syshandle(d), f, &icon));
    if ((icon.flags & wimp_ISELECTED) != 0)
       return 1;
    else
       return 0;
}

/* 2-Feb-90 IDJ: Experiment with catching raw events on the find dbox to
                    solve opening wrong size problem on drag
*/

static BOOL txtedit__findbox_rawevents(dbox d, void *event, void *handle)
{
   wimp_eventstr *e = (wimp_eventstr *)event;

     /* event handling:  EOPEN:  open to appropriate size
                         else:   pass it on to the help handler (yuk!)
     */
   switch(e->e)
   {
      case wimp_EOPEN:
           /* see if magic chars is set (if so make findbox big) */
         { wimp_icon icon;
#ifdef ALLOW_OLD_PATTERNS
           wimp_icon icon_reg;
#endif
           wimp_w find_handle = dbox_syshandle(d);
           wimp_get_icon_info(find_handle, txtedit_FiMagic, &icon);
#ifdef ALLOW_OLD_PATTERNS

           wimp_get_icon_info(find_handle, txtedit_FiRegularExpressions, &icon_reg);
#endif

           /* IDJ 31-Jan-90: Magic is now a click icon */
           /* When magic is on, the extra icons appear - when not, they go away */
           wimpt_noerr(wimp_open_wind(&e->data.o));
           if ((icon.flags & wimp_ISELECTED) != 0
#ifdef ALLOW_OLD_PATTERNS
|| (icon_reg.flags & wimp_ISELECTED) != 0
#endif
)
             txtedit__extend_findbox(find_handle, txtedit_large_findbox);
           else
             txtedit__extend_findbox(find_handle, txtedit_small_findbox);
         }
         return TRUE;

      default:
           /* pass it on to the interactive help handler */
           return help_dboxrawevents(d, event, handle);
   }
}

static BOOL txtedit__use_ambiguous(dbox find)
{
   char replace[256];
   int i = 0;

   dbox_getfield(find, txtedit_FiReplace, replace, 255);

   while (i < 255 && replace[i] != 0)
   {
      if (replace[i] == txtfind_field_ch && isdigit(replace[i+1])) return TRUE;
      i++;
   }

   return FALSE;
}


static void txtedit__swap_icons(wimp_w w, int old_lo, int old_hi, int new_lo, int new_hi)
{
   int i;

   /* --- get rid of old icons --- */
   for (i = old_lo; i <= old_hi; i++) wimpt_noerr(wimp_set_icon_state(w, i, wimp_IDELETED, wimp_IDELETED));

   /* --- re-incarnate new icons --- */
   for (i = new_lo; i <= new_hi; i++) wimpt_noerr(wimp_set_icon_state(w, i, 0, wimp_IDELETED));
}


static void txtedit_find(txtedit_state *s)
{

static dbox       find = NULL;
static dbox       found = NULL;
char              finds[256], repls[256], previousFind[256], previousReplace[256];

txt_index         at, wasat, endat;
dbox_field        cmd1, cmd2;
int               loopflag1, loopflag2, majorEdits, undoneEdits;
BOOL              magic, Case, oldMagic, oldCase, previous = FALSE;
#ifdef ALLOW_OLD_PATTERNS
BOOL              oldRegular;
#endif
Pattern           *pattern = NULL;
wimp_w            find_handle;

#ifdef FIELDNUM
Ambiguous_entry ambiguous[MAX_AMBIGUOUS];
SubPattern sub_patterns[128];
int amb;
int sub;
int TD1[256];
#endif



majorEdits = 0;
undoneEdits = 0;

if (find == NULL) {
  find = dbox_new("find");
  if (find == 0) return;
};

find_handle = dbox_syshandle(find);

dbox_raw_eventhandler(find, txtedit__findbox_rawevents, "FIND");

dbox_setfield(find, txtedit_FiMsg, "");

if (found == NULL) {
  found = dbox_new("found");
  if (found == 0) return;
};
dbox_raw_eventhandler(found, help_dboxrawevents, "FOUND");

oldMagic = txtedit_getnumeric(find, txtedit_FiMagic);
oldCase = dbox_getnumeric(find, txtedit_FiCase);
#ifdef ALLOW_OLD_PATTERNS
oldRegular = txtedit_getnumeric(find, txtedit_FiRegularExpressions);
#endif
dbox_getfield(find, txtedit_FiFind, &previousFind[0], 255);
dbox_getfield(find, txtedit_FiReplace, &previousReplace[0], 255);

/* >>>> Maybe these should be reset every time. I suspect, however, that
they are things that people will typically leave set for longish periods.
Thus, let's try not setting them. */

dbox_setfield(find, txtedit_FiFind, "");
dbox_setfield(find, txtedit_FiReplace, "");


dbox_show(find);

/* 2-2-90 IDJ extra safety in case dbox is wrong size */
   if (oldMagic
#ifdef ALLOW_OLD_PATTERNS
|| oldRegular
#endif
)
       txtedit__extend_findbox(find_handle, txtedit_large_findbox);
   else
       txtedit__extend_findbox(find_handle, txtedit_small_findbox);


loopflag1 = 1;

while (loopflag1)

{
     if (previous)
     {
         cmd1 = dbox_fillin(find);
         previous = FALSE;
     }
     else
         cmd1 = dbox_fillin_fixedcaret(find);

     switch (cmd1)

     {
     case txtedit_FiPrevious:
         { int latest_magic = txtedit_getnumeric(find, txtedit_FiMagic);
#ifdef ALLOW_OLD_PATTERNS
           int latest_regular = txtedit_getnumeric(find, txtedit_FiRegularExpressions);
#endif

           dbox_setnumeric(find, txtedit_FiMagic, oldMagic);
#ifdef ALLOW_OLD_PATTERNS
           dbox_setnumeric(find, txtedit_FiRegularExpressions, oldRegular);
#endif
           /* IDJ 31-Jan-90 May need to change size of dbox */
           /* check with WRS that previous really does mean this */
           if (latest_magic != oldMagic
#ifdef ALLOW_OLD_PATTERNS
|| latest_regular != oldRegular
#endif
)
           {
#ifdef ALLOW_OLD_PATTERNS
              if (oldMagic)
                  txtedit__swap_icons(find_handle, txtedit_FiAny, txtedit_FiHex, txtedit_FiBackGnd, txtedit_FiFoundString);
              else if (oldRegular)
                  txtedit__swap_icons(find_handle, txtedit_FiBackGnd, txtedit_FiFoundString, txtedit_FiAny, txtedit_FiHex);
#endif
              if (oldMagic
#ifdef ALLOW_OLD_PATTERNS
|| oldRegular
#endif
              ) txtedit__extend_findbox(find_handle, txtedit_large_findbox);
              else txtedit__extend_findbox(find_handle, txtedit_small_findbox);
           }

           dbox_setnumeric(find, txtedit_FiCase, oldCase);
           dbox_setfield(find, txtedit_FiFind, &previousFind[0]);
           dbox_setfield(find, txtedit_FiReplace, &previousReplace[0]);
           previous = TRUE;
           break;
         }

     case txtedit_FiCount:
         dbox_getfield(find, txtedit_FiFind, &finds[0], 255);
         magic = txtedit_getnumeric(find, txtedit_FiMagic)
#ifdef ALLOW_OLD_PATTERNS
|| txtedit_getnumeric(find, txtedit_FiRegularExpressions)
#endif
;
         Case = dbox_getnumeric(find, txtedit_FiCase);

         if (finds[0] == 0) break;
         /* 20-Dec-88 WRS: if null string to search for, ignore the search. */

         dbox_setfield(find, txtedit_FiMsg, msgs_lookup(MSGS_txt31));

         at = txt_dot(s->t);
         {
           int count = 0;
           int x, y;
           char msg[40];
           typedef void SignalHandler(int);
           SignalHandler *oldeschandler;

           visdelay_begin();
           oldeschandler = signal(SIGINT, &eschandler);
           escflag = FALSE;
           x = 0; y = 0;
           wimpt_noerr(os_byte(229, &x, &y));

           wasat = at;

           /* IDJ Jan-90 -- Change so that pattern is lexed ONCE, and then search done */
           pattern = txtfind_build_pattern(&finds[0], magic, !Case
#ifdef ALLOW_OLD_PATTERNS
, txtedit_getnumeric(find, txtedit_FiMagic)
#endif
#ifdef FIELDNUM
, 0
#endif
);

           /* IDJ Oct-90 -- Also now use enhanced Boyer-Moore on leading substring */
           if (pattern)
               txtfind_build_TD1(TD1, pattern, !Case);

           while (txtfind_find(s->t, &at, pattern, !Case
#ifdef FIELDNUM
, 0 ,0 , FALSE              /* IDJ: 5-Apr-90: don't need ambiguous patterns for counting */
#endif
, TD1
) != -1)
           {
             if (at == wasat) { /* foolish thing to count. */
               break;
             };
             count++;
             /* tracef2("counting, at=%i count=%i.\n", at, count); */
             if (escflag) break;
           };

           x = 1; y = 0;
           wimpt_noerr(os_byte(229, &x, &y));
           (void) signal(SIGINT, oldeschandler);
           visdelay_end();

           sprintf(msg, msgs_lookup(MSGS_txt32), count);
           dbox_setfield(find, txtedit_FiMsg, msg);
         };
         break;

     case txtedit_FiGo:
         dbox_getfield(find, txtedit_FiFind, &finds[0], 255);
         dbox_getfield(find, txtedit_FiReplace, &repls[0], 255);
         magic = txtedit_getnumeric(find, txtedit_FiMagic)
#ifdef ALLOW_OLD_PATTERNS
|| txtedit_getnumeric(find, txtedit_FiRegularExpressions)
#endif
;
         Case = dbox_getnumeric(find, txtedit_FiCase);

         if (finds[0] == 0) break;
         /* 20-Dec-88 WRS: if null string to search for, ignore the search. */

         dbox_setfield(find, txtedit_FiMsg, msgs_lookup(MSGS_txt33));

         txtundo_separate_major_edits(s->t);
         majorEdits++;

         wasat = txt_dot(s->t);
         endat = wasat;

         visdelay_begin();

         /* IDJ Jan-90 -- parse pattern just once */
#ifdef FIELDNUM
         for (amb = 0; amb < MAX_AMBIGUOUS; amb++)
              ambiguous[amb].start = ambiguous[amb].end = -1;
         for (sub = 0; sub < 128; sub++)
         {
            sub_patterns[sub].start_node = 0xffffffff;
            sub_patterns[sub].flags = 0;
            sub_patterns[sub].start_pos = -1;
         }
#endif
         pattern = txtfind_build_pattern(&finds[0], magic, !Case
#ifdef ALLOW_OLD_PATTERNS
, txtedit_getnumeric(find, txtedit_FiMagic)
#endif
#ifdef FIELDNUM
, (txtedit__use_ambiguous(find))?sub_patterns:0
#endif
);

         /* IDJ Oct-90 -- Also now use enhanced Boyer-Moore on leading substring */
         if (pattern)
             txtfind_build_TD1(TD1, pattern, !Case);

         at = txtfind_find(s->t, &endat, pattern, !Case
#ifdef FIELDNUM
, 0 , 0 , FALSE
#endif
, TD1
);
         visdelay_end();

         if (at == -1)
         {
           dbox_setfield(find, txtedit_FiMsg, msgs_lookup(MSGS_txt34));
           txt_setdot(s->t, wasat);
         }
         else
         {
           txt_setdot(s->t, at);
           txtscrap_setselect(s->t, at, endat);
           dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt35));
           dbox_hide(find);
           dbox_show(found);

           loopflag2 = 1;

           while (loopflag2)

           {

             cmd2 = dbox_fillin(found);

             switch (cmd2)

             {

             case txtedit_FoCont:

                 if (undoneEdits)
                 {
                   txtundo_commit(s->t);
                   undoneEdits = 0;
                 }
                 txtundo_separate_major_edits(s->t);
                 majorEdits++;

                 /* we can only rely on dot being right since people may
                    have messed us up with Undo/Redo. So we search
                    again to get our start and end points */

                 dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt33));
                 wasat = txt_dot(s->t);
                 endat = wasat;
                 visdelay_begin();
                 at = txtfind_find(s->t, &endat, pattern, !Case
#ifdef FIELDNUM
, 0 , 0 , FALSE
#endif
, TD1
);
                 visdelay_end();

                 if (at == wasat) {
                   visdelay_begin();
                   at = txtfind_find(s->t, &endat, pattern, !Case
#ifdef FIELDNUM
, 0 , 0 , FALSE
#endif
, TD1
);
                   visdelay_end();
                 };

                 if (at == -1)
                   dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt34));
                 else
                 {
                   txt_setdot(s->t, at);
                   txtscrap_setselect(s->t, at, endat);
                   dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt35));
                 }
                 break;    /* txtedit_FoCont */

             case txtedit_FoRep:

                 if (undoneEdits)
                 {
                   txtundo_commit(s->t);
                   undoneEdits = 0;
                 }
                 txtundo_separate_major_edits(s->t);
                 majorEdits++;

                 /* we can only rely on dot being right since people may
                    have messed us up with Undo/Redo. So we search
                    again to get our start and end points */

                 dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt33));
                 wasat = txt_dot(s->t);
                 endat = wasat;
                 visdelay_begin();

                 at = txtfind_find(s->t, &endat, pattern, !Case
#ifdef FIELDNUM
, (txtedit__use_ambiguous(find))?ambiguous:0
, (txtedit__use_ambiguous(find))?sub_patterns:0
, FALSE
#endif
, TD1
);

                 if (at == wasat)
                 {
#ifdef FIELDNUM
                   /* try the search again(!) to patch up field#'s */
                   if (txtedit__use_ambiguous(find))
                   {
                      endat = wasat;
                      at = txtfind_find(s->t, &endat, pattern, !Case, (txtedit__use_ambiguous(find))?ambiguous:0, (txtedit__use_ambiguous(find))?sub_patterns:0, TRUE, TD1);
                   }
#endif
                   txtfind_replace(s->t, at, &endat, &repls[0], magic
#ifdef FIELDNUM
, ambiguous
#endif
#ifdef ALLOW_OLD_PATTERNS
, txtedit_getnumeric(find, txtedit_FiMagic)
#endif
);
                   txtscrap_setselect(s->t, at, endat);

                   dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt33));
                   at = txtfind_find(s->t, &endat, pattern, !Case
#ifdef FIELDNUM
, (txtedit__use_ambiguous(find))?ambiguous:0
, (txtedit__use_ambiguous(find))?sub_patterns:0
, FALSE
#endif
, TD1
);

                   if (at == -1)
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt34));
                   else
                   {
                     txt_setdot(s->t, at);
                     txtscrap_setselect(s->t, at, endat);
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt35));
                   }
                 }
                 else
                 {
                   if (at == -1)
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt34));
                   else
                   {
                     txt_setdot(s->t, at);
                     txtscrap_setselect(s->t, at, endat);
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt36));
                   }
                 };

                 visdelay_end();
                 txtedit_settexttitle(s);
                 break;    /* txtedit_FoRep */

             case txtedit_FoLastRep:

                 if (undoneEdits)
                 {
                   txtundo_commit(s->t);
                   undoneEdits = 0;
                 }
                 txtundo_separate_major_edits(s->t);
                 majorEdits++;

                 /* we can only rely on dot being right since people may
                    have messed us up with Undo/Redo. So we search
                    again to get our start and end points */

                 dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt33));
                 wasat = txt_dot(s->t);
                 endat = wasat;
                 at = txtfind_find(s->t, &endat, pattern, !Case
#ifdef FIELDNUM
, (txtedit__use_ambiguous(find))?ambiguous:0
, (txtedit__use_ambiguous(find))?sub_patterns:0
, FALSE
#endif
, TD1
);

                 if (at == wasat)
                 {
#ifdef FIELDNUM
                   /* try the search again(!) to patch up field#'s */
                   if (txtedit__use_ambiguous(find))
                   {
                      endat = wasat;
                      at = txtfind_find(s->t, &endat, pattern, !Case, (txtedit__use_ambiguous(find))?ambiguous:0, (txtedit__use_ambiguous(find))?sub_patterns:0, TRUE, TD1);
                   }
#endif
                   txtfind_replace(s->t, at, &endat, &repls[0], magic
#ifdef FIELDNUM
, ambiguous
#endif
#ifdef ALLOW_OLD_PATTERNS
, txtedit_getnumeric(find, txtedit_FiMagic)
#endif
);
                   txtscrap_setselect(s->t, at, endat);
                   loopflag2 = 0;
                   loopflag1 = 0;
                 }
                 else
                 {
                   if (at == -1)
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt34));
                   else
                   {
                     txt_setdot(s->t, at);
                     txtscrap_setselect(s->t, at, endat);
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt37));
                   }
                 }
                 txtedit_settexttitle(s);
                 break;    /* txtedit_FoCont FoRep FoLastRep */

             case txtedit_FoEndRep:

             /* Global replace: very similar to end-of-file-replace, but with
                  display turned off.
                  In practice, found to be more popular: scratch the old one.
             */
             {
                 int count = 0;
                 int x, y;
                 char a[40];
                 txt_index startat;
                 typedef void SignalHandler(int);
                 SignalHandler *oldeschandler;

                 if (undoneEdits)
                 {
                   txtundo_commit(s->t);
                   undoneEdits = 0;
                 }
                 txtundo_separate_major_edits(s->t);
                 majorEdits++;

                 /* we can only rely on dot being right since people may
                    have messed us up with Undo/Redo. So we search
                    again to get our start and end points */

                 dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt33));

                 visdelay_begin();
                 oldeschandler = signal(SIGINT, &eschandler);
                 escflag = FALSE;
                 x = 0; y = 0;
                 wimpt_noerr(os_byte(229, &x, &y));

                 txt_setcharoptions(s->t, txt_DISPLAY, 0);

                 endat = txt_dot(s->t);
                 startat = endat;
#ifdef FIELDNUM
                 wasat = endat;
#endif
                 at = txtfind_find(s->t, &endat, pattern, !Case
#ifdef FIELDNUM
, (txtedit__use_ambiguous(find))?ambiguous:0
, (txtedit__use_ambiguous(find))?sub_patterns:0
, FALSE
#endif
, TD1
);

                 /* IDJ: 1-Jul-91: added check that we're not stuck in one place at == wasat */
                 while (at != -1 && at != endat)
                 {

#ifdef FIELDNUM
                   /* try the search again(!) to patch up field#'s */
                   if (txtedit__use_ambiguous(find))
                   {
                      /*endat = wasat;*/
                      txt_setdot(s->t, at);
                      endat = at;
                      at = txtfind_find(s->t, &endat, pattern, !Case, ambiguous, sub_patterns, TRUE, TD1);
                   }
#endif
                   txt_setdot(s->t, at);
                   txtfind_replace(s->t, at, &endat, &repls[0], magic
#ifdef FIELDNUM
, ambiguous
#endif
#ifdef ALLOW_OLD_PATTERNS
, txtedit_getnumeric(find, txtedit_FiMagic)
#endif
);
                   count++;

#ifdef FIELDNUM
                   wasat = endat;
#endif
                   at = txtfind_find(s->t, &endat, pattern, !Case
#ifdef FIELDNUM
, (txtedit__use_ambiguous(find))?ambiguous:0
, (txtedit__use_ambiguous(find))?sub_patterns:0
, FALSE
#endif
, TD1
);
                   if (escflag) break;
                 }

                 txt_setdot(s->t, startat);
                 txt_setcharoptions(s->t, txt_DISPLAY, txt_DISPLAY);

                 x = 1; y = 0;
                 wimpt_noerr(os_byte(229, &x, &y));
                 visdelay_end();

                 sprintf(a, msgs_lookup(MSGS_txt38), count);
                 dbox_setfield(found, txtedit_FoMsg, a);
                 txtedit_settexttitle(s);
                 break;   /* txtedit_FoEndRep */
             };

             case txtedit_FoUndo:

             /*
              *  Allow user to undo any major edits done in this Find command.
              */
                 if (!undoneEdits)
                     txtundo_init(s->t);

                 /* Undo the first major separator. */

                 if (!majorEdits ||
                           (txtundo_undo(s->t) == txtundo_RANOUT))
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt39));
                 else
                 {
                     { /* 15-Nov-88 */
                       int i = 5;

                       visdelay_begin();
                       while (txtundo_undo(s->t) == txtundo_MINOR) {
                         i--;
                         if (i == 0) txt_setcharoptions(s->t, txt_DISPLAY, 0);
                       };
                       visdelay_end();
                       if (i <= 0) txt_setcharoptions(s->t, txt_DISPLAY, txt_DISPLAY);
                     };

                     majorEdits--;
                     undoneEdits++;
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt40)); /* "Undone" */
                 }
                 txtedit_settexttitle(s);
                 break;  /* txtedit_FoUndo */


             case txtedit_FoRedo:

             /*
              *  Allow user to redo any major edits done in this Find command.
              */

                 if (undoneEdits)
                 {
                     txtedit__redomajor(s, 5); /* 15-Nov-88 */
                     majorEdits++;
                     undoneEdits--;
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt41));
                 }
                 else
                     dbox_setfield(found, txtedit_FoMsg, msgs_lookup(MSGS_txt42));

                 txtedit_settexttitle(s);
                 break;  /* txtedit_FoRedo */


             default : /* Exit from this find command */
                 if (undoneEdits)
                 {
                   txtundo_commit(s->t);
                   undoneEdits = 0;
                 }
                 txtundo_separate_major_edits(s->t);
                 majorEdits++;

                 loopflag2 = 0;
                 loopflag1 = 0;
                 break;

             }
           }  /* end while(loopflag2) */
         }  /* end if */
         break;

     case txtedit_FiMagic:
     case txtedit_FiRegularExpressions:
         { wimp_icon icon;
           wimp_get_icon_info(find_handle, cmd1, &icon);

           /* IDJ 31-Jan-90: Magic is now a click icon */
           /* When magic is on, the extra icons appear - when not, they go away */

           if ((icon.flags & wimp_ISELECTED) != 0) {
             wimpt_noerr(wimp_set_icon_state(find_handle, cmd1, 0, wimp_ISELECTED));
             txtedit__extend_findbox(find_handle, txtedit_small_findbox);
           } else {
             wimpt_noerr(wimp_set_icon_state(find_handle, cmd1, wimp_ISELECTED, wimp_ISELECTED));
#ifdef ALLOW_OLD_PATTERNS
             wimpt_noerr(wimp_set_icon_state(find_handle, (cmd1 == txtedit_FiMagic)?txtedit_FiRegularExpressions:txtedit_FiMagic, 0, wimp_ISELECTED));
#endif
             txtedit__extend_findbox(find_handle, txtedit_large_findbox);
           };

           if ((icon.flags & wimp_ISELECTED) == 0)  /* ie was off, now on */
           {
              if (cmd1 == txtedit_FiMagic)
                 txtedit__swap_icons(find_handle, txtedit_FiAny, txtedit_FiHex, txtedit_FiBackGnd, txtedit_FiFoundString);
              else
                 txtedit__swap_icons(find_handle, txtedit_FiBackGnd, txtedit_FiFoundString, txtedit_FiAny, txtedit_FiHex);
           }
         }
         break;

     case txtedit_FiAny:
         wimp_processkey(txtfind_any_ch);
         break;

     case txtedit_FiNewline:
         wimp_processkey(txtfind_newline_ch);
         break;

     case txtedit_FiAlphanum:
         wimp_processkey(txtfind_alphanum_ch);
         break;

     case txtedit_FiDigit:
         wimp_processkey(txtfind_digit_ch);
         break;

     case txtedit_FiCtrl:
         wimp_processkey(txtfind_ctrl_ch);
         break;

     case txtedit_FiNormal:
         wimp_processkey(txtfind_normal_ch);
         break;

     case txtedit_FiSetBra:
         wimp_processkey(txtfind_setbra_ch);
         break;

     case txtedit_FiSetKet:
         wimp_processkey(txtfind_setket_ch);
         break;

     case txtedit_FiNot:
         wimp_processkey(txtfind_not_ch);
         break;

     case txtedit_Fi0OrMore:
         wimp_processkey(txtfind_0ormore_ch);
         break;

     case txtedit_Fi1OrMore:
         wimp_processkey(txtfind_1ormore_ch);
         break;

     case txtedit_FiMost:
         wimp_processkey(txtfind_most_ch);
         break;

     case txtedit_FiTo:
         wimp_processkey(txtfind_to_ch);
         break;

     case txtedit_FiFound:
         wimp_processkey(txtfind_found_ch);
         break;

     case txtedit_FiField:
         wimp_processkey(txtfind_field_ch);
         break;

     case txtedit_FiHex:
         wimp_processkey(txtfind_hex_ch);
         break;

     default :
         loopflag1 = 0;
         break;

     }

} /* end while(loopflag1) */

/* before we go, make sure both find and found dboxes are hidden */
dbox_hide(find);
dbox_hide(found);

/* ... and free up space used for pattern matching */
/* IDJ 2-2-90 */
  if (pattern != NULL && pattern->nfa != NULL)
  {
      free(pattern->nfa);
      free(pattern);
  }


}


/* -------- Miscellaneous operations. -------- */

static dbox idbox = 0;

static void txtedit_indentselection(void)

{

int by;
BOOL loop = TRUE;
char a[100];
txt t = txtscrap_selectowner();

if (t == NULL) return; /* No selection, no indent then */

if (idbox == 0) {
 idbox = dbox_new("indent");
 if (idbox == 0) return;
}
dbox_raw_eventhandler(idbox, help_dboxrawevents, "INDENT");

dbox_show(idbox);

  while (loop) {
    switch(dbox_fillin(idbox)) {

    case txtedit_IndOK:
        by = dbox_getnumeric(idbox, txtedit_IndBy);
        if (by == 0)
          {
          by = 99;
          dbox_getfield(idbox, txtedit_IndBy, &a[0], by);
          }
        else {
          int i = 0;
          while (i < 99) a[i++] = ' ';
          a[99] = 0;
        };
        txtmisc_indentregion(
          t, txt_selectstart(t), txt_selectend(t), by, a);
        if (dbox_persist()) {
          txtundo_separate_major_edits(t);
        } else {
          loop = FALSE;
        };
        break;

    default:
      loop = FALSE;
      break;

    };
  };

dbox_hide(idbox);
}


void txtedit_swapcase(txt t)
{
  char *a;
  int i, segsize, size;
  txt_index pos;

  t = txtscrap_selectowner();
  if (t == NULL) return; /* No selection, no swap then */

  pos = txt_selectstart(t);
  size = txt_selectend(t) - pos; /* At least 1 */
  txt_setcharoptions(t, txt_DISPLAY, 0);
  while (size) {
    txt_arrayseg(t, pos, &a, &segsize);
    if (segsize > size) segsize = size;
    for (i = 0; i < segsize; i++) a[i] = isupper(a[i]) ? tolower(a[i])
                                                       : toupper(a[i]);
    size = size - segsize;
    pos = pos + segsize;
  }
  /* Mark as updated, make a note in the undo buffer */
  txt_setcharoptions(t, txt_UPDATED + txt_DISPLAY, txt_UPDATED + txt_DISPLAY);
  txtundo_putcode(t->undostate, 't');
}


static void txtedit_goto(txtedit_state *s)
{

dbox d;

d = dbox_new("goto");
if (d == 0) return;
dbox_raw_eventhandler(d, help_dboxrawevents, "GOTO");
dbox_setnumeric(d, txtedit_GoCurrentLine, txtmisc_currentlinenumber(s->t));
dbox_setnumeric(d, txtedit_GoCurrentChar, txt_dot(s->t));
dbox_show(d);

/* 07-Dec-89: The closing of the dbox puts back the caret exactly where it
was, thus in the case where a move occurs we must close the box before
making the move. */
while (1) {
  if (dbox_fillin(d) == txtedit_GoGo)
  {
    if (dbox_persist())
    {
      txtmisc_gotoline(s->t, dbox_getnumeric(d, txtedit_GoLine));
      txtundo_separate_major_edits(s->t);
    }
    else
    {
      int line = dbox_getnumeric(d, txtedit_GoLine);
      dbox_dispose(&d);
      txtmisc_gotoline(s->t, line);
      return;
    }
    txtedit_clearselection(s->t); /* Goto equates to a caret move */
  } else {
    break;
  }
}

dbox_dispose(&d);

}


static void txtedit_editnewfile(txtedit_state *s)
{

char a[256];
txtar_options o;

tracef0("editing new file.\n");

a[0] = 0;

dboxfile(msgs_lookup("txt69"), -1, &a[0], 256);

if (a[0] != 0)
  {
  txtar_getoptions(s->t, &o);
  txtedit_newwithoptions(&a[0], 0, &o);
  }

}

#if BASIC
static BOOL txtedit__validbasicfile(char *filename)
{
  BOOL result = 0;
  int r0, r1;
  char buff[256];

  strcpy(buff, filename);
  if (!os_swi2r(OS_Find+os_X, 0x4F, (int)buff, &r0, &r1)) {             /* open the file */
    if (r0 != 0) {
      r1 = r0;
      if (!os_swi2r(OS_BGet+os_X, r0, r1, &r0, &r1)) {                  /* get the first byte */
        if (r0 == 13) {
          if (!os_swi2r(OS_BGet+os_X, r0, r1, &r0, &r1)) {              /* get the 2 bytes that */
            if (r0 == 255) {
              result = TRUE; /* empty BASIC program */
            } else {
              if (!os_swi2r(OS_BGet+os_X, r0, r1, &r0, &r1)) {          /* make up the line num */
                if (!os_swi2r(OS_BGet+os_X, r0, r1, &r0, &r1)) {        /* and the line length */
                  if (!os_swi3(OS_Args+os_X, 1, r1, r0)) {              /* set the file ptr from it */
                    if (!os_swi2r(OS_BGet+os_X, r0, r1, &r0, &r1)) {    /* get that byte */
                      if (r0 == 13)
                        result = 1;
                    }
                  }
                }
              }
            }
          }
        }
      }
      os_swi2(OS_Find, 0, r1);                       /* close the file */
      if (!result) {
        _kernel_oserror *e = (_kernel_oserror *) buff; /* Reuse buff since it's big enough */
        e->errnum = 0;
        strcpy(e->errmess,msgs_lookup(MSGS_bas1));
        r1 = _swi(Wimp_ReportError, _IN(0)|_IN(1)|_IN(2)|_RETURN(1),
             e, 3, wimpt_programname());
        if (r1 == 2) return 2;
      }
    }
  }
  return(result);
}
#endif

/* >>>> Code copied between here and NewWithOptions, could be tidied up. */

/* PJC: extended so that BASIC files can be detokenised */

void txtedit_doinsertfile(txtedit_state *s, char *filename, BOOL replaceifwasnull) {
  int result;
  BOOL insrep;
  typdat ty;
  int  size, tsize;
  txt_index dot;
  
  /* Insertion replaces selection */
  insrep = txtscrap_selectowner() == s->t;
  if (insrep) txtedit_deleteselection();
  tsize = txt_size(s->t);
  dot = txt_dot(s->t);

  if (filename[0] != 0) {
#if BASIC
    int filety;
    int l;
    if (txtedit__detokenise != -1) {
      /* we know the detokenise address, so we ought to check the filetype */
      os_error *er;
      os_filestr file;

      file.action = 5;
      file.name = filename;
      er = os_file(&file);
      if (er) {
        werr(FALSE, er->errmess);
        return;
      }
      if (file.action != 1) {
        werr(FALSE, msgs_lookup(MSGS_txt51), filename);
        return;
      }
      l = file.start;
      filety = 0xfff & (file.loadaddr >> 8);
      if ((0xfff & (file.loadaddr >> 20)) != 0xfff) filety = -1;
    } else {
      /* we don't have the address, force a normal loading */
      filety = -1;
      l = -1;
    }
    if (filety == 0xffb && (result = txtedit__validbasicfile(filename))) {
     if (result == 2) return;
     result = txtfile_basicinsert(s->t, filename, l, &ty, txtedit__detokenise, txtedit__strip);
    } else {
#endif
     result = txtfile_insert(s->t, filename, -1, &ty);
#if BASIC
    }
#endif
    if (result) {
      /* Now consider
      - the text was empty and has been entirely replaced by the loaded file (tsize == 0, insrep == 0)
      - the text had no selection and has been extended by the loaded file   (tsize != 0, insrep == 0)
      - the text was all selected and has been entirely replaced             (tsize == 0, insrep != 0)
      - the text was partly selected and the selection has been replaced     (tsize != 0, insrep != 0). */
      if (insrep) {
        size = txt_size(s->t) - tsize;
        txt_setdot(s->t, dot);
        txtscrap_setselect(s->t, dot, dot + size);
      } else {
        if (tsize == 0) {
          s->ty = ty;
          txt_setcharoptions(s->t, txt_UPDATED + txt_DISPLAY, txt_DISPLAY);
          txtundo_purge_undo(s->t);
          if (replaceifwasnull) {
            strcpy(s->filename, filename);
            txtedit_settexttitle(s);
          };
        };
      };
    };
  };
}

static void txtedit_insertfile(txtedit_state *s)
{
  char filename[256];
  
  tracef0("inserting file.\n");
  filename[0] = 0;
  dboxfile(msgs_lookup("txt70"), -1, filename, sizeof(filename));
  
  txtedit_doinsertfile(s, filename, TRUE);
}

/* -------- Saving file and selection. -------- */
/* PJC: extended to allow saving of BASIC programs */

static BOOL txtedit__saverprocsafe(char *filename, void *handle, BOOL safe) {
/* 28-Nov-88: Code shared between the xfersend save case, and just clicking on
Save in the root menu. */

#if BASIC
  int ty;
#endif
  BOOL result;

  typdat newty;
  txtedit_state *s = (txtedit_state*) handle;
  tracef0("saverproc.\n");

  if (txtedit__save_handler != 0)
     if (txtedit__save_handler(filename, s, txtedit__save_handle) == FALSE)
         return FALSE;

  if (txt_UPDATED & txt_charoptions(s->t))
    txtfile_buildnewtimestamp(s->ty, &newty);
  else
    newty = s->ty;

#if BASIC
  ty = 0xfff & (s->ty.ld >> 8);
  if ((0xfff & (s->ty.ld >> 20)) != 0xfff) ty = -1;
  if ((ty == 0xffb) && (txtedit__tokenise != -1)) {
   result = txtfile_savebasicrange(s->t, filename, newty, 0, INT_MAX, txtedit__tokenise, txtedit__increment);
  } else {
#endif
   result = txtfile_saverange(s->t, filename, newty, 0, INT_MAX);
#if BASIC
  }
#endif

  if (result) {
    tracef0("saverproc worked.\n");
    if (safe) {
      strcpy(s->filename, filename);
      s->ty = newty;
      txt_setcharoptions(s->t, txt_UPDATED, 0);
      txtedit_settexttitle(s);
    };

    txt_setlastref(s->t, (txt_charoptions(s->t) & txt_UPDATED) ? xfersend_read_last_ref() : -1);
    tracef1("txtedit__saverprocsafe: set txt_lastref to &%x\n", txt_lastref(s->t));
    return TRUE;
  } else {
    werr(FALSE, msgs_lookup(MSGS_txt2), filename);
    return FALSE;
  };
}

static BOOL txtedit__saverproc(char *filename, void *handle) {
  return txtedit__saverprocsafe(filename, handle, xfersend_file_is_safe());
}

static BOOL txtedit__senderproc(void *handle, int *maxbuf) {
  txtedit_state *s = (txtedit_state*) handle;
  txt t = s->t;
  txt_index i = 0;
  txt_index size = txt_size(t);
  char *buffer;
  int segsize;

#if BASIC
  int ty = 0xfff & (s->ty.ld >> 8);
  if ((0xfff & (s->ty.ld >> 20)) != 0xfff) ty = -1;
  if ((ty == 0xffb) && (txtedit__tokenise != -1)) {
    return(txtfile_basicsenderproc(t, maxbuf, 0, txt_size(t), txtedit__tokenise, txtedit__increment));
  } else {
#endif
    tracef0("senderproc.\n");
    while (i < size) {
      /* Note that size must be computed before the loop starts, for the
      case where you are importing into yourself... */
      txt_arrayseg(t, i, &buffer, &segsize);
      if (segsize > *maxbuf) segsize = *maxbuf;
      if (segsize + i > size) segsize = size - i;
      if (! xfersend_sendbuf(buffer, segsize)) return FALSE;
      i += segsize;
    };
    return TRUE;
#if BASIC
  }
#endif
}

/* It's inherently hard to do insertion into yourself. */
static BOOL withinsaveas = FALSE;
static txtedit_state *sas = 0;

static char *txtedit__dftname(int ty) {
  return
    ty == 0xfff ? msgs_lookup(MSGS_txt26) :
   (ty == 0xffd ? msgs_lookup(MSGS_txt27) :
   (ty == 0xffe ? msgs_lookup(MSGS_txt28) :
   (ty == 0xfeb ? msgs_lookup(MSGS_txt29) :
   (ty == 0xfe1 ? msgs_lookup(MSGS_txt29a) :
   (ty == 0xffb ? msgs_lookup(MSGS_txt29b) :
    msgs_lookup(MSGS_txt30))))));
}

static void txtedit_saveas(txtedit_state *s)
{
  int size = txt_size(s->t);
  int ty = 0xfff & (s->ty.ld >> 8);
  if ((0xfff & (s->ty.ld >> 20)) != 0xfff) ty = -1;
  if (size == 0) size = 1;
  withinsaveas = TRUE;
  sas = s;

   saveas(
     ty,
     (s->filename[0] == 0 ? txtedit__dftname(ty) : s->filename),
     size,
     txtedit__saverproc,
     txtedit__senderproc,
     0,
     (void*) s);
  txt_setlastref(s->t,(txt_charoptions(s->t) & txt_UPDATED) ? xfersend_read_last_ref() : 0);
  tracef1("txtedit_saveas: set txt_lastref to &%x\n", txt_lastref(s->t));

  withinsaveas = FALSE;
}

/* PJC: extended to support BASIC */

static BOOL txtedit__saveselproc(char *filename, void *handle) {
#if BASIC
  int ty;
#endif
  BOOL result;

  typdat newty;

  txtedit_state *s = (txtedit_state*) handle;
  tracef0("saveselproc.\n");

  if (txtedit__save_handler != 0)
      if (txtedit__save_handler(filename, s, txtedit__save_handle) == FALSE)
          return FALSE;

  txtfile_buildnewtimestamp(s->ty, &newty);

#if BASIC
  ty = 0xfff & (s->ty.ld >> 8);
  if ((0xfff & (s->ty.ld >> 20)) != 0xfff) ty = -1;
  if ((ty == 0xffb) && (txtedit__tokenise != -1)) {
    result = txtfile_savebasicrange(s->t, filename, newty,
               txt_selectstart(s->t), txt_selectend(s->t), txtedit__tokenise, txtedit__increment);
  } else {
#endif
    result = txtfile_saverange(s->t, filename, newty,
               txt_selectstart(s->t), txt_selectend(s->t));
#if BASIC
  }
#endif
  if (result) {
    tracef0("saveselproc worked.\n");
    return TRUE;
  } else {
    werr(FALSE, msgs_lookup(MSGS_txt2), filename);
    return FALSE;
  };
}

static BOOL txtedit__sendselproc(void *handle, int *maxbuf) {
#if BASIC
  int ty;
#endif
  txtedit_state *s = (txtedit_state*) handle;
  txt t = s->t;
  txt_index i = txt_selectstart(t);
  txt_index selend = txt_selectend(t);
  char *buffer;
  int segsize;
  tracef0("sendselproc.\n");

#if BASIC
  ty = 0xfff & (s->ty.ld >> 8);
  if ((0xfff & (s->ty.ld >> 20)) != 0xfff) ty = -1;
  if ((ty == 0xffb) && (txtedit__tokenise != -1)) {
    return(txtfile_basicsenderproc(t, maxbuf, txt_selectstart(t), txt_selectend(t), txtedit__tokenise, txtedit__increment));
  } else {
#endif
    while (i < selend) {
      /* Note that selend must be computed before the loop starts, for the
      case where you are importing into yourself... */
      txt_arrayseg(t, i, &buffer, &segsize);
      if (segsize + i > selend) segsize = selend - i;
      if (segsize > *maxbuf) segsize = *maxbuf;
      if (! xfersend_sendbuf(buffer, segsize)) return FALSE;
      i += segsize;
    };
    return TRUE;
#if BASIC
  }
#endif
}

/* Clipboard helpers for xfersend */

static BOOL txtedit__saveclipproc(char *filename, void *handle) {
  os_error  *err;
  os_filestr file;
  char      *clip = (char *)clipboard_anchor;
  int        size = flex_size(&clipboard_anchor);

  tracef0("saveclipproc.\n");

  file.action   = 0; /* Save */
  file.name     = filename;
  file.loadaddr = (int)0xffffff00; /* Text file on 01 Jan 1900 */
  file.execaddr = 0;
  file.start    = (int)&clip[0];
  file.end      = (int)&clip[size];
  err = os_file(&file);
  if (err != NULL)
  {
    werr(FALSE, err->errmess);
    return FALSE;
  }
  tracef0("saveclipproc worked.\n");
  return TRUE;
}

static BOOL txtedit__sendclipproc(void *handle, int *maxbuf) {
  char *clip = (char *)clipboard_anchor;
  int   size = flex_size(&clipboard_anchor);
  int   avail, sent = 0;

  tracef0("sendclipproc.\n");

  while (sent < size)
  {
    avail = size - sent;
    if (avail > *maxbuf)
      avail = *maxbuf; /* MIN(recipient space, unsent clipboard) */
    if (!xfersend_sendbuf(&clip[sent], avail)) return FALSE;
    sent += avail;
  }
  return TRUE;
}

/* It's hard to do pipeing to/from the same object: it really
just doesn't work! So, we have to spot this and use the
txtmisc facilities. */
static BOOL withinsaveselect = FALSE;
static txtedit_state *sss;

static void txtedit_saveselect(txtedit_state *s)
{
  int ty = 0xfff & (s->ty.ld >> 8);
  if ((0xfff & (s->ty.ld >> 20)) != 0xfff) ty = -1;

  withinsaveselect = TRUE;
  sss = s;
  saveas(
    ty,
    msgs_lookup(MSGS_txt73),
    txt_selectend(s->t) - txt_selectstart(s->t),
    txtedit__saveselproc,
    txtedit__sendselproc,
    0,
    (void*) s);
  withinsaveselect = FALSE;
}

static txtedit_state *txtedit__import_s;
static int txtedit__import_size;
#define IMPORT_BUFSIZE 4000
/* If the incoming stuff is bigger than the estimate then extend
by this amount. */
/* Bug in this stuff at the moment: if we run out of space on a
subsequent buffer, the initial buffers will still be in there. */

static BOOL txtedit__import_buffer_processor(char **buffer, int *size) {
  txt t = txtedit__import_s->t;
  int tsize = txt_size(t);
  int dudsize;
  txt_movedot(t, *size); /* skip over existing buffer */
  *size = IMPORT_BUFSIZE;
  txtedit__import_size = IMPORT_BUFSIZE;
  txt_replacechars(t, 0, NULL, IMPORT_BUFSIZE); /* insert rubbish */
  if (txt_size(t) != tsize + IMPORT_BUFSIZE) { /* out of space */
    werr(FALSE, msgs_lookup(MSGS_txt3));
    return FALSE;
  };
  txt_arrayseg(t, txt_dot(t), buffer, &dudsize); /* get pointer to them */
  return TRUE;
}

/* new version */
BOOL txtedit_doimport(txtedit_state *s, int filetype, int estsize) {
  txt t = s->t;
  char *buffer;
  int size, tsize;
  txt_index dot;
  int last;
  BOOL insrep, undo;
  txt_charoption wasupdated = txt_charoptions(t) & txt_UPDATED;
  txtedit__import_s = s;

  /* IDJ: 06-Aug-91: bug-fix for estimated size of <= zero */
  if (estsize <= 0) estsize = IMPORT_BUFSIZE;

  filetype=filetype;
  if (withinsaveselect && s == sss) {
    /* Doing a Selection->Save into yourself is a no-op since the
    imported text replaces the selection, and becomes the new selection; just
    close the menu. */
    wimp_create_menu((wimp_menustr *)-1, 0, 0);
    return TRUE;
  };
  if (withinsaveas && s == sas) {
    werr(FALSE, msgs_lookup(MSGS_txt1)); /* No saving into yourself */
    return FALSE;
  };
  txt_setcharoptions(t, txt_DISPLAY, 0);

  /* Insertion replaces selection */
  insrep = txtscrap_selectowner() == s->t;
  if (insrep) txtedit_deleteselection();
#if BASIC
  if ((filetype == 0xffb) && (txtedit__detokenise != -1)) {
    return txtfile_basicimport(s, insrep, txtedit__detokenise, txtedit__strip);
  } else {
#endif
    undo = txtundo_suspend_undo(t, TRUE);
    tsize = txt_size(t);
    dot = txt_dot(t); /* in case of error result, to delete all */

    txt_replacechars(t, 0, NULL, estsize); /* create blanks */
    if (txt_size(t) != tsize + estsize) { /* out of space */
      txt_delete(t, txt_size(t) - tsize); /* delete blanks */
      werr(FALSE, msgs_lookup(MSGS_txt3));
      txt_setcharoptions(t, txt_DISPLAY + txt_UPDATED, txt_DISPLAY + wasupdated);
      txtedit_settexttitle(s);
      txtundo_suspend_undo(t, undo);
      return FALSE;
    };
    txt_arrayseg(t, txt_dot(t), &buffer, &size); /* get pointer to them */
    txtedit__import_size = estsize;
    last = xferrecv_doimport(buffer, estsize, txtedit__import_buffer_processor);
    if (last == -1) {
      /* delete all insertions */
      tracef0("Not enough room for imported data.\n");
      txt_setdot(t, dot);
      txt_delete(t, txt_size(t) - tsize); /* delete everything new */
      txt_setcharoptions(s->t, txt_DISPLAY + txt_UPDATED, txt_DISPLAY + wasupdated);
      txtedit_settexttitle(s);
      txtundo_suspend_undo(t, undo);
      return FALSE;
    } else {
      /* last indicates the number of bytes actually transferred into
      the final buffer. Delete any remaining blanks. */
      txt_movedot(t, last);
      txt_delete(t, txtedit__import_size - last);
      size = txt_size(t) - tsize;
      txt_setdot(t, dot);
      txtundo_suspend_undo(t, undo);
      txtundo_putnumber(t->undostate, size);
      txtundo_putcode(t->undostate, 'd');
      if (size == 0) {
        /* At the end of the day, nothing has been inserted. Check
        that modified flag does not change. */
        txt_setcharoptions(t, txt_DISPLAY + txt_UPDATED, txt_DISPLAY + wasupdated);
      } else {
        /* When insertion replaced a selection, must select the new
        insertion in its place. */
        if (insrep) {
          txtscrap_setselect(t, dot, dot + size);
        } else {
          txt_movedot(t, size);
          txt_show(s->t); /* Force a redraw so caret x/y is recalculated */
        }
        txt_setcharoptions(t, txt_DISPLAY, txt_DISPLAY);
      };
      txtedit_settexttitle(s);
      txtundo_separate_major_edits(s->t);
      return TRUE;
    };
#if BASIC
  }
#endif
}

/* -------- Information display. -------- */

/* info about file, template offsets. */

/* Standard tool for editors? */
/* could toggle update flag, change type/name */

static void txtedit_infoaboutfile(txtedit_state *s)
{

dbox d;
char a[30];
BOOL stamped = ((unsigned int) s->ty.ld >> 20) >= 0xfff;

    d = dbox_new("fileInfo");
    if (d == 0) return;
    dbox_raw_eventhandler(d, help_dboxrawevents, "FILEINFO");

    dbox_setfield(d, txtedit_IFName, (s->filename[0] == 0 ? msgs_lookup(MSGS_txt65) : s->filename));

    dbox_setfield(d, txtedit_IFModified,
      ((txt_UPDATED & txt_charoptions(s->t)) != 0) ? msgs_lookup(MSGS_txt66) : msgs_lookup(MSGS_txt67));

    if (stamped) {
      os_swi4r(OS_FSControl, 18, /* decode file type into text */
        0, 0xfff & (s->ty.ld >> 8), 0,
        0, 0, (int*) &a[0], (int*) &a[4]); /* little-endian-specific */
      a[8] = '(';
      sprintf(&a[9], "%03x", 0xfff & (s->ty.ld >> 8));
      a[12] = ')';
      a[13] = 0;
      dbox_setfield(d, txtedit_IFType, a);
    } else {
      dbox_setfield(d, txtedit_IFType, msgs_lookup(MSGS_txt68));
    };

    dbox_setnumeric(d, txtedit_IFSize, txt_size(s->t));

    if (stamped) {
      os_swi3(OS_ConvertStandardDateAndTime, (int) &s->ty.ex, (int) &a[0], 30);
    } else {
      sprintf(a, "%08x %08x", s->ty.ld, s->ty.ex);
    };
    dbox_setfield(d, txtedit_IFLastUpdate, a);

    fileicon((wimp_w) dbox_syshandle(d),
      txtedit_IFIcon, 0xfff & (s->ty.ld >> 8));

    dbox_show(d);

    dbox_fillin(d);

    dbox_dispose(&d);
}

void txtedit__undomajor(txtedit_state *s) {
  int i = 20;

  visdelay_begin();
  txtundo_undo(s->t);
  while (txtundo_undo(s->t) == txtundo_MINOR) {
    i--;
    if (i == 0) txt_setcharoptions(s->t, txt_DISPLAY, 0);
  };
  visdelay_end();
  if (i <= 0) txt_setcharoptions(s->t, txt_DISPLAY, txt_DISPLAY);
}

void txtedit__redomajor(txtedit_state *s, int harmless) {
  int i = harmless;

  visdelay_begin();
  while (txtundo_redo(s->t) == txtundo_MINOR) {
    i--;
    if (i == 0) txt_setcharoptions(s->t, txt_DISPLAY, 0);
  };
  visdelay_end();
  if (i <= 0) txt_setcharoptions(s->t, txt_DISPLAY, txt_DISPLAY);
}

static void txtedit_clearselection(txt t) {
  /* Clear any selection, reveal the caret. */

  txtscrap_setselect(NULL, 0, 0);
  txt_setcharoptions(t, txt_CARET, txt_CARET); 
}

static void txtedit_copyselection(txtedit_state *s) {
  txt    owner;

  owner = txtscrap_selectowner();
  if ((owner != NULL) && txt_selectset(s->t)) {
    char  *a;
    size_t n, size;
    int    segsize;
    BOOL   success, claim;

    size = txt_selectend(owner) - txt_selectstart(owner);
    claim = (clipboard_anchor == NULL);

    if (claim)
      success = flex_alloc((flex_ptr)&clipboard_anchor, size);
    else
      success = flex_extend((flex_ptr)&clipboard_anchor, size);

    if (success) {
      /* Copy the selection into the temporary store */
      n = 0;
      while (n != size) {
        txt_arrayseg(owner, txt_selectstart(owner) + n, &a, &segsize);
        segsize = (segsize < size - n) ? segsize : size - n;
        memcpy((char *)clipboard_anchor + n, a, segsize);
        n += segsize;
      }

      if (claim) {
        wimp_msgstr m;

        /* Stake my claim of the clipboard */
        m.hdr.size = sizeof(wimp_msghdr) + sizeof(wimp_msgclaimentity);
        m.hdr.your_ref = 0;
        m.hdr.action = wimp_MCLAIMENTITY;
        m.data.claimentity.flags = wimp_MCLAIMENTITY_flags_clipboard;
        wimpt_noerr(wimp_sendmessage(wimp_ESEND, &m, 0));
      }
    } else {
      werr(FALSE, msgs_lookup(MSGS_txt48)); /* Not enough memory */
    }
  }
}


static void txtedit_pasteselection(txtedit_state *s) {
   wimp_msgstr m;
   int *types = m.data.datarequest.types;
   
   /* Ask for the clipboard data */
   m.hdr.size = sizeof(wimp_msghdr) + sizeof(wimp_msgdatarequest) + sizeof(int);
   m.hdr.your_ref = 0;
   m.hdr.action = wimp_MDATAREQUEST;
   m.data.datarequest.w = txt_syshandle(s->t); /* As though dropped into that window */
   m.data.datarequest.h = s; /* Handle back to state, might be useful */
   m.data.datarequest.x =
   m.data.datarequest.y = 0;   
   m.data.datarequest.flags = wimp_MDATAREQUEST_flags_clipboard;
   types[0] = 0xfff; /* Our one preferred type */
   types[1] = wimp_MDATAREQUEST_types_end;
   wimpt_noerr(wimp_sendmessage(wimp_ESENDWANTACK, &m, 0));
   clipboard_ref = m.hdr.my_ref; /* Picked by Wimp */
}

/* Distinguish whether this is a test paste or a real one */
static BOOL  withinmsel = FALSE;
static int   mselx, msely;

static BOOL txtedit_pasteok(txt t, wimp_msgstr *m) {
  BOOL faded, istext = m->data.datasave.type == 0xfff;

  if (m->hdr.your_ref != clipboard_ref) return TRUE; /* Pass all non replies */
  if (withinmsel) {
    /* This was a trial paste to see if anything was there, generate and
    show the 'Selection' menu instead, then abort the paste silently */
    faded = (txt_charoptions(t) & txt_READONLY) || !istext;
    menu_setflags(m3, txtedit_MSelPaste, FALSE, faded);
    wimp_create_submenu(menu_syshandle(m3), mselx, msely);
    withinmsel = FALSE;
    return FALSE;
  }
  return istext;
}


static void txtedit_deleteselection(void) {
  txtedit_state *from = txtedit__findtxt(txtscrap_selectowner());
  txt_marker m;
  txt owner;

  owner = txtscrap_selectowner();
  if (owner != NULL && txt_selectset(owner))
  {
    txt_newmarker(owner, &m);
    txt_setdot(owner, txt_selectstart(owner));
    txt_delete(owner, txt_selectend(owner) - txt_selectstart(owner));
    txtmisc_normalisepara(owner, 0);
    txt_movedottomarker(owner, &m);
    txt_disposemarker(owner, &m);
    txtedit_clearselection(owner);
  }
  if (from != NULL)
  {
    txtedit_settexttitle(from);
  }
}


static void txtedit_infoaboutprogram(void)
{

dbox d;

    d = dbox_new("progInfo");
    if (d == 0) return;
    dbox_raw_eventhandler(d, help_dboxrawevents, "PROGINFO");

    /* Place the version string in the dialogue box */
    dbox_setfield(d, 4, msgs_lookup("_Version"));

    dbox_show(d);
    dbox_fillin(d);
    dbox_dispose(&d);
}


#if PRINT
static void txtedit__reply_to_printer(wimp_eventstr *e, txtedit_state *s)
{
   wimp_msgstr reply;
   int ty = 0xfff & (s->ty.ld >> 8);
   if ((0xfff & (s->ty.ld >> 20)) != 0xfff) ty = -1;

#if BASIC
   if (ty == 0xffb) ty = 0xfff;
#endif

   /* --- reply with Message_DataLoad --- */
   reply.hdr.size = 256;
   reply.hdr.your_ref = e->data.msg.hdr.my_ref;
   reply.hdr.action = wimp_MDATALOAD;
   reply.data.dataload.size = 0;
   reply.data.dataload.type = ty;
   reply.data.dataload.w = e->data.msg.data.datasaveok.w;
   reply.data.dataload.i = e->data.msg.data.datasaveok.i;
   strcpy(reply.data.dataload.name, e->data.msg.data.datasaveok.name);
   wimpt_noerr(wimp_sendmessage(wimp_ESEND, &reply, e->data.msg.hdr.task));
}


static BOOL txtedit__print_wholefile_unknowns(wimp_eventstr *e, void *handle)
{
   txtedit_state *s = (txtedit_state *)handle;

   switch(e->e)
   {
      case wimp_ESEND:
      case wimp_ESENDWANTACK:
         switch(e->data.msg.hdr.action)
         {
            case wimp_MPrintError:
               werr(FALSE, &e->data.msg.data.chars[4]); /* JSR 18-1-94 was 24 */
               win_remove_unknown_event_processor(txtedit__print_wholefile_unknowns, handle);
               return TRUE;

            case wimp_MDATASAVEOK:
               {
                  /* --- save to (s)crap file --- */
                  if (txtfile_saverange(s->t, e->data.msg.data.datasaveok.name, s->ty, 0, INT_MAX))
                  {
                     txtedit__reply_to_printer(e, s);
                  }
                  else  /* error so remove processor */
                     win_remove_unknown_event_processor(txtedit__print_wholefile_unknowns, handle);
               }
               return TRUE;

            case wimp_MDATALOADOK:
               win_remove_unknown_event_processor(txtedit__print_wholefile_unknowns, handle);
               return TRUE;

            default:
               return FALSE;
         }
         break;

      case wimp_EACK:
         werr(FALSE, msgs_lookup(MSGS_txt64));
         win_remove_unknown_event_processor(txtedit__print_wholefile_unknowns, handle);
         return TRUE;

      default:
         return FALSE;
   }

   return FALSE;
}


static BOOL txtedit__print_selection_unknowns(wimp_eventstr *e, void *handle)
{
   txtedit_state *s = (txtedit_state *)handle;

   switch(e->e)
   {
      case wimp_ESEND:
      case wimp_ESENDWANTACK:
         switch(e->data.msg.hdr.action)
         {
            case wimp_MPrintError:
               werr(FALSE, &e->data.msg.data.chars[4]); /* JSR 18-1-94 was 24 */
               win_remove_unknown_event_processor(txtedit__print_selection_unknowns, handle);
               return TRUE;

            case wimp_MDATASAVEOK:
               {
                  /* --- save to (s)crap file --- */
                  if (txtfile_saverange(s->t, e->data.msg.data.datasaveok.name, s->ty, txt_selectstart(s->t), txt_selectend(s->t)))
                  {
                     txtedit__reply_to_printer(e, s);
                  }
                  else  /* error so remove processor */
                     win_remove_unknown_event_processor(txtedit__print_selection_unknowns, handle);
               }
               return TRUE;

            case wimp_MDATALOADOK:
               win_remove_unknown_event_processor(txtedit__print_selection_unknowns, handle);
               return TRUE;

            default:
               return FALSE;
         }
         break;

      case wimp_EACK:
         werr(FALSE, msgs_lookup(MSGS_txt64));
         win_remove_unknown_event_processor(txtedit__print_selection_unknowns, handle);
         return TRUE;

      default:
         return FALSE;
   }

   return FALSE;
}


static void txtedit__printstart(txtedit_state *s, int size, win_unknown_event_processor p)
{
   wimp_msgstr msg;
   int ty = 0xfff & (s->ty.ld >> 8);
   if ((0xfff & (s->ty.ld >> 20)) != 0xfff) ty = -1;

   if (size <= 0) return;
   msg.hdr.size = 256;
   msg.hdr.your_ref = 0;
   msg.hdr.action = wimp_MPrintSave;
   msg.data.datasave.estsize = size;   /* maybe whole file or selection */
   msg.data.datasave.type = ty;
   strcpy(msg.data.datasave.leaf, (s->filename[0])?s->filename:msgs_lookup(MSGS_txt65));
   wimpt_noerr(wimp_sendmessage(wimp_ESENDWANTACK, &msg, 0));

   win_add_unknown_event_processor(p, s);
}

#endif  /* PRINT */

static void txtedit_menueventproc(void *v, char *cmd)
{

txtedit_state *s = (txtedit_state *)v;
BOOL wasupdated = txt_UPDATED & txt_charoptions(s->t);
wimp_eventstr *e = wimpt_last_event();

  if (
       (e->e == wimp_ESEND || e->e == wimp_ESENDWANTACK)
       &&
       e->data.msg.hdr.action == wimp_MHELPREQUEST
     )
  {
    /* 14-Dec-89: If the last event was an interactive help one,
    provide help instead of doing the hit. This is a bit of a cheat,
    but means that txtedit_menuevent can be used by c.message to give
    menu interactive help on the task window menu. */
    txtedit__help_handler(v, cmd);
    return;
  }

if (cmd[0] == txtedit_MEdit
&& (cmd[1] == txtedit_MUndo || cmd[1] == txtedit_MRedo)) {
  /* no separation */
} else {
  txtundo_separate_major_edits(s->t);
};

switch (cmd[0])

{

case txtedit_MMisc :

     switch (cmd[1])
     {
     case txtedit_MAboutProgram : if (cmd[2] != 0) txtedit_infoaboutprogram();    break;
     case txtedit_MAboutFile    : if (cmd[2] != 0) txtedit_infoaboutfile(s);       break;
     case txtedit_MNewType      : if (cmd[2] != 0)
                                  { os_regset r;
                                    r.r[0] = 31;
                                    r.r[1] = (int)filetypebuff;
                                    if (wimpt_complain(os_swix(OS_FSControl, &r)) == 0) {
                                      if ((0xfff & (s->ty.ld >> 20)) != 0xfff) {
                                        /* no filetype present - build a time stamp before typing */
                                        s->ty.ex = -1;
                                        s->ty.ld = -1;
                                        txtfile_buildnewtimestamp(s->ty, &s->ty);
                                      }
                                      s->ty.ld &= 0xfff000ff;
                                      s->ty.ld |= (r.r[2] << 8);
                                    }
                                  }
                                  break;
     case txtedit_MSplit        : txtedit_splitwindow(s);
                                  break;
#if PRINT
     case txtedit_MPrint        : /* send print start message */
                                  txtedit__printstart(s, txt_size(s->t), txtedit__print_wholefile_unknowns);
                                  break;
#endif
     case txtedit_MOverwrite    : s->overwrite = ! s->overwrite;
#ifdef SET_MISC_OPTIONS
                                  {
                                  txtar_options opts;
                                  txtar_getoptions(s->t, &opts);
                                  opts.overwrite = s->overwrite;
                                  txtar_setoptions(s->t, &opts);
                                  }
#endif
                                  txtedit_settexttitle(s);
                                  break;
#if TAB1
     case txtedit_MColTab       : s->wordtab = ! s->wordtab;
#ifdef SET_MISC_OPTIONS
                                  {
                                  txtar_options opts;
                                  txtar_getoptions(s->t, &opts);
                                  opts.wordtab = s->wordtab;
                                  txtar_setoptions(s->t, &opts);
                                  }
#endif
                                  txtedit_settexttitle(s);
                                  break;
#endif
#if WORDWRAP
     case txtedit_MWordwrap: s->wordwrap = ! s->wordwrap;
#ifdef SET_MISC_OPTIONS
                                  {
                                  txtar_options opts;
                                  txtar_getoptions(s->t, &opts);
                                  opts.wordwrap = s->wordwrap;
                                  txtar_setoptions(s->t, &opts);
                                  }
#endif
                             txtedit_settexttitle(s);
                             break;
#endif
#if TRACE
     case txtedit_MTrace        : trace_on();             break;
     case txtedit_MNoTrace      : trace_off();            break;
#endif
     default : break;
     }
     break;

case txtedit_MFile :

     if (cmd[1] == 0) {
       /* he clicked on "save", so save straight away. */
       if (s->filename[0] != 0) {
         /* Simple test, do nothing if no name there. */
         txtedit__saverprocsafe(s->filename, s, TRUE);
         break;
       }
     }
     /* submenu or click on save */
     txtedit_saveas(s);
     break;

case txtedit_MSel :
     switch (cmd[1])
     {
     case txtedit_MSelSave      : if (cmd[2] != 0) {
                                    txtedit_saveselect(s);
                                  } else {
                                    /* This is the top level 'Select' submenu warning. Kick off
                                    an exchange to decide whether the clipboard has text or not. */
                                    withinmsel = TRUE;
                                    mselx = e->data.msg.data.menuwarn.x;
                                    msely = e->data.msg.data.menuwarn.y;
                                    txtedit_pasteselection(s);
                                  }
                                  break;
#if PRINT
     case txtedit_MSelPrint     : txtedit__printstart(s, txt_selectend(s->t) - txt_selectstart(s->t),
                                                      txtedit__print_selection_unknowns);
                                  break;
#endif
     case txtedit_MSelCopy      : txtedit_copyselection(s);   break;
     case txtedit_MSelPaste     : txtedit_pasteselection(s);  break;
     case txtedit_MSelCut       : txtedit_copyselection(s);   /* Fall through */
     case txtedit_MSelDelete    : txtedit_deleteselection();  break;
     case txtedit_MSelSelAll    : txtscrap_setselect(s->t, 0, INT_MAX);        break;
     case txtedit_MSelClear     : txtedit_clearselection(s->t);                break;
     case txtedit_MSelSwapCase  : txtedit_swapcase(s->t);     break;
     case txtedit_MSelIndent    : if (cmd[2] != 0) txtedit_indentselection();  break;
     default : break;
     }
     break;

case txtedit_MEdit :

     switch (cmd[1])
     {
     case txtedit_MGoto         : if (cmd[2] != 0) txtedit_goto(s);            break;
     case txtedit_MFind         : if (cmd[2] != 0) txtedit_find(s);            break;
     case txtedit_MUndo         : txtedit__undomajor(s);      break;
     case txtedit_MRedo         : txtedit__redomajor(s, 20);  break;
     case txtedit_MExchangeCRLF :
                                  visdelay_begin();
                                  txtmisc_exchangecrlf(s->t);
                                  visdelay_end();
                                  break;
     case txtedit_MExpandTabs   :
                                  visdelay_begin();
                                  txtmisc_expandtabs(s->t);
                                  visdelay_end();
                                  break;
     case txtedit_MFormatText:
       txtedit_donormalisepara(s);
       break;
     default : break;
     }
     break;

case txtedit_MDisplay :

     txtoptmenu_eventproc(s->t, &cmd[1]);
     break;

default :

     break;

}

if (cmd[0] == txtedit_MEdit
&& (cmd[1] == txtedit_MUndo || cmd[1] == txtedit_MRedo)) {
  /* no separation */
} else {
  txtundo_separate_major_edits(s->t);
};

   {
   if (wasupdated != (txt_UPDATED & txt_charoptions(s->t)))
     /* change the title so that the update is displayed */
     txtedit_settexttitle(s);
   }

}


void txtedit_menuevent(txtedit_state *s, char *a) {
  txtedit_menueventproc((void*) s, a);
}


void txtedit_splitwindow(void *v)
{

txtedit_state *s;

s = (txtedit_state*)v;

txtwin_new(s->t);
event_attachmenumaker(
  txt_syshandle(s->t), txtedit_menumaker, txtedit_menueventproc, s);
txtedit_settexttitle(s);

}


static void txtedit_obeyeventcode(txt t, txtedit_state *s, txt_eventcode e)

{

unsigned count;
BOOL loop_flag, wasupdated;
txt_eventcode next_e;
#if TRACE
char c;
#endif

wasupdated = txt_UPDATED & txt_charoptions(t);

if (((e >> 31) & 1) != 0)

  {
  txtedit_mouse(s, e, e & 0xFFFFFF);
  txtundo_separate_major_edits(t);
  }

else

  {

     loop_flag = TRUE;
     next_e = e;
     while (loop_flag)
     {
       /* The loop is for when you look ahead in the key buffer,
          and have to do something different with what you find. */
       loop_flag = FALSE;
       e = next_e; /* So the state before noticeseveral() is available */
       if (e == 13) e = 10; /* RETURN = line feed. */

       switch (e) {
         default:
           /* undo/redo ops are joined together into a single major edit,
           for undoing purposes. */
           txtundo_separate_major_edits(t);
         case akbd_Fn + 8:
         case akbd_Fn + 9:
           break;
       };

       switch (e) {
#if TRACE
         case 23: /* ctl-W -- insert char forwards */
                  txt_insertchar(t, 'W');
                  break;
         case 2:  /* ctl-B -- poll keyboard. */
                  if (akbd_pollsh()) return;
                  if (akbd_pollctl()) return;
                  if (akbd_pollkey((int *)&count)) return;
                  break;
         case 17: /* ctl-Q -- Text internal print-out-innards. */
                  txt_insertchar(t, 17);
                  break;
         case akbd_Fn + akbd_Sh + akbd_Ctl + 7:
                  txt_replaceatend(s->t, 0, "hello there\nhow are you", 22);
                  break;

         case akbd_Fn + akbd_Sh + akbd_Ctl + 6: /* trial force of system error */
                  { int *a = (int*) -1;
                    *a = 1;
                  };
                  break;
#endif

         /* function keys */

#if OVERWRITE
         case akbd_Fn + akbd_Sh + 1:
           s->overwrite = ! s->overwrite;
           {
              txtar_options opts;
              txtar_getoptions(s->t, &opts);
              opts.overwrite = s->overwrite;
              txtar_setoptions(s->t, &opts);
           }
           /* IDJ: 1-Jul-91: close down menu tree */
           event_clear_current_menu();
           txtedit_settexttitle(s);
           break;
#endif

         case txt_EXTRACODE + akbd_Fn + 1:
           {
             wimp_eventstr *ee = wimpt_last_event();
             tracef0("help request.\n");
             if (ee->data.msg.data.helprequest.m.i == -1) {
               ee->data.msg.hdr.your_ref = ee->data.msg.hdr.my_ref;
               ee->data.msg.hdr.action = wimp_MHELPREPLY;
               ee->data.msg.hdr.size = 256; /* be generous! */
               sprintf(ee->data.msg.data.helpreply.text,
                 "%s|M%s|M%s",
                 msgs_lookup(MSGS_txt19),
                 msgs_lookup(MSGS_txt20),
                 ((s->t == txtscrap_selectowner()) ?
                   msgs_lookup(MSGS_txt21):
                   msgs_lookup(MSGS_txt22)));
               wimpt_noerr(
                wimp_sendmessage(wimp_ESEND, &ee->data.msg, ee->data.msg.hdr.task));
            };
           };
           return; /* very harmless event, do not set selectrecent etc. */
         case akbd_Fn + akbd_Sh + akbd_Ctl + 1:
                  txtmisc_expandtabs(s->t);
                  break;
         case akbd_Fn + 2:
                  txtedit_editnewfile(s);
                  break;
         case akbd_Fn + akbd_Sh + 2:
                  txtedit_insertfile(s);
                  break;
         case txt_EXTRACODE + akbd_Fn + akbd_Sh + 2: /* insert/drag file. */
                  {
                    wimp_eventstr *ee = wimpt_last_event();
                    char *filename;
                    int filetype;

                    /* Filter out replies to MDATAREQUEST that we don't fancy */
                    if (ee->data.msg.hdr.action == wimp_MDATASAVE) {
                      if (!txtedit_pasteok(t, &ee->data.msg)) break;
                    }

                    filetype = xferrecv_checkinsert(&filename);
                    if (filetype != -1) {
                      if (akbd_pollsh()) {
                        /* Shift held down, insert the filename instead */
                        txt_insertstring(s->t, filename);
                        txt_movedot(s->t, strlen(filename));
                        txt_insertstring(s->t, "\n"); /* add a \n too */
                        txt_movedot(s->t, 1);
                      } else {
                        int size = txt_size(s->t);

                        /* No shift, xferrecv the file contents */
                        txtedit_doinsertfile(s, filename, xferrecv_file_is_safe());
                        xferrecv_insertfileok();
                        txt_movedot(s->t, txt_size(t) - size); /* move past insertion */
                      };
                    } else {
                      int estsize;
                      
                      filetype = xferrecv_checkimport(&estsize);
                      if (filetype != -1) {
                        txtedit_doimport(s, filetype, estsize);
                      } else {
                        /* Neither insert nor import, ignore it */
                      };
                    };
                  };
                  break;
         case akbd_Fn + 3:
                  txtedit_saveas(s);
                  break;
#if TAB1
         case akbd_Sh + akbd_Fn + 3:
                  s->wordtab = ! s->wordtab;
                  {
                     txtar_options opts;
                     txtar_getoptions(s->t, &opts);
                     opts.wordtab = s->wordtab;
                     txtar_setoptions(s->t, &opts);
                  }
                  /* IDJ: 1-Jul-91: close down menu tree */
                  event_clear_current_menu();
                  txtedit_settexttitle(s);
                  break;
#endif
         case akbd_Fn + 4:
                  txtedit_find(s);
                  break;

         case 19: /* control-S */
                  txtedit_swapcase(s->t);
                  break;
                  
         case akbd_Fn + akbd_Ctl + 4:
                  txtedit_indentselection();
                  break;

         case akbd_Fn + 5:
                  txtedit_goto(s);
                  break;

#if WORDWRAP
         case akbd_Fn + akbd_Ctl + 5:
                  s->wordwrap = ! s->wordwrap;
                  {
                     txtar_options opts;
                     txtar_getoptions(s->t, &opts);
                     opts.wordwrap = s->wordwrap;
                     txtar_setoptions(s->t, &opts);
                  }
                  /* IDJ: 1-Jul-91: close down menu tree */
                  event_clear_current_menu();
                  txtedit_settexttitle(s);
                  break;
#endif

         case 27: /* escape */
         case akbd_Fn + akbd_Sh + 6: /* clear select */
                  txtedit_clearselection(s->t);
                  break;

         case akbd_Fn + akbd_Ctl + 6:
                  txtedit_donormalisepara(s);
                  break;

         case akbd_Fn + 8:
                  txtedit__undomajor(s);
                  break;
         case akbd_Fn + akbd_Ctl + 8:
                  txtmisc_exchangecrlf(s->t);
                  break;
         case akbd_Fn + 9:
                  txtedit__redomajor(s, 20);
                  break;

         /* close key */

         case txt_EXTRACODE + akbd_Fn + 127:
         case akbd_Fn + akbd_Ctl + 2:
                  {
                    BOOL updated = (txt_UPDATED & txt_charoptions(s->t)) != 0;
                    BOOL manywindows = txtwin_number(s->t) > 1;



                    /* if right button down then open parent viewer */
                    {
                      wimp_mousestr m;
                      wimp_get_point_info(&m);
                      if ((m.bbits & wimp_BRIGHT) != 0) {
                        /* can trample on filename now. */
                        /* need to strip off the leafname. */
                        int i = strlen(s->filename) - 1;
                        while (i > 0 && s->filename[i] != '.') i--;
                        if (i > 0) {
                          char a[256];
                          s->filename[i] = 0;
                          sprintf(a, "filer_opendir %s", s->filename);
                          wimpt_complain(os_cli(a));
                          s->filename[i] = '.';
                        };
                        if (akbd_pollsh() | (updated & !manywindows)) {
                          /* don't close if shift down, or might need dboxes */
                          break;
                        };
                      };
                    };

                    if (manywindows)
                      {
                      txtwin_dispose(s->t);
                      txtedit_settexttitle(s);
                      }
                    else
                      {

                      if (txtedit__close_handler != 0)
                       txtedit__close_handler(s->filename, s, txtedit__close_handle);
                      if (updated)
                        {
                        char a[300];
                        if (s->filename[0] != 0) {
                          sprintf(a, msgs_lookup(MSGS_txt8), s->filename);
                        } else {
                          sprintf(a, msgs_lookup(MSGS_txt9));
                        };
                        switch (dboxquery_close(a))
                          {
                          case dboxquery_close_SAVE:
                              txtedit_saveas(s);
                              break;
                          case dboxquery_close_DISCARD:
                              txt_setcharoptions(t, txt_UPDATED, 0);

                              break;
                          default : break;
                              /* cancel do nothing, it stays updated. */
                          }
                        }
                      if ((txt_UPDATED & txt_charoptions(s->t)) == 0)
                        /* don't if save failed. */
                        txtedit_dispose(s);
                        return; /* e.g. DON'T settexttitle, because s no longer there. */
                      }
                  };
                  break;
#if !NEWDELETE
         case 127:          /* delete key */
#endif
         case 8:            /* control-H (backspace) */
                if (txt_selectset(t))
                {
                  /* Equivalent to cut */
                  txtedit_copyselection(s);
                  txtedit_deleteselection();
                }
                else
                {
                  int dot = txt_dot(t);
                  int distance;
                  BOOL ateof = dot == txt_size(t);
                  BOOL atnl = txt_charatdot(t) == '\n';

                  loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                  /* zero if BOF */
                  if (dot < count) count = dot;
                  txt_setcharoptions(t, txt_CARET, 0);
                  txt_movehorizontal(t, count * -1);
                  distance = dot - txt_dot(t);
                  if (distance != 0) {
                    if (s->overwrite && (!ateof) && (!atnl)) {
                      /* replace chars with spaces. */
                      char a[100];
                      int i = 0;
                      while (i < count) a[i++] = ' ';
                      a[count] = 0;
                      txt_replacechars(t, distance, a, distance);
                    } else {
                      txt_delete(t, distance);
                    };
                  };
                  /* 23-May-89 This is different from deleting 'count', in that if the
                  cursor was over to the right of a NewLine, the movehorizontal will only
                  decrement us gently to the left. */
#if WORDWRAP
                  txtedit_normalisepara(s);
#endif
                  txt_setcharoptions(t, txt_CARET, txt_CARET);
                  break;
                };

         /* Selection keys */

         case 3:  /* control-C */
                  txtedit_copyselection(s);
                  break;
         case 24: /* control-X */
                  txtedit_copyselection(s);
                  /* Fall through */
         case 11: /* control-K */
                  txtedit_deleteselection();
                  break;
         case akbd_InsertK: /* Insert */         
         case 22: /* control-V */
                  txtedit_pasteselection(s);
                  break;
         case 1:  /* control-A */
                  txtscrap_setselect(s->t, 0, INT_MAX);
                  break;
         case 26: /* control-Z */
                  txtedit_clearselection(s->t);
                  break;

         /* Arrow keys */

         case akbd_LeftK:
         case akbd_UpK:
                  /* Exit selection at left */
                  if (txt_selectset(t))
                    txt_setdot(t, txt_selectstart(t));
                     
                  if (e == akbd_LeftK) { /* LeftK */
                    txt_movehorizontal(t, -1);
                  } else { /* UpK */
                    loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                    txt_movevertical(t, 0 - count, NULL);
                  }
                  break;
         case akbd_RightK:
         case akbd_DownK:
                  /* Exit selection at right */
                  if (txt_selectset(t))
                    txt_setdot(t, txt_selectend(t));

                  if (e == akbd_RightK) { /* RightK */
                    txt_movehorizontal(t, 1);
                  } else { /* DownK */
                    loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                    txt_movevertical(t, count, NULL);
                  }
                  break;
         case akbd_Sh + akbd_Ctl + akbd_UpK:
         case txt_EXTRACODE + akbd_Sh + akbd_Ctl + akbd_UpK:
                  loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                  txt_movevertical(t, 0 - count, 1);
                  loop_flag = FALSE;
                  break;
         case  akbd_Sh + akbd_Ctl + akbd_DownK:
         case txt_EXTRACODE + akbd_Sh + akbd_Ctl + akbd_DownK:
                  loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                  txt_movevertical(t,  count, 1);
                  break;
#if NEWDELETE
         case 127:
#else
         case akbd_EndK: /* delete char */
#endif
                  if (txt_selectset(t))
                  {
                    /* Equivalent to cut */
                    txtedit_copyselection(s);
                    txtedit_deleteselection();
                  }
                  else
                  {
                    loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                    txt_delete(t, count);
#if WORDWRAP
                    txtedit_normalisepara(s);
#endif
                  }
                  break;
         case akbd_Sh + akbd_LeftK:
                  txt_setdot(t, txtmisc_bow(t, txt_dot(t)));
                  break;
         case akbd_Sh + akbd_RightK:
                  txt_setdot(t, txtmisc_eow(t, txt_dot(t)));
                  break;
         case akbd_Sh + akbd_UpK:
         case txt_EXTRACODE + akbd_Sh + akbd_UpK:
                  loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                  txt_movevertical(t, 0-(txt_visiblelinecount(t)*count), NULL);
                  break;
         case akbd_Sh + akbd_DownK:
         case txt_EXTRACODE + akbd_Sh + akbd_DownK:
                  loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                  txt_movevertical(t, txt_visiblelinecount(t)*count, NULL);
                  break;
         case akbd_Sh + akbd_EndK: /* delete word */
                  { txt_index to = txt_dot(t);
                    loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                    while ((count--) > 0) to = txtmisc_eow(t, to);
                    txt_delete(t, to - txt_dot(t));
                    txtedit_clearselection(s->t); /* more sane than deleting it */
#if WORDWRAP
                    txtedit_normalisepara(s);
#endif
                  };
                  break;
         case akbd_Ctl + akbd_LeftK:
                  txt_setdot(t, txtmisc_bol(t, txt_dot(t)));
                  break;
         case akbd_Ctl + akbd_RightK:
                  txt_setdot(t, txtmisc_eol(t, txt_dot(t)));
                  break;
         case akbd_Ctl + akbd_UpK:
         case 30: /* home key (and control-^) */
                  txt_setdot(t, 0);
                  break;
#if NEWDELETE
         case akbd_EndK:
#endif
         case akbd_Ctl + akbd_DownK:
                  txt_setdot(t, INT_MAX);
                  break;
         case akbd_Ctl + akbd_EndK: /* delete line */
                  { txt_index end = 1 + txtmisc_eol(t, txt_dot(t));
                    loop_flag = txtedit_noticeseveral((int *)&next_e, &count);
                    txt_setdot(t, txtmisc_bol(t, txt_dot(t)));
                    txt_delete(t, end - txt_dot(t));
                    txtedit_clearselection(s->t); /* more sane than deleting it */
#if WORDWRAP
                    txtedit_normalisepara(s);
#endif
                  };
                  break;
         case akbd_TabK:
                  if (s->wordtab) {
                    txtedit_clearselection(s->t); /* Word tab mode moves the cursor */
                    txtmisc_tab(s->t);
                  } else {
                    txtedit_deleteselection(); /* Column tab mode inserts spaces */
                    txtmisc_tabcol(s->t);
                  };
                  break;

#if PRINT
         case akbd_PrintK:
                  txtedit__printstart(s, txt_size(s->t), txtedit__print_wholefile_unknowns);
                  break;
#endif

         default : /* including RETURN key and line feed. */
                  if (e >= 256) {
                    tracef0("give key back to wimp...\n");
                    wimp_processkey(e);
                  } else {
                    loop_flag = txtedit_keyboardinput(s, &e);
                  };
                  break;
       };
       switch (e) {
         case 30: /* home key */
#if NEWDELETE
         case akbd_EndK:
#endif
         case akbd_LeftK:            case akbd_RightK:
         case akbd_Ctl + akbd_LeftK: case akbd_Ctl + akbd_RightK:
         case akbd_Sh + akbd_LeftK:  case akbd_Sh + akbd_RightK:
         case akbd_UpK:              case akbd_DownK:
         case akbd_Ctl + akbd_UpK:   case akbd_Ctl + akbd_DownK:
         case akbd_Sh + akbd_UpK:    case akbd_Sh + akbd_DownK:
                  /* Movers clear the selection */
                  txtedit_clearselection(s->t);
                  break;
       };
       switch (e) {
         default:
           /* undo/redo ops are joined together into a single major edit,
           for undoing purposes. */
           txtundo_separate_major_edits(t);
         case akbd_Fn + 8:
         case akbd_Fn + 9:
           break;
       };
     } /* endwhile */
     s->selectrecent = FALSE;
     s->seltype = txtedit_CHARSEL;
  }

  if (wasupdated != (txt_UPDATED & txt_charoptions(t)))
    /* change the title so that the update is displayed */
    txtedit_settexttitle(s);
}

static void txtedit_eventhandler(txt t, void *s)
{
  txtedit_obeyeventcode(t, s, txt_get(t));
}

#ifndef SET_MISC_OPTIONS
static int txtedit__readoptnum(char *buf, int *i) {
  /* read a number from the option string. */
  int result = buf[*i] - '0';
  char c;
  if (buf[*i] == 0) return 0;
  (*i)++;
  c = buf[*i];
  if (c >= '0' && c <= '9') {
    result *= 10;
    result += c - '0';
    (*i)++;
  };
  return result;
}
#endif

txtedit_state *txtedit_newwithoptions(char *filename, int desired_filetype, txtar_options *o)
{
txtedit_state  *s;
typdat ty;
txt t;
int len;

  int filetype;
  BOOL result;

tracef1("newwithoptions of '%s'.\n", (int) filename);

{ int objtype;
  int attr;
  os_error *er;

  if (filename == 0 || filename[0] == 0) {
    er = 0;
    objtype = 0; /* not found */
  } else {
    er = os_swi6r(os_X + OS_File, 5, (int) filename, 0, 0, 0, 0,
           &objtype,
           0,
           &ty.ld,
           &ty.ex,
           &len,
           &attr);

    if (wimpt_complain(er) != 0) return NULL;

    if (objtype != 1) {
      static os_error e;

      e.errnum = 0;
      sprintf(e.errmess, msgs_lookup(MSGS_txt43), filename);
      wimpt_complain(&e);
      return NULL;
    };

    /* If the file already has a viewer on it which isn't updated, and
    the datestamp matches, then just pop that window to the top. If the
    datestamp does not match then reload the window from the file,
    assuming that the file has been updated behind our backs. */
    s = 0;
    if (filename != 0) s = txtedit_findnamedtxt(filename);
    if (s != 0
    && (0 == (txt_UPDATED & txt_charoptions(s->t)))) {
      wimp_wstate ws;
      wimp_w      w;
      if (ty.ld == s->ty.ld && ty.ex == s->ty.ex) {
        tracef1("non-updated window on '%s' already exists.\n", (int) filename);
      } else {
        tracef1("file '%s' has been updated, reload.\n", (int) filename);
        txt_setdot(s->t, 0);
        txt_delete(s->t, INT_MAX);
        txtedit_doinsertfile(s, filename, TRUE);
      };
      w = txt_syshandle(s->t);
      wimp_get_wind_state(w, &ws);
      ws.o.behind = -1; /* pop to top */
      wimp_sendwmessage(wimp_EOPEN, (wimp_msgstr*) &ws.o, w, -1);
      txt_setcharoptions(s->t, txt_CARET, 0); /* force re-aquisition */
      txt_setcharoptions(s->t, txt_CARET, txt_CARET);
      return s;
    };

  };

  tracef0("os_file 5 returned ok.\n");

  if (objtype != 1)
  {
    ty.ld = (int)0xfff00000;             /* text attribute */
    ty.ld |= desired_filetype << 8;
    ty.ex = 0;
    txtfile_buildnewtimestamp(ty, &ty);  /* new time and date */
    len = 0;
  }

  /* All other errors will be caught by attempting to load the file. */
  /* >>>> some check on the length? */
};

tracef2("ld=%x,ex=%x.\n", ty.ld, ty.ex);

t = txt_new(filename);
if (t == 0) {
   werr(FALSE, msgs_lookup(MSGS_txt4));
   return NULL;
};

s = txtedit__init(t);
if (s == 0) {
   txt_dispose(&t);
   werr(FALSE, msgs_lookup(MSGS_txt5));
   return NULL;
};

s->ty = ty;


#ifndef SET_MISC_OPTIONS
{
    /* Setting various options. */
    /* If options are added, check with the other finder in c.txtar
       that there isn't a clash. */
    /* Mnemonics: Overwrite, Tab col, worDwrap, Undo, Parawidth */

#define MAXSYSVARSIZE 256

    char buf[MAXSYSVARSIZE];
    int i = 0;
    int undosize = 5000;
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
      case 'O':
      case 'o':
        s->overwrite = TRUE;
        break;
      case 'T':
      case 't':
        s->wordtab = FALSE;
        break;
      case 'D':
      case 'd':
        s->wordwrap = TRUE;
        break;
      case 'U':
      case 'u':
        undosize = txtedit__readoptnum(buf, &i);
        if (undosize < 100) undosize = 100;
        break;
      case 'n':
      case 'N':
        buf[i] = 0; /* font name: force end. */
        break;
      default:
        break;
        /* Note that, if an unrecognised option comes along, a following
        signed number will be skipped over. Thus, other options not mentioned
        here will simply be ignored. */
        /* Also, spaces will be ignored too. */
      };
    };
    txtundo_setbufsize(s->t, undosize);

};
#endif


#ifdef SET_MISC_OPTIONS
{
   txtar_options opts;

   txtar_getoptions(s->t, &opts);
   txtundo_setbufsize(s->t, opts.undosize);
}
#endif




/* PJC: change made so that if the filetype is NOT text,
   wordwrap is initially forced to OFF
*/
filetype = 0xfff & (s->ty.ld >> 8);
if ((0xfff & (s->ty.ld >> 20)) != 0xfff) filetype = -1;
if (filetype != 0xfff) s->wordwrap = FALSE;

txt_setcharoptions(s->t, txt_DISPLAY, 0);
txt_show(s->t);

if (o != NULL) txtar_setoptions(s->t, o);

txt_setcharoptions(s->t, txt_CARET, txt_CARET);

if (filename != 0 && filename[0] != 0) {

#if BASIC
  /* PJC: assumes that filetype is still correct from earlier on */
  if (txtedit__detokenise == -1) filetype = -1;
  if (filetype == 0xffb && (result = txtedit__validbasicfile(filename))) {
    if (result == 2)
        result = 0;
    else
        result = txtfile_basicinsert(s->t, filename, len, &(s->ty), txtedit__detokenise, txtedit__strip);
  } else {
#endif
    result = txtfile_insert(s->t, filename, len, &(s->ty));
#if BASIC
  }
#endif

  if (!result) {
    txtedit_dispose(s);
    return NULL;
  };
};

txt_eventhandler(s->t, txtedit_eventhandler, s);

event_attachmenumaker(txt_syshandle(s->t), txtedit_menumaker,
                        txtedit_menueventproc, s);
/* >>>> could fail, in which case you won't get a menu -
harmless at least. */

txt_setcharoptions(s->t, txt_UPDATED + txt_DISPLAY, txt_DISPLAY);
txtundo_purge_undo(s->t);
strcpy(s->filename, filename);
txtedit_settexttitle(s);

/* IDJ up-call to tell others that a new state has been created 15-Feb-90 */
if (txtedit__open_handler != 0)
    txtedit__open_handler(s->filename, s, txtedit__open_handle);
return s;
}

/* >>>> Should this be public? def.TextEdit has somewhat gone to the
dogs, as the module metamorphoses from general purpose toolbox to quick
demo hack. */


txtedit_state *txtedit_new(char *filename, int filetype)
{
   return txtedit_newwithoptions(filename, filetype, NULL);
}


/* Install special handlers (maybe useful for file reservation in SDE) */
/* IDJ 30-11-89 */

#ifndef UROM
txtedit_update_handler txtedit_register_update_handler (txtedit_update_handler h, void *handle)
{
   txtedit_update_handler oldh = txtedit__update_handler;
   txtedit__update_handler = h;
   txtedit__update_handle  = handle;
   return oldh;
}
#endif

#ifndef UROM
txtedit_save_handler txtedit_register_save_handler (txtedit_save_handler h,
                                                    void *handle)
{
   txtedit_save_handler oldh = txtedit__save_handler;
   txtedit__save_handler = h;
   txtedit__save_handle = handle;
   return oldh;
}
#endif

#ifndef UROM
txtedit_close_handler txtedit_register_close_handler (txtedit_close_handler h, void *handle)
{
   txtedit_close_handler oldh = txtedit__close_handler;
   txtedit__close_handler = h;
   txtedit__close_handle = handle;
   return oldh;
}
#endif

#ifndef UROM
txtedit_shutdown_handler txtedit_register_shutdown_handler (txtedit_shutdown_handler h, void *handle)
{
   txtedit_shutdown_handler oldh = txtedit__shutdown_handler;
   txtedit__shutdown_handler = h;
   txtedit__shutdown_handle = handle;
   return oldh;
}
#endif

#ifndef UROM
txtedit_undofail_handler txtedit_register_undofail_handler (txtedit_undofail_handler h, void *handle)
{
   txtedit_undofail_handler oldh = txtedit__undofail_handler;
   txtedit__undofail_handler = h;
   txtedit__undofail_handle = handle;
   return oldh;
}
#endif

#ifndef UROM
/* yet another up-call for use by the DDE (IDJ: 15-Feb-90) */
txtedit_open_handler txtedit_register_open_handler (txtedit_open_handler h, void *handle)
{
   txtedit_open_handler oldh = txtedit__open_handler;
   txtedit__open_handler = h;
   txtedit__open_handle = handle;
   return oldh;
}
#endif

/* Access to the list of edits */

txtedit_state *txtedit_getstates(void)
{
   return txtedits;
}


/* -------- Initialisation. -------- */


txtedit_state *txtedit_install(txt t)
{

txtedit_state  *s;

s = txtedit__init(t);
if (s == 0) return 0;
txt_eventhandler(t, txtedit_eventhandler, s);
event_attachmenumaker(txt_syshandle(t), txtedit_menumaker,
                                         txtedit_menueventproc, s);
return s;
}


static BOOL txtedit__datasavedhandler(wimp_eventstr *e, void *handle)
{
  handle=handle;

  switch(e->e)
  {
    case wimp_EACK:
        if ((e->data.msg.hdr.action == wimp_MDATAREQUEST) &&
            (e->data.msg.hdr.my_ref == clipboard_ref) && withinmsel)
        {
          /* Bounced trying to open the 'Selection' menu, shade 'Paste' option and
          show it anyway, the non bounced case is handled by txtedit_pasteok(). */
          menu_setflags(m3, txtedit_MSelPaste,  FALSE, TRUE);
          wimp_create_submenu(menu_syshandle(m3), mselx, msely);
          withinmsel = FALSE;
        }
        return FALSE;

    case wimp_ESEND:
    case wimp_ESENDWANTACK:
        tracef3("Message: task=&%x, your_ref=&%x, type=&%x\n", e->data.msg.hdr.task,
                                                               e->data.msg.hdr.your_ref,
                                                               e->data.msg.hdr.action);
        switch (e->data.msg.hdr.action) {
           case wimp_MDATASAVED:
              {
                 txtedit_state *s;
       
                 for (s = txtedits; s; s = s->next) {
                   int lastref = txt_lastref(s->t);
                   if (lastref && (lastref == e->data.msg.hdr.your_ref)) {
                     tracef1("Marking buffer &%p unmodified\n",s->t);
                     txt_setcharoptions(s->t, txt_UPDATED, 0);    /* mark text unmodified */
                     txtedit_settexttitle(s);                     /* update title bar */
                     break;
                   }
                 }
              }
              return TRUE;

           case wimp_MCLAIMENTITY:
              if ((wimpt_task() == e->data.msg.hdr.task) ||
                  (!(e->data.msg.data.claimentity.flags & wimp_MCLAIMENTITY_flags_clipboard)))
                return FALSE; /* msg from myself or not a clipboard claim */

              if (clipboard_anchor != NULL)
                flex_free(&clipboard_anchor); /* free that clipboard */
              return TRUE;

           case wimp_MDATAREQUEST:
              if ((e->data.msg.data.datarequest.flags & wimp_MDATAREQUEST_flags_clipboard) &&
                  (clipboard_anchor != NULL))
              {
                /* Someone asked for the clipboard contents and we have text placed on it */
                xfersend_close_on_xfer(FALSE, (wimp_w)-1);
                xfersend_pipe(0xfff, NULL, flex_size(&clipboard_anchor),
                              txtedit__saveclipproc,
                              txtedit__sendclipproc,
                              NULL /* Not printing */,
                              e,
                              NULL /* No handle */
                             );
                return TRUE;
              }
              return FALSE;
        }
  }

  return FALSE;
}

#if BASIC
void txtedit_setBASICaddresses(int tokenise, int detokenise)
{
  txtedit__detokenise = detokenise;
  txtedit__tokenise = tokenise;
}

void txtedit_setBASICstrip(BOOL newstrip)
{
  txtedit__strip = newstrip;
}

void txtedit_setBASICincrement(int increment)
{
  txtedit__increment = increment;
}
#endif

void txtedit_init(void)
{
   txtoptmenu_init();

   win_add_unknown_event_processor(txtedit__datasavedhandler, NULL);

#if BASIC
   txtedit__detokenise = -1;
   txtedit__tokenise = -1;
   txtedit__increment = 10;
   txtedit__strip = FALSE;
#endif
}
