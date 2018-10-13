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
        GET     Hdr:Proc

        GET     Hdr:OSEntries

        GET     hdr.iMx6q
        GET     hdr.UART
        GET     hdr.StaticWS

        EXPORT  HAL_DebugTX
        EXPORT  HAL_DebugRX
 [ Debug
        EXPORT  DebugHALPrint
        EXPORT  DebugHALPrintReg
        EXPORT  DebugMemDump
        EXPORT  DebugHALPrintByte
        EXPORT  DebugCallstack
 ]

        AREA    |Asm$$Code|, CODE, READONLY, PIC

 [ Debug

; No initialisation; assumes the serial
; port is already set up

; In all cases, sb must be HAL workspace ptr

; in: a1 = character to TX
HAL_DebugTX

        LDR     a2, [sb, #:INDEX:DebugUART]
        LDR     a3, [a2, #UART_UCR2_OFFSET]
        TST     a3, #1<<2                  ; TX enabled?
        ORRNE   a3, a3, #1<<2              ; assume uart is also enabled..
        STRNE   a3, [a2, #UART_UCR2_OFFSET] ; force enable.. else could abort
HAL_DebugTX_Loop
        LDR     a3, [a2, #UART_USR2_OFFSET]
        TST     a3, #1<<14  ;UART_LSR_TX_FIFO_E
        BEQ     HAL_DebugTX_Loop
        STRB    a1, [a2, #UART_UTXD_OFFSET]
        MOV     pc, lr

; out: a1 = character, or -1 if none available
HAL_DebugRX     ROUT
        LDR     a2, [sb, #:INDEX:DebugUART]
        LDRB    a1, [a2, #UART_USR2_OFFSET]
        TST     a1, #1<<0  ;UART_LSR_RX_FIFO_E
        MOVEQ   a1, #-1
        LDRNEB  a1, [a2, #UART_URXD_OFFSET]
; moveq pc,lr ; nothing received
; mov a3,lr
; DebugReg a1, "rx:"
; mov lr,a3
        MOV     pc, lr

DebugHALPrint
        Push    "a1-a4,v1"
        MOV     v1, lr
10      LDRB    a1, [v1], #1
        TEQ     a1, #0
        BEQ     %FT20
        BL      HAL_DebugTX
        B       %BT10
20      ADD     v1, v1, #3
        BIC     lr, v1, #3
        Pull    "a1-a4,v1"
        MOV     pc, lr

DebugHALPrintReg ; Output number on top of stack to the serial port
        Push    "a1-a4,v1-v4,lr"
        LDR     v2, [sp,#9*4]
        ADR     v3, hextab
        MOV     v4, #8
10      LDRB    a1, [v3, v2, LSR #28]
        bl      HAL_DebugTX
        MOV     v2, v2, LSL #4
        SUBS    v4, v4, #1
        BNE     %BT10
        MOV     a1, #32
        bl      HAL_DebugTX

        Pull    "a1-a4,v1-v4,lr"
        ADD     sp, sp, #4
        MOV     pc, lr

hextab  DCB "0123456789abcdef"

DebugMemDump ; r0 = start, r1 = size
        Push    "a1-a4,v1-v3,lr"
        MOV     v2, a1
        MOV     v3, a2
        LDR     a2, [sb, #:INDEX:DebugUART]
        ADR     a3, hextab
100
        ; Print addr
        MOV     a1, v2
        MOV     a4, #8
10
        LDR     v1, [a2, #UART_USR2_OFFSET]
        TST     v1, #1<<14 ; tx fifo empty bit
        BEQ     %BT10
        LDRB    v1, [a3, a1, LSR #28]
        STRB    v1, [a2, #UART_UTXD_OFFSET]
        MOV     a1, a1, LSL #4
        SUBS    a4, a4, #1
        BNE     %BT10
20
        LDR     v1, [a2, #UART_USR2_OFFSET]
        TST     v1, #1<<14 ; tx fifo empty bit
        BEQ     %BT20
        MOV     v1, #32
        STRB    v1, [a2, #UART_UTXD_OFFSET]

        ; Print value
        LDR     a1, [v2]
        MOV     a4, #8
10
        LDR     v1, [a2, #UART_USR2_OFFSET]
        TST     v1, #1<<14 ; tx fifo empty bit
        BEQ     %BT10
        LDRB    v1, [a3, a1, LSR #28]
        STRB    v1, [a2, #UART_UTXD_OFFSET]
        MOV     a1, a1, LSL #4
        SUBS    a4, a4, #1
        BNE     %BT10
20
        LDRB    v1, [a2, #UART_USR2_OFFSET]
        TST     v1, #1<<14 ; tx fifo empty bit
        BEQ     %BT20
        MOV     v1, #13
        STRB    v1, [a2, #UART_UTXD_OFFSET]
30
        LDR     v1, [a2, #UART_USR2_OFFSET]
        TST     v1, #1<<14 ; tx fifo empty bit
        BEQ     %BT30
        MOV     v1, #10
        STRB    v1, [a2, #UART_UTXD_OFFSET]

        ADD     v2, v2, #4 ; Counter dodgy exception vector
        SUBS    v3, v3, #4
        BGT     %BT100
        Pull    "a1-a4,v1-v3,pc"

DebugHALPrintByte ; Output a byte on top of stack to the serial port
        Push    "a1-a4,v1"
        LDR     a1, [sp,#5*4]
        LDR     a2, [sb, #:INDEX:DebugUART]
        ADR     a3, hextab
        MOV     a4, #2
10
        LDR     v1, [a2, #UART_USR2_OFFSET]
        TST     v1, #1<<14 ; tx fifo empty bit
        BEQ     %BT10
        LDRB    v1, [a3, a1, LSR #4]
        STRB    v1, [a2, #UART_UTXD_OFFSET]
10
        LDR     v1, [a2, #UART_USR2_OFFSET]
        TST     v1, #1<<14 ; tx fifo empty bit
        BEQ     %BT10
        AND     a1, a1, #&F
        LDRB    v1, [a3, a1]
        STRB    v1, [a2, #UART_UTXD_OFFSET]
        Pull    "a1-a4,v1"
        ADD     sp, sp, #4
        MOV     pc, lr

DebugCallstack ; Dump the stack until we crash
        Push    "r14"
        ADD     r14,r13,#4 ; Push original SP onto stack
        Push    "r0-r12,r14"
        MRS     a1, CPSR
        Push    "a1"
        ORR     a1, a1, #F32_bit+I32_bit ; No interruptions!
        MSR     CPSR_c, a1
        ADR     lr, DebugHALPrintReg
        B       DebugHALPrintReg

 | ; Debug

HAL_DebugRX
        MOV     a1, #-1
        ; fall UTXD_OFFSETough
HAL_DebugTX
        MOV     pc, lr

 ] ; Debug

;       EXPORT  |_dprintf|
;|_dprintf|
;       B       printf

        END
