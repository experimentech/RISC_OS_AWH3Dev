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
# Makefile for UnSqzAIF

COMPONENT  = UnSqzAIF
ROM_SOURCE = ModHead.s
TARGET     = UnSqzAIF
RESOURCES  = no

include StdTools
include AAsmModule

# Dynamic dependencies:
o.CortexA9.UnSqzAIF: s.ModHead
o.CortexA9.UnSqzAIF: Hdr:ListOpts
o.CortexA9.UnSqzAIF: Hdr:Macros
o.CortexA9.UnSqzAIF: Hdr:System
o.CortexA9.UnSqzAIF: Hdr:SWIs
o.CortexA9.UnSqzAIF: Hdr:CPU.Arch
o.CortexA9.UnSqzAIF: Hdr:Machine.<Machine>
o.CortexA9.UnSqzAIF: Hdr:Machine.Machine
o.CortexA9.UnSqzAIF: Hdr:CPU.Generic26
o.CortexA9.UnSqzAIF: Hdr:CPU.Generic32
o.CortexA9.UnSqzAIF: Hdr:IO.GenericIO
o.CortexA9.UnSqzAIF: Hdr:RISCOS
o.CortexA9.UnSqzAIF: Hdr:Services
o.CortexA9.UnSqzAIF: Hdr:ModHand
o.CortexA9.UnSqzAIF: Hdr:MsgTrans
o.CortexA9.UnSqzAIF: Hdr:FSNumbers
o.CortexA9.UnSqzAIF: Hdr:NewErrors
o.CortexA9.UnSqzAIF: Hdr:NdrDebug
o.CortexA9.UnSqzAIF: Hdr:Proc
o.CortexA9.UnSqzAIF: VersionASM
