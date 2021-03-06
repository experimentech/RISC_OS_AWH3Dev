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
/*-> c.DrawTrans
 *
 * Transformation functions for Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.13
 * History: 0.10 - 13 July 1989 - created from c.drawselect
 *          0.11 - 20 July 1989 - line width scaling added
 *                                undo added
 *          0.12 - 24 Aug  1989 - bug in group rotation fixed
 *          0.13 - 25 Sept 1989 - bug in scaling exactly htl or vtl lines
 *
 * This contains the code for scale, rotate, translate, etc. of both
 * selections and ranges of objects.
 *
 * Some of the control blocks are rather convoluted, and could be improved.
 *
 * The undo saved for scaling is grossly inefficient: it saves whole objects.
*/

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <limits.h>
#include <string.h>

#include "os.h"
#include "msgs.h"
#include "sprite.h"
#include "werr.h"
#include "visdelay.h"
#include "drawmod.h"
#include "jpeg.h"
#include "dbox.h"
#include "font.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawDispl.h"
#include "DrawGrid.h"
#include "DrawObject.h"
#include "DrawScan.h"
#include "DrawTextC.h"
#include "DrawTrans.h"
#include "DrawUndo.h"

#define SQR(x) ((x)*(x))
#define ABS(x) ((x) >= 0? (x): -(x))

static void transform_matrix (drawmod_transmat t, drawmod_transmat m)
  /*Apply t to m, in place (m modified, t not).*/

{ double T [6], M [6], R [6];
  int i;

  for (i = 0; i < 4; i++)
    T [i] = (double) t [i]/65536.0, M [i] = (double) m [i]/65536.0;

  T [4] = (double) t [4], M [4] = (double) m [4];
  T [5] = (double) t [5], M [5] = (double) m [5];

  R [0] = T [0]*M [0] + T [2]*M [1];
  R [1] = T [1]*M [0] + T [3]*M [1];
  R [2] = T [0]*M [2] + T [2]*M [3];
  R [3] = T [1]*M [2] + T [3]*M [3];
  R [4] = T [0]*M [4] + T [2]*M [5] + T [4];
  R [5] = T [1]*M [4] + T [3]*M [5] + T [5];

  for (i = 0; i < 4; i++)
    m [i] = (int) (65536.0*R [i]);

  m [4] = (int) R [4];
  m [5] = (int) R [5];
}

/*Set pointers for given range, and register for undo*/
/*flags are only relevant for scale*/
static void start_trans (diagrec *diag, int start, int end, char **s,
    char **e)

{ *s = start == -1? NULL: diag->paper + start;
  *e = end   == -1? NULL: diag->paper + end;
}

/*Used by operations that record the whole object data in undo*/

/*Record an undo block*/
static void full_set_undo (diagrec *diag, draw_objptr hdrptr)

{ if (diag)
    draw_undo_put (diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
        (int) hdrptr.bytep, hdrptr.objhdrp->size);
}

/*----------------------------------------------------------*/
/*translate (trans_x,trans_y)*/
/*translate objects by (trans_x,trans_y)*/
/*----------------------------------------------------------*/

static void translate_bbox (draw_objptr hdrptr, trans_str *trans)

{ draw_bboxtyp *bbox = draw_displ_bbox (hdrptr);
  bbox->x0 += trans->dx;
  bbox->y0 += trans->dy;
  bbox->x1 += trans->dx;
  bbox->y1 += trans->dy;
}

static void translate_coord (int *c, trans_str *trans)

{ c [0] += trans->dx;
  c [1] += trans->dy;
}

static void translate_text (draw_objptr hdrptr, trans_str *trans)

{ translate_bbox (hdrptr, trans);
  translate_coord (&hdrptr.textp->coord.x, trans);
}

static void translate_path (draw_objptr hdrptr, trans_str *trans)

{ drawmod_pathelemptr pathptr;

  translate_bbox (hdrptr, trans);

  /*translate all coordinates in the path by (trans_x,trans_y)*/
  pathptr = draw_obj_pathstart (hdrptr); /*Assumes >= 0 elements*/

  while (pathptr.end->tag != path_term)
    switch (pathptr.end->tag)
    { case path_move_2:
      case path_lineto:
        translate_coord (&pathptr.move2->x, trans);
        pathptr.move2++;
      break;

      case path_bezier:
        translate_coord (&pathptr.bezier->x1, trans);
        translate_coord (&pathptr.bezier->x2, trans);
        translate_coord (&pathptr.bezier->x3, trans);
        pathptr.bezier++;
      break;

      case path_closeline:
        pathptr.closeline++;
      break;
    }
}

static void translate_textcolumn (draw_objptr hdrptr, trans_str *trans)

{ draw_objptr parent;

  parent = draw_text_findParent (hdrptr.textcolp);
  if (!draw_text_parentSelected (parent))
  { translate_bbox (hdrptr, trans);
    draw_text_rebound (parent);
  }
}

static void translate_textarea (draw_objptr hdrptr, trans_str *trans)

{ draw_textcolhdr *column;
  draw_objptr      columnObject;

  /*Move the parent*/
  translate_bbox (hdrptr, trans);

  /*Move each column*/
  column = & (hdrptr.textareastrp->column);
  while (column->tag == draw_OBJTEXTCOL)
  { columnObject.textcolp = column++;
    translate_bbox (columnObject, trans);
  }
}

static void translate_trfmtext (draw_objptr hdrptr, trans_str *trans)

{ translate_bbox (hdrptr, trans);
  translate_coord (&hdrptr.trfmtextp->coord.x, trans);
}

static void translate_trfmsprite (draw_objptr hdrptr, trans_str *trans)

{ hdrptr.trfmspritep->bbox.x0 += trans->dx;
  hdrptr.trfmspritep->bbox.y0 += trans->dy;
  hdrptr.trfmspritep->bbox.x1 += trans->dx;
  hdrptr.trfmspritep->bbox.y1 += trans->dy;

  hdrptr.trfmspritep->trfm [4] += trans->dx;
  hdrptr.trfmspritep->trfm [5] += trans->dy;
}

static void translate_jpeg (draw_objptr hdrptr, trans_str *trans)

{ ftracef2 ("translate_jpeg by (%d, %d)\n", trans->dx, trans->dy);

  hdrptr.jpegp->bbox.x0 += trans->dx;
  hdrptr.jpegp->bbox.y0 += trans->dy;
  hdrptr.jpegp->bbox.x1 += trans->dx;
  hdrptr.jpegp->bbox.y1 += trans->dy;

  hdrptr.jpegp->trans_mat [4] += trans->dx;
  hdrptr.jpegp->trans_mat [5] += trans->dy;
}

static void translate_group (draw_objptr hdrptr, trans_str *trans);

static despatch_tab translatetab =
{ 0 /*fontlist*/,     translate_text,         translate_path,
  0 /*rect*/,         0 /*elli*/,             translate_bbox /*sprite*/,
  translate_group,    0 /*tagged*/,           0 /*'8'*/,
  translate_textarea, translate_textcolumn,   0 /*option*/,
  translate_trfmtext, translate_trfmsprite,   0,
  0,                  translate_jpeg
};

static void translate_group (draw_objptr hdrptr, trans_str *trans)

{ translate_bbox (hdrptr, trans);
  draw_scan_traverse (hdrptr.bytep, NULL, translatetab, trans);
}

void draw_trans_translate_without_undo (diagrec *diag, int start, int end,
    trans_str *trans)

{ char      *s, *e;

  start_trans (diag, start, end, &s, &e);
  draw_scan_traverse_splitredraw (s, e, diag, translatetab, trans, FALSE);
}

void draw_trans_translate (diagrec *diag, int start, int end,
    trans_str *trans)

{ draw_undo_trans undo;

  visdelay_begin (); /*Fix MED-1994. J R C 17th Jan 1994*/

  draw_trans_translate_without_undo (diag, start, end, trans);

  undo.start = start;
  undo.end   = end;
  undo.t     = *trans;

  draw_undo_put (diag, draw_undo__trans, (int)&undo, 0);

  visdelay_end (); /*Fix MED-1994. J R C 17th Jan 1994*/
}

/*----------------------------------------------------------*/
/*rotate (sin_theta,cos_theta)*/
/*rotate objects by angle theta about their centres*/
/*----------------------------------------------------------*/

typedef struct
{ double sin_theta, cos_theta;
  int    centx,     centy;
  BOOL   set_centre; /*TRUE to set own centre, else use supplied one*/
} rotate_typ;

static void matrix_from_rotate (drawmod_transmat m, rotate_typ *r)

/*      (1   0   cx) (cos theta  -sin theta   0)  (1   0  -cx)
   m := (0   1   cy) (sin theta   cos theta   0)  (0   1  -cy)
        (0   0    1) (0           0           1)  (0   0    1)
*/

{ m [0] = (int) (65536.0*r->cos_theta);
  m [1] = (int) (65536.0*r->sin_theta);
  m [2] =-m [1];
  m [3] = m [0];
  m [4] = (int) ((double) r->centx* (1.0 - r->cos_theta) +
      (double) r->centy*r->sin_theta);
  m [5] = (int) (- (double) r->centx*r->sin_theta +
      (double) r->centy* (1.0 - r->cos_theta));
}

/*Find the centre of the object*/
static void set_centre (draw_objptr hdrptr, rotate_typ *rotate)

{ draw_bboxtyp *bbox;
  if (rotate->set_centre)
  { bbox = draw_displ_bbox (hdrptr);
    rotate->centx = (bbox->x1 + bbox->x0)/2;
    rotate->centy = (bbox->y1 + bbox->y0)/2;
  }
}

/*Rotates a coordinate and applies an offset*/
/*The source, destination and offset each point to two element arrays,
   in the order x, y*/
static void rotate_coord (rotate_typ *r, double *from, int *to,
    double *offset)

{ from[0] -= r->centx;
  from[1] -= r->centy;

  to[0] = (int) (r->centx + from[0]*r->cos_theta - from[1]*r->sin_theta
                         - offset[0]);
  to[1] = (int) (r->centy + from[1]*r->cos_theta + from[0]*r->sin_theta
                         - offset[1]);
}

static void rotate_coord_int (rotate_typ *r, int *c, double *offset)

{ double from[2];
  from[0] = (double)c[0] - r->centx;
  from[1] = (double)c[1] - r->centy;

  c[0] = (int) (r->centx + from[0]*r->cos_theta - from[1]*r->sin_theta
                        - offset[0]);
  c[1] = (int) (r->centy + from[1]*r->cos_theta + from[0]*r->sin_theta
                        - offset[1]);
}

/*Find centre shift. shift -> int[2]. Used for textcols.*/
static void rotate_shift (draw_bboxtyp *box, rotate_typ *rotate,
                         trans_str *shift)

{ double pt[2], offset[2];

  /*Find centre of box*/
  offset[0] = pt[0] = ((double) box->x1 + (double) box->x0)/2;
  offset[1] = pt[1] = ((double) box->y1 + (double) box->y0)/2;
  shift->dx = shift->dy = 0;

  rotate_coord (rotate, pt, (int *) shift, offset);
}

static void rotate_text (draw_objptr hdrptr, rotate_typ *rotate)

{ double pt [2], offset [2];

  set_centre (hdrptr, rotate);

  pt [0] = ((double) hdrptr.textp->bbox.x1 +
      (double) hdrptr.textp->bbox.x0)/2;
  pt [1] = ((double) hdrptr.textp->bbox.y1 +
      (double) hdrptr.textp->bbox.y0)/2;

  offset [0] = pt [0] - hdrptr.textp->coord.x;
  offset [1] = pt [1] - hdrptr.textp->coord.y;

  rotate_coord (rotate, pt, &hdrptr.textp->coord.x, offset);
}

static void rotate_path (draw_objptr hdrptr, rotate_typ *rotate)

{ drawmod_pathelemptr pathptr;
  double     offset[2];

  set_centre (hdrptr, rotate);
  offset[0] = offset[1] = 1.0;

  /*coordinates are absolute, offset (centx,centy)*/
  /*relative to the centre of rotation*/
  /*rotate all coordinates in the path*/
  pathptr = draw_obj_pathstart (hdrptr);        /*Assumes >= 0 elements*/

  while (pathptr.end->tag != path_term)
    switch (pathptr.end->tag)
    { case path_move_2:
      case path_lineto:
        rotate_coord_int (rotate, &pathptr.move2->x, offset);
        pathptr.move2++;
      break;

      case path_bezier:
        rotate_coord_int (rotate, &pathptr.bezier->x1, offset);
        rotate_coord_int (rotate, &pathptr.bezier->x2, offset);
        rotate_coord_int (rotate, &pathptr.bezier->x3, offset);
        pathptr.bezier++;
      break;

      case path_closeline:
        pathptr.closeline++;
      break;
}   }

static void rotate_sprite (draw_objptr hdrptr, rotate_typ *rotate)

{ double pt[2], offset[2];
  int    wid, hei;
  set_centre (hdrptr, rotate);

  wid = hdrptr.spritep->bbox.x1 - hdrptr.spritep->bbox.x0;
  hei = hdrptr.spritep->bbox.y1 - hdrptr.spritep->bbox.y0;

  offset [0] = (double) wid/2.0;
  offset [1] = (double) hei/2.0;

  pt [0] = ((double) hdrptr.spritep->bbox.x1 +
      (double) hdrptr.spritep->bbox.x0)/2;
  pt [1] = ((double) hdrptr.spritep->bbox.y1 +
      (double) hdrptr.spritep->bbox.y0)/2;

  rotate_coord (rotate, pt, &hdrptr.spritep->bbox.x0, offset);
  hdrptr.spritep->bbox.x1 = hdrptr.spritep->bbox.x0 + wid;
  hdrptr.spritep->bbox.y1 = hdrptr.spritep->bbox.y0 + hei;
}


/*Text area - rotate about centre*/
static void rotate_textarea (draw_objptr hdrptr, rotate_typ *rotate)

{ trans_str trans;
  set_centre (hdrptr, rotate);

  /*Get the shift vector*/
  rotate_shift (draw_displ_bbox (hdrptr), rotate, &trans);

  /*Apply to the area and to each column*/
  translate_textarea (hdrptr, &trans);
}

static void rotate_textcol (draw_objptr hdrptr, rotate_typ *rotate)

{ draw_objptr parent = draw_text_findParent (hdrptr.textcolp);

  if (!draw_text_parentSelected (parent))
  { trans_str trans;

    set_centre (hdrptr, rotate);

    /*Get the shift vector for the column*/
    rotate_shift (draw_displ_bbox (hdrptr), rotate, &trans);

    /*Apply it*/
    translate_bbox (hdrptr, &trans);

    /*Rebound the parent*/
    draw_text_rebound (parent);
  }
}

static void rotate_trfmtext (draw_objptr hdrptr, rotate_typ *rotate)

