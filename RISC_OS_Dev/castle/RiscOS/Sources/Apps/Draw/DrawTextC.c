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
/* -> c.DrawTextC
 *
 * Text area/column object handling
 * Author: David Elworthy
 * Version: 0.67
 * History: 0.10 - 19 July 1988 - created
 *          0.20 - 29 July 1988 - font verification
 *          0.30 -  1 Aug  1988 - text column areas
 *          0.31 -  8 Aug  1988 - RAM transfers
 *          0.40 -  9 Aug  1988 - hyphens, extra space in objects, IDs
 *          0.41 - 10 Aug  1988 - background colours, line breaks, font
 *                                widths
 *          0.42 - 12 Aug  1988 - various bug fixes, source level clipping
 *          0.50 - 15 Aug  1988 - the great name change
 *          0.51 - 16 Aug  1988 - hyphen changes, margins,
 *                                positive termination,
 *                                miscellaneous cleaning
 *          0.52 - 23 Aug  1988 - special case for start of paragraph,
 *                                conversion to flex
 *          0.53 - 26 Aug  1988 - standard header
 *          0.54 -  1 Sept 1988 - delete old object
 *          0.55 - 19 Oct  1988 - return errors in do_objtextcol &
 *                                do_objtextarea to caller
 *          0.60 - 10 Nov  1988 - changes to state setting code
 *          0.61 - 25 Nov  1988 - better recovery on running out ot memory
 *          0.62 - 30 Nov  1988 - dispose of flex block if loadfile() fails
 *          0.63 - 12 June 1989 - old code weeded. Header tidied.
 *                                upgraded to colourtran.
 *                 16 June 1989 - upgraded to msgs
 *          0.64 - 20 June 1989 - rehacked file load code
 *          0.65 - 23 June 1989 - bug fixes and name changes
 *          0.66 - 10 July 1989 - scale, rotate, translate, restyle moved out
 *                 14 July 1989 - also file I/O stuff
 *                 17 July 1989 - underlining bug fixed
 *          0.67 - 12 Sept 1989 - bug with wrong initial font; also bug fixed
 *                                in chunk length calculation
 *
 * To handle errors, we do a prescan just after the file has been loaded to
 * check that all special sequences are valid. Errors are reported at this
 * stage. During rendering, errors that could not be trapped earlier are
 * passed back up as far as possible.
 *
 * Fonts: when the file is being verified, we make sure that there is at least
 * one font that can be loaded, and report and error if there is not. The
 * handle for this font is used as the default, and also for sections where the
 * font is unrecognised.
 *
 * When reading text, we must create a temporary store so that we can verify it
 * and find the number of columns. There is thus a short term overhead of
 * memory equal to the size of the text file.
 *
 * To get the underlining and vertical move state at the start of each output
 * line, some extra control sequences have to be inserted: this leads to some
 * horrible code, but I can't see how to get round it.
 */
#ifndef USE_TRUE_COLOUR
  #define USE_TRUE_COLOUR TRUE
#endif
#define TRACE_GS FALSE

#include <ctype.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <swis.h>

#include "os.h"
#include "bbc.h"
#include "flex.h"
#include "font.h"
#include "wimp.h"
#include "wimpt.h"
#include "werr.h"
#include "colourtran.h"
#include "msgs.h"
#include "xferrecv.h"
#include "drawmod.h"
#include "jpeg.h"
#include "dbox.h"
#include "menu.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawAction.h"
#include "DrawDispl.h"
#include "DrawObject.h"
#include "DrawFileIO.h"
#include "DrawMenu.h"
#include "DrawSelect.h"
#include "DrawTextC.h"

#if TRACE
  /*#define XTRACE for extended tracing*/
#endif

/*--------------------Macros, types, and globals -------------------------*/
#define strnul(s) ((s) [0] == '\0')

static BOOL Started_Printing; /*used to suppress leading newlines in the
                                text area. J R C 18 June 1991*/

static int scaleup (int xx)

{ return (int) (xx*draw_displ_scalefactor);
}

static int scaleupO (int xx, int org)

{ return (int) (org + xx*draw_displ_scalefactor);
}

#define scaleupX(xx) scaleupO (xx, orgx)
#define scaleupY(yy) scaleupO (yy, orgy)

/* Symbolic values for text alignment */
typedef enum {alignLeft, alignRight, alignCentre, alignDouble} draw_align;

#define draw_text_maxFonts 99

/* Default sizes of a text area */
#define draw_textarea_HEIGHT (dbc_OneInch + dbc_HalfInch)
#define draw_textarea_WIDTH  (dbc_OneInch + dbc_HalfInch)

/* Extra separation between areas */
#define draw_textarea_SEPARATION (dbc_QuarterInch)

/* Extra size used in forming parent bbox */
#define draw_textarea_BORDERX (dbc_FifthInch)
#define draw_textarea_BORDERY (dbc_FifthInch)

/* Font usage counter - more convenient for this to be global */
static int draw_usedFont [256];

/* Symbolic codes for font manager operations */
#define draw_font_vmove     11
#define draw_font_colour    18
#define draw_font_true_colour \
                            19 /*J R C 22 Nov '89*/
#define draw_font_comment   21
#define draw_font_underline 25
#define draw_font_setfont   26

/* Total length of underline and vmove sequences */
#define draw_insert 7

/* Structure representing the parameter state at the start of an output line */
typedef struct
{ int        leading, paraLeading;  /* In font units */
  int        lmargin, rmargin;      /* In font units */
  font       defaultFont;
  int        under1, under2;
  int        vmove;
  draw_align align;
} draw_linedata;

/* Line number used in reporting */
static int lineNum;

/* Macro for matching terminators */
#ifdef XTRACE
   #define isTerm(c) (ftracef0 ("isTerm\n"), (c) == '\n' || (c) == '/')
#else
   #define isTerm(c) ((c) == '\n' || (c) == '/')
#endif

/*Function for matching separators*/
static BOOL isSep (int c)

{
  #ifdef XTRACE
    ftracef0 ("isSep\n");
  #endif
  return c == ' ' || c == '\t'; /*J R C 24th Jul 1995*/
}

/* Globals used for address and maximum length of current chunk */
static char *chunk;
static int  chunkLen;

#define draw_bigvalue (1 << 28)  /* A large positive value */

/* Standard header: used if the gumby fails to give us one */
char *draw_text_header =
"\\! 1\n\\F 0 Trinity.Medium 12\n\\F 1 Corpus.Medium 12\n\\0\\AD/\\L12\n";

/*
 Function    : draw_text_findParent
 Purpose     : find the parent of a text column
 Parameters  : pointer to text area column (as an column pointer)
 Returns     : object pointer
 Description : looks backwards in steps of the size of the header until it
               finds the parent tag.
*/

draw_objptr draw_text_findParent (draw_textcolhdr *from)

{ draw_objptr parent;

  ftracef0 ("draw_text_findParent\n");
  while (from->tag == draw_OBJTEXTCOL) from -= 1;
  parent.textcolp = from;               /* Minor type fiddle here */
  return (parent);
}

/*
 Function    : draw_text_findEnd
 Purpose     : find end section of a text area
 Parameters  : header pointer
 Returns     : pointer to end section
 Description : skips over the columns and returns a pointer to the end object
*/

draw_textareaend *draw_text_findEnd (draw_objptr hdrptr)

{ draw_textcolhdr *column = &hdrptr.textareastrp->column;

  ftracef0 ("draw_text_findEnd\n");
  while (column->tag == draw_OBJTEXTCOL) column++;
  return (draw_textareaend *) column;
}
#if 0
/*
 Function    : draw_text_getFontNum
 Purpose     : get a one or two digit font number
 Parameters  : pointer to string
               OUT: font number
 Returns     : pointer to next character
 Description : read either one or two characters are forms a font number
               from them. Returns -1 if the number is too high or if there
               are no digits in the string.
*/

static char *draw_text_getFontNum (char *text, int *fontNumber)

{ int num = draw_text_maxFonts+1;  /* Forces an error if bad number */

  ftracef0 ("draw_text_getFontNum\n");
  if (isdigit (*text))
  { num = *text++ - '0';
    if (isdigit (*text)) num = num*10 + *text++ - '0';
  }

  *fontNumber = num <= draw_text_maxFonts? num: -1;
  if (*text == '/') text++;
  return (text);
}
#endif
/*
 Function    : draw_getNum
 Purpose     : get an integer out of a string
 Parameters  : offset into string
               pointer to string
               pointer to int (NULL -> no assignment)
               flag: TRUE if negative numbers are allowed
               flag: TRUE if the terminator must be present
         OUT : updated offset
 Returns     : termination code (see below)
 Description : skip leading space; read an integer; find terminator (if
               required). Sets the termination code on the basis of what was
               read, as follows:

               OK: number read ok, terminator was <spaces>\n or <spaces>/,
                   or no terminator required. Output pointer is character
                   after terminator)
               BAD: no number could be read, or invalid terminator
               MORE: number read ok, terminator was another digit
                              (output pointer points to digit)
               The string is accessed via offsets to avoid flex block
               problems.
*/

#define draw_numOK   0
#define draw_numBAD  1
#define draw_numMORE 2

static int draw_getNum (int from, char *base, int *to, BOOL negative,
    BOOL terminate, int *rest)

