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
/* output.c
 *
 * Author: Keith Ruttle (Acorn)
 *
 * Description
 * ===========
 * Output routines
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
 * 05-Oct-95  17:36  JPD  Version 1.00
 * First version with change record.
 *
 *
 **End of change record*
 */

#ifdef OldCode

#include "defs.h"

#include "net/if.h"

#else

#include <string.h>

#include "sys/types.h"
#include "sys/socket.h"
#include "net/if.h"
#include "netinet/in.h"
#include "net/route.h"
#include "protocols/routed.h"

#include "module.h"
#include "mnsg.h"
#include "interface.h"
#include "table.h"
#include "data.h"
#include "trace.h"
#include "output.h"
#endif

/******************************************************************************/

#ifdef OldCode
/*
 * Apply the function "f" to all non-passive
 * interfaces.
 */
toall(f)
        int (*f)();
{
        struct interface *ifp;
        extern struct interface *ifnet;

        for (ifp = ifnet; ifp; ifp = ifp->int_next)
                (*f)(&ifp->int_broadaddr, 0, ifp);
}
#else
void toall(void (*f)())
/*
 * Apply the function "f" to all non-passive
 * interfaces.
 */
{
   struct interface *ifp;
   extern struct interface *ifnet;

   for (ifp = ifnet; ifp; ifp = ifp->int_next)
      (*f)(&ifp->int_broadaddr, 0, ifp);

   return;

} /* toall() */

#endif

/******************************************************************************/
#ifdef OldCode
/*ARGSUSED*/
rsendmsg(dst, flags, ifp)
        struct sockaddr *dst;
        int flags;
        struct interface *ifp;
{
        inet_output(*routedsock, flags, dst, sizeof (struct rip));
        TRACE_OUTPUT(ifp, dst, sizeof (struct rip));
}
#else
void rsendmsg(struct sockaddr *dst, int flags, struct interface *ifp)
{
   UNUSED(ifp);

   inet_output(*routedsock, flags, dst, sizeof(struct rip));

   TRACE_OUTPUT(ifp, (struct sockaddr_in *)dst, sizeof (struct rip));

   return;

} /* rsendmsg() */

#endif

/******************************************************************************/

#ifdef OldCode
supply(dst, flags, ifp)
        struct sockaddr *dst;
        int flags;
        struct interface *ifp;
{
        struct rt_entry *rt;
        struct netinfo *n = msg->rip_nets;
        struct rthash *rh;
        struct rthash *base = hosthash;
        int doinghost = 1, size;
        int npackets = 0;

        msg->rip_cmd = RIPCMD_RESPONSE;
        msg->rip_vers = RIPVERSION;
        memset(msg->rip_res1, 0, sizeof(msg->rip_res1));
again:
        for (rh = base; rh < &base[ROUTEHASHSIZ]; rh++)
        for (rt = rh->rt_forw; rt != (struct rt_entry *)rh; rt = rt->rt_forw) {

                if (ifp && rt->rt_ifp == ifp &&
                    (rt->rt_state & RTS_INTERFACE) == 0)
                        continue;
                if (rt->rt_state & RTS_EXTERNAL)
                        continue;

                if (doinghost == 0 && rt->rt_state & RTS_SUBNET) {
                        if (rt->rt_dst.sa_family != dst->sa_family)
                                continue;
                        if (inet_sendroute(rt, dst) == 0)
                                continue;
                }
                size = (char *)n - packet;
                if (size > MAXPACKETSIZE - sizeof (struct netinfo)) {
                        TRACE_OUTPUT(ifp, dst, size);
                        inet_output(*routedsock, flags, dst, size);

                        if (ifp && (ifp->int_flags &
                           (IFF_BROADCAST | IFF_POINTOPOINT | IFF_REMOTE)) == 0)
                                return;
                        n = msg->rip_nets;
                        npackets++;
                }
                n->rip_dst = rt->rt_dst;
                n->rip_metric = htonl(rt->rt_metric);
                n++;
        }
        if (doinghost) {
                doinghost = 0;
                base = nethash;
                goto again;
        }
        if (n != msg->rip_nets || npackets == 0) {
                size = (char *)n - packet;
                TRACE_OUTPUT(ifp, dst, size);
                inet_output(*routedsock, flags, dst, size);
        }
}
#else
/******************************************************************************/

void supply(struct sockaddr *dst, int flags, struct interface *ifp)
{
   struct rt_entry *rt;
   struct netinfo *n = msg->rip_nets;
   struct rthash *rh;
   struct rthash *base = hosthash;
   int doinghost = 1, size;
   int npackets = 0;

   msg->rip_cmd = RIPCMD_RESPONSE;
   msg->rip_vers = RIPVERSION;
   memset(msg->rip_res1, 0, sizeof(msg->rip_res1));

again:
   for (rh = base; rh < &base[ROUTEHASHSIZ]; rh++)
      for (rt = rh->rt_forw; rt != (struct rt_entry *)rh; rt = rt->rt_forw)
      {
         if (ifp && rt->rt_ifp == ifp &&
            (rt->rt_state & RTS_INTERFACE) == 0)
               continue;
         if (rt->rt_state & RTS_EXTERNAL)
            continue;

         if (doinghost == 0 && rt->rt_state & RTS_SUBNET)
         {
            if (rt->rt_dst.sa_family != dst->sa_family)
               continue;
            if (inet_sendroute(rt, dst) == 0)
               continue;
         }
         size = (char *)n - packet;
         if (size > MAXPACKETSIZE - sizeof (struct netinfo))
         {
            TRACE_OUTPUT(ifp, (struct sockaddr_in *)dst, size);
            inet_output(*routedsock, flags, dst, size);

            if (ifp && (ifp->int_flags &
                           (IFF_BROADCAST | IFF_POINTOPOINT | IFF_REMOTE)) == 0)
               return;
            n = msg->rip_nets;
            npackets++;
         }
         n->rip_dst = rt->rt_dst;
         n->rip_metric = htonl(rt->rt_metric);
         n++;
      }

   if (doinghost)
   {
      doinghost = 0;
      base = nethash;
      goto again;
   }

   if (n != msg->rip_nets || npackets == 0)
   {
      size = (char *)n - packet;
      TRACE_OUTPUT(ifp, (struct sockaddr_in *)dst, size);
      inet_output(*routedsock, flags, dst, size);
   }

   return;

} /* supply() */

#endif

/******************************************************************************/

/* EOF output.c */
