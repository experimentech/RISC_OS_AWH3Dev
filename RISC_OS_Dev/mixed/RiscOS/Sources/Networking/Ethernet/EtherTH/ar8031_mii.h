/*
 * Copyright (c) 2017, Colin Granville
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * The name Colin Granville may not be used to endorse or promote
 *       products derived from this software without specific prior written
 *       permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#ifndef AR8031_MII_H
#define AR8031_MII_H

#include "mii.h"

#define AR8031_MII_IDH  0x004D
#define AR8031_MII_IDL  0xD074

#define AR8035_MII_IDH  0x004D
#define AR8035_MII_IDL  0xD072

#define AR8031_MII_FCR  16      /* Function Control Register */
#define AR8031_MII_SSR  17      /* Specific Status Register */
                        #define AR8031_MII_SSR__SPEED                   (3 << 14)
                        #define AR8031_MII_SSR__SPEED_10                (0)
                        #define AR8031_MII_SSR__SPEED_100               (1 << 14)
                        #define AR8031_MII_SSR__SPEED_1000              (2 << 14)
                        #define AR8031_MII_SSR__DUPLEX                  (1 << 13)
                        #define AR8031_MII_SSR__DUPLEX_HALF             (0)
                        #define AR8031_MII_SSR__DUPLEX_FULL             (1 << 13)
                        #define AR8031_MII_SSR__PAGE_RECEIVED           (1 << 12)
                        #define AR8031_MII_SSR__SPD_DPLX_OK             (1 << 11)       /* speed and duplex resolved */
                        #define AR8031_MII_SSR__LINK                    (1 << 10)
                        #define AR8031_MII_SSR__LINK_DOWN               (0)
                        #define AR8031_MII_SSR__LINK_UP                 (1 << 10)
                        #define AR8031_MII_SSR__MDI_STS                 (1 << 6)
                        #define AR8031_MII_SSR__MDI_MDI                 (0)
                        #define AR8031_MII_SSR__MDI_MDIX                (1 << 6)
                        #define AR8031_MII_SSR__WIRE_DOWNGRD            (1 << 5)        /* wirespeed downgrade */
                        #define AR8031_MII_SSR__TX_PAUSE_EN             (1 << 3)
                        #define AR8031_MII_SSR__RX_PAUSE_EN             (1 << 2)
                        #define AR8031_MII_SSR__POLARITY                (1 << 1)
                        #define AR8031_MII_SSR__JABBER                  (1 << 0)

#define AR8031_MII_IER  18      /* Interrupt enable register */
                        #define AR8031_MII_IER__AUTO_NEG_ERR            (1 << 15)         /* Auto Megotiation Error */
                        #define AR8031_MII_IER__SPEED_CHANGED           (1 << 14)
                        #define AR8031_MII_IER__PAGE_RECEIVED           (1 << 12)
                        #define AR8031_MII_IER__LINK_FAIL               (1 << 11)
                        #define AR8031_MII_IER__LINK_SUCCESS            (1 << 10)
                        #define AR8031_MII_IER__FAST_LINK_DOWN_1        (1 << 9)
                        #define AR8031_MII_IER__LINK_FAIL_BX            (1 << 8)
                        #define AR8031_MII_IER__LINK_SUCCESS_BX         (1 << 7)
                        #define AR8031_MII_IER__FAST_LINK_DOWN_0        (1 << 6)
                        #define AR8031_MII_IER__WIRESPEED_DGRD          (1 << 5)
                        #define AR8031_MII_IER__INT_10MS_PTP            (1 << 4)
                        #define AR8031_MII_IER__INT_10RX_PTP            (1 << 3)
                        #define AR8031_MII_IER__INT_TX_PTP              (1 << 2)
                        #define AR8031_MII_IER__POLARITY_CHANGED        (1 << 1)
                        #define AR8031_MII_IER__INT_WOL_PTP             (1 << 0)        /* Wake on LAN */


#define AR8031_MII_ISR  19       /* Interrupt status register */
                        #define AR8031_MII_ISR__AUTO_NEG_ERR            (1 << 15)         /* Auto Megotiation Error */
                        #define AR8031_MII_ISR__SPEED_CHANGED           (1 << 14)
                        #define AR8031_MII_ISR__PAGE_RECEIVED           (1 << 12)
                        #define AR8031_MII_ISR__LINK_FAIL               (1 << 11)
                        #define AR8031_MII_ISR__LINK_SUCCESS            (1 << 10)
                        #define AR8031_MII_ISR__FAST_LINK_DOWN_1        (1 << 9)
                        #define AR8031_MII_ISR__LINK_FAIL_BX            (1 << 8)
                        #define AR8031_MII_ISR__LINK_SUCCESS_B          (1 << 7)
                        #define AR8031_MII_ISR__FAST_LINK_DOWN_0        (1 << 6)
                        #define AR8031_MII_ISR__WIRESPEED_DGRD          (1 << 5)
                        #define AR8031_MII_ISR__INT_10MS_PTP            (1 << 4)
                        #define AR8031_MII_ISR__INT_10RX_PTP            (1 << 3)
                        #define AR8031_MII_ISR__INT_TX_PTP              (1 << 2)
                        #define AR8031_MII_ISR__POLARITY_CHANG          (1 << 1)
                        #define AR8031_MII_ISR__INT_WOL_PTP             (1 << 0)          /* Wake on LAN */

#define AR8031_MII_DPAR 29      /* Debug Port Address Register */
#define AR8031_MII_DPDR 30      /* Debug Port Data Register */

#define AR8031_MII_CCR  31      /* Chip Configure Register */
                        #define AR8031_MII_CCR__SEL_COPPER_PAGE         (1 << 15)
                        #define AR8031_MII_CCR__PREFER_COPPER           (1 << 10)

#define AR8031_MII_DBG_SARDES_REG               5

void     ar8031_mii_dbg_set(device_t* device, int reg, uint32_t value);
uint32_t ar8031_mii_dbg_get(device_t* device, int reg);
void     ar8031_mii_dbg_modify(device_t* device, int reg, uint32_t bic, uint32_t eor);

#endif