{ drawmod_transmat mat;
  double offset [2];

  set_centre (hdrptr, rotate);
  offset [0] = offset [1] = 0.0;

  /*Get the matrix to be applied to this text line.*/
  matrix_from_rotate (mat, rotate);

  /*Update the origin.*/
  rotate_coord_int (rotate, &hdrptr.trfmtextp->coord.x, offset);

  ftracef3 ("draw_trans: applying: (%10d %10d %10d)\n",
      mat [0], mat [2], mat [4]);
  ftracef3 ("                      (%10d %10d %10d)\n",
      mat [1], mat [3], mat [5]);

  ftracef3 ("                    = (%10.2f %10.2f %10.2f)\n",
      mat [0]/65536.0, mat [2]/65536.0, mat [4]/256.0);
  ftracef3 ("                      (%10.2f %10.2f %10.2f)\n",
      mat [1]/65536.0, mat [3]/65536.0, mat [5]/256.0);

  /*Apply it.*/
  transform_matrix (mat, hdrptr.trfmtextp->trfm);

  /*Zap the translation parts back to 0.*/
  hdrptr.trfmtextp->trfm [4] = hdrptr.trfmtextp->trfm [5] = 0;

  ftracef3 ("draw_trans: result: (%10d %10d %10d)\n",
      hdrptr.trfmspritep->trfm [0],
      hdrptr.trfmspritep->trfm [2],
      hdrptr.trfmspritep->trfm [4]);
  ftracef3 ("                    (%10d %10d %10d)\n",
      hdrptr.trfmspritep->trfm [1],
      hdrptr.trfmspritep->trfm [3],
      hdrptr.trfmspritep->trfm [5]);

  ftracef3 ("                  = (%10.2f %10.2f %10.2f)\n",
      hdrptr.trfmspritep->trfm [0]/65536.0,
      hdrptr.trfmspritep->trfm [2]/65536.0,
      hdrptr.trfmspritep->trfm [4]/256.0);
  ftracef3 ("                    (%10.2f %10.2f %10.2f)\n",
      hdrptr.trfmspritep->trfm [1]/65536.0,
      hdrptr.trfmspritep->trfm [3]/65536.0,
      hdrptr.trfmspritep->trfm [5]/256.0);

  /*Bounding box now wrong - will be fixed later.*/
}

static void rotate_trfmsprite (draw_objptr hdrptr, rotate_typ *rotate)

{ drawmod_transmat mat;

  set_centre (hdrptr, rotate);

  /*Get the matrix to be applied to this sprite.*/
  matrix_from_rotate (mat, rotate);

  /*Apply it.*/
  transform_matrix (mat, hdrptr.trfmspritep->trfm);

  /*Bounding box now wrong - will be fixed later.*/
}

static void rotate_jpeg (draw_objptr hdrptr, rotate_typ *rotate)

{ drawmod_transmat mat;
  trans_str trans;

  set_centre (hdrptr, rotate);

  if (draw_jpegs_rotate)
  { /*Get the matrix to be applied to this JPEG.*/
    matrix_from_rotate (mat, rotate);

    /*Apply it.*/
    transform_matrix (mat, hdrptr.jpegp->trans_mat);
  }
  else
  { /*Get the shift vector*/
    rotate_shift (draw_displ_bbox (hdrptr), rotate, &trans);

    /*Apply*/
    translate_jpeg (hdrptr, &trans);
  }

  /*Bounding box now wrong - will be fixed later.*/
}

static void rotate_group (draw_objptr hdrptr, rotate_typ *rotate);

static despatch_tab rotatetab =
{ 0 /*fontlist*/,    rotate_text,       rotate_path,
  0 /*rect*/,        0 /*elli*/,        rotate_sprite,
  rotate_group,      0 /*tagged*/,      0 /*'8'*/,
  rotate_textarea,   rotate_textcol,    0 /*options*/,
  rotate_trfmtext,   rotate_trfmsprite, 0 /*trfmtextarea*/,
  0 /*trfmtextcol*/, rotate_jpeg
};

static void rotate_group (draw_objptr hdrptr, rotate_typ *rotate)

{ BOOL saved_set = rotate->set_centre;

  set_centre (hdrptr, rotate);
  rotate->set_centre = FALSE; /*Indicate centre is set*/
  draw_scan_traverse (hdrptr.bytep, NULL, rotatetab, rotate);
  rotate->set_centre = saved_set; /*Restore old centre flag*/
}

/*The main rotate function*/
void draw_trans_rotate (diagrec *diag, int start, int end,
    draw_trans_rotate_str *rotate)

{ rotate_typ  r;
  char *s, *e;
  draw_undo_rotate undo;

  r.sin_theta  = rotate->sin_theta;
  r.cos_theta  = rotate->cos_theta;
  r.set_centre = TRUE;

  visdelay_begin (); /*Fix MED-1994. J R C 17th Jan 1994*/

  start_trans (diag, start, end, &s, &e);
  draw_scan_traverse_withredraw (s, e, diag, rotatetab, &r, FALSE);

  undo.start = start;
  undo.end   = end;
  undo.sin_theta = rotate->sin_theta;
  undo.cos_theta = rotate->cos_theta;

  draw_undo_put (diag, draw_undo__rotate, (int)&undo, 0);

  visdelay_end (); /*Fix MED-1994. J R C 17th Jan 1994*/
}

/*----------------------------------------------------------*/
/*scale (scale block = dolines, old_Dx,old_Dy, new_Dx,new_Dy)
  scale objects by new_Dx/old_Dx, new_Dy/old_Dy
  maybe do lines as well
  The scaling method is to specify the new bbox for each object. The
  procedure for scaling is then:
  - if the new bbox has zero size in either dimension, widen it to the Draw
  equivalent of 1 OS unit.
  - if the new bbox exceeds int_max in either dimension, limit it to that
  - find the actual x and y factors
  - for each point in the box, scale it as if the box were at (0,0), then
  translate it to the final box. Thus, if the point were initially (x,y) in
  a box with BL at (x0, y0) and the final box had bottom left at (x0', y0'),
  with scale factors (sx, sy) then the point would transform to:
   (sx (x - x0) + x0', sy (y - y0) + y0')
  - apply the same scaling (sx, sy) to non-point items in the object, e.g.
  font sizes.
  In scaling itself, the new boxes can be found from the same calculation
  used in paint_scaleboxes.
  In undo, we can save the old bboxes.
*/
/*-----------------------------------------------------------*/

typedef struct

{ double   xscale, yscale; /*Scale, checked for each object*/
  double   rawxsc, rawysc; /*Unadjusted scale*/
  draw_objcoord org;
  BOOL     set_org;        /*TRUE to set own centre, else use supplied one*/
  int      table;          /*Index into despatch tables*/
  diagrec *diag;           /*Diag being scaled. NULL if undo not to be put*/
} scale_typ;

static void matrix_from_scale (drawmod_transmat m, scale_typ *s)

/*      (1   0   ox) (sx   0    0)  (1   0  -ox)
   m := (0   1   oy) (0    sy   0)  (0   1  -oy)
        (0   0    1) (0    0    1)  (0   0    1)
*/

{ m [0] = (int) (65536.0*s->xscale);
  m [1] = 0;
  m [2] = 0;
  m [3] = (int) (65536.0*s->yscale);
  m [4] = (int) ((double) s->org.x*(1.0 - s->xscale));
  m [5] = (int) ((double) s->org.y*(1.0 - s->yscale));
}

