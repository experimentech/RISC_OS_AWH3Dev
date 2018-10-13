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

#include "Global/OsBytes.h"
#include "Global/Services.h"
#include "Global/Variables.h"
#include "Interface/Podule.h"
#include "AsmUtils/irqs.h"
#include "swis.h"

#include <sys/types.h>
#include <sys/dcistructs.h>
#include <sys/errno.h>
#include <sys/mbuf.h>
#include <net/ethernet.h>

#include "EtherBHdr.h"
#include "filtering.h"
#include "glue.h"
#include "bus.h"
#include "selftest.h"
#include "seeq8005var.h"
#include "ebmodule.h"

/* Global state */
uint8_t       units;
etherb_nic_t  nic[NIC_MAX_CONTROLLERS];
etherb_if_t  *nicunit[NIC_MAX_INTERFACES * NIC_MAX_CONTROLLERS];
struct mbctl  mbctl;

/* Local state */
static bool            mbufsession;
static uint32_t        message_block[4];
static const char      driver_name[] = "eb";
static const char      driver_title[] = "EtherB";
static uint8_t         padbuf[ETHER_MIN_LEN - ETHER_CRC_LEN];

static void etherb_stats(bool fill, uint8_t unit, struct stats *buffer)
{
	if (fill)
	{
		/* Fill in the stats */
		buffer->st_interface_type = ST_TYPE_10BASE2NT;
		buffer->st_link_polarity = ST_LINK_POLARITY_CORRECT;
		buffer->st_link_status = ST_STATUS_HALF_DUPLEX;
		if (!nicunit[unit]->ctrl->faulty)
		{
			/* Passed self test, so it must be OK and active */
			buffer->st_link_status |= ST_STATUS_OK | ST_STATUS_ACTIVE;
		}
		switch (nicunit[unit]->ctrl->addresslevel)
		{
			case ADDRLVL_SPECIFIC:
				buffer->st_link_status |= ST_STATUS_DIRECT;
				break;

			case ADDRLVL_NORMAL:
				buffer->st_link_status |= ST_STATUS_BROADCAST;
				break;

			case ADDRLVL_MULTICAST:
				buffer->st_link_status |= ST_STATUS_MULTICAST;
				break;

			case ADDRLVL_PROMISCUOUS:
				buffer->st_link_status |= ST_STATUS_PROMISCUOUS;
				break;
		}

		buffer->st_tx_frames = nicunit[unit]->tx_packets;
		buffer->st_tx_bytes = nicunit[unit]->tx_bytes;
		buffer->st_tx_general_errors = nicunit[unit]->tx_errors;

		buffer->st_unwanted_frames = nicunit[unit]->rx_discards;
		buffer->st_rx_frames = nicunit[unit]->rx_packets;
		buffer->st_rx_bytes = nicunit[unit]->rx_bytes;
		buffer->st_rx_general_errors = nicunit[unit]->rx_errors;
	}
	else
	{
		/* Report which are gathered with all 1's */
		memset(buffer, 0, sizeof(struct stats));
		buffer->st_interface_type = 0xFF;
		buffer->st_link_polarity = 0xFF;
		buffer->st_link_status = 0xFF;

		buffer->st_tx_frames = 0xFFFFFFFFuL;
		buffer->st_tx_bytes = 0xFFFFFFFFuL;
		buffer->st_tx_general_errors = 0xFFFFFFFFuL;

		buffer->st_unwanted_frames = 0xFFFFFFFFuL;
		buffer->st_rx_frames = 0xFFFFFFFFuL;
		buffer->st_rx_bytes = 0xFFFFFFFFuL;
		buffer->st_rx_general_errors = 0xFFFFFFFFuL;
	}
}

static void etherb_stop_mbuf_session(void)
{
	_swix(Mbuf_CloseSession, _IN(0), &mbctl);
	mbufsession = FALSE;
}

static _kernel_oserror *etherb_start_mbuf_session(void)
{
	_kernel_oserror *error = NULL;

	/* Read the MbufManager version number to deduce its presence, and
	 * try to open a session if not got a session already.
	 */
	if ((_swix(Mbuf_Control, _IN(0), 0) == NULL) && !mbufsession)
	{
		/* Client initialisers */
		mbctl.mbcsize = sizeof(mbctl);
		mbctl.mbcvers = MBUF_MANAGER_VERSION;
		mbctl.flags = 0;
		mbctl.advminubs = MINCONTIG;
		mbctl.advmaxubs = ETHERMTU;
		mbctl.mincontig = MINCONTIG;
		mbctl.spare1 = 0;

		/* Try to get a session */
		error = _swix(Mbuf_OpenSession, _IN(0), &mbctl);
		if (error == NULL) mbufsession = TRUE;
	}

	return error;
}

static const char *etherb_name_chip(etherb_nic_t *nic)
{
	static const char *chips[] =  { "80C04/16b", "8005/16b", "80C04A/16b",
	                                "80C04/8b",  "8005/8b",  "80C04A/8b"
	                              };
	uint8_t entry;

	/* Numbers don't need internationalising */
	entry = nic->controller.sc_variant;
	if (nic->controller.sc_flags & SF_8004_TYPE_A) entry = entry + 2;
	if (nic->controller.sc_flags & SF_8BIT) entry = entry + 3;

	return chips[entry];
}

static _kernel_oserror *etherb_open_messages(void)
{
	_kernel_oserror *error;

#ifndef ROM
	/* Register the messages for RAM based modules */
	error = _swix(ResourceFS_RegisterFiles, _IN(0), etherb_messages());
	if (error != NULL) return error;
#endif

	/* Try open, report fail */
	error = _swix(MessageTrans_OpenFile, _INR(0,2), message_block, Module_MessagesFile, 0);
#ifndef ROM
	if (error != NULL) _swix(ResourceFS_DeregisterFiles, _IN(0), etherb_messages());
#endif
	return error;
}

static void etherb_destroy_messages(void)
{
	/* Tidy up and deregister */
	_swix(MessageTrans_CloseFile, _IN(0), message_block);
#ifndef ROM
	_swix(ResourceFS_DeregisterFiles, _IN(0), etherb_messages());
#endif
}

static void etherb_add_interface(uint8_t unit, uint8_t index, int32_t slot, void *pw)
{
	uint32_t info[9];
	int32_t  number;
	uint8_t  andmask, ormask;

	/* Get some vitals */
	memset(info, 0, sizeof(info));
	_swix(Podule_ReadInfo, _INR(0,3),
	      Podule_ReadInfo_SyncBase |
	      Podule_ReadInfo_CMOSAddress |
	      Podule_ReadInfo_CMOSSize |
	      Podule_ReadInfo_ROMAddress |
	      Podule_ReadInfo_IntStatus |      
	      Podule_ReadInfo_IntRequest |
	      Podule_ReadInfo_IntMask |
	      Podule_ReadInfo_IntValue |
	      Podule_ReadInfo_IntDeviceVector,
	      info, sizeof(info), slot);
	nic[index].podule = slot;
	nic[index].hwbase = (void *)info[0];
	nic[index].cmos = info[1];
	nic[index].cmossize = info[2];
	nic[index].rombase = (void *)info[3];
	nic[index].irqstatus = (volatile const uint32_t *)info[4];
	nic[index].irqrequest = (volatile const uint32_t *)info[5];
	nic[index].irqmask = (volatile uint32_t *)info[6];
	nic[index].irqbit = info[7];
	nic[index].irqdevice = info[8];
	DPRINTF(("%s in podule %d, controller at 0x%p, ROM at 0x%p\n",
	        driver_title, slot, nic[index].hwbase, nic[index].rombase));
       
	/* Crank up the speed */
	_swix(Podule_SetSpeed, _IN(0) | _IN(3), Podule_Speed_TypeC, slot); 

	/* Read the unique id separately so failure can be given a distinct error code */
	info[0] = info[1] = 0;
	_swix(Podule_ReadInfo, _INR(0,3),
	      Podule_ReadInfo_EthernetAddress,
	      info, sizeof(info), slot);
	for (number = 0; number < ETHER_ADDR_LEN; number++)
	{
		const uint8_t *eui = (uint8_t *)info;

		/* Endian swap */
		nicunit[unit]->eui[ETHER_ADDR_LEN - number - 1] = eui[number];
	}

	/* Check the EUI48 is sane */
	andmask = ormask = nicunit[unit]->eui[0];
	DPRINTF(("EUI48 %02X", nicunit[unit]->eui[0]));
	for (number = 1; number < ETHER_ADDR_LEN; number++)
	{
		andmask &= nicunit[unit]->eui[number];
		ormask |= nicunit[unit]->eui[number];
		DPRINTF((":%02X", nicunit[unit]->eui[number]));
	}
	DPRINTF(("\n"));
	if ((andmask == 0xFF) || (ormask == 0))
	{
		nic[index].faulty |= NIC_FAULT_NO_EUI48;
		return;
	}

	/* Modify it for multiple addresses per machine */
	if (nicunit[unit]->virtual)
	{
		memcpy(nicunit[unit]->eui, nic[0].interface[0].eui, ETHER_ADDR_LEN);
		nicunit[unit]->eui[EUI_ALT_BYTE] |= EUI_ALT_BIT;
	}

	/* Check the CMOS odd parity else default */
	nic[index].flags = NIC_FLAG_DEFAULT;
	if (nic[index].cmossize)
	{
		uint32_t flags;
		uint8_t  parity = 0;

		if (_swix(OS_Byte, _INR(0,1) | _OUT(2), OsByte_ReadCMOS, nic[index].cmos, &flags) == NULL)
		{
			for (number = 0; number < 8; number++)
			{
				if (flags & (1 << number)) parity++;
			}
			if (parity & 1)
			{
				nic[index].flags = flags;
				DPRINTF(("CMOS restored from 0x%X as 0x%X\n", nic[index].cmos, nic[index].flags));
			}
			else
			{
				_swix(OS_Byte, _INR(0,2), OsByte_WriteCMOS, nic[index].cmos, NIC_FLAG_DEFAULT);
				DPRINTF(("CMOS failed parity, defaulted\n"));
			}
		}
	}

	/* Skip initialise if chip not enabled */
	if ((nic[index].flags & NIC_FLAG_ENABLE) == 0) return;

	/* Mark as configured successfully */
	nic[index].mtu = ETHERMTU;
	nicunit[unit]->filters = NULL;
	_swix(OS_ReadMonotonicTime, _OUT(0), &nic[index].starttime);

	if (!nicunit[unit]->virtual)
	{
		/* The 80C04 only has one hardware address slot (8005 & 80C04A have more),
		 * for commonality only one hardware address is used, any virtual interfaces
		 * go promiscuous and use software filtering. Now, get attached to the chip.
		 */
		nic[index].ifp = &nic[index].controller.sc_ethercom.ec_if;
		nic[index].ifp->if_sadl = (struct sockaddr_dl *)nicunit[unit]->eui;
		nic[index].controller.sc_iot = (uintptr_t)nic[index].hwbase;
		seeq8005_attach(&nic[index].controller, padbuf, NULL, 0, 0);
		if (nic[index].controller.sc_flags & SF_FAIL_AUTODETECT)
		{
			DPRINTF(("No recognised MAC (or PHY) found\n"));
			nic[index].faulty |= NIC_FAULT_NO_LANCHIP;
			return;
		}
		DPRINTF(("Attached seeq8005 in slot %d as unit %s%d\n", slot, driver_name, unit));
	}

	/* Translate the location */
	nicunit[unit]->dib.dib_location = (unsigned char *)malloc(32);
	if (nicunit[unit]->dib.dib_location == NULL)
	{
		nic[index].faulty |= NIC_FAULT_NO_RMA;
		return;
	}
	else
	{
		char locname[32];

		strcpy(locname, etherb_message_lookup(MSG12_NIC, NULL, NULL, NULL));
		sprintf((char *)nicunit[unit]->dib.dib_location, locname, slot);
	} 

	/* Fill in a device info block */
	nicunit[unit]->dib.dib_swibase = EtherB_00;
	nicunit[unit]->dib.dib_name = (unsigned char *)driver_name;
	nicunit[unit]->dib.dib_unit = unit;
	nicunit[unit]->dib.dib_address = nicunit[unit]->eui;
	nicunit[unit]->dib.dib_module = (unsigned char *)driver_title;
	nicunit[unit]->dib.dib_slot.sl_slotid = DIB_SLOT_PODULE(slot);
	nicunit[unit]->dib.dib_slot.sl_minor = 0;
	nicunit[unit]->dib.dib_slot.sl_pcmciaslot = 0;
	nicunit[unit]->dib.dib_slot.sl_mbz = 0;
	nicunit[unit]->dib.dib_inquire = INQ_MULTICAST |
	                                 INQ_RXERRORS |
	                                 INQ_HWADDRVALID |
	                                 INQ_SOFTHWADDR |
	                                 INQ_HASSTATS |
	                                 INQ_CANREFLECT |
	                                 INQ_PROMISCUOUS;
	if (nicunit[unit]->virtual)
	{
		nicunit[unit]->dib.dib_inquire |= INQ_VIRTUAL | INQ_SWVIRTUAL;
	}

	UNUSED(pw);
}

