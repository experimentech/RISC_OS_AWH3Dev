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
# Makefile for OHCIDriver
#

COMPONENT    = OHCIDriver
OBJS         = call_veneer bsd_fns ohcimodule ohci
HDRS         =
CMHGDEPENDS  = ohcimodule
LIBS         = ${CALLXLIB} ${ASMUTILS}
CDEFINES    += ${CDEBUG} -DKERNEL -D_KERNEL -Dpaddr_t=int -D__P(A)=A -DKLD_MODULE -DDISABLE_PACKED
ROMCDEFINES  = -DROM
RES_AREA     = resource_files
CINCLUDES    = -IC:USB,TCPIPLibs:,C:,tbox:
CFLAGS       = -Wp

ifeq (${DEBUG},TRUE)
CFLAGS      += -DDEBUGLIB -DOHCI_DEBUG -DUSB_DEBUG
CMHGFLAGS   += -DDEBUGLIB -DOHCI_DEBUG
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
o.bsd_fns:	h.ohcireg
o.bsd_fns:	h.ohcivar
o.bsd_fns:	C:Global.h.HALEntries
o.bsd_fns:	C:Interface.h.USBDriver
o.bsd_fns:	C:callx.h.callx
o.bsd_fns:	C:h.kernel
o.bsd_fns:	C:DebugLib.h.DebugLib
o.ohcimodule:	c.ohcimodule
o.ohcimodule:	C:h.swis
o.ohcimodule:	C:h.kernel
o.ohcimodule:	TCPIPLibs:sys.h.types
o.ohcimodule:	TCPIPLibs:sys.h.cdefs
o.ohcimodule:	TCPIPLibs:machine.h.endian
o.ohcimodule:	TCPIPLibs:machine.h.ansi
o.ohcimodule:	TCPIPLibs:machine.h.types
o.ohcimodule:	TCPIPLibs:sys.h.systm
o.ohcimodule:	TCPIPLibs:machine.h.cpufunc
o.ohcimodule:	TCPIPLibs:machine.h.stdarg
o.ohcimodule:	TCPIPLibs:sys.h.callout
o.ohcimodule:	TCPIPLibs:sys.h.queue
o.ohcimodule:	C:USB.machine.h.bus
o.ohcimodule:	TCPIPLibs:sys.h.types
o.ohcimodule:	C:USB.dev.usb.h.usb
o.ohcimodule:	TCPIPLibs:sys.h.types
o.ohcimodule:	TCPIPLibs:sys.h.time
o.ohcimodule:	C:USB.dev.usb.h.usb_port
o.ohcimodule:	C:USB.sys.h.device
o.ohcimodule:	TCPIPLibs:sys.h.queue
o.ohcimodule:	TCPIPLibs:h.errno
o.ohcimodule:	TCPIPLibs:sys.h.errno
o.ohcimodule:	TCPIPLibs:sys.h.ioccom
o.ohcimodule:	C:USB.dev.usb.h.usbdi
o.ohcimodule:	TCPIPLibs:sys.h.cdefs
o.ohcimodule:	C:USB.dev.usb.h.usbdivar
o.ohcimodule:	h.ohcireg
o.ohcimodule:	h.ohcivar
o.ohcimodule:	C:Global.h.RISCOS
o.ohcimodule:	C:Global.h.Services
o.ohcimodule:	C:Global.h.HALEntries
o.ohcimodule:	C:Global.h.OSRSI6
o.ohcimodule:	C:Global.h.OSMisc
o.ohcimodule:	C:Global.h.OsBytes
o.ohcimodule:	C:Interface.h.PCI
o.ohcimodule:	C:Interface.h.USBDriver
o.ohcimodule:	C:USB.h.USBDevFS
o.ohcimodule:	C:AsmUtils.h.callbacks
o.ohcimodule:	C:callx.h.callx
o.ohcimodule:	C:h.kernel
o.ohcimodule:	tbox:h.toolbox
o.ohcimodule:	tbox:h.wimp
o.ohcimodule:	h.OHCIDriverHdr
o.ohcimodule:	C:DebugLib.h.DebugLib
o.ohci:	c.ohci
o.ohci:	TCPIPLibs:sys.h.cdefs
o.ohci:	TCPIPLibs:sys.h.param
o.ohci:	TCPIPLibs:sys.h.types
o.ohci:	TCPIPLibs:sys.h.cdefs
o.ohci:	TCPIPLibs:machine.h.endian
o.ohci:	TCPIPLibs:machine.h.ansi
o.ohci:	TCPIPLibs:machine.h.types
o.ohci:	TCPIPLibs:sys.h.syslimits
o.ohci:	TCPIPLibs:sys.h.cdefs
o.ohci:	TCPIPLibs:sys.h.errno
o.ohci:	TCPIPLibs:sys.h.time
o.ohci:	TCPIPLibs:sys.h.resource
o.ohci:	TCPIPLibs:sys.h.types
o.ohci:	TCPIPLibs:sys.h.ucred
o.ohci:	TCPIPLibs:sys.h.uio
o.ohci:	TCPIPLibs:sys.h.rtprio
o.ohci:	TCPIPLibs:sys.h.signal
o.ohci:	TCPIPLibs:machine.h.signal
o.ohci:	TCPIPLibs:machine.h.param
o.ohci:	TCPIPLibs:machine.h.limits
o.ohci:	TCPIPLibs:sys.h.systm
o.ohci:	TCPIPLibs:machine.h.cpufunc
o.ohci:	TCPIPLibs:machine.h.stdarg
o.ohci:	TCPIPLibs:sys.h.callout
o.ohci:	TCPIPLibs:sys.h.queue
o.ohci:	TCPIPLibs:sys.h.malloc
o.ohci:	TCPIPLibs:sys.h.proc
o.ohci:	TCPIPLibs:machine.h.proc
o.ohci:	TCPIPLibs:sys.h.queue
o.ohci:	TCPIPLibs:sys.h.rtprio
o.ohci:	TCPIPLibs:sys.h.select
o.ohci:	TCPIPLibs:sys.h.time
o.ohci:	TCPIPLibs:sys.h.queue
o.ohci:	C:USB.machine.h.bus
o.ohci:	TCPIPLibs:sys.h.types
o.ohci:	TCPIPLibs:machine.h.endian
o.ohci:	C:USB.dev.usb.h.usb
o.ohci:	TCPIPLibs:sys.h.types
o.ohci:	TCPIPLibs:sys.h.time
o.ohci:	C:USB.dev.usb.h.usb_port
o.ohci:	C:USB.sys.h.device
o.ohci:	TCPIPLibs:sys.h.queue
o.ohci:	TCPIPLibs:h.errno
o.ohci:	TCPIPLibs:sys.h.ioccom
o.ohci:	C:USB.dev.usb.h.usbdi
o.ohci:	TCPIPLibs:sys.h.cdefs
o.ohci:	C:USB.dev.usb.h.usbdivar
o.ohci:	h.ohcireg
o.ohci:	h.ohcivar
o.OHCIDriverHdr:	cmhg.OHCIDriverHdr
o.OHCIDriverHdr:	C:Global.h.RISCOS
o.OHCIDriverHdr:	C:Global.h.Services
o.OHCIDriverHdr:	VersionNum
