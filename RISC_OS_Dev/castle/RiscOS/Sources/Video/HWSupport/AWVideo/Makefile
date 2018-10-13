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
# Makefile for AWVideo

COMPONENT = AWVideo
TARGET	  = AWVideo

# By default, the shared makefiles assume you want to use CMHG to create
# your module header. This is how to override it:
CMHGFILE =

# Header export phase
#ASMHDRS   =
#ASMCHDRS  =
HDRS      =
OBJS     = AWVideo ipu_dc ipu_dmfc ipu_dp

# CModule is equally useful for assembler modules. Its advantages over the
# AAmModule makefile are that you can use multiple source files (permitting
# more encapsulation, which is good programing practice) and it allows you
# to use non-postion-independent code, provided you do BL __RelocCode early
# in module initialisation.
include CModule


# Dynamic dependencies:
o.AWVideo: s.AWVideo
o.AWVideo: <Hdr$Dir>.Global.ListOpts
o.AWVideo: <Hdr$Dir>.Global.Macros
o.AWVideo: <Hdr$Dir>.Global.System
o.AWVideo: Hdr:SWIs
o.AWVideo: Hdr:CPU.Arch
o.AWVideo: Hdr:Machine.<Machine>
o.AWVideo: Hdr:Machine.Machine
o.AWVideo: Hdr:CPU.Generic26
o.AWVideo: Hdr:CPU.Generic32
o.AWVideo: Hdr:IO.GenericIO
o.AWVideo: Hdr:RISCOS
o.AWVideo: <Hdr$Dir>.Interface.ModHand
o.AWVideo: <Hdr$Dir>.Global.Services
o.AWVideo: <Hdr$Dir>.Interface.ResourceFS
o.AWVideo: VersionASM
o.AWVideo: <Hdr$Dir>.Global.Proc
o.AWVideo: <Hdr$Dir>.Global.FSNumbers
o.AWVideo: <Hdr$Dir>.Interface.HighFSI
o.AWVideo: <Hdr$Dir>.Global.NewErrors
o.AWVideo: <Hdr$Dir>.Interface.VideoDevice
o.AWVideo: hdr:HALDevice
o.AWVideo: <Hdr$Dir>.Interface.HALEntries
o.AWVideo: <Hdr$Dir>.Interface.VidcList
o.AWVideo: <Hdr$Dir>.Interface.PCI
o.AWVideo: <Hdr$Dir>.Global.GraphicsV
o.AWVideo: <Hdr$Dir>.Interface.VduExt
o.AWVideo: <Hdr$Dir>.Interface.AudioDevice
o.AWVideo: hdr:HALDevice
o.AWVideo: <Hdr$Dir>.Interface.VFPSupport
o.AWVideo: <Hdr$Dir>.Interface.OSMisc
o.AWVideo: <Hdr$Dir>.Interface.MsgTrans
o.AWVideo: <Hdr$Dir>.Global.CMOS
o.AWVideo: <Hdr$Dir>.Interface.ScrModes
o.AWVideo: hdr.Debug
o.AWVideo: hdr.Video
o.AWVideo: hdr.iMx6qMemMap
o.AWVideo: hdr.iMx6qReg
o.AWVideo: hdr.cpmem
o.AWVideo: hdr.StaticWS
o.AWVideo: s.GraphicsV
o.AWVideo: s.Debug
o.AWVideo: s.Video
o.AWVideo: s.Audio
o.AWVideo: s.Errors
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
