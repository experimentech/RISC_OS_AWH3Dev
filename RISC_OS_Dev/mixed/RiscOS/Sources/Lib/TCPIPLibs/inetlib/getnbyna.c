/* -*-C-*-
 *
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/getnbyna,v 4.1 1997-03-06 14:27:47 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/getnbyna,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.2  95/04/20  12:39:40  kwelton
 * All library functions are now prototyped in inetlib.h.
 *
 * Revision 1.1	 95/04/18  16:47:49  kwelton
 * Initial revision
 *
 */
/*
 * Copyright (c) 1983 Regents of the University of California.
 * All rights reserved.	 The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if defined(LIBC_SCCS) && !defined(lint)
static char sccsid[] = "@(#)getnetbyname.c	5.3 (Berkeley) 5/19/86";
#endif /* LIBC_SCCS and not lint */

#include <string.h>

#include "netdb.h"

#include "inetlib.h"

struct netent *getnetbyname(const char *name)
{
	register struct netent *p;
	register char **cp;

	setnetent(_net_stayopen);
	while (p = getnetent()) {
		if (strcmp(p->n_name, name) == 0)
			break;
		for (cp = p->n_aliases; *cp != 0; cp++)
			if (strcmp(*cp, name) == 0)
				goto found;
	}
found:
	if (!_net_stayopen)
		endnetent();
	return (p);
}

/* EOF getnbyna.c */
