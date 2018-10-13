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
 * File:        init.c
 *
 * Copyright © 1992 PSI Systems Innovations
 * Copyright © 1994 i-cubed Limited
 * Copyright © 1995 Network Solutions
 * Copyright © 2000 Design IT
 *
 *************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <kernel.h>
#include <swis.h>
#include "AsmUtils/irqs.h"
#include "Global/Variables.h"
#include "Global/OsBytes.h"
#include "Global/IO/GenericIO.h"
#include "Global/DevNos.h"
#include "Interface/Podule.h"

#include <sys/types.h>
#include <sys/dcistructs.h>
#include <sys/errno.h>

#include "EtherHHdr.h"
#include "if_eh.h"
#include "Init.h"
#include "eh_io.h"
#include "module.h"

/*#define TRACE_ROUTINES 1*/
/*#define DEBUGINIT 1     */
/* #define DEBUG          */
/* #define NO_ROM_ADDRESS */
/* #define DEBUGB         */

/*
 * Conditional compilation defines.
 */
#ifdef DRIVER16BIT
#define WINBODGEDCR2
#endif

/*
 * Local routines.
 */
static int      eh_run_diags(struct eh_softc *, int);
#ifdef LOOPBACK_TEST
static int      eh_loopback(struct eh_softc *, TestPacket *, u_char, u_char);
static int      lb3_failed(struct eh_softc *, NICRef);
#endif
static int      check_cable(struct eh_softc *);
static int      get_ether_address(int *, u_char *, int, int);
#ifdef DRIVER16BIT
static int      eh_memtest(struct eh_softc *, int, u_int *);
#else
static int      eh_memtest(struct eh_softc *, int, u_char *);
#endif
static void     eh_init_low(int, int, int, int);
#ifdef LOOPBACK_TEST
static void     build_tpkt(struct eh_softc *, TestPacket *);
#endif
static void     eh_setup_diags(struct eh_softc *, NICRef, u_char, u_char);
static void     eh_hwinit(struct eh_softc *);
static void     sel_coax_inter(struct eh_softc *);
static void     sel_tpi_inter(struct eh_softc *);
static void     claim_podule_interrupt(struct eh_softc *);
static u_char   check_adaptor(struct eh_softc *);
static u_char   get_adaptor_id(struct eh_softc *);

/*
 * External data.
 */
int             ehcnt = 0;
volatile int    pre_init = TRUE, pre_reset = FALSE;
char            eh_lasterr[80] = { 0 };
struct          eh_softc *eh_softc[MAX_NUM_SLOTS] = { 0 };

/*
 * Define array of expansion slots when Podule_ReadInfo isn't implemented.
 */
static const int sync_addresses[4] =
                      { (0x033C0000 + (0 << 14)),
                        (0x033C0000 + (1 << 14)),
                        (0x033C0000 + (2 << 14)),
                        (0x033C0000 + (3 << 14))
                      };

static const int memc_addresses[4] =
                      { (0x03000000 + (0 << 14)),
                        (0x03000000 + (1 << 14)),
                        (0x03000000 + (2 << 14)),
                        (0x03000000 + (3 << 14))
                      };

/*
 * Initialisation and diagnostics routines.
 */

void eh_init(void)
{
    int i, s = 0, card_type, unit, count;
    u_char buffer[16];
    _kernel_oserror *e;
    _kernel_swi_regs rin,rout;

    struct eh_softc *en;

#ifdef TRACE_ROUTINES
    printf("debug: eh_init irq:%x\n",(int) eh_irq_entry);
    fflush(stdout);
#endif

    /* Default stance */
    ehcnt = 0;

    /*
     * Test if 'i' key is being pressed during initialisation.
     * If so then do not initialise card.
     */
    rin.r[0] = OsByte_INKEY;
    rin.r[1] = 37 ^ 0xff;
    rin.r[2] = 0xff;
    _kernel_swi(XOS_Bit | OS_Byte, &rin, &rout);
    if (rout.r[2] == 0xff && rout.r[1] == 0xff)
    {
       return;
    }

    if (_kernel_swi(XOS_Bit | Podule_ReturnNumber, &rin, &rout) != NULL)
       return; /* No podule manager => no EtherLan */
    count = rout.r[0];
    if (count == 0)
       return; /* No podules => no EtherLan */

    for (i = 0; i < count; i++)
    {
       rin.r[2] = (int) buffer;
       rin.r[3] = i;
       e = _kernel_swi(XOS_Bit | Podule_ReadHeader, &rin, &rout);
       if (e == NULL)
       {
          card_type = (buffer[3] | (buffer[4] << 8));

          /* the acorn cards have different product codes that are mapped to i-cubed ones */
          switch (card_type)
          {
            case EH_ACORN_100:
              card_type = EH_TYPE_100;
              break;              /* Oh no, its going to crash, quick put on the break : DJB 1/8/96*/
            case EH_ACORN_200:
              card_type = EH_TYPE_200;
              break;
            case EH_ACORN_500:
              card_type = EH_TYPE_500;
              break;
            case EH_ACORN_600:
              card_type = EH_TYPE_600;
              break;
            case EH_ACORN_700:
              card_type = EH_TYPE_700;
              break;
          }

          if (card_type == EH_TYPE_100 ||
              card_type == EH_TYPE_200 ||
              card_type == EH_TYPE_500 ||
              card_type == EH_TYPE_600 ||
              card_type == EH_TYPE_700)
          {
#ifdef DEBUG
             printf("debug: slot %d, cardtype %x\n", i, card_type);
#endif
             s = ensure_irqs_off();                /* interrupts off for low level init */
             ehcnt++;
             unit = ehcnt - 1;
             eh_init_low (i, unit, 0, card_type);  /* init software structure for card. */
             en = eh_softc[unit];
             restore_irqs(s);
#if 0
             eh_reset_card(en);                    /* resets hardware.                  */
#endif                    
             eh_init_low (i, unit, 1, card_type);  /* init card hardware.               */

#ifdef DEBUG
             /* OSS 16 June 2001 Changed read CMOS to take a byte number 0..3 */
             printf("Virtual %x %x\n", virtual, eh_readcmos(en, 1));
#endif
             if (virtual)
             {
                /* if this interface also has a second virtual interface */
                ehcnt++;
                unit = ehcnt - 1;
                s = ensure_irqs_off();                /* interrupts off for low level init */
                eh_init_low (i, unit, 0, card_type);  /* init software structure for card. */
                restore_irqs(s);

                /* make the Ethernet address of the virtual card unit 0 with top bit of manufacturer's address set */
                en = eh_softc[unit]; /* make unit 1 have special address */
                en->eh_addr[3] = (en->eh_addr[3] | 0x80);
             }
          }
       }
    }

    if (ehcnt == 0)
    {
       return;
    }

    rin.r[0] = (int) "Inet$EhCount";
    rin.r[1] = (int) &ehcnt;
    rin.r[2] = sizeof(int);
    rin.r[3] = 0;
    rin.r[4] = VarType_Number;
    _kernel_swi(XOS_Bit | OS_SetVarVal, &rin, &rout);

    rin.r[0] = (int) "Inet$EtherType";
    rin.r[1] = (int) "eh0";
    rin.r[2] = strlen("eh0");
    rin.r[3] = 0;
    rin.r[4] = VarType_String;
    _kernel_swi(XOS_Bit | OS_SetVarVal, &rin, &rout);

    /* if pre_init is FALSE then we have not been loaded from an expansion card
     * therefore we can start up now, otherwise we must wait until all the
     * modules have been loaded from the card before allowing the driver to
     * be called
     */
    if (pre_init == FALSE)
       eh_postinit();

#ifdef TRACE_ROUTINES
    printf("debug: eh_init complete, pre_init:%x\n",pre_init);
    fflush(stdout);
#endif
} /* eh_init()          */


/*
 * Gets called after all modules been initialised.
 */
void eh_postinit(void)
{
   struct eh_softc *eh;
    _kernel_swi_regs rin,rout;
   int i;

#ifdef TRACE_ROUTINES
   printf("debug: eh_postinit\n");
   fflush(stdout);
#endif

   pre_init = FALSE;

   /*for (i = 0; i < ehcnt; i++)*/
   for (i = ehcnt-1; i > -1; i--)
   {
      eh = eh_softc[i];

      /* add callback to issue service call for each interface to tell everyone we are active */
      rin.r[0] = (int) eh_call_back;
      rin.r[1] = (int) eh->eh_dib;
      _kernel_swi(XOS_Bit | OS_AddCallBack, &rin, &rout);
#ifdef TRACE_ROUTINES
      printf("debug: callback r0:%x r1:%x\n",rin.r[0],rin.r[1]);
#endif

      /*
       * If RiscPC card then no loader to call.
       */
#ifdef WINBODGEDCR2
      if (eh->eh_cardtype == EH_TYPE_600)
      {
         NICRef nic;
         nic = eh->Chip;
         nic->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2);
#ifdef DEBUG
         printf("debug: modifying dcr in postinit\n");
         fflush(stdout);
#endif
      }
#endif
   }
} /* eh_postinit()      */


/*
 * Low priority podule card initialisation - first round with ints off
 * allocates memory for control structures; second round declares the driver
 * to the network interface code.
 */

void eh_init_low(int slot, int unit, int irqs_on, int card_type)
{
    int i;
    _kernel_oserror *e;

#ifdef TRACE_ROUTINES
    printf("debug: eh_init_low irqs:%d cardtype:%x unit:%x slot:%x\n",
        irqs_on, card_type, unit, slot);
    fflush(stdout);
#endif

    if (!irqs_on)
    {
        struct eh_softc *en;
        struct dib      *db;
        const char      *msg;
        int  *buf;
        int   infbuf[16];
        char  slottext[4];
        char *tp;
        _kernel_swi_regs rin, rout;

        /* Get some memory for the control structure for eh_softc */
        en = (struct eh_softc *) malloc(sizeof(*en));
        if (en != NULL)
        {
            memset ((char *) en, 0, sizeof(struct eh_softc));
            eh_softc[unit] = en;

#ifdef DEBUG
            printf("debug: eh_softc is at:%x\n", (int) en);
#endif

            /* Initialise the eh_softc structure.           */
            en->eh_cardtype = card_type;
            en->eh_unit = unit;
            en->eh_slot = slot;
            en->eh_imr_value = IMR_INIT_VALUE;
            en->buffer_pstart = TX_START;
            en->rcr_status = RCR_INIT_VALUE;
            en->eh_next_pkt = RX_START + 1;

            /* Set up description of location of the card */
            sprintf(slottext, "%d", slot);
            msg = eh_message((slot == 8) ? M3_NETWORK_SLOT
                                         : M2_EXPANSION_SLOT, slottext, NULL, NULL);
            tp  = (char *)malloc(strlen(msg) + 1 /* Terminator */);
            if (tp != NULL)
            {
                strcpy(tp, msg);
                en->eh_location = (u_char *) tp;
            }
            else
            {
                en->eh_location = NULL;
                sprintf(eh_lasterr, "eh_init_low: malloc tp fail (unit %d)", unit);
            }

            if (card_type == EH_TYPE_700)
            {
#ifdef DRIVER16BIT
                /* EtherLan700 motherboard i/f */
                rin.r[0] = Podule_ReadInfo_EASILogical;
                rin.r[1] = (int) infbuf;
                rin.r[2] = sizeof(infbuf);
                rin.r[3] = en->eh_slot;
                _kernel_swi(XOS_Bit | Podule_ReadInfo, &rin, &rout);

                en->eh_easi_base = infbuf[0];
                en->Chip = (NICRef) (en->eh_easi_base + EHCARD7_CHIP_OFFSET);
                en->page_reg = (u_char *) en->eh_easi_base;
                en->cntrl_reg = (u_char *) en->eh_easi_base + EHCARD7_CNTRL_OFFSET;
                en->cntrl_reg2 = (u_char *) en->eh_easi_base + EHCARD7_CNTRL_OFFSET2;
                en->rom = (u_char *) en->eh_easi_base;
                en->rom_page_size = ROM_PAGE_SIZE;
                en->dma_port = (u_int *) (en->eh_easi_base + EHCARD7_DMA_OFFSET);

                /* this card uses the same i/o routines as the 600 card */
                en->io_out = eh_io_out_6;
                en->io_hout = eh_io_hout_6;
                en->io_flushout = eh_flush_output_6;
#endif
            }
            else
            {
               if (card_type != EH_TYPE_600)
               {
                   rin.r[0] = Podule_ReadInfo_SyncBase | Podule_ReadInfo_MEMC;
                   rin.r[1] = (int) infbuf;
                   rin.r[2] = sizeof(infbuf);
                   rin.r[3] = en->eh_slot;
                   if (_kernel_swi(XOS_Bit | Podule_ReadInfo, &rin, &rout) != NULL)
                   {
                       /* Fallback to table for pre RISC OS 3.50 */
                       infbuf[0] = sync_addresses[en->eh_slot];
                       infbuf[1] = memc_addresses[en->eh_slot];
                   }

                   /* Adjust address from SyncBase to FastBase, feel the speed */
                   infbuf[0] -= 0x80000;

                   /* EtherLan100/200/500 */
                   en->Chip = (NICRef) (infbuf[1] + EHCARD_CHIP_OFFSET);
#ifdef DRIVER16BIT
                   en->dma_port = (u_int *) (infbuf[1] + EHCARD_DMA_OFFSET);
#else
                   en->dma_port = (u_char *) (infbuf[1] + EHCARD_DMA_OFFSET);
#endif
                   en->page_reg = (u_char *) (infbuf[0] + EHCARD_PAGEREG_OFFSET);
                   en->cntrl_reg = (u_char *) (infbuf[0] + EHCARD_CNTRL_OFFSET);
                   en->cntrl_reg2 = (u_char *) (infbuf[0] + EHCARD_CNTRL_OFFSET2);
                   en->rom = (u_char *) infbuf[0];
                   en->rom_page_size = ROM_PAGE_SIZE;
#ifdef DRIVER16BIT
                   en->io_out = eh_io_out_5;
                   en->io_hout = eh_io_hout_5;
                   en->io_flushout = eh_flush_output_5;
#endif
               }
               else
               {
                   /* EtherLan600 NIC */
                   rin.r[0] = Podule_ReadInfo_SyncBase | Podule_ReadInfo_ROMAddress;
                   rin.r[1] = (int) infbuf;
                   rin.r[2] = sizeof(infbuf);
                   rin.r[3] = en->eh_slot;
                   _kernel_swi(XOS_Bit | Podule_ReadInfo, &rin, &rout);

                   en->Chip = (NICRef) (infbuf[0] + EHCARD6_CHIP_OFFSET);
                   en->rom = (u_char *) infbuf[1];
                   en->page_reg = (u_char *) (infbuf[0] + EHCARD6_PAGEREG_OFFSET);
                   en->cntrl_reg = (u_char *) (infbuf[0] + EHCARD6_CNTRL_OFFSET);
                   en->rom_page_size = ROM_600_PAGE_SIZE;
#ifdef DRIVER16BIT
                   en->dma_port = (u_int *) (infbuf[0] + EHCARD6_DMA_OFFSET);
                   en->io_out = eh_io_out_6;
                   en->io_hout = eh_io_hout_6;
                   en->io_flushout = eh_flush_output_6;
#endif
               }
            }
            for (i = 0; i < MAXTXQ; ++i)
            {
                en->TxqPool[i].TxNext = (i < (MAXTXQ - 1)) ?
                                         &(en->TxqPool[(i + 1)]) : (TxqRef)NULL;
                en->TxqPool[i].TxStartPage = (i * PAGES_PER_TX) + en->buffer_pstart;
            }
            en->TxqFree = en->TxqPool;
            en->TxPending = (TxqRef)NULL;

#ifdef DEBUG
            printf("debug: TxqPool is at:%x\n", (int) en->TxqPool);
#endif

            /* find out base address of CMOS RAM */
            /* OSS 16 June 2001 Had to move this earlier because eh_hwinit()
               now needs the cmos base to be able to get the adaptor type
               of an E600 card */
            rin.r[3] = slot;
            _kernel_swi(XOS_Bit | Podule_HardwareAddress, &rin, &rout);
            en->eh_cmosbase = rout.r[3] & Podule_CMOSAddressANDMask;

            /* if bit zero of the cmos is set then start this as a virtual interface */
            /* OSS 16 June 2001 Changed read CMOS to take a byte number 0..3 */
            /* OSS 4.51 20 Nov 2002 Read virtual INSIDE eh_init_low
               so that the dib flags can clear the bit for being
               able to filter multicasts. */
            if (eh_readcmos(en, 1) & 0x01)
               virtual = TRUE;
            else
               virtual = FALSE;

            /* Initialise the hardware.                      */
            eh_reset_card(en);
            eh_hwinit(en);

#ifdef NO_ROM_ADDRESS
            en->eh_addr[0] = 0x00;
            en->eh_addr[1] = 0xc0;
            en->eh_addr[2] = 0x32;
            en->eh_addr[3] = 0x10;
            en->eh_addr[4] = 0x00;
            en->eh_addr[5] = 0x00;
            en->eh_rev = CURRENT_HW_REV;
#else
           /*
            * Read the Ethernet hardware address.
            * Try to get it from RISC OS first if 700 card
            */
            if (card_type == EH_TYPE_700)
            {
                char addrbuf[8];

                rin.r[0] = Podule_ReadInfo_EthernetAddress;
                rin.r[1] = (int) addrbuf;
                rin.r[2] = sizeof(addrbuf);
                rin.r[3] = en->eh_slot;
                e = _kernel_swi(XOS_Bit | Podule_ReadInfo, &rin, &rout);
                for (i = 2; i < 8; i++)
                    en->eh_addr[8-i-1] = addrbuf[i-2]; /* Reverse endianness too */
#ifdef DEBUG
                printf("debug: e:%x i:%x\n", (int) e, i);
#endif
            }
            else
                e = (_kernel_oserror *) 0xff; /* Force a look through the chunks */

            if (e != NULL)
            {
                buf = malloc(en->rom_page_size*2);
                if (buf != NULL)
                {
                    if (en->eh_cardtype == EH_TYPE_700)
                    {
                       rin.r[0] = 0x00;  /* chunk number */
                       rin.r[2] = (int) buf;
                       rin.r[3] = en->eh_slot;
                       _kernel_swi(XOS_Bit | Podule_ReadChunk, &rin, &rout);
                    }
                    else
                    {
                        if (en->eh_cardtype == EH_TYPE_600)
                        {
                           rin.r[0] = 0x00;  /* offset from base of podule's address space */
                           rin.r[1] = en->rom_page_size;
                           rin.r[2] = (int) buf;
                           rin.r[3] = en->eh_slot;
                           _kernel_swi(XOS_Bit | Podule_RawRead, &rin, &rout);
                        }
                        else
                        {
                           eh_set_rom_page(en, 0);
                           for (i = 0; i < en->rom_page_size; i++)
                           {
                              *((u_char *) buf + i) = *(en->rom + i*4);
                           }
                           eh_set_rom_page(en, en->rom_page_size);
                           for (i = 0; i < en->rom_page_size; i++)
                           {
                              *((u_char *) buf + i + en->rom_page_size) = *(en->rom + i*4);
                           }
                        }
                    }

                    if (get_ether_address(buf, (u_char *) en->eh_addr, 2*en->rom_page_size, en->eh_cardtype) != TRUE)
                    {
                       free(buf);
                       sprintf(eh_lasterr, "eh_init_low: no MAC address for slot %d (unit %d)", en->eh_slot, unit);
                       en->eh_flags |= EH_FAULTY;
                       return;
                    }
                    free(buf);
                }
                else
                    sprintf(eh_lasterr, "eh_init_low: out of memory (unit %d)", unit);
            }
#endif
            /* set up driver information block for each device */
            db = (DibRef) malloc(sizeof(Dib));
            if (db != NULL)
            {
                memset ((char *) db, 0, sizeof(Dib));
                db->dib_swibase = EtherH_00;
                db->dib_name = (u_char *) "eh";
                db->dib_unit = en->eh_unit;
                db->dib_address = (u_char *) en->eh_addr;
                db->dib_module = (u_char *) "EtherH";
                db->dib_location = en->eh_location;
                db->dib_slot.sl_slotid = slot;

                /* OSS 4.51 20 Nov 2002 Sort out flags to be correct for
                   both virtual (no multicast filtering) and the second
                   virtual interface. This code is the same as that in
                   eh_inquire() to ask directly. */
                db->dib_inquire = INQUIRE_FLAGS;
                if (virtual)
                {
                    db->dib_inquire &= ~INQ_FILTERMCAST;
                    if (unit > 0)
                    {
                        db->dib_inquire |= INQ_VIRTUAL | INQ_SWVIRTUAL;
                    }
                }
                en->eh_dib = db;
#ifdef DEBUG
                printf("debug: dib is at:%x\n",(int) db);
#endif

            }
            else
                sprintf(eh_lasterr, "eh_init_low: unable to claim memory for dib (unit %d)", unit);
        }
        else
            sprintf(eh_lasterr, "eh_init_low: unable to claim memory for interface data (unit %d)", unit);
    }
    else
    {
        struct eh_softc *en;

#ifdef TRACE_ROUTINES
        printf("debug: irqs on, unit:%x ehcnt:%x\n",unit, ehcnt);
#endif
        if (unit < 0 || unit >= ehcnt)
            return;
        else
            en = eh_softc[unit];

        /* Run the diagnostics.                 */
        eh_post(en, 0);

#ifdef TRACE_ROUTINES
        printf("debug: post complete\n");
#endif
        /*
         * Keep the NIC interrupts masked off and chip reset.
         */
        en->Chip->imr = 0x00;
        en->Chip->command = 0x21;
#ifdef WINBODGEDCR2
        if (en->eh_cardtype == EH_TYPE_600)
        {
           if (pre_init == TRUE)
              en->Chip->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2) | LAS;
           else
              en->Chip->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2);
#ifdef DEBUG
           printf("debug: modifying dcr at the end of init_low\n");
#endif
        }
