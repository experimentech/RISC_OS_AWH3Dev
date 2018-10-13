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
        GET objmacs.s

        GBLL    FloatingPointArgsInRegs
FloatingPointArgsInRegs SETL {FALSE}
        [ FloatingPointArgsInRegs
        ! 0, "WARNING: Floating point arguments ARE being passed in FP registers"
        ]

        CodeArea

        EXPORT  _new_atan2
        EXPORT  atan2f
        EXPORT  fma
        EXPORT  fmaf
        EXPORT  log1p
        EXPORT  log1pf

        IMPORT  _ll_muluu

        ^       0,sp
Xsue    #       4
Xmhi    #       4
Xmlo    #       4
Ysue    #       4
Ymhi    #       4
Ymlo    #       4
Zsue    #       4
Zmhi    #       4
Zm2     #       4
Zm3     #       4
Zm4     #       4
fma_framesize * :INDEX:@

; An "extended extended" number with extra bits - 128 bits
; of mantissa. Exponent range same as normal exponent.
        ^       0,sp
XYsue   #       4
XYmhi   #       4
XYmmh   #       4
XYmml   #       4
XYmlo   #       4

; In: a1->128-bit mantissa, a2 = amount to denormalise by.
; Out: a1-a4 = denormalised mantissa (bit 127 = sticky)
m128_denormalise
        CMP     a2,#128
        BHS     m128_flush
        FunctionEntry ,"v1"
        MOV     ip,a2
        LDMIA   a1,{a1-a4}
        CMP     ip,#32
        BLO     %FT10
05      TEQ     a4,#0
        MOV     a4,a3
        ORRNE   a4,a4,#1
        MOV     a3,a2
        MOV     a2,a1
        MOV     a1,#0
        SUB     ip,ip,#32
        CMP     ip,#32
        BHS     %BT05
10      RSB     v1,ip,#32
        MOVS    lr,a4,LSL v1
        MOV     a4,a4,LSR ip
        ORRNE   a4,a4,#1
        ORR     a4,a4,a3,LSL v1
        MOV     a3,a3,LSR ip
        ORR     a3,a3,a2,LSL v1
        MOV     a2,a2,LSR ip
        ORR     a2,a2,a1,LSL v1
        MOV     a1,a1,LSR ip
        Return  ,"v1"

m128_flush
        LDMIA   a1,{a1-a4}
        ORRS    ip,a1,a2
        ORRS    ip,ip,a3
        ORRS    ip,ip,a4
        MOV     a1,#0
        MOV     a2,#0
        MOV     a3,#0
        MOVEQ   a4,#0
        MOVNE   a4,#1
        Return  ,,LinkNotStacked

; fma (fused multiply-add) implementation
fma
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!,{a1-a4}
        LDFD    f0,[sp],#8
        LDFD    f1,[sp],#8
        LDFD    f2,[sp,#0]
        ]
        FunctionEntry ,"v1-v6"
        ; Convert to extended precision, because they're easier to
        ; work with, and it eliminates subnormals.
        ; 64x64->128+64->53 is just as easy as 53x53->106+53->53
        ASSERT  fma_framesize = 3*12+8
        STFE    f2,[sp,#-12-8]!
        STFE    f1,[sp,#-12]!
        STFE    f0,[sp,#-12]!

        LDR     a1,Xsue
        LDR     a2,Ysue

        BIC     a3,a1,#&80000000        ; a1,a2 = exponents
        BIC     a4,a2,#&80000000

        ; Check for NaNs/infinities (exponent > &6000 will suffice
        ; because we know operands are only doubles, so max normal
        ; exponent is &43FF)
        CMP     a3,#&6000
        CMPLO   a4,#&6000
        BHS     fma_naninfmult

        ; If either operand has zero exponent, it's a zero, so
        ; zero result
        TEQ     a3,#0
        TEQNE   a4,#0
        BEQ     fma_zeromult

        ADD     v5,a3,a4
        SUB     v5,v5,#&3F00            ; v5 = prospective exponent
        SUB     v5,v5,#&00FE            ; (exponent range &379C-&47FE)
        EOR     v6,a1,a2                ; v6 = result sign
        AND     v6,v6,#&80000000

        ; Multiply the two mantissas
        ; Assemble the result in {v1,v2,v3,v4} (v1 high)
        ; Just break it down into 32x32->64 multiplies

        LDR     a1,Xmlo
        LDR     a2,Ymlo
        BL      _ll_muluu
        MOV     v4,a1
        MOV     v3,a2

        LDR     a1,Xmhi
        LDR     a2,Ymhi
        BL      _ll_muluu
        MOV     v2,a1
        MOV     v1,a2

        LDR     a1,Xmlo
        LDR     a2,Ymhi
        BL      _ll_muluu
        ADDS    v3,v3,a1
        ADCS    v2,v2,a2
        ADC     v1,v1,#0

        LDR     a1,Xmhi
        LDR     a2,Ymlo
        BL      _ll_muluu
        ADDS    v3,v3,a1
        ADCS    v2,v2,a2
        ADCS    v1,v1,#0

        ; May need to normalise, but by at most 1 bit
        ; given that operands were normalised.
        BMI     %FT01

        ADDS    v4,v4,v4
        ADCS    v3,v3,v3
        ADCS    v2,v2,v2
        ADC     v1,v1,v1
        SUB     v5,v5,#1
01
        ; Write x*y into XY
        ORR     a4,v5,v6
        ASSERT  :INDEX:XYsue = 0
        STMIA   sp,{a4,v1-v4}

        LDR     a1,Zsue
        BIC     a2,a1,#&80000000

        ; Check for z being inf/NaN. Again, exp>=&6000 is fine
        CMP     a2,#&6000
        BHS     fma_naninfadd

        ; Extend Z to 128 bits
        MOV     lr,#0
        STR     lr,Zm3
        STR     lr,Zm4

        ; Normal addition now of two extended extended numbers
        ; Mantissas are 128-bit, but we only have 106 significant
        ; bits. Use the bottom bit as a sticky bit in forthcoming
        ; normalisations, the other excess as guard/round bits.

        EOR     v4,a1,v6
        SUBS    a3,v5,a2
        ; a1 = z sign/exponent
        ; a2 = z exponent
        ; a3 = exponent difference (x*y) compared to z; flags set on this
        ; v4 = sign difference
        ; v5 = (x*y) exponent
        ; v6 = (x*y) sign
        ; XY and Z are 160-bit numbers
        BHI     fma_op2shift
        BEQ     fma_shiftdone
fma_op1shift
        MOV     v5, a2
        ADR     a1,XYmhi
        RSB     a2,a3,#0
        BL      m128_denormalise
        ASSERT  :INDEX:XYmhi=4
        STMIB   sp,{a1-a4}
        B       fma_shiftdone

fma_op2shift
        ADR     a1,Zmhi
        MOV     a2,a3
        BL      m128_denormalise
        ADR     lr,Zmhi
        STMIA   lr,{a1-a4}
        B       fma_shiftdone

; Now v4 = sign difference
;     v5 = prospective exponent
;     v6 = operand 1 sign
fma_shiftdone
        TEQ     v4,#0
        ASSERT  :INDEX:XYmhi=4
        LDMIB   sp,{a1-a4}
        ADR     lr,Zmhi
        LDMIA   lr,{v1-v4}
        BMI     fma_difference

fma_sum
        ADDS    a4,a4,v4
        ADCS    a3,a3,v3
        ADCS    a2,a2,v2
        ADCS    a1,a1,v1
        BCC     fma_adddone
        ADD     v5,v5,#1
        MOVS    a1,a1,RRX
        MOVS    a2,a2,RRX
        MOVS    a3,a3,RRX
        MOVS    a4,a4,RRX
        ORRCS   a4,a4,#1
        B       fma_adddone

fma_difference
        SUBS    a4,a4,v4
        SBCS    a3,a3,v3
        SBCS    a2,a2,v2
        SBCS    a1,a1,v1
        BCS     fma_diffnorm
        ; Subtraction came out negative
        EOR     v6,v6,#&80000000
        RSBS    a4,a4,#0
        RSCS    a3,a3,#0
        RSCS    a2,a2,#0
        RSCS    a1,a1,#0
fma_diffnorm
        ; Maximum normalisation is 106-odd bits. N flag indicates
        ; if we're already normalised.
        BMI     fma_adddone
        ; Try 1 bit to start with
        ADDS    a4,a4,a4
        ADCS    a3,a3,a3
        ADCS    a2,a2,a2
        ADCS    a1,a1,a1
        SUB     v5,v5,#1
        BMI     fma_adddone
        ; Okay, still not normalised. We can infer that the
        ; exponent difference was 0 or 1, so the round/sticky bits are 0.
        ; Check for an exact zero result first.
        ORR     lr,a1,a2
        ORR     lr,lr,a3
        ORRS    lr,lr,a4
        BEQ     fma_zerosub

20      TEQ     a1,#0
        MOVEQ   a1,a2
        MOVEQ   a2,a3
        MOVEQ   a3,a4
        MOVEQ   a4,#0
        SUBEQ   v5,v5,#32
        BEQ     %BT20

        MOV     lr,#0
        MOVS    ip,a1,LSR #16
        MOVEQ   a1,a1,LSL #16
        ADDEQ   lr,lr,#16
        MOVS    ip,a1,LSR #24
        MOVEQ   a1,a1,LSL #8
        ADDEQ   lr,lr,#8
        MOVS    ip,a1,LSR #28
        MOVEQ   a1,a1,LSL #4
        ADDEQ   lr,lr,#4
        MOVS    ip,a1,LSR #30
        MOVEQ   a1,a1,LSL #2
        ADDEQ   lr,lr,#2
        MOVS    ip,a1,LSR #31
        MOVEQ   a1,a1,LSL #1
        ADDEQ   lr,lr,#1

        RSBS    ip,lr,#32
        ORR     a1,a1,a2,LSR ip
        MOV     a2,a2,LSL lr
        ORR     a2,a2,a3,LSR ip
        MOV     a3,a3,LSL lr
        ORR     a3,a3,a4,LSR ip
        MOV     a4,a4,LSL lr
        SUB     v5,v5,lr

fma_adddone

; We now have an answer. v5 is our exponent; a1-a4 are 128
; bits of mantissa (bottom bit sticky). v6 is our sign.
; First, transfer the sticky bit to bit 63.

        ORRS    a3,a3,a4
        ORRNE   a2,a2,#1

fma_return
; Now just pack it back into an extended number, and convert
; to double. Hey presto.

        ORR     lr,v5,v6
        STR     lr,[sp,#0]
        STMIB   sp,{a1,a2}
        LDFE    f0,[sp],#fma_framesize
        MVFD    f0,f0
        Return  ,"v1-v6"

; Subtracted equal quantities. Result is +0 (rounding to nearest).
fma_zerosub
        MOV     v5,#0
        MOV     v6,#0
        B       fma_return

; One of x and y is an infinity or NaN. First check if z is a NaN;
; if it is then copy it into x to make sure MUF doesn't raise an
; invalid for 0*inf. [C99 says fma(0,inf,nan) is allowed to raise
; invalid, but the current IEEE 754R draft says it shouldn't.]
; Then fall through to the code that handles fma(0,finite,z).
fma_naninfmult
        CMF     f2,#0
        MVFVSD  f0,f2

; One of x and y is zero, the other is finite. The result is zero.
; We can thus just calculate x*y+z in normal arithmetic, to get
; all the appropriate exceptions out.
fma_zeromult
        MUFD    f0,f0,f1
        ADFD    f0,f0,f2
        ADD     sp,sp,#fma_framesize
        Return  ,"v1-v6"

; z is an infinity or NaN. We know x*y is finite and non-zero,
; so the result is z. Just return it.
fma_naninfadd
        MVFD    f0,f2
        ADD     sp,sp,#fma_framesize
        Return  ,"v1-v6"

; fmaf implementation is MUCH simpler. Note that this DOES
; raise "invalid" for fmaf(0,INFINITY,NAN), unlike fma. To avoid
; this would seriously affect its performance and prevent inlining,
; and we're claiming FP_FAST_FMAF.
fmaf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        LDFD    f2, [sp, #0]
        ]
        MVFS    f0, f0
        MVFS    f1, f1
        MVFS    f2, f2
        FMLE    f0, f0, f1              ; IVO possible
        ADFS    f0, f0, f2              ; UFL, OFL, INX possible
        Return  ,,LinkNotStacked

; This implementation based on Goldberg [1991], who showed that
; log1p(x) = (x * log(1+x)) / ((1+x) - 1) has error < 5*epsilon
; for 0 <= x < 0.75 if log is accurate. That should mean this is
; more than adequate to get a good double result in 0 <= x < 0.5.
; Experimentally, it does appear good for -0.5 < x < 0.5.
; For |x| >= 0.5 we just calculate log(1+x) in extended precision,
; as we won't be losing accuracy in the addition.
log1p
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        CNF     f0, #0.5
        BLE     log1p_bigneg
        ADFE    f1, f0, #1              ; if (1+x) == 1, return x
        CMF     f1, #1                  ; gets INX right
        Return  ,,LinkNotStacked,EQ
        CMF     f0, #0.5
        BPL     log1p_bigpos
        LGNE    f2, f1
        MUFE    f2, f2, f0
        SUFE    f3, f1, #1
        DVFD    f0, f2, f3
        Return  ,,LinkNotStacked

log1p_bigneg
        CNF     f0, #1                  ; To avoid inexact
        ADFGEE  f0, f0, #1
        LGND    f0, f0
        Return  ,,LinkNotStacked

log1p_bigpos
        LGND    f0, f1
        Return  ,,LinkNotStacked

log1pf
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        MVFS    f0, f0
        CNF     f0, #0.5
        BLE     log1pf_bigneg
        ADFE    f1, f0, #1              ; if (1+x) == 1, return x
        CMF     f1, #1                  ; gets INX right
        Return  ,,LinkNotStacked,EQ
        CMF     f0, #0.5
        BPL     log1pf_bigpos
        LGNE    f2, f1
        MUFE    f2, f2, f0
        SUFE    f3, f1, #1
        DVFS    f0, f2, f3
        Return  ,,LinkNotStacked

log1pf_bigneg
        CNF     f0, #1                  ; To avoid inexact
        ADFGEE  f0, f0, #1
        LGND    f0, f0
        Return  ,,LinkNotStacked

log1pf_bigpos
        LGNS    f0, f1
        Return  ,,LinkNotStacked

        MACRO
$name   Atan2 $p
        Function $name, leaf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        [ "$p" = "S"
        MVFS    f0, f0
        MVFS    f1, f1
        ]
        ; Try to deal with x != �y case as fast as possible.
        CMF     f0, f1
        CNFNE   f0, f1
        POLNE$p f0, f1, f0
        Return  ,,LinkNotStacked,NE
        ; If x == �y, then may be special cases (inf,inf) and (0,0), which
        ; POL rejects as invalid operations.
        ; Handle these by regularising arguments, eg: (+inf,-inf) -> (+1,-1)
        ; (+0,+0) -> (+0,+1)
        CMF     f0, #0
        BNE     %FT10
      [ FloatingPointArgsInRegs
        [ "$p" = "S"
        STFS    f1, [sp, #-4]!
        LDR     r2, [sp], #4
        |
        STFD    f1, [sp, #-8]!
        LDR     r2, [sp], #8
        ]
      ]
        TEQ     r2, #0
        MVFPL$p f1, #1
        MNFMI$p f1, #1
        POL$p   f0, f1, f0
        Return  ,,LinkNotStacked

10      MVFGT$p f2, #1
        MNFLE$p f2, #1
        CMF     f0, f1
        MVFEQ$p f1, f2
        MNFNE$p f1, f2
        POL$p   f0, f1, f2
        Return  ,,LinkNotStacked
        MEND

_new_atan2   Atan2   D
atan2f  Atan2   S

        END


