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
/* Title:   getstate.c
 * Purpose: return state for a FontDbox Object
 * Author:  TGR
 * History: 27-Spr-94: TGR: created
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
#include "objects/generic.h"

#include "object.h"
#include "task.h"

#include "getstate.h"

extern _kernel_oserror *getstate_object (_kernel_swi_regs *r, TaskDescriptor *t)
{

    /*
     * request for info about an object
     * R0 = 5
     * R1 = Object ID
     * R2 = internal handle returned when Object was created
     * R3 = wimp task handle of caller (use to identify task descriptor)
     * R4 -> user regs R0-R9
     *      R0 =  flags
     *      R1 =  Object ID
     */

    /*
     * return state in R0
     *
     */

   FontDboxInternal  *internal = (FontDboxInternal *) r->r[2];

   r->r[0] = (internal->flags & FontDboxInternal_IsShowing) ?
                        Toolbox_GetObjectState_Showing : 0;
   IGNORE(t);

   return NULL;
}
