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
/* Title:   display.c
 * Purpose: display field gadgets
 * Author:
 * History: 22-Feb-94: IDJ: created
 *          08-Mar-94: CSM: Written based on label gadget. No events yet
 *          09-Mar-94: CSM: Events work
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "swis.h"
#include "kernel.h"

#include "const.h"
#include "macros.h"
#include "debug.h"
#include "mem.h"
#include "string32.h"
#include "messages.h"

#include "style.h"
#include "objects/toolbox.h"
#include "objects/window.h"

#include "../globals.h"
#include "../gadgets.h"
#include "../object.h"

#include "display.h"

ICONLIST(2)
extern int WIMP_WINDOW;
extern WindowInternal *CURRENT_WINDOW;

typedef struct _display_field_internal
{
  int   icon_handle ;
  DisplayField display_field ;  /* Fill this in from gadget_template */
} display_field_internal ;

_kernel_oserror *display_field_add (GadgetInternal *gadget, ObjectID window,
                                    int **icon_list, Gadget *gadget_template,
                                    int window_handle)
{
    wimp_IconCreate  i;
    _kernel_oserror *e;
    display_field_internal *d;
    int temp;

    IGNORE(window);

    /*
     * Allocate our own data to hang off the GadgetInternal structure.
     * We take a copy of the display's template (ie its textual string).
     */

    temp = gadget_template->data.display_field.max_text_len ;

    d = mem_allocate (sizeof (display_field_internal) + temp, "display_field_add, display_field_internal type") ;
    if (d == NULL)
        return out_of_memory();

    gadget->data = (void *) d ;

    d->display_field.max_text_len = temp;

    d->display_field.text = temp ? (char *) (d+1) : "";

    string_copy_chk (d->display_field.text, gadget_template->data.display_field.text,temp);

    DEBUG debug_output ("display", "Creating DisplayField with string %s\n\r", d->display_field.text) ;

    /*
     * Set up a real wimp icon block, with text buffer pointing at our copy
     * of the template.
     */

    i.window_handle                        = window_handle ;
    i.icon.data.indirect_text.buffer       = d->display_field.text ;
    i.icon.data.indirect_text.buff_len     = d->display_field.max_text_len ;
    i.icon.data.indirect_text.valid_string = style_DISPLAY_FIELD_VALIDSTR ;
    i.icon.flags                           = style_DISPLAY_FIELD_ICONFLAGS ;

    switch (gadget_template->hdr.flags & DisplayField_Justification)
    {
      case DisplayField_LeftJustify:
        break ;

      case DisplayField_RightJustify:
        i.icon.flags |= wimp_ICONFLAGS_RJUSTIFY ;
        break ;

      case DisplayField_Centred:
        i.icon.flags |= wimp_ICONFLAGS_HCENTRE ;
        break ;
    }

    SetCoords(i)

    /*
     * Create the underlying wimp icon (and store its handle).
     */

    if ((e = CreateIcon(i, &(d->icon_handle))) != NULL)
        goto error;


    /*
     * Return icon list to caller.
     */

    *icon_list = IconList;

    IconList[0] = d->icon_handle;

    return NULL;


error:

    if (d != NULL)
        mem_free (d, "freeing display field");

    return e;
}


_kernel_oserror *display_field_method   (GadgetInternal *gadget, ObjectID window, _kernel_swi_regs *r)
{
  _kernel_oserror        *e=NULL;
  _kernel_swi_regs       *user_regs = USER_REGS (r) ;
  int                     method    = user_regs->r[2];
  display_field_internal *d         = (display_field_internal *) gadget->data ;
#ifdef GenerateEventsForMethods
  _kernel_swi_regs        regs;
  ToolboxEvent            event ;
#endif
  wimp_Bbox               box;

  IGNORE(window);
   
  DEBUG debug_output ("display", "display_field_method: entry, supplied gadget type %d\n\r",
                       gadget->gadget_hdr.type) ;

  switch (method - DisplayField_Base)
  {
    case (DisplayField_SetValue- DisplayField_Base):

      /* Should I check string length here, or cheerfully reallocate? */
      /* Issue: not clear if ValueChanged_TooLong is just a flag asserted
       * when the text wont fit into the event block returned if DisplayField_
       * ValueChanged is raised as an event
       */
      DEBUG debug_output ("display", "DisplayField_SetValue: string supplied was %s\n\r", (char *) user_regs->r[4]) ;
      DEBUG debug_output ("display", "DisplayField_SetValue: we think max buffer len is %d, supplied string len is %d\n\r",
                          d->display_field.max_text_len, string_length ((char *) user_regs->r[4])) ;

      if (!string_copy_chk (d->display_field.text, (char *) user_regs->r[4], d->display_field.max_text_len ))
      {
        DEBUG debug_output ("display", "DisplayField_SetValue: string was larger than previous max\n\r") ;
        return buffer_too_short();
      }

      /*
       * Redraw the gadget - by using a smaller bounding box, it flickers less.
       */

      box = * ((wimp_Bbox *) &gadget->gadget_hdr.xmin);
      box.xmin += 8;
      box.xmax -= 4;
      box.ymin += 4;
      box.ymax -= 8;

      update_window(WIMP_WINDOW,&box);

      /*
       * Raise toolbox event
       * Hatchet job here - to find out the maximum string length, I use
       *    knowledge of which structures are used...
       * Egads! This code is frogging ugly. Not convinced it's right yet either...
       */

#ifdef GenerateEventsForMethods

/* if this gets enabled in the future, then check below and set flags */

      if (string_length (d->display_field.text) >=
          (sizeof (ToolboxEvent) - sizeof (ToolboxEventHeader) - 4))
      {
        event.hdr.size = sizeof (ToolboxEvent) ; /* It's curved to fit... */
        event.data.words[0] = DisplayField_ValueChanged_TooLong ;
        (void) string_copy_chk ( (char *) &event.data.words[1],
                                 d->display_field.text,
                                 sizeof (ToolboxEvent) - sizeof (ToolboxEventHeader) - 5 ) ;
                                 /* Leave room for terminator! */
        DEBUG debug_output ("display", "DisplayField_SetValue: Truncating string to %d characters\n\r",
                            sizeof (ToolboxEvent) - sizeof (ToolboxEventHeader) - 5) ;
      }
      else
      {
        /* +5 means minus one for the terminator, minus four for the flags
           but add 3 to round up to words, then BIC 3
         */

        event.hdr.size = ((string_length (d->display_field.text) + sizeof (ToolboxEventHeader) + 8) & ~3) ;
        event.data.words[0] = 0 ;
        string_copy ( (char *) &event.data.words[1], d->display_field.text ) ;
        DEBUG debug_output ("display", "DisplayField_SetValue: taking a chance, I think it's short enough\n\r") ;
      }

      event.hdr.event_code = DisplayField_ValueChanged ;

      DEBUG debug_output ("display", "DisplayField_SetValue: raising toolbox event\n\r") ;

      regs.r[0] = 0 ; /* Flags */
      regs.r[1] = (int) window ;
      regs.r[2] = (int) gadget->gadget_hdr.component_id ;
      regs.r[3] = (int) &event ;
      if ((e = _kernel_swi (Toolbox_RaiseToolboxEvent, &regs, &regs)) != NULL)
        return (e);
#endif

      break ;

    case (DisplayField_GetValue- DisplayField_Base):
      string_to_buffer ((char *)user_regs->r[4],d->display_field.text,&(user_regs->r[5]));

      DEBUG debug_output ("display", "DisplayField_GetValue: returning string %s\n\r", (char *) user_regs->r[4]) ;

      break ;

    case (DisplayField_SetFont- DisplayField_Base):

       return (gadgets_set_font(CURRENT_WINDOW,d->icon_handle,(char *) user_regs->r[4],user_regs->r[5],
                        user_regs->r[6],style_DISPLAY_FIELD_ICONFLAGS));

       break;
    default:
       return (BadMethod(method));

  }

  return (e) ;
}