#endif
        /* Claim interrupts */
        claim_podule_interrupt(en);

#ifdef DMA
        /* setup dma stuff */
        en->eh_dma_busy = FALSE;
        en->eh_rx_pending = FALSE;

        for (i = 0; i < MAXDMA; i++)
        {
            en->eh_dc[i].en = NULL;
            en->eh_dc[i].sp = (ScatterRef) malloc(sizeof(ScatterRef) * 16);
        }
        dma_register(en);
#endif
    }

} /* eh_init_low()              */


/*
 * this needs to be changed!
 */

static void claim_podule_interrupt(struct eh_softc *en)
{
    int infbuf[4];
    u_char  *iomd_imr;
    u_char  mask;
    _kernel_oserror *e;
    _kernel_swi_regs rin, rout;

#ifdef DEBUGB
    printf("debug: claim interrupt for slot %d\n", en->eh_slot);
    fflush(stdout);
#endif

    /*
     * Determine Podule info.
     */
    rin.r[0] = Podule_ReadInfo_DMAPrimary |
               Podule_ReadInfo_IntMask | Podule_ReadInfo_IntValue | Podule_ReadInfo_IntDeviceVector;
    rin.r[1] = (int) infbuf;
    rin.r[2] = sizeof(infbuf);
    rin.r[3] = en->eh_slot;
    e = _kernel_swi(XOS_Bit | Podule_ReadInfo, &rin, &rout);
    if (e == NULL)
    {
       en->eh_primary_dma = infbuf[0];
       iomd_imr = (u_char *) infbuf[1];
       mask = (u_char) infbuf[2];
       en->eh_deviceno = infbuf[3];
#ifdef DEBUG
       printf("debug: PoduleReadInfo worked OK! iomd_imr:%x mask:%x primary_dma:%x devno:%x\n",
              (int) iomd_imr, (int) mask, (int) en->eh_primary_dma, en->eh_deviceno);
#endif
    }
    else
    {
       /* Pre Podule_ReadInfo means pre RISC OS 3.50, use hardwired IOC knowledge */
       iomd_imr = (u_char *) (IOC + IOCIRQMSKB);
       mask = podule_IRQ_bit;
       en->eh_deviceno = Podule_DevNo;
#ifdef DEBUG
       printf("debug: iomd imr = %x, mask = %x\n", (int) iomd_imr, (int) mask);
#endif
    }

    /*
     * Hit interrupt mask register.
     * This is required for the network slot card in order to make sure the interrupts
     * are generated
     */
#ifdef DEBUG
    printf("debug: hitting interrupt mask register in IOMD\n");
#endif

    mask |= *iomd_imr;
    *iomd_imr = mask;

    if (en->eh_deviceno)
    {
       rin.r[0] = en->eh_deviceno; /* claim interrupts for this card */
       rin.r[1] = (int) eh_irq_entry;
       rin.r[2] = (int) module_wsp;
       rin.r[3] = (int) en->cntrl_reg;
       rin.r[4] = (int) EH_INTR_STAT;

       e = _kernel_swi(XOS_Bit | OS_ClaimDeviceVector, &rin, &rout);

#ifdef DEBUG
       printf("debug: claimed device vector entry at:%x wsp:%x interrupt status at:%x mask:%x device:%x, e:%x\n",(int) eh_irq_entry,
               (int)  module_wsp, (int) en->cntrl_reg, (int) EH_INTR_STAT, (int) en->eh_deviceno, (int) e);
#endif
    }
    else
       sprintf(eh_lasterr, "claim_podule_interrupt: unknown or bad device number (unit %d)", en->eh_unit);

} /* claim_podule_interrupt()               */


/*
 * Give the Ethernet card a soft reset.
 *
 */
void eh_reset_card(struct eh_softc *en)
{
    NICRef nic = en->Chip;

#ifdef TRACE_ROUTINES
    printf("debug: eh_reset_card slot:%d with:%x\n", en->eh_slot, CMD_INIT_VALUE);
    fflush(stdout);
#endif

    /* Assert software reset command.           */
    nic->command = CMD_INIT_VALUE;

    /* Wait for it to take effect.              */
    MICRODELAY(NIC_RESET_PERIOD);

#ifdef DEBUG
    printf("debug: eh_reset_card reset\n");
    fflush(stdout);
#endif

    /*
     * Clear all bits in the ISR and the IMR.
     *
     */
#ifdef DEBUG
    printf("debug: eh_reset_card setup isr, imr\n");
    fflush(stdout);
#endif
    nic->isr = 0xff;
    nic->imr = 0x00;

} /* eh_reset_card()            */


/*
 * Run power on self test for a card.
 */

int eh_post(struct eh_softc *en, int loopback_only)
{
    int retc;

#ifdef TRACE_ROUTINES
    printf("debug: eh_post loopback:%x en->eh_flags:%x\n",loopback_only,en->eh_flags);
    fflush(stdout);
#endif

    /* Do not run the tests if fault found.     */
    /* if ((en->eh_flags & EH_FAULTY)) return(0); */

    /* Run the diagnostic tests.                */
    retc = eh_run_diags(en, loopback_only);
    if (!retc &&
        !(en->eh_flags & EH_RECOVERABLE_ERROR))
    {
#ifdef DEBUGINIT
        printf("debug: interface is faulty and is not recoverable flags:%x retc:%x\n",en->eh_flags,retc);
#endif
        en->eh_flags |= EH_FAULTY;
    }
    else
       /* setup the NIC ready for normal operation */
       eh_setup(en);

    /* Return status.                           */
    return(retc);

} /* int eh_post()      */


/*
 * eh_run_diags - run a set of internal diagnostics. return 0 if
 * something failed, else 1.
 */

static int eh_run_diags(struct eh_softc *en, int loopback_only)
{
    register int i;
    u_char *memc1a = (u_char *) MEMC1a;
    _kernel_swi_regs regs;
    _kernel_oserror * error;

#ifdef LOOPBACK_TEST
    TestPacket lback_data;
    static int lb_sequence[] = { LOOPBACK1, LOOPBACK2, LOOPBACK3 };
#endif

#ifdef TRACE_ROUTINES
    printf("debug: eh_run_diags loopback:%x\n",loopback_only);
    fflush(stdout);
#endif

    /* first check to see if this machine is fitted with MEMC1a */
    /* OSS 23 June 2001 Castle commented this test out for Kinetic
       cards on RISC OS 4, so put the test back in and make it
       dependent on RISC OS 3.11 or earlier */

    regs.r[0] = OsByte_OSVersionIdentifier;
    regs.r[1] = 0;
    regs.r[2] = 255;
    error = _kernel_swi(OS_Byte, &regs, &regs);
    if (error != NULL)
    {
      en->eh_flags &= ~EH_RECOVERABLE_ERROR;
      sprintf(eh_lasterr, "eh_run_diags: %s (unit %d)", error->errmess, en->eh_unit);
      return(0);
    }

    /* OSS 23 June 2001  &A0 Arthur 1.20    &A1 RISC OS 2.00
       &A2 RISC OS 2.01  &A3 RISC OS 3.00   &A4 RISC OS 3.10 & 3.11
       &A5 RISC OS 3.5   &A6 RISC OS 3.6 & 2875 STB
       &A7 RISC OS 3.7 & 3875 & 4000 STB */

    if (regs.r[1] <= 0xA4)
    {
        if (!(*memc1a & 1))
        {
          en->eh_flags &= ~EH_RECOVERABLE_ERROR;
          sprintf(eh_lasterr, "eh_run_diags: requires MEMC1a (unit %d)", en->eh_unit);
          return(0);
        }
    }

    if (!loopback_only)
    {
#ifdef DRIVER16BIT
        u_int pattern[PAT_LEN];
#else
        u_char pattern[PAT_LEN];
#endif

        /* Build the test pattern.                      */
        for (i = 0; i < (PAT_MID - 1); ++i)
        {
            pattern[i] = O(i);
            pattern[i + PAT_MID] = Z(i);
        }
        pattern[PAT_MID - 1] = 0;
        pattern[PAT_LEN - 1] = DATA_MASK;

        /* Configure the NIC in an appropriate mode.    */
        /*
         * bring the NIC back to page 0, alive & kicking
         */
        eh_setup_diags(en, en->Chip, LOOPBACK1, 0);

        /* Run the test for all pages.                  */
        for (i = en->buffer_pstart; i < (NIC_BUFFER / NIC_PAGE); ++i)
        {
            if (!eh_memtest(en, i, pattern)) return(0);
        }
    }

    /*
     * Run loopback tests - make sure the NIC is in some
     * sensible state, build the test packet & copy it
     * into on-card RAM.
     */
#ifdef LOOPBACK_TEST
    eh_setup_diags(en, en->Chip, LOOPBACK1, 0);
    build_tpkt(en, &lback_data);
#endif

    /*
     * For a combo interface, take user preferences into account
     * otherwise when 'auto' try to deduce.
     */
    if (en->eh_interface == INTERFACE_COMBO)
    {
       switch (eh_readcmos(en, 2))
       {
          case 'T':
             sel_tpi_inter(en);
             en->eh_interface = INTERFACE_10BASET;
             break;

          case '2':
             sel_coax_inter(en);
             en->eh_interface = INTERFACE_10BASE2;
             break;

          default:
             /*
              * Set 10BASET interface and check for goodlink pulses.
              */
             sel_tpi_inter(en);
             MICRODELAY(100000);
             if (!get_goodlink(en))
             {
#ifdef DEBUG
                printf("debug: tpi interface check failed (no goodlinks) !!!\n");
#endif       
                sel_coax_inter(en);
                en->eh_interface = INTERFACE_10BASE2;
             }
             else
             {
                en->eh_interface = INTERFACE_10BASET;
             }
             break;
       }
    }

    /* Run a cable check before trying loopback tests.  */
    if (!check_cable(en))
    {
#ifdef DEBUGINIT
       printf("debug: cable check failed, is recoverable\n");
#endif
       en->eh_flags |= EH_RECOVERABLE_ERROR;
       if (en->eh_interface == INTERFACE_MICRO_T)
          en->eh_interface = INTERFACE_NONE;
       return(0);
    }
    else
       en->eh_flags &= ~EH_RECOVERABLE_ERROR;

#ifdef LOOPBACK_TEST
    for (i = 0; i < (sizeof(lb_sequence) / sizeof(lb_sequence[0])); ++i)
    {
        register u_int mode = lb_sequence[i];

        if (!eh_loopback(en, &lback_data, mode, 0)) return(0);

#ifdef TEST_CRC_CALC
        if (!eh_loopback(en, &lback_data, mode, 1)) return(0);
#endif
    }
#endif

    /*
     * All tests passed - return OK status.
     */
    return(1);

} /* eh_run_diags()             */



/*
 * Run a memory test on the given page.
 */

#ifdef DRIVER16BIT
static int eh_memtest(struct eh_softc *en, int page, u_int *pattern)
#else
static int eh_memtest(struct eh_softc *en, int page, u_char *pattern)
#endif
{
    int         i, j;
#ifdef DRIVER16BIT
    u_int       nextbyte;
    int         length = NIC_PAGE >> 1;
#else
    u_char      nextbyte;
    int         length = NIC_PAGE;
#endif
    NICRef      nic = en->Chip;

    /*
     * Write the pattern into RAM.
     */
    nic->rbcr0 = ~0;
    nic->command = START_DMA(DMA_READ);

    MICRODELAY(1);
    nic->command = START_DMA(DMA_ABORT);

    nic->rsar0 = 0;
    nic->rsar1 = page;
    nic->rbcr0 = NIC_PAGE;
    nic->rbcr1 = NIC_PAGE >> 8;
    nic->command = START_DMA(DMA_WRITE);
    for (i = 0, j = 0; i < length; ++i)
    {
#ifdef DRIVER16BIT
        if (en->eh_cardtype == EH_TYPE_500)
           *en->dma_port = pattern[j] << 16; /* this is for 500 series cards*/
        else
           *en->dma_port = pattern[j];
#else
        *en->dma_port = pattern[j];
#endif

        if (++j == PAT_LEN) j = 0;
    }

    if (!(nic->isr & RDC))
    {
        sprintf(eh_lasterr, "eh_memtest: remote write has not completed (unit %d)", en->eh_unit);
        return(0);
    }
    else
        nic->isr = RDC;

    /*
     * Now do the read & check.
     */
    nic->rsar0 = 0;
    nic->rsar1 = page;
    nic->rbcr0 = NIC_PAGE;
    nic->rbcr1 = NIC_PAGE >> 8;
    nic->command = START_DMA(DMA_READ);
    for (i = 0, j = 0; i < length; ++i)
    {
        if ((nextbyte = (*en->dma_port & DATA_MASK)) != pattern[j])
        {
            sprintf(eh_lasterr,
                    "eh_memtest: RAM failure page %d, byte %d, R%x/W%x (unit %d)",
                    page, i, nextbyte, pattern[j], en->eh_unit);
            return(0);
        }

        if (++j == PAT_LEN) j = 0;
    }

    /* Finished OK.                             */
    return(1);

} /* eh_memtest()               */


/*
 * attempt to send test packet out in non-loopback mode, use
 * transmit status to work out whether or not the cabling is OK
 */

static int check_cable(struct eh_softc *en)
{
    NICRef nic = en->Chip;
    int i, unit = en->eh_unit;
#ifdef DRIVER16BIT
    u_int bytebuf = 0;
#endif
    char *errortype = NULL;
    TestPacket lback_data;
    u_char *dptr = (u_char *) (&lback_data);

#ifdef TRACE_ROUTINES
    printf("debug: check_cable\n");
    fflush(stdout);
#endif

    /*
     * make sure the NIC is stopped, set it up, then mask out
     * interrupts and start it running
     */

#ifdef TRACE_ROUTINES
    printf("debug: setup regs\n");
    fflush(stdout);
#endif

    nic->command = SEL_PAGE(0, NIC_RUNNING);
    nic->tcr = TCR_INIT_VALUE | LOOP_MODE(LIVE_NET);
    nic->imr = 0x00;

    nic->rbcr0 = ~0;
    nic->command = START_DMA(DMA_READ);

    MICRODELAY(1);
    nic->command = START_DMA(DMA_ABORT);

#ifdef TRACE_ROUTINES
    printf("debug: setup rsar\n");
    fflush(stdout);
#endif

    /*
     * The NIC is loaded using byte wide transfers, but can only
     * read byte wide for loopback testing.
     */
    nic->rsar0 = 0;
    nic->rsar1 = en->buffer_pstart;
    nic->rbcr0 = TESTP_LEN;
    nic->rbcr1 = TESTP_LEN >> 8;
    nic->command = START_DMA(DMA_WRITE);

#ifdef TRACE_ROUTINES
    printf("debug: load card\n");
    fflush(stdout);
#endif

#ifdef DRIVER16BIT
#ifdef TRACE_ROUTINES
    printf("debug: load header\n");
    fflush(stdout);
#endif
    (en->io_hout)(en->eh_addr, en->eh_addr, 0x00, en->dma_port);
#ifdef TRACE_ROUTINES
    printf("debug: load data\n");
    fflush(stdout);
#endif
    (en->io_out)(dptr, en->dma_port, (TESTP_LEN-PACK_HDR_LEN), &bytebuf);
#ifdef TRACE_ROUTINES
    printf("debug: flush odd bytes\n");
    fflush(stdout);
#endif
    /* Flush any odd bytes remaining */
    (en->io_flushout)(en->dma_port, &bytebuf);
#else
    eh_io_out(dptr, en->dma_port, TESTP_LEN);
#endif

#ifdef TRACE_ROUTINES
    printf("debug: check rdc\n");
    fflush(stdout);
#endif

    if (!(nic->isr & RDC))
    {
       /*
        * this is not yet a fatal error - give it
        * a chance to recover then try again
        */
        MICRODELAY(RDC_RECOVER_PERIOD);
    }

    if (!(nic->isr & RDC))
    {
        sprintf(eh_lasterr, "Unit %d: remote DMA failure\n", en->eh_unit);
#ifdef TRACE_ROUTINES
        printf("debug: remote dma failed\n");
        fflush(stdout);
#endif
        return(0);
    }
    else
    {
#ifdef TRACE_ROUTINES
        printf("debug: ack dma complete\n");
        fflush(stdout);
#endif
        /* Acknowledge the DMA completion.              */
        nic->isr = RDC;
    }
#ifdef TRACE_ROUTINES
    printf("debug: start dma tx\n");
    fflush(stdout);
#endif

    nic->tpsr = en->buffer_pstart;
    nic->tbcr0 = TESTP_LEN;
    nic->tbcr1 = TESTP_LEN >> 8;

    nic->command = START_DMA(DMA_IDLE) | TXP;
#ifdef TRACE_ROUTINES
    printf("debug: start tx cctimeo:%x\n", CC_TIMEO);
#endif

    /* wait until the packet is transmitted */
    for (i = 0; i < CC_TIMEO; ++i)
    {
        if ((nic->isr & PTX) | (nic->isr & TXE))
            break;

        MICRODELAY(1000000 / HZ);
    }

#ifdef TRACE_ROUTINES
    printf("debug: done tx cctimeo:%x tsr:%x isr:%x ncr:%x\n", CC_TIMEO, nic->tsr, nic->isr, nic->ncr);
#endif

    if (!(nic->tsr & TXOK))
        errortype = "connected";

    if ((nic->tsr & ABT) | ((nic->tsr & COL) && (nic->ncr > EXCESSIVE_COLL)))
       if (!(nic->tsr & CRS))
           errortype = "terminated";

    if (errortype)
    {
#ifdef DEBUGINIT
        printf("debug: cable fault\n");
#endif
        sprintf(eh_lasterr, "check_cable: cable is not %s (unit %d)\n",
                            errortype, unit);
        return(0);
    }
    else
        return(1);

} /* check_cable()              */


/*
 * eh_setup - initialise the NIC, but do not bring it up onto the network.
 * returns <> 0 if all OK, 0 if hardware determined to be faulty.
 */

int eh_setup(struct eh_softc *en)
{
    int i;
    NICRef nic = en->Chip;

#ifdef DEBUGINIT
    printf("debug: eh_setup unit:%d\n",en->eh_unit);
    fflush(stdout);
#endif

    /* Initialise the command register.                 */
    nic->command = CMD_INIT_VALUE;

    /* Wait for it to take effect.              */
    for (i = 0; i < RST_DELAY && (nic->isr & RST) == 0; i++)
    {
        MICRODELAY(1);
    }

    /* If RST flag in ISR was not set then      */
    /* flag error and finish.                   */
    if (i == RST_DELAY)
    {
#ifdef DEBUGINIT
        printf("debug: rst flag not set, interface is faulty\n");
#endif

        en->eh_flags |= EH_FAULTY;
        return(0);
    }

    /*
     * Set up the Data Configuration Register:
     *
     * 8-bit data transfers for 8-bit cards,
     * 16-bit data transfers for 16-bit cards,
     * normal operation,
     * auto-initialise remote,
     * fifo threshold of 4 bytes (2 words).
     */

#ifdef DRIVER16BIT
#ifdef WINBODGEDCR2
    if (en->eh_cardtype == EH_TYPE_600)
        nic->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2) | LAS;
    else
        nic->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2);
#else
    nic->dcr = DCR_INIT_VALUE | FIFO_THRESH(WORD_THRESH2);
#endif
#else
    nic->dcr = DCR_INIT_VALUE | FIFO_THRESH(BYTE_THRESH4);
#endif

    /* Clear remote byte count registers.               */
    nic->rbcr0 = nic->rbcr1 = 0;

    /*
     * Set up the Receive Configuration Register:
     *
     *
     */
    nic->rcr = en->rcr_status;

    /* Put the NIC into loopback mode.                  */
    nic->tcr = TCR_INIT_VALUE | LOOP_MODE(LOOPBACK1);

    /* Set up the receive buffer ring.                  */
    nic->bnry = RX_START;

    /* changed from RX_START 8/9/97 GS */

    nic->pstart = RX_START + 1;
    nic->pstop = RX_END;

#ifdef DEBUG
    printf("init: RX_START:%x RX_END:%x TX_START:%x\n", RX_START, RX_END, TX_START);
