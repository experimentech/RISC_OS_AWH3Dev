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


#ifndef DEVICE_H
#define DEVICE_H

#include "dci.h"
#include "dcifilter.h"

#include "swis.h"
#include "sys/queue.h"
#include "Global/HALDevice.h"
#include "Global/HALEntries.h"
#include "HalEtherDevice.h"


/****************************************************
                 Register offsets

               (all 4 bytes apart)
*****************************************************/
/* no 0 */
#define ENET_EIR                        0x4
                                        #define ENET_EIR__BABR          (1 << 30)
                                        #define ENET_EIR__BABT          (1 << 29)
                                        #define ENET_EIR__GRA           (1 << 28)
                                        #define ENET_EIR__TXF           (1 << 27)
                                        #define ENET_EIR__TXB           (1 << 26)
                                        #define ENET_EIR__RXF           (1 << 25)
                                        #define ENET_EIR__RXB           (1 << 24)
                                        #define ENET_EIR__MII           (1 << 23)
                                        #define ENET_EIR__EBERR         (1 << 22)
                                        #define ENET_EIR__LC            (1 << 21)
                                        #define ENET_EIR__RL            (1 << 20)
                                        #define ENET_EIR__UN            (1 << 19)
                                        #define ENET_EIR__PLR           (1 << 18)
                                        #define ENET_EIR__WAKEUP        (1 << 17)
                                        #define ENET_EIR__TS_AVAIL      (1 << 16)
                                        #define ENET_EIR__TS_TIMER      (1 << 15)

#define ENET_EIMR                       0x8
                                        #define ENET_EIMR__BABR         (1 << 30)
                                        #define ENET_EIMR__BABT         (1 << 29)
                                        #define ENET_EIMR__GRA          (1 << 28)
                                        #define ENET_EIMR__TXF          (1 << 27)
                                        #define ENET_EIMR__TXB          (1 << 26)
                                        #define ENET_EIMR__RXF          (1 << 25)
                                        #define ENET_EIMR__RXB          (1 << 24)
                                        #define ENET_EIMR__MII          (1 << 23)
                                        #define ENET_EIMR__EBERR        (1 << 22)
                                        #define ENET_EIMR__LC           (1 << 21)
                                        #define ENET_EIMR__RL           (1 << 20)
                                        #define ENET_EIMR__UN           (1 << 19)
                                        #define ENET_EIMR__PLR          (1 << 18)
                                        #define ENET_EIMR__WAKEUP       (1 << 17)
                                        #define ENET_EIMR__TS_AVAIL     (1 << 16)
                                        #define ENET_EIMR__TS_TIMER     (1 << 15)
/* no 0xc */
#define ENET_RDAR                       0x10
                                        #define ENET_RDAR__RDAR         (1 << 24)

#define ENET_TDAR                       0x14
                                        #define ENET_TDAR__TDAR         (1 << 24)
/* no 0x18 - 0x20 */
#define ENET_ECR                        0x24
                                        #define ENET_ECR__REQUIRED      0xf0000000u     /* must be set when writing */
                                        #define ENET_ECR__DBSWP         ((1 << 8) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__STOPEN        ((1 << 7) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__DBGEN         ((1 << 6) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__SPEED         ((1 << 5) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__SPEED_1000    ((1 << 5) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__SPEED_10_100  ((0) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__EN1588        ((1 << 4) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__SLEEP         ((1 << 3) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__MAGICEN       ((1 << 2) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__ETHEREN       ((1 << 1) | ENET_ECR__REQUIRED)
                                        #define ENET_ECR__RESET         ((1 << 0) | ENET_ECR__REQUIRED)
