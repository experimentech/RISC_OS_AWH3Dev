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
/* Title:   task.c
 * Purpose: task handling for the Menu module
 * Author:  TGR
 * History: 16-Nov-93: TGR: created from IDJ template
 *
 */


#include <stdio.h>
#include <stdlib.h>
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

/*
 * This module has a linked list of client tasks.
 * task_add gets called when a Service_ToolboxTaskBorn
 * service call goes round.
 * The task is removed when the Service_WimpCloseDown is
 * received.
 * Each task keeps an Object list
 */


static TaskDescriptor *task__list = NULL;


extern BOOL task_any_active(void)
{
    return task__list != NULL;
}

extern TaskDescriptor *task_find (int task_handle)
{

   /*
    * Function to return a TaskDescriptor corresponding to
    * a task with a given Wimp handle
    */

   TaskDescriptor *t;

   DEBUG debug_output ("t","Menu: looking for task 0x%x\n",task_handle);

   t = task__list;

   while (t != NULL)
   {
      if (t->task_handle == task_handle)
         break;

      t = t->next;
   }

   return t;
}


extern void task_remove (int task_handle)
{
   /*
   * Function to remove a task descriptor from the list, given its
   * Wimp task handle.  Memory is freed, and we also delete any objects
   * owned by the exiting task.
   */

   TaskDescriptor *t = task__list;
   TaskDescriptor *prev_t = NULL, *next = NULL;
   MenuInternal   *i,*j;
   int             c;

   DEBUG debug_output ("t","Menu: looking to delete task 0x%x\n",task_handle);

   while (t != NULL)
   {
      next = t->next;

      if (t->task_handle == task_handle)
      {
         /*
          * remove this task's object's list
          */

         if (t->object_list != NULL) {

            i = t->object_list;

            /* If something horrible goes wrong whilst we're clearing up,
               then we'll just re-enter here and send ourselves into an
               infinite loop, so remove the task from the list before hand. */

            if (t == task__list)
               task__list = next;
            else
               prev_t->next = next;

            mem_freek (t);

            do {
               j = i->hdr.forward;

               if (global_menu.top == i) {
                  global_menu.top      = NULL;
                  global_menu.current  = NULL;
                  global_menu.flags   &= ~GLOBAL_MENU_INFO_FLAGS_IS_SHOWING
                                      &  ~GLOBAL_MENU_INFO_FLAGS_SHOW_NEXT;
                  global_menu.t        = NULL;
               }
               if ((i->hdr.wimp_menu)->hdr.title.indirect_text.buffer)
                  mem_freek ((i->hdr.wimp_menu)->hdr.title.indirect_text.buffer);

                 /* may not be any help */

               if (i->hdr.help_message) mem_freek (i->hdr.help_message);

               for (c=0;c<i->hdr.num_entries;c++) {
                  remove_menu_entry (wimp_menu_entry(i->hdr.wimp_menu,c),menu_internal_entry(i,c));
               }

               if (i->hdr.entries) mem_freek (i->hdr.entries);

               mem_freek (i->hdr.wimp_menu);
               mem_freek (i);

            } while ((i=j) != t->object_list);
         }

         /*
          * remove the task descriptor itself
          */

         else {
            if (t == task__list)
               task__list = next;
            else
               prev_t->next = next;

            mem_freek (t);
         }
         return;
      }
      prev_t = t;
      t = next;
   }
}


extern void task_add (int task_handle)
{
   /*
    * Function to add a task descriptor to the list of active
    * Toolbox tasks.
    */

   /*
    * extra safety check, we make sure that the task is not already there!
    */

   TaskDescriptor *new_t;

   DEBUG debug_output ("t","Menu: adding task\n");


   if (task_find (task_handle) != NULL)
      return;


   /*
    * add task to list
    */

   if ((new_t = mem_alloc (sizeof(TaskDescriptor))) == NULL)
   {
      raise_toolbox_error(Menu_AllocFailed,0,0,-1);
      return;
   }

   new_t->task_handle = task_handle;
   new_t->next = task__list;
   new_t->object_list = NULL;
   task__list = new_t;

   DEBUG debug_output ("t","Menu: added task's handle = 0x%x\n",task_handle);
}