{ int r;
  long int l;
  char *end;

  #if TRACE
    ftracef (__FILE__, __LINE__,
        "draw_getNum (\"%.10s...\"): from %d, to 0x%X, -ve %s, "
        "terminate %s, rest 0x%X\n",
        &base [from], from, to, whether (negative),
        whether (terminate), rest);
  #endif
  /*Skip leading spaces*/
  while (isSep (base [from])) from++;

  /*Skip leading minus and digits*/
  if (isdigit (base [from]))
    r = from;
  else if (negative && base [from] == '-')
    r = from + 1;
  else
  { ftracef0 ("draw_getNum -> draw_numBAD\n");
    return draw_numBAD;
  }
  while (isdigit (base [r])) r++;

  /*Get the value*/
  l = strtol (&base [from], &end, 10);
  ftracef1 ("Read %ld\n", l);

  if (r == from || end == &base [from] || l == LONG_MAX || l == LONG_MIN)
  { ftracef0 ("draw_getNum -> draw_numBAD\n");
    return draw_numBAD;
  }
  if (to != NULL) *to = (int) l;

  if (!terminate)
  { if (base [r] == '/')
      /*Termination is allowed, just not compulsory.*/
      *rest = r + 1;
    else
      *rest = r;
    ftracef1 ("draw_getNum -> draw_numOK, next \'%c\'\n",
        base [*rest]);
    return draw_numOK;
  }
  else
  { /*Skip trailing spaces*/
    while (isSep (base [r])) r++;

    if (isdigit (base [r]))
    { *rest = r;
      ftracef1 ("draw_getNum -> draw_numMORE, next \'%c\'\n",
        base [*rest]);
      return draw_numMORE;
    }
    else if (negative && base [r] == '-')
    { *rest = r;
      ftracef1 ("draw_getNum -> -ve draw_numMORE, next \'%c\'\n",
        base [*rest]);
      return draw_numMORE;
    }
    else if (isTerm (base [r]))
    { *rest = r + 1;
      ftracef1 ("draw_getNum -> draw_numOK, next \'%c\'\n",
        base [*rest]);
      return draw_numOK;
    }
    else
    { ftracef0 ("draw_getNum -> draw_numBAD\n");
      return draw_numBAD;
    }
  }
}

/*
 Function    : draw_getFloat
 Purpose     : get a float out of a string
 Parameters  : offset into string
               pointer to string
               pointer to double (NULL -> no assignment)
               flag: TRUE if negative numbers are allowed
               flag: TRUE if the terminator must be present
         OUT : updated offset
 Returns     : termination code (see below)
 Description : skip leading space; read a float; find terminator (if
               required). Sets the termination code on the basis of what was
               read, as follows:

               OK: number read ok, terminator was <spaces>\n or <spaces>/,
                   or no terminator required. Output pointer is character
                   after terminator)
               BAD: no number could be read, or invalid terminator
               MORE: number read ok, terminator was another digit
                              (output pointer points to digit)
               The string is accessed via offsets to avoid flex block
               problems.
*/

static int draw_getFloat (int from, char *base, double *to, BOOL negative,
    BOOL terminate, int *rest)

{ int r;
  double d;
  char *end;

  #if TRACE
    ftracef (__FILE__, __LINE__,
        "draw_getFloat (\"%.10s...\"): from %d, to 0x%X, -ve %s, "
        "terminate %s, rest 0x%X\n",
        &base [from], from, to, whether (negative),
        whether (terminate), rest);
  #endif
  /*Skip leading spaces*/
  while (isSep (base [from])) from++;

  /*Skip leading minus and digits (and .)*/
  if (isdigit (base [from]) || base [from] == '.')
    r = from;
  else if (negative && base [from] == '-')
    r = from + 1;
  else
  { ftracef0 ("draw_getFloat -> draw_numBAD\n");
    return draw_numBAD;
  }
  while (isdigit (base [r]) || base [r] == '.') r++;

  /*Get the value*/
  d = strtod (&base [from], &end);
  ftracef1 ("Read %f\n", d);

  if (r == from || end == &base [from] || d == HUGE_VAL || d == -HUGE_VAL)
  { ftracef0 ("draw_getFloat -> draw_numBAD\n");
    return draw_numBAD;
  }
  if (to != NULL) *to = d;

  if (!terminate)
  { if (base [r] == '/')
      /*Termination is allowed, just not compulsory.*/
      *rest = r + 1;
    else
      *rest = r;
    ftracef1 ("draw_getFloat -> draw_numOK, next \'%c\'\n",
        base [*rest]);
    return draw_numOK;
  }
  else
  { /*Skip trailing spaces*/
    while (isSep (base [r])) r++;

    if (isdigit (base [r]))
    { *rest = r;
      ftracef1 ("draw_getFloat -> draw_numMORE, next \'%c\'\n",
        base [*rest]);
      return draw_numMORE;
    }
    else if (isTerm (base [r]))
    { *rest = r + 1;
      ftracef1 ("draw_getFloat -> draw_numOK, next \'%c\'\n",
        base [*rest]);
      return draw_numOK;
    }
    else
    { ftracef0 ("draw_getFloat -> draw_numBAD\n");
      return draw_numBAD;
    }
  }
}

/*
 Function    : draw_text_setFont
 Purpose     : locate and record font
 Parameters  : pointer to start of font definition sequence
               pointer to fonts array
               flag: TRUE = whinge on missing font
               OUT: font handle (-1 if we failed)
 Returns     : new input pointer (character after newline)
 Description : this is used to handle the font definition sequence. The input
               has the form:
                <digit*><name><space><pointsize><newline>.
               or:
                <digit*><name><space><pointsize><space><pointwidth><newline>.

               This routine can also be called during verification, since we
               try to make sure that there is at least one valid font. Since
               this can happen before any scalefactor is set up, for a drop
               onto the icon bar, if the scalefactor is 0, we pretend it is
               1.
*/

static char *draw_text_setFont (char *in, font *fonts, BOOL whinge,
    int *handle)

  /*Check the font defn line at *in. If fonts != NULL, fill in
    fonts [font number] with the font handle, increment
    draw_usedFont [handle], and return the handle in *handle. Otherwise,
    look up the font name in draw_fontcat and return its entry number.*/

{ int fontNumber, end, scaleSize, scaleWidth;
  double pointSize, pointWidth;
  char *name, displaced;
  os_error *err;
  font fontHandle;

  ftracef0 ("draw_text_setFont\n");
  *handle = -1;

  /* Get font number */
  while (isSep (*in)) in++;
  /*in = draw_text_getFontNum (in, &fontNumber);*/
  ftracef0 ("calling draw_getNum()\n");
  if (!(draw_getNum (0, in, &fontNumber, FALSE, FALSE, &end) ==
      draw_numOK && fontNumber <= draw_text_maxFonts))
    fontNumber = -1;
  in += end;

  /* Skip leading spaces in font name */
  while (isSep (*in)) in++;

  /* Find end of font name */
  for (name = in; !isSep (*in); in++)
    ;
  displaced = *in;
  *in = '\0';

  /* Get point size, and maybe width */
  ftracef0 ("calling draw_getFloat()\n");
  if (draw_getFloat (1, in, &pointSize, FALSE, TRUE, &end) == draw_numMORE)
  { ftracef0 ("calling draw_getFloat() again\n");
    draw_getFloat (end, in, &pointWidth, FALSE, TRUE, &end);
  }
  else
    pointWidth = pointSize;

  if (fontNumber == -1)
  { /*Bad font number - give up completely.*/
    *handle = 0;
    if (whinge) werr (FALSE, msgs_lookup ("TextF5"));
  }
  else if (fonts != NULL)
  { /*Find sizes at current scaling*/
    if (draw_displ_scalefactor == 0.0)
      scaleSize  = (int) (16*pointSize), scaleWidth = (int) (16*pointWidth);
    else
      scaleSize  = (int) (16*draw_displ_scalefactor*pointSize),
      scaleWidth = (int) (16*draw_displ_scalefactor*pointWidth);

    ftracef5 ("draw_text_setFont: name \"%.*s%s\", width %d, height %d\n",
        16, name, strlen (name) > 16? "...": "",
        scaleWidth, scaleSize);
    if (strlen (name) < 256 && (err = font_find (name, scaleWidth,
        scaleSize, 0, 0, &fontHandle)) == NULL && fontHandle != 0)
    { ftracef2
          ("draw_text_setFont: recording font handle %d in 'fonts [%d]'\n",
          fontHandle, fontNumber);
      fonts [fontNumber] = fontHandle;

      ftracef1 ("draw_text_setFont: writing handle to address 0x%X\n",
          handle);
      draw_usedFont [*handle = fontHandle]++;
    }
    else
    { ftracef1 ("draw_text_setFont: clearing 'fonts [%d]'\n", fontNumber);
      fonts [fontNumber] = -1;
      if (whinge) werr (FALSE, msgs_lookup ("TextL1"), name);
    }
  }
  else
    *handle = draw_menu_addfonttypeentry (name);

  *in = displaced;
  return in + end;
}

/*
 Function    : draw_text_setColour
 Purpose     : set colour for a given r, g, b value
 Parameters  : r, g, b intensities (as a palette entry, i.e. BBGGRRxx)
               (foreground and background)
 Returns     : void
 Description : selects the best colour for the given font and rgb values.
*/

static void  draw_text_setColour (int colour, int backcolour)

{ font fonth  = 0; /*was -1 J R C 23 Nov '89*/
  int  offset = 14;

  ftracef2 ("draw_text_setColour: colour: 0x%X; backcolour: 0x%X\n",
      colour, backcolour);
  colourtran_setfontcolours (&fonth, (wimp_paletteword *) &backcolour,
      (wimp_paletteword *) &colour, &offset);
}

/*
 Function    : draw_text_setup_colour
 Purpose     : set a gcol for a given r, g, b value
 Parameters  : r, g, b intensities (as a palette entry, i.e. BBGGRRxx)
               (foreground and background)
               offset into string to place colour sequence at
 Returns     : void
 Description : finds the best gcol value for text, and puts this into a colour
               change sequence in the string
*/

static void draw_text_setup_colour (int colour, int backcolour, int out)

{ int offset = 14;

  ftracef0 ("draw_text_setup_colour\n");
  #if !USE_TRUE_COLOUR
    font fonth  = -1;

    ftracef2 ("draw_text_setup_colour: colour: 0x%X; backcolour: 0x%X\n",
        colour, backcolour);
    colourtran_returnfontcolours (&fonth, (wimp_paletteword *)&backcolour,
        (wimp_paletteword *) &colour, &offset);

    chunk [out++] = draw_font_colour;
    chunk [out++] = backcolour;
    chunk [out++] = colour;
    chunk [out++] = offset);
  #else
    ftracef2 ("draw_text_setup_colour: colour: 0x%X; backcolour: 0x%X\n",
        colour, backcolour);
    chunk [out++] = draw_font_true_colour;
    chunk [out++] = backcolour >> 8;
    chunk [out++] = backcolour >> 16;
    chunk [out++] = backcolour >> 24;
    chunk [out++] = colour >> 8;
    chunk [out++] = colour >> 16;
    chunk [out++] = colour >> 24;
    chunk [out++] = offset;
  #endif
}

/* Static variables - used for the forground and background RGB values last
   seen. We need to hold these statically, because both are needed to set a
   colour, and it is not always easy to find the last values. See at the start
   of rendering from the object colours
 */

static draw_coltyp draw_text_fg, draw_text_bg;

/*
 Function    : draw_setVmove
 Purpose     : set vertical move
 Parameters  : buffer offset
               move in points
 Returns     : void
*/

static void draw_setVmove (int out, int move)

{ ftracef1 ("draw_setVmove: move %dmpt\n", move);

  chunk [out++] = draw_font_vmove;
  chunk [out++] = move;
  chunk [out++] = move >> 8;
  chunk [out++] = move >> 16;
}

/*
 Function    : draw_setLMPstate
 Purpose     : set state on L, M and P commands; skip hyphens
 Parameters  : offset into source string, at L, M or P
               base address of string
               state data
 Returns     : offset to rest of string
 Description : sets the state on an L, M or P command, either in the original
               string, or when processing the output. Skips hyphens, which can
               appear in output comments.
*/

static int draw_setLMPstate (int from, char *base, draw_linedata *state)

{ int i;

  ftracef0 ("draw_setLMPstate\n");
  switch (base [from++])
  { case 'L':
      ftracef0 ("calling draw_getNum()\n");
      draw_getNum (from, base, &i, FALSE, TRUE, &from);
      state->leading = draw_pointsToFont (i);
      ftracef1 ("state->leading = %dmpt\n", state->leading);
    break;

    case 'P':
      ftracef0 ("calling draw_getNum()\n");
      draw_getNum (from, base, &i, FALSE, TRUE, &from);
      state->paraLeading = draw_pointsToFont (i);
    break;

    case 'M':
      ftracef0 ("calling draw_getNum()\n");
      draw_getNum (from, base, &i, FALSE, TRUE, &from);
      state->lmargin = draw_pointsToFont (i);
      ftracef0 ("calling draw_getNum() again\n");
      draw_getNum (from, base, &i, FALSE, TRUE, &from);
      state->rmargin = draw_pointsToFont (i);
    break;

    case '-':
      from++;   /* Skip hyphen comment terminator */
    break;
  }

  return (from);
}

/*
 Function    : draw_text_allocate
 Purpose     : allocate memory for string
 Parameters  : pointer to string
 Returns     : TRUE if memory can be allocated
 Description : this calculates the size of a buffer large enough to hold the
               string that will be generated by get String. The size <=
               number of characters up to \<nl>, <nl><nl>, <nl>\0, \0.
               + total length of numbers in \L sequences
               + total length of numbers in \P sequences
               + total length of numbers in \M sequences
               + number of \V sequences*2
               + number of \U sequences
               + number of \C sequences*2
               + number of \B sequences*2
               + number of \- sequences
               + number of \<digit> sequences*2
               + space for terminator and initial settings

               This does not allow for the string getting broken by a \A --
               but this is hard to test for, because of the initial case.

               Memory is then allocated if the current space is not large
               enough. If not, we don't report an error, but we do return
               FALSE.
*/

static BOOL draw_text_allocate (char *from)

{ int extra = 10; /*terminator, initial colour, underline, vmove*/
  char *at;
  BOOL getOut = FALSE;
  int length;

  ftracef0 ("draw_text_allocate\n");
  /* Look for \ and newline */
  at = from;
  do
  { at += strcspn (at, "\n\\");
    if (*at == '\\')
      switch (*++at)
      { case 'L': case 'M': case 'P':
          extra += 2 + strcspn (at, "\n/");
          at += strcspn (at, "\n/") + 1;
        break;

        case 'B': case 'C':
          #if USE_TRUE_COLOURS
            extra += 10;
          #else
            extra += 2;
          #endif
          at += strcspn (at, "\n/") + 1;
        break;

        case 'U':
          extra++;
          if (*++at != '.') at += strcspn (at, "\n/");
          at++;
        break;

        case '-':
          extra++;
          at++;
        break;

        case 'V':
        { int end;

          /*if (*++at == '-') at += 2; else at++;*/
          ftracef0 ("calling draw_getNum()\n");
          (void) draw_getNum (0, ++at, NULL, TRUE, FALSE, &end);
          at += end;
          extra += 2;
        }
        break;

        case '\n':
          getOut = TRUE;
        break;

        default:
          if (isdigit (*at))
          { int end;

            /*at = draw_text_getFontNum (at, &dummy);*/
            ftracef0 ("calling draw_getNum()\n");
            (void) draw_getNum (0, at, NULL, FALSE, FALSE, &end);
            at += end;
            extra += 2;
          }
          else
            at++;
        break;
      }
    else if (*at == '\n')
      getOut = *++at == '\n';
  }
  while (*at != '\0' && !getOut);

  if ((length = extra + at - from) > chunkLen)
  { int flexCode;

    /* Allocate new memory, or extend existing memory, in 1k units */
    chunkLen = (length/1024 + 1)*1024;
    if (chunk == NULL)
      flexCode = FLEX_ALLOC ((flex_ptr) &chunk, chunkLen);
    else
      flexCode = FLEX_EXTEND ((flex_ptr) &chunk, chunkLen);

    if (flexCode == 0)
      /* Error - can't claim memory */
      return FALSE;
  }

  return TRUE;
}

/*
 Function    : draw_text_getString
 Purpose     : get a cleaned string
 Parameters  : pointer to input string
               pointer to font array
               IN/OUT: line state data
 Returns     : pointer to rest of string (NULL on error)
 Description : this takes the string from the current location up to the end
               of the paragraph or to a change in the align and builds a string
               that is closer to what the font manager can handle. Some further
               processing will still be necessary. Sequences that cannot
               immediately be coded up are replaced by font manager comment
               sequences. The output string is terminated by a null character.
               If the break was caused by a paragraph break, the null is
               preceded by a newline.
               The interpretation proceeds as follows:
               1. control characters are deleted, except for tab, which is
                  replaced by a space.
               2. All other characters are copied, except '\', which is
                  interpreted according to the next character, and newline
                  (see below)
               3. \\ is replaced by \
               4. \; .. <newline> is deleted (comment).
               5. \F<digit*><name><space><size><space><width><newline> defines
                  a font. The font reference is recorded in a table, and an
                  Arthur font handle generated for it. The handle is logged, so
                  we can lose it later. Both the size and width are in points.
                  The font name may have leading spaces.
               6. \<digit*> inserts a font change sequence.
               7. \L<number><newline> is replaced by a comment containing the
                  number and the newline - the rendition code must look for
                  this to determine the leading.
               8. \V [-]<digit> is replaced by a vertical move sequence, in
                  scaled units.
               9. \Ax sets the align flag. Note that if any characters appear
                  before this, the string is terminated just before it. x = L
                  (left), R (right), C (centre), D (justified both sides).
                  Other characters are ignored; the string is not terminated in
                  this case.
               10. \U<number1><space><number2><newline> starts underlining.
                   \U. (no newline) turns underlining off (so does \U with
                   <number2> = 0)
               11a.\C<numberR><space><numberG><space><numberB><newline>
                 b.\B<numberR><space><numberG><space><numberB><newline>
                   Both of these generate a colour change sequence in the
                   string.
               12. \D<number><newline> is skipped.
               13. \P<number><newline> is treated as for \L.
               14. \- is replaced a comment.
               15. \<newline> forces a line break, but not a paragraph break.
               16. \M<L><spaces><R><newline> replaced by a margin setting
                   comment.
               17. \other: (never occurs - gets weeded out in verify)
               18. newline: before any printable text, this causes a paragraph
                   space to be inserted. In the body of text, a sequence of n
                   newlines cause n-1 paragraph spaces. A single newline is
                   ignored, except that if it is not preceded or followed by
                   a space (or tab), it generates a space in the output.

               Any command may be terminated by '/'. Where the command would
               normally be terminated by a newline, it replaced the newline.

               Note that \ sequences are case sensitive.
               <digit*> is interpreted as a number consisting of either one or
               two digits, depending on whether the character following the
               first digit is numeric or not.

               When there is an error in the font, the previous font persists.
               There is guaranteed to be a least some text in a valid font, as
               a result of the verification. Any characters before the first
               font change are skipped, including newlines; however, we must
               retain all leading, etc. changes. The default font contains -1
               until we see a good font. The last font seen is returned for the
               next default font.
               If the chunk of text gets too long, we force a line break in a
               rather ugly way: this ought never to happen.

               Before the first call, the \! version string must have been
               skipped.

               Those commands which affect only the state data, if they occur
               at the start of a paragraph, are applied here, rather than
               producing anything in the output string.
*/

/* Macro for skipping optional terminator */
#define draw_text_termSkip(match, in) {if (*(match) == '/') (in)++;}

static char *draw_text_getString (char *in, font *fonts,
    draw_linedata *state)

{ int getOut = FALSE /*Deep break*/, printing = FALSE /*TRUE when a print
    character seen*/, out /*Offset into output buffer*/;
  font currentFont /*Last font seen (default initially)*/;

  ftracef0 ("draw_text_getString\n");
  currentFont = state->defaultFont;
  out = draw_insert;

  /* Allocate space for chunk */
  if (!draw_text_allocate (in)) return NULL;

  /* Process end of string, or until we break out */
  while (*in && !getOut)
  { /* Length check */
    if (out >= chunkLen) break;

    if (*in == '\t')  /* tab -> space */
    { /*if (currentFont != -1) No need to check font here. J R C 25 Jan 1990*/
      { chunk [out++] = ' ';
        Started_Printing = printing = TRUE;
      }
      in++;
    }
    else if (*in == '\n')
    { in++;
      if (currentFont != -1 && Started_Printing)
        /*Skip newlines before first valid font - or if not printing yet
          J R C 24 Jan 1990*/
      { if (!printing || *in == '\n' || isSep (*in))
            /*Newline-space also starts a new paragraph. J R C 24th Jul 1995*/
        { /* Paragraph termination */
          chunk [out++] = '\n';
          if (*in == '\n') in++; /*Do not skip over a space, if it was
              one. J R C 24th Jul 1995*/
          getOut = TRUE;
        }
        else
          /*Newline not preceded or followed by a space generates a space*/
          if (!(isSep (chunk [out - 1]) || isSep (*in)))
            chunk [out++] = ' ';
      }
    }
    else if (*in < ' ')
      /* skip control character */
      in++;
    else if (*in != '\\')                /* Ordinary character: copy */
    { if (currentFont == -1)
        return NULL;

      chunk [out++] = *in;
      Started_Printing = printing = TRUE;
      in++;
    }
    else                                      /* \ -> special sequence */
    { switch (*++in)
      { case '\\':                              /* \\ : replace by \ */
          if (TRUE /*currentFont != -1 J R C*/)
          { chunk [out++] = '\\';
            Started_Printing = printing = TRUE;
          }
          draw_text_termSkip (++in, in)
        break;

        case ';':                        /* \; : delete to newline */
          while (*in++ != '\n') ;
        break;

        case '-':                               /* \-: soft hyphen */
          chunk [out++] = draw_font_comment;
          chunk [out++] = '-';
          chunk [out++] = '\n';
          draw_text_termSkip (++in, in)
        break;

        case '\n':                         /* \<nl> : split string */
          draw_text_termSkip (++in, in)
          getOut = TRUE;
        break;

        case 'A':         /* \A : align sequence; maybe break string */
        { /* If we have done any output, break on an align */
          if (printing)
          { /* Step back over \A sequence */
            in--;
            getOut = TRUE;
          }
          else
          { /* Get align code */
            switch (*++in)
            { case 'L': state->align = alignLeft; break;
              case 'R': state->align = alignRight;break;
              case 'C': state->align = alignCentre; break;
              case 'D': state->align = alignDouble; break;
            }
            draw_text_termSkip (++in, in)
          }
        }
        break;

        case 'B':
        case 'C':                           /* \B, \C: colour change */
        { int r, g, b;
          BOOL foreground = *in == 'C';

          if (sscanf (++in, "%d %d %d", &r, &g, &b) < 3)
            r = 0, g = 0, b = 0;
          in = strpbrk (in, "\n/") + 1;

          if (r == -1)
          { if (foreground)
              draw_text_fg = TRANSPARENT;
            else
              draw_text_bg = TRANSPARENT;
          }
          else
          { if (r < 0) r = 0; else if (r > 255) r = 255;
            if (g < 0) g = 0; else if (g > 255) g = 255;
            if (b < 0) b = 0; else if (b > 255) b = 255;
  
            if (foreground)
              draw_text_fg = b << 24 | g << 16 | r << 8;
            else
              draw_text_bg = b << 24 | g << 16 | r << 8;
          }

          draw_text_setup_colour (draw_text_fg, draw_text_bg, out);
          #if USE_TRUE_COLOUR
            out += 8;
          #else
            out += 4;
          #endif
        }
        break;

        case 'D':
        { int i;
          ftracef0 ("calling draw_getNum()\n");
          draw_getNum (1, in, NULL, FALSE, TRUE, &i);
          in += i;
        }
        break;

        case 'F':                     /* \F : handle font definition */
        { int dummy;

          in = draw_text_setFont (in + 1, fonts, FALSE, &dummy);
                                 /*oops, was ++in!*/
        }
        break;

        case 'L': case 'M': case 'P':         /* \L, \P, \M */
          if (printing)
          { ftracef1 ("draw_text: draw_text_getString: "
                "found \\%c while printing\n", *in);
            chunk [out++] = draw_font_comment;
            while (!isTerm (*in)) chunk [out++] = *in++;
            chunk [out++] = '\n';
            in++;
          }
          else
          { ftracef1 ("draw_text: draw_text_getString: "
                "found \\%c while not printing\n", *in);
            in += draw_setLMPstate (0, in, state);
          }
        break;

        case 'U':                   /* \U : start or end underlining */
        { if (*++in == '.')
          { /* Turn underlining off */
            chunk [out++] = draw_font_underline;
            chunk [out++] = 0;
            chunk [out++] = 0;
            draw_text_termSkip (++in, in)
          }
          else
          { int shift, thick;

            /* Fetch two number from string */
            if (sscanf (in, "%d %d", &shift, &thick) < 2)
              shift = 0, thick = 0;
            in = strpbrk (in, "\n/") + 1;

            if (shift > 127)  shift = 127;
            if (shift < -128) shift = -128;
            if (shift < 0)  shift = 256 + shift;

            if (thick < 0)   thick = 0;
            if (thick > 255) thick = 255;

            /* Output underline sequence */
            chunk [out++] = draw_font_underline;
            chunk [out++] = shift & 255;
            chunk [out++] = thick & 255;
          }
        }
        break;

        case 'V':                            /* \V : vertical move */
        { int points, end;

          /*start = ++in;
          if (*in == '-') {sign *= -1; in++;}
          points = scaleup ((*in++ - '0')*sign);*/

          ftracef0 ("calling draw_getNum()\n");
          (void) draw_getNum (0, ++in, &points, TRUE, FALSE, &end);
          in += end;

          draw_setVmove (out, scaleup (draw_pointsToFont (points)));
          out += 4;

          /*draw_text_termSkip (in, in)*/
        }
        break;

        default:
          if (isdigit (*in))
          { int fontNumber, end;

            /*in = draw_text_getFontNum (in, &fontNumber);*/
            ftracef0 ("calling draw_getNum()\n");
            if (!(draw_getNum (0, in, &fontNumber, FALSE, FALSE, &end) ==
                draw_numOK && fontNumber <= draw_text_maxFonts))
              fontNumber = -1;
            in += end;

            /* \<number> : font selection */
            if (fontNumber != -1)
            { /*Fix various faults: if this font is -1, substitute some
                other. J R C 14th Feb 1994*/
              font f;
              int i;

              if ((f = fonts [fontNumber]) == -1)
              { ftracef1 ("did not find font for \\%d\n", fontNumber);
                for (i = 0; i <= draw_text_maxFonts; i++)
                  if ((f = fonts [i]) != -1)
                  { ftracef1 ("substituting font \\%d\n", i);
                    break;
              }   }

              /*If we have no useful fonts at all, just don't change.*/
              if (f != -1)
              { chunk [out++] = draw_font_setfont;
                chunk [out++] = currentFont = f;
              }
            }
          }
        break;
      }
    }
  }

  chunk [out] = '\0';
  state->defaultFont = currentFont;
  return (in);
}

/*
 Function    : draw_text_getLine
 Purpose     : extract an output line of text from a chunk
 Parameters  : offset into chunk
               error block pointer
               scaled max. width
               OUT: actual width (scaled)
               OUT: character displaced from split location
 Returns     : offset to rest of chunk (-1 on error)
 Description : a split location for the line is found.

               Try to split at a space; if this is not possible, we allow
               splitting at any character. Then we backspace from the given
               position, to a soft hyphen, if any, and split there. The scan
               back stops at the start of the string or at a preceding space.

               When we use a hyphen, a hyphen character is written over the
               comment character, and a null placed over the character that
               follows it. The displaced character is then returned
               as the comment character. The code that restores the displaced
               character must make special allowance for this.
*/

static int draw_text_getLine (int offset, os_error **error, int width,
    int *trueWidth, char *displaced)

{ font_string fs;
  int next = -1, i, space, hyphen = -1, term;

  #ifdef XTRACE
    ftracef0 ("draw_text_getLine: formatting \"");
    ftrace_paint (chunk + offset);
    ftracef (NULL, 0, "\"\n");
  #endif

  /* Width may be too small: produce a null string */
  if (width <= 0)
  { *displaced = chunk [offset];
    chunk [offset] = '\0';
    *error = NULL;
    return 0;
  }

  /* Find where to split string if we could split anywhere */
  fs.x     = width;
  fs.y     = draw_bigvalue;
  fs.split = -1;
  fs.term  = draw_bigvalue;
  fs.s     = chunk + offset;
  #ifdef XTRACE
    ftracef0 ("calling Font_StringWidth \"");
    ftrace_paint (fs.s);
    ftracef (NULL, 0, "\", max x %d, max y %d, "
        "split '%c', index %d\n",
        fs.x, fs.y, fs.split, fs.term);
  #endif
  if ((*error = font_strwidth (&fs)) != NULL)
    return -1;
  term = offset + fs.term /*cannot be nought*/;
  #ifdef XTRACE
    ftracef1 ("-> %d\n", fs.term);
  #endif
  *trueWidth = fs.x;

  /* Find where to split string at spaces */
  fs.x     = width;
  fs.y     = draw_bigvalue;
  fs.split = 32;
  fs.term  = draw_bigvalue;
  fs.s     = chunk + offset;
  #ifdef XTRACE
    ftracef0 ("calling Font_StringWidth \"");
    ftrace_paint (fs.s);
    ftracef (NULL, 0, "\", max x %d, max y %d, "
        "split '%c', index %d\n",
        fs.x, fs.y, fs.split, fs.term);
  #endif
  if ((*error = font_strwidth (&fs)) != NULL)
    return -1;
  space = offset + fs.term /*may be nought*/;
  #ifdef XTRACE
    ftracef1 ("-> %d\n", fs.term);
  #endif
  if (fs.term != 0) *trueWidth = fs.x;

  if (space != term)
  { /*We might be able to fit in more characters than just 'space': find
      hyphenation location.*/
    for (i = space; i < term; )
    { switch (chunk [i])
      { case draw_font_setfont:
          i += 2;
        break;

        case draw_font_vmove: case draw_font_colour:
          i += 4;
        break;

        case draw_font_true_colour: /*J R C 22 Nov '89*/
          i += 8;
        break;

        case draw_font_underline:
          i += 3;
        break;

        case draw_font_comment:
          if (chunk [i + 1] == '-') hyphen = i;

          while (chunk [i++] != '\n')
            ;
        break;

        default:
          i++;
        break;
       }

       #ifdef XTRACE
         ftracef1 ("split at soft hyphen gives %d\n", hyphen);
       #endif
    }

    if (hyphen != -1)
    { /*Insert the hyphen, and set the special displaced character*/
      ftracef0 ("draw_text_getLine: hyphenating\n");

      chunk [hyphen] = '-';
      next = hyphen + 1;
      *displaced  = draw_font_comment;
      chunk [next] = '\0';

      /* Recalculate true width */
      fs.x     = width;
      fs.y     = draw_bigvalue;
      fs.split = -1;
      fs.term  = draw_bigvalue;
      fs.s     = chunk + offset;
      if ((*error = font_strwidth (&fs)) != NULL)
        return -1;
      #ifdef XTRACE
        ftracef0 ("calling Font_StringWidth \"");
        ftrace_paint (fs.s);
        ftracef (NULL, 0, "\", max x %d, max y %d, "
            "split '%c', index %d\n",
            fs.x, fs.y, fs.split, fs.term);
      #endif
      term = offset + fs.term;
      #ifdef XTRACE
        ftracef1 ("-> %d\n", fs.term);
      #endif
      *trueWidth = fs.x;
    }
    else
    { ftracef0 ("no hyphens to use - using split at space\n");
      if (space != offset) term = space;
    }
  }

  /* Break at the termination location, if we didn't hyphenate */
  if (next == -1)
  { /* Backtrack over spaces */
    next = term;
    if (isSep (chunk [next]))
    { while (isSep (chunk [--next]))
        ;
      next++;
    }

    /* Split the string */
    *displaced  = chunk [next];
    chunk [next] = '\0';

    /* Recalculate the exact width, if spaces were found */
    ftracef2 ("next != space: %s%s\n", whether (next != space),
        next == space? " - optimising out new strwidth call": "");
    if (next != space)
    { fs.x     = width;
      fs.y     = draw_bigvalue;
      fs.split = -1;
      fs.term  = draw_bigvalue;
      fs.s     = chunk + offset;
      #ifdef XTRACE
        ftracef0 ("calling Font_StringWidth \"");
        ftrace_paint (fs.s);
        ftracef (NULL, 0, "\", max x %d, max y %d, split '%c', index %d\n",
            fs.x, fs.y, fs.split, fs.term);
      #endif
      if ((*error = font_strwidth (&fs)) != NULL)
        return -1;
      #ifdef XTRACE
        ftracef1 ("-> %d\n", fs.term);
      #endif
      *trueWidth = fs.x;
    }
  }

  ftracef1 ("giving true width of %d\n", *trueWidth);
  return next;
}

