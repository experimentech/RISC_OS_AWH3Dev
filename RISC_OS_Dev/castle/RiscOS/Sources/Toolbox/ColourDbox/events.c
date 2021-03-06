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
 * History: 8-Mar-94: TGR: created from IDJ template
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"


#include "const.h"
#include "macros.h"
#include "debug.h"
#include "mem.h"
#include "messages.h"
#include "string32.h"

#include "objects/toolbox.h"
#include "objects/colourdbox.h"

#include "auxiliary.h"
#include "object.h"
#include "events.h"

_kernel_oserror *event_help_request (wimp_Message message_block, TaskDescriptor *t, IDBlock *id_block, _kernel_swi_regs *r);
_kernel_oserror *event_colourdbox_to_show    (ObjectID object_id);
_kernel_oserror *event_menus_deleted         (TaskDescriptor *t);
_kernel_oserror *event_picker_choice         (TaskDescriptor *t, wimp_PollBlock *block);
_kernel_oserror *event_colour_changed        (TaskDescriptor *t, wimp_PollBlock *block);

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

   wimp_PollBlock   *block           = (wimp_PollBlock *)r->r[1];
   IDBlock          *id_block        = (IDBlock *)r->r[3];
   int               event_code      = r->r[0];
   TaskDescriptor   *t               = (TaskDescriptor *) r->r[2];

   DEBUG debug_output ("e","ColD: Postfilter entered, received wimp event code = 0x%x\n",event_code);
   r->r[0] = 0;

   switch (event_code) {

      case wimp_EREDRAW:
      /*case wimp_EKEY:*/
         r->r[0] = find_internal_w (*((int *)block),t) ? -1 : 0;
         return NULL;
      case wimp_ESEND:
      case wimp_ESEND_WANT_ACK:
         DEBUG debug_output ("e","ColD: message received, action = 0x%x\n",block->msg.hdr.action);
         switch (block->msg.hdr.action) {
            case wimp_MMENUS_DELETED:
               return event_menus_deleted (t);
               break;
            case colourpicker_MCOLOURCHANGED:
               return event_colour_changed (t, block);
            case colourpicker_MPICKERCHOICE:
               return event_picker_choice  (t, block);
               break;
            case colourpicker_MCLOSEDIALOGUEREQUEST:
               {
                  ColourDboxInternal *internal;
                  _kernel_oserror     *e;

                  DEBUG debug_output ("e","ColD: CloseDialogueRequest\n");
                  if ((internal = find_internal_d (((ColourPicker_CloseDialogueRequest_Event *)(block))->message.dialogue_handle, t)) == NULL) {
                     DEBUG debug_output ("e","ColD: Not our colour picker, dh = 0x%x\n", ((ColourPicker_CloseDialogueRequest_Event *)(block))->message.dialogue_handle);
                     return NULL;
                  }
                  DEBUG debug_output ("e","ColD: ... object ID = 0x%x\n",internal->object_id);
/*
                  if ((e = fetch_state (internal)) != NULL)
                     return e;
*/
                  if ((e = close_dialogue (internal, t)) != NULL)
                     return e;

/*
                  if (!(--t->window_count) && ((e = deregister_task(t)) != NULL))
                     return e;
*/
                  id_block->self_id = internal->object_id;
                  r->r[0]           = 1;

                  return NULL;
               }
               break;
/* No longer handled (bug in ColourPicker module)
            case wimp_MHELP_REQUEST:
               return event_help_request(block->msg,t,id_block,r);
               break;
*/
            default:
               break;
         }
         break;
      case wimp_ETOOLBOX_EVENT:
         DEBUG debug_output ("e","ColD: handling a toolbox event, code = 0x%x\n",block->toolbox_event.hdr.event_code);
         switch (block->toolbox_event.hdr.event_code) {
            case ColourDbox_AboutToBeShown:
                  return event_colourdbox_to_show (id_block->self_id);
               break;
            default:
               break;
         }
      default:
         break;
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

    DEBUG debug_output ("e","ColD: prefilter entered\n");

    if (global_next) return show_actual();

    IGNORE (r);

    return NULL;
}

/*
_kernel_oserror *event_help_request (wimp_Message message_block, TaskDescriptor *t, IDBlock *id_block, _kernel_swi_regs *r) {

   _kernel_oserror    *e;
   _kernel_swi_regs    regs;
   ColourDboxInternal *internal;
   wimp_Message        help_reply;
   int                 str_len;

   DEBUG debug_output ("e","Menu: request for help\n");

   IGNORE(t);

   if ((internal = find_internal_w (message_block.data.help_request.window_handle, t)) == NULL)
      return NULL;

   if (!internal->help_message) return NULL;

   help_reply.hdr.your_ref = message_block.hdr.my_ref;
   help_reply.hdr.action   = wimp_MHELP_REPLY;
   help_reply.hdr.size     = sizeof(wimp_Message);

   string_copy_chk (help_reply.data.chars, internal->help_message, wimp_MAX_MSG_DATA_SIZE);

   str_len = strlen(help_reply.data.chars);

   if (str_len < wimp_MAX_MSG_DATA_SIZE) {
      help_reply.data.chars[str_len+1] = '\0';
      if (str_len+1 < wimp_MAX_MSG_DATA_SIZE)
         help_reply.data.chars[str_len+2] = '\0';
   }
   regs.r[0] = wimp_ESEND;
   regs.r[1] = (int) &help_reply;
   regs.r[2] = message_block.hdr.task_handle;

   if ((e = _kernel_swi (Wimp_SendMessage, &regs, &regs)) != NULL) {
      return e;
   }

   r->r[0]           = 1;
   id_block->self_id = internal->object_id;

   return NULL;
}
*/

_kernel_oserror *event_colourdbox_to_show      (ObjectID object_id) {

   _kernel_oserror    *e;
   _kernel_swi_regs    regs;

   DEBUG debug_output ("e","ColD: colourdbox_to_show entered\n");

   regs.r[0] = 0;
   regs.r[1] = (int) object_id;

   if ((e = _kernel_swi (Toolbox_GetInternalHandle, &regs, &regs)) != NULL)
      return e;

   global_next = (ColourDboxInternal *) regs.r[0];

   return NULL;
}

_kernel_oserror *event_menus_deleted         (TaskDescriptor *t) {

   _kernel_oserror    *e;
   _kernel_swi_regs    regs;
   ColourDboxInternal *internal;

   DEBUG debug_output ("e","ColourDbox: menus deleted, handling...\n");

   if (!global_menu)
      return NULL;

   DEBUG debug_output ("e","ColourDbox: we've got a live one!\n");

   regs.r[0] = 0;
   regs.r[1] = (int) global_menu;

   if ((e = _kernel_swi (Toolbox_GetInternalHandle, &regs, &regs)) != NULL)
      return e;

   internal = (ColourDboxInternal *) regs.r[0];

   internal->flags &= ~ColourDboxInternal_IsShowing;

   if (internal->flags & ColourDboxInternal_GenerateHideEvent) {
      if ((e = dialogue_completed (global_menu)) != NULL)
         return e;
   }
   global_menu = 0;

   /* deregister interest in events etc.

   regs.r[0] = 1;
   regs.r[1] = ColourDbox_PostFilter;
   regs.r[2] = (int) t;
   regs.r[3] = Toolbox_RegisterPostFilter_WimpMessage;
   regs.r[4] = (int) menu_messages_of_interest;

   if ((e = _kernel_swi (Toolbox_RegisterPostFilter, &regs, &regs)) != NULL)
      return e;
*/
/*
   if (!(--t->window_count) && ((e = deregister_task(t)) != NULL))
      return e;
*/
   IGNORE(t);


   return NULL;
}

_kernel_oserror *event_picker_choice         (TaskDescriptor *t, wimp_PollBlock *block) {

   _kernel_oserror                    *e;
   _kernel_swi_regs                    regs;
   ColourDboxInternal                 *internal;
   ToolboxEvent                        toolbox_event;
   ColourDbox_ColourSelected_Event    *colour_selected
                                             = (ColourDbox_ColourSelected_Event *) &toolbox_event;
   ColourPicker_PickerChoice_Event    *picker_choice  = (ColourPicker_PickerChoice_Event *) block;

   /* raise the toolbox event  ColourDbox_ColourSelected _if_ the client has asked to be
        informed of this */

   if ((internal = find_internal_d (picker_choice->message.dialogue_handle, t)) == NULL) {
      DEBUG debug_output ("e","ColD: Not our colour picker, dh = 0x%x, 0x%x\n", ((ColourPicker_CloseDialogueRequest_Event *)(block))->message.dialogue_handle, ((int *)block)[5]);
      return NULL;
   }
   toolbox_event.hdr.size       = sizeof(ColourDbox_ColourSelected_Event);
   toolbox_event.hdr.event_code = ColourDbox_ColourSelected;
   toolbox_event.hdr.flags      = 0;

   memcpy (&colour_selected->hdr.flags, &picker_choice->message.flags, picker_choice->message.colour_descriptor_block.hdr.extension_size + sizeof (ColourDescriptorHeader) + sizeof(int));

   regs.r[0] = 0;
   regs.r[1] = (int) internal->object_id;
   regs.r[2] = -1;
   regs.r[3] = (int) &toolbox_event;

   if ((e = _kernel_swi (Toolbox_RaiseToolboxEvent, &regs, &regs)) != NULL) {
      return e;
   }
   if (internal->colour_model_block) mem_freek (internal->colour_model_block);
   if (internal->colour_block_extd)  mem_freek (internal->colour_block_extd);
   internal->colour_model_block  = NULL;

   if ((internal->colour_block_extd = mem_alloc (256)) == NULL)
      return make_error (ColourDbox_AllocFailed, 0);

   memcpy (internal->colour_block_extd, &picker_choice->message.colour_descriptor_block, picker_choice->message.colour_descriptor_block.hdr.extension_size + sizeof(int) - sizeof (ColourPickerHeader));
   return NULL;
}
_kernel_oserror *event_colour_changed         (TaskDescriptor *t, wimp_PollBlock *block) {

   ColourDboxInternal                 *internal;
   ColourPicker_ColourChanged_Event   *colour_changed = (ColourPicker_ColourChanged_Event *) block;

   DEBUG debug_output ("e","ColD: event colour changed\n");

   if ((internal = find_internal_d (colour_changed->message.dialogue_handle, t)) == NULL) {
      DEBUG debug_output ("e","ColD: Not our colour picker, dh = 0x%x, 0x%x\n", ((ColourPicker_CloseDialogueRequest_Event *)(block))->message.dialogue_handle, ((int *)block)[5]);
      return NULL;
   }
   if (internal->colour_model_block) mem_freek (internal->colour_model_block);
   if (internal->colour_block_extd)  mem_freek (internal->colour_block_extd);
   internal->colour_model_block  = NULL;
   internal->colour_block_extd   = NULL;

   if ((internal->colour_block_extd = mem_alloc (256)) == NULL)
      return make_error (ColourDbox_AllocFailed, 0);

   DEBUG debug_dump (&colour_changed->message.colour_descriptor_block, colour_changed->message.colour_descriptor_block.hdr.extension_size + sizeof(int) - sizeof (ColourPickerHeader));

   memcpy (internal->colour_block_extd, &colour_changed->message.colour_descriptor_block, colour_changed->message.colour_descriptor_block.hdr.extension_size + sizeof(int) - sizeof (ColourPickerHeader));
   return NULL;
}