static _kernel_oserror *etherb_config_option(const char *args)
{
	_kernel_oserror *error;
	char     param[16 + 1];
	uint32_t count = 0;
	uint32_t flags;
	uint8_t  parity = 0;
	bool     match = FALSE;
	uint8_t  unit = 0;

	/* Turn into a caseless C string */
	while ((*args > ' ') && (count < (sizeof(param) - 1)))
	{
		param[count] = toupper(*args);
		args++;
		count++;
	}
	param[count] = 0;

	/* Check what follows is only spaces */
	while (*args == ' ')
	{
		args++;
	}
	if (*args > ' ') return configure_TOO_MANY_PARAMS;

	/* Get the CMOS */
	error = _swix(OS_Byte, _INR(0,1) | _OUT(2), OsByte_ReadCMOS, nicunit[unit]->ctrl->cmos, &flags);
	if (error != NULL) return error;

	/* So now there is only one cleaned parameter */
	if (strcmp(param, "DISABLE") == 0)        match = TRUE, flags &= ~NIC_FLAG_ENABLE;
	if (strcmp(param, "ENABLE") == 0)         match = TRUE, flags |= NIC_FLAG_ENABLE;
	if (strcmp(param, "STRICT") == 0)         match = TRUE, flags &= ~NIC_FLAG_IGNORE;
	if (strcmp(param, "IGNORE") == 0)         match = TRUE, flags |= NIC_FLAG_IGNORE;
	if (strcmp(param, "NOLIVEWIRETEST") == 0) match = TRUE, flags &= ~NIC_FLAG_LIVEWIRE;
	if (strcmp(param, "LIVEWIRETEST") == 0)   match = TRUE, flags |= NIC_FLAG_LIVEWIRE;
	if (strcmp(param, "TERSE") == 0)          match = TRUE, flags &= ~NIC_FLAG_VERBOSE;
	if (strcmp(param, "VERBOSE") == 0)        match = TRUE, flags |= NIC_FLAG_VERBOSE;
	if (strcmp(param, "SINGLE") == 0)         match = TRUE, flags &= ~NIC_FLAG_MULTIPLE;
	if (strcmp(param, "MULTIPLE") == 0)       match = TRUE, flags |= NIC_FLAG_MULTIPLE;
	if (strcmp(param, "DEFAULT") == 0)        match = TRUE, flags = NIC_FLAG_DEFAULT;
	if (!match) return configure_BAD_OPTION;

	/* Redo the parity */
	for (count = 0; count < 8; count++)
	{
		if (flags & (1 << count)) parity++;
	}
	if ((parity & 1) == 0) flags ^= NIC_FLAG_PARITY;
	DPRINTF(("Applied %s to get new CMOS flags 0x%X\n", param, flags));

	/* Note configure options are not applied until next reset */
	return _swix(OS_Byte, _INR(0,2), OsByte_WriteCMOS, nicunit[unit]->ctrl->cmos, flags);
}

