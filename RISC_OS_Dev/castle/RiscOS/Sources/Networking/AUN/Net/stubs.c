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
/* stubs.c
 *
 * Author: Keith Ruttle (Acorn)
 *
 * Description
 * ===========
 * Socket interface stubs
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
 * 09-Dec-94  17:40  JPD  Version 1.00
 * First version with change record. Modified: #includes to be ANSI-compliant.
 *
 * 10-Jan-95  16:26  JPD  Version 1.01
 * Added debugging.
 *
 * 13-Jan-95  15:01  JPD  Version 1.02
 * Modified to compile with -fah option.
 *
 * 14-Feb-95  09:24  JPD  Version 1.03
 * Added further debugging.
 *
 * 23-Feb-95  11:33  JPD  Version 1.04
 * Modified debugging.
 *
 * 14-Mar-95  15:54  JPD  Version 1.05
 * Removed OldCode.
 *
 *
 **End of change record*
 */

#include "kernel.h"

#include "sys/types.h"
#include "sys/errno.h"
#include "sys/socket.h"
#include "sys/time.h"

#include "stubs.h"
#include "debug.h"

#define XBIT            0x20000
#define BASESOCKETSWI   0x41200+XBIT

#define Socket          BASESOCKETSWI+0
#define Bind            BASESOCKETSWI+1
#define Recvfrom        BASESOCKETSWI+6
#define Recvmsg         BASESOCKETSWI+7
#define Sendto          BASESOCKETSWI+9
#define Sendmsg         BASESOCKETSWI+10
#define Setsockopt      BASESOCKETSWI+12
#define Socketclose     BASESOCKETSWI+16
#define Socketselect    BASESOCKETSWI+17
#define Socketioctl     BASESOCKETSWI+18
#define SendtoSM        BASESOCKETSWI+25

/*
 * socket interface stubs
 */
int errno;


/******************************************************************************/

int socket(int domain, int type, int protocol)
{
   _kernel_oserror *e;
   _kernel_swi_regs rin, rout;

   rin.r[0] = domain;
   rin.r[1] = type;
   rin.r[2] = protocol;
   xDEBUGP2("#calling SWI socket (0x%08X)\n\r", Socket);
   e = _kernel_swi(Socket, &rin, &rout);
   xDEBUGP1("#back from SWI socket\n\r");
   errno = e ? e->errnum : 0;
   if (errno > EREMOTE)
      errno = ESRCH;

   return (errno ? -1 : rout.r[0]);

} /* socket() */

/******************************************************************************/

int bind(int s, struct sockaddr *name, int namelen)
{
        _kernel_oserror *e;
        _kernel_swi_regs rin, rout;

        rin.r[0] = s;
        rin.r[1] = (int)name;
        rin.r[2] = namelen;
        e = _kernel_swi(Bind, &rin, &rout);
        errno = e ? e->errnum : 0;
        if (errno > EREMOTE) errno = ESRCH;
        return (errno ? -1 : 0);
}

/******************************************************************************/

int sendtosm(int s, char *buf, int len, char *buf1, int len1, struct sockaddr_in *to)
{
        _kernel_oserror *e;
        _kernel_swi_regs r;

        r.r[0] = s;
        r.r[1] = (int)buf;
        r.r[2] = len;
        r.r[3] = (int)buf1;
        r.r[4] = len1;
        r.r[5] = (int)to;
        e = _kernel_swi(SendtoSM, &r, &r);
        errno = e ? e->errnum : 0;
        if (errno > EREMOTE) errno = ESRCH;
        return (errno ? -1 : 0);
}

/******************************************************************************/

int sendto(int s, const void *msg, size_t len, int flag,
                                           const struct sockaddr *to, int tolen)
{
        _kernel_oserror *e;
        _kernel_swi_regs rin, rout;

        rin.r[0] = s;
        rin.r[1] = (int)msg;
        rin.r[2] = len;
        rin.r[3] = flag;
        rin.r[4] = (int)to;
        rin.r[5] = tolen;
        e = _kernel_swi(Sendto, &rin, &rout);
        errno = e ? e->errnum : 0;
        if (errno > EREMOTE) errno = ESRCH;
        return (errno ? -1 : rout.r[0]);
}

/******************************************************************************/

#ifdef NEVER_DEFINED
sendmsg(s, msg, flag)
int s;
struct msghdr *msg;
int flag;
{
        _kernel_oserror *e;
        _kernel_swi_regs rin, rout;

        rin.r[0] = s;
        rin.r[1] = (int)msg;
        rin.r[2] = flag;
        e = _kernel_swi(Sendmsg, &rin, &rout);
        errno = e ? e->errnum : 0;
        if (errno > EREMOTE) errno = ESRCH;
        return (errno ? -1 : rout.r[0]);
}
#endif

/******************************************************************************/

int recvfrom(int s, void *buf, size_t len, int flags, struct sockaddr *from,
                                                               int *fromlenaddr)
{
        _kernel_oserror *e;
        _kernel_swi_regs rin, rout;

        rin.r[0] = s;
        rin.r[1] = (int)buf;
        rin.r[2] = len;
        rin.r[3] = flags;
        rin.r[4] = (int)from;
        rin.r[5] = (int)fromlenaddr;
        e = _kernel_swi(Recvfrom, &rin, &rout);
        errno = e ? e->errnum : 0;
        if (errno > EREMOTE) errno = ESRCH;
        return (errno ? -1 : rout.r[0]);
}

/******************************************************************************/

#ifdef NEVER_DEFINED
recvmsg(s, msg, flags)
int s;
struct msghdr *msg;
int flags;
{
        _kernel_oserror *e;
        _kernel_swi_regs rin, rout;

        rin.r[0] = s;
        rin.r[1] = (int)msg;
        rin.r[2] = flags;
        e = _kernel_swi(Recvmsg, &rin, &rout);
        errno = e ? e->errnum : 0;
        if (errno > EREMOTE) errno = ESRCH;
        return (errno ? -1 : rout.r[0]);
}
#endif

/******************************************************************************/

int setsockopt(int s, int level, int optname, const void *optval, int optlen)
{
        _kernel_oserror *e;
        _kernel_swi_regs rin, rout;

        rin.r[0] = s;
        rin.r[1] = level;
        rin.r[2] = optname;
        rin.r[3] = (int)optval;
        rin.r[4] = optlen;
        e = _kernel_swi(Setsockopt, &rin, &rout);
        errno = e ? e->errnum : 0;
        if (errno > EREMOTE) errno = ESRCH;
        return (errno ? -1 : 0);
}

/******************************************************************************/

int socketclose(int d)
{
   _kernel_oserror *e;
   _kernel_swi_regs rin, rout;

   xDEBUGP2("#socketclose(%d)\n\r", d);
   rin.r[0] = d;
   e = _kernel_swi(Socketclose, &rin, &rout);
   errno = e ? e->errnum : 0;
   if (errno > EREMOTE)
      errno = ESRCH;

   return (errno ? -1 : 0);

} /* socketclose() */

/******************************************************************************/

int select(int nfds, fd_set *rfds, fd_set *wfds, fd_set *efds,
                                                             struct timeval *tv)
{
        _kernel_oserror *e;
        _kernel_swi_regs rin, rout;

        rin.r[0] = nfds;
        rin.r[1] = (int)rfds;
        rin.r[2] = (int)wfds;
        rin.r[3] = (int)efds;
        rin.r[4] = (int)tv;
        e = _kernel_swi(Socketselect, &rin, &rout);
        errno = e ? e->errnum : 0;
        if (errno > EREMOTE) errno = ESRCH;
        return (errno ? -1 : rout.r[0]);
}

/******************************************************************************/

int socketioctl(int s, int cmd, char *data)
{
   _kernel_oserror *e;
   _kernel_swi_regs rin, rout;

   rin.r[0] = s;
   rin.r[1] = cmd;
   rin.r[2] = (int)data;
   e = _kernel_swi(Socketioctl, &rin, &rout);
   errno = e ? e->errnum : 0;
#ifdef DEBUG
   if (errno != 0)
      DEBUGP2("#socketioctl() errno = %d\n\r", errno);
#endif
   if (errno > EREMOTE)
      errno = ESRCH;

   return (errno ? -1 : 0);

} /* socketioctl() */

/******************************************************************************/

/* EOF stubs.c */
