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
/* -> c.DrawMenu
 *
 * Menu maker and selection routines for Draw
 * Also handles keys
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.18
 * History: 0.10 - 12 June 1989 - header added. Old code weeded.
 *                                interpolation added.
 *                                upgraded to drawmod
 *                                bug fix 1242 (Pattern -> Line pattern)
 *                 16 June 1989 - upgraded to msgs
 *          0.11 - 19 June 1989 - keystoke equivalent added
 *                 21 June 1989 - split up select menu
 *                                gave menu variables better names
 *          0.12 -  7 July 1989 - select and transform rearranged.
 *                                snap changed, path edit snap added
 *                 11 July 1989 - zoom lock added
 *          0.13 - 17 July 1989 - undo and redo added
 *          0.14 -  4 Aug  1989 - tighter restriction on grade/interp
 *          0.15 - 13 Aug  1989 - dbox position setting
 *          0.16 - 25 Aug  1989 - paper limits reset added
 *          0.17 - 06 Sept 1989 - enable nulls for dboxtcol
 *          0.18 - 13 Sept 1989 - avoid static data problems for module version
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "Global/FileTypes.h"

#include "akbd.h"
#include "colourmenu.h"
#include "dbox.h"
#include "dboxtcol.h"
#include "event.h"
#include "magnify.h"
#include "msgs.h"
#include "os.h"
#include "saveas.h"
#include "werr.h"
#include "wimp.h"
#include "wimpt.h"
#include "xferrecv.h"
#include "help.h"
#include "drawmod.h"
#include "jpeg.h"
#include "font.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawAction.h"
#include "DrawDispl.h"
#include "DrawEdit.h"
#include "DrawEnter.h"
#include "DrawFileIO.h"
#include "DrawGrid.h"
#include "DrawMenu.h"
#include "DrawMenuD.h"
#include "DrawObject.h"
#include "DrawPrint.h"
#include "DrawScan.h"
#include "DrawSelect.h"
#include "DrawTextC.h"
#include "DrawTrans.h"
#include "DrawUndo.h"

/*------------------------------------------------------------------------*/
/*                      The principal menus                               */

menu draw_menu_mainmenu;

static menu mMisc, mSave, mStyle, mEnter, mSelect, mTransform, mGrid,
    mFontText;

static menu mLinewidth, mLinepattern, mJoin, mStrCap, mEndCap, mWinding,
    mFonttype, mFontsize, mFontheight;

static menu mJustify, mInterpol, mGrade;

static menu mPaper;

static menu mRotate, mXscale, mYscale, mLscale, mMagnify;

static menu mCapStr, mCapEnd;
static menu mTriWidS, mTriHeiS, mTriWidE, mTriHeiE;
static menu mEdit;

static wimp_menustr *Font_Menu_Ptr = NULL;

/* Window for which menu was last seen */
static wimp_w main_window = -1;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* draw_menu_maker  - constructs a static menu skeleton (from main)       */
/* draw_menu_filler - ticks/shades skeleton when 'menu' is pressed        */
/* draw_menu_proc   - processes menu actions                              */
/*                                                                        */
/* ---------------------------------------------------------------------- */

#define MIN_FONTSIZE dbc_OnePoint
#define MAX_FONTSIZE dbc_OneThousandPoint
#define fontsizetext "MenuFS1"

static int fontsizevalue [] =
  { 0, /* ignore 0th entry */
    dbc_EightPoint,
    dbc_TenPoint,
    dbc_TwelvePoint,
    dbc_FourteenPoint,
    dbc_TwentyPoint
  };

#define MIN_LINEWIDTH THIN
#define MAX_LINEWIDTH dbc_OneThousandPoint
#define linewidthtext "MenuLW1"

static int linewidthvalue [] =
  { 0,
    THIN,
    dbc_QuarterPoint,
    dbc_HalfPoint,
    dbc_OnePoint,
    dbc_TwoPoint,
    dbc_FourPoint
  };

static char *linejointext = "MenuLJ1";

static draw_jointyp linejoinvalue [] =
  { 0,
    join_mitred,
    join_round,
    join_bevelled
  };

static char *linecaptext = "MenuLC1";
static draw_captyp linecapvalue [] =
  { 0,
    cap_butt,
    cap_round,
    cap_square,
    cap_triang
  };

static char *linewindingtext = "MenuLR1";
static draw_windtyp linewindingvalue [] =
  { (draw_windtyp) 0,
    wind_nonzero,
    wind_evenodd
  };

#define MIN_TRICAP 0
#define MAX_TRICAP 0x100
#define tricaptext "MenuLC4"
static int tricapvalue [] = {0, 16, 32, 48, 64};

#define MAX_SCALEFACTOR 100

/* none is  _______________________________  */
/* pat1 is  _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _  */
/* pat2 is  __  __  __  __  __  __  __  __   */
/* pat3 is  ____    ____    ____    ____     */
/* pat4 is  ____ _ ____ _ ____ _ ____ _ ____ */

static draw_dashstr pat1 = {0, 6, {dbc_TwentythInch, dbc_TwentythInch,
                                   dbc_TwentythInch, dbc_TwentythInch,
                                   dbc_TwentythInch, dbc_TwentythInch}};

static draw_dashstr pat2 = {0, 6, {dbc_TenthInch, dbc_TenthInch,
                                   dbc_TenthInch, dbc_TenthInch,
                                   dbc_TenthInch, dbc_TenthInch}};

static draw_dashstr pat3 = {0, 6, {dbc_FifthInch, dbc_FifthInch,
                                   dbc_FifthInch, dbc_FifthInch,
                                   dbc_FifthInch, dbc_FifthInch}};

static draw_dashstr pat4 = {0, 4, {dbc_FifthInch, dbc_TwentythInch,
                                   dbc_TwentythInch, dbc_TwentythInch}};

#define linepatterntext "MenuLP1"

static draw_dashstr *linepatternvalue [6]={0};
static void init_static_arrays (void)

{ linepatternvalue [0] = 0;
  linepatternvalue [1] = SOLID;
  linepatternvalue [2] = &pat1;
  linepatternvalue [3] = &pat2;
  linepatternvalue [4] = &pat3;
  linepatternvalue [5] = &pat4;
}

#define menu_sel_bufferLen 10   /* was 10 } try something narrower */

#define menu_sel_fieldWid 6
#define grid_spacing_fieldWid 6
#define grid_subdivision_fieldWid 3     /* ie 2 digits */

static char
  mSelLinewidth [menu_sel_bufferLen],
  mSelFontsize [menu_sel_bufferLen],
  mSelFontheight [menu_sel_bufferLen],
  mSelFontText [draw_menu_TEXT_LINE_LIMIT + 1],
  mSelTriCapWid [menu_sel_bufferLen] /*Start & End TriCap*/,
  mSelTriCapHei [menu_sel_bufferLen]  /*are common*/,
  mSelRotate [menu_sel_bufferLen],
  mSelXscale [menu_sel_bufferLen],
  mSelYscale [menu_sel_bufferLen],
  mSelLscale [menu_sel_bufferLen],
  mSelMagnify [menu_sel_bufferLen],
  mSelInterpol [menu_sel_bufferLen],
  mSelGrade [menu_sel_bufferLen];

/*-----------------------------------------------------------------------*/
/*                             Style actions                             */
/*-----------------------------------------------------------------------*/

typedef struct
{ BOOL       path_fade;     /* False if path_data is valid */
  BOOL       path_pattern_fade;
  pathrec    path_data;

  BOOL       textcol_fade;
  BOOL       text_fade;
  fontrec    text_data;
} style_str;

static style_str style;

/* text objects have a colour, fontsize (x,y) and font name,               */
/* whereas text areas have only a colour                                  */
/*                                                                        */
/*  text_fade   textcol_fade                                              */
/*  TRUE        TRUE            no data in text_data, fade its menu entrie*/
/*  TRUE        FALSE           text_data.textcolour holds colour from a  */
/*                              text areas, fade other menu entries       */
/*  FALSE       TRUE            text_data holds text object data, all fiel*/
/*                              valid                                     */
/*  FALSE       FALSE           text_data.textcolour holds colour from a  */
/*                              either a text or a text area object       */
/*                              other fields show text object data        */

/* read_style - fill 'style' variable used by 'draw_setstylemenu' either  */
/*              a) In entry mode, with user selected colour & width info  */
/*              b) In select mode, by examining currently selected objects*/

static void readstyle_path (draw_objptr hdrptr, void *handle)

{ draw_pathstyle s      = hdrptr.pathp->pathstyle;
  style_str      *style = (style_str *)handle;
  int            i;
  draw_dashstr   *pat   = draw_obj_dashstart (hdrptr);

  ftracef0 ("[readstyle_path\n");

  style->path_pattern_fade    = FALSE;
  style->path_fade            = FALSE;
  style->path_data.linewidth  = hdrptr.pathp->pathwidth;
  style->path_data.linecolour = hdrptr.pathp->pathcolour;
  style->path_data.fillcolour = hdrptr.pathp->fillcolour;
  style->path_data.pattern = SOLID;

  if (pat != SOLID)
    for (i = 1; i < sizeof linepatternvalue/sizeof (draw_dashstr *); i++)
    { draw_dashstr *proposed = linepatternvalue [i];
      BOOL found = FALSE;

      if (proposed != SOLID)
      { if ((pat->dash.dashcount == proposed->dash.dashcount) &&
            (pat->dash.dashstart == proposed->dash.dashstart))
        { int j;
          found = TRUE;

          for (j = 0; j < pat->dash.dashcount; j++)
            if (pat->elements [j] != proposed->elements [j])
            { found = FALSE;
              break;
            }
        }
      }
      if (found) { style->path_data.pattern = proposed; break; }
  }

  style->path_data.join      = s.s.join;
  style->path_data.startcap  = s.s.startcap;
  style->path_data.endcap    = s.s.endcap;
  style->path_data.windrule  = (draw_windtyp) s.s.windrule;
  style->path_data.tricapwid = s.s.tricapwid;
  style->path_data.tricaphei = s.s.tricaphei;
  ftracef0 ("readstyle_path]\n");
}

static void readstyle_text (draw_objptr hdrptr, void *handle)

{ style_str *style = (style_str *)handle;

  ftracef0 ("[readstyle_text\n");

  style->text_fade = FALSE;
  style->text_data.typeface   = hdrptr.textp->textstyle.fontref;
  style->text_data.typesizex  = hdrptr.textp->fsizex;
  style->text_data.typesizey  = hdrptr.textp->fsizey;
  style->text_data.textcolour = hdrptr.textp->textcolour;
  style->text_data.background = hdrptr.textp->background;
  ftracef0 ("readstyle_text]\n");

}

static void readstyle_textarea (draw_objptr hdrptr, void *handle)

{ draw_textcolhdr *column;
  draw_objptr      endObject;
  style_str       *style = (style_str *)handle;

  ftracef0 ("[readstyle_textarea\n");

  /* Skip through columns */
  column = & (hdrptr.textareastrp->column);
  while (column->tag == draw_OBJTEXTCOL) column++;

  endObject.textcolp = column;

  style->textcol_fade = FALSE;
  style->text_data.textcolour = endObject.textareaendp->textcolour;
  style->text_data.background = endObject.textareaendp->backcolour;
  ftracef0 ("readstyle_textarea]\n");
}

static void readstyle_trfmtext (draw_objptr hdrptr, void *handle)

{ style_str *style = (style_str *)handle;

  ftracef0 ("[readstyle_trfmtext\n");

  style->text_fade = FALSE;
  style->text_data.typeface   = hdrptr.trfmtextp->textstyle.fontref;
  style->text_data.typesizex  = hdrptr.trfmtextp->fsizex;
  style->text_data.typesizey  = hdrptr.trfmtextp->fsizey;
  style->text_data.textcolour = hdrptr.trfmtextp->textcolour;
  style->text_data.background = hdrptr.trfmtextp->background;
  ftracef0 ("readstyle_trfmtext]\n");

}

static despatch_tab readstyletab =
{ 0 /*fontlist*/,     readstyle_text,     readstyle_path, 0 /*rect*/,
  0 /*elli*/,         0 /*spri*/,         0 /*group*/,    0 /*tagged*/,
  0 /*'8'*/,          readstyle_textarea, 0 /*textcol*/,  0 /*options*/,
  readstyle_trfmtext};

static void read_style (diagrec *diag)

{ style.path_fade = style.text_fade = style.textcol_fade = TRUE;
  style.path_pattern_fade = TRUE;

  ftracef0 ("[read_style\n");

  switch (diag->misc->mainstate)
  { case state_path:
    case state_text:
    case state_rect:
    case state_elli:
      style.path_pattern_fade = FALSE;    /* Only shown in entry mode */
    case state_edit:
      style.path_fade         = FALSE;
      style.path_data         = diag->misc->path;
      style.text_fade         = FALSE;
      style.text_data         = diag->misc->font;
    break;

    case state_sel:
      draw_scan_traverse (NULL, NULL, readstyletab, &style);
    break;
  }
  ftracef0 ("read_style]\n");
}

/*Now whenever a style change is made, the diagram entry mode variables are
  updated (used to apply the style change to either 1)  the selection group
  2a) the diagram entry mode variables or 2b) the incompletely entered
  object). JRC 24 Jan 1990 */

static void set_style (diagrec *diag, restyle_action action, int changeto)

