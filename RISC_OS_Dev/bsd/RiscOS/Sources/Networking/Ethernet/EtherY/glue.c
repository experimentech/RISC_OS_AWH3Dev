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
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <ctype.h>

#include "sys/types.h"
#include "sys/errno.h"
#include "sys/mbuf.h"
#include "sys/queue.h"
#include "sys/dcistructs.h"
#include "net/ethernet.h"

#include "AsmUtils/irqs.h"

#include "filtering.h"
#include "glue.h"
#include "bus.h"
#include "mii.h"
#include "miivar.h"
#include "mii_bitbang.h"
#include "smc91cxxvar.h"
#include "eymodule.h"

/* Local state */
static volatile txdesc_t desc[EY_TX_BUFFER_COUNT];

/*
 * Register the PHY with the PHY handler
 */
void mii_attach(device_t parent, struct mii_data *mii, int capmask,
                int phyloc, int offloc, int flags)
{
	device_t self = (device_t)mii->mii_ifp->if_softc;

	/* Only supporting one (internal) PHY here, so this reduces to
	 * managing a list of 1 entry, so there's nothing to do. 
	 */
	DPRINTF(("PHY id %04X%04X\n", mii->mii_readreg(self, INT_PHY_ADDR, MII_PHYIDR1),
	                              mii->mii_readreg(self, INT_PHY_ADDR, MII_PHYIDR2)));

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
	uint8_t  index;
	uint16_t reg;
	uint32_t flags;
	device_t self = (device_t)mii->mii_ifp->if_softc;

	for (index = 0; index < NIC_MAX_CONTROLLERS; index++)
	{
		/* Match by structure which NIC this would have been */
		if (&nic[index].controller.sc_ec.ec_if == mii->mii_ifp) break;
	}
	DPRINTF(("Configuring PHY on slot %d from CMOS 0x%X\n", nic[index].podule, nic[index].flags)); 

	/* Map from CMOS flags into some PHY setup commands */
	flags = nic[index].flags; 
	if (flags & NIC_FLAG_LINKAUTO)
	{
		DPRINTF(("Setting PHY for autonegotiate\n"));

		reg = ANAR_CSMA;
		if (flags & NIC_FLAG_AD10_FULL) reg |= ANAR_10_FD;
		if (flags & NIC_FLAG_AD10_HALF) reg |= ANAR_10;
		if (flags & NIC_FLAG_AD100_FULL) reg |= ANAR_TX_FD;
		if (flags & NIC_FLAG_AD100_HALF) reg |= ANAR_TX;
		mii->mii_writereg(self, INT_PHY_ADDR, MII_ANAR, reg);

		reg = BMCR_AUTOEN | BMCR_STARTNEG;
		mii->mii_writereg(self, INT_PHY_ADDR, MII_BMCR, reg);
	}
	else
	{
		DPRINTF(("Setting PHY to forced speed & duplex\n"));

		reg = 0;
		if (flags & NIC_FLAG_LINK100) reg |= BMCR_SPEED0;
		if (flags & NIC_FLAG_LINKFULL) reg |= BMCR_FDX; 
		mii->mii_writereg(self, INT_PHY_ADDR, MII_BMCR, reg);
	}

	/* Enable notification on link change, disable packet level ones */
	mii->mii_writereg(self, INT_PHY_ADDR, MII_PHYMSK, ~PHYST_INT &
	                                                  ~PHYST_LNKFAIL &
	                                                  ~PHYST_SPDDET &
	                                                  ~PHYST_DPLXDET);
 
	/* Initial read of the status to clear the latch */
	mii->mii_ifp->phy_status = mii->mii_readreg(self, INT_PHY_ADDR, MII_PHYST);

	return -1;
}

/*
 * Dummy function (use interrupt on change flag rather than polling)
 */
void mii_tick(struct mii_data *mii)
{
	UNUSED(mii);
}

/*
 * Fetch the latest PHY update
 */
void mii_pollstat(struct mii_data *mii)
{
	device_t self = (device_t)mii->mii_ifp->if_softc;

	/* Read (also clears) the latest status */
	mii->mii_ifp->phy_status = mii->mii_readreg(self, INT_PHY_ADDR, MII_PHYST);
}

/*
 * Dummy function
 */
void aprint_normal(void *fmt, ...)
{
	UNUSED(fmt);
}

/*
 * Receive a packet to filter
 */
void glue_receive(struct ifnet *ifp, struct mbuf *chain)
{
	struct mbuf *shuffle;
	uint8_t *hdr;
	RxHdr   *rxhdr;
	int8_t   intf, ctrl, unit;
	int8_t   specific = 0;
	uint16_t frame, class;
	uint32_t length = chain->m_pkthdr.len;

	hdr = mtod(chain, uint8_t *);
	frame = (hdr[(2 * ETHER_ADDR_LEN) + 0] << 8) | hdr[(2 * ETHER_ADDR_LEN) + 1];

	for (ctrl = 0; ctrl < NIC_MAX_CONTROLLERS; ctrl++)
	{
		/* Match by structure which NIC this would have been */
		if (&nic[ctrl].controller.sc_ec.ec_if == ifp)
		{
			break;
		}
	}

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
			for (intf = 0; intf < NIC_MAX_INTERFACES; intf++)
			{
				if (memcmp(hdr, nic[ctrl].interface[intf].eui, ETHER_ADDR_LEN) == 0)
				{
					class = IS_MINE;
					unit = (ctrl * NIC_MAX_INTERFACES) + intf;
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
		for (intf = 0; intf < NIC_MAX_INTERFACES; intf++)
		{
			unit = (ctrl * NIC_MAX_INTERFACES) + intf;
			if ((class == IS_MINE) && (specific != unit)) continue;
			nic[ctrl].interface[intf].rx_errors++;
		}
		m_freem(chain);
		return;
	}
	shuffle->m_list = NULL;
	shuffle->m_type = MT_HEADER;
	rxhdr = mtod(shuffle, RxHdr *);
	rxhdr->rx_tag = 0;
	rxhdr->rx_error_level = (int)chain->m_pkthdr.rcvif;
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
	for (intf = NIC_MAX_INTERFACES - 1; intf >= 0; intf--)
	{
		unit = (ctrl * NIC_MAX_INTERFACES) + intf;
		if ((class == IS_MINE) && (specific != unit)) continue;

		/* Non specifics get propagated to virtual units as clones */
		if ((class != IS_MINE) && (intf > 0))
		{
			struct mbuf *clone;
#if GLUE_DUMP_RX
			printf("Rx%c : clone, %d bytes\n", '0' + unit, length);
#endif
			clone = COPY_P(chain, 0, M_COPYALL);
			if (clone == NULL)
			{
				nic[ctrl].interface[intf].rx_errors++;
			}
			else
			{
				nic[ctrl].interface[intf].rx_packets++;
				nic[ctrl].interface[intf].rx_bytes += length;
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
		nic[ctrl].interface[intf].rx_packets++;
		nic[ctrl].interface[intf].rx_bytes += length;
		filter_input(unit, class, rxhdr, chain);
	}
}

/*
 * Receive error counting
 */
void glue_inc_rxerrors(struct ifnet *ifp)
{
	uint8_t index, intf;

	/* Add this receive error to the corresponding
	 * unit's counts
	 */
	for (index = 0; index < NIC_MAX_CONTROLLERS; index++)
	{
		/* Match by structure which NIC this would have been */
		if (&nic[index].controller.sc_ec.ec_if == ifp)
		{
			for (intf = 0; intf < NIC_MAX_INTERFACES; intf++)
			{
				nicunit[intf]->rx_errors++;
			}
			break;
		}
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
				static uint8_t history;

				ifp->if_snd = CAT(hdr, chain);
				while (ifp->if_snd != NULL)
				{
					/* Block here until (allocation succeeds) and/or it goes */
					s = splnet();
					ifp->if_start(ifp);
					splx(s);
				}

				/* Unlink the header for reuse down the list */
				hdr->m_next = NULL;

				/* The NetBSD driver uses the chip in auto release mode, so the default
				 * stance is that the packet is assumed to be sent. Only on error do
				 * we get notified - keep a record of previously sent packets with
				 * the corresponding MMU handle to fix up the stats.
				 * This allows for virtual interface support at some point.
				 */
				s = splnet();
				nicunit[unit]->tx_packets++;
				nicunit[unit]->tx_bytes += length;
				desc[history].length = length;
				desc[history].unit = unit;
				desc[history].mmu = ifp->if_mmu;
				splx(s);
				history++;
				if (history >= EY_TX_BUFFER_COUNT) history = 0;
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
void glue_transmitted(int8_t which, bool success)
{
	size_t i;

	if (which == EY_TX_BUFFER_COUNT)
	{
		int s;

		/* Special case marks all with the same success state */
		s = splnet();
		for (i = 0; i < EY_TX_BUFFER_COUNT; i++)
		{
			desc[i].mmu = -1;
		}
		splx(s);

		return;
	}

	/* Transmit error, find the matching MMU entry, and debit the account */
	for (i = 0; i < EY_TX_BUFFER_COUNT; i++)
	{
		if (desc[i].mmu == which)
		{
			nicunit[desc[i].unit]->tx_packets--;
			nicunit[desc[i].unit]->tx_bytes -= desc[i].length;
			nicunit[desc[i].unit]->tx_errors++;
			break;
		}
	}

	UNUSED(success);
}

/*
 * Microsecond delay
 */
void delay(uint32_t delay)
{
	volatile uint8_t *rom = (volatile uint8_t *)nic[0].rombase;
	uint8_t  dummy;

	while (delay)
	{
		/* Using Podule_Speed_TypeC takes 5 x 16MHz ticks per
		 * access, or 312.5ns. So we can waste 1us by reading
		 * the flash four-ish times
		 */
		dummy = *rom;
		dummy = *rom;
		dummy = *rom;
		dummy = *rom;
		delay--;
	}
}
