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
/* -> c.DrawObject
 *
 * Object handling for Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.12
 * History: 0.10 - 19 June 1989 - extracted from c.Draw 0.10 (16 June 1989)
 *          0.11 - 23 June 1989 - some code moved from c.DrawSelect
 *                                fixed bug 2002
 *                 26 June 1989 - drawArcs merged in
 *          0.12 - 18 July 1989 - undo added
 *
 */

#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <swis.h>
#include "Global/Countries.h"

#include "bbc.h"
#include "bezierarc.h"
#include "flex.h"
#include "font.h"
#include "msgs.h"
#include "os.h"
#include "sprite.h"
#include "werr.h"
#include "wimp.h"
#include "wimpt.h"
#include "drawmod.h"
#include "jpeg.h"
#include "dbox.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawAction.h"
#include "DrawDispl.h"
#include "DrawEnter.h"
#include "DrawObject.h"
#include "DrawSelect.h"
#include "DrawTextC.h"
#include "DrawTrans.h"
#include "DrawUndo.h"

/*------------------------------------------------------------------------*/
/*                   General object handling                              */
/*------------------------------------------------------------------------*/

/* Check/allocate space in a diagram */
os_error *draw_obj_checkspace(diagrec *diag, int needed)

{ int shortfall;

  ftracef2("draw_obj_checkspace: diag: 0x%X; needed: %d\n", diag, needed);
  needed += 32; /* 8 words extra for luck */
  shortfall = needed - (diag->misc->stacklimit - diag->misc->ghostlimit);
  ftracef3("... ask for %d bytes, there are %d bytes free, shortfall: %d\n",
        needed, diag->misc->stacklimit - diag->misc->ghostlimit, shortfall);

  if (shortfall > 0)
  { /* Claim extra needed plus a percentage of current size */
    shortfall += (diag->misc->bufferlimit*incfact_PAPERSIZE)/100;
    shortfall = shortfall + 3 & ~3; /* round up to a word */

    ftracef1("midextend by %d bytes\n",shortfall);

    if ( FLEX_MIDEXTEND ((flex_ptr) &diag->paper,
                         diag->misc->stacklimit, shortfall))
    { diag->misc->stacklimit += shortfall;
      diag->misc->bufferlimit += shortfall;
    }
    else
      return draw_make_oserror("DrawNR");
  }

  return 0;
}

/* Writes a fileheader at ghostlimit (normally =ghoststart)      */
/* should ONLY be used when converting files into Draw format    */
void draw_obj_fileheader(diagrec *diag)

{ draw_objptr hdrptr;                 /*    No limits updated */

  ftracef0 ("draw_obj_fileheader\n");
  hdrptr.bytep = diag->paper + diag->misc->ghostlimit;
  *hdrptr.filehdrp = draw_blank_header;

  diag->misc->ghostlimit += sizeof(draw_fileheader);
}

static int draw_currentalphabet; /*cached system alphabet*/

static draw_groupnametyp twelvespaces = { ' ',' ',' ',' ',
                                          ' ',' ',' ',' ',
                                          ' ',' ',' ',' ',};

void draw_obj_start(diagrec *diag, draw_tagtyp tag)

{ draw_objptr hdrptr;
  int hdr_off = diag->misc->ghostlimit;
  int junk;

  ftracef0 ("draw_obj_start\n");
  hdrptr.bytep = diag->paper + diag->misc->ghostlimit;
  hdrptr.objhdrp->tag = tag;

  diag->misc->stacklimit -= sizeof (int);

  *(int *) (diag->paper + diag->misc->stacklimit) =
                                             diag->misc->ghostlimit;

  ftracef2("draw_obj_start: pushing %d to offset %d\n",
      diag->misc->ghostlimit, diag->misc->stacklimit);

  switch (tag)
  { case draw_OBJFONTLIST:
      diag->misc->ghostlimit += sizeof(draw_fontliststrhdr);
    break;

    case draw_OBJTEXT:
      diag->misc->ghostlimit += sizeof(draw_textstrhdr) + sizeof (char);
      hdrptr.textp->text[0] = 0;   /* Null text string */
      draw_currentalphabet = 127;  /* Read alphabet */
      os_byte(71, &draw_currentalphabet, &junk);
    break;

    case draw_OBJPATH:
    { drawmod_pathelemptr pathptr;

      diag->misc->ghostlimit += sizeof(draw_pathstrhdr) +
                                sizeof(drawmod_path_termstr);

      hdrptr.pathp->pathstyle.i = 0;
      pathptr.bytep = (char *) &hdrptr.pathp->data;
      pathptr.end->tag = path_term;
    }
    break;

    case draw_OBJGROUP:
      diag->misc->ghostlimit += sizeof(draw_groustr);
      hdrptr.groupp->name = twelvespaces;
    break;

    case draw_OBJTEXTCOL:
      /* Allow for header part of text column */
      diag->misc->ghostlimit += sizeof(draw_textcolhdr);
    break;

    case draw_OBJTEXTAREA:
      diag->misc->ghostlimit += sizeof(draw_textareahdr);
    break;

    case draw_OBJTRFMTEXT:
      diag->misc->ghostlimit += sizeof (draw_trfmtextstrhdr) +
          sizeof (char);
      hdrptr.trfmtextp->text [0] = 0; /* Null text string */
    break;

    default: /*Not expected: draw_OBJSPRITE, draw_OBJTAGG etc.*/
      werr(1, msgs_lookup("DrawUO"));
    break;
  }

  ftracef3 ("draw_obj_start: setting size of 0x%X (offset %d) to %d\n",
    hdrptr.bytep, hdr_off, diag->misc->ghostlimit - hdr_off);
  hdrptr.objhdrp->size = diag->misc->ghostlimit - hdr_off;
}

/* Common code for finish and complete */
/* Does not put undo information */
static draw_objptr object_done(diagrec *diag, int *offset)

{ draw_objptr hdrptr;
  int hdroff = *(int *) (diag->paper + diag->misc->stacklimit);

  ftracef0 ("object_done\n");
  hdrptr.bytep = diag->paper + hdroff;

  ftracef4("pulled %d from offset %d solidlimit=%d ghoststart=%d\n",
         hdroff,diag->misc->stacklimit,diag->misc->solidlimit,
         diag->misc->ghoststart);

  diag->misc->stacklimit += sizeof(int);

  hdrptr.objhdrp->size = diag->misc->ghostlimit - hdroff;

  if (offset) *offset = hdroff;
  return hdrptr;
}


/* draw_obj_fin. Finish object but don't put any undo */
void draw_obj_fin(diagrec *diag)

{ int         hdroff;
  draw_objptr hdrptr = object_done(diag, &hdroff);

  ftracef0 ("draw_obj_fin\n");
  draw_obj_bound_object(hdrptr);

  /* If object complete ie this is not a nested object, add to data base */
  if (diag->misc->ghoststart == hdroff)
    draw_obj_appendghost(diag);
}

/* draw_obj_finish                                    */
/*                                                    */
/* Fill the size field, compute the BBox,             */
/* merge with solid image if ghost object is complete */
/* c.f. draw_object_complete                          */
void draw_obj_finish(diagrec *diag)

{ int hdroff;
  draw_objptr hdrptr = object_done(diag, &hdroff);

  ftracef0 ("draw_obj_finish\n");
  draw_obj_bound_object(hdrptr);

  /* If object complete ie this is not a nested object, add to data base */
  if (diag->misc->ghoststart == hdroff)
  { ftracef0 ("draw_obj_finish: calling draw_obj_appendghost\n");
    draw_obj_appendghost(diag);
  }

  /* Record that an object was inserted for undo */
  ftracef0 ("draw_obj_finish: calling draw_undo_separate_major_edits\n");
  draw_undo_separate_major_edits(diag);

  ftracef0 ("draw_obj_finish: calling draw_undo_put\n");
  draw_undo_put(diag, draw_undo__insert, hdroff, hdrptr.objhdrp->size);
}

/* Add to database (for copy/load/append, etc.) */
void draw_obj_appendghost(diagrec *diag)

{ ftracef0 ("draw_obj_appendghost\n");
  if (diag->misc->solidlimit != diag->misc->ghoststart)
  { int size = diag->misc->ghostlimit - diag->misc->ghoststart;

    draw_select_copydown(diag, diag->misc->ghoststart,
                               diag->misc->solidlimit, size);

    diag->misc->ghostlimit = diag->misc->solidlimit + size;
  }

  diag->misc->solidlimit = diag->misc->ghostlimit;
  diag->misc->ghoststart = diag->misc->ghostlimit;
}

/* Complete object. Don't bound or append it */
void draw_obj_complete(diagrec *diag)

{ ftracef0 ("draw_obj_complete\n");
  object_done(diag, NULL);
}

void draw_obj_flush(diagrec *diag)

{ ftracef0 ("draw_obj_flush\n");
  diag->misc->ghoststart = diag->misc->solidlimit;
  diag->misc->ghostlimit = diag->misc->solidlimit;
  diag->misc->stacklimit = diag->misc->bufferlimit;
}
#if 0 /*not used*/
/* Get offset for next object */
int draw_obj_next(diagrec *diag, int offset)

{ draw_objptr hdrptr;

  ftracef0 ("draw_obj_next\n");
  hdrptr.bytep = diag->paper + offset;
  return offset + hdrptr.objhdrp->size;
}
#endif
/*---------------------------------------------------------------------------*/
/*                     General box manipulation                              */
/*---------------------------------------------------------------------------*/

void draw_obj_unify(draw_bboxtyp *to, draw_bboxtyp *from)

{ ftracef0 ("draw_obj_unify\n");
  if (from->x0 < to->x0) to->x0 = from->x0;
  if (from->y0 < to->y0) to->y0 = from->y0;
  if (from->x1 > to->x1) to->x1 = from->x1;
  if (from->y1 > to->y1) to->y1 = from->y1;
}

