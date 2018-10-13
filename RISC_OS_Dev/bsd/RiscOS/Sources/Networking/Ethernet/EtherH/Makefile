# Copyright (c) 2002, Design IT
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
# 
# Makefile for EtherH
#

COMPONENT    = EtherH
TARGET      ?= EtherH16
ifeq (${TARGET},EtherH16)
# For 16 bit EtherH NICs
CMHGDEFINES  = -DDRIVER16BIT
CDEFINES     = -DDRIVER16BIT
OBJS         = if_eh init module Support Eh_io5_16 Eh_io6_16
else
# For 8 bit EtherH podules
CMHGDEFINES  = -DDRIVER8BIT
CDEFINES     = -DDRIVER8BIT
OBJS         = if_eh init module Support Eh_io
endif
CMHGFILE     = EtherHHdr
CMHGDEPENDS  = module init
HDRS         =
ROMCDEFINES  = -DROM
RES_AREA     = eh_messages
RES_PATH     = Resources.EtherH.Messages
CINCLUDES    = -ITCPIPLibs:,C:
LIBS        += ${INETLIB} ${ASMUTILS}

include CModule

CFLAGS      += -Wp -DINET ${C_OPTSPEED}
CDFLAGS     += -DDEBUG

# Dynamic dependencies:
