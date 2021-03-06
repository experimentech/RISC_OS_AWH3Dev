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
/* File:    gadgets.h
 * Purpose: Text Gadgets
 *
 */

#ifndef __gadgets_h
#define __gadgets_h

#ifndef __toolbox_h
#include "objects/toolbox.h"
#endif

#ifndef __window_h
#include "objects/window.h"
#endif

/* Gadgets SWI calls ****************************************************************************/

#define TextGadgets_SWIChunkBase    0x140180
#define TextGadgets_TextArea        (TextGadgets_SWIChunkBase + 0)
#define TextGadgets_TextField       (TextGadgets_SWIChunkBase + 1)
#define TextGadgets_ScrollList      (TextGadgets_SWIChunkBase + 2)
#define TextGadgets_Scrollbar       (TextGadgets_SWIChunkBase + 3)
#define TextGadgets_RedrawAll       (TextGadgets_SWIChunkBase + 4)
#define TextGadgets_Filter          (TextGadgets_SWIChunkBase + 5)

/* Gadgets Errors *******************************************************************************/

#define TextGadgets_ErrorBase       (Program_Error | 0x0081A300)

#define TextGadgets_TasksActive     (TextGadgets_ErrorBase+0x00) /* Gadget task(s) active */
#define TextGadgets_DuffColour      (TextGadgets_ErrorBase+0x01) /* Invalid desktop colour */
#define TextGadgets_AllocFailed     (TextGadgets_ErrorBase+0x02) /* Out of memory */
#define TextGadgets_BarAllocFailed  (TextGadgets_ErrorBase+0x03) /* Out of memory for scrollbar */
#define TextGadgets_ListAllocFailed (TextGadgets_ErrorBase+0x04) /* Out of memory for scrolllist */
#define TextGadgets_AreaAllocFailed (TextGadgets_ErrorBase+0x05) /* Out of memory for textarea */
#define TextGadgets_FontScanStrange (TextGadgets_ErrorBase+0x06) /* Font_ScanString strange */
#define TextGadgets_IntMallocFail   (TextGadgets_ErrorBase+0x07) /* Int err - Out of memory */
#define TextGadgets_IntNoSuchBlock  (TextGadgets_ErrorBase+0x08) /* Int err - Block does not exist */
#define TextGadgets_IntReinitMem    (TextGadgets_ErrorBase+0x09) /* Int err - Attempt to reinitialise memory */
#define TextGadgets_IntNeverInit    (TextGadgets_ErrorBase+0x0A) /* Int err - Memory has not been initialised */
#define TextGadgets_UKScrollbar     (TextGadgets_ErrorBase+0x0B) /* No such scrollbar */
#define TextGadgets_UKScrollList    (TextGadgets_ErrorBase+0x0C) /* No such scrolllist */
#define TextGadgets_UKTextArea      (TextGadgets_ErrorBase+0x0D) /* No such textarea */
#define TextGadgets_BadIndex        (TextGadgets_ErrorBase+0x0E) /* Bad index */

/* TextArea flags *******************************************************************************/

#define TextArea_Scrollbar_Vertical     0x00000001
#define TextArea_Scrollbar_Horizontal   0x00000002
#define TextArea_WordWrap               0x00000004

#define TextAreaValidFlags              0xC0000007

#define TextArea_DesktopColours         (1<<0)

/* TextArea types *******************************************************************************/

typedef struct
{
    GadgetHeader        hdr;
    int                 type;
    int                 event;
    char                *text;
    unsigned int        foreground;
    unsigned int        background;
} TextArea;

/* TextArea methods *****************************************************************************/

#define TextArea_Base                   0x4018
#define TextArea_Type                   (sizeof(TextArea)) << 16 | TextArea_Base
#define TextArea_SWIBase                0x140180

#define TextArea_GetState               (TextArea_Base + 0)
#define TextArea_SetState               (TextArea_Base + 1)
#define TextArea_SetText                (TextArea_Base + 2)
#define TextArea_GetText                (TextArea_Base + 3)
#define TextArea_InsertText             (TextArea_Base + 4)
#define TextArea_ReplaceText            (TextArea_Base + 5)
#define TextArea_GetSelection           (TextArea_Base + 6)
#define TextArea_SetSelection           (TextArea_Base + 7)
#define TextArea_SetFont                (TextArea_Base + 8)
#define TextArea_SetColour              (TextArea_Base + 9)
#define TextArea_GetColour              (TextArea_Base + 10)
#define TextArea_SetCursorPosition      (TextArea_Base + 11)
#define TextArea_GetCursorPosition      (TextArea_Base + 12)

