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
/* mns.c
 *
 * Author: Keith Ruttle (Acorn)
 *
 * Description
 * ===========
 * Module code
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
 * 05-Jan-95  16:55  JPD  Version 1.00
 * First version with change record. Modified: #includes to be ANSI-compliant,
 * other constructs to remove compiler warnings, code to cope with DCI-4 and
 * new mbuf structure. Added changes from KRuttle's 6.03 version (different
 * to RISC OS SrcFiler 6.03 version!). Begin changes to allow
 * order of module initialisation to be less restrictive. Changed to use
 * new definitions from dcistructs.h.
 *
 * 20-Jan-95  10:19  JPD  Version 1.01
 * Allow compilation with -fah option. Issue Service_ReAllocatePorts on
 * reinitialisation (now done on callback).
 *
 * 01-Feb-95  09:54  JPD  Version 1.02
 * Added NetworkParameters SWI. Reinitialise properly when Econet is killed.
 * Changed is_aun_configured() to check BootNet$File, if set, starts with
 * "Net".
 *
 * 06-Feb-95  19:21  JPD  Version 1.03
 * Added special pleading to force reinitialisation when Internet starting
 * service call is received after Internet was thought to be present.
 * Initialise connected_econet to -1 not 0. This seems sensible anyway, but
 * has the added bonus that when NetFS is started by the BootNet module
 * before Callbacks have gone off, allowing the Net module is properly
 * initialised, the NetFS initialisation does not fail.
 *
 * 14-Feb-95  10:58  JPD  Version 1.04
 * Tighten lock checking in setting of callbacks. Add removal of any
 * callbacks set on finalisation. Tightened checking of Internet present to
 * include check that it has a device driver.
 *
 * 28-Feb-95  12:52  JPD  Version 1.05
 * Added back in, KRuttle's 6.03 change of wild card semantics which had
 * fallen out as it was not in the RISC OS SrcFiler 6.03 version. Should
 * fix fault reports MED-02789 and MED-04403. Removed OldCode. Pass out-of-
 * -range SWIs on to Econet module, if present, to maximise chance of a
 * change to Econet module not requiring change to Net module. Corrected
 * error in SWI despatch allowing a slightly out-of-range SWI to cause a
 * branch through zero exception. Corrected error message produced for other
 * out-of-range SWIs. Added returning of different values for peek machine
 * type depending on what machine we are running on. Simplify service call
 * reinitialisation stategy.
 *
 * 14-Mar-95  15:25  JPD  Version 1.06
 * Removed some code to mnscommon.c.
 *
 * 21-Mar-95  18:00  JPD  Version 1.07
 * Added some debug. Updated comments. Moved mns_sc_handler() and
 * reset_is_soft() to mnscommon.c.
 *
 * 03-Oct-95  17:50  JPD  Version 1.08
 * Corrected some extern declarations: should not change code.
 *
 * 06-Oct-95  10:34  JPD  Version 1.03
 * Moved machine_type and modules_present to mnscommon.c.
 *
 * 29-May-96  11:26  KJB  Version 1.09
 * Revised to 4.4BSD. Now issues Service_InternetStatus 1 when map info
 * received.
 *
 **End of change record*
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "kernel.h"
#include "swis.h"
#include "Global/OsBytes.h"
#include "Global/CMOS.h"
#include "Global/RISCOS.h"

#include "sys/types.h"
#include "sys/uio.h"
#include "sys/socket.h"
#include "sys/time.h"
#include "sys/ioctl.h"
#include "sys/dcistructs.h"
#include "netinet/in.h"
#include "net/if.h"
#include "protocols/routed.h"

#include "netasm.h"
#include "module.h"
#include "mnscommon.h"
#include "configure.h"
#include "debug.h"
#include "inetfn.h"
#include "io.h"
#include "showrt.h"
#include "socklib.h"
#include "swicode.h"
#include "text.h"
#include "routecode.h"
#include "mns.h"
#include "NetHdr.h" /* From CMHG */

extern char *inet_ntoa();
extern u_long inet_makeaddr(u_long, u_long);

struct mns mns = { 0 };
int connected_econet = -1;
int econet_transport_type = 0;
int econet_not_present = 0;

static void mns_showmap(int argc, char **argv);
static void mns_shroutes(int argc, char **argv);
static void mns_showif(int argc, char **argv);
static int atp_add_newitem(struct atp_block *a);
static int init_sockets(void);
static int mns_warnings(void);
static int dst_is_local_econet(u_long ip);

struct client mns_cli_call[5] =
{
   mns_showmap,
   mns_shroutes,
   mns_showif,
   mns_ping,
   0,
};


#define MAXSWI 33
struct swient
{
   _kernel_oserror *(*swi_call)(_kernel_swi_regs *);      /* SWI handler */
};

static struct swient mns_ent[MAXSWI+1] =
{
   CreateReceive,  ExamineReceive, ReadReceive,
   AbandonReceive, WaitForReception, EnumerateReceive,
   StartTransmit, PollTransmit, AbandonTransmit,
   DoTransmit, ReadLocalStationAndNet,
   ConvertStatusToString, ConvertStatusToError,
   ReadProtection, SetProtection, ReadStationNumber,
   PrintBanner, ReadTransportType, ReleasePort, AllocatePort,
   DeAllocatePort, ClaimPort, StartImmediate,
   DoImmediate, AbandonAndReadReceive, Version, NetworkState,
   PacketSize, ReadTransportName, InetRxDirect, EnumerateMap,
   EnumerateTransmit, HardwareAddresses, NetworkParameters,
};

static _kernel_oserror *is_aun_configured(void);
static int do_myaddress(char *ifname, u_long a, u_char net, u_char station);
static void seek_address(char *ifname);
static void read_ifs(int print, int all);
static void atp_request_map_from_server(u_long server);
static void mns_info(int all);
static void process_input(int sock);
static void routed_process_input(int sock);
static void atp_process_input(int sock);

/******************************************************************************/

