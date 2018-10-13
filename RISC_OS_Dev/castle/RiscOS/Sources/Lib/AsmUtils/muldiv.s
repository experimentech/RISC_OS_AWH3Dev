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
; Title:  muldiv.s
; Purpose: muliplier and divider, with 64-bit intermediate products

; muldiv(a, b, c) -> a*b/c

        GET     hdr:ListOpts
        GET     hdr:Macros
        GET     hdr:System
        GET     hdr:Machine.<Machine>
        GET     hdr:APCS.<APCS>

        AREA |muldiv$$code|, CODE, READONLY, PIC

        EXPORT muldiv
muldiv
 ; the intermediate product is 64 bits long
 ; do everything using moduluses, and sort out signs later

        FunctionEntry "a1-a4,v1-v2"

 ; first, the double-length product, returned in a3 & a4
         ; uses ip, a1 and a2 as workspace
        MOV     a3, #0
        MOV     a4, #0
        MOV     ip, #0
        CMPS    a2, #0
        RSBLT   a2, a2, #0      ; abs b
        MOV     v2, a2
        CMPS    a1, #0
        RSBLT   a1, a1, #0      ; abs a
muldiv0
        MOVS    a2, a2, LSR #1
        BCC     muldiv1
        ADDS    a4, a4, a1
        ADC     a3, a3, ip
muldiv1
        MOVS    a1, a1, ASL #1
        ADC     ip, ip, ip
        CMPS    a2, #0
        BNE     muldiv0

 ; now the 64*32 bit divide
 ; dividend in a3 and a4
 ; remainder ends up in a4; quotient in ip
 ; uses a1 and a2 to hold the (shifted) divisor;
 ;      v1 for the current bit in the quotient
        LDR     a2, [sp, #8]    ; recover divisor
        CMPS    a2, #0
        Return  "a1-a4,v1-v2",,EQ
        RSBLT   a2, a2, #0      ; abs c
        MOV     v2, a2
        MOV     ip, #0
        MOV     a1, #0
        MOV     v1, #0
        MOV     lr, #1
muldiv2
        CMPS    a1, #&80000000
        BCS     muldiv3
        CMPS    a1, a3
        CMPEQS  a2, a4          ; compare of [a1, a2] against [a3, a4]
        BCS     muldiv3
        MOVS    a2, a2, ASL #1
        MOV     a1, a1, ASL #1
        ADC     a1, a1, #0
        ADD     v1, v1, #1
        B       muldiv2

muldiv3
        CMPS    a1, a3
        CMPEQS  a2, a4
        BHI     muldiv4
        CMPS    v1, #31
        ADDLE   ip, ip, lr, ASL v1
        SUBS    a4, a4, a2
        SBC     a3, a3, a1
muldiv4
        MOVS    a1, a1, ASR #1
        MOV     a2, a2, RRX
        SUBS    v1, v1, #1
        BGE     muldiv3

 ; now all we need to do is sort out the signs.
        LDMFD   sp!, {a1, a2, a3, v1}
        EOR     a2, a2, a1      ; a2 has the sign of a*b: a3 is the sign of c
        MOV     a1, ip
        TEQS    a2, a3          ; if a*b and c have opposite signs,
        RSBMI   a1, a1, #0      ; negate the quotient
        CMPS    a2, #0          ; and if the dividend was negative,
        RSBLT   a4, a4, #0      ; negate the remainder
;;;;    Now discard the remainder - J R C 19 March 1991
;;;;    STR     a4, [v1]
        Return  "v1-v2"

        END
