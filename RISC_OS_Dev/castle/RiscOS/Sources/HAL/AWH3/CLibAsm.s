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

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  |__rt_sdiv|

|__rt_sdiv|
; Signed divide of a2 by a1: returns quotient in a1, remainder in a2
; Quotient is truncated (rounded towards zero).
; Sign of remainder = sign of dividend.
; Destroys a3, a4 and ip
; Negates dividend and divisor, then does an unsigned divide; signs
; get sorted out again at the end.

        ANDS    a3, a1, #&80000000
        RSBMI   a1, a1, #0
        EORS    a4, a3, a2, ASR #32
        RSBCS   a2, a2, #0
        RSBS    ip, a1, a2, LSR #3
        BCC     s_sh2
        RSBS    ip, a1, a2, LSR #8
        BCC     s_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&FF000000
        RSBS    ip, a1, a2, LSR #4
        BCC     s_sh3
        RSBS    ip, a1, a2, LSR #8
        BCC     s_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&00FF0000
        RSBS    ip, a1, a2, LSR #8
        MOVCS   a1, a1, LSL #8
        ORRCS   a3, a3, #&0000FF00
        RSBS    ip, a1, a2, LSR #4
        BCC     s_sh3
        RSBS    ip, a1, #0
        BCS     dividebyzero
s_loop  MOVCS   a1, a1, LSR #8
s_sh7   RSBS    ip, a1, a2, LSR #7
        SUBCS   a2, a2, a1, LSL #7
        ADC     a3, a3, a3
s_sh6   RSBS    ip, a1, a2, LSR #6
        SUBCS   a2, a2, a1, LSL #6
        ADC     a3, a3, a3
s_sh5   RSBS    ip, a1, a2, LSR #5
        SUBCS   a2, a2, a1, LSL #5
        ADC     a3, a3, a3
s_sh4   RSBS    ip, a1, a2, LSR #4
        SUBCS   a2, a2, a1, LSL #4
        ADC     a3, a3, a3
s_sh3   RSBS    ip, a1, a2, LSR #3
        SUBCS   a2, a2, a1, LSL #3
        ADC     a3, a3, a3
s_sh2   RSBS    ip, a1, a2, LSR #2
        SUBCS   a2, a2, a1, LSL #2
        ADC     a3, a3, a3
s_sh1   RSBS    ip, a1, a2, LSR #1
        SUBCS   a2, a2, a1, LSL #1
        ADC     a3, a3, a3
s_sh0   RSBS    ip, a1, a2
        SUBCS   a2, a2, a1
        ADCS    a3, a3, a3
        BCS     s_loop
        EORS    a1, a3, a4, ASR #31
        ADD     a1, a1, a4, LSR #31
        RSBCS   a2, a2, #0
        MOV     pc, lr

dividebyzero
        B       panic

        EXPORT  |__rt_udiv|
|__rt_udiv|
; Unsigned divide of a2 by a1: returns quotient in a1, remainder in a2
; Destroys a3 and ip

        MOV     a3, #0
        RSBS    ip, a1, a2, LSR #3
        BCC     u_sh2
        RSBS    ip, a1, a2, LSR #8
        BCC     u_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&FF000000
        RSBS    ip, a1, a2, LSR #4
        BCC     u_sh3
        RSBS    ip, a1, a2, LSR #8
        BCC     u_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&00FF0000
        RSBS    ip, a1, a2, LSR #8
        MOVCS   a1, a1, LSL #8
        ORRCS   a3, a3, #&0000FF00
        RSBS    ip, a1, a2, LSR #4
        BCC     u_sh3
        RSBS    ip, a1, #0
        BCS     dividebyzero
u_loop  MOVCS   a1, a1, LSR #8
u_sh7   RSBS    ip, a1, a2, LSR #7
        SUBCS   a2, a2, a1, LSL #7
        ADC     a3, a3, a3
u_sh6   RSBS    ip, a1, a2, LSR #6
        SUBCS   a2, a2, a1, LSL #6
        ADC     a3, a3, a3
u_sh5   RSBS    ip, a1, a2, LSR #5
        SUBCS   a2, a2, a1, LSL #5
        ADC     a3, a3, a3
u_sh4   RSBS    ip, a1, a2, LSR #4
        SUBCS   a2, a2, a1, LSL #4
        ADC     a3, a3, a3
u_sh3   RSBS    ip, a1, a2, LSR #3
        SUBCS   a2, a2, a1, LSL #3
        ADC     a3, a3, a3
u_sh2   RSBS    ip, a1, a2, LSR #2
        SUBCS   a2, a2, a1, LSL #2
        ADC     a3, a3, a3
u_sh1   RSBS    ip, a1, a2, LSR #1
        SUBCS   a2, a2, a1, LSL #1
        ADC     a3, a3, a3
