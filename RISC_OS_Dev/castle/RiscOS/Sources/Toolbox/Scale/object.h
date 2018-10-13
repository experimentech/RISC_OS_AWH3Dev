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
/* Title:   object.h
 * Purpose: object list handling for the Scale module
 * Author:  TGR
 * History: 15-Feb-94: TGR: created
 *
 */


#ifndef __object_h
#define __object_h


#ifndef __window_h
#include "objects.window.h"
#endif

typedef struct _coords {
   int x,y;
} Coordinates;

typedef union _show_info {
   WindowShowObjectBlock  window_info;
   Coordinates            coords;
} ShowInfo;

typedef struct _scale_internal {
   struct _scale_internal   *forward;
   struct _scale_internal   *backward;
   int                       flags;
   int                       show_type;
   ShowInfo                 *show_info;
   ObjectID                  object_id, sub_object_id;
   int                       std_value[4];
} ScaleInternal;

#define ScaleInternal_GenerateShowEvent    0x00000001
#define ScaleInternal_GenerateHideEvent    0x00000002
#define ScaleInternal_IsShowing            0x00000010
#define ScaleInternal_MenuSemantics        0x00000100
#define ScaleInternal_SubMenuSemantics     0x00000200
#define ScaleInternal_FullInfoShow         0x00000400
#define ScaleInternal_ScaleToFit           0x00001000

#endif
