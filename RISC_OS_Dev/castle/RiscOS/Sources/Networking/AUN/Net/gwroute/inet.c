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
/* inet.c
 *
 * Author: Keith Ruttle (Acorn)
 *
 * Description
 * ===========
 * internet routines
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
 * 18-Oct-95  12:38  JPD  Version 1.00
 * First version with change record.
 *
 *
 **End of change record*
 */

#ifdef OldCode
#include "defs.h"
extern struct interface *ifnet;

#else
#include <ctype.h>

#include "sys/types.h"
#include "sys/socket.h"
#include "netinet/in.h"
#include "net/route.h"
#include "protocols/routed.h"

#include "table.h"
#include "data.h"
#include "interface.h"
#include "inetcode.h"
#endif

/******************************************************************************/

#ifdef OldCode
/*
 * Formulate an Internet address from network + host.
 */
struct in_addr
inet_rmakeaddr(net, host)
        u_long net, host;
{
        register struct interface *ifp;
        register u_long mask;
        u_long addr;

        if (IN_CLASSA(net))
                mask = IN_CLASSA_HOST;
        else if (IN_CLASSB(net))
                mask = IN_CLASSB_HOST;
        else
                mask = IN_CLASSC_HOST;
        for (ifp = ifnet; ifp; ifp = ifp->int_next)
                if ((ifp->int_netmask & net) == ifp->int_net) {
`                        mask = ~ifp->int_subnetmask;
                        break;
                }
        addr = net | (host & mask);
        addr = htonl(addr);
        return (*(struct in_addr *)&addr);
}
#else
struct in_addr inet_rmakeaddr(u_long net, u_long host)
{
/*
 * Formulate an Internet address from network + host.
 */
   register struct interface *ifp;
   register u_long mask;
   u_long addr;

   if (IN_CLASSA(net))
      mask = IN_CLASSA_HOST;
   else if (IN_CLASSB(net))
      mask = IN_CLASSB_HOST;
   else
      mask = IN_CLASSC_HOST;
   for (ifp = ifnet; ifp; ifp = ifp->int_next)
      if ((ifp->int_netmask & net) == ifp->int_net)
      {
         mask = ~ifp->int_subnetmask;
         break;
      }

   addr = net | (host & mask);
   addr = htonl(addr);

   return (*(struct in_addr *)&addr);

} /* in_addr() */

#endif

/******************************************************************************/

#ifdef OldCode
/*
 * Return the network number from an internet address.
 */
inet_rnetof(in)
        struct in_addr in;
{
        register u_long i = ntohl(in.s_addr);
        register u_long net;
        register struct interface *ifp;

        if (IN_CLASSA(i))
                net = i & IN_CLASSA_NET;
        else if (IN_CLASSB(i))
                net = i & IN_CLASSB_NET;
        else
                net = i & IN_CLASSC_NET;

        /*
         * Check whether network is a subnet;
         * if so, return subnet number.
         */
        for (ifp = ifnet; ifp; ifp = ifp->int_next)
                if ((ifp->int_netmask & net) == ifp->int_net)
                        return (i & ifp->int_subnetmask);
        return (net);
}
#else
u_long inet_rnetof(struct in_addr in)
{
/*
 * Return the network number from an internet address.
 */

   register u_long i = ntohl(in.s_addr);
   register u_long net;
   register struct interface *ifp;

   if (IN_CLASSA(i))
      net = i & IN_CLASSA_NET;
   else
      if (IN_CLASSB(i))
         net = i & IN_CLASSB_NET;
      else
         net = i & IN_CLASSC_NET;

   /*
    * Check whether network is a subnet;
    * if so, return subnet number.
    */
   for (ifp = ifnet; ifp; ifp = ifp->int_next)
      if ((ifp->int_netmask & net) == ifp->int_net)
         return (i & ifp->int_subnetmask);

   return net;

} /* inet_rnetof() */

#endif

/******************************************************************************/
#ifdef OldCode
/*
 * Return the host portion of an internet address.
 */
inet_rlnaof(in)
        struct in_addr in;
{
        register u_long i = ntohl(in.s_addr);
        register u_long net, host;
        register struct interface *ifp;

        if (IN_CLASSA(i)) {
                net = i & IN_CLASSA_NET;
                host = i & IN_CLASSA_HOST;
        } else if (IN_CLASSB(i)) {
                net = i & IN_CLASSB_NET;
                host = i & IN_CLASSB_HOST;
        } else {
                net = i & IN_CLASSC_NET;
                host = i & IN_CLASSC_HOST;
        }

        /*
         * Check whether network is a subnet;
         * if so, use the modified interpretation of `host'.
         */
        for (ifp = ifnet; ifp; ifp = ifp->int_next)
                if ((ifp->int_netmask & net) == ifp->int_net)
                        return (host &~ ifp->int_subnetmask);
        return (host);
}
#else
u_long inet_rlnaof(struct in_addr in)
{
/*
 * Return the host portion of an internet address.
 */

   register u_long i = ntohl(in.s_addr);
   register u_long net, host;
   register struct interface *ifp;

   if (IN_CLASSA(i))
   {
      net = i & IN_CLASSA_NET;
      host = i & IN_CLASSA_HOST;
   }
   else
      if (IN_CLASSB(i))
      {
         net = i & IN_CLASSB_NET;
         host = i & IN_CLASSB_HOST;
      }
      else
      {
         net = i & IN_CLASSC_NET;
         host = i & IN_CLASSC_HOST;
      }

   /*
    * Check whether network is a subnet;
    * if so, use the modified interpretation of `host'.
    */
   for (ifp = ifnet; ifp; ifp = ifp->int_next)
      if ((ifp->int_netmask & net) == ifp->int_net)
          return (host &~ ifp->int_subnetmask);

   return host;

} /* inet_rlnaof() */

#endif

/******************************************************************************/

#ifdef OldCode
/*
 * Return RTF_HOST if the address is
 * for an Internet host, RTF_SUBNET for a subnet,
 * 0 for a network.
 */
inet_rtflags(sin)
        struct sockaddr_in *sin;
{
        register u_long i = ntohl(sin->sin_addr.s_addr);
        register u_long net, host;
        register struct interface *ifp;

        if (IN_CLASSA(i)) {
                net = i & IN_CLASSA_NET;
                host = i & IN_CLASSA_HOST;
        } else if (IN_CLASSB(i)) {
                net = i & IN_CLASSB_NET;
                host = i & IN_CLASSB_HOST;
        } else {
                net = i & IN_CLASSC_NET;
                host = i & IN_CLASSC_HOST;
        }

        /*
         * Check whether this network is subnetted;
         * if so, check whether this is a subnet or a host.
         */
        for (ifp = ifnet; ifp; ifp = ifp->int_next)
                if (net == ifp->int_net) {
                        if (host &~ ifp->int_subnetmask)
                                return (RTF_HOST);
                        else if (ifp->int_subnetmask != ifp->int_netmask)
                                return (RTF_SUBNET);
                        else
                                return (0);             /* network */
                }
        if (host == 0)
                return (0);     /* network */
        else
                return (RTF_HOST);
}
#else
int inet_rtflags(struct sockaddr_in *sin)
{
/*
 * Return RTF_HOST if the address is for an Internet host,
 * RTF_SUBNET for a subnet, 0 for a network.
 */

   register u_long i = ntohl(sin->sin_addr.s_addr);
   register u_long net, host;
   register struct interface *ifp;

   if (IN_CLASSA(i))
   {
      net = i & IN_CLASSA_NET;
      host = i & IN_CLASSA_HOST;
   }
   else
      if (IN_CLASSB(i))
      {
         net = i & IN_CLASSB_NET;
         host = i & IN_CLASSB_HOST;
      }
      else
      {
         net = i & IN_CLASSC_NET;
         host = i & IN_CLASSC_HOST;
      }

   /*
    * Check whether this network is subnetted;
    * if so, check whether this is a subnet or a host.
    */
   for (ifp = ifnet; ifp; ifp = ifp->int_next)
      if (net == ifp->int_net)
      {
         if (host &~ ifp->int_subnetmask)
             return RTF_HOST;
         else
            if (ifp->int_subnetmask != ifp->int_netmask)
               return RTF_SUBNET;
            else
               return 0;             /* network */
      }

   if (host == 0)
      return 0;     /* network */
   else
      return RTF_HOST;

} /* inet_rtflags() */

#endif
/******************************************************************************/

#ifdef OldCode
/*
 * Return true if a route to subnet/host of route rt should be sent to dst.
 * Send it only if dst is on the same logical network if not "internal",
 * otherwise only if the route is the "internal" route for the logical net.
 */
inet_sendroute(rt, dst)
        struct rt_entry *rt;
        struct sockaddr_in *dst;
{
        register u_long r =
            ntohl(((struct sockaddr_in *)&rt->rt_dst)->sin_addr.s_addr);
        register u_long d = ntohl(dst->sin_addr.s_addr);

        if (IN_CLASSA(r)) {
                if ((r & IN_CLASSA_NET) == (d & IN_CLASSA_NET)) {
                        if ((r & IN_CLASSA_HOST) == 0)
                                return ((rt->rt_state & RTS_INTERNAL) == 0);
                        return (1);
                }
                if (r & IN_CLASSA_HOST)
                        return (0);
                return ((rt->rt_state & RTS_INTERNAL) != 0);
        } else if (IN_CLASSB(r)) {
                if ((r & IN_CLASSB_NET) == (d & IN_CLASSB_NET)) {
                        if ((r & IN_CLASSB_HOST) == 0)
                                return ((rt->rt_state & RTS_INTERNAL) == 0);
                        return (1);
                }
                if (r & IN_CLASSB_HOST)
                        return (0);
                return ((rt->rt_state & RTS_INTERNAL) != 0);
        } else {
                if ((r & IN_CLASSC_NET) == (d & IN_CLASSC_NET)) {
                        if ((r & IN_CLASSC_HOST) == 0)
                                return ((rt->rt_state & RTS_INTERNAL) == 0);
                        return (1);
                }
                if (r & IN_CLASSC_HOST)
                        return (0);
                return ((rt->rt_state & RTS_INTERNAL) != 0);
        }
}
#else
int inet_sendroute(struct rt_entry *rt, struct sockaddr_in *dst)
{
/*
 * Return true if a route to subnet/host of route rt should be sent to dst.
 * Send it only if dst is on the same logical network if not "internal",
 * otherwise only if the route is the "internal" route for the logical net.
 */

   register u_long r =
                    ntohl(((struct sockaddr_in *)&rt->rt_dst)->sin_addr.s_addr);
   register u_long d = ntohl(dst->sin_addr.s_addr);

   if (IN_CLASSA(r))
   {
      if ((r & IN_CLASSA_NET) == (d & IN_CLASSA_NET))
      {
         if ((r & IN_CLASSA_HOST) == 0)
            return ((rt->rt_state & RTS_INTERNAL) == 0);
         return 1;
      }

      if (r & IN_CLASSA_HOST)
         return 0;

      return ((rt->rt_state & RTS_INTERNAL) != 0);

   }
   else
      if (IN_CLASSB(r))
      {
         if ((r & IN_CLASSB_NET) == (d & IN_CLASSB_NET))
         {
            if ((r & IN_CLASSB_HOST) == 0)
               return ((rt->rt_state & RTS_INTERNAL) == 0);

            return 1;
         }
         if (r & IN_CLASSB_HOST)
            return 0;

         return ((rt->rt_state & RTS_INTERNAL) != 0);
      }
      else
      {
         if ((r & IN_CLASSC_NET) == (d & IN_CLASSC_NET))
         {
            if ((r & IN_CLASSC_HOST) == 0)
               return ((rt->rt_state & RTS_INTERNAL) == 0);

            return 1;
         }
         if (r & IN_CLASSC_HOST)
            return 0;

         return ((rt->rt_state & RTS_INTERNAL) != 0);
      }

} /* inet_sendroute() */

#endif

#ifdef OldCode
#include <sys/types.h>
#include <ctype.h>
#endif

/******************************************************************************/

#ifdef OldCode
/*
 * Internet address interpretation routine.
 * All the network library routines call this
 * routine to interpret entries in the data bases
 * which are expected to be an address.
 * The value returned is in network order.
 */
u_long
inet_addr(cp)
        register char *cp;
{
        u_long val, base, n;
        char c;
        u_long parts[4], *pp = parts;

again:
        /*
         * Collect number up to ``.''.
         * Values are specified as for C:
         * 0x=hex, 0=octal, other=decimal.
         */
        val = 0; base = 10;
        if (*cp == '0')
                base = 8, cp++;
        if (*cp == 'x' || *cp == 'X')
                base = 16, cp++;
        while (c = *cp) {
                if (isdigit(c)) {
                        val = (val * base) + (c - '0');
                        cp++;
                        continue;
                }
                if (base == 16 && isxdigit(c)) {
                        val = (val << 4) + (c + 10 - (islower(c) ? 'a' : 'A'));
                        cp++;
                        continue;
                }
                break;
        }
        if (*cp == '.') {
                /*
                 * Internet format:
                 *      a.b.c.d
                 *      a.b.c   (with c treated as 16-bits)
                 *      a.b     (with b treated as 24 bits)
                 */
                if (pp >= parts + 4)
                        return (-1);
                *pp++ = val, cp++;
                goto again;
        }
        /*
         * Check for trailing characters.
         */
        if (*cp && !isspace(*cp))
                return (-1);
        *pp++ = val;
        /*
         * Concoct the address according to
         * the number of parts specified.
         */
        n = pp - parts;
        switch (n) {

        case 1:                         /* a -- 32 bits */
                val = parts[0];
                break;

        case 2:                         /* a.b -- 8.24 bits */
                val = (parts[0] << 24) | (parts[1] & 0xffffff);
                break;

        case 3:                         /* a.b.c -- 8.8.16 bits */
                val = (parts[0] << 24) | ((parts[1] & 0xff) << 16) |
                        (parts[2] & 0xffff);
                break;

        case 4:                         /* a.b.c.d -- 8.8.8.8 bits */
                val = (parts[0] << 24) | ((parts[1] & 0xff) << 16) |
                      ((parts[2] & 0xff) << 8) | (parts[3] & 0xff);
                break;

        default:
                return (-1);
        }
        val = htonl(val);
        return (val);
}
#else
u_long inet_addr(register char *cp)
{
/*
 * Internet address interpretation routine. All the network library routines
 * call this routine to interpret entries in the data bases which are
 * expected to be an address. The value returned is in network order.
 */

   u_long val, base, n;
   char c;
   u_long parts[4], *pp = parts;

again:
   /*
    * Collect number up to ``.''.
    * Values are specified as for C:
    * 0x=hex, 0=octal, other=decimal.
    */
   val = 0; base = 10;
   if (*cp == '0')
      base = 8, cp++;
   if (*cp == 'x' || *cp == 'X')
      base = 16, cp++;

   while (c = *cp)
   {
      if (isdigit(c))
      {
         val = (val * base) + (c - '0');
         cp++;
         continue;
      }

      if (base == 16 && isxdigit(c))
      {
         val = (val << 4) + (c + 10 - (islower(c) ? 'a' : 'A'));
         cp++;
         continue;
      }
      break;
   }

   if (*cp == '.')
   {
      /* Internet format:
       *      a.b.c.d
       *      a.b.c   (with c treated as 16-bits)
       *      a.b     (with b treated as 24 bits)
       */
      if (pp >= parts + 4)
         return -1;

      *pp++ = val, cp++;
      goto again;
   }

   /*
    * Check for trailing characters.
    */
   if (*cp && !isspace(*cp))
      return -1;

   *pp++ = val;

   /*
    * Concoct the address according to
    * the number of parts specified.
    */
   n = pp - parts;

   switch (n)
   {
      case 1:                         /* a -- 32 bits */
         val = parts[0];
         break;

      case 2:                         /* a.b -- 8.24 bits */
         val = (parts[0] << 24) | (parts[1] & 0xffffff);
         break;

      case 3:                         /* a.b.c -- 8.8.16 bits */
         val = (parts[0] << 24) | ((parts[1] & 0xff) << 16) |
                                                            (parts[2] & 0xffff);
         break;

      case 4:                         /* a.b.c.d -- 8.8.8.8 bits */
         val = (parts[0] << 24) | ((parts[1] & 0xff) << 16) |
                                   ((parts[2] & 0xff) << 8) | (parts[3] & 0xff);
         break;

      default:
         return -1;
   }

   val = htonl(val);

   return val;

}

#endif

/******************************************************************************/

/* EOF inet.c */
