/* -*-C-*-
 *
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/getsbyna,v 4.1 1997-03-06 14:27:48 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/getsbyna,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.2  95/04/20  12:39:53  kwelton
 * All library functions are now prototyped in inetlib.h.
 *
 * Revision 1.1	 95/04/18  16:47:55  kwelton
 * Initial revision
 *
 */
/*
 * Copyright (c) 1983 Regents of the University of California.
 * All rights reserved.	 The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if defined(LIBC_SCCS) && !defined(lint)
static char sccsid[] = "@(#)getservbyname.c	5.3 (Berkeley) 5/19/86";
#endif /* LIBC_SCCS and not lint */

#include <string.h>

#include "netdb.h"

#include "inetlib.h"

struct servent *getservbyname(const char *name, const char *proto)
{
	register struct servent *p;
	register char **cp;

	setservent(_serv_stayopen);
	while (p = getservent()) {
		if (strcmp(name, p->s_name) == 0)
			goto gotname;
		for (cp = p->s_aliases; *cp; cp++)
			if (strcmp(name, *cp) == 0)
				goto gotname;
		continue;
gotname:
		if (proto == 0 || strcmp(p->s_proto, proto) == 0)
			break;
	}
	if (!_serv_stayopen)
		endservent();
	return (p);
}

/* EOF getsbyna.c */
