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
# Makefile for Kernel
#

COMPONENT       = Kernel

ifeq (${MAKECMDGOALS},install)
EXP_HDR         = ${INSTDIR}.Hdr.Interface
C_EXP_HDR       = ${INSTDIR}.C.Global.h
else
C_EXP_HDR       = <cexport$dir>.Global.h
endif

TOKHELPSRC      = ${TOKENSOURCE}
HELPSRC         = HelpStrs
ROM_SOURCE      = GetAll.s
KERNEL_MODULE   = bin${SEP}${COMPONENT}
ASFLAGS        += -PD "FreezeDevRel SETL {${FREEZE_DEV_REL}}"
CUSTOMROM       = custom
CUSTOMEXP       = custom
CUSTOMSA        = custom
EXPORTS         = ${EXP_HDR}.EnvNumbers \
                  ${EXP_HDR}.HALDevice \
                  ${EXP_HDR}.HALEntries \
                  ${EXP_HDR}.ModHand \
                  ${EXP_HDR}.OSEntries \
                  ${EXP_HDR}.OSMem \
                  ${EXP_HDR}.OSMisc \
                  ${EXP_HDR}.OSRSI6 \
                  ${EXP_HDR}.PL310 \
                  ${EXP_HDR}.PublicWS \
                  ${EXP_HDR}.RISCOS \
                  ${EXP_HDR}.Variables \
                  ${EXP_HDR}.VduExt \
                  ${EXP_HDR}.VIDCList \
                  ${EXP_HDR}.VideoDevice \
                  ${C_EXP_HDR}.HALDevice \
                  ${C_EXP_HDR}.HALEntries \
                  ${C_EXP_HDR}.ModHand \
                  ${C_EXP_HDR}.OSEntries \
                  ${C_EXP_HDR}.OSMem \
                  ${C_EXP_HDR}.OSMisc \
                  ${C_EXP_HDR}.OSRSI6 \
                  ${C_EXP_HDR}.RISCOS \
                  ${C_EXP_HDR}.Variables \
                  ${C_EXP_HDR}.VduExt \
                  ${C_EXP_HDR}.VIDCList

include StdTools
include AAsmModule

# Override this to "TRUE" in the components file if
# you want an odd-numbered (development) build to be
# a 'freezable' build - e.g. with no ROM debug output
FREEZE_DEV_REL ?= FALSE

#
# Custom ROM:
#
rom: ${KERNEL_MODULE}
        @${ECHO} ${COMPONENT}: rom module built

install_rom: ${KERNEL_MODULE}
        ${CP} ${KERNEL_MODULE} ${INSTDIR}${SEP}${TARGET} ${CPFLAGS}
        ${CP} ${KERNEL_MODULE}_gpa ${INSTDIR}${SEP}${TARGET}_gpa ${CPFLAGS}
        @${ECHO} ${COMPONENT}: rom module installed

inst_dirs:
        ${MKDIR} ${EXP_HDR}
        ${MKDIR} ${C_EXP_HDR}

install: ${EXPORTS} inst_dirs
        @${ECHO} ${COMPONENT}: header files installed

${KERNEL_MODULE}: ${ROM_OBJECT} ${DIRS}
        ${MKDIR} bin
        ${LD} -bin -o $@ ${ROM_OBJECT}
        ${LD} -aif -bin -d -o ${KERNEL_MODULE}_aif ${ROM_OBJECT}
        ${TOGPA} -s ${KERNEL_MODULE}_aif ${KERNEL_MODULE}_gpa

#
# Custom exports:
#
export: ${EXPORTS}
        @${ECHO} ${COMPONENT}: export complete

${EXP_HDR}.EnvNumbers: hdr.EnvNumbers
        ${CP} hdr.EnvNumbers $@ ${CPFLAGS}

${EXP_HDR}.HALDevice: hdr.HALDevice
        ${CP} hdr.HALDevice $@ ${CPFLAGS}

${EXP_HDR}.HALEntries: hdr.HALEntries
        ${CP} hdr.HALEntries $@ ${CPFLAGS}

${EXP_HDR}.ModHand: hdr.ModHand
        ${CP} hdr.ModHand $@ ${CPFLAGS}

${EXP_HDR}.OSEntries: hdr.OSEntries
        ${CP} hdr.OSEntries $@ ${CPFLAGS}

${EXP_HDR}.OSMem: hdr.OSMem
        ${CP} hdr.OSMem $@ ${CPFLAGS}

${EXP_HDR}.OSMisc: hdr.OSMisc
        ${CP} hdr.OSMisc $@ ${CPFLAGS}

${EXP_HDR}.OSRSI6: hdr.OSRSI6
        ${CP} hdr.OSRSI6 $@ ${CPFLAGS}

${EXP_HDR}.PL310: hdr.PL310
        ${CP} hdr.PL310 $@ ${CPFLAGS}

${EXP_HDR}.PublicWS: hdr.PublicWS
        ${CP} hdr.PublicWS $@ ${CPFLAGS}

${EXP_HDR}.RISCOS: hdr.RISCOS
        ${CP} hdr.RISCOS $@ ${CPFLAGS}

${EXP_HDR}.Variables: hdr.Variables
        ${CP} hdr.Variables $@ ${CPFLAGS}

${EXP_HDR}.VduExt: hdr.VduExt
        ${CP} hdr.VduExt $@ ${CPFLAGS}

${EXP_HDR}.VIDCList: hdr.VIDCList
        ${CP} hdr.VIDCList $@ ${CPFLAGS}

${EXP_HDR}.VideoDevice: hdr.VideoDevice
        ${CP} hdr.VideoDevice $@ ${CPFLAGS}

${C_EXP_HDR}.HALDevice: Global.h.HALDevice h.HALDevice
        ${FAPPEND} $@ h.HALDevice Global.h.HALDevice

${C_EXP_HDR}.HALEntries: hdr.HALEntries
        ${MKDIR} ${C_EXP_HDR}
        ${HDR2H} hdr.HALEntries $@

${C_EXP_HDR}.ModHand: hdr.ModHand
        ${MKDIR} ${C_EXP_HDR}
        ${HDR2H} hdr.ModHand $@

${C_EXP_HDR}.OSEntries: Global.h.OSEntries h.OSEntries
        ${FAPPEND} $@ h.OSEntries Global.h.OSEntries

${C_EXP_HDR}.OSMem: hdr.OSMem
        ${MKDIR} ${C_EXP_HDR}
        ${HDR2H} hdr.OSMem $@

${C_EXP_HDR}.OSMisc: hdr.OSMisc
        ${MKDIR} ${C_EXP_HDR}
        ${HDR2H} hdr.OSMisc $@

${C_EXP_HDR}.OSRSI6: hdr.OSRSI6
        ${MKDIR} ${C_EXP_HDR}
        ${HDR2H} hdr.OSRSI6 $@

${C_EXP_HDR}.RISCOS: hdr.RISCOS
        ${MKDIR} ${C_EXP_HDR}
        ${HDR2H} hdr.RISCOS $@

${C_EXP_HDR}.Variables: hdr.Variables
        ${MKDIR} ${C_EXP_HDR}
        ${HDR2H} hdr.Variables $@

${C_EXP_HDR}.VduExt: hdr.VduExt
        ${MKDIR} ${C_EXP_HDR}
        ${HDR2H} hdr.VduExt $@

${C_EXP_HDR}.VIDCList: Global.h.VIDCList h.VIDCList
        ${FAPPEND} $@ h.VIDCList Global.h.VIDCList

Global.h.HALDevice: hdr.HALDevice
        ${MKDIR} Global.h
        ${HDR2H} hdr.HALDevice $@

Global.h.OSEntries: hdr.OSEntries
        ${MKDIR} Global.h
        ${HDR2H} hdr.OSEntries $@

Global.h.VIDCList: hdr.VIDCList
        ${MKDIR} Global.h
        ${HDR2H} hdr.VIDCList $@

clean::
        ${XWIPE} Global ${WFLAGS}
        ${XWIPE} bin    ${WFLAGS}

