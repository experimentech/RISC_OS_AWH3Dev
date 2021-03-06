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
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/getwd,v 4.1 1997-03-06 14:28:00 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/getwd,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.1  95/04/20  09:50:17  kwelton
 * Initial revision
 *
 */
#include "kernel.h"
#include "swis.h"

#include "unixlib.h"

char *getwd(char *buf)
{
    char namebuf[32], *b, *c, length;

    _swix(OS_GBPB, _IN(0)|_IN(2), 6, namebuf);

    length = namebuf[1];
    b = buf;
    c = &namebuf[2];

    while (length-- > 0)
	*b++ = *c++;

    *b = '\0';

    return(buf);
}

/* EOF getwd.c */
