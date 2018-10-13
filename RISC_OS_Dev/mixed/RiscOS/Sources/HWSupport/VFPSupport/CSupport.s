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

; Math functions taken from SharedCLibrary - just the bare minimum needed by
; softfloat

        EXPORT  __rt_udiv
        EXPORT  _ll_mul
        EXPORT  _ll_udiv
        EXPORT  _ll_shift_l
        EXPORT  _ll_ushift_r
        EXPORT  _ll_cmpu

; Redefine CLib macros to the general ones

        MACRO
        FunctionEntry $UsesSb, $SaveList, $MakeFrame
        ASSERT  "$UsesSb"=""
        ASSERT  "$MakeFrame"=""
        LCLS    Temps
        LCLS    TempsC
Temps   SETS    "$SaveList"
TempsC  SETS    ""
 [ Temps <> ""
TempsC SETS Temps :CC: ","
 ]
        Push    "$TempsC.lr"
        MEND

        MACRO
        Return $UsesSb, $ReloadList, $Base, $CC
        ASSERT  "$UsesSb"=""
        LCLS    Temps
        LCLS    TempsC
Temps   SETS    "$ReloadList"
TempsC  SETS    ""
 [ Temps <> ""
TempsC SETS Temps :CC: ","
 ]
   [ "$Base" = "LinkNotStacked" :LAND: "$ReloadList"=""
        MOV$CC  pc, lr
   |
        ASSERT  "$Base"=""
        Pull    "$TempsC.pc", $CC
   ]
        MEND

        MACRO
        Pop     $Regs,$Caret,$CC,$Base
        ASSERT  "$Caret"=""
        ASSERT  "$Base"=""
        Pull    "$Regs", $CC
        MEND

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


; Assume ARMv5+, but keep these switches in place so that any updates to the
; SCL code can easily be copied over to here

                GBLL    HaveCLZ
HaveCLZ         SETL    {TRUE}

                GBLL    HaveMULL
HaveMULL        SETL    {TRUE}

                GBLL    RuntimeArch
RuntimeArch     SETL    {FALSE}

        ; Multiply two 64-bit numbers
        ; In:  (a1,a2),(a3,a4)
        ; Out: (a1,a2)
_ll_mul         ROUT
        FunctionEntry
      [ RuntimeArch
        CPUArch ip, lr
        CMP     ip, #CPUArch_v4
        BCC     mul_hardway
      ]
      [ RuntimeArch :LOR: HaveMULL
        ; Have UMULL instruction
        MOV     ip, a1
        UMULL   a1, lr, a3, a1
        MLA     lr, ip, a4, lr
        MLA     a2, a3, a2, lr
        Return
      ]
      [ RuntimeArch :LOR: :LNOT: HaveMULL
mul_hardway     ROUT
        ; No UMULL instruction
        ; Break the operation down thus:
        ;              aaaaaaaa bbbb cccc
        ;            * dddddddd eeee ffff
        ;              ------------------
        ;                     cccc * ffff
        ;                bbbb * ffff
        ;                cccc * eeee
        ;           bbbb * eeee
        ;   aaaaaaaa * eeeeffff
        ; + dddddddd * bbbbcccc
        MUL     a2, a3, a2          ; msw starts as aaaaaaaa * eeeeffff
        MLA     a2, a4, a1, a2      ; msw += dddddddd * bbbbcccc

        MOV     lr, a3, LSR #16     ; lr = eeee from now on
        MOV     ip, a1, LSR #16     ; ip = bbbb from now on
        SUB     a4, a3, lr, LSL #16 ; a4 = ffff
        SUB     a3, a1, ip, LSL #16 ; a3 = cccc
        MUL     a1, a3, a4          ; lsw starts as cccc * ffff

        MUL     a4, ip, a4
        MUL     a3, lr, a3
        ADDS    a3, a4, a3          ; a3 = (bbbb * ffff + cccc * eeee) [0:31]
        MOV     a4, a3, RRX         ; a4 = (bbbb * ffff + cccc * eeee) [1:32]

        ADDS    a1, a1, a3, LSL #16 ; lsw now complete
        ADC     a2, a2, a4, LSR #15
        MLA     a2, ip, lr, a2      ; msw completed by adding bbbb * eeee
        Return
      ]
      
        ; Divide a uint64_t by another, returning both quotient and remainder
        ; In:  dividend (a1,a2), divisor (a3,a4)
        ; Out: quotient (a1,a2), remainder (a3,a4)
_ll_udiv        ROUT
        FunctionEntry , "a1-v6,sl,fp"
        ; Register usage:
        ; v1,v2 = quotient (initially 0)
        ; v3,v4 = remainder (initially dividend)
        ; v5,v6 = divisor
        ; sl = CPU architecture
        ; fp used as a scratch register
        ; note none of our callees use sl or fp in their usual sense
        Pop     "v3-v6"
