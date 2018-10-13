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
/* -> c.DrawEnter
 *
 * Enter objects in Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.10
 * History: 0.10 - 12 June 1989 - header added. Old code weeded.
 *                                upgraded to drawmod
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <swis.h>

#include "os.h"
#include "bbc.h"
#include "wimp.h"
#include "wimpt.h"
#include "win.h"
#include "event.h"
#include "drawmod.h"
#include "jpeg.h"
#include "dbox.h"
#include "font.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawDispl.h"
#include "DrawEdit.h"
#include "DrawEnter.h"
#include "DrawObject.h"

null_owner_str  draw_enter_null_owner  = {0,0,-1};
focus_owner_str draw_enter_focus_owner = {0,0,-1};

#if 1 /*JRC*/
static void Bound_Pointer (int x0, int y0, int x1, int y1)

{  int ox, oy;
   char buf [20];

   ftracef0 ("draw_enter: Bound_Pointer\n");

   ox = bbc_vduvar (bbc_OrgX);
   oy = bbc_vduvar (bbc_OrgY);

   x0 -= ox, y0 -= oy;
   x1 -= ox, y1 -= oy;

   buf [0] = 1;

   buf [1] = x0;
   buf [2] = x0 >> 8;
   buf [3] = y0;
   buf [4] = y0 >> 8;

   buf [5] = x1;
   buf [6] = x1 >> 8;
   buf [7] = y1;
   buf [8] = y1 >> 8;

   os_swi2 (OS_Word, 21, (int) buf);
}

static void Unbound_Pointer (void)

{ ftracef0 ("draw_enter: Unbound_Pointer\n");
  Bound_Pointer
   (  0,
      0,
      bbc_vduvar (bbc_XWindLimit) << draw_currentmode.xeigfactor,
      bbc_vduvar (bbc_YWindLimit) << draw_currentmode.yeigfactor
   );
}
#endif

static void claim_idle_for_null_owner (void)

{ ftracef0 ("draw_enter: claim_idle_for_null_owner\n");

  win_claim_idle_events (draw_enter_null_owner.hand);

  if (draw_enter_null_owner.hand == -1)
    event_setmask ((wimp_emask) (event_getmask () | wimp_EMNULL));
  else
    event_setmask ((wimp_emask) (event_getmask () & ~wimp_EMNULL));

  #if 1 /*JRC*/
    if
    ( draw_enter_null_owner.hand != -1 &&
      draw_enter_null_owner.diag != 0 &&
      ( draw_enter_null_owner.diag->misc->mainstate == state_sel ||
        draw_enter_null_owner.diag->misc->mainstate == state_edit ||
        draw_enter_null_owner.diag->misc->substate == state_zoom ||
        draw_enter_null_owner.diag->misc->substate == state_printerI ||
        draw_enter_null_owner.diag->misc->substate == state_printerO
    ) )
    { wimp_wstate state;

      /*Bound the mouse to this window, just for fun*/
      wimpt_noerr (wimp_get_wind_state (draw_enter_null_owner.hand,
          &state));
      Bound_Pointer (state.o.box.x0, state.o.box.y0,
          state.o.box.x1, state.o.box.y1);
    }
    else
      /*Unbound the mouse*/
      Unbound_Pointer ();
  #endif
}

/* Steal null ownership (as far as the wimp is concerned) from any other
   owner. All current claimants still receive nulls in order of diag number
*/
void draw_enter_claim_nulls(diagrec *diag, viewrec *vuue)

{ ftracef0 ("draw_enter_claim_nulls\n");

  draw_enter_null_owner.diag = diag;
  draw_enter_null_owner.vuue = vuue;
  draw_enter_null_owner.hand = vuue->w;

  ftracef3 ("trying to claim idle events for diag=%d,vuue=%d,hand=%d\n",
      draw_enter_null_owner.diag,
      draw_enter_null_owner.vuue,
      draw_enter_null_owner.hand);

  diag->misc->wantsnulls = vuue;  /* direct movements etc here */
  claim_idle_for_null_owner();

  ftracef3("idle events claimed for diag=%d,vuue=%d,hand=%d\n",
      draw_enter_null_owner.diag,
      draw_enter_null_owner.vuue,
      draw_enter_null_owner.hand);
}

/* Give null ownership to any view that wants it, */
/* if no one does, switch off null events.        */
void draw_enter_release_nulls(diagrec *diag)

{ diagrec *i;

  ftracef0 ("draw_enter_release_nulls\n");
  ftracef2 ("nulls released by diag=%d,vuue=%d\n",
      diag, diag->misc->wantsnulls);

  diag->misc->wantsnulls     = 0;
  draw_enter_null_owner.diag = 0;    /* Assume noone wants nulls */
  draw_enter_null_owner.vuue = 0;
  draw_enter_null_owner.hand = -1;

  /* Give nulls to first interested diagram */
  for (i = draw_startdiagchain; i != 0; i = i->nextdiag)
    if (i->misc != 0)
      if (i->misc->wantsnulls != 0)
      { draw_enter_null_owner.diag = i;
        draw_enter_null_owner.vuue = i->misc->wantsnulls;
        draw_enter_null_owner.hand = draw_enter_null_owner.vuue->w;

        ftracef3("  then reclaimed by diag=%d,vuue=%d,hand=%d\n",
              draw_enter_null_owner.diag,
              draw_enter_null_owner.vuue,
              draw_enter_null_owner.hand);

        break;
      }

  claim_idle_for_null_owner();
}

/* Claim focus, setting caret position in the window, but not displaying it */
void draw_enter_claim_focus(diagrec *diag,viewrec *vuue)

{ ftracef0 ("draw_enter_claim_focus\n");
  draw_enter_focus_owner.diag = diag;
  draw_enter_focus_owner.vuue = vuue;
  draw_enter_focus_owner.hand = vuue->w;

  draw_get_focus();
  draw_displ_showcaret_if_up(diag);

  ftracef3("draw_enter_claim_focus: diag: 0x%X; vuue: 0x%X, hand: %d\n",
      draw_enter_focus_owner.diag, draw_enter_focus_owner.vuue,
      draw_enter_focus_owner.hand);
}

/* Any other window that wants input focus will claim it when entered */
void draw_enter_release_focus(void)

{ ftracef2("draw_enter_release_focus: diag: 0x%X; vuue: 0x%X\n",
      draw_enter_focus_owner.diag, draw_enter_focus_owner.vuue);

  draw_enter_focus_owner.diag = 0;
  draw_enter_focus_owner.vuue = 0;
  draw_enter_focus_owner.hand = -1;

  draw_get_focus(); /* Discards focus */
}

/* Claim both nulls and focus - occurs often enough to be worth having its
   own�function
 */
void draw_enter_claim (diagrec *diag, viewrec *vuue)

{ ftracef0 ("draw_enter_claim\n");
  draw_enter_claim_nulls(diag, vuue);
  draw_enter_claim_focus(diag, vuue);
}

os_error *draw_enter_select(diagrec *diag,viewrec *vuue, draw_objcoord *pt)

{ os_error *err = 0;
  int needspace;

  ftracef0 ("draw_enter_select\n");

  /* Easier to do space checks here than get part way through adding   */
  /* something, detect a problem and have to undo things               */
  /* In general we ask for far more space than needed, just to be safe */

  switch (diag->misc->substate)
  { case state_path:
      needspace = sizeof(draw_pathstrhdr) +
                                  4*sizeof(largest_path_str);
    break;

    case state_path_move:
    case state_path_point1:
    case state_path_point2:
    case state_path_point3:
      needspace = 4*sizeof(largest_path_str);
    break;

    case state_text:
    case state_text_caret:
    case state_text_char:
      needspace = 4*sizeof(draw_textstr);
    break;

    case state_rect :
      needspace = sizeof(draw_pathstrhdr) +
                              sizeof(path_pseudo_rectangle);
                  /* over-zealous by sizeof(path_movestr) */
    break;

    case state_elli :
      needspace = sizeof(draw_pathstrhdr) +
                              sizeof(path_pseudo_ellipse);
      /* over-zealous by sizeof(path_movestr) */
    break;

    case state_rect_drag:                       /* no space needed */
    case state_elli_drag:
      needspace = 0;
    break; /* do a complete! */
                /* if dashed, we might not have room for pattern, */
                /* 'complete' regards this as unimportant and    */
                /* gives us a rect/elli without a pattern        */

    default:
      return 0;
  }

  if (err = draw_obj_checkspace(diag, needspace), err) return err;

  /* From here on, we don't expect any errors, and any that occur will */
  /* muck up our construction line redrawing, but catch them anyway    */
  draw_displ_eor_cons2(diag); /* remove construction lines */

  switch (diag->misc->substate)
  {
    case state_path:                                       /* click at 'a' */
      draw_enter_claim(diag,vuue);
      draw_obj_start(diag, draw_OBJPATH);
      /* Fall into move case for start of path */

    case state_path_move:
      ftracef2("|<state2> move_to(%d,%d)| ",pt->x,pt->y);
      diag->misc->pta_off = diag->misc->pty_off = diag->misc->ghostlimit -
                                                  sizeof(drawmod_path_termstr);
      draw_obj_addpath_move(diag, pt);                                 /* a */

      diag->misc->ptz_off =diag->misc->ghostlimit-sizeof(drawmod_path_termstr);
      if (diag->misc->options.curved)                  /* a-m */
        draw_obj_addpath_curve(diag, pt, pt, pt);
      else
        draw_obj_addpath_line(diag, pt);
      diag->misc->substate = state_path_point1;
      break;

    case state_path_point1:                                  /* click at 'b' */
      { int ptx_off = diag->misc->ptx_off = diag->misc->pty_off;
        int pty_off = diag->misc->pty_off = diag->misc->ptz_off;
        int ptz_off = diag->misc->ptz_off = diag->misc->ghostlimit-
                                               sizeof(drawmod_path_termstr);
        diag->misc->ptb_off = pty_off;

        if (diag->misc->options.curved)              /* a-b-m */
        { ftracef2("|<state3> curve_to(%d,%d)| ",pt->x,pt->y);

          draw_enter_straightcurve(diag, ptx_off, pty_off);
          draw_obj_addpath_curve(diag, pt, pt, pt);

          draw_enter_fit_corner(diag, ptx_off, pty_off, ptz_off);
        }
        else
        { ftracef2("|<state3> line_to(%d,%d)| ",pt->x,pt->y);
          draw_obj_addpath_line(diag, pt);
        }

        diag->misc->substate = state_path_point2;
        break;
      }

    case state_path_point2:                                  /* click at 'c' */
      { int ptw_off = diag->misc->ptw_off = diag->misc->ptx_off;
        int ptx_off = diag->misc->ptx_off = diag->misc->pty_off;
        int pty_off = diag->misc->pty_off = diag->misc->ptz_off;
        int ptz_off = diag->misc->ptz_off = diag->misc->ghostlimit-
                                               sizeof(drawmod_path_termstr);

        if (diag->misc->options.curved)            /* a-b-c-m */
        { ftracef2("|<state4> curve_to(%d,%d)| ",pt->x,pt->y);

          draw_enter_straightcurve(diag, ptx_off,pty_off);
          draw_obj_addpath_curve(diag, pt, pt, pt);
        }
        else
        { ftracef2("|<state4> line_to(%d,%d)| ",pt->x,pt->y);

          draw_obj_addpath_line(diag, pt);
        }

        draw_enter_fit_corner(diag, ptw_off, ptx_off, pty_off);  /* a-(b)-c */
        draw_enter_fit_corner(diag, ptx_off, pty_off, ptz_off);

        diag->misc->substate = state_path_point3;
        break;
      }

    case state_path_point3:                                  /* click at 'd' */
      { int ptw_off = diag->misc->ptw_off = diag->misc->ptx_off;
        int ptx_off = diag->misc->ptx_off = diag->misc->pty_off;
        int pty_off = diag->misc->pty_off = diag->misc->ptz_off;
        int ptz_off = diag->misc->ptz_off = diag->misc->ghostlimit-
                                               sizeof(drawmod_path_termstr);

        if (diag->misc->options.curved)               /* -d-m */
        { ftracef2("|<state4> curve_to(%d,%d)| ",pt->x,pt->y);

          draw_enter_straightcurve(diag, ptx_off, pty_off);
          draw_obj_addpath_curve(diag, pt, pt, pt);
        }
        else
        { ftracef2("|<state4> line_to(%d,%d)| ",pt->x,pt->y);

          draw_obj_addpath_line(diag, pt);
        }

        draw_enter_fit_corner(diag, ptw_off,ptx_off,pty_off); /* a-b-(c)-d */
        draw_enter_fit_corner(diag, ptx_off,pty_off,ptz_off);

        diag->misc->substate = state_path_point3;
        break;
      }

/*********************/
/* enter a complete rectangle - made of a move, 4 lines, close and term */

    case state_rect:
      draw_enter_claim(diag, vuue);
      draw_obj_start(diag, draw_OBJPATH);

      ftracef0("enter_rectangle\n");
      diag->misc->pta_off = diag->misc->ghostlimit
                            - sizeof(drawmod_path_termstr);
      draw_obj_addpath_move(diag, pt);                          /* top left */
      draw_obj_addpath_line(diag, pt);                         /* top right */
      draw_obj_addpath_line(diag, pt);                      /* bottom right */
      draw_obj_addpath_line(diag, pt);                       /* bottom left */
      draw_obj_addpath_line(diag, pt);                  /* back to top left */
      draw_obj_addpath_close(diag);                          /* and close it */

      diag->misc->substate = state_rect_drag;
      break;

    case state_rect_drag:
      err = draw_enter_complete(diag);
      break;

/* enter a complete ellipse (well a circle radius zero) */
/*  made of a move, 4 curves, close and term */

    case state_elli:
      draw_enter_claim(diag, vuue);
      draw_obj_start(diag, draw_OBJPATH);

      ftracef0("enter_ellipse\n");
      diag->misc->pta_off = diag->misc->ghostlimit
                            - sizeof(drawmod_path_termstr);

      draw_obj_addpath_move(diag, pt);          /* NW */
      draw_obj_addpath_curve(diag, pt,pt,pt);   /* NE */
      draw_obj_addpath_curve(diag, pt,pt,pt);   /* SE */
      draw_obj_addpath_curve(diag, pt,pt,pt);   /* SW */
      draw_obj_addpath_curve(diag, pt,pt,pt);   /* back to NW */
      draw_obj_addpath_close(diag);             /* and close it */

      diag->misc->ellicentre = *pt;
      diag->misc->substate = state_elli_drag;
      break;

    case state_elli_drag:
      err = draw_enter_complete(diag);
      break;

/*********************/
    case state_text_caret:
    case state_text_char:             /* Complete this line and drop into.. */
                                      /* start line, reclaiming nulls is OK */
      if (diag->misc->substate == state_text_caret)
        draw_obj_flush(diag);
      else
      {
        draw_obj_addtext_term(diag);
        draw_obj_finish(diag);
        draw_modified(diag);
      }
      /* Fall into state_text case for start of next object */

    case state_text:                   /* Start textline */
      draw_obj_start(diag, draw_OBJTEXT);
      draw_obj_setcoord(diag, pt);
      draw_obj_settext_font(diag, diag->misc->font.typeface,
                                  diag->misc->font.typesizex,
                                  diag->misc->font.typesizey);
      draw_obj_settext_colour(diag, diag->misc->font.textcolour,
                                    diag->misc->font.background);

      diag->misc->substate = state_text_caret;

      draw_enter_claim(diag, vuue);
      draw_displ_showcaret(vuue);

/*--2--*/
      break;
  }

  draw_displ_eor_cons3(diag); /* show construction lines */
  return(err);
}

