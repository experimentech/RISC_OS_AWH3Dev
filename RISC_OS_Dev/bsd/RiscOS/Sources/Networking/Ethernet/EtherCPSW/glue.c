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
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include "swis.h"

#include "sys/types.h"
#include "sys/systm.h"
#include "sys/errno.h"
#include "sys/mbuf.h"
#include "sys/queue.h"
#include "sys/dcistructs.h"
#include "net/ethernet.h"

#include "AsmUtils/clz.h"
#include "AsmUtils/irqs.h"
#include "Global/HALDevice.h"
#include "Global/HALEntries.h"
#include "Global/OSRSI6.h"
#include "Global/OSMisc.h"

#include "EtherCPSWHdr.h"
#include "filtering.h"
#include "bus.h"
#include "glue.h"
#include "if_cpswreg.h"
#include "ecpmodule.h"

#include "mii.h"
#include "miivar.h"

/*
 * Register the PHY with the PHY handler
 */
void mii_attach(device_t parent, struct mii_data *mii, int capmask,
                int phyloc, int offloc, int flags)
{
	device_t self = (device_t)mii->mii_ifp->if_softc;
	int8_t   address;
	uint32_t id;
	size_t   mac;

	/* Mark none found */
	for (mac = 0; mac < CPSW_ETH_PORTS; mac++)
	{
		mii->mii_ifp->mac[mac].phy_address = -1;
	}

	/* Scan for all possible PHYs */
	for (mac = 0, address = MII_NPHY - 1; address >= 0; address--)
	{
		id = mii->mii_readreg(self, address, MII_PHYIDR1) |
		     (mii->mii_readreg(self, address, MII_PHYIDR2) << 16);
		if (id != 0)
		{
			if (mac < CPSW_ETH_PORTS)
			{
				/* Assign to MAC and finish */
				mii->mii_ifp->mac[mac].phy_id = id;
				mii->mii_ifp->mac[mac].phy_address = address;
				DPRINTF(("PHY addr %u for MAC %u, id=%08X\n",
				         address, mac, id));
			}
			mac++;
		}
	}

	/* We handle the PHYs via a static struct for simplicity, as there
	 * isn't really an MII driver backing it up, so mark the list empty.
	 */
	LIST_INIT(&mii->mii_phys);

	UNUSED(parent);
	UNUSED(capmask);
	UNUSED(phyloc);
	UNUSED(offloc);
	UNUSED(flags);
}

/*
 * Media change request, write the PHY settings again
 */
int mii_mediachg(struct mii_data *mii)
{
	size_t   i;
	uint16_t reg;
	uint16_t flags;
	device_t self = (device_t)mii->mii_ifp->if_softc;

	for (i = 0; i < CPSW_ETH_PORTS; i++)
	{
		DPRINTF(("Configuring PHY on MAC %d from CMOS 0x%X\n", i, nic[i].flags));

		/* Map from CMOS flags into some PHY setup commands */
		flags = nic[i].flags;
		if (flags & NIC_FLAG_LINKAUTO)
		{
			DPRINTF(("Setting PHY for autonegotiate\n"));

			reg = ANAR_CSMA;
			if (flags & NIC_FLAG_FLOW_GEN) reg |= ANAR_PAUSE_SYM;
			if (flags & NIC_FLAG_FLOW_RESP) reg |= ANAR_PAUSE_ASYM;
			if (flags & NIC_FLAG_AD10_FULL) reg |= ANAR_10_FD;
			if (flags & NIC_FLAG_AD10_HALF) reg |= ANAR_10;
			if (flags & NIC_FLAG_AD100_FULL) reg |= ANAR_TX_FD;
			if (flags & NIC_FLAG_AD100_HALF) reg |= ANAR_TX;
			mii->mii_writereg(self, mii->mii_ifp->mac[i].phy_address, MII_ANAR, reg);

			reg = BMCR_AUTOEN | BMCR_STARTNEG;
			mii->mii_writereg(self, mii->mii_ifp->mac[i].phy_address, MII_BMCR, reg);

			reg = 0;
			if (flags & NIC_FLAG_AD1000) reg |= GTCR_ADV_1000TFDX | GTCR_ADV_1000THDX;
			mii->mii_writereg(self, mii->mii_ifp->mac[i].phy_address, MII_100T2CR, reg);
		}
		else
		{
			DPRINTF(("Setting PHY to forced speed & duplex\n"));

			reg = 0;
			if (flags & NIC_FLAG_LINK100) reg |= BMCR_SPEED0;
			if (flags & NIC_FLAG_LINKFULL) reg |= BMCR_FDX;
			mii->mii_writereg(self, mii->mii_ifp->mac[i].phy_address, MII_BMCR, reg);
		}

		/* Everyone loves flashy lights, force single LED mode */
		mii->mii_writereg(self, mii->mii_ifp->mac[i].phy_address, MII_MMDACR, MMDACR_FN_ADDRESS | MII_MMDCCD);
		mii->mii_writereg(self, mii->mii_ifp->mac[i].phy_address, MII_MMDAADR, MII_MMDCCA);
		mii->mii_writereg(self, mii->mii_ifp->mac[i].phy_address, MII_MMDACR, MMDACR_FN_DATANPI | MII_MMDCCD);
		reg = mii->mii_readreg(self, mii->mii_ifp->mac[i].phy_address, MII_MMDAADR);
		mii->mii_writereg(self, mii->mii_ifp->mac[i].phy_address, MII_MMDAADR, reg | MMDCC_LEDOVRD);
	}

	return 0;
}

/*
 * Inform the PHY that the interface is now down
 */
void mii_down(struct mii_data *mii)
{
	UNUSED(mii);
}

/*
 * Period poll of PHY (because only port 0 can get MDIO ints, not port 1)
 */
void mii_tick(struct mii_data *mii)
{
	size_t   i;
	uint16_t reg;
	device_t self = (device_t)mii->mii_ifp->if_softc;
	struct ifnet *ifp = mii->mii_ifp;

	/* Refresh all the cached copies of PHY status */
	for (i = 0; i < CPSW_ETH_PORTS; i++)
	{
		if (ifp->mac[i].phy_address == -1) continue;
		reg = mii->mii_readreg(self, ifp->mac[i].phy_address, MII_VSPHYST);
		if ((reg & (PHYST_SPD10 | PHYST_SPD100 | PHYST_SPD1000)) == 0)
		{
			/* Link fail bit never seems to set even when cable unplugged,
			 * so if none of the speed bits are on assume no link!
			 */
			reg |= PHYST_LNKFAIL;
		}
		ifp->mac[i].phy_status = reg; 
	}
}

/*
 * Dummy function
 */
void aprint_normal(void *fmt, ...)
{
	UNUSED(fmt);
}

void panic(const char *fmt, ...)
{
	UNUSED(fmt);
}

/*
 * Little helpers
 */
uint32_t shiftout(uint32_t value, uint32_t mask)
{
	return (value & mask) >> ctz(mask);
}

/*
 * Autoconf attach details
 */
static int (*intrfn[4])(void *);
static void *intrarg[4];

void *intr_establish(int irq, int priority, int level, int (*fn)(void *), void *arg)
{
	size_t i;
	_kernel_oserror *err;
	extern struct device *device;

	i = irq - device->devicenumber; /* Device number to array index */
	if (i > (sizeof(intrfn)/sizeof(intrfn[0])))
	{
		/* Bad */
		return NULL;
	}
	intrfn[i] = fn;
	intrarg[i] = arg;

	/* Unmask the interrupt */
	err = _swix(OS_Hardware, _IN(0) | _INR(8,9),
	            irq, OSHW_CallHAL, EntryNo_HAL_IRQEnable);
	if (err == NULL)
	{
		/* Arbitrary non zero opaque handle */
		return &intrfn[i];
	}
	UNUSED(level);
	UNUSED(priority);

	return NULL;
}

