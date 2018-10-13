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

TARGET=         IfConfig


INCLUDES=	C:,TCPIPLibs:
CC=		cc
RM=             remove
WFLAGS=         fr~c~v
WIPE=           x wipe

CFLAGS=		-wp -I$(INCLUDES) -c ${THROWBACK} -depend !Depend

OBJS=		o.${TARGET}

LIBS=		C:o.Stubs TCPIPLibs:o.Unixlib TCPIPLibs:o.Inetlib \
		TCPIPLibs:o.Socklib5

.SUFFIXES:	.c .o
.c.o:;		$(CC) $(CFLAGS) -o $@ $<

${TARGET}:	$(OBJS) $(LIBS)
		Link -o $@ $(OBJS) $(LIBS)
		Squeeze $@

clean:;		${RM} ${TARGET}
		IfThere o.* Then ${WIPE} o.* ${WFLAGS}
	
# Dynamic dependencies:
o.IfConfig:	c.IfConfig
o.IfConfig:	TCPIPLibs:sys.h.param
o.IfConfig:	TCPIPLibs:sys.h.types
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:machine.h.endian
o.IfConfig:	TCPIPLibs:machine.h.ansi
o.IfConfig:	TCPIPLibs:machine.h.types
o.IfConfig:	TCPIPLibs:sys.h.syslimits
o.IfConfig:	TCPIPLibs:sys.h.signal
o.IfConfig:	TCPIPLibs:machine.h.signal
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:machine.h.param
o.IfConfig:	TCPIPLibs:machine.h.limits
o.IfConfig:	TCPIPLibs:sys.h.socket
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:sys.h.ioctl
o.IfConfig:	TCPIPLibs:sys.h.ttycom
o.IfConfig:	TCPIPLibs:sys.h.ioccom
o.IfConfig:	TCPIPLibs:sys.h.ioccom
o.IfConfig:	TCPIPLibs:sys.h.filio
o.IfConfig:	TCPIPLibs:sys.h.ioccom
o.IfConfig:	TCPIPLibs:sys.h.sockio
o.IfConfig:	TCPIPLibs:sys.h.ioccom
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:net.h.if
o.IfConfig:	TCPIPLibs:sys.h.time
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:net.h.if_var
o.IfConfig:	TCPIPLibs:sys.h.queue
o.IfConfig:	TCPIPLibs:net.h.if_dl
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:netinet.h.in
o.IfConfig:	TCPIPLibs:netinet.h.in_var
o.IfConfig:	TCPIPLibs:sys.h.queue
o.IfConfig:	TCPIPLibs:arpa.h.inet
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:netns.h.ns
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:netns.h.ns_if
o.IfConfig:	TCPIPLibs:h.netdb
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:netiso.h.iso
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:netiso.h.iso_var
o.IfConfig:	TCPIPLibs:sys.h.protosw
o.IfConfig:	TCPIPLibs:h.err
o.IfConfig:	TCPIPLibs:machine.h.ansi
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:sys.h.errno
o.IfConfig:	C:h.kernel
o.IfConfig:	TCPIPLibs:h.unistd
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:sys.h.types
o.IfConfig:	TCPIPLibs:sys.h.unistd
o.IfConfig:	TCPIPLibs:sys.h._posix
o.IfConfig:	TCPIPLibs:h.nlist
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:h.kvm
o.IfConfig:	TCPIPLibs:h.nlist
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:sys.h.fcntl
o.IfConfig:	TCPIPLibs:sys.h.types
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:h.riscos
o.IfConfig:	C:h.swis
o.IfConfig:	TCPIPLibs:h.socklib
o.IfConfig:	TCPIPLibs:sys.h.types
o.IfConfig:	TCPIPLibs:sys.h.socket
o.IfConfig:	TCPIPLibs:sys.h.stat
o.IfConfig:	TCPIPLibs:sys.h.time
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	TCPIPLibs:sys.h.time
o.IfConfig:	TCPIPLibs:sys.h.uio
o.IfConfig:	TCPIPLibs:sys.h.cdefs
o.IfConfig:	C:h.kernel
o.IfConfig:	TCPIPLibs:h.unixlib
