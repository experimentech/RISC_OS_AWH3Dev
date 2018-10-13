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
/* Created by Hdr2H.  Do not edit.*/
#ifndef GLOBAL_VIDCLIST_H
#define GLOBAL_VIDCLIST_H

#pragma force_top_level
#pragma include_only_once

#define VIDCList3_Type                           (0)
#define VIDCList3_PixelDepth                     (4)
#define VIDCList3_HorizSyncWidth                 (8)
#define VIDCList3_HorizBackPorch                 (12)
#define VIDCList3_HorizLeftBorder                (16)
#define VIDCList3_HorizDisplaySize               (20)
#define VIDCList3_HorizRightBorder               (24)
#define VIDCList3_HorizFrontPorch                (28)
#define VIDCList3_VertiSyncWidth                 (32)
#define VIDCList3_VertiBackPorch                 (36)
#define VIDCList3_VertiTopBorder                 (40)
#define VIDCList3_VertiDisplaySize               (44)
#define VIDCList3_VertiBottomBorder              (48)
#define VIDCList3_VertiFrontPorch                (52)
#define VIDCList3_PixelRate                      (56)
#define VIDCList3_SyncPol                        (60)
#define VIDCList3_ControlList                    (64)
#define ControlList_LCDMode                      (1)
#define ControlList_LCDDualPanelMode             (2)
#define ControlList_LCDOffset0                   (3)
#define ControlList_LCDOffset1                   (4)
#define ControlList_HiResMode                    (5)
#define ControlList_DACControl                   (6)
#define ControlList_RGBPedestals                 (7)
#define ControlList_ExternalRegister             (8)
#define ControlList_HClockSelect                 (9)
#define ControlList_RClockFrequency              (10)
#define ControlList_DPMSState                    (11)
#define ControlList_Interlaced                   (12)
#define ControlList_OutputFormat                 (13)
#define ControlList_ExtraBytes                   (14)
#define ControlList_NColour                      (15)
#define ControlList_ModeFlags                    (16)
#define ControlList_InvalidReason                (17)
#define ControlList_Terminator                   (-1)
#define SyncPol_InvertHSync                      (1)
#define SyncPol_InvertVSync                      (2)
#define SyncPol_InterlaceSpecified               (4)
#define SyncPol_Interlace                        (8)
#endif
