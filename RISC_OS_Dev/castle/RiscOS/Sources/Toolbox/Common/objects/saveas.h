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
/* File:    saveas.h
 * Purpose: SaveAs Objects
 * Author:  Timothy G Roddis
 * History: 16-Feb-94: TGR: created
 *
 */

#ifndef __SaveAs_h
#define __SaveAs_h

#ifndef __os_h
#include "os.h"
#endif

#ifndef __window_h
#include "objects/window.h"
#endif

#ifndef __wimp_h
#include "twimp.h"
#endif

/* SaveAs SWI calls *******************************************************************************/

#define SaveAs_SWIChunkBase    0x82bc0
#define SaveAs_ObjectClass     SaveAs_SWIChunkBase
#define SaveAs_ClassSWI        (SaveAs_SWIChunkBase + 0)
#define SaveAs_PostFilter      (SaveAs_SWIChunkBase + 1)
#define SaveAs_PreFilter       (SaveAs_SWIChunkBase + 2)

/* SaveAs Templates *******************************************************************************/

/* flags */

#define SaveAs_GenerateShowEvent             0x00000001
#define SaveAs_GenerateHideEvent             0x00000002
#define SaveAs_ExcludeSelectionButton        0x00000004
#define SaveAs_AutomaticRAMTransfer          0x00000008
#define SaveAs_ClientSupportsRAMTransfer     0x00000010

/* templates */

typedef struct
{
        int        flags;
        char      *filename;
        int        filetype;
        char      *title;
        int        max_title;
        char      *window;

} SaveAsTemplate;

/* component IDs */

#define SaveAs_ComponentIDBase              (SaveAs_SWIChunkBase<<4)

#define SaveAs_Draggable_FileIcon            (SaveAs_ComponentIDBase)
#define SaveAs_WritableField_FileName        (SaveAs_ComponentIDBase + 1)
#define SaveAs_ActionButton_Cancel           (SaveAs_ComponentIDBase + 2)
#define SaveAs_ActionButton_Save             (SaveAs_ComponentIDBase + 3)
#define SaveAs_OptionButton_Selection        (SaveAs_ComponentIDBase + 4)

/* SaveAs Methods *********************************************************************************/

#define SaveAs_GetWindowID             0
#define SaveAs_SetTitle                1
#define SaveAs_GetTitle                2
#define SaveAs_SetFileName             3
#define SaveAs_GetFileName             4
#define SaveAs_SetFileType             5
#define SaveAs_GetFileType             6
#define SaveAs_SetFileSize             7
#define SaveAs_GetFileSize             8
#define SaveAs_SelectionAvailable      9
#define SaveAs_SetDataAddress         10
#define SaveAs_BufferFilled           11
#define SaveAs_FileSaveCompleted      12

/* SaveAs Toolbox Events **************************************************************************/

#define SaveAs_AboutToBeShown     SaveAs_SWIChunkBase
#define SaveAs_DialogueCompleted  (SaveAs_SWIChunkBase + 1)
#define SaveAs_SaveToFile         (SaveAs_SWIChunkBase + 2)
#define SaveAs_FillBuffer         (SaveAs_SWIChunkBase + 3)
#define SaveAs_SaveCompleted      (SaveAs_SWIChunkBase + 4)

typedef struct {
   ToolboxEventHeader hdr;
   int                show_type;
   union {
      struct {
         int                x,y;
      } coords;
      WindowShowObjectBlock full;

   } info;

} SaveAs_AboutToBeShown_Event;

typedef struct {
   ToolboxEventHeader hdr;
} SaveAs_DialogueCompleted_Event;

typedef struct {
   ToolboxEventHeader hdr;
   char               filename [212];
} SaveAs_SaveToFile_Event;

typedef struct {
   ToolboxEventHeader hdr;
   int                size;
   char              *address;
   int                no_bytes;
} SaveAs_FillBuffer_Event;

typedef struct {
   ToolboxEventHeader hdr;
   int                wimp_message_no;
   char               filename [208];
} SaveAs_SaveCompleted_Event;

/* SaveAs Errors **********************************************************************************/


#define SaveAs_ErrorBase           (Program_Error | 0x0080B600)

#define SaveAs_TasksActive        (SaveAs_ErrorBase+0x00)
#define SaveAs_AllocFailed        (SaveAs_ErrorBase+0x01)
#define SaveAs_ShortBuffer        (SaveAs_ErrorBase+0x02)
#define SaveAs_FileNameTooLong    (SaveAs_ErrorBase+0x03)
#define SaveAs_NoSuchTask         (SaveAs_ErrorBase+0x11)
#define SaveAs_NoSuchMethod       (SaveAs_ErrorBase+0x12)
#define SaveAs_NoSuchMiscOpMethod (SaveAs_ErrorBase+0x13)
#define SaveAs_NotType1           (SaveAs_ErrorBase+0x21)
#define SaveAs_NotType3           (SaveAs_ErrorBase+0x23)
#define SaveAs_BufferExceeded     (SaveAs_ErrorBase+0x31)
#define SaveAs_DataAddressUnset   (SaveAs_ErrorBase+0x32)
#define SaveAs_NotFullPath        ((SaveAs_ErrorBase+0x33) & 0xFFFFFFuL) /* Not a program error */
#define SaveAs_SaveFailed         ((SaveAs_ErrorBase+0x34) & 0xFFFFFFuL) /* Not a program error */

#endif
