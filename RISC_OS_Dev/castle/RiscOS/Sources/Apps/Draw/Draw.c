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
/*-> c.Draw
 *
 * Main file for Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.17
 * History: 0.10 - 12 June 1989 - header added. Old code weeded.
 *                                converted to use Drawmod for paths
 *                 16 June 1989 - upgrade to use msgs for messages
 *          0.11 - 19 June 1989 - DrawObjects extracted
 *                                broke down big functions
 *                                added keystroke actions
 *                                claim input focus on more actions
 *          0.12 - 23 June 1989 - bug 1501 fixed
 *                                use heap (so we can avoid some mallocs)
 *          0.13 - 29 June 1989 - shift/button actions
 *          0.14 - 11 July 1989 - auto scrolling. Zooms moved out.
 *                 12 July 1989 - Draw$Options added
 *          0.15 - 18 July 1989 - undo added
 *                  7 Aug  1989 - Undo buffer size option
 *          0.16 - 25 Aug  1989 - more work on paper limits
 *          0.17 - 06 Sept 1989 - make heap non-compacting
 *          0.79 - 13 Jan  1992 - set fixed size stack to 6K
 *   OSS    0.83 - 12 Mar  1992 - Split in half to allow name translation as
 *                                part of fix to RP-0716.
 *   OSS    0.84 - 13 Mar  1992 - Get it right this time.
 */

#include <assert.h>
#include <ctype.h>
#include "kernel.h"
#include <limits.h>
#include <locale.h>
#include <math.h>
#include <signal.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <swis.h>
#include "Global/Variables.h"
#include "Global/FileTypes.h"

#include "os.h"
#include "akbd.h"
#include "bbc.h"
#include "flex.h"
#include "heap.h"
#include "menu.h"
#include "pointer.h"
#include "res.h"
#include "resspr.h"
#include "wimp.h"
#include "wimpt.h"
#include "win.h"
#include "werr.h"
#include "baricon.h"
#include "template.h"
#include "visdelay.h"
#include "msgs.h"
#include "msgtrans.h"
#include "dboxquery.h"
#include "xferrecv.h"
#include "saveas.h"
#include "bezierarc.h"
#include "help.h"
#include "drawmod.h"
#include "jpeg.h"
#include "dbox.h"
#include "font.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawAction.h"
#include "DrawDispl.h"
#include "DrawDXF.h"
#include "DrawEdit.h"
#include "DrawEnter.h"
#include "DrawFileIO.h"
#include "DrawGrid.h"
#include "DrawHelp.h"
#include "DrawMenu.h"
#include "DrawObject.h"
#include "DrawPrint.h"
#include "DrawSelect.h"
#include "DrawTrans.h"
#include "DrawUndo.h"

#define EMPTY(s) ((s) [0] == '\0')
#define CLEAR(s) ((s) [0] =  '\0')

#define SIG_LIMIT 11 /*largest signal number + 1*/

#undef  FREEZE_STACK
#define FREEZE_STACK 1

extern _kernel_ExtendProc flex_budge;

/*External variables*/
fontcatstr draw_fontcat = /*JRC 6 Aug 1990*/
  { 0 /*menu size - not used 12 April 1991*/,
    1 /*system font present*/
    /*, ...*/
  };

currentmodestr draw_currentmode; /*= {15, 1, 2, 0x200, 0x400 };*/
coloursstr     draw_colours; /*initialised from template file*/
diagrec        *draw_startdiagchain = NULL;

draw_objcoord draw_stdcircpoints [13];
static draw_objcoord zero = {0, 0 };

static int modevarlist [] =
{ bbc_GCharSizeX, bbc_GCharSizeY, bbc_GCharSpaceX, bbc_GCharSpaceY,
  bbc_NColour,    bbc_XEigFactor, bbc_YEigFactor,
  -1
};

scale_str draw_scale_cb;
rotat_str draw_rotate_cb;
captu_str draw_capture_cb;
trans_str draw_translate_cb;

/*Data block for recording the palette - set up on a mode or palette change*/
wimp_palettestr draw_palette;

/*Handle of the window that the pointer is in: -1 if none*/
static diagrec *pointer_diag = NULL;

/*N.B. We have chosen 180 graphics units per inch so for A4 paper,*/
/*exact work area limits are:*/
/*A4 portrait (0,0, 1488,2104)              ie  8.25"w x 11.75"h*/
/*A4 landscape (0,0, 2104,1488)             ie 11.75"w x  8.25"h*/

#define A4portrait_scroll    0, 0 /*2104*/
#define A4portrait_extent   {0, 0, 1488, 2104}
#define A4landscape_scroll   0, 1488 /*was 0???*/
#define A4landscape_extent  {0, 0, 2104, 1488}

static
  struct
  { wimp_wind paper;
    wimp_icon colouricons [10];
  }
  blank_view =
  { { {300, 600, 800, 1000},                     /*work area coordinates*/
      A4landscape_scroll,                        /*scroll bar positions*/
      (wimp_w) -1,                               /*in front of all windows*/
      (wimp_wflags) (wimp_WMOVEABLE | wimp_WNEW | wimp_WBACK |
          wimp_WQUIT | wimp_WTITLE | wimp_WTOGGLE |
          wimp_WSIZE | wimp_WVSCR | wimp_WHSCR),
      {0xE,0xD,0x7, Window_WORKBG, 0x4,0xD,0xC,0x0}, /*colours*/
      A4landscape_extent,                            /*work area extent*/
      (wimp_iconflags) (wimp_ITEXT | wimp_IHCENTRE | wimp_IVCENTRE |   /*title icon flags*/
      wimp_INDIRECT | wimp_IFORECOL*1 | wimp_IBACKCOL*0),
      (wimp_iconflags) (wimp_IBTYPE*10),             /*default button type*/
      (void *) 0,                                    /*sprite area pointer*/
      0x00010001,                                    /*minimum window size*/
      {'D','i','a','g',' ',' ','V','i','e','w',' ',0x0},       /*title*/
      0,                                             /*number of icons*/
    }
  };

static struct
{ wimp_wind pane;
  wimp_icon toolcons [15];
} blank_pane;

/*Block to contain the initial settings for the blank view and pane, and
   the shift so far*/
static struct
{ int papery0, papery1;
  int paney0,  paney1;
  int yshift;           /*Positive downwards*/
} blank_position;

static
  draw_options
    initial_options =
    { {Paper_A4, (paperoptions_typ) 0},
      {1.0, 2, {0, 0, 0, 0, 1}},
      {1, 1, 0},
      TRUE,
      {0, 1, 0, 0, 0, 0, 0, 0},
      5000
    };

draw_options draw_current_options;

/*The directory we started up from (<Draw$Dir> variable might not be the
  right place because it is changed if another Draw starts up)*/
static char Draw_Dir [FILENAMEMAX];
#define MAX_OPTIONS 80

/*Raw bounding box, used in routines which form bounds*/
draw_bboxtyp draw_big_box = {INT_MAX, INT_MAX, INT_MIN, INT_MIN };

#if TRACE
  #if FREEZE_STACK
  static int Dont_Budge (int n, void **a)

  { ftracef0 ("NOT BUDGING FLEX NOW!!!\n");
    n = n, a = a;
    return 0;
  }
  #else
  static int Do_Budge (int n, void **a)

  { ftracef0 ("BUDGING FLEX NOW!!!\n");
    return flex_budge (n, a);
  }
  #endif
#endif

BOOL draw_jpegs_rotate = TRUE;
BOOL draw_fonts_blend = TRUE;

static void cache_currentmodevars (void)

{ int junk;

  ftracef0 ("cache_currentmodevars\n");
  bbc_vduvars (modevarlist, &draw_currentmode.gcharsizex);

  draw_currentmode.gcharaltered = 0;
  draw_currentmode.pixx     =     1 << draw_currentmode.xeigfactor;
  draw_currentmode.pixy     =     1 << draw_currentmode.yeigfactor;
  draw_currentmode.pixsizex = 0x100 << draw_currentmode.xeigfactor;
  draw_currentmode.pixsizey = 0x100 << draw_currentmode.yeigfactor;

  draw_currentmode.x_wind_limit = bbc_vduvar (bbc_XWindLimit) + 1 <<
      draw_currentmode.xeigfactor << 8;
  draw_currentmode.y_wind_limit = bbc_vduvar (bbc_YWindLimit) + 1 <<
      draw_currentmode.yeigfactor << 8;

  (void) os_byte (135, &junk, &draw_currentmode.mode);
  ftracef1 ("ncolour %u\n", draw_currentmode.ncolour);
}

/*Routines to dump the whole of a diagram - what a wheeze.*/
#if TRACE
  static void *trace_objects (draw_objptr start, size_t size, int indent)

  { draw_objptr obj_ptr, ptr;
    int i;
    size_t obj_size;
    draw_path_tagtype tag;

    ftracef (__FILE__, __LINE__, "trace_objects: start: 0x%X, "
        "size: %d; indent: %d\n",
        start.bytep, size, indent);

    for (i = 0; i < indent; i++) ftracef (NULL, 0, "  ");

    for
    ( ptr = start;
      ptr.bytep < start.bytep + size;
      ptr.bytep += ptr.objhdrp->size
    )
    { if ((obj_size = ptr.objhdrp->size) == 0)
      { ftracef (NULL, 0, "  ***Zero sized object***\n");
        return (void *) 1;
      }

      switch (ptr.objhdrp->tag)
      { default:
          ftracef (NULL, 0, "  ***Unrecognised object type: %d***\n",
              ptr.objhdrp->tag);
        return (void *) 1;

        case draw_OBJFONTLIST:
          ftracef (NULL, 0, "  Font list (size %d)\n", obj_size);
        break;

        case draw_OBJTEXT:
          ftracef (NULL, 0, "  Text line (size %d): \"%s\"\n",
              obj_size, ptr.textp->text);
        break;

        case draw_OBJPATH:
          { drawmod_pathelemptr pathptr = draw_obj_pathstart (ptr);

            ftracef (NULL, 0, "  Path (size %d):", obj_size);
            do
            { if (pathptr.bytep >= start.bytep + size)
              { ftracef (NULL, 0, " ***incomplete path***");
                return (void *) 1;
              }

              switch (tag = pathptr.end->tag)
              { case path_term:
                  ftracef (NULL, 0, " term");
                break;

                case path_ptr:
                  ftracef (NULL, 0, " ptr at 0x%X", pathptr.ptr->ptr);
                  pathptr.ptr++;
                break;

                case path_move_2:
                  ftracef (NULL, 0, " move_2 to (%d, %d)",
                      pathptr.move2->x,  pathptr.move2->y);
                  pathptr.move2++;
                break;

                case path_move_3:
                  ftracef (NULL, 0, " move_3 to (%d, %d)",
                      pathptr.move3->x, pathptr.move3->y);
                  pathptr.move3++;
                break;

                case path_closegap:
                  ftracef (NULL, 0, " closegap");
                  pathptr.closegap++;
                break;

                case path_closeline:
                  ftracef (NULL, 0, " closeline");
                  pathptr.closeline++;
                break;

                case path_bezier:
                  ftracef
                  ( NULL, 0,
                    " bezier via (%d, %d) and (%d, %d) to (%d, %d)",
                    pathptr.bezier->x1, pathptr.bezier->y1,
                    pathptr.bezier->x2, pathptr.bezier->y2,
                    pathptr.bezier->x3, pathptr.bezier->y3
                  );
                  pathptr.bezier++;
                break;

                case path_gapto:
                  ftracef (NULL, 0, " gapto (%d, %d)",
                      pathptr.gapto->x, pathptr.gapto->y);
                  pathptr.gapto++;
                break;

                case path_lineto:
                  ftracef (NULL, 0, " lineto (%d, %d)",
                      pathptr.lineto->x, pathptr.lineto->y);
                  pathptr.lineto++;
                break;
              }
            }
            while (tag != path_term);
            ftracef (NULL, 0, "\n");
          }
        break;

        case draw_OBJSPRITE:
          ftracef (NULL, 0, "  Sprite (size %d)\n", obj_size);
        break;

        case draw_OBJGROUP:
          ftracef (NULL, 0, "  Group (size %d):\n", obj_size);
          if
          ( trace_objects
            ( (obj_ptr.bytep = ptr.bytep + sizeof (draw_groustr), obj_ptr),
              ptr.groupp->size - sizeof (draw_groustr),
              indent + 1
            ) != NULL
          )
            return (void *) 1;

        case draw_OBJTAGG:
          ftracef (NULL, 0, "  Tagged object (size %d)\n", obj_size);
        break;

        case draw_OBJTEXTAREA:
          ftracef (NULL, 0, "  Text area (size %d)\n", obj_size);
        break;

        case draw_OBJTEXTCOL:
          ftracef (NULL, 0, "  Text column (size %d)\n", obj_size);
        break;

        case draw_OBJTRFMTEXT:
          ftracef (NULL, 0, "  Transformed text line (size %d): \"%s\"\n",
              obj_size, ptr.trfmtextp->text);
        break;

        case draw_OBJTRFMSPRITE:
          ftracef (NULL, 0, "  Transformed sprite (size %d)\n", obj_size);
        break;

        case draw_OBJJPEG:
          ftracef (NULL, 0, "  JPEG (size %d)\n", obj_size);
        break;
      }
    }

    return NULL;
  }
#endif
#if TRACE
/*-------------------------------------------------------------------*/
void draw_trace_db (diagrec *diag)

{ draw_objptr obj_ptr;

  ftracef
  ( NULL, 0,
    "Current diagram: 0x%X; next: 0x%X; prev: 0x%X; misc at 0x%X\n",
    diag, diag->nextdiag, diag->prevdiag, diag->misc
  );

  ftracef
  ( NULL, 0,
    "Misc\n"
    " ( Solid: %d ~ %d; ghost: %d ~ %d; stack lt: %d; buff lt: %d\n",
    diag->misc->solidstart, diag->misc->solidlimit,
    diag->misc->ghoststart, diag->misc->ghostlimit,
    diag->misc->stacklimit, diag->misc->bufferlimit
  );

  ftracef
  ( NULL, 0,
    "  Main state: (draw_state) %d; substate: (draw_state) %d; "
        "options:%s%s%s\n",
    diag->misc->mainstate, diag->misc->substate,
    diag->misc->options.curved? " curved": "",
    diag->misc->options.closed? " closed": "",
    diag->misc->options.modified? " modified": ""
  );

  ftracef
  ( NULL, 0,
    "  paperstate: *0x%X; wantsnulls: 0x%X; path: *0x%X; font: *0x%X\n"
    "  pta_off: %d; ptb_off: %d; "
      "ptw_off: %d; ptx_off: %d; pty_off: %d; ptz_off: %d\n"
    "  ptzzz: (%d, %d); ellicentre: (%d, %d)\n"
    "  filename: %s; vuuecnt: %d\n",
    &diag->misc->paperstate, diag->misc->wantsnulls, &diag->misc->path,
      &diag->misc->font,
    diag->misc->pta_off, diag->misc->ptb_off,
      diag->misc->ptw_off, diag->misc->ptx_off, diag->misc->pty_off,
      diag->misc->ptz_off,
    diag->misc->ptzzz.x, diag->misc->ptzzz.y,
      diag->misc->ellicentre.x, diag->misc->ellicentre.y,
    diag->misc->filename, diag->misc->vuuecnt
  );

  ftracef
  ( NULL, 0,
    "  pathedit_cb:\n"
    "  ( over: (region) %d; obj_off: %d; sub_off: %d\n"
    "    fele_off: %d; pele_off: %d; cele_off: %d\n"
    "    cor_off: %d; corA_off: %d; corB_off: %d; corC_off: %d; "
      "corD_off: %d\n"
    "    changed: %c\n"
    "  )\n",
    diag->misc->pathedit_cb.over, diag->misc->pathedit_cb.obj_off,
      diag->misc->pathedit_cb.sub_off,
    diag->misc->pathedit_cb.fele_off, diag->misc->pathedit_cb.pele_off,
      diag->misc->pathedit_cb.cele_off,
    diag->misc->pathedit_cb.cor_off,
      diag->misc->pathedit_cb.corA_off, diag->misc->pathedit_cb.corB_off,
      diag->misc->pathedit_cb.corC_off, diag->misc->pathedit_cb.corD_off,
    diag->misc->pathedit_cb.changed? 'T': 'F'
  );

  ftracef (NULL, 0, "  save: *0x%X\n)\n", &diag->misc->save);

  ftracef
  ( NULL, 0,
    "paper: 0x%X; view 0x%X; undo: 0x%X\n",
    diag->paper, diag->view, diag->undo
  );

  ftracef (NULL, 0, "Solid objects:\n");
  if (trace_objects
      ((obj_ptr.bytep = diag->paper + diag->misc->solidstart + 0, obj_ptr),
      (size_t) (diag->misc->solidlimit - diag->misc->solidstart - 0), 0) !=
      NULL)
    return;

  ftracef (NULL, 0, "Ghost objects:\n");
  if
  ( trace_objects
    ( (obj_ptr.bytep = diag->paper + diag->misc->ghoststart + 0, obj_ptr),
      (size_t) (diag->misc->ghostlimit - diag->misc->ghoststart - 0),
      0
    ) != NULL
  )
    return;

  ftracef
  ( NULL, 0,
    "Stack contains %d object%s; top: %d; bottom: %d\n",
    diag->misc->bufferlimit - diag->misc->stacklimit,
    diag->misc->bufferlimit - diag->misc->stacklimit == 1? "": "s",
    *(int *) (diag->paper + diag->misc->stacklimit),
    *(int *) (diag->paper + diag->misc->bufferlimit)
  );

  ftracef (NULL, 0, "Selection is at 0x%X, containing:\n  {",
      draw_selection);
  { int i;
    for (i = 0; i < draw_selection->indx; i++)
      ftracef (NULL, 0, i == 0? "%d": ", %d", draw_selection->array [i]);
  }
  ftracef (NULL, 0, "}\n");
}
#endif

#if CATCH_SIGNALS
  static jmp_buf Buf;
  static void Signal_Handler (int signal) {longjmp (Buf, signal);}
  static void (*Saved_Handlers [SIG_LIMIT]) (int);
#endif

void draw_sort (int *a, int *b)

{ ftracef0 ("draw_sort\n");
  if (*a > *b) {int tmp = *b; *b = *a; *a = tmp;}
}

void draw_reset_gchar (void)

{ ftracef0 ("draw_reset_gchar\n");
  if (draw_currentmode.gcharaltered)
  { draw_displ_setVDU5charsize (draw_currentmode.gcharsizex,
        draw_currentmode.gcharsizey, draw_currentmode.gcharspacex,
        draw_currentmode.gcharspacey);
    draw_currentmode.gcharaltered = 0;
  }
}

/*Produce a correctly word aligned error from a messages file token*/
os_error *draw_make_oserror (const char *token)

{ static os_error block;
  /* N.B. prefix messages with #### to fake error number field */
  memcpy (&block, msgs_lookup ((char *) token), sizeof (block));
  return &block;
}

/*Make origin, typically from a wimp_openstr*/
static void make_origin (draw_objcoord *to, wimp_box *box, int *scroll)

{ ftracef0 ("make_origin\n");
  to->x = box->x0 - scroll [0];
  to->y = box->y1 - scroll [1];
}

/*Set the window extent of view, diag; based on paper size & zoom factor*/
void draw_setextent (viewrec *vuue)

{ diagrec *diag         = vuue->diag;
  wimp_w w              = vuue->w;
  draw_bboxtyp newlimit = diag->misc->paperstate.viewlimit;
  double scale          = vuue->zoomfactor;
  wimp_redrawstr blk;

  ftracef0 ("draw_setextent\n");
  /*Adjust the window extent*/
  blk.w = w;
  draw_box_scale ((draw_bboxtyp *) &blk.box, &newlimit,
      draw_draw_to_osD (scale));

  /*Window manager gets confused if the window isn't an exact number of*/
  /*pixels, this may mean that expand to full size (which works) then*/
  /*shrink may fail. The window manager thinks the window isn't full*/
  /*size and refuses to shrink it.*/
  blk.box.x0 &= ~(draw_currentmode.pixx - 1);
  blk.box.y0 &= ~(draw_currentmode.pixy - 1);
  blk.box.x1 = (blk.box.x1 + (draw_currentmode.pixx - 1)) &
      ~(draw_currentmode.pixx - 1);
  blk.box.y1 = (blk.box.y1 + (draw_currentmode.pixy - 1)) &
      ~(draw_currentmode.pixy - 1);

  wimpt_noerr (wimp_set_extent (&blk));
  ftracef4 ("extent set to (%d, %d, %d, %d)\n",
      blk.box.x0, blk.box.y0, blk.box.x1, blk.box.y1);

  /*Mark the whole window as invalid*/
  blk.w = w;
  blk.box.x0 = blk.box.y0 = -0x1fffffff;
  blk.box.x1 = blk.box.y1 =  0x1fffffff;
  wimp_force_redraw (&blk);
}

/*Change pointer to reflect state*/
static void draw_setpointer (diagrec *diag)

{ ftracef0 ("draw_setpointer\n");
  if (pointer_diag)
    switch (diag->misc->mainstate)
    { case state_path:
      case state_elli:
      case state_rect:
      { sprite_id id;
        sprite_info info;

        /* read sprite information for the crosshairs */
        id.tag    = sprite_id_name;
        id.s.name = "crosshairs";
        wimpt_noerr (sprite_readsize (resspr_area (), &id, &info));
        wimpt_noerr (pointer_set_shape (resspr_area (), &id, (info.width-1)/2, (info.height-1)/2));
      }
      break;

      default:
        pointer_reset_shape ();  /*'normal' shape*/
      break;
    }
}

static void draw_set_icon_state (wimp_w w, wimp_i i, BOOL selected)

{ ftracef0 ("draw_set_icon_state\n");
  wimpt_noerr
  ( wimp_set_icon_state
    ( w,
      i,
      selected? wimp_ISELECTED: (wimp_iconflags) 0,
      wimp_ISELECTED
    )
  );
}

/*Show diag state in toolbox pane of vuue*/
/*show = TRUE,  highlight icons*/
/*show = FALSE, unhighlight icons*/
static void draw_toolbox_showstate (diagrec *diag, viewrec *vuue, int show)

{ wimp_w pane = vuue->pw;
  draw_state mainstate = diag->misc->mainstate;
  int curved = diag->misc->options.curved;
  int closed = diag->misc->options.closed;

  ftracef3 ("draw_toolbox_showstate: diag: 0x%X; vuue: 0x%X; show: %d\n",
      diag, vuue, show);
  switch (mainstate)
  { case state_path:
      draw_set_icon_state
      ( pane,
        curved?
          (closed? tbi_curv_c: tbi_curv_o):
          (closed? tbi_line_c: tbi_line_o),
        show
      );
    break;

    case state_rect:
      draw_set_icon_state (pane, tbi_rect, show);
    break;

    case state_elli:
      draw_set_icon_state (pane, tbi_elli, show);
    break;

    case state_text:
      draw_set_icon_state (pane, tbi_text, show);
    break;

    case state_sel:
      draw_set_icon_state (pane, tbi_select, show);
    break;
  }

  /*if (FALSE)
    draw_set_icon_state (pane, tbi_move, show);*/
}

/*Show toolbox for all views in a diagram*/
void draw_toolbox_showall (diagrec *diag, int show)

{ viewrec *vuue;

  ftracef2 ("draw_toolbox_showall: diag: 0x%X; show: %d\n", diag, show);
  for (vuue = diag->view; vuue != 0; vuue = vuue->nextview)
    draw_toolbox_showstate (diag, vuue, show);
}

/*Low level caret call*/
void draw_set_caret (wimp_w w, int x, int y, int height)

{ wimp_caretstr c;

  ftracef0 ("draw_set_caret\n");
  c.w      = w;
  c.i      = -1;
  c.x      = x;
  c.y      = y;
  c.height = height;
  c.index  = 0;
  wimpt_noerr (wimp_set_caret_pos (&c));
}

/*Get the input focus, with no caret*/
void draw_get_focus (void)

{ wimp_wstate   wstate;
  int           x = 0, y = 0;

  ftracef1 ("draw_get_focus: owner 0x%X\n", draw_enter_focus_owner.diag);
  if (draw_enter_focus_owner.hand != -1)
  { wimpt_noerr (wimp_get_wind_state (draw_enter_focus_owner.hand, &wstate));
    x = wstate.o.x;
    y = wstate.o.y;
  }

  draw_set_caret (draw_enter_focus_owner.hand, x, y, 0x02000000);
}
#if 0 /*not used*/
void draw_kill_caret (void)

{ ftracef0 ("draw_kill_caret\n");
  draw_set_caret (-1, -1, -1, 0x01000010);
}
#endif
void draw_action_abandon (diagrec *diag) /*flush any object, restore screen*/

{ ftracef1 ("draw_action_abandon: diag: 0x%X\n", diag);
  switch (diag->misc->substate)
  { case state_path:
    case state_rect:
    case state_elli:
    case state_edit:
    case state_text:
    return;

    case state_path_move:
    case state_path_point1:
    case state_path_point2:
    case state_path_point3:
    case state_rect_drag:
    case state_elli_drag:
      draw_displ_eor_skeleton (diag);       /*remove construction lines*/
      draw_obj_flush (diag);
    break;

    case state_text_caret:
    case state_text_char:
    { draw_bboxtyp bbox;
      BOOL found;
      int hdroff = * (int*) (diag->paper + diag->misc->stacklimit);
      draw_objptr hdrptr;

      hdrptr.bytep = diag->paper + hdroff;

      found = draw_obj_findTextBox (hdrptr, &bbox);

      draw_obj_flush (diag);
      draw_get_focus ();       /*Kills caret but keeps focus*/

      if (found)
        draw_displ_redrawarea (diag, &bbox);
      else  /*Only happens if font manager blows up*/
        draw_displ_forceredraw (diag);
    }
    break;

    case state_sel_select:  /*dragging to select objects*/
    case state_sel_adjust:  /*dragging to adjust selection*/
    case state_sel_shift_select:  /*dragging to select objects*/
    case state_sel_shift_adjust:  /*dragging to adjust selection*/
    case state_zoom:        /*dragging zoom*/
      draw_displ_eor_capturebox (diag);
    break;

    case state_sel_trans:  /*translating selection*/
      draw_displ_eor_transboxes (diag);
    break;

    case state_sel_scale:  /*stretching selection*/
      draw_displ_eor_scaleboxes (diag);
    break;

    case state_sel_rotate:  /*rotating selection*/
      draw_displ_eor_rotatboxes (diag);
    break;

    case state_edit_drag:  /*we drag anchor/control point(s) directly,*/
    case state_edit_drag1:
    case state_edit_drag2:
    break;               /*so nothing to unplot*/
  }

  diag->misc->substate = diag->misc->mainstate;

  if (draw_enter_null_owner.diag == diag) draw_enter_release_nulls (diag);
}

/*Change state.
   'setundo' indicates that a the changestate constitutes a single undo
   operation.
*/
void draw_action_changestate (diagrec *diag, draw_state newstate,
                             int curved, /*only used if*/
                             int closed, /*mainstate is state_path*/
                             BOOL setundo)

{ draw_state   oldstate = diag->misc->mainstate;
  diag_options oldopts  = diag->misc->options;

  ftracef3 ("draw_action_changestate: diag: 0x%X; newstate: %d; "
      "setundo: %s\n", diag, newstate, setundo? "true": "false");
  /*Do nothing if there is really no change*/
  if (oldstate == newstate && oldopts.curved == curved &&
      oldopts.closed == closed)
  { draw_menu_entry_option (newstate, curved, closed);
    return;
  }

  /*Start undo putting if asked*/
  if (setundo) draw_undo_separate_major_edits (diag);

  draw_toolbox_showall (diag, FALSE);

  if (oldstate == newstate)
  { /*Save the old state and options*/
    draw_undo_put (diag, draw_undo__changestate, (int) oldstate,
        *(int *) &oldopts);

    if (oldstate == state_path)
    { os_error *err;

      draw_displ_eor_cons2 (diag);

      err = draw_enter_state_changelinecurve (diag,
          curved? path_bezier: path_lineto);
      diag->misc->options.curved = curved;
      draw_displ_eor_cons2 (diag);

      if (wimpt_complain (err))
      { draw_undo_prevent_undo (diag);
        return;
      }
    }
  }
  else
  { ftracef0 ("Complete any path etc\n");
    draw_enter_complete (diag);

    ftracef0 ("Kill anything that won't complete\n");
    draw_action_abandon (diag);

    if (oldstate == state_sel && draw_selection->owner == diag)
        /*was just oldstate == state_sel. J R C 16th Feb 1994*/
      draw_select_release_selection (diag);

    if (oldstate == state_edit)
      draw_edit_release_edit (diag);

    /*Save the old state and options*/
    if (oldstate != -1) /*JRC 18 Dec '89*/
      draw_undo_put
      (diag, draw_undo__changestate, (int) oldstate, *(int *) &oldopts);

    diag->misc->mainstate = diag->misc->substate = newstate;

    if (newstate == state_path)
      diag->misc->options.curved = curved;

    if (diag && newstate == state_sel)
      draw_select_claim_selection (diag);     /*pinch it from anyone else*/

    if (newstate == state_edit)
      draw_edit_claim_edit (diag);

    draw_setpointer (diag);  /*change pointer to reflect state*/
  }

  if (newstate == state_path)
    diag->misc->options.closed = closed;

  draw_toolbox_showall (diag, TRUE);

  draw_menu_entry_option (newstate, curved, closed);
}

/*Code for handling null events, both real and simulated*/
/*If the mouse is within a pixel of the window edge, then scroll the window,
   but only if the buttons are down.*/
/*Returns TRUE if the mouse is scrolled back into the window*/
static BOOL draw_null_event_handler (wimp_mousestr mouse)

{ wimp_wstate r;
  diagrec *diag;
  viewrec *vuue;
  draw_objcoord org, mouseD;

  ftracef0 ("draw_null_event_handler\n");
  /*If there is a null_owner (just being paranoid) pass event to it if the
    pointer is in the window or if null owner is in path edit mode. This
    means points can be dragged outside the window, but all other operations
    freeze at window edge
  */
  if ((diag = draw_enter_null_owner.diag) != 0)
    if (pointer_diag == diag || diag->misc->mainstate == state_edit)
      if ((vuue = diag->misc->wantsnulls) != 0)
      { BOOL scrolled = FALSE;

        draw_displ_scalefactor = vuue->zoomfactor;
        wimp_get_wind_state (vuue->w, &r);

        /*Check for scrolling at window edge*/
        if
        (
#if 1 /*JRC*/
          ( diag->misc->mainstate == state_sel ||
            diag->misc->mainstate == state_edit ||
            diag->misc->substate == state_zoom ||
            diag->misc->substate == state_printerI ||
            diag->misc->substate == state_printerO
          ) &&
#endif
          (mouse.bbits & ~wimp_BMID) != 0
        )
        { int dx = 0, dy = 0, nearx, neary;
          BOOL xscroll = TRUE, yscroll = TRUE;

          /*Scroll window if we are near the edge of it*/
          nearx = (r.o.box.x1 - r.o.box.x0)/20;
          if ((dx = mouse.x - r.o.box.x1) >= -nearx)
            /*Near right of window*/
            r.o.x += 2*(nearx + dx);
          else if ((dx = mouse.x - r.o.box.x0) <= nearx)
            /*Near left of window*/
            r.o.x -= 2*(nearx - dx);
          else
            xscroll = FALSE;

          neary = (r.o.box.y1 - r.o.box.y0)/20;
          if ((dy = mouse.y - r.o.box.y1) >= -neary)
            /*Near top of window*/
            r.o.y += 2*(neary + dy);
          else if ((dy = mouse.y - r.o.box.y0) <= neary)
            /*Near bottom of window*/
            r.o.y -= 2*(neary - dy);
          else
            yscroll = FALSE;

          /*Apply scroll, move pointer and change mouse block*/
          if (xscroll || yscroll)
          {
#if 0
            char block [5];
#endif

            /*Adjust scroll and re-open window*/
            draw_open_wind (&r.o, vuue);
#if 0
            /*Alter mouse position on screen*/
            block [0] = 3;
            block [1] = mouse.x;
            block [2] = mouse.x>>8;
            block [3] = mouse.y;
            block [4] = mouse.y>>8;
            wimpt_noerr (os_word (0x15, &block));
#endif
            /*Make sure window data is up to date*/
            wimp_get_wind_state (vuue->w, &r);
            scrolled = TRUE;
          }
        }

        /*draw_make_clip (&r, &org, &clip);*/
        make_origin (&org, &r.o.box, &r.o.x);
        draw_point_scale (&mouseD, (draw_objcoord *) &mouse.x, &org);

        /*Snap mouse, except when dragging a zoom or printer box -- or a
          capture box. JRC 11 Oct 1990*/
        if (!(diag->misc->substate == state_zoom ||
            /*diag->misc->substate == state_printerI ||
            diag->misc->substate == state_printerO ||
                Snap when dragging limits JRC 25 June 1991*/
            diag->misc->substate == state_sel_select ||
            diag->misc->substate == state_sel_adjust ||
            diag->misc->substate == state_sel_shift_select ||
            diag->misc->substate == state_sel_shift_adjust))
          draw_grid_snap_if_locked (vuue, &mouseD);

        if (mouseD.x != diag->misc->ptzzz.x ||
            mouseD.y != diag->misc->ptzzz.y)
          draw_obj_move_construction (diag, &mouseD);

        return scrolled;
      }

  return FALSE;
}

#if 0 /*not used. JRC 11 Oct 1990*/
/*Centre the view on the given point, as far as possible without actually
moving the window. x and y are screen coordinates*/
static void centre_view (viewrec *vuue, wimp_wstate *blk, int x, int y)

{ ftracef0 ("centre_view\n");
  blk->o.x += x - (blk->o.box.x1 + blk->o.box.x0)/2;
  blk->o.y += y - (blk->o.box.y1 + blk->o.box.y0)/2;

  draw_open_wind (&blk->o, vuue);
}
#endif

/*Set the paper limits to lie at the given bottom left location*/
/*The flag indicates whether select or adjust was used*/
static void set_paper_limit (viewrec *vuue, draw_objcoord pt, BOOL select)

{ diagrec        *diag  = vuue->diag;
  paperstate_typ *paper = &diag->misc->paperstate;

  ftracef0 ("set_paper_limit\n");
  /*draw_displ_show_printmargins() no longer xors. J R C 1st Feb 1994*/
  /*Remove old print margins*/
  /*was draw_displ_show_printmargins (diag);*/

  /*Indicate that we are no longer using default values*/
  paper->options = (paperoptions_typ) (paper->options & ~Paper_Default);

  /*Snap the point to the grid*/
  draw_grid_snap_if_locked (vuue, &pt);

  if (select)
  { /*Click position is bottom left*/
    paper->setlimit.x1 += pt.x - paper->setlimit.x0;
    paper->setlimit.y1 += pt.y - paper->setlimit.y0;
    paper->setlimit.x0  = pt.x;
    paper->setlimit.y0  = pt.y;
  }
  else
  { /*Click position is top right*/
    paper->setlimit.x0 += pt.x - paper->setlimit.x1;
    paper->setlimit.y0 += pt.y - paper->setlimit.y1;
    paper->setlimit.x1  = pt.x;
    paper->setlimit.y1  = pt.y;
  }

  /*Display new print margins*/
  draw_displ_forceredraw (diag);
      /*was draw_displ_show_printmargins (diag);*/
}

/*Set printer limits from box*/
void draw_set_paper_limits (diagrec *diag, captu_str box)

{ paperstate_typ *paper = &diag->misc->paperstate;

  ftracef0 ("draw_set_paper_limits\n");
  /*Print margins no longer xorred. J R C 1st Feb 1994*/
  /*Remove old print margins*/
  /*was draw_displ_show_printmargins (diag);*/

  /*Indicate that we are no longer using default values*/
  paper->options = (paperoptions_typ) (paper->options & ~Paper_Default);

  /*Reorder coordinates of box*/
  draw_sort (&box.x0, &box.x1);
  draw_sort (&box.y0, &box.y1);

  if (diag->misc->mainstate == state_printerI)
  { /*Setting inner limits*/
    draw_bboxtyp pbox, vbox;
    draw_print_get_limits (diag, &pbox, &vbox);

    paper->setlimit.x0 = box.x0 - (vbox.x0 - pbox.x0);
    paper->setlimit.y0 = box.y0 - (vbox.y0 - pbox.y0);
    paper->setlimit.x1 = box.x1 + (vbox.x1 - pbox.x1);
    paper->setlimit.y1 = box.y1 + (vbox.y1 - pbox.y1);
  }
  else
  { /*Setting outer limits*/
    paper->setlimit = box;
  }

  /*Display new print margins*/
  draw_displ_forceredraw (diag);
      /*was draw_displ_show_printmargins (diag);*/
}

/*Start a capture. Used for select and for zoom drag.*/
/*Also abandons current action first, if asked nicely*/
void draw_start_capture (viewrec *vuue, draw_state state, draw_objcoord *pt,
                        BOOL abandon)

{ diagrec *diag = vuue->diag;

  ftracef0 ("draw_start_capture\n");
  if (abandon) draw_action_abandon (diag);

  /*Prepare for drag*/
  diag->misc->substate = state;
  draw_enter_claim (diag, vuue);

  /*Snap box, except for zoom and printer drag -- or a
          capture box. JRC 11 Oct 1990*/
  if (!(state == state_sel_select ||
        state == state_sel_adjust ||
        state == state_sel_shift_select ||
        state == state_sel_shift_adjust ||
        state == state_zoom /*||
        state == state_printerI ||
        state == state_printerO
            Snap when dragging limits JRC 25 June 1991*/))
    draw_grid_snap_if_locked (vuue, pt);

  /*Fiddle it by using the select capture box*/
  draw_capture_cb.x0 = draw_capture_cb.x1 = pt->x;
  draw_capture_cb.y0 = draw_capture_cb.y1 = pt->y;

  draw_displ_eor_capturebox (diag);
}

/*-----------------------------------------------------------------------*/
/*The main paper event handler*/
/*Subsidiary routines first*/

void draw_make_clip (wimp_redrawstr *r, draw_objcoord *orgO, draw_bboxtyp *clip)

{ draw_objcoord org;

  ftracef0 ("draw_make_clip\n");
  make_origin (&org, &r->box, &r->scx);
  orgO->x = draw_os_to_draw (org.x);
  orgO->y = draw_os_to_draw (org.y);

  draw_point_scale ((draw_objcoord *) &clip->x0, (draw_objcoord *) &r->g.x0, &org);
  draw_point_scale ((draw_objcoord *) &clip->x1, (draw_objcoord *) &r->g.x1, &org);
}

static void paper_redraw (viewrec *vuue)

{ diagrec *diag = vuue->diag;
  int more;
  wimp_redrawstr r;

  ftracef0 ("paper_redraw\n");

  r.w = vuue->w;
  wimpt_noerr (wimp_redraw_wind (&r, &more));
  draw_displ_scalefactor = vuue->zoomfactor;

  #if TRACE
    ftracef (__FILE__, __LINE__,
        "paper_redraw: r.box: (%d, %d, %d, %d); r.sc: (%d, %d); "
        "r.g: (%d, %d, %d, %d)\n",
        r.box.x0, r.box.y0, r.box.x1, r.box.y1, r.scx, r.scy,
        r.g.x0, r.g.y0, r.g.x1, r.g.y1);
  #endif

  while (more)
  { draw_bboxtyp clip;
    draw_objcoord org;
    draw_make_clip (&r, &org, &clip);

    if (diag->misc->paperstate.options & Paper_Show)
      draw_displ_do_printmargin (diag, &org);

    ftracef1 ("obj_off=%d\n", diag->misc->mainstate == state_edit?
        diag->misc->pathedit_cb.obj_off: 0);

    if (diag->misc->mainstate == state_edit &&
        diag->misc->pathedit_cb.obj_off >= 0)
    { draw_objptr stop;

      stop.bytep = diag->paper + diag->misc->pathedit_cb.obj_off;

    #if TRACE
      wimpt_noerr (draw_displ_do_objects (diag, diag->misc->solidstart,
          diag->misc->pathedit_cb.obj_off, &org, &clip));

      wimpt_noerr (draw_displ_do_objects (diag,
          diag->misc->pathedit_cb.obj_off + stop.objhdrp->size,
          diag->misc->solidlimit, &org, &clip));
    #else
      (void) draw_displ_do_objects (diag, diag->misc->solidstart,
          diag->misc->pathedit_cb.obj_off, &org, &clip);

      (void) draw_displ_do_objects (diag,
          diag->misc->pathedit_cb.obj_off + stop.objhdrp->size,
          diag->misc->solidlimit, &org, &clip);
    #endif
    }
    else
      /*repaint all objects in the database*/
    #if TRACE
      wimpt_noerr (draw_displ_do_objects (diag,
          diag->misc->solidstart, diag->misc->solidlimit, &org, &clip));
    #else
      (void) draw_displ_do_objects (diag,
          diag->misc->solidstart, diag->misc->solidlimit, &org, &clip);
    #endif

    /*Repaint construction lines if this diag claims nulls*/
    draw_displ_paint_skeleton (diag, &org);

    /*Paint selection boxes if the diagram is the selection owner*/
    draw_displ_paint_bboxes (diag, &org);

    /*Unusual in that it takes a vuue as different grids apply to each
      vuue*/
    if (vuue->flags.show)
      draw_displ_paint_grid (vuue, &org, clip);

    wimpt_noerr (wimp_get_rectangle (&r, &more));
  }
}

static void dispose_view (viewrec *vuue)

{ diagrec *diag = vuue->diag;
  ftracef2 ("dispose_view: diag: 0x%X; vuue: 0x%X\n", diag, vuue);

  #if 0 /*J R C 22nd Sep 1993*/
  /*Get rid of the diag pointer in draw_selection->owner, if any.*/
  if (diag == draw_selection->owner)
    draw_select_set (NULL);
  #endif

  /*Remove this vuue from the view list:
     IF not first record THEN point our predecessor at our successor
                         ELSE point diag->view at our successor
     IF not last record  THEN point our successor at our predecessor*/
  if (vuue->prevview)
    vuue->prevview->nextview = vuue->nextview;
  else
    diag->view = vuue->nextview;

  if (vuue->nextview) vuue->nextview->prevview = vuue->prevview;
  diag->misc->vuuecnt--;  /*view no longer in list, so dec viewcnt*/

  win_register_event_handler (vuue->w, NULL, NULL);
  win_register_event_handler (vuue->pw, NULL, NULL); /*JRC 13 September
      1991*/

  /*Delete window and its pane*/
  wimp_close_wind (vuue->pw);
  wimp_delete_wind (vuue->pw);
  wimp_close_wind (vuue->w);
  wimp_delete_wind (vuue->w);
  win_activedec ();

  /*Free the memory*/
  Free (vuue->title);
  Free (vuue);
}

void draw_paper_close (viewrec *vuue)

{ int singlevuue;
  diagrec *diag = vuue->diag;
  BOOL shifted = akbd_pollsh ();

  ftracef0 ("draw_paper_close\n");
  /*Kill any menus*/
  draw_menu_kill (vuue->w);

  ftracef3 ("** Close_Window_Request, diag 0x%X, vuue 0x%X, vuuecnt %d\n",
      diag, vuue, diag->misc->vuuecnt);

  singlevuue = diag->misc->vuuecnt == 1;

  /*FIX G-RO-9964 JRC 29 Oct '91 Don't close if SHIFT is down.*/
  { /*The magic 'open directory on close with right click' code*/
    wimp_mousestr m;

    wimpt_noerr (wimp_get_point_info (&m));
    ftracef1 ("mouse button state is 0x%X\n", m.bbits);
    if ((m.bbits & wimp_BRIGHT) != 0)
    { /*Can trample on filename now - need to strip off the leafname.*/
      char *dot = strrchr (diag->misc->filename, '.');

      if (dot != NULL)
      { char cli [15 + sizeof diag->misc->filename];

        *dot = 0;
        sprintf (cli, "%%Filer_OpenDir %s", diag->misc->filename);
        *dot = '.';  /*put back the '.' we trampled on*/

        wimpt_complain (os_cli (cli));
        /*don't close if shift down!*/
        if (shifted) return;
      }
    }
  }

  /*If only view on a modified diagram, give user a chance to save it*/
  if (singlevuue && diag->misc->options.modified)
  { char a [300], *name = diag->misc->filename;

    if (*name == 0 || strlen (name) > 255)
      sprintf (a, msgs_lookup ("DrawS1"));
    else
      sprintf (a, msgs_lookup ("DrawS2"), name);

    switch (dboxquery_close (a))
    { case dboxquery_close_SAVE:
        if (*name == 0) name = filename_whole;
          saveas (FileType_Draw, name, 1024,
              draw_file_file_saveall, draw_file_ram_saveall,
              draw_file_printall, (void*)diag);
      break;

      case dboxquery_close_DISCARD:
        diag->misc->options.modified = 0; /*data not wanted*/
      break;

      default:
      break;    /*cancel, do nothing, it stays updated.*/
    }
  }

  /*If singlevuue & modified, either reply was cancel OR yes & save failed
    so don't delete diagram. If singlevuue & !modified, (includes reply
    no), delete diagram. If !singlevuue, delete this view*/
  if (singlevuue && diag->misc->options.modified) return;

  /*If this window has the input focus, give it away*/
  if (draw_enter_focus_owner.hand == vuue->w) draw_enter_release_focus ();

  /*If this window owns nulls, either: release them (if this is the only
    vuue) or pass them to another vuue on this diagram*/
  if (draw_enter_null_owner.hand == vuue->w)
  { if (singlevuue)
      draw_enter_release_nulls (diag);
    else
    { if (vuue->prevview)
        draw_enter_claim_nulls (diag, vuue->prevview);
      else
        draw_enter_claim_nulls (diag, vuue->nextview);
    }
  }

  /*Give away selection if this is the only vuue*/
  if (draw_select_owns (diag) && singlevuue)
    draw_select_set (NULL);

  /*SMC: Reset pointer if it's in this diag*/
  if (pointer_diag == diag)
  {
    pointer_diag = 0;
    pointer_reset_shape ();
  }

  if (singlevuue)
    draw_dispose_diag (diag);
  else
  { dispose_view (vuue); /*remove from view list, free memory*/
                                  /*closes and deletes the window*/
    draw_displ_redrawtitle (diag); /*Redraw other titles*/
  }
}

static void paper_but (wimp_mousestr *m, viewrec *vuue)

{ draw_objcoord org, pt;
  wimp_wstate r;
  os_error *err;
  BOOL shifted = akbd_pollsh ();
  BOOL control = akbd_pollctl ();
  diagrec *diag = vuue->diag;

  ftracef0 ("paper_but\n");
  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);

  /*Make sure we have input focus*/
  draw_enter_claim_focus (diag, vuue);

  draw_displ_scalefactor = vuue->zoomfactor;
  wimp_get_wind_state (m->w, &r);
  make_origin (&org, &r.o.box, &r.o.x);
  pt.x = draw_scaledown (m->x - org.x);       /*mouse position relative to*/
  pt.y = draw_scaledown (m->y - org.y);       /*window (ie diagram) origin*/

  if ((err = draw_obj_drop_construction (diag)) != NULL)
    return;

  if (m->bbits & wimp_BLEFT)       /*0x004 Double 'select'*/
  { switch (diag->misc->mainstate)
    { case state_path:
      case state_text:
      case state_rect:
      case state_elli:
        err = draw_enter_doubleselect (diag);
      break;

      case state_sel:
        draw_select_doubleselect (diag, &pt);
      break;
    }
  }
  else if (m->bbits & wimp_BDRAGLEFT)     /*0x040 Long 'select'*/
  { if (control)
    { /*Start printer limits drag (outer box)*/
      /*We must avoid being in state_zoom while there is a path edit in
        progress, because while in state_zoom path being editing is not
        redrawn. JRC 23 Jan 1990*/
      if (diag->misc->mainstate == state_edit)
        draw_edit_select (diag);

      draw_start_capture (vuue, state_printerO, &pt, TRUE);
    }
    else
    { switch (diag->misc->mainstate)
      { case state_sel:
          draw_select_longselect (diag, vuue, &pt, shifted);
        break;
      }
    }
  }
  else if (m->bbits & wimp_BCLICKLEFT)   /*0x400 Short 'select'*/
  { if (control)
      set_paper_limit (vuue, pt, TRUE);
    /*else if (shifted)
      centre_view (vuue, &r, m->x, m->y); Removed JRC 11 Oct 1990*/
    else /*Same for SELECT and shift-SELECT*/
    { switch (diag->misc->mainstate)
      { case state_path:
        case state_text:
        case state_rect:
        case state_elli:
          draw_grid_snap_if_locked (vuue, &pt);

          if (pt.x != diag->misc->ptzzz.x || pt.y != diag->misc->ptzzz.y)
            draw_obj_move_construction (diag, &pt);

          err = draw_enter_select (diag, vuue, &pt);
        break;

        case state_sel:
          err = draw_select_select (diag, &pt);
        break;

       case state_edit:
         draw_edit_select (diag);
       break;
      }
    }
  }
  else if (m->bbits & wimp_BRIGHT)      /*0x001 Double 'adjust'*/
  { if (shifted)
    { draw_action_abandon (diag);
      draw_action_zoom_alter (vuue, -1);
    }
    else
    { switch (diag->misc->mainstate)
      { case state_edit:
          draw_edit_doubleadjust (diag, &pt);
        break;
      }
    }
  }
  else if (m->bbits & wimp_BDRAGRIGHT)    /*0x010 Long 'adjust'*/
  { if (control)
    { /*Start printer limits drag (inner box)*/
      /*We must avoid being in state_zoom while there is a path edit in
        progress, because while in state_zoom path being editing is not
        redrawn. JRC 23 Jan 1990*/
      if (diag->misc->mainstate == state_edit)
        draw_edit_select (diag);

      draw_start_capture (vuue, state_printerI, &pt, TRUE);
    }
    else if (shifted)
    { switch (diag->misc->mainstate)
      { default:
          /*Start Zoom drag*/
          draw_start_capture (vuue, state_zoom, &pt, TRUE);
          draw_action_zoom_view (vuue);
        break;

        case state_edit:
          draw_edit_long_shift_adjust (diag, vuue, &pt);
        break;
      }
    }
    else /*not shifted*/
    { switch (diag->misc->mainstate)
      { case state_sel:
          draw_select_longadjust (diag, vuue, &pt, FALSE); /*TRUE not
              invoked from anywhere*/
        break;

        case state_edit:
          draw_edit_longadjust (diag, vuue, &pt);
        break;
      }
    }
  }
  else if (m->bbits & wimp_BCLICKRIGHT)  /*0x100 Short 'adjust'*/
  { if (control)
      set_paper_limit (vuue, pt, FALSE);
    else if (!shifted)
    { switch (diag->misc->mainstate)
      { case state_sel:
          err = draw_select_adjust (diag, &pt);
        break;

        case state_path:
        case state_rect:
        case state_elli:
        case state_text:
          err = draw_enter_adjust (diag, &pt);
        break;

        case state_edit:
          draw_edit_adjust (diag, &pt);
        break;
      }
    }
    else /*shifted*/
    { switch (diag->misc->mainstate)
      { case state_edit:
          draw_edit_adjust (diag, &pt); /*Do the same for shift-adjust as
              for adjust in edit mode. JRC 6 Feb 1990*/
        break;
      }
    }
  }

  diag->misc->ptzzz = pt;

  ftracef2
  ( "paper_but: ptzzz = pt (%d, %d)\n",
    diag->misc->ptzzz.x, diag->misc->ptzzz.y
  );
}

/*Check and copy the file name*/
static BOOL check_filename (char *name, char *to, int maxlen)

{ ftracef0 ("check_filename\n");

  /*Fix - if name is very long, give up*/
  if (strlen (name) > maxlen - 1)
  { Error (0, "FileP1");
    return FALSE;
  }
  strcpy (to, name);
  return TRUE;
}

/*Load operations*/
/*Creates the diagram if it is NULL. vuue should also be NULL if so.*/
/*If dataopen is TRUE, then only allow draw files to be loaded*/
static os_error *load_file (diagrec *diag, viewrec *vuue, draw_objcoord *pt,
                           BOOL dataopen)

{ int estsize, filetype = xferrecv_checkimport (&estsize);

  ftracef0 ("load_file\n");
  if (diag == NULL) vuue = NULL;

  switch (filetype)
  { case FileType_DataExchangeFormat:
    case FileType_Draw:
    #if ALLOW_DFILES
      case FileType_EarlyDrawingProgram:
    #endif
    case FileType_Sprite:
    case FileType_Text:
    case FileType_JPEG:
      draw_file_loadfile (diag, vuue, "", filetype, estsize, via_RAM, pt);
    break;

    default:
      #if REJECTUNKNOWNFILETYPES
        return draw_make_oserror ("DrawCL");
      #endif
    break;

    case -1:                                    /*Not an import*/
    { char *name, filename [FILENAMEMAX];

      filetype = xferrecv_checkinsert (&name);

      switch (filetype)
      { case FileType_Sprite:
        #if ALLOW_DFILES
          case FileType_EarlyDrawingProgram:
        #endif
        case FileType_Text:
        case FileType_DataExchangeFormat:
        case FileType_JPEG:
          if (dataopen) break;
          /* else fall through */

        case FileType_Draw:
          if (check_filename (name, filename, FILENAMEMAX))
          { draw_file_loadfile (diag, vuue, filename, 0, 0, via_FILE, pt);

            ftracef0 ("sending Message_DataSaveAck\n");
            xferrecv_insertfileok (); /*Must respond before putting up
                dbox (in draw_dxf_setOptions ()).*/
          }
        break;

        default:
          #if REJECTUNKNOWNFILETYPES
            if (!dataopen) return draw_make_oserror ("DrawCL");
          #endif
        break;
      }
      break;
    }
  }

  return NULL;
}

/*Event handler for nulls, redraws, key clicks etc on the main window*/
/*(the paper) of a view*/
static void draw_paper__wimp_event_handler (wimp_eventstr *e, void *handle)

{ os_error *err = 0;
  viewrec  *vuue = (viewrec *) handle;
  diagrec  *diag = vuue->diag;

  ftracef1 ("draw_paper__wimp_event_handler: diag 0x%X\n", diag);
  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  #if 0 /*RISC_OS_PLUS*/
  if (!help_process (e))
  #endif
    switch (e->e)
    { case wimp_ENULL:
      { wimp_mousestr mouse;

        ftracef0 ("** Null_Reason_Code **\n");
        wimp_get_point_info (&mouse);
        draw_null_event_handler (mouse); /*Get the construction up to date*/

        /*If the 'select' & 'adjust' buttons are up, give each null*/
        /*claimer the chance to drop any stretch/translate/rotate boxes,*/
        /*area grab rectangles or edited points.*/
        if ((mouse.bbits & 0x005)==0)
        { diagrec *diag;
          for (diag = draw_startdiagchain; diag != 0; diag = diag->nextdiag)
            if (diag->misc->wantsnulls)
              draw_obj_drop_construction (diag);
        }
      }
      break;

      case wimp_EREDRAW:
        ftracef0 ("** Redraw_Window_Request **\n");
        paper_redraw (vuue);
      break;

      case wimp_EOPEN:
        ftracef0 ("** Open_Window_Request **\n");
        draw_open_wind (&e->data.o, vuue);   /*open paper and toolbox*/
      break;

      case wimp_ECLOSE:
        ftracef0 ("** Close_Window_Request **\n");
        draw_paper_close (vuue);
      break;

      case wimp_EPTRLEAVE:
      { wimp_mousestr mouse;

        ftracef0 ("** Pointer_Leaving_Window **\n");
        wimp_get_point_info (&mouse);

        /*Simulate null event on the window (for better visual effect)*/
        if (pointer_diag)
          if (draw_null_event_handler (mouse))
            break;

        /*Reset the pointer to normal shape*/
        pointer_diag = 0;
        pointer_reset_shape ();
      }
      break;

      case wimp_EPTRENTER:
        ftracef0 ("** Pointer_Entering_Window **\n");

        pointer_diag = diag;
        draw_setpointer (diag);     /*change pointer to reflect state*/

        /*if dragging a line/box from view-to-view change current_handle*/
        if (diag->misc->mainstate != diag->misc->substate)
          if (diag->misc->wantsnulls)
            draw_enter_claim (diag, vuue);

        /*Force a null event to get the construction up to date*/
        { wimp_mousestr mouse;
          wimp_get_point_info (&mouse);
          draw_null_event_handler (mouse);
        }
      break;

      case wimp_EBUT:
        ftracef0 ("** Mouse_Button **\n");
        paper_but (&e->data.but.m, vuue);
      break;

      case wimp_EUSERDRAG:
        ftracef0 ("** User_DragBox **\n");
      break;

      case wimp_EKEY:
        ftracef4 ("** Key_Pressed, window=%d, caret at (%d,%d), "
            "key code=%d **\n", e->data.key.c.w, e->data.key.c.x,
            e->data.key.c.y,e->data.key.chcode);

        draw_menu_processkeys (diag, vuue, e->data.key.chcode);
      break;

      case wimp_EMENU:
        ftracef0 ("** Menu_Select ** This should not happen\n");
      break;

      case wimp_ESCROLL:
        ftracef0 ("** Scroll_Request **\n");
      break;

      case wimp_ESEND:
      case wimp_ESENDWANTACK:
        ftracef0 (e->e == wimp_ESEND? "** User_Message **\n":
            "** User_Message_Acknowledge **\n");
        switch (e->data.msg.hdr.action)
        { case wimp_MHELPREQUEST:
            ftracef0 ("   Help Request\n");
            draw_help_helpmessage (e, diag);
          break;

          case wimp_MDATASAVE:   /*import*/
          case wimp_MDATALOAD:   /*insert*/
          case wimp_MDATAOPEN:   /*insert*/
            { wimp_mousestr mouse;
              wimp_wstate   r;
              draw_objcoord org, mouseD;

              ftracef0
              ( e->data.msg.hdr.action == wimp_MDATASAVE? "   Data Save\n":
                e->data.msg.hdr.action == wimp_MDATALOAD? "   Data Load\n":
                                                          "   Data Open\n"
              );
              /*Find the mouse location*/
              wimp_get_point_info (&mouse);
              wimp_get_wind_state (vuue->w, &r);
              draw_displ_scalefactor = vuue->zoomfactor;

              make_origin (&org, &r.o.box, &r.o.x);
              draw_point_scale (&mouseD, (draw_objcoord *)&mouse.x, &org);

              /*Gravitate to grid position*/
              draw_grid_snap_if_locked (vuue, &mouseD);

              /*Do the load*/
              err = load_file (diag, vuue, &mouseD, FALSE);
            }
          break;

          default:
            ftracef1 ("  Message Type %d\n", e->data.msg.hdr.action);
          break;
        }
      break;
    }

  /*Reset VDU5 character size*/
  draw_reset_gchar ();

  wimpt_complain (err);
}

