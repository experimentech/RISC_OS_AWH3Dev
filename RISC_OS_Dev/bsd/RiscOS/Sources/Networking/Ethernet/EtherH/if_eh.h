/*
 * Copyright (c) 2002, Design IT
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
/**************************************************************************
 * Title:       RISC OS Ethernet Driver Source
 * Authors:     Douglas J. Berry, Gary Stephenson
 * File:        if_eh.h
 *
 * Copyright © 1992 PSI Systems Innovations
 * Copyright © 1994 Network Solutions
 * Copyright © 2000 Design IT
 *
 *
 * Initial Revision 1.0         17th July 1992 DJB
 *
 * History
 *             2nd June 1993        DJB
 * Modded to stop macros for hardware addresses being "hardwired".
 *
 * 4.00        12th December 1994   GS
 * Changes for DCI 4
 *
 * 4.01        7th February 1995    GS
 * Stat structure added
 * INTERFACE_ id numbers changed to match spec
 *
 * 4.45        23rd June 2001       OSS
 * Put multicast address reference counts into per unit structure since
 * the registers themselves are per unit (does no-one test multiple units
 * these days?)
 *
 * Put software multicast discarding tables into the per filter structure
 * since multicast addresses are claimed per filter.
 *
 * 4.50 20 Nov 2002 OSS
 * LanManFS 2.22 (32 bit sadly) does specific multicast filtering and
 * these are of the form 03:00:00:00:00:01 which makes all my 23 bit
 * assumptions in the software tables fail. Changed to full 48 bits
 * of the mac address plus a byte for reference count and a spare.
 *
 ***************************************************************************/

/*
 * Initial code supplied by Acorn Computers Ltd
 */
/*
 * $Header: /home/rool/cvsroot/bsd/RiscOS/Sources/Networking/Ethernet/EtherH/h/if_eh,v 1.9 2012/10/13 21:06:53 rsprowson Exp $
 * $Source: /home/rool/cvsroot/bsd/RiscOS/Sources/Networking/Ethernet/EtherH/h/if_eh,v $
 *
 * Copyright (c) 1989 Acorn Computers Ltd., Cambridge, England
 *
 */

#ifndef __armif_if_eh_h
#define __armif_if_eh_h

#define TRUE                1
#define FALSE               0

#ifndef NULL
#define NULL                (void *)0
#endif

#define CURRENT_HW_REV      1

/*
 * hardware interface type
 */
#define INTERFACE_NONE      0
#define INTERFACE_10BASE5   1
#define INTERFACE_10BASET   2
#define INTERFACE_10BASE2   3
#define INTERFACE_COMBO_5   4
#define INTERFACE_COMBO_T   5
#define INTERFACE_SQUELCH_T 6
#define INTERFACE_ECONET    7
#define INTERFACE_SERIAL    8
#define INTERFACE_COMBO     9
#define INTERFACE_MICRO_2   10
#define INTERFACE_MICRO_T   11
#define INTERFACE_ULIMIT    4

#define INTERFACE_UNKNOWN   127

#define RST_DELAY           100000

/*
 * Definition of the NIC structure.
 *
 * Each register is 8 bits wide, which maps onto a word in I/O space.
 * The Network Interface Controller itself has 48 registers, of which
 * a single page of 16 can accessed at any one time. Page 0 is the set
 * of registers used when the chip is up & running; page 1 defines
 * Ethernet Address and multicast filters; while page 2 allows access to
 * page 0 registers which should normally be left alone, but may be required
 * for debugging.
 */
 /* Does not actually matter the order here of reg and pad,
  * since registers accessed as bytes and so go out duplicated across
  * the data bus.
  */
typedef u_char  byte;

typedef struct
{
    u_char reg;
    u_char pad[3];
} NIC_Reg;

typedef struct
{
    int r[16];
} NICRegs, *NICRegsRef;

typedef struct
{
    volatile NIC_Reg r0;
    volatile NIC_Reg r1;
    volatile NIC_Reg r2;
    volatile NIC_Reg r3;
    volatile NIC_Reg r4;
    volatile NIC_Reg r5;
    volatile NIC_Reg r6;
    volatile NIC_Reg r7;
    volatile NIC_Reg r8;
    volatile NIC_Reg r9;
    volatile NIC_Reg ra;
    volatile NIC_Reg rb;
    volatile NIC_Reg rc;
    volatile NIC_Reg rd;
    volatile NIC_Reg re;
    volatile NIC_Reg rf;
} NIC, *NICRef;

/* defines for registers that map onto the above structure */

/* page 0 (read)        */
#define command r0.reg
#define clda0   r1.reg
#define clda1   r2.reg
#define bnry    r3.reg
#define tsr     r4.reg
#define ncr     r5.reg
#define fifo    r6.reg
#define isr     r7.reg
#define crda0   r8.reg
#define crda1   r9.reg
#define rsr     rc.reg
#define cntr0   rd.reg
#define cntr1   re.reg
#define cntr2   rf.reg

/* page 0 (write)       */
#define pstart  r1.reg
#define pstop   r2.reg
/*      bnry    r3.reg */
#define tpsr    r4.reg
#define tbcr0   r5.reg
#define tbcr1   r6.reg
#define rsar0   r8.reg
#define rsar1   r9.reg
#define rbcr0   ra.reg
#define rbcr1   rb.reg
#define rcr     rc.reg
#define tcr     rd.reg
#define dcr     re.reg
#define imr     rf.reg

/* page 0   AT/LANTIC   */
#define mcra    ra.reg
#define mcrb    rb.reg

/* page 1               */
#define par0    r1.reg
#define par1    r2.reg
#define par2    r3.reg
#define par3    r4.reg
#define par4    r5.reg
#define par5    r6.reg
#define curr    r7.reg
#define mar0    r8.reg
#define mar1    r9.reg
#define mar2    ra.reg
#define mar3    rb.reg
#define mar4    rc.reg
#define mar5    rd.reg
#define mar6    re.reg
#define mar7    rf.reg

/*
 * defines/macros for manipulating the command register
 *
 * NOTE: the page select bits can only be modified when the
 * remote DMA is idle, and the DMA commands can only be issued
 * when the NIC is running and in page 0.
 *
 */
#define STP             (1 << 0)
#define STA             (1 << 1)
#define TXP             (1 << 2)
#define DMA_READ        0x01
#define DMA_WRITE       0x02
#define DMA_SENDP       0x03
#define DMA_ABORT       0x04
#define DMA_IDLE        DMA_ABORT
#define DMA_SHIFT       3
#define PAGE_SHIFT      6
#define NIC_STOPPED     0
#define NIC_RUNNING     1
#define NIC_LIVE(x)     ((x) ? STA : STP)
#define SEL_PAGE(x,y)   (((x) << PAGE_SHIFT) | (DMA_IDLE << DMA_SHIFT) | \
                        NIC_LIVE(y))
#define START_DMA(x)    (((x) << DMA_SHIFT) | STA)
#define CMD_INIT_VALUE  (DMA_ABORT << DMA_SHIFT) | STP              /* = 0x21       */

/*
 * defines for bits in remaining registers
 */

/* isr/imr */
#define PRX             (1 << 0)
#define PTX             (1 << 1)
#define RXE             (1 << 2)
#define TXE             (1 << 3)
#define OVW             (1 << 4)
#define CNT             (1 << 5)
#define RDC             (1 << 6)
#define RST             (1 << 7)
#define IMR_INIT_VALUE  PRX | PTX | RXE | TXE | OVW | CNT

