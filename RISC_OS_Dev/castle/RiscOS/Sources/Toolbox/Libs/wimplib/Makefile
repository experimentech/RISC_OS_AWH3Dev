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
# Makefile for wimplib
#
# *****************************************
# ***       C h a n g e   L i s t       ***
# *****************************************
# Date		Name		Description
# ----		----		-----------
# 1997-09-03	BAL		Created
# 09 Oct 1997   RWB		Removed some reduntant phases
#


# ------------------------------------------------------------------------------
# Paths
#

EXP_HDR		= <export$dir>
LIBDIR		= <Lib$Dir>


# ------------------------------------------------------------------------------
# Generic options
#

MKDIR		= do mkdir -p
AS		= objasm
CP		= copy
CC		= cc
CM		= cmhg
RM		= remove
LD		= link
LB		= libfile
WIPE		= x wipe

CFLAGS		= -c -depend !Depend -ffah -strict ${INCLUDES} ${DFLAGS}
AFLAGS		= -depend !Depend -Stamp -quit
CPFLAGS		= ~CLFNR~V
LBFLAGS		= -c
WFLAGS		= ~CFR~V


# ------------------------------------------------------------------------------
# Libraries
#

CLIB		= CLIB:o.stubs
RLIB		= RISCOSLIB:o.risc_oslib
RSTUBS		= RISCOSLIB:o.rstubs
ROMSTUBS	= RISCOSLIB:o.romstubs
ROMCSTUBS	= RISCOSLIB:o.romcstubs
ABSSYM		= RISC_OSLib:o.AbsSym


# ------------------------------------------------------------------------------
# Include files
#

INCLUDES	= -IC:
DFLAGS		= 


# ------------------------------------------------------------------------------
# Program specific options:
#

COMPONENT	= wimplib
TARGET		= ${COMPONENT}
EXPORTS		= ${EXP_HDR}.${COMPONENT}

OBJS		=\
 o.waddmsg\
 o.wbasesp\
 o.wblockcpy\
 o.wclosedown\
 o.wclosete\
 o.wclosew\
 o.wcommw\
 o.wcreatei\
 o.wcreatem\
 o.wcreatesm\
 o.wcreatew\
 o.wdecodem\
 o.wdeletei\
 o.wdeletew\
 o.wdragbox\
 o.wforcere\
 o.wforcere2\
 o.wgetcarp\
 o.wgeticst\
 o.wgetmenu\
 o.wgetpoi\
 o.wgetrec\
 o.wgetwinf\
 o.wgetwinfni\
 o.wgetwino\
 o.wgetwst\
 o.wgetwst2\
 o.winit\
 o.wloadte\
 o.wopente\
 o.wopenw\
 o.wopenw2\
 o.wplotic\
 o.wpoll\
 o.wpollidle\
 o.wprocessk\
 o.wreadpal\
 o.wredraww\
 o.wremmsg\
 o.wreporte\
 o.wresizeic\
 o.wsendm\
 o.wsetcarp\
 o.wsetcol\
 o.wsetcolm\
 o.wsetext\
 o.wsetfon\
 o.wseticst\
 o.wsetmode\
 o.wsetpal\
 o.wsetpos\
 o.wslotsize\
 o.wspriteop\
 o.wstartt\
 o.wsysinfo\
 o.wtextcol\
 o.wtextop\
 o.wtransbl\
 o.wupdatew\
 o.wwhichi\
 o.!!version
 

# ------------------------------------------------------------------------------
# Rule patterns
#

.SUFFIXES: .o .s .h .cmhg .c .z
.c.o:;     ${CC} ${CFLAGS} -o $@ $<
.s.o:;     ${AS} ${AFLAGS} -o $@ $<
.cmhg.o:;  ${CM} ${CMHGFLAGS} -o $@ $<
.cmhg.h:;  ${CM} ${CMHGFLAGS} -d $@ $<


# ------------------------------------------------------------------------------
# RISC OS ROM build rules
#

export: export_${PHASE}

clean:
	${WIPE} o.* ${WFLAGS}
	${RM} ${TARGET}
	@echo ${COMPONENT}: cleaned

export_hdrs: h.wimplib dirs
	${CP}	h.wimplib	${LIBDIR}.tboxlibs.h.wimplib	${CPFLAGS}
	@echo ${COMPONENT}: export complete (hdrs)

export_libs: ${TARGET} dirs
	${CP}	${TARGET}	${LIBDIR}.tboxlibs.o.${TARGET}	${CPFLAGS}
	@echo ${COMPONENT}: export complete (libs)

local_dirs:
	${MKDIR} o

dirs:
	${MKDIR} ${LIBDIR}
	${MKDIR} ${LIBDIR}.tboxlibs
	${MKDIR} ${LIBDIR}.tboxlibs.h
	${MKDIR} ${LIBDIR}.tboxlibs.o
        

# ------------------------------------------------------------------------------
# Final link
#

${TARGET}: ${OBJS} local_dirs
	${LB} ${LBFLAGS} -o ${TARGET} ${OBJS}

