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
/* Text Gadgets module
 * Provides: TextArea and scrolling list toolbox gadgets
 *
 * Revision History
 * piers    18/06/96 Created
 * piers    26/09/96 Restarted
 * piers    06/01/96 Added TextArea plot method for ResEd
 * piers    19/01/98 Added Wimp_EOpenWindow to interested-events for dragging
 * pete     23/06/99 Made the Scrollbar fade handler PRIVATE not DEFAULT.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"
#include "Global/Services.h"

#include "macros.h"
#include "rmensure.h"
#include "objmodule.h"
#include "messages.h"
#include "twimp.h"
#include "objects/gadgets.h"

#include "TextGadget.h"
#include "glib.h"
#include "MemMan.h"
#include "TextMan.h"
#include "TextAreaP.h"
#include "ScrollLisP.h"
#include "ScrollbarP.h"

#include "TextGadgetHdr.h"

#ifdef MemCheck_MEMCHECK
#include "MemCheck:MemCheck.h"
#endif

unsigned int    redrawing_window = 0;

int filter_toolbox_events[] =
{
    Toolbox_ObjectDeleted, Window_ObjectClass,
    Window_AboutToBeShown, Window_ObjectClass,
    Scrollbar_PositionChanged, Window_ObjectClass,
    -1
};

int filter_wimp_events[] =
{
    wimp_ENULL, 0,
    wimp_EOPEN, 0,
    wimp_EREDRAW, 0,
    wimp_EBUT, 0,
    wimp_EUSER_DRAG, 0,
    wimp_ESCROLL, 0,
    wimp_EKEY, 0,
    -1
};

#ifndef ROM
extern int Resources(void);
#endif

static void register_gadgets(void)
{
    FeatureMask features;

    features.mask = 0;
    features.bits.add    = PRIVATE_HANDLER;
    features.bits.mclick = DEFAULT_HANDLER;
    features.bits.method = PRIVATE_HANDLER;
    features.bits.remove = PRIVATE_HANDLER;
    features.bits.fade   = PRIVATE_HANDLER;
    features.bits.plot   = PRIVATE_HANDLER;
    features.bits.move   = PRIVATE_HANDLER;
    register_gadget_type(0, TextArea_Type, TextAreaValidFlags,
    		features.mask, TextGadgets_TextArea);

    features.mask = 0;
    features.bits.add    = PRIVATE_HANDLER;
    features.bits.mclick = PRIVATE_HANDLER;
    features.bits.method = PRIVATE_HANDLER;
    features.bits.remove = PRIVATE_HANDLER;
    features.bits.fade   = PRIVATE_HANDLER;
    features.bits.plot   = PRIVATE_HANDLER;
    features.bits.move   = PRIVATE_HANDLER;
    register_gadget_type(0, ScrollList_Type, ScrollListValidFlags,
    		features.mask, TextGadgets_ScrollList);

    features.mask = 0;
    features.bits.add    = PRIVATE_HANDLER;
    features.bits.mclick = DEFAULT_HANDLER;
    features.bits.method = PRIVATE_HANDLER;
    features.bits.remove = PRIVATE_HANDLER;
    features.bits.fade   = PRIVATE_HANDLER;
    features.bits.plot   = PRIVATE_HANDLER;
    features.bits.move   = PRIVATE_HANDLER;
    register_gadget_type(0, Scrollbar_Type, ScrollbarValidFlags,
    		features.mask, TextGadgets_Scrollbar);
}

_kernel_oserror *TextGadgets_init(const char *cmd_tail, int podule_base, void *pw)
{
    _kernel_oserror *e;

    IGNORE(cmd_tail);
    IGNORE(podule_base);
    IGNORE(pw);

#ifdef MemCheck_MEMCHECK
    MemCheck_InitNoDebug();
    MemCheck_InterceptSCLStringFunctions();
    MemCheck_SetStoreMallocFunctions(1);
    MemCheck_RedirectToFilename("adfs::4.$.memout");
#endif

    if ((e = rmensure ("Window","Toolbox.Window","1.32")) != NULL)
        return e;

#ifndef ROM
    /* Add the messages to ResourceFS */
    if ((e = objmodule_register_resources(Resources())) != NULL)
    {
        return e;
    }
