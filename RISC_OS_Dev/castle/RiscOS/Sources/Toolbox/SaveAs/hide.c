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
 * Purpose: hide a SaveAs Object
 * Author:  TGR
 * History: 17-Feb-94: TGR: created
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include "kernel.h"
#include "swis.h"

#include "const.h"
#include "macros.h"
#include "debug.h"
#include "mem.h"
#include "messages.h"

#include "objects/toolbox.h"
#include "objects/window.h"
#include "objects/saveas.h"

#include "auxiliary.h"
#include "object.h"
#include "task.h"

#include "hide.h"

extern _kernel_oserror *hide_object (_kernel_swi_regs *r, TaskDescriptor *t)
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
     * Remove the object from view.  For efficiency, we should stop expressing
     * interest in any events which can't happen whilst the Object is
     * hidden.
     *
     */

   _kernel_swi_regs     regs;
   SaveAsInternal      *internal   = (SaveAsInternal *) r->r[2];

   if (~internal->flags & SaveAsInternal_IsShowing)
      return NULL;

   internal->flags &= ~SaveAsInternal_IsShowing;

   if (internal->wimp_message) {
      if (internal->wimp_message) mem_freek (internal->wimp_message);
      internal->wimp_message = NULL;
   }
   regs.r[0] = 0;
   regs.r[1] = (int) internal->sub_object_id;

   IGNORE(t);

   return _kernel_swi (Toolbox_HideObject, &regs, &regs);

/*
   global_menu = 0;
*/

/*
   return (internal->flags & SaveAsInternal_GenerateHideEvent) ? dialogue_completed (object_id) : NULL;
*/
}

