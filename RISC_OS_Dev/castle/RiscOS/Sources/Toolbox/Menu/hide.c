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
/* Title:   hide.c
 * Purpose: hide a Menu Object
 * Author:  TGR
 * History: 4-Nov-93: TGR: created
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include "kernel.h"
#include "swis.h"

#include "const.h"
#include "macros.h"
#include "objects/toolbox.h"
#include "objects/menu.h"
#include "string32.h"
#include "messages.h"
#include "debug.h"
#include "mem.h"

#include "auxiliary.h"

#include "object.h"
#include "task.h"

#include "hide.h"

extern _kernel_oserror *hide_menu (_kernel_swi_regs *r, TaskDescriptor *t)
{

    /*
     * request to hide an object
     * R0 = 4
     * R1 = Object ID
     * R2 = internal handle returned when Object was created
     * R3 = wimp task handle of caller (use to identify task descriptor)
     * R4 -> user regs R0-R9
     *      R0 =  flags
     *      R1 =  Object ID
     *
     */

    /*
     * Remove the object from view.
     */

   _kernel_oserror   *e;
   _kernel_swi_regs   regs;
   ObjectID           object_id   = (ObjectID) r->r[1];

   if ((global_menu.t == t) && (global_menu.top != NULL) && (global_menu.top->hdr.object_id == object_id)) {

      DEBUG debug_output ("h","Menu: hiding menus\n");

      regs.r[1] = -1;

      if ((e = _kernel_swi (Wimp_CreateMenu, &regs, &regs)) != NULL)
         return e;

      return has_been_hidden ();
   }
   return NULL;
}
