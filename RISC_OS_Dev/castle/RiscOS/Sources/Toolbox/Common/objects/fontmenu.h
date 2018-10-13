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
/* File:    fontmenu.h
 * Purpose: Font Menu Objects
 * Author:  Timothy G Roddis
 * History: 10-Jan-94: TGR: created
 *
 */

#ifndef __fontmenu_h
#define __fontmenu_h

#ifndef __toolbox_h
#include "objects/toolbox.h"
#endif


/* Font Menu Templates **************************************************************************/

#define FontMenu_GenerateShowEvent     0x00000001
#define FontMenu_GenerateHideEvent     0x00000002
#define FontMenu_SystemFont            0x00000004

typedef struct
{
        int   flags;
        char *ticked_font;
} FontMenuTemplate;

/* Font Menu SWI calls **************************************************************************/

#define FontMenu_SWIChunkBase    0x82a40
#define FontMenu_ObjectClass     FontMenu_SWIChunkBase
#define FontMenu_ClassSWI        (FontMenu_SWIChunkBase + 0)
#define FontMenu_PostFilter      (FontMenu_SWIChunkBase + 1)
#define FontMenu_PreFilter       (FontMenu_SWIChunkBase + 2)

/* Font Menu Methods ****************************************************************************/

#define FontMenu_SetFont 0
#define FontMenu_GetFont 1

/* Font Menu Toolbox Events *********************************************************************/

#define FontMenu_AboutToBeShown     FontMenu_SWIChunkBase
#define FontMenu_HasBeenHidden      (FontMenu_SWIChunkBase + 1)
#define FontMenu_Selection          (FontMenu_SWIChunkBase + 2)

typedef struct {
   ToolboxEventHeader hdr;
   int                show_type;
   int                x,y;
} FontMenu_AboutToBeShown_Event;

typedef struct {
   ToolboxEventHeader hdr;
} FontMenu_HasBeenHidden_Event;

typedef struct {
   ToolboxEventHeader hdr;
   char               font_id[216];
} FontMenu_Selection_Event;


/* Font Menu Errors ******************************************************************************/

#define FontMenu_ErrorBase           (Program_Error | 0x0080B000)

#define FontMenu_AllocFailed        (FontMenu_ErrorBase+0x01)
#define FontMenu_ShortBuffer        (FontMenu_ErrorBase+0x02)
#define FontMenu_NoSuchTask         (FontMenu_ErrorBase+0x11)
#define FontMenu_NoSuchMethod       (FontMenu_ErrorBase+0x12)
#define FontMenu_NoSuchMiscOpMethod (FontMenu_ErrorBase+0x13)
#define FontMenu_TasksActive        (FontMenu_ErrorBase+0x00)

#endif