#endif

    /*
     * Clear all bits in the ISR, then set up the IMR.
     *
     * Interrupts required:
     *
     * packet received,
     * packet transmitted,
     * receive error,
     * transmit error,
     * overwrite warning,
     * counter overflow.
     *
     * NOTE: write clear value to ISR twice to ensure all ints cleared!!!
     */
    nic->isr = 0xff;
    nic->isr = 0xff;
    nic->imr = IMR_INIT_VALUE;

    /* Select page 1 & set physical address.                    */
    /* This is bodged here for bug found in MXIC controller.    */
    /* Should be able to set up physical address regs any time. */
    /* But if done while activity on the network it screws up.  */
    nic->command = SEL_PAGE(1, NIC_STOPPED);

#ifdef DEBUGINIT
    printf("debug: Setup ethernet address\n");
#endif
    nic->par0 = en->eh_addr[0];
    nic->par1 = en->eh_addr[1];
    nic->par2 = en->eh_addr[2];
    nic->par3 = en->eh_addr[3];
    nic->par4 = en->eh_addr[4];
    nic->par5 = en->eh_addr[5];

    /* Set the multicast hashing table (accept all packets when enabled). */
    /* OSS 4.51 20 Nov 2002 Initialise multicast address registers to zero,
       there is no point an interface with no frame filters receiving
       multicasts only to have to discard them. Also this setup to zero
       is required for reference counting and filtering later to work
       properly. */
    nic->mar0 = nic->mar1 = nic->mar2 = nic->mar3 = 0x00;
    nic->mar4 = nic->mar5 = nic->mar6 = nic->mar7 = 0x00;

    /* 23 June 2001 OSS Clear out the multicast reference counts */
    /* Note that by the time the chip is running the multicast
       registers will have been set to 0 */

    for (i = 0; i < MAR_BITS; i++)
    {
        en->mar_refcount[i] = 0;
    }

    /* Set the current page register for remote DMA.            */
    nic->curr = RX_START + 1;

    /* update the eh struct to indicate where next packet will be */
    en->eh_next_pkt = RX_START + 1;

    /* Put the NIC back to page 0.                              */
    nic->command = SEL_PAGE(0, NIC_STOPPED);

    /* All done OK.                                             */
#ifdef DEBUGB
    printf("debug: eh_setup ok\n");
    fflush(stdout);
#endif

    return(1);

} /* eh_setup()         */


static int get_ether_address(int *buf, u_char *ether_address, int buf_size, int cardtype)
{
   int       i, codebase, offset;
   char     *description;
   struct {
      u_char type;
      int    length;
      int    base;
   } chunk_dir;

#ifdef TRACE_ROUTINES
   printf("debug: get_ether_address\n");
   fflush(stdout);
#endif

   if (cardtype == EH_TYPE_700)
   {
       chunk_dir.length = buf_size;
       description = (char *) buf;
   }
   else
   {
       /* Get first chunk directory                         */
       chunk_dir.type = (u_char) buf[4];
       if (cardtype != EH_TYPE_600 && chunk_dir.type != OSType_Loader)
       {
           /* printf("debug: First chunk not loader !!\n");    */
           return FALSE;
       }

       if (chunk_dir.type == OSType_Loader)
       {
          chunk_dir.length = buf[4] >> 8;
          chunk_dir.base = buf[5];
          codebase = chunk_dir.base + chunk_dir.length;
       }
       else
       {
          codebase = 16;
       }

       offset = 0;
       /* Search for description chunk.                             */
       do {
          chunk_dir.type = (u_char) buf[(codebase + offset)/4];
          chunk_dir.length = buf[(codebase + offset)/4] >> 8;
          chunk_dir.base = buf[(codebase + offset + 4)/4];
          offset += 8;
       } while (chunk_dir.type != DeviceType_Description && (codebase + offset) < buf_size);

       if ((codebase + offset) == buf_size)
       {
           /* printf("Description chunk not found !!\n");                      */
           return FALSE;
       }

       description = (char *) buf + chunk_dir.base + codebase;
   }

   for (i = 0; i < chunk_dir.length && description[i] != '('; i++)
      ;

   if (i == chunk_dir.length)
   {
/*     printf("Ethernet address not found in description string !!\n"); */
       return FALSE;
   }

   description += i + 1;
   for (i = 0; i < HW_ADDR_LEN; i++)
   {
      ether_address[i] = (u_char) strtol(description, NULL, 16);
      description += 3;
   }

   return TRUE;

} /* get_ether_address()        */


/******************************************************************
 *
 * Start of PROM handling and card dependent control routines.
 *
 ******************************************************************/

/*
 * Initialise Ethernet card:-
 *
 *      disable interrupts,
 *      read adaptor ID,
 *      select 10 BaseT or 10 Base2 interface,
 *      enable ROM page register writes.
 *
 */

static void eh_hwinit(struct eh_softc *en)
{
   u_char temp;
   NICRef nic = en->Chip;
   _kernel_swi_regs rin,rout;

#ifdef TRACE_ROUTINES
    printf("debug: eh_hwinit\n");
    fflush(stdout);
#endif

   switch (en->eh_cardtype)
   {
#ifdef DRIVER8BIT
      case EH_TYPE_200:
         /* Clear first control register.                     */
         nulldev(*en->cntrl_reg);             /* Read first   */
         *en->cntrl_reg = 0;
         en->control_reg = 0;

         /* Clear second control register.                    */
         *en->cntrl_reg = 0;
         en->control_reg2 = 0;

         /* Check adaptor ID.                                 */
         if (check_adaptor(en) == FALSE)
         {
            printf("%s\n", eh_message(M1_WARNING_UK_MAU, NULL, NULL, NULL));
         }

         /* Read control register.                            */
         nulldev(*en->cntrl_reg);
         break;
#endif

      case EH_TYPE_600:
         /*
          * For RiscPC card set Mode Control Register A in AT/Lantic.
          */
#ifdef TRACE_ROUTINES
         printf("debug: eh_hwinit: about to set mode control register\n");
         fflush(stdout);
#endif

         temp = nic->mcra;
         nic->mcra = EH6_MCRA;

#ifdef TRACE_ROUTINES
         printf("debug: eh_hwinit: mode control register set\n");
         fflush(stdout);
#endif
         /* Fall through */
         
      case EH_TYPE_100:
      case EH_TYPE_500:
      case EH_TYPE_700:
         /* Clear first control register.                     */
         nulldev(*en->cntrl_reg);             /* Read first   */
         *en->cntrl_reg = 0;
         en->control_reg = 0;

#ifdef TRACE_ROUTINES
         printf("debug: eh_hwinit: now check adaptor id\n");
         fflush(stdout);
#endif

         /* Check adaptor ID.                                 */
         if (check_adaptor(en) == FALSE)
         {
            printf("%s\n", eh_message(M0_WARNING_UK_INTERFACE, NULL, NULL, NULL));
         }

         rin.r[0] = Podule_Speed_TypeA;
         rin.r[3] = en->eh_slot;
         _kernel_swi(XOS_Bit | Podule_SetSpeed, &rin, &rout);
#ifdef DEBUG
         if (rout.r[0] != Podule_Speed_TypeA)
            printf("debug: I dont think Podule_SetSpeed worked (r0 = %d) !!\n", rout.r[0]);
         else
            printf("debug: Podule_SetSpeed worked!\n");
#endif            

         break;
   }

#ifdef TRACE_ROUTINES
   printf("debug: eh_hwinit done\n");
   fflush(stdout);
#endif

} /* eh_hwinit()                */


/*
 *
 */

static u_char check_adaptor(struct eh_softc *en)
{
   int id = get_adaptor_id(en);

#ifdef TRACE_ROUTINES
   printf("debug: check_adaptor id:%x\n",id);
   fflush(stdout);
#endif

   en->eh_interface = id;

   /* Enable appropriate adaptor interface.             */
   /* 10BASET=5 10BASE2=3 MICRO_T=11 MICRO_2=10 COMBO=9 EH_NOMAU=1<<5   */
   switch(id)
   {
      /* If twisted pair adapter then enable twisted    */
      /* interface.                                     */
      case (INTERFACE_10BASET):
      case (INTERFACE_MICRO_T):
         sel_tpi_inter(en);
         en->eh_flags &= ~EH_NOMAU;
         break;

      /* If cheapernet adapter then enable cheapernet   */
      /* interface.                                     */
      case (INTERFACE_10BASE2):
      case (INTERFACE_MICRO_2):
         sel_coax_inter(en);
         en->eh_flags &= ~EH_NOMAU;
         break;

      /* If combo adapter then enable twisted           */
      /* interface.                                     */
      case (INTERFACE_COMBO):
         sel_tpi_inter(en);
         en->eh_flags &= ~EH_NOMAU;
         break;

      default:
         sprintf(eh_lasterr, "check_adaptor: unknown or no MAU adaptor connected (unit %d)", en->eh_unit);
         en->eh_flags |= EH_NOMAU;
         return FALSE;
   }
   return TRUE;

} /* check_adaptor()            */


