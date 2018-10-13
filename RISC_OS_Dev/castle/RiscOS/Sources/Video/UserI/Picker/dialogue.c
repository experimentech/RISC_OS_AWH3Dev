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
/*dialogue.c - opening and closing of ColourPicker dialogues*/

/*From CLib*/
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <kernel.h>

/*From OSLib*/
#include "colourtrans.h"
#include "filter.h"
#include "help.h"
#include "macros.h"
#include "os.h"
#include "osspriteop.h"
#include "taskmanager.h"
#include "wimp.h"
#include "wimpreadsysinfo.h"

/*From Support*/
#include "lookup.h"
#include "m.h"
#include "relocate.h"
#include "riscos.h"
#include "task.h"
#include "trace.h"
#include "window.h"

/*Local*/
#include "colourpicker.h"
#include "dialogue.h"
#include "icon.h"
#include "main.h"
#include "model.h"
#include "veneer.h"

dialogue_task_list dialogue_active_tasks, *dialogue_last_task;

static dialogue_list Transient;

static resource_template *Picker;

static os_coord Size;

static os_coord Offset;

static osspriteop_header *Crosshatch;

static wimp_i Icons [] =
      {dialogue_PICKER_RGB, dialogue_PICKER_CMYK, dialogue_PICKER_HSV};

#if TRACE
#ifdef XTRACE
/*------------------------------------------------------------------------*/
static void Trace_Dialogues (char *s)

{  dialogue_task_list t;
   dialogue_list l;

   tracef ("Trace_Dialogues: %s\n" _ s);

   for (t = dialogue_active_tasks; t != NULL; t = t->next)
   {  tracef ("{  0x%X:\n" _ t);
      tracef ("   sentinel '%.4s'\n" _ &t->sentinel);
      tracef ("   task 0x%X\n" _ t->task);
      tracef ("   saved mask 0x%X\n" _ t->saved_mask);
      tracef ("   post_name %s\n" _ t->post_name);
      tracef ("   pre_name %s\n" _ t->pre_name);
      tracef ("   open_dialogues 0x%X\n" _ t->open_dialogues);
      tracef ("   last_dialogue 0x%X\n" _ t->last_dialogue);
      for (l = t->open_dialogues; l != NULL; l = l->next)
      {  tracef ("   {  0x%X:\n" _ l);
         tracef ("      sentinel '%.4s'\n" _ &l->sentinel);
         tracef ("      model 0x%X\n" _ l->model);
         tracef ("      colour 0x%X\n" _ l->colour);
         tracef ("      main_w 0x%X\n" _ l->main_w);
         tracef ("      parent 0x%X\n" _ l->parent);
         tracef ("   }\n");
      }
      tracef ("}\n");
   }
}
#endif
#else
   #define Trace_Dialogues(s) SKIP
#endif
/*------------------------------------------------------------------------*/
static os_error *None_Selected (wimp_w w, osbool *none_out)

{  wimp_icon_state state;
   osbool none;
   os_error *error = NULL;

   tracef ("None_Selected\n");

   /*Get the state of the None button.*/
   state.w = w;
   state.i = dialogue_PICKER_NONE;
   if ((error = xwimp_get_icon_state (&state)) != NULL)
      goto finish;

   none = (state.icon.flags & (wimp_ICON_SHADED | wimp_ICON_SELECTED)) ==
         wimp_ICON_SELECTED;

   if (none_out != NULL) *none_out = none;

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Update (dialogue_list l)

   /*Draw the contents of the given window.*/

{  os_error *error = NULL;
   relocate_frame frame;
   osbool none, more;
   wimp_draw update;
   osspriteop_TRANS_TAB (2) trans_tab;

   tracef ("Update\n");

   if ((error = None_Selected (l->main_w, &none)) != NULL)
      goto finish;

   if (none)
      if ((error = xcolourtrans_generate_table_for_sprite
            (osspriteop_UNSPECIFIED, (osspriteop_id) Crosshatch,
            colourtrans_CURRENT_MODE, colourtrans_CURRENT_PALETTE,
            (osspriteop_trans_tab *) &trans_tab,
            colourtrans_GIVEN_SPRITE, SKIP, SKIP, NULL)) != NULL)
         goto finish;

   update.w = l->main_w;
   update.box = Picker->window.icons [dialogue_PICKER_PATCH].extent;
   if ((error = xwimp_update_window (&update, &more)) != NULL)
      goto finish;

   while (more)
   {  if (!none)
      {  relocate_begin (l->model->workspace, &frame);
         error = (*(os_error *(*) (colourpicker_colour *))
               l->model->model->entries [colourpicker_ENTRY_SET_COLOUR])
               (l->colour);
         relocate_end (&frame);
         if (error != NULL) goto finish;

         if ((error = xos_plot (os_MOVE_TO | os_PLOT_SOLID,
               update.box.x0, update.box.y0)) != NULL)
            goto finish;

         if ((error = xos_plot (os_PLOT_TO | os_PLOT_RECTANGLE,
               update.box.x1, update.box.y1)) != NULL)
            goto finish;
      }
      else
         /*Plot a crosshatched sprite to represent "no colour selected.*/
         if ((error = xosspriteop_put_sprite_scaled
               (osspriteop_PTR, (osspriteop_area *) 0x100,
               (osspriteop_id) Crosshatch,
               update.box.x0, update.box.y0, os_ACTION_USE_MASK,
               NULL, (osspriteop_trans_tab *) &trans_tab)) != NULL)
            goto finish;

      if ((error = xwimp_get_rectangle (&update, &more)) != NULL)
         goto finish;
   }

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Colour_Choice (dialogue_list l)

   /*Send a Colour Choice message.*/

{  os_error *error = NULL;
   colourpicker_message_colour_choice *colour_choice = NULL;
   osbool none;

   tracef ("Colour_Choice\n");

   /*Get the state of the None button.*/
   if ((error = None_Selected (l->main_w, &none)) != NULL)
      goto finish;

   if ((colour_choice = m_ALLOC (colourpicker_SIZEOF_MESSAGE_COLOUR_CHOICE
         (l->colour->size/sizeof (int)))) == NULL)
   {  error = riscos_error_lookup (os_GLOBAL_NO_MEM, "NoMem");
      goto finish;
   }

   colour_choice->d      = (colourpicker_d) l;
   colour_choice->flags  = none? colourpicker_COLOUR_TRANSPARENT: NONE;
   colour_choice->colour = l->colour->colour;
   colour_choice->size   = l->colour->size;
   memcpy (colour_choice->info, l->colour->info, l->colour->size);

   if ((error = task_send_user_message (l->parent->task, 0,
         message_COLOUR_PICKER_COLOUR_CHOICE, colour_choice,
         colourpicker_SIZEOF_MESSAGE_COLOUR_CHOICE
         (l->colour->size/sizeof (int)))) != NULL)
      goto finish;

finish:
   m_FREE (colour_choice, colourpicker_SIZEOF_MESSAGE_COLOUR_CHOICE
         (l->colour->size/sizeof (int)));
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Close_Dialogue_Request (dialogue_list l)

   /*Send a close dialogue request message.*/

{  os_error *error = NULL;
   colourpicker_message_close_dialogue_request close;

   tracef ("Close_Dialogue_Request\n");

   close.d = (colourpicker_d) l;

   if ((error = task_send_user_message (l->parent->task, 0,
        message_COLOUR_PICKER_CLOSE_DIALOGUE_REQUEST, &close, sizeof close))
        != NULL)
      goto finish;

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Open_Parent_Request (dialogue_list l)

   /*Send an open parent request message.*/

{  os_error *error = NULL;
   colourpicker_message_open_parent_request open;

   tracef ("Open_Parent_Request\n");

   open.d = (colourpicker_d) l;

   if ((error = task_send_user_message (l->parent->task, 0,
        message_COLOUR_PICKER_OPEN_PARENT_REQUEST, &open, sizeof open)) !=
        NULL)
      goto finish;

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Reset_Colour_Request (dialogue_list l)

   /*Send a reset colour request message.*/

{  os_error *error = NULL;
   colourpicker_message_reset_colour_request reset;

   tracef ("Reset_Colour_Request\n");

   reset.d = (colourpicker_d) l;

   if ((error = task_send_user_message (l->parent->task, 0,
        message_COLOUR_PICKER_RESET_COLOUR_REQUEST, &reset, sizeof reset)) !=
        NULL)
      goto finish;

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Choice (void *h, void *b, osbool *unclaimed)

   /*Called back when click SELECT or ADJUST on OK. N B: |block| may be NULL
      because this may be called for key presses on the model pane.*/

{  dialogue_list l = (dialogue_list) h;
   os_error *error = NULL;

   NOT_USED (b)
   NOT_USED (unclaimed)

   tracef ("Choice\n");

   /*Send a colour choice message.*/
   if ((error = Colour_Choice (l)) != NULL)
      goto finish;

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Reset (void *h, void *b, osbool *unclaimed)

   /*Called back when click ADJUST on Cancel.*/

{  dialogue_list l = (dialogue_list) h;
   os_error *error = NULL;

   NOT_USED (b)
   NOT_USED (unclaimed)

   tracef ("Reset\n");

   if ((error = Reset_Colour_Request (l)) != NULL)
      goto finish;

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Close (void *h, void *b, osbool *unclaimed)

   /*Click SELECT on OK or Cancel. N B: |block| may be NULL
      because this may be called for key presses on the model pane.*/

{  dialogue_list l = (dialogue_list) h;
   os_error *error = NULL;

   NOT_USED (b)

   tracef ("Close\n");

   if ((error = Close_Dialogue_Request (l)) != NULL)
      goto finish;

   *unclaimed = FALSE;
      /*the dialogue is gone*/

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Parent (void *h, void *b, osbool *unclaimed)

   /*Click ADJUST on Close.*/

{  dialogue_list l = (dialogue_list) h;
   os_error *error = NULL;

   NOT_USED (b)
   NOT_USED (unclaimed)

   tracef ("Close\n");

   if ((error = Open_Parent_Request (l)) != NULL)
      goto finish;

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Dismiss (void *h, void *b, osbool *unclaimed)

   /*Click SELECT on OK or Cancel when the dialogue is transient.
      N B: |block| may be NULL because this may be called for key presses on
      the model pane.*/

{  dialogue_list l = (dialogue_list) h;
   os_error *error = NULL;

   NOT_USED (b)

   tracef ("Dismiss\n");

   tracef ("closing menu ...\n");
   if ((error = xwimp_create_menu (wimp_CLOSE_MENU, SKIP, SKIP)) != NULL)
      goto finish;
   tracef ("closing menu ... done\n");

   tracef ("closing transient dialogue ...\n");
   if ((error = dialogue_close (NONE, (colourpicker_d) l)) != NULL)
      goto finish;
   tracef ("closing transient dialogue ... done\n");

   *unclaimed = FALSE;
      /*the dialogue is gone*/

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Colour_Changed (dialogue_list l, osbool none, osbool dragging)

   /*Sends the message appropriate when |l| enters state |none|.*/

{  osbool suppress;
   os_error *error = NULL;
   colourpicker_message_colour_changed *colour_changed = NULL;

   tracef ("Colour_Changed, flags are 0x%X\n" _ l->flags);
   switch ((l->flags & colourpicker_DIALOGUE_TYPE) >>
         colourpicker_DIALOGUE_TYPE_SHIFT)
   {  case colourpicker_DIALOGUE_TYPE_NEVER:
         tracef ("suppressed because task never wants changed\n");
         suppress = TRUE;
      break;

      case colourpicker_DIALOGUE_TYPE_CLICK:
         tracef (dragging? "suppressed because dragging\n":
               "not suppressed, not dragging\n");
         suppress = dragging;
      break;

      case colourpicker_DIALOGUE_TYPE_CLICK_DRAG:
         tracef ("not suppressed\n");
         suppress = FALSE;
      break;

      default:
         tracef ("FAULT\n");
         return NULL;
      break;
   }

   if (!suppress)
   {  tracef ("Sending message_COLOUR_PICKER_COLOUR_CHANGED to task\n");
      if ((colour_changed = m_ALLOC
            (colourpicker_SIZEOF_MESSAGE_COLOUR_CHANGED
            (l->colour->size/sizeof (int)))) == NULL)
      {  error = riscos_error_lookup (os_GLOBAL_NO_MEM, "NoMem");
         goto finish;
      }

      colour_changed->d      = (colourpicker_d) l;
      colour_changed->flags  =
            (none? colourpicker_COLOUR_TRANSPARENT: NONE) |
            (dragging? colourpicker_COLOUR_DRAGGING: NONE);
      colour_changed->colour = l->colour->colour;
      colour_changed->size   = l->colour->size;
      memcpy (colour_changed->info, l->colour->info, l->colour->size);

      if ((error = task_send_user_message (l->parent->task, 0,
            message_COLOUR_PICKER_COLOUR_CHANGED, colour_changed,
            colourpicker_SIZEOF_MESSAGE_COLOUR_CHANGED
            (l->colour->size/sizeof (int)))) != NULL)
         goto finish;
   }
   else
      tracef ("Suppressed message_COLOUR_PICKER_COLOUR_CHANGED - task "
            "doesn't want it\n");

   /*Update the colour patch.*/
   if ((error = Update (l)) != NULL)
      goto finish;

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   m_FREE (colour_changed, colourpicker_SIZEOF_MESSAGE_COLOUR_CHANGED
            (l->colour->size/sizeof (int)));
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *None (void *h, void *b, osbool *unclaimed)

{  dialogue_list l = (dialogue_list) h;
   wimp_block *block = (wimp_block *) b;
   os_error *error = NULL;
   osbool none;

   NOT_USED (unclaimed)

   tracef ("None\n");

   /*Are we in a "None" state?*/
   if ((error = None_Selected (block ASREF pointer.w, &none)) != NULL)
      goto finish;

   if ((error = Colour_Changed (l, none, /*dragging?*/ FALSE)) != NULL)
      goto finish;

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Redraw (void *h, void *b, osbool *unclaimed)

{  dialogue_list l = (dialogue_list) h;
   wimp_draw *redraw = &((wimp_block *) b) ASREF redraw;
   os_error *error = NULL;
   osbool more;
   relocate_frame frame;

   NOT_USED (unclaimed)

   tracef ("Redraw\n");

   /*Do the WIMP redraws.*/
   if ((error = xwimp_redraw_window (redraw, &more)) != NULL)
      goto finish;

   while (more)
   {  /* We don't do anything on the redraw: the only thing have to be
         redrawn is the colour patch, and we do that by Update, since then
         we get the right clipping rectangle.*/

      if (l->model->model->entries [colourpicker_ENTRY_REDRAW_AREA] != NULL)
      {  /*Allow the model a lookin here.*/
         relocate_begin (l->model->workspace, &frame);
         error = (*(os_error *(*) (colourpicker_colour *, wimp_draw *))
               l->model->model->entries [colourpicker_ENTRY_REDRAW_AREA])
               (l->colour, redraw);
         relocate_end (&frame);
         if (error != NULL) goto finish;
      }

      if ((error = xwimp_get_rectangle (redraw, &more)) != NULL)
         goto finish;
   }

   /*Redraw the colour patch.*/
   if ((error = Update (l)) != NULL)
      goto finish;

   /*Allow the model a lookin here too.*/
   if (l->model->model->entries [colourpicker_ENTRY_UPDATE_AREA] != NULL)
   {  relocate_begin (l->model->workspace, &frame);
      error = (*(os_error *(*) (wimp_w, colourpicker_colour *))
            l->model->model->entries [colourpicker_ENTRY_UPDATE_AREA])
            (l->main_w, l->colour);
      relocate_end (&frame);
      if (error != NULL) goto finish;
   }

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Menus_Deleted (void *h, void *b, osbool *unclaimed)

{  dialogue_list l = (dialogue_list) h;
   wimp_message *message = &((wimp_block *) b) ASREF message;
   os_error *error = NULL;

   NOT_USED (message)

   tracef ("Menus_Deleted\n");

   tracef ("menus deleted: in event 0x%X, in structure 0x%X\n" _
         ((wimp_message_menus_deleted *) &message->data)->menu _
         l->main_w);

   if ((error = dialogue_close (NONE, (colourpicker_d) l)) != NULL)
      goto finish;

   *unclaimed = FALSE;
      /*no more callbacks?*/

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Model (void *h, void *b, osbool *unclaimed)

   /*Change from one model to another.*/

{  dialogue_list l = (dialogue_list) h;
   wimp_pointer *pointer = &((wimp_block *) b) ASREF pointer;
   os_error *error = NULL;
   int model_no = SKIP, i;
   model_list m;
   wimp_icon_state icon_state;
   wimp_window_state window_state;
   relocate_frame frame;
   colourpicker_dialogue dialogue; /*only colour is used*/
   osbool none;

   NOT_USED (unclaimed)

   tracef ("Model\n");

   /*If this is already the selected icon, do nothing.*/
   icon_state.w = pointer->w;
   icon_state.i = pointer->i;
   if ((error = xwimp_get_icon_state (&icon_state)) != NULL)
      goto finish;
   if ((icon_state.icon.flags & wimp_ICON_SELECTED) == NONE)
   {  /*Force the redraw before changing anything (or the icons flicker).*/
      window_state.w = l->main_w;
      if ((error = xwimp_get_window_state (&window_state)) != NULL)
         goto finish;

      if ((error = xwimp_force_redraw (l->main_w,
            window_state.xscroll, window_state.visible.y0 -
            window_state.visible.y1 + window_state.yscroll,
            window_state.visible.x1 - window_state.visible.x0 +
            window_state.xscroll, window_state.yscroll)) != NULL)
         goto finish;

      /*Get the model no.*/
      for (i = 0; i < COUNT (Icons); i++)
      {  /*Set the icons to the proper amount of selectedness.*/
         tracef ("xwimp_set_icon_state (0x%X, %d, 0x%X, 0x%X)\n" _
               pointer->w _ Icons [i] _
               pointer->i == Icons [i]? wimp_ICON_SELECTED: NONE _
               wimp_ICON_SELECTED);
         if ((error = xwimp_set_icon_state (pointer->w,
               Icons [i], pointer->i == Icons [i]?
               wimp_ICON_SELECTED: NONE, wimp_ICON_SELECTED)) != NULL)
            goto finish;

         if (pointer->i == Icons [i])
            model_no = i;
      }
      tracef ("model %d\n" _ model_no);

      /*Find the colourpicker_model pointer for this model.*/
      for (m = model_registry; m != NULL; m = m->next)
         if (m->model_no == model_no)
            break;

      if (m == NULL)
      {  char s [DEC_WIDTH + 1];
         error = main_error_lookup (error_COLOUR_PICKER_BAD_MODEL,
               "BadModel", riscos_format_dec (s, model_no, 0, 1));
         goto finish;
      }

      dialogue.colour = l->colour->colour;
      tracef ("preserving colour 0x%X\n" _ l->colour->colour);
      dialogue.size = 0;

      /*Close down the old model.*/
      relocate_begin (l->model->workspace, &frame);
      error = (*(os_error *(*) (colourpicker_colour *))
            l->model->model->entries
            [colourpicker_ENTRY_DIALOGUE_FINISHING]) (l->colour);
      relocate_end (&frame);
      if (error != NULL) goto finish;

      l->model = m;

      /*Start up the new one.*/
      relocate_begin (l->model->workspace, &frame);
      error = (*(os_error *(*) (task_r, wimp_w, colourpicker_dialogue *,
            os_coord *, bits, colourpicker_colour **))
            l->model->model->entries [colourpicker_ENTRY_DIALOGUE_STARTING])
            (l->parent->r, l->main_w, &dialogue, &Offset, NONE, &l->colour);
      relocate_end (&frame);
      if (error != NULL) goto finish;

      /*Fix MED-1703: issue a message_COLOUR_PICKER_COLOUR_CHANGED in this
         case (even though it hasn't, except maybe a bit), to allow
         applications to track the current model, if they like.*/
      if ((error = None_Selected (l->main_w, &none)) != NULL)
         goto finish;

      if ((error = Colour_Changed (l, none, /*dragging?*/ FALSE)) != NULL)
         goto finish;
   }

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Help_Reply (wimp_message *message, osbool *replied_out)

   /*Reply to the given message.*/

{  help_message_request *request = (help_message_request *) &message->data;
   os_error *error = NULL;
   char token [80 + 1], *reply;
   osbool replied = FALSE;

   tracef ("Help_Reply\n");

   /*Filter out icons that cannot possibly be ours. Note the last two (OK,
      Cancel, if present) might, but might not.*/
   if (request->i < Picker->window.icon_count)
   {  strcpy (token, "Picker");

      /*Get the name of this icon (if any).*/
      if (request->i != wimp_ICON_WINDOW)
         if ((error = icon_name (request->w, request->i,
               token + strlen (token))) != NULL)
            goto finish;

      if ((error = lookup (main_messages, token, (void **) &reply)) != NULL)
      {  if (error->errnum != os_GLOBAL_NO_ANY)
            goto finish;
         error = NULL;
         reply = NULL;
      }
      /*|reply| is possibly 13-terminated, possibly in read-only memory.*/

      if (reply != NULL)
      {  if ((error = task_send_user_message (message->sender,
               message->my_ref, message_HELP_REPLY, reply,
               ALIGN (riscos_strlen (reply) + 1))) != NULL)
            goto finish;

         replied = TRUE;
      }
   }

   if (replied_out != NULL) *replied_out = replied;

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Help (void *h, void *b, osbool *unclaimed)

{  dialogue_list l = (dialogue_list) h;
   wimp_message *message = &((wimp_block *) b) ASREF message;
   os_error *error = NULL;
   osbool replied;

   tracef ("Help: dialogue flags 0x%X (IGNORE_HELP 0x%X)\n" _
         l->flags _ colourpicker_DIALOGUE_IGNORE_HELP);

   /*If this dialogue is ignoring help, do nothing.*/
   if ((l->flags & colourpicker_DIALOGUE_IGNORE_HELP) == NONE)
   {  if ((error = Help_Reply (message, &replied)) != NULL)
         goto finish;
   }
   else
      replied = TRUE;

   tracef ("setting 0x%X to %s\n" _ unclaimed _ WHETHER (!replied));
   if (replied) *unclaimed = FALSE;
      /*Fix bug: if help is not wanted, make sure that we claim the event,
      so the back ends won't see it.*/

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Task_New (wimp_t task, dialogue_task_list *tt_out)

   /*Creates a new task structure.*/

{  os_error *error = NULL, *error1;
   dialogue_task_list t = NULL;
   osbool done_new = FALSE, done_register_post_filter = FALSE,
      done_register_pre_filter = FALSE;
   char *name;

   static char Post_Name [filter_NAME_LIMIT + 1],
         Pre_Name [filter_NAME_LIMIT + 1];

   tracef ("Task_New\n");

   /*Make a dialogue_task_list entry for this task.*/
   if ((t = m_ALLOC (sizeof *t)) == NULL)
   {  error = riscos_error_lookup (os_GLOBAL_NO_MEM, "NoMem");
      goto finish;
   }

   /*sentinel*/
   t->sentinel = *(int *) "CPT ";

   /*task*/
   t->task = task;

   /*workspace*/
   t->workspace = main_workspace;

   /*saved_mask*/
   /*set in the prefilter, not used until the postfilter, so doesn't need
     initialising*/

   /*key*/
   t->key = -1;

   /*r*/
   if ((error1 = xtaskmanager_task_name_from_handle (task, &name)) != NULL)
   {  tracef ("No task name found! Using \"%s\" instead!\n" _
            error1->errmess);
      name = error1->errmess;
   }

   if ((error = task_new (name, task, &t->r)) != NULL)
      goto finish;
   done_new = TRUE;

   /*post_name*/
   if ((error = lookup (main_messages, "Post", (void **) &name)) != NULL)
      goto finish;
   t->post_name = riscos_strncpy (Post_Name, name, filter_NAME_LIMIT);

   /*pre_name*/
   if ((error = lookup (main_messages, "Pre", (void **) &name)) != NULL)
      goto finish;
   t->pre_name = riscos_strncpy (Pre_Name, name, filter_NAME_LIMIT);

   /*open_dialogues*/
   t->open_dialogues = NULL;

   /*last_dialogue*/
   t->last_dialogue = &t->open_dialogues;

   /*next*/
   t->next = NULL;

   if ((error = xfilter_register_post_filter (t->post_name,
         (void *) &veneer_post_filter, (byte *) t, task, NONE)) != NULL)
      goto finish;
   done_register_post_filter = TRUE;

   if ((error = xfilter_register_pre_filter (t->pre_name,
         (void *) &veneer_pre_filter, (byte *) t, task)) != NULL)
      goto finish;
   done_register_pre_filter = TRUE;

   if (tt_out != NULL) *tt_out = t;

finish:
   if (error != NULL)
   {  tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);

      if (done_register_pre_filter)
      {  os_error *error1;

         tracef ("xfilter_de_register_pre_filter\n");
         error1 = xfilter_de_register_pre_filter (t->pre_name,
               (void *) &veneer_pre_filter, (byte *) t, task);
         if (error == NULL) error = error1;
      }

      if (done_register_post_filter)
      {  os_error *error1;

         tracef ("xfilter_de_register_post_filter\n");
         error1 = xfilter_de_register_post_filter (t->post_name,
               (void *) &veneer_post_filter, (byte *) t, task, NONE);
         if (error == NULL) error = error1;
      }

      if (done_new)
      {  os_error *error1;

         tracef ("task_delete\n");
         error1 = task_delete (t->r);
         if (error == NULL) error = error1;
      }

      m_FREE (t, sizeof *t);
   }

   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Task_Delete (dialogue_task_list t)

   /*Deletes a task structure.*/

{  os_error *error = NULL;

   tracef ("Task_Delete\n");

   if (t->sentinel != *(int *) "CPT ")
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_HANDLE,
            "BadHandle");
      goto finish;
   }
   t->sentinel = 0;

   if ((error = xfilter_de_register_pre_filter (t->pre_name,
         (void *) &veneer_pre_filter, (byte *) t, t->task)) != NULL)
      goto finish;

   if ((error = xfilter_de_register_post_filter (t->post_name,
         (void *) &veneer_post_filter, (byte *) t, t->task, NONE)) != NULL)
      goto finish;

   if ((error = task_delete (t->r)) != NULL)
      goto finish;

   m_FREE (t, sizeof *t);

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *New (colourpicker_dialogue *dialogue,
      dialogue_task_list t, bits flags, dialogue_list *l_out)

   /*Creates a new dialogue structure.*/

{  os_error *error = NULL;
   int model_no;
   model_list m;
   dialogue_list l = NULL;
   osbool done_create_picker = FALSE, done_create_menu = FALSE,
      done_start = FALSE, done_register = FALSE;
   wimp_open open;
   relocate_frame frame;
   char *title;
   callback_l list = NULL;

   tracef ("New\n");

   /*Make a dialogue_list entry for this dialogue.*/
   if ((l = m_ALLOC (sizeof *l)) == NULL)
   {  error = riscos_error_lookup (os_GLOBAL_NO_MEM, "NoMem");
      goto finish;
   }

   /*sentinel*/
   l->sentinel = *(int *) "CPD ";

   /*flags*/
   l->flags = dialogue->flags;

   /*title*/
   /*Fill in the title from the colourpicker_dialogue.*/
   if ((l->title = dialogue->title) != NULL)
      title = dialogue->title;
   else
   {  if ((error = lookup (main_messages, "Title", (void **) &title)) !=
            NULL)
         goto finish;
   }
   riscos_strncpy (Picker->window.title_data AS indirected_text.text,
         title, Picker->window.title_data AS indirected_text.size);
   tracef ("new title is \"%s\"\n" _
         Picker->window.title_data AS indirected_text.text);

   /*main_w, main_data*/
   if ((flags & colourpicker_OPEN_TRANSIENT) == NONE)
      /*Permanent window: highlights in cream*/
      Picker->window.highlight_bg = wimp_COLOUR_CREAM;
   else
      /*Transient window: highlights in grey*/
      Picker->window.highlight_bg = wimp_COLOUR_LIGHT_GREY;

   if ((flags & (colourpicker_OPEN_TRANSIENT | colourpicker_OPEN_TOOLBOX)) ==
         colourpicker_OPEN_TOOLBOX)
   {  /*Toolbox: has Close and Back, no OK and Cancel*/
      Picker->window.flags |=
            wimp_WINDOW_BACK_ICON | wimp_WINDOW_CLOSE_ICON;
      Picker->window.icons [dialogue_PICKER_OK].flags |=
            wimp_ICON_DELETED;
      Picker->window.icons [dialogue_PICKER_CANCEL].flags |=
            wimp_ICON_DELETED;
   }
   else
   {  /*Dialogue box: has OK and Cancel, no Close and Back*/
      Picker->window.flags &=
            ~(wimp_WINDOW_BACK_ICON | wimp_WINDOW_CLOSE_ICON);
      Picker->window.icons [dialogue_PICKER_OK].flags &=
            ~wimp_ICON_DELETED;
      Picker->window.icons [dialogue_PICKER_CANCEL].flags &=
            ~wimp_ICON_DELETED;
   }

   if ((error = resource_create_window (Picker, &l->main_w, &l->main_data))
         != NULL)
      goto finish;
   done_create_picker = TRUE;
   tracef ("created window 0x%X\n" _ l->main_w);

   /*Set the None icon from the flags.*/
   if ((l->flags & colourpicker_DIALOGUE_OFFERS_TRANSPARENT) != NONE)
   {  if ((error = xwimp_set_icon_state (l->main_w, dialogue_PICKER_NONE,
            (l->flags & colourpicker_DIALOGUE_TRANSPARENT) != NONE?
            wimp_ICON_SELECTED: NONE, wimp_ICON_SELECTED)) != NULL)
         goto finish;
   }
   else
   {  if ((error = xwimp_set_icon_state (l->main_w, dialogue_PICKER_NONE,
            wimp_ICON_SHADED, wimp_ICON_SHADED)) != NULL)
         goto finish;
   }

   /*model*/
   model_no = dialogue->size > 0? dialogue->info [0]:
         colourpicker_MODEL_RGB;

   /*Find the colourpicker_model pointer for this model.*/
   for (m = model_registry; m != NULL; m = m->next)
      if (m->model_no == model_no)
         break;

   if ((l->model = m) == NULL)
   {  char s [DEC_WIDTH + 1];
      error = main_error_lookup (error_COLOUR_PICKER_BAD_MODEL, "BadModel",
            riscos_format_dec (s, model_no, 0, 1));
      goto finish;
   }

   /*Set the right icon.*/
   if ((error = xwimp_set_icon_state (l->main_w, Icons [model_no],
         wimp_ICON_SELECTED, wimp_ICON_SELECTED)) != NULL)
      goto finish;

   /*colour*/
   /*provided by the colour model, this changes as the dialogue box is
     manipulated*/

   /*Open the window.*/
   if ((flags & colourpicker_OPEN_TRANSIENT) != NONE)
   {  if ((flags & colourpicker_OPEN_SUB_MENU) != NONE)
      {  tracef ("open it as a submenu\n");
         if ((error = xwimp_create_sub_menu ((wimp_menu *) l->main_w,
               dialogue->visible.x0, dialogue->visible.y1)) != NULL)
            goto finish;
      }
      else
      {  tracef ("open it as a main menu\n");
         if ((error = xwimp_create_menu ((wimp_menu *) l->main_w,
               dialogue->visible.x0, dialogue->visible.y1)) != NULL)
            goto finish;
      }
      done_create_menu = TRUE;
   }
   else
   {  tracef ("open it as a real window\n");
      open.w          = l->main_w;
      open.visible.x0 = dialogue->visible.x0;
      open.visible.y1 = dialogue->visible.y1;
      open.visible.x1 = open.visible.x0 + Size.x;
      open.visible.y0 = open.visible.y1 - Size.y;
         /*place dialogue at (x0, y1) with that size*/
      open.xscroll    = Picker->window.xscroll;
      open.yscroll    = Picker->window.yscroll;
      open.next       = wimp_TOP;

      if ((error = xwimp_open_window (&open)) != NULL)
            goto finish;
   }

   relocate_begin (l->model->workspace, &frame);
   error = (*(os_error *(*) (task_r, wimp_w, colourpicker_dialogue *,
         os_coord *, bits, colourpicker_colour **)) l->model->model->entries
         [colourpicker_ENTRY_DIALOGUE_STARTING]) (t->r, l->main_w,
         dialogue, &Offset, flags, &l->colour);
   relocate_end (&frame);
   if (error != NULL) goto finish;
   done_start = TRUE;

   /*parent*/
   l->parent = t;

   /*next*/
   l->next = NULL;

   /*Add all the callbacks that are needed initially - first, ones common to
      all pickers.*/
   list = task_list (t->r);
   done_register = TRUE;
   if
   (  /*Redraw the picker window.*/
      (error = callback_register (list, &Redraw, l, 2,
            wimp_REDRAW_WINDOW_REQUEST, l->main_w)) != NULL ||

      /*Click SELECT or ADJUST on None.*/
      (error = callback_register (list, &None, l, 5, wimp_MOUSE_CLICK,
            l->main_w, dialogue_PICKER_NONE, wimp_CLICK_SELECT, NONE)) !=
            NULL ||
      (error = callback_register (list, &None, l, 5, wimp_MOUSE_CLICK,
            l->main_w, dialogue_PICKER_NONE, wimp_CLICK_ADJUST, NONE)) !=
            NULL ||

      /*Click SELECT on the model icons.*/
      (error = callback_register (list, &Model, l, 5,
            wimp_MOUSE_CLICK, l->main_w, dialogue_PICKER_RGB,
            wimp_CLICK_SELECT, NONE)) != NULL ||
      (error = callback_register (list, &Model, l, 5,
            wimp_MOUSE_CLICK, l->main_w, dialogue_PICKER_CMYK,
            wimp_CLICK_SELECT, NONE)) != NULL ||
      (error = callback_register (list, &Model, l, 5,
            wimp_MOUSE_CLICK, l->main_w, dialogue_PICKER_HSV,
            wimp_CLICK_SELECT, NONE)) != NULL ||

      /*Respond to help request events.*/
      (error = callback_register (list, &Help, l, 3,
            wimp_USER_MESSAGE_RECORDED, message_HELP_REQUEST, l->main_w)) !=
            NULL
   )
      goto finish;

   /*Ones needed only by toolboxes.*/
   if ((flags & (colourpicker_OPEN_TRANSIENT | colourpicker_OPEN_TOOLBOX)) ==
         colourpicker_OPEN_TOOLBOX)
   {  if
      (  /*Clicks on Close.*/
         (error = callback_register (list, &Close, l, 4,
               wimp_CLOSE_WINDOW_REQUEST, l->main_w, wimp_CLICK_SELECT,
               NONE)) != NULL ||
         (error = callback_register (list, &Parent, l, 4,
               wimp_CLOSE_WINDOW_REQUEST, l->main_w, wimp_CLICK_ADJUST,
               NONE)) != NULL ||
         (error = callback_register (list, &Close, l, 4,
               wimp_CLOSE_WINDOW_REQUEST, l->main_w, wimp_CLICK_ADJUST,
               NONE)) != NULL ||
         (error = callback_register (list, &Parent, l, 4,
               wimp_CLOSE_WINDOW_REQUEST, l->main_w, wimp_CLICK_ADJUST,
               task_SHIFT)) != NULL
      )
         goto finish;
   }
   else
   {  /*Those needed only by dialogue boxes.*/
      if
      (  /*Click SELECT on OK*/
         (error = callback_register (list, &Choice, l, 5, wimp_MOUSE_CLICK,
               l->main_w, dialogue_PICKER_OK, wimp_CLICK_SELECT, NONE)) !=
               NULL ||

         /*Click ADJUST on OK.*/
         (error = callback_register (list, &Choice, l, 5, wimp_MOUSE_CLICK,
               l->main_w, dialogue_PICKER_OK, wimp_CLICK_ADJUST, NONE)) !=
               NULL ||

         /*Click ADJUST on Cancel.*/
         (error = callback_register (list, &Reset, l, 5, wimp_MOUSE_CLICK,
               l->main_w, dialogue_PICKER_CANCEL, wimp_CLICK_ADJUST, NONE))
               != NULL ||

         /*Press Return (invoked only via ColourPickerModelSWI_ProcessKey).*/
         (error = callback_register (list, &Choice, l, 4, wimp_KEY_PRESSED,
               l->main_w, wimp_ICON_WINDOW, wimp_KEY_RETURN)) != NULL
      )
         goto finish;

      if ((flags & colourpicker_OPEN_TRANSIENT) != NONE)
      {  /*Those needed only by transient (menu and sub-menu) dialogue
            boxes.*/
         if
         (  /*We need to find out when it goes away of its own accord.*/
            (error = callback_register (list, &Menus_Deleted, l, 2,
                  wimp_USER_MESSAGE, message_MENUS_DELETED)) != NULL ||
            (error = callback_register (list, &Menus_Deleted, l, 2,
                  wimp_USER_MESSAGE_RECORDED, message_MENUS_DELETED)) !=
                  NULL
                  ||

            /*And also when it is dismissed.*/
            (error = callback_register (list, &Dismiss, l, 5,
                  wimp_MOUSE_CLICK, l->main_w, dialogue_PICKER_OK,
                  wimp_CLICK_SELECT, NONE)) != NULL ||

            (error = callback_register (list, &Dismiss, l, 5,
                  wimp_MOUSE_CLICK, l->main_w, dialogue_PICKER_CANCEL,
                  wimp_CLICK_SELECT, NONE)) != NULL ||

            (error = callback_register (list, &Dismiss, l, 4,
                  wimp_KEY_PRESSED, l->main_w, wimp_ICON_WINDOW,
                  wimp_KEY_RETURN)) != NULL ||

            (error = callback_register (list, &Dismiss, l, 4,
                  wimp_KEY_PRESSED, l->main_w, wimp_ICON_WINDOW,
                  wimp_KEY_ESCAPE)) != NULL
         )
            goto finish;
      }
      else
      {  /*Those needed only by permanent dialogue boxes: the
            CloseDialogueRequest-generating handlers.*/
         if
         (  /*Click SELECT on OK.*/
            (error = callback_register (list, &Close, l, 5,
                  wimp_MOUSE_CLICK, l->main_w, dialogue_PICKER_OK,
                  wimp_CLICK_SELECT, NONE)) != NULL ||

            /*Click SELECT on Cancel.*/
            (error = callback_register (list, &Close, l, 5,
                  wimp_MOUSE_CLICK, l->main_w, dialogue_PICKER_CANCEL,
                  wimp_CLICK_SELECT, NONE)) != NULL ||

            /*Press Return (invoked via ColourPickerModelSWI_ProcessKey).*/
            (error = callback_register (list, &Close, l, 4,
                  wimp_KEY_PRESSED, l->main_w, wimp_ICON_WINDOW,
                  wimp_KEY_RETURN)) != NULL ||

            /*Press Escape (ditto).*/
            (error = callback_register (list, &Close, l, 4,
                  wimp_KEY_PRESSED, l->main_w, wimp_ICON_WINDOW,
                  wimp_KEY_ESCAPE)) != NULL
         )
            goto finish;
   }  }

   if (l_out != NULL) *l_out = l;

finish:
   if (error != NULL)
   {  tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);

      if (done_register)
      {  tracef ("callback_deregister\n");
         callback_deregister (list, l, 0);
      }

      if (done_start)
      {  os_error *error1;

         tracef ("relocating to model: ME 0x%X, MODEL 0x%X\n" _
               main_workspace _ l->model->workspace);
         relocate_begin (l->model->workspace, &frame);
         error1 = (*(os_error *(*) (colourpicker_colour *))
               l->model->model->entries
               [colourpicker_ENTRY_DIALOGUE_FINISHING]) (l->colour);
         relocate_end (&frame);
         tracef ("relocated back\n");
         if (error == NULL) error = error1;
      }

      /*If the dialogue was being opened as a menu or submenu, we must delete
         the menu tree, or the WIMP aborts later. J R C 3rd Mar 1994*/
      if (done_create_menu)
      {  os_error *error1;

         tracef ("xwimp_create_menu\n");
         error1 = xwimp_create_menu (wimp_CLOSE_MENU, SKIP, SKIP);
         if (error == NULL) error = error1;
      }

      if (done_create_picker)
      {  os_error *error1;

         tracef ("resource_delete_window\n");
         error1 = resource_delete_window (l->main_w, l->main_data);
         if (error == NULL) error = error1;
      }

      tracef ("m_FREE\n");
      m_FREE (l, sizeof *l);
   }

   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Delete (dialogue_list l)
      /*Second argument ("transient") removed. J R C 23rd Feb 1994*/
      /*New 2nd argument "delete_tree" added. J R C  3rd Mar 1994*/
      /*Removed completely. JRC 10th Jan 1995*/

   /*Deletes a dialogue structure.*/

{  os_error *error = NULL, *error1;
   relocate_frame frame;
   wimp_window_state state;

   tracef ("Delete\n");

   if (l->sentinel != *(int *) "CPD ")
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_HANDLE,
            "BadHandle");
      goto finish;
   }
   l->sentinel = 0;

   tracef ("relocating to model: ME 0x%X, MODEL 0x%X\n" _
         main_workspace _ l->model->workspace);
   relocate_begin (l->model->workspace, &frame);
   error1 = (*(os_error *(*) (colourpicker_colour *))
         l->model->model->entries
         [colourpicker_ENTRY_DIALOGUE_FINISHING]) (l->colour);
   relocate_end (&frame);
   tracef ("relocated back\n");

   /*Remove all the callbacks for this dialogue.*/
   callback_deregister (task_list (l->parent->r), l, 0);

   if (l == Transient)
   {  Transient = NULL;

      /*We must delete the menu tree if we are deleting a transient colour
         picker that is open.*/
      state.w = l->main_w;
      if ((error = xwimp_get_window_state (&state)) != NULL)
         goto finish;

      if ((state.flags & wimp_WINDOW_OPEN) != NONE)
      {  tracef ("opened as a submenu\n");
         if ((error = xwimp_create_menu (wimp_CLOSE_MENU, SKIP, SKIP)) !=
               NULL)
            goto finish;
   }  }

   tracef ("deleting main window\n");
#ifndef ROM
/* This is Service_WindowDeleted.  Issued for the sole benefit of BorderUtils
 * in RISC OS 3.1 to stop the Wimp dying when deleting a window containing
 * an icon which is slabbed in.
 */
   {
      _kernel_swi_regs regs;              /* NK 12.1.95 */
      regs.r[0] = (int) l->main_w;
      regs.r[1] = 0x44ec5;
      regs.r[2] = (int) l->parent->task;
      _kernel_swi(OS_ServiceCall,&regs,&regs);

   }
#endif
   if ((error = resource_delete_window (l->main_w, l->main_data)) !=
         NULL)
      goto finish;

   m_FREE (l, sizeof *l);

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_setup (void)

{  os_error *error = NULL;

   /*Find the wimp_window to use to create new ones.*/
   if ((error = lookup (main_templates, "Picker", (void **) &Picker)) !=
         NULL)
      goto finish;

   /*Fill in the position from the arguments given.*/
   Size.x = Picker->window.visible.x1 - Picker->window.visible.x0;
   Size.y = Picker->window.visible.y1 - Picker->window.visible.y0;
      /*size of the template*/

   /*Find the offsets to the placeholder icon.*/
   Offset.x = Picker->window.icons [dialogue_PICKER_PLACEHOLDER].extent.x0 -
         Picker->window.xscroll;
   Offset.y = Picker->window.icons [dialogue_PICKER_PLACEHOLDER].extent.y1 -
         Picker->window.yscroll;
   tracef ("offset is (%d, %d)\n" _ Offset.x _ Offset.y);

   /*Get the pointer to the crosshatch sprite.*/
   if ((error = lookup (main_sprites, "crosshatch", (void **) &Crosshatch))
         != NULL)
      goto finish;

finish:
   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_initialise (void)

{  os_error *error = NULL;

   tracef ("dialogue_initialise\n");

   /*Clear the list of open dialogues.*/
   dialogue_active_tasks = NULL;
   dialogue_last_task = &dialogue_active_tasks;

   if ((error = dialogue_setup ()) != NULL)
      goto finish;

   Transient = NULL;

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_terminate (void)

   /* Close down the whole module. Refuses to die if there are any dialogues
      open.

      **NOTE** This function is unlike all the others in this source file:
      it is not called in the context of a WIMP task, but asynchronously.
   */

{  os_error *error = NULL;

   tracef ("dialogue_terminate\n");

   if (dialogue_active_tasks != NULL)
   {  char *module_name;

      if ((error = lookup (main_messages, "Module", (void **) &module_name))
            != NULL)
         goto finish;

      tracef ("%.*s is in use\n" _
            riscos_strlen (module_name) _ module_name);
      error = main_error_lookup (error_COLOUR_PICKER_IN_USE, "InUse",
            module_name);
      goto finish;
   }

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_open (bits flags, colourpicker_dialogue *dialogue,
      colourpicker_d *d_out, wimp_w *w_out)

{  os_error *error = NULL;
   dialogue_list l = NULL;
   dialogue_task_list t = NULL;
   osbool done_new = FALSE, done_task_new = FALSE;
   wimp_t task;

   tracef ("dialogue_open: flags 0x%X, dialogue 0x%X\n" _ flags _ dialogue);

   /*Check arguments.*/
   if ((flags & ~(colourpicker_OPEN_TRANSIENT | colourpicker_OPEN_SUB_MENU))
         != NONE)
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_FLAGS, "BadFlags");
      goto finish;
   }

   if ((error = xwimpreadsysinfo_task (&task, NULL)) != NULL)
      goto finish;
   *(int *) &task &= 0xFFFF;
   tracef ("module thinks task is 0x%X\n" _ task);

   if (task == 0)
   {  error = main_error_lookup (error_COLOUR_PICKER_UNINIT, "Uninit");
      goto finish;
   }

   #ifdef MTRACE
      tracef ("memory state at start of OpenDialogue\n");
      m_SUMMARY ();
   #endif

   /*Make sure this task has a suitable filter, so we can monitor the events
      it gets and do The Right Thing.*/
   if ((t = dialogue_task (task)) == NULL)
   {  /*No record exists for this active task: invent one.*/
      if ((error = Task_New (task, &t)) != NULL)
         goto finish;
      done_task_new = TRUE;
   }

   /*Create the open dialogue record for this dialogue.*/
   if ((error = New (dialogue, t, flags, &l)) != NULL)
      goto finish;
   done_new = TRUE;

   /*If it's new, add this task list entry to the list of all active task
      records.*/
   if (done_task_new)
   {  *dialogue_last_task = t;
      dialogue_last_task = &t->next;
   }

   /*Link me into the task's list of dialogues.*/
   *t->last_dialogue = l;
   t->last_dialogue = &l->next;

   if ((flags & colourpicker_OPEN_TRANSIENT) != NONE)
   {  /*If there is a transient dialogue open already, close it.*/
      if (Transient != NULL)
      {  tracef ("closing transient dialogue ...\n");
         if ((error = dialogue_close (NONE, (colourpicker_d) Transient)) !=
                NULL)
            goto finish;
         tracef ("closing transient dialogue ... done\n");
      }

      /*Record the new transient.*/
      Transient = l;
   }

   tracef ("new dialogue is 0x%X, window 0x%X == %d\n" _
         l _ l->main_w _ l->main_w);

   if (w_out != NULL) *w_out = l->main_w;
   if (d_out != NULL) *d_out = (colourpicker_d) l;

finish:
   if (error != NULL)
   {  tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);

      if (done_new)
      {  os_error *error1;

         tracef ("Delete\n");
         /*we must close the menu tree if there was an error while trying to
            open a transient dbox*/
         error1 = Delete (l);
         if (error == NULL) error = error1;
      }

      if (done_task_new)
      {  os_error *error1;

         tracef ("Task_Delete\n");
         error1 = Task_Delete (t);
         if (error == NULL) error = error1;
      }

      tracef ("m_FREE\n");
      m_FREE (l, sizeof *l);
   }

   #ifdef MTRACE
      tracef ("memory state at end of OpenDialogue\n");
      m_SUMMARY ();
   #endif

   #ifdef XTRACE
   Trace_Dialogues ("opened dialogue");
   #endif
   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_close (bits flags, colourpicker_d d)

   /* Implements the SWI ColourPicker_CloseDialogue.
   */

{  os_error *error = NULL;
   dialogue_list l, *ll;
   dialogue_task_list t, *tt;

   tracef ("dialogue_close: flags 0x%X, d 0x%X\n" _ flags _ d);

   #ifdef XTRACE
   Trace_Dialogues ("start");
   #endif

   /*Check arguments.*/
   if (flags != NONE)
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_FLAGS, "BadFlags");
      goto finish;
   }

   l = (dialogue_list) d;

   if (l->sentinel != *(int *) "CPD ")		/* NK 12.1.95 */
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_HANDLE,
            "BadHandle");
      goto finish;
   }

   t = l->parent;

   /*Find the predecessor of this dialogue and remove this one from the
         list.*/
   for (ll = &t->open_dialogues; *ll != NULL; ll = &(*ll)->next)
      if (*ll == l)
      {  tracef ("*0x%X = 0x%X\n" _ ll _ l->next);
         *ll = l->next;
         break;
      }

   if (l->next == NULL)
   {  /*I was the last one in my parent's list: update it.*/
      tracef ("t->last_dialogue = 0x%X\n" _ ll);
      t->last_dialogue = ll;
   }

   /*Never delete the menu tree fom here: either we are being called to
      delete a transient dialogue because a new one is being opened, or we
      are being called by a client who has received a message_COLOUR_PICKER_-
      CLOSE_DIALOGUE_REQUEST event, and in either case the menu tree is
      already gone. I hope. J R C 3rd Mar 1994*/
   if ((error = Delete (l)) != NULL)
      goto finish;

   if (t->open_dialogues == NULL)
   {
      #ifdef XTRACE
      Trace_Dialogues ("deleted dialogue");
      #endif

      /*My parent has no children now! Find its predecessor, and unlink it
          from its list.*/
      for (tt = &dialogue_active_tasks; *tt != NULL; tt = &(*tt)->next)
         if (*tt == t)
         {  tracef ("*0x%X = 0x%X\n" _ tt _ t->next);
            *tt = t->next;
            break;
         }

      #ifdef XTRACE
      Trace_Dialogues ("task unlinked");
      #endif

      if (t->next == NULL)
      {  /*I was the last task in the list.*/
         tracef ("dialogue_last_task = 0x%X\n" _ tt);
         dialogue_last_task = tt;
      }

      #ifdef XTRACE
      Trace_Dialogues ("last fixed up");
      #endif

      /*And delete it.*/
      if ((error = Task_Delete (t)) != NULL)
         goto finish;
   }

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);

   #ifdef XTRACE
   Trace_Dialogues ("done close");
   #endif

   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_update (bits flags, colourpicker_d d,
       colourpicker_dialogue *dialogue)

{  os_error *error = NULL;
   dialogue_list l;
   int i;

   tracef ("dialogue_update\n");

   /*Check arguments.*/
   if ((flags & ~(colourpicker_UPDATE_OFFERS_TRANSPARENT |
         colourpicker_UPDATE_TRANSPARENT | colourpicker_UPDATE_TYPE |
         colourpicker_UPDATE_VISIBLE | colourpicker_UPDATE_SCROLL |
         colourpicker_UPDATE_TITLE | colourpicker_UPDATE_COLOUR |
         colourpicker_UPDATE_MODEL | colourpicker_UPDATE_IGNORE_HELP |
         colourpicker_UPDATE_IGNORE_KEY_PRESSED)) != NONE)
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_FLAGS, "BadFlags");
      goto finish;
   }

   /*Recall that the handle is the list element.*/
   l = (dialogue_list) d;

   if (l->sentinel != *(int *) "CPD ")
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_HANDLE,
            "BadHandle");
      goto finish;
   }

   if ((flags & colourpicker_UPDATE_OFFERS_TRANSPARENT) != NONE)
   {  if ((dialogue->flags & colourpicker_DIALOGUE_OFFERS_TRANSPARENT) !=
            NONE)
      {  /*Add a None button to |d|.*/
         if ((error = xwimp_set_icon_state (l->main_w, dialogue_PICKER_NONE,
               NONE, wimp_ICON_SHADED)) != NULL)
            goto finish;

         /*Fix MED-xxxx: update record to reflect change. JRC 21st Dec 1994*/
         l->flags |= colourpicker_DIALOGUE_OFFERS_TRANSPARENT;
      }
      else
      {  /*Remove the None button from |d|. Deselect transparent, just in
            case. (JRC 9th Dec 1994)*/
         if ((error = xwimp_set_icon_state (l->main_w, dialogue_PICKER_NONE,
               wimp_ICON_SHADED, wimp_ICON_SHADED | wimp_ICON_SELECTED)) !=
               NULL)
            goto finish;

         /*Fix MED-xxxx: update record to reflect change. JRC 21st Dec 1994*/
         l->flags &= ~colourpicker_DIALOGUE_OFFERS_TRANSPARENT;
   }  }

   if ((flags & colourpicker_UPDATE_TRANSPARENT) != NONE)
   {  osbool none = (dialogue->flags & colourpicker_DIALOGUE_TRANSPARENT) !=
            NONE;

      /*Set the dialogue box.*/
      if ((error = xwimp_set_icon_state (l->main_w, dialogue_PICKER_NONE,
            none? wimp_ICON_SELECTED: NONE, wimp_ICON_SELECTED)) != NULL)
         goto finish;

      /*Send the relevant message.*/
      if ((error = Colour_Changed (l, none, /*dragging?*/ FALSE)) != NULL)
         goto finish;

      /*Fix MED-xxxx: update record to reflect change. JRC 21st Dec 1994*/
      if (none)
         l->flags |= colourpicker_DIALOGUE_TRANSPARENT;
      else
         l->flags &= ~colourpicker_DIALOGUE_TRANSPARENT;
   }

   if ((flags & colourpicker_UPDATE_TYPE) != NONE)
      /*Change the message type of |d| from |dialogue|.*/
      l->flags = (l->flags & ~colourpicker_DIALOGUE_TYPE) |
            (dialogue->flags & colourpicker_DIALOGUE_TYPE);

   if ((flags & (colourpicker_UPDATE_VISIBLE | colourpicker_UPDATE_SCROLL))
         != NONE)
   {  /*Implemented JRC 23rd Feb 1995*/
      wimp_window_state state;

      state.w = l->main_w;
      if ((error = xwimp_get_window_state (&state)) != NULL)
         goto finish;

      if ((flags & colourpicker_UPDATE_VISIBLE) != NONE)
      {  state.visible.x0 = dialogue->visible.x0;
         state.visible.y1 = dialogue->visible.y1;
         state.visible.x1 = state.visible.x0 + Size.x;
         state.visible.y0 = state.visible.y1 - Size.y;
      }
      if ((flags & colourpicker_UPDATE_SCROLL) != NONE)
      {  state.xscroll = dialogue->xscroll;
         state.yscroll = dialogue->yscroll;
      }

      if ((error = xwimp_open_window ((wimp_open *) &state)) != NULL)
         goto finish;
   }

   if ((flags & colourpicker_UPDATE_TITLE) != NONE)
   #if 0
   {  wimp_outline outline;
      wimp_window_info info;
      char *title;

      if ((l->title = dialogue->title) != NULL)
         title = dialogue->title;
      else
      {  if ((error = lookup (main_messages, "Title", (void **) &title))
               != NULL)
            goto finish;
      }

      /*Update the window's indirected data.*/
      info.w = l->main_w;
      if ((error = xwimp_get_window_info_header_only (&info)) != NULL)
         goto finish;

      riscos_strncpy (info.title_data AS indirected_text.text,
            title, info.title_data AS indirected_text.size);

      /*Redraw that area of the screen.*/
      outline.w = l->main_w;
      if ((error = xwimp_get_window_outline (&outline)) != NULL)
         goto finish;

      if ((error = xwimp_force_redraw ((wimp_w) -1, outline.outline.x0,
            info.visible.y1, outline.outline.x1, outline.outline.y1)) !=
            NULL)
         goto finish;
   }
   #else
   {  char *title;

      if ((l->title = dialogue->title) != NULL)
         title = dialogue->title;
      else
      {  if ((error = lookup (main_messages, "Title", (void **) &title))
               != NULL)
            goto finish;
      }

      if ((error = window_set_title (l->main_w, title)) != NULL)
         goto finish;
   }
   #endif

   if ((flags & colourpicker_UPDATE_COLOUR) != NONE)
   {  relocate_frame frame;
      colourpicker_dialogue dialogue2;

      dialogue2.colour = dialogue->colour;
      dialogue2.size = 0;

      relocate_begin (l->model->workspace, &frame);
      error = (*(os_error *(*) (colourpicker_dialogue *,
            colourpicker_colour *)) l->model->model->entries
            [colourpicker_ENTRY_SET_VALUES]) (&dialogue2, l->colour);
      relocate_end (&frame);
      if (error != NULL) goto finish;
   }

   if ((flags & colourpicker_UPDATE_MODEL) != NONE)
   {  relocate_frame frame;
      int model_no;
      model_list m;

      /*Which is the new model?*/
      model_no = dialogue->size > 0? dialogue->info [0]:
            colourpicker_MODEL_RGB;

      /*Find the colourpicker_model pointer for this model.*/
      for (m = model_registry; m != NULL; m = m->next)
         if (m->model_no == model_no)
            break;

      if (m == NULL)
      {  char s [DEC_WIDTH + 1];
         error = main_error_lookup (error_COLOUR_PICKER_BAD_MODEL,
               "BadModel", riscos_format_dec (s, model_no, 0, 1));
         goto finish;
      }

      /*Fix MED-3681, force redraw the window. J R C 22nd Aug 1994*/
      if ((error = xwimp_force_redraw (l->main_w, -0x1FFFFFFF, -0x1FFFFFFF,
            0x1FFFFFFF, 0x1FFFFFFF)) != NULL)
         goto finish;

      /*Close down the old model.*/
      relocate_begin (l->model->workspace, &frame);
      error = (*(os_error *(*) (colourpicker_colour *))
            l->model->model->entries
            [colourpicker_ENTRY_DIALOGUE_FINISHING]) (l->colour);
      relocate_end (&frame);
      if (error != NULL) goto finish;

      l->model = m;

      /*Start up the new one.*/
      relocate_begin (l->model->workspace, &frame);
      error = (*(os_error *(*) (task_r, wimp_w, colourpicker_dialogue *,
            os_coord *, bits, colourpicker_colour **))
            l->model->model->entries [colourpicker_ENTRY_DIALOGUE_STARTING])
            (l->parent->r, l->main_w, dialogue, &Offset, NONE, &l->colour);
      relocate_end (&frame);
      if (error != NULL) goto finish;

      /*Set the icons to the proper amount of selectedness.*/
      for (i = 0; i < COUNT (Icons); i++)
         if ((error = xwimp_set_icon_state (l->main_w, Icons [i],
               i == model_no? wimp_ICON_SELECTED: NONE,
               wimp_ICON_SELECTED)) != NULL)
            goto finish;
   }

   if ((flags & colourpicker_UPDATE_IGNORE_HELP) != NONE)
      /*Change the ignore help bit.*/
      l->flags = (l->flags & ~colourpicker_DIALOGUE_IGNORE_HELP) |
            (dialogue->flags & colourpicker_DIALOGUE_IGNORE_HELP);

   if ((flags & colourpicker_UPDATE_IGNORE_KEY_PRESSED) != NONE)
      /*Change the ignore key pressed bit.*/
      l->flags = (l->flags & ~colourpicker_DIALOGUE_IGNORE_KEY_PRESSED) |
            (dialogue->flags & colourpicker_DIALOGUE_IGNORE_KEY_PRESSED);

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_read (bits flags, colourpicker_d d,
      colourpicker_dialogue *dialogue, wimp_w *w_out, int *size_out)

{  os_error *error = NULL;
   dialogue_list l;
   int size;

   tracef ("dialogue_read\n");

   /*Check arguments.*/
   if (flags != NONE)
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_FLAGS, "BadFlags");
      goto finish;
   }

   /*Recall that the handle is the list element.*/
   l = (dialogue_list) d;

   if (l->sentinel != *(int *) "CPD ")
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_HANDLE,
            "BadHandle");
      goto finish;
   }

   size = l->model->model->info_size /*was l->colour->size JRC 8th Dec
         1994*/;

   if (dialogue != NULL)
   {  /*Return what the user gave us, as modified since.*/
      wimp_window_state state;

      state.w = l->main_w;
      if ((error = xwimp_get_window_state (&state)) != NULL)
         goto finish;

      dialogue->flags   = l->flags;
      dialogue->title   = l->title;
      dialogue->visible = state.visible;
      dialogue->xscroll = state.xscroll;
      dialogue->yscroll = state.yscroll;
      dialogue->colour  = l->colour->colour;
      dialogue->size    = size;
      memcpy (&dialogue->info, &l->colour->info, size);
   }
   else
   {  /*Only write the buffer size out if there is no buffer. JRC 10th Jan
        1995*/
      if (size_out != NULL)
         *size_out = offsetof (colourpicker_dialogue, info) + size;
   }

   if (w_out != NULL) *w_out = l->main_w;

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_close_down (dialogue_task_list t)

   /*Dispose of our resources held for the given task.*/

{  os_error *error = NULL;
   dialogue_task_list *tt;
   dialogue_list l, next_l;

   tracef ("dialogue_close_down\n");

   /*If the task that is closing down has the transient dialogue, delete the
      menu tree to prevent an abort. J R C 3rd Mar 1994*/
   for (l = t->open_dialogues; l != NULL; l = next_l)
   {  next_l = l->next;
      if ((error = Delete (l)) != NULL)
         goto finish;
   }

   /*Find my predecessor, and unlink me from the list.*/
   for (tt = &dialogue_active_tasks; *tt != NULL; tt = &(*tt)->next)
      if (*tt == t)
      {  tracef ("*0x%X = 0x%X\n" _ tt _ t->next);
         *tt = t->next;
         break;
      }

   #ifdef XTRACE
   Trace_Dialogues ("task unlinked");
   #endif

   if (t->next == NULL)
   {  /*I was the last task in the list.*/
      tracef ("dialogue_last_task = 0x%X\n" _ tt);
      dialogue_last_task = tt;
   }

   #ifdef XTRACE
   Trace_Dialogues ("last fixed up");
   #endif

   /*And delete me.*/
   if ((error = Task_Delete (t)) != NULL)
      goto finish;

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
dialogue_task_list dialogue_task (wimp_t task)

{  dialogue_task_list t;

   tracef ("dialogue_task\n");

   for (t = dialogue_active_tasks; t != NULL; t = t->next)
      if (t->task == task)
            return t;

   return NULL;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_colour_changed (osbool dragging,
      colourpicker_colour *colour)

   /*Called when a colour model notices a colour changing.*/

{  os_error *error = NULL;
   dialogue_task_list t;
   dialogue_list l = SKIP;
   osbool none;

   tracef ("dialogue_colour_changed\n");

   /*Find the dialogue that is displaying this colour.*/
   for (t = dialogue_active_tasks; t != NULL; t = t->next)
      for (l = t->open_dialogues; l != NULL; l = l->next)
         if (l->colour == colour)
            goto break2;
break2:;

   if (l != NULL)
   {  /*|l| is the dialogue structure for the dialogue on whose behalf
         the message was sent.*/

      /*Clear the None button, if it is set. (If it's shaded, this just
         doesn't do anything.)*/
      if ((error = None_Selected (l->main_w, &none)) != NULL)
         goto finish;
      if (none)
         if ((error = xwimp_set_icon_state (l->main_w, dialogue_PICKER_NONE,
               NONE, wimp_ICON_SELECTED)) != NULL)
            goto finish;

      if ((error = Colour_Changed (l, /*none?*/ FALSE, dragging)) != NULL)
         goto finish;

      /*Update the colour patch.*/
      if ((error = Update (l)) != NULL)
         goto finish;
   }

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_process_key (int c, colourpicker_colour *colour)

   /*Called for key presses that the colour model cannot cope with.*/

{  os_error *error = NULL;
   dialogue_task_list t;
   dialogue_list l = NULL;
   osbool unclaimed;

   tracef ("dialogue_process_key\n");

   /*Find the dialogue that is displaying this colour.*/
   for (t = dialogue_active_tasks; t != NULL; t = t->next)
      for (l = t->open_dialogues; l != NULL; l = l->next)
         if (l->colour == colour)
            goto break2;
break2:;

   /*This is a bit low, but it should do the trick.*/
   if (l != NULL)
   {  /*|l| is the dialogue structure for the dialogue on whose behalf
         the key was pressed.*/

      if ((error = callback (task_list (l->parent->r), l, &unclaimed, 4,
            wimp_KEY_PRESSED, l->main_w, wimp_ICON_WINDOW, c)) != NULL)
         goto finish;

      if (unclaimed)
      {  tracef ("key press not claimed - setting key %d\n" _ c);
         if ((l->flags & colourpicker_DIALOGUE_IGNORE_KEY_PRESSED) == NONE)
            t->key = c;
   }  }

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
/*------------------------------------------------------------------------*/
os_error *dialogue_help_reply (bits flags, wimp_message *message)

   /*May be called by an application that is handling its own help, to get
     the ColourPicker's default help.*/

{  os_error *error = NULL;
   dialogue_task_list t;
   dialogue_list l;
   help_message_request *request = (help_message_request *) &message->data;
   wimp_w w = request->w;

   tracef ("dialogue_help_reply\n");

   /*Check arguments.*/
   if (flags != NONE)
   {  error = main_error_lookup (error_COLOUR_PICKER_BAD_FLAGS, "BadFlags");
      goto finish;
   }

   /*Find the dialogue with this window, if there is one.*/
   for (t = dialogue_active_tasks; t != NULL; t = t->next)
      for (l = t->open_dialogues; l != NULL; l = l->next)
         if (l->main_w == w)
         {  /*Just fake a message_HELP_REQUEST, and call our own postfilter.
               The alternative would involve faking an event for the back
               ends anyway, since that is the only way of entering them:
               this way, we keep code size low.*/
            if ((error = main_event (wimp_USER_MESSAGE_RECORDED,
                  (wimp_block *) message, t)) != NULL)
               goto finish;

            goto break2;
         }
break2:;

finish:
   if (error != NULL)
      tracef ("ERROR: %s (error 0x%X)\n" _ error->errmess _ error->errnum);
   return error;
}
