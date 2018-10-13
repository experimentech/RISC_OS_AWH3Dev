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
 * File:        if_eh.c
 *
 * Copyright © 1992 PSI Systems Innovations
 * Copyright © 1994 i-cubed Limited
 * Copyright © 1995-1998 Network Solutions
 * Copyright © 2000-2002 Design IT
 *
 * Current issues:
 * 1. what to do when mbuf manager refuses to allocate any more mbufs
 * 2. autosensing after card has started or cable is reconnected
 * 3. txpending while tx buffer is full errors?
 *
 **************************************************************************/

/*
 * Initial code supplied by Acorn Computers Ltd, thank you very much.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include <kernel.h>
#include <swis.h>
#include "AsmUtils/irqs.h"
#include "Global/OsBytes.h"
#include "Global/OsWords.h"

#include <sys/types.h>
#include <sys/dcistructs.h>
#include <sys/errno.h>
#include <sys/mbuf.h>
#include <inetlib.h>

#include "if_eh.h"
#include "EtherHHdr.h"
#include "module.h"
#include "Init.h"
#include "eh_io.h"

/*
 * Conditional compilation defines.
 */
#ifdef DRIVER16BIT
#define WINBODGEDCR2
#define WINBODGE_DCR_1R
#endif

/* abort packets by skiping to next one instead of reading data from card */
#define ABORTSKIP

/* #define DEBUG1               */
/* #define DEBUGMULTICAST       */
/* #define DEBUGINT             */
/* #define BORDER               */
/* #define DEBUGABORT           */
/* #define TESTCODE             */
/* #define DEBUGDMA             */
/* #define DEBUGMBUF            */
/* #define DEBUGFILTER          */
/* #define DEBUGRX              */
/* #define DEBUG                */
/* #define DEBUGTX              */
/* #define DEBUGB               */
/* #define TRACE_ROUTINES       */
/* #define DEBUG_ERR            */
/* #define DEBUGC               */

/*
 * Local routines.
 */
static int eh_disint(struct eh_softc *);
static int eh_read(struct eh_softc *, NICRef);
static int eh_bringup(int);
static void tx_done(struct eh_softc *, NICRef);
static int eh_tx_main(_kernel_swi_regs *);
static void eh_txfailed(struct eh_softc*, NICRef);
static void eh_rxfailed(struct eh_softc*, NICRef);
static void eh_txdone(struct eh_softc *, NICRef);
static struct eh_fib *find_protocol(struct eh_softc *, int);
#ifdef DRIVER16BIT
static void load_packet(struct eh_softc *, u_char *, u_char *, u_short, register struct mbuf *, volatile u_int *, int);
#else
static void load_packet(struct eh_softc *, u_char *, u_char *, u_short, register struct mbuf *, volatile u_char *, int);
#endif

/*
 * Public data.
 */
int                 eh_irqh_active = FALSE;
int                 virtual = FALSE;

/*
 * External data.
 */
extern int          ehcnt;
extern struct       eh_softc *eh_softc[];
extern volatile int pre_init, pre_reset;

/*
 * Local data.
 */
static int          eh_tx_active = FALSE;
static char         eh_lastlog[80] = { 0 };

/*
 * DEBUG info.
 */
#ifdef DEBUG_ERR
int     store[128];
int     store_ind = 0;
#endif

#ifdef DEBUG
int     db_irq_handl = 0,
        db_irqs = 0;
#endif


int eh_dciversion(_kernel_swi_regs *r)
{
#ifdef TRACE_ROUTINES
    printf("debug: SWI DCIVersion entered\n");
#endif
    r->r[1] = DCIVERSION;
    return (0);
} /* eh_dciversion */


int eh_inquire(_kernel_swi_regs *r)
{
    int unit, error;
#ifdef TRACE_ROUTINES
    printf("debug: SWI Inquire entered, returning:%x\n", INQUIRE_FLAGS);
#endif

    unit = r->r[1];
    /* check its for us */
    if (unit < 0 || unit >= ehcnt)
    {
        SETDCI4ERRNO(error, ENXIO);
        return (error);
    }

    /* OSS 4.51 20 Nov 2002 Sort out flags to be correct for both virtual
       (no multicast filtering) and the second virtual interface. This
       code is the same as in eh_init_low() where it goes in the dib. */
    r->r[2] = INQUIRE_FLAGS;
    if (virtual)
    {
        r->r[2] &= ~INQ_FILTERMCAST;
        if (unit > 0)
        {
            r->r[2] |= INQ_VIRTUAL | INQ_SWVIRTUAL;
        }
    }

    return(0);
} /* eh_inquire() */


int eh_getnetworkmtu(_kernel_swi_regs *r)
{
#ifdef TRACE_ROUTINES
    printf("debug: SWI GetNetworkMTU entered, returning:%d\n", ETHERMTU);
#endif
    r->r[2] = ETHERMTU;
    return (0);
} /* eh_getnetworkmtu() */


int eh_setnetworkmtu(_kernel_swi_regs *r)
{
    int error;

#ifdef TRACE_ROUTINES
    printf("debug: SWI SetNetworkMTU entered\n");
#endif
    UNUSED(r);
    SETDCI4ERRNO(error, ENOTTY);

    return (error);
} /* eh_setnetworkmtu() */


/*
 *
 */

int eh_transmit(_kernel_swi_regs *r)
{
    register struct mbuf *m, *m0;
    int error, flags;

    flags = r->r[0];
    m = (struct mbuf *)(r->r[3]);
    error = eh_tx_main(r);
    /*
     * Free mbuf list if we have ownership of it
     */
    if (!(flags & TX_PROTOSDATA))
    {
        for ( ; m; m = m0)
        {
            m0 = m->m_list;
#ifdef DEBUGTX
            printf("debug: free mbuf chain:%x m0:%x\n",(int) m, (int) m0);
#endif
            m_freem(m);
        }
    }

    return(error);
} /* eh_transmit */


static int eh_tx_main(_kernel_swi_regs *r)
{
    register struct eh_softc *en;
    register struct mbuf *m;
    int flags, type, error = 0, unit;
    u_char *dstadd, *srcadd;

#ifdef BORDER
    set_border(2);
#endif

#ifdef DEBUGTX
    printf("debug: eh_tx_main entered\n");
#endif

    unit = r->r[1];

    /*
     * Check that its for us.
     */
    if (unit < 0 || unit >= ehcnt)
    {
        SETDCI4ERRNO(error, ENXIO);
        return (error);
    }

    /* always use first physical unit for tx but use real unit number for source address etc.. */
    if (virtual)
       en = eh_softc[0];
    else
       en = eh_softc[unit];

#ifdef DEBUGTX
    printf("tx on unit:%d dma_busy:%x cntrl_reg:%x\n",unit, en->eh_dma_busy, (int) en->cntrl_reg);
#endif

    /* if this interface is marked as faulty then try again in case
     * it was a cable problem ie: not connected
     */
    if (en->eh_flags & EH_RECOVERABLE_ERROR)
    {
        if (eh_bringup(en->eh_unit) != 0)
        {
            en->eh_oerrors++;
            SETDCI4ERRNO(error, EIO);
            return(error);
        }
    }

#ifdef DEBUGTX
    printf("debug: eh_tx_main check flags\n");
#endif

    if (!(en->eh_flags & EH_RUNNING))
    {
        sprintf(eh_lastlog, "eh_tx_main: tx blocked, nic not running (unit %d)\n", unit);
        return(INETERR_TXBLOCKED);
    }

    if (eh_tx_active == TRUE)
    {
        sprintf(eh_lasterr, "eh_tx_main: tx blocked, transmit re-entry (unit %d)", unit);
        return(INETERR_TXBLOCKED);
    }

    if (eh_irqh_active == TRUE)
    {
        sprintf(eh_lasterr, "eh_tx_main: tx blocked, irq in progress (unit %d)", unit);
        return(INETERR_TXBLOCKED);
    }

    if (en->eh_dma_busy == TRUE)
    {
        sprintf(eh_lasterr, "eh_tx_main: tx blocked, local dma in use (unit %d)", unit);
        return(INETERR_TXBLOCKED);
    }

#ifdef DEBUG
    printf("debug: eh_tx_main disable card ints\n");
#endif

    /* disable all ints from the NIC since we can't service an
     * rx during a tx
     */
    eh_disint(en);

    /* set flag to indicate we are doing a transmit from this device */
    eh_tx_active = TRUE;

    flags = r->r[0];
    type = r->r[2];
    m = (struct mbuf *)(r->r[3]);
    dstadd = (u_char *)(r->r[4]);

    if (flags & TX_FAKESOURCE)
        srcadd = (u_char *) (r->r[5]);
    else
        srcadd = (u_char *) eh_softc[unit]->eh_addr;

#ifdef DEBUGTX
    printf("debug: SWI Transmit entered, unit:%d dstadd:%s\n", unit, eh_sprint_mac(dstadd));
    printf("flags:%d type:%x mbuf chain:%x srcadd:%s pre_init:%x\n",
             flags, type, (int) m, eh_sprint_mac(srcadd), (int) pre_init);
#endif

#ifdef DRIVER16BIT
#ifdef WINBODGE_DCR_1R
    if ((pre_init == TRUE) && (en->eh_cardtype == EH_TYPE_600))
        en->Chip->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2);
#endif
#endif


#ifdef DEBUG
   printf("debug: eh_tx_main call tx_mbufs\n");
#endif

   error = tx_mbufs(en, m, dstadd, srcadd, type, unit);

   if (error)
       en->eh_oerrors++;

   /* what is this bit in aid of?? */
   /* What !!!! You mean it isn't obvious ! Call yourself a programmer !!! */
#ifdef DRIVER16BIT
#ifdef WINBODGE_DCR_1R
    if ((pre_init == TRUE) && (en->eh_cardtype == EH_TYPE_600))
        en->Chip->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2) | LAS;
#endif
#endif

    /* mark this device as free to transmit and enable card interrupts */
    eh_tx_active = FALSE;

    /* re-enable cards interrupts */
    eh_enint(en);

    return (error);

} /* eh_tx_main()      */


/*
 * SWI Filter
 *
 * If nothing is claimed then Normal, Sink and Monitor are allowed
 * If Normal already claimed then Normal and Sink are allowed
 * If Sink then normal is allowed
 * If Monitor then nothing else is allowed to claim
 *
 */

int eh_filter(_kernel_swi_regs *r)
{
    int flags, unit, frame_type, frame_level, i;
    int add_level, err_level, rcr_val, oldstate;
    int error = 0;
    u_int rx_handler;
    u_char *private;
    struct eh_softc *en;
    struct eh_fib *fp;
    NICRef nic;

    unit = r->r[1];
    /* check its for us */
    if (unit < 0 || unit >= ehcnt)
    {
        SETDCI4ERRNO(error, ENXIO);
        return (error);
    }

    flags      = r->r[0];
    frame_type = GET_FRAMETYPE (r->r[2]);
    frame_level= GET_FRAMELEVEL (r->r[2]);
    add_level  = r->r[3];
    err_level  = r->r[4];
    private    = (u_char *) r->r[5];
    rx_handler = r->r[6];

    en = eh_softc[unit];
    nic = en->Chip;

#ifdef DEBUGMULTICAST
    printf("debug filter: flags:%x, unit:%d, frame_type:%x, frame_level:%x\n",
            flags, unit, frame_type, frame_level);
    printf("debug filter: add_level:%d, err_level:%d, private:%x, rx_handler:%x\n",
            add_level, err_level, (int)private, (int)rx_handler);
#endif

    if (mbuf_present == FALSE)
        return(INETERR_NOMM);

    if (flags & FILTER_RELEASE)
    {
        /* protocol module wishes to release a previously claimed frame type */
        return(free_filter(en, frame_type, private));
    }

    /* OSS 4.51 20 Nov 2002 Removed some pointless extra complexity and if
       statements, merged all the tests in the frame level switch. */

    switch(frame_level)
    {
        case FRMLVL_IEEE:
            /* is there any other IEEE claim? */
            /* first make sure it hasn't been claimed already, if it has return error */
            for (fp = en->eh_fib; fp; fp = fp->next_fib)
            {
                if (fp->frame_level == FRMLVL_IEEE)
                    return(INETERR_FILTERGONE);
            }
            /* make sure frame type is 0 */
            if (frame_type != 0)
            {
                SETDCI4ERRNO(error, EINVAL);
                return(error);
            }
            break;

        case FRMLVL_E2MONITOR:
            /* first make sure there are no E2 level claims already, if so return error */
            for (fp = en->eh_fib; fp; fp = fp->next_fib)
            {
                if (fp->frame_level != FRMLVL_IEEE)
                    return(INETERR_FILTERGONE);
            }
            /* make sure frame type is 0 */
            if (frame_type != 0)
            {
                SETDCI4ERRNO(error, EINVAL);
                return(error);
            }
            break;

        case FRMLVL_E2SINK:
            /* first make sure sink hasn't been claimed already, if so return error */
            for (fp = en->eh_fib; fp; fp = fp->next_fib)
            {
                if (fp->frame_level == FRMLVL_E2SINK)
                    return(INETERR_FILTERGONE);
            }
            /* make sure frame type is 0 */
            if (frame_type != 0)
            {
                SETDCI4ERRNO(error, EINVAL);
                return(error);
            }
            break;

        case FRMLVL_E2SPECIFIC:
            /* first make sure this frame type hasn't been claimed already */
            for (fp = en->eh_fib; fp; fp = fp->next_fib)
            {
                if (fp->frame_type == frame_type)
                    return(INETERR_FILTERGONE);
            }
            break;

        default:
            SETDCI4ERRNO(error, EINVAL);
            return(error);
    }


    /* protocol module wishes to register an interest in this frame type,
     * first get some memory for the control structure for eh_fib
     */
#ifdef DEBUGFILTER
    printf("add frame filter to list\n");
#endif

    if ((fp = (struct eh_fib *) malloc(sizeof(struct eh_fib))) == NULL)
    {
        SETDCI4ERRNO(error, ENOMEM);
        return(error);
    }

    memset ((char *) fp, 0, sizeof(struct eh_fib));
    fp->flags       = flags;
    fp->unit        = unit;
    fp->frame_type  = frame_type;
    fp->frame_level = frame_level;
    fp->add_level   = add_level;
    fp->err_level   = err_level;
    fp->private     = private;
    fp->handler     = rx_handler;
    /* OSS 23 June 2001 This isn't needed, the structure has been memset to 0
    for (i = 0; i < MAR_BITS; i++)
      fp->mar_refcount[i] = 0; ***/
    fp->next_fib    = en->eh_fib;

    /* OSS 23 June 2001 Don't need to zero out software multicast filter stats or table
       due to the memset to 0 above */

    /* Removed at v4.06         */
#if 0
    /*
     * if we get here then first check the address level required
     * and setup the controller as required
     * Also check we configure controller to match highest level claim
     * This section needs to be tested!!!!
     */
    if (en->eh_flags & EH_RUNNING)
    {
        /* the controller is already running, stop it first then
         * reconfigure it. This ignores any errors at this stage
         */
         error = enioctl(unit, 1, 0);
    }
#endif

    /* lowest level for rcr */
    rcr_val = RCR_INIT_VALUE;

    /*
     * if virtual interface then we have to receive all packets and decide which ones are
     * really meant for us in software, hardly optimal but it will have to do!
     */
    if (virtual)
       add_level = ADDRLVL_PROMISCUOUS;

    switch (add_level)
    {
        case (ADDRLVL_PROMISCUOUS):
            /* accept broadcast, all multicast and from any physical address
             * multicast address registers are all set to 0x00 in eh_setup()
             */
            rcr_val = RCR_PROMISCUOUS;
            oldstate = ensure_irqs_off();
            nic->command = SEL_PAGE(1, NIC_RUNNING);
            MICRODELAY(NIC_RESET_PERIOD);
            nic->mar0 = nic->mar1 = nic->mar2 = nic->mar3 = 0xff;
            nic->mar4 = nic->mar5 = nic->mar6 = nic->mar7 = 0xff;

            /* OSS 4.51 20 Nov 2002 Added incrementing of reference counts
               for a promiscuous claim */
            for (i = 0; i < MAR_BITS; i++)
            {
               fp->mar_refcount[i]++;
               en->mar_refcount[i]++; /* OSS 23 June 2001 Made en-> and not global */
            }

            /* OSS 23 June 2001 Want all multicasts */
            fp->softmult_disabled = TRUE;

            nic->command = SEL_PAGE(0, NIC_RUNNING);
            restore_irqs(oldstate);
            break;

        case (ADDRLVL_MULTICAST):
            /* accept broadcast and all multicast packets
             * multicast address registers are all set to 0x00 in eh_setup()
             */
            rcr_val = RCR_MULTICAST;

#ifdef DEBUGMULTICAST
            printf("debug: filter flags:%x FILTER_SPECIFIC_MCAST:%x\n",flags,FILTER_SPECIFIC_MCAST);
#endif
            oldstate = ensure_irqs_off();
            nic->command = SEL_PAGE(1, NIC_RUNNING);
            MICRODELAY(NIC_RESET_PERIOD);
            if (flags & FILTER_SPECIFIC_MCAST)
            {
#if 0
              /* OSS 4.51 20 Nov 2002 Used to zero the multicast registers,
                 but that is wrong as there may be another filter already
                 claiming some multicasts and not others eg. Internet
                 already has claims when LanManFS 2.22 loads. To allow
                 the removal of this, had to change initialisation to
                 set registers to 0x00 instead of 0xff but that is better
                 anyway (don't want multicasts if no filters). */
              nic->mar0 = nic->mar1 = nic->mar2 = nic->mar3 = 0x00;
              nic->mar4 = nic->mar5 = nic->mar6 = nic->mar7 = 0x00;
              for (i = 0; i < MAR_BITS; i++)
                 fp->mar_refcount[i] = 0x00;
#endif
            }
            else
            {
              nic->mar0 = nic->mar1 = nic->mar2 = nic->mar3 = 0xff;
              nic->mar4 = nic->mar5 = nic->mar6 = nic->mar7 = 0xff;

              /* OSS 23 June 2001 Added incrementing of reference counts
                 for an all multicasts claim */
              for (i = 0; i < MAR_BITS; i++)
              {
                 fp->mar_refcount[i]++;
                 en->mar_refcount[i]++; /* OSS 23 June 2001 Made en-> and not global */
              }

              /* OSS 23 June 2001 Want all multicasts */
              fp->softmult_disabled = TRUE;
            }
            nic->command = SEL_PAGE(0, NIC_RUNNING);
            restore_irqs(oldstate);

            break;

        case (ADDRLVL_NORMAL):
            /* accept broadcast and any addressed to us */
            rcr_val = RCR_INIT_VALUE;
            break;

        case (ADDRLVL_SPECIFIC):
            /* only accept packets addressed to us
             * no action required, filtered in eh_read
             */
            break;

        default:
            SETDCI4ERRNO(error, EINVAL);
            return(error);

    }

    if (err_level == ERRLVL_ERRORS)
        rcr_val = (rcr_val | SEP);

    /* only reprogram if controller is set at lower level than required
     * sets value for use later during eh_bringup
     * this needs to be checked !!!
     */
    if (rcr_val > en->rcr_status)
    {
        en->rcr_status = rcr_val;

        /* Added this bit in at v4.06
         *
         * If we get here then first check the address level required
         * and setup the controller as required.
         * Also check we configure controller to match highest level claim
         * This section needs to be tested!!!!
         * Only do this if address level changing, i.e. controller RCR changing.
         */
        if (en->eh_flags & EH_RUNNING)
        {
            /*
             * The controller is already running, stop/reset it first then
             * reconfigure it. This ignores any errors at this stage.
             */
             error = enioctl(unit, 1, 0);

             if ((virtual) && (unit != 0))
                error = enioctl(0, 0, 0);
        }

#ifdef DEBUGFILTER
        printf("Mode: %x\n",en->rcr_status);
#endif
    }
    /*
     * store pointer to fib chain
     */
    en->eh_fib = fp;

    /*
     * Try to start this interface.
     * This calls eh_bringup(). This will only do something if the
     * controller is not already running, i.e. EH_RUNNING is not set.
     * Otherwise it returns immediately.
     */
    error = enioctl(unit, 0, 0);

    if ((virtual) && (unit != 0))
      error = enioctl(0, 0, 0);

    /* if error and not recoverable return error number */
    if (error & !(en->eh_flags & EH_RECOVERABLE_ERROR))
        return(error);

#ifdef DEBUGFILTER
    printf("filter all ok\n");
#endif
    return(0);

} /* eh_filter() */


/*
 * Statistics interface
 */
int eh_stats(_kernel_swi_regs *r)
{
    int flags, unit, mode, type, error;
    struct eh_softc *en;
    struct stats *sp;

    unit  = r->r[1];
    /* check its for us */
    if (unit < 0 || unit >= ehcnt)
    {
        SETDCI4ERRNO(error, ENXIO);
        return (error);
    }

    flags  = r->r[0];
    sp     = (struct stats *) r->r[2];
    en     = eh_softc[unit];

    /* OSS 4.52 22 Nov 2002 Always zero out the structure */
    memset(sp, '\0', sizeof(*sp));

    if (flags & 1)
    {
      if (virtual && en->eh_unit > 0)
      {
        /* OSS 4.52 22 Nov 2002 Fill in stats for virtual interface */

        sp->st_link_status = ((en->eh_flags & 0x02) | (~(en->eh_flags & 0x01) & 0x01));
        sp->st_tx_frames = en->eh_opackets;
        sp->st_rx_frames = en->eh_ipackets;
      }
      else
      {
        switch (en->eh_interface)
        {
            case (INTERFACE_10BASET):
              type = ST_TYPE_10BASET;
              break;
            case (INTERFACE_10BASE2):
              type = ST_TYPE_10BASE2;
              break;
            default:
              type = 0;
              break;
        }

        /* return the statistics that we support */
        sp->st_interface_type = type;

        switch(en->rcr_status & 0xfe)
        {
            case (RCR_SPECIFIC):
                mode = ST_STATUS_DIRECT;
                break;
            case (RCR_INIT_VALUE):
                mode = ST_STATUS_BROADCAST;
                break;
            case (RCR_MULTICAST):
                mode = ST_STATUS_MULTICAST;
                break;
            case (RCR_PROMISCUOUS):
                mode = ST_STATUS_PROMISCUOUS;
                break;
            default:
                mode = 0x00;
        }
        sp->st_link_status = (mode | (en->eh_flags & 0x02) | (~(en->eh_flags & 0x01) & 0x01));


#ifdef DEBUG
        printf("debug: link_status:%x mode:%x eh_flags:%x\n",(int) sp->st_link_status,
                mode, en->eh_flags);
#endif
         /* OSS 4.51 20 Nov 2002 E200 and E600 can't return link polarity,
           *EHInfo doesn't print it. Also can't return link polarity for
           any card that is not using the 10baseT interface. */
        if (en->eh_cardtype != EH_TYPE_200 &&
            en->eh_cardtype != EH_TYPE_600 &&
            en->eh_interface == INTERFACE_10BASET &&
            (*(en->cntrl_reg + STAT2_OFFSET) & EH_POL) == 0)
        {
            /* Polarity correct */
            sp->st_link_polarity      = ST_LINK_POLARITY_CORRECT;
        }
        else
        {
            /* Polarity incorrect or we can't read it */
            sp->st_link_polarity      = ST_LINK_POLARITY_INCORRECT;
        }

        /* tx stats */
        sp->st_tx_frames         = en->eh_opackets;
        sp->st_collisions        = en->ncoll;
        sp->st_excess_collisions = en->nxscoll;
        sp->st_tx_general_errors = en->eh_oerrors;

        /* rx stats */
        sp->st_rx_frames              = en->eh_ipackets;
        sp->st_crc_failures           = en->ncrc;
        sp->st_frame_alignment_errors = en->nfae;
        sp->st_dropped_frames         = en->nfrl;
        sp->st_overlong_frames        = en->eh_toobig;
        sp->st_unwanted_frames        = en->eh_reject;
        sp->st_rx_general_errors      = en->eh_ierrors;
      }
    }
    else
    {
      if (virtual && en->eh_unit > 0)
      {
        /* OSS 4.52 22 Nov 2002 Return indication of what virtual
           interface can display. */
        memset(sp, '\0', sizeof(*sp));

        /* Return only active/inactive and OK/not in status */
        sp->st_link_status              = 0x03;

        sp->st_tx_frames                = 0xffffffff;
        sp->st_rx_frames                = 0xffffffff;
      }
      else
      {
        /* return indication of which statistics are gathered */
        memset(sp, '\0', sizeof(*sp));

        sp->st_interface_type     = 0xff;
        sp->st_link_status        = 0xff;

        /* OSS 4.51 20 Nov 2002 E200 and E600 can't return link polarity,
           *EHInfo doesn't print it. Also can't return link polarity for
           any card that is not using the 10baseT interface. */
        if (en->eh_cardtype != EH_TYPE_200 &&
            en->eh_cardtype != EH_TYPE_600 &&
            en->eh_interface == INTERFACE_10BASET)
        {
            sp->st_link_polarity      = 0xff;
        }
        else
        {
            sp->st_link_polarity      = 0x00;
        }

        sp->st_blank1             = 0x00;
        sp->st_link_failures      = 0x00;
        sp->st_network_collisions = 0x00;

        sp->st_collisions         = 0xffffffff;
        sp->st_excess_collisions  = 0xffffffff;
        sp->st_heartbeat_failures = 0x00;
        sp->st_not_listening      = 0x00;
        sp->st_tx_frames          = 0xffffffff;
        sp->st_tx_bytes           = 0x00;
        sp->st_tx_general_errors  = 0xffffffff;
        sp->st_last_dest_addr[0]  = 0x00;
        sp->st_last_dest_addr[1]  = 0x00;
        sp->st_last_dest_addr[2]  = 0x00;
        sp->st_last_dest_addr[3]  = 0x00;
        sp->st_last_dest_addr[4]  = 0x00;
        sp->st_last_dest_addr[5]  = 0x00;
        sp->st_last_dest_addr[6]  = 0x00;
        sp->st_last_dest_addr[7]  = 0x00;

        sp->st_crc_failures           = 0xffffffff;
        sp->st_frame_alignment_errors = 0xffffffff;
        sp->st_dropped_frames         = 0xffffffff;
        sp->st_runt_frames            = 0x00;
        sp->st_overlong_frames        = 0xffffffff;
        sp->st_jabbers                = 0x00;
        sp->st_late_events            = 0x00;
        sp->st_unwanted_frames        = 0xffffffff;
        sp->st_rx_frames              = 0xffffffff;
        sp->st_rx_bytes               = 0x00;
        sp->st_rx_general_errors      = 0xffffffff;
        sp->st_last_src_addr[0]       = 0x00;
        sp->st_last_src_addr[1]       = 0x00;
        sp->st_last_src_addr[2]       = 0x00;
        sp->st_last_src_addr[3]       = 0x00;
        sp->st_last_src_addr[4]       = 0x00;
        sp->st_last_src_addr[5]       = 0x00;
        sp->st_last_src_addr[6]       = 0x00;
        sp->st_last_src_addr[7]       = 0x00;
      }
    }
    return(0);
}

/* claim/release all or specific multicast addresses for reception */

int eh_multicastrequest(_kernel_swi_regs *r)
{
    int flags, unit, frame_type, mar_count, error;
    int oldstate, i;
    u_long crc, index, mar, bit, val;
    u_int rx_handler;
    u_char *private, *multicast_hw, *multicast_log, TxPending;
    struct eh_fib *fp;
    struct eh_softc *en;
    NICRef nic;
    NICRegsRef nicregs;

    /* OSS 23 June 2001 Bottom 23 bits of multicast address, first empty slot in array */
    /* OSS 4.51 20 Nov 2002 Don't use bottom 23 bits any more */

    int first_empty;

    flags          = r->r[0];
    unit           = r->r[1];
    frame_type     = GET_FRAMETYPE (r->r[2]);
    multicast_hw   = (u_char *) r->r[3];
    multicast_log  = (u_char *) r->r[4];
    private        = (u_char *) r->r[5];
    rx_handler     = r->r[6];

    /* check its for us */
    if (unit < 0 || unit >= ehcnt)
    {
        SETDCI4ERRNO(error, ENXIO);
        return (error);
    }

    en = eh_softc[unit];
    nic = en->Chip;
    nicregs = (NICRegsRef)en->Chip;

    fp = find_protocol(en, frame_type);

    if (fp != NULL)
    {
#ifdef DEBUG1
        printf("debug: multicast: flags:%x, unit:%d, frame_type:%x r3:%x addr:%x\n",
                flags, unit, frame_type, r->r[3], (int)en->eh_addr);
        printf("debug: multicast: multicast_hw:%x, multicast_log:%x, private:%x, rx_handler:%x\n",
                (int)multicast_hw, (int)multicast_log, (int)private, (int)rx_handler);
        printf("debug: mac address: %s\n", eh_sprint_mac(r->r[3]));
#endif
        crc = calc_crc(multicast_hw, 6);
        index = (crc >> 26) & 63;
        mar = (index / MAX_MAR) + MAR_OFFSET;
        bit = 1uL << (index % MAX_MAR);
        if ((mar < MAR_OFFSET) || (mar > MAR_OFFSET+MAX_MAR))
        {
            SETDCI4ERRNO(error, ENXIO);
            return(error);
        }

#ifdef DEBUG1
        printf("debug: index:%x mar:%x bit:%x\n",index, mar, bit);
#endif

        /*
         * disable system IRQs
         */
        oldstate = ensure_irqs_off();
        shutdown(en, nic, &TxPending);
        nic->command = SEL_PAGE(1, NIC_RUNNING);
        MICRODELAY(NIC_RESET_PERIOD);

/* OSS 22 Mar 2001 Was val = (nicregs->r[mar] >> 16) & 0xff; */
/* Needs to be char * access to work on E600 NIC as well as podule */
        val = *(u_char *) &nicregs->r[mar];
        if (flags & MULTICAST_ADDR_REL)
        {
            /* release multicast address(s) */
            if (flags & MULTICAST_ALL_ADDR)
            {
               for (i = 0; i < MAR_BITS; i++)
               {
                  /* OSS 4.52 22 Nov 2002 Only read and write the
                     hardware if we have a remembered non zero count
                     to start with. */
                  mar_count = en->mar_refcount[i];

                  en->mar_refcount[i] -= fp->mar_refcount[i]; /* OSS 23 June 2001 Made en-> and not global */
                  fp->mar_refcount[i] = 0;

                  if (mar_count > 0 && en->mar_refcount[i] <= 0) /* OSS 23 June 2001 Made en-> and not global */
                  {
                     mar = (i / MAX_MAR) + MAR_OFFSET;
                     bit = 1uL << (i % MAX_MAR);
/* OSS 22 Mar 2001 Was val = nicregs->r[mar] >> 16; */ /* get current value in mar */
/* Needs to be char * access to work on E600 NIC as well as podule */
                     val = *(u_char *) &nicregs->r[mar];  /* get current value in mar */
                     val = (val & ~bit);             /* clear bit for this filter */
/* OSS 22 Mar 2001 Was nicregs->r[mar] = val << 16; */ /* write back the new value */
/* Needs to be char * access to work on E600 NIC as well as podule */
                     *(u_char *) &nicregs->r[mar] = (u_char)val;  /* write back the new value */
                  }
               }

               /* OSS 23 June 2001 Release all multicast addresses for this filter
                  so just zero out the table */

               memset(fp->softmult, '\0', sizeof(fp->softmult));
               fp->softmult_disabled = FALSE;
            }
            else
            {
               en->mar_refcount[index]--; /* OSS 23 June 2001 Made en-> and not global */
               fp->mar_refcount[index]--;

               /* only need to clear this bit if no other filter has a claim on it */
               if (en->mar_refcount[index] <= 0) /* OSS 23 June 2001 Made en-> and not global */
               {
                 val = (val & ~bit);          /* clear bit */
/* OSS 22 Mar 2001 Was nicregs->r[mar] = val << 16; */ /* write back the new value */
/* Needs to be char * access to work on E600 NIC as well as podule */
                 *(u_char *) &nicregs->r[mar] = (u_char)val; /* write back the new value */
               }

               /* OSS 23 June 2001 Need to decrement the use count of this
                  address in the software table and set the entry to 0 if
                  use count becomes zero.
                  OSS 4.51 20 Nov 2002 Converted software multicast table
                  to structure with full 6 byte mac address. */

               if (!fp->softmult_disabled)
               {
                  for (i = 0; i < SOFTMULT_COUNT; i++)
                  {
                     if (fp->softmult[i].use_count != 0 &&
                         memcmp(multicast_hw, fp->softmult[i].mac, 6) == 0)
                     {
                        /* We've found the array entry for this one */

                        break;
                     }
                  }

                  if (i < SOFTMULT_COUNT)
                  {
                     /* Found the entry so decrement the usage count and if that makes
                        it zero then set the entire entry to 0. */

                     if (--(fp->softmult[i].use_count) == 0)
                     {
                        memset(&fp->softmult[i], '\0', sizeof(fp->softmult[i]));
                     }
                  }
               }
           }

#ifdef DEBUG
           printf("debug: release multicast val=%x\n",val);
#endif
        }
        else
        {
           if (flags & MULTICAST_ALL_ADDR)
           {
              /* OSS 23 June 2001 Use MAR_BITS instead of 64 */

              for (i = 0; i < MAR_BITS; i++)
              {
                 fp->mar_refcount[i]++;
                 en->mar_refcount[i]++; /* OSS 23 June 2001 Made en-> and not global */
              }
              /* claim all multicast addresses */
              nic->mar0 = nic->mar1 = nic->mar2 = nic->mar3 = 0xff;
              nic->mar4 = nic->mar5 = nic->mar6 = nic->mar7 = 0xff;

              /* OSS 23 June 2001 Need all multicast addresses. Might as well zero out the
                 table since it isn't much use */

              memset(fp->softmult, '\0', sizeof(fp->softmult));
              fp->softmult_disabled = TRUE;
           }
           else
           {
              /* request multicast address */
              val = (val | bit);            /* set bit */
/* OSS 22 Mar 2001 Was nicregs->r[mar] = val << 16; */ /* write new value to MAR */
/* Needs to be char * access to work on E600 NIC as well as podule */
              *(u_char *) &nicregs->r[mar] = (u_char)val;  /* write new value to MAR */
              fp->mar_refcount[index]++;
              en->mar_refcount[index]++; /* OSS 23 June 2001 Made en-> and not global */

              /* OSS 23 June 2001 Need to add this one to the software
                 multicast table if there is room.
                 OSS 4.51 20 Nov 2002 Converted software multicast table
                 to structure with full 6 byte mac address. */

              if (!fp->softmult_disabled)
              {
                 for (i = 0, first_empty = -1; i < SOFTMULT_COUNT; i++)
                 {
                    if (fp->softmult[i].use_count == 0)
                    {
                       /* If we've found the first empty one remember it */

                       if (first_empty == -1)
                       {
                         first_empty = i;
                       }
                    }
                    else if (memcmp(multicast_hw, fp->softmult[i].mac, 6) == 0)
                    {
                       /* We've found the array entry for this one */

                       break;
                    }
                 }

                 if (i < SOFTMULT_COUNT)
                 {
                    /* Found an existing entry so increment the usage count */

                    fp->softmult[i].use_count++;
                 }
                 else if (first_empty != -1)
                 {
                    /* Put it into the first empty slot */

                    fp->softmult[first_empty].use_count = 1;
                    memcpy(fp->softmult[first_empty].mac, multicast_hw, 6);
                 }
                 else
                 {
                    /* Didn't find an existing entry and no empty slot so disable */

                    memset(fp->softmult, '\0', sizeof(fp->softmult));
                    fp->softmult_disabled = TRUE;
                 }
              }
           }

#ifdef DEBUG
           printf("debug: request multicast\n");
#endif
        }
        nic->command = SEL_PAGE(0, NIC_RUNNING);

        startup(en, nic, TxPending);

        restore_irqs(oldstate);

#ifdef DEBUG
        printf("debug: mar0 is at %x and %x index:%x mar_refcount:%x\n",(int)nic->mar3, (int)nicregs->r[mar], index, en->mar_refcount[index]);
        printf("debug: mar0:%x mar1:%x mar2:%x mar3:%x mar4:%x mar5:%x mar6:%x mar7:%x\n",
                nic->mar0,nic->mar1,nic->mar2,nic->mar3,nic->mar4,nic->mar5,nic->mar6,nic->mar7);
        printf("debug: multicast, crc:%x index:%d mar:%d b:%d val:%x\n",crc, index, mar, bit, val);
#endif

    }
    else
    {
        SETDCI4ERRNO(error, ENXIO);
        return (error);
    }

    return(0);
}


/*
 * Remove a frame filter from list
 * Private must match stored value in fib
 * if frame_type is -1 then remove all frame types claimed by this module
 * else remove specific frame type requested
 *
 * Modified by DJB 25/07/95
 *      Fixed bug.
 *
 */

int free_filter (struct eh_softc *en, int frame_type, u_char *private)
{
    int found = 0, val, i, bit, oldstate, mar_count, error;
    u_long mar;
    struct eh_fib *fp, *last, *this_fp;
    u_char TxPending;
    NICRef nic;
    NICRegsRef nicregs;
    _kernel_swi_regs rin, rout;

#ifdef TRACE_ROUTINES1
    printf("Free_filter unit:%x type:%x private:%x\n",en->eh_unit, frame_type, (int) private);
#endif

    nic = en->Chip;
    nicregs = (NICRegsRef)en->Chip;

    last = en->eh_fib;
    fp = last;

    while (fp != NULL)
    {
        if (private == fp->private)
        {
#ifdef TRACE_ROUTINES
            printf("debug: found match:%x\n",(int)private);
#endif
            if ((frame_type == fp->frame_type) || (frame_type == -1))
            {
                found += 1;
                /* issue service call */
                rin.r[0] = (int) en->eh_dib;
                rin.r[1] = Service_DCIFrameTypeFree;
                SET_FRAMETYPE(rin.r[2], fp->frame_type);
                SET_FRAMELEVEL(rin.r[2], fp->frame_level);
                rin.r[3] = fp->add_level;
                rin.r[4] = fp->err_level;
#ifdef DEBUG
                printf("debug: service call DCIFrameTypeFree:%x\n", rin.r[2]);
#endif
                _kernel_swi(XOS_Bit | OS_ServiceCall, &rin, &rout);

                fp->frame_type = NULL;
                fp->private = NULL;

                /* OSS 4.52 22 Nov 2002 Changed single '=' to double equals,
                   means that multicast registers might stand a chance of
                   being set back to 0. */
                if (pre_reset == FALSE)
                {
                   /* OSS 4.52 22 Nov 2002 Moved the disable and restore of
                      IRQs inside the if statement, there's no point doing
                      the disable and then deciding to do nothing after all
                      and immediately restoring IRQs. */
                   oldstate = ensure_irqs_off();
                   shutdown(en, nic, &TxPending);
                   nic->command = SEL_PAGE(1, NIC_RUNNING);
                   MICRODELAY(NIC_RESET_PERIOD);
                   for (i = 0; i < MAR_BITS; i++)
                   {
                      /* OSS 4.52 22 Nov 2002 Only read and write the
                         hardware if we have a remembered non zero count
                         to start with. */
                      mar_count = en->mar_refcount[i];

                      en->mar_refcount[i] -= (fp->mar_refcount[i]); /* OSS 23 June 2001 Made en-> and not global */
                      fp->mar_refcount[i] = 0;

                      if (mar_count > 0 && en->mar_refcount[i] <= 0) /* OSS 23 June 2001 Made en-> and not global */
                      {
                         mar = (i / MAX_MAR) + MAR_OFFSET;
                         bit = 1 << (i % MAX_MAR);
/* OSS 23 June 2001 Was val = nicregs->r[mar] >>16; */  /* get current value in mar */
/* Needs to be char * access to work on E600 NIC as well as podule */
                         val = *(u_char *) &nicregs->r[mar];  /* get current value in mar */
                         val = (val & ~bit);            /* clear bit for this filter */
/* OSS 23 June 2001 Was nicregs->r[mar] = val << 16; */ /* write back the new value */
/* Needs to be char * access to work on E600 NIC as well as podule */
                         *(u_char *) &nicregs->r[mar] = val;  /* write back the new value */
                      }
                   }
                   nic->command = SEL_PAGE(0, NIC_RUNNING);
                   startup(en, nic, TxPending);
                   restore_irqs(oldstate);
                }

                this_fp = fp;
                if (fp == en->eh_fib)
                {
                    fp = fp->next_fib;
                    en->eh_fib = fp;
                    last = fp;
                }
                else
                {
                    last->next_fib = fp->next_fib;
                    fp = fp->next_fib;
                }
                free(this_fp);
            }
            else
            {
                last = fp;
                fp = fp->next_fib;
            }
        }
        else
        {
            last = fp;
            fp = fp->next_fib;
        }
    }

#ifdef TRACE_ROUTINES1
    printf("Free_filter done, found:%d\n",found);
#endif

    if (found)
       return 0;

    SETDCI4ERRNO(error, EPERM);
    return error;

} /* free_filter() */

/*
 * Interrupt handler.
 * returns 1 if couldn't handle interupt else returns 0 if all ok
 */
int eh_irq_handler(_kernel_swi_regs *r, void *pw)
{
    register struct eh_softc *en;
    int i, j, oldstate, claim = 1;

    /*
     * check if irq_handler is being re-entered, this interrupt should
     * get serviced by the previous thread? This should never happen anyway!
     */
    if (eh_irqh_active == TRUE)
    {
        sprintf(eh_lasterr, "eh_irq_handler: reentered during irq");
        return(claim);
    }

    /*
     * check if irq_handler is being called while transmit is in progress
     * This should never happen either!
     */
    if (eh_tx_active == TRUE)
    {
        /* OSS 4.51 20 Nov 2002 With multiple cards this is entirely
           legimate as the IRQ may be for a different card to the one
           that is tx active. So don't flag a bogus error.
           OSS 4.52 21 Nov 2002 Get the test the right way round! */
        if (virtual || ehcnt <= 1)
        {
            sprintf(eh_lasterr, "eh_irq_handler: re-entering irq_handler during tx");
        }
        return(claim);
    }


#ifdef BORDER
        set_border(0);
#endif

    /*
     * Disable card interrupts from all our cards and mark handler as active.
     * We want to make sure we are not re-entered to service another card
     */
    eh_irqh_active = TRUE;

    for (j = 0; j < ehcnt; j++)
       eh_disint(eh_softc[j]);

    /*
     * Enable system IRQs
     */
    oldstate = ensure_irqs_on();

    if (virtual)
    {
       /* there can only be one physical interface in this mode, and it is always unit 0 */
       eh_intr(eh_softc[0]);
    }
    else
    {
       /* now check and service interrupts on all the cards we know about */
       for (i = 0; i < ehcnt; i++)
       {

           en = eh_softc[i];
           /*
            * Handle our interrupt.
            */
           eh_intr(en);
       }
    }

    /*
     * Restore system IRQs
     */
    restore_irqs(oldstate);

    /* now re-enable interrupts from all our cards */
    for (j = 0; j < ehcnt; j++)
       eh_enint(eh_softc[j]);

    eh_irqh_active = FALSE;

#ifdef BORDER
    set_border(3);
#endif

    UNUSED(pw);
    UNUSED(r);
    
    return (claim);

} /* eh_irq_handler()           */

void eh_final(void *pw)
{
    _kernel_swi_regs rin, rout;
    struct eh_softc *en;
    int i, s;

#ifdef TRACE_ROUTINES1
    printf("debug: eh_final, closing mbuf session\n");
    fflush(stdout);
#endif

    /*
     * Disable interrupts.
     */
    s = ensure_irqs_off();

    for (i = 0; i < ehcnt; i++)
    {
        en = eh_softc[i];
#ifdef DMA
        /* shutdown dma */
        dma_deregister(en);
#endif
        eh_reset_card(en);
        en->eh_flags &= ~EH_RUNNING;
        rin.r[0] = (int) en->eh_dib;
        rin.r[1] = Service_DCIDriverStatus;
        rin.r[2] = DCIDRIVER_DYING;
        rin.r[3] = DCIVERSION;
        _kernel_swi(XOS_Bit | OS_ServiceCall, &rin, &rout);

        rin.r[0] = en->eh_deviceno;
        rin.r[1] = (int) eh_irq_entry;
        rin.r[2] = (int) pw;
        rin.r[3] = (int) en->cntrl_reg;
        rin.r[4] = (int) EH_INTR_STAT;
        _kernel_swi(XOS_Bit | OS_ReleaseDeviceVector, &rin, &rout);
    }

    /* close mbuf manager session, ignore any errors, this assumes we have opened a session! */
    mb_closesession();

    restore_irqs(s);

} /* eh_final()         */

/*
 * Print out EHINFO information.
 * OSS 4.51 21 Nov 2002 General cleanup of the formatting
 */
void eh_statshow(void)
{
    struct eh_softc *en;
    struct eh_fib *fp;
    NICRef nic;
    NICRegsRef nicregs;
    int    ehi, val, oldstate, type;
    u_long mc;
    char   temp[64], number[12];
    char   formatter[16];

    /* Print the heading and formulate a width formatter to make things line up */
    printf("%s\n", eh_message(M6_STAT_HEADING, NULL, NULL, NULL));
    sprintf(formatter, "%%-%ds: %%s\n", strlen(eh_message(M7_STAT_MEASURE, NULL, NULL, NULL)));

    for (ehi = 0; ehi < ehcnt; ehi++)
    {
        printf("\neh%d:\n\n", ehi);

        en = eh_softc[ehi];
        nic = en->Chip;
        nicregs = (NICRegsRef)en->Chip;

#ifdef DEBUG
        if (en->eh_cardtype == EH_TYPE_600)
        {
           if (((nic->mcrb) & 0x20) == 0x20)
              printf("debug: AT/LANTIC bus error!!!\n");
           else
              printf("debug: mcrb = %x\n", nic->mcrb);
        }
#endif

        /* Driver, unit, location and EUI */
#ifdef DRIVER16BIT
        printf(formatter, eh_message(M15_STAT_DRIVER, NULL, NULL, NULL), "eh16");
#else
        printf(formatter, eh_message(M15_STAT_DRIVER, NULL, NULL, NULL), "eh8");
#endif
        sprintf(number, "%d", ehi);
        printf(formatter, eh_message(M14_STAT_UNIT, NULL, NULL, NULL), number);
        printf(formatter, eh_message(M8_STAT_LOCATION, NULL, NULL, NULL), en->eh_location);
        sprintf(temp, "%02X:%02X:%02X:%02X:%02X:%02X",
                en->eh_addr[0], en->eh_addr[1], en->eh_addr[2],
                en->eh_addr[3], en->eh_addr[4], en->eh_addr[5]);
        printf(formatter, eh_message(M9_STAT_EUI48, NULL, NULL, NULL), temp);

        /* Go no further if faulty */
        if ((en->eh_flags & EH_FAULTY) && (!en->eh_flags & EH_RECOVERABLE_ERROR))
        {
            strcpy(temp, eh_message(M12_TYPE_FAULTY, NULL, NULL, NULL));
            printf(formatter, eh_message(M10_STAT_CONTROLLER, NULL, NULL, NULL), temp);
            continue;
        }
        
        /* OSS 4.52 22 Nov 2002 More changes as to what we print for a
           virtual interface. Don't print the card type, print virtual
           instead. */
        if (virtual && en->eh_unit > 0)
        {
            strcpy(temp, eh_message(M11_TYPE_VIRTUAL, NULL, NULL, NULL));
        }
        else
        {
            type = 0;
            switch(en->eh_cardtype)
            {
#ifdef DRIVER8BIT
                case EH_TYPE_100:
                    type = 100;
                    break;

               case EH_TYPE_200:
                    type = 200;
                    break;
#endif
#ifdef DRIVER16BIT
                case EH_TYPE_500:
                    type = 500;
                    break;

                case EH_TYPE_600:
                    type = 600;
                    break;

                case EH_TYPE_700:
                    type = 700;
                    break;
#endif
            }
            sprintf(number, "%d", type);
            sprintf(temp, eh_message(M13_TYPE_ETHERLAN, number, NULL, NULL));
        } /* end if (virtual && en->eh_unit > 0) else */
        printf(formatter, eh_message(M10_STAT_CONTROLLER, NULL, NULL, NULL), temp);

        printf(formatter, eh_message(M17_STAT_AUTHOR, NULL, NULL, NULL), "© Design IT, 2002");

        /* OSS 4.52 22 Nov 2002 Restrict radically what we print about
           a virtual interface. It has no hardware so link status is
           silly along with all sorts of other data. */
        if (virtual && en->eh_unit > 0)
        {
            sprintf(number, "%u", en->eh_ipackets);
            printf(formatter, eh_message(M19_PACKET_RECEIVED, NULL, NULL, NULL), number); 
            sprintf(number, "%u", en->eh_opackets);
            printf(formatter, eh_message(M18_PACKET_SENT, NULL, NULL, NULL), number);
        }
        else
        {
#ifdef SMALL_RAM
            sprintf(number, "%dkB", NIC_BUFFER/1024);
            printf(formatter, eh_message(M20_STAT_BUFFER, NULL, NULL, NULL), number);
#endif
#ifdef DRIVER8BIT
            if (en->eh_cardtype == EH_TYPE_200)
            {
               switch(en->eh_interface)
               {
                  case INTERFACE_NONE:
                     strcpy(temp, eh_message(M21_MAU_NONE, NULL, NULL, NULL));
                     break;

                  case INTERFACE_10BASET:
                     strcpy(temp, eh_message(M22_MAU_10BT, NULL, NULL, NULL));
                     break;

                  case INTERFACE_10BASE2:
                     strcpy(temp, eh_message(M23_MAU_10B2, NULL, NULL, NULL));
                     break;

                  case INTERFACE_MICRO_2:
                     strcpy(temp, eh_message(M24_MAU_MICRO_10BT, NULL, NULL, NULL));
                     break;

                  case INTERFACE_MICRO_T:
                     strcpy(temp, eh_message(M25_MAU_MICRO_10B2, NULL, NULL, NULL));
                     break;

                  case INTERFACE_UNKNOWN:
                  default:
                     sprintf(number, "%d", en->eh_interface);
                     strcpy(temp, eh_message(M26_MAU_UK, number, NULL, NULL));
                     break;
               }
            }
            else
#endif
            {
               switch(en->eh_interface)
               {
                  case INTERFACE_10BASET:
                     strcpy(temp, eh_message(M27_MAU_INTEGRATED_10BT, NULL, NULL, NULL));
                     break;

                  case INTERFACE_10BASE2:
                     strcpy(temp, eh_message(M28_MAU_INTEGRATED_10B2, NULL, NULL, NULL));
                     break;

                  default:
                     sprintf(number, "%d", en->eh_interface);
                     strcpy(temp, eh_message(M29_MAU_INTEGRATED_UK, number, NULL, NULL));
                     break;
               }
            }
            printf(formatter, eh_message(M16_STAT_MEDIA, NULL, NULL, NULL), temp); 

            /* OSS 4.52 22 Nov 2002 Virtual RX and TX stats moved higher
               up into a larger if clause */
            sprintf(number, "%u", en->eh_ipackets);
            printf(formatter, eh_message(M19_PACKET_RECEIVED, NULL, NULL, NULL), number); 
            sprintf(number, "%u", en->eh_ierrors);
            printf(formatter, eh_message(M31_IO_RECEIVE_ERR, NULL, NULL, NULL), number); 
            if (en->eh_ierrors)
            {
                sprintf(temp, "fae=%u, crc=%u, frl=%u, ovrn=%u",
                        en->nfae, en->ncrc, en->nfrl, en->novrn);
                printf(formatter, "", temp);
            }

            sprintf(number, "%u", en->eh_opackets);
            printf(formatter, eh_message(M18_PACKET_SENT, NULL, NULL, NULL), number);
            sprintf(number, "%u", en->eh_oerrors);
            printf(formatter, eh_message(M30_IO_SEND_ERR, NULL, NULL, NULL), number);
            if (en->eh_oerrors)
            {
                sprintf(temp, "nxscoll=%u, nundrn=%u, nmaxp=%u, nnotx=%u, nrdc=%u",
                        en->nxscoll, en->nundrn, en->nmaxp, en->nnotx, en->nrdc);
                printf(formatter, "", temp);
            }

            /* Supress zero values of these guru level internal counters */
            if (en->eh_collisions)
            {
                sprintf(number, "%u", en->eh_collisions);
                printf(formatter, eh_message(M32_IO_COLLISIONS, NULL, NULL, NULL), number);
            }
            if (en->eh_reject)
            {
                sprintf(number, "%u", en->eh_reject);
                printf(formatter, eh_message(M33_IO_REJECTS, NULL, NULL, NULL), number);
            }
            if (en->eh_nombuf)
            {
                sprintf(number, "%u", en->eh_nombuf);
                printf(formatter, eh_message(M34_IO_NOMBUFS, NULL, NULL, NULL), number);
            }
            if (en->eh_ovw)
            {
                sprintf(number, "%u", en->eh_ovw);
                printf(formatter, eh_message(M37_IO_OVERWRITES, NULL, NULL, NULL), number);
            }
#ifdef DMA
            sprintf(number, "%u", en->eh_dmapackets);
            printf(formatter, eh_message(M35_DMA_AVAILABLE, NULL, NULL, NULL), number);
            sprintf(number, "%u", en->eh_nodma);
            printf(formatter, eh_message(M36_DMA_UNAVAILABLE, NULL, NULL, NULL), number);
#endif

            /* OSS 4.52 22 Nov 2002 There is no point printing the interface
               type for a virtual interface since it is the same as the
               primary (and might give the false impression that there
               is some hardware here). */

            if (en->eh_interface == INTERFACE_10BASET
                && en->eh_cardtype != EH_TYPE_200)
            {
                if (get_goodlink(en) == TRUE)
                {
                    strcpy(temp, eh_message(M38_LINK_GOOD, NULL, NULL, NULL));
                }
                else
                {
                    strcpy(temp, eh_message(M39_LINK_BAD, NULL, NULL, NULL));
                }

                if (en->eh_cardtype != EH_TYPE_600)
                {
                   if ((*(en->cntrl_reg + STAT2_OFFSET) & EH_POL) == 0)
                      strcat(temp, eh_message(M40_POLARITY_CORRECT, NULL, NULL, NULL));
                   else
                      strcat(temp, eh_message(M41_POLARITY_INCORRECT, NULL, NULL, NULL));
                }
                printf(formatter, eh_message(M42_STAT_LINK, NULL, NULL, NULL), temp);
            }

            /* Only print multicast address registers for the primary unit since that's the one
               that has real hardware associated. Also, even with no frame
               filters the controller has multicast address registers. */
            temp[0] = 0;
            for (mc = MAR_OFFSET; mc < MAX_MAR+MAR_OFFSET; mc++)
            {
              oldstate = ensure_irqs_off();
              nic->command = SEL_PAGE(1, NIC_RUNNING);
              MICRODELAY(NIC_RESET_PERIOD);
              val = *(u_char *) &nicregs->r[mc];
              nic->command = SEL_PAGE(0, NIC_RUNNING);
              restore_irqs(oldstate);

              sprintf(number, "%02X:", val);
              strcat(temp, number);
            }
            temp[(3 * MAX_MAR) - 1] = 0; /* No trailing colon */
            printf(formatter, eh_message(M48_MCAST_REGS, NULL, NULL, NULL), temp);
            
            /* OSS 4.52 22 Nov 2002 Don't print the controller mode for
               virtual interface, it doesn't make any sense since it isn't
               the real hardware. Any information is a lie. */
            switch ((en->rcr_status & 0xfe))
            {
                case RCR_INIT_VALUE:
                    strcpy(temp, eh_message(M50_MODE_NORMAL, NULL, NULL, NULL));
                    break;

                case RCR_MULTICAST:
                    strcpy(temp, eh_message(M51_MODE_MULTICAST, NULL, NULL, NULL));
                    break;

                case RCR_PROMISCUOUS:
                    strcpy(temp, eh_message(M52_MODE_PROMISCUOUS, NULL, NULL, NULL));
                    break;

                default:
                    strcpy(temp, eh_message(M53_MODE_UNKNOWN, NULL, NULL, NULL));
                    break;
            }

            if (en->rcr_status & SEP)
                strcat(temp, eh_message(M54_MODE_WITH_ERRORS, NULL, NULL, NULL));
            else
                strcat(temp, eh_message(M55_MODE_WITHOUT_ERRORS, NULL, NULL, NULL));

            printf(formatter, eh_message(M49_MODE_HEADER, NULL, NULL, NULL), temp);

        } /* end if (virtual && en->eh_unit > 0) else */

        /* And now the registered filter clients */
        fp = en->eh_fib;
        if (fp != NULL)
        {
            printf("\n%s\n\n", eh_message(M43_FRAME_CLIENTS, NULL, NULL, NULL));
            for ( ; fp; fp = fp->next_fib)
            {
                if (fp->frame_type == 0)
                   sprintf(temp, "IEEE (AddrLvl %02d, ErrLvl %02d)", fp->add_level, fp->err_level);
                else
                   sprintf(temp, "%04X (AddrLvl %02d, ErrLvl %02d)", fp->frame_type, fp->add_level, fp->err_level);

                printf("%s=(%p/%p)\n", eh_message(M44_FRAME_TYPE, temp, NULL, NULL),
                                       (int)fp->handler, (int)fp->private);

                /* OSS 23 June 2001 Print out the software discard table */
                /* OSS 4.51 20 Nov 2002 Only if we're at multicast address level or higher. */

                if (fp->add_level >= ADDRLVL_MULTICAST)
                {
                    if (fp->softmult_disabled)
                    {
                        printf("%s\n", eh_message(M45_MCAST_NOT_ENABLED, NULL, NULL, NULL));
                    }
                    else
                    {
                        int i;

                        for (i = 0; i < SOFTMULT_COUNT; i++)
                        {
                            if (fp->softmult[i].use_count != 0)
                            {
                                /* We've found an array entry */
                                /* OSS 4.51 20 Nov 2002 Change to new 48 bit entries */

                                sprintf(temp, "%02X:%02X:%02X:%02X:%02X:%02X",
                                        fp->softmult[i].mac[0], fp->softmult[i].mac[1],
                                        fp->softmult[i].mac[2], fp->softmult[i].mac[3],
                                        fp->softmult[i].mac[4], fp->softmult[i].mac[5]);
                                sprintf(number, "%u", fp->softmult[i].use_count);
                                printf("%s\n", eh_message(M46_MCAST_NON_ZERO, temp, number, NULL));
                            }
                        }
                        sprintf(temp, "%u", fp->softmult_discards);
                        sprintf(number, "%u", fp->softmult_allowed);  
                        printf("%s\n", eh_message(M47_MCAST_SUMMARY, temp, number, NULL));
                    }
                }
            } /* end loop over frame filters */

        } /* end if (fp == NULL) */

    }/* end loop over all units */

    val = 0;
#ifdef DRIVER16BIT
    if ((pre_init == TRUE) && (eh_softc[0]->eh_cardtype == EH_TYPE_600))
    {
        if (!val) putchar(10);
        strcpy(temp, eh_message(M57_DRIVER_NOT_INIT, NULL, NULL, NULL));
        val = printf("%s %s\n", eh_message(M56_DRIVER_WARNING, NULL, NULL, NULL), temp);
    }
#endif

    if (mbuf_present == FALSE)
    {
        if (!val) putchar(10);
        strcpy(temp, eh_message(M58_DRIVER_NO_MBM, NULL, NULL, NULL));
        val = printf("%s %s\n", eh_message(M56_DRIVER_WARNING, NULL, NULL, NULL), temp);
    }

    if (eh_lastlog[0])
    {
        if (!val) putchar(10);
        val = printf("%s %s\n", eh_message(M59_DRIVER_LAST_LOG, NULL, NULL, NULL), eh_lastlog);
        eh_lastlog[0] = 0;
    }

    if (eh_lasterr[0])
    {
        if (!val) putchar(10);
        val = printf("%s %s\n", eh_message(M60_DRIVER_LAST_ERR, NULL, NULL, NULL), eh_lasterr);
        eh_lasterr[0] = 0;
    }

} /* eh_statshow() */

/*
 * run diagnostic tests on all cards
 */
void eh_ehtest(void)
{
    int i;
    struct eh_softc *en;

    printf("%s\n", eh_message(M4_DIAG_START, NULL, NULL, NULL));
    for (i = 0; i < ehcnt; i++)
    {
        /* if virtual then only test unit 0 */
        if (virtual && (i == 0))
        {
           en = eh_softc[i];
           enioctl(i, 1, 0);
           eh_post(en, 0);
           enioctl(i, 0, 0);
        }
    }
    printf("%s\n", eh_message(M5_DIAG_FINISH, NULL, NULL, NULL));
    eh_statshow();
}

_kernel_oserror *eh_cmos_virtual(const char *arg_string, int arg_count)
{
   int n, i;
   _kernel_swi_regs rin, rout;
   struct eh_softc *en;
   char s[0x100];

   UNUSED(arg_count);
   
#ifdef DEBUGC
   printf("&arg_string %x arg_string %x\n",
          (int) &arg_string, (int) arg_string);
#endif

   /* use the unit's cmos allocation to store if virtual is on or off */
   en = eh_softc[0];
   /* OSS 16 June 2001 Added byte number to eh_readcmos function */
   n = eh_readcmos(en, 1);

   /* Deal with *CONFIGURE, and *STATUS EHVirtual */
   if (arg_string == arg_CONFIGURE_SYNTAX)
   {
      printf("EHVirtual  On|Off\n");
      return NULL;
   }
   if (arg_string == arg_STATUS)
   {
      printf("EHVirtual  ");
      if (n & 0x01)
         printf("On\n");
      else
         printf("Off\n");
      return NULL;
   }

   /* Set operation */

   /* OSS v4.47 12 Nov 2002 Command lines are control character
       terminated. The old code used to assume zero terminated
       which is why it sometimes crashed. Also add a limit on
       size of buffer. */
   for (i = 0;
        i < (sizeof(s) - 1) && arg_string[i] >= ' ';
        i++)
   {
       s[i] = toupper(arg_string[i]);
   }
   s[i] = '\0';

   if (strstr(s, "ON") != NULL)
       n = (n | 0x01);
   else if (strstr(s, "OFF") != NULL)
       n = (n & 0xfe);
   else
       return configure_BAD_OPTION;

   rin.r[0] = OsByte_WriteCMOS;
   rin.r[1] = en->eh_cmosbase + 1;
   rin.r[2] = n;
   return _kernel_swi(XOS_Bit | OS_Byte, &rin, &rout);
}


#ifdef DRIVER16BIT
/* OSS 16 June 2001 Added *Configure EHConnection for E600 cards. We use cmose byte 2
   out of the 0..3 allocated per podule - byte 0 is for the frame buffer count of a bridge
   card (obsolete and source may not even compile) and byte 1 is used for EHVirtual. */

_kernel_oserror *eh_cmos_connection(const char *arg_string, int arg_count)
{
   int n, i;
   _kernel_swi_regs regs;
   struct eh_softc *en;
   char s[0x100];

   UNUSED(arg_count);

#ifdef DEBUGC
   printf("&arg_string %x arg_string %x\n",
          (int) &arg_string, (int) arg_string);
#endif

   /* Find whether we have an E600 interface or not */
   en = NULL;
   for (i = 0; i < ehcnt; i++)
   {
      if (eh_softc[i]->eh_cardtype == EH_TYPE_600)
      {
         en = eh_softc[i];
         break;
      }
   }

   /* Get out early for both *status and *configure if there isn't an E600 card */
   if (en == NULL)
   {
      return NULL;
   }


   /* All the other cmos stuff uses the cmos bytes in the first card, but since
      this only applies to E600 cards and there can be only one of those fitted
      we might as well use the cmos bytes of the card it applies to */
   n = eh_readcmos(en, 2);

   /* Deal with *CONFIGURE, and *STATUS EHVirtual */
   if (arg_string == arg_CONFIGURE_SYNTAX)
   {
      printf("EHConnection Auto|10BaseT|10Base2\n");
      return NULL;
   }
   if (arg_string == arg_STATUS)
   {
      printf("EHConnection ");
      if (n == 'T')
         printf("10BaseT\n");
      else if (n == '2')
         printf("10Base2\n");
      else
         printf("Auto\n");
      return NULL;
   }

   /* Set operation */

   /* OSS v4.47 12 Nov 2002 Command lines are control character
      terminated. The old code used to assume zero terminated
      which is why it sometimes crashed. Also add a limit on
      size of buffer. */
   for (i = 0;
        i < (sizeof(s) - 1) && arg_string[i] >= ' ';
        i++)
   {
       s[i] = toupper(arg_string[i]);
   }
   s[i] = '\0';
 
   if (strstr(s, "10BASET"))
       n = 'T';
   else if (strstr(s, "10BASE2"))
       n = '2';
   else if (strstr(s, "AUTO"))
       n = 0;
   else
       return configure_BAD_OPTION;
 
   regs.r[0] = OsByte_WriteCMOS;
   regs.r[1] = en->eh_cmosbase + 2;
   regs.r[2] = n;
   return _kernel_swi(XOS_Bit | OS_Byte, &regs, &regs);
}
#endif /* DRIVER16BIT */

/* OSS 16 June 2001 New version of eh_readcmos that takes a byte offset 0..3
   for which of the podule's 4 bytes to read from */
int eh_readcmos(struct eh_softc *en, int byte)
{
   _kernel_swi_regs rin, rout;

   rin.r[0] = OsByte_ReadCMOS;
   rin.r[1] = en->eh_cmosbase + byte;
   _kernel_swi(XOS_Bit | OS_Byte, &rin, &rout);

   return(rout.r[2]);
}


/*
 * Read device and dispose of data.
 */

void nulldev(u_char c)
{
   u_char x;
   x = c;
} /* nulldev()          */


/*
 * eh_bringup - bring the card up live onto the network - returns 0
 * if all OK, else errno.
 */

static int eh_bringup(int unit)
{
    register struct eh_softc *en = eh_softc[unit];
    NICRef      nic = en->Chip;

    /* do not do this if already running */
    if (en->eh_flags & EH_RUNNING)
    {
#ifdef DEBUG
        printf("debug: already running\n");
#endif
        return(0);
    }

    /*
     * check to see that card passed diagnostic tests
     */
    if (en->eh_flags & EH_RECOVERABLE_ERROR)
    {
        /* POST detected no network - try again */
        /* if (!eh_post(en, 1)) */
            /*
             * do not bring this network up - unit is either
             * faulty or still has a recoverable error
             */
            return((en->eh_flags & EH_FAULTY) ? ENETDOWN : ETIMEDOUT);
    }

    /* if (!eh_setup(unit, LIVE)) return (ENETDOWN);        Unit is faulty.      */

    eh_disint(en);

    /*
     * Set the NIC running, take it out of loopback mode.
     */
    nic->command = SEL_PAGE(0, NIC_RUNNING);
    nic->tcr = TCR_INIT_VALUE | LOOP_MODE(LIVE_NET);

    /* setup receive configuration register */
#ifdef DEBUG
    printf("debug: set up rcr:%x\n",en->rcr_status);
#endif
    nic->rcr = en->rcr_status;
    nic->isr = 0xff;
    nic->imr = en->eh_imr_value;

    /* Mark this interface as active.   */
    en->eh_flags |= EH_RUNNING;

    /* Make sure DCR is correct.        */
#ifdef DRIVER16BIT
#ifdef WINBODGEDCR2
    if ((pre_init == FALSE) && (en->eh_cardtype == EH_TYPE_600))
    {
#ifdef DEBUG
        printf("debug: make sure dcr is correct in bringup\n");
#endif
        nic->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2);
    }
#endif
#endif

    /* Enable interrupts from hardware.     */
    eh_enint(en);

#ifdef DEBUG
    printf("debug: eh_bringup all ok\n");
#endif

    /* All done.                        */
    return(0);

} /* eh_bringup()                       */

/*
 *
 */
int enioctl(int unit, int cmd, int flag)
{
    register struct eh_softc *en;
    int error = 0;

    if (unit < 0 || unit >= ehcnt)
    {
        SETDCI4ERRNO(error, ENXIO);
        return (error);
    }
    en = eh_softc[unit];

#ifdef DEBUG
    printf("enioctl cmd:%x flag:%x\n",cmd, flag);
#endif

    switch(cmd)
    {
      case 0:
#ifdef DEBUG
        printf("enioctl call bringup unit:%x\n",unit);
#endif
        error = eh_bringup(unit);
        if (error != 0)
           sprintf(eh_lastlog, "enioctl: bringup fail error %d (unit %d)", error, unit);
        break;

      case 1:
        eh_disint(en);

        /*
         * log a message on next CD/Heartbeat error
         */
        en->eh_flags &= ~EH_SQEINFORMED;
        en->eh_flags |= EH_SQETEST;

        if ((en->eh_flags & EH_FAULTY))
        {
            eh_reset_card(en);
            break;
        }

        if (flag == 0 && (en->eh_flags & EH_RUNNING))
        {
            /* take the card down */
            eh_reset_card(en);
            en->eh_flags &= ~EH_RUNNING;
        }
        else if (flag && !(en->eh_flags & EH_RUNNING))
            error = eh_bringup(unit);

        eh_enint(en);
        break;

      default:
        break;
    }

    /* that's all */
    return(error);

} /* enioctl()          */


/*
 * tx_mbufs - copy packet out of mbuf chain into Tx buffer, and queue
 * the transmit request. returns 0 if all OK, else an appropriate errno.
 */

int tx_mbufs(register struct eh_softc *en, struct mbuf *m, u_char *dstadd, u_char *srcadd, int type, int unit)
{
    register struct mbuf *m0;
    register int datalen;
    register NICRef nic = en->Chip;
    TxqRef txdesc;
    int retries, error;
    u_char TxPending;

    for ( ; m; m = m->m_list)
    {
        /*
         * Count the length of the packet.
         */
        for (datalen = PACK_HDR_LEN, m0 = m; m0; m0 = m0->m_next)
            datalen += m0->m_len;

#ifdef DEBUG
        printf("debug: tx_mbuf, datalen:%x mbuf head:%x\n",datalen,(int) m);
#endif


#ifdef TESTCODE
#else
        if (datalen > ETHERMAXP)
        {
            sprintf(eh_lastlog, "tx_mbufs: too big (unit %d)", en->eh_unit);
            ++en->nmaxp;
            SETDCI4ERRNO(error, EMSGSIZE);
            return(error);
        }
#endif

        /* Check for a free transmit structure.     */
        if ((txdesc = en->TxqFree) == (TxqRef)NULL)
        {
            /* no free structures so check to see if last tx has completed */
            sprintf(eh_lastlog, "tx_mbufs: no tx structure (unit %d)", en->eh_unit);

            /* if packet has not been txed or was not an error then is there one in progress? */
            if (!(nicisr(nic) & (PTX | TXE)))
            {
                if ((nic->command) & TXP)
                {
                    MICRODELAY(20); /* delay increased from 20 to 2000! (17/9/97 GS) */
                    if (!(nicisr(nic) & (PTX | TXE))) /* what if this is a transmit error??? */
                    {
                        sprintf(eh_lastlog, "tx_mbufs: tx buffer full and tx pending (unit %d)",en->eh_unit);
                        ++en->nnotx;
                        SETDCI4ERRNO(error, ENOBUFS);
                        return(error);
                    }
                }
                else
                {
                    sprintf(eh_lastlog, "tx_mbufs: no tx pending and tx buffer full (unit %d)", en->eh_unit);
                    ++en->nnotx;
                    SETDCI4ERRNO(error, ENOBUFS);
                    return(error);
                }
            }

            eh_txdone(en, nic);

            if ((txdesc = en->TxqFree) == (TxqRef)NULL)
            {
                /* we have real problems if we get here */
                sprintf(eh_lastlog, "tx_mbufs: tx buffer overflow (unit %d)",en->eh_unit);
                ++en->nnotx;
                SETDCI4ERRNO(error, ENOBUFS);
                return(error);
            }
        }

        /* Pull this buffer off the chain.      */
        en->TxqFree = txdesc->TxNext;
        txdesc->TxNext = (TxqRef)NULL;
        txdesc->TxByteCount = MAX(datalen, (ETHERMIN + PACK_HDR_LEN));

        /* loop until packet is loaded, or excessive retries have failed */
        for (retries = 0; retries <= MAX_RDC_RETRIES; ++retries)
        {
            /*
             * define I/O direction, execute workaround for bug in remote
             * write DMA, initialise remote DMA parameters, then load
             * the packet
             */
            nic->rbcr0 = ~0;
            nic->command = START_DMA(DMA_READ);

            MICRODELAY(1);
            nic->command = START_DMA(DMA_ABORT);

            nic->rsar0 = 0;
            nic->rsar1 = txdesc->TxStartPage;
            nic->rbcr0 = datalen;
            nic->rbcr1 = datalen >> 8;
            nic->command = START_DMA(DMA_WRITE);

            load_packet(en, dstadd, srcadd, (u_short) htons(type), m, en->dma_port, datalen);

            if (!(nic->isr & RDC))
            {
                /*
                 * this is not yet a fatal error - give it
                 * a chance to recover then try again
                 */
                MICRODELAY(RDC_RECOVER_PERIOD);
            }

            /* now test the RDC bit for real */
            if (!(nic->isr & RDC))
            {
                /*
                 * something *is* wrong - stop the NIC, then
                 * start it up again
                 */
                shutdown(en, nic, &TxPending);
                startup(en, nic, TxPending);
            }
            else
            {
                /* transfer has completed OK */
                nic->isr = RDC;
                break;
            }
        }

        if (retries > MAX_RDC_RETRIES)
        {
            /*
             * discarding this transmit - return transmit buffer
             * to free chain & return error
             */
            txdesc->TxNext = en->TxqFree;
            en->TxqFree = txdesc;
            sprintf(eh_lastlog, "tx_mbufs: RDC failure (unit %d)", en->eh_unit);
            ++en->nrdc;
            SETDCI4ERRNO(error, EIO);
            return(error);
        }

        /* is this the first packet in the queue? */
        if (en->TxPending == (TxqRef)NULL)
        {
            /* yes - kick start the NIC */
            en->TxPending = txdesc;
            start_tx(en, nic);
        }
        else
        {
            /* if not the first packet in the queue add it to the end of the list */
            register TxqRef prev;
            for (prev = en->TxPending; prev->TxNext; prev = prev->TxNext)
              /* do nothing */
              ;

            prev->TxNext = txdesc;
        }

        /* increment tx frames count of unit as passed to eh_transmit which may be different from
         * the real unit number if virtual mode is on
         */
        eh_softc[unit]->eh_opackets++;

        /* see if any tx has completed. What if was a tx error????? */
        if (nicisr(nic) & PTX)
            eh_txdone(en, nic);
    }
    /*
     * All done.
     */
#ifdef DEBUG
    printf("debug: tx_mbuf done\n");
#endif
    return(0);

} /* tx_mbufs()         */


#ifdef DRIVER16BIT

/*
 *
 */

static void load_packet(struct eh_softc *en, u_char *hw_dst, u_char *hw_src, u_short type, register struct mbuf *m0, volatile u_int *port, int framelen)
{
    u_int bytebuf = 0;

#ifdef DEBUG
    printf("load_packet data:%x port:%x len:%x\n",(int)mtod(m0, u_char *),(int)port,m0->m_len);
#endif
    /*
     * Load up the packet destination, source, and type first.
     */
    (en->io_hout)(hw_dst, hw_src, type, port);

#ifdef DMATX
    framelen = dma_queue(DMA_CONTROL_WRITE, (framelen - PACK_HDR_LEN), en, m0, NULL);
#endif
    if (framelen != 0)
    {
       /* Now load up the mbuf data.        */
       for ( ; m0; m0 = m0->m_next)
       {
           (en->io_out)(mtod(m0, u_char *), port, m0->m_len, &bytebuf);
       }

       /* Flush any odd bytes remaining */
       (en->io_flushout)(port, &bytebuf);
    }

    /* Finished.                        */
    return;

} /* load_packet()              */

#else

/*
 *
 */

static void load_packet(struct eh_softc *en, u_char *hw_dst, u_char *hw_src, u_short type, register struct mbuf *m0, volatile u_char *port, int framelen)
{
#ifdef DEBUG
    printf("load_packet data:%x port:%x len:%x\n", (int)mtod(m0, u_char *), (int)port, m0->m_len);
#endif
   /*
    * Load up the packet destination, source, and type first.
    */
   eh_io_out(hw_dst, port, HW_ADDR_LEN);
   eh_io_out(hw_src, port, HW_ADDR_LEN);
   eh_io_out((u_char *) (&type), port, sizeof(u_short));

   /* Now load up the mbuf data.        */
   for ( ; m0; m0 = m0->m_next)
   {
      eh_io_out(mtod(m0, u_char *), port, m0->m_len);
   }
   
   UNUSED(en);
   UNUSED(framelen);
   
   /* Finished.                        */
   return;

} /* load_packet()              */

#endif


/*
 * eh_intr - entry point for ISR, steps are:
 *
 * 1 - handle all received packets
 *
 * 2 - deal with packet transmitted ints.
 *
 * 3 - check for transmit errors
 *
 * 4 - check for receive errors
 *
 * 5 - check for overwrite warning (should not happen - this is tested
 *     for within the receive packet code)
 *
 * 6 - deal with tally counter overflows
 *
 */

void eh_intr(register struct eh_softc *en)
{
    register NICRef nic = en->Chip;
    u_char TxPending;
    int count = 0;

    /* loop until all ints cleared */
    /* counter will stop this routine forever if something has gone badly wrong */

    while (nicisr(nic) && count<0x2000)
    {
        /* stage 1 - received packets */
        while (nicisr(nic) & PRX)
            eh_recv(en, nic);

        /* stage 2 - transmitted packets */
        while (nicisr(nic) & PTX)
            eh_txdone(en, nic);

        /* stage 3 - transmit errors */
        while (nicisr(nic) & TXE)
            eh_txfailed(en, nic);

        /* stage 4 - receive errors */
        while (nicisr(nic) & RXE)
            eh_rxfailed(en, nic);

        /* stage 5 - overwrite warning */
        while (nicisr(nic) & OVW)
        {
            if (nicisr(nic) & PRX)
                eh_recv(en, nic);       /* More packets have arrived so read them out */
            else
            {
                shutdown(en, nic, &TxPending);
                nic->isr = OVW;
                startup(en, nic, TxPending);
            }
        }

        /* stage 6 - tally counter overflow */
        while (nicisr(nic) & CNT)
        {
            if (nicisr(nic) & RXE)
                /* got more errors */
                eh_rxfailed(en, nic);
            else
            {
                /* this is also bad news */
                sprintf(eh_lasterr,"eh_intr: CNT with no receive errors"
                                   "FAE: %x CRC: %x FRL: %x (unit %d)",
                                   nic->cntr0, nic->cntr1, nic->cntr2, en->eh_unit);
                nic->isr = CNT;
            }
        }

        /* all over bar the shouting - test for extraneous bits */
        if (nicisr(nic) & RDC)
        {
            sprintf(eh_lastlog, "eh_intr: RDC signalled (unit %d)", en->eh_unit);
            /* Fix for DSL.                     */
            nic->isr = RDC;
        }
        else
        {
           if (nicisr(nic) & RST)
           {
              sprintf(eh_lasterr, "eh_intr: RST signalled (unit %d)", en->eh_unit);
           }
        }
        count++;
    }

} /* eh_intr()          */


/*
 * eh_recv - deal with received packet interrupts
 */

void eh_recv(struct eh_softc *en, NICRef nic)
{
    u_char overflowed = 0;
    u_char current_page, TxPending;
    int read_status = 0, count = 0, oldstate;

#ifdef DRIVER16BIT
#ifdef WINBODGE_DCR_1R
    if ((pre_init == TRUE) && (en->eh_cardtype == EH_TYPE_600))
        nic->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2);
#endif
#endif

#ifdef TRACE_ROUTINES
    printf("debug: eh_recv\n");
#endif

    /*
     * Acknowledge receive interrupt.
     */
    nic->isr = PRX;

    /*
     * Loop until all packets read.
     */
    if (!en->eh_dma_busy)
    {
        /*
         * Read where the start of the free buffer is.
         */
        oldstate = ensure_irqs_off();
        nic->command = SEL_PAGE(1, NIC_RUNNING);
        /*MICRODELAY(NIC_RESET_PERIOD);*/
        current_page = niccurr(nic);
        nic->command = SEL_PAGE(0, NIC_RUNNING);
        restore_irqs(oldstate);

        if (current_page == RX_START)
           current_page = RX_END + 1;

        /*
         * Loop until the boundary pointer reaches the start
         * of the free buffer.
         */
        while ((nicbnry(nic) != current_page - 1) && (count < 0x2000))
        {
#ifdef DMA
            /* can't start another dma operation whilst one is in progress, sorry */
            if (en->eh_dma_busy)
            {
               /* printf("dma: busy, rx_pending:%x\n", en->eh_rx_pending); */
               en->eh_rx_pending = TRUE;
               sprintf(eh_lasterr, "eh_recv: local dma busy, rx pending (unit %d)", en->eh_unit);
               return;

            }
#endif
            /*
             * Check for receive ring overflows.
             */
            if ((nicisr(nic) & OVW))
            {

#ifdef DEBUGABORT
                printf("eh_recv: overflow\n");
#endif

                ++overflowed;
                en->eh_ovw++;
                shutdown(en, nic, &TxPending);
                sprintf(eh_lastlog, "eh_recv: overflow signalled (unit %d)", en->eh_unit);

                /* Remove a packet & acknowledge the overflow.  */
                read_status = eh_read(en, nic);
                nic->isr = OVW;
            }
            else
            {
                /* Read next packet */
                read_status = eh_read(en, nic);
            }

            count++;
        }
        en->eh_rx_pending = FALSE;
    }
    else
    {
        /* an rx int was generated but we couldn't deal with it because
         * we have to wait until the previous one has been dealt with
         */
        en->eh_rx_pending = TRUE;
        sprintf(eh_lasterr, "eh_recv: local dma busy, rx pending (unit %d)", en->eh_unit);
    }

    /* Restart reception if necessary.                          */
    if (overflowed)
    {
        startup(en, nic, TxPending);
    }

#ifdef DEBUG
if (count > 20)
  printf("debug: frame count = %d\n",count);
#endif

#ifdef DRIVER16BIT
#ifdef WINBODGE_DCR_1R
    if ((pre_init == TRUE) && (en->eh_cardtype == EH_TYPE_600))
        nic->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2) | LAS;
#endif
#endif

} /* eh_recv()          */

/*
 * find a protocol module for this unit given a frame type
 */
struct eh_fib *find_protocol(struct eh_softc *en, int type)
{
    struct eh_fib *fp;

    /* is this an IEEE length or Ethernet 2.0 frame type? */
    if (type <= ETHERMTU)
    {
        /* treat this as an IEEE length field, is there a protocol module that wants IEEE? */
        for (fp = en->eh_fib; fp; fp = fp->next_fib)
        {
            if (FRMLVL_IEEE == fp->frame_level)
            {
#ifdef DEBUG
                printf("IEEE protocol module found fp:%x\n", (int) fp);
#endif
                return(fp);
            }
        }
    }
    else
    {
#ifdef DEBUG
        printf("debug: not ieee so search for others\n");
#endif
        /*
         * any protocol module want this frame type or has claimed all frame types?
         */
        for (fp = en->eh_fib; fp; fp = fp->next_fib)
        {
           if ((type == fp->frame_type) || (FRMLVL_E2MONITOR == fp->frame_level))
           {
#ifdef DEBUG
               printf("Protocol module found fp:%x\n", (int) fp);
#endif
               return(fp);
           }
        }

        /* if no one wants this frame type does anyone want unclaimed types? */
        for (fp = en->eh_fib; fp; fp = fp->next_fib)
        {
           if (FRMLVL_E2SINK == fp->frame_level)
           {
#ifdef DEBUG
              printf("Protocol sink module found fp:%x\n", (int) fp);
#endif
              return(fp);
           }
        }
    }
    return(0);
}

/*
 * eh_read - read a packet out of the ring buffer (no trailers!)
 *
 *    Frame filtering...
 *
 *    Get length of frame then frame header
 *
 *    If frame type is < ETHERMTU then if there is a protocol
 *    module that has claimed IEEE 802.3 (FRMLVL_IEEE) then
 *    goto the address check.
 *
 *    If no montior module has claimed all frames then if a
 *    module has claimed this specific frame type then goto
 *    address check else see if a module has claimed all unclaimed
 *    Ethernet 2.0 frames (FMLVL_SINK) if so then goto address check
 *    else reject frame.
 *
 *    address check:
 *    If this frame was addressed to us then load it and goto error check.
 *    If this a broadcast packet and the address level
 *    of the protocol module is specific then reject else goto load it etc.
 *    If not broadcast and to us then does is this module accepting all
 *    frames? If not reject else goto load it.
 *
 *    load it:
 *    Load data into mbuf chain (dma version uses to DMA manager to do this)
 *    Then if module requires error free reject if error occured.
 *
 *    Call protocol module through direct entry point
 *
 */

int eh_read(struct eh_softc *en, NICRef nic)
{
#ifdef DRIVER16BIT
    register u_int databuff;
    register volatile u_int *port = en->dma_port;
#else
    register volatile u_char *port = en->dma_port;
#endif
    struct mbuf *m, *m0;
    struct eh_fib *fp = NULL;
    struct eh_softc *en0, *en1;
    RxHdr  *rx_hdr;

    u_char buff_hdr[BUFF_HDR_LEN];
    u_char pack_hdr[PACK_HDR_LEN];
    u_short type;
    u_int datalen, len, framelen, valid;
    int i, old_next_pkt, status = 0, found = 0, debuglen;

    struct mbuf *mcopy;
    int p, broadcast = 0;
    u_int copylen = 0;

#ifdef DMA
    int dma_started = 0;
#endif

#ifdef TRACE_ROUTINES
    printf("debug: eh_read\n");
#endif

    /*
     * Start the Send Packet command.
     */
#if 0
    nic->rbcr1 = 0x0f;
    nic->command = START_DMA(DMA_SENDP);
#else
    /* set flag to indicate local dma is busy */
    en->eh_dma_busy = TRUE;

    nic->rbcr0 = BUFF_HDR_LEN;
    nic->rbcr1 = 0;
    nic->rsar0 = 0;
    nic->rsar1 = en->eh_next_pkt;
    nic->command = START_DMA(DMA_READ);
#endif

    /*
     * Read the buffer header.
     */
#ifdef DRIVER16BIT
    for (i = 0; i < BUFF_HDR_LEN; i += 2)
    {
        databuff = *port;
#ifdef DEBUG
        printf("%x:",databuff);
#endif
        buff_hdr[i] = databuff;
        buff_hdr[i + 1] = databuff >> 8;
    }
#else
    for (i = 0; i < BUFF_HDR_LEN; i++)
    {
        buff_hdr[i] = *port;
    }
#endif

    /*
     * update next_pkt pointer from this header
     */
    old_next_pkt = en->eh_next_pkt;     /* keep copy of old pointer in case need to re-start again later     */
    en->eh_next_pkt = *(buff_hdr + 1);  /* this is the pointer to the start of the next packet in the buffer */

    /*
     * Read the frame length from this header. ie: how many bytes are actually in the buffer
     */
    framelen = *(u_short *)(buff_hdr + 2);

#ifdef DEBUG
    printf("debug: eh_read(): framelen:%x eh_next_pkt:%x old_next_pkt:%x\n",framelen, en->eh_next_pkt,  old_next_pkt);
#endif

    if (framelen < PACK_HDR_LEN)
    {
        sprintf(eh_lasterr, "eh_read: bad framelen:%x in eh_read (unit %d)", framelen, en->eh_unit);
        framelen = 0; /* do not attempt to read any more data from the DMA port as it has all been read! */
        goto abort;
    }

    nic->rbcr0 = PACK_HDR_LEN;       /* set up remote byte count regs with number of */
    nic->rbcr1 = 0;
    nic->command = START_DMA(DMA_READ); /* and start the remote dma process */

    /*
     * Read the packet header to get dest address, src address
     * and packet type.
     */
#ifdef DRIVER16BIT
    for (i = 0; i < PACK_HDR_LEN; i += 2)
    {
        databuff = *port;
#ifdef DEBUG
        printf("%x:",databuff);
#endif
        pack_hdr[i] = databuff;
        pack_hdr[i + 1] = databuff >> 8;
    }
#else
    for (i = 0; i < PACK_HDR_LEN; i++)
    {
        pack_hdr[i] = *port;
    }
#endif

    /* adjust frame length to reflect how much data remains in the receive buffer for this packet */
    framelen -= PACK_HDR_LEN;

#ifdef DEBUG
    printf("eh_read: pack_hdr:%s\n", eh_sprint_mac(pack_hdr));
#endif
    en0 = en;

    /* if top bit of manufacturer allocted Ethernet address is set then this is addressed to
     * the virtual interface which is always this unit number + 1
     */
    if (virtual)
    {
       /* is it addressed directly to any of our units? */
       for (i = 0; ((i < ehcnt) && !found); i++)
       {
          found = 1;
          en0 = eh_softc[i];
          for (p = 0; ((p < HW_ADDR_LEN) && found); p++)
          {
             if (pack_hdr[p] != (en0->eh_addr[p] & 0xff))
                found = 0;
          }
       }
       /* if this bit of the dest address is set then it is a broadcast or multicast packet */
       /* if (pack_hdr[0] & ADDR_MULTICAST) */

       /*
        * if this frame is not a broadcast and not addressed to us and no protocol
        * module has requested all frames then abort it
        */
       if (!found)
       {
          /* see if the packet is a broadcast or multicast packet, if not abort it */
          /* what about promisucous mode operation ???? */
          if ((pack_hdr[0] & ADDR_MULTICAST))
          {
            broadcast = 1;
            en0 = eh_softc[0]; /* in virtual mode, see if first unit wants this broadcast first and copy to others */
          }
          else
            goto abort;
       }
#ifdef DEBUG
       printf("debug: virtual broadcast:%x found:%x unit:%x address:%s\n", broadcast, found, en0->eh_unit, eh_sprint_mac((int) &pack_hdr[0]));
#endif
    }

    /* Get the frame type from the header and see if we know about a protocol module who wants it. */
    type = ntohs(*(u_short *)(pack_hdr + (2 * HW_ADDR_LEN)));

#ifdef DEBUG
    printf("debug: frame type:%x framelen:%x\n",type, framelen);
#endif

    if (type <= ETHERMTU)
    {
        /* the length of valid data is the type field */
        datalen = (int) type;
    }
    else
    {
        /* datalen represents how much valid data is in the buffer */
        datalen = (framelen - CRC_LEN);
    }

    /* is the frame > than maximum transmission unit? */
    if (datalen > ETHERMTU)
    {
        sprintf(eh_lasterr, "eh_read: datalen %x > ETHERMTU, framelen %x (unit %d)", datalen, framelen, en0->eh_unit);
        goto abort;
    }

    found = 0;
    if (virtual && broadcast)
    {
        /* are there any protocol modules on any unit that want this frame type? */
        for (i = 0; ((i < ehcnt) && !found); i++)
        {
            en1 = eh_softc[i];
            fp = find_protocol(en1, type);
            if (fp != NULL)
            {
#ifdef DEBUG
                printf("debug: protocol found for type:%x datalen:%x fp:%x unit:%x\n", type, datalen, (int)fp, en1->eh_unit);
#endif
                found = 1;
            }
        }
    }
    else
    {
      /* only check the unit that it was received on */
      fp = find_protocol(en0, type);
      if (fp != NULL)
         found = 1;
    }

    if (!found)
    {
#ifdef DEBUG
        printf("debug: no protocol found for type:%x datalen:%x\n", type, datalen);
#endif
        goto abort;
    }

    /* if we get here there is at least one protocol on one unit that wants this frame so
     * now decide if we are going to read it from card
     * fp points to the protocol on the first unit that wants this frame
     */

    /* is this frame addressed directly to us? */
    for (i = 0; i < HW_ADDR_LEN; i++)
    {
        if (pack_hdr[i] != (en0->eh_addr[i] & 0xff))
            found = 0;
    }

    if (!found)
    {
#ifdef DEBUG
        printf("debug: not addressed to us\n");
#endif
        /* if not for us is it a broadcast packet? (ff:ff:ff:ff:ff:ff) */
        found = 1;
        for (i = 0; i < HW_ADDR_LEN; i++)
        {
            if (pack_hdr[i] != 0xff)
                found = 0;
        }

#ifdef DEBUG
        printf("debug: found broadcast? (ff:ff:ff:ff:ff:ff):%x\n", found);
#endif

        if (found)
        {
            /* this is a broadcast packet */
            if (fp->add_level == ADDRLVL_SPECIFIC)
            {
#ifdef DEBUG
               printf("debug: is broadcast and addrlvl is specific\n");
#endif
               framelen = 0;
            }
#ifdef DEBUG
            printf("debug: IS broadcast\n");
#endif
            broadcast = 1;
        }
        else
        {
            /* this frame is not addressed to us and is not a broadcast so
             * does the protocol module still want this frame?
             * ie: promiscuous or multicast mode
             */
#ifdef DEBUG
            printf("debug: not found\n");
#endif
            /* is it a multicast packet ? */
            if (fp->add_level == ADDRLVL_MULTICAST)
            {
                if (!(pack_hdr[0] & ADDR_MULTICAST))
                {
#ifdef DEBUG
                   printf("debug: is not multicast and multicast is set\n");
#endif
                   framelen = 0;
                }
                else if (!fp->softmult_disabled) /* Disabled in virtual mode so don't worry */
                {
                   /* OSS 23 June 2001 We're in multicast mode and it is a multicast packet so
                      decide if we want it or not.
                      OSS 4.51 20 Nov 2002 Changed to full 48 bits code. */

                   for (i = 0; i < SOFTMULT_COUNT; i++)
                   {
                      if (fp->softmult[i].use_count != 0 &&
                          memcmp(pack_hdr, fp->softmult[i].mac, 6) == 0)
                      {
                         /* We've found the array entry for this one */

                         break;
                      }
                   }

                   if (i < SOFTMULT_COUNT)
                   {
                      /* Found the entry so just increment statistic and allow through */

                      fp->softmult_allowed++;
                   }
                   else
                   {
                      /* Entry not found, increment discard stat and throw away */

                      fp->softmult_discards++;
                      goto abort;
                   }
                }
#ifdef DEBUG
                printf("debug: IS multicast and multicast is set\n");
#endif
                broadcast = 1;
            }
            else
            {
#ifdef DEBUG
                printf("debug: not multicast mode\n");
#endif

                if (fp->add_level != ADDRLVL_PROMISCUOUS)
                {
#ifdef DEBUG
                   printf("debug: is not broadcast or for us and addrlvl is not PROMISCUOUS %x\n",fp->add_level);
#endif
                   goto abort;
                }
            }
        }
    }

#ifdef DEBUG
    printf("debug: now claim mbuf rxhdr:%x m:%x\n", sizeof(RxHdr), (int) m);
#endif
    /*
     * claim mbuf for rx header block for this frame
     */

    m = (ALLOC(sizeof(RxHdr), NULL));

#ifdef DEBUG
    printf("mbuf %x\n", (int) m);
#endif

    if (m == NULL)
    {
#ifdef DEBUG
        printf("mbuf not claimed\n");
#endif
        sprintf(eh_lasterr, "eh_read: failed to claim mbuf header for %x (unit %d)", (int) m, en->eh_unit);
        /* reset the next pkt pointer so that the next eh_read will attempt to read the same packet again */
        /*en->eh_next_pkt = old_next_pkt;*/
        status = 0;
        en->eh_nombuf++;
        goto abort;
    }

#ifdef DEBUG
    printf("claimed mbuf for header:%x srcadd:%x fp:%x\n",(int) m, (int) &pack_hdr[0], (int) fp);
#endif
    rx_hdr = mtod(m, RxHdr *);
    rx_hdr->rx_tag = 0;
    rx_hdr->rx_frame_type = type;
    rx_hdr->rx_error_level = 0;
    for (i = 0; i < HW_ADDR_LEN; i++)
    {
        rx_hdr->rx_dst_addr[i] = pack_hdr[i];
        rx_hdr->rx_src_addr[i] = pack_hdr[i+HW_ADDR_LEN];
    }
    m->m_len = sizeof(RxHdr);
    m->m_type = MT_HEADER;

    /* see if protocol requires safe mbuf chain and if so make it safe before passing on */
    if (fp->flags & FILTER_NO_UNSAFE)
    {
#ifdef DEBUG
        printf("debug: ensure safe header\n");
#endif
        m = ENSURE_SAFE(m);
    }

    /*
     * if this was a multicast or broadcast and in virtual mode then make a copy to send
     * the other protocol module
     */
    if (virtual && broadcast)
    {
       /* what if this fails? */
       mcopy = COPY(m, 0, m->m_len);
       if (mcopy)
       {
          mcopy->m_len = sizeof(RxHdr);
          mcopy->m_type = MT_HEADER;
          copylen = framelen;
       }
    }
    else
       mcopy = NULL;

    /*
     * now read data out of the packet into an mbuf chain.
     * claim next mbuf in chain for the data - big enough to hold the whole frame
     * make sure the size is word aligned
     */
    if ((m->m_next = ALLOC(((framelen + 3) &  ~3), NULL)) == NULL)
    {
        /* free mbuf chain claimed for hdr */
        m_freem(m);
        m_freem(mcopy);
        sprintf(eh_lasterr, "eh_read: failed to claim mbuf for framelen %x (unit %d)", framelen, en->eh_unit);
        /* reset the next pkt pointer so that the next eh_read will attempt to read the same packet again */
        /*en->eh_next_pkt = old_next_pkt;*/
        status = 0;
        en->eh_nombuf++;
        goto abort;
    }

#ifdef DMA
#ifdef DEBUGDMA
    printf("debug: start_dma sendp:%x rbcr1:%x framelen:%x mbuf:%x\n", START_DMA(DMA_SENDP), (int) &nic->rbcr1, framelen, (int) m);
#endif
    if ((en->eh_primary_dma) && ((framelen % 0x10) == 0))
    {
       /* nb: dma manager will only accept lengths that are a multiple of transfer size ie:16 bit */
       /*if (framelen & 1)
          framelen++;*/
       framelen = dma_queue(DMA_CONTROL_READ, framelen, en, m, fp);

       if (framelen != 0)
          sprintf(eh_lastlog, "eh_read: DMA request failed (unit %d)", en->eh_unit);
       else
       {
          en->eh_dmapackets++;
          dma_started = 1;
       }
#ifdef DEBUGDMA
       printf("debug: DMA framelen:%x dma_started:%d\n",framelen, dma_started);
#endif
    }
#endif /* DMA */

    if (framelen != 0)
    {
       nic->rbcr0 = (framelen & 0xff);     /* set up remote byte count regs with number of */
       nic->rbcr1 = (framelen >> 8);       /* bytes to read, info from the header */
       nic->command = START_DMA(DMA_READ); /* and start the remote dma process */

       debuglen = datalen;

       for (m0 = m->m_next ; m0; m0 = m0->m_next)
       {
#ifdef DEBUG
           printf("debug: data mbuf ptr:%x mbuf len:%x datalen:%x framelen:%x srcadd:%s\n",
                  (int)m0, m0->m_len, datalen, framelen, eh_sprint_mac((int) &pack_hdr[0]));
#endif
           len = MIN(framelen, m0->m_len);
           if (m0->m_len & 1)
              sprintf(eh_lasterr, "eh_read: mbuf odd length %x (unit %d)", (int) m0->m_len, en0->eh_unit);
           valid = MIN(datalen, len);
           eh_io_in(port, mtod(m0, u_char *), len);
           m0->m_len  = valid;   /* this is the amount of valid data in this mbuf */
           m0->m_type = MT_DATA;
           framelen -= len;      /* update the amount of data read from the card */
           datalen -= valid;     /* update the amount of valid data still to be put into an mbuf */
       }
       /* Increment count of received packets.             */
       en0->eh_ipackets++;

       if (virtual && broadcast)
       {
          /* what if this fails? */
          if (mcopy)
          {
             mcopy->m_next = COPY(m->m_next, 0, copylen);
             if (mcopy->m_next)
                mcopy->m_next->m_type = MT_DATA;
             else
             {
                m_freem(mcopy);
                mcopy = NULL;
             }
          }
       }
    }
    else
       goto abort;

#ifdef DEBUG
    printf("debug: len:%x framelen:%x datalen:%x fp:%x\n",len, framelen, datalen, (int)fp);
#endif

    if (framelen != 0)
    {
        /* something went wrong so abort this operation
         * and free mbuf chain!!!
         */
        /* free mbuf chain claimed for hdr and data */
        m_freem(m);
        m_freem(mcopy);
        sprintf(eh_lasterr, "eh_read: failed to copy data into mbuf (unit %d)", en0->eh_unit);
        goto abort;
    }

    /* read out anything left over and drop on floor, such as the CRC
     * and clear RDC interrupt
     */
       abort_packet(en, framelen, 0);

    while (fp)
    {
       /* see if protocol requires safe mbuf chain and if so make it safe before passing on */
       if (fp->flags & FILTER_NO_UNSAFE)
       {
#ifdef DEBUG
           printf("debug: ensure safe data\n");
#endif
           m->m_next = ENSURE_SAFE(m->m_next);
       }

#ifdef DEBUGABORT
       printf("debug: eh_read dib ptr:%x mbuf head:%x len:%x handler:%x private word:%x\n",
              (int)en0->eh_dib, (int) m, (int) m->m_len, (int)fp->handler, (int)fp->private);
#endif

       /* does this module want frames with errors? if so did an error occur?  */
       if (fp->err_level ==  ERRLVL_NO_ERRORS)
       {
           if (!(nic->rsr & RSR_PRX))
           {
#ifdef DEBUG
               printf("debug: frame received with error\n");
#endif
               /* free mbuf chain claimed for hdr and data */
               m_freem(m);
               m_freem(mcopy);
               sprintf(eh_lasterr, "eh_read: frame received with error (unit %d)", en0->eh_unit);
               return(0); /* changed from 1 19/9/97 GS */
           }
       }

#ifdef DEBUG
       printf("debug: frame received for :%x mbuf len:%x\n", (int) fp->handler, (int) m->m_len);
#endif

       eh_call_protocol(en0->eh_dib, m, fp->private, fp->handler);


#if 0
       if (en0->eh_lastsize != debuglen)
       {
#ifdef DEBUG1
         /* if the framecount was not 10 and the last count was 10 report this */
         if  ((en0->eh_lastcount == 10) && (en0->eh_framecount != 10) && (en0->eh_lastsize == 1500))
            printf("debug: frame size:%x count:%x\n",en0->eh_lastsize,en0->eh_framecount);
#endif
         /* if last frame was 1500 long, note how many we received */
         if (en0->eh_lastsize == 1500)
            en0->eh_lastcount = en0->eh_framecount;

         en0->eh_lastsize = debuglen;
         en0->eh_framecount = 0;
       }
       else
         en0->eh_framecount++;
#endif

       /*
        * if this was a broadcast or multicast frame then send a copy to any protocol
        * that wants it on the next unit only (ie: the virtual one)
        */
       fp = 0;

       if ((virtual && broadcast) && mcopy)
       {
          en0 = eh_softc[en0->eh_unit + 1]; /* get ptr to next unit??? */
          if (en0)
          {
            fp = find_protocol(en0, type);
            if (fp != NULL)
            {
#ifdef DEBUG
               printf("debug: copy of data also sent to protocol handler:%x\n", (int) fp->handler);
#endif
               m = mcopy;
               mcopy = 0;
            }
            else
               m_freem(mcopy);
          }
          else
            m_freem(mcopy);
       }
    }
    return(0); /* all ok */

abort:
#ifdef DEBUG
       printf("abort packet from eh_read framelen:%x\n", framelen);
#endif
       if (status == 0) en->eh_reject++;

#ifdef DMA
       if (!dma_started)
#endif
          abort_packet(en, framelen, 0);
    return(status) ; /* non-0 if not all ok? */
} /* eh_read()          */


/*
 * abort_packet - stop the currently executing send_packet command
 * this gets called at the end of every eh_read so may be entered with
 * a count of 0 which means the read has finished and all that is left
 * to do is update pointers and check and clear the RDC interrupt
 */

void abort_packet(struct eh_softc *en, int count, int skip)
{
#ifndef ABORTSKIP
    int i;
#endif
    NICRef nic = en->Chip;
    int new_bnry;

    UNUSED(skip);
    
#ifdef BORDER
    set_border(1);
#endif

#ifdef DEBUGDMA
    printf("abort: count:%x next_pkt:%x\n",count,en->eh_next_pkt);
#endif

#ifdef ABORTSKIP

   /*
    * Send the ABORT DMA command,
    */
    nic->command = START_DMA(DMA_ABORT);

#if 0
    if (count > 0)
    {
       /*
        * only do the read of the DMA port if there is some data left to be read for the current DMA
        * operation
        */
       if (count > (ETHERMTU + PACK_HDR_LEN + CRC_LEN))
          sprintf(eh_lastlog, "abort_packet: bad length %x (unit %d)", count, en->eh_unit);

       /*
        * Throw away the data waiting for us at the DMA port.
        * if we do this and there is no data waiting at this port, the machine will hang!
        */
       nulldev(*port);
    }
#endif

    /*
     * Check that remote DMA has completed.
     */

    if (!(nicisr(nic) & RDC))
    {
       /*
        * this is not yet a fatal error - give it
        * a chance to recover then try again
        */
       MICRODELAY(RDC_RECOVER_PERIOD);
       if (!(nicisr(nic) & RDC))
       {
          sprintf(eh_lastlog, "abort_packet: RDC failure length %x (unit %d)", count, en->eh_unit);
          nic->command = START_DMA(DMA_ABORT);
#ifdef DEBUGABORT
          printf("abort: RDC still high!\n");
#endif
       }
    }

    /*
     * Move the boundary pointer to point to one page behind start next packet.
     * check if this is less than start of of rx buffer and if so then make it
     * one behind end of rx buffer. This is to cater for the fact that it is
     * circular (obviously). eh_next_pkt had better be right otherwise we are in trouble
     */
    new_bnry = en->eh_next_pkt - 1;

    if (new_bnry < RX_START)
    {
#ifdef DEBUG
       printf("debug: new_bnry is less than RX_Start =%x\n",new_bnry);
#endif
       new_bnry = RX_END - 1;
    }

    nic->bnry = new_bnry;

    /*
     * Clear Remote DMA Byte Count Registers
     */
    nic->rbcr0 = 0;
    nic->rbcr1 = 0;

#ifdef DEBUG
    printf("abort: next_pkt:%x new_bnry:%x\n", en->eh_next_pkt, new_bnry);
#endif

    /* Acknowledge end of remote DMA.   */
    nic->isr = RDC;

    /* and clear dma in use flag */
    en->eh_dma_busy = FALSE;

#else

#ifdef DRIVER16BIT
    for (i = 0; i < (count+1)/2; i++)
    {
       nulldev(*port);
    }
#else
    for (i = 0; i < count; i++)
    {
       nulldev(*port);
    }
#endif

    /*
     * Check that remote DMA has completed.
     */
    if (!(nicisr(nic) & RDC))
    {
        /*
         * this is not yet a fatal error - give it
         * a chance to recover then try again
         */
        MICRODELAY(RDC_RECOVER_PERIOD);
        if (!(nicisr(nic) & RDC))
        {
#ifdef DEBUG
            printf("debug: abort_packet - RDC failed\n");
#endif

            sprintf(eh_lastlog, "abort_packet: RDC failure (unit %d)", en->eh_unit);
            nic->command = START_DMA(DMA_ABORT);
            /*nic->bnry = *(buff_hdr + 1);*/
        }
    }

    /* Acknowledge end of remote DMA.   */
    nic->isr = RDC;

#endif /* ABORTSKIP */

} /* abort_packet()             */



/*
 * shutdown - go through the motions of taking the NIC off a live
 * network to allow recovery from a ring buffer overflow
 */

void shutdown(struct eh_softc *en, NICRef nic, u_char *TxPending)
{
    /*
     * follow the recipe given in the NIC datasheets, i.e.
     *
     * test for transmit pending
     * issue the STOP command,
     * clear remote byte counters,
     * wait for RST to come up,
     * put the NIC into loopback,
     * issue the START command.
     */

    *TxPending = nic->command & TXP;
    nic->command = SEL_PAGE(0, NIC_STOPPED);

    MICRODELAY(NIC_RESET_PERIOD);

    nic->rbcr0 = nic->rbcr1 = 0;

    nic->tcr = TCR_INIT_VALUE | LOOP_MODE(LOOPBACK1);
    nic->command = SEL_PAGE(0, NIC_RUNNING);

    /*
     * acknowledge the RST bit also clear RDC which
     * decides to appear
     */
    nic->isr = (RST | RDC);

} /* shutdown()         */


/*
 * startup - bring the NIC back onto a live network following a shutdown
 */

void startup(struct eh_softc *en, NICRef nic, u_char TxPending)
{
#ifdef TRACE_ROUTINES
    printf("debug: startup\n");
    fflush(stdout);
#endif

    /*
     * follow the recipe given in the NIC datasheets, i.e.
     *
     * take the NIC out of loopback & onto the live network
     */
    nic->tcr = TCR_INIT_VALUE | LOOP_MODE(LIVE_NET);

    /*
     * restart transmit if lost by shutdown
     */
    if ((TxPending) && !(nic->isr & (PTX | TXE)))
        start_tx(en, nic);

} /* startup()          */


/*
 * eh_txdone - remove a successfully transmitted packet from the queue,
 * then start next packet if necessary.
 */

static void eh_txdone(struct eh_softc *en, NICRef nic)
{
    /*
     * acknowledge the interrupt and
     * increment the count of transmitted packets
     */

    nic->isr = PTX;

#ifdef DEBUG
    printf("eh_txdone cleared tx int\n");
#endif



    /* check for Signal Quality Error if this is appropriate.   */
    if ((en->eh_flags & EH_SQETEST) && !(nic->tsr & COL) && (nic->tsr & CDH))
    {
#if 0
        /* Check if adaptor connected.                          */
        check_adaptor(en);
#endif

        /* do not repeatedly send out this message.             */
        if (!(en->eh_flags & EH_SQEINFORMED))
        {
            sprintf(eh_lastlog,
                    "eh_txdone: CD/Heartbeat failure, is the AUI cable connected? (unit %d)",
                    en->eh_unit);
            en->eh_flags |= EH_SQEINFORMED;
        }
    }

#ifdef DEBUG
    printf("eh_txdone test for collisions\n");
#endif

    /* test for recovered collisions */
    if (nic->tsr & COL)
    {
        u_char n_colls = nic->ncr & 0x0f;

        en->ncoll += n_colls;
        en->eh_collisions += n_colls;
        en->eh_flags &= ~EH_SQETEST;
    }
    else
        en->eh_flags |= EH_SQETEST;

    tx_done(en, nic);

} /* eh_txdone()                */


/*
 * tx_done - remove transmit request from head of queue, start next
 * transmit if required
 */

static void tx_done(struct eh_softc *en, NICRef nic)
{
    TxqRef txdesc;
    int    oldstate;

#ifdef DEBUG
    printf("debug: tx_done free entry in tx queue\n");
#endif

    /*
     * Turn interrupts off, 'cause we are manipulating transmit queue.
     */
    oldstate = ensure_irqs_off();

    /* Act cautious.            */
    if (!en->TxPending)
    {
        sprintf(eh_lasterr, "tx_done: packet transmitted from empty queue (unit %d)", en->eh_unit);
        restore_irqs(oldstate);
        return;
    }

    /*
     * Put this transmit request back into the free list.
     */
    if (en->TxqFree)
    {
        for (txdesc = en->TxqFree; txdesc->TxNext; txdesc = txdesc->TxNext)
            /* do nothing */
            ;
        txdesc->TxNext = en->TxPending;
    }
    else
        en->TxqFree = en->TxPending;

    txdesc = en->TxPending->TxNext;
    en->TxPending->TxNext = (TxqRef)NULL;

#ifdef DEBUG
    printf("debug: tx_done start next tx in queue\n");
#endif

    /*
     * Start next transmit if one there.
     */
    en->TxPending = txdesc;
    if (txdesc != NULL)
        start_tx(en, nic);

    /* Finished. */
    restore_irqs(oldstate);

#ifdef DEBUG
    printf("debug: tx_done done\n");
#endif

} /* tx_done()          */


/*
 * start_tx - send a transmit packet command to the NIC.
 * MUST be called with interrupts off.
 */

void start_tx(struct eh_softc *en, NICRef nic)
{
    TxqRef txq = en->TxPending;

#ifdef DEBUG
    printf("debug: start_tx\n");
#endif

    /* set up the control registers */
    nic->tpsr = txq->TxStartPage;
    nic->tbcr0 = txq->TxByteCount;
    nic->tbcr1 = txq->TxByteCount >> 8;

    /* start the transmission */
    nic->command = START_DMA(DMA_IDLE) | TXP;

} /* start_tx()         */


/*
 * eh_txfailed - `recover' from a transmit error. this means log the
 * failure then forget about the packet it happened on.
 */

static void eh_txfailed(struct eh_softc *en, NICRef nic)
{
    /*
     * acknowledge the interrupt, then increment the count
     * of Tx errors
     */
    nic->isr = TXE;
    en->eh_oerrors++;

    /* check for aborted transmit (excess collisions) */
    if (nic->tsr & ABT)
    {
        ++en->nxscoll;
        en->eh_collisions += 16;
    }

    /* check for FIFO underrun */
    if (nic->tsr & FU)
    {
        ++en->nundrn;
    }

    /* now get rid of this transmit request */
    tx_done(en, nic);
} /* eh_txfailed()              */


/*
 * eh_rxfailed - deal with receive errors.
 * This means log them then forget about them.
 */

static void eh_rxfailed(struct eh_softc *en, NICRef nic)
{
    u_char err_count, max_count = 0;

    /*
     * acknowledge both the receive error & counter
     * overflow interrupts, then increment the count
     * of bad receives
     */
    nic->isr = (RXE | CNT);
    en->eh_ierrors++;

    /* frame alignment errors */
    err_count = nic->cntr0;
    en->nfae += err_count;
    max_count = MAX(max_count, err_count);

    /* crc errors */
    err_count = nic->cntr1;
    en->ncrc += err_count;
    max_count = MAX(max_count, err_count);

    /* frames lost */
    err_count = nic->cntr2;
    en->nfrl += err_count;
    max_count = MAX(max_count, err_count);

    /*
     * if all these counters returned zero, then assume
     * problem was a fifo overrun. (a bit crude)
     */
    if (max_count == 0)
    {
        ++(en->novrn);
    }

} /* eh_rxfailed()              */



/*
 * Disable interrupts and controller prior to software reset.
 * tidy up interrupt handlers etc..
 * Reset ROM page register.
 */

void eh_softreset(void)
{
    struct eh_softc *en;
    int i;

#ifdef TRACE_ROUTINES1
    printf("debug: eh_softreset\n");
    fflush(stdout);
#endif

    pre_init = TRUE;

    /* reset each card, mark as inactive, set DCR for 600 cards and set rom page to 0 */
    for (i = 0; i < ehcnt; i++)
    {
        en = eh_softc[i];
        eh_reset_card(en);
        en->eh_flags &= ~EH_RUNNING;

#ifdef WINBODGEDCR2
        if (en->eh_cardtype == EH_TYPE_600)
        {
           en->Chip->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2) | LAS;
        }
#endif
        eh_set_rom_page(en, 0x00);    /* Reset ROM page register to 0. */
    }

} /* eh_softreset()        */


/*
 * Disable interrupts from card.
 */

static int eh_disint(struct eh_softc *en)
{
   int oldstate = en->control_reg & EH_INTR_MASK;

#ifdef DEBUGINT
    printf("debug: eh_disint:%x en->control_reg:%x\n",(int) en->cntrl_reg, (int) en->control_reg);
    fflush(stdout);
#endif

   switch (en->eh_cardtype)
   {
#ifdef DRIVER8BIT
      case EH_TYPE_200:
         /* Read control register.                            */
         nulldev(*en->cntrl_reg);

         /* Disable interrupts.                               */
         en->control_reg &= ~EH_INTR_MASK;
         *en->cntrl_reg = en->control_reg;

         /* Read control register.                            */
         nulldev(*en->cntrl_reg);
         break;
#endif

      case EH_TYPE_100:
      case EH_TYPE_500:
      case EH_TYPE_600:
      case EH_TYPE_700:
         /* Disable interrupts.                                */
         en->control_reg &= ~EH_INTR_MASK;
         *en->cntrl_reg = en->control_reg;
         break;
   }

   return oldstate;

} /* eh_disint()         */


/*
 * Enable interrupts from card.
 */

void eh_enint(struct eh_softc *en)
{

#ifdef TRACE_ROUTINES
    printf("debug: eh_enint cardtype:%x\n", (int) en->eh_cardtype );
    fflush(stdout);
#endif

   switch (en->eh_cardtype)
   {
#ifdef DRIVER8BIT
      case EH_TYPE_200:
         /* Read control register.                            */
         nulldev(*en->cntrl_reg);

         /* Enable interrupts.                                */
         en->control_reg |= EH_INTR_MASK;
         *en->cntrl_reg = en->control_reg;

         /* Read control register.                            */
         nulldev(*en->cntrl_reg);
         break;
#endif

      case EH_TYPE_100:
      case EH_TYPE_500:
      case EH_TYPE_600:
      case EH_TYPE_700:
         /* Enable interrupts.                                */
         en->control_reg |= EH_INTR_MASK;

#ifdef DEBUGINT
         printf("debug: eh_enint eh_slot:%x en->cntrl_reg:%x en->control_reg:%x\n", (int) en->eh_slot, (int) en->cntrl_reg, (int) en->control_reg);
         fflush(stdout);
#endif
         *en->cntrl_reg = en->control_reg;
         break;
   }

} /* eh_enint()         */

#ifdef BORDER
int set_border(colour)
int colour;
{
    _kernel_oserror *e;
    _kernel_swi_regs rin,rout;
    char block[6];

    block[0] = 0;
    block[1] = 24;
    block[2] = 0;
    block[3] = 0;
    block[4] = 0;

    block[colour+2]=255;

    rin.r[0] = OsWord_WritePalette;
    rin.r[1] = (int) block;
    e =_kernel_swi(XOS_Bit | OS_Word, &rin, &rout);
}
#endif
/* EOF */
