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
# Makefile for Allwinner H3 HAL
#

VideoInHAL ?= FALSE

COMPONENT = AWH3 HAL
TARGET = AWH3
OBJS = Top Boot Debug KbdScan UART Interrupts RAM Timers CLib CLibAsm Misc CMOS Watchdog USB hdmi ram_detect #VideoiMx6 #Video #PIO_c
# PRCM Video I2C RTC SDMA TPS Audio GPIO GPMC NIC NVMemory CPUClk SR37x SDIO KbdMatrix PAudio BMU gic-disable
USBDIR = <Lib$Dir>.USB

HDRS =
CMHGFILE =
CUSTOMRES = custom
CUSTOMROM = custom
ROM_TARGET = custom
LNK_TARGET = custom
AIFDBG    = aif._${TARGET}
GPADBG    = gpa.GPA


ifeq (${VideoInHAL},TRUE)
# hdmi_print
#OBJS += hdmi_tx_audio  hdmi_audio ipu_dc ipu_dp ipu_dmfc
CFLAGS += -DVideoInHAL
endif
ASFLAGS += -PD "VideoInHAL SETL {${VideoInHAL}}"

include StdTools
include CModule
#CFLAGS +=  -ff -APCS 3/32bit/nofp/noswst
CCFLAGS += -ff -APCS 3/32bit/nofp/noswst
ASFLAGS += -APCS 3/nofp/noswst --cpu Cortex-A7
ROM_LIBS =
HDRS = hdr.StaticWS



#${USBDIR}.o.MUSBDriver ${USBDIR}.o.EHCIHALLib ${USBDIR}.o.USBDriver

resources:
        gen_h
        @${ECHO} ${COMPONENT}: no resources

rom: aof.${TARGET}
        @${ECHO} ${COMPONENT}: rom module built

_debug: ${GPADBG}
        @echo ${COMPONENT}: debug image built

install_rom: linked.${TARGET}
        ${CP} linked.${TARGET} ${INSTDIR}.${TARGET} ${CPFLAGS}
        @echo ${COMPONENT}: rom module installed

aof.${TARGET}: ${ROM_OBJS_} ${ROM_LIBS} ${DIRS} ${ROM_DEPEND}
        ${LD} -o $@ -aof ${ROM_OBJS_} ${ROM_LIBS}

linked.${TARGET}: aof.${TARGET}
        ${LD} ${LDFLAGS} ${LDLINKFLAGS} -o $@ -bin -base 0xFC000000 aof.${TARGET}

${AIFDBG}: ${ROM_OBJS_} ${ROM_LIBS}
        ${MKDIR} aif
        ${LD} -aif -bin -d -o ${AIFDBG} ${ROM_OBJS_} ${ROM_LIBS}

${GPADBG}: ${AIFDBG}
        ToGPA -s ${AIFDBG} ${GPADBG}

#Custom stuff
gen_h: ${HDRS}
       @${ECHO} ${HDRS}: hdr2h complete

h.StaticWS: hdr.StaticWS
        ${MKDIR} h
        ${HDR2H} hdr.StaticWS $@

h.AllWinnerH3: hdr.AllWinnerH3
        ${MKDIR} h
        ${HDR2H} hdr.AllWinnerH3 $@

# Dynamic dependencies:
