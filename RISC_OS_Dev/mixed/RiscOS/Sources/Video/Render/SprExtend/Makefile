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
# Makefile for SprExtend
#

COMPONENT = SpriteExtend
TARGET   ?= SprExtend
OBJS      = sources.${TARGET}
ROM_TARGET= rm.${TARGET}
RAM_TARGET= rm.SprExtendSA
ROM_OBJECT= ${TARGET}.o
RAM_OBJECT= ${TARGET}SA.o
EXP_HDR   = <export$dir>

include StdTools
include StdRules
include ModuleLibs

# To switch between making debugging and non-debugging versions of SprExtend:
#   change the #define of DEBUG in commondefs.h
#   change the SETL of 'debug' in sources.SprExtend
CDEFINES  = -DRISCOS -DAVOID_TABLES -DNO_ZERO_ROW_TEST -DLAZYDECODE
CINCLUDES = -IC:
CFLAGS   += ${C_NO_STKCHK}

SFILES =\
 jhdr.s\
 stdpalette.s\
 yuvtabs.s

IJGFILES =\
 jdmarker.o\
 jdhuff.o\
 jdarith.o\
 jdinput.o\
 jdmaster.o\
 jdmainct.o\
 jdcolor.o\
 jdapistd.o\
 jdapimin.o\
 jdpostct.o\
 jddctmgr.o\
 jdcoefct.o\
 jdsample.o\
 jdtrans.o\
 jcomapi.o\
 jcapimin.o\
 jcmaster.o\
 jchuff.o\
 jctrans.o\
 jcparam.o\
 jcmarker.o\
 jdatasrc.o\
 jdatadst.o\
 jidctfst.o\
 jaricom.o\
 jutils.o
 
# Extra utilites (generate assembler code)
GENJHDR    = utils.genjhdr
GENPALETTE = utils.genpalette
GENYUVTABS = utils.genyuvtabs

#
# Targets:
#
install: install_${TARGET}; @

install_SprExtend: ${RAM_TARGET}
        ${MKDIR} ${INSTDIR}
        ${CP} ${RAM_TARGET} ${INSTDIR}.SprExtend ${CPFLAGS}
        @${ECHO} ${COMPONENT}: ram module installed

install_rom: ${ROM_TARGET}
        ${MKDIR} ${INSTDIR}
        ${CP} ${ROM_TARGET} ${INSTDIR}.${TARGET} ${CPFLAGS}
        @${ECHO} ${COMPONENT}: rom module installed

rom: ${ROM_TARGET}
        @${ECHO} ${COMPONENT}: rom module built

standalone: ${RAM_TARGET}
        @${ECHO} ${COMPONENT}: ram module built

export: hdr.SprExtend
        ${CP} hdr.SprExtend ${EXP_HDR}.SprExtend ${CPFLAGS}
        @${ECHO} ${COMPONENT}: export complete

clean:
        ${RM} ${ROM_TARGET}
        ${RM} ${RAM_TARGET}
        ${RM} ${GENPALETTE}
        ${RM} ${GENYUVTABS}
        ${RM} ${GENJHDR}
        ${XWIPE} o ${WFLAGS}
        ${XWIPE} oh ${WFLAGS}
        ${XWIPE} od ${WFLAGS}
        ${XWIPE} s.* ${WFLAGS}
        @${ECHO} ${COMPONENT}: cleaned

resources:
        ${MKDIR} ${RESDIR}.${TARGET}
        ${TOKENCHECK} LocalRes:Messages
        ${CP} LocalRes:Messages  ${RESDIR}.${TARGET}.Messages  ${CPFLAGS}
        @${ECHO} ${COMPONENT}: resource files copied

#
# Generate the SFILES:
#
yuvtabs.s: ${GENYUVTABS}
        ${RUN}${GENYUVTABS} > $@

stdpalette.s: ${GENPALETTE}
        ${RUN}${GENPALETTE} > $@

jhdr.s: ${GENJHDR}
        ${RUN}${GENJHDR} > $@

${GENPALETTE}: genpalette.c
        ${MAKE} -f util/mk COMPONENT=genpalette THROWBACK=${THROWBACK}

${GENYUVTABS}: genyuvtabs.c
        ${MAKE} -f util/mk COMPONENT=genyuvtabs THROWBACK=${THROWBACK}

${GENJHDR}: genjhdr.c jpeglib.h jconfig.h jmorecfg.h
        ${MAKE} -f util/mk COMPONENT=genjhdr THROWBACK=${THROWBACK}

#
# Static dependencies:
#
${ROM_OBJECT}: ${OBJS} ${SFILES}
        ${MKDIR} o
        ${AS} ${ASFLAGS} -o $@ ${OBJS}

