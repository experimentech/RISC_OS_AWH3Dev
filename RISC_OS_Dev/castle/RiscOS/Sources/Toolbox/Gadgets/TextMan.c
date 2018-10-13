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
/* Title:   TextMan.c
 * Purpose: Text management functions.
 *
 * Revision History
 * rlougher  Nov 96  Created
 * rlougher 18/12/96 Added code to keep track of max x-extent during editing
 * rlougher 14/02/97 Fixed line limit (1000) on text replace
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include "kernel.h"
#include "swis.h"

#include "macros.h"
#include "messages.h"
#include "objects/gadgets.h"

#include "twimp.h"
#include "MemMan.h"
#include "TextMan.h"

typedef struct {
    int  *new_lines;
    int  line_no;
    int  max_line;
    char *split_pos;
    int  split_xpoint;
    int  x_pos;
} Scan;

_kernel_oserror *grow_lines(Text *text, int size);
_kernel_oserror *grow_lines_by(Text *text, int size);
_kernel_oserror *create_insertion(Text *text, int pos);
int             line_start(Text *text, int line_no);
int             line_end(Text *text, int line_no);
int             line_index_of_char(Text *text, int pos);
char            *text_to_mem(Text *text, int pos);
char            *expand_tabs(char *str, int *len);

_kernel_oserror *create_text(int size, int font_handle, Text **t_pntr)
{
    _kernel_oserror *err;
    Text            *text;
    HandleId        handle;

    /* Create the memory block to hold the text data */

    if((err = create_block(size + 1, &handle)) != NULL)
        return err;

    if((text = malloc(sizeof(Text))) == NULL)
    {
        delete_block(handle);
        return make_error(TextGadgets_IntMallocFail, 0);
    }

    *(get_handle(handle)->base) = '\0';

    text->insert_line    = 0;
    text->insert_delta   = 0;
    text->insert_pos     = 0;
    text->insert_gap_end = 0;
    text->no_of_lines    = 1;
    text->lne_tbl_sze    = 0;
    text->line_table     = NULL;
    text->xmax_table     = NULL;
    text->sel_stop_pos   = -1;
    text->sel_stop_line  = 0;
    text->xmax           = 0;
    text->xmax_line      = 0;

    /* Create the line table for the text */

    if((err = grow_lines(text, size)) != NULL)
    {
        free(text);
        delete_block(handle);
        return err;
    }

    text->line_table[0] = -1;
    text->xmax_table[0] = 0;
    text->text_data = handle;
    *t_pntr = text;

    return set_font(text, font_handle);
}


_kernel_oserror *set_font(Text *text, int font_handle)
{
    int min, max;

    text->font_handle = font_handle;
    _swix(Font_ReadInfo,_IN(0)|_OUT(2)|_OUT(4), font_handle, &min, &max);
    text->line_height = max + (min < 0 ? - min : 0);
    text->font_base = max;

    text->tab_stop = 72000;
    _swix(Font_ScanString,_INR(0,4)|_OUT(3), text->font_handle, " ", 1<<8,
                              0xfffffff, 0, &text->space);

    if(get_text_size(text) > 0)
        return compose_text(text);

    return NULL;
}


void delete_text(Text *text)
{
    delete_block(text->text_data);
    free(text->line_table);
    free(text->xmax_table);
    free(text);
}


static void update_lines(Text *text)
{
    int i;

    for(i = text->insert_line; i < text->no_of_lines; i++)
        text->line_table[i] += text->insert_delta;

    text->insert_delta = 0;
}


_kernel_oserror *move_insertion(Text *text, int pos)
{
    int diff = text->insert_gap_end - text->insert_pos;

    if(diff == 0)
        return create_insertion(text, pos);
    else
    {
        char *base = get_handle(text->text_data)->base;

        if(pos < text->insert_pos)
            memmove(base + pos + diff, base + pos, text->insert_pos - pos);
        else
            memmove(base + text->insert_pos, base + text->insert_gap_end,
                    pos - text->insert_gap_end);
    }
    text->insert_pos = pos;
    text->insert_gap_end = pos + diff;

    update_lines(text);
    text->insert_line = line_index_of_char(text, pos);

    return NULL;
}


_kernel_oserror *create_insertion(Text *text, int pos)
{
    _kernel_oserror *err;
    Handle *handle = get_handle(text->text_data);

    if((err = extend_block(text->text_data, pos, INSERTION_GAP)) != NULL)
        return err;

    *(handle->base + pos) = '\0';

    text->insert_pos = pos;
    text->insert_gap_end = pos + INSERTION_GAP;
    text->insert_delta = 0;
    text->insert_line = line_index_of_char(text, pos);

    return NULL;
}


void close_insertion(Text *text)
{
    shrink_block(text->text_data, text->insert_pos,
                 text->insert_gap_end - text->insert_pos);

    text->insert_gap_end = text->insert_pos;

    update_lines(text);
}

static int line_len(Text *text, int line_no)
{
    int xpoints;

    if(line_no == text->insert_line)
    {
        int start = line_start(text, line_no);
        int len = text->insert_pos - start;
        char *start_pntr = text_to_mem(text, start);
        int xpoints2;

        if((text->insert_gap_end - text->insert_pos) > 0)
            *(get_handle(text->text_data)->base + text->insert_pos) = '\0';

        _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                              text->font_handle, start_pntr, 1<<7|1<<8,
                              0xfffffff, 0, len,
                              &xpoints);

        len = line_end(text, line_no) - text->insert_pos + 1;
        start_pntr = text_to_mem(text, text->insert_pos);

        _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                              text->font_handle, start_pntr, 1<<7|1<<8,
                              0xfffffff, 0, len,
                              &xpoints2);

        xpoints += xpoints2;
    }
    else
    {
        int start = line_start(text, line_no);
        int len = line_end(text, line_no) - start + 1;
        char *start_pntr = text_to_mem(text, start);

        _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                              text->font_handle, start_pntr, 1<<7|1<<8,
                              0xfffffff, 0, len,
                              &xpoints);
    }
    _swix(Font_ConverttoOS,_IN(1)|_IN(2)|_OUT(1), xpoints, 0, &xpoints);

    return xpoints;
}

static _kernel_oserror *new_line(Scan *scan, int pos, char *end, char *start)
{
    scan->new_lines[scan->line_no++] = pos;
    if(scan->line_no == scan->max_line)
    {
        int extra = (end - start + 1) / 20 + 5;

        if((scan->new_lines = realloc(scan->new_lines,
                       (scan->max_line += extra) * sizeof(int))) == NULL)
            return make_error(TextGadgets_IntMallocFail, 0);
    }

    return NULL;
}

static _kernel_oserror *scan_text(Text *text, char *start_pntr, char *end, char *con, Scan *scan)
{
        _kernel_oserror *e;
        int             tab_stop = text->tab_stop;
       	char            *char_pntr = start_pntr;
       	int             xpoints, xp;
       	int             margin = text->margin;

        while(char_pntr <= end)
        {
            if(*char_pntr == ' ' || *char_pntr == '\t' || *char_pntr == '\n')
            {
               int old_line_no = scan->line_no;

                _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                                      text->font_handle, start_pntr, 1<<7|1<<8,
                                      0xffffff, 0, char_pntr - start_pntr,
                                      &xpoints);

                if((scan->x_pos + xpoints) > margin)
                {
                    if(scan->split_pos != NULL)
                    {
                        if((e = new_line(scan, scan->split_pos - con - 1, end, char_pntr)) != NULL)
                            return e;
                        scan->x_pos -= scan->split_xpoint;
                    }

                    while((scan->x_pos + xpoints) > margin)
                    {
                        _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(1)|_OUT(3),
                                               text->font_handle, start_pntr, 1<<17|1<<7|1<<8,
                                               margin - scan->x_pos, 0, char_pntr - start_pntr,
                                               &start_pntr, &xp);

                        if((e = new_line(scan, (scan->split_pos = start_pntr) - con - 1, end,
                                            char_pntr)) != NULL)
                            return e;
                        scan->x_pos = 0;
                        xpoints -= xp;
                    }
                }

                scan->x_pos += xpoints;

                if(*char_pntr == ' ')
                    scan->x_pos += text->space;
                else
                    if(*char_pntr == '\t')
                    {
                        int offset = tab_stop - (scan->x_pos % tab_stop);
                        *++char_pntr = (char) offset;
                        *++char_pntr = (char) (offset >> 8);
                        *++char_pntr = (char) (offset >> 16);
                        scan->x_pos += offset;
                    }
                    else
                        if((old_line_no == scan->line_no) | (scan->split_pos != char_pntr))
                        {
                            if((e = new_line(scan, char_pntr - con, end, char_pntr)) != NULL)
                                return e;
                            scan->x_pos = 0;
                        }

                if(*char_pntr++ != '\n')
                {
                    scan->split_pos = char_pntr;
                    scan->split_xpoint = scan->x_pos;
                }
                else
                    scan->split_pos = NULL;
                start_pntr = char_pntr;
            }
            else
                char_pntr++;
        }

    if(start_pntr <= end)
    {
        _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                          text->font_handle, start_pntr, 1<<7|1<<8,
                          0xffffff, 0, end - start_pntr + 1,
                          &xpoints);

        if((scan->x_pos + xpoints) > margin)
        {
            if(scan->split_pos != NULL)
            {
                if((e = new_line(scan, scan->split_pos - con - 1, end, start_pntr)) != NULL)
                    return e;
                scan->x_pos -= scan->split_xpoint;
            }

            while((scan->x_pos + xpoints) > margin)
            {
                _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(1)|_OUT(3),
                                       text->font_handle, start_pntr, 1<<17|1<<7|1<<8,
                                       margin - scan->x_pos, 0, end - start_pntr + 1,
                                       &start_pntr, &xp);

                if((e = new_line(scan, start_pntr - con - 1, end, start_pntr)) != NULL)
                    return e;
                scan->x_pos = 0;
                xpoints -= xp;
            }
            scan->split_pos = NULL;
        }
        scan->x_pos += xpoints;
    }

    return NULL;
}

_kernel_oserror *compose_text(Text *text)
{
    _kernel_oserror *err;
    Handle          *handle = get_handle(text->text_data);
    char            *end, *base = handle->base;
    int             insert_pos = text->insert_pos;
    Scan            scan;
    int             i;

    if(text->insert_gap_end > insert_pos)
        close_insertion(text);

    end = base + handle->size - 2;

    scan.max_line = (end - base + 1) / 20 + 5;
    scan.new_lines = malloc((scan.max_line + 1) * sizeof(int));

    /* If the malloc fails ... */
    if (scan.new_lines == NULL)
    {
      /* ... return an error message */
      return make_error(TextGadgets_IntMallocFail, 0);
    }

    scan.line_no = 0;

    scan.x_pos = 0;
    scan.split_pos = NULL;

    if((err = scan_text(text, base, end, base, &scan)) != NULL)
        return err;

    if((end < base) || (*end != '\n'))
        scan.new_lines[scan.line_no++] = end - base;

    if(scan.line_no > text->lne_tbl_sze)
        if((err = grow_lines_by(text, scan.line_no - text->lne_tbl_sze)) != NULL)
            return err;

    for(i = 0; i < scan.line_no; i++)
        text->line_table[i] = scan.new_lines[i];

    text->no_of_lines = scan.line_no;
    text->insert_line = text->insert_pos = 0;

    text->insert_line = line_index_of_char(text, insert_pos);
    text->insert_pos = insert_pos;

    if(text->sel_stop_pos != -1)
        text->sel_stop_line = line_index_of_char(text, text->sel_stop_pos);

    text->xmax_line = text->xmax = 0;
    for(i = 0; i < scan.line_no; i++)
    {
        text->xmax_table[i] = line_len(text, i);
        if(text->xmax_table[i] > text->xmax)
        {
            text->xmax_line = i;
            text->xmax = text->xmax_table[i];
        }
    }
    free(scan.new_lines);

    return NULL;
}


char *expand_tabs(char *str, int *len)
{
    char *new_str;
    int no_tabs = 0;
    char *pos = str, *pos2;

    while(*pos)
       if(*pos++ == '\t')
          no_tabs++;

    *len = pos - str;
    if(no_tabs == 0)
        return str;

    *len += no_tabs * 3;
    pos2 = new_str = malloc(*len + 1);

    if (new_str == NULL)
      return new_str;

    for(pos = str; (*pos2++ = *pos) != NULL;)
        if(*pos++ == '\t')
            pos2 += 3;

    return new_str;
}


_kernel_oserror *replace_text(Text *text, int from, int ex_to, const char *s,
                      int *first_line_p, int *last_line_p, int *line_delta_p)
{
    Handle          *handle = get_handle(text->text_data);
    _kernel_oserror *err;
    int             str_size;
    char            *str = expand_tabs((char *)s, &str_size);
    int             to = ex_to - 1;
    int             delta;
    int             insert_pos = text->insert_pos;
    int             insert_line = text->insert_line;
    int             first_line, last_line, last_line_end, first_line_start;
    char            *base = handle->base;
    int             line_delta;
    char            *end, *con;
    int             old_xmax;
    int             gap_size = text->insert_gap_end - insert_pos;
    Scan            scan;
    char            *old_end;
    int             old_line_no;
    int             old_split = 0;
    char            *start;
    int             ld = 0, ln = 0;
    int             step_back = FALSE;
    int             i;

    /* If expand_tabs failed */
    if (str == NULL)
    {
      /* return an error message */
      return make_error(TextGadgets_IntMallocFail, 0);
    }

    if((ex_to == -1) || (to > line_end(text, text->no_of_lines - 1)))
        to = line_end(text, text->no_of_lines - 1);

    if(from == -1 || (from > line_end(text, text->no_of_lines - 1)))
        from = line_end(text, text->no_of_lines - 1) + 1;

    delta = str_size - (to - from + 1);

    if((str_size == 0) && (delta == 0)) return NULL;

    first_line = line_index_of_char(text, from);

    if((to < insert_pos) && (from != insert_pos))
    {
        if(delta < 0)
            shrink_block(text->text_data, from, -delta);
        else
            if((err = extend_block(text->text_data, from, delta)) != NULL)
                return err;

        memcpy(base + from, str, str_size);

        insert_pos = text->insert_pos += delta;
        text->insert_gap_end += delta;
    }
    else
    {
        if(from <= insert_pos)
        {
            text->insert_gap_end += to - insert_pos + 1;
            text->insert_pos = insert_pos = from;
            text->insert_line = insert_line = first_line;
            gap_size = text->insert_gap_end - insert_pos;

            if((err = extend_block(text->text_data, from + gap_size,
                      str_size)) != NULL)
                return err;
        }
        else
        {
            if(delta < 0)
                shrink_block(text->text_data, from + gap_size, -delta);
            else
                if((err = extend_block(text->text_data, from + gap_size,
                        delta)) != NULL)
                    return err;
        }

        memcpy(base + from + gap_size, str, str_size);
    }

    if((first_line > 0) && (*text_to_mem(text, line_end(text, first_line - 1)) != '\n'))
    {
        first_line--;
        step_back = TRUE;
    }

    last_line = line_index_of_char(text, to);
    first_line_start = line_start(text, first_line);
    last_line_end = line_end(text, last_line);

    scan.max_line = (last_line_end - first_line_start + 1 + delta) / 20 + 5;
    scan.new_lines = malloc((scan.max_line + 1) * sizeof(int));

    /* If the malloc fails ... */
    if (scan.new_lines == NULL)
    {
      /* ... attempt to clean up, this is largely intelligent guesswork */
      if((to < insert_pos) && (from != insert_pos))
      {
        if (delta > 0)
          shrink_block(text->text_data, from, -delta);
      }
      else
      {
        if(from <= insert_pos)
        {
          shrink_block(text->text_data, from + gap_size, str_size);
        }
        else
        {
          if (delta > 0)
            shrink_block(text->text_data, from + gap_size, -delta);
        }
      }

      /* and return an error */
      return make_error(TextGadgets_IntMallocFail, 0);
    }

    scan.line_no = scan.x_pos = 0;
    scan.split_pos = NULL;

    if((first_line <= insert_line) && (last_line >= insert_line))
    {
        end = base + text->insert_pos - 1;
        if((err = scan_text(text, start = base + first_line_start, end, base, &scan)) != NULL)
            return err;

        con = base + gap_size + text->insert_delta;
        old_end = end + gap_size;
        if(gap_size > 0) *old_end = '\0';
        ld = scan.line_no - (insert_line - first_line);
        ln = scan.line_no;

        if(scan.split_pos != NULL)
        {
            old_split = scan.split_pos - base - 1;
            scan.split_pos = (char *) 1;
        }
        end = last_line_end + base + gap_size + delta;
        if((err = scan_text(text, old_end + 1, end, con, &scan)) != NULL)
           return err;
    }
    else
    {
        if(last_line < insert_line)
        {
            start = base + first_line_start,
            end = base + last_line_end + delta;
            con = base;
        }
        else
        {
            start = base + first_line_start + gap_size;
            end = base + last_line_end + delta + gap_size;
            con = base + gap_size + text->insert_delta;
        }
        if((err = scan_text(text, start, end, con, &scan)) != NULL)
            return err;
    }

    if((++last_line < text->no_of_lines) && ((start >  end) || (*end != '\n')))
    {
        old_line_no = scan.line_no;
        do {
           old_end = end;

           if(last_line == text->insert_line)
           {
               end = base + text->insert_pos - 1;
               if((err = scan_text(text, old_end + 1, end, con, &scan)) != NULL)
                   return err;

               con = base + gap_size + text->insert_delta;
               ld = scan.line_no -  (last_line - first_line);
               ln = scan.line_no;

               if(scan.split_pos != NULL)
               {
                   old_split = scan.split_pos - base - 1;
                   scan.split_pos = (char *) 1;
               }

               old_end = end + gap_size;
               if(gap_size > 0) *old_end = '\0';
           }
           end = line_end(text, last_line) + base + delta;
           if(last_line++ >= text->insert_line) end += gap_size;
           if((err = scan_text(text, old_end + 1, end, con, &scan)) != NULL)
               return err;

        } while((*end != '\n') && (last_line < text->no_of_lines) &&
               ((scan.line_no == old_line_no) ||
               ((scan.new_lines[scan.line_no - 1] + con) > old_end)));
    }
    last_line --;

    if((ln < scan.line_no) && (scan.new_lines[ln] == - (int) con))
    {
        scan.new_lines[ln] = old_split;
        ld++;
    }
    if((start > end) || (*end != '\n'))
        scan.new_lines[scan.line_no++] = end - con;

    line_delta = scan.line_no - (last_line - first_line + 1);
    *first_line_p = first_line;
    *last_line_p = last_line;
    *line_delta_p = line_delta;

    if(step_back && (scan.new_lines[0] == text->line_table[first_line]) &&
       ((first_line != insert_line) || ld == 0))
          (*first_line_p)++;

    if(last_line < insert_line)
    {
        for(i = last_line + 1; i < text->insert_line; i++)
            text->line_table[i] += delta;
        text->insert_delta += delta;
        text->insert_line += line_delta;
    }
    else
    {
        if(first_line < insert_line)
            text->insert_line += ld;
        for(i = last_line + 1; i < text->no_of_lines; i++)
            text->line_table[i] += delta;
    }

    if(line_delta != 0)
    {
        if(line_delta < 0)
            for(i = last_line + 1; i < text->no_of_lines; i++)
            {
                text->line_table[i + line_delta] = text->line_table[i];
                text->xmax_table[i + line_delta] = text->xmax_table[i];
            }
        else
        {
            int free = text->lne_tbl_sze - text->no_of_lines - line_delta;
            if((free < 0) && ((err = grow_lines_by(text, -free)) != NULL))
                return err;
            for(i = text->no_of_lines - 1; i > last_line; i--)
            {
                text->line_table[i + line_delta] = text->line_table[i];
                text->xmax_table[i + line_delta] = text->xmax_table[i];
            }
        }
    }

    for(i = 0; i < scan.line_no; i++)
        text->line_table[first_line + i] = scan.new_lines[i];

    free(scan.new_lines);

    text->no_of_lines += line_delta;

    old_xmax = text->xmax;

    for(i = first_line; i < (first_line + scan.line_no); i++)
    {
        text->xmax_table[i] = line_len(text, i);

        if(text->xmax_table[i] > text->xmax)
        {
            text->xmax_line = i;
            text->xmax = text->xmax_table[i];
        }
    }

    if(text->xmax == old_xmax)
    {
      if(text->xmax_line > last_line)
          text->xmax_line += line_delta;
      else
          if(text->xmax_line >= first_line)
          {
              text->xmax_line = 0;
              text->xmax = text->xmax_table[0];
              for(i = 0; i < text->no_of_lines; i++)
                  if(text->xmax_table[i] > text->xmax)
                  {
                      text->xmax_line = i;
                      text->xmax = text->xmax_table[i];
                  }
          }
    }

    if(s != str)
        free(str);

    return NULL;
}


_kernel_oserror *insert_text(Text *text, char *s,
                      int *first_line_p, int *last_line_p, int *line_delta)
{
    Handle          *handle = get_handle(text->text_data);
    _kernel_oserror *err;
    int             left = text->insert_gap_end - text->insert_pos;
    int             str_size;
    char            *str = expand_tabs((char *) s, &str_size);
    char            *start, *end, *con, *char_pntr;
    int             i, old_xmax;
    char            *base = handle->base;
    int             gap_size;
    int             ld, ln;
    int             first_line = text->insert_line;
    int             last_line = first_line;
    char            *old_end;
    Scan            scan;
    int             new_lines[10];
    int             old_split = 0;
    int             old_line_no;

    /* If expand_tabs failed */
    if (str == NULL)
    {
      /* return an error message */
      return make_error(TextGadgets_IntMallocFail, 0);
    }

    scan.new_lines = new_lines;
    scan.max_line = (sizeof(new_lines) / sizeof(new_lines[0])) - 1;
    scan.line_no = 0;

    if(left <= str_size)
    {
        left -= str_size + INSERTION_GAP;
        if((err = extend_block(text->text_data, text->insert_pos, -left))
               != NULL)
            return err;

        text->insert_gap_end -= left;
    }

    memcpy(end = base + text->insert_pos, str, str_size);

    text->insert_delta += str_size;
    text->insert_pos += str_size;
    gap_size = text->insert_gap_end - text->insert_pos;

    *(base + text->insert_pos) = '\0';

    start = base + line_start(text, first_line);

    scan.x_pos = 0;
    scan.split_pos = NULL;

    if((last_line > 0) && (*(start - 1) != '\n'))
    {
        for(char_pntr = start;
            (*char_pntr != ' ') && (*char_pntr != '\t') && (char_pntr < end);
            char_pntr++);

        if(char_pntr == end)
            start = base + line_start(text, --first_line);
    }

    end = base + text->insert_pos - 1;
    if((err = scan_text(text, start, end, base, &scan)) != NULL)
        return err;

    con = base + gap_size + text->insert_delta;
    old_end = end + gap_size;
    if(gap_size > 0) *old_end = '\0';
    ld = scan.line_no -  (last_line - first_line);
    ln = scan.line_no;

    if(scan.split_pos != NULL)
    {
        old_split = scan.split_pos - base - 1;
        scan.split_pos = (char *) 1;
    }

    end = line_end(text, last_line++) + base + gap_size;
    if((err = scan_text(text, old_end + 1, end, con, &scan)) != NULL)
        return err;

    if((*end != '\n') && (last_line < text->no_of_lines))
    {
        do {
           old_end = end;
           end = line_end(text, last_line++) + base + gap_size;

           old_line_no = scan.line_no;
           if((err = scan_text(text, old_end + 1, end, con, &scan)) != NULL)
               return err;

        } while((*end != '\n') && (last_line < text->no_of_lines) &&
               ((scan.line_no == old_line_no) ||
               ((scan.new_lines[scan.line_no - 1] + con) > old_end)));
    }

    if((ln < scan.line_no) && (scan.new_lines[ln] == - (int) con))
    {
        scan.new_lines[ln] = old_split;
        ld++;
    }

    if(*end != '\n')
        scan.new_lines[scan.line_no++] =  end - con;

    *line_delta = scan.line_no - (last_line - first_line);
    *last_line_p = last_line - 1;
    if(*line_delta != 0)
    {
        if(*line_delta < 0)
            for(i = last_line; i < text->no_of_lines; i++)
            {
                text->line_table[i + *line_delta] = text->line_table[i];
                text->xmax_table[i + *line_delta] = text->xmax_table[i];
            }
        else
        {
            int free = text->lne_tbl_sze - text->no_of_lines - *line_delta;
            if((free < 0) && ((err = grow_lines_by(text, -free)) != NULL))
                return err;
            for(i = text->no_of_lines - 1; i >= last_line; i--)
            {
                text->line_table[i + *line_delta] = text->line_table[i];
                text->xmax_table[i + *line_delta] = text->xmax_table[i];
            }
        }
    }
     for(i = 0; i < scan.line_no; i++)
        text->line_table[first_line + i] = scan.new_lines[i];

    *first_line_p = first_line;

    text->insert_line += ld;
    text->no_of_lines += *line_delta;

    old_xmax = text->xmax;

    for(i = first_line; i < (first_line + scan.line_no); i++)
    {
        text->xmax_table[i] = line_len(text, i);

        if(text->xmax_table[i] > text->xmax)
        {
            text->xmax_line = i;
            text->xmax = text->xmax_table[i];
        }
    }

    if(text->xmax == old_xmax)
    {
      if(text->xmax_line > first_line)
          text->xmax_line += *line_delta;
      else
          if(text->xmax_line == first_line)
          {
              text->xmax_line = 0;
              text->xmax = text->xmax_table[0];
              for(i = 0; i < text->no_of_lines; i++)
                  if(text->xmax_table[i] > text->xmax)
                  {
                      text->xmax_line = i;
                      text->xmax = text->xmax_table[i];
                  }
          }
    }

    if(s != str)
        free(str);

    return NULL;
}


char *get_text(Text *text, int from, int ex_to, char *buff)
{
    char *base = get_handle(text->text_data)->base;
    int to = ex_to - 1;

    if((ex_to == -1) || (to > line_end(text, text->no_of_lines - 1)))
        to = line_end(text, text->no_of_lines - 1);

    if(to < text->insert_pos)
        memcpy(buff, base + from, to - from + 1);
    else
    {
        if(from >= text->insert_pos)
            memcpy(buff, base + from - text->insert_pos +
                    text->insert_gap_end, to - from + 1);
        else
        {
            int size;
            memcpy(buff, base + from, size = text->insert_pos - from);
            memcpy(buff + size, base + text->insert_gap_end,
                   to - text->insert_pos + 1);
        }
    }
    *(buff + to - from + 1) = '\0';
    return buff;
}