/* ------------------------------------------------------------------------- */
/*                                                                           */
/* draw_enter_doubleselect                                                   */
/*                                                                           */
/* 'Complete' object eg                                                      */
/*    Complete path entry (open or autoclosed)                               */
/*    Complete line of text                                                  */
/*                                                                           */
/* ------------------------------------------------------------------------- */

os_error *draw_enter_doubleselect(diagrec *diag)

{ ftracef0 ("draw_enter_doubleselect\n");
  return(draw_enter_complete(diag));
}

/* ------------------------------------------------------------------------- */
/*                                                                           */
/* Complete the current object                                               */
/*                                                                           */
/* If the only problem is 'no room to add dash pattern', this is ignored and */
/* the object completed with no pattern (ie solid outline).                  */
/* All other errors are returned                                             */
/*                                                                           */

/*>>>>>try reordering this - return if mainstate==substate, then call */
/*  draw_eor_cons, try to lump path/rect/ellipse style setting together */

/* Subsidiary routines first */

/* finish path, (path/rectangle/ellipse) by adding style info - colour, dash */
/* pattern etc; completing & drawing object; mark diagram as modified;       */
/* release nulls and focus                                                   */

static void finish_path(diagrec *diag,int obj_off)

{ ftracef0 ("draw_enter: finish_path\n");

  draw_obj_addpath_term(diag);
  draw_obj_setpath_colours(diag, diag->misc->path.fillcolour,
                                 diag->misc->path.linecolour,
                                 diag->misc->path.linewidth);
  draw_obj_setpath_style(diag, diag->misc->path.join,
                               diag->misc->path.startcap,
                               diag->misc->path.endcap,
                               diag->misc->path.windrule,
                               diag->misc->path.tricapwid,
                               diag->misc->path.tricaphei);

  /* assume caller will check for space for dashpattern */
  /* or doesn't care if it gets ommitted                */
  if (diag->misc->path.pattern)
    draw_obj_setpath_dashpattern(diag, diag->misc->path.pattern);

  draw_obj_finish(diag);
  draw_enter_release_nulls(diag);

  diag->misc->substate = diag->misc->mainstate;

  draw_modified(diag);
  draw_displ_redrawobject(diag, obj_off);  /* repaint just this object */
}

/* draw_enter_closepath                                               */
/* N.B. assumes  1) checkspace already called,                        */
/*               2) substate >= state_path_point2, ie >= 2 points in dBase */

static void draw_enter_closepath(diagrec *diag)

{ drawmod_pathelemptr pta, ptz;

  int ptb_off = diag->misc->ptb_off;
  int ptx_off = diag->misc->ptx_off;
  int pty_off = diag->misc->pty_off;
  int ptz_off = diag->misc->ptz_off;

  ftracef0 ("draw_enter_closepath\n");

  pta.bytep = diag->misc->pta_off + diag->paper;
  ptz.bytep = diag->misc->ptz_off + diag->paper;

  if (ptz.bezier->tag == path_bezier)
  {
    ptz.bezier->x3 = pta.move2->x;   /* curve back to start point */
    ptz.bezier->y3 = pta.move2->y;
    ftracef2("closepath with curve_to(%d,%d)| ",pta.move2->x,pta.move2->y);
  }
  else
  {
    ptz.lineto->x = pta.move2->x;     /* line back to start point */
    ptz.lineto->y = pta.move2->y;     /*>>>>>try to remove this */
                                     /*would need mods to fitcorner stuff?*/
    ftracef2("closepath with line_to(%d,%d)| ",pta.move2->x,pta.move2->y);
  }

  draw_obj_addpath_close(diag);

  draw_enter_fit_corner(diag, ptx_off,pty_off,ptz_off);     /* a-b-..-(y)-a  */
  draw_enter_fit_corner(diag, pty_off,ptz_off,ptb_off);     /* (a)-b..-y-(a) */
}

static void draw_enter_openpath(diagrec *diag)

{ int ptz_off = diag->misc->ptz_off;
  drawmod_pathelemptr ptz;

  ftracef0 ("draw_enter_openpath\n");

  ptz.bytep = ptz_off + diag->paper;

  draw_obj_delete(diag, ptz_off, (ptz.lineto->tag == path_lineto) ?
                                   sizeof(drawmod_path_linetostr) :
                                   sizeof(drawmod_path_bezierstr));
}

/* Close or open, depending on flag */
static void draw_enter_endpath(diagrec *diag, int close)

{ ftracef0 ("draw_enter_endpath\n");

  if (close) draw_enter_closepath(diag);
  else       draw_enter_openpath(diag);
}

os_error *draw_enter_complete(diagrec *diag)

{ os_error *err = 0;
  int obj_off = diag->misc->solidlimit; /* Where object will be after */
                                        /* the finish! >>>> UGH       */

  ftracef0 ("draw_enter_complete\n");

  /* If in state_path_point1, do a delete last point. */
  /*   If we've done a MoveTo, this removes it and sets state1a */
  /*   If only subpath, this kills the whole path object and sets state1 */

  if (diag->misc->substate == state_path_point1)
    draw_enter_delete(diag);

  switch (diag->misc->substate)
  {
  /*>>>>>>OK for state_path->state_path_point1 then complete*/
  /* not nice for state_path_move->state_path_point1 complete, cos it kills
     earlier subpaths */
  /* maybe we should do nothing */

    case state_path_point1:/* Only happens if above draw_enter_delete failed */
    case state_path:
      ftracef0 ("draw_enter_complete: state_path/state_path_point1\n");
    break;

    case state_path_move:
    case state_path_point2:
    case state_path_point3:
      ftracef0 ("draw_enter_complete: state_path_move/state_path_point2/state_path_point3\n");
      if (err = draw_obj_checkspace(diag, 2 * sizeof(largest_path_str)), err)
        return(err);

      draw_displ_eor_skeleton(diag);         /* remove construction lines */
                       /* N.B. a redrawobject call leaves traces of lines */
                       /*      when the 'complete' menu option is used    */

      /* if state_path_move subpath is already open/closed as needed */
      /* else close path/junk trailing line                         */
      if (diag->misc->substate != state_path_move)
        draw_enter_endpath(diag, diag->misc->options.closed);

      finish_path(diag,obj_off);
    break;

    case state_rect_drag:
    case state_elli_drag:
      ftracef0 ("draw_enter_complete: state_rect_drag/state_elli_drag\n");
      draw_displ_eor_skeleton(diag);           /* remove construction lines */
      finish_path(diag,obj_off);
    break;

    case state_rect:
    case state_elli:
      ftracef0 ("draw_enter_complete: state_rect/state_elli\n");
    break;

    case state_text_caret:
    case state_text_char:
      ftracef0 ("draw_enter_complete: state_text_caret/state_text_char\n");
      if (diag->misc->substate == state_text_caret)
        draw_obj_flush(diag);
      else
      { if (err = draw_obj_checkspace(diag, sizeof( int )), err) return err;

        draw_obj_addtext_term(diag);
        draw_obj_finish(diag);

        /* Redraw the completed object */
        draw_displ_redrawobject(diag, obj_off);

        /* Set modified flag */
        draw_modified(diag);
      }

      draw_get_focus(); /* Kills caret but keeps focus */
      diag->misc->substate = state_text;
    break;

    case state_text:
      ftracef0 ("draw_enter_complete: state_text\n");
    break;
  }
  return(err);
}

/* Scan a path from given firstele and return the offset to the path element */
/* that precedes the given currele.                                          */
/* If this doesn't exist return firstele_off                                 */
static int findprevelement(diagrec *diag, int firstele_off, int currele_off)

{ drawmod_pathelemptr ptr, prevele, currele;

  ftracef0 ("draw_enter: findprevelement\n");

  prevele.bytep = ptr.bytep = firstele_off + diag->paper;
  currele.bytep = currele_off + diag->paper;

  while (ptr.bytep < currele.bytep)
    switch (ptr.end->tag)
    { case path_move_2:
      case path_lineto:
        prevele.move2 = ptr.move2++;
        break;

      case path_bezier:
        prevele.bezier = ptr.bezier++;
        break;

      case path_closeline:
        prevele.closeline = ptr.closeline++;
        break;
    }

  return(prevele.bytep - diag->paper);
}

/* Scan a path object,                                                 */
/*  find its last subpath, assign to pt(a,b, w,x,y,z)_off and substate */
static void findlastsubpath(diagrec *diag, int hdr_off)

