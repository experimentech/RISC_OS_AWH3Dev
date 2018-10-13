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
/* Title:   gadgets.c
 * Purpose: generic gadgets in the Window module
 * Author:  IDJ
 * History: 11-Feb-94: IDJ: created
 *          09-Mar-94: CSM: Slight (ahem) problem with gadgets_method: was using
 *                          % 64 to calculate gadget type instead of / 64.
 *                          Changed interface to gadgets__redraw_gadget to take
 *                          a wimp window handle, not WindowInternal. Allows gadgets
 *                          to make use of it.
 *          06-Apr-94: IDJ: changed gadget type to be <gadget>.Base as in hdr file
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#include "swis.h"
#include "kernel.h"
#include "Global/Services.h"
#include "Global/NewErrors.h"

#include "const.h"
#include "macros.h"
#include "debug.h"
#include "mem.h"
#include "string32.h"
#include "messages.h"


#include "objects/toolbox.h"
#include "objects/window.h"

#include "globals.h"
#include "gadgets.h"
#include "object.h"
#include "miscop.h"
#include "veneers.h"
#include "utils.h"
#include "events.h"

#include "gadgets.actbut.h"
#include "gadgets.adjuster.h"
#include "gadgets.display.h"
#include "gadgets.draggable.h"
#include "gadgets.label.h"
#include "gadgets.labelbox.h"
#include "gadgets.numrange.h"
#include "gadgets.optbut.h"
#include "gadgets.popupmenu.h"
#include "gadgets.radiobut.h"
#include "gadgets.slider.h"
#include "gadgets.stringset.h"
#include "gadgets.button.h"
#include "gadgets.writable.h"
#include "gadgets.simple.h"



/*
 * This file implements the generic gadget operations, and dispatches methods and
 * events to their appropriate gadget-specific implementations
 */


#define MAX_ICONS_FOR_GADGET 16   /* this gives largest number of icons used to implement a gadget (yuk) */

/* reason codes for gadget extension */

#define GADGET_ADD              1
#define GADGET_REMOVE           2
#define GADGET_FADE             3
#define GADGET_METHOD           4
#define GADGET_TBEVENT          5
#define GADGET_MCLICK           6
#define GADGET_KPRESSED         7
#define GADGET_MESSAGE          8
#define GADGET_PLOT             9
#define GADGET_SETFOCUS         10
#define GADGET_MOVE             11
#define GADGET_POSTADD          12
#define GADGET_WINDOWAPPEARING  13

/* entry points giving addresses of functions to be called depending on gadget type */

typedef struct gadgetentrypoints
{
    _kernel_oserror    *(*add)           (GadgetInternal *gadget, ObjectID window, int **icon_list, Gadget *gadget_template, int window_handle);
    _kernel_oserror    *(*remove)        (GadgetInternal *gadget, ObjectID window, int recurse);
    _kernel_oserror    *(*fade)          (GadgetInternal *gadget, ObjectID window, int do_fade);

    _kernel_oserror    *(*method)        (GadgetInternal *gadget, ObjectID window, _kernel_swi_regs *r);

    _kernel_oserror    *(*toolbox_event) (GadgetInternal *gadget, ToolboxEvent *event, ComponentID gadget_id, ObjectID ob);

    _kernel_oserror    *(*mouse_click)   (GadgetInternal *gadget, ObjectID window, wimp_PollBlock *poll_block, int *claimed);
    _kernel_oserror    *(*key_pressed)   (GadgetInternal *gadget, ObjectID window, wimp_PollBlock *poll_block, int *claimed);

    /* set *claimed to 1 to claim message */
    _kernel_oserror    *(*user_message)  (wimp_PollBlock *poll_block, int *claimed);

    /* How about sensible co-ordinates? 0,0 topleft 10,10 bottom right? Perhaps not... */
    _kernel_oserror    *(*redraw)        (GadgetInternal *gadget, int x0, int y0, int x1, int y1);

    _kernel_oserror    *(*set_focus)     (GadgetInternal *gadget, int window_handle, int direction) ;
    _kernel_oserror    *(*move)          (GadgetInternal *gadget, ObjectID window, int window_handle, wimp_Bbox *box);
    int                 ValidFlags;
} GadgetEntryPoints;


int WIMP_WINDOW=0;        /* used by gadgets, when they require underlying window */
static int CurrentId=0x1000;
int SWI_WimpCreateIcon=Wimp_CreateIcon;
static int PlotGadgetOptions;
static int GlobalIconFlags;
extern WindowInternal *CURRENT_WINDOW;
extern int WIMP_VERSION_NUMBER;
WindowInternal *CURRENT_WINDOW;
static _kernel_oserror *last_create_icon_error;

static _kernel_oserror *gadgets__set_fade(GadgetInternal *g, ObjectID window, unsigned int do_fade);

static int get_font(int win,int i);

static GadgetEntryPoints entry_points[MAX_GADGET_CODE+1] = {
        {action_button_add,
         action_button_remove,
         action_button_set_fade,
         action_button_method,
         action_button_toolbox_event,
         action_button_mouse_click,
         action_button_key_pressed,
         action_button_user_message,
         action_button_redraw,
         action_button_set_focus,
         NULL,
         ActionButtonValidFlags
        },

        {option_button_add,
         option_button_remove,
         option_button_set_fade,
         option_button_method,
         option_button_toolbox_event,
         option_button_mouse_click,
         option_button_key_pressed,
         option_button_user_message,
         option_button_redraw,
         option_button_set_focus,
         NULL,
         OptionButtonValidFlags
        },

        {labelled_box_add,
         labelled_box_remove,
         labelled_box_set_fade,
         labelled_box_method,
         labelled_box_toolbox_event,
         labelled_box_mouse_click,
         labelled_box_key_pressed,
         labelled_box_user_message,
         labelled_box_redraw,
         labelled_box_set_focus,
         labelled_box_move,
         LabelledBoxValidFlags
        },

        {label_add,
         label_remove,
         label_set_fade,
         label_method,
         label_toolbox_event,
         label_mouse_click,
         label_key_pressed,
         label_user_message,
         label_redraw,
         label_set_focus,
         NULL,
         LabelValidFlags
        },

        {radio_button_add,
         radio_button_remove,
         radio_button_set_fade,
         radio_button_method,
         radio_button_toolbox_event,
         radio_button_mouse_click,
         radio_button_key_pressed,
         radio_button_user_message,
         radio_button_redraw,
         radio_button_set_focus,
         NULL,
         RadioButtonValidFlags
        },

        {display_field_add,
         display_field_remove,
         display_field_set_fade,
         display_field_method,
         display_field_toolbox_event,
         display_field_mouse_click,
         display_field_key_pressed,
         display_field_user_message,
         display_field_redraw,
         display_field_set_focus,
         NULL,
         DisplayFieldValidFlags
        },

        {writable_field_add,
         writable_field_remove,
         writable_field_set_fade,
         writable_field_method,
         writable_field_toolbox_event,
         writable_field_mouse_click,
         writable_field_key_pressed,
         writable_field_user_message,
         writable_field_redraw,
         writable_field_set_focus,
         NULL,
         WritableFieldValidFlags
        },

        {slider_add,
         slider_remove,
         slider_set_fade,
         slider_method,
         slider_toolbox_event,
         slider_mouse_click,
         slider_key_pressed,
         slider_user_message,
         slider_redraw,
         slider_set_focus,
         slider_move,
         SliderValidFlags
        },

        {draggable_add,
         draggable_remove,
         draggable_set_fade,
         draggable_method,
         draggable_toolbox_event,
         draggable_mouse_click,
         draggable_key_pressed,
         draggable_user_message,
         draggable_redraw,
         draggable_set_focus,
         NULL,
         DraggableValidFlags
        },

        {popup_menu_add,
         popup_menu_remove,
         popup_menu_set_fade,
         popup_menu_method,
         popup_menu_toolbox_event,
         popup_menu_mouse_click,
         popup_menu_key_pressed,
         popup_menu_user_message,
         popup_menu_redraw,
         popup_menu_set_focus,
         NULL,
         PopupMenuValidFlags
        },

        {adjuster_add,
         adjuster_remove,
         adjuster_set_fade,
         adjuster_method,
         adjuster_toolbox_event,
         adjuster_mouse_click,
         adjuster_key_pressed,
         adjuster_user_message,
         adjuster_redraw,
         adjuster_set_focus,
         NULL,
         AdjusterValidFlags
        },

        {number_range_add,
         number_range_remove,
         number_range_set_fade,
         number_range_method,
         number_range_toolbox_event,
         number_range_mouse_click,
         number_range_key_pressed,
         number_range_user_message,
         number_range_redraw,
         number_range_set_focus,
         number_range_move,
         NumberRangeValidFlags
        },

        {string_set_add,
         string_set_remove,
         string_set_set_fade,
         string_set_method,
         string_set_toolbox_event,
         string_set_mouse_click,
         string_set_key_pressed,
         string_set_user_message,
         string_set_redraw,
         string_set_set_focus,
         string_set_move,
         StringSetValidFlags
        },

        {button_add,
         button_remove,
         button_set_fade,
         button_method,
         button_toolbox_event,
         button_mouse_click,
         button_key_pressed,
         button_user_message,
         button_redraw,
         button_set_focus,
         NULL,
         ButtonValidFlags
        }
};


typedef struct ghan {
  struct ghan *next;
  int type;
  int validflags;
  int SWIno;
  union {
  int mask;
  struct {int add:2,
      remove:2,
      postadd:2,
      method:2,
      tbevent:2,
      mclick:2,
      kpress:2,
      message:2,
      plot:2,
      setfocus:2,
      move:2,
      fade:2,
      windowappearing:2;
    }bits;
  } features;
} GadgetHandler;


#define NO_HANDLER      0
#define DEFAULT_HANDLER 1
#define PRIVATE_HANDLER 2
#define ACORN_HANDLER   3

static GadgetHandler *ExternalHandlers=NULL;

#define INTERNAL_GADGET ((GadgetHandler *) -1)
#define BAD_FLAGS ((GadgetHandler *) -2)
#define BAD_GADGET ((GadgetHandler *) -3)

/*
 * gadgets_check_external(GadgetHeader,field)
 * checks given gadget to see if it is listed on gadgets extension list
 * if it isn't then -1 is returned. If it is, but the handler is an Acorn
 * one, then -1 is also returned.
 */

#if debugging
static char Handler_Strings[][20] = {"No handler","Default handler","Private handler","Acorn handler"};
#define Debug_Handler(a,b) debug_output("gadgets++","%s for %s, type %x\n",Handler_Strings[b],a,list->type);
#else
#define Debug_Handler(a,b) ((void) 0)
#endif

static GadgetHandler * gadgets_check_external(GadgetHeader *ghdr,int field)
{
   GadgetHandler *list = ExternalHandlers;
   while (list) {
      if ((list->type & 0xffff) == (ghdr->type & 0xffff)) {
         switch (field) {
           case GADGET_ADD:
             DEBUG Debug_Handler("Gadget_Add",list->features.bits.add);
             if (list->features.bits.add == ACORN_HANDLER) goto end_check;
             if ((~(list->validflags)) & (ghdr->flags)) return BAD_FLAGS;
             break;
           case GADGET_REMOVE:
             DEBUG Debug_Handler("Gadget_Remove",list->features.bits.remove);
             if (list->features.bits.remove == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_FADE:
             DEBUG Debug_Handler("Gadget_Fade",list->features.bits.fade);
             if (list->features.bits.fade == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_METHOD:
             DEBUG Debug_Handler("Gadget_Method",list->features.bits.method);
             if (list->features.bits.method == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_TBEVENT:
             DEBUG Debug_Handler("Gadget_TBEvent",list->features.bits.tbevent);
             if (list->features.bits.tbevent == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_MCLICK:
             DEBUG Debug_Handler("Gadget_MClick",list->features.bits.mclick);
             if (list->features.bits.mclick == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_KPRESSED:
             DEBUG Debug_Handler("Gadget_KPressed",list->features.bits.kpress);
             if (list->features.bits.kpress == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_MESSAGE:
             DEBUG Debug_Handler("Gadget_Message",list->features.bits.message);
             if (list->features.bits.message == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_PLOT:
             DEBUG Debug_Handler("Gadget_Plot",list->features.bits.plot);
             if (list->features.bits.plot == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_SETFOCUS:
             DEBUG Debug_Handler("Gadget_SetFocus",list->features.bits.setfocus);
             if (list->features.bits.setfocus == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_MOVE:
             DEBUG Debug_Handler("Gadget_Move",list->features.bits.move);
             if (list->features.bits.move == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_POSTADD:
             DEBUG Debug_Handler("Gadget_PostAdd",list->features.bits.postadd);
             if (list->features.bits.postadd == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           case GADGET_WINDOWAPPEARING:
             DEBUG Debug_Handler("Gadget_WindowAppearing",list->features.bits.windowappearing);
             if (list->features.bits.windowappearing == ACORN_HANDLER) return INTERNAL_GADGET;
             break;
           default:
             break;
         }
         return list;
      }
      list = list->next;
   }

   if (((((ghdr->type & 0xffff) - Gadget_Max) / 64) > MAX_GADGET_CODE) || ((ghdr->type & 0xffff) < Gadget_Max))
      return BAD_GADGET;

end_check:

   if (field == GADGET_ADD && (ghdr->flags & (~(entry_points[((ghdr->type & 0xffff) - Gadget_Max) / 64].ValidFlags))))
      return BAD_FLAGS;

   return INTERNAL_GADGET;
}

static GadgetInternal *gadgets__find_gadget (ComponentID component_id, WindowInternal *w)
{
    GadgetInternal *g = w->gadgets;

    while (g != NULL)
    {
        if (g->gadget_hdr.component_id == component_id)
            break;

        g = g->next;
    }

    return g;
}

_kernel_oserror *gadgets__redraw_gadget (int window_handle, GadgetHeader *ghdr)
{
    wimp_GetWindowState state;
    _kernel_oserror    *e;

    state.open.window_handle = window_handle;

    if (SWI_WimpCreateIcon == Wimp_PlotIcon) return NULL; /* don't want to wipe our nice gadget! */

    if ((e = wimp_get_window_state (&state)) != NULL) return e;

    if (state.flags & wimp_WINDOWFLAGS_OPEN)
        redraw_window(window_handle,(wimp_Bbox *) &(ghdr->xmin));

    return NULL;
}

static _kernel_oserror *gadgets__get_icon_list (WindowInternal *w, GadgetInternal *g, int *buffer, int *buffer_size)
{
    /*
     * Function to return the icon list which implements a gadget.  We go through
     * the icon mapping list looking for this gadget, and fill in the client's
     * buffer (if non-null)
     */

    int nicons = 0;
    int i;

    for (i = 0; i < w->num_icon_mappings; i++)
    {
        if (w->icon_mappings[i] == g)
        {
            if ( buffer)
            {
                if ( nicons*sizeof(int) >= *buffer_size)	break;
                buffer[ nicons] = i;
                nicons++;
            }

            else	nicons++;
        /*
            nicons++;
            if (buffer != NULL)
            {
                if (nicons*sizeof(int) > *buffer_size)
                {
                    nicons--;
                    break;
                }
                else
                    buffer[nicons-1] = i;
            }
        */
        }
    }

    //if (buffer_size != NULL)
        *buffer_size = nicons*sizeof(int);

    return NULL;
}



_kernel_oserror *gadgets__get_icon_list2 ( _kernel_swi_regs* r)
{
   WindowInternal*	window;
   GadgetInternal*	gadget;
   window	= window_from_wimp_window( r->r[1]);
   if ( !window)
   {
       r->r[4] = -1;
       return NULL;
   }

   gadget	= gadgets__find_gadget( r->r[2], window);

   if ( !gadget)	return invalid_component (r->r[2]);

   return gadgets__get_icon_list( window, gadget, (int*) r->r[3], &r->r[4]);
}



static _kernel_oserror *dispatch_external(GadgetHandler *list,_kernel_swi_regs *regs)
{
   _kernel_oserror *er;
   int temp;

   temp = list->features.mask;
   list->features.mask = -1;            /* so that it can call the next in the chain */
   er = _kernel_swi(list->SWIno,regs,regs);
   if (er && (er->errnum == ErrorNumber_NoSuchSWI)) {
      /* if the SWI doesn't exist, then deregister to prevent further calls */
      _kernel_swi_regs r;
      r.r[0] = 0;
      r.r[1] = list->type;
      r.r[2] = list->SWIno;
      gadgets_deregister_external(&r);
      return er;

   }
   list->features.mask = temp;
   return er;

}

static _kernel_oserror *gadgets_focus_external(GadgetHandler *list,GadgetInternal *g,int wimp, int dir)
{
   _kernel_swi_regs regs;

   IGNORE(wimp);

   if (list->features.bits.setfocus == PRIVATE_HANDLER) {
      regs.r[0] = dir ? 1:0;
      regs.r[1] = g->gadget_hdr.type;
      regs.r[2] = GADGET_SETFOCUS;
      regs.r[3] = (int) g->data;
      return dispatch_external(list,&regs);
   }
   return NULL;
}

extern _kernel_oserror *gadgets_set_focus (GadgetInternal *g, int window_handle, int direction)
{
  _kernel_oserror *e = NULL ;
  GadgetHandler *list;

  DEBUG debug_output ("gadgets_focus", "gadgets_set_focus\n\r") ;

  if ((list = gadgets_check_external(&(g->gadget_hdr),GADGET_SETFOCUS)) != INTERNAL_GADGET)
        return gadgets_focus_external(list,g,window_handle,direction);

  if (entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].set_focus != NULL)
    e = entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].set_focus (g, window_handle, direction) ;

  return e ;
}


static _kernel_oserror *gadgets_add_external(GadgetHandler *list,GadgetInternal *g,
                        ObjectID id, int **icons, Gadget *gt,int wimp)
{
   _kernel_swi_regs regs;
   _kernel_oserror *e;

   if (list->features.bits.add != PRIVATE_HANDLER) return NULL;

   regs.r[0] = 0;
   regs.r[1] = list->type;
   regs.r[2] = GADGET_ADD;
   regs.r[3] = (int) gt;
   regs.r[4] = (int) id;
   regs.r[5] = (int) wimp;

   e = dispatch_external(list,&regs);
   if (e) return e;

   g->data = (void *) regs.r[0];
   *icons = (int *) regs.r[1];

   return NULL;
}

static _kernel_oserror *gadgets_postadd_external(GadgetHandler *list,GadgetInternal *g,
                        ObjectID id, int **icons, Gadget *gt,int wimp)
{
   _kernel_swi_regs regs;
   _kernel_oserror *e;

   IGNORE(gt);

   if (list->features.bits.postadd != PRIVATE_HANDLER) return NULL;

   regs.r[0] = 0;
   regs.r[1] = list->type;
   regs.r[2] = GADGET_POSTADD;
   regs.r[3] = (int) g->data;
   regs.r[4] = (int) id;
   regs.r[5] = (int) wimp;
   regs.r[6] = (int) *icons;

   e = dispatch_external(list,&regs);
   return e;

}

static _kernel_oserror *gadgets_fade_external(GadgetHandler *list,GadgetInternal *g,
                        ObjectID id,int fade)
{
   _kernel_swi_regs regs;
   _kernel_oserror *e;

   if (list->features.bits.fade != PRIVATE_HANDLER) return NULL;

   regs.r[0] = 0;
   regs.r[1] = list->type;
   regs.r[2] = GADGET_FADE;
   regs.r[3] = (int) g->data;
   regs.r[4] = fade;
   regs.r[5] = (int) id;

   e = dispatch_external(list,&regs);
   return e;

}

static _kernel_oserror *gadgets_remove_external(GadgetHandler *list,GadgetInternal *g,WindowInternal *w,int recurse)
{
   _kernel_swi_regs regs;

   if (list->features.bits.remove == DEFAULT_HANDLER) return simple_remove(g,w->id,0);
   if (list->features.bits.remove == PRIVATE_HANDLER) {
      regs.r[0] = recurse;
      regs.r[1] = list->type;
      regs.r[2] = GADGET_REMOVE;
      regs.r[3] = (int) g->data;
      return dispatch_external(list,&regs);
   }
   return NULL;
}

typedef struct {
  int type;
  int validflags;
  int mask;
} GadgetExtensionRecord;

_kernel_oserror *gadgets_register_external(_kernel_swi_regs *regs)
{
   GadgetHandler *new;
   _kernel_swi_regs r;
   GadgetExtensionRecord *input = (GadgetExtensionRecord *) regs->r[1];

   r.r[1] = Service_GadgetRegistered;

   if (regs->r[0]) return bad_flags(Window_RegisterExternal,regs->r[0]);
   while (input->type != -1) {
      new = mem_allocate (sizeof(GadgetHandler),"New gadget type");
      if (!new) return out_of_memory();
      new->type = input->type;
      new->validflags = input->validflags;
      new->features.mask = input->mask;
      DEBUG debug_output("gadgets++","Adding external for type %x with mask %x\n",input->type,input->mask);
      new->SWIno = regs->r[2];
      new->next = ExternalHandlers;
      ExternalHandlers = new;
      r.r[0] = new->type;
      r.r[2] = new->SWIno;
      r.r[3] = new->features.mask;
      _kernel_swi(OS_ServiceCall,&r,&r);

      input++;
   }
   return NULL;
}

_kernel_oserror *gadgets_deregister_external(_kernel_swi_regs *regs)
{
   _kernel_swi_regs r;
   GadgetHandler *prev=NULL,*list = ExternalHandlers;

   if (regs->r[0]) return bad_flags(Window_DeregisterExternal,regs->r[0]);

   while (list) {
      if ((list->type == regs->r[1]) && (list->SWIno == regs->r[2])) {
         r.r[0] = regs->r[1];
         r.r[1] = Service_GadgetDeregistered;
         r.r[2] = regs->r[2];
         _kernel_swi(OS_ServiceCall,&r,&r);
         DEBUG debug_output("gadgets++","Removing external for type %x\n",list->type);
         if (list == ExternalHandlers) ExternalHandlers = list->next;
         else prev->next = list->next;
         return NULL;
      }
      prev=list;
      list = list->next;
   }
   return make_error_hex (Window_InvalidGadgetType, 1, regs->r[1]);
}

_kernel_oserror *gadgets_support_external(_kernel_swi_regs *regs)
{

   switch (regs->r[1]) {
      case 0:
      {
         int t;
         wimp_IconCreate i = *(wimp_IconCreate *) regs->r[2];
         if(CreateIcon(i,&t)) t =-1;
         regs->r[0] = t;
         break;
      }
      case 1:
      {
         break;
      }
      case 2:
      {
         if (regs->r[0] & 1) {
             if (CreateObjectFromMemory((void *)regs->r[2],(ObjectID *) &(regs->r[0]))) regs->r[0] =0;
         } else {
             if (CreateObjectFromTemplate((char *)regs->r[2],(ObjectID *) &(regs->r[0]))) regs->r[0] =0;
         }
         break;
      }
      case 3:
      {
         CreateSubGadget((ObjectID) regs->r[2], (Gadget *) regs->r[3], (ComponentID *) &(regs->r[0]),regs->r[4]);
         break;
      }
      case 4:
      {
         regs->r[0] = (int) mem_allocate(regs->r[2],"External gadget claim");
         break;
      }
      case 5:
      {
         mem_free((void *) regs->r[2],"External gadget free");
         break;
      }
      case 6:
      {
         regs->r[0] = (int) mem_extend((void *) regs->r[2],regs->r[3]);
         break;
      }

   }
   return NULL;
}

extern _kernel_oserror *gadgets_add (Gadget *gt, WindowInternal *w, ComponentID *gadget_id)
{
    /*
     * Function to add a new gadget to a Toolbox Window.
     * This just creates a new element in the list of gadgets, fills in the
     * generic header information from the gadget "template", and then
     * calls the appropriate "gadget creator" function for a gadget of this
     * type, to create the block which is attached to "data", and to extend
     * the icon list for this Window.  Note that the creator function must
     * also fix up any indirected data pointers in the gadget which has
     * now been created from the gadget "template".
     * Note that "r" is the Toolbox's register set (user regs pointed at
     * by r4).
     */

    _kernel_oserror    *e  = NULL;
    GadgetInternal     *g;
    int                *icon_list = NULL;
    _kernel_swi_regs    regs;
    wimp_GetWindowInfo  info;
    GadgetInternal    **new_icon_mappings = NULL;
    int                 i;
    ComponentID         max=0;
    GadgetHandler *external =0;

    CURRENT_WINDOW=w;

    DEBUG debug_output ("gadgets_add", "Adding gadget (type %d)\n", gt->hdr.type);

    /*
     * check validity of gadget type code
     */

    external = gadgets_check_external(&(gt->hdr),GADGET_ADD);
    if (external == BAD_FLAGS) {
       if (gt->hdr.type == Button_Type) {
          extern void create_extras(Gadget *g, WindowInternal *w);
          create_extras(gt, w);
          return 0;
       }
       return make_error_hex (Window_InvalidFlags,1,gt->hdr.type & 0xffff);
    }
    if (external == BAD_GADGET)
       return make_error_hex (Window_InvalidGadgetType, 1, gt->hdr.type);

    GlobalIconFlags = 0;
    if (((WIMP_VERSION_NUMBER >= 350) || (SWI_WimpCreateIcon == Wimp_PlotIcon))
        && (gt->hdr.flags & Gadget_Faded))
       GlobalIconFlags =  wimp_ICONFLAGS_FADED;

    /*
     * check for duplicate id's
     */

    if (w->gadgets != NULL)
    {
        g = w->gadgets;

        while (g != NULL)
        {
            if (g->gadget_hdr.component_id == gt->hdr.component_id)
                return make_error_hex (Window_DuplicateComponentID, 1, gt->hdr.component_id);
            if (g->gadget_hdr.component_id < 0x1000000 && g->gadget_hdr.component_id >= max) max = g->gadget_hdr.component_id+1;
            g = g->next;
        }
    }

    /*
     * create a new gadget internal data structure.
     */

    if ((g = mem_allocate (sizeof(GadgetInternal), "gadget internal block")) == 0)
        return out_of_memory();


    /*
     * Now take a copy of the "template" header for the gadget. Note that we just
     * take a copy of the header, and rely on the creator function to do the
     * rest.  We take a copy of the help message for this gadget too.
     */

    g->gadget_hdr = gt->hdr;
    if (g->gadget_hdr.component_id == -1) g->gadget_hdr.component_id =max;

    /* make way for 'unknown' gadgets */

    g->gadget_hdr.type = g->gadget_hdr.type & 0xffff;

    if (gt->hdr.help_message != NULL)
    {
        if ((g->gadget_hdr.help_message = mem_allocate (g->gadget_hdr.max_help, "gadget help")) == NULL)
        {
            e = out_of_memory();
            goto error;
        }
        string_copy (g->gadget_hdr.help_message, gt->hdr.help_message);
    }


    /*
     * Now call the appropriate creator function for this gadget type
     */

    DEBUG debug_output ("gadgets_add", "Calling gadget add function\n");

    if (external == INTERNAL_GADGET) {
        if (entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].add != NULL)
            if ((e = entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].add
                (g, w->id, &icon_list, gt, w->wimp_window_handle)) != NULL)
               goto error;
    } else {
        /* SJM/EPW: 28/06/96: Bug fix. If toolbox allocates component id then external
         * gadget handler needs to be told what it is.
         * So copy of gadget is taken so that id can be poked in.
         */
        Gadget *gcopy = mem_allocate(gt->hdr.type >> 16, "gadget copy");
        if (gcopy == NULL)
        {
            e = out_of_memory();
            goto error;
        }

        memcpy(gcopy, gt, gt->hdr.type >> 16);
        gcopy->hdr.component_id = g->gadget_hdr.component_id;

        e = gadgets_add_external(external,g, w->id, &icon_list, gcopy, w->wimp_window_handle);

        mem_free(gcopy, "gadget copy");

        if (e)
           goto error;
    }


    DEBUG debug_output ("gadgets_add", "Returned from gadget add function\n");

    /*
     * The creator function has filled in the "icon_list", which is a -1 terminated list
     * of icon numbers making up this gadget.  We use this to update the icon_mappings for
     * the parent window, so that, for example, clicks on the icons are dispatched to the
     * correct gadget functions.
     * Icons have been created now, so we can create a new icon mapping array, and copy in
     * the new enries which have come from the creator function.
     */

    if (SWI_WimpCreateIcon == Wimp_PlotIcon) info.window.nicons=0;
    else {

       if ((external = gadgets_check_external(&(g->gadget_hdr),GADGET_POSTADD)) != INTERNAL_GADGET) {
           if ((e = gadgets_postadd_external(external,g, w->id, &icon_list, gt, w->wimp_window_handle)) !=NULL) return e;
       }

       info.window_handle = w->wimp_window_handle;
       regs.r[1] = (int) ((int) (&info) | 0x00000001);       /* get window header only */

       if ((e = _kernel_swi (Wimp_GetWindowInfo, &regs, &regs)) != NULL)
          goto error;

       DEBUG debug_output ("gadgets_add", "Returned from get window info\n");

       /* new icon mapping array */

   /*    if (info.window.nicons != w->num_icon_mappings)   */
       {
          if ((new_icon_mappings = mem_allocate (info.window.nicons*sizeof(GadgetInternal*), "icon mappings")) == NULL)
          {
              e = out_of_memory();
              goto error;
          }

          DEBUG debug_output ("gadgets_add", "alloc'ed space for %d icons\n", info.window.nicons);

          /* copy old icon mappings */

          for (i = 0; i < info.window.nicons; i++)
         {
           if (i < w->num_icon_mappings)
               new_icon_mappings[i] = w->icon_mappings[i];
           else
               new_icon_mappings[i] = NULL;
         }

         DEBUG debug_output ("gadgets_add", "copied old mappings\n");

         /* fill in new mappings for new gadget */

         i = 0;

         if(icon_list) {
           DEBUG debug_output ("gadgets_add", "copying new mappings %d ...\n",icon_list[0]);
         }

         while ((icon_list != NULL) && (icon_list[i] != -1))
         {
           if (icon_list[i] < info.window.nicons)
               new_icon_mappings[icon_list[i]] = g;

           i++;
         }

         w->num_icon_mappings = info.window.nicons;

         /* swap over to new icon mappings */

         if (w->icon_mappings != NULL)
           mem_free (w->icon_mappings, "freeing old icon mappings");

         w->icon_mappings = new_icon_mappings;
       }
    }

    /*
     * ... and add to head of list.
     */

    g->prev    = NULL;
    g->next    = w->gadgets;
    if (w->gadgets != NULL)
        w->gadgets->prev = g;
    w->gadgets = g;

    w->num_gadgets++;

    /*
     * force a redraw on the window, for the gadget's bounding box, cos the
     * Wimp doesn't do this for us.  First check the Window is open!
     */

    if ((WIMP_VERSION_NUMBER < 350) &&
        (gt->hdr.flags & Gadget_Faded) && (SWI_WimpCreateIcon == Wimp_CreateIcon)) {
           WIMP_WINDOW = w->wimp_window_handle;
           gadgets__set_fade(g,w->id,1);
    }

    if ((info.window.flags & wimp_WINDOWFLAGS_OPEN) && (e = gadgets__redraw_gadget (w->wimp_window_handle, &g->gadget_hdr)) != NULL)
        goto error;


    /*
     * return component id of gadget
     */

    *gadget_id = g->gadget_hdr.component_id;

    /*
     * Bit of debugging output: Does the icon mapping stuff really work?
     */

    DEBUG
    {
      for (i = 0; i < info.window.nicons; i++)
      {
        if (w->icon_mappings[i]) {
           debug_output ("mapping", "Icon %d mapped to gadget of type %d\n\r",
            i, w->icon_mappings[i]->gadget_hdr.type) ; }
        else {
           debug_output ("mapping", "Icon %d not mapped to any gadget\n\r",i); }
      }
    }

    return NULL;


error:
    DEBUG debug_output ("gadgets_add", "gadgets_add error:%s\n", e->errmess);

    if (g->gadget_hdr.help_message != NULL)
        mem_free (g->gadget_hdr.help_message, "error while adding gadget");

    if (new_icon_mappings != NULL)
        mem_free (new_icon_mappings, "error while adding gadget");

    mem_free (g, "error while adding gadget");

    return e;
}



extern _kernel_oserror *gadgets_remove (ComponentID gadget_id, WindowInternal *w,int recurse)
{
    /*
     * Function to remove a gadget from a Toolbox Window
     * This removes the element from the list of gadgets, and calls the
     * "gadget remover" for this gadget to get rid of the block pointed
     * at by "data".  It also "forgets" the mappings from the gadget's
     * icon numbers to the gadget.
     */

    _kernel_oserror *e;
    GadgetInternal  *g;
    int              i;
    GadgetHandler *ext;

    /*
     * find the gadget with the specified component id.
     */

    CURRENT_WINDOW=w;

    DEBUG debug_output ("gadgets_remove", "gadgets_remove id:%d\n", gadget_id);

    if ((g = gadgets__find_gadget (gadget_id, w)) == NULL)
        return invalid_component (gadget_id);


    /* set the window */

    WIMP_WINDOW=w->wimp_window_handle;

    /*
     * Call the remover function for this gadget type, and then
     * remove the block which was copied from the gadget template.
     */

    if ((ext = gadgets_check_external(&(g->gadget_hdr),GADGET_REMOVE)) != INTERNAL_GADGET) {
        if ((e = gadgets_remove_external(ext,g, w,recurse)) !=NULL) return e;
    }
    else {
        if (entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].remove != NULL)
           if ((e = entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].remove (g, w->id,recurse)) != NULL)
               return e;
    }


    /*
     * "Forget" the icons which formed part of this gadget
     */

    if (w->icon_mappings != NULL)
    {
        for (i = 0; i < w->num_icon_mappings; i++)
        {
            if (w->icon_mappings[i] == g)
                w->icon_mappings[i] = NULL;
        }
    }


    /*
     * force a redraw on the window, for the gadget's bounding box, cos the
     * Wimp doesn't do this for us.  First check the Window is open!
     */

    if ((e = gadgets__redraw_gadget (w->wimp_window_handle, &g->gadget_hdr)) != NULL)
       return e;


    /*
     * ... and remove the item from the list of gadgets
     */

    if (g == w->gadgets)
        w->gadgets = g->next;
    else
        g->prev->next = g->next;
    if (g->next != NULL)
        g->next->prev = g->prev;


    if (g->gadget_hdr.help_message != NULL)
        mem_free (g->gadget_hdr.help_message, "freeing gadget's help message");

    mem_free (g, "freeing gadget");


    w->num_gadgets--;

    return NULL;
}



extern void gadgets_remove_all (WindowInternal *w,int recurse)
{
    /*
     * Function to remove all gadgets from a window
     */

    GadgetInternal *last = NULL;

    while (w->gadgets && (w->gadgets != last) && (w->num_gadgets>0))
    {
        last = w->gadgets;
        gadgets_remove (w->gadgets->gadget_hdr.component_id, w, recurse);
    }
}

static _kernel_oserror *gadgets__set_fade(GadgetInternal *g, ObjectID window, unsigned int do_fade)
{
    GadgetHandler *ext;
    DEBUG debug_output ("method", "gadgets_method: decided to call fade method if it exists\n\r") ;

    if ((ext = gadgets_check_external(&(g->gadget_hdr),GADGET_FADE)) != INTERNAL_GADGET) {
        return gadgets_fade_external(ext,g,window,do_fade);
    }
    if (entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].fade != NULL)
    {
        DEBUG debug_output ("method", "gadgets_method: calling fade method\n\r") ;
        return ( entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].fade (g, window, do_fade));
    }
    else return NULL;
}

extern _kernel_oserror *gadgets_set_fade(ComponentID id, unsigned int do_fade)
{
    GadgetInternal *g;

    if ((g = gadgets__find_gadget (id, CURRENT_WINDOW)) == NULL)
    {
        DEBUG debug_output ("method", "gadgets_method: Invalid Component ID\n\r") ;
        return invalid_component (id);
    }
    return gadgets__set_fade(g,CURRENT_WINDOW ->id,do_fade);
}

static _kernel_oserror *gadgets_method_external(GadgetHandler *list,GadgetInternal *g,
                         _kernel_swi_regs *r)
{
   _kernel_swi_regs regs;
   _kernel_oserror *e;

   if (list->features.bits.method != PRIVATE_HANDLER) return NULL;

   regs.r[0] = 0;
   regs.r[1] = list->type;
   regs.r[2] = GADGET_METHOD;
   regs.r[3] = (int) g->data;
   regs.r[4] = (int) USER_REGS(r);

   e = dispatch_external(list,&regs);
   return e;

}


static _kernel_oserror *gadgets_call_method_entry(GadgetInternal *g, _kernel_swi_regs *r, WindowInternal *w)
{
       GadgetHandler *ext;
       _kernel_oserror *e = NULL;

       DEBUG debug_output("method", "calling gadget method entry for reason code %d (%#x)\n\r",
       	((_kernel_swi_regs *)r->r[4])->r[2], ((_kernel_swi_regs *)r->r[4])->r[2]);

       if ((ext = gadgets_check_external(&(g->gadget_hdr),GADGET_METHOD)) != INTERNAL_GADGET) {
           if ((e = gadgets_method_external(ext,g,r)) !=NULL) return e;
       }
       else {
           if (entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].method != NULL)
               e = entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].method (g, w->id, r);
       }

       return e;
}


extern _kernel_oserror *gadgets_method (_kernel_swi_regs *r, WindowInternal *w)
{
    /*
     * Function to dispatch a method which is for a given gadget type.
     * The WindowInternal structure has been found, from the SWI's input
     * register R2 (Window's ObjectID). "r" is the Toolbox's register set.
     *
     * This function deals with any generic methods, and passes others on to
     * the appropriate method function for the gadget type.
     * Methods 64-127 are reserved as generic gadget methods.
     */

    _kernel_oserror  *e         = NULL;
    _kernel_swi_regs *user_regs = USER_REGS(r);
    int               method    = user_regs->r[2]; /* Was one, Ian! */
    ComponentID       gadget_id = (ComponentID) user_regs->r[3];
    GadgetInternal   *g;


    DEBUG debug_output ("method", "gadgets_method: entry, method number %#x component number %#x\n\r", method, gadget_id) ;

    /*
     * validate gadget component ID
     */

    if ((g = gadgets__find_gadget (gadget_id, w)) == NULL)
    {
        DEBUG debug_output ("method", "gadgets_method: Invalid Component ID\n\r") ;
        return invalid_component ( gadget_id);
    }


    /*
     * If generic gadget method, we handle it, else we check validity, and pass
     * on to gadget-specific handler.
     */

    WIMP_WINDOW=w->wimp_window_handle;
    CURRENT_WINDOW = w;

    if (method == Gadget_SetHelpMessage)
    {
        /* sbrodie: 23/11/98: this method must be propagated to all the sub-gadgets in a
         * composite gadget.  To this end, this method is treated as a gadget-specific
         * method from which errors are allowed to occur and are discarded if they happen
         * to be Window_NoSuchMiscOpMethod.
         */
        GadgetHeader *hdr = &g->gadget_hdr;
        char *help_message = (char *) user_regs->r[4];

	DEBUG debug_output("method", "attempting to set help text\n");

        if (hdr->help_message == NULL)
            e =  buffer_too_short();
        else if (help_message == NULL)
            /* sbrodie: This is clearly daft as once you unset the help message, you
             * cannot get one back again. I've left it as is, but I *have* insisted on
             * adding protection to stop those subsequent attempts from blatting zero
             * page.  Ho hum.
             */
            hdr->help_message = NULL;
        else if (string_length (help_message)+1 > hdr->max_help)
            e =  buffer_too_short();
        else
            string_copy (hdr->help_message, help_message);
        if (e == NULL)
        {
            e = gadgets_call_method_entry(g, r, w);
            /* Ignore No such method errors */
            if (e != NULL && e->errnum == Window_NoSuchMiscOpMethod) e = NULL;
        }
    }
    else
    if (method >= Gadget_Base && method <= Gadget_Max)
    {
        GadgetHeader *hdr = &g->gadget_hdr;

        DEBUG debug_output ("method", "gadgets_method: It's a generic gadget method\n\r") ;

        switch (method)
        {
            case Gadget_GetFlags:
                user_regs->r[0] = hdr->flags;
                break;

            case Gadget_SetFlags:
                /* first check to see if faded bit is being changed */
                /* Should be looking at r0 dammit, r4 is slightly silly. */
                DEBUG debug_output ("method", "gadgets_method: SetFlags method called r4 = %d\n\r",
                        user_regs->r[4]) ;
                if ((user_regs->r[4] & Gadget_Faded) ^ (hdr->flags & Gadget_Faded))
                        gadgets__set_fade(g,w->id,user_regs->r[4] & Gadget_Faded);

                /* only allow the setting of top flags */

                hdr->flags = (hdr->flags & 0xffffff) | (user_regs->r[4] & 0xff000000U);
                break;

            case Gadget_SetHelpMessage:
                /* No longer reached - this method is handled specially */
                break;

            case Gadget_GetHelpMessage:
                string_to_buffer ((char *)user_regs->r[4], hdr->help_message, &user_regs->r[5]);
                break;

            case Gadget_GetIconList:
                e = gadgets__get_icon_list (w, g, (int *)user_regs->r[4], &user_regs->r[5]);
                break;

            case Gadget_SetFocus:
                e = gadgets_set_focus (g, w->wimp_window_handle, user_regs->r[0] & 1) ;
                break;

            case Gadget_MoveGadget:
                e = gadgets_move_gadget (w, g, (wimp_Bbox *)user_regs->r[4]) ;
                break;
            case Gadget_GetType:
                user_regs->r[0] = g->gadget_hdr.type;
                break;
            case Gadget_GetBBox:
                memcpy ((int *) user_regs->r[4] , &g->gadget_hdr.xmin, sizeof(wimp_Bbox));
                break;
            default:
                break;
        }
    }
    else {

       DEBUG debug_output ("method", "gadgets_method: It's a gadget specific method\n\r") ;
       e = gadgets_call_method_entry(g, r, w);

    }


    return e;
}



extern _kernel_oserror *gadgets_toolbox_event (WindowInternal *w, ToolboxEvent *event, IDBlock *id_block)
{
    /*
     * Function to dispatch a toolbox event delivered on a window,gadget pair.
     * We call all gadget functions.
     */

    _kernel_oserror *e = NULL;
    GadgetInternal  *g;

    g = w->gadgets;

    while (g != NULL)
    {
        if ((g->gadget_hdr.type <= (64 * MAX_GADGET_CODE + Gadget_Max)) &&
             (entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].toolbox_event != NULL))
            if ((e = entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].toolbox_event
                                (g, event, id_block->self_component, id_block->self_id)) != NULL)
                goto end;

        g = g->next;
    }

