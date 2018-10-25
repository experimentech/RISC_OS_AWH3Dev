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
# Makefile for unixlib.a
#
# Makefile,v
# Revision 1.1  95/04/20  09:50:39  kwelton
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

CFLAGS=		-depend !Depend -Wp -zps0 -I${INCLUDES} -fah -Fn -DINET -DCOMPAT_INET4
CFLAGSZM=	-depend !Depend -Wp -zps1 -I${INCLUDES} -ffah -DINET -DCOMPAT_INET4 -zM

AFLAGS=		-depend !Depend
AFLAGSZM=	-depend !Depend -PD "module SETL {TRUE}"

CCZM=		${CC} ${CFLAGSZM}
ASZM=		${AS} ${AFLAGSZM}

CFILES=		access.c chdir.c chmod.c close.c filestat.c flushinput.c \
		fstat.c getdtabsiz.c getegid.c geteuid.c getgroups.c \
		gethostnam.c getlogin.c getpass.c getpid.c getpwent.c \
		getpwnam.c getpwuid.c getuid.c getusernam.c getwd.c \
		gtimeofday.c herror.c index.c ioctl.c killfile.c lseek.c \
		memops.c osreadc.c read.c readdir.c readv.c strcasecmp.c \
		stubs.c write.c writev.c xgets.c xperror.c xputchar.c \
		getopt.c strsep.c kvm.c err.c errlst.c xstrerror.c \
		strdup.c sleep.c ffs.c getifaddrs.c asm.s

OFILES=		access.o chdir.o chmod.o close.o filestat.o flushinput.o \
		fstat.o getdtabsiz.o getegid.o geteuid.o getgroups.o \
		gethostnam.o getlogin.o getpass.o getpid.o getpwent.o \
		getpwnam.o getpwuid.o getuid.o getusernam.o getwd.o \
		gtimeofday.o herror.o index.o ioctl.o killfile.o lseek.o \
		memops.o osreadc.o read.o readdir.o readv.o strcasecmp.o \
		stubs.o write.o writev.o xgets.o xperror.o xputchar.o \
		getopt.o strsep.o kvm.o err.o errlst.o xstrerror.o \
		strdup.o sleep.o ffs.o getifaddrs.o asm.o

ZFILES=		z.access z.chdir z.chmod z.close z.filestat z.flushinput \
		z.fstat z.getdtabsiz z.getegid z.geteuid z.getgroups \
		z.gethostnam z.getlogin z.getpass z.getpid z.getpwent \
		z.getpwnam z.getpwuid z.getuid z.getusernam z.getwd \
		z.gtimeofday z.herror z.index z.ioctl z.killfile z.lseek \
		z.memops z.osreadc z.read z.readdir z.readv z.strcasecmp \
		z.stubs z.write z.writev z.xgets z.xperror z.xputchar \
		z.getopt z.strsep z.kvm z.err z.errlst z.xstrerror \
		z.strdup z.sleep z.ffs z.getifaddrs z.asm

.SUFFIXES:	.z .o .c .s

.c.z:;	     ${CCZM} -c -o $@ $<
.c.o:;       ${CC} ${CFLAGS} -c -o $@ $<
.s.z:;       ${ASZM} -o $@ $<
.s.o:;       ${AS} ${AFLAGS} -o $@ $<

COMPONENT = unixlib
LIBDIR = <Lib$Dir>

all:	unixlib unixlibzm

unixlib:	${OFILES} local_dirs
	${LIB} -c unixlib ${OFILES}
	${LIB} -o unixlib

unixlibzm:	${ZFILES} local_dirs
	${LIB} -c unixlibzm ${ZFILES}
	${LIB} -o unixlibzm

export: export_${PHASE}

export_hdrs:
	${CP} h.unixlib	TCPIPLibs:h.unixlib	${CPFLAGS}
        @echo ${COMPONENT}: export complete (hdrs)

export_libs: unixlib unixlibzm dirs
	${CP} unixlib	TCPIPLibs:o.unixlib	${CPFLAGS}
	${CP} unixlibzm	TCPIPLibs:o.unixlibzm	${CPFLAGS}

