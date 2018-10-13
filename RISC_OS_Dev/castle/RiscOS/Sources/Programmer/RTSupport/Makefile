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
# Makefile for RTSupport
#

DEBUG ?= FALSE

COMPONENT   = Real Time Support
TARGET      = RTSupport
OBJS        = debug global mess scheduler module
RES_AREA    = resmess_ResourcesFiles
CMHGDEPENDS = module
CMHGAUTOHDR = ${TARGET}
CMHGFILE_SWIPREFIX = RT
HDRS        =
ASMHDRS     = ${TARGET}
ASMCHDRS    = ${TARGET}
ROMCDEFINES = -DROM_MODULE
INSTRES_FILES = Priorities

ifeq ($(DEBUG),TRUE)
CFLAGS += -DDEBUGLIB
ASFLAGS += -PD "DEBUGLIB SETL {TRUE}"
LIBS = ${DEBUGLIBS} ${NET5LIBS}
endif

include CModule

CFLAGS     += -We
CDFLAGS    += -DDEBUGLIB

# Dynamic dependencies:
