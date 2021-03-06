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
/* showrt.c
 *
 * Author: Keith Ruttle (Acorn)
 *
 * Description
 * ===========
 * Code to support *Networks command
 *
 * Environment
 * ===========
 * Acorn RISC OS 3.11 or later.
 *
 * Compiler
 * ========
 * Acorn Archimedes C release 5.06 or later.
 *
 * Change record
 * =============
 *
 * JPD  Jem Davies (Cambridge Systems Design)
 *
 *
 * 12-Dec-94  09:36  JPD  Version 1.00
 * First version with change record. Modified: #includes to be ANSI-compliant.
 *
 * 13-Jan-95  12:17  JPD  Version 1.01
 * Modified to add static declarations and begin changes to enable
 * compilation with -fah option.
 *
 * 19-Jan-95  11:04  JPD  Version 1.02
 * Correct problem in mns_showroutes() with mbuf handling
 *
 * 14-Mar-95  15:47  JPD  Version 1.03
 * Removed OldCode.
 *
 * 11-Oct-95  17:33  JPD  Version 1.04
 * Changed to make sprintnet() and sprintroute() not static: needed by NetG.
 *
 *
 **End of change record*
 */

#include <stdio.h>
#include <string.h>

#include "kernel.h"

#include "sys/types.h"
#include "sys/socket.h"
#include "sys/ioctl.h"
#include "sys/mbuf.h"
#include "net/route.h"
#include "netinet/in.h"
#include "nlist.h"

#include "module.h"
#include "mnscommon.h"
#include "mns.h"
#include "showrt.h"
#include "socklib.h"

static void p_tree(struct radix_node *rn);

/******************************************************************************/

void mns_showroutes(void)
{
#define kread(v, b, l) (memcpy((b), (void *)(v), (l)))
#define kget(p, d) (kread((u_long)(p), (char *)&(d), sizeof (d)))
   struct nlist nl[] = { { "_rt_tables" }, "" };
   struct radix_node_head *rt_tables[AF_MAX];
   struct radix_node_head *rnh, head;
   /* If we've received map info from a !Gateway, get it */
   if ((mns.mns_flags & MNS_SEEKADDR) != 0 || kvm_nlist(0, nl) < 0)
      return;

   kget(nl[0].n_value, rt_tables);

   if ((rnh = rt_tables[AF_INET]) == 0)
      return;
   kget(rnh, head);
   p_tree(head.rnh_treetop);

   return;
} /* mns_showroutes() */

static void p_rtentry(struct rtentry *rt);

static struct	rtentry rtentry;
static struct	radix_node rnode;

static void p_tree(struct radix_node *rn)
{

again:
	kget(rn, rnode);
	if (rnode.rn_b < 0) {
		if (!(rnode.rn_flags & RNF_ROOT)) {
			kget(rn, rtentry);
			p_rtentry(&rtentry);
		}
		if (rn = rnode.rn_dupedkey)
			goto again;
	} else {
		rn = rnode.rn_r;
		p_tree(rnode.rn_l);
		p_tree(rn);
	}
}

static void p_rtentry(struct rtentry *rt)
{
	/*
	 * Don't print cloned routes
	 */
	if (rt->rt_parent || (rt->rt_flags & RTF_WASCLONED))
		return;

        /* print the name of the network */
        printf("%-16s", sprintnet(rt_key(rt)));
        /* if a gateway print "gateway = " and address of gateway */
        if (rt->rt_flags & RTF_GATEWAY)
           printf("%s=%s\n", mns_str(Str_Gteway),sprintroute(rt->rt_gateway));
        else
           /* print "local" to show this name is name of local network */
           printf("%s\n", mns_str(Str_Local));
}

/******************************************************************************/

char *sprintroute(struct sockaddr *sa)
{
/*
 * return network address (as a string) of a gateway to a network
 */

   static char line[32];
   struct in_addr in;

   in = ((struct sockaddr_in *)sa)->sin_addr;
   in.s_addr = ntohl(in.s_addr);
#define C(x) ((x) & 0xff)
#ifdef FULL
   (void) sprintf(line, "%u.%u.%u.%u", C(in.s_addr >> 24),
                           C(in.s_addr >> 16), C(in.s_addr >> 8), C(in.s_addr));
#else
   (void) sprintf(line, "%lu.%lu", C(in.s_addr >> 8), C(in.s_addr));
#endif
   return line;

} /* sprintroute() */

/******************************************************************************/

char *sprintnet(struct sockaddr *sa)
{
/*
 * return network name (as a string) of a network address
 */

   static char line[32];
   struct in_addr in;

   in = ((struct sockaddr_in *)sa)->sin_addr;
   in.s_addr = ntohl(in.s_addr);
   if (!mns_addrtoname(line, in.s_addr))
      (void) sprintf(line, "%lu.%lu", C(in.s_addr >> 24), C(in.s_addr >> 16));

   return line;

} /* sprintnet() */

/******************************************************************************/

/* EOF showrt.c */
