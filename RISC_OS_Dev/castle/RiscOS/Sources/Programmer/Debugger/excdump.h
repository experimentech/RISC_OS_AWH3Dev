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
#ifndef H_EXCDUMP_H
#define H_EXCDUMP_H

#pragma force_top_level
#pragma include_only_once

#define ExcDump_Chunk_Memory                     (0)
#define ExcDump_Chunk_OSRSI6                     (1)
#define ExcDump_Chunk_Regs                       (2)
#define ExcDump_Chunk_Error                      (3)
#define ExcDump_Chunk_OSMem16                    (4)
#define ExcDump_Reg_R0                           (0)
#define ExcDump_Reg_R1                           (1)
#define ExcDump_Reg_R2                           (2)
#define ExcDump_Reg_R3                           (3)
#define ExcDump_Reg_R4                           (4)
#define ExcDump_Reg_R5                           (5)
#define ExcDump_Reg_R6                           (6)
#define ExcDump_Reg_R7                           (7)
#define ExcDump_Reg_R8                           (8)
#define ExcDump_Reg_R9                           (9)
#define ExcDump_Reg_R10                          (10)
#define ExcDump_Reg_R11                          (11)
#define ExcDump_Reg_R12                          (12)
#define ExcDump_Reg_R13                          (13)
#define ExcDump_Reg_R14                          (14)
#define ExcDump_Reg_R15                          (15)
#define ExcDump_Reg_CPSR                         (16)
#define ExcDump_Reg_R13_usr                      (17)
#define ExcDump_Reg_R14_usr                      (18)
#define ExcDump_Reg_R13_svc                      (19)
#define ExcDump_Reg_R14_svc                      (20)
#define ExcDump_Reg_SPSR_svc                     (21)
#define ExcDump_Reg_R13_irq                      (22)
#define ExcDump_Reg_R14_irq                      (23)
#define ExcDump_Reg_SPSR_irq                     (24)
#define ExcDump_Reg_R13_abt                      (25)
#define ExcDump_Reg_R14_abt                      (26)
#define ExcDump_Reg_SPSR_abt                     (27)
#define ExcDump_Reg_R13_und                      (28)
#define ExcDump_Reg_R14_und                      (29)
#define ExcDump_Reg_SPSR_und                     (30)
#define ExcDump_Reg_Count                        (31)
#define ExcAnnotateAll_DescribeBlocks            (1)
#endif
