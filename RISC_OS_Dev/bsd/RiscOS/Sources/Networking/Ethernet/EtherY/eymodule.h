/*
 * Copyright (c) 2013, RISC OS Open Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of RISC OS Open Ltd nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
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
#ifndef EYMODULE_H
#define EYMODULE_H

/* Module constants */
#define ErrorBase_Castle10_100  0x81F700
#define ErrorBase_UnixRange     200 /* Errors below this are mapped to 0x20Enn */
#define ProdType_Castle10_100   0x0146
#define Manf_CastleTechnology   0x0055

/* Limits */
#define NIC_MAX_CONTROLLERS 5       /* Support up to this many boards */
#define NIC_MAX_INTERFACES  1       /* No virtual interfaces here */
#define NIC_IS_NIC_SLOT     8       /* Implicit, since no API to determine */

/* Network status information */
typedef struct
{
	struct nic          *ctrl;
	uint8_t              eui[ETHER_ADDR_LEN];
	Dib                  dib;
	filter_t            *filters;
	volatile uint32_t    tx_packets;
	volatile uint32_t    tx_bytes;
	volatile uint32_t    tx_errors;
	volatile uint32_t    rx_packets;
	volatile uint32_t    rx_bytes;
	volatile uint32_t    rx_errors;
	volatile uint32_t    rx_discards;
} ethery_if_t;

typedef struct nic
{
	uint32_t podule;
	uint32_t cmossize;
	uint32_t cmos;
	uint32_t flags;
#define NIC_FLAG_LINK100    1       /* Link100/Link10 */
#define NIC_FLAG_LINKFULL   2       /* Full/Half */
#define NIC_FLAG_LINKAUTO   4       /* Auto/else use LINK100 & LINKFULL bits */
#define NIC_FLAG_AD10_FULL  8       /* Advertise 10baseT full/half */
#define NIC_FLAG_AD10_HALF  16
#define NIC_FLAG_AD100_FULL 32      /* Advertise 100baseT full/half */
#define NIC_FLAG_AD100_HALF 64
#define NIC_FLAG_UNUSED     128
#define NIC_FLAG_DEFAULT    (NIC_FLAG_LINKAUTO | NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF | NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF)
	void                    *hwbase;
	void                    *rombase;
	volatile const uint32_t *irqstatus;
	volatile const uint32_t *irqrequest;
	volatile uint32_t       *irqmask;
	uint32_t                 irqbit;
	uint32_t                 irqdevice;

	volatile uint8_t        *private_irq;
#define NIC_PRIVATE_IRQ_MASK     1  /* It's b0 in the register in the CPLD */

	uint32_t  starttime;
	uint16_t  mtu;
	uint8_t   addresslevel;
	uint8_t   errorlevel;
	bool      running;
	uint8_t   faulty;
#define NIC_FAULT_NO_IOALLOC  1
#define NIC_FAULT_NO_EUI48    2
#define NIC_FAULT_NO_LANCHIP  4
#define NIC_FAULT_NO_RMA      8
#define NIC_FAULT_NO_VECTOR   16

	struct smc91cxx_softc controller;
	struct ifnet         *ifp;
	ethery_if_t           interface[NIC_MAX_INTERFACES];
} ethery_nic_t;

/* Message and error handling */
typedef enum
{
#define EIFBAD              0x80
#define EMMBAD              0x81
#define ENOMM               0x82
#define EPANICED            0x83
#define EBADCLI             0x84
#define EMLCFAIL            0x85
#define ETXBLOCKED          0x86
#define EFILTERGONE         0x87
#if ELAST >= ErrorBase_UnixRange
#error "Overlapping with Unix errors"
#endif
	ERR00_NO_PODULES = ErrorBase_UnixRange,
	ERR01_NO_SUPPORTED_ETHERY,
	ERR02_NO_EUI_SET,
	ERR03_SINGLE_INSTANCE,
	ERR04_FAIL_DETECT,
	ERR05_UNIT_IS_OFF
} ethery_err_t;

typedef enum
{
	MSG00_INFO_LENGTH = 0,
	MSG01_IF_DRIVER,
	MSG02_IF_UNIT,
	MSG03_IF_LOCATION,
	MSG04_IF_EUI,
	MSG05_IF_CONTROLLER,
	MSG06_IF_RUNTIME,
	MSG07_IF_ATTRIBUTE,
	MSG08_NETBSD,
	MSG09_TIME_FORMAT,
	MSG10_UP,
	MSG11_DOWN,
	MSG12_NIC,
	MSG13_PODULE,
	MSG14_AUTHOR,
	MSG15_AUTHOR,
	MSG16_PASSED,
	MSG17_FAILED,
	MSG18_INFO_STATS,
	MSG19_EMPTY, /* Intentionally so */
	MSG20_STAT_P_SENT,
	MSG21_STAT_P_RECEIVED,
	MSG22_STAT_B_SENT,
	MSG23_STAT_B_RECEIVED,
	MSG24_STAT_E_SENT,
	MSG25_STAT_E_RECEIVED,
	MSG26_STAT_UNDELIVERED,
	MSG27_FRAME_802_3,
	MSG28_FRAME_MONITOR,
	MSG29_FRAME_SINK,
	MSG30_FRAME_STANDARD,
	MSG31_FRAME_DESC,
	MSG32_SELFTEST,
	MSG33_IF_MEDIA,
	MSG34_BT_HALFDUP,
	MSG35_BT_FULLDUP,
	MSG36_UNPLUGGED,
	MSG37_UNITNO
} ethery_msg_t;

/* Debug support */
#ifdef DEBUG
#define DPRINTF(k)          printf k
#else
#define DPRINTF(k)          /* No debug */
#endif

/* Global stuff */
char *ethery_message_lookup(ethery_msg_t, const char *, const char *, const char *);
_kernel_oserror *ethery_error_lookup(ethery_err_t);
void ethery_review_levels(uint8_t);
extern void *ethery_messages(void); /* Generated by 'resgen' */
extern ethery_nic_t nic[NIC_MAX_CONTROLLERS];
extern ethery_if_t *nicunit[NIC_MAX_INTERFACES * NIC_MAX_CONTROLLERS];
extern uint8_t units;

#endif
