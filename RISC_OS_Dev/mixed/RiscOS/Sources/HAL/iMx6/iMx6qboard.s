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
; Set up logical addresses of all interesting board hardware


        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>
        $GetIO

        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors

        GET     hdr:iMx6q
        GET     HDR:Timers
        GET     hdr.StaticWS
        AREA    |Asm$$Code|, CODE, READONLY, PIC
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]
        EXPORT  HWLogicalInit

        IMPORT  ENET_CheckForPhy

        ALIGN
; CPUIOBase, PCIeBase,  and MainIOBase are already initialised
; v1-> logical address of hal pre-mmu work space
HWLogicalInit
        Push    "lr"
; first anything related to CPUIOBase
        LDR     a1, CPUIOBase              ; new logical address
                                           ; 0x0 -> 0x00cfffff
        sub     a1, a1, #CPU_IOBase        ; convert to offset

 [ A9Timers
        ; Timers in CPU Space
        LDR     a2, = Timer3_Base
        ADD     a2, a1, a2
        STR     a2, Timers_Log +12         ; new logical address
        LDR     a2, = Timer4_Base
        ADD     a2, a1, a2
        STR     a2, Timers_Log +16         ; new logical address
 ]

        LDR     a2, = SCU_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, SCU_Log             ; System Control Unit base address

        LDR     a2, = IC_DISTRIBUTOR_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, IRQDi_Log             ; Interrupt Distributor base address

        LDR     a2, = IC_INTERFACES_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, IRQC_Log             ; Interrupt controller base address

        LDR     a2, = HDMI_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, HDMI_Log             ; HDMI base address

; Then anything to do with PCIeBase
        LDR     a1, PCIeBase              ; new logical address
                                          ; 0x01000000->0x01ffffff
        sub     a1, a1, #PCIe_Base        ; convert to offset


; then stuff to do with MainIOBase
        LDR     a1, MainIOBase            ; new logical address
                                          ; 0x02000000->0x02bfffff
        sub     a1, a1, #Main_IOBase        ; convert to offset
; UART and Debug Uart   (which may well be the same)
        mov     a3, #UART_Count
        add     a4, v1, #:INDEX:UART_Base
        adrl    lr, UART_Base
11
        LDR     a2, [a4], #4
        ADD     a2, a1, a2                  ; adjust for new logical address
        STR     a2, [lr], #4               ; updated
        subs    a3, a3, #1
        bgt     %bt11
        LDR     a2, [v1,#:INDEX:DebugUART]
        ADD     a2, a1, a2                  ; adjust for new logical address
        STR     a2, DebugUART               ; updated
        ADRL    a4, UART_IRQ
        mov     a2, #UART1_IRQ
        str     a2, [a4], #4
        mov     a2, #UART2_IRQ
        str     a2, [a4], #4
        mov     a2, #UART3_IRQ
        str     a2, [a4], #4
        mov     a2, #UART4_IRQ
        str     a2, [a4], #4
        mov     a2, #UART5_IRQ
        str     a2, [a4], #4
; config fuses
        ldr     a2, = OCOTP_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, OCOTP_Log             ; new logical address
; DebugReg a2, "OCOTP_Log: "


; CCM
        ldr     a3, [v1,#:INDEX:CCM_Base]
        ADD     a3, a1, a3
        str     a3, CCM_Base                ; updated
; IOMUX
        ldr     a4, [v1,#:INDEX:IOMUXC_Base]
        ADD     a4, a1, a4
        str     a4, IOMUXC_Base             ; updated

; Timers in MainIO space
        LDR     a2, = Timer0_Base
        ADD     a2, a1, a2
        STR     a2, Timers_Log             ; new logical address
        LDR     a2, = Timer1_Base
        ADD     a2, a1, a2
        STR     a2, Timers_Log +4          ; new logical address
        LDR     a2, = Timer2_Base
        ADD     a2, a1, a2
        STR     a2, Timers_Log +8          ; new logical address


; SRC controller
        LDR     a2, = SRC_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, SRC_Log             ; new logical address

        LDR     a2, = IPU1_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, IPU1_Log             ; new logical address
; DebugReg a2, "IPU1_Log: "

        LDR     a2, = IPU2_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, IPU2_Log             ; new logical address
; DebugReg a2, "IPU2_Log: "

        LDR     a2, = CCM_ANALOG_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, CCMAn_Log             ; new logical address

        LDR     a2, = GPC_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, GPC_Log             ; new logical address

        LDR     a2, = ENET_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, ENET_Log             ; new logical address

        LDR     a2, = GPIO1_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, GPIO_Log             ; new logical address


        LDR     a2, = SATA_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, SATA_Log             ; new logical address

        LDR     a2, = USBOH3_USB_IPS_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, USB_Log             ; new logical address

        LDR     a2, = IP2APB_USBPHY1_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, USBPHY_Log             ; new logical address

        LDR     a2, = WDOG1_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, WDOG1_Log              ; new logical address

        LDR     a2, = WDOG2_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, WDOG2_Log              ; new logical address

        LDR     a2, = USDHC1_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, SDIO_Log              ; new logical address

        LDR     a2, = SDMA_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, SDMA_Log              ; new logical address

        LDR     a2, = ECSPI1_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, SPI_Log               ; new logical address

        LDR     a2, = AUDMUX_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, AudMux_Log

        LDR     a2, = SSI1_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, SSI_Log

        LDR     a2, = SSI2_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, SSI_Log + 4

        LDR     a2, = SSI3_BASE_ADDR
        ADD     a2, a1, a2
        STR     a2, SSI_Log + 8

; this check uses GPIO and CCM so they must already be set up above
; sb should be correct at this point (!!)
        BL      ENET_CheckForPhy         ; lets see if we can check board type

; I2C busses ; swap bus order here to put I2C clk and ram on riscos bus 0 for
; earlier RevB and C boards
        LDR     a4, BoardDetectInfo
        TST     a4, #1
        ADRL    a4, I2C_Table + I2C_XHW - I2CBlockBase     ; I2C_XHW
        LDRNE   a2, = I2C1_BASE_ADDR
        MOVNE   a3, #1
        LDREQ   a2, = I2C2_BASE_ADDR
        MOVEQ   a3, #2
        STR     a3, [a4, #I2C_XACTIONum-I2C_XHW] ; for error recovery later
        ADD     a2, a1, a2
        MOV     a3, #1                   ; first bus RevBC uses I2C2
        STR     a3, [a4, #I2C_XIONum-I2C_XHW] ; interface number
        STR     a2, [a4], #I2CBlockSize  ; new logical address
        LDRNE   a2, = I2C2_BASE_ADDR
        MOVNE   a3, #2                   ; remember actual physical channel used
        LDREQ   a2, = I2C1_BASE_ADDR
        MOVEQ   a3, #1
        STR     a3, [a4, #I2C_XACTIONum-I2C_XHW]
        ADD     a2, a1, a2
        MOV     a3, #0                   ; second bus RevBC uses I2C1
        STR     a3, [a4, #I2C_XIONum-I2C_XHW] ; bus number
        STR     a2, [a4], #I2CBlockSize  ; new logical address
        LDR     a2, = I2C3_BASE_ADDR
        MOV     a3, #3
        STR     a3, [a4, #I2C_XACTIONum-I2C_XHW]
        ADD     a2, a1, a2
        MOV     a3, #2                   ; Third bus uses I2C3
        STR     a3, [a4, #I2C_XIONum-I2C_XHW] ; bus number
        STR     a2, [a4]                 ; new logical address
        ADRL    a4, I2C_Table + I2C_XIRQ-I2CBlockBase
        MOVNE   a2, #I2C1_IRQ
        MOVEQ   a2, #I2C2_IRQ
        STR     a2, [a4], #I2CBlockSize ; IRQ number
        MOVNE   a2, #I2C2_IRQ
        MOVEQ   a2, #I2C1_IRQ
        STR     a2, [a4], #I2CBlockSize ;
        MOV     a2, #I2C3_IRQ
        STR     a2, [a4]                 ;


        Pull    "pc"






        END