/* dcr */
#define WTS             (1 << 0)
#define BOS             (1 << 1)
#define LAS             (1 << 2)
#define LS              (1 << 3)
#define AUREM           (1 << 4)
#define FIFOT_SHIFT     5
#ifdef DRIVER16BIT
#define WORD_THRESH1    0
#define WORD_THRESH2    1
#define WORD_THRESH4    2
#define WORD_THRESH6    3
#define DCR_INIT_VALUE  WTS | LS | AUREM        /* Select 16-bit.       */
#else
#define BYTE_THRESH2    0
#define BYTE_THRESH4    1
#define BYTE_THRESH8    2
#define BYTE_THRESH12   3
#define DCR_INIT_VALUE  LS | AUREM              /* Select 8-bit.        */
#endif
#define FIFO_THRESH(x)  ((x) << FIFOT_SHIFT)

/* tcr */
#define INCRC           (1 << 0)
#define ATD             (1 << 3)
#define OFST            (1 << 4)
#define LOOPM_SHIFT     1
#define LIVE_NET        0
#define LOOPBACK1       1
#define LOOPBACK2       2
#define LOOPBACK3       3
#define TCR_INIT_VALUE  0
#define LOOP_MODE(x)    ((x) << LOOPM_SHIFT)

/* tsr */
#define TXOK            (1 << 0)
#define COL             (1 << 2)
#define ABT             (1 << 3)
#define CRS             (1 << 4)
#define FU              (1 << 5)
#define CDH             (1 << 6)
#define OWC             (1 << 7)

/* rcr */
#define SEP             (1 << 0)
#define ARUNT           (1 << 1)
#define AB              (1 << 2)
#define AM              (1 << 3)
#define PRO             (1 << 4)
#define MON             (1 << 5)
#define RCR_SPECIFIC    0
#define RCR_INIT_VALUE  AB
#define RCR_MULTICAST   AB | AM
#define RCR_PROMISCUOUS AB | AM | PRO

/* rsr */
#define RSR_PRX         (1 << 0)
#define CRCE            (1 << 1)
#define FAE             (1 << 2)
#define FO              (1 << 3)
#define MPA             (1 << 4)
#define PHY             (1 << 5)
#define DIS             (1 << 6)
#define DFR             (1 << 7)

#define nicbnry(x)      x->bnry
#define nicisr(x)       x->isr
#define niccurr(x)      x->curr


/*
 * packet field lengths
 */
#define HW_ADDR_LEN  6                          /* length of hardware address */
#define PACK_HDR_LEN ((2 * HW_ADDR_LEN) + 2)    /* bytes in packet header */
#define BUFF_HDR_LEN 4                          /* bytes in Rx buffer header */
#define CRC_LEN      4                          /* CRC bytes in a packet */
#define ETHERMAXP    (ETHERMTU + PACK_HDR_LEN)  /* max packet size */

/*
 * NIC buffer management. The Ethernet card has on board static RAM
 * which is split between transmit and receive buffers. All received
 * data is immediately read out into a chain of mbufs, whereas the driver
 * maintains a queue of pending transmissions which are currently in the
 * transmit buffer.
 *
 * Each member of the transmit buffer pool has an area of RAM reserved
 * for its use, this area being enough pages to store an ETHERMTU packet.
 * All RAM not reserved for a transmit buffer is used for the receive
 * buffer.
 *
 */


#ifdef DRIVER16BIT
#ifdef SMALL_RAM
#define NIC_BUFFER      (16 * 1024)
#define MAXTXQ          4
#define TX_START        1
#else
#define NIC_BUFFER      (64 * 1024)
#define MAXTXQ          16
#define TX_START        1
#endif
#else
#define NIC_BUFFER      (32 * 1024)
#define MAXTXQ          9
#define TX_START        0
#endif

#define NIC_PAGE        256             /* buffer page size */
#define PAGES_PER_TX    (((ETHERMAXP - 1) / NIC_PAGE) + 1)
#define RX_START        (TX_START + (MAXTXQ * PAGES_PER_TX))
#define RX_END          (NIC_BUFFER / NIC_PAGE)
#define MAXDMA          3

typedef struct _txq
{
    struct _txq *TxNext;
    u_short TxStartPage;
    u_short TxByteCount;
} Txq, *TxqRef; /* transmit queue */


