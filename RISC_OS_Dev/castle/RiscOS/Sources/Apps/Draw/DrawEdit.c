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
/*-> c.DrawEdit
 *
 * Edit objects in Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.14
 * History: 0.10 - 12 June 1989 - header added. Old code weeded.
 *                                upgraded to drawmod
 *          0.11 -  7 July 1989 - path snap added
 *          0.12 -  2 Aug  1989 - restore old state at end of edit
 *          0.13 -  9 Aug  1989 - undo changes
 *          0.14 - 24 Aug  1989 - divide path into two better
 *
 * As of 0.13, going into path edit but not making any change still queues
 * an undo.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#include "os.h"
#include "wimp.h"
#include "werr.h"
#include "dbox.h"
#include "msgs.h"
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
#include "DrawGrid.h"
#include "DrawMenu.h"
#include "DrawMenuD.h"
#include "DrawObject.h"
#include "DrawSelect.h"
#include "DrawUndo.h"

#define PI 3.1415926897946

/*--------------------------------------------------------------------*/
/*Classify objects*/

/*                                                                    */
/*objects are classed as follows                                      */
/*class = single items  0 0000 0001  single item   - path             */
/*                      0 0000 0010                  text             */
/*                      1 0000 0001  grouped items - paths only       */
/*                      1 0000 0010                  text only        */
/*                      1 0000 0011                  paths & text     */
/*                                                                    */
/*no distinction is made between grouped and nested grouped structures*/
/*                                                                    */
/*The result should be interpreted as                                 */
/*  single/not single,                                                */
/*  path(s) present/absent                                            */
/*  text(s) present/absent                                            */
/*                                                                    */

static void whatclass(draw_objptr hdrptr, class *classp)
{
  ftracef0 ("whatclass\n");
  switch (hdrptr.objhdrp->tag)
  {
    case draw_OBJTEXT:
      *classp = (class) (*classp | class_TEXT);
    break;

    case draw_OBJPATH:
      *classp = (class) (*classp | class_PATH);
    break;

    case draw_OBJGROUP:
    { int i;
      int start = sizeof(draw_groustr);
      int limit = hdrptr.objhdrp->size;
      draw_objptr objptr;

      *classp = (class) (*classp | class_GROUP);

      /*class the objects in the group */
      for (i = start ; i < limit ; i += objptr.objhdrp->size)
      { objptr.bytep = hdrptr.bytep + i;
        whatclass(objptr, classp);               /*may recurse*/
      }
    }
    break;

    case draw_OBJSPRITE:
      *classp = (class) (*classp | class_SPRITE);
    break;

    case draw_OBJTRFMTEXT:
      *classp = (class) (*classp | class_TEXT);
    break;

    case draw_OBJTRFMSPRITE:
      *classp = (class) (*classp | class_SPRITE);
    break;
  }
}

static int over_grabbable_object(diagrec *diag, draw_objcoord *pt,
                                pathedit_str *editblk)
{
  region regionv;
  int offsetv;
  int found = draw_obj_over_object(diag, pt, &regionv, &offsetv);

  ftracef0 ("over_grabbable_object\n");
  editblk->over     = overSpace;
  editblk->obj_off  = editblk->sub_off  = editblk->fele_off =    /*assume*/
  editblk->pele_off = editblk->cele_off = editblk->cor_off = -1; /*not found*/

  if (found)
  { draw_objptr hdrptr;               /*found an object, but can*/
    class classv = (class) 0;                 /*we edit it?             */

    hdrptr.bytep = diag->paper + offsetv;

    whatclass(hdrptr, &classv);

    /*We can only edit paths*/
    if (classv == class_PATH)
    {
      editblk->over    = overObject;
      editblk->obj_off = offsetv;
      editblk->sub_off = offsetv;

      return(1);    /*editable object found*/
    }
  }
  return(0);   /*not over object, or not editable*/
}

/*----------------------------------------------------------------------*/

/*curves are scanned in the order: endpoint(x3,y3) then bez1(x1,y1)     */
/*then bez2(x2,y2) to ensure that a bezier point can always be separated*/
/*from an end point, if over it                                         */

/*returns TRUE if anywhere over an object*/

/*N.B. bezier control points can fall outside the BBox, in this case*/
/*     a hit returns 'TRUE' and 'overCurveB(1/2)',                  */
/*     a near miss returns 'FALSE'                                  */

static int whatpoint(diagrec *diag,pathedit_str *cbp, draw_bboxtyp *box)
{
  draw_objptr hdrptr;
  region over     = overSpace;
  int fele_off = -1;
  int pele_off = -1;
  int cele_off = -1;
  int  cor_off = -1;

  ftracef0 ("whatpoint\n");
  if (cbp->obj_off < 0 || cbp->sub_off < 0) return(0);/*no selected object*/

  hdrptr.bytep = cbp->sub_off + diag->paper;

  if (draw_box_overlap (draw_displ_bbox (hdrptr), box)) over = overObject;

  switch (hdrptr.objhdrp->tag)
  {
    case draw_OBJPATH:
    { drawmod_pathelemptr pathptr, endptr, prevptr;
      int lastMove = 0;

      pathptr      = draw_obj_pathstart(hdrptr);
      endptr.bytep = hdrptr.bytep + hdrptr.pathp->size;
      prevptr      = pathptr;

      while (pathptr.bytep < endptr.bytep)
      { switch (pathptr.end->tag)
        { case path_term:
          case path_closeline:
            pathptr.closeline++;
          break;

          case path_move_2:
            lastMove = pathptr.bytep - diag->paper;

            if (draw_box_within((draw_objcoord *)&pathptr.move2->x, box))
            {
              over     = overMoveEp;
              cele_off = pathptr.bytep - diag->paper;
              pele_off = prevptr.bytep - diag->paper;
              cor_off  = (char*)(&pathptr.move2->x) - diag->paper;
              fele_off = lastMove;
            }
            prevptr.move2 = pathptr.move2++;
          break;

          case path_lineto:
            if (draw_box_within((draw_objcoord *)&pathptr.lineto->x, box))
            {
              over     = overLineEp;
              pele_off = prevptr.bytep - diag->paper;
              cele_off = pathptr.bytep - diag->paper;
              cor_off  = (char*)(&pathptr.lineto->x) - diag->paper;
              fele_off = lastMove;
            }
            prevptr.lineto = pathptr.lineto++;
          break;

          case path_bezier:
          { char *from = NULL;

            if (draw_box_within((draw_objcoord *)&pathptr.bezier->x3, box))
            {
              over = overCurveEp;
              from = (char*)&pathptr.bezier->x3;
            }
            if (draw_box_within((draw_objcoord *)&pathptr.bezier->x1, box))
            {
              over = overCurveB1;
              from = (char*)&pathptr.bezier->x1;
            }
            if (draw_box_within((draw_objcoord *)&pathptr.bezier->x2, box))
            {
              over = overCurveB2;
              from = (char*)&pathptr.bezier->x2;
            }

            if (from)
            {
              pele_off = prevptr.bytep - diag->paper;
              cele_off = pathptr.bytep - diag->paper;
              cor_off  = from - diag->paper;
              fele_off = lastMove;
            }
            prevptr.bezier = pathptr.bezier++;
          }
          break;
        }
      }
    }
    break;
  }

  if (over == overSpace) return (0);

  cbp->over     = over;
  cbp->fele_off = fele_off;
  cbp->pele_off = pele_off;
  cbp->cele_off = cele_off;
  cbp->cor_off  = cor_off;

  return(1);
}

/*Set undo at start of a path editing*/
static void set_undo(diagrec *diag, int obj_off)
{
  draw_objptr hdrptr;
  hdrptr.bytep = diag->paper + obj_off;

  ftracef0 ("setundo\n");
  /*Put a conceptual delete. This will be balanced by a conceptual insert*/
  draw_undo_put(diag, draw_undo__delete, obj_off, hdrptr.objhdrp->size);
  diag->misc->pathedit_cb.changed = FALSE;
}

/*grab object for editing, including starting the undo for it*/
/*assumes cbp->(obj_off & sub_off) are valid*/
static void grab_this(diagrec *diag, draw_objcoord *pt, pathedit_str *cbp)
{
  draw_bboxtyp box;
  int          obj_off = diag->misc->pathedit_cb.obj_off;

  ftracef0 ("grab_this\n");
  draw_box_get_test_box(pt, &box);

  /*Start undo*/
  set_undo(diag, obj_off);

  whatpoint(diag, cbp, &box);

  draw_displ_eor_skeleton(diag); /*No point when the object's just been
    invalidated.*/
  draw_displ_redrawobject(diag, obj_off); /*Which way round?*/

  /*Stack the object to allow proper insert/delete with update of size field*/
  diag->misc->stacklimit = diag->misc->bufferlimit; /*flatten nesting stack*/

  /*Push object*/
  diag->misc->stacklimit -= sizeof(int);
  *(int*)(diag->paper + diag->misc->stacklimit) = obj_off;
}

/*------------------------------------------------------------------------*/

/*Are we over an object that is selected for editing*/
static int over_grabbed_object(diagrec *diag, draw_objcoord *pt,
    pathedit_str *cbp)
{
  int hit;
  pathedit_str newdata = *cbp;
  draw_bboxtyp box;

  ftracef0 ("over_grabbed_object\n");
  draw_box_get_test_box(pt, &box);
  hit = whatpoint(diag, &newdata, &box);  /*TRUE if over object*/

  if (hit && (newdata.cele_off > -1))
  {
    if (newdata.cele_off != cbp->cele_off)
    {                                    /*selected element changed*/
      draw_displ_eor_highlightskeleton(diag);  /*unhighlight old line*/
      *cbp = newdata;                          /*pass back new data  */
      draw_displ_eor_highlightskeleton(diag);  /*  highlight new line*/
    }
    else
    { *cbp = newdata;        /*selected element unchanged, but control*/
                             /*point may have, so pass back new data  */
    }
  }
  else
    cbp->over = overObject;      /*over object, preserve selected element */

  return(hit);
}

/*---------------------------------------------------------------------------*/

/*find the path object that covers (x,y) that occurs just before*/
/*object obj_off                                                */
/*This allows repeated adjust clicks to cycle through objects   */

static void previous_path(diagrec *diag, int obj_off, draw_objcoord *pt,
                          pathedit_str *editblk)
{ int found = obj_off;
  int i;
  draw_objptr hdrptr;

  ftracef0 ("previous_path\n");
  /*Scan the data base and return the last path whose bbox surrounds
     the point (x,y) that occurs before object obj_off.
     If not found continue search and find last path in dBase that
     surrounds point (x,y).
 */
  for (i = diag->misc->solidstart; i < diag->misc->solidlimit;
       i += hdrptr.objhdrp->size)
  { hdrptr.bytep = diag->paper + i;

    if (hdrptr.objhdrp->tag == draw_OBJPATH)
    { ftracef2("testing (%d,%d) ", pt->x, pt->y);
      ftracef4("against (%d,%d, %d,%d)\n", hdrptr.objhdrp->bbox.x0,
                                    hdrptr.objhdrp->bbox.y0,
                                    hdrptr.objhdrp->bbox.x1,
                                    hdrptr.objhdrp->bbox.y1);

      if (draw_box_within(pt, &hdrptr.objhdrp->bbox))
        if (i != obj_off || found == obj_off)
          found = i;          /*over body of object*/
    }
  }

  editblk->over    = overObject;
  editblk->obj_off = found;
  editblk->sub_off = found;

  editblk->fele_off = editblk->pele_off =        /*any new path returned*/
  editblk->cele_off = editblk->cor_off  = -1;    /*unhighlighted        */
}

/*---------------------------------------------------------------------------*/

/*Claim the edit, as a result of a state change.*/
void draw_edit_claim_edit(diagrec *diag)
{
  ftracef0 ("draw_edit_claim_edit\n");
  diag->misc->pathedit_cb.obj_off =
  diag->misc->pathedit_cb.sub_off = -1;

  diag->misc->stacklimit = diag->misc->bufferlimit; /*flatten nesting stack*/
}

static void clear_edit(diagrec *diag)
{
  int obj_off = diag->misc->pathedit_cb.obj_off;

  ftracef2("clear_edit: diag: %d; pathedit_cb.obj_off: %d\n", diag, obj_off);

  /*remove skeleton, redraw object*/
  if (obj_off >= 0)
  {
    draw_objptr hdrptr;

    hdrptr.bytep = diag->paper + obj_off;

    draw_obj_bound_object(hdrptr);    /*update bbox*/
    draw_displ_eor_skeleton(diag);
    draw_displ_redrawobject(diag, obj_off);

    /*Record undo information: a conceptual insert*/
    draw_undo_put(diag, draw_undo__insert, obj_off, hdrptr.objhdrp->size);
  }

  diag->misc->stacklimit = diag->misc->bufferlimit; /*flatten nesting stack*/
}

/*Restore the state that we in force before we entered edit mode*/
/*Note that if we call restore state, then the call to
   draw_action_changestate will always result in a call to
   draw_edit_release_edit. So callers of this function need not call
   clear_edit, or clear the object offset
*/
static void restore_state(diagrec *diag, int obj_off)
{
  ftracef0 ("restore_state\n");
  draw_action_changestate(diag, diag->misc->save.state,
                                diag->misc->save.opts.curved,
                                diag->misc->save.opts.closed,
                                FALSE);

  if (diag->misc->mainstate == state_sel && obj_off != -1)
    /*Reselect the object*/
    draw_select_object(diag, obj_off);

  diag->misc->pathedit_cb.obj_off = -1;
}

void draw_edit_release_edit(diagrec *diag)
{
  ftracef0 ("draw_edit_release_edit\n");
  clear_edit(diag);
  diag->misc->pathedit_cb.obj_off = -1;
}

void draw_edit_select(diagrec *diag)
{
  ftracef0 ("draw_edit_select\n");
  restore_state(diag, diag->misc->pathedit_cb.obj_off);
}

/*Change state, preserving old one*/
static void set_enter_state(diagrec *diag)
{
  ftracef0 ("set_enter_state\n");
  diag->misc->save.state = diag->misc->mainstate;
  diag->misc->save.opts  = diag->misc->options;

  draw_undo_separate_major_edits(diag);

  draw_action_changestate(diag, state_edit, 0,0, FALSE);
}

void draw_edit_adjust(diagrec *diag, draw_objcoord *pt)
{
  ftracef0 ("draw_edit_adjust\n");
  /*If we are not already in edit mode, change state and save old state*/
  if (diag->misc->mainstate != state_edit)
    set_enter_state(diag);

  /*Check the adjust was not over the object already being edited (if any)*/
  if (!over_grabbed_object(diag, pt, &diag->misc->pathedit_cb))
  {
    int obj_off = diag->misc->pathedit_cb.obj_off;

    /*Finish edit on old object*/
    clear_edit(diag);

    /*Check edit was over an editable object*/
    if (over_grabbable_object(diag, pt, &diag->misc->pathedit_cb))
      grab_this(diag, pt, &diag->misc->pathedit_cb);
    else
      restore_state(diag, obj_off);
  }
}

void draw_edit_doubleadjust(diagrec *diag, draw_objcoord *pt)
{
  ftracef0 ("draw_edit_doubleadjust\n");
  /*We forbid double adjust if the edit was entered from select*/
  if (diag->misc->save.state != state_sel
      && over_grabbed_object(diag, pt, &diag->misc->pathedit_cb))
  { int current_off = diag->misc->pathedit_cb.obj_off;
    pathedit_str prev;

    previous_path(diag, current_off, pt, &prev);

    if (current_off != prev.obj_off)
    {
      clear_edit(diag);

      diag->misc->pathedit_cb = prev;      /*tunnel, grab previous obj*/
      grab_this(diag, pt, &diag->misc->pathedit_cb);
    }
  }
}

/*Record that path has changed. Also redraw skeleton if asked nicely*/
static void edit_modified(diagrec *diag, BOOL redraw)
{
  ftracef0 ("edit_modified\n");
  draw_modified(diag);
  diag->misc->pathedit_cb.changed = TRUE;
  if (redraw)
    draw_displ_eor_skeleton(diag);
}


/*returns 0 if no selected line (ie no subpath selected)*/
/*                                                      */
/*returns 1 if line/curve selected plus                 */
/* offset to last line/curve                            */
/* offset to past line/curve, ie ->close   (if closed)  */
/*                               ->move/term (if open)  */

BOOL draw_edit_findsubpathend(diagrec *diag, int *lastele_offp,
                                    int *close_offp)
{
  drawmod_pathelemptr prevele, currele;

  ftracef0 ("draw_edit_findsubpathend\n");
  if (!draw_edit_got_pathelement(diag)) return FALSE;

  prevele.bytep = diag->misc->pathedit_cb.fele_off + diag->paper;
  currele.move2 = prevele.move2 + 1;

  while (1)
  { switch (currele.end->tag)
    {
      case path_lineto:
        prevele.lineto = currele.lineto++;
      continue;

      case path_bezier:
        prevele.bezier = currele.bezier++;
      continue;

      case path_term:
      case path_closeline:
      case path_move_2:
      break;
    }
    break;
  }

  *lastele_offp = prevele.bytep - diag->paper;

  *close_offp   = currele.bytep - diag->paper;

  return TRUE;
}

/*Set up corX elements of pathedit_cb: common to long adjust, long shift
  adjust and numeric point entry. Returns TRUE if anything changed
*/
static BOOL alter_points(diagrec *diag, draw_state state)
{
  drawmod_pathelemptr firstele, currele;

  ftracef0 ("alter_points\n");
  firstele.bytep = diag->misc->pathedit_cb.fele_off + diag->paper;
  currele.bytep  = diag->misc->pathedit_cb.cele_off + diag->paper;

  diag->misc->pathedit_cb.corA_off = diag->misc->pathedit_cb.corB_off =
  diag->misc->pathedit_cb.corC_off = diag->misc->pathedit_cb.corD_off = 0;
  edit_modified (diag, FALSE);

  if (diag->misc->pathedit_cb.over == overCurveB1 ||
      diag->misc->pathedit_cb.over == overCurveB2)
  { /*Dragging a bezier point - drag the opposite one too if shift is down*/
    ftracef1 ("alter_points: over control: setting A to %d\n",
        diag->misc->pathedit_cb.cor_off);
    diag->misc->pathedit_cb.corA_off = diag->misc->pathedit_cb.cor_off;

    /*Rest of the function is for shift-drags only.*/
    if (state == state_edit_drag1)
    { /*Bezier on previous line?*/
      drawmod_pathelemptr firstele, prevele;

      if (diag->misc->pathedit_cb.over != overCurveB1) return FALSE;

      if (diag->misc->pathedit_cb.pele_off == 0 ||
          diag->misc->pathedit_cb.pele_off == -1)
        return FALSE;

      firstele.bytep = diag->paper + diag->misc->pathedit_cb.fele_off;
      prevele.bytep = diag->paper + diag->misc->pathedit_cb.pele_off;
      if (prevele.bytep == firstele.bytep)
      { int last, term;
        (void) draw_edit_findsubpathend (diag, &last, &term);
        prevele.bytep = diag->paper + last;
      }
      ftracef1 ("alter_points: gives prevele at offset %d\n",
          (int) (prevele.bytep - diag->paper));

      if (prevele.bezier->tag == path_bezier)
      { /*record the endpoint of the previous curve, to be used as the central anchor*/
        ftracef1 ("alter_points: over end point: setting B to %d\n",
            (int) ((char *) &prevele.bezier->x3 - diag->paper));
        diag->misc->pathedit_cb.corB_off = (char *) &prevele.bezier->x3 - diag->paper;

        /*use the bez2*/
        ftracef1 ("alter_points: over end point: setting C to %d\n",
            (int) ((char *) &prevele.bezier->x2 - diag->paper));
        diag->misc->pathedit_cb.corC_off = (char *) &prevele.bezier->x2 - diag->paper;
      }
    }

    if (state == state_edit_drag2)
    { /*Bezier on next line?*/
      drawmod_pathelemptr nextele;

      if (diag->misc->pathedit_cb.over != overCurveB2) return FALSE;

      nextele.bezier = currele.bezier + 1;
      if (nextele.lineto->tag == path_closeline)
      { /*if a closeline, use the start*/
        nextele.bytep = diag->paper + diag->misc->pathedit_cb.fele_off;
        if (nextele.lineto->tag == path_move_2) /*Always does?*/
          nextele.move2++;
      }

      ftracef2 ("drag bez 2: alter_points: current segment: %d; next segment: %d\n",
          currele.bezier->tag, nextele.bezier->tag);
      if (nextele.bezier->tag == path_bezier)
      { /*record the endpoint of me, to be used as the central anchor*/
        ftracef1 ("alter_points: over end point: setting B to %d\n",
            (int) ((char *) &currele.bezier->x3 - diag->paper));
        diag->misc->pathedit_cb.corB_off = (char *) &currele.bezier->x3 - diag->paper;

        /*use the bez1*/
        ftracef1 ("alter_points: over end point: setting C to %d\n",
            (int) ((char *) &nextele.bezier->x1 - diag->paper));
        diag->misc->pathedit_cb.corC_off = (char *) &nextele.bezier->x1 - diag->paper;
      }
    }

    if (state == state_edit_drag1 || state == state_edit_drag2)
    { /*Save the ratio for tangent lengths*/
      draw_objcoord
        *coorA = (draw_objcoord *) (diag->paper + diag->misc->pathedit_cb.corA_off),
        *coorB = (draw_objcoord *) (diag->paper + diag->misc->pathedit_cb.corB_off),
        *coorC = (draw_objcoord *) (diag->paper + diag->misc->pathedit_cb.corC_off);
      int
        xA = coorA->x - coorB->x, yA = coorA->y - coorB->y,
        xC = coorC->x - coorB->x, yC = coorC->y - coorB->y;
      double
        rA = sqrt ((double) xA*(double) xA + (double) yA*(double) yA),
        thA = xA == 0 && yA == 0? 0.0: atan2 ((double) yA, (double) xA),
        rC = sqrt ((double) xC*(double) xC + (double) yC*(double) yC),
        thC = xC == 0 && yC == 0? 0.0: atan2 ((double) yC, (double) xC);

      diag->misc->pathedit_cb.ratio =
          rA < 256.0? 1.0: rC/rA; /*don't scale if radius < 1 O S unit*/
      diag->misc->pathedit_cb.angle = thC - thA;
    }

    return TRUE;
  }
  else if (diag->misc->pathedit_cb.over == overMoveEp ||
      diag->misc->pathedit_cb.over == overLineEp ||
      diag->misc->pathedit_cb.over == overCurveEp)
  { /*Dragging an endpoint. Drag it, the bezier on this line (if a curve),
      its twin at the other end of the line (if closed), and the bezier on
      the next line (if it is a curve).*/
    drawmod_pathelemptr nextele;

    if (state == state_edit_drag1 || state == state_edit_drag2)
      return FALSE;

    ftracef1 ("alter_points: over end point: setting A to %d\n",
        diag->misc->pathedit_cb.cor_off);
    diag->misc->pathedit_cb.corA_off = diag->misc->pathedit_cb.cor_off;

    /*Bezier on me?*/
    if (diag->misc->pathedit_cb.over == overCurveEp)
    { ftracef1 ("alter_points: setting C to %d\n",
          (int) ((char *) &currele.bezier->x2 - diag->paper));
      diag->misc->pathedit_cb.corC_off =
          (char *) &currele.bezier->x2 - diag->paper;
      nextele.bezier = currele.bezier + 1;
    }
    else
      nextele.lineto = currele.lineto + 1;

    /*Other end to move too?*/
    if (nextele.lineto->tag == path_closeline)
    { ftracef1 ("alter_points: setting B to %d\n",
          (int) ((char *) &firstele.move2->x - diag->paper));
      diag->misc->pathedit_cb.corB_off =
          (char *) &firstele.move2->x - diag->paper;
      nextele.move2 = firstele.move2 + 1;
    }

    /*Bezier on next line?*/
    if (nextele.bezier->tag == path_bezier)
    { /*move the bez1*/
      ftracef1 ("alter_points: setting D to %d\n",
          (int) ((char *) &nextele.bezier->x1 - diag->paper));
      diag->misc->pathedit_cb.corD_off =
          (char *) &nextele.bezier->x1 - diag->paper;
    }
    return TRUE;
  }
  else
    return FALSE;
}

/*Move points on long adjust*/
void draw_edit_longadjust(diagrec *diag,viewrec *vuue, draw_objcoord *pt)
{
  ftracef0 ("draw_edit_longadjust\n");
  if (over_grabbed_object(diag, pt, &diag->misc->pathedit_cb))
  { if (alter_points(diag, state_edit_drag))
    { diag->misc->substate = state_edit_drag;
      draw_enter_claim(diag, vuue);
    }
  }
  ftracef0("leaving draw_edit_longadjust\n");
}

/*Move points in pairs (if one is a control point) on long shift-adjust*/
void draw_edit_long_shift_adjust (diagrec *diag,viewrec *vuue, draw_objcoord *pt)
{
  ftracef0 ("draw_edit_long_shift_adjust\n");
  if (over_grabbed_object (diag, pt, &diag->misc->pathedit_cb))
  { if (alter_points (diag, state_edit_drag1))
    { diag->misc->substate = state_edit_drag1;
      draw_enter_claim (diag, vuue);
    }
    else if (alter_points (diag, state_edit_drag2))
    { diag->misc->substate = state_edit_drag2;
      draw_enter_claim (diag, vuue);
    }
    else if (alter_points (diag, state_edit_drag))
    { diag->misc->substate = state_edit_drag;
      draw_enter_claim (diag, vuue);
    }
  }
  ftracef0 ("leaving draw_edit_long_shift_adjust\n");
}

#if FALSE /*unused*/
/*Are we in edit mode, with a selected object?*/
static int draw_edit_got_pathobject(diagrec *diag)

{ ftracef0 ("draw_edit_got_pathobject\n");

  return diag->misc->mainstate == state_edit &&
      diag->misc->pathedit_cb.obj_off >= 0 &&
      diag->misc->pathedit_cb.sub_off >= 0;
}
#endif

/*Are we in edit mode, with a selected object and a highlighted line/curve
  path element?*/
int draw_edit_got_pathelement (diagrec *diag)

{ ftracef0 ("draw_edit_got_pathelement\n");
  if (diag->misc->mainstate == state_edit &&
      diag->misc->pathedit_cb.obj_off >= 0 &&
      diag->misc->pathedit_cb.sub_off >= 0 &&
      diag->misc->pathedit_cb.pele_off >= 0 &&
      diag->misc->pathedit_cb.cele_off >= 0)
  { drawmod_pathelemptr currele;

    currele.bytep = diag->misc->pathedit_cb.cele_off + diag->paper;

    return currele.lineto->tag == path_lineto ||
        currele.bezier->tag == path_bezier ||
        currele.bezier->tag == path_move_2;
          /*Moves are okay too. JRC 2 July 1991*/
  }

  return 0;
}

/*Switch to edit mode, and edit the given object*/
/*obj_off assumed to point to a path object     */
void draw_edit_editobject(diagrec *diag, int obj_off)
{
  ftracef0 ("draw_edit_editobject\n");
  /*Get into right state, saving old one*/
  set_enter_state(diag);

  /*Save old object info for undoing*/
  set_undo(diag, obj_off);

  /*Set up control block*/
  diag->misc->pathedit_cb.over     = overObject;
  diag->misc->pathedit_cb.obj_off  = obj_off;
  diag->misc->pathedit_cb.sub_off  = obj_off;
  diag->misc->pathedit_cb.fele_off = -1;
  diag->misc->pathedit_cb.pele_off = -1;
  diag->misc->pathedit_cb.cele_off = -1;
  diag->misc->pathedit_cb.cor_off  = -1;

  draw_displ_redrawobject(diag, obj_off);
  draw_displ_eor_skeleton(diag);

  /*Stack the object to allow proper insert/delete with update of size field*/
  diag->misc->stacklimit = diag->misc->bufferlimit; /*flatten nesting stack*/

  /*Push object*/
  diag->misc->stacklimit -= sizeof(int);
  *(int *) (diag->paper + diag->misc->stacklimit) = obj_off;
}

/*Routine for changing lines between lines, curves and moves*/
/*From version 0.27, assumes menu checks we are in a suitable state*/
os_error *draw_edit_changelinecurve(diagrec *diag, draw_path_tagtype tag)
{ os_error *err = 0;

  ftracef0 ("draw_edit_changelinecurve\n");
  draw_displ_eor_skeleton(diag);

  /*If we are not changing to a move, do ordinary linecurve stuff*/
  if (tag != path_move_2)
    err = draw_enter_changelinecurve(diag,
                                     diag->misc->pathedit_cb.pele_off,
                                     diag->misc->pathedit_cb.cele_off,
                                     tag);
  else
    err = draw_enter_changeToMove(diag, diag->misc->pathedit_cb.fele_off,
                                  diag->misc->pathedit_cb.cele_off);

  edit_modified(diag, TRUE);

  return err;
}

/*Find a point half way between two others*/
static void half_point(draw_objcoord *to, draw_objcoord *a, draw_objcoord *b)
{
  ftracef0 ("half_point\n");
  to->x = (a->x + b->x) / 2;
  to->y = (a->y + b->y) / 2;
}

/*Divide a curve into two*/
static void fit_mid_curve(drawmod_pathelemptr a,
                          drawmod_pathelemptr b,
                          drawmod_pathelemptr c)
{
  draw_objcoord t;
  draw_objcoord *b1 = (draw_objcoord *) &b.bezier->x1;
  draw_objcoord *b2 = (draw_objcoord *) &b.bezier->x2;
  draw_objcoord *b3 = (draw_objcoord *) &b.bezier->x3;
  draw_objcoord *c1 = (draw_objcoord *) &c.bezier->x1;
  draw_objcoord *c2 = (draw_objcoord *) &c.bezier->x2;
  draw_objcoord *c3 = (draw_objcoord *) &c.bezier->x3;
  draw_objcoord *a3 =
    (draw_objcoord *) (a.bezier->tag == path_bezier? &a.bezier->x3: &a.lineto->x);

  ftracef0 ("fit_mid_curve\n");
  half_point(b1, a3, c1);
  half_point(&t, c1, c2);
  half_point(b2, b1, &t);
  half_point(c2, c2, c3);
  half_point(c1, &t, c2);
  half_point(b3, b2, c1);
}

os_error *draw_edit_addpoint(diagrec *diag)
{ os_error *err = NULL;
  int prevele_off = diag->misc->pathedit_cb.pele_off;
  int currele_off = diag->misc->pathedit_cb.cele_off;
  drawmod_pathelemptr eleptr;
  draw_objcoord prev, curr;

  ftracef0 ("draw_edit_addpoint\n");
  if (draw_edit_got_pathelement (diag))
  { /*easier to check before unplotting current line*/
    if (eleptr.bytep = currele_off + diag->paper,
       eleptr.bezier->tag == path_move_2)
      return NULL; /*can't add point at a move (shouldn't happen, though)*/

    ftracef0 ("draw_edit_addpoint: calling draw_obj_checkspace\n");
    if ((err = draw_obj_checkspace (diag, sizeof (largest_path_str))) != 0)
      return err;

    ftracef0 ("draw_edit_addpoint: calling draw_displ_eor_skeleton\n");
    draw_displ_eor_skeleton (diag);

    if (eleptr.bytep = prevele_off + diag->paper,
        eleptr.bezier->tag == path_bezier)
      prev.x = eleptr.bezier->x3, prev.y = eleptr.bezier->y3;
    else
      /*Could be a line or move*/
      prev.x = eleptr.lineto->x, prev.y = eleptr.lineto->y;

    if (eleptr.bytep = currele_off + diag->paper,
       eleptr.bezier->tag == path_bezier)
    { curr.x = eleptr.bezier->x3; curr.y = eleptr.bezier->y3;

      ftracef0 ("draw_edit_addpoint: path_bezier: "
          "calling draw_obj_insert\n");
      draw_obj_insert(diag, currele_off, sizeof (drawmod_path_bezierstr));
      eleptr.bytep = currele_off + diag->paper;

      eleptr.bezier->tag = path_bezier;

      { drawmod_pathelemptr prev, next;

        prev.bytep = diag->paper + prevele_off;
        next.bytep = diag->paper + currele_off +
            sizeof (drawmod_path_bezierstr);
        ftracef0 ("draw_edit_addpoint: calling fit_mid_curve\n");
        fit_mid_curve (prev, eleptr, next);
      }
    }
    else
    { curr.x = eleptr.lineto->x; curr.y = eleptr.lineto->y;

      ftracef0 ("draw_edit_addpoint: NOT path_bezier: "
          "calling draw_obj_insert\n");
      draw_obj_insert(diag, currele_off, sizeof (drawmod_path_linetostr));
      eleptr.bytep = currele_off + diag->paper;
      ftracef0 ("draw_edit_addpoint: calling half_point\n");
      half_point ((draw_objcoord *) &eleptr.lineto->x, &curr, &prev);
    }

    ftracef0 ("draw_edit_addpoint: calling edit_modified\n");
    edit_modified (diag, TRUE);
  }

  return NULL;    /*Any errors were caught earlier*/
}

/*On entry selected element is Move/Line/Curve*/

/*The following element sequences are legal, selected element in capitals

  MOVE {line/curve}          the start of an open path, so quit.
                             (in a closed path, the MOVE is covered by the
                              final {LINE/CURVE}CLOSE sequence and should
                              never get selected).

  {LINE/CURVE} {line/curve}     middle of subpath, remove selected element

  {line/curve} {LINE/CURVE} {move/term}  end of open subpath,
                                         remove selected element

  {line/curve} {LINE/CURVE} close      wrap point on closed subpath, assign
                                       endpoint of preceding line/curve to
                                       move at start of subpath
                                       remove selected element

  move {LINE/CURVE} close {move/term}  forms a single point/loop
                                       remove 'move {LINE/CURVE} close'

  move {LINE/CURVE} {move/term}        forms a single line/curve
                                       remove 'move {LINE/CURVE}'*/

