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
; File:    CirrusDSP.s
; Purpose: Disassembly of the Cirrus DSP instruction set
; Author:  K Bracey

 [ CirrusDSP
CirrusDSPInstruction

        ; arrive here with cccc 11oo xxxx xxxx xxxx #### xxxx xxxx
        ; where oo <> 11 and #### is in the range [4-6]

        CMP     r3, #&0E
        BEQ     CirrusDSP_processing

; DSP Data Transfer
        ; arrive here with cccc 110x xxxx xxxx xxxx xxxx xxxx xxxx
        ; format is        cccc 110p unwl nnnn dddd #### iiii iiii
        ;
        ; <CFLDR|CFSTR><S|D|32|64>{cond} Cd,[Rn,#imm]{!}
        ; <CFLDR|CFSTR><S|D|32|64>{cond} Cd,[Rn],#imm
        ;
        ; where cccc = condition
        ;          p = Pre-indexing/~Post-indexing
        ;          u = Up/~Down
        ;          n = transfer length (S/D, or 32/64)
        ;          w = Writeback
        ;          l = Load/~Store
        ;       nnnn = Rn
        ;       dddd = Cd
        ;   iiiiiiii = 8-bit immediate offset
        ;       #### = CP# (4 => float, 5 => integer)

        TEQ     r2, #6 :SHL: 8          ; CP6 not used
        BEQ     Co_Transfer

        TST     r4, #1 :SHL: 24 :OR: 1 :SHL: 21
        BEQ     Undefined               ; Post-indexed, but no writeback!

        TestStr 20,Cfldr,Cfstr          ; Load/~Store bit

        TEQ     r2, #5 :SHL: 6
        BEQ     %FT01
        TestBit 22,"D","S"
        BL      Conditions
        B       %FT02
01
        TestStr 22,S_64,S_32,conds
02

        AND     r14, r4, #1 :SHL: 15    ; FPDT precision bits (Y,X)
        MOV     r14, r14, LSR #15
        AND     r10, r4, #1 :SHL: 22
        ORR     r14, r14, r10, LSR #22-1
        ADR     r10, fp_prec
        LDRB    r10, [r10, r14]
        STRB    r10, [r0], #1

        BL      Tab

        MOV     r5, r4, LSR #12         ; Fd
        BL      Dis_F_Register

        B       CPDT_Common

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Floating_processing ROUT

	; arrive here with cccc 1110 xxxx xxxx xxxx 0001 xxxx xxxx

	TSTS	r4, #1 :SHL: 19
	TSTNES	r4, #1 :SHL: 7
	BNE	Coprocessor_NotFP	; Silly precision

        TST     r4, #1 :SHL: 4          ; Transfer/~Operation bit
        BNE     Floating_Register_Transfer

	; Floating Point Data Operation (FPDO)
	; arrive here with cccc 1110 xxxx exxx xxxx 0001 fxx0 xxxx
	; with ef <> 11
	;
	; format is        cccc 1110 abcd ennn jddd 0001 fgh0 immm
	;
	; <Dyadic op>{cond}<S|D|E>{P|M|Z} Fd,Fn,<Fm|#constant>
	; <Monadic op>{cond}<S|D|E>{P|M|Z} Fd,<Fm|#constant>
	;
	; where cccc = condition
	;       abcd = opcode
	;	  ef = destination size
	;         gh = rounding mode
	;       immm = Fm/constant
	;	 nnn = Fn
	;        ddd = Fd
	;          j = Monadic/~Dyadic

        MOV     R6, #Potential_SWICDP_Next
        STR     R6, Mistake

        AND     r6, r4, #2_01111:SHL:20 ; FPOpc
        TestBit	15
	BEQ	%FT05
        ORR     r6, r6, #2_10000:SHL:20 ; jabcde

	TST	r4, #2_111:SHL:16	; Check Fn=F0 for monadic opcodes
	BNE	Coprocessor_NotFP

5	CMP	r6, #12:SHL:20
	BLS	%FT01
	CMP	r6, #15:SHL:20
	BLS	Coprocessor_NotFP

01      ADR     r1, Floating_Operations
        BL      FPRT_FPDO_Common

        MOV     r5, r4, LSR #12         ; Fd
        BL      Dis_F_Register

        TestBit	15
        BNE     Dis_FmOrConstant        ; [unary op]

        BL      AddComma
        B       Dis_Fn_FmOrConstant

        LTORG

Ldf     DCB     "LDF", 0
Stf     DCB     "STF", 0

Lfm     DCB     "LFM", 0
Sfm     DCB     "SFM", 0

Floating_Operations

        DCB     "ADF"           ; 0  ... binary ops
        DCB     "MUF"           ; 1
        DCB     "SUF"           ; 2
        DCB     "RSF"           ; 3
        DCB     "DVF"           ; 4
        DCB     "RDF"           ; 5
        DCB     "POW"           ; 6
        DCB     "RPW"           ; 7

        DCB     "RMF"           ; 8
        DCB     "FML"           ; 9
        DCB     "FDV"           ; 10
        DCB     "FRD"           ; 11
        DCB     "POL"           ; 12
        DCB     "F0D"           ; 13 ... undefined binary ops
        DCB     "F0E"           ; 14
        DCB     "F0F"           ; 15

        DCB     "MVF"           ; 16 ... unary ops
        DCB     "MNF"           ; 17
        DCB     "ABS"           ; 18
        DCB     "RND"           ; 19
        DCB     "SQT"           ; 20
        DCB     "LOG"           ; 21
        DCB     "LGN"           ; 22
        DCB     "EXP"           ; 23

        DCB     "SIN"           ; 24
        DCB     "COS"           ; 25
        DCB     "TAN"           ; 26
        DCB     "ASN"           ; 27
        DCB     "ACS"           ; 28
        DCB     "ATN"           ; 29
        DCB     "URD"           ; 30
        DCB     "NRM"           ; 31

fp_round
	DCB	0, "PMZ"
fp_prec
        DCB     "SDEP"

Floating_Transfers

        DCB     "FLT"           ; 0/L
        DCB     "FIX"           ; 0/S
        DCB     "WFS"           ; 1/L
        DCB     "RFS"           ; 1/S
        DCB     "WFC"           ; 2/L
        DCB     "RFC"           ; 2/S

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

FPRT_FPDO_Common ENTRY

        ADD     r6, r6, r6, LSL #1      ; *3
        ADD     r1, r1, r6, LSR #20
        LDRB    r10, [r1], #1
        STRB    r10, [r0], #1
        LDRB    r10, [r1], #1
        STRB    r10, [r0], #1
        LDRB    r10, [r1], #1
        STRB    r10, [r0], #1

        BL      Conditions

	TestBit	4
	BEQ	%FT01			; FPDO always has precision bits
	ANDS	r14, r4, #2_1111 :SHL: 20
	BEQ	%FT01			; FLT has precision
	CMPS	r14, #2_0110 :SHL: 20
	BLO	%FT02			; WFS etc don't have precision

	; Show precision for undefined instructions

01      AND     r14, r4, #1 :SHL: 7     ; FPDO/FPRT precision bits (e,f)
        MOV     r14, r14, LSR #7
        AND     r10, r4, #1 :SHL: 19
        ORR     r14, r14, r10, LSR #19-1
        ADR     r10, fp_prec
        LDRB    r10, [r10, r14]
        STRB    r10, [r0], #1

	; WFS etc don't use the rounding bits, but they should be set
	; to zero anyway, so don't bother checking

02	ANDS	r14, r4, #2_11 :SHL: 5
	ADRNE	r10, fp_round
	LDRNEB	r10, [r10, r14, LSR #5]
	STRNEB	r10, [r0], #1

04      BL      Tab
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	; Floating Point Register Transfer (FPRT)
	; arrive here with cccc 1110 xxxx exxx xxxx 0001 fxx1 xxxx
	; with ef <> 11
	;
	; format is        cccc 1110 abcl ennn dddd 0001 fgh1 0mmm
	;
	; FLT{cond}<S|D|E>{P|M|Z} Fn,Rd
	; FIX{cond}{P|M|Z}        Rd,Fm
	; <WFS|RFS|WFC|RFC>{cond} Rd
	;
	; where cccc = condition
	;          l = Load/~Store
	;        abc = operation            abcl         abcl
	;   				    0000 FLT     0001 FIX
	;       			    0010 WFS     0011 RFS
	;				    0100 WFC     0101 RFC
	;                                                1xx1 may be compare
	;         ef = destination size (FLT only)
	;         gh = rounding mode (FLT and FIX only)
	;        nnn = Fn (FLT only)
	;        mmm = Fm (FIX only)
	;       dddd = Rd
Floating_Register_Transfer ROUT

	; Check for CMF (abc=4-7, Rd=R15, efgh=0000)
        LDR     r2,  =&0E98FFF0
        LDR     r10, =&0E90F110
        AND     r2, r4, r2
        CMP     r2, r10
        BEQ     Floating_Status_Transfer

        AND     r6, r4, #2_1111 :SHL: 20 ; FPOpc + L

	CMP	r6, #6 :SHL: 20
	BHS	Coprocessor_NotFP	; Show undefined as simple MCR/MRC

	ADR	r1, Floating_Transfers	; Needed by FPRT_FPDO_Common

	CMP	r6, #1 :SHL: 20
	BLO	FPRT_FLT
	BEQ	FPRT_FIX

FPRT_RFSetc
	TSTS	r4, #2_11101111		; WFS etc can't have bits 0-3,5-7,16-19 set
	BNE	Coprocessor_NotFP
	TSTS	r4, #2_1111:SHL:16
	BNE	Coprocessor_NotFP

	; arrive here with cccc 1110 0bcl 0000 dddd 0001 0001 0000        (bc <> 11)
	BL	FPRT_FPDO_Common
	MOV	r5, r4, LSR #12
	BL	Dis_Register		; Rd
	B	InstructionEnd

FPRT_FIX
	TSTS	r4, #1:SHL:3 :OR: 1:SHL:7
	BNE	Coprocessor_NotFP	; FIX can't have bits 3,7,16-19 set
	TSTS	r4, #2_1111:SHL:16
	BNE	Coprocessor_NotFP

	; arrive here with cccc 1110 0001 0000 dddd 0001 0gh1 0mmm
	BL	FPRT_FPDO_Common
	MOV	r5, r4, LSR #12
	BL	Dis_Register		; Rd (destination ARM register)
	BL	Dis_FmOrConstant	; Fm (source FP register)
	B	InstructionEnd

FPRT_FLT
	TSTS	r4, #2_1111		; FLT can't have bits 0-3 set
	BNE	Coprocessor_NotFP

	; arrive here with cccc 1110 0000 ennn dddd 0001 fgh1 0000
	BL	FPRT_FPDO_Common
	MOV	r5, r4, LSR #16
	BL	Dis_F_Register		; Fn (destination FP register)
	MOV	r5, r4, LSR #12
	BL	Comma_Dis_Register	; Rd (source ARM register)
	B	InstructionEnd

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Floating Point Status Transfer

Cmf     DCB     "CMF", 0
Cnf     DCB     "CNF", 0
        ALIGN

Floating_Status_Transfer
	; Floating point compare
	; arrive here with cccc 1110 1xx1 0xxx 1111 0001 0001 xxxx
	;
	; format is        cccc 1110 1en1 0nnn 1111 0001 0001 immm
	;
	; <CMF|CNF>{E}{cond} Fn,Fm
	; <CMF|CNF>{E}{cond} Fn,#constant
	;
	; where cccc = condition
	;	   e = Exception
	;	   n = CNF/~CMF
	;	 nnn = Fn
	;       immm = Fm/constant

	TestStr	21,Cnf,Cmf              ; Negated compare/~Compare bit

	TestBit	22,"E"                  ; Exception bit

        BL      Conditions

        BL      Tab

; .............................................................................

Dis_Fn_FmOrConstant

        MOV     r5, r4, LSR #16         ; Fn
        BL      Dis_F_Register

; .............................................................................

Dis_FmOrConstant ROUT

        BL      AddComma

        TST     r4, #2_1000             ; Immediate operand ?
        BNE     %FT50

        AND     r5, r4, #2_0111         ; Fm
        BL      Dis_F_Register
        B       InstructionEnd

50
	AddChar	"#"

        AND     r8, r4, #2_0111         ; 3 bits instead of Fm
        CMPS    r8, #6                  ; 0..7 -> 0,1,2,3,4,5,0.5,10
        ADREQ   r10, Pt5                ; 0.5
        BEQ     SaveStringEnd

        MOVHI   r8, #10
        BL      StoreDecimal

        B       InstructionEnd


Pt5     DCB     "0.5", 0

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

New_FPA
	; arrive here with cccc 11oo xxxx xxxx xxxx 0010 xxxx xxxx
	; where oo <> 11
	;
	; format is        cccc 110p uywl nnnn xddd 0010 iiii iiii
	;
	; <LFM|SFM>{cond} Fd,count,[Rn, #imm]{!}
	; <LFM|SFM>{cond} Fd,count,[Rn],#imm
	;
	; where cccc = condition
	;          p = Pre-indexed/~Post-indexed
	;          u = Up/~Down
	;         yx = register count (4,1,2 or 3)
	;          w = Writeback
	;          l = Load/~Store
	;       nnnn = Rn
	;        ddd = Fd
	;   iiiiiiii = immediate offset

	TestBit 25
	BNE	Coprocessor_NotFP       ;only coproc 2 codes so far are LFM/SFM

	TST	r4, #1 :SHL: 24 :OR: 1 :SHL: 21
	BEQ	Undefined		; Post-indexed, but no writeback!

	TestStr	20,Lfm,Sfm,conds
        BL      Tab

        MOV     r5, r4, LSR #12         ; Fd
        BL      Dis_F_Register

	AddChar	","

        MOV     r5, r4, LSR #15
        AND     r5, r5, #1
        MOV     r14, r4, LSR #21
        AND     r14, r14, #2
        ORRS    r5, r5, r14
        MOVEQ   r5, #4
        ADD     r5, r5, #"0"
        STRB    r5, [r0], #1

	B	CPDT_Common ;drop into ordinary CPDT processing

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ShowFPRegs_Code

        ENTRY "r6-r11",12

        LDR     wp, [r12]

        SWI     XFPEmulator_ExceptionDump
        EXIT    VS

        MOV     r5, r0

        BL      message_writes          ; Display address of register dump
        DCB     "M17", 0	        ; "Register dump (stored at &)
        ALIGN

        MOVVC   r10, r0
        BLVC    DisplayHexWord
        EXIT    VS

        BL      message_writes
        DCB     "M18", 0	        ; ") is:"
        ALIGN
        SWIVC   XOS_NewLine
        EXIT    VS
        BL      message_writes
        DCB     "F03", 0                ; "S Exp J Fraction" headers
        ALIGN
        EXIT    VS

        RFS     r1                      ; save current FPSR
        Push    "r1"
        MOV     r1, #0                  ; no exceptions
        WFS     r1
        SFMFD   f0, 1, [sp]!            ; and save F0

        MOV     r4, #0
        ADD     r11, r5, #4

10 ; Display dumped registers in hex format first

        TST     r4, #1
        SWIEQ   XOS_NewLine
        BVS     ExitSFPR

        BEQ     %FT12
        SWI     XOS_WriteS
        DCB     "          ", 0
        ALIGN
12
        SWIVC   XOS_WriteI+"F"

        ADDVC   r0, r4, #"0"
        SWIVC   XOS_WriteC
        BVS     ExitSFPR

        SWI     XOS_WriteS
        DCB     " = ", 0
        ALIGN
        BVS     ExitSFPR

        LDR     r3, [r11], #4           ; get extended value from dump
        TST     r3, #1:SHL:31           ; sign bit
        SWIEQ   XOS_WriteI+"0"
        SWINE   XOS_WriteI+"1"
        SWIVC   XOS_WriteI+" "
        MOVVC   r10, r3, LSL #17
        MOVVC   r10, r10, LSR #17       ; exponent
        MOVVC   r2, #12
        BLVC    DisplayHex
        SWIVC   XOS_WriteI + " "
        BVS     ExitSFPR
        LDR     r3, [r11], #4
        TST     r3, #1:SHL:31           ; J bit
        SWIEQ   XOS_WriteI+"0"
        SWINE   XOS_WriteI+"1"
        SWIVC   XOS_WriteI+" "
        BICVC   r10, r3, #1:SHL:31
        BLVC    DisplayHexWord
        LDRVC   r10, [r11], #4
        BLVC    DisplayHexWord
        BVS     ExitSFPR

        ADD     r4, r4, #1
        TEQS    r4, #8
        BNE     %BT10

        SWI     XOS_NewLine
        BVS     ExitSFPR
        SWI     XOS_WriteS
        DCB     "FPSR = ", 0
        ALIGN
        LDRVC   r10, [r5]
        BLVC    DisplayHexWord
        SWIVC   XOS_NewLine
        SWIVC   XOS_NewLine
        BVS     ExitSFPR

        MOV     r4, #0
        ADD     r11, r5, #4

10 ; Followed by registers in decimal

        TST     r4, #1
        SWIEQ   XOS_NewLine
        BVS     ExitSFPR

        SWINV   XOS_WriteI+space

        SWIVC   XOS_WriteI+"F"

        ADDVC   r0, r4, #"0"
        SWIVC   XOS_WriteC
        BVS     ExitSFPR

        SWI     XOS_WriteS
        DCB     " = ", 0
        ALIGN
        BVS     ExitSFPR

        LDFE    f0, [r11], #12          ; get extended value from dump
        STFP    f0, [sp, #16]           ; and convert to expanded packed decimal
        LDR     r3, [sp, #16]           ; r3 := sign + exponent
        TST     r3, #1:SHL:31
        SWINE   XOS_WriteI + "-"
        MOVVC   r10, r3, LSR #8
        MOVVC   r2, #0
        BLVC    DisplayHex
        SWIVC   XOS_WriteI + "."
        MOVVC   r10, r3
        MOVVC   r2, #4
        BLVC    DisplayHex
        LDRVC   r10, [sp, #20]
        BLVC    DisplayHexWord
        LDRVC   r10, [sp, #24]
        BLVC    DisplayHexWord
        BVS     ExitSFPR

        BIC     r10, r3, #&F0000000
        MOVS    r10, r10, LSR #12
        BEQ     NoExponent

        SWI     XOS_WriteI + "E"
        BVS     ExitSFPR
        TST     r3, #1:SHL:30
        SWIEQ   XOS_WriteI + "+"
        SWINE   XOS_WriteI + "-"
        MOVVC   r2, #12
        BLVC    DisplayHex
        BVS     ExitSFPR

NoExponent
        ADD     r4, r4, #1
        TEQS    r4, #8
        BNE     %BT10

        SWI     XOS_NewLine
ExitSFPR
        LFMFD   f0, 1, [sp]!
        Pull    "r1"
        WFS     r1                      ; restore FPSR
        EXIT
 ]
        END
