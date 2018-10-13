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
#ifndef H_SHARED_H
#define H_SHARED_H

#pragma force_top_level
#pragma include_only_once

#define XCRelocOffset                            (0)
#define RoundingMode                             (4)
#define XFlags                                   (5)
#define ExceptionFlags                           (6)
#define ExceptionEnable                          (7)
#define Reg_D                                    (8)
#define Reg_N                                    (12)
#define Reg_M                                    (16)
#define TheInstruction                           (20)
#define TheFPEXC                                 (24)
#define TheContext                               (28)
#define Workspace                                (32)
#define UserRegisters                            (36)
#define UserPSR                                  (100)
#define CLASS_NOT_VFP                            (1)
#define CLASS_NOT_CDP                            (2)
#define CLASS_VFP3                               (4)
#define CLASS_VFP4                               (8)
#define CLASS_S                                  (16)
#define CLASS_D                                  (32)
#define CLASS_D32                                (64)
#define CLASS_HP                                 (128)
#define CLASS_SQRT                               (256)
#define CLASS_DIV                                (512)
#define REG_FPSID                                (0)
#define REG_FPSCR                                (1)
#define REG_MVFR1                                (6)
#define REG_MVFR0                                (7)
#define REG_FPEXC                                (8)
#define REG_FPINST                               (9)
#define REG_FPINST2                              (10)
#endif