${EXP_HDR}.${COMPONENT}: hdr.${COMPONENT}
	${CP} hdr.${COMPONENT} $@ ${CPFLAGS}


# ------------------------------------------------------------------------------
# Dynamic dependencies:
o.waddmsg: s.waddmsg
o.waddmsg: hdr.apcs
o.wbasesp: s.wbasesp
o.wbasesp: hdr.apcs
o.wblockcpy: s.wblockcpy
o.wblockcpy: hdr.apcs
o.wclosedown: s.wclosedown
o.wclosedown: hdr.apcs
o.wclosete: s.wclosete
o.wclosete: hdr.apcs
o.wclosew: s.wclosew
o.wclosew: hdr.apcs
o.wcommw: s.wcommw
o.wcommw: hdr.apcs
o.wcreatei: s.wcreatei
o.wcreatei: hdr.apcs
o.wcreatem: s.wcreatem
o.wcreatem: hdr.apcs
o.wcreatesm: s.wcreatesm
o.wcreatesm: hdr.apcs
o.wcreatew: s.wcreatew
o.wcreatew: hdr.apcs
o.wdecodem: s.wdecodem
o.wdecodem: hdr.apcs
o.wdeletei: s.wdeletei
o.wdeletei: hdr.apcs
o.wdeletew: s.wdeletew
o.wdeletew: hdr.apcs
o.wdragbox: s.wdragbox
o.wdragbox: hdr.apcs
o.wforcere: s.wforcere
o.wforcere: hdr.apcs
o.wforcere2: s.wforcere2
o.wforcere2: hdr.apcs
o.wgetcarp: s.wgetcarp
o.wgetcarp: hdr.apcs
o.wgeticst: s.wgeticst
o.wgeticst: hdr.apcs
o.wgetmenu: s.wgetmenu
o.wgetmenu: hdr.apcs
o.wgetpoi: s.wgetpoi
o.wgetpoi: hdr.apcs
o.wgetrec: s.wgetrec
o.wgetrec: hdr.apcs
o.wgetwinf: s.wgetwinf
o.wgetwinf: hdr.apcs
o.wgetwinfni: s.wgetwinfni
o.wgetwinfni: hdr.apcs
o.wgetwino: s.wgetwino
o.wgetwino: hdr.apcs
o.wgetwst: s.wgetwst
o.wgetwst: hdr.apcs
o.wgetwst2: s.wgetwst2
o.wgetwst2: hdr.apcs
o.winit: s.winit
o.winit: hdr.apcs
o.wloadte: s.wloadte
o.wloadte: hdr.apcs
o.wopente: s.wopente
o.wopente: hdr.apcs
o.wopenw: s.wopenw
o.wopenw: hdr.apcs
o.wopenw2: s.wopenw2
o.wopenw2: hdr.apcs
o.wplotic: s.wplotic
o.wplotic: hdr.apcs
o.wpoll: s.wpoll
o.wpoll: hdr.apcs
o.wpollidle: s.wpollidle
o.wpollidle: hdr.apcs
o.wprocessk: s.wprocessk
o.wprocessk: hdr.apcs
o.wreadpal: s.wreadpal
o.wreadpal: hdr.apcs
o.wredraww: s.wredraww
o.wredraww: hdr.apcs
o.wremmsg: s.wremmsg
o.wremmsg: hdr.apcs
o.wreporte: s.wreporte
o.wreporte: hdr.apcs
o.wresizeic: s.wresizeic
o.wresizeic: hdr.apcs
o.wsendm: s.wsendm
o.wsendm: hdr.apcs
o.wsetcarp: s.wsetcarp
o.wsetcarp: hdr.apcs
o.wsetcol: s.wsetcol
o.wsetcol: hdr.apcs
o.wsetcolm: s.wsetcolm
o.wsetcolm: hdr.apcs
o.wsetext: s.wsetext
o.wsetext: hdr.apcs
o.wsetfon: s.wsetfon
o.wsetfon: hdr.apcs
o.wseticst: s.wseticst
o.wseticst: hdr.apcs
o.wsetmode: s.wsetmode
o.wsetmode: hdr.apcs
o.wsetpal: s.wsetpal
o.wsetpal: hdr.apcs
o.wsetpos: s.wsetpos
o.wsetpos: hdr.apcs
o.wslotsize: s.wslotsize
o.wslotsize: hdr.apcs
o.wspriteop: s.wspriteop
o.wspriteop: hdr.apcs
o.wstartt: s.wstartt
o.wstartt: hdr.apcs
o.wsysinfo: s.wsysinfo
o.wsysinfo: hdr.apcs
o.wtextcol: s.wtextcol
o.wtextcol: hdr.apcs
o.wtextop: s.wtextop
o.wtextop: hdr.apcs
o.wtransbl: s.wtransbl
o.wtransbl: hdr.apcs
o.wupdatew: s.wupdatew
o.wupdatew: hdr.apcs
o.wwhichi: s.wwhichi
o.wwhichi: hdr.apcs
o.!!version: s.!!version