/*---------------------------------------------------------------------------*/
/*                       Database manipulation                               */
/*---------------------------------------------------------------------------*/

/* Create an empty space in the middle of a diagram, ready for insert */
os_error *draw_obj_makespace(diagrec *diag, int atoff, int size)

{ os_error *err = draw_obj_checkspace(diag, size);

  ftracef0 ("draw_obj_makespace\n");
  if (!err)
  { /* Copy data in the diagram */
    draw_select_copyup(diag, atoff, atoff + size,
                       diag->misc->ghostlimit - atoff);

    /* Update limit pointers */
    /* These tests used to be strictly less than, but I think this is wrong */
    if (atoff <= diag->misc->solidlimit) diag->misc->solidlimit += size;
    if (atoff <= diag->misc->ghoststart) diag->misc->ghoststart += size;
    diag->misc->ghostlimit += size;
  }

  return err;
}

os_error *draw_obj_insert(diagrec *diag, int atoff, int size)

{ int       i;
  os_error  *err = draw_obj_makespace(diag, atoff, size);

  ftracef0 ("draw_obj_insert\n");
  if (err) return(err);

  /* update the size fields of the stacked objects */
  for (i = diag->misc->stacklimit; i < diag->misc->bufferlimit; i+=sizeof(int))
  { draw_objptr hdrptr;

    int hdroff = *(int*)(diag->paper + i);
    hdrptr.bytep = diag->paper + hdroff;
    hdrptr.pathp->size += size;
  }

  return(0);
}

/* Get rid of some space from the middle of a diagram */
void draw_obj_losespace(diagrec *diag, int atoff, int size)

{ ftracef0 ("draw_obj_losespace\n");
  draw_select_copydown(diag, atoff+size, atoff,
                       diag->misc->ghostlimit-atoff-size);

  /* update ghostlimit and ghoststart (maybe) and solidlimit (maybe) */
  /* These tests used to be strictly less than, but I think this is wrong */
  /*Well, I don't. JRC 25th Nov 1994*/
  if (atoff < diag->misc->solidlimit) diag->misc->solidlimit -= size;
  if (atoff < diag->misc->ghoststart) diag->misc->ghoststart -= size;
  diag->misc->ghostlimit -= size;
}

void draw_obj_delete(diagrec *diag, int atoff, int size)

{ int i;

  ftracef0 ("draw_obj_delete\n");
  draw_obj_losespace(diag, atoff, size);

  /* update the size fields of the stacked objects */
  for (i = diag->misc->stacklimit; i < diag->misc->bufferlimit; i+=sizeof(int))
  { draw_objptr hdrptr;
    int hdroff = *(int*)(diag->paper + i);

    hdrptr.bytep = diag->paper + hdroff;
    hdrptr.pathp->size -= size;
  }
}

void draw_obj_delete_object(diagrec *diag)

{ draw_objptr hdrptr;
  int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);

  ftracef0 ("draw_obj_delete_object\n");
  diag->misc->stacklimit += sizeof(int);  /* pop object off stack */

  hdrptr.bytep = diag->paper + hdroff;

  /* ditch object, update enclosing groups */
  draw_obj_delete(diag, hdroff, hdrptr.objhdrp->size);
}

/* This is used for text columns. The new object is copied in over the old
  object, and deleted from the ghost area. This retains the select state.
  The selection for objects further down the data base must also be checked,
  since their offset will change. We need not worry about the old object
  being part of a group or tagg structure, since in that case, we could
  never have found it when checking what we were over. */
void draw_obj_deleteObject(diagrec *diag, int oldOffset, int newOffset)

{ draw_objptr hdrptr;      /* General header pointer */
  int oldSize, newSize, sizeChange, oldEnd, s;

  ftracef0 ("draw_obj_deleteObject\n");
  hdrptr.bytep = diag->paper + newOffset;
  newSize      = hdrptr.objhdrp->size;
  hdrptr.bytep = diag->paper + oldOffset;
  oldSize      = hdrptr.objhdrp->size;
  sizeChange   = newSize - oldSize;
  oldEnd       = oldSize + oldOffset;

  /* Save conceptual deletion of object no redraw. Also save selection */
  draw_select_put_array(diag, FALSE);
  draw_undo_put(diag, draw_undo__delete, oldOffset, oldSize);

  /* Make sure we have enough temporary space */
  if (wimpt_complain(draw_obj_checkspace(diag, sizeChange)))
    return; /* Give up */

  /* Copy the rest of the database down or up */
  if (sizeChange > 0)
    draw_select_copyup (diag, oldEnd, oldEnd + sizeChange,
        diag->misc->ghostlimit - oldEnd);
  else if (sizeChange < 0)
    draw_select_copydown(diag, oldEnd, oldEnd + sizeChange,
        diag->misc->ghostlimit - oldEnd);

  /* Copy in the new object */
  newOffset += sizeChange;
  draw_select_copydown (diag, newOffset, oldOffset, newSize);

  /* Adjust selection */
  if (draw_select_owns(diag))
    for (s = 0; s < draw_selection->indx; s++)
      if (draw_selection->array[s] >= oldEnd)
        draw_selection->array[s] += sizeChange;

  /* Adjust limits to reflect size change, and to delete the new object */
  diag->misc->solidlimit += sizeChange;
  diag->misc->ghoststart += sizeChange;
  diag->misc->ghostlimit += sizeChange - newSize;

  /* For undo, mark conceptual insertion of object with redraw */
  draw_undo_put(diag, draw_undo__insert, oldOffset, newSize);
}

/*---------------------------------------------------------------------------*/
/*                         Path manipulation                                 */
/*---------------------------------------------------------------------------*/

static int insert_pathele (diagrec *diag, int size)

{ os_error *error;
  int hdroff, atoff;
  draw_objptr hdrptr;
  drawmod_pathelemptr pathptr;

  ftracef2 ("insert_pathele: diag: 0x%X; size: %d\n", diag, size);

  hdroff = *(int *) (diag->paper + diag->misc->stacklimit);
  hdrptr.bytep = diag->paper + hdroff;
  ftracef4 ("insert_pathele: building atoff - "
      "hdroff: %d; hdrptr: 0x%X; hdrptr.pathp->size: %d; sizeof (drawmod_path_termstr): %d\n",
      hdroff, hdrptr.bytep, hdrptr.pathp->size, sizeof (drawmod_path_termstr));
  atoff = hdroff + hdrptr.pathp->size - sizeof (drawmod_path_termstr);

  #if 1 /*Code exists - why not call it? JRC*/
    if ((error = draw_obj_insert (diag, atoff, size)) != NULL)
    { werr (TRUE, error->errmess);
      return 0;
    }

    ftracef4 ("insert_pathele: building pathptr - "
        "diag: 0x%X; diag->paper: 0x%X; atoff: %d; size: %d\n",
        diag, diag->paper, atoff, size);

    pathptr.bytep = diag->paper + atoff + size;
    pathptr.end->tag = path_term;
  #else
    draw_select_copyup(diag, atoff, atoff + size,
                       diag->misc->ghostlimit - atoff);

    /* Update ghostlimit and ghoststart (maybe) and solidlimit (maybe) */
    if (atoff </*=JRC*/ diag->misc->solidlimit) diag->misc->solidlimit += size;
    if (atoff </*=JRC*/ diag->misc->ghoststart) diag->misc->ghoststart += size;
    diag->misc->ghostlimit += size;

    /* Update the size fields of the stacked objects */
    for (i = diag->misc->stacklimit; i < diag->misc->bufferlimit; i += sizeof (int))
    { hdroff = *(int *) (diag->paper + i);
      hdrptr.bytep = diag->paper + hdroff;
      hdrptr.pathp->size += size;
    }
  #endif

  return atoff;
}

void draw_obj_addpath_move(diagrec *diag, draw_objcoord *pt)

{ drawmod_pathelemptr pathptr;

  ftracef0 ("draw_obj_addpath_move\n");
  pathptr.bytep = diag->paper + insert_pathele(diag,
                                sizeof(drawmod_path_movestr));
  pathptr.move2->tag = path_move_2;
  pathptr.move2->x   = pt->x;
  pathptr.move2->y   = pt->y;
}

void draw_obj_addpath_line(diagrec *diag, draw_objcoord *pt)

{ drawmod_pathelemptr pathptr;

  ftracef0 ("draw_obj_addpath_line\n");
  pathptr.bytep     = diag->paper + insert_pathele(diag,
                                    sizeof(drawmod_path_linetostr));
  pathptr.lineto->tag = path_lineto;
  pathptr.lineto->x   = pt->x;
  pathptr.lineto->y   = pt->y;
}

void draw_obj_addpath_curve(diagrec *diag, draw_objcoord *pt1,
                                           draw_objcoord *pt2,
                                           draw_objcoord *pt3)

{ drawmod_pathelemptr pathptr;

  ftracef0 ("draw_obj_addpath_curve\n");
  pathptr.bytep      = diag->paper + insert_pathele(diag,
                                     sizeof(drawmod_path_bezierstr));
  pathptr.bezier->tag = path_bezier;
  pathptr.bezier->x1  = pt1->x; pathptr.bezier->y1 = pt1->y;
  pathptr.bezier->x2  = pt2->x; pathptr.bezier->y2 = pt2->y;
  pathptr.bezier->x3  = pt3->x; pathptr.bezier->y3 = pt3->y;
}

void draw_obj_addpath_close(diagrec *diag)

{ drawmod_pathelemptr pathptr;

  ftracef0 ("draw_obj_addpath_close\n");
  pathptr.bytep         = diag->paper + insert_pathele(diag,
                                        sizeof(drawmod_path_closelinestr));
  pathptr.closeline->tag = path_closeline;
}

void draw_obj_addpath_term(diagrec *diag)