/*
 Function    : draw_text_newColumn
 Purpose     : set parameters for a new column
 Parameters  : column pointer
               pointer to bounding box to set (font units)
               OUT: base y location
 Returns     : void
 Description : sets the parameters from the header of the given column.
*/

static void draw_text_newColumn (draw_textcolhdr *column, draw_bboxtyp *box,
    int *basey)

{ draw_bboxtyp *bbox = &column->bbox;

  ftracef0 ("draw_text_newColumn\n");
  box->x0 = draw_drawToFont (bbox->x0);
  box->y0 = draw_drawToFont (bbox->y0);
  box->x1 = draw_drawToFont (bbox->x1);
  box->y1 = draw_drawToFont (bbox->y1);
  *basey = box->y1;
}

/*
 Function    : draw_text_paintCheck
 Purpose     : check that text will be painted within a given region
 Parameters  : chunk offset
               y base (unscaled, font units)
               clip box (in font units, no origin shift, scaled)
               region box (in font units, unscaled)
 Returns     : symbolic code (see below)
 Description : finds the string bbox, and makes sure that it does not protrude
               beyond the limits of the given region box. If text overlaps the
               top of the box, we should not render it - however, the font and
               colour changes (etc.) must still be executed. If the text sticks
               out below the bottom of the box, either in position or as a
               result of descenders, we should move to a new column.
               Source level clipping is also carried out here; the x test for
               this is an approximation.

               If the string is empty, we force a move to the next area,
               since we certainly can't plot it in this one.

               The return codes are:
                OK - go ahead with paint
                SKIP - text is too tall to fit in box, or is clipped
                LOW - text is to low: new column needed
*/

#define draw_paint_OK   0
#define draw_paint_SKIP 1
#define draw_paint_LOW  2

#define STATE_SCANNED_BY_DRAW 0

static int draw_text_paintCheck (int offset, int y, /*draw_bboxtyp *clip,*/
    draw_bboxtyp *box, draw_linedata *state)

{ font_info fi;

  state = state;
  ftracef1 ("draw_text_paintCheck (..., {leading %d, ...})\n",
      state->leading);
  /*Check base position is ok, and that the text is non-empty*/
  if (y <= box->y0 || strnul (chunk + offset))
    return draw_paint_LOW;
  y = scaleup (y);

  /* Must use font_stringbox here (can't estimate) otherwise lines can get chopped
   * off and text columns can become disrupted after zooming.
   */
  font_stringbbox (chunk + offset, &fi);
  ftracef3 ("y %d, miny %dmpt, maxy %dmpt\n", y, fi.miny, fi.maxy);
  ftracef4 ("box ((%d, %d), (%d, %d))\n",
      scaleup (box->x0), scaleup (box->y0),
      scaleup (box->x1), scaleup (box->y1));

  if (fi.miny + y < scaleup (box->y0))
    return draw_paint_LOW;

  #if STATE_SCANNED_BY_DRAW
    if (fi.maxy + y > scaleup (box->y1) ||
        scaleup (box->x1) < clip->x0 ||
        scaleup (box->x0) > clip->x1 ||
        fi.maxy + y < clip->y0 ||
        fi.miny + y > clip->y1)
    { int t;  /* Text index */

      /* Implement special sequences */
      for (t = offset; chunk [t] != '\0'; )
      { switch (chunk [t])
        { case draw_font_vmove:
            t += 4;
          break;

          case draw_font_colour:
            font_setcolour (0, chunk [t+1], chunk [t+2], chunk [t+3]);
            t += 4;
          break;

          case draw_font_true_colour: /*J R C 22 Nov '89*/
            draw_text_setColour
            ( chunk [t + 4] << 8 | chunk [t + 5] << 16 | chunk [t + 6] << 24,
              chunk [t + 1] << 8 | chunk [t + 2] << 16 | chunk [t + 3] << 24
            );
            t += 8;
          break;

          case draw_font_comment:
            while (chunk [t++] != '\n')
              ;
          break;

          case draw_font_underline:
            t += 3;
          break;

          case draw_font_setfont:
            font_setfont ((font) chunk [t + 1]);
            ftracef1 ("font_setfont (%d)\n", chunk [t + 1]);
            t += 2;
          break;

          default:
            t++;
          break;
        }
      }

      return draw_paint_SKIP;
    }
  #else
    /*if (fi.maxy + y > scaleup (box->y1))
      return draw_paint_SKIP;*/
  #endif

  return draw_paint_OK;
}

/*
 Function    : draw_text_paint
 Purpose     : paint the current line
 Parameters  : chunk offset
               left limit, right limit
               plot flags
               align code
               true width
               x origin
               y location (origin + offset)
 Returns     : os error, or NULL
 Description : the text is plotted with appropriate alignment. Before this is
               done, we measure its bounding box, and it any part of it lies
               outside the given box, then nothing is painted. This is NOT the
               same as the check for a new column -- it is a test that avoids
               problems with redraw. We can be sure that it fits horizontally.
*/

static os_error *draw_text_paint (int offset, int x0, int x1,
    int plotType, draw_align align, int trueWidth, int orgx, int y)

{ os_error *err = NULL;
  int x;

  ftracef0 ("draw_text_paint: text \"");
  ftrace_paint (chunk + offset);
  #if TRACE
    ftracef (NULL, 0, "\", displace \'%d\', x0 %d, x1 %d, align 0x%X, "
        "trueWidth %d, orgx %d, y %d)\n", displace, x0, x1, align,
        trueWidth, orgx, y);
  #endif

  if (align == alignRight)
    x = (int) (draw_displ_scalefactor*x1 - trueWidth);
  else if (align == alignCentre)
    x = (int) ((draw_displ_scalefactor*((double) x1 + (double) x0) -
        trueWidth)/2);
  else
  { if (plotType & font_JUSTIFY)
    { /* Do move for the alignment box */
      ftracef2 ("bbc_move (%d, %d)\n", draw_fontToOS (scaleupX (x1)),
          draw_fontToOS (y));
      bbc_move (draw_fontToOS (scaleupX (x1)), draw_fontToOS (y));
    }
    x = scaleup (x0);
  }
  ftracef4 ("painting at (%d + %d, %d), plot type 0x%X\n",
      orgx, x, y, plotType);

  /*Paint the text, unless empty.*/
  ftracef1 ("chunk [offset] = %d\n", chunk [offset]);
  if (chunk [offset])
    err = font_paint (chunk + offset, plotType, orgx + x, y);

  ftracef0 ("leaving draw_text_paint\n");
  return err;
}

/*
 Function    : draw_textPatchup
 Purpose     : patchup when exiting draw_textArea
 Parameters  : void
 Returns     : void
 Description : frees the chunk if need be, and releases all the fonts
*/

static void draw_textPatchup (void)

{ int  i;

  ftracef0 ("draw_textPatchup\n");
  if (chunk) FLEX_FREE ((flex_ptr) &chunk);

  /* Lose all the fonts */
  for (i = 0; i < 256; i++)
  { while (draw_usedFont [i] > 0)
    { font_lose ((font)i);
      draw_usedFont [i] -= 1;
    }
  }
}

/*
 Function    : draw_text_stateScan
 Purpose     : scan for state parameters
 Parameters  : pointer to chunk
               start offset in chunk
               end offset in chunk
               pointer to state data block
 Returns     : void
 Description : called after a line has been output to note the state
               parameters that will apply to the next line.
               Affects underline, vertical move, margin and line/paragraph
               spacing state.
*/

static void draw_text_stateScan (char *chunk, int start, int end,
                                draw_linedata *state)