{ ftracef0 ("[set_style\n");

  if (draw_select_owns (diag))
    switch (action)
    { case restyle_LINEPATTERN:
        draw_select_repattern_selection ((draw_dashstr *) changeto);
      break;

      default: /*Fixed-width items.*/
        draw_select_restyle_selection (action, changeto);
      break;
    }
  else
    switch (diag->misc->substate)
    { case state_text_caret:
      case state_text_char:
      { int hdroff = *(int *) (diag->paper + diag->misc->stacklimit);
        draw_objptr hdrptr;
        draw_bboxtyp box;

        hdrptr.bytep = diag->paper + hdroff;

        if (draw_obj_findTextBox (hdrptr, &box))
          draw_displ_redrawarea (diag, &box);   /* Redraw over old object */
        else
          draw_displ_forceredraw (diag);

        draw_select_restyle_object (hdrptr, action, changeto);

        if (draw_obj_findTextBox (hdrptr, &box))
          draw_displ_redrawarea (diag, &box);   /* Redraw over new object */
        else
          draw_displ_forceredraw (diag);

        /* Reset the caret: probably not the best way */
        draw_displ_eor_skeleton (diag);
      }
    }

  switch (action)
  { case restyle_LINEWIDTH:
      diag->misc->path.linewidth = changeto;
    break;

    case restyle_LINECOLOUR:
      diag->misc->path.linecolour = changeto;
    break;

    case restyle_FILLCOLOUR:
      diag->misc->path.fillcolour = changeto;
    break;

    case restyle_LINEPATTERN:
      diag->misc->path.pattern = (draw_dashstr *) changeto;
    break;

    case restyle_LINEJOIN:
      diag->misc->path.join = changeto;
    break;

    case restyle_LINESTARTCAP:
      diag->misc->path.startcap = changeto;
    break;

    case restyle_LINEENDCAP:
      diag->misc->path.endcap = changeto;
    break;

    case restyle_LINETRICAPWID:
      diag->misc->path.tricapwid = changeto;
    break;

    case restyle_LINETRICAPHEI:
      diag->misc->path.tricaphei = changeto;
    break;

    case restyle_LINEWINDING:
      diag->misc->path.windrule = (draw_windtyp) changeto;
    break;

    case restyle_FONTFACE:
      draw_set_current_font (diag, changeto,
          diag->misc->font.typesizex,
          diag->misc->font.typesizey);
    break;

    case restyle_FONTSIZE: /* change both x and y */
      draw_set_current_font (diag, diag->misc->font.typeface,
          changeto, changeto);
    break;

    case restyle_FONTSIZEY: /* change y only */
      draw_set_current_font (diag, diag->misc->font.typeface,
          diag->misc->font.typesizex,
          changeto);
    break;

    case restyle_FONTCOLOUR:
      diag->misc->font.textcolour = changeto;
    break;

    case restyle_FONTBACKGROUND:
      diag->misc->font.background = changeto;
    break;
  }
  ftracef0 ("set_style]\n");
}

static void set_style_limited (diagrec *diag, restyle_action action,
                       int changeto, int lowest, int toohigh)

{ ftracef0 ("[set_style_limited\n");

  if (changeto >= lowest && changeto < toohigh)
    set_style (diag, action, changeto);
  ftracef0 ("set_style_limited]\n");
}

/* -------------------------------------------------------------------- */

static struct            /* set if we own the selection     */
{ BOOL path;             /* and have one or more selected.. */
  BOOL sprite;
  BOOL group;
  BOOL textarea;
  BOOL interpol;
  BOOL text;             /*system font or antialiased*/
  BOOL antialiased_text; /*not system font*/
  BOOL jpeg;
} got;

/* -------------------------------------------------------------------- */
/* General menu maker */
static menu make_menu (char *title, char *body)

{  menu m;

   ftracef0 ("[make_menu\n");
   m = menu_new (msgs_lookup (title), msgs_lookup (body));
   ftracef0 ("make_menu]\n");
   return m;
}

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* read_select - fill 'select' variable used by 'draw_setselectmodemenu'  */
/*                                                                        */

static void read_select (diagrec *diag)

{ int i;
  draw_objptr hdrptr;

  ftracef0 ("[read_select\n");

  got.path = got.sprite = got.group = got.textarea =
     got.interpol = got.text = got.antialiased_text = got.jpeg = FALSE;

  if (draw_select_owns (diag))
  { for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
    { if (hdrptr.objhdrp->tag == draw_OBJPATH) got.path = TRUE;

      if (hdrptr.objhdrp->tag == draw_OBJSPRITE ||
          hdrptr.objhdrp->tag == draw_OBJTRFMSPRITE) got.sprite = TRUE;

      if (hdrptr.objhdrp->tag == draw_OBJGROUP) got.group = TRUE;

      if (hdrptr.objhdrp->tag == draw_OBJTEXTAREA) got.textarea = TRUE;

      if (hdrptr.objhdrp->tag == draw_OBJTEXT ||
          hdrptr.objhdrp->tag == draw_OBJTRFMTEXT)
        got.text = TRUE;

      if ((hdrptr.objhdrp->tag == draw_OBJTEXT &&
          hdrptr.textp->textstyle.fontref != NULL) ||
          (hdrptr.objhdrp->tag == draw_OBJTRFMTEXT &&
          hdrptr.trfmtextp->textstyle.fontref != NULL))
        got.antialiased_text = TRUE;

      if (hdrptr.objhdrp->tag == draw_OBJJPEG) got.jpeg = TRUE;
    }

    /* Interpolate - only if one object of suitable type */
    if (i == 1)
      got.interpol = draw_select_may_grade (draw_select_find (0));
  }
  #if TRACE
    ftracef (__FILE__, __LINE__,
        "path %s, sprite %s, group %s, textarea %s, interpol %s, "
        "text %s, antialiased_text %s, jpeg %s\n",
        whether (got.path), whether (got.sprite), whether (got.group),
        whether (got.textarea), whether (got.interpol), whether (got.text),
        whether (got.antialiased_text), whether (got.jpeg));
  #endif

  ftracef0 ("read_select]\n");
}

/*-----------------------------------------------------------------------*/
/*                          Save actions                                 */
/*-----------------------------------------------------------------------*/

/* Flags to indicate what may be saved */
#define save_File       1
#define save_Selection  2
#define save_Sprite     4
#define save_TextArea   8
#define save_PostScript (1 << 4)
#define save_JPEG       (1 << 5)

typedef int save_flags;

/* Table of parameters for saving */
static
  struct
  { char              *name;              /* Default name */
    int                type;              /* File type */
    xfersend_saveproc  save;              /* Save procedure */
    xfersend_sendproc  ramsave;           /* RAM save procedure */
    xfersend_printproc print;             /* Printer procedure */
    int              (*size) (diagrec *); /* size estimator*/
       /*added J R C 9th Mar 1994*/
  }
  save_table [] =
    { { /*File*/
        "FileDr",
        FileType_Draw,
        draw_file_file_saveall,
        draw_file_ram_saveall,
        draw_file_printall,
        &draw_file_size
      },
      { /*Selection*/
        "FileSe",
        FileType_Draw,
        draw_file_file_saveselection,
        draw_file_ram_saveselection,
        NULL,
        &draw_file_selection_size
      },
      { /*Sprite*/
        "FileSp",
        FileType_Sprite,
        draw_file_file_exportsprites,
        draw_file_ram_exportsprites,
        NULL,
        &draw_file_sprites_size
      },
      { /*Text area*/
        "FileTa",
        FileType_Text,
        draw_file_file_exportTextArea,
        draw_file_ram_exportTextArea,
        NULL,
        &draw_file_text_size
      },
      /*This entry added by J R C. 28th Sep 1993*/
      { /*EPSF*/
        "FileTb",
        0xFF5,
        draw_file_file_exportEPSF,
        NULL,
        NULL,
        NULL
      },
      /*This entry added by J R C. 21st Sep 1994*/
      { /*JPEG*/
        "FileTc",
        FileType_JPEG,
        draw_file_file_exportJPEG,
        NULL,
        NULL,
        NULL
      }
    };

/* Report what may be saved */
static save_flags may_save (diagrec *diag)

{ save_flags f = save_File; /* can always save a file */

  ftracef0 ("[may_save\n");

  if (draw_select_owns (diag) && draw_selection->indx > 0)
    f |= save_Selection;

  if (got.sprite && draw_selection->indx == 1) f |= save_Sprite;

  if (got.textarea && draw_selection->indx == 1) f |= save_TextArea;
      /*only allow save text area if exactly 1 is selected. JRC 8 Oct 1990*/

  if (draw_print_have_postscript ())
     f |= save_PostScript;

  if (got.jpeg && draw_selection->indx == 1) f |= save_JPEG;

  ftracef0 ("may_save]\n");
  return f;
}

/* Save in specified manner.
   'key' is TRUE if from a keystroke - in this case, we set the caret
   position, and also make checks that the save is allowed
   auto_name means we can save the file without putting up a dbox, provided
   it has a valid name. If not, we pop up the dbox.
*/
static void do_save (diagrec *diag, save_flags how, BOOL key,
    BOOL auto_name)

{ int  index;  /* Index into save_table */
  char *name;

  ftracef4
  ( "[do_save: diag: 0x%X; how: 0x%X; key: %c; auto_name: %c\n",
    diag, how, key? 't': 'f', auto_name? 't': 'f'
  );

  /* Check validity of save (in case we came from keystroke) */
  ftracef0 ("[do_save: calling read_select\n");
  read_select (diag);

  if ((may_save (diag) & how) == 0)
  { Error (0, "MenuNoS");
    return;
  }

  /* Set the caret position, so dbox is in a reasonable position */
  if (key)
  { ftracef0 ("[do_save: calling draw_get_focus\n");
    draw_get_focus ();
  }

  /* Find the sort of save and the file name */
  index =
    how == save_File?       0:
    how == save_Selection?  1:
    how == save_Sprite?     2:
    how == save_TextArea?   3:
    how == save_PostScript? 4:
    how == save_JPEG?       5: -1;

  if (auto_name && how == save_File && diag->misc->filename [0] != '\0')
  { /* Name is given and we can auto save: so do it! */
    ftracef0 ("[do_save: calling draw_file_file_savedirect\n");
    draw_file_file_savedirect (diag->misc->filename, diag);
  }
  else
  { int est_size;

    if (how != save_File || (name = diag->misc->filename) [0] == '\0')
      name = msgs_lookup (save_table [index].name);

    if (save_table [index].size != NULL)
      est_size = (*save_table [index].size) (diag) + 4;
            /*add 4 so that the buffer is always incomplete the first time,
            so the whole transfer happens in one exchange*/
    else
      est_size = 1024;

    ftracef0 ("[do_save: calling saveas\n");
    saveas (save_table [index].type, name, est_size,
           save_table [index].save,
           save_table [index].ramsave,
           save_table [index].print,
           (void *) diag);
  }

  /* Return the caret to where it was */
  if (key)
  { ftracef0 ("[do_save: calling draw_displ_show_caret_if_up\n");
    draw_displ_showcaret_if_up (diag);
  }
  ftracef0 ("do_save]\n");
}

/*------------------------------------------------------------------------*/
/*                          Load actions                                  */
/*------------------------------------------------------------------------*/
/* These come from keys only */

/* Load or insert a file.
   diag is the window which contained the input focus (so we can restore
   caret on escape). vuue is NULL for a load, else the input window.
   'load' is FALSE for an insert, TRUE for a load.
 */
static void do_load (diagrec *diag, viewrec *vuue, BOOL load)

{ dbox d;
  diagrec *loaddiag = load? NULL: diag;

  ftracef0 ("[do_load\n");

  /* Set the caret position, so dbox is in a reasonable position */
  draw_get_focus ();

  /* Put up the load dialogue box */
  if ((d = dbox_new ("dboxfile_db")) != NULL)
  { /*Supply raw event handler for help messages*/
    dbox_raw_eventhandler (d, &help_dboxrawevents, (void *) "LOAD");

    /* Fill in type of load */
    dbox_setfield (d, 1, msgs_lookup ((load) ? "MenuLF" : "MenuLI"));
    dbox_showstatic (d);

    do
    { switch (dbox_fillin (d))
      { case 0: /* OK */
          /* Get the name of the file */
          { char filename [FILENAMEMAX];
            dbox_getfield (d, 2, filename, FILENAMEMAX);

            draw_file_load_named_file (filename, loaddiag, vuue);
          }
        break;

        default:
        break;  /* Ignore other fields */
      }
    } while (dbox_persist ());
    dbox_hide (d); /* Make sure it has gone away */
  }

  /* Return the caret to where it was */
  draw_displ_showcaret_if_up (diag);
  ftracef0 ("do_load]\n");
}

/*-----------------------------------------------------------------------*/
/*                           Edit actions                                */
/*-----------------------------------------------------------------------*/

/* Reports whether editing is valid for moves, lines, curves, numeric entry,
   grid snap, or just any at all. Note thay grid snap is always valid, even
   if got_elem is FALSE. */
static BOOL edit_check (diagrec *diag, viewrec *vuue, BOOL *move,
    BOOL *line, BOOL *curve, BOOL *enter, BOOL *snap, BOOL *closed)