_ll_udiv_lateentry  ROUT
        MOV     v1, #0
        MOV     v2, #0

        ; Calculate a floating point underestimate of the
        ; reciprocal of the divisor. The representation used is
        ;   mantissa: 16 bits
        ;   exponent: number of binary places below integers of lsb of mantissa
        ; The way the mantissa and exponent are calculated
        ; depends upon the number of leading zeros in the divisor.
     [ RuntimeArch
        CPUArch sl, lr
        CMP     sl, #CPUArch_v5T
        CLZCS   a1, v6
        MOVCC   a1, v6
        BLCC    soft_clz
     |
      [ HaveCLZ
        CLZ     a1, v6
      |
        MOV     a1, v6
        BL      soft_clz
      ]
     ]
        MOV     fp, a1 ; fp = leading zeros in divisor
        CMP     fp, #16
        BCS     %FT10
        ; Divisor has 0..15 leading zeros.
        MOV     a2, v6, LSL fp
        MOVS    a1, v5
        MOVEQS  a1, a2, LSL #16
        MOVNE   a1, #1 ; round up to account for loss of accuracy
        ADD     a1, a1, a2, LSR #16 ; divisor for calculating mantissa
        B       %FT40

10      CMP     v6, #0
        BEQ     %FT20
        ; Divisor has 16..31 leading zeros.
        SUB     a2, fp, #16
        RSB     a3, fp, #48
        MOVS    a1, v5, LSL a2
        MOVNE   a1, #1 ; round up to account for loss of accuracy
        ADD     a1, a1, v6, LSL a2
        ADD     a1, a1, v5, LSR a3 ; divisor for calculating mantissa
        B       %FT40

20
     [ RuntimeArch
        CMP     sl, #CPUArch_v5T
        CLZCS   a1, v5
        MOVCC   a1, v5
        BLCC    soft_clz
     |
      [ HaveCLZ
        CLZ     a1, v5
      |
        MOV     a1, v5
        BL      soft_clz
      ]
     ]
        ADD     fp, a1, #32 ; fp = leading zeros in divisor
        CMP     fp, #48
        BCS     %FT30
        ; Divisor has 32..47 leading zeros.
        MOV     a2, v5, LSL a1
        MOVS    a1, a2, LSL #16
        MOVNE   a1, #1 ; round up to account for loss of accuracy
        ADD     a1, a1, a2, LSR #16 ; divisor for calculating mantissa
        B       %FT40

30      CMP     v5, #0
        BEQ     %FT99
        ; Divisor has 48..63 leading zeros.
        SUB     a2, a1, #16
        MOV     a1, v5, LSL a2 ; divisor for calculating mantissa
        ; drop through

40      MOV     a2, #&80000000 ; dividend for calculating mantissa
        BL      __rt_udiv ; a1 = mantissa &8000..&10000
        RSB     a2, fp, #15+64 ; a2 = exponent
        TST     a1, #&10000
        MOVNE   a1, #&8000 ; force any &10000 mantissas into 16 bits
        SUBNE   a2, a2, #1

50      ; Main iteration loop:
        ; each time round loop, calculate a close underestimate of
        ; the quotient by multiplying through the "remainder" by the
        ; approximate reciprocal of the divisor.
        ; a1 = mantissa
        ; a2 = exponent

        ; Perform 16 (a1) * 64 (v3,v4) -> 80 (a3,a4,lr) multiply
      [ RuntimeArch
        CMP     sl, #CPUArch_v4
        BCC     %FT51
      ]

      [ RuntimeArch :LOR: HaveMULL
        ; Have UMULL instruction
        UMULL   a3, ip, v3, a1
        UMULL   a4, lr, v4, a1
        ADDS    a4, ip, a4
        ADC     lr, lr, #0
      ]
      [ RuntimeArch
        B       %FT60

51
      ]
      [ RuntimeArch :LOR: :LNOT: HaveMULL
        ; No UMULL instruction
        ;        aaaa bbbb cccc dddd
        ;      *                eeee
        ;        -------------------
        ;                dddd * eeee
        ;           cccc * eeee
        ;      bbbb * eeee
        ; aaaa * eeee
        MOV     ip, v4, LSR #16
        MOV     fp, v3, LSR #16
        SUB     a4, v4, ip, LSL #16
        SUB     a3, v3, fp, LSL #16
        MUL     ip, a1, ip
        MUL     fp, a1, fp
        MUL     a4, a1, a4
        MUL     a3, a1, a3
        MOV     lr, ip, LSR #16
        MOV     ip, ip, LSL #16
        ORR     ip, ip, fp, LSR #16
        MOV     fp, fp, LSL #16
        ADDS    a3, a3, fp
        ADCS    a4, a4, ip
        ADC     lr, lr, #0
      ]
60      ; Shift down by exponent
        ; First a word at a time, if necessary:
        SUBS    ip, a2, #32
        BCC     %FT62
61      MOV     a3, a4
        MOV     a4, lr
        MOV     lr, #0
        SUBS    ip, ip, #32
        BCS     %BT61
62      ; Then by bits, if necessary:
        ADDS    ip, ip, #32
        BEQ     %FT70
        RSB     fp, ip, #32
        MOV     a3, a3, LSR ip
        ORR     a3, a3, a4, LSL fp
        MOV     a4, a4, LSR ip
        ORR     a4, a4, lr, LSL fp

70      ; Now (a3,a4) contains an underestimate of the quotient.
        ; Add it to the running total for the quotient, then
        ; multiply through by divisor and subtract from the remainder.

        ; Sometimes (a3,a4) = 0, in which case this step can be skipped.
        ORRS    lr, a3, a4
        BEQ     %FT80

        ADDS    v1, v1, a3
        ADC     v2, v2, a4

      [ RuntimeArch
        CMP     sl, #CPUArch_v4
        MOVCS   lr, a3
        UMULLCS a3, ip, v5, lr
        MLACS   a4, v5, a4, ip
        MLACS   a4, v6, lr, a4
        BCS     %FT75
      ]
      [ :LNOT: RuntimeArch :LAND: HaveMULL
        MOV     lr, a3
        UMULL   a3, ip, v5, lr
        MLA     a4, v5, a4, ip
        MLA     a4, v6, lr, a4
      ]
      [ RuntimeArch :LOR: :LNOT: HaveMULL
        ; No UMULL instruction
        ; Proceeed as for mul_hardway
        MUL     a4, v5, a4
        MLA     a4, v6, a3, a4

        MOV     ip, a3, LSR #16
        MOV     lr, v5, LSR #16
        SUB     fp, a3, ip, LSL #16
        SUB     lr, v5, lr, LSL #16
        MUL     a3, fp, lr
        Push    "ip"

        MUL     ip, lr, ip
        MOV     lr, v5, LSR #16
        MUL     fp, lr, fp
        ADDS    fp, ip, fp
        MOV     ip, fp, RRX

        ADDS    a3, a3, fp, LSL #16
        ADC     a4, a4, ip, LSR #15
        Pop     "ip"
        MLA     a4, ip, lr, a4
      ]
75      SUBS    v3, v3, a3
        SBC     v4, v4, a4

80      ; Termination condition for iteration loop is
        ;   remainder < divisor
        ; OR
        ;   quotient increment == 0
        CMP     v3, v5
        SBCS    lr, v4, v6
        TEQCC   lr, lr     ; set Z if r < d (and preserve C)
        ORRCSS  lr, a3, a4 ; else Z = a3 and a4 both 0
        BNE     %BT50

        ; The final multiple of the divisor can get lost in rounding
        ; so subtract one more divisor if necessary
        CMP     v3, v5
        SBCS    lr, v4, v6
        BCC     %FT85
        ADDS    v1, v1, #1
        ADC     v2, v2, #0
        SUBS    v3, v3, v5
        SBC     v4, v4, v6
85
        Push    "v1-v4"
        Return  , "a1-v6,sl,fp"

99      ; Division by zero
        Pop     "v1-v6,sl,fp,lr"
        B       __rt_div0

        ; Shift a 64-bit number left
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_shift_l     ROUT
        RSBS    ip, a3, #32
        MOVHI   a2, a2, LSL a3
        ORRHI   a2, a2, a1, LSR ip
        MOVHI   a1, a1, LSL a3
        Return  ,, LinkNotStacked, HI
        SUB     ip, a3, #32
        MOV     a2, a1, LSL ip
        MOV     a1, #0
        Return  ,, LinkNotStacked

        ; Logical-shift a 64-bit number right
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_ushift_r    ROUT
        RSBS    ip, a3, #32
        MOVHI   a1, a1, LSR a3
        ORRHI   a1, a1, a2, LSL ip
        MOVHI   a2, a2, LSR a3
        Return  ,, LinkNotStacked, HI
        SUB     ip, a3, #32
        MOV     a1, a2, LSR ip
        MOV     a2, #0
        Return  ,, LinkNotStacked

        ; Compare two uint64_t numbers, or test two int64_t numbers for equality
        ; In:  (a1,a2),(a3,a4)
        ; Out: Z set if equal, Z clear if different
        ;      C set if unsigned higher or same, C clear if unsigned lower
        ;      all registers preserved
_ll_cmpu        ROUT
        CMP     a2, a4
        CMPEQ   a1, a3
        MOV     pc, lr ; irrespective of calling standard

        END
