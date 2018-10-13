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
#ifndef main_H
#define main_H

/* > main.h */
/*
 *  Main header for the Paint program
 *
 *  DAHE, 04 Sep 89: heap allocation added
 *        07 Sep 89: symbolic SWI numbers
 *  JAB,  23 Jan 91: Added structure 'snapshotstr' for snapshot
 *                   implementation
 *  CDP,  27 Jan 92: Added include for fixes.h.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "wimp.h"
#include "sprite.h"
#include "win.h"
#include "msgs.h"
#include "colourpick.h"

#include "ftrace.h"

#if TRACE
  #define spencer(s) s;
  #define spencer2(s) s

  #define WHETHER(c) ((c)? "true": "false")
#else
  #define spencer(s) ;
  #define spencer2(s)
#endif

#define ENTRIES(n) ((n) <  3? 1 << (1 << (n)): (n) == 3? 16: 0)
#define MIN(x, y) ((x) < (y)? (x): (y))
#define MAX(x, y) ((x) > (y)? (x): (y))

#define toolspacesize 9
    /* amount of scratchspace a tool is given */

#define NAME_LIMIT 12 /*not defined in sprite.h!*/

typedef struct
{
  int scale_xmul;
  int scale_ymul;
  int scale_xdiv;
  int scale_ydiv;
} main_scaling_block;        /* ready for use by sprite scaling ops */

typedef struct
{
  char set [20];
  sprite_area *sarea;
} main_ecf;

typedef
  struct main_ttab
  { struct main_ttab *link;
    int refcount;

    int smode, spalsize;
    int *spal;
    int dlog2bpp,dncolour,dmodeflags;
    int *dpal; /*If these match, the rest must be the same.*/

    int ttab_size;
    char *table;     /* flex'ed real translation table */
    int ttab2_size;
    char *table2;     /* flex'ed real GCOL translation table */
  }
  main_ttab;

typedef struct main_sprite_window
{
  struct main_sprite_window *link;
  struct main_window        *window;
  struct main_sprite        *sprite;
  char                      *title;
  main_scaling_block         blobsize;
  char                       gridcol;
  BOOL                       read_only;
} main_sprite_window;

typedef struct main_colour
{
  unsigned int colour; /* Palette index/colour number, without alpha channel */
  char         alpha;  /* 0-255. If 1bpp (i.e. on/off mask) only valid values are 0 & 255 */
  BOOL         ecf;    /* True if colour is actually ECF index */
} main_colour;

/* main_sprite flags */
#define MSF_SELECTED    1
typedef struct main_sprite
{
  struct main_sprite *link;
  struct main_file   *file;        /* parent file info */
  main_sprite_window *windows;     /* windows onto sprite */
  int                 offset;      /* of sprite in file */
  int                 spriteno;    /* index of sprite in file */
  main_ttab          *transtab;    /* colour translation table */
  main_scaling_block  mode;        /* mode conversion */
  main_scaling_block  iconsize;
  wimp_w              colourhandle;
  main_ecf            ECFs [4];
  main_colour         gcol;        /* current painting colour */
  main_colour         gcol2;       /* current colour for ADJUST */
  int                 toolspace [toolspacesize]; /* tool scratch space */
  colourpicker_d      colourdialogue; /* handle of colourpicker */
  char               *colourtitle; /* indirected colour title */
  char                needsnull;   /* set if tracking pointer */
  char                coloursize;
  unsigned int        flags;
} main_sprite;

typedef struct main_file
{
  main_sprite        *sprites;       /* linked list of sprites */
  char               *filename;      /* flex array */
  sprite_area        *spritearea;    /* flex array of bytes */
  char               *title;         /* indirected title space */
  char                fullinfo;      /* big icons or full info */
  char                modified;
  char                use_current_palette;
  char                lastwidth;
  struct main_window *window;
} main_file;

typedef union
{
  main_file           file;
  main_sprite_window  sprite;
} main_info_block;

typedef enum
{
  main_window_is_file,
  main_window_is_sprite
} main_window_tag;

#define MW_SELDRAGRIGHT  1
#define MW_SELSAVING     2
#define MW_SELSAVEBYDRAG 4
typedef struct main_window
{
  struct main_window *link;
  wimp_w              handle;
  main_window_tag     tag;
  main_info_block    *data;
  struct
  {
    int          count;
    int          flags;
    wimp_box     transbox; /* Holds menu selected temporary */
    main_sprite *transsprite;
  } selection;
} main_window;

typedef
  struct
  { struct {BOOL full_info, use_desktop_colours;} display;
    struct {BOOL show_colours, small_colours;} colours;
    struct {BOOL show_tools;} tools;
    struct {int mul, div;} zoom;
    struct {BOOL show; int colour;} grid;
    struct {BOOL on;} extended;
  }
  main_options;

typedef
  struct
  { wimp_wind t;
    char ind [128];
  }
  main_template; /*Fix overwriting store bugs. J R C 14th Oct 1993*/

extern main_options main_current_options;
  /*Set at start up from initial_options and <Paint$Options>. Maintained
    by the routines that change state.*/
extern main_window *main_windows;
extern const wimp_box main_big_extent;

extern os_error *main_read_pixel (sprite_area *, sprite_id *, int, int,
    sprite_colour *);

extern void main_snapshot_show (void);

extern int main_create_window (wimp_wind *, wimp_w *, win_event_handler,
    void *);
extern void main_delete_window (wimp_w);
extern void main_window_delete (main_window *);

extern int __root_stack_size;

#if TRACE
  #define main_NO_ROOM(a) main_no_room (a)

  extern void main_no_room (char *);
#else
  #define main_NO_ROOM(a) main_no_room ()

  extern void main_no_room (void);
#endif

extern void main_set_extent (main_window *);

extern void main_set_title (main_window *, char *);

/* returns 0 if not over a sprite or window->selection.count >1 */
extern main_sprite *main_pick_menu_button_sprite (main_window *);

extern void main_force_redraw (wimp_w);

extern void main_help_message (char *tag, wimp_eventstr *);

extern void main_set_printer_data (void);

extern void main_set_modified (main_file *);

extern void main_allocate_position (wimp_box *);

extern void main_check_position (main_window *);

extern void main_select_all(main_window *);

extern void main_clear_all(main_window *);

extern int main_selection_file_size(main_window *);

extern int main_save_selection(char *, void *);

/* returns work area of all bounding boxes for a sprite*/
extern BOOL main_get_all_sprite_bboxes (main_window *,main_sprite *,
                                        wimp_box *,wimp_box *,
                                        wimp_box *);

/*************************************************************
 *  Manifests for the size sprites appear in the file window *
 *************************************************************/

#define main_FILER_TextHeight 40
#define main_FILER_TextWidth  20
#define main_FILER_XSize  (12 * (main_FILER_TextWidth - 4))
#define main_FILER_YSize main_FILER_XSize
#define main_FILER_Border  (main_FILER_TextWidth - 4)
#define main_FILER_TotalHeight \
     (main_FILER_YSize + main_FILER_TextHeight + main_FILER_Border)
#define main_FILER_TotalWidth  (main_FILER_XSize + main_FILER_Border)

#define main_FILER_FullInfoWidth \
     (main_FILER_XSize/2 + 55*main_FILER_TextWidth)
#define main_FILER_FullInfoHeight  (3*main_FILER_TextHeight)

/* Macro to do source clipping:
   provide graphics window wimp_box *, bounding box of object */

#define main_CLIPS(g, myx0, myy0, myx1, myy1) (!((myx0) > (g)->x1 || \
     (myx1) < (g)->x0 || (myy0) > (g)->y1 || (myy1) < (g)->y0))

/* Claim idle events */
extern void main_claim_idle (wimp_w);

extern os_error *main_error (char *);

extern void main_iprintf (int, int, int, char *, ...);

#endif
