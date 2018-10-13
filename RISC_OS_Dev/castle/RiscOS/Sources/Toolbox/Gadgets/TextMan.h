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
/* Title:   TextMan.h
 * Purpose: Header file for text manager.
 *
 * Revision History
 * rlougher  Nov 96  Created
 */

#define INSERTION_GAP 256

typedef struct
{
    int    insert_line;
    int    insert_delta;
    int    insert_pos;
    int    insert_gap_end;
    int    no_of_lines;
    int    lne_tbl_sze;
    int    *line_table;
    int    *xmax_table;
    int    font_handle;
    int    font_base;
    int    line_height;
    int    sel_stop_pos;
    int    sel_stop_line;
    int    xmax;
    int    xmax_line;
    int    tab_stop;
    int    space;
    int    margin;
    HandleId text_data;
} Text;

_kernel_oserror *create_text(int size, int font_handle, Text **text);
void            delete_text(Text *text);
_kernel_oserror *compose_text(Text *text);
_kernel_oserror *create_insertion(Text *text, int pos);
_kernel_oserror *move_insertion(Text *text, int pos);
_kernel_oserror *replace_text(Text * text, int from, int to, const char *str,
                          int *first_line, int *last_line, int *line_delta);
_kernel_oserror *insert_text(Text *text, char *str, int *first_line,
                             int *last_line, int *line_delta);
_kernel_oserror *set_font(Text *text, int font_handle);
char *get_text(Text *text, int from, int to, char *buff);
int get_text_size(Text *text);

void close_insertion(Text *text);

char *get_line(Text *text, int line_no, char *buff);
void display_lines(Text *text, int ymin, int ymax, int xorg, int yorg,
                   int fg, int bg);

void char_block(Text *text, int xcoord, int ycoord, int *line_no, int *index,
                int *xpos, int *ypos);
void char_pos(Text *text, int index, int *xpos, int *ypos);
int line_end(Text *text, int line_no);
int line_index_of_char(Text *text, int pos);
void dump_object(FILE *out, Text *text);
