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
# Copyright (c) 1995 Acorn Computers Ltd., Cambridge, England
#
# Makefile for socklib.a
#

include StdTools

COMPONENT=	socklib
LIBDIR=		<Lib$Dir>
INCLUDES=	TCPIPLibs:,C:
DIRS=		o._dirs

CFLAGS=		-depend !Depend ${THROWBACK} -pcc -zps0 -I${INCLUDES} -fah -Fn -DINET
CFLAGSZM=	-depend !Depend ${THROWBACK} -pcc -zps1 -I${INCLUDES} -ffah -DINET -zM
ASFLAGS=	-depend !Depend ${THROWBACK}
ASFLAGSZM=	-depend !Depend ${THROWBACK} -predefine "module SETL {TRUE}"

OFILES4=	accept.o bind.o connect.o copyerror.o getpeernam.o \
		getsocknam.o getsockopt.o getstabsiz.o listen.o makecall.o \
		recv.o recvfrom.o recvmsg.o select.o send.o sendmsg.o \
		sendto.o setsockopt.o shutdown.o sockclose.o socket.o \
		socketstat.o sockioctl.o sockread.o sockreadv.o sockwrite.o \
		sockwritev.o sendtosm.o sysctl.o naccept.o nrecvfrom.o \
		nrecvmsg.o nsendmsg.o ngetpeerna.o ngetsockna.o kvm_nlist.o \
		sockver.o _inet_err.o

ZFILES4=	z.accept z.bind z.connect z.copyerror z.getpeernam \
		z.getsocknam z.getsockopt z.getstabsiz z.listen z.makecall \
		z.recv z.recvfrom z.recvmsg z.select z.send z.sendmsg \
		z.sendto z.setsockopt z.shutdown z.sockclose z.socket \
		z.socketstat z.sockioctl z.sockread z.sockreadv z.sockwrite \
		z.sockwritev z.sendtosm z.sysctl z.naccept z.nrecvfrom \
		z.nrecvmsg z.nsendmsg z.ngetpeerna z.ngetsockna z.kvm_nlist \
		z.sockver z._inet_err

OFILES5=	accept5.o bind.o connect.o copyerror.o getpeerna5.o \
		getsockna5.o getsockopt.o getstabsiz.o listen.o makecall.o \
		recv5.o recvfrom5.o recvmsg5.o select.o send5.o sendmsg5.o \
		sendto.o setsockopt.o shutdown.o sockclose.o socket.o \
		socketstat.o sockioctl.o sockread.o sockreadv.o sockwrite.o \
		sockwritev.o sendtosm.o sysctl.o \
		oaccept.o ogetpeerna.o ogetsockna.o orecvmsg.o osendmsg.o \
		orecvfrom.o kvm_nlist.o sockver.o _inet_err.o

ZFILES5=	z.accept5 z.bind z.connect z.copyerror z.getpeerna5 \
		z.getsockna5 z.getsockopt z.getstabsiz z.listen z.makecall \
		z.recv5 z.recvfrom5 z.recvmsg5 z.select z.send5 z.sendmsg5 \
		z.sendto z.setsockopt z.shutdown z.sockclose z.socket \
		z.socketstat z.sockioctl z.sockread z.sockreadv z.sockwrite \
		z.sockwritev z.sendtosm z.sysctl \
		z.oaccept z.ogetpeerna z.ogetsockna z.orecvmsg z.osendmsg \
		z.orecvfrom z.kvm_nlist z.sockver z._inet_err

.SUFFIXES:	.z .o .s .sz .sn .c

.c.z:;		${CC} ${CFLAGSZM} -c -o $@ $<
.c.o:;		${CC} ${CFLAGS} -c -o $@ $<
.s.z:;		${AS} ${ASFLAGSZM} $< $@
.sz.z:;		${AS} ${ASFLAGSZM} $< $@
.s.o:;		${AS} ${ASFLAGS} $< $@
.sn.o:;		${AS} ${ASFLAGS} $< $@

all:		veneers socklib socklibzm socklib5 socklib5zm

${OFILES4}:	veneers
${ZFILES4}:	veneers
${OFILES5}:	veneers
${ZFILES5}:	veneers

socklib: ${OFILES4} ${DIRS}
	${AR} -c socklib ${OFILES4}
	${AR} -o socklib

socklibzm: ${ZFILES4} ${DIRS}
	${AR} -c socklibzm ${ZFILES4}
	${AR} -o socklibzm

socklib5: ${OFILES5} ${DIRS}
	${AR} -c socklib5 ${OFILES5}
	${AR} -o socklib5

socklib5zm: ${ZFILES5} ${DIRS}
	${AR} -c socklib5zm ${ZFILES5}
	${AR} -o socklib5zm

veneers: mkveneers Prototypes
	${PERL}  mkveneers Prototypes
	${TOUCH} veneers

export: export_${PHASE}

export_hdrs:
	${CP} h.socklib TCPIPLibs:h.socklib ${CPFLAGS}
	@${ECHO} ${COMPONENT}: header export complete

export_libs: socklib socklibzm socklib5 socklib5zm
	${MKDIR} ${LIBDIR}
	${MKDIR} ${LIBDIR}.TCPIPLibs
	${MKDIR} ${LIBDIR}.TCPIPLibs.o
	${CP} socklib	 TCPIPLibs:o.socklib	${CPFLAGS}
	${CP} socklibzm	 TCPIPLibs:o.socklibzm	${CPFLAGS}
	${CP} socklib5	 TCPIPLibs:o.socklib5	${CPFLAGS}
	${CP} socklib5zm TCPIPLibs:o.socklib5zm	${CPFLAGS}
	@${ECHO} ${COMPONENT}: library export complete

o._dirs:
	${MKDIR} o
	${MKDIR} z
	${MKDIR} sn
	${MKDIR} sz
	${TOUCH} $@

clean:
	${WIPE} o  ${WFLAGS}
	${WIPE} z  ${WFLAGS}
	${WIPE} sn ${WFLAGS}
	${WIPE} sz ${WFLAGS}
	${RM} veneers
	${RM} socklib
	${RM} socklibzm
	${RM} socklib5
	${RM} socklib5zm

# Dynamic dependencies:
o.accept: sn.accept
o.accept: hdr.InetSWIs
o.getpeernam: sn.getpeernam
o.getpeernam: hdr.InetSWIs
o.getsocknam: sn.getsocknam
o.getsocknam: hdr.InetSWIs
o.recv: sn.recv
o.recv: hdr.InetSWIs
o.recvfrom: sn.recvfrom
o.recvfrom: hdr.InetSWIs
o.recvmsg: sn.recvmsg
o.recvmsg: hdr.InetSWIs
o.send: sn.send
o.send: hdr.InetSWIs
o.sendmsg: sn.sendmsg
o.sendmsg: hdr.InetSWIs
o.naccept: sn.naccept
o.naccept: hdr.InetSWIs
o.nrecvfrom: sn.nrecvfrom
o.nrecvfrom: hdr.InetSWIs
o.nrecvmsg: sn.nrecvmsg
o.nrecvmsg: hdr.InetSWIs
o.nsendmsg: sn.nsendmsg
o.nsendmsg: hdr.InetSWIs
o.ngetpeerna: sn.ngetpeerna
o.ngetpeerna: hdr.InetSWIs
o.ngetsockna: sn.ngetsockna
o.ngetsockna: hdr.InetSWIs
o.accept5: sn.accept5
o.accept5: hdr.InetSWIs
o.bind: sn.bind
o.bind: hdr.InetSWIs
o.connect: sn.connect
o.connect: hdr.InetSWIs
o.copyerror: s.copyerror
o.getpeerna5: sn.getpeerna5
o.getpeerna5: hdr.InetSWIs
o.getsockna5: sn.getsockna5
o.getsockna5: hdr.InetSWIs
o.getsockopt: sn.getsockopt
o.getsockopt: hdr.InetSWIs
o.getstabsiz: sn.getstabsiz
o.getstabsiz: hdr.InetSWIs
o.listen: sn.listen
o.listen: hdr.InetSWIs
o.makecall: s.makecall
o.makecall: Hdr:ListOpts
o.makecall: Hdr:Macros
o.makecall: Hdr:System
o.makecall: Hdr:SWIs
o.makecall: Hdr:CPU.Arch
o.makecall: Hdr:Machine.<Machine>
o.makecall: Hdr:Machine.Machine
o.makecall: Hdr:CPU.Generic26
o.makecall: Hdr:CPU.Generic32
o.makecall: Hdr:IO.GenericIO
o.makecall: Hdr:RISCOS
o.makecall: Hdr:Machine.<Machine>
o.makecall: Hdr:Machine.Machine
o.makecall: Hdr:APCS.<APCS>
o.makecall: Hdr:APCS.Common
o.recv5:	c.recv5
o.recv5:	TCPIPLibs:sys.h.types
o.recv5:	TCPIPLibs:sys.h.cdefs
o.recv5:	TCPIPLibs:machine.h.endian
o.recv5:	TCPIPLibs:machine.h.ansi
o.recv5:	TCPIPLibs:machine.h.types
o.recv5:	TCPIPLibs:sys.h.socket
o.recv5:	TCPIPLibs:sys.h.cdefs
o.recv5:	h.socklib
o.recv5:	TCPIPLibs:sys.h.types
o.recv5:	TCPIPLibs:sys.h.socket
o.recv5:	TCPIPLibs:sys.h.stat
o.recv5:	TCPIPLibs:sys.h.time
o.recv5:	TCPIPLibs:sys.h.cdefs
o.recv5:	TCPIPLibs:sys.h.cdefs
o.recv5:	TCPIPLibs:sys.h.time
o.recv5:	TCPIPLibs:sys.h.uio
o.recv5:	TCPIPLibs:sys.h.cdefs
o.recv5:	C:h.kernel
o.recvfrom5: sn.recvfrom5
o.recvfrom5: hdr.InetSWIs
o.recvmsg5: sn.recvmsg5
o.recvmsg5: hdr.InetSWIs
o.select: sn.select
o.select: hdr.InetSWIs
o.send5:	c.send5
o.send5:	TCPIPLibs:sys.h.types
o.send5:	TCPIPLibs:sys.h.cdefs
o.send5:	TCPIPLibs:machine.h.endian
o.send5:	TCPIPLibs:machine.h.ansi
o.send5:	TCPIPLibs:machine.h.types
o.send5:	TCPIPLibs:sys.h.socket
o.send5:	TCPIPLibs:sys.h.cdefs
o.send5:	h.socklib
o.send5:	TCPIPLibs:sys.h.types
o.send5:	TCPIPLibs:sys.h.socket
o.send5:	TCPIPLibs:sys.h.stat
o.send5:	TCPIPLibs:sys.h.time
o.send5:	TCPIPLibs:sys.h.cdefs
o.send5:	TCPIPLibs:sys.h.cdefs
o.send5:	TCPIPLibs:sys.h.time
o.send5:	TCPIPLibs:sys.h.uio
o.send5:	TCPIPLibs:sys.h.cdefs
o.send5:	C:h.kernel
o.sendmsg5: sn.sendmsg5
o.sendmsg5: hdr.InetSWIs
o.sendto: sn.sendto
o.sendto: hdr.InetSWIs
o.setsockopt: sn.setsockopt
o.setsockopt: hdr.InetSWIs
o.shutdown: sn.shutdown
o.shutdown: hdr.InetSWIs
o.sockclose: sn.sockclose
o.sockclose: hdr.InetSWIs
o.socket: sn.socket
o.socket: hdr.InetSWIs
o.socketstat: sn.socketstat
o.socketstat: hdr.InetSWIs
o.sockioctl: sn.sockioctl
o.sockioctl: hdr.InetSWIs
o.sockread: sn.sockread
o.sockread: hdr.InetSWIs
o.sockreadv: sn.sockreadv
o.sockreadv: hdr.InetSWIs
o.sockwrite: sn.sockwrite
o.sockwrite: hdr.InetSWIs
o.sockwritev: sn.sockwritev
o.sockwritev: hdr.InetSWIs
o.sendtosm: sn.sendtosm
o.sendtosm: hdr.InetSWIs
o.sysctl: sn.sysctl
o.sysctl: hdr.InetSWIs
o.oaccept: sn.oaccept
o.oaccept: hdr.InetSWIs
o.ogetpeerna: sn.ogetpeerna
o.ogetpeerna: hdr.InetSWIs
o.ogetsockna: sn.ogetsockna
o.ogetsockna: hdr.InetSWIs
o.orecvmsg: sn.orecvmsg
o.orecvmsg: hdr.InetSWIs
o.osendmsg: sn.osendmsg
o.osendmsg: hdr.InetSWIs
o.orecvfrom: sn.orecvfrom
o.orecvfrom: hdr.InetSWIs
o.kvm_nlist: sn.kvm_nlist
o.kvm_nlist: hdr.InetSWIs
o.sockver: sn.sockver
o.sockver: hdr.InetSWIs
o._inet_err:	c._inet_err
o._inet_err:	TCPIPLibs:h.errno
o._inet_err:	TCPIPLibs:sys.h.errno
o._inet_err:	C:h.kernel
