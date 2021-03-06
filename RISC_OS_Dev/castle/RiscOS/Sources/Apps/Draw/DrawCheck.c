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
/* -> c.DrawCheck
 *
 * 1. Check a Draw file for consistency
 * 2. Shift all coordinates in a Draw file
 *
 * Author: David Elworthy
 * Version: 0.55
 * History: 0.10 - 26 July 1988 - created from BASIC DrawReport code
 *          0.20 - 29 July 1988 - verify text column objects
 *          0.30 -  1 Aug  1988 - changed text column verification
 *          0.31 -  4 Aug  1988 - various "improvements"
 *          0.40 -  4 Aug  1988 - coordinate shift added.
 *          0.50 - 15 Aug  1988 - text columns/areas name change
 *          0.51 - 23 Nov  1988 - check_bbox call removed from
 *                                check_fileHeader
 *          0.52 - 13 June 1989 - upgraded to use drawmod
 *                 16 June 1989 - upgraded to use msgs
 *                                made error() a function
 *          0.53 - 28 June 1989 - added scale+shift function
 *          0.54 - 13 July 1989 - shift extracted
 *          0.55 - 29 Aug  1989 - overall file size checked
 *
 * Checks an Draw file held in a buffer, and reports any problems, with the
 * offset from the start of the buffer.
 *
 * The (global) ok flag can indicate no error, recoverable error or fatal
 * error.
 * A fatal error is generally some sort of mistake in an object size.
 * On a fatal error, we return as soon as possible. The returned buffer
 * location need not be sensible.
 *
 * Note that the code here must be changed if there are any changes in the
 * internal structure of an object.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <ctype.h>

#include "os.h"
#include "wimp.h"
#include "sprite.h"
#include "werr.h"
#include "xferrecv.h"
#include "msgs.h"
#include "drawmod.h"
#include "jpeg.h"
#include "dbox.h"
#include "font.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawCheck.h"
#include "DrawObject.h"
#include "DrawTextC.h"
#include "DrawTrans.h"
#include "DrawFileIO.h"
#include "DrawDispl.h"

/*-------------------------------------------------------------------------*/
/* Common stuff - both shift and check                                     */

/* Types for check/shift functions */
typedef void check_shift_fn(draw_objptr object);

typedef struct
{
  draw_tagtyp  tag;                /* Tag */
  int          sizelow, sizehigh;  /* Bounds on size */
  BOOL         box;                /* Flag - object has a bbox */
  check_shift_fn *fn;              /* Function to call, or NULL */
} check_shift_table;

/* Macro to help declare them */
#define Check_shift_fn(name)  void name(draw_objptr object)

/*-------------------------------------------------------------------------*/
/* Code for checking Draw files                                         */

/* Miscellaneous headers */
static char *check_start;

/* Error levels */
#define OK_OK    0
#define OK_ERROR 1
#define OK_FATAL 2

/* Flag for indicating errors */
static int check_ok;

/* 'Infinite' size value */
#define check_BIG (INT_MAX)

/* Status flags */
static BOOL check_fontSeen, check_textSeen;

/* Forward reference */
static draw_objptr check_object(draw_objptr object);

/*
 Function    : error
 Purpose     : report an error
 Parameters  : message tag
               location in buffer
               error level
 Returns     : void
*/

static void error(char *message, char *at, int level)

{ ftracef0 ("draw_check: error [\n");

  if (at)
    werr(0, msgs_lookup("Chk00"), msgs_lookup(message), (int) (at - check_start));
  else
    werr(0, msgs_lookup(message));

  check_ok |= level;
}

/*
 Function    : check_bbox
 Purpose     : check a bounding box
 Parameters  : bounding box pointer
 Returns     : void
 Description : checks that the coordinate in the box are in the right order.
*/

static void  check_bbox(draw_bboxtyp *box)
{

  ftracef0 ("draw_check: check_bbox [\n");
  if (box->x0 > box->x1 || box->y0 > box->y1)
    error("ChkB1", (char *)box, OK_ERROR);
}

