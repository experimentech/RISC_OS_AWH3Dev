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
#include <sys/queue.h>
#include <net/ethernet.h>

#include "EtherYHdr.h"
#include "filtering.h"
#include "glue.h"
#include "bus.h"
#include "miivar.h"
#include "smc91cxxvar.h"
#include "eymodule.h"

/* Global state */
uint8_t       units;
ethery_nic_t  nic[NIC_MAX_CONTROLLERS];
ethery_if_t  *nicunit[NIC_MAX_INTERFACES * NIC_MAX_CONTROLLERS];
struct mbctl  mbctl;

/* Local state */
static bool            mbufsession;
static uint32_t        message_block[4];
static const char      driver_name[] = "ey";
static const char      driver_title[] = "EtherY";

static void ethery_stats(bool fill, uint8_t unit, struct stats *buffer)
{
	if (fill)
	{
		uint16_t physt = nicunit[unit]->ctrl->ifp->phy_status;

		/* Fill in the stats */
		buffer->st_interface_type = (physt & PHYST_SPDDET) ? ST_TYPE_100BASETX :
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

static void ethery_stop_mbuf_session(void)
{
	_swix(Mbuf_CloseSession, _IN(0), &mbctl);
	mbufsession = FALSE;
}

static _kernel_oserror *ethery_start_mbuf_session(void)
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

static const char *ethery_name_chip(ethery_nic_t *nic)
{
	UNUSED(nic);

	return "LAN91C111";
}

static _kernel_oserror *ethery_open_messages(void)
{
	_kernel_oserror *error;

#ifndef ROM
	/* Register the messages for RAM based modules */
	error = _swix(ResourceFS_RegisterFiles, _IN(0), ethery_messages());
	if (error != NULL) return error;
#endif

	/* Try open, report fail */
	error = _swix(MessageTrans_OpenFile, _INR(0,2), message_block, Module_MessagesFile, 0);
#ifndef ROM
	if (error != NULL) _swix(ResourceFS_DeregisterFiles, _IN(0), ethery_messages());
#endif
	return error;
}

static void ethery_destroy_messages(void)
{
	/* Tidy up and deregister */
	_swix(MessageTrans_CloseFile, _IN(0), message_block);
#ifndef ROM
	_swix(ResourceFS_DeregisterFiles, _IN(0), ethery_messages());
#endif
}

static void ethery_add_interface(uint8_t unit, uint8_t index, int32_t slot, void *pw)
{
	uint32_t info[10];
	int32_t  number;
	uint8_t  andmask, ormask;
	int      state;
	_kernel_oserror *error;

	/* Get some vitals */
	memset(info, 0, sizeof(info));
	_swix(Podule_ReadInfo, _INR(0,3),
	      Podule_ReadInfo_SyncBase |
	      Podule_ReadInfo_CMOSAddress |
	      Podule_ReadInfo_CMOSSize |
	      Podule_ReadInfo_ROMAddress |
	      Podule_ReadInfo_EASILogical |
	      Podule_ReadInfo_IntStatus |
	      Podule_ReadInfo_IntRequest |
	      Podule_ReadInfo_IntMask |
	      Podule_ReadInfo_IntValue |
	      Podule_ReadInfo_IntDeviceVector,
	      info, sizeof(info), slot);
	nic[index].podule = slot;
	nic[index].cmos = info[1];
	nic[index].cmossize = info[2];
	nic[index].irqstatus = (volatile const uint32_t *)info[5];
	nic[index].irqrequest = (volatile const uint32_t *)info[6];
	nic[index].irqmask = (volatile uint32_t *)info[7];
	nic[index].irqbit = info[8];
	nic[index].irqdevice = info[9];

	/* The podule variant is EASI only, check we've not been plugged into
	 * something pre Risc PC era that has neither EASI nor NICs.
	 */
	if (slot == NIC_IS_NIC_SLOT)
	{
		if (info[0] == 0)
		{
			nic[index].faulty |= NIC_FAULT_NO_IOALLOC;
			return;
		}
		nic[index].private_irq = (volatile uint8_t *)(info[0] + 0x00);
		nic[index].hwbase = (void *)(info[0] + 0x80);
		nic[index].rombase = (void *)info[3];
	}
	else
	{
		if (info[4] == 0)
		{
			nic[index].faulty |= NIC_FAULT_NO_IOALLOC;
			return;
		}
		nic[index].private_irq = (volatile uint8_t *)(info[4] + 0x800C00);
		nic[index].hwbase = (void *)(info[4] + 0x800D00);
		nic[index].rombase = (void *)info[4];
		nic[index].controller.sc_flags |= SMC_FLAGS_32BIT_READ;
	}
	DPRINTF(("%s in podule %d, controller at 0x%p, ROM at 0x%p\n",
	        driver_title, slot, nic[index].hwbase, nic[index].rombase));

	/* Put a flag in bit 31 to denote whether to use the 16 bit NIC
	 * or 32 bit EASI variant of the bus access functions to avoid having to
	 * make lots of changes to the smc91cxx driver. The original address can be
	 * recovered by a left shift since hwbase is always at least word aligned.
	 */
	nic[index].controller.sc_bst = ((uintptr_t)nic[index].hwbase >> 1) |
	                               ((slot == NIC_IS_NIC_SLOT) ? 0x80000000 : 0);

	/* Crank up the speed */
	_swix(Podule_SetSpeed, _IN(0) | _IN(3), Podule_Speed_TypeC, slot);

	/* Back references to real */
	nicunit[unit] = &nic[unit].interface[0];
	nicunit[unit]->ctrl = &nic[unit];

	/* Prefer to use the machine's unique id if a NIC */
	info[0] = info[1] = 0;
	if (slot == NIC_IS_NIC_SLOT)
	{
		_swix(Podule_ReadInfo, _INR(0,3),
		      Podule_ReadInfo_EthernetAddress,
		      info, sizeof(info), slot);
		for (number = 0; number < ETHER_ADDR_LEN; number++)
		{
			const uint8_t *eui = (uint8_t *)info;

			/* Endian swap */
			nicunit[unit]->eui[ETHER_ADDR_LEN - number - 1] = eui[number];
		}
	}
	if ((info[0] | info[1]) == 0)
	{
		uint32_t size, type, current, next = 0;

		/* Then try the card's allocation */
		do
		{
			current = next;
			if (_swix(Podule_EnumerateChunks, _IN(0) | _IN(3) | _OUTR(0,2),
			          current, slot,
			          &next, &size, &type) != NULL)
			{
				break;
			}
			if ((type == DeviceType_EthernetID) && (size == ETHER_ADDR_LEN))
			{
				_swix(Podule_ReadChunk, _IN(0) | _INR(2,3),
				      current, nicunit[unit]->eui, slot);
				break;
			}
		} while (next != 0);
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

	/* Retrieve the CMOS options */
	nic[index].flags = NIC_FLAG_DEFAULT;
	if (nic[index].cmossize)
	{
		uint32_t flags;

		if (_swix(OS_Byte, _INR(0,1) | _OUT(2), OsByte_ReadCMOS, nic[index].cmos, &flags) == NULL)
		{
			switch (flags & (NIC_FLAG_LINKAUTO | NIC_FLAG_LINK100 | NIC_FLAG_LINKFULL))
			{
				case NIC_FLAG_LINKAUTO:
				case 0:
				case NIC_FLAG_LINK100:
				case NIC_FLAG_LINKFULL:
				case NIC_FLAG_LINK100 | NIC_FLAG_LINKFULL:
					nic[index].flags = flags;
					DPRINTF(("CMOS restored from 0x%X as 0x%X\n", nic[index].cmos, flags));
					break;

				default:
					_swix(OS_Byte, _INR(0,2), OsByte_WriteCMOS, nic[index].cmos, NIC_FLAG_DEFAULT);
					DPRINTF(("CMOS impossible combo, defaulted\n"));
					break;
			}
		}
	}

	/* Now, get attached to the chip */
	nic[index].ifp = &nic[index].controller.sc_ec.ec_if;
	nic[index].ifp->if_sadl = (struct sockaddr_dl *)nicunit[unit]->eui;
	smc91cxx_attach(&nic[index].controller, nicunit[unit]->eui);
	if ((nic[index].controller.sc_flags & SMC_FLAGS_ATTACHED) == 0)
	{
		DPRINTF(("No recognised MAC (or PHY) found\n"));
		nic[index].faulty |= NIC_FAULT_NO_LANCHIP;
		return;
	}
	DPRINTF(("Attached smc91cxx in slot %d as unit %s%d\n", slot, driver_name, unit));

	/* Attach and unmask the interrupt */
	error = _swix(OS_ClaimDeviceVector, _INR(0,4),
	              nic[index].irqdevice, ethery_interrupt, pw,
	              nic[index].private_irq, NIC_PRIVATE_IRQ_MASK);
	if (error != NULL)
	{
		nic[index].faulty |= NIC_FAULT_NO_VECTOR;
		return;
	}
	state = irqs_off();
	*nic[index].irqmask |= nic[index].irqbit;
	restore_irqs(state);

	/* Mark as configured successfully */
	nic[index].mtu = ETHERMTU;
	_swix(OS_ReadMonotonicTime, _OUT(0), &nic[index].starttime);
	nicunit[unit]->filters = NULL; 

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

		strcpy(locname, ethery_message_lookup((slot == NIC_IS_NIC_SLOT) ? MSG12_NIC : MSG13_PODULE,
		                                      NULL, NULL, NULL));
		sprintf((char *)nicunit[unit]->dib.dib_location, locname, slot);
	} 

	/* Fill in a device info block */
	nicunit[unit]->dib.dib_swibase = EtherY_00;
	nicunit[unit]->dib.dib_name = (unsigned char *)driver_name;
	nicunit[unit]->dib.dib_unit = unit;
	nicunit[unit]->dib.dib_address = nicunit[unit]->eui;
	nicunit[unit]->dib.dib_module = (unsigned char *)driver_title;
	nicunit[unit]->dib.dib_slot.sl_slotid = DIB_SLOT_PODULE(slot);
	nicunit[unit]->dib.dib_slot.sl_minor = 0;
	nicunit[unit]->dib.dib_slot.sl_pcmciaslot = 0;
	nicunit[unit]->dib.dib_slot.sl_mbz = 0;
	nicunit[unit]->dib.dib_inquire = INQ_MULTICAST |
	                                 INQ_PROMISCUOUS |
	                                 INQ_RXERRORS |
	                                 INQ_HWADDRVALID |
	                                 INQ_SOFTHWADDR |
	                                 INQ_HASSTATS;
}

static _kernel_oserror *ethery_config_link(const char *args)
{
	_kernel_oserror *error;
	struct { char *split[3]; char buffer[sizeof("uAutoFull") + 3]; } readargs;
	uint32_t count = 0;
	uint32_t flags;
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
		return ethery_error_lookup(ERR05_UNIT_IS_OFF);
	}

	/* Get the CMOS */
	error = _swix(OS_Byte, _INR(0,1) | _OUT(2), OsByte_ReadCMOS, nicunit[unit]->ctrl->cmos, &flags);
	if (error != NULL) return error;

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
	return _swix(OS_Byte, _INR(0,2), OsByte_WriteCMOS, nicunit[unit]->ctrl->cmos, flags);
}

static _kernel_oserror *ethery_config_advertise(const char *args)
{
	_kernel_oserror *error;
	struct { char *split[7]; char buffer[sizeof("u10HalfFull100HalfFull") + 7]; } readargs;
	uint32_t count = 0;
	uint32_t flags;
	bool     match = FALSE;
	uint16_t speed = 0, tk[2] = { 0, 0 };
	uint8_t  unit;

	/* Split & uppercase, the first 2 arguments must exist */
	error = _swix(OS_ReadArgs, _INR(0,3),
	              "/A,/A,,,,,", args, &readargs, sizeof(readargs));
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
		return ethery_error_lookup(ERR05_UNIT_IS_OFF);
	}

	/* Get the CMOS */
	error = _swix(OS_Byte, _INR(0,1) | _OUT(2), OsByte_ReadCMOS, nicunit[unit]->ctrl->cmos, &flags);
	if (error != NULL) return error;

	/* Tokenise the advertisements to make them easier to decode */
	count = 1;
	while (count < 7)
	{
		if (readargs.split[count] == NULL) break;
		if ((strcmp(readargs.split[count], "10") == 0) || (strcmp(readargs.split[count], "100") == 0))
		{
			/* Swap collection. If already got tokens, that's a bad repeat */
			speed = strcmp(readargs.split[count], "10") ? 1 : 0;
			if (tk[speed] != 0) return configure_TOO_MANY_PARAMS;
			tk[speed] |= 1;
			match = TRUE;
		}
		if (strcmp(readargs.split[count], "HALF") == 0) match = TRUE, tk[speed] = (tk[speed] << 4) | 2;
		if (strcmp(readargs.split[count], "FULL") == 0) match = TRUE, tk[speed] = (tk[speed] << 4) | 3;
		count++;
	}
	if (!match) return configure_BAD_OPTION;

	/* Check for the valid combinations */
	flags &= ~(NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF | NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF);
	for (count = 0; count < 6; count++)
	{
		                               /*            S     SH     SF    SHF    SFH */
		static const uint16_t valid[] = { 0x000, 0x001, 0x012, 0x013, 0x123, 0x132 };
		static const uint8_t bit10[]  = { 0,
		                                  NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF,
		                                  NIC_FLAG_AD10_HALF,
		                                  NIC_FLAG_AD10_FULL,
		                                  NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF,
		                                  NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF
		                                };
		static const uint8_t bit100[] = { 0,
		                                  NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF,
		                                  NIC_FLAG_AD100_HALF,
		                                  NIC_FLAG_AD100_FULL,
		                                  NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF,
		                                  NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF
		                                };

		if (tk[0] == valid[count]) flags |= bit10[count],  tk[0] = 0;
		if (tk[1] == valid[count]) flags |= bit100[count], tk[1] = 0;
	}
	if (tk[0] | tk[1]) return configure_TOO_MANY_PARAMS;

	DPRINTF(("Unit %s%d new CMOS flags 0x%X\n", driver_name, unit, flags));

	/* Note configure options are not applied until next reset */
	return _swix(OS_Byte, _INR(0,2), OsByte_WriteCMOS, nicunit[unit]->ctrl->cmos, flags);
}

