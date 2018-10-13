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


;Truncated version of the OMAP3 version.
;OMAP3 uses some registers nonexistent in the AWH3 UART.
;TODO, port the rest of this file.


        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>

        GET     Hdr:Proc
        GET     Hdr:OSEntries


       	GET     hdr.AllWinnerH3
        GET     hdr.board
        GET     hdr.StaticWS
        GET     hdr.UART

 [ Debug
    GET     Debug
	IMPORT  HAL_DebugTX
	IMPORT  HAL_DebugRX
 ]

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




        MACRO
         BaseAddr
           ADRL ip, HALUART_Log
           LDR a1, [ip, a1, LSL #2]

        MEND




;---------------------------------------------------------------

        AREA    |Asm$$Code|, CODE, READONLY, PIC

;here we go!
HAL_UARTPorts
	LDRB	a1, NumUART
    MOV     pc, lr
;-----------------------------------------------------------------------------

HAL_UARTShutdown
    MOV     pc, lr
;-----------------------------------------------------------------------------

HAL_UARTStartUp
    MOV     pc, lr
;-----------------------------------------------------------------------------

HAL_UARTFeatures
        ;Most features are available, but not implemented currently.
    MOV     a1, #2_00001
    MOV     pc, lr
;-----------------------------------------------------------------------------

; int ReceiveByte(int port, int *status)
HAL_UARTReceiveByte
;from OMAP3. Should be valid.
    BaseAddr
    TEQ     a2, #0
    LDRNEB  a3, [a1, #UART_LSR]     ; Read int state if returning status
    LDRB    a1, [a1, #UART_RBR]
    STRNE   a3, [a2]
    MOV     pc, lr
;-----------------------------------------------------------------------------

HAL_UARTTransmitByte
    BaseAddr
    STRB    a2, [a1, #UART_THR]
    MOV     pc, lr
;-----------------------------------------------------------------------------
HAL_UARTLineStatus
    BaseAddr
    LDRB    a1, [a1, #UART_LSR]
    MOV     pc, lr
;-----------------------------------------------------------------------------

HAL_UARTInterruptEnable
    Push    "lr"
    BaseAddr
    PHPSEI  ip, a4
    LDRB    a4, [a1, #UART_IER]
    AND     a3, a4, a3
    EOR     a3, a2, a3
    STRB    a3, [a1, #UART_IER]
    PLP     ip
    MOV     a1, a4
    DebugTX "HAL_UARTInterruptEnable"
    Pull    "lr"
    MOV     pc, lr
;-----------------------------------------------------------------------------

HAL_UARTRate
    ;OMAP3 version uses nonexistent registers.
    Entry   "v1,v3"
    BaseAddr
    PHPSEI  ip, a4

;Doesn't exist.
;        MOV     v1, #7
;        STRB    v1, [a1, #UART_MDR1]    ; Disable UART

    LDRB    v3, [a1, #UART_LCR]
    ORR     a4, v3, #LCR_DLAB           ; Access divisor latch registers
    STRB    a4, [a1, #UART_LCR]

    LDRB    a3, [a1, #UART_DLL]     ; Read the current baud rate
    LDRB    a4, [a1, #UART_DLH]     ;DLM = DLH?
    LDR     v1, =UARTCLK
    ADDS    a4, a3, a4, LSL#8
    BEQ     %FT05                   ; Skip divide if no baud programmed yet
    DivRem  a3, v1, a4, lr          ; a3 now contains baud rate * 16
    CMP     v1, a4, LSR#1           ; If the remainder is greater than 1/2
    ADDGE   a3, a3, #1              ; the divisor, round up
05
    CMN     a2, #1                  ; Don't write if we're reading!
    BEQ     %FT10

; We need to program 24MHz / (16 * baud rate)

    LDR     v1, =UARTCLK            ; This was corrupted by the above DIVREM
    DivRem  a4, v1, a2, lr
    CMP     v1, a2, LSR#1           ; If the remainder is greater than 1/2
    ADDGE   a4, a4, #1              ; the divisor, round up

    STRB    a4, [a1, #UART_DLL]
    MOV     a4, a4, LSR#8
    STRB    a4, [a1, #UART_DLH]

10  STRB    v3, [a1, #UART_LCR]     ; Turn off divisor latch access
;        MOV     v3, #0
;        STRB    v3, [a1, #UART_MDR1]    ; Restart UART
    MOV     a1, a3                  ; Return previous state
    PLP     ip
    EXIT


;-----------------------------------------------------------------------------

HAL_UARTFormat
   ;looks good in OMAP but missing constants from my definition.
    MOV     pc, lr
;-----------------------------------------------------------------------------

HAL_UARTFIFOSize
    BaseAddr
    MOV     a1, #64
    TEQ     a2, #0
    STRNE   a1, [a2]
    TEQ     a3, #0
    STRNE   a1, [a3]
    MOV     pc, lr

;-----------------------------------------------------------------------------

HAL_UARTFIFOClear
    BaseAddr
        ;remember BaseAddr is handling the port details. a1
        ;RX = b0, TX = b1.
        ;UART_FCR b1 = RFIFOR
        ;         b2 = XFIFOR
    AND    a2, a2, #2_11
    MOV    a2, a2, LSL #1
    STR    a2, [a1, #UART_FCR]

    MOV    pc, lr
;-----------------------------------------------------------------------------
;int HAL_UARTFIFOEnable(int port, int enable)
HAL_UARTFIFOEnable
    BaseAddr
    ;UART_FCR is write only. What a pain!
    CMP    a2, #-1
    MOVEQ  pc, lr
    CMP    a2, #0
    MOVEQ  a2, #0 ;disable FIFO
    MOVNE  a2, #1 ;enable  FIFO
    STR    a2, [a1, #UART_FCR]

    MOV    pc, lr

;-----------------------------------------------------------------------------

HAL_UARTFIFOThreshold
   BaseAddr
   CMP    a2, #1
   MOVEQ  a3, #2_00
   CMP    a2, #4
   MOVEQ  a3, #2_01
   CMP    a2, #8
   MOVEQ  a3, #2_10
   CMP    a2, #14
   MOVEQ  a3, #2_11

;bits 7:6
   MOV    a3, a3, LSL#6

   ORR    a3, #2_1 ;adding the FIFO enable bit
   STR    a3, [a1, #UART_FCR]

   ;FIXME. Danger of writing illegal value.

   MOV    a1, #-1 ;TODO. Save previous FIFO states in StaticWS.


   ;00 1 char
   ;01 1/4 full. 16 chars
   ;10 1/2 full. 32 chars
   ;11 2 less than full. 62
    MOV    pc, lr
;-----------------------------------------------------------------------------

HAL_UARTInterruptID
    BaseAddr
    Push    "lr"
    LDRB    a4, [a1, #UART_IIR]
    TST     a4, #1
    MOVEQ   a1, a4, LSR #1
    ANDEQ   a1, a1, #7
    MOVNE   a1, #-1
    DebugTX "HAL_UARTInterruptID"
    Pull    "lr"
    MOV     pc, lr
;-----------------------------------------------------------------------------

HAL_UARTBreak
        BaseAddr
        PHPSEI  ip, a3
        LDRB    a3, [a1, #UART_LCR]
        ANDS    a4, a3, #LCR_BC
        MOVNE   a4, #1
        CMP     a2, #-1
        BEQ     %FT10
        CMP     a2, #0
        BICEQ   a3, a3, #LCR_BC
        ORRNE   a3, a3, #LCR_BC
        STRB    a3, [a1, #UART_LCR]
10      MOV     a1, a4
        PLP     ip
        MOV     pc, lr
;-----------------------------------------------------------------------------

HAL_UARTModemControl
    MOV    pc, lr
;-----------------------------------------------------------------------------

;hmm...
HAL_UARTModemStatus
   BaseAddr
   LDRB    a1, [a1, #UART_MSR]
   MOV     pc, lr

;also suspicious
;returns interrupt associated with a UART. Is this even right?
;-----------------------------------------------------------------------------

HAL_UARTDevice
;        ADD     a1, sb, a1
;	LDRB	a1, HALUARTIRQ
;        LDRB    a1, [a1, #BoardConfig_HALUARTIRQ]
;        MOV     pc, lr
        ADD     a1, sb, a1
        LDR a2, HALUARTIRQ
        MOV a1, a1, LSL#2 ; to get the right amount to rotate
        LSR a2, a2, a1
        AND a2, a2, #&FF ;mask for correct byte.
        MOV a1, a2
        MOV     pc, lr


;-----------------------------------------------------------------------------

HAL_UARTDefault
	LDRB	a1, DefaultUART
    MOV     pc, lr



   ;Not including S_UART. It's for the OpenRISC core.


   END