#endif

    /* Point at, and open, the messages. Yes, that is a 10 letter truncated name */
    objmodule_ensure_path("TextGadgets$Path", "Resources:$.Resources.TextGadget.");
    if ((e = messages_file_open("TextGadgets:Messages")) != NULL)
        goto faildereg;
    
    register_gadgets();

    if ((e = scrolllist_init()) != NULL)
        goto failclose;

    if ((e = textarea_init()) != NULL)
        goto failclose;

    return NULL;

failclose:
    messages_file_close();
faildereg:
#ifndef ROM
    objmodule_deregister_resources(Resources());
#endif
    return e;
}

void TextGadgets_services(int service_number, _kernel_swi_regs *r, void *pw)
{
    IGNORE(pw);
    IGNORE(r);

#ifdef MemCheck_MEMCHECK
    MemCheck_RegisterMiscBlock(r, sizeof(_kernel_swi_regs));
#endif

    switch (service_number)
    {
        case Service_WindowModuleStarting:
            register_gadgets();
            break;

        case Service_RedrawingWindow:
            redrawing_window = r->r[0];
            break;

#ifndef ROM
        case Service_ResourceFSStarting:
            (*(void (*)(int, void *, void *, void *))r->r[2])(Resources(), 0, 0, (void *)r->r[3]);
            break;
#endif
        default:
            break;
    }

#ifdef MemCheck_MEMCHECK
    MemCheck_UnRegisterMiscBlock(r);
#endif
}

_kernel_oserror *TextGadgets_final(int fatal, int podule, void *pw)
{
    IGNORE(fatal);
    IGNORE(podule);
    IGNORE(pw);

    if(textarea_active() || scrolllist_active() || scrollbar_active())
        return make_error(TextGadgets_TasksActive, 0);

    deregister_gadget_type(0, TextArea_Type, TextGadgets_TextArea);
    deregister_gadget_type(0, ScrollList_Type, TextGadgets_ScrollList);
    deregister_gadget_type(0, Scrollbar_Type, TextGadgets_Scrollbar);

    scrolllist_die();
    scrollbar_die();
    textarea_die();

    /* Close the messages (and deregister if not in ROM) */
    messages_file_close();
#ifndef ROM
    objmodule_deregister_resources(Resources());
#endif
    
#ifdef MemCheck_MEMCHECK
    MemCheck_OutputBlocksInfo();
#endif

    return NULL;
}

_kernel_oserror *TextGadgets_SWI_handler(int swi_no, _kernel_swi_regs *r,
		void *pw)
{
    _kernel_oserror *e = NULL;

    IGNORE(pw);

#ifdef MemCheck_MEMCHECK
    MemCheck_RegisterMiscBlock(r, sizeof(_kernel_swi_regs));
#endif

    switch (swi_no) {
        case (TextGadgets_TextArea - TextGadgets_SWIChunkBase):
           switch (r->r[2]) {
              case GADGET_ADD:
#ifdef MemCheck_MEMCHECK
                MemCheck_RegisterMiscBlock((void*)r->r[3], sizeof(TextArea));
#endif
                e = textarea_add((TextArea *) r->r[3],r->r[5],r->r[4],
                	(int **) &(r->r[1]),(int **) &(r->r[0]));
#ifdef MemCheck_MEMCHECK
                MemCheck_UnRegisterMiscBlock((void*)r->r[3]);
#endif
                break;
              case GADGET_METHOD:
                e = textarea_method((PrivateTextArea *) r->r[3],
                	(_kernel_swi_regs *)(r->r[4]));
                break;
              case GADGET_REMOVE:
                e = textarea_remove((PrivateTextArea *) r->r[3]);
                break;
              case GADGET_FADE:
                e = textarea_fade((PrivateTextArea *) r->r[3],r->r[4]);
                break;
              case GADGET_PLOT:
                e = textarea_plot((TextArea *) r->r[3]);
                break;
              case GADGET_MOVE:
                e = textarea_move((int) r->r[1], (PrivateTextArea *) r->r[3],
                	(wimp_Bbox *) r->r[5]);
                break;
              default:
                break;

           }
           break;

        case (TextGadgets_ScrollList - TextGadgets_SWIChunkBase):
           switch (r->r[2]) {
              case GADGET_ADD:
#ifdef MemCheck_MEMCHECK
                MemCheck_RegisterMiscBlock((void*)r->r[3], sizeof(ScrollList));
#endif
                e = scrolllist_add((ScrollList *) r->r[3],r->r[5],r->r[4],
                	(int **) &(r->r[1]),(int **) &(r->r[0]));
#ifdef MemCheck_MEMCHECK
                MemCheck_UnRegisterMiscBlock((void*)r->r[3]);
#endif
                break;
              case GADGET_METHOD:
                e = scrolllist_method((PrivateScrollList *) r->r[3],
                	(_kernel_swi_regs *)(r->r[4]));
                break;
              case GADGET_REMOVE:
                e = scrolllist_remove((PrivateScrollList *) r->r[3]);
                break;
              case GADGET_FADE:
                e = scrolllist_fade((PrivateScrollList *) r->r[3],r->r[4]);
                break;
              case GADGET_PLOT:
                e = scrolllist_plot((ScrollList *) r->r[3]);
                break;
              case GADGET_MOVE:
                e = scrolllist_move((int) r->r[1],
                	(PrivateScrollList *) r->r[3],
                	(wimp_Bbox *) r->r[5]);
                break;
              default:
                break;

           }
           break;

        case (TextGadgets_Scrollbar - TextGadgets_SWIChunkBase):
           switch (r->r[2]) {
              case GADGET_ADD:
#ifdef MemCheck_MEMCHECK
                MemCheck_RegisterMiscBlock((void*)r->r[3], sizeof(Scrollbar));
#endif
                e = scrollbar_add((Scrollbar *) r->r[3],r->r[5],r->r[4],
                	(int **) &(r->r[1]),(int **) &(r->r[0]));
#ifdef MemCheck_MEMCHECK
                MemCheck_UnRegisterMiscBlock((void*)r->r[3]);
#endif
                break;
              case GADGET_METHOD:
                e = scrollbar_method((PrivateScrollbar *) r->r[3],
                	(_kernel_swi_regs *)(r->r[4]));
                break;
              case GADGET_REMOVE:
                e = scrollbar_remove((PrivateScrollbar *) r->r[3]);
                break;
              case GADGET_FADE:
                e = scrollbar_fade((PrivateScrollbar *) r->r[3],r->r[4]);
                break;
              case GADGET_PLOT:
                e = scrollbar_plot((Scrollbar *) r->r[3]);
                break;
              case GADGET_MOVE:
                e = scrollbar_move((PrivateScrollbar*)r->r[3],
                				(wimp_Bbox *)r->r[5]);
              	break;
              default:
                break;

           }
           break;

        case (TextGadgets_RedrawAll - TextGadgets_SWIChunkBase):
//            e = scrolllist_redraw_all(r->r[0], r->r[1]);
            // add other gadget redraw functions here...
            break;

        case (TextGadgets_Filter - TextGadgets_SWIChunkBase):
            textarea_filter(r);
            scrolllist_filter(r);
            scrollbar_filter(r);
            break;

        default:
            e = error_BAD_SWI;
            break;
    }

#ifdef MemCheck_MEMCHECK
    MemCheck_UnRegisterMiscBlock(r);
#endif

    return e;
}

/* ------------------------------------------------------------------------
 */
//_kernel_oserror *redraw_gadget(int window_handle, GadgetHeader *hdr)
//{
//    wimp_GetWindowState	state;
//    _kernel_oserror		*e;
//
//    state.window_handle = window_handle;
//
//    if ((e = wimp_get_window_state(&state)) != NULL)
//        return e;
//
//    if (state.flags & WimpWindow_Open)
//    {
//        wimp_force_redraw(window_handle, hdr->box.xmin, hdr->box.ymin,
//        			hdr->box.xmax, hdr->box.ymax);
//    }
//
//    return NULL;
//}