/*Set the scale factor, so that the resulting bbox is >= 1 OS unit*/
/*Also ensure that objects are not scaled beyond maximum size*/
/*Saves scaling info if diag is non NULL. It should in this case be taken*/
/*from scale->diag by the caller*/
static void scale_check (draw_objptr hdrptr, scale_typ *scale, diagrec *diag)

{
#if 0 /*JRC*/
  int dx = hdrptr.objhdrp->bbox.x1 - hdrptr.objhdrp->bbox.x0;
  int dy = hdrptr.objhdrp->bbox.y1 - hdrptr.objhdrp->bbox.y0;
#endif

#if 1
  /*Find minimum and maximum scaling factors, based on the overall size of
     the object. If the object has zero size in one direction, there is
     nothing we can do to change this. We must keep the scaling factor the
     same in this case, to avoid a position shift (on horizontal or vertical
     paths).
*/

  scale->xscale = fabs (scale->rawxsc);
  scale->yscale = fabs (scale->rawysc);

  ftracef2
  ( "draw_trans: scale_check: scale: input (%f, %f) ",
    scale->xscale,
    scale->yscale
  );

#if 0 /*JRC*/
  if (dx != 0)
  { if (dx * scale->xscale < draw_os_to_draw (1))
      scale->xscale = ((double)draw_os_to_draw (1)) / dx;
    if (dx * scale->xscale > INT_MAX)
      scale->xscale = ((double)INT_MAX) / dx;
  }

  if (dy != 0)
  { if (dy * scale->yscale < draw_os_to_draw (1))
      scale->yscale = ((double)draw_os_to_draw (1)) / dy;
    if (dy * scale->yscale > INT_MAX)
      scale->yscale = ((double)INT_MAX) / dy;
  }
#endif
#else
  if (dx == 0)
    scale->xscale = 0;
  else if (dx * scale->xscale < draw_os_to_draw (1))
    scale->xscale = ((double)draw_os_to_draw (1)) / dx;
  else if (dx * scale->xscale > INT_MAX)
    scale->xscale = ((double)INT_MAX) / dx;

  if (dy == 0)
    scale->yscale = 0;
  else if (dy * scale->yscale < draw_os_to_draw (1))
    scale->yscale = (double) draw_os_to_draw (1)/dy;
  else if (dy * scale->yscale > INT_MAX)
    scale->yscale = (double) INT_MAX/dy;
#endif

  if (scale->rawxsc < 0) scale->xscale = -scale->xscale;
  if (scale->rawysc < 0) scale->yscale = -scale->yscale;

  ftracef2 ("output (%f, %f)\n", scale->xscale, scale->yscale);

  /*Extract origin*/
  if (scale->set_org)
  { draw_bboxtyp *bbox = draw_displ_bbox (hdrptr);
    scale->org.x = bbox->x0;
    scale->org.y = bbox->y1;
    ftracef2 ("draw_trans: scale_check: origin is at (%d, %d)\n",
        scale->org.x, scale->org.y);
  }

  full_set_undo (diag, hdrptr);
}

/*Low level point scale*/

static int point_scale (int p2, double p, int p1)

{ int ret = (int) ((1.0 - p)*p1 + p*p2);

  ftracef4 ("draw_trans: point_scale: p1 %d p2 %d p %f -> %d\n",
      p1, p2, p, ret);

  return ret;
}

/*Same, but floating point*/

static double fpoint_scale (double p2, double p, int p1)

{ double ret = (1.0 - p)*p1 + p*p2;

  ftracef4 ("draw_trans: fpoint_scale: p1 %d p2 %f p %f -> %f\n",
      p1, p2, p, ret);

  return ret;
}

/*Scale a point*/
static void scale_coord (scale_typ *scale, int *point)

{ point[0] = point_scale (point[0], scale->xscale, scale->org.x);
  point[1] = point_scale (point[1], scale->yscale, scale->org.y);
}

/*Same, but floating point*/
static void fscale_coord (scale_typ *scale, double *point)

{ point [0] = fpoint_scale (point [0], scale->xscale, scale->org.x);
  point [1] = fpoint_scale (point [1], scale->yscale, scale->org.y);
}

static void scale_coord_abs (scale_typ *scale, int *point)

{ point[0] = point_scale (point[0], fabs (scale->xscale), scale->org.x);
  point[1] = point_scale (point[1], fabs (scale->yscale), scale->org.y);

/*>>>  point[0] = (int) ((point[0] - scale->org.x) * fabs (scale->xscale)
                   + scale->org.x);
  point[1] = (int) ((point[1] - scale->org.y) * fabs (scale->yscale)
                   + scale->org.y);
*/
}

/*Scale text: the font manager cannot accept -ve point sizes, so we cannot*/
/*reflect text (ie so it reads backwards/upside-down) or -ve (x/y)scale.*/
/*For -ve scaling, therefore translate the text to its mirror position,*/
/*then scale it by the absolute amount.*/
static void scale_text (draw_objptr hdrptr, scale_typ *scale)

{ double fsizex, fsizey;

  scale_check (hdrptr, scale, scale->diag);

  fsizex = hdrptr.textp->fsizex*fabs (scale->xscale),
  fsizey = hdrptr.textp->fsizey*fabs (scale->yscale);

  if (fsizex <= -(double) MAX_COORD || fsizex >= (double) MAX_COORD)
  { werr(FALSE, msgs_lookup ("DrawO"), (double) MAX_COORD/hdrptr.textp->fsizex);
    return;
  }

  if (fsizey <= -(double) MAX_COORD || fsizey >= (double) MAX_COORD)
  { werr(FALSE, msgs_lookup ("DrawO"), (double) MAX_COORD/hdrptr.textp->fsizey);
    return;
  }

  if (scale->xscale < 0)
    hdrptr.textp->coord.x -= hdrptr.textp->bbox.x1 + hdrptr.textp->bbox.x0
                             - 2*scale->org.x;
  if (scale->yscale < 0)
    hdrptr.textp->coord.y -= hdrptr.textp->bbox.y1 + hdrptr.textp->bbox.y0
                             - 2*scale->org.y;

  hdrptr.textp->fsizex = (int) fsizex;
  hdrptr.textp->fsizey = (int) fsizey;

  scale_coord_abs (scale, &hdrptr.textp->coord.x);
  ftracef4 ("text scaled to size (%d, %d) at (%d, %d)\n",
      hdrptr.textp->fsizex, hdrptr.textp->fsizey,
      hdrptr.textp->coord.x, hdrptr.textp->coord.y);
}

/*Scale lines in path*/
static void scale_pathLines (draw_objptr hdrptr, scale_typ *scale)

{ hdrptr.pathp->pathwidth =
      (int) (hdrptr.pathp->pathwidth*fabs (scale->xscale));
}

/*Check scaling, then scale lines in path*/
static void scale_pathL (draw_objptr hdrptr, scale_typ *scale)

{ scale_check (hdrptr, scale, scale->diag);
  scale_pathLines (hdrptr, scale);
}

/*Scale body of path*/
static void scale_pathBody (draw_objptr hdrptr, scale_typ *scale)

{ drawmod_pathelemptr pathptr;

  /*scale all coordinates in the path, relative to (orgx,orgy)*/
  pathptr = draw_obj_pathstart (hdrptr);        /*Assumes >= 0 elements*/

  while (pathptr.end->tag != path_term)
    switch (pathptr.end->tag)
    { case path_move_2:
      case path_lineto:
        scale_coord (scale, &pathptr.move2->x);
        pathptr.move2++;
      break;

      case path_bezier:
        scale_coord (scale, &pathptr.bezier->x1);
        scale_coord (scale, &pathptr.bezier->x2);
        scale_coord (scale, &pathptr.bezier->x3);
        pathptr.bezier++;
      break;

      case path_closeline:
        pathptr.closeline++;
      break;
}   }

/*Check scaling, then scale body of path*/
static void scale_pathB (draw_objptr hdrptr, scale_typ *scale)

{ scale_check (hdrptr, scale, scale->diag);
  scale_pathBody (hdrptr, scale);
}

/*Scale both parts of path*/
static void scale_pathBL (draw_objptr hdrptr, scale_typ *scale)

{ scale_check (hdrptr, scale, scale->diag);
  scale_pathBody (hdrptr, scale);
  scale_pathLines (hdrptr, scale);
}

static void scale_sprite (draw_objptr hdrptr, scale_typ *scale)

{ int spriwid = hdrptr.spritep->bbox.x1 - hdrptr.spritep->bbox.x0;
  int sprihei = hdrptr.spritep->bbox.y1 - hdrptr.spritep->bbox.y0;

  sprite_id id;

  id.tag    = sprite_id_addr;
  id.s.addr = &hdrptr.spritep->sprite;

  scale_check (hdrptr, scale, scale->diag);

  if (scale->xscale < 0)
  { hdrptr.spritep->bbox.x0 = 2*scale->org.x - hdrptr.spritep->bbox.x1;
    sprite_flip_y (UNUSED_SA, &id);
  }

  if (scale->yscale < 0)
  { hdrptr.spritep->bbox.y0 = 2*scale->org.y - hdrptr.spritep->bbox.y1;
    sprite_flip_x (UNUSED_SA, &id);
  }

  scale_coord_abs (scale, &hdrptr.spritep->bbox.x0);
  hdrptr.spritep->bbox.x1 = (int) (hdrptr.spritep->bbox.x0 + spriwid
                                  * fabs (scale->xscale));
  hdrptr.spritep->bbox.y1 = (int) (hdrptr.spritep->bbox.y0 + sprihei
                                  * fabs (scale->yscale));
}

static void scale_textC (draw_objptr hdrptr, scale_typ *scale)

{ draw_bboxtyp box;
  int width, height;
  int topx, basey;
  draw_textcolhdr *column = hdrptr.textcolp;

  /*Calculate new width and height*/
  box = column->bbox;
  width = (int) (scale->xscale* ((double) box.x1 - (double) box.x0));
  height= (int) (scale->yscale* ((double) box.y1 - (double) box.y0));

  /*Find new corner*/
  topx  = scale->org.x + width;
  basey = scale->org.y - height;

  /*Swap corners if wrong way round; else log new bbox*/
  if (topx > scale->org.x)
  { column->bbox.x0 = scale->org.x;
    column->bbox.x1 = topx;
  }
  else
  { column->bbox.x0 = topx;
    column->bbox.x1 = scale->org.x;
  }

  if (basey < scale->org.y)
  { column->bbox.y0 = basey;
    column->bbox.y1 = scale->org.y;
  }
  else
  { column->bbox.y0 = scale->org.y;
    column->bbox.y1 = basey;
  }
}

static void scale_textarea (draw_objptr hdrptr, scale_typ *scale)

{ /*draw_textcolhdr *column;*/

  /*scale_check may be redundant if there is not just one column. We call it
     to set for undo*/
  scale_check (hdrptr, scale, scale->diag);

  if (draw_text_oneColumn (hdrptr))
  { draw_objptr colptr;

    /*Scale the column*/
    colptr.textcolp = &hdrptr.textareastrp->column;
    scale_textC (colptr, scale);

    /*Copy the bbox to area*/
    hdrptr.textareastrp->bbox = colptr.textcolp->bbox; /*not column->bbox. JRC*/
  }
}

static void scale_textcolumn (draw_objptr hdrptr, scale_typ *scale)

{ draw_objptr parent = draw_text_findParent (hdrptr.textcolp);

  /*Save undo on the parent*/
  full_set_undo (scale->diag, parent);

  scale_check (hdrptr, scale, NULL);

  /*Do the scaling*/
  scale_textC (hdrptr, scale);

  /*Recalculate parent bbox*/
  draw_text_rebound (parent);
}

static void scale_trfmtext (draw_objptr hdrptr, scale_typ *scale)

{ double
    m0 = (double) hdrptr.trfmtextp->trfm [0]/65536.0,
    m1 = (double) hdrptr.trfmtextp->trfm [1]/65536.0,
    m2 = (double) hdrptr.trfmtextp->trfm [2]/65536.0,
    m3 = (double) hdrptr.trfmtextp->trfm [3]/65536.0,
    alpha, beta, rx, ry;
  int t;

  scale_check (hdrptr, scale, scale->diag);
  alpha = scale->xscale;
  beta  = scale->yscale;

  /*Factors for the width and height of the text.*/
  rx = sqrt (SQR (alpha*m0) + SQR (beta*m1));
  ry = rx != 0.0?
      fabs (sqrt (SQR (m2) + SQR (m3))*alpha*beta*(m0*m3 - m1*m2)/rx): 0.0;
  ftracef2 ("factors for (width, height) are (%f, %f)\n", rx, ry);

  #if TRACE
    ftracef (__FILE__, __LINE__,
      "matrix is (%10.2f   %10.2f), scale (%f, %f)\n"
      "          (%10.2f   %10.2f), centre (%d, %d)\n",
      m0, m2, alpha, beta,
      m1, m3, scale->org.x, scale->org.y
    );
  #endif

  /*Avoid fsize[xy] falling below 1/16pt*/
  ftracef2 ("size: start %d by %d\n",
      hdrptr.trfmtextp->fsizex, hdrptr.trfmtextp->fsizey);
  t = (int) (hdrptr.trfmtextp->fsizex*rx);
  if (t >= dbc_OnePoint/16)
    hdrptr.trfmtextp->fsizex = t;
  else
  { hdrptr.trfmtextp->fsizex = dbc_OnePoint/16;
    rx = (double) dbc_OnePoint/(16.0*(double) hdrptr.trfmtextp->fsizex);
  }

  t = (int) (hdrptr.trfmtextp->fsizey*ry);
  if (t >= dbc_OnePoint/16)
    hdrptr.trfmtextp->fsizey = t;
  else
  { hdrptr.trfmtextp->fsizey = dbc_OnePoint/16;
    ry = (double) dbc_OnePoint/(16.0*(double) hdrptr.trfmtextp->fsizey);
  }
  ftracef2 ("size: end %d by %d\n", hdrptr.trfmtextp->fsizex,
    hdrptr.trfmtextp->fsizey);

  ftracef2 ("origin: start (%d, %d)\n", hdrptr.trfmtextp->coord.x,
      hdrptr.trfmtextp->coord.y);
  /*Move the origin of the text.*/
  scale_coord (scale, &hdrptr.trfmtextp->coord.x);
  ftracef2 ("origin: end (%d, %d)\n", hdrptr.trfmtextp->coord.x,
      hdrptr.trfmtextp->coord.y);

  /*Update the matrix.*/
  hdrptr.trfmtextp->trfm [0] =
      (int) (hdrptr.trfmtextp->trfm [0]*alpha/rx);
  hdrptr.trfmtextp->trfm [1] =
      (int) (hdrptr.trfmtextp->trfm [1]*beta/rx);
  hdrptr.trfmtextp->trfm [2] =
      (int) (hdrptr.trfmtextp->trfm [2]*alpha/ry);
  hdrptr.trfmtextp->trfm [3] =
      (int) (hdrptr.trfmtextp->trfm [3]*beta/ry);
}

static void scale_trfmsprite (draw_objptr hdrptr, scale_typ *scale)

{ drawmod_transmat mat;

  scale_check (hdrptr, scale, scale->diag);
  matrix_from_scale (mat, scale);

  ftracef3 ("draw_trans: applying: (%10d %10d %10d)\n",
      mat [0], mat [2], mat [4]);
  ftracef3 ("                      (%10d %10d %10d)\n",
      mat [1], mat [3], mat [5]);

  ftracef3 ("                    = (%10.2f %10.2f %10.2f)\n",
      mat [0]/65536.0, mat [2]/65536.0, mat [4]/256.0);
  ftracef3 ("                      (%10.2f %10.2f %10.2f)\n",
      mat [1]/65536.0, mat [3]/65536.0, mat [5]/256.0);

  /*Apply it.*/
  transform_matrix (mat, hdrptr.trfmspritep->trfm);

  ftracef3 ("draw_trans: result: (%10d %10d %10d)\n",
      hdrptr.trfmspritep->trfm [0],
      hdrptr.trfmspritep->trfm [2],
      hdrptr.trfmspritep->trfm [4]);
  ftracef3 ("                    (%10d %10d %10d)\n",
      hdrptr.trfmspritep->trfm [1],
      hdrptr.trfmspritep->trfm [3],
      hdrptr.trfmspritep->trfm [5]);

  ftracef3 ("                  = (%10.2f %10.2f %10.2f)\n",
      hdrptr.trfmspritep->trfm [0]/65536.0,
      hdrptr.trfmspritep->trfm [2]/65536.0,
      hdrptr.trfmspritep->trfm [4]/256.0);
  ftracef3 ("                    (%10.2f %10.2f %10.2f)\n",
      hdrptr.trfmspritep->trfm [1]/65536.0,
      hdrptr.trfmspritep->trfm [3]/65536.0,
      hdrptr.trfmspritep->trfm [5]/256.0);

  /*Bounding box now wrong - will be fixed later.*/
}

static void scale_jpeg (draw_objptr hdrptr, scale_typ *scale)

{ drawmod_transmat mat, m;

  scale_check (hdrptr, scale, scale->diag);

  if (!(draw_jpegs_rotate || (scale->xscale >= 0 && scale->yscale >= 0)))
  { /*If we are asked to do something to the JPEG which would result in a
      negative scale factor, we modify the matrix beforehand so that by the
      time it's all over, the factors are still positive.*/
    m [1] = m [2] = 0;

    if (scale->xscale >= 0)
      m [0] =  0x10000, m [4] = 0;
    else
      m [0] = -0x10000, m [4] = hdrptr.jpegp->width;

    if (scale->yscale >= 0)
      m [3] =  0x10000, m [5] = 0;
    else
      m [3] = -0x10000, m [5] = hdrptr.jpegp->height;

    transform_matrix (hdrptr.jpegp->trans_mat, m);
    memcpy (hdrptr.jpegp->trans_mat, m, sizeof m);
  }

  matrix_from_scale (mat, scale);

  /*Apply it.*/
  transform_matrix (mat, hdrptr.jpegp->trans_mat);

  /*Bounding box now wrong - will be fixed later.*/ }

static void scale_group (draw_objptr hdrptr, scale_typ *scale);

/*Array of despatch tables: indexed by {line, body, both}*/
static despatch_tab scaletab[3] =

{ /*Line only*/
  { 0 /*fontlist*/,     0 /*text*/,         scale_pathL,
    0 /*rect*/,         0 /*elli*/,         0 /*sprite*/,
    scale_group
  },

  /*Body only*/
  { 0 /*fontlist*/,     scale_text,         scale_pathB,
    0 /*rect*/,         0 /*elli*/,         scale_sprite,
    scale_group,        0 /*tagged*/,       0 /*'8'*/,
    scale_textarea,     scale_textcolumn,   0 /*option*/,
    scale_trfmtext,     scale_trfmsprite,   0,
    0,                  scale_jpeg
  },

  /*Both body and lines*/
  { 0 /*fontlist*/,     scale_text,         scale_pathBL,
    0 /*rect*/,         0 /*elli*/,         scale_sprite,
    scale_group,        0 /*tagged*/,       0 /*'8'*/,
    scale_textarea,     scale_textcolumn,   0 /*option*/,
    scale_trfmtext,     scale_trfmsprite,   0,
    0,                  scale_jpeg
  }
};

static void scale_group (draw_objptr hdrptr, scale_typ *scale)

{ scale_typ saved_scale = *scale;

  /*Save whole group for undoing, if at top level*/
  full_set_undo (scale->diag, hdrptr);

  if (scale->set_org)  /*Only applies at top level of grouping*/
  { draw_bboxtyp *bbox = draw_displ_bbox (hdrptr);
    scale->org.x = bbox->x0;
    scale->org.y = bbox->y1;
    ftracef2
    ( "draw_trans: scale_group: origin is at (%d, %d)\n",
      scale->org.x, scale->org.y
    );
  }

  scale->set_org = FALSE;
  scale->diag    = NULL;  /*Prevent saving for undo*/

  draw_scan_traverse (hdrptr.bytep, NULL, scaletab[scale->table], scale);

  *scale = saved_scale;
}

/*Main scale function*/
void draw_trans_scale (diagrec *diag, int start, int end,
    draw_trans_scale_str *scale)

{ scale_typ sc;
  char *s, *e;
  double scale_factor;

  ftracef4
  ( "draw_trans_scale: scale old (%f, %f) new (%f, %f)\n",
    scale->old_Dx, scale->old_Dy,
    scale->new_Dx, scale->new_Dy
  );

  visdelay_begin (); /*Fix MED-1994. J R C 17th Jan 1994*/

  sc.rawxsc  = scale->old_Dx == 0.0? 0.0: scale->new_Dx/scale->old_Dx;
  sc.rawysc  = scale->old_Dy == 0.0? 0.0: scale->new_Dy/scale->old_Dy;
  sc.xscale  = sc.rawxsc;
  sc.yscale  = sc.rawysc;
  sc.set_org = TRUE;
  sc.table   = scale->u.flags.dolines? (scale->u.flags.dobody? 2: 0): 1;
  sc.diag    = diag;

  ftracef2 ("draw_trans_scale: sc %f %f\n", sc.rawxsc, sc.rawysc);

  /*use the larger scale to check for line widths - don't bother checking
    scales less than 1*/
  if (fabs (scale_factor = sc.rawxsc > sc.rawysc? sc.rawxsc: sc.rawysc) >
      1.0)
  { if (scale->u.flags.dobody)
    { draw_bboxtyp selection_bbox;
      struct {double x0, y0, x1, y1;} fbbox;
      int i, a, b;

      /*For safety, check that the numbers are o k first.*/
      draw_obj_bound_selection (&selection_bbox);
      for (i = 0; i < 4; i++)
        (&fbbox.x0) [i] = (&selection_bbox.x0) [i];

      sc.org.x = selection_bbox.x0;
      sc.org.y = selection_bbox.y1;
      fscale_coord (&sc, &fbbox.x0); /*lucky ...*/
      fscale_coord (&sc, &fbbox.x1);
      ftracef2 ("scaled width is (%f, %f)\n",
          fbbox.x1 - fbbox.x0, fbbox.y1 - fbbox.y0);
      a = selection_bbox.x1 - selection_bbox.x0;
      b = selection_bbox.y1 - selection_bbox.y0;

      for (i = 0; i < 4; i++)
         if (!(-(double) MAX_COORD <= (&fbbox.x0) [i] &&
             (&fbbox.x0) [i] <= (double) MAX_COORD))
         { double f1, f2, f;

           f1 = a != 0? ((double) MAX_COORD - sc.org.x)/(double) a: INT_MAX;
           f2 = b != 0? ((double) MAX_COORD - sc.org.y)/(double) b: INT_MAX;
               /*If both are 0, we can't possibly have got here*/

           f = f1 < f2? f1: f2;

           werr (FALSE, msgs_lookup ("DrawO"), f > 1.0? f: 1.0);
           return;
    }    }

    if (scale->u.flags.dolines)
    { int width;
      double scaled_width;

      /*Check no line would get too wide.*/
      draw_obj_bound_selection_width (&width);

      scaled_width = (double) width*scale_factor;

      if (!(-(double) MAX_COORD <= scaled_width &&
          (double) scaled_width <= MAX_COORD))
      { double f = (double) MAX_COORD/(double) width;

        werr (FALSE, msgs_lookup ("DrawO"), f);
        return;
      }
    }
  }

  start_trans (diag, start, end, &s, &e);
  draw_scan_traverse_withredraw (s, e, diag, scaletab [sc.table], &sc,
      FALSE);

  visdelay_end (); /*Fix MED-1994. J R C 17th Jan 1994*/
}

/*----------------------------------------------------------*/
/*gridsnap (diag, vuue)*/
/*snap all vertices to grid in window vuue*/
/*----------------------------------------------------------*/

typedef
  struct
  { diagrec *diag;
    viewrec *vuue;
    int dx, dy;
    BOOL set_offset;
  } gridsnap_str;

/*Set the offset for a whole group.*/
static void set_offset (draw_objptr hdrptr, gridsnap_str *snap)

{ draw_objcoord c;

  /*Text lines take the offset from their baseline; paths go from their
    start point; all other objects just snap thw top-left of the bounding
    box.*/
  if (snap->set_offset)
    switch (hdrptr.objhdrp->tag)
    { case draw_OBJTEXT:
        c.x = hdrptr.textp->coord.x;
        c.y = hdrptr.textp->coord.y;

        draw_grid_snap (snap->vuue, &c);

        snap->dx = c.x - hdrptr.textp->coord.x;
        snap->dy = c.y - hdrptr.textp->coord.y;
      break;

      case draw_OBJPATH:
      { drawmod_pathelemptr path_elem = draw_obj_pathstart (hdrptr);

        #if TRACE
          assert (path_elem.end->tag == path_move_2);
        #endif

        if (path_elem.end->tag == path_move_2) /*and it had better*/
        { c.x = path_elem.move2->x;
          c.y = path_elem.move2->y;

          draw_grid_snap (snap->vuue, &c);

          snap->dx = c.x - path_elem.move2->x;
          snap->dy = c.y - path_elem.move2->y;
        }
        else /*Oops*/
          snap->dx = snap->dy = 0;
      }
      break;

      case draw_OBJTRFMTEXT:
        c.x = hdrptr.trfmtextp->coord.x;
        c.y = hdrptr.trfmtextp->coord.y;

        draw_grid_snap (snap->vuue, &c);

        snap->dx = c.x - hdrptr.trfmtextp->coord.x;
        snap->dy = c.y - hdrptr.trfmtextp->coord.y;
      break;

      default:
        { draw_bboxtyp *bbox = draw_displ_bbox (hdrptr);
          c.x = bbox->x0;
          c.y = bbox->y1;

          draw_grid_snap (snap->vuue, &c);

          snap->dx = c.x - bbox->x0;
          snap->dy = c.y - bbox->y1;
        }
      break;
}   }

static void gridsnap_text (draw_objptr hdrptr, gridsnap_str *snap)

{ full_set_undo (snap->diag, hdrptr);
  set_offset (hdrptr, snap);

  hdrptr.textp->coord.x += snap->dx;
  hdrptr.textp->coord.y += snap->dy;
    /*was draw_grid_snap (snap->vuue, &hdrptr.textp->coord);*/

  /*Rebound the object*/
  draw_obj_bound_object (hdrptr);
}

static void gridsnap_path (draw_objptr hdrptr, gridsnap_str *snap)

{ trans_str     trans;

  full_set_undo (snap->diag, hdrptr);
  set_offset (hdrptr, snap);
  ftracef2 ("draw_trans: gridsnap_path: offset set to (%d, %d)\n",
      snap->dx, snap->dy);

  #if 0
    dx = oldbox->x1 - oldbox->x0;
    dy = oldbox->y1 - oldbox->y0;

    /*Find the bbox of the path and snap it to the grid*/
    newbox = *oldbox;
    draw_grid_snap (snap->vuue, (draw_objcoord *)&newbox.x0);
    draw_grid_snap (snap->vuue, (draw_objcoord *)&newbox.x1);

    /*Translate the path to give it the same top left as the new box*/
    trans.dx = newbox.x0 - oldbox->x0;
    trans.dy = newbox.y1 - oldbox->y1;
    translate_path (hdrptr, &trans);

    /*Scale the path into the new box. Origin is top left*/
    scale.rawxsc  = dx == 0.0? 0.0:
        ((double) newbox.x1 - (double) newbox.x0)/dx;
    scale.rawysc  = dy == 0.0? 0.0:
        ((double) newbox.y1 - (double) newbox.y0)/dy;
    scale.set_org = TRUE; /*Origin is not set*/
    scale.diag    = NULL;
    scale_pathB (hdrptr, &scale);
  #else
    /*Translate the path*/
    trans.dx = snap->dx;
    trans.dy = snap->dy;
    translate_path (hdrptr, &trans);
  #endif

  /*Rebound the object*/
  draw_obj_bound_object (hdrptr);
}

static void gridsnap_sprite (draw_objptr hdrptr, gridsnap_str *snap)

{
  #if 0
    draw_objcoord pt;

    pt.x = hdrptr.spritep->bbox.x0;
    pt.y = hdrptr.spritep->bbox.y1;

    full_set_undo (snap->diag, hdrptr);
    draw_grid_snap (snap->vuue, &pt);

    /*Get the order right.*/
    hdrptr.spritep->bbox.x1 += pt.x - hdrptr.spritep->bbox.x0;
    hdrptr.spritep->bbox.y0 += pt.y - hdrptr.spritep->bbox.y1;

    hdrptr.spritep->bbox.x0 = pt.x;
    hdrptr.spritep->bbox.y1 = pt.y;
  #else
    full_set_undo (snap->diag, hdrptr);
    set_offset (hdrptr, snap);

    hdrptr.spritep->bbox.x0 += snap->dx;
    hdrptr.spritep->bbox.y0 += snap->dy;

    hdrptr.spritep->bbox.x1 += snap->dx;
    hdrptr.spritep->bbox.y1 += snap->dy;

    /*Doesn't need rebounding*/
  #endif
}

static void gridsnap_textcol (draw_objptr hdrptr, gridsnap_str *snap)

{ full_set_undo (snap->diag, hdrptr);

  #if 0
    pt.x = hdrptr.textcolp->bbox.x0;
    pt.y = hdrptr.textcolp->bbox.y1;

    draw_grid_snap (snap->vuue, &pt);

    /*Store the distance to move in pt*/
    pt.x -= hdrptr.textcolp->bbox.x0;
    pt.y -= hdrptr.textcolp->bbox.y1;

    hdrptr.textcolp->bbox.x0 += pt.x;
    hdrptr.textcolp->bbox.y0 += pt.y;
    hdrptr.textcolp->bbox.x1 += pt.x;
    hdrptr.textcolp->bbox.y1 += pt.y;
  #else
    set_offset (hdrptr, snap);

    hdrptr.textcolp->bbox.x0 += snap->dx;
    hdrptr.textcolp->bbox.y0 += snap->dy;
    hdrptr.textcolp->bbox.x1 += snap->dx;
    hdrptr.textcolp->bbox.y1 += snap->dy;
  #endif
}

static void gridsnap_textarea (draw_objptr hdrptr, gridsnap_str *snap)

{ draw_textcolhdr *textcol_hdrptr;

  full_set_undo (snap->diag, hdrptr);

  #if 0
    pt.x = hdrptr.textareap->bbox.x0;
    pt.y = hdrptr.textareap->bbox.y1;

    draw_grid_snap (snap->vuue, &pt);

    /*Store the distance to move in pt*/
    pt.x -= hdrptr.textareap->bbox.x0;
    pt.y -= hdrptr.textareap->bbox.y1;

    /*Move all the textcols*/
    for
    ( textcol_hdrptr = (draw_textcolhdr *) (hdrptr.textareap + 1);
      textcol_hdrptr->tag != 0;
      textcol_hdrptr++
    )
    { textcol_hdrptr->bbox.x0 += pt.x;
      textcol_hdrptr->bbox.y0 += pt.y;
      textcol_hdrptr->bbox.x1 += pt.x;
      textcol_hdrptr->bbox.y1 += pt.y;
    }

    /*Move the textarea*/
    hdrptr.textareap->bbox.x0 += pt.x;
    hdrptr.textareap->bbox.y0 += pt.y;
    hdrptr.textareap->bbox.x1 += pt.x;
    hdrptr.textareap->bbox.y1 += pt.y;
  #else
    set_offset (hdrptr, snap);

    /*Move all the textcols*/
    for (textcol_hdrptr = (draw_textcolhdr *) (hdrptr.textareap + 1);
        textcol_hdrptr->tag != 0; textcol_hdrptr++)
    { textcol_hdrptr->bbox.x0 += snap->dx;
      textcol_hdrptr->bbox.y0 += snap->dy;
      textcol_hdrptr->bbox.x1 += snap->dx;
      textcol_hdrptr->bbox.y1 += snap->dy;
    }

    /*Move the textarea*/
    hdrptr.textareap->bbox.x0 += snap->dx;
    hdrptr.textareap->bbox.y0 += snap->dy;
    hdrptr.textareap->bbox.x1 += snap->dx;
    hdrptr.textareap->bbox.y1 += snap->dy;
  #endif
}

static void gridsnap_trfmtext (draw_objptr hdrptr, gridsnap_str *snap)

{ full_set_undo (snap->diag, hdrptr);

  #if 0
    draw_grid_snap (snap->vuue, &hdrptr.trfmtextp->coord);
  #else
    set_offset (hdrptr, snap);

    hdrptr.trfmtextp->coord.x += snap->dx;
    hdrptr.trfmtextp->coord.y += snap->dy;

    draw_obj_bound_object (hdrptr);
  #endif
}

static void gridsnap_trfmsprite (draw_objptr hdrptr, gridsnap_str *snap)

{ draw_objcoord pt;

  pt.x = hdrptr.trfmspritep->bbox.x0;
  pt.y = hdrptr.trfmspritep->bbox.y1;

  full_set_undo (snap->diag, hdrptr);

  #if 0
    draw_grid_snap (snap->vuue, &pt);

    /*Get the order right.*/
    hdrptr.trfmspritep->trfm [4] += pt.x - hdrptr.trfmspritep->bbox.x0;
    hdrptr.trfmspritep->trfm [5] += pt.y - hdrptr.trfmspritep->bbox.y1;

    hdrptr.trfmspritep->bbox.x1 += pt.x - hdrptr.trfmspritep->bbox.x0;
    hdrptr.trfmspritep->bbox.y0 += pt.y - hdrptr.trfmspritep->bbox.y1;

    hdrptr.trfmspritep->bbox.x0 = pt.x;
    hdrptr.trfmspritep->bbox.y1 = pt.y;
  #else
    set_offset (hdrptr, snap);

    hdrptr.trfmspritep->bbox.x0 += snap->dx;
    hdrptr.trfmspritep->bbox.y0 += snap->dy;
    hdrptr.trfmspritep->bbox.x1 += snap->dx;
    hdrptr.trfmspritep->bbox.y1 += snap->dy;

    hdrptr.trfmspritep->trfm [4] += snap->dx;
    hdrptr.trfmspritep->trfm [5] += snap->dy;
  #endif
}

static void gridsnap_jpeg (draw_objptr hdrptr, gridsnap_str *snap)

{ draw_objcoord pt;

  pt.x = hdrptr.jpegp->bbox.x0;
  pt.y = hdrptr.jpegp->bbox.y1;

  full_set_undo (snap->diag, hdrptr);
  set_offset (hdrptr, snap);

  hdrptr.jpegp->bbox.x0 += snap->dx;
  hdrptr.jpegp->bbox.y0 += snap->dy;
  hdrptr.jpegp->bbox.x1 += snap->dx;
  hdrptr.jpegp->bbox.y1 += snap->dy;

  hdrptr.jpegp->trans_mat [4] += snap->dx;
  hdrptr.jpegp->trans_mat [5] += snap->dy;
}

static void gridsnap_group (draw_objptr hdrptr, gridsnap_str *snap);

static despatch_tab gridsnaptab =
{ 0 /*fontlist*/,    gridsnap_text,       gridsnap_path,    0 /*rect*/,
  0 /*elli*/,        gridsnap_sprite,     gridsnap_group,   0 /*tagged*/,
  0 /*'8'*/,         gridsnap_textarea,   gridsnap_textcol, 0 /*option*/,
  gridsnap_trfmtext, gridsnap_trfmsprite, 0,                0,
  gridsnap_jpeg
};

static void gridsnap_group (draw_objptr hdrptr, gridsnap_str *snap)

{ BOOL saved_set = snap->set_offset;

  /*Save group header for undo and recurse*/
  if (snap->diag)
    draw_undo_put (snap->diag, (draw_undo_class) (draw_undo__object | draw_undoDIAG),
        (int) hdrptr.bytep, sizeof (draw_groustr));

  #if 0
    draw_scan_traverse (hdrptr.bytep, NULL, gridsnaptab, snap);
  #else
    set_offset (hdrptr, snap);
    snap->set_offset = FALSE; /*indicates offset is now set*/
    draw_scan_traverse (hdrptr.bytep, NULL, gridsnaptab, snap);
    snap->set_offset = saved_set; /*restores old offset flag*/
  #endif
}

void draw_trans_gridsnap_selection (viewrec *vuue)

{ gridsnap_str snap;
  diagrec      *diag = vuue->diag;

  snap.diag = diag;
  snap.vuue = vuue;

  visdelay_begin (); /*Fix MED-1994. J R C 17th Jan 1994*/

  #if 0
    draw_undo_put_start_mod (diag, -1);
  #else
    draw_undo_separate_major_edits (diag);
  #endif

  /*Snap each object*/
  snap.set_offset = TRUE;
  draw_scan_traverse_withredraw (NULL, NULL, diag, gridsnaptab, &snap,
      FALSE);

  visdelay_end (); /*Fix MED-1994. J R C 17th Jan 1994*/
}
