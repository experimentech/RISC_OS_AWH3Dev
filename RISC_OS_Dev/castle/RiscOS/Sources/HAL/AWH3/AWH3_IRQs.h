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
#ifndef H_AWH3_IRQS_H
#define H_AWH3_IRQS_H

#pragma force_top_level
#pragma include_only_once

#define INT_SGI_0                                (0)
#define INT_SGI_1                                (1)
#define INT_SGI_2                                (2)
#define INT_SGI_3                                (3)
#define INT_SGI_4                                (4)
#define INT_SGI_5                                (5)
#define INT_SGI_6                                (6)
#define INT_SGI_7                                (7)
#define INT_SGI_8                                (8)
#define INT_SGI_9                                (9)
#define INT_SGI_10                               (10)
#define INT_SGI_11                               (11)
#define INT_SGI_12                               (12)
#define INT_SGI_13                               (13)
#define INT_SGI_14                               (14)
#define INT_SGI_15                               (15)
#define INT_PPI_0                                (16)
#define INT_PPI_1                                (17)
#define INT_PPI_2                                (18)
#define INT_PPI_3                                (19)
#define INT_PPI_4                                (20)
#define INT_PPI_5                                (21)
#define INT_PPI_6                                (22)
#define INT_PPI_7                                (23)
#define INT_PPI_8                                (24)
#define INT_PPI_9                                (25)
#define INT_PPI_10                               (26)
#define INT_PPI_11                               (27)
#define INT_PPI_12                               (28)
#define INT_PPI_13                               (29)
#define INT_PPI_14                               (30)
#define INT_PPI_15                               (31)
#define INT_UART_0                               (32)
#define INT_UART_1                               (33)
#define INT_UART_2                               (34)
#define INT_UART_3                               (35)
#define INT_TWI_0                                (38)
#define INT_TWI_1                                (39)
#define INT_TWI_2                                (40)
#define INT_PA_EINT                              (43)
#define INT_OWA                                  (44)
#define INT_I2S_PCM0                             (45)
#define INT_I2S_PCM1                             (46)
#define INT_I2S_PCM2                             (47)
#define INT_PG_EINT                              (49)
#define INT_TIMER_0                              (50)
#define INT_TIMER_1                              (51)
#define INT_WATCHDOG                             (57)
#define INT_AUDIO_CODEC                          (61)
#define INT_KEYADC                               (62)
#define INT_THS                                  (63)
#define INT_EXTERNAL_NMI                         (64)
#define INT_R_TIMER_0                            (65)
#define INT_R_TIMER_1                            (66)
#define INT_R_WATCHDOG                           (68)
#define INT_CIR_RX                               (69)
#define INT_R_UART                               (70)
#define INT_R_ALARM_0                            (72)
#define INT_R_ALARM_1                            (73)
#define INT_R_TIMER_2                            (74)
#define INT_R_TIMER_3                            (75)
#define INT_R_TWI                                (76)
#define INT_R_PL_EINT                            (77)
#define INT_R_TWD                                (78)
#define INT_M_BOX                                (81)
#define INT_DMA                                  (82)
#define INT_HS_TIMER                             (83)
#define INT_SMC                                  (88)
#define INT_VE                                   (90)
#define INT_SD_MMC_0                             (92)
#define INT_SD_MMC_1                             (93)
#define INT_SD_MMC_2                             (94)
#define INT_SPI_0                                (97)
#define INT_SPI_1                                (98)
#define INT_NAND                                 (102)
#define INT_USB_OTG_DEVICE                       (103)
#define INT_USB_OTG_EHCI_0                       (104)
#define INT_USB_OTG_OHCI_0                       (105)
#define INT_USB_EHCI_1                           (106)
#define INT_USB_OHCI_1                           (107)
#define INT_USB_EHCI_2                           (108)
#define INT_USB_OHCI_2                           (109)
#define INT_USB_EHCI_3                           (110)
#define INT_USB_OHCI_3                           (111)
#define INT_SS_S                                 (112)
#define INT_TS                                   (113)
#define INT_EMAC                                 (114)
#define INT_SCR                                  (115)
#define INT_CSI                                  (116)
#define INT_CSI_CCI                              (117)
#define INT_LCD_0                                (118)
#define INT_LCD_1                                (119)
#define INT_HDMI                                 (120)
#define INT_TVE                                  (124)
#define INT_DIT                                  (125)
#define INT_SS_NS                                (126)
#define INT_DE                                   (127)
#define INT_GPU_GP                               (129)
#define INT_GPU_GPMMU                            (130)
#define INT_GPU_PP0                              (131)
#define INT_GPU_PPMMU0                           (132)
#define INT_GPU_PMU                              (133)
#define INT_GPU_PP1                              (134)
#define INT_GPU_PPMMU1                           (135)
#define INT_CTI0                                 (140)
#define INT_CTI1                                 (141)
#define INT_CTI2                                 (142)
#define INT_CTI3                                 (143)
#define INT_COMMTX0                              (144)
#define INT_COMMTX1                              (145)
#define INT_COMMTX2                              (146)
#define INT_COMMTX3                              (147)
#define INT_COMMRX0                              (148)
#define INT_COMMRX1                              (149)
#define INT_COMMRX2                              (150)
#define INT_COMMRX3                              (151)
#define INT_PMU0                                 (152)
#define INT_PMU1                                 (153)
#define INT_PMU2                                 (154)
#define INT_PMU3                                 (155)
#define INT_AXI_ERROR                            (156)
#define SW_INTERRUPT_0                           (INT_SGI_0)
#define SW_INTERRUPT_1                           (INT_SGI_1)
#define SW_INTERRUPT_2                           (INT_SGI_2)
#define SW_INTERRUPT_3                           (INT_SGI_3)
#define SW_INTERRUPT_4                           (INT_SGI_4)
#define SW_INTERRUPT_5                           (INT_SGI_5)
#define SW_INTERRUPT_6                           (INT_SGI_6)
#define SW_INTERRUPT_7                           (INT_SGI_7)
#define SW_INTERRUPT_8                           (INT_SGI_8)
#define SW_INTERRUPT_9                           (INT_SGI_9)
#define SW_INTERRUPT_10                          (INT_SGI_10)
#define SW_INTERRUPT_11                          (INT_SGI_11)
#define SW_INTERRUPT_12                          (INT_SGI_12)
#define SW_INTERRUPT_13                          (INT_SGI_13)
#define SW_INTERRUPT_14                          (INT_SGI_14)
#define SW_INTERRUPT_15                          (INT_SGI_15)
#define IMX_INT_UART1                            (INT_UART_0)
#define IMX_INT_UART2                            (INT_UART_1)
#define IMX_INT_UART3                            (INT_UART_2)
#define IMX_INT_UART4                            (INT_UART_3)
#define IMX_INT_I2C1                             (INT_TWI_0)
#define IMX_INT_I2C2                             (INT_TWI_1)
#define IMX_INT_I2C3                             (INT_TWI_2)
#define IMX_INT_TEMPERATURE                      (INT_THS)
#define IMX_INT_WDOG1                            (INT_WATCHDOG)
#endif