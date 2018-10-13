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
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <ctype.h>

#include "sys/types.h"
#include "sys/errno.h"
#include "sys/mbuf.h"
#include "sys/dcistructs.h"
#include "net/ethernet.h"

#include "AsmUtils/irqs.h"

#include "filtering.h"
#include "glue.h"
#include "bus.h"
#include "seeq8005reg.h"
#include "seeq8005var.h"
#include "ebmodule.h"

/* Local state */
static volatile txdesc_t desc[EA_TX_BUFFER_COUNT];

/*
 * Translate a change in address or error level to chip settings
 */
void glue_set_levels(struct ifnet *ifp)
{
	uint8_t  unit, esummed, asummed;
	uint16_t passerrors;
	uint16_t matchmode;

	/* Since there's only one controller, combine levels */
	asummed = ADDRLVL_SPECIFIC;
	esummed = ERRLVL_NO_ERRORS;
	for (unit = 0; unit < units; unit++)
	{
		esummed = MAX(esummed, nicunit[unit]->ctrl->errorlevel);
		asummed = MAX(asummed, nicunit[unit]->ctrl->addresslevel);
	}

	/* While the 8005 and 80C04A do have more than 1 station address slot,
	 * keep things common to all supported chips by going promiscuous.
	 */
	if (units > 1) asummed = ADDRLVL_PROMISCUOUS;

	/* Map to SEEQ chip register bits */
	switch (esummed)
	{
		case ERRLVL_NO_ERRORS:
			passerrors = 0;
			break;

		default:
			passerrors = SEEQ_CFG2_CRC_ERR_ENABLE | SEEQ_CFG2_DRIB_ERR_ENABLE;
			break;
	}
	switch (asummed)
	{
		case ADDRLVL_SPECIFIC:
			matchmode = SEEQ_CFG1_SPECIFIC;
			break;

		case ADDRLVL_NORMAL:
			matchmode = SEEQ_CFG1_BROADCAST;
			break;

		case ADDRLVL_MULTICAST:
			matchmode = SEEQ_CFG1_MULTICAST;
			break;

		case ADDRLVL_PROMISCUOUS:
			matchmode = SEEQ_CFG1_PROMISCUOUS;
			break;
	}

	/* Write to the chip */
	ifp->if_ioctl(ifp, IOCTL_SET_MATCHMODE, &matchmode);
	ifp->if_ioctl(ifp, IOCTL_PASS_RXERRORS, &passerrors);
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

	/* Only one supported, so it must be this controller */
	ctrl = 0;

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
	for (unit = units - 1; unit >= 0; unit--)
	{
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
void glue_inc_rxerrors(void)
{
	size_t i;

	/* Add this receive error to the corresponding
	 * unit's counts
	 */
	for (i = 0; i < units; i++)
	{
		nicunit[i]->rx_errors++;
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
				/* The original NetBSD code only permitted one pending transmit
				 * packet at a time, dequeueing the next only when the first completed.
				 * In this driver the slack time while the chip is transmitting on the
				 * wire is used to stuff more data into the chip, so some record of
				 * packets posted but not yet sent must be retained in descriptors.
				 */
				i = 0;
				while (1)
				{
					/* Find a descriptor, or block here in SVC mode with interrupts
					 * enabled until one becomes free
					 */
					if (!desc[i].inuse) break;
					i++;
					if (i >= EA_TX_BUFFER_COUNT) i = 0;
				}
				hdr->m_type = i;
				desc[i].length = length;
				desc[i].unit = unit;
				desc[i].inuse = TRUE;
				ifp->if_snd = CAT(hdr, chain);
				ifp->if_start(ifp);

				/* Unlink the header for reuse down the list */
				hdr->m_next = NULL;
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
void glue_transmitted(uint8_t which, bool success)
{
	if (which == EA_TX_BUFFER_COUNT)
	{
		int s;

		/* Special case marks all with the same success state */
		s = splnet();
		for (which = 0; which < EA_TX_BUFFER_COUNT; which++)
		{
			if (desc[which].inuse) glue_transmitted(which, success);
		}
		splx(s);

		return;
	}

	/* A packet completed, update statistics now it's definitely gone */
	if (success)
	{
		nicunit[desc[which].unit]->tx_packets++;
		nicunit[desc[which].unit]->tx_bytes += desc[which].length;
	}
	else
	{
		nicunit[desc[which].unit]->tx_errors++;
	}
	desc[which].inuse = FALSE;
}

/*
 * Dummy function (no logging)
 */
void logentry(log_severity_t severity, const char *fmt, ...)
{
	UNUSED(severity);
	UNUSED(fmt);
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
		 * the EPROM four-ish times
		 */
		dummy = *rom;
		dummy = *rom;
		dummy = *rom;
		dummy = *rom;
		delay--;
	}
}
