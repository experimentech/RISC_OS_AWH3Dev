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
/* inetfn.c
 *
 * Author: Keith Ruttle (Acorn)
 *
 * Description
 * ===========
 * Internet and network address manipulation routines
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
 * 04-Jan-95  11:56  JPD  Version 1.00
 * First version with change record. Modified: #includes to be ANSI-compliant,
 * added header file for extern delarations.
 *
 * 22-Feb-95  11:53  JPD  Vesrion 1.01
 * Removed OldCode
 *
 *
 **End of change record*
 */

#include "sys/types.h"
#include "netinet/in.h"

#include "inetfn.h"


/*
 * Return the netmask pertaining to an internet address.
 */
u_long inet_maskof(u_long inaddr)
{
	register u_long i = ntohl(inaddr);
	register u_long mask;

        /* All hard-wired in AUN! */
	if (i == 0)
		mask = 0;
	else
		mask = IN_CLASSB_NET;

	return (htonl(mask));
}


/******************************************************************************/

/* EOF inetfn.c */