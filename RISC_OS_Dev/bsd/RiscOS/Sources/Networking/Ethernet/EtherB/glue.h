/*
 * Copyright (c) 2012, RISC OS Open Ltd
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
#ifndef GLUE_H
#define GLUE_H

/* Debug switches, not really interrupt safe, use with caution */
#define GLUE_DUMP_TX       0
#define GLUE_DUMP_RX       0
#define GLUE_DUMP_EUI48(k) do { size_t i; \
                                for (i = 0; i < ETHER_ADDR_LEN; i++) printf("%02X ", k ## [i]); \
                           } while (0);

/* Interface to NetBSD SEEQ8005 driver */
struct ifnet
{
	void    *if_softc;
	char     if_xname[4]; /* Unused by RISC OS */
	uint32_t if_flags;    /* Unused by RISC OS */
#define IFF_NOTRAILERS 1<<20  /* Unused by RISC OS */

	int (*if_init)        /* Initialise */
	      (struct ifnet *);
	int (*if_ioctl)       /* I/O control */
	      (struct ifnet *, u_long, void *);
	void (*if_watchdog)   /* Watchdog */
	      (struct ifnet *);
	void (*if_start)      /* Start interface */
	      (struct ifnet *);
	void (*if_stop)       /* Stop interface */
	      (struct ifnet *, int);
	void (*if_input)      /* Input routine (from h/w driver) */
	       (struct ifnet *, struct mbuf *);

	/* Watchdog */
	uint32_t if_timer;

	/* Last level setting overrides */
	uint16_t if_matchmode;
	uint16_t if_passerrors;

	/* Receive packet status of packet being collected */
	uint16_t rx_status;

	/* Link level structure just used as a pointer to EUI48 */
	struct sockaddr_dl *if_sadl;

	/* Handover mbuf chain */
	struct mbuf *if_snd;
	int8_t   tx_order[EA_TX_BUFFER_COUNT];

	/* Placeholders since we support more than 1 interface */
	int      if_opackets;
	int      if_ipackets;
	int      if_oerrors;
};

/* Just enough ethercom to make it compile */
struct ethercom
{
	struct ifnet ec_if;
};

/* Porting definitions */
#define KASSERT(k)              /* Nothing */
#define IFQ_SET_READY(q)        /* Nothing */
#define IFQ_DEQUEUE(q,v)        do { v = *(q); *(q) = NULL; } while (0);
#define device_xname(k)         "eb0"
#define strlcpy(d,s,x)          strcpy(d,s)
#define rnd_add_uint32(a,b)     /* Nothing */
#define min(a,b)                ((a) < (b) ? (a) : (b))
#define max(a,b)                ((a) < (b) ? (b) : (a))
#define MCLBYTES                4096
#define ALIGNBYTES              3
#define ALIGN(p)                (((uintptr_t)(p) + ALIGNBYTES) & ~ALIGNBYTES)
#define bpf_mtap(a,b)           /* No Berkeley packet filter */
#define ether_ioctl(a,b,c)      (0 * (int)(b) * (int)(c))
#define __predict_false(k)      k
#define splnet()                irqs_off()
#define splx(k)                 restore_irqs(k)
#define CLLADDR(s)              (s) /* Used once, so point direct */
#define UNUSED(k)               (k)=(k)
#define IFM_ETHER               0   /* Unused by RISC OS */
#define IFM_NONE                0   /* Unused by RISC OS */

/* Some handy macros */
#define MIN(a,b)                ((a) < (b) ? (a) : (b))
#define MAX(a,b)                ((a) < (b) ? (b) : (a))
#define FALSE                   0
#define TRUE                    (!FALSE)

/* Packet transmit and receive */
typedef struct
{
	uint32_t     length;
	bool         inuse;
	uint8_t      unit;
} txdesc_t;
typedef enum
{
	HW_BROADCAST,
	HW_MULTICAST,
	HW_SPECIFIC
} hwaddr_t;
int glue_transmit(bool, uint8_t, uint16_t, struct mbuf *, uint8_t *, uint8_t *, struct ifnet *);
void glue_transmitted(uint8_t, bool);
void glue_receive(struct ifnet *, struct mbuf *);
void glue_inc_rxerrors(void);

/* Dummy structure members */
typedef int krndsource_t;

typedef struct
{
	int unused;
} device_t;

struct ifmedia
{
	int unused;
};

/* I/O control extensions */
#define IOCTL_SET_MATCHMODE     0 /* arg = CFG1 match mode bits */
#define IOCTL_PASS_RXERRORS     1 /* arg = CFG2 error mode bits */
#define IOCTL_TEST_IRQ_SET      2 /* arg = none */
#define IOCTL_TEST_IRQ_MASK     3 /* arg = none */
#define IOCTL_TEST_IRQ_RESTORE  4 /* arg = none */
#define IOCTL_LOOPBACK          5 /* arg = TRUE/FALSE */
#define IOCTL_HEAR_MYSELF       6 /* arg = TRUE/FALSE */
#define IOCTL_ADD_TX_CRC        7 /* arg = TRUE/FALSE */
#define IOCTL_STRIP_RX_CRC      8 /* arg = TRUE/FALSE */
void glue_set_levels(struct ifnet *);

/* Logging */
typedef enum
{
	LOG_WARNING,
	LOG_ERR,
} log_severity_t;
#define log                     logentry /* Avoid <maths.h> conflict */
void logentry(log_severity_t, const char *, ...);

/* Micro delay */
void delay(uint32_t);

#endif
