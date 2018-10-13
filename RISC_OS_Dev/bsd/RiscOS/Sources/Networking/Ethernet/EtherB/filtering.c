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
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>

#include "swis.h"
#include "AsmUtils/irqs.h"

#include "sys/types.h"
#include "sys/dcistructs.h"
#include "sys/errno.h"
#include "sys/mbuf.h"
#include "sys/queue.h"
#include "net/ethernet.h"

#include "filtering.h"
#include "glue.h"
#include "bus.h"
#include "seeq8005var.h"
#include "ebmodule.h"

/*
 * Run a single packet through the filters
 */
void filter_input(uint8_t unit, uint8_t class, RxHdr *rxhdr, struct mbuf *chain)
{
	const filter_t *sink = NULL;
	const filter_t *entry;
	uint16_t        frame = rxhdr->rx_frame_type;
	bool            defects = (rxhdr->rx_error_level != 0);

	/* Find the best filter */
	entry = nicunit[unit]->filters;
	while (entry != NULL)
	{
		switch (GET_FRAMELEVEL(entry->type))
		{
			case FRMLVL_E2SINK:
				sink = entry;
				break;

			case FRMLVL_E2MONITOR:
				if ((frame > ETHERMTU) &&
				    IS_A_KEEPER(entry->addresslevel, class) &&
				    IS_GOOD_ENOUGH(entry->errorlevel, defects))
				{
					/* Monitor it */
					DPRINTF(("Rx%c : to monitor\n", '0' + unit));
					filter_to_protocol(&nicunit[unit]->dib,
					                   chain,
					                   entry->handler,
					                   entry->pw);
					return;
				}
				break;

			case FRMLVL_IEEE:
				if ((frame <= ETHERMTU) &&
				    IS_A_KEEPER(entry->addresslevel, class) &&
				    IS_GOOD_ENOUGH(entry->errorlevel, defects))
				{
					/* Raw IEEE */
					DPRINTF(("Rx%c : to IEEE\n", '0' + unit));
					filter_to_protocol(&nicunit[unit]->dib,
					                   chain,
					                   entry->handler,
					                   entry->pw);
					return;
				}
				break;

			case FRMLVL_E2SPECIFIC:
				if ((GET_FRAMETYPE(entry->type) == frame) &&
				    IS_A_KEEPER(entry->addresslevel, class) &&
				    IS_GOOD_ENOUGH(entry->errorlevel, defects))
				{
					/* Specific match for this frame */
					DPRINTF(("Rx%c : to specific protocol\n", '0' + unit));
					filter_to_protocol(&nicunit[unit]->dib,
					                   chain,
					                   entry->handler,
					                   entry->pw);
					return;
				}
				break;
		}
		entry = entry->next;
	}

	/* Unclaimed so far, if there's no sink or it's IEEE, dump it */
	if ((sink == NULL) || (frame <= ETHERMTU) ||
	    !IS_A_KEEPER(sink->addresslevel, class) ||
	    !IS_GOOD_ENOUGH(sink->errorlevel, defects))
	{
		DPRINTF(("Rx%c : discard\n", '0' + unit));
		nicunit[unit]->rx_discards++;
		m_freem(chain);
		return;
	}
	DPRINTF(("Rx%c : to sink\n", '0' + unit));
	filter_to_protocol(&nicunit[unit]->dib,
	                   chain,
	                   sink->handler,
	                   sink->pw);
}

/*
 * Module exit unconditionally destroys the filter list
 */
void filter_destroy(uint8_t unit)
{
	filter_t *entry, *copy;

	entry = nicunit[unit]->filters;
	while (entry != NULL)
	{
		copy = entry->next;
		DPRINTF(("Destroy filter %X at %p\n", entry->type, (void *)entry));
		free(entry);
		entry = copy;
	}
}

/*
 * An entire protocol module has gone
 */
void filter_protocol_remove(uint8_t unit, void *pw)
{
	const filter_t *entry, *remove;

	/* Private words are unique to a protocol module, key off that */
	entry = nicunit[unit]->filters;
	while (entry != NULL)
	{
		remove = entry;
		entry = entry->next;
		if (remove->pw == pw)
		{
			filter_remove(unit, remove->type, remove->addresslevel, remove->errorlevel,
			              remove->handler, remove->pw);
		}
	}
}

/*
 * Add a new filter if possible
 */
_kernel_oserror *filter_add(uint8_t unit, uint32_t type, uint32_t addresslevel, uint32_t errorlevel,
                            filter_handler_t handler, void *pw, uint32_t flags)
{
	filter_t *entry;
	int       state;

	/* Vet the arguments before even considering adding it */
	switch (GET_FRAMELEVEL(type))
	{
		case FRMLVL_E2SINK:
		case FRMLVL_E2MONITOR:
		case FRMLVL_IEEE:
			if (GET_FRAMETYPE(type) != 0)
			{
				/* Must be zero for those */
				return etherb_error_lookup((etherb_err_t)EINVAL);
			}
			/* Fall through */
		case FRMLVL_E2SPECIFIC:
			break;

		default:
			return etherb_error_lookup((etherb_err_t)EINVAL);
	}
	switch (addresslevel)
	{
		case ADDRLVL_SPECIFIC:
		case ADDRLVL_NORMAL:
		case ADDRLVL_MULTICAST:
		case ADDRLVL_PROMISCUOUS:
			break;

		default:
			return etherb_error_lookup((etherb_err_t)EINVAL);
	}
	switch (errorlevel)
	{
		case ERRLVL_NO_ERRORS:
		case ERRLVL_ERRORS:
			break;

		default:
			return etherb_error_lookup((etherb_err_t)EINVAL);
	}

	/* Validate flags */
	if (flags >= FILTER_1STRESERVED)
	{
		etherb_error_lookup((etherb_err_t)EINVAL);
	}

	/* If there are already filters check this isn't a duplicate */
	entry = nicunit[unit]->filters;
	while (entry != NULL)
	{
		/* Highest current level    Permitted new level
		 * ---------------------    -------------------
		 * Nothing (list empty)     Normal/Sink/Monitor
		 * Normal                   Normal/Sink
		 * Sink                     Normal
		 * Monitor                  None
		 * Normal: frame level filtering
		 * Sink: any frames not claimed by 'normal'
		 * Monitor: all frames
		 */
		switch (GET_FRAMELEVEL(entry->type))
		{
			case FRMLVL_E2SPECIFIC:
				/* Permit different specifics and sink */
				if ((entry->type == type) ||
				    (GET_FRAMELEVEL(type) == FRMLVL_E2MONITOR))
				{
					return etherb_error_lookup((etherb_err_t)EFILTERGONE);
				}
				break;

			case FRMLVL_E2SINK:
				/* Permit more specifics and IEEE when sink active */
				if ((GET_FRAMELEVEL(type) == FRMLVL_E2SINK) ||
				    (GET_FRAMELEVEL(type) == FRMLVL_E2MONITOR))
				{
					return etherb_error_lookup((etherb_err_t)EFILTERGONE);
				}
				break;

			case FRMLVL_E2MONITOR:
				/* Permit only non Ethernet II when monitoring */
				if (GET_FRAMELEVEL(type) != FRMLVL_IEEE)
				{
					return etherb_error_lookup((etherb_err_t)EFILTERGONE);
				}
				break;

			case FRMLVL_IEEE:
				/* Only one IEEE at a time */
				if (GET_FRAMELEVEL(type) == FRMLVL_IEEE)
				{
					return etherb_error_lookup((etherb_err_t)EFILTERGONE);
				}
				break;
		}
		entry = entry->next;
	}

	/* Add it and insert it at the list head */
	entry = (filter_t *)malloc(sizeof(filter_t));
	DPRINTF(("Malloc filter %X at %p\n", type, (void *)entry));
	if (entry == NULL) return etherb_error_lookup((etherb_err_t)ENOMEM);
	entry->type = type;
	entry->errorlevel = (uint8_t)errorlevel;
	entry->addresslevel = (uint8_t)addresslevel;
	entry->flags = (uint8_t)flags;
	entry->pw = pw;
	entry->handler = handler;

	/* Careful not to leave the list dangling */
	state = irqs_off();
	entry->next = nicunit[unit]->filters;
	nicunit[unit]->filters = entry;
	restore_irqs(state);

	etherb_review_levels(unit);

	return NULL;
}

/*
 * Remove an existing filter if possible
 */
_kernel_oserror *filter_remove(uint8_t unit, uint32_t type, uint32_t addresslevel, uint32_t errorlevel,
                               filter_handler_t handler, void *pw)
{
	filter_t *entry, *previous;
	bool      removed = FALSE;
	int       state;

	/* No need to range check type/addresslevel/errorlevel because
	 * they can't be in the list after filter_add() checked. Just look for
	 * an exact match
	 */
	previous = NULL;
	entry = nicunit[unit]->filters;
	while (entry != NULL)
	{
		if ((entry->type == type) && (entry->addresslevel == addresslevel) &&
		    (entry->errorlevel == errorlevel))
		{
			/* Match... */
			if ((entry->handler != handler) || (entry->pw != pw))
			{
				/* ...but you didn't register it */
				return etherb_error_lookup((etherb_err_t)EPERM);
			}

			/* Unpick from the list */
			state = irqs_off();
			if (previous == NULL)
			{
				/* Head of list being removed */
				nicunit[unit]->filters = entry->next;
			}
			else
			{
				previous->next = entry->next;
			}
			restore_irqs(state);
			removed = TRUE;
			break;
		}
		previous = entry;
		entry = entry->next;
	}

	if (removed)
	{
		/* Announce that type became free (now the list is self consistent again) */
		_swix(OS_ServiceCall, _INR(0,4), &nicunit[unit]->dib,
		      Service_DCIFrameTypeFree,
		      entry->type, entry->addresslevel, entry->errorlevel);

		/* Release the block */
		DPRINTF(("Free filter %X at %p\n", type, (void *)entry));
		free(entry);

		etherb_review_levels(unit);

		return NULL;
	}

	return etherb_error_lookup((etherb_err_t)EINVAL);
}