static void etherb_lineup_info(etherb_msg_t tag, const char *value, uint32_t length)
{
	/* Regimented columns of information */
	length = length - printf(etherb_message_lookup(tag, NULL, NULL, NULL));
	while (length)
	{
		putchar(' ');
		length--;
	}
	printf(": %s\n", value);
}

static void etherb_interface_info(uint8_t which)
{
	uint32_t        longest, now, level;
	char            msg[80];
	const filter_t *list;

	/* Headings for this unit */
	strcpy(msg, (char *)nicunit[which]->dib.dib_location);
	msg[0] = tolower(msg[0]); 
	printf("\n%s%d: %s, %s, %s\n\n",
	       driver_name,
	       which,
	       etherb_name_chip(nicunit[which]->ctrl),
	       msg,
	       etherb_message_lookup(nicunit[which]->ctrl->faulty ? MSG11_DOWN : MSG10_UP, NULL, NULL, NULL));

	/* Find where the columns line up */
	longest = strlen(etherb_message_lookup(MSG00_INFO_LENGTH, NULL, NULL, NULL));

	/* Driver */
	etherb_lineup_info(MSG01_IF_DRIVER, driver_name, longest);

	/* Unit */
	sprintf(msg, "%d", which);
	etherb_lineup_info(MSG02_IF_UNIT, msg, longest);

	/* Location */
	etherb_lineup_info(MSG03_IF_LOCATION, (char *)nicunit[which]->dib.dib_location, longest);

	/* EUI48 */
	sprintf(msg, "%02X:%02X:%02X:%02X:%02X:%02X",
	        nicunit[which]->eui[0], nicunit[which]->eui[1],
	        nicunit[which]->eui[2], nicunit[which]->eui[3],
	        nicunit[which]->eui[4], nicunit[which]->eui[5]);
	etherb_lineup_info(MSG04_IF_EUI, msg, longest);

	/* Controller */
	etherb_lineup_info(MSG05_IF_CONTROLLER, etherb_name_chip(nicunit[which]->ctrl), longest);

	/* Running time */
	_swix(OS_ReadMonotonicTime, _OUT(0), &now);
	now = (now - nicunit[which]->ctrl->starttime) / 100;
	sprintf(msg, etherb_message_lookup(MSG09_TIME_FORMAT, NULL, NULL, NULL),
	        now / 86400, (now % 86400) / 3600, (now % 3600) / 60, now % 60);
	etherb_lineup_info(MSG06_IF_RUNTIME, msg, longest);

	/* Copyright notice */
	strcpy(msg, etherb_message_lookup(MSG14_AUTHOR, NULL, NULL, NULL));
	etherb_lineup_info(MSG07_IF_ATTRIBUTE, msg, longest);
	strcpy(msg, etherb_message_lookup(MSG15_AUTHOR, NULL, NULL, NULL));
	etherb_lineup_info(MSG19_EMPTY, msg, longest);

	/* Send and receive stats */
	sprintf(msg, "%u", nicunit[which]->tx_packets);
	etherb_lineup_info(MSG20_STAT_P_SENT, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_packets);
	etherb_lineup_info(MSG21_STAT_P_RECEIVED, msg, longest);
	sprintf(msg, "%u", nicunit[which]->tx_bytes);
	etherb_lineup_info(MSG22_STAT_B_SENT, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_bytes);
	etherb_lineup_info(MSG23_STAT_B_RECEIVED, msg, longest);
	sprintf(msg, "%u", nicunit[which]->tx_errors);
	etherb_lineup_info(MSG24_STAT_E_SENT, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_errors);
	etherb_lineup_info(MSG25_STAT_E_RECEIVED, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_discards);
	etherb_lineup_info(MSG26_STAT_UNDELIVERED, msg, longest);

	/* Registered frame filters */
	sprintf(msg, "%s\n", etherb_message_lookup(MSG31_FRAME_DESC, NULL, NULL, NULL));
	for (level = FRMLVL_IEEE; level >= FRMLVL_E2SPECIFIC; level--)
	{
		bool shown = FALSE;
		static const etherb_msg_t headings[] = { MSG30_FRAME_STANDARD,
		                                         MSG29_FRAME_SINK,
		                                         MSG28_FRAME_MONITOR,
		                                         MSG27_FRAME_802_3
		                                       };

		list = nicunit[which]->filters;
		while (list != NULL)
		{
			/* Filter the filters by level */
			if (GET_FRAMELEVEL(list->type) == level)
			{
				if (!shown)
				{
					/* One off print the section heading */
					shown = TRUE;
					printf("\n%s:\n\n", etherb_message_lookup(headings[level - 1], NULL, NULL, NULL));
				}
				printf(msg, GET_FRAMETYPE(list->type),
				       list->addresslevel, list->errorlevel,
				       list->handler, list->pw);
			}
			list = list->next;
		}
	}
}

/*
 * A change in address or error level occurred
 */
void etherb_review_levels(uint8_t unit)
{
	uint8_t         alevel, elevel;
	const filter_t *entry;

	/* Scan all the filters and pick the slackest level */
	alevel = ADDRLVL_SPECIFIC;
	elevel = ERRLVL_NO_ERRORS;
	entry = nicunit[unit]->filters;
	while (entry != NULL)
	{
		alevel = MAX(alevel, entry->addresslevel);
		elevel = MAX(elevel, entry->errorlevel);
		entry = entry->next;
	}
	DPRINTF(("Reviewed %s%d, new alevel=%d, new elevel=%d\n", driver_name, unit, alevel, elevel));
	nicunit[unit]->ctrl->addresslevel = alevel;
	nicunit[unit]->ctrl->errorlevel = elevel;

	/* Sync the hardware level */
	glue_set_levels(nicunit[unit]->ctrl->ifp);
}

/*
 * Internationalised messages
 */
char *etherb_message_lookup(etherb_msg_t which, const char *arg1, const char *arg2, const char *arg3)
{
	static char message[256];
	char token[8];

	sprintf(token, "M%02d", which);
	if (_swix(MessageTrans_Lookup, _INR(0,7),
	          message_block, token, message, sizeof(message),
	          arg1, arg2, arg3, 0) != NULL)
	{
		/* Lookup failed, hardwire to english */
		strcpy(message, "Message lookup failed");
	}

	return message;
}

/*
 * Internationalised errors
 */
_kernel_oserror *etherb_error_lookup(etherb_err_t which)
{
	static _kernel_oserror error;
	char token[8];

	sprintf(token, "E%02d", which);
	if (_swix(MessageTrans_Lookup, _INR(0,7),
	          message_block, token, error.errmess, sizeof(error.errmess),
	          0, 0, 0, 0) != NULL)
	{
		/* Lookup failed, hardwire to english */
		strcpy(error.errmess, "Message lookup failed");
	}
	if (which < ErrorBase_UnixRange)
	{
		/* Unix error, translate this to a DCI4 error */
		error.errnum = DCI4ERRORBLOCK + which;
	}
	else
	{
		/* Private error, use module's allocation */
		error.errnum = ErrorBase_ANTEtherB + which - ErrorBase_UnixRange;
	}

	return &error;
}

/*
 * Ticker heartbeat
 */
_kernel_oserror *etherb_heartbeat_handler(_kernel_swi_regs *r, void *pw)
{
	uint8_t index;

	for (index = 0; index < NIC_MAX_CONTROLLERS; index++)
	{
		struct ifnet *ifp;

		if (!nic[index].running) continue;
		ifp = nic[index].ifp;
		if (ifp->if_timer)
		{
			ifp->if_timer--;
			if (ifp->if_timer == 0) ifp->if_watchdog(ifp);
		}
	}

	UNUSED(r);
	UNUSED(pw);

	return NULL;
}

/*
 * Interrupt from the network chip
 */
_kernel_oserror *etherb_interrupt_handler(_kernel_swi_regs *r, void *pw)
{
	uint8_t index;

	/* Only one supported, so it must be this controller */
	index = 0;
	seeq8005intr(&nic[index].controller);

	UNUSED(r);
	UNUSED(pw);

	return NULL;
}

/*
 * Callback when linked into the module chain
 */
_kernel_oserror *etherb_driver_linked_handler(_kernel_swi_regs *r, void *pw)
{
	uint8_t  oldmbs, unit;
	char     var[8];
	uint32_t length;

	/* Here because the MbufManager started or via callback now my SWIs
	 * are available, either way, try opening an MbufManager session.
	 */
	oldmbs = mbufsession;
	etherb_start_mbuf_session();
	if ((oldmbs != mbufsession) && mbufsession)
	{
		/* Start 1s watchdog */
		_swix(OS_CallEvery, _INR(0,2), 100, etherb_heartbeat, pw);

		/* Enable send/receive */
		DPRINTF(("Got mbufs, going online\n"));

		/* Transitioned to functioning state */
		for (unit = 0; unit < units; unit++)
		{
			struct ifnet *ifp = nicunit[unit]->ctrl->ifp;

			ifp->if_init(ifp);
			if (selftest_execute(ifp, unit, etherb_name_chip(nicunit[unit]->ctrl),
			                     (char *)nicunit[unit]->dib.dib_location, pw))
			{
				DPRINTF(("Selftest of %s%d failed\n", driver_name, unit));
				nicunit[unit]->ctrl->faulty |= NIC_FAULT_SELFTEST;
			}

			if (!nicunit[unit]->ctrl->faulty)
			{
				if (!nicunit[unit]->ctrl->running)
				{
					nicunit[unit]->ctrl->running = TRUE;
					DPRINTF(("NIC in slot %d running\n", nicunit[unit]->ctrl->podule));
				}

				_swix(OS_ServiceCall, _INR(0,3),
				      &nicunit[unit]->dib,
				      Service_DCIDriverStatus,
				      DCIDRIVER_STARTING, DCIVERSION);
				DPRINTF(("Announced %s%d is starting\n", driver_name, unit));
			}
		}

		/* Set the compatibility variable to the last starting driver */
		length = sprintf(var, "%s0", driver_name);
		_swix(OS_SetVarVal, _INR(0,4),
		      "Inet$EtherType",
		      var, length, 0, VarType_LiteralString);
	}
	else
	{
		DPRINTF(("Failed to get mbufs\n"));
	}

	UNUSED(r);

	return NULL;
}

/*
 * Initialisation
 */
_kernel_oserror *etherb_init(const char *cmd_tail, int podule_base, void *pw)
{
	uint8_t  header[16];
	uint16_t manufacturer, product;
	int32_t  number, slot;
	_kernel_oserror *error;
	int      state;

	error = etherb_open_messages();
	if (error != NULL) return error;

	/* Only 1 set of hardware, only 1 instance */
	if (podule_base == 1)
	{
		error = etherb_error_lookup(ERR03_SINGLE_INSTANCE);
		goto init_fail;
	}

	/* Check for podule support */
	if ((_swix(Podule_ReturnNumber, _OUT(0), &number) != NULL) ||
	    (number == 0))
	{
		error = etherb_error_lookup(ERR00_NO_PODULES);
		goto init_fail;
	}

	/* Look in the NIC slot for a supported adapter */
	slot = number - 1;
	if (_swix(Podule_ReadHeader, _INR(2,3), header, slot) == NULL)
	{
		manufacturer = header[5] | (header[6] << 8);
		product =      header[3] | (header[4] << 8);
		if ((product != ProdType_ANTEtherB) || (manufacturer != Manf_ANTLimited))
		{
			error = etherb_error_lookup(ERR01_NIC_NOT_ETHERB);
			goto init_fail;
		}

		/* Always one real one */
		nicunit[units] = &nic[0].interface[0];
		nicunit[units]->ctrl = &nic[0];
		nicunit[units]->virtual = FALSE;
		etherb_add_interface(units, 0, slot, pw);
		units++;

		/* Maybe a virtual one */
		if (nic[0].flags & NIC_FLAG_MULTIPLE)
		{
			nicunit[units] = &nic[0].interface[1];
			nicunit[units]->ctrl = &nic[0];
			nicunit[units]->virtual = TRUE;
			etherb_add_interface(units, 0, slot, pw);
			units++;
		}
	}
	DPRINTF(("Total of %d %s interfaces\n", units, driver_title));
	if (units == 0)
	{
		error = etherb_error_lookup(ERR01_NIC_NOT_ETHERB);
		goto init_fail;
	}

	/* Attach and unmask the interrupt */
	error = _swix(OS_ClaimDeviceVector, _INR(0,4),
	              nic[0].irqdevice, etherb_interrupt, pw,
	              nic[0].irqstatus, nic[0].irqbit);
	if (error != NULL)
	{
		nic[0].faulty |= NIC_FAULT_NO_VECTOR;
		goto init_fail;
	}
	state = irqs_off();
	*nic[0].irqmask |= nic[0].irqbit;
	restore_irqs(state);

	/* Everything else has to be done on a callback once my SWIs are available */
	_swix(OS_AddCallBack, _INR(0,1), etherb_driver_linked, pw);

	UNUSED(cmd_tail);

	return NULL;

init_fail:
	units = 0;
	etherb_destroy_messages();

	return error;
}

/*
 * Finalisation
 */
_kernel_oserror *etherb_final(int fatal, int podule, void *pw)
{
	uint8_t unit;

	/* When fatal is -ve it's a Service_PreReset, skip clean up */
	if (fatal >= 0)
	{
		for (unit = 0; unit < units; unit++)
		{
			if (!mbufsession) continue;

			/* Elvis has left the building */
			_swix(OS_ServiceCall, _INR(0,3),
			      &nicunit[unit]->dib,
			      Service_DCIDriverStatus,
			      DCIDRIVER_DYING, DCIVERSION);

			DPRINTF(("Announced %s%d is dying\n", driver_name, unit));

			/* Don't leak old filters */
			filter_destroy(unit);

			/* Finished with the location */
			free(nicunit[unit]->dib.dib_location);
		}
		etherb_stop_mbuf_session();
		etherb_destroy_messages();
	}

	/* Halt any booked callbacks */
	_swix(OS_RemoveTickerEvent, _INR(0,1), etherb_heartbeat, pw);
	_swix(OS_RemoveCallBack, _INR(0,1), etherb_driver_linked, pw);

	for (unit = 0; unit < units; unit++)
	{
		if (nicunit[unit]->ctrl->running)
		{
			struct ifnet *ifp = nicunit[unit]->ctrl->ifp;

			/* Go offline */
			DPRINTF(("NIC in slot %d going offline\n", nicunit[unit]->ctrl->podule));
			ifp->if_stop(ifp, TRUE);
			nicunit[unit]->ctrl->running = FALSE;

			/* Get off the vector */
			_swix(OS_ReleaseDeviceVector, _INR(0,4),
			      nicunit[unit]->ctrl->irqdevice, etherb_interrupt, pw,
			      nicunit[unit]->ctrl->irqstatus, nicunit[unit]->ctrl->irqbit);
			DPRINTF(("Hardware shut down\n"));
		}
	}

	UNUSED(podule);

	return NULL;
}

/*
 * Service call handler
 */
void etherb_services(int service_number, _kernel_swi_regs *r, void *pw)
{
	uint8_t unit;

	switch (service_number)
	{
		case Service_MbufManagerStatus:
			switch (r->r[0])
			{
				case MbufManagerStatus_Started:
					/* MbufManager started after this module, so go do the
					 * startup sideeffects.
					 */
					DPRINTF(("MbufManager up\n"));
					etherb_driver_linked_handler(r, pw);
					break;

				case MbufManagerStatus_Stopping:
					/* This might arrive if this module is the very last client
					 * to stop, but since the session is only closed in the finalisation
					 * handler it's probably safe to ignore.
					 */
					DPRINTF(("MbufManager stopped and my session is %s\n",
					        mbufsession ? "open" : "closed"));
					break;

				case MbufManagerStatus_Scavenge:
				default:
					break;
			}
			break;

		case Service_EnumerateNetworkDrivers:
			/* Driver only useful if linked with MBufManager */
			if (!mbufsession) break;
			for (unit = 0; unit < units; unit++)
			{
				ChDib *chain;

				/* It is the caller's responsibility to free the chain */
				chain = (ChDib *)malloc(sizeof(ChDib));
				if (chain != NULL)
				{
					chain->chd_dib = &nicunit[unit]->dib;
					chain->chd_next = (ChDib *)r->r[0];
					r->r[0] = (int)chain;
				}
			}
			break;

		case Service_PreReset:
			/* Make sure the hardware can't interrupt during reset */
			etherb_final(-1, 0, pw);
			break;

		case Service_DCIProtocolStatus:
			if (((r->r[3] / 100) == (DCIVERSION / 100)) &&
			    (r->r[2] == DCIPROTOCOL_DYING))
			{
				DPRINTF(("Protocols for %s to be removed\n", (char *)r->r[4]));
				for (unit = 0; unit < units; unit++)
				{
					/* Check if that protocol owns any filters */
					filter_protocol_remove(unit, (void *)r->r[0]);
				}
			}
			break;

#ifndef ROM
		case Service_ResourceFSStarting:
			(*(void (*)(void *, void *, void *, void *))r->r[2])(etherb_messages(), 0, 0, (void *)r->r[3]);
			break;
#endif
	}
}

/*
 * Command handler
 */
_kernel_oserror *etherb_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
	_kernel_oserror *error;
	uint32_t select;
	uint32_t flags;
	bool     fail;

	switch (cmd_no)
	{
		case CMD_EBInfo:
			if (argc == 0)
			{
				/* When not specified, do all */
				if (units == 0) return etherb_error_lookup(ERR05_UNIT_IS_OFF);
				printf("%s\n", etherb_message_lookup(MSG18_INFO_STATS, NULL, NULL, NULL));
				for (select = 0; select < units; select++)
				{
					etherb_interface_info(select);
				}
			}
			else
			{
				error = _swix(OS_ReadUnsigned, _INR(0,1) | _OUT(2),
				              10, arg_string, &select);
				if (error) return error;
				if (select >= units) return etherb_error_lookup(ERR05_UNIT_IS_OFF);
				printf("%s\n", etherb_message_lookup(MSG18_INFO_STATS, NULL, NULL, NULL));
				etherb_interface_info(select);
			}
			break;

		case CMD_EBTest:
			if (argc == 0)
			{
				/* When not specified, do all */
				if (units == 0) return etherb_error_lookup(ERR05_UNIT_IS_OFF);
				for (select = 0; select < units; select++)
				{
					struct ifnet *ifp = nicunit[select]->ctrl->ifp;

					fail = selftest_execute(ifp, select, etherb_name_chip(nicunit[select]->ctrl),
					                        (char *)nicunit[select]->dib.dib_location, pw);
					printf("%s%d %s", driver_name,
					                  select,
					                  etherb_message_lookup(MSG32_SELFTEST, NULL, NULL, NULL));
					printf(" %s\n", etherb_message_lookup(fail ?
					                                      MSG17_FAILED :
					                                      MSG16_PASSED, NULL, NULL, NULL));
				}
			}
			else
			{
				struct ifnet *ifp;

				error = _swix(OS_ReadUnsigned, _INR(0,1) | _OUT(2),
				              10, arg_string, &select);
				if (error) return error;
				if (select >= units) return etherb_error_lookup(ERR05_UNIT_IS_OFF);
				ifp = nicunit[select]->ctrl->ifp;
				fail = selftest_execute(ifp, select, etherb_name_chip(nicunit[select]->ctrl),
				                        (char *)nicunit[select]->dib.dib_location, pw);
				printf("%s%d %s", driver_name,
				                  select,
				                  etherb_message_lookup(MSG32_SELFTEST, NULL, NULL, NULL));
				printf(" %s\n", etherb_message_lookup(fail ?
				                                      MSG17_FAILED :
				                                      MSG16_PASSED, NULL, NULL, NULL));
			}
			break;

		case CMD_EtherB:
			/* Check for *STATUS and *CONFIGURE alone */
			if (arg_string == arg_STATUS)
			{
				select = 0;
				error = _swix(OS_Byte, _INR(0,1) | _OUT(2),
				              OsByte_ReadCMOS, nicunit[select]->ctrl->cmos, &flags);
				if (error != NULL) return NULL;

				printf("EtherB     %s\nEtherB     %s\n"
				       "EtherB     %s\nEtherB     %s\nEtherB     %s\n",
				       flags & NIC_FLAG_ENABLE ? "Enable" : "Disable",
				       flags & NIC_FLAG_IGNORE ? "Ignore" : "Strict",
				       flags & NIC_FLAG_LIVEWIRE ? "LiveWireTest" : "NoLiveWireTest",
				       flags & NIC_FLAG_VERBOSE ? "Verbose" : "Terse",
				       flags & NIC_FLAG_MULTIPLE ? "Multiple" : "Single");

				return NULL;
			}
			if (arg_string == arg_CONFIGURE_SYNTAX)
			{
				/* Configure keywords aren't internationalised,
				 * so the syntax mustn't be either.
				 */
				printf("EtherB     Disable | Enable\n"
				       "EtherB     Strict | Ignore\n"
				       "EtherB     NoLiveWireTest | LiveWireTest\n"
				       "EtherB     Terse | Verbose\n"
				       "EtherB     Single | Multiple\n"
				       "EtherB     Default\n");

				return NULL;
			}

			/* Otherwise, trying to set it */
			return etherb_config_option(arg_string);
	}

	return NULL;
}

/*
 * SWI handler
 */
_kernel_oserror *etherb_swis(int swi_offset, _kernel_swi_regs *r, void *pw)
{
	/* The veneer preserves the old interrupt state */
	ensure_irqs_on();

	switch (swi_offset)
	{
		case EtherB_DCIVersion - EtherB_00:
			if (r->r[0] != 0) return etherb_error_lookup((etherb_err_t)EINVAL);
			r->r[1] = DCIVERSION;
			break;

		case EtherB_Inquire - EtherB_00:
			if (r->r[0] != 0) return etherb_error_lookup((etherb_err_t)EINVAL);
			if (r->r[1] >= units) return etherb_error_lookup((etherb_err_t)ENXIO);
			r->r[2] = nicunit[r->r[1]]->dib.dib_inquire;
			break;

		case EtherB_GetNetworkMTU - EtherB_00:
			if (r->r[0] != 0) return etherb_error_lookup((etherb_err_t)EINVAL);
			if (r->r[1] >= units) return etherb_error_lookup((etherb_err_t)ENXIO);
			r->r[2] = nicunit[r->r[1]]->ctrl->mtu;
			break;

		case EtherB_SetNetworkMTU - EtherB_00:
			/* Ethernet II has a fixed MTU */
			if (r->r[0] != 0) return etherb_error_lookup((etherb_err_t)EINVAL);
			if (r->r[1] >= units) return etherb_error_lookup((etherb_err_t)ENXIO);
			if (r->r[2] != ETHERMTU) return etherb_error_lookup((etherb_err_t)ENOTTY);
			break;

		case EtherB_Stats - EtherB_00:
			if (r->r[0] > 1) return etherb_error_lookup((etherb_err_t)EINVAL);
			if (r->r[1] >= units) return etherb_error_lookup((etherb_err_t)ENXIO);
			etherb_stats((r->r[0] & 1) ? TRUE : FALSE, (uint8_t)r->r[1], (struct stats *)r->r[2]);
			break;

		case EtherB_Filter - EtherB_00:
			if (r->r[0] >= FILTER_1STRESERVED) return etherb_error_lookup((etherb_err_t)EINVAL);
			if (r->r[1] >= units) return etherb_error_lookup((etherb_err_t)ENXIO);
			if (r->r[0] & FILTER_RELEASE)
			{
				/* Release the filter */
				return filter_remove((uint8_t)r->r[1],
				                     r->r[2], r->r[3], r->r[4],
				                     (filter_handler_t)r->r[6], (void *)r->r[5]); 
			}
			/* Try to claim a filter */
			return filter_add((uint8_t)r->r[1],
			                  r->r[2], r->r[3], r->r[4],
			                  (filter_handler_t)r->r[6], (void *)r->r[5],
			                  r->r[0]);

		case EtherB_Transmit - EtherB_00:
			if (r->r[0] >= TX_1STRESERVED) return etherb_error_lookup((etherb_err_t)EINVAL);
			if (r->r[1] >= units) return etherb_error_lookup((etherb_err_t)ENXIO);
			if (r->r[0] & TX_FAKESOURCE)
			{
				int error;
				struct ifnet *ifp = nicunit[r->r[1]]->ctrl->ifp;

				error = glue_transmit((r->r[0] & TX_PROTOSDATA) ? FALSE : TRUE,
				                      (uint8_t)r->r[1],
				                      (uint16_t)r->r[2],
				                      (struct mbuf *)r->r[3],
				                      (uint8_t *)r->r[5],
				                      (uint8_t *)r->r[4],
				                      ifp);
				if (error >= 0) return etherb_error_lookup((etherb_err_t)error);
			}
			else
			{
				int error;
				struct ifnet *ifp = nicunit[r->r[1]]->ctrl->ifp;

				error = glue_transmit((r->r[0] & TX_PROTOSDATA) ? FALSE : TRUE,
				                      (uint8_t)r->r[1],
				                      (uint16_t)r->r[2],
				                      (struct mbuf *)r->r[3],
				                      nicunit[r->r[1]]->eui,
				                      (uint8_t *)r->r[4],
				                      ifp);
				if (error >= 0) return etherb_error_lookup((etherb_err_t)error);
			}
			break;

		default:
			DPRINTF(("SWI offset %d invalid\n", swi_offset));
			return error_BAD_SWI;
	}

	UNUSED(pw);

	return NULL;
}