/*
 Function    : check_text
 Purpose     : check a string
 Parameters  : pointer to string
               maximum length
 Returns     : length of string
 Description : check the string for control characters, etc.
*/
static int  check_text(char *buffer, int length)
{ BOOL ctl_found = FALSE;
  int  i;
  int  c;

  ftracef0 ("draw_check: check_text [\n");

  for (i = 0 ; i < length ; i++)
  {
    if (buffer[i] == 0) return (i);

    c = (int)buffer[i];
    if (!((31 < c && c < 127) || (127 < c && c <= 255)))
      if (! ctl_found)
      { error("ChkC1", buffer, OK_ERROR);
        ctl_found = TRUE; /*only give 1 error JRC*/
      }
  }

  return (length);
}

/*
 Function    : check_size
 Purpose     : check an object size
 Parameters  : object size
               lower bound
               upper bound (may be 'check_BIG' for any size)
               pointer to location for error report
 Returns     : void
*/

static void check_size(int size, int low, int high, char *where)
{

  ftracef0 ("draw_check: check_size [\n");
  ftracef3 ("size: %d; max %d, min %d\n", size, high, low);
  if (size < low)    error("ChkO1", where, OK_FATAL);
  if (size > high)   error("ChkO2", where, OK_FATAL);
  if ((size & 3) != 0) error("ChkO3", where, OK_FATAL);
}

/*
 Function    : check_overrun
 Purpose     : check for data overrun
 Parameters  : remaining object size
               pointer to current location for error report
 Returns     : void
 Description :
*/

static void check_overrun(int size, char *where)
{

  ftracef0 ("draw_check: check_overrun [\n");
  if (size < 0) error("ChkO4", where, OK_FATAL);
}

/*--------------------------------------------------------------------------*/

/*
 Function    : check_<object>
 Purpose     : general object check routines
 Parameters  : pointer to start of object
 Returns     : void
*/

/* Font table: check we have only one, that it is after text, and that there
   is no rubbish at the end of it
 */

static Check_shift_fn(check_fontList)
{
  int fontNum;
  int ptr  = 8;            /* Skip over type and size */
  int size;

  ftracef0 ("draw_check: check_fontlist [\n");

  size = object.fontlistp->size;

  if (check_fontSeen) error("ChkF1", object.bytep, OK_ERROR);
  if (check_textSeen) error("ChkF2", object.bytep, OK_ERROR);

  check_fontSeen = TRUE;

  while (ptr < size)
  {
    if ((fontNum = (int)object.bytep[ptr++]) == 0) break;
    ptr += check_text(object.bytep+ptr, check_BIG);
  }

  check_overrun(size - ptr, object.bytep + ptr);
}

/* Text: check style, text */
static Check_shift_fn(check_textObject)
{
  int  ptr;

  ftracef0 ("draw_check: check_textObject [\n");

  check_textSeen = TRUE;

  if (object.textp->textstyle.reserved8 != 0
      || object.textp->textstyle.reserved16 != 0)
      error("ChkT1", object.bytep, OK_ERROR);
    ptr = sizeof(draw_textstrhdr) + check_text((char *)&(object.textp->text), check_BIG);

  check_overrun(object.textp->size - ptr, object.bytep + ptr);
}

/* Path: check elements of path. Must start with move, and have a line or
   curve in it somewhere */
static Check_shift_fn(check_pathObject)
{
  drawmod_pathelemptr path = draw_obj_pathstart(object);
  int  extra;
  int  lineSeen = FALSE;

  ftracef0 ("draw_check: check_pathObject [\n");

  if (path.move2->tag != path_move_2)
    error("ChkP1", object.bytep, OK_ERROR);
  do
  {
    switch (path.end->tag)
    {
      case path_term     : break;
      case path_move_2   : path.move2     += 1; break;
      case path_closeline: path.closeline += 1; break;
      case path_bezier   : path.bezier += 1;
                           lineSeen = TRUE;
                           break;
      case path_lineto   : path.lineto += 1;
                           lineSeen = TRUE;
                           break;
      default:
        error("ChkP2", path.bytep, OK_FATAL);
        return;
    }
  } while (path.end->tag != path_term);

  if (!lineSeen)
    error("ChkP3", object.bytep, OK_ERROR);

  extra = object.pathp->size -
          (path.bytep - object.bytep + sizeof(drawmod_path_termstr));

  if (extra > 0) error("ChkP4", object.bytep, OK_FATAL);
  else
    check_overrun(extra, path.bytep);
}

/* Sprite: check size (based on minimum size for a sprite definition),
   and sprite header block */
static Check_shift_fn(check_spriteObject)
{
  int  spriteSize;

  ftracef0 ("draw_check: check_spriteObject [\n");

  spriteSize = object.spritep->sprite.next;
  if (object.spritep->size - sizeof(draw_objhdr) < spriteSize)
    error("ChkS1", object.bytep, OK_FATAL);
}

static Check_shift_fn(check_groupObject)
{
  char *end;

  ftracef0 ("draw_check: check_groupObject [\n");

  end = object.bytep + object.groupp->size;
  object.bytep += sizeof(draw_groustr);

  while ((check_ok & OK_FATAL) == 0 && object.bytep < end)
    object = check_object(object);
}

#ifdef draw_OBJTAGG
static Check_shift_fn(check_tagObject)
{
  char *end;

  ftracef0 ("draw_check: check_tagObject [\n");

  end = check_object(object.bytep + 28);
  check_overrun((int)(end - object.bytep) - object.objhdrp->size, end);
}
#endif

/* Text column: check size and tag. TRUE if it was a text column */
static BOOL check_textColumn(draw_textcolhdr *column)
{ ftracef0 ("draw_check: check_textColumn [\n");

  if (column->tag == 0) return (FALSE);
  else if (column->tag != draw_OBJTEXTCOL)
  {
    error("ChkT2", (char *)column, OK_FATAL);
    return (FALSE);
  }

  check_size(column->size, sizeof(draw_textcolhdr), sizeof(draw_textcolhdr),
             (char *)column);
  return((check_ok & OK_FATAL) == 0);
}

/* Text area: check size and verify using text column code */
static Check_shift_fn(check_textArea)
{
  int  columns, actualColumns;
  draw_objptr column, area;
  char *text;

  ftracef0 ("draw_check: check_textArea [\n");

  for (column.textcolp = &(object.textareastrp->column), actualColumns = 0 ;
       check_ok != OK_FATAL && check_textColumn(column.textcolp) ;
       column.bytep += sizeof(draw_textcolhdr), actualColumns += 1)
    ;

  text = sizeof(draw_textareastrend) + column.bytep;
  if (!draw_text_verifyTextArea(text, strlen(text), &columns, NULL) ||
      columns < 1)
    check_ok |= OK_ERROR;
  else if (columns != actualColumns)
    error("ChkT3", object.bytep, OK_ERROR);
  else /* Ensure reserved words are zero */
  {
    area.bytep = column.bytep;
    if (area.textareaendp->blank1 != 0 || area.textareaendp->blank2 != 0)
      error("ChkT4", object.bytep, OK_ERROR);
  }
}

/* Text: check style, text */
static Check_shift_fn(check_trfmtextObject)

{ int  ptr;

  ftracef0 ("draw_check: check_trfmtextObject [\n");

  check_textSeen = TRUE;

  if (object.trfmtextp->textstyle.reserved8 != 0
      || object.trfmtextp->textstyle.reserved16 != 0)
      error("ChkT1", object.bytep, OK_ERROR);
    ptr = sizeof(draw_trfmtextstrhdr) + check_text ((char *) &object.trfmtextp->text, check_BIG);

  check_overrun(object.trfmtextp->size - ptr, object.bytep + ptr);
}

/* Sprite: check size (based on minimum size for a sprite definition),
   and sprite header block */
static Check_shift_fn(check_trfmspriteObject)
{
  int  spriteSize;

  ftracef0 ("draw_check: check_trfmspriteObject [\n");

  spriteSize = object.trfmspritep->sprite.next;
  if (object.trfmspritep->size - sizeof(draw_objhdr) < spriteSize)
    error("ChkS1", object.bytep, OK_FATAL);
}

/* JPEG: size <= check header + len < size + 4*/
static Check_shift_fn(check_jpegObject)

