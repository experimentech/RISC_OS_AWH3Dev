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
; File:    VFP.s
; Purpose: Disassembly of the Vector Floating Point instruction set
; Author:  K Bracey
; History: 13-Aug-00: KJB: created

VFP
        AddChar "F"

        CMP     r3, #&E
        BEQ     VFP_processing

; VFP Load and Store instructions
        ; arrive here with cccc 110x xxxx xxxx xxxx 101x xxxx xxxx
        ; format is        cccc 110p udwl nnnn dddd 101# iiii iiii
        ;
        ; <FLD|FST><S|D>{cond}            Fd,[Rn,#imm]
        ; <FLDM|FSTM><IA|DB><S|D|X>{cond} Rn{!},{reglist}
        ;
        ; where cccc = condition                     puw
        ;        puw = addressing mode               00x undefined
        ;          # = Double or Mixed/~Single       010 multiple, IA
        ;    dddd(d) = Fd                            011 multiple, IA !
        ;          l = Load/~Store                   1x0 single
        ;       nnnn = Rn                            101 multiple, DB !
        ;       iiii = 8-bit immediate offset        111 undefined

        AND     r14, r4, #2_1101:SHL:21         ; isolate PUW
        CMP     r14, #2_0001:SHL:21
        BLO     VFP_extension
        BEQ     VFP_undefined
        TEQ     r14, #2_1101:SHL:21
        BEQ     VFP_undefined

        TestStr 20,Ld,St

        AND     r10, r4, #2_1001:SHL:21
        TEQ     r10, #2_1000:SHL:21             ; P + ~W?
        BNE     VFP_LdStMultiple

        TestBit 8,"D","S"
        BL      Conditions

        BL      Tab
        BL      Dis_VFP_Fd

        B       CPDT_Common

Ld      = "LD", 0
St      = "ST", 0
Mia     = "MIA", 0
Mdb     = "MDB", 0
        ALIGN

VFP_LdStMultiple
        TestStr 23,Mia,Mdb                      ; increment/offset or decrement?
        TestBit 8,,"S"                          ; single, or
        BEQ     %FT20
        TestBit 0,"X","D"                       ; double/unspecified
20      BL      Conditions
        BL      TabOrPushOver                   ; can be 9 characters!
        MOV     r5, r4, LSR #16
        BL      Dis_Register
        TEQ     r5, #15
        BNE     %FT22
        TestBit 21
        MOVNE   r10, #Mistake_PCwriteback
        STRNE   r10, Mistake
22
        TestBit 21,"!"
        AddStr  CmBrc
        AND     r5, r4, #2_1111:SHL:12          ; start register
        MOV     r5, r5, LSR #11
        TestBit 22
        ORRNE   r5, r5, #1
        BL      Dis_VFP_Register
        AND     r14, r4, #2_11111111            ; offset (number of words to transfer)
        MOV     r1, r14
        TestBit 8
        BICNE   r14, r14, #1                    ; ignore extra word of X form
        SUB     r14, r14, #1
        BICNE   r14, r14, #1                    ; make it an inclusive end register offset
        MOVNE   r1, r1, LSR #1                  ; r1 = number of registers
        TEQ     r1, #0
        BEQ     VFP_unpredictable               ; must be > 0
        ADD     r5, r5, r14                     ; end register
        CMP     r5, #32                         ; don't run off end
        BHS     VFP_unpredictable
        TEQ     r1, #1                          ; if 1 register, that's it
        BEQ     %FT40
        TEQ     r1, #2                          ; comma for 2 registers
        MOVEQ   r10, #","
        MOVNE   r10, #"-"
        STRB    r10, [r0], #1
        BL      Dis_VFP_Register                ; print the final register
40
        AddChar "}"
        B       InstructionEnd

CmBrc   = ",{", 0
Mrrs    = "MRRS", 0
Msrr    = "MSRR", 0
Mrrd    = "MRRD", 0
Mdrr    = "MDRR", 0

        ALIGN

VFP_extension
        ; arrive here with cccc 1100 0x0x xxxx xxxx 101x xxxx xxxx
        ; format is        cccc 1100 010l nnnn dddd 101# 00m1 mmmm
        ;
        ; FMSRR{cond} Rd,Rn,{Sm,Sm+1}
        ; FMRRS{cond} Rd,Rn,{Sm,Sm+1}
        ; FMDRR{cond} Dm,Rd,Rn
        ; FMRRD{cond} Rd,Rn,Dm
        ;
        ; where cccc = condition
        ;          l = Load/~Store (ie load from coprocessor)
        ;          # = Double/~Single
        ;       nnnn = Rn
        ;       dddd = Rd
        ;    mmmm(m) = Fm

        TestBit 22
        BEQ     VFP_undefined
        AND     r14, r4, #2_1101:SHL:4
        TEQ     r14, #2_0001:SHL:4
        BNE     VFP_undefined
        TestBit 8
        BNE     VFP_double_dual_transfer

VFP_single_dual_transfer
        TestStr 20,Mrrs,Msrr,conds
        BL      Tab
        BL      Dis_RdRn
        AddStr  CmBrc
        BL      Dis_VFP_Fm
        ADD     r5, r5, #1
        BL      Comma_Dis_VFP_Register
        TST     r5, #31
        BEQ     VFP_undefined
        AddChar "}"
        B       InstructionEnd

VFP_double_dual_transfer
        TestStr 20,Mrrd,Mdrr,conds
        BL      Tab
        TestBit 20
        BNE     %FT10
        BL      Dis_VFP_Fm
        BL      AddComma
10      BL      Dis_RdRn
        TestBit 20
        BLNE    Comma_Dis_VFP_Fm
        B       InstructionEnd

VFP_processing
        ; arrive here with cccc 1110 xxxx xxxx xxxx 101x xxxx xxxx
        TestBit 4
        BNE     VFP_register_transfer

        ; arrive here with cccc 1110 xxxx xxxx xxxx 101x xxx0 xxxx
        ; format is        cccc 1110 pdqr nnnn dddd 101# nsm0 mmmm
        ;
        ; <Primary op><S|D>{cond} Fd,Fn,Fm
        ; ...
        ;
        ; where cccc = condition
        ;       pqrs = primary opcode
        ;          # = Double/~Single
        ;    nnnn(n) = Fn   (secondary opcode if pqrs = 1111)
        ;    dddd(d) = Fd
        ;    mmmm(m) = Fm

        MOV     r6, #0                  ; piece together the opcode
        TestBit 23
        ORRNE   r6, r6, #2_1000
        AND     r14, r4, #2_11:SHL:20
        ORR     r6, r6, r14, LSR #19
        TestBit 6
        ORRNE   r6, r6, #1
        TEQ     r6, #15
        BEQ     VFP_secondary_data_processing
        CMP     r6, #9
        BHS     VFP_undefined
        ADR     r10, VFP_dp_opc1_table
        ADD     r10, r10, r6, LSL #2
        ADD     r10, r10, r6
        BL      SaveString
        TestBit 8,"D","S"
        BL      Conditions
        BL      TabOrPushOver
        BL      Dis_VFP_Fd
        BL      Comma_Dis_VFP_Fn
        BL      Comma_Dis_VFP_Fm
        B       InstructionEnd

VFP_dp_opc1_table
        = "MAC",0,0
        = "NMAC",0
        = "MSC",0,0
        = "NMSC",0
        = "MUL",0,0
        = "NMUL",0
        = "ADD",0,0
        = "SUB",0,0
        = "DIV",0;,0

VFP_monadic_table
        = "CPY",0
        = "ABS",0
        = "NEG",0
        = "SQRT",0 ; Change entry size to 5 if SQRT not last entry
        ALIGN

VFP_secondary_data_processing
        ; arrive here with cccc 1110 1x11 xxxx xxxx 101x x1x0 xxxx
        ; format is        cccc 1110 1d11 nnnn dddd 101# n1m0 mmmm
        ;
        ; <Secondary op><S|D>{cond} Fd,Fm
        ; ...
        ;
        ; where cccc = condition
        ;          # = Double/~Single
        ;    nnnn(n) = secondary opcode
        ;    dddd(d) = Fd
        ;    mmmm(m) = Fm

        AND     r6, r4, #2_1111:SHL:16
        MOV     r6, r6, LSR #15
        TestBit 7
        ORRNE   r6, r6, #1                      ; r6 = opcode

        CMP     r6, #2_00011                    ; 000xx = monadic
        BLS     VFP_monadic
        CMP     r6, #2_01000
        BLO     VFP_undefined
        CMP     r6, #2_01011                    ; 010xx = compare
        BLS     VFP_compare
        CMP     r6, #2_01111
        BLO     VFP_undefined
        BEQ     VFP_convert_precision           ; 01111 = convert S<->D
        CMP     r6, #2_10001
        BLS     VFP_convert_to_fp               ; 1000x = convert to FP
        CMP     r6, #2_11000
        BLO     VFP_undefined
        CMP     r6, #2_11011
        BLS     VFP_convert_to_int              ; 110xx = convert to int
        B       VFP_undefined

VFP_monadic
        ; arrive here with cccc 1110 1x11 000x xxxx 101x x1x0 xxxx
        ; format is        cccc 1110 1d11 000n dddd 101# n1m0 mmmm
        ;
        ; <FCPY|FABS|FNEG|FSQRT><S|D>{cond} Fd,Fm
        ADR     r10, VFP_monadic_table
        ADD     r10, r10, r6, LSL #2
        BL      SaveString
        TestBit 8,"D","S"
        BL      Conditions
        BL      TabOrPushOver
        BL      Dis_VFP_Fd
        BL      Comma_Dis_VFP_Fm
        B       InstructionEnd

VFP_compare
        ; arrive here with cccc 1110 1x11 010x xxxx 101x x1x0 xxxx
        ; format is        cccc 1110 1d11 010z dddd 101# e1m0 mmmm
        ;
        ; FCMP{E}<S|D>{cond}  Fd,Fm
        ; FCMP{E}Z<S|D>{cond} Fd
        AddStr  Cmp
        TestBit 7,"E"
        TestBit 16,"Z"
        TestBit 8,"D","S"
        BL      Conditions
        BL      TabOrPushOver
        BL      Dis_VFP_Fd
        TestBit 16
        BNE     %FT20
        BL      Comma_Dis_VFP_Fm
        B       InstructionEnd
20
        TST     r4, #2_101111
        BEQ     InstructionEnd          ; I'm following the ARM ARM
        TestBit 5                       ; to the letter here - bit 5
        BNE     VFP_undefined           ; IS 0, bits 0-3 SHOULD BE
        B       VFP_unpredictable       ; zero

VFP_convert_precision
        ; arrive here with cccc 1110 1x11 0111 xxxx 101x 11x0 xxxx
        ; format is        cccc 1110 1d11 0111 dddd 101# 11m0 mmmm
        ;
        ; FCVTDS{cond} Dd,Sm
        ; FCVTSD{cond} Sd,Dm
        AddStr  Cvt
        TestBit 8
        MOVEQ   r10, #"D"
        MOVNE   r10, #"S"               ; First letter is inverse
        STRB    r10, [r0], #1           ; of precision
        EOR     r10, r10, #"D":EOR:"S"  ; Second is opposite
        STRB    r10, [r0], #1
        BL      Conditions
        BL      TabOrPushOver
        EOR     r4, r4, #1:SHL:8        ; Sneakily invert D/S
        BL      Dis_VFP_Fd
        EOR     r4, r4, #1:SHL:8        ; Put it back
        BL      Comma_Dis_VFP_Fm
        B       InstructionEnd

VFP_convert_to_fp
        ; arrive here with cccc 1110 1x11 1000 xxxx 101x x1x0 xxxx
        ; format is        cccc 1110 1d11 1000 dddd 101# s1m0 mmmm
        ;
        ; F<S|U>ITO<S|D>{cond} Fd,Sm
        TestStr 7,Sito,Uito
        TestBit 8,"D","S"
        BL      Conditions
        BL      TabOrPushOver
        BL      Dis_VFP_Fd
        BL      Comma_Dis_VFP_Sm
        B       InstructionEnd

VFP_convert_to_int
        ; arrive here with cccc 1110 1x11 110x xxxx 101x x1x0 xxxx
        ; format is        cccc 1110 1d11 110s dddd 101# z1m0 mmmm
        ;
        ; FTO<U|S>I{Z}<S|D>{cond} Sd,Fm
        AddStr  To
        TestBit 16,"S","U"
        AddChar "I"
        TestBit 7,"Z"
        TestBit 8,"D","S"
        BL      Conditions
        BL      TabOrPushOver
        BL      Dis_VFP_Sd
        BL      Comma_Dis_VFP_Fm
        B       InstructionEnd

Cmp    = "CMP",0
Cvt    = "CVT",0
Sito   = "SITO",0
Uito   = "UI" ;...
To     = "TO",0
        ALIGN

        ROUT
VFP_register_transfer
        ; arrive here with cccc 1110 xxxx xxxx xxxx 101x xxx1 xxxx
        ; format  is       cccc 1110 oool nnnn dddd 101# n001 0000
        TST     r4, #2_11:SHL:5
        BNE     VFP_undefined
        TST     r4, #2_1111
        BNE     VFP_unpredictable
        AND     r6, r4, #2_111:SHL:21
        TestBit 23
        BNE     VFP_system_register_transfer

        CMP     r6, #2_010:SHL:21
        BHS     VFP_undefined
        ; arrive here with cccc 1110 00xx xxxx xxxx 101x x001 0000
        ; format is        cccc 1110 00hl nnnn dddd 101# n001 0000
        ;
        ; FMSR{cond}      Sn,Rd
        ; FMRS{cond}      Rd,Sn
        ; FMD<L|H>R{cond} Dn,Rd
        ; FMRD<L|H>{cond} Rd,Dn

        AddChar "M"
        ADR     r10, VFPRT_table
        AND     r6, r4, #2_11:SHL:20
        TestBit 8
        ORRNE   r6, r6, #1:SHL:19               ; hl#
        LDRB    r14, [r10, r6, LSR #19-2]!
        TEQ     r14, #0
        BEQ     VFP_undefined
        BL      SaveStringConditions
        BL      Tab
        TestBit 20
        BNE     %FT20
        BL      Dis_VFP_Fn
        MOV     r5, r4, LSR #12
        BL      Comma_Dis_Register
        B       InstructionEnd
20      MOV     r5, r4, LSR #12
        BL      Dis_Register
        BL      Comma_Dis_VFP_Fn
        B       InstructionEnd

VFPRT_table
        = "SR",0,0
        = "DLR",0
        = "RS",0,0
        = "RDL",0
        = 0,0,0,0
        = "DHR",0
        = 0,0,0,0
        = "RDH",0
Mrx    = "MRX",0
Mxr    = "MXR",0
Fpsid   = "FPSID",0
Fpscr   = "FPSCR",0
Fpexc   = "FPEXC",0
Fmstat  = "FMSTAT",0
        ALIGN

        ROUT
VFP_system_register_transfer
        ; arrive here with cccc 1110 1xxx xxxx xxxx 101x x001 0000
        ; format is        cccc 1110 111l nnnn dddd 1010 n001 0000
        ;
        ; FMXR{cond} <FPSID|FPSCR|FPEXC>,Rd
        ; FMRX{cond} Rd,<FPSID|FPSCR|FPEXC>
        TEQ     r6, #2_111:SHL:21
        TSTEQ   r4, #1:SHL:8
        BNE     VFP_undefined
        TestStr 20,Mrx,Mxr,conds
        TestBit 20
        BNE     %FT20

        BL      Tab
        BL      Dis_VFP_Sys_Fn
        MOV     r5, r4, LSR #12
        BL      Comma_Dis_Register
        B       InstructionEnd

20      AND     r14, r4, #&FF:SHL:12    ; check for FMSTAT (FMRX PC,FPSCR)
        TEQ     r14, #&1F:SHL:12
        TSTEQ   r4, #1:SHL:7
        BNE     %FT25
        TST     r4, #1:SHL:20
        BEQ     %FT25
        ADR     r0, StringBuffer
        AddStr  Fmstat,,conds
        B       InstructionEnd

25      MOV     r5, r4, LSR #12
        BL      Tab_Dis_Register
        BL      AddComma
        BL      Dis_VFP_Sys_Fn
        B       InstructionEnd

Dis_VFP_Sys_Fn
        TestBit 7
        BNE     VFP_undefined
        AND     r5, r4, #2_1111:SHL:16
        MOV     r10, #0
        CMP     r5, #2_0001:SHL:16
        ADRLO   r10, Fpsid
        ADREQ   r10, Fpscr
        TEQ     r5, #2_1000:SHL:16
        ADREQ   r10, Fpexc
        TEQ     r10, #0
        BNE     SaveString
        B       VFP_undefined


Comma_Dis_VFP_Register
        AddChar ","
Dis_VFP_Register
        CLC
        AND     r8, r5, #2_11111
        TestBit 8,"D","S"
        MOVNES  r8, r8, LSR #1
        BCC     StoreDecimal
        B       VFP_undefined

Dis_VFP_Fd
        AND     r5, r4, #2_1111:SHL:12
        MOV     r5, r5, LSR #11
        TestBit 22
        ORRNE   r5, r5, #1
        B       Dis_VFP_Register

Comma_Dis_VFP_Fn
        AddChar ","
Dis_VFP_Fn
        AND     r5, r4, #2_1111:SHL:16
        MOV     r5, r5, LSR #15
        TestBit 7
        ORRNE   r5, r5, #1
        B       Dis_VFP_Register

Comma_Dis_VFP_Fm
        AddChar ","
Dis_VFP_Fm
        MOV     r5, r4, LSL #1
        TestBit 5
        ORRNE   r5, r5, #1
        B       Dis_VFP_Register

Dis_VFP_S_Register
        AddChar "S"
        AND     r8, r5, #2_11111
        B       StoreDecimal

Dis_VFP_Sd
        AND     r5, r4, #2_1111:SHL:12
        MOV     r5, r5, LSR #11
        TestBit 22
        ORRNE   r5, r5, #1
        B       Dis_VFP_S_Register

Comma_Dis_VFP_Sm
        AddChar ","
Dis_VFP_Sm
        MOV     r5, r4, LSL #1
        TestBit 5
        ORRNE   r5, r5, #1
        B       Dis_VFP_S_Register

VFP_unpredictable
VFP_undefined
        ADR     r0, StringBuffer
        B       Coprocessor_NotFP

        END