os_error *draw_edit_deletesegment(diagrec *diag)
{
  int firstele_off = diag->misc->pathedit_cb.fele_off;
  int prevele_off  = diag->misc->pathedit_cb.pele_off;
  int currele_off  = diag->misc->pathedit_cb.cele_off;
  int deselect     = FALSE;
  int remvoff, remvsz;
  draw_objptr hdrptr;
  drawmod_pathelemptr firstele, prevele, currele, nextele;

  ftracef0 ("draw_edit_deletesegment\n");
  firstele.bytep = firstele_off + diag->paper;
  prevele.bytep  = prevele_off  + diag->paper;
  currele.bytep  = currele_off  + diag->paper;

  if (!draw_edit_got_pathelement(diag)) return(0);

  if (currele.move2->tag == path_move_2)
  { ftracef0("start of subpath\n");
    return(0);                           /*start of subpath, do nowt*/
  }

  draw_displ_eor_skeleton(diag);

  /*assume tag is Draw_PathLINE or Draw_PathCURVE*/
  remvoff = currele_off; /*assume deletion of current element*/
                         /*may delete MOVE or CLOSE as well  */
  if (currele.lineto->tag == path_lineto)
  { nextele.lineto = currele.lineto+1;
    remvsz = sizeof(drawmod_path_linetostr);
  }
  else
  { nextele.bezier = currele.bezier + 1;
    remvsz = sizeof(drawmod_path_bezierstr);
  }

  /*If at wrap point on a closed subpath pull subpath start to new
    endpoint*/
  if (nextele.closeline->tag == path_closeline)
  {
    firstele.move2->x = (currele.lineto-1)->x;
    firstele.move2->y = (currele.lineto-1)->y;

    diag->misc->pathedit_cb.pele_off = diag->misc->pathedit_cb.fele_off;
    diag->misc->pathedit_cb.cele_off = diag->misc->pathedit_cb.fele_off +
                                               sizeof(drawmod_path_movestr);
    ftracef0("repositioning MoveTo\n");
  }

  /*If deleting the end of an open subpath, don't select anything
    afterwards*/
  deselect = ((nextele.move2->tag == path_move_2) ||
              (nextele.end->tag   == path_term));

  /*if a single segment, ie move {LINE/CURVE} {move/term}*/
  /*                     OR move {LINE/CURVE} close      */
  /*delete the 'move' and optional 'close' as well       */

  if (prevele.move2->tag == path_move_2)
    switch (nextele.move2->tag)
    { case path_closeline:
        remvsz += sizeof(drawmod_path_closelinestr);
      case path_move_2:
      case path_term:
        remvoff -= sizeof(drawmod_path_movestr);
        remvsz  += sizeof(drawmod_path_movestr);

        deselect = TRUE;  /*don't highlight after the deletion*/
    }

  draw_obj_delete(diag, remvoff, remvsz);
  edit_modified(diag, FALSE);

  hdrptr.bytep = diag->misc->pathedit_cb.sub_off + diag->paper;

  if (deselect)
  { diag->misc->pathedit_cb.fele_off = diag->misc->pathedit_cb.pele_off =
    diag->misc->pathedit_cb.cele_off = diag->misc->pathedit_cb.cor_off = -1;
  }

  /*If all subpaths have been deleted, delete the rest of the object (hdr &
     term) and restore state. Also end the undo, so all it has is the redraw
     and delete we put at the start.*/

  firstele = draw_obj_pathstart(hdrptr);      /*first element in object*/

  if (firstele.end->tag == path_term)
  {
    draw_obj_delete_object(diag);
    diag->misc->pathedit_cb.obj_off = -1; /*Stop reselection*/
    restore_state(diag, -1);

    return(0);
  }

  draw_displ_eor_skeleton(diag);

  return(0);    /*Cannot produce errors ?*/
}

/*Flatten join - applies to a single endpoint*/
os_error *draw_edit_flatten_join (diagrec *diag)

{ drawmod_pathelemptr currele, nextele;
  draw_path_tagtype curr, next;

  ftracef0 ("draw_edit_flatten_join\n");
  currele.bytep = diag->paper + diag->misc->pathedit_cb.cele_off;
  curr = currele.lineto->tag;

  if (curr == path_lineto)
    nextele.lineto = currele.lineto + 1;
  else if (curr == path_bezier)
    nextele.bezier = currele.bezier + 1;
  else
    return NULL;

  if (nextele.lineto->tag == path_closeline)
  { /*if a closeline, use the start*/
    nextele.bytep = diag->paper + diag->misc->pathedit_cb.fele_off;
    if (nextele.lineto->tag == path_move_2) /*Always does?*/
      nextele.move2++;
  }

  next = nextele.lineto->tag;
  ftracef2 ("draw_edit_flatten_path: curr: %d; next: %d\n",
      curr, next);

  if (!(next == path_lineto || next == path_bezier)) return NULL;
    /*next must be line or curve*/
  if (!(curr == path_bezier || next == path_bezier)) return NULL;
    /*at least one must be a curve*/

  if (curr == path_bezier && next == path_bezier)
  { int dx1, dy1, dx2, dy2;
    double length1, length2, diff, angle, angle1, angle2, c, s;

    dx1 = currele.bezier->x3 - currele.bezier->x2;
    dy1 = currele.bezier->y3 - currele.bezier->y2;
    angle1 = dx1 == 0 && dy1 == 0? 0.0: atan2 ((double) dy1, (double) dx1);
    length1 = sqrt ((double) dx1*(double) dx1 + (double) dy1*(double) dy1);
    ftracef2 ("draw_edit_flatten_path: angle1: %f; length1: %d\n", angle1,
        length1);

    dx2 = nextele.bezier->x1 - currele.bezier->x3;
    dy2 = nextele.bezier->y1 - currele.bezier->y3;
    angle2 = dx2 == 0 && dy2 == 0? 0.0: atan2 ((double) dy2, (double) dx2);
    length2 = sqrt ((double) dx2*(double) dx2 + (double) dy2*(double) dy2);
    ftracef2 ("draw_edit_flatten_path: angle2: %f; length2: %d\n", angle2,
        length2);

    diff = fmod (angle2 - angle1 + 16*PI, 2*PI);
    angle = diff < PI? diff/2.0 + angle1: diff/2.0 + angle1 + PI;
    c = cos (angle), s = sin (angle);
    ftracef1 ("draw_edit_flatten_path: angle: %f\n", angle);

    /*adjust each bezier to have the same angle, but with the same lengths
        as before*/
    draw_displ_eor_skeleton (diag);
    currele.bezier->x2 = currele.bezier->x3 - (int) (length1*c);
    currele.bezier->y2 = currele.bezier->y3 - (int) (length1*s);

    nextele.bezier->x1 = currele.bezier->x3 + (int) (length2*c);
    nextele.bezier->y1 = currele.bezier->y3 + (int) (length2*s);
    edit_modified (diag, /*redraw?*/ TRUE);
  }
  else if (curr == path_bezier)
  { /*Get the required angle for currele*/
    int dx, dy;
    double length, angle;

    dx = nextele.lineto->x - currele.bezier->x3;
    dy = nextele.lineto->y - currele.bezier->y3;
    angle = dx == 0 && dy == 0? 0.0: atan2 ((double) dy, (double) dx);

    /*get the required length*/
    dx = currele.bezier->x3 - currele.bezier->x2;
    dy = currele.bezier->y3 - currele.bezier->y2;
    length = sqrt ((double) dx*(double) dx + (double) dy*(double) dy);

    /*adjust my bezier 2 to point the other way from the given one,
      but with the same length*/
    draw_displ_eor_skeleton (diag);
    ftracef2 ("draw_edit_flatten_path: length: %f; angle: %f\n", length,
        angle);
    currele.bezier->x2 = currele.bezier->x3 - (int) (length*cos (angle));
    currele.bezier->y2 = currele.bezier->y3 - (int) (length*sin (angle));
    edit_modified (diag, /*redraw?*/ TRUE);
  }
  else if (next == path_bezier)
  { /*Get the required angle for nextele. This needs the start point of curr!*/
    int dx, dy;
    double length, angle;

    drawmod_pathelemptr prevele;
    draw_objcoord s;

    prevele.bytep = diag->paper + diag->misc->pathedit_cb.pele_off;

    switch (prevele.lineto->tag)
    { case path_bezier:
        s.x = prevele.bezier->x3, s.y = prevele.bezier->y3;
      break;
      case path_move_2:
      case path_lineto:
        s.x = prevele.lineto->x, s.y = prevele.lineto->y;
      break;
    }
    dx = currele.lineto->x - s.x;
    dy = currele.lineto->y - s.y;
    angle = dx == 0 && dy == 0? 0.0: atan2 ((double) dy, (double) dx);

    /*get the required length*/
    dx = currele.lineto->x - nextele.bezier->x1;
    dy = currele.lineto->y - nextele.bezier->y1;
    length = sqrt ((double) dx*(double) dx + (double) dy*(double) dy);

    /*adjust my bezier 1 to point the other way from the given one,
      but with the same length*/
    draw_displ_eor_skeleton (diag);
    ftracef2 ("draw_edit_flatten_path: length: %f; angle: %f\n", length,
        angle);
    nextele.bezier->x1 = currele.lineto->x + (int) (length*cos (angle));
    nextele.bezier->y1 = currele.lineto->y + (int) (length*sin (angle));
    edit_modified (diag, /*redraw?*/ TRUE);
  }

  return NULL;
}

os_error *draw_edit_openpath(diagrec *diag,viewrec *vuue)
{
  int lastele_off, end_off;
  drawmod_pathelemptr endptr;

  ftracef0 ("draw_edit_openpath\n");
  if (draw_edit_findsubpathend(diag, &lastele_off,&end_off))
  { /*returns TRUE if line/curve selected*/

    endptr.bytep = diag->paper + end_off;

    if (endptr.closeline->tag == path_closeline)
    {
      /*We have a selected an closed subpath, so open it*/
      draw_displ_eor_skeleton(diag);

      { trans_str jog;
        draw_grid_jog(vuue, &jog);

        (endptr.lineto-1)->x += jog.dx;
        (endptr.lineto-1)->y += jog.dy;
      }

      draw_obj_delete(diag, end_off, sizeof(drawmod_path_closelinestr));
      edit_modified(diag, TRUE);
    }
  }
  return(0);
}

os_error *draw_edit_closepath(diagrec *diag)
{ os_error *err = 0;
  int lastele_off,end_off;
  drawmod_pathelemptr endptr;

  ftracef0 ("draw_edit_closepath\n");
  if (draw_edit_findsubpathend(diag, &lastele_off,&end_off))
  { /*returns TRUE if line/curve selected*/

    endptr.bytep = diag->paper + end_off;

    if (endptr.closeline->tag != path_closeline)
    {
      /*We have a selected an open subpath, so try to close it*/
      draw_displ_eor_skeleton(diag);

      if (err = draw_obj_insert
                (diag, end_off, sizeof(drawmod_path_closelinestr)), !err)
      { drawmod_pathelemptr firstele;
        firstele.bytep = diag->paper + diag->misc->pathedit_cb.fele_off;
        endptr.bytep   = diag->paper + end_off;  /*in case heap moved*/

        (endptr.lineto-1)->x = firstele.move2->x; /*snap end of path to*/
        (endptr.lineto-1)->y = firstele.move2->y; /*initial move(x,y)  */
        endptr.closeline->tag = path_closeline;
      }

      edit_modified(diag, TRUE);
    }
  }

  return err;
}

/*Adjust a point, specified numerically: input is via a dbox*/
#define numpoint_do      ((dbox_field) 0)
#define numpoint_x       ((dbox_field) 1)
#define numpoint_y       ((dbox_field) 2)
#define numpoint_inch    ((dbox_field) 3)
#define numpoint_cm      ((dbox_field) 4)
#define numpoint_abandon ((dbox_field) 5)
#define numpoint_maxBuffer 13

static BOOL draw_adjust_inches = TRUE;

/*Force the point fields to the given values*/
static void draw_edit_adjustSet(dbox dialogue, draw_objcoord *pt)
{
  int      divide = (draw_adjust_inches) ? dbc_OneInch : dbc_OneCm;

  ftracef0 ("draw_edit_adjustSet\n");
  draw_setfield(dialogue, numpoint_x, (double)pt->x / divide);
  draw_setfield(dialogue, numpoint_y, (double)pt->y / divide);

  dbox_setnumeric(dialogue, numpoint_inch,  draw_adjust_inches);
  dbox_setnumeric(dialogue, numpoint_cm  , !draw_adjust_inches);
}

static BOOL get_num(dbox d, int field, double *n)
{
  char     buffer[numpoint_maxBuffer];

  ftracef0 ("get_num\n");
  dbox_getfield(d, field, buffer, numpoint_maxBuffer);
  if (sscanf (buffer, "%lf", n) < 1)
  { *n = 0;
    return FALSE;
  }
  else
    return TRUE;
}

/*Get current coordinate values. TRUE on good values*/
static BOOL draw_edit_adjustGet(dbox dialogue, draw_objcoord *pt)

{ double x, y;
  int mult = draw_adjust_inches? dbc_OneInch: dbc_OneCm;

  ftracef0 ("draw_edit_adjustGet\n");
  if (!(get_num (dialogue, numpoint_x, &x) &&
      get_num (dialogue, numpoint_y, &y)))
    return FALSE;

  x *= mult, y *= mult;

  if (!(-MAX_COORD <= x && x <= MAX_COORD))
  { werr (FALSE, msgs_lookup("DrawO1"), (double) MAX_COORD/(double) mult);
    return FALSE;
  }

  if (!(-MAX_COORD <= y && y <= MAX_COORD))
  { werr (FALSE, msgs_lookup("DrawO1"), (double) MAX_COORD/(double) mult);
    return FALSE;
  }

  pt->x = (int) (x + 0.5);
  pt->y = (int) (y + 0.5);

  return TRUE;
}

