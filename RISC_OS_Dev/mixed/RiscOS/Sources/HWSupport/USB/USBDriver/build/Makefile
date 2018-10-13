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
