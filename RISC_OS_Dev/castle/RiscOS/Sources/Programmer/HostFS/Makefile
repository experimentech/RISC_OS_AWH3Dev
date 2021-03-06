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
# Makefile for TML_HostFS
#
# ***********************************
# ***    C h a n g e   L i s t    ***
# ***********************************
# Date       Name         Description
# ----       ----         -----------
# 26-May-94  AMcC         Created.
#

#
# Paths
#
EXP_HDR = <export$dir>

#
# Generic options:
#
MKDIR   = cdir
AS      = aasm
CP      = copy
RM      = remove
CCFLAGS = -c -depend !Depend -IC:
ASFLAGS = -depend !Depend -Stamp -quit
CPFLAGS = ~cfr~v

#
# Program specific options:
#
COMPONENT ?= TML_HostFS
SOURCE    = s.${COMPONENT}
TARGET    = rm.${COMPONENT}
EXPORTS   = ${EXP_HDR}.HostFS \
            ${EXP_HDR}.HostDebug

#
# Generic rules:
#
all: DumpFile SpewChars ${TARGET}
        @echo ${COMPONENT}: all complete

export: ${EXPORTS}
        @echo ${COMPONENT}: export complete

clean:
        ${RM} ${TARGET}
        ${RM} DumpFile
        ${RM} SpewChars
        @echo ${COMPONENT}: cleaned

DumpFile: s.DumpFile
        ${AS} ${ASFLAGS} -To $@ -From s.DumpFile
        SetType $@ Absolute

SpewChars: s.SpewChars
        ${AS} ${ASFLAGS} -To $@ -From s.SpewChars
        SetType $@ Absolute

${TARGET}: ${SOURCE}
        ${AS} ${ASFLAGS} -module -To $@ -From ${SOURCE}

${EXP_HDR}.HostFS: hdr.HostFS
        ${CP} hdr.HostFS $@ ${CPFLAGS}

${EXP_HDR}.HostDebug: hdr.HostDebug
        ${CP} hdr.HostDebug $@ ${CPFLAGS}

install_rom: ${TARGET}
        ${CP} ${TARGET} ${INSTDIR}.${COMPONENT} ${CPFLAGS}
        @echo ${COMPONENT}: rom module installed

# Dynamic dependencies:
