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
# Makefile for USBDriver
# 

COMPONENT       = USBDriver
UNAME           = "RISC_OS"
VPATH           = ^.build ^.dev.usb
EXPLIBDIR       = <Lib$Dir>.USB
DEVICELIST      = Resources.<Locale>.USBDevs
CUSTOMEXP       = custom
CINCLUDES       = -Itbox:,TCPIPLibs:,^.,OS:,C:USB
CDEFINES       += ${CDEBUG} -DKERNEL -D_KERNEL -Dpaddr_t=int -D__P(A)=A -DKLD_MODULE -DDISABLE_PACKED
RES_AREA        = resource_files
LIBS            = ${CALLXLIB} ${ASMUTILS}
CMHGDEPENDS     = usbmouse usbmodule usbkboard
INSTRES_FILES   = USBDevs
INSTRES_DEPENDS = ${DEVICELIST}
OBJS            = usbmodule port usb usbdi usb_subr \
                  usbdi_util usb_quirks uhub usbmouse usbkboard \
                  hid bufman triggercbs call_veneer

#
# Debug switch
#
DEBUG ?= FALSE
ifeq (${DEBUG},TRUE)
CFLAGS         += -DUSB_DEBUG -DDEBUGLIB
CMHGDEFINES    += -DUSB_DEBUG
LIBS           += ${DEBUGLIBS} ${NET5LIBS}
endif

include CModule

CFLAGS         += -wp -wc

#
# Produce the devices list
#
makedevs: c.makedevs ${DIRS}
        ${MAKE} -f makedevs/mk COMPONENT=makedevs THROWBACK=${THROWBACK}

${DEVICELIST}: makedevs ^.dev.usb.h.usbdevs ^.dev.usb.h.usbdevs_data
        ${RUN}makedevs > $@

#
# Supplemented or overridden targets
#
clean::
        ${RM} ${DEVICELIST}
        ${RM} makedevs
        ${RM} ^.dev.usb.h.usbdevs
        ${RM} ^.dev.usb.h.usbdevs_data

export: export_${PHASE}
        @${NOP}

export_hdrs: h.${CMHGFILE} ^.dev.usb.h.usbdevs
        ${MKDIR} o
        ${MKDIR} ${EXPLIBDIR}.dev.usb.h
        ${MKDIR} ${EXPLIBDIR}.sys.h
        ${MKDIR} ${EXPLIBDIR}.machine.h
        ${MKDIR} ${EXPLIBDIR}.h
        ${MKDIR} ${EXPLIBDIR}.Hdr
        # DeviceFS/Service call interface
        ${CP} h.USBDevFS           ${EXPLIBDIR}.h.USBDevFS         ${CPFLAGS}
        # Host driver interface
        ${CP} ^.dev.usb.h.usb      ${EXPLIBDIR}.dev.usb.h.usb      ${CPFLAGS}
        ${CP} ^.dev.usb.h.usbdi    ${EXPLIBDIR}.dev.usb.h.usbdi    ${CPFLAGS}
        ${CP} ^.dev.usb.h.usbdivar ${EXPLIBDIR}.dev.usb.h.usbdivar ${CPFLAGS}
        ${CP} ^.dev.usb.h.usb_port ${EXPLIBDIR}.dev.usb.h.usb_port ${CPFLAGS}
        ${CP} ^.sys.h.device       ${EXPLIBDIR}.sys.h.device       ${CPFLAGS}
        ${CP} ^.machine.h.bus      ${EXPLIBDIR}.machine.h.bus      ${CPFLAGS}
        ${CP} ^.VersionNum         ${EXPLIBDIR}.LibVersion         ${CPFLAGS}
        # Conversion of the USB device database
        ${CP} ^.dev.usb.h.usbdevs  ${EXPLIBDIR}.dev.usb.h.usbdevs  ${CPFLAGS}
        # Equivalent of ASMHDRS and ASMCHDRS and CMHGAUTOHDR
        ${CP} Hdr.USBDriver        ${EXP_HDR}.USBDriver            ${CPFLAGS}
        ${HDR2H} Hdr.USBDriver ${C_EXP_HDR}.USBDriver
        ${DO} ${AWK} -- "/.ifndef ${CMHGFILE_SWIPREFIX}/,/endif/" h.${CMHGFILE} > o._h_USBDriver
        ${FAPPEND} ${C_EXP_HDR}.USBDriver ${C_EXP_HDR}.USBDriver o._h_USBDriver
        @${ECHO} ${COMPONENT}: header export complete

export_libs:
        @${ECHO} ${COMPONENT}: no exported libraries

#
# Static dependencies
#
^.dev.usb.h.usbdevs ^.dev.usb.h.usbdevs_data: ^.dev.usb.usbdevs ^.dev.usb.devlist2h/awk
        ${GAWK} -v os="${UNAME} -s" -f ^.dev.usb.devlist2h/awk ^.dev.usb.usbdevs

# Dynamic dependencies:
o.usbmodule:	c.usbmodule
o.usbmodule:	C:Global.h.RISCOS
o.usbmodule:	C:Global.h.Services
o.usbmodule:	C:Global.h.UpCall
o.usbmodule:	C:Global.h.FSNumbers
o.usbmodule:	C:Interface.h.DeviceFS
o.usbmodule:	C:Interface.h.USBDriver
o.usbmodule:	TCPIPLibs:sys.h.callout
o.usbmodule:	TCPIPLibs:sys.h.queue
o.usbmodule:	TCPIPLibs:sys.h.ioctl
o.usbmodule:	TCPIPLibs:sys.h.ttycom
o.usbmodule:	TCPIPLibs:sys.h.ioccom
o.usbmodule:	TCPIPLibs:sys.h.ioccom
o.usbmodule:	TCPIPLibs:sys.h.filio
o.usbmodule:	TCPIPLibs:sys.h.ioccom
o.usbmodule:	TCPIPLibs:sys.h.sockio
o.usbmodule:	TCPIPLibs:sys.h.ioccom
o.usbmodule:	TCPIPLibs:sys.h.time
o.usbmodule:	^.dev.usb.h.usb
o.usbmodule:	TCPIPLibs:sys.h.types
o.usbmodule:	TCPIPLibs:sys.h.cdefs
o.usbmodule:	TCPIPLibs:machine.h.endian
o.usbmodule:	TCPIPLibs:machine.h.ansi
o.usbmodule:	TCPIPLibs:machine.h.types
o.usbmodule:	TCPIPLibs:sys.h.time
o.usbmodule:	^.dev.usb.h.usb_port
o.usbmodule:	^.sys.h.device
o.usbmodule:	TCPIPLibs:sys.h.queue
o.usbmodule:	TCPIPLibs:h.errno
o.usbmodule:	TCPIPLibs:sys.h.errno
o.usbmodule:	TCPIPLibs:sys.h.ioccom
o.usbmodule:	^.dev.usb.h.usbdi
o.usbmodule:	TCPIPLibs:sys.h.cdefs
o.usbmodule:	^.dev.usb.h.usbdi_util
o.usbmodule:	^.dev.usb.h.usbdivar
o.usbmodule:	^.dev.usb.h.usbhid
o.usbmodule:	^.dev.usb.h.usb_quirks
o.usbmodule:	h.USBDriverHdr
o.usbmodule:	C:h.kernel
o.usbmodule:	C:h.swis
o.usbmodule:	C:debuglib.h.debuglib
o.usbmodule:	C:callx.h.callx
o.usbmodule:	C:h.kernel
o.usbmodule:	OS:oslib.h.devicefs
o.usbmodule:	OS:oslib.h.types
o.usbmodule:	OS:oslib.h.os
o.usbmodule:	OS:oslib.h.oscore32
o.usbmodule:	OS:oslib.h.osf32
o.usbmodule:	OS:oslib.h.osargs
o.usbmodule:	OS:oslib.h.fileswitch
o.usbmodule:	OS:oslib.h.fileswch32
o.usbmodule:	OS:oslib.h.osargs32
o.usbmodule:	OS:oslib.h.buffer
o.usbmodule:	OS:oslib.h.devicefs32
o.usbmodule:	tbox:h.toolbox
o.usbmodule:	tbox:h.wimp
o.usbmodule:	h.bufman
o.usbmodule:	C:h.kernel
o.usbmodule:	h.usbmouse
o.usbmodule:	h.usbkboard
o.usbmodule:	h.USBDevFS
o.port:	c.port
o.port:	C:DebugLib.h.DebugLib
o.port:	C:callx.h.callx
o.port:	C:h.kernel
o.port:	C:h.swis
o.port:	TCPIPLibs:sys.h.callout
o.port:	TCPIPLibs:sys.h.queue
o.port:	TCPIPLibs:sys.h.time
o.port:	C:Global.h.HALEntries
o.port:	C:Global.h.OSMisc
o.port:	TCPIPLibs:sys.h.types
o.port:	TCPIPLibs:sys.h.cdefs
o.port:	TCPIPLibs:machine.h.endian
o.port:	TCPIPLibs:machine.h.ansi
o.port:	TCPIPLibs:machine.h.types
o.port:	^.dev.usb.h.usb_port
o.port:	^.sys.h.device
o.port:	TCPIPLibs:sys.h.queue
o.port:	TCPIPLibs:h.errno
o.port:	TCPIPLibs:sys.h.errno
o.port:	TCPIPLibs:sys.h.ioccom
o.usb:	^.dev.usb.c.usb
o.usb:	TCPIPLibs:sys.h.cdefs
o.usb:	TCPIPLibs:sys.h.param
o.usb:	TCPIPLibs:sys.h.types
o.usb:	TCPIPLibs:sys.h.cdefs
o.usb:	TCPIPLibs:machine.h.endian
o.usb:	TCPIPLibs:machine.h.ansi
o.usb:	TCPIPLibs:machine.h.types
o.usb:	TCPIPLibs:sys.h.syslimits
o.usb:	TCPIPLibs:sys.h.cdefs
o.usb:	TCPIPLibs:sys.h.errno
o.usb:	TCPIPLibs:sys.h.time
o.usb:	TCPIPLibs:sys.h.resource
o.usb:	TCPIPLibs:sys.h.types
o.usb:	TCPIPLibs:sys.h.ucred
o.usb:	TCPIPLibs:sys.h.uio
o.usb:	TCPIPLibs:sys.h.rtprio
o.usb:	TCPIPLibs:sys.h.signal
o.usb:	TCPIPLibs:machine.h.signal
o.usb:	TCPIPLibs:machine.h.param
o.usb:	TCPIPLibs:machine.h.limits
o.usb:	TCPIPLibs:sys.h.systm
o.usb:	TCPIPLibs:machine.h.cpufunc
o.usb:	TCPIPLibs:machine.h.stdarg
o.usb:	TCPIPLibs:sys.h.callout
o.usb:	TCPIPLibs:sys.h.queue
o.usb:	TCPIPLibs:sys.h.kernel
o.usb:	TCPIPLibs:sys.h.linker_set
o.usb:	TCPIPLibs:sys.h.malloc
o.usb:	^.sys.h.device
o.usb:	TCPIPLibs:sys.h.queue
o.usb:	TCPIPLibs:sys.h.proc
o.usb:	TCPIPLibs:machine.h.proc
o.usb:	TCPIPLibs:sys.h.queue
o.usb:	TCPIPLibs:sys.h.rtprio
o.usb:	TCPIPLibs:sys.h.select
o.usb:	TCPIPLibs:sys.h.time
o.usb:	TCPIPLibs:sys.h.conf
o.usb:	TCPIPLibs:sys.h.fcntl
o.usb:	^.sys.h.poll
o.usb:	TCPIPLibs:sys.h.select
o.usb:	TCPIPLibs:sys.h.vnode
o.usb:	TCPIPLibs:sys.h.queue
o.usb:	TCPIPLibs:sys.h.signalvar
o.usb:	^.dev.usb.h.usb
o.usb:	TCPIPLibs:sys.h.types
o.usb:	TCPIPLibs:sys.h.time
o.usb:	^.dev.usb.h.usb_port
o.usb:	^.sys.h.device
o.usb:	TCPIPLibs:h.errno
o.usb:	TCPIPLibs:sys.h.ioccom
o.usb:	^.dev.usb.h.usbdi
o.usb:	TCPIPLibs:sys.h.cdefs
o.usb:	^.dev.usb.h.usbdi_util
o.usb:	^.machine.h.bus
o.usb:	TCPIPLibs:sys.h.types
o.usb:	^.dev.usb.h.usbdivar
o.usb:	^.dev.usb.h.usb_quirks
o.usbdi:	^.dev.usb.c.usbdi
o.usbdi:	TCPIPLibs:sys.h.cdefs
o.usbdi:	TCPIPLibs:sys.h.param
o.usbdi:	TCPIPLibs:sys.h.types
o.usbdi:	TCPIPLibs:sys.h.cdefs
o.usbdi:	TCPIPLibs:machine.h.endian
o.usbdi:	TCPIPLibs:machine.h.ansi
o.usbdi:	TCPIPLibs:machine.h.types
o.usbdi:	TCPIPLibs:sys.h.syslimits
o.usbdi:	TCPIPLibs:sys.h.cdefs
o.usbdi:	TCPIPLibs:sys.h.errno
o.usbdi:	TCPIPLibs:sys.h.time
o.usbdi:	TCPIPLibs:sys.h.resource
o.usbdi:	TCPIPLibs:sys.h.types
o.usbdi:	TCPIPLibs:sys.h.ucred
o.usbdi:	TCPIPLibs:sys.h.uio
o.usbdi:	TCPIPLibs:sys.h.rtprio
o.usbdi:	TCPIPLibs:sys.h.signal
o.usbdi:	TCPIPLibs:machine.h.signal
o.usbdi:	TCPIPLibs:machine.h.param
o.usbdi:	TCPIPLibs:machine.h.limits
o.usbdi:	TCPIPLibs:sys.h.systm
o.usbdi:	TCPIPLibs:machine.h.cpufunc
o.usbdi:	TCPIPLibs:machine.h.stdarg
o.usbdi:	TCPIPLibs:sys.h.callout
o.usbdi:	TCPIPLibs:sys.h.queue
o.usbdi:	TCPIPLibs:sys.h.malloc
o.usbdi:	TCPIPLibs:sys.h.proc
o.usbdi:	TCPIPLibs:machine.h.proc
o.usbdi:	TCPIPLibs:sys.h.queue
o.usbdi:	TCPIPLibs:sys.h.rtprio
o.usbdi:	TCPIPLibs:sys.h.select
o.usbdi:	TCPIPLibs:sys.h.time
o.usbdi:	^.machine.h.bus
o.usbdi:	TCPIPLibs:sys.h.types
o.usbdi:	^.dev.usb.h.usb
o.usbdi:	TCPIPLibs:sys.h.types
o.usbdi:	TCPIPLibs:sys.h.time
o.usbdi:	^.dev.usb.h.usb_port
o.usbdi:	^.sys.h.device
o.usbdi:	TCPIPLibs:sys.h.queue
o.usbdi:	TCPIPLibs:h.errno
o.usbdi:	TCPIPLibs:sys.h.ioccom
o.usbdi:	^.dev.usb.h.usbdi
o.usbdi:	TCPIPLibs:sys.h.cdefs
o.usbdi:	^.dev.usb.h.usbdi_util
o.usbdi:	^.dev.usb.h.usbdivar
o.usbdi:	^.dev.usb.h.usb_mem
o.usbdi:	^.dev.usb.h.usb_quirks
o.usb_subr:	^.dev.usb.c.usb_subr
o.usb_subr:	TCPIPLibs:sys.h.cdefs
o.usb_subr:	TCPIPLibs:sys.h.param
o.usb_subr:	TCPIPLibs:sys.h.types
o.usb_subr:	TCPIPLibs:sys.h.cdefs
o.usb_subr:	TCPIPLibs:machine.h.endian
o.usb_subr:	TCPIPLibs:machine.h.ansi
o.usb_subr:	TCPIPLibs:machine.h.types
o.usb_subr:	TCPIPLibs:sys.h.syslimits
o.usb_subr:	TCPIPLibs:sys.h.cdefs
o.usb_subr:	TCPIPLibs:sys.h.errno
o.usb_subr:	TCPIPLibs:sys.h.time
o.usb_subr:	TCPIPLibs:sys.h.resource
o.usb_subr:	TCPIPLibs:sys.h.types
o.usb_subr:	TCPIPLibs:sys.h.ucred
o.usb_subr:	TCPIPLibs:sys.h.uio
o.usb_subr:	TCPIPLibs:sys.h.rtprio
o.usb_subr:	TCPIPLibs:sys.h.signal
o.usb_subr:	TCPIPLibs:machine.h.signal
o.usb_subr:	TCPIPLibs:machine.h.param
o.usb_subr:	TCPIPLibs:machine.h.limits
o.usb_subr:	TCPIPLibs:sys.h.systm
o.usb_subr:	TCPIPLibs:machine.h.cpufunc
o.usb_subr:	TCPIPLibs:machine.h.stdarg
o.usb_subr:	TCPIPLibs:sys.h.callout
o.usb_subr:	TCPIPLibs:sys.h.queue
o.usb_subr:	TCPIPLibs:sys.h.kernel
o.usb_subr:	TCPIPLibs:sys.h.linker_set
o.usb_subr:	TCPIPLibs:sys.h.malloc
o.usb_subr:	TCPIPLibs:sys.h.proc
o.usb_subr:	TCPIPLibs:machine.h.proc
o.usb_subr:	TCPIPLibs:sys.h.queue
o.usb_subr:	TCPIPLibs:sys.h.rtprio
o.usb_subr:	TCPIPLibs:sys.h.select
o.usb_subr:	TCPIPLibs:sys.h.time
o.usb_subr:	^.machine.h.bus
o.usb_subr:	TCPIPLibs:sys.h.types
o.usb_subr:	^.dev.usb.h.usb
o.usb_subr:	TCPIPLibs:sys.h.types
o.usb_subr:	TCPIPLibs:sys.h.time
o.usb_subr:	^.dev.usb.h.usb_port
o.usb_subr:	^.sys.h.device
o.usb_subr:	TCPIPLibs:sys.h.queue
o.usb_subr:	TCPIPLibs:h.errno
o.usb_subr:	TCPIPLibs:sys.h.ioccom
o.usb_subr:	^.dev.usb.h.usbdi
o.usb_subr:	TCPIPLibs:sys.h.cdefs
o.usb_subr:	^.dev.usb.h.usbdi_util
o.usb_subr:	^.dev.usb.h.usbdivar
o.usb_subr:	^.dev.usb.h.usbdevs
o.usb_subr:	^.dev.usb.h.usb_quirks
o.usbdi_util:	^.dev.usb.c.usbdi_util
o.usbdi_util:	TCPIPLibs:sys.h.cdefs
o.usbdi_util:	TCPIPLibs:sys.h.param
o.usbdi_util:	TCPIPLibs:sys.h.types
o.usbdi_util:	TCPIPLibs:sys.h.cdefs
o.usbdi_util:	TCPIPLibs:machine.h.endian
o.usbdi_util:	TCPIPLibs:machine.h.ansi
o.usbdi_util:	TCPIPLibs:machine.h.types
o.usbdi_util:	TCPIPLibs:sys.h.syslimits
o.usbdi_util:	TCPIPLibs:sys.h.cdefs
o.usbdi_util:	TCPIPLibs:sys.h.errno
o.usbdi_util:	TCPIPLibs:sys.h.time
o.usbdi_util:	TCPIPLibs:sys.h.resource
o.usbdi_util:	TCPIPLibs:sys.h.types
o.usbdi_util:	TCPIPLibs:sys.h.ucred
o.usbdi_util:	TCPIPLibs:sys.h.uio
o.usbdi_util:	TCPIPLibs:sys.h.rtprio
o.usbdi_util:	TCPIPLibs:sys.h.signal
o.usbdi_util:	TCPIPLibs:machine.h.signal
o.usbdi_util:	TCPIPLibs:machine.h.param
o.usbdi_util:	TCPIPLibs:machine.h.limits
o.usbdi_util:	TCPIPLibs:sys.h.systm
o.usbdi_util:	TCPIPLibs:machine.h.cpufunc
o.usbdi_util:	TCPIPLibs:machine.h.stdarg
o.usbdi_util:	TCPIPLibs:sys.h.callout
o.usbdi_util:	TCPIPLibs:sys.h.queue
o.usbdi_util:	TCPIPLibs:sys.h.kernel
o.usbdi_util:	TCPIPLibs:sys.h.linker_set
o.usbdi_util:	TCPIPLibs:sys.h.malloc
o.usbdi_util:	TCPIPLibs:sys.h.proc
o.usbdi_util:	TCPIPLibs:machine.h.proc
o.usbdi_util:	TCPIPLibs:sys.h.queue
o.usbdi_util:	TCPIPLibs:sys.h.rtprio
o.usbdi_util:	TCPIPLibs:sys.h.select
o.usbdi_util:	TCPIPLibs:sys.h.time
o.usbdi_util:	^.sys.h.device
o.usbdi_util:	TCPIPLibs:sys.h.queue
o.usbdi_util:	^.dev.usb.h.usb
o.usbdi_util:	TCPIPLibs:sys.h.types
o.usbdi_util:	TCPIPLibs:sys.h.time
o.usbdi_util:	^.dev.usb.h.usb_port
o.usbdi_util:	^.sys.h.device
o.usbdi_util:	TCPIPLibs:h.errno
o.usbdi_util:	TCPIPLibs:sys.h.ioccom
o.usbdi_util:	^.dev.usb.h.usbhid
o.usbdi_util:	^.dev.usb.h.usbdi
o.usbdi_util:	TCPIPLibs:sys.h.cdefs
o.usbdi_util:	^.dev.usb.h.usbdi_util
o.usb_quirks:	^.dev.usb.c.usb_quirks
o.usb_quirks:	TCPIPLibs:sys.h.cdefs
o.usb_quirks:	TCPIPLibs:sys.h.param
o.usb_quirks:	TCPIPLibs:sys.h.types
o.usb_quirks:	TCPIPLibs:sys.h.cdefs
o.usb_quirks:	TCPIPLibs:machine.h.endian
o.usb_quirks:	TCPIPLibs:machine.h.ansi
o.usb_quirks:	TCPIPLibs:machine.h.types
o.usb_quirks:	TCPIPLibs:sys.h.syslimits
o.usb_quirks:	TCPIPLibs:sys.h.cdefs
o.usb_quirks:	TCPIPLibs:sys.h.errno
o.usb_quirks:	TCPIPLibs:sys.h.time
o.usb_quirks:	TCPIPLibs:sys.h.resource
o.usb_quirks:	TCPIPLibs:sys.h.types
o.usb_quirks:	TCPIPLibs:sys.h.ucred
o.usb_quirks:	TCPIPLibs:sys.h.uio
o.usb_quirks:	TCPIPLibs:sys.h.rtprio
o.usb_quirks:	TCPIPLibs:sys.h.signal
o.usb_quirks:	TCPIPLibs:machine.h.signal
o.usb_quirks:	TCPIPLibs:machine.h.param
o.usb_quirks:	TCPIPLibs:machine.h.limits
o.usb_quirks:	TCPIPLibs:sys.h.systm
o.usb_quirks:	TCPIPLibs:machine.h.cpufunc
o.usb_quirks:	TCPIPLibs:machine.h.stdarg
o.usb_quirks:	TCPIPLibs:sys.h.callout
o.usb_quirks:	TCPIPLibs:sys.h.queue
o.usb_quirks:	^.dev.usb.h.usb
o.usb_quirks:	TCPIPLibs:sys.h.types
o.usb_quirks:	TCPIPLibs:sys.h.time
o.usb_quirks:	^.dev.usb.h.usb_port
o.usb_quirks:	^.sys.h.device
o.usb_quirks:	TCPIPLibs:sys.h.queue
o.usb_quirks:	TCPIPLibs:h.errno
o.usb_quirks:	TCPIPLibs:sys.h.ioccom
o.usb_quirks:	^.dev.usb.h.usbdevs
o.usb_quirks:	^.dev.usb.h.usb_quirks
o.uhub:	^.dev.usb.c.uhub
o.uhub:	TCPIPLibs:sys.h.cdefs
o.uhub:	TCPIPLibs:sys.h.param
o.uhub:	TCPIPLibs:sys.h.types
o.uhub:	TCPIPLibs:sys.h.cdefs
o.uhub:	TCPIPLibs:machine.h.endian
o.uhub:	TCPIPLibs:machine.h.ansi
o.uhub:	TCPIPLibs:machine.h.types
o.uhub:	TCPIPLibs:sys.h.syslimits
o.uhub:	TCPIPLibs:sys.h.cdefs
o.uhub:	TCPIPLibs:sys.h.errno
o.uhub:	TCPIPLibs:sys.h.time
o.uhub:	TCPIPLibs:sys.h.resource
o.uhub:	TCPIPLibs:sys.h.types
o.uhub:	TCPIPLibs:sys.h.ucred
o.uhub:	TCPIPLibs:sys.h.uio
o.uhub:	TCPIPLibs:sys.h.rtprio
o.uhub:	TCPIPLibs:sys.h.signal
o.uhub:	TCPIPLibs:machine.h.signal
o.uhub:	TCPIPLibs:machine.h.param
o.uhub:	TCPIPLibs:machine.h.limits
o.uhub:	TCPIPLibs:sys.h.systm
o.uhub:	TCPIPLibs:machine.h.cpufunc
o.uhub:	TCPIPLibs:machine.h.stdarg
o.uhub:	TCPIPLibs:sys.h.callout
o.uhub:	TCPIPLibs:sys.h.queue
o.uhub:	TCPIPLibs:sys.h.kernel
o.uhub:	TCPIPLibs:sys.h.linker_set
o.uhub:	TCPIPLibs:sys.h.malloc
o.uhub:	^.machine.h.bus
o.uhub:	TCPIPLibs:sys.h.types
o.uhub:	^.dev.usb.h.usb
o.uhub:	TCPIPLibs:sys.h.types
o.uhub:	TCPIPLibs:sys.h.time
o.uhub:	^.dev.usb.h.usb_port
o.uhub:	^.sys.h.device
o.uhub:	TCPIPLibs:sys.h.queue
o.uhub:	TCPIPLibs:h.errno
o.uhub:	TCPIPLibs:sys.h.ioccom
o.uhub:	^.dev.usb.h.usbdi
o.uhub:	TCPIPLibs:sys.h.cdefs
o.uhub:	^.dev.usb.h.usbdi_util
o.uhub:	^.dev.usb.h.usbdivar
o.usbmouse:	c.usbmouse
o.usbmouse:	C:Global.h.RISCOS
o.usbmouse:	C:Global.h.Keyboard
o.usbmouse:	C:Global.h.Pointer
o.usbmouse:	C:Global.h.VduExt
o.usbmouse:	h.USBDriverHdr
o.usbmouse:	C:h.kernel
o.usbmouse:	C:h.swis
o.usbmouse:	C:debuglib.h.debuglib
o.usbmouse:	C:callx.h.callx
o.usbmouse:	C:h.kernel
o.usbmouse:	TCPIPLibs:sys.h.callout
o.usbmouse:	TCPIPLibs:sys.h.queue
o.usbmouse:	TCPIPLibs:sys.h.ioctl
o.usbmouse:	TCPIPLibs:sys.h.ttycom
o.usbmouse:	TCPIPLibs:sys.h.ioccom
o.usbmouse:	TCPIPLibs:sys.h.ioccom
o.usbmouse:	TCPIPLibs:sys.h.filio
o.usbmouse:	TCPIPLibs:sys.h.ioccom
o.usbmouse:	TCPIPLibs:sys.h.sockio
o.usbmouse:	TCPIPLibs:sys.h.ioccom
o.usbmouse:	^.dev.usb.h.usb
o.usbmouse:	TCPIPLibs:sys.h.types
o.usbmouse:	TCPIPLibs:sys.h.cdefs
o.usbmouse:	TCPIPLibs:machine.h.endian
o.usbmouse:	TCPIPLibs:machine.h.ansi
o.usbmouse:	TCPIPLibs:machine.h.types
o.usbmouse:	TCPIPLibs:sys.h.time
o.usbmouse:	^.dev.usb.h.usb_port
o.usbmouse:	^.sys.h.device
o.usbmouse:	TCPIPLibs:sys.h.queue
o.usbmouse:	TCPIPLibs:h.errno
o.usbmouse:	TCPIPLibs:sys.h.errno
o.usbmouse:	TCPIPLibs:sys.h.ioccom
o.usbmouse:	^.dev.usb.h.usbhid
o.usbmouse:	^.dev.usb.h.usbdi
o.usbmouse:	TCPIPLibs:sys.h.cdefs
o.usbmouse:	^.dev.usb.h.usbdi_util
o.usbmouse:	^.dev.usb.h.usbdivar
o.usbmouse:	^.dev.usb.h.usbdevs
o.usbmouse:	^.dev.usb.h.usb_quirks
o.usbmouse:	^.dev.usb.h.hid
o.usbmouse:	h.usbmouse
o.usbmouse:	tbox:h.wimplib
o.usbmouse:	tbox:h.wimp
o.usbkboard:	c.usbkboard
o.usbkboard:	C:Global.h.RISCOS
o.usbkboard:	C:Global.h.Keyboard
o.usbkboard:	C:Global.h.Pointer
o.usbkboard:	C:callx.h.callx
o.usbkboard:	C:h.kernel
o.usbkboard:	h.USBDriverHdr
o.usbkboard:	C:h.swis
o.usbkboard:	C:debuglib.h.debuglib
o.usbkboard:	TCPIPLibs:sys.h.callout
o.usbkboard:	TCPIPLibs:sys.h.queue
o.usbkboard:	TCPIPLibs:sys.h.ioctl
o.usbkboard:	TCPIPLibs:sys.h.ttycom
o.usbkboard:	TCPIPLibs:sys.h.ioccom
o.usbkboard:	TCPIPLibs:sys.h.ioccom
o.usbkboard:	TCPIPLibs:sys.h.filio
o.usbkboard:	TCPIPLibs:sys.h.ioccom
o.usbkboard:	TCPIPLibs:sys.h.sockio
o.usbkboard:	TCPIPLibs:sys.h.ioccom
o.usbkboard:	^.dev.usb.h.usb
o.usbkboard:	TCPIPLibs:sys.h.types
o.usbkboard:	TCPIPLibs:sys.h.cdefs
o.usbkboard:	TCPIPLibs:machine.h.endian
o.usbkboard:	TCPIPLibs:machine.h.ansi
o.usbkboard:	TCPIPLibs:machine.h.types
o.usbkboard:	TCPIPLibs:sys.h.time
o.usbkboard:	^.dev.usb.h.usb_port
o.usbkboard:	^.sys.h.device
o.usbkboard:	TCPIPLibs:sys.h.queue
o.usbkboard:	TCPIPLibs:h.errno
o.usbkboard:	TCPIPLibs:sys.h.errno
o.usbkboard:	TCPIPLibs:sys.h.ioccom
o.usbkboard:	^.dev.usb.h.usbdi
o.usbkboard:	TCPIPLibs:sys.h.cdefs
o.usbkboard:	^.dev.usb.h.usbdi_util
o.usbkboard:	^.dev.usb.h.usbdivar
o.usbkboard:	^.dev.usb.h.usbhid
o.usbkboard:	h.usbkboard
o.usbkboard:	tbox:h.wimplib
o.usbkboard:	tbox:h.wimp
o.hid:	^.dev.usb.c.hid
o.hid:	TCPIPLibs:sys.h.cdefs
o.hid:	TCPIPLibs:sys.h.param
o.hid:	TCPIPLibs:sys.h.types
o.hid:	TCPIPLibs:sys.h.cdefs
o.hid:	TCPIPLibs:machine.h.endian
o.hid:	TCPIPLibs:machine.h.ansi
o.hid:	TCPIPLibs:machine.h.types
o.hid:	TCPIPLibs:sys.h.syslimits
o.hid:	TCPIPLibs:sys.h.cdefs
o.hid:	TCPIPLibs:sys.h.errno
o.hid:	TCPIPLibs:sys.h.time
o.hid:	TCPIPLibs:sys.h.resource
o.hid:	TCPIPLibs:sys.h.types
o.hid:	TCPIPLibs:sys.h.ucred
o.hid:	TCPIPLibs:sys.h.uio
o.hid:	TCPIPLibs:sys.h.rtprio
o.hid:	TCPIPLibs:sys.h.signal
o.hid:	TCPIPLibs:machine.h.signal
o.hid:	TCPIPLibs:machine.h.param
o.hid:	TCPIPLibs:machine.h.limits
o.hid:	TCPIPLibs:sys.h.systm
o.hid:	TCPIPLibs:machine.h.cpufunc
o.hid:	TCPIPLibs:machine.h.stdarg
o.hid:	TCPIPLibs:sys.h.callout
o.hid:	TCPIPLibs:sys.h.queue
o.hid:	TCPIPLibs:sys.h.malloc
o.hid:	^.dev.usb.h.usb
o.hid:	TCPIPLibs:sys.h.types
o.hid:	TCPIPLibs:sys.h.time
o.hid:	^.dev.usb.h.usb_port
o.hid:	^.sys.h.device
o.hid:	TCPIPLibs:sys.h.queue
o.hid:	TCPIPLibs:h.errno
o.hid:	TCPIPLibs:sys.h.ioccom
o.hid:	^.dev.usb.h.usbhid
o.hid:	^.dev.usb.h.hid
o.bufman: s.bufman
o.triggercbs: s.triggercbs
o.triggercbs: Hdr:ListOpts
o.triggercbs: Hdr:PublicWS
o.triggercbs: Hdr:Macros
o.triggercbs: Hdr:System
o.triggercbs: Hdr:SWIs
o.triggercbs: Hdr:CPU.Arch
o.triggercbs: Hdr:Machine.<Machine>
o.triggercbs: Hdr:Machine.Machine
o.triggercbs: Hdr:CPU.Generic26
o.triggercbs: Hdr:CPU.Generic32
o.triggercbs: Hdr:IO.GenericIO
o.triggercbs: Hdr:RISCOS
o.triggercbs: Hdr:OSRSI6
o.triggercbs: Hdr:Proc
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
o.USBDriverHdr:	cmhg.USBDriverHdr
o.USBDriverHdr:	C:Global.h.Services
o.USBDriverHdr:	^.VersionNum
