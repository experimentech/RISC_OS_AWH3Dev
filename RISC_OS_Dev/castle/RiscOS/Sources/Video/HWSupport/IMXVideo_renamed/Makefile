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
# Makefile for IMXVideo

COMPONENT = IMXVideo
TARGET	  = IMXVideo

# By default, the shared makefiles assume you want to use CMHG to create
# your module header. This is how to override it:
CMHGFILE =

# Header export phase
#ASMHDRS   =
#ASMCHDRS  =
HDRS      =
OBJS     = IMXVideo ipu_dc ipu_dmfc ipu_dp

# CModule is equally useful for assembler modules. Its advantages over the
# AAmModule makefile are that you can use multiple source files (permitting
# more encapsulation, which is good programing practice) and it allows you
# to use non-postion-independent code, provided you do BL __RelocCode early
# in module initialisation.
include CModule


# Dynamic dependencies:
o.IMXVideo: s.IMXVideo
o.IMXVideo: <Hdr$Dir>.Global.ListOpts
o.IMXVideo: <Hdr$Dir>.Global.Macros
o.IMXVideo: <Hdr$Dir>.Global.System
o.IMXVideo: Hdr:SWIs
o.IMXVideo: Hdr:CPU.Arch
o.IMXVideo: Hdr:Machine.<Machine>
o.IMXVideo: Hdr:Machine.Machine
o.IMXVideo: Hdr:CPU.Generic26
o.IMXVideo: Hdr:CPU.Generic32
o.IMXVideo: Hdr:IO.GenericIO
o.IMXVideo: Hdr:RISCOS
o.IMXVideo: <Hdr$Dir>.Interface.ModHand
o.IMXVideo: <Hdr$Dir>.Global.Services
o.IMXVideo: <Hdr$Dir>.Interface.ResourceFS
o.IMXVideo: VersionASM
o.IMXVideo: <Hdr$Dir>.Global.Proc
o.IMXVideo: <Hdr$Dir>.Global.FSNumbers
o.IMXVideo: <Hdr$Dir>.Interface.HighFSI
o.IMXVideo: <Hdr$Dir>.Global.NewErrors
o.IMXVideo: <Hdr$Dir>.Interface.VideoDevice
o.IMXVideo: hdr:HALDevice
o.IMXVideo: <Hdr$Dir>.Interface.HALEntries
o.IMXVideo: <Hdr$Dir>.Interface.VidcList
o.IMXVideo: <Hdr$Dir>.Interface.PCI
o.IMXVideo: <Hdr$Dir>.Global.GraphicsV
o.IMXVideo: <Hdr$Dir>.Interface.VduExt
o.IMXVideo: <Hdr$Dir>.Interface.AudioDevice
o.IMXVideo: hdr:HALDevice
o.IMXVideo: <Hdr$Dir>.Interface.VFPSupport
o.IMXVideo: <Hdr$Dir>.Interface.OSMisc
o.IMXVideo: <Hdr$Dir>.Interface.MsgTrans
o.IMXVideo: <Hdr$Dir>.Global.CMOS
o.IMXVideo: <Hdr$Dir>.Interface.ScrModes
o.IMXVideo: hdr.Debug
o.IMXVideo: hdr.Video
o.IMXVideo: hdr.iMx6qMemMap
o.IMXVideo: hdr.iMx6qReg
o.IMXVideo: hdr.cpmem
o.IMXVideo: hdr.StaticWS
o.IMXVideo: s.GraphicsV
o.IMXVideo: s.Debug
o.IMXVideo: s.Video
o.IMXVideo: s.Audio
o.IMXVideo: s.Errors
o.ipu_dc:	c.ipu_dc
o.ipu_dc:	h.ipu_common
o.ipu_dc:	h.sdk
o.ipu_dc:	h.sdk_types
o.ipu_dc:	h.io
o.ipu_dc:	h.sdk_types
o.ipu_dc:	h.soc_memory_map
o.ipu_dc:	h.ws
o.ipu_dc:	h.hdmi_tx
o.ipu_dc:	h.registers
o.ipu_dc:	h.regs
o.ipu_dc:	h.regs
o.ipu_dc:	h.ipu_common
o.ipu_dc:	h.ips_display
o.ipu_dc:	h.ipu_reg_def
o.ipu_dc:	h.regsipu
o.ipu_dmfc:	c.ipu_dmfc
o.ipu_dmfc:	h.ipu_common
o.ipu_dmfc:	h.sdk
o.ipu_dmfc:	h.sdk_types
o.ipu_dmfc:	h.io
o.ipu_dmfc:	h.sdk_types
o.ipu_dmfc:	h.soc_memory_map
o.ipu_dmfc:	h.ws
o.ipu_dmfc:	h.hdmi_tx
o.ipu_dmfc:	h.registers
o.ipu_dmfc:	h.regs
o.ipu_dmfc:	h.regs
o.ipu_dmfc:	h.ipu_common
o.ipu_dmfc:	h.ips_display
o.ipu_dmfc:	h.ipu_reg_def
o.ipu_dmfc:	h.regsipu
o.ipu_dp:	c.ipu_dp
o.ipu_dp:	h.ipu_common
o.ipu_dp:	h.sdk
o.ipu_dp:	h.sdk_types
o.ipu_dp:	h.io
o.ipu_dp:	h.sdk_types
o.ipu_dp:	h.soc_memory_map
o.ipu_dp:	h.ws
o.ipu_dp:	h.hdmi_tx
o.ipu_dp:	h.registers
o.ipu_dp:	h.regs
o.ipu_dp:	h.regs
o.ipu_dp:	h.ipu_common
o.ipu_dp:	h.ips_display
o.ipu_dp:	h.ipu_reg_def
o.ipu_dp:	h.regsipu
