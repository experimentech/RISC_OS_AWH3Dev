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
#ifndef GLOBAL_OSENTRIES_H
#define GLOBAL_OSENTRIES_H

#pragma force_top_level
#pragma include_only_once

#define OS_InitARM                               (0)
#define OS_AddRAM                                (1)
#define OS_Start                                 (2)
#define OS_MapInIO                               (3)
#define OS_AddDevice                             (4)
#define OS_LogToPhys                             (5)
#define OS_IICOpV                                (6)
#define HighestOSEntry                           (7 - 1)
#define OSHdr_Magic                              (0)
#define OSHdr_Flags                              (4)
#define OSHdr_ImageSize                          (8)
#define OSHdr_Entries                            (12)
#define OSHdr_NumEntries                         (16)
#define OSHdr_CompressedSize                     (20)
#define OSHdr_DecompressHdr                      (24)
#define OSHdr_CompressOffset                     (28)
#define OSHdr_size                               (32)
#define OSHdrFlag_SupportsCompression            (1)
#define OSHdr_ValidFlags                         (1)
#define OSStartFlag_POR                          (1 << 0)
#define OSStartFlag_NoCMOSReset                  (1 << 1)
#define OSStartFlag_CMOSReset                    (1 << 2)
#define OSStartFlag_NoCMOS                       (1 << 3)
#define OSStartFlag_RAMCleared                   (1 << 4)
#define OSDecompHdr_WSSize                       (0)
#define OSDecompHdr_Code                         (4)
#define OSDecompHdr_size                         (8)
#define OSAddRAM_IsVRAM                          (1 << 0)
#define OSAddRAM_VRAMNotForGeneralUse            (1 << 1)
#define OSAddRAM_NoDMA                           (1 << 7)
#define OSAddRAM_Speed                           (1 << 8)
#endif
