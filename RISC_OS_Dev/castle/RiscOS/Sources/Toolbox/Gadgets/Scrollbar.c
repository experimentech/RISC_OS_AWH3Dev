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
/* Title:   Scrollbar.c
 * Purpose: Scrollbar gadget for textgadgets module
 *
 * Revision History
 * piers    12/07/96 Created
 * piers    26/09/96 Rewritten to use nested windows rather than drawing
 *                   scrollbar manually
 * piers    20/11/96 Got around a bug in the toolbox where if a gadget isn't
 *                   made up of icons, it creates new ones. Passing a NULL
 *                   list fails, but passing an empty list containing -1 works.
 * piers    19/01/98 Added dragging support
 * ADH      24/03/99 Set title_bg to 2 rather than leaving it uninitialised.
 *                   Put scroll_inner and scroll_outer the right way around.
 * pete     18/6/99  Added fading support.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"

#include "macros.h"
#include "messages.h"
#include "twimp.h"
#include "objects/gadgets.h"

#include "glib.h"
#include "TextGadget.h"
#include "ScrollbarP.h"
#include "Utils.h"

#ifdef MemCheck_MEMCHECK
#include "MemCheck:MemCheck.h"
#endif

typedef struct
{
    unsigned int	flags;
    wimp_Bbox		box;
    unsigned int	min;
    unsigned int	max;
    unsigned int	value;
    unsigned int	visible;
    unsigned int	line_inc;
    unsigned int	page_inc;
} ScrollbarPlotInfo;

static int my_icons[] = {-1};

static PrivateScrollbar **scrollbar_list = NULL;

static _kernel_oserror *add_redraw_handler(PrivateScrollbar *tb)
{

    if (scrollbar_list == NULL)
    {
        if ( (scrollbar_list = malloc(sizeof(PrivateScrollbar*) * 2)) ==NULL)
            return make_error(TextGadgets_BarAllocFailed, 0);

        scrollbar_list[0] = tb;
        scrollbar_list[1] = NULL;
    }
    else
    {
        PrivateScrollbar **new_list;
        unsigned int i;

        for (i = 0; scrollbar_list[i] != NULL; i++)
            ;

        new_list = realloc(scrollbar_list,sizeof(PrivateScrollbar *) * (i+2));

        if (new_list == NULL)
            return make_error(TextGadgets_BarAllocFailed, 0);

        scrollbar_list = new_list;

        scrollbar_list[i] = tb;
        scrollbar_list[i + 1] = NULL;
    }

    return NULL;
}

static _kernel_oserror *remove_redraw_handler(const PrivateScrollbar *tb)
{
    unsigned int i, j;

    if (scrollbar_list == NULL)
        return make_error(TextGadgets_UKScrollbar, 0);

    for (i = 0;
        (scrollbar_list[i] != NULL) && (scrollbar_list[i] != tb);
        i++)
        ;

    if (scrollbar_list[i] == NULL)
        return make_error(TextGadgets_UKScrollbar, 0);

    for (j = i; scrollbar_list[j] != NULL; j++)
        ;

    // j points to last entry

    if (j <= 1)
    {
        free(scrollbar_list);
        scrollbar_list = NULL;
    }
    else
    {
        PrivateScrollbar **new_list;

        for (; i < j; i++)
            scrollbar_list[i] = scrollbar_list[i + 1];

        // No need to generate an error if the realloc fails, 'cos
        // it'll just realloc next time, hopefully
        new_list = realloc(scrollbar_list, sizeof(PrivateScrollbar *) * (j+1));

        if (new_list != NULL)
            scrollbar_list = new_list;
    }

    return NULL;
}

static _kernel_oserror *scrollbar_show(PrivateScrollbar *sdata)
{
    wimp_OpenWindow	open_win;
    wimp_Bbox		extent = {0, 0, 0, 0};

    open_win.window_handle = sdata->scrollbar_window;
    work_to_screen_handle(&open_win.visible_area, &sdata->box,
    						sdata->parent_window);
    if (sdata->state & Scrollbar_Horizontal)
    {
        open_win.visible_area.ymin = open_win.visible_area.ymax;

        if (sdata->visible != 0)
        {
            extent.xmax = (sdata->box.xmax - sdata->box.xmin) *
        		(sdata->max - sdata->min + sdata->visible) /
        		(int)sdata->visible;
            if (extent.xmax < (sdata->box.xmax - sdata->box.xmin))
                extent.xmax = sdata->box.xmax - sdata->box.xmin;
        }
        else
            extent.xmax = -0xffff;

        if (sdata->value - sdata->min == 0)
            open_win.scx = 0;
        else
            open_win.scx = (extent.xmax) /
            	(int)(sdata->max - sdata->min) * (sdata->value - sdata->min);
    }
    else
    {
        open_win.visible_area.xmax = open_win.visible_area.xmin;

        if (sdata->visible != 0)
        {
            extent.ymin = -((sdata->box.ymax - sdata->box.ymin) *
        		(sdata->max - sdata->min + sdata->visible) /
        		(int)sdata->visible);
            if (extent.ymin > (sdata->box.ymax - sdata->box.ymin))
                extent.ymin = sdata->box.ymax - sdata->box.ymin;
        }
        else
            extent.ymin = -0xffff;

        if (sdata->value - sdata->min == 0)
            open_win.scy = 0;
        else
            open_win.scy = (extent.ymin) /
            	(int)(sdata->max - sdata->min) * (sdata->value - sdata->min);
    }

    /* PJG: (18/6/99) Now, if the scrollbar is faded, just set the extent to
    *                 be the window size so we get one big sausage.
     */
    if (sdata->faded)
    {
        extent.xmin = 0;
        extent.xmax = sdata->box.xmax - sdata->box.xmin;
        extent.ymax = 0;
        extent.ymin = -(sdata->box.ymax - sdata->box.ymin);
    }

    wimp_set_extent(sdata->scrollbar_window, &extent);
    open_win.behind = 0;
    _swix(Wimp_OpenWindow, _INR(1,4), &open_win, 0x4B534154 /*'TASK'*/,
    				sdata->parent_window, 0);

    return NULL;
}

int scrollbar_active(void)
{
    return scrollbar_list != NULL;
}

/* scrollbar_die -----------------------------------------------------------
 * Need to remove all scrollbar windows
 */
_kernel_oserror *scrollbar_die(void)
{
    return NULL;
}

/* scrollbar_add ----------------------------------------------------------
 */
_kernel_oserror *
scrollbar_add(Scrollbar *sdata, int wimpw, ObjectID object_id,
				int **icons, int **data)
{
    PrivateScrollbar		*sb;
    wimp_Window			win;
    wimp_GetWindowState		open_win;

    sb = (PrivateScrollbar *) mem_allocate(sizeof(PrivateScrollbar));
    if (!sb)
        return make_error(TextGadgets_BarAllocFailed, 0);

#ifdef MemCheck_MEMCHECK
    MemCheck_RegisterMiscBlock(sb, sizeof(PrivateScrollbar));
#endif

    sb->event = sdata->event ? sdata->event : Scrollbar_PositionChanged;
    sb->state = sdata->hdr.flags;
    sb->object_id = object_id;
    sb->component_id = sdata->hdr.component_id;

    sb->type = sdata->type;
    sb->faded = 0; // PJG (18/6/99) scrollbar is not faded
    sb->parent_window = wimpw;

    sb->box.xmin = sdata->hdr.xmin;
    sb->box.ymin = sdata->hdr.ymin;
    sb->box.xmax = sdata->hdr.xmax;
    sb->box.ymax = sdata->hdr.ymax;
    sb->min = sdata->min;
    if ((sb->max = sdata->max) < sb->min)
        sb->max = sb->min;
    if ((sb->value = sdata->value) > sb->max)
        sb->value = sb->max;
    if (sb->value < sb->min)
        sb->value = sb->min;
    if ((sb->visible = sdata->visible) > sb->max)
        sb->visible = sb->max;
    sb->line_inc = sdata->line_inc;
    sb->page_inc = sdata->page_inc;

    win.box.xmin = 0;
    win.box.ymin = 0;
    win.box.xmax = 0;
    win.box.ymax = 0;
    win.scx = 0;
    win.scy = 0;
    win.behind = -1;
    win.flags = wimp_WINDOWFLAGS_AUTOREDRAW | wimp_WINDOWFLAGS_PANE |
    		wimp_WINDOWFLAGS_ALLOW_OFF_SCREEN | wimp_WINDOWFLAGS_CLICK_SCROLL_REQUEST |
    		(int)wimp_WINDOWFLAGS_USE_NEW_FLAGS;
    if (sb->state & Scrollbar_Horizontal)
        win.flags |= wimp_WINDOWFLAGS_HAS_HSCROLLBAR;
    else
        win.flags |= wimp_WINDOWFLAGS_HAS_VSCROLLBAR;
    win.colours[0] = 0xff;
    win.colours[1] = 2;
    win.colours[4] = 3;
    win.colours[5] = 1;
    win.ex.xmin = 0;
    win.ex.ymin = -0xffff;
    win.ex.xmax = 0xffff;
    win.ex.ymax = 0;
    win.title_flags = 0;
    win.work_area_flags = 0;
    win.sprite_area = NULL;
    win.min_size = 0x00010001;
    win.title.indirect_text.buffer = NULL;
    win.title.indirect_text.valid_string = NULL;
    win.title.indirect_text.buff_len = 0;
    win.nicons = 0;

    // Display scrollbar if parent is showing
    open_win.open.window_handle = sb->parent_window;
    wimp_get_window_state(&open_win);

    wimp_create_window(&win, &sb->scrollbar_window);

    scrollbar_show(sb);

    *icons = my_icons;

    add_redraw_handler(sb);

    *data = (int *) sb;

    add_task_interest(GLib_ToolboxEvents, filter_toolbox_events,
    				TextGadgets_Filter);
    add_task_interest(GLib_WimpEvents, filter_wimp_events,
    				TextGadgets_Filter);

    return NULL;
}

