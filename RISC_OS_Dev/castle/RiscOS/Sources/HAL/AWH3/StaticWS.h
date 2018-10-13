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
#ifndef H_STATICWS_H
#define H_STATICWS_H

#pragma force_top_level
#pragma include_only_once

#define IO_BaseAddr                              (0)
#define SRAM_A1_BaseAddr                         (4)
#define SRAM_A2_BaseAddr                         (8)
#define SRAM_C_BaseAddr                          (12)
#define VRAM_BaseAddr                            (16)
#define CPUCFG_BaseAddr                          (20)
#define MPU_INTC_Log                             (24)
#define SCU_Log                                  (24)
#define SCU_BaseAddr                             (24)
#define USB_Host_BaseAddr                        (28)
#define USB_OTG_BaseAddr                         (32)
#define IRQDi_Log                                (36)
#define GIC_DISTBaseAddr                         (36)
#define IRQC_Log                                 (40)
#define GIC_CPUIFBaseAddr                        (40)
#define TIMER_Log                                (44)
#define HS_TMR_Log                               (48)
#define NCNBWorkspace                            (52)
#define NCNBAllocNext                            (56)
#define CCU_BaseAddr                             (60)
#define OSheader                                 (64)
#define HDMI_BaseAddr                            (68)
#define DebugUART                                (72)
#define HALUART                                  (76)
#define HALUART_Log                              (76)
#define UART_0_Log                               (76)
#define UART_1_Log                               (80)
#define UART_2_Log                               (84)
#define UART_3_Log                               (88)
#define HALUARTIRQ                               (92)
#define DefaultUART                              (96)
#define NumUART                                  (97)
#define padding                                  (98)
#define SimulatedCMOS                            (100)
#define HAL_WsSize                               (2148)
#define sizeof_workspace                         (2148)
#endif
