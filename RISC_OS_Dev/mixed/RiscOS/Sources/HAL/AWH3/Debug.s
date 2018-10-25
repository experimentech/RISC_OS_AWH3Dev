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
       	GBLL	DebugExported

        GET     UART
        GET     StaticWS
        GET     AllWinnerH3
        GET     board
        GET     Debug

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



;---------------------
; Code
;---------------------
 [ Debug




HAL_DebugTX
	LDR	a2, DebugUART
HAL_DebugTX_Loop
        LDRB    a3, [a2, #UART_LSR]
        TST     a3, #LSR_THRE
        BEQ     HAL_DebugTX_Loop
        STRB    a1, [a2, #UART_THR]
        MOV     pc, lr

;   PUSH {a2}
;   LDR a2, =UART_0
;   STRB a1, [a2, #UART_THR]
;   POP  {a2}
;   MOV pc, lr






HAL_DebugRX     ROUT
	LDR	a2, DebugUART
        LDRB    a1, [a2, #UART_LSR]
        TST     a1, #LSR_DR
        MOVEQ   a1, #-1
        LDRNEB  a1, [a2, #UART_RBR]
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
        Push    "a1-a4,v1"
        LDR     a1, [sp,#5*4]
        LDR     a2, DebugUART
        ADR     a3, hextab
        MOV     a4, #8
10
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT10
        LDRB    v1, [a3, a1, LSR #28]
        STRB    v1, [a2, #UART_THR]
        MOV     a1, a1, LSL #4
        SUBS    a4, a4, #1
        BNE     %BT10
20
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT20
        MOV     v1, #13
        STRB    v1, [a2, #UART_THR]
30
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT30
        MOV     v1, #10
        STRB    v1, [a2, #UART_THR]

        Pull    "a1-a4,v1"
        ADD     sp, sp, #4
        MOV     pc, lr

hextab  DCB "0123456789abcdef"
;--------
DebugMemDump ; r0 = start, r1 = size
        Push    "a1-a4,v1-v3,lr"
        MOV     v2, a1
        MOV     v3, a2
        LDR     a2, DebugUART
        ADR     a3, hextab
100
        ; Print addr
        MOV     a1, v2
        MOV     a4, #8
10
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT10
        LDRB    v1, [a3, a1, LSR #28]
        STRB    v1, [a2, #UART_THR]
        MOV     a1, a1, LSL #4
        SUBS    a4, a4, #1
        BNE     %BT10
20
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT20
        MOV     v1, #32
        STRB    v1, [a2, #UART_THR]

        ; Print value
        LDR     a1, [v2]
        MOV     a4, #8
10
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT10
        LDRB    v1, [a3, a1, LSR #28]
        STRB    v1, [a2, #UART_THR]
        MOV     a1, a1, LSL #4
        SUBS    a4, a4, #1
        BNE     %BT10
20
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT20
        MOV     v1, #13
        STRB    v1, [a2, #UART_THR]
30
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT30
        MOV     v1, #10
        STRB    v1, [a2, #UART_THR]

        ADD     v2, v2, #4 ; Counter dodgy exception vector
        SUBS    v3, v3, #4
        BGT     %BT100
        Pull    "a1-a4,v1-v3,pc"

DebugHALPrintByte ; Output a byte on top of stack to the serial port
        Push    "a1-a4,v1"
        LDR     a1, [sp,#5*4]
        LDR     a2, DebugUART
        ADR     a3, hextab
        MOV     a4, #2
10
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT10
        LDRB    v1, [a3, a1, LSR #4]
        STRB    v1, [a2, #UART_THR]
10
        LDRB    v1, [a2, #UART_LSR]
        TST     v1, #LSR_THRE
        BEQ     %BT10
        AND     a1, a1, #&F
        LDRB    v1, [a3, a1]
        STRB    v1, [a2, #UART_THR]
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
        ; fall through
HAL_DebugTX
        MOV     pc, lr

 ] ; Debug

;        EXPORT  |_dprintf|
;|_dprintf|
;        B       printf

        END
