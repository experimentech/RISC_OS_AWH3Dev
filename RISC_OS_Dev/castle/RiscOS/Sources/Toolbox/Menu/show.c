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
/* Title:   show.c
 * Purpose: show a Menu Object
 * Author:  TGR
 * History: 4-Nov-93: TGR: created
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"

#include "const.h"
#include "macros.h"
#include "string32.h"
#include "messages.h"
#include "objects/toolbox.h"
#include "objects/menu.h"
#include "debug.h"
#include "mem.h"

#include "object.h"
#include "auxiliary.h"
#include "task.h"

#include "show.h"

_kernel_oserror *show_menu_coords (_kernel_swi_regs *user_regs,DisplayInfo *menu_coords);

extern _kernel_oserror *show_menu (_kernel_swi_regs *r, TaskDescriptor *t)
{

    /*
     * request to show an object
     * R0 = 3
     * R1 = Object ID
     * R2 = internal handle returned when Object was created
     * R3 = wimp task handle of caller (use to identify task descriptor)
     * R4 -> user regs R0-R9
     *      R0 =  flags
     *      R1 =  Object ID
     *      R2 =  type of show
     *      R3 -> buffer giving Object-specific data for showing this
     *            Object
     *      R4 =  Parent Object ID
     *      R5 =  Parent Component ID
     */

    /*
     * Function to "display" an Object on the screen.  If R2 == -1, then
     * display in 64 OS units left of pointer. If R2 == -2, then display
     * 96 OS units from bottom of icon bar.
     * If Object has bit set to say warn before show, then we should just
     * send Toolbox Event, and wait for the next call to Wimp_Poll after
     * the event is delivered before the Object is actually shown
     * (ie catch it in the prefilter).
     *
     */

   _kernel_swi_regs   regs,
                     *user_regs     = (_kernel_swi_regs *) r->r[4];
   _kernel_oserror   *e;
   MenuInternal      *menu_int      = (MenuInternal *) r->r[2];
   ObjectID           object_id     = menu_int->hdr.object_id;
   ToolboxEvent       toolbox_event;
   Menu_AboutToBeShown_Event
                     *menu_atbs;
   DisplayInfo        menu_coords;
   BOOL               is_submenu    = user_regs->r[0] & 2;
   int                count;

   DEBUG debug_output ("s","Menu: entering show, task = 0x%x, menu_int=0x%x, object_id=0x%x\n",(int)t,menu_int,object_id);
   DEBUG if (object_id != (ObjectID) user_regs->r[1] || user_regs->r[1] != r->r[1]) debug_output ("s","Menu: sanity check reveals object ids unequal\n");

   if ((e = show_menu_coords (user_regs,&menu_coords)) != NULL)
       return e;

   global_menu.x          = menu_coords.x;
   global_menu.y          = menu_coords.y;
   global_menu.current    = menu_int;
   global_menu.t          = t;

   if (!is_submenu) {
      global_menu.top = global_menu.current;
   }
   global_menu.flags &= ~GLOBAL_MENU_INFO_FLAGS_SHOW_NEXT;

   r->r[0] = (int) global_menu.current->hdr.wimp_menu;

   count = (menu_int->hdr.flags&MENU_INT_FLAGS_GENERATE_SHOW_EVENT)
           ? ((menu_int->hdr.show_event)
             ? 2
             : 1)
           : 0;

   if (!count) {
      global_menu.flags |= GLOBAL_MENU_INFO_FLAGS_IS_SHOWING;
      return (is_submenu) ? menu_show_submenu_actual () : menu_show_actual ();
   }
   while (count--) {
      if (count) {
         DEBUG debug_output ("s","Menu: sending 0x%x as show_event\n",menu_int->hdr.show_event);
         toolbox_event.hdr.event_code = menu_int->hdr.show_event;
      } else {
         DEBUG debug_output ("s","Menu: sending ordinary show_event\n",menu_int->hdr.show_event);
         toolbox_event.hdr.event_code = Menu_AboutToBeShown;
      }
      /* Show warning flag */

      regs.r[0]                    =  0;                     /* flags*/
      regs.r[1]                    =  r->r[1];               /* Object id */
      regs.r[2]                    =  -1;                    /* Component id */
      regs.r[3]                    =  (int) &toolbox_event;

      toolbox_event.hdr.size       =  sizeof(Menu_AboutToBeShown_Event);
      toolbox_event.hdr.flags      =  /*user_regs->r[0]*/0;

      menu_atbs            = (Menu_AboutToBeShown_Event *) &toolbox_event;
      menu_atbs->show_type = user_regs->r[2];
      menu_atbs->x         = global_menu.x;
      menu_atbs->y         = global_menu.y;

      if ((e = _kernel_swi (Toolbox_RaiseToolboxEvent, &regs, &regs)) != NULL)
         return e;
   }
   return NULL;
}

_kernel_oserror *show_menu_coords (_kernel_swi_regs *user_regs,DisplayInfo *menu_coords) {

   _kernel_oserror  *e;
   _kernel_swi_regs  regs;
   DisplayInfo      *coords      = (DisplayInfo *) user_regs->r[3];
   wimp_PointerInfo  ptr_info;

   switch (user_regs->r[2]) {

      case 1:
      case 2:
         menu_coords->x = coords->x;
         menu_coords->y = coords->y;
         break;
      default:
         regs.r[1] = (int) &ptr_info;

         if ((e = _kernel_swi (Wimp_GetPointerInfo, &regs, &regs)) != NULL) return e;

         menu_coords->x = ptr_info.x - 64;
         menu_coords->y = ptr_info.y;
         break;
   }
   DEBUG debug_output ("s","Menu: show coordinates are (%d,%d)\n",menu_coords->x,menu_coords->y);
   return NULL;
}