${ROM_TARGET}: ${ROM_OBJECT} ${IJGFILES} asmcore.o
        ${LD} -o $@ -rmf ${ROM_OBJECT} ${IJGFILES} asmcore.o

${RAM_OBJECT}: ${OBJS} ${SFILES}
        ${MKDIR} o
        ${AS} ${ASFLAGS} -PD "standalone SETL {TRUE}" -o $@ ${OBJS}

${RAM_TARGET}: ${RAM_OBJECT} ${IJGFILES} asmcore.o resmsg.o 
        ${LD} -o $@ -rmf ${RAM_OBJECT} ${IJGFILES} asmcore.o resmsg.o 
        ${MODSQZ} $@

resmsg.o: LocalRes:Messages
        ${TOKENCHECK} LocalRes:Messages
        ${MKDIR} o
        ${RESGEN} resfsarea o.resmsg LocalRes:Messages Resources.SprExtend.Messages

asmcore.o:
        ${MKDIR} o
        ${CC} ${CFLAGS} $*.c

# Dynamic dependencies:
o.SprExtend: sources.SprExtend
o.SprExtend: Hdr:ListOpts
o.SprExtend: Hdr:Macros
o.SprExtend: Hdr:System
o.SprExtend: Hdr:SWIs
o.SprExtend: Hdr:CPU.Arch
o.SprExtend: Hdr:Machine.<Machine>
o.SprExtend: Hdr:Machine.Machine
o.SprExtend: Hdr:CPU.Generic26
o.SprExtend: Hdr:CPU.Generic32
o.SprExtend: Hdr:IO.GenericIO
o.SprExtend: Hdr:RISCOS
o.SprExtend: Hdr:ModHand
o.SprExtend: Hdr:Services
o.SprExtend: Hdr:VduExt
o.SprExtend: Hdr:HighFSI
o.SprExtend: Hdr:OsWords
o.SprExtend: Hdr:FSNumbers
o.SprExtend: Hdr:NewErrors
o.SprExtend: Hdr:NDRDebug
o.SprExtend: Hdr:Sprite
o.SprExtend: Hdr:ColourTran
o.SprExtend: Hdr:PublicWS
o.SprExtend: Hdr:Draw
o.SprExtend: Hdr:ExtraLong
o.SprExtend: Hdr:MsgTrans
o.SprExtend: Hdr:ResourceFS
o.SprExtend: Hdr:Proc
o.SprExtend: Hdr:HostFS
o.SprExtend: Hdr:PDriver
o.SprExtend: Hdr:OSRSI6
o.SprExtend: Hdr:BlendTable
o.SprExtend: Hdr:GraphicsV
o.SprExtend: Hdr:OSMisc
o.SprExtend: hdr.SprExtend
o.SprExtend: VersionASM
o.SprExtend: Sources.SWIs
o.SprExtend: Sources.SprOp
o.SprExtend: Sources.SprAdjSize
o.SprExtend: Sources.SprTrans
o.SprExtend: Sources.MsgCode
o.SprExtend: Sources.PutScaled
o.SprExtend: Sources.swiv2
o.SprExtend: Sources.CSupport
o.SprExtend: s.jhdr
o.SprExtend: s.yuvtabs
o.SprExtend: Sources.diffuse
o.jdmarker:	c.jdmarker
o.jdmarker:	h.jinclude
o.jdmarker:	C:h.kernel
o.jdmarker:	h.commondefs
o.jdmarker:	h.jconfig
o.jdmarker:	h.jpeglib
o.jdmarker:	h.jmorecfg
o.jdmarker:	h.jpegint
o.jdmarker:	h.jerror
o.jdhuff:	c.jdhuff
o.jdhuff:	h.jinclude
o.jdhuff:	C:h.kernel
o.jdhuff:	h.commondefs
o.jdhuff:	h.jconfig
o.jdhuff:	h.jpeglib
o.jdhuff:	h.jmorecfg
o.jdhuff:	h.jpegint
o.jdhuff:	h.jerror
o.jdarith:	c.jdarith
o.jdarith:	h.jinclude
o.jdarith:	C:h.kernel
o.jdarith:	h.commondefs
o.jdarith:	h.jconfig
o.jdarith:	h.jpeglib
o.jdarith:	h.jmorecfg
o.jdarith:	h.jpegint
o.jdarith:	h.jerror
o.jdinput:	c.jdinput
o.jdinput:	h.jinclude
o.jdinput:	C:h.kernel
o.jdinput:	h.commondefs
o.jdinput:	h.jconfig
o.jdinput:	h.jpeglib
o.jdinput:	h.jmorecfg
o.jdinput:	h.jpegint
o.jdinput:	h.jerror
o.jdmaster:	c.jdmaster
o.jdmaster:	h.jinclude
o.jdmaster:	C:h.kernel
o.jdmaster:	h.commondefs
o.jdmaster:	h.jconfig
o.jdmaster:	h.jpeglib
o.jdmaster:	h.jmorecfg
o.jdmaster:	h.jpegint
o.jdmaster:	h.jerror
o.jdmainct:	c.jdmainct
o.jdmainct:	h.jinclude
o.jdmainct:	C:h.kernel
o.jdmainct:	h.commondefs
o.jdmainct:	h.jconfig
o.jdmainct:	h.jpeglib
o.jdmainct:	h.jmorecfg
o.jdmainct:	h.jpegint
o.jdmainct:	h.jerror
o.jdcolor:	c.jdcolor
o.jdcolor:	h.jinclude
o.jdcolor:	C:h.kernel
o.jdcolor:	h.commondefs
o.jdcolor:	h.jconfig
o.jdcolor:	h.jpeglib
o.jdcolor:	h.jmorecfg
o.jdcolor:	h.jpegint
o.jdcolor:	h.jerror
o.jdapistd:	c.jdapistd
o.jdapistd:	h.jinclude
o.jdapistd:	C:h.kernel
o.jdapistd:	h.commondefs
o.jdapistd:	h.jconfig
o.jdapistd:	h.jpeglib
o.jdapistd:	h.jmorecfg
o.jdapistd:	h.jpegint
o.jdapistd:	h.jerror
o.jdapimin:	c.jdapimin
o.jdapimin:	h.jinclude
o.jdapimin:	C:h.kernel
o.jdapimin:	h.commondefs
o.jdapimin:	h.jconfig
o.jdapimin:	h.jpeglib
o.jdapimin:	h.jmorecfg
o.jdapimin:	h.jpegint
o.jdapimin:	h.jerror
o.jdpostct:	c.jdpostct
o.jdpostct:	h.jinclude
o.jdpostct:	C:h.kernel
o.jdpostct:	h.commondefs
o.jdpostct:	h.jconfig
o.jdpostct:	h.jpeglib
o.jdpostct:	h.jmorecfg
o.jdpostct:	h.jpegint
o.jdpostct:	h.jerror
o.jddctmgr:	c.jddctmgr
o.jddctmgr:	h.jinclude
o.jddctmgr:	C:h.kernel
o.jddctmgr:	h.commondefs
o.jddctmgr:	h.jconfig
o.jddctmgr:	h.jpeglib
o.jddctmgr:	h.jmorecfg
o.jddctmgr:	h.jpegint
o.jddctmgr:	h.jerror
o.jddctmgr:	h.jdct
o.jdcoefct:	c.jdcoefct
o.jdcoefct:	h.jinclude
o.jdcoefct:	C:h.kernel
o.jdcoefct:	h.commondefs
o.jdcoefct:	h.jconfig
o.jdcoefct:	h.jpeglib
o.jdcoefct:	h.jmorecfg
o.jdcoefct:	h.jpegint
o.jdcoefct:	h.jerror
o.jdsample:	c.jdsample
o.jdsample:	h.jinclude
o.jdsample:	C:h.kernel
o.jdsample:	h.commondefs
o.jdsample:	h.jconfig
o.jdsample:	h.jpeglib
o.jdsample:	h.jmorecfg
o.jdsample:	h.jpegint
o.jdsample:	h.jerror
o.jdtrans:	c.jdtrans
o.jdtrans:	h.jinclude
o.jdtrans:	C:h.kernel
o.jdtrans:	h.commondefs
o.jdtrans:	h.jconfig
o.jdtrans:	h.jpeglib
o.jdtrans:	h.jmorecfg
o.jdtrans:	h.jpegint
o.jdtrans:	h.jerror
o.jcomapi:	c.jcomapi
o.jcomapi:	h.jinclude
o.jcomapi:	C:h.kernel
o.jcomapi:	h.commondefs
o.jcomapi:	h.jconfig
o.jcomapi:	h.jpeglib
o.jcomapi:	h.jmorecfg
o.jcomapi:	h.jpegint
o.jcomapi:	h.jerror
o.jcapimin:	c.jcapimin
o.jcapimin:	h.jinclude
o.jcapimin:	C:h.kernel
o.jcapimin:	h.commondefs
o.jcapimin:	h.jconfig
o.jcapimin:	h.jpeglib
o.jcapimin:	h.jmorecfg
o.jcapimin:	h.jpegint
o.jcapimin:	h.jerror
o.jcmaster:	c.jcmaster
o.jcmaster:	h.jinclude
o.jcmaster:	C:h.kernel
o.jcmaster:	h.commondefs
o.jcmaster:	h.jconfig
o.jcmaster:	h.jpeglib
o.jcmaster:	h.jmorecfg
o.jcmaster:	h.jpegint
o.jcmaster:	h.jerror
o.jchuff:	c.jchuff
o.jchuff:	h.jinclude
o.jchuff:	C:h.kernel
o.jchuff:	h.commondefs
o.jchuff:	h.jconfig
o.jchuff:	h.jpeglib
o.jchuff:	h.jmorecfg
o.jchuff:	h.jpegint
o.jchuff:	h.jerror
o.jctrans:	c.jctrans
o.jctrans:	h.jinclude
o.jctrans:	C:h.kernel
o.jctrans:	h.commondefs
o.jctrans:	h.jconfig
o.jctrans:	h.jpeglib
o.jctrans:	h.jmorecfg
o.jctrans:	h.jpegint
o.jctrans:	h.jerror
o.jcparam:	c.jcparam
o.jcparam:	h.jinclude
o.jcparam:	C:h.kernel
o.jcparam:	h.commondefs
o.jcparam:	h.jconfig
o.jcparam:	h.jpeglib
o.jcparam:	h.jmorecfg
o.jcparam:	h.jpegint
o.jcparam:	h.jerror
o.jcmarker:	c.jcmarker
o.jcmarker:	h.jinclude
o.jcmarker:	C:h.kernel
o.jcmarker:	h.commondefs
o.jcmarker:	h.jconfig
o.jcmarker:	h.jpeglib
o.jcmarker:	h.jmorecfg
o.jcmarker:	h.jpegint
o.jcmarker:	h.jerror
o.jdatasrc:	c.jdatasrc
o.jdatasrc:	h.jinclude
o.jdatasrc:	C:h.kernel
o.jdatasrc:	h.commondefs
o.jdatasrc:	h.jconfig
o.jdatasrc:	h.jpeglib
o.jdatasrc:	h.jmorecfg
o.jdatasrc:	h.jerror
o.jdatadst:	c.jdatadst
o.jdatadst:	h.jinclude
o.jdatadst:	C:h.kernel
o.jdatadst:	h.commondefs
o.jdatadst:	h.jconfig
o.jdatadst:	h.jpeglib
o.jdatadst:	h.jmorecfg
o.jdatadst:	h.jerror
o.jidctfst:	c.jidctfst
o.jidctfst:	h.jinclude
o.jidctfst:	C:h.kernel
o.jidctfst:	h.commondefs
o.jidctfst:	h.jconfig
o.jidctfst:	h.jpeglib
o.jidctfst:	h.jmorecfg
o.jidctfst:	h.jpegint
o.jidctfst:	h.jerror
o.jidctfst:	h.jdct
o.jaricom:	c.jaricom
o.jaricom:	h.jinclude
o.jaricom:	C:h.kernel
o.jaricom:	h.commondefs
o.jaricom:	h.jconfig
o.jaricom:	h.jpeglib
o.jaricom:	h.jmorecfg
o.jaricom:	h.jpegint
o.jaricom:	h.jerror
o.jutils:	c.jutils
o.jutils:	h.jinclude
o.jutils:	C:h.kernel
o.jutils:	h.commondefs
o.jutils:	h.jconfig
o.jutils:	h.jpeglib
o.jutils:	h.jmorecfg
o.jutils:	h.jpegint
o.jutils:	h.jerror
o.asmcore:	c.asmcore
o.asmcore:	C:h.swis
o.asmcore:	C:h.kernel
o.asmcore:	C:Global.h.Sprite
o.asmcore:	C:Global.h.VduExt
o.asmcore:	C:Interface.h.BlendTable
o.asmcore:	h.jinclude
o.asmcore:	C:h.kernel
o.asmcore:	h.commondefs
o.asmcore:	h.jconfig
o.asmcore:	h.jpeglib
o.asmcore:	h.jmorecfg
o.asmcore:	h.jpegint
o.asmcore:	h.jerror
o.asmcore:	h.putscaled
o.asmcore:	c.rojpeg
o.asmcore:	C:h.swis
o.asmcore:	C:Global.h.VduExt
o.asmcore:	C:Interface.h.HighFSI
o.asmcore:	h.commondefs
o.asmcore:	h.rojpeg
o.asmcore:	c.romemmgr
o.asmcore:	C:h.swis
o.asmcore:	c.romerge
o.asmcore:	c.rotranscode
o.asmcore:	c.putscaled
o.asmcore:	c.sprtrans