{ drawmod_pathelemptr prevele, currele, nextele, p;
  BOOL got_elem = draw_edit_got_pathelement (diag);

  ftracef0 ("[edit_check\n");

  *move = *line = *curve = *enter =
    got_elem || diag->misc->pathedit_cb.over == overMoveEp;

  if (*enter)  /* If a Move/Line/Curve is selected */
  { /* Find the current elements */
    currele.bytep = diag->paper + diag->misc->pathedit_cb.cele_off;
    prevele.bytep = diag->paper + diag->misc->pathedit_cb.pele_off;
    nextele.bytep = NULL;

    switch (currele.end->tag)
    { case path_move_2:
        *move = FALSE;
        switch (prevele.end->tag)
        { case path_move_2:
            *line = *curve = FALSE;
          break;

          case path_lineto:
            *line = *curve = prevele.lineto+1 == currele.lineto;
          break;

          case path_bezier:
            *line = *curve = prevele.bezier+1 == currele.bezier;
          break;
        }
        nextele.move2 = currele.move2 + 1;
      break;

      case path_lineto:
        *line = FALSE;
        nextele.lineto = currele.lineto + 1;
      break;

      case path_bezier:
        *curve = FALSE;
        nextele.bezier = currele.bezier + 1;
      break;
    }

    if (!((prevele.lineto->tag == path_lineto ||
        prevele.bezier->tag == path_bezier) &&
        (nextele.lineto->tag == path_lineto ||
        nextele.bezier->tag == path_bezier)))
      *move = FALSE;

    /*Find out if we are in an open or closed path section. The section
      stops at a move_2 or end path; it is closed if it had a close
      in it.*/
    *closed = FALSE;
    p = currele;
    do
      switch (p.end->tag)
      { case path_move_2:
          p.move2++;
        break;

        case path_lineto:
          p.lineto++;
        break;

        case path_bezier:
          p.bezier++;
        break;

        case path_closeline:
          *closed = TRUE;
          p.closeline++;
        break;
      }
    while (p.end->tag != path_move_2 && p.end->tag != path_term);
  }

  /* Check if grid snap is allowed */
  *snap = vuue->flags.show || vuue->flags.lock;
  ftracef0 ("edit_check]\n");
  return got_elem;
}

/* 'code'  is the same as the menu subdivision */
/* Checks action is possible, in case we came from a keystroke */
static void do_edit (int code, diagrec *diag, viewrec *vuue)

{ os_error *err = 0;

  BOOL got_elem, move, line, curve, enter, snap, closed;

  ftracef0 ("[do_edit\n");

  got_elem = edit_check (diag, vuue, &move, &line, &curve, &enter, &snap,
      &closed);

  /* Make sure there is some editing possible */
  if ((code == s_Edit_Curve && !curve) ||
      (code == s_Edit_Line  && !line)  ||
      (code == s_Edit_Move  && !move)  ||
      (code == s_Edit_Flatten && !got_elem) ||
      ((code == s_Edit_Add  || code == s_Edit_Delete) && !got_elem) ||
      (code == s_Edit_Coord && !enter) ||
      (code == s_Edit_Snap && !snap) ||
      (code == s_Edit_Open && !got_elem) ||
      (code == s_Edit_Close && !got_elem))
    return;

  switch (code)
  { case s_Edit_Curve:
      err = draw_edit_changelinecurve (diag, path_bezier);
    break;

    case s_Edit_Line:
      err = draw_edit_changelinecurve (diag, path_lineto);
    break;

    case s_Edit_Move:
      err = draw_edit_changelinecurve (diag, path_move_2);
    break;

    case s_Edit_Add:
      err = draw_edit_addpoint (diag);
    break;

    case s_Edit_Delete:
      err = draw_edit_deletesegment (diag);
    break;

    case s_Edit_Flatten:
      err = draw_edit_flatten_join (diag);
    break;

    case s_Edit_Open:
      err = draw_edit_openpath (diag, vuue);
    break;

    case s_Edit_Close:
      err = draw_edit_closepath (diag);
    break;

    case s_Edit_Coord:
      err = draw_edit_adjustpoint (diag);
    break;

    case s_Edit_Snap:
      err = draw_edit_snappath (diag, vuue);
    break;
  }

  wimpt_complain (err);
  ftracef0 ("do_edit]\n");
}

/*------------------------------------------------------------------------*/
/*                          Enter actions                                 */
/*------------------------------------------------------------------------*/

static BOOL enter_check (int code, diagrec *diag, int *tick)

{ ftracef0 ("[enter_check\n");

  *tick = 0;

  switch (code)
  { case s_Enter_Enter:
    return TRUE;

    case s_Enter_Text:
      *tick = diag->misc->mainstate == state_text;
    return TRUE;

    case s_Enter_Line:
      *tick = diag->misc->mainstate==state_path &&
          !diag->misc->options.curved;
    return TRUE;

    case s_Enter_Curve:
      *tick = diag->misc->mainstate==state_path &&
          diag->misc->options.curved;
    return TRUE;

    case s_Enter_Move:
    return diag->misc->mainstate == state_path;

    case s_Enter_Complete:
    return diag->misc->mainstate == state_path;

    case s_Enter_Autoclose:
      *tick = diag->misc->options.closed;
    return diag->misc->mainstate == state_path;

    case s_Enter_Abandon:
    return TRUE;

    case s_Enter_Rectangle:
      *tick = diag->misc->mainstate == state_rect;
    return TRUE;

    case s_Enter_Ellipse:
      *tick = diag->misc->mainstate == state_elli;
    return TRUE;
  }

  ftracef0 ("enter_check]\n");
  return FALSE; /* Dummy */
}

/* 'code'   is the same as the menu subdivision */
/* Checks action is possible, in case we came from a keystroke */
static void do_enter (int code, diagrec *diag)

{ draw_state mainstate = diag->misc->mainstate;
  int curve = diag->misc->options.curved;
  int close = diag->misc->options.closed;
  os_error *err = 0;
  int dummy;
  ftracef0 ("[do_enter\n");

  if (!enter_check (code, diag,  &dummy)) return;

  switch (code)
  { case s_Enter_Enter:
      draw_action_changestate (diag, state_path, curve, close, TRUE);
    break;

    case s_Enter_Text:
      draw_action_changestate (diag, state_text, 0, 0, TRUE);
    break;

    case s_Enter_Line:
      draw_action_changestate (diag, state_path, 0, close, TRUE);
    break;

    case s_Enter_Curve:
      draw_action_changestate (diag, state_path, 1, close, TRUE);
    break;

    case s_Enter_Move:
      err = draw_enter_movepending (diag);
    break;

    case s_Enter_Complete:
      err = draw_enter_complete (diag);
    break;

    case s_Enter_Autoclose:
      if (mainstate == state_path)
        draw_action_changestate (diag, state_path, curve, !close, TRUE);
    break;

    case s_Enter_Abandon:
      draw_action_abandon (diag);
    break;

    case s_Enter_Rectangle:
      draw_action_changestate (diag, state_rect, 0, 0, TRUE);
    break;

    case s_Enter_Ellipse:
      draw_action_changestate (diag, state_elli, 0, 0, TRUE);
    break;
  }

  wimpt_complain (err);
  ftracef0 ("do_enter]\n");
}

/*------------------------------------------------------------------------*/
/*                         Select actions                                 */
/*------------------------------------------------------------------------*/

/* Last justify actions */
static char last_htl_justify = 0;
static char last_vtl_justify = 0;

/* Check validity of select actions */
/* The parameter is the same as the menu subdivision */
static BOOL select_check (int which, int code, diagrec *diag, viewrec *vuue)

{ BOOL owner = draw_select_owns (diag);
  ftracef0 ("[select_check\n");

  if (which == 1)
    switch (code)
    { case s_Select_Select:
      case s_Select_All:
        return TRUE;
      case s_Select_Clear:
      case s_Select_Delete:
      case s_Select_Front:
      case s_Select_Back:
        return owner && draw_selection->indx > 0;
      case s_Select_Copy:
        return draw_selection->indx > 0;
      case s_Select_Group:
        return owner && draw_selection->indx > 1;
      case s_Select_Ungroup:
        return got.group; /*Allow Ungroup with >1 group. JRC 24 Jan 1990*/
      case s_Select_Edit:
        return draw_selection->indx == 1 && (got.path || got.text);
      case s_Select_Snap:
        return owner && draw_selection->indx > 0
                && (vuue->flags.show || vuue->flags.lock);
      case s_Select_Justify:
        return got.group;
      case s_Select_Interp:
      case s_Select_Grade:
        return got.interpol;
      case s_Select_To_Path:
        return got.antialiased_text || got.group; /*lazy - but
                                  nothing else on this menu
                                  recurses through groups*/
    }
  else
    switch (code)
    { case s_Transform_Rotate:
        /*Check object is rotatable. JRC 9th Jan 1995*/
        return owner && draw_selection->indx > 0 && draw_select_rotatable (diag);

      case s_Transform_XScale:
      case s_Transform_YScale:
      case s_Transform_Magnify:
        return owner && draw_selection->indx > 0;

      case s_Transform_LScale:
        return owner && !style.path_fade;
    }
  ftracef0 ("select_check]\n");

  return FALSE; /* Dummy */
}

/* 'which'  is 1 or 2 for the first or second select menus */
/* 'code'   is the same as the menu subdivision */
/* 'hit'    is the rest of the hit string, if any */
/* Checks action is possible, in case we came from a keystroke */
static void do_select (int which, int code, char *hit, diagrec *diag,
                      viewrec *vuue)

{ os_error *err = 0;
  diagrec  *sel = draw_selection->owner;

  ftracef0 ("[do_select\n");

  /* Check validity of action */
  read_style (diag);
  read_select (diag);
  if (!select_check (which, code, diag, vuue)) return;

  if (which == 1)
  { /* Mark beginning of undo, except for case of path edit */
    if (!(code == s_Select_Edit && got.path))
      draw_undo_separate_major_edits (diag);

    switch (code)
    { case s_Select_Select:
        draw_action_changestate (diag, state_sel, 0, 0, FALSE);
      break;

      case s_Select_All:
        draw_action_changestate (diag, state_sel, 0, 0, FALSE);
        err = draw_select_selectall (diag);
      break;

      case s_Select_Clear:
        draw_select_clearall (sel);
      break;

      case s_Select_Copy:
      { trans_str jog;

        draw_grid_jog (vuue, &jog);
        err = draw_select_copy (sel, diag, &jog);
      }
      break;

      case s_Select_Delete:
        err = draw_select_delete (sel);
      break;

      case s_Select_Front:
        err = draw_select_front (sel);
      break;

      case s_Select_Back:
        err = draw_select_back (sel);
      break;

      case s_Select_Group:
        err = draw_select_group (sel);
      break;

      case s_Select_Ungroup:
        err = draw_select_action_ungroup ();
      break;

      case s_Select_Edit:
        if (draw_select_owns (diag) && draw_selection->indx == 1)
        { int obj_off = draw_selection->array [0];

          if (got.path)
            /*Came from menu or keystroke*/
            draw_edit_editobject (diag, obj_off);
          else if (got.text)
          { ftracef0 ("checking menu hit\n");
            if (hit != NULL)
            { /*Came from menu*/
              if (*hit == 1)
                draw_select_selection_text (mSelFontText);
            }
            else
              draw_edit_text (diag, obj_off);
          }
        }
      break;

      case s_Select_Snap:
        draw_trans_gridsnap_selection (vuue);
      break;

      case s_Select_Justify:
        if (hit == NULL || *hit == 0)
          draw_select_justify_selection (last_htl_justify,
              last_vtl_justify);
        else if (*hit >= 1 && *hit <= 3)
          draw_select_justify_selection (last_htl_justify = *hit,
              last_vtl_justify = 0);
        else if (*hit >= 4 && *hit <= 6)
          draw_select_justify_selection (last_htl_justify = 0,
              last_vtl_justify = *hit - 3);
      break;

      case s_Select_Interp:
      case s_Select_Grade:
      { int levels;
        if (code == s_Select_Interp)
        { if (sscanf (mSelInterpol, "%d", &levels) < 1)
            levels = 0;
        }
        else
        { if (sscanf (mSelGrade, "%d", &levels) < 1)
            levels = 0;
        }

        if (levels > 255) levels = 255;
        if (levels > 1)
          draw_select_interpolate (sel, levels, code == s_Select_Interp);
      }
      break;

      case s_Select_To_Path:
        draw_select_convert_to_paths (sel); /*or give error message*/
      break;
    }
  }
  else
  {
    #if 0
      draw_undo_put_start_mod (diag, -1);
    #else
      draw_undo_separate_major_edits (diag);
    #endif

    if (code == s_Transform_Rotate)
    { double angle;

      if (sscanf (mSelRotate, "%lf", &angle) < 1)
        angle = 0.0;
      if (angle != 0.0)
      { draw_trans_rotate_str rotate;

        /* Fiddle the rotate block, so we can call undo */
        angle *= 0.0174532925;   /* deg -> rad */
        rotate.sin_theta = sin (angle);
        rotate.cos_theta = cos (angle);

        ftracef0 ("BEFORE:\n"), draw_trace_db (diag);
        draw_select_make_rotatable (diag);

        ftracef0 ("BETWEEN:\n"), draw_trace_db (diag);
        draw_trans_rotate (diag, -1, -1, &rotate);

        ftracef0 ("AFTER:\n"), draw_trace_db (diag);
      }
    }
    else
    { draw_trans_scale_str scale;
      BOOL negative_scale = FALSE;

      scale.u.flags.dolines = 0;
      scale.u.flags.dobody  = 1;
      scale.old_Dx = scale.old_Dy = scale.new_Dx = scale.new_Dy = 1.0;

      switch (code)
      { case s_Transform_XScale:
          if (sscanf (mSelXscale, "%lf", &scale.new_Dx) < 1)
            scale.new_Dx = 0;
          if (scale.new_Dx < 0) negative_scale = TRUE;
        break;

        case s_Transform_YScale:
          if (sscanf (mSelYscale, "%lf", &scale.new_Dy) < 1)
            scale.new_Dy = 0;
          if (scale.new_Dy < 0) negative_scale = TRUE;
        break;

        case s_Transform_LScale:
          if (sscanf (mSelLscale, "%lf", &scale.new_Dx) < 1)
            scale.new_Dx = 0;
          scale.u.flags.dobody  = 0;
          scale.u.flags.dolines = 1;
        break;

        case s_Transform_Magnify:
          if (sscanf (mSelMagnify, "%lf", &scale.new_Dx) < 1)
            scale.new_Dx = 0;
          if (scale.new_Dx < 0) negative_scale = TRUE;
             /*the scale is actually positive, but the text will turn upside
               down, so must be rotatable*/
          scale.new_Dy  = scale.new_Dx;
          scale.u.flags.dolines = 1;
        break;
      }

      #if 0 /*Better check done in DrawTrans:scale_check().*/
      if (fabs (scale.new_Dx) > MAX_SCALEFACTOR)
        scale.new_Dx = scale.new_Dx < 0? -MAX_SCALEFACTOR: MAX_SCALEFACTOR;
      if (fabs (scale.new_Dy) > MAX_SCALEFACTOR)
        scale.new_Dy = scale.new_Dy < 0? -MAX_SCALEFACTOR: MAX_SCALEFACTOR;
      #endif
      ftracef2 ("scaling by (%f, %f)\n", scale.new_Dx, scale.new_Dy);

      if (scale.new_Dx != 1.0 || scale.new_Dy != 1.0)
      { ftracef0 ("DrawMenu: do_select: calling draw_trans_scale\n");
        if (negative_scale) draw_select_make_rotatable (diag);

        draw_trans_scale (diag, -1, -1, &scale);
      }
    }
  }

  wimpt_complain (err);
  ftracef0 ("do_select]\n");
}

/*-----------------------------------------------------------------------*/
/*                            Toolbox actions                            */
/*-----------------------------------------------------------------------*/

void draw_menu_toolbox_toggle (viewrec *vuue)

{ ftracef0 ("[draw_menu_toolbox_toggle\n");

  vuue->flags.showpane ^= 1;                       /* toggle state */
  if (vuue->flags.showpane)                        /* new state is..*/
  { wimp_wstate wstate;                            /*   toolbox open */
    wimp_get_wind_state (vuue->w, &wstate);
    draw_open_wind (&wstate.o, vuue);
  }
  else
    wimp_close_wind (vuue->pw);                     /*   toolbox closed */

  ftracef0 ("draw_menu_toolbox_toggle]\n");
}

/*-----------------------------------------------------------------------*/
/*                             Colour actions                            */
/*-----------------------------------------------------------------------*/

/* Colour change control block */
typedef struct
{ diagrec         *diag;
  restyle_action  action;
  dboxtcol_colour *colour;
} colour_change_block;

/* Function called by dboxtcol. Called on left or right click of OK */
static void apply_colour (dboxtcol_colour col, void *handle)

{ colour_change_block *block = (colour_change_block *) handle;

  ftracef0 ("[apply_colour\n");
  set_style (block->diag, block->action, col);
  *block->colour = col;  /* Ensure source of colour is updated */
  draw_reset_gchar (); /*JRC 28 Jan 1991*/
  ftracef0 ("apply_colour]\n");

}

/* Function for changing a colour attribute */
static void change_colour (diagrec *diag, restyle_action action,
                          dboxtcol_colour *colour, BOOL trans,
                          char *title)

{ colour_change_block block;
  wimp_emask          emask;

  ftracef0 ("[change_colour\n");

  block.diag   = diag;
  block.action = action;
  block.colour = colour;

  /* Enable null events */
  event_setmask ((wimp_emask) ((emask = event_getmask ()) & ~wimp_EMNULL));

  dboxtcol (colour, trans, msgs_lookup (title), &apply_colour,
      (void *) &block);

  /* Restore event mask */
  event_setmask (emask);
  ftracef0 ("change_colour]\n");
}

/* -------------------------------------------------------------------- */

static void set_write (menu m, int subdiv, char *buffer, int width,
                      char *valid, char *init)

{ ftracef0 ("[set_write\n");

  menu_make_writeable (m, subdiv, buffer, width, valid);
  sprintf (buffer, init);
  ftracef0 ("set_write]\n");

}

/* -------------------------------------------------------------------- */

static menu draw_makepaperlimitsmenu (void)

{ ftracef0 ("draw_makepaperlimitsmenu [\n");
  return make_menu ("MenuP0", "MenuP1");
}

/* Returns show state */
static int draw_setpaperlimitsmenu (menu m, paperstate_typ paperstate)

{ int
    tickshow      = (paperstate.options & Paper_Show)      != 0,
    ticklandscape = (paperstate.options & Paper_Landscape) != 0,
    tickreset     = (paperstate.options & Paper_Default)   != 0;

  ftracef0 ("[draw_setpaperlimitsmenu\n");

  menu_setflags (m, s_Misc_Paper_Show,      tickshow,                    0);
  menu_setflags (m, s_Misc_Paper_Reset,     tickreset,                   0);
  menu_setflags (m, s_Misc_Paper_Portrait,  !ticklandscape,              0);
  menu_setflags (m, s_Misc_Paper_Landscape, ticklandscape,               0);
  menu_setflags (m, s_Misc_Paper_A0,        paperstate.size == Paper_A0, 0);
  menu_setflags (m, s_Misc_Paper_A1,        paperstate.size == Paper_A1, 0);
  menu_setflags (m, s_Misc_Paper_A2,        paperstate.size == Paper_A2, 0);
  menu_setflags (m, s_Misc_Paper_A3,        paperstate.size == Paper_A3, 0);
  menu_setflags (m, s_Misc_Paper_A4,        paperstate.size == Paper_A4, 0);
  menu_setflags (m, s_Misc_Paper_A5,        paperstate.size == Paper_A5, 0);

  ftracef0 ("draw_setpaperlimitsmenu]\n");

  return tickshow;
}

static void draw_setmiscmenu (diagrec *diag, viewrec *vuue)

{ BOOL mayredo;

  ftracef0 ("[draw_setmiscmenu\n");

  menu_setflags (mMisc, s_Misc_Paper,
               draw_setpaperlimitsmenu (mPaper, diag->misc->paperstate), 0);
  menu_setflags (mMisc, s_Misc_Zoomlock, vuue->flags.zoomlock, 0);
  menu_setflags (mMisc, s_Misc_Undo, 0,
      !draw_undo_may_undo (diag, &mayredo));
  menu_setflags (mMisc, s_Misc_Redo, 0, !mayredo);
  ftracef0 ("draw_setmiscmenu]\n");
}

/* -------------------------------------------------------------------- */

/* Tick slot on colour menu (no 'None' entry) */
static void draw_setcolourmenu (menu m, int colour)

{ int i;

  ftracef0 ("[draw_setcolourmenu\n");

  colour++;
  for (i = 1; i <= 16; i++)
    menu_setflags (m, i, i == colour, 0);
  ftracef0 ("draw_setcolourmenu]\n");
}

/* -------------------------------------------------------------------- */

static void draw_setlinepatternmenu (menu m, draw_dashstr *pattern)

{ int i;

  /* Tick slot containing 'pattern', clear all others */
  for (i = 1; i < sizeof linepatternvalue/sizeof (draw_dashstr *); i++)
    menu_setflags (m, i, linepatternvalue [i] == pattern, 0);
}

static void draw_setlinejoinmenu (menu m, int join)

{ int i;

  /* Tick slot containing 'join', clear all others */
  for (i = 1; i < sizeof linejoinvalue/sizeof (draw_jointyp); i++)
    menu_setflags (m, i, linejoinvalue [i] == join, 0);
}

static void draw_setlinecapmenu (menu m, int cap)

{ int i;

  /* Tick slot containing 'cap', clear all others */
  for (i = 1; i < sizeof linecapvalue/sizeof (draw_captyp); i++)
    menu_setflags (m, i, linecapvalue [i] == cap, 0);
}

static void draw_setlinewindingmenu (menu m, int winding)

{ int i;

  /* Tick slot containing 'winding', clear all others */
  for (i = 1; i < sizeof linewindingvalue/sizeof (draw_windtyp); i++)
    menu_setflags (m, i, linewindingvalue [i] == winding, 0);
}

/* -------------------------------------------------------------------- */

static wimp_menustr *draw_makefonttypemenu (int tick_fontref)

{  char *tick_font;

   if (tick_fontref == 0)
     /*Use system font*/
     tick_font = (char *) 1;
   else
     tick_font = draw_fontcat.name [tick_fontref];

   ftracef1 ("draw_makefonttypemenu: making menu with %s ticked\n",
       tick_fontref != 0? tick_font: "System font");
   if (wimpt_complain (font_makemenu (&Font_Menu_Ptr, tick_font,
         fontmenu_WithSystemFont)) != NULL)
      return NULL;

   return Font_Menu_Ptr;
}

int draw_menu_addfonttypeentry (char *name)

{ int i;
  BOOL found;

  ftracef1 ("searching fontcat for name %s\n", name);
  found = FALSE;
  for (i = 1; i < draw_fontcat.list_size; i++)
    if (draw_file_matches (draw_fontcat.name [i], name))
    { ftracef0 ("draw_menu_addfontypeentry: found it\n");
      found = TRUE;
      break;
    }

  /*If found, return the index, else add the new name to fontcat*/
  if (found)
    return i;
  else
  { ftracef1 ("draw_menu_addfontypeentry: adding '%s' to fontcat\n",
        name);
    if (draw_fontcat.list_size >= 256 ||
        (draw_fontcat.name [draw_fontcat.list_size] =
        Alloc (strlen (name) + 1)) == NULL)
    { Error (TRUE, "MenuE1");
      return 0;
    }

    strcpy (draw_fontcat.name [draw_fontcat.list_size], name);
    return draw_fontcat.list_size++;
  }
}
#if 0
static void draw_setfonttypemenu (menu m, int fontref)

{ int i;

  fontref++;

  for (i = 0; i < draw_fontcat.list_size; i++)
    menu_setflags (m, i, i == fontref, 0);
}
#endif
/* -------------------------------------------------------------------- */

static menu draw_makefontsizemenu (char *heading, char *buffer)

{ menu m;

  m = make_menu (heading, fontsizetext);
  set_write (m, s_Font_var, buffer, menu_sel_fieldWid, draw_numvalid1, draw_zero_str);
  return (m);
}

static void draw_setfontsizemenu (menu m, char *buffer, int size)

{ int i;

  /* Tick slot containing 'size', clear all others */
  for (i = 1; i < (sizeof fontsizevalue / sizeof (int)); i++)
    menu_setflags (m, i, fontsizevalue [i] == size, 0);
  sprintf (buffer, "%.2f", (double)size/dbc_OnePoint);
}

static int draw_readfontsizemenu (int item, char *buffer)

{ switch (item)
  { default: return -1;

    case s_Font_8:
    case s_Font_10:
    case s_Font_12:
    case s_Font_14:
    case s_Font_20:
      return fontsizevalue [item];

    case s_Font_var:
    { double size;
      if (sscanf (buffer, "%lf", &size) < 1)
        size = 0;
      return (int) (size*dbc_OnePoint);
    }
  }
}
/* -------------------------------------------------------------------- */
static menu draw_makelinewidthmenu (char *buffer)

{ menu m;

  m = menu_new(msgs_lookup("MenuLW0"), msgs_lookup("MenuLW1"));
     /*removed stupid code from here. J R C. 15th Nov 1993*/

  set_write (m, s_Width_var, buffer, menu_sel_fieldWid, draw_numvalid1, draw_zero_str);
  return (m);
}

static void draw_setlinewidthmenu (menu m, char *buffer, int width)

{ int i;

  /* Tick slot containing 'width', clear all others */
  for (i = 1; i < (sizeof linewidthvalue / sizeof (int)); i++)
    menu_setflags (m, i, linewidthvalue [i] == width, 0);
  sprintf (buffer, "%.2f", (double)width/dbc_OnePoint);
}

static int draw_readlinewidthmenu (int item, char *buffer)

{ switch (item)
  { default: return -1;

    case s_Width_Thin: case s_Width_025:
    case s_Width_05:   case s_Width_1:
    case s_Width_2:    case s_Width_4:
      return linewidthvalue [item];

    case s_Width_var:
    { double size;

      if (sscanf (buffer, "%lf", &size) < 1)
        size = 0;
      return (int) (size*dbc_OnePoint);
    }
  }
}

/* -------------------------------------------------------------------- */

static menu draw_maketricapmenu (char *heading, char *buffer)

{ menu m;

  m = make_menu (heading, tricaptext);
  set_write (m, s_Cap_var, buffer, menu_sel_fieldWid, draw_numvalid1, draw_zero_str);
  return (m);
}

static void draw_settricapmenu (menu m, char *buffer, int factor)

{ int i;

  /* Tick slot containing 'factor', clear all others */
  for (i = 1; i < sizeof tricapvalue/sizeof (int); i++)
    menu_setflags (m, i, tricapvalue [i] == factor, 0);
  sprintf (buffer, "%.2f", (double)factor/16);
}

static int draw_readtricapmenu (int item, char *buffer)

{ switch (item)
  { default: return (-1);

    case s_Cap_x1: case s_Cap_x2:
    case s_Cap_x3: case s_Cap_x4:
      return tricapvalue [item];

    case s_Cap_var:
    { double size;

      if (sscanf (buffer, "%lf", &size) < 1)
        size = 0;
      return (int) (size*16);
    }
  }
}

/* -------------------------------------------------------------------- */

static menu draw_makestylemenu (void)
   /*diag - the diagram for which this is the style menu*/

{ menu m = make_menu ("MenuS0", "MenuS1");

  mLinewidth = draw_makelinewidthmenu (mSelLinewidth);

  mLinepattern = make_menu ("MenuLP0", linepatterntext);
  menu_make_sprite (mLinepattern, 1, "none");
  menu_make_sprite (mLinepattern, 2, "pat1");
  menu_make_sprite (mLinepattern, 3, "pat2");
  menu_make_sprite (mLinepattern, 4, "pat3");
  menu_make_sprite (mLinepattern, 5, "pat4");

  mJoin    = make_menu ("MenuLJ0", linejointext);
  mStrCap  = make_menu ("MenuLCs", linecaptext);
  mCapStr  = make_menu ("MenuLC2", "MenuLC3");
  mTriWidS = draw_maketricapmenu ("MenuLG1", mSelTriCapWid);
  mTriHeiS = draw_maketricapmenu ("MenuLG2", mSelTriCapHei);

  menu_submenu (mCapStr, s_Style_Cap_Width,    mTriWidS);
  menu_submenu (mCapStr, s_Style_Cap_Height,   mTriHeiS);
  menu_submenu (mStrCap, s_Style_Cap_Triangle, mCapStr);

  mEndCap = make_menu ("MenuLCe", linecaptext);
  mCapEnd = make_menu ("MenuLC2", "MenuLC3");

  mTriWidE = draw_maketricapmenu ("MenuLG1", mSelTriCapWid);
  mTriHeiE = draw_maketricapmenu ("MenuLG2", mSelTriCapHei);

  menu_submenu (mCapEnd, s_Style_Cap_Width,    mTriWidE);
  menu_submenu (mCapEnd, s_Style_Cap_Height,   mTriHeiE);
  menu_submenu (mEndCap, s_Style_Cap_Triangle, mCapEnd);

  mWinding    = make_menu ("MenuLR0", linewindingtext);
  mFonttype   = NULL; /*don't make this till the menu is displayed*/
  mFontsize   = draw_makefontsizemenu ("MenuLG3", mSelFontsize);
  mFontheight = draw_makefontsizemenu ("MenuLG2", mSelFontheight);

  menu_submenu (m, s_Style_Linewidth,  mLinewidth);
  menu_submenu (m, s_Style_Pattern,    mLinepattern);
  menu_submenu (m, s_Style_Join,       mJoin);
  menu_submenu (m, s_Style_Startcap,   mStrCap);
  menu_submenu (m, s_Style_Endcap,     mEndCap);
  menu_submenu (m, s_Style_Winding,    mWinding);
  /*menu_submenu (m, s_Style_Typeface,   mFonttype);*/
  menu_submenu (m, s_Style_Typesize,   mFontsize);
  menu_submenu (m, s_Style_Typeheight, mFontheight);

  return m;
}

static void draw_setstylemenu (diagrec *diag)
  /*diag - the diagram for which this is the style menu*/

{ int i;

  diag = diag;

  for (i = 1; i <= 8; i++)
    menu_setflags (mStyle, i, 0, style.path_fade);
  menu_setflags (mStyle, s_Style_Pattern, 0, style.path_pattern_fade);

  if (!style.path_fade)
  { draw_setlinewidthmenu (mLinewidth,
                          mSelLinewidth, style.path_data.linewidth);

    if (!style.path_pattern_fade)
      draw_setlinepatternmenu (mLinepattern, style.path_data.pattern);

    draw_setlinejoinmenu (mJoin, style.path_data.join);
    draw_setlinecapmenu (mStrCap, style.path_data.startcap);
    draw_settricapmenu (mTriWidS, mSelTriCapWid, style.path_data.tricapwid);
    draw_settricapmenu (mTriHeiS, mSelTriCapHei, style.path_data.tricaphei);
    draw_setlinecapmenu (mEndCap, style.path_data.endcap);
    draw_settricapmenu (mTriWidE, mSelTriCapWid, style.path_data.tricapwid);
    draw_settricapmenu (mTriHeiE, mSelTriCapHei, style.path_data.tricaphei);
    draw_setlinewindingmenu (mWinding, style.path_data.windrule);
  }

  for (i = 9; i <= 11; i++)
    menu_setflags (mStyle, i, 0, style.text_fade);

  if (!style.text_fade)
  { /*With Font Manager 2.87+, build the whole new font menu every time*/
    wimp_menustr *font_menu;

    if ((font_menu = draw_makefonttypemenu (style.text_data.typeface)) ==
        NULL)
      return;

    /*Look at mStyle to find the place to write this wimp_menustr *. We know
      that a struct menu__str has the wimp menu structure at word 0 (though
      we're not really supposed to ...)*/
    ((wimp_menuitem *) ((wimp_menuhdr *) *(int *) mStyle + 1) +
        (s_Style_Typeface - 1))->submenu = font_menu;

    /*draw_setfonttypemenu (mFonttype, style.text_data.typeface);*/
    draw_setfontsizemenu (mFontsize, mSelFontsize,
        style.text_data.typesizex);
    draw_setfontsizemenu (mFontheight, mSelFontheight,
        style.text_data.typesizey);
  }

  menu_setflags (mStyle, s_Style_Textcolour, 0,
                style.text_fade && style.textcol_fade);
  menu_setflags (mStyle, s_Style_Background, 0,
                style.text_fade && style.textcol_fade);
}

/* -------------------------------------------------------------------- */

static void draw_setentermodemenu (diagrec *diag, menu m)

{ int i;

  for (i = 1; i <= 9; i++)
  { int tick, available;

    available = enter_check (i, diag, &tick);
    menu_setflags (m, i, tick, !available);
  }
}

/* -------------------------------------------------------------------- */

/* Additional menus for numeric select actions, and their buffers */

/* Make both select and transform menus */
static menu draw_makeselectmodemenu (menu *transform)

{ menu m = make_menu ("MenuSe0", "MenuSe1");
  menu t = make_menu ("MenuSe2", "MenuSe3");

  mFontText = make_menu ("MenuLG4", "MenuFT1");
  set_write (mFontText, 1, mSelFontText, draw_menu_TEXT_LINE_LIMIT, "", "");
  mJustify  = make_menu ("MenuSJ0", "MenuSJ1");
  mInterpol = make_menu ("MenuSG0", "MenuSN");
  mGrade    = make_menu ("MenuSG0", "MenuSN");

  menu_submenu (m, s_Select_Edit,    NULL /*sometimes mFontText*/);
  menu_submenu (m, s_Select_Justify, mJustify);
  menu_submenu (m, s_Select_Interp,  mInterpol);
  menu_submenu (m, s_Select_Grade,   mGrade);

  mRotate   = make_menu ("MenuSA0", "MenuSN");
  mXscale   = make_menu ("MenuSX0", "MenuSN");
  mYscale   = make_menu ("MenuSY0", "MenuSN");
  mLscale   = make_menu ("MenuSL0", "MenuSN");
  mMagnify  = make_menu ("MenuSM0", "MenuSN");

  menu_submenu (t, s_Transform_Rotate,  mRotate);
  menu_submenu (t, s_Transform_XScale,  mXscale);
  menu_submenu (t, s_Transform_YScale,  mYscale);
  menu_submenu (t, s_Transform_LScale,  mLscale);
  menu_submenu (t, s_Transform_Magnify, mMagnify);

  set_write (mInterpol,1, mSelInterpol,menu_sel_fieldWid, draw_numvalid0,    "8");
  set_write (mGrade,   1, mSelGrade,   menu_sel_fieldWid, draw_numvalid0,    "8");

  set_write (mRotate,  1, mSelRotate,  menu_sel_fieldWid, draw_numvalid2,draw_zero_str);
  set_write (mXscale,  1, mSelXscale,  menu_sel_fieldWid, draw_numvalid2,draw_one_str);
  set_write (mYscale,  1, mSelYscale,  menu_sel_fieldWid, draw_numvalid2,draw_one_str);
  set_write (mLscale,  1, mSelLscale,  menu_sel_fieldWid, draw_numvalid1,   draw_one_str);
  set_write (mMagnify, 1, mSelMagnify, menu_sel_fieldWid, draw_numvalid2,draw_one_str);

  *transform = t;
  return m;
}

static void draw_setselectmodemenu (diagrec *diag, viewrec *vuue, menu m,
    menu t)

{ int i;

  for (i = 0; i <= s_Select_To_Path; i++)
  { BOOL fade = !select_check (1, i, diag, vuue);

    switch (i)
    { case s_Select_Edit:
        /*The text menu appears and disappears.*/
        ftracef2 ("altering select menu: fade %s, got.path %s\n",
          whether (fade), whether (got.path));
        /*Now we'll be extremely wicked ...*/
        /*menu_submenu (m, s_Select_Edit, fade || got.path? 0: mFontText);*/
        ((wimp_menuitem *) ((wimp_menuhdr *) *(int *) m + 1) +
             (s_Select_Edit - 1))->submenu = fade || got.path? NULL:
             (wimp_menustr *) menu_syshandle (mFontText);

        if (!(fade || got.path))
        { draw_objptr hdrptr = draw_select_find (0);

          strcpy (mSelFontText, hdrptr.objhdrp->tag == draw_OBJTEXT?
              hdrptr.textp->text: hdrptr.trfmtextp->text);
        }
      break;
    }

    menu_setflags (m, i, 0, fade);
  }

  for (i = 0; i <= s_Transform_Magnify; i++)
    menu_setflags (t, i, 0, !select_check (2, i, diag, vuue));

  /* Set justify submenus */
  for (i = 1; i <= 6; i++)
    menu_setflags (mJustify, i,
        i <= 3? last_htl_justify == i: last_vtl_justify == i - 3, 0);
}
/* -------------------------------------------------------------------- */

/* There are several sets of submenus and buffers: we index then by (in
   order) x/y, inch/cm, spacing/division. Putting them in arrays leads to
   some strange loops, but makes the code neater.
*/

/* Buffers for numeric values (indexed by x/y then inch/cm) */
static char grid_buffer [2/*x,y*/] [2/*in,cm*/] [2/*sp,div*/] [menu_sel_bufferLen];

/* Subsidiary menu handles */
static menu mSize [2 /*x,y*/] [2 /*inch,cm*/];
static menu mUser [2 /*x,y*/] [2 /*inch,cm*/] [2 /*space,div*/];
static menu mColour;

/* Definition of the standard grid sizes - must match the menu entries:
   indexed by inch,cm, then menu subdivision */
static  double gridSpace [] [5]   = {{1, 1,  1,  1, -1},
                                  {1, 1,  -1, 0, 0}};
static  int    gridDivide [] [5]  = {{4, 16, 5, 10, -1},
                                  {2, 10, -1, 0, 0}};
static  int    grid_base [/*inch,cm*/] =
          {s_Grid_Inch_userSpace, s_Grid_Cm_userSpace};

/* Text for the menus */
static char *sizeText [/*inch,cm*/] =
                     {"MenuGrI", "MenuGrC"};
static char *sizeTitle [/*inch, cm */] = {"MenuGsI", "MenuGsC"};
static char *userTitle [/*space,div*/] = {"MenuGr0", "MenuGr1"};

/* Create menus - includes some slightly silly loops */
static menu draw_makegridmenu (void)

{ menu grid_m;                       /* Top level grid menu */
  int  xy, size, user;               /* Indices */

  /* Create all the menus */
  /* Level 1 */
  grid_m  = make_menu ("MenuGD0", "MenuGD1");
  mColour = colourmenu_make (msgs_lookup ("MenuGD0"), FALSE);

  /* Levels 2, 3 */
  for (xy = 0; xy < 2; xy++)
    for (size = 0; size < 2; size++)
    { /* Level 2 */
      mSize [xy] [size] = make_menu (sizeTitle [size], sizeText [size]);

      for (user = 0; user < 2; user++)
        mUser [xy] [size] [user] = make_menu (userTitle [user], "MenuSW");

      set_write (mUser [xy] [size] [0], 1, grid_buffer [xy] [size] [0],
                grid_spacing_fieldWid, draw_numvalid1, draw_one_str);
      set_write (mUser [xy] [size] [1], 1, grid_buffer [xy] [size] [1],
                grid_subdivision_fieldWid, draw_numvalid0, "1");
    }

  /* Build tree: level 3 into level 2 */
  for (xy = 0; xy < 2; xy++)
    for (size = 0; size < 2; size++)
      for (user = 0; user < 2; user++)
        menu_submenu (mSize [xy] [size], grid_base [size]+user,
            mUser [xy] [size] [user]);

  /* Build tree: level 2 into level 1 */
  menu_submenu (grid_m, s_Grid_Colour, mColour);
  for (xy = 0; xy < 2; xy++)
    for (size = 0; size < 2; size++)
      menu_submenu (grid_m, s_Grid_Inch+size+xy*2, mSize [xy] [size]);

  return grid_m;
}

/* In setting the spacing and subdivisions, we see if they match any of the
   standard values, and tick that entry if so. If not, the writeable fields
   are set to the values.
*/

static void draw_setgridmenu (menu m, viewrec *v)

{ int i, xy, size;
  int tickshow  = v->flags.show;
  int ticklock  = v->flags.lock;
  int tickiso   = v->flags.iso;
  int fade      = !(tickshow || ticklock);

  /* Main grid menu settings */
  menu_setflags (m, s_Grid_Show,   tickshow, 0);
  menu_setflags (m, s_Grid_Lock,   ticklock, 0);
  menu_setflags (m, s_Grid_Auto,   v->flags.autoadj, fade);
  menu_setflags (m, s_Grid_Colour, 0, fade);
  menu_setflags (m, s_Grid_Rect,   v->flags.rect, fade);
  menu_setflags (m, s_Grid_Iso,    tickiso,  fade);

  /* Set size submenus */
  for (xy = 0; xy < 2; xy++)
  { for (size = 0; size < 2; size++)
    { BOOL found;

      /* Tick relevant submenus */
      menu_setflags (m, s_Grid_Inch+size+xy*2,
          xy == 0? (size == 0? v->flags.xinch: v->flags.xcm):
                   (size == 0? v->flags.yinch: v->flags.ycm), fade);

      /* Tick/set writeable fields in size submenus */
      for (i = 0, found = FALSE; gridSpace [size] [i] != -1; i++)
      { if (v->gridunit [size].space [xy]  == gridSpace [size] [i] &&
            v->gridunit [size].divide [xy] == gridDivide [size] [i])
        { /* Tick this item */
          menu_setflags (mSize [xy] [size], i+1, 1, 0);
          found = TRUE;
        }
        else /* Untick it */
          menu_setflags (mSize [xy] [size], i+1, 0, 0);
      }

      /* Not found - place values in writeable item */
      /*Put them there anyway. JRC 24 Jan 1990*/
      /*if (!found)*/
      { sprintf (grid_buffer [xy] [size] [0], "%lf",
            v->gridunit [size].space [xy]);
        sprintf (grid_buffer [xy] [size] [1], "%d",
            v->gridunit [size].divide [xy]);
        /* SMC: Terminate strings at their maximum length */
        grid_buffer [xy] [size] [0] [grid_spacing_fieldWid-1] = '\0';
        grid_buffer [xy] [size] [1] [grid_subdivision_fieldWid-1] = '\0';
      }
    }
  }

  /* Isometric - all y cases are faded */
  if (tickiso)
  { menu_setflags (m, s_Grid_InchY, v->flags.yinch, 1);
    menu_setflags (m, s_Grid_CmY,   v->flags.ycm, 1);
  }

  draw_setcolourmenu (mColour, v->gridcolour);
}