/*Event handler for nulls,redraws,key clicks etc on the pane window*/
/*(the toolbox) of a view*/
static void draw_toolbox__wimp_event_handler (wimp_eventstr *e, void *handle)

{ os_error *err  = 0;
  viewrec  *vuue = (viewrec *)handle;
  diagrec  *diag = vuue->diag;   /*the diagram that owns the view*/
                                 /*that owns the pane window on*/
                                 /*which the event occured*/

  ftracef0 ("draw_toolbox__wimp_event_handler\n");
  #if 0 /*RISC_OS_PLUS*/
  if (!help_process (e))
  #endif
    switch (e->e)
    { case wimp_EOPEN:
        ftracef0 ("** Open_Window_Request on pane (toolbox) window **\n");
        wimp_open_wind (&e->data.o);
      break;

      case wimp_EBUT:
        ftracef2 ("** Mouse_Click on pane (toolbox) window, icon %d, "
          "buttons &%x **\n",
          e->data.but.m.i,e->data.but.m.bbits);

        if (e->data.but.m.bbits & 0x5)   /*'select' or 'adjust'*/
        { BOOL setundo, fromedit;

          ftracef0 ("Grab input focus\n");
          draw_enter_claim_focus (diag, vuue);

          ftracef0 ("Changing state from the toolbox registers a change "
              "for undo, except when we are changing between different "
              "path styles in the middle of entering a path object. Or "
              "when changing from path edit\n");
          fromedit = diag->misc->mainstate == state_edit;
          setundo = ! ((diag->misc->mainstate == state_path
                      && diag->misc->substate != diag->misc->mainstate)
                      || fromedit);

          switch (e->data.but.m.i)
          { case tbi_line_o: ftracef0 ("Line, open\n");
              draw_action_changestate (diag, state_path, 0, 0, setundo);
            break;

            case tbi_line_c: ftracef0 ("Line, auto-closed\n");
              draw_action_changestate (diag, state_path, 0, 1, setundo);
            break;

            case tbi_curv_o: ftracef0 ("Curve, open\n");
              draw_action_changestate (diag, state_path, 1, 0, setundo);
            break;

            case tbi_curv_c: ftracef0 ("Curve, auto-closed\n");
              draw_action_changestate (diag, state_path, 1, 1, setundo);
            break;

            case tbi_move: ftracef0 ("Move (new subpath)\n");
              err = draw_enter_movepending (diag);
            break;

            case tbi_rect: ftracef0 ("Rectangle\n");
              draw_action_changestate (diag, state_rect, 0, 0, !fromedit);
            break;

            case tbi_elli: ftracef0 ("Ellipse\n");
              draw_action_changestate (diag, state_elli, 0, 0, !fromedit);
            break;

            case tbi_text: ftracef0 ("Text\n");
              draw_action_changestate (diag, state_text, 0, 0, !fromedit);
            break;

            case tbi_select: ftracef0 ("Select mode\n");
              /*draw_action_abandon (diag);*/ /*Abandon any line entry -
                  removed JRC 21 June 1991*/
              draw_action_changestate (diag, state_sel, 0, 0, !fromedit);
            break;
          }
        }
      break;

      case wimp_EKEY:
        ftracef1 ("** Key_Pressed on tool window, key code=%d**\n",
          e->data.key.chcode);
        wimp_processkey (e->data.key.chcode);   /*toolbox can't handle it*/
      break;                                    /*so give back to the wimp*/

      case wimp_ESEND:
      case wimp_ESENDWANTACK:
        switch (e->data.msg.hdr.action)
        { case wimp_MHELPREQUEST:
            draw_help_helptoolbox (e);
          break;
        }
      break;
    }

  /*Reset VDU5 character size*/
  draw_reset_gchar ();

  wimpt_complain (err);
}

/*Register the event handler for a window*/
static void draw_register_events (viewrec *vuue)

{ ftracef0 ("draw_register_events\n");
  win_register_event_handler (vuue->w, &draw_paper__wimp_event_handler,
      vuue);
  event_attachmenumaker (vuue->w, draw_menu_filler, draw_menu_proc, vuue);
  if (vuue->pw != -1) win_register_event_handler (vuue->pw,
      &draw_toolbox__wimp_event_handler, vuue);
}

/*--------------------------- Quit handling -----------------------------*/

static int draw_countupdated (void)

{ diagrec *diag;
  int count = 0;

  ftracef0 ("draw_countupdated\n");
  for (diag = draw_startdiagchain; diag; diag = diag->nextdiag)
    if (diag->misc->options.modified) count++;
  return count;
}

/*Check we are allowed to quit*/
static BOOL draw_mayquit (void)

{ int count = draw_countupdated ();

  ftracef0 ("draw_mayquit\n");
  if (count == 0)
    return TRUE;
  else
  { char a [80];
    if (count == 1)
      strcpy (a, msgs_lookup ("DrawQ1"));
    else
      sprintf (a, msgs_lookup ("DrawQ2"), count);
    return dboxquery_quit (a) == dboxquery_quit_DISCARD;
  }
}

/*Prequit handler - used when we get a closedown, either
  global or Task 'Draw' => Quit from the Task Manager window.*/
static void draw_prequit (void)

{ int count = draw_countupdated ();

  ftracef0 ("draw_prequit\n");
  if (count != 0)
  { /*First, acknowledge the message*/
    wimp_eventstr *e   = wimpt_last_event ();
    wimp_msgstr   *msg = &e->data.msg;       /*Make access easier*/

    if ((e->e == wimp_ESEND || e->e == wimp_ESENDWANTACK)
         && msg->hdr.action == wimp_MPREQUIT)
    { wimp_t taskmgr    = msg->hdr.task;
      int original_size = msg->hdr.size,
        original_words0 = msg->data.words [0];

      msg->hdr.your_ref = msg->hdr.my_ref;
      wimpt_noerr (wimp_sendmessage (wimp_EACK, msg, msg->hdr.task));

      /*And then tell the user*/
      if (draw_mayquit ())
      { diagrec *diag;
        diagrec *next;
        wimp_eventdata ee;

        /*User has modified data that he doesn't want so..*/
        /*Dispose of all our diagrams and restart the close down*/
        /*sequence. When the prequit call arrives again, we have*/
        /*no diagrams and die quietly.*/

        /*The more obvious method (which does NOT work) would be*/
        /*broadcast the quit message, then call exit (). The task*/
        /*(Draw) dies immediatly, then the task manager kills any*/
        /*messages in transit from it so the broadcast doesn't get*/
        /*through.*/

        /*To restart the closedown sequence, assume that the sender*/
        /*is the Task Manager, and that sh-ctl-12  is the closedown*/
        /*key sequence.*/

        for (diag = draw_startdiagchain; diag!=0; )
        { if (draw_enter_null_owner.diag == diag)
            draw_enter_release_nulls (diag);
          if (draw_enter_focus_owner.diag == diag)
            draw_enter_release_focus ();

          next = diag->nextdiag;     /*N.B. MUST read nextdiag BEFORE*/
          draw_dispose_diag (diag);   /*dispose_diag, cos this frees*/
          diag = next;               /*the block and C widdles in it*/
        }

        if (original_size > sizeof (wimp_msghdr) &&
            (original_words0 & 1 /*Killed from task manager?*/))
          /*Acknowledged the prequit, the user doesn't want its data -
            die!*/
          exit (0);
        else
        { /*Acknowledged the prequit, the user doesn't want its data, this
            was a desktop closedown - S-C-F12*/
          wimpt_noerr (wimp_get_caret_pos (&ee.key.c));
          ee.key.chcode = akbd_Sh + akbd_Ctl + akbd_Fn12;
          ftracef3 ("send key (%d) c-s-F12 (%d) to switcher (0x%X)\n",
              wimp_EKEY, akbd_Sh + akbd_Ctl + akbd_Fn12, taskmgr);
          wimpt_noerr (wimp_sendmessage (wimp_EKEY, (wimp_msgstr*) &ee,
              taskmgr));
        }
      }
    }
  }
}

/*Translate draw_current_options to string (in static space).*/
static char *write_options (void)

{ static char Buffer [MAX_OPTIONS + 1];
  int len;
  draw_options *opt  = &draw_current_options;
  draw_options *opt0 = &initial_options;
    /*name equivalence to save typing.*/

  ftracef0 ("write_options\n");
  Buffer [0] = '\0';

  if (memcmp (&opt->paper, &opt0->paper, sizeof opt->paper) != 0)
  { char P [32];

    sprintf
    ( P,
      "P%c%s%s ",
      opt->paper.size == Paper_A0?
        '0':
      opt->paper.size == Paper_A1?
        '1':
      opt->paper.size == Paper_A2?
        '2':
      opt->paper.size == Paper_A3?
        '3':
      opt->paper.size == Paper_A5?
        '5':
        '4',
      opt->paper.o & Paper_Landscape? "L": "",
      opt->paper.o & Paper_Show? "S": ""
    );
    strcat (Buffer, P);
  }

  if (memcmp (&opt->grid, &opt0->grid, sizeof opt->grid) != 0)
  { char G [32];

    sprintf
    ( G,
      "G%.3fx%d%s%s%s%s%s ",
      opt->grid.space,
      opt->grid.divide,
      opt->grid.o [0]? "I": "",
      opt->grid.o [1]? "A": "",
      opt->grid.o [2]? "S": "",
      opt->grid.o [3]? "L": "",
      opt->grid.o [4]? "C": ""
    );
    strcat (Buffer, G);
  }

  if (memcmp (&opt->zoom, &opt0->zoom, sizeof opt->zoom) != 0)
  { char Z [32];

    sprintf
    ( Z,
      "Z%d:%d%s ",
      opt->zoom.mul,
      opt->zoom.div,
      opt->zoom.lock? "L": ""
    );
    strcat (Buffer, Z);
  }

  if (memcmp (&opt->toolbox, &opt0->toolbox, sizeof opt->toolbox) != 0)
  { char T [32];
    sprintf (T, "T%c ", opt->toolbox? '+': '-' );
    strcat (Buffer, T);
  }

  if (memcmp (&opt->mode, &opt0->mode, sizeof opt->mode) != 0)
  { char M [32];

    sprintf
    ( M,
      "M%c ",
      opt->mode.line?   'L':
      opt->mode.cline?  'l':
      opt->mode.curve?  'C':
      opt->mode.ccurve? 'c':
      opt->mode.rect?   'R':
      opt->mode.elli?   'E':
      opt->mode.text?   'T':
      opt->mode.select? 'S':
        'l'
    );
    strcat (Buffer, M);
  }

  if (memcmp (&opt->undo_size, &opt0->undo_size, sizeof opt->undo_size) != 0)
  { char U [32];
    sprintf (U, "U%d ", opt->undo_size);
    strcat (Buffer, U);
  }

  if ((len = strlen (Buffer)) > 0)
    /*Overwrite the last space with '\0' for neatness*/
    Buffer [--len] = '\0';
  else
    /*No output*/
    strcpy(Buffer, "\"\"");

  return Buffer;
}

/**************************************************************************
 *                                                                        *
 * Background message receiver: allow drops onto icon.                    *
 *                                                                        *
 **************************************************************************/

static void draw_bkg_events (wimp_eventstr *e, void *handle)

{ os_error *err = 0;

  handle = handle; /*avoid not used warning*/

  ftracef0 ("draw_bkg_events\n");
  #if 0 /*RISC_OS_PLUS*/
  if (!help_process (e))
  #endif
    switch (e->e)
    { case wimp_ESEND:
      case wimp_ESENDWANTACK:
      { wimp_msgstr *msg = &e->data.msg;       /*Make access easier*/

        switch (msg->hdr.action)
        { case wimp_MMODECHANGE:
            cache_currentmodevars ();
            wimp_readpalette (&draw_palette);
          break;

          case wimp_PALETTECHANGE:
          { diagrec *diag;

            /*always reread the palette, it might be the calibration that has changed */
            wimp_readpalette (&draw_palette);

            /*redraw all views of all diagrams so they show true colours*/
            for (diag = draw_startdiagchain; diag != 0; diag = diag->nextdiag)
              draw_displ_forceredraw (diag);
          }
          break;

          case wimp_MSetPrinter:
            draw_print_recachepagelimits ();     /*repaint our paper limits*/
          break;

          case wimp_MPrintTypeOdd:
            { int      filetype;
              char     *name;

              filetype = xferrecv_checkprint (&name);

              switch (filetype)
              { case FileType_Draw:
                  { diagrec  *diag;

                    diag = draw_file_loadfile (NULL, NULL, name, 0, 0,
                        via_FILE,&zero);
                    if (diag)
                    { ftracef0 ("draw_bkg_events: draw_print_printall\n");
                      err = draw_print_printall (diag);
                      ftracef0 ("draw_bkg_events: draw_dispose_diag\n");
                      draw_dispose_diag (diag);
                    }
                    ftracef0 ("draw_bkg_events: xferrecv_fileok\n");
                    xferrecv_printfileok (-1);
                  }
                break;
              }
            }
          break;

          case wimp_MHELPREQUEST: /*return a helpful message about our icon*/
            draw_help_reply (msg, "DrawH1", "");
          break;

          case wimp_MPREQUIT:
            draw_prequit ();
          break;

          case wimp_MDATASAVE:
          case wimp_MDATALOAD:
          case wimp_MDATAOPEN:
            err = load_file (NULL, NULL, &zero, msg->hdr.action==wimp_MDATAOPEN);
          break;

          case wimp_SAVEDESK:
            if (strlen (Draw_Dir) > 0) /*save if we know where we started*/
            {  os_gbpbstr gbpb_str;
               char lines [17 + MAX_OPTIONS + 1 + 4 + FILENAMEMAX + 1 + 1];

               sprintf
               ( lines,
                 "Set Draw$Options %s\nRun %s\n",
                 write_options (), Draw_Dir
               );

               gbpb_str.action = 0x2,
               gbpb_str.file_handle = msg->data.savedesk.filehandle,
               gbpb_str.data_addr = (void *) lines,
               gbpb_str.number = strlen (lines);

               if (wimpt_complain (os_gbpb (&gbpb_str)) != NULL)
               { /*Send back acknowledgement*/
                 msg->hdr.your_ref = msg->hdr.my_ref;
                 msg->hdr.size = 20;

                 wimpt_complain
                 ( wimp_sendmessage (wimp_EACK, msg, msg->hdr.task)
                 );
               }
            }
          break;
        }

        /*Reset VDU5 character size*/
        draw_reset_gchar ();

        wimpt_complain (err);
      }
      break;
    }
}

