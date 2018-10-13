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
/************************************************************************/
/* � Acorn Computers Ltd, 1992.                                         */
/*                                                                      */
/* This file forms part of an unsupported source release of RISC_OSLib. */
/*                                                                      */
/* It may be freely used to create executable images for saleable       */
/* products but cannot be sold in source form or as an object library   */
/* without the prior written consent of Acorn Computers Ltd.            */
/*                                                                      */
/* If this file is re-distributed (even if modified) it should retain   */
/* this copyright notice.                                               */
/*                                                                      */
/************************************************************************/

/* Title: c.drawTextC
 * Purpose: handling draw text columns
 * History: IDJ: 06-Feb-92: prepared for source release
 *          JAB: Merged text rendering fixes
 *
 */

/*
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
 * line, some extra control sequences have to be inserted.
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define isdigit(c) (c) >= '0' && (c) <= '9'

#include "os.h"
#include "bbc.h"
#include "font.h"
#include "sprite.h"
#include "werr.h"

#define scalefactor dr_scalefactor /* Name equivalence */
#include "DrawIntern/drawfile1.h"
#include "drawfdiag.h"
#include "DrawIntern/drawfile2.h"
#include "drawferror.h"

extern BOOL Draw_memoryError; /* Must be defined elsewhere! */

/*--------------------Macros, types, and globals ----------------------------*/

#define scaleup(xx)            ((int)((xx) * scalefactor))
#define scaleupX(xx)           ((int)(orgx + (xx) * scalefactor))
#define scaleupY(xx)           ((int)(orgy + (xx) * scalefactor))

/* Symbolic values for text alignment */
typedef enum {alignLeft, alignRight, alignCentre, alignDouble} draw_align;

#define draw_text_maxFonts 99

/* Font usage counter - more convenient for this to be global */
static int *draw_usedFont  /*[256]*/;

static void draw_usedFont_init(int fault)
{
  if (draw_usedFont == 0) draw_usedFont = malloc(256 * sizeof(*draw_usedFont));
  if (draw_usedFont == 0) {
    if (fault) {
      werr(TRUE, "draw1:Out of memory for font table");
    }
  }
  else {
    int i;

    for (i = 0; i<256; ++i) {
      draw_usedFont[i] = 0;
    }
  }
}

/* Symbolic codes for font manager operations */
#define draw_font_vmove     11
#define draw_font_colour    18
#define draw_true_font_colour 19
#define draw_font_comment   21
#define draw_font_underline 25
#define draw_font_setfont   26

/* Total length of underline and vmove sequences */
#define draw_insert 7

/* Structure representing the parameter state at the start of an output line */
typedef struct
{
  int        leading, paraLeading;  /* In font units */
  int        lmargin, rmargin;      /* In font units */
  font       defaultFont;
  int        under1, under2;
  int        vmove;
  draw_align align;
} draw_linedata;


/* Macro for matching terminators */
#define isTerm(c) (c == '\n' || c == '/')

/* Globals used for address and maximum length of current chunk */
static char *chunk;
static int  chunkLen;

#define draw_bigvalue 1 << 28  /* A large positive value */


/*
 Function    : draw_text_findParent
 Purpose     : find the parent of a text column
 Parameters  : pointer to text area column (as an column pointer)
 Returns     : object pointer
 Description : looks backwards in steps of the size of the header until it
               finds the parent tag.
*/

static draw_objptr draw_text_findParent(draw_textcolhdr *from)
{
    draw_objptr parent;

    while (from->tag == draw_OBJTEXTCOL) from -= 1;

    parent.textcolp = from;               /* Minor type fiddle here */
    return(parent);
}

/*
 Function    : draw_text_findEnd
 Purpose     : find end section of a text area
 Parameters  : header pointer
 Returns     : pointer to end section
 Description : skips over the columns and returns a pointer to the end object
*/

static draw_textareaend *draw_text_findEnd(draw_objptr hdrptr)
{
    draw_textcolhdr *column;

    column = &(hdrptr.textareastrp->column);
    while (column->tag == draw_OBJTEXTCOL) column++;
    return ((draw_textareaend *)column);
}

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

static char *draw_text_getFontNum(char *text, int *fontNumber)
{
    int num = draw_text_maxFonts+1;  /* Forces an error if bad number */

    if (isdigit(*text))
    {
        num = *text++ - '0';

        if (isdigit(*text)) num = num * 10 + *text++ - '0';
    }

    *fontNumber = (num <= draw_text_maxFonts) ? num : -1;
    if (*text == '/') text += 1;
    return (text);
}

/*
 Function    : draw_getNum
 Purpose     : get an unsigned integer out of a string
 Parameters  : offset into string
               pointer to string
               pointer to int (NULL -> no assignment)
               flag: TRUE if negative numbers are allowed
               OUT: updated offset
 Returns     : termination code (see below)
 Description : skip leading space; read an integer, skip trailing space.
               Sets the termination code on the basis of what was read, as
               follows: OK: number read ok, terminator was \n or /
                            (output pointer is character after terminator)
                        BAD: no number could be read, or invalid terminator
                        MORE: number read ok, terminator was another digit
                              (output pointer points to digit)
               The string is accessed via offsets to avoid flex block problems.
*/

#define draw_numOK    0
#define draw_numBAD   1
#define draw_numMORE 2

static int  draw_getNum(int from, char *base, int *to, BOOL negative, int *rest)
{
    int  r;

    while (base[from] == ' ') from += 1;
    if (isdigit(base[from])) r = from;
    else if (negative && base[from] == '-') r = from+1;
    else return(draw_numBAD);

    if (to) *to = atoi(base + from);

    while (isdigit(base[r])) r += 1;
    if (r == from) return (draw_numBAD);

    while (base[r] == ' ') r += 1;
    if (isdigit(base[r]))
    {
        *rest = r;
        return (draw_numMORE);
    }
    else if (isTerm(base[r]))
    {
        *rest = r + 1;
        return (draw_numOK);
    }
    else
        return (draw_numBAD);
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
               onto the icon bar, if the scalefactor is 0, we pretend it is 1.
*/

static char *draw_text_setFont(char *in, font *fonts, BOOL whinge, int *handle)
{
    int      fontNumber;
    char     *name;
    int      end;
    char     displaced;
    int      pointSize,  scaleSize;
    int      pointWidth, scaleWidth;
    os_error *err;
    font     fontHandle;

    *handle = -1;
    whinge = whinge; /* Gobstopper */

    /* Get font number */
    while (*in == ' ') in += 1;
    in = draw_text_getFontNum(in, &fontNumber);

    /* Skip leading spaces in font name */
    while (*in == ' ') in++;

    /* Find end of font name */
    for (name = in; *in != ' ' ; in++) ;
    displaced = *in;
    *in = '\0';

    /* Get point size, and maybe width */
    if (draw_getNum(1, in, &pointSize, FALSE, &end) == draw_numMORE)
        draw_getNum(end, in, &pointWidth, FALSE, &end);
    else
        pointWidth = pointSize;

    /* Find sizes at current scaling */
    scaleSize  = (int)(pointSize  * ((scalefactor==0.0)? 16: 16 *scalefactor));
    scaleWidth = (int)(pointWidth * ((scalefactor==0.0)? 16: 16 *scalefactor));

    if ((err = font_find(name, scaleWidth, scaleSize, 0, 0, &fontHandle)) == 0
        && fontHandle != 0)
    {
        /* Record font reference, handle and size */
        fonts[fontNumber] = fontHandle;
        draw_usedFont_init(1);
        draw_usedFont[*handle = fontHandle] += 1;
    }
    else
    {
        fonts[fontNumber] = -1;
    }

    *in = displaced;
    return (in + end);
}

/* Colour handling SWIs */
#define SWI_ColourTrans_ReturnFontColour 0x4074e
#define SWI_ColourTrans_SetFontColour    0x4074f

/*
 Function    : draw_text_setColour
 Purpose     : set colour for a given r, g, b value
 Parameters  : r, g, b intensities (as a palette entry, i.e. BBGGRRxx)
               (foreground and background)
 Returns     : void
 Description : selects the best colour for the given font and rgb values.
*/

#pragma -s1

static void  draw_text_setColour(int colour, int backcolour)
{
    os_regset r;

    r.r[0] = -1;
    r.r[1] = backcolour;
    r.r[2] = colour;
    r.r[3] = 14;

    /* Set the best approximation to the given colours */
    os_swi(SWI_ColourTrans_SetFontColour, &r);
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

static void draw_text_setup_colour(int colour, int backcolour, int out)
{
#ifdef draw_true_font_colour
    chunk[out++] = draw_true_font_colour;
    chunk[out++] = (char)((backcolour >> 8) & 0xff);
    chunk[out++] = (char)((backcolour >> 16) & 0xff);
    chunk[out++] = (char)((backcolour >> 24) & 0xff);
    chunk[out++] = (char)((colour >> 8) & 0xff);
    chunk[out++] = (char)((colour >> 16) & 0xff);
    chunk[out++] = (char)((colour >> 24) & 0xff);
    chunk[out++] = (char)(14);
#else
    os_regset r;

    r.r[0] = -1;
    r.r[1] = backcolour;
    r.r[2] = colour;
    r.r[3] = 14;

    /* Set the best approximation to the given colours */
    os_swi(SWI_ColourTrans_ReturnFontColour, &r);

    chunk[out++] = draw_font_colour;
    chunk[out++] = (char)(r.r[1] & 0xff);
    chunk[out++] = (char)(r.r[2] & 0xff);
    chunk[out++] = (char)(r.r[3] & 0xff);
#endif
}

#pragma -s0

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

static void draw_setVmove(int out, int move)
{
    chunk[out++] = draw_font_vmove;
    chunk[out++] = move & 0xff;
    chunk[out++] = (move & 0xff00) >> 8;
    chunk[out++] = (move & 0xff0000) >> 16;
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

static int draw_setLMPstate(int from, char *base, draw_linedata *state)
{
    int i;

    switch (base[from++])
    {
        case 'L':
            draw_getNum(from, base, &i, FALSE, &from);
            state->leading = draw_pointsToFont(i);
            break;

        case 'P':
            draw_getNum(from, base, &i, FALSE, &from);
            state->paraLeading = draw_pointsToFont(i);
            break;

        case 'M':
            draw_getNum(from, base, &i, FALSE, &from);
            state->lmargin = draw_pointsToFont(i);
            draw_getNum(from, base, &i, FALSE, &from);
            state->rmargin = draw_pointsToFont(i);
            break;

        case '-':
            from += 1;   /* Skip hyphen comment terminator */
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
               + number of \V sequences * 2
               + number of \U sequences
               + number of \C sequences * 2
               + number of \B sequences * 2
               + number of \- sequences
               + space for terminator and initial settings

               This does not allow for the string getting broken by a \A --
               but this is hard to test for, because of the initial case.

               Memory is then allocated if the current space is not large
               enough. If not, we don't report an error, but we do return
               FALSE.
*/

static BOOL  draw_text_allocate(char *from)
{
    int  extra = 10;     /* terminator, initial colour, underline, vmove */
    char *at;
    BOOL getOut = FALSE;
    int  length;

    /* Look for \ and newline */
    at = from;
    do
    {
        at += strcspn(at, "\n\\");
        if (*at == '\\')
        {
            switch (*(++at))
            {
                case 'L': case 'M': case 'P':
                    extra += 2+strcspn(at, "\n/");
                    at += strcspn(at, "\n/") + 1;
                    break;
                case 'B': case 'C':
                    extra += 2;
                    at += strcspn(at, "\n/") + 1;
                    break;
                case 'U':
                    extra += 1;
                    if (*(++at) != '.') at += strcspn(at, "\n/");
                    at += 1;
                    break;
                case '-':
                    extra += 1;
                    at += 1;
                    break;
                case 'V':
                    extra += 2;
                    if (*(++at) == '-') at += 2; else at += 1;
                    break;
                case '\n':
                    getOut = TRUE; break;
            }
        }
        else if (*at == '\n')
        {
            getOut = (*(++at) == '\n');
        }
    } while (*at != '\0' && !getOut);

    if ((length = extra + at - from) > chunkLen)
    {   int flexCode;

        /* Allocate new memory, or extend existing memory, in 1k units */
        chunkLen = ((length / 1024) + 1) * 1024;

        if (chunk == NULL)
        {
          if (Draw_allocator)
            flexCode = Draw_allocator((void **)&chunk, chunkLen);
          else flexCode = 0;
        }
        else
        {
          if (Draw_extender)
            flexCode = Draw_extender((void **)&chunk, chunkLen);
          else flexCode = 0;
        }
        Draw_memoryError = (flexCode == 0);
    }

    return (TRUE);
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
                  a font. The font reference is recorded in a table, and a
                  font handle generated for it. The handle is logged, so
                  we can lose it later. Both the size and width are in points.
                  The font name may have leading spaces.
               6. \<digit*> inserts a font change sequence.
               7. \L<number><newline> is replaced by a comment containing the
                  number and the newline - the rendition code must look for
                  this to determine the leading.
               8. \V[-]<digit> is replaced by a vertical move sequence, in
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
#define draw_text_termSkip(match, in) if (*(match) == '/') in += 1

static char *draw_text_getString(char *in, font *fonts, draw_linedata *state)
{
    int  getOut = FALSE;       /* Deep break */
    font currentFont;          /* Last font seen (default initially) */
    int  printing = FALSE;     /* TRUE when a print character seen */
    int  out;                  /* Offset into output buffer */

    currentFont = state->defaultFont;
    out = draw_insert;

    /* Allocate space for chunk */
    if (!draw_text_allocate(in)) return (NULL);

    /* Process end of string, or until we break out */
    while (*in && !getOut)
    {
        /* Length check */
        if (out >= chunkLen)
        {
           break;
        }

        if (*in == '\t')  /* tab -> space */
        {
            if (currentFont != -1) { chunk[out++] = ' '; printing = TRUE; }
            in += 1;
        }
        else if (*in == '\n')
        {
            if (currentFont == -1)  /* Skip newlines before first valid font */
            {
                in += 1;
            }
            else
            {
                /* Newline - paragraph break if either followed by another
                   newline, or if it is the first printable character */
                if (!printing || *(++in) == '\n')
                {
                    /* Paragraph termination */
                    chunk[out++] = '\n';
                    in += 1;
                    getOut = TRUE;
                }
                else
                {
                    /* Newline not preceded or followed by a space generates
                       a space */
                   if (chunk[out-1] != ' ' && *in != ' ' && *in != '\t')
                       chunk[out++] = ' ';
                }
            }
        }
        else if (*in < ' ') /* skip control character */
        {
            in += 1;
        }
        else if (*in != '\\')                    /* Ordinary character: copy */
        {
            if (currentFont != -1) { chunk[out++] = *in; printing = TRUE; }
            in += 1;
        }
        else                                        /* \ -> special sequence */
        {
            switch (*(++in))
            {
                case '\\':                              /* \\ : replace by \ */
                    if (currentFont != -1)
                    { chunk[out++] = '\\'; printing = TRUE; }
                    draw_text_termSkip(++in, in);
                    break;
                case ';':                          /* \; : delete to newline */
                    while (*in++ != '\n') ;
                    break;
                case '-':                                 /* \-: soft hyphen */
                    chunk[out++] = draw_font_comment;
                    chunk[out++] = '-';
                    chunk[out++] = '\n';
                    draw_text_termSkip(++in, in);
                    break;
                case '\n':                           /* \<nl> : split string */
                    draw_text_termSkip(++in, in);
                    getOut = TRUE;
                    break;
                case 'A':         /* \A : align sequence; maybe break string */
                {
                    /* If we have done any output, break on an align */
                    if (printing)
                    {
                        /* Step back over \A sequence */
                        in -= 1;
                        getOut = TRUE;
                    }
                    else
                    {
                        /* Get align code */
                        switch (*(++in))
                        {
                            case 'L': state->align = alignLeft;   break;
                            case 'R': state->align = alignRight;  break;
                            case 'C': state->align = alignCentre; break;
                            case 'D': state->align = alignDouble; break;
                        }
                        draw_text_termSkip(++in, in);
                    }
                    break;
                }
                case 'B':
                case 'C':                           /* \B, \C: colour change */
                {
                    int r, g, b;
                    BOOL foreground = (*in == 'C');

                    sscanf(++in, "%d %d %d", &r, &g, &b);
                    in = strpbrk(in, "\n/") + 1;

                    if (r < 0) r = 0; else if (r > 255) r = 255;
                    if (g < 0) g = 0; else if (g > 255) g = 255;
                    if (b < 0) b = 0; else if (b > 255) b = 255;

                    if (foreground)
                        draw_text_fg = b << 24 | g << 16 | r << 8;
                    else
                        draw_text_bg = b << 24 | g << 16 | r << 8;

                    draw_text_setup_colour(draw_text_fg, draw_text_bg, out);
                    out += 4;
                    break;
                }
                case 'D':
                {   int i;
                    draw_getNum(1, in, NULL, FALSE, &i);
                    in += i;
                    break;
                }
                case 'F':                     /* \F : handle font definition */
                {
                    int dummy;

                    in = draw_text_setFont(in+1, fonts, FALSE, &dummy);
                    break;
                }
                case 'L': case 'M': case 'P':               /* \L, \P, \M */
                    if (printing)
                    {
                        chunk[out++] = draw_font_comment;
                        while (!isTerm(*in)) chunk[out++] = *in++;
                        chunk[out++] = '\n';
                        in += 1;
                    }
                    else
                    {
                        in += draw_setLMPstate(0, in, state);
                    }
                    break;
                case 'U':                   /* \U : start or end underlining */
                {
                    if (*(++in) == '.')
                    {
                        /* Turn underlining off */
                        chunk[out++] = draw_font_underline;
                        chunk[out++] = 0;
                        chunk[out++] = 0;
                        draw_text_termSkip(++in, in);
                    }
                    else
                    {
                        int shift, thick;

                        /* Fetch two number from string */
                        sscanf(in, "%d %d", &shift, &thick);
                        in = strpbrk(in, "\n/") + 1;

                        shift = scaleup(shift);
                        thick = scaleup(thick);

                        if (shift > 127)  shift = 127;
                        if (shift < -128) shift = -128;
                        if (shift < 0)    shift = 256 + shift;

                        if (thick < 0)   thick = 0;
                        if (thick > 255) thick = 255;

                        /* Output underline sequence */
                        chunk[out++] = draw_font_underline;
                        chunk[out++] = shift & 255;
                        chunk[out++] = thick & 255;
                    }
                    break;
                }
                case 'V':                              /* \V : vertical move */
                {
                    int sign = 1000;    /* sign and conversion factor */
                    int points;
                    char *start;

                    start = ++in;
                    if (*in == '-') {sign = -1000; in += 1;}
                    points = scaleup((*in++ - '0') * sign);
                    draw_setVmove(out, points);
                    out += 4;

                    draw_text_termSkip(in, in);
                    break;
                }
                default:
                    if (isdigit(*in))
                    {
                        int fontNumber;
                        in = draw_text_getFontNum(in, &fontNumber);

                        /* \<number> : font selection */
                        if (fonts[fontNumber] != -1)
                        {
                            if (currentFont == -1 || !printing)
                            {
                                currentFont = fonts[fontNumber];
                                if (font_setfont(currentFont) != NULL)
                                    return (NULL);
                            }
                            else
                            {   /* Font change sequence */
                                chunk[out++] = draw_font_setfont;
                                chunk[out++] = currentFont = fonts[fontNumber];
                            }
                        }
                        /* else:  Bad font: no change */
                    }
                    break;
            }
        }
    }

    chunk[out] = '\0';
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

static int  draw_text_getLine(int offset, os_error **error, int width,
                              int *trueWidth, char *displaced)
{
    font_string fs;
    int         next = -1;
    int         i, space, hyphen, term;

    /* Width may be too small: produce a null string */
    if (width <= 0)
    {
        *displaced = chunk[offset];
        chunk[offset] = '\0';
        return (0);
    }

    /* Find where to split string */
    fs.x     = width;
    fs.y     = draw_bigvalue;
    fs.split = 32;
    fs.term  = draw_bigvalue;
    fs.s     = chunk + offset;

    if ((*error = font_strwidth(&fs)) != NULL)
        return(-1);

    /* Check that we were able to split the string at a space */
    if (fs.term == 0)
    {
        /* Split anywhere */
        fs.x     = width;
        fs.y     = draw_bigvalue;
        fs.split = -1;
        fs.term  = draw_bigvalue;
        fs.s     = chunk + offset;
        if ((*error = font_strwidth(&fs)) != NULL)
            return(-1);
    }

    /* Find hyphenation location, unless whole word fits */
    if (chunk[term = offset + fs.term] != '\n' && chunk[term] != '\0')
    {
        for (i = space = hyphen = offset ; i < term ; )
        {
            switch (chunk[i])
            {
                case draw_font_setfont: i += 2; break;
                case draw_font_vmove: case draw_font_colour: i += 4; break;
                case draw_font_underline: i += 3; break;
                case draw_font_comment:
                   if (chunk[i+1] != '-')
                   {
                       while (chunk[i++] != '\n');
                   }
                   else
                   {
                       hyphen = i;
                       i += 2;
                   }
                   break;
               case ' ': space = i++; break;
               default : i += 1; break;
           }
        }

        if (hyphen > offset && hyphen > space)
        {
            /* Insert the hyphen, and set the special displaced character */
            chunk[hyphen] = '-';
            next = hyphen + 1;
            *displaced  = draw_font_comment;
            chunk[next] = '\0';

            /* Recalculate true width */
            fs.x     = width;
            fs.y     = draw_bigvalue;
            fs.split = -1;
            fs.term  = draw_bigvalue;
            fs.s     = chunk + offset;
            if ((*error = font_strwidth(&fs)) != NULL)  return (-1);
            term = offset + fs.term;
        }
    }

    /* Break at the termination location, if we didn't hyphenate */
    if (next == -1)
    {
        /* Backtrack over spaces */
        next = term;
        if (chunk[next] == ' ')
        {
            while (chunk[--next] == ' ') ;
            next += 1;
        }

        /* Split the string */
        *displaced  = chunk[next];
        chunk[next] = '\0';

        /* Recalculate the exact width, if spaces were found */
        if (next != term)
        {
          fs.x     = width;
          fs.y     = draw_bigvalue;
          fs.split = -1;
          fs.term  = draw_bigvalue;
          fs.s     = chunk + offset;
          if ((*error = font_strwidth(&fs)) != NULL)  return (-1);
        }
    }
    *trueWidth = fs.x;

    return (next);
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

static void draw_text_newColumn(draw_textcolhdr *column,
                                draw_bboxtyp *box, int *basey)
{
    draw_bboxtyp *bbox;
    bbox = &(column->bbox);

    box->x0 = draw_drawToFont(bbox->x0);
    box->y0 = draw_drawToFont(bbox->y0);
    box->x1 = draw_drawToFont(bbox->x1);
    *basey = box->y1 = draw_drawToFont(bbox->y1);
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

static int draw_text_paintCheck(int offset, int y, draw_bboxtyp *clip,
                                draw_bboxtyp *box)
{
    font_info fi;

    /* Check base position is ok, and that the text is non-empty */
    if (y <= box->y0 || strlen(chunk+offset) == 0) return (draw_paint_LOW);
    y = scaleup(y);

    /* Get a bounding box for the string, and check it against boxes */
    font_stringbbox(chunk+offset, &fi);
    if (fi.miny + y < scaleup(box->y0)) return (draw_paint_LOW);

    if (fi.maxy + y > scaleup(box->y1)
        || scaleup(box->x1) < clip->x0 || scaleup(box->x0) > clip->x1
        || fi.maxy + y < clip->y0 || fi.miny + y > clip->y1)
    {
        int t;  /* Text index */

        /* Implement special sequences */
        for (t = offset ; chunk[t] != '\0' ; )
        {
            switch (chunk[t])
            {
                case draw_font_vmove: t += 4; break;
                case draw_font_colour:
                    font_setcolour(0, chunk[t+1], chunk[t+2], chunk[t+3]);
                    t += 4;
                    break;
                case draw_font_comment:
                    while (chunk[t++] != '\n') ;
                    break;
                case draw_font_underline: t += 3; break;
                case draw_font_setfont:
                    font_setfont((font)chunk[t+1]);
                    t += 2;
                    break;
                default: t += 1; break;
            }
        }

        return (draw_paint_SKIP);
    }

    return (draw_paint_OK);
}

/*
 Function    : draw_text_paint
 Purpose     : paint the current line
 Parameters  : chunk offset
               displaced character from line
               left limit, right limit
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

static os_error *draw_text_paint(int offset,
                          char displace,
                          int x0, int x1,
                          draw_align align,
                          int trueWidth,
                          int orgx, int y)
    /*int  offset;
    char displace;
    int  x0, x1;
    draw_align align;
    int  trueWidth, orgx, y;*/
{
    os_error *err = NULL;
    int      x;
    int      plotType = font_ABS;

    /* Get plot point, allowing for alignment and scaling */
    if (align == alignDouble && displace != '\0' && displace != '\n')
        plotType |= font_JUSTIFY;

    if (align == alignRight)
        x = (int)(scalefactor * x1 - trueWidth);
    else if (align == alignCentre)
        x = (int)((scalefactor * (x1 + x0) - trueWidth)/2);
    else
    {
        if (plotType & font_JUSTIFY)
        {
            /* Do move for the alignment box */
            bbc_move((int)draw_fontToOS(scaleupX(x1)),
                     (int)draw_fontToOS(y));
        }
        x = scaleup(x0);
    }

    /* Paint the text, unless empty. */
    if (chunk[offset])
    {
        err = font_paint(chunk+offset, plotType, orgx+x, y);
    }

    return (err);
}

/*
 Function    : draw_textPatchup
 Purpose     : patchup when exiting draw_textArea
 Parameters  : void
 Returns     : void
 Description : frees the chunk if need be, and releases all the fonts
*/

static void draw_textPatchup()
{
    int  i;

    if (chunk && Draw_freer) Draw_freer((void **) &chunk);

    draw_usedFont_init(1);

    /* Lose all the fonts */
    for (i = 0 ; i < 256 ; i++)
    {
        while (draw_usedFont[i] > 0)
        {
            font_lose((font)i);
            draw_usedFont[i] -= 1;
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
 Description : called after a line has been output to note the state parameters
               that will apply to the next line.
               Affects underline, vertical move, margin and line/paragraph
               spacing state.
*/

static void draw_text_stateScan(char *chunk, int start, int end, draw_linedata *state)
{
    int c;

    /* Scan for state parameters */
    for (c = start ; c < end ; )
    {
        switch (chunk[c++])
        {
            case draw_font_setfont: c += 1; break;
            case draw_font_colour:  c += 3; break;
            case draw_font_vmove:
                state->vmove += chunk[c] + chunk[c+1] <<8 + chunk[c+2] <<16;
                c += 3;
                break;
            case draw_font_underline:
                state->under1 = chunk[c];
                state->under2 = chunk[c+1];
                c += 2;
                break;
            case draw_font_comment:
                c = draw_setLMPstate(c, chunk, state);
                break;
/*          default: do nothing */
        }
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

static BOOL draw_textArea(draw_objptr hdrptr, int orgx, int orgy,
                          draw_bboxtyp *clip, os_error **error)
{
    int      i, y;
    char     *text;
    os_error *err;
    BOOL     newColumn = FALSE;
    font     fonts[draw_text_maxFonts+1];
    draw_bboxtyp     box;
    draw_textareaend *endptr = draw_text_findEnd(hdrptr);
    draw_textcolhdr  *column = &(hdrptr.textareastrp->column);
    draw_linedata    state;

    /* Malloc draw_usedFont to save space in the shared library */
    if (draw_usedFont == 0) draw_usedFont = malloc(256*sizeof(int));

    /* Find start colours and save them */
    draw_text_fg = endptr->textcolour;
    draw_text_bg = endptr->backcolour;
    if (draw_text_fg == TRANSPARENT)
      draw_text_fg = draw_text_bg;

    /* Set default state data */
    state.defaultFont = -1;
    state.leading     = draw_pointsToFont(10);
    state.paraLeading = draw_pointsToFont(10);
    state.lmargin     = draw_pointsToFont(1);
    state.rmargin     = draw_pointsToFont(1);
    state.align       = alignLeft;
    state.under1      = state.under2 = 0;
    state.vmove       = 0;

    /* Set initial colour */
    draw_text_setColour(draw_text_fg, draw_text_bg);

    /* Some size constants and initial position */
    orgx = draw_drawToFont(orgx);
    orgy = draw_drawToFont(orgy);

    /* Initialise arrays and defaults */
    for (i = 0 ; i < 256 ; i++) draw_usedFont[i] = 0;
    for (i = 0 ; i <= draw_text_maxFonts  ; i++) fonts[i] = -1;

    /* Point to text and skip ID string (guaranteed present) */
    for (text = &(endptr->text[0]) ; !isTerm(*text) ; text++) ;

    /* Load parameters for first column */
    draw_text_newColumn(column++, &box, &y);

    /* While there is text to process */
    while (*text)
    {
        int  c = draw_insert;        /* Offset in chunk */

        /* Select default font, if any */
        if (state.defaultFont != -1 &&
            (err = font_setfont(state.defaultFont)) != NULL)
        {
            *error = err;
            draw_textPatchup();
            return (FALSE);
        }

        /* Set up chunk */
        if ((text = draw_text_getString(text, fonts, &state)) == NULL)
        {
            /* Error in chunk: probably too long */
            *error = NULL;
            draw_textPatchup();
            return (FALSE);
        }

        /* Ensure chunk is not empty */
        if (chunk[c] != '\0' && chunk[c] != '\n')
        {
            int  trueWidth, scaledWidth, x0, x1, next;
            char displaced;

            /* Loop over each line in the chunk */
            while (chunk[c] != '\0' && chunk[c] != '\n')
            {
                /* If necessary, move to a new column */
                if (newColumn)
                {
                    if (column->tag == draw_OBJTEXTCOL)
                    {
                        /* Find new column parameters */
                        draw_text_newColumn(column++, &box, &y);
                        newColumn = FALSE;
                    }
                    else /* No more columns */
                    {
                        draw_textPatchup();
                        return (TRUE);
                    }
                }

                /* Shift the box sides to allow for the margin */
                x0 = box.x0 + state.lmargin;
                x1 = box.x1 - state.rmargin;

                /* Insert the state data into the string (yukky) */
                c -= draw_insert;       /* Guaranteed to be enough room */
                chunk[c]   = draw_font_underline;
                chunk[c+1] = state.under1;
                chunk[c+2] = state.under2;
                draw_setVmove(c+3, state.vmove);

                /* Get line */
                scaledWidth = scaleup(x1 - x0);
                if ((next = draw_text_getLine(c, error, scaledWidth,
                                              &trueWidth, &displaced)) == -1)
                {
                    draw_textPatchup();
                    return (FALSE);
                }

                /* Set new base position */
                y -= state.leading;

                /* Plot if we are still in box (may fail with descenders) */
                switch (draw_text_paintCheck(c, y, clip, &box))
                {
                    case draw_paint_OK:
                    {
                        if (state.defaultFont != -1 &&
                            (err = draw_text_paint(c, displaced, x0, x1,
                                    state.align, trueWidth, orgx, scaleupY(y)))
                             != NULL)
                        {
                            draw_textPatchup();
                            return (FALSE);
                        }
                        /* Fall into skip case */
                    }
                    case draw_paint_SKIP:
                        draw_text_stateScan(chunk, c, next, &state);
                        c = (displaced == ' ') ? next + 1 :
                            (displaced == draw_font_comment) ? next + 2 : next;
                        while (chunk[c] == ' ') c++;   /* Skip extra spaces */
                        break;

                    case draw_paint_LOW:
                        newColumn = TRUE;
                        c += draw_insert; /* Teeny fiddle */
                        break;
                }

                /* Restore split character, allowing for hyphens */
                if (displaced == draw_font_comment)
                {
                    chunk[next-1] = draw_font_comment;
                    chunk[next]   = '-';
                }
                else
                    chunk[next] = displaced;

                /* At the end of a paragraph, shift by para leading */
                if (displaced == '\n') y -= state.paraLeading;
            }
        }
        else
        {
            /* Chunk is empty - treat it as a null paragraph */
            y -= state.paraLeading;
        }
    }

    *error = NULL;
    draw_textPatchup();
    return (TRUE);
}


/*
 Function    : draw_verifyTextArea
 Purpose     : check text area definition
 Parameters  : pointer to start
               OUT: error code
               OUT: error location
               OUT: number of columna
 Returns     : TRUE if ok
 Description : check that all special sequences in the object are OK.

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

BOOL draw_verifyTextArea(char *text, int *errcode, char **location, int *columns)
{
    char *end;
    font fonts[draw_text_maxFonts+1]; /* Font table: digit->fontHandle */
    int  seenColumns = FALSE;
    int  handle;

    end = text + strlen(text);
    *columns = 1;
    *location = text;

    /* Check ID heading */
    if (*text++ != '\\' || *text++ != '!')
    {
        *errcode = draw_CorruptTextArea;
        return (FALSE);
    }
    else
    {
        int  version = -1, offset;

        if (draw_getNum(0, text, &version, TRUE, &offset) != draw_numOK
            || version != draw_text_VERSION)
        {
            *errcode = draw_TextAreaVersion;
            return (FALSE);
        }
        text += offset;
    }

    /* Ensure clean termination so we don't need to check for null later */
    if (*(end - 1) != '\n')
    {
        *errcode = draw_MissingNewline;
        return (FALSE);
    }

    /* Look for special sequence */
    while (text < end && *(text += strcspn(text, "\\\n")) != '\0')
    {
        if (*text == '\n')
        {
            text    += 1;
            continue;
        }

        *location = text+1;

        switch (*(++text))
        {
            case '-': case '\\':
                text += 1; break;
            case '\n':
                text += 1; break;
            case ';':                                           /* \;: skip */
                while (*text++ != '\n') ;
                break;
            case 'A':               /* \A: must be followed by L, R, C or D */
                if (strchr("LRCD", *(++text)) == NULL)
                {
                    *errcode = draw_BadAlign;
                    return (FALSE);
                }
                if (*(++text) == '/') text += 1;
                break;
            case 'B':
            case 'C':             /* \B or \C followed by three numbers */
            {
                int  i;

                if (draw_getNum (1, text, NULL, FALSE, &i) != draw_numMORE
                    || draw_getNum(i, text, NULL, FALSE, &i) != draw_numMORE
                    || draw_getNum(i, text, NULL, FALSE, &i) != draw_numOK)
                {
                    *errcode = draw_BadTerminator;
                    return (FALSE);
                }
                text += i;
                break;
            }
            case 'D':                             /* \D: get no. of columns */
            {
                if (seenColumns)
                {
                    *errcode = draw_ManyDCommands;
                    return (FALSE);
                }
                else
                {   int i;
                    if (draw_getNum(1, text, columns, FALSE, &i) != draw_numOK)
                    {
                        *errcode = draw_BadTerminator;
                        return (FALSE);
                    }
                    else
                    {
                        seenColumns = TRUE;
                        text += i;
                    }
                }
                break;
            }
            case 'F':                          /* \F: check font definition */
            {
                int fontNum;
                char *fontDefText;

                while (*(++text) == ' ') ;
                text = draw_text_getFontNum(fontDefText = text, &fontNum);
                if (fontNum == -1)
                {
                    *errcode = draw_BadFontNumber;
                    return (FALSE);
                }
                else
                {
                    int  sizeTerm, i;

                    /* Skip to a non-space, i.e. to start of name */
                    while (text < end && *text == ' ') text += 1;

                    /* Look for terminating space, i.e. to end of name */
                    while (text < end && *text != ' ') text += 1;
                    if (*text != ' ')
                    {
                        *errcode = draw_UnexpectedCharacter;
                        return (FALSE);
                    }

                    if ((sizeTerm = draw_getNum(0, text, NULL, FALSE, &i))
                                      == draw_numMORE)
                    {
                        /* Read second number */
                        if (draw_getNum(i, text, NULL, FALSE, &i) !=draw_numOK)
                        {
                            *errcode = draw_BadFontWidth;
                            return (FALSE);
                        }
                    }
                    else if (sizeTerm == draw_numBAD)
                    {
                        *errcode = draw_BadFontSize;
                        return (FALSE);
                    }

                    /* Try to load the font */
                    draw_text_setFont(fontDefText, fonts, FALSE, &handle);

                    if (handle != -1) font_lose(handle);
                    text += i;
                }
                break;
            }
            case 'L': case 'P':  /* \L, \P: must be followed by <number><nl> */
            {
                int  i;

                if (draw_getNum(1, text, NULL, FALSE, &i) != draw_numOK)
                {
                    *errcode = draw_BadTerminator;
                    return (FALSE);
                }
                text += i;
                break;
            }
            case 'M':               /* \M: check numbers */
            {   int i;

                if (draw_getNum(1, text, NULL, FALSE, &i) != draw_numMORE
                    || draw_getNum(i, text, NULL, FALSE, &i) != draw_numOK)
                {
                    *errcode = draw_BadTerminator;
                    return (FALSE);
                }
                text += i;
                break;
            }
            case 'U':               /* \U: \U. or \U<n1><space><n2> */
                if (*(++text) != '.')
                {   int i;

                    if (draw_getNum(0, text, NULL, TRUE, &i) != draw_numMORE
                        || draw_getNum(i, text, NULL, FALSE, &i) != draw_numOK)
                    {
                        *errcode = draw_BadTerminator;
                        return (FALSE);
                    }
                    text += i;
                }
                break;
            case 'V':        /* \V: must be followed by -<digit> or <digit> */
                if (*(++text) == '-') text += 1;
                if (!isdigit(*text++))
                {
                    *errcode = draw_NonDigitV;
                    return (FALSE);
                }
                if (*(++text) == '/') text += 1;
                break;
            default:                               /* \<other>: digits only */
                if (!isdigit(*text))
                {
                    *errcode = draw_BadEscape;
                    return (FALSE);
                }
                else
                {
                    int fontNumber;
                    text = draw_text_getFontNum(text, &fontNumber);
                    if (fontNumber == -1)
                    {
                        *errcode = draw_BadFontNumber;
                        return (FALSE);
                    }
                    if (*text == '/') text += 1;
                }
                break;
        }
    }

    if (*columns < 1)
    {
        *errcode = draw_FewColumns;
        return (FALSE);
    }

    return (TRUE);
}

/*
 Function    : do_objtextarea
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

os_error *do_objtextarea(draw_objptr hdrptr, int orgx, int orgy,
                                             draw_bboxtyp *clip)
{
    os_error *err;

    /* Convert clipping box into screen coordinates */
    clip->x0 = scaleup(draw_drawToFont(clip->x0));
    clip->y0 = scaleup(draw_drawToFont(clip->y0));
    clip->x1 = scaleup(draw_drawToFont(clip->x1));
    clip->y1 = scaleup(draw_drawToFont(clip->y1));

    chunk = NULL;
    chunkLen = 0;

    draw_textArea(hdrptr, orgx, orgy, clip, &err); /* No error check */
    return(err);
}

/*
 Function    : do_objtextcol
 Purpose     : render a text column object
 Parameters  : header pointer
               x, y origins
               cliiping box in data base coordinates
 Returns     : os_error or Null
 Description : find the parent and render it
*/

os_error *do_objtextcol(draw_objptr hdrptr, int orgx,int orgy,
                                            draw_bboxtyp *clip)
{
  return(do_objtextarea(draw_text_findParent(hdrptr.textcolp),
                        orgx, orgy, clip
                       )
        );
}


BOOL drawtextc_init(void)
{
    draw_usedFont_init(0);
    return (draw_usedFont != 0);
}
