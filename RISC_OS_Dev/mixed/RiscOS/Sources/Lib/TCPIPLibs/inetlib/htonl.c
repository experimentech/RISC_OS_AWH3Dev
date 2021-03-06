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
/* -*-C-*-
 *
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/htonl,v 4.1 1997-03-06 14:27:48 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/htonl,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.2  95/04/20  12:40:01  kwelton
 * All library functions are now prototyped in inetlib.h.
 *
 * Revision 1.1	 95/04/18  16:47:58  kwelton
 * Initial revision
 *
 */
#include "sys/types.h"

#include "inetlib.h"

#define ROR(x, n) (((x) << (32-(n))) | ((x) >> (n)))

#undef htonl
#undef htons

u_long htonl(u_long x)
{
    return(ntohl(x));
}

int htons(int x)
{
    return(ntohs(x));
}

u_long ntohl(u_long x)
{
#ifdef __arm
    /*
     * This compiles to the neat four cycle byte-swap code
     * from the ARM Architecture Reference (section 4.1.4).
     * (Seven cycles on the ARM 8, but that's 'cos it's
     * slow).
     */
    u_long t;
                            /* x = A , B , C , D   */
    t = x ^ ROR(x, 16);     /* t = A^C,B^D,C^A,D^B */
    t &=~ 0x00ff0000;       /* t = A^C, 0 ,C^A,D^B */
    x = ROR(x, 8);          /* x = D , A , B , C   */
    x = x ^ (t >> 8);       /* x = D , C , B , A   */

    return x;
#else
    return(((x & 0xff) << 24) | ((x & 0xff00) << 8) |
	   ((x & 0xff0000) >> 8) | ((x & 0xff000000) >> 24));
#endif
}

int ntohs(int x)
{
    return(((x & 0xff) << 8) | ((x & 0xff00) >> 8));
}

/* EOF htonl.c */
