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
# Makefile for Floating Point Accelerator Support Code (FPASC)

COMPONENT ?= FPEmulator
SA_MODULE  = FPERAM${SUFFIX_MODULE}
ifeq (,${MAKE_VERSION})
ROM_SOURCE = s.${MACHINE}
else
ROM_SOURCE = ${MACHINE}.s
endif
HEADER1    = FPEmulator

FPEANCHOR ?= Low
# 32bit-compatible RAM builds store FPEAnchor locally, so that they're compatible with kernels which use high or low zero page workspace. But this means the module must write to its own image to set its workspace pointer.
# 26bit-only builds can stick with the legacy low FPEAnchor location, avoiding the need for the module to self-modify.
ifeq (${FPE_APCS},3/26bit)
FPEANCHOR_RAM ?= Low
else
FPEANCHOR_RAM ?= Local
endif

ifeq (,$(filter ${MAKECMDGOALS},rom install_rom))
ASFLAGS += -PD "FPEAnchorType SETS \"${FPEANCHOR_RAM}\""
else
ASFLAGS += -PD "FPEAnchorType SETS \"${FPEANCHOR}\""
endif
ASFLAGS += -APCS ${FPE_APCS}

ifeq (,${MAKE_VERSION})
ASFLAGS += -PD "CoreDir SETS \"^.coresrc.s.\"" -PD "VeneerDir SETS \"^.vensrc.riscos.\"" -PD "FileExt SETS \"\""   -I^
else
ASFLAGS += -PD "CoreDir SETS \"coresrc/\""     -PD "VeneerDir SETS \"vensrc/riscos/\""   -PD "FileExt SETS \".s\""
# The layout of source files in this component is rather non-standard!

SYMLINK_DEPEND = symlink_extra
symlink_extra:
	$(foreach linksource,$(wildcard ../coresrc/s/*), \
		$(shell \
			leaf=`basename ${linksource}`; \
			[ -d ${linksource} ] || [ -L objs/coresrc/$$leaf.s ] || mkdir -p objs/coresrc; \
			[ -d ${linksource} ] || [ -L objs/coresrc/$$leaf.s ] || ln -s ../../${linksource} objs/coresrc/$$leaf.s; \
		) \
	)
	$(foreach linksource,$(wildcard ../vensrc/riscos/*), \
		$(shell \
			leaf=`basename ${linksource}`; \
			[ -d ${linksource} ] || [ -L objs/vensrc/riscos/$$leaf.s ] || mkdir -p objs/vensrc/riscos; \
			[ -d ${linksource} ] || [ -L objs/vensrc/riscos/$$leaf.s ] || ln -s ../../../${linksource} objs/vensrc/riscos/$$leaf.s; \
		) \
	)
	@[ -L objs/VersionASM ] || ln -s ../../VersionASM objs/VersionASM
endif

include AAsmModule

# Dynamic dependencies:
o.CortexA7.FPEmulator: s.CortexA7
o.CortexA7.FPEmulator: ^.coresrc.s.main
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.s.defaults
o.CortexA7.FPEmulator: ^.coresrc.^.vensrc.riscos.options
o.CortexA7.FPEmulator: <Hdr$Dir>.Global.ListOpts
o.CortexA7.FPEmulator: <Hdr$Dir>.Global.Macros
o.CortexA7.FPEmulator: <Hdr$Dir>.Global.Services
o.CortexA7.FPEmulator: <Hdr$Dir>.Interface.ModHand
o.CortexA7.FPEmulator: <Hdr$Dir>.Interface.EnvNumbers
o.CortexA7.FPEmulator: ^.coresrc.^.vensrc.riscos.FPEMacros
o.CortexA7.FPEmulator: ^.VersionASM
o.CortexA7.FPEmulator: <Hdr$Dir>.Interface.PublicWS
o.CortexA7.FPEmulator: <Hdr$Dir>.Interface.OSRSI6
o.CortexA7.FPEmulator: <Hdr$Dir>.Global.SWIs
o.CortexA7.FPEmulator: ^.RISCOS
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.s.optcheck
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.s.regnames
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.s.armdefs
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.s.fpadefs
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.s.wsdefs
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.vensrc.riscos.ctxtws
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.vensrc.riscos.globalws
o.CortexA7.FPEmulator: ^.coresrc.^.vensrc.riscos.start
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.s.toplevel
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.coresrc.s.macros
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.coresrc.s.fpaundef
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.coresrc.s.fpeundef
o.CortexA7.FPEmulator: <Hdr$Dir>.Global.CPU.Arch
o.CortexA7.FPEmulator: Hdr:Machine.<Machine>
o.CortexA7.FPEmulator: Hdr:Machine.Machine
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.coresrc.s.ldst
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.coresrc.s.rounding
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.coresrc.s.nans
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.coresrc.s.arith
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.coresrc.s.transhw
o.CortexA7.FPEmulator: ^.coresrc.^.coresrc.^.coresrc.s.interf
o.CortexA7.FPEmulator: ^.coresrc.^.vensrc.riscos.end