u_sh0   RSBS    ip, a1, a2
        SUBCS   a2, a2, a1
        ADCS    a3, a3, a3
        BCS     u_loop
        MOV     a1, a3
        MOV     pc, lr

; Fast unsigned divide by 10: dividend in a1
; Returns quotient in a1, remainder in a2

        EXPORT  |__rt_udiv10|
|__rt_udiv10|
        SUB     a2, a1, #10
        SUB     a1, a1, a1, LSR #2
        ADD     a1, a1, a1, LSR #4
        ADD     a1, a1, a1, LSR #8
        ADD     a1, a1, a1, LSR #16
        MOV     a1, a1, LSR #3
        ADD     a3, a1, a1, LSL #2
        SUBS    a2, a2, a3, LSL #1
        ADDPL   a1, a1, #1
        ADDMI   a2, a2, #10
        MOV     pc, lr

        ; Divide a uint64_t by 10, returning both quotient and remainder
        ; In:  (a1,a2)
        ; Out: quotient (a1,a2), remainder (a3,a4)
        EXPORT  _ll_udiv10
_ll_udiv10
        STR     a1, [sp, #-4]!
        ; Multiply by 0.6 (= &0.999 recurring)
        ; and subtract multiplication by 0.5 (LSR #1).
        ; Ignore fractional parts for now.
        LDR     ip, =&99999999
        UMULL   a4, a3, a1, ip
        UMULL   a4, ip, a2, ip
        MOVS    a2, a2, LSR #1
        MOVS    a1, a1, RRX
        ADCS    a1, a1, #0
        ADC     a2, a2, #0
        SUBS    a1, a4, a1
        SBC     a2, ip, a2
        ADDS    a1, a1, ip
        ADC     a2, a2, #0
        ADDS    a1, a1, a3
        ADC     a2, a2, #0
        ; It can be shown mathematically that this is an underestimate
        ; of the true quotient by up to 2.5. Compensate by detecting
        ; over-large remainders.
40      MOV     ip, #10
        MUL     a3, a1, ip ; quotient * 10 (MSW is unimportant)
        LDR     a4, [sp], #4
        SUB     a3, a4, a3 ; remainder between 0 and 25
        ; Bring the remainder back within range.
        ; For a number x <= 68, x / 10 == (x * 13) >> 7
        MOV     a4, #13
        MUL     a4, a3, a4
        MOV     a4, a4, LSR #7
        ADDS    a1, a1, a4
        ADC     a2, a2, #0
        MUL     a4, ip, a4
        SUB     a3, a3, a4
        MOV     a4, #0
        MOV     pc, lr

        ; Logical-shift a 64-bit number right
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
        EXPORT  _ll_ushift_r
_ll_ushift_r
        RSBS    ip, a3, #32
        MOVHI   a1, a1, LSR a3
        ORRHI   a1, a1, a2, LSL ip
        MOVHI   a2, a2, LSR a3
        MOVHI   pc, lr
        SUB     ip, a3, #32
        MOV     a1, a2, LSR ip
        MOV     a2, #0
        MOV     pc, lr

        ; Multiply a 64-bit number by a uint32_t
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
        EXPORT _ll_mullu
_ll_mullu
        UMULL   a1, lr, a3, a1
        MLA     a2, a3, a2, lr
        MOV     pc, lr

        IMPORT  sprintf
        IMPORT  printf
        EXPORT  |_sprintf|
        EXPORT  |_printf|

_sprintf
        B       sprintf

_printf
        B       printf

        ; Compare two uint64_t numbers, or test two int64_t numbers for equality
        ; In:  (a1,a2),(a3,a4)
        ; Out: Z set if equal, Z clear if different
        ;      C set if unsigned higher or same, C clear if unsigned lower
        ;      all registers preserved
        EXPORT  _ll_cmpu
_ll_cmpu
        CMP     a2, a4
        CMPEQ   a1, a3
        MOV     pc, lr

        EXPORT  memset
memset
        ORR     ip, a1, a3
        TST     ip, #3
        BEQ     memset_wordaligned
        MOV     a4, a1
        TEQ     a3, #0
10      STRNEB  a2, [a4], #1
        SUBS    a3, a3, #1
        BNE     %BT10
        MOV     pc, lr

memset_wordaligned
        AND     a2, a2, #&FF
        ORR     a2, a2, a2, LSL #8
        ORR     a2, a2, a2, LSL #16
        ; fall through

        EXPORT  _memset
_memset
        MOV     a4, a1
        TEQ     a3, #0
10      STRNE   a2, [a4], #4
        SUBS    a3, a3, #4
        BNE     %BT10
        MOV     pc, lr

        EXPORT  panic
panic
        BKPT    &1234
        B       panic

        END
