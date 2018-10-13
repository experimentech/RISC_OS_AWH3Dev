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
#include "swis.h"

#include "filtering.h"
#include "glue.h"
#include "bus.h"
#include "selftest.h"
#include "seeq8005reg.h"
#include "seeq8005var.h"
#include "ebmodule.h"

static volatile enum { MATCHED_TYPE, MATCHED_CRC, MATCHED_WAIT, MATCHED_LOCAL_CRC } incoming;
static uint32_t localcrc;

static uint32_t selftest_crc32(const uint8_t *block, size_t length, uint32_t crc)
{
	size_t i;
	int8_t j;

	crc = ~crc;
	for (i = 0; i < length; i++)
	{
		crc = crc ^ block[i];
		for (j = 7; j >= 0; j--)
		{
			/* Uses the bit reversed polynomial 0xEDB88320
			 * instead of the normal 0x04C11DB7 along with a
			 * right shift to avoid having to reverse bits in
			 * every operation
			 */
			crc = (crc >> 1) ^ ((crc & 1) ? 0xEDB88320 : 0);
		}
	}
	return ~crc;
}

static void selftest_emit(struct mbuf *packet, struct ifnet *ifp, uint8_t unit)
{
	uint32_t now, start;

	_swix(OS_ReadMonotonicTime, _OUT(0), &now);
	start = now;
	incoming = MATCHED_WAIT;
	glue_transmit(FALSE, unit, TEST_ETHERII_EXP1, packet,
	              nicunit[unit]->eui, nicunit[unit]->eui,
	              ifp);
	while ((incoming == MATCHED_WAIT) && (now - start < 200))
	{
		_swix(OS_ReadMonotonicTime, _OUT(0), &now);
	}
}

static void selftest_incoming(Dib *dib, struct mbuf *chain)
{
	RxHdr       *header;
	uint32_t     length, chipcrc;
	struct mbuf *mb;

	/* See if what was received is what was expected */
	header = mtod(chain, RxHdr *);
	if (header->rx_frame_type == TEST_ETHERII_EXP1)
	{
		incoming = MATCHED_TYPE;
		if (header->rx_error_level == 0)
		{
			/* And it's error free */
			incoming = MATCHED_CRC;
		}

		/* Sum the data portion of the chain to see if it's a test packet
		 * with the CRC left on. If so, check it matches the computed one.
		 */
		length = 0;
		for (mb = chain; mb != NULL; mb = mb->m_next)
		{
			if (mb->m_type == MT_DATA) length = length + mb->m_len;
		}
		if (length == (TEST_ETHERII_SIZE - ETHER_HDR_LEN + ETHER_CRC_LEN))
		{
			TRIM(chain, -ETHER_CRC_LEN, &chipcrc);
			if (chipcrc == localcrc) incoming = MATCHED_LOCAL_CRC;
		}
	}

	/* In any case, free the chain */
	m_freem(chain);
	UNUSED(dib);
}

bool selftest_execute(struct ifnet *ifp, uint8_t unit, const char *chip, const char *loc, void *pw)
{
	uint8_t   result = TEST_OK;
	uint8_t   skip   = 0;
	uint8_t  *packet;
	int       state;
	filter_t *oldfilters;
	struct mbuf           *wrap, *wrapcrc;
	struct seeq8005_softc *sc = ifp->if_softc;
	struct ether_header   *header;

	/* Ready for (re)test */
	nicunit[unit]->ctrl->faulty = FALSE;
	TEST_VERBOSE(("%s%s %s\n", etherb_message_lookup(MSG33_TEST_LOC, NULL, NULL, NULL),
		                   chip,
		                   loc));

	/* Test 1 - interrupts are needed for the other tests */
	state = ensure_irqs_off();
	ifp->if_ioctl(ifp, IOCTL_TEST_IRQ_MASK, NULL);
	if ((*nicunit[unit]->ctrl->irqstatus & nicunit[unit]->ctrl->irqbit) == nicunit[unit]->ctrl->irqbit)
	{
		/* Set when it shouldn't be */
		skip = TEST_CRCGEN | TEST_LOOPBACK | TEST_LIVEWIRE;
		result |= TEST_IRQS;
	}
	else
	{
		ifp->if_ioctl(ifp, IOCTL_TEST_IRQ_SET, NULL);
		delay(10);
		if ((*nicunit[unit]->ctrl->irqstatus & nicunit[unit]->ctrl->irqbit) != nicunit[unit]->ctrl->irqbit)
		{
			/* Clear when it shouldn't be */
			skip = TEST_CRCGEN | TEST_LOOPBACK | TEST_LIVEWIRE;
			result |= TEST_IRQS;
		}
	}
	ifp->if_ioctl(ifp, IOCTL_TEST_IRQ_RESTORE, NULL);
	restore_irqs(state);
	TEST_VERBOSE(("%s", etherb_message_lookup(MSG34_TEST_IRQS, NULL, NULL, NULL)));
	TEST_VERBOSE(("%s\n", etherb_message_lookup((result & TEST_IRQS) ? MSG17_FAILED : MSG16_PASSED,
	                                           NULL, NULL, NULL)));

	/* Test 2 - buffer memory is needed for the other tests */
	if (sc->sc_flags & SF_FAIL_RAMTEST)
	{
		skip = TEST_CRCGEN | TEST_LOOPBACK | TEST_LIVEWIRE;
		result |= TEST_MEMORY;
	}
	TEST_VERBOSE(("%s", etherb_message_lookup(MSG35_TEST_MEMORY, NULL, NULL, NULL)));
	TEST_VERBOSE(("%s\n", etherb_message_lookup((result & TEST_MEMORY) ? MSG17_FAILED : MSG16_PASSED,
	                                            NULL, NULL, NULL)));

	/* Make a test Ethernet II packet */
	packet = malloc(TEST_ETHERII_SIZE + ETHER_CRC_LEN);
	if (packet == NULL)
	{
		skip = TEST_CRCGEN | TEST_LOOPBACK | TEST_LIVEWIRE;
		wrap = wrapcrc = NULL;
	}
	else
	{
		/* Build the MAC header too so the CRC can be found */
		memset(&packet[ETHER_HDR_LEN], TEST_ETHERII_PATTERN, TEST_ETHERII_SIZE - ETHER_HDR_LEN);
		header = (struct ether_header *)packet;
		memcpy(&header->ether_dhost, nicunit[unit]->eui, ETHER_ADDR_LEN);
		memcpy(&header->ether_shost, nicunit[unit]->eui, ETHER_ADDR_LEN);
		header->ether_type = htons(TEST_ETHERII_EXP1);
		sprintf((char *)&packet[ETHER_HDR_LEN], "TEST PACKET UNIT %d", unit);

		/* Calculate the expected frame check */
		localcrc = selftest_crc32(packet, TEST_ETHERII_SIZE, 0);

		/* Make an mbuf describing to the payload (and again with CRC on the end) */
		wrap    = ALLOC_U(TEST_ETHERII_SIZE - ETHER_HDR_LEN, &packet[ETHER_HDR_LEN]);
		wrapcrc = ALLOC_U(TEST_ETHERII_SIZE - ETHER_HDR_LEN + ETHER_CRC_LEN, &packet[ETHER_HDR_LEN]);
	}

	/* Unhook any protocol clients, run the test, then restore the state back again */
	state = ensure_irqs_off();
	oldfilters = nicunit[unit]->filters;
	nicunit[unit]->filters = NULL;
	restore_irqs(state);
	filter_add(unit,
	           FRMLVL_E2SINK << 16, ADDRLVL_SPECIFIC, ERRLVL_ERRORS,
	           selftest_incoming, pw,
	           FILTER_CLAIM | FILTER_NO_UNSAFE);

	/* Test 3 - loopback */
	if (skip & TEST_LOOPBACK)
	{
		result |= TEST_LOOPBACK;
	}
	else
	{
		bool loopback;

		/* Loop packets */
		loopback = TRUE;
		ifp->if_ioctl(ifp, IOCTL_LOOPBACK, &loopback);

		/* This is not an integrity test so any receive match will do */
		selftest_emit(wrap, ifp, unit);
		if (incoming == MATCHED_WAIT)
		{
			result |= TEST_LOOPBACK;
			skip |= TEST_CRCGEN | TEST_LIVEWIRE;
		}

		/* Remove loop */
		loopback = FALSE;
		ifp->if_ioctl(ifp, IOCTL_LOOPBACK, &loopback);
	}
	TEST_VERBOSE(("%s", etherb_message_lookup(MSG36_TEST_LOOPBACK, NULL, NULL, NULL)));
	TEST_VERBOSE(("%s\n", etherb_message_lookup((result & TEST_LOOPBACK) ? MSG17_FAILED : MSG16_PASSED,
	                                            NULL, NULL, NULL)));

	/* Test 4 - CRC generator */
	if (skip & TEST_CRCGEN)
	{
		result |= TEST_CRCGEN;
	}
	else
	{
		bool     loopback, addcrc, stripcrc;
		uint32_t duffcrc;

		/* Loop packets */
		loopback = TRUE;
		ifp->if_ioctl(ifp, IOCTL_LOOPBACK, &loopback);

		/* Of the 16 possible tests there are only 3 useful ones
		 * a) SW gen CRC sent correctly, HW agrees it is correct
		 * b) SW gen CRC sent incorrectly, HW agrees it is incorrect
		 * c) HW sends a packet, SW agrees it is correct
		 */
		addcrc = FALSE;
		ifp->if_ioctl(ifp, IOCTL_ADD_TX_CRC, &addcrc);
		memcpy(&packet[TEST_ETHERII_SIZE], &localcrc, ETHER_CRC_LEN);
		selftest_emit(wrapcrc, ifp, unit);
		if (incoming != MATCHED_CRC)
		{
			result |= TEST_CRCGEN;
			skip |= TEST_LIVEWIRE;
		}

		duffcrc = ~localcrc;
		memcpy(&packet[TEST_ETHERII_SIZE], &duffcrc, ETHER_CRC_LEN);
		selftest_emit(wrapcrc, ifp, unit);
		if (incoming == MATCHED_CRC)
		{
			result |= TEST_CRCGEN;
			skip |= TEST_LIVEWIRE;
		}

		addcrc = TRUE;
		ifp->if_ioctl(ifp, IOCTL_ADD_TX_CRC, &addcrc);
		stripcrc = FALSE;
		ifp->if_ioctl(ifp, IOCTL_STRIP_RX_CRC, &stripcrc);
		selftest_emit(wrap, ifp, unit);
		if (incoming != MATCHED_LOCAL_CRC)
		{
			result |= TEST_CRCGEN;
			skip |= TEST_LIVEWIRE;
		}
		stripcrc = TRUE;
		ifp->if_ioctl(ifp, IOCTL_STRIP_RX_CRC, &stripcrc);

		/* Remove loop */
		loopback = FALSE;
		ifp->if_ioctl(ifp, IOCTL_LOOPBACK, &loopback);
	}
	TEST_VERBOSE(("%s", etherb_message_lookup(MSG38_TEST_CRCGEN, NULL, NULL, NULL)));
	TEST_VERBOSE(("%s\n", etherb_message_lookup((result & TEST_CRCGEN) ? MSG17_FAILED : MSG16_PASSED,
	                                            NULL, NULL, NULL)));

	/* Test 5 - live wire (optional) */
	if (nicunit[unit]->ctrl->flags & NIC_FLAG_LIVEWIRE)
	{
		if (skip & TEST_LIVEWIRE)
		{
			result |= TEST_LIVEWIRE;
		}
		else
		{
			bool feedback;
	
			/* Receive packets from me */
			feedback = TRUE;
			ifp->if_ioctl(ifp, IOCTL_HEAR_MYSELF, &feedback);
	
			/* The CRC hardware is known good by now, so only an error free receive will do */
			selftest_emit(wrap, ifp, unit);
			if (incoming != MATCHED_CRC)
			{
				result |= TEST_LIVEWIRE;
			}
	
			/* Remove loop */
			feedback = FALSE;
			ifp->if_ioctl(ifp, IOCTL_HEAR_MYSELF, &feedback);
		}
		TEST_VERBOSE(("%s", etherb_message_lookup(MSG37_TEST_LIVEWIRE, NULL, NULL, NULL)));
		TEST_VERBOSE(("%s\n", etherb_message_lookup((result & TEST_LIVEWIRE) ? MSG17_FAILED : MSG16_PASSED,
		                                            NULL, NULL, NULL)));
	}

	/* Rehook any clients and tidy up */
	filter_remove(unit,
	              FRMLVL_E2SINK << 16, ADDRLVL_SPECIFIC, ERRLVL_ERRORS,
	              selftest_incoming, pw);
	state = ensure_irqs_off();
	nicunit[unit]->filters = oldfilters;
	etherb_review_levels(unit);
	restore_irqs(state);
	free(packet);
	m_freem(wrap);
	m_freem(wrapcrc);

	/* As there's only one real chip, a failure of any unit faults all */
	if (nicunit[unit]->ctrl->flags & NIC_FLAG_IGNORE)
	{
		/* Carry on regardless */
		nicunit[unit]->ctrl->faulty = FALSE;
	}
	else
	{
		nicunit[unit]->ctrl->faulty = (result != TEST_OK);
	}
	return (result != TEST_OK);
}