{ drawmod_pathelemptr pathptr;

  ftracef0 ("draw_obj_addpath_term\n");
  pathptr.bytep    = diag->paper + diag->misc->ghostlimit;
}

#if (0)
/* Not used anywhere */
void draw_obj_addcoord(diagrec *diag, coord x, coord y)

{ draw_objptr coordptr;

  ftracef0 ("draw_obj_addcoord\n");
  coordptr.bytep = diag->paper + diag->misc->ghostlimit;
  coordptr.coordp->x = x; coordptr.coordp->y = y;
  diag->misc->ghostlimit += sizeof(draw_objcoord);
}
#endif

/* Return the address of the first path element in a path object */
/* this starts either after the path header (no dash pattern)    */
/* or after the dash pattern                                     */

drawmod_pathelemptr draw_obj_pathstart(draw_objptr hdrptr)

{ drawmod_pathelemptr pathptr;

  ftracef0 ("draw_obj_pathstart\n");
  if (hdrptr.pathp->pathstyle.s.dashed)
    pathptr.wordp =
        &hdrptr.pathp->data.elements [hdrptr.pathp->data.dash.dashcount];
  else
    pathptr.bytep = (char *) &hdrptr.pathp->data;

  return pathptr;
}

/* Return the address of the dash pattern of a path object, or zero */
draw_dashstr *draw_obj_dashstart(draw_objptr hdrptr)

{ ftracef0 ("draw_obj_dashstart\n");
  return (hdrptr.pathp->pathstyle.s.dashed) ? &hdrptr.pathp->data : 0;
}

/*---------------------------------------------------------------------------*/
/*                         Text manipulation                                 */
/*---------------------------------------------------------------------------*/


void draw_obj_addstring(diagrec *diag, char *from)

{ draw_objptr hdrptr;
  int hdroff = *(int *) (diag->paper + diag->misc->stacklimit);

  ftracef0 ("draw_obj_addstring\n");
  hdrptr.bytep = diag->paper + hdroff;

  { char *to = &hdrptr.textp->text [0];

    /*Copy string, terminate on ctrl char with a null*/
    while ((*to++ = *from++) >= ' ');
    *(to-1) = '\0';

    /*Pad with nulls to a word boundary*/
    while ((int) to & 3) *to++ = '\0';

    diag->misc->ghostlimit = to - diag->paper;
  }
}

void draw_obj_addtext_char(diagrec *diag, char ch)

{ char *to = diag->paper + diag->misc->ghostlimit;

  ftracef0 ("draw_obj_addtext_char\n");
  *to   = '\0';
  *--to = ch;                                /* Terminated to keep  */
  diag->misc->ghostlimit += sizeof(char);    /* font manager happy */
}

int draw_obj_findtext_len(diagrec *diag)    /* Count chars incase string is */
{                                           /*  padded to word boundary     */
  int hdroff = *(int *) (diag->paper + diag->misc->stacklimit);
  draw_objptr hdrptr;
  char *charp;
  int count;

  ftracef0 ("draw_obj_findtext_len\n");
  hdrptr.bytep = diag->paper + hdroff;
  charp = &hdrptr.textp->text[0];

  for (count = 0; *charp++ != 0; count++);

  return(count);
}

void draw_obj_deltext_char(diagrec *diag) /* Assumes at least 1 char present */
{ char *to = diag->paper + diag->misc->ghostlimit;
  int   bytes;

  ftracef0 ("draw_obj_deltext_char\n");
  if (draw_currentalphabet == ISOAlphabet_UTF8)
  { to -= 2; /* Byte before the null */
    bytes = 1;
    while ((*to & 0xC0) == 0x80) /* Skip continuation marks */
    { bytes++;
      to--;
    }
    *to = '\0'; /* Knock out with a null */ 
  }
  else
  { *(to-2) = '\0'; /* Knock out with a null */
    bytes = 1; /* Not UTF-8, so 1 character = 1 byte */
  }
  diag->misc->ghostlimit -= (bytes * sizeof (char));
}

void draw_obj_addtext_term(diagrec *diag)    /* text has 1 null terminator*/

{ int  lim = diag->misc->ghostlimit; /* but may need padding to a  */
  char *to = diag->paper + lim;         /*  word boundary */

  ftracef0 ("draw_obj_addtext_term\n");
  while ((lim & 3) != 0) {*to++ = '\0'; lim++;}

  diag->misc->ghostlimit = lim;
}

/*------------------------------------------------------------------------*/
/*                      Object attributes                                 */
/*------------------------------------------------------------------------*/

#if (0)
/* No-one uses this */
void draw_obj_setbbox(diagrec *diag, int x0, int y0, int x1, int y1)

{ draw_objptr hdrptr;
  int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);

  ftracef0 ("draw_obj_setbbox\n");
  hdrptr.bytep = diag->paper + hdroff;

  hdrptr.objhdrp->bbox.x0 = x0;
  hdrptr.objhdrp->bbox.y0 = y0;
  hdrptr.objhdrp->bbox.x1 = x1;
  hdrptr.objhdrp->bbox.y1 = y1;
}
#endif

#if (0)
/* No-one uses this either */
void draw_obj_readbbox(diagrec *diag, draw_bboxtyp *blk)

{ draw_objptr hdrptr;
  int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);

  ftracef0 ("draw_obj_readbbox\n");
  hdrptr.bytep = (diag->paper + hdroff);

  *blk = hdrptr.objhdrp->bbox;
}
#endif

void draw_obj_setpath_colours(diagrec *diag, draw_coltyp    fillcolour,
                                             draw_coltyp    linecolour,
                                             draw_pathwidth linewidth)

{ int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);
  draw_objptr hdrptr;

  ftracef0 ("draw_obj_setpath_colours\n");
  hdrptr.bytep = (diag->paper + hdroff);

  hdrptr.pathp->fillcolour = fillcolour;
  hdrptr.pathp->pathcolour = linecolour;
  hdrptr.pathp->pathwidth  = linewidth;
}

/* N.B. this clears the line dashed bit, it is expected that any     */
/*      dash pattern is added, and the dashed bit set AFTER all      */
/*      path elements have been added, and after the colours & style */
/*      have been set                                                */

void draw_obj_setpath_style(diagrec *diag, draw_jointyp join,
                                           draw_captyp  startcap,
                                           draw_captyp  endcap,
                                           draw_windtyp windrule,
                                           int          tricapwid,
                                           int          tricaphei)

{ draw_objptr hdrptr;
  int         hdroff = *(int *) (diag->paper + diag->misc->stacklimit);

  ftracef0 ("draw_obj_setpath_style\n");
  hdrptr.bytep = diag->paper + hdroff;

  #if TRACE
    ftracef (__FILE__, __LINE__,
      "draw_obj_setpath_style: size: %d; join: %d; startcap: %d; endcap: %d; "
      "windrule: %d\n", hdrptr.objhdrp->size, join, startcap, endcap, windrule);
  #endif

  /* Pack up path style - also clears the dashed bit */
  hdrptr.pathp->pathstyle.p.style     = pathpack (join, endcap, startcap, windrule);
  hdrptr.pathp->pathstyle.p.reserved8 = 0;
  hdrptr.pathp->pathstyle.p.tricapwid = tricapwid;
  hdrptr.pathp->pathstyle.p.tricaphei = tricaphei;
}

/* Assumes path does not have a dash pattern, and inserts pattern-> */
/* after header and before first path element                       */
/* N.B. assumes pattern IS NOT IN A FLEX BLOCK as heap may shift    */
/*      whilst making space for pattern                             */
os_error *draw_obj_setpath_dashpattern(diagrec *diag, draw_dashstr *pattern)

{ int  hdroff = *(int*)(diag->paper + diag->misc->stacklimit);
  int  at_off = hdroff + sizeof(draw_pathstrhdr);
  int  size   = sizeof(drawmod_dashhdr)
                + sizeof(int)*pattern->dash.dashcount;
  draw_objptr hdrptr;
  os_error    *err;

  ftracef0 ("draw_obj_setpath_dashpattern\n");
  if (err = draw_obj_insert(diag, at_off,size), err == 0)
  { hdrptr.bytep = diag->paper + hdroff;
    hdrptr.pathp->pathstyle.s.dashed = 1;

    /* Copy pattern */
    memcpy((char*)&hdrptr.pathp->data, (char*)pattern, size);
  }

  return err;
}

void draw_obj_settext_colour(diagrec *diag, draw_coltyp textcolour,
                                            draw_coltyp background)

{ int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);
  draw_objptr hdrptr;

  ftracef0 ("draw_obj_settext_colour\n");
  hdrptr.bytep = (diag->paper + hdroff);

  hdrptr.textp->textcolour = textcolour;
  hdrptr.textp->background = background;
}

void draw_obj_settext_font(diagrec *diag, int fref, int fsizex, int fsizey)

{ int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);
  draw_objptr hdrptr;

  ftracef0 ("draw_obj_settext_font\n");
  hdrptr.bytep = (diag->paper + hdroff);
  hdrptr.textp->textstyle.fontref    = fref;   /* 8 bit font ref     */
  hdrptr.textp->textstyle.reserved8  = 0;      /* } 24 reserved bits */
  hdrptr.textp->textstyle.reserved16 = 0;      /* }                  */

  hdrptr.textp->fsizex = fsizex;
  hdrptr.textp->fsizey = fsizey;
}

void draw_obj_setcoord(diagrec *diag, draw_objcoord *pt)

{ int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);
  draw_objptr hdrptr;

  ftracef0 ("draw_obj_setcoord\n");
  hdrptr.bytep = (diag->paper + hdroff);

  hdrptr.textp->coord = *pt;
}

void draw_obj_readcoord(diagrec *diag, draw_objcoord *blk)

{ draw_objptr hdrptr;
  int hdroff = *(int*)(diag->paper + diag->misc->stacklimit);

  ftracef0 ("draw_obj_readcoord\n");
  hdrptr.bytep = (diag->paper + hdroff);

  blk->x = hdrptr.textp->coord.x;
  blk->y = hdrptr.textp->coord.y;
}

void draw_obj_addfontentry(diagrec *diag, int ref, char *name)

{ char *to;

  ftracef0 ("draw_obj_addfontentry\n");
  to    = diag->paper + diag->misc->ghostlimit;
  *to++ = ref;


  while ((*to++ = *name++) >= ' ');   /* Copy string, terminate on */
  *(to-1) = '\0';                      /* ctrl char, with a null    */
  diag->misc->ghostlimit = to-diag->paper;
}

/*------------------------------------------------------------------------*/
/*                  Bounding box calculation                              */
/*------------------------------------------------------------------------*/


void draw_obj_bound_minmax(int x, int y, draw_bboxtyp *boundp)

{ ftracef0 ("draw_obj_bound_minmax\n");
  if (x < boundp->x0) boundp->x0 = x;
  if (x > boundp->x1) boundp->x1 = x;
  if (y < boundp->y0) boundp->y0 = y;
  if (y > boundp->y1) boundp->y1 = y;
}

/* Call minmax on each limit in turn */
void draw_obj_bound_minmax2(draw_objptr hdrptr, draw_bboxtyp *boundp)

{ draw_bboxtyp *bbox = draw_displ_bbox (hdrptr);
  ftracef0 ("draw_obj_bound_minmax2\n");
  draw_obj_bound_minmax(bbox->x0, bbox->y0, boundp);
  draw_obj_bound_minmax(bbox->x1, bbox->y1, boundp);
}

/* Local implementation of oddly missing function from RISC_OSLib */
static os_error *font_scanstring(const char *text, int options, font fonth,
                                 const drawmod_transmat *matrix, draw_bboxtyp *bbox)
{ os_error *error;
  os_regset reg_set;
  struct {struct {int x, y;} space_offset; struct {int x, y;} char_offset;
          int split_char; draw_bboxtyp bbox;} block;

  options |= 1 << 5 /*R5 -> coordinate block*/ |
             1 << 8 /*R0 = initial font handle*/ |
             1 << 18 /*return bbox*/;
  if (matrix != NULL)
  { options |= 1 << 6 /*R6 -> trfm*/;
    reg_set.r [6] = (int) matrix;
  }
  reg_set.r [0] = fonth;
  reg_set.r [1] = (int) text;
  reg_set.r [2] = options;
  reg_set.r [3] = INT_MAX;
  reg_set.r [4] = INT_MAX;
  reg_set.r [5] = (int) memset (&block, 0, sizeof block);
  error = os_swix (Font_ScanString, &reg_set);

  *bbox = block.bbox;
  
  return error;
}
 
/* Code to find the bbox for just the current text object. FALSE on error */
BOOL draw_obj_findTextBox(draw_objptr hdrptr, draw_bboxtyp *bbox)

{ BOOL ok = TRUE;
  font fonth;
  const char *text;

  ftracef0 ("draw_obj_findTextBox\n");
  text = &hdrptr.textp->text [0];

  if (hdrptr.textp->textstyle.fontref)
  { /* Find the font */
    /* fsizex & fsizey are in 1/640ths point, current font managers */
    /* take 1/16ths point, so scale by 1/40 (ie 16/640)             */

    ok = font_find (draw_fontcat.name[hdrptr.textp->textstyle.fontref],
                    MAXZOOMFACTOR*hdrptr.textp->fsizex/40,
                    MAXZOOMFACTOR*hdrptr.textp->fsizey/40,
                    0,0, &fonth) == NULL;
    if (ok)
    { ok = font_scanstring (text, 0, fonth, NULL, bbox) == NULL;
      font_lose (fonth);

      if (ok)
      { /* Calculate actual bbox in Draw units from millipoints */
        bbox->x0 = (bbox->x0 << 8)/(400*MAXZOOMFACTOR) + hdrptr.textp->coord.x;
        bbox->x1 = (bbox->x1 << 8)/(400*MAXZOOMFACTOR) + hdrptr.textp->coord.x;
        bbox->y0 = (bbox->y0 << 8)/(400*MAXZOOMFACTOR) + hdrptr.textp->coord.y;
        bbox->y1 = (bbox->y1 << 8)/(400*MAXZOOMFACTOR) + hdrptr.textp->coord.y;

        return(TRUE);
      }
    }
  }

/*Either text is in system font, OR an unfound fancy font (so rendered in */
/*system font) or some font manager call went bang, so..                  */
/*Return BBox for system font.                                            */
  bbox->x0 = hdrptr.textp->coord.x;
  bbox->x1 = hdrptr.textp->coord.x +
             hdrptr.textp->fsizex*strlen(hdrptr.textp->text);

  /* Assume char base line is row 7 (of 8) */
  bbox->y1 = hdrptr.textp->coord.y + (7*hdrptr.textp->fsizey)/8;
  bbox->y0 = bbox->y1 - hdrptr.textp->fsizey;
  return ok;
}

static void bound_text(draw_objptr hdrptr)

{ ftracef0 ("bound_text\n");
  draw_obj_findTextBox(hdrptr, &hdrptr.textp->bbox);
}

/*Bounding box calculated at maximum zoom factor to ensure all
  pixels lie within it*/
static drawmod_transmat MaxZoomMatrix = { MAXZOOMFACTOR*65536, 0,
                                         0, MAXZOOMFACTOR*65536,
                                         0, 0};

#define NEWPATHBBOX   (1)

/* Macro to ease rounding */
#define RoundUp(i) (int)((double) (i)/MAXZOOMFACTOR + 0.5)

static os_error *bound_path (draw_objptr hdrptr)

{
  #if NEWPATHBBOX
                                           /*was PFlatten JRC 29 Jan 1990*/
    #define FillStyle ((drawmod_filltype) (fill_PFlatten | fill_PThicken | fill_PReflatten | \
                     fill_FBint | fill_FNonbint | fill_FBext))
    drawmod_line        linestyle;
    drawmod_options     options;
    drawmod_pathelemptr pathptr = draw_obj_pathstart(hdrptr);
    os_error *error;

    ftracef0 ("bound_path\n");
    /* Set up line style */
    linestyle.flatness     = 200/MAXZOOMFACTOR;
    linestyle.thickness    = hdrptr.pathp->pathwidth;
    linestyle.dash_pattern = (drawmod_dashhdr *)draw_obj_dashstart(hdrptr);
    draw_displ_unpackpathstyle(hdrptr, &linestyle.spec);

    /* Set up options to get box */
    options.tag      = tag_box;
    options.data.box = (drawmod_box *)&hdrptr.pathp->bbox;

    if ((error = drawmod_processpath (pathptr, FillStyle, &MaxZoomMatrix,
        &linestyle, &options, NULL)) != NULL)
      return error;

    /* Bounding box for path at maximum magnification, so scale down */
    hdrptr.pathp->bbox.x0 = RoundUp(hdrptr.pathp->bbox.x0);
    hdrptr.pathp->bbox.y0 = RoundUp(hdrptr.pathp->bbox.y0);
    hdrptr.pathp->bbox.x1 = RoundUp(hdrptr.pathp->bbox.x1);
    hdrptr.pathp->bbox.y1 = RoundUp(hdrptr.pathp->bbox.y1);

    /*Zero length paths produce a funny BBox, so merge MoveTo(x,y) into
      BBox*/
    draw_obj_bound_minmax (pathptr.move2->x, pathptr.move2->y,
        &hdrptr.pathp->bbox);

    return NULL;
  #else
    path_eleptr pathptr;
    draw_bboxtyp bound = draw_big_box;

    ftracef0 ("bound_path\n");
    /* scan the coordinates in the path to find the bounding box        */
    pathptr.move = draw_obj_pathstart(hdrptr); /*&hdrptr.pathp->path;*/

    while (pathptr.move->tag != Draw_PathTERM)
      switch (pathptr.move->tag)
      { case Draw_PathMOVE:
        case Draw_PathLINE:
          draw_obj_bound_minmax(pathptr.move->x,pathptr.move->y, &bound);
          pathptr.move++;
        break;

        case Draw_PathCURVE:
          draw_obj_bound_minmax(pathptr.curve->x1,pathptr.curve->y1, &bound);
          draw_obj_bound_minmax(pathptr.curve->x2,pathptr.curve->y2, &bound);
          draw_obj_bound_minmax(pathptr.curve->x3,pathptr.curve->y3, &bound);
          pathptr.curve++;
        break;

        case Draw_PathCLOSE:
          pathptr.close++;
        break;
      }

      hdrptr.pathp->bbox = bound;

  #endif

#if (0 /*TRACE*/)
if (hdrptr.pathp->bbox.x0 > hdrptr.pathp->bbox.x1 ||
    hdrptr.pathp->bbox.y0 > hdrptr.pathp->bbox.y1)
  { path_eleptr pathptr;

    ftracef0("NAFF PATH BBOX\n");

    ftracef4("path BBox is (%d,%d,%d,%d)\n", hdrptr.pathp->bbox.x0,
                                             hdrptr.pathp->bbox.y0,
                                             hdrptr.pathp->bbox.x1,
                                             hdrptr.pathp->bbox.y1);

    pathptr.move = draw_obj_pathstart(hdrptr);

    ftracef0("{");

    while (pathptr.move->tag != Draw_PathTERM)
      switch (pathptr.move->tag)
      { case Draw_PathMOVE:
          ftracef2("  Move(%d,%d) ",pathptr.move->x,pathptr.move->y);
          pathptr.move++;
        break;

        case Draw_PathLINE:
          ftracef2("  Line(%d,%d) ",pathptr.line->x,pathptr.line->y);
          pathptr.line++;
        break;

        case Draw_PathCURVE:
          ftracef2("  Curve(%d,%d, ", pathptr.curve->x1,pathptr.curve->y1);
          ftracef4("%d,%d, %d,%d)",pathptr.curve->x2,pathptr.curve->y2,
                                   pathptr.curve->x3,pathptr.curve->y3);
          pathptr.curve++;
        break;

        case Draw_PathCLOSE:
          ftracef0("  Close");
          pathptr.close++;
        break;
      }
    ftracef0("  Term}\n");
  }
#endif
}

static void transform_coord (draw_objcoord *p, drawmod_transmat m)
  /*Apply the given trfm to the point, in place.*/

{ draw_objcoord r;

  r.x = (int) ((double) m [0]*(double) p->x/65536.0 +
      (double) m [2]*(double) p->y/65536.0 +
      (double) m [4]);
  r.y = (int) ((double) m [1]*(double) p->x/65536.0 +
      (double) m [3]*(double) p->y/65536.0 +
      (double) m [5]);

  *p = r;
}

/*Code to bound a rotated piece of system text*/
static BOOL find_trfmtext_system_bbox (draw_objptr hdrptr,
    draw_bboxtyp *bbox)

{ draw_objcoord c;
  int len = strlen (hdrptr.trfmtextp->text);
  drawmod_transmat trans_mat;

  memcpy (trans_mat, hdrptr.trfmtextp->trfm, sizeof trans_mat);
  trans_mat [4] += hdrptr.trfmtextp->coord.x;
  trans_mat [5] += hdrptr.trfmtextp->coord.y - hdrptr.trfmtextp->fsizey/8;
  *bbox = draw_big_box;

  ftracef0 ("find_trfmtext_system_bbox\n");
  c.x = 0, c.y = -hdrptr.trfmtextp->fsizey/8;
  transform_coord (&c, trans_mat);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", 0, 0, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, bbox);

  c.x = len*hdrptr.trfmtextp->fsizex, c.y = -hdrptr.trfmtextp->fsizey/8;
  transform_coord (&c, trans_mat);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", 1, 0, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, bbox);

  c.x = len*hdrptr.trfmtextp->fsizex, c.y = 7*hdrptr.trfmtextp->fsizey/8;
  transform_coord (&c, trans_mat);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", 1, 1, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, bbox);

  c.x = 0, c.y = 7*hdrptr.trfmtextp->fsizey/8;
  transform_coord (&c, trans_mat);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", 0, 1, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, bbox);

  ftracef4 ("trfmtext_system BBox is (%d, %d, %d, %d)\n",
      hdrptr.trfmtextp->bbox.x0,
      hdrptr.trfmtextp->bbox.y0,
      hdrptr.trfmtextp->bbox.x1,
      hdrptr.trfmtextp->bbox.y1);

  return TRUE;
}

/*Code to find the bbox for just the current text object. FALSE on error.*/
static BOOL find_trfmtext_bbox (draw_objptr hdrptr, draw_bboxtyp *bbox)

{ os_error *error;
  font h;
  int  options;
  size_t i;
  const char *text;
  draw_bboxtyp bounds;

  ftracef0 ("find_trfmtext_bbox\n");
  text = &hdrptr.trfmtextp->text [0];

  if (hdrptr.trfmtextp->textstyle.fontref == 0)
    return find_trfmtext_system_bbox (hdrptr, bbox);
  else
  { /*Find the untransformed font.*/
    error = font_find (draw_fontcat.name [hdrptr.trfmtextp->textstyle.fontref],
                       MAXZOOMFACTOR*hdrptr.trfmtextp->fsizex/40,
                       MAXZOOMFACTOR*hdrptr.trfmtextp->fsizey/40,
                       0, 0, &h);
    if (error != NULL) return FALSE;
    options = (hdrptr.trfmtextp->flags.kerned ? font_KERN : 0) |
              (hdrptr.trfmtextp->flags.direction ? font_RTOL : 0);  
    error = font_scanstring (text, options, h, &hdrptr.trfmtextp->trfm, &bounds);
    if (error != NULL)
    { /*On error, try again without the trfm matrix. We don't
        actually have any right at all to assume that Font_ScanString goes
        wrong in the same ways and for the same reasons as Font_Paint, but
        we don't have much choice.*/
      ftracef1 ("find_trfmtext_bbox: *ERROR* \"%s\"\n", error->errmess);
      error = font_scanstring (text, options, h, NULL, &bounds);
    }

    font_lose (h);

    if (error != NULL)
    { ftracef1 ("find_trfmtext_bbox: *ERROR* \"%s\"\n", error->errmess);
      return FALSE;
    }

    ftracef4 ("find_trfmtext_bbox: font manager gives bbox of "
        "(%d, %d, %d, %d)\n", bounds.x0, bounds.y0,
        bounds.x1, bounds.y1);

    for (i = 0; i < 4; i++)
    { /*Convert from millipoints to transformed Draw units*/
       (&bbox->x0) [i] = ((&bounds.x0) [i] << 8)/(400*MAXZOOMFACTOR);
       (&bbox->x0) [i] +=
         !(i & 1)? hdrptr.trfmtextp->coord.x: hdrptr.trfmtextp->coord.y;
    }

    return TRUE;
  }
}

static void bound_trfmtext (draw_objptr hdrptr)
  /*We know the matrix is rotate (theta).shear (phi) for some theta, phi,
    but this doesn't help particularly.*/

{ ftracef0 ("bound_trfmtext\n");
  find_trfmtext_bbox (hdrptr, &hdrptr.textp->bbox);
}

static void bound_trfmsprite (draw_objptr hdrptr)

{ sprite_id id;
  sprite_info info;
  draw_objcoord c;
  int height, width, mode;

  hdrptr.trfmspritep->bbox = draw_big_box;

  id.tag = sprite_id_addr;
  id.s.addr = &hdrptr.trfmspritep->sprite;
  sprite_readsize (UNUSED_SA, &id, &info);

  /*Convert to Draw units*/
  mode = hdrptr.trfmspritep->sprite.mode;
  width  = info.width  << bbc_modevar (mode, bbc_XEigFactor) + 8;
  height = info.height << bbc_modevar (mode, bbc_YEigFactor) + 8;
  ftracef4 ("width %d OSU = %d DU, height %d OSU = %d DU\n",
      info.width  << bbc_modevar (mode, bbc_XEigFactor), width,
      info.height << bbc_modevar (mode, bbc_YEigFactor), height);

  ftracef0 ("bound_trfmsprite\n");
  c.x = c.y = 0;
  transform_coord (&c, hdrptr.trfmspritep->trfm);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", 0, 0, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, &hdrptr.trfmspritep->bbox);

  c.x = width, c.y = 0;
  transform_coord (&c, hdrptr.trfmspritep->trfm);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", width, 0, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, &hdrptr.trfmspritep->bbox);

  c.x = width, c.y = height;
  transform_coord (&c, hdrptr.trfmspritep->trfm);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", width, height, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, &hdrptr.trfmspritep->bbox);

  c.x = 0, c.y = height;
  transform_coord (&c, hdrptr.trfmspritep->trfm);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", 0, height, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, &hdrptr.trfmspritep->bbox);

  ftracef4 ("trfmsprite BBox is (%d, %d, %d, %d)\n",
      hdrptr.trfmspritep->bbox.x0,
      hdrptr.trfmspritep->bbox.y0,
      hdrptr.trfmspritep->bbox.x1,
      hdrptr.trfmspritep->bbox.y1);
}

static void bound_jpeg (draw_objptr hdrptr)

{ draw_objcoord c;

  hdrptr.jpegp->bbox = draw_big_box;

  ftracef0 ("bound_jpeg\n");
  c.x = c.y = 0;
  transform_coord (&c, hdrptr.jpegp->trans_mat);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", 0, 0, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, &hdrptr.jpegp->bbox);

  c.x = hdrptr.jpegp->width, c.y = 0;
  transform_coord (&c, hdrptr.jpegp->trans_mat);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", hdrptr.jpegp->width, 0, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, &hdrptr.jpegp->bbox);

  c.x = hdrptr.jpegp->width, c.y = hdrptr.jpegp->height;
  transform_coord (&c, hdrptr.jpegp->trans_mat);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", hdrptr.jpegp->width, hdrptr.jpegp->height, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, &hdrptr.jpegp->bbox);

  c.x = 0, c.y = hdrptr.jpegp->height;
  transform_coord (&c, hdrptr.jpegp->trans_mat);
  ftracef4 ("(%d, %d) -> (%d, %d)\n", 0, hdrptr.jpegp->height, c.x, c.y);
  draw_obj_bound_minmax (c.x, c.y, &hdrptr.jpegp->bbox);

  ftracef4 ("jpeg BBox is ((%d, %d), (%d, %d))\n",
      hdrptr.jpegp->bbox.x0,
      hdrptr.jpegp->bbox.y0,
      hdrptr.jpegp->bbox.x1,
      hdrptr.jpegp->bbox.y1);
}

BOOL draw_obj_bound_object(draw_objptr hdrptr)

