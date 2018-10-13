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
/* c.DrawUndo
 *
 * Undo functions in Draw
 *
 * Author:  David Elworthy
 * Version: 0.18
 * History: 0.10 - 17 July 1989 - created
 *          0.11 - 26 July 1989 - rehack undo classes
 *          0.12 - 28 July 1989 - changed head structure
 *          0.13 -  2 Aug  1989 - state undo made explicit
 *          0.14 -  7 Aug  1989 - put_end (FALSE) was killing all of buffer:
 *                                want it to kill just most recent chunk
 *          0.15 -  8 Aug  1989 - major rehack to make it more like Edit
 *                 10 Aug  1989 - selection changes
 *                 11 Aug  1989 - undo separator, abolish minor edit concept
 *          0.16 - 22 Aug  1989 - modified and name operations added
 *          0.17 - 12 Sept 1989 - fix a serious problem about overwriting
 *          0.18 - 25 Sept 1989 - fix a redraw bug
 *          Jonathan Coxhead 2 August 1991 Remove the funny -1 flags for
 *             buffer empty (waste 1 word in the buffer, gain more in code)
 *                 16th Dec 1993 Add FLEXUNDO to allow the undo buffer to be
 *                 held in a heap block.
 *
 * Based on the undo code in Edit.
 * Unlike Edit, we put separators between undone blocks. This is because the
 * original put and the corresponding undo inverse may be of different
 * sizes. If we don't do this, redo gets into problems - it doesn't remove
 * enough from the buffer.
 *
 * The current data structures are inefficient. Some proposals:
 *  don't use sizeof, since it rounds to word size
 *  don't use size field where size is deducible. This makes skipop more
 *   complex
 *
 * Some of this code is rather messy - it relies on status information
 * carried by flags and by special values of the pointers. It would be nice
 * to do a rewrite.
 *
 * The redraw on undoing delete, insert or object data change can be very
 * slow, if there are many objects. The approach that is taken from version
 * 0.18 onwards is to call a routine which accumulates rectangles and then
 * redraws the lot. This may be worse in some cases, but it avoid very
 * confusing slowness in others: particularly the case of undoing deletion
 * of many objects (see a bug report from JAllin for an example of this
 * confusion!).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "os.h"
#include "flex.h"
#include "werr.h"
#include "drawmod.h"
#include "jpeg.h"
#include "dbox.h"
#include "font.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawDispl.h"
#include "DrawObject.h"
#include "DrawSelect.h"
#include "DrawTrans.h"
#include "DrawUndo.h"

#if TRACE
  /*#define XTRACE 1*/
#endif

#define GENERATE(s) os_swi1 (0x2B, "####" s)

#define ONE_WORD 4 /*avoids buffer full/buffer empty ambiguity*/

#define FLEXUNDO 1 /*clear this to put the undo buffers in heap blocks*/

typedef struct drawundo__state
{ char *buf;
  int  size;
  int  head;
  int  tail;
/*
  tail always points to a major structure. This enables us to discard chunks
  of space in the buffer without fear of only deleting the undo for part of
  an operation (as can happen in Edit). The size field of the major
  structure is filled in when the next major is placed. If we try to discard
  the current chunk, we clear the buffer and say it can't be done.
  If the buffer has just been wiped, then head and tail are set to -1. We
  need to do this, to distinguish the case of a completely empty buffer from
  an exactly full one.
  *** Not any more ***
 */
  int  ptr;        /* current pointer for undo/redo */
  int  start;      /* offset of last major edit structure. This is used to
                      find where to fill in the next field when putting, and
                      to avoid overwriting the undo information during an
                      undo. -1 if we aren't in a state where we need to
                      know/can know */
  unsigned int  withinundo : 1;
  unsigned int  full       : 1;
/*
   If set, buffer filled up during put, called either externally or from
   undo_undo. In this case, any further putting is prevented until either we
   put a major separator or the end of the undo/redo. In all of these cases,
   the buffer is cleared. Undo and redo are also prevented at the level of
   major chunks if the buffer is full. This is in case part of the undo
   chunk was put but not all of it.
 */
 } drawundo__state;

#define IND(a, b) ((a)? (a)->b: NULL)
#define IND2(a, b, c) ((a) && (a)->b? ((drawundo) (a)->b)->c: NULL)

/* -------- Addition classes ---------- */
#define draw_undo__major ((draw_undo_class) 127)
/* Major edit separator */

#define draw_undo__undo_sep ((draw_undo_class) 126)
/* Separator between blocks put in undo. This is needed for redo. It appears
at the end of the information put by undo. The size field indicates where
the put for the undo started. */

/* Internal code for minor edit */
#define drawundo_MINOR ((drawundo_result) -1)

/* Each entry in the undo buffer ends in the following structure: */
typedef struct
{
/*>>> could compact this: e.g. make size a short */
  int  size;     /* Size of data excluding this terminator */
  char class;    /* Class of undo operation. *** MUST be a char *** */
} undo_term;

#ifdef XTRACE
  static void xtracef (drawundo u)

  { int j, size = 0 /*for Norcroft*/;
    enum {at_class, at_size, at_first_data, in_data} state = at_class;
    char class = '\0';
    BOOL found_ptr = FALSE;

    ftracef0 ("Undo buffer contains ...\n");

    for (j = u->head; j != u->tail;)
    { if (!(0 <= j && j < u->size))
        GENERATE ("Internal error - counter outside buffer");

      if (j == u->ptr)
      { if (state == at_class)
        { found_ptr = TRUE;
          ftracef0 ("*******\n");
        }
        else
          GENERATE ("Internal error - current position not a class");
      }

      j = (j - 4 + u->size)%u->size;

      ftracef1 ("buf [%d]: ", j);

      switch (state)
      { case at_class:
        { class = (char) u->buf [j];

          ftracef (NULL, 0, "class %s (0x%X)", class ==
              draw_undo__major? "draw_undo__major": class ==
              draw_undo__changestate? "draw_undo__changestate": class ==
              draw_undo__trans? "draw_undo__trans": class ==
              draw_undo__rotate? "draw_undo__rotate": class ==
              draw_undo__object? "draw_undo__object": class ==
              draw_undo__insert? "draw_undo__insert": class ==
              draw_undo__delete? "draw_undo__delete": class ==
              draw_undo__select? "draw_undo__select": class ==
              draw_undo__sel_array? "draw_undo__sel_array": class ==
              draw_undo__sel_array_no? "draw_undo__sel_array_no": class
              == draw_undo__redraw? "draw_undo__redraw": class ==
              draw_undo__info? "draw_undo__info": class ==
              draw_undo__undo_sep? "draw_undo__undo_sep": "???",
              *(int *) &u->buf [j]);

          state = at_size;
        }
        break;

        case at_size:
        { size = *(int *) &u->buf [j];

          if (class == draw_undo__undo_sep)
          { ftracef (NULL, 0, "size %d", size);
            state = at_class;
          }
          else
          { ftracef (NULL, 0, "size %d", size);
            state = size > 0? at_first_data: at_class;
          }
        }
        break;

        case at_first_data:
        case in_data:
          ftracef (NULL, 0, "data %d (0x%X)\n", *(int *) &u->buf [j],
              *(int *) &u->buf [j]);
          state = (size -= 4) > 0? in_data: at_class;
        break;
      }
      if (j == u->ptr) ftracef (NULL, 0, " ***");
      if (state != in_data) ftracef (NULL, 0, "\n");
    }
    ftracef0 ("... end\n");

    if (u->head != u->tail && !found_ptr)
      GENERATE ("ptr not pointing in buffer\n");
  }

  #define XTRACEF \
      (ftracef5 ("... diag->undo 0x%X, diag->undo->tail %d, " \
          "diag->undo->ptr %d, diag->undo->start %d, " \
          "diag->undo->head %d\n", \
          IND (diag, undo), \
          IND2 (diag, undo, tail), \
          IND2 (diag, undo, ptr), \
          IND2 (diag, undo, start), \
          IND2 (diag, undo, head)), \
      xtracef ((drawundo) IND (diag, undo)))
#else
  #define XTRACEF ((void) 0)
#endif

#define FTRACEF0(x0) \
    (ftracef0 (x0), XTRACEF)
#define FTRACEF1(x0, x1) \
    (ftracef1 (x0, x1), XTRACEF)
#define FTRACEF2(x0, x1, x2) \
    (ftracef2 (x0, x1, x2), XTRACEF)
#define FTRACEF3(x0, x1, x2, x3) \
    (ftracef3 (x0, x1, x2, x3), XTRACEF)
#define FTRACEF4(x0, x1, x2, x3, x4) \
    (ftracef4 (x0, x1, x2, x3, x4), XTRACEF)
#define FTRACEF5(x0, x1, x2, x3, x4, x5) \
    (ftracef5 (x0, x1, x2, x3, x4, x5), XTRACEF)

#define SGN(x) ((x) > 0? 1: (x) < 0? -1: 0)

#define INITIAL_BUF_SIZE 20

/* The data for the individual operations is as follows: */
typedef struct
{ draw_state   state;
  diag_options options;
} undo_changestate;

/* Trans and Rotate use draw_undo_trans and draw_undo_rotate */

/* Object and Delete put the offset. For Object and Delete, this is
   preceded by a block of data. For object, the offset is negated if there
   is to be no redraw.
 */

/* Insert puts the object offset and the number of bytes inserted: */
typedef struct
{ int nbytes;
  int offset;
} undo_insert;

/* Select puts an offset. For deselection it is -ve with 0 changed to -1 */

/* Sel_Array put the whole array. The index is deducible from the size */

/* Major (start) puts the offset of the next major structure (-1 if not yet
   set, i.e. the start of the latest undo chunk). The next field gets filled
   in when we put the next major structure, or at the start of an undo. The
   second of these is necessary to stop redo resetting u->ptr.
 */
typedef struct {int  next;} undo_major;

#define MajorSize (sizeof (undo_term) + sizeof (undo_major))
/* Total size of a major edit entry */

/* Redraw puts a bbox */

/* Flags used in undo_info */
typedef struct
{ unsigned int modified : 1;
  unsigned int named    : 1;
} undo_info_flag;

/* Info puts the modified flag, and the filename. The whole thing is padded
  to a word boundary. The filename may be omitted.
 */
typedef struct
{ undo_info_flag flag;
  char name [FILENAMEMAX]; /*Buffer for filename - may not be full size*/
} undo_info;

#if TRACE
  static BOOL Within (int a, int b, int c)
  { return a == b || b == c || c == a || a < b == b < c != c < a;
        /*honest!*/
  }

  static BOOL Outside (int a, int b, int c)
  { return a == b || b == c || c == a || a < b == b < c == c < a;
        /*would I lie?*/
  }

  #define Assert_Within(s, a, b, c) \
    ( Within (a, b, c)? \
        (void) 0: \
        werr (TRUE, "%s,%d: %s not within [%s; %s]", \
            __FILE__, __LINE__, #b, #a, #c) \
    )

  #define Assert_Outside(s, a, b, c) \
    ( Outside (a, b, c)? \
      (void) 0: \
      werr (TRUE, "%s,%d: %s not outside [%s; %s]", \
            __FILE__, __LINE__, #b, #a, #c) \
    )
#endif

/* -------- Creation, Deletion -------- */
static void draw_undo__wipe (drawundo u)

{ ftracef1 ("draw_undo__wipe: u: 0x%X\n", u);
  u->head  = u->tail = u->ptr = 0;
  u->start = -1;
  u->withinundo = 0;
  u->full       = 0;
}

drawundo draw_undo_new (void)

{ drawundo u = Alloc (sizeof (drawundo__state));

  ftracef1 ("draw_undo_new: Alloc at 0x%X\n", u);
  if (u == 0) return 0;

#if FLEXUNDO
  if (FLEX_ALLOC ((void **) &u->buf, INITIAL_BUF_SIZE) == 0)
#else
  if ((u->buf = Alloc (INITIAL_BUF_SIZE)) == 0)
#endif
  { Free (u);
    return 0;
  }

  draw_undo__wipe (u);
  u->size = INITIAL_BUF_SIZE;
  return u;
}

void draw_undo_dispose (drawundo u)

{ ftracef1 ("draw_undo_dispose: u: 0x%X\n", u);
#if FLEXUNDO
  FLEX_FREE ((void **) &u->buf);
#else
  Free (u->buf);
#endif
  Free (u);
}

void draw_undo_setbufsize (diagrec *diag, int nbytes)

{ drawundo u = diag->undo;
  int by = nbytes <= u->size? 0: nbytes - u->size;

  FTRACEF2 ("draw_undo_setbufsize: diag: 0x%X; diag->undo: 0x%X\n",
      diag, diag->undo);
#if FLEXUNDO
  if (FLEX_MIDEXTEND ((void **) &u->buf, u->head, by))
  { draw_undo__wipe (u);

  #if 1
    draw_undo_put (diag, draw_undo__major, NULL, NULL);
        /*Fixes problem with full buffer.*/
  #endif
    u->size += by;
  }
  else
  { /* can't have the store, but it doesn't matter. */
    FTRACEF0 ("draw_undo_setbufsize: didn't work.\n");
  }
#else
  { char *buf;

    if ((buf = Alloc (nbytes)) != 0)
    { draw_undo__wipe (u);

    #if 1
      draw_undo_put (diag, draw_undo__major, NULL, NULL);
          /*Fixes problem with full buffer.*/
    #endif

      Free (u->buf);
      u->buf = buf;
      u->size = nbytes;
    }
    else
    { /* can't have the store, but it doesn't matter. */
      FTRACEF0 ("draw_undo_setbufsize: didn't work.\n");
    }
  }
#endif
}

void draw_undo_prevent_undo (diagrec *diag)

{ FTRACEF2 ("draw_undo_prevent_undo: diag: 0x%X; diag->undo: 0x%X\n",
      diag, IND (diag, undo));
  draw_undo__wipe (diag->undo);

  #if 1
  draw_undo_put (diag, draw_undo__major, NULL, NULL);
      /*Fixes problem with full buffer*/
  #endif
}

/* Move pointer. */
static int move_ptr (drawundo u, int ptr, int by)

{ ftracef3 ("draw_undo: move_ptr: u: 0x%X; ptr: %d; by: %d\n", u, ptr, by);
  by = SGN (by)*(abs (by) + 3 & ~3); /*word align*/
  return (ptr + by + u->size)%u->size;
}

/* ---------- Put operations. ---------- */
/* Get a pointer to a next field in a major structure which starts at the
   given offset. Allows for circularity in buffer. */
static int *int_pointer (drawundo u, int where)

{ ftracef5 ("draw_undo: int_pointer: u: 0x%X; u->buf: 0x%X; u->size: %d; "
      "where: %d -> %d\n",
      u, u->buf, u->size, where, u->buf + where%u->size);
  /*if (where == u->size) where = 0;*/
  return (int *) (u->buf + where%u->size);
}

/* Check there is space to insert data */
/* The size of an undo_term is added in to nbytes */
/* Discards space as necessary */
/* Returns FALSE if buffer too small, or if we overwrite current chunk */
static BOOL draw_undo__checkspace (drawundo u, int nbytes)

{ ftracef2 ("draw_undo__checkspace: u: 0x%X; nbytes: %d\n", u, nbytes);
  nbytes += sizeof (undo_term);

  if (nbytes > u->size - ONE_WORD)
    /* Can't be done */
    return FALSE;

  while (TRUE)
  { int freespace, next;

    freespace = u->size - (u->head - u->tail + u->size)%u->size - ONE_WORD;

    ftracef1 ("draw_undo__checkspace: %d bytes free\n", freespace);
    if (freespace >= nbytes) break;

    /* Discard from tail, and see if that helps */

    /* Error if the tail has reached the start position: works for both
       putting and undo */
    if (u->start == u->tail || u->start == -1) return FALSE;

    /* Get the next field of the major structure at tail */
    next = *int_pointer (u, u->tail);

    /* Check we are not going to overwrite the current put */
    if (next == -1) return FALSE;

    ftracef1 ("draw_undo__checkspace: discard space: tail set to %d\n",
        next);
    u->tail = next;
  }

  return TRUE;
}

/*Put a block of data. The data is placed at the head. It is assumed that
  there is enough space*/
static void draw_undo__putblock (drawundo u, char *from, int nbytes)

{ int endspace;

  ftracef3 ("draw_undo__putblock: u: 0x%d; from: 0x%X; nbytes: %d\n",
      u, from, nbytes);
  if (nbytes == 0) return;

  if ((endspace = u->size - u->head) >= nbytes)
    /* Will all fit after head */
    memcpy (u->buf + u->head, from, nbytes);
  else
  { /* Split into two parts */
    memcpy (u->buf + u->head, from, endspace);
    memcpy (u->buf, from + endspace, nbytes - endspace);
  }
  u->head = move_ptr (u, u->head, nbytes);
}

/* Put a block and a terminator */
static void draw_undo__putdata (drawundo u, char *from, undo_term *term)

{ ftracef0 ("draw_undo__putdata\n");
  if (from != NULL)
    draw_undo__putblock (u, from, term->size);
  draw_undo__putblock (u, (char *) term, sizeof (undo_term));
}

/* Put a sequence of blocks for some of the classes */
/* Puts a block from 'from' of 'fromsize' */
/* Then 'data' as a word */
/* Then 'term.' The size field is set here */
static BOOL put_blocks (drawundo u, char *from, int fromsize, int data,
    undo_term *term)

{ int size = fromsize + sizeof (int);

  ftracef0 ("draw_undo: put_blocks\n");
  if (!draw_undo__checkspace (u, size))
    return FALSE;

  term->size = size;
  draw_undo__putblock (u, from, fromsize);
  draw_undo__putblock (u, (char *) &data, sizeof (int));
  draw_undo__putblock (u, (char *) term, sizeof (undo_term));
  return TRUE;
}

void draw_undo_put (diagrec *diag, draw_undo_class class, int data,
    int data1)

{ undo_term term;
  BOOL space_ok = TRUE;
  drawundo u = diag->undo;

  FTRACEF4 ("draw_undo_put: diag: 0x%X; class: %d; data: %d; data1: %d\n",
      diag, class, data, data1);
  #ifdef XTRACE
    FTRACEF3 ("... u->head: %d; u->ptr: %d; u->tail: %d\n",
        IND (u, head), IND (u, ptr), IND (u, tail));
  #endif

  /* Prevent putting if buffer full */
  if (u->full) return;

  /* Special check for diagram addresses */
  if (class & draw_undoDIAG)
  { BOOL neg = data < 0;

    data = abs (data) - (int) diag->paper; /* Turn data into an offset */
    if (neg) data = -data;                 /* Restore sign */
    class = (draw_undo_class) (class & ~draw_undoDIAG);
  }

  ftracef1 ("draw_undo_put (%s)\n", class == draw_undo__major? "draw_undo__major":
      class == draw_undo__changestate? "draw_undo__changestate": class == draw_undo__trans?
      "draw_undo__trans": class == draw_undo__rotate? "draw_undo__rotate": class
      == draw_undo__object? "draw_undo__object": class == draw_undo__insert? "draw_undo__insert":
      class == draw_undo__delete? "draw_undo__delete": class == draw_undo__select?
      "draw_undo__select": class == draw_undo__sel_array? "draw_undo__sel_array":
      class == draw_undo__sel_array_no? "draw_undo__sel_array_no": class == draw_undo__redraw?
      "draw_undo__redraw": class == draw_undo__info? "draw_undo__info": class == draw_undo__undo_sep? "draw_undo__undo_sep": "???");

  /* Form terminator */
  term.size  = 0;
  term.class = (char) class;

  /* For each case, check space and put data */
  switch (class)
  { case draw_undo__major:
    { undo_major m;

      if ((space_ok = draw_undo__checkspace (u, sizeof m)) != FALSE)
      {
        #if 1
          if (u->start != -1)
          { ftracef1 ("next field of major structure at offset %d\n",
                u->start);
            *int_pointer (u, u->start) = u->head;
          }
        #elif 0
          if (*int_pointer (u, u->start) == -1)
            *int_pointer (u, u->start) = u->head;
        #else
          *int_pointer (u, u->start != -1? u->start: 0) = u->head;
              /*JRC 25 June 1991 Seemed like a good idea*/
        #endif

        term.size  = sizeof m;
        m.next     = -1;
        u->start   = u->head;
        draw_undo__putdata (u, (char *) &m, &term);
      }
    }
    break;

    case draw_undo__undo_sep:
      if ((space_ok = draw_undo__checkspace (u, 0)) != FALSE)
      { term.size = data;
        draw_undo__putdata (u, NULL, &term);
      }
    break;

    case draw_undo__changestate:
    { undo_changestate c;

      if ((space_ok = draw_undo__checkspace (u, sizeof c)) != FALSE)
      { term.size = sizeof c;
        c.state   = diag->misc->mainstate;
        c.options = diag->misc->options;
        draw_undo__putdata (u, (char *) &c, &term);
      }
    }
    break;

    case draw_undo__trans:
    { draw_undo_trans t;

      if ((space_ok = draw_undo__checkspace (u, sizeof t)) != FALSE)
      { term.size = sizeof t;
        t = *(draw_undo_trans *) data;
        draw_undo__putdata (u, (char *) &t, &term);
      }
    }
    break;

    case draw_undo__rotate:
    { draw_undo_rotate r;

      if ((space_ok = draw_undo__checkspace (u, sizeof r)) != FALSE)
      { term.size = sizeof r;
        r = *(draw_undo_rotate *) data;
        draw_undo__putdata (u, (char *) &r, &term);
      }
    }
    break;

    case draw_undo__object:
    case draw_undo__delete:
      if (data1 != 0) /* Only bother for non zero size */
      { ftracef2 ("object at offset %d, size %d\n", abs (data), data1);
        space_ok = put_blocks (u, diag->paper + abs (data), data1, data,
            &term);
      }
    break;

    case draw_undo__insert:
      if (data1 != 0) /*Only bother for non zero size*/
      { undo_insert i;

        if ((space_ok = draw_undo__checkspace (u, sizeof i)) != FALSE)
        { ftracef2 ("object at offset %d, size %d\n", data, data1);
          term.size = sizeof i;
          i.nbytes = data1;
          i.offset = data;
          draw_undo__putdata (u, (char *) &i, &term);
        }
      }
    break;

    case draw_undo__select:
      FTRACEF2 ("draw_undo_put: select with data %d data1 %d\n",
          data, data1);
      if (data1 < 0) data = data == 0? -1: -data;

      if ((space_ok = draw_undo__checkspace (u, sizeof (int))) != FALSE)
      { term.size = sizeof (int);
        draw_undo__putdata (u, (char *) &data, &term);
      }
    break;

    case draw_undo__sel_array:
    case draw_undo__sel_array_no:
    { int size = data*sizeof (int);

      FTRACEF1 ("draw_undo_put: put sel_array with data %d\n", data);
      if ((space_ok = draw_undo__checkspace (u, size)) != FALSE)
      { term.size = size;
        draw_undo__putdata (u, (char *) data1, &term);
      }
    }
    break;

    case draw_undo__redraw:
    { int size = sizeof (draw_bboxtyp);

      /* Write the box */
      FTRACEF0 ("draw_undo_put: for redraw\n");
      if ((space_ok = draw_undo__checkspace (u, size)) != FALSE)
      { term.size = size;
        draw_undo__putdata (u, (char *) data, &term);
      }
    }
    break;

    #if 0
      case draw_undo__info:
      { undo_info_flag flag;
        int namelen = 0;

        FTRACEF3 ("draw_undo_put: info: modified %s, name change %s, "
            "name \"%s\"\n", whether (data), whether (data1 != -1),
            data1 == NULL? "<untitled>":
            data1 == -1? "(same)": (char *) data1);

        flag.modified = data? 1: 0;
        flag.named = data1 != -1;
        namelen =
            flag.named? data1 == NULL? 0: strlen ((char *) data1)+4 & ~3: 0;

        if ((space_ok = draw_undo__checkspace (u, sizeof flag + namelen)) !=
            FALSE)
        { term.size = sizeof flag + namelen;
          draw_undo__putblock (u, (char *) &flag, sizeof flag);
          if (data1 != -1)
            draw_undo__putblock (u, (char *) data1, namelen);
          draw_undo__putdata (u, NULL, &term);
        }
      }
      break;
    #endif
  }

  /* Error check */
  if (!space_ok)
    /* Not enough space - set flag */
    u->full = 1;

  if (u->withinundo == 0)
  { /* If this update is generated outside an undo context then
    cancel any current chain of undos. */
    u->ptr = u->head;
  }
  FTRACEF1 ("draw_undo_put: completed (full %s)\n", whether (u->full));
}

/* -------- Extract operations. -------- */

static int draw_undo__count_ptr_to_tail (drawundo u, int ptr)
/* i.e. bytes still extractable.
   Extraction happens below the pointer, i.e. starts at head.
   ptr == tail => nothing left.
*/
{ ftracef0 ("draw_undo__count_ptr_to_tail\n");
  #if TRACE
    ftracef4 ("size %d, tail %d, ptr %d, head %d\n",
        u->size, u->tail, ptr, u->head);
    Assert_Within (u->size, u->tail, ptr, u->head);
  #endif

  return (ptr - u->tail + u->size)%u->size;
}

/* Get data starting at a given pointer */
static void draw_undo__getdata (drawundo u, int ptr, int nbytes, char *to)

{ int endspace;

  ftracef0 ("draw_undo__getdata\n");
  if (nbytes == 0) return;

  #if TRACE
    Assert_Within (u->size, u->tail, ptr, u->head);
    Assert_Outside (u->size, ptr, u->head, ptr + nbytes);
  #endif

  #if 1
    if ((endspace = u->size - ptr) >= nbytes)
      /*Can fetch in one lump*/
      memcpy (to, u->buf + ptr, nbytes);
    else
    { /*Take two goes.*/
      memcpy (to, u->buf + ptr, endspace);
      memcpy (to + endspace, u->buf, nbytes - endspace);
    }
  #else
    if (ptr < u->head)
      /*Get as one lump*/
      memcpy (to, u->buf + ptr, nbytes);
    else
    { /* Get in two parts */
      int part_size = u->size - ptr;

      if (nbytes < part_size)
        memcpy (to, u->buf + ptr, nbytes);
      else
      { memcpy (to, u->buf + ptr, part_size);
        memcpy ((char *)to + part_size, u->buf, nbytes - part_size);
      }
    }
  #endif
}

/* Get data ending at pointer and update pointer */
static BOOL draw_undo__extract (drawundo u, int nbytes, void *to)

{ ftracef0 ("draw_undo_extract\n");
  /*if (u->ptr == u->tail) return FALSE;*/

  if (draw_undo__count_ptr_to_tail (u, u->ptr) < nbytes)
    return FALSE;

  u->ptr = move_ptr (u, u->ptr, -nbytes);
  draw_undo__getdata (u, u->ptr, nbytes, to);
  return TRUE;
}

/* Get preceding character. This can be used to fetch the class */
static char draw_undo__classbefore (drawundo u, int p)

{ undo_term term;
  int       savedptr = u->ptr;

  ftracef0 ("draw_undo__classbefore\n");
  /* Assumed that extract will always work */
  u->ptr = p;
  if (!draw_undo__extract (u, sizeof term, &term))
    #if TRACE
      GENERATE ("extract failed in classbefore");
    #else
      ;
    #endif
  u->ptr = savedptr;
  return term.class;
}

/* ---------- Edit separator ---------- */
/* When we put a major separator, we also commit any undo in progress */
void draw_undo_separate_major_edits (diagrec *diag)

{ drawundo u = diag->undo;

  FTRACEF1 ("draw_undo_separate_major_edits: diag: 0x%X\n", diag);
  if (u->head != u->tail
      && draw_undo__classbefore (u, u->head) == draw_undo__major)
    /* already separated */
    FTRACEF0 ("draw_undo_separate_major_edits: already separated\n");
  else
  { /* If the full flag is set, first wipe the buffer */
    if (u->full) draw_undo__wipe (u);

    draw_undo_commit (diag);

    #if 0 /*Done in draw_undo_put(). JRC 25 June 1991*/
      if (u->start != -1)
        /*Set the next field of the major structure*/
        *int_pointer (u, u->start) = u->head;
    #endif

    draw_undo_put (diag, draw_undo__major, 0, 0);
  }
}
#if 0
void draw_undo_put_start_mod (diagrec *diag, int data1)

{ FTRACEF0 ("draw_undo_start_mod\n");
  draw_undo_separate_major_edits (diag);
  /*draw_undo_put (diag, draw_undo__info, diag->misc->options.modified,
      data1);*/
}
#endif
/* -------- Undo operations. -------- */
static int draw_undo__skipop (drawundo u, int p, draw_undo_class *class)
/* Skip past a complete recorded operation. Return its class if asked */

{ int  saveptr, result;
  undo_term term;

  ftracef0 ("draw_undo__skipop\n");
  saveptr = u->ptr;
  u->ptr  = p;

  if (!draw_undo__extract (u, sizeof term, &term))
    #if TRACE
      GENERATE ("extract failed in skipop");
    #else
      ;
    #endif

  result = move_ptr (u, u->ptr, -term.size);
  u->ptr = saveptr;
  if (class) *class = (draw_undo_class) term.class;

  return result;
}

/* Find the last major edit marker, and return the offset just to the left of
   it. Start with the object at last */
static int find_last_major (drawundo u, int last)

{ draw_undo_class class;

  ftracef0 ("draw_undo: find_last_major\n");
  while (last = draw_undo__skipop (u, last, &class),
      class != draw_undo__major)
    ;
  return last;
}

/* Redraw as many object as we can in a given range */
/* Always redraws one object, so obj_size can be (say) 0 for this */
/* In fact, this just accumulates the rectangles for redrawing */
/* If x0 > x1, we assume that the rectangle is not yet initialised */
static void undo__redraw (diagrec *diag, int offset, int obj_size,
                         draw_bboxtyp *rect)

{ int end = offset + obj_size;

  FTRACEF0 ("draw_undo: undo__redraw\n");
  /* Accumulate rectangles */
  do
  { draw_objptr hdrptr;
    hdrptr.bytep = diag->paper + offset;

    if (rect->x0 > rect->x1)
      *rect = *draw_displ_bbox (hdrptr);
    else
      draw_obj_unify (rect, draw_displ_bbox (hdrptr));

    offset += hdrptr.objhdrp->size;
  }
  while (offset < end);
}
#if 0 /*not used*/
void draw_undo_init (diagrec *diag)

{ drawundo u = diag->undo;
  FTRACEF0 ("draw_undo_init\n");
  u->ptr = u->head;
}
#endif
void draw_undo_commit (diagrec *diag)

{ drawundo u = diag->undo;
  FTRACEF4 ("draw_undo_commit: diag: 0x%X; diag->undo: 0x%X; "
      "diag->undo->ptr: %d: diag->undo->head: %d\n",
      diag, u, IND (u, ptr), IND (u, head));
  u->head = u->ptr;
}

/* Main part of undo code - undoes one operation */
static drawundo_result undo_undo (diagrec *diag, draw_bboxtyp *redraw_rect)

{ drawundo  u = diag->undo;
  int       saveptr = u->ptr;
  undo_term term;
  BOOL      ranout = FALSE;
  drawundo_result result = drawundo_MINOR;

  FTRACEF0 ("draw_undo: undo_undo\n");
  if (!draw_undo__extract (u, sizeof term, &term)) return drawundo_RANOUT;
  FTRACEF4 ("draw_undo: undo_undo class %d headp %d ptr %d tail %d\n",
      term.class, u->head, u->ptr+sizeof term, u->tail);

  ftracef1 ("draw_undo: undo_undo undoing %s\n", term.class == draw_undo__major? "draw_undo__major":
      term.class == draw_undo__changestate? "draw_undo__changestate": term.class == draw_undo__trans?
      "draw_undo__trans": term.class == draw_undo__rotate? "draw_undo__rotate": term.class
      == draw_undo__object? "draw_undo__object": term.class == draw_undo__insert? "draw_undo__insert":
      term.class == draw_undo__delete? "draw_undo__delete": term.class == draw_undo__select?
      "draw_undo__select": term.class == draw_undo__sel_array? "draw_undo__sel_array":
      term.class == draw_undo__sel_array_no? "draw_undo__sel_array_no": term.class == draw_undo__redraw?
      "draw_undo__redraw": term.class == draw_undo__info? "draw_undo__info": term.class == draw_undo__undo_sep? "draw_undo__undo_sep": "???");

  /* u->ptr now points to end of actual data block. Examine class */
  switch (term.class)
  { case draw_undo__major:
    { undo_major m;

      result = drawundo_MAJOR;

      if (!draw_undo__extract (u, sizeof m, &m))
        ranout = TRUE;
      break;
    }

    case draw_undo__changestate:
    { undo_changestate c;

      if (draw_undo__extract (u, sizeof c, &c))
        draw_action_changestate (diag, c.state, c.options.curved,
                                               c.options.closed, FALSE);
      else ranout = TRUE;
      break;
    }

    case draw_undo__trans:
    { draw_undo_trans t;
      if (draw_undo__extract (u, sizeof t, &t))
      { t.t.dx = -t.t.dx;
        t.t.dy = -t.t.dy;
        draw_trans_translate (diag, t.start, t.end, &t.t);
      }
      else ranout = TRUE;
      break;
    }

    case draw_undo__rotate:
    { draw_undo_rotate r;
      if (draw_undo__extract (u, sizeof r, &r))
      { r.sin_theta = -r.sin_theta;
        draw_trans_rotate (diag, r.start, r.end,
                          (draw_trans_rotate_str *)&r.sin_theta);
      }
      else ranout = TRUE;
      break;
    }

    case draw_undo__object:
    { int data;

      /* Reload the data into the diagram */
      if (draw_undo__extract (u, sizeof data, &data))
      { int offset   = abs (data);
        int obj_size = term.size - sizeof offset;

        /* Put opposite for redoing */
        draw_undo_put (diag, draw_undo__object, data, obj_size);

        /* Redraw range of objects */
        if (data >= 0) undo__redraw (diag, offset, obj_size, redraw_rect);

        if (draw_undo__extract (u, obj_size, diag->paper + offset))
        { /* Redraw range of objects again in case of bbox change */
          if (data >= 0) undo__redraw (diag, offset, obj_size, redraw_rect);

          /* Ensure modified flag is correct */
          /* FTRACEF0 ("== undo__object setting modified\n");
          draw_modified_no_undo (diag);*/

          break;
        }
      }
      ranout = TRUE;
      break;
    }

    case draw_undo__insert:
    { undo_insert i;

      if (draw_undo__extract (u, sizeof i, &i))
      { FTRACEF2 ("draw_undo: undo_undo insert with offset %d size %d\n",
            i.offset, i.nbytes);
        /* Put delete for undoing */
        draw_undo_put (diag, draw_undo__delete, i.offset, i.nbytes);

        /* Redraw objects */
        if (i.offset >= 0)
          undo__redraw (diag, i.offset, i.nbytes, redraw_rect);

        /* Delete data from diagram */
        draw_obj_losespace (diag, abs (i.offset), i.nbytes);

        /* Ensure modified flag is correct */
        /* FTRACEF0 ("== undo__insert setting modified\n");
        draw_modified_no_undo (diag);*/
      }
      else ranout = TRUE;
      break;
    }

    case draw_undo__delete:
    { int data;

      if (draw_undo__extract (u, sizeof data, &data))
      { int obj_size = term.size - sizeof data;
        int offset   = abs (data);

        FTRACEF2 ("draw_undo: undo_undo delete at %d of size %d\n",
            data, obj_size);
        /* Put insert for undoing */
        draw_undo_put (diag, draw_undo__insert, data, obj_size);

        /* Insert data into diagram */
        if (draw_obj_makespace (diag, offset, obj_size) == 0
            && draw_undo__extract (u, obj_size, diag->paper + offset))
        { /* Redraw objects */
          undo__redraw (diag, offset, obj_size, redraw_rect);

          /* Ensure modified flag is correct */
          /* FTRACEF0 ("== undo__delete setting modified\n");
          draw_modified_no_undo (diag);*/

          break;
        }
      }
      ranout = TRUE;
      break;
    }

    case draw_undo__select:
    { int offset;

      if (draw_undo__extract (u, sizeof offset, &offset))
      { if (offset >= 0)
        { FTRACEF1 ("draw_undo: undo_undo select: offset %d (deselect)\n",
              offset);
          draw_deselect_object (diag, offset);
          break;
        }
        else
        { FTRACEF1 ("draw_undo: undo_undo select: offset %d (select)\n",
              offset);
          if (draw_select_object (diag, (offset == -1) ? 0 : -offset) == 0)
            break;
        }
      }
      ranout = TRUE;
    }
    break;

    case draw_undo__sel_array:
    case draw_undo__sel_array_no:
    { int entries = term.size / sizeof (int);
      BOOL redraw = term.class == draw_undo__sel_array;

      FTRACEF1 ("draw_undo: undo_undo sel array with %d entries\n",
          entries);
      /* Put current array */
      draw_select_put_array (diag, redraw);

      /* Erase current array */
      if (redraw) draw_displ_eor_bboxes (diag);

      /* Get space for array */
      while (draw_selection->limit < entries && !draw_select_checkspace ())
        ;

      /* Recover array */
      if (draw_selection->limit >= entries
          && draw_undo__extract (u, term.size, draw_selection->array))
      { /* Repaint it */
          draw_selection->indx = entries;
        if (redraw) draw_displ_eor_bboxes (diag);
        break;
      }
      ranout = TRUE;
    }
    break;

    case draw_undo__redraw:
    { draw_bboxtyp box;

      /* Queue the redraw and rewrite the box */
      if (draw_undo__extract (u, sizeof box, &box))
      { FTRACEF0 ("draw_undo: undo_undo a redraw\n");
        /* Put delete for undoing */
        draw_undo_put (diag, draw_undo__redraw, (int) &box, 0);

        /* Redraw area */
        draw_displ_redrawarea (diag, &box);
      }
      else ranout = TRUE;
      break;
    }

    #if 0
      case draw_undo__info:
      { undo_info i;

        if (draw_undo__extract (u, term.size, &i))
        { FTRACEF3
              ("draw_undo: restoring: modified %s, named %s, name \"%s\"\n",
              whether (i.flag.modified),
              whether (i.flag.named),
              i.flag.named? i.name: "(same)");

          /* Put current values for redo */
          draw_undo_put (diag, draw_undo__info,
              diag->misc->options.modified,
              i.flag.named? diag->misc->filename [0] != '\0'?
              (int) diag->misc->filename: NULL: -1);

          diag->misc->options.modified = i.flag.modified;
          if (i.flag.named)
            strcpy (diag->misc->filename, i.name);
          /*else
            diag->misc->filename [0] = '\0'; JRC*/

          draw_displ_redrawtitle (diag);
        }
        else
          ranout = TRUE;
      }
      break;
    #endif
  }


  if (ranout)
  { u->ptr = saveptr;
    FTRACEF1 ("draw_undo: undo_undo returns %d (ranout)\n",
        drawundo_RANOUT);
    return drawundo_RANOUT;
  }
  else
  { FTRACEF1 ("draw_undo: undo_undo returns %d\n", result);
    return result;
  }
}

/* Finish redraw in undoing */
static void finish_redraw (diagrec *diag, draw_bboxtyp *redraw_rect)

{ FTRACEF0 ("draw_undo: finish_redraw\n");
  if (redraw_rect->x1 >= redraw_rect->x0)
    draw_displ_redrawarea (diag, redraw_rect);
}

/* Undo an operation until we reach the major separator */
drawundo_result draw_undo_undo (diagrec *diag)

{ drawundo_result result;
  drawundo u = diag->undo;
  int head = u->head; /* Where the undo put starts */
  draw_bboxtyp redraw_rect;

  FTRACEF0 ("draw_undo_undo\n");
  /* Find where the major separator is */
  u->start = find_last_major (u, u->ptr);

  /* Fill in the next field, if not already set. This is needed, because
     redo makes use of it */
  if (*int_pointer (u, u->start) == -1)
    *int_pointer (u, u->start) = u->head;

  FTRACEF2 ("draw_undo_undo: start of undo with head %d start %d\n",
      head, u->start);
  /* If we are entering, cancel current action instead of undoing */
  if (diag->misc->mainstate != diag->misc->substate)
  { draw_action_abandon (diag);
    return drawundo_MAJOR;
  }

  u->withinundo = 1;

  /* Initialise redraw box */
  redraw_rect.x1 = 0;
  redraw_rect.x0 = 1; /* Anything with x0 > x1 */

  /* Undo until we hit a major separator or until we run out */
  while ((result = undo_undo (diag, &redraw_rect)) == drawundo_MINOR)
    ;

  /* If buffer is full, wipe it */
  if (u->full)
    draw_undo__wipe (u);
  else
    /* Write separator for redo */
    draw_undo_put (diag, draw_undo__undo_sep, head, 0);

  u->withinundo = 0;
  u->start = -1;
  FTRACEF1 ("draw_undo_undo: returns %d\n", result);
  finish_redraw (diag, &redraw_rect);
  return result;
}


/* -------- Redo operations. -------- */

/* Redo: head points to what we want to start redoing */
/* On exit, head has been reduced to the end of the data put by the undo it
   is reversing, and ptr has been advanced over what we redid, so that the
   next undo gets it again. We do the first by using the size field in the
   draw_undo__undo_sep to find the start of the data put in the undo, and the
   latter by using the next field in the major separator. We return that we
   have run out of redo if, at the end, the two are the same.
*/

drawundo_result draw_undo_redo (diagrec *diag)

{ drawundo  u = diag->undo;
  undo_term term;
  int       savedptr = u->ptr;
  int       limit;
  drawundo_result res;
  draw_bboxtyp    redraw_rect;

  FTRACEF0 ("draw_undo_redo\n");
  /* Initialise redraw box */
  redraw_rect.x1 = 0;
  redraw_rect.x0 = 1; /* Anything with x0 > x1 */

  /* Find where redo is to stop */
  u->ptr = u->head;
  if (draw_undo__extract (u, sizeof term, &term))
  { u->withinundo = 1;

    limit = term.size;

    /* Redo until pointer reaches end */
    while (u->ptr != limit)
    { /* Call undo for one step only */
      if (res = undo_undo (diag, &redraw_rect), res == drawundo_RANOUT) break;
    }

    /* If buffer is full, wipe it */
    if (u->full)
      draw_undo__wipe (u);
    else
    { /* Reset head */
      u->head = limit;

      /* There is a major separator just to the right of the saved pointer.
         We use the next field of this separator to find where the record ends
       */
      u->ptr = *int_pointer (u, savedptr);

      if (u->ptr == -1) /* Record was not complete, and hence last one */
        u->ptr = u->head;
    }

    u->withinundo = 0;
    FTRACEF2 ("draw_undo_redo: head %d => return %d\n",
        u->head, (u->ptr == u->head) ? drawundo_RANOUT : drawundo_MAJOR);
    finish_redraw (diag, &redraw_rect);
    return (u->ptr == u->head) ? drawundo_RANOUT : drawundo_MAJOR;
  }

  finish_redraw (diag, &redraw_rect);
  return drawundo_RANOUT; /* Extract failed */
}

/*---------------------------------------------*/
#if 0 /*not used*/
/* Unwind back to the start of the last major edit */
void draw_undo_put_unwind (diagrec *diag)

{ drawundo u = diag->undo;

  FTRACEF0 ("draw_undo_put_unwind\n");
  u->head = find_last_major (u, u->head);
}
#endif
/*---------------------------------------------*/

/* Undo is permitted only we are not editing or zooming, and either we are
   entering an object, or there is space in the buffer.

   Redo is permitted if there are any entries placed by undo, and the buffer
   is not full.
*/

BOOL draw_undo_may_undo (diagrec *diag, BOOL *redo)

{ drawundo u = diag->undo;

  FTRACEF0 ("draw_undo_may_undo\n");

  /* May not undo or redo during editing or zooming */
  if (diag->misc->mainstate == state_edit ||
      diag->misc->mainstate == state_zoom ||
      /*May never undo or redo if entering an object. JRC 4 Oct 1990 */
      diag->misc->mainstate != diag->misc->substate)
  { *redo = FALSE;
    return FALSE;
  }
  else
  { /*May redo if buffer has not run out*/
    FTRACEF3 ("draw_undo_may_undo: redo? full %s, empty %s, redo size %d\n",
        whether (u->full),
        whether (u->head == u->tail),
        u->head - u->ptr);
    #ifdef XTRACE
      ftracef3 ("... (head %d, tail %d, ptr %d\n",
          u->head, u->tail, u->ptr);
    #endif
    *redo = !u->full && u->head != u->tail &&
        (u->head - u->ptr + u->size)%u->size > 12;

    /*May undo if there is something in the undo buffer and it is not full*/
    ftracef3 ("draw_undo_may_undo: undo? full %s, empty %s, undo size %d\n",
       whether (u->full),
       whether (u->head == u->tail),
       u->ptr - u->tail);
    ftracef2 ("may redo: %s, may undo: %s\n", whether (*redo),
        whether (!u->full && u->head != u->tail &&
        (u->ptr - u->tail + u->size)%u->size > 12));
    return !u->full && u->head != u->tail &&
        (u->ptr - u->tail + u->size)%u->size > 12;
  }
}
