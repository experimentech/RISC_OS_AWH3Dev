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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"



#include "<Toolbox$Common>.const.h"
#include "<Toolbox$Common>.macros.h"
#include "<Toolbox$Common>.services.h"
#include "<Toolbox$Common>.debug.h"
#include "<Toolbox$Common>.mem.h"
#include "<Toolbox$Common>.wimp.h"
#include "<Toolbox$Common>.style.h"
#include "<Toolbox$Common>.string32.h"
#include "<Toolbox$Common>.objects.toolbox.h"
#include "<Toolbox$Common>.objects.menu.h"
#include "<Toolbox$Common>.objects.iconbar.h"
#include "<Toolbox$Common>.objects.window.h"

#define TEMPLATE_MENUFLAGS_GENERATE_EVENT 0x00000001
#define TEMPLATE_MENUFLAGS_TICK           0x00000001
#define TEMPLATE_MENUFLAGS_DOTTED_LINE    0x00000002
#define TEMPLATE_MENUFLAGS_FADED          0x00000100
#define TEMPLATE_MENUFLAGS_SPRITE         0x00000200
#define TEMPLATE_MENUFLAGS_SUBMENU        0x00000400

#define object_FCREATE_ON_LOAD            0x00000001
#define object_FSHOW_ON_CREATE            0x00000002
#define object_FSHARED                    0x00000004
#define object_FANCESTOR                  0x00000008


/*
 * Resource file header
 */

unsigned int resfile_start  = 'FSER' ;
unsigned int version        = 100 ;
unsigned int objects_offset = -1 ; /* /* FIX UP as &resfile_start - &string_table_offset */

/*
 * Start of first object
 */

unsigned int string_table_offset     = -1 ; /* Ohpleaseohpleaseohplease */
unsigned int messages_table_offset   = -1 ;
unsigned int relocation_table_offset = -1 ;

/*
 * Window object header
 */

ObjectTemplateHeader window_header = {
                                   Window_ObjectClass,
                                   object_FSHOW_ON_CREATE,
                                   100,
                                   "window\0\0\0\0\0", /* Padded */
                                   sizeof (WindowTemplate) + sizeof (ObjectTemplateHeader),
                                   NULL,
                                   (void *)0,   /* /* FIX UP */
                                   sizeof (WindowTemplate)
                                  };

/*
 * Start the window template here
 */

WindowTemplate  window_template = {
                            Window_AutoOpen|Window_AutoClose,
                            NULL, /* Help message */
                            0,    /* Max help message */
                            NULL, /* Pointer shape */
                            0,    /* Max pointer shape */
                            0,    /* Pointer X hot spot */
                            0,    /* Pointer Y hot spot */
                            NULL, /* Menu */
                            0,    /* Number of key shortcuts */
                            NULL, /* Keyboard shortcuts (offset) */
                            0,    /* number of gadgets */
                            NULL, /* gadgets (offset) */
                            {
                                {400, 400, 500, 500},   /* box */
                                0,   /* scx */
                                0,   /* scy */
                                -1,  /* behind */
                                wimp_WINDOWFLAGS_MOVEABLE|
                                wimp_WINDOWFLAGS_AUTOREDRAW|
                                wimp_WINDOWFLAGS_ALLOW_OFF_SCREEN|
                                wimp_WINDOWFLAGS_AUTOREPEAT_SCROLL_REQUEST|   /* flags */
                                wimp_WINDOWFLAGS_HAS_BACK_ICON|
                                wimp_WINDOWFLAGS_HAS_CLOSE_ICON|
                                wimp_WINDOWFLAGS_HAS_TITLE_BAR|
                                wimp_WINDOWFLAGS_HAS_TOGGLE_ICON|
                                wimp_WINDOWFLAGS_HAS_VSCROLLBAR|
                                wimp_WINDOWFLAGS_HAS_ADJUST_SIZE_ICON|
                                wimp_WINDOWFLAGS_HAS_HSCROLLBAR|
                                wimp_WINDOWFLAGS_USE_NEW_FLAGS,
                                {'\x07','\x02','\x00','\x01','\x03','\x01','\x0c','\x00'},
                                {0, -1000, 1000, 0},   /* ex */
                                wimp_ICONFLAGS_TEXT|
                                wimp_ICONFLAGS_HCENTRE|
                                wimp_ICONFLAGS_VCENTRE|
                                wimp_ICONFLAGS_INDIRECT, /* title_flags */
                                wimp_BUTTON_NEVER,       /* work area flags */
                                NULL,                    /* sprite area */
                                0,                       /* min_size */
                                {0},                     /* title data - fix up later */
                                0                        /* nicons */
                            }
                           };

int numrelocs = 0 ;

int end ;

int main (int argc, char **argv)
{
  FILE *f ;

  /*
   * Fix up offsets
   */

  objects_offset = (int) &string_table_offset - (int) &resfile_start ;
  window_header.body = (void *) ((int) &window_template - (int) &window_header) ;
  relocation_table_offset = -1 ; /* (int) &numrelocs - (int) &string_table_offset ; */

  fprintf (stderr, "Objects offset is %d, body offset is %d, relocation table offset is %d\n",
           objects_offset, window_header.body, relocation_table_offset) ;

  f = fopen ("res", "wb") ;
  if (f == NULL)
  {
    fprintf (stderr, "Bugger: Can't open file 'res' - what's wrong?\n") ;
    exit (EXIT_FAILURE) ;
  }

  fwrite (&resfile_start, (int) &end - (int) &resfile_start, 1, f) ;

  fclose (f) ;

  exit (EXIT_SUCCESS) ;
}
