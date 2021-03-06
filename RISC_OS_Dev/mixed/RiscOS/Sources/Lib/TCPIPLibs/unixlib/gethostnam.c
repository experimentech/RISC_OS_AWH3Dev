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
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/gethostnam,v 4.1 1997-03-06 14:27:59 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/gethostnam,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.1  95/04/20  09:50:07  kwelton
 * Initial revision
 *
 */
#include <stdio.h>
#include <string.h>

#include "kernel.h"
#include "swis.h"

#include "unixlib.h"
#include "stubs.h"

static const char hostnamevar[] = "Inet$HostName";
static const char defaulthostname[] = "ARM_NoName";

/**********************************************************************/

char *getvarhostname(void)
{
    int retried = 0;
    int nread;
    _kernel_oserror *e;

    do
    {
        if( (e = _swix(OS_ReadVarVal, _INR(0,4)|_OUT(2),
                                      hostnamevar,
                                      _varnamebuf,
                                      VARBUFSIZE,
                                      0, 0,
                                      &nread
                      )) == NULL )
	{
	    _varnamebuf[nread] = '\0';

	    if (nread > 0)
		return(_varnamebuf);
	}

	if( !retried )
	{
	    e = _swix(OS_SetVarVal, _INR(0,4),
	                            hostnamevar,
	                            defaulthostname,
	                            sizeof(defaulthostname),
	                            0, 0);
	}
    } while( !(retried++) && e == NULL );

    /*
     * failed - return nothing
     */
    return ((char *)0);
}

/**********************************************************************/

int gethostname(char *name, int max_namelen)
{
    char *n;

    if( (n = getvarhostname()) != 0 )
	(void)strncpy(name, n, max_namelen);
    else
	(void)strncpy(name, defaulthostname, max_namelen);

    return (0);
}

/**********************************************************************/

/* EOF gethostnam.c */
