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
/*
 * Copyright (c) 2008-2012, Freescale Semiconductor, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * o Redistributions of source code must retain the above copyright notice, this list
 *   of conditions and the following disclaimer.
 *
 * o Redistributions in binary form must reproduce the above copyright notice, this
 *   list of conditions and the following disclaimer in the documentation and/or
 *   other materials provided with the distribution.
 *
 * o Neither the name of Freescale Semiconductor, Inc. nor the names of its
 *   contributors may be used to endorse or promote products derived from this
 *   software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*!
 * @file sdk.h
 * @brief       Basic defines
 *
 * @ingroup diag_init
 */
#ifndef __SDK_H__
#define __SDK_H__

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdint.h>

#include "sdk_types.h"
//#include "sdk_version.h"
#include "io.h"

#include "soc_memory_map.h"
#include "ws.h"

#include "registers.h"
#include "regs.h"
//#include "iomux_config.h"
#include "iomux_define.h"
#include "iomux_register.h"
//#include "utility/system_util.h"
#include "gpio.h"
#include "interrupt.h"
#include "gic.h"
#include "ccm_pll.h"
#include "max7310.h"
#include "imx_i2c.h"
#include "imx_uart.h"
#include "timer.h"
// #include "usb/usb.h"
//#include "keypad/keypad_port.h"
#include "ecspi_ifc.h"
//#if !defined(CHIP_MX6SL)
#include "enet.h"
//#else
//#include "fec/fec.h"
//#endif
//#include "board_id/board_id.h"

#include "buffers.h"
#include "ldb_def.h"

#include "ipu_common.h"
#include "ips_display.h"


//#include "board_io_expanders.h"
//#include "board_i2c.h"
//
//#if defined(CHIP_MX6DQ)
//#include "imx_sata.h"
//#endif



// Bit write macro to access SDK defined registers
#define BITWRITE(where,field,what) ((HW_##where.U)= ((HW_##where.U) &~(BM_##where##_##field)) | (what << (BP_##where##_##field)))
//#define BITWRITE(where,field,what) do{printf("BW:%x, %x\n",HW_##where##_ADDR,(what << (BP_##where##_##field)));((HW_##where.U)= ((HW_##where.U) &~(BM_##where##_##field)) | (what << (BP_##where##_##field)));}while(0)

// Bit read macro to access SDK defined registers
#define BITREAD(where,field) ( ((HW_##where.U) &~(BM_##where##_##field)) >> (BP_##where##_##field))
//#define BITREAD(where,field) (do{printf("BR:%x\n",HW_##where##_ADDR);(uint32_t x;x= ((HW_##where.U) &~(BM_##where##_##field)) >> (BP_##where##_##field));x;}while(0))



// setup and define type for all register sets in use, assuming mem mapping on
#define REGS_HDMI_BASE ((uint8_t*)(sb->HDMI_Log))
#ifdef SRC_BASE_ADDR
#undef SRC_BASE_ADDR
#define SRC_BASE_ADDR                   (sb->SRC_Log)
#endif
#define REGS_IPU1_BASE ((uint32_t *)(sb->IPU1_Log)) //!< Base address for IPU instance number 1.
#define REGS_IPU2_BASE ((uint32_t *)(sb->IPU2_Log)) //!< Base address for IPU instance number 2.
#define REGS_CCM_ANALOG_BASE (sb->CCMAn_Log) //!< Base address for CCM_ANALOG.
#define REGS_CCM_BASE ((uint32_t)(sb->CCM_Base)) //!< Base address for CCM.
#define REGS_GPC_BASE (sb->GPC_Log) //!< Base address for GPC.
#define REGS_IOMUXC_BASE (sb->IOMUXC_Base) //!< Base address for IOMUXC.



#define REGS_ESAI_BASE (xx0x02024000) //!< Base address for ESAI.
#define REGS_ECSPI1_BASE (xx0x02008000) //!< Base address for ECSPI instance number 1.
#define REGS_ECSPI2_BASE (xx0x0200c000) //!< Base address for ECSPI instance number 2.
#define REGS_ECSPI3_BASE (xx0x02010000) //!< Base address for ECSPI instance number 3.
#define REGS_ECSPI4_BASE (xx0x02014000) //!< Base address for ECSPI instance number 4.
#define REGS_ECSPI5_BASE (xx0x02018000) //!< Base address for ECSPI instance number 5.
#define REGS_SDMAARM_BASE (xx0x020ec000) //!< Base address for SDMAARM.
#define REGS_SPBA_BASE (xx0x0203c000) //!< Base address for SPBA.
#define REGS_SPDIF_BASE (xx0x02004000) //!< Base address for SPDIF.
#define REGS_I2C1_BASE (xx0x021a0000) //!< Base address for I2C instance number 1.
#define REGS_I2C2_BASE (xx0x021a4000) //!< Base address for I2C instance number 2.
#define REGS_I2C3_BASE (xx0x021a8000) //!< Base address for I2C instance number 3.
#define REGS_GPT_BASE (xx0x02098000) //!< Base address for GPT.
#define REGS_EPIT1_BASE (xx0x020d0000) //!< Base address for EPIT instance number 1.
#define REGS_EPIT2_BASE (xx0x020d4000) //!< Base address for EPIT instance number 2.
#define REGS_SSI1_BASE (xx0x02028000) //!< Base address for SSI instance number 1.
#define REGS_SSI2_BASE (xx0x0202c000) //!< Base address for SSI instance number 2.
#define REGS_SSI3_BASE (xx0x02030000) //!< Base address for SSI instance number 3.
#define REGS_UART1_BASE (xx0x02020000) //!< Base address for UART instance number 1.
#define REGS_UART2_BASE (xx0x021e8000) //!< Base address for UART instance number 2.
#define REGS_UART3_BASE (xx0x021ec000) //!< Base address for UART instance number 3.
#define REGS_UART4_BASE (xx0x021f0000) //!< Base address for UART instance number 4.
#define REGS_UART5_BASE (xx0x021f4000) //!< Base address for UART instance number 5.
#define REGS_ENET_BASE (xx0x02188000) //!< Base address for ENET.
#define REGS_SATA_BASE (xx0x02200000) //!< Base address for SATA.
#define REGS_LDB_BASE (xx0x020e0008) //!< Base address for LDB.

// address offsets used in  clock_gating_config((
#define REGS_ESAI_BaseOffset    (0x024000) //!< Base address for ESAI.
#define REGS_ECSPI1_BaseOffset  (0x008000) //!< Base address for ECSPI instance number 1.
#define REGS_ECSPI2_BaseOffset  (0x00c000) //!< Base address for ECSPI instance number 2.
#define REGS_ECSPI3_BaseOffset  (0x010000) //!< Base address for ECSPI instance number 3.
#define REGS_ECSPI4_BaseOffset  (0x014000) //!< Base address for ECSPI instance number 4.
#define REGS_ECSPI5_BaseOffset  (0x018000) //!< Base address for ECSPI instance number 5.
#define REGS_SDMAARM_BaseOffset (0x0ec000) //!< Base address for SDMAARM.
#define REGS_SPBA_BaseOffset    (0x03c000) //!< Base address for SPBA.
#define REGS_SPDIF_BaseOffset   (0x004000) //!< Base address for SPDIF.
#define REGS_I2C1_BaseOffset    (0x1a0000) //!< Base address for I2C instance number 1.
#define REGS_I2C2_BaseOffset    (0x1a4000) //!< Base address for I2C instance number 2.
#define REGS_I2C3_BaseOffset    (0x1a8000) //!< Base address for I2C instance number 3.
#define REGS_GPT_BaseOffset     (0x098000) //!< Base address for GPT.
#define REGS_EPIT1_BaseOffset   (0x0d0000) //!< Base address for EPIT instance number 1.
#define REGS_EPIT2_BaseOffset   (0x0d4000) //!< Base address for EPIT instance number 2.
#define REGS_SSI1_BaseOffset    (0x028000) //!< Base address for SSI instance number 1.
#define REGS_SSI2_BaseOffset    (0x02c000) //!< Base address for SSI instance number 2.
#define REGS_SSI3_BaseOffset    (0x030000) //!< Base address for SSI instance number 3.
#define REGS_UART1_BaseOffset   (0x020000) //!< Base address for UART instance number 1.
#define REGS_UART2_BaseOffset   (0x1e8000) //!< Base address for UART instance number 2.
#define REGS_UART3_BaseOffset   (0x1ec000) //!< Base address for UART instance number 3.
#define REGS_UART4_BaseOffset   (0x1f0000) //!< Base address for UART instance number 4.
#define REGS_UART5_BaseOffset   (0x1f4000) //!< Base address for UART instance number 5.
#define REGS_ENET_BaseOffset    (0x188000) //!< Base address for ENET.
#define REGS_SATA_BaseOffset    (0x200000) //!< Base address for SATA.
#define REGS_LDB_BaseOffset     (0x0e0008) //!< Base address for LDB.
#define CAAM_BaseOffset         (0x100000)

#define REGS_GPMI_ BaseOffset    (0x112000) // this relates to CPUIOBase, not MainIOBase


#define REGS_BaseOffset 0x00000000






#define hal_delay_us HAL_CounterDelay
extern int HAL_CounterDelay(int);



#endif // __SDK_H__
////////////////////////////////////////////////////////////////////////////////
// EOF
////////////////////////////////////////////////////////////////////////////////
