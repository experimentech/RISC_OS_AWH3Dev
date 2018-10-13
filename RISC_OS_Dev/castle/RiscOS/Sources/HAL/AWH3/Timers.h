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
#ifndef H_TIMERS_H
#define H_TIMERS_H

#pragma force_top_level
#pragma include_only_once

#define TMR_IRQ_EN_REG                           (0x0)
#define TMR_IRQ_STA_REG                          (0x4)
#define TMR0_CTRL_REG                            (0x10)
#define TMR0_INTV_VALUE_REG                      (0x14)
#define TMR0_CUR_VALUE_REG                       (0x18)
#define TMR1_CTRL_REG                            (0x20)
#define TMR1_INTV_VALUE_REG                      (0x24)
#define TMR1_CUR_VALUE_REG                       (0x28)
#define AVS_CNT_CTL_REG                          (0x80)
#define AVS_CNT_0_REG                            (0x84)
#define AVS_CNT_1_REG                            (0x88)
#define AVS_CNT_DIV_REG                          (0x8c)
#define WDOG0_IRQ_EN_REG                         (0xa0)
#define WDOG0_IRQ_STA_REG                        (0xa4)
#define WDOG0_CTRL_REG                           (0xb0)
#define WDOG0_CFG_REG                            (0xb4)
#define WDOG0_MODE_REG                           (0xb8)
#define TMR1_IRQ_EN                              (2)
#define TMR0_IRQ_EN                              (1)
#define TMR_1_IRQ_PEND                           (1)
#define TMR_0_IRQ_PEND                           (2)
#define TMR0_MODE                                (128)
#define TMR0_CLK_PRES                            (112)
#define TMR0_CLK_SRC                             (12)
#define TMR0_RELOAD                              (2)
#define TMR0_EN                                  (1)
#define TMR0_INTV_VALUE                          (0xffffffff)
#define CNT64_CLK_SRC_SEL                        (4)
#define CNT64_RL_EN                              (2)
#define CNT64_CLR_EN                             (1)
#define CNT64_LO                                 (0xffffffff)
#define CNT64_HI                                 (0xffffffff)
#endif
