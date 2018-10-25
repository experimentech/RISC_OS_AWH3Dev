# This source code in this file is licensed to You by Castle Technology
# Limited ("Castle") and its licensors on contractual terms and conditions
# ("Licence") which entitle you freely to modify and/or to distribute this
# source code subject to Your compliance with the terms of the Licence.
# 
# This source code has been made available to You without any warranties
# whatsoever. Consequently, Your use, modification and distribution of this
# source code is entirely at Your own risk and neither Castle, its licensors
# nor any other person who has contributed to this source code shall be
# liable to You for any loss or damage which You may suffer as a result of
# Your use, modification or distribution of this source code.
# 
# Full details of Your rights and obligations are set out in the Licence.
# You should have received a copy of the Licence with this source code file.
# If You have not received a copy, the text of the Licence is available
# online at www.castle-technology.co.uk/riscosbaselicence.htm
# 
#
# Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
#
# Makefile for inetlib.a
#
# Makefile,v
# Revision 1.3  95/06/01  15:37:14  kwelton
# Added rresvport(), remade dependencies.
#
# Revision 1.2  95/04/20  12:40:17  kwelton
# All library functions are now prototyped in inetlib.h.
#
# Revision 1.1  95/04/18  16:48:06  kwelton
# Initial revision
#
#
LIBDIR = <Lib$Dir>

#
# Generic options:
#
MKDIR   = do mkdir -p
WIPE    = x wipe
RM      = x remove
CP      = copy
CC	= cc
AS	= objasm
LD	= link
LIB	= libfile
CMHG	= cmhg

WFLAGS  = ~c~v
CPFLAGS = ~cflnr~v

INCLUDES=	TCPIPLibs:,C:

CFLAGS=		-depend !Depend -Wap -zps0 -I${INCLUDES} -fah -Fn -DINET -DCOMPAT_INET4
CFLAGSZM=	-depend !Depend -Wap -zps1 -I${INCLUDES} -ffah -DINET -DCOMPAT_INET4 -zM

CCZM=		${CC} ${CFLAGSZM}

CFILES=		gethent.c gethnad.c getnbyad.c getnbyna.c getnent.c \
		getprent.c getprnam.c getproto.c getsbyna.c getsbypo.c \
		getsent.c htonl.c inet_addr.c inet_lnaof.c inet_maddr.c \
		inet_nof.c inet_ntoa.c inet_nwork.c rresvport.c \
		linkaddr.c ns_addr.c ns_ntoa.c iso_addr.c sysctlbyna.c \
		inet_nntop.c inet_npton.c inet_ntop.c inet_pton.c

OFILES=		gethent.o gethnad.o getnbyad.o getnbyna.o getnent.o \
		getprent.o getprnam.o getproto.o getsbyna.o getsbypo.o \
		getsent.o htonl.o inet_addr.o inet_lnaof.o inet_maddr.o \
		inet_nof.o inet_ntoa.o inet_nwork.o rresvport.o \
		linkaddr.o ns_addr.o ns_ntoa.o iso_addr.o sysctlbyna.o \
		inet_nntop.o inet_npton.o inet_ntop.o inet_pton.o

ZFILES=		z.gethent z.gethnad z.getnbyad z.getnbyna z.getnent \
		z.getprent z.getprnam z.getproto z.getsbyna z.getsbypo \
		z.getsent z.htonl z.inet_addr z.inet_lnaof z.inet_maddr \
		z.inet_nof z.inet_ntoa z.inet_nwork z.rresvport \
		z.linkaddr z.ns_addr z.ns_ntoa z.iso_addr z.sysctlbyna \
		z.inet_nntop z.inet_npton z.inet_ntop z.inet_pton

.SUFFIXES:	.z .o .c .s

.c.z:;       ${CCZM} -c -o $@ $<
.c.o:;       ${CC} ${CFLAGS} -c -o $@ $<

COMPONENT = inetlib
LIBDIR = <Lib$Dir>

all:	inetlib inetlibzm

inetlib:	${OFILES} local_dirs
	${LIB} -c inetlib ${OFILES}
	${LIB} -o inetlib

inetlibzm:	${ZFILES} local_dirs
	${LIB} -c inetlibzm ${ZFILES}
	${LIB} -o inetlibzm

export: export_${PHASE}

export_hdrs:
	${CP} h.inetlib	TCPIPLibs:h.inetlib	${CPFLAGS}
        @echo ${COMPONENT}: export complete (hdrs)

export_libs: inetlib inetlibzm dirs
	${CP} inetlib	TCPIPLibs:o.inetlib	${CPFLAGS}
	${CP} inetlibzm	TCPIPLibs:o.inetlibzm	${CPFLAGS}

dirs:
	${MKDIR} $(LIBDIR)
	${MKDIR} $(LIBDIR).TCPIPLibs
	${MKDIR} $(LIBDIR).TCPIPLibs.o

local_dirs:
        ${MKDIR} o
        ${MKDIR} z

clean:
	${WIPE} o.* ${WFLAGS}
	${WIPE} z.* ${WFLAGS}
	${RM} inetlib
	${RM} inetlibzm


# Dynamic dependencies:
o.gethent:	c.gethent
o.gethent:	TCPIPLibs:h.netdb
o.gethent:	TCPIPLibs:sys.h.cdefs
o.gethent:	TCPIPLibs:sys.h.types
o.gethent:	TCPIPLibs:sys.h.cdefs
o.gethent:	TCPIPLibs:machine.h.endian
o.gethent:	TCPIPLibs:machine.h.ansi
o.gethent:	TCPIPLibs:machine.h.types
o.gethent:	TCPIPLibs:sys.h.socket
o.gethent:	TCPIPLibs:sys.h.cdefs
o.gethent:	h.inetlib
o.gethent:	TCPIPLibs:sys.h.types
o.gethent:	TCPIPLibs:netinet.h.in
o.gethnad:	c.gethnad
o.gethnad:	C:h.kernel
o.gethnad:	C:h.swis
o.gethnad:	TCPIPLibs:h.netdb
o.gethnad:	TCPIPLibs:sys.h.cdefs
o.gethnad:	h.inetlib
o.gethnad:	TCPIPLibs:sys.h.types
o.gethnad:	TCPIPLibs:sys.h.cdefs
o.gethnad:	TCPIPLibs:machine.h.endian
o.gethnad:	TCPIPLibs:machine.h.ansi
o.gethnad:	TCPIPLibs:machine.h.types
o.gethnad:	TCPIPLibs:netinet.h.in
o.getnbyad:	c.getnbyad
o.getnbyad:	TCPIPLibs:h.netdb
o.getnbyad:	TCPIPLibs:sys.h.cdefs
o.getnbyad:	h.inetlib
o.getnbyad:	TCPIPLibs:sys.h.types
o.getnbyad:	TCPIPLibs:sys.h.cdefs
o.getnbyad:	TCPIPLibs:machine.h.endian
o.getnbyad:	TCPIPLibs:machine.h.ansi
o.getnbyad:	TCPIPLibs:machine.h.types
o.getnbyad:	TCPIPLibs:netinet.h.in
o.getnbyna:	c.getnbyna
o.getnbyna:	TCPIPLibs:h.netdb
o.getnbyna:	TCPIPLibs:sys.h.cdefs
o.getnbyna:	h.inetlib
o.getnbyna:	TCPIPLibs:sys.h.types
o.getnbyna:	TCPIPLibs:sys.h.cdefs
o.getnbyna:	TCPIPLibs:machine.h.endian
o.getnbyna:	TCPIPLibs:machine.h.ansi
o.getnbyna:	TCPIPLibs:machine.h.types
o.getnbyna:	TCPIPLibs:netinet.h.in
o.getnent:	c.getnent
o.getnent:	TCPIPLibs:h.netdb
o.getnent:	TCPIPLibs:sys.h.cdefs
o.getnent:	TCPIPLibs:sys.h.types
o.getnent:	TCPIPLibs:sys.h.cdefs
o.getnent:	TCPIPLibs:machine.h.endian
o.getnent:	TCPIPLibs:machine.h.ansi
o.getnent:	TCPIPLibs:machine.h.types
o.getnent:	TCPIPLibs:sys.h.socket
o.getnent:	TCPIPLibs:sys.h.cdefs
o.getnent:	h.inetlib
o.getnent:	TCPIPLibs:sys.h.types
o.getnent:	TCPIPLibs:netinet.h.in
o.getprent:	c.getprent
o.getprent:	TCPIPLibs:h.netdb
o.getprent:	TCPIPLibs:sys.h.cdefs
o.getprent:	TCPIPLibs:sys.h.types
o.getprent:	TCPIPLibs:sys.h.cdefs
o.getprent:	TCPIPLibs:machine.h.endian
o.getprent:	TCPIPLibs:machine.h.ansi
o.getprent:	TCPIPLibs:machine.h.types
o.getprent:	TCPIPLibs:sys.h.socket
o.getprent:	TCPIPLibs:sys.h.cdefs
o.getprent:	h.inetlib
o.getprent:	TCPIPLibs:sys.h.types
o.getprent:	TCPIPLibs:netinet.h.in
o.getprnam:	c.getprnam
o.getprnam:	TCPIPLibs:h.netdb
o.getprnam:	TCPIPLibs:sys.h.cdefs
o.getprnam:	h.inetlib
o.getprnam:	TCPIPLibs:sys.h.types
o.getprnam:	TCPIPLibs:sys.h.cdefs
o.getprnam:	TCPIPLibs:machine.h.endian
o.getprnam:	TCPIPLibs:machine.h.ansi
o.getprnam:	TCPIPLibs:machine.h.types
o.getprnam:	TCPIPLibs:netinet.h.in
o.getproto:	c.getproto
o.getproto:	TCPIPLibs:h.netdb
o.getproto:	TCPIPLibs:sys.h.cdefs
o.getproto:	h.inetlib
o.getproto:	TCPIPLibs:sys.h.types
o.getproto:	TCPIPLibs:sys.h.cdefs
o.getproto:	TCPIPLibs:machine.h.endian
o.getproto:	TCPIPLibs:machine.h.ansi
o.getproto:	TCPIPLibs:machine.h.types
o.getproto:	TCPIPLibs:netinet.h.in
o.getsbyna:	c.getsbyna
o.getsbyna:	TCPIPLibs:h.netdb
o.getsbyna:	TCPIPLibs:sys.h.cdefs
o.getsbyna:	h.inetlib
o.getsbyna:	TCPIPLibs:sys.h.types
o.getsbyna:	TCPIPLibs:sys.h.cdefs
o.getsbyna:	TCPIPLibs:machine.h.endian
o.getsbyna:	TCPIPLibs:machine.h.ansi
o.getsbyna:	TCPIPLibs:machine.h.types
o.getsbyna:	TCPIPLibs:netinet.h.in
o.getsbypo:	c.getsbypo
o.getsbypo:	TCPIPLibs:h.netdb
o.getsbypo:	TCPIPLibs:sys.h.cdefs
o.getsbypo:	h.inetlib
o.getsbypo:	TCPIPLibs:sys.h.types
o.getsbypo:	TCPIPLibs:sys.h.cdefs
o.getsbypo:	TCPIPLibs:machine.h.endian
o.getsbypo:	TCPIPLibs:machine.h.ansi
o.getsbypo:	TCPIPLibs:machine.h.types
o.getsbypo:	TCPIPLibs:netinet.h.in
o.getsent:	c.getsent
o.getsent:	TCPIPLibs:h.netdb
o.getsent:	TCPIPLibs:sys.h.cdefs
o.getsent:	TCPIPLibs:sys.h.types
o.getsent:	TCPIPLibs:sys.h.cdefs
o.getsent:	TCPIPLibs:machine.h.endian
o.getsent:	TCPIPLibs:machine.h.ansi
o.getsent:	TCPIPLibs:machine.h.types
o.getsent:	TCPIPLibs:sys.h.socket
o.getsent:	TCPIPLibs:sys.h.cdefs
o.getsent:	h.inetlib
o.getsent:	TCPIPLibs:sys.h.types
o.getsent:	TCPIPLibs:netinet.h.in
o.htonl:	c.htonl
o.htonl:	TCPIPLibs:sys.h.types
o.htonl:	TCPIPLibs:sys.h.cdefs
o.htonl:	TCPIPLibs:machine.h.endian
o.htonl:	TCPIPLibs:machine.h.ansi
o.htonl:	TCPIPLibs:machine.h.types
o.htonl:	h.inetlib
o.htonl:	TCPIPLibs:sys.h.types
o.htonl:	TCPIPLibs:netinet.h.in
o.inet_addr:	c.inet_addr
o.inet_addr:	TCPIPLibs:sys.h.param
o.inet_addr:	TCPIPLibs:sys.h.types
o.inet_addr:	TCPIPLibs:sys.h.cdefs
o.inet_addr:	TCPIPLibs:machine.h.endian
o.inet_addr:	TCPIPLibs:machine.h.ansi
o.inet_addr:	TCPIPLibs:machine.h.types
o.inet_addr:	TCPIPLibs:sys.h.syslimits
o.inet_addr:	TCPIPLibs:sys.h.signal
o.inet_addr:	TCPIPLibs:machine.h.signal
o.inet_addr:	TCPIPLibs:sys.h.cdefs
o.inet_addr:	TCPIPLibs:machine.h.param
o.inet_addr:	TCPIPLibs:machine.h.limits
o.inet_addr:	TCPIPLibs:netinet.h.in
o.inet_addr:	TCPIPLibs:arpa.h.inet
o.inet_addr:	TCPIPLibs:sys.h.cdefs
o.inet_addr:	h.inetlib
o.inet_addr:	TCPIPLibs:sys.h.types
o.inet_addr:	TCPIPLibs:netinet.h.in
o.inet_lnaof:	c.inet_lnaof
o.inet_lnaof:	TCPIPLibs:sys.h.types
o.inet_lnaof:	TCPIPLibs:sys.h.cdefs
o.inet_lnaof:	TCPIPLibs:machine.h.endian
o.inet_lnaof:	TCPIPLibs:machine.h.ansi
o.inet_lnaof:	TCPIPLibs:machine.h.types
o.inet_lnaof:	TCPIPLibs:netinet.h.in
o.inet_lnaof:	h.inetlib
o.inet_lnaof:	TCPIPLibs:sys.h.types
o.inet_lnaof:	TCPIPLibs:netinet.h.in
o.inet_maddr:	c.inet_maddr
o.inet_maddr:	TCPIPLibs:sys.h.param
o.inet_maddr:	TCPIPLibs:sys.h.types
o.inet_maddr:	TCPIPLibs:sys.h.cdefs
o.inet_maddr:	TCPIPLibs:machine.h.endian
o.inet_maddr:	TCPIPLibs:machine.h.ansi
o.inet_maddr:	TCPIPLibs:machine.h.types
o.inet_maddr:	TCPIPLibs:sys.h.syslimits
o.inet_maddr:	TCPIPLibs:sys.h.signal
o.inet_maddr:	TCPIPLibs:machine.h.signal
o.inet_maddr:	TCPIPLibs:sys.h.cdefs
o.inet_maddr:	TCPIPLibs:machine.h.param
o.inet_maddr:	TCPIPLibs:machine.h.limits
o.inet_maddr:	TCPIPLibs:netinet.h.in
o.inet_maddr:	TCPIPLibs:arpa.h.inet
o.inet_maddr:	TCPIPLibs:sys.h.cdefs
o.inet_maddr:	h.inetlib
o.inet_maddr:	TCPIPLibs:sys.h.types
o.inet_maddr:	TCPIPLibs:netinet.h.in
o.inet_nof:	c.inet_nof
o.inet_nof:	TCPIPLibs:sys.h.types
o.inet_nof:	TCPIPLibs:sys.h.cdefs
o.inet_nof:	TCPIPLibs:machine.h.endian
o.inet_nof:	TCPIPLibs:machine.h.ansi
o.inet_nof:	TCPIPLibs:machine.h.types
o.inet_nof:	TCPIPLibs:netinet.h.in
o.inet_nof:	h.inetlib
o.inet_nof:	TCPIPLibs:sys.h.types
o.inet_nof:	TCPIPLibs:netinet.h.in
o.inet_ntoa:	c.inet_ntoa
o.inet_ntoa:	TCPIPLibs:sys.h.types
o.inet_ntoa:	TCPIPLibs:sys.h.cdefs
o.inet_ntoa:	TCPIPLibs:machine.h.endian
o.inet_ntoa:	TCPIPLibs:machine.h.ansi
o.inet_ntoa:	TCPIPLibs:machine.h.types
o.inet_ntoa:	TCPIPLibs:netinet.h.in
o.inet_ntoa:	h.inetlib
o.inet_ntoa:	TCPIPLibs:sys.h.types
o.inet_ntoa:	TCPIPLibs:netinet.h.in
o.inet_nwork:	c.inet_nwork
o.inet_nwork:	TCPIPLibs:sys.h.types
o.inet_nwork:	TCPIPLibs:sys.h.cdefs
o.inet_nwork:	TCPIPLibs:machine.h.endian
o.inet_nwork:	TCPIPLibs:machine.h.ansi
o.inet_nwork:	TCPIPLibs:machine.h.types
o.inet_nwork:	h.inetlib
o.inet_nwork:	TCPIPLibs:sys.h.types
o.inet_nwork:	TCPIPLibs:netinet.h.in
o.rresvport:	c.rresvport
o.rresvport:	TCPIPLibs:sys.h.errno
o.rresvport:	C:h.kernel
o.rresvport:	TCPIPLibs:sys.h.types
o.rresvport:	TCPIPLibs:sys.h.cdefs
o.rresvport:	TCPIPLibs:machine.h.endian
o.rresvport:	TCPIPLibs:machine.h.ansi
o.rresvport:	TCPIPLibs:machine.h.types
o.rresvport:	TCPIPLibs:sys.h.socket
o.rresvport:	TCPIPLibs:sys.h.cdefs
o.rresvport:	TCPIPLibs:netinet.h.in
o.rresvport:	h.inetlib
o.rresvport:	TCPIPLibs:sys.h.types
o.rresvport:	TCPIPLibs:netinet.h.in
o.linkaddr:	c.linkaddr
o.linkaddr:	TCPIPLibs:sys.h.types
o.linkaddr:	TCPIPLibs:sys.h.cdefs
o.linkaddr:	TCPIPLibs:machine.h.endian
o.linkaddr:	TCPIPLibs:machine.h.ansi
o.linkaddr:	TCPIPLibs:machine.h.types
o.linkaddr:	TCPIPLibs:sys.h.socket
o.linkaddr:	TCPIPLibs:sys.h.cdefs
o.linkaddr:	TCPIPLibs:net.h.if_dl
o.linkaddr:	TCPIPLibs:sys.h.cdefs
o.linkaddr:	h.inetlib
o.linkaddr:	TCPIPLibs:sys.h.types
o.linkaddr:	TCPIPLibs:netinet.h.in
o.ns_addr:	c.ns_addr
o.ns_addr:	TCPIPLibs:sys.h.param
o.ns_addr:	TCPIPLibs:sys.h.types
o.ns_addr:	TCPIPLibs:sys.h.cdefs
o.ns_addr:	TCPIPLibs:machine.h.endian
o.ns_addr:	TCPIPLibs:machine.h.ansi
o.ns_addr:	TCPIPLibs:machine.h.types
o.ns_addr:	TCPIPLibs:sys.h.syslimits
o.ns_addr:	TCPIPLibs:sys.h.signal
o.ns_addr:	TCPIPLibs:machine.h.signal
o.ns_addr:	TCPIPLibs:sys.h.cdefs
o.ns_addr:	TCPIPLibs:machine.h.param
o.ns_addr:	TCPIPLibs:machine.h.limits
o.ns_addr:	TCPIPLibs:netns.h.ns
o.ns_addr:	TCPIPLibs:sys.h.cdefs
o.ns_addr:	h.inetlib
o.ns_addr:	TCPIPLibs:sys.h.types
o.ns_addr:	TCPIPLibs:netinet.h.in
o.ns_ntoa:	c.ns_ntoa
o.ns_ntoa:	TCPIPLibs:sys.h.param
o.ns_ntoa:	TCPIPLibs:sys.h.types
o.ns_ntoa:	TCPIPLibs:sys.h.cdefs
o.ns_ntoa:	TCPIPLibs:machine.h.endian
o.ns_ntoa:	TCPIPLibs:machine.h.ansi
o.ns_ntoa:	TCPIPLibs:machine.h.types
o.ns_ntoa:	TCPIPLibs:sys.h.syslimits
o.ns_ntoa:	TCPIPLibs:sys.h.signal
o.ns_ntoa:	TCPIPLibs:machine.h.signal
o.ns_ntoa:	TCPIPLibs:sys.h.cdefs
o.ns_ntoa:	TCPIPLibs:machine.h.param
o.ns_ntoa:	TCPIPLibs:machine.h.limits
o.ns_ntoa:	TCPIPLibs:netns.h.ns
o.ns_ntoa:	TCPIPLibs:sys.h.cdefs
o.iso_addr:	c.iso_addr
o.iso_addr:	TCPIPLibs:sys.h.types
o.iso_addr:	TCPIPLibs:sys.h.cdefs
o.iso_addr:	TCPIPLibs:machine.h.endian
o.iso_addr:	TCPIPLibs:machine.h.ansi
o.iso_addr:	TCPIPLibs:machine.h.types
o.iso_addr:	TCPIPLibs:netiso.h.iso
o.iso_addr:	TCPIPLibs:netinet.h.in
o.iso_addr:	TCPIPLibs:sys.h.cdefs
o.iso_addr:	h.inetlib
o.iso_addr:	TCPIPLibs:sys.h.types
o.iso_addr:	TCPIPLibs:netinet.h.in
o.sysctlbyna:	c.sysctlbyna
o.sysctlbyna:	TCPIPLibs:sys.h.types
o.sysctlbyna:	TCPIPLibs:sys.h.cdefs
o.sysctlbyna:	TCPIPLibs:machine.h.endian
o.sysctlbyna:	TCPIPLibs:machine.h.ansi
o.sysctlbyna:	TCPIPLibs:machine.h.types
o.sysctlbyna:	TCPIPLibs:sys.h.sysctl
o.sysctlbyna:	TCPIPLibs:sys.h._posix
o.sysctlbyna:	TCPIPLibs:sys.h.cdefs
o.sysctlbyna:	h.inetlib
o.sysctlbyna:	TCPIPLibs:sys.h.types
o.sysctlbyna:	TCPIPLibs:netinet.h.in
o.inet_nntop:	c.inet_nntop
o.inet_nntop:	TCPIPLibs:sys.h.types
o.inet_nntop:	TCPIPLibs:sys.h.cdefs
o.inet_nntop:	TCPIPLibs:machine.h.endian
o.inet_nntop:	TCPIPLibs:machine.h.ansi
o.inet_nntop:	TCPIPLibs:machine.h.types
o.inet_nntop:	TCPIPLibs:sys.h.socket
o.inet_nntop:	TCPIPLibs:sys.h.cdefs
o.inet_nntop:	TCPIPLibs:netinet.h.in
o.inet_nntop:	TCPIPLibs:arpa.h.inet
o.inet_nntop:	TCPIPLibs:sys.h.cdefs
o.inet_nntop:	TCPIPLibs:sys.h.errno
o.inet_nntop:	C:h.kernel
o.inet_nntop:	h.inetlib
o.inet_nntop:	TCPIPLibs:sys.h.types
o.inet_nntop:	TCPIPLibs:netinet.h.in
o.inet_npton:	c.inet_npton
o.inet_npton:	TCPIPLibs:sys.h.types
o.inet_npton:	TCPIPLibs:sys.h.cdefs
o.inet_npton:	TCPIPLibs:machine.h.endian
o.inet_npton:	TCPIPLibs:machine.h.ansi
o.inet_npton:	TCPIPLibs:machine.h.types
o.inet_npton:	TCPIPLibs:sys.h.socket
o.inet_npton:	TCPIPLibs:sys.h.cdefs
o.inet_npton:	TCPIPLibs:netinet.h.in
o.inet_npton:	TCPIPLibs:arpa.h.inet
o.inet_npton:	TCPIPLibs:sys.h.cdefs
o.inet_npton:	TCPIPLibs:sys.h.errno
o.inet_npton:	C:h.kernel
o.inet_npton:	h.inetlib
o.inet_npton:	TCPIPLibs:sys.h.types
o.inet_npton:	TCPIPLibs:netinet.h.in
o.inet_ntop:	c.inet_ntop
o.inet_ntop:	TCPIPLibs:sys.h.param
o.inet_ntop:	TCPIPLibs:sys.h.types
o.inet_ntop:	TCPIPLibs:sys.h.cdefs
o.inet_ntop:	TCPIPLibs:machine.h.endian
o.inet_ntop:	TCPIPLibs:machine.h.ansi
o.inet_ntop:	TCPIPLibs:machine.h.types
o.inet_ntop:	TCPIPLibs:sys.h.syslimits
o.inet_ntop:	TCPIPLibs:sys.h.signal
o.inet_ntop:	TCPIPLibs:machine.h.signal
o.inet_ntop:	TCPIPLibs:sys.h.cdefs
o.inet_ntop:	TCPIPLibs:machine.h.param
o.inet_ntop:	TCPIPLibs:machine.h.limits
o.inet_ntop:	TCPIPLibs:sys.h.types
o.inet_ntop:	TCPIPLibs:sys.h.socket
o.inet_ntop:	TCPIPLibs:sys.h.cdefs
o.inet_ntop:	TCPIPLibs:netinet.h.in
o.inet_ntop:	TCPIPLibs:arpa.h.inet
o.inet_ntop:	TCPIPLibs:sys.h.cdefs
o.inet_ntop:	TCPIPLibs:arpa.h.nameser
o.inet_ntop:	TCPIPLibs:sys.h.param
o.inet_ntop:	TCPIPLibs:sys.h.types
o.inet_ntop:	TCPIPLibs:sys.h.cdefs
o.inet_ntop:	TCPIPLibs:machine.h.endian
o.inet_ntop:	TCPIPLibs:sys.h.errno
o.inet_ntop:	C:h.kernel
o.inet_ntop:	h.inetlib
o.inet_ntop:	TCPIPLibs:sys.h.types
o.inet_ntop:	TCPIPLibs:netinet.h.in
o.inet_pton:	c.inet_pton
o.inet_pton:	TCPIPLibs:sys.h.param
o.inet_pton:	TCPIPLibs:sys.h.types
o.inet_pton:	TCPIPLibs:sys.h.cdefs
o.inet_pton:	TCPIPLibs:machine.h.endian
o.inet_pton:	TCPIPLibs:machine.h.ansi
o.inet_pton:	TCPIPLibs:machine.h.types
o.inet_pton:	TCPIPLibs:sys.h.syslimits
o.inet_pton:	TCPIPLibs:sys.h.signal
o.inet_pton:	TCPIPLibs:machine.h.signal
o.inet_pton:	TCPIPLibs:sys.h.cdefs
o.inet_pton:	TCPIPLibs:machine.h.param
o.inet_pton:	TCPIPLibs:machine.h.limits
o.inet_pton:	TCPIPLibs:sys.h.types
o.inet_pton:	TCPIPLibs:sys.h.socket
o.inet_pton:	TCPIPLibs:sys.h.cdefs
o.inet_pton:	TCPIPLibs:netinet.h.in
o.inet_pton:	TCPIPLibs:arpa.h.inet
o.inet_pton:	TCPIPLibs:sys.h.cdefs
o.inet_pton:	TCPIPLibs:arpa.h.nameser
o.inet_pton:	TCPIPLibs:sys.h.param
o.inet_pton:	TCPIPLibs:sys.h.types
o.inet_pton:	TCPIPLibs:sys.h.cdefs
o.inet_pton:	TCPIPLibs:machine.h.endian
o.inet_pton:	TCPIPLibs:sys.h.errno
o.inet_pton:	C:h.kernel
o.inet_pton:	h.inetlib
o.inet_pton:	TCPIPLibs:sys.h.types
o.inet_pton:	TCPIPLibs:netinet.h.in
