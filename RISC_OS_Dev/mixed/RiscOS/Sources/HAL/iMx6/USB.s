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

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>
        $GetIO

        GET     Hdr:OSEntries
        GET     Hdr:HALEntries

        GET     hdr.iMx6q
        GET     hdr.StaticWS
        GET     hdr.Timers
        GET     hdr.PRCM
        GET     hdr.GPIO
        GET     hdr.iMx6qIRQs

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  USB_Init

        EXPORT  HAL_USBControllerInfo
        EXPORT  HAL_USBPortPower
        EXPORT  HAL_USBPortIRQStatus
        EXPORT  HAL_USBPortIRQClear

        IMPORT  HAL_CounterDelay
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]

; USB PHY power is controlled via GPIO
;USB2_PHY_GPIO * 147  -> board config
USB2_PHY_Reset_delay * 10000 ; 10msec

; GPIO pins for USB
GPIO_HUB_NRESET *       62
GPIO_HUB_POWER  *       1


; these need correct locating
EHCI_IRQ        *       IMX_INT_USBOH3_UH1
OTG_IRQ         *       IMX_INT_USBOH3_UOTG


USB_Init
        Push    "lr"
        ; Initialise USB
        ; set up  H1_OC input  eimd30 alt6
        ;
        ldr     a2, [sb, #:INDEX:IOMUXC_Base]
        mov     a3, #6                  ; alt6
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D30-IOMUXC_BASE_ADDR] ; USBH1_OC
        ; select which pin to use
        mov     a3, #0                  ;use d30
        str     a3, [a2,#IOMUXC_USBOH3_IPP_IND_UH1_OC_SELECT_INPUT-IOMUXC_BASE_ADDR]

; otg_oc is GPIO_9 as input (which needs manual handling as it isnt the chip's i/p)
        mov     a3, #5                  ; alt5
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_GPIO_9-IOMUXC_BASE_ADDR] ; USB_OTG_OC as i/p GPIO09

; otg_id is GPIO_1 as input  alt3
        mov     a3, #3                  ; alt3
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_GPIO_1-IOMUXC_BASE_ADDR] ; USB_OTG_ID
; select the right multiplex setting (default conflicts with I2C1 signals)
        ldr     a3, [a2,#IOMUXC_GPR1-IOMUXC_BASE_ADDR]
        orr     a3, a3, #1<<13
        str     a3, [a2,#IOMUXC_GPR1-IOMUXC_BASE_ADDR]

; otg_pwr_en is EIM_D22 as output alt4
        mov     a3, #4                  ; alt4
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D22-IOMUXC_BASE_ADDR] ; USB_OTG_PWR_EN






        ; enable clocks?
        ldr     a2, CCM_Base
        ldr     a3, [a2, #CCM_CCGR6_OFFSET]
        bic     a3, a3, #3<<0                   ; usb clock
        orr     a3, a3, #3<<0                   ; on
        str     a3, [a2, #CCM_CCGR6_OFFSET]

        ; otg uses USB_PLL1
        ldr     a2, CCMAn_Log
        mov     a3, #((1<<12)+(1<<6))     ; power on, clocks on
        str     a3, [a2, #HW_CCM_ANALOG_PLL_USB1_ADDR+Set_Offset]
01      ldr     a3, [a2, #HW_CCM_ANALOG_PLL_USB1_ADDR]
        tst     a3, #1<<31
        beq     %bt01                           ; not locked yet
        mov     a3, #1<<16                      ; bypass bit
        str     a3, [a2, #HW_CCM_ANALOG_PLL_USB1_ADDR+Clr_Offset]   ; clear
        mov     a3, #1<<13
        str     a3, [a2, #HW_CCM_ANALOG_PLL_USB1_ADDR+Set_Offset]  ; enable output

        ; H1 uses USB_PLL2
        ldr     a2, CCMAn_Log
        mov     a3, #((1<<12)+(1<<6))     ; power on, clocks on
        str     a3, [a2, #HW_CCM_ANALOG_PLL_USB2_ADDR+Set_Offset]
01      ldr     a3, [a2, #HW_CCM_ANALOG_PLL_USB2_ADDR]
        tst     a3, #1<<31
        beq     %bt01                           ; not locked yet
        mov     a3, #1<<16                      ; bypass bit
        str     a3, [a2, #HW_CCM_ANALOG_PLL_USB2_ADDR+Clr_Offset]   ; clear
        mov     a3, #1<<13
        str     a3, [a2, #HW_CCM_ANALOG_PLL_USB2_ADDR+Set_Offset]  ; enable output

        ; configure the Phy .. Phy1 is OTG. Phy2 is H1
        ldr     a3, USBPHY_Log
        mov     a2, #1<<31                      ; soft reset bit
        str     a2, [a3, #HW_USBPHY_CTRL_ADDR_OFFSET+Clr_Offset]
        mov     a2, #1<<30                      ; clock gate bit
        str     a2, [a3, #HW_USBPHY_CTRL_ADDR_OFFSET+Clr_Offset]
        mov     a2, #0
        str     a2, [a3, #HW_USBPHY_PWD_ADDR_OFFSET] ; clear all powerdown bits
        ldr     a2, =((1<<14)+(1<<15)+(1<<1))   ; USBPHY_CTRL_ENUTMILEVEL2
                                                ;+USBPHY_CTRL_ENUTMILEVEL3
                                                ;+USBPHY_CTRL_ENHOSTDISCONDETECT
        str     a2, [a3, #HW_USBPHY_CTRL_ADDR_OFFSET+Set_Offset]
        ldr     a2, [a3, #HW_USBPHY_PWD_ADDR_OFFSET] ; clear all powerdown bits
; DebugReg a2, "Phy0 Powerdown reg "
; add a3, a3, #HW_USBPHY_PWD_ADDR_OFFSET
; DebugReg a3, "Phy0 Powerdown reg addr "
        add     a3, a3, #IP2APB_USBPHY2_BASE_ADDR-IP2APB_USBPHY1_BASE_ADDR
        mov     a2, #1<<31                      ; soft reset bit
        str     a2, [a3, #HW_USBPHY_CTRL_ADDR_OFFSET+Clr_Offset]
        mov     a2, #1<<30                      ; clock gate bit
        str     a2, [a3, #HW_USBPHY_CTRL_ADDR_OFFSET+Clr_Offset]
        mov     a2, #0
        str     a2, [a3, #HW_USBPHY_PWD_ADDR_OFFSET] ; clear all powerdown bits
        ldr     a2, =((1<<14)+(1<<15)+(1<<1))   ; USBPHY_CTRL_ENUTMILEVEL2
                                                ;+USBPHY_CTRL_ENUTMILEVEL3
                                                ;+USBPHY_CTRL_ENHOSTDISCONDETECT
        str     a2, [a3, #HW_USBPHY_CTRL_ADDR_OFFSET+Set_Offset]
        ldr     a2, [a3, #HW_USBPHY_PWD_ADDR_OFFSET] ; clear all powerdown bits
; DebugReg a2, "Phy1 Powerdown reg "
; add a3, a3, #HW_USBPHY_PWD_ADDR_OFFSET
; DebugReg a3, "Phy1 Powerdown reg addr "

        ldr     a3, CCMAn_Log
        mov     a2, #1<<20                      ; charge detect bit   .. off
        str     a2, [a3,#HW_USB_ANALOG_USB1_CHRG_DETECT_OFFSET+Set_Offset]
        str     a2, [a3,#HW_USB_ANALOG_USB2_CHRG_DETECT_OFFSET+Set_Offset]
        mov     a2, #1<<30                      ; clock gate bit
        str     a2, [a3, #HW_USB_ANALOG_USB1_MISC_OFFSET+Set_Offset]
        str     a2, [a3, #HW_USB_ANALOG_USB2_MISC_OFFSET+Set_Offset]

        ; Disable builtin OC detection in the OTG controller (the IMX inputs
        ; which can be used for OC detection are all used for other purposes)
        ldr     a3, USB_Log
        ldr     a2, [a3, #USB_OTG_CTRL_REG-USB_OTG_BASE_ADDR]
        orr     a2, a2, #1<<7
        str     a2, [a3, #USB_OTG_CTRL_REG-USB_OTG_BASE_ADDR]


        Pull    "pc"

        ; a1 = interface #
        ; a2 = usbinfo ptr
        ; a3 = sizeof(usbinfo)
        ; Return sizeof(usbinfo) or 0 for no more devices
        ; If supplied size isn't large enough, only the controller type will be filled in
HAL_USBControllerInfo
;   Push "lr"
; DebugReg a1, " Query USBController  "
;   Pull "lr"
        CMP     a1, #1
        MOVHI   a1, #0
        MOVHI   pc, lr
        BEQ     %FT10
;        BNE     %FT10
; device0 .. use USB_H1
        ; Fill in the usbinfo struct
        MOV     a1, #HALUSBControllerType_EHCI
        STR     a1, [a2, #HALUSBControllerInfo_Type]
        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        MOVLO   pc, lr
        MOV     a4, #HALUSBControllerFlag_32bit_Regs+HALUSBControllerFlag_EHCI_ETTF
        STR     a4, [a2, #HALUSBControllerInfo_Flags]
        ldr     a4, USB_Log
        ADD     a4, a4, #USB_H1_CAPLENGTH-USB_OTG_BASE_ADDR; start of exposed usb registerset
;   Push "lr"
; DebugReg a4, " (HCI)ehci base address "
        STR     a4, [a2, #HALUSBControllerInfo_HW]
        MOV     a4, #EHCI_IRQ
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]
; DebugReg a4, " (HCI)ehci irq "
;   Pull "lr"
        MOV     pc, lr
10
; device1 .. use USB_OTG
; mov pc,lr
        MOV     a1, #HALUSBControllerType_EHCI ; ehci otg???
        STR     a1, [a2, #HALUSBControllerInfo_Type]
        CMP     a3, #HALUSBControllerInfo_SizeOf
        MOV     a1, #HALUSBControllerInfo_SizeOf
        MOVLO   pc, lr
        MOV     a4, #HALUSBControllerFlag_32bit_Regs+HALUSBControllerFlag_EHCI_ETTF;+HALUSBControllerFlag_HAL_Port_Power+HALUSBControllerFlag_HAL_Over_Current
        STR     a4, [a2, #HALUSBControllerInfo_Flags]
        ldr     a4, USB_Log
        ADD     a4, a4, #USB_OTG_CAPLENGTH-USB_OTG_BASE_ADDR
;   Push "lr"
; DebugReg a4, " (HCI)ehciotg base address "
        STR     a4, [a2, #HALUSBControllerInfo_HW]
        MOV     a4, #OTG_IRQ
        STR     a4, [a2, #HALUSBControllerInfo_DevNo]
; DebugReg a4, " (HCI)ehciotg irq "
; add     a4, a2, #HALUSBControllerInfo_HW
; DebugReg a4, " (HCI)ehciotg HALUSBControllerInfo_HW addr "
;   Pull "lr"

; mov a4, #0
; STR     a4, [a2, #HALUSBControllerInfo_HW]

        MOV     pc, lr


        ; These are unused for EHCI
HAL_USBPortPower
HAL_USBPortIRQStatus
HAL_USBPortIRQClear
        MOV     a1, #-1
        MOV     pc, lr

        END
