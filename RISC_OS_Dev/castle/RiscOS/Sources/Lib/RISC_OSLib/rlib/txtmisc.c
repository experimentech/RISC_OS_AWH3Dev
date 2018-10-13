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
/*
 * Title: txtmisc.c
 * Purpose: Search text for string.
 * Author: AFP
 * Status: system-independent
 * Requires:
 *   h.txt
 * History:
 *   16 Jul 87 -- started
 *   18 Dec 87: AFP: converted into C.
 *   02 Mar 88: WRS: improved use of trace.
 *   17 Mar 88: IGJ: txtmisc_formattxt added
 *    1 Jun 90: NDR: txtmisc wordwrap routines moved here from c.txtedit
 *    8 May 91: ECN: #ifndefed out unused ROM functions
 *   11 Jun 91: IDJ: expand tabs and CR<>LF now set modified flag
 */

#define BOOL int
#define TRUE 1
#define FALSE 0

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#include "werr.h"
#include "txt.h"
#include "flex.h"
#include "txtscrap.h"
#include "EditIntern/txtmisc.h"
#include "EditIntern/txtundo.h"
#include "trace.h"
#include "msgs.h"
#include "VerIntern/messages.h"

int txtmisc_alphach(char c)

/* We try to cover the letters with accents on them too. Is this right?
Not sure. */

{

return(((c >= 'a') && (c <= 'z')) ||
       ((c >= 'A') && (c <= 'Z')) ||
       ((c >= '0') && (c <= '9')) ||
       (c >= 128+64));

}

txt_index txtmisc_bow(txt t, txt_index i)

{

if (i > 0 && txt_charat(t, i - 1) == '\n')
     --i;
while (i > 0 && txtmisc_alphach(txt_charat(t, i - 1)) && txt_charat(t, i - 1) != '\n')
     --i;
while (i > 0 && !txtmisc_alphach(txt_charat(t, i - 1)) && txt_charat(t, i - 1) != '\n')
     --i;

return(i);

}




txt_index txtmisc_eow(txt t, txt_index i)

{

txt_index lim;

lim = txt_size(t);
if (i < lim && txt_charat(t, i) == '\n')
     ++i;
while (i < lim && txtmisc_alphach(txt_charat(t, i)) && txt_charat(t, i) != '\n')
     ++i;
while (i < lim && !txtmisc_alphach(txt_charat(t, i)) && txt_charat(t, i) != '\n')
     ++i;
return(i);

}



/* beginning of line */
txt_index txtmisc_bol(txt t, txt_index i)

{

while (i > 0 && (txt_charat(t, i - 1) != '\n'))
     --i;
return(i);

}



/* end of line */
txt_index txtmisc_eol(txt t, txt_index i)

{

txt_index lim;

lim = txt_size(t);

while (i < lim && (txt_charat(t, i) != '\n'))
     ++i;
return(i);

}


#ifndef UROM
int txtmisc_bof(txt t)
{

return(txt_dot(t) == 0);

}
#endif


int txtmisc_eof(txt t)
{
return(txt_dot(t) == txt_size(t));
}



unsigned txtmisc_currentlinenumber(txt t)

{

txt_index at;
unsigned size;
char *a;
int n,j,line;

size = txt_dot(t);
at = 0;
line = 1;

while (at != size)

     {
     txt_arrayseg(t, at, &a, &n);
     n = (n < size) ? n : size;
     for (j = 0; j < n; j++)
        if (a[j] == '\n')
          ++line;
     at += n;
     }
return(line);

}




void txtmisc_gotoline(txt t, unsigned l)

{

txt_index at;
unsigned size;
char *a;
int n,j=0;

if (l == 1) /* move to top of file */
  txt_setdot(t, 0);

if (l > 1)

  {

  size = txt_size(t);
  at = 0;
  while (at != size && l != 1)
       {
       txt_arrayseg(t, at, &a, &n);
       for (j = 0; (j < n && l != 1); j++)
           if (a[j] == '\n')
            --l;
       if (l != 1)
         {
         at += n;
         j = 0;
         }
       }

  txt_setdot(t, at+j);

  }
}


static int txtmisc_blackch(char c)

{
return(c != ' ' && c != '\n' && c != 0);
}

void txtmisc_tab(txt t)

/* This implementation is somewhat of a cheat, in that I move up
to the line above, hit cursor right a few times, and go back down
again. Various things can go wrong, e.g. with wrapped lines. In tests,
doing a tab with the line above wrapped is particularly noticable. */

{

txt_index to, dot;
int       topline;
BOOL      endoflineabove = FALSE;


txt_setcharoptions(t, txt_CARET, 0);

dot = txt_dot(t);

txt_movevertical(t, -1, NULL); /* move to line above */

topline = (dot == txt_dot(t)) ? 0 : 1;

dot = txt_dot(t);

to = dot;

while (txtmisc_blackch(txt_charat(t, to)))
     ++to;

if (txt_charat(t, to) == '\n') endoflineabove = TRUE;

while (txt_charat(t, to) == ' ')
     ++to;

txt_setdot(t, to);

if (topline)
  txt_movevertical(t, 1, NULL); /* and move back to line below again */

if (endoflineabove) txt_setdot(t, txtmisc_bol(t, txt_dot(t)));

txt_setcharoptions(t, txt_CARET, txt_CARET);

}

void txtmisc_tabcol(txt t) {
/* If the dot is at a newline then the whole thing is different: tabbing
affects the horizontal tab offset, rather than moving you in the file. There
is a problem in that you can't tell about the existing horizontal tab at the
txt interface: BUT YOU CAN, by inserting a space and seeing how many spaces
appear! Then undo this, and presto. */

  txt_index i = txt_dot(t);
  BOOL atnewline = txt_charatdot(t) == '\n' || txt_dot(t) == txt_size(t);
  int currentoffset = 0;

  if (atnewline) {
    txt_charoption opts = txt_charoptions(t);
    if ((txt_CARET & opts) != 0) txt_setcharoptions(t, txt_CARET, 0);
    txtundo_separate_major_edits(t);
    txt_insertchar(t, ' ');
    /* Turning off display loses your horizontal offset, so it must be done
    after the insertchar. */
    currentoffset = txt_dot(t) - i;
    while (txtundo_undo(t) == txtundo_MINOR); /* undo the insert. */
    txtundo_commit(t); /* totally forget the insertion and its reversal */
    if ((txt_CARET & opts) != 0) txt_setcharoptions(t, txt_CARET, txt_CARET);
  };

  while (i > 0 && txt_charat(t, i-1) != '\n') i--; /* i now start of line */
  i = txt_dot(t) - i; /* i now length of line */
  if (atnewline) i += currentoffset; /* i now current col position. */
  while (i >= 8) i -= 8; /* i now fraction of tab col that we stick out over */
  i = 8 - i; /* i now no of spaces to insert; */

  if (atnewline) {
    txt_movehorizontal(t, currentoffset + i);
  } else {
    txt_replacechars(t, 0, "        ", i);
    txt_movedot(t, i);
  };

}

void txtmisc_expandtabs(txt t)

{

char c, *spaces = "        ";
txt_index at, size, dot;
unsigned col, nspaces;

at = col = 0;
size = txt_size(t);
dot = txt_dot(t);
 txt_setcharoptions(t, txt_DISPLAY, 0);
while (at != size)
      {
      if ((c = txt_charat(t, at)) == '\n')
         {
         ++at;
         col = 0;
         }
      else if (c == 9)
         {
         txt_setdot(t, at);
         nspaces = 8 - col % 8;
         txt_replacechars(t, 1, spaces, nspaces);
         size += (nspaces - 1);
         if (at < dot)
            dot += (nspaces - 1);
         }
      else
         {
         ++at;
         ++col;
         }
      }
txt_setdot(t, dot);

txt_setcharoptions(t, txt_DISPLAY, txt_DISPLAY);
}



void txtmisc_indentregion(txt t, txt_index from, txt_index to, int by,
                          char *with)

{
unsigned cby, del, del1;
int big;
txt_marker savedot;

if (from != 0)
   {
   from = txtmisc_eol(t, txtmisc_bol(t, from - 1)); /* now on a NewLineCh. */
   ++from; /* now at the start of a line */
   }
to = (to < txt_size(t)) ? to : txt_size(t);
if (by == 0)
   return;

if (by > 0)
   {
   cby = (by < strlen(with)) ? by : strlen(with);
   del = 0;
   }
else
   {
   cby = 0;
   del = -1 * by;
   }
big = to > from + 1000;
if (big)
   txt_setcharoptions(t, txt_DISPLAY, 0);
txt_newmarker(t, &savedot);
while (from < to)
      {
      txt_setdot(t, from);
      if (txt_charatdot(t) != '\n')
         /* don't do anything to blank lines */
         {
         int linelen = txtmisc_eol(t, from) - from;
         del1 = (del < linelen) ? del : linelen; /* 22-Nov-88 WRS: bug fix. */
         txt_replacechars(t, del1, with, cby);
         to += cby;
         to -= del1;
         }
      if (cby > 0 && txt_selectstart(t) > txt_dot(t))
         /* only for first line: we fail to select inserted chars */
         txtscrap_setselect(t, txt_selectstart(t) - cby, txt_selectend(t));
      from = txtmisc_eol(t, from) + 1;
      /* the EOL is done twice because the Replace affects its value. */
      }
txt_movedottomarker(t, &savedot);
txt_disposemarker(t, &savedot);
if (big)
   txt_setcharoptions(t, txt_DISPLAY, txt_DISPLAY);
}


void txtmisc_exchangecrlf(txt t)

{

txt_index at;
unsigned size, j;
int n;
char *a, c;
BOOL updated = FALSE;

txt_setcharoptions(t, txt_DISPLAY, 0);
size = txt_size(t);
at = 0;
while (at != size)
      {
      txt_arrayseg(t, at, &a, &n);
      for (j = 0; j < n; j++)
          {
            if ((c = a[j]) == '\n')
            {
               updated = TRUE;
               a[j] = '\r';
            }
            if (c == '\r')
            {
               updated = TRUE;
               a[j] = '\n';
            }
          }
      at += n;
      }
txt_setcharoptions(t, txt_DISPLAY, txt_DISPLAY);
if (updated) txt_setcharoptions(t, txt_UPDATED, txt_UPDATED);
txtundo_purge_undo(t);
}

/* -------- Selection utilities. -------- */


txt_index txtmisc_furthestaway(txt t, txt_index from, txt_index a1,
                               txt_index a2)

{
t=t;
if (from <= (a1 + a2) / 2)
   return((a1 > a2) ? a1 : a2);
else
   return((a1 < a2) ? a1 : a2);
}


void txtmisc_select3(txt t, txt_index a1, txt_index a2, txt_index a3)

{

txt_index a4;

txtscrap_setselect(t, (a1 < (a4 = (a2 < a3) ? a2 : a3)) ? a1 : a4,
                   (a1 > (a4 = (a2 > a3) ? a2 : a3)) ? a1 : a4);
}


static BOOL txtmisc__linenonalpha(txt t, txt_index i) {
  char c = txt_charat(t, i);
  if (i > txt_size(t)) return FALSE;
  if (i < 0) return FALSE;
  if (txtmisc_alphach(c)) return FALSE;
  if (c == '\n') return FALSE;
  return TRUE;
}

void txtmisc_selectpointandword(txt t, txt_index point, txt_index word)

{

txt_index begin = word;
txt_index end = begin;
txt_index size = txt_size(t);

if (txtmisc_alphach(txt_charat(t, begin - 1))
    ||
    txtmisc_alphach(txt_charat(t, end)))
{
  /* We are pointed at a word. */
  while (begin > 0 && txtmisc_alphach(txt_charat(t, begin - 1))) begin--;
  while (txtmisc_alphach(txt_charat(t, end))) end++;
  if (txt_charat(t, end) == '\n' || end == size) {
    /* There is no whitespace after this word - gobble up whitespace before it. */
    while (txtmisc__linenonalpha(t, begin - 1)) begin--;
  } else {
    /* There is whitespace after this word - gobble it up (default case) */
    while (txtmisc__linenonalpha(t, end)) end++;
  };
} else {
  /* We are pointed at whitespace. */
  while (txtmisc__linenonalpha(t, begin - 1)) begin--;
  while (txtmisc__linenonalpha(t, end)) end++;
  if (begin == 0 || txt_charat(t, begin - 1) == '\n') {
    /* We are at the left end of a line - gobble up the word on the right */
    while (txtmisc_alphach(txt_charat(t, end))) end++;
  } else {
    /* Gobble up the word on the left (default case). */
    while (begin > 0 && txtmisc_alphach(txt_charat(t, begin - 1))) begin--;
  };
};

txtmisc_select3(t, point, begin, end);

}


void txtmisc_selectpointandline(txt t, txt_index point, txt_index line)

{

txt_index begin, end;

begin = txtmisc_bol(t, line);
end = 1 + txtmisc_eol(t, begin);
txtmisc_select3(t, point, begin, end);

}

/* -------- Wordwrap -------- */

/* This incorrectly resides in txtedit at the moment. */
void txtmisc_normalisepara(
  txt t,
  int parawidth
);

/* -------- Wordwrap. -------- */

#if WORDWRAP

BOOL txtmisc_paraend(txt t, txt_index i) {
  if (txt_size(t) <= i) return TRUE;
  if (txt_charat(t, i) != '\n') return FALSE;
  if (i == 0) return TRUE;
  if (txt_charat(t, i-1) == '\n') return TRUE;
  if (txt_size(t) == i+1) return TRUE;
/*  return strchr("\n .", txt_charat(t, i+1)) != 0; */
  {
    char ch = txt_charat(t, i+1);
    if (ch == '\n') return TRUE;
    if (ch == ' ') return TRUE;
    if (ch == '.') return TRUE;
    return FALSE;
  };
}

#ifndef UROM
BOOL txtmisc_parastart(txt t, txt_index i) {
  if (i == 0) return TRUE;
  if (txtmisc_paraend(t, i-1)) return TRUE;
  if (i == 1) return FALSE;
  return (txtmisc_paraend(t, i-2));
}
#endif

#ifndef UROM
txt_index txtmisc_bop(txt t, txt_index i) {
  while (!txtmisc_parastart(t, i)) {
    i = txtmisc_bol(t, i-1);
  };
  return i;
}
#endif

txt_index txtmisc_eop(txt t, txt_index i) {
  while (!txtmisc_paraend(t, i)) {
    i = txtmisc_eol(t, i+1);
  };
  return i;
}

void txtmisc_normalisepara(
  txt t,
  int parawidth
)
/* Usually called during typin (flag-controlled), after the insertion but before
the advancement of the caret. Normalise the characters from the caret to the
next end-of-paragraph, converting between spaces and newlines in order to
improve layout. Do this all in a separate memory block and then do a single
txt_replacechars in order to manufacture the resulting effect.

Bugs: limited buffer size
*/

#define PSIZ 512

/* It's reasonable to have a maximum on the amount that you're prepared to look
ahead. If the result ripples ahead more than this, tough luck. */
/* If parawidth is more than this it won't work very well. */

{
    char c[PSIZ];
    int paramax;
    int at = 0; /* index of current point into c. */
    int col = 0; /* column of current point. */
    txt_index dot;
    txt_index parastart;
    int minchange;
    int maxchange;
    int hascaret = txt_charoptions(t) & txt_CARET;
    BOOL modified = FALSE;
    BOOL bufoverflow = TRUE;

    tracef1("normalisepara width=%i.\n", parawidth);
    if (parawidth == 0) return; /* do no formatting. */

    dot = txt_dot(t);
    parastart = txtmisc_bol(t, dot);

    while (bufoverflow) {
      /* We only loop here if the paragraph is larger than PSIZ, e.g. our work
      buffer is not big enough. */
      int prevat = at;
      int prevcol = col;
      int prevprevat;
      int prevprevcol;

      /* col == dot's current column position. */
      tracef2("dot=%i, dot para start=%i.\n", dot, parastart);

      /* Fill the buffer from parastart to the next end of paragraph. */
      paramax = 0;
      while (paramax < PSIZ && !txtmisc_paraend(t, parastart + paramax)) {
        c[paramax] = txt_charat(t, parastart + paramax);
        paramax++;
      };
      /* c[paramax] is the final NewLineCh, or is beyond the end of file. */
      tracef1("paramax = %i.\n", paramax);

      minchange = paramax;
      maxchange = 0;
      /* c[minchange]..c[maxchange] must be updated in the text buffer. */

      while (1) {
        int nextwhite;
        int nextwhitecol;

        prevprevat = prevat;
        prevprevcol = prevcol;
        prevat = at;
        prevcol = col;

        while (c[at] != '\n' && c[at] != ' ' && at < paramax) { /* hop over word */
          at++;
          col++;
        };
        while ((c[at] == '\n' || c[at] == ' ') && at < paramax) { /* hop over gap */
          at++;
          col++;
        };
        if (at == paramax) {
          if (paramax != PSIZ) {
            bufoverflow = FALSE; /* "usual" exit route from the loop */
          };
          break;
        };
        /* We are now at the start of a word, at>0, or at==paramax cos the buffer's not big enough. */
        tracef2("word start: at=%i col=%i.\n", at, col);

        nextwhite = at;
        while (c[nextwhite] != '\n' && c[nextwhite] != ' ' && nextwhite < paramax) { /* find end of word */
          nextwhite++;
        };
        if (nextwhite == PSIZ) {
          /* the buffer's not big enough. */
          break;
        };
        nextwhitecol = col + nextwhite - at;

        at--; /* point at the whitespace before */
        if (nextwhitecol > parawidth) { /* or >= perhaps? */
          if (c[at] == ' ') { /* this should be a newline */
            c[at] = '\n';
            if (minchange > at) minchange = at;
            if (maxchange <= at) maxchange = at+1;
          };
        } else {
          if (c[at] == '\n') { /* this should be a space */
            c[at] = ' ';
            if (minchange > at) minchange = at;
            if (maxchange <= at) maxchange = at+1;
          };
        };
        if (c[at] == '\n') col = 0;
        at++; /* point at the word start */
      }; /* end while */

      if (minchange < maxchange) {
        /* there is some changing to do. */
        tracef2("update %i..%i.\n", minchange, maxchange);
        if ((! modified) && (hascaret != 0)) txt_setcharoptions(t, txt_CARET, 0);
        txt_setdot(t, parastart + minchange);

        /* At this point we'd like to just do the replace, but we also want to preserve
        the positioning of the selection start and end, if they are affected. */
        /* Arguably this should be a flag to replacechars - e.g. do not affect the position of
        markers within the replaced area? */
        {
          txt_index selstart = txt_selectstart(t);
          txt_index selend = txt_selectend(t);
          txt_index here = txt_dot(t);
          txt_replacechars(t, maxchange - minchange, &c[minchange], maxchange - minchange);
          if ((selstart >= here && selstart <= here + maxchange - minchange)
          || (selend >= here && selend <= here + maxchange - minchange)) {
            txt_setselect(t, selstart, selend);
          };
        };
        modified = TRUE;
      } else {
        tracef0("Not updating.\n");
      }; /* if */

      if (bufoverflow) { /* we're going to be looping. */
        if (prevat == 0) {
          /* a word longer than the buffer - don't really care as long as we advance */
          parastart += at;
          /* col stays as it is. */
        } else if (prevprevat == 0) {
          /* words so long that two words spans the buffer */
          parastart += prevat;
          col = prevcol;
        } else {
          /* normal case - go back two words, to ensure that we get all possible
          line breaks correct. */
          parastart += prevprevat;
          col = prevprevcol;
        };
        at = 0;
      };

    }; /* while */

    if (modified) {
      txt_setdot(t, dot);
      if (hascaret != 0) txt_setcharoptions(t, txt_CARET, txt_CARET);
    };
}
/* Should be able to go round again if the paragraph is bigger than the buffer. */

#endif

