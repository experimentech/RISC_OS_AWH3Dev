# 
# Copyright (c) 2017, RISC OS Open Ltd
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of RISC OS Open Ltd nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
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
# 
# Makefile for EHCIDriver
#

COMPONENT    = EHCIDriver
OBJS         = call_veneer usbroothub_subr bsd_fns ehcimodule ehci
HDRS         =
CMHGDEPENDS  = ehcimodule
LIBS         = ${CALLXLIB} ${ASMUTILS}
CDEFINES    += ${CDEBUG} -DKERNEL -D_KERNEL -Dpaddr_t=int -D__P(A)=A -DKLD_MODULE -DDISABLE_PACKED
ROMCDEFINES  = -DROM
RES_AREA     = resource_files
CINCLUDES    = -IC:USB,TCPIPLibs:,C:,tbox:
CFLAGS       = -Wp

ifeq (${DEBUG},TRUE)
CFLAGS      += -DDEBUGLIB -DEHCI_DEBUG -DUSB_DEBUG
CMHGFLAGS   += -DDEBUGLIB -DEHCI_DEBUG
LIBS        += ${DEBUGLIBS} ${SOCK5LIB} ${INETLIB}
endif

include CModule

# Dynamic dependencies:
o.call_veneer: s.call_veneer
o.call_veneer: Hdr:ListOpts
o.call_veneer: Hdr:Macros
o.call_veneer: Hdr:System
o.call_veneer: Hdr:SWIs
o.call_veneer: Hdr:CPU.Arch
o.call_veneer: Hdr:Machine.<Machine>
o.call_veneer: Hdr:Machine.Machine
o.call_veneer: Hdr:CPU.Generic26
o.call_veneer: Hdr:CPU.Generic32
o.call_veneer: Hdr:IO.GenericIO
o.call_veneer: Hdr:RISCOS
o.call_veneer: Hdr:Proc
o.usbroothub_subr:	c.usbroothub_subr
o.usbroothub_subr:	C:USB.dev.usb.h.usb
o.usbroothub_subr:	TCPIPLibs:sys.h.types
o.usbroothub_subr:	TCPIPLibs:sys.h.cdefs
o.usbroothub_subr:	TCPIPLibs:machine.h.endian
o.usbroothub_subr:	TCPIPLibs:machine.h.ansi
o.usbroothub_subr:	TCPIPLibs:machine.h.types
o.usbroothub_subr:	TCPIPLibs:sys.h.time
o.usbroothub_subr:	C:USB.dev.usb.h.usb_port
o.usbroothub_subr:	C:USB.sys.h.device
o.usbroothub_subr:	TCPIPLibs:sys.h.queue
o.usbroothub_subr:	TCPIPLibs:h.errno
o.usbroothub_subr:	TCPIPLibs:sys.h.errno
o.usbroothub_subr:	TCPIPLibs:sys.h.ioccom
o.usbroothub_subr:	h.usbroothub_subr
o.bsd_fns:	c.bsd_fns
o.bsd_fns:	C:h.swis
o.bsd_fns:	C:h.kernel
o.bsd_fns:	TCPIPLibs:sys.h.types
o.bsd_fns:	TCPIPLibs:sys.h.cdefs
o.bsd_fns:	TCPIPLibs:machine.h.endian
o.bsd_fns:	TCPIPLibs:machine.h.ansi
o.bsd_fns:	TCPIPLibs:machine.h.types
o.bsd_fns:	TCPIPLibs:sys.h.callout
o.bsd_fns:	TCPIPLibs:sys.h.queue
o.bsd_fns:	TCPIPLibs:sys.h.time
o.bsd_fns:	TCPIPLibs:sys.h.systm
o.bsd_fns:	TCPIPLibs:machine.h.cpufunc
o.bsd_fns:	TCPIPLibs:machine.h.stdarg
o.bsd_fns:	TCPIPLibs:sys.h.callout
o.bsd_fns:	C:USB.machine.h.bus
o.bsd_fns:	TCPIPLibs:sys.h.types
o.bsd_fns:	C:USB.dev.usb.h.usb
o.bsd_fns:	TCPIPLibs:sys.h.types
o.bsd_fns:	TCPIPLibs:sys.h.time
o.bsd_fns:	C:USB.dev.usb.h.usb_port
o.bsd_fns:	C:USB.sys.h.device
o.bsd_fns:	TCPIPLibs:sys.h.queue
o.bsd_fns:	TCPIPLibs:h.errno
o.bsd_fns:	TCPIPLibs:sys.h.errno
o.bsd_fns:	TCPIPLibs:sys.h.ioccom
o.bsd_fns:	C:USB.dev.usb.h.usbdi
o.bsd_fns:	TCPIPLibs:sys.h.cdefs
o.bsd_fns:	C:USB.dev.usb.h.usbdivar
o.bsd_fns:	h.ehcireg
o.bsd_fns:	h.ehcivar
o.bsd_fns:	C:Global.h.HALEntries
o.bsd_fns:	C:Interface.h.USBDriver
o.bsd_fns:	C:callx.h.callx
o.bsd_fns:	C:h.kernel
o.bsd_fns:	C:DebugLib.h.DebugLib
o.ehcimodule:	c.ehcimodule
o.ehcimodule:	C:h.swis
o.ehcimodule:	C:h.kernel
o.ehcimodule:	TCPIPLibs:sys.h.types
o.ehcimodule:	TCPIPLibs:sys.h.cdefs
o.ehcimodule:	TCPIPLibs:machine.h.endian
o.ehcimodule:	TCPIPLibs:machine.h.ansi
o.ehcimodule:	TCPIPLibs:machine.h.types
o.ehcimodule:	TCPIPLibs:sys.h.systm
o.ehcimodule:	TCPIPLibs:machine.h.cpufunc
o.ehcimodule:	TCPIPLibs:machine.h.stdarg
o.ehcimodule:	TCPIPLibs:sys.h.callout
o.ehcimodule:	TCPIPLibs:sys.h.queue
o.ehcimodule:	C:USB.machine.h.bus
o.ehcimodule:	TCPIPLibs:sys.h.types
o.ehcimodule:	C:USB.dev.usb.h.usb
o.ehcimodule:	TCPIPLibs:sys.h.types
o.ehcimodule:	TCPIPLibs:sys.h.time
o.ehcimodule:	C:USB.dev.usb.h.usb_port
o.ehcimodule:	C:USB.sys.h.device
o.ehcimodule:	TCPIPLibs:sys.h.queue
o.ehcimodule:	TCPIPLibs:h.errno
o.ehcimodule:	TCPIPLibs:sys.h.errno
o.ehcimodule:	TCPIPLibs:sys.h.ioccom
o.ehcimodule:	C:USB.dev.usb.h.usbdi
o.ehcimodule:	TCPIPLibs:sys.h.cdefs
o.ehcimodule:	C:USB.dev.usb.h.usbdivar
o.ehcimodule:	h.ehcireg
o.ehcimodule:	h.ehcivar
o.ehcimodule:	C:Global.h.RISCOS
o.ehcimodule:	C:Global.h.Services
o.ehcimodule:	C:Global.h.HALEntries
o.ehcimodule:	C:Global.h.OSRSI6
o.ehcimodule:	C:Global.h.OSMisc
o.ehcimodule:	C:Global.h.OsBytes
o.ehcimodule:	C:Interface.h.PCI
o.ehcimodule:	C:Interface.h.USBDriver
o.ehcimodule:	C:USB.h.USBDevFS
o.ehcimodule:	C:AsmUtils.h.callbacks
o.ehcimodule:	C:callx.h.callx
o.ehcimodule:	C:h.kernel
o.ehcimodule:	tbox:h.toolbox
o.ehcimodule:	tbox:h.wimp
o.ehcimodule:	h.EHCIDriverHdr
o.ehcimodule:	C:DebugLib.h.DebugLib
o.ehci:	c.ehci
o.ehci:	TCPIPLibs:sys.h.cdefs
o.ehci:	TCPIPLibs:sys.h.param
o.ehci:	TCPIPLibs:sys.h.types
o.ehci:	TCPIPLibs:sys.h.cdefs
o.ehci:	TCPIPLibs:machine.h.endian
o.ehci:	TCPIPLibs:machine.h.ansi
o.ehci:	TCPIPLibs:machine.h.types
o.ehci:	TCPIPLibs:sys.h.syslimits
o.ehci:	TCPIPLibs:sys.h.cdefs
o.ehci:	TCPIPLibs:sys.h.errno
o.ehci:	TCPIPLibs:sys.h.time
o.ehci:	TCPIPLibs:sys.h.resource
o.ehci:	TCPIPLibs:sys.h.types
o.ehci:	TCPIPLibs:sys.h.ucred
o.ehci:	TCPIPLibs:sys.h.uio
o.ehci:	TCPIPLibs:sys.h.rtprio
o.ehci:	TCPIPLibs:sys.h.signal
o.ehci:	TCPIPLibs:machine.h.signal
o.ehci:	TCPIPLibs:machine.h.param
o.ehci:	TCPIPLibs:machine.h.limits
o.ehci:	TCPIPLibs:sys.h.systm
o.ehci:	TCPIPLibs:machine.h.cpufunc
o.ehci:	TCPIPLibs:machine.h.stdarg
o.ehci:	TCPIPLibs:sys.h.callout
o.ehci:	TCPIPLibs:sys.h.queue
o.ehci:	TCPIPLibs:sys.h.kernel
o.ehci:	TCPIPLibs:sys.h.linker_set
o.ehci:	TCPIPLibs:sys.h.malloc
o.ehci:	C:USB.sys.h.device
o.ehci:	TCPIPLibs:sys.h.queue
o.ehci:	TCPIPLibs:sys.h.select
o.ehci:	TCPIPLibs:sys.h.proc
o.ehci:	TCPIPLibs:machine.h.proc
o.ehci:	TCPIPLibs:sys.h.queue
o.ehci:	TCPIPLibs:sys.h.rtprio
o.ehci:	TCPIPLibs:sys.h.select
o.ehci:	TCPIPLibs:sys.h.time
o.ehci:	TCPIPLibs:sys.h.queue
o.ehci:	C:USB.machine.h.bus
o.ehci:	TCPIPLibs:sys.h.types
o.ehci:	C:USB.dev.usb.h.usb
o.ehci:	TCPIPLibs:sys.h.types
o.ehci:	TCPIPLibs:sys.h.time
o.ehci:	C:USB.dev.usb.h.usb_port
o.ehci:	C:USB.sys.h.device
o.ehci:	TCPIPLibs:h.errno
o.ehci:	TCPIPLibs:sys.h.ioccom
o.ehci:	C:USB.dev.usb.h.usbdi
o.ehci:	TCPIPLibs:sys.h.cdefs
o.ehci:	C:USB.dev.usb.h.usbdivar
o.ehci:	h.ehcireg
o.ehci:	h.ehcivar
o.ehci:	h.usbroothub_subr
o.EHCIDriverHdr:	cmhg.EHCIDriverHdr
o.EHCIDriverHdr:	C:Global.h.RISCOS
o.EHCIDriverHdr:	C:Global.h.Services
o.EHCIDriverHdr:	VersionNum
