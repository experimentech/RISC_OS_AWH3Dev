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
/* -> c.DrawSelect
 *
 * Operations on selected objects for Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.17
 * History: 0.10 - ?? June 1989 - added header to original Draw code
 *          0.11 - 07 June 1989 - interpolation functions added
 *                 12 June 1989 - old versions weeded
 *                                upgraded to drawmod
 *                 19 June 1989 - hold on to input focus more
 *          0.12 - 07 July 1989 - change snapping during movement
 *                                change path snap
 *                 10 July 1989 - enforced minimum scaling
 *          0.13 - 11 July 1989 - convert to draw_scan
 *                 13 July 1989 - functions moved to drawtrans
 *          0.14 - 18 July 1989 - undo added
 *                                line width scaling moved to drawtrans
 *          0.15 -  4 Aug  1989 - new work on grade/interpolate
 *          0.16 - 14 Sept 1989 - grid snap bug mended
 *          0.17 - 15 Sept 1989 - redraw optimisation
 *
 * When deleting a selection, we apply an optimisation to the redraw, as
 * follows: if there are more than a threshold number of objects, their
 * bounding boxes are unified, and this area is redrawn; is less, the
 * objects are redrawn individually. This gets round a problem in some modes
 * with the wimp rectangle area becoming ful. Unifying the boxes can also be
 * faster, because of the wimp's rectangle algorithm.
 */

#define Threshold 5

#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>
#include <string.h>
#include <math.h>
#include <limits.h>

#include "bbc.h"
#include "flex.h"
#include "font.h"
#include "msgs.h"
#include "os.h"
#include "sprite.h"
#include "visdelay.h"
#include "werr.h"
#include "wimp.h"
#include "wimpt.h"
#include "jpeg.h"
#include "dbox.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawAction.h"
#include "DrawDispl.h"
#include "DrawEnter.h"
#include "DrawGrid.h"
#include "DrawObject.h"
#include "DrawScan.h"
#include "DrawSelect.h"
#include "DrawTextC.h"
#include "DrawTrans.h"
#include "DrawUndo.h"

/*NOTE when restyling, deleting, copying, centreing etc selected objects.
call draw_modified (diag) to ensure the modified bit is set (and '*' appears
on title bar). This call is made in xxxxxx_selection, this means that
ineffective restyles such as change fontname of a line! sets the modified
bit even though the dBase is unchanged. If this is a problem, a solution is
to move the draw_modified calls into restyle_{path/text/textarea}. THIS IS A
LOT OF WORK!!!, as these routines need to be passed 'diag', (using
selection_owner instead is dangerous).*/

selection_str *draw_selection;

/*------------------------------------------------------------------------*/

static int over_selected_object (diagrec *diag, draw_objcoord *pt,
                                region *regionp, int *offsetp)
{ int    found = -1;   /*<0 means not found, >=0 means found at that offset*/
  region posn = overSpace;      /*Space, Object, Rotate or Stretch*/
  int    i;
  draw_objptr hdrptr;

  ftracef0 ("over_selected_object\n");
  /*Scan the selection group and return the last object whose
     bounding box or grab points surround the point (x,y).*/

  for (i = draw_selection->indx; i > 0; )
  { draw_bboxtyp bbox;
    hdrptr.bytep = diag->paper + draw_selection->array [--i];

    /*Get bbox, possibly widened*/
    draw_obj_get_box (draw_displ_bbox (hdrptr), &bbox);

    ftracef2 ("testing (%d,%d)\n", pt->x, pt->y);
    ftracef4 ("against ((%d, %d), (%d, %d))\n",
        bbox.x0, bbox.y0, bbox.x1, bbox.y1);

    if (draw_box_within (pt, &bbox))
    { found = draw_selection->array [i];
      posn  = overObject;
      break;                                      /*over body of object*/
    }
    else if (bbox.x1 <= pt->x && bbox.x1 + draw_scaledown (grabW) >= pt->x)
    { if (bbox.y1 <= pt->y && bbox.y1 + draw_scaledown (grabH) >= pt->y &&
          draw_obj_rotatable (hdrptr) /*JRC 10th Jan 1995*/)
      { found = draw_selection->array [i];
        posn  = overRotate;
        break;                               /*over TR (rotate) box*/
      }
      else if (bbox.y0 >= pt->y && bbox.y0 - draw_scaledown (grabH) <= pt->y)
      { found = draw_selection->array [i];
        posn  = overStretch;
        break;                            /*over BR (stretch) box*/
      }
    }
  }

  *regionp = posn;
  *offsetp = found;

  return found >= 0;
}

os_error *draw_select_checkspace (void)

{ ftracef2 ("draw_select_checkspace: index: %d; limit: %d\n",
      draw_selection->indx, draw_selection->limit);
  if (draw_selection->indx == draw_selection->limit)
  { int newsize = sizeof (selection_str) +
        (draw_selection->limit + default_SELECTIONSIZE)*sizeof (int);
                               /*^ new. J R C 22nd Sep 1993*/

    ftracef1 ("draw_select_checkspace: flex_extend (, %d)\n", newsize);
    /*array full, try to extend*/
    if (FLEX_EXTEND ((flex_ptr) &draw_selection, newsize) == 0)
    { ftracef0 ("draw_select_checkspace: extending draw_selection FAILED\n");
      return draw_make_oserror ("DrawR3");
    }

    ftracef1 ("draw_select_checkspace: draw_selection 0x%X\n",
        draw_selection);
    ftracef2 ("draw_selection->owner 0x%X, "
        "draw_selection->owner->paper 0x%X\n",
        draw_selection->owner, draw_selection->owner->paper);
    draw_selection->limit += default_SELECTIONSIZE;
  }
  ftracef0 ("draw_select_checkspace]\n");

  return 0;
}

/*Make a space in the array return index for it, or -1 if already present*/
static os_error *make_insert_space (int obj_off, int *index)

{ os_error *err;
  int i, j;

  ftracef0 ("make_insert_space\n");
  *index = -1; /*Assume found*/

  for (i = 0; i < draw_selection->indx; i++)
  { if (obj_off == draw_selection->array [i]) return 0;

    if (obj_off <  draw_selection->array [i]) break;
  }

  /*either draw_selection->array [i] > obj_off or i == draw_selection->indx,
    so insert obj_off at draw_selection->array [i]*/
  ftracef2 ("select, i=%d, draw_selection->indx=%d\n",i,
      draw_selection->indx);

  if ((err = draw_select_checkspace ()) != NULL)
    return err;

  for (j = draw_selection->indx; j > i; j--)
    draw_selection->array [j] = draw_selection->array [j-1];

  draw_selection->indx++;

  *index = i;

  return 0;
}

os_error *draw_select_object (diagrec *diag, int obj_off)

{ os_error *err = 0;
  int      i;

  ftracef0 ("draw_select_object\n");
  /*Scan selected object array, if obj_off already selected then noaction
    else insert and highlight*/
  err = make_insert_space (obj_off, &i);
  if (!err && i != -1)
  { draw_undo_put (diag, draw_undo__select, obj_off, 0);

    ftracef3 ("writing object offset %d to offset %d (address 0x%X)\n",
        obj_off, i, &draw_selection->array [i]);
    draw_selection->array [i] = obj_off;
    draw_displ_eor_bbox (diag, obj_off);
  }

  return err;
}

/*External version of deselect - used by undo*/
void draw_deselect_object (diagrec *diag, int obj_off)

{ int i, j;

  ftracef0 ("draw_deselect_object\n");
  if (draw_selection->indx <= 0) return;
  draw_undo_put (diag, draw_undo__select, obj_off, -1);

  /*first item is draw_selection->array [0]
     last  item is draw_selection->array [draw_selection->indx-1]
*/

  /*Scan selected object array,*/
  /*  if obj_off not selected then noaction*/
  /*                          else delete and highlight*/
  for (i = 0; i < draw_selection->indx; i++)
  { if (obj_off == draw_selection->array [i]) break;
  }

  /*either (draw_selection->array [i] =obj_off) or (i =draw_selection->indx)*/
  /*so remove draw_selection->array [i]*/
  draw_selection->indx--;

  ftracef2 ("deselect, i=%d, draw_selection->indx=%d\n",
      i, draw_selection->indx);

  for (j = i; j < draw_selection->indx; j++)
    draw_selection->array [j] = draw_selection->array [j+1];

  draw_displ_eor_bbox (diag, obj_off);
}

/*Internal version of deselect - puts undo start first*/
static void deselect_object (diagrec *diag, int obj_off)

{ ftracef0 ("deselect_object\n");
  if (draw_selection->indx <= 0) return;
  draw_undo_separate_major_edits (diag);
  draw_deselect_object (diag, obj_off);
}

/*--------------------------------------------------------------------------*/
/*Put selection/deselection of whole array*/
void draw_select_put_array (diagrec *diag, BOOL redraw)

{ ftracef0 ("draw_select_put_array\n");
  if (draw_selection->owner == diag)
    draw_undo_put (diag,
        redraw? draw_undo__sel_array: draw_undo__sel_array_no,
        draw_selection->indx, (int) draw_selection->array);
}

/*--------------------------------------------------------------------------*/
static void draw_select_clear (diagrec *diag)

{ ftracef0 ("draw_select_clear\n");
  /*Save current array*/
  draw_select_put_array (diag, TRUE);

  /*Save whole selection for undo*/
  if (draw_selection->indx != 0)
  { draw_displ_eor_bboxes (diag);
    draw_selection->indx = 0;

    if (draw_selection->limit > default_SELECTIONSIZE)
    {                                              /*shrink to default size*/
      ftracef1 ("draw_select_clear: flex_extend (, %d)\n", sizeof (selection_str));
      FLEX_EXTEND ((flex_ptr) &draw_selection,sizeof (selection_str));
      draw_selection->limit = default_SELECTIONSIZE;
    }
  }
}

void draw_select_claim_selection (diagrec *diag)

{ ftracef1 ("draw_select_claim_selection: diag: 0x%p\n", diag);
  /*the selection is a single owner (single diagram resource) so steal
    it from any current owner by forcing h(im/er) into draw_mode.*/
  if (draw_selection->owner != diag)
  { if (draw_selection->owner != 0)
      draw_action_changestate (draw_selection->owner, state_path, 0, 0,
          TRUE);

    draw_selection->owner = diag;
    draw_selection->indx  = 0;
  }
}

void draw_select_release_selection (diagrec *diag)

{ ftracef1 ("draw_select_release_selection: diag: 0x%p\n", diag);
  draw_select_clear (diag);
  draw_selection->owner = 0;
}

/*-------------------------------------------------------------------------*/

static os_error *draw_select_range (diagrec *diag, int start, int end)
{ os_error *err = 0;
  int      i, size;
  draw_objptr hdrptr;

  ftracef0 ("draw_select_range\n");
  draw_selection->indx = 0;

  for (i = start; i < end; i += size)
  { hdrptr.bytep = diag->paper + i;  /*N.B. the checkspace may cause*/
    size = hdrptr.objhdrp->size;     /*     heap movement*/

    switch (hdrptr.objhdrp->tag)
    { case draw_OBJTEXTAREA:
        /*Select text area*/
        if (err = draw_select_checkspace (), err) return (err);
        draw_selection->array [draw_selection->indx++] = i;
        hdrptr.bytep = diag->paper + i;  /*in case heap moved*/

        /*Select columns within it if more than one column*/
        if (!draw_text_oneColumn (hdrptr))
        { draw_objptr column;
          int offset = i + sizeof (draw_textareahdr);

          column.bytep = diag->paper + offset;
          while (column.objhdrp->tag == draw_OBJTEXTCOL)
          { if (err = draw_select_checkspace (), err) return (err);
            draw_selection->array [draw_selection->indx++] = offset;
            offset += sizeof (draw_textcolhdr);
            column.bytep = diag->paper + offset;
          }
        }
        break;

        case draw_OBJTEXT:
        case draw_OBJPATH:
        case draw_OBJSPRITE:
        case draw_OBJGROUP:
        case draw_OBJTAGG:
        case draw_OBJTRFMTEXT:
        case draw_OBJTRFMSPRITE:
        case draw_OBJJPEG:
          if ((err = draw_select_checkspace ()) != NULL)
            return err;
          draw_selection->array [draw_selection->indx++] = i;

        default:
          ftracef1("draw_select_range: unknown object type %d\n",hdrptr.objhdrp->tag);
        break;
      }
    }
  return 0;  /*exit OK*/
}

/*Select all objects in the drawing*/
os_error *draw_select_selectall (diagrec *diag)

{ os_error *err;

  ftracef0 ("draw_select_selectall\n");
  draw_undo_separate_major_edits (diag);
  draw_select_clear (diag);

  err = draw_select_range (diag, diag->misc->solidstart,
      diag->misc->solidlimit);
  draw_displ_eor_bboxes (draw_selection->owner);

  return (err);
}

os_error *draw_select_select (diagrec *diag, draw_objcoord *pt)

{ int obj_off;          /*position of object in dBase*/
  region obj_region;    /*click on main area, rotate box or stretch box*/
  os_error *err = 0;

  ftracef0 ("draw_select_select\n");
  /*Quit if already dragging something*/
  if (diag->misc->substate != state_sel) return 0;

  if (!over_selected_object (diag, pt, &obj_region, &obj_off))
  { ftracef0 ("not over selected object, so clear selection\n");
    draw_undo_separate_major_edits (diag); /*Start of new undo put*/
    draw_select_clear (diag);

    if (draw_obj_over_object (diag, pt, &obj_region, &obj_off))
    { ftracef0 ("select object\n");
      err = draw_select_object (diag, obj_off);
    }
  }

  return err;
}

void draw_select_doubleselect (diagrec *diag, draw_objcoord *pt)

{ int obj_off;          /*position of object in dBase*/
  region obj_region;    /*click on main area, rotate box or stretch box*/

  ftracef3 ("draw_select_doubleselect: diag: %d; point: (%d, %d)\n",
      diag, pt->x, pt->y);
  if (over_selected_object (diag, pt, &obj_region, &obj_off))
  { int prev;

    /*See if we are over a text column*/
    if (!draw_text_previous_textcolumn (diag, obj_off, pt, &prev))
      prev = draw_obj_previous_object (diag, obj_off, pt);

    if (prev != obj_off)
    { deselect_object (diag, obj_off);
      draw_select_object (diag, prev);
    }
  }
}

/*If over a selected object,*/
/*  case overObject (centre)  prepare to move selection*/
/*  case overRotate box       prepare to rotate selection*/
/*  case overStretch box      prepare to scale selection*/
/*else*/
/*  prepare capture box*/
void draw_select_longselect (diagrec *diag, viewrec *vuue, draw_objcoord *pt,
    BOOL shifted)

{ draw_objptr hdrptr;
  int obj_off;          /*position of object in dBase*/
  region obj_region;    /*click on main area, rotate box or stretch box*/
  int x = pt->x, y = pt->y;

  ftracef0 ("draw_select_longselect\n");
  /*Quit if already dragging something*/
  if (diag->misc->substate != state_sel) return;

  if (over_selected_object (diag, pt, &obj_region, &obj_off))
  { draw_bboxtyp box;
    hdrptr.bytep = diag->paper + obj_off;
    box          = *draw_displ_bbox (hdrptr);

    switch (obj_region)
    { case overObject:
        diag->misc->substate = state_sel_trans;   /*Prepare for drag*/

        #if 0
        /*At start of drag with grid lock on, align the objects to the grid.
          To do this, find the bottom left of the nominated object, and find
          the translation to place it on the grid.*/
        /*Don't do this - it messes up grid alignment. JRC 7 Oct 1990*/
        if (vuue->flags.lock)
        { draw_objcoord pt1;

          pt1.x = box.x0;
          pt1.y = box.y0;
          draw_grid_snap (vuue, &pt1);
          draw_translate_cb.dx = pt1.x - box.x0;
          draw_translate_cb.dy = pt1.y - box.y0;
        }
        else
        #endif
          draw_translate_cb.dx = draw_translate_cb.dy = 0;

        draw_displ_eor_transboxes (diag);
      break;

      case overRotate:
        { double len_cent_grab;

          diag->misc->substate = state_sel_rotate;   /*Prepare for rotate*/

          draw_rotate_cb.centreX = (box.x0 + box.x1) / 2;
          draw_rotate_cb.centreY = (box.y0 + box.y1) / 2;

          len_cent_grab =
            sqrt (((double)x - (double)draw_rotate_cb.centreX)*
                  ((double)x - (double)draw_rotate_cb.centreX) +
                  ((double)y - (double)draw_rotate_cb.centreY)*
                  ((double)y - (double)draw_rotate_cb.centreY));

          draw_rotate_cb.sinB =
            ((double)y - (double)draw_rotate_cb.centreY)/
                        (double)len_cent_grab;
          draw_rotate_cb.cosB =
            ((double)x - (double)draw_rotate_cb.centreX)/
                         (double)len_cent_grab;
          draw_rotate_cb.sinA_B  = 0; /*sin (A-B) = sin (0)*/
          draw_rotate_cb.cosA_B  = 1; /*cos (A-B) = cos (0)*/

          draw_displ_eor_rotatboxes (diag);
        }
      break;

      case overStretch:
        diag->misc->substate = state_sel_scale;   /*Prepare for scale*/

        draw_scale_cb.new_Dx = draw_scale_cb.old_Dx = box.x1 - box.x0;
        draw_scale_cb.new_Dy = draw_scale_cb.old_Dy = box.y1 - box.y0;

        draw_displ_eor_scaleboxes (diag);              /*scale 1:1*/


#if 0
        /* Colin Granville 5-2-2011
           following lines removed to fix ROOL ticket #137
           resizing objects using the drag box is dodgy */

        /*Fake mouse position to box corner*/
        pt->x = box.x1;
        pt->y = box.y0;
#endif

      break;
    }

   draw_enter_claim (diag, vuue);
  }
  else
    draw_start_capture (vuue, shifted? state_sel_shift_select:
      state_sel_select, pt, FALSE);

  /*Snap mouse onto grid*/
#if 0
        /* Colin Granville 5-2-2011
           following line removed to fix ROOL ticket #137
           resizing objects using the drag box is dodgy */

  if (diag->misc->substate != state_sel_scale)
#endif
    draw_grid_snap_if_locked (vuue, pt);
}

/*If over an already selected object, deselect it,*/
/*else add object to the existing selection*/
/*Can be used to select first object*/
os_error *draw_select_adjust (diagrec *diag, draw_objcoord *pt)

{ int obj_off;          /*position of object in dBase*/
  region obj_region;    /*click on main area, rotate box or stretch box*/
  os_error *err = 0;

  ftracef0 ("draw_select_adjust\n");
  /*Quit if already dragging something*/
  if (diag->misc->substate != state_sel) return 0;

  if (over_selected_object (diag, pt, &obj_region, &obj_off))
  { if (obj_region == overObject)
      deselect_object (diag, obj_off);
  }
  else
  { if (draw_obj_over_object (diag, pt, &obj_region,&obj_off))
    { draw_undo_separate_major_edits (diag);
      err = draw_select_object (diag, obj_off);
    }
  }

  return err;
}

void draw_select_longadjust (diagrec *diag, viewrec *vuue, draw_objcoord *pt,
    BOOL shifted)

{ int obj_off;          /*position of object in dBase*/
  region obj_region;    /*click on main area, rotate box or stretch box*/

  ftracef0 ("draw_select_longadjust\n");
  /*Quit if already dragging something*/
  if (diag->misc->substate != state_sel) return;

  if (!over_selected_object (diag, pt, &obj_region, &obj_off))
    if (draw_selection->indx > 0)
    { ftracef0 ("Not over selected object, retain selection\n");
      draw_start_capture (vuue, shifted? state_sel_shift_adjust:
        state_sel_adjust, pt, FALSE);
    }
  }

void draw_select_clearall (diagrec *diag)

{ ftracef0 ("draw_select_clearall\n");
  draw_undo_separate_major_edits (diag); /*Start of new undo put*/
  draw_select_clear (diag);
}

/*----------------------------------------------------------------------*/
/**/
/*draw_select_capture_area (diag, toggle, x0,y0,x1,y1, overlap)*/
/**/
/*capture all the objects enclosed by the box (x0,y0,x1,y1)*/
/* toggle = 0 means select the objects in the box and deselect any outsid*/
/* toggle = 1 means select the objects in the box leaving others intact*/
/* These correspond to select and adjust drags*/
/* x0,y0,x1,y1 are dBase coordinates*/
/*                 =====*/
/*Uses 'marked selection' to give better appearance on undo*/
/**/
/*----------------------------------------------------------------------*/

os_error *draw_select_capture_area (diagrec *diag, int toggle,
    captu_str box, BOOL overlap)

{ os_error *err;
  int i, size;
  draw_objptr hdrptr;

  ftracef0 ("draw_select_capture_area\n");
  /*If this is an adjust drag, put the current state of the selection*/
  if (toggle == 1)
  { draw_undo_separate_major_edits (diag);
    draw_select_put_array (diag, TRUE);
  }

  draw_sort (&box.x0, &box.x1);
  draw_sort (&box.y0, &box.y1);

  /*Scan the data base and process any object that overlaps
     the area (x0,y0, x1,y1).*/
  ftracef4 ("area is ((%d, %d) ... (%d, %d))\n",
      box.x0, box.y0, box.x1, box.y1);

  for (i = diag->misc->solidstart; i < diag->misc->solidlimit; i += size)
  { hdrptr.bytep = diag->paper + i;
    size = hdrptr.objhdrp->size;

    switch (hdrptr.objhdrp->tag)
    { case draw_OBJTEXT:
      case draw_OBJPATH:
      case draw_OBJSPRITE:
      case draw_OBJGROUP:
      case draw_OBJTEXTAREA:
      case draw_OBJTEXTCOL:
      case draw_OBJTRFMTEXT:
      case draw_OBJTRFMSPRITE:
      case draw_OBJJPEG:
        if (overlap? draw_box_overlap (draw_displ_bbox (hdrptr), &box):
            draw_box_inside (draw_displ_bbox (hdrptr), &box))
          if ((err = draw_select_mark (i, TRUE)) != NULL)
            return err;
      break;

      case draw_OBJTAGG:
      { draw_objptr tagptr;

        tagptr.bytep = hdrptr.bytep + sizeof (draw_taggstr);

        if (overlap? draw_box_overlap (draw_displ_bbox (tagptr), &box):
            draw_box_inside (draw_displ_bbox (tagptr), &box))
          if ((err = draw_select_mark (i, TRUE)) != NULL)
            return err;
      }
      break;

      default:
        ftracef1("draw_select_capture_area: unknown object type %d\n",hdrptr.objhdrp->tag);
        /*ignore unknown types*/
      break;
    }
  }

  /*Complete the selection*/
  draw_select_marked (diag, TRUE);

  return NULL;
}

/*-------------------------------------------------------------------------*/
/**/
/*Batch selection/deselection*/
/*Used during undo.*/
/**/
/*-------------------------------------------------------------------------*/

/*The approach is to scan the array for the given offset. If it is found,
   then on deselect, it is marked (by ORing it) that it is to be
   deselected. If it is not found then on select, it is inserted, also
   marked. This can involve extension of the array. Since offsets are always
   multiple of 4 (they lie on word boundaries), we can mark with 1, thus
   avoiding any special checks in routines such as make_insert_space.
*/

#define Mark  (1)

os_error *draw_select_mark (int offset, BOOL select)

{ os_error *err;
  int i;

  ftracef0 ("draw_select_mark\n");
  if (select)
  { if ((err = make_insert_space (offset, &i)) != NULL)
      return err;

    if (i != -1) draw_selection->array [i] = offset | Mark;
  }
  else
    /*Look for entry*/
    for (i = 0; i < draw_selection->indx; i++)
      /*If we have found entry, mark it as to be deselected*/
      if (offset == draw_selection->array [i])
        draw_selection->array [i] = offset | Mark;

  return 0;
}

/*This finishes the marked undo. A redraw of the bbox of each negative
   element in the array is made. In the case of deselection, these entries are
   then deleted from the array. In the case of selection, the entries are
   changed to positive, i.e. genuinely selected.
*/

void draw_select_marked (diagrec *diag, BOOL select)

{ int i;

  ftracef0 ("draw_select_marked\n");
  /*EOR bbox of each marked element*/
  for (i = 0; i < draw_selection->indx; i++)
  { int entry = draw_selection->array [i];

    if (entry & Mark)
    { entry = entry & ~Mark;
      draw_displ_eor_bbox (diag, entry);
      if (select) draw_selection->array [i] = entry;
    }
  }

  /*Tidy up array if deselecting*/
  if (!select)
  { int from, to;

    for (from = to = 0; from < draw_selection->indx; from++)
    { int entry = draw_selection->array [from];

      if ((entry & Mark) == 0 && to != from)
        draw_selection->array [to++] = entry;
    }
    draw_selection->indx = to;
  }
}

/*-------------------------------------------------------------------------*/
/**/
/*select_justify_selection (l,c,r, t,m,b)*/
/**/
/*  justify objects within any selected grouped object*/
/**/
/*-------------------------------------------------------------------------*/

void draw_select_justify_selection (int horz, int vert)
{ int i = 0;
  draw_bboxtyp bound = draw_big_box;
  diagrec *diag;

  ftracef0 ("draw_select_justify_selection\n");
  if (draw_selection->indx <= 0) return;

  diag = draw_selection->owner;

  #if 0
    draw_undo_put_start_mod (diag, -1);
  #else
    draw_undo_separate_major_edits (diag);
  #endif

  for (i = 0; i < draw_selection->indx; i++)
  { int         hdr_off = draw_selection->array [i];
    draw_objptr hdrptr;

    hdrptr.bytep = diag->paper + hdr_off;

    if (hdrptr.objhdrp->tag == draw_OBJGROUP)
    { draw_bboxtyp jbox = *draw_displ_bbox (hdrptr);  /*limits of group*/

      /*Write undo info for the group. Only the bbox can change*/
      draw_undo_put (diag, draw_undo__object, hdr_off,
          sizeof (draw_groustr));

      draw_obj_bound_minmax2 (hdrptr, &bound);

      /*for each object in the group,*/
      /*justify with respect to jbox (the group BBox)*/
      { int          obj_off, next_off, end_off;
        draw_bboxtyp obox;
        trans_str    t;

        end_off = hdr_off + hdrptr.objhdrp->size;
        obj_off = hdr_off + sizeof (draw_groustr);

        for (; obj_off < end_off; obj_off = next_off)
        { draw_objptr objptr;
          objptr.bytep = diag->paper + obj_off;
          next_off = obj_off + objptr.objhdrp->size;

          obox = *draw_displ_bbox (objptr);  /*current object within group*/

          switch (horz) /*Left, Centre, Right or none*/
          { case 1:  t.dx = jbox.x0 - obox.x0; break;
            case 2:  t.dx = (jbox.x0+jbox.x1)/2 - (obox.x0+obox.x1)/2;
                     break;
            case 3:  t.dx = jbox.x1 - obox.x1; break;
            default: t.dx = 0; break;
          }

          switch (vert) /*Top, Middle, Bottom or none*/
          { case 1 : t.dy = jbox.y1 - obox.y1; break;
            case 2 : t.dy = (jbox.y0+jbox.y1)/2 - (obox.y0+obox.y1)/2;
                     break;
            case 3 : t.dy = jbox.y0 - obox.y0; break;
            default: t.dy = 0; break;
          }

          if (t.dx != 0 || t.dy != 0)
            draw_trans_translate (diag, obj_off, next_off, &t);
        }
      }

      /*Calculate BBox of the internaly justified group object*/
      draw_obj_bound_object (hdrptr);
      draw_obj_bound_minmax2 (hdrptr, &bound);
    }
  }

  draw_modified (draw_selection->owner);
  draw_displ_redrawarea (draw_selection->owner, &bound);
}

/*-------------------------------------------------------------------------*/
/**/
/*Code for operations on the selection: copy, front, back, group, delete*/
/*The following functions replace a single large function in earlier*/
/*versions which used a range of flags to indicate the operation. Here we*/
/*still pass round some flags to the common routines, but it is all a bit*/
/*more comprehensible. Well, I think so, anyway.*/
/**/
/*A number of the routines takes a source diagram, which must be the same*/
/*as the selection owner.*/
/**/
/*-------------------------------------------------------------------------*/


/*Checks and startup for select move/copy operations*/
/*If total is non-NULL, yields the total size of the selected objects*/
/*Returns TRUE if operation may go ahead.*/
/*dest is used only for checks, and only if !=src.*/
/*Assumes undo putting has been started for the dest. We also start it for*/
/*the src if different here.*/
static BOOL start_movecopy (diagrec *src, diagrec *dest, int *total)

{ ftracef0 ("satrt_movecopy\n");
  draw_action_abandon (src);

  if (draw_selection->indx <= 0 ||
      src->misc->ghoststart != src->misc->ghostlimit)
  { return FALSE;
  }

  if (dest != src)
  { draw_action_abandon (dest);
    if (dest->misc->mainstate != dest->misc->substate ||
        dest->misc->ghoststart!= dest->misc->ghostlimit)
    { return FALSE;
    }
  }

  /*Abandon if there are only text columns selected*/
  if (draw_select_deselect_type (src, draw_OBJTEXTCOL))
    return FALSE;

  /*Turn on the hourglass in case the operation takes a long time*/
  visdelay_begin ();

  /*Start undo putting*/
  if (dest != src) draw_undo_separate_major_edits (src);

  /*Put notional deselection of all objects*/
  /*This will be balanced by a later reselection put*/
  draw_select_put_array (src, FALSE);

  if (total != NULL)
  { int i;

    /*Total size of objects*/
    for (i = 0, *total = 0; i < draw_selection->indx; i++)
    { draw_objptr hdrptr;
      hdrptr.bytep = src->paper + draw_selection->array [i];
      *total += hdrptr.objhdrp->size;
    }
  }

  return TRUE;
}

/*Finish movecopy operations - sets modified and completes the undo*/
/*Takes an error flag to see if the operation worked*/
/*Applies to dest as well, if not = src*/
static void finish_movecopy (diagrec *src, diagrec *dest, BOOL ok)

{ ftracef0 ("finish_movecopy\n");
  if (ok)
  { draw_modified (dest); /*Destination is always modified*/
    if (dest != src) draw_modified (src);

    /*Put notional reselection*/
    draw_select_put_array (src, FALSE);
    if (dest != src) draw_select_put_array (dest, FALSE);
  }
  else
  { /*Error - zap undo*/
    draw_undo_prevent_undo (src);
    if (dest != src) draw_undo_prevent_undo (dest);
  }

  visdelay_end ();
}

/*Delete the entire selection.
   Flags for: queue a redraw for each object
   The selection array is left untouched
*/
static void delete_selection (diagrec *diag, BOOL redraw)

{ int  i, offset = 0;
  BOOL unify = FALSE;
  draw_bboxtyp box = draw_big_box;

  ftracef0 ("delete_selection\n");
  if (redraw && (draw_selection->indx > Threshold))
  { unify  = TRUE;
    redraw = FALSE;
  }

  for (i = draw_selection->indx-1; i >= 0; i--)
  { draw_objptr hdrptr;
    int         size, obj_off;

    obj_off      = draw_selection->array [i] + offset;
    hdrptr.bytep = diag->paper + obj_off;
    size         = hdrptr.objhdrp->size;

    /*Queue redraw*/
    if (redraw)
      draw_displ_redrawobject (diag, obj_off);
    else if (unify)
      draw_obj_unify (&box, draw_displ_bbox (hdrptr));

    /*Save for undo*/
    draw_undo_put (diag, draw_undo__delete, obj_off, size);

    /*Close up space in data base*/
    draw_obj_losespace (diag, obj_off, size);
  }

  if (unify)
    draw_displ_redrawarea (diag, &box);
}

/*Claim/make space at a given ofset*/
/*This also adjusts the selection index, if the space is inserted before
   selected objects. Doing this makes some other code easier.
   Flag: make => actually make the space, else just check it can be made.
   The second case is used for callers who want to build objects, rather
   than just doing memory copies.
   The undo information we put assumed that whether we are checking or making
   space, we will eventually use it.
*/
static os_error *select_space (diagrec *diag, int offset, int size, BOOL make)

{ os_error *err;

  ftracef0 ("select_space\n");
  err = (make) ? draw_obj_makespace (diag, offset, size)
               : draw_obj_checkspace (diag, size);

  if (!err)
  { int  i;

    draw_undo_put (diag, draw_undo__insert, offset, size);

    /*Adjust selection array*/
    if (diag == draw_selection->owner)
    { for (i = 0; i < draw_selection->indx; i++)
      { if (draw_selection->array [i] >= offset)
          draw_selection->array [i] += size;
      }
    }
  }
  return err;
}

/*Copy the whole selection to a given destination*/
/*Assume space is already allocated*/
static void copy_selection (diagrec *src, diagrec *dest, int offset)

{ int   i;
  char *destp = dest->paper + offset;

  ftracef0 ("copy_selection\n");
  for (i = 0; i < draw_selection->indx; i++)
  { draw_objptr hdrptr;
    int         size;

    hdrptr.bytep = src->paper + draw_selection->array [i];
    size         = hdrptr.objhdrp->size;
    memmove (destp, hdrptr.bytep, size);
    destp += size;
  }
}

/*Regenerate the selection array over objects in a given range*/
/*Returns the number of selected objects*/
static int build_selection_array (diagrec *diag, int offset, int size)

{ int i = 0;
  int end = offset + size;

  ftracef0 ("build_selection_array\n");
  while (offset < end)
  { draw_objptr hdrptr;
    hdrptr.bytep = diag->paper + offset;
    draw_selection->array [i++] = offset;

    offset += hdrptr.objhdrp->size;
  }

  return i;
}

/*Delete the selection*/
os_error *draw_select_delete (diagrec *src)

{ BOOL ok;

  ftracef0 ("draw_select_delete\n");
  /*Make initial checks*/
  if (ok = start_movecopy (src, src, NULL), ok)
  { /*Delete all the objects, with redraw*/
    delete_selection (src, TRUE);

    /*Clear selection*/
    draw_selection->indx = 0;
  }

  /*Finish off*/
  finish_movecopy (src, src, ok);
  return 0; /*Always return zero, even if it didn't work*/
}

/*Common code for moving to start or back*/
/*The flag is used to get the right offset when regenerating the selection
   array
*/
static os_error *front_back (diagrec *src, int offset, BOOL front)

{ int totalsize = 0;
  os_error *err = 0;
  BOOL     ok;

  ftracef0 ("front_back\n");
  /*Make initial checks*/
  if (ok = start_movecopy (src, src, &totalsize), ok)
  { /*Reserve space for the new objects*/
    if (err = select_space (src, offset, totalsize, TRUE), err)
      ok = FALSE;
    else
    { /*Copy each object in the selection*/
      copy_selection (src, src, offset);

      /*Delete the original objects*/
      delete_selection (src, TRUE);

      /*Regenerate the selection array*/
      /*To do this, we may need to fiddle the offset first*/
      build_selection_array (src, (front) ? offset - totalsize : offset,
                            totalsize);
    }
  }

  /*Finish off*/
  finish_movecopy (src, src, ok);
  return err;
}

/*Move the selection to the front, i.e. the end of the data base*/
os_error *draw_select_front (diagrec *src)

{ ftracef0 ("draw_select_front\n");
  return front_back (src, src->misc->ghostlimit, TRUE);
}

/*Move selection to the back, i.e. to the start of the data base*/
os_error *draw_select_back (diagrec *src)

{ ftracef0 ("draw_select_back\n");
  return front_back (src, src->misc->solidstart, FALSE);
}

/*Make a copy of the selection, jogging it.*/
/*Can copy to another diagram*/
os_error *draw_select_copy (diagrec *src, diagrec *dest, trans_str *trans)

{ os_error *err = 0;
  BOOL     ok;
  int      totalsize = 0;

  ftracef0 ("draw_select_copy\n");
  /*Make initial checks*/
  if (ok = start_movecopy (src, dest, &totalsize), ok)
  { int offset = dest->misc->solidlimit;

    /*Reserve space for the new objects*/
    if (err = select_space (dest, offset, totalsize, TRUE), err)
      ok = FALSE;
    else
    { /*Copy objects*/
      copy_selection (src, dest, offset);

      /*Change state on copy to another diagram*/
      if (src != dest)
      { /*Change source to line entry*/
        draw_action_changestate (src, state_path, 0, 1, FALSE);

        /*Change destination to select mode*/
        draw_action_changestate (dest, state_sel, 0, 0, FALSE);
      }

      /*Change selection array*/
      draw_selection->indx = build_selection_array (dest, offset, totalsize);

      /*Translate objects*/
      if (src != dest)
        trans->dx = trans->dy = 0; /*>>> maybe change: e.g. base on mouse*/
      draw_trans_translate (dest, -1, -1, trans);
    }
  }

  /*Finish off*/
  finish_movecopy (src, dest, ok);
  return err;
}

/*Make a group from the selection*/
os_error *draw_select_group (diagrec *src)

{ os_error *err = 0;
  BOOL     ok;
  int      totalsize = 0;

  ftracef0 ("draw_select_group\n");
  /*Make initial checks*/
  if (ok = start_movecopy (src, src, &totalsize), ok)
  { int offset = src->misc->solidlimit;

    /*Check space for the group, without 'making' it*/
    err = select_space (src, offset, totalsize + sizeof (draw_groustr), FALSE);
    if (err)
      ok = FALSE;
    else
    { /*Create group header*/
      draw_obj_start (src, draw_OBJGROUP);

      /*Copy objects into group*/
      copy_selection (src, src, src->misc->ghostlimit);
      src->misc->ghostlimit += totalsize;

      /*Finish off the group*/
      draw_obj_fin (src);

      /*Delete the original objects*/
      delete_selection (src, FALSE);

      /*Change selection array*/
      draw_selection->indx = 1;
      draw_selection->array [0] = src->misc->solidlimit
                                 - totalsize - sizeof (draw_groustr);

      /*Ensure the new group is redrawn, and queue redraw for undo*/
      draw_displ_redrawobject (src, draw_selection->array [0]);
    }
  }

  /*Finish off*/
  finish_movecopy (src, src, ok);
  return err;
}

/*Copy down - used to open up space*/
void draw_select_copydown (diagrec *diag,int from_off, int to_off, int size)

{ ftracef0 ("draw_select_copydown\n");
  memmove (diag->paper + to_off, diag->paper + from_off, size);
}

/*Copy up - used to close up space*/
void draw_select_copyup (diagrec *diag,int from_off, int to_off, int size)

{ ftracef0 ("draw_select_copyup\n");
  memmove (diag->paper + to_off, diag->paper + from_off, size);
}

/*Ungroup an object - simplified from earlier versions.
  Now ungroups multiple groups at once.*/
os_error *draw_select_action_ungroup (void)

{ int this, next;
  os_error *error;

  ftracef0 ("draw_select_action_ungroup\n");
  /*Check that the owner is in a fit state to accept the operation.*/
  if (draw_selection->owner->misc->ghoststart !=
      draw_selection->owner->misc->ghostlimit)
    return NULL;

  visdelay_begin ();

  /*Start saving for undo*/
  draw_undo_separate_major_edits (draw_selection->owner);

  /*Put notional deselection*/
  draw_select_put_array (draw_selection->owner, FALSE);

  /*Remove BBox of the selected objects*/
  draw_displ_eor_bboxes (draw_selection->owner);

  /*Note: it is important that in this loop, the diagram be valid at the end
    of each iteration. The variables this, next are important - this must
    always point at the object currently being processed,
    next at the one after.*/
  for (this = 0; this < draw_selection->indx; this = next)
  { int atoff;
    draw_objptr hdrptr;

    ftracef1 ("this: %d\n", this);
    atoff = draw_selection->array [this];
    hdrptr.bytep = draw_selection->owner->paper + atoff;

    next = this + 1;
    if (hdrptr.objhdrp->tag == draw_OBJGROUP)
    { int group_size = hdrptr.groupp->size;

      /*Lose the space at the group header*/
      draw_undo_put (draw_selection->owner, draw_undo__delete, atoff,
            sizeof (draw_groustr));
      draw_obj_losespace (draw_selection->owner, atoff,
            sizeof (draw_groustr));
        /*diagram now inconsistent*/

      { /*Adjust all objects in the selection beyond this to point at where
            the object now is really.*/
        int i;

        for (i = this + 1; i < draw_selection->indx; i++)
          draw_selection->array [i] -= sizeof (draw_groustr);
      }

      { /*Put all the objects that were in the group into the selection.
          Move the rest of the selection up to make room first.*/
        int end = atoff + group_size - sizeof (draw_groustr), o;

        hdrptr.bytep = draw_selection->owner->paper + atoff; /*heap moved?*/

        for (o = atoff + hdrptr.objhdrp->size; o < end;
            o += hdrptr.objhdrp->size)
        { ftracef1 ("o: %d\n", o);
          if ((error = draw_select_checkspace ()) != NULL) break;
            /*stop if we can't extend the selection. The diagram is
              inconsistent now. Oops ...*/

          { int j;

            ftracef2 ("j varying from %d down to %d\n",
                draw_selection->indx - 1, next);
            for (j = draw_selection->indx - 1 /*next +
                draw_selection->indx - this - 1*/; j >= next; j--)
              draw_selection->array [j + 1] = draw_selection->array [j];
            /*slightly lazy - could do all this outside the loop, but it
                sounds like a nightmare!!*/
          }
          draw_selection->indx++;

          draw_selection->array [next] = o;

          /***/
          hdrptr.bytep = draw_selection->owner->paper + o;
          next++;
        }
        /*next now set up to be this in outer loop*/
      }
    }
  }

  /*Redraw the selection boxes*/
  draw_displ_eor_bboxes (draw_selection->owner);

  /*Finish off*/
  finish_movecopy (draw_selection->owner, draw_selection->owner, TRUE);
  return 0;
}

/*----------------------------------------------------------------------*/
/**/
/*restyle_selection (diag, action, changeto)*/
/**/
/*  restyle the specified item to the new value*/
/**/
/*----------------------------------------------------------------------*/

typedef struct
{ diagrec *diag; restyle_action action; int new;
} restyle_typ;

/*General restyle routine - also puts undo*/
static void do_restyle (restyle_typ *restyle, void *at, int size)

{ ftracef1 ("do_restyle: size %d\n", size);
  /*Save undo without redraw*/
  if (restyle->diag)
    draw_undo_put (restyle->diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
                  -(int) at, size);

  /*Change object's data*/
  memcpy (at, &restyle->new, size);
}

/*Put the bbox into the undo buffer*/
static void put_bbox (diagrec *diag, draw_objptr hdrptr)

{ ftracef0 ("put_bbox\n");
  if (diag)
    /*Save undo without redraw*/
    draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
                  - (int)&hdrptr.textp->bbox, sizeof (draw_bboxtyp));
}

/*
   All text fields except fontref are one word. So we use a common change
   routine for them, and a separate one for the fontref.
*/
static void restyle_text (draw_objptr hdrptr, restyle_typ *restyle)

{ ftracef0 ("restyle_text\n");

  switch (restyle->action)
  { case restyle_FONTFACE:
      do_restyle (restyle, &hdrptr.textp->textstyle.fontref,
          sizeof (draw_fontref));
    break;

    case restyle_FONTSIZE:  /*change both x and y*/
      do_restyle (restyle, &hdrptr.textp->fsizex, sizeof (draw_fontsize));
    /*Fall into y case*/

    case restyle_FONTSIZEY: /*change y only*/
      do_restyle (restyle, &hdrptr.textp->fsizey, sizeof (draw_fontsize));
    break;

    case restyle_FONTCOLOUR:
      do_restyle (restyle, &hdrptr.textp->textcolour, sizeof (draw_coltyp));
    break;

    case restyle_FONTBACKGROUND:
      do_restyle (restyle, &hdrptr.textp->background, sizeof (draw_coltyp));
    break;

    default:
    return;
  }

  /*If we arrive here, we made a change. Save the bbox of the object too*/
  put_bbox (restyle->diag, hdrptr);
}

static void restyle_path (draw_objptr hdrptr, restyle_typ *restyle)

{ ftracef0 ("restyle_path\n");
  switch (restyle->action)
  { case restyle_FILLCOLOUR:
      do_restyle (restyle, &hdrptr.pathp->fillcolour, sizeof (draw_coltyp));
      break;

    case restyle_LINECOLOUR:
      do_restyle (restyle, &hdrptr.pathp->pathcolour, sizeof (draw_coltyp));
      break;

    case restyle_LINEWIDTH:
      do_restyle (restyle, &hdrptr.pathp->pathwidth, sizeof (draw_pathwidth));
      break;

    case restyle_LINEJOIN:
    case restyle_LINESTARTCAP:
    case restyle_LINEENDCAP:
    case restyle_LINETRICAPWID:
    case restyle_LINETRICAPHEI:
    case restyle_LINEWINDING:
    { diagrec *diag = restyle->diag;

      /*Save undo information: whole style word, no redraw*/
      if (diag)
        draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
                      - (int)&hdrptr.pathp->pathstyle, sizeof (draw_pathstyle));

      switch (restyle->action)
      { case restyle_LINEJOIN:
          hdrptr.pathp->pathstyle.s.join = restyle->new;
          break;

        case restyle_LINESTARTCAP:
          hdrptr.pathp->pathstyle.s.startcap = restyle->new;
          break;

        case restyle_LINEENDCAP:
          hdrptr.pathp->pathstyle.s.endcap = restyle->new;
          break;

        case restyle_LINETRICAPWID:
          hdrptr.pathp->pathstyle.s.tricapwid = restyle->new;
          break;

        case restyle_LINETRICAPHEI:
          hdrptr.pathp->pathstyle.s.tricaphei = restyle->new;
          break;

        case restyle_LINEWINDING:
          hdrptr.pathp->pathstyle.s.windrule = restyle->new;
          break;
      }
      break;
    }

    default:
      return;
  }

  /*If we arrive here, we made a change. Save the bbox of the object too*/
  put_bbox (restyle->diag, hdrptr);
}

static void restyle_textarea (draw_objptr hdrptr, restyle_typ *restyle)

{ ftracef0 ("restyle_textarea\n");
  switch (restyle->action)
  { case restyle_FONTCOLOUR:
    { draw_textareaend *end = draw_text_findEnd (hdrptr);

      do_restyle (restyle, &end->textcolour, sizeof (draw_coltyp));
      break;
    }

    case restyle_FONTBACKGROUND:
    { draw_textareaend *end = draw_text_findEnd (hdrptr);

      do_restyle (restyle, &end->backcolour, sizeof (draw_coltyp));
      break;
    }
  }
}

/*
   All text fields except fontref are one word. So we use a common change
   routine for them, and a separate one for the fontref.
*/
static void restyle_trfmtext (draw_objptr hdrptr, restyle_typ *restyle)

{ ftracef0 ("restyle_trfmtext\n");

  switch (restyle->action)
  { case restyle_FONTFACE:
      /*Don't restyle trfmtexts to be system font.*/
      if (restyle->new != 0)
        do_restyle (restyle, &hdrptr.trfmtextp->textstyle.fontref,
                 sizeof (draw_fontref));
    break;

    case restyle_FONTSIZE:  /*change both x and y*/
      do_restyle (restyle, &hdrptr.trfmtextp->fsizex, sizeof (draw_fontsize));
    /*Fall into y case*/

    case restyle_FONTSIZEY: /*change y only*/
      do_restyle (restyle, &hdrptr.trfmtextp->fsizey, sizeof (draw_fontsize));
    break;

    case restyle_FONTCOLOUR:
      do_restyle (restyle, &hdrptr.trfmtextp->textcolour, sizeof (draw_coltyp));
    break;

    case restyle_FONTBACKGROUND:
      do_restyle (restyle, &hdrptr.trfmtextp->background, sizeof (draw_coltyp));
    break;

    default:
    return;
  }

  /*If we arrive here, we made a change. Save the bbox of the object too*/
  put_bbox (restyle->diag, hdrptr);
}

static despatch_tab restyletab =
{ 0 /*fontlist*/,   restyle_text,     restyle_path,     0 /*rect*/,
  0 /*elli*/,       0 /*sprite*/,     0 /*group*/,      0 /*tagged*/,
  0 /*'8'*/,        restyle_textarea, 0 /*textcolumn*/, 0 /*options*/,
  restyle_trfmtext};

void draw_select_restyle_selection (restyle_action action, int changeto)

{ restyle_typ restyle;

  ftracef0 ("draw_select_restyle_selection\n");
  restyle.diag   = draw_selection->owner;
  restyle.action = action;
  restyle.new    = changeto;

  draw_scan_traverse_withredraw (NULL, NULL, restyle.diag, restyletab,
                                &restyle, TRUE);
}

/*Restyle a single object, without redraw*/
void draw_select_restyle_object (draw_objptr hdrptr, restyle_action action,
                               int changeto)

{ restyle_typ restyle;

  ftracef0 ("draw_select_restyle_object\n");
  restyle.action = action;
  restyle.new    = changeto;
  restyle.diag   = NULL;

  draw_scan_traverse_object (hdrptr, restyletab, &restyle);
}

/*-------------------------------------------------------------------------*/
/*Alter the dash pattern style of all selected paths*/
/*(both top-level and within grouped objects)*/

/*N.B. we call dBase_(insert/delete) even though we haven't pushed
  anything onto the stack, and infact do our own hdrptr->size changes,
  this is'nt a problem since that stack is flat ie diag->misc->stacklimit
  == diag->misc->bufferlimit. This MAY cause a problem if dBase_xxxx is
  changed. Reports of any change was made.*/

static os_error *draw_select_repattern_object (diagrec *diag, int hdroff,
    draw_dashstr *pattern /*new pattern*/,
    int *changedbyp /*return change in size*/, BOOL *changed)

{ os_error *err = 0;
  int changedby = 0;
  draw_objptr hdrptr;

  ftracef0 ("draw_select_repattern_object\n");
  hdrptr.bytep = hdroff + diag->paper;    /*be careful with addresses,*/
                                          /*cos heap WILL shift*/
  switch (hdrptr.objhdrp->tag)
  { case draw_OBJPATH:
    { int atoff   = hdroff + sizeof (draw_pathstrhdr);
      int cursize = 0;  /*size of pattern (if any) already in path*/
      int newsize = 0;  /*size of pattern (if any) to apply*/
      int diff;

      *changed = TRUE;

      if (hdrptr.pathp->pathstyle.s.dashed)
        cursize = sizeof (drawmod_dashhdr) +
                  sizeof (int)*hdrptr.pathp->data.dash.dashcount;

      if (pattern)
        newsize = sizeof (drawmod_dashhdr) +
                  sizeof (int)*pattern->dash.dashcount;

      /*For repatterning, say that we deleted and reinserted data, without
         redraw*/
      draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
                    - (int)&hdrptr.pathp->size, sizeof (draw_sizetyp));
      draw_undo_put (diag, draw_undo__delete, -atoff, cursize);
      draw_undo_put (diag, draw_undo__insert, -atoff, newsize);

      diff = newsize - cursize;   /*amount of extra space needed*/

      if (diff > 0)
        err = draw_obj_insert (diag, atoff, diff);
      else if (diff < 0)
        draw_obj_delete (diag, atoff, -diff);

      hdrptr.bytep = diag->paper + hdroff;    /*heap moved!*/

      if (!err)
      { hdrptr.pathp->size += diff;  /*correct for size change*/
        changedby = diff;

        /*Save the dashed bit (by saving path style)*/
        draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
                      - (int)&hdrptr.pathp->pathstyle, sizeof (draw_pathstyle));

        hdrptr.pathp->pathstyle.s.dashed = 0;

        if (pattern)     /*set dashed bit and copy pattern*/
        { hdrptr.pathp->pathstyle.s.dashed = 1;

          memcpy ((char*)&hdrptr.pathp->data, (char*)pattern, newsize);
        }
      }
      break;
    }

    case draw_OBJGROUP:
    { int  i;
      int  start   = sizeof (draw_groustr);
      int  diff    = 0;
      BOOL change  = FALSE;
      int  newsize = hdrptr.groupp->size;

      draw_objptr objptr;

      for (i = start; i < newsize; i += objptr.objhdrp->size)
      { err = draw_select_repattern_object (diag,hdroff+i,pattern, &diff,
                                           &change);
                                                              /*may recurse*/
        if (err) break;   /*abort, with some objects changed*/

        hdrptr.bytep = diag->paper + hdroff;  /*Group header*/
        objptr.bytep = hdrptr.bytep + i;    /*current object in group*/
        newsize     += diff;
        changedby   += diff;
      }

      if (change)
      { draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
                      - (int)&hdrptr.groupp->size, sizeof (draw_sizetyp));
        *changed = TRUE;
      }
      hdrptr.groupp->size = newsize;
    }
  }

  *changedbyp = changedby;  /*tell the caller how much extra space we took*/
  return (err);
}

/*Assumes undo start and end are done externally*/
void draw_select_repattern_selection (draw_dashstr *pattern)

{ os_error *err = 0;
  int i, j;
  int changedby;
  draw_bboxtyp bound = draw_big_box;
  diagrec *diag = draw_selection->owner;
  BOOL changed = FALSE;

  ftracef0 ("draw_select_repattern_selection\n");
  if (draw_selection->indx <= 0) return;

  /*put old selection array, in case it changes*/
  draw_select_put_array (diag, TRUE);

  /*relies on all selected objects being graphic (ie have bboxes)*/
  for (i = 0; i < draw_selection->indx; i++)
  { draw_objptr hdrptr;
    int hdroff = draw_selection->array [i];

    hdrptr.bytep = diag->paper + hdroff;

    draw_obj_bound_minmax2 (hdrptr, &bound);

    err = draw_select_repattern_object (diag, hdroff, pattern, &changedby,
        &changed);

    hdrptr.bytep = diag->paper + hdroff;    /*heap moved*/

    /*The size of this object has changed, so alter all later selection
      offsets. If an error occured above, we must still do this, cos some
      paths could have been changed before the error ('No room') occurred.
      Also put the change to the selection array.*/
    if (changedby != 0)
      for (j = i+1; j < draw_selection->indx; j++)
        draw_selection->array [j] += changedby;

    draw_obj_bound_object (hdrptr);
    draw_obj_bound_minmax2 (hdrptr, &bound);

    if (err) break; /*selection partially changed*/
  }

  if (changed)
  { draw_modified (diag);
    draw_displ_redrawarea (diag, &bound);
    draw_undo_put (diag, draw_undo__redraw, (int)&bound, 0);

    /*put new selection array*/
    draw_select_put_array (diag, TRUE);
  }
}

/*------------------------------------------------------------------------*/
static os_error *draw_select_object_text (diagrec *diag, int hdroff,
    char *text)

{ draw_objptr hdrptr;
  os_error *error;
  int hdrsize, atoff, cur_size /*size of text already in object*/,
    len, new_size /*size of new text*/, diff;

  ftracef1 ("draw_select_object_text: \"%s\"\n", text);
  hdrptr.bytep = hdroff + diag->paper;
  hdrsize = hdrptr.objhdrp->tag == draw_OBJTEXT?
      sizeof (draw_textstrhdr): sizeof (draw_trfmtextstrhdr);
  atoff = hdroff + hdrsize;
  len = strlen (text);

  cur_size = hdrptr.objhdrp->size; /*was hdrsize +
      (strlen (&hdrptr.textp->text [0])/sizeof (int) + 1)*sizeof (int);*/
  new_size = hdrsize + (len/sizeof (int) + 1)*sizeof (int);
  ftracef2 ("cur_size: %d, new_size: %d\n", cur_size, new_size);

  draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
      -(int) &hdrptr.objhdrp->size, sizeof (draw_sizetyp));
  draw_undo_put (diag, draw_undo__delete, -hdroff, cur_size);
  draw_undo_put (diag, draw_undo__insert, -hdroff, new_size);

  diff = new_size - cur_size;

  if (diff > 0)
  { if ((error = draw_obj_insert (diag, atoff, diff)) != NULL)
      return error;
  }
  else if (diff < 0)
    draw_obj_delete (diag, atoff, -diff);

  hdrptr.bytep = diag->paper + hdroff; /*heap moved?*/

  hdrptr.objhdrp->size = new_size;
  draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
      -(int) hdrptr.bytep, cur_size);

  /*Remember to pad to word boundary*/
  strncpy (hdrptr.objhdrp->tag == draw_OBJTEXT? hdrptr.textp->text:
      hdrptr.trfmtextp->text, text, len + 4 & ~3);
  return NULL;
}

/*Assumes undo start and end are done externally*/
void draw_select_selection_text (char *text)
  /*Changes the text of the selected item. This is already known to be a
    single text or trfmtext object.*/

{ os_error *error = 0;
  draw_bboxtyp bound = draw_big_box;
  diagrec *diag = draw_selection->owner;
  draw_objptr hdrptr;
  int hdroff = draw_selection->array [0];

  ftracef1 ("draw_select_selection_text: \"%s\"\n", text);
  hdrptr.bytep = diag->paper + hdroff;
  if (draw_selection->indx != 1) return;
  if (!(hdrptr.objhdrp->tag == draw_OBJTEXT ||
      hdrptr.objhdrp->tag == draw_OBJTRFMTEXT)) return;

  if (strlen (text) != 0)
  { ftracef0 ("put old selection array, in case it changes\n");
    draw_select_put_array (diag, TRUE);

    hdrptr.bytep = diag->paper + hdroff;
    draw_obj_bound_minmax2 (hdrptr, &bound);
    error = draw_select_object_text (diag, hdroff, text);

    ftracef0 ("The size of this object has changed\n");
    hdrptr.bytep = diag->paper + hdroff; /*heap moved?*/
    draw_obj_bound_object (hdrptr);
    draw_obj_bound_minmax2 (hdrptr, &bound);

    draw_modified (diag);
    draw_displ_redrawarea (diag, &bound);
    draw_undo_put (diag, draw_undo__redraw, (int) &bound, 0);

    ftracef0 ("put new selection array\n");
    draw_select_put_array (diag, TRUE);
  }
  else
    /*No new text - delete the object completely.*/
    (void) draw_select_delete (diag);
}
/*----------------------------------------------------------------------*/
/*Deselect all objects of a given type. Return TRUE if nothing left*/
BOOL draw_select_deselect_type (diagrec *diag, draw_tagtyp tag)

{ int  to, from;
  draw_objptr hdrptr;

  ftracef3 ("draw_select_deselect_type: diagrec: 0x%p; tag: %d; "
      "draw_selection->indx: %d\n", diag, tag, draw_selection->indx);

  for (to = 0, from = 0; from < draw_selection->indx; )
  { hdrptr.bytep = diag->paper + draw_selection->array [from];
    if (hdrptr.objhdrp->tag == tag)
      /*Paint over select box, and skip to next object*/
      draw_displ_eor_bbox (diag, draw_selection->array [from++]);
    else
      draw_selection->array [to++] = draw_selection->array [from++];
  }

  return (draw_selection->indx = to) == 0;
}

#if 0
/*-------------------------------------------------------------------------*/
static void dump_path (draw_objptr path)

{ drawmod_pathelemptr point = draw_obj_pathstart (path);
  char                *end = path.bytep + path.objhdrp->size;

  ftracef0 ("dump_path\n");
  do
    switch (point.move2->tag)
    { case path_move_2:
        ftracef2 ("> move (%d,%d)\n", point.move2->x, point.move2->y);
        point.move2 += 1;
      break;

      case path_lineto:
        ftracef2 ("> line (%d,%d)\n", point.lineto->x, point.lineto->y);
        point.lineto += 1;
      break;

      case path_bezier:
        ftracef (NULL, 0, "> curve (%d,%d) via (%d,%d) and (%d,%d)\n",
            point.bezier->x3, point.bezier->y3,
            point.bezier->x1, point.bezier->y1,
            point.bezier->x2, point.bezier->y2);
        point.bezier += 1;
      break;

      case path_term:
        ftracef0 ("> term\n");
        point.end += 1;
      break;

      case path_closeline:
        ftracef0 ("> close\n");
        point.closeline += 1;
      break;

      default:
        ftracef0 ("> Unknown: end of dump\n");
        return;
    }
  while (point.bytep < end);
}
#endif

/*-------------------------------------------------------------------------*/
/*Interpolate/grade code*/

/*Locate the first and second objects in a group*/
static void locate_objects (draw_objptr group, draw_objptr *object)

{ ftracef0 ("locate_objects\n");
  object [0].bytep = group.bytep + sizeof (draw_groustr);
  object [1].bytep = object [0].bytep + object [0].objhdrp->size;
}

/*Locate the first and second objects paths*/
static void locate_paths (draw_objptr *object, drawmod_pathelemptr *path)

{ ftracef0 ("locate_paths\n");
  path [0] = draw_obj_pathstart (object [0]);
  path [1] = draw_obj_pathstart (object [1]);
}

/*Get the path tags*/
static void get_path_tags (drawmod_pathelemptr *path, draw_path_tagtype *tag)

{ ftracef0 ("get_path_tags\n");
  tag [0] = path [0].end->tag;
  tag [1] = path [1].end->tag;
}

/*Find the size of a path element*/
static int element_size (draw_path_tagtype tag)

{ ftracef0 ("element_size\n");
  return
      tag == path_move_2?    sizeof (drawmod_path_movestr):
      tag == path_lineto?    sizeof (drawmod_path_linetostr):
      tag == path_bezier?    sizeof (drawmod_path_bezierstr):
      tag == path_closeline? sizeof (drawmod_path_closelinestr):
                             sizeof (drawmod_path_termstr);
}

/*Advance path pointers by given tags*/
static void advance_paths (drawmod_pathelemptr *path,
                          draw_path_tagtype tag0, draw_path_tagtype tag1)

{ ftracef0 ("advance_paths\n");
  path [0].bytep += element_size (tag0);
  path [1].bytep += element_size (tag1);
}

/*Find the size of the subpath to be build from two existing ones, and
   return pointers to the end (next move/term) of the existing ones. Also
   report if closed. Return the size for the path including doubling, etc.
   for doughnut paths, and initial moves.
*/

static int subpath_size (drawmod_pathelemptr *source, drawmod_pathelemptr *dest,
                        BOOL doughnut, BOOL *closed)

{ BOOL scanning = TRUE;
  draw_path_tagtype tag [2];
  int  size = 0;

  ftracef0 ("subpath_size\n");
  *closed     = FALSE;
  dest [0]     = source [0];
  dest [1]     = source [1];
  get_path_tags (dest, tag);

  while (scanning)
  {
    advance_paths (dest, tag [0], tag [1]); /*Pass over current element*/
    get_path_tags (dest, tag);

    switch (tag [0])
    { case path_lineto:
        size += element_size (tag [1]);
        break;

      case path_bezier:
        size += sizeof (drawmod_path_bezierstr);
        break;

      case path_closeline:  /*Double space for closed doughnuts*/
        *closed = TRUE;
        break;

      case path_move_2: /*End of an open path*/
        scanning = FALSE;
        break;

      case path_term:
        scanning = FALSE;
        break;
    }
  }

  if (*closed)
  { if (doughnut)
      size       += size + sizeof (drawmod_path_movestr);
    else
      size += element_size (path_closeline);
  }
  else
  { size += size + 2*sizeof (drawmod_path_linetostr);
  }

  return size + sizeof (drawmod_path_movestr);
}

/*Macro for setting points. Both arguments are int**/
#define SetPoint(at, from) (*(at) = *(from), *((at) + 1) = *((from) + 1))

/*Add an element to a path*/
static void add_element (drawmod_pathelemptr p, int *pt,
    draw_path_tagtype tag)

{ ftracef0 ("add_element\n");
  p.end->tag = tag;

  if (tag == path_bezier)      SetPoint (&p.bezier->x3, pt);
  else if (tag == path_lineto) SetPoint (&p.lineto->x, pt);
  else if (tag == path_move_2) SetPoint (&p.move2->x, pt);
}

static int add_at_start (drawmod_pathelemptr *p, int *pt,draw_path_tagtype tag)

{ int ele_size;

  ftracef0 ("add_at_start\n");
  add_element (*p, pt, tag);
  p->bytep += (ele_size = element_size (tag));
  return ele_size;
}

static int add_at_end (drawmod_pathelemptr *p, int *pt, draw_path_tagtype tag)

{ int ele_size;

  ftracef0 ("add_at_end\n");
  p->bytep -= (ele_size = element_size (tag));
  add_element (*p, pt, tag);
  return ele_size;
}

/*Find the space needed for a graded path*/
/*Returns the space for an individual object and the total space needed for
   the objects.
*/
static int graded_space (draw_objptr group, int levels, BOOL doughnut,
                        int *total_space)

{ draw_objptr         path [2];
  drawmod_pathelemptr point [2];
  draw_path_tagtype   tag [2];
  int                 header, space = 0;

  ftracef0 ("graded_space\n");
  locate_objects (group, path);
  locate_paths  (path,  point);

  /*Find space for object headers*/
  header = point [0].bytep - path [0].bytep;

  /*For each subpath*/
  while (get_path_tags (point, tag), tag [0] != path_term)
  { BOOL closed;

    space += subpath_size (point, point, doughnut, &closed);
  }

  /*Add terminating elements and object header*/
  space += sizeof (drawmod_path_termstr) + header;

  /*Find total size for all objects plus group header*/
  *total_space = space * levels + sizeof (draw_groustr);

  return space;
}

/*Report if an object may be graded*/
BOOL draw_select_may_grade (draw_objptr object)

