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
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/access,v 4.3 1999-05-11 13:04:00 sbrodie Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/access,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.2  95/05/02  10:08:05  kwelton
 * Completely reworked to make it closer to the UNIX original, i.e. check
 * both read and write access in one call by OR'ing the appropriate mode
 * bits.  This call is still pretty naff, because RISC OS has no concept
 * of users, therefore when used on NFS filesystems this call has to
 * assume that it is the owner access bits that need to be checked rather
 * than the public ones.
 *
 * Revision 1.1  95/04/20  09:49:54  kwelton
 * Initial revision
 *
 */
#include "errno.h"
#include "kernel.h"
#include "swis.h"

#include "unistd.h"

#include "unixlib.h"

int access(const char *path, int mode)
{
    _kernel_osfile_block osf;
    int type;

    /* clear global error indicator */
    errno = 0;

    type = _kernel_osfile(17, path, &osf);

    /*
     * r0 = 0 means object not found
     */
    if( type == 0 || type == _kernel_ERROR)
	errno = ENOENT;

    /*
     * check requested access bits: X_OK always returns success since
     * RISC OS has no concept of execute permissions; R_OK and W_OK
     * need to be tested if the object is not a directory.
     */
    if( errno == 0 && type != 2 )
    {
	int attr = osf.end;

	if( (mode & R_OK) )
	    if( !(attr & 0x01) )
		errno = EACCES;

	if( (mode & W_OK) )
	    if( !(attr & 0x02) )
		errno = EACCES;
    }

    /* all done */
    return((errno == 0) ? 0 : -1);
}

/* EOF access.c */