end:
    return e;
}

extern int gadgets_help_message (WindowInternal *w, wimp_PollBlock *poll_block, IDBlock *id_block)
{
    IGNORE(id_block);

    if (poll_block->msg.data.help_request.icon_handle <= w->num_icon_mappings && poll_block->msg.data.help_request.icon_handle >=0)
    {
        GadgetInternal *g = w->icon_mappings[poll_block->msg.data.help_request.icon_handle];

        if (g->gadget_hdr.help_message) events_send_help(g->gadget_hdr.help_message,poll_block);
        else return 0;

        return 1;
    }
    return 0;
}

static _kernel_oserror *gadgets_mouseclick_external(GadgetHandler *list,GadgetInternal *g,WindowInternal *w,
                                        wimp_PollBlock *poll_block,int *claimed)
{
   _kernel_swi_regs regs;
   _kernel_oserror *e;

   if (list->features.bits.mclick == PRIVATE_HANDLER) {
      regs.r[0] = 0;
      regs.r[1] = g->gadget_hdr.type;
      regs.r[2] = GADGET_MCLICK;
      regs.r[3] = (int) g->data;
      regs.r[4] = (int) w->id;
      regs.r[5] = w->wimp_window_handle;
      regs.r[6] = (int) poll_block;
      e =  dispatch_external(list,&regs);
      if (!e) *claimed = regs.r[1];
      return e;
   }
   return NULL;

}