/* -------------------------------------------------------------------- */

/* Path edit menu. The following rules stop silly/dangerous changes:
    may only change to a line if the current element is not already a line,
    and it is not preceded by a close (change from MOVE only);
    similarly for curves;
    may only chage to a move, if the current element is a line or curve, and it
    is by preceded and followed by lines/curves.
*/

static void draw_seteditmenu (diagrec *diag, viewrec *vuue, menu m)

{ BOOL got_elem, move, line, curve, enter, snap, closed;
  drawmod_pathelemptr currele;
  ftracef0 ("[draw_seteditmenu\n");
  currele.bytep = diag->paper + diag->misc->pathedit_cb.cele_off;

  got_elem = edit_check (diag, vuue, &move, &line, &curve, &enter, &snap,
      &closed);

  menu_setflags (m, s_Edit_Curve,  0, !curve);    /*change to curve*/
  menu_setflags (m, s_Edit_Line,   0, !line);     /*change to line*/
  menu_setflags (m, s_Edit_Move,   0, !move);     /*change to move*/
  menu_setflags (m, s_Edit_Add,    0, !(got_elem &&
      currele.bezier->tag != path_move_2));       /*add point*/
  menu_setflags (m, s_Edit_Delete, 0, !got_elem); /*delete segment*/
  menu_setflags (m, s_Edit_Flatten,0, !got_elem); /*flatten join*/
  menu_setflags (m, s_Edit_Open,   0, !(got_elem && closed)); /*open*/
  menu_setflags (m, s_Edit_Close,  0, !(got_elem && !closed)); /*close*/
  menu_setflags (m, s_Edit_Coord,  0, !enter);    /*numeric point entry*/
  menu_setflags (m, s_Edit_Snap,   0, !snap);     /*grid snap*/
  ftracef0 ("draw_seteditmenu]\n");
}

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* draw_menu_maker - is called on by main (), it constructs a static      */
/* ===============   menu skeleton, this is ticked/shaded later by        */
/*                          draw_menu_filler                              */

void draw_menu_maker (void)

{ /* Local to drawMenu: mEnter */
  ftracef0 ("draw_menu_maker: [\n");

  /* Build static */
  init_static_arrays ();

  draw_menu_mainmenu = make_menu ("MenuD0", "MenuD1");

  mMisc = make_menu ("MenuM0", "MenuM1");

  mPaper = draw_makepaperlimitsmenu ();
  menu_submenu (mMisc, s_Misc_Paper, mPaper);

  mSave = make_menu ("MenuSv0", "MenuSv1");

  mStyle  = draw_makestylemenu ();
  mEnter  = make_menu ("MenuEn0", "MenuEn1");
  mSelect = draw_makeselectmodemenu (&mTransform);
  mGrid   = draw_makegridmenu ();

  menu_submenu (draw_menu_mainmenu, s_Misc,   mMisc);
  menu_submenu (draw_menu_mainmenu, s_Save,   mSave);
  menu_submenu (draw_menu_mainmenu, s_Style,  mStyle);
  menu_submenu (draw_menu_mainmenu, s_Enter,  mEnter);
  menu_submenu (draw_menu_mainmenu, s_Select, mSelect);
  menu_submenu (draw_menu_mainmenu, s_Transform, mTransform);
  menu_submenu (draw_menu_mainmenu, s_Grid,   mGrid);

  /* Displayed whilst editing a path object */
  mEdit = make_menu ("MenuEd0", "MenuEd1");
  ftracef0 ("draw_menu_maker: ]\n");
}

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* draw_menu_filler - called when the mouse menu button is pressed,       */
/* ================   it ticks/shades etc the skeleton produced by        */
/*                           draw_menu_maker.                             */
/*                                                                        */

menu draw_menu_filler (void *handle)

{ viewrec *vuue = (viewrec *) handle;
  diagrec *diag = vuue->diag;
  draw_objptr hdrptr;

  ftracef0 ("draw_menu_filler: [\n");

  main_window = vuue->w;

  ftracef2 ("draw_menu_filler (diag=%d,view=%d)\n", (int)diag, (int)vuue);

  read_style (diag);
  read_select (diag);

  if (diag->misc->mainstate == state_edit)
  { draw_seteditmenu (diag, vuue, mEdit);

    ftracef0 ("registering edit menu help handler\n");
    help_register_handler (&help_simplehandler, (void *) "EDIT");

    ftracef0 ("draw_menu_filler: ]\n");
    return mEdit;
  }
  else
  { int tickentermode = diag->misc->mainstate == state_path ||
        diag->misc->mainstate == state_rect ||
        diag->misc->mainstate == state_elli ||
        diag->misc->mainstate == state_text;
    int tickselectmode = draw_select_owns (diag);
    int ticktoolbox = vuue->flags.showpane;
    save_flags f = may_save (diag);

    menu_setflags (draw_menu_mainmenu, s_Enter,   tickentermode,    0);
    menu_setflags (draw_menu_mainmenu, s_Select,  tickselectmode,   0);
    menu_setflags (draw_menu_mainmenu, s_Transform,
                      0, !tickselectmode || draw_selection->indx == 0);
    menu_setflags (draw_menu_mainmenu, s_Grid,    vuue->flags.show, 0);
    menu_setflags (draw_menu_mainmenu, s_Toolbox, ticktoolbox,      0);

    menu_setflags (mSave, s_Save_Select,     0, !(f & save_Selection));
    menu_setflags (mSave, s_Save_Sprite,     0, !(f & save_Sprite));
    menu_setflags (mSave, s_Save_Textarea,   0, !(f & save_TextArea));
    menu_setflags (mSave, s_Save_PostScript, 0, !(f & save_PostScript));
    menu_setflags (mSave, s_Save_JPEG,       0, !(f & save_JPEG));

    hdrptr.bytep = diag->paper + draw_selection->array [0];
    menu_setflags (mTransform, s_Transform_Rotate, 0, draw_selection->indx == 1 &&
          !draw_obj_rotatable (hdrptr));

    draw_setentermodemenu (diag, mEnter);
    draw_setselectmodemenu (diag, vuue, mSelect, mTransform);

    draw_setgridmenu (mGrid, vuue);
    draw_setmiscmenu (diag, vuue);
    draw_setstylemenu (diag);

    ftracef0 ("registering main menu help handler\n");
    help_register_handler (&help_simplehandler, (void *) "D");

    ftracef0 ("draw_menu_filler: ]\n");
    return draw_menu_mainmenu;
  }
}

/* ---------------------------------------------------------------------- */
/*                                                                        */
/*draw_menu_infoaboutprogram - cause the progInfo template to be displayed*/
/* ==========================                                             */
/*                                                                        */

void draw_menu_infoaboutprogram (void)

{ dbox d = dbox_new ("progInfo");

  if (d)
  { /*Supply raw event handler for help messages*/
    dbox_raw_eventhandler (d, &help_dboxrawevents, (void *) "INFO");

    /* Place the version string in the dialogue box */
    dbox_setfield (d, 4, msgs_lookup ("_Version"));

    dbox_show (d);
    dbox_fillin (d);
    dbox_hide (d);
    dbox_dispose (&d);
  }
}

static void draw_menu_infoaboutprinter (int *copiesp)

  /* Returns copies count */

{ int copies = 0;
  dbox d;
  char *name;

  if ((d = dbox_new ("printerInfo")) != NULL)
  { draw_print_recachepagelimits ();

    dbox_setfield (d, 0, (name = draw_printer_name ()) != NULL? name:
        msgs_lookup ("Print0"));
    dbox_setnumeric (d, 2, print_copies);
        /* start with last number of copies */

    /*Supply raw event handler for help messages*/
    dbox_raw_eventhandler (d, &help_dboxrawevents, (void *) "PRINT");

    dbox_show (d);

    switch (dbox_fillin (d))
    { case -1: /*Close*/
        copies = 0;
      break;

      default:
        /*Fix Med-1493. J R C 17th Dec 1993*/
        print_copies = copies = dbox_getnumeric (d, 2);
      break;
    }

    dbox_hide (d);
    dbox_dispose (&d);
  }

  *copiesp = copies;
}

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* draw_menu_proc - is called when a menu entry is selected               */
/* ==============                                                         */
/*                                                                        */

void draw_menu_proc (void *handle, char *hit)

