# Makefile for SDFS

COMPONENT   = SDFS
ASMHDRS     = SDFS SDFSErr
ASMCHDRS    = SDFS SDFSErr
HDRS        =
CMHGFILE    = SDFSHdr
CMHGDEPENDS = command module
OBJS        = base cardreg command discop free freeveneer globals message miscop module sdio service swi
LIBS        = ${SYNCLIB}
ROMCDEFINES = -DROM_MODULE
CLEAN_DEPEND = extra_clean

#CFLAGS     += -DDEBUG_ENABLED

#OBJS       += gpiodebug
#CFLAGS     += -DGPIODEBUG

include CModule

expasmc.SDFSErr: hdr.SDFSErr
	${HDR2H} hdr.SDFSErr ${C_EXP_HDR}.SDFSErr
	
expasm.SDFSErr: hdr.SDFSErr
	${CP} hdr.SDFSErr ${EXP_HDR}.SDFSErr ${CPFLAGS}

hdr.SDFSErr: o.SDFSErr
	${LD} -bin -o $@ o.SDFSErr
	SetType $@ Text

ifeq (,${MAKE_VERSION})

# RISC OS / amu case

clean::
	@IfThere hdr.SDFSErr Then ${ECHO} ${RM} hdr.SDFSErr
	@IfThere hdr.SDFSErr Then ${RM} hdr.SDFSErr

else

# Posix / gmake case

clean::
	${NOP}

endif

# Dynamic dependencies:
o.SDFSErr: s.SDFSErr
o.SDFSErr: <Hdr$Dir>.Global.ListOpts
o.SDFSErr: <Hdr$Dir>.Global.FSNumbers
o.SDFSErr: <Hdr$Dir>.Interface.FileCoreErr
o.base: s.base
o.cardreg:	c.cardreg
o.cardreg:	h.cardreg
o.cardreg:	h.globals
o.cardreg:	C:h.kernel
o.cardreg:	C:h.swis
o.cardreg:	C:SyncLib.h.spin
o.cardreg:	C:SyncLib.h.spinrw
o.cardreg:	h.message
o.cardreg:	C:h.kernel
o.command:	c.command
o.command:	C:h.swis
o.command:	C:h.kernel
o.command:	C:Global.h.CMOS
o.command:	C:Global.h.FSNumbers
o.command:	C:Global.h.OsBytes
o.command:	C:Global.h.RISCOS
o.command:	C:Interface.h.HighFSI
o.command:	h.SDFSHdr
o.command:	h.command
o.command:	C:h.kernel
o.command:	h.globals
o.command:	C:h.kernel
o.command:	C:h.swis
o.command:	C:SyncLib.h.spin
o.command:	C:SyncLib.h.spinrw
o.command:	h.message
o.command:	C:h.kernel
o.discop:	c.discop
o.discop:	C:h.swis
o.discop:	C:h.kernel
o.discop:	C:Global.h.NewErrors
o.discop:	C:Interface.h.FileCore
o.discop:	C:Interface.h.FileCoreErr
o.discop:	C:Interface.h.SDFSErr
o.discop:	C:Interface.h.SDIO
o.discop:	h.cardreg
o.discop:	h.discop
o.discop:	h.globals
o.discop:	C:h.kernel
o.discop:	C:h.swis
o.discop:	C:SyncLib.h.spin
o.discop:	C:SyncLib.h.spinrw
o.discop:	h.globals
o.discop:	h.message
o.discop:	C:h.kernel
o.discop:	h.sdio
o.discop:	C:h.kernel
o.discop:	h.gpiodebug
o.free:	c.free
o.free:	C:h.swis
o.free:	C:h.kernel
o.free:	C:Interface.h.Free
o.free:	h.free
o.free:	C:h.kernel
o.free:	h.globals
o.free:	C:h.kernel
o.free:	C:h.swis
o.free:	C:SyncLib.h.spin
o.free:	C:SyncLib.h.spinrw
o.freeveneer: s.freeveneer
o.freeveneer: <Hdr$Dir>.Global.ListOpts
o.freeveneer: <Hdr$Dir>.Global.Macros
o.freeveneer: <Hdr$Dir>.Global.System
o.freeveneer: Hdr:SWIs
o.freeveneer: Hdr:CPU.Arch
o.freeveneer: Hdr:Machine.<Machine>
o.freeveneer: Hdr:Machine.Machine
o.freeveneer: Hdr:CPU.Generic26
o.freeveneer: Hdr:CPU.Generic32
o.freeveneer: Hdr:IO.GenericIO
o.freeveneer: Hdr:RISCOS
o.freeveneer: <Hdr$Dir>.Global.APCS.APCS-32
o.freeveneer: Hdr:APCS.Common
o.globals:	c.globals
o.globals:	h.globals
o.globals:	C:h.kernel
o.globals:	C:h.swis
o.globals:	C:SyncLib.h.spin
o.globals:	C:SyncLib.h.spinrw
o.message:	c.message
o.message:	C:h.kernel
o.message:	C:h.swis
o.message:	h.globals
o.message:	C:h.kernel
o.message:	C:h.swis
o.message:	C:SyncLib.h.spin
o.message:	C:SyncLib.h.spinrw
o.message:	h.message
o.message:	C:h.kernel
o.miscop:	c.miscop
o.miscop:	C:Interface.h.FileCore
o.miscop:	C:Interface.h.FileCoreErr
o.miscop:	C:Interface.h.SDIO
o.miscop:	h.discop
o.miscop:	h.globals
o.miscop:	C:h.kernel
o.miscop:	C:h.swis
o.miscop:	C:SyncLib.h.spin
o.miscop:	C:SyncLib.h.spinrw
o.miscop:	h.miscop
o.miscop:	h.globals
o.module:	c.module
o.module:	C:h.swis
o.module:	C:h.kernel
o.module:	C:Global.h.CMOS
o.module:	C:Global.h.FSNumbers
o.module:	C:Global.h.OsBytes
o.module:	C:Global.h.ModHand
o.module:	C:Global.h.RISCOS
o.module:	C:Global.h.SWIs
o.module:	C:Interface.h.FileCore
o.module:	C:Interface.h.FileCoreErr
o.module:	C:Interface.h.SDFSErr
o.module:	C:Interface.h.SDIO
o.module:	C:Interface.h.SDHCIDevice
o.module:	C:Global.h.HALDevice
o.module:	C:SyncLib.h.synclib
o.module:	C:SyncLib.h.atomic
o.module:	C:SyncLib.h.barrier
o.module:	C:SyncLib.h.cpuevent
o.module:	C:SyncLib.h.mutex
o.module:	C:SyncLib.h.spin
o.module:	C:SyncLib.h.spinrw
o.module:	h.SDFSHdr
o.module:	h.command
o.module:	C:h.kernel
o.module:	h.discop
o.module:	h.globals
o.module:	C:h.kernel
o.module:	C:h.swis
o.module:	C:SyncLib.h.spin
o.module:	C:SyncLib.h.spinrw
o.module:	h.free
o.module:	C:h.kernel
o.module:	h.globals
o.module:	h.message
o.module:	C:h.kernel
o.module:	h.miscop
o.module:	h.globals
o.module:	h.service
o.module:	C:h.kernel
o.module:	h.swi
o.module:	C:h.kernel
o.module:	h.gpiodebug
h.SDFSHdr:	cmhg.SDFSHdr
h.SDFSHdr:	C:Global.h.Services
h.SDFSHdr:	C:Interface.h.SDIO
h.SDFSHdr:	VersionNum
o.sdio: s.sdio
o.sdio: <Hdr$Dir>.Global.ListOpts
o.sdio: <Hdr$Dir>.Global.Macros
o.sdio: <Hdr$Dir>.Global.System
o.sdio: Hdr:SWIs
o.sdio: Hdr:CPU.Arch
o.sdio: Hdr:Machine.<Machine>
o.sdio: Hdr:Machine.Machine
o.sdio: Hdr:CPU.Generic26
o.sdio: Hdr:CPU.Generic32
o.sdio: Hdr:IO.GenericIO
o.sdio: Hdr:RISCOS
o.sdio: <Hdr$Dir>.Global.FSNumbers
o.sdio: <Hdr$Dir>.Global.NewErrors
o.sdio: <Hdr$Dir>.Interface.SDIO
o.sdio: <Hdr$Dir>.Global.APCS.APCS-32
o.sdio: Hdr:APCS.Common
o.service:	c.service
o.service:	C:h.swis
o.service:	C:h.kernel
o.service:	C:Global.h.RISCOS
o.service:	C:Global.h.Upcall
o.service:	C:Interface.h.SDIO
o.service:	C:SyncLib.h.barrier
o.service:	C:SyncLib.h.spinrw
o.service:	h.cardreg
o.service:	h.globals
o.service:	C:h.kernel
o.service:	C:h.swis
o.service:	C:SyncLib.h.spin
o.service:	C:SyncLib.h.spinrw
o.service:	h.service
o.service:	C:h.kernel
o.swi:	c.swi
o.swi:	C:h.kernel
o.swi:	C:Global.h.NewErrors
o.swi:	C:Interface.h.SDFS
o.swi:	C:Interface.h.SDFSErr
o.swi:	C:SyncLib.h.spinrw
o.swi:	h.globals
o.swi:	C:h.kernel
o.swi:	C:h.swis
o.swi:	C:SyncLib.h.spin
o.swi:	C:SyncLib.h.spinrw
o.swi:	h.message
o.swi:	C:h.kernel
o.swi:	h.swi
o.swi:	C:h.kernel
o.SDFSHdr:	cmhg.SDFSHdr
o.SDFSHdr:	C:Global.h.Services
o.SDFSHdr:	C:Interface.h.SDIO
o.SDFSHdr:	VersionNum