extern _kernel_oserror *gadgets_mouse_click (WindowInternal *w, wimp_PollBlock *poll_block, int *claimed, IDBlock *id_block)
{
    /*
     * Function to deal with a mouse click in a Toolbox Window
     * First find the gadget corresponding to this icon
     * number, and dispatch.
     * If dealt with, then set *claimed to non-zero.
     */

    _kernel_oserror *e = NULL;
    GadgetHandler *list;

    if (poll_block->mouse_click.icon_handle < w->num_icon_mappings && poll_block->mouse_click.icon_handle >=0)
    {
        GadgetInternal *g = w->icon_mappings[poll_block->mouse_click.icon_handle];

        WIMP_WINDOW=w->wimp_window_handle;

        if (!g) return NULL;

        if ((list = gadgets_check_external(&(g->gadget_hdr),GADGET_MCLICK)) != INTERNAL_GADGET) {
            e = gadgets_mouseclick_external(list,g,w, poll_block, claimed);
        }
        else {
            if (entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].mouse_click != NULL)
               e = entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].mouse_click (g, w->id, poll_block, claimed);
        }
        if (*claimed != FALSE)
            id_block->self_component = g->gadget_hdr.component_id;
    }

    return e;
}


extern _kernel_oserror *gadgets_key_pressed (WindowInternal *w, wimp_PollBlock *poll_block, int *claimed, IDBlock *id_block)
{
    /*
     * Function to deal with a key press in a Toolbox Window.
     * Calls all functions to see if anyone is interested.
     */

    GadgetInternal  *g = w->gadgets;
    _kernel_oserror *e;

    while (g != NULL)
    {
        *claimed = FALSE;

        if ((g->gadget_hdr.type <= (64 * MAX_GADGET_CODE + Gadget_Max)) &&
                (entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].key_pressed != NULL))
            if ((e = entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].key_pressed (g, w->id, poll_block, claimed)) != NULL)
                return e;
        if (*claimed != FALSE)
           id_block->self_component = g->gadget_hdr.component_id;
        g = g->next;
    }

    *claimed = FALSE;

    return NULL;
}

