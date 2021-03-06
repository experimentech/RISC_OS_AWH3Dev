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
 * $Header: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/ioctl,v 4.1 1997-03-06 14:28:00 rbuckley Exp $
 * $Source: /home/rool/hg/rool/internal/rab/cvsroot/mixed/RiscOS/Sources/Lib/TCPIPLibs/unixlib/c/ioctl,v $
 *
 * Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
 *
 * :RCS Log discontinued:
 * Revision 1.2  95/05/02  11:11:21  kwelton
 * Third argument to ioctl() is better described as a void *, rather
 * than a char *.
 *
 * Revision 1.1  95/04/20  09:50:21  kwelton
 * Initial revision
 *
 */
/*
 * Don't include unixlib.h because of the silly declaration of ioctl.h
 * #include "unixlib.h"
 */
extern int ioctl(int s, int cmd, void *data);
extern int socketioctl(int s, int cmd, void *data);

int ioctl(int s, int cmd, void *data)
{
    return(socketioctl(s, cmd, data));
}

/* EOF ioctl.c */