{ draw_objptr hdrptr;
  drawmod_pathelemptr pta, ptb, ptw, ptx, pty, ptz, p;

  ftracef0 ("draw_enter: findlastsubpath\n");

  hdrptr.bytep = hdr_off + diag->paper;
  p = draw_obj_pathstart(hdrptr);

  pta.move2 = ptb.move2 = ptw.move2 =ptx.move2 = pty.move2 = ptz.move2 = 0;

  while (p.end->tag != path_term)
  {
    ptw.move2 = ptx.move2; ptx.move2 = pty.move2;
    pty.move2 = ptz.move2; ptz.move2 = p.move2;

    switch (p.move2->tag)
    { case path_move_2:
        ptw.move2  = ptx.move2 = pty.move2 = 0;
        pta.move2  = p.move2++;
        ptb.lineto = p.lineto;
        break;

      case path_lineto:
        p.lineto += 1;
        break;

      case path_bezier:
        p.bezier += 1;
        break;
    }
    if (p.closeline->tag == path_closeline) p.closeline += 1;
  }

  diag->misc->pta_off  = pta.bytep - diag->paper;
  diag->misc->ptb_off  = ptb.bytep - diag->paper;
  diag->misc->pty_off  = pty.bytep - diag->paper;
  diag->misc->ptz_off  = ptz.bytep - diag->paper;
  diag->misc->substate = state_path_point3;

  if (ptx.move2 == 0)
  { diag->misc->substate = state_path_point1; diag->misc->ptx_off = 0; }
  else
    diag->misc->ptx_off = ptx.bytep - diag->paper;

  if (ptw.move2 == 0)
  { diag->misc->substate = state_path_point2; diag->misc->ptw_off = 0; }
  else
    diag->misc->ptw_off = ptw.bytep - diag->paper;
}

  /* delete last point entered */
  /*
   state_path      } do nothing
   state_path_move }

   state_path_point1  pta=pty -> MoveTo
                      ptz -> (Line/Curve)To
                      do nothing

   state_path_point2  pta=ptx -> MoveTo
                      pty -> (Line/Curve)To
                      ptz -> (Line/Curve)To
                      delete line/curve given by pty, -> state_path_point3

   state_path_point3  pta=ptw -> MoveTo
                      ptx -> (Line/Curve)To
                      pty -> (Line/Curve)To
                      ptz -> (Line/Curve)To
                      delete line/curve given by pty, -> state_path_point2
   OR
   state_path_point3  ptw -> (Line/Curve)To
                      ptx -> (Line/Curve)To
                      pty -> (Line/Curve)To
                      ptz -> (Line/Curve)To
                      delete line/curve given by pty, stay in state_path_point3
*/

void draw_enter_delete(diagrec *diag)

{ ftracef0 ("draw_enter_delete\n");

  switch (diag->misc->substate)
  {
    case state_rect_drag:
    case state_elli_drag:
      draw_action_abandon(diag);    /* remove construction lines   */
      return;                       /* kill rectangle/ellipse path */

    case state_text_char:
    { draw_bboxtyp bbox1,bbox2;
      int found;
      int hdroff = *(int *) (diag->paper + diag->misc->stacklimit);
      draw_objptr hdrptr;
      hdrptr.bytep = (diag->paper + hdroff);

      found = draw_obj_findTextBox(hdrptr, &bbox1);
      bbox2 = bbox1;
      bbox2.x1 = bbox2.x0;

      draw_obj_deltext_char(diag);          /* backspace char */

      if (draw_obj_findtext_len (diag) == 0)      /* if string empty, */
        diag->misc->substate = state_text_caret; /* change state     */
      else
        if (!draw_obj_findTextBox(hdrptr, &bbox2)) found = FALSE;

        if (bbox1.y0 > bbox2.y0) bbox1.y0 = bbox2.y0;
        if (bbox1.y1 < bbox2.y1) bbox1.y1 = bbox2.y1;
        bbox1.x0 = bbox2.x1;

        if (found)
          draw_displ_redrawarea(diag, &bbox1);
        else /* Only happens if the font manager blows up */
          draw_displ_forceredraw(diag);

        draw_displ_eor_skeleton(diag); /*place caret*/
      }
      break;

    case state_path:
    case state_text:
    case state_text_caret:
    default:
      return;

    case state_path_move:
    case state_path_point1:
    case state_path_point2:
    case state_path_point3:
      break;
  }

  { drawmod_pathelemptr pty, ptz;

    int pta_off = diag->misc->pta_off;
    int ptw_off = diag->misc->ptw_off;
    int ptx_off = diag->misc->ptx_off;
    int pty_off = diag->misc->pty_off;
    int ptz_off = diag->misc->ptz_off;

    pty.bytep = pty_off + diag->paper;
    ptz.bytep = ptz_off + diag->paper;

    draw_displ_eor_cons3(diag); /* remove 2 lines (current & previous) */

    switch (diag->misc->substate)
    {
      case state_path_move:
      { int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);

        draw_displ_eor_skeleton(diag);

/*, then scan the previous subpath                      */
/*      and initialise pta,ptw,ptx,pty,ptz and substate */
              findlastsubpath(diag, hdroff);

        pta_off = diag->misc->pta_off;  /* reload cos findlastsubpath */
        ptw_off = diag->misc->ptw_off;  /* changed the lot            */
        ptx_off = diag->misc->ptx_off;
        pty_off = diag->misc->pty_off;
        ptz_off = diag->misc->ptz_off;

        ptz.bytep = ptz_off + diag->paper; /* and the heap moved????? */

        /*If subpath is closed, open it*/
        { drawmod_pathelemptr closep;

          if (ptz.bezier->tag == path_bezier)
            closep.bezier = ptz.bezier + 1;
          else
            closep.lineto = ptz.lineto+1;

          if (closep.closeline->tag == path_closeline)
            draw_obj_delete(diag, closep.bytep-diag->paper,
                               sizeof(drawmod_path_closelinestr));
        }

        if (diag->misc->options.curved)
          draw_enter_changelinecurve(diag, pty_off,ptz_off, path_bezier);
        else
          draw_enter_changelinecurve(diag, pty_off,ptz_off, path_lineto);

        ptz.bytep = ptz_off + diag->paper;

        if (ptz.bezier->tag == path_bezier)
        { ptz.bezier->x3 = diag->misc->ptzzz.x;
          ptz.bezier->y3 = diag->misc->ptzzz.y;

          draw_enter_straightcurve(diag, pty_off,ptz_off);
        }
        else
        { ptz.lineto->x = diag->misc->ptzzz.x;
          ptz.lineto->y = diag->misc->ptzzz.y;
        }
        if (diag->misc->substate > state_path_point1)
          draw_enter_fit_corner(diag, ptx_off,pty_off,ptz_off);

        draw_displ_eor_skeleton(diag);
      }
      return;

      /*  state_path_point1  pta=pty -> MoveTo
                             ptz -> (Line/Curve)To
      */
      case state_path_point1:
      { int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);
        draw_objptr hdrptr;
        drawmod_pathelemptr pta, pt_test;

        hdrptr.bytep = diag->paper + hdroff;
        pta.bytep = pta_off + diag->paper;

        /* If this is the only subpath, flush the whole object */
        pt_test = draw_obj_pathstart(hdrptr);
        if (pta.bytep == pt_test.bytep)
        { draw_obj_flush(diag);
          diag->misc->substate = state_path;
        }
        else
        {
          /* Else delete the MoveTo & (Line/Curve)To. */
          if (ptz.bezier->tag == path_bezier)
            draw_obj_delete(diag, pty_off, sizeof(drawmod_path_movestr) +
                                           sizeof(drawmod_path_bezierstr));
          else
            draw_obj_delete(diag, pty_off, sizeof(drawmod_path_movestr) +
                                           sizeof(drawmod_path_linetostr));
            diag->misc->substate = state_path_move;
        }
      }
      break;

      /*  state_path_point2  pta=ptx -> MoveTo
                             pty -> (Line/Curve)To
                             ptz -> (Line/Curve)To
      */
      case state_path_point2:
        if (pty.bezier->tag == path_bezier)
          draw_obj_delete(diag, pty_off, sizeof(drawmod_path_bezierstr));
        else
          draw_obj_delete(diag, pty_off, sizeof(drawmod_path_linetostr));

        ptz_off = pty_off;
        pty_off = ptx_off;
        diag->misc->substate = state_path_point1;

        ptz.bytep = ptz_off + diag->paper;

        if (ptz.bezier->tag == path_bezier)
          draw_enter_straightcurve(diag, pty_off,ptz_off);

        break;

      /*  state_path_point3  pta=ptw -> MoveTo OR (Line/Curve)To
                             ptx -> (Line/Curve)To
                             pty -> (Line/Curve)To
                             ptz -> (Line/Curve)To
      */
      case state_path_point3:
        if (pty.bezier->tag == path_bezier)
          draw_obj_delete(diag, pty_off, sizeof(drawmod_path_bezierstr));
        else
          draw_obj_delete(diag, pty_off, sizeof(drawmod_path_linetostr));

        ptz_off = pty_off;
        pty_off = ptx_off;
        ptx_off = ptw_off;

        if (ptx_off == pta_off)          /*ie ptx->MoveTo */
          diag->misc->substate = state_path_point2;
        else
          ptw_off = findprevelement(diag, pta_off, ptx_off);
                                         /* still in state_path_point3, */
                                         /* scan for earlier element */

        ptz.bytep = ptz_off + diag->paper;

        if (ptz.bezier->tag == path_bezier)
          draw_enter_straightcurve(diag, pty_off,ptz_off);

        draw_enter_fit_corner(diag, ptx_off,pty_off,ptz_off);

        break;
    }

    diag->misc->ptw_off = ptw_off;
    diag->misc->ptx_off = ptx_off;
    diag->misc->pty_off = pty_off;
    diag->misc->ptz_off = ptz_off;

    draw_displ_eor_cons2(diag);  /* put back one line */
  }
}

/*------------------------------------------------------------------------*/
/*                                                                        */
/* draw_enter_adjust                                                      */
/*                                                                        */
/* If in idle state, switch to edit mode, give click to edits adjust      */
/* handler                                                                */
/* If entering a path (or rectangle or ellipse), complete the object then */
/* select it for editing.                                                 */
/* In any other state, eg text entry, the click is ignored.               */
/*                                                                        */

os_error *draw_enter_adjust (diagrec *diag, draw_objcoord *pt)

{ os_error *err;

  ftracef0 ("draw_enter_adjust\n");

  if (diag->misc->mainstate == diag->misc->substate)
  { int obj_off;
    region r;

    if (draw_obj_over_object (diag, pt, &r, &obj_off))
    { draw_objptr hdrptr;

      hdrptr.bytep = diag->paper + obj_off;
      switch (hdrptr.objhdrp->tag)
      { case draw_OBJPATH:
          draw_edit_adjust (diag, pt);
        break;

        #if 0 /*doesn't work (dbox vanishes)*/
          case draw_OBJTEXT: case draw_OBJTRFMTEXT:
            draw_edit_text (diag, obj_off);
          break;
        #endif
      }
    }
  }
  else
  { int obj_off = diag->misc->solidlimit; /* Where object will be after */
                                          /* the complete! */
    switch (diag->misc->mainstate)
    { case state_path:
      case state_rect:
      case state_elli:
      case state_text:
        if (err = draw_enter_complete(diag), err) return err;

        /*Complete may have failed, or if in state_path_point1 and no
            other subpath present, deleted the object, so check it exists */
        if (diag->misc->solidlimit > obj_off)
        { if (diag->misc->mainstate != state_text)
            draw_edit_editobject(diag, obj_off);
          #if 0
          else
            draw_edit_text (diag, obj_off);
          #endif
        }
      break;
    }
  }
  return NULL;
}

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* draw_enter_movepending                                                 */
/*                                                                        */
/* 'Move' within a path                                                   */
/*    ie complete the current subpath and switch to state_path_move       */
/*       to allow a further 'path_move'.                                  */
/*                                                                        */
/* ---------------------------------------------------------------------- */

os_error *draw_enter_movepending(diagrec *diag)

{ os_error *err = 0;

  ftracef0 ("draw_enter_movepending\n");

  if ((diag->misc->mainstate == state_path) &&
      (diag->misc->substate >= state_path_point2))
  {
    if (err = draw_obj_checkspace(diag, 2 * sizeof(largest_path_str)), err)
      return(err);

    draw_displ_eor_skeleton(diag);

    draw_enter_endpath(diag, diag->misc->options.closed);

    diag->misc->substate = state_path_move;

    draw_displ_eor_skeleton(diag);
  }
  return(err);
}