{ os_error *err = 0;
  viewrec *vuue = (viewrec *) handle;
  diagrec *diag = vuue->diag;
  char *o_hit = hit;
  draw_options old_options;

  ftracef0 ("draw_menu_proc: [\n");

  /* Take a copy of the current options for later compare */
  memcpy (&old_options, &draw_current_options, sizeof (draw_options));
  
  main_window = -1;

  ftracef2 ("draw_menu_proc: diag %d, view %d\n", diag, vuue);
  if (diag->misc->mainstate == state_edit)
    do_edit (*hit, diag, vuue);
  else
  { switch (*hit++)
    { case s_Misc: /* misc */
      { switch (*hit++)
        { case  s_Misc_Info:
            if (*hit) draw_menu_infoaboutprogram ();
          break;

          case  s_Misc_Newview: /* misc.newview */
          { viewrec *vuue;
            err = draw_opennewview (diag, &vuue);
          }
          break;

          case  s_Misc_Paper: /* misc.paperlimits */
          { papersize_typ    size;
            paperoptions_typ options;

            size    = diag->misc->paperstate.size;
            options = diag->misc->paperstate.options;

            switch (*hit++)
            { case s_Misc_Paper_Show:
              case 0:
                draw_action_option (diag,
                    options = (paperoptions_typ) (options ^ Paper_Show));

                if ((options & Paper_Show) != 0)
                  draw_current_options.paper.o =
                      (paperoptions_typ) (draw_current_options.paper.o | Paper_Show);
                else
                  draw_current_options.paper.o =
                      (paperoptions_typ) (draw_current_options.paper.o & ~Paper_Show);
              break;

              case s_Misc_Paper_Reset:
                #if 0
                  if ((options & Paper_Default) == 0)
                    draw_action_option (diag, options | Paper_Default);
                #else
                  draw_action_option (diag,
                      options = (paperoptions_typ) (options ^ Paper_Default));

                if ((options & Paper_Default) != 0)
                  draw_current_options.paper.o =
                      (paperoptions_typ) (draw_current_options.paper.o | Paper_Default);
                else
                  draw_current_options.paper.o =
                      (paperoptions_typ) (draw_current_options.paper.o & ~Paper_Default);
                #endif
              break;

              case s_Misc_Paper_Portrait:
                draw_action_resize (diag, size,
                    options = (paperoptions_typ) (options & ~Paper_Landscape));
                draw_current_options.paper.o =
                    (paperoptions_typ) (draw_current_options.paper.o & ~Paper_Landscape);
              break;

              case s_Misc_Paper_Landscape:
                draw_action_resize (diag, size,
                    options = (paperoptions_typ) (options | Paper_Landscape));
                draw_current_options.paper.o =
                    (paperoptions_typ) (draw_current_options.paper.o | Paper_Landscape);
              break;

              case s_Misc_Paper_A0:
              case s_Misc_Paper_A1:
              case s_Misc_Paper_A2:
              case s_Misc_Paper_A3:
              case s_Misc_Paper_A4:
              case s_Misc_Paper_A5:
              { papersize_typ paper = (papersize_typ) (*(hit - 1) - 4 << 8);

                draw_action_resize (diag, paper, options);
                draw_current_options.paper.size = paper;
              }
              break;
            }

            draw_print_recachepagelimits ();
          }
          break;

          case  s_Misc_Print: /* misc.print */
          { /*FIX G-RO-9923 JRC 15 Oct '91 Print on choosing Print.*/
            int copies;

            if (*hit != 0)
              draw_menu_infoaboutprinter (&copies);
            else
              copies = 1;

            /*FIX G-RO-9224 JRC 18 Oct '91 Queue the file for later
              printing.*/
            if (copies > 0)
              err = draw_print_queue (diag, copies);
          }
          break;

          case s_Misc_Zoomlock:
            /* Change flag, leave zoom unchanged */
            vuue->flags.zoomlock ^= 1;

            draw_current_options.zoom.lock = vuue->flags.zoomlock;
          break;

          case s_Misc_Undo:
          { BOOL dummy;

            if (draw_undo_may_undo (diag, &dummy))
              draw_undo_undo (diag);
          }
          break;

          case s_Misc_Redo:
          { BOOL mayredo;

            if (draw_undo_may_undo (diag, &mayredo), mayredo)
              draw_undo_redo (diag);
          }
          break;
        }
      }
      break;

      case s_Save: /* file */
        if (*hit)
          do_save
          ( diag,
            *hit == s_Save_File?       save_File:
            *hit == s_Save_Select?     save_Selection:
            *hit == s_Save_Sprite?     save_Sprite:
            *hit == s_Save_PostScript? save_PostScript:
            *hit == s_Save_Textarea?   save_TextArea:
            *hit == s_Save_JPEG?       save_JPEG:
                                       -1,

            FALSE,
            hit [1] == 0
          );
        else
          do_save (diag, save_File, FALSE, TRUE);
      break;

      case s_Style: /* style */
      { int size;
        int slot = *(hit + 1);
        if (slot == 0) break;

        /* Style setting is unusual in that it does its own undo start and
           end, but only when we are going to work on a selection*/
        if (draw_select_owns (diag))    /* Start undo putting */
          draw_undo_separate_major_edits (diag);

        switch (*hit++)
        { case s_Style_Linewidth:
            set_style_limited (diag, restyle_LINEWIDTH,
                draw_readlinewidthmenu (slot, mSelLinewidth),
                MIN_LINEWIDTH, MAX_LINEWIDTH);
          break;

          case s_Style_Linecolour:
            change_colour (diag, restyle_LINECOLOUR,
                (dboxtcol_colour *) &style.path_data.linecolour,
                TRUE, "MenuCl1");
          break;

          case s_Style_Fillcolour:
            change_colour (diag, restyle_FILLCOLOUR,
                (dboxtcol_colour *) &style.path_data.fillcolour,
                TRUE, "MenuCl2");
          break;

          case s_Style_Pattern:
            set_style (diag, restyle_LINEPATTERN,
                (int) linepatternvalue [slot]);
          break;

          case s_Style_Join:
            set_style (diag, restyle_LINEJOIN, linejoinvalue [slot]);
          break;

          case s_Style_Startcap:
            set_style (diag, restyle_LINESTARTCAP, linecapvalue [slot]);
            slot = *(++hit + 1);

            switch (*hit++)  /* If non-zero, click on tricap menu */
            { case s_Style_Cap_Width:
                if (slot)
                  set_style_limited (diag, restyle_LINETRICAPWID,
                      draw_readtricapmenu (slot, mSelTriCapWid),
                      MIN_TRICAP, MAX_TRICAP);
              break;

              case s_Style_Cap_Height:
                if (slot)
                  set_style_limited (diag, restyle_LINETRICAPHEI,
                      draw_readtricapmenu (slot, mSelTriCapHei),
                      MIN_TRICAP, MAX_TRICAP);
              break;
            }
          break;

          case s_Style_Endcap:
            set_style (diag, restyle_LINEENDCAP, linecapvalue [slot]);
            slot = *(++hit+1);
            switch (*hit++)  /* If non-zero, click on tricap menu */
            { case s_Style_Cap_Width:
                if (slot)
                  set_style_limited (diag, restyle_LINETRICAPWID,
                      draw_readtricapmenu (slot, mSelTriCapWid),
                      MIN_TRICAP, MAX_TRICAP);
              break;

              case s_Style_Cap_Height:
                if (slot)
                  set_style_limited (diag, restyle_LINETRICAPHEI,
                      draw_readtricapmenu (slot, mSelTriCapHei),
                      MIN_TRICAP, MAX_TRICAP);
              break;
            }
          break;

          case s_Style_Winding:
            set_style (diag, restyle_LINEWINDING, linewindingvalue [slot]);
          break;

          case s_Style_Typeface:
          { int int_hit [10], i, fontref;
            font fonth;

            ftracef5 ("decoding menu with hits %d %d %d %d %d\n",
                o_hit [0], o_hit [1], o_hit [2], o_hit [3], o_hit [4]);

            for (i = 0; o_hit [i] != '\0'; i++)
              int_hit [i] = o_hit [i] - 1;
            int_hit [i] = -1;

            /*decode the menu entry*/
            if (int_hit [2] == 0)
              /*System font hit*/
              fontref = 0;
            else
            { char *this_font = NULL, *name;

              if (wimpt_complain (font_decodemenu (Font_Menu_Ptr,
                  &int_hit [2], &this_font)) != NULL)
                break;

              ftracef1 ("Font found is %s\n", this_font);
              /*Strip off the garbage, if any*/
              if ((name = strstr (this_font, "\\F")) != NULL)
                name += 2; /*skip over the \F*/
              else
                name = this_font;

              /*Find the terminator - font identifier stops at first blank
                or '\\'*/
              name [strcspn (name, " \\")] = '\0';
              ftracef1 ("identifier is %s\n", name);

              err = font_find (name, 1, 1, 0, 0, &fonth);
              if (err) {
                (free) (this_font);
                break;
              }
              font_lose (fonth);

              /*make sure it's in the fontcat*/
              fontref = draw_menu_addfonttypeentry (name);

              (free) (this_font);
            }

            /*set the text to that font*/
            set_style (diag, restyle_FONTFACE, fontref);

            #if TRACE
               /*Dump the fontcat here, for fun:*/
               ftracef0 ("fontcat now contains ...\n");
               for (i = 1; i < draw_fontcat.list_size; i++)
                 ftracef1 ("%s\n", draw_fontcat.name [i]);
               ftracef0 ("... end\n");
            #endif
          }
          break;

          case s_Style_Typesize:
            size = draw_readfontsizemenu (slot, mSelFontsize);
            set_style_limited (diag, restyle_FONTSIZE,
                size, MIN_FONTSIZE, MAX_FONTSIZE);
          break;

          case s_Style_Typeheight:
            set_style_limited (diag, restyle_FONTSIZEY,
                draw_readfontsizemenu (slot, mSelFontheight),
                MIN_FONTSIZE, MAX_FONTSIZE);
          break;

          case s_Style_Textcolour:
            change_colour (diag, restyle_FONTCOLOUR,
                (dboxtcol_colour *) &style.text_data.textcolour,
                TRUE, "MenuCl4");
          break;

          case s_Style_Background:
            change_colour (diag, restyle_FONTBACKGROUND,
                (dboxtcol_colour *) &style.text_data.background,
                draw_fonts_blend, "MenuCl5");
          break;
        }
      break;
      }

      case s_Enter: /* entermode */
        do_enter (*hit, diag);
      break;

      case s_Select: /* selectmode */
        do_select (1, *hit, hit+1, diag, vuue);
      break;

      case s_Transform:
        do_select (2, *hit, hit+1, diag, vuue);
      break;

      case s_Zoom: /* zoomfactor */
        if (*hit)
        { zoomchangestr newzoom;

          newzoom.diag = diag;
          newzoom.view = vuue;
          newzoom.zoom = vuue->zoom;

          ftracef0 ("draw_menu_proc: calling magnify_select\n");
          magnify_select (&newzoom.zoom.mul, &newzoom.zoom.div,
                           MAXZOOMFACTOR, MAXZOOMFACTOR,
                           draw_action_zoom, (void*)&newzoom);
          ftracef0 ("draw_menu_proc: returned from magnify_select\n");
        }
      break;

      case s_Grid: /* grid */
      { BOOL redrawGrid = FALSE;
        int displ = vuue->flags.show;

        switch (*hit++)
        { case s_Grid_Show:
          case 0:
            if (displ) draw_displ_eor_grid (vuue);
            vuue->flags.show ^= 1;
            draw_current_options.grid.o [2] = vuue->flags.show;
            redrawGrid = TRUE;
          break;

          case s_Grid_Lock:
            vuue->flags.lock ^= 1;
            draw_displ_redraw_one_title (vuue);
            draw_current_options.grid.o [3] = vuue->flags.lock;
          break;

          case s_Grid_Auto:
            if (displ) draw_displ_eor_grid (vuue);
            vuue->flags.autoadj ^= 1;
            draw_current_options.grid.o [1] = vuue->flags.autoadj;
            redrawGrid = TRUE;
          break;

          case s_Grid_Colour:
            if (displ) draw_displ_eor_grid (vuue);
            if (*hit > 0) vuue->gridcolour = *hit - 1;
            redrawGrid = TRUE;
          break;

          case s_Grid_Inch:
          case s_Grid_InchY:
          case s_Grid_Cm:
          case s_Grid_CmY:
          { int topHit = *(hit - 1);
            int yonly = topHit == s_Grid_InchY || topHit == s_Grid_CmY;
            int size =
              topHit == s_Grid_Inch || topHit == s_Grid_InchY?
                grid_Inch:
                grid_Cm;
            int xy, setFrom;

            if (displ) draw_displ_eor_grid (vuue);

            /* A faintly silly loop. It happens either once or twice only */
            for (xy = setFrom = yonly? 1: 0; xy <= 1; xy++)
            { if (xy == 0)
                if (size == grid_Inch)
                  vuue->flags.xinch = 1, vuue->flags.xcm   = 0;
                else
                  vuue->flags.xinch = 0, vuue->flags.xcm   = 1;
              else
                if (size == grid_Inch)
                  vuue->flags.yinch = 1, vuue->flags.ycm   = 0;
                else
                  vuue->flags.yinch = 0, vuue->flags.ycm   = 1;

              if (*hit >= grid_base [size])
              { double min, max;

                if (sscanf (grid_buffer [setFrom] [size] [0],
                    "%lf", &vuue->gridunit [size].space [xy]) < 1)
                  vuue->gridunit [size].space [xy] = 0;
                if (sscanf (grid_buffer [setFrom] [size] [1],
                    "%d", &vuue->gridunit [size].divide [xy]) < 1)
                  vuue->gridunit [size].divide [xy] = 0;

                /* Make some sensible defaults */
                #if 0
                if (vuue->gridunit [size].space [xy] == 0.0)
                  vuue->gridunit [size].space [xy] = 1.0;
                #endif

                /*Better. Major and minor division distance must be between
                  1 pixel and the screen width. Use y sizes for both.*/
                if (vuue->gridunit [size].divide [xy] == 0)
                  vuue->gridunit [size].divide [xy] = 1;

                /* Take account of max zoom factor (8:1) when calculating min. */
                if (size == grid_Inch)
                  min = (double) draw_currentmode.pixsizey/
                      (double) (dbc_OneInch << 3),
                  max = (double) draw_currentmode.y_wind_limit/
                      (double) dbc_OneInch;
                else
                  min = (double) draw_currentmode.pixsizey/
                      (double) (dbc_OneCm << 3),
                  max = (double) draw_currentmode.y_wind_limit/
                      (double) dbc_OneCm;

                if (vuue->gridunit [size].space [xy] < min)
                  vuue->gridunit [size].space [xy] = min;
                if (vuue->gridunit [size].space [xy] > max)
                  vuue->gridunit [size].space [xy] = max;

                if (vuue->gridunit [size].space [xy]/
                    vuue->gridunit [size].divide [xy] < min)
                  vuue->gridunit [size].divide [xy] =
                      (int) (vuue->gridunit [size].space [xy]/min);
                if (vuue->gridunit [size].space [xy]/
                    vuue->gridunit [size].divide [xy] > max)
                  vuue->gridunit [size].divide [xy] =
                      (int) (vuue->gridunit [size].space [xy]/max);
              }
              else if (*hit > 0)
              { vuue->gridunit [size].space [xy] =
                              gridSpace [size] [*hit - 1];
                vuue->gridunit [size].divide [xy] =
                              gridDivide [size] [*hit - 1];
              }

              if (!yonly)
              { draw_current_options.grid.space =
                  vuue->gridunit [size].space [xy];
                draw_current_options.grid.divide =
                  vuue->gridunit [size].divide [xy];
                draw_current_options.grid.o [4] =
                  size == grid_Cm;
              }
            }

            redrawGrid = TRUE;
          }
          break;

          case s_Grid_Rect:
            if (displ) draw_displ_eor_grid (vuue);
            vuue->flags.rect = 1;
            vuue->flags.iso  = 0;
            redrawGrid = TRUE;
            draw_current_options.grid.o [0] = FALSE;
          break;

          case s_Grid_Iso:
            if (displ) draw_displ_eor_grid (vuue);
            vuue->flags.iso  = 1;
            vuue->flags.rect = 0;
            redrawGrid = TRUE;
            draw_current_options.grid.o [0] = TRUE;
          break;
        }

        if (redrawGrid)
        { draw_grid_setstate (vuue);
          if (vuue->flags.show) draw_displ_eor_grid (vuue);
        }
      }
      break;

      case s_Toolbox:
        draw_menu_toolbox_toggle (vuue);
        draw_current_options.toolbox = vuue->flags.showpane;
      break;
    }
  }

  /* changing system 'font size' or drawing grid crosses alters */
  /* VDU5 character size, so restore normal values              */
  draw_reset_gchar ();

  wimpt_complain (err);    /* Report any errors */

  /* Look if options changed and update Draw$Options if needed */
  if (memcmp (&draw_current_options, &old_options, sizeof (draw_options)) != 0)
    draw_set_dollar_options ();
    
  ftracef0 ("draw_menu_proc: ]\n");
}

/*------------------------------------------------------------------------*/
/* Kill all menus, if closing specified window */
void draw_menu_kill (wimp_w window)

{ ftracef0 ("draw_menu_kill: [\n");

  if (window == main_window)
  { wimpt_noerr (wimp_create_menu ((wimp_menustr *)-1, 0, 0));
    main_window = -1;
  }
  ftracef0 ("draw_menu_kill: ]\n");

}

/*------------------------------------------------------------------------*/
/* Key processing */

static os_error *draw_menu_movecursor (int dx, int dy) /*dx, dy in dBcords*/