int get_goodlink(struct eh_softc *en)
{
   NICRef nic = en->Chip;

#ifdef TRACE_ROUTINES
   printf("debug: get_goodlink\n");
   fflush(stdout);
#endif

   switch(en->eh_cardtype)
   {
      case EH_TYPE_200:
            return -1;

      case EH_TYPE_100:
      case EH_TYPE_500:
      case EH_TYPE_700:
            if ((*(en->cntrl_reg) & EH_GOODLINK) == 0)
            {
                return TRUE;
            }
            else
            {
                return FALSE;
            }

      case EH_TYPE_600:
            if ((nic->mcrb & 0x04) == 0x04)
            {
                return TRUE;
            }
            else
            {
                return FALSE;
            }
    }

    return -1;
}


/*
 * Select coax interface on combo card.
 */
static void sel_coax_inter(struct eh_softc *en)
{
#ifdef DRIVER16BIT
   u_char data;
   NICRef nic = en->Chip;
#endif

#ifdef TRACE_ROUTINES
   printf("debug: sel_coax_inter\n");
   fflush(stdout);
#endif

   switch(en->eh_cardtype)
   {
#ifdef DRIVER8BIT
      case EH_TYPE_200:
         /* Read control register.                      */
         nulldev(*en->cntrl_reg);
         en->control_reg2 &= ~EH_TPISEL;
         *en->cntrl_reg = en->control_reg;
         *en->cntrl_reg = en->control_reg2;
         return;
#endif

      case EH_TYPE_100:
      case EH_TYPE_500:
      case EH_TYPE_700:
         /*
          * Write 0 to TPISEL (select 10Base2)
          */
         en->control_reg &= ~EH_TPISEL;
         *en->cntrl_reg = en->control_reg;

         /*
          * Wait 100 ms for DC/DC to start up.
          */
         MICRODELAY(100000);
         break;

#ifdef DRIVER16BIT
      case EH_TYPE_600:
         data = nic->mcrb;
         nic->mcrb = ((data & 0xf8) | EH6_10B2SEL);
         break;
#endif
   }

} /* sel_coax_inter() */


/*
 * Select TPI interface on combo card.
 */
static void sel_tpi_inter(struct eh_softc *en)
{
#ifdef DRIVER16BIT
   u_char data;
   NICRef nic = en->Chip;
#endif

#ifdef TRACE_ROUTINES
   printf("debug: sel_tpi_inter\n");
   fflush(stdout);
#endif

   switch (en->eh_cardtype)
   {
#ifdef DRIVER8BIT
      case EH_TYPE_200:
         /* Read control register.                      */
         nulldev(*en->cntrl_reg);
         en->control_reg2 |= EH_TPISEL;
         *en->cntrl_reg = en->control_reg;
         *en->cntrl_reg = en->control_reg2;
         break;
#endif

      case EH_TYPE_100:
      case EH_TYPE_500:
      case EH_TYPE_700:
         /* Write 1 to TPISEL (select twisted pair)   */
         en->control_reg |= EH_TPISEL;
         *en->cntrl_reg = en->control_reg;
         break;

#ifdef DRIVER16BIT
      case EH_TYPE_600:
         data = nic->mcrb;
         nic->mcrb = ((data & 0xf8) | EH6_10BTSEL);
         break;
#endif

   }

} /* sel_tpi_inter() */


/*
 *
 */
static u_char get_adaptor_id(struct eh_softc *en)
{
#ifdef DRIVER8BIT
   int i;
#endif
   u_char data;
#ifdef DRIVER16BIT
   NICRef nic = en->Chip;
#endif

#ifdef TRACE_ROUTINES
   printf("debug: get_adaptor_id\n");
   fflush(stdout);
#endif

   switch(en->eh_cardtype)
   {
#ifdef DRIVER8BIT
      case EH_TYPE_200:
         data = en->control_reg;

         /* Read first.                       */
         nulldev(*en->cntrl_reg);

         /* Test if Micro 10Base2 MAU         */
         /* Set IDC high first.               */
         data |= EH_ID_CONTROL;
         *en->cntrl_reg = data;
         MICRODELAY(5);
         /* Read back level.                  */
         if ((*en->cntrl_reg & EH_ID_CONTROL) == 0)
         {
            /* If read back a 0 then write a 0*/
            data &= ~EH_ID_CONTROL;
            *en->cntrl_reg = data;
            MICRODELAY(5);
            if ((*en->cntrl_reg & EH_ID_CONTROL) == 0)
               return INTERFACE_MICRO_2;
         }

         /* Set IDC high to reset counter.    */
         data |= EH_ID_CONTROL;
         *en->cntrl_reg = data;
         MICRODELAY(100000);


         /* this needs to be checked - id numbers have changed!! */
         /* Determine ID.                     */
         for (i = 0; i < INTERFACE_ULIMIT; i++)
         {
            /* Set IDC low.                   */
            nulldev(*en->cntrl_reg);
            data &= ~EH_ID_CONTROL;
            *en->cntrl_reg = data;
            MICRODELAY(5);

            /* Read back level.               */
            if ((*en->cntrl_reg & EH_ID_CONTROL) == EH_ID_CONTROL)
               break;

            /* Set IDC high.                  */
            data |= EH_ID_CONTROL;
            *en->cntrl_reg = data;
            MICRODELAY(5);
         }
         if (i == INTERFACE_NONE)
            return INTERFACE_MICRO_T;

         return i;

         break;
#endif
      case EH_TYPE_100:
      case EH_TYPE_500:
      case EH_TYPE_700:
         /* if this is a virtual interface then return id of unit 0 */
         if (virtual && (en->eh_unit > 0))
            return(eh_softc[0]->eh_interface);

         /* Read first.                       */
         nulldev(*en->cntrl_reg);

         /* Write 1 to TPISEL (select twisted pair)   */
         *en->cntrl_reg = 2;
         data = *(en->cntrl_reg + STAT2_OFFSET);
         if ((data & 1) == 1)
            return INTERFACE_10BASE2;

         /* Write 0 to TPISEL (select 10Base2)        */
         *en->cntrl_reg = 0;
         data = *(en->cntrl_reg + STAT2_OFFSET);
         if ((data & 1) == 0)
            return INTERFACE_10BASET;

         return INTERFACE_COMBO;
         break;

#ifdef DRIVER16BIT
      case EH_TYPE_600:
#ifdef DEBUG
         printf("debug: get_adaptor_id E600\n");
         fflush(stdout);
#endif

         data = (nic->mcrb) & 0x03;
         switch (data)
         {
            case 0x00:
               return INTERFACE_10BASET;

            case 0x01:
               return INTERFACE_10BASE2;

            case 0x03:
               return INTERFACE_COMBO;
         }
         return INTERFACE_UNKNOWN;
#endif

   }

   return INTERFACE_UNKNOWN;

} /* get_adaptor_id()           */


/*
 * Set ROM page register.
 */
u_int *eh_set_rom_page(struct eh_softc *en, u_int address)
{

#ifdef TRACE_ROUTINES
   printf("debug: eh_set_rom_page en:%x address:%x\n",(int) en, address);
   fflush(stdout);
#endif

   if (en->eh_cardtype != EH_TYPE_600)
   {
      /* Set page register.                       */
      *((u_char *) en->page_reg) = (u_char) ((int) address / en->rom_page_size);

      /* Return address within page.              */
      return (u_int *) ((int) address % en->rom_page_size);
   }

   /* Reset page register.                       */
   *((u_char *) en->page_reg) = 0;

   return 0;

} /* eh_set_rom_page()        */



/*
 * configure the NIC for diagnostic tests
 */

static void eh_setup_diags(struct eh_softc *en, NICRef nic, u_char loop_mode,
u_char manual_crc)
{
#ifdef TRACE_ROUTINES
    printf("debug: eh_setup_diags loopmode:%d\n",loop_mode);
    fflush(stdout);
#endif

    /*
     * must ensure the NIC is stopped - the act of starting
     * initialises its internal FIFO pointers. must also clear any
     * previous loopback mode - can only enter a loopback mode from
     * normal operation
     */
    nic->tcr = LOOP_MODE(LIVE_NET);

    /* Issue software reset command.            */
    nic->command = SEL_PAGE(0, NIC_STOPPED);
    MICRODELAY(NIC_RESET_PERIOD);

    /*
     * now set tcr to required loopback mode and
     * CRC type, then clear interrupts & mask
     * them all out
     */
    nic->tcr = LOOP_MODE(loop_mode) | manual_crc;
    nic->isr = 0xff;
    nic->imr = 0x00;

#ifdef DEBUGINIT
    printf("debug: setup DCR\n");
#endif
    /*
     * Set up data configuration register.
     */
#ifdef DRIVER16BIT
    nic->dcr = WTS | FIFO_THRESH(WORD_THRESH2);
#else
    nic->dcr = FIFO_THRESH(BYTE_THRESH4);
#endif

    /*
     * bring the NIC back to page 0, alive & kicking
     */
    nic->command = SEL_PAGE(0, NIC_RUNNING);

    UNUSED(en);
} /* eh_setup_diags()           */

#if 1
/*
 * calculate the Autodin II CRC for the passed data
 */
u_long calc_crc(u_char *data, int datalen)
{
    u_long crc;
    int i, j;

    crc = ~0;
    for (i = 0; i < datalen; ++i)
    {
        u_char next = *data++;
        for (j = 0; j < NBBY; ++j)
        {
            if ((next & 1uL) ^ (crc >> 31))
                crc = (crc << 1) ^ POLYNOMIAL;
            else
                crc <<= 1;
            next >>= 1;
        }
    }
    return(crc);
}    
#else
/*
 * calculate the Autodin II CRC for the passed data
 */
u_char *calc_crc(u_char *data, int datalen)
{
    u_long crc, swap = 0;
    int i, j;
    static u_char retc[sizeof(crc)];

    crc = ~0;
    for (i = 0; i < datalen; ++i)
    {
        u_char next = *data++;
        for (j = 0; j < NBBY; ++j)
        {
            if ((next & 1) ^ (crc >> 31))
                crc = (crc << 1) ^ POLYNOMIAL;
            else
                crc <<= 1;
            next >>= 1;
        }
    }

    /* reverse, nibble swap & complement the result */
    for (i = 0; i < (NBBY * sizeof(crc)); ++i)
    {
        swap <<= 1;
        swap |= ((crc & 0x01) ? 1 : 0);
        crc >>= 1;
    }

    for (i = 0; i < sizeof(crc); ++i)
    {
        retc[i] = ~(swap & 0xff);
        swap >>= NBBY;
    }
    
    return(retc);
} /* *calc_crc()                */
#endif

#ifdef LOOPBACK_TEST
/*
 * build a loopback test packet - this is currently all zeros, plus an
 * appropriate CRC
 */
static void build_tpkt(struct eh_softc *en, TestPacket *test_pack)
{
    int i;
    u_char *cptr;

#ifdef TRACE_ROUTINES
    printf("debug: build_tpkt\n");
    fflush(stdout);
#endif

    /*
     * check size of TestPacket to make sure no padding is present
     */
    if (sizeof(TestPacket) != (TESTP_LEN + CRC_LEN))
        panic("en: bad size for TestPacket\n");

    /*
     * build a packet full of zeroes then fill in the source
     * and destination address
     */
    memset ((caddr_t)test_pack, 0, TESTP_LEN);
    memcpy ((caddr_t)test_pack->src_addr, (caddr_t)en->eh_addr, HW_ADDR_LEN);
    memcpy ((caddr_t)test_pack->dst_addr, (caddr_t)en->eh_addr, HW_ADDR_LEN);

#ifdef TEST_CRC_CALC
    /*
     * calculate & fill in the packet's CRC
     */
    for (i = 0, cptr = calc_crc((u_char *) test_pack, TESTP_LEN);
        i < CRC_LEN; ++i, ++cptr)
        test_pack->crc_bytes[i] = *cptr;
#endif

} /* build_tpkt()               */


/*
 * Run loopback tests in given loopback mode.
 * Manual_crc is the CRC source used to program tcr
 * (0 if NIC is to generate CRC, !0 if CRC not appended after transmit).
 * Routine returns 0 if test failed, else !0
 *
 */
static int eh_loopback(struct eh_softc *en, TestPacket *test_pack, u_char loop_mode,
u_char manual_crc)
{
    NICRef nic = en->Chip;
    int i, pack_len;

#ifdef TRACE_ROUTINES
    printf("debug: eh_loopback loop_mode:%x\n",(int) loop_mode);
    fflush(stdout);
#endif

    /*
     * set up the NIC, then start the transmit
     */
    eh_setup_diags(en, nic, loop_mode, manual_crc);
    pack_len = TESTP_LEN + ((manual_crc) ? CRC_LEN : 0);
    nic->tpsr = en->buffer_pstart;
#ifdef DRIVER16BIT
    nic->tbcr0 = pack_len << 1;
    nic->tbcr1 = pack_len >> 7;
#else
    nic->tbcr0 = pack_len;
    nic->tbcr1 = pack_len >> 8;
#endif
    nic->command = START_DMA(DMA_IDLE) | TXP;

    for(i = 0; i < LB_TIMEO; ++i)
    {
        if ((nic->isr & (PTX | TXE)))
            /* packet has gone out */
            break;

        MICRODELAY(1000000 / HZ);

    }

    if ((loop_mode == LOOPBACK3) && (nic->isr == TXE || i == LB_TIMEO))
        return(lb3_failed(en, nic));
    else if (i == LB_TIMEO)
    {
        /* timed_out */
        sprintf(eh_lasterr, "eh_loopback: loopback %d/%d tx timed out (unit %d)",
                loop_mode, manual_crc, en->eh_unit);
        return(0);
    }

    /*
     * now wait for the receive to come in
     */
    for(i = 0; i < LB_TIMEO; ++i)
    {
        if ((nic->rsr & (RSR_PRX | CRCE | FAE)))
            break;

        MICRODELAY(1000000 / HZ);
    }

    if (i == LB_TIMEO)
    {
        /* timed_out */
        sprintf(eh_lasterr, "eh_loopback: loopback %d/%d rx timed out (unit %d)",
                loop_mode, manual_crc, en->eh_unit);
        return(0);
    }

#ifdef TEST_CRC_CALC
    /*
     * check the result from the test
     */
    if (manual_crc)
    {
        if ((nic->isr & RXE))
        {
            sprintf(eh_lasterr, "eh_loopback: loopback %d/%d bad CRC recognition (unit %d)",
                    loop_mode, manual_crc, en->eh_unit);
            return(0);
        }
    }
    else if (loop_mode != LOOPBACK3)
    {
        u_char nic_crc, *ok_crc;

        /*
         * junk unwanted data from the FIFO
         */
        for (i = 0; i < N_JUNK; ++i) nulldev(nic->fifo);

        /*
         * now read the CRC back & check it against what is expected
         */
        for(i = 0, ok_crc = test_pack->crc_bytes;
            i < CRC_LEN; ++i, ++ok_crc)
            if ((nic_crc = nic->fifo) != *ok_crc)
            {
                sprintf(eh_lasterr, "eh_loopback: loopback %d/%d bad CRC N%x L%x (unit %d)",
                        loop_mode, manual_crc,
                        nic_crc, *ok_crc, en->eh_unit);
                return(0);
            }
    }
#else
    if ((nic->isr & RXE))
    {
        sprintf(eh_lasterr, "eh_loopback: loopback %d/%d rx error rsr = %x (unit %d)",
                loop_mode, manual_crc, nic->rsr, en->eh_unit);
        return(0);
    }
#endif

    /* tests passed successfully */
    return(1);

} /* eh_loopback()              */


/*
 * see what has gone wrong with mode 3 loopback (onto live net,
 * therefore susceptible to genuine collisions)
 */

static int lb3_failed(struct eh_softc *en, NICRef nic)
{
    u_char txstat = nic->tsr;
    int unit = en->eh_unit;

#ifdef TRACE_ROUTINES
    printf("debug: lb3_failed\n");
    fflush(stdout);
#endif

    if (!(txstat & COL))
    {
        sprintf(eh_lasterr, "lb3_failed: CTI failure, no COL (unit %d)",
                unit);
        return(0);
    }
    else if ((txstat & ABT))
    {
        sprintf(eh_lasterr, "lb3_failed: bad network termination (unit %d)",
                unit);
        return(0);
    }
    else if (nic->ncr == 0)
    {
        sprintf(eh_lasterr, "lb3_failed: CTI failure, COL with 0 collisions (unit %d)",
                unit);
        return(0);
    }
    else
    {
        return(1);
    }
} /* lb3_failed()               */
#endif

/* EOF init.c */
