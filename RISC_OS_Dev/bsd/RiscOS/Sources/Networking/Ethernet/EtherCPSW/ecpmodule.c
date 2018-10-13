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
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <ctype.h>

#include "Global/OsBytes.h"
#include "Global/Services.h"
#include "Global/Variables.h"
#include "Global/CMOS.h"
#include "Global/HALDevice.h"
#include "Global/HALEntries.h"
#include "Global/NewErrors.h"
#include "AsmUtils/irqs.h"
#include "swis.h"

#include <sys/types.h>
#include <sys/dcistructs.h>
#include <sys/errno.h>
#include <sys/mbuf.h>
#include <sys/queue.h>
#include <net/ethernet.h>

#include "EtherCPSWHdr.h"
#include "filtering.h"
#include "glue.h"
#include "if_cpswreg.h"
#include "ecpmodule.h"

/* Global state */
struct device *device;
uint8_t        units;
ethercp_nic_t  nic[NIC_MAX_CONTROLLERS];
ethercp_if_t  *nicunit[NIC_MAX_INTERFACES * NIC_MAX_CONTROLLERS];
struct mbctl   mbctl;
struct ifnet  *nicifp;

/* Local state */
static bool            mbufsession;
static uint32_t        message_block[4];
static const char      driver_name[] = "ecp";
static const char      driver_title[] = "EtherCP";

static void ethercp_stats(bool fill, uint8_t unit, struct stats *buffer)
{
	if (fill)
	{
		uint16_t physt = nicifp->mac[nicunit[unit]->ctrlnum].phy_status;

		/* Fill in the stats */
		buffer->st_interface_type = (physt & PHYST_SPD1000) ? ST_TYPE_1000BASET :
		                            (physt & PHYST_SPD100) ? ST_TYPE_100BASETX :
		                                                     ST_TYPE_10BASET;
		buffer->st_link_polarity = ST_LINK_POLARITY_CORRECT; /* Auto MDI-X is on */
		buffer->st_link_status = (physt & PHYST_DPLXDET) ? ST_STATUS_FULL_DUPLEX :
		                                                   ST_STATUS_HALF_DUPLEX;
		if (nicunit[unit]->ctrl->running) 
		{
			/* Running (therefore not faulty), so it must be active */
			buffer->st_link_status |= ST_STATUS_ACTIVE;
			if ((physt & PHYST_LNKFAIL) == 0) buffer->st_link_status |= ST_STATUS_OK;
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

static void ethercp_stop_mbuf_session(void)
{
	_swix(Mbuf_CloseSession, _IN(0), &mbctl);
	mbufsession = FALSE;
}

static _kernel_oserror *ethercp_start_mbuf_session(void)
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

static const char *ethercp_name_chip(void)
{
	return "CPSW";
}

static _kernel_oserror *ethercp_open_messages(void)
{
	_kernel_oserror *error;

#ifndef ROM
	/* Register the messages for RAM based modules */
	error = _swix(ResourceFS_RegisterFiles, _IN(0), ethercp_messages());
	if (error != NULL) return error;
#endif

	/* Try open, report fail */
	error = _swix(MessageTrans_OpenFile, _INR(0,2), message_block, Module_MessagesFile, 0);
#ifndef ROM
	if (error != NULL) _swix(ResourceFS_DeregisterFiles, _IN(0), ethercp_messages());
#endif
	return error;
}

static void ethercp_destroy_messages(void)
{
	/* Tidy up and deregister */
	_swix(MessageTrans_CloseFile, _IN(0), message_block);
#ifndef ROM
	_swix(ResourceFS_DeregisterFiles, _IN(0), ethercp_messages());
#endif
}

static uint16_t ethercp_modify_cmos(uint16_t flags, uint32_t cmos, bool write)
{
	size_t   i;
	uint8_t *byte = (uint8_t *)&flags;

	for (i = 0; i < NIC_CMOS_FLAGS_SIZE; i++)
	{
		if (write)
		{
			_swix(OS_Byte, _INR(0,2), OsByte_WriteCMOS, cmos + i, byte[i]);
		}
		else
		{
			uint32_t value = 0;

			_swix(OS_Byte, _INR(0,1) | _OUT(2), OsByte_ReadCMOS, cmos + i, &value);
			byte[i] = (uint8_t)value;
		}
	}

	return flags;
}

static void ethercp_add_interface(uint8_t unit, uint8_t ctrl, void *pw)
{
	int32_t  number;
	uint8_t  andmask, ormask;
	static uint32_t usedcmos = 0;
	uint32_t info[2];

	/* No Podule/PCI manager to query, get the machine's EUI48 */
	info[0] = info[1] = 0;
	if (_swix(OS_ReadSysInfo, _IN(0) | _OUTR(0,1),
	                          4, &info[0], &info[1]) == NULL)
	{
		for (number = 0; number < ETHER_ADDR_LEN; number++)
		{
			const uint8_t *eui = (uint8_t *)info;

			/* Endian swap */
			nicunit[unit]->eui[ETHER_ADDR_LEN - number - 1] = eui[number];
		}
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
		nic[ctrl].faulty |= NIC_FAULT_NO_EUI48;
		return;
	}

	/* Modify it for multiple addresses per machine */
	if ((nicunit[unit]->eui[EUI_ALT_BYTE] & EUI_ALT_BIT) && nicunit[unit]->virtual)
	{
		/* Virtual interface bit is set already, abort */
		nic[ctrl].faulty |= NIC_FAULT_NO_EUI48;
		return;
	}
	if ((nicunit[unit]->eui[EUI_IF_BYTE] % NIC_MAX_CONTROLLERS) && (ctrl > 0))
	{
		/* Non primary spare bits already set, abort */
		nic[ctrl].faulty |= NIC_FAULT_NO_EUI48;
		return;
	}
	if (nicunit[unit]->virtual)
	{
		nicunit[unit]->eui[EUI_ALT_BYTE] |= EUI_ALT_BIT;
	}
	nicunit[unit]->eui[EUI_IF_BYTE] |= ctrl; 

	/* Retrieve the CMOS options */
	nic[ctrl].flags = NIC_FLAG_DEFAULT;
	nic[ctrl].cmos = NIC_CMOS + (ctrl * NIC_CMOS_FLAGS_SIZE);
	nic[ctrl].cmossize = (usedcmos >= NIC_CMOS_SIZE) ? 0 : NIC_CMOS_FLAGS_SIZE;
	if (!nicunit[unit]->virtual) usedcmos = usedcmos + NIC_CMOS_FLAGS_SIZE;
	if (nic[ctrl].cmossize)
	{
		uint16_t flags = ethercp_modify_cmos(0, nic[ctrl].cmos, FALSE);

		switch (flags & (NIC_FLAG_LINKAUTO | NIC_FLAG_LINK100 | NIC_FLAG_LINKFULL | NIC_FLAG_UNUSED))
		{
			case NIC_FLAG_LINKAUTO:
			case 0:
			case NIC_FLAG_LINK100:
			case NIC_FLAG_LINKFULL:
			case NIC_FLAG_LINK100 | NIC_FLAG_LINKFULL:
				nic[ctrl].flags = flags;
				DPRINTF(("CMOS restored from 0x%X as 0x%X\n", nic[ctrl].cmos, flags));
				break;

			default:
				ethercp_modify_cmos(NIC_FLAG_DEFAULT, nic[ctrl].cmos, TRUE);
				DPRINTF(("CMOS impossible combo, defaulted\n"));
				break;
		}
	}

	if (!nicunit[unit]->virtual)
	{
		/* Set up the MAC that corresponds to that interface */
		memcpy(nicifp->mac[ctrl].enaddr, nicunit[unit]->eui, ETHER_ADDR_LEN);
		if (nicifp->mac[ctrl].phy_address == -1)
		{
			DPRINTF(("No recognised MAC (or PHY) found\n"));
			nic[ctrl].faulty |= NIC_FAULT_NO_LANCHIP;
			return;
		}
		DPRINTF(("Set up cpsw as unit %s%d\n", driver_name, unit));
	}

	/* Mark as configured successfully */
	nic[ctrl].mtu = ETHERMTU;
	nicunit[unit]->filters = NULL; 
	_swix(OS_ReadMonotonicTime, _OUT(0), &nic[ctrl].starttime);

	/* Translate the location */
	nicunit[unit]->dib.dib_location = (unsigned char *)malloc(32);
	if (nicunit[unit]->dib.dib_location == NULL)
	{
		nic[ctrl].faulty |= NIC_FAULT_NO_RMA;
		return;
	}
	else
	{
		char locname[32];

		strcpy(locname, ethercp_message_lookup(MSG12_MOTHERBOARD, NULL, NULL, NULL));
		sprintf((char *)nicunit[unit]->dib.dib_location, locname, ctrl);
	} 

	/* Fill in a device info block */
	nicunit[unit]->dib.dib_swibase = EtherCP_00;
	nicunit[unit]->dib.dib_name = (unsigned char *)driver_name;
	nicunit[unit]->dib.dib_unit = unit;
	nicunit[unit]->dib.dib_address = nicunit[unit]->eui;
	nicunit[unit]->dib.dib_module = (unsigned char *)driver_title;
	nicunit[unit]->dib.dib_slot.sl_slotid = DIB_SLOT_SYS_BUS;
	nicunit[unit]->dib.dib_slot.sl_minor = device->location >> 16;
	nicunit[unit]->dib.dib_slot.sl_pcmciaslot = 0;
	nicunit[unit]->dib.dib_slot.sl_mbz = 0;
	nicunit[unit]->dib.dib_inquire = INQ_MULTICAST |
	                                 INQ_PROMISCUOUS |
	                                 INQ_RXERRORS |
	                                 INQ_HWADDRVALID |
	                                 INQ_SOFTHWADDR |
	                                 INQ_HASSTATS;
	if (nicunit[unit]->virtual)
	{
		nicunit[unit]->dib.dib_inquire |= INQ_VIRTUAL | INQ_SWVIRTUAL;
	}

	UNUSED(pw);
}

static _kernel_oserror *ethercp_config_link(const char *args)
{
	_kernel_oserror *error;
	struct { char *split[3]; char buffer[sizeof("uAutoFull") + 3]; } readargs;
	uint32_t count = 0;
	uint16_t flags;
	bool     match = FALSE;
	uint8_t  unit;

	/* Split & uppercase, the first 2 arguments must exist */
	error = _swix(OS_ReadArgs, _INR(0,3),
	              "/A,/A,", args, &readargs, sizeof(readargs));
	if (error != NULL) return error;
	while (count < sizeof(readargs.buffer))
	{
		readargs.buffer[count] = toupper(readargs.buffer[count]);
		count++;
	}

	/* Which unit? */
	unit = *readargs.split[0] - '0';
	if ((unit >= units) || (strlen(readargs.split[0]) > 1))
	{
		return ethercp_error_lookup(ERR05_UNIT_IS_OFF);
	}
	if (nicunit[unit]->virtual)
	{
		return ethercp_error_lookup(ERR01_UNREAL);
	}
	
	/* Get the CMOS */
	flags = ethercp_modify_cmos(0, nicunit[unit]->ctrl->cmos, FALSE);

	/* Parse Auto | 10 | 100 */
	flags &= ~(NIC_FLAG_LINK100 | NIC_FLAG_LINKFULL | NIC_FLAG_LINKAUTO);
	if (strcmp(readargs.split[1], "AUTO") == 0) match = TRUE, flags |= NIC_FLAG_LINKAUTO;
	if (strcmp(readargs.split[1], "10") == 0)   match = TRUE, flags |= 0;
	if (strcmp(readargs.split[1], "100") == 0)  match = TRUE, flags |= NIC_FLAG_LINK100;
	if (!match) return configure_BAD_OPTION;

	if (flags & NIC_FLAG_LINKAUTO)
	{
		/* No more arguments from you */
		if (readargs.split[2] != NULL) return configure_BAD_OPTION;
	}
	else
	{
		/* Parse Full | Half */
		match = FALSE;
		if (strcmp(readargs.split[2], "FULL") == 0) match = TRUE, flags |= NIC_FLAG_LINKFULL;
		if (strcmp(readargs.split[2], "HALF") == 0) match = TRUE, flags |= 0;
		if (!match) return configure_BAD_OPTION;
	}
	DPRINTF(("Unit %s%d new CMOS flags 0x%X\n", driver_name, unit, flags));

	/* Note configure options are not applied until next reset */
	ethercp_modify_cmos(flags, nicunit[unit]->ctrl->cmos, TRUE);
	return NULL;
}

static _kernel_oserror *ethercp_config_virtual(const char *args)
{
	_kernel_oserror *error;
	struct { char *split[2]; char buffer[sizeof("uOff") + 2]; } readargs;
	uint32_t count = 0;
	uint16_t flags;
	bool     match = FALSE;
	uint8_t  unit;

	/* Split & uppercase, the first 2 arguments must exist */
	error = _swix(OS_ReadArgs, _INR(0,3),
	              "/A,/A", args, &readargs, sizeof(readargs));
	if (error != NULL) return error;
	while (count < sizeof(readargs.buffer))
	{
		readargs.buffer[count] = toupper(readargs.buffer[count]);
		count++;
	}

	/* Which unit? */
	unit = *readargs.split[0] - '0';
	if ((unit >= units) || (strlen(readargs.split[0]) > 1))
	{
		return ethercp_error_lookup(ERR05_UNIT_IS_OFF);
	}
	if (nicunit[unit]->virtual)
	{
		return ethercp_error_lookup(ERR01_UNREAL);
	}

	/* Get the CMOS */
	flags = ethercp_modify_cmos(0, nicunit[unit]->ctrl->cmos, FALSE);

	/* Parse On | Off */
	flags &= ~NIC_FLAG_VIRTUAL;
	if (strcmp(readargs.split[1], "ON") == 0)  match = TRUE, flags |= NIC_FLAG_VIRTUAL;
	if (strcmp(readargs.split[1], "OFF") == 0) match = TRUE, flags |= 0;
	if (!match) return configure_BAD_OPTION;

	DPRINTF(("Unit %s%d new CMOS flags 0x%X\n", driver_name, unit, flags));

	/* Note configure options are not applied until next reset */
	ethercp_modify_cmos(flags, nicunit[unit]->ctrl->cmos, TRUE);
	return NULL;
}

static _kernel_oserror *ethercp_config_advertise(const char *args)
{
	_kernel_oserror *error;
	struct { char *split[10]; char buffer[sizeof("u10HalfFull100HalfFull1000HalfFull") + 10]; } readargs;
	uint32_t count = 0;
	uint16_t flags;
	bool     match = FALSE;
	uint16_t speed = 0, tk[3] = { 0, 0, 0 };
	uint8_t  unit;

	/* Split & uppercase, the first 2 arguments must exist */
	error = _swix(OS_ReadArgs, _INR(0,3),
	              "/A,/A,,,,,,,,", args, &readargs, sizeof(readargs));
	if (error != NULL) return error;
	while (count < sizeof(readargs.buffer))
	{
		readargs.buffer[count] = toupper(readargs.buffer[count]);
		count++;
	}

	/* Which unit? */
	unit = *readargs.split[0] - '0';
	if ((unit >= units) || (strlen(readargs.split[0]) > 1))
	{
		return ethercp_error_lookup(ERR05_UNIT_IS_OFF);
	}
	if (nicunit[unit]->virtual)
	{
		return ethercp_error_lookup(ERR01_UNREAL);
	}

	/* Get the CMOS */
	flags = ethercp_modify_cmos(0, nicunit[unit]->ctrl->cmos, FALSE);

	/* Tokenise the advertisements to make them easier to decode */
	count = 1;
	while (count < 10)
	{
		if (readargs.split[count] == NULL) break;
		if ((strcmp(readargs.split[count], "10") == 0) || (strcmp(readargs.split[count], "100") == 0) ||
		    (strcmp(readargs.split[count], "1000") == 0))
		{
			/* Swap collection. If already got tokens, that's a bad repeat */
			speed = strcmp(readargs.split[count], "10") ?
			        strcmp(readargs.split[count], "100") ? 2 : 1 : 0;
			if (tk[speed] != 0) return configure_TOO_MANY_PARAMS;
			tk[speed] |= 1;
			match = TRUE;
		}
		if (strcmp(readargs.split[count], "HALF") == 0) match = TRUE, tk[speed] = (tk[speed] << 4) | 2;
		if (strcmp(readargs.split[count], "FULL") == 0) match = TRUE, tk[speed] = (tk[speed] << 4) | 3;
		count++;
	}
	if (!match) return configure_BAD_OPTION;

	/* No duplex options for speed 1000 */
	if (tk[2] > 1) return configure_BAD_OPTION;

	/* Check for the valid combinations */
	flags &= ~(NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF | NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF |
	           NIC_FLAG_AD1000);
	for (count = 0; count < 6; count++)
	{
		                                /*            S     SH     SF    SHF    SFH */
		static const uint16_t valid[]  = { 0x000, 0x001, 0x012, 0x013, 0x123, 0x132 };
		static const uint8_t bit10[]   = { 0,
		                                   NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF,
		                                   NIC_FLAG_AD10_HALF,
		                                   NIC_FLAG_AD10_FULL,
		                                   NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF,
		                                   NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF
		                                 };
		static const uint8_t bit100[]  = { 0,
		                                   NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF,
		                                   NIC_FLAG_AD100_HALF,
		                                   NIC_FLAG_AD100_FULL,
		                                   NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF,
		                                   NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF
		                                 };
		static const uint8_t bit1000[] = { 0,
		                                   NIC_FLAG_AD1000
		                                 };

		if (tk[0] == valid[count]) flags |= bit10[count],   tk[0] = 0;
		if (tk[1] == valid[count]) flags |= bit100[count],  tk[1] = 0;
		if (tk[2] == valid[count]) flags |= bit1000[count], tk[2] = 0;
	}
	if (tk[0] | tk[1] | tk[2]) return configure_TOO_MANY_PARAMS;

	DPRINTF(("Unit %s%d new CMOS flags 0x%X\n", driver_name, unit, flags));

	/* Note configure options are not applied until next reset */
	ethercp_modify_cmos(flags, nicunit[unit]->ctrl->cmos, TRUE);
	return NULL;
}

static _kernel_oserror *ethercp_config_flowcontrol(const char *args)
{
	_kernel_oserror *error;
	struct { char *split[2]; char buffer[sizeof("uGenerate") + 2]; } readargs;
	uint32_t count = 0;
	uint16_t flags;
	bool     match = FALSE;
	uint8_t  unit;

	/* Split & uppercase, the first 2 arguments must exist */
	error = _swix(OS_ReadArgs, _INR(0,3),
	              "/A,/A", args, &readargs, sizeof(readargs));
	if (error != NULL) return error;
	while (count < sizeof(readargs.buffer))
	{
		readargs.buffer[count] = toupper(readargs.buffer[count]);
		count++;
	}

	/* Which unit? */
	unit = *readargs.split[0] - '0';
	if ((unit >= units) || (strlen(readargs.split[0]) > 1))
	{
		return ethercp_error_lookup(ERR05_UNIT_IS_OFF);
	}
	if (nicunit[unit]->virtual)
	{
		return ethercp_error_lookup(ERR01_UNREAL);
	}
	
	/* Get the CMOS */
	flags = ethercp_modify_cmos(0, nicunit[unit]->ctrl->cmos, FALSE);

	/* Parse None | Generate | Respond | Full */
	flags &= ~(NIC_FLAG_FLOW_GEN | NIC_FLAG_FLOW_RESP);
	if (strcmp(readargs.split[1], "NONE") == 0)     match = TRUE, flags |= 0;
	if (strcmp(readargs.split[1], "GENERATE") == 0) match = TRUE, flags |= NIC_FLAG_FLOW_GEN;
	if (strcmp(readargs.split[1], "RESPOND") == 0)  match = TRUE, flags |= NIC_FLAG_FLOW_RESP;
	if (strcmp(readargs.split[1], "FULL") == 0)     match = TRUE, flags |= NIC_FLAG_FLOW_GEN | NIC_FLAG_FLOW_RESP;
	if (!match) return configure_BAD_OPTION;

	DPRINTF(("Unit %s%d new CMOS flags 0x%X\n", driver_name, unit, flags));

	/* Note configure options are not applied until next reset */
	ethercp_modify_cmos(flags, nicunit[unit]->ctrl->cmos, TRUE);
	return NULL;
}

static void ethercp_lineup_info(ethercp_msg_t tag, const char *value, uint32_t length)
{
	/* Regimented columns of information */
	length = length - printf(ethercp_message_lookup(tag, NULL, NULL, NULL));
	while (length)
	{
		putchar(' ');
		length--;
	}
	printf(": %s\n", value);
}

static void ethercp_interface_info(uint8_t which)
{
	uint32_t        longest, now, level;
	uint16_t        physt;
	char            msg[80];
	const filter_t *list;

	/* Headings for this unit */
	strcpy(msg, (char *)nicunit[which]->dib.dib_location);
	msg[0] = tolower(msg[0]); 
	printf("\n%s%d: %s, %s, %s\n\n",
	       driver_name,
	       which,
	       ethercp_name_chip(),
	       msg,
	       ethercp_message_lookup(nicunit[which]->ctrl->faulty ? MSG11_DOWN : MSG10_UP, NULL, NULL, NULL));

	/* Find where the columns line up */
	longest = strlen(ethercp_message_lookup(MSG00_INFO_LENGTH, NULL, NULL, NULL));

	/* Driver */
	ethercp_lineup_info(MSG01_IF_DRIVER, driver_name, longest);

	/* Unit */
	sprintf(msg, "%d", which);
	ethercp_lineup_info(MSG02_IF_UNIT, msg, longest);

	/* Location */
	ethercp_lineup_info(MSG03_IF_LOCATION, (char *)nicunit[which]->dib.dib_location, longest);

	/* EUI48 */
	sprintf(msg, "%02X:%02X:%02X:%02X:%02X:%02X",
	        nicunit[which]->eui[0], nicunit[which]->eui[1],
	        nicunit[which]->eui[2], nicunit[which]->eui[3],
	        nicunit[which]->eui[4], nicunit[which]->eui[5]);
	ethercp_lineup_info(MSG04_IF_EUI, msg, longest);

	/* Controller */
	strcpy(msg, nicunit[which]->virtual ? ethercp_message_lookup(MSG13_VIRTUAL, NULL, NULL, NULL)
	                                    : ethercp_name_chip());
	ethercp_lineup_info(MSG05_IF_CONTROLLER, msg, longest);

	/* Media state */
	if (!nicunit[which]->virtual)
	{
		physt = nicifp->mac[nicunit[which]->ctrlnum].phy_status;
		if (physt & PHYST_LNKFAIL)
		{
			strcpy(msg, ethercp_message_lookup(MSG36_UNPLUGGED, NULL, NULL, NULL)); 
		}
		else
		{
			strcpy(msg, ethercp_message_lookup((physt & PHYST_DPLXDET) ? MSG35_BT_FULLDUP :
			                                                            MSG34_BT_HALFDUP,
			                                   (physt & PHYST_SPD1000) ? "1000" :
			                                   (physt & PHYST_SPD100) ? "100" : "10", NULL, NULL));
		}
		ethercp_lineup_info(MSG33_IF_MEDIA, msg, longest);
	}

	/* Running time */
	_swix(OS_ReadMonotonicTime, _OUT(0), &now);
	now = (now - nicunit[which]->ctrl->starttime) / 100;
	sprintf(msg, ethercp_message_lookup(MSG09_TIME_FORMAT, NULL, NULL, NULL),
	        now / 86400, (now % 86400) / 3600, (now % 3600) / 60, now % 60);
	ethercp_lineup_info(MSG06_IF_RUNTIME, msg, longest);

	/* Send and receive stats */
	sprintf(msg, "%u", nicunit[which]->tx_packets);
	ethercp_lineup_info(MSG20_STAT_P_SENT, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_packets);
	ethercp_lineup_info(MSG21_STAT_P_RECEIVED, msg, longest);
	sprintf(msg, "%u", nicunit[which]->tx_bytes);
	ethercp_lineup_info(MSG22_STAT_B_SENT, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_bytes);
	ethercp_lineup_info(MSG23_STAT_B_RECEIVED, msg, longest);
	sprintf(msg, "%u", nicunit[which]->tx_errors);
	ethercp_lineup_info(MSG24_STAT_E_SENT, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_errors);
	ethercp_lineup_info(MSG25_STAT_E_RECEIVED, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_discards);
	ethercp_lineup_info(MSG26_STAT_UNDELIVERED, msg, longest);

	/* Registered frame filters */
	sprintf(msg, "%s\n", ethercp_message_lookup(MSG31_FRAME_DESC, NULL, NULL, NULL));
	for (level = FRMLVL_IEEE; level >= FRMLVL_E2SPECIFIC; level--)
	{
		bool shown = FALSE;
		static const ethercp_msg_t headings[] = { MSG30_FRAME_STANDARD,
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
					printf("\n%s:\n\n", ethercp_message_lookup(headings[level - 1], NULL, NULL, NULL));
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
void ethercp_review_levels(uint8_t unit)
{
	uint16_t        value;
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
	value = elevel | (nicunit[unit]->ctrlnum << 8);
	nicifp->if_ioctl(nicifp, SIOCSETERRLVL, &value);
	value = alevel | (nicunit[unit]->ctrlnum << 8);
	nicifp->if_ioctl(nicifp, SIOCSETPROMISC, &value);
}

/*
 * Internationalised messages
 */
char *ethercp_message_lookup(ethercp_msg_t which, const char *arg1, const char *arg2, const char *arg3)
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
_kernel_oserror *ethercp_error_lookup(ethercp_err_t which)
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
		error.errnum = ErrorBase_EtherCPSW + which - ErrorBase_UnixRange;
	}

	return &error;
}

/*
 * Ticker heartbeat
 */
_kernel_oserror *ethercp_heartbeat_handler(_kernel_swi_regs *r, void *pw)
{
	callout_callevery();
	UNUSED(r);
	UNUSED(pw);

	return NULL;
}

/*
 * Callback when linked into the module chain
 */
_kernel_oserror *ethercp_driver_linked_handler(_kernel_swi_regs *r, void *pw)
{
	uint8_t  oldmbs, unit;
	char     var[8];
	uint32_t length;

	/* Here because the MbufManager started or via callback now my SWIs
	 * are available, either way, try opening an MbufManager session.
	 */
	oldmbs = mbufsession;
	ethercp_start_mbuf_session();
	if ((oldmbs != mbufsession) && mbufsession)
	{
		/* Start 1s watchdog */
		_swix(OS_CallEvery, _INR(0,2), 100, ethercp_heartbeat, pw);

		/* Enable send/receive */
		DPRINTF(("Got mbufs, going online\n"));

		/* Start the top level CPSW */
		nicifp->if_init(nicifp);

		/* Transitioned to functioning state */
		for (unit = 0; unit < units; unit++)
		{
			if (!nicunit[unit]->ctrl->faulty)
			{
				if (!nicunit[unit]->ctrl->running)
				{
					nicunit[unit]->ctrl->running = TRUE;
					DPRINTF(("NIC on MAC %u running\n", nicunit[unit]->ctrlnum));
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
_kernel_oserror *ethercp_init(const char *cmd_tail, int podule_base, void *pw)
{
	struct obio_attach_args oaa;
	struct cpsw_softc *softc = NULL;
	_kernel_oserror   *error;
	int32_t pos = 0;
	size_t  i = 0;

	error = ethercp_open_messages();
	if (error != NULL) return error;

	/* Only 1 instance, but can support multiple hardware */
	if (podule_base == 1)
	{
		error = ethercp_error_lookup(ERR03_SINGLE_INSTANCE);
		goto init_fail;
	}

	while (1)
	{
		error = _swix(OS_Hardware, _INR(0,1) | _IN(8) | _OUTR(1,2),
		                           HALDeviceType_Comms + HALDeviceComms_EtherNIC, pos,
		                           OSHW_DeviceEnumerate,
		                           &pos, &device);
		if (error != NULL) goto init_fail;
		if (pos == -1)
		{
			static const internaterr_t badhard = { ErrorNumber_BadHard, "BadHard" };

			/* No matches, quit */
			error = _swix(MessageTrans_ErrorLookup, _INR(0,2), &badhard, 0, 0);
			goto init_fail;
		}
		if ((device->id == HALDeviceID_EtherNIC_CPSW) &&
		    (device->devicenumber != -1) &&
		    device->Activate(device))
		{
			/* Caught a live one */
			break;
		}
	}

	/* Now, get attached to the chip */
	softc = calloc(1, cpsw_ca.ca_devsize);
	if (softc == NULL)
	{
		error = ethercp_error_lookup((ethercp_err_t)ENOMEM);
		goto init_fail;
	}
	obio_attach_from_hal_device(&oaa, device);
	cpsw_ca.ca_attach(NULL, (device_t)softc, &oaa);

	/* Probe how many MACs there are.
	 * Note that the addition might fail but we must assign a unit
	 * number anyway so that the unit numbers match up with what AutoSense
	 * would guess, since it can't know whether there's a fault or not.
	 */
	while (1)
	{
		volatile uint32_t *idver = (volatile uint32_t *)((uintptr_t)device->address + CPSW_SL_IDVER(i));

		if (*idver == 0) break;

		/* Always one real one */
		nic[i].controller = softc;
		nicunit[units] = &nic[i].interface[0];
		nicunit[units]->ctrl = &nic[i];
		nicunit[units]->ctrlnum = i;
		nicunit[units]->unitnum = units;
		nicunit[units]->virtual = FALSE;
		ethercp_add_interface(units, i, pw);
		units++;

		/* Maybe a virtual one */
		if (nic[i].flags & NIC_FLAG_VIRTUAL)
		{
			nicunit[units] = &nic[i].interface[1];
			nicunit[units]->ctrl = &nic[i];
			nicunit[units]->ctrlnum = i;
			nicunit[units]->unitnum = units;
			nicunit[units]->virtual = TRUE;
			ethercp_add_interface(units, i, pw);
			units++;
		}

		i++;
	}

	DPRINTF(("Total of %d %s interfaces\n", units, driver_title));
	if (units == 0)
	{
		error = ethercp_error_lookup(ERR00_NO_SUPPORTED_CPSW);
		goto init_fail;
	}

	/* Bulk register the handler, this assumes the HAL has dished out 4 consecutive
	 * device numbers for the 4 consecutive interrupt reasons, such that the despatch to
	 * the NetBSD code can turn the device number back into an array reference.
	 */
	error = NULL;
	for (i = 0; (error == NULL) && (i < 4); i++)
	{
		error = _swix(OS_ClaimDeviceVector, _INR(0,2),
	                      device->devicenumber + i, intr, pw);
	}
	if (error != NULL)
	{
		/* One failed makes the whole exercise pointless */
		for (i = 0; i < 4; i++)
		{
			_swix(OS_ReleaseDeviceVector, _INR(0,2),
			      device->devicenumber + i, intr, pw);
		}
		goto init_fail;
	}

	/* Everything else has to be done on a callback once my SWIs are available */
	_swix(OS_AddCallBack, _INR(0,1), ethercp_driver_linked, pw);

	UNUSED(cmd_tail);

	return NULL;

init_fail:
	free(softc);
	units = 0;
	ethercp_destroy_messages();

	return error;
}

/*
 * Finalisation
 */
_kernel_oserror *ethercp_final(int fatal, int podule, void *pw)
{
	uint8_t unit;
	size_t  i;

	/* When fatal is -ve it's a Service_PreReset, skip clean up */
	if (fatal >= 0)
	{
		for (unit = 0; unit < units; unit++)
		{
			if (!mbufsession) continue;

			if (!nicunit[unit]->ctrl->faulty)
			{
				/* Elvis has left the building */
				_swix(OS_ServiceCall, _INR(0,3),
				      &nicunit[unit]->dib,
				      Service_DCIDriverStatus,
				      DCIDRIVER_DYING, DCIVERSION);

				DPRINTF(("Announced %s%d is dying\n", driver_name, unit));
			}

			/* Don't leak old filters */
			filter_destroy(unit);

			/* Finished with the location */
			free(nicunit[unit]->dib.dib_location);
		}
		ethercp_stop_mbuf_session();
		ethercp_destroy_messages();
	}

	/* Halt any booked callbacks */
	_swix(OS_RemoveTickerEvent, _INR(0,1), ethercp_heartbeat, pw);
	_swix(OS_RemoveCallBack, _INR(0,1), ethercp_driver_linked, pw);

	for (unit = 0; unit < units; unit++)
	{
		if (nicunit[unit]->ctrl->running)
		{
			/* Go offline */
			DPRINTF(("NIC on MAC %u going offline\n", nicunit[unit]->ctrlnum));
			nicunit[unit]->ctrl->running = FALSE;
		}
	}

	/* Clear up any CPSW loose ends */
	nicifp->if_stop(nicifp, TRUE);
	cpsw_ca.ca_detach((device_t)nic[0].controller, 0);
	free(nic[0].controller);

	/* Get off the vectors */
	for (i = 0; i < 4; i++)
	{
		_swix(OS_ReleaseDeviceVector, _INR(0,2),
		      device->devicenumber + i, intr, pw);
	}
	DPRINTF(("Hardware shut down\n"));

	UNUSED(podule);

	return NULL;
}

/*
 * Service call handler
 */
void ethercp_services(int service_number, _kernel_swi_regs *r, void *pw)
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
					ethercp_driver_linked_handler(r, pw);
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
			ethercp_final(-1, 0, pw);
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
			(*(void (*)(void *, void *, void *, void *))r->r[2])(ethercp_messages(), 0, 0, (void *)r->r[3]);
			break;
#endif
	}
}

/*
 * Command handler
 */
_kernel_oserror *ethercp_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
	_kernel_oserror *error;
	uint32_t select;
	uint16_t flags;

	switch (cmd_no)
	{
		case CMD_ECPInfo:
			if (argc == 0)
			{
				/* When not specified, do all */
				if (units == 0) return ethercp_error_lookup(ERR05_UNIT_IS_OFF);
				printf("%s\n", ethercp_message_lookup(MSG18_INFO_STATS, NULL, NULL, NULL));
				for (select = 0; select < units; select++)
				{
					ethercp_interface_info(select);
				}
			}
			else
			{
				error = _swix(OS_ReadUnsigned, _INR(0,1) | _OUT(2),
				              10, arg_string, &select);
				if (error) return error;
				if (select >= units) return ethercp_error_lookup(ERR05_UNIT_IS_OFF);
				printf("%s\n", ethercp_message_lookup(MSG18_INFO_STATS, NULL, NULL, NULL));
				ethercp_interface_info(select);
			}
			break;

		case CMD_ECPTest:
			if (argc == 0)
			{
				/* When not specified, do all */
				if (units == 0) return ethercp_error_lookup(ERR05_UNIT_IS_OFF);
				for (select = 0; select < units; select++)
				{
					printf("%s%d %s", driver_name,
					                  select,
					                  ethercp_message_lookup(MSG32_SELFTEST, NULL, NULL, NULL));
					printf(" %s\n", ethercp_message_lookup(nicunit[select]->ctrl->faulty ?
					                                      MSG17_FAILED :
					                                      MSG16_PASSED, NULL, NULL, NULL));
				}
			}
			else
			{
				error = _swix(OS_ReadUnsigned, _INR(0,1) | _OUT(2),
				              10, arg_string, &select);
				if (error) return error;
				if (select >= units) return ethercp_error_lookup(ERR05_UNIT_IS_OFF);
				printf("%s%d %s", driver_name,
				                  select,
				                  ethercp_message_lookup(MSG32_SELFTEST, NULL, NULL, NULL));
				printf(" %s\n", ethercp_message_lookup(nicunit[select]->ctrl->faulty ?
				                                      MSG17_FAILED :
				                                      MSG16_PASSED, NULL, NULL, NULL));
			}
			break;

		case CMD_ECPLink:
			/* Check for *STATUS and *CONFIGURE alone */
			if (arg_string == arg_STATUS)
			{
				for (select = 0; select < units; select++)
				{
					if (nicunit[select]->virtual) continue;
					flags = ethercp_modify_cmos(0, nicunit[select]->ctrl->cmos, FALSE);
					printf("ECPLink        %u %s%s\n", select,
					       flags & NIC_FLAG_LINKAUTO ? "Auto" :
					       flags & NIC_FLAG_LINK100 ? "100" : "10",
					       flags & NIC_FLAG_LINKAUTO ? "" :
					       flags & NIC_FLAG_LINKFULL ? " Full" : " Half");
				}

				return NULL;
			}
			if (arg_string == arg_CONFIGURE_SYNTAX)
			{
				/* Configure keywords aren't internationalised,
				 * so the syntax mustn't be either.
				 */
				printf("ECPLink        <%s> Auto | 10 Half|Full | 100 Half|Full\n",
				       ethercp_message_lookup(MSG37_UNITNO, NULL, NULL, NULL));

				return NULL;
			}

			/* Otherwise, trying to set it */
			return ethercp_config_link(arg_string);

		case CMD_ECPVirtual:
			/* Check for *STATUS and *CONFIGURE alone */
			if (arg_string == arg_STATUS)
			{
				for (select = 0; select < units; select++)
				{
					if (nicunit[select]->virtual) continue;
					flags = ethercp_modify_cmos(0, nicunit[select]->ctrl->cmos, FALSE);
					printf("ECPVirtual     %u %s\n", select,
					       flags & NIC_FLAG_VIRTUAL ? "On" : "Off");
				}

				return NULL;
			}
			if (arg_string == arg_CONFIGURE_SYNTAX)
			{
				/* Configure keywords aren't internationalised,
				 * so the syntax mustn't be either.
				 */
				printf("ECPVirtual     <%s> On|Off\n",
				       ethercp_message_lookup(MSG37_UNITNO, NULL, NULL, NULL));

				return NULL;
			}

			/* Otherwise, trying to set it */
			return ethercp_config_virtual(arg_string);

		case CMD_ECPAdvertise:
			/* Check for *STATUS and *CONFIGURE alone */
			if (arg_string == arg_STATUS)
			{
				for (select = 0; select < units; select++)
				{
					if (nicunit[select]->virtual) continue;
					flags = ethercp_modify_cmos(0, nicunit[select]->ctrl->cmos, FALSE);
					printf("ECPAdvertise   %u%s%s%s%s%s%s%s\n", select,
					       flags & (NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF) ? " 10" : "",
					       flags & NIC_FLAG_AD10_FULL ? " Full" : "",
					       flags & NIC_FLAG_AD10_HALF ? " Half" : "",
					       flags & (NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF) ? " 100" : "",
					       flags & NIC_FLAG_AD100_FULL ? " Full" : "",
					       flags & NIC_FLAG_AD100_HALF ? " Half" : "",
					       flags & (NIC_FLAG_AD1000) ? " 1000" : "");
				}

				return NULL;
			}
			if (arg_string == arg_CONFIGURE_SYNTAX)
			{
				/* Configure keywords aren't internationalised,
				 * so the syntax mustn't be either.
				 */
				printf("ECPAdvertise   <%s> [10 [Half] [Full]] [100 [Half] [Full]] [1000]\n",
				       ethercp_message_lookup(MSG37_UNITNO, NULL, NULL, NULL));

				return NULL;
			}

			/* Otherwise, trying to set it */
			return ethercp_config_advertise(arg_string);

		case CMD_ECPFlowControl:
			/* Check for *STATUS and *CONFIGURE alone */
			if (arg_string == arg_STATUS)
			{
				for (select = 0; select < units; select++)
				{
					static const char *opts[] = { "None", "Generate", "Respond", "Full" };
					size_t opt = 0;

					if (nicunit[select]->virtual) continue;
					flags = ethercp_modify_cmos(0, nicunit[select]->ctrl->cmos, FALSE);
					if (flags & NIC_FLAG_FLOW_GEN) opt |= 1;
					if (flags & NIC_FLAG_FLOW_RESP) opt |= 2;
					printf("ECPFlowControl %u %s\n", select, opts[opt]);
				}

				return NULL;
			}
			if (arg_string == arg_CONFIGURE_SYNTAX)
			{
				/* Configure keywords aren't internationalised,
				 * so the syntax mustn't be either.
				 */
				printf("ECPFlowControl <%s> None | Generate | Respond | Full\n",
				       ethercp_message_lookup(MSG37_UNITNO, NULL, NULL, NULL));

				return NULL;
			}

			/* Otherwise, trying to set it */
			return ethercp_config_flowcontrol(arg_string);
	}

	UNUSED(pw);

	return NULL;
}

/*
 * SWI handler
 */
_kernel_oserror *ethercp_swis(int swi_offset, _kernel_swi_regs *r, void *pw)
{
	/* The veneer preserves the old interrupt state */
	ensure_irqs_on();

	switch (swi_offset)
	{
		case EtherCP_DCIVersion - EtherCP_00:
			if (r->r[0] != 0) return ethercp_error_lookup((ethercp_err_t)EINVAL);
			r->r[1] = DCIVERSION;
			break;

		case EtherCP_Inquire - EtherCP_00:
			if (r->r[0] != 0) return ethercp_error_lookup((ethercp_err_t)EINVAL);
			if (r->r[1] >= units) return ethercp_error_lookup((ethercp_err_t)ENXIO);
			r->r[2] = nicunit[r->r[1]]->dib.dib_inquire;
			break;

		case EtherCP_GetNetworkMTU - EtherCP_00:
			if (r->r[0] != 0) return ethercp_error_lookup((ethercp_err_t)EINVAL);
			if (r->r[1] >= units) return ethercp_error_lookup((ethercp_err_t)ENXIO);
			r->r[2] = nicunit[r->r[1]]->ctrl->mtu;
			break;

		case EtherCP_SetNetworkMTU - EtherCP_00:
			/* Ethernet II has a fixed MTU */
			if (r->r[0] != 0) return ethercp_error_lookup((ethercp_err_t)EINVAL);
			if (r->r[1] >= units) return ethercp_error_lookup((ethercp_err_t)ENXIO);
			if (r->r[2] != ETHERMTU) return ethercp_error_lookup((ethercp_err_t)ENOTTY);
			break;

		case EtherCP_Stats - EtherCP_00:
			if (r->r[0] > 1) return ethercp_error_lookup((ethercp_err_t)EINVAL);
			if (r->r[1] >= units) return ethercp_error_lookup((ethercp_err_t)ENXIO);
			ethercp_stats((r->r[0] & 1) ? TRUE : FALSE, (uint8_t)r->r[1], (struct stats *)r->r[2]);
			break;

		case EtherCP_Filter - EtherCP_00:
			if (r->r[0] >= FILTER_1STRESERVED) return ethercp_error_lookup((ethercp_err_t)EINVAL);
			if (r->r[1] >= units) return ethercp_error_lookup((ethercp_err_t)ENXIO);
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

		case EtherCP_Transmit - EtherCP_00:
			if (r->r[0] >= TX_1STRESERVED) return ethercp_error_lookup((ethercp_err_t)EINVAL);
			if (r->r[1] >= units) return ethercp_error_lookup((ethercp_err_t)ENXIO);
			if (r->r[0] & TX_FAKESOURCE)
			{
				int error;

				error = glue_transmit((r->r[0] & TX_PROTOSDATA) ? FALSE : TRUE,
				                      (uint8_t)r->r[1],
				                      (uint16_t)r->r[2],
				                      (struct mbuf *)r->r[3],
				                      (uint8_t *)r->r[5],
				                      (uint8_t *)r->r[4],
				                      nicifp);
				if (error >= 0) return ethercp_error_lookup((ethercp_err_t)error);
			}
			else
			{
				int error;

				error = glue_transmit((r->r[0] & TX_PROTOSDATA) ? FALSE : TRUE,
				                      (uint8_t)r->r[1],
				                      (uint16_t)r->r[2],
				                      (struct mbuf *)r->r[3],
				                      nicunit[r->r[1]]->eui,
				                      (uint8_t *)r->r[4],
				                      nicifp);
				if (error >= 0) return ethercp_error_lookup((ethercp_err_t)error);
			}
			break;

		default:
			DPRINTF(("SWI offset %d invalid\n", swi_offset));
			return error_BAD_SWI;
	}

	UNUSED(pw);

	return NULL;
}
