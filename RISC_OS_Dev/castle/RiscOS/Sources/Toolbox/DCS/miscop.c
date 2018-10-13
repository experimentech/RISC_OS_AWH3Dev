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
/* Title:   miscop.c
 * Purpose: miscellanaous operations on a Generic Object
 * Author:  IDJ
 * History: 7-Oct-93: IDJ: created
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
#include "objects/DCS.h"

#include "object.h"
#include "task.h"

#include "miscop.h"


extern _kernel_oserror *miscop_object (_kernel_swi_regs *r, TaskDescriptor *t,int class)
{
    IGNORE(t);
    
    /*
     * do a "miscellaneous (ie object-specific) operation on an object
     * R0 = 6
     * R1 = Object ID
     * R2 = internal handle returned when Object was created
     * R3 = wimp task handle of caller (use to identify task descriptor)
     * R4 -> user regs R0-R9
     *      R0 =  flags
     *      R1 =  Object ID
     *      R2 =  method code
     *      R3-R9 method-specific data
     */

    /*
     * This is the routine which deals with all object-specific operations.
     *
     *
     */

    /* it just so happens that Quit and DCS have the same methods */

    _kernel_swi_regs *user_regs    = USER_REGS(r);
    _kernel_swi_regs regs;
    _kernel_oserror *e= NULL;

    regs = * user_regs;
    regs.r[1] = ((Object *) r->r[2]) ->window;                /* set object id to window id, as we pass most on */

    switch(regs.r[2]) {
        case DCS_GetWindowID:
           user_regs->r[0] = regs.r[1];
           break;

        case DCS_SetMessage:
           regs.r[2] = Button_SetValue;
           regs.r[4] = regs.r[3];
           regs.r[3] = class<<4;               /* Cid of text */
           return _kernel_swi(Toolbox_ObjectMiscOp,&regs,&regs);
           break;
        case DCS_GetMessage:
           regs.r[2] = Button_GetValue;
           regs.r[5] = regs.r[4];
           regs.r[4] = regs.r[3];
           regs.r[3] = class<<4;               /* Cid of text */
           e = _kernel_swi(Toolbox_ObjectMiscOp,&regs,&regs);
           if (!e) user_regs->r[4] = regs.r[5];         /* update len */
           break;

        case DCS_SetTitle:
           regs.r[2] = Window_SetTitle;
           e = _kernel_swi(Toolbox_ObjectMiscOp,&regs,&regs);
           break;

        case DCS_GetTitle:
           regs.r[2] = Window_GetTitle;
           e = _kernel_swi(Toolbox_ObjectMiscOp,&regs,user_regs);
                /* note user_regs, so R4 gets updated */
           break;

        default:
           break;
        }
    return e;
}

