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

TARGET=         ARP


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
o.ARP:	c.ARP
o.ARP:	TCPIPLibs:sys.h.param
o.ARP:	TCPIPLibs:sys.h.types
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:machine.h.endian
o.ARP:	TCPIPLibs:machine.h.ansi
o.ARP:	TCPIPLibs:machine.h.types
o.ARP:	TCPIPLibs:sys.h.syslimits
o.ARP:	TCPIPLibs:sys.h.signal
o.ARP:	TCPIPLibs:machine.h.signal
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:machine.h.param
o.ARP:	TCPIPLibs:machine.h.limits
o.ARP:	TCPIPLibs:sys.h.file
o.ARP:	TCPIPLibs:sys.h.fcntl
o.ARP:	TCPIPLibs:sys.h.types
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:sys.h.unistd
o.ARP:	TCPIPLibs:sys.h._posix
o.ARP:	TCPIPLibs:sys.h.socket
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:sys.h.sysctl
o.ARP:	TCPIPLibs:sys.h._posix
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:net.h.if
o.ARP:	TCPIPLibs:sys.h.time
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:net.h.if_dl
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:net.h.if_types
o.ARP:	TCPIPLibs:net.h.route
o.ARP:	TCPIPLibs:net.h.radix
o.ARP:	TCPIPLibs:netinet.h.in
o.ARP:	TCPIPLibs:netinet.h.if_ether
o.ARP:	TCPIPLibs:net.h.ethernet
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:net.h.if_arp
o.ARP:	TCPIPLibs:sys.h.socket
o.ARP:	TCPIPLibs:arpa.h.inet
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:h.netdb
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:sys.h.errno
o.ARP:	C:h.kernel
o.ARP:	TCPIPLibs:h.unixlib
o.ARP:	TCPIPLibs:h.riscos
o.ARP:	TCPIPLibs:h.socklib
o.ARP:	TCPIPLibs:sys.h.types
o.ARP:	TCPIPLibs:sys.h.socket
o.ARP:	TCPIPLibs:sys.h.stat
o.ARP:	TCPIPLibs:sys.h.time
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	TCPIPLibs:sys.h.time
o.ARP:	TCPIPLibs:sys.h.uio
o.ARP:	TCPIPLibs:sys.h.cdefs
o.ARP:	C:h.kernel
o.ARP:	TCPIPLibs:h.nlist
o.ARP:	TCPIPLibs:sys.h.cdefs
