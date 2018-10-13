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
#ifndef GLUE_H
#define GLUE_H

/* Debug switches, not really interrupt safe, use with caution */
#define GLUE_DUMP_TX       0
#define GLUE_DUMP_RX       0
#define GLUE_DUMP_EUI48(k) do { size_t i; \
                                for (i = 0; i < ETHER_ADDR_LEN; i++) printf("%02X ", k ## [i]); \
                           } while (0);

/* Interface to NetBSD CPSW driver */
struct ifnet
{
	void    *if_softc;

	char     if_xname[4]; /* Unused by RISC OS */
	uint32_t if_flags;    /* Unused by RISC OS */
	uint32_t if_capabilities; /* Unused by RISC OS */

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
	int (*if_init)        /* Initialise */
	      (struct ifnet *);

	/* The bits kept per MAC/PHY pair */
	struct
	{
		/* Identity of the MAC */
		uint8_t  enaddr[ETHER_ADDR_LEN];

		/* Last level setting overrides */
		uint16_t if_matchmode;
		bool     if_passerrors;

		/* Cache of latest PHY status */
		uint16_t phy_status;
#define MII_VSPHYST     31 /* Micrel KSZ9031 vendor specific */
#define PHYST_LNKFAIL   0x0001
#define PHYST_1KMASTER  0x0004
#define PHYST_DPLXDET   0x0008
#define PHYST_SPD10     0x0010
#define PHYST_SPD100    0x0020
#define PHYST_SPD1000   0x0040
#define PHYST_JAB       0x0200
#define PHYST_INTLVL    0x4000
#define MII_MMDCCD      2 /* Micrel KSZ9031 common control */
#define MII_MMDCCA      0
#define MMDCC_LEDOVRD   (1u<<4)
#define MMDCC_LEDMODE   (1u<<3)
#define MMDCC_CLK25MODE (1u<<1)
		uint32_t phy_id;
		int8_t   phy_address;
	} mac[2];

	/* Watchdog */
	uint32_t if_timer;

	/* Handover mbuf chain */
	struct mbuf        *if_snd;
	uint8_t             if_sndport;
	uint8_t             if_sndunit;

	/* Stats */
	int      if_opackets;
	int      if_ipackets;
	int      if_oerrors;
	int      if_ierrors;
};

/* Just enough ethercom to make it compile */
struct ethercom
{
	struct ifnet ec_if;
	struct mii_data *ec_mii;
};

/* Porting definitions */
#define KASSERT(k)                 /* Nothing */
#define IFQ_SET_READY(q)           /* Nothing */
#define IFQ_DEQUEUE(q,v)           do { v = *(q); *(q) = NULL; } while (0);
#define IFQ_POLL(q,v)              do { v = *(q); } while (0);
#define m_length(m)                (MBCTL.count_bytes)(&MBCTL,(m))
#define powerof2(x)                ((((x)-1)&(x))==0)
#define roundup2(v,r)              (((v)+((r)-1)) & ~((r)-1))
#define CTASSERT(e)                CTASSERT0(e, __LINE__)
#define CTASSERT0(e,n)             CTASSERT1(e,n)
#define CTASSERT1(e,n)             typedef char _ct ## n[(e) ? 1 : -1]
#define device_xname(k)            "ecp"
#define strlcpy(d,s,x)             strcpy(d,s)
#define device_private(k)          (struct cpsw_softc *)(k)
#define MCLBYTES                   4096
#define hz                         1
#define ISSET(a,b)                 (((a) & (b)) ? 1 : 0)
#define __BIT(k)                   (1u<<(k))
#define __BITS(hi,lo)              ((__BIT((hi)+1)-1)^(__BIT((lo))-1))
#define __SHIFTOUT(a,b)            shiftout(a,b)
#define ifmedia_init(a,b,c,d)      (a)->ifm_cur = (a)
#define ifmedia_add(a,b,c,d)       /* Nothing */
#define ifmedia_set(a,b)           /* Nothing */
#define ifmedia_delete_instance(a,b) /* Nothing */
#define if_attach(a)               glue_attachif(a)
#define if_detach(a)               /* Nothing */
#define ether_ifattach(a,b)        /* Nothing */
#define ether_ifdetach(a)          /* Nothing */
#define ether_sprintf(k)           "Unused"
#define ether_ioctl(a,b,c)         (0 * (int)(b) * (int)(c))
#define __predict_false(k)         k
#define __diagused                 /* Nothing */
#define __arraycount(a)            (sizeof((a))/sizeof((a[0])))
#define bpf_mtap(a,b)              /* No Berkeley packet filter */
typedef int cfdata_t;              /* Unused type */
typedef int *prop_dictionary_t;    /* Unused type */
#define device_properties(k)       NULL
#define sitara_cm_reg_write_4(a,b) /* Leave the HAL to control setup */
#define KERNHIST_FUNC(f)           /* Nothing */
#define KERNHIST_LOG(a,b,c,d,e,f)  /* Nothing */
#define KERNHIST_INIT(a,b)         /* Nothing */
#define kmem_zalloc(s,f)           calloc((s),1)
#define kmem_alloc(s,f)            malloc((s))
#define kmem_free(p,s)             free((p))
#define splnet()                   irqs_off()
#define splx(k)                    restore_irqs(k)
#define UNUSED(k)                  (k)=(k)
#define IFM_ETHER                  16  /* Unused by RISC OS */
#define IFM_MANUAL                 0   /* Unused by RISC OS */
#define IFM_AUTO                   1   /* Unused by RISC OS */

