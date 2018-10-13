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
  Purpose: File load and save operations for Text objects
  Author: WRS
  Status: under development
  History:
    18 August 87: started
    14/1/1988 converted to 'C'. AFP.
    22/03/88: igj: uses os_file to load/save objects
 *  13-Dec-89: WRS: msgs literal text put back in.
     7-Mar-91: PJC: support for BASIC files added
    27-Jun-91: IDJ: removed special case of zero length files, to force access rights checking
    10-Jul-91: IDJ/PJC: fixed bug in BASIC file saving
    19-Jul-91: IDJ: fix to guard against stack extension moving flex blocks
    31-Jul-91: PJC: more BASIC bug-fixes
*/

#define BOOL int
#define TRUE 1
#define FALSE 0

#define BASIC 1

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#include "os.h"
#include "txt.h"
#include "typdat.h"

#if BASIC
#include "flex.h"
#include "swis.h"
#include "wimpt.h"
#include "txt.h"
#include "EditIntern/txtundo.h"
#include "EditIntern/txt1.h"
#include "txtedit.h"
#include "txtscrap.h"
#include "xfersend.h"
#include "xferrecv.h"
#endif

#include "EditIntern/txtfile.h"
#include "trace.h"
#include "werr.h"
#include "msgs.h"
#include "visdelay.h"
#include "VerIntern/messages.h"

void txtfile_buildnewtimestamp(typdat oldty, typdat *newty)
/* restamp the file with a current time/date stamp */

{
int block[2];
/* ignore call if untyped, thus preserving Load/Exec addresses */
if (((unsigned int)oldty.ld >> 20) >= 0xfff) /* it's got a type ! */
{
    block[0] = 3;
    os_word(14, &block);
    newty->ld = ((unsigned int) oldty.ld & 0xffffff00) + (block[1] & 0xff);
    newty->ex = block[0];
}
else
{
    newty->ld = oldty.ld;
    newty->ex = oldty.ex;
}
}


BOOL txtfile_insert(txt t, char *filename, int l, typdat *ty)
/* The insert operation works in two phases. First, find out the size of the
file and insert that much junk into it. Then, actually read the contents of
the file directly into the text object memory. It is important to take this
approach to reduce memory fragmentation when inserting very large files,
otherwise several extensions may be made to the object which significantly
zap store. */
/* Obviously, this has to happen with display turned off or the junk would
significantly mess things up... */
/* Where can one be sure to find a large supply of junk? We guess at our own
code, not necessarily good if some of the machine's memory is not readable...
*/

{

int n;
BOOL result = TRUE;
BOOL wasupdated = (txt_UPDATED & txt_charoptions(t)) != 0;
txt_index at;
char *a;
int size;
os_error *er;
os_filestr file;

if (l < 0) {

  file.action = 5;
  file.name = filename;

  er = os_file(&file);
  tracef0("the os_file 5 returned.\n");
  if (er != 0) { /* read info on pathname */
      werr(FALSE, er->errmess);
      return(0);
  };

  if (file.action != 1) { /* Did we find a file ? */
      werr(FALSE, msgs_lookup(MSGS_txt51), filename);
      return(0);
  };

  l = file.start;
};

/*if (l != 0)   IDJ: 27-Jun-91: removed this check to force load to be tried */
{
    txt_setcharoptions(t, txt_DISPLAY, 0);
    visdelay_begin();

    size = txt_size(t);

    /* 24-Oct-02 KJB: txt_replacechars now accepts a null pointer, and treats
    it as a request to insert the appropriate number of spaces */
    txt_replacechars(t, 0, NULL, l);

    if (l + size != txt_size(t)) {
      /* There isn't enough room. He will already have received an error
      message. Delete whatever rubbish we were able to insert, and return
      FALSE. */
      txt_delete(t, txt_size(t) - size);
      visdelay_end();
      txt_setcharoptions(t, txt_DISPLAY, txt_DISPLAY);
      if (! wasupdated) txt_setcharoptions(t, txt_UPDATED, 0);
      return FALSE;
    };
    at = txt_dot(t);
    txt_arrayseg(t, at, &a, &n);
    file.action = 0xff;  /* load named file */
    file.name = filename;
    file.loadaddr = (int) &a[0];
    file.execaddr = 0;

    er = os_file(&file);
    if (er != 0) { /* load into buffer */
        werr(FALSE, er->errmess);
        txt_delete(t, txt_size(t) - size);
        if (! wasupdated) txt_setcharoptions(t, txt_UPDATED, 0);
        result = FALSE;
    } else {
        ty->ld = file.loadaddr;  /* return type to client */
        ty->ex = file.execaddr;
    };

    visdelay_end();
    txt_setcharoptions(t, txt_DISPLAY, txt_DISPLAY);
};

return(result);
/* >>>> If it didn't work, how do I get an error message out? */

}



int txtfile_saverange(txt t, char *filename, typdat ty,
                      txt_index from, txt_index to)
/* This is much simpler than insert, we save the file */

{

int n, result, oldattribs = -1;
char *a;
os_filestr file;
txt_index wasat;
os_error *er;

if (to < 0) to = INT_MAX; /* >>>> M2 compatibility fudge! */

tracef2("From = %d  To = %d\n", (int)from, (int)to);

txt_setcharoptions(t, txt_DISPLAY, 0);
wasat = txt_dot(t);
txt_setdot(t, from);
txt_arrayseg(t, from, &a, &n);

if (to < from)
    result = TRUE;
else
{
    if (n > to - from)
        n = to - from;

    file.action = 17; /* Read cat info */
    file.name = filename;
    (void) os_file(&file);
    /* if something is already there,remember its attributes */
    if (file.action != 0) oldattribs = file.end;

    file.action = 0;  /* Save */
    file.loadaddr = ty.ld;
    file.execaddr = ty.ex;
    file.start = (int) &a[0];
    file.end = (int) &a[n];
    er = os_file(&file);
    if (er != 0) {
      werr(FALSE, er->errmess);
    };

    if (oldattribs != -1) {
      file.action = 4; /* Write attribs */
      file.end = oldattribs;
      (void) os_file(&file);
    };

    result = er == 0;
}

txt_setdot(t, wasat);
txt_setdisplayok(t);
return(result);

}

#if BASIC

extern void bastxt_detokenise(int output_buffer, int input_address, int *flag, int *detokeniser);
extern void bastxt_tokenise(char **output_buffer, char **input_buffer, int *line_number, int *tokeniser, int increment);

static char *sender_anchor;
static char *receiver_anchor;
static int   receiver_size;

static BOOL txtfile__basicimportdata(txt t, char **anchor, int input_size, int detok_addr, BOOL strip)
{
  BOOL result = TRUE;
  BOOL wasupdated = ((txt_UPDATED & txt_charoptions(t)) != 0);
  int size = input_size * 2;
  int in = 0;
  int out = 0;
  int c = 0;
  int d = 0;
  char *buff = NULL;
  char *previous_address = NULL;

  /* strategy is:

     1) flex a detok buffer that is 200% the size of the tokenised data
     2) detokenise a line into the detok buffer.
     3) if the line contained a line number reference, then if the user
        wants to try again with line numbers, restart at (2).
     4) loop to (2) until the end of the program has been reached.
     5) insert the detok buffer into the txt, watching for shifting
        anchors.

  */

  if (flex_alloc((flex_ptr)&buff, size)) {
    out = 0;
    in = 1; /* start at 1 to skip the initial CR */
    c = -1;

    visdelay_begin();
    while (c != 0) {
      c = strip;
      d = detok_addr;
      bastxt_detokenise((int)buff + out, (int)*anchor + in, &c, &d);
      if (c > 0) {
        /* update offsets NOW in case the blocks move ! */
        in = c - (int)*anchor;
        out = d - (int)buff - 1;
        if (out > size) {
          werr(0, msgs_lookup(MSGS_bas8), out - size);
        }
      }
      if (c == -1) {
        /* amg 30th August 1994, change err to be an os_error instead of   */
        /* a char[] - makes setting the error number tidier (it never used */
        /* to bother!                                                      */

        os_error err;

        /* line number reference found */
        visdelay_end();
        sprintf(err.errmess, msgs_lookup(MSGS_bas2));
        err.errnum = 0;
        os_swi3r(Wimp_ReportError, (int)&err, 3, (int)wimpt_programname(), NULL, &c, NULL);
        visdelay_begin();

        if (c == 1) {
          strip = FALSE;
          in = 1;
          out = 0;
        } else {
          c = 0; /* already deleted the insertions, so let's just exit */
          result = FALSE;
        }
      }
    }
    if (result) {
      txt_setcharoptions(t, txt_DISPLAY, 0);
      previous_address = buff;
      size = txt_size(t);
      txt_replacechars(t, 0, buff, out);
      if (txt_size(t) != out + size) {
        txt_delete(t, txt_size(t) - size);
        txt_setcharoptions(t, txt_UPDATED, wasupdated);
        result = FALSE;
      } else {
        if (buff != previous_address) {
          txt_replacechars(t, out, buff, out);
        }
      }
      txt_setcharoptions(t, txt_DISPLAY, txt_DISPLAY);
    }
    visdelay_end();
    flex_free((flex_ptr)&buff);
  } else {
    werr(0, msgs_lookup(MSGS_bas6));
    result = FALSE;
  }

  return(result);
}

static BOOL txtfile__basicimportbufferprocessor(char **buffer, int *size)
{
  /* this routine is called when the buffer is full,
     so copy the data into the flex buffer.
  */

  int new_size = receiver_size + *size;
  BOOL result;

  if (receiver_size == 0) {
    result = flex_alloc((flex_ptr)&receiver_anchor, *size);
  } else {
    result = flex_extend((flex_ptr)&receiver_anchor, new_size);
  }
  if (result) {
    memcpy(receiver_anchor + receiver_size, *buffer, *size);
    receiver_size = new_size;
  }
  return(result);
}

BOOL txtfile_basicimport(txtedit_state *s, BOOL insrep, int detokenise, BOOL strip)
{
  /* Plan of action is:
     1) import everything into a flex buffer
     2) detokenise and insert!
  */
  int last;
  BOOL result, undo;
  txt_index dot;
  int size, tsize;
  char *import_buffer = malloc(4096); /* do imports in 4K chunks */

  if (import_buffer == NULL) {
    werr(FALSE, msgs_lookup(MSGS_txt3));
    return(FALSE);
  }

  undo = txtundo_suspend_undo(s->t, TRUE);
  tsize = txt_size(s->t);
  dot = txt_dot(s->t);
  receiver_anchor = NULL; /* no imported data yet */
  receiver_size = 0;

  last = xferrecv_doimport(import_buffer, 4096, txtfile__basicimportbufferprocessor);
  if (last == -1) {
    result = FALSE;
  } else {
    if (txtfile__basicimportbufferprocessor(&import_buffer, &last)) {
      txtfile__basicimportdata(s->t, &receiver_anchor, receiver_size, detokenise, strip);
      result = TRUE;
    } else result = FALSE;
  }
  free(import_buffer);
  if (receiver_anchor != NULL)
    flex_free((flex_ptr)&receiver_anchor);

  if (result) {
    size = txt_size(s->t) - tsize; /* Delta */
    txt_setdot(s->t, dot);
    txtundo_suspend_undo(s->t, undo);
    txtundo_putnumber(s->t->undostate, size);
    txtundo_putcode(s->t->undostate, 'd');
    if (size == 0) {
      /* Nothing happened overall */
    } else {
      /* When insertion replaced a selection, must select the new
      insertion in its place. */
      if (insrep) {
        txtscrap_setselect(s->t, dot, dot + size);
      } else {
        txt_movedot(s->t, size);
        txt_show(s->t); /* Force a redraw so caret x/y is recalculated */
      }
    }
  }
  txtedit_settexttitle(s);
  txtundo_separate_major_edits(s->t);
  return(result);
}

BOOL txtfile_basicinsert(txt t, char *filename, int l, typdat *ty, int detokenise, BOOL strip)
{
  BOOL result = FALSE;
  os_error *er;
  os_filestr file;
  char *anchor;

  if (l > 0) {

    /* steps required are:

       1) flex enough memory to load the BASIC file in and load it.
       2) import the data
       3) when finished, release the original flex block

    */

    if (flex_alloc((flex_ptr)&anchor, l)) {
      file.action = 0xFF; /* load named file */
      file.name = filename;
      file.loadaddr = (int)anchor;
      file.execaddr = 0;

      er = os_file(&file);
      if (er != 0) {
        werr(FALSE, er->errmess);
        result = FALSE;
      } else {
        result = txtfile__basicimportdata(t, &anchor, file.start, detokenise, strip);
      }
      flex_free((flex_ptr)&anchor);
    } else {
      werr(0, msgs_lookup(MSGS_bas6));
      return(FALSE);
    }

    if (result) {
      ty->ld = file.loadaddr;  /* return type to client */
      ty->ex = file.execaddr;
    }
  }
  return(result);
}

#define tokenising_successful 0
#define tokenising_nomemory 1
#define tokenising_badlinenumbers 2

static int txtfile__basicdotokenising(txt t, txt_index from, txt_index to, int *end_ptr, int token_addr, int increment)
{
  char *a;
  char *output_buffer;
  char *input_buffer;
  int n;
  int line_number;
  int tokenise;
  int result = tokenising_successful;
  txt_index wasat;
  char *old_anchor;
  char *old_a;

  txt_setcharoptions(t, txt_DISPLAY, 0);
  wasat = txt_dot(t);
  txt_setdot(t,from);
  txt_arrayseg(t, from, &a, &n);
  if (to < from) {
    /* wacky incomprehensible test! */
    result = tokenising_successful;
  } else {
    if (n > to - from)
      n = to - from;
    n +=1;                                                  /* allow for a missing terminator */
    if (flex_alloc((flex_ptr)&sender_anchor, n)) {          /* get the buffer memory */
      int nn = 0, warning_issued = FALSE;
      char last_ch;
      line_number = 0;

      /* IDJ: fix to guard against stack extension moving flex blocks */
      txt_arrayseg(t, from, &a, &nn);
      *sender_anchor = 13;                                  /* all good BASIC programs start with CR */
      if (a[n-2] == 13 || a[n-2] == 10)                     /* if text is already terminated properly */
       n--;                                                 /* then decrement the count */
      last_ch = a[n-1];                                     /* ensure terminated by CR */
      a[n-1] = 13;                                          /* this is always done */

      visdelay_begin();

      txt_arrayseg(t, from, &input_buffer, &nn);
      output_buffer = sender_anchor + 1;
      old_a = input_buffer;
      old_anchor = sender_anchor;

      do
      {
        int sender_size, fixed_line_number, lines_flag;

        tokenise = token_addr;

        bastxt_tokenise(&output_buffer, &input_buffer, &line_number, &tokenise, increment);
        lines_flag = line_number & 0xC0000000;
        fixed_line_number = line_number & 0x3FFFFFFF;

        if (lines_flag == 0xC0000000)
        {
          if (!warning_issued)
          {
             werr(0, msgs_lookup(MSGS_basA), fixed_line_number);
             visdelay_begin();
             warning_issued = TRUE;
          }
        }
        if (tokenise & (1<<8))
        {
          werr(0, msgs_lookup(MSGS_bas3), fixed_line_number);
          visdelay_begin();
        }
        if ((tokenise & 255) == 1)
        {
          werr(0, msgs_lookup(MSGS_bas4), fixed_line_number);
          visdelay_begin();
        }
        if ((tokenise & ~255) != 0)
        {
          werr(0, msgs_lookup(MSGS_bas5), fixed_line_number);
          visdelay_begin();
        }

        /* check we've got at least 512 bytes free in the ouput
           buffer for next time around
        */
        sender_size = flex_size((flex_ptr)&sender_anchor);
        if (sender_size - (output_buffer - old_anchor) < 512)
        {
           if (flex_extend((flex_ptr)&sender_anchor, sender_size + 4096) == 0)
           {
              txt_arrayseg(t, from, &a, &nn);
              a[n-1] = last_ch;
              flex_free((flex_ptr)&sender_anchor);
              txt_setdot(t, wasat);
              txt_setdisplayok(t);
              return tokenising_nomemory;
           }
        }

        /* rationalise anchors BEFORE line number test 'cos it has a break */
        txt_arrayseg(t, from, &a, &nn);
        if (old_anchor != sender_anchor || old_a != a)
        {
           input_buffer = a + (input_buffer - old_a);
           output_buffer = sender_anchor + (output_buffer - old_anchor);
           old_a = a;
           old_anchor = sender_anchor;
        }

        if (fixed_line_number > 65279)
        {
          result = tokenising_badlinenumbers; /* failed to save correctly */
          break; /* to get us out of the while loop */
        }
      } while (input_buffer < a + n);
      a[n-1] = last_ch;
      *(output_buffer) = 255;
      *end_ptr = (output_buffer - sender_anchor + 1);
      if (result != tokenising_badlinenumbers)
        visdelay_end();
    } else {
      result = tokenising_nomemory;
    }
  }
  txt_setdot(t, wasat);
  txt_setdisplayok(t);
  return(result);
}

BOOL txtfile_basicsenderproc(txt t, int *maxbuf, txt_index from, txt_index to, int tokenise, int increment)
{
  int offset;
  int end_ptr;
  int segsize;

  switch (txtfile__basicdotokenising(t, from, to, &end_ptr, tokenise, increment))
  {
    case tokenising_successful:     offset = 0;
                                    while (offset < end_ptr)
                                    {
                                      segsize = (end_ptr - offset);
                                      if (segsize > *maxbuf) segsize = *maxbuf;
                                      if (! xfersend_sendbuf((char *)(sender_anchor + offset), segsize))
                                      {
                                        flex_free((flex_ptr)&sender_anchor);
                                        return(FALSE);
                                      }
                                      offset += segsize;
                                    }
                                    flex_free((flex_ptr)&sender_anchor);
                                    return(TRUE);
    case tokenising_nomemory:       werr(0, msgs_lookup(MSGS_bas7));
                                    break;
    case tokenising_badlinenumbers: werr(0, msgs_lookup(MSGS_bas9));
                                    flex_free((flex_ptr)&sender_anchor);
                                    break;
  }
  return(FALSE);
}

BOOL txtfile_savebasicrange(txt t, char *filename, typdat ty, txt_index from, txt_index to, int tokenise, int increment)
{
  int end_ptr;
  os_filestr file;
  os_error *er;
  BOOL result = TRUE;

  switch (txtfile__basicdotokenising(t, from, to, &end_ptr, tokenise, increment))
  {
    case tokenising_successful:     file.action = 0;
                                    file.name = filename;
                                    file.loadaddr = ty.ld;
                                    file.execaddr = ty.ex;
                                    file.start = (int)sender_anchor;
                                    file.end = (int)sender_anchor + end_ptr;
                                    er = os_file(&file);
                                    if (er != 0) {
                                      werr(FALSE, er->errmess);
                                    }
                                    result = er == 0;
                                    flex_free((flex_ptr)&sender_anchor);
                                    break;
    case tokenising_nomemory:       werr(0, msgs_lookup(MSGS_bas7));
                                    result = FALSE;
                                    break;
    case tokenising_badlinenumbers: werr(0, msgs_lookup(MSGS_bas9));
                                    flex_free((flex_ptr)&sender_anchor);
                                    result = FALSE;
                                    break;
  }
  return(result);
}

#endif
