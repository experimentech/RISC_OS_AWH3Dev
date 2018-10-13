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
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/getpwuid,v 4.1 1997-03-06 14:28:00 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/getpwuid,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.1  95/04/20  09:50:13  kwelton
 * Initial revision
 *
 */
#include <string.h>
#include "pwd.h"

#include "unixlib.h"
#include "stubs.h"

static const char defaultusername[] = "root";

/**********************************************************************/

struct passwd *getpwuid(unsigned long uid)
{
    uid = uid;

    memset((char *)&_pwbuf, 0, sizeof(_pwbuf));

    _pwbuf.pw_name = getvarusername();

    if( _pwbuf.pw_name == 0 )
	_pwbuf.pw_name = (char *)defaultusername;

    _pwbuf.pw_uid = UNIX_MagicNumber_UID_Nobody;
    _pwbuf.pw_gid = UNIX_MagicNumber_GID_Nobody;
    return(&_pwbuf);
}

/**********************************************************************/

/* EOF getpwuid.c */