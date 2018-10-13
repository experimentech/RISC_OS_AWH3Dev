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
# Makefile for SPI driver
#

COMPONENT    = SPIDriver
OBJS         = module spi asm
CMHGDEPENDS  = module spi
CMHGFILE     = header
ASMHDRS      = SPIDriver SPIDevice
ASMCHDRS     = SPIDriver SPIDevice
HDRS         = 
CFLAGS       = -We
CDFLAGS      = -DDEBUGLIB
LIBS         = ${CALLXLIB} ${ASMUTILS}
ROMCDEFINES  = -DROM
ifeq ("${CMDHELP}","None")
CMHGDEFINES += -DNO_INTERNATIONAL_HELP
endif

include CModule

DBG_LIBS    += ${NET5LIBS}

expasmc.SPIDriver: hdr.SPIDriver h.SPIDriver
	${HDR2H} hdr.SPIDriver ${C_EXP_HDR}.SPIDriver
	FAppend ${C_EXP_HDR}.SPIDriver h.SPIDriver ${C_EXP_HDR}.SPIDriver



# Dynamic dependencies:
o.module:	c.module
o.module:	C:h.swis
o.module:	C:h.kernel
o.module:	C:debuglib.h.debuglib
o.module:	C:callx.h.callx
o.module:	C:h.kernel
o.module:	C:Global.h.Services
o.module:	C:Global.h.HALDevice
o.module:	C:Interface.h.SPIDriver
o.module:	h.header
o.module:	h.spi
o.module:	h.module
o.module:	h.asm
o.spi:	c.spi
o.spi:	C:h.swis
o.spi:	C:h.kernel
o.spi:	C:debuglib.h.debuglib
o.spi:	C:callx.h.callx
o.spi:	C:h.kernel
o.spi:	C:Global.h.Services
o.spi:	C:Global.h.HALDevice
o.spi:	C:Interface.h.SPIDriver
o.spi:	h.header
o.spi:	h.spi
o.spi:	h.module
o.spi:	h.asm
h.header:	cmhg.header
h.header:	VersionNum
h.header:	C:Global.h.Services
o.asm: s.asm
o.asm: <Hdr$Dir>.Global.ListOpts
o.asm: <Hdr$Dir>.Global.Macros
o.asm: <Hdr$Dir>.Global.System
o.asm: Hdr:SWIs
o.asm: Hdr:CPU.Arch
o.asm: Hdr:Machine.<Machine>
o.asm: Hdr:Machine.Machine
o.asm: Hdr:CPU.Generic26
o.asm: Hdr:CPU.Generic32
o.asm: Hdr:IO.GenericIO
o.asm: Hdr:RISCOS
o.asm: <Hdr$Dir>.Interface.OSMisc
o.header:	cmhg.header
o.header:	VersionNum
o.header:	C:Global.h.Services