char *get_line(Text *text, int line_no, char *buff)
{
    return get_text(text, line_start(text, line_no),
                          line_end(text, line_no) + 1, buff);
}


int get_text_size(Text *text)
{
    return line_end(text, text->no_of_lines - 1) + 1;
}


int line_start(Text *text, int line_no)
{
    int start;

    if(line_no == 0)
        return 0;

    start = text->line_table[line_no - 1] + 1;
    return line_no <= text->insert_line ? start : start + text->insert_delta;
}


int line_end(Text *text, int line_no)
{
    int end;

    if(line_no >= text->no_of_lines)
       line_no = text->no_of_lines - 1;

    end = text->line_table[line_no];
    return line_no < text->insert_line ? end : end + text->insert_delta;
}


int line_index_of_char(Text *text, int pos)
{
    int low, high, i;
    int *lines = text->line_table;

    if(pos > (lines[text->insert_line] + text->insert_delta))
    {
        low = text->insert_line;
        high = text->no_of_lines - 1;
        pos -= text->insert_delta;
    }
    else
    {
        low = 0;
        high = text->insert_line;
    }

    if(pos <= lines[low])
       return low;

    while(high - low > 1)
    {
        i = (high + low) / 2;
        if(lines[i] < pos)
            low = i;
        else
            high = i;
    }
    return high;
}


char *text_to_mem(Text *text, int text_pos)
{
    int pos = (text_pos < text->insert_pos ? text_pos :
                    text_pos + text->insert_gap_end - text->insert_pos);

    return get_handle(text->text_data)->base + pos;
}


_kernel_oserror *grow_lines(Text *text, int text_size)
{
    int by  = text_size / 20 + 5; /* Rough estimate of how many lines
                                     needed for text */

    return grow_lines_by(text, by);
}


_kernel_oserror *grow_lines_by(Text *text, int by)
{
    int *new_table, *new_xmax, new_size;

    new_size = text->lne_tbl_sze + by;

    if((new_table = realloc(text->line_table,
                               new_size * sizeof(int))) == NULL)
        return make_error(TextGadgets_IntMallocFail, 0);

    if((new_xmax = realloc(text->xmax_table,
                               new_size * sizeof(int))) == NULL)
        return make_error(TextGadgets_IntMallocFail, 0);

    text->line_table = new_table;
    text->xmax_table = new_xmax;
    text->lne_tbl_sze = new_size;

    return NULL;
}


void char_block(Text *text, int xcoord, int ycoord, int *line, int *index,
                int *xpos, int *ypos)
{
    int xpoints, ypoints;
    int line_no = ycoord / text->line_height;

    if(line_no >= text->no_of_lines)
       line_no = text->no_of_lines - 1;
    else
        if(line_no < 0)
            line_no = 0;

    _swix(Font_Converttopoints,_IN(1)|_IN(2)|_OUT(1), xcoord, 0, &xpoints);

    if(line_no == text->insert_line)
    {
        int start = line_start(text, line_no);
        int end = line_end(text, line_no);
        int len = text->insert_pos - start;
        char *start_pntr = text_to_mem(text, start);
        char *char_pntr;
        int points = xpoints;

        if((text->insert_gap_end - text->insert_pos) > 0)
            *(get_handle(text->text_data)->base + text->insert_pos) = '\0';

        _swix(Font_ScanString,_INR(0,4)|_IN(7)|
                              _OUT(1)|_OUT(3)|_OUT(4), text->font_handle,
                              start_pntr, 1<<17|1<<7|1<<8, xpoints, 0, len,
                              &char_pntr, &xpoints, &ypoints);

        *index = start + (int)(char_pntr - start_pntr);
        if(*index == text->insert_pos)
        {
            len = end - text->insert_pos + 1;
            start_pntr = text_to_mem(text, text->insert_pos);
            points -= xpoints;

            _swix(Font_ScanString,_INR(0,4)|_IN(7)|
                                  _OUT(1)|_OUT(3)|_OUT(4), text->font_handle,
                                   start_pntr, 1<<17|1<<7|1<<8, points, 0,
                                  len, &char_pntr, &points, &ypoints);

            *index += (int)(char_pntr - start_pntr);
            xpoints += points;
        }
    }
    else
    {
        int start = line_start(text, line_no);
        int len = line_end(text, line_no) - start + 1;
        char *start_pntr = text_to_mem(text, start);
        char *char_pntr;

        _swix(Font_ScanString,_INR(0,4)|_IN(7)|
                              _OUT(1)|_OUT(3)|_OUT(4), text->font_handle,
                              start_pntr, 1<<17|1<<7|1<<8, xpoints, 0,
                              len, &char_pntr, &xpoints, &ypoints);

        *index = start + (int)(char_pntr - start_pntr);
    }
    _swix(Font_ConverttoOS,_IN(1)|_IN(2)|_OUT(1), xpoints, 0, xpos);
    *ypos = (line_no + 1) * text->line_height;
    *line = line_no;
}


void char_pos(Text *text, int index, int *xpos, int *ypos)
{
    int xpoints;
    int line_no = line_index_of_char(text, index);

    if((line_no == text->insert_line) && (index > text->insert_pos))
    {
        int start = line_start(text, line_no);
        int len = text->insert_pos - start;
        char *start_pntr = text_to_mem(text, start);
        int xpoints2;

        if((text->insert_gap_end - text->insert_pos) > 0)
            *(get_handle(text->text_data)->base + text->insert_pos) = '\0';

        _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                              text->font_handle, start_pntr, 1<<7|1<<8,
                              0xfffffff, 0, len,
                              &xpoints);

        len = index - text->insert_pos;
        start_pntr = text_to_mem(text, text->insert_pos);

        _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                              text->font_handle, start_pntr, 1<<7|1<<8,
                              0xfffffff, 0, len,
                              &xpoints2);

        xpoints += xpoints2;
    }
    else
    {
        int start = line_start(text, line_no);
        int len = index - start;
        char *start_pntr = text_to_mem(text, start);

        _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                              text->font_handle, start_pntr, 1<<7|1<<8,
                              0xfffffff, 0, len,
                              &xpoints);
    }
    _swix(Font_ConverttoOS,_IN(1)|_IN(2)|_OUT(1), xpoints, 0, xpos);
    *ypos = (line_no + 1) * text->line_height;
}


static void draw_line(Text *text, int line_no, int base, int *block, int right,
               int fg, int bg)
{
    int start = line_start(text, line_no);
    int len = line_end(text, line_no) - start + 1;
    char *start_pntr = text_to_mem(text, start);

    _swix(ColourTrans_SetFontColours,_IN(0)|_IN(1)|_IN(2)|_IN(3), 0, bg,
          fg, 14);

    block[6] = right;
    _swix(Font_Paint,_INR(0,5)|_IN(7),
                     0, start_pntr, 1<<1|1<<5|1<<7|1<<8, block[4], base,
                     block, len);
}

static void draw_line2(Text *text, int line_no, int split, int base, int *block,
                int right, int fg, int bg, int fg2, int bg2)
{
    int start = line_start(text, line_no);
    int len = split - start;
    char *start_pntr = text_to_mem(text, start);
    int split_pnt;

    _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                      0, start_pntr,1<<7|1<<8, 0xfffffff, 0, len, &split_pnt);
    block[6] = block[4] + split_pnt;

    _swix(ColourTrans_SetFontColours,_IN(0)|_IN(1)|_IN(2)|_IN(3), 0, bg,
          fg, 14);


    _swix(Font_Paint,_INR(0,5)|_IN(7),
                     0, start_pntr, 1<<1|1<<5|1<<7|1<<8, block[4], base,
                     block, len);

    len = line_end(text, line_no) - split + 1;
    start_pntr = text_to_mem(text, split);
    block[4] = block[6];
    block[6] = right;

    _swix(ColourTrans_SetFontColours,_IN(0)|_IN(1)|_IN(2)|_IN(3), 0, bg2,
          fg2, 14);

    _swix(Font_Paint,_INR(0,5)|_IN(7),
                     0, start_pntr, 1<<1|1<<5|1<<7|1<<8, block[4], base,
                     block, len);
}

static void draw_insert(Text *text, int line_no, int split, int base,
              int *block, int right, int fg, int bg, int fg2, int bg2)
{
    int start = line_start(text, line_no);
    int len = split - start;
    char *start_pntr = text_to_mem(text, start);
    int split_pnt;

    if((text->insert_gap_end - text->insert_pos) > 0)
        *(get_handle(text->text_data)->base + text->insert_pos) = '\0';

    _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                      0, start_pntr,1<<7|1<<8, 0xfffffff, 0, len, &split_pnt);
    block[6] = block[4] + split_pnt;

    _swix(ColourTrans_SetFontColours,_IN(0)|_IN(1)|_IN(2)|_IN(3), 0, bg,
          fg, 14);


    _swix(Font_Paint,_INR(0,5)|_IN(7),
                     0, start_pntr, 1<<1|1<<5|1<<7|1<<8, block[4], base,
                     block, len);

    len = line_end(text, line_no) - split + 1;
    start_pntr = text_to_mem(text, split);
    block[4] = block[6];
    block[6] = right;

    _swix(ColourTrans_SetFontColours,_IN(0)|_IN(1)|_IN(2)|_IN(3), 0, bg2,
          fg2, 14);

    _swix(Font_Paint,_INR(0,5)|_IN(7),
                     0, start_pntr, 1<<1|1<<5|1<<7|1<<8, block[4], base,
                     block, len);
}

static void draw_line3(Text *text, int line_no, int split1, int split2,
                int base, int *block, int right, int fg, int bg)
{
    int start = line_start(text, line_no);
    int len = split1 - start;
    char *start_pntr = text_to_mem(text, start);
    int split_pnt;

    _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                      0, start_pntr, 1<<7|1<<8, 0xfffffff, 0, len, &split_pnt);
    block[6] = block[4] + split_pnt;

    _swix(ColourTrans_SetFontColours,_IN(0)|_IN(1)|_IN(2)|_IN(3), 0, bg,
          fg, 14);

    _swix(Font_Paint,_INR(0,5)|_IN(7),
                     0, start_pntr, 1<<1|1<<5|1<<7|1<<8, block[4], base,
                     block, len);

    len = split2 - split1;
    start_pntr = text_to_mem(text, split1);

    _swix(Font_ScanString,_INR(0,4)|_IN(7)|_OUT(3),
                    0, start_pntr, 1<<7|1<<8, 0xfffffff, 0, len, &split_pnt);
    block[4] = block[6];
    block[6] += split_pnt;

    _swix(ColourTrans_SetFontColours,_IN(0)|_IN(1)|_IN(2)|_IN(3), 0, fg,
          bg, 14);

    _swix(Font_Paint,_INR(0,5)|_IN(7),
                     0, start_pntr, 1<<1|1<<5|1<<7|1<<8, block[4], base,
                     block, len);
    len = line_end(text, line_no) - split2 + 1;
    start_pntr = text_to_mem(text, split2);
    block[4] = block[6];
    block[6] = right;

    _swix(ColourTrans_SetFontColours,_IN(0)|_IN(1)|_IN(2)|_IN(3), 0, bg,
          fg, 14);

    _swix(Font_Paint,_INR(0,5)|_IN(7),
                     0, start_pntr, 1<<1|1<<5|1<<7|1<<8, block[4], base,
                     block, len);
}

static void draw_selected(Text *text, int line1, int pos1, int line2, int pos2,
                   int base, int right, int *block, int fg, int bg)
{
    if(line1 < line2)
        draw_line2(text, line1, pos1, base, block, right, fg, bg, bg, fg);
    else
        if(line1 > line2)
            draw_line2(text, line1, pos1, base, block, right, bg, fg,
                       fg, bg);
        else
            if(pos1 < pos2)
                draw_line3(text, line1, pos1, pos2, base, block, right,
                           fg, bg);
            else
                draw_line3(text, line1, pos2, pos1, base, block, right,
                           fg, bg);
}


void display_lines(Text *text, int ymin, int ymax, int xorg, int yorg,
                   int fg, int bg)
{
    int ypos, i, step;
    int top_line, bottom_line;
    int top, bottom, left, right;
    int block[8];
    int start, stop;

    if(text->insert_line < text->sel_stop_line)
    {
        start = text->insert_line;
        stop = text->sel_stop_line;
    }
    else
    {
        stop = text->insert_line;
        start = text->sel_stop_line;
    }

    block[0] = block[1] = block[2] = block[3] = 0;

    if((top_line = ymin / text->line_height) < text->no_of_lines)
    {
        bottom_line = ymax / text->line_height;
        if(bottom_line >= text->no_of_lines)
            bottom_line = text->no_of_lines - 1;

        top = yorg - (top_line * text->line_height);
        bottom = top - text->line_height;
        ypos = top - text->font_base;

        _swix(Font_Converttopoints,_IN(1)|_IN(2)|_OUT(1)|_OUT(2),
              xorg, top, &left, &top);
        _swix(Font_Converttopoints,_IN(1)|_IN(2)|_OUT(1)|_OUT(2),
              0xffff, bottom, &right, &bottom);
        _swix(Font_Converttopoints,_IN(1)|_IN(2)|_OUT(1)|_OUT(2),
              text->line_height, ypos, &step, &ypos);

        _swix(Font_SetFont,_IN(0), text->font_handle);

        for(i = top_line; i <= bottom_line; i++)
        {
            block[4] = left;
            block[5] = bottom;
            block[7] = top;

            if(i == text->insert_line)
                if(text->sel_stop_pos == -1)
                    draw_insert(text, i, text->insert_pos, ypos, block, right,
                               fg, bg, fg, bg);
                else
                    draw_selected(text, i, text->insert_pos,
                                  text->sel_stop_line, text->sel_stop_pos,
                                  ypos, right, block, fg, bg);
            else
                 if(i == text->sel_stop_line)
                     if(text->sel_stop_pos != -1)
                         draw_selected(text, i, text->sel_stop_pos,
                                  text->insert_line, text->insert_pos,
                                  ypos, right, block, fg, bg);
                    else
                        draw_line(text, i, ypos, block, right, fg, bg);
                 else
                     if((text->sel_stop_pos == -1) || (i > stop) ||
                         (i < start))
                         draw_line(text, i, ypos, block, right, fg, bg);
                     else
                         draw_line(text, i, ypos, block, right, bg, fg);

            top = bottom;
            bottom -= step;
            ypos -= step;
        }
    }
}


#if 0
void dump_object(FILE *out, Text *text)
{
    int i;
    char line[256];

    fprintf(out, "\n\nTEXT OBJECT\n-----------\n\n");
    fprintf(out, "Insert_line   : %d\n", text->insert_line);
    fprintf(out, "Insert_delta  : %d\n", text->insert_delta);
    fprintf(out, "Insert_pos    : %d\n", text->insert_pos);
    fprintf(out, "Insert_gap_end: %d\n", text->insert_gap_end);
    fprintf(out, "No_of_lines   : %d\n", text->no_of_lines);
    fprintf(out, "lne_tbl_sze   : %d\n", text->lne_tbl_sze);
    fprintf(out, "sel_stop_pos  : %d\n", text->sel_stop_pos);
    fprintf(out, "sel_stop_line : %d\n", text->sel_stop_line);
    fprintf(out, "xmax          : %d\n", text->xmax);
    fprintf(out, "xmax_line     : %d\n", text->xmax_line);

    fprintf(out, "\nLine table:\n");
    for(i = 0; i < text->no_of_lines; i++)
    {
        fprintf(out, "\tLine: %d\n", i);
        fprintf(out, "\t\traw: %d start: %d end: %d xmax: %d\n", text->line_table[i],
                  line_start(text, i), line_end(text, i), text->xmax_table[i]);
        fprintf(out, "\t\t%s", get_line(text, i, line));
    }

    fprintf(out, "\nMemory block:\n");
    fprintf(out, "\tbase address: %d\n", (int) text->text_data->base);
    fprintf(out, "\tsize        : %d\n", text->text_data->size);
    fprintf(out, "\tfree        : %d\n", text->text_data->free);
}
#endif