{ ftracef0 ("draw_obj_bound_object\n");
  switch (hdrptr.objhdrp->tag)
  { case draw_OBJTEXT:
      ftracef0 ("draw_obj_bound_object: bounding text\n");
      bound_text(hdrptr);
    break;

    case draw_OBJPATH:
      ftracef0 ("draw_obj_bound_object: bounding path\n");
      if (bound_path (hdrptr) != NULL)
        return FALSE;
    break;

    case draw_OBJSPRITE:
      ftracef0 ("draw_obj_bound_object: bounding sprite\n");
      ftracef4("sprite BBox is (%d,%d,%d,%d)\n", hdrptr.spritep->bbox.x0,
                                             hdrptr.spritep->bbox.y0,
                                             hdrptr.spritep->bbox.x1,
                                             hdrptr.spritep->bbox.y1);
    break;

    case draw_OBJGROUP:
      { int i, limit = hdrptr.objhdrp->size;
        draw_objptr objptr;
        draw_bboxtyp bound = draw_big_box;
        BOOL got_one = FALSE;

        ftracef0 ("draw_obj_bound_object: bounding group\n");
        /*scan the objects in the group to find the overall bounding box*/
        for (i = sizeof (draw_groustr); i < limit;
            i += objptr.objhdrp->size)
        { objptr.bytep = hdrptr.bytep + i;
          if (draw_obj_bound_object (objptr))
          { got_one = TRUE;
            draw_obj_bound_minmax2 (objptr, &bound);
          }
        }

        if (got_one)
        { hdrptr.groupp->bbox = bound;

          ftracef4 ("draw_obj_bound_object: group BBox is (%d,%d,%d,%d)\n",
              hdrptr.groupp->bbox.x0, hdrptr.groupp->bbox.y0,
              hdrptr.groupp->bbox.x1, hdrptr.groupp->bbox.y1);
        }
        else
          return FALSE;
      }
    break;

    case draw_OBJTAGG:
      ftracef0 ("draw_obj_bound_object: bounding tagged object\n");
      /* Bounding box of object inside tagged object is used. */
    break;

    case draw_OBJTEXTCOL:
      ftracef0 ("draw_obj_bound_object: bounding text column\n");
      draw_text_bound_objtextcol(hdrptr);
    break;

    case draw_OBJTEXTAREA:
      ftracef0 ("draw_obj_bound_object: bounding text area\n");
      draw_text_bound_objtextarea(hdrptr);
    break;

    case draw_OBJTRFMTEXT:
      ftracef0 ("draw_obj_bound_object: bounding trfmtext\n");
      bound_trfmtext (hdrptr);
    break;

    case draw_OBJTRFMSPRITE:
      ftracef0 ("draw_obj_bound_object: bounding trfmsprite\n");
      bound_trfmsprite (hdrptr);
    break;

    case draw_OBJJPEG:
      ftracef0 ("draw_obj_bound_object: bounding jpeg\n");
      bound_jpeg (hdrptr);
    break;

    default:
      ftracef1
      ( "draw_obj_bound_object: bounding unrecognised object type %d\n",
        hdrptr.objhdrp->tag
      );
      return FALSE; /*JRC 9 Oct 1990 - tell caller if there is a bbox*/
    break;
  }

  return TRUE;
}

/*Bound all the given objects. If box is non NULL, return the union of their
   boxes */
void draw_obj_bound_objects
    (diagrec *diag, int from, int to, draw_bboxtyp *box)

{ int i;
  draw_objptr hdrptr;

  ftracef0 ("draw_obj_bound_objects\n");
  if (box)
    *box = draw_big_box;

  for (i = from; i < to; i += hdrptr.objhdrp->size)
  { hdrptr.bytep = diag->paper + i;
    if (draw_obj_bound_object(hdrptr) && box)
      draw_obj_unify(box, draw_displ_bbox(hdrptr));
  }
}

void draw_obj_bound_selection(draw_bboxtyp *boundp)

{ int i;
  draw_objptr hdrptr;

  ftracef0 ("draw_obj_bound_selection\n");
  *boundp = draw_big_box;

  /* If selected, it must have a BBox */
  for (i = 0; hdrptr = draw_select_find(i), hdrptr.bytep != NULL; i++)
    draw_obj_bound_minmax2(hdrptr, boundp);
}

static void Bound_Path_Width (draw_pathstrhdr *pathptr, int *widthp)

{ ftracef1 ("Bound_Path_Width: width is %d\n", pathptr->pathwidth/640);

  if (pathptr->pathwidth > *widthp) *widthp = pathptr->pathwidth;
}

static void Bound_Width (draw_objptr hdrptr, int *widthp)

{ switch (hdrptr.objhdrp->tag)
  { case draw_OBJPATH:
      ftracef0 ("draw_obj_bound_object: bounding path\n");
      Bound_Path_Width (hdrptr.pathhdrp, widthp);
    break;

    case draw_OBJGROUP:
    { int i, limit = hdrptr.objhdrp->size;
      draw_objptr objptr;

      /*scan the objects in the group to find the max width*/
      for (i = sizeof (draw_groustr); i < limit;
          i += objptr.objhdrp->size)
      { objptr.bytep = hdrptr.bytep + i;
        Bound_Width (objptr, widthp);
      }
    }
    break;
  }
}

void draw_obj_bound_selection_width (int *widthp)

{ int i;
  draw_objptr hdrptr;

  ftracef0 ("draw_obj_bound_selection_width\n");
  *widthp = 0;

  /*If selected, it must have a BBox*/
  for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
    Bound_Width (hdrptr, widthp);
}

void draw_obj_bound_all(diagrec *diag, draw_bboxtyp *boundp)

{ draw_objptr hdrptr,limit;

  ftracef0 ("draw_obj_bound_all\n");
  hdrptr.bytep = diag->paper + diag->misc->solidstart;
  limit.bytep  = diag->paper + diag->misc->solidlimit;

  *boundp = draw_big_box;

  for (; hdrptr.bytep < limit.bytep; hdrptr.bytep += hdrptr.objhdrp->size)
  { switch(hdrptr.objhdrp->tag)
    { case draw_OBJTEXT:
      case draw_OBJPATH:
      case draw_OBJSPRITE:
      case draw_OBJGROUP:
      case draw_OBJTEXTAREA:
      case draw_OBJTEXTCOL:
      case draw_OBJTRFMTEXT:
      case draw_OBJTRFMSPRITE:
      case draw_OBJJPEG:
        draw_obj_bound_minmax2 (hdrptr, boundp);
      break;

      case draw_OBJTAGG:
        { draw_objptr tagptr;

          /*Use the bbox of the tagged object.*/
          tagptr.bytep = hdrptr.bytep + sizeof (draw_taggstr);
          draw_obj_bound_minmax2 (tagptr, boundp);
        }
      break;

      default: /* Unknown, so may not have a BBox */
      break;
    }
  }
}

/* Fetch the bbox, widening it if it is small */
void draw_obj_get_box(draw_bboxtyp *from, draw_bboxtyp *bbox)

{ ftracef0 ("draw_obj_get_box\n");
  *bbox = *from;

  if (bbox->x1 - bbox->x0 <  draw_currentmode.pixsizex)
    bbox->x0 -= draw_currentmode.pixsizex;
  if (bbox->x1 - bbox->x0 == draw_currentmode.pixsizex)
    bbox->x1 += draw_currentmode.pixsizex;

  if (bbox->y1 - bbox->y0 <  draw_currentmode.pixsizey)
    bbox->y0 -= draw_currentmode.pixsizey;
  if (bbox->y1 - bbox->y0 == draw_currentmode.pixsizey)
    bbox->y1 += draw_currentmode.pixsizey;
}

/* ------------------------------------------------------------------------- */

void draw_obj_path_move(diagrec *diag, draw_objcoord *pt)

{ draw_objcoord *coordp = (draw_objcoord*)(diag->paper +
                           diag->misc->pathedit_cb.corA_off);
  int dx = pt->x - coordp->x;
  int dy = pt->y - coordp->y;

  ftracef3
  ( "draw_obj_path_move: adjusting coords at 0x%X to (%d, %d)\n",
    &coordp->x, coordp + dx, coordp + dy
  );

  coordp->x += dx; coordp->y += dy;

  /* If moving the endpoint of a closed subpath, move its startpoint */
  if (diag->misc->pathedit_cb.corB_off)
  { draw_objcoord *coordBp = (draw_objcoord*)(diag->paper +
                              diag->misc->pathedit_cb.corB_off);
    ftracef0 ("draw_obj_path_move: also moving startpoint\n");
    *coordBp = *coordp;
  }

  if (diag->misc->pathedit_cb.corC_off)
  { draw_objcoord *coordCp = (draw_objcoord*)(diag->paper +
                              diag->misc->pathedit_cb.corC_off);
    ftracef0 ("draw_obj_path_move: also moving bezier 2 of this\n");
    coordCp->x += dx; coordCp->y += dy;
  }

  if (diag->misc->pathedit_cb.corD_off)
  { draw_objcoord *coordDp = (draw_objcoord*)(diag->paper +
                              diag->misc->pathedit_cb.corD_off);
    ftracef0 ("draw_obj_path_move: also moving bezier 1 of next\n");
    coordDp->x += dx; coordDp->y += dy;
  }
}

/*Routine for shift-adjust drgging. Alters the control point of the next
  segment round (stored in corB, corC) if they exist. JRC 6 Feb 1990*/
static void draw_obj_path_move2 (diagrec *diag, draw_objcoord *pt)

{ draw_objcoord
      *coorA = (draw_objcoord *) (diag->paper + diag->misc->pathedit_cb.corA_off);
  int dx = pt->x - coorA->x, dy = pt->y - coorA->y;

  ftracef0 ("draw_obj_path_move2\n");
  if (diag->misc->pathedit_cb.corB_off != 0 && diag->misc->pathedit_cb.corC_off != 0)
  { draw_objcoord
      *coorB = (draw_objcoord *) (diag->paper + diag->misc->pathedit_cb.corB_off),
      *coorC = (draw_objcoord *) (diag->paper + diag->misc->pathedit_cb.corC_off);
    double rA2, thA2, rC2, thC2;
    int xA2, yA2, xC2, yC2;

    /*Get all coords w r t B*/
    xA2 = coorA->x + dx - coorB->x, yA2 = coorA->y + dy - coorB->y;

    /*Convert to polar*/
    rA2 = sqrt ((double) xA2*(double) xA2 + (double) yA2*(double) yA2),
    thA2 = xA2 == 0 && yA2 == 0? 0.0: atan2 ((double) yA2, (double) xA2);

    /*Get new C coords*/
    rC2 = diag->misc->pathedit_cb.ratio*rA2, thC2 = diag->misc->pathedit_cb.angle + thA2;

    /*Convert back to cartesian*/
    xC2 = (int) (rC2*cos (thC2)), yC2 = (int) (rC2*sin (thC2));

    /*Update original values*/
    ftracef3 ("draw_obj_path_move2: adjusting coords at 0x%X to (%d, %d)\n",
        &coorC->x, xC2 + coorB->x, yC2 + coorB->y);
    coorC->x = xC2 + coorB->x, coorC->y = yC2 + coorB->y;
  }

  ftracef3 ("draw_obj_path_move2: adjusting coords at 0x%X to (%d, %d)\n",
    &coorA->x, coorA->x + dx, coorA->y + dy);
  coorA->x += dx, coorA->y += dy;
}

#if TRACE
static char *STATE (draw_state state)

{  static char *States [] =
      {  "state_path",        /* Entering a path object [*] */
         "state_path_move",   /* Placing initial point of a subpath */
         "state_path_point1", /* Placing first  point of a line or curve */
         "state_path_point2", /* Placing second point of a line or curve */
         "state_path_point3", /* Placing >=3rd  point of a line or curve */
         "state_text",        /* Entering a text object [*] */
         "state_text_caret",  /* Caret in place, empty text */
         "state_text_char",   /* Text entered */
         "state_sel",         /* Start state for select mode [*] */
         "state_sel_select",  /* 'select' drag a box to select objects   */
         "state_sel_adjust",  /* 'adjust' drag a box to adjust selection */
         /*These two added by JRC 11 Oct 1990*/
         "state_sel_shift_select",
                              /*shift-'select' drag a box to select objects*/
         "state_sel_shift_adjust",
                              /* shift-'adjust' drag a box */
         "state_sel_trans",   /* 'select' on object, translate selection */
         "state_sel_scale",   /* 'select' on stretch box, scale selection */
         "state_sel_rotate",  /* 'select' on rotate box, rotate selection */
         "state_edit",        /* Start state for edit mode [*] */
         "state_edit_drag",   /* Dragging a point during path edit */
         "state_edit_drag1",  /* Dragging two points by bezier 1 during path
                                 edit.*/
         "state_edit_drag2",  /* Dragging two points by bezier 2 during path
                                 edit.*/
         "state_rect",        /* start state for rectangle entry [*] */
         "state_rect_drag",   /* Rectangle drag in progress */
         "state_elli",        /* start state for ellipse entry [*] */
         "state_elli_drag",   /* Ellipse drag in progress */
         "state_zoom",        /* dragging zoom box [*] */
         "state_printerI",    /* dragging inner printer limits [*] */
         "state_printerO"     /* dragging outer printer limits [*] */
      };

   return States [state];
}
#endif

void draw_obj_move_construction(diagrec *diag, draw_objcoord *mouse)

{ int ptzzz_x = diag->misc->ptzzz.x;
  int ptzzz_y = diag->misc->ptzzz.y;

  ftracef4 ("draw_obj_move_construction: mouse (%d, %d) to (%d, %d)\n",
      ptzzz_x, ptzzz_y, mouse->x, mouse->y);

  ftracef2 ("main state %s, substate %s\n",
      STATE (diag->misc->mainstate), STATE (diag->misc->substate));

  switch (diag->misc->substate)
  { case state_path_point1:
    case state_path_point2:
    case state_path_point3:
      draw_displ_eor_cons2(diag); /*remove construction lines*/

      { int ptx_off = diag->misc->ptx_off;
        int pty_off = diag->misc->pty_off;
        int ptz_off = diag->misc->ptz_off;
        drawmod_pathelemptr z;

        z.bytep = ptz_off + diag->paper;

        if (z.bezier->tag == path_bezier)
        { z.bezier->x3  = mouse->x; z.bezier->y3  = mouse->y;

          draw_enter_straightcurve(diag, pty_off,ptz_off);
        }
        else
        { z.lineto->x = mouse->x; z.lineto->y = mouse->y;
        }

        if (diag->misc->substate > state_path_point1)
          draw_enter_fit_corner(diag, ptx_off, pty_off, ptz_off);
      }

      draw_displ_eor_cons2(diag); /* show construction lines */
    break;

    case state_rect_drag:
      draw_displ_eor_skeleton(diag);         /* remove old rectangle */

      { path_pseudo_rectangle *rectp;
        rectp = (path_pseudo_rectangle*)(diag->misc->pta_off + diag->paper);

        rectp->line1.x = rectp->line2.x = mouse->x;
        rectp->line2.y = rectp->line3.y = mouse->y;
      }

      draw_displ_eor_skeleton(diag);          /* redraw new rectangle */
    break;

    case state_elli_drag:
      draw_displ_eor_skeleton(diag);         /* remove old ellipse */

      { int transx = diag->misc->ellicentre.x;
        int transy = diag->misc->ellicentre.y;

        double scalex = ((double)mouse->x - (double)transx)/(double)dbc_StdCircRad;
        double scaley = ((double)mouse->y - (double)transy)/(double)dbc_StdCircRad;

        path_pseudo_ellipse *ellip;
        drawmod_pathelemptr curvep;
        int i;

        ellip = (path_pseudo_ellipse*)(diag->misc->pta_off + diag->paper);
        curvep.bezier = &ellip->curve1;

        for (i = 1; i < 13; )
        { curvep.bezier->x1 = (int)(draw_stdcircpoints[i  ].x * scalex+transx);
          curvep.bezier->y1 = (int)(draw_stdcircpoints[i++].y * scaley+transy);
          curvep.bezier->x2 = (int)(draw_stdcircpoints[i  ].x * scalex+transx);
          curvep.bezier->y2 = (int)(draw_stdcircpoints[i++].y * scaley+transy);
          curvep.bezier->x3 = (int)(draw_stdcircpoints[i  ].x * scalex+transx);
          curvep.bezier->y3 = (int)(draw_stdcircpoints[i++].y * scaley+transy);

          curvep.bezier++;
        }

        ellip->move.x = ellip->curve4.x3;
        ellip->move.y = ellip->curve4.y3;
      }

      draw_displ_eor_skeleton(diag);          /* redraw new ellipse */
    break;


    case state_sel_select:
    case state_sel_adjust:
    case state_sel_shift_select:
    case state_sel_shift_adjust:
    case state_printerI:
    case state_printerO:
    case state_zoom:
      draw_displ_eor_capturebox(diag);
      draw_capture_cb.x1 = mouse->x;
      draw_capture_cb.y1 = mouse->y;
      draw_displ_eor_capturebox(diag);
    break;

    case state_sel_trans:
      draw_displ_eor_transboxes(diag);
      draw_translate_cb.dx += mouse->x - ptzzz_x;
      draw_translate_cb.dy += mouse->y - ptzzz_y;
      draw_displ_eor_transboxes(diag);
    break;

    case state_sel_rotate:
      { double sinA,cosA;
        double len_cent_mouse =
          sqrt (((double) mouse->x - (double) draw_rotate_cb.centreX)*
                ((double) mouse->x - (double) draw_rotate_cb.centreX)+
                ((double) mouse->y - (double) draw_rotate_cb.centreY)*
                ((double) mouse->y - (double) draw_rotate_cb.centreY));

        draw_displ_eor_rotatboxes(diag);

        sinA = ((double) mouse->y - (double) draw_rotate_cb.centreY)/
                 (double) len_cent_mouse;
        cosA = ((double) mouse->x - (double) draw_rotate_cb.centreX)/
                 (double) len_cent_mouse;

        draw_rotate_cb.sinA_B
          = sinA * draw_rotate_cb.cosB - cosA * draw_rotate_cb.sinB;
        draw_rotate_cb.cosA_B
          = cosA * draw_rotate_cb.cosB + sinA * draw_rotate_cb.sinB;
        draw_displ_eor_rotatboxes(diag);
      }
    break;

    case state_sel_scale:
      draw_displ_eor_scaleboxes(diag);

      ftracef4
      ( "draw_obj_move_construction: mouse (%d, %d) ptzzz (%d, %d)\n",
        mouse->x, mouse->y,
        ptzzz_x, ptzzz_y
      );
      draw_scale_cb.new_Dx += mouse->x - ptzzz_x;
      draw_scale_cb.new_Dy -= mouse->y - ptzzz_y;

      ftracef4
      ( "draw_obj_move_construction: old (%d, %d) new (%d, %d)\n",
        draw_scale_cb.old_Dx, draw_scale_cb.old_Dy,
        draw_scale_cb.new_Dx, draw_scale_cb.new_Dy
      );

      draw_displ_eor_scaleboxes(diag);
    break;

    case state_edit_drag:
      draw_displ_eor_currnext(diag);
      draw_obj_path_move(diag, mouse);
      draw_displ_eor_currnext(diag);
    break;

    case state_edit_drag2:
      draw_displ_eor_currnext(diag);
      draw_obj_path_move2(diag, mouse);
      draw_displ_eor_currnext(diag);
    break;

    case state_edit_drag1:
      draw_displ_eor_prevcurr(diag);
      draw_obj_path_move2(diag, mouse);
      draw_displ_eor_prevcurr(diag);
    break;
  }

  diag->misc->ptzzz = *mouse;

  ftracef2
  ( "draw_obj_move_construction: ptzzz = *mouse (%d, %d)\n",
    diag->misc->ptzzz.x, diag->misc->ptzzz.y
  );
}

/* Drop any translate/rotate/scale boxes or control points being edited  */
/* apply the operation to the data base and release nulls & input focus  */
os_error *draw_obj_drop_construction(diagrec *diag)

{ os_error *err = 0;

  ftracef0 ("draw_obj_drop_construction\n");
  if (diag->misc->wantsnulls)
  { switch (diag->misc->substate)
    { case state_sel_select:
      case state_sel_adjust:
      case state_sel_shift_select:
      case state_sel_shift_adjust:
        draw_displ_eor_capturebox (diag);
        err =
          draw_select_capture_area
          ( diag,
            /*toggle?*/ diag->misc->substate == state_sel_adjust ||
              diag->misc->substate == state_sel_shift_adjust,
            draw_capture_cb,
            /*overlap?*/ diag->misc->substate == state_sel_select ||
              diag->misc->substate == state_sel_adjust /*JRC 11 Oct 1990*/
          );
      break;

      case state_sel_trans:
        draw_displ_eor_transboxes(diag);
        #if 0
          draw_undo_put_start_mod(diag, -1);
        #else
          draw_undo_separate_major_edits (diag);
        #endif
        draw_trans_translate(diag, -1, -1, &draw_translate_cb);
      break;

      case state_sel_rotate:
        draw_displ_eor_rotatboxes(diag);
        #if 0
          draw_undo_put_start_mod(diag, -1);
        #else
          draw_undo_separate_major_edits (diag);
        #endif

        ftracef0 ("BEFORE:\n"), draw_trace_db (diag);
        draw_select_make_rotatable (diag);

        /* Relies on cos coming after sin in draw_rotate_cb */
        ftracef0 ("BETWEEN:\n"), draw_trace_db (diag);
        draw_trans_rotate (diag, -1, -1,
            (draw_trans_rotate_str *) &draw_rotate_cb.sinA_B);
        ftracef0 ("AFTER:\n"), draw_trace_db (diag);
      break;

      case state_sel_scale:
        { draw_trans_scale_str scale;

          draw_displ_eor_scaleboxes(diag);

          scale.u.flags.dolines = FALSE;
          scale.u.flags.dobody  = TRUE;
          scale.old_Dx = draw_scale_cb.old_Dx;
          scale.old_Dy = draw_scale_cb.old_Dy;
          scale.new_Dx = draw_scale_cb.new_Dx;
          scale.new_Dy = draw_scale_cb.new_Dy;

          ftracef4
          ( "draw_obj_drop_construction: old (%f, %f) new (%f, %f)\n",
            scale.old_Dx, scale.old_Dy,
            scale.new_Dx, scale.new_Dy
          );
          ftracef4
          ( "draw_obj_drop_construction: SAME: old (%d, %d) new (%d, %d)\n",
            draw_scale_cb.old_Dx, draw_scale_cb.old_Dy,
            draw_scale_cb.new_Dx, draw_scale_cb.new_Dy
          );

          #if 0
            draw_undo_put_start_mod(diag, -1);
          #else
            draw_undo_separate_major_edits (diag);
          #endif
          ftracef0 ("draw_obj_drop_construction: called draw_undo_put_\n");
          ftracef4
          ( "draw_obj_drop_construction: old (%f, %f) new (%f, %f)\n",
            scale.old_Dx, scale.old_Dy,
            scale.new_Dx, scale.new_Dy
          );

          if (scale.new_Dx < 0 || scale.new_Dy < 0)
          { ftracef0 ("draw_obj_drop_construction: "
                "calling draw_select_make_rotatable\n");
            draw_select_make_rotatable (diag);
          }

          ftracef0 ("draw_obj_drop_construction: "
              "calling draw_trans_scale\n");
          draw_trans_scale(diag, -1, -1, &scale);
        }
      break;

      /* use the following to drop a point when the drag is released */
      case state_edit_drag:
      case state_edit_drag1:
      case state_edit_drag2:
      {
        #if FALSE
          draw_objptr hdrptr;
          hdrptr.bytep = diag->paper + diag->misc->pathedit_cb.obj_off;

          /* Do a full redraw of the path - an approximate solution to the
            obscured line redraw problem. Must rebound it first */
          bound_object(hdrptr);
          draw_redrawobject(diag, diag->misc->pathedit_cb.obj_off);
          draw_eor_skeleton(diag);
          draw_eor_skeleton(diag);
        #endif
      }
      break;

      case state_zoom:  /* Force new zoom */
        draw_displ_eor_capturebox(diag);
        draw_action_zoom_new(diag, draw_capture_cb);
      break;

      case state_printerI: /* Set printer limits */
      case state_printerO:
        draw_displ_eor_capturebox(diag);
        draw_set_paper_limits(diag, draw_capture_cb);
      break;

      default:
        return 0;  /* leave nulls & focus alone           */
    }

    /* Drop to idle state, release nulls & focus */
    diag->misc->substate = diag->misc->mainstate;
    draw_enter_release_nulls(diag);
  }

  return err;
}

/*------------- over object detection ---------------------------------------*/
/* over_object_search is the main loop for seeing if we are over an object   */
/* over_object looks for an object                                           */
/* previous_object looks for an object which may be under another one        */
/* Very small bboxes are widened to give us more chance of hitting them      */

static int over_object_search(diagrec *diag, int obj_off, draw_objcoord *pt)

{ int found = obj_off;
  int i;
  draw_objptr hdrptr;

  ftracef0 ("over_object_search\n");
  /* Scan the data base and return the last object whose bbox surrounds
     the point (x,y) that occurs before object obj_off.
     If not found continue search and find last object in dBase that
     surrounds point (x,y).
  */
  for (i = diag->misc->solidstart; i < diag->misc->solidlimit;
       i += hdrptr.objhdrp->size)
  { hdrptr.bytep = diag->paper + i;
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
      { draw_bboxtyp bbox;

        /* Get bbox, possibly widened */
        draw_obj_get_box(draw_displ_bbox (hdrptr), &bbox);

        if (draw_box_within (pt, &bbox))
        { if (i == obj_off && found != obj_off)
            return found;
          else
            found = i; /*over body of object*/
        }
      }
      break;

      case draw_OBJTAGG:
      { draw_bboxtyp bbox;
        draw_objptr tagptr;

        tagptr.bytep = hdrptr.bytep + sizeof (draw_taggstr);
        draw_obj_get_box (draw_displ_bbox (tagptr), &bbox);

        if (draw_box_within (pt, &bbox))
        { if (i == obj_off && found != obj_off)
            return found;
          else
            found = i; /*over body of object*/
        }
      }
      break;

      default:  /* unknown, may not even have a BBox */
      break;
    }
  }
  return found;
}

/* over_object calls previous_object with a silly offset */
int draw_obj_over_object(diagrec *diag, draw_objcoord *pt, region *regionp,
                         int *offsetp)

{ int found = over_object_search(diag, -1, pt);

  ftracef0 ("draw_obj_over_object\n");
  if (found != -1) *regionp = overObject;

  *offsetp = found;
  return (found>=0);
}

/* find the dBase object that covers (x,y) that occurs just before */
/* object obj_off                                                  */
/* This allows repeated select clicks to cycle through objects     */

int draw_obj_previous_object(diagrec *diag, int obj_off, draw_objcoord *pt)

{ ftracef0 ("draw_obj_previous_object\n");
  return over_object_search(diag, obj_off, pt);
}

/*
 Function    : draw_obj_addpath_centred_circle
 Purpose     : add a circle to a path
 Parameters  : diagram pointer
               centre of circle
               radius of circle
               move/line flag: see below
 Returns     : void
 Description : this adds the circle of the given centre and radius to the
               current path. It is assumed that there is a path under
               contruction, and that the style, colour, etc. parameters have
               been set up. If the flag is non-zero, then a line is drawn to
               the start point; otherwise we move to the start point.

               Space required: sizeof(path_curvestr)*n + sizeof(path_closestr)
               where n is 4 if the line flag is 0, and 5 if non-0.
*/

void draw_obj_addpath_centred_circle
             (diagrec *diag, draw_objcoord centre, int radius, int line)

{ draw_objcoord points [13];
  bezierarc_coord bcentre;
  int i;

  ftracef0 ("draw_obj_addpath_centred_circle\n");
  bcentre.x = centre.x;
  bcentre.y = centre.y;
  bezierarc_circle(bcentre, radius, (bezierarc_coord *)points);

  /* Move/line to initial point */
  if (line)
    draw_obj_addpath_line(diag, &points[0]);
  else
    draw_obj_addpath_move(diag, &points[0]);

  /* Curve to each point in turn */
  for (i = 1; i <= 11; i += 3)
    draw_obj_addpath_curve(diag, &points[i], &points[i+1], &points[i+2]);

  draw_obj_addpath_close(diag);
}

BOOL draw_obj_rotatable (draw_objptr hdrptr)

   /*Is an object rotatable?*/

{ switch (hdrptr.objhdrp->tag)
  { case draw_OBJPATH:
    case draw_OBJSPRITE:
    case draw_OBJTRFMTEXT:
    case draw_OBJTRFMSPRITE:
    case draw_OBJTRFMTEXTAREA:
    case draw_OBJTRFMTEXTCOL:
      return TRUE;
    break;

    case draw_OBJTEXT:
      return hdrptr.textp->textstyle.fontref != 0;
    break;

    case draw_OBJJPEG:
      return draw_jpegs_rotate;
    break;

    case draw_OBJGROUP:
    { int i, limit = hdrptr.objhdrp->size;
      draw_objptr objptr;

      /*scan the objects in the group*/
      for (i = sizeof (draw_groustr); i < limit; i += objptr.objhdrp->size)
      { objptr.bytep = hdrptr.bytep + i;
        if (draw_obj_rotatable (objptr))
          return TRUE;
      }

      return FALSE;
    }
    break;

    default:
      /*All unrecognised object types cannot be rotated, as well as anything
        not listed above (draw_OBJFONTLIST, draw_OBJTAGG, draw_OBJTEXTAREA,
        draw_OBJTEXTCOL, draw_OPTIONS).*/
      return FALSE;
    break;
  }
}


