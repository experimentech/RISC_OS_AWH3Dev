/*
 * Copyright (c) 2014, Elesar Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of Elesar Ltd nor the names of its contributors
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
#ifndef ECPMODULE_H
#define ECPMODULE_H

/* Module constants */
#define ErrorBase_EtherCPSW     0x820100
#define ErrorBase_UnixRange     200 /* Errors below this are mapped to 0x20Enn */

/* Limits */
#define NIC_MAX_CONTROLLERS 2       /* Limited by 2 bit field in ALE filter */
#define NIC_MAX_INTERFACES  2       /* One real plus one virtual interface per controller */

/* Network status information */
typedef struct
{
	struct nic          *ctrl;
	size_t               ctrlnum;
	size_t               unitnum;
#define EUI_ALT_BIT          128    /* OR'd to get the 2nd virtual interface */
#define EUI_ALT_BYTE         3
#define EUI_IF_BYTE          5
	uint8_t              eui[ETHER_ADDR_LEN];
	bool                 virtual;
	Dib                  dib;
	filter_t            *filters;
	volatile uint32_t    tx_packets;
	volatile uint32_t    tx_bytes;
	volatile uint32_t    tx_errors;
	volatile uint32_t    rx_packets;
	volatile uint32_t    rx_bytes;
	volatile uint32_t    rx_errors;
	volatile uint32_t    rx_discards;
} ethercp_if_t;

typedef struct nic
{
#define NIC_CMOS_SIZE        4       /* Recycling podule 8's allocation */
#define NIC_CMOS_FLAGS_SIZE  sizeof(uint16_t)
#define NIC_CMOS             PoduleExtraCMOS
	uint32_t cmossize;
	int32_t  cmos;
	uint16_t flags;
#define NIC_FLAG_LINK100     1      /* Link100/Link10 */
#define NIC_FLAG_LINKFULL    2      /* Full/Half */
#define NIC_FLAG_LINKAUTO    4      /* Auto/else use LINK100 & LINKFULL bits */
#define NIC_FLAG_AD10_FULL   8      /* Advertise 10baseT full/half */
#define NIC_FLAG_AD10_HALF   16
#define NIC_FLAG_AD100_FULL  32     /* Advertise 100baseT full/half */
#define NIC_FLAG_AD100_HALF  64
#define NIC_FLAG_AD1000      128    /* Advertise 1000baseT */
#define NIC_FLAG_VIRTUAL     256
#define NIC_FLAG_FLOW_GEN    512
#define NIC_FLAG_FLOW_RESP   1024
#define NIC_FLAG_UNUSED      0xF800
#define NIC_FLAG_DEFAULT     (NIC_FLAG_LINKAUTO | NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF | NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF | NIC_FLAG_AD1000)

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

	struct cpsw_softc *controller;
	ethercp_if_t       interface[NIC_MAX_INTERFACES];
} ethercp_nic_t;

/* Message and error handling */
typedef struct
{
	uint32_t errnum;
	char     errmess[8];
} internaterr_t;

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
	ERR00_NO_SUPPORTED_CPSW = ErrorBase_UnixRange,
	ERR01_UNREAL,
	ERR02_NO_EUI_SET,
	ERR03_SINGLE_INSTANCE,
	ERR04_FAIL_DETECT,
	ERR05_UNIT_IS_OFF
} ethercp_err_t;

typedef enum
{
	MSG00_INFO_LENGTH = 0,
	MSG01_IF_DRIVER,
	MSG02_IF_UNIT,
	MSG03_IF_LOCATION,
	MSG04_IF_EUI,
	MSG05_IF_CONTROLLER,
	MSG06_IF_RUNTIME,
	MSG07,
	MSG08,
	MSG09_TIME_FORMAT,
	MSG10_UP,
	MSG11_DOWN,
	MSG12_MOTHERBOARD,
	MSG13_VIRTUAL,
	MSG14,
	MSG15,
	MSG16_PASSED,
	MSG17_FAILED,
	MSG18_INFO_STATS,
	MSG19,
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
} ethercp_msg_t;

/* Debug support */
#ifdef DEBUG
#define DPRINTF(k)          printf k
#else
#define DPRINTF(k)          /* No debug */
#endif

/* Global stuff */
char *ethercp_message_lookup(ethercp_msg_t, const char *, const char *, const char *);
_kernel_oserror *ethercp_error_lookup(ethercp_err_t);
void ethercp_review_levels(uint8_t);
extern void *ethercp_messages(void); /* Generated by 'resgen' */
extern ethercp_nic_t nic[NIC_MAX_CONTROLLERS];
extern ethercp_if_t *nicunit[NIC_MAX_INTERFACES * NIC_MAX_CONTROLLERS];
extern uint8_t units;
extern struct device *device;
extern struct ifnet *nicifp;

#endif