{ int c;

  state->vmove = 0;

  #if TRACE
    ftracef0 ("draw_text_stateScan: \"");
    ftrace_paint (chunk + start);
    ftracef (NULL, 0, "\"\n");
  #endif

  /* Scan for state parameters */
  for (c = start; c < end; )
    switch (chunk [c++])
    { case draw_font_setfont:
        c++;
      break;

      case draw_font_colour:
        c += 3;
      break;

      case draw_font_true_colour:
        c += 7;
      break; /*J R C 22 Nov '89*/

      case draw_font_vmove:
      { int move = chunk [c] | chunk [c + 1] << 8 | chunk [c + 2] << 16;

        if ((move & 0x800000) != 0) move |= 0xFF000000; /*sign extend*/
        ftracef2 ("adding %d to vmove of %d\n", move, state->vmove);
        state->vmove += move;
        c += 3;
      }
      break;

      case draw_font_underline:
        state->under1 = chunk [c++];
        state->under2 = chunk [c++];
      break;

      case draw_font_comment:
        c = draw_setLMPstate (c, chunk, state);
      break;
    }
}

/*
 Function    : draw_textArea
 Purpose     : create a text area object
 Parameters  : object pointer
               x, y origin (bottom left)
               clipping box in scaled font units
               os error pointer
 Returns     : TRUE if ok
 Description : creates a text area as follows:
               the font tables are initialised, and some other defaults set up.
               Then we draw as much as possible in each column, and continue
               until either the end of the text is reached, or all the columns
               are full.
               Within each column, we grab a chunk, i.e. up to a newline break,
               and then progressively split it into lines, using the font
               manager. When we run out of space for a line, we move to a new
               column, resetting the bounding box and position parameters.
               Newlines at the start of a new column are not output (this
               happens without need for a special case from the way paintCheck
               works).
               When all text has been painted, we lose the fonts.
               A colour change to the given initial colour is inserted before
               the first string.

               On an error, FALSE is returned, with the os error pointer set,
               or with NULL for an internal error.

               Calculations are done throughout in 1/72000 inch units rather
               than draw units.

               Before each physical output line, the vertical move and
               underline must be set up.
*/

static BOOL draw_textArea (draw_objptr hdrptr, draw_objcoord *org,
    /*draw_bboxtyp *clip,*/ os_error **error)

{ int i, y, orgx, orgy;
  char *text;
  os_error *err;
  BOOL newColumn = FALSE;
  font fonts [draw_text_maxFonts+1];
  draw_bboxtyp     box;
  draw_textareaend *endptr = draw_text_findEnd (hdrptr);
  draw_textcolhdr  *column = &hdrptr.textareastrp->column;
  draw_linedata    state;

  ftracef0 ("draw_textArea\n");
  /* Find start colours and save them */
  draw_text_fg = endptr->textcolour;
  draw_text_bg = endptr->backcolour;
  if (draw_text_fg == TRANSPARENT)
    draw_text_fg = draw_text_bg;

  /* Set default state data */
  state.defaultFont = -1;
  state.leading     =
  state.paraLeading = draw_pointsToFont (10);
  ftracef1 ("state->leading = %dmpt\n", state.leading);
  state.lmargin     =
  state.rmargin     = draw_pointsToFont (1);
  state.align       = alignLeft;
  state.under1      =
  state.under2      =
  state.vmove       = 0;

  /* Set initial colour */
  draw_text_setColour (draw_text_fg, draw_text_bg);

  /* Some size constants and initial position */
  orgx = draw_drawToFont (org->x);
  orgy = draw_drawToFont (org->y);

  /* Initialise arrays and defaults */
  for (i = 0; i < 256; i++) draw_usedFont [i] = 0;
  for (i = 0; i <= draw_text_maxFonts; i++) fonts [i] = -1;

  /* Point to text and skip ID string (guaranteed present) */
  for (text = &endptr->text [0]; !isTerm (*text); text++)
    ;

  /* Load parameters for first column */
  draw_text_newColumn (column++, &box, &y);

  /* While there is text to process */
  Started_Printing = FALSE;
  while (*text)
  { int c = draw_insert;        /* Offset in chunk */


    /* Select default font, if any */
    if
    ( state.defaultFont != -1 &&
      ( ftracef1 ("font_setfont (%d)\n", state.defaultFont),
        err = font_setfont (state.defaultFont)
      ) != NULL
    )
    { *error = err;
      draw_textPatchup ();
      return FALSE;
    }

    /* Set up chunk */
    if ((text = draw_text_getString (text, fonts, &state)) == NULL)
    { /* Error in chunk: probably too long */
      *error = NULL;
      draw_textPatchup ();
      return FALSE;
    }

    /* Ensure chunk is not empty */
    if (chunk [c] != '\0' && chunk [c] != '\n')
    { int  plotType, trueWidth, scaledWidth, x0, x1, next;
      char displaced;

      /* Loop over each line in the chunk */
      while (chunk [c] != '\0' && chunk [c] != '\n')
      { /* If necessary, move to a new column */
        if (newColumn)
        { if (column->tag == draw_OBJTEXTCOL)
          { /* Find new column parameters */
            draw_text_newColumn (column++, &box, &y);
            newColumn = FALSE;
          }
          else /* No more columns */
          { draw_textPatchup ();
            return TRUE;
          }
        }

        /* Shift the box sides to allow for the margin */
        x0 = box.x0 + state.lmargin;
        x1 = box.x1 - state.rmargin;

        /* Insert the state data into the string */
        c -= draw_insert;     /* Guaranteed to be enough room */
        chunk [c]     = draw_font_underline;
        chunk [c + 1] = state.under1;
        chunk [c + 2] = state.under2;
        draw_setVmove (c + 3, state.vmove);

        /* Get line */
        scaledWidth = scaleup (x1 - x0);
        if ((next = draw_text_getLine (c, error, scaledWidth, &trueWidth,
            &displaced)) == -1)
        { draw_textPatchup ();
          return FALSE;
        }

        /* Set new base position */
        y -= state.leading;

        /* Plot if we are still in box (may fail with descenders) */
        switch (draw_text_paintCheck (c, y, /*clip,*/ &box, &state))
        { case draw_paint_OK:
            /* Set up plotting style */
            plotType = ((draw_text_bg == TRANSPARENT) && draw_fonts_blend) ? font_BLENDED : 0;

            /* Get plot point, allowing for alignment and scaling */
            if (state.align == alignDouble && displaced != '\0' && displaced != '\n')
              plotType |= font_JUSTIFY;

            if (state.defaultFont != -1 && draw_text_fg != TRANSPARENT && (err = draw_text_paint
                (c, x0, x1, plotType, state.align, trueWidth, orgx, scaleupY (y))) != NULL)
            { draw_textPatchup ();
              return FALSE;
            }
          /* Fall into skip case */

          case draw_paint_SKIP:
            draw_text_stateScan (chunk, c, next, &state);
            c = isSep (displaced)? next + 1:
                displaced == draw_font_comment? next + 2: next;
            while (isSep (chunk [c])) c++;   /* Skip extra spaces */
          break;

          case draw_paint_LOW:
            newColumn = TRUE;
            c += draw_insert; /* Teeny fiddle */
          break;
        }

        /* Restore split character, allowing for hyphens */
        if (displaced == draw_font_comment)
        { chunk [next-1] = draw_font_comment;
          chunk [next]   = '-';
        }
        else
          chunk [next] = displaced;

        /* At the end of a paragraph, shift by para  */
        if (displaced == '\n') y -= state.paraLeading;
      }
    }
    else
      /* Chunk is empty - treat it as a null paragraph */
      y -= state.paraLeading;
  }

  *error = NULL;
  draw_textPatchup ();
  return TRUE;
}

/*
 Function    : draw_report
 Purpose     : report an error
 Parameters  : error message
               argument character (or 0, if none)
 Returns     : void
 Description : reports an error, with the line number
*/

static void draw_report (char *text, char arg)

{ char buffer [200];

  ftracef0 ("draw_report\n");
  sprintf (buffer, msgs_lookup (text), arg);
  werr (0, msgs_lookup ("Text00"), buffer, lineNum);
}

/*
 Function    : draw_text_verifyTextArea
 Purpose     : check text area definition
 Parameters  : pointer to start of text
               length of text
               OUT: number of columns
 Returns     : TRUE if ok
 Description : check that all special sequences in the object are OK. The text
               is not null terminated.

               The default font is set to the number of the first font seen.
               If an error occurs, we return immediately - means checking is
               minimal, but avoids a plethora of messages.

               All texts must start with an ID line of the form:
               \! <number><newline>, where <number> is the text area
               version. If the first character is not a backslash, we prepend
               a standard header.

               The only error that is 'non-fatal' is the font warning.

               The text must end with a newline. Ensureing this is so
               simplified some tests later (i.e. no need to test for hitting
               end of the string as well as terminator).
*/

/* Macro for line number checking */
#define draw_countLine(at) {if (*(at) == '\n') lineNum++;}

BOOL draw_text_verifyTextArea (char *text, int length, int *columns,
    char *fontusetab)
  /*Added fontusetab - if non-NULL, filled in with 1 for each font used
    (as defined by the entry numbers in draw_fontcat).*/