/* Some handy macros */
#define MIN(a,b)                   ((a) < (b) ? (a) : (b))
#define MAX(a,b)                   ((a) < (b) ? (b) : (a))
#define FALSE                      0
#define TRUE                       (!FALSE)

/* Packet transmit and receive */
int glue_transmit(bool, uint8_t, uint16_t, struct mbuf *, uint8_t *, uint8_t *, struct ifnet *);
void glue_transmitted(uint8_t, size_t, bool);
void glue_receive(struct ifnet *, struct mbuf *);
void glue_inc_rxerrors(uint8_t);
void glue_attachif(struct ifnet *);

/* Dummy structure members */
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
#define SIOCSETERRLVL   8 /* arg = boolean TRUE to pass errors */
#define SIOCSETPROMISC  9 /* arg = spec/normal/multi/promisc */

/* Autoconf attach details */
struct cfattach
{
	size_t ca_devsize;
	void (*ca_attach)(device_t, device_t, void *);
	int (*ca_detach)(device_t, int);
};
#define CFATTACH_DECL_NEW(name,size,b,attach,detach,d) struct cfattach name ## _ca = { size, attach, detach }
extern struct cfattach cpsw_ca;    /* Autoconf attach details */

struct obio_attach_args
{
	int             obio_intrbase;
	uintptr_t       obio_addr;
	size_t          obio_size; /* Unused by RISC OS */
	uintptr_t       obio_iot;  /* Unused by RISC OS */
	void           *obio_dmat; /* Unused by RISC OS */
};
void obio_attach_from_hal_device(struct obio_attach_args *, struct device *); 

void intr_disestablish(void *);
void *intr_establish(int, int, int, int (*)(void *), void *);
#define IPL_VM                  0 /* HAL does priority */
#define IST_LEVEL               0 /* HAL does priority */

/* Callouts */
typedef void *callout_t;
#define callout_init(a,b)       /* Nothing to do for OS_CallEvery */
#define callout_destroy(a)      /* Nothing */
void callout_schedule(callout_t *, int);
void callout_setfunc(callout_t *, void(*)(void *), void *);
bool callout_stop(callout_t *);
void callout_callevery(void);

/* Little helpers */
uint32_t shiftout(uint32_t, uint32_t);

/* Logging */
void aprint_normal(void *, ...);
#define aprint_naive            aprint_normal
#define aprint_error_dev        aprint_normal
#define aprint_normal_dev       aprint_normal
#define aprint_debug_dev        aprint_normal
#define device_printf           aprint_normal

/* Micro delay */
void delay(uint32_t);

#endif
