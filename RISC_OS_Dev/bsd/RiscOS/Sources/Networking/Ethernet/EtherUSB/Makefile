# 
# Copyright (c) 2006, James Peacock
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of RISC OS Open Ltd nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# 
# Makefile for EtherUSB
#

COMPONENT    = EtherUSB
TARGET      ?= EtherUSB
OBJS         = cdc config mbuf mii module net products usb utils ticker\
               smsc95xx smsc75xx ax88172 ax88772 mcs7830 pegasus smsc78xx
CMHGDEPENDS  = module net usb utils
ROMCDEFINES  = -DROM
HDRS         =
CINCLUDES    = -ITCPIPLibs:,C:
LIBS        += ${NET5LIBS} ${ASMUTILS} ${SYNCLIB}
CUSTOMSA     = custom

include CModule

CFLAGS      += -Wp -c99

#
# Specials for install (and standalone because they use the same override)
#
standalone: rm.${SA_TARGET}
        @${ECHO} ${COMPONENT}: ram module built

install: install_${TARGET}; @

install_EtherUSB: rm.${SA_TARGET}
        ${MKDIR} ${INSTDIR}
        ${CP} rm.${SA_TARGET} ${INSTDIR}.${TARGET} ${CPFLAGS}
        @${ECHO} ${COMPONENT}: ram module installed

install_AutoSense: AutoSense.${COMPONENT}
        ${CP} AutoSense.${COMPONENT} ${INSTDIR}.${COMPONENT} ${CPFLAGS}
        @${ECHO} ${COMPONENT}: AutoSense file installed

# Dynamic dependencies:
