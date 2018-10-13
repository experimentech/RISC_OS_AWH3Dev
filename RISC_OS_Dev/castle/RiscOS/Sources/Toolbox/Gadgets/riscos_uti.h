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
 * riscos_uti.h
 *
 * The utils.c file defines various functions that might otherwise
 * have been found in a library like RISC OS Lib, ie. small functions
 * based on SWI calls to RISC OS.
 *
 */
#ifndef RISCOS_UTI_H
#define RISCOS_UTI_H

#define FAILED 0
#define SUCCESS 1

/*
 * This structure is used to carry information about a sprite around
 */

typedef struct
{
    char name[12];
    int width;
    int height;
    int depth;
    unsigned int mode;
} ROSpriteInfo;

extern MessagesFD	messages;

int decompress(char **file, int *size);

int file_size(char *name) ;

_kernel_oserror * file_load(char *name, char *add) ;

void CLG(void);

char *object_name(ObjectID id);

int is_object(ObjectID id,char *name);

void warn_about_memory(void);

ObjectID named_object(char *name);

char *lookup_token(const char *t);

_kernel_oserror *sprite_area_create(void);

_kernel_oserror *sprite_area_delete(void);

_kernel_oserror *sprite_create(unsigned int width, unsigned int height,
		unsigned int depth, char **name);

_kernel_oserror *sprite_delete(char *name);

_kernel_oserror *os_switch_to_sprite (ROSpriteInfo *sprinfo, int *old);

_kernel_oserror * os_switch_to_screen (int *old);

_kernel_oserror *os_set_gcol (unsigned int p1);

_kernel_oserror *os_switch_surface (ROSpriteInfo *sprinfo);

#define PLOT_MOVE		4
#define PLOT_DRAW		5
#define PLOT_BACK		7
#define PLOT_DRAW_RELATIVE	1
#define PLOT_LINE		0
#define PLOT_TRIANGLE_FILL	80
#define PLOT_RECTANGLE_FILL	96
#define PLOT_ARC		160
#define PLOT_SEGMENT		168
#define PLOT_BLOCK_COPY		190
#define PLOT_ELLIPSE		192
#define PLOT_ELLIPSE_FILL	200
_kernel_oserror *os_plot(unsigned short command, int x, int y);
_kernel_oserror * os_sprite_plot_to_screen (ROSpriteInfo *sprinfo, char *tt, long x, long y);

// Following functions are defined in riscos_graphics.s
wimp_Bbox get_graphics_window(void);
void set_graphics_window(wimp_Bbox box);
/* set_graphics_window_in_window ------------------------------------------
 * Sets a graphics window inside existing graphics window
 * Returns: 0 if new window is 0*0 pixels, else 1
 */
int set_graphics_window_in_window(wimp_Bbox inside, wimp_Bbox outside);

_kernel_oserror *colourtrans_set_gcol(unsigned int colour,
			unsigned int flags, unsigned int action);
_kernel_oserror *colourtrans_set_font_colours(unsigned int font_handle,
			unsigned int background, unsigned int foreground,
			unsigned int max_offset);

#endif