{ ftracef0 ("draw_select_may_grade\n");
  /*The object is gradable if it is a group...*/
  if (object.objhdrp->tag == draw_OBJGROUP)
  { draw_objptr path [2];

    locate_objects (object, path);

    /*... containing exactly two paths ...*/
    if (path [0].objhdrp->tag == draw_OBJPATH &&
        path [1].objhdrp->tag == draw_OBJPATH &&
        path [1].bytep + path [1].objhdrp->size
                        == object.bytep + object.objhdrp->size)
    { /*... with corresponding elements ...*/
      drawmod_pathelemptr p [2];
      draw_path_tagtype   tag [2];

      locate_paths (path, p);
      get_path_tags (p, tag);

      while (get_path_tags (p, tag), tag [0] != path_term)
      { if (tag [0] == tag [1] ||
            (tag [0] == path_lineto && tag [1] == path_bezier) ||
            (tag [1] == path_lineto && tag [0] == path_bezier))
        { advance_paths (p, tag [0], tag [1]);
        }
        else
        { return FALSE;
        }
      }

      return (tag [0] == tag [1]);
    }
  }

  return FALSE;
}

/*General integer interpolation*/
static int interpolate (int start, int end, int level, int levels)

{ ftracef0 ("interpolate\n");
  return (start == end || level == 0) ?  start :
         (level == levels)            ?  end   :
         (int) (0.5 + (((double) end - (double) start) * level) / levels + start);
}

static void interpolate_point (int *point1, int *point2, int level, int levels,
                              int *to)

{ ftracef0 ("interpolate_point\n");
  to [0] = interpolate (point1 [0], point2 [0], level, levels);
  to [1] = interpolate (point1 [1], point2 [1], level, levels);
}

static int *get_point (drawmod_pathelemptr from, draw_path_tagtype tag)

{ ftracef0 ("get_point\n");
  if (tag == path_move_2)
    return & (from.move2->x);
  else if (tag == path_lineto)
    return & (from.lineto->x);
  else if (tag == path_bezier)
    return & (from.bezier->x3);
/*else werr (1, "Fundamental error %d", tag);*/
  return NULL;
}

/*Interpolate a path part*/
static void interpolate_part (drawmod_pathelemptr *point, int *dest,
                             int level, int levels)

{ ftracef0 ("interpolate_part\n");
  interpolate_point (get_point (point [0], point [0].end->tag),
                    get_point (point [1], point [1].end->tag),
                    level, levels, dest);
}

static void set_curve_points (drawmod_pathelemptr source,
                             drawmod_path_bezierstr *dest)

{ ftracef0 ("set_curve_points\n");
  if (source.bezier->tag == path_bezier)
    memcpy (dest, source.bezier, sizeof (drawmod_path_bezierstr));
  else
  { SetPoint (&dest->x3, &source.lineto->x);

    /*Set bezier points at ends of line*/
    SetPoint (&dest->x1, &source.lineto->x);
    SetPoint (&dest->x2, &source.lineto->x);
  }
}

static void interpolate_curve_point (drawmod_pathelemptr *source,
                                    drawmod_pathelemptr dest,
                                    BOOL reverse, int level, int levels)

{ /*These are just convenient structures for holding the points*/
  drawmod_path_bezierstr curve [2];
  int i;

  ftracef0 ("interpolate_curve_point\n");
  for (i = 0; i <= 1; i++) set_curve_points (source [i], &curve [i]);

  if (reverse)
  { interpolate_point (&curve [0].x1, &curve [1].x1, level, levels,
                      &dest.bezier->x2);
    interpolate_point (&curve [0].x2, &curve [1].x2, level, levels,
                      &dest.bezier->x1);
  }
  else
  { interpolate_point (&curve [0].x1, &curve [1].x1, level, levels,
                      &dest.bezier->x1);
    interpolate_point (&curve [0].x2, &curve [1].x2, level, levels,
                      &dest.bezier->x2);
  }
}

/*Type for breaking down colours*/
typedef union
{ struct   {char gcol; char colour [3]; } c;
  unsigned int word;
} grade_colour;

static draw_coltyp interpolate_colour (grade_colour *col, int level, int levels)

{ int          i;
  grade_colour result;
  int  levels1   = levels - 1;
  int  halflevel = levels1 / 2;

  ftracef0 ("interpolate_colour\n");
  /*If either colour is transparent, return the other*/
  if (col [0].word == TRANSPARENT) return col [1].word;
  else if (col [1].word == TRANSPARENT) return col [0].word;

  for (i = 0, result.word = 0; i < 3; i++)
  { int from, step;

    from = col [0].c.colour [i];
    step = (level * (col [1].c.colour [i] - from) + halflevel) / levels1;

    result.c.colour [i] = (from + step < 0) ? 0 : (from + step) & 0xff;
  }

  return result.word;
}

/*Set fill colour - changes transparent to white*/
static int set_fill_colour (draw_objptr source, draw_objptr other)

{ draw_coltyp c = source.pathp->fillcolour;

  ftracef0 ("set_fill_colour\n");
  return (c == TRANSPARENT && other.pathp->fillcolour != TRANSPARENT)
         ? WHITE : c;
}

/*Set path colour - changes transparent to black*/
static int set_path_colour (draw_objptr source, draw_objptr other)

{ draw_coltyp c = source.pathp->pathcolour;

  ftracef0 ("set_path_colour\n");
  return (c == TRANSPARENT && other.pathp->pathcolour != TRANSPARENT)
         ? BLACK : c;
}

/*Interpolate header fields*/
static void interpolate_header (draw_objptr dest, draw_objptr *source,
                               int level, int levels)

{ /*Interpolate colours*/
  grade_colour col [2];

  ftracef0 ("interpolate_header\n");
  col [0].word = set_fill_colour (source [0], source [1]);
  col [1].word = set_fill_colour (source [1], source [0]);
  dest.pathp->fillcolour = interpolate_colour (col, level, levels);
  col [0].word = set_path_colour (source [0], source [1]);
  col [1].word = set_path_colour (source [1], source [0]);
  dest.pathp->pathcolour = interpolate_colour (col, level, levels);

  /*Interpolate line widths*/
  dest.pathp->pathwidth  = interpolate (source [0].pathp->pathwidth,
                                       source [1].pathp->pathwidth,
                                       level, levels);

  /*Interpolate triangle characteristics*/
  dest.pathp->pathstyle.s.tricapwid
                 = interpolate (source [0].pathp->pathstyle.s.tricapwid,
                               source [1].pathp->pathstyle.s.tricapwid,
                               level, levels) & 0xff;
  dest.pathp->pathstyle.s.tricaphei
                 = interpolate (source [0].pathp->pathstyle.s.tricaphei,
                               source [1].pathp->pathstyle.s.tricaphei,
                               level, levels) & 0xff;
}

/*Make a subpath from the sources*/
static void make_subpath (drawmod_pathelemptr dest,
                         drawmod_pathelemptr dest_end,
                         drawmod_pathelemptr *source,
                         BOOL closed, BOOL doughnut,
                         int fromlevel, int levels)

{ int  tolevel;
  BOOL pyramid = (!doughnut && closed);
  int  pt [2], lastpt [2];
  draw_path_tagtype   tag [2];
  drawmod_pathelemptr point [2];

  ftracef0 ("make_subpath\n");
  /*Fiddle number of levels*/
  if (closed && !doughnut) levels -= 1;
  tolevel = fromlevel + 1;

  /*Make local copy of points*/
  point [0] = source [0];
  point [1] = source [1];

  /*dest      : move (x0', y0')
     dest_end  : line (x0', y0') [open only]
*/
  interpolate_part (point, pt, fromlevel, levels);
  add_at_start (&dest, pt, path_move_2);
  if (!closed) add_at_end (&dest_end, pt, path_lineto);

  /*Find x0" and y0", and keep them as xi-1" and yi-1"*/
  interpolate_part (point, lastpt, tolevel, levels);

  /*Iterate over path*/
  advance_paths (point, path_move_2, path_move_2);

  while (get_path_tags (point, tag),
         tag [0] != path_move_2 && tag [0] != path_term)
  { /*On close element, break out*/
    if (tag [0] == path_closeline)
    {
      if (pyramid) add_at_start (&dest, NULL, path_closeline);
      advance_paths (point, path_closeline, path_closeline);
      break;
    }
    else
    { /*Find xi' and yi'*/
      interpolate_part (point, pt, fromlevel, levels);

      /*Make element at start: ei (xi', yi')*/
      if (tag [0] == path_bezier || tag [1] == path_bezier)
      { interpolate_curve_point (point, dest, FALSE, fromlevel, levels);
        add_at_start (&dest, pt, path_bezier);

        /*Make element at end: ei (xi-1", yi-1")*/
        if (!pyramid) add_at_end (&dest_end, lastpt, path_bezier);
      }
      else
      { add_at_start (&dest, pt, tag [0]);
        if (!pyramid) add_at_end (&dest_end, lastpt, tag [0]);
      }

      if ((tag [0] == path_bezier || tag [1] == path_bezier) && !pyramid)
        interpolate_curve_point (point, dest_end, TRUE, tolevel,levels);

      /*Find xi" and yi" and keep them for next loop*/
      interpolate_part (point, lastpt, tolevel, levels);

      /*Point to next element*/
      advance_paths (point, tag [0], tag [1]);
    }
  }

  /*Fill in line or move in middle*/
  if (!pyramid)
    add_at_start (&dest, lastpt, (closed) ? path_move_2 : path_lineto);
}

/*Interpolate the points in the path*/
static void interpolate_path (drawmod_pathelemptr dest,
                             drawmod_pathelemptr *source,
                             int level, int levels, BOOL doughnut)

{ draw_path_tagtype   tag [2];

  ftracef0 ("interpolate_path\n");
  /*Iterate over each subpath*/
  while (get_path_tags (source, tag), tag [0] != path_term
                                     && tag [0] != path_closeline)
  { drawmod_pathelemptr source_end [2];
    drawmod_pathelemptr dest_end;
    int  size;
    BOOL closed;

    /*Find end of subpaths, and see if closed*/
    size = subpath_size (source, source_end, doughnut, &closed);

    /*Build the path*/
    dest_end.bytep = dest.bytep + size;

    make_subpath (dest, dest_end, source, closed, doughnut, level, levels);

    /*Update pointer to start of destination subpath*/
    dest.bytep += size;

    /*Point to next source subpath*/
    source [0] = source_end [0];
    source [1] = source_end [1];
  }

  /*Add termination to path*/
  add_at_start (&dest, NULL, path_term);
}

/*See if one object is wholly within another*/
static BOOL object_within (draw_objptr outer, draw_objptr inner)

{ draw_bboxtyp *outerb, *innerb;

  ftracef0 ("object_within\n");
  outerb = draw_displ_bbox (outer);
  innerb = draw_displ_bbox (inner);
  return (outerb->x0 < innerb->x0 && innerb->x1 < outerb->x1 &&
          outerb->y0 < innerb->y0 && innerb->y1 < outerb->y1);
}

/*Interpolate the path object at a given level. Source points to the two
   objects from which we will form the result.
*/
static void interpolate_level (draw_objptr dest, draw_objptr *source,
                              int level, int levels, BOOL doughnut)

{ drawmod_pathelemptr sourcep [2];

  ftracef0 ("interpolate_level\n");
  /*Swap order if path 1 is wholly within path 0 and non-doughnut*/
  if (object_within (source [1], source [0]) && !doughnut)
  { draw_objptr temp = source [0];
    source [0] = source [1];
    source [1] = temp;
  }

  locate_paths (source, sourcep);

  /*Interpolate the headers*/
  memcpy (dest.bytep, source [0].bytep, (int) (sourcep [0].bytep-source [0].bytep));
  interpolate_header (dest, source, level, levels);

  /*Interpolate the path itself*/
  interpolate_path (draw_obj_pathstart (dest), sourcep, level, levels, doughnut);
}

/*Convert the (one) selected group into an interpolated object*/
/*Closed paths can be interpolated as 'doughnuts' or as 'coins'*/
/*Doughnuts also includes open paths*/
/*Undo saving is very crass - just save a delete for all the old objects in
   the selection and an insert for all the new ones.
*/
void draw_select_interpolate (diagrec *diag, int levels, BOOL doughnut)

{ draw_objptr group;
  int         offset = draw_selection->array [0];
  int         oldsize, newsize;
  int         new_offset;

  ftracef0 ("draw_select_interpolate\n");
  /*Interpolate the selected object*/
  group.bytep = diag->paper + offset;
  oldsize     = group.objhdrp->size;

  /*Turn hourglass on while we do this*/
  visdelay_begin ();

  /*Check object may be graded*/
  if (draw_select_may_grade (group))
  { int path_size = graded_space (group, levels, doughnut, &newsize);
    draw_objptr new_group;
    draw_objptr dest, source [2];
    int         level;

    /*Allocate space needed for prototype paths and for result*/
    if (wimpt_complain (draw_obj_checkspace (diag, newsize)) != NULL)
    { draw_undo_prevent_undo (diag);
      visdelay_end ();
      return;
    }

    group.bytep = diag->paper + offset; /*In case of heap shift*/

    /*Start the group and reserve space for the objects in it*/
    new_offset = diag->misc->ghostlimit;
    draw_obj_start (diag, draw_OBJGROUP);
    diag->misc->ghostlimit += newsize - sizeof (draw_groustr);

    /*Make interpolated group header*/
    new_group.bytep = diag->paper + new_offset;
    new_group.groupp->size = newsize;

    /*Build prototype paths*/
    locate_objects (group, source);
    dest.bytep = new_group.bytep + sizeof (draw_groustr);
    for (level = 0; level < levels; level++)
    { interpolate_level (dest, source, level, levels, doughnut);
      dest.objhdrp->size = path_size;
      dest.bytep += path_size;
    }

    /*Complete the group*/
    draw_obj_fin (diag);

    /*Notionally deselect old group and delete it*/
    draw_undo_put (diag, draw_undo__select, offset, -1);
    draw_undo_put (diag, draw_undo__delete, offset, oldsize);

    draw_obj_losespace (diag, offset, oldsize);
    new_offset -= oldsize;

    /*Select and redraw the new group, and save undo for it*/
    draw_selection->array [0] = new_offset; /*Fiddle selection*/
    draw_undo_put (diag, draw_undo__insert, new_offset, newsize);

    draw_displ_redrawobject (diag, new_offset);
    draw_undo_put (diag, draw_undo__select, new_offset, 0);

    draw_obj_flush (diag);

    /*Mark diagram as modified*/
    draw_modified (diag);

    visdelay_end ();
  }
}

/*--------------------------------------------------------------------------*/
void draw_select_set (diagrec *diag)

{ ftracef0 ("draw_select_set\n");
  draw_selection->owner = diag;
  draw_selection->indx  = 0;
}

BOOL draw_select_alloc (void)

{ ftracef0 ("draw_select_alloc\n");

  if (FLEX_ALLOC ((flex_ptr) &draw_selection, sizeof (selection_str)))
  { ftracef1 ("draw_select_alloc: flex_alloc -> draw_selection 0x%X\n",
        draw_selection);
    draw_selection->owner = 0;
    draw_selection->indx  = 0;
    draw_selection->limit = default_SELECTIONSIZE;
    ftracef0 ("draw_select_alloc -> TRUE\n");
    return TRUE;
  }
  else
  { ftracef0 ("draw_select_alloc -> FALSE\n");
    return FALSE;
  }
}

BOOL draw_select_owns (diagrec *diag)

{ ftracef0 ("draw_select_owns\n");
  return (draw_selection->owner == diag);
}

draw_objptr draw_select_find (int i)

{ draw_objptr hdrptr;

  ftracef1 ("draw_select_find (%d)\n", i);
  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  hdrptr.bytep = (i >= draw_selection->indx)
                 ? NULL
                 : draw_selection->owner->paper + draw_selection->array [i];

  return hdrptr;
}
/*-------------------------------------------------------------------------*/
/*Convert to paths*/
/*  Convert all text lines in the selection to paths.*/
/*-------------------------------------------------------------------------*/
static os_error *Convert_Text_Line_To_Paths (diagrec *diag,
    int text_line_off)

/*Converts a single text line to path objects in a ghost group and pushes it
  onto the stack.*/

{ os_error *error;
  int group_off, paths_off;
  size_t size;
  draw_objptr group_ptr, text_line_ptr;
  drawmod_buffer *buff_ptr;
  double old_scale_factor;

  static draw_objcoord Origin = {0, 0};
  static draw_bboxtyp Big_Box = {INT_MIN, INT_MIN, INT_MAX, INT_MAX};

  ftracef3 ("Convert_Text_Line_To_Paths: "
      "text_line_off: %d; diag: 0x%p; diag->paper: 0x%p\n",
      text_line_off, diag, diag->paper);

  text_line_ptr.bytep = diag->paper + text_line_off;

  if ((text_line_ptr.objhdrp->tag == draw_OBJTEXT?
      text_line_ptr.textp->textstyle.fontref:
      text_line_ptr.trfmtextp->textstyle.fontref) == NULL)
    return draw_make_oserror ("DrawT");
  ftracef0 ("turn off system font output\n"); /*JRC 1 Feb 1990*/
  (void) bbc_vdu (bbc_DisableVDU);

  /*How big are the paths?*/
  if ((error = font_output_to_null
      (/*hint?*/ FALSE, /*skeleton?*/ FALSE, font_ERROR)) != NULL)
  { ftracef0 ("turn on system font output (error)\n"); /*JRC 1 Feb 1990*/
    (void) bbc_vdu (bbc_EnableVDU);
    return error;
  }

  /*Paint them to nowhere as if at (0, 0).*/
  ftracef0 ("Convert_Text_Line_To_Paths: "
      "calling draw_displ_do_objects\n");
  if
  ( ( old_scale_factor = draw_displ_scalefactor, /*Oh no, he's not ...*/
      draw_displ_scalefactor = 1.0,
      error =
        draw_displ_do_objects
        (diag,
          text_line_off,
          text_line_off + 1,
          &Origin,
          &Big_Box
        ),
      draw_displ_scalefactor = old_scale_factor, /*he did!*/
      error
    ) != NULL
  )
  { (void) font_output_to_screen ();
    ftracef0 ("turn on system font output (error)\n"); /*JRC 1 Feb 1990*/
    (void) bbc_vdu (bbc_EnableVDU);
    return error;
  }

  /*Get the size. (This is actually 8 bytes (== sizeof (drawmod_buffer)) too
    big.)*/
  if ((error = font_output_size (&size)) != NULL)
  { (void) font_output_to_screen ();
    ftracef0 ("turn on system font output (error)\n"); /*JRC 1 Feb 1990*/
    (void) bbc_vdu (bbc_EnableVDU);
    return error;
  }

  /*Make sure the ghost region is big enough for a group containing this.
    This moves the heap.*/
  ftracef0 ("Convert_Text_Line_To_Paths: "
      "calling draw_obj_checkspace\n");
  if ((error = draw_obj_checkspace (diag, sizeof (draw_groustr) + size)) !=
      NULL)
  { (void) font_output_to_screen ();
    ftracef0 ("turn on system font output (error)\n"); /*JRC 1 Feb 1990*/
    (void) bbc_vdu (bbc_EnableVDU);
    return error;
  }

  text_line_ptr.bytep = diag->paper + text_line_off; /*update pointer*/

  /*Make a group header big enough for the paths and fill it in*/
  group_off = diag->misc->ghoststart;
  group_ptr.bytep = diag->paper + group_off;
  draw_obj_start (diag, draw_OBJGROUP);
  diag->misc->ghostlimit += size;

  group_ptr.groupp->size += size;
  group_ptr.groupp->bbox = text_line_ptr.objhdrp->tag == draw_OBJTEXT?
      text_line_ptr.textp->bbox: text_line_ptr.trfmtextp->bbox;

  paths_off = group_off + sizeof (draw_groustr);
  buff_ptr = (drawmod_buffer *) (diag->paper + paths_off);

  /*Convert the text line to paths FOR REAL this time*/
  buff_ptr->zeroword = 0;
  buff_ptr->sizeword = size - sizeof (drawmod_buffer);
  if
  ( ( error =
        font_output_to_buffer
        (buff_ptr, /*hint?*/ FALSE, /*skeleton?*/ FALSE, font_ERROR)
    ) != NULL
  )
  { draw_obj_flush (diag);
    (void) font_output_to_screen ();
    ftracef0 ("turn on system font output (error)\n"); /*JRC 1 Feb 1990*/
    (void) bbc_vdu (bbc_EnableVDU);
    return error;
  }

  /*Paint them to paths as if at (0, 0). Use a
    really big clipping region (i e, don't clip).*/
  if
  ( ( old_scale_factor = draw_displ_scalefactor, /*not again ...*/
      draw_displ_scalefactor = 1.0,
      error =
        draw_displ_do_objects
        (diag,
          text_line_off,
          text_line_off + 1,
          &Origin,
          &Big_Box
        ),
      draw_displ_scalefactor = old_scale_factor, /*... yes*/
      error
    ) != NULL
  )
  { draw_obj_flush (diag);
    (void) font_output_to_screen ();
    ftracef0 ("turn on system font output (error)\n"); /*JRC 1 Feb 1990*/
    (void) bbc_vdu (bbc_EnableVDU);
    return error;
  }

  /*Is the text line only 1 path long?*/
  { draw_objptr obj_ptr;
    obj_ptr.bytep = diag->paper + paths_off;

    if (size - sizeof (drawmod_buffer) == obj_ptr.objhdrp->size)
    { /*Only one path in group.*/
      memmove (diag->paper + group_off,
          diag->paper + group_off + sizeof (draw_groustr), size);

      /*Shrink the ghost region to lose the extra 8 bytes and the group
          header.*/
      diag->misc->ghostlimit -= sizeof (draw_groustr) +
          sizeof (drawmod_buffer);
    }
    else
    { /*Shrink the ghost region and the group to lose the extra 8 bytes.*/
      group_ptr.groupp->size -= sizeof (drawmod_buffer);
      diag->misc->ghostlimit -= sizeof (drawmod_buffer);
    }
  }

  if ((error = font_output_to_screen ()) != NULL)
  { ftracef0 ("turn on system font output (error)\n"); /*JRC 1 Feb 1990*/
    (void) bbc_vdu (bbc_EnableVDU);
    return error;
  }

  /*The draw_displ_do_objects may have failed because the font wasn't
    found, but do nothing anyway*/
  ftracef0 ("turn on system font output\n"); /*JRC 1 Feb 1990*/
  (void) bbc_vdu (bbc_EnableVDU);

  return NULL;
}
/*------------------------------------------------------------------------*/
static os_error *Convert_Object_To_Paths (diagrec *diag, int hdroff,
      int *changedby /*out*/, BOOL *changed /*in/out*/)

/*Converts text lines in an object into paths.*/

{ draw_objptr hdrptr;
  BOOL object_changed = FALSE;
  os_error *error = NULL;

  ftracef1 ("Convert_Object_To_Paths: "
      "converting object at offset %d\n", hdroff);
  *changedby = 0;
  hdrptr.bytep = diag->paper + hdroff; /*careful with pointer*/

  switch (hdrptr.objhdrp->tag)
  { case draw_OBJTEXT: case draw_OBJTRFMTEXT:
    { size_t oldsize, newsize;
      ptrdiff_t diff;
      draw_objptr ghostptr;
      int ghostoff;

      ftracef0 (hdrptr.objhdrp->tag == draw_OBJTEXT?
          "Convert_Object_To_Paths: it's a text line\n":
          "Convert_Object_To_Paths: it's a trfmtext\n");

      /*If system font, do nothing.*/
      if ((hdrptr.objhdrp->tag == draw_OBJTEXT?
          hdrptr.textp->textstyle.fontref:
          hdrptr.trfmtextp->textstyle.fontref) != NULL)
      { /*Build a group of paths in the ghost area*/
        if ((error = Convert_Text_Line_To_Paths (diag, hdroff)) != NULL)
          return error;

        ghostoff = *(int *) (diag->paper + diag->misc->stacklimit);
        ftracef1 ("Convert_Object_To_Paths: "
            "ghost is at offset%d\n", ghostoff);
        hdrptr.bytep = diag->paper + hdroff;
        ghostptr.bytep = diag->paper + ghostoff;

        /*Make space for the new group.*/
        oldsize = hdrptr.objhdrp->size;
        newsize = ghostptr.objhdrp->size;
        diff = newsize - oldsize;

        if (diff > 0)
        { ftracef1 ("Convert_Object_To_Paths: "
              "making %d bytes\n", diff);
          if ((error = draw_obj_makespace (diag, hdroff, diff)) != NULL)
          { draw_obj_flush (diag);
            return error;
          }
        }
        else if (diff < 0)
          ftracef1 ("Convert_Object_To_Paths: "
              "losing %d bytes\n", -diff),
          draw_obj_losespace (diag, hdroff, -diff);

        ghostoff += diff; /*very dodgy*/
        ftracef1 ("Convert_Object_To_Paths: "
              "ghost moved to offset%d\n", ghostoff);
        hdrptr.bytep = diag->paper + hdroff;
        ghostptr.bytep = diag->paper + ghostoff;

        /*Copy it in, over the top of the old.*/
        draw_undo_put (diag, draw_undo__delete, -hdroff, oldsize);
        ftracef3 ("Convert_Object_To_Paths: "
              "copying %d bytes to offset %d from offset %d\n",
              newsize, hdroff, ghostoff);
        (void) memcpy (hdrptr.bytep, ghostptr.bytep, newsize);
        draw_undo_put (diag, draw_undo__insert, -hdroff, newsize);

        /*Zap the ghost area*/
        draw_obj_flush (diag);

        object_changed = TRUE;
        *changedby = diff;
      }
    }
    break;

    case draw_OBJGROUP:
    { draw_objptr objptr;
      int i, start = sizeof (draw_groustr),
        newsize = hdrptr.objhdrp->size;

      ftracef0 ("Convert_Object_To_Paths: it's a group\n");
      for (i = start; i < newsize; i += objptr.objhdrp->size)
      { int object_changedby;

        error =
          Convert_Object_To_Paths
          ( diag,
            hdroff + i,
            &object_changedby,
            &object_changed
          ); /*don't raise error yet*/

        *changedby += object_changedby;
        if (error != NULL) break;

        hdrptr.bytep = diag->paper + hdroff; /*update pointer*/
        objptr.bytep = hdrptr.bytep + i;
        newsize += object_changedby;
      }

      if (object_changed)
        draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
          - (int) &hdrptr.groupp->size, sizeof (draw_sizetyp));

      hdrptr.groupp->size = newsize;
    }
    break;

    #if TRACE
      default:
        ftracef (__FILE__, __LINE__,
            "Convert_Object_To_Paths: "
            "it's unknown object type %d\n", hdrptr.objhdrp->tag);
      break;
    #endif
  }

  *changed = *changed || object_changed;
  return error;
}

void draw_select_convert_to_paths (diagrec *diag)

/*Converts text lines in the selection into paths.*/

{ int i, j;
  draw_bboxtyp bound = draw_big_box;
  BOOL changed = FALSE;
  os_error *error;

  ftracef0 ("draw_select_convert_to_paths\n");
  if (draw_selection->indx <= 0) return;

  /*Start undo putting.*/
  ftracef0 ("draw_select_convert_to_paths: calling draw_select_owns\n");
  if (draw_select_owns (diag)) draw_undo_separate_major_edits (diag);

  /*Put whole selection, in case it changes.*/
  ftracef0 ("draw_select_convert_to_paths: "
      "calling draw_select_put_array\n");
  draw_select_put_array (diag, TRUE);

  visdelay_begin (); /*FIX RP-0224 JRC 30 Oct '91*/

  /*Rely on all selected objects having bboxes.*/
  for (i = 0; i < draw_selection->indx; i++)
  { draw_objptr hdrptr;
    int hdroff = draw_selection->array [i], changedby;

    hdrptr.bytep = diag->paper + hdroff;

    draw_obj_bound_minmax2 (hdrptr, &bound);

    ftracef0 ("draw_select_convert_to_paths: "
      "calling Convert_Object_To_Paths\n");
    error = Convert_Object_To_Paths (diag, hdroff, &changedby, &changed);
        /*don't raise error yet ...*/

    hdrptr.bytep = diag->paper + hdroff; /*update pointer*/

    /*Change all later offsets in the selection.*/
    if (changedby != 0)
      for (j = i + 1; j < draw_selection->indx; j++)
        draw_selection->array [j] += changedby;

    draw_obj_bound_object (hdrptr);
    draw_obj_bound_minmax2 (hdrptr, &bound);

    if (error != NULL)
    { werr (FALSE, error->errmess);
      break;
    }
  }

  visdelay_end (); /*FIX RP-0224 JRC 30 Oct '91*/

  ftracef0 ("draw_select_convert_to_paths: winding up\n");
  if (changed)
  { draw_modified (diag);
    draw_displ_redrawarea (diag, &bound);
    draw_undo_put (diag, draw_undo__redraw, (int) &bound, 0);
    draw_select_put_array (diag, TRUE);
  }
}

/*------------------------------------------------------------------------*/
static os_error *Make_Rotatable (diagrec *diag, int hdroff,
      int *changedby /*out*/, BOOL *changed /*in/out*/)

/*Converts text lines and sprites in an object into transformed text lines
  and transformed paths, respectively.*/

{ draw_objptr hdrptr;
  BOOL object_changed = FALSE;
  os_error *error = NULL;

  ftracef1 ("Make_Rotatable: "
      "converting object at offset %d\n", hdroff);
  *changedby = 0;
  hdrptr.bytep = diag->paper + hdroff; /*careful with pointer*/

  switch (hdrptr.objhdrp->tag)
  { case draw_OBJTEXT:
      if (hdrptr.texthdrp->textstyle.fontref != 0)
      { ftracef0 ("Make_Rotatable: anti-aliased text line\n");

        ftracef0 ("HMM1:\n"), draw_trace_db (diag);
        draw_undo_put (diag, draw_undo__delete, -hdroff,
            hdrptr.texthdrp->size);

        hdrptr.bytep = diag->paper + hdroff;
        ftracef1 ("Make_Rotatable: making %d bytes\n",
            sizeof (drawmod_transmat) + sizeof (draw_fontflags));
        /*Make space for the transformation.*/
        ftracef0 ("HMM2:\n"), draw_trace_db (diag);
        if ((error = draw_obj_makespace (diag,
            hdroff + offsetof (draw_trfmtextstrhdr, trfm),
            sizeof (drawmod_transmat) + sizeof (draw_fontflags))) != NULL)
          return error;

        hdrptr.bytep = diag->paper + hdroff;
        ftracef2 ("updating offsets 0x%X, 0x%X\n",
            (char *) &hdrptr.trfmtexthdrp->tag - (char *) diag->paper,
            (char *) &hdrptr.trfmtexthdrp->size - (char *) diag->paper);
        hdrptr.trfmtexthdrp->tag = draw_OBJTRFMTEXT;
        hdrptr.trfmtexthdrp->size += sizeof (drawmod_transmat) +
            sizeof (draw_fontflags);
        ftracef0 ("HMM3:\n"), draw_trace_db (diag);

        /*Copy it in.*/
        hdrptr.trfmtexthdrp->trfm [0] = 1 << 16;
        hdrptr.trfmtexthdrp->trfm [1] = 0;
        hdrptr.trfmtexthdrp->trfm [2] = 0;
        hdrptr.trfmtexthdrp->trfm [3] = 1 << 16;
        hdrptr.trfmtexthdrp->trfm [4] = 0;
        hdrptr.trfmtexthdrp->trfm [5] = 0;

        *(int *) &hdrptr.trfmtexthdrp->flags = 0;

        draw_undo_put (diag, draw_undo__insert, -hdroff,
            hdrptr.trfmtexthdrp->size);

        hdrptr.bytep = diag->paper + hdroff;
        object_changed = TRUE;
        *changedby = sizeof (drawmod_transmat) + sizeof (draw_fontflags);
      }
    break;

    case draw_OBJSPRITE:
    { sprite_id id;
      sprite_info info;
      int mode, width, height;

      ftracef4 ("Make_Rotatable: sprite (%d, %d, %d, %d)\n",
          hdrptr.spritep->bbox.x0, hdrptr.spritep->bbox.y0,
          hdrptr.spritep->bbox.x1, hdrptr.spritep->bbox.y1);

      ftracef0 ("HMM1:\n"), draw_trace_db (diag);
      draw_undo_put (diag, draw_undo__delete, -hdroff,
          hdrptr.spritehdrp->size);

      hdrptr.bytep = diag->paper + hdroff;
      ftracef1 ("Make_Rotatable: making %d bytes\n",
          sizeof (drawmod_transmat));
      /*Make space for the transformation.*/
      ftracef0 ("HMM2:\n"), draw_trace_db (diag);
      if ((error = draw_obj_makespace (diag,
          hdroff + offsetof (draw_trfmspristrhdr, trfm),
          sizeof (drawmod_transmat))) != NULL)
        return error;

      hdrptr.bytep = diag->paper + hdroff;
      ftracef2 ("updating offsets 0x%X, 0x%X\n",
          (char *) &hdrptr.trfmsprihdrp->tag - (char *) diag->paper,
          (char *) &hdrptr.trfmsprihdrp->size - (char *) diag->paper);
      hdrptr.trfmsprihdrp->tag = draw_OBJTRFMSPRITE;
      hdrptr.trfmsprihdrp->size += sizeof (drawmod_transmat);
      ftracef0 ("HMM3:\n"), draw_trace_db (diag);

      id.tag = sprite_id_addr;
      id.s.addr = &hdrptr.trfmspritep->sprite;
      sprite_readsize (UNUSED_SA, &id, &info);
      mode = hdrptr.trfmspritep->sprite.mode;
      width  = info.width  << bbc_modevar (mode, bbc_XEigFactor) + 8;
      height = info.height << bbc_modevar (mode, bbc_YEigFactor) + 8;

      /*Copy it in.*/
      hdrptr.trfmsprihdrp->trfm [0] =
          (int) (65536.0*(double) (int) (hdrptr.trfmspritep->bbox.x1 -
          hdrptr.trfmspritep->bbox.x0)/(double) width);
      hdrptr.trfmsprihdrp->trfm [1] = 0;
      hdrptr.trfmsprihdrp->trfm [2] = 0;
      hdrptr.trfmsprihdrp->trfm [3] =
          (int) (65536.0*(double) (int) (hdrptr.trfmspritep->bbox.y1 -
          hdrptr.trfmspritep->bbox.y0)/(double) height);
      hdrptr.trfmsprihdrp->trfm [4] = hdrptr.trfmspritep->bbox.x0;
      hdrptr.trfmsprihdrp->trfm [5] = hdrptr.trfmspritep->bbox.y0;

      ftracef3 ("Make_Rotatable: (%10d %10d %10d)\n",
          hdrptr.trfmsprihdrp->trfm [0],
          hdrptr.trfmsprihdrp->trfm [2],
          hdrptr.trfmsprihdrp->trfm [4]);
      ftracef3 ("                (%10d %10d %10d)\n",
          hdrptr.trfmsprihdrp->trfm [1],
          hdrptr.trfmsprihdrp->trfm [3],
          hdrptr.trfmsprihdrp->trfm [5]);

      ftracef3 ("              = (%10.2f %10.2f %10.2f)\n",
          hdrptr.trfmsprihdrp->trfm [0]/65536.0,
          hdrptr.trfmsprihdrp->trfm [2]/65536.0,
          hdrptr.trfmsprihdrp->trfm [4]/256.0);
      ftracef3 ("                (%10.2f %10.2f %10.2f)\n",
          hdrptr.trfmsprihdrp->trfm [1]/65536.0,
          hdrptr.trfmsprihdrp->trfm [3]/65536.0,
          hdrptr.trfmsprihdrp->trfm [5]/256.0);

      draw_undo_put (diag, draw_undo__insert, -hdroff,
          hdrptr.trfmsprihdrp->size);

      hdrptr.bytep = diag->paper + hdroff;
      object_changed = TRUE;
      *changedby = sizeof (drawmod_transmat);
    }
    break;

    case draw_OBJGROUP:
    { draw_objptr objptr;
      int i, start = sizeof (draw_groustr),
        newsize = hdrptr.objhdrp->size;

      ftracef0 ("Make_Rotatable: it's a group\n");
      for (i = start; i < newsize; i += objptr.objhdrp->size)
      { int object_changedby;

        error = Make_Rotatable (diag, hdroff + i, &object_changedby,
            &object_changed); /*don't raise error yet*/

        *changedby += object_changedby;
        if (error != NULL) break;

        hdrptr.bytep = diag->paper + hdroff; /*update pointer*/
        objptr.bytep = hdrptr.bytep + i;
        newsize += object_changedby;
      }

      if (object_changed)
        draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
            -(int) &hdrptr.groupp->size, sizeof (draw_sizetyp));

      hdrptr.groupp->size = newsize;
    }
    break;
  }

  if (object_changed) *changed = TRUE;
  return error;
}

os_error *draw_select_make_rotatable (diagrec *diag)

/*Converts sprites and text lines in the selection into transformed text
   lines and transformed sprites, respectively.*/

{ int i, j;
  draw_bboxtyp bound = draw_big_box;
  BOOL changed = FALSE;
  os_error *error;

  ftracef0 ("draw_select_make_rotatable\n");
  if (draw_selection->indx <= 0) return NULL;

  /*Start undo putting.*/
  ftracef0 ("draw_select_make_rotatable: calling draw_select_owns\n");
  if (draw_select_owns (diag)) draw_undo_separate_major_edits (diag);

  /*Put whole selection, in case it changes.*/
  ftracef0 ("draw_select_make_rotatable: calling draw_select_put_array\n");
  draw_select_put_array (diag, TRUE);

  /*Rely on all selected objects having bboxes.*/
  for (i = 0; i < draw_selection->indx; i++)
  { draw_objptr hdrptr;
    int hdroff = draw_selection->array [i], changedby;

    hdrptr.bytep = diag->paper + hdroff;

    draw_obj_bound_minmax2 (hdrptr, &bound);

    ftracef0 ("draw_select_make_rotatable: calling Make_Rotatable\n");
    error = Make_Rotatable (diag, hdroff, &changedby, &changed);
      /*don't raise error yet ...*/

    hdrptr.bytep = diag->paper + hdroff; /*update pointer*/

    /*Change all later offsets in the selection.*/
    if (changedby != 0)
      for (j = i + 1; j < draw_selection->indx; j++)
        draw_selection->array [j] += changedby;

    draw_obj_bound_object (hdrptr);
    draw_obj_bound_minmax2 (hdrptr, &bound);

    if (error != NULL)
    { werr (FALSE, error->errmess);
      break;
    }
  }

  ftracef0 ("EARLY\n"), draw_trace_db (diag);

  ftracef0 ("draw_select_make_rotatable: winding up\n");
  if (changed)
  { draw_modified (diag);
    draw_displ_redrawarea (diag, &bound);
    draw_undo_put (diag, draw_undo__redraw, (int) &bound, 0);
    draw_select_put_array (diag, TRUE);
  }

  return NULL;
}

BOOL draw_select_rotatable (diagrec *diag)

   /*Does the selection contain anything that can be rotated?*/

{ int i;
  draw_objptr hdrptr;

  ftracef0 ("draw_select_rotatable\n");
  for (i = 0; i < draw_selection->indx; i++)
  { hdrptr.bytep = diag->paper + draw_selection->array [i];
    if (draw_obj_rotatable (hdrptr))
       return TRUE;
  }

  return FALSE;
}
