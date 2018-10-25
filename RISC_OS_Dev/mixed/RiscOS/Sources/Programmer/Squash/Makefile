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
# Makefile for Squash module
#

COMPONENT   = Squash
HDRS        =
ASMHDRS     = Squash
CMHGDEPENDS = compress
OBJS        = compress comp_ass cssr debug \
              zcat_ass12 zssr

include CModule

# Dynamic dependencies:
o.compress:	c.compress
o.compress:	C:h.swis
o.compress:	C:h.kernel
o.compress:	C:Global.h.NewErrors
o.compress:	h.debug
o.compress:	h.cssr
o.compress:	h.defs
o.compress:	h.zssr
o.compress:	h.defs
o.compress:	h.SquashHdr
o.comp_ass: s.comp_ass
o.comp_ass: hdr:ListOpts
o.comp_ass: hdr:Macros
o.comp_ass: hdr:System
o.comp_ass: Hdr:SWIs
o.comp_ass: Hdr:CPU.Arch
o.comp_ass: Hdr:Machine.<Machine>
o.comp_ass: Hdr:Machine.Machine
o.comp_ass: Hdr:CPU.Generic26
o.comp_ass: Hdr:CPU.Generic32
o.comp_ass: Hdr:IO.GenericIO
o.comp_ass: Hdr:RISCOS
o.comp_ass: hdr.debug
o.cssr:	c.cssr
o.cssr:	C:h.kernel
o.cssr:	h.debug
o.cssr:	h.cssr
o.cssr:	h.defs
o.debug: s.debug
o.debug: Hdr:ListOpts
o.debug: Hdr:Macros
o.debug: Hdr:System
o.debug: Hdr:SWIs
o.debug: Hdr:CPU.Arch
o.debug: Hdr:Machine.<Machine>
o.debug: Hdr:Machine.Machine
o.debug: Hdr:CPU.Generic26
o.debug: Hdr:CPU.Generic32
o.debug: Hdr:IO.GenericIO
o.debug: Hdr:RISCOS
o.debug: Hdr:ModHand
o.debug: Hdr:HostFS
o.zcat_ass12: s.zcat_ass12
o.zcat_ass12: s.zcat_ass
o.zcat_ass12: hdr:ListOpts
o.zcat_ass12: hdr:Macros
o.zcat_ass12: hdr:System
o.zcat_ass12: Hdr:SWIs
o.zcat_ass12: Hdr:CPU.Arch
o.zcat_ass12: Hdr:Machine.<Machine>
o.zcat_ass12: Hdr:Machine.Machine
o.zcat_ass12: Hdr:CPU.Generic26
o.zcat_ass12: Hdr:CPU.Generic32
o.zcat_ass12: Hdr:IO.GenericIO
o.zcat_ass12: Hdr:RISCOS
o.zcat_ass12: hdr:CPU.Arch
o.zssr:	c.zssr
o.zssr:	C:h.kernel
o.zssr:	h.debug
o.zssr:	h.zssr
o.zssr:	h.defs
o.SquashHdr:	cmhg.SquashHdr
o.SquashHdr:	VersionNum
