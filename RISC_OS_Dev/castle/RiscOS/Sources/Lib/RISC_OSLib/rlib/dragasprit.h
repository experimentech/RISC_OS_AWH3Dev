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
/****************************************************************************
 * This source file was written by Acorn Computers Limited. It is part of   *
 * the RISCOS library for writing applications in C for RISC OS. It may be  *
 * used freely in the creation of programs for Archimedes. It should be     *
 * used with Acorn's C Compiler Release 3 or later.                         *
 *                                                                          *
 ***************************************************************************/

/*
 * Title  : dragasprit.h
 * Purpose: provide access to RISC OS DragASprite facilities
 *          
 */

# ifndef __dragasprit_h
# define __dragasprit_h

# ifndef __os_h
# include "os.h"
# endif

# ifndef __sprite_h
# include "sprite.h"
# endif

# ifndef __wimp_h
# include "wimp.h"
# endif

typedef enum {                          /* dragasprit options */

  dragasprite_HJUSTIFY_LEFT      = 0x00000000,   /* sprite left justified in box */
  dragasprite_HJUSTIFY_CENTRE    = 0x00000001,   /* sprite horizontally centred in box */
  dragasprite_HJUSTIFY_RIGHT     = 0x00000002,   /* sprite right justified in box */

  dragasprite_VJUSTIFY_BOTTOM    = 0x00000000,   /* sprite at bottom of box */
  dragasprite_VJUSTIFY_CENTRE    = 0x00000004,   /* sprite half way up box */
  dragasprite_VJUSTIFY_TOP       = 0x00000008,   /* sprite at top of box */

  dragasprite_BOUNDTO_SCREEN     = 0x00000000,   /* bound thing to screen */
  dragasprite_BOUNDTO_WINDOW     = 0x00000010,   /* bound thing to window the pointer's over */
  dragasprite_BOUNDTO_USERBOX    = 0x00000020,   /* bound thing to a user specified box */

  dragasprite_BOUND_BOX          = 0x00000000,   /* thing to bound is a box (sprite or original box) */
  dragasprite_BOUND_POINTER      = 0x00000040,   /* thing to bound is pointer */

  dragasprite_DROPSHADOW_MISSING = 0x00000000,   /* don't do a drop shadow effect */
  dragasprite_DROPSHADOW_PRESENT = 0x00000080    /* do do a drop shadow effect */

} dragasprite_options;

/* ----------------------- dragasprite_start --------------------------------
 * Start a drag, dragging a sprite
 *
 */
extern os_error * dragasprite_start(dragasprite_options,sprite_area *,char *,wimp_box *,wimp_box *);

/* ----------------------- dragasprite_stop ---------------------------------
 * Stop a drag, informing Drag A Sprite of this.
 *
 */
extern os_error * dragasprite_stop( void );

# endif

/* end of dragasprit.h */