/*'left' click on Draw's icon, so create a new piece of paper*/
/*and open 1 view onto it*/

/*if an error occurs, tidy up then report it*/
static void draw__iconclick (wimp_i i)

{ diagrec *diag;

  i = i; /*stupid compiler*/

  ftracef0 ("draw__iconclick\n");

  wimpt_complain (draw_opennewdiag (&diag, TRUE));
}

static void draw__iconmenuproc (void *handle, char *hit)

{ ftracef0 ("draw__iconmenuproc\n");
  handle = handle; /*stupid compiler*/

  switch (hit [0])
  { case 1:
      if (hit [1]) draw_menu_infoaboutprogram ();
    break;

    case 2:
      if (draw_mayquit ()) exit (0);
    break;
  }
}

/*Read Draw$Options and parse it*/

/*Set booleans based on the presence of optional letters*/
static char *get_options (char *from, char *look, int *result, int max)

{ int i;

  ftracef0 ("get_options\n");
  for (i = 0; i < max; i++) result [i] = 0;

  while (*from)
  { i = (int) (strchr (look, toupper (*from)) - look);
    if (i < max) result [i] = 1;
    from++;
  }
  return from;
}

static void read_options (void)

{ /*Now sets draw_current_options. Called only once, at startup. JRC*/
  char buffer [MAX_OPTIONS + 1], *token, *options;
  draw_options *opt = &draw_current_options;

  /*Set defaults*/
  *opt = initial_options;

  ftracef0 ("read_options\n");
  if ((options = getenv ("Draw$Options")) != NULL)
  { sprintf (buffer, "%.*s", MAX_OPTIONS, options);

    /*Get tokens separated by spaces*/
    for (token = strtok (buffer, " "); token != NULL;
        token = strtok (NULL, " "))
    { /*Find token type*/
      switch (toupper (token [0]))
      { case 'P': /*PnL?S?*/
        { BOOL options [2]; /*land, show*/

          if (token [1])
          { switch (token [1])
            { case '0': opt->paper.size = Paper_A0; break;
              case '1': opt->paper.size = Paper_A1; break;
              case '2': opt->paper.size = Paper_A2; break;
              case '3': opt->paper.size = Paper_A3; break;
              case '5': opt->paper.size = Paper_A5; break;
              default : opt->paper.size = Paper_A4; break;
            }

            token = get_options (&token [2], "LS", options, 2);
            opt->paper.o = (paperoptions_typ) ((options [0]? Paper_Landscape: 0) |
                           (options [1]? Paper_Show: 0));
          }
        }
        break;

        case 'G': /*G(<a>x<b>)?I?A?S?L?C?*/
        { double space;
          int subdiv;
          char *rest = &token [1];

          if (isdigit (*rest) &&
              (space = strtod (rest, &rest)) != 0.0 &&
              toupper (*rest++) == 'X' &&
              (subdiv = (int) strtol (rest, &rest, 10)) != 0)
          { opt->grid.space = space;
            opt->grid.divide = subdiv;
          }

          get_options (rest, "IASLC", opt->grid.o, 5);
        }
        break;

        case 'Z': /*Z<a>:<b>L?*/
        { int mul, div;
          char  *rest;

          mul = (int)strtol (token+1, &rest, 10);
          if (rest != token && toupper (*rest) != ':') break;
          div = (int)strtol (rest+1, &rest, 10);
          if (rest == token) break;

          if (toupper (*rest) == 'L') opt->zoom.lock = 1;

          if (mul < 1) mul = 1;
          else if (mul > MAXZOOMFACTOR) mul = MAXZOOMFACTOR;
          if (div < 1) div = 1;
          else if (div > MAXZOOMFACTOR) div = MAXZOOMFACTOR;
          opt->zoom.mul = mul;
          opt->zoom.div = div;

          ftracef2 ("zoom options set to %d: %d\n",
              opt->zoom.mul, opt->zoom.div);
        }
        break;

        case 'T': /*T [+|-]*/
          if (token [1] == '+') opt->toolbox = 1;
          else if (token [1] == '-') opt->toolbox = 0;
          ftracef1 ("toolbox is %s\n", opt->toolbox? "ON": "OFF");
        break;

        case 'M': /*M [L|l|C|c|R|E|T|S]*/
        { opt->mode.line   = opt->mode.cline = opt->mode.curve =
          opt->mode.ccurve = opt->mode.rect  = opt->mode.elli  =
          opt->mode.text   = opt->mode.select = 0;

          switch (token [1])
          { case 'L':           opt->mode.line   = 1; break;
            case 'l':           opt->mode.cline  = 1; break;
            case 'C':           opt->mode.curve  = 1; break;
            case 'c':           opt->mode.ccurve = 1; break;
            case 'R': case 'r': opt->mode.rect   = 1; break;
            case 'E': case 'e': opt->mode.elli   = 1; break;
            case 'T': case 't': opt->mode.text   = 1; break;
            case 'S': case 's': opt->mode.select = 1; break;
            default: opt->mode = initial_options.mode;
          }
        }
        break;

        case 'U': /*U<size>*/
        { int size = (int) strtol (token + 1, (char **) NULL, 10);

          /*Use either given size rounded to a multiple of 4 or default*/
          opt->undo_size = size <= 0? initial_options.undo_size: size & ~3;
        }
        break;
      }
    }
  }

  ftracef2 ("zoom options set to %d: %d\n",
      opt->zoom.mul, opt->zoom.div);
}

static int get_icon_colour (int index)

{ ftracef0 ("get_icon_colour\n");
  return (blank_view.colouricons [index].flags >> 28) & 0xF;
}

/*Set up sprite area for dboxes which use opt and radio sprites*/
static void set_sprite_area (char *template)

{ wimp_wind *w  = template_syshandle (template);
  ftracef0 ("set_sprite_area\n");
  w->spritearea = (void *)1; /*Wimp sprite area*/
}

static menu Icon_Bar_Menu_Maker (void *handle)

{ menu icon_bar_menu = (menu) handle;

  ftracef0 ("Icon_Bar_Menu_Maker\n");
  ftracef0 ("registering icon bar menu help handler\n");
  help_register_handler (&help_simplehandler, (void *) "ICON");

  return icon_bar_menu;
}

static BOOL Help_Process (wimp_eventstr *event, void *h)

{ ftracef0 ("Help_Process\n");
  h = h;
  return help_process (event);
}

/* Fixed stack size !!!
 * 4k is the max required
 * 0.5k bodge safety factor
 */
#if TRACE
int __root_stack_size = 24*1024+512+512;
#else
int __root_stack_size = 4*1024+512+512;
#endif

#if 0
extern int disable_stack_extension;
#endif

char draw_numvalid0[] = "a0-9";
char draw_numvalid1[] = "a0-9.\0"; /*final '\0' overwritten with '.'*/
char draw_numvalid2[] = "a0-9.\\-\0";

char draw_zero_str[] = "0.0";
char draw_one_str[] = "1.0";

int main (int argc, char **argv)

{ os_error *error;
  template *t;
  int       version;
  #if CATCH_SIGNALS
    int s, sig;
  #endif

  static wimp_msgaction Messages [] =
    { wimp_MDATASAVE,
      wimp_MDATASAVEOK,
      wimp_MDATALOAD,
      wimp_MDATALOADOK,
      wimp_MDATAOPEN,
      wimp_MRAMFETCH,
      wimp_MRAMTRANSMIT,
      wimp_MPREQUIT,
      wimp_PALETTECHANGE,
      wimp_SAVEDESK,
      wimp_MDATASAVED,
      wimp_MMENUWARN,
      wimp_MMODECHANGE,
      wimp_MHELPREQUEST,
      wimp_MHELPREPLY,
      wimp_MPrintFile,
      wimp_MWillPrint,
      wimp_MPrintSave,
      wimp_MPrintError,
      wimp_MPrintTypeOdd,
      wimp_MPrintTypeKnown,
      wimp_MSetPrinter,
      wimp_MCLOSEDOWN
    };

  #if 0
  disable_stack_extension = FREEZE_STACK;
  #endif

  setlocale (LC_ALL, "");

  draw_numvalid1[5] =
      draw_numvalid2[7] =
      draw_zero_str[1] =
      draw_one_str[1] =
          *localeconv()->decimal_point;

  ftrace_on ();
  ftracef0 ("main\n");

  /* Install signal handlers for errors etc. */
  wimpt_install_signal_handlers();

  #if TRACE
  { /*Trace environment handler addresses.*/
    int junk, handler, r12, i, buffer;

    for (i = 0; i < 17; i++)
    { os_swi4r (OS_ChangeEnvironment, i, 0, 0, 0,
          &junk, &handler, &r12, &buffer);
      ftracef4 ("Environment handler %d is 0x%X, r12 0x%X, buffer at 0x%X\n",
          i, handler, r12, buffer);
    }
  }
  #endif

  /* OSS Read Messages file by explicit pathname. */
  res_init ("Draw");
  msgs_readfile("Draw:Messages");

  /* OSS Read Sprites file by explicit name. */

  resspr_readfile("Draw:Sprites");

  wimpt_wimpversion (300);
  wimpt_messages (Messages);
  wimpt_init (msgs_lookup ("Draw00"));

  FLEX_INIT ();
  #if TRACE
    #if FREEZE_STACK
       _kernel_register_slotextend (&Dont_Budge);
    #else
       _kernel_register_slotextend (&Do_Budge);
    #endif
  #else
    #if FREEZE_STACK
       /*default*/
    #else
       _kernel_register_slotextend (&flex_budge);
    #endif
  #endif
  heap_init (FALSE /*non-compacting*/);

  /* OSS Read Templates file by explicit pathname. */

  template_readfile("Draw:Templates");
  visdelay_init ();
  dbox_init ();
  dboxquery_quit (0);     /*reserves space*/
  dboxquery_close (0);

  set_sprite_area ("NumPoint");
  set_sprite_area ("DXFloader");

  os_read_var_val ("Draw$Dir", Draw_Dir, FILENAMEMAX);
  read_options (); /*Sets draw_current_options.*/

  t = template_find ("paper");
  assert (t->window.nicons <= 10);
  memcpy (&blank_view.paper, &t->window,
      sizeof (wimp_wind) + sizeof (wimp_icon)*t->window.nicons);
  ftracef2 ("scroll offsets in template file are (%d, %d)\n",
      blank_view.paper.scx, blank_view.paper.scy);

  blank_view.paper.nicons = 0; /*Icons in the template provide colour
      information and are not wanted in our window*/

  blank_position.papery0 = blank_view.paper.box.y0;
  blank_position.papery1 = blank_view.paper.box.y1;
  blank_position.yshift  = 0;

  draw_colours.skeleton    = get_icon_colour (0);
  draw_colours.anchorpt    = get_icon_colour (1);
  draw_colours.bezierpt    = get_icon_colour (2);
  draw_colours.highlight   = get_icon_colour (3);

  draw_colours.grid        = get_icon_colour (4);
  draw_colours.bbox        = get_icon_colour (5);
  draw_colours.printmargin = get_icon_colour (6);

  t = template_find ("pane");
  assert (t->window.nicons <= 15);
  memcpy (&blank_pane.pane, &t->window,
         sizeof (wimp_wind) + sizeof (wimp_icon)*t->window.nicons);

  blank_pane.pane.spritearea = (void*)resspr_area ();
  blank_position.paney0 = blank_pane.pane.box.y0;
  blank_position.paney1 = blank_pane.pane.box.y1;

  /*Claim some memory for the selection group, so that it is possible
    to enter select mode and delete items even when RAM is full*/
  if (!draw_select_alloc ())
    Error (1, "DrawR1");

  baricon
  ( msgs_lookup("BarIcon"),     /* OSS Look sprite name up in Messages */
    1, /*Use WIMP sprite pool for Draw. JRC 17 Jan '90*/
    &draw__iconclick
  );

  { menu icon_bar_menu = menu_new (msgs_lookup ("Draw00"),
        msgs_lookup ("DrawM1"));

    if (!event_attachmenumaker (win_ICONBAR, &Icon_Bar_Menu_Maker,
      draw__iconmenuproc, (void *) icon_bar_menu))
    Error (1, "DrawR2");
  }

  draw_menu_maker (); /*construct menu skeleton 'mainmenu' and 'editmenu'
      also constructs the fontlist!*/

  /*Set up a dummy window event handler to get icon messages*/
  win_register_event_handler (win_ICONBARLOAD, draw_bkg_events, 0);
  win_claim_unknown_events (win_ICONBARLOAD);

  /*Set up an unknown event handler to get help messages on windows.*/
  win_add_unknown_event_processor (&Help_Process, NULL);

  draw_printer = draw_no_printer;  /*assume no printer*/
  draw_print_recachepagelimits ();  /*find physical & usable printer page*/

  cache_currentmodevars ();     /*recached each time background event*/
                               /*handler receives a mode change message*/
  wimp_readpalette (&draw_palette); /*Record palette colours*/

  /*Find out if jpegs are rotatable by this version of SpriteExtend*/
  draw_jpegs_rotate = jpeg_arbitrary_trans_supported ();
  ftracef1 ("jpegs rotate: %s\n", draw_jpegs_rotate ? "TRUE" : "FALSE");

  /*Find out if fonts are background blendable by this version of FontManager*/
  os_swix1r (Font_CacheAddr, 0, &version);
  draw_fonts_blend = version >= 335;
  ftracef1 ("fonts blend: %s\n", draw_fonts_blend ? "TRUE" : "FALSE");
     
  /*Generate the points on a circle of standard radius, centre (0,0).*/
  /*These are placed in a point buffer implemented as an array of coords,*/
  /*the circle is given by:*/
  /*a move to point 0*/
  /*curve to 1, 2, 3 (i.e. 1,2 are control, 3 is end)*/
  /*curve to 4, 5, 6*/
  /*curve to 7, 8, 9*/
  /*curve to 10, 11, 12*/

  /*these values are copied into a path_pseudo_ellipse and scaled/translated
    as needed by the ellipse entry code*/
  { bezierarc_coord bcentre;
    bcentre.x = bcentre.y = 0;

    bezierarc_circle (bcentre, dbc_StdCircRad,
        (bezierarc_coord *) draw_stdcircpoints);
  }

  #if CATCH_SIGNALS
    /*Catch all signals we can apart from SIGINT.*/
    for (s = 1; s < SIG_LIMIT; s++)
      if (s != SIGINT && (Saved_Handlers [s] = signal (s, SIG_IGN)) != SIG_IGN &&
          signal (s, &Signal_Handler) == SIG_ERR)
        werr (FALSE, _kernel_last_oserror ()->errmess);

    if ((sig = setjmp (Buf)) != 0)
    { /*Save everything we can ...*/
      diagrec *diag;
      char preserve [FILENAMEMAX + 1], *scrap_dir = getenv ("WIMP$ScrapDir"),
        *draw = msgs_lookup ("Draw00");
      int f = 0;
      BOOL reported = FALSE;
      os_filestr file_str;
      os_error error;
      os_regset regs;
      _kernel_oserror *last_error;
      char last_errmess [256];

      /*Remember the error first.*/
      last_error = _kernel_last_oserror ();
      if (last_error != NULL)
        strcpy (last_errmess, last_error->errmess);
      else
        CLEAR (last_errmess);

      /*Set all handlers back to their previous setting.*/
      for (s = 1; s < SIG_LIMIT; s++)
        if (s != SIGINT && (!(Saved_Handlers [s] == SIG_ERR ||
            Saved_Handlers [s] == SIG_IGN) &&
            signal (s, Saved_Handlers [s]) == SIG_ERR))
          werr (FALSE, _kernel_last_oserror ()->errmess);

      ftracef2 ("CAUGHT SIGNAL %d!\nError was \"%s\"\n", sig, last_errmess);
      pointer_reset_shape (); /*Just in case*/

      error.errnum = 0;

      if (scrap_dir != NULL)
        for (diag = draw_startdiagchain; diag != NULL; diag = diag->nextdiag)
          if (diag->misc->options.modified)
          { if (!reported)
            { struct {int errno; char errmess [sizeof "DrawX"];} DrawX =
                  {0, "DrawX"};

              regs.r[0] = (int)&DrawX;
              regs.r[1] = (int)msgs_main_control_block ();
              regs.r[2] = NULL;
              regs.r[3] = 0;
              regs.r[4] = (int)last_errmess;
              regs.r[5] = (int)"<WIMP$ScrapDir>";
              regs.r[6] = (int)draw;
              regs.r[7] = 0;
              os_swix (MessageTrans_ErrorLookup, &regs);
              regs.r[1] = 3 /*OK and Cancel boxes*/;
              regs.r[2] = (int)draw;
              os_swix (Wimp_ReportError, &regs);
              reported = TRUE;

              if (regs.r[1] == 2) break; /*cancel*/

              /*Make the directory, if necessary.*/
              sprintf (preserve, "%s.%s", scrap_dir, draw);

              file_str.action = 8 /*create directory*/;
              file_str.name   = preserve /*name*/;
              file_str.start  = 0 /*default number of entries*/;

              if (wimpt_complain (os_file (&file_str)) != NULL)
                return 1;
            }

            sprintf (preserve, "%s.%s.%d", scrap_dir, draw, f++);
            ftracef2 ("Attempting to save %s in %s\n",
                !EMPTY (diag->misc->filename)? diag->misc->filename:
                msgs_lookup ("DrawUn"), preserve);
            (void) draw_file_file_savedirect (preserve, diag);
              /*Carry on with the next even if this one failed.*/
          }

      /*Report the error if we haven't yet.*/
      if (!reported)
      { os_error *err;
        os_regset regs;
        os_error  errblk = {0, "wimpt1"};

        regs.r[0] = (int)&errblk;
        regs.r[1] = (int)msgs_default_control_block ();
        regs.r[2] = NULL;
        regs.r[3] = 0;
        err = os_swix (MessageTrans_ErrorLookup, &regs);
        sprintf (errblk.errmess, err->errmess, last_errmess);
        wimpt_reporterror (&errblk, (wimp_errflags) 0);
      }

      return 1;
    }
  #endif

  while (--argc)
  { if (draw_file_matches (*++argv, "-print"))
    { if (--argc)
      { char *filename = *++argv;
        diagrec *diag = draw_file_loadfile (NULL, NULL, filename, 0, 0,
            via_FILE, &zero);

        if (diag)
        { ftracef1 ("main: calling draw_print_printall (0x%X)\n", diag);
          if ((error = draw_print_printall (diag)) != NULL)
            werr (FALSE, error->errmess);
          draw_dispose_diag (diag);
        }
      }
      else argc = 1;                   /*ignore bad parameters*/
    }
    else                               /*must be a filename*/
    { char *filename = *argv;
      draw_file_load_named_file (filename, NULL, NULL);
    }
  }

  while (TRUE) event_process ();

  return 0;
}

/*Similar to wimp_open_wind but opens window with pane (toolbox) correctly
  positioned in front. main is wimp_openstr for the main window. vuue->pw
  is the window handle of the pane. This routine is also used to note that
  last non-full size extent*/

void draw_open_wind (wimp_openstr *main, viewrec *vuue)

{ wimp_wstate oldmain, newmain;
  BOOL full_requested;

  /*Get main window state*/
  ftracef0 ("draw_open_wind\n");
  wimpt_noerr (wimp_get_wind_state (vuue->w, &oldmain));
  full_requested = (oldmain.flags & wimp_WFULL) == 0 &&
      (oldmain.flags & wimp_WCLICK_TOGGLE) != 0;
  ftracef1 ("full_requested: %s\n", full_requested? "true": "false");

  ftracef4 ("main suggestion: (%d, %d), (%d, %d)\n",
      main->box.x0, main->box.y0, main->box.x1, main->box.y1);
  ftracef2 ("scroll offset suggestion (%d, %d)\n", main->x, main->y);

  if (vuue->flags.showpane)
  { wimp_wstate pane;
    int pane_width, pane_height;

    pane_width = blank_pane.pane.box.x1 - blank_pane.pane.box.x0;
    pane_height = blank_pane.pane.box.y1 - blank_pane.pane.box.y0;
    ftracef2 ("pane_width %d, pane_height %d\n", pane_width, pane_height);

    #if 0 /*FIX G-RO-9755 JRC 7 Oct 1991 don't shrink main window*/
    if ((oldmain.flags & wimp_WOPEN) != 0)
    { wimp_redrawstr main_outline;

      /*Get the left border by looking at it.*/
      main_outline.w = main->w;
      wimpt_noerr (wimp_getwindowoutline (&main_outline));
      left_border = oldmain.o.box.x0 - main_outline.box.x0;
        /*wrong the very first time this window is opened*/
      right_border = main_outline.box.x1 - oldmain.o.box.x1;
        /*might be wrong, but not used anyway*/
    }
    else
    { /*Can't - just guess*/
      left_border = 4; /*yes, it's a hack*/
      right_border = 44; /*not used*/
    }

    ftracef1 ("left hand border width is %d\n", left_border);
    ftracef1 ("scroll bar width is %d\n", right_border);

    if (full_requested)
    { /*When going to full size, move the left hand edge of the window right
        so that there is space for the toolbox.*/
      int screen_width = draw_currentmode.x_wind_limit >> 8, spare_width;

      ftracef1 ("screen_width %d\n", screen_width);
      /*Make sure the window is far enough to the left that the pane fits*/
      if (main->box.x0 < pane_width)
        main->box.x1 += pane_width - main->box.x0,
        main->box.x0 = pane_width;

      /*Make sure the width of the window fits on the screen.*/
      spare_width = screen_width - left_border - right_border - pane_width;
      if (main->box.x1 - main->box.x0 > spare_width)
        main->box.x1 = main->box.x0 + spare_width;

      ftracef4 ("main modified: (%d, %d), (%d, %d)\n",
        main->box.x0, main->box.y0, main->box.x1, main->box.y1);
    }
    #endif

    /*To mimimise repaints, when main window is moving left, open pane
      window (shifted left) first, then do open main and open pane. The
      second open pane is needed in case the main window positioning was
      modified to keep it on screen.*/
    if (main->box.x0 <= oldmain.o.box.x0)
    { pane.o.w      = vuue->pw;
      /*FIX G-RO-9755 JRC 7 Oct 1991 move pane onscreen if possible*/
      pane.o.box.x1 = main->box.x0 >= 0? MAX (main->box.x0, pane_width):
          main->box.x0 + pane_width;
      pane.o.box.y1 = main->box.y1;

      pane.o.box.x0 = pane.o.box.x1 - pane_width;
      pane.o.box.y0 = pane.o.box.y1 - pane_height;

      pane.o.x = pane.o.y = 0;
      pane.o.behind = main->behind;

      ftracef2 ("opening pane before, x = %d, behind = %d\n",
          pane.o.box.x0, pane.o.behind);
      ftracef4 ("opening pane at (%d, %d), (%d, %d)\n",
          pane.o.box.x0, pane.o.box.y0, pane.o.box.x1, pane.o.box.y1);
      wimpt_noerr (wimp_open_wind (&pane.o));
    }

    /*Open main window, then open pane (based on the actual position values
      returned by wimp_open_window, in case window positioning was modified
      to keep it on screen).*/
    wimpt_noerr (wimp_get_wind_state (vuue->pw, &pane));

    /*If pane window already on screen, and trying to open main window at
      same layer as pane window, open main behind pane, to reduce flicker*/
    if ((pane.flags & wimp_WOPEN) && main->behind == pane.o.behind)
      main->behind = vuue->pw;

    ftracef2 ("opening main, x=%d, behind=%d\n",
        main->box.x0, main->behind);
    ftracef4 ("opening main at (%d, %d), (%d, %d)\n",
        main->box.x0, main->box.y0, main->box.x1, main->box.y1);
    ftracef2 ("scroll offsets (%d, %d)\n", main->x, main->y);
    wimpt_noerr (wimp_open_wind (main));       /*open main (paper) window*/

    /*FIX G-RO-9755 JRC 7 Oct 1991 move pane onscreen if possible*/
    pane.o.box.x1 = main->box.x0 >= 0? MAX (main->box.x0, pane_width):
        main->box.x0 + pane_width;
    pane.o.box.y1 = main->box.y1;

    pane.o.box.x0 = pane.o.box.x1 - pane_width;
    pane.o.box.y0 = pane.o.box.y1 - pane_height;

    /*Hitting 'back' on main window will cause 'pane' to go behind 'main' so
      read behind position of 'main' after opening*/
    { wimp_wstate main;

      wimpt_noerr (wimp_get_wind_state (vuue->w, &main));
      pane.o.behind = main.o.behind;
    }

    ftracef2 ("opening pane after, x=%d, behind=%d\n",
        pane.o.box.x0, pane.o.behind);
    wimpt_noerr (wimp_open_wind (&pane.o));
  }
  else
  { ftracef4 ("opening main at ((%d, %d), (%d, %d))\n",
        main->box.x0, main->box.y0, main->box.x1, main->box.y1);
    ftracef2 ("scroll offsets (%d, %d)\n", main->x, main->y);
    wimpt_noerr (wimp_open_wind (main));
  }

  /*Make a note of the old size*/
  wimpt_noerr (wimp_get_wind_state (vuue->w, &newmain));

  vuue->lastextent = newmain.o.box;
  vuue->lastx      = newmain.o.x;
  vuue->lasty      = newmain.o.y;
  ftracef2 ("saved scroll offsets (%d, %d)\n", vuue->lastx, vuue->lasty);
  ftracef0 ("leaving draw_open_wind\n");
}

/*------------------------------------------------------------------------*/

/*draw_createblank - create a blank sheet of paper*/

/*Claims space for and initialises diag->misc & diag->paper*/

/*In : size = initial paper size in bytes*/
/*Out: true/false for OK/no room*/


draw_fileheader draw_blank_header =

{ { filetypetext },
  majorformatversionstamp,
  minorformatversionstamp,
  { programidentity },
  { 0,0,0,0 },
};

#if (0)
static paperstate_typ blank_paperstate =

{ Paper_A4,                              /*size*/
  Paper_Landscape,                       /*options*/
  { 0,0, dbc_A4long, dbc_A4short }       /*viewlimit*/
};
#endif

static os_error *draw_createblank (int size, diagrec **diagp,
    BOOL grab_selection)

{ draw_objptr hdrptr;
  diagrec *diag;
  draw_options *opt = &draw_current_options;

  ftracef1 ("draw_createblank: grab_selection: %c\n",
      grab_selection? 'T': 'F');
  /*options opt;
  read_options (&opt); Now done at startup. JRC.*/

  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  *diagp = 0; /*incase Alloc or flex fail*/

  /*Claim a small (non shifting) block, to hold pointers to our*/
  /*main dBase, misc workspace & filename*/
  if ((diag = (diagrec *) Alloc (sizeof (diagrec))) == NULL)
    return draw_make_oserror ("DrawNR");     /*Return error*/
  ftracef1 ("draw_createblank: allocated diag: 0x%X\n", diag);

  /*diag now holds a pointer to a block in 'C's heap, dispose of this*/
  /*if an error occurs in claiming the rest of our w/s from flex*/
  size = size+3 & ~3;

  ftracef1 ("draw_createblank: claiming %d bytes of paper\n", size);
  if (FLEX_ALLOC ((flex_ptr) &diag->misc, sizeof (draw_diagstr)) == NULL)
  { Free (diag);
    return draw_make_oserror ("DrawNR");
  }

  if (FLEX_ALLOC ((flex_ptr) &diag->paper, size) == NULL)
  { FLEX_FREE ((flex_ptr) &diag->misc); /*free 1st block*/
    Free (diag);
    return draw_make_oserror ("DrawNR");
  }

  if ((diag->undo = draw_undo_new ()) == NULL)
  { FLEX_FREE ((flex_ptr) &diag->paper);
    FLEX_FREE ((flex_ptr) &diag->misc); /*free 1st block*/
    Free (diag);
    return draw_make_oserror ("DrawNR");
  }

  draw_undo_setbufsize (diag, opt->undo_size);
  draw_undo_separate_major_edits (diag);

  ftracef4 ("draw_createblank: made block for diag: 0x%X; "
      "diag->misc: 0x%X; diag->paper: 0x%X; diag->undo: 0x%X\n",
      diag, diag->misc, diag->paper, diag->undo);

  hdrptr.bytep     = diag->paper;
  *hdrptr.filehdrp = draw_blank_header;

  diag->misc->solidstart = diag->misc->solidlimit =
    diag->misc->ghoststart = diag->misc->ghostlimit = 0;
  diag->misc->stacklimit = diag->misc->bufferlimit = size;

  diag->misc->mainstate = diag->misc->substate =
    opt->mode.rect?   state_rect:
    opt->mode.elli?   state_elli:
    opt->mode.text?   state_text:
    opt->mode.select? state_sel: state_path;

  diag->misc->options.curved = opt->mode.curve || opt->mode.ccurve;
  diag->misc->options.closed = opt->mode.cline || opt->mode.ccurve;
  #if TRACE
    ftracef
    ( __FILE__, __LINE__,
      "draw_createblank: mainstate, substate (from options): "
      "%crect%celli%ctext%cselect%cline%ccurve%ccline%cccurve\n",
      opt->mode.rect? ' ': '~',
      opt->mode.elli? ' ': '~',
      opt->mode.text? ' ': '~',
      opt->mode.select? ' ': '~',
      opt->mode.line? ' ': '~',
      opt->mode.curve? ' ': '~',
      opt->mode.cline? ' ': '~',
      opt->mode.ccurve? ' ': '~'
    );
  #endif

  draw_action_set_papersize (diag, opt->paper.size,
                                  (paperoptions_typ) (opt->paper.o | Paper_Default));

  diag->misc->wantsnulls = 0;     /*Not at the moment we don't*/

  diag->misc->path.linewidth      = THIN;
  diag->misc->path.linecolour     = BLACK;
  diag->misc->path.fillcolour     = TRANSPARENT;
  diag->misc->path.pattern        = SOLID;
  diag->misc->path.join           = join_bevelled;
  diag->misc->path.endcap         = cap_butt;
  diag->misc->path.startcap       = cap_butt;
  diag->misc->path.windrule       = wind_evenodd;
  diag->misc->path.tricapwid      = 0x10;
  diag->misc->path.tricaphei      = 0x20;

  draw_set_current_font (diag, default_FONTREF,
                        default_FONTSIZEX, default_FONTSIZEY);
  diag->misc->font.textcolour     = BLACK;
  diag->misc->font.background     = WHITE;

  diag->misc->filename [0]         = 0;    /*Untitled*/
  diag->misc->options.modified    = 0;    /*Unmodified*/
  diag->misc->options.datestamped = 0;    /*Don't know where it came from.*/
  diag->misc->vuuecnt             = 0;    /*No views*/
  diag->view = 0;

  diag->prevdiag = 0;
  if (draw_startdiagchain != NULL) draw_startdiagchain->prevdiag = diag;
  diag->nextdiag = draw_startdiagchain;   /*Link diag into chain*/
  draw_startdiagchain = diag;

  /*Can't use draw_select_set (diag); because whoever used to have the
    selection won't like it, and the selection box would go wrong. Now
    done by draw_action_changestate. JRC 18 Dec '89*/
  if (diag->misc->mainstate == state_sel && grab_selection)
  { diag->misc->mainstate = (draw_state) -1; /*a random previous state to
                                     fool draw_action_changestate with*/
    ftracef0 ("draw_createblank: calling draw_action_changestate\n");
    draw_action_changestate (diag, state_sel, '?', '?', TRUE /*was FALSE. JRC 15 Mar '90*/);
  }

  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);

  *diagp = diag;
  return NULL;
}

void draw_fillwindowtitle (viewrec *vuue)

{ diagrec *diag = vuue->diag;
  int  modified = diag->misc->options.modified;
  int  vuuecnt  = diag->misc->vuuecnt;
  char name [TITLEBUFMAX], extra [256];

  ftracef0 ("draw_fillwindowtitle\n");
  /*Copy file name to local buffer*/
  sprintf (name, "%.*s", TITLEBUFMAX - 1,
      diag->misc->filename [0] != '\0'? diag->misc->filename: UNTITLED);
  ftracef1 ("name is \"%s\"\n", name);

  /*Form local buffer of extra rubbish*/
  if (vuuecnt > 1)
    sprintf (extra, "%s%d%s", (modified) ? " * " : " ", vuuecnt,
                   (vuue->flags.lock) ? msgs_lookup ("DrawG1") : "");
  else
    sprintf (extra, "%s%s", (modified) ? " *" : "",
                   (vuue->flags.lock) ? msgs_lookup ("DrawG1") : "");

  strncat (name, extra, TITLEBUFMAX - strlen (name));
  name [TITLEBUFMAX-1] = '\0';
  strcpy (vuue->title, name);
}

void draw_modified_no_undo (diagrec *diag)

{ ftracef0 ("draw_modified_no_undo\n");
  if (diag->misc->options.modified) return;

  diag->misc->options.modified = 1;
  draw_displ_redrawtitle (diag);       /*So redraw titles of other views*/
                                      /*(calls draw_fillwindowtitle)*/
}

void draw_modified (diagrec *diag)

{ ftracef0 ("draw_modified\n");
  /*draw_undo_put (diag, draw_undo__info, diag->misc->options.modified,
      -1); No longer JRC 5 August 1991*/
  draw_modified_no_undo (diag);
}

/* Write to Draw$Options */
void draw_set_dollar_options (void)

{ char *value;

  value = write_options ();
  os_swix5 (OS_SetVarVal, "Draw$Options", value,
            strlen (value), 0, VarType_String);
}

/*Create (but don't display) a view window (plus its pane),*/
/*and insert at the head of the view chain for the diagram*/
static os_error *draw_createview (diagrec *diag, viewrec **vuuep)

{ os_error *err;
  wimp_w   hand;                    /*handle for main window*/
  wimp_w   phand;                   /*handle for pane window*/
  viewrec  *vuue;
  char    *title = NULL;
  draw_options *opt = &draw_current_options;

  ftracef0 ("draw_createview\n");
  /*options  opt;
  read_options (&opt); Now done at startup. JRC.*/

  *vuuep = 0; /*incase Alloc fails*/

  if ((vuue = (viewrec *) Alloc (sizeof (viewrec))) == NULL)
    return draw_make_oserror ("DrawNR");      /*Return error*/

  /*Allocate space for title*/
  if ((title = Alloc (TITLEBUFMAX)) == NULL)
  { Free (vuue);
    return draw_make_oserror ("DrawNR");
  }

  *title = 0;

  /*vuue now holds a pointer to a block in C's heap, dispose of this if an
    error occurs in creating the window*/
  blank_view.paper.behind      = -1;            /*top window*/
  blank_view.paper.minsize     = 0x00010001;
  blank_view.paper.titleflags  = (wimp_iconflags) (blank_view.paper.titleflags | wimp_INDIRECT);
  blank_view.paper.title.indirecttext.buffer      = title;
  blank_view.paper.title.indirecttext.bufflen     = TITLEBUFMAX;
  blank_view.paper.title.indirecttext.validstring = 0;
  blank_view.paper.box.y0 = blank_position.papery0 - blank_position.yshift;

  if (blank_view.paper.box.y0 < 150)
  { blank_view.paper.box.y0 = blank_position.papery0;
    blank_view.paper.box.y1 = blank_position.papery1;
    blank_pane.pane.box.y0  = blank_position.paney0;
    blank_pane.pane.box.y1  = blank_position.paney1;
    blank_position.yshift   = 48;
  }
  else
  { blank_view.paper.box.y1 =
        blank_position.papery1 - blank_position.yshift;
    blank_pane.pane.box.y0 = blank_position.paney0  - blank_position.yshift;
    blank_pane.pane.box.y1 = blank_position.paney1  - blank_position.yshift;
    blank_position.yshift += 48;
  }

  ftracef2 ("Creating main window with offsets (%d, %d)\n",
      blank_view.paper.scx, blank_view.paper.scy);
  if (err = wimp_create_wind (&blank_view.paper, &hand), !err)
  { blank_pane.pane.behind = -1;         /*top window*/

    if (err = wimp_create_wind (&blank_pane.pane, &phand), !err)
    { /*Insert the new view at the head of the view list. N.B. the view
        list is doubly linked using prevview & nextview, with a pointer to
        the first record held in diag->view. In the first view block,
        prevview=0. In the last view block, lastview=0. If this is the
        first/only view on this diagram, prevview=nextview=0.*/

      vuue->prevview = 0;
      if (diag->view) diag->view->prevview = vuue;
      vuue->nextview = diag->view;
      diag->view = vuue;
      vuue->diag = diag;  /*Parent pointer*/

      vuue->w  = hand;
      vuue->pw = phand;
      vuue->flags.showpane = opt->toolbox;

      vuue->zoom.mul   = opt->zoom.mul;
      vuue->zoom.div   = opt->zoom.div;
      vuue->zoomfactor = (double) vuue->zoom.mul/(double) vuue->zoom.div;
      ftracef1 ("using zoom factor of %.2f\n", vuue->zoomfactor);
      vuue->flags.zoomlock = opt->zoom.lock;
      /*FIX A-RO-9898 JRC 23 Sept 1991*/
      vuue->lastzoom.mul = vuue->lastzoom.div = 1;

      { int xy;

        vuue->flags.rect    =!opt->grid.o [0];
        vuue->flags.iso     = opt->grid.o [0];
        vuue->flags.autoadj = opt->grid.o [1];
        vuue->flags.show    = opt->grid.o [2];
        vuue->flags.lock    = opt->grid.o [3];
        vuue->flags.xinch   = vuue->flags.yinch =!opt->grid.o [4];
        vuue->flags.xcm     = vuue->flags.ycm   = opt->grid.o [4];

        for (xy = 0; xy < 2; xy++)
        { vuue->gridunit [grid_Inch].space [xy]  =
             vuue->flags.xinch? opt->grid.space: 1.0;
          vuue->gridunit [grid_Inch].divide [xy] =
             vuue->flags.xinch? opt->grid.divide: 4;
          vuue->gridunit [grid_Cm].space [xy] =
             vuue->flags.xcm? opt->grid.space: 1.0;
          vuue->gridunit [grid_Cm].divide [xy]   =
             vuue->flags.xcm? opt->grid.divide: 2;
        }

        vuue->gridcolour = draw_colours.grid;
        draw_grid_setstate (vuue);
      }

      vuue->title = title;
      diag->misc->vuuecnt++;     /*Another view*/

      draw_toolbox_showstate (diag, vuue, TRUE);
      draw_displ_redrawtitle (diag);     /*So redraw titles of other views*/
                                        /*(calls draw_fillwindowtitle)*/
      *vuuep = vuue;

      return (0);                    /*exit OK*/
    }

    /*Creating the pane window failed, so dispose of main window*/
    wimp_delete_wind (hand);
  }

  /*Creation of main (or pane) window failed, so free Alloced block*/
  Free (title);
  Free (vuue);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  return err;
}

static os_error *draw_openview (viewrec *vuue)

{ wimp_openstr p; /*record for opening window*/

  ftracef0 ("draw_openview\n");
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  p.w      = vuue->w;
  p.box.x0 = blank_view.paper.box.x0;
  p.box.y0 = blank_view.paper.box.y0;
  p.box.x1 = blank_view.paper.box.x1;
  p.box.y1 = blank_view.paper.box.y1;
  p.x      = blank_view.paper.scx;
  p.y      = blank_view.paper.scy;
  ftracef2 ("draw_openview: scx %d, scy %d\n", p.x, p.y);

  p.behind = -1;

  ftracef0 ("draw_openview: draw_setextent\n");
  draw_setextent (vuue);
  ftracef0 ("draw_openview: draw_open_wind\n");
  draw_open_wind (&p, vuue);      /*open paper & toolbox windows*/

  ftracef0 ("draw_openview: draw_register_events\n");
  draw_register_events (vuue);
  ftracef0 ("draw_openview: win_activeinc\n");
  win_activeinc ();

  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  return 0;  /*exit ok*/
}

os_error *draw_opennewview (diagrec *diag, viewrec **vuuep)

{ os_error *err;
  viewrec *vuue;

  ftracef0 ("draw_opennewview\n");
  /*options  opt;
  read_options (&opt); Now done at startup (and redundant here anyway). JRC*/
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);

  if ((err = draw_createview (diag, &vuue)) != NULL)
    return err;
  ftracef1 ("draw_opennewview: created view with zoom factor %.2f\n",
      vuue->zoomfactor);

  if ((err = draw_openview (vuue)) != NULL)
  { dispose_view (vuue);
    return err;
  }

  *vuuep = vuue;
  /*Give the input focus to the new view*/
  draw_enter_claim_focus (diag, vuue);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  return NULL;
}

os_error *draw_opennewdiag (diagrec **diagp, BOOL grab_selection)

{ os_error *err;
  diagrec *diag;
  viewrec *vuue;

  ftracef0 ("draw_opennewdiag\n");

  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  if ((err = draw_createblank (default_PAPERSIZE, &diag, grab_selection)) !=
      NULL)
    return err;

  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  if ((err = draw_opennewview (diag, &vuue)) != NULL)
  { draw_dispose_diag (diag);
    return err;
  }

  *diagp = diag;
  return 0;
}

void draw_dispose_diag (diagrec *diag)

{ viewrec *vuue, *next;

  ftracef1 ("draw_dispose_diag: removing diag 0x%X from chain\n", diag);

  /*Get rid of the diag pointer in draw_selection->owner, if any.
     (J R C 22nd Sep 1993)*/
  if (diag == draw_selection->owner)
    draw_select_set (NULL);

  /*Dispose of any views - usually be 0..1 of them*/
  for (vuue = diag->view; vuue != 0; vuue = next)
  { next = vuue->nextview;
    dispose_view (vuue);
  }

  /*Remove this diag from the view list:
     IF not first record THEN point our predecessor at our successor
                         ELSE point startdiagchain at our successor
     IF not last record  THEN point our successor at our predecessor*/
  if (diag->prevdiag)
    diag->prevdiag->nextdiag = diag->nextdiag;
  else
    draw_startdiagchain = diag->nextdiag;

  if (diag->nextdiag) diag->nextdiag->prevdiag = diag->prevdiag;

  /*Free the memory*/
  draw_undo_dispose (diag->undo);
  FLEX_FREE ((flex_ptr) &diag->paper);
  FLEX_FREE ((flex_ptr) &diag->misc);
  Free (diag);

  ftracef0 ("exit draw_dispose_diag\n");
}


/*set_current_font (diagrec *diag, int fref, int fsizex,int fsizey)*/

/*fref is an index into a list of font names*/
/*fsizex & fsizey are in 1/640ths point*/

void draw_set_current_font (diagrec *diag, int fref, int fsizex,int fsizey)

{ ftracef0 ("draw_set_current_font\n");
  diag->misc->font.typeface  = fref;
  diag->misc->font.typesizex = fsizex;
  diag->misc->font.typesizey = fsizey;
}