/* no 0x28 - 0x3c */
#define ENET_MMFR                       0x40
                                        #define ENET_MMFR__ST(n)        (((n) & 3) << 30)
                                        #define ENET_MMFR__OP(n)        (((n) & 3) << 28)
                                        #define ENET_MMFR__PHYADR(n)    (((n) & 31) << 23)
                                        #define ENET_MMFR__REGADR(n)    (((n) & 31) << 18)
                                        #define ENET_MMFR__TA(n)        (((n) & 3) << 16)
                                        #define ENET_MMFR__DATA(n)      ((n) & 0xffff)
#define ENET_MSCR                       0x44
                                        #define ENET_MSCR__MII_SPEED(n) (((n) & 0x3f) << 1)
                                        #define ENET_MSCR__DIS_PRE      (1 << 7)
                                        #define ENET_MSCR__HOLDTIME(n)  (((n) & 7) << 8)
/* no 0x48 - 0x60 */
#define ENET_MIBC                       0x64
                                        #define ENET_MIBC__MIB_DIS      (1 << 31)
                                        #define ENET_MIBC__MIB_IDLE     (1 << 30)
                                        #define ENET_MIBC__MIB_CLEAR    (1 << 29)
/* no 0x68 - 0x80 */
#define ENET_RCR                        0x84
                                        #define ENET_RCR__GRS           (1 << 31)
                                        #define ENET_RCR__NLC           (1 << 30)
                                        #define ENET_RCR__MAX_FL(n)     (((n) & 0x3fff) << 16)
                                        #define ENET_RCR__CFEN          (1 << 15)
                                        #define ENET_RCR__CRCFWD        (1 << 14)
                                        #define ENET_RCR__PAUFWD        (1 << 13)
                                        #define ENET_RCR__PADEN         (1 << 12)
                                        #define ENET_RCR__RMII_10T      (1 << 9)
                                        #define ENET_RCR__RMII_MODE     (1 << 8)
                                        #define ENET_RCR__RGMII_EN      (1 << 6)
                                        #define ENET_RCR__FCE           (1 << 5)
                                        #define ENET_RCR__BC_REG        (1 << 4)
                                        #define ENET_RCR__PROM          (1 << 3)
                                        #define ENET_RCR__MII_MODE      (1 << 2)
                                        #define ENET_RCR__DRT           (1 << 1)
                                        #define ENET_RCR__LOOP          (1 << 0)
/* no 0x88 - 0xc0 */
#define ENET_TCR                        0xc4
                                        #define ENET_TCR__CRCFWD        (1 << 9)
                                        #define ENET_TCR__ADDINS        (1 << 8)
                                        #define ENET_TCR__ADDSEL        (7 << 5)
                                        #define ENET_TCR__ADDSEL_000    (0)
                                        #define ENET_TCR__RFC_PAUSE     (1 << 4)
                                        #define ENET_TCR__TFC_PAUSE     (1 << 3)
                                        #define ENET_TCR__FDEN          (1 << 2)
                                        #define ENET_TCR__GTS           (1 << 0)

/* no 0xc8 - 0xe0 */
#define ENET_PALR                       0xe4
#define ENET_PAUR                       0xe8
                                        #define ENET_PAUR__8808                  (0x8808)
#define ENET_OPD                        0xec
                                        #define ENET_OPD__PAUSE_DURATION(n)      ((n) & 0xffff)
                                        #define ENET_OPD__OP_CODE                (1 << 16)
/* no 0xd0 - 0x114 */
#define ENET_IAUR                       0x118
#define ENET_IALR                       0x11c
#define ENET_GAUR                       0x120
#define ENET_GALR                       0x124
/* no 0x128 - 0x140 */
#define ENET_TFWR                       0x144
                                        #define ENET_TFWR__STRFWD       (1 << 8)
                                        #define ENET_TFWR__TWFR(n)      ((n) & 0x3f)
/* no 0x148 - 0x17c */
#define ENET_RDSR                       0x180
#define ENET_TDSR                       0x184
#define ENET_MRBR                       0x188
#define ENET_RSFL                       0x190
                                        #define ENET_RSFL__STRFWD       0
#define ENET_RSEM                       0x194
                                        #define ENET_RSEM__NO_XON_XOFF  0
#define ENET_RAEM                       0x198
#define ENET_RAFL                       0x19c
#define ENET_TSEM                       0x1a0
                                        #define ENET_TSEM__NO_EMPYING_SIGNAL;
#define ENET_TAEM                       0x1a4
#define ENET_TAFL                       0x1a8
#define ENET_TIPG                       0x1ac
#define ENET_FTRL                       0x1b0
/* no 0x1b4 - 0x1bc */
#define ENET_TACC                       0x1c0
                                        #define ENET_TACC__PROCHK       (1 << 4)
                                        #define ENET_TACC__IPCHK        (1 << 3)
                                        #define ENET_TACC__SHIFT16      (1 << 0)
#define ENET_RACC                       0x1c4
                                        #define ENET_RACC__SHIFT16      (1 << 7)
                                        #define ENET_RACC__LINEDIS      (1 << 6)
                                        #define ENET_RACC__PRODIS       (1 << 2)
                                        #define ENET_RACC__IPDIS        (1 << 1)
                                        #define ENET_RACC__PADREM       (1 << 0)
/* no 0x1c8 - 0x1fc */
#define ENET_RMON_T_DROP                0x200
#define ENET_RMON_T_PACKETS             0x204
#define ENET_RMON_T_BC_PKT              0x208
#define ENET_RMON_T_MC_PKT              0x20c
#define ENET_RMON_T_CRC_ALIGN           0x210
#define ENET_RMON_T_UNDERSIZE           0x214
#define ENET_RMON_T_OVERSIZE            0x218
#define ENET_RMON_T_FRAG                0x21c
#define ENET_RMON_T_JAB                 0x220
#define ENET_RMON_T_COL                 0x224
#define ENET_RMON_T_P64                 0x228
#define ENET_RMON_T_P65TO127            0x22c
#define ENET_RMON_T_P128TO255           0x230
#define ENET_RMON_T_P256TO511           0x234
#define ENET_RMON_T_P512TO1023          0x238
#define ENET_RMON_T_P1024TO2047         0x23c
#define ENET_RMON_T_P_GTE2048           0x240
#define ENET_RMON_T_OCTETS              0x244

#define ENET_IEEE_T_DROP                0x248
#define ENET_IEEE_T_FRAME_OK            0x24c
#define ENET_IEEE_T_1COL                0x250
#define ENET_IEEE_T_MCOL                0x254
#define ENET_IEEE_T_DEF                 0x258
#define ENET_IEEE_T_LCOL                0x25c
#define ENET_IEEE_T_EXCOL               0x260
#define ENET_IEEE_T_MACERR              0x264
#define ENET_IEEE_T_CSERR               0x268
#define ENET_IEEE_T_SQE                 0x26c
#define ENET_IEEE_T_FDXFC               0x270
#define ENET_IEEE_T_OCTETS_OK           0x274
/* no 0x278 to 0x280 */
#define ENET_RMON_R_PACKETS             0x284
#define ENET_RMON_R_BC_PKT              0x288
#define ENET_RMON_R_MC_PKT              0x28c
#define ENET_RMON_R_CRC_ALIGN           0x290
#define ENET_RMON_R_UNDERSIZE           0x294
#define ENET_RMON_R_OVERSIZE            0x298
#define ENET_RMON_R_FRAG                0x29c
#define ENET_RMON_R_JAB                 0x2a0
#define ENET_RMON_R_RESVD_0             0x2a4
#define ENET_RMON_R_P64                 0x2a8
#define ENET_RMON_R_P65TO127            0x2ac
#define ENET_RMON_R_P128TO255           0x2b0
#define ENET_RMON_R_P256TO511           0x2b4
#define ENET_RMON_R_P512TO1023          0x2b8
#define ENET_RMON_R_P1024TO2047         0x2bc
#define ENET_RMON_R_P_GTE2048           0x2c0
#define ENET_RMON_R_OCTETS              0x2c4

