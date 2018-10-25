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
#ifndef H_UART_H
#define H_UART_H

#pragma force_top_level
#pragma include_only_once

#define UART_Number                              (4)
#define UART_RBR                                 (0x0)
#define UART_THR                                 (0x0)
#define UART_DLL                                 (0x0)
#define UART_DLH                                 (0x4)
#define UART_IER                                 (0x4)
#define UART_IIR                                 (0x8)
#define UART_FCR                                 (0x8)
#define UART_LCR                                 (0xc)
#define UART_MCR                                 (0x10)
#define UART_LSR                                 (0x14)
#define UART_MSR                                 (0x18)
#define UART_SCH                                 (0x1c)
#define UART_USR                                 (0x7c)
#define UART_TFL                                 (0x80)
#define UART_RFL                                 (0x84)
#define UART_HALT                                (0xa4)
#define RBR_RBR                                  (255)
#define THR_THR                                  (255)
#define DLL_DLL                                  (255)
#define DLH_DLH                                  (255)
#define IER_PTIME                                (128)
#define IER_EDSSI                                (8)
#define IER_ELSI                                 (4)
#define IER_ETBEI                                (2)
#define IER_ERBFI                                (1)
#define IIR_FEFLAG                               (192)
#define IIR_IID                                  (15)
#define FCR_RT                                   (192)
#define FCR_TFT                                  (48)
#define FCR_DMAM                                 (8)
#define FCR_XFIFOR                               (4)
#define FCR_RFIFOR                               (2)
#define FCR_FIFOE                                (1)
#define LCR_DLAB                                 (128)
#define LCR_BC                                   (64)
#define LCR_EPS                                  (48)
#define LCR_PEN                                  (8)
#define LCR_STOP                                 (4)
#define LCR_DLS                                  (3)
#define MCR_AFCE                                 (32)
#define MCR_LOOP                                 (16)
#define MCR_RTS                                  (2)
#define MCR_DTR                                  (1)
#define LSR_FIFOERR                              (128)
#define LSR_TEMT                                 (64)
#define LSR_THRE                                 (32)
#define LSR_BI                                   (16)
#define LSR_FE                                   (8)
#define LSR_PE                                   (4)
#define LSR_OE                                   (2)
#define LSR_DR                                   (1)
#define MSR_DCD                                  (128)
#define MSR_RI                                   (64)
#define MSR_DSR                                  (32)
#define MSR_CTS                                  (16)
#define MSR_DDCD                                 (8)
#define MSR_TERI                                 (4)
#define MSR_DDSR                                 (2)
#define MSR_DCTS                                 (1)
#define SCH_SCRATCH_REG                          (255)
#define USR_RFF                                  (16)
#define USR_RFNE                                 (8)
#define USR_TFE                                  (4)
#define USR_TFNF                                 (2)
#define USR_BUSY                                 (1)
#define TFL_TFL                                  (127)
#define HALT_SIR_RX_INVERT                       (32)
#define HALT_SIR_TX_INVERT                       (16)
#define HALT_CHANGE_UPDATE                       (4)
#define HALT_CHCFG_AT_BUSY                       (2)
#define HALT_HALT_TX                             (1)
#define UARTCLK                                  (24000000)
#endif