{ ftracef0 ("draw_check: check_jpegObject [\n");

  if (!(sizeof(draw_jpegstrhdr) + object.jpegp->len <= object.jpegp->size &&
      object.jpegp->size < sizeof(draw_jpegstrhdr) + object.jpegp->len + 4))
    error("ChkS1", object.bytep, OK_FATAL);
}

/*-------------------------------------------------------------------------*/

/*
 Function    : check_fileHeader
 Purpose     : check Draw file header
 Parameters  : object pointer
 Returns     : pointer to object after header
 Description : checks the file header for:
   - not being an Draw file
   - bad version
*/

static draw_objptr check_fileHeader(draw_objptr object)
{
  int drawName = *(int *) "Draw"; /* the text 'Draw' as an integer */

  ftracef0 ("draw_check\n");

  if (object.wordp[0] != drawName)
  {
    Error(0, "ChkH1");
    check_ok = OK_FATAL;
  }
  else
  {
    if (object.filehdrp->majorstamp > majorformatversionstamp)
    {
      Error(0, "ChkH2");
      check_ok = OK_FATAL;
    }
  }

  object.bytep += sizeof(draw_fileheader);
  return object;
}

/*
 Data Group  : functions descriptions table
 Description :
*/

static check_shift_table check_functions[draw_TAG_LIMIT] =
{ { draw_OBJFONTLIST,   sizeof(draw_fontliststrhdr),  check_BIG,
      FALSE, check_fontList},
  { draw_OBJTEXT,       sizeof(draw_textstrhdr),      check_BIG,
      TRUE,  check_textObject},
  { draw_OBJPATH,       sizeof(draw_pathstrhdr),      check_BIG,
      TRUE,  check_pathObject},
#ifdef draw_OBJRECT
  { draw_OBJRECT,       sizeof(draw_objhdr),          sizeof(draw_objhdr),
      TRUE,  NULL},
#endif
#ifdef draw_OBJELLI
  { draw_OBJELLI,       sizeof(draw_objhdr),          sizeof(draw_objhdr),
      TRUE,  NULL},
#endif
  { draw_OBJSPRITE,     sizeof(draw_spristrhdr),      check_BIG,
      TRUE, check_spriteObject},
  { draw_OBJGROUP,      sizeof(draw_groustr),         check_BIG,
      TRUE, check_groupObject},
#ifdef draw_OBJTAGG
  { draw_OBJTAGG,       sizeof(draw_objhdr),          check_BIG,
      TRUE, check_tagObject},
#endif
  { draw_OBJTEXTAREA,   sizeof(draw_textareastrhdr),  check_BIG,
      TRUE, check_textArea},
  { draw_OBJTEXTCOL,    0,                            0,
      FALSE, NULL}, /*never seen*/
  { draw_OPTIONS,       sizeof (draw_optionsstr),     sizeof (draw_optionsstr),
      FALSE, NULL},
  { draw_OBJTRFMTEXT,   sizeof (draw_trfmtextstrhdr), check_BIG,
      TRUE, check_trfmtextObject},
  { draw_OBJTRFMSPRITE, sizeof(draw_trfmspristrhdr),  check_BIG,
      TRUE, check_trfmspriteObject},
  { draw_OBJJPEG,       sizeof(draw_jpegstrhdr),      check_BIG,
      TRUE, check_jpegObject},

  /*terminator*/
  { (draw_tagtyp) -1,   0,                            0,
      FALSE, NULL}
};

/*
 Function    : check_object
 Purpose     : check an Draw object
 Parameters  : pointer to object data
 Returns     : pointer to next object
*/

static draw_objptr check_object(draw_objptr object)
{
  draw_tagtyp type;
  check_shift_table *c;

  ftracef0 ("draw_check: check_object [\n");

  type = object.objhdrp->tag;

  for (c = check_functions ; c->tag != -1 ; c++)
  {
    if (c->tag == type)
    {
      /* Check size */
      check_size(object.objhdrp->size, c->sizelow, c->sizehigh,
                 object.bytep);
      if (check_ok & OK_FATAL)
        object.bytep = NULL;
      else
      { /* Check bbox */
        if (c->box) check_bbox(draw_displ_bbox (object));

        /* Additional checks */
        if (c->fn) (c->fn)(object);
      }
      break;
    }
  }

#if (REJECTUNKNOWNOBJECTS)
  if (c->tag == -1) error("ChkU1", object.bytep, OK_FATAL);
#else
  if (c->tag == -1)
  { /* Check that the size is reasonable: at least one word */
    check_size(object.objhdrp->size, sizeof(int), check_BIG, object.bytep);

    if (check_ok & OK_FATAL)
      object.bytep = NULL;
  }
#endif

  object.bytep += object.objhdrp->size;
  return (object);
}

/*
 Function    : draw_check_Draw_file
 Purpose     : check an Draw file for errors
 Parameters  : diagram record
               start and end offsets
 Returns     : TRUE if no errors
 Notes       : start must be the offset of the file header
*/

BOOL draw_check_Draw_file(diagrec *diag, int start, int end)
{
  draw_objptr object, endobj;

  ftracef0 ("draw_check_Draw_file [\n");

  check_fontSeen = check_textSeen = FALSE;
  check_ok       = OK_OK;
  object.bytep   = check_start = diag->paper + start;
  endobj.bytep   = diag->paper + end;
  object         = check_fileHeader(object);

  while ((check_ok & OK_FATAL) == 0 && object.bytep < endobj.bytep)
    object = check_object(object);

  /* Check that the object sizes were exact */
  if (check_ok == OK_OK && object.bytep > endobj.bytep)
    error("ChkF3", NULL, OK_ERROR);

  return (check_ok == OK_OK);
}

/*------------------------------------------------------------------------*/
/* Code for shifting files                                                */

/* Globals to hold the current base */
static int shift_x, shift_y;

/*
 Function    : draw_shift_Draw_file
 Purpose     : transform all coordinates to a new origin
 Parameters  : diagram record
               start and end offsets
               x base, y base
 Returns     : void
 Description : this shifts all coordinates in the Draw file held in the
               buffer to the given base. It uses code similar to the
               checking code to follow the structure of the file.
               Assumes the buffer has already been checked.
               Start must be after the file header.
*/

void draw_shift_Draw_file(diagrec *diag, int start, int end,
                          trans_str *trans)
{

  ftracef0 ("draw_shift_Draw_file [\n");
  draw_trans_translate_without_undo(diag, start, end, trans);
}

/*------------------------------------------------------------------------*/
/* Code for scaling files                                                 */
/* Unlike select scaling, the fixed point is the bottom left              */
/* Scaling leaves the bboxes unchanged, so the objects MUST be rebound    */

/* Globals to hold the current factor (base is in shift_ variables) */
static double scale_x, scale_y;
#define scaleX(i)  i = (int)((i) * scale_x)
#define scaleY(i)  i = (int)((i) * scale_y)

/* Forward reference */
static draw_objptr scale_object(draw_objptr object);

/*
 Function    : scale_coord
 Purpose     : scale a coordinate
 Parameters  : pointer to x (y assumed to be 1 word after x)
 Returns     : void
*/

static void scale_coord(int *at)
{ ftracef0 ("draw_check: scale_coord [\n");
  at[0] = (int)((at[0] * scale_x) + shift_x);
  at[1] = (int)((at[1] * scale_y) + shift_y);
}

/* Text - scale base location and font sizes */
static Check_shift_fn(scale_textObject)
{
  ftracef0 ("draw_check: scale_textObject [\n");

  scale_coord(&(object.textp->coord.x));
  scaleX(object.textp->fsizex);
  if (object.textp->fsizex < 0)
    object.textp->fsizex = -object.textp->fsizex;
  scaleY(object.textp->fsizey);
  if (object.textp->fsizey < 0)
    object.textp->fsizey = -object.textp->fsizey;
}