dirs:
	${MKDIR} $(LIBDIR)
	${MKDIR} $(LIBDIR).TCPIPLibs
	${MKDIR} $(LIBDIR).TCPIPLibs.o

local_dirs:
        ${MKDIR} o
        ${MKDIR} z
        Create local_dirs

clean:
	${WIPE} o.* ${WFLAGS}
	${WIPE} z.* ${WFLAGS}
	${RM} local_dirs
	${RM} unixlib
	${RM} unixlibzm


# Dynamic dependencies:
o.access:	c.access
o.access:	TCPIPLibs:h.errno
o.access:	TCPIPLibs:sys.h.errno
o.access:	C:h.kernel
o.access:	C:h.kernel
o.access:	C:h.swis
o.access:	TCPIPLibs:h.unistd
o.access:	TCPIPLibs:sys.h.cdefs
o.access:	TCPIPLibs:sys.h.types
o.access:	TCPIPLibs:sys.h.cdefs
o.access:	TCPIPLibs:machine.h.endian
o.access:	TCPIPLibs:machine.h.ansi
o.access:	TCPIPLibs:machine.h.types
o.access:	TCPIPLibs:sys.h.unistd
o.access:	TCPIPLibs:sys.h._posix
o.access:	h.unixlib
o.chdir:	c.chdir
o.chdir:	C:h.kernel
o.chdir:	C:h.swis
o.chdir:	h.unixlib
o.chmod:	c.chmod
o.chmod:	TCPIPLibs:h.errno
o.chmod:	TCPIPLibs:sys.h.errno
o.chmod:	C:h.kernel
o.chmod:	C:h.kernel
o.chmod:	C:h.swis
o.chmod:	h.unixlib
o.close:	c.close
o.close:	h.unixlib
o.close:	TCPIPLibs:h.socklib
o.close:	TCPIPLibs:sys.h.types
o.close:	TCPIPLibs:sys.h.cdefs
o.close:	TCPIPLibs:machine.h.endian
o.close:	TCPIPLibs:machine.h.ansi
o.close:	TCPIPLibs:machine.h.types
o.close:	TCPIPLibs:sys.h.socket
o.close:	TCPIPLibs:sys.h.cdefs
o.close:	TCPIPLibs:sys.h.stat
o.close:	TCPIPLibs:sys.h.time
o.close:	TCPIPLibs:sys.h.cdefs
o.close:	TCPIPLibs:sys.h.cdefs
o.close:	TCPIPLibs:sys.h.time
o.close:	TCPIPLibs:sys.h.uio
o.close:	TCPIPLibs:sys.h.cdefs
o.close:	C:h.kernel
o.filestat:	c.filestat
o.filestat:	TCPIPLibs:h.errno
o.filestat:	TCPIPLibs:sys.h.errno
o.filestat:	C:h.kernel
o.filestat:	C:h.kernel
o.filestat:	C:h.swis
o.filestat:	h.unixlib
o.flushinput:	c.flushinput
o.flushinput:	C:h.kernel
o.flushinput:	C:h.swis
o.flushinput:	h.unixlib
o.fstat:	c.fstat
o.fstat:	h.unixlib
o.fstat:	TCPIPLibs:h.socklib
o.fstat:	TCPIPLibs:sys.h.types
o.fstat:	TCPIPLibs:sys.h.cdefs
o.fstat:	TCPIPLibs:machine.h.endian
o.fstat:	TCPIPLibs:machine.h.ansi
o.fstat:	TCPIPLibs:machine.h.types
o.fstat:	TCPIPLibs:sys.h.socket
o.fstat:	TCPIPLibs:sys.h.cdefs
o.fstat:	TCPIPLibs:sys.h.stat
o.fstat:	TCPIPLibs:sys.h.time
o.fstat:	TCPIPLibs:sys.h.cdefs
o.fstat:	TCPIPLibs:sys.h.cdefs
o.fstat:	TCPIPLibs:sys.h.time
o.fstat:	TCPIPLibs:sys.h.uio
o.fstat:	TCPIPLibs:sys.h.cdefs
o.fstat:	C:h.kernel
o.getdtabsiz:	c.getdtabsiz
o.getdtabsiz:	h.unixlib
o.getdtabsiz:	TCPIPLibs:h.socklib
o.getdtabsiz:	TCPIPLibs:sys.h.types
o.getdtabsiz:	TCPIPLibs:sys.h.cdefs
o.getdtabsiz:	TCPIPLibs:machine.h.endian
o.getdtabsiz:	TCPIPLibs:machine.h.ansi
o.getdtabsiz:	TCPIPLibs:machine.h.types
o.getdtabsiz:	TCPIPLibs:sys.h.socket
o.getdtabsiz:	TCPIPLibs:sys.h.cdefs
o.getdtabsiz:	TCPIPLibs:sys.h.stat
o.getdtabsiz:	TCPIPLibs:sys.h.time
o.getdtabsiz:	TCPIPLibs:sys.h.cdefs
o.getdtabsiz:	TCPIPLibs:sys.h.cdefs
o.getdtabsiz:	TCPIPLibs:sys.h.time
o.getdtabsiz:	TCPIPLibs:sys.h.uio
o.getdtabsiz:	TCPIPLibs:sys.h.cdefs
o.getdtabsiz:	C:h.kernel
o.getegid:	c.getegid
o.getegid:	h.unixlib
o.getegid:	h.stubs
o.geteuid:	c.geteuid
o.geteuid:	h.unixlib
o.geteuid:	h.stubs
o.getgroups:	c.getgroups
o.getgroups:	h.unixlib
o.getgroups:	h.stubs
o.gethostnam:	c.gethostnam
o.gethostnam:	C:h.kernel
o.gethostnam:	C:h.swis
o.gethostnam:	h.unixlib
o.gethostnam:	h.stubs
o.getlogin:	c.getlogin
o.getlogin:	h.unixlib
o.getpass:	c.getpass
o.getpass:	h.unixlib
o.getpid:	c.getpid
o.getpid:	C:h.kernel
o.getpid:	C:h.swis
o.getpid:	h.unixlib
o.getpid:	h.stubs
o.getpwent:	c.getpwent
o.getpwent:	h.unixlib
o.getpwnam:	c.getpwnam
o.getpwnam:	TCPIPLibs:h.pwd
o.getpwnam:	TCPIPLibs:sys.h.types
o.getpwnam:	TCPIPLibs:sys.h.cdefs
o.getpwnam:	TCPIPLibs:machine.h.endian
o.getpwnam:	TCPIPLibs:machine.h.ansi
o.getpwnam:	TCPIPLibs:machine.h.types
o.getpwnam:	TCPIPLibs:sys.h.cdefs
o.getpwnam:	h.stubs
o.getpwnam:	h.unixlib
o.getpwuid:	c.getpwuid
o.getpwuid:	TCPIPLibs:h.pwd
o.getpwuid:	TCPIPLibs:sys.h.types
o.getpwuid:	TCPIPLibs:sys.h.cdefs
o.getpwuid:	TCPIPLibs:machine.h.endian
o.getpwuid:	TCPIPLibs:machine.h.ansi
o.getpwuid:	TCPIPLibs:machine.h.types
o.getpwuid:	TCPIPLibs:sys.h.cdefs
o.getpwuid:	h.unixlib
o.getpwuid:	h.stubs
o.getuid:	c.getuid
o.getuid:	h.unixlib
o.getuid:	h.stubs
o.getusernam:	c.getusernam
o.getusernam:	C:h.kernel
o.getusernam:	C:h.swis
o.getusernam:	h.unixlib
o.getusernam:	h.stubs
o.getwd:	c.getwd
o.getwd:	C:h.kernel
o.getwd:	C:h.swis
o.getwd:	h.unixlib
o.gtimeofday:	c.gtimeofday
o.gtimeofday:	TCPIPLibs:sys.h.time
o.gtimeofday:	TCPIPLibs:sys.h.cdefs
o.gtimeofday:	TCPIPLibs:sys.h.types
o.gtimeofday:	TCPIPLibs:sys.h.cdefs
o.gtimeofday:	TCPIPLibs:machine.h.endian
o.gtimeofday:	TCPIPLibs:machine.h.ansi
o.gtimeofday:	TCPIPLibs:machine.h.types
o.gtimeofday:	C:h.swis
o.gtimeofday:	C:h.kernel
o.gtimeofday:	C:Global.h.HalEntries
o.gtimeofday:	h.unixlib
o.gtimeofday:	h.asm
o.gtimeofday:	C:h.stdio
o.herror:	c.herror
o.herror:	h.unixlib
o.index:	c.index
o.index:	h.unixlib
o.ioctl:	c.ioctl
o.killfile:	c.killfile
o.killfile:	C:h.kernel
o.killfile:	C:h.swis
o.killfile:	h.unixlib
o.lseek:	c.lseek
o.lseek:	TCPIPLibs:h.errno
o.lseek:	TCPIPLibs:sys.h.errno
o.lseek:	C:h.kernel
o.lseek:	h.unixlib
o.memops:	c.memops
o.memops:	h.unixlib
o.osreadc:	c.osreadc
o.osreadc:	C:h.kernel
o.osreadc:	h.unixlib
o.read:	c.read
o.read:	h.unixlib
o.read:	TCPIPLibs:h.socklib
o.read:	TCPIPLibs:sys.h.types
o.read:	TCPIPLibs:sys.h.cdefs
o.read:	TCPIPLibs:machine.h.endian
o.read:	TCPIPLibs:machine.h.ansi
o.read:	TCPIPLibs:machine.h.types
o.read:	TCPIPLibs:sys.h.socket
o.read:	TCPIPLibs:sys.h.cdefs
o.read:	TCPIPLibs:sys.h.stat
o.read:	TCPIPLibs:sys.h.time
o.read:	TCPIPLibs:sys.h.cdefs
o.read:	TCPIPLibs:sys.h.cdefs
o.read:	TCPIPLibs:sys.h.time
o.read:	TCPIPLibs:sys.h.uio
o.read:	TCPIPLibs:sys.h.cdefs
o.read:	C:h.kernel
o.readdir:	c.readdir
o.readdir:	C:h.kernel
o.readdir:	C:h.swis
o.readdir:	h.unixlib
o.readv:	c.readv
o.readv:	TCPIPLibs:sys.h.types
o.readv:	TCPIPLibs:sys.h.cdefs
o.readv:	TCPIPLibs:machine.h.endian
o.readv:	TCPIPLibs:machine.h.ansi
o.readv:	TCPIPLibs:machine.h.types
o.readv:	TCPIPLibs:sys.h.uio
o.readv:	TCPIPLibs:sys.h.cdefs
o.readv:	h.unixlib
o.readv:	TCPIPLibs:h.socklib
o.readv:	TCPIPLibs:sys.h.types
o.readv:	TCPIPLibs:sys.h.socket
o.readv:	TCPIPLibs:sys.h.cdefs
o.readv:	TCPIPLibs:sys.h.stat
o.readv:	TCPIPLibs:sys.h.time
o.readv:	TCPIPLibs:sys.h.cdefs
o.readv:	TCPIPLibs:sys.h.cdefs
o.readv:	TCPIPLibs:sys.h.time
o.readv:	TCPIPLibs:sys.h.uio
o.readv:	C:h.kernel
o.strcasecmp:	c.strcasecmp
o.strcasecmp:	TCPIPLibs:sys.h.cdefs
o.strcasecmp:	h.unixlib
o.stubs:	c.stubs
o.stubs:	TCPIPLibs:h.pwd
o.stubs:	TCPIPLibs:sys.h.types
o.stubs:	TCPIPLibs:sys.h.cdefs
o.stubs:	TCPIPLibs:machine.h.endian
o.stubs:	TCPIPLibs:machine.h.ansi
o.stubs:	TCPIPLibs:machine.h.types
o.stubs:	TCPIPLibs:sys.h.cdefs
o.stubs:	h.stubs
o.write:	c.write
o.write:	h.unixlib
o.write:	TCPIPLibs:h.socklib
o.write:	TCPIPLibs:sys.h.types
o.write:	TCPIPLibs:sys.h.cdefs
o.write:	TCPIPLibs:machine.h.endian
o.write:	TCPIPLibs:machine.h.ansi
o.write:	TCPIPLibs:machine.h.types
o.write:	TCPIPLibs:sys.h.socket
o.write:	TCPIPLibs:sys.h.cdefs
o.write:	TCPIPLibs:sys.h.stat
o.write:	TCPIPLibs:sys.h.time
o.write:	TCPIPLibs:sys.h.cdefs
o.write:	TCPIPLibs:sys.h.cdefs
o.write:	TCPIPLibs:sys.h.time
o.write:	TCPIPLibs:sys.h.uio
o.write:	TCPIPLibs:sys.h.cdefs
o.write:	C:h.kernel
o.writev:	c.writev
o.writev:	TCPIPLibs:sys.h.types
o.writev:	TCPIPLibs:sys.h.cdefs
o.writev:	TCPIPLibs:machine.h.endian
o.writev:	TCPIPLibs:machine.h.ansi
o.writev:	TCPIPLibs:machine.h.types
o.writev:	TCPIPLibs:sys.h.uio
o.writev:	TCPIPLibs:sys.h.cdefs
o.writev:	TCPIPLibs:h.socklib
o.writev:	TCPIPLibs:sys.h.types
o.writev:	TCPIPLibs:sys.h.socket
o.writev:	TCPIPLibs:sys.h.cdefs
o.writev:	TCPIPLibs:sys.h.stat
o.writev:	TCPIPLibs:sys.h.time
o.writev:	TCPIPLibs:sys.h.cdefs
o.writev:	TCPIPLibs:sys.h.cdefs
o.writev:	TCPIPLibs:sys.h.time
o.writev:	TCPIPLibs:sys.h.uio
o.writev:	C:h.kernel
o.writev:	h.unixlib
o.xgets:	c.xgets
o.xgets:	h.unixlib
o.xperror:	c.xperror
o.xperror:	TCPIPLibs:sys.h.types
o.xperror:	TCPIPLibs:sys.h.cdefs
o.xperror:	TCPIPLibs:machine.h.endian
o.xperror:	TCPIPLibs:machine.h.ansi
o.xperror:	TCPIPLibs:machine.h.types
o.xperror:	TCPIPLibs:h.unistd
o.xperror:	TCPIPLibs:sys.h.cdefs
o.xperror:	TCPIPLibs:sys.h.types
o.xperror:	TCPIPLibs:sys.h.unistd
o.xperror:	TCPIPLibs:sys.h._posix
o.xperror:	TCPIPLibs:sys.h.errno
o.xperror:	C:h.kernel
o.xperror:	h.unixlib
o.xputchar:	c.xputchar
o.xputchar:	C:h.kernel
o.xputchar:	C:h.swis
o.xputchar:	h.unixlib
o.getopt:	c.getopt
o.getopt:	h.unixlib
o.strsep:	c.strsep
o.strsep:	TCPIPLibs:sys.h.cdefs
o.strsep:	h.unixlib
o.kvm:	c.kvm
o.kvm:	TCPIPLibs:sys.h.types
o.kvm:	TCPIPLibs:sys.h.cdefs
o.kvm:	TCPIPLibs:machine.h.endian
o.kvm:	TCPIPLibs:machine.h.ansi
o.kvm:	TCPIPLibs:machine.h.types
o.kvm:	TCPIPLibs:h.kvm
o.kvm:	TCPIPLibs:h.nlist
o.kvm:	TCPIPLibs:sys.h.cdefs
o.kvm:	TCPIPLibs:sys.h.cdefs
o.kvm:	h.unixlib
o.err:	c.err
o.err:	TCPIPLibs:h.err
o.err:	TCPIPLibs:machine.h.ansi
o.err:	TCPIPLibs:sys.h.cdefs
o.err:	TCPIPLibs:sys.h.errno
o.err:	C:h.kernel
o.err:	h.unixlib
o.err:	TCPIPLibs:h.socklib
o.err:	TCPIPLibs:sys.h.types
o.err:	TCPIPLibs:sys.h.cdefs
o.err:	TCPIPLibs:machine.h.endian
o.err:	TCPIPLibs:machine.h.ansi
o.err:	TCPIPLibs:machine.h.types
o.err:	TCPIPLibs:sys.h.socket
o.err:	TCPIPLibs:sys.h.cdefs
o.err:	TCPIPLibs:sys.h.stat
o.err:	TCPIPLibs:sys.h.time
o.err:	TCPIPLibs:sys.h.cdefs
o.err:	TCPIPLibs:sys.h.cdefs
o.err:	TCPIPLibs:sys.h.time
o.err:	TCPIPLibs:sys.h.uio
o.err:	TCPIPLibs:sys.h.cdefs
o.err:	C:h.kernel
o.err:	TCPIPLibs:h.riscos
o.err:	C:h.kernel
o.errlst:	c.errlst
o.errlst:	h.unixlib
o.xstrerror:	c.xstrerror
o.xstrerror:	h.unixlib
o.strdup:	c.strdup
o.strdup:	h.unixlib
o.sleep:	c.sleep
o.sleep:	C:h.swis
o.sleep:	C:h.kernel
o.sleep:	TCPIPLibs:h.unixlib
o.ffs:	c.ffs
o.ffs:	h.unixlib
o.getifaddrs:	c.getifaddrs
o.getifaddrs:	TCPIPLibs:sys.h.cdefs
o.getifaddrs:	TCPIPLibs:sys.h.types
o.getifaddrs:	TCPIPLibs:sys.h.cdefs
o.getifaddrs:	TCPIPLibs:machine.h.endian
o.getifaddrs:	TCPIPLibs:machine.h.ansi
o.getifaddrs:	TCPIPLibs:machine.h.types
o.getifaddrs:	TCPIPLibs:sys.h.ioctl
o.getifaddrs:	TCPIPLibs:sys.h.ttycom
o.getifaddrs:	TCPIPLibs:sys.h.ioccom
o.getifaddrs:	TCPIPLibs:sys.h.ioccom
o.getifaddrs:	TCPIPLibs:sys.h.filio
o.getifaddrs:	TCPIPLibs:sys.h.ioccom
o.getifaddrs:	TCPIPLibs:sys.h.sockio
o.getifaddrs:	TCPIPLibs:sys.h.ioccom
o.getifaddrs:	TCPIPLibs:sys.h.cdefs
o.getifaddrs:	TCPIPLibs:sys.h.socket
o.getifaddrs:	TCPIPLibs:sys.h.cdefs
o.getifaddrs:	TCPIPLibs:net.h.if
o.getifaddrs:	TCPIPLibs:sys.h.time
o.getifaddrs:	TCPIPLibs:sys.h.cdefs
o.getifaddrs:	TCPIPLibs:sys.h.param
o.getifaddrs:	TCPIPLibs:sys.h.types
o.getifaddrs:	TCPIPLibs:sys.h.syslimits
o.getifaddrs:	TCPIPLibs:sys.h.signal
o.getifaddrs:	TCPIPLibs:machine.h.signal
o.getifaddrs:	TCPIPLibs:sys.h.cdefs
o.getifaddrs:	TCPIPLibs:machine.h.param
o.getifaddrs:	TCPIPLibs:machine.h.limits
o.getifaddrs:	TCPIPLibs:net.h.route
o.getifaddrs:	TCPIPLibs:net.h.radix
o.getifaddrs:	TCPIPLibs:sys.h.sysctl
o.getifaddrs:	TCPIPLibs:sys.h._posix
o.getifaddrs:	TCPIPLibs:sys.h.cdefs
o.getifaddrs:	TCPIPLibs:net.h.if_dl
o.getifaddrs:	TCPIPLibs:sys.h.cdefs
o.getifaddrs:	TCPIPLibs:sys.h.errno
o.getifaddrs:	C:h.kernel
o.getifaddrs:	TCPIPLibs:h.ifaddrs
o.getifaddrs:	TCPIPLibs:sys.h.cdefs
o.getifaddrs:	h.unixlib
o.asm: s.asm
o.asm: Hdr:ListOpts
o.asm: Hdr:Macros
o.asm: Hdr:System
o.asm: Hdr:SWIs
o.asm: Hdr:CPU.Arch
o.asm: Hdr:Machine.<Machine>
o.asm: Hdr:Machine.Machine
o.asm: Hdr:CPU.Generic26
o.asm: Hdr:CPU.Generic32
o.asm: Hdr:IO.GenericIO
o.asm: Hdr:RISCOS
o.asm: Hdr:APCS.<APCS>
o.asm: Hdr:APCS.Common
