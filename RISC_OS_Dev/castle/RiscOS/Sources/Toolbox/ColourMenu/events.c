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
 * History: 26-Jan-94: TGR: created
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
#include "string32.h"
#include "messages.h"
#include "objects/toolbox.h"
#include "objects/colourmenu.h"


#include "object.h"
#include "auxiliary.h"
#include "events.h"

_kernel_oserror *event_help_request (wimp_Message message_block, TaskDescriptor *t);
_kernel_oserror *event_menu_warning (wimp_Message message_block, TaskDescriptor *t);
_kernel_oserror *event_menus_deleted (wimp_Message message_block, TaskDescriptor *t);
_kernel_oserror *event_menu_selection (int *menu_tree, TaskDescriptor *t, IDBlock *id_block,_kernel_swi_regs *r);
_kernel_oserror *event_menu_to_show (TaskDescriptor *t, IDBlock *id_block,_kernel_swi_regs *r);
_kernel_oserror *menu_show_actual (void);
_kernel_oserror *menu_show_submenu_actual (void);

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


   _kernel_oserror *e;
   wimp_PollBlock  *block      = (wimp_PollBlock *)r->r[1];
   IDBlock         *id_block   = (IDBlock *)r->r[3];
   int              event_code = r->r[0];
   TaskDescriptor  *t          = (TaskDescriptor *) r->r[2];

   DEBUG debug_output ("e","ColourMenu: Postfilter entered, received wimp event code = 0x%x\n",event_code);


   r->r[0] = 0;

   if (t == NULL)
      return NULL;

   switch (event_code) {
      case wimp_ESEND:
      case wimp_ESEND_WANT_ACK:
         switch (block->msg.hdr.action) {
            case wimp_MMENUS_DELETED:
               return event_menus_deleted(block->msg,t);
               break;
            case wimp_MHELP_REQUEST:
               return event_help_request(block->msg,t);
               break;
            case wimp_MPALETTE_CHANGE:
               if ((e = palette_update()) != NULL) {
                  return e;
               }
               break;
            default:
               break;
         }
         break;
      case wimp_EMENU:
         return event_menu_selection((int *) r->r[1],t,id_block,r);
                                       /* ... R1 points to a list of menu selections */
         break;
      case wimp_ETOOLBOX_EVENT:
         DEBUG debug_output ("e","ColourMenu: toolbox event\n");
         if (block->toolbox_event.hdr.event_code == ColourMenu_AboutToBeShown) {
            DEBUG debug_output ("e","ColourMenu: AboutToBeShown event returned\n");
            return event_menu_to_show (t,id_block,r);
         }
         break;
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

   DEBUG debug_output ("e","ColourMenu: prefilter entered\n");

   if (global_menu.flags & GLOBAL_MENU_INFO_FLAGS_SHOW_NEXT) {

      global_menu.flags = (global_menu.flags
                        |   GLOBAL_MENU_INFO_FLAGS_IS_SHOWING)
                        &  ~GLOBAL_MENU_INFO_FLAGS_SHOW_NEXT;

      return ((global_menu.flags & GLOBAL_MENU_INFO_FLAGS_TOP_LEVEL)?menu_show_actual():menu_show_submenu_actual());
   }
   IGNORE(r);

   return NULL;
}



/* Respond to request for help ******************************************************************/

_kernel_oserror *event_help_request (wimp_Message message_block, TaskDescriptor *t) {

   _kernel_swi_regs  regs;
   _kernel_oserror  *e;
   ColourMenuInternal *menu_int = global_menu.current;
   wimp_Message       help_reply;
   ObjectID          object_id = menu_int->object_id;
   int               buffer[64];

   if (!menu_int) return NULL;

   object_id = menu_int->object_id;

   DEBUG debug_output ("e","ColourMenu: request for help\n");

   regs.r[0] = 0;
   regs.r[1] = (int) buffer;

   if ((e = _kernel_swi (Wimp_GetMenuState, &regs, &regs)) != NULL) {
      return e;
   }

   if (!menu_showing(buffer)) return NULL;

   if (global_menu.t == t) {

      int str_len;

      help_reply.hdr.your_ref = message_block.hdr.my_ref;
      help_reply.hdr.action   = wimp_MHELP_REPLY;
      help_reply.hdr.size = sizeof(wimp_Message);
      string_copy_chk (help_reply.data.chars, global_help_message, wimp_MAX_MSG_DATA_SIZE);

      str_len = strlen(global_help_message);

      if (str_len < wimp_MAX_MSG_DATA_SIZE) {
         global_help_message[str_len+1] = '\0';
         if (str_len+1 < wimp_MAX_MSG_DATA_SIZE)
            global_help_message[str_len+2] = '\0';
      }
   }
   regs.r[0] = wimp_ESEND;
   regs.r[1] = (int) &help_reply;
   regs.r[2] = message_block.hdr.task_handle;

   if ((e = _kernel_swi (Wimp_SendMessage, &regs, &regs)) != NULL) {
      return e;
   }
   return NULL;
}


/* Menu will be deleted. Mark it as not showing *************************************************/

_kernel_oserror *event_menus_deleted (wimp_Message message_block, TaskDescriptor *t){

   ColourMenuInternal *menu_int     = global_menu.current;
   ObjectID          object_id;

   if (!menu_int) return NULL;

   if (global_menu.wimp_menu != (wimp_Menu *) (*message_block.data.words))
      return NULL;

   object_id = menu_int->object_id;

   DEBUG debug_output ("e","ColourMenu: menus deleted, tidying up\n");

   IGNORE(t);
   IGNORE(message_block);

   return has_been_hidden ();
}


/* Respond to a menu selection ******************************************************************/

_kernel_oserror *event_menu_selection (int *menu_tree, TaskDescriptor *t, IDBlock *id_block,_kernel_swi_regs *r) {

   _kernel_swi_regs     regs;
   _kernel_oserror     *e;
   ColourMenuInternal  *menu_int       = global_menu.current;
   ObjectID             object_id;
   ToolboxEvent         toolbox_event;
   ColourMenu_Selection_Event
                       *selection;
   int                 *pposition      = global_menu_state;
   wimp_PointerInfo     pointer_info;

   DEBUG debug_output ("e","ColourMenu: selection entered\n");

   if (!menu_int || (*menu_tree == -1)) {
      return NULL;
   }
   if (!(menu_showing(menu_tree))) {
      DEBUG debug_output ("e","ColourMenu: menu not found, returning\n");
      return NULL;
   }
   object_id = global_menu.current->object_id;

   while (*pposition != -1) {
      if (*pposition++ != *menu_tree++) {
         return NULL;
      }
   }
   if (*menu_tree == -1) return NULL;

   set_colour (global_menu.current, *menu_tree);

   DEBUG debug_output ("e","ColourMenu: set new colour\n");

   selection                                = (ColourMenu_Selection_Event *) &toolbox_event;
   toolbox_event.hdr.size                   = sizeof (ColourMenu_Selection_Event);
   toolbox_event.hdr.event_code             = ColourMenu_Selection;
   toolbox_event.hdr.flags                  = 0;
   selection->colour                        = *menu_tree;

   regs.r[0] =  0;
   regs.r[1] =  (int) object_id;
   regs.r[2] =  -1;
   regs.r[3] =  (int) selection;

   if ((e = _kernel_swi (Toolbox_RaiseToolboxEvent, &regs, &regs)) != NULL) {
      return e;
   }
   regs.r[1] = (int) &pointer_info;

   if ((e = _kernel_swi (Wimp_GetPointerInfo, &regs, &regs)) != NULL) {
      return e;
   }
   if (pointer_info.button_state & wimp_ADJUST_BUTTON) {

      DEBUG debug_output ("e","ColourMenu: adjust click\n");

      if ((e = update_tree()) != NULL)
         return e;

   } else if (pointer_info.button_state & (wimp_SELECT_BUTTON|wimp_MENU_BUTTON)) {
      has_been_hidden ();
   }
   r->r[0] = 1;
   id_block->self_id        = object_id;

   IGNORE(r);
   IGNORE(t);

   return NULL;
}


_kernel_oserror *event_menu_to_show (TaskDescriptor *t, IDBlock *id_block,_kernel_swi_regs *r) {

   if (global_menu.t == t) { /* No further checking - assume this is it */
      global_menu.flags |= GLOBAL_MENU_INFO_FLAGS_SHOW_NEXT;
/*
      id_block->self_id = global_menu.current->object_id;
*/
   }

   IGNORE (r);
   IGNORE (id_block);

   return NULL;
}


