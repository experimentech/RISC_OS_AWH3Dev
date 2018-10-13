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
/* input.c
 *
 * Author: Keith Ruttle (Acorn)
 *
 * Description
 * ===========
 * RIP Input routine
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
 * 13-Oct-95  15:43  JPD  Version 1.00
 * First version with change record.
 *
 *
 **End of change record*
 */

#ifdef OldCode

#include "defs.h"
#include <sys/syslog.h>
#else

#include <string.h>

#include "sys/types.h"
#include "sys/socket.h"
#include "net/if.h"
#include "netinet/in.h"
#include "net/route.h"
#include "protocols/routed.h"

#include "mnsg.h"
#include "debug.h"
#include "interface.h"
#include "table.h"
#include "data.h"
#include "startup.h"
#include "trace.h"
#include "defs.h"
#include "input.h"
#endif

/******************************************************************************/

#ifdef OldCode
extern int startup_timer, not_routing;
#endif

/******************************************************************************/
#ifdef OldCode
/*
 * Process a newly received packet.
 */
rip_input(from, rip, size)
        struct sockaddr *from;
        struct rip *rip;
        int size;
{
        struct rt_entry *rt;
        struct netinfo *n;
        struct interface *ifp;
        struct interface *if_ifwithdstaddr();
        int count;
        static struct sockaddr badfrom, badfrom2;

        ifp = 0;
        TRACE_INPUT(ifp, from, (char *)rip, size);
        if (rip->rip_vers == 0)
                return;
        switch (rip->rip_cmd) {

        case RIPCMD_REQUEST:
                n = rip->rip_nets;
                count = size - ((char *)n - (char *)rip);
                if (count < sizeof (struct netinfo))
                        return;
                for (; count > 0; n++) {
                        if (count < sizeof (struct netinfo))
                                break;
                        count -= sizeof (struct netinfo);
                        n->rip_metric = ntohl(n->rip_metric);

                        if (n->rip_dst.sa_family == AF_UNSPEC && n->rip_metric == HOPCNT_INFINITY && count == 0) {
                                supply(from, 0, 0);
                                return;
                        }
                        rt = rtlookup(&n->rip_dst);
                        n->rip_metric = rt == 0 ? HOPCNT_INFINITY :
                                min(rt->rt_metric + 1, HOPCNT_INFINITY);
                        n->rip_metric = htonl(n->rip_metric);
                }
                rip->rip_cmd = RIPCMD_RESPONSE;
                memcpy(packet, (char *)rip, size);
                inet_output(*routedsock, 0, from, size);
                return;

        case RIPCMD_TRACEON:
        case RIPCMD_TRACEOFF:
                return;

        case RIPCMD_RESPONSE:
                ifp = if_ifwithaddr(from);
                if (ifp || not_routing)
                        return;

                if (startup_timer)
                        startup_timer = 0;
                if ((rt = rtfind(from)) && (rt->rt_state & (RTS_INTERFACE | RTS_REMOTE)))
                        rt->rt_timer = 0;
                else if ((ifp = if_ifwithdstaddr(from)) &&
                    (rt == 0 || rt->rt_metric >= ifp->int_metric))
                        addrouteforif(ifp);

                if ((ifp = if_iflookup(from)) == 0 || (ifp->int_flags &
                    (IFF_BROADCAST | IFF_POINTOPOINT | IFF_REMOTE)) == 0) {
                        if (memcmp((char *)from, (char *)&badfrom, sizeof(badfrom)) != 0)
                                badfrom = *from;
                        return;
                }
                size -= 4 * sizeof (char);
                n = rip->rip_nets;
                for (; size > 0; size -= sizeof (struct netinfo), n++) {
                        if (size < sizeof (struct netinfo))
                                break;
                        n->rip_metric = ntohl(n->rip_metric);
                        if (n->rip_metric == 0 || (unsigned) n->rip_metric > HOPCNT_INFINITY) {
                                if (memcmp((char *)from, (char *)&badfrom2, sizeof(badfrom2)) != 0)
                                        badfrom2 = *from;
                                continue;
                        }

                        if ((unsigned) n->rip_metric < HOPCNT_INFINITY)
                                n->rip_metric += ifp->int_metric;
                        if ((unsigned) n->rip_metric > HOPCNT_INFINITY)
                                n->rip_metric = HOPCNT_INFINITY;
                        rt = rtlookup(&n->rip_dst);
                        if (rt == 0 || (rt->rt_state & (RTS_INTERNAL|RTS_INTERFACE)) == (RTS_INTERNAL|RTS_INTERFACE)) {
                                /*
                                 * If we're hearing a logical network route
                                 * back from a peer to which we sent it,
                                 * ignore it.
                                 */
                                if (rt && rt->rt_state & RTS_SUBNET && inet_sendroute(rt, from))
                                        continue;
                                if ((unsigned)n->rip_metric < HOPCNT_INFINITY) {
                                    /*
                                     * Look for an equivalent route that
                                     * includes this one before adding
                                     * this route.
                                     */
                                    rt = rtfind(&n->rip_dst);
                                    if (rt && equal(from, &rt->rt_router))
                                            continue;
                                    rtadd(&n->rip_dst, from, n->rip_metric, 0);
                                    setrtdelay();
                                }
                                continue;
                        }

                        if (n->rip_metric < rt->rt_metric) {
                                 rtchange(rt, from, n->rip_metric);
                                 setrtdelay();
                                 rt->rt_timer = 0;
                        }
                }
                return;
        }
}
#else

