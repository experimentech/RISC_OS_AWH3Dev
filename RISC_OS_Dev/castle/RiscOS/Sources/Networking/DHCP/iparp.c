/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 *
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 *
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
/*
 *  DHCP (iparp.c)
 *
 * Copyright (C) Element 14 Ltd. 1999
 *
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "kernel.h"
#include "swis.h"

#include "sys/types.h"
#include "sys/dcistructs.h"
#include "sys/file.h"
#include "sys/socket.h"
#include "sys/sysctl.h"
#include "net/if.h"
#include "net/if_dl.h"
#include "net/if_types.h"
#include "net/route.h"
#include "netinet/in.h"
#include "netinet/if_ether.h"
#include "arpa/inet.h"
#include "protocols/dhcp.h"
#include "sys/errno.h"
#include "socklib.h"

#include "dhcpintern.h"
#include "interfaces.h"
#include "packets.h"
#include "consts.h"
#include "module.h"
#include "sockets.h"
#include "iparp.h"

/* This code has been adapted from the ARP command-line utility
 *
 * It extracts the ARP cache from the Internet module and then searches through it
 * for the address of the proposed IP address.  arp_for_ip will return 0 if the IP
 * address does not appear in the ARP cache or if it is there and the hardware
 * address matches our local hardware address for the interface.  It returns -1
 * otherwise, indicating that the address is believed to be in and that we should
 * send a DHCPDECLINE to the server which offered it to us.
 *
 */

static char *iparp_get_arp_cache(size_t *needed)
{
        char *buf;
	int mib[6];
	mib[0] = CTL_NET;
	mib[1] = PF_ROUTE;
	mib[2] = 0;
	mib[3] = AF_INET;
	mib[4] = NET_RT_FLAGS;
	mib[5] = RTF_LLINFO;

	if (sysctl(mib, sizeof(mib)/sizeof(*mib), NULL, needed, NULL, 0) < 0) {
	        trace(("sysctl(1) -> %d\n", errno));
	        return NULL;
	}
	if (*needed == 0)
		return NULL; /* Avoid bogus error report in trace */

	buf = malloc(*needed);
	if (buf != NULL) {
		if (sysctl(mib, sizeof(mib)/sizeof(*mib), buf, needed, NULL, 0) < 0) {
	        	trace(("sysctl(2) -> %d\n", errno));
		        free(buf);
		        buf = NULL;
		}
	}
	else {
	        trace(("iparp: malloc failed (needed %d)\n", *needed));
	}

	return buf;
}

static int iparp_search(char *buf, char *lim, u_long sought, void *dib_address, int write_ea)
{
	char *next;
	struct rt_msghdr *rtm;
	struct sockaddr_inarp *sin;
	struct sockaddr_dl *sdl;

	for (next = buf; next < lim; next += rtm->rtm_msglen) {
		rtm = (struct rt_msghdr *)next;
		sin = (struct sockaddr_inarp *)(rtm + 1);
		sdl = (struct sockaddr_dl *)(sin + 1);
		if (sought != sin->sin_addr.s_addr)
			continue;
		if (sdl->sdl_alen) {
		        if (write_ea) {
		                memcpy(dib_address, LLADDR(sdl), sizeof(struct ether_addr));
		                return 0;
		        }
			else if (memcmp(LLADDR(sdl), dib_address, sizeof(struct ether_addr)) == 0) {
			        /* OK - ARP entry matches us */
			        trace(("iparp: Local ARP cache has our address and it's right\n"));
			        break;
			}
			trace(("iparp: Local ARP cache knows this IP address and it's WRONG\n"));
			trace(("iparp: iparp recommends that we decline this address\n"));
			return -1;
		}
		break;
	}

	/* OK - we are happy - there were no conflicts in the local ARP cache */
	return 0;
}

/*
 * RG: changed to take a DIB as 1st parameter instead of interface block
 * This is so we can do an ARP lookup after deleting an interface
*/
int arp_for_ip(Dib *dib, u_long addr)
{
        int res;
        char *buf;
	size_t needed;

	/* Should we attempt to force a network ARP lookup to find this address first? */

	buf = iparp_get_arp_cache(&needed);
	if (buf == NULL) {
	        /* Unable to retrieve ARP cache - allow address to go through as we don't know */
	        trace(("iparp: Unable to read ARP cache from Internet module\n"));
	        res = 0;
	}
	else {
		res = iparp_search(buf, buf + needed, addr, dib->dib_address, 0);
		free(buf);
	}

	return res;
}


int iparp_lookup_local_ip_address(struct in_addr ia, struct ether_addr *ea)
{
        int res;
        char *buf;
	size_t needed;

	buf = iparp_get_arp_cache(&needed);
	if (buf == NULL) {
	        /* Unable to retrieve ARP cache - allow address to go through as we don't know */
	        trace(("iparp: Unable to read ARP cache from Internet module\n"));
	        res = 0;
	}
	else {
		res = iparp_search(buf, buf + needed, ia.s_addr, ea, 1);
		free(buf);
	}

	return res;
}
