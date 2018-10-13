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

        EXPORT  HAL_UARTPorts
        EXPORT  HAL_UARTStartUp
        EXPORT  HAL_UARTShutdown
        EXPORT  HAL_UARTFeatures
        EXPORT  HAL_UARTReceiveByte
        EXPORT  HAL_UARTTransmitByte
        EXPORT  HAL_UARTLineStatus
        EXPORT  HAL_UARTInterruptEnable
        EXPORT  HAL_UARTRate
        EXPORT  HAL_UARTFormat
        EXPORT  HAL_UARTFIFOSize
        EXPORT  HAL_UARTFIFOClear
        EXPORT  HAL_UARTFIFOEnable
        EXPORT  HAL_UARTFIFOThreshold
        EXPORT  HAL_UARTInterruptID
        EXPORT  HAL_UARTBreak
        EXPORT  HAL_UARTModemControl
        EXPORT  HAL_UARTModemStatus
        EXPORT  HAL_UARTDevice
        EXPORT  HAL_UARTDefault

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>

        GET     Hdr:Proc
        GET     Hdr:OSEntries

        GET     hdr.iMx6q
        GET     hdr.StaticWS
        GET     hdr.UART
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]

; In all cases, sb must be HAL workspace ptr
; Put base address into the a1, given port number in a1
        MACRO
        BaseAddr
; DebugReg a1,"port "
        ADD     a1, sb, a1, LSL #2
        LDR     a1, [a1, #:INDEX:UART_Base]
; DebugReg a1,"addr "
        MEND
; next copy of macro is used if debug printing undefined
        MACRO
        BaseAddrNoDebug
        ADD     a1, sb, a1, LSL #2
        LDR     a1, [a1, #:INDEX:UART_Base]
        MEND

        MACRO
        DbPR    $reg, $str, $cond
 [ Debug
    [ "$cond" = ""
        Push    "lr"
        DebugReg $reg, $str
        Pull    "lr"
    |
        B$cond  %ft991
        b       %ft992
991
        Push    "lr"
        SavePSR "lr"
        Push    "lr"
        DebugReg $reg, $str
        Pull    "lr"
        RestPSR "lr"
        Pull    "lr"
992
    ]
 |
 ]
        MEND

        MACRO
        DbPRNC    $reg, $str, $cond
 [ Debug
    [ "$cond" = ""
        Push    "lr"
        DebugRegNCR $reg, $str
        Pull    "lr"
    |
        B$cond  %ft991
        b       %ft992
991
        Push    "lr"
        SavePSR "lr"
        Push    "lr"
        DebugRegNCR $reg, $str
        Pull    "lr"
        RestPSR "lr"
        Pull    "lr"
992
    ]
 |
 ]
        MEND

        AREA    |Asm$$Code|, CODE, READONLY, PIC

; int Ports(void)
;
;   Return number of serial ports available.
;
HAL_UARTPorts
        MOV     a1, #UART_CountReported
        MOV     pc, lr

; void Shutdown(int port)
;
HAL_UARTShutdown
        ; Just reuse the startup code

; initialise all chip hardware to 'let the UARTS out of the chip'
; and to give the uart blocks a clock
; a1 = uart number (0-4)  ;; allow 0,1,2 only
;
; DCE mode vs DTE mode:
; in DCE mode uart1 correctly drives the serioa io chip
; in DTE mode the rx/tx pads are swapped, and the cts/rts pads are swapped
;
;
;
HAL_UART_HardwareConfig
        cmp     a1, #UART_CountReported-1
        movgt   pc, lr          ; UART1 goes to RS232 on wandboard.
                                ; 2 and 3 also accessible
; set up pads
; uart1 is routed to the wandboard serial connector
; hal uart device 0
;                CSIO_D10 alt3 o/p txd
;                CSIO_D11 alt3 i/p rxd
;                EIM_D20  alt4 i/p cts
;                EIM_D19  alt4 o/p rts
;
; uart2 is available on testpoints only
; hal uart device 1
;                SD4_DAT7 alt2 o/p txd
;                SD4_DAT4 alt2 i/p rxd
;                SD4_DAT6 alt2 i/p cts
;                SD4_DAT5 alt2 o/p rts
;
; uart3 is routed to the bluetooth module and not available externally
; hal uart device 2
;                EIM_D24 alt2 o/p txd
;                EIM_D25 alt2 i/p rxd
;                EIM_D23 alt2 i/p cts
;                EIM_EB3 alt2 o/p rts
;
; uart4 is available only through pads allocated and connected to
; the bluetooth module
; txd csi0_dat12 alt 3 to daughter board test point
; rxd csi0_dat13 alt 3 to daughter board test point
; txd csi0_dat12 alt 3 to daughter board test point
; rxd key_row0 alt 4 to bluetooth module
; txd key_col0 alt 4 to bluetooth module
; rts csi0_dat16 alt 3 to daughter board test point
; cts csi0_dat17 alt 3 to daughter board test point
;
; uart5 is available only through pads allocated and connected to the
; bluetooth module
; txd csi0_dat14 alt 3 to daughter board test point
; rxd csi0_dat15 alt 3 to daughter board test point
; rxd key_row1 alt 4 to bluetooth module
; txd key_col1 alt 4 to bluetooth module
; rts csi0_dat18 alt 3 to daughter board test point
; cts csi0_dat19 alt 3 to daughter board test point
; cts key_row4 alt 4 to gpio
; rts key_col4 alt 4 to gpio

;
; note: if switching between DCE mode and DTE mode, then the rts and cts pads
;       swap over, as do the txd and rxd pads.
;

; void StartUp(int port)
;
HAL_UARTStartUp
; first setup pads,pins, and clock sources
        ldr     a2, [sb, #:INDEX:IOMUXC_Base]
        ldr     a3, =IOMuxPadUartOut           ; pad drive stuff
        cmp     a1, #1
        beq     DoUART2
        bgt     DoUART3
DoUart1 str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D20-IOMUXC_BASE_ADDR] ; O/P
;        ldr     a3, =IOMuxPadUartIn          ; pad drive stuff
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D19-IOMUXC_BASE_ADDR] ; I/P
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_CSI0_DAT10-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_CSI0_DAT11-IOMUXC_BASE_ADDR]
        mov     a3, #3                  ; alt3
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_CSI0_DAT10-IOMUXC_BASE_ADDR]  ;txd
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_CSI0_DAT11-IOMUXC_BASE_ADDR]  ;rxd (ip)
        mov     a3, #4                  ; alt4
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D19-IOMUXC_BASE_ADDR]  ;cts(physical input)
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D20-IOMUXC_BASE_ADDR]  ;rts(output)
        mov     a3, #1                  ;UART1_UART_RX_DATA_SELECT_INPUT ip sig to dat11
        str     a3, [a2,#IOMUXC_UART1_IPP_UART_RXD_MUX_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3, #1       ;UART1_UART_RTS_SELECT_INPUT (input signal is routed to pin eimd20)
        str     a3, [a2,#IOMUXC_UART1_IPP_UART_RTS_B_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3,  #0<<6                  ;Set to DCEmode (correct for pcb wiring)
        b       UARTPinsDone
;
DoUART2 str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD4_DAT7-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD4_DAT4-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD4_DAT6-IOMUXC_BASE_ADDR]     ; cts
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD4_DAT5-IOMUXC_BASE_ADDR]     ; rts
        mov     a3, #2                  ; alt2
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD4_DAT7-IOMUXC_BASE_ADDR]  ;txd
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD4_DAT4-IOMUXC_BASE_ADDR]  ;rxd
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD4_DAT6-IOMUXC_BASE_ADDR]  ;cts
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD4_DAT5-IOMUXC_BASE_ADDR]  ;rts
        mov     a3, #6                  ;UART2_UART_RX_DATA_SELECT_INPUT
        str     a3, [a2,#IOMUXC_UART2_IPP_UART_RXD_MUX_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3, #4           ;UART2_UART_RTS_SELECT_INPUT  as cts.. DCE mode
        str     a3, [a2,#IOMUXC_UART2_IPP_UART_RTS_B_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3,  #0<<6                  ;Set to DCEmode (user choice)
        b       UARTPinsDone
;
DoUART3 str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D24-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D25-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D23-IOMUXC_BASE_ADDR]     ; cts
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_EB3-IOMUXC_BASE_ADDR]     ; rts
        mov     a3, #2                  ; alt2
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D24-IOMUXC_BASE_ADDR]  ;txd
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D25-IOMUXC_BASE_ADDR]  ;rxd
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D23-IOMUXC_BASE_ADDR]  ;cts
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_EB3-IOMUXC_BASE_ADDR]  ;rts
        mov     a3, #1                  ;UART3_UART_RX_DATA_SELECT_INPUT
        str     a3, [a2,#IOMUXC_UART1_IPP_UART_RXD_MUX_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3, #1;0           ;UART3_UART_RTS_SELECT_INPUT  as cts.. DTE mode
        str     a3, [a2,#IOMUXC_UART1_IPP_UART_RTS_B_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3,  #0<<6                  ;Set to DCEmode (board wiring)

UARTPinsDone
        BaseAddrNoDebug
        str     a3, [a1, #UART_UFCR_OFFSET]
        ldr     a2, [sb, #:INDEX:CCM_Base]
; root clock o/p to uart
        ldr     a3, [a2,#CCM_CSCDR1_OFFSET]
        bic     a3, a3, #&3f            ; ensure uart_podf set to 1/1
        str     a3, [a2,#CCM_CSCDR1_OFFSET]
; turn on uart clock supply
        ldr     a3, [a2,#CCM_CCGR5_OFFSET]
        orr     a3, a3, #&f<<24         ; ensure uart clock and serial clock on
        str     a3, [a2,#CCM_CCGR5_OFFSET]

; now set uart registers up
        mov     a2, #1                         ;reset UART state machines
        str     a2, [a1, #UART_UCR2_OFFSET]
        ldr     a2, = &2006                    ;UCR2 = CTSC,TXEN,RXEN=1,reset clr
        str     a2, [a1, #UART_UCR2_OFFSET]
        mov     a2, #1                         ;UARTEN = 1,enable the UART
        str     a2, [a1, #UART_UCR1_OFFSET]
        ldr     a2, = &6467                    ; (cts active , rts ignore)
        str     a2, [a1, #UART_UCR2_OFFSET]    ;UCR2 = 8n2,IRTS,CTSC,RTECany,TXEN,RXEN=1,reset not set
        ldr     a2, [a1, #UART_UCR3_OFFSET]    ;
        mov     a2, #1<<2                      ; force mux bit, all esle off
        str     a2, [a1, #UART_UCR3_OFFSET]    ;set RXD_MUX_SEL bit
        ldr     a2, [a1, #UART_UFCR_OFFSET]
        bic     a2, a2, #7<<7
        orr     a2, a2, #5<<7                  ;set RFDIV to div-by-1 or b101
        orr     a2, a2, #(UART_FIFODepth/2)<<10; set tx fifo trigger to 1/2 max
        orr     a2, a2, #(UART_FIFODepth/2)<<0 ; set rx fifo trigger to 1/2 max
;        orr     a2, a2, #1<<6                  ;Set to DTEmode (rts/cts correct)
        str     a2, [a1, #UART_UFCR_OFFSET]
        mov     a2, #0x4                       ; powerup default speed to 115200 ish
        str     a2, [a1, #UART_UBIR_OFFSET]
        mov     a2, #0xd8                      ; ditto
        str     a2, [a1, #UART_UBMR_OFFSET]
        mov     a2, #0
        str     a2, [a1, #UART_UMCR_OFFSET]    ; ensure it is rs232 mode
        MOV     pc, lr


; int Features(int port)
;
;      Bit 0:  FIFOs available
;      Bit 1:  DMA available
;      Bit 2:  Modem lines available
;      bit 3:  Hardware RTS/CTS control available
;
HAL_UARTFeatures
        MOV     a1, #2_1101
        MOV     pc, lr

; int ReceiveByte(int port, int *status)
;
;   Returns the next byte from the FIFO (if enabled) or the holding register.
;   If status is non-NULL, the line status associated with the byte is
;   read (see LineStatus). The return value is only meaningful if a
;   received byte is available (bit 0 of *status will be set).
;
HAL_UARTReceiveByte
        BaseAddr
        MOV     ip, lr
        TEQ     a2, #0
        LDREQB  a1, [a1, #UART_URXD_OFFSET]
; DbPR a1, "RxByte "
        MOVEQ   pc, ip

        MOV     a4, a2
        BL      linestatus2
; DbPRNC a1, "RxByte Status "
        STRB    a1, [a4]       ; remember the line status if reqd
        AND     a1, a2, #&ff   ; recover the byte read
        MOV     pc, ip


; void TransmitByte(int port, int byte)
;
HAL_UARTTransmitByte
        adrl    a3, UART_TIRQEn
        add     a3, a3, a1
        BaseAddr
; DbPR a2,"TXByte "
        STRB    a2, [a1, #UART_UTXD_OFFSET]
; now reactivate the TxMty irq if it should be turned on
        ldrb    a4, [a3]
        tst     a4, #1<<6          ; see HAL_UARTInterruptEnable
        ldrne   a4, [a1, #UART_UCR1_OFFSET]
        orrne   a4, a4, #1<<6      ; TxMty
        strne   a4, [a1, #UART_UCR1_OFFSET]
; DbPR a2,"TXirqen ", NE
        MOV     pc, lr

; int LineStatus(int port)
;
;      Bit 0: Receiver Data Ready
;      Bit 1: Overrun Error
;      Bit 2: Parity Error
;      Bit 3: Framing Error
;      Bit 4: Break Error
;      Bit 5: Transmitter Holding Register Empty
;      Bit 6: Transmitter Empty (including FIFO)
;      Bit 7: FIFO contains a Parity, Framing or Break error
;
;   Parity, Framing and Break errors are associated with each byte received.
;   Whether the values reported here are associated with the last byte
;   read using ReceiveByte or with the next byte to be read is undefined.
;   You should request the status using ReceiveByte to ensure accurate
;   identification of bytes with errors.
;
;   Error bits are cleared whenever status is read, using either LineStatus
;   or ReceiveByte with status non-NULL.
;
; returns line status in a1, and received byte, if there in a2
HAL_UARTLineStatus
        BaseAddr
linestatus2                         ; call entry from HAL_UARTReceiveByte
        Entry   "a4"                ; a4 preserved for HAL_UARTReceiveByte
        mov     a3, a1
        mov     a1, #0
        LDR     a2, [a3, #UART_USR2_OFFSET]
        and     a4, a2, #3<<1
        tst     a2, #1<<1
        orrne   a1, a1, #1<<1       ; overrun
        tst     a2, #1<<2
        orrne   a1, a1, #1<<4       ; break
        ands    a4, a2, #3<<1
        strne   a4, [a3, #UART_USR2_OFFSET] ; clear W1C bits if needed
        tst     a2, #1<<3
        orrne   a1, a1, #1<<6       ; tx fully empty
        LDR     a2, [a3, #UART_USR1_OFFSET]
        ands    a4, a2, #1<<15
        orrne   a1, a1, #1<<2       ; parity error
        tst     a2, #1<<10
        orrne   a1, a1, #1<<3       ; framing error
        orrnes  a4, a4, #1<<10
        strne   a4, [a3, #UART_USR1_OFFSET] ; clear W1C bits if needed
        tst     a2, #1<<(13)
        orrne   a1, a1, #1<<5       ; tx hold reg empty

        LDR     a2, [a3, #UART_URXD_OFFSET]; get the flags (and byte)
        tst     a2, #1<<15
        orrne   a1, a1, #1<<0       ; data ready
        tst     a2, #1<<14
        orrne   a1, a1, #1<<7       ; there's an error
        tst     a2, #1<<13
        orrne   a1, a1, #1<<1       ; overrun error
        tst     a2, #1<<12
        orrne   a1, a1, #1<<3       ; framing error
        tst     a2, #1<<11
        orrne   a1, a1, #1<<4       ; break error
        tst     a2, #1<<10
        orrne   a1, a1, #1<<2       ; parity error
                                    ; a3 now has error bits from the flags

; DbPR a1,"LineStat "
        EXIT

; int Rate(int port, int baud16)
;
;   Sets the rate, in units of 1/16 of a baud. Returns the previous rate.
;   Use -1 to read.

; ref clk is 80MHz. baudrate=refclk/(16*((BMR+1)/(BIR+1)))
; i.e. 80MHz/(16*baudrate) =(BMR+1)/(BIR+1)
;
HAL_UARTRate
        Entry   "v1,v2,v3"
        BaseAddr
        PHPSEI  ip, a4
        ldr     a4, [a1, #UART_UCR1_OFFSET]
        bic     a4, a4, #1                   ;UARTEN = 0,disable the clock
        str     a4, [a1, #UART_UCR1_OFFSET]
        ldr     a3, [a1, #UART_UBIR_OFFSET]
        ldr     v1, [a1, #UART_UBMR_OFFSET]
; compute ((BMR+1)*16)/(BIR+1)
        add     v1, v1, #1
        mov     v1, v1, lsl #4          ; *16
        add     a3, a3, #1
        DivRem  a4, v1, a3, lr          ; a3 now contains ((BMR+1)*16)/(BIR+1)
        CMP     v1, a3, LSR#1           ; If the remainder is greater than 1/2
        ADDGE   a4, a4, #1              ; the divisor, round up
        LDR     v1, =UARTCLK*16
        DivRem  a3, v1, a4, lr          ; a4 now contains baud rate*16
        CMP     v1, a4, LSR#1           ; If the remainder is greater than 1/2
        ADDGE   a3, a3, #1              ; the divisor, round up
        CMN     a2, #1                  ; Don't write if we're reading!
        BEQ     %FT30

; We need to program the speed

        LDR     v1, =UARTCLK*16         ; This was corrupted by the above DIVREM
        DivRem  v2, v1, a2, lr          ; a2 is given as BR*16
        CMP     v1, a2, LSR#1           ; If the remainder is greater than 1/2
        ADDGE   v2, v2, #1              ; the divisor, round up
        ; now scale to keep to 16 bits or less
        mov     v1, #&10                ; start with div 16 on bottom
10      cmp     v2, #&10000             ; top too big?
        blt     %ft20
        cmp     v1, #1
        beq     %ft20                   ; cannot reduce further
        mov     a4, v1                  ; old scaling
        sub     v1, v1, #1              ; new scaling
        mul     v3, v1, v2              ; * new scaling
        DivRem  v2, v3, a4, lr          ; div old scaling
        CMP     v3, a4, LSR#1           ; If the remainder is greater than 1/2
        ADDGE   v2, v2, #1              ; the divisor, round up
        b       %bt10                   ; repeat if needed
20      cmp     v2, #&10000             ; top still too big?
        sublt   v1, v1, #1              ; 1 less than actual
        sublt   v2, v2, #1              ; 1 less than actual
        strlt   v1, [a1, #UART_UBIR_OFFSET]  ; update first!
        strlt   v2, [a1, #UART_UBMR_OFFSET]

30      ldr     a2, [a1, #UART_UCR1_OFFSET]
        orr     a2, a2, #1               ;UARTEN = 1,enable the clock
        str     a2, [a1, #UART_UCR1_OFFSET]
        MOV     a1, a3                  ; Return previous state
        PLP     ip
        EXIT

; int Format(int port, int format)
;
;   Bits 0-1: Bits per word  0=>5, 1=>6, 2=>7, 3=>8
;   Bit 2:    Stop length 0=>1, 1=>2 (1.5 if 5 bits)
;   Bit 3:    Parity enabled
;   Bits 4-5: Parity:  0 => Odd (or disabled)
;                      1 => Even
;                      2 => Mark (parity bit = 1)
;                      3 => Space (parity bit = 0)
;
;   Returns previous format. -1 to read.
;

;HAL_UARTFormatMask * (UART_LCR_PARITY_TYPE2 + UART_LCR_PARITY_TYPE1 + UART_LCR_PARITY_EN + UART_LCR_NB_STOP + UART_LCR_CHAR_LENGTH)

HAL_UARTFormat
        BaseAddr
        PHPSEI  ip, a3
        ldr     a4, [a1, #UART_UCR2_OFFSET]
        tst     a4, #1<<8
        mov     a3, #1<<1
        orrne   a3, a3, #1<<3           ; report parity enabled
        tst     a4, #1<<7
        orrne   a3, a3, #1<<4           ; report parity state
        tst     a4, #1<<6
        orrne   a3, a3, #1<<2           ; report stop bits
        tst     a4, #1<<5
        orrne   a3, a3, #1<<0           ; report width
        CMN     a2, #1                  ; Don't write if we're reading!
        BEQ     %FT30
        tst     a2, #(1<<1)
        beq     %FT30                   ; illegal word width
        tst     a2, #(1<<5)
        bne     %FT30                   ; illegal parity option
        bic     a4, a4, #&f<<5          ; clear relevant bits
        tst     a2, #1<<0
        orrne   a4, a4, #1<<5
        tst     a2, #1<<2
        orrne   a4, a4, #1<<6
        tst     a2, #1<<4
        orrne   a4, a4, #1<<7
        tst     a2, #1<<3
        orrne   a4, a4, #1<<8
        str     a4, [a1, #UART_UCR2_OFFSET]
30
        PLP     ip
        MOV     a1, a3
        MOV     pc, lr

; void FIFOSize(int port, int *rx, int *tx)
;
;   Returns the size of the RX and TX FIFOs. Either parameter may be NULL.
;   Note that the size of the TX FIFO is the total amount of data that can
;   be sent immediately when the Transmitter Holding Register Empty
;   status holds. (So an unusual UART that had a transmit threshold
;   should return total FIFO size minus threshold).
;
HAL_UARTFIFOSize
        BaseAddr
        MOV     a1, #UART_FIFODepth
        TEQ     a2, #0
        STRNE   a1, [a2]
        TEQ     a3, #0
        STRNE   a1, [a3]
        MOV     pc, lr

; void FIFOClear(int port, int flags)
;
;   Clears the input FIFO (if bit 0 set) and the output FIFO (if bit 1 set).
;
HAL_UARTFIFOClear
        ADD     a4, sb, a1
        BaseAddr
; not implemented
        MOV     pc, lr

; int FIFOEnable(int port, int enable)
;
;   Enables or disables the RX and TX FIFOs: 0 => disable, 1 => enable
;   -1 => read status. Returns previous status.
;
HAL_UARTFIFOEnable
        BaseAddr
        PHPSEI  ip, a3
        mov     a1, #1           ; fifos always enabled
        PLP     ip
        mov     pc, lr

; int FIFOThreshold(int port, int threshold)
;
;   Sets the receive threshold level for the FIFO RX interrupt.
;   this is 0 to 32 bytes. Returns previous value. -1 to read.
;
HAL_UARTFIFOThreshold
        BaseAddr
        PHPSEI  ip, a3
        ldr     a4, [a1, #UART_UFCR_OFFSET]
        and     a3, a4, #&3f
        CMN     a2, #1                  ; Don't write if we're reading!
        BEQ     %FT30
        cmp     a2, #UART_FIFODepth
        bgt     %ft30                   ; too big
        bic     a4, a4, #&3f
        orr     a4, a4, a2
        str     a4, [a1, #UART_UFCR_OFFSET]
30      MOV     a1, a3
        PLP     ip
        mov     pc, lr

; int InterruptEnable(int port, int bits, int mask)
;
;   Enables interrupts. Bits are:
;
;      Bit 0: Received Data Available (and Character Timeout)
;             (UCR4 bit 0)
;      Bit 1: Transmitter Holding Register Empty
;             (UCR1 bit 6)txempty irq
;      Bit 2: Received Line Status
;             (UCR1 bit 5  RTS changed )
;             ( UCR3 bit 4 DTR changed .. not implemented ATM)
;      Bit 3: Modem Status
;             (UCR1 bit 5  RTS changed .. linked through from CTS in padmux)
;             ( UCR3 bit 4 DTR changed .. not implemented ATM)
;
;   Returns previous state.
;
HAL_UARTInterruptEnable
        Entry   "v1, v2, v3"
; DbPRNC a2, "IEin eor "
; DbPRNC a3, "mask "
        mov     v3, a1              ; remember port number
        BaseAddr
        PHPSEI  ip, a4
        ldr     v1, [a1, #UART_UCR1_OFFSET]
        mov     a4, #0
        tst     v1, #1<<6           ; TxMty irqen?
        orrne   a4, a4, #1<<1
        tst     v1, #1<<5           ; RTS changed irqen (CTS really)
        orrne   a4, a4, #1<<3
        ldr     v2, [a1, #UART_UCR4_OFFSET]
        tst     v2, #1<<0       ; RxDAV
        orrne   a4, a4, #1<<0
        AND     a3, a4, a3
        EOR     a3, a2, a3
; DbPRNC a3, "IEbits to set "
        tst     a3, #1<<0
        biceq   v2, v2, #1<<0       ; RxDAV
        orrne   v2, v2, #1<<0
        tst     a3, #1<<1
        biceq   v1, v1, #1<<6       ; TxMty
        orrne   v1, v1, #1<<6
        adrl    lr, UART_TIRQEn
        ldrb    a2, [lr, v3]        ;
        biceq   a2, a2, #1<<6       ; TxMty irq enable state
        orrne   a2, a2, #1<<6
        strb    a2, [lr, v3]        ; store in this port's store
        tst     a3, #1<<3           ; rx line status
        biceq   v1, v1, #1<<5       ; RTS changed irq
        orrne   v1, v1, #1<<5
        str     v1, [a1, #UART_UCR1_OFFSET]
        str     v2, [a1, #UART_UCR4_OFFSET]
        PLP     ip
        MOV     a1, a4              ; old state
; DbPR a1, "out "
        EXIT


; int InterruptID(int port)
;
;   Returns the highest priority interrupt currently asserted. In order
;   of priority:
;
;   3 => Receiver Line Status (Cleared by ReceiveByte)
;   2 => Received Data Available (Cleared by reading enough data)
;        USR2 bit 0 to match the irq enable bit above
;   6 => Character Timeout (received data waiting)
;   1 => Transmitter Holding Register Empty (Cleared by this call)
;        USR2 bit 14 to match the irq enable bit above
;   0 => Modem Status (Cleared by ModemStatus)
;   -1 => No Interrupt
;
;   The Modem Status interrupt occurs when the CTS, DSR or DCD inputs
;   change, or when RI goes from high to low (ie bits 0 to 3 of ModemStatus
;   are set).
;
; at present the only IRQs configured are
HAL_UARTInterruptID
        Entry   "v1"
        mov     v1, a1
; DbPRNC a1, "IrqID "
        BaseAddr
;        ldr     a2, [a1, #UART_UCR3_OFFSET]
; DbPRNC a2, "c3: "
;        ldr     a2, [a1, #UART_UCR1_OFFSET]
; DbPRNC a2, "c1: "
;        ldr     a2, [a1, #UART_UCR2_OFFSET]
; DbPRNC a2, "c2: "
;        ldr     a2, [a1, #UART_UCR4_OFFSET]
; DbPRNC a2, "c4: "
;        ldr     a2, [a1, #UART_UFCR_OFFSET]
; DbPRNC a2, "fc: "
;        ldr     a2, [a1, #UART_USR1_OFFSET]
; DbPRNC a2, "s1: "
;        ldr     a2, [a1, #UART_USR2_OFFSET]
; DbPRNC a2, "s2: "
        ldr     a2, [a1, #UART_USR2_OFFSET]
        tst     a2, #1<<0
        movne   a1, #2         ; rx dav irq
; DbPR a1, "1 ", NE
        EXIT    NE
        tst     a2, #1<<14     ; tx mty flag
   ; If we don't silence this IRQ it'll continue forever
   ; as the interrupt isn't actually maskable
        ldrne   a2, [a1, #UART_UCR1_OFFSET]
        tstne   a2, #1<<6     ; was it enabled
        bicne   a2, a2, #1<<6 ;  if so, dis the irq for now
        strne   a2, [a1, #UART_UCR1_OFFSET]
        movne   a1, #1         ; and report tx mty irq
; DbPR a1, "2 ", NE
        EXIT    NE
        ldr     a2, [a1, #UART_USR1_OFFSET]
; DbPRNC a2, "USR1 "
        tst     a2, #1<<12     ; rts delta
        movne   a2, #1<<12
        strne   a2, [a1, #UART_USR1_OFFSET] ; clear it
        adrnel  lr, UART_TIRQEn
        ldrneb  a2, [lr, v1]        ;
        orrne   a2, a2, #1<<5       ; remember rtsd irq happened
        strneb  a2, [lr, v1]        ; store in this port's store
        movne   a1, #0
        moveq   a1, #-1        ; else report no irq
; DbPR a1, "3 "
        EXIT

; int Break(int port, int enable)
;
;   Activates (1) or deactivates (0) a break condition. -1 to read,
;   returns previous state.
;
HAL_UARTBreak
        BaseAddr
        PHPSEI  ip, a3
        ldr     a4, [a1, #UART_UCR1_OFFSET]
        and     a3, a4, #1<<4
        mov     a3, a3, lsr #4
        CMN     a2, #1                  ; Don't write if we're reading!
        BEQ     %FT30
        cmp     a2, #1
        bgt     %ft30                   ; too big
        bic     a4, a4, #1<<4
        orr     a4, a4, a2, lsr #4
        str     a4, [a1, #UART_UCR1_OFFSET]
30      MOV     a1, a3
        PLP     ip
        MOV     pc, lr

; int ModemControl(int port, int bits, int mask)
;
;   else
;   Modifies the modem control outputs.
;
;   Bit 0: DTR
;          write on UCR3 bit 10 in DTE mode
;   Bit 1: RTS (CTS in chip - O/P) (if Bit 5 is 0)
;          write as chip CTS_B on UCR2/12 if UCR2/13 set 0 for SW control
;          read as 1 always if hardware cts enabled (We're DTE mode)
;   Bit 5: Enable Hardware RTS/CTS control
;
;   A 1 bit in mask is do not modify. A 0 bit is modify
;
;   Note that these are logical outputs, although the physical pins may be
;   inverted.  So 1 indicates a request to send.  Returns previous state.
;   Needs to clear the modem interrupt status.

HAL_UARTModemControl
        Entry   "v1"
; DbPRNC a1,"MC "
; DbPRNC a2,"e "
; DbPRNC a3,"m "
        BaseAddr
        PHPSEI  ip, a4
        ldr     a4, [a1,#UART_UCR2_OFFSET]
        mvn     a3, a3
        tst     a3, #((1<<5)+(1<<1)+(1<<0))
        ldr     lr, [a1,#UART_UCR3_OFFSET]
        beq     %ft001           ; no bits to control

; DbPRNC a2,"set "
        tst     a3, #((1<<5))
        beq     %ft002
        tst     a2, #1<<5
        biceq   a4, a4, #1<<13   ; set h/w rts/cts
        orrne   a4, a4, #1<<13   ; set manual
002     tst     a3, #((1<<1))
        beq     %ft003
        tst     a2, #1<<1
        biceq   a4, a4, #1<<12   ; set cts bit value
        orrne   a4, a4, #1<<12   ;
        str     a4, [a1,#UART_UCR2_OFFSET]
003     tst     a3, #((1<<0))
        beq     %ft001
        tst     a2, #1<<0        ; dtr?
        orrne   lr, lr, #1<<10
        biceq   lr, lr, #1<<10
        str     lr, [a1,#UART_UCR3_OFFSET]
001
        tst     a4, #1<<13
        moveq   v1, #0
        movne   v1, #1<<5           ; record current state of bit
        tst     a4, #1<<12
        tsteq   a4, #1<<13
        orrne   v1, v1, #1<<1       ; cts always reads 1 if hw hs
; DbPRNC a4,"wr "
        tst     lr, #1<<10
        orrne   a1, v1, #1<<0
        biceq   a1, v1, #1<<0
        PLP     ip

; DbPR a1,"mc2: "
        EXIT

; int ModemStatus(int port)
;
;   Reads the modem status inputs.
;
;   Bit 0: CTS changed since last call (RTS in chip) read as
;   Bit 1: DSR changed since last call
;   Bit 2: RI changed from high to low since last call
;   Bit 3: DCD changed since last call
;   Bit 4: CTS (RTS in chip)
;   Bit 5: DSR
;   Bit 6: RI
;   Bit 7: DCD
;
;   Note that these are logical inputs, although the physical pins may be
;   inverted.  So 1 indicates a Clear To Send condition.  This must also clear
;   the modem interrupt status.
;
; the only pin available to us is CTS (RTS in chip)
HAL_UARTModemStatus
        Entry   "v1"
        mov     v1, a1
        BaseAddr
        PHPSEI  ip, a4                      ; need monotonic check
        mov     a3, #0
        mov     a4, a3
        ldr     a2, [a1, #UART_USR1_OFFSET] ;
        tst     a2, #1<<12                  ;RTSD
        orrne   a4, a4, #1<<0
        movne   a3, #1<<12                  ; write 1 to clear
        strne   a3, [a1, #UART_USR1_OFFSET] ; clear it
        adrl    lr, UART_TIRQEn
        ldrb    a3, [lr, v1]                ; this port's store
        tst     a3, #1<<5                   ; did we get rts change irq
        orrne   a4, a4, #1<<0               ;  current status
        bicne   a3, a3, #1<<5               ; clr it
        strneb  a3, [lr, v1]                ; store in this port's store
        PLP     ip
        tst     a2, #1<<14                  ; RTSS
        orrne   a4, a4, #1<<4               ; read current status
        mov     a1, a4
; DbPR a1,"MS "
        EXIT

; int Device(int port)
;
;   Return the device number allocated to the UART port
;
HAL_UARTDevice
        ADD     a1, sb, a1, LSL #2
        LDR     a1, [a1, #:INDEX:UART_IRQ]
        MOV     pc, lr

; int Default(void)
;
;   Return the default UART for the OS to use, or -1 for none
;
HAL_UARTDefault
        mov     a1, #Default_UART
        MOV     pc, lr

        END