void rip_input(struct sockaddr *from, struct rip *rip, int size)
{
/*
 * Process a newly received packet.
 */

   struct rt_entry *rt;
   struct netinfo *n;
   struct interface *ifp;
   int count;
   static struct sockaddr badfrom, badfrom2;

   DEBUGP2("#rip_input() from %08X\n\r",
                                 ((struct sockaddr_in *)from)->sin_addr.s_addr);

   ifp = 0;

   DEBUGP2("#Calling TRACE_INPUT, traceactions = %d\n\r", traceactions);
   TRACE_INPUT(ifp, (struct sockaddr_in *)from, (char *)rip, size);

   if (rip->rip_vers == 0)
      return;

   switch (rip->rip_cmd)
   {
      case RIPCMD_REQUEST:
         DEBUGP1("#rip_input() RIPCMD_REQUEST\n\r");
         n = rip->rip_nets;
         count = size - ((char *)n - (char *)rip);

         if (count < sizeof (struct netinfo))
            return;

         for (; count > 0; n++)
         {
            if (count < sizeof (struct netinfo))
               break;
            count -= sizeof (struct netinfo);
            n->rip_metric = ntohl(n->rip_metric);

            if (n->rip_dst.sa_family == AF_UNSPEC &&
                                 n->rip_metric == HOPCNT_INFINITY && count == 0)
            {
               supply(from, 0, 0);
               return;
            }

            rt = rtlookup(&n->rip_dst);
            n->rip_metric = rt == 0 ? HOPCNT_INFINITY :
                    min(rt->rt_metric + 1, HOPCNT_INFINITY);
            n->rip_metric = htonl(n->rip_metric);
         }
         rip->rip_cmd = RIPCMD_RESPONSE;
         memcpy(packet, (char *)rip, size);
         inet_output(*routedsock, 0, from, size);
         return;

      case RIPCMD_TRACEON:
      case RIPCMD_TRACEOFF:
         return;

      case RIPCMD_RESPONSE:
         DEBUGP1("#rip_input() RIPCMD_RESPONSE\n\r");
         ifp = if_ifwithaddr(from);
         if (ifp || not_routing)
            return;

         if (startup_timer)
            startup_timer = 0;

         if ((rt = rtfind(from)) &&
                                  (rt->rt_state & (RTS_INTERFACE | RTS_REMOTE)))
            rt->rt_timer = 0;
         else
            if ((ifp = if_ifwithdstaddr(from)) &&
                                  (rt == 0 || rt->rt_metric >= ifp->int_metric))
               addrouteforif(ifp);

         if ((ifp = if_iflookup(from)) == 0 || (ifp->int_flags &
                           (IFF_BROADCAST | IFF_POINTOPOINT | IFF_REMOTE)) == 0)
         {
            if (memcmp((char *)from, (char *)&badfrom, sizeof(badfrom)) != 0)
               badfrom = *from;
            return;
         }

         size -= 4 * sizeof (char);
         n = rip->rip_nets;
         for (; size > 0; size -= sizeof (struct netinfo), n++)
         {
            if (size < sizeof (struct netinfo))
               break;

            n->rip_metric = ntohl(n->rip_metric);
            if (n->rip_metric == 0 ||
                                     (unsigned) n->rip_metric > HOPCNT_INFINITY)
            {
               if (memcmp((char *)from, (char *)&badfrom2, sizeof(badfrom2))
                                                                          != 0)
                  badfrom2 = *from;
               continue;
            }

            if ((unsigned) n->rip_metric < HOPCNT_INFINITY)
               n->rip_metric += ifp->int_metric;
            if ((unsigned) n->rip_metric > HOPCNT_INFINITY)
               n->rip_metric = HOPCNT_INFINITY;
            rt = rtlookup(&n->rip_dst);
            if (rt == 0 || (rt->rt_state & (RTS_INTERNAL|RTS_INTERFACE)) ==
                                                   (RTS_INTERNAL|RTS_INTERFACE))
            {
               /*
                * If we're hearing a logical network route back from a peer to
                * which we sent it, ignore it.
                */
               if (rt && rt->rt_state & RTS_SUBNET && inet_sendroute(rt, from))
                  continue;
               if ((unsigned)n->rip_metric < HOPCNT_INFINITY)
               {
                  /*
                   * Look for an equivalent route that
                   * includes this one before adding
                   * this route.
                   */
                  rt = rtfind(&n->rip_dst);
                  if (rt && equal(from, &rt->rt_router))
                     continue;
                  rtadd(&n->rip_dst, from, n->rip_metric, 0);
                  setrtdelay();
               }
               continue;
            }

            if (n->rip_metric < rt->rt_metric)
            {
               rtchange(rt, from, n->rip_metric);
               setrtdelay();
               rt->rt_timer = 0;
            }
         }
      return;
   }

} /* rip_input() */

#endif

/******************************************************************************/

/* EOF input.c */
