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
/*
 * The mrouted program is covered by the license in the accompanying file
 * named "LICENSE".  Use of the mrouted program represents acceptance of
 * the terms and conditions listed in that file.
 *
 * The mrouted program is COPYRIGHT 1989 by The Board of Trustees of
 * Leland Stanford Junior University.
 *
 *
 * $Id: pathnames,v 1.1 1999-07-22 16:49:55 kbracey Exp $
 * pathnames.h,v 3.8 1995/11/29 22:36:57 fenner Rel
 */

#ifndef __riscos
#define _PATH_MROUTED_CONF	"/etc/mrouted.conf"

#if (defined(BSD) && (BSD >= 199103))
#define _PATH_MROUTED_PID	"/var/run/mrouted.pid"
#define _PATH_MROUTED_GENID	"/var/run/mrouted.genid"
#define _PATH_MROUTED_DUMP	"/var/tmp/mrouted.dump"
#define _PATH_MROUTED_CACHE	"/var/tmp/mrouted.cache"
#else
#define _PATH_MROUTED_PID	"/etc/mrouted.pid"
#define _PATH_MROUTED_GENID	"/etc/mrouted.genid"
#define _PATH_MROUTED_DUMP	"/usr/tmp/mrouted.dump"
#define _PATH_MROUTED_CACHE	"/usr/tmp/mrouted.cache"
#endif
#endif
