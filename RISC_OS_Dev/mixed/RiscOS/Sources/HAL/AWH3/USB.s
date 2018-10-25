; This source code in this file is licensed to You by Castle Technology
; Limited ("Castle") and its licensors on contractual terms and conditions
; ("Licence") which entitle you freely to modify and/or to distribute this
; source code subject to Your compliance with the terms of the Licence.
;
; This source code has been made available to You without any warranties
; whatsoever. Consequently, Your use, modification and distribution of this
; source code is entirely at Your own risk and neither Castle, its licensors
; nor any other person who has contributed to this source code shall be
; liable to You for any loss or damage which You may suffer as a result of
; Your use, modification or distribution of this source code.
;
; Full details of Your rights and obligations are set out in the Licence.
; You should have received a copy of the Licence with this source code file.
; If You have not received a copy, the text of the Licence is available
; online at www.castle-technology.co.uk/riscosbaselicence.htm
;

;USB.s
;WIP.
;OTG HCI host mode nonfunctional.
;Needs GPIO config. ID pin pulled down. PL2? according to Armbian Forum.
;Weird. PL2 is S_UART_TX (fn2), S_PL_EINT2(fn6) in datasheet.
;PL2. Output. SUN4I_PINCTRL_10_MA(??) No pullup/down.
;TODO: GPIO Control!!!!!!

;usb otg at 0x01c1a000 according to U-Boot

    GET     Hdr:ListOpts
    GET     Hdr:Macros
    GET     Hdr:System
    GET     Hdr:OSEntries
    GET     Hdr:HALEntries
    GET     Hdr:Machine.<Machine>
    GET     Hdr:ImageSize.<ImageSize>

    GET     hdr.AllWinnerH3
    GET     hdr.AWH3IRQs
    GET     hdr.StaticWS
    ;may be conflicts with Registers.
    GET     hdr.Registers
    GET     hdr.USB
    GET     hdr.GPIO

 [ Debug
    GET     Debug
    IMPORT  HAL_DebugTX
    IMPORT  HAL_DebugRX
    IMPORT  DebugHALPrint
    IMPORT  DebugHALPrintReg
    IMPORT  DebugMemDump
    IMPORT  DebugHALPrintByte
    IMPORT  DebugCallstack

 ]
    EXPORT  HAL_USBControllerInfo
    EXPORT  USB_Init
    EXPORT  USB_ReportRegs

    AREA    |Asm$$Code|, CODE, READONLY, PIC

;Note: All the #HALUSB* struct entries etc. come from the HALEntries kernel
;header.
;blahblah.Kernel.hdr.HALEntries

;As expected, USB is a good metric for determining an order of priorites
;for implementation of system features.
;------------------------------------------------------------------------------

;taken from OMAP4. Needs to be redone for AWH3. Just a guide.
;size_t HAL_USBControllerInfo( int bus, struct usbinfo *info, size_t len )
USB_Init
       Push "a1-a3, lr"
       ;I know the regs are all messed up. I'll fix it later.

       ;hm. No pins to fiddle
       ;No power control
       ;OTG as yet unimplemented
       ;Clocks just seem to be hardwired, but need enabling and unmasking.
       ;U-boot would have init'd everything anyway.
       ;*Doesn't work with a uImage. Trying to fix

       ;Setting some CCU values based off
       ; what I've pulled from the registers when working.


       ;TODO - OHCI needs regs set in init.


       LDR      a1, CCU_BaseAddr


       ;BUS_CLK_GATING_REG0
       LDR      a2, =&ee000000
       LDR      a3, [a1, #BUS_CLK_GATING_REG0]
       ORR      a2, a2, a3
       STR      a2, [a1, #BUS_CLK_GATING_REG0]
       DSB
       DebugTX  "BUS_CLK_GATING_REG0 set         "
       LDR      a2, [a1, #BUS_CLK_GATING_REG0]
       ISB
       DSB
       DebugReg a2, "BUS_CLK_GATING_REG0  value: "

       ;question is what order should these be set in?
       ;BUS_SOFT_RESET_REG0
       LDR      a2, =&ee000000
       LDR      a3, [a1, #BUS_SOFT_RST_REG0]
       ORR      a2, a2, a3
       STR      a2, [a1, #BUS_SOFT_RST_REG0]
       DSB
       DebugTX  "BUS_SOFT_RST_REG0 set           "
       LDR      a2, [a1, #BUS_SOFT_RST_REG0]
       ISB
       DSB
       DebugReg a2, "BUS_SOFT_RST_REG0 value:    "


       ;de-assert reset and set special clock gating.
       LDR      a2, =&000e0e0e
       STR      a2, [a1, #USBPHY_CFG_REG]
       DSB
       DebugTX "USBPHY_CFG_REG set               "
       LDR      a2, [a1, #USBPHY_CFG_REG]
       ISB
       DSB
       DebugReg a2, "USBPHY_CFG_REG value:       "



;Need to add per-controller HSIC stuff, I think.
       LDR    a1, USB_Host_BaseAddr

       MOV    a2, #USB_HCI0_Offset
       ADD    a2, a1, a2
       ;a2 is now our absolute
       MOV    a3,  #USB_AHB_INCR8_EN | USB_AHB_INCR4_BURST_EN | USB_AHB_INCRX_ALIGN_EN | USB_ULPI_BYPASS_EN
       STR    a3, [a2, #HCI_ICR]

       MOV    a2, #USB_HCI1_Offset
       ADD    a2, a1, a2
       ;a2 is now our absolute
       MOV    a3,  #USB_AHB_INCR8_EN | USB_AHB_INCR4_BURST_EN | USB_AHB_INCRX_ALIGN_EN | USB_ULPI_BYPASS_EN
       STR    a3, [a2, #HCI_ICR]

       MOV    a2, #USB_HCI2_Offset
       ADD    a2, a1, a2
       ;a2 is now our absolute
       MOV    a3,  #USB_AHB_INCR8_EN | USB_AHB_INCR4_BURST_EN | USB_AHB_INCRX_ALIGN_EN | USB_ULPI_BYPASS_EN
       STR    a3, [a2, #HCI_ICR]


       MOV    a2, #USB_HCI3_Offset
       ADD    a2, a1, a2
       ;a2 is now our absolute
       MOV    a3,  #USB_AHB_INCR8_EN | USB_AHB_INCR4_BURST_EN | USB_AHB_INCRX_ALIGN_EN | USB_ULPI_BYPASS_EN
       STR    a3, [a2, #HCI_ICR]


       ;AHB2_CLK_CFG
       ;stays 0 in either config.



;Yes. The values below are correct. The reg values are both the same.

       ;Next up, it looks like the EHCI registers need some pre-fiddling.
       ;make sure run/stop is set to stop (USBCMD b0 = 0 is stopped). (USBSTS b12 = 1 = halted.
       ;NOTE all registers are 0 for EHCI somehow in bootm.
       ;I'm going to try just telling all hosts to stop.
 [ False

       LDR     a1, USB_Host_BaseAddr ;StaticWS

       ;HCI1
       LDR     a2, =USB_HCI1_Offset  ;out of MOV  range
       ADD     a2, a1, a2
       LDR     a3, [a2, #EHCI_USBCMD]
       BIC     a3, a3, #1 << 0 ; Might put the controller in a sane mode
       STR     a3, [a2, #EHCI_USBCMD]

       MOV     a3, #1 << 0 ; manual sez this be the last config step
       STR     a3, [a2, #EHCI_CONFIGFLAG]

       ;HCI2
       LDR     a2, =USB_HCI2_Offset  ;out of MOV  range
       ADD     a2, a1, a2
       LDR     a3, [a2, #EHCI_USBCMD]
       BIC     a3, a3, #1 << 0
       STR     a3, [a2, #EHCI_USBCMD]

       MOV     a3, #1 << 0
       STR     a3, [a2, #EHCI_CONFIGFLAG]

       ;HCI3
       LDR     a2, =USB_HCI2_Offset  ;out of MOV  range
       ADD     a2, a1, a2
       LDR     a3, [a2, #EHCI_USBCMD]
       BIC     a3, a3, #1 << 0
       STR     a3, [a2, #EHCI_USBCMD]

       MOV     a3, #1 << 0
       STR     a3, [a2, #EHCI_CONFIGFLAG]
       ;controller isn't even active. Not bothering checking right now.
       ;Just seeing if a write will give it a kick.
 ]
;===============================;
;------HACK FOR OTG POWER-------; Remove this when PIO is finished.
;===============================;
 [ True
       ;PIO_BaseAddr.
       ;PIO base is    0x01C20800
       ;Port L base is 0x01F02C00
       ;=              0x002E2400
;       LDR     a1, PIO_BaseAddr
;       LDR     a2, =&2E2400

       LDR     a1, R_PIO_BaseAddr ;Port L
;       ADD     a1, a2, a1 ;a1 = port L base.
;we need PL2 set to output and logic low I think.
       ;let's cause some errors.
       LDR     a2, [a1, #PL_CFG0]
 ;      MOV     a3, #2_111
       BIC     a2, a2, #2_111 << 8 ;clear PL2 bits
       ORR     a2, a2, #2_001 << 8 ;set to output
       STR     a2, [a1, #PL_CFG0]

       ;PL_DRV0
       ; 0 = 10mA
       ; 1 = 20mA
       ; 2 = 30mA
       ; 3 = 40mA
       LDR     a2, [a1, #PL_DRV0]
       ;each port is 2 bits
       BIC     a2, a2, #2_11 << 4
       ;Set PL2 to 00. 10mA
       STR     a2, [a1, #PL_DRV0]

       ;drive it low, I guess.

       LDR     a2, [a1, #PL_DAT]
       BIC     a2, a2, #1 << 2
       STR     a2, [a1, #PL_DAT]

       ;disable the pullup



 ]

       Pull "a1-a3, lr"

       MOV      pc, lr
;---------------------------------------------------------------------
;      void USB_ReportRegs();
;---------------------------------------------------------------------

;I'm putting this here for debugging.
USB_ReportRegs
     Push "a1-a3, lr"

     DebugTX "CCU registers:"
     LDR    a2, CCU_BaseAddr
     LDR    a3, [a2, #USBPHY_CFG_REG]
     DSB
     ISB
     DebugReg a3,    "USBPHY_CFG_REG      "
     LDR    a3, [a2, #AHB2_CLK_CFG]
     DSB
     ISB
     DebugReg a3,    "AHB2_CLK_CFG        "
     LDR    a3, [a2, #BUS_CLK_GATING_REG0]
     DSB
     ISB
     DebugReg a3,    "BUS_CLK_GATING_REG0 "
     LDR    a3, [a2, #BUS_SOFT_RST_REG0]
     DSB
     ISB
     DebugReg a3,    "BUS_SOFT_RST_REG0   "



     ;let's go HCI1
;     LDR    a2, =USB_HCI1 ;good as any.
     LDR    a2,  USB_Host_BaseAddr
     ;HCI1 offset is 0. So just cheating here.
     ;I could loop this, but I want printed labels.
     DebugTX "EHCI1 Operational Register      "
     LDR    a3, [a2, #EHCI_USBCMD]
     DebugReg a3,    "EHCI_USBCMD            "
     LDR    a3, [a2, #EHCI_USBSTS]
     DebugReg a3,    "EHCI_USBSTS            "
     LDR    a3, [a2, #EHCI_USBINTR]
     DebugReg a3,    "EHCI_USBINTR           "
     LDR    a3, [a2, #EHCI_FRINDEX]
     DebugReg a3,    "EHCI_FRINDEX           "
     LDR    a3, [a2, #EHCI_CTRLDSSEGMENT]
     DebugReg a3,    "EHCI_CTRLDSSEGMENT     "
     LDR    a3, [a2, #EHCI_PERIODICLISTBASE]
     DebugReg a3,    "EHCI_PERIODICLISTBASE  "
     LDR    a3, [a2, #EHCI_ASYNCLISTADDR]
     DebugReg a3,    "EHCI_ASYNCLISTADDR     "
     LDR    a3, [a2, #EHCI_CONFIGFLAG]
     DebugReg a3,    "EHCI_CONFIGFLAG        "
     LDR    a3, [a2, #EHCI_PORTSC_0]
     DebugReg a3,    "EHCI_PORTSC            "

     ADD    a2, a2, #&1000 ;EHCI2 offset

     DebugTX "EHCI2 Operational Register      "
     LDR    a3, [a2, #EHCI_USBCMD]
     DebugReg a3,    "EHCI_USBCMD            "
     LDR    a3, [a2, #EHCI_USBSTS]
     DebugReg a3,    "EHCI_USBSTS            "
     LDR    a3, [a2, #EHCI_USBINTR]
     DebugReg a3,    "EHCI_USBINTR           "
     LDR    a3, [a2, #EHCI_FRINDEX]
     DebugReg a3,    "EHCI_FRINDEX           "
     LDR    a3, [a2, #EHCI_CTRLDSSEGMENT]
     DebugReg a3,    "EHCI_CTRLDSSEGMENT     "
     LDR    a3, [a2, #EHCI_PERIODICLISTBASE]
     DebugReg a3,    "EHCI_PERIODICLISTBASE  "
     LDR    a3, [a2, #EHCI_ASYNCLISTADDR]
     DebugReg a3,    "EHCI_ASYNCLISTADDR     "
     LDR    a3, [a2, #EHCI_CONFIGFLAG]
     DebugReg a3,    "EHCI_CONFIGFLAG        "
     LDR    a3, [a2, #EHCI_PORTSC_0]
     DebugReg a3,    "EHCI_PORTSC            "

     ADD    a2, a2, #&1000

     DebugTX "EHCI3 Operational Register      "
     LDR    a3, [a2, #EHCI_USBCMD]
     DebugReg a3,    "EHCI_USBCMD            "
     LDR    a3, [a2, #EHCI_USBSTS]
     DebugReg a3,    "EHCI_USBSTS            "
     LDR    a3, [a2, #EHCI_USBINTR]
     DebugReg a3,    "EHCI_USBINTR           "
     LDR    a3, [a2, #EHCI_FRINDEX]
     DebugReg a3,    "EHCI_FRINDEX           "
     LDR    a3, [a2, #EHCI_CTRLDSSEGMENT]
     DebugReg a3,    "EHCI_CTRLDSSEGMENT     "
     LDR    a3, [a2, #EHCI_PERIODICLISTBASE]
     DebugReg a3,    "EHCI_PERIODICLISTBASE  "
     LDR    a3, [a2, #EHCI_ASYNCLISTADDR]
     DebugReg a3,    "EHCI_ASYNCLISTADDR     "
     LDR    a3, [a2, #EHCI_CONFIGFLAG]
     DebugReg a3,    "EHCI_CONFIGFLAG        "
     LDR    a3, [a2, #EHCI_PORTSC_0]
     DebugReg a3,    "EHCI_PORTSC            "

     Pull "a1-a3, lr"
     MOV pc, lr


; According to the H3 there is no controller 0.
; What is going on!?
; index << 2.
; b [startlabel, index]
; startlabel
; B %FT10.
; B %FT20 etc.
;------------------------------------------------------------------------------
; size_t HAL_USBControllerInfo(int bus, struct usbinfo *info, size_t len
;------------------------------------------------------------------------------

HAL_USBControllerInfo
   Push  "lr"
;   DebugReg a1, "Checking USB controller# "
;above nukes it but it did tell me that the count is 0 indexed.

;not really needed
;   CMP    a1, #8 ;Too big.
;   MOVGT  a1, #0 ;return 0 for invalid index.
;   BGT    %FT100

;xHCI0 is OTG.
;Port order rearranged to correspond with U-Boot's port order.
;OHCI1 = 10
;OHCI2 = 30
;OHCI3 = 50
;OHCI0 = 70

;EHCI1 = 20
;EHCI2 = 40
;EHCI3 = 60
;EHCI0 = 80

;EHCI and OHCI. No OTG
 [ True
   CMP    a1, #0
   BEQ    %FT20
   CMP    a1, #1
   BEQ    %FT10
   CMP    a1, #2
   BEQ    %FT40
   CMP    a1, #3
   BEQ    %FT30
   CMP    a1, #4
   BEQ    %FT60
   CMP    a1, #5
   BEQ    %FT50
   CMP    a1, #6
   BEQ    %FT80
   CMP    a1, #7
   BEQ    %FT70
 ]


;EHCI Only
 [ False
   CMP    a1, #0
   BEQ    %FT20
   CMP    a1, #1
   BEQ    %FT40
   CMP    a1, #2
   BEQ    %FT60
 ]


   ; None of the above
   MOV    a1, #0
   B      %FT100
;I tried to be clever in a previous version. Not worth it.
;Just going to make a huge slab of a function.
        ;a1 = bus#
        ;a2 = usbinfo struct pointer
        ;a3 = length of info
;Labels are totally arbitrary.
;This is only enumerated once AFAIK so it doesn't need to be super fast.

;AHA! I've been reusing a1. It should only be used to read bus# and
;it should not be reused after len is set.

10 ;OHCI1 -------------------------------------------------------------

        ;Set type to OHCI
        MOV     a1, #HALUSBControllerType_OHCI
        STR     a1, [a2, #HALUSBControllerInfo_Type]

        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        BLO     %FT100
        ;If the len is too short, just return port type.

        MOV     a4, #0 ;TODO: OHCI flags and implementation of related fns.
        STR     a4, [a2, #HALUSBControllerInfo_Flags]

        LDR     a3, USB_Host_BaseAddr ;staticWS
        ADD     a4, a3, #USB_HCI1_Offset ;0 here but trying for consistency.
        ADD     a4, a4, #OHCI_BASE ;For OHCI, change to OHCI_BASE
        STR     a4, [a2, #HALUSBControllerInfo_HW]

        ;Set controller interrupt number
        MOV     a4, #INT_USB_OHCI_1
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]

        B       %FT100

20 ;EHCI1 -------------------------------------------------------------

        ;Set type to EHCI
        MOV     a1, #HALUSBControllerType_EHCI
        STR     a1, [a2, #HALUSBControllerInfo_Type]

        ;This odd little dance.
        ;It compares len to the size of an info structure.
        ; then it adds it as a potential return value
        ;returns if the value was smaller than the constant.
        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        BLO     %FT100
        ;If the len is too short, just return port type.

        ;a3 isn't used after this point. Use it as a scratch reg.
        ;Set controller flags
        MOV     a4, #HALUSBControllerFlag_32bit_Regs
        STR     a4, [a2, #HALUSBControllerInfo_Flags]

        LDR     a3, USB_Host_BaseAddr ;staticWS
        ADD     a4, a3, #USB_HCI1_Offset ;0 here but trying for consistency.
        ADD     a4, a4, #EHCI_BASE ;For OHCI, change to OHCI_BASE
        STR     a4, [a2, #HALUSBControllerInfo_HW]

        ;MOV     a1, #USB_HCI1_Offset
        ;LDR     a4, USB_Host_BaseAddr
        ;ADD     a4, a4, a1 ;Calculate the base for the correct controller.
        ;ADD     a4, a4, #EHCI_BASE       ;adjusted in hdr. #0 but whatever
        ;STR     a4, [a2, #HALUSBControllerInfo_HW]

        ;Set controller interrupt number
        MOV     a4, #INT_USB_EHCI_1
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]


        B       %FT100

30 ;OHCI2 -------------------------------------------------------------
        ;Set type to OHCI
        MOV     a1, #HALUSBControllerType_OHCI
        STR     a1, [a2, #HALUSBControllerInfo_Type]

        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        BLO     %FT100
        ;If the len is too short, just return port type.

        MOV     a4, #0 ;TODO: OHCI flags and implementation of related fns.
        STR     a4, [a2, #HALUSBControllerInfo_Flags]

        LDR     a3, USB_Host_BaseAddr ;staticWS
        ADD     a4, a3, #USB_HCI2_Offset ;0 here but trying for consistency.
        ADD     a4, a4, #OHCI_BASE ;For OHCI, change to OHCI_BASE
        STR     a4, [a2, #HALUSBControllerInfo_HW]

        ;Set controller interrupt number
        MOV     a4, #INT_USB_OHCI_2
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]

        B       %FT100
40 ;EHCI2 -------------------------------------------------------------

        ;Set type to EHCI
        MOV     a1, #HALUSBControllerType_EHCI
        STR     a1, [a2, #HALUSBControllerInfo_Type]

        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        BLO     %FT100

        ;Set controller flags
        MOV     a4, #HALUSBControllerFlag_32bit_Regs
        STR     a4, [a2, #HALUSBControllerInfo_Flags]

        LDR     a3, USB_Host_BaseAddr ;staticWS
        ADD     a4, a3, #USB_HCI2_Offset
        ADD     a4, a4, #EHCI_BASE ;For OHCI, change to OHCI_BASE
        STR     a4, [a2, #HALUSBControllerInfo_HW]

        ;Set controller interrupt number
        MOV     a4, #INT_USB_EHCI_2
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]

        B       %FT100

50 ;OHCI3 -------------------------------------------------------------
        ;Set type to OHCI
        MOV     a1, #HALUSBControllerType_OHCI
        STR     a1, [a2, #HALUSBControllerInfo_Type]

        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        BLO     %FT100
        ;If the len is too short, just return port type.

        MOV     a4, #0 ;TODO: OHCI flags and implementation of related fns.
        STR     a4, [a2, #HALUSBControllerInfo_Flags]

        LDR     a3, USB_Host_BaseAddr ;staticWS
        ADD     a4, a3, #USB_HCI3_Offset ;0 here but trying for consistency.
        ADD     a4, a4, #OHCI_BASE ;For OHCI, change to OHCI_BASE
        STR     a4, [a2, #HALUSBControllerInfo_HW]

        ;Set controller interrupt number
        MOV     a4, #INT_USB_OHCI_3
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]

        B       %FT100
60 ;EHCI3 -------------------------------------------------------------

        ;Set type to EHCI
        MOV     a1, #HALUSBControllerType_EHCI
        STR     a1, [a2, #HALUSBControllerInfo_Type]

        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        BLO     %FT100

        ;Set controller flags
        MOV     a4, #HALUSBControllerFlag_32bit_Regs
        STR     a4, [a2, #HALUSBControllerInfo_Flags]

        LDR     a3, USB_Host_BaseAddr ;staticWS
        ADD     a4, a3, #USB_HCI3_Offset
        ADD     a4, a4, #EHCI_BASE ;For OHCI, change to OHCI_BASE
        STR     a4, [a2, #HALUSBControllerInfo_HW]

        ;Set controller interrupt number
        MOV     a4, #INT_USB_EHCI_3
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]

        B       %FT100


;Below two are broken! They need the following:

;Enabling of IO pin for port power. Code is in init but somethin'g not woeking.
;Extra init step for the OTG port?
;The driver sees the port, but no attached devices.
;No power to devices.
;Backfeeding via powered hub doesn't work.
70 ;OTG OHCI -------------------------------------------------------------

        ;Set type to OHCI
        MOV     a1, #HALUSBControllerType_OHCI
        STR     a1, [a2, #HALUSBControllerInfo_Type]

        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        BLO     %FT100
        ;If the len is too short, just return port type.

        MOV     a4, #0 ;TODO: OHCI flags and implementation of related fns.
        STR     a4, [a2, #HALUSBControllerInfo_Flags]

        LDR     a3, USB_Host_BaseAddr ;staticWS
        ADD     a4, a3, #USB_HCI0_Offset ;0 here but trying for consistency.
        ADD     a4, a4, #OHCI_BASE ;For OHCI, change to OHCI_BASE
        STR     a4, [a2, #HALUSBControllerInfo_HW]

        ;Set controller interrupt number
        MOV     a4, #INT_USB_OTG_OHCI_0
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]

        B       %FT100

80 ;OTG EHCI -------------------------------------------------------------


        ;Set type to EHCI
        MOV     a1, #HALUSBControllerType_EHCI
        STR     a1, [a2, #HALUSBControllerInfo_Type]

        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        BLO     %FT100

        ;Set controller flags
        MOV     a4, #HALUSBControllerFlag_32bit_Regs
        STR     a4, [a2, #HALUSBControllerInfo_Flags]

        LDR     a3, USB_Host_BaseAddr ;staticWS
        ADD     a4, a3, #USB_HCI0_Offset
        ADD     a4, a4, #EHCI_BASE ;For OHCI, change to OHCI_BASE
        STR     a4, [a2, #HALUSBControllerInfo_HW]

        ;Set controller interrupt number
        MOV     a4, #INT_USB_OTG_EHCI_0
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]

        B       %FT100

        ;TODO
;USB OTG is lowest in memory. However it has been placed last on the
; enum list because it's easier to remove later for special case
; host / device handling.


;Let's try to answer the USB quiz!
;We have 3 hosts:
; USB_HCI1  &01C1B000
; USB_HCI2  &01C1C000
; USB_HCI3  &01C1D000

100
        Pull   "lr"
        MOV     pc, lr


;------------------------------------------------------------------------------

HAL_USBPortPower
;bit 8 of HCRHDESCRIPTORA in OHCI 0x448 seems to detect whether power switching
;has been implemented. Don't mind it for now.
;    MOV    pc, lr
;------------------------------------------------------------------------------
HAL_USBPortIRQStatus ;um?
    MOV    pc, lr
;------------------------------------------------------------------------------
;void HAL_USBPortIRQClear(int bus, int port)
HAL_USBPortIRQClear
    MOV    a1, #-1
    MOV    pc, lr
;------------------------------------------------------------------------------

;no special overcurrent IRQ exists. Only reading from the register.
;HAL_USBPortDevice
;HCSParams N_PORTS in datasheet says # is always 1.
;Therefore query port 0 of bus n.
;    MOV    pc, lr
;------------------------------------------------------------------------------

    END

