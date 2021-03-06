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
/* Title:   create.c
 * Purpose: create a ColourDbox Object
 * Author:  TGR
 * History: 7-Mar-94: TGR: created
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include "kernel.h"
#include "swis.h"
#include "string.h"

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
#include "task.h"

#include "create.h"


extern _kernel_oserror *create_object (_kernel_swi_regs *r, TaskDescriptor *t)
{

    /*
     * request to create an object
     * R0 = 0
     * R1 = Object ID
     * R2 = 0  (will be internal handle for other SWIs
     * R3 = wimp task handle of caller (use to identify task descriptor)
     * R4 -> user regs R0-R9
     *      R0 = flags
     *           bit 0 set => create from memory
     *      R1 -> description block
     */

    /*
     * The Toolbox has already checked that this is not just a create
     * call for a shared Object which already exists.
     * We create a new Object, and add it to the list of Objects for this
     * task.
     * We need to remember the ObjectID passed to us by the Toolbox, so
     * that we can identify this Object if we are given an ID from the
     * client's "id block".
     * Note that if any template names are held in the Object, then we
     * create an Object from that template, and store its ID.
     * Note also that the Toolbox has changed the client's R1 to point
     * at an in-core template, if it wasn't already!
     */

   _kernel_oserror      *e                = NULL;
   _kernel_swi_regs     *user_regs        = (_kernel_swi_regs *) r->r[4];
   ObjectTemplateHeader *obj_temp_hdr     = (ObjectTemplateHeader *)user_regs->r[1];
   ColourDboxTemplate   *template         = (ColourDboxTemplate *) obj_temp_hdr->body;
   ColourDboxInternal   *internal;
   int                   buffer_size      = 0;

   if ((internal = mem_alloc (sizeof (ColourDboxInternal))) == NULL)
      return make_error (ColourDbox_AllocFailed, 0);

   internal->object_id = (ObjectID) r->r[1];

   internal->flags
      = ((template->flags & ColourDbox_GenerateShowEvent)
         ? ColourDboxInternal_GenerateShowEvent : 0)
      | ((template->flags & ColourDbox_GenerateHideEvent)
         ? ColourDboxInternal_GenerateHideEvent : 0)
      | ((template->flags & ColourDbox_IncludeNoneButton)
         ? ColourDboxInternal_IncludeNoneButton : 0)
      | ((template->flags & ColourDbox_SelectNoneButton)
         ? ColourDboxInternal_SelectNoneButton : 0);
/*
      | ((template->flags & ColourDbox_ChangeInfoExceptDrag)
         ? ColourDboxInternal_ChangeInfoExceptDrag : 0)
      | ((template->flags&ColourDbox_AllChangeInfo)
         ? ColourDboxInternal_AllChangeInfo : 0);
*/
   internal->x = -1; /* Rogue value */

   if (!template->title) {
      /* Provide a default title */
      if ((e = messages_file_lookup ("Title", 0, &buffer_size, 0)) != NULL)
         goto clearup1;

      if ((internal->title = mem_alloc (buffer_size)) == NULL) {
         e = make_error(ColourDbox_AllocFailed,0);
         goto clearup1;
      }
      if ((e = messages_file_lookup ("Title", internal->title, &buffer_size, 0)) !=NULL)
         goto clearup1;
   } else {
      /* Caller provided their own title */
      if ((internal->title = mem_alloc (template->max_title)) == NULL) {
         e = make_error (ColourDbox_AllocFailed, 0);
         goto clearup1;
      }
      string_copy_chk (internal->title, template->title, template->max_title);
   }
   internal->max_title          = strlen(internal->title) + 1;
   if (template->max_title > internal->max_title) internal->max_title = template->max_title;
   internal->colour             = template->colour;

   DEBUG debug_output ("f","ColD: creating with RGB colour word = 0x%x, title = '%s'\n",internal->colour, internal->title);

   internal->colour_block_extd  = NULL;
   internal->colour_model_block = NULL;

   if (t->object_list) { /* If there are already colourdboxes attached to the task ... */

      internal->forward                        = t->object_list;
      internal->backward                       = t->object_list->backward;
      t->object_list->backward->forward        = internal;
      t->object_list->backward                 = internal;

   } else {              /* ... if not ... */

      e = register_task (t);

      t->object_list     = internal;
      internal->forward  = internal;
      internal->backward = internal;
   }

   r->r[0] = (int) internal;

   return e;

clearup1:
   mem_freek(internal);
   return e;
}