_kernel_oserror *mns_init(const char *cmd_tail, int pbase, void *pw)
{
/*
 * cmhg module initialisation entry
 *
 * Parameters:
 *    cmd_tail : pointer to command line tail
 *    pbase    : 0 unless code invoked from a podule
 *    pw       : "R12" value established by module initialisation
 *
 * Returns:
 *     0 : => successfully initialised
 *    !0 : => a problem, pointer to standard RISC OS error block
 */

   _kernel_oserror *e;

   UNUSED(pbase);
   UNUSED(cmd_tail);

   /* take note of our workspace pointer for future use */
   module_wsp = pw;

   DEBUGP1("\n\r#module initialisation\n\r");

   xDEBUGP2("#pbase = %08X\n\r", pbase);

   xDEBUGP5("#-- 1: %08X, %08X, %08X, %08X\n\r",
                   *(unsigned int *)0x01c00000, *(unsigned int *)0x01c00004,
                   ((*((unsigned int **)pw)))[1],((*((unsigned int **)pw)))[2]);

   /* This must really be done now, cannot wait for do_mns_init() */
   memset(&mns, 0, sizeof(mns));
   mns.mns_rxdsock = -1;
   mns.mns_txdsock = -1;
   mns.mns_atpsock = -1;
   mns.mns_routedsock = -1;

   /* Open message file for us */
   e = init_msgs(Module_MessagesFile, msg_fd_mns);
   if (e)
      return e;

   /* Check to see if we ought not to be here */
   e = is_aun_configured();
   if (e)
      goto out3;

   /* Install on event vector */
   e = _swix(OS_Claim, _INR(0,2), EventV, mns_event_entry, module_wsp);
   if (e)
      goto out3;

   /* Enable Internet events */
   e = _swix(OS_Byte, _INR(0,1), OsByte_EnableEvent, Event_Internet);
   if (e)
      goto out2;

   /* Install ticker code */
   e = calleverytick(tick_entry);
   if (e)
      goto out1;

   /* check machine type we are running on, for later machine type peek */
   check_machine_type();

   /* Find real Econet module so SWIs can be handed on to it */
   e = init_econet();
   if (e)
      econet_not_present = 1;

   if (modules_present = check_present(), modules_present)
   {
      /* perform main initialisation and, if successful, wait for any RevARP
      * response.
      */
      DEBUGP1("#do_mns_init from module initialisation\n\r");
      if (do_mns_init(1))
      {
         int starttime = time(0);

         while (time(0) < starttime+STARTUP_TIMEOUT)
         {
            usermode_donothing();
            if (mns.mns_retrycount == RETRY_COUNT)
               break;
            if (mns.mns_flags & MNS_ALLSET)
               break;
         }
      }
   }
   else
   {
      DEBUGP1("#modules not present\r\n");
      do_mns_init(0);
   }

   /* if a DCI driver has been found, print any warning message */
   if (mns.mns_device[0] != 0)
   {
      DEBUGP2("#init: mns_device = %s, doing warnings\n\r", mns.mns_device);
      (void) mns_warnings();
   }

  /* set flag and set a Callback, so that the service call to say that
   * "Econet" has been reinitialised will be issued on a Callback after this
   * initialisation has completed.
   */
   restarting = 1;
   setcallback();

   return NULL; /* return OK */

out1:
   _swix(OS_Byte, _INR(0,1), OsByte_DisableEvent, Event_Internet);
out2:
   _swix(OS_Release, _INR(0,2), EventV, mns_event_entry, module_wsp);
out3:
   release_msgs(msg_fd_mns);

#ifdef DEBUG
   if (e != 0)
      DEBUGP2("#module init failing with error: %s\n\r", e->errmess);
#endif

   return e;

} /* mns_init() */

/******************************************************************************/

int do_mns_init(int booting)
{
/*
 * Perform initialisation
 *
 * Parameters:
 *    booting : !0 => initialisation for first time
 *               0 => reinitialisation as result of service call
 *
 * Returns:
 *    !0 : => successfully initialised
 *     0 : => either a problem, or reinitialised
 */

   _kernel_swi_regs r;
   int no_econet_clock = 0;
   int rxd, txd, atp, routed;

   DEBUGP2("#do_mns_init(%d)\n\r", booting);

   rxd = booting ? -1 : mns.mns_rxdsock;
   txd = booting ? -1 : mns.mns_txdsock;
   atp = booting ? -1 : mns.mns_atpsock;
   routed = booting ? -1 : mns.mns_routedsock;
   memset((char *)&mns, 0, sizeof(mns));
   mns.mns_rxdsock    = rxd;
   mns.mns_txdsock    = txd;
   mns.mns_atpsock    = atp;
   mns.mns_routedsock = routed;
   mns.mns_txhandle   = MNS_HANDLE_BASE;
   mns.mns_rxhandle   = MNS_HANDLE_BASE;
   mns.mns_nextport   = 1;

   /* Find first DCI driver present and get Econet status */
   mns.mns_stationnumber = read_device_info(mns.mns_device, mns.mns_module,
                                            &connected_econet, &no_econet_clock,
                                            &mns.mns_segsize);

   if (!booting)
      return 0;

   /* If station number unavailable or no DCI driver present */
   if (mns.mns_stationnumber <= 1 || !mns.mns_device[0])
   {
      DEBUGP1("#do_mns_init() no stn num avail or no DCI driver present\n\r");
      return 0;
   }

  /* If we are connected to an Econet, note this in network state for this
   * net number.
   */
   if (connected_econet != -1)
      mns.mns_states[connected_econet] |= ECONET_IS_CONNECTED;

   /* Read the actual transport type for the "Econet" */
   r.r[0] = 0;
   r.r[1] = 2;
   econet_transport_type =
                         call_econet(Econet_ReadTransportType, &r) ? 2 : r.r[2];

  /* If the first DCI driver was EconetA, note its net number as the net
   * number for AUN Econet use.
   */
   if (strcmp(mns.mns_device, "ec0") == 0)
      mns.mns_econetnumber = connected_econet;

   /* Try to invent an Internet address for this station */
   return (do_myaddress(mns.mns_device, (u_long)0, 0, mns.mns_stationnumber));

} /* do_mns_init() */

/******************************************************************************/

_kernel_oserror *mns_swi_handler(int swinum, _kernel_swi_regs *r, void *pw)
{
/* cmhg module SWI handler
 *
 * Parameters:
 *    swinum : SWI number within our SWI chunk
 *    r      : pointer to registers structure
 *    pw     : "R12" value
 *
 * Returns:
 *    0 => all OK
 *   !0 => some error occurred (pointer to RISC OS error block)
 *
 */

   struct swient *callp;
   _kernel_oserror *e = 0;
   int oldstate;

   UNUSED(pw);

   DEBUGP4("#swi_handler() swinum %X, ecoipaddr %X, flags & SEEKADDR %d\n\r",
                   swinum, mns.mns_econetipadr, (mns.mns_flags & MNS_SEEKADDR));

   if (mns.mns_econetipadr && (mns.mns_flags & MNS_SEEKADDR))
      return call_econet(swinum, r);

   if (swinum < 0 || swinum > 63)
      return error_BAD_SWI;

   if (swinum > MAXSWI)
   {
      if (connected_econet != -1)
         return call_econet(swinum, r);
      else
         return error_BAD_SWI;
   }

   callp = &mns_ent[swinum];
   oldstate = ensure_irqs_off();
   e = (_kernel_oserror *)(*(callp->swi_call))(r);
   restore_irqs(oldstate);

   return e;

} /* mns_swi_handler() */

/******************************************************************************/

static void mns_showif(int argc, char **argv)
{
/*
 * *NetStat code
 *
 * Parameters:
 *    argc : }
 *    argv : } command line parms
 *
 * Returns:
 *    None
 */

   int all = 0;

   UNUSED(argv);

   if (mns_warnings())
#ifdef DEBUG
      /* Go on to do the rest, as its a debug version */
      ;
#else
      return;
#endif

   /* If any argument present at all, do full info */

   if (argc > 0)
      all = 1;


   /* Output information about the network interfaces */

   read_ifs(1, all);


   /* Output information about connected networks, and optionally, statistics */

   if (mns.mns_flags != 0)
      mns_info(all);

   return;

} /* mns_showif() */

/******************************************************************************/

static void mns_showmap(int argc, char **argv)
{
/*
 * *NetMap code: show mapping from pseudo-Econet numbers to Internet addresses
 *
 * Parameters:
 *    argc : }
 *    argv : } command line parms (optional net number)
 *
 * Returns:
 *    None
 */

   struct address_q *q;
   u_char net = 0;
   char abuf[32];
   int n;

   if (argc)
      net = (u_char)atoi(argv[0]);

   for (q = mns.mns_mapq; q; q = q->q_next)
   {
      if (net && net != q->q_net)
         continue;
      sprintf(abuf, "%s", inet_ntoa(q->q_ip));
      if (n = strlen(abuf))
         abuf[n-1] = 'x';
      printf("%-8d%-16s%-16s%s\n", q->q_net, q->q_netname, abuf, q->q_sitename);
      if (net)
         break;
   }

   return;

} /* mns_showmap() */

/******************************************************************************/

static void mns_shroutes(int argc, char **argv)
{
/*
 * *Networks code
 *
 * Parameters:
 *    argc : }
 *    argv : } command line parms
 *
 * Returns:
 *    None
 */

   UNUSED(argc);
   UNUSED(argv);

   mns_showroutes();

   return;

}  /* mns_shroutes() */

/******************************************************************************/

_kernel_oserror *tick_handler(_kernel_swi_regs *r, void *pw)
{
/*
 * cmhg ticker handler
 *
 * Parameters:
 *    r  : pointer to registers block
 *    pw : "R12" value established by module initialisation
 */

   int flags = mns.mns_flags;

   UNUSED(r);
   UNUSED(pw);

   /* if retry time reached and retries to do */
   if (mns.mns_retrydelay && --(mns.mns_retrydelay) == 0 &&
                                           ++(mns.mns_retrycount) < RETRY_COUNT)
   {
      DEBUGP1("#tick_handler()\n\r");
      /* If we are seeking address via MNS Rarp */
      if (flags & MNS_SEEKADDR)
      {
         DEBUGP1("#tick_handler() seeking address via MNS Rarp \n\r");

         /* If event handler has received MNS Rarp reply */
         if (flags & MNS_SETADDR)
         {
            DEBUGP1(
        "#tick_handler() event handler must have received MNS Rarp reply\n\r");
            mns.mns_flags &= ~MNS_SETADDR; /* unset note of reply */

            /* set Internet address using the address sent to us by !Gateway */
            (void) do_myaddress(mns.mns_device, mns.mns_ifaddrs[1],
                                   mns.mns_econetnumber, mns.mns_stationnumber);
            mns.mns_states[RESERVED_NET] &= ~MNS_IS_CONNECTED;
         }

         /* If there is a gateway */
         if (mns.mns_serverip)
         {
            DEBUGP1("#tick_handler() there is a gateway\n\r");
            mns.mns_flags &= ~MNS_SEEKADDR;
            mns.mns_flags |= MNS_WANTMAP;    /* note that we want the map */
            mns.mns_retrydelay = 10;
            mns.mns_retrycount = 0;
            return NULL;
         }

         if ((flags & MNS_SETADDR) == 0)
         {
            DEBUGP1("#tick_handler() seek ...\n\r");
            seek_address(mns.mns_device);
            DEBUGP1("#tick_handler()... back\n\r");
         }
      }
      else
      {
         /* if looking for map */
         if (flags & MNS_WANTMAP)
         {
            DEBUGP1("#tick_handler() looking for a map\n\r");
            (void) atp_request_map_from_server(mns.mns_serverip);
            mns.mns_serverip = 0;
         }
         else
            if (flags & MNS_WANTROUTE)
                routed_init();
      }
   }

   check_rxcbs();
   check_txcbs();

   return NULL;

} /* tick_handler() */

/******************************************************************************/

_kernel_oserror *mns_final(int fatal, int podule, void *pw)
{
/* Finalisation code
 *
 * Parameters:
 *    None
 *
 * Returns:
 *    None
 */

   DEBUGP1("#module finalisation\n\r");

   UNUSED(fatal);
   UNUSED(podule);
   UNUSED(pw);

  /* One could argue about the order of releasing the vectors and closing
   * the sockets, but this is the way it was.
   */

   /* Disable Internet event and remove from event vector */
   _swix(OS_Byte, _INR(0,1), OsByte_DisableEvent, Event_Internet);
   _swix(OS_Release, _INR(0,2), EventV, mns_event_entry, module_wsp);   

   /* Close sockets */
   free_sockets();

   /* remove the installed ticker handler */
   removetickerevent(tick_entry);

   /* remove any added transient callback */
   removecallback();

   /* Close MessageTrans message files */
   release_msgs(msg_fd_mns);

   return NULL;

} /* mns_final() */

/******************************************************************************/

int mns_event_handler(_kernel_swi_regs *r, void *pw)
{
/*
 * cmhg event handler
 *
 * Parameters:
 *    r  : pointer to registers block
 *    pw : "R12" value established by module initialisation
 *
 * Returns:
 *    0 => interrupt "claimed"
 *   !0 => interrupt not "claimed"
 */

   UNUSED(pw);

   /* cmhg will only pass through this event anyway */
   if (r->r[0] == Event_Internet)
   {
      /*
       * No need for IRQs to be off.
       */
      _kernel_irqs_on();

      /* if notification of asynchronous I/O */
      if (r->r[1] == SocketIO &&
         (r->r[2] == mns.mns_atpsock || r->r[2] == mns.mns_routedsock))
      {
         DEBUGP1("#Event SocketIO ...\n\r");
         process_input(r->r[2]);
         return _kernel_irqs_off(), 0;
      }
      else
         /* if MNS Rarp reply and we were looking for it */
         if (r->r[1] == RarpReply && r->r[3] &&
                                            (mns.mns_flags & MNS_SEEKADDR) != 0)
         {
            DEBUGP3("#Event RarpReply: R2: %08X, R3: %08X\n\r",
                                                              r->r[2], r->r[3]);
            /* take note of the address of server */
            if (r->r[2])
               mns.mns_serverip = (u_long)r->r[2];

            if (mns.mns_ifaddrs[1] == 0)
            {
               /* make a note of partial address !Gateway server sent for us */
               mns.mns_ifaddrs[1] = (u_long)r->r[3];

               /* Note that this has been received (acted on in tick_handler) */
               mns.mns_flags |= MNS_SETADDR;
            }
            else
               if (mns.mns_serverip == 0)
                  return _kernel_irqs_off(), 1;

            /* setup to retry */
            mns.mns_retrydelay = 10;
            mns.mns_retrycount = 0;
            return _kernel_irqs_off(), 0;
         }
   }
   return _kernel_irqs_off(), 1;

} /* mns_event_handler() */

/******************************************************************************/

static void read_ifs(int print, int all)
{
/*
 * Obtain information about the network interfaces
 *
 * Parameters:
 *    print : !0 => display details of interfaces
 *    all   : !0 => print full information
 *
 * Returns:
 *    None
 */

   int s, n, eco, no_econet_clock;
   static char buf[256];
   struct ifconf ifc;
   struct ifreq ifreq, *ifr;
   struct sockaddr_in *sin;
   u_long addr;

   DEBUGP3("#read_ifs(%d, %d)\n\r", print, all);

   /* open a socket to use to obtain details */
   if ((s = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
      return;

   ifc.ifc_len = sizeof(buf);
   ifc.ifc_buf = buf;

   /* get the interface info list from the Internet module */
   if (socketioctl(s, OSIOCGIFCONF, (char *)&ifc) < 0)
   {
      socketclose(s);
      return;
   }

   /* if not using EconetA and we are connected to Econet, get Econet info */
   if (print && strcmp(mns.mns_device, "ec0") != 0 && connected_econet != -1)
   {
      (void) read_eco_info(&connected_econet, &no_econet_clock);
      printf("%-18s", mns_str(Str_NtvEco));
      printf("%d.%d", connected_econet, mns.mns_stationnumber);
      if (no_econet_clock)
         printf(" (%s)", mns_str(Str_Noclck));
      printf("\n\n");
   }

   mns.mns_ifcnt = 0;
   mns.mns_econetipadr = 0;
   ifr = ifc.ifc_req;

   /* step forwards through interface info list */
   for (n = ifc.ifc_len / sizeof (struct ifreq); n > 0; n--, ifr++)
   {
      if (((struct osockaddr *)&ifr->ifr_addr)->sa_family != AF_INET)
         continue;

      ifreq = *ifr;
      /* Ignore the loopback interface */
      if (socketioctl(s, SIOCGIFFLAGS, (char *)&ifreq) < 0 ||
                                                 ifreq.ifr_flags & IFF_LOOPBACK)
         continue;

      /* Print "Interface" */
      if (print)
         printf("%-18s", mns_str(Str_IfType));

      eco = strcmp(ifreq.ifr_name, "ec0") == 0 ? 1 : 0;

     /* Print the module title that we first found when we last initialised.
      * This may not be the same as the module we are actually using!
      */

      if (print)
         printf("%s ", mns.mns_module);

      if ((ifreq.ifr_flags & (IFF_BROADCAST|IFF_UP)) != (IFF_BROADCAST|IFF_UP))
      {
         if (print)
            printf("(%s)\n", mns_str(Str_Down));
         break;
      }

      if (print)
         printf("\n");

      /* get interface Internet address */
      if (socketioctl(s, SIOCGIFADDR, (char *)&ifreq) < 0)
         break;

      sin = (struct sockaddr_in *)&ifreq.ifr_addr;
      addr = ntohl(sin->sin_addr.s_addr);
      mns.mns_netnumber = (addr & 0xff00) >> 8;

      if (eco)
         mns.mns_econetipadr = (addr & ~0xffff);

      if (print)
      {
         /* Print "AUN Station" */
         printf("%-18s%d.%d\n", mns_str(Str_StaNum), mns.mns_netnumber,
                                                         mns.mns_stationnumber);
         /* Print "Full address" */
         if (all)
            printf("%-18s%s\n", mns_str(Str_FullAd),
                                        inet_ntoa(*((u_long *)&sin->sin_addr)));
      }

      /* get Internet broadcast address for interface */
      if (socketioctl(s, SIOCGIFBRDADDR, (char *)&ifreq) < 0)
         break;

      sin = (struct sockaddr_in *)&ifreq.ifr_addr;
      mns.mns_ifaddrs[0] = sin->sin_addr.s_addr;
      mns.mns_ifcnt = 1;
      break;
   }

   /* close the socket: we only opened it to get the info */
   socketclose(s);

   return;

} /* read_ifs() */

/******************************************************************************/

static void process_input(int sock)
{
/* Process input on a socket: event has been received to indicate I/O is
 * "available" on this socket
 *
 * Parameters:
 *    sock : the socket number
 *
 * Returns:
 *    None
 *
 */

   fd_set ibits;
   int nfd, r;
   struct timeval tv;

   DEBUGP2("#process_input(%d)\n\r", sock);

   FD_ZERO(&ibits);
   nfd = sock + 1;
   FD_SET(sock, &ibits);
   tv.tv_sec = 0;
   tv.tv_usec = 0;

   /* If any data available on this socket */
   if ((r = select(nfd, &ibits, 0, 0, &tv)) > 0 && FD_ISSET(sock, &ibits))
   {
      if (sock == mns.mns_atpsock)
         atp_process_input(sock);
      else
         if (sock == mns.mns_routedsock)
            routed_process_input(sock);
   }

   return;

} /* process_input() */

/******************************************************************************/

static void atp_process_input(int sock)
{
   struct sockaddr from;
   int fromlen, r;
   char *c;
   static char inbuf[1024];
   struct atp_msg *atp;
   struct atp_block ablock;

   DEBUGP2("#atp_process_input(%d)\n\r", sock);

   for (;;)
   {
      fromlen = sizeof(from);
      r = recvfrom(sock, inbuf, sizeof(inbuf), 0, &from, &fromlen);
      if (r < 0 || fromlen != sizeof(struct sockaddr_in))
         break;
      atp = (struct atp_msg *)inbuf;
      c = (char *)&atp->atp_address;
      if (atp->atp_opcode == MNS_TRANSFORM_REPLY)
      {
         for (r = 0; r < atp->atp_count; r++)
         {
            ablock.atpb_net     = *c++;
            ablock.atpb_station = *c++;
            memcpy((char *)&(ablock.atpb_ipadr), c, 4);
            c += 4;
            memcpy(ablock.atpb_sitename, c, ITEM_NAMELEN);
            c += 16;
            memcpy(ablock.atpb_netname, c, ITEM_NAMELEN);
            c += 16;
            (void) atp_add_newitem(&ablock);
         }
         if (mns.mns_flags & MNS_WANTMAP)
         {
            mns.mns_flags &= ~MNS_WANTMAP;
            mns.mns_flags |= MNS_WANTROUTE;
            mns.mns_retrydelay = 10;
            mns.mns_retrycount = 0;
            netmapchanged_on_callback();
         }
      }
   }

   return;

} /* atp_process_input() */

/******************************************************************************/

static void routed_process_input(int sock)
{
   struct sockaddr from;
   int fromlen, r;
   static char inbuf[1024];

   DEBUGP2("#routed_process_input(%d)\n\r", sock);

   for (;;)
   {
      fromlen = sizeof(from);
      r = recvfrom(sock, inbuf, sizeof(inbuf), 0, &from, &fromlen);
      if (r < 0 || fromlen != sizeof(struct sockaddr_in))
         break;
      if (rip_input(&from, (struct rip *)inbuf, r) &&
                                           (mns.mns_flags & MNS_WANTROUTE) != 0)
      {
         mns.mns_flags &= ~MNS_WANTROUTE;
         mns.mns_flags |= MNS_ALLSET;
      }
   }
   return;

} /* routed_process_input() */

/******************************************************************************/

static u_long atp_setbcast(u_long addr)
{
   struct address_q *q;

   for (q = mns.mns_mapq; q; q = q->q_next)
   {
      if (q->q_bcast == addr)
         return (u_long)0;
   }

   return ((addr == mns.mns_ifaddrs[0]) ? (u_long)0 : addr);

} /* atp_setbcast() */

/******************************************************************************/

static int atp_add_newitem(struct atp_block *a)
{
   struct address_q *q;
   struct address_q **p;

   if (mns.mns_flags & MNS_SEEKADDR)
      return 0;

   p = &(mns.mns_mapq);
   while (*p)
   {
      if ((*p)->q_net == a->atpb_net)
      {
         if ((*p)->q_ip == a->atpb_ipadr)
            return 0;
         q = *p;
         break;
      }
      p = &((*p)->q_next);
   }

   if ((*p) == 0)
   {
      q = (struct address_q *)malloc (sizeof(struct address_q));
      if (q == (struct address_q *)0)
         return -1;
      q->q_bcast = 0;
      q->q_next  = (struct address_q *)0;
      *p = q;
   }

   q->q_net     = a->atpb_net;
   q->q_ip      = a->atpb_ipadr;
   q->q_bcast   = atp_setbcast(q->q_ip | 0xffff0000);
   memcpy(q->q_sitename, a->atpb_sitename, ITEM_NAMELEN);
   memcpy(q->q_netname, a->atpb_netname, ITEM_NAMELEN);

   if ((mns.mns_states[q->q_net] & ECONET_IS_CONNECTED) == 0)
       mns.mns_states[q->q_net] |= MNS_IS_CONNECTED;

   return 0;

} /* atp_add_newitem() */

/******************************************************************************/

static struct atp_msg atp;

static void atp_request_map_from_server(u_long server)
{
   struct sockaddr_in sin;

   sin.sin_family      = AF_INET;
   sin.sin_len         = sizeof sin;
   sin.sin_port        = htons((u_short)MNSATPPORT);
   sin.sin_addr.s_addr = server;
   atp.atp_opcode      = MNS_TRANSFORM_REQUEST;
   atp.atp_count       = 0;
   mns.mns_retrydelay  = RETRY_DELAY;
   (void) sendto(mns.mns_atpsock, (char *)&(atp.atp_opcode), 2, 0,
                                          (struct sockaddr *)&sin, sizeof(sin));

   DEBUGP2("#atp_request_map_from_server() server = %x\n\r", server);

   return;

} /* atp_request_map_from_server() */

/******************************************************************************/

static int do_myaddress(char *ifname, u_long a, u_char net, u_char station)
{
/* Try to set/invent an Internet address for this station
 *
 * Parameters:
 *    ifname  : device name of DCI driver, e.g. "en0"
 *    a       : interface address
 *    net     : net number
 *    station : the local station number
 *
 * Returns:
 *    !0 : => success
 *     0 : => a problem
 */

   struct sockaddr_in sinn;
   struct ifreq ifr;
   int s;
   u_long addr = ntohl(a);

   DEBUGP3("#do_myaddress(%08X, %s)\n\r", addr, ifname);

  /* check parms: interface name not null and station address not set in
   * interface address
   */
   if (*ifname == 0 || (addr & 0xff) != 0)
      return 0;

   /* open a socket to extract information */

   if ((s = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
      goto bad;

   strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));

   /* get the interface flags */
   DEBUGP1("#do_myaddress() about to get i/f flags\n\r");
   if (socketioctl(s, SIOCGIFFLAGS, (caddr_t)&ifr) < 0)
   {
      DEBUGP1("#SIOCGIFFLAGS ioctl failed\n\r");
      goto bad;
   }
   DEBUGP1("#do_myaddress() got i/f flags\n\r");

  /* If interface Internet address has been specified by caller, this is
   * being called as a result of an MNS Rarp reply being received. This
   * would have sent an address with a host byte of zero.
   */
   if (addr)
   {
      strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
      sinn.sin_family = AF_INET;
      sinn.sin_len = sizeof sinn;
      sinn.sin_addr.s_addr = htonl(0xffff0000);
      ifr.ifr_addr = *(struct sockaddr *)&sinn;

      /* Set the NetMask */
      if (socketioctl(s, SIOCSIFNETMASK, (caddr_t)&ifr) < 0)
         goto bad;

     /* If a net number was specified by caller then it will be the Econet
      * net number and we must be operating over EconetA
      */
      if (net)
      {
         mns.mns_netnumber = net;
         /* mask off bottom two bytes and OR in <Net>.<Stn> */
         addr &= ~0xffff;
         addr |= (station | net << 8);
      }
      else
      {
         /* mask off bottom byte and OR in <Stn> */
         addr &= ~0xff;
         addr |= station;
      }
      sinn.sin_addr.s_addr = htonl(addr);
   }
   else
      /* else make Internet address from station specified into 1.0.128.<Stn> */
      sinn.sin_addr.s_addr = inet_makeaddr(1, (station | (RESERVED_NET << 8)));

   sinn.sin_family = AF_INET;
   sinn.sin_len = sizeof sinn;
   ifr.ifr_addr = *(struct sockaddr *)&sinn;

  /* Set the interface Internet address. With DCI-4, this has the effect of
   * the Internet module now claiming its frame types from the driver.
   */
   DEBUGP2("#about to set Interface address to %08X\n\r", (int)sinn.sin_addr.s_addr);
   if (socketioctl(s, SIOCSIFADDR, (caddr_t)&ifr) < 0)
   {
      DEBUGP1("#SIFADDR ioctl failed\n\r");
      goto bad;
   }
   DEBUGP1("#Interface address has now been set\n\r");

  /* If interface Internet address was not specified by caller,
   * open normal use sockets
   */
   if (!addr)
   {
      if (init_sockets() == -1)
         goto bad;
      read_ifs(0, 0);
      mns.mns_retrycount = 0;
      seek_address(ifname);           /* Try to seek net address via MNS Rarp */
   }
   else
      read_ifs(0, 0);

   /* Note that we are connected to this net */
   mns.mns_states[mns.mns_netnumber] |= MNS_IS_CONNECTED;

   /* close the socket we opened just to do the manipulation */
   socketclose(s);

   DEBUGP1("#do_myaddress() exit\r\n");
   return 1;

bad:
   /* close the socket if open */
   if (s != -1)
      socketclose(s);

   mns.mns_flags = 0;

   return 0;

} /* do_myaddress() */

/******************************************************************************/

static void seek_address(char *ifname)
{
/* Try to seek net address via MNS Rarp
 *
 * Parameters:
 *    ifname  : device name of DCI driver, e.g. "en0"
 *
 * Returns:
 *    None
 */

   struct ifreq ifr;

   DEBUGP2("#seek_address() ifname = %s\n\r", ifname);

   strncpy(ifr.ifr_name, ifname, sizeof (ifr.ifr_name));
   mns.mns_flags |= MNS_SEEKADDR; /* note looking for address */
   mns.mns_retrydelay = RETRY_DELAY;
   DEBUGP2("#seek_address() atpsock = %d\n\r", mns.mns_atpsock);
#ifdef DEBUG
   DEBUGP2("#seek_address() ioctl WHOIAMMNS returned %d\n\r",
                   socketioctl(mns.mns_atpsock, SIOCGWHOIAMMNS, (caddr_t)&ifr));
#else
   (void) socketioctl(mns.mns_atpsock, SIOCGWHOIAMMNS, (caddr_t)&ifr);
#endif

   DEBUGP1("#seek_address() exit\r\n");

   return;

} /* seek_address() */

/******************************************************************************/

static int init_sockets(void)
{
   if (mns.mns_flags & MNS_SOCKET)
   {
      DEBUGP1("#init_sockets() MNS_SOCKET set: returning 0\n\r");
      return 0;
   }

   /* open on data port for input, get called directly by Internet on Rx */
   mns.mns_rxdsock    = do_getsock(MNSDATAPORT, 1, 1);

   /* open for output (port irrelevant), Rx events from Internet */
   mns.mns_txdsock    = do_getsock(MNSDATAPORT, 0, 0);

   /* open on ATP port for input, Rx events from Internet */
   mns.mns_atpsock    = do_getsock(MNSATPPORT, 1, 0);

   /* open on routed port for input, Rx events from Internet */
   mns.mns_routedsock = do_getsock(ROUTEDPORT, 1, 0);


   if (mns.mns_rxdsock < 0 || mns.mns_txdsock < 0 ||
       mns.mns_atpsock < 0 || mns.mns_routedsock < 0)
   {
      DEBUGP5("#init_sockets() do_getsock failed: returning -1\n\r#sockets = %d %d %d %d\n\r", mns.mns_rxdsock, mns.mns_txdsock, mns.mns_atpsock, mns.mns_routedsock);
      return -1;
   }
   mns.mns_flags |= MNS_SOCKET;

   DEBUGP1("#init_sockets() succeeded: returning 0\n\r");

   return 0;

} /* init_sockets() */

/******************************************************************************/

void free_sockets(void)
{
   DEBUGP5(
 "#free_sockets, rxdsock = %d, txdsock = %d, atpsock = %d, routedsock = %d\n\r",
         mns.mns_rxdsock, mns.mns_txdsock, mns.mns_atpsock, mns.mns_routedsock);

   if (mns.mns_rxdsock != -1)
   {
      (void) socketclose(mns.mns_rxdsock);
      mns.mns_rxdsock = -1;
   }

   if (mns.mns_txdsock != -1)
   {
      (void) socketclose(mns.mns_txdsock);
      mns.mns_txdsock = -1;
   }

   if (mns.mns_atpsock != -1)
   {
      (void) socketclose(mns.mns_atpsock);
      mns.mns_atpsock = -1;
   }

   if (mns.mns_routedsock != -1)
   {
      (void) socketclose(mns.mns_routedsock);
      mns.mns_routedsock = -1;
   }

   return;

} /* free_sockets() */

/******************************************************************************/

static int mns_warnings(void)
{
   if (mns.mns_stationnumber <= 1)
   {
      printf("%s: ", mns_str(Str_Warn));
      printf("%s\n", mns_str(Str_BadSta));
      return 1;
   }

   if (mns.mns_device[0] == 0)
   {
      xDEBUGP1("#mns_warnings() about to do poss. Net hardware problem\n\r");
      printf("%s: ", mns_str(Str_Warn));
      printf("%s\n", mns_str(Str_BadDev));
      return 1;
   }

   if (mns.mns_flags == 0)
   {
      xDEBUGP1("#mns_warnings() about to do No access to network\n\r");
      printf("%s: ", mns_str(Str_Warn));
      printf("%s\n", mns_str(Str_BadInet));
      return 1;
   }

   if (mns.mns_flags & MNS_WANTMAP)
   {
      printf("%s: ", mns_str(Str_Warn));
      printf("%s; ", mns_str(Str_NoMap));
      printf("%s\n", mns_str(Str_GwConf));
      return 1;
   }

   if (mns.mns_flags & MNS_WANTROUTE)
   {
      printf("%s: ", mns_str(Str_Warn));
      printf("%s; ", mns_str(Str_NoRout));
      printf("%s\n", mns_str(Str_GwConf));
      return 1;
   }

   return 0;

} /* mns_warnings() */

/******************************************************************************/

static void mns_info(int all)
{
/* Output information about connected networks, and optionally, statistics
 *
 * Parameters:
 *    all : !0 => print statistics
 *
 * Returns:
 *    None
 */

   int i, found = 0;

   printf("\n%-18s", mns_str(Str_AccNet));
   for (i = 1; i < 256; i++)
   {
      if (mns.mns_states[i] & (ECONET_IS_CONNECTED | MNS_IS_CONNECTED))
      {
         if ((++found % 8) == 0)
            printf("\n%-18s", " ");
         if (mns.mns_states[i] & ECONET_IS_CONNECTED)
            printf("*%-5d", i);
         else
            if (mns.mns_ifcnt > 0)
               printf("%-6d", i);
      }
   }
   printf("\n");

   if (!all)
      return;

   printf("\n%-18s", mns_str(Str_TxStat));
   printf("%s=%d, ", mns_str(Str_Data), mns.mns_txcnt);
   printf("%s=%d, ", mns_str(Str_Immedt), mns.mns_tximmcnt);
   printf("%s=%d, ", mns_str(Str_ImmRep), mns.mns_tximmrcnt);
   printf("%s=%d\n",mns_str(Str_Retry), mns.mns_txretry);
   printf("%-18s", " ");
   printf("%s=%d, ", mns_str(Str_Error), mns.mns_txerrs);
   printf("%s=%d, ", mns_str(Str_DtaAck), mns.mns_txacks);
   printf("%s=%d, ", mns_str(Str_DtaRej), mns.mns_txrej);
   printf("%s=%d\n", mns_str(Str_BrdCst), mns.mns_txbccnt);
   printf("%-18s", " ");
   printf("(%s=%d, ", mns_str(Str_Local), mns.mns_txlbc);
   printf("%s=%d)\n", mns_str(Str_Global), mns.mns_txgbc);
   printf("\n%-18s", mns_str(Str_RxStat));
   printf("%s=%d, ", mns_str(Str_Data), mns.mns_rxcnt);
   printf("%s=%d, ", mns_str(Str_Immedt), mns.mns_rximmcnt);
   printf("%s=%d, ", mns_str(Str_BrdCst), mns.mns_rxbc);
   printf("%s=%d\n", mns_str(Str_Dscard), mns.mns_rxdiscard);
   printf("%-18s", " ");
   printf("%s=%d, ", mns_str(Str_Retry), mns.mns_rxretries);
   printf("%s=%d, ", mns_str(Str_Error), mns.mns_rxerrs);
   printf("%s=%d, ", mns_str(Str_DtaAck), mns.mns_rxacks);
   printf("%s=%d\n", mns_str(Str_DtaRej), mns.mns_rxrej);
   printf("%-18s", " ");
   printf("%s=%d, ", mns_str(Str_ImmRep), mns.mns_rximreply);
   printf("%s=%d\n", mns_str(Str_InvRep), mns.mns_rxackdiscard);
   printf("\n%-18s", mns_str(Str_ModSts));
   printf("0%o", mns.mns_flags);
   printf("\n");

   return;

} /* mns_info() */

/******************************************************************************/

int ip_to_mns(u_long addr, int *net, int *station)
{
   struct address_q *q;
   u_long i, m;

   i = ntohl(addr);
   if (mns.mns_flags & MNS_SEEKADDR)
   {
      *station = i & 0xff;
      *net = mns.mns_netnumber;
      return 1;
   }
   m = i & ~0xff;

   for (q = mns.mns_mapq; q; q = q->q_next)
   {
      if (m == htonl(q->q_ip))
      {
         *station = i & 0xff;
         *net = (int)q->q_net;
         return 1;
      }
   }

   return 0;

} /* ip_to_mns() */

/******************************************************************************/

int src_is_ok(struct rxcb *rx, int net, int station)
{
   if (((rx->rx_network > 0 && rx->rx_network < ANY_NETWORK) && net != rx->rx_network) ||
        ((rx->rx_station > 0 && rx->rx_station < ANY_STATION) && station != rx->rx_station))
      return 0;

   return 1;

} /* src_is_ok() */

/******************************************************************************/

u_long mns_to_ip(int net, int station)
{
   struct address_q *q;
   u_long addr;

   if (net == 0)
      net = local_net();

   if ((mns.mns_states[net] & ECONET_IS_CONNECTED) != 0)
      return (u_long)0;

   if (mns.mns_flags & MNS_SEEKADDR)
   {
      if (mns.mns_econetipadr)
         return (u_long)0;
      if (net == mns.mns_netnumber)
      {
         addr = mns.mns_ifaddrs[1] ?
                             mns.mns_ifaddrs[1] & ~0xff000000 | htonl(station) :
                             inet_makeaddr(1, (station | (RESERVED_NET << 8)));
         return addr;
      }
   }
   else
   {
      for (q = mns.mns_mapq; q; q = q->q_next)
      {
         if (net == q->q_net)
            return (dst_is_local_econet(q->q_ip) ?
                                        (u_long)0 : (q->q_ip | htonl(station)));
      }
   }

   return ((connected_econet != -1) ? (u_long) 0 : (u_long) -1);

} /* mns_to_ip() */

/******************************************************************************/

static int dst_is_local_econet(u_long ip)
{
   u_long i = ntohl(ip);

   if (mns.mns_econetipadr)
   {
      i &= ~0xffff;
      return ((i == mns.mns_econetipadr) ? 1 : 0);
   }

   return (0);

} /* dst_is_local_econet() */

/******************************************************************************/

int mns_addrtoname(char *b, u_long i)
{
   struct address_q *q;
   u_long ipa;

   i &= ~0xffff;
   for (q = mns.mns_mapq; q; q = q->q_next)
   {
      ipa = ntohl(q->q_ip) & ~0xffff;
      if (ipa == i)
      {
          if (q->q_sitename[0])
          {
             strcpy(b, q->q_sitename);
             strcat(b, ".");
             strcat(b, q->q_netname);
          }
          else
             strcpy(b, q->q_netname);
          return 1;
      }
   }

   return 0;

} /* mns_addrtoname() */

/******************************************************************************/

int msg_broadcast(u_char flag, u_char port, char *data, int len, int local)
{

   if (!mns.mns_econetipadr)
      (void) msg_transmit(INADDR_BROADCAST, flag, 0, port, data, len,
                                                       BROADCAST_DATA_FRAME, 0);

   if (!local)
   {
      struct address_q *q;

      for (q = mns.mns_mapq; q; q = q->q_next)
      {
         if (q->q_bcast)
            (void) msg_transmit(q->q_bcast, flag, 0, port, data, len,
                                                       BROADCAST_DATA_FRAME, 0);
      }
      mns.mns_txgbc++;
   }
   else
      mns.mns_txlbc++;

   mns.mns_txbccnt++;

   return 0;

} /* msg_broadcast() */

/******************************************************************************/

static _kernel_oserror *is_aun_configured(void)
{
/*
 * Find out whether Net module should be allowed to start
 *
 * Parameters:
 *    None
 *
 * Returns:
 *     0 : => success (i.e. allow to start)
 *    !0 : => error (pointer to standard RISC OS error block)
 */

   _kernel_swi_regs r;
   char namebuf[32];

   /* This variable would be set by running a !BootNet application. Is it set?*/
   r.r[0] = (int)"BootNet$File";
   r.r[1] = (int)namebuf;
   r.r[2] = 32;
   r.r[3] = 0;
   r.r[4] = 0;

   /* If it is set, then return OK */

   if (_kernel_swi(OS_ReadVarVal, &r, &r) == 0)
   {
      /* If it is set, then check its value */
      if (strncmp(namebuf, "Net", 3) == 0)
         return NULL;
      else
         /* If it is set to anything else, do not start */
         return mns_error(Err_NotConf);
   }

   /* else, read CMOS to see if BootNet is Configured */
   r.r[0] = OsByte_ReadCMOS;
   r.r[1] = AUNBoot;
   /* If bit is set return OK, else return eror */
   if (_kernel_swi(OS_Byte, &r, &r) == 0 && (r.r[2] & AUNBootBit) !=0)
      return NULL;

   /* else return saying not configured */

   return mns_error(Err_NotConf);

} /* is_aun_configured() */

/******************************************************************************/

int in_local_aun_network(int net)
{
   return ((net == 0 || net == mns.mns_netnumber) ? 1 : 0);
}

/******************************************************************************/

_kernel_oserror *range_check(int port, int station, int net)
{
   if (port < 0 || port > 255)
      return mns_error(Err_BadPort);

   if (station < 0 || station > 255)
      return mns_error(Err_BadStn);

   if (net < 0 || net > 255)
      return mns_error(Err_BadNet);

   return NULL;

} /* range_check() */

/******************************************************************************/

int is_wild(int port, int station, int network)
{
   return ((network == ANY_NETWORK || station == ANY_STATION ||
           (network == 0 && station == 0) ||
            port == ANY_PORT || port == 0) ? 1 : 0);
}

/******************************************************************************/

/* EOF mns.c */
