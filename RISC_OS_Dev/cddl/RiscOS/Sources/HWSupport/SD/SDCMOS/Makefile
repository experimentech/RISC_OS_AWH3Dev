# Makefile for SDCMOS	

COMPONENT = SDCMOS
CMHGFILE  =
HDRS      =
CUSTOMRES = no
ASFLAGS   = ${MYASFLAGS}

include CModule

# Dynamic dependencies:
o.SDCMOS: s.SDCMOS
o.SDCMOS: Hdr:ListOpts
o.SDCMOS: Hdr:Macros
o.SDCMOS: Hdr:System
o.SDCMOS: Hdr:SWIs
o.SDCMOS: Hdr:CPU.Arch
o.SDCMOS: Hdr:Machine.<Machine>
o.SDCMOS: Hdr:Machine.Machine
o.SDCMOS: Hdr:CPU.Generic26
o.SDCMOS: Hdr:CPU.Generic32
o.SDCMOS: Hdr:IO.GenericIO
o.SDCMOS: Hdr:RISCOS
o.SDCMOS: Hdr:Proc
o.SDCMOS: Hdr:HighFSI
o.SDCMOS: Hdr:ModHand
o.SDCMOS: Hdr:OsBytes
o.SDCMOS: Hdr:OsWords
o.SDCMOS: Hdr:CMOS
o.SDCMOS: Hdr:FSNumbers
o.SDCMOS: Hdr:NewErrors
o.SDCMOS: Hdr:Territory
o.SDCMOS: Hdr:FileTypes
o.SDCMOS: Hdr:Services
o.SDCMOS: Hdr:MsgTrans
o.SDCMOS: Hdr:RTC
o.SDCMOS: Hdr:HALDevice
o.SDCMOS: Hdr:HALEntries
o.SDCMOS: Hdr:SDFS
o.SDCMOS: VersionASM