static _kernel_oserror *_set_bounds(unsigned int flags,
		PrivateScrollbar *sdata,
		unsigned int min, unsigned int max, unsigned int visible)
{
    if (flags & Scrollbar_Lower_Bound)
        sdata->min = min;
    if (flags & Scrollbar_Upper_Bound)
        sdata->max = max;
    if (flags & Scrollbar_Visible_Len)
        sdata->visible = visible;

    if (sdata->max < sdata->min)
        sdata->max = sdata->min;
    if (sdata->visible > sdata->max)
        sdata->visible = sdata->max;
    if (sdata->visible < sdata->min)
        sdata->visible = sdata->min;

    // Need to set window extent

    return NULL;
}

static _kernel_oserror *_get_bounds(unsigned int flags,
		PrivateScrollbar *sdata, _kernel_swi_regs *regs)
{
    if (flags & Scrollbar_Lower_Bound)
        regs->r[0] = sdata->min;
    if (flags & Scrollbar_Upper_Bound)
        regs->r[1] = sdata->max;
    if (flags & Scrollbar_Visible_Len)
        regs->r[2] = sdata->visible;

    return NULL;
}

static _kernel_oserror *_set_increments(unsigned int flags,
		PrivateScrollbar *sdata,
		unsigned int line, unsigned int page)
{
    if (flags & Scrollbar_Line_Inc)
        sdata->line_inc = line;
    if (flags & Scrollbar_Page_Inc)
        sdata->page_inc = page;

    return NULL;
}

static _kernel_oserror *_get_increments(unsigned int flags,
		PrivateScrollbar *sdata, _kernel_swi_regs *regs)
{
    if (flags & Scrollbar_Line_Inc)
        regs->r[0] = sdata->line_inc;
    if (flags & Scrollbar_Page_Inc)
        regs->r[1] = sdata->page_inc;

    return NULL;
}

_kernel_oserror *scrollbar_method(PrivateScrollbar *handle,
				_kernel_swi_regs *regs)
{
    _kernel_oserror *e = NULL;

#ifdef MemCheck_MEMCHECK
    MemCheck_RegisterMiscBlock(regs, sizeof(_kernel_swi_regs));
#endif

    switch (regs->r[2])
    {
        case Scrollbar_GetState:
            regs->r[0] = handle->state;
            break;
        case Scrollbar_SetState:
            handle->state = regs->r[4];
            break;
        case Scrollbar_SetBounds:
            e = _set_bounds(regs->r[0], handle, regs->r[4], regs->r[5],
            		regs->r[6]);
            break;
        case Scrollbar_GetBounds:
            e = _get_bounds(regs->r[0], handle, regs);
            break;
        case Scrollbar_SetValue:
            handle->value = regs->r[4];
            scrollbar_show(handle);
            break;
        case Scrollbar_GetValue:
            regs->r[0] = handle->value;
            break;
        case Scrollbar_SetIncrements:
            e = _set_increments(regs->r[0], handle, regs->r[4], regs->r[5]);
            break;
        case Scrollbar_GetIncrements:
            e = _get_increments(regs->r[0], handle, regs);
            break;
        case Scrollbar_SetEvent:
            handle->event = regs->r[4];
            break;
        case Scrollbar_GetEvent:
            regs->r[0] = handle->event;
        default:
            break;
   }

#ifdef MemCheck_MEMCHECK
    MemCheck_UnRegisterMiscBlock(regs);
#endif

   return e;
}

/* ------------------------------------------------------------------------
 */
_kernel_oserror *scrollbar_remove(PrivateScrollbar *handle)
{
    remove_redraw_handler(handle);

    remove_task_interest(GLib_ToolboxEvents, filter_toolbox_events);
    remove_task_interest(GLib_WimpEvents, filter_wimp_events);

    mem_free(handle);

#ifdef MemCheck_MEMCHECK
    MemCheck_UnRegisterMiscBlock(handle);
#endif

    return NULL;
}

_kernel_oserror *scrollbar_fade(PrivateScrollbar *handle, int fade)
{
    /* PJG: (18/6/99) Now the sausage will be plotted as big as possible
     *                and we will ignore it.
     */
    handle->faded = fade;
    scrollbar_show(handle);

    return NULL;
}

_kernel_oserror *scrollbar_plot(Scrollbar *sdata)
{
    wimp_GetWindowState	state;

    if ((state.open.window_handle = redrawing_window) == 0)
        return NULL;

sdata = sdata;

    return NULL;
}

static _kernel_oserror *_do_drag_scroll(wimp_OpenWindowRequest *event)
{
    int old_position, i;

    for (i = 0; scrollbar_list[i] != NULL; i++)
        if (scrollbar_list[i]->scrollbar_window == event->open_block.window_handle)
        {
            PrivateScrollbar *sdata = scrollbar_list[i];
            ScrollbarPositionChangedEvent changed;

            if (sdata->faded) return NULL; // PJG (18/6/99) Ignore if faded
                                           //               bit is set.

            old_position = sdata->value;

            if (sdata->state & Scrollbar_Horizontal)
            {
                int extent = (sdata->box.xmax - sdata->box.xmin) *
                	(sdata->max - sdata->min + sdata->visible);

                if (extent == 0)
                    sdata->value = sdata->max;
                else
                    sdata->value = (event->open_block.scx *
                    	(sdata->max - sdata->min) *
	                sdata->visible / extent) + sdata->min;
            }
            else
            {
                int extent = (sdata->box.ymax - sdata->box.ymin) *
                	(sdata->max - sdata->min + sdata->visible);

	        if (extent == 0)
	            sdata->value = sdata->max;
	        else
                    sdata->value = (-event->open_block.scy *
                        (sdata->max - sdata->min) *
                	sdata->visible / extent) + sdata->min;
            }

            if (old_position != sdata->value)
            {
                changed.hdr.size = sizeof(ScrollbarPositionChangedEvent);
                changed.hdr.event_code = sdata->event;
                changed.hdr.flags = 0;

                changed.direction = 0;

                changed.new_position = sdata->value;

                _swix(Toolbox_RaiseToolboxEvent, _INR(0,3),
                      0, sdata->object_id, sdata->component_id, (ToolboxEvent *)&changed);

                scrollbar_show(sdata);
            }
        }


    return NULL;
}