/*
 * ROM definitions.
 */
#define ROM_SIZE            (128 * 1024L)
#define ROM_PAGE_SIZE       512             /* Size of ROM page.        */
#define NUM_ROM_PAGES       256             /* Number of pages.         */
#define ROM_600_PAGE_SIZE   4096
#define NUM_ROM_600_PAGES   256

#define ENABLE_DMA          3
#define DISABLE_DMA         1

/*
 * Define I/O addresses used by the expansion card:
 */
#define MAX_NUM_SLOTS   9      /* For static allocation, the actual number is read at runtime */

/*
 * Addresses for podules (EtherLan100/200/500)
 */
#define EHCARD_CHIP_OFFSET     0x0    /* MEMC space */
#define EHCARD_DMA_OFFSET      0x800  /* MEMC space */
#define EHCARD_PAGEREG_OFFSET  0x0    /* Podule space */
#define EHCARD_CNTRL_OFFSET    0x800  /* Podule space */
#define EHCARD_CNTRL_OFFSET2   0x2800 /* Podule space */
#define STAT2_OFFSET           0x2000 /* Control register (offset from EHCARD_CNTRL_OFFSET) */

/*
 * Addresses for NIC card (EtherLan600)
 */
#define EHCARD6_CHIP_OFFSET    0x0
#define EHCARD6_DMA_OFFSET     0x40
#define EHCARD6_PAGEREG_OFFSET 0x100
#define EHCARD6_CNTRL_OFFSET   0x200

/*
 * Addresses of card in EASI space (EtherLan700)
 */
#define EHCARD7_CHIP_OFFSET    0x00800800
#define EHCARD7_DMA_OFFSET     0x00802800
#define EHCARD7_CNTRL_OFFSET   0x00800000
#define EHCARD7_CNTRL_OFFSET2  0x00802000

/*
 * Bit twiddling macros for hardware registers.
 */
/* Write only lines.            */
#define EH_INTR_MASK    (1 << 0)        /* Interrupt Mask.              */
#define EH_ID_CONTROL   (1 << 1)        /* ID control.                  */
#define EH_RPR_WD       (1 << 0)        /* ROM Page Reg. write disable. */
#define EH_TPISEL       (1 << 1)        /* TPI select.                  */

/* Read only lines.             */
#define EH_INTR_STAT    (1 << 0)        /* Interrupt status.            */
#define EH_GOODLINK     (1 << 1)        /* TPI Goodlink status.         */
#define EH_TPI_STAT     (1 << 0)        /* TPI/AUI select.              */
#define EH_POL          (1 << 1)        /* TPI polarity status.         */

/* RiscPC interface select commands.        */
#define EH6_10BTSEL     (0)             /* TPI (10BaseT) select.                    */
#define EH6_10B2SEL     (1)             /* Thin ethernet (10Base2) select.          */
#define EH6_AUISEL      (2)             /* AUI port select.                         */
#define EH6_10BTRSSEL   (3)             /* TPI (10BaseT) resduced squelch select.   */

/* RiscPC Mode Control Register defaults.       */
#define EH6_MCRA        0x18

/*
 * the fib structure holds the info for frame filtering, it contains the frames
 * accepted and what to do with them.
 */
/* OSS 23 June 2001 Some useful defines for the efficient multicast discard */
/* OSS 4.51 20 Nov 2002 Convert to a structure for each softmult element.
   Note that the use_count always seems to be 0 or 1 ie. nothing does
   multiple claims, but it gives us something quick and simple to test
   for whether an entry is used or not. */

typedef struct
{
    unsigned char       mac[6];
    unsigned char       use_count;
    unsigned char       spare;
} SoftmultEntry;

#define SOFTMULT_COUNT 16

#define MAX_MAR         8uL
#define MAR_OFFSET      8uL
#define MAR_BITS        64

typedef struct eh_fib
{
    int           flags;        /* flags */
    int           unit;         /* unit number */
    int           frame_type;   /* frame type */
    int           frame_level;  /* frame class/level 1-4 */
    int           add_level;    /* address filtering level 0-3 */
    int           err_level;    /* 0 pass only error free frames, 1 pass all frames */
    u_int         handler;      /* address of protocol modules received frame handler */
    u_char        *private;     /* protocol module's private workspace pointer */

    /* OSS 4.51 20 Nov 2002 Changed from [64] to [MAR_BITS] which is set to 64 */
    int           mar_refcount[MAR_BITS];  /* multicast address registers ref count */

    /* OSS 23 June 2001 This is a table for software skipping incoming multicasts
       which hash to the same bit in the 64 bit hardware address registers. It is
       held per filter because multicasts are requested per filter */
    SoftmultEntry softmult[SOFTMULT_COUNT];     /* OSS 4.51 20 Nov 2002 Array of struct */
    unsigned int  softmult_discards;            /* Statistic */
    unsigned int  softmult_allowed;             /* Statistic */
    unsigned char softmult_disabled;            /* TRUE or FALSE */

    struct eh_fib *next_fib;    /* pointer to next fib or NULL if last one */
} Fib, *FibRef;

typedef struct scatter_list
{
   u_int address;
   u_int length;
} Scatter, *ScatterRef;


typedef struct dma_request
{
   u_int  dma_tag;
   volatile u_char *eh_dmactrl;               /* do not move this as the assember routines rely on */
   int    flags;                              /* it being here!! */
   DibRef eh_dib;
   struct eh_fib *fp;
   struct mbuf *m;
   ScatterRef sp;
   struct eh_softc *en;
} DMAReq, *DMARef;


/*
 * The eh_softc structure is the main driver control block, one
 * per unit. It contains all information needed to access the
 * ethernet card hardware.
 */
struct eh_softc
{
    u_char      eh_slot;        /* physical slot number         */
    short       eh_unit;        /* Unit number                  */
    char        eh_addr[6];     /* physical ethernet address    */
    u_short     eh_flags;       /* always have some of these    */
    int         eh_imr_value;   /* current value for imr        */
    int         eh_irqh_active; /* irq handler active           */
    int         eh_tx_active;   /* swi transmit in progress     */
    u_char      eh_rev;         /* hardware revision number     */
    u_char      eh_interface;   /* Interface type.              */
    int         eh_cardtype;    /* E100, E200, etc              */
    int         rom_page_size;  /*                              */
    int         buffer_pstart;  /* Start page for onboard buffer*/
    void        (*io_out)();    /* Steam driven out to DMA port routine.*/
    void        (*io_hout)();   /* Steam driven packet header output.   */
    void        (*io_flushout)();  /* Flush DMA byte output buffer.     */
    DibRef      eh_dib;         /* pointer to driver info block         */
    FibRef      eh_fib;         /* pointer to start of fib chain        */
    struct eh_softc *eh_ptr;    /* pointer to interface that has frames for this one */
    u_char      *eh_location;   /* pointer to desciption of location of card */
/* generic interface statistics */
    int         eh_ipackets;    /* packets received on interface        */
    int         eh_ierrors;     /* input errors on interface            */
    int         eh_opackets;    /* packets sent on interface            */
    int         eh_oerrors;     /* output errors on interface           */
    int         eh_collisions;  /* collisions on csma interfaces        */
    int         eh_reject;      /* number of rejected packets.          */
    int         eh_nombuf;      /* attempt to claim mbuf that failed    */
    int         eh_nodma;       /* no free DMA struct                   */
    int         eh_ovw;         /* overwrite warning                    */
    int         eh_toobig;      /* Number of packets that are too big.  */
    int         eh_cmosbase;    /* base address of cmos ram             */
    int         eh_dmapackets;  /* number of packets transfered using dma */
    int         eh_primary_dma; /* primary dma logical channel          */
    int         eh_dma_channel; /* channel registration handle          */
    int         eh_dma_busy;    /* flag to indicate if dma is busy      */
    int         eh_lastsize;
    int         eh_lastcount;
    int         eh_framecount;
    DMAReq      eh_dc[MAXDMA];
    int         eh_rx_pending;  /* flag to indicate rx is pending       */
    u_char      eh_next_pkt;    /* next packet pointer                  */
    int         eh_easi_base;   /* base address of easi space           */
    int         eh_deviceno;    /* claimed device number for IRQs       */
    NICRef      Chip;           /* The hardware.                        */
#ifdef DRIVER16BIT
    volatile u_int *dma_port;   /* Where remote DMA data appears.       */
#else
    volatile u_char *dma_port;  /* Where remote DMA data appears.       */
#endif
    volatile u_char *page_reg;  /* EPROM page register.                 */
    volatile u_char *cntrl_reg; /* control register                     */
    volatile u_char *cntrl_reg2;/* control register2                    */
    int         control_reg;    /* current control register value       */
    int         control_reg2;   /* 2nd current control register value   */
    int         rcr_status;     /* Current setting of receive config register */
    u_char      *rom;           /* ROM.                                 */
    Txq         TxqPool[MAXTXQ];/* pool of transmit structures */
    TxqRef      TxqFree;        /* chain of free transmit structures */
    TxqRef      TxPending;      /* chain of pending transmits */
    struct
    {
        u_int crc_count;        /* CRC failure */
        u_int fae_count;        /* Frame Alignmnt Errors */
        u_int frl_count;        /* Frames Lost (no resources) */
        u_int ovrn_count;       /* FIFO Overrun */
        u_int undrn_count;      /* FIFO Underrun */
        u_int coll_count;       /* Number of collisions that eventually
                                 * went out OK */
        u_int xscoll_count;     /* Number of excessive collisions */
        u_int maxp_count;       /* attempt to transmit packet > max packet size */
        u_int notx_count;       /* no free tx structures */
        u_int rdc_count;        /* rdc failure during tx */
    } errors;

    /* OSS 23 June 2001 Put reference counts for multicast bits in here. They
       used to be global but since the real hardware is per unit then the
       reference counts need to be per unit as well. */

    int mar_refcount[64];
};


/*
 * Flag Bits
 */
#define EH_FAULTY            (1 << 0)  /* Card is dead for some reason  */
#define EH_RUNNING           (1 << 1)  /* Card is `live' on the network */
#define EH_SQETEST           (1 << 2)  /* CD/Heartbeat test is valid    */
#define EH_SQEINFORMED       (1 << 3)  /* CD/Heartbeat failure logged   */
#define EH_RECOVERABLE_ERROR (1 << 4)  /* Ethernet is not connected     */
#define EH_NOMAU             (1 << 5)  /* No MAU is attatched           */

/*
 * members of the errors structure
 */
#define ncrc    errors.crc_count
#define nfae    errors.fae_count
#define nfrl    errors.frl_count
#define novrn   errors.ovrn_count
#define nundrn  errors.undrn_count
#define ncoll   errors.coll_count
#define nxscoll errors.xscoll_count
#define nmaxp   errors.maxp_count
#define nnotx   errors.notx_count
#define nrdc    errors.rdc_count

/* dma manager things */
#define DMA_CONTROL_READ  0
#define DMA_CONTROL_WRITE 1

#ifdef KERNEL
extern struct en_softc *eh_softc[]; /* array of control structures, indexed
                                     * on logical slot number */

extern int n_en;                    /* number of cards KERNEL is
                                     * configured for */
#endif /* KERNEL */


/*
 * Debug control
 */
#ifdef KERNEL
extern int en_block;

#define BLOCK_BROAD     (1 << 0)
#define BLOCK_STARTARP  (1 << 1)
#define BLOCK_PROM      (1 << 4)

#ifdef EN_DEBUG

extern int en_debug;
#define DoDebug(x)      (en_debug & (x))

#define DEBUG_ISR       (1 << 0)
#define DEBUG_RX        (1 << 1)
#define DEBUG_TX        (1 << 2)
#define DEBUG_TRAILERS  (1 << 3)
#define DEBUG_DATA_IN   (1 << 5)
#define DEBUG_DATA_OUT  (1 << 6)
#define DEBUG_MINIMUM   (1 << 8)
#define DEBUG_VERBOSE   (1 << 9)

#endif /* EN_DEBUG */
#endif /* KERNEL */

#define MAX_RDC_RETRIES         5               /* max. no of RDC failures */
#define RDC_RECOVER_PERIOD      10              /* delay to give RDC a
                                                 * chance to appear */
#define NIC_RESET_PERIOD        2000            /* how long to wait after reset */

#define ETHERMTU        1500
#define ETHERMIN        (60-14)
#define ADDR_MULTICAST  0x01                    /* in byte[0] of hardware address */

#define INQUIRE_FLAGS \
  (INQ_MULTICAST | INQ_PROMISCUOUS | INQ_RXERRORS | INQ_HWADDRVALID | \
   INQ_SOFTHWADDR | INQ_HASSTATS | INQ_FILTERMCAST)

/*
 * i-cubed and Design IT EtherLan product codes.
 */
#define EH_TYPE_200     0xBD
#define EH_TYPE_100     0xCF
#define EH_TYPE_500     0xD4
#define EH_TYPE_600     0xEC
#define EH_TYPE_700     0x12f

/*
 * acorn EtherLan product codes
 */
#define EH_ACORN_100    0x11c
#define EH_ACORN_200    0x11d
#define EH_ACORN_500    0x11f
#define EH_ACORN_600    0x11e
#define EH_ACORN_700    0x12e

#define HZ              700

#ifdef DRIVER16BIT
#define DATA_MASK       0xffff
#else
#define DATA_MASK       0xff
#endif

#define LIVE    1

/*
 * Defines size of ROM cache size.
 * Caution should be used here. RM memory seems to increase in chumks of 32K bytes.
 * Using this size meant no more memory was being used in the RMA after initialisation.
 * Changing this to 16K used up another 32K of RMA.
 */
#define HEAD_SIZE       800
#define TAIL_MARGIN     512
#define SET_TAILS       0x80000001
#define SET_TAILE       0x80000002
#define SET_HEAD        0x80000003

/*
 * Public functions.
 */
void eh_statshow(void);
void abort_packet(struct eh_softc *, int, int);
void eh_ehtest(void);
void eh_softreset(void);
void eh_intr(register struct eh_softc *);
void eh_final(void *);
void eh_init(void);
int  eh_readcmos(struct eh_softc *, int);
_kernel_oserror *eh_cmos_virtual(const char *, int);
_kernel_oserror *eh_cmos_connection(const char *, int);
void nulldev(u_char);
void eh_recv(struct eh_softc *, NICRef);
void eh_call_back(void);
void eh_enint(struct eh_softc *);
void start_tx(struct eh_softc *, NICRef);
void shutdown(struct eh_softc *, NICRef, u_char *);
void startup(struct eh_softc *, NICRef, u_char);
int enioctl(int, int, int);
int tx_mbufs(register struct eh_softc *, struct mbuf *, u_char *, u_char *, int, int);
int eh_dciversion(_kernel_swi_regs *);
int eh_inquire(_kernel_swi_regs *);
int eh_getnetworkmtu(_kernel_swi_regs *);
int eh_setnetworkmtu(_kernel_swi_regs *);
int eh_transmit(_kernel_swi_regs *);
int eh_filter(_kernel_swi_regs *);
int eh_stats(_kernel_swi_regs *);
int eh_multicastrequest(_kernel_swi_regs *);

/*
 * Public data.
 */
extern int eh_irqh_active;
extern int virtual;

#endif/*__armif_if_en_h*/

/* EOF if_en.h */
