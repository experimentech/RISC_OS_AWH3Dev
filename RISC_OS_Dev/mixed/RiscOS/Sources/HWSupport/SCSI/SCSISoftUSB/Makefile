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
# Makefile for SCSISoftUSB
#

COMPONENT   = SCSISoftUSB
TARGET     ?= SCSISoftUSB
OBJS        = global glue module umass umass_quirks asm
HDRS        =
CINCLUDES   = -ITCPIPLibs:,C:USB
CFLAGS     += -wp -wc -we -DDISABLE_PACKED -D_KERNEL
CMHGFILE    = modhdr
CMHGDEPENDS = glue module
RAMCDEFINES = -DSTANDALONE
CDFLAGS    += -DDEBUGLIB -DUMASS_DEBUG -DUSB_DEBUG
CMHGDFLAGS += -DDEBUGLIB -DUMASS_DEBUG -DUSB_DEBUG
RES_OBJ     = resmess
RES_AREA    = resmess_ResourcesFiles

include CModule

DBG_LIBS   += ${SOCK5LIB} ${INETLIB}

# Dynamic dependencies:
o.global:	c.global
o.global:	h.global
o.global:	C:tboxlibs.h.toolbox
o.global:	C:h.kernel
o.global:	C:tboxlibs.h.wimp
o.glue:	c.glue
o.glue:	C:h.swis
o.glue:	C:h.kernel
o.glue:	C:Global.h.NewErrors
o.glue:	C:Global.h.RISCOS
o.glue:	C:Interface.h.DeviceFS
o.glue:	C:Interface.h.SCSIErr
o.glue:	C:Interface.h.RTSupport
o.glue:	C:USB.dev.usb.h.usb
o.glue:	TCPIPLibs:sys.h.types
o.glue:	TCPIPLibs:sys.h.cdefs
o.glue:	TCPIPLibs:machine.h.endian
o.glue:	TCPIPLibs:machine.h.ansi
o.glue:	TCPIPLibs:machine.h.types
o.glue:	TCPIPLibs:sys.h.time
o.glue:	TCPIPLibs:sys.h.cdefs
o.glue:	C:USB.dev.usb.h.usb_port
o.glue:	C:USB.sys.h.device
o.glue:	TCPIPLibs:sys.h.queue
o.glue:	TCPIPLibs:h.errno
o.glue:	TCPIPLibs:sys.h.errno
o.glue:	C:h.kernel
o.glue:	TCPIPLibs:sys.h.ioccom
o.glue:	C:USB.dev.usb.h.usbdi
o.glue:	TCPIPLibs:sys.h.cdefs
o.glue:	h.asm
o.glue:	C:h.kernel
o.glue:	h.global
o.glue:	C:tboxlibs.h.toolbox
o.glue:	C:tboxlibs.h.wimp
o.glue:	h.glue
o.glue:	h.modhdr
o.glue:	h.umassvar
o.glue:	h.debug
o.module:	c.module
o.module:	C:h.kernel
o.module:	C:h.swis
o.module:	C:Global.h.Services
o.module:	C:Global.h.RISCOS
o.module:	C:Interface.h.SCSIErr
o.module:	C:Interface.h.RTSupport
o.module:	C:DebugLib.h.DebugLib
o.module:	C:USB.h.USBDevFS
o.module:	h.global
o.module:	C:tboxlibs.h.toolbox
o.module:	C:tboxlibs.h.wimp
o.module:	h.glue
o.module:	h.modhdr
o.module:	h.resmess
o.umass:	c.umass
o.umass:	h.debug
o.umass:	C:USB.dev.usb.h.usb
o.umass:	TCPIPLibs:sys.h.types
o.umass:	TCPIPLibs:sys.h.cdefs
o.umass:	TCPIPLibs:machine.h.endian
o.umass:	TCPIPLibs:machine.h.ansi
o.umass:	TCPIPLibs:machine.h.types
o.umass:	TCPIPLibs:sys.h.time
o.umass:	TCPIPLibs:sys.h.cdefs
o.umass:	C:USB.dev.usb.h.usb_port
o.umass:	C:USB.sys.h.device
o.umass:	TCPIPLibs:sys.h.queue
o.umass:	TCPIPLibs:h.errno
o.umass:	TCPIPLibs:sys.h.errno
o.umass:	C:h.kernel
o.umass:	TCPIPLibs:sys.h.ioccom
o.umass:	C:USB.dev.usb.h.usbdi
o.umass:	TCPIPLibs:sys.h.cdefs
o.umass:	h.umassvar
o.umass:	h.umass_quirks
o.umass:	h.global
o.umass:	C:tboxlibs.h.toolbox
o.umass:	C:tboxlibs.h.wimp
o.umass_quirks:	c.umass_quirks
o.umass_quirks:	TCPIPLibs:sys.h.param
o.umass_quirks:	TCPIPLibs:sys.h.types
o.umass_quirks:	TCPIPLibs:sys.h.cdefs
o.umass_quirks:	TCPIPLibs:machine.h.endian
o.umass_quirks:	TCPIPLibs:machine.h.ansi
o.umass_quirks:	TCPIPLibs:machine.h.types
o.umass_quirks:	TCPIPLibs:sys.h.syslimits
o.umass_quirks:	TCPIPLibs:sys.h.signal
o.umass_quirks:	TCPIPLibs:machine.h.signal
o.umass_quirks:	TCPIPLibs:sys.h.cdefs
o.umass_quirks:	TCPIPLibs:machine.h.param
o.umass_quirks:	TCPIPLibs:machine.h.limits
o.umass_quirks:	C:USB.dev.usb.h.usb
o.umass_quirks:	TCPIPLibs:sys.h.types
o.umass_quirks:	TCPIPLibs:sys.h.time
o.umass_quirks:	TCPIPLibs:sys.h.cdefs
o.umass_quirks:	C:USB.dev.usb.h.usb_port
o.umass_quirks:	C:USB.sys.h.device
o.umass_quirks:	TCPIPLibs:sys.h.queue
o.umass_quirks:	TCPIPLibs:h.errno
o.umass_quirks:	TCPIPLibs:sys.h.errno
o.umass_quirks:	C:h.kernel
o.umass_quirks:	TCPIPLibs:sys.h.ioccom
o.umass_quirks:	C:USB.dev.usb.h.usbdi
o.umass_quirks:	TCPIPLibs:sys.h.cdefs
o.umass_quirks:	C:USB.dev.usb.h.usbdevs
o.umass_quirks:	h.umassvar
o.umass_quirks:	h.umass_quirks
o.asm: s.asm
o.asm: hdr:ListOpts
o.asm: hdr:Macros
o.asm: hdr:System
o.asm: Hdr:SWIs
o.asm: Hdr:CPU.Arch
o.asm: Hdr:Machine.<Machine>
o.asm: Hdr:Machine.Machine
o.asm: Hdr:CPU.Generic26
o.asm: Hdr:CPU.Generic32
o.asm: Hdr:IO.GenericIO
o.asm: Hdr:RISCOS
o.asm: hdr:APCS.<APCS>
o.asm: Hdr:APCS.Common
o.asm: hdr:UpCall
o.modhdr:	cmhg.modhdr
o.modhdr:	C:Global.h.Services
o.modhdr:	VersionNum
