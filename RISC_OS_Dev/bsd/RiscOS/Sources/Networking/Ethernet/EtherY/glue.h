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
#ifndef GLUE_H
#define GLUE_H

/* Debug switches, not really interrupt safe, use with caution */
#define GLUE_DUMP_TX       0
#define GLUE_DUMP_RX       0
#define GLUE_DUMP_EUI48(k) do { size_t i; \
                                for (i = 0; i < ETHER_ADDR_LEN; i++) printf("%02X ", k ## [i]); \
                           } while (0);

/* Interface to NetBSD SMC91CXX driver */
struct ifnet
{
	void    *if_softc;

	char     if_xname[4]; /* Unused by RISC OS */
	uint32_t if_flags;    /* Unused by RISC OS */
#define IFF_NOTRAILERS 1<<20  /* Unused by RISC OS */

	int (*if_ioctl)       /* I/O control */
	      (struct ifnet *, u_long, void *);
	void (*if_watchdog)   /* Watchdog */
	      (struct ifnet *);
	void (*if_start)      /* Start interface */
	      (struct ifnet *);
	void (*if_input)      /* Input routine (from h/w driver) */
	       (struct ifnet *, struct mbuf *);

	/* Watchdog */
	uint32_t if_timer;

	/* Last level setting overrides */
	uint16_t if_matchmode;
	bool     if_passerrors;

	/* Cache of latest PHY status */
	uint16_t phy_status;
#define INT_PHY_ADDR    0     /* Datasheet section 7.7 says 00000 */
#define MII_PHYST       18
#define MII_PHYMSK      19
#define PHYST_INT       0x8000
#define PHYST_LNKFAIL   0x4000
#define PHYST_LOSSSYNC  0x2000
#define PHYST_CWRD      0x1000
#define PHYST_SSD       0x0800
#define PHYST_ESD       0x0400
#define PHYST_RPOL      0x0200
#define PHYST_JAB       0x0100
#define PHYST_SPDDET    0x0080
#define PHYST_DPLXDET   0x0040

	/* Link level structure just used as a pointer to EUI48 */
	struct sockaddr_dl *if_sadl;

	/* Handover mbuf chain */
	struct mbuf        *if_snd;
	int8_t              if_mmu;

	/* Stats */
	int      if_opackets;
	int      if_ipackets;
	int      if_oerrors;
	int      if_ierrors;
	int      if_collisions;
};

/* Just enough ethercom to make it compile */
struct ethercom
{
	struct ifnet ec_if;
};

/* Porting definitions */
#define KDASSERT(k)                /* Nothing */
#define KASSERT(k)                 /* Nothing */
#define IFQ_SET_READY(q)           /* Nothing */
#define IFQ_DEQUEUE(q,v)           do { v = *(q); *(q) = NULL; } while (0);
#define IFQ_POLL(q,v)              do { v = *(q); } while (0);
#define device_xname(k)            "ey0"
#define device_is_active(k)        TRUE
#define strlcpy(d,s,x)             strcpy(d,s)
#define rnd_add_uint32(a,b)        /* Nothing */
#define rnd_attach_source(a,b,c,d) /* Nothing */
#define device_private(k)          (struct smc91cxx_softc *)(k)
#define ALIGNBYTES                 3
#define ALIGN(p)                   (((uintptr_t)(p) + ALIGNBYTES) & ~ALIGNBYTES)
#define bpf_mtap(a,b)              /* No Berkeley packet filter */
#define ether_ioctl(a,b,c)         (0 * (int)(b) * (int)(c))
#define if_attach(a)               /* Nothing */
#define if_deactivate(a)           /* Nothing */
#define ifmedia_init(a,b,c,d)      (a)->ifm_cur = (a)
#define ifmedia_set(a,b)           (a)->ifm_cur->ifm_media = (b)
#define ifioctl_common(a,b,c)      0
#define ether_ifattach(a,b)        /* Nothing */
#define __predict_false(k)         k
#define format_bytes(a,b,c)        /* Nothing */
#define ether_sprintf(k)           "Unused"
#define panic(k)                   /* Nothing */
#define splnet()                   irqs_off()
#define splx(k)                    restore_irqs(k)
#define CLLADDR(s)                 (s) /* Used once, so point direct */
#define UNUSED(k)                  (k)=(k)
#define IFM_ETHER                  16  /* Unused by RISC OS */
#define IFM_NONE                   0   /* Unused by RISC OS */
#define IFM_10_T                   1   /* Unused by RISC OS */
#define IFM_10_5                   2   /* Unused by RISC OS */
#define IFM_FDX                    4   /* Unused by RISC OS */
#define IFM_TYPE(k)                ((k) & 0xF0)
#define IFM_SUBTYPE(k)             ((k) & 0x0F)

/* Some handy macros */
#define MIN(a,b)                   ((a) < (b) ? (a) : (b))
#define MAX(a,b)                   ((a) < (b) ? (b) : (a))
#define FALSE                      0
#define TRUE                       (!FALSE)

/* Packet transmit and receive */
typedef struct
{
	uint32_t     length;
	int8_t       mmu;
	uint8_t      unit;
} txdesc_t;
int glue_transmit(bool, uint8_t, uint16_t, struct mbuf *, uint8_t *, uint8_t *, struct ifnet *);
void glue_transmitted(int8_t, bool);
void glue_receive(struct ifnet *, struct mbuf *);
void glue_inc_rxerrors(struct ifnet *);

/* Dummy structure members */
typedef int krndsource_t;

typedef enum devact
{
	DVACT_DEACTIVATE
} devact_t;

typedef int pmf_qual_t;

typedef struct
{
	int unused;
} *device_t;

struct ifmedia
{
	int             ifm_media;
	struct ifmedia *ifm_cur;
};

/* I/O control extensions */
#define SIOCINITIFADDR  0 /* arg = none */
#define SIOCSIFFLAGS    1 /* arg = flags */
#define SIOCADDMULTI    2 /* arg = struct ifreq pointer */
#define SIOCDELMULTI    3 /* arg = struct ifreq pointer */
#define SIOCGIFMEDIA    4 /* arg = none */
#define SIOCSIFMEDIA    5 /* arg = none */
#define SIOCDRIVERSTOP  6 /* arg = none */
#define SIOCDRIVERINIT  7 /* arg = none */
#define SIOCSETERRLVL   8 /* arg = boolean TRUE to pass errors */
#define SIOCSETPROMISC  9 /* arg = spec/normal/multi/promisc */

/* Callouts */
struct callout
{
	int unused;
};
#define callout_init(a,b)       /* Uses OS_CallEvery instead */
#define callout_reset(a,b,c,d)  /* Uses OS_CallEvery instead */

/* Logging */
void aprint_normal(void *, ...);
#define aprint_error_dev        aprint_normal
#define aprint_normal_dev       aprint_normal
#define log(a, b, c)            /* Nothing */

/* Micro delay */
void delay(uint32_t);

#endif