# Dynamic dependencies:
o.CortexA7.Kernel: s.GetAll
o.CortexA7.Kernel: Hdr:ListOpts
o.CortexA7.Kernel: Hdr:Macros
o.CortexA7.Kernel: Hdr:System
o.CortexA7.Kernel: Hdr:SWIs
o.CortexA7.Kernel: Hdr:CPU.Arch
o.CortexA7.Kernel: Hdr:Machine.<Machine>
o.CortexA7.Kernel: Hdr:Machine.Machine
o.CortexA7.Kernel: Hdr:CPU.Generic26
o.CortexA7.Kernel: Hdr:CPU.Generic32
o.CortexA7.Kernel: Hdr:IO.GenericIO
o.CortexA7.Kernel: Hdr:RISCOS
o.CortexA7.Kernel: Hdr:CPU.Arch
o.CortexA7.Kernel: Hdr:Machine.<Machine>
o.CortexA7.Kernel: Hdr:Machine.Machine
o.CortexA7.Kernel: Hdr:HALSize.<HALSize>
o.CortexA7.Kernel: Hdr:ImageSize.<ImageSize>
o.CortexA7.Kernel: Hdr:UserIF.<UserIF>
o.CortexA7.Kernel: Hdr:UserIF.UserIF
o.CortexA7.Kernel: Hdr:CPU.ARM600
o.CortexA7.Kernel: Hdr:IO.IOMD
o.CortexA7.Kernel: Hdr:IO.IOMD
o.CortexA7.Kernel: Hdr:MEMM.VMSAv6
o.CortexA7.Kernel: Hdr:VIDC.VIDC20
o.CortexA7.Kernel: hdr.Options
o.CortexA7.Kernel: Version
o.CortexA7.Kernel: VersionASM
o.CortexA7.Kernel: Hdr:CMOS
o.CortexA7.Kernel: Hdr:Heap
o.CortexA7.Kernel: Hdr:Sprite
o.CortexA7.Kernel: Hdr:PublicWS
o.CortexA7.Kernel: Hdr:KernelWS
o.CortexA7.Kernel: Hdr:HALEntries
o.CortexA7.Kernel: Hdr:HALDevice
o.CortexA7.Kernel: Hdr:OSEntries
o.CortexA7.Kernel: Hdr:Services
o.CortexA7.Kernel: Hdr:FSNumbers
o.CortexA7.Kernel: Hdr:HighFSI
o.CortexA7.Kernel: Hdr:NewErrors
o.CortexA7.Kernel: Hdr:Proc
o.CortexA7.Kernel: Hdr:KeyWS
o.CortexA7.Kernel: Hdr:RS423
o.CortexA7.Kernel: Hdr:ModHand
o.CortexA7.Kernel: Hdr:Variables
o.CortexA7.Kernel: Hdr:EnvNumbers
o.CortexA7.Kernel: Hdr:UpCall
o.CortexA7.Kernel: Hdr:Sound
o.CortexA7.Kernel: Hdr:Pointer
o.CortexA7.Kernel: Hdr:Podule
o.CortexA7.Kernel: Hdr:VduExt
o.CortexA7.Kernel: Hdr:Buffer
o.CortexA7.Kernel: Hdr:Font
o.CortexA7.Kernel: Hdr:DevNos
o.CortexA7.Kernel: Hdr:OsBytes
o.CortexA7.Kernel: Hdr:Internatio
o.CortexA7.Kernel: Hdr:Territory
o.CortexA7.Kernel: Hdr:Countries
o.CortexA7.Kernel: Hdr:Portable
o.CortexA7.Kernel: Hdr:MsgTrans
o.CortexA7.Kernel: Hdr:PaletteV
o.CortexA7.Kernel: Hdr:GraphicsV
o.CortexA7.Kernel: Hdr:VIDCList
o.CortexA7.Kernel: Hdr:Wimp
o.CortexA7.Kernel: Hdr:ColourTran
o.CortexA7.Kernel: Hdr:Debug
o.CortexA7.Kernel: Hdr:FileTypes
o.CortexA7.Kernel: Hdr:RTC
o.CortexA7.Kernel: Hdr:SerialOp
o.CortexA7.Kernel: Hdr:Keyboard
o.CortexA7.Kernel: Hdr:OSMem
o.CortexA7.Kernel: Hdr:OSMisc
o.CortexA7.Kernel: Hdr:OSRSI6
o.CortexA7.Kernel: Hdr:PL310
o.CortexA7.Kernel: hdr:HALDevice
o.CortexA7.Kernel: hdr.Copro15ops
o.CortexA7.Kernel: Hdr:CPU.Arch
o.CortexA7.Kernel: hdr.ARMops
o.CortexA7.Kernel: s.Kernel
o.CortexA7.Kernel: s.AMBControl.Options
o.CortexA7.Kernel: s.AMBControl.Workspace
o.CortexA7.Kernel: s.ARMops
o.CortexA7.Kernel: s.NewIRQs
o.CortexA7.Kernel: s.Oscli
o.CortexA7.Kernel: s.SysComms
o.CortexA7.Kernel: s.MosDict
o.CortexA7.Kernel: s.TokHelpSrc
o.CortexA7.Kernel: s.HeapMan
o.CortexA7.Kernel: s.ModHand
o.CortexA7.Kernel: s.Unsqueeze
o.CortexA7.Kernel: s.ArthurSWIs
o.CortexA7.Kernel: s.VMSAv6
o.CortexA7.Kernel: s.Exceptions
o.CortexA7.Kernel: s.ChangeDyn
o.CortexA7.Kernel: s.HAL
o.CortexA7.Kernel: s.Arthur2
o.CortexA7.Kernel: s.LibKern
o.CortexA7.Kernel: s.Utility
o.CortexA7.Kernel: s.MoreComms
o.CortexA7.Kernel: s.Convrsions
o.CortexA7.Kernel: s.MoreSWIs
o.CortexA7.Kernel: s.ExtraSWIs
o.CortexA7.Kernel: s.HeapSort
o.CortexA7.Kernel: s.Arthur3
o.CortexA7.Kernel: s.SWINaming
o.CortexA7.Kernel: s.TickEvents
o.CortexA7.Kernel: s.NewReset
o.CortexA7.Kernel: s.MsgCode
o.CortexA7.Kernel: s.Middle
o.CortexA7.Kernel: s.Super1
o.CortexA7.Kernel: s.MemInfo
o.CortexA7.Kernel: s.CPUFeatures
o.CortexA7.Kernel: s.MemMap2
o.CortexA7.Kernel: s.vdu.VduDriver
o.CortexA7.Kernel: s.vdu.VduDecl
o.CortexA7.Kernel: s.vdu.VduGrafDec
o.CortexA7.Kernel: s.vdu.VduModes
o.CortexA7.Kernel: s.vdu.VduSWIs
o.CortexA7.Kernel: s.vdu.VduPalette
o.CortexA7.Kernel: s.vdu.vdupalxx
o.CortexA7.Kernel: s.vdu.VduPlot
o.CortexA7.Kernel: s.vdu.VduGrafA
o.CortexA7.Kernel: s.vdu.VduGrafB
o.CortexA7.Kernel: s.vdu.VduGrafC
o.CortexA7.Kernel: s.vdu.VduGrafD
o.CortexA7.Kernel: s.vdu.VduGrafE
o.CortexA7.Kernel: s.vdu.VduGrafF
o.CortexA7.Kernel: s.vdu.VduGrafG
o.CortexA7.Kernel: s.vdu.VduGrafH
o.CortexA7.Kernel: s.vdu.VduGrafI
o.CortexA7.Kernel: s.vdu.VduGrafJ
o.CortexA7.Kernel: s.vdu.VduGrafK
o.CortexA7.Kernel: s.vdu.VduGrafL
o.CortexA7.Kernel: s.vdu.VduGrafV
o.CortexA7.Kernel: s.vdu.VduGrafHAL
o.CortexA7.Kernel: s.vdu.VduWrch
o.CortexA7.Kernel: s.vdu.Vdu23
o.CortexA7.Kernel: s.vdu.VduPointer
o.CortexA7.Kernel: s.vdu.Vdu5
o.CortexA7.Kernel: s.vdu.VduCurSoft
o.CortexA7.Kernel: s.vdu.VduTTX
o.CortexA7.Kernel: s.vdu.VduFontL1
o.CortexA7.Kernel: s.PMF.osinit
o.CortexA7.Kernel: s.PMF.oseven
o.CortexA7.Kernel: s.PMF.osbyte
o.CortexA7.Kernel: s.PMF.osword
o.CortexA7.Kernel: s.PMF.realtime
o.CortexA7.Kernel: s.PMF.i2cutils
o.CortexA7.Kernel: s.PMF.IIC
o.CortexA7.Kernel: s.PMF.oswrch
o.CortexA7.Kernel: s.PMF.buffer
o.CortexA7.Kernel: s.PMF.key
o.CortexA7.Kernel: s.PMF.mouse
o.CortexA7.Kernel: s.AMBControl.AMB
o.CortexA7.Kernel: s.AMBControl.main
o.CortexA7.Kernel: s.AMBControl.allocate
o.CortexA7.Kernel: s.AMBControl.deallocate
o.CortexA7.Kernel: s.AMBControl.growshrink
o.CortexA7.Kernel: s.AMBControl.handler
o.CortexA7.Kernel: s.AMBControl.mapslot
o.CortexA7.Kernel: s.AMBControl.mapsome
o.CortexA7.Kernel: s.AMBControl.readinfo
o.CortexA7.Kernel: s.AMBControl.growp
o.CortexA7.Kernel: s.AMBControl.shrinkp
o.CortexA7.Kernel: s.AMBControl.Memory
o.CortexA7.Kernel: s.AMBControl.memmap
