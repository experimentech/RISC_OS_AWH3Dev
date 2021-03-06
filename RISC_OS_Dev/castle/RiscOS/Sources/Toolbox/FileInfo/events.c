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
/* Title:   events.c
 * Purpose: filters registered with the Toolbox.  Events are delivered here.
 * Author:  TGR
 * History: 7-Feb-94: TGR: created from IDJ template
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
#include "twimp.h"

#include "objects/toolbox.h"
#include "objects/fileinfo.h"

#include "auxiliary.h"
#include "object.h"
#include "events.h"


_kernel_oserror *event_close_window (TaskDescriptor *t, IDBlock *id_block);
_kernel_oserror *event_fileinfo_to_show (ObjectID object_id);
/*
_kernel_oserror *event_menus_deleted (void);
*/

extern _kernel_oserror *events_postfilter (_kernel_swi_regs *r)
{

    /*
     * called from the main Toolbox postfilter, when an event happens which
     * this module has expressed an interest in.
     * R0 = Wimp event reason code
     * R1 ->client's Wimp event block
     * R2 = Task Descriptor of task interested in the event
     * R3 ->6-word "ID block" as passed to Toolbox_Initialise
     *
     */

    /*
     * This function gets a pointer to the task interested in the event in
     * R2 (since this was the value passed to Toolbox_RegisterPostFilter).
     * If the event is dealt with by this module (eg ID block gets updated).
     * then set R0 to non-null before return.
     */

   _kernel_oserror  *e;
   _kernel_swi_regs  regs;
   wimp_PollBlock   *block           = (wimp_PollBlock *)r->r[1];
   IDBlock          *id_block        = (IDBlock *)r->r[3];
   int               event_code      = r->r[0];
   FileInfoInternal *internal;
   TaskDescriptor   *t               = (TaskDescriptor *) r->r[2];

   DEBUG debug_output ("e","FileInfo: Postfilter entered, received wimp event code = 0x%x\n",event_code);

   r->r[0] = 0;

   if (event_code == wimp_ETOOLBOX_EVENT) {

      DEBUG debug_output ("e","FileInfo: handling a toolbox event, code = 0x%x\n",block->toolbox_event.hdr.event_code);
      switch (block->toolbox_event.hdr.event_code) {
         case FileInfo_AboutToBeShown:
            regs.r[0] = 0;
            regs.r[1] = (int) id_block->self_id;

            if ((e = _kernel_swi (Toolbox_GetInternalHandle, &regs, &regs)) != NULL)
               return e;

            global_next = (FileInfoInternal *) regs.r[0];

            break;
         case Window_HasBeenHidden:
         {
            _kernel_swi_regs    regs;
            ToolboxEvent        toolbox_event;

            if ((internal = find_internal (t, id_block->self_id)) == NULL)
               return NULL;

            internal->flags &= ~FileInfoInternal_IsShowing;

            if (~internal->flags & FileInfoInternal_GenerateHideEvent) return NULL;

            regs.r[0] = 0;
            regs.r[1] = (int) internal->object_id;
            regs.r[2] = -1;
            regs.r[3] = (int) &toolbox_event;

            toolbox_event.hdr.size       = sizeof (FileInfo_DialogueCompleted_Event);
            toolbox_event.hdr.event_code = FileInfo_DialogueCompleted;
            toolbox_event.hdr.flags      = 0;

            return _kernel_swi (Toolbox_RaiseToolboxEvent, &regs, &regs);
         }
      }
   }
   return NULL;
}


extern _kernel_oserror *events_prefilter (_kernel_swi_regs *r)
{

    /*
     * called from the main Toolbox prefilter, when Wimp_Poll is called.
     * R0 = mask passed to Wimp_Poll
     * R1 ->client's poll block passed to Wimp_Poll
     * R2 = Task Descriptor.
     *
     */

    /*
     * This function gets a pointer to the current task in
     * R2 (since this was the value passed to Toolbox_RegisterPreFilter).
     * This function can enable additional events by zero-ing bits in
     * r->r[0]
     */

    IGNORE (r);

    return (global_next) ? show_actual() : NULL;
}

/*
_kernel_oserror *event_menus_deleted (void) {

   _kernel_oserror    *e;
   _kernel_swi_regs    regs;
   FileInfoInternal   *internal;

   if (global_menu) {

      regs.r[0] = 0;
      regs.r[1] = (int) global_menu;

      global_menu = 0;

      if ((e = _kernel_swi (Toolbox_GetInternalHandle, &regs, &regs)) != NULL)
         return e;

      internal = (FileInfoInternal *) regs.r[0];

      internal->flags &= ~FileInfoInternal_IsShowing;

      if (internal->flags & FileInfoInternal_GenerateHideEvent) {
         return dialogue_completed (global_menu);
      }
   }
   return NULL;
}
*/
