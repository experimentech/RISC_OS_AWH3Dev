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


#ifndef MII_H
#define MII_H

#include "device.h"

/* See IEEE 802.3 for registers 0-15. Other registers are vendor specific*/

/* MII class 22 registers */
#define MII_BCR         0                                               /* Basic Control Register */
                        #define MII_BCR__RESET                  (1 << 15)       /* PHY soft reset */
                        #define MII_BCR__LOOPBACK               (1 << 14)
                        #define MII_BCR__SPEED                  ((1 << 13) | (1 << 6)) /* Connection speed */
                        #define MII_BCR__SPEED_10               (0)
                        #define MII_BCR__SPEED_100              (1 << 13)
                        #define MII_BCR__SPEED_1000             (1 << 6)
                        #define MII_BCR__AUTONEGEN              (1 << 12)       /* Auto Negotiate Enable*/
                        #define MII_BCR__PWRDOWN                (1 << 11)
                        #define MII_BCR__REAUTONEG              (1 << 9)        /* Restart Auto Negotiate */
                        #define MII_BCR__DUPLEX                 (1 << 8)        /* Duplex Mode */
                        #define MII_BCR__DUPLEX_HALF            (0)
                        #define MII_BCR__DUPLEX_FULL            (1 << 8)

#define MII_BSR         1                                               /* Basic Status Register */
                        #define MII_BSR__100BASET4_ABLE          (1 << 15)
                        #define MII_BSR__100BASETX_FD_ABLE       (1 << 14)
                        #define MII_BSR__100BASETX_HD_ABLE       (1 << 13)
                        #define MII_BSR__10BASET_FD_ABLE         (1 << 12)
                        #define MII_BSR__10BASET_HD_ABLE         (1 << 11)
                        #define MII_BSR__100BASET2_FD_ABLE       (1 << 10)
                        #define MII_BSR__100BASET2_HD_ABLE       (1 << 9)
                        #define MII_BSR__EXTENDED_STATUS         (1 << 8)
                        #define MII_BSR__AUTO_NEG_COMPLETE       (1 << 5)
                        #define MII_BSR__REMOTE_FAULT            (1 << 4)
                        #define MII_BSR__AUTO_NEG_ABILITY        (1 << 3)
                        #define MII_BSR__LINK_STATUS             (1 << 2)
                        #define MII_BSR__JABBER                  (1 << 1)
                        #define MII_BSR__EXTENDED_CAPABILITIES   (1 << 0)

#define MII_IDH         2                                               /* Identifier high word Register */
#define MII_IDL         3                                               /* Identifier low word Register */
#define MII_ANAR        4                                               /* Auto Negotiation Advert */
                        #define MII_ANAR__NEXT_PAGE             (1 << 15)
                        #define MII_ANAR__ACK                   (1 << 14)
                        #define MII_ANAR__REMOTE_FAULT          (1 << 13)
                        #define MII_ANAR__XNP_ABLE              (1 << 12)
                        #define MII_ANAR__ASYM_PAUSE            (1 << 11)
                        #define MII_ANAR__PAUSE                 (1 << 10)
                        #define MII_ANAR__100BASET4             (1 << 9)
                        #define MII_ANAR__100BASETX_FULL        (1 << 8)
                        #define MII_ANAR__100BASETX_HALF        (1 << 7)
                        #define MII_ANAR__10BASETX_FULL         (1 << 6)
                        #define MII_ANAR__10BASETX_HALF         (1 << 5)
                        #define MII_ANAR__SELECTOR_FIELD(n)     ((n) & 1f)

#define MII_ANLPBAPR    5                                              /* Auto Netgotiation Link Partner Base Page Ability */
#define MII_ANNP        7
#define MII_MSCR        9                                               /* Master/Slave Control Register */
                        #define MII_MSCR__TEST_MODE             (7 << 13)
                        #define MII_MSCR__NORMAL_MODE           (0)
                        #define MII_MSCR__TEST_MODE_1           (1 << 13)
                        #define MII_MSCR__TEST_MODE_2           (2 << 13)
                        #define MII_MSCR__TEST_MODE_3           (3 << 13)
                        #define MII_MSCR__TEST_MODE_4           (4 << 13)
                        #define MII_MSCR__CONFIG_EN             (1 << 12)
                        #define MII_MSCR__CONFIG_MPORT          (1 << 11)
                        #define MII_MSCR__PORT_MPORT            (1 << 10)
                        #define MII_MSCR__ADV1000TFD            (1 << 9)
                        #define MII_MSCR__ADV1000THD            (1 << 8)

#define MII_MMD_ACR     13                                              /* MMD Access Control REgister */
                        #define MII_MMS_ACR__ADDR               (0 << 14)
                        #define MII_MMS_ACR__DATA               (1 << 14)
                        #define MII_MMS_ACR__DATA_WR_INC        (2 << 14)
                        #define MII_MMS_ACR__DATA_W_INC         (3 << 14)
                        #define MII_MMS_ACR__DEVAD(n)           ((n) & 0x1f)

#define MII_MMD_AADR    14                                              /* MMD Access Address Data Register */
/* MII class 22 functions */
void                    mii_hardresetPhy(device_t*);
void                    mii_resetPhy(device_t*);
void                    mii_reAutoNegotiate(device_t* device);
uint32_t                mii_getReg(device_t*, int reg);
void                    mii_setReg(device_t*, int reg, uint32_t value);
void                    mii_modifyReg(device_t*, int reg, uint32_t bic, uint32_t eor);
uint32_t                mii_mmd_get(device_t* device, int reg, int address);
void                    mii_mmd_set(device_t* device, int reg, int address, uint32_t val);
void                    mii_mmd_modify(device_t* device, int reg, int address, uint32_t bic, uint32_t eor);


#endif