static void ethery_lineup_info(ethery_msg_t tag, const char *value, uint32_t length)
{
	/* Regimented columns of information */
	length = length - printf(ethery_message_lookup(tag, NULL, NULL, NULL));
	while (length)
	{
		putchar(' ');
		length--;
	}
	printf(": %s\n", value);
}

static void ethery_interface_info(uint8_t which)
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
	       ethery_name_chip(nicunit[which]->ctrl),
	       msg,
	       ethery_message_lookup(nicunit[which]->ctrl->faulty ? MSG11_DOWN : MSG10_UP, NULL, NULL, NULL));

	/* Find where the columns line up */
	longest = strlen(ethery_message_lookup(MSG00_INFO_LENGTH, NULL, NULL, NULL));

	/* Driver */
	ethery_lineup_info(MSG01_IF_DRIVER, driver_name, longest);

	/* Unit */
	sprintf(msg, "%d", which);
	ethery_lineup_info(MSG02_IF_UNIT, msg, longest);

	/* Location */
	ethery_lineup_info(MSG03_IF_LOCATION, (char *)nicunit[which]->dib.dib_location, longest);

	/* EUI48 */
	sprintf(msg, "%02X:%02X:%02X:%02X:%02X:%02X",
	        nicunit[which]->eui[0], nicunit[which]->eui[1],
	        nicunit[which]->eui[2], nicunit[which]->eui[3],
	        nicunit[which]->eui[4], nicunit[which]->eui[5]);
	ethery_lineup_info(MSG04_IF_EUI, msg, longest);

	/* Controller */
	ethery_lineup_info(MSG05_IF_CONTROLLER, ethery_name_chip(nicunit[which]->ctrl), longest);

	/* Media state */
	physt = nicunit[which]->ctrl->ifp->phy_status;
	if (physt & PHYST_LNKFAIL)
	{
		strcpy(msg, ethery_message_lookup(MSG36_UNPLUGGED, NULL, NULL, NULL)); 
	}
	else
	{
		strcpy(msg, ethery_message_lookup((physt & PHYST_DPLXDET) ? MSG35_BT_FULLDUP :
		                                                            MSG34_BT_HALFDUP,
		                                  (physt & PHYST_SPDDET) ? "100" : "10", NULL, NULL));
	}
	ethery_lineup_info(MSG33_IF_MEDIA, msg, longest);

	/* Running time */
	_swix(OS_ReadMonotonicTime, _OUT(0), &now);
	now = (now - nicunit[which]->ctrl->starttime) / 100;
	sprintf(msg, ethery_message_lookup(MSG09_TIME_FORMAT, NULL, NULL, NULL),
	        now / 86400, (now % 86400) / 3600, (now % 3600) / 60, now % 60);
	ethery_lineup_info(MSG06_IF_RUNTIME, msg, longest);

	/* Copyright notice */
	strcpy(msg, ethery_message_lookup(MSG14_AUTHOR, NULL, NULL, NULL));
	ethery_lineup_info(MSG07_IF_ATTRIBUTE, msg, longest);
	strcpy(msg, ethery_message_lookup(MSG15_AUTHOR, NULL, NULL, NULL));
	ethery_lineup_info(MSG19_EMPTY, msg, longest);

	/* Send and receive stats */
	sprintf(msg, "%u", nicunit[which]->tx_packets);
	ethery_lineup_info(MSG20_STAT_P_SENT, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_packets);
	ethery_lineup_info(MSG21_STAT_P_RECEIVED, msg, longest);
	sprintf(msg, "%u", nicunit[which]->tx_bytes);
	ethery_lineup_info(MSG22_STAT_B_SENT, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_bytes);
	ethery_lineup_info(MSG23_STAT_B_RECEIVED, msg, longest);
	sprintf(msg, "%u", nicunit[which]->tx_errors);
	ethery_lineup_info(MSG24_STAT_E_SENT, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_errors);
	ethery_lineup_info(MSG25_STAT_E_RECEIVED, msg, longest);
	sprintf(msg, "%u", nicunit[which]->rx_discards);
	ethery_lineup_info(MSG26_STAT_UNDELIVERED, msg, longest);

	/* Registered frame filters */
	sprintf(msg, "%s\n", ethery_message_lookup(MSG31_FRAME_DESC, NULL, NULL, NULL));
	for (level = FRMLVL_IEEE; level >= FRMLVL_E2SPECIFIC; level--)
	{
		bool shown = FALSE;
		static const ethery_msg_t headings[] = { MSG30_FRAME_STANDARD,
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
					printf("\n%s:\n\n", ethery_message_lookup(headings[level - 1], NULL, NULL, NULL));
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
void ethery_review_levels(uint8_t unit)
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
	nicunit[unit]->ctrl->ifp->if_ioctl(nicunit[unit]->ctrl->ifp, SIOCSETERRLVL, &elevel);
	nicunit[unit]->ctrl->ifp->if_ioctl(nicunit[unit]->ctrl->ifp, SIOCSETPROMISC, &alevel);
}

/*
 * Internationalised messages
 */
char *ethery_message_lookup(ethery_msg_t which, const char *arg1, const char *arg2, const char *arg3)
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
_kernel_oserror *ethery_error_lookup(ethery_err_t which)
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
		error.errnum = ErrorBase_Castle10_100 + which - ErrorBase_UnixRange;
	}

	return &error;
}

