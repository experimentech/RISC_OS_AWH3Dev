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
# Makefile for AHCIDriver

COMPONENT = AHCIDriver
TARGET	  = AHCIDriver

# By default, the shared makefiles assume you want to use CMHG to create
# your module header. This is how to override it:
CMHGFILE =

# Header export phase
ASMHDRS   =  AHCIDevice
HDRS      =
OBJS     = module

# CModule is equally useful for assembler modules. Its advantages over the
# AAmModule makefile are that you can use multiple source files (permitting
# more encapsulation, which is good programing practice) and it allows you
# to use non-postion-independent code, provided you do BL __RelocCode early
# in module initialisation.
include CModule


# Dynamic dependencies:
o.module: s.module
o.module: <Hdr$Dir>.Global.ListOpts
o.module: <Hdr$Dir>.Global.Macros
o.module: <Hdr$Dir>.Global.System
o.module: Hdr:SWIs
o.module: Hdr:CPU.Arch
o.module: Hdr:Machine.<Machine>
o.module: Hdr:Machine.Machine
o.module: Hdr:CPU.Generic26
o.module: Hdr:CPU.Generic32
o.module: Hdr:IO.GenericIO
o.module: Hdr:RISCOS
o.module: <Hdr$Dir>.Interface.ModHand
o.module: <Hdr$Dir>.Global.Services
o.module: <Hdr$Dir>.Interface.ResourceFS
o.module: VersionASM
o.module: <Hdr$Dir>.Global.Proc
o.module: <Hdr$Dir>.Global.FSNumbers
o.module: <Hdr$Dir>.Global.NewErrors
o.module: <Hdr$Dir>.Interface.HALEntries
o.module: <Hdr$Dir>.Interface.HALDevice
o.module: hdr.AHCIDevice
o.module: Hdr:HALDevice
o.module: <Hdr$Dir>.Interface.OSMisc
o.module: hdr.module
o.module: <Hdr$Dir>.Interface.PCI
o.module: <Hdr$Dir>.Interface.SCSI
o.module: hdr.scsicmd
o.module: Resources.AHCIDriver_Help
o.module: Resources.AHCIDriver_Help
o.module: Resources.AHCIDriver_Help
o.module: Resources.AHCIDriver_Help
o.module: s.Debug
o.module: s.chip
o.module: hdr.AHCI
o.module: hdr.AHCISTRUCT
o.module: s.scsisoft
o.module: hdr.AHCI
o.module: hdr.SCSICMD
o.module: <Hdr$Dir>.Interface.Portable
o.module: <Hdr$Dir>.Interface.SCSIErr