/* Path: scale each element of path; also linewidth (in x direction) */
static Check_shift_fn(scale_pathObject)
{
    drawmod_pathelemptr path = draw_obj_pathstart(object);

  ftracef0 ("draw_check: scale_pathObject [\n");

    scaleX(object.pathp->pathwidth);
    if (object.pathp->pathwidth < 0)
      object.pathp->pathwidth = -object.pathp->pathwidth;

    do  switch (path.end->tag)
        {
            case path_term:
            break;
            case path_move_2:
                scale_coord(&(path.move2->x));
            path.move2 += 1; break;
            case path_lineto:
                scale_coord(&(path.lineto->x));
                path.lineto += 1;
            break;
            case path_closeline:
                path.closeline += 1;
            break;
            case path_bezier:
                scale_coord(&(path.bezier->x1));
                scale_coord(&(path.bezier->x2));
                scale_coord(&(path.bezier->x3));
                path.bezier += 1;
            break;
        }
    while (path.end->tag != path_term);
}

/* Group - recurse on contents */
static Check_shift_fn(scale_groupObject)
{
  char *end;

  ftracef0 ("draw_check: scale_groupObject [\n");

  end = object.bytep + object.groupp->size;
  object.bytep += sizeof(draw_groustr);

  while (object.bytep < end)
    object = scale_object(object);
}

#ifdef draw_OBJTAGG
/* Tagged - recurse */
static Check_shift_fn(scale_tagObject)
{
  ftracef0 ("draw_check: scale_tagObject [\n");

  scale_object(object.bytep + 28);
}
#endif

/* Functions table - size fields are not used */
static check_shift_table scale_functions[draw_TAG_LIMIT] =
{
 {draw_OBJFONTLIST,   0, 0, FALSE, NULL},
 {draw_OBJTEXT,       0, 0, TRUE,  scale_textObject},
 {draw_OBJPATH,       0, 0, TRUE,  scale_pathObject},
#ifdef draw_OBJRECT
 {draw_OBJRECT,       0, 0, TRUE,  NULL},
#endif
#ifdef draw_OBJELLI
 {draw_OBJELLI,       0, 0, TRUE,  NULL},
#endif
 {draw_OBJSPRITE,     0, 0, TRUE,  NULL},
 {draw_OBJGROUP,      0, 0, TRUE,  scale_groupObject},
#ifdef draw_OBJTAGG
 {draw_OBJTAGG,       0, 0, TRUE,  scale_tagObject},
#endif
 {draw_OBJTEXTAREA,   0, 0, TRUE,  NULL},
 {draw_OPTIONS,       0, 0, FALSE, NULL},
 {draw_OBJTRFMTEXT,   0, 0, TRUE,  NULL},
 {draw_OBJTRFMSPRITE, 0, 0, TRUE,  NULL},
 {draw_OBJJPEG,       0, 0, TRUE,  NULL},

 {(draw_tagtyp) -1,   0, 0, FALSE, NULL}
};

/*
 Function    : scale_object
 Purpose     : scale an arc draw object
 Parameters  : object pointer
 Returns     : pointer to next object
*/

static draw_objptr scale_object(draw_objptr object)
{
  draw_tagtyp type;
  check_shift_table *s;

  ftracef0 ("draw_check: scale_object [\n");

  type = object.objhdrp->tag;

  for (s = scale_functions ; s->tag != -1 ; s++)
    if (s->tag == type)
    { /* Additional shifting */
      if (s->fn) (s->fn)(object);
      break;
    }

  object.bytep += object.objhdrp->size;
  return (object);
}

/*
 Function    : draw_scale_Draw_file
 Purpose     : scale and transform all coordinates to a new origin
 Parameters  : diagram start
               start and end offsets (after file header)
               x base, y base
               x scale, y scale
 Returns     : void

 Scaling is applied before shifting.
*/

void draw_scale_Draw_file(diagrec *diag, int start, int end,
                         int xMove, int yMove, double xScale, double yScale)
{ draw_objptr object;
  char *endptr;

  ftracef0 ("draw_scale_Draw_file [\n");

  shift_x = xMove;
  shift_y = yMove;
  scale_x = xScale;
  scale_y = yScale;

  object.bytep = diag->paper + start;
  endptr       = diag->paper + end;

  while (object.bytep < endptr)
     object = scale_object(object);
}
