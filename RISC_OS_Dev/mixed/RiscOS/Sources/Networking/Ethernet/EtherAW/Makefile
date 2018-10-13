#
# Copyright (c) 2017, Colin Granville
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * The name Colin Granville may not be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.



# Makefile for EtherTH

COMPONENT   = EtherTH
TARGET      ?= EtherTH

# The CMHG and resources object files are added automatically, so don't need to be listed
OBJS = module device utils dci dcierror dcifilter mii ar8031
HDRS        =
ASMHDRS     = EtherDevice
CMHGFILE    = ModuleHdr
CMHGDEPENDS = module device dcierror
CINCLUDES   = -ITCPIPLibs:,C:
LIBS        = ${CALLXLIB} ${ASMUTILS}
CFLAGS      += -Wp

ifeq (${DEBUG},TRUE)
CFLAGS         += -DDEBUGLIB
LIBS           += ${DEBUGLIBS} ${NET5LIBS}
endif

include CModule

# Dynamic dependencies:
o.module:	c.module
o.module:	TCPIPLibs:sys.h.queue
o.module:	C:Global.h.services
o.module:	C:callx.h.callx
o.module:	C:h.kernel
o.module:	h.dci
o.module:	TCPIPLibs:sys.h.types
o.module:	TCPIPLibs:sys.h.cdefs
o.module:	TCPIPLibs:machine.h.endian
o.module:	TCPIPLibs:machine.h.ansi
o.module:	TCPIPLibs:machine.h.types
o.module:	TCPIPLibs:net.h.ethernet
o.module:	TCPIPLibs:sys.h.cdefs
o.module:	TCPIPLibs:sys.h.dcistructs
o.module:	C:h.swis
o.module:	TCPIPLibs:sys.h.mbuf
o.module:	TCPIPLibs:sys.h.malloc
o.module:	C:h.swis
o.module:	h.ModuleHdr
o.module:	h.module
o.module:	h.device
o.module:	h.dci
o.module:	h.dcifilter
o.module:	h.dci
o.module:	C:h.swis
o.module:	TCPIPLibs:sys.h.queue
o.module:	C:Global.h.HALDevice
o.module:	C:Global.h.HALEntries
o.module:	h.HalEtherDevice
o.module:	C:Global.h.HalDevice
o.module:	h.mii
o.module:	h.device
o.module:	h.debug
o.module:	C:debuglib.h.debuglib
o.module:	h.utils
o.module:	C:h.swis
o.module:	h.dcierror
o.module:	C:h.swis
o.module:	TCPIPLibs:sys.h.errno
o.module:	C:h.kernel
o.device:	c.device
o.device:	h.dcierror
o.device:	C:h.swis
o.device:	C:h.kernel
o.device:	TCPIPLibs:sys.h.errno
o.device:	C:h.kernel
o.device:	h.debug
o.device:	C:debuglib.h.debuglib
o.device:	h.device
o.device:	h.dci
o.device:	TCPIPLibs:sys.h.types
o.device:	TCPIPLibs:sys.h.cdefs
o.device:	TCPIPLibs:machine.h.endian
o.device:	TCPIPLibs:machine.h.ansi
o.device:	TCPIPLibs:machine.h.types
o.device:	TCPIPLibs:net.h.ethernet
o.device:	TCPIPLibs:sys.h.cdefs
o.device:	TCPIPLibs:sys.h.dcistructs
o.device:	C:h.swis
o.device:	TCPIPLibs:sys.h.mbuf
o.device:	TCPIPLibs:sys.h.malloc
o.device:	h.dcifilter
o.device:	h.dci
o.device:	C:h.swis
o.device:	TCPIPLibs:sys.h.queue
o.device:	C:Global.h.HALDevice
o.device:	C:Global.h.HALEntries
o.device:	h.HalEtherDevice
o.device:	C:Global.h.HalDevice
o.device:	h.module
o.device:	h.ModuleHdr
o.device:	h.utils
o.device:	C:h.swis
o.device:	h.mii
o.device:	h.device
o.device:	h.ar8031_mii
o.device:	h.mii
o.device:	C:AsmUtils.h.irqs
o.device:	C:callx.h.callx
o.device:	C:h.kernel
o.utils:	c.utils
o.utils:	C:Global.h.HALEntries
o.utils:	C:Global.h.OSMisc
o.utils:	C:h.swis
o.utils:	C:h.kernel
o.utils:	h.utils
o.utils:	C:h.swis
o.utils:	h.debug
o.utils:	C:debuglib.h.debuglib
o.dci:	c.dci
o.dci:	h.dci
o.dci:	TCPIPLibs:sys.h.types
o.dci:	TCPIPLibs:sys.h.cdefs
o.dci:	TCPIPLibs:machine.h.endian
o.dci:	TCPIPLibs:machine.h.ansi
o.dci:	TCPIPLibs:machine.h.types
o.dci:	TCPIPLibs:net.h.ethernet
o.dci:	TCPIPLibs:sys.h.cdefs
o.dci:	TCPIPLibs:sys.h.dcistructs
o.dci:	C:h.swis
o.dci:	C:h.kernel
o.dci:	TCPIPLibs:sys.h.mbuf
o.dci:	TCPIPLibs:sys.h.malloc
o.dcierror:	c.dcierror
o.dcierror:	h.dcierror
o.dcierror:	C:h.swis
o.dcierror:	C:h.kernel
o.dcierror:	TCPIPLibs:sys.h.errno
o.dcierror:	C:h.kernel
o.dcierror:	h.ModuleHdr
o.dcierror:	h.dci
o.dcierror:	TCPIPLibs:sys.h.types
o.dcierror:	TCPIPLibs:sys.h.cdefs
o.dcierror:	TCPIPLibs:machine.h.endian
o.dcierror:	TCPIPLibs:machine.h.ansi
o.dcierror:	TCPIPLibs:machine.h.types
o.dcierror:	TCPIPLibs:net.h.ethernet
o.dcierror:	TCPIPLibs:sys.h.cdefs
o.dcierror:	TCPIPLibs:sys.h.dcistructs
o.dcierror:	C:h.swis
o.dcierror:	TCPIPLibs:sys.h.mbuf
o.dcierror:	TCPIPLibs:sys.h.malloc
o.dcierror:	h.debug
o.dcierror:	C:debuglib.h.debuglib
h.ModuleHdr:	cmhg.ModuleHdr
h.ModuleHdr:	C:Global.h.Services
h.ModuleHdr:	VersionNum
o.dcifilter:	c.dcifilter
o.dcifilter:	TCPIPLibs:sys.h.queue
o.dcifilter:	h.debug
o.dcifilter:	C:debuglib.h.debuglib
o.dcifilter:	h.dcifilter
o.dcifilter:	h.dci
o.dcifilter:	TCPIPLibs:sys.h.types
o.dcifilter:	TCPIPLibs:sys.h.cdefs
o.dcifilter:	TCPIPLibs:machine.h.endian
o.dcifilter:	TCPIPLibs:machine.h.ansi
o.dcifilter:	TCPIPLibs:machine.h.types
o.dcifilter:	TCPIPLibs:net.h.ethernet
o.dcifilter:	TCPIPLibs:sys.h.cdefs
o.dcifilter:	TCPIPLibs:sys.h.dcistructs
o.dcifilter:	C:h.swis
o.dcifilter:	C:h.kernel
o.dcifilter:	TCPIPLibs:sys.h.mbuf
o.dcifilter:	TCPIPLibs:sys.h.malloc
o.dcifilter:	h.dcierror
o.dcifilter:	C:h.swis
o.dcifilter:	TCPIPLibs:sys.h.errno
o.dcifilter:	C:h.kernel
o.dcifilter:	h.utils
o.dcifilter:	C:h.swis
o.mii:	c.mii
o.mii:	h.mii
o.mii:	h.device
o.mii:	h.dci
o.mii:	TCPIPLibs:sys.h.types
o.mii:	TCPIPLibs:sys.h.cdefs
o.mii:	TCPIPLibs:machine.h.endian
o.mii:	TCPIPLibs:machine.h.ansi
o.mii:	TCPIPLibs:machine.h.types
o.mii:	TCPIPLibs:net.h.ethernet
o.mii:	TCPIPLibs:sys.h.cdefs
o.mii:	TCPIPLibs:sys.h.dcistructs
o.mii:	C:h.swis
o.mii:	C:h.kernel
o.mii:	TCPIPLibs:sys.h.mbuf
o.mii:	TCPIPLibs:sys.h.malloc
o.mii:	h.dcifilter
o.mii:	h.dci
o.mii:	C:h.swis
o.mii:	TCPIPLibs:sys.h.queue
o.mii:	C:Global.h.HALDevice
o.mii:	C:Global.h.HALEntries
o.mii:	h.HalEtherDevice
o.mii:	C:Global.h.HalDevice
o.mii:	h.utils
o.mii:	C:h.swis
o.mii:	h.debug
o.mii:	C:debuglib.h.debuglib
o.mii:	h.device
o.mii:	C:AsmUtils.h.irqs
o.ar8031:	c.ar8031
o.ar8031:	h.ar8031_mii
o.ar8031:	h.mii
o.ar8031:	h.device
o.ar8031:	h.dci
o.ar8031:	TCPIPLibs:sys.h.types
o.ar8031:	TCPIPLibs:sys.h.cdefs
o.ar8031:	TCPIPLibs:machine.h.endian
o.ar8031:	TCPIPLibs:machine.h.ansi
o.ar8031:	TCPIPLibs:machine.h.types
o.ar8031:	TCPIPLibs:net.h.ethernet
o.ar8031:	TCPIPLibs:sys.h.cdefs
o.ar8031:	TCPIPLibs:sys.h.dcistructs
o.ar8031:	C:h.swis
o.ar8031:	C:h.kernel
o.ar8031:	TCPIPLibs:sys.h.mbuf
o.ar8031:	TCPIPLibs:sys.h.malloc
o.ar8031:	h.dcifilter
o.ar8031:	h.dci
o.ar8031:	C:h.swis
o.ar8031:	TCPIPLibs:sys.h.queue
o.ar8031:	C:Global.h.HALDevice
o.ar8031:	C:Global.h.HALEntries
o.ar8031:	h.HalEtherDevice
o.ar8031:	C:Global.h.HalDevice
o.ar8031:	C:AsmUtils.h.irqs
o.ModuleHdr:	cmhg.ModuleHdr
o.ModuleHdr:	C:Global.h.Services
o.ModuleHdr:	VersionNum