/* Change line <--> curve. Also used to change from (but not to) moves */
os_error *draw_enter_changelinecurve(diagrec *diag, int prevele_off,
                                     int currele_off, draw_path_tagtype tag)
{ int sizechange = sizeof(drawmod_path_bezierstr)
                   - sizeof(drawmod_path_linetostr);
  drawmod_pathelemptr currele;

  ftracef4 ("draw_enter_changelinecurve: diag: 0x%X; prevele_off: %d; "
      "currele_off: %d; tag: %d\n",
      diag, prevele_off, currele_off, tag);

  currele.bytep = currele_off + diag->paper;

  if (currele.lineto->tag != path_lineto &&
      currele.bezier->tag != path_bezier &&
      currele.move2->tag  != path_move_2)
    return(0);

  if (currele.bezier->tag == tag) return(0);    /* No change */

  if (tag == path_lineto)
  { ftracef0 ("draw_enter_changelinecurve: changing from b�zier or move to line\n");
    currele.bytep = currele_off + diag->paper;
    if (currele.bezier->tag == path_bezier)
    { currele.lineto->tag = tag;
      currele.lineto->x = currele.bezier->x3;
      currele.lineto->y = currele.bezier->y3;

      draw_obj_delete(diag, currele_off + sizeof(drawmod_path_linetostr),
                   sizechange);
    }
    else /* Change from move */
      currele.lineto->tag = tag;

    /*Must update pathele_cb here, because noone else does it. JRC 31 Jan 1990*/
    diag->misc->pathedit_cb.over = overLineEp;
    diag->misc->pathedit_cb.cor_off = currele_off + sizeof (draw_tagtyp); /*coords of lineto after tag*/
  }
  else
  { os_error *err;
    ftracef0 ("draw_enter_changelinecurve: changing from line or move to b�zier\n");
    if ((err = draw_obj_insert(diag,
                  currele_off + sizeof(drawmod_path_linetostr), sizechange)) != NULL)
      return err;

    currele.bytep = currele_off + diag->paper;  /* here incase heap shifts */
    currele.bezier->tag = path_bezier;
    currele.bezier->x3  = currele.lineto->x;
    currele.bezier->y3  = currele.lineto->y;

    draw_enter_straightcurve(diag, prevele_off,currele_off);

    /*Must update pathele_cb here, because noone else does it. JRC 31 Jan 1990*/
    diag->misc->pathedit_cb.over = overCurveEp;
    diag->misc->pathedit_cb.cor_off = currele_off + sizeof (draw_tagtyp) + 4*sizeof (int);
      /*coords of b�zier after tag and 2 vias*/
  }
  return(0);
}

/* Change a line/curve to a move.
   If the subpath following the new move is closed, we must insert a new line
   or curve segment from the first element coordinate to the end of the move,
   to keep it all closed and thus consistent. The subpath ending in the move
   must also be closed. Currele is always either a curve or a line.

   NB! This code relies on a curve taking more space than a line plus a move.
 */

os_error *draw_enter_changeToMove(diagrec *diag, int firstele_off,
                                  int currele_off)

{ drawmod_pathelemptr currele, endele, firstele;

  ftracef0 ("draw_enter_changeToMove\n");

  currele.bytep = currele_off + diag->paper;

  /* Search for end of path starting with currele: either a move or a close */
  endele.bytep = currele.bytep;
  do
  {
    switch (endele.move2->tag)
    {
      case path_lineto: endele.lineto += 1; break;
      case path_bezier: endele.bezier += 1; break;
      /* Other cases never happen */
    }
  } while (endele.closeline->tag != path_closeline
           && endele.move2->tag  != path_move_2
           && endele.end->tag    != path_term);

  if (endele.closeline->tag != path_closeline)
  {
    if (currele.lineto->tag == path_lineto)
    { /* Open line to move: just change tag */
      currele.move2->tag = path_move_2;
    }
    else
    { /* Open curve -> line: change tag and reduce space */
      currele.move2->tag = path_move_2;

      draw_obj_delete(diag, currele_off+sizeof(drawmod_path_movestr),
               sizeof(drawmod_path_bezierstr) - sizeof(drawmod_path_movestr));
    }
  }
  else
  { int oldTag = currele.lineto->tag;

    /* Close preceding subpath, change to move and close following subpath */
    os_error *err;
    int      x, y;
    int      sizechange = 2*sizeof(drawmod_path_linetostr)
                          + sizeof(drawmod_path_closelinestr)
                          + sizeof(drawmod_path_movestr);

    if (oldTag == path_lineto)
    {
      sizechange -= sizeof(drawmod_path_linetostr);
      x = currele.lineto->x;
      y = currele.lineto->y;
    }
    else
    {
      sizechange -= sizeof(drawmod_path_bezierstr);
      x = currele.bezier->x3;
      y = currele.bezier->y3;
    }

    /* Increase/reduce space in the database */
    if (sizechange > 0)
    {
      err = draw_obj_insert(diag, currele_off, sizechange);
      if (err) return(err);
    }
    else if (sizechange < 0)
    {
      draw_obj_delete(diag, currele_off, sizechange);
    }

    currele.bytep  = diag->paper + currele_off;
    firstele.bytep = diag->paper + firstele_off;

    /* Set up the new elements */
    currele.lineto->tag = path_lineto;    /* Closing line of old subpath */
    currele.lineto->x = firstele.move2->x;
    currele.lineto->y = firstele.move2->y;
    currele.lineto += 1;

    currele.closeline->tag = path_closeline;  /* Close old subpath */
    currele.closeline += 1;

    currele.move2->tag = path_move_2;  /*Start new subpath at same place*/
    currele.move2->x = firstele.move2->x;
    currele.move2->y = firstele.move2->y;
    currele.move2 += 1;

    currele.lineto->tag = path_lineto;   /* Line joining to old path */
    currele.lineto->x = x;
    currele.lineto->y = y;
  }

  return(0);
}

os_error *draw_enter_state_changelinecurve(diagrec *diag,
                                           draw_path_tagtype tag)
{ int ptx_off = diag->misc->ptx_off;
  int pty_off = diag->misc->pty_off;
  int ptz_off = diag->misc->ptz_off;

  ftracef0 ("draw_enter_state_changelinecurve\n");

  switch (diag->misc->substate)
    { case state_path:
      case state_path_move:
        break;

      case state_path_point1:
      case state_path_point2:
      case state_path_point3:
      { os_error *err = draw_enter_changelinecurve(diag,pty_off,ptz_off,tag);
        if (err) return(err);

        if (diag->misc->substate > state_path_point1)
          draw_enter_fit_corner(diag, ptx_off,pty_off,ptz_off);

        break;
      }
    }
  return(0);
}

/* Get the end point of a line or bezier */
static void get_end_point(drawmod_pathelemptr from, draw_doublecoord *to)

{ ftracef0 ("draw_enter: get_end_point\n");

  if (from.bezier->tag == path_bezier)
  {
    to->x = from.bezier->x3;
    to->y = from.bezier->y3;
  }
  else
  {
    to->x = from.lineto->x;
    to->y = from.lineto->y;
  }
}

/* Get the length of the line between two points */
static double line_length(draw_doublecoord *a, draw_doublecoord *b)