{ char *end;
  font fonts [draw_text_maxFonts + 1]; /* Font table: digit->fontHandle */
  int seenColumns = FALSE, handle, version = -1, offset, first_font = -1;

  ftracef0 ("draw_text_verifyTextArea\n");
  end = text + length;
  if (columns != NULL) *columns = 1;
  lineNum  = 1;

  /* Check ID heading */
  if (*text++ != '\\' || *text++ != '!')
  { Error (0, "TextC1");
    return FALSE;
  }

  ftracef0 ("calling draw_getNum()\n");
  if (draw_getNum (0, text, &version, TRUE, TRUE, &offset) != draw_numOK ||
      version != draw_text_VERSION)
  { Error (0, "TextV1");
    return FALSE;
  }

  draw_countLine (text-1);
  text += offset;

  /*Ensure clean termination so we don't need to check for null later*/
  if (*(end - 1) != '\n')
  { Error (0, "TextN1");
    return FALSE;
  }

  /* Look for special sequence */
  while (text < end /*&& *(text += strcspn (text, "\\\n")) != '\0'*/)
    switch (*text)
    { case '\n':
        text++;
        lineNum++;
      break;

      default: /*Check there is selected font before any printing chars*/
        if (first_font == -1)
        { Error (FALSE, "TextF6");
          return FALSE;
        }
        text++;
      break;

      case '\\':
        switch (*++text)
        { case '-': case '\\':
            text++;
          break;

          case '\n':
            text++;
          break;

          case ';':                                       /* \;: skip */
            while (*text++ != '\n')
              ;
          break;

          case 'A':               /* \A: must be followed by L, R, C or D */
            if (strchr ("LRCD", *++text) == NULL)
            { draw_report ("TextA1", *text);
              return FALSE;
            }
            if (*++text == '/') text++;
          break;

          case 'B': case 'C':  /* \B or \C followed by three numbers */
          { int  i;
            int  r, g, b;

            ftracef0 ("calling draw_getNum() up to 3 times\n");
            if (draw_getNum (1, text, &r, TRUE, TRUE, &i) != draw_numMORE
                || draw_getNum (i, text, &g, TRUE, TRUE, &i) != draw_numMORE
                || draw_getNum (i, text, &b, TRUE, TRUE, &i) != draw_numOK)
            { draw_report ("TextT1", *text);
              return FALSE;
            }
            if (((r < 0) || (g < 0) || (b < 0)) /* If transparent allow only -1 -1 -1 */
                && ((r != -1) || (g != -1) || (b != -1)))
            { draw_report ("TextT1", *text);
              return FALSE;
            }
            text += i;
          }
          break;

          case 'D':                             /* \D: get no. of columns */
          { int i;

            if (seenColumns)
            { draw_report ("TextD1", 0);
              return FALSE;
            }

            ftracef0 ("calling draw_getNum()\n");
            if (draw_getNum (1, text, columns, FALSE, TRUE, &i) != draw_numOK)
            { draw_report ("TextT1", 'D');
              return FALSE;
            }

            seenColumns = TRUE;
            text += i;
          }
          break;

          case 'F':                        /* \F: check font definition */
          { int fontNum, end1;
            char *fontDefText;
            int sizeTerm, i;

            while (isSep (*++text))
              ;
            fontDefText = text;
            /*text = draw_text_getFontNum (fontDefText, &fontNum);*/
            ftracef0 ("calling draw_getNum()\n");
            if (!(draw_getNum (0, fontDefText, &fontNum, FALSE, FALSE, &end1) ==
                draw_numOK && fontNum <= draw_text_maxFonts))
            { draw_report ("TextF1", 0);
              return FALSE;
            }
            text += end1;

            /* Skip to a non-space, i.e. to start of name */
            while (text < end && isSep (*text)) text++;

            /* Look for terminating space, i.e. to end of name */
            while (text < end && !isSep (*text)) text++;
            if (!isSep (*text))
            { draw_report ("TextF2", 0);
              return FALSE;
            }

            ftracef0 ("calling draw_getFloat()\n");
            if ((sizeTerm = draw_getFloat (0, text, NULL, FALSE, TRUE, &i)) ==
                draw_numMORE)
            { /* Read second number */
              ftracef0 ("calling draw_getFloat()\n");
              if (draw_getFloat (i, text, NULL, FALSE, TRUE, &i) != draw_numOK)
              { draw_report ("TextF3", 0);
                return FALSE;
              }
            }
            else if (sizeTerm == draw_numBAD)
            { draw_report ("TextF4", 0);
              return FALSE;
            }

            /* Try to load the font */
            draw_text_setFont (fontDefText, fonts, TRUE, &handle);
            if (handle != -1) font_lose (handle);

            if (fontusetab != NULL)
            { /*Register the font in draw_fontcat (whether or not it was
                actually found) and also in fontusetab.*/
              draw_text_setFont (fontDefText, NULL, FALSE, &handle);
              if (handle != 0) fontusetab [handle] = 1;
            }
            text += i;
          }
          break;

          case 'L': case 'P':  /* \L, \P: must be followed by <number><nl> */
          { char code = *text;
            int  i;

            ftracef0 ("calling draw_getNum()\n");
            if (draw_getNum (1, text, NULL, FALSE, TRUE, &i) != draw_numOK)
            { draw_report ("TextT1", code);
              return FALSE;
            }
            text += i;
          }
          break;

          case 'M':         /* \M: check numbers */
          { int i;

            ftracef0 ("calling draw_getNum()\n");
            if (draw_getNum (1, text, NULL, FALSE, TRUE, &i) != draw_numMORE ||
               draw_getNum (i, text, NULL, FALSE, TRUE, &i) != draw_numOK)
            { draw_report ("TextT1", 'M');
              return FALSE;
            }
            text += i;
          }
          break;

          case 'U':               /* \U: \U. or \U<n1><space><n2> */
            if (*++text != '.')
            { int i;

              ftracef0 ("calling draw_getNum()\n");
              if (draw_getNum (0, text, NULL, TRUE, TRUE, &i) != draw_numMORE ||
                  draw_getNum (i, text, NULL, FALSE, TRUE, &i) != draw_numOK)
              { draw_report ("TextT1", 'U');
                return FALSE;
              }
              text += i;
            }
          break;

          case 'V': /* \V: must be followed by -<digit> or <digit> */
            #if 0
              if (*++text == '-') text++;
              if (!isdigit (*text++))
              { draw_report ("TextV2", *(text-1));
                return FALSE;
              }
              if (*++text == '/') text++;
            #else
              /*J R C 20 June 1991 allow any number here*/
              { int i;

                ftracef0 ("calling draw_getNum()\n");
                if (draw_getNum (1, text, NULL, TRUE, FALSE, &i) != draw_numOK)
                { draw_report ("TextV2", 'V');
                  return FALSE;
                }
                text += i;
              }
            #endif
          break;

          default:                               /* \<other>: digits only */
          { int fontNumber, end;

            if (!isdigit (*text))
            { draw_report ("TextE1", *text);
              return FALSE;
            }

            /*text = draw_text_getFontNum (text, &fontNumber);*/
            ftracef0 ("calling draw_getNum()\n");
            if (!(draw_getNum (0, text, &fontNumber, FALSE, FALSE, &end) ==
                draw_numOK && fontNumber <= draw_text_maxFonts))
            { draw_report ("TextF5", 0);
              return FALSE;
            }
            text += end;

            if (first_font == -1) first_font = fontNumber;
          }
          break;
        }
        draw_countLine (text-1);
      break;
    }

  if (columns != NULL && *columns < 1)
  { Error (0, "TextC2");
    return FALSE;
  }

  return TRUE;
}

/*
 Function    : draw_text_setAtts
 Purpose     : set attributes for an object and check what it is over
 Parameters  : diagram pointer
               pointer to new object header
               number of columns in new object
               mouse location
               OUT: offset to old object header
 Returns     : TRUE if over a text area object
 Description : if we are over a text area object, then we copy the bounding
               boxes of the columns in it to the new object. Extra columns in
               the old object are lost, extra ones in the new object are set to
               the same size as the last one seen, but with an offset in the x
               direction. The colour is also lifted from the old object.

               if we are not over a text area, then we use a standard colour
               and standard sizes for the text columns, with the mouse location
               giving the bottom left of the parent box. This is set by making
               the first column go there if there is one column, or making the
               first column go to there+border offset if there is more than one

               In finding the object we are over, we start at the top level,
               and then look progressively deeper until either we find a text
               area, or we have examined all objects.

               An offset to the old object is returned, so it can be deleted.

               A check must be made on selection -- extra areas in the old
               object are deselected; if the new object has a single column,
               we must take care which selection boxes get erased.
*/

static BOOL draw_text_setAtts (diagrec *diag, draw_objptr newObject,
                              int columns, draw_objcoord *pt, int *oldOffset)

{ region overRegion;
  int offset, deeper /*Offsets within diagram*/, firstOffset, overAnObject,
      i, bboxX, bboxY;
  draw_textcolhdr *newColumn = &newObject.textareastrp->column;
  draw_textareaend *newEnd;
  int x = pt->x, y = pt->y;

  ftracef0 ("draw_text_setAtts\n");
  /* Look for a text area object */
  overAnObject = draw_obj_over_object (diag, pt, &overRegion, &offset) &&
      overRegion == overObject;
  firstOffset  = offset;

  while (overAnObject)
  { draw_objptr oldObject;

    oldObject.bytep = diag->paper + offset;
    if (oldObject.textareap->tag == draw_OBJTEXTAREA)
    { draw_textareaend *oldEnd = draw_text_findEnd (oldObject);
      draw_textcolhdr *oldColumn;

      /* Copy the boxes */
      oldColumn = & (oldObject.textareastrp->column);
      for (i = 0; i < columns && oldColumn->tag == draw_OBJTEXTCOL;
          i++, newColumn++, oldColumn++)
        newColumn->bbox = oldColumn->bbox;

      /* Fill any remaining boxes with default values */
      bboxX = (--oldColumn)->bbox.x1 + draw_textarea_SEPARATION;
      for (; i < columns; i++, newColumn++)
      { newColumn->bbox.x0 = bboxX;
        newColumn->bbox.y0 = oldColumn->bbox.y0;
        newColumn->bbox.x1 = bboxX + draw_textarea_WIDTH;
        newColumn->bbox.y1 = oldColumn->bbox.y1;
        bboxX = newColumn->bbox.x1 + draw_textarea_SEPARATION;
      }

      /* Force deselection of any extra areas in old object */
      if (draw_select_owns (diag))
      { int from, to, startOff, endOff;

        if (columns == 1)
          startOff = (char *)oldColumn - diag->paper;
        else
          startOff = (char *) (oldColumn + 1) - diag->paper;
        endOff = (char *) oldEnd - diag->paper;
        for (from = 0; from < draw_selection->indx &&
            draw_selection->array [from] < startOff; from++)
          ;

        if (from != draw_selection->indx
              && draw_selection->array [from] < endOff)
        { for (to = from; to < draw_selection->indx &&
              draw_selection->array [to] < endOff; to++)
            ;

          for (; to < draw_selection->indx; from++, to++)
            draw_selection->array [from] = draw_selection->array [to];

          draw_selection->indx = from;
        }
      }

      /* Set colour from old object, and set end mark */
      newEnd = (draw_textareaend *)newColumn;
      newEnd->endmark = 0;
      newEnd->blank1  = newEnd->blank2 = 0;
      newEnd->textcolour = oldEnd->textcolour;
      newEnd->backcolour = oldEnd->backcolour;
      *oldOffset = offset;
      return TRUE;
    }

    /* Look a bit deeper, unless this was the last object */
    deeper = draw_obj_previous_object (diag, offset, pt);
    overAnObject = (deeper != firstOffset) && (deeper != -1);
    offset = deeper;
  }

  /* Set standard bounding boxes on the columns */
  if (columns != 1)
  { x += draw_textarea_BORDERX;
    y += draw_textarea_BORDERY;
  }

  newColumn->bbox.x0 = x;
  newColumn->bbox.y0 = y;
  newColumn->bbox.x1 = x + draw_textarea_WIDTH;
  newColumn->bbox.y1 = bboxY = y + draw_textarea_HEIGHT;
  bboxX = newColumn->bbox.x1 + draw_textarea_SEPARATION;

  for (newColumn++, i = 1; i < columns; i++, newColumn++)
  { newColumn->bbox.x0 = bboxX;
    newColumn->bbox.y0 = y;
    newColumn->bbox.x1 = bboxX + draw_textarea_WIDTH;
    newColumn->bbox.y1 = bboxY;
    bboxX = newColumn->bbox.x1 + draw_textarea_SEPARATION;
  }

  /* Set end mark and standard colour */
  newEnd = (draw_textareaend *)newColumn;
  newEnd->endmark = 0;
  newEnd->blank1  = newEnd->blank2 = 0;
  newEnd->textcolour = (int)BLACK;
  newEnd->backcolour = (int)WHITE;

  *oldOffset = 0;
  return FALSE;
}

/*
 Function    : draw_text_create
 Purpose     : create a text area object on initial read
 Parameters  : diagram record
               pointer to pointer to text, may not be null terminated
               length of text
               number of columns
               mouse position
 Returns     : TRUE if ok
 Description : this creates a text area and its columns from verified text.
               If we are over an existing object, it is deleted.
               The columns are not created using the standard draw_obj_start
               mechanism; instead we just fill in the tag and size
               ourselves. If the old object lies within a group or tagged
               object (or a sequence of them), we must preserve the old
               structure. This is done by copying the start and end of the
               old object and fiddling the sizes.
*/

BOOL draw_text_create (diagrec *diag, char **text, int length,
                      int columns, draw_objcoord *mouse)

{ char *to;
  draw_objptr hdrptr, endptr;
  draw_textcolhdr *column;
  BOOL deleteObj;
  int i, hdroff, offset;

  ftracef0 ("draw_text_create\n");
  /* Start the object */
  if (wimpt_complain (draw_obj_checkspace (diag,
      sizeof (draw_textareahdr) + columns*sizeof (draw_textcolhdr) + 1 +
      length + sizeof (draw_textareastrend))) != NULL)
    return FALSE;

  /* Fill in area object header fields */
  hdroff = diag->misc->ghostlimit;
  draw_obj_start (diag, draw_OBJTEXTAREA);
  hdrptr.bytep = diag->paper + hdroff;

  /* Create the columns */
  for (i = 0, column = &hdrptr.textareastrp->column; i < columns; i++)
  { column->tag = draw_OBJTEXTCOL;
    column->size = sizeof (draw_textcolhdr);
    column++;
  }

  /* Set attributes */
  endptr.textcolp = column;      /* Point to end block */
  to = &endptr.textareaendp->text [0];
  memcpy (to, *text, length);
  to [length] = '\0';
  deleteObj = draw_text_setAtts (diag, hdrptr, columns, mouse, &offset);

  /* Set parent bbox */
  draw_text_bound_objtextarea (hdrptr);

  /* Pad text to a word boundary */
  while ((++length & 3) != 0) to [length] = '\0';

  /* Complete the object - must set ghost limit first */
  diag->misc->ghostlimit = to + length - diag->paper;
  draw_obj_complete (diag);

  /* Delete if over old object and new object is ok */
  if (deleteObj)
    draw_obj_deleteObject (diag, offset, hdroff);

  return TRUE;
}

/***************************************************************************/
/*                      Interface to Draw world                            */
/***************************************************************************/

/*
 Function    : draw_text_bound_objtextarea
 Purpose     : generate bounding box of text area object
 Parameters  : pointer to object header
 Returns     : void
 Description : bbox is formed from the union of the children. Except when there
               is only one column, the parent box is made slightly larger than
               the union, to show that it really is there under selection.
*/

void draw_text_bound_objtextarea (draw_objptr hdrptr)

{ draw_textcolhdr *column;
  draw_bboxtyp     *bbox;

  ftracef0 ("draw_text_bound_objtextarea\n");
  /* Point to first column, and get its box */
  column = &hdrptr.textareastrp->column;
  bbox = &hdrptr.textareastrp->bbox;
  *bbox = column->bbox;

  /* Form union of boxes */
  while ((++column)->tag == draw_OBJTEXTCOL)
    draw_obj_unify (bbox, &column->bbox);

  /* Apply a small shift to the box, if there is more than one column */
  if (!draw_text_oneColumn (hdrptr))
    draw_widen_box (bbox, draw_textarea_BORDERX, draw_textarea_BORDERY);
}

/*
 Function    : draw_text_bound_objtextcol
 Purpose     : generate bounding box of text column object
 Parameters  : pointer to object header
 Returns     : void
 Description : does nothing - bounding box is set up in read.
*/

void draw_text_bound_objtextcol (draw_objptr hdrptr)

{ ftracef0 ("draw_text_bound_objtextcol\n");
  /* Defeat warning message */ hdrptr = hdrptr;
}

/*
 Function    : draw_text_do_objtextarea
 Purpose     : render a text area object
 Parameters  : header pointer
               x, y origins
               clipping box in data base coordinates
 Returns     : os_error or Null
 Description : draw the object. Clipping is carried out on a line by line
               basis, in the paiting check -- it is most convenient to have the
               clipping box in scaled font units at this point, but without the
               origin shift applied.
*/

os_error *draw_text_do_objtextarea (draw_objptr hdrptr,
    draw_objcoord *org /*, draw_bboxtyp *clip*/)

{ os_error *err;

  ftracef0 ("draw_text_do_objtextarea\n");
  /* Convert clipping box into screen coordinates */
  /*draw_box_scale (clip, clip, 25*draw_displ_scalefactor/16);*/

  chunk = NULL;
  chunkLen = 0;

  draw_textArea (hdrptr, org, /*clip,*/ &err); /* No error check */
  return err;
}

/*
 Function    : draw_text_do_objtextcol
 Purpose     : render a text column object
 Parameters  : header pointer
               x, y origins
               cliiping box in data base coordinates
 Returns     : os_error or Null
 Description : find the parent and render it
*/

os_error *draw_text_do_objtextcol (draw_objptr hdrptr,
  draw_objcoord *org /*, draw_bboxtyp *clip*/)

{ ftracef0 ("draw_text_do_objtextcol\n");
  return draw_text_do_objtextarea (draw_text_findParent (hdrptr.textcolp),
    org /*, clip*/);
}

/*
 Function    : draw_text_rebound
 Purpose     : rebound a text area
 Parameters  : object pointer
 Returns     : void
 Description : the bounding box of the text area is calculated using
               bound_textarea. Both the old and the new bounding boxes must be
               marked as needing a redraw: this is because the standard object
               manipuation only redraws the bounding box of the object being
               changed, which might be just an column.
               (Only used in selection actions)
*/

void draw_text_rebound (draw_objptr hdrptr)

{ ftracef0 ("draw_text_rebound\n");
  /* Redraw old column */
  draw_displ_redrawobject (draw_selection->owner,
                          hdrptr.bytep - draw_selection->owner->paper);

  /* Recalculate bounding box */
  draw_text_bound_objtextarea (hdrptr);

  /* Redraw new column */
  draw_displ_redrawobject (draw_selection->owner,
                          hdrptr.bytep - draw_selection->owner->paper);
}

/*
 Function    : draw_text_parentSelected
 Purpose     : see if the parent of an column is selected
 Parameters  : parent object pointer
 Returns     : TRUE if selected
 Description : scans the selection index for the given parent. This is used to
               avoid actions such as translation getting applied to columns
               twice.
*/

BOOL draw_text_parentSelected (draw_objptr parent)

{ int i, offset;
  offset = parent.bytep - draw_selection->owner->paper;

  ftracef0 ("draw_text_parent_selected\n");
  for (i = draw_selection->indx; i > 0; )
    if (draw_selection->array [--i] == offset)
      return TRUE;

  return FALSE;
}

/*
 Function    : draw_text_previous_textcolumn
 Purpose     : attempt to find a text column of a selected text area
 Parameters  : diagram record
               parent offset
               select location (x,y)
               OUT: column offset
 Returns     : TRUE if an column found
 Description : this is called on a double select over a text area. We examine
               each of its text columns, and if any of them contains the given
               location, its offset is returned.
*/

BOOL draw_text_previous_textcolumn (diagrec *diag, int parent,
    draw_objcoord *pt, int *column_off)

{ draw_objptr hdrptr;
  hdrptr.bytep = diag->paper + parent;

  ftracef0 ("draw_text_previous_textcolumn\n");
  /* Make sure parent is a text area with more than one column */
  if (hdrptr.objhdrp->tag != draw_OBJTEXTAREA ||
      draw_text_oneColumn (hdrptr))
    return FALSE;
  hdrptr.bytep += sizeof (draw_textareahdr);

  /* Scan text columns list */
  while (hdrptr.objhdrp->tag == draw_OBJTEXTCOL)
  { draw_bboxtyp bbox = *draw_displ_bbox (hdrptr);
    if (draw_box_within (pt, &bbox))
    { *column_off = hdrptr.bytep - diag->paper;
      return TRUE;
    }
    else
      hdrptr.bytep += sizeof (draw_textcolhdr);
  }

  return FALSE;
}
