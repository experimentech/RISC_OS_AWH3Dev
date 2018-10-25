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
#ifndef H_GPIO_H
#define H_GPIO_H

#pragma force_top_level
#pragma include_only_once

#define P0_CFG0                                  (0x0)
#define P0_CFG1                                  (0x4)
#define P0_CFG2                                  (0x8)
#define P0_CFG3                                  (0xc)
#define P1_CFG0                                  (0x24)
#define P1_CFG1                                  (0x28)
#define P1_CFG2                                  (0x2c)
#define P1_CFG3                                  (0x30)
#define P2_CFG0                                  (0x48)
#define P2_CFG1                                  (0x4c)
#define P2_CFG2                                  (0x50)
#define P2_CFG3                                  (0x54)
#define P3_CFG0                                  (0x6c)
#define P3_CFG1                                  (0x70)
#define P3_CFG2                                  (0x74)
#define P3_CFG3                                  (0x78)
#define P4_CFG0                                  (0x90)
#define P4_CFG1                                  (0x94)
#define P4_CFG2                                  (0x98)
#define P4_CFG3                                  (0x9c)
#define P5_CFG0                                  (0xb4)
#define P5_CFG1                                  (0xb8)
#define P5_CFG2                                  (0xbc)
#define P5_CFG3                                  (0xc0)
#define P6_CFG0                                  (0xd8)
#define P6_CFG1                                  (0xdc)
#define P6_CFG2                                  (0xe0)
#define P6_CFG3                                  (0xe4)
#define P0_DAT                                   (0x10)
#define P1_DAT                                   (0x34)
#define P2_DAT                                   (0x58)
#define P3_DAT                                   (0x7c)
#define P4_DAT                                   (0xa0)
#define P5_DAT                                   (0xc4)
#define P6_DAT                                   (0xe8)
#define P0_DRV0                                  (0x14)
#define P0_DRV1                                  (0x18)
#define P1_DRV0                                  (0x38)
#define P1_DRV1                                  (0x3c)
#define P2_DRV0                                  (0x5c)
#define P2_DRV1                                  (0x60)
#define P3_DRV0                                  (0x80)
#define P3_DRV1                                  (0x84)
#define P4_DRV0                                  (0xa4)
#define P4_DRV1                                  (0xa8)
#define P5_DRV0                                  (0xc8)
#define P5_DRV1                                  (0xcb)
#define P6_DRV0                                  (0xd8)
#define P6_DRV1                                  (0xe0)
#define P0_PUL0                                  (0x1c)
#define P0_PUL1                                  (0x20)
#define P1_PUL0                                  (0x40)
#define P1_PUL1                                  (0x44)
#define P2_PUL0                                  (0x64)
#define P2_PUL1                                  (0x68)
#define P3_PUL0                                  (0x88)
#define P3_PUL1                                  (0x8c)
#define P4_PUL0                                  (0xac)
#define P4_PUL1                                  (0xb0)
#define P5_PUL0                                  (0xd0)
#define P5_PUL1                                  (0xd4)
#define P6_PUL0                                  (0xf4)
#define P6_PUL1                                  (0xf8)
#define PA_INT_CFG0                              (0x200)
#define PA_INT_CFG1                              (0x204)
#define PA_INT_CFG2                              (0x208)
#define PA_INT_CFG3                              (0x20c)
#define PA_INT_CTL                               (0x210)
#define PA_INT_STA                               (0x214)
#define PA_INT_DEB                               (0x218)
#define PG_INT_CFG0                              (0x220)
#define PG_INT_CFG1                              (0x224)
#define PG_INT_CFG2                              (0x228)
#define PG_INT_CFG3                              (0x22c)
#define PG_INT_CTL                               (0x230)
#define PG_INT_STA                               (0x234)
#define PG_INT_DEB                               (0x238)
#define PA7_SELECT                               (28)
#define PA6_SELECT                               (24)
#define PA5_SELECT                               (20)
#define PA4_SELECT                               (16)
#define PA3_SELECT                               (12)
#define PA2_SELECT                               (8)
#define PA1_SELECT                               (4)
#define PA0_SELECT                               (0)
#define PA_15_SELECT                             (28)
#define PA_14_SELECT                             (24)
#define PA_13_SELECT                             (20)
#define PA_12_SELECT                             (16)
#define PA_11_SELECT                             (12)
#define PA_10_SELECT                             (8)
#define PA_9_SELECT                              (4)
#define PA_8_SELECT                              (0)
#define PA21_SELECT                              (20)
#define PA20_SELECT                              (16)
#define PA19_SELECT                              (12)
#define PA18_SELECT                              (8)
#define PA17_SELECT                              (4)
#define PA16_SELECT                              (0)
#define PA_DAT                                   (0x3fffff)
#endif
