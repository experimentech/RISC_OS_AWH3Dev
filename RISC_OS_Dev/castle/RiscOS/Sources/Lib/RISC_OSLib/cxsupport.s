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

        CodeArea

        EXPORT  _cxd_mul [FPREGARGS]
        EXPORT  _cxf_mul [FPREGARGS]
        EXPORT  _cxd_div [FPREGARGS]
        EXPORT  _cxf_div [FPREGARGS]
        EXPORT  _cxd_rdv [FPREGARGS]
        EXPORT  _cxf_rdv [FPREGARGS]

        EXPORT  __log_cabs

        EXPORT  cabs
        EXPORT  cabsf
        EXPORT  csqrt
        EXPORT  csqrtf

        EXPORT  carg
        EXPORT  cargf
        EXPORT  cimag
        EXPORT  cimagf
        EXPORT  conj
        EXPORT  conjf
        EXPORT  cproj
        EXPORT  cprojf
        EXPORT  creal
        EXPORT  crealf

        IMPORT  hypot
        IMPORT  hypotf
        IMPORT  _new_atan2
        IMPORT  atan2f

FP_ZERO * 0
FP_SUBNORMAL * 1
FP_NORMAL * 2
FP_INFINITE * 3
FP_NAN * 4

|__fpclassifyl|
        STFE    f0,[sp,#-12]!
        LDMFD   sp!,{a1-a3}
        MOVS    a4,a1,LSL #17
        BEQ     %FT02
        ADDS    a4,a4,#1:SHL:17
        MOVCC   a1,#FP_NORMAL
        MOVCC   pc,lr
        ORRS    a4,a3,a2,LSL #1
        MOVEQ   a1,#FP_INFINITE
        MOVNE   a1,#FP_NAN
        MOV     pc,lr

02      ORRS    a4,a2,a3
        MOVEQ   a1,#FP_ZERO
        MOVEQ   pc,lr
        TEQ     a2,#0
        MOVMI   a1,#FP_NORMAL
        MOVPL   a1,#FP_SUBNORMAL
        MOV     pc,lr

copysignl
        STFE    f1,[sp,#-12]!
        STFE    f0,[sp,#-12]!
        LDMFD   sp,{a1-a4}
        BIC     a1,a1,#&80000000
        AND     a4,a4,#&80000000
        ORR     a1,a1,a4
        STR     a1,[sp,#0]
        LDFE    f0,[sp],#24
        MOV     pc,lr

; (f4+i*f5) * (f6+i*f7) -> (f0+i*f1) in full extended precision
_cx_mul
        MUFE    f0,f4,f6
        MUFE    f1,f5,f7
        SUFE    f0,f0,f1
        MUFE    f1,f5,f6
        MUFE    f2,f4,f7
        ADFE    f1,f1,f2
        CMF     f0,f0           ; if not (NaN+i*NaN) return now
        CMFVS   f1,f1
        MOVVC   pc,lr

        ; Recovery mechanism from Annex G

        STMFD   sp!,{v1-v5,lr}
        MOV     v5,#0           ; v5 = recalc flag
        SFMFD   f0,2,[sp]!      ; remember original attempt

        MVFE    f0,f4           ; v1-v4 = classification of f4-f7
        BL      __fpclassifyl
        MOV     v1,a1
        MVFE    f0,f5
        BL      __fpclassifyl
        MOV     v2,a1
        MVFE    f0,f6
        BL      __fpclassifyl
        MOV     v3,a1
        MVFE    f0,f7
        BL      __fpclassifyl
        MOV     v4,a1

        TEQ     v1,#FP_INFINITE
        TEQNE   v2,#FP_INFINITE
        BNE     %FT20

        ; (f4+i*f5) is infinite - box the infinity and remove NaNs from other operand
        TEQ     v1,#FP_INFINITE
        MVFEQE  f0,#1
        MVFNEE  f0,#0
        MVFE    f1,f4
        BL      copysignl
        MVFE    f4,f0

        TEQ     v2,#FP_INFINITE
        MVFEQE  f0,#1
        MVFNEE  f0,#0
        MVFE    f1,f5
        BL      copysignl
        MVFE    f5,f0

        TEQ     v3,#FP_NAN
        BNE     %FT01
        MVFE    f0,#0
        MVFE    f1,f6
        BL      copysignl
        MVFE    f6,f0
01
        TEQ     v4,#FP_NAN
        BNE     %FT01
        MVFE    f0,#0
        MVFE    f1,f7
        BL      copysignl
        MVFE    f7,f0
01
        MOV     v5,#1

20      TEQ     v3,#FP_INFINITE
        TEQNE   v4,#FP_INFINITE
        BNE     %FT40

        ; (f6+i*f7) is infinite - box the infinity and remove NaNs from other operand
        TEQ     v3,#FP_INFINITE
        MVFEQE  f0,#1
        MVFNEE  f0,#0
        MVFE    f1,f6
        BL      copysignl
        MVFE    f6,f0

        TEQ     v4,#FP_INFINITE
        MVFEQE  f0,#1
        MVFNEE  f0,#0
        MVFE    f1,f7
        BL      copysignl
        MVFE    f7,f0

        TEQ     v1,#FP_NAN
        BNE     %FT01
        MVFE    f0,#0
        MVFE    f1,f4
        BL      copysignl
        MVFE    f4,f0
01
        TEQ     v2,#FP_NAN
        BNE     %FT01
        MVFE    f0,#0
        MVFE    f1,f5
        BL      copysignl
        MVFE    f5,f0
01
        MOV     v5,#1

40      ; Annex G has guff to clear up NaNs generated by overflow
        ; (eg big * big - big * big -> inf - inf -> NaN), but that
        ; can't happen here because we know arguments were no larger
        ; than double.

        TEQ     v5,#1
        LFMNEFD f0,2,[sp]!
        LDMNEFD sp!,{v1-v5,pc}

        LDFE    f3,ExtInf
        MUFE    f0,f4,f6
        MUFE    f1,f5,f7
        SUFE    f0,f0,f1
        MUFE    f1,f5,f6
        MUFE    f2,f4,f7
        ADFE    f1,f1,f2
        MUFE    f0,f0,f3
        MUFE    f1,f1,f3
        ADD     sp,sp,#12*2
        LDMFD   sp!,{v1-v5,pc}

; (f4+i*f5) / (f6+i*f7) -> (f0+i*f1) in full extended precision
_cx_div
        MUFE    f0,f6,f6
        MUFE    f1,f7,f7
        ADFE    f3,f0,f1        ; f3 = denom
        MUFE    f0,f4,f6
        MUFE    f1,f5,f7
        ADFE    f0,f0,f1
        DVFE    f0,f0,f3
        MUFE    f1,f5,f6
        MUFE    f2,f4,f7
        SUFE    f1,f1,f2
        DVFE    f1,f1,f3
        CMF     f0,f0
        CMFVS   f1,f1
        MOVVC   pc,lr

        ; Based on Annex G implementation again. Recover infinities and zeros
        ; from NaN+i*NaN results. Three cases...

        STMFD   sp!,{v1-v4,lr}
        MVFE    f0,f4           ; v1-v4 = classification of f4-f7
        BL      __fpclassifyl
        MOV     v1,a1
        MVFE    f0,f5
        BL      __fpclassifyl
        MOV     v2,a1
        MVFE    f0,f6
        BL      __fpclassifyl
        MOV     v3,a1
        MVFE    f0,f7
        BL      __fpclassifyl
        MOV     v4,a1

        CMF     f3,#0
        BNE     %FT20
        TEQ     v1,#FP_NAN
        TEQEQ   v2,#FP_NAN
        BEQ     %FT20

        ; Case 1: non-zero / zero

        LDFE    f0,ExtInf
        MVFE    f1,f4
        BL      copysignl
        MUFE    f1,f0,f5
        MUFE    f0,f0,f4
        LDMFD   sp!,{v1-v4,pc}

20      TEQ     v1,#FP_INFINITE
        TEQNE   v2,#FP_INFINITE
        BNE     %FT40
        CMP     v3,#FP_NORMAL
        CMPLS   v4,#FP_NORMAL
        BHI     %FT40

        ; Case 2: infinity / finite

        TEQ     v1,#FP_INFINITE
        MVFEQE  f0,#1
        MVFNEE  f0,#0
        MVFE    f1,f4
        BL      copysignl
        MVFE    f4,f0

        TEQ     v2,#FP_INFINITE
        MVFEQE  f0,#1
        MVFNEE  f0,#0
        MVFE    f1,f5
        BL      copysignl
        MVFE    f5,f0

        LDFE    f3,ExtInf
        MUFE    f0,f4,f6
        MUFE    f1,f5,f7
        ADFE    f0,f0,f1
        MUFE    f0,f0,f3
        MUFE    f1,f5,f6
        MUFE    f2,f4,f7
        SUFE    f1,f1,f2
        MUFE    f1,f1,f3
        LDMFD   sp!,{v1-v4,pc}

40      TEQ     v3,#FP_INFINITE
        TEQNE   v4,#FP_INFINITE
        BNE     %FT60
        CMP     v1,#FP_NORMAL
        CMPLS   v2,#FP_NORMAL
        BHI     %FT60

        ; Case 3: finite / infinity

        TEQ     v3,#FP_INFINITE
        MVFEQE  f0,#1
        MVFNEE  f0,#0
        MVFE    f1,f6
        BL      copysignl
        MVFE    f6,f0

        TEQ     v4,#FP_INFINITE
        MVFEQE  f0,#1
        MVFNEE  f0,#0
        MVFE    f1,f7
        BL      copysignl
        MVFE    f7,f0

        MUFE    f0,f4,f6
        MUFE    f1,f5,f7
        ADFE    f0,f0,f1
        MUFE    f0,f0,#0
        MUFE    f1,f5,f6
        MUFE    f2,f4,f7
        SUFE    f1,f1,f2
        MUFE    f1,f1,#0
60      LDMFD   sp!,{v1-v4,pc}


ExtInf  DCD     &00007FFF, &00000000, &00000000


_cxd_mul ROUT
        SFMFD   f4,4,[sp]!
        MVFD    f4,f0
        MVFD    f5,f1
        MVFD    f6,f2
        MVFD    f7,f3
        MOV     ip,lr
        BL      _cx_mul
        MVFD    f0,f0
        MVFD    f1,f1
        LFMFD   f4,4,[sp]!
        MOV     pc,ip

_cxf_mul ROUT
        SFMFD   f4,4,[sp]!
        MVFS    f4,f0
        MVFS    f5,f1
        MVFS    f6,f2
        MVFS    f7,f3
        MOV     ip,lr
        BL      _cx_mul
        MVFS    f0,f0
        MVFS    f1,f1
        LFMFD   f4,4,[sp]!
        MOV     pc,ip

_cxd_div ROUT
        SFMFD   f4,4,[sp]!
        MVFD    f4,f0
        MVFD    f5,f1
        MVFD    f6,f2
        MVFD    f7,f3
_cxd_div1
        MOV     ip,lr
        BL      _cx_div
        MVFD    f0,f0
        MVFD    f1,f1
        LFMFD   f4,4,[sp]!
        MOV     pc,ip

_cxd_rdv ROUT
        SFMFD   f4,4,[sp]!
        MVFD    f4,f2
        MVFD    f5,f3
        MVFD    f6,f0
        MVFD    f7,f1
        B       _cxd_div1

_cxf_div ROUT
        SFMFD   f4,4,[sp]!
        MVFS    f4,f0
        MVFS    f5,f1
        MVFS    f6,f2
        MVFS    f7,f3
_cxf_div1
        MOV     ip,lr
        BL      _cx_div
        MVFS    f0,f0
        MVFS    f1,f1
        LFMFD   f4,4,[sp]!
        MOV     pc,ip

_cxf_rdv ROUT
        SFMFD   f4,4,[sp]!
        MVFS    f4,f2
        MVFS    f5,f3
        MVFS    f6,f0
        MVFS    f7,f1
        B       _cxf_div1

; calculate log(cabs(z)). Use extended intermediates to avoid over/underflow

__log_cabs
        BIC     a1,a1,#&80000000        ; Fast way to do fabs
        BIC     a3,a3,#&80000000
        STMFD   sp!,{a1-a4}
        LDFD    f2,[sp],#8
        LDFD    f3,[sp],#8
        CMF     f2,f3
        MUFVCE  f0,f2,f2
        MUFVCE  f1,f3,f3
        ADFVCE  f0,f0,f1
        LGNVCD  f0,f0
        MUFVCD  f0,f0,#0.5
        MOVVC   pc,lr
; cabs(nan,inf)==cabs(inf,nan)==inf; otherwise cabs(nan,x)=nan
        LDFD    f0,DblInf
        CMF     f2,f0
        CMFNE   f3,f0
        ADFNED  f0,f2,f3
        MOV     pc,lr

cabs
        B       hypot

cabsf
        STMFD   sp!,{a1-a2}
        LDFS    f0,[sp],#4
        LDFS    f1,[sp],#4
        STFD    f0,[sp,#-16]!
        STFD    f1,[sp,#8]
        LDMFD   sp!,{a1-a4}
        B       hypotf

csqrtx
        CMF     f1,#0
        BMI     csqrt_negi
        BEQ     csqrt_real
        BVS     csqrt_nani
csqrt_posi
        LDFE    f3,ExtInf
        CMF     f1,f3
        BEQ     csqrt_infi
        MUFE    f2,f0,f0
        MUFE    f3,f1,f1
        ADFE    f2,f2,f3
        SQTE    f2,f2           ; f2 = |z|
        ABSE    f3,f0
        ADFE    f2,f3,f2
        MUFE    f2,f2,#0.5
        SQTE    f2,f2           ; f2 = w = sqrt((|x|+|z|)/2)
        CMF     f0,#0
        BMI     csqrt_negr
        MVFE    f0,f2
        DVFE    f1,f1,f2
        MUFE    f1,f1,#0.5
        MOV     pc,lr
csqrt_negr
        DVFE    f0,f1,f2
        MUFE    f0,f0,#0.5
        MVFE    f1,f2
        CMF     f0,f1
        MOV     pc,lr

csqrt_infi
        MVFE    f0,f1
        MOV     pc,lr

csqrt_negi
        MOV     a4,lr
        MNFE    f1,f1
        BL      csqrt_posi
        MNFE    f1,f1
        MOV     pc,a4

csqrt_real
        CMF     f0,#0
        BMI     csqrt_negreal
        BEQ     csqrt_zero
        MVFVSE  f1,f0           ; NaN propagation
        SQTE    f0,f0
        MOV     pc,lr

csqrt_negreal
        STFE    f1,[sp,#-12]!
        LDR     a3,[sp],#12
        MNFE    f0,f0
        SQTE    f1,f0
        MVFE    f0,#0
        TEQ     a3,#0
        MNFMIE  f1,f1
        MOV     pc,lr

csqrt_zero
        MVFE    f0,#0
        MOV     pc,lr

csqrt_nani
        LDFE    f3,ExtInf
        CMF     f0,f3
        MOVEQ   pc,lr
        CNF     f0,f3
        ABSNEE  f0,f1
        MOVNE   pc,lr
        ; csqrt(-inf + I*NaN) - muck around for conj() identity
        STFE    f1,[sp,#-12]!
        LDR     a3,[sp],#12
        TEQ     a3,#0
        ABSE    f0,f1
        MVFPLE  f1,f3
        MNFMIE  f1,f3
        MOV     pc,lr


; (pos+I*0) -> (sqrt(pos)+I*0)
; (+0+I*0)  -> (+0+I*0)
; (-0+I*0)  -> (+0+I*0)
; (NAN+I*0) -> (NaN+I*NaN)
; (neg+I*0) -> (0+I*sqrt(-neg))

csqrt
        STMFD   sp!,{a1-a4}
        LDFD    f0,[sp],#8
        LDFD    f1,[sp],#8
        MOV     ip,lr
        BL      csqrtx
        MVFD    f0,f0
        MVFD    f1,f1
        MOV     pc,ip

csqrtf
        STMFD   sp!,{a1-a2}
        LDFS    f0,[sp],#4
        LDFS    f1,[sp],#4
        MOV     ip,lr
        BL      csqrtx
        MVFS    f0,f0
        MVFS    f1,f1
        MOV     pc,ip

carg
        MOV     ip,a1
        MOV     a1,a3
        MOV     a3,ip
        MOV     ip,a2
        MOV     a2,a4
        MOV     a4,ip
        B       _new_atan2

cargf
        STMFD   sp!,{a1-a2}
        LDFS    f0,[sp],#4
        LDFS    f1,[sp],#4
        STFD    f0,[sp,#-8]!
        STFD    f1,[sp,#-8]!
        LDMIA   sp!,{a1-a4}
        B       atan2f

cimag
        STMFD   sp!,{a3-a4}
        LDFD    f0,[sp],#8
        MOV     pc,lr

cimagf
        STR     a2,[sp,#-4]!
        LDFS    f0,[sp],#4
        MOV     pc,lr

conj
        EOR     a3,a3,#&80000000
        STMFD   sp!,{a1-a4}
        LDFD    f0,[sp],#8
        LDFD    f1,[sp],#8
        MOV     pc,lr

conjf
        EOR     a2,a2,#&80000000
        STMFD   sp!,{a1-a2}
        LDFS    f0,[sp],#4
        LDFS    f1,[sp],#4
        MOV     pc,lr

DblInf
        DCD     &7FF00000,&00000000
cproj
        LDFD    f2,DblInf
        ABSD    f3,f0
        CMF     f3,f2
        ABSNED  f3,f1
        CMFNE   f3,f2
        MOVNE   pc,lr
        MVFD    f0,f2
        STFD    f1,[sp,#-8]!
        LDMIA   sp!,{a1,a2}
        TST     a1,#0
        MVFPLD  f1,#0
        MNFMID  f1,#0
        MOV     pc,lr

SglInf
        DCD     &7F800000
cprojf
        LDFS    f2,SglInf
        ABSS    f3,f0
        CMF     f3,f2
        ABSNES  f3,f1
        CMFNE   f3,f2
        MOVNE   pc,lr
        MVFS    f0,f2
        STFS    f1,[sp,#-4]!
        LDR     a1,[sp],#4
        TST     a1,#0
        MVFPLS  f1,#0
        MNFMIS  f1,#0
        MOV     pc,lr

creal
        STMFD   sp!,{a1-a2}
        LDFD    f0,[sp],#8
        MOV     pc,lr

crealf
        STR     a1,[sp,#-4]!
        LDFS    f0,[sp],#4
        MOV     pc,lr

        END