#define ENET_IEEE_R_DROP                0x2c8
#define ENET_IEEE_R_FRAME_OK            0x2cc
#define ENET_IEEE_R_CRC                 0x2d0
#define ENET_IEEE_R_ALIGN               0x2d4
#define ENET_IEEE_R_MACERR              0x2d8
#define ENET_IEEE_R_FDXFC               0x2dc
#define ENET_IEEE_R_OCTETS_OK           0x2e0
/* no 0x2e4 to 0x3fc */
/* timer */
#define ENET_ATCR                       0x400
                                        #define ENET_ATCR__SLAVE        (1 << 13)
                                        #define ENET_ATCR__CAPTURE      (1 << 11)
                                        #define ENET_ATCR__RESTART      (1 << 9)
                                        #define ENET_ATCR__PINPER       (1 << 7)
                                        #define ENET_ATCR__PEREN        (1 << 4)
                                        #define ENET_ATCR__OFFRST       (1 << 3)
                                        #define ENET_ATCR__OFFEN        (1 << 2)
                                        #define ENET_ATCR__EN           (1 << 0)

#define ENET_ATVR                       0x404
#define ENET_ATOFF                      0x408
#define ENET_ATPER                      0x40c
#define ENET_ATCOR                      0x410
                                        #define ENET_ATCOR__RESET       (1u << 31)
#define ENET_ATINC                      0x414
                                        #define ENET_ATINC__INC_CORR(n) ((n) << 8)
                                        #define ENET_ATINC__INC(n)      ((n) << 0)
#define ENET_ATSTMP                     0x418
/* no 0x41c to 0x600 */
#define ENET_TGSR                       0x604
#define ENET_TCSR                       0x608
#define ENET_TCCR                       0x60c

/****************************************************
          Data buffer for Buffer Descriptors
*****************************************************/

typedef struct
{
        uint8_t data[(ETHER_MAX_LEN + 2 + 15) & ~15]; /* Add 2 for device's word alignment and round up.
                                                      Size must be 16 byte aligned. */
}BD_Data_t;


/****************************************************
               RX Buffer Descriptor
*****************************************************/

#define RXBD_RING_BUFFER_SIZE   16 //128 /* 16 */

typedef struct
{
        volatile uint32_t       status;
                                #define RXBD_STATUS__E                  (1u << 31)
                                #define RXBD_STATUS__RO1                (1u << 30)
                                #define RXBD_STATUS__W                  (1u << 29)
                                #define RXBD_STATUS__RO2                (1u << 28)
                                #define RXBD_STATUS__L                  (1u << 27)
                                #define RXBD_STATUS__M                  (1u << 24)
                                #define RXBD_STATUS__BC                 (1u << 23)
                                #define RXBD_STATUS__MC                 (1u << 22)
                                #define RXBD_STATUS__LG                 (1u << 21)
                                #define RXBD_STATUS__NO                 (1u << 20)
                                #define RXBD_STATUS__CR                 (1u << 18)
                                #define RXBD_STATUS__OV                 (1u << 17)
                                #define RXBD_STATUS__TR                 (1u << 16)
                                #define RXBD_STATUS__LEN(n)             ((n) & 0xffff)
        BD_Data_t*              data;           /* physical address of contiguous PCI ram for packet*/
} RxBD_t;


/****************************************************
               TX Buffer Descriptor
*****************************************************/
#define TXBD_RING_BUFFER_SIZE   16

typedef struct
{
        volatile uint32_t       status;
                                #define TXBD_STATUS__R                  (1u << 31)
                                #define TXBD_STATUS__TO1                (1u << 30)
                                #define TXBD_STATUS__W                  (1u << 29)
                                #define TXBD_STATUS__TO2                (1u << 28)
                                #define TXBD_STATUS__L                  (1u << 27)
                                #define TXBD_STATUS__TC                 (1u << 26)
                                #define TXBD_STATUS__ABC                (1u << 25)
                                #define TXBD_STATUS__LEN(n)             ((n) & 0xffff)
        BD_Data_t*              data;          /* physical address of contiguous PCI ram for packet*/
} TxBD_t;

/****************************************************
               Device Structure
*****************************************************/

#define PAUSE_THRESHOLD         2400
#define PAUSE_DURATION          60

typedef struct
{
        BD_Data_t       rx_packets[RXBD_RING_BUFFER_SIZE];
        BD_Data_t       tx_packets[TXBD_RING_BUFFER_SIZE];
        RxBD_t          rx_ring_buf[RXBD_RING_BUFFER_SIZE];
        TxBD_t          tx_ring_buf[TXBD_RING_BUFFER_SIZE];
}device_mem_t;

typedef struct device_t
{
        SLIST_ENTRY(device_t)   next;
        uint32_t                flags;
        HalEtherDevice_t*       hal_device;
        void*                   hal_pw;
        void*                   pw;
        volatile uint32_t*      register_base;
        device_mem_t*           mem;
        TxBD_t*                 tx_ring_ptr;
        BD_Data_t*              tx_packet_ptr;
        RxBD_t*                 rx_ring_ptr;
        BD_Data_t*              rx_packet_ptr;
        int32_t                 mem_physical_offset;
        dcifilter_t*            dcifilter;
        Dib                     dib;                    /* Driver Information Block */
        uint8_t                 net_address[ETHER_ADDR_LEN];
} device_t;


SLIST_HEAD(device_list_t, device_t);

extern struct device_list_t device_list;

#define device_getReg(device_ptr, reg_byte_offset) ((device_ptr)->register_base[(reg_byte_offset) >> 2])
#define device_setReg(device_ptr, reg_byte_offset, value) ((device_ptr)->register_base[(reg_byte_offset) >> 2] = value)
#define device_modifyReg(device_ptr, reg_byte_offset, bic, eor) \
        do { \
                uint32_t val = device_getReg((device_ptr), (reg_byte_offset)); \
                val &= ~(bic); \
                val ^= (eor); \
                device_setReg((device_ptr), (reg_byte_offset), (val)); \
        } while (0)


/* create a new device and put it on device list */
_kernel_oserror*        device_new(int unit, HalEtherDevice_t* hal_device, void* pw);

void                    device_delete(device_t*);
device_t*               device_getFromUnit(int unit);

_kernel_oserror*        device_inquire(device_t*, dci_InquireArgs_t*);
_kernel_oserror*        device_getNetworkMTU(device_t*, dci_GetNetworkMTUArgs_t*);
_kernel_oserror*        device_setNetworkMTU(device_t*, dci_SetNetworkMTUArgs_t*);
_kernel_oserror*        device_transmit(device_t*, dci_TransmitArgs_t*);
_kernel_oserror*        device_stats(device_t*, dci_StatsArgs_t*);
_kernel_oserror*        device_multicastRequest(device_t*, dci_MulticastRequestArgs_t*);
/*
 * Flags indicating which resources have been allocated
 * so that device destroy can be called from anywhere from
 * within device new and free resources allocated so far.
 */
#define DF_I_MEMORY             (1 << 0)
#define DF_I_PCI_MEMORY         (1 << 1)
#define DF_I_VECTORCLAIMED      (1 << 2)
#define DF_I_PHYVECTORCLAIMED   (1 << 3)
#define DF_I_IRQENABLED         (1 << 4)
#define DF_I_PHYIRQENABLED      (1 << 5)
#define DF_I_DCIFILTER          (1 << 6)
#define DF_I_DRIVER_STARTING    (1 << 7)
#define DF_I_HAL_HAS_PHY_PWRRST (1 << 8)
#define DF_I_PHY_AR8035         (1 << 9)


#endif
