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
; File:    ARMv6.s
; Purpose: Disassembly of ARMv6 (and those few ARMv7
;                                and those few ARMv8 AArch32) instructions
; Author:  K Bracey
; History: 23-Feb-00: KJB: created

LdrexStrex ROUT
        ; arrive here with cccc 0001 1xxx xxxx xxxx xxxx 1001 xxxx
        ; format is        cccc 0001 1wwl nnnn dddd 111r 1001 mmmm
        ;
        ; LD<R|A>EX<H|B>{cond} Rd,[Rn]
        ; ST<R|L>EX<H|B>{cond} Rd,Rm,[Rn]
        ; LD<R|A>EXD{cond} Rd,Rd+1,[Rn]
        ; ST<R|L>EXD{cond} Rd,Rm,Rm+1,[Rn]
        ;
        ; where cccc = condition
        ;          l = Load/~Store
        ;          r = Register/~Ordered
        ;         ww = 00 (word) 01 (dword) 10 (byte) 11 (halfword)
        ;       nnnn = Rn
        ;       dddd = Rd
        ;       mmmm = Rm (=1111 for LDREX)
        AND     r5, r4, #2_1111:SHL:8
        TEQ     r5, #2_1100:SHL:8
        BEQ     LdaStl
        TEQ     r5, #2_1111:SHL:8
        TEQNE   r5, #2_1110:SHL:8
        BNE     Undefined

        [ WarnARMv6
        MOV     r14, #Mistake_ARMv6
        ]
        [ WarnARMv6K
        TST     r4, #2_0110:SHL:20      ; <D|H|B>
        MOVNE   r14, #Mistake_ARMv6K
        ]
        [ WarnARMv6 :LOR: WarnARMv6K
        STR     r14, Mistake
        ]

        TestBit 8                       ; Register or ordered type
        BNE     %FT10

        [ WarnARMv8
        MOV     r14, #Mistake_ARMv8
        STR     r14, Mistake
        ]
        TestStr 20,Ldaex,Stlex
        B       %FT20
10
        TestStr 20,Ldrex,Strex
20
        ADR     r14, Exwidth
        ANDS    r7, r4, #2_0110:SHL:20
        LDRNEB  r14, [r14, r7, LSR #21]
        STRNEB  r14, [r0], #1           ; <D|H|B>
        BL      Conditions
        BL      TabOrPushOver

        MOV     r9,r4,LSR #16
        AND     r9,r9,#2_1111           ; Rn

        MOV     R5,R4,LSR #12
        AND     r5,r5,#2_1111           ; Rd

        AND     r6,r4,#2_1111           ; Rm

        ; Rd=Rn & STREX -> unpredictable
        TestBit 20
        TEQEQS  r5,r9
        MOVEQ   r14,#Mistake_RdRn
        STREQ   r14,Mistake

        ; Rd=Rm -> unpredictable
        TEQS    r6,r5
        MOVEQ   r14,#Mistake_RdRm
        STREQ   r14,Mistake

        ; any reg=R15 -> unpredictable
        TEQS    r5,#15
        TEQNES  r9,#15
        MOVEQ   r14,#Mistake_R15
        STREQ   r14,Mistake

        BL      Dis_Register
        TEQS    r7,#2_0010:SHL:20
        BNE     %FT30

        ; Double word special
        TestBit 20
        MOVEQ   r5, r6                  ; Rm
        ADDEQ   r6, r6, #1              ; Rm+1 for STREXD

        MOVS    r14, r5, LSR #1         ; Rd or Rm odd?
        MOVCC   r14, #Mistake_R15
        MOVCS   r14, #Mistake_BaseOdd
        CMPCC   r5, #14                 ; Rd or Rm imply target PC?
        STRCS   r14, Mistake

        TestBit 20
        ADDNE   r5, r5, #1              ; Rd+1 for LDREXD
        BL      Comma_Dis_Register
30
        TestBit 20
        MOVEQ   r5, r6
        BEQ     SwpCommon1
        ; Load case - Rm field must be 15
        TEQS    r6, #15
        BEQ     SwpCommon2
        B       Undefined

Exwidth DCB     "?", "D", "B", "H"
Ldrex   DCB     "LDREX", 0
Strex   DCB     "STREX", 0
Ldaex   DCB     "LDAEX", 0
Stlex   DCB     "STLEX", 0
        ALIGN

LdaStl ROUT
        ; arrive here with cccc 0001 1xxx xxxx xxxx 1100 1001 xxxx
        ; format is        cccc 0001 1wwl nnnn dddd 1100 1001 mmmm
        ;
        ; LDA{cond}<H|B> Rd,[Rn]
        ; STL{cond}<H|B> Rm,[Rn]
        ;
        ; where cccc = condition
        ;          l = Load/~Store
        ;         ww = 00 (word) 01 (dword) 10 (byte) 11 (halfword)
        ;       nnnn = Rn
        ;       dddd = Rd
        ;       mmmm = Rm (=1111 for LDA)
        TestBit 20
        ANDNE   r5, r4, #2_1111
        TEQNE   r5, #2_1111             ; Check mmmm for LDA
        BNE     Undefined

        ANDS    r8, r4, #2_11:SHL:21
        TEQ     r8, #2_01:SHL:21        ; Check for dword size (invalid)
        BEQ     Undefined

        [ WarnARMv8
        MOV     r14, #Mistake_ARMv8
        STR     r14, Mistake
        ]

        TestStr 20,LdaOp,StlOp,conds
        ADR     r14, Exwidth
        MOVS    r8, r8
        LDRNEB  r14, [r14, r8, LSR #21]
        STRNEB  r14, [r0], #1           ; <H|B>

        TestBit 20
        MOVNE   r5, r4, LSR #12
        MOVEQ   r5, r4
        BL      Tab_Dis_Register
        MOV     r9, r4, LSR #16         ; Rn

        AND     r9, r9, #2_1111
        TEQ     r9, #15
        TEQNE   r5, #15
        MOVEQ   r14, #Mistake_R15       ; Rn or Rd or Rm = PC
        STREQ   r14, Mistake
        B       SwpCommon2

LdaOp   DCB     "LDA", 0
StlOp   DCB     "STL", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Maintenance_uncond ROUT
        ; arrive here with 1111 0101 0111 1111 1111 0000 xxxx xxxx
        ; all but 4 of 16 are unpredictable
        AND     r5, r4, #2_1111:SHL:4
        TEQ     r5, #1:SHL:4
        BEQ     is_CLREX

        TEQ     r5, #4:SHL:4
        TEQNE   r5, #5:SHL:4
        TEQNE   r5, #6:SHL:4
        BEQ     is_DSB_DMB_ISB

        ADR     r10, UnpredArm          ; Specifically not undefined
        BL      lookup_r10
        BL      SaveString
        B       InstructionEnd

is_DSB_DMB_ISB
        ; arrive here with 1111 0101 0111 1111 1111 0000 01im tttt
        ;
        ; <DSB|DMB|ISB> type
        ;
        ; where tttt = type
        ;          i = I/~D
        ;          m = M/~S
        [ WarnARMv7
        MOV     r14, #Mistake_ARMv7
        STR     r14, Mistake
        ]
        TestBit 5,"I","D"
        TestBit 4,"M","S"
        AddChar "B"
        BL      Tab

        AND     r5, r4, #2_0011         ; 0=unpredictable, 1=LD, 2=ST, 3=all
        SUBS    r5, r5, #1
        [ WarnARMv8
        MOVEQ   r14, #Mistake_ARMv8     ; LD
        STREQ   r14, Mistake
        ]
        MOVMI   r6, #2_1111             ; Behave as SY, but unpredictable
        MOVMI   r14, #Mistake_Unpred
        STRMI   r14, Mistake

        AND     r6, r4, #2_1111
        TestBit 5                       ; ISB
        TEQNE   r6, #2_1111             ; Must be SY
        MOVNE   r14, #Mistake_Unpred    ; otherwise unpredictable
        STRNE   r14, Mistake

        ; Now fits a vague pattern
        TEQ     r6, #2_1110             ; If it's just ST don't do SY
        TEQNE   r6, #2_1101             ; If it's just LD don't do SY
        ANDNE   r14, r6, #2_1100        ; One of 4 in the table
        ADRNE   r10, Barrier
        ADDNE   r10, r10, r14
        BLNE    SaveString

        ; Append LD/ST
        CMP     r5, #1
        ADRCC   r10, Typeld
        ADREQ   r10, Typest
        BLLS    SaveString
        B       InstructionEnd
        
is_CLREX
        ; arrive here with 1111 0101 0111 1111 1111 0000 0001 xxxx
        ; format is        1111 0101 0111 1111 1111 0000 0001 1111
        ;
        ; CLREX
        MOV     r5, r4, LSL #28
        CMP     r5, #&F0000000
        BNE     Undefined

        AddStr  Clrex
        [ WarnARMv6K
        MOV     r14, #Mistake_ARMv6K
        STR     r14, Mistake
        ]
        BL      Tab
        B       InstructionEnd

UnpredArm
        DCB     "M65", 0
Clrex   DCB     "CLREX", 0
Typest  DCB     "ST", 0
Typeld  DCB     "LD", 0
Barrier DCB     "OSH", 0, "NSH", 0, "ISH", 0, "SY", 0
        ;        00        01        10       11
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Hints ROUT
        ; arrive here with cccc 0011 0010 0000 1111 xxxx xxxx xxxx
        ; format is        cccc 0011 0010 0000 1111 0000 hhhh hhhh
        ;
        ; where cccc = condition
        ;       hhhhhhhh = hint type
        ;
        ; unassigned hints behave as NOP but are reserved
        TSTS    r4, #2_1111:SHL:8
        BNE     Undefined
        [ WarnARMv6K
        MOV     r14, #Mistake_ARMv6K
        STR     r14, Mistake
        ]
        ANDS    r5, r4, #&FF            ; Isolate op2
        CMPS    r5, #2_11110000         ; DBG
        BCS     %FT10

        CMPS    r5, #5
        ADR     r10, NopH
        ADDLS   r14, r5, r5, LSL #1     ; x3
        ADDLS   r10, r10, r14, LSL #1   ; x6
        MOVHI   r14, #Mistake_Unpred    ; Behave as NOP but might change
        STRHI   r14, Mistake
        [ WarnARMv8
        MOVEQ   r14, #Mistake_ARMv8     ; SEVL
        STREQ   r14, Mistake
        ]
        BL      SaveStringConditions
        BL      Tab
        B       InstructionEnd
10
        [ WarnARMv7
        MOV     r14, #Mistake_ARMv7     ; DBG
        STR     r14, Mistake
        ]
        AddStr  DbgH,,conds
Tab_imm4
        BL      Tab
        AND     r8, r4, #2_1111
        B       Rem_Number
        
NopH    DCB     "NOP", 0, 0, 0
YieldH  DCB     "YIELD", 0
WfeH    DCB     "WFE", 0, 0, 0
WfiH    DCB     "WFI", 0, 0, 0
SevH    DCB     "SEV", 0, 0, 0
SevlH   DCB     "SEVL", 0, 0
DbgH    DCB     "DBG", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Move_imm16 ROUT
        ; arrive here with cccc 0011 0x00 xxxx xxxx xxxx xxxx xxxx
        ; format is        cccc 0011 0t00 iiii dddd iiii iiii iiii
        ;
        ; MOVT{cond} Rd,#imm16
        ; MOVW{cond} Rd,#imm16
        ;
        ; where cccc = condition
        ;       t = top/~bottom
        ;
        ; MOVT Rd[31:16] := imm16
        ; MOVW Rd[15:0] := imm16

        [ WarnARMv6T2
        MOV     r14, #Mistake_ARMv6T2
        STR     r14, Mistake
        ]
        TestStr 22,MovtTab,MovwTab,conds
        MOV     r5, r4, LSR #12
        BL      Tab_Dis_Register
        BL      AddCommaHash
        BIC     r8, r4, #2_1111:SHL:12
        MOV     r5, r4, LSR #16
        ORR     r8, r8, r5, LSL #12
        MOV     r2, #12
        BL      StoreHex
        B       InstructionEnd
        
MovtTab DCB     "MOVT", 0
MovwTab DCB     "MOVW", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

mul_sub ROUT
        ; arrive here with cccc 0000 0110 xxxx xxxx xxxx 1001 xxxx
        ; format is        cccc 0000 0100 dddd aaaa mmmm 1001 nnnn
        ;
        ; MLS{cond}  Rd, Rn, Rm, Ra
        ;
        ; where cccc = condition
        ;
        ; Rd := Rn - Ra*Rm

        [ WarnARMv6T2
        MOV     r14, #Mistake_ARMv6T2
        STR     r14, Mistake
        ]
        AddStr  MlsTab,,conds

        MOV     r5, r4, LSR #16         ; Rd
        BL      Tab_Dis_Register
        CMP     r5, #15

        MOV     r5, r4
        BL      Comma_Dis_Register      ; Rn
        CMPCC   r5, #15

        MOV     r5, r4, LSR #8          ; Rm
        BL      Comma_Dis_Register
        CMPCC   r5, #15

        MOV     r5, r4, LSR #12         ; Ra
        BL      Comma_Dis_Register
        CMPCC   r5, #15

        MOVCS   r14, #Mistake_R15
        STRCS   r14, Mistake
        B       InstructionEnd

MlsTab  DCB     "MLS", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

is_SMC ROUT
        ; arrive here with cccc 0001 0110 xxxx xxxx xxxx 0111 xxxx
        ; format is        cccc 0001 0110 0000 0000 0000 0111 iiii
        ;
        ; SMI{cond}  imm4
        ;
        ; where cccc = condition
        ;       iiii = number

        [ WarnARMv6K
        MOV     r14, #Mistake_ARMv6K    ; Optional in v6K
        STR     r14, Mistake
        ]
        TST     r4, #2_1111:SHL:8
        TSTEQ   r4, #2_11111111:SHL:12
        BNE     Undefined
        AddStr  SmiTab,,conds
        B       Tab_imm4

SmiTab  DCB     "SMI",0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

is_ERET ROUT
        ; arrive here with cccc 0001 0xx0 xxxx xxxx xxxx 0110 xxxx
        ; format is        cccc 0001 0110 0000 0000 0000 0110 1110
        ;
        ; ERET{cond}
        ;
        ; where cccc = condition

        [ WarnARMv7VE
        MOV     r14, #Mistake_ARMv7VE   ; Optional in v7VE
        STR     r14, Mistake
        ]
        LDR     r5, =2_0001011000000000000001101110:SHL:4
        TEQ     r5, r4, LSL #4
        BNE     Undefined
        AddStr  ERetTab,,conds
        BL      Tab
        B       InstructionEnd

ERetTab DCB     "ERET",0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Srs_Or_Rfe ROUT
        ; arrive here with 1111 100x xxxx xxxx xxxx xxxx xxxx xxxx
        ; format is        cccc 100p uqwq nnnn 0000 qqqq 000m mmmm
        ;
        ; RFE<I|D><A|B> Rn{!}
        ; SRS<I|D><A|B> SP{!},#mode
        ;
        ; where qqqq = qualifier (0-1-1010 = RFE, 1-0-0101 = SRS)
        ;          p = Pre-indexing/~Post-indexing
        ;          u = Up/~Down
        ;          w = Writeback
        ;      mmmmm = mode, or 0 for RFE
        ;       nnnn = Rn

        [ WarnARMv6
        MOV     r14, #Mistake_ARMv6
        STR     r14, Mistake
        ]
        LDR     r5,  =2_10100001111111111111111
        AND     r5, r4, r5
        LDR     r14, =2_00100000000101000000000 ; RFE
        TEQ     r5, r14
        BICNE   r5, r5, #2_000000000000011111 ; Let any mode through
        LDRNE   r14, =2_10000000000010100000000 ; SRS
        TEQNE   r5, r14
        BNE     Undefined

        TestBit 20
        BNE     %FT10
        AND     r5, r4, #2_1111:SHL:16
        TEQ     r5, #13:SHL:16          ; Must be SRS to SP
        BNE     Undefined
10
        TestStr 20,RfeTab,SrsTab
        TestBit 23,"I","D"              ; Up/~Down bit
        TestBit 24,"B","A"              ; Pre/~Post bit

        MOV     r5, r4, LSR #16
        BL      Tab_Dis_Register
        TEQ     r5, #15
        MOVEQ   r14, #Mistake_R15
        STREQ   r14, Mistake

        TestBit 21,"!"                  ; Writeback bit
        TestBit 20                      ; Is mode needed?
        ANDEQ   r8, r4, #2_11111
        BLEQ    StoreCommaHash_Decimal
        B       InstructionEnd
        
RfeTab  DCB     "RFE",0
SrsTab  DCB     "SRS",0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

maal
        ; Multiply-Accumulate-Accumulate long
        ; Arrive here with cccc 0000 0100 xxxx xxxx xxxx 1001 xxxx
        ; Format is        cccc 0000 0100 hhhh llll ssss 1001 mmmm
        ;
        ; UMAAL{cond}{S} RdLo,RdHi,Rm,Rs
        ;
        ; where cccc = condition
        ;       hhhh = RdHi
        ;       llll = RdLo
        ;       ssss = Rs
        ;       mmmm = Rm
        ;
        ; (RdHi,RdLo) := Rm*Rs + RdLo + RdHi

        [ WarnARMv6
        MOV     r14, #Mistake_ARMv6     ; all instructions here are ARMv6
        STR     r14, Mistake
        ]

        AddStr  Umaal,,conds

Dis_RlRhRmRs
        BL      TabOrPushOver

        MOV     r5, r4, LSR #12         ; RdLo
        AND     r6, r5, #2_1111
        BL      Dis_Register

        MOV     r5, r4, LSR #16         ; RdHi
        AND     r7, r5, #2_1111
        BL      Comma_Dis_Register

        MOV     r5, r4                  ; Rm
        AND     r8, r5, #2_1111
        BL      Comma_Dis_Register

        MOV     r5, r4, LSR #8          ; Rs
        AND     r9, r5, #2_1111
        BL      Comma_Dis_Register

        ; Can't use R15 as any register, unpredictable
        ; if RdLo=RdHi
        LDR     r14, Mistake
        TEQS    r6, r7
        MOVEQ   r14, #Mistake_RdLoRdHi
        TEQS    r6, #15
        TEQNES  r7, #15
        TEQNES  r8, #15
        TEQNES  r9, #15
        MOVEQ   r14, #Mistake_R15
        STR     r14, Mistake

        B       InstructionEnd

Umaal   DCB     "UMAAL", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

MRS_banked
        ; arrive here with cccc 0001 0x00 xxxx xxxx 001x 0000 0000
        ;
        ; format is        cccc 0001 0r00 mmmm dddd 001m 0000 0000
        ;
        ; MRS{cond} Rd, <banked_reg>
        ; where cccc = condition
        ;       dddd = Rd
        ;      mmmmm = mode
        ;          r = 1 for SPSR, 0 for reg
        [ WarnARMv7VE
        MOV     r14, #Mistake_ARMv7VE   ; Optional in v7VE
        STR     r14, Mistake
        ]
        ADRL    r10, MrsTAB
        BL      SaveStringConditions
        MOV     r5, r4, LSR #12
        BL      Tab_Dis_Register
        TEQ     r5, #15                 ; PC unpredictable
        MOVEQ   r14, #Mistake_R15
        STREQ   r14, Mistake
        BL      AddComma
        BL      Dis_Banked_Register
        B       InstructionEnd

MSR_banked
        ; arrive here with cccc 0001 0x10 xxxx 1111 001x 0000 xxxx
        ;
        ; format is        cccc 0001 0r00 mmmm 1111 001m 0000 nnnn
        ;
        ; MSR{cond} <banked_reg>, Rn
        ; where cccc = condition
        ;       nnnn = Rn
        ;      mmmmm = mode
        ;          r = 1 for SPSR, 0 for reg
        [ WarnARMv7VE
        MOV     r14, #Mistake_ARMv7VE   ; Optional in v7VE
        STR     r14, Mistake
        ]
        ADRL    r10, MsrTAB
        BL      SaveStringConditions
        BL      Tab
        BL      Dis_Banked_Register
        MOV     r5, r4
        BL      Comma_Dis_Register
        CMP     r5, #13
        MOVCS   r14, #Mistake_Unpred    ; R13-R15 unpredictable
        STRCS   r14, Mistake
        B       InstructionEnd

Dis_Banked_Register
        ; From DDI 0406C, B9.2.3 
        Push    "lr"
        MOV     r2, r4, LSL #12
        MOV     r2, r2, LSR #32 - 4
        TestBit 8
        ORRNE   r2, r2, #1:SHL:4        ; r2 := SYSm
        TestBit 22
        BNE     %FT30                   ; Banked SPSR

        LDR     r14, UnpredBReg
        MOV     r5, #1
        MOV     r5, r5, LSL r2          ; 2^SYSm
        TST     r14, r5
        MOVNE   r14, #Mistake_Unpred
        STRNE   r14, Mistake 

        ; Special case exception LR (don't want "ER14")
        TEQ     r2, #2_11110
        AddStr  ExcLRTAB,EQ
        BEQ     %FT40

        ; When SYSm[4:3] is 2_10 or 2_11 they're pairs of LR/SR
        CMP     r2, #2_10000
        ANDCC   r5, r2, #7
        ADDCC   r5, r5, #8              ; R8-R15
        BCC     %FT20
        TST     r2, #1
        MOVNE   r5, #13                 ; SP
        MOVEQ   r5, #14                 ; LR
20
        BL      Dis_Register
        B       %FT40
30
        ADRL    r10, spsr_tab
        BL      SaveString
        LDR     r14, UnpredBSPSR
        MOV     r5, #1
        MOV     r5, r5, LSL r2          ; 2^SYSm
        TST     r14, r5
        MOVNE   r14, #Mistake_Unpred
        STRNE   r14, Mistake 
40
        AddChar "_"
        ADR     r14, SYSmSuffixTAB
        LDRB    r14, [r14, r2, LSR #1]
        ADR     r10, BankedModeSuffixes
        ADD     r10, r10, r14, LSL #2
        BL      SaveString
        Pull    "pc"

ExcLRTAB
        DCB     "ELR", 0
        ALIGN
UnpredBReg
        ;         11----->10----->01----->00----->
        DCD     2_00001111000000001000000010000000
UnpredBSPSR
        ;         11----->10----->01----->00----->
        DCD     2_10101111101010101011111111111111
SYSmSuffixTAB
        ; Both register/SPSR use follow the same pairs of mode suffixes
        DCD     &00000000               ; SYSm[4:3] = 2_00
        DCD     &01010101               ; SYSm[4:3] = 2_01
        DCD     &05040302               ; SYSm[4:3] = 2_10
        DCD     &07060000               ; SYSm[4:3] = 2_11
BankedModeSuffixes
        DCB     "usr", 0                ; 0
        DCB     "fiq", 0                ; 1
        DCB     "irq", 0                ; 2
        DCB     "svc", 0                ; 3
        DCB     "abt", 0                ; 4
        DCB     "und", 0                ; 5
        DCB     "mon", 0                ; 6
        DCB     "hyp", 0                ; 7
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ControlExtension_uncond
        ; arrive here with 1111 0001 xxxx xxxx xxxx xxxx xxxx xxxx
        TSTS    r4, #2_11111100:SHL:8
        TSTEQS  r4, #2_1111:SHL:20
        BNE     Undefined

        [ WarnARMv6
        MOV     r14, #Mistake_ARMv6     ; all instructions here are ARMv6
        STR     r14, Mistake
        ]

        TestBit 16
        BNE     %FT20
        ; arrive here with 1111 0001 0000 xxx0 0000 00xx xxxx xxxx
        ; format is        1111 0001 0000 ssc0 0000 000a if0m mmmm
        ;
        ; CPS<ID|IE> <a|i|f>{,#mode}
        ; CPS        mode
        ;
        ; where    a = abort
        ;          i = irq
        ;          f = fiq
        ;      mmmmm = mode
        ;         ss = state change 11=disable, 10=enable
        ;          c = ChangeMode/~ChangeMode
        TST     r4, #2_00100010:SHL:4
        BNE     Undefined

        ANDS    r5, r4, #2_11:SHL:18
        TSTEQ   r4, #1:SHL:17           ; state = 00, c = 0
        TEQNE   r5, #2_01:SHL:18        ; state = 01
        BEQ     %FT05
 
        BIC     r14, r4, #2_111:SHL:6
        MOVS    r14, r14, LSL #31-17    ; mmmmm != 0 but c = 0
        BGT     %FT05

        TestBit 19                      
        AND     r8, r4, #2_111:SHL:6    ; Copy b19 next to aif bits
        ORRNE   r8, r8, #1:SHL:9        ; Range 0001 to 1000 is bad
        SUB     r8, r8, #1              ;   now 0000 to 0111 is bad instead
        CMP     r8, #2_1000:SHL:6       ; So state = 1x and aif == 0
        BCS     %FT10                   ; or state = 0x and aif != 0
05
        MOV     r14, #Mistake_Unpred
        STR     r14, Mistake
10
        AddStr  ChgSt
        CMP     r5, #2_10:SHL:18
        AND     r8, r4, #2_11111
        BCC     %FT15
        AddChar "I"
        TestBit 18,"D","E"
        BL      Tab
        TestBit 8,"a"
        TestBit 7,"i"
        TestBit 6,"f"
        TestBit 17
        BLNE    StoreCommaHash_Decimal  ; Using R8 from above
        B       InstructionEnd
15
        BL      Tab
        B       Rem_Number
20
        ; arrive here with 1111 0001 0000 xxx1 0000 00xx xxxx xxxx
        ; format is        1111 0001 0000 0001 0000 00e0 0000 0000
        ;
        ; SETEND   <BE|LE>
        ;
        ; where    e = BE/~LE

        TST     r4, #2_1110:SHL:16
        MOVEQS  r14, r4, LSL #32-9
        BNE     Undefined

        AddStr  Setend
        BL      Tab
        TestBit 9,"B","L"
        AddChar "E"
        B       InstructionEnd

Setend  DCB     "SETEND",0
ChgSt   DCB     "CPS",0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

UndefinedExtension ROUT
        ; arrive here with cccc 011x xxxx xxxx xxxx xxxx xxx1 xxxx

        [ WarnARMv6
        MOV     r14, #Mistake_ARMv6     ; most instructions here are ARMv6
        STR     r14, Mistake
        ]

        TestBit 24
        BNE     Mulv6
        TestBit 23
        BEQ     Parallel

        ; arrive here with cccc 0110 1xxx xxxx xxxx xxxx xxx1 xxxx
        AND     r5, r4, #2_1111:SHL:4
        AND     r6, r4, #2_1111:SHL:20
        ORR     r5, r6, r5, LSL #12     ; Now got op1 and op2 into 8 bits
        TST     r5, #2_01110010:SHL:16
        BEQ     is_PKH
        TEQ     r5, #2_10001011:SHL:16
        BEQ     is_SEL
        BIC     r6, r5, #2_01001000:SHL:16
        TEQ     r6,     #2_10110011:SHL:16
        BEQ     Rev_or_Rbit
        BIC     r6, r5, #2_01110000:SHL:16
        TEQ     r6,     #2_10000111:SHL:16
        BEQ     Extenders
        BIC     r6, r5, #2_01011110:SHL:16
        TEQ     r6,     #2_10100001:SHL:16
        BNE     Undefined

Saturates
        ; arrive here with cccc 0110 1x1x xxxx xxxx xxxx xxx1 xxxx
        ; format is        cccc 0110 1u1b bbbb dddd iiii ith1 nnnn
        ;
        ; <U|S>SAT<16>{cond} Rd,#bit,Rn{,shift}
        ;
        ; where cccc = condition
        ;          u = Unsigned/~Signed
        ;      bbbbb = saturation bit position
        ;          t = type of shift (1 = ASR, 0 = LSL)
        ;          h = halfword oriented (and iiiiit = 111100)
        TestBit 22,"U","S"
        MOV     r8, r4, LSR #16
        AND     r8, r8, #2_11111
        ADDEQ   r8, r8, #1              ; SSAT is encoded as bit-1
        TestStr 5,Sat16,SatOp,conds
        ANDNE   r5, r4, #2_11111100:SHL:4
        TEQNE   r5, #2_11110000:SHL:4
        BNE     Undefined

        MOV     r5, r4, LSR #12
        BL      TabOrPushOver
        BL      Dis_Register
        MOV     r6, r5
        BL      AddCommaHash
        BL      StoreDecimal_Comma      ; Using R8 from above
        MOV     r5, r4
        BL      Dis_Register
        TEQ     r5, #15
        TEQNE   r6, #15
        MOVEQ   r14, #Mistake_R15
        STREQ   r14, Mistake
        TestBit 5
        BNE     InstructionEnd          ; No shift on the <16> form
        B       Comma_LSL_or_ASR

SatOp   DCB     "SAT", 0
Sat16   DCB     "SAT16", 0
        ALIGN

Extenders ROUT
        ; arrive here with cccc 0110 1xxx xxxx xxxx xxxx 0111 xxxx
        ; format is        cccc 0110 1uww nnnn dddd rr00 0111 mmmm
        ;
        ; <U|S>XT<B|H|B16>{cond}     Rd,Rm{,rotate}
        ; or <U|S>XTA<B|H|B16>{cond} Rd,Rn,Rm{,rotate}
        ;
        ; where cccc = condition
        ;          u = Unsigned/~Signed
        ;         ww = width    (00=B16, 01=undef, 10=B, 11=H)
        ;       nnnn = Rn       (1111 is the non-A form)
        ;       dddd = Rd
        ;         rr = rotation (00=none, 01=ROR#8, 10=ROR#16, 11=ROR#24)
        ;       mmmm = Rm
        TST     r4, #2_0011:SHL:8
        BNE     Undefined
        TestBit 22,"U","S"
        AND     r7, r4, #2_1111:SHL:16
        TEQ     r7, #2_1111:SHL:16
        ADRNE   r10, EcsTeeA
        ADREQ   r10, EcsTee
        BL      SaveString
        TestBit 21
        BEQ     %FT10
        TestBit 20,"H","B"
        BL      Conditions
        B       %FT20
10
        TestBit 20
        BNE     Undefined
        AddStr  Bee16,,conds
20
        BL      TabOrPushOver
        MOV     r5, r4, LSR #12         ; Rd
        BL      Dis_Register
        MOV     r6, r5
        TEQ     r7, #2_1111:SHL:16
        MOVNE   r5, r4, LSR #16
        BLNE    Comma_Dis_Register      ; Maybe Rn
        MOV     r5, r4
        BL      Comma_Dis_Register      ; Rm
        TEQ     r5, #15
        TEQNE   r6, #16
        MOVEQ   r14, #Mistake_R15
        STREQ   r14, Mistake

        ANDS    r8, r4, #2_11:SHL:10
        BEQ     InstructionEnd          ; No rotate

        ADR     r10, RawHash
        BL      SaveString
        MOV     r8, r8, LSR #7          ; rr => 24/16/8
        BL      Rem_Number

EcsTee  DCB     "XT", 0
EcsTeeA DCB     "XTA", 0
Bee16   DCB     "B16", 0
RawHash DCB     ",ROR #", 0
        ALIGN

Rev_or_Rbit
        ; arrive here with cccc 0110 1x11 xxxx xxxx xxxx x011 xxxx
        ; format is        cccc 0110 1s11 1111 dddd 1111 h011 mmmm
        ;
        ; <REV|REV16|REVSH>{cond} Rd,Rm
        ; or           RBIT{cond} Rd,Rm
        ;
        ; where cccc = condition
        ;          s = sign-extend
        ;       dddd = Rd
        ;       mmmm = Rm
        ;          h = half-word      (s=1 & h=0 is RBIT)
        AND     r5, r4, #2_1111:SHL:8
        TEQ     r5, #2_1111:SHL:8
        ANDEQ   r5, r4, #2_1111:SHL:16
        TEQEQ   r5, #2_1111:SHL:16
        BNE     Undefined
        TestBit 22
        BNE     %FT2
        TestStr 7,Rev16,Rev,conds
        B       %FT3
2
        TestStr 7,RevSH,RbitTab,conds
        MOVEQ   r14, #Mistake_ARMv6T2   ; RBIT came later
        STREQ   r14, Mistake
3
        MOV     r5, r4, LSR #12
        AND     r5, r5, #15
        AND     r6, r4, #15
        TEQS    r5, #15
        TEQNES  r6, #15
        MOVEQ   lr, #Mistake_R15
        STREQ   lr, Mistake
        BL      Tab_Dis_Register
        MOV     r5, r4
        BL      Comma_Dis_Register
        B       InstructionEnd

is_SEL
        ; arrive here with cccc 0110 1000 xxxx xxxx xxxx 1011 xxxx
        ; format is        cccc 0110 1000 nnnn dddd 1111 1011 mmmm
        ;
        ; SEL{cond} Rd,Rn,Rm
        ;
        ; where cccc = condition
        ;       nnnn = Rn
        ;       dddd = Rd
        ;       mmmm = Rm
        AND     r5, r4, #2_1111:SHL:8
        TEQ     r5, #2_1111:SHL:8
        BNE     Undefined
        AddStr  Sel,,conds
        BL      Tab
        B       Dis_RdRnRm

Rev     DCB     "REV",0
Rev16   DCB     "REV16",0
RevSH   DCB     "REVSH",0
RbitTab DCB     "RBIT",0
Sel     DCB     "SEL",0
Pkhtb   DCB     "PKHTB",0
Pkhbt   DCB     "PKHBT",0
        ALIGN

is_PKH
        ; arrive here with cccc 0110 1000 xxxx xxxx xxxx xx01 xxxx
        ; format is        cccc 0110 1000 nnnn dddd iiii it01 mmmm
        ;
        ; PKH<TB|BT>{cond} Rd,Rn,Rm{,<ASR|LSL>#imm5}
        ;
        ; where cccc = condition
        ;       nnnn = Rn
        ;       dddd = Rd
        ;       mmmm = Rm
        ;          t = TB/~BT
        ;      iiiii = imm5   (0 = no shift)
        TestStr 6,Pkhtb,Pkhbt,conds
        MOV     r5, r4, LSR #12         ; Rd
        BL      Tab_Dis_Register
        CMP     r5, #15

        MOV     r5, r4, LSR #16
        BL      Comma_Dis_Register      ; Rn
        CMPCC   r5, #15

        MOV     r5, r4                  ; Rm
        BL      Comma_Dis_Register
        CMPCC   r5, #15
        MOVCS   r14, #Mistake_R15
        STRCS   r14, Mistake

Comma_LSL_or_ASR
        TST     r4, #2_11111100:SHL:4
        BEQ     InstructionEnd          ; Silent LSL #0

        MOV     r8, r4, LSR #7
        ANDS    r8, r8, #2_11111
        MOVEQ   r8, #32                 ; ASR #0 is ASR #32
        TestBit 6
        ADRL    r10, ShiftTypes         ; -> LSL
        ADDNE   r10, r10, #2*6          ; -> ASR
        BL      SaveString
        AddChar "#"
        B       Rem_Number

Parallel
        ; arrive here with cccc 0110 0xxx xxxx xxxx xxxx xxx1 xxxx
        ; format is        cccc 0110 0ppp nnnn dddd 1111 ooo1 mmmm
        ;
        ; <S|Q|SH|U|UQ|UH><ADD8|ADD16|SUB8|SUB16|ADDSUBX|SUBADDX>{cond}
        ;                                                      Rd,Rn,Rm
        ;
        ; where cccc = condition
        ;        ppp = prefix
        ;       nnnn = Rn
        ;       dddd = Rd
        ;        ooo = op
        ;       mmmm = Rm

        ANDS    r5, r4, #2_011:SHL:20
        BEQ     Undefined
        AND     r5, r4, #2_1111:SHL:8
        TEQS    r5, #2_1111:SHL:8
        BNE     Undefined

        ADR     r10,ParallelPrefixTAB-3
        AND     r5, r4, #2_111:SHL:20
        ADD     r5, r5, r5, LSL #1
        ADD     r10, r10, r5, LSR #20
        BL      SaveString

        EOR     r8, r4, r4, LSR #1
        TSTS    r8, #1:SHL:5
        BEQ     %FT01                   ; bit 5 = bit 6

        TestBit 7                       ; bit 5 != bit 6
        BNE     Undefined               ; ooo = 101 or 110 (undefined)

        TestStr 5,ParAsx,ParSax
        B       %FT02
01
        TestStr 6,ParSub,ParAdd
        TestStr 7,Par8,Par16
02
        BL      Conditions
        BL      TabOrPushOver

Dis_RdRnRm
        MOV     r5, r4, LSR #12         ; Rd
        AND     r6, r5, #2_1111
        BL      Dis_Register

        MOV     r5, r4, LSR #16         ; Rn
        AND     r7, r5, #2_1111
        BL      Comma_Dis_Register

        MOV     r5, r4                  ; Rm
        AND     r8, r5, #2_1111
        BL      Comma_Dis_Register

        ; Can't use R15 as any register
        TEQS    r6, #15
        TEQNES  r7, #15
        TEQNES  r8, #15
        MOVEQ   r14, #Mistake_R15
        STREQ   r14, Mistake

        B       InstructionEnd

ParallelPrefixTAB
        DCB     "S",0,0
        DCB     "Q",0,0
        DCB     "SH",0
        DCB     0,0,0
        DCB     "U",0,0
        DCB     "UQ",0
        DCB     "UH",0
ParSax  DCB     "SAX",0
ParAsx  DCB     "ASX",0
ParAdd  DCB     "ADD",0
ParSub  DCB     "SUB",0
Par8    DCB     "8",0
Par16   DCB     "16",0
        ALIGN

Mulv6
        ; arrive here with cccc 0111 xxxx xxxx xxxx xxxx xxx1 xxxx
        ANDS    r5, r4, #2_1111:SHL:20
        BEQ     DualSignedMultiplySum
        TEQS    r5, #2_0100:SHL:20
        BEQ     DualSignedMultiplySumLong
        TEQS    r5, #2_0101:SHL:20
        BEQ     SignedMultiplyMSB
        TEQS    r5, #2_1000:SHL:20
        BEQ     SumAbsoluteDifferences
        TEQS    r5, #2_0001:SHL:20
        TEQNES  r5, #2_0011:SHL:20
        BEQ     Division
        BIC     r5, r5, #2_0001:SHL:20  ; Knock out top bit of imm5
        TEQ     r5, #2_1100:SHL:20
        BEQ     BitFieldInsClr
        BIC     r5, r5, #2_0100:SHL:20  ; Knock out sign/unsigned bit
        TEQ     r5, #2_1010:SHL:20
        BEQ     BitFieldExtract
        B       Undefined

DualSignedMultiplySum
        ; arrive here with cccc 0111 0000 xxxx xxxx xxxx xxx1 xxxx
        ; format is        cccc 0111 0000 dddd nnnn ssss 0sx1 mmmm
        ;
        ; <SMUAD|SMUSD>{X}{cond}  Rd,Rm,Rs
        ; <SMLAD|SMLSD>{X}{cond}  Rd,Rm,Rs,Rn
        ;
        ; where cccc = condition
        ;       dddd = Rd
        ;       nnnn = Rn  (=1111 for SMUxD)
        ;       ssss = Rs
        ;          s = Subtract/~Add
        ;          x = eXchange
        ;       mmmm = Rm
        ;
        ; Rd = (RmLo*RsLo) +/- (RmHi*RsHi)         [X swaps RsHi/RsLo]
        ; Rd = (RmLo*RsLo) +/- (RmHi*RsHi) + Rn

        TestBit 7
        BNE     Undefined
        AddChar "S"
        AddChar "M"
        AND     r5, r4, #2_1111:SHL:12
        TEQS    r5, #2_1111:SHL:12
        MOVEQ   r10, #"U"
        MOVNE   r10, #"L"
        STRB    R10,[R0],#1
        TestBit 6,"S","A"
        AddChar "D"
        TestBit 5,"X"
        BL      Conditions
        BL      TabOrPushOver

Dis_RdRmRs_OptRn
        AND     r8, r4, #15
        MOV     r6, r4, LSR #8
        AND     r6, r6, #15
        MOV     r5, r4, LSR #16
        AND     r5, r5, #15
        TEQS    r8, #15
        TEQNES  r6, #15
        TEQNES  r5, #15
        MOVEQ   r14, #Mistake_R15
        STREQ   r14, Mistake

        BL      Dis_Register
        MOV     r5, r4
        BL      Comma_Dis_Register
        MOV     r5, r4, LSR #8
        BL      Comma_Dis_Register
        MOV     r5, r4, LSR #12
        AND     r5, r5, #15
        TEQ     r5, #15
        BLNE    Comma_Dis_Register

        B       InstructionEnd

Division
        ; arrive here with cccc 0111 00x1 xxxx xxxx xxxx xxx1 xxxx
        ; format is        cccc 0111 00u1 dddd 1111 mmmm 0001 nnnn
        ;
        ; <U|S>DIV{cond}  Rd,Rn,Rm
        ;
        ; where cccc = condition
        ;          u = unsigned/~signed
        ;       dddd = Rd
        ;       nnnn = Rn
        ;       mmmm = Rm

        TST     r4, #2_1110:SHL:4
        ANDEQ   r5, r4, #2_1111:SHL:12
        TEQEQ   r5, #2_1111:SHL:12
        BNE     Undefined
        [ WarnARMv7
        MOV     r14, #Mistake_ARMv7
        STR     r14, Mistake
        ]
        TestBit 21,"U","S"
        AddStr  DivOp,,conds
        BL      Tab
        B       Dis_RdRmRs_OptRn

DualSignedMultiplySumLong
        ; arrive here with cccc 0111 0100 xxxx xxxx xxxx xxx1 xxxx
        ; format is        cccc 0111 0100 hhhh llll ssss 0sx1 mmmm
        ;
        ; <SMLALD|SMLSLD>{X}{cond}  RdLo,RdHi,Rm,Rs
        ;
        ; where cccc = condition
        ;       hhhh = RdHi
        ;       llll = RdLo
        ;       ssss = Rs
        ;          s = Subtract/~Add
        ;          x = eXchange
        ;       mmmm = Rm
        ;
        ; (RdHi,RdLo) += (RmLo*RsLo) +/- (RmHi*RsHi)     [X swaps RsHi/RsLo]

        TestBit 7
        BNE     Undefined
        TestStr 6,Smlsld,Smlald
        TestBit 5,"X"
        BL      Conditions
        B       Dis_RlRhRmRs

SignedMultiplyMSB
        ; arrive here with cccc 0111 0101 xxxx xxxx xxxx xxx1 xxxx
        ; format is        cccc 0111 0101 dddd nnnn ssss ssr1 mmmm
        ;
        ; SMMUL{R}{cond}         Rd,Rm,Rs
        ; <SMMLA|SMMLS>{R}{cond} Rd,Rm,Rs,Rn
        ;
        ; where cccc = condition
        ;       dddd = Rd
        ;       nnnn = Rn  (=1111 for SMMUL)
        ;       ssss = Rs
        ;         ss = Subtract/~Add (=0 for SMMUL)
        ;          r = Round
        ;       mmmm = Rm
        ;
        ; Rd := (Rm*Rs).Hi
        ; Rd := (Rm*Rs).Hi +/- Rn
        EOR     r5, r4, r4, LSR #1
        TSTS    r5, #1:SHL:6
        BNE     Undefined               ; bit 6 must equal bit 7

        AND     r5, r4, #2_1111:SHL:12
        TEQ     r5, #2_1111:SHL:12
        BEQ     %FT01
        TestStr 6,Smmls,Smmla
        B       %FT02
01
        AddStr  Smmul
        TestBit 6
        BNE     Undefined
02
        TestBit 5,"R"
        BL      Conditions
        BL      TabOrPushOver

        B       Dis_RdRmRs_OptRn

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SumAbsoluteDifferences
        ; arrive here with cccc 0111 1000 xxxx xxxx xxxx xxx1 xxxx
        ; format is        cccc 0111 1000 dddd nnnn ssss 0001 mmmm
        ;
        ; USAD8{cond}    Rd,Rm,Rs
        ; USADA8{cond}   Rd,Rm,Rs,Rn
        ;
        ; where cccc = condition
        ;       dddd = Rd
        ;       nnnn = Rn  (=1111 for USAD8)
        ;       ssss = Rs
        ;          a = Halfword/~Byte
        ;       mmmm = Rm
        ;
        ; Rd = |Rm.3-Rs.3| + |Rm.2-Rs.2| + |Rm.1-Rs.1| + |Rm.0-Rs.0|
        ; Rd = |Rm.3-Rs.3| + |Rm.2-Rs.2| + |Rm.1-Rs.1| + |Rm.0-Rs.0| + Rn

        TSTS    r4, #2_111:SHL:5
        BNE     Undefined
        AddStr  Usad
        AND     r5, r4, #2_1111:SHL:12
        TEQ     r5, #2_1111:SHL:12
        AddChar "A",NE
        AddChar "8"
        BL      Conditions
        BL      TabOrPushOver
        B       Dis_RdRmRs_OptRn

DivOp   DCB     "DIV",0
Smmul   DCB     "SMMUL",0
Smmla   DCB     "SMMLA",0
Smmls   DCB     "SMMLS",0
Smlald  DCB     "SMLALD",0
Smlsld  DCB     "SMLSLD",0
Usad    DCB     "USAD",0
        ALIGN

BitFieldInsClr
        ; arrive here with cccc 0111 110x xxxx xxxx xxxx xxx1 xxxx
        ; format is        cccc 0111 110m mmmm dddd llll l001 nnnn
        ;
        ; BFI{cond}   Rd,Rn,#l,#w
        ; BFC{cond}   Rd,#l,#w
        ;
        ; where cccc = condition
        ;       dddd = Rd
        ;       nnnn = Rn  (=1111 for BFC)
        ;      mmmmm = msb
        ;      lllll = lsb
        [ WarnARMv6T2
        MOV     r14, #Mistake_ARMv6T2
        STR     r14, Mistake
        ]
        TST     r4, #2_0110:SHL:4
        BNE     Undefined
        AND     r6, r4, #2_1111
        TEQ     r6, #15
        ADREQ   r10, BfcTab
        ADRNE   r10, BfiTab
        BL      SaveStringConditions
        
        MOV     r5, r4, LSR #12
        BL      Tab_Dis_Register        ; Rd
        TEQ     r5, #15
        MOVEQ   r14, #Mistake_Unpred
        STREQ   r14, Mistake
        TEQ     r6, #15
        MOVNE   r5, r4
        BLNE    Comma_Dis_Register

        BL      AddCommaHash
        MOV     r8, r4, LSR #7
        AND     r8, r8, #2_11111
        BL      StoreDecimal            ; lsb
        RSB     r8, r8, #1
        MOV     r5, r4, LSL #11
        ADDS    r8, r8, r5, LSR #32-5   ; width = msb-lsb+1 = 1-lsb+msb
        MOVLE   r14, #Mistake_Unpred
        STRLE   r14, Mistake
        BL      StoreCommaHash_Decimal  ; width
        B       InstructionEnd

BfiTab  DCB     "BFI",0
BfcTab  DCB     "BFC",0
BfxTab  DCB     "BFX",0
        ALIGN
        
BitFieldExtract
        ; arrive here with cccc 0111 1x1x xxxx xxxx xxxx xxx1 xxxx
        ; format is        cccc 0111 1u1w wwww dddd llll l101 nnnn
        ;
        ; <U|S>BFX{cond} Rd,Rn,#lsb,#width
        ;
        ; where cccc = condition
        ;          u = Unsigned/~Signed
        ;       dddd = Rd
        ;       nnnn = Rn
        ;      wwwww = width - 1
        ;      lllll = lsb
        [ WarnARMv6T2
        MOV     r14, #Mistake_ARMv6T2
        STR     r14, Mistake
        ]
        AND     r5, r4, #2_0110:SHL:4
        TEQ     r5, #2_0100:SHL:4
        BNE     Undefined
        TestBit 22,"U","S"
        AddStr  BfxTab,,conds
        MOV     r5, r4, LSR #12
        BL      Tab_Dis_Register
        MOV     r6, r5
        MOV     r5, r4
        BL      Comma_Dis_Register
        TEQ     r5, #15
        TEQNE   r6, #15
        MOVEQ   r14, #Mistake_R15       ; Any reg PC is bad
        STREQ   r14, Mistake
        BL      AddCommaHash
        MOV     r8, r4, LSR #7
        AND     r8, r8, #2_11111
        BL      StoreDecimal_Comma
        MOV     r14, r4, LSR #16        ; Gah, if only there was some kind of
        AND     r14, r14, #2_11111      ; bit field extraction instruction
        ADD     r8, r8, r14
        CMP     r8, #32
        MOVHS   r8, #Mistake_Unpred
        STRHS   r8, Mistake
        ADD     r8, r14, #1
        AddChar "#"
        B       Rem_Number

is_CRC ROUT
        ; arrive here with cccc 0001 0xx0 xxxx xxxx xxxx 0100 xxxx
        ; format is        cccc 0001 0ss0 nnnn dddd 00p0 0100 mmmm
        ;
        ; CRC32<C><B|H|W|D>{cond} Rd,Rn,Rm
        ;
        ; where cccc = condition
        ;          p = polynomial
        ;       dddd = Rd
        ;       nnnn = Rn
        ;       mmmm = Rm
        ;         ss = size
        TST     r4, #2_1101:SHL:8
        BNE     Undefined
        [ WarnARMv8
        MOV     r14, #Mistake_ARMv8
        STR     r14, Mistake
        ]
        AND     r5, r4, #2_1111:SHL:28
        TEQ     r5, #2_1110:SHL:28      ; Note conditional is unpredictable
        AND     r5, r4, #2_11:SHL:21
        MOV     r14, #Mistake_Unpred
        STRNE   r14, Mistake
        TEQ     r5, #2_11:SHL:21        ; As is 64 bit size
        STREQ   r14, Mistake

        AddStr  Crc32Op
        TestBit 9,"C"
        ADR     r14, Crc32Sz
        LDRB    r10, [r14, r5, LSR #21]
        STRB    r10, [r0], #1

        MOV     r5, r4, LSR #12
        BL      Tab_Dis_Register
        MOV     r7, r5

        MOV     r5, r4, LSR #16
        BL      Comma_Dis_Register
        MOV     r8, r5

        MOV     r5, r4
        BL      Comma_Dis_Register
        TEQ     r5, #15                 ; Can't use PC for nothing no more
        TEQNE   r7, #15
        TEQNE   r8, #15
        MOVEQ   r14, #Mistake_R15
        STREQ   r14, Mistake
        B       InstructionEnd

Crc32Op DCB     "CRC32", 0
Crc32Sz DCB     "BHWD"
        ALIGN

        END
