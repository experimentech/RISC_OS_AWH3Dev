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

TARGET=         Ping


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
o.Ping:	c.Ping
o.Ping:	TCPIPLibs:sys.h.param
o.Ping:	TCPIPLibs:sys.h.types
o.Ping:	TCPIPLibs:sys.h.cdefs
o.Ping:	TCPIPLibs:machine.h.endian
o.Ping:	TCPIPLibs:machine.h.ansi
o.Ping:	TCPIPLibs:machine.h.types
o.Ping:	TCPIPLibs:sys.h.syslimits
o.Ping:	TCPIPLibs:sys.h.signal
o.Ping:	TCPIPLibs:machine.h.signal
o.Ping:	TCPIPLibs:sys.h.cdefs
o.Ping:	TCPIPLibs:machine.h.param
o.Ping:	TCPIPLibs:machine.h.limits
o.Ping:	TCPIPLibs:sys.h.socket
o.Ping:	TCPIPLibs:sys.h.cdefs
o.Ping:	TCPIPLibs:sys.h.file
o.Ping:	TCPIPLibs:sys.h.fcntl
o.Ping:	TCPIPLibs:sys.h.types
o.Ping:	TCPIPLibs:sys.h.cdefs
o.Ping:	TCPIPLibs:sys.h.unistd
o.Ping:	TCPIPLibs:sys.h._posix
o.Ping:	TCPIPLibs:sys.h.time
o.Ping:	TCPIPLibs:sys.h.cdefs
o.Ping:	TCPIPLibs:sys.h.signal
o.Ping:	TCPIPLibs:sys.h.ioctl
o.Ping:	TCPIPLibs:sys.h.ttycom
o.Ping:	TCPIPLibs:sys.h.ioccom
o.Ping:	TCPIPLibs:sys.h.ioccom
o.Ping:	TCPIPLibs:sys.h.filio
o.Ping:	TCPIPLibs:sys.h.ioccom
o.Ping:	TCPIPLibs:sys.h.sockio
o.Ping:	TCPIPLibs:sys.h.ioccom
o.Ping:	TCPIPLibs:sys.h.cdefs
o.Ping:	TCPIPLibs:netinet.h.in_systm
o.Ping:	TCPIPLibs:netinet.h.in
o.Ping:	TCPIPLibs:netinet.h.ip
o.Ping:	TCPIPLibs:netinet.h.ip_icmp
o.Ping:	TCPIPLibs:netinet.h.ip_var
o.Ping:	TCPIPLibs:arpa.h.inet
o.Ping:	TCPIPLibs:sys.h.cdefs
o.Ping:	TCPIPLibs:h.netdb
o.Ping:	TCPIPLibs:sys.h.cdefs
o.Ping:	TCPIPLibs:h.unistd
o.Ping:	TCPIPLibs:sys.h.cdefs
o.Ping:	TCPIPLibs:sys.h.types
o.Ping:	TCPIPLibs:sys.h.unistd
o.Ping:	TCPIPLibs:sys.h.errno
o.Ping:	C:h.kernel
o.Ping:	TCPIPLibs:h.riscos
o.Ping:	TCPIPLibs:h.unixlib