static _kernel_oserror *(*drag_func)(wimp_PollBlock *poll_block)=NULL;

extern void gadgets_set_drag_function(_kernel_oserror *(*df)(wimp_PollBlock *poll_block))
{
    drag_func=df;
}

extern _kernel_oserror *gadgets_user_drag (wimp_PollBlock *poll_block)
{
    /*
     * Function to deal with end of user drag operation.
     */

    _kernel_oserror *e = NULL;

    DEBUG debug_output ("drag", "User Drag\n\r") ;

    if (drag_func) {
        e=(*drag_func)(poll_block);
        drag_func=NULL;
    }

    return e;
}


extern int gadgets_user_message (WindowInternal *w, wimp_PollBlock *poll_block, IDBlock *id_block)
{
    /*
     * Function to deal with the arrival of a "user message" (wimp_ESEND/ESEND_WANT_ACK).
     * Pass to ALL functions, 'til claimed.  If claimed, return non-zero.
     */

    GadgetInternal  *g = w->gadgets;
    _kernel_oserror *e;
    int claimed = FALSE;

    while (g != NULL)
    {
        if ((g->gadget_hdr.type <= (64 * MAX_GADGET_CODE + Gadget_Max)) &&
                (entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].user_message != NULL))
            if ((e = entry_points[(g->gadget_hdr.type - Gadget_Max) / 64].user_message (poll_block, &claimed)) != NULL)
                raise_toolbox_oserror (e, w->id, g->gadget_hdr.component_id);

        if (claimed)
            break;

        g = g->next;
    }

    if (claimed)
    {
        id_block->self_id =        w->id;
        id_block->self_component = g->gadget_hdr.component_id;
    }

    return claimed;
}

_kernel_oserror *CreateSubGadget(ObjectID window, Gadget *gadget, ComponentID *id,int mask)
{
    _kernel_oserror *e;

    IGNORE(window);

    gadget->hdr.component_id= ((CurrentId<<12) + mask);

    if ((e = gadgets_add(gadget,CURRENT_WINDOW,id)) !=NULL) return e;

    *id=((CurrentId<<12) + mask);
    CurrentId++;
    if (CurrentId >= 0x80000) CurrentId=0x1000;
    return NULL;
}


_kernel_oserror *CreateIcon (wimp_IconCreate i,int *handle)
{
        _kernel_swi_regs regs;

    i.icon.flags |= GlobalIconFlags;

    regs.r[0] = 0;
    regs.r[1] = (int) &i;
    regs.r[4] =0;               /* bug in PlotIcon */
    regs.r[5] =0;

    DEBUG debug_output ("CreateIcon", "Creating icon (%d,%d)-(%d,%d)\n",i.icon.bbox.xmin,
                        i.icon.bbox.ymin,i.icon.bbox.xmax,i.icon.bbox.ymax);

    if (SWI_WimpCreateIcon == Wimp_PlotIcon)
       {

#ifdef MUNGE_PLOT

       if (PlotGadgetOptions & 1) {
          i.icon.flags |= (wimp_ICONFLAGS_INVERT | wimp_ICONFLAGS_FILLED);
       }
       if (PlotGadgetOptions & 2) {
          if (i.icon.flags & wimp_ICONFLAGS_ANTI_ALIASED) {}
          else {
             static char cmap[] = { 2,3,4,5,6,7,8,11,3,1,1,3,1,3,1,1};

             unsigned int bc= i.icon.flags & (wimp_ICONFLAGS_BACKCOL * 15U);
             unsigned int fc= i.icon.flags & (wimp_ICONFLAGS_FORECOL * 15U);
             i.icon.flags &= ~(15 * (wimp_ICONFLAGS_BACKCOL | wimp_ICONFLAGS_FORECOL));
             bc = wimp_ICONFLAGS_BACKCOL * (cmap [bc/wimp_ICONFLAGS_BACKCOL]);
             fc = wimp_ICONFLAGS_FORECOL * (cmap [fc/wimp_ICONFLAGS_FORECOL]);
             i.icon.flags |= (bc | fc);
          }
       }
#endif

       regs.r[1] = (int) &(i.icon);

    } /* move beyond window handle */

    if ((last_create_icon_error = _kernel_swi (SWI_WimpCreateIcon, &regs, &regs)) != NULL) return last_create_icon_error;

    if (SWI_WimpCreateIcon == Wimp_CreateIcon)
       { *handle=regs.r[0]; }
    else
       { *handle=-1; }              /* this is to make PlotGadget work */

    DEBUG debug_output ("CreateIcon", "Created icon\n");

    return NULL;
}


_kernel_oserror *DeleteIcons(GadgetInternal *id,ObjectID window)
{
        _kernel_oserror *e=NULL;
        int no=0,i,buf[MAX_ICONS_FOR_GADGET],t=(sizeof (int))*MAX_ICONS_FOR_GADGET;
        int del[2];

        WindowInternal   *win       = CURRENT_WINDOW;

        if (SWI_WimpCreateIcon == Wimp_PlotIcon) return NULL;

        DEBUG debug_output ("DeleteIcons", "About to delete icons on window %d\n",window);

        e=gadgets__get_icon_list(win,id,NULL,&no);      /* returns no. of icons in gadget */
        no = (no/4);                                       /* buffer is ints */
        DEBUG debug_output ("DeleteIcons", "%d icons to delete\n",no);


        del[0] = WIMP_WINDOW;

        if (!e) {
                e=gadgets__get_icon_list(win,id,buf,&t);
                if (e) no=0;
                for (i=0;i<no;i++) {
                        _kernel_swi_regs regs;
                        int fh;

                        del[1]=buf[i];

                        DEBUG debug_output ("FreeFonts", "About to free fonts for icon%d\n", buf[i]);
                        if ((fh = get_font(WIMP_WINDOW, buf[i])) != -1)
                        {
                            TaskDescriptor *t;
                            DEBUG debug_output("DeleteIcons", "LoseFont handle %i\n",fh);
                            _swix(Font_LoseFont, _IN(0), fh);
                            t = task_find_from_window(win);
                            if (t && t->font_bindings) /* should NEVER be false */
                            {
                              int *fb=t->font_bindings;
                              fb[fh]--;
                            }
                        }

                        DEBUG debug_output ("DeleteIcons", "About to delete icon%d\n",buf[i]);

                        regs.r[1]=(int) &del;

                        if ((e = _kernel_swi (Wimp_DeleteIcon, &regs, &regs)) != NULL)
                                 return e;
                }
        }
        return e;
}

static int filter_counter=0;

static void (*gadget_filters[16])(void);

static void _gadget_filter(void)
{
        int t;
        for (t=0; t<filter_counter;t++) {
                (*gadget_filters[t])();
        }
}

static void _add_a_filter(void (*filter)())
{
        if (filter_counter ==0 ) gadget_prefilter_state(_gadget_filter);

        if (filter_counter == 16) return;       /* oops!, no more filters */

        gadget_filters[filter_counter]=filter;

        filter_counter++;

}

static void _delete_a_filter(void (*filter)())
{
        int t,s=0;
        for (t=0;t<filter_counter;t++) {
            if (s==0) {
                if (filter == gadget_filters[t]) s=1;
            }
            if (s==1) gadget_filters[t]=gadget_filters[t+1];      /* don't try and be clever and use else! */
        }
        filter_counter--;
        if (filter_counter==0) gadget_prefilter_state(NULL);
}

void gadget_add_filter(void (*filter)(),int *refc)
{
        if ((*refc)!=0) {
                (*refc)++;
                return;
        }
        (*refc)++;
        _add_a_filter(filter);
}

void gadget_delete_filter(void (*filter)(),int *refc)
{
        if ((*refc)>1) {
                (*refc)--;
                return;
        }
        (*refc)--;
        _delete_a_filter(filter);
}

static _kernel_oserror *gadgets_external_plot(GadgetHandler *external,_kernel_swi_regs *r)
{
   _kernel_swi_regs regs;
   regs.r[0] = 0;
   regs.r[1] = external->type;
   regs.r[2] = GADGET_PLOT;
   regs.r[3] = r->r[1];
   return _kernel_swi(external->SWIno,&regs,&regs);
}

_kernel_oserror *gadgets_plotgadget(_kernel_swi_regs *r)
{
    WindowInternal win;
    ComponentID cid=-1;
    _kernel_oserror *er;
    GadgetHandler *external =0;

    external = gadgets_check_external(&(((Gadget *) r->r[1])->hdr),GADGET_PLOT);
    if ((int) external >0 && external->features.bits.plot == PRIVATE_HANDLER) return gadgets_external_plot(external,r);

    win.gadgets=NULL;
    win.wimp_window_handle=NULL;
    win.icon_mappings=NULL;
    win.num_gadgets=0;
    win.panes = NULL;

    /* bits 0-2 of flags are plot gadget options */

    PlotGadgetOptions = r->r[0] & 7;

    SWI_WimpCreateIcon=Wimp_PlotIcon;
    #define MAGIC_ERROR_CODE ((_kernel_oserror *)2)
    last_create_icon_error = MAGIC_ERROR_CODE; /* Magic number */
    DEBUG debug_output ("plot_gadget", "About to Plot Gadget\n");

    er = gadgets_add((Gadget *) r->r[1],&win,&cid);
    DEBUG debug_output ("plot_gadget", "About to tidy up after Ploting Gadget\n");

    if (!er) {
      gadgets_remove(cid,&win,1);
    } else if (last_create_icon_error != NULL) {
      wimp_IconCreate i;
      int dum;
      Gadget *gt = (Gadget *) r->r[1];
      i.icon.bbox.xmin = gt->hdr.xmin;
      i.icon.bbox.ymin = gt->hdr.ymin;
      i.icon.bbox.xmax = gt->hdr.xmax;
      i.icon.bbox.ymax = gt->hdr.ymax;
      i.icon.flags = wimp_ICONFLAGS_HAS_BORDER + (7 <<24);
      CreateIcon(i,&dum);
    }
    else {
            /* We cannot return errors from Window_SupportExternal 0, so gadgets may well
             * choose to generate errors if they get a -1 icon handle returned from such
             * calls.  If we remember the success/failure state of the last call to
             * CreateIcon, then we can detect this condition and not draw the rectangle
             * around the gadget.
             */
    }

    SWI_WimpCreateIcon=Wimp_CreateIcon;
    return er;
}

_kernel_oserror *gadgets_raise_event(ObjectID window,ComponentID id,void *e)
{
    _kernel_swi_regs regs;
    regs.r[0] = 0 ; /* Flags */
    regs.r[1] = (int) window ;
    regs.r[2] = (int) id ;
    regs.r[3] = (int) e ;
    return( _kernel_swi (Toolbox_RaiseToolboxEvent, &regs, &regs));
}

static _kernel_oserror *find_font(char *font,int xs,int ys,int *fh)
{
    _kernel_oserror *er;

    DEBUG debug_output ("fonts", "Looking for %s at (%d by %d)\n",font,xs,ys);

    if((er = _swix(Font_FindFont,_INR(1,5)|_OUT(0), font, xs, ys, 0, 0, fh)) != NULL) return er;

    DEBUG debug_output("find_font", "Found font, handle %i\n", *fh);

    return NULL;

}
static int get_font(int win,int i)
{
    wimp_GetIconState st;
    st.window_handle = win;
    st.icon_handle =i;
    wimp_get_icon_state(&st);

    if (!(st.icon.flags & wimp_ICONFLAGS_ANTI_ALIASED)) return -1;

    return (st.icon.flags >>24);
}

extern void set_icon_state(int w,int i,unsigned int eor,unsigned int fh)
{
    wimp_SetIconState st;

    st.window_handle = w;
    st.icon_handle = i;
    st.clear_word = eor;
    st.EOR_word = fh;

    wimp_set_icon_state(&st);
}

static void set_font(int w,int i,int fh, int flags)
{
    wimp_SetIconState st;

    DEBUG debug_output ("fonts", "About to set font %d on icon %d, window %d\n",fh,i,w);

    st.window_handle = w;
    st.icon_handle = i;
    st.clear_word = wimp_ICONFLAGS_ANTI_ALIASED | ((unsigned)wimp_ICONFLAGS_FORECOL)*15U
    			| ((unsigned)wimp_ICONFLAGS_BACKCOL)*15U;
    if (fh)
     st.EOR_word = wimp_ICONFLAGS_ANTI_ALIASED | wimp_ICONFLAGS_FORECOL * fh;
    else
     st.EOR_word = (flags & st.clear_word);       /* get colour */
    wimp_set_icon_state(&st);
}

extern void gadgets_refind_fonts(TaskDescriptor *t)
{
    _kernel_swi_regs regs;
/*    _kernel_oserror *er=NULL;  */
    char cbuf[128];

    int i,j,*fb,xs,ys,fh;

    if ((t->font_bindings) == NULL) return;

    fb = t->font_bindings;

    DEBUG debug_output ("fonts", "About to go looking for fonts!\n");

    for (i=1; i<256;i++) {
      WindowInternal *w = t->object_list;

      if (fb[i]) {
        regs.r[0] = i;
        regs.r[1] = (int) cbuf;
        regs.r[3] = 0x4C4C5546;         /* 'FULL' */

        _kernel_swi(Font_ReadDefn,&regs,&regs);

        xs = regs.r[2];
        ys = regs.r[3];

        for (j=0; j<fb[i]; j++)
        {
          _swix(Font_LoseFont,_IN(0),i);
          DEBUG debug_output ("gadgets_refind_fonts", "LoseFont handle %i\n",i);
        }

      }
      while (fb[i] && w) {
         int buf[256];                  /* hope this is enough ! */
         regs.r[0] = w->wimp_window_handle;
         regs.r[1] = (int) buf;
         regs.r[2] = wimp_ICONFLAGS_DELETED | wimp_ICONFLAGS_ANTI_ALIASED | 255U * wimp_ICONFLAGS_FORECOL;
         regs.r[3] =                          wimp_ICONFLAGS_ANTI_ALIASED | i * wimp_ICONFLAGS_FORECOL;

         _kernel_swi(Wimp_WhichIcon,&regs,&regs);

         for (j=0; buf[j] != -1;j++) {
            fb[i]--;
            /* find it again !*/
            if (find_font(cbuf,xs,ys,&fh) == NULL)
            { /* Only remember font if find succeeds */
              DEBUG debug_output ("gadgets_refind_fonts", "Re-find font %s, OK handle %i\n",cbuf,i);
              set_font(w->wimp_window_handle,buf[j],fh,0);
              fb[fh]++;                          /* note, fh may be i! */
            }
            else
            {
              DEBUG debug_output ("gadgets_refind_fonts", "Re-find font %s, FAILED\n",cbuf);
              set_font(w->wimp_window_handle,buf[j],0,0); /* Unset font */
            }
         }
       w =w->next;
       }
    }
    return;
}

_kernel_oserror *gadgets_set_font(WindowInternal *w,int i, char * font, int xs, int ys,int flags)
{
    _kernel_oserror *er=NULL;
    TaskDescriptor *t;
    int *fb,c,fh;

    DEBUG debug_output ("fonts", "About to set font %s on icon %d, window %d\n",font,i,w);

    if (((unsigned int) font) < 256) fh =(int) font;
    else {
      if ((er = find_font(font,xs,ys,&fh)) != NULL)
          {
           DEBUG debug_output ("fonts", "Couldn't find %s\n",font);

           return er;
       }
    }

    t = task_find_from_window(w);

    if (!t) {
       if ((((unsigned int) font) >= 256) && (fh!=0))
         _swix(Font_LoseFont,_IN(0),fh); /* remember to free the font too */
       DEBUG debug_output ("fonts", "(Fonts) Didn't find task, window %d!\n",w);

       return NULL;        /* what can we do ? */
    }

    if (fh && (t->font_bindings == NULL)) {
       t->font_bindings = mem_allocate(256 * sizeof(int),"allocation font bindings");
       if (t->font_bindings == NULL)
       {
         /* JRF: There is a question here as to who owns the font handle
                 passed to the module in the font name, iff it is < 256.
                 I believe that once the SWI is called, unless it returns
                 with an error, the Window module is in control of this
                 handle.

                 Consequently, we need to check that we're not trying to
                 release a handle that we don't own on this failure.
                 See also the above case for freeing the font. */
         if ((((unsigned int) font) >= 256) && (fh!=0))
           _swix(Font_LoseFont,_IN(0),fh); /* On alloc failure, free font */
         DEBUG debug_output ("fonts", "Out of memory, aborting set_font\n",c);
         return out_of_memory();
       }
       for (c=0; c<256; c++) (t->font_bindings)[c]=0;
    }

    fb = t->font_bindings;
    if (fh) fb[fh]++;

    c = get_font(w->wimp_window_handle,i);
    if (c>0) {
      fb[c]--;
      _swix(Font_LoseFont,_IN(0),c);
      DEBUG debug_output ("fonts", "Losing icon's font handle %i\n",c);
    }

    if (fh >= 0) set_font(w->wimp_window_handle,i,fh,flags);

    return NULL;
}

