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
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/rresvport,v 4.1 1997-03-06 14:27:48 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/inetlib/c/rresvport,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.1  95/06/01  15:38:00  kwelton
 * Initial revision
 *
 */
#include "sys/errno.h"
#include "sys/types.h"
#include "sys/socket.h"

#include "netinet/in.h"

#include "inetlib.h"

extern int socketclose(int);

int rresvport(int *alport)
{
    struct sockaddr_in sin;
    int s;

    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = INADDR_ANY;
    s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0)
	return (-1);

    for (;;)
    {
	sin.sin_port = htons((u_short)*alport);
	if( bind(s, (struct sockaddr *)&sin, sizeof(sin)) >= 0 )
	    return (s);

	if( errno != EADDRINUSE )
	{
	    (void)socketclose(s);
	    return (-1);
	}

	(*alport)--;
	if( *alport == IPPORT_RESERVED/2 )
	{
	    (void)socketclose(s);
	    errno = EAGAIN;
	    return (-1);
	}
    }
}

/* EOF rresvport.c */