static _kernel_oserror *_do_scroll(wimp_ScrollRequest *event)
{
    PrivateScrollbar	*sdata;
    int			i;

    for (i = 0; scrollbar_list[i] != NULL; i++)
        if (scrollbar_list[i]->scrollbar_window == event->open_block.window_handle)
        {
            // Found it!
            ScrollbarPositionChangedEvent changed;
            int old_position;

            sdata = scrollbar_list[i];
            old_position = sdata->value;

            if (sdata->faded) return NULL; // PJG (18/6/99) Ignore if faded
                                           //               bit is set.

            changed.hdr.size = sizeof(ScrollbarPositionChangedEvent);
            changed.hdr.event_code = sdata->event;
            changed.hdr.flags = 0;

            if (sdata->state & Scrollbar_Horizontal)
                changed.direction = event->x_scroll_direction;
            else
                changed.direction = -event->y_scroll_direction;

            switch (changed.direction)
            {
              case -2:
                if (sdata->value > sdata->page_inc)
                    sdata->value = sdata->value - sdata->page_inc;
                else
                    sdata->value = sdata->min;
                break;
              case -1:
                if (sdata->value > sdata->line_inc)
                    sdata->value = sdata->value - sdata->line_inc;
                else
                    sdata->value = sdata->min;
                break;
              case 0:
                break;
              case 1:
                sdata->value = sdata->value + sdata->line_inc;
                break;
              case 2:
                sdata->value = sdata->value + sdata->page_inc;
                break;
            }
            if (sdata->value < sdata->min)
                sdata->value = sdata->min;
            if (sdata->value > sdata->max)
                sdata->value = sdata->max;

            changed.new_position = sdata->value;

            if (old_position != sdata->value)
            {
                _swix(Toolbox_RaiseToolboxEvent, _INR(0,3),
                      0, sdata->object_id, sdata->component_id, (ToolboxEvent *)&changed);

                scrollbar_show(sdata);
            }
        }

    return NULL;
}

#ifdef MemCheck_MEMCHECK
static _kernel_oserror *scrollbar_filter2(_kernel_swi_regs *regs)
#else
_kernel_oserror *scrollbar_filter(_kernel_swi_regs *regs)
#endif
{
    ToolboxEvent *event = (ToolboxEvent *)regs->r[1];
    IDBlock	*id_block = (IDBlock *)regs->r[3];
    int		event_code = regs->r[0];
    unsigned int i;

    if (scrollbar_list == NULL)
        return NULL;

    if (event_code == wimp_ESCROLL)
    {
        _do_scroll((wimp_ScrollRequest *)regs->r[1]);
    }
    else if (event_code == wimp_EOPEN)
    {
        _do_drag_scroll((wimp_OpenWindowRequest *)regs->r[1]);
    }

    // All checks after here should assume event is a toolbox event
    if (event_code != wimp_ETOOLBOX_EVENT)
         return NULL;

    if (event->hdr.event_code == Toolbox_ObjectDeleted)
    {
        int remaining = 0;
        PrivateScrollbar **new_list;

        // An object has been deleted, so remove from internal list
        // any gadgets inside it.
        for (i = 0; scrollbar_list[i] != NULL; i++)
        {
            if (scrollbar_list[i]->object_id == id_block->self_id)
            {
                // Found one!
                int j;

                wimp_delete_window( (wimp_DeleteWindow *)
                		&(scrollbar_list[i]->scrollbar_window));

                for (j = i; scrollbar_list[j] != NULL; j++)
                {
                    // Copy down following gadgets
                    scrollbar_list[j] = scrollbar_list[j+1];
                }
            }
            else
                remaining++;
        }

        // Shrink memory block
        if (remaining == 0)
        {
            free(scrollbar_list);
            scrollbar_list = NULL;
        }
        else
        {
            new_list = realloc(scrollbar_list,
        			sizeof(PrivateScrollbar*) * (remaining + 1));
            if (new_list != NULL)
                scrollbar_list = new_list;
        }
    }

    return NULL;
}

#ifdef MemCheck_MEMCHECK
_kernel_oserror *scrollbar_filter(_kernel_swi_regs *regs)
{
    _kernel_oserror *e;

    MemCheck_RegisterMiscBlock((void*)regs->r[1], 256);
    MemCheck_RegisterMiscBlock((void*)regs->r[3], sizeof(IdBlock));
    e = scrollbar_filter2(regs);
    MemCheck_UnRegisterMiscBlock((void*)regs->r[1]);
    MemCheck_UnRegisterMiscBlock((void*)regs->r[3]);

    return e;
}
#endif

_kernel_oserror *scrollbar_move(PrivateScrollbar *sdata, wimp_Bbox *box)
{
    wimp_GetWindowState	state;

    sdata->box = *box;

    state.open.window_handle = sdata->scrollbar_window;
    wimp_get_window_state(&state);

    return scrollbar_show(sdata);
}
