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



#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "dcierror.h"

#include "debug.h"
#include "device.h"
#include "module.h"
#include "ModuleHdr.h"
#include "utils.h"
#include "mii.h"
#include "ar8031_mii.h"
#include "AsmUtils/irqs.h"
#include "callx/callx.h"

#ifdef DEBUGLIB

#define print_tx_ring(d) \
do { \
        TxBD_t* b = d->mem->tx_ring_buf; \
        for (int i = 0; i < TXBD_RING_BUFFER_SIZE; i++) \
        { \
                dprintf_here("TXptr=%#p status=%08x ptr=%d\n", (void*) &b[i], b[i].status, &b[i] == d->tx_ring_ptr); \
        } \
        dprintf(("","\n"));\
} while (0)

#define print_rx_ring(d) \
do { \
        RxBD_t* b = d->mem->rx_ring_buf; \
        for (int i = 0; i < RXBD_RING_BUFFER_SIZE; i++) \
        { \
                dprintf_here("RXptr=%#p status=%08x ptr=%d\n", (void*) &b[i], b[i].status, &b[i] == d->rx_ring_ptr); \
        } \
        dprintf(("","\n")); \
} while (0)

#define print_net_addr(txt, addr) \
        dprintf_here("Net addr: %s %02x:%02x:%02x:%02x:%02x:%02x\n", (txt), (addr)[0], (addr)[1],(addr)[2],(addr)[3],(addr)[4],(addr)[5]);

static int print_ping(const char* txt,const uint8_t* data)
{
        if (data[ETHER_HDR_LEN - 2] <= 8) return 0;
//ping        if (!(data[23] == 1 && (data[34] == 8 || data[34] == 0) & data[35] == 0)) return 0;
        dprintf_here("%s\n", txt);
        print_net_addr("dst", data);
        print_net_addr("src", data + ETHER_ADDR_LEN);
        dprintf_here("type=%02x%02x\n",data[ETHER_HDR_LEN - 2],data[ETHER_HDR_LEN - 1]);

        for (int i = 0; i < 8; i++)
        {
        dprintf(("","%02x %02x %02x %02x %02x %02x %02x %02x   ",data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7]));
        data += 8;
        dprintf(("","%02x %02x %02x %02x %02x %02x %02x %02x\n",data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7]));
        data += 8;
        }
        dprintf(("","\n"));
        return 1;
}

#endif

static _kernel_oserror* tdar_bug_fix(_kernel_swi_regs* r, void* pw, void* handle);


struct device_list_t  device_list = SLIST_HEAD_INITIALIZER(&device_list);

device_t* device_getFromUnit(int unit)
{
        device_t* d;
        SLIST_FOREACH(d, &device_list, next)
        {
                if (d->dib.dib_unit == unit) return d;
        }
        return NULL;
}

static _kernel_oserror* device_destroy(device_t* device, _kernel_oserror* err)
{
        device_delete(device);
        dprintf_here("Error: %s\n", err->errmess);
        return err;
}

#define DRIVER_ID               (1 << 3)

_kernel_oserror* device_new(int unit, HalEtherDevice_t* hal_device, void* pw)
{
        dprintf_here("unit=%d hal_device=%#p\n", unit, (void*) hal_device);

        _kernel_oserror* err;

        if (hal_device == NULL ||
            hal_device->base.address == NULL ||
            hal_device->base.devicenumber == -1) return dcierror(EINVAL);

        dprintf_here("started\n");

        device_t* dev = calloc(1, sizeof(device_t));

        if (dev == NULL) return dcierror(ENOMEM);
        dev->flags |= DF_I_MEMORY;              /* memory allocated */


        dev->hal_device         = hal_device;
        dev->pw                 = pw;
        dev->register_base      = hal_device->base.address;
        dev->dib.dib_swibase    = MODULE_SWI_BASE;
        dev->dib.dib_name       = (unsigned char*) MODULE_DCI_NAME;
        dev->dib.dib_unit       = unit;
        dev->dib.dib_address    = dev->net_address;
        dev->dib.dib_module     = (unsigned char*) Module_Title;
        dev->dib.dib_location   = (unsigned char*) MODULE_LOCATION;
        dev->dib.dib_slot.sl_slotid     = DIB_SLOT_SYS_BUS;
        dev->dib.dib_slot.sl_minor      = hal_device->base.location >> 16;
        dev->dib.dib_slot.sl_pcmciaslot = 0;
        dev->dib.dib_slot.sl_mbz        = 0;
        dev->dib.dib_inquire    = (INQ_MULTICAST |       /* see dcistructs.h */
                                 /*INQ_FILTERMCAST | */  /* Not implemented yet - causes swi 7 (MulticastRequests) */
                                   INQ_PROMISCUOUS |
                                   INQ_RXERRORS |
                                   INQ_HWADDRVALID |
                                   INQ_SOFTHWADDR |
                                   INQ_HASSTATS |
                                   INQ_HASESTATS);

        dev->hal_pw             = utils_get_hal_pw();
        dev->hal_device->phy.enable(0, dev->hal_pw);
        SLIST_INSERT_HEAD(&device_list, dev, next);

        /* device can now be used for accessing registers */

        err = dcifilter_new(&dev->dib, &dev->dcifilter);
        if (err) return device_destroy(dev, err);
        dev->flags |= DF_I_DCIFILTER;

        /* Check if we can use the Phy PwrRst call *
         * (earlier HALs exported this as 0)       */
        if(dev->hal_pw == dev->hal_device->phy.HAL_WS)
            dev->flags |= DF_I_HAL_HAS_PHY_PWRRST;

        /*
         * Alloc PCI contiguous memory for:
         *      Tx ring buffer - holds an array of Tx buffer descriptors.
         *      Tx packet data - series of packet data buffers - one for each descriptor - to store data for tx
         *      Rx ring buffer - holds an array of Rx buffer descriptors.
         *      Rx packet data - series of packet data buffers - one for each descriptor - to store rx data
         */

        char* log  = NULL;
        char* phys = NULL;

        /* rx_ring_buf and tx_ring_buf need to be 16 byte aligned */
        err = _swix(PCI_RAMAlloc, _INR(0,2) | _OUTR(0,1), sizeof(device_mem_t), 16, 0, &log, &phys);

        if (err) return device_destroy(dev, err);
        dev->flags |= DF_I_PCI_MEMORY;          /* pci memory allocated */

        dev->mem                        = (void*) log;
        dev->mem_physical_offset        = phys - log;

        dprintf_here("phys=%#p log=%#p size=%d\n", (void*)phys, (void*)log, sizeof(device_mem_t));

        /* Configure ring buffers */
        for (int i = 0; i < RXBD_RING_BUFFER_SIZE; i++)
        {
                dev->mem->rx_ring_buf[i].status = RXBD_STATUS__E | (i == RXBD_RING_BUFFER_SIZE - 1 ? RXBD_STATUS__W : 0);
                dev->mem->rx_ring_buf[i].data   = (void*) (((char*) &dev->mem->rx_packets[i]) + dev->mem_physical_offset);
        }

        for (int i = 0; i < TXBD_RING_BUFFER_SIZE; i++)
        {
                dev->mem->tx_ring_buf[i].status = (i == TXBD_RING_BUFFER_SIZE - 1 ? TXBD_STATUS__W : 0);
                dev->mem->tx_ring_buf[i].data   = (void*) (((char*) &dev->mem->tx_packets[i]) + dev->mem_physical_offset);
        }

        /* These need setting when a reset occurs */
        dev->tx_ring_ptr        = dev->mem->tx_ring_buf;
        dev->tx_packet_ptr      = dev->mem->tx_packets;
        dev->rx_ring_ptr        = dev->mem->rx_ring_buf;
        dev->rx_packet_ptr      = dev->mem->rx_packets;
#if 0
        print_tx_ring(dev);
        print_rx_ring(dev);
#endif

        /*
         * Get net address
         *
         * Which just happens to be the machine id in the imx6 hal
         */

        uint32_t a, b;
        err = _swix(OS_ReadSysInfo, _IN(0) | _OUTR(3,4), 2 /* Read machine ID */, &a, &b);
        if (err) return device_destroy(dev, err);

        dprintf_here("Machine id: %08x %08x\n", a ,b);

        uint8_t* addr = dev->net_address;
        addr[0] = ((b >> 8) & 0xff);
        addr[1] = (b  & 0xff);
        addr[2] = ((a >> 24) & 0xff);
        addr[3] = ((a >> 16) & 0xff);
        addr[4] = ((a >> 8) & 0xff);
        addr[5] = (a & 0xff);

        dprintf_here("Net addr: %02x:%02x:%02x:%02x:%02x:%02x\n", addr[0], addr[1],addr[2],addr[3],addr[4],addr[5]);

        /* reset device */

        device_setReg(dev, ENET_ECR, ENET_ECR__RESET);

        for (int i = 1000; i; i--)
        {
                if ((device_getReg(dev, ENET_ECR) & ENET_ECR__RESET) == 0) break;
                utils_delay_us(50);
        }

        /* set speed so that mii can be used */
        device_setReg(dev, ENET_MSCR, ENET_MSCR__MII_SPEED((dev->hal_device->phy.clock + 5000000 - 1)/ 5000000));

        /* Initialise registers */

        device_setReg(dev, ENET_ECR, ENET_ECR__DBSWP);          /* little endian */

        device_setReg(dev, ENET_MIBC, 0);                       /* start statistic counters */


        device_setReg(dev, ENET_RCR, (ENET_RCR__MAX_FL(ETHER_MAX_LEN) |
                                      ENET_RCR__RGMII_EN |
                                      ENET_RCR__PADEN |
                                      ENET_RCR__MII_MODE));

        device_setReg(dev, ENET_TCR, ENET_TCR__FDEN);           /* full duplex enable */

        /* set net address */

        addr = dev->net_address;
        device_setReg(dev, ENET_PALR, ((addr[0] << 24) | (addr[1] << 16) | (addr[2] << 8) | addr[3]) );
        device_setReg(dev, ENET_PAUR, ((addr[4] << 24) | (addr[5] << 16) | ENET_PAUR__8808));

        /* initialise ring buffers */
        device_setReg(dev, ENET_RDSR, ((uint32_t)(((char*) dev->mem->rx_ring_buf) + dev->mem_physical_offset)));
        device_setReg(dev, ENET_TDSR, ((uint32_t)(((char*) dev->mem->tx_ring_buf) + dev->mem_physical_offset)));
        device_setReg(dev, ENET_MRBR, sizeof(BD_Data_t));

        /* flow control */
                /* Best for GIGABIT and 100/10 */
                /* rx thresholds (8 byte words - max 511) */
                /* values are used words in fifo */
                /* Values tuned for armx6 - flow control required as dma to phy is limited to 400Mb/s */
        device_modifyReg(dev, ENET_RCR, ENET_RCR__FCE, ENET_RCR__FCE);
        device_setReg(dev, ENET_OPD, PAUSE_DURATION);           /* pause duration */

        device_setReg(dev, ENET_RAEM, 0x06);                    /* min 6 - reception stops if used words are less than this */
        device_setReg(dev, ENET_RSFL, ENET_RSFL__STRFWD);       /* reception starts if used space is greater than or equal to this. */
                                                                /* must be greater than ENET_RAEM when not ENET_RSFL__STRFWD (0)*/
                /* values are free words in fifo */
        device_setReg(dev, ENET_RSEM, PAUSE_THRESHOLD/8);       /* transmit xon/xoff when free words cross this level. */
                                                                /* a value ENET_RSEM__NO_XON_XOFF (0) disables transmission. */
        device_setReg(dev, ENET_RAFL, 0x04);                    /* min 4 - frames dropped when free words are less than this.*/
        /* tx thresholds (8 byte words - max 511) */
                /* values are free words in fifo */
        device_setReg(dev, ENET_TAFL, 0x04);                    /* min 4 - transmission stops if free words are less than this */
        device_setReg(dev, ENET_TSEM, 0x00);                    /* Inform the MAC when free words are less than this */
                /* values are used words in fifo */
        device_setReg(dev, ENET_TFWR, ENET_TFWR__STRFWD);       /* transmission starts when used words are greater than or equal to this. */
                                                                /* alternatively set ENET_TFWR__STRFWD */
        device_setReg(dev, ENET_TAEM, 0x04);                    /* min 4  - underflow error if used words are less than this and not end of frame*/
        device_setReg(dev, ENET_TIPG, 0x0c);



        device_setReg(dev, ENET_FTRL, ETHER_MAX_LEN);

        device_setReg(dev, ENET_RACC,  ENET_RACC__PADREM | ENET_RACC__LINEDIS | ENET_RACC__PRODIS | ENET_RACC__IPDIS);

        /* make sure the phy is turned on and reset if possible,*
         * so we can read its ID                                */
        mii_hardresetPhy(dev);

        /* Only AR8031 device supported */
        if (mii_getReg(dev, MII_IDH) != AR8031_MII_IDH ||
        mii_getReg(dev, MII_IDL) != AR8031_MII_IDL)
        {
          dprintf_here("idh:%x idl:%x\n",mii_getReg(dev, MII_IDH),mii_getReg(dev, MII_IDL));
          dprintf_here("bcr:%x \n",mii_getReg(dev, MII_BCR));
          if (mii_getReg(dev, MII_IDH) == AR8035_MII_IDH ||
          mii_getReg(dev, MII_IDL) == AR8035_MII_IDL)
          {
            dprintf_here("AR8035 found \n");
            dev->flags |= DF_I_PHY_AR8035;              /* remember */
          }
          else
          {
            return device_destroy(dev, dcierror(EINVAL));
          }
        }
        mii_modifyReg(dev, AR8031_MII_CCR, AR8031_MII_CCR__SEL_COPPER_PAGE | AR8031_MII_CCR__PREFER_COPPER,
                                           AR8031_MII_CCR__SEL_COPPER_PAGE | AR8031_MII_CCR__PREFER_COPPER);


        mii_mmd_modify(dev, 7, 0x8016, 0x1c, 0x18);                             /* Set 125MHz from local pll source */
        ar8031_mii_dbg_modify(dev, AR8031_MII_DBG_SARDES_REG, 0x100, 0x100);    /* rgmii_tx_clk_dly on */
        mii_resetPhy(dev);      /* ensure settings and renegotiate */
        /* Advertise pause control */
        mii_modifyReg(dev, MII_ANAR, MII_ANAR__PAUSE | MII_ANAR__ASYM_PAUSE, MII_ANAR__PAUSE | MII_ANAR__ASYM_PAUSE);
        mii_setReg(dev, MII_BCR, MII_BCR__AUTONEGEN | MII_BCR__REAUTONEG );

        int failed = 1;
        if (mii_getReg(dev, MII_BCR) & MII_BCR__AUTONEGEN)
        {
                for (int i = 0; i <6000; i++)
                {
                        if (mii_getReg(dev, MII_BSR) & MII_BSR__AUTO_NEG_COMPLETE) {failed = 0;break;}
                        utils_delay_us(1000);
                }
        }
        uint32_t ssr = mii_getReg(dev, AR8031_MII_SSR);

        if (failed == 0 && (ssr & AR8031_MII_SSR__SPEED) == AR8031_MII_SSR__SPEED_1000)
        {
                device_modifyReg(dev, ENET_ECR, ENET_ECR__SPEED, ENET_ECR__SPEED_1000);          /* little endian */
        }
        else
        {
                device_modifyReg(dev, ENET_ECR, ENET_ECR__SPEED, ENET_ECR__SPEED_10_100);          /* little endian */
        }



        /* Setup Interrupts */

        err = _swix(OS_ClaimDeviceVector, _INR(0,2), hal_device->base.devicenumber | (1u << 31),
                                                     device_interrupt, pw);

        if (err) return device_destroy(dev, err);
        dev->flags |= DF_I_VECTORCLAIMED;

        err = _swix(OS_Hardware, _IN(0) | _INR(8,9),dev->hal_device->base.devicenumber, OSHW_CallHAL, EntryNo_HAL_IRQEnable);
        if (err != NULL) return device_destroy(dev, err);
        dev->flags |= DF_I_IRQENABLED;

        err = _swix(OS_ClaimDeviceVector, _INR(0,2), hal_device->phy.devicenumber | (1u << 31),
                                                     ar8031_mii_interrupt, pw);

        if (err) return device_destroy(dev, err);
        dev->flags |= DF_I_PHYVECTORCLAIMED;


        mii_getReg(dev, AR8031_MII_ISR); /* clear ar8031 interrupt by reading interrupt status register */
        err = _swix(OS_Hardware, _IN(0) | _INR(8,9),dev->hal_device->phy.devicenumber, OSHW_CallHAL, EntryNo_HAL_IRQEnable);
        if (err != NULL) return device_destroy(dev, err);
        dev->flags |= DF_I_PHYIRQENABLED;


        device_modifyReg(dev, ENET_ECR, ENET_ECR__ETHEREN, ENET_ECR__ETHEREN); /* enable ethernet */
        device_setReg(dev, ENET_EIMR, ENET_EIMR__RXF);
        device_setReg(dev, ENET_RDAR, ENET_RDAR__RDAR);

        callx_add_callevery(1, tdar_bug_fix, dev);


        mii_setReg(dev, AR8031_MII_IER, AR8031_MII_IER__SPEED_CHANGED);
        dev->hal_device->phy.clear(1, dev->hal_pw);
        dev->hal_device->phy.enable(1, dev->hal_pw);

        /* set our Inet$EtherType variable */
        char dn[strlen(MODULE_DCI_NAME)+4];
        sprintf(dn,"%s%1d",dev->dib.dib_name,dev->dib.dib_unit);
        _swix(OS_SetVarVal,_INR(0,4),"Inet$EtherType",dn,strlen(dn),0,4);

        /* Announce Driver */
        _swix(OS_ServiceCall, _INR(0,3), &(dev->dib), Service_DCIDriverStatus, DCIDRIVER_STARTING, DCIVERSION);
        dev->flags |= DF_I_DRIVER_STARTING;

        dprintf_here("complete\n");
        return NULL;
}

void device_delete(device_t* device)
{
        device_t* found;
        SLIST_FOREACH(found, &device_list, next)
        {
                if (found == device) break;
        }
        if (found == NULL) return;      /* not in list so already deleted */

        uint32_t flags = device->flags;

        if (flags & DF_I_DRIVER_STARTING)
        {
                _swix(OS_ServiceCall, _INR(0,3), &device->dib, Service_DCIDriverStatus, DCIDRIVER_DYING, DCIVERSION);
                dprintf_here("dying\n");
        }

        if (flags & DF_I_PHYIRQENABLED)
        {
                device->hal_device->phy.enable(0, device->hal_pw);
                _swix(OS_Hardware, _IN(0) | _INR(8,9),device->hal_device->phy.devicenumber, OSHW_CallHAL, EntryNo_HAL_IRQDisable);
        }

        if (flags & DF_I_IRQENABLED)
        {
                device_setReg(device,ENET_EIMR, 0);                             /* disable all interrupts */
                device_modifyReg(device, ENET_ECR, ENET_ECR__ETHEREN, 0);       /* disable ethernet */
                _swix(OS_Hardware, _IN(0) | _INR(8,9),device->hal_device->base.devicenumber, OSHW_CallHAL, EntryNo_HAL_IRQDisable);
        }

        if (flags & DF_I_PCI_MEMORY) _swix(PCI_RAMFree, _IN(0), device->mem);

        if (flags & DF_I_PHYVECTORCLAIMED)
        {
                _swix(OS_ReleaseDeviceVector, _INR(0,2), device->hal_device->phy.devicenumber | (1u << 31),
                                                               ar8031_mii_interrupt, device->pw);
        }

        if (flags & DF_I_VECTORCLAIMED)
        {
                _swix(OS_ReleaseDeviceVector, _INR(0,2), device->hal_device->base.devicenumber | (1u << 31),
                                                               device_interrupt, device->pw);
        }

        if (flags & DF_I_DCIFILTER) device->dcifilter = dcifilter_delete(device->dcifilter);

        /* if poss, turn off phy */
        if (flags & DF_I_HAL_HAS_PHY_PWRRST) device->hal_device->phy.PwrRst(0,device->hal_pw);

        SLIST_REMOVE(&device_list, device, device_t, next);
        free(device);
}

_kernel_oserror* device_stats(device_t* d, dci_StatsArgs_t* args)
{
        if (d == NULL || args == NULL || args->stats == NULL) return dcierror(EINVAL);
        switch (args->stat_reason_code)
        {
                case dci_STAT_INQUIRE:

                        dprintf_here("Inquire\n");
                        memset(args->stats, 0, sizeof(struct stats));   /* default to returning no statistics */

                        args->stats->st_interface_type          = dci_STAT_VALID;
                        args->stats->st_link_status             = dci_STAT_VALID;
                        args->stats->st_link_polarity           = dci_STAT_VALID;
                        args->stats->st_collisions              = dci_STAT_VALID;
                        args->stats->st_excess_collisions       = dci_STAT_VALID;
                        args->stats->st_tx_frames               = dci_STAT_VALID;
                        args->stats->st_tx_bytes                = dci_STAT_VALID;
                        args->stats->st_crc_failures            = dci_STAT_VALID;
                        args->stats->st_frame_alignment_errors  = dci_STAT_VALID;
                        args->stats->st_dropped_frames          = dci_STAT_VALID;
                        args->stats->st_unwanted_frames         = dci_STAT_VALID;
                        args->stats->st_rx_frames               = dci_STAT_VALID;
                        args->stats->st_rx_bytes                = dci_STAT_VALID;
                        return NULL;

                case dci_STAT_READ:
                {
                        dprintf_here("Read\n");
                    //    memset(args->stats, 0, sizeof(struct stats));   /* default to returning no statistics */
                        unsigned char status = ST_STATUS_OK;
                        uint32_t reg    = mii_getReg(d, AR8031_MII_SSR);
                        if (reg & AR8031_MII_SSR__LINK_UP)         status |= ST_STATUS_ACTIVE;
                        if (reg & AR8031_MII_SSR__DUPLEX_FULL)  status |= ST_STATUS_FULL_DUPLEX;

                        unsigned char iftype;
                        switch (reg & AR8031_MII_SSR__SPEED)
                        {
                                case AR8031_MII_SSR__SPEED_10: iftype = ST_TYPE_10BASET; break;
                                case AR8031_MII_SSR__SPEED_100: iftype = ST_TYPE_100BASETX; break;
                                default: iftype = ST_TYPE_1000BASET; break;
                        }

                        args->stats->st_interface_type          = iftype;
                        args->stats->st_link_status             = status;
                        args->stats->st_link_polarity           = (reg & AR8031_MII_SSR__POLARITY)
                                                                         ?  ST_LINK_POLARITY_INCORRECT
                                                                         :  ST_LINK_POLARITY_CORRECT;
                        args->stats->st_collisions              = device_getReg(d, ENET_IEEE_T_1COL);
                        args->stats->st_excess_collisions       = device_getReg(d, ENET_IEEE_T_EXCOL);
                        args->stats->st_tx_frames               = device_getReg(d, ENET_IEEE_T_FRAME_OK);
                        args->stats->st_tx_bytes                = device_getReg(d, ENET_IEEE_T_OCTETS_OK);
                        args->stats->st_crc_failures            = device_getReg(d, ENET_IEEE_R_CRC);
                        args->stats->st_frame_alignment_errors  = device_getReg(d, ENET_IEEE_R_ALIGN);
                        args->stats->st_dropped_frames          = device_getReg(d, ENET_IEEE_R_DROP);
                        args->stats->st_unwanted_frames         = dcifilter_getUnwantedFrames(d->dcifilter);
                        args->stats->st_rx_frames               = device_getReg(d, ENET_IEEE_R_FRAME_OK);
                        args->stats->st_rx_bytes                = device_getReg(d, ENET_IEEE_R_OCTETS_OK);

               }
                        return NULL;
        }
        return dcierror(EINVAL);
}

_kernel_oserror* device_multicastRequest(device_t* d, dci_MulticastRequestArgs_t* args)
{
        IGNORE(d);
        IGNORE(args);
        return NULL;
        return dcierror(EINVAL);
}
_kernel_oserror* device_inquire(device_t* d, dci_InquireArgs_t* args)
{
        args->inquire_flags_out = d->dib.dib_inquire;
        return NULL;
}

_kernel_oserror* device_getNetworkMTU(device_t* d, dci_GetNetworkMTUArgs_t* args)
{
        IGNORE(d);
        args->mtu_out = ETHERMTU;
        return NULL;
}

_kernel_oserror* device_setNetworkMTU(device_t* d, dci_SetNetworkMTUArgs_t* args)
{
        IGNORE(d);
        IGNORE(args);
        /* do nothing for now */
        return NULL;
}

static uint8_t* __inline copy_net_address(uint8_t* to, const uint8_t* from)
{
        for (int i = 0; i < ETHER_ADDR_LEN; i++, from++, to++) *to = *from;
        return to;
}

_kernel_oserror* device_transmit(device_t* d, dci_TransmitArgs_t* args)
{
        const uint8_t* src = (args->tx_flags & TX_FAKESOURCE) ? args->src_net_addr : d->net_address;

        struct mbuf* packet;
        for (packet = args->mbuf_list; packet; packet = packet->m_nextpkt)
        {
                uint32_t status = d->tx_ring_ptr->status;
#if 0
                if (status & TXBD_STATUS__R) break;     /* still not ready */
#else
                if (status & TXBD_STATUS__R)
                {
                        /*
                         * Buffer full
                         * Wait up to 0.015 secs for a buffer to clear so that we don't have to
                         * discard the packet and suffer a retry.
                         */
                        device_setReg(d, ENET_TDAR, ENET_TDAR__TDAR); /* just in case its not set */
                        int i;
                        for (i = 150; i; i--)
                        {
                                utils_delay_us(10);
                                status = d->tx_ring_ptr->status;
                                if ((status & TXBD_STATUS__R) == 0) break;
                        }
                        if (i == 0) break; /* No use - will have to discard it */
                }
#endif
                /* buffer ready for transmission */

                uint8_t* p = d->tx_packet_ptr->data;
                p = copy_net_address(p, args->dst_net_addr);
                p = copy_net_address(p, src);
                *p++ = (args->ethertype >> 8); /* type in network byte order */
                *p++ = args->ethertype;

                size_t size = m_count_bytes(packet) + ETHER_HDR_LEN;

                m_export(packet, M_COPYALL, p);   /* copy mbuf data */


                d->tx_ring_ptr->status = ((status & TXBD_STATUS__W) |
                                         TXBD_STATUS__R |
                                         TXBD_STATUS__L |
                                         TXBD_STATUS__TC |
                                         size);
                device_setReg(d, ENET_TDAR, ENET_TDAR__TDAR);   /* tx ring updated */

                /* Move to next buffer */
                if (status & TXBD_STATUS__W)
                {
                        /* At end of ring buffer so wrap to first */
                        d->tx_ring_ptr   = d->mem->tx_ring_buf;
                        d->tx_packet_ptr = d->mem->tx_packets;
                }
                else
                {
                        d->tx_ring_ptr++;
                        d->tx_packet_ptr++;
                }
        }


        if ((args->tx_flags & TX_PROTOSDATA) == TX_DRIVERSDATA)
        {
                /* Free mbufs as we own them */
                for (struct mbuf *next, *item = args->mbuf_list; item ; item = next)
                {
                        next = item->m_nextpkt;
                        m_freem(item);
                }
        }


        return packet == NULL ? NULL : dcierror(INETERR_TXBLOCKED);
}


