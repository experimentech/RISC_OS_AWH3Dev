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
/* if.c
 *
 * Author: Keith Ruttle (Acorn)
 *
 * Description
 * ===========
 * interface routines
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
 * 13-Oct-95  15:41  JPD  Version 1.00
 * First version with change record.
 *
 *
 **End of change record*
 */

#ifdef OldCode
#include "defs.h"

extern  struct interface *ifnet;
#else
#include "sys/types.h"
#include "sys/socket.h"
#include "net/route.h"
#include "netinet/in.h"
#include "protocols/routed.h"
#include "net/if.h"

#include "interface.h"
#include "table.h"
#include "data.h"
#endif

/******************************************************************************/

#ifdef OldCode
/*
 * Find the interface with address addr.
 */
struct interface *
if_ifwithaddr(addr)
        struct sockaddr *addr;
{
        struct interface *ifp;

#define same(a1, a2) \
        (memcmp((caddr_t)((a1)->sa_data), (caddr_t)((a2)->sa_data), 14) == 0)
        for (ifp = ifnet; ifp; ifp = ifp->int_next) {
                if (ifp->int_flags & IFF_REMOTE)
                        continue;
                if (ifp->int_addr.sa_family != addr->sa_family)
                        continue;
                if (same(&ifp->int_addr, addr))
                        break;
                if ((ifp->int_flags & IFF_BROADCAST) &&
                    same(&ifp->int_broadaddr, addr))
                        break;
        }
        return (ifp);
}
#else
struct interface *if_ifwithaddr(struct sockaddr *addr)
{
/*
 * Find the interface with address addr.
 */

   struct interface *ifp;

#define same(a1, a2) \
   (memcmp((caddr_t)((a1)->sa_data), (caddr_t)((a2)->sa_data), 14) == 0)

   for (ifp = ifnet; ifp; ifp = ifp->int_next)
   {
      if (ifp->int_flags & IFF_REMOTE)
         continue;

      if (ifp->int_addr.sa_family != addr->sa_family)
         continue;

      if (same(&ifp->int_addr, addr))
         break;

      if ((ifp->int_flags & IFF_BROADCAST) && same(&ifp->int_broadaddr, addr))
         break;
   }

   return ifp;

} /* if_withaddr() */

#endif
/******************************************************************************/

#ifdef OldCode
/*
 * Find the point-to-point interface with destination address addr.
 */
struct interface *
if_ifwithdstaddr(addr)
        struct sockaddr *addr;
{
        struct interface *ifp;

        for (ifp = ifnet; ifp; ifp = ifp->int_next) {
                if ((ifp->int_flags & IFF_POINTOPOINT) == 0)
                        continue;
                if (same(&ifp->int_dstaddr, addr))
                        break;
        }
        return (ifp);
}
#else
struct interface *if_ifwithdstaddr(struct sockaddr *addr)
{
/*
 * Find the point-to-point interface with destination address addr.
 */
   struct interface *ifp;

   for (ifp = ifnet; ifp; ifp = ifp->int_next)
   {
      if ((ifp->int_flags & IFF_POINTOPOINT) == 0)
         continue;
      if (same(&ifp->int_dstaddr, addr))
         break;
   }
   return ifp;

} /* if_ifwithdstaddr() */

#endif

/******************************************************************************/

#ifdef OldCode
/*
 * Find the interface on the network
 * of the specified address.
 */
struct interface *
if_ifwithnet(addr)
        struct sockaddr *addr;
{
        struct interface *ifp;

        for (ifp = ifnet; ifp; ifp = ifp->int_next) {
                if (ifp->int_flags & IFF_REMOTE)
                        continue;
                if (inet_netmatch(addr, &ifp->int_addr))
                        break;
        }
        return (ifp);
}
#else
struct interface *if_ifwithnet(struct sockaddr *addr)
{
/*
 * Find the interface on the network
 * of the specified address.
 */
   struct interface *ifp;

   for (ifp = ifnet; ifp; ifp = ifp->int_next)
   {
      if (ifp->int_flags & IFF_REMOTE)
         continue;
      if (inet_netmatch(addr, &ifp->int_addr))
         break;
   }

   return ifp;

} /* if_ifwithnet() */

#endif

/******************************************************************************/

#ifdef OldCode
/*
 * Find an interface from which the specified address
 * should have come from.
 */
struct interface *
if_iflookup(addr)
        struct sockaddr *addr;
{
        struct interface *ifp, *maybe;

        maybe = 0;
        for (ifp = ifnet; ifp; ifp = ifp->int_next) {
                if (same(&ifp->int_addr, addr))
                        break;
                if ((ifp->int_flags & IFF_BROADCAST) &&
                    same(&ifp->int_broadaddr, addr))
                        break;
                if ((ifp->int_flags & IFF_POINTOPOINT) &&
                    same(&ifp->int_dstaddr, addr))
                        break;
                if (maybe == 0 && inet_netmatch(addr, &ifp->int_addr))
                        maybe = ifp;
        }
        if (ifp == 0)
                ifp = maybe;
        return (ifp);
}
#else
struct interface *if_iflookup(struct sockaddr *addr)
{
/*
 * Find an interface from which the specified address
 * should have come from.
 */

   struct interface *ifp, *maybe;

   maybe = 0;
   for (ifp = ifnet; ifp; ifp = ifp->int_next)
   {
      if (same(&ifp->int_addr, addr))
         break;
      if ((ifp->int_flags & IFF_BROADCAST) && same(&ifp->int_broadaddr, addr))
         break;
      if ((ifp->int_flags & IFF_POINTOPOINT) && same(&ifp->int_dstaddr, addr))
         break;
      if (maybe == 0 && inet_netmatch(addr, &ifp->int_addr))
         maybe = ifp;
   }

   if (ifp == 0)
           ifp = maybe;

   return ifp;

} /* if_iflookup() */

#endif

/******************************************************************************/

/* EOF if.c */
