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

#define OSentries                                (0)
#define IO_BaseAddr                              (32)
#define SRAM_A1_BaseAddr                         (36)
#define SRAM_A2_BaseAddr                         (40)
#define SRAM_C_BaseAddr                          (44)
#define VRAM_BaseAddr                            (48)
#define CPUCFG_BaseAddr                          (52)
#define MPU_INTC_Log                             (56)
#define SCU_Log                                  (56)
#define SCU_BaseAddr                             (56)
#define PIO_BaseAddr                             (60)
#define R_PIO_BaseAddr                           (64)
#define USB_Host_BaseAddr                        (68)
#define USB_OTG_BaseAddr                         (72)
#define IRQDi_Log                                (76)
#define GIC_DISTBaseAddr                         (76)
#define IRQC_Log                                 (80)
#define GIC_CPUIFBaseAddr                        (80)
#define TIMER_Log                                (84)
#define HS_TMR_Log                               (88)
#define NCNBWorkspace                            (92)
#define NCNBAllocNext                            (96)
#define CCU_BaseAddr                             (100)
#define MMC_BaseAddr                             (104)
#define OSheader                                 (108)
#define HDMI_BaseAddr                            (112)
#define PointerPhys                              (116)
#define PointerLog                               (120)
#define PointerPal                               (124)
#define PointerX                                 (140)
#define PointerY                                 (144)
#define PointerPalDirty                          (148)
#define PointerDisabled                          (149)
#define IPU1_Log                                 (152)
#define IPU2_Log                                 (156)
#define DebugUART                                (160)
#define HALUART                                  (164)
#define HALUART_Log                              (164)
#define UART_0_Log                               (164)
#define UART_1_Log                               (168)
#define UART_2_Log                               (172)
#define UART_3_Log                               (176)
#define HALUARTIRQ                               (180)
#define DefaultUART                              (184)
#define NumUART                                  (185)
#define padding                                  (186)
#define SimulatedCMOS                            (188)
#define HAL_WsSize                               (2236)
#define sizeof_workspace                         (2236)
#endif
