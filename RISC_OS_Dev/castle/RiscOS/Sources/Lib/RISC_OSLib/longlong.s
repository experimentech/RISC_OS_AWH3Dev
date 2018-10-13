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
        GET     objmacs.s
        GET     h_common.s

        CodeArea

        EXPORT  _ll_from_u
        EXPORT  _ll_from_l
        EXPORT  _ll_to_l

        EXPORT  _ll_add
        EXPORT  _ll_addlu
        EXPORT  _ll_addls
        EXPORT  _ll_adduu
        EXPORT  _ll_addss
        EXPORT  _ll_sub
        EXPORT  _ll_sublu
        EXPORT  _ll_subls
        EXPORT  _ll_subuu
        EXPORT  _ll_subss
        EXPORT  _ll_rsb
        EXPORT  _ll_rsblu
        EXPORT  _ll_rsbls
        EXPORT  _ll_rsbuu
        EXPORT  _ll_rsbss
        EXPORT  _ll_mul
        EXPORT  _ll_mullu
        EXPORT  _ll_mulls
        EXPORT  _ll_muluu
        EXPORT  _ll_mulss
        EXPORT  _ll_udiv
        EXPORT  _ll_urdv
        EXPORT  _ll_udiv10
        EXPORT  _ll_sdiv
        EXPORT  _ll_srdv
        EXPORT  _ll_sdiv10

        EXPORT  _ll_not
        EXPORT  _ll_neg
        EXPORT  _ll_and
        EXPORT  _ll_or
        EXPORT  _ll_eor
        EXPORT  _ll_shift_l
        EXPORT  _ll_ushift_r
        EXPORT  _ll_sshift_r

        EXPORT  _ll_cmpu
        EXPORT  _ll_cmpge
        EXPORT  _ll_cmple

        IMPORT  __rt_div0
        IMPORT  __rt_udiv

        GET     Hdr:ListOpts
        GET     Hdr:CPU.Arch
        GET     Hdr:OSMisc

                GBLL    HaveCLZ
HaveCLZ         SETL    :LNOT: NoARMv5

                GBLL    HaveMULL
HaveMULL        SETL    :LNOT: NoARMM

                GBLL    RuntimeArch
RuntimeArch     SETL    {FALSE} ; TODO - Get this runtime detection working. s.k_data suggests there's plenty of spare space for storing O__architecture?

 [ RuntimeArch
XOS_EnterOS     *       &16
XOS_LeaveOS     *       &7C

CPUArch_pre_v4  *       0
CPUArch_v4      *       1
CPUArch_v4T     *       2
CPUArch_v5      *       3
CPUArch_v5T     *       4
CPUArch_v5TE    *       5
CPUArch_v5TEJ   *       6
CPUArch_v6      *       7

cp15    CP      15
c0      CN      0

        ; Routine to determine the CPU architecture
        ; (needs to be called from init somewhere)
        ; In:  v6 = static base, USR mode
ReadCPUArch
        Push    "a1,lr"
        SWI     XOS_EnterOS
        MRC     cp15, 0, lr, c0, c0, 0
        ANDS    a1, lr, #&F000
        MOVEQ   lr, #0 ; 0 if pre-ARM7
        TEQNE   a1, #&7000
        MOVEQ   a1, lr, LSR #22
        ANDEQ   a1, a1, #2 ; ARM7 may be v3 or v4T
        MOVNE   a1, lr, LSR #16
        ANDNE   a1, a1, #&F ; post-ARM7 may be v4 onwards
;        STR     a1, [v6, #O__architecture]
        SWI     XOS_LeaveOS
      [ {CONFIG}=26
        TEQVSP  pc, #0
        [ NoARMa
        NOP
        ]
      |
        MSRVS   CPSR_c, #0 ; Assume OS_LeaveOS error means we're on a 26bit OS
        [ StrongARM_MSR_bug
        NOP
        ]
      ]
        Pop     "a1,pc"

        ; CPUArch
        ; Determine the architecture of the CPU
        ; Ideally this should be cached in static workspace
        ; but that can't be done as a retrofit to old versions!
        ; $r: output register to hold one of the constants above
        ; $tmp: scratch register
        MACRO
$l      CPUArch $r, $tmp
 [ 1=1
        MOV     $r, #CPUArch_pre_v4 ; eg 7500FE
 |
  [ 1=1
        MOV     $r, #CPUArch_v4 ; eg StrongARM
  |
   [ 1=1
        MOV     $r, #CPUArch_v5TE ; eg XScale
   |
        LoadStaticBase $r, $tmp
        LDR     $r, [$r, #O__architecture]
   ]
  ]
 ]
        MEND
 ]

        ; Convert uint32_t to uint64_t or int64_t
        ; In:  a1
        ; Out: (a1,a2)
_ll_from_u      ROUT
        MOV     a2, #0
        Return  ,, LinkNotStacked

        ; Convert int32_t to int64_t or uint64_t
        ; In:  a1
        ; Out: (a1,a2)
_ll_from_l      ROUT
        MOV     a2, a1, ASR #31
        Return  ,, LinkNotStacked

        ; Convert int64_t or uint64_t to int32_t or uint32_t
        ; In:  (a1,a2)
        ; Out: a1
_ll_to_l        ROUT
        Return  ,, LinkNotStacked


        ; Add two 64-bit numbers
        ; In:  (a1,a2),(a3,a4)
        ; Out: (a1,a2)
_ll_add         ROUT
        ADDS    a1, a1, a3
        ADC     a2, a2, a4
        Return  ,, LinkNotStacked

        ; Add a uint32_t to a 64-bit number
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_addlu       ROUT
        ADDS    a1, a1, a3
        ADC     a2, a2, #0
        Return  ,, LinkNotStacked

        ; Add an int32_t to a 64-bit number
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_addls       ROUT
        ADDS    a1, a1, a3
        ADC     a2, a2, a3, ASR #31
        Return  ,, LinkNotStacked

       ; Create a 64-bit number by adding two uint32_t numbers
       ; In:  a1,a2
       ; Out: (a1,a2)
_ll_adduu       ROUT
        ADDS    a1, a1, a2
        MOVCC   a2, #0
        MOVCS   a2, #1
        Return  ,, LinkNotStacked

       ; Create a 64-bit number by adding two int32_t numbers
       ; In:  a1,a2
       ; Out: (a1,a2)
_ll_addss       ROUT
        MOV     ip, a1, ASR #31
        ADDS    a1, a1, a2
        ADC     a2, ip, a2, ASR #31
        Return  ,, LinkNotStacked


        ; Subtract two 64-bit numbers
        ; In:  (a1,a2),(a3,a4)
        ; Out: (a1,a2)
_ll_sub         ROUT
        SUBS    a1, a1, a3
        SBC     a2, a2, a4
        Return  ,, LinkNotStacked

        ; Subtract a uint32_t from a 64-bit number
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_sublu       ROUT
        SUBS    a1, a1, a3
        SBC     a2, a2, #0
        Return  ,, LinkNotStacked

        ; Subtract an int32_t from a 64-bit number
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_subls       ROUT
        SUBS    a1, a1, a3
        SBC     a2, a2, a3, ASR #31
        Return  ,, LinkNotStacked

       ; Create a 64-bit number by subtracting two uint32_t numbers
       ; In:  a1,a2
       ; Out: (a1,a2)
_ll_subuu       ROUT
        SUBS    a1, a1, a2
        MOVCC   a2, #-1
        MOVCS   a2, #0   ; carry = not borrow
        Return  ,, LinkNotStacked

       ; Create a 64-bit number by subtracting two int32_t numbers
       ; In:  a1,a2
       ; Out: (a1,a2)
_ll_subss       ROUT
        MOV     ip, a1, ASR #31
        SUBS    a1, a1, a2
        SBC     a2, ip, a2, ASR #31
        Return  ,, LinkNotStacked


        ; Reverse-subtract two 64-bit numbers
        ; In:  (a1,a2),(a3,a4)
        ; Out: (a1,a2)
_ll_rsb         ROUT
        RSBS    a1, a1, a3
        RSC     a2, a2, a4
        Return  ,, LinkNotStacked

        ; Subtract a 64-bit number from a uint32_t
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_rsblu       ROUT
        RSBS    a1, a1, a3
        RSC     a2, a2, #0
        Return  ,, LinkNotStacked

        ; Subtract a 64-bit number from an int32_t
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_rsbls       ROUT
        RSBS    a1, a1, a3
        RSC     a2, a2, a3, ASR #31
        Return  ,, LinkNotStacked

       ; Create a 64-bit number by reverse-subtracting two uint32_t numbers
       ; In:  a1,a2
       ; Out: (a1,a2)
_ll_rsbuu       ROUT
        RSBS    a1, a1, a2
        MOVCC   a2, #-1
        MOVCS   a2, #0   ; carry = not borrow
        Return  ,, LinkNotStacked

       ; Create a 64-bit number by reverse-subtracting two int32_t numbers
       ; In:  a1,a2
       ; Out: (a1,a2)
_ll_rsbss       ROUT
        MOV     ip, a1, ASR #31
        RSBS    a1, a1, a2
        RSB     a2, ip, a2, ASR #31
        Return  ,, LinkNotStacked


        ; Multiply two 64-bit numbers
        ; In:  (a1,a2),(a3,a4)
        ; Out: (a1,a2)
_ll_mul         ROUT
      [ NoARMM
_ll_mul_NoARMM  ROUT
        FunctionEntry
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
      [ SupportARMM :LAND: (:LNOT: NoARMM :LOR: SHARED_C_LIBRARY)
_ll_mul_SupportARMM
        FunctionEntry
        ; Have UMULL instruction
        MOV     ip, a1
        UMULL   a1, lr, a3, a1
        MLA     lr, ip, a4, lr
        MLA     a2, a3, a2, lr
        Return
      ]

        ; Multiply a 64-bit number by a uint32_t
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_mullu       ROUT
      [ NoARMM
_ll_mullu_NoARMM
        MOV     a4, #0
        B       _ll_mul_NoARMM
      ]
      [ SupportARMM :LAND: (:LNOT: NoARMM :LOR: SHARED_C_LIBRARY)
_ll_mullu_SupportARMM
        ; Have UMULL instruction
        UMULL   a1, ip, a3, a1
        MLA     a2, a3, a2, ip
        Return  ,, LinkNotStacked
      ]

        ; Multiply a 64-bit number by an int32_t
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_mulls       ROUT
        MOV     a4, a3, ASR #31
        B       _ll_mul

        ; Create a 64-bit number by multiplying two uint32_t numbers
        ; In:  a1,a2
        ; Out: (a1,a2)
_ll_muluu       ROUT
      [ NoARMM
_ll_muluu_NoARMM
        ; No UMULL instruction
        MOV     a3, a2
        MOV     a2, #0
        MOV     a4, #0
        B       _ll_mul_NoARMM
      ]
      [ SupportARMM :LAND: (:LNOT: NoARMM :LOR: SHARED_C_LIBRARY)
_ll_muluu_SupportARMM
        ; Have UMULL instruction
        MOV     ip, a1
        UMULL   a1, a2, ip, a2
        Return  ,, LinkNotStacked
      ]

        ; Create a 64-bit number by multiplying two int32_t numbers
        ; In:  a1,a2
        ; Out: (a1,a2)
_ll_mulss       ROUT
      [ NoARMM
_ll_mulss_NoARMM
        ; No SMULL instruction
        MOV     a3, a2
        MOV     a2, a1, ASR #31
        MOV     a4, a3, ASR #31
        B       _ll_mul_NoARMM
      ]
      [ SupportARMM :LAND: (:LNOT: NoARMM :LOR: SHARED_C_LIBRARY)
_ll_mulss_SupportARMM
        ; Have SMULL instruction
        MOV     ip, a1
        SMULL   a1, a2, ip, a2
        Return  ,, LinkNotStacked
      ]


      [ RuntimeArch :LOR: :LNOT: HaveCLZ
        ; Emulate CLZ instruction for architectures that lack it
        ; Pinched from AsmUtils
soft_clz        ROUT
        ORRS    a4, a1, a1, LSR #1
        MOVEQ   a1, #32
        ORRNE   a1, a4, a4, LSR #2
        Return  ,, LinkNotStacked, EQ
        ORR     a1, a1, a1, LSR #4
        LDR     a2, =&06C9C57D
        ORR     a1, a1, a1, LSR #8
        ADR     a3, clz_table
        ORR     a1, a1, a1, LSR #16
        MLAS    a1, a2, a1, a2
        LDRNEB  a1, [a3, a1, LSR #27]
        Return  ,, LinkNotStacked
clz_table
        = 32, 31, 14, 30, 22, 13, 29, 19,  2, 21, 12, 10, 25, 28, 18,  8
        =  1, 15, 23, 20,  3, 11, 26,  9, 16, 24,  4, 27, 17,  5,  6,  7
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

        ; Divide a uint64_t by another, returning both quotient and remainder
        ; In:  divisor (a1,a2), dividend (a3,a4)
        ; Out: quotient (a1,a2), remainder (a3,a4)
_ll_urdv        ROUT
        FunctionEntry , "a1-v6,sl,fp"
        Pop     "v5,v6"
        Pop     "v3,v4"
        B       _ll_udiv_lateentry

        ; Divide a uint64_t by 10, returning both quotient and remainder
        ; In:  (a1,a2)
        ; Out: quotient (a1,a2), remainder (a3,a4)
_ll_udiv10      ROUT
      [ NoARMM
_ll_udiv10_NoARMM
        Push    "a1"
        ; No UMULL instruction
        ; Multiply by 0.6 (= &0.999 recurring)
        ; and subtract multiplication by 0.5 (LSR #1).
        ; Ignore fractional parts for now.
        Push    "v1,lr"
        LDR     lr, =&9999
        MOV     ip, a2, LSR #16     ; MS halfword
        SUB     v1, a2, ip, LSL #16
        MOV     a4, a1, LSR #16
        SUB     a3, a1, a4, LSL #16 ; LS halfword
        MUL     a3, lr, a3          ; multiply through by &9999
        MUL     a4, lr, a4
        MUL     v1, lr, v1
        MUL     ip, lr, ip
        MOVS    a2, a2, LSR #1      ; find half the dividend
        MOVS    a1, a1, RRX
        ADCS    a1, a1, #0          ; round upwards
        ADC     a2, a2, #0
        ADD     a4, a4, a4, LSR #16 ; can't unsigned overflow
        ADD     a4, a4, a3, LSR #16 ; can't unsigned overflow
        SUBS    a1, a4, a1
        SBC     a2, ip, a2
        ADDS    a1, a1, v1
        ADC     a2, a2, #0
        ADDS    a1, a1, v1, ROR #16
        ADC     a2, a2, v1, LSR #16
        ADDS    a1, a1, ip
        ADC     a2, a2, #0
        ADDS    a1, a1, ip, ROR #16
        ADC     a2, a2, ip, LSR #16
        ; It can be shown mathematically that this is an underestimate
        ; of the true quotient by up to 4.5. Compensate by detecting
        ; over-large remainders.
        Pop     "v1,lr"
       [ SupportARMM :LAND: (:LNOT: NoARMM :LOR: SHARED_C_LIBRARY)
        B       %FT40
       ]
      ]
      [ SupportARMM :LAND: (:LNOT: NoARMM :LOR: SHARED_C_LIBRARY)
_ll_udiv10_SupportARMM
        Push    "a1"
        ; Have UMULL instruction
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
      ]
        ; It can be shown mathematically that this is an underestimate
        ; of the true quotient by up to 2.5. Compensate by detecting
        ; over-large remainders.
40      MOV     ip, #10
        MUL     a3, a1, ip ; quotient * 10 (MSW is unimportant)
        Pop     "a4"
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
        Return  ,, LinkNotStacked

        ; Divide an int64_t by another, returning both quotient and remainder
        ; In:  dividend (a1,a2), divisor (a3,a4)
        ; Out: quotient (a1,a2), remainder (a3,a4)
        ; Remainder has same sign as dividend - required by C99, although
        ; earlier versions of C allowed the sign to match the divisor
_ll_sdiv        ROUT
        FunctionEntry , "v1"
        MOVS    v1, a4, LSR #31
        BEQ     %FT10
        ; Find absolute divisor
        RSBS    a3, a3, #0
        RSC     a4, a4, #0
10      EORS    v1, v1, a2, ASR #31
        BPL     %FT20
        ; Find absolute dividend
        RSBS    a1, a1, #0
        RSC     a2, a2, #0
20      BL      _ll_udiv
        TEQ     v1, #0
        BPL     %FT30
        ; Remainder is negative (sign(dividend) == -1)
        RSBS    a3, a3, #0
        RSC     a4, a4, #0
30      TST     v1, #1
        BEQ     %FT40
        ; Quotient is negative (sign(divisor) != sign(dividend))
        RSBS    a1, a1, #0
        RSC     a2, a2, #0
40
        Return  , "v1"

        ; Divide an int64_t by another, returning both quotient and remainder
        ; In:  divisor (a1,a2), dividend (a3,a4)
        ; Out: quotient (a1,a2), remainder (a3,a4)
        ; Remainder has same sign as dividend - required by C99, although
        ; earlier versions of C allowed the sign to match the divisor
_ll_srdv        ROUT
        FunctionEntry , "v1"
        MOVS    v1, a2, LSR #31
        BEQ     %FT10
        ; Find absolute divisor
        RSBS    a1, a1, #0
        RSC     a2, a2, #0
10      EORS    v1, v1, a4, ASR #31
        BPL     %FT20
        ; Find absolute dividend
        RSBS    a3, a3, #0
        RSC     a4, a4, #0
20      BL      _ll_urdv
        TEQ     v1, #0
        BPL     %FT30
        ; Remainder is negative (sign(dividend) == -1)
        RSBS    a3, a3, #0
        RSC     a4, a4, #0
30      TST     v1, #1
        BEQ     %FT40
        ; Quotient is negative (sign(divisor) != sign(dividend))
        RSBS    a1, a1, #0
        RSC     a2, a2, #0
40
        Return  , "v1"

        ; Divide an int64_t by 10, returning both quotient and remainder
        ; Remainder has same sign as dividend - required by C99, although
        ; earlier versions of C allowed the sign to match the divisor
        ; In:  (a1,a2)
        ; Out: quotient (a1,a2), remainder (a3,a4)
_ll_sdiv10      ROUT
        FunctionEntry , "v1"
        MOVS    v1, a2
        BPL     %FT10
        RSBS    a1, a1, #0 ; find abs(divisor)
        RSC     a2, a2, #0
10      BL      _ll_udiv10
        TEQ     v1, #0
        Return  , "v1",, PL
        RSBS    a1, a1, #0
        RSC     a2, a2, #0
        RSBS    a3, a3, #0
        RSC     a4, a4, #0
        Return  , "v1"

        ; Find the bitwise NOT of a 64-bit number
        ; In:  (a1,a2)
        ; Out: (a1,a2)
_ll_not         ROUT
        MVN     a1, a1
        MVN     a2, a2
        Return  ,, LinkNotStacked

        ; Find the negative of a 64-bit number
        ; In:  (a1,a2)
        ; Out: (a1,a2)
_ll_neg         ROUT
        RSBS    a1, a1, #0
        RSC     a2, a2, #0
        Return  ,, LinkNotStacked

        ; Find the bitwise AND of two 64-bit numbers
        ; In:  (a1,a2)
        ; Out: (a1,a2)
_ll_and         ROUT
        AND     a1, a1, a3
        AND     a2, a2, a4
        Return  ,, LinkNotStacked

        ; Find the bitwise OR of two 64-bit numbers
        ; In:  (a1,a2)
        ; Out: (a1,a2)
_ll_or          ROUT
        ORR     a1, a1, a3
        ORR     a2, a2, a4
        Return  ,, LinkNotStacked

        ; Find the bitwise exclusive OR of two 64-bit numbers
        ; In:  (a1,a2)
        ; Out: (a1,a2)
_ll_eor         ROUT
        EOR     a1, a1, a3
        EOR     a2, a2, a4
        Return  ,, LinkNotStacked

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

        ; Arithmetic-shift a 64-bit number right
        ; In:  (a1,a2),a3
        ; Out: (a1,a2)
_ll_sshift_r    ROUT
        RSBS    ip, a3, #32
        MOVHI   a1, a1, LSR a3
        ORRHI   a1, a1, a2, LSL ip
        MOVHI   a2, a2, ASR a3
        Return  ,, LinkNotStacked, HI
        SUB     ip, a3, #32
        MOV     a1, a2, ASR ip
        MOV     a2, a1, ASR #31
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

        ; Compare two int64_t numbers for testing GE or LT
        ; In:  (a1,a2),(a3,a4)
        ; Out: N == V if signed greater than or equal, N != V if signed less than
        ;      a1, a2 corrupted
_ll_cmpge       ROUT
        SUBS    a1, a1, a3
        SBCS    a2, a2, a4
        MOV     pc, lr ; irrespective of calling standard

        ; Compare two int64_t numbers for testing LE or GT
        ; In:  (a1,a2),(a3,a4)
        ; Out: N == V if signed less than or equal, N != V if signed greater than
        ;      (ie subsequent instructions need to use GE/LT condition instead of LE/GT)
        ;      a1, a2 corrupted
_ll_cmple       ROUT
        SUBS    a1, a3, a1
        SBCS    a2, a4, a2
        MOV     pc, lr ; irrespective of calling standard

        RoutineVariant _ll_mul, ARMM, UMULL_UMLAL
        RoutineVariant _ll_mullu, ARMM, UMULL_UMLAL
        RoutineVariant _ll_muluu, ARMM, UMULL_UMLAL
        RoutineVariant _ll_mulss, ARMM, SMULL_SMLAL
        RoutineVariant _ll_udiv10, ARMM, UMULL_UMLAL

; Now the floating point functions...

        EXPORT  _ll_uto_d
        EXPORT  _ll_sto_d
        EXPORT  _ll_uto_f
        EXPORT  _ll_sto_f
        EXPORT  _ll_ufrom_d
        EXPORT  _ll_sfrom_d
        EXPORT  _ll_ufrom_f
        EXPORT  _ll_sfrom_f
        EXPORT  llrint
        EXPORT  llrintf
        EXPORT  llround
        EXPORT  llroundf

; bit  31      rounding direction
; bits 30..26  exceptions (30=INX,29=UFL,28=OFL,27=DVZ,26=IVO)
; bit  24      flush to zero
; bits 23..22  rounding mode
; bit  18      "round" version of to-nearest (halfway case round away from zero)
; bit  17      rounded convert (as opposed to towards zero)
; bit  16      attempt to convert NaN
; bits 9..7    in type
; bits 6..4    out type
; bits 3..0    function

FE_EX_RDIR      *       &80000000
FE_EX_EXCEPT_MASK *     &7C000000
FE_EX_INEXACT   *       &40000000
FE_EX_UNDERFLOW *       &20000000
FE_EX_OVERFLOW  *       &10000000
FE_EX_DIVBYZERO *       &08000000
FE_EX_INVALID   *       &04000000
FE_EX_FLUSHZERO *       &01000000
FE_EX_ROUND_MASK *      &00C00000
FE_EX_CVT_RND   *       &00040000
FE_EX_CVT_R     *       &00020000
FE_EX_CVT_NAN   *       &00010000
FE_EX_INTYPE_MASK *     &00000380
FE_EX_OUTTYPE_MASK *    &00000070
FE_EX_TYPE_MASK *       &00000070
FE_EX_FN_MASK   *       &0000000F

FE_EX_ROUND_NEAREST *   &00000000
FE_EX_ROUND_PLUSINF *   &00400000
FE_EX_ROUND_MINUSINF *  &00800000
FE_EX_ROUND_ZERO *      &00C00000

FE_EX_BASETYPE_FLOAT *  0
FE_EX_BASETYPE_DOUBLE * 1
FE_EX_BASETYPE_UNSIGNED * 2
FE_EX_BASETYPE_INT *    4
FE_EX_BASETYPE_LONGLONG * FE_EX_BASETYPE_INT+FE_EX_BASETYPE_DOUBLE
FE_EX_BASETYPE_UINT *   FE_EX_BASETYPE_INT+FE_EX_BASETYPE_UNSIGNED
FE_EX_BASETYPE_ULONGLONG * FE_EX_BASETYPE_LONGLONG+FE_EX_BASETYPE_UNSIGNED

FE_EX_TYPE_FLOAT *      FE_EX_BASETYPE_FLOAT :SHL: 4
FE_EX_TYPE_DOUBLE *     FE_EX_BASETYPE_DOUBLE :SHL: 4
FE_EX_TYPE_INT  *       FE_EX_BASETYPE_INT :SHL: 4
FE_EX_TYPE_LONGLONG *   FE_EX_BASETYPE_LONGLONG :SHL: 4
FE_EX_TYPE_UINT *       FE_EX_BASETYPE_UINT :SHL: 4
FE_EX_TYPE_ULONGLONG *  FE_EX_BASETYPE_ULONGLONG :SHL: 4

FE_EX_INTYPE_FLOAT *    FE_EX_BASETYPE_FLOAT :SHL: 7
FE_EX_INTYPE_DOUBLE *   FE_EX_BASETYPE_DOUBLE :SHL: 7
FE_EX_INTYPE_INT  *     FE_EX_BASETYPE_INT :SHL: 7
FE_EX_INTYPE_LONGLONG * FE_EX_BASETYPE_LONGLONG :SHL: 7
FE_EX_INTYPE_UINT *     FE_EX_BASETYPE_UINT :SHL: 7
FE_EX_INTYPE_ULONGLONG * FE_EX_BASETYPE_ULONGLONG :SHL: 7

FE_EX_OUTTYPE_FLOAT *    FE_EX_BASETYPE_FLOAT :SHL: 4
FE_EX_OUTTYPE_DOUBLE *   FE_EX_BASETYPE_DOUBLE :SHL: 4
FE_EX_OUTTYPE_UNSIGNED * FE_EX_BASETYPE_UNSIGNED :SHL: 4
FE_EX_OUTTYPE_INT  *     FE_EX_BASETYPE_INT :SHL: 4
FE_EX_OUTTYPE_LONGLONG * FE_EX_BASETYPE_LONGLONG :SHL: 4
FE_EX_OUTTYPE_UINT *     FE_EX_BASETYPE_UINT :SHL: 4
FE_EX_OUTTYPE_ULONGLONG * FE_EX_BASETYPE_ULONGLONG :SHL: 4

FE_EX_FN_ADD    *       1
FE_EX_FN_SUB    *       2
FE_EX_FN_MUL    *       3
FE_EX_FN_DIV    *       4
FE_EX_FN_REM    *       5
FE_EX_FN_RND    *       6
FE_EX_FN_SQRT   *       7
FE_EX_FN_CVT    *       8
FE_EX_FN_CMP    *       9
FE_EX_FN_RAISE  *       15

_ll_uto_d       ROUT
        MOV     a3,#&42000000
        B       dfltll_normalise
_ll_sto_d       ROUT
        ANDS    a3,a2,#&80000000
        BPL     %FT10
        RSBS    a1,a1,#0
        RSC     a2,a2,#0
10      ORR     a3,a3,#&42000000
dfltll_normalise ROUT
        SUB     a3,a3,#&00300000
        MOVS    a4,a2
        MOVNE   a4,#32
        MOVEQS  a2,a1
        Return  ,,LinkNotStacked,EQ
 [ HaveCLZ
        CLZ     ip,a2
        MOV     a2,a2,LSL ip
        SUB     a4,a4,ip
 |
        MOVS    ip,a2,LSR #16
        SUBEQ   a4,a4,#16
        MOVEQS  a2,a2,LSL #16
        TST     a2,#&FF000000
        SUBEQ   a4,a4,#8
        MOVEQ   a2,a2,LSL #8
        TST     a2,#&F0000000
        SUBEQ   a4,a4,#4
        MOVEQ   a2,a2,LSL #4
        TST     a2,#&C0000000
        SUBEQ   a4,a4,#2
        MOVEQS  a2,a2,LSL #2
        MOVPL   a2,a2,LSL #1
        SUBPL   a4,a4,#1
 ]
        ADD     a3,a3,a4,LSL #20
        ORR     ip,a2,a1,LSR a4
        RSB     a4,a4,#32
        MOV     a4,a1,LSL a4
        MOVS    a2,a4,LSL #21
        MOVNE   a2,#FE_EX_INEXACT
        STMDB   sp!,{a2,lr}
        MOVS    a2,a4,LSL #22
        ANDEQ   a2,a4,a4,LSR #1
        MOVEQS  a2,a2,LSR #11
        MOV     a2,a4,LSR #11
        ADCS    a2,a2,ip,LSL #21
        ADC     a1,a3,ip,LSR #11
        MOVS    a4,a4,LSL #22
        LDMIA   sp!,{ip,lr}
        TST     ip,#FE_EX_INEXACT
        BNE     __fpl_exception
        Return  ,,LinkNotStacked

_ll_uto_f       ROUT
        MOV     a3,#&3F800000
        B       fltll_normalise
_ll_sto_f       ROUT
        ANDS    a3,a2,#&80000000
        BPL     %FT10
        RSBS    a1,a1,#0
        RSC     a2,a2,#0
10      ORR     a3,a3,#&3F800000
fltll_normalise ROUT
        ADD     a3,a3,#&0F000000
        MOVS    a4,a2
        MOVNE   a4,#32
        MOVEQS  a2,a1
        Return  ,,LinkNotStacked,EQ
 [ HaveCLZ
        CLZ     ip,a2
        MOV     a2,a2,LSL ip
        SUB     a4,a4,ip
 |
        MOVS    ip,a2,LSR #16
        SUBEQ   a4,a4,#16
        MOVEQS  a2,a2,LSL #16
        TST     a2,#&FF000000
        SUBEQ   a4,a4,#8
        MOVEQ   a2,a2,LSL #8
        TST     a2,#&F0000000
        SUBEQ   a4,a4,#4
        MOVEQ   a2,a2,LSL #4
        TST     a2,#&C0000000
        SUBEQ   a4,a4,#2
        MOVEQS  a2,a2,LSL #2
        MOVPL   a2,a2,LSL #1
        SUBPL   a4,a4,#1
 ]
        ORR     a2,a2,a1,LSR a4
        ADD     a3,a3,a4,LSL #23
        RSB     a4,a4,#32
        MOVS    ip,a1,LSL a4
        ORRS    ip,ip,a2,LSL #25
        ADC     a1,a3,a2,LSR #8
        ADC     ip,pc,#0
        ORRNES  ip,ip,#4,2
        BICCS   a1,a1,#1
        MOVS    ip,ip,LSL #30
        BNE     __fpl_exception
        Return  ,,LinkNotStacked

_ll_ufrom_d     ROUT
        MOVS    a3,a1,ASR #20
        MOV     a4,a1,LSL #11
        ORR     a4,a4,a2,LSR #21
        MOV     ip,a2,LSL #11
        ORRNE   a4,a4,#&80000000
        BMI     ll_ufrom_d_neg
        SUB     a3,a3,#&4E
        RSBS    a3,a3,#&03F0
        BLT     ll_ufrom_d_ivo
        CMP     a3,#&50
        MOVGE   a3,#&50
        MOV     a2,a4,LSR a3
        MOV     a1,ip,LSR a3
        RSBS    a3,a3,#32
        ORRHI   a1,a1,a4,LSL a3
        RSB     a3,a3,#0
        ORRLS   a1,a1,a4,LSR a3
        RSBS    a3,a3,#0
        MOVGE   ip,ip,LSL a3
        MOVLT   ip,ip,LSR #1
        ADDS    a3,a3,#32
        ORRGE   ip,ip,a4,LSL a3
        MOVGE   a4,#0
        CMP     a4,#1
        ORRCS   ip,ip,#1
        TST     ip,ip
        Return  ,,LinkNotStacked,EQ
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_ULONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INEXACT
        B       __fpl_exception
ll_ufrom_d_neg  ROUT
        ADD     a3,a1,#&40000000
        CMN     a3,#&00100000
        BGE     ll_ufrom_d_ivo
        ORRS    a3,a2,a1,LSL #1
        MOV     a1,#0
        MOV     a2,#0
        LDRNE   ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_ULONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INEXACT
        BNE     __fpl_exception
        Return  ,,LinkNotStacked
ll_ufrom_d_ivo  ROUT
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_ULONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INVALID
        MOV     a4,a1,LSL #1
        CMP     a4,#&FFE00000
        CMPEQ   a2,#0
        ORRHI   ip,ip,#FE_EX_CVT_NAN
        B       __fpl_exception
        LTORG


        MACRO
$func   DblRound $round

$func
        MOVS    a3,a1,ASR #20           ; a3 = exponent, and 21 sign bits
        MOV     a4,a1,LSL #11
        ORR     a4,a4,a2,LSR #21
        MOV     ip,a2,LSL #11           ; ip = low mantissa
        ORRNE   a4,a4,#&80000000        ; a4 = high mantissa, unit bit forced on if neg
        BMI     $func._neg
        SUB     a3,a3,#&4E
        RSBS    a3,a3,#&03F0            ; a3 = &43E-exp = shift to get b.p. at bottom
        BLE     $func._ivo              ; (must shift right, to get bit 63 clear)
        CMP     a3,#80                  ; clamp to a shift by 80
        MOVGE   a3,#80
        MOV     a2,a4,LSR a3            ; a2 & a1 = shifted
        MOV     a1,ip,LSR a3
        RSBS    a3,a3,#32
        ORRHI   a1,a1,a4,LSL a3
        RSB     a3,a3,#0
        ORRLS   a1,a1,a4,LSR a3
        RSBS    a3,a3,#0
        MOVGE   ip,ip,LSL a3
        MOVLT   ip,ip,LSR #1
        ADDS    a3,a3,#32
        ORRGE   ip,ip,a4,LSL a3
        MOVGE   a4,#0
        CMP     a4,#1
        ORRCS   ip,ip,#1
        TST     ip,ip
        Return  ,,LinkNotStacked,EQ
 [ "$round" = "rint"
        TEQ     ip,#&80000000
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INEXACT+FE_EX_CVT_R
        MVNEQS  a4,a1,LSL #31
        BMI     __fpl_exception
        ADDS    a1,a1,#1                ; Can't overflow, as any argument >= 2^52
        ADCS    a2,a2,#0                ; is an integer, so won't get here
        B       __fpl_exception
 ]
 [ "$round" = "round"
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INEXACT+FE_EX_CVT_RND
        BPL     __fpl_exception
        ADDS    a1,a1,#1
        ADCS    a2,a2,#0
        B       __fpl_exception
 ]
 [ "$round" = ""
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INEXACT
        B       __fpl_exception
 ]
$func._neg
        ADD     a3,a3,#&03F0
        CMN     a3,#&0410
        BICEQ   a4,a4,#&80000000        ; clear sign bit if exponent = 0
        RSBS    a3,a3,#&2E
        BLT     $func._ivo
        BEQ     $func._minint
$func._neg_noovf
        CMP     a3,#&50
        MOVGE   a3,#&50
        MOV     a2,a4,LSR a3
        MOV     a1,ip,LSR a3
        RSBS    a3,a3,#32
        ORRHI   a1,a1,a4,LSL a3
        RSB     a3,a3,#0
        ORRLS   a1,a1,a4,LSR a3
        RSBS    a1,a1,#0
        RSC     a2,a2,#0
        RSBS    a3,a3,#0
        MOVGE   ip,ip,LSL a3
        MOVLT   ip,ip,LSR #1
        ADDS    a3,a3,#32
        ORRGE   ip,ip,a4,LSL a3
        MOVGE   a4,#0
        CMP     a4,#1
        ORRCS   ip,ip,#1
        TST     ip,ip
        Return  ,,LinkNotStacked,EQ
 [ "$round" = "rint"
        TEQ     ip,#&80000000
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INEXACT+FE_EX_CVT_R
        MVNEQS  a4,a1,LSL #31
        BMI     __fpl_exception
        SUBS    a1,a1,#1
        SBC     a2,a2,#0
        B       __fpl_exception
 ]
 [ "$round" = "round"
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INEXACT+FE_EX_CVT_RND
        BPL     __fpl_exception
        SUBS    a1,a1,#1
        SBCS    a2,a2,#0
        B       __fpl_exception
 ]
 [ "$round" = ""
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INEXACT
        B       __fpl_exception
 ]
$func._minint
        TEQ     ip,#0
        TEQEQ   a4,#&80000000
        BEQ     $func._neg_noovf
$func._ivo
 [ "$round" = "rint"
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INVALID+FE_EX_CVT_R
 |
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_DOUBLE+FE_EX_INVALID
 ]
        MOV     a4,a1,LSL #1
        CMP     a4,#&FFE00000
        CMPEQ   a2,#0
        ORRHI   ip,ip,#FE_EX_CVT_NAN
        B       __fpl_exception
        MEND

_ll_sfrom_d     DblRound
llrint          DblRound  rint
llround         DblRound  round
        LTORG

_ll_ufrom_f     ROUT
        MOVS    a3,a1,ASR #23
        MOV     a4,a1,LSL #8
        ORRNE   a4,a4,#&80000000
        BMI     ll_ufrom_f_negative
        RSBS    a3,a3,#&BE
        BCC     ll_ufrom_f_ivo
        MOV     a2,a4,LSR a3
        SUBS    ip,a3,#32
        MOVCS   a1,a4,LSR ip
        RSBCC   ip,a3,#32
        MOVCC   a1,a4,LSL ip
        Return  ,,LinkNotStacked,CC
        RSBS    a3,a3,#&40
        MOVPL   a4,a4,LSL a3
        MOVMI   a4,a4,LSR #1
        TST     a4,a4
        Return  ,,LinkNotStacked,EQ
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_ULONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INEXACT
        B       __fpl_exception
ll_ufrom_f_negative ROUT
        MOV     ip,a1,LSL #1
        CMP     ip,#&7F000000
        BCS     ll_ufrom_f_ivo
        MOV     a1,#0
        MOV     a2,#0
        CMP     ip,#0
        LDRNE   ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_ULONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INEXACT
        BNE     __fpl_exception
        Return  ,,LinkNotStacked
ll_ufrom_f_ivo  ROUT
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_ULONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INVALID
        MOV     a4,a1,LSL #1
        CMP     a4,#&FF000000
        ORRHI   ip,ip,#FE_EX_CVT_NAN
        B       __fpl_exception
        LTORG

        MACRO
$func   FltRound $round

$func
        MOVS    a3,a1,ASR #23
        MOV     a4,a1,LSL #8
        ORRNE   a4,a4,#&80000000
        BMI     $func.negative
        RSBS    a3,a3,#&BE
        BLS     $func.ivo
        MOV     a2,a4,LSR a3
        SUBS    ip,a3,#32
        MOVCS   a1,a4,LSR ip
        RSBCC   ip,a3,#32
        MOVCC   a1,a4,LSL ip
        Return  ,,LinkNotStacked,CC
        RSBS    a3,a3,#64
        MOVPL   a4,a4,LSL a3
        MOVMI   a4,a4,LSR #1
        TST     a4,a4
        Return  ,,LinkNotStacked,EQ
 [ "$round" = "rint"
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INEXACT+FE_EX_CVT_R
        TEQ     a4,#&80000000
        MVNEQS  a4,a1,LSL #31
        ADDPL   a1,a1,#1                ; Can't overflow, as any argument >= 2^23
                                        ; is an integer, so won't get here
 ]
 [ "$round" = "round"
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INEXACT+FE_EX_CVT_RND
        ADDMI   a1,a1,#1
 ]
 [ "$round" = ""
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INEXACT
 ]
        B       __fpl_exception
$func.negative
        CMP     a1,#&DF000000
        BHI     $func.ivo
        ANDS    a3,a3,#&FF
        BICEQ   a4,a4,#&80000000
        RSB     a3,a3,#&BE
        MOV     a2,a4,LSR a3
        SUBS    ip,a3,#32
        MOVCS   a1,a4,LSR ip
        RSBCC   ip,a3,#32
        MOVCC   a1,a4,LSL ip
        RSBS    a1,a1,#0
        RSC     a2,a2,#0
        RSBS    a3,a3,#&40
        MOVPL   a4,a4,LSL a3
        MOVMI   a4,a4,LSR #1
        TST     a4,a4
        Return  ,,LinkNotStacked,EQ
 [ "$round" = "rint"
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INEXACT+FE_EX_CVT_R
        TEQ     a4,#&80000000
        MVNEQS  a4,a1,LSL #31
        SUBPL   a1,a1,#1                ; Can't overflow, as any argument >= 2^23
                                        ; is an integer, so won't get here
 ]
 [ "$round" = "round"
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INEXACT+FE_EX_CVT_RND
        SUBMI   a1,a1,#1
 ]
 [ "$round" = ""
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INEXACT
 ]
        B       __fpl_exception
$func.ivo
 [ "$round" = "rint"
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INVALID+FE_EX_CVT_R
 |
        LDR     ip,=FE_EX_FN_CVT+FE_EX_OUTTYPE_LONGLONG+FE_EX_INTYPE_FLOAT+FE_EX_INVALID
 ]
        MOV     a4,a1,LSL #1
        CMP     a4,#&FF000000
        ORRHI   ip,ip,#FE_EX_CVT_NAN
        B       __fpl_exception
        MEND

_ll_sfrom_f     FltRound

; Extra complication because of callee narrowing

llrintf         ROUT
        STMFD   sp!,{a1-a2}
        LDFD    f0,[sp],#8
        STFS    f0,[sp,#-4]!
        LDR     a1,[sp],#4
        ; fall through

_ll_sfrom_f_r   FltRound  rint

llroundf        ROUT
        STMFD   sp!,{a1-a2}
        LDFD    f0,[sp],#8
        STFS    f0,[sp,#-4]!
        LDR     a1,[sp],#4
        ; fall through

_ll_sfrom_f_rnd FltRound  round




; FP support code.

; __fpl_exception receives all exception-generating results. This includes
; all inexact results, so it is responsible for rounding.
;
; ip on entry tells it what to do, and consists of the FE_EX_xxx flags

__fpl_exception ROUT
        TST     ip,#FE_EX_OUTTYPE_DOUBLE
        MOVEQ   a3,a2
        STMDB   sp!,{a1-a4}
        RFS     a2
        BIC     a4,ip,a2,LSL #10       ; BIC out enabled exceptions
        ANDS    a4,a4,#FE_EX_UNDERFLOW+FE_EX_OVERFLOW
        ORRNE   ip,ip,#FE_EX_INEXACT
        MOV     a4,ip,LSL #1
        MOV     a4,a4,LSR #27           ; move exceptions down to bottom
        ORR     a2,a2,a4                ; OR them into cumulative FPSR bits
        AND     a4,a2,#&100             ; extract ND bit
        ORR     ip,ip,a4,LSL #16        ; pop it in our word
        WFS     a2
        AND     a4,ip,#FE_EX_FN_MASK
        TEQ     a4,#FE_EX_FN_CVT
        ANDNE   a4,ip,#FE_EX_TYPE_MASK
        ORRNE   ip,ip,a4,LSL #3
        MOVEQ   a4,#FE_EX_CVT_R
        BICEQS  a4,a4,ip
        ORREQ   ip,ip,#FE_EX_ROUND_ZERO
        ; If we actually had trap handlers we should worry about
        ; FE_EX_CVT_RND here (eg have FE_EX_ROUND_NEAREST)
        TST     ip,#FE_EX_UNDERFLOW
        BNE     underflow
        TST     ip,#FE_EX_OVERFLOW
        BNE     overflow
        TST     ip,#FE_EX_INEXACT
        BNE     inexact
        TST     ip,#FE_EX_DIVBYZERO
        BNE     divide_by_zero
; invalid
        TST     a2,#&00010000           ; IOE bit
        LDMIA   sp!,{a1-a4}
        BEQ     return_NaN
        B       _fp_trapveneer
overflow
        TST     a2,#&00040000           ; OFE bit
        LDMIA   sp!,{a1-a4}
        BEQ     ovf_return
        B       _fp_trapveneer
underflow
        TST     a2,#&00080000           ; UFE bit
        LDMIA   sp!,{a1-a4}
        BEQ     return_result
        B       _fp_trapveneer
divide_by_zero
        TST     a2,#&00020000           ; DZE bit
        LDMIA   sp!,{a1-a4}
        BNE     _fp_trapveneer
        EOR     a3,a1,a3
        B       return_Inf
inexact
        TST     a2,#&00100000           ; IXE bit
        LDMIA   sp!,{a1-a4}
        BEQ     return_result
        B       _fp_trapveneer
return_result
        TST     ip,#FE_EX_OUTTYPE_DOUBLE
        Return  ,,LinkNotStacked
ovf_return
        AND     a3,a1,#&80000000
return_Inf
        AND     a3,a3,#&80000000
        TST     ip,#FE_EX_OUTTYPE_DOUBLE
        ADRNE   a1,prototype_double_Inf
        LDMNEIA a1,{a1,a2}
        ORRNE   a1,a1,a3
        LDREQ   a1,prototype_single_Inf
        ORREQ   a1,a1,a3
        Return  ,,LinkNotStacked
return_NaN
        AND     a3,a1,#&80000000
        TST     ip,#FE_EX_OUTTYPE_DOUBLE
        ADRNE   a1,prototype_double_NaN
        LDMNEIA a1,{a1,a2}
        ORRNE   a1,a1,a3
        LDREQ   a1,prototype_single_NaN
        ORREQ   a1,a1,a3
        B       __fpl_return_NaN
prototype_double_Inf
        DCD     &7FF00000,&00000000
        DCD     &7FEFFFFF,&FFFFFFFF
prototype_single_Inf
        DCD     &7F800000
        DCD     &7F7FFFFF
prototype_double_NaN
        DCD     &7FF80000,&00000000
prototype_single_NaN
        DCD     &7FC00000

__fpl_return_NaN ROUT
        AND     a4,ip,#FE_EX_FN_MASK
;        CMP     a4,#FE_EX_FN_CMP
;        MOVEQ   a1,#8
;        BEQ     __fpl_cmpreturn
        CMP     a4,#FE_EX_FN_CVT
        ANDEQ   a4,ip,#FE_EX_OUTTYPE_INT
        TEQEQ   a4,#FE_EX_OUTTYPE_INT
        Return  ,,LinkNotStacked,NE
        TST     ip,#FE_EX_CVT_NAN
        BNE     return_zero
        TST     ip,#FE_EX_OUTTYPE_UNSIGNED
        BNE     return_umaxint
        TST     ip,#FE_EX_OUTTYPE_DOUBLE       ; long long?
        MOV     a3,a1
        MVNEQ   a1,#&80000000
        MVNNE   a2,#&80000000
        MVNNE   a1,#0
        TST     a3,#&80000000
        MVNNE   a1,a1
        MVNNE   a2,a2
        Return  ,,LinkNotStacked
return_zero
        MOV     a1,#0
        MOV     a2,#0
        Return  ,,LinkNotStacked
return_umaxint
        MVN     a1,#0
        MVN     a2,#0
        TST     a3,#&80000000
        MVNNE   a1,a1
        MVNNE   a2,a2
        Return  ,,LinkNotStacked


        IMPORT  feraiseexcept
_fp_trapveneer  ROUT
        ; This would be a bit backwards for some people, but it works for us...
        ; we know the relevant traps are enabled, so feraiseexcept won't
        ; return. Honest...
        MOV     a1,ip,LSR #26
        AND     a1,a1,#&1F
        B       feraiseexcept

        END