/*
 * Ticker heartbeat
 */
_kernel_oserror *ethery_heartbeat_handler(_kernel_swi_regs *r, void *pw)
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
_kernel_oserror *ethery_interrupt_handler(_kernel_swi_regs *r, void *pw)
{
	uint8_t index;
	volatile uint8_t *irqctrl;

	for (index = 0; index < NIC_MAX_CONTROLLERS; index++)
	{
		if (!nic[index].running) continue;
		irqctrl = nic[index].private_irq;
		if (*irqctrl & NIC_PRIVATE_IRQ_MASK)
		{
			/* It is running and there is an interrupt pending */
			*irqctrl = 0;
			bus_flush(irqctrl);
			smc91cxx_intr(&nic[index].controller);
			*irqctrl = NIC_PRIVATE_IRQ_MASK;
		}
	}

	UNUSED(r);
	UNUSED(pw);

	return NULL;
}

/*
 * Callback when linked into the module chain
 */
_kernel_oserror *ethery_driver_linked_handler(_kernel_swi_regs *r, void *pw)
{
	uint8_t  oldmbs, unit;
	char     var[8];
	uint32_t length;

	/* Here because the MbufManager started or via callback now my SWIs
	 * are available, either way, try opening an MbufManager session.
	 */
	oldmbs = mbufsession;
	ethery_start_mbuf_session();
	if ((oldmbs != mbufsession) && mbufsession)
	{
		/* Start 1s watchdog */
		_swix(OS_CallEvery, _INR(0,2), 100, ethery_heartbeat, pw);

		/* Enable send/receive */
		DPRINTF(("Got mbufs, going online\n"));

		/* Transitioned to functioning state */
		for (unit = 0; unit < units; unit++)
		{
			struct ifnet *ifp = nicunit[unit]->ctrl->ifp;

			if (!nicunit[unit]->ctrl->faulty)
			{
				if (!nicunit[unit]->ctrl->running)
				{
					ifp->if_ioctl(ifp, SIOCDRIVERINIT, NULL);
					nicunit[unit]->ctrl->running = TRUE;
					*nicunit[unit]->ctrl->private_irq = NIC_PRIVATE_IRQ_MASK;
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
_kernel_oserror *ethery_init(const char *cmd_tail, int podule_base, void *pw)
{
	uint8_t  header[16];
	uint16_t manufacturer, product;
	int32_t  number, slot;
	_kernel_oserror *error;

	error = ethery_open_messages();
	if (error != NULL) return error;

	/* Only 1 instance, but can support multiple hardware */
	if (podule_base == 1)
	{
		error = ethery_error_lookup(ERR03_SINGLE_INSTANCE);
		goto init_fail;
	}

	/* Check for podule support */
	if ((_swix(Podule_ReturnNumber, _OUT(0), &number) != NULL) ||
	    (number == 0))
	{
		error = ethery_error_lookup(ERR00_NO_PODULES);
		goto init_fail;
	}

	/* Look for any of the supported network adapters */
	for (slot = 0; slot < number; slot++)
	{
		if (_swix(Podule_ReadHeader, _INR(2,3), header, slot) != NULL)
		{
			/* Nothing in that slot */
			continue;
		}

		manufacturer = header[5] | (header[6] << 8);
		product =      header[3] | (header[4] << 8);
		if ((product != ProdType_Castle10_100) || (manufacturer != Manf_CastleTechnology))
		{
			/* Not one of the ones we support */
			continue;
		}

		/* Try to add that one.
		 * As there's no support for virtual interfaces, the interface array
		 * index is the same as the unit number.
		 * Note that the addition might fail but we must assign a unit
		 * number anyway so that the unit numbers match up with what AutoSense
		 * would guess, since it can't know whether there's a fault or not.
		 */
		ethery_add_interface(units, units, slot, pw);
		units++;
		if (units == (NIC_MAX_CONTROLLERS * NIC_MAX_INTERFACES)) break;
	}
	DPRINTF(("Total of %d %s interfaces\n", units, driver_title));
	if (units == 0)
	{
		error = ethery_error_lookup(ERR01_NO_SUPPORTED_ETHERY);
		goto init_fail;
	}

	/* Everything else has to be done on a callback once my SWIs are available */
	_swix(OS_AddCallBack, _INR(0,1), ethery_driver_linked, pw);

	UNUSED(cmd_tail);

	return NULL;

init_fail:
	units = 0;
	ethery_destroy_messages();

	return error;
}

/*
 * Finalisation
 */
_kernel_oserror *ethery_final(int fatal, int podule, void *pw)
{
	uint8_t unit;

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
		ethery_stop_mbuf_session();
		ethery_destroy_messages();
	}

	/* Halt any booked callbacks */
	_swix(OS_RemoveTickerEvent, _INR(0,1), ethery_heartbeat, pw);
	_swix(OS_RemoveCallBack, _INR(0,1), ethery_driver_linked, pw);

	for (unit = 0; unit < units; unit++)
	{
		if (nicunit[unit]->ctrl->running)
		{
			struct ifnet *ifp = nicunit[unit]->ctrl->ifp;

			/* Go offline */
			DPRINTF(("NIC in slot %d going offline\n", nicunit[unit]->ctrl->podule));
			*nicunit[unit]->ctrl->private_irq = 0;
			bus_flush(nicunit[unit]->ctrl->private_irq);
			nicunit[unit]->ctrl->running = FALSE;
			ifp->if_ioctl(ifp, SIOCDRIVERSTOP, NULL);

			/* Get off the vector */
			_swix(OS_ReleaseDeviceVector, _INR(0,4),
			      nicunit[unit]->ctrl->irqdevice, ethery_interrupt, pw,
			      nicunit[unit]->ctrl->private_irq, NIC_PRIVATE_IRQ_MASK);
			DPRINTF(("Hardware shut down\n"));
		}
	}

	UNUSED(podule);

	return NULL;
}

/*
 * Service call handler
 */
void ethery_services(int service_number, _kernel_swi_regs *r, void *pw)
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
					ethery_driver_linked_handler(r, pw);
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
			ethery_final(-1, 0, pw);
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
			(*(void (*)(void *, void *, void *, void *))r->r[2])(ethery_messages(), 0, 0, (void *)r->r[3]);
			break;
#endif
	}
}

/*
 * Command handler
 */
_kernel_oserror *ethery_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
	_kernel_oserror *error;
	uint32_t select;
	uint32_t flags;

	switch (cmd_no)
	{
		case CMD_EYInfo:
			if (argc == 0)
			{
				/* When not specified, do all */
				if (units == 0) return ethery_error_lookup(ERR05_UNIT_IS_OFF);
				printf("%s\n", ethery_message_lookup(MSG18_INFO_STATS, NULL, NULL, NULL));
				for (select = 0; select < units; select++)
				{
					ethery_interface_info(select);
				}
			}
			else
			{
				error = _swix(OS_ReadUnsigned, _INR(0,1) | _OUT(2),
				              10, arg_string, &select);
				if (error) return error;
				if (select >= units) return ethery_error_lookup(ERR05_UNIT_IS_OFF);
				printf("%s\n", ethery_message_lookup(MSG18_INFO_STATS, NULL, NULL, NULL));
				ethery_interface_info(select);
			}
			break;

		case CMD_EYTest:
			if (argc == 0)
			{
				/* When not specified, do all */
				if (units == 0) return ethery_error_lookup(ERR05_UNIT_IS_OFF);
				for (select = 0; select < units; select++)
				{
					printf("%s%d %s", driver_name,
					                  select,
					                  ethery_message_lookup(MSG32_SELFTEST, NULL, NULL, NULL));
					printf(" %s\n", ethery_message_lookup(nicunit[select]->ctrl->faulty ?
					                                      MSG17_FAILED :
					                                      MSG16_PASSED, NULL, NULL, NULL));
				}
			}
			else
			{
				error = _swix(OS_ReadUnsigned, _INR(0,1) | _OUT(2),
				              10, arg_string, &select);
				if (error) return error;
				if (select >= units) return ethery_error_lookup(ERR05_UNIT_IS_OFF);
				printf("%s%d %s", driver_name,
				                  select,
				                  ethery_message_lookup(MSG32_SELFTEST, NULL, NULL, NULL));
				printf(" %s\n", ethery_message_lookup(nicunit[select]->ctrl->faulty ?
				                                      MSG17_FAILED :
				                                      MSG16_PASSED, NULL, NULL, NULL));
			}
			break;

		case CMD_EYLink:
			/* Check for *STATUS and *CONFIGURE alone */
			if (arg_string == arg_STATUS)
			{
				for (select = 0; select < units; select++)
				{
					error = _swix(OS_Byte, _INR(0,1) | _OUT(2),
					              OsByte_ReadCMOS, nicunit[select]->ctrl->cmos, &flags);
					if (error != NULL) return NULL;

					printf("EYLink      %u %s%s\n", select,
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
				printf("EYLink      <%s> Auto | 10 Half|Full | 100 Half|Full\n",
				       ethery_message_lookup(MSG37_UNITNO, NULL, NULL, NULL));

				return NULL;
			}

			/* Otherwise, trying to set it */
			return ethery_config_link(arg_string);

		case CMD_EYAdvertise:
			/* Check for *STATUS and *CONFIGURE alone */
			if (arg_string == arg_STATUS)
			{
				for (select = 0; select < units; select++)
				{
					error = _swix(OS_Byte, _INR(0,1) | _OUT(2),
					              OsByte_ReadCMOS, nicunit[select]->ctrl->cmos, &flags);
					if (error != NULL) return NULL;

					printf("EYAdvertise %u%s%s%s%s%s%s\n", select,
					       flags & (NIC_FLAG_AD10_FULL | NIC_FLAG_AD10_HALF) ? " 10" : "",
					       flags & NIC_FLAG_AD10_FULL ? " Full" : "",
					       flags & NIC_FLAG_AD10_HALF ? " Half" : "",
					       flags & (NIC_FLAG_AD100_FULL | NIC_FLAG_AD100_HALF) ? " 100" : "",
					       flags & NIC_FLAG_AD100_FULL ? " Full" : "",
					       flags & NIC_FLAG_AD100_HALF ? " Half" : "");
				}

				return NULL;
			}
			if (arg_string == arg_CONFIGURE_SYNTAX)
			{
				/* Configure keywords aren't internationalised,
				 * so the syntax mustn't be either.
				 */
				printf("EYAdvertise <%s> [10 [Half] [Full]] [100 [Half] [Full]]\n",
				       ethery_message_lookup(MSG37_UNITNO, NULL, NULL, NULL));

				return NULL;
			}

			/* Otherwise, trying to set it */
			return ethery_config_advertise(arg_string);
	}

	UNUSED(pw);

	return NULL;
}

/*
 * SWI handler
 */
_kernel_oserror *ethery_swis(int swi_offset, _kernel_swi_regs *r, void *pw)
{
	/* The veneer preserves the old interrupt state */
	ensure_irqs_on();

	switch (swi_offset)
	{
		case EtherY_DCIVersion - EtherY_00:
			if (r->r[0] != 0) return ethery_error_lookup((ethery_err_t)EINVAL);
			r->r[1] = DCIVERSION;
			break;

		case EtherY_Inquire - EtherY_00:
			if (r->r[0] != 0) return ethery_error_lookup((ethery_err_t)EINVAL);
			if (r->r[1] >= units) return ethery_error_lookup((ethery_err_t)ENXIO);
			r->r[2] = nicunit[r->r[1]]->dib.dib_inquire;
			break;

		case EtherY_GetNetworkMTU - EtherY_00:
			if (r->r[0] != 0) return ethery_error_lookup((ethery_err_t)EINVAL);
			if (r->r[1] >= units) return ethery_error_lookup((ethery_err_t)ENXIO);
			r->r[2] = nicunit[r->r[1]]->ctrl->mtu;
			break;

		case EtherY_SetNetworkMTU - EtherY_00:
			/* Ethernet II has a fixed MTU */
			if (r->r[0] != 0) return ethery_error_lookup((ethery_err_t)EINVAL);
			if (r->r[1] >= units) return ethery_error_lookup((ethery_err_t)ENXIO);
			if (r->r[2] != ETHERMTU) return ethery_error_lookup((ethery_err_t)ENOTTY);
			break;

		case EtherY_Stats - EtherY_00:
			if (r->r[0] > 1) return ethery_error_lookup((ethery_err_t)EINVAL);
			if (r->r[1] >= units) return ethery_error_lookup((ethery_err_t)ENXIO);
			ethery_stats((r->r[0] & 1) ? TRUE : FALSE, (uint8_t)r->r[1], (struct stats *)r->r[2]);
			break;

		case EtherY_Filter - EtherY_00:
			if (r->r[0] >= FILTER_1STRESERVED) return ethery_error_lookup((ethery_err_t)EINVAL);
			if (r->r[1] >= units) return ethery_error_lookup((ethery_err_t)ENXIO);
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

		case EtherY_Transmit - EtherY_00:
			if (r->r[0] >= TX_1STRESERVED) return ethery_error_lookup((ethery_err_t)EINVAL);
			if (r->r[1] >= units) return ethery_error_lookup((ethery_err_t)ENXIO);
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
				if (error >= 0) return ethery_error_lookup((ethery_err_t)error);
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
				if (error >= 0) return ethery_error_lookup((ethery_err_t)error);
			}
			break;

		default:
			DPRINTF(("SWI offset %d invalid\n", swi_offset));
			return error_BAD_SWI;
	}

	UNUSED(pw);

	return NULL;
}
