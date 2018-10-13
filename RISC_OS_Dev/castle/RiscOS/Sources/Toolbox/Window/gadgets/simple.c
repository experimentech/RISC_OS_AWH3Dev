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
/* Title:   simple.c
 * Purpose: simple gadgets
 * Author:
 * History: NK : 08-Apr-94
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "swis.h"
#include "kernel.h"

#include "const.h"
#include "macros.h"
#include "debug.h"
#include "mem.h"
#include "string32.h"
#include "messages.h"

#include "style.h"
#include "objects/toolbox.h"
#include "objects/window.h"

#include "../globals.h"
#include "../gadgets.h"
#include "../object.h"
#include "../veneers.h"

#include "simple.h"

extern int WIMP_WINDOW;

typedef struct _simple_internal
{
  int   icon_handle ;
  int   icon_handle2 ;
  int   icon_handle3 ;
} simple_internal ;


_kernel_oserror *simple_remove   (GadgetInternal *gadget, ObjectID window,int recurse)
{
    _kernel_oserror  *e=NULL;
    simple_internal *ab = (simple_internal *) gadget->data;
 
    IGNORE(window);
    IGNORE(recurse);

    /*
     * Remove the icon from the window
     */

    e = DeleteIcons(gadget,window);

    /*
     * ... and free up the memory we have used
     */

    mem_free (ab, "removing simple gadget data");

    return e;
}

extern int WIMP_VERSION_NUMBER;                                       

static _kernel_oserror *if310(GadgetInternal *gadget,simple_internal *ab,int do_fade)
{
     _kernel_swi_regs regs;
     regs.r[0] = (int) &(gadget->gadget_hdr);
     regs.r[1] = (int) ab;
     regs.r[2] = WIMP_WINDOW;
     regs.r[3] = do_fade;
     return (_kernel_swi(0x82d00,&regs,&regs));

}

_kernel_oserror *simple_set_fade (GadgetInternal *gadget, ObjectID window, int do_fade)
{
  wimp_SetIconState set ;
  simple_internal *ab = (simple_internal *) gadget->data ;
  window=window;                              /* Not Used */

  DEBUG debug_output ("fade", "simple_set_fade: fade flag is %d\n\r", do_fade) ;
 
  if (WIMP_VERSION_NUMBER < 350) return if310(gadget,ab,do_fade);

  set.window_handle = WIMP_WINDOW;
  set.icon_handle   = ab->icon_handle ;
  set.clear_word    = wimp_ICONFLAGS_FADED ;
  set.EOR_word      = do_fade ? wimp_ICONFLAGS_FADED : 0 ;

  return wimp_set_icon_state( &set);
}


_kernel_oserror *simple_set_fade2 (GadgetInternal *gadget, ObjectID window, int do_fade)
{
  _kernel_oserror   *e;
  wimp_SetIconState  set ;
  simple_internal      *l = (simple_internal *) gadget->data ;

  window=window;                              /* Not Used */

  DEBUG debug_output ("fade", "simple_set_fade2: fade flag is %d\n\r", do_fade) ;

  if (WIMP_VERSION_NUMBER < 350) return if310(gadget,l,do_fade);

  set.window_handle = WIMP_WINDOW;
  set.icon_handle   = l->icon_handle ;
  set.clear_word    = wimp_ICONFLAGS_FADED ;
  set.EOR_word      = do_fade ? wimp_ICONFLAGS_FADED : 0 ;

  if ((e = wimp_set_icon_state( &set)) != NULL)  return (e);
                                            
        /* note _Base, not _Type */

  if (gadget->gadget_hdr.type == Slider_Base) {
        set.icon_handle = l->icon_handle3;
        if ((e = wimp_set_icon_state( &set)) != NULL)  return (e);
  }

  set.icon_handle   = l->icon_handle2 ;
                                      
  return wimp_set_icon_state( &set);
}