void intr_disestablish(void *ih)
{
	UNUSED(ih);
}

int intr_handler(_kernel_swi_regs *r, void *pw)
{
	size_t i;
	extern struct device *device;

	i = (r->r[0] & 0xFFFFFF) - device->devicenumber; /* Device number to array index */
	if ((i > (sizeof(intrfn)/sizeof(intrfn[0]))) ||
	    (intrfn[i] == NULL))
	{
		/* Not handled */
		return 1;
	}
	UNUSED(pw);

	if (intrfn[i](intrarg[i]))
	{
		/* Handled, so clear and claim */
		_swix(OS_Hardware, _IN(0) | _INR(8,9),
		      r->r[0] & 0xFFFFFF, OSHW_CallHAL, EntryNo_HAL_IRQClear);
		return 0;
	}
	return 1;
}

void obio_attach_from_hal_device(struct obio_attach_args *oaa, struct device *device)
{
	const uint32_t *table;
	uintptr_t       phys, log;

	/* There surely must be a nicer API to get hold of the physical address
	 * of some IO, rather than assuming OS_Memory maps in IO in 1MB chunks,
	 * and grubbing round in the L1PT, but seems not.
	 */
	_swix(OS_ReadSysInfo, _INR(0,2) | _OUT(2), 6, 0, OSRSI6_L1PT, &table);
	log = (uintptr_t)device->address; 
	phys = table[log >> 20];
	oaa->obio_addr = (phys & ~0xFFFFF) + (log & 0xFFFFF);
	oaa->obio_intrbase = device->devicenumber;
}

/*
 * Receive a packet to filter
 */
void glue_receive(struct ifnet *unused, struct mbuf *chain)
{
	struct mbuf *shuffle;
	uint8_t *hdr;
	RxHdr   *rxhdr;
	int8_t   ctrl, unit;
	int8_t   specific = 0;
	uint16_t frame, class;
	uint32_t length = chain->m_pkthdr.len;

	hdr = mtod(chain, uint8_t *);
	frame = (hdr[(2 * ETHER_ADDR_LEN) + 0] << 8) | hdr[(2 * ETHER_ADDR_LEN) + 1];

	/* Recover which NIC this would have been */
	ctrl = (int8_t)(((uintptr_t)chain->m_pkthdr.rcvif) >> 8) - 1;

	/* Don't process packets from faulty hardware */
	if (nic[ctrl].faulty)
	{
		m_freem(chain);
		return;
	}
 
	/* Figure out which EUI48 class it is */
	if (((hdr[0] & 1) != 0) && (hdr[0] != 0xFF))
	{
		class = IS_MULTICAST;
	}
	else
	{
		if ((hdr[0] & hdr[1] & hdr[2] & hdr[3] & hdr[4] & hdr[5]) == 0xFF)
		{
			class = IS_BROADCAST;
		}
		else
		{
			/* Specific of some sort */
			class = IS_SPECIFIC;
			for (unit = 0; unit < units; unit++)
			{
				if (nicunit[unit]->ctrlnum != ctrl) continue;
				if (memcmp(hdr, nicunit[unit]->eui, ETHER_ADDR_LEN) == 0)
				{
					class = IS_MINE;
					specific = unit;
					break;
				}
			}
		}
	}

	/* Shuffle the header into protocol handler format */
	shuffle = ALLOC_S(sizeof(RxHdr), NULL);
	if (shuffle == NULL)
	{
		for (unit = 0; unit < units; unit++)
		{
			if (nicunit[unit]->ctrlnum != ctrl) continue;
			if ((class == IS_MINE) && (specific != unit)) continue;
			nicunit[unit]->rx_errors++;
		}
		m_freem(chain);
		return;
	}
	shuffle->m_list = NULL;
	shuffle->m_type = MT_HEADER;
	rxhdr = mtod(shuffle, RxHdr *);
	rxhdr->rx_tag = 0;
	rxhdr->rx_error_level = (int)((uintptr_t)chain->m_pkthdr.rcvif & 0xFF);
	rxhdr->_spad[0] = rxhdr->_spad[1] = 0;
	rxhdr->_dpad[0] = rxhdr->_dpad[1] = 0;
	memcpy(rxhdr->rx_dst_addr, &hdr[0], ETHER_ADDR_LEN);
	memcpy(rxhdr->rx_src_addr, &hdr[ETHER_ADDR_LEN], ETHER_ADDR_LEN);
	rxhdr->rx_frame_type = frame;

	/* Ditch the flattened head of the chain, and prefix the shuffled copy */
	shuffle->m_next = chain->m_next;
	m_free(chain);
	chain = shuffle;

	/* Pass on to unit(s) concerned */
	for (unit = units - 1; unit >= 0; unit--)
	{
		if (nicunit[unit]->ctrlnum != ctrl) continue;
		if ((class == IS_MINE) && (specific != unit)) continue;

		/* Non specifics get propagated to virtual units as clones */
		if ((class != IS_MINE) && nicunit[unit]->virtual)
		{
			struct mbuf *clone;
#if GLUE_DUMP_RX
			printf("Rx%c : clone, %d bytes\n", '0' + unit, length);
#endif
			clone = COPY_P(chain, 0, M_COPYALL);
			if (clone == NULL)
			{
				nicunit[unit]->rx_errors++;
			}
			else
			{
				nicunit[unit]->rx_packets++;
				nicunit[unit]->rx_bytes += length;
				filter_input(unit, class, rxhdr, clone);
			}
			continue;
		}
#if GLUE_DUMP_RX
		printf("Rx%c : ", '0' + unit);
		GLUE_DUMP_EUI48(rxhdr->rx_dst_addr);
		printf(": ");
		GLUE_DUMP_EUI48(rxhdr->rx_src_addr);
		printf(": type %04X, %d bytes\n", rxhdr->rx_frame_type, length);
#endif
		/* Remainder is for this specific unit or is the master copy for unit 0 */
		nicunit[unit]->rx_packets++;
		nicunit[unit]->rx_bytes += length;
		filter_input(unit, class, rxhdr, chain);
	}

	UNUSED(unused);
}

/*
 * Receive error counting
 */
void glue_inc_rxerrors(uint8_t port)
{
	size_t i;

	/* Due to the error, the EUI48 may be duff, so
	 * attribute an error to all interfaces that port serves.
	 */
	port--;
	for (i = 0; i < units; i++)
	{
		if (nicunit[i]->ctrlnum == port) nicunit[i]->rx_errors++;
	}
}

/*
 * Transmit packet list
 */
int glue_transmit(bool free, uint8_t unit, uint16_t frame,
                  struct mbuf *list, uint8_t *src, uint8_t *dst, struct ifnet *ifp)
{
	struct mbuf *chain, *mb, *hdr;
	int          error = -1;
	size_t       i;
	int          s;

	/* Build a common header for all packets in the chain */
	hdr = ALLOC_S(ETHER_HDR_LEN, NULL);
	if (hdr == NULL)
	{
		error = ENOBUFS;
		s = splnet();
		nicunit[unit]->tx_errors++;
		splx(s);
	}
	if (error < 0)
	{
		uint8_t *data;

		/* Copy in the header fields */
		data = mtod(hdr, uint8_t *);
		for (i = 0; i < ETHER_ADDR_LEN; i++)
		{
			data[0              + i] = dst[i];
			data[ETHER_ADDR_LEN + i] = src[i];
		}
		data[(2 * ETHER_ADDR_LEN) + 0] = (uint8_t)(frame >> 8);
		data[(2 * ETHER_ADDR_LEN) + 1] = (uint8_t)frame;

		/* Gate on whether the NIC works or not */
		if (nicunit[unit]->ctrl->faulty) error = ENETDOWN;
	}

	while (list != NULL)
	{
		chain = list;
		list = list->m_list;

		/* Send each chain in the list until first error */
		if (error < 0)
		{
			uint32_t length;

			/* Sum the chain */
			length = 0;
			for (mb = chain; mb != NULL; mb = mb->m_next)
			{
				length = length + mb->m_len;
			}
			if (length > nicunit[unit]->ctrl->mtu)
			{
				error = EMSGSIZE;
				s = splnet();
				nicunit[unit]->tx_errors++;
				splx(s);
			}
#if GLUE_DUMP_TX
			printf("Tx%c : ", '0' + unit);
			GLUE_DUMP_EUI48(dst);
			printf(": ");
			GLUE_DUMP_EUI48(src);
			printf(": type %04X, %d bytes", frame, length);
			if (length < (ETHER_MIN_LEN - ETHER_HDR_LEN))
			{
				printf(" + %d pad\n", ETHER_MIN_LEN - ETHER_HDR_LEN - length);
			}
			else
			{
				printf("\n");
			}
#endif
			if (error < 0)
			{
				s = splnet();
				ifp->if_snd = CAT(hdr, chain);
				ifp->if_sndport = nicunit[unit]->ctrlnum;
				ifp->if_sndunit = unit;
				ifp->if_start(ifp);
				splx(s);

				/* Unlink the header for reuse down the list */
				hdr->m_next = NULL;

				/* If the chain wasn't dequeued infer an error */
				if (ifp->if_snd != NULL)
				{
					error = EIO;
					s = splnet();
					nicunit[unit]->tx_errors++;
					splx(s);
				}
			}
		}

		/* Free (when our responsibility) even if error */
		if (free) m_freem(chain);
	}

	/* Done with the header too */
	m_free(hdr);

	return error;
}

/*
 * Post transmit statistics gathering
 */
void glue_transmitted(uint8_t unit, size_t length, bool success)
{
	if (success)
	{
		nicunit[unit]->tx_packets++;
		nicunit[unit]->tx_bytes += length - ETHER_HDR_LEN;
	}
	else
	{
		nicunit[unit]->tx_errors++;
	}
}

/*
 * Initial interface attach
 */
void glue_attachif(struct ifnet *ifp)
{
	/* As the softc is kept as a private struct, the only thing to do here
	 * is grab a copy of the address of the ifnet so we have the
	 * function pointers available.
	 */
	nicifp = ifp;
}

/*
 * Callouts
 */
static void (*tickfn)(void *);
static void *tickarg;
static bool tickrun = FALSE;
void callout_schedule(callout_t *c, int ticks)
{
	tickrun = TRUE;
	UNUSED(ticks);
	UNUSED(c);
}

void callout_setfunc(callout_t *c, void (*fn)(void *), void *arg)
{
	tickfn = fn;
	tickarg = arg;
	UNUSED(c);
}

bool callout_stop(callout_t *c)
{
	tickrun = FALSE;
	UNUSED(c);

	return FALSE;
}

void callout_callevery(void)
{
	if (tickrun && (tickfn != NULL))
	{
		tickfn(tickarg);
	}
	if (nicifp->if_timer)
	{
		nicifp->if_timer--;
		if (nicifp->if_timer == 0) nicifp->if_watchdog(nicifp);
	}
}

/*
 * Bus space
 */
static void (*dmb_read)(void);
static void (*dmb_write)(void);
uint32_t bus_read_4(bus_space_handle_t space, bus_size_t offset)
{
	volatile uint32_t *base;

	base = (volatile uint32_t *)space;

	return base[offset >> 2];
}

void bus_read_region_4(bus_space_handle_t space, bus_size_t offset, uint32_t *datap, size_t count)
{
	volatile uint32_t *base;

	base = (volatile uint32_t *)space;
	while (count)
	{
		*datap = base[offset >> 2];
		offset = offset + sizeof(uint32_t);
		datap++;
		count--;
	}
}

void bus_write_4(bus_space_handle_t space, bus_size_t offset, uint32_t value)
{
	volatile uint32_t *base;

	base = (volatile uint32_t *)space;
	base[offset >> 2] = value;
}

void bus_write_region_4(bus_space_handle_t space, bus_size_t offset, const uint32_t *datap, size_t count)
{
	volatile uint32_t *base;

	base = (volatile uint32_t *)space;
	while (count)
	{
		base[offset >> 2] = *datap;
		offset = offset + sizeof(uint32_t);
		datap++;
		count--;
	}
}

void bus_set_region_4(bus_space_handle_t space, bus_size_t offset, uint32_t value, size_t count)
{
	volatile uint32_t *base;

	base = (volatile uint32_t *)space;
	while (count)
	{
		base[offset >> 2] = value;
		offset = offset + sizeof(uint32_t);
		count--;
	}
}

int bus_space_map(bus_space_tag_t space, bus_addr_t address, bus_size_t size,
                  int flags, bus_space_handle_t *handlep)
{
	/* The HAL already mapped in the whole register set. Just set the handle to
	 * be the logical address so that bus_space_subregion() can use it as a base.
	 */
	*handlep = (bus_space_handle_t)device->address;
	UNUSED(space);
	UNUSED(address);
	UNUSED(size);
	UNUSED(flags);

	return 0;
}

void bus_space_unmap(bus_space_tag_t space, bus_space_handle_t handle, bus_size_t size)
{
	/* Leave it */
	UNUSED(space);
	UNUSED(handle);
	UNUSED(size);
}

int bus_space_subregion(bus_space_tag_t space, bus_space_handle_t handle,
                        bus_size_t offset, bus_size_t size, bus_space_handle_t *nhandlep)
{
	/* The HAL already mapped in the whole register set. Just derive a new
	 * handle (logical address) for use with read_4 and write_4.
	 */
	*nhandlep = (bus_space_handle_t)(offset + (uintptr_t)handle);
	UNUSED(space);
	UNUSED(size);

	return 0;
}

int bus_dmamap_create(bus_dma_tag_t tag, bus_size_t size, int nsegments, bus_size_t maxsegsz,
                      bus_size_t boundary, int flags, bus_dmamap_t *dmamp)
{
	_kernel_oserror *err;
	void *phys, *log;
	bus_dma_segment_t *segment;
	bus_dmamap_t map;

	/* Check we've got the memory barriers for DMA related sync */
	if ((dmb_read == NULL) && (dmb_write == NULL))
	{
		err = _swix(OS_MMUControl, _IN(0) | _OUT(0),
		            MMUCReason_GetARMop + (ARMop_DMB_Write << 8), &dmb_write);
		if (err != NULL) return ENOMEM;
		err = _swix(OS_MMUControl, _IN(0) | _OUT(0),
		            MMUCReason_GetARMop + (ARMop_DMB_Read << 8), &dmb_read);
		if (err != NULL) return ENOMEM;
	}

	/* Mostly ignore the arguments passed by if_cpsw. Instead, make the size much closer to the MTU,
	 * and granularity quite fine (since CPSW's DMA engine only needs word aligned data), then
	 * allocate from uncached memory - see 'doc/DataPumping' for rationale.
	 */
	size = MIN(size, 2048);

	segment = malloc(sizeof(bus_dma_segment_t));
	if (segment == NULL)
	{
		return ENOMEM;
	}

	map = malloc(sizeof(*map));
	if (map == NULL)
	{
		free(segment);

		return ENOMEM;
	}

	err = _swix(PCI_RAMAlloc, _INR(0,2) | _OUTR(0,1), size, 32, 0,
	                                                  &log, &phys);
	if (err != NULL)
	{
		free(map);
		free(segment);

		return ENOMEM;
	}

	/* Populate the mandatory members */
	map->dm_mapsize = 2048;
	map->dm_nsegs = 1;
	map->dm_segs = segment;
	segment->ds_addr = (bus_addr_t)phys;
	segment->ds_len = 2048;
	segment->ds_logical = (bus_addr_t)log;
	*dmamp = map;

	UNUSED(flags);
	UNUSED(boundary);
	UNUSED(tag);
	UNUSED(nsegments);
	UNUSED(maxsegsz);

	return 0;
}

void bus_dmamap_destroy(bus_dma_tag_t tag, bus_dmamap_t dmam)
{
	_kernel_oserror *err;

	err = _swix(PCI_RAMFree, _IN(0), dmam->dm_segs[0].ds_logical);
	if (err != NULL)
	{
		DPRINTF(("Failed to free uncached RAM %p\n", (void *)dmam->dm_segs[0].ds_logical)); 
	}
	free(dmam->dm_segs);
	free(dmam);

	UNUSED(tag);
}

int bus_dmamap_load(bus_dma_tag_t tag, bus_dmamap_t dmam, void *buf, bus_size_t buflen,
                    struct proc *p, int flags)
{
	/* Just copy the data into the uncached area */
	if ((dmam == NULL) ||
	    (dmam->dm_nsegs == 0) ||
	    (buflen > dmam->dm_mapsize))
	{
		return EINVAL;
	}
	memcpy((void *)dmam->dm_segs[0].ds_logical, buf, buflen);
	dmam->dm_segs[0].ds_len = buflen;

	UNUSED(tag);
	UNUSED(p);
	UNUSED(flags);

	return 0;
}

int bus_dmamap_load_mbuf(bus_dma_tag_t tag, bus_dmamap_t dmam, struct mbuf *chain, int flags)
{
	/* Just copy the mbuf into the uncached area */
	if ((dmam == NULL) ||
	    (dmam->dm_nsegs == 0))
	{
		return EINVAL;
	}
	EXPORT(chain, dmam->dm_mapsize, (void *)dmam->dm_segs[0].ds_logical);
	dmam->dm_segs[0].ds_len = m_length(chain);

	UNUSED(tag);
	UNUSED(flags);

	return 0;
}

void bus_dmamap_unload(bus_dma_tag_t tag, bus_dmamap_t dmam)
{
	/* Nothing to do, nothing was consumed during a load */
	UNUSED(tag);
	UNUSED(dmam);
}

void bus_dmamap_sync(bus_dma_tag_t tag, bus_dmamap_t dmam, bus_addr_t offset,
                     bus_size_t len, int ops)
{
	switch (ops)
	{
		case BUS_DMASYNC_PREREAD | BUS_DMASYNC_PREWRITE:
			/* Both */
		case BUS_DMASYNC_PREREAD:
			/* DMA about to write to RAM, ensure prior CPU writes are done */
		case BUS_DMASYNC_PREWRITE:
			/* DMA about to fetch from RAM, ensure CPU writes made it */
			dmb_write();
			break;

		case BUS_DMASYNC_POSTREAD | BUS_DMASYNC_POSTWRITE:
			/* Both */
		case BUS_DMASYNC_POSTREAD:
			/* DMA has written to RAM, ensure CPU didn't read ahead */
			dmb_read();
			break;

		case BUS_DMASYNC_POSTWRITE:
			/* DMA finished, nothing the CPU needs to do */
			break;
	}

	UNUSED(tag);
	UNUSED(dmam);
	UNUSED(offset);
	UNUSED(len);
}

/*
 * Microsecond delay
 */
void delay(uint32_t delay)
{
	_swix(OS_Hardware, _IN(0) | _INR(8,9), delay, OSHW_CallHAL, EntryNo_HAL_CounterDelay);
}