extern void gadgets_wimp_to_toolbox(int *blk,_kernel_swi_regs *r)
{
   WindowInternal *w;

   r->r[0] = blk[0];
   r->r[1] = blk[1];
   w = window_from_wimp_window(blk[3]);
   if (!w) {
      r->r[2] = (1<<8) | blk[2];
      r->r[3] = blk[3];
      r->r[4] = blk[4];
      return;
   }

   r->r[2] = blk[2];
   r->r[3] = w->id;
   if (blk[4] <0) r->r[4] = blk[4];
   else r->r[4] =
        (int) (w->icon_mappings[blk[4]] ->gadget_hdr.component_id);

}

extern _kernel_oserror *gadgets_get_pointer_info(_kernel_swi_regs *r)
{
   int blk[5];

   _swix(Wimp_GetPointerInfo,_IN(1),blk);

   gadgets_wimp_to_toolbox(blk,r);

   return NULL;
}

extern _kernel_oserror *gadget_method(ObjectID obj,int method,ComponentID comp,int value,int *r5)
{
   _kernel_swi_regs regs;
   _kernel_oserror *e = NULL;
   regs.r[0] = 0;
   regs.r[1] = obj;
   regs.r[2] = method;
   regs.r[3] = comp;
   regs.r[4] = value;
   if (r5) regs.r[5] = *r5;
   e =_kernel_swi (Toolbox_ObjectMiscOp, &regs, &regs);
   if (r5) *r5 = regs.r[5];
   return e;

}

static _kernel_oserror *simple_move_gadget(WindowInternal *win,GadgetInternal *id,wimp_Bbox *box)
{
    _kernel_oserror *e=NULL;
    int no=0,i,buf[MAX_ICONS_FOR_GADGET],t=(sizeof (int))*MAX_ICONS_FOR_GADGET;
    int xoff,yoff,xmoff,ymoff;
    wimp_Bbox newbox;
    wimp_GetIconState state;
    wimp_GetCaretPosition pos;

    e=gadgets__get_icon_list(win,id,NULL,&no);      /* returns no. of icons in gadget */
    no = (no/4);                                       /* buffer is ints */

    xoff = box->xmin - id->gadget_hdr.xmin;
    yoff = box->ymin - id->gadget_hdr.ymin;

    xmoff = box->xmax - id->gadget_hdr.xmax;
    ymoff = box->ymax - id->gadget_hdr.ymax;

    wimp_get_caret_position(&pos);

    if (!e) {
        e=gadgets__get_icon_list(win,id,buf,&t);
        if (e) no=0;
        for (i=0;i<no;i++) {
                state.window_handle = win->wimp_window_handle;
                state.icon_handle   = buf[i];

                if ((e = wimp_get_icon_state(&state)) != NULL)
                         return e;

                newbox.xmin = state.icon.bbox.xmin +xoff;
                newbox.ymin = state.icon.bbox.ymin +yoff;
                newbox.xmax = state.icon.bbox.xmax +xmoff;
                newbox.ymax = state.icon.bbox.ymax +ymoff;

                resize_icon(state.window_handle,state.icon_handle,&newbox);

                if (pos.window_handle == state.window_handle &&
                    pos.icon_handle == state.icon_handle)
                   wimp_set_caret_position(state.window_handle,state.icon_handle,
                                           pos.x_caret_offset + xoff,
                                           pos.y_caret_offset + yoff,
                                           pos.caret_height,pos.caret_index);
        }
    }
    return e;
}

static _kernel_oserror *gadgets_move_external(GadgetHandler *list,GadgetInternal *g,
                         WindowInternal *id,wimp_Bbox *box)
{
   _kernel_swi_regs regs;
   _kernel_oserror *e;

   if (list->features.bits.move == DEFAULT_HANDLER) return simple_move_gadget(id,g,box);

   if (list->features.bits.move != PRIVATE_HANDLER) return NULL;

   regs.r[0] = 0;
   regs.r[1] = list->type;
   regs.r[2] = GADGET_MOVE;
   regs.r[3] = (int) g->data;
   regs.r[4] = (int) id->wimp_window_handle;
   regs.r[5] = (int) box;
   regs.r[6] = (int) id->id;

   e = dispatch_external(list,&regs);
   return e;

}


_kernel_oserror *gadgets_move_gadget(WindowInternal *win,GadgetInternal *id, wimp_Bbox *box)
{
    _kernel_oserror *e=NULL;
    GadgetHandler *ext;

    if ((ext = gadgets_check_external(&(id->gadget_hdr),GADGET_MOVE)) != INTERNAL_GADGET) {
        e = gadgets_move_external(ext,id, win,box);
    }
    else {
        if (entry_points[(id->gadget_hdr.type - Gadget_Max) / 64].move != NULL) {
           if ((e = entry_points[(id->gadget_hdr.type - Gadget_Max) / 64].move
                        (id, win->id,win->wimp_window_handle,box)) != NULL)
               return e;
        }
        else {
            e= simple_move_gadget(win,id,box);
        }
    }
    if (!e) {
        gadgets__redraw_gadget(win->wimp_window_handle,&(id->gadget_hdr));
        *( (wimp_Bbox *) &(id->gadget_hdr.xmin)) = *box;
        gadgets__redraw_gadget(win->wimp_window_handle,&(id->gadget_hdr));
    }
    return e;
}

extern _kernel_oserror * CreateObjectFromMemory (void *mem, ObjectID *obj)
{
    _kernel_swi_regs regs;
    _kernel_oserror *e=NULL;

    regs.r[0]=1;
    regs.r[1]= (int) mem;

    if (SWI_WimpCreateIcon == Wimp_CreateIcon) {
        if ((e = _kernel_swi(Toolbox_CreateObject,&regs,&regs)) !=NULL) return e;
    }

    *obj = (ObjectID) regs.r[0];

    /* e must be NULL, probably quicker than return NULL */

    return e;

}

extern _kernel_oserror * CreateObjectFromTemplate (char *name, ObjectID *obj)
{
    _kernel_swi_regs regs;
    _kernel_oserror *e=NULL;

    regs.r[0]=0;
    regs.r[1]= (int) name;

        /* allow NULL/empty string names */

    if (regs.r[1] && ( * ((char *) regs.r[1])) && (SWI_WimpCreateIcon == Wimp_CreateIcon)) {
        if ((e = _kernel_swi(Toolbox_CreateObject,&regs,&regs)) !=NULL) return e;
    }

    *obj = (ObjectID) regs.r[0];


    /* e must be NULL, probably quicker than return NULL */

    return e;

}




_kernel_oserror* gadgets_enumerate( _kernel_swi_regs* r)
/*
On entry:
    r0 = flags
    r1 = Wimp window handle
    r2 = -1 to start from first gadget, otherwise value returned from previous call.
    r3 = pointer to buffer or 0 to get required size
    r4 = size of buffer, or unused if r3=0

On exit:
    If r3 on entry is 0:
        r4 = required buffersize (-1 if r1 is not a toolbox window).
    If r3 on entry is non-0:
        r2 = value to pass on to next call in r2. 0 if no more.
        r4 = num bytes written to buffer (-1 if r1 is not a toolbox window).
    All other registers preserved.
 */
{
    WindowInternal*	window		= window_from_wimp_window( r->r[1]);
    GadgetInternal**	pos		= (GadgetInternal**)	&r->r[2];
    ComponentID*	buffer		= (ComponentID*)	r->r[3];
    size_t*		buffsize	= (size_t*)		&r->r[4];
    int			maxi		= (buffer) ? *buffsize / sizeof( ComponentID) : INT_MAX;
    GadgetInternal* 	g;
    int             	i;

    if ( !window)	// Not a toolbox window.
    {
        *buffsize = -1;
        return NULL;
    }

    if ( NULL==*pos)	// In case we are called after complete list hs been returned.
    {
        *buffsize = 0;
        return NULL;
    }
    else if ( (GadgetInternal*) -1 == *pos)	g = window->gadgets;	// First gadget
    else					g = *pos;

    for ( i=0; g && i<maxi; g=g->next, i++)
    {
        if ( buffer)	buffer[ i] = g->gadget_hdr.component_id;
    }

    *pos = g;
    *buffsize = i*sizeof( GadgetInternal*);

    return NULL;
}