{ double abx = a->x - b->x;
  double aby = a->y - b->y;

  ftracef0 ("draw_enter: line_length\n");

  return sqrt(abx*abx + aby*aby);
}

/* draw_enter_fit_curvecurve(a,b,c) where a,b,c are pointers            */
/*                                                                      */
/* by definition, a->tag is <line to|move to> OR <curve to>             */
/*                b->tag is <curve to>                                  */
/*                c->tag is <curve to>                                  */
/* OR                                                                   */
/*                a->tag is <curve to>                                  */
/*                b->tag is <curve to>                                  */
/*                c->tag is <line to|move to> OR <curve to>             */
/*                                                                      */

void draw_enter_fit_curvecurve(drawmod_pathelemptr a_p,
                               drawmod_pathelemptr b_p,
                               drawmod_pathelemptr c_p,
                               draw_objcoord *result)

{ draw_doublecoord a, b, c, i;

  ftracef0 ("draw_enter_fit_curvecurve\n");

  get_end_point(a_p, &a);
  b.x = b_p.bezier->x3; b.y = b_p.bezier->y3;       /* must be curveto b */
  get_end_point(c_p, &c);

  {
    double len_ab = line_length(&a, &b);
    double len_bc = line_length(&b, &c);

    if (len_ab < 0.1)
    {
      i.x = (c.x+2*b.x)/3;
      i.y = (c.y+2*b.y)/3;
    }
    else
    {
      double bc_over_ab = len_bc / len_ab;

      i.x = b.x + bc_over_ab * (a.x - b.x);
      i.y = b.y + bc_over_ab * (a.y - b.y);
    }

    { double len_ci = line_length(&i, &c);

      if (len_ci < 0.1)
      {
        result->x  = (int)b.x;
        result->y  = (int)b.y;
      }
      else
      {
        double bc_over_3ci = len_bc / (3 * len_ci);

        result->x = (int)(b.x + bc_over_3ci * (c.x-i.x));
        result->y = (int)(b.y + bc_over_3ci * (c.y-i.y));
      }
    }

    ftracef4("\n\n curve-curve: a(b)c : (%d,%d) (%d,%d) ", a.x,a.y, b.x,b.y);
    ftracef2("(%d,%d)\n",c.x,c.y);
    ftracef2(" bezier c.x1,c.y1 = (%d,%d)\n\n",result->x,result->y);
  }
}

/* draw_enter_fit_linecurve(a,b,c) where a,b,c are pointers             */
/*                                                                      */
/* by definition, a->tag is <line to|move to> OR <curve to>             */
/*                b->tag is <line to>                                   */
/*                c->tag is <curve to>                                  */
/*                                       ie a-b)c                       */
/*                                                                      */
/* OR             a->tag is <line to>                                   */
/*                b->tag is <curve to>                                  */
/*                c->tag is <line to|move to> OR <curve to>             */
/*                                       ie j(k-l passed as (l,k,j)     */
/*                                                                      */
/*                                                                      */

static void draw_enter_fit_linecurve(drawmod_pathelemptr a_p,
                                     drawmod_pathelemptr b_p,
                                     drawmod_pathelemptr c_p,
                                     draw_objcoord *result)

{ draw_doublecoord a, b, c;

  ftracef0 ("draw_enter: fit_linecurve\n");

  get_end_point(a_p, &a);
  get_end_point(b_p, &b);
  get_end_point(c_p, &c);

  { double len_ab = line_length(&a, &b);
    double len_bc = line_length(&b, &c);

    /* If a and b coincide, put the control point right on b */
    if (len_ab == 0)
    {
      result->x = (int)(b.x);
      result->y = (int)(b.y);
    }
    else
    {
      double bc_over_3ab = len_bc / (3 * len_ab);
      result->x = (int)(b.x + bc_over_3ab * (b.x-a.x));
      result->y = (int)(b.y + bc_over_3ab * (b.y-a.y));
    }

    ftracef4("line-curve: a-b)c : (%d,%d) (%d,%d) ", a.x,a.y, b.x,b.y);
    ftracef2("(%d,%d)\n", c.x,c.y);
    ftracef2("bezier c.x1,c.y1 = (%d,%d)\n",result->x,result->y);
  }
}

void draw_enter_fit_corner(diagrec *diag, int a_off, int b_off, int c_off)

{ drawmod_pathelemptr a,b,c;

  ftracef0 ("draw_enter_fit_corner\n");

  a.bytep = a_off + diag->paper;
  b.bytep = b_off + diag->paper;
  c.bytep = c_off + diag->paper;

  if (b.bezier->tag == path_bezier)
  { if (c.bezier->tag == path_bezier)
    { draw_enter_fit_curvecurve(a,b,c, (draw_objcoord *)&c.bezier->x1);
      draw_enter_fit_curvecurve(c,b,a, (draw_objcoord *)&b.bezier->x2);
    }
    else
      draw_enter_fit_linecurve(c,b,a, (draw_objcoord *)&b.bezier->x2);
  }
  else if (c.bezier->tag == path_bezier)
    draw_enter_fit_linecurve(a,b,c, (draw_objcoord *)&c.bezier->x1);
}

/* draw_enter_straightcurve(a,b) where a,b are pointers                 */
/*                                                                      */
/* by definition, b->tag is <curve to>                                  */
/*                                                                      */
/*           but, a->tag is <line to|move to> OR <curve to>             */
/*                                                                      */

void draw_enter_straightcurve(diagrec *diag, int a_off,int b_off)

{ drawmod_pathelemptr a_p, b_p;

  draw_objcoord a;
  draw_objcoord b;
  int dx,dy;

  ftracef0 ("draw_enter_straightcurve\n");

  a_p.bytep = a_off + diag->paper;
  b_p.bytep = b_off + diag->paper;

  if (a_p.bezier->tag == path_bezier)
  { a.x = a_p.bezier->x3; a.y = a_p.bezier->y3; }
  else
  { a.x = a_p.lineto->x; a.y = a_p.lineto->y; }

  b.x = b_p.bezier->x3;  b.y = b_p.bezier->y3;

  dx = (b.x-a.x)/3;
  dy = (b.y-a.y)/3;

  b_p.bezier->x1 = a.x + dx;
  b_p.bezier->y1 = a.y + dy;
  b_p.bezier->x2 = b.x - dx;
  b_p.bezier->y2 = b.y - dy;
}