{ os_error      *err;
  wimp_mousestr mouse;
  char          block [5];
  int           x, y;

  if (err = wimp_get_point_info (&mouse), !err)
  { x = mouse.x + (dx >> 8);
    y = mouse.y + (dy >> 8);

    block [0] = 3;
    block [1] = x; block [2] = x>>8;
    block [3] = y; block [4] = y>>8;

    err = os_word (0x15, &block);
  }

  return (err);
}

void draw_menu_processkeys (diagrec *diag, viewrec *vuue, int key)

{ BOOL edit = (diag->misc->mainstate == state_edit);
  draw_displ_scalefactor = vuue->zoomfactor;
  ftracef0 ("draw_menu_processkeys: [\n");

  /* Kill off the menu. This avoids it getting out of step */
  wimpt_noerr (wimp_create_menu ((wimp_menustr *)-1, 0, 0));

  /* Take action depending on key and state */
  switch (key)
  { case akbd_PrintK: /* Print */
      { int copies;

        /* Set the caret position, so dbox is in a reasonable position */
        draw_get_focus ();

        draw_menu_infoaboutprinter (&copies);

        /* Return the caret to where it was */
        draw_displ_showcaret_if_up (diag);

        if (copies > 0)
          wimpt_complain (draw_print_queue (diag, copies));
      }
    break;

    /*F1 to be used for !Help, so not used here. JRC 24 Jan 1990.
      Reinstated 2 Oct 1990*/
    case akbd_Fn + 1:                             /* Show/hide grid */
      if (vuue->flags.show) draw_displ_eor_grid (vuue);
      vuue->flags.show ^= 1;
      draw_current_options.grid.o [2] = vuue->flags.show;
      draw_grid_setstate (vuue);
      if (vuue->flags.show) draw_displ_eor_grid (vuue);
    break;

    case akbd_Fn + akbd_Sh  + 1:                  /* Lock/unlock grid */
      vuue->flags.lock ^= 1;
      draw_displ_redraw_one_title (vuue);
      draw_current_options.grid.o [3] = vuue->flags.lock;
    break;

    case akbd_Fn + akbd_Ctl + 1:                  /* Toolbox on/off */
      draw_menu_toolbox_toggle (vuue);
      draw_current_options.toolbox = vuue->flags.showpane;
    break;

    case akbd_Fn + 2:                             /* Load named file */
      do_load (diag, NULL, TRUE);
    break;

    case akbd_Fn + akbd_Sh + 2:                   /* Insert named file */
      do_load (diag, vuue, FALSE);
    break;

    case akbd_Fn + akbd_Ctl + 2:                  /* Close window */
      draw_paper_close (vuue);
    break;

    case akbd_Fn + 3:                             /* Save file */
      do_save (diag, save_File, TRUE, FALSE);
    break;

    case akbd_Fn + akbd_Sh  + 3:                  /* Save selection */
      do_save (diag, save_Selection, TRUE, FALSE);
    break;

    case akbd_Fn + akbd_Ctl + 3:                  /* Save sprites */
      /*It's the amazing double-duty function key shortcut! J R C 21st Sep 1994*/
      read_select (diag);

      if (may_save (diag) & save_Sprite)
        do_save (diag, save_Sprite, TRUE, FALSE);
      else if (may_save (diag) & save_JPEG)
        do_save (diag, save_JPEG, TRUE, FALSE);
    break;

    case akbd_Fn + akbd_Ctl + akbd_Sh + 3:        /* Save text area */
      do_save (diag, save_TextArea, TRUE, FALSE);
    break;

    case akbd_PrintK | akbd_Ctl | akbd_Sh: /* shift-ctrl-Print */
      do_save (diag, save_PostScript, TRUE, FALSE);
    break;

    case akbd_Fn + 4:                             /* Group objects */
    case 7  /* G */:
      do_select (1, s_Select_Group, NULL, diag, vuue);
    break;

    case akbd_Fn + akbd_Sh + 4:                   /* Ungroup objects */
    case 21 /* U */:
      do_select (1, s_Select_Ungroup, NULL, diag, vuue);
    break;

    case akbd_Fn + akbd_Ctl + 4:                  /* Bring group to front */
    case 6  /* F */:
      do_select (1, s_Select_Front, NULL, diag, vuue);
    break;

    case akbd_Fn + akbd_Ctl + akbd_Sh + 4:        /* Send group to back */
    case 2  /* B */:
      do_select (1, s_Select_Back, NULL, diag, vuue);
    break;

    case akbd_Fn + 5:               /* Select all or Numeric point entry */
      if (edit)
      { draw_get_focus ();
        do_edit (s_Edit_Coord, diag, vuue);
        draw_displ_showcaret_if_up (diag);
      }
      else
        do_select (1, s_Select_All, NULL, diag, vuue);
    break;

    case akbd_Fn + akbd_Sh + 5:                   /* Snap to grid */
    case 19 /* S */:
      if (edit) do_edit (s_Edit_Snap,  diag, vuue);
      else      do_select (1, s_Select_Snap, NULL, diag, vuue);
    break;

    case akbd_Fn + akbd_Ctl + 5:                  /* Justify */
    case 10 /* J */:
      do_select (1, s_Select_Justify, NULL, diag, vuue);
    break;

    case akbd_Fn + 6:                             /* Select mode */
      if (!draw_select_owns (diag))
        draw_action_changestate (diag, state_sel, 0, 0, TRUE);
    break;

    case akbd_Fn + akbd_Sh + 6:
    case 26 /* Z */:                              /* Clear selection */
      do_select (1, s_Select_Clear, NULL, diag, vuue);
    break;

    case akbd_Fn + akbd_Ctl + 6:                  /* Edit */
    case 5  /* E */:
      do_select (1, s_Select_Edit, NULL, diag, vuue);
    break;

    case akbd_Fn + 7:
    case akbd_CopyK:
    case 3 /* C */:                        /* Copy selection or Add point */
      if (edit) do_edit (s_Edit_Add,  diag, vuue);
      else      do_select (1, s_Select_Copy, NULL, diag, vuue);
    break;

    case akbd_Fn + 8:                             /* Undo */
    { BOOL dummy;
      if (draw_undo_may_undo (diag, &dummy))
        draw_undo_undo (diag);
    }
    break;

    case akbd_Fn + akbd_Sh + 8:
    case 11 /* K */:                /* Delete selection or Delete segment */
      if (edit) do_edit (s_Edit_Delete, diag, vuue);
      else      do_select (1, s_Select_Delete, NULL, diag, vuue);
    break;

    case akbd_Fn + 9:                             /* Redo */
    { BOOL mayredo;
      draw_undo_may_undo (diag, &mayredo);
      if (mayredo)
        draw_undo_redo (diag);
    }
    break;

    /*case akbd_Fn + akbd_Sh + 9:*/               /* Enter text */
    case akbd_Fn + akbd_Ctl + 7:
    case akbd_TabK:
      do_enter (s_Enter_Text, diag);
    break;

    /*case akbd_Fn10:*/                  /* Enter line or Change to line */
    case akbd_Fn + akbd_Ctl + 9:
      if (edit)
        do_edit (s_Edit_Line,  diag, vuue);
      else
        do_enter (s_Enter_Line, diag);
    break;

    /*case akbd_Fn10 + akbd_Sh:*/      /* Enter curve or Change to curve */
    case akbd_Fn + akbd_Ctl + 8:
      if (edit)
        do_edit (s_Edit_Curve,  diag, vuue);
      else
        do_enter (s_Enter_Curve, diag);
    break;

    #if 0 /*All definitions for F10, F11 removed. JRC 22 Nov '89*/
      case akbd_Fn10 + akbd_Ctl:           /* Enter rectangle */
        do_enter (s_Enter_Rectangle, diag);
      break;

      case akbd_Fn10 + akbd_Ctl + akbd_Sh: /* Enter ellipse */
        do_enter (s_Enter_Ellipse, diag);
      break;

      case akbd_Fn11:                  /* Enter move or Change to move */
        if (edit)  do_edit (s_Edit_Move,  diag, vuue);
        else       do_enter (s_Enter_Move, diag);
      break;

      case akbd_Fn11 + akbd_Sh:        /* Toggle autoclose or open path */
        if (edit)  do_edit (s_Edit_Open, diag, vuue);
        else       do_enter (s_Enter_Autoclose, diag);
      break;

      case akbd_Fn11 + akbd_Ctl:           /* Close path */
        if (edit)  do_edit (s_Edit_Close, diag, vuue);
      break;
    #endif

    case 1  /*control-A*/:                       /* Select all */
      do_select (1, s_Select_All, NULL, diag, vuue);
    break;

    case 4 /*control-D*/:                        /* Zoom 1:1 */
      draw_action_zoom_alter (vuue, 0);
    break;

    case 8 /*control-H*/:                        /* Delete character/line */
    case 127 /* Delete */:
      switch (diag->misc->mainstate)
      { case state_path:
        case state_rect:
        case state_elli:
        case state_text:
          draw_enter_delete (diag);
        break;

        default: /* Do same as ctrl/X and s/f8 */
          if (edit) do_edit (s_Edit_Delete,  diag, vuue);
          else      do_select (1, s_Select_Delete, NULL, diag, vuue);
      }
    break;

    case 12 /*control-L*/:                       /* Zoom lock 2 */
      vuue->flags.zoomlock ^= 1;
    break;

    case 13 /* Return */:                  /* Finish action */
      /*If entering text, fake a 'select' on the line below, this will
        finish this line and start another*/
      if (diag->misc->substate == state_text_caret ||
          diag->misc->substate == state_text_char)
      { draw_objcoord coord;

        draw_obj_readcoord (diag, &coord);
        coord.y -= draw_displ_lineheight (diag);

        wimpt_complain (draw_enter_select (diag, vuue, &coord));
      }
      else
        /* Else complete any path etc */
        wimpt_complain (draw_enter_complete (diag));
    break;

    case 17 /*control-Q*/:                         /* Zoom in */
      draw_action_zoom_alter (vuue, -1);
    break;

    case 18 /*control-R*/:                         /* Restore zoom */
    { zoomchangestr newzoom;

      newzoom.diag = diag;
      newzoom.view = vuue;
      newzoom.zoom = vuue->lastzoom;
      draw_action_zoom (&newzoom);
    }
    break;

    case 23 /*control-W*/:                         /* Zoom out */
      draw_action_zoom_alter (vuue, 1);
    break;

    case 27 /* Escape */:                    /* Abandon action */
      draw_action_abandon (diag);
    break;

    #if TRACE
      case 28 /*control-\*/:
        *(int *) -4 = 0; /*address exception!*/
      break;
    #endif

    case akbd_LeftK:                         /* Move point left */
      wimpt_complain (draw_menu_movecursor (-draw_currentmode.pixsizex, 0));
    break;

    case akbd_RightK:                        /* Move point left */
      wimpt_complain (draw_menu_movecursor (draw_currentmode.pixsizex, 0));
    break;

    case akbd_UpK:                           /* Move point left */
      wimpt_complain (draw_menu_movecursor (0, draw_currentmode.pixsizey));
    break;

    case akbd_DownK:                         /* Move point left */
      wimpt_complain (draw_menu_movecursor (0, -draw_currentmode.pixsizey));
    break;

    default:
      if (key >= ' ' && key <= 255)
      { ftracef2 ("draw_processkeys: key: %d; substate: %d\n",
            key, diag->misc->substate);
        if (diag->misc->substate == state_text_caret ||
            diag->misc->substate == state_text_char)
        { if (!wimpt_complain (draw_obj_checkspace (diag, 4)))
          { draw_obj_addtext_char (diag, key);
            diag->misc->substate = state_text_char;
            draw_displ_eor_skeleton (diag); /* paint the text */
          }
        }
      }
      else
        /*not a character or a Draw control key, so give it back*/
        wimp_processkey (key);
    break;
  }

  ftracef0 ("draw_menu_processkeys: ]\n");
}

void draw_menu_entry_option (draw_state newstate, int curved, int closed)

/*Called back from draw_action_changestate whenever the state changes.
   Has no effect if the state is not legal.*/

{ draw_options *opt = &draw_current_options;
  ftracef0 ("draw_menu_entry_option: [\n");

  opt->mode.line = opt->mode.cline = opt->mode.curve = opt->mode.ccurve =
     opt->mode.rect = opt->mode.elli = opt->mode.text = opt->mode.select =
     0;

  switch (newstate)
  { case state_path:
      opt->mode.line = opt->mode.cline = opt->mode.curve =
         opt->mode.ccurve = opt->mode.rect = opt->mode.elli =
         opt->mode.text = opt->mode.select = 0;

      if (curved)
        if (closed)
          opt->mode.ccurve = 1;
        else
          opt->mode.curve = 1;
      else
        if (closed)
          opt->mode.cline = 1;
        else
          opt->mode.line = 1;
    break;

    case state_text:
      opt->mode.line = opt->mode.cline = opt->mode.curve =
         opt->mode.ccurve = opt->mode.rect = opt->mode.elli =
         opt->mode.select = 0;

      opt->mode.text = 1;
    break;

    case state_sel:
      opt->mode.line = opt->mode.cline = opt->mode.curve =
         opt->mode.ccurve = opt->mode.rect = opt->mode.elli =
         opt->mode.text = 0;

      opt->mode.select = 1;
    break;

    case state_rect:
      opt->mode.line = opt->mode.cline = opt->mode.curve =
         opt->mode.ccurve = opt->mode.elli = opt->mode.text =
         opt->mode.select = 0;

      opt->mode.rect = 1;
    break;

    case state_elli:
      opt->mode.line = opt->mode.cline = opt->mode.curve =
         opt->mode.ccurve = opt->mode.rect = opt->mode.text =
         opt->mode.select = 0;

      opt->mode.elli = 1;
    break;
  }

  /* Must have changed the mode option */
  draw_set_dollar_options ();

  ftracef0 ("draw_menu_entry_option: ]\n");
}