os_error *draw_edit_adjustpoint(diagrec *diag)
{ os_error *err = NULL;
  dbox d;
  BOOL filling = TRUE;
  draw_objcoord pt;
  drawmod_pathelemptr element;

  ftracef0 ("draw_edit_adjustpoint\n");
  /*Create dialogue box and set current values*/
  if ((d = dbox_new ("NumPoint")) == 0)
    return NULL;

  /*Supply raw event handler for help messages*/
  dbox_raw_eventhandler (d, &help_dboxrawevents, (void *) "COORDS");

  element.bytep = diag->misc->pathedit_cb.cele_off + diag->paper;

  switch (diag->misc->pathedit_cb.over)
  { case overMoveEp:
      ftracef0 ("draw_edit_adjustpoint: overMoveEp\n");
      pt.x = element.move2->x;
      pt.y = element.move2->y;
    break;

    case overLineEp:
      ftracef0 ("draw_edit_adjustpoint: overLineEp\n");
      pt.x = element.lineto->x;
      pt.y = element.lineto->y;
    break;

    case overCurveB1:
      ftracef0 ("draw_edit_adjustpoint: overCurveB1\n");
      pt.x = element.bezier->x1;
      pt.y = element.bezier->y1;
    break;

    case overCurveB2:
      ftracef0 ("draw_edit_adjustpoint: overCurveB2\n");
      pt.x = element.bezier->x2;
      pt.y = element.bezier->y2;
    break;

    case overCurveEp:
      ftracef0 ("draw_edit_adjustpoint: overCurveEp\n");
      pt.x = element.bezier->x3;
      pt.y = element.bezier->y3;
    break;

    default: /*This should never happen*/
      ftracef0 ("draw_edit_adjustpoint: THIS NEVER HAPPENS!\n");
      pt.x = pt.y = 0;
    break;
  }
  draw_edit_adjustSet (d, &pt);

  dbox_show (d);

  while (filling)
  { switch (dbox_fillin (d))
    { case numpoint_do:
        /*Adjust the point*/
        if (draw_edit_adjustGet (d, &pt))
        { /*Alter the point according to its type*/
          if (alter_points (diag, state_edit_drag))
          { /*Don't allow points to be moved too far*/
            if (pt.x > dbc_WorldX0 && pt.x < dbc_WorldX1 &&
                pt.y > dbc_WorldY0 && pt.y < dbc_WorldY1)
            { /*Rub out old object*/
              ftracef0 ("draw_edit_adjustpoint: "
                  "calling draw_displ_eor_skeleton\n");
              draw_displ_eor_skeleton (diag);
              ftracef0 ("draw_edit_adjustpoint: "
                  "calling draw_obj_path_move\n");
              draw_obj_path_move (diag, &pt);
              ftracef0 ("draw_edit_adjustpoint: calling edit_modified\n");
              edit_modified (diag, TRUE);
            }
          }
          ftracef0 ("draw_edit_adjustpoint: calling dbox_persist\n");
          filling = dbox_persist ();
        }
      break;

      case numpoint_abandon:
      case dbox_CLOSE:  /*Get out without adding a point*/
        filling = FALSE;
      break;

      case numpoint_inch:
        draw_edit_adjustGet(d, &pt);
        draw_adjust_inches = TRUE;
        draw_edit_adjustSet(d, &pt);
      break;

      case numpoint_cm:
        draw_edit_adjustGet(d, &pt);
        draw_adjust_inches = FALSE;
        draw_edit_adjustSet(d, &pt);
      break;

      case numpoint_x:
      case numpoint_y:
      default:        /*Do nothing*/
      break;
    }
  }

  dbox_dispose (&d);
  return err;
}

/*Grid snap every point in the path*/
os_error *draw_edit_snappath(diagrec *diag, viewrec *vuue)
{
  draw_objptr         hdrptr;
  drawmod_pathelemptr pathptr;

  ftracef0 ("draw_edit_snappath\n");
  draw_displ_eor_skeleton(diag);          /*Rub out old object*/

  /*Find the path*/
  hdrptr.bytep = diag->misc->pathedit_cb.obj_off + diag->paper;
  pathptr      = draw_obj_pathstart(hdrptr);
  edit_modified(diag, FALSE);

  /*Snap each point, including control points*/
  while (pathptr.end->tag != path_term)
    switch (pathptr.end->tag)
    { case path_move_2:
      case path_lineto:
      { int byX = pathptr.move2->x;
        int byY = pathptr.move2->y;

        draw_grid_snap(vuue, (draw_objcoord *)&pathptr.move2->x);

        byX = pathptr.move2->x - byX;     /*amount anchor moved by*/
        byY = pathptr.move2->y - byY;
        pathptr.move2++;

        if (pathptr.bezier->tag == path_bezier)
        { pathptr.bezier->x1 += byX;    /*if next element is curved*/
          pathptr.bezier->y1 += byY;    /*move its bez1            */
        }
      }
      break;

      case path_bezier:
      { int byX = pathptr.bezier->x3;
        int byY = pathptr.bezier->y3;

        draw_grid_snap(vuue, (draw_objcoord *) &pathptr.bezier->x3);

        byX = pathptr.bezier->x3 - byX;   /*amount anchor moved by*/
        byY = pathptr.bezier->y3 - byY;

        pathptr.bezier->x2 += byX;        /*move our bez2 by same amount*/
        pathptr.bezier->y2 += byY;

        pathptr.bezier++;

        if (pathptr.bezier->tag == path_bezier)
        { pathptr.bezier->x1 += byX;    /*if next element is curved*/
          pathptr.bezier->y1 += byY;    /*move its bez1            */
        }
      }
      break;

      case path_closeline:
        pathptr.closeline++;
      break;
    }

  draw_displ_eor_skeleton(diag);          /*Draw new object*/
  return 0; /*There is never any error*/
}
/*------------------------------------------------------------------------*/
void draw_edit_text (diagrec *diag, int obj_off)
    /*Used if we came from keystroke or Adjust-click on text line*/

{ dbox text_dbox;

  ftracef0 ("draw_edit_text\n");

  /*Set the caret position, so dbox is in a reasonable position. J R C 4th
      Oct 1993*/
  draw_get_focus ();

  if ((text_dbox = dbox_new ("text")) != NULL)
  { BOOL open;
    draw_objptr hdrptr;
    char *text;

    hdrptr.bytep = diag->paper + obj_off;
    if (hdrptr.objhdrp->tag == draw_OBJTEXT)
      text = hdrptr.textp->text;
    else
      text = hdrptr.trfmtextp->text;

    dbox_setfield (text_dbox, t_Text, text);

    dbox_show (text_dbox); /*was dbox_showstatic J R C 4th Oct 1993*/
    dbox_raw_eventhandler (text_dbox, &help_dboxrawevents, (void *) "TEXT");

    open = TRUE;
    while (open)
    { wimp_i i = dbox_fillin (text_dbox);

      ftracef1 ("Got event on text dbox icon %d\n", i);
      switch (i)
      { case t_Ok:
        { char text_buf [draw_menu_TEXT_LINE_LIMIT + 1];

          /*An invisible button to catch Return key presses*/
          dbox_getfield (text_dbox, t_Text, text_buf,
              draw_menu_TEXT_LINE_LIMIT);
          draw_select_selection_text (text_buf);

          open = dbox_persist ();
        }
        break;

        case dbox_CLOSE:
          open = FALSE;
        break;
      }
    }

    /*Return the caret to where it was. J R C 4th Oct 1993*/
    draw_displ_showcaret_if_up (diag);

    dbox_dispose (&text_dbox);
  }
}
