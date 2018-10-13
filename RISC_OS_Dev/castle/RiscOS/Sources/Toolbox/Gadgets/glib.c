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

#include <stdio.h>
#include <stdlib.h>
#include "kernel.h"
#include "swis.h"

#include "twimp.h"
#include "macros.h"
#include "objects/toolbox.h"
#include "objects/window.h"

#include "Sizes.h"
#include "riscos_uti.h"
#include "glib.h"

extern _kernel_oserror *register_gadget_types(unsigned int flags, GadgetExtensionRecord *rec,int SWIno)
{
   return _swix(Window_RegisterExternal, _INR(0,2), flags, rec, SWIno);

}

extern _kernel_oserror *register_gadget_type(unsigned int flags, int type,unsigned int valid, unsigned int mask,int SWIno)
{
  GadgetExtensionRecord rec[2];

  rec[0].type = type;
  rec[0].validflags = valid;
  rec[0].features.mask = mask;
  rec[1].type = -1;

  return (register_gadget_types(flags,&rec[0],SWIno));
}

extern _kernel_oserror *deregister_gadget_type(unsigned int flags, int type,int SWIno)
{
   return _swix(Window_DeregisterExternal, _INR(0,2), flags, type, SWIno);
}

void *mem_allocate(int amount)
{
   _kernel_swi_regs regs;

   regs.r[0] = 0;
   regs.r[1] = 4;
   regs.r[2] = amount;
   _kernel_swi(Window_SupportExternal,&regs,&regs);
   return (void *) regs.r[0];
}

void mem_free(void *tag)
{
   _swix(Window_SupportExternal, _INR(0,2), 0, 5, tag);
}

void graphics_window(wimp_Bbox *area)
{
   _swix(OS_WriteI+5,0);
   _swix(OS_WriteI+24,0);
   _swix(OS_WriteI+((area->xmin) & 255),0);
   _swix(OS_WriteI+(((area->xmin) >> 8) & 255),0);
   _swix(OS_WriteI+((area->ymin) & 255),0);
   _swix(OS_WriteI+(((area->ymin) >> 8) & 255),0);
   _swix(OS_WriteI+((area->xmax -1) & 255),0);
   _swix(OS_WriteI+(((area->xmax -1) >> 8) & 255),0);
   _swix(OS_WriteI+((area->ymax -1) & 255),0);
   _swix(OS_WriteI+(((area->ymax -1) >> 8) & 255),0);

}

/* convert work area coords to screen coords */

void work_to_screen(wimp_Bbox *wa, wimp_GetWindowState *state)
{
    wa->xmin += state->open.visible_area.xmin - state->open.scx;
    wa->xmax += state->open.visible_area.xmin - state->open.scx;

    wa->ymin += state->open.visible_area.ymax - state->open.scy;
    wa->ymax += state->open.visible_area.ymax - state->open.scy;
}

/* convert screen coords to work area */

void screen_to_work(wimp_Bbox *wa, wimp_GetWindowState *state)
{
    wa->xmin -= state->open.visible_area.xmin - state->open.scx;
    wa->xmax -= state->open.visible_area.xmin - state->open.scx;

    wa->ymin -= state->open.visible_area.ymax - state->open.scy;
    wa->ymax -= state->open.visible_area.ymax - state->open.scy;
}

/* modify a box and then colour it in */

static void plot_2d_rect(const wimp_Bbox *bound, wimp_Bbox *rect, int fillcol, int adjx, int adjy)
{
    int scalex, scaley;

    scalex = sizes_x_scale();
    scaley = sizes_y_scale();

    // New size
    rect->xmin = MIN(rect->xmin + adjx, bound->xmax);
    rect->xmax = MAX(rect->xmax - adjx, bound->xmin);
    rect->ymin = MIN(rect->ymin + adjy, bound->ymax);
    rect->ymax = MAX(rect->ymax - adjy, bound->ymin);

    // Plot if it's at least 1 OSU wide and high
    if (((rect->ymax - rect->ymin) >= scaley) &&
        ((rect->xmax - rect->xmin) >= scalex))
    {
        colourtrans_set_gcol(fillcol, 1<<7, 0);
        os_plot(PLOT_MOVE, rect->xmin, rect->ymin);
        os_plot(PLOT_RECTANGLE_FILL | PLOT_BACK, rect->xmax, rect->ymax);
    }
}

/* plot a fake flat scroll bar */

void plot_2d_scrollbar(const wimp_Bbox *bound, int bordercol, BOOL vertical)
{
    int scalex, scaley, insetx, insety;
    wimp_Bbox box;

    scalex = sizes_x_scale();
    scaley = sizes_y_scale();
    box = *bound;

    // Plot scrollbar inner border 'L' or '�'
    colourtrans_set_gcol(bordercol, 0, 0);
    if (vertical)
    {
        box.xmin += scalex;
        os_plot(PLOT_MOVE, box.xmin, box.ymax);
        os_plot(PLOT_DRAW, box.xmin, box.ymin);
        os_plot(PLOT_DRAW, box.xmax, box.ymin);
        insetx = scalex * (SIZES_SCROLL_WELL_LR / scalex);
        insety = scaley * SIZES_SCROLL_WELL_TB;
    }
    else
    {
        box.ymax -= scaley;
        os_plot(PLOT_MOVE, box.xmin, box.ymax);
        os_plot(PLOT_DRAW, box.xmax, box.ymax);
        os_plot(PLOT_DRAW, box.xmax, box.ymin);
        insetx = scalex * SIZES_SCROLL_WELL_TB;
        insety = scaley * (SIZES_SCROLL_WELL_LR / scaley);
    }

    // Plot scrollbar background (MidLightGrey), 1 pixel in
    plot_2d_rect(bound, &box, 0x99999900, scalex, scaley);

    // Plot scrollbar border, inset by the well size
    plot_2d_rect(bound, &box, bordercol, insetx, insety);

    // Plot scrollbar inner (VeryLightGrey), 1 pixel in
    plot_2d_rect(bound, &box, 0xDDDDDD00, scalex, scaley);
}
