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
 * Title:       RISC OS Ethernet Driver Source (DMA support)
 * Author:      Gary Stephenson
 * File:        dma.c
 *
 * Copyright © 1995 Network Solutions
 * Copyright © Design IT 2000
 *
 **************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <kernel.h>
#include <swis.h>

#include <sys/types.h>
#include <sys/dcistructs.h>
#include <sys/errno.h>
#include <sys/mbuf.h>

#include "if_eh.h"
#include "Init.h"
#include "Dma.h"
#include "module.h"

#define DEBUGDMA

struct dma_control
{
   void (*enable)();
   void (*disable)();
   void (*start)();
   void (*completed)();
   void (*sync)();
};

static struct dma_control dma =
{
        eh_enable_dma,
        eh_disable_dma,
        eh_start_dma,
        eh_completed_dma,
        eh_sync_dma
};

/* init dma bits */
void dma_register(struct eh_softc *en)
{
    _kernel_swi_regs rin,rout;
    _kernel_oserror *e;

    rin.r[0] = 0;                  /* flags, currently all 0                */
    rin.r[1] = en->eh_primary_dma; /* logical channel                       */
    rin.r[2] = 1;                  /* DMA cycle speed                       */
    rin.r[3] = 2;                  /* transfer unit size 2 bytes (16 bit)   */
    rin.r[4] = (int) &dma;         /* pointer to table of control routines  */
    rin.r[5] = (int) module_wsp;   /* workspace pointer to be passed in r12 */

#ifdef DEBUG
    printf("control table:%x module_wsp:%x\n", (int) &dma, (int) module_wsp);
#endif

    e =_kernel_swi(XOS_Bit | DMA_RegisterChannel, &rin, &rout);
    if (e == 0)
    {
        en->eh_dma_channel = rout.r[0];
#ifdef DEBUG
        printf("dma channel:%x\n", en->eh_dma_channel);
#endif
    }

}


void dma_deregister(struct eh_softc *en)
{
    _kernel_swi_regs rin,rout;
    _kernel_oserror *e;

    rin.r[0] =  en->eh_dma_channel;
    e =_kernel_swi(XOS_Bit | DMA_DeregisterChannel, &rin, &rout);

}


int dma_queue(int flags, int framelen, struct eh_softc *en, struct mbuf *m, struct eh_fib *fp)
{
    struct mbuf *m0;
    int i, found;
    /* int mbufs = 0;*/
    struct scatter_list *sp0;
    struct dma_request *dc;
    _kernel_swi_regs rin, rout;
    _kernel_oserror *e;
    NICRef nic;

    nic = en->Chip;

    /* count how many mbuf there are in this chain
    for (m0 = m->m_next; m0; m0 = m0->m_next)
       mbufs++;*/

    /* look for first free dma control structure */
    i = 0;
    found = FALSE;
    while ((i < MAXDMA) && (found == FALSE))
    {
       dc = &en->eh_dc[i];
       if (dc->en == NULL)
          found = TRUE;
       i++;
    }

    if (found)
    {
        /* printf("dc:%x\n", (int) dc);*/
        /* allocate a dma request control block */
        if (en)
        {
           /* now build a scatter list */
           /* note: the scatter list can only hold a limited number of pointer/length */
           /* pairs and if there are more mbufs in the chain this will go wrong!!     */
           sp0 = dc->sp;
           /*
            * if this is a write then data start at m otherwise m points to the rx hdr
            * and m->m_next is where the data will go
            */
           if (flags & DMA_CONTROL_WRITE)
              m0 = m;
           else
              m0 = m->m_next;

           for ( ; m0; m0 = m0->m_next)
           {
              m0->m_type = MT_DATA;
              sp0->address = (int) m0 + m0->m_off;
              sp0->length  = m0->m_len;
              sp0++;
           }
           sp0->address = 0;
           sp0->length = 0;
           dc->flags = flags;
           dc->eh_dmactrl = en->cntrl_reg2;
           dc->eh_dib = en->eh_dib;          /* the dib this dma is for */
           dc->fp = fp;                      /* frame info block pointer */
           dc->m = m;                        /* pointer to start of mbuf chain (hdr + data) */
#if 0
           dc->sp = sp;                      /* scatter list pointer, static allocation */
#endif           
           dc->en = en;

           rin.r[0] = flags;                 /* flags */
           rin.r[1] = en->eh_dma_channel;    /* logical dma channel */
           rin.r[2] = (int) dc;              /* value to be passed in r11 */
           rin.r[3] = (int) dc->sp;          /* pointer to scatter list */
           rin.r[4] = framelen;              /* how much data to read or write, the mbufs had better be big enough! */
           rin.r[5] = 0;                     /* size of circular buffer (if bit 1 of r0 set) */
           rin.r[6] = 0;                     /* number of bytes between DMAsync (if bit 2 of r0 set) */

#ifdef DEBUG
           printf("dma: flags:%x channel:%x dc:%x sp:%x framelen:%x m:%x\n",
                  flags, en->eh_dma_channel, (int) dc, (int) dc->sp, framelen, (int) m);
#endif
           /*
            * stop this card from generating any rx interrupts when the irq
            * handler has finished with this interrupt
            */
           /*en->eh_imr_value = (en->eh_imr_value & 0xfe);*/
           /*en->eh_imr_value = 0x00;*/

           e =_kernel_swi(XOS_Bit | DMA_QueueTransfer, &rin, &rout);

           if (e == 0)
           {
              dc->dma_tag = rout.r[0];
#ifdef DEBUGDMA
              printf("dma: dc:%x hello\n", (int) dc);
#endif
              framelen = 0;
           }
           else
           {
              en->eh_imr_value = IMR_INIT_VALUE;
              /* free this dma control block */
              dc->en = NULL;
              sprintf(eh_lasterr, "dma_queue: manager error %x (unit %d)", e->errnum, en->en_unit);
           }
        }
    }
    else
    {
#ifdef DEBUGDMA
       printf("dma failed\n");
#endif
       sprintf(eh_lasterr, "dma_queue: failed to allocate dc for mbuf %x (unit %d)", (int) m, en->en_unit);
       en->eh_nodma++;
    }
    return(framelen);
}


/* dma control routines */
void completed_dma_handler(_kernel_swi_regs *r, void *pw)
{
   struct eh_softc *en;
   struct dma_request *dc;
   struct eh_fib *fp;
   pw = pw;

   dc = (struct dma_request *) r->r[0];
   /* this had better be a valid pointer!! */
   fp = dc->fp;
   en = dc->en;

#ifdef DEBUGDMA
   printf("dma: completed r11:%x fp:%x rx_pending:%x dma_busy:%x\n",
          r->r[0], (int) fp, en->eh_rx_pending, en->eh_dma_busy);
#endif
   /*en->eh_imr_value = IMR_INIT_VALUE;*/

   if (!(dc->flags & DMA_CONTROL_WRITE))
   {
      /* update pointers, clear RDC and dma_busy flag*/
      abort_packet(en, 0, 0);

#if 0
      if (en->eh_rx_pending)
      {
          en->eh_rx_pending = FALSE;
      }
#endif

      eh_call_protocol(dc->eh_dib, dc->m, fp->private, fp->handler);

      /*
       * if not already in irq handler, check to see if there are any packets waiting in the receive buffer
       */
      /*if (!en->eh_irqh_active)*/
      if (en->eh_rx_pending)
         eh_recv(en, en->Chip);

   }
   /*
    * free dma control structure
    */
   dc->en = NULL;
   /*
    * if not already in irq handler restore imr
    */
   if (!eh_irqh_active)
      eh_enint(en);
}

