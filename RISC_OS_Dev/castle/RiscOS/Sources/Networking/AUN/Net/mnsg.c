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
/* mnsg.c
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
 * 15-Nov-95  14:47  JPD  Version 1.00
 * First version with change record. Modified: #includes to be ANSI-compliant,
 * other constructs to remove compiler warnings, code to cope with DCI-4 and
 * new mbuf structure. Added changes from KRuttle's 6.03 version (different
 * to RISC OS SrcFiler 6.03 version!). Allow order of module initialisation
 * to be less restrictive. Changed to use new definitions from dcistructs.h.
 *
 **End of change record*
 */

#include <string.h>
#include <stdio.h>

#include "kernel.h"
#include "swis.h"
#include "Global/OsBytes.h"
#include "Global/RISCOS.h"

#ifdef OldCode
#include <sys/types.h>
#include <sys/uio.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <net/if.h>
#include <stdio.h>
#include <sys/errno.h>
#include <ctype.h>

#include "module.h"

#else

#include <stdlib.h>

#include "sys/types.h"
#include "sys/uio.h"
#include "sys/socket.h"
#include "sys/time.h"
#include "sys/ioctl.h"
#include "netinet/in.h"
#include "net/if.h"
#include "sys/dcistructs.h"
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
#include "mns.h"
#include "mnsg.h"
#include "NetGHdr.h" /* From CMHG */
#include "gwroute/startup.h"
#include "gwroute/input.h"
#include "gwroute/trace.h"
#include "gwroute/timer.h"
#endif

#ifdef OldCode
extern int mns_event_entry(), tick_entry();
extern _kernel_oserror *call_econet();
extern _kernel_oserror *do_econet();
extern int *swi_code, *swi_data;
#else
extern char *inet_ntoa();
#endif

#ifdef OldCode
void *module_wsp = 0;
#endif

struct mns mns = { 0 };
int connected_econet = 0;
int econet_transport_type = 0;
int econet_not_present = 0;
int routed_changes = 0;
int startup_timer = 0;
#ifdef OldCode
int restarting = 0;
#endif
static u_long eco_bcast = 0;
int *routedsock = 0;  /* for routed */
int *timerp = 0;
int not_routing = 0;

extern const char *message_strs[];
extern const struct eblk error_blocks[];

#ifdef OldCode
struct {
    int  e_nbr;
    char e_string[36];
} ebuf = { 0 };

char textbuf[64];

int msg_fd_mns[4];
#endif

#ifdef OldCode
struct client {
        int (*cli_call)();      /* cli handler */
};
#endif

#ifdef OldCode
int mns_addmap();
int mns_showmap(), mns_showroutes(), mns_showif(), mns_ping();
int routed_traceoff(), routed_traceon(), routed_notrouting();
#else
static void mns_addmap(int argc, char **argv);
static void mns_showmap(int argc, char **argv);
static void mns_shroutes(int argc, char **argv);
static void mns_showif(int argc, char **argv);
static void routed_traceoff(int argc, char **argv);
static void routed_traceon(int argc, char **argv);
static void routed_notrouting(int argc, char **argv);
static int atp_return_map_q(char *, int *);
#endif

struct client mns_cli_call[9] = {
    mns_addmap,
    mns_showmap,
    mns_shroutes,
    mns_showif,
    mns_ping,
    routed_traceoff,
    routed_traceon,
    routed_notrouting,
    0,
};

#ifdef OldCode
struct swient {
        int (*swi_call)();      /* swi handler */
};

extern int CreateReceive(), ExamineReceive(), ReadReceive();
extern int AbandonReceive(), WaitForReception(), EnumerateReceive();
extern int StartTransmit(), PollTransmit(), AbandonTransmit();
extern int DoTransmit(), ReadLocalStationAndNet();
extern int ConvertStatusToString(), ConvertStatusToError();
extern int ReadProtection(), SetProtection(), ReadStationNumber();
extern int PrintBanner(), ReadTransportType(), ReleasePort(), AllocatePort();
extern int DeAllocatePort(), ClaimPort(), StartImmediate();
extern int DoImmediate(), AbandonAndReadReceive(), Version(), NetworkState();
extern int PacketSize(), ReadTransportName(), InetRxDirect(), EnumerateMap();
extern int EnumerateTransmit(), HardwareAddresses();

#define MAXSWI 34

struct swient mns_ent[MAXSWI] = {
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
    EnumerateTransmit, HardwareAddresses,
    0,
};
#else
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
#endif


#ifdef OldCode
extern _kernel_oserror *mns_error(), *init_msgs();
extern _kernel_oserror *calleverytick(), *init_econet();
extern u_long htonl(), inet_makeaddr();
extern char *inet_ntoa(), *mns_str(), *strchr();
#else
static void read_ifs(int gateway, int print);
static void namtomodule(char *nm);
static void process_input(int sock);
static void routed_process_input(int sock);
static void atp_process_input(int sock);
static int mns_warnings(void);
static void mns_info(int all);
static void setbmap(void);
#endif

static int atp_add_newitem(struct atp_block *a);
#ifdef OldCode
int init_sockets(void);
#else
static int init_sockets(void);
#endif
static int dst_is_local_econet(u_long ip);

/******************************************************************************/
#ifdef OldCode
 /*ARGS_USED*/
_kernel_oserror *
mns_init(cmd_tail, pbase, pw)
char *cmd_tail;
int pbase;
void *pw;
{
    _kernel_oserror *e = 0;

    module_wsp = pw;
    e = mns_claimv();
    if (e)
        return (e);
    e = mns_evenable();
    if (e)
        goto out;
    e = calleverytick(tick_entry);
    if (e)
        goto out;
    e = init_msgs(Module_MessagesFile, msg_fd_mns);
    if (e)
        goto out;
    e = init_econet();
    if (e)
        econet_not_present = 1;
    do_mns_init(1);
    routedsock = &(mns.mns_routedsock);
    timerp = &(mns.mns_timer);
    restarting = 1;
    setcallback();
    return NULL;
out:
    return (e);
}
#else
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
   memset((char *)&mns, 0, sizeof(mns));
   mns.mns_rxdsock = -1;
   mns.mns_txdsock = -1;
   mns.mns_atpsock = -1;
   mns.mns_routedsock = -1;

   /* Open message file for us */
   e = init_msgs(Module_MessagesFile, msg_fd_mns);
   if (e)
      return e;

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

   do_mns_init(1);

   routedsock = &(mns.mns_routedsock);
   timerp = &(mns.mns_timer);

  /* set flag and set a Callback, so that the service call to say that
   * "Econet" has been reinitialised will be issued on a Callback after this
   * initialisation has completed.
   */
   restarting = 1;
   setcallback();

   DEBUGP1("#module init successful\n\r");
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
   else
      DEBUGP1("#module init successful");
#endif

   return e;

} /* mns_init() */
#endif
/******************************************************************************/

#ifdef OldCode
notify_users()
{
    _kernel_swi_regs r;

    r.r[1] = Service_ReAllocatePorts;
    (void) _kernel_swi(OS_ServiceCall, &r, &r);
}
#endif

#ifdef OldCode
do_mns_init(booting)
int booting;
{
    _kernel_swi_regs r;
    int no_econet_clock = 0;
    int rxd, txd, atp, routed;

    rxd = booting ? -1 : mns.mns_rxdsock;
    txd = booting ? -1 : mns.mns_txdsock;
    atp = booting ? -1 : mns.mns_atpsock;
    routed = booting ? -1 : mns.mns_routedsock;
    memset((char *)&mns, 0, sizeof(mns));
    mns.mns_rxdsock    = rxd;
    mns.mns_txdsock    = txd;
    mns.mns_atpsock    = atp;
    mns.mns_routedsock = routed;
    mns.mns_txhandle = MNS_HANDLE_BASE;
    mns.mns_rxhandle = MNS_HANDLE_BASE;
    mns.mns_nextport = 1;
    if (!booting)
        return;
    (void) read_device_info(mns.mns_device, mns.mns_module,
                            &connected_econet, &no_econet_clock,
                            &mns.mns_segsize);
    if (connected_econet != -1)
        mns.mns_states[connected_econet] |= ECONET_IS_CONNECTED;
    r.r[0] = 0; r.r[1] = 2;
    econet_transport_type = call_econet(Econet_ReadTransportType, &r) ? 2 : r.r[2];
}
#else

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
 *    None
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

   if (!booting)
      return 1;

   /* Find first DCI driver present and get Econet status */
   (void) read_device_info(mns.mns_device, mns.mns_module,
                           &connected_econet, &no_econet_clock,
                           &mns.mns_segsize);

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
   return 1;

} /* do_mns_init() */

#endif

/******************************************************************************/
#ifdef OldCode
_kernel_oserror *
mns_swi_handler(swinum, r, pw)
int swinum;
_kernel_swi_regs *r;
void *pw;
{
    struct swient *callp;
    _kernel_oserror *e = 0;
    int oldstate;

    if (swinum < 0 || swinum >= MAXSWI)
        return (mns_error(Err_BadSWI));
    callp = &mns_ent[swinum];
    oldstate = ensure_irqs_off();
    e = (_kernel_oserror *)(*(callp->swi_call))(r);
    restore_irqs(oldstate);
    return (e);
}
#else
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

#endif

/******************************************************************************/

#ifdef OldCode
/*ARGSUSED*/
_kernel_oserror *
mns_cli_handler(arg_string, arg_count, cmd_no, pw)
char *arg_string;
int arg_count, cmd_no;
void *pw;
{
    struct client *callp;
    int margc;
    char *margv[10];
    char *cp;
    char **argp = margv;

    margc = 0;
    cp = arg_string;
    while (*cp && arg_count-- > 0) {
        while (isspace(*cp))
            cp++;
        if (*cp == '\0')
            break;
        *argp++ = cp;
        margc++;
        while (*cp != '\0' && !isspace(*cp))
            cp++;
        if (*cp == '\0')
            break;
        *cp++ = '\0';
    }
    *argp++ = 0;
    callp = &mns_cli_call[cmd_no];
    (void)(*(callp->cli_call))(margc, margv);
    return NULL;
}
#endif

#ifdef OldCode
mns_addmap(argc, argv)
int argc;
char **argv;
{
    struct atp_block ablock;
    u_long inet_addr();

    if (strcmp (argv[0], "0") == 0) {
        read_ifs(1, 0);
        setbmap();
        if (mns.mns_ifcnt > 0 && init_sockets() != -1) {
            mns.mns_flags = (MNS_GATEWAY|MNS_MAPISSET|MNS_SOCKET);
            if (mns.mns_routedsock != -1)
                startup_routed();
        }
    }
    else if (strcmp (argv[0], "1") == 0 && !(mns.mns_flags & MNS_MAPISSET)) {
        memset(ablock.atpb_sitename, 0, 16);
        memset(ablock.atpb_netname, 0, 16);
        ablock.atpb_ipadr = inet_addr(argv[1]);
        ablock.atpb_net = (u_char)atoi(argv[2]);
        ablock.atpb_station = 0;
        ablock.atpb_sitename[0] = 0;
        ablock.atpb_netname[0] = 0;
        argc -= 2;
        if (argc > 0 && strlen(argv[3]) < ITEM_NAMELEN) {
            if (strcmp(argv[3], "ThisSite") != 0)
                strcpy(ablock.atpb_sitename, argv[3]);
            argc--;
        }
        if (argc > 0 && strlen(argv[4]) < ITEM_NAMELEN)
            strcpy(ablock.atpb_netname, argv[4]);
        (void) atp_add_newitem(&ablock);
    }
}
#else
/******************************************************************************/

static void mns_addmap(int argc, char **argv)
{
/*
 * *AddMap code
 *
 * Parameters:
 *    argc : }
 *    argv : } command line parms
 *
 * Returns:
 *    None
 */

   struct atp_block ablock;
   u_long inet_addr();

   if (strcmp (argv[0], "0") == 0)
   {
     /* i.e. if this a *AddMap 0 command, then it is a special form of the
      * command: start up as a !Gateway
      */
      DEBUGP1("#*AddMap 0 command, starting Gateway\n\r");

      read_ifs(1, 0);
      setbmap();
      if (mns.mns_ifcnt > 0 && init_sockets() != -1)
      {
         mns.mns_flags = (MNS_GATEWAY|MNS_MAPISSET|MNS_SOCKET);
         if (mns.mns_routedsock != -1)
            startup_routed();
      }
   }
   else
      if (strcmp (argv[0], "1") == 0 && !(mns.mns_flags & MNS_MAPISSET))
      {
         /* *AddMap 1 is obviously another special */
         memset(ablock.atpb_sitename, 0, 16);
         memset(ablock.atpb_netname, 0, 16);
         ablock.atpb_ipadr = inet_addr(argv[1]);
         ablock.atpb_net = (u_char)atoi(argv[2]);
         ablock.atpb_station = 0;
         ablock.atpb_sitename[0] = 0;
         ablock.atpb_netname[0] = 0;
         argc -= 2;
         if (argc > 0 && strlen(argv[3]) < ITEM_NAMELEN)
         {
            if (strcmp(argv[3], "ThisSite") != 0)
               strcpy(ablock.atpb_sitename, argv[3]);
            argc--;
         }
         if (argc > 0 && strlen(argv[4]) < ITEM_NAMELEN)
            strcpy(ablock.atpb_netname, argv[4]);
         (void) atp_add_newitem(&ablock);
      }

   return;

} /* mns_addmap() */

#endif

/******************************************************************************/

#ifdef OldCode
/*ARGSUSED*/
mns_showif(argc, argv)
int argc;
char **argv;
{
    int all = 0;

    if (mns_warnings())
        return;
    if (argc > 0)
        all = 1;
    read_ifs(0, 1);
    mns_info(all);
}
#else
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

   read_ifs(0, 1);


   /* Output information about connected networks, and optionally, statistics */

   mns_info(all);

   return;

} /* mns_showif() */

#endif

/******************************************************************************/

#ifdef OldCode
mns_ping(argc, argv)
int argc;
char **argv;
{
    _kernel_swi_regs r;
    int station, net;
    char b[6];

    r.r[1] = (int)(argv[0]);
    if (!ReadStationNumber(&r)) {
        station = r.r[2];
        net     = r.r[3] == -1 ? 0 : r.r[3];
        r.r[0]  = 8;   /* MachinePeek */
        r.r[1]  = 0;
        r.r[2]  = station;
        r.r[3]  = net;
        r.r[4]  = (int)b;
        r.r[5]  = sizeof(b);
        r.r[6]  = 2;
        r.r[7]  = 100;
        printf("%s\n", (DoImmediate(&r) == 0 && r.r[0] == Status_Transmitted) ?
                       mns_str(Str_TxOk) : mns_str(Str_NotAcc));
        return;
    }
    printf("%s\n", mns_str(Str_GtwSta));
}
#endif

/******************************************************************************/
#ifdef OldCode
mns_showmap(argc, argv)
int argc;
char **argv;
{
    struct address_q *q;
    u_char net = 0;
    char abuf[32];
    int n;

    if (argc)
        net = (u_char)atoi(argv[0]);
    for (q = mns.mns_mapq; q; q = q->q_next) {
        if (net && net != q->q_net)
            continue;
        sprintf(abuf, "%s", inet_ntoa(q->q_ip));
        if (n = strlen(abuf))
            abuf[n-1] = 'x';
        printf("%-8d%-16s%-16s%s\n", q->q_net, q->q_netname, abuf, q->q_sitename);
        if (net)
            break;
    }
}
#else
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

#endif

/******************************************************************************/

static void mns_shroutes(int argc, char **argv)
{
/*
 * *Networks code
 *
 * Parameters:
 *    argc : }
 *    argv : } command line parms (none)
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

#ifdef OldCode
/*ARGSUSED*/
routed_traceoff(argc, argv)
int argc;
char **argv;
{
    traceoff(1);
    return (0);
}
#else

/******************************************************************************/

static void routed_traceoff(int argc, char **argv)
{
/*
 * *NetTraceOff code:
 *
 * Parameters:
 *    argc : }
 *    argv : } command line parms (none)
 *
 * Returns:
 *    None
 */

   UNUSED(argc);
   UNUSED(argv);

   traceoff();

   return;

} /* routed_traceoff() */

#endif

/******************************************************************************/

#ifdef OldCode
routed_traceon(argc, argv)
int argc;
char **argv;
{
    traceon (argc > 0 ? *argv : 0);
    return (0);
}

#else

/******************************************************************************/

static void routed_traceon(int argc, char **argv)
{
/*
 * *NetTraceOn code:
 *
 * Parameters:
 *    argc : }
 *    argv : } command line parms (filename for trace output)
 *
 * Returns:
 *    None
 */

   traceon(argc > 0 ? *argv : 0);

   return;

} /* routed_traceon() */
#endif

/******************************************************************************/

#ifdef OldCode
/*ARGSUSED*/
routed_notrouting(argc, argv)
int argc;
char **argv;
{
    not_routing = 1;
    return (0);
}
#else
/******************************************************************************/

static void routed_notrouting(int argc, char **argv)
{
/*
 * *NetRouterOff code:
 *
 * Parameters:
 *    argc : }
 *    argv : } command line parms (none)
 *
 * Returns:
 *    None
 */

   UNUSED(argc);
   UNUSED(argv);

   not_routing = 1;

   return;

} /* routed_notrouting() */

#endif
/******************************************************************************/

#ifdef OldCode
_kernel_oserror *
mns_error(error)
int error;
{
    _kernel_swi_regs r;
    _kernel_oserror *e;

    if (!error)
        return NULL;
    ebuf.e_nbr = error_blocks[error].err_nbr;
    strcpy(ebuf.e_string, error_blocks[error].err_token);
    memset ((char *)&r, 0, sizeof(r));
    r.r[0] = (int)&ebuf;
    r.r[1] = (int)msg_fd_mns;
    e = _kernel_swi(MessageTrans_ErrorLookup, &r, &r);
    return (e ? e : (_kernel_oserror *)&ebuf);
}

char *
mns_str(strnbr)
int strnbr;
{
    _kernel_swi_regs r;
    _kernel_oserror *e;

    /* prevent unwanted parameter substitution */
    memset ((char *)&r, 0, sizeof(r));
    *textbuf = '\0';
    r.r[0] = (int)msg_fd_mns;
    r.r[1] = (int)message_strs[strnbr];
    r.r[2] = (int)textbuf;
    r.r[3] = sizeof(textbuf);
    e = _kernel_swi(MessageTrans_Lookup, &r, &r);
    return (e ? message_strs[strnbr] : textbuf);
}

generate_event(rx, handle, status, port)
int rx, handle, status, port;
{
    _kernel_swi_regs r;

    r.r[0] = rx ? Event_Econet_Rx : Event_Econet_Tx;
    r.r[1] = handle;
    r.r[2] = status;
    r.r[3] = port;
    (void) _kernel_swi(OS_GenerateEvent, &r, &r);
}

extern int callb_entry();
volatile int callbackflag = 0;

setcallback()
{
    if (callbackflag == 0) {
        callbackflag = 1;
        if (callback(callb_entry) != 0)
            callbackflag = 0;
    }
}

generate_event_on_callback(tx)
struct txcb *tx;
{
    tx->tx_callb = 1;
    setcallback();
}

retransmit_on_callback(tx)
struct txcb *tx;
{
    tx->tx_callb = 2;
    setcallback();
}

int callback(func)
void (* func)();
{
    _kernel_swi_regs r;

    r.r[0] = (int)func;
    r.r[1] = (int)module_wsp;
    return (_kernel_swi(OS_AddCallBack, &r, &r) != 0 ? -1 : 0);
}

int callb_handler(r)
int *r;
{
    struct txcb *tx;
    int cval;
    int oldstate;

    if (callbackflag == 0)
        return (1);
    callbackflag = 0;
    if (restarting) {
        restarting = 0;
        notify_users();
    }
    for (;;) {
        oldstate = ensure_irqs_off();
        for (tx = mns.mns_txlist; tx; tx = tx->tx_next) {
            if ((cval = tx->tx_callb) != 0) {
                tx->tx_callb = 0;
                break;
            }
        }
        restore_irqs(oldstate);
        if (tx == (struct txcb *)0)
            break;
        switch (cval) {
            case 1:
                if (tx->tx_status != Status_Free)
                    generate_event(0, tx->tx_handle, tx->tx_status, tx->tx_port);
                break;

            case 2:
                retry_tx(tx);
                break;

            default:
                break;
        }
    }
    return (1);
}

_kernel_oserror *
calleverytick(fun)
int (*fun)();
{
    _kernel_oserror *e;
    _kernel_swi_regs r;

    r.r[0] = TickerV;
    r.r[1] = (int)fun;
    r.r[2] = (int)module_wsp;
    e = _kernel_swi(OS_Claim, &r, &r);
    if (e)
        return (e);
    return NULL;
}

removetickerevent(fun)
int (*fun)();
{
    _kernel_swi_regs r;

    r.r[0] = TickerV;
    r.r[1] = (int)fun;
    r.r[2] = (int)module_wsp;
    (void) _kernel_swi(OS_Release, &r, &r);
}
#endif

/******************************************************************************/

#ifdef OldCode
tick_handler(r, pw)
int *r;
void *pw;
{
    if (mns.mns_timer > 0 && --(mns.mns_timer) == 0)
        rt_bcast();
    if (startup_timer > 0 && --startup_timer == 0)
        do_ripcmd_req();
    check_rxcbs();
    check_txcbs();
    return (1);
}
#else
_kernel_oserror *tick_handler(_kernel_swi_regs *r, void *pw)
{
/*
 * cmhg ticker interrupt handler
 *
 * Parameters:
 *    r  : pointer to registers block
 *    pw : "R12" value established by module initialisation
 */

   UNUSED(r);
   UNUSED(pw);

   if (mns.mns_timer > 0 && --(mns.mns_timer) == 0)
      rt_bcast();

   if (startup_timer > 0 && --startup_timer == 0)
      do_ripcmd_req();

   check_rxcbs();
   check_txcbs();

   return NULL;

} /* tick_handler() */

#endif

/******************************************************************************/
/*
 * This version of this routine is different from that used in the other
 * variants of the modules in that it switches off checksums on sockets.
 * Ignore this difference and use the other variant in mnscommon.c.
 */

#ifdef OldCode
int
do_getsock(port, inputsocket, direct)
int port, inputsocket, direct;
{
    struct sockaddr_in addr;
    int sock, arg, on = 1;

    if ((sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
        return (-1);
    arg = direct ? Econet_InetRxDirect : 1;
    if (socketioctl(sock, FIONBIO, (char *)&on) < 0 || socketioctl(sock, direct ? FIORXDIR : FIOASYNC, (char *)&arg) < 0) {
        socketclose (sock);
        return (-1);
    }
    if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST, (char *)&on, sizeof (on)) < 0 ||
        setsockopt(sock, SOL_SOCKET, SO_NOCHKSUM, (char *)&on, sizeof (on)) < 0) {
        socketclose(sock);
        return (-1);
    }
    if (inputsocket) {
        addr.sin_family = AF_INET;
        addr.sin_len    = sizeof addr;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons((u_short)port);
        if (bind(sock, (struct sockaddr *)&addr, sizeof (addr)) < 0) {
            socketclose(sock);
            return (-1);
        }
    }
    return (sock);
}
#else
#if 0
int do_getsock(int port, int inputsocket, int direct)
{
   struct sockaddr_in addr;
   int sock, arg, on = 1;


   if ((sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
       return -1;

   arg = direct ? Econet_InetRxDirect : 1;

   if (socketioctl(sock, FIONBIO, (char *)&on) < 0 ||
       socketioctl(sock, direct ? FIORXDIR : FIOASYNC, (char *)&arg) < 0)
   {
      socketclose (sock);
      return -1;
   }

   if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST, (char *)&on, sizeof (on)) < 0
     || setsockopt(sock, SOL_SOCKET, SO_NOCHKSUM, (char *)&on, sizeof (on)) < 0)
   {
      socketclose(sock);
      return -1;
   }

   if (inputsocket)
   {
      addr.sin_family = AF_INET;
      addr.sin_addr.s_addr = htonl(INADDR_ANY);
      addr.sin_port = htons((u_short)port);
      if (bind(sock, (struct sockaddr *)&addr, sizeof (addr)) < 0)
      {
         socketclose(sock);
         return -1;
      }
   }

   return sock;

} /* do_getsock() */

#endif
#endif

/******************************************************************************/

#ifdef OldCode
mns_final()
{
    traceoff(1);
    mns_releasev();
    release_msgs(msg_fd_mns);
    free_sockets();
    removetickerevent(tick_entry);
}
#else
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

   traceoff();

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

#endif

#ifdef OldCode
/*ARGSUSED*/
void mns_sc_handler(sn,r)
int sn;
_kernel_swi_regs *r;
{
    switch (sn) {
        case Service_ProtocolDying:
            if (r->r[2] == InternetID)
                break;
            return;

        case Service_Reset:
            if (!reset_is_soft())
                return;
            break;

        case Service_EconetDying:
            break;

        default:
            return;
    }
    do_mns_init(0);
    econet_not_present = 1;
    connected_econet = -1;
    return;
}

int reset_is_soft()
{
    _kernel_swi_regs r;

    r.r[0] = OsByte_RW_LastResetType;
    r.r[1] = 0;
    r.r[2] = 255;
    return ((_kernel_swi(OS_Byte, &r, &r) != 0 || r.r[1] == 0) ? 1 : 0);
}
#endif

/******************************************************************************/

#ifdef OldCode
mns_event_handler(r, pw)
int *r;
void *pw;
{
    if (r[0] == Event_Internet && r[1] == SocketIO) {
        if (r[2] == mns.mns_atpsock || r[2] == mns.mns_routedsock) {
            process_input(r[2]);
            return (0);
        }
    }
    return (1);
}
#else
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

   /* cmhg will only pass through Internet event anyway */
   if (r->r[0] == Event_Internet && r->r[1] == SocketIO)
   {
      _kernel_irqs_on();

      /* if notification of asynchronous I/O */
      if (r->r[2] == mns.mns_atpsock || r->r[2] == mns.mns_routedsock)
      {
         DEBUGP1("#Event SocketIO ...\n\r");
         process_input(r->r[2]);
         return _kernel_irqs_off(), 0;
      }
   }
   return _kernel_irqs_off(), 1;

} /* mns_event_handler() */

#endif

/******************************************************************************/

#ifdef OldCode
read_ifs(gateway, print)
int gateway, print;
{
    int s, n, eco, no_econet_clock;
    char buf[512], name[24];
    struct ifconf ifc;
    struct ifreq ifreq, *ifr;
    struct sockaddr_in *sin;
    u_long addr;
    int icnt, first = 1;

    if ((s = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
        return;
    ifc.ifc_len = sizeof (buf);
    ifc.ifc_buf = buf;
    if (socketioctl(s, OSIOCGIFCONF, (char *)&ifc) < 0) {
        socketclose(s);
        return;
    }
    if (print && mns.mns_econetipadr == 0 && connected_econet != -1) {
        (void) read_eco_info(&connected_econet, &no_econet_clock);
        printf("%-18s", mns_str(Str_NtvEco));
        printf("%d.%d", connected_econet, mns.mns_stationnumber);
        if (no_econet_clock)
            printf(" (%s)", mns_str(Str_Noclck));
        printf("\n\n");
    }
    for (n = 0; n < 4; n++)
        mns.mns_ifaddrs[n] = 0;
    icnt = 0;
    mns.mns_ifcnt = 0;
    mns.mns_econetipadr = 0;
    eco_bcast = 0;
    ifr = ifc.ifc_req;
    for (n = ifc.ifc_len / sizeof (struct ifreq); n > 0; n--, ifr++) {
        if (((struct osockaddr *)&ifr->ifr_addr)->sa_family != AF_INET)
           continue;
        ifreq = *ifr;
        if (socketioctl(s, SIOCGIFFLAGS, (char *)&ifreq) < 0 || ifreq.ifr_flags & IFF_LOOPBACK)
            continue;
        if (print) {
            if (!first)
                printf("\n");
            printf("%-18s", mns_str(Str_IfType));
        }
        eco = strcmp(ifreq.ifr_name, "ec0") == 0 ? 1 : 0;
        if (print) {
            strcpy(name, ifreq.ifr_name);
            name[strlen(name) - 1] = 0;
            namtomodule(name);
            printf("%s ", name);
        }
        if ((ifreq.ifr_flags & (IFF_BROADCAST|IFF_UP)) != (IFF_BROADCAST|IFF_UP)) {
            if (print)
                printf("(%s)\n", mns_str(Str_Down));
            goto next;
        }
        if (print)
            printf("\n");
        if (socketioctl(s, SIOCGIFADDR, (char *)&ifreq) < 0)
            goto next;
        sin = (struct sockaddr_in *)&ifreq.ifr_addr;
        addr = ntohl(sin->sin_addr.s_addr);
        if (mns.mns_stationnumber == 0)
            mns.mns_stationnumber = (addr & 0xff);
        if (print) {
            printf("%-18s%ld.%ld\n",  mns_str(Str_StaNum), (addr & 0xff00) >> 8, addr & 0xff);
            printf("%-18s%s\n", mns_str(Str_FullAd), inet_ntoa(sin->sin_addr));
        }
        if (eco || !mns.mns_netnumber)
            mns.mns_netnumber = (addr & 0xff00) >> 8;
        if (eco) {
            mns.mns_econetipadr = (addr & ~0xffff);
            mns.mns_econetnumber = connected_econet;
        }
        if (socketioctl(s, SIOCGIFBRDADDR, (char *)&ifreq) < 0)
            goto next;
        sin = (struct sockaddr_in *)&ifreq.ifr_addr;

        if (eco)
            eco_bcast = sin->sin_addr.s_addr;
        else
            mns.mns_ifaddrs[icnt++] = sin->sin_addr.s_addr;
        mns.mns_ifcnt++;
        if (gateway)
            (void) socketioctl(s, SIOCGWHOIAMMNS, (char *)&ifreq);
        if (icnt == 4 && eco_bcast)
            break;
next:
        first = 0;
    }
    socketclose(s);
    return;
}
#else
/******************************************************************************/

static void read_ifs(int gateway, int print)
{
/*
 * Obtain information about the network interfaces
 *
 * Parameters:
 *    gateway : whether starting up as a !Gateway machine
 *    print   : !0 => display details of interfaces
 *
 * Returns:
 *    None
 */

   int s, n, eco, no_econet_clock;
   static char buf[512];
   char name[24];
   struct ifconf ifc;
   struct ifreq ifreq, *ifr;
   struct sockaddr_in *sin;
   u_long addr;
   int icnt, first = 1;

   DEBUGP3("#read_ifs(%d, %d)\n\r", gateway, print);

   /* open a socket to use to obtain details */
   if ((s = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
      return;

   ifc.ifc_len = sizeof (buf);
   ifc.ifc_buf = buf;

   /* get the interface info list from the Internet module */
   if (socketioctl(s, OSIOCGIFCONF, (char *)&ifc) < 0)
   {
      socketclose(s);
      return;
   }

   /* if connected to Econet, get Econet info */
   if (print && mns.mns_econetipadr == 0 && connected_econet != -1)
   {
      (void) read_eco_info(&connected_econet, &no_econet_clock);
      printf("%-18s", mns_str(Str_NtvEco));
      printf("%d.%d", connected_econet, mns.mns_stationnumber);
      if (no_econet_clock)
         printf(" (%s)", mns_str(Str_Noclck));
      printf("\n\n");
   }

   for (n = 0; n < 4; n++)
      mns.mns_ifaddrs[n] = 0;
   icnt = 0;
   mns.mns_ifcnt = 0;
   mns.mns_econetipadr = 0;
   eco_bcast = 0;
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

      if (print)
      {
         if (!first)
            printf("\n");
         /* Print "Interface" */
         printf("%-18s", mns_str(Str_IfType));
      }

      /* If looking at the EconetA device, set eco true */
      eco = strcmp(ifreq.ifr_name, "ec0") == 0 ? 1 : 0;

      if (print)
      {
         strcpy(name, ifreq.ifr_name);
         name[strlen(name) - 1] = 0;
         namtomodule(name);
         printf("%s ", name);
      }

      if ((ifreq.ifr_flags & (IFF_BROADCAST|IFF_UP)) != (IFF_BROADCAST|IFF_UP))
      {
         if (print)
            printf("(%s)\n", mns_str(Str_Down));
         goto next;
      }

      if (print)
         printf("\n");

      /* get interface Internet address */
      if (socketioctl(s, SIOCGIFADDR, (char *)&ifreq) < 0)
         goto next;

      sin = (struct sockaddr_in *)&ifreq.ifr_addr;
      addr = ntohl(sin->sin_addr.s_addr);

      if (mns.mns_stationnumber == 0)
         mns.mns_stationnumber = (addr & 0xff);

      if (print)
      {
         /* Print "AUN Station" */
         printf("%-18s%ld.%ld\n", mns_str(Str_StaNum),
                                             (addr & 0xff00) >> 8, addr & 0xff);
         /* Print "Full address" */
         printf("%-18s%s\n", mns_str(Str_FullAd),
                                        inet_ntoa(*((u_long *)&sin->sin_addr)));
      }

      if (eco || !mns.mns_netnumber)
         mns.mns_netnumber = (addr & 0xff00) >> 8;

      if (eco)
      {
         mns.mns_econetipadr = (addr & ~0xffff);
         mns.mns_econetnumber = connected_econet;
      }

      /* get Internet broadcast address for interface */
      if (socketioctl(s, SIOCGIFBRDADDR, (char *)&ifreq) < 0)
         goto next;

      sin = (struct sockaddr_in *)&ifreq.ifr_addr;

      /* If this is the EconetA interface, take copy of the broadcast address */
      if (eco)
         eco_bcast = sin->sin_addr.s_addr;
      else
         mns.mns_ifaddrs[icnt++] = sin->sin_addr.s_addr;
      mns.mns_ifcnt++;

      if (gateway)
      /* If startup as a !Gateway, broadcast REVARP replies to tell everyone
       * else their address
       */
      {
         DEBUGP2("#read_ifs() Doing socketioctl SIOCSWHOTHEYARE to %s\n\r",
                                                                ifreq.ifr_name);
         (void) socketioctl(s, SIOCSWHOTHEYARE, (char *)&ifreq);
      }

      /* if we've done 4 interfaces and we've got the Econet broadcast address*/
      if (icnt == 4 && eco_bcast)
         break;

next:
      first = 0;
   }

   /* close the socket: we only opened it to get the info */
   socketclose(s);

   return;

} /* read_ifs() */

#endif

/******************************************************************************/
#ifdef OldCode
int
process_input(sock)
int sock;
{
    fd_set ibits;
    int nfd, r;
    struct timeval tv;

    FD_ZERO(&ibits);
    nfd = sock + 1;
    FD_SET(sock, &ibits);
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    if ((r = select(nfd, &ibits, 0, 0, &tv)) > 0 && FD_ISSET(sock, &ibits)) {
        if (sock == mns.mns_atpsock)
            atp_process_input(sock);
        else if (sock == mns.mns_routedsock)
            routed_process_input(sock);
    }
    return (0);
}
#else
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

#endif

/******************************************************************************/
#ifdef OldCode
char atpbuf[1024];

int
atp_process_input(sock)
int sock;
{
    struct sockaddr from;
    int fromlen, r, count;
    char *c;
    struct atp_msg *atp;

    for (;;) {
        fromlen = sizeof (from);
        r = recvfrom(sock, atpbuf, sizeof (atpbuf), 0, &from, &fromlen);
        if (r < 0 || fromlen != sizeof (struct sockaddr_in))
            break;
        atp = (struct atp_msg *)atpbuf;
        c = (char *)&atp->atp_address;
        if (atp->atp_opcode == MNS_TRANSFORM_REQUEST) {
            r = atp_return_map_q(c, &count);
            if (count > 0) {
                atp->atp_opcode = MNS_TRANSFORM_REPLY;
                atp->atp_count = count;
                (void) sendto(mns.mns_atpsock, (char *)atp, r+2, 0, &from, sizeof(struct sockaddr_in));
            }
        }
    }
    return (0);
}
#else
/******************************************************************************/

static void atp_process_input(int sock)
{
   struct sockaddr from;
   int fromlen, r, count;
   char *c;
   struct atp_msg *atp;
   static char atpbuf[1024];

   DEBUGP2("#atp_process_input(%d)\n\r", sock);

   for (;;)
   {
      fromlen = sizeof(from);
      r = recvfrom(sock, atpbuf, sizeof (atpbuf), 0, &from, &fromlen);
      if (r < 0 || fromlen != sizeof (struct sockaddr_in))
         break;
      atp = (struct atp_msg *)atpbuf;
      c = (char *)&atp->atp_address;
      if (atp->atp_opcode == MNS_TRANSFORM_REQUEST)
      {
         r = atp_return_map_q(c, &count);
         if (count > 0)
         {
            atp->atp_opcode = MNS_TRANSFORM_REPLY;
            atp->atp_count = count;
            (void) sendto(mns.mns_atpsock, (char *)atp, r+2, 0, &from,
                                                    sizeof(struct sockaddr_in));
         }
      }
   }

   return;

} /* atp_process_input() */

#endif

/******************************************************************************/

#ifdef OldCode
char ripbuf[1024];

int routed_process_input(sock)
int sock;
{
    struct sockaddr from;
    int fromlen, r;

    for (;;) {
        fromlen = sizeof (from);
        r = recvfrom(sock, ripbuf, sizeof (ripbuf), 0, &from, &fromlen);
        if (r < 0 || fromlen != sizeof (struct sockaddr_in))
            break;
        rip_input(&from, (struct rip *)ripbuf, r);
    }
    return (0);
}
#else

static void routed_process_input(int sock)
{
   struct sockaddr from;
   int fromlen, r;
   static char ripbuf[1024];

   DEBUGP2("#routed_process_input(%d)\n\r", sock);

   for (;;)
   {
      fromlen = sizeof(from);
      r = recvfrom(sock, ripbuf, sizeof(ripbuf), 0, &from, &fromlen);
      if (r < 0 || fromlen != sizeof(struct sockaddr_in))
         break;
      rip_input(&from, (struct rip *)ripbuf, r);
   }

   return;

} /* routed_process_input() */

#endif

/******************************************************************************/

#ifdef OldCode
u_long
atp_setbcast(addr)
u_long addr;
{
    struct address_q *q;

    for (q = mns.mns_mapq; q; q = q->q_next) {
        if (q->q_bcast == addr)
            return ((u_long)0);
    }
    return (addr);
}
#else
static u_long atp_setbcast(u_long addr)
{
   struct address_q *q;

   for (q = mns.mns_mapq; q; q = q->q_next)
   {
      if (q->q_bcast == addr)
         return (u_long)0;
   }

   return addr;

} /* atp_setbcast() */

#endif

/******************************************************************************/

#ifdef OldCode
int
atp_add_newitem(a)
struct atp_block *a;
{
    struct address_q *q;
    char *malloc();
    struct address_q **p;

    p = &(mns.mns_mapq);
    while (*p) {
        if ((*p)->q_net == a->atpb_net) {
            if ((*p)->q_ip == a->atpb_ipadr)
                return(0);
            q = *p;
            break;
        }
        p = &((*p)->q_next);
    }
    if ((*p) == 0) {
        q = (struct address_q *)malloc (sizeof(struct address_q));
        if (q == (struct address_q *)0)
            return (-1);
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
    return (0);
}
#else
/******************************************************************************/

static int atp_add_newitem(struct atp_block *a)
{
   struct address_q *q;
   struct address_q **p;

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

#endif

static int atp_return_map_q(char *a, int *count)
{
    struct address_q *q;
    int n, r;

    r = 0; n = 0;
    for (q = mns.mns_mapq; q; q = q->q_next) {
        *a++ = q->q_net;
        *a++ = 0;
        memcpy(a, (char *)&(q->q_ip), 4);
        a += 4;
        r += 6;
        memcpy(a, q->q_sitename, ITEM_NAMELEN);
        a += ITEM_NAMELEN;
        r += ITEM_NAMELEN;
        memcpy(a, q->q_netname, ITEM_NAMELEN);
        a += ITEM_NAMELEN;
        r += ITEM_NAMELEN;
        n++;
    };
    *count = n;
    return (r);
}

#ifdef OldCode
int init_sockets(void)
{
    if (mns.mns_flags & MNS_SOCKET)
        return (0);
    mns.mns_rxdsock = do_getsock(MNSDATAPORT, 1, 1);
    mns.mns_txdsock = do_getsock(MNSDATAPORT, 0, 0);
    mns.mns_atpsock = do_getsock(MNSATPPORT, 1, 0);
    mns.mns_routedsock = do_getsock(ROUTEDPORT, 1, 0);
    if (mns.mns_rxdsock < 0 || mns.mns_txdsock < 0 ||
        mns.mns_atpsock < 0 || mns.mns_routedsock < 0)
        return (-1);
    return (0);
}
#else
static int init_sockets(void)
{
/* Initialise sockets for our use
 *
 * Parameters:
 *    None
 *
 * Returns:
 *    0 : => all OK
 *   !0 : => some problem
 *
 */


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

   DEBUGP1("#init_sockets() succeeded: returning 0\n\r");

   return 0;

} /* init_sockets() */

#endif

/******************************************************************************/

#ifdef OldCode
free_sockets()
{
    if (mns.mns_rxdsock != -1)
        (void) socketclose(mns.mns_rxdsock);
    if (mns.mns_txdsock != -1)
        (void) socketclose(mns.mns_txdsock);
    if (mns.mns_atpsock != -1)
        (void) socketclose(mns.mns_atpsock);
    if (mns.mns_routedsock != -1)
        (void) socketclose(mns.mns_routedsock);
}
#else
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
#endif

/******************************************************************************/

static int mns_warnings(void)
{
   if (!(mns.mns_flags & MNS_GATEWAY))
   {
      printf("%s: ", mns_str(Str_Warn));
      printf("%s\n", mns_str(Str_BadGwy));
      return 1;
   }

   return 0;

} /* mns_warnings() */

/******************************************************************************/

#ifdef OldCode
mns_info(all)
int all;
{
    int i, found = 0;

    printf("\n%-18s", mns_str(Str_AccNet));
    for (i = 1; i < 256; i++) {
        if (mns.mns_states[i] & (ECONET_IS_CONNECTED|MNS_IS_CONNECTED)) {
            if ((++found % 8) == 0)
                printf("\n%-18s", " ");
            if (mns.mns_states[i] & ECONET_IS_CONNECTED)
                printf("*%-5d", i);
            else if (mns.mns_ifcnt > 0)
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
}

#else

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
      if (mns.mns_states[i] & (ECONET_IS_CONNECTED|MNS_IS_CONNECTED))
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
#endif

/******************************************************************************/

#ifdef OldCode
int
ip_to_mns(addr, net, station)
u_long addr;
int *net, *station;
{
    struct address_q *q;
    u_long i, m;

    i = ntohl(addr);
    m = i & ~0xff;
    for (q = mns.mns_mapq; q; q = q->q_next) {
        if (m == htonl(q->q_ip)) {
            *station = i & 0xff;
            *net = (int)q->q_net;
            return(1);
        }
    }
    return (0);
}

#else
int ip_to_mns(u_long addr, int *net, int *station)
{
   struct address_q *q;
   u_long i, m;

   i = ntohl(addr);
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

#endif

/******************************************************************************/

#ifdef OldCode
int
src_is_ok(rx, net, station)
struct rxcb *rx;
int net, station;
{
    if (((rx->rx_network > 0 && rx->rx_network < ANY_NETWORK) && net != rx->rx_network) ||
        ((rx->rx_station > 0 && rx->rx_station < ANY_STATION) && station != rx->rx_station))
        return (0);
    return (1);
}
#else

int src_is_ok(struct rxcb *rx, int net, int station)
{
   if (((rx->rx_network > 0 && rx->rx_network < ANY_NETWORK) && net != rx->rx_network) ||
        ((rx->rx_station > 0 && rx->rx_station < ANY_STATION) && station != rx->rx_station))
      return 0;

   return 1;

} /* src_is_ok() */

#endif

/******************************************************************************/

#ifdef OldCode
u_long
mns_to_ip(net, station)
int net, station;
{
    struct address_q *q;

    if (net == 0)
        net = local_net();

    if ((mns.mns_states[net] & ECONET_IS_CONNECTED) != 0)
        return ((u_long)0);

    for (q = mns.mns_mapq; q; q = q->q_next) {
        if (net == q->q_net)
            return (dst_is_local_econet(q->q_ip) ? (u_long)0 : (q->q_ip | htonl(station)));
    }

    return ((connected_econet != -1) ? (u_long) 0 : (u_long) -1);
}
#else

u_long mns_to_ip(int net, int station)
{
   struct address_q *q;

   if (net == 0)
      net = local_net();

   if ((mns.mns_states[net] & ECONET_IS_CONNECTED) != 0)
      return (u_long)0;

   for (q = mns.mns_mapq; q; q = q->q_next)
   {
      if (net == q->q_net)
         return (dst_is_local_econet(q->q_ip) ?
                                        (u_long)0 : (q->q_ip | htonl(station)));
   }

   return ((connected_econet != -1) ? (u_long) 0 : (u_long) -1);

} /* mns_to_ip() */

#endif

/******************************************************************************/

static int dst_is_local_econet(u_long ip)
{
   u_long i = ntohl(ip);

   if (mns.mns_econetipadr)
   {
      i &= ~0xffff;
      return ((i == mns.mns_econetipadr) ? 1 : 0);
   }

   return 0;

} /* dst_is_local() */

/******************************************************************************/

#ifdef OldCode
int
mns_addrtoname(b, i)
char *b;
u_long i;
{
    struct address_q *q;
    u_long ipa;

    i &= ~0xffff;
    for (q = mns.mns_mapq; q; q = q->q_next) {
        ipa = ntohl(q->q_ip) & ~0xffff;
        if (ipa == i) {
            if (q->q_sitename[0]) {
                strcpy(b, q->q_sitename);
                strcat(b, ".");
                strcat(b, q->q_netname);
            }
            else
                strcpy(b, q->q_netname);
            return (1);
        }
    }
    return (0);
}
#else
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

#endif

/******************************************************************************/

#ifdef oldCode
setbmap()
{
    struct address_q *q;

    for (q = mns.mns_mapq; q; q = q->q_next) {
        if (q->q_bcast == eco_bcast)
            q->q_bcast = 0;
    }
}
#else
static void setbmap(void)
{
   struct address_q *q;

   for (q = mns.mns_mapq; q; q = q->q_next)
   {
      if (q->q_bcast == eco_bcast)
         q->q_bcast = 0;
   }

   return;

} /* setbmap() */

#endif

/******************************************************************************/
#ifdef OldCode
int
msg_broadcast(flag, port, data, len, local)
u_char flag, port;
char *data;
int len, local;
{
    struct address_q *q;
    int i;

    if (local || !mns.mns_mapq) {
        for (i = 0; i < 4; i++) {
            if (mns.mns_ifaddrs[i])
                (void) msg_transmit(mns.mns_ifaddrs[i], flag, 0, port, data, len, BROADCAST_DATA_FRAME, 0);
        }
    }
    else {
        for (q = mns.mns_mapq; q; q = q->q_next) {
            if (q->q_bcast)
                (void) msg_transmit(q->q_bcast, flag, 0, port, data, len, BROADCAST_DATA_FRAME, 0);
        }
    }
    if (local)
        mns.mns_txlbc++;
    else
        mns.mns_txgbc++;
    mns.mns_txbccnt++;
    return (0);
}
#else
/******************************************************************************/

int msg_broadcast(u_char flag, u_char port, char *data, int len, int local)
{
   struct address_q *q;
   int i;

   if (local || !mns.mns_mapq)
   {
      for (i = 0; i < 4; i++)
      {
         if (mns.mns_ifaddrs[i])
            (void) msg_transmit(mns.mns_ifaddrs[i], flag, 0, port, data, len,
                                                       BROADCAST_DATA_FRAME, 0);
      }
   }
   else
   {
      for (q = mns.mns_mapq; q; q = q->q_next)
      {
         if (q->q_bcast)
            (void) msg_transmit(q->q_bcast, flag, 0, port, data, len,
                                                       BROADCAST_DATA_FRAME, 0);
      }
   }

   if (local)
      mns.mns_txlbc++;
   else
      mns.mns_txgbc++;

   mns.mns_txbccnt++;

   return 0;

} /* msg_broadcast() */

#endif

/******************************************************************************/

#ifdef OldCode
namtomodule(nm)
char *nm;
{
    _kernel_swi_regs r;
    _kernel_oserror *e;
    struct dib *d;

    r.r[1] = Service_FindNetworkDriver;
    r.r[2] = (int)nm;
    r.r[3] = 0;
    e = _kernel_swi(OS_ServiceCall,&r, &r);
    if (e == 0 && r.r[1] == 0 && (d = (struct dib *)(r.r[3])) != (struct dib *)0) {
        e = _kernel_swi(d->dib_swibase + DCI_Version, &r, &r);
        if (!e && r.r[0] >= CURRENT_DCI_VERSION)
            strncpy(nm, d->dib_module, 24);
    }
}
#else
/******************************************************************************/

static void namtomodule(char *nm)
{
/*
 * Get the module name relating to a device name
 *
 * Parameters:
 *    nm : pointer to a string holding the device name without the number,
 *         e.g. "en"
 *
 * Returns:
 *    None
 *    nm : still points to the string, now holding the module name,
 *         e.g. "Ether2"
 */

   _kernel_swi_regs r;
   _kernel_oserror *e;
   struct dib *d;
   struct chaindib *chdp, *n;

   r.r[0] = 0;         /* initialise to zero so that we can detect a response */
   r.r[1] = Service_EnumerateNetworkDrivers;
   /* Issue service call to find all DCI4 drivers */
   e = _kernel_swi(OS_ServiceCall, &r, &r);


   /* if no error issuing service call and received a response */
   if ((e == 0) && (chdp = (struct chaindib *)(r.r[0]), chdp != 0))
   {
      n = chdp->chd_next;
      d = chdp->chd_dib;

      while (d != 0)
      {
         if (strcmp((char *)d->dib_name, nm) == 0)
         {
            r.r[0] = 0;
            e = _kernel_swi((d->dib_swibase + DCI4Version), &r, &r);
            if (!e && r.r[1] >= MINIMUM_DCI_VERSION)
               strncpy(nm, (char *)d->dib_module, 24);
            break;
         }
         else
         {
            if (n == 0)
               break;

            /* step on */
            d = n->chd_dib;
            n = n->chd_next;
         }
      }

      /* Now, free all the chaindibs returned to us */
      while (chdp != 0)
      {
         r.r[0] = 7;      /* reason code Free */
         r.r[2] = (int) chdp;
         chdp = chdp->chd_next;
         if (e = _kernel_swi(OS_Module, &r, &r), e != 0);
            /* if any error, probably should not continue freeing blocks */
            break;
      }
   }

   return;

} /* namtomodule() */

#endif

/******************************************************************************/

#ifdef OldCode
int
in_local_aun_network(net)
int net;
{
    return (0);
}
#else
/******************************************************************************/

int in_local_aun_network(int net)
{
   UNUSED(net);

   return 0;

}  /* in_local_aun_network() */

#endif

/******************************************************************************/

#ifdef OldCode
_kernel_oserror *
range_check(port, station, net)
int port, station, net;
{
    if (port < 0 || port > 255)
        return(mns_error(Err_BadPort));
    if (station < 0 || station > 255)
        return(mns_error(Err_BadStn));
    if (net < 0 || net > 255)
        return(mns_error(Err_BadNet));
    return NULL;
#else
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

#endif

/******************************************************************************/
#ifdef OldCode

int
is_wild(port, station, network)
int port, station, network;
{
    return ((network == ANY_NETWORK || network == 0 ||
             station == ANY_STATION || station == 0 ||
             port == ANY_PORT || port == 0) ? 1 : 0);
}
#else
int is_wild(int port, int station, int network)
{
/* Insert KRuttle's 6.03 changes */
   return ((network == ANY_NETWORK || station == ANY_STATION ||
           (network == 0 && station == 0) ||
            port == ANY_PORT || port == 0) ? 1 : 0);

} /* is_wild() */

#endif

/******************************************************************************/

/* EOF mnsg.c */