static _kernel_oserror* tdar_bug_fix(_kernel_swi_regs* r, void* pw, void* handle)
{
        IGNORE(r);
        IGNORE(pw);

        /*
         * A bug in the chip means that ENET_TDAR__TDAR may not always
         * be set. This call_every is a workaround to set ENET_TDAR__TDAR
         * if it isn't set and there is data to be sent in the buffer;
         */

        device_t* d = handle;

        if (device_getReg(d, ENET_TDAR) == 0)
        {
                volatile TxBD_t* last = d->tx_ring_ptr != d->mem->tx_ring_buf           ?
                                        d->tx_ring_ptr - 1                              :
                                        &d->mem->tx_ring_buf[TXBD_RING_BUFFER_SIZE -1];

                if (last->status & TXBD_STATUS__R) device_setReg(d, ENET_TDAR, ENET_TDAR__TDAR);
        }

        return NULL;
}

#define CLAIM           0
#define DONTCLAIM       1

int device_interrupt_handler(_kernel_swi_regs *r, void *pw)
{
        IGNORE(pw);
        IGNORE(r);
        device_t* d = SLIST_FIRST(&device_list); /* There should only be 1 item in list **TEST** */

        if (d == NULL) return DONTCLAIM; /* shouldn't happen - chaos ensues if it does */

        if ((device_getReg(d,ENET_EIMR) & ENET_EIMR__RXF) == 0 ||
            (device_getReg(d,ENET_EIR) & ENET_EIR__RXF) == 0) return DONTCLAIM;

        device_setReg(d, ENET_EIMR, 0); // disable all ENET interrupts
        device_setReg(d,ENET_EIR, ENET_EIR__RXF);

        while ((d->rx_ring_ptr->status & RXBD_STATUS__E) == 0)
        {
                int32_t status = d->rx_ring_ptr->status;

                if (dcifilter_receivedPacket(d->dcifilter, d->rx_packet_ptr->data,
                                                                RXBD_STATUS__LEN(status),
                                                                DCIFILTER_PT_UNICAST,
                                                                false) == DCIFILTER_BLOCKED) break;

                d->rx_ring_ptr->status = (status & RXBD_STATUS__W) | RXBD_STATUS__E;

                device_setReg(d, ENET_RDAR, ENET_RDAR__RDAR);   /* rx ring updated */
                utils_delay_us(10); /* needed for writes to slow (wireless) connections - who knows why */
                if (status & RXBD_STATUS__W)
                {
                        /* At end of ring buffer so wrap to first */
                        d->rx_ring_ptr   = d->mem->rx_ring_buf;
                        d->rx_packet_ptr = d->mem->rx_packets;
                }
                else
                {
                        d->rx_ring_ptr++;
                        d->rx_packet_ptr++;
                }

        }

        _swix(OS_Hardware, _IN(0) | _INR(8,9), d->hal_device->base.devicenumber, OSHW_CallHAL, EntryNo_HAL_IRQClear);

        device_setReg(d,ENET_EIMR, ENET_EIMR__RXF);

        return CLAIM;
}

int ar8031_mii_interrupt_handler(_kernel_swi_regs *r, void *pw)
{
        device_t* d = SLIST_FIRST(&device_list); /* There should only be 1 item in list **TEST** */

        if (d == NULL) return DONTCLAIM;

        dprintf_here("isr=%08x\n", *d->hal_device->phy.irqRegAddr);

        if ((*d->hal_device->phy.irqRegAddr & d->hal_device->phy.irqBitMask) == 0) return DONTCLAIM;

         mii_getReg(d, AR8031_MII_ISR); /* clear ar8031 interrupt by reading interrupt status register */
        *d->hal_device->phy.irqRegAddr = d->hal_device->phy.irqBitMask;         /* clear phy interrupts */
        _swix(OS_Hardware, _IN(0) | _INR(8,9), d->hal_device->phy.devicenumber, OSHW_CallHAL, EntryNo_HAL_IRQClear);

        dprintf_here("isr=%08x\n", *d->hal_device->phy.irqRegAddr);


        dprintf_here("HELLO %08x test=%d\n", mii_getReg(d, AR8031_MII_IER), d->hal_device->phy.test(1, d->hal_pw));

        uint32_t ssr = mii_getReg(d, AR8031_MII_SSR);
        if ((ssr & AR8031_MII_SSR__SPEED) == AR8031_MII_SSR__SPEED_1000)
        {
                device_modifyReg(d, ENET_ECR, ENET_ECR__SPEED, ENET_ECR__SPEED_1000);
        }
        else
        {
                device_modifyReg(d, ENET_ECR, ENET_ECR__SPEED, ENET_ECR__SPEED_10_100);
        }
        dprintf_here("ssr=%08x ecr=%08x\n", ssr, device_getReg(d, ENET_ECR));
        IGNORE(pw);
        IGNORE(r);

        return CLAIM;
}