/* TextArea events ******************************************************************************/

/* Scrollbar flags *******************************************************************************/

#define Scrollbar_Vertical      0x00000000
#define Scrollbar_Horizontal    0x00000001

#define ScrollbarValidFlags     0xC0000001

#define Scrollbar_Lower_Bound   (1<<0)
#define Scrollbar_Upper_Bound   (1<<1)
#define Scrollbar_Visible_Len   (1<<2)

#define Scrollbar_Line_Inc      (1<<0)
#define Scrollbar_Page_Inc      (1<<1)

/* Scrollbar types *******************************************************************************/

typedef struct
{
    GadgetHeader        hdr;
    int                 type;
    int                 event;
    unsigned int        min;
    unsigned int        max;
    unsigned int        value;
    unsigned int        visible;
    unsigned int        line_inc;
    unsigned int        page_inc;
} Scrollbar;

/* Scrollbar methods *****************************************************************************/

#define Scrollbar_Base          0x401B
#define Scrollbar_Type          (sizeof(Scrollbar)) << 16 | Scrollbar_Base
#define Scrollbar_SWIBase       0x140183

#define Scrollbar_GetState      (Scrollbar_Base + 0)
#define Scrollbar_SetState      (Scrollbar_Base + 1)
#define Scrollbar_SetBounds     (Scrollbar_Base + 2)
#define Scrollbar_GetBounds     (Scrollbar_Base + 3)
#define Scrollbar_SetValue      (Scrollbar_Base + 4)
#define Scrollbar_GetValue      (Scrollbar_Base + 5)
#define Scrollbar_SetIncrements (Scrollbar_Base + 6)
#define Scrollbar_GetIncrements (Scrollbar_Base + 7)
#define Scrollbar_SetEvent      (Scrollbar_Base + 8)
#define Scrollbar_GetEvent      (Scrollbar_Base + 9)

/* Scrollbar events ******************************************************************************/

#define Scrollbar_PositionChanged       (Scrollbar_SWIBase)

typedef struct
{
    ToolboxEventHeader  hdr;
    unsigned int        new_position;
    int                 direction;
} ScrollbarPositionChangedEvent;

/* ScrollList flags ******************************************************************************/

#define ScrollList_SingleSelections     0x00000000
#define ScrollList_MultipleSelections   0x00000001

#define ScrollListValidFlags            0xC0000001

#define ScrollList_DesktopColours                    (1<<0)

#define ScrollList_SelectionChangingMethod_SendEvent (1u<<0)
#define ScrollList_SelectionChangingMethod_OnAll     (1u<<1)

#define ScrollList_AddItem_MakeVisible               (1u<<3)
#define ScrollList_DeleteItems_DoNotJumpToTop        (1u<<1)

/* ScrollList types ******************************************************************************/

typedef struct
{
    GadgetHeader        hdr;
    int                 event;
    unsigned int        foreground;
    unsigned int        background;
} ScrollList;

/* ScrollList methods ****************************************************************************/

#define ScrollList_Base         0x401A
#define ScrollList_Type         (sizeof(ScrollList)) << 16 | ScrollList_Base
#define ScrollList_SWIBase      0x140182

#define ScrollList_GetState     (ScrollList_Base + 0)
#define ScrollList_SetState     (ScrollList_Base + 1)
#define ScrollList_AddItem      (ScrollList_Base + 2)
#define ScrollList_DeleteItems  (ScrollList_Base + 3)
#define ScrollList_SelectItem   (ScrollList_Base + 4)
#define ScrollList_DeselectItem (ScrollList_Base + 5)
#define ScrollList_GetSelected  (ScrollList_Base + 6)
#define ScrollList_MakeVisible  (ScrollList_Base + 7)
#define ScrollList_SetColour    (ScrollList_Base + 8)
#define ScrollList_GetColour    (ScrollList_Base + 9)
#define ScrollList_SetFont      (ScrollList_Base + 10)
#define ScrollList_GetItemText  (ScrollList_Base + 11)
#define ScrollList_CountItems   (ScrollList_Base + 12)
#define ScrollList_SetItemText  (ScrollList_Base + 13)

/* ScrollList events *****************************************************************************/

#define ScrollList_Selection    (0x140180 + 1)

#define ScrollList_Selection_Flags_Set          (1<<0)
#define ScrollList_Selection_Flags_DoubleClick  (1<<1)
#define ScrollList_Selection_Flags_AdjustClick  (1<<2)

typedef struct
{
    ToolboxEventHeader  hdr;
    unsigned int        flags;
    int                 item;
} ScrollListSelectionEvent;

#endif
