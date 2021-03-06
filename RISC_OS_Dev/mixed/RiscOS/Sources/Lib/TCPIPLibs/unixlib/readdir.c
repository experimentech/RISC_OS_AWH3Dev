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
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/readdir,v 4.1 1997-03-06 14:28:01 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/readdir,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.1  95/04/20  09:50:27  kwelton
 * Initial revision
 *
 */
#include "kernel.h"
#include "swis.h"

#include "unixlib.h"

/*
 * This is very poor - in no way, shape, or form, is it a
 * replacement/emulation of the UNIX readdir() function. I
 * am *not* going to mess with it, however, since the chance
 * is that something, somewhere, uses it in its current form.
 *
 * What I cannot understand is, if the function has been changed
 * so radically, why does it still have the same name?
 */
int readdir(const char *path, char *buf, int len, const char *name, int offset)
{
    _kernel_osgbpb_block osg;

    osg.dataptr  = buf;
    osg.nbytes   = 1;
    osg.fileptr  = offset;
    osg.buf_len  = len;
    osg.wild_fld = (char *) name;

   _kernel_osgbpb(9, (int) path, &osg);

    if( osg.nbytes != 1 )			/* number of objects read */
	return(-1);
    else
	return(osg.fileptr);			/* next item to read */
}

/* EOF readdir.c */
