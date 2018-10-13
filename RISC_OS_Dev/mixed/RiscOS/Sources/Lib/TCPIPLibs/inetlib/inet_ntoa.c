/* -*-C-*-
 *
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/inet_ntoa,v 4.1 1997-03-06 14:27:48 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/inet_ntoa,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.2  95/04/20  12:40:13  kwelton
 * All library functions are now prototyped in inetlib.h.
 *
 * Revision 1.1	 95/04/18  16:48:04  kwelton
 * Initial revision
 *
 */
/*
 * Copyright (c) 1983 Regents of the University of California.
 * All rights reserved.	 The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if defined(LIBC_SCCS) && !defined(lint)
static char sccsid[] = "@(#)inet_ntoa.c 5.2 (Berkeley) 3/9/86";
#endif /* LIBC_SCCS and not lint */

#include <stdio.h>

#include "sys/types.h"

#include "netinet/in.h"

#include "inetlib.h"

/*
 * Convert network-format internet address
 * to base 256 d.d.d.d representation.
 */
char *inet_ntoa(struct in_addr in)
{
	static char b[18];
	register char *p;

	p = (char *)&in;
#define UC(b)	(((int)b)&0xff)
	sprintf(b, "%d.%d.%d.%d", UC(p[0]), UC(p[1]), UC(p[2]), UC(p[3]));
	return (b);
}

/* EOF inet_ntoa.c */
