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
# Makefile for PCI
#
# ***********************************
# ***    C h a n g e   L i s t    ***
# ***********************************
# Date       Name         Description
# ----       ----         -----------
# 06-Jun-00  SNB          Recreated using makefile fragments

COMPONENT = PCI

#
# Program specific options:
#
HEADER1    = ${COMPONENT}
ASMCHEADER1= ${COMPONENT}
EXPORTS    = ${C_EXP_HDR}.${ASMCHEADER1}

TOKHELPSRC = ${TOKENSOURCE}
HELPSRC    = HelpTexts
ROM_SOURCE = GetAll.s

ASFLAGS    = ${OPTIONS}

include StdTools
include AAsmModule

#
# Generic rules:
#
clean::
        ${WIPE} rm ${WFLAGS}
        @@echo ${COMPONENT}: cleaned 

# Dynamic dependencies:
