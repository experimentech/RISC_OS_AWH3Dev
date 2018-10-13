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
;> Assembler

ASS     MOV     R10,#OPT_list+OPT_errors
        STRB    R10,[ARGP,#BYTESM]
        LDR     R10,[ARGP,#ASSPC]
        Push    "R10" ; Save for CASMKET
CASM    MOV     AELINE,LINE
        BL      AESPAC
        TEQ     R10,#"."
        BNE     CASM1
        BL      LVBLNK
        BNE     CASM1A
        BCS     ERSYNT
        BL      CREATE
CASM1A  CMP     TYPE,#128
        BCS     ERTYPENUM
        MOV     R4,IACC
        MOV     R5,TYPE
        LDR     IACC,[ARGP,#ASSPC]
        MOV     TYPE,#4
        BL      STOREA
        BL      AESPAC
CASM1   TEQ     R10,#"]"
        BEQ     CASMKET
        MOV     R2,#0
        TEQ     R10,#":"
        TEQNE   R10,#13
        BEQ     CASMX
        CMP     R10,#"\\"
        CMPNE   R10,#";"
        CMPNE   R10,#TREM
        BEQ     CASMXCOM
        CMP     R10,#"="
        BEQ     CASMDCB
        CMP     R10,#"&"
        BEQ     CASMEQUD
        TEQ     R10,#TFN
        BEQ     CASMFN
        CMP     R10,#&7F
        BHS     CASMTOK

 [ :DEF: VFPAssembler
        TEQ     R10,#"V"                         ; begins with V?
        TEQNE   R10,#"v"                         ; ?
        BEQ     VFPEntry                         ; try the VFP assembler...
VFPReturn
 ]

CASM1B  LDRB    R1,[AELINE]
        CMP     R10,#TOR                         ; special case tokenised [OR]R
        BIC     R1,R1,#" "
        CMPEQ   R1,#"R"
        LDREQ   R2,CASMTBORR
        ADDEQ   AELINE,AELINE,#1
        BEQ     CASMGT1
        CMP     R10,#TMOVE                       ; special case tokenised [MOVE]Q
        BEQ     CASMMOVEQ
 [ :DEF: VFPAssembler
        CMP     R10,#TVDU                        ; special case tokenised [VDU]P
        CMPEQ   R1,#"P"
        BEQ     VFPEntryVDUP
 ]
        BIC     R10,R10,#" "
        TEQ     R10,#"B"
        BEQ     CASMB
CASM2A  ORR     R0,R10,R1,LSL #8
        LDRB    R1,[AELINE,#1]
        BIC     R1,R1,#" "
        ORR     R0,R0,R1,LSL #16
        ADR     R1,CASMTB
        LDR     R2,[R1],#4
        MOV     R0,R0,LSL #8
CASM2   TEQ     R0,R2,LSL #8
        BEQ     CASMGT
        TEQ     R2,#0
        LDRNE   R2,[R1],#4
        BNE     CASM2
        ADR     R1,CASMTB2
        LDR     R2,[R1],#4
CASM3   TEQ     R0,R2,LSL #8
        BEQ     CASMGT2
        TEQ     R2,#0
        LDRNE   R2,[R1],#4
        BNE     CASM3
        ADR     R1,CASMTB3
        LDR     R2,[R1],#4
CASM4   TEQ     R0,R2,LSL #8
        BEQ     CASMGT3
        TEQ     R2,#0
        LDRNE   R2,[R1],#4
        BNE     CASM4
        B       ERASS1
CASMTOK ADR     R1,CASMTOKTB
CASMTK2 LDRB    R2,[R1],#2
        TEQ     R10,R2
        TEQNE   R2,#0
        BNE     CASMTK2
        TEQ     R2,#0
        BEQ     CASM1B
        LDRB    R2,[R1,#-1]
        LDR     R2,[PC,R2,LSL #2]
        B       CASMGT1

CASMTB  =       "SWI",&8F
        =       "ADC",&05
        =       "ADD",&04
CASMTBAND
        =       "AND",&00
        =       "BIC",&0E
        =       "CMN",&1B
        =       "CMP",&1A
CASMTBEOR
        =       "EOR",&01
        =       "MOV",&2D
        =       "MVN",&2F
CASMTBORR
        =       "ORR",&0C
        =       "RSB",&03
        =       "RSC",&07
        =       "SBC",&06
        =       "SUB",&02
        =       "TEQ",&19
        =       "TST",&18
        =       "MUL",&30
        =       "MLA",&31
        =       "MLS",&33
        =       "LDR",&44
        =       "STR",&54
        =       "LDM",&68
        =       "STM",&78
        =       "OPT",&F0
        =       "EQU",&F1
        =       "DCB",&F2
        =       "DCW",&F3
        =       "DCD",&F4
        =       "ADR",&F5
        =       "ALI",&F6
        =       "CDP",&90
        =       "MRR",&92
        =       "MCR",&94
        =       "MRC",&96
        =       "STC",&98
        =       "LDC",&9C
        =       "SWP",&A0
        =       "MSR",&A1
        =       "MRS",&A3
        =       "ADF",&D0
        =       "MVF",&E0
        =       "MUF",&D1
        =       "MNF",&E1
        =       "SUF",&D2
CASMTBABS
        =       "ABS",&E2
        =       "RSF",&D3
CASMTBRND
        =       "RND",&E3
        =       "DVF",&D4
        =       "SQT",&E4
        =       "RDF",&D5
CASMTBLOG
        =       "LOG",&E5
        =       "POW",&D6
        =       "LGN",&E6
        =       "RPW",&D7
CASMTBEXP
        =       "EXP",&E7
        =       "RMF",&D8
CASMTBSIN
        =       "SIN",&E8
        =       "FML",&D9
CASMTBCOS
        =       "COS",&E9
        =       "FDV",&DA
CASMTBTAN
        =       "TAN",&EA
        =       "FRD",&DB
CASMTBASN
        =       "ASN",&EB
        =       "POL",&DC
CASMTBACS
        =       "ACS",&EC
CASMTBATN
        =       "ATN",&ED
        =       "URD",&EE
        =       "NRM",&EF
        =       "FLT",&C0
        =       "FIX",&C1
        =       "WFS",&C2
        =       "RFS",&C3
        =       "WFC",&C4
        =       "RFC",&C5
        =       "CMF",&C9
        =       "CNF",&CB
        =       "STF",&B0
        =       "LDF",&B4
        =       "SFM",&B8
        =       "LFM",&BC
        =       "DCF",&F7
        =       "UMU",&34
        =       "UML",&35
        =       "SMU",&36
        =       "SML",&37
        =       "NOP",&FF
        &       0
CASMTOKTB

        =       TAND, (CASMTBAND - CASMTB):SHR:2
        =       TEOR, (CASMTBEOR - CASMTB):SHR:2
        =       TABS, (CASMTBABS - CASMTB):SHR:2
        =       TRND, (CASMTBRND - CASMTB):SHR:2
        =       TLOG, (CASMTBLOG - CASMTB):SHR:2
        =       TEXP, (CASMTBEXP - CASMTB):SHR:2
        =       TSIN, (CASMTBSIN - CASMTB):SHR:2
        =       TCOS, (CASMTBCOS - CASMTB):SHR:2
        =       TTAN, (CASMTBTAN - CASMTB):SHR:2
        =       TASN, (CASMTBASN - CASMTB):SHR:2
        =       TACS, (CASMTBACS - CASMTB):SHR:2
        =       TATN, (CASMTBATN - CASMTB):SHR:2
        =       0
        ALIGN

; group of 16 opcodes that do not demand matching of more
;   than 3 chars before any condition
CASMTB2 =       "DBG",&02
        =       "CLZ",&16
        =       "HVC",&24  ; unconditional
        =       "PLD",&39  ; unconditional
        =       "PLI",&4D  ; unconditional
        =       "BFC",&5C
        =       "BFI",&6C
        =       "WFE",&72
        =       "SEL",&88
        =       "HLT",&90
        =       "DMB",&A7  ; unconditional
        =       "DSB",&B7  ; unconditional
        =       "ISB",&C7  ; unconditional
        =       "REV",&DB
        =       "UDF",&EF  ; unconditional
        =       "WFI",&F2
        &       0

; opcodes that are longer, unconditional and/or simply did not fit
;   in the two preceding tables. alphabetically sorted

CASMTB3_START
CASMTB3 =       "BKP",(CASMTB_BKP-CASMTB3)/4
        =       "CLR",(CASMTB_CLR-CASMTB3)/4
        =       "CPS",(CASMTB_CPS-CASMTB3)/4
        =       "CRC",(CASMTB_CRC-CASMTB3)/4
        =       "ERE",(CASMTB_ERE-CASMTB3)/4
        =       "LDA",(CASMTB_LDA-CASMTB3)/4
        =       "PKH",(CASMTB_PKH-CASMTB3)/4
        =       "POP",(CASMTB_POP-CASMTB3)/4
        =       "PUS",(CASMTB_PUS-CASMTB3)/4
        =       "QAD",(CASMTB_QAD-CASMTB3)/4
        =       "QAS",(CASMTB_QAS-CASMTB3)/4
        =       "QSU",(CASMTB_QSU-CASMTB3)/4
        =       "QDA",(CASMTB_QDA-CASMTB3)/4
        =       "QDS",(CASMTB_QDS-CASMTB3)/4
        =       "QSA",(CASMTB_QSA-CASMTB3)/4
        =       "RBI",(CASMTB_RBI-CASMTB3)/4
        =       "RFE",(CASMTB_RFE-CASMTB3)/4
        =       "SAD",(CASMTB_SAD-CASMTB3)/4
        =       "SAS",(CASMTB_SAS-CASMTB3)/4
        =       "SBF",(CASMTB_SBF-CASMTB3)/4
        =       "SDI",(CASMTB_SDI-CASMTB3)/4
        =       "SET",(CASMTB_SET-CASMTB3)/4
        =       "SEV",(CASMTB_SEV-CASMTB3)/4
        =       "SHA",(CASMTB_SHA-CASMTB3)/4
        =       "SHS",(CASMTB_SHS-CASMTB3)/4
        =       "SMC",(CASMTB_SMC-CASMTB3)/4
        =       "SMI",(CASMTB_SMI-CASMTB3)/4
        =       "SMM",(CASMTB_SMM-CASMTB3)/4
        =       "SRS",(CASMTB_SRS-CASMTB3)/4
        =       "SSA",(CASMTB_SSA-CASMTB3)/4
        =       "SSU",(CASMTB_SSU-CASMTB3)/4
        =       "STL",(CASMTB_STL-CASMTB3)/4
        =       "SVC",(CASMTB_SVC-CASMTB3)/4
        =       "SXT",(CASMTB_SXT-CASMTB3)/4
        =       "UAD",(CASMTB_UAD-CASMTB3)/4
        =       "UAS",(CASMTB_UAS-CASMTB3)/4
        =       "UBF",(CASMTB_UBF-CASMTB3)/4
        =       "UDI",(CASMTB_UDI-CASMTB3)/4
        =       "UHA",(CASMTB_UHA-CASMTB3)/4
        =       "UHS",(CASMTB_UHS-CASMTB3)/4
        =       "UMA",(CASMTB_UMA-CASMTB3)/4
        =       "UQA",(CASMTB_UQA-CASMTB3)/4
        =       "UQS",(CASMTB_UQS-CASMTB3)/4
        =       "USA",(CASMTB_USA-CASMTB3)/4
        =       "USU",(CASMTB_USU-CASMTB3)/4
        =       "UXT",(CASMTB_UXT-CASMTB3)/4
        =       "YIE",(CASMTB_YIE-CASMTB3)/4
        &       0

; each level 2 table consists of a list of suffixes, each followed by 2 bytes:
;   1st byte - bit 7   indicates 'suffix end'
;              bit 6   indicates opcode may be conditional
;             bits 5:0 index into jump table
;   2nd byte - 'starter' byte is supplied as bits 27:20 of instruction in R1
;
; the table is terminated by a 0-valued byte. no alignment requirements apply
; to table entries, but each table must be word-aligned. entries within a table
; are tested sequentially, so suffixes that are substrings of others must be
; listed later (ie. '...B16' must precede '...B' to prevent incorrect matching)
;
; Please keep tables listed alphabetically by the first 3 chars of opcode(s)

CASMTB_BKP
        =       "T",&C1,&12
        =       0
        ALIGN
CASMTB_CLR
        =       "EX",&A0,&57
        =       0
        ALIGN
CASMTB_CPS
        =       "IE",&9B,&10
        =       "ID",&9C,&10
        =       &97,&10
        =       0
        ALIGN
CASMTB_CRC
        =       "32B",&A4,&10
        =       "32H",&A4,&12
        =       "32W",&A4,&14
        =       "32CB",&A4,&90         ; Denote CRC32C via 2nd byte b7
        =       "32CH",&A4,&92
        =       "32CW",&A4,&94
        =       0
        ALIGN
CASMTB_ERE
        =       "T",&D3,&16
        =       0
        ALIGN
CASMTB_LDA
        =       "EXD",&E5,&1B
        =       "EXH",&E5,&1F
        =       "EXB",&E5,&1D
        =       "EX",&E5,&19
        =       &E6,&19
        =       0
        ALIGN
CASMTB_PKH
        =       "TB",&C2,&68
        =       "BT",&C3,&68
        =       0
        ALIGN
CASMTB_POP
        =       &E1,&0B
        =       0
        ALIGN
CASMTB_PUS
        =       "H",&E1,&12
        =       0
        ALIGN
CASMTB_QAD
        =       "D16",&C7,&62
        =       "D8",&C8,&62
        =       "D",&C0,&10
        =       0
        ALIGN
CASMTB_QAS
        =       "X",&C4,&62
        =       0
        ALIGN
CASMTB_QSU
        =       "B16",&D5,&62
        =       "B8",&D6,&62
        =       "B",&C0,&12
        =       0
        ALIGN
CASMTB_QDA
        =       "DD",&C0,&14
        =       0
        ALIGN
CASMTB_QDS
        =       "UB",&C0,&16
        =       0
        ALIGN
CASMTB_QSA
        =       "X",&C5,&62
        =       0
        ALIGN
CASMTB_RBI
        =       "T",&C6,&6F
        =       0
        ALIGN
CASMTB_RFE
        =       "DA",&92,&81
        =       "DB",&92,&91
        =       "IA",&92,&89
        =       "IB",&92,&99
        =       0
        ALIGN
CASMTB_SAD
        =       "D16",&C7,&61
        =       "D8",&C8,&61
        =       0
        ALIGN
CASMTB_SAS
        =       "X",&C4,&61
        =       0
        ALIGN
CASMTB_SBF
        =       "X",&CA,&7A
        =       0
        ALIGN
CASMTB_SDI
        =       "V",&C9,&71
        =       0
        ALIGN
CASMTB_SET
        =       "END",&8B,&10
        =       0
        ALIGN
CASMTB_SEV
        =       "L",&E3,&B2            ; Denote SEVL via 2nd byte b7
        =       &E3,&32
        =       0
        ALIGN
CASMTB_SHA
        =       "DD16",&C7,&63
        =       "DD8",&C8,&63
        =       "SX",&C4,&63
        =       0
        ALIGN
CASMTB_SHS
        =       "AX",&C5,&63
        =       "UB16",&D5,&63
        =       "UB8",&D6,&63
        =       0
        ALIGN
CASMTB_SMC
        =       &D8,&16
        =       0
        ALIGN
CASMTB_SMI
        =       &E2,&16
        =       0
        ALIGN
CASMTB_SMM
        =       "LA",&9D,&75
        =       "LS",&9E,&75
        =       "UL",&9F,&75
        ALIGN
CASMTB_SRS
        =       "DA",&99,&84
        =       "DB",&99,&94
        =       "IA",&99,&8C
        =       "IB",&99,&9C
        =       0
        ALIGN
CASMTB_SSA
        =       "T16",&CE,&6A
        =       "T",&CD,&6A
        =       "X",&C5,&61
        =       0
        ALIGN
CASMTB_SSU
        =       "B16",&D5,&61
        =       "B8",&D6,&61
        =       0
        ALIGN
CASMTB_STL
        =       "EXD",&E7,&1A
        =       "EXH",&E7,&1E
        =       "EXB",&E7,&1C
        =       "EX",&E7,&18
        =       &E8,&18
        =       0
        ALIGN
CASMTB_SVC
        =       &DA,&F0
        =       0
        ALIGN
CASMTB_SXT
        =       "AB16",&CF,&68
        =       "AB",&CF,&6A
        =       "AH",&CF,&6B
        =       "B16",&D0,&68
        =       "B",&D0,&6A
        =       "H",&D0,&6B
        =       0
        ALIGN
CASMTB_UAD
        =       "D16",&C7,&65
        =       "D8",&C8,&65
        =       0
        ALIGN
CASMTB_UAS
        =       "X",&C4,&65
        =       0
        ALIGN
CASMTB_UBF
        =       "X",&CA,&7E
        =       0
        ALIGN
CASMTB_UDI
        =       "V",&C9,&73
        =       0
        ALIGN
CASMTB_UHA
        =       "DD16",&C7,&67
        =       "DD8",&C8,&67
        =       "SX",&C4,&67
        =       0
        ALIGN
CASMTB_UHS
        =       "AX",&C5,&67
        =       "UB16",&D5,&67
        =       "UB8",&D6,&67
        =       0
        ALIGN
CASMTB_UMA
        =       "AL",&D4,&04
        =       0
        ALIGN
CASMTB_UQA
        =       "DD16",&C7,&66
        =       "DD8",&C8,&66
        =       "SX",&C4,&66
        =       0
        ALIGN
CASMTB_UQS
        =       "AX",&C5,&66
        =       "UB16",&D5,&66
        =       "UB8",&D6,&66
        =       0
        ALIGN
CASMTB_USA
        =       "D8",&C9,&78
        =       "DA8",&CC,&78
        =       "T16",&CE,&6E
        =       "T",&CD,&6E
        =       "X",&C5,&65
        =       0
        ALIGN
CASMTB_USU
        =       "B16",&D5,&65
        =       "B8",&D6,&65
        =       0
        ALIGN
CASMTB_UXT
        =       "AB16",&CF,&6C
        =       "AB",&CF,&6E
        =       "AH",&CF,&6F
        =       "B16",&D0,&6C
        =       "B",&D0,&6E
        =       "H",&D0,&6F
        =       0
        ALIGN
CASMTB_YIE
CASMTB3_END
        =       "LD",&D1,&32
        =       0
        ALIGN

        ; check that table offsets will be within range
        ASSERT  (CASMTB3_END - CASMTB3_START) < &400

CASMKET MVN     R10,#0                 ;deal with ]
        STRB    R10,[ARGP,#BYTESM]
        MOV     LINE,AELINE
        MOV     R10, R0
        MOV     R0, #1
        Pull    "R1" ; Get stashed start address
        LDR     R2,[ARGP,#ASSPC]
        CMP     R2, R1
        SWIHI   XOS_SynchroniseCodeAreas
        MOV     R0, R10
        B       STMT

CASMGT  ADD     AELINE,AELINE,#2
CASMGT1 CMP     R2,#&F0000000
        BCS     CASMOPS
        BL      ALIGN                  ;definitely not a directive, so align
        AND     R1,R2,#&0F000000
        CMP     R2,#&40000000
        MOVLO   R1,R1,LSR #3
        CMP     R2,#&C0000000
        MOVHS   R1,R1,LSR #4
        MOV     R4,R2,LSR #28
        BL      DOCOND
        ADR     R0,CASMTABLE
        LDR     R3,[R0,R4,LSL #2]
        ADD     PC,PC,R3
ASMAJ                           *       .+4
CASMTABLE

        &       CASMTHREEDATA-ASMAJ
        &       CASMTWOCMP   -ASMAJ
        &       CASMTWOMOV   -ASMAJ
        &       CASMMUL      -ASMAJ
        &       CASMLDR      -ASMAJ
        &       CASMSTR      -ASMAJ
        &       CASMLDM      -ASMAJ
        &       CASMSTM      -ASMAJ
        &       CASMSWI      -ASMAJ
        &       CASMCP       -ASMAJ
        &       CASMARM6     -ASMAJ
        &       CASMFPDT     -ASMAJ
        &       CASMFPRT     -ASMAJ
        &       CASMFPTHREEOP-ASMAJ
        &       CASMFPTWOOP  -ASMAJ

CASMGT2 ADD     AELINE,AELINE,#2
        BL      ALIGN                  ;definitely not a directive
        AND     R1,R2,#&0F000000
        MOV     R1,R1,LSR #4
        MOV     R4,R2,LSR #28
        BL      DOCOND
        ADR     R0,CASMTABLE2
        LDR     R3,[R0,R4,LSL #2]
        ADD     PC,PC,R3
ASMAJ2                          *       .+4
CASMTABLE2
        &       CASMDBG      -ASMAJ2
        &       CASMCLZ      -ASMAJ2
        &       CASMHVC      -ASMAJ2
        &       CASMPLD      -ASMAJ2
        &       CASMPLI      -ASMAJ2
        &       CASMBFC      -ASMAJ2
        &       CASMBFI      -ASMAJ2
        &       CASMWFE      -ASMAJ2
        &       CASMSEL      -ASMAJ2
        &       CASMHLT      -ASMAJ2
        &       CASMDMB      -ASMAJ2
        &       CASMDSB      -ASMAJ2
        &       CASMISB      -ASMAJ2
        &       CASMREV      -ASMAJ2
        &       CASMUDF      -ASMAJ2
        &       CASMWFI      -ASMAJ2

CASMGT3 ADD     AELINE,AELINE,#2
        BL      ALIGN                  ;definitely not a directive

        ; second stage matching works char-by-char, testing against
        ;   each of the variable-length suffixes in the referenced
        ;   level 2 table

        BIC     R2,R2,#&00C00000
        ADR     R1,CASMTB3
        ADD     R1,R1,R2,LSR #22       ;address of level 2 table

        MOV     R4,AELINE              ;remember current match position
        LDRB    R10,[AELINE],#1
        LDRB    R0,[R1],#1
CASM3LP CMP     R10,#"a"
        BICHS   R10,R10,#" "
        TST     R0,#&80
        TEQEQ   R10,R0
        LDREQB  R10,[AELINE],#1
        LDREQB  R0,[R1],#1
        BEQ     CASM3LP

        ; got verdict - if matched, dispatch

        TST     R0,#&80
        BNE     CASM3MATCH

        ;rewind to 4th char of opcode and try the next table entry, if any

        LDRB    R0,[R1],#1
        MOV     AELINE,R4
CASM3NEXT
        TST     R0,#&80
        LDREQB  R0,[R1],#1
        BEQ     CASM3NEXT
        LDRB    R0,[R1,#1]             ;first char of next suffix, or terminator
        LDRB    R10,[AELINE],#1
        ADD     R1,R1,#2
        TEQ     R0,#0
        BEQ     ERASS1                 ;end of table, not a valid opcode
        B       CASM3LP

CASM3MATCH
        ; collect the byte to use as a starter in encoding the instruction
        ;  (and which permits the parser routine to differentiate
        ;   opcodes if it's invoked for multiple table entries)

        LDRB    R1,[R1]
        SUB     AELINE,AELINE,#1       ;AELINE -> first char after matched opcode
        AND     R4,R0,#&3F             ;jump table index for this opcode
        MOV     R1,R1,LSL #20          ;'starter' byte supplies bits 27:20
        TST     R0,#&40
        ORREQ   R1,R1,#&F0000000       ;most unconditionals use F (formerly-NV)
        BLNE    DOCOND
        ADR     R0,CASMTABLE3
        LDR     R3,[R0,R4,LSL #2]
        ; AELINE -> first char after matched opcode chars
        ; R10 invalid
        ADD     PC,PC,R3

; Append new instructions, do NOT insert; indexes into this jump table
;   are stored in the CASMTB3 table and would need adjusting
ASMAJ3                          *       .+4
CASMTABLE3
        &       CASMQSAT     -ASMAJ3
        &       CASMBKPT     -ASMAJ3
        &       CASMPKHTB    -ASMAJ3
        &       CASMPKHBT    -ASMAJ3
        &       CASMASX      -ASMAJ3
        &       CASMSAX      -ASMAJ3
        &       CASMRBIT     -ASMAJ3
        &       CASMADD16    -ASMAJ3
        &       CASMADD8     -ASMAJ3
        &       CASMDIV      -ASMAJ3
        &       CASMBFX      -ASMAJ3
        &       CASMSETEND   -ASMAJ3
        &       CASMUSADA8   -ASMAJ3
        &       CASMSAT      -ASMAJ3
        &       CASMSAT16    -ASMAJ3
        &       CASMSUXTA    -ASMAJ3
        &       CASMSUXT     -ASMAJ3
        &       CASMYIELD    -ASMAJ3
        &       CASMRFE      -ASMAJ3
        &       CASMERET     -ASMAJ3
        &       CASMUMAAL    -ASMAJ3
        &       CASMSUB16    -ASMAJ3
        &       CASMSUB8     -ASMAJ3
        &       CASMCPS      -ASMAJ3
        &       CASMSMC      -ASMAJ3
        &       CASMSRS      -ASMAJ3
        &       CASMSVC      -ASMAJ3
        &       CASMCPSIE    -ASMAJ3
        &       CASMCPSID    -ASMAJ3
        &       CASMSMMLA    -ASMAJ3
        &       CASMSMMLS    -ASMAJ3
        &       CASMSMMUL    -ASMAJ3
        &       CASMCLREX    -ASMAJ3
        &       CASMPUSHPOP  -ASMAJ3
        &       CASMSMI      -ASMAJ3
        &       CASMSEV      -ASMAJ3
        &       CASMCRC32    -ASMAJ3
        &       CASMLDAEX    -ASMAJ3
        &       CASMLDA      -ASMAJ3
        &       CASMSTLEX    -ASMAJ3
        &       CASMSTL      -ASMAJ3

; PUSH and POP do NOT set bit 27 at this point,
;   to allow differentiation from LDM/STM later...
CASMPUSHPOP
        ORR     R1,R1,#&D0000
        B       CASMSTM1A

CASMLDM ORR     R1,R1,#&100000
CASMSTM LDRB    R10,[AELINE],#1
        BIC     R2,R10,#" "
        LDRB    R0,[AELINE],#1
        BIC     R0,R0,#" "
        ORR     R0,R2,R0,LSL #8
        MOV     R0,R0,LSL #16
        ADR     R2,STMTAB
CASMSTM1

        LDR     R3,[R2],#4
        TEQ     R3,#0
        BEQ     ERSYNT
        CMP     R0,R3,LSL #16
        BNE     CASMSTM1
        TST     R1,#&100000            ;if LDM
        MOVNE   R3,R3,LSL #8           ;use other value
        AND     R3,R3,#&FF000000
        ORR     R1,R1,R3,LSR #1
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #16
        BL      AESPAC
        CMP     R10,#"!"
        ORREQ   R1,R1,#&200000
        BLEQ    AESPAC
        CMP     R10,#","
        BNE     ERCOMM
CASMSTM1A
        BL      AESPAC
        CMP     R10,#"{"
        BNE     ERASSB2
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12       ;remember register number
        BL      AESPAC
        CMP     R10,#"}"
        TSTEQ   R1,#&08000000
        BEQ     CASMPUSHPOP1
        AND     R0,R1,#&F000
        BIC     R1,R1,R0
        MOV     R0,R0,LSR #12
        MOV     R3,#1
        ORR     R1,R1,R3,LSL R0
        B       CASMSTM2A

CASMSTM2

        BL      CHKREGSPC
        MOV     R3,#1
        ORR     R1,R1,R3,LSL R0
        BL      AESPAC
CASMSTM2A

        CMP     R10,#","
        BEQ     CASMSTM2
        CMP     R10,#"-"
        BNE     CASMSTM3
        STMFD   SP!,{R0,R3}
        BL      CHKREGSPC
        LDMFD   SP!,{R2,R3}
        CMP     R0,R2
        BEQ     CASMSTM5
        MOVCS   R14,R0
        MOVCS   R0,R2
        MOVCS   R2,R14                 ;swap if r0 > r2
CASMSTM4

        ORR     R1,R1,R3,LSL R0
        ADD     R0,R0,#1
        CMP     R0,R2
        BNE     CASMSTM4
        ORR     R1,R1,R3,LSL R0
CASMSTM5

        BL      AESPAC
        CMP     R10,#","
        BEQ     CASMSTM2
CASMSTM3

        CMP     R10,#"}"
        BNE     ERASSB3
        BL      AESPAC
        EOR     R2,R1,#&08000000
        CMP     R10,#"^"
        TSTEQ   R2,#&08000000          ;exclude PUSH/POP
        ORREQ   R1,R1,#&400000
        ADREQL  R14,CASMICHK
        BEQ     AESPAC                 ;t.c.o.
        ORR     R1,R1,#&08000000       ;complete PUSH/POP encoding
        B       CASMICHK
CASMPUSHPOP1

        ;single register PUSH/POP encoding
        TST     R1,#&100000
        BICNE   R1,R1,#&200000
        ORR     R1,R1,#&04000000
        ORR     R1,R1,#4
        ADRL    R14,CASMICHK
        B       AESPAC                 ;t.c.o.
STMTAB  =       "IA",1,1
        =       "IB",3,3
        =       "DA",0,0
        =       "DB",2,2
        =       "FA",0,3
        =       "FD",1,2
        =       "EA",2,1
        =       "ED",3,0
        =       0,0,0,0

CASMLDSTNC
        ; LD/STR instructions that must not be conditional at this stage
        TEQ     R10,#"E"
        BEQ     CASMLDSTREX
        B       CASMLDSTR

CASMLDR ORR     R1,R1,#&00100000
CASMSTR LDRB    R10,[AELINE]
        ORR     R1,R1,#&00800000
        BIC     R10,R10,#" "
        BNE     CASMLDSTNC
CASMLDSTR
        TEQ     R10,#"S"
        TEQNE   R10,#"H"
        TEQNE   R10,#"D"
        BEQ     CASMLDRSHD
        TEQ     R10,#"B"
        ORREQ   R1,R1,#&400000
CASMLDSTCOMMON3
        LDREQB  R10,[AELINE,#1]!
        TEQ     R10,#"t"
        TEQNE   R10,#"T"
        ORREQ   R1,R1,#&200000
        ADDEQ   AELINE,AELINE,#1

        BL      CHKREGSPC
CASMLDSTCOMMON

        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
CASMLDSTCOMMON2

        CMP     R10,#"["
        BNE     CASMLDRLABEL
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #16
        BL      AESPAC
        CMP     R10,#"]"
        BEQ     CASMPOST
        TST     R1,#&200000
        BNE     ERASSB1
        ; do not set 'pre-indexed' bit in PLD and PLI instructions
        ;  because these are implicitly pre-indexed, and this bit
        ;  differentiates them
        AND     R14,R1,#&F0000000
        TEQ     R14,#&F0000000
        ORRNE   R1,R1,#&1000000
        CMP     R10,#","
        BNE     ERCOMM
        BL      AESPAC
        CMP     R10,#"#"
        BEQ     CASMPREIM
        TST     R1,#&8000000
        BNE     ERSYNT
        CMP     R10,#"-"
        BICEQ   R1,R1,#&800000
        BLEQ    AESPAC
        BL      CHKREG
        ORR     R1,R1,R0
        BL      AESPAC
        TST     R1,#&4000000
        ORRNE   R1,R1,#&2000000
        BICEQ   R1,R1,#&400000
        BEQ     CASMPREEND
        CMP     R10,#","
        BLEQ    CASMDATASHIFT
        B       CASMPREEND
CASMPREIM

        BL      ASMEXPR
        SUB     AELINE,AELINE,#1
        BL      PACKPOST
        BL      AESPAC
CASMPREEND

        CMP     R10,#"]"
        BNE     ERASSB1
        BL      AESPAC
        CMP     R10,#"!"
        BNE     CASMICHK
        ; PLD/PLI do not permit writeback
        AND     R14,R1,#&F0000000
        TEQ     R14,#&F0000000
        ORRNE   R1,R1,#&200000
        BLNE    AESPAC
        B       CASMICHK
CASMPOST

        BL      AESPAC
        CMP     R10,#","
        BEQ     CASMPOST1
        TST     R1,#&200000
        ORREQ   R1,R1,#&1000000
        B       CASMICHK
CASMPOST1
        ; PLD/PLI do not support post-indexed addressing
        ;   (a corollary of not supporting writeback)
        AND     R14,R1,#&F0000000
        TEQ     R14,#&F0000000
        BEQ     CASMICHK
        BL      AESPAC
        CMP     R10,#"#"
        BEQ     CASMPOSTIM
        CMP     R10,#"{"
        BEQ     CASMPOSTINFO
        TST     R1,#&8000000
        BNE     ERSYNT
        CMP     R10,#"-"
        BICEQ   R1,R1,#&800000
        BLEQ    AESPAC
        BL      CHKREG
        ORR     R1,R1,R0
        BL      AESPAC
        TST     R1,#&4000000
        ORRNE   R1,R1,#&2000000
        BICEQ   R1,R1,#&400000
        BEQ     CASMICHK
        CMP     R10,#","
        BLEQ    CASMDATASHIFT
        B       CASMICHK
CASMPOSTIM

        TST     R1,#&8000000
        ORRNE   R1,R1,#&200000
        BL      ASMEXPR
        BL      PACKPOST
        B       CASMICHK
CASMPOSTINFO

        TST     R1,#&8000000
        BEQ     ERSYNT
        BL      ASMEXPR
        CMP     R10,#"}"
        BNE     ERASSB3
        CMP     R0,#255
        BHI     ERASS2C
        ORR     R1,R1,R0
        BL      AESPAC
        B       CASMICHK
CASMLDRLABEL

        SUB     AELINE,AELINE,#1
        BL      ASMEXPR
        LDR     R2,[ARGP,#ASSPC]
        ADD     R2,R2,#8
        SUB     IACC,IACC,R2
        ORR     R1,R1,#&F0000          ;base reg PC
        ; do not set 'pre-indexed' bit in PLD and PLI instructions
        ;  because these are implicitly pre-indexed, and this bit
        ;  differentiates them
        AND     R14,R1,#&F0000000
        TEQ     R14,#&F0000000
        ORRNE   R1,R1,#&1000000        ;pre-indexed mode
        BL      PACKPOST
        B       CASMICHK

PACKPOST

        TEQ     IACC,#0
        BICMI   R1,R1,#&800000
        RSBMI   IACC,IACC,#0
        TST     R1,#&8000000
        BNE     PACKPOSTCP
        TST     R1,#&4000000
        BEQ     PACKPOSTH
        CMP     IACC,#&1000
        ORRCC   R1,R1,IACC
        MOVCC   PC,R14
PACKPOSTBAD

        LDRB    R0,[ARGP,#BYTESM]
        TST     R0,#OPT_errors
        MOVEQ   PC,R14
        B       ERASS2A

PACKPOSTCP

        TST     IACC,#3
        BNE     PACKPOSTBAD
        CMP     IACC,#&400
        BHS     PACKPOSTBAD
        ORR     R1,R1,IACC,LSR #2
        MOV     PC,R14
PACKPOSTH

        STR     R14,[SP,#-4]!
        CMP     IACC,#&100
        BHS     PACKPOSTBAD
        AND     R14,IACC,#&F
        ORR     R1,R1,R14
        AND     R14,IACC,#&F0
        ORR     R1,R1,R14,LSL #4
        LDR     PC,[SP],#4
CASMLDRSHD

        ; LDR<S|H|D>...
        BIC     R1,R1,#&4000000
        ORR     R1,R1,#&400000
        TEQ     R10,#"H"
        ORREQ   R1,R1,#&B0
        BEQ     CASMLDSTCOMMON3
        TEQ     R10,#"D"
        ADDEQ   AELINE,AELINE,#1
        BEQ     CASMLDRD
        ; ...so it must be LDRS...
        TST     R1,#&100000
        LDRNEB  R10,[AELINE,#1]!
        BEQ     ERASS1                 ;signedness is meaningless for STR
        ORR     R1,R1,#&D0
        BIC     R10,R10,#" "
        TEQ     R10,#"H"
        ORREQ   R1,R1,#&20
        TEQNE   R10,#"B"
        BNE     ERASS1
        B       CASMLDSTCOMMON3
CASMLDRD

        TST     R1,#&100000
        BIC     R1,R1,#&100000
        ORRNE   R1,R1,#&D0
        ORREQ   R1,R1,#&F0
        BL      CHKREGSPC
        TST     R0,#1
        BNE     ERASS3
        B       CASMLDSTCOMMON

CASMLDA
        ORR     R1,R1,#1:SHL:9
        LDRB    R10,[AELINE]
        BIC     R10,R10,#" "
        TEQ     R10,#"H"
        ORREQ   R1,R1,#1:SHL:21        ; Sets b22 & b21 by cunning
        TEQNE   R10,#"B"
        ORREQ   R1,R1,#1:SHL:22
        ADDEQ   AELINE,AELINE,#1
CASMLDAEX
        EOR     R1,R1,#1:SHL:9
        ORR     R1,R1,#&09F
        ORR     R1,R1,#&C00
        B       CASMEXPOSTCC           ; Treat like LDREX now

CASMSTL
        ORR     R1,R1,#2_1111:SHL:12   ; Rd=15 for non -EX
        ORR     R1,R1,#&C90
        LDRB    R10,[AELINE]
        BIC     R10,R10,#" "
        TEQ     R10,#"H"
        ORREQ   R1,R1,#1:SHL:21        ; Sets b22 & b21 by cunning
        TEQNE   R10,#"B"
        ORREQ   R1,R1,#1:SHL:22
        ADDEQ   AELINE,AELINE,#1
        BL      CHKREGSPC
        ORR     R1,R1,R0
        B       CASMLDSTREX2
CASMSTLEX
        ORR     R1,R1,#&E90
        B       CASMEXPOSTCC           ; Treat like STREX now

CASMLDSTREX
        LDRB    R10,[AELINE,#1]!
        BIC     R1,R1,#&FF000000
        ORR     R1,R1,#&F90
        BIC     R10,R10,#" "
        TEQ     R10,#"X"
        LDREQB  R10,[AELINE,#1]!
        BNE     ERASS1
        BIC     R0,R10,#" "
        ORR     R1,R1,#&01000000
        TEQ     R0,#"B"
        ORREQ   R1,R1,#&00400000
        TEQ     R0,#"D"
        ORREQ   R1,R1,#&00200000
        TEQ     R0,#"H"
        ORREQ   R1,R1,#&00600000
        TST     R1,#&00600000
        ADDNE   AELINE,AELINE,#1
        BL      DOCOND
CASMEXPOSTCC
        BL      CHKREGSPC
        ;Rt must be even and not R14 for LDREXD
        AND     R14,R1,#7:SHL:20
        TEQ     R14,#3:SHL:20          ; op=LD sz=D
        BNE     %FT10
        MOVS    R14,R0,LSR #1          ; C=1 <=> t=odd
        CMPCC   R0,#14                 ; C=1 <=> t=14 (15 is odd)
        BCS     ERASS3
10      ORR     R1,R1,R0,LSL #12       ; Rd for STREX or Rt for LDREX
        BL      CHKCOM
        TST     R1,#&00100000          ; LDREX rather than store?
        ORRNE   R1,R1,#&F
        BNE     CASMLDREX1
        BL      CHKREG
        ;Rt must be even and not R14 for STREXD
        AND     R14,R1,#7:SHL:20
        TEQ     R14,#2:SHL:20          ; op=ST sz=D
        BNE     %FT10
        MOVS    R14,R0,LSR #1          ; C=1 <=> t=odd
        CMPCC   R0,#14                 ; C=1 <=> t=14 (15 is odd)
        BCS     ERASS3
10      ORR     R1,R1,R0
        BL      CHKCOM
CASMLDREX1

        AND     R2,R1,#&00600000
        TEQ     R2,#&00200000
        BNE     CASMLDSTREX1
        ; Rt2 must be Rt+1 for <LDR|STR>EXD in ARM ISA
        BL      CHKREG
        TST     R1,#&100000
        MOVEQ   R2,R1,LSL #28
        MOVNE   R2,R1,LSL #16
        SUB     R0,R0,#1
        TEQ     R0,R2,LSR #28
        BNE     ERASS3
        ; Rt2 is not encoded
CASMLDSTREX2
        BL      CHKCOM
CASMLDSTREX1
        CMP     R10,#"["
        BNE     ERASSB4
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #16
        BL      AESPAC
        CMP     R10,#"]"
        BNE     ERASSB1
        ADRL    R14,CASMICHK
        B       AESPAC

CASMMOVWT
        MOV     R1,R2
        BL      DOCOND
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        BL      ASMIMEXPR
        CMP     R0,#&10000
        ANDLO   R2,R0,#&F000
        MOVLO   R0,R0,LSL #20
        ORRLO   R1,R1,R2,LSL #4
        BHS     ERASS2
        ORR     R1,R1,R0,LSR #20
        B       CASMICHK

CASMMOVEQ

        CMP     R1,#"Q"
        BNE     ERASS1
        BL      ALIGN
        MOV     R1,#&1A00000
        ADD     AELINE,AELINE,#1
CASMTWOMOV

        LDRB    R10,[AELINE],#1
        BEQ     CASMTWOMOV1            ; condition specified
        TST     R1,#&400000
        BNE     CASMTWOMOV1

        ; test for MOVW/MOVT opcode
        BIC     R0,R10,#" "
        MOV     R2,#&03000000
        TEQ     R0,#"T"
        ORREQ   R2,R2,#&00400000
        TEQNE   R0,#"W"
        BEQ     CASMMOVWT

CASMTWOMOV1

        CMP     R10,#"S"
        CMPNE   R10,#"s"
        ORREQ   R1,R1,#&100000
        LDREQB  R10,[AELINE],#1
        BL      CHKREGSPCCONT
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
        B       CASMONES2
CASMTWOCMP

        ORR     R1,R1,#&100000
        LDRB    R10,[AELINE]
        CMP     R10,#"S"
        CMPNE   R10,#"s"
        ADDEQ   AELINE,AELINE,#1
        CMP     R10,#"P"
        CMPNE   R10,#"p"
        ADDEQ   AELINE,AELINE,#1
        ORREQ   R1,R1,#&F000
        BL      AESPAC
        B       CASMTWORN
CASMTHREEDATA

        LDRB    R10,[AELINE],#1
        CMP     R10,#"S"
        CMPNE   R10,#"s"
        ORREQ   R1,R1,#&100000
        LDREQB  R10,[AELINE],#1
        BL      CHKREGSPCCONT
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
CASMTWORN

        BL      CHKREG
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #16
CASMONES2

        CMP     R10,#"#"
        BEQ     CASMDATAIM
        BL      CHKREG
        ORR     R1,R1,R0
        BL      AESPAC
        CMP     R10,#","
        BLEQ    CASMDATASHIFT
        B       CASMICHK

; Parse and encode register shift specifier (suitable for DP and SDT instructions;
;   also used for PKH with external qualification of shift type/amount)
;
; entry R1 = instruction being built
;       AELINE -> first character of shift specifier (ie. after comma, for typical usage)
; exit  R1[11:0] completed with shift type and shift amount (constant/register Rs)
CASMDATASHIFT

        STR     R14,[SP,#-4]!
        BL      AESPAC
        BIC     R0,R10,#" "
        LDRB    R2,[AELINE],#1
        BIC     R2,R2,#" "
        LDRB    R3,[AELINE],#1
        BIC     R3,R3,#" "
        ORR     R0,R0,R2,LSL #8
        ORR     R0,R0,R3,LSL #16
        MOV     R0,R0,LSL #8
        ADR     R2,CASMDATASHIFTTAB
        LDR     R3,[R2],#4
CASMDATASHIFT1

        TEQ     R3,#0
        BEQ     ERSYNT
        CMP     R0,R3,LSL #8
        LDRNE   R3,[R2],#4
        BNE     CASMDATASHIFT1
        BL      AESPAC
        MOVS    R3,R3,LSL #4
        MOV     R3,R3,LSR #24
        AND     R3,R3,#&F0
        ORR     R1,R1,R3
        LDRCC   PC,[SP],#4             ;RRX
        CMP     R10,#"#"
        BEQ     CASMDATASHIFTCONST
        TST     R1,#&0C000000
        BNE     ERASS2S                ;check for LDR/STR (or, indeed, any not dp)
        ORR     R1,R1,#&10
        BL      CHKREG
        LDR     R14,[SP],#4
        ORR     R1,R1,R0,LSL #8
        B       AESPAC                 ;t.c.o.
CASMDATASHIFTCONST

        BL      ASMEXPR
        ANDS    R2,R1,#&60
        BEQ     CASMDATASHIFTCONSTNOZEROCHK
        TEQ     R0,#0
        BEQ     ERASS2S                ;shift by zero not allowed for LSR, ASR, ROR
CASMDATASHIFTCONSTNOZEROCHK

        EOR     R2,R2,R2,LSR #1
        ANDS    R2,R2,#&20
        BNE     CASMDATASHIFTCONSTCHECK33
        CMP     R0,#32
        BCS     ERASS2S
CASMDATASHIFTCONSTCHECK33

        CMP     R0,#33
        BCS     ERASS2S
        AND     R0,R0,#31
        ORR     R1,R1,R0,LSL #7
        LDR     PC,[SP],#4
CASMDATASHIFTTAB

        =       "ASL",&10
        =       "LSL",&10
        =       "LSR",&12
        =       "ASR",&14
        =       "ROR",&16
        =       "RRX",&06
        =       0,0,0,0
CASMDATAIM
        ORR     R1,R1,#&2000000
        BL      ASMEXPR
        MOV     R2,#0
CASMDATAIM1

        CMP     R0,#&100
        BCC     CASMDATAIM2
        MOV     R0,R0,ROR #30
        ADDS    R2,R2,#1
        CMP     R2,#16
        BNE     CASMDATAIM1
        LDRB    R3,[ARGP,#BYTESM]
        TST     R3,#OPT_errors
        BNE     ERASS2
CASMDATAIM2

        ORR     R1,R1,R0
        ORR     R1,R1,R2,LSL #8
        B       CASMICHK

; Signed Most Significant Word Multiply opcodes
;
; Bits 27:20 have been set by parser to
;                &07500000

CASMSMMUL
        ORR     R1,R1,#&F000           ; non-accumulating, so no Ra
        B       CASMSMMLA
CASMSMMLS
        ORR     R1,R1,#&C0
CASMSMMLA
        LDRB    R10,[AELINE],#1
        BIC     R1,R1,#&F0000000
        ORR     R1,R1,#&10
        TEQ     R10,#"R"
        TEQNE   R10,#"r"
        ORREQ   R1,R1,#&20             ; rounding, not truncating
        SUBNE   AELINE,AELINE,#1
        BL      DOCOND
        B       CASMMLS

; Multiply [Long][and Accumulate|Subtract]
;
;   Opcode start Bits 24:21 have been set by parser
;   MUL          &00000000
;   MLA          &00200000
;   MLS          &00600000
;   SMU          &00C00000
;   SML          &00E00000
;   UMU          &00800000
;   UML          &00A00000

CASMMUL MOVNE   R3,#0                  ; R3=0 if no condition found
        ORR     R1,R1,#&90
        TST     R1,#&800000
        BNE     CASMMULL
        TST     R1,#&400000
        BNE     CASMMLS                ;MLS does not affect PSR
        LDRB    R10,[AELINE]
        CMP     R10,#"S"
        CMPNE   R10,#"s"
        ORREQ   R1,R1,#&100000
        ADDEQ   AELINE,AELINE,#1
CASMMLS BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #16       ;"Rd" is the normal Rn field
        BL      CHKREG
        AND     R4,R1,#&F0000
        CMP     R4,R0,LSL #16
        TSTEQ   R1,#&400000            ;for MUL/MLA (but not MLS/SMMxx)
        BEQ     ERASSMUL               ;  error if Rm same as Rd(Rn)

        ; SMMUL supports an implicit destination in UAL syntax,
        ;  in which case Rd is the same as Rn (first operand)
        BL      AESPAC
        CMP     R10,#","
        ORREQ   R1,R1,R0               ;complete 'Rn' (stored in normal Rm field)
        BEQ     CASMMUL3
        TST     R1,#&F000
        BEQ     ERCOMM
        AND     R2,R1,#&F0000
        ORR     R1,R1,R0,LSL #8
        ORR     R1,R1,R2,LSR #16       ;complete 'Rn' by replicating 'Rd'
        B       CASMICHK
CASMMUL3

        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #8        ;last reg is Rs
        TST     R1,#&600000
        BEQ     CASMMUL2               ;MUL requires only 2 operands
        TST     R1,#&F000
        BNE     CASMMUL2               ;SMMUL likewise
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0,LSL #12       ;last for MLA
CASMMUL2

        BL      AESPAC
        B       CASMICHK
CASMMULL

        TEQ     R3,#0
        SUBNE   AELINE,AELINE,#2       ;rewind to start of condition
        LDRB    R10,[AELINE],#1
        BIC     R1,R1,#&F0000000
        BIC     R10,R10,#" "
        TST     R1,#&200000
        MOVEQ   R14,#"L"               ;try <S|U>MUL...
        MOVNE   R14,#"A"               ;try <S|U>MLA...
        TEQ     R10,R14
        BEQ     CASMMULL1
        TST     R1,#&400000
        BEQ     ERASS1                 ;reject unsigned
        BIC     R1,R1,#&400000
        ;could be SMUA..|SMUS.. or SMLS..
        ;Add or Subtract?

        TEQ     R10,#"S"
        ORREQ   R1,R1,#&40
        TEQNE   R10,#"A"
        LDREQB  R10,[AELINE],#1
        BNE     ERASS1

        ;<SMU|SML><A|S>... check for
        ;  optional L(ong), D(ual) and optional (e)X(change)

        TST     R1,#&200000            ;opcode starts 'SML..?'
        BIC     R10,R10,#" "
        BEQ     CASMSMULAS             ;L(ong) is only for SML<A|S>, not SMUA|S
        ;SML<A|S>[L]D
        TEQ     R10,#"L"
        LDREQB  R10,[AELINE],#1
        ORREQ   R1,R1,#&400000
        BICEQ   R10,R10,#" "
CASMSMULAS
        TEQ     R10,#"D"
CASMMULD
        LDREQB  R10,[AELINE]
        BNE     ERASS1

        ; (D)ual 16x16 multiplication, optionally (L)ong and/or with (A)dd or (S)ubtracted
        BIC     R1,R1,#&80             ;leaves &10
        ORR     R1,R1,#&07000000
        BIC     R1,R1,#&00800000

        BIC     R10,R10,#" "
        TEQ     R10,#"X"
        ORREQ   R1,R1,#&20
        ADDEQ   AELINE,AELINE,#1

        TST     R1,#&200000
        ORREQ   R1,R1,#&F000           ;SMU<A|S>D, not long
        BEQ     CASMSMULREGS
        BIC     R1,R1,#&200000         ;this bit was just the parser indicating
                                       ;  the opcode prefix
        TST     R1,#&400000
        BEQ     CASMSMLASREGS          ;SML<A|S>D, not long
        ; Long
        BL      DOCOND
        B       CASMMULL4              ;SML<A|S>LD
CASMMULL1

        LDRB    R10,[AELINE],#1
        TST     R1,#&400000
        BIC     R10,R10,#" "
        BNE     CASMDSPMUL
        ; UMUL/UMLA...
CASMMULL2

        TEQ     R10,#"L"
        BNE     ERASS1
CASMMULL3

        BL      DOCOND
        LDRB    R10,[AELINE]
        BIC     R10,R10,#" "
        TEQ     R10,#"S"
        ORREQ   R1,R1,#&100000
        ADDEQ   AELINE,AELINE,#1
CASMMULL4

        BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12       ; RdLo
        BL      CHKREG
        ORR     R1,R1,R0,LSL #16       ; RdHi
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0               ; Rm
        TST     R1,#&01000000
        BNE     CASMMULL5              ; D(ual) instrs have no conflicts
        AND     R4,R1,#&F000
        AND     R10,R1,#&F0000
        TEQ     R0,R4,LSR #12          ; Is Rm=RdLo?
        TEQNE   R0,R10,LSR #16         ; Is Rm=RdHi?
        TEQNE   R4,R10,LSR #4          ; Is RdLo=RdHi?
        BEQ     ERASSMUL
CASMMULL5

        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0,LSL #8        ; Rs
        BL      AESPAC
        B       CASMICHK
CASMDSPMUL

        TST     R1,#&200000
        BNE     CASMDSPSMLA
CASMDSPSMUL

        TEQ     R10,#"W"
        TEQNE   R10,#"T"
        ORREQ   R1,R1,#&20
        TEQNE   R10,#"B"
        BNE     CASMMULL2
        BIC     R1,R1,#&10
        BIC     R1,R1,#&C00000
        ORR     R1,R1,#&1200000
        TEQ     R10,#"W"
        LDRB    R10,[AELINE],#1
        ORRNE   R1,R1,#&400000
        BIC     R10,R10,#" "
        TEQ     R10,#"T"
        ORREQ   R1,R1,#&40
        TEQNE   R10,#"B"
        BNE     ERASS1
CASMSMULREGS

        BL      DOCOND
        BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #16       ; Rd
        BL      CHKREG
        BL      AESPAC
        CMP     R10,#","
        BEQ     CASMSMULRS

        ;SMU<A|S>D and SMUL<W|B|T><B|T> support an implicit
        ;  destination register in UAL syntax, in which case
        ;  Rd == first operand register

        AND   R2,R1,#&F0000
        ORR   R1,R1,R0,LSL #8
        ORR   R1,R1,R2,LSR #16
        B     CASMICHK
CASMSMULRS

        ORR     R1,R1,R0               ; Rm
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #8        ; Rs
        BL      AESPAC
        B       CASMICHK
CASMDSPSMLA

        TEQ     R10,#"L"
        LDREQB  R10,[AELINE],#1
        BNE     CASMDSPSMLA2
        BIC     R10,R10,#" "
        TEQ     R10,#"D"
        ORREQ   R1,R1,#&400000
        BEQ     CASMMULD               ; SMLALD

        TEQ     R10,#"B"
        TEQNE   R10,#"T"
        SUBNE   AELINE,AELINE,#1
        BNE     CASMMULL3
        BIC     R1,R1,#&A00000
        B       CASMDSPSMLA22

CASMDSPSMLA2

        TEQ     R10,#"D"
        BICEQ   R1,R1,#&400000
        BEQ     CASMMULD               ; SMLAD
        TEQ     R10,#"W"
        BICNE   R1,R1,#&200000
        TEQNE   R10,#"B"
        TEQNE   R10,#"T"
        BNE     CASMMULL2
        BIC     R1,R1,#&C00000
CASMDSPSMLA22

        BIC     R1,R1,#&10
        ORR     R1,R1,#&1000000
        TEQ     R10,#"T"
        ORREQ   R1,R1,#&20
        LDRB    R10,[AELINE],#1
        BIC     R10,R10,#" "
        TEQ     R10,#"T"
        ORREQ   R1,R1,#&40
        TEQNE   R10,#"B"
        BNE     ERASS1
CASMSMLASREGS
        BL      DOCOND
        BL      CHKREGSPC
        TST     R1,#&400000
        BEQ     CASMDSPSMLA3
        ORR     R1,R1,R0,LSL #12       ; RdLo
        BL      CHKCOM
        BL      CHKREG
CASMDSPSMLA3

        ORR     R1,R1,R0,LSL #16       ; Rd / RdHi
        BL      CHKCOM
        BL      CHKREG
        BL      CHKCOM
        ORR     R1,R1,R0               ; Rm
        BL      CHKREG
        ORR     R1,R1,R0,LSL #8        ; Rs
        TST     R1,#&400000
        BNE     CASMDSPSMLA5
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0,LSL #12       ; Rn
CASMDSPSMLA4

        BL      AESPAC
        B       CASMICHK
CASMDSPSMLA5

        AND     R4,R1,#&F000
        AND     R14,R1,#&F0000
        TEQ     R4,R14,LSR #4          ; Is RdLo=RdHi?
        BEQ     ERASSMUL
        B       CASMDSPSMLA4

CASMSVC BL      AESPAC
        CMP     R10,#"#"
        SUBNE   AELINE,AELINE,#1
CASMSWI STR     R1,[SP,#-4]!
        BL      EXPR
        TEQ     TYPE,#0
        BNE     CASMSWI1
        MOV     R0,#0
        STRB    R0,[CLEN]
        ADD     R1,ARGP,#STRACC
        SWI     OS_SWINumberFromString
        B       CASMSWI2
CASMSWI1

        BLMI    SFIX
CASMSWI2

        LDR     R1,[SP],#4
        BIC     R0,R0,#&FF000000
        ORR     R1,R1,R0
        B       CASMICHK
CASMCP  MOVNE   R3,#0                  ; R3=0 if no condition found
        ANDS    R10,R1,#&F000000
        BEQ     CASMCDP
        CMP     R10,#&8000000
        BHS     CASMCPDT
CASMCPRT

        TST     R10,#&4000000
        BEQ     CASMMRRC
        TST     R10,#&2000000
        TEQEQ   R3,#0
        LDREQB  R14,[AELINE]
        BICEQ   R14,R14,#" "
        TEQEQ   R14,#"R"
        BEQ     CASMMCRR
        TEQ     R3,#0
        LDREQB  R14,[AELINE]
        TEQEQ   R14,#"2"
        ORREQ   R1,R1,#&F0000000
        ADDEQ   AELINE,AELINE,#1
        ORR     R1,R1,#&10
        TST     R10,#&2000000
        ORRNE   R1,R1,#&100000
        BL      CHKCOPROSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #8
        SUB     AELINE,AELINE,#1
        BL      ASMEXPR
        CMP     R0,#7
        BHI     ERASS2C
        ORR     R1,R1,R0,LSL #21
        SUB     AELINE,AELINE,#1
        BL      CHKCOM
        BL      CHKREG
CASMCPCOMMON

        ORR     R1,R1,#&E000000
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        BL      CHKCPREG
        ORR     R1,R1,R0,LSL #16
        BL      CHKCOM
        BL      CHKCPREG
        ORR     R1,R1,R0
        BL      AESPAC
        TEQ     R10,#","
        BNE     CASMICHK
        BL      ASMEXPR
        CMP     R0,#7
        BHI     ERASS2C
        ORR     R1,R1,R0,LSL #5
        B       CASMICHK
CASMMRRC

        TEQ     R3,#0
        SUBNE   AELINE,AELINE,#2
        LDRB    R10,[AELINE],#1
        BIC     R10,R10,#" "
        TEQ     R10,#"C"
        BNE     ERASS1
        BIC     R1,R1,#&FF00000
        ORR     R1,R1,#&C500000
        B       CASMCPRRT
CASMMCRR

        ADD     AELINE,AELINE,#1
        BIC     R1,R1,#&FF00000
        ORR     R1,R1,#&C400000
CASMCPRRT

        BIC     R1,R1,#&F0000000
        BL      DOCOND
        BL      CHKCOPROSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #8
        SUB     AELINE,AELINE,#1
        BL      ASMEXPR
        CMP     R0,#15
        BHI     ERASS2C
        ORR     R1,R1,R0,LSL #4
        SUB     AELINE,AELINE,#1
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0,LSL #16
        BL      CHKCOM
        BL      CHKCPREG
        ORR     R1,R1,R0
        BL      AESPAC
        B       CASMICHK
CASMCDP
        TEQ     R3,#0
        LDREQB  R10,[AELINE]
        TEQEQ   R10,#"2"
        ORREQ   R1,R1,#&F0000000
        ADDEQ   AELINE,AELINE,#1
        BL      CHKCOPROSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #8
        SUB     AELINE,AELINE,#1
        BL      ASMEXPR
        CMP     R0,#15
        BHI     ERASS2C
        ORR     R1,R1,R0,LSL #20
        SUB     AELINE,AELINE,#1
        BL      CHKCOM
        BL      CHKCPREG
        B       CASMCPCOMMON
CASMCPDT

        ORRNE   R1,R1,#&100000
        ORR     R1,R1,#&C000000
        ORR     R1,R1,#&800000
        LDRB    R10,[AELINE]
        TEQ     R3,#0
        TEQEQ   R10,#"2"
        ORREQ   R1,R1,#&F0000000
        LDREQB  R10,[AELINE,#1]!
        TEQ     R10,#"L"
        TEQNE   R10,#"l"
        ORREQ   R1,R1,#&400000
        ADDEQ   AELINE,AELINE,#1
        BL      CHKCOPROSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #8
        BL      CHKCPREG
        B       CASMLDSTCOMMON
CASMARM6

        ANDS    R10,R1,#&0F000000
        BEQ     CASMSWP
        CMP     R10,#&01000000
        BHI     CASMMRS
CASMMSR
        ORR     R1,R1,#&F000
        ORR     R1,R1,#&200000
        BL      AESPAC
        TEQ     R10,#"A"
        TEQNE   R10,#"a"
        BEQ     CASMMSRA
        MOV     R2,AELINE              ;remember in case of rewinding
        BL      CHKPSR
        LDREQB  R10,[AELINE],#1
        TEQEQ   R10,#"_"
        BNE     CASMMSRBANK
CASMMSR1
        LDRB    R10,[AELINE],#1
        ORR     R10,R10,#" "
        TEQ     R10,#"c"
        ORREQ   R1,R1,#&10000
        BEQ     CASMMSR1
        TEQ     R10,#"x"
        ORREQ   R1,R1,#&20000
        BEQ     CASMMSR1
        TEQ     R10,#"s"
        ORREQ   R1,R1,#&40000
        BEQ     CASMMSR1
        TEQ     R10,#"f"
        ORREQ   R1,R1,#&80000
        BEQ     CASMMSR1

        TST     R1,#&400000
        BEQ     CASMMSR2
        CMP     R10,#"a"
        RSBCSS  R0,R10,#"z"
        BCC     CASMMSR2
        ;invalid SPSR field, try banked register
        LDRB    R10,[R2,#-1]
        BIC     R1,R1,#&F0000
        MOV     AELINE,R2              ;rewind
CASMMSRBANK

        BIC     R1,R1,#1:SHL:22
        ORR     R1,R1,#&200
        BL      CASMBANKEDREG
        SUB     AELINE,AELINE,#1
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0
        BL      AESPAC
        B       CASMICHK
CASMMSR2

        SUB     AELINE,AELINE,#1
        BL      CHKCOM
        TEQ     R10,#"#"
        BEQ     CASMDATAIM
        BL      CHKREG
        ORR     R1,R1,R0
        BL      AESPAC
        B       CASMICHK
CASMMSRA

        BL      CHKPSR
        LDREQB  R10,[AELINE],#1
        TEQEQ   R10,#"_"
        BNE     ERSYNT
        TST     R1,#&400000            ;SPSR?
        BNE     CASMMSR1
CASMMSRA1
        LDRB    R10,[AELINE],#1
        ORR     R10,R10,#" "
        TEQ     R10,#"n"
        LDREQB  R10,[AELINE],#1
        BEQ     CASMMSRAF
        TEQ     R10,#"g"
        ORREQ   R1,R1,#&40000
        BEQ     CASMMSRA1
        B       CASMMSR2
CASMMSRAF

        ORR     R10,R10,#" "
        TEQ     R10,#"z"
        LDREQB  R10,[AELINE],#1
        ORREQ   R10,R10,#" "
        TEQEQ   R10,#"c"
        LDREQB  R10,[AELINE],#1
        ORREQ   R10,R10,#" "
        TEQEQ   R10,#"v"
        LDREQB  R10,[AELINE],#1
        ORR     R10,R10,#" "
        TEQEQ   R10,#"q"
        ORREQ   R1,R1,#&80000
        BEQ     CASMMSRA1
        B       ERSYNT

CASMMRS
        BIC     R1,R1,#&2000000
        BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
        BL      CHKPSR
        ADRL    R14,CASMICHK
        BNE     CASMMRSBANK
        ;valid PSR, but need to check not a substring of SPSR_<mode>
        ORR     R1,R1,#&F0000
        TST     R1,#&400000
        LDRNEB  R10,[AELINE]
        BEQ     AESPAC                 ; t.c.o.
        TEQ     R10,#"_"
        BNE     AESPAC                 ; t.c.o.
        BIC     R1,R1,#&F0000
        LDRB    R10,[AELINE,#-4]
        SUB     AELINE,AELINE,#3
CASMMRSBANK

        BIC     R1,R1,#1:SHL:22
        ORR     R1,R1,#&200
        B       CASMBANKEDREG          ; t.c.o.
; entry R10 = first char of possible PSR name
;       AELINE -> second char
; exit  R2 preserved
; EQ if valid PSR name found, <A|C|S>PSR
;       AELINE -> first char after PSR name
; NE if not, R10/AELINE unchanged
CHKPSR  BIC     R0,R10,#" "
        TEQ     R0,#"S"
        ORREQ   R1,R1,#&400000
        TEQNE   R0,#"C"
        TEQNE   R0,#"A"
        LDREQB  R0,[AELINE]
        MOVNE   PC,R14
        TEQ     R0,#"P"
        TEQNE   R0,#"p"
        LDREQB  R0,[AELINE,#1]
        MOVNE   PC,R14
        TEQ     R0,#"S"
        TEQNE   R0,#"s"
        LDREQB  R0,[AELINE,#2]
        MOVNE   PC,R14
        TEQ     R0,#"R"
        TEQNE   R0,#"r"
        ADDEQ   AELINE,AELINE,#3
        MOV     PC,R14
CASMSWP
        ORR     R1,R1,#&1000000
        ORR     R1,R1,#&90
        LDRB    R10,[AELINE]
        TEQ     R10,#"B"
        TEQNE   R10,#"b"
        ORREQ   R1,R1,#&400000
        ADDEQ   AELINE,AELINE,#1
        BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
        BL      CHKREG
        ORR     R1,R1,R0
        BL      CHKCOM
        TEQ     R10,#"["
        BNE     ERASSB4
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #16
        BL      AESPAC
        TEQ     R10,#"]"
        BNE     ERASSB1
        BL      AESPAC
        B       CASMICHK

; entry R10 = first char of banked register name
;       AELINE->second char
; exit  R1 updated with completed R/M1/M fields
;       R10 = first non-space char following register name
;       AELINE->beyond this char
;       Does not return if not a valid banked register
CASMBANKEDREG
        STR     R14,[SP,#-4]!
        ; try for LR and R0-R15
        LDRB    R0,[AELINE],#1         ;read second char
        BIC     R10,R10,#" "
        TEQ     R10,#"L"
        BIC     R2,R0,#" "
        TEQEQ   R2,#"R"
        MOVEQ   R0,#&E
        BEQ     CASMBANKED2
        TEQ     R10,#"R"
        BNE     CASMBANKEDNR
        SUBS    R0,R0,#"0"
        RSBCSS  R2,R0,#9
        BCC     ERASS3
        ; if '1' try for second digit (R10-R14 valid)
        TEQ     R0,#1
        LDREQB  R0,[AELINE],#1
        BNE     CASMBANKED1
        SUBS    R0,R0,#"0"
        RSBCSS  R2,R0,#4
        BCC     ERASS3                 ;also rejects R1, not banked
        ADD     R0,R0,#10
        B       CASMBANKED1
CASMBANKEDNR
        ; try for ELR, SP and SPSR
        LDRB    R3,[AELINE],#1
        TEQ     R10,#"E"
        TEQEQ   R2,#"L"
        BIC     R0,R3,#" "
        TEQEQ   R0,#"R"
        MOVEQ   R0,#&1E                ;denotes ELR temporarily
        BEQ     CASMBANKED2            ;ELR_<mode> where mode must be hyp
        TEQ     R10,#"S"
        TEQEQ   R2,#"P"
        BNE     ERASS3
        TEQ     R3,#"_"
        MOVEQ   R0,#&D
        STREQ   R0,[SP,#-4]!           ;remember register number
        BEQ     CASMBANKED2U
        TEQ     R0,#"S"
        LDREQB  R10,[AELINE],#1
        BICEQ   R10,R10,#" "
        TEQEQ   R10,#"R"
        BNE     ERASS3
        MOV     R0,#&10                ;SPSR_<mode>
CASMBANKED1
        CMP     R0,#15
        CMPNE   R0,#7
        BLS     ERASS3
CASMBANKED2
        LDRB    R10,[AELINE],#1
        STR     R0,[SP,#-4]!           ;remember register number
        CMP     R10,#"_"
CASMBANKED2U
        LDREQB  R10,[AELINE],#1
        LDREQB  R2,[AELINE],#1
        BNE     ERASS3
        LDRB    R3,[AELINE],#1
        BIC     R0,R10,#" "
        BIC     R2,R2,#" "
        BIC     R3,R3,#" "
        ORR     R0,R0,R2,LSL #8
        ORR     R0,R0,R3,LSL #16

        ; match mode suffix
        ADR     R2,CASMBANKTAB
        LDR     R3,[R2],#4
        MOV     R0,R0,LSL #8
CASMBANKED3
        TEQ     R3,#0
        BEQ     ERSYNT
        CMP     R0,R3,LSL #8
        LDRNE   R3,[R2],#4
        BNE     CASMBANKED3

        LDR     R0,[R13],#4            ;retrieve register number

        ; special cases
        MOV     R2,#&1E
        CMP     R3,#&1E000000
        MOVHS   R2,#&E
        TEQ     R0,R2
        BEQ     ERASS3                 ;check (E)LR appropriate for mode

        TEQ     R0,#&10
        BEQ     CASMBANKSPSR
        AND     R0,R0,#&F              ;ELR -> LR

        SUBS    R0,R0,#13
        RSBCCS  R2,R3,#&10000000
        BCC     ERASS3                 ;R8-R12 only in _usr and _fiq
        TST     R3,#&10000000
        ADDEQ   R0,R0,#13-8
        EORNE   R0,R0,#1               ;LR encoded before SP for higher modes!

        ADD     R0,R0,R3,LSR #24
        B       CASMBANKENC
CASMBANKSPSR

        MOVS    R0,R3,LSR #24
        BEQ     ERASS3                 ;no SPSR_usr
        TST     R0,#&10
        ADDEQ   R0,R0,#&06             ;map to same M1:M value as LR_<mode>
        ORR     R1,R1,#&400000         ;set 'R' bit
CASMBANKENC

        AND     R2,R0,#&F
        TST     R0,#&10
        ORR     R1,R1,R2,LSL #16
        ORRNE   R1,R1,#&100
        LDR     R14,[SP],#4
        B       AESPAC                 ;t.c.o.

CASMBANKTAB
        =       "USR",&00
        =       "FIQ",&08
        =       "IRQ",&10
        =       "SVC",&12
        =       "ABT",&14
        =       "UND",&16
        =       "MON",&1C
        =       "HYP",&1E
        =       0,0,0,0

CASMFPTWOOP

        ORR     R1,R1,#&8000
CASMFPTHREEOP

        ORR     R1,R1,#&100
        ORR     R1,R1,#&E000000
        BL      DOFPPREC
        BL      DOFPROUND
        BL      CHKFPREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
        TST     R1,#&8000
        BNE     CASMFPDO1
        BL      CHKFPREG
CASMFPCOMMON

        ORR     R1,R1,R0,LSL #16
        BL      CHKCOM
CASMFPDO1

        TEQ     R10,#"#"
        BEQ     CASMFPIMM
        BL      CHKFPREG
        ORR     R1,R1,R0
        BL      AESPAC
        B       CASMICHK
CASMFPIMM

        ORR     R1,R1,#&8
        STR     R1,[SP,#-4]!
        BL      EXPR
        TEQ     TYPE,#0
        BEQ     ERTYPEINT
        BLPL    IFLT
        ADR     R4,CASMFPIMMTBEND
        MOV     R5,#7
 [ FPOINT=0
        ORR     FGRD,FSIGN,FACCX
 ]
CASMFPIMM1

 [ FPOINT=0
        LDMDB   R4!,{R6,R7}
        TEQ     R6,FACC
        TEQEQ   R7,FGRD
 ELIF FPOINT=1
        LDFS    F1,[R4,#-4]!
        CMF     FACC,F1
 ELIF FPOINT=2
        FLDD    D1,[R4,#-8]!
        FCMPD   FACC,D1
        FMRX    PC,FPSCR
 |
        ! 1, "Unknown FPOINT setting"
 ]
        BEQ     CASMFPGOTIMM
        SUBS    R5,R5,#1
        BGE     CASMFPIMM1
        LDRB    R0,[ARGP,#BYTESM]
        TST     R0,#OPT_errors
        BNE     ERASS2
        MOV     R5,#0
CASMFPGOTIMM

        LDR     R1,[SP],#4
        ORR     R1,R1,R5
        B       CASMICHK
CASMFPIMMTB

 [ FPOINT=0
        &       &00000000
        =       &00,0,0,0              ; 0
        &       &80000000
        =       &81,0,0,0              ; 1
        &       &80000000
        =       &82,0,0,0              ; 2
        &       &C0000000
        =       &82,0,0,0              ; 3
        &       &80000000
        =       &83,0,0,0              ; 4
        &       &A0000000
        =       &83,0,0,0              ; 5
        &       &80000000
        =       &80,0,0,0              ; 0.5
        &       &A0000000
        =       &84,0,0,0              ; 10
 ELIF FPOINT=1
        ;       Aasm doesn't seem to like comma-separated FP constants
        DCFS    0
        DCFS    1
        DCFS    2
        DCFS    3
        DCFS    4
        DCFS    5
        DCFS    0.5
        DCFS    10
 ELIF FPOINT=2
        ; No way of directly comparing float & double values, so just store as doubles
        DCFD    0
        DCFD    1
        DCFD    2
        DCFD    3
        DCFD    4
        DCFD    5
        DCFD    0.5
        DCFD    10
 |
        ! 1, "Unknown FPPOINT setting"
 ]
CASMFPIMMTBEND


CASMFPDT

        AND     R10,R1,#&F000000
        ORR     R1,R1,#&C000000
        TST     R10,#&4000000
        ORRNE   R1,R1,#&100000
        TST     R10,#&8000000
        ORRNE   R1,R1,#&200
        ORREQ   R1,R1,#&100
        BNE     CASMLFM
CASMLDF ORR     R1,R1,#&800000
        BL      DOFPPRECDT
        BL      CHKFPREGSPC
        B       CASMLDSTCOMMON
CASMLFM LDRB    R10,[AELINE]
        LDRB    R0,[AELINE,#1]
        BIC     R10,R10,#" "
        BIC     R0,R0,#" "
        TEQ     R10,#"E"
        TEQEQ   R0,#"A"
        BEQ     CASMLFMEA
        TEQ     R10,#"F"
        TEQEQ   R0,#"D"
        BEQ     CASMLFMFD
        ORR     R1,R1,#&800000
        BL      CHKFPREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
        BL      DOLFMCOUNT
        BL      CHKCOM
        B       CASMLDSTCOMMON2

;       LFMFD! ->  LFM [],#        SFMFD! -> SFM [,#-]!
;       LFMFD  ->  LFM []          SFMFD  -> SFM [,#-]
;       LFMEA! ->  LFM [,#-]!      SFMEA! -> SFM [],#
;       LFMEA  ->  LFM [,#-]       SFMEA  -> SFM []
CASMLFMFD

        MOV     R4,#1
        B       CASMLFMSTK
CASMLFMEA

        MOV     R4,#0
CASMLFMSTK

        TST     R1,#&100000
        EORNE   R4,R4,#1
        ADD     AELINE,AELINE,#2
        STR     R4,[SP,#-4]!
        BL      CHKFPREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
        BL      DOLFMCOUNT
        ADD     R0,R0,R0,LSL #1
        ORR     R1,R1,R0
        BL      CHKCOM
        TEQ     R10,#"["
        BNE     ERASSB4
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #16
        BL      AESPAC
        TEQ     R10,#"]"
        BNE     ERASSB1
        BL      AESPAC
        TEQ     R10,#"!"
        LDREQ   R4,[SP],#4
        ORREQ   R4,R4,#2
        STREQ   R4,[SP,#-4]!
        BLEQ    AESPAC
        LDR     R4,[SP],#4
        ADR     R0,CASMLFMTB
        LDR     R0,[R0,R4,LSL #2]
        ORR     R1,R1,R0
        TST     R1,#&80
        BICNE   R1,R1,#&FF
        B       CASMICHK
CASMLFMTB

        &       &01800080
        &       &01000000
        &       &00A00000
        &       &01200000

DOLFMCOUNT

        STR     R14,[SP,#-4]!
        SUB     AELINE,AELINE,#1
        BL      ASMEXPR
        SUB     AELINE,AELINE,#1
        CMP     R0,#4
        BHI     ERSYNT
        TEQ     R0,#0
        BEQ     ERSYNT
        TST     R0,#2
        ORRNE   R1,R1,#&400000
        TST     R0,#1
        ORRNE   R1,R1,#&8000
        LDR     PC,[SP],#4
CASMFPRT

        ORR     R1,R1,#&E000000
        ORR     R1,R1,#&110
        ANDS    R10,R1,#&F00000
        BEQ     CASMFLT
        CMP     R10,#&800000
        BHS     CASMCMF
        CMP     R10,#&200000
        BHS     CASMWRFSC
CASMFIX BL      DOFPROUND
        BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
        BL      CHKFPREG
        ORR     R1,R1,R0
        BL      AESPAC
        B       CASMICHK
CASMFLT BL      DOFPPREC
        BL      DOFPROUND
        BL      CHKFPREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #16
        BL      CHKREG
        ORR     R1,R1,R0,LSL #12
        BL      AESPAC
        B       CASMICHK
CASMWRFSC

        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      AESPAC
        B       CASMICHK
CASMCMF ORR     R1,R1,#&F000
        LDRB    R10,[AELINE]
        TEQ     R10,#"E"
        TEQNE   R10,#"e"
        BNE     CASMCMF1
        LDRB    R10,[AELINE,#-1]
        TEQ     R10,#"F"
        TEQNE   R10,#"f"
        ADDEQ   AELINE,AELINE,#1
        ORREQ   R1,R1,#&400000
        BICEQ   R1,R1,#&F0000000
        BLEQ    DOCOND
CASMCMF1

        BL      CHKFPREGSPC
        B       CASMFPCOMMON

CASMBX  LDRB    R10,[AELINE,#1]!       ; first char after X
        TEQ     R10,#"J"
        TEQNE   R10,#"j"
        ADDEQ   AELINE,AELINE,#1
        MOVEQ   R1,#&20                ; BXJ
        MOVNE   R1,#&10                ; BX
CASMBX1 BL      DOCOND
        ANDNE   R2,R1,#&F0
        MOVEQ   R2,#0
        TEQ     R2,#&30                ; was it BLX? BLX supports an immediate operand (label)
        BEQ     CASMBLX                ;   but BX and BXJ do not
        BL      CHKREGSPC
CASMBXR ORR     R1,R1,R0
        LDR     R0,CASMBXI
        ORR     R1,R1,R0
        BL      AESPAC
        B       CASMICHK
CASMBXI &       &012FFF00              ; bits [7:4] denote branch type, and are already in R1
CASMBLX
        BL      AESPAC
        BL      GETREG                 ; distinguish BLX <reg> from BLX <probably imm24>
        BEQ     CASMBXR
        ; BX|BLX|BXJ
        SUB     AELINE,AELINE,#1
        STR     AELINE,[SP,#-4]!
        BL      EXPR                   ; read an expression
        STMFD   SP!,{R0,TYPE,R10,AELINE}
        LDR     AELINE,[SP,#16]
        BL      FACTOR                 ; go back and read a factor
        BEQ     CASMBLXL               ; not a number? go with expression
        BLMI    INTEGB
        BL      AESPAC
        LDR     R14,[SP,#12]
        TEQ     R14,AELINE             ; is there just a factor following?
        BNE     CASMBLXL               ; no -> use expression result
        ADD     SP,SP,#20
        CMP     R0,#15                 ; and is it <= 15
        LDRLS   R1,CASMBLXI            ; yes -> BLX <reg>
        BHI     CASMBLXL2              ; no -> treat it as a label
        ORR     R1,R1,R0
        B       CASMICHK
CASMBLXI

        &       &E12FFF30
CASMBLXL

        LDMFD   SP!,{R0,TYPE,R10,AELINE}
        ADD     SP,SP,#4
        TEQ     TYPE,#0
        BEQ     ERTYPEINT
        BLMI    INTEGB
CASMBLXL2

        BL      GET2PC
        ADD     R3,R2,#8-1             ;-1 deals with unaligned destination
        SUB     R3,R0,R3
        MOVS    R3,R3,LSR #2
        BIC     R3,R3,#&FF000000
        ORR     R1,R3,#&FA000000
        ORRCS   R1,R1,#&01000000       ; half-word alignment (Thumb)
        B       CASMICHK

CASMB   TEQ     R1,#"I"                ; for BIC
        TEQNE   R1,#"K"                ; for BKPT
        TEQNE   R1,#"F"                ; for BFC/BFI
        BEQ     CASM2A
        BL      ALIGN
        LDRB    R10,[AELINE]
        MOV     R1,#&B000000
        BIC     R10,R10,#" "
        TEQ     R10,#"X"
        BEQ     CASMBX
        TEQ     R10,#"L"
        BNE     CASMB1
        ; BL<cond>[X]
        ADD     AELINE,AELINE,#1
        BL      DOCOND                 ;BL<cc>?
        BEQ     CASMB2                 ;if BL and a cond then ok
        BIC     R10,R10,#" "
        TEQ     R10,#"X"               ;unconditional, might be BLX
        ADDEQ   AELINE,AELINE,#1
        MOVEQ   R1,#&30
        BEQ     CASMBX1
        SUB     AELINE,AELINE,#1       ;unread L
        BIC     R1,R1,#&F0000000       ;remove any cond added so far
        BL      DOCOND
        BICEQ   R1,R1,#&1000000        ;B(Lx) recognised - must be branch
        BEQ     CASMB2
        ADD     AELINE,AELINE,#1       ;finally BL okay!
        B       CASMB2
CASMB1  MOV     R1,#&A000000           ;not BL: try branch
        BL      DOCOND
CASMB2  BL      ASMEXPR
        BL      GET2PC
        ADD     R3,R2,#8-3             ;-3 deals with unaligned destination
        SUBS    R3,R0,R3               ; negative offset?
        ANDMI   R2,R3,#&FE000000       ; yes.. get hi bits
        EORPL   R2,R3,#&FE000000       ; no.. toggle hi bits i.e. FE if was 0
        MOV     R2,R2,LSR #25          ; clear remaining bits
        TEQ     R2,#&7F                ; test OK state
        BNE     ERASS2A                ; Bad Address offset
        MOV     R3,R3,LSR #2
        BIC     R3,R3,#&FF000000
        ORR     R1,R1,R3
CASMICHK

        MOV     R2,#4                  ;assemble instruction sized thing
CASMXCHK

        BL      ASMCHK                 ;check syntax and assemble R2 size
CASMX   LDR     R3,[ARGP,#ASSPC]
        LDRB    R0,[ARGP,#BYTESM]
        TST     R0,#OPT_asm_to_O
        MOVEQ   R4,R3
        LDRNE   R4,[ARGP,#ASSPC-4]     ;O%
        CMP     R2,#5
        ADDCS   R5,ARGP,#STRACC
        SUBCS   R6,R2,R5               ;length of string
        MOVCC   R6,R2
        TST     R0,#OPT_check_limit
        BEQ     CASMXNOLIMIT
        ADD     R5,R4,R6
        LDR     R7,[ARGP,#ASSPC-16]    ;L%
        CMP     R5,R7
        BHI     ERASS2LIM
CASMXNOLIMIT

        CMP     R2,#5
        BCC     CASMXNOTSTRING
        ADD     R5,ARGP,#STRACC
        MOV     R2,R6
        CMP     R2,#5
        LDRCC   R1,[R5]
        BCC     CASMXNOTSTRING
        MOV     R7,R4
CASMXSTRING

        LDRB    R1,[R5],#1
        STRB    R1,[R7],#1
        SUBS    R6,R6,#1
        BNE     CASMXSTRING
        B       CASMXPLACED
CASMXNOTSTRING

        CMP     R2,#0
        BEQ     CASMXPLACED
        STRB    R1,[R4]
        CMP     R2,#1
        BEQ     CASMXPLACED
        MOV     R5,R1,LSR #8
        STRB    R5,[R4,#1]
        CMP     R2,#2
        BEQ     CASMXPLACED
        MOV     R5,R1,LSR #16
        STRB    R5,[R4,#2]
        CMP     R2,#3
        MOV     R5,R1,LSR #24
        STRNEB  R5,[R4,#3]
CASMXPLACED

        TST     R0,#OPT_asm_to_O
        ADDNE   R4,R4,R2
        STRNE   R4,[ARGP,#ASSPC-4]
        TST     R0,#OPT_list
        BEQ     CASMXN
        STR     R10,[SP,#-4]!
        MOV     R10,R3
        BL      WORDHX
        SWI     OS_WriteI+" "
        MOV     R10,R1
        CMP     R2,#5
        BCS     CASMBYTPRINT
        STMFD   SP!,{R0,R9}
        MOVS    R9,R2,LSL #3
        SUB     R9,R9,#4
        LDMEQFD SP!,{R0,R9}
        BLNE    WORDLP
        RSB     R0,R2,#4
        MOVS    R0,R0,LSL #1
CASMXPAD1

        BEQ     CASMX1
        SWI     OS_WriteI+" "
        SUBS    R0,R0,#1
        B       CASMXPAD1
CASMXCOM

        BL      ASMCHK2
        B       CASMX
CASMBYTPRINT

        SWI     OS_WriteS
        =       "        ",0
        ALIGN
;print bytes
CASMX1  LDR     R10,[SP],#4
        MOV     TYPE,#0
        SWI     OS_WriteI+" "
        LDRB    R0,[LINE],#1
        CMP     R0,#"."
        BNE     CASMXT
        MOV     R4,#0
        MOV     R7,#0
CASMXL  BL      TOKOUT
        ADD     R4,R4,#1
        LDRB    R0,[LINE],#1
        CMP     R0,#":"
        CMPNE   R0,#";"
        CMPNE   R0,#"\\"
        CMPNE   R0,#TREM
        CMPNE   R0,#" "
        BHI     CASMXL
        RSBS    R0,R4,#10
        MOVLS   R0,#1
        BL      SPCSWC
        SUB     LINE,LINE,#1
        B       CASMXTS
CASMXT  CMP     R0,#":"
        CMPNE   R0,#13
        BEQ     CASMX3
        SWI     OS_WriteS
        =       "          ",0
        ALIGN
        SUB     LINE,LINE,#1
CASMXTS LDRB    R0,[LINE],#1
        CMP     R0,#" "
        BEQ     CASMXTS
        TEQ     R0,#":"
        TEQNE   R0,#13
        BEQ     CASMX3
CASMX2  MOV     R7,#0
        BL      TOKOUT
        LDRB    R0,[LINE],#1
        CMP     LINE,AELINE
        BCC     CASMX2
CASMX3  SWI     OS_NewLine
CASMXN  ADD     R3,R3,R2
        STR     R3,[ARGP,#ASSPC]
        MOV     LINE,AELINE
        TEQ     R10,#13
        BNE     CASM
        LDRB    R10,[LINE],#1
        CMP     R10,#&FF
        BEQ     CLRSTK                 ;check for program end
        ADD     LINE,LINE,#2
        LDR     R4,[ARGP,#ESCWORD]
        CMP     R4,#0
        BLNE    DOEXCEPTION
        B       CASM
;assembler directives
CASMOPS MOV     R0,R2,LSR #24
        CMP     R0,#&F1
        BEQ     CASMEQU
        BCS     CASMDCB
;&F0 = OPT
        BL      ASMEXPR
        BL      ASMCHK
        AND     R0,R0,#OPT_mask
        STRB    R0,[ARGP,#BYTESM]
        MOV     R2,#0
        B       CASMX
CASMEQU LDRB    R10,[AELINE],#1
        BIC     R10,R10,#" "
        CMP     R10,#"S"
        BEQ     CASMEQUS
        CMP     R10,#"D"
        BEQ     CASMEQUD
        CMP     R10,#"B"
        BEQ     CASMEQUB
        CMP     R10,#"F"
        BEQ     CASMDCF
        CMP     R10,#"W"
        BNE     ERASS1EQU
CASMDCW BL      ASMEXPR
        MOV     R2,#2
        B       CASMEQUB2
CASMEQUB

        BL      ASMEXPR
CASMEQUB1

        MOV     R2,#1
CASMEQUB2

        MOV     R1,IACC
        B       CASMXCHK
CASMDCD CMP     R0,#&F5
        BEQ     CASMADR
        BCS     CASMALI
CASMEQUD

        BL      ASMEXPR
        MOV     R1,IACC
        B       CASMICHK
CASMEQUS

        BL      EXPR
        TEQ     TYPE,#0
        BNE     ERTYPESTR
CASMEQUS1

        B       CASMXCHK
CASMDCB CMP     R0,#&F3
        BEQ     CASMDCW
        BCS     CASMDCD
        BL      EXPR
        TEQ     TYPE,#0
        BEQ     CASMEQUS1
        BLMI    SFIX
        B       CASMEQUB1
CASMADR
;       LDRB    R10,[AELINE]
;       BIC     R2,R10,#" "
;       CMP     R2,#"L"
;       ADDEQ   AELINE,AELINE,#1
        MOV     R1,#&000F0000
        ORR     R1,R1,#&02000000
        BL      ALIGN                  ;definitely an opcode, so align
        BL      DOCOND
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        SUB     AELINE,AELINE,#1
        BL      ASMEXPR
        BL      ASMCHK
        BL      GET2PC
        ADD     R3,R2,#8
        SUBS    R0,R0,R3
        ORRPL   R1,R1,#&00800000
        ORRMI   R1,R1,#&00400000
        RSBMI   R0,R0,#0
        MOV     R2,#0
        B       CASMDATAIM1
CASMALI CMP     R0,#&F7
        BEQ     CASMDCF
        BHI     CASMNOP
        LDRB    R10,[AELINE],#1
        BIC     R2,R10,#" "
        CMP     R2,#"G"
        LDRB    R10,[AELINE],#1
        BIC     R2,R10,#" "
        CMPEQ   R2,#"N"
        BNE     ERASS1
        BL      AESPAC
        BL      ALIGN
        MOV     R2,#0
        B       CASMXCHK
CASMDCF LDRB    R10,[AELINE],#1
        BIC     R4,R10,#" "
        CMP     R4,#"D"
        STR     R4,[SP,#-4]!
        BNE     CASMDCF2
        LDRB    R10,[AELINE]
        CMP     R10,#"."
        BNE     CASMDCF2
        LDRB    R2,[AELINE,#1]
        ORR     R2,R2,#" "
        LDRB    R4,[AELINE,#2]
        BIC     R4,R4,#" "
        LDRB    R10,[AELINE,#3]
        BIC     R10,R10,#" "
        CMP     R2,#"f"
        CMPEQ   R4,#"P"
        CMPEQ   R10,#"A"
        ADDEQ   AELINE,AELINE,#4
        BEQ     CASMDCF2
        CMP     R2,#"v"
        CMPEQ   R4,#"F"
        CMPEQ   R10,#"P"
        STREQ   R2,[SP]                 ; Pretend we parsed 'DCFv', which is impossible for the
        ADDEQ   AELINE,AELINE,#4        ;   user to have entered (due to uppercase conversion)
CASMDCF2
        BL      EXPR
        TEQ     TYPE,#0
        BEQ     ERTYPEINT
        BLPL    IFLT
        LDR     R4,[SP],#4
        TEQ     R4,#"E"
        BEQ     CASMDCFE
        TEQ     R4,#"D"
        BEQ     CASMDCFD
      [ :DEF: VFPAssembler
        TEQ     R4,#"v"
        BEQ     CASMDCFv
        TEQ     R4,#"H"
        BEQ     CASMDCFH
      ]
        TEQ     R4,#"S"
        BNE     ERASSFP1
CASMDCFS

 [ FPOINT=0
        ASSERT  FACCX=R1
        SUBS    FACCX,FACCX,#2
        BLE     CASMDCFSSMALL
        ORR     R1,FSIGN,FACCX,LSL #23
        BIC     FACC,FACC,#&80000000
        ORR     R1,R1,FACC,LSR #8       ; XXX No rounding
        B       CASMICHK
CASMDCFSSMALL

        RSB     FACCX,FACCX,#9
        ORR     R1,FSIGN,FACC,LSR FACCX
        B       CASMICHK
 ELIF FPOINT=1
        STFS    FACC,[SP,#-4]!
        LDR     R1,[SP],#4
        B       CASMICHK
 ELIF FPOINT=2
        FCVTSD  S0,FACC ; Assume FACC corruptible
        FPSCRCheck R1
        FMRS    R1,S0
        B       CASMICHK
 |
        ! 1, "Unknown FPOINT setting"
 ]
CASMDCFD

        ADD     R2,ARGP,#STRACC
 [ FPOINT=0
        ASSERT  FACCX=R1
        ASSERT  FGRD=R2
        TEQ     FACC,#0
        MOVEQ   FACCX,#0
        ADDNE   FACCX,FACCX,#&400
        SUBNE   FACCX,FACCX,#&82
        ORR     R7,FSIGN,FACCX,LSL #20
        BIC     FACC,FACC,#&80000000
        ORR     R7,R7,FACC,LSR #11
        STR     R7,[R2],#4
        MOV     R7,FACC,LSL #21
        STR     R7,[R2],#4
 ELIF FPOINT=1
        STFD    FACC,[R2],#8
 ELIF FPOINT=2
        ASSERT  FACC = 0
        FSTS    S1,[R2],#4
        FSTS    S0,[R2],#4
 |
        ! 1, "Unknown FPOINT setting"
 ]
        B       CASMXCHK

 [ :DEF: VFPAssembler
CASMDCFv
        ADD     R2,ARGP,#STRACC
  [ FPOINT=0
        ASSERT  FACCX=R1
        ASSERT  FGRD=R2
        TEQ     FACC,#0
        MOVEQ   FACCX,#0
        ADDNE   FACCX,FACCX,#&400
        SUBNE   FACCX,FACCX,#&82
        ORR     R7,FSIGN,FACCX,LSL #20
        BIC     FACC,FACC,#&80000000
        ORR     R7,R7,FACC,LSR #11
        STR     R7,[R2,#4]
        MOV     R7,FACC,LSL #21
        STR     R7,[R2],#8
  ELIF FPOINT=1
        STFD    FACC,[R2]
        LDMIA   R2,{R0,R1}
        STR     R0,[R2,#4]
        STR     R1,[R2],#8
  ELIF FPOINT=2
        FSTD    FACC,[R2],#8
  |
        ! 1, "Unknown FPOINT setting"
  ]
        B       CASMXCHK

CASMDCFH
  [ FPOINT=0
        ASSERT  FACCX=R1
        SUBS    FACCX,FACCX,#2+127-15
        MOV     FSIGN,FSIGN,LSR #16
        MOV     R2,#2
        BLE     CASMDCFHSMALL
        CMP     FACCX,#&1F ; Assume AHP in use?
        ORR     R1,FSIGN,FACCX,LSL #10
        BIC     FACC,FACC,#&80000000
        ORR     R1,R1,FACC,LSR #16+5       ; XXX No rounding
        BLE     CASMXCHK
        LDRB    R0,[ARGP,#BYTESM]
        TST     R0,#OPT_errors
        BNE     FOVR
        B       CASMXCHK
CASMDCFHSMALL

        RSB     FACCX,FACCX,#16+6
        ORR     R1,FSIGN,FACC,LSR FACCX
        B       CASMXCHK
  |
    [ FPOINT=1
        STFS    FACC,[SP,#-4]!
        LDR     R1,[SP],#4
    |
        ; We could try and use the half-precision extension here, but it's probably not worth the effort
        FCVTSD  S0,FACC ; Assume FACC corruptible
        FPSCRCheck R1
        FMRS    R1,S0
    ]
        MOV     R2,R1,LSR #23 ; exponent
        MOV     R0,R1,LSL #8 ; mantissa
        AND     R2,R2,#&FF
        ORR     R0,R0,#&80000000 ; safe to set this, even on denormalised numbers (the shift
                                 ;   amount will be so large that this bit will be lost)
        SUBS    R2,R2,#127-15
        RSBLE   R2,R2,#1
        MOVLE   R0,R0,LSR R2
        MOVLE   R2,#0
        MOV     R0,R0,LSR #21
        TST     R1,#&80000000
        BIC     R0,R0,#&400
        ORR     R1,R0,R2,LSL #10
        ORRNE   R1,R1,#&8000
        CMP     R2,#&1F ; Assume AHP in use?
        MOV     R2,#2
        BLE     CASMXCHK
        LDRB    R0,[ARGP,#BYTESM]
        TST     R0,#OPT_errors
        BNE     FOVR
        B       CASMXCHK
  ]
 ]

CASMDCFE

        ADD     R2,ARGP,#STRACC
 [ FPOINT=0
        TEQ     FACC,#0
        MOVEQ   FACCX,#0
        ADDNE   FACCX,FACCX,#&4000
        SUBNE   FACCX,FACCX,#&82
        ORR     FACCX,FSIGN,FACCX
        STR     FACCX,[R2],#4
        STR     FACC,[R2],#4
        MOV     FACC,#0
        STR     FACC,[R2],#4
 ELIF FPOINT=1
        STFE    FACC,[R2],#12
 ELIF FPOINT=2
        FMRRD   R14,R1,FACC ; Transfer to FPA word order
        ; Only deal with three types of numbers:
        ; * Zero
        ; * Denormalised
        ; * Normalised
        EORS    R0,R14,R1,LSL #1 ; EQ if (+/-) zero
        ; Move the sign bit to R0
        AND     R0,R1,#&80000000
        BIC     R1,R1,#&80000000
        BEQ     CASMDCFE0
        ; Detect denormalised numbers
        CMP     R1,#1<<20
        ; Transfer exponent to R0
        ORRHS   R0,R0,R1,LSR #20
        ORRHS   R0,R0,#16383-1023 ; Adjust bias
        ; Shift over the fraction
        MOV     R1,R1,LSL #31-20
        ORR     R1,R1,R14,LSR #21
        MOV     R14,R14,LSL #32-21
        ; Set J
        ORRHS   R1,R1,#&80000000
        BICLO   R1,R1,#&80000000
CASMDCFE0
        STMIA   R2!,{R0,R1,R14}
 ]
        B       CASMXCHK

CASMNOP BL      AESPAC
        BL      ALIGN
        MOV     R1,#&E1000000
        ORR     R1,R1,#&A00000
        B       CASMICHK

CASMQSAT
        ORR     R1,R1,#&50
        BL      CHKREGSPC
        BL      CHKCOM

        ; NB. Rm and Rn are specified in the opposite order to ARM convention

        ORR     R1,R1,R0,LSL #12       ; Rd
        BL      CHKREG
        BL      AESPAC
        CMP     R10,#","
        ANDNE   R2,R1,#&F000
        ORRNE   R1,R1,R0,LSL #16       ; complete Rn
        ORRNE   R1,R1,R2,LSR #12       ; replicate Rd as Rm
        BNE     CASMICHK
        ORR     R1,R1,R0               ; complete Rm
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #16       ; Rn
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMDBG BL      AESPAC
        BL      ASMIMEXPR
        CMP     R0,#15
        BHI     ERASS2
        ORR     R1,R1,R0
        ORR     R1,R1,#&F0
        ORR     R1,R1,#&F000
        ORR     R1,R1,#&3000000
        SUB     AELINE,AELINE,#1
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMCLZ ORR     R1,R1,#&1000000
        ORR     R1,R1,#&F0000
        ORR     R1,R1,#&F10
        BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12       ; Rd
        BL      CHKREG
        ORR     R1,R1,R0               ; Rm
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.


CASMCPSID
        ORR     R1,R1,#&40000
CASMCPSIE

        ORR     R1,R1,#&80000
        BL      AESPAC
CASMCPSLP

        BIC     R10,R10,#" "
        TEQ     R10,#"A"
        ORREQ   R1,R1,#&100
        LDREQB  R10,[AELINE],#1
        BEQ     CASMCPSLP
        TEQ     R10,#"I"
        ORREQ   R1,R1,#&80
        LDREQB  R10,[AELINE],#1
        BEQ     CASMCPSLP
        TEQ     R10,#"F"
        ORREQ   R1,R1,#&40
        LDREQB  R10,[AELINE],#1
        SUBNE   AELINE,AELINE,#1       ; rewind to re-read
        BEQ     CASMCPSLP
        BL      AESPAC
        CMP     R10,#","
        BNE     CASMICHK
        ; mode number also specified

CASMCPS BL      AESPAC
        BL      ASMIMEXPR
        CMP     R0,#&20
        BHS     ERASS2
        ORR     R1,R1,R0
        ORR     R1,R1,#&20000
        B       CASMICHK

CASMHLT
        ; arrive here R1=0 + CC
CASMBKPT
        ORR     R1,R1,#&1000000
        ORR     R1,R1,#&70
        BL      AESPAC
        BL      ASMIMEXPR
        MOV     R0,R0,LSL #16
        MOV     R14,R0,LSL #12
        MOV     R0,R0,LSR #20
        ORR     R1,R1,R0,LSL #8
        ORR     R1,R1,R14,LSR #28
        B       CASMICHK

CASMPLD LDRNEB  R10,[AELINE]
        BEQ     ERASS1                 ; no conditions please
        BIC     R10,R10,#" "
        TEQ     R10,#"W"
        ORRNE   R1,R1,#&400000
        ADDEQ   AELINE,AELINE,#1
        ORR     R1,R1,#&F5000000
        ORR     R1,R1,#&F000
        ADRL    R14,CASMLDSTCOMMON2
        B       AESPAC                 ; t.c.o.

CASMPLI BEQ     ERASS1                 ; no conditions please
        ORR     R1,R1,#&F4000000
        ORR     R1,R1,#&F000
        ADRL    R14,CASMLDSTCOMMON2
        B       AESPAC                 ; t.c.o.

CASMBFI ORR     R1,R1,#&07000000
        ORR     R1,R1,#&10
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0
        B       CASMBFCOM
CASMBFC ORR     R1,R1,#&07000000
        ORR     R1,R1,#&1F
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
CASMBFCOM
        BL      CHKCOM
        BL      ASMIMEXPR
        CMP     R0,#31                 ; check lsb
        BHI     ERASS2
        ORR     R1,R1,R0,LSL #7
        SUB     AELINE,AELINE,#1
        BL      CHKCOM
        BL      ASMIMEXPR              ; field width expression
        AND     R2,R1,#&F80            ; recover lsb
        CMP     R0,#32
        ADDLS   R0,R0,R2,LSR #7        ; check msb+1
        CMPLS   R0,#31
        SUBLS   R0,R0,#1               ; msb is inclusive
        BHI     ERASS2
        ORR     R1,R1,R0,LSL #16
        SUB     AELINE,AELINE,#1
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMCLREX
        MVN     R1,#&FE0
        BIC     R1,R1,#&0A800000       ; &F57FF01F
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMCRC32
        TST     R1,#1:SHL:27           ; transfer C discriminator to b9
        BIC     R1,R1,#3:SHL:27        ; clear discriminator, make AL
        ORRNE   R1,R1,#2_1001:SHL:6
        ORREQ   R1,R1,#2_0001:SHL:6
CASMTHREEREG
        ; three plain registers, no shifty business
        BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
        BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #16
        BL      CHKREGSPC
        ORR     R1,R1,R0
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMSEL ORR     R1,R1,#&6000000
        ORR     R1,R1,#&FB0
CASMTWOTHREEREG

        ; two or three registers, Rd may be implicit (Rd == Rn)
        BL      CHKREGSPC
        BL      CHKCOM
        ORR     R1,R1,R0,LSL #12
        BL      CHKREG
        BL      AESPAC
        CMP     R10,#","
        ANDNE   R2,R1,#&F000           ; implicit Rd, replicate
        ORRNE   R1,R1,R0               ; complete Rm
        ORRNE   R1,R1,R2,LSL #4        ; complete Rn
        BNE     CASMICHK
        ORR     R1,R1,R0,LSL #16
        BL      CHKREGSPC
        ORR     R1,R1,R0
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.


CASMSEV MOVS    R14,R1,LSR #27+1       ; transfer L discriminator to C
        ADC     R1,R1,#4               
        BIC     R1,R1,#1:SHL:27
        ORR     R1,R1,#&0000F000
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMDMB ORR     R1,R1,#&10
CASMDSB BEQ     ERASS1                 ; no conditions please
        BL      AESPAC
        ORR     R1,R1,#&F5000000
        ORR     R1,R1,#&000FF000
        TEQ     R10,#TESCSTMT
        LDREQB  R10,[AELINE],#1
        BEQ     CASMDBSYST             ; (SYST?)
        BIC     R10,R10,#" "
        TEQ     R10,#"S"
        TEQNE   R10,#"L"
        BEQ     CASMDBSYS              ; S(T|Y?) or L(D?) alone

        ;check ISH/OSH/NSH
        ORR     R1,R1,#&41
        TEQ     R10,#"I"
        ORREQ   R1,R1,#&C
        TEQNE   R10,#"N"
        EOREQ   R1,R1,#4
        TEQNE   R10,#"O"
        LDREQB  R10,[AELINE],#1
        ORRNE   R1,R1,#&F              ; default to SY
        ADRNEL  R14,CASMICHK
        SUBNE   AELINE,AELINE,#1
        BNE     AESPAC                 ; t.c.o.

        BIC     R10,R10,#" "
        TEQ     R10,#"S"
        LDREQB  R10,[AELINE],#1
        ORREQ   R1,R1,#2
        BICEQ   R10,R10,#" "
        TEQEQ   R10,#"H"
        LDREQB  R10,[AELINE]
        BNE     ERSYNT

        ;check suffixes for ST (store) and LD (load)
        BIC     R10,R10,#" "
        LDRB    R14,[AELINE,#1]
        BIC     R14,R14,#" "
        TEQ     R10,#"L"
        TEQEQ   R14,#"D"
        BICEQ   R1,R1,#2               ; load
        BEQ     %FT10
        TEQ     R10,#"S"
        TEQEQ   R14,#"T"
        BICEQ   R1,R1,#1               ; store
10      ADDEQ   AELINE,AELINE,#2
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.
CASMDBSYST
        TEQ     R10,#TSYS
        LDREQB  R10,[AELINE],#1
        ORREQ   R1,R1,#&4E
        BICEQ   R10,R10,#" "
        TEQEQ   R10,#"T"               ; SYST synonym for ST
        BNE     ERSYNT
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.
CASMDBSYS
        LDRB    R14,[AELINE],#1
        BIC     R14,R14,#" "
        ORR     R1,R1,#&4E             ; full system something
        TEQ     R10,#"S"
        TEQEQ   R14,#"T"
        BEQ     %FT10
        TEQ     R10,#"L"
        TEQEQ   R14,#"D"
        EOREQ   R1,R1,#3               ; ST->LD
        BEQ     %FT10
        TEQ     R10,#"S"
        TEQEQ   R14,#"Y"
        ORREQ   R1,R1,#1               ; ST->SY
        BNE     ERSYNT
10      ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMISB BEQ     ERASS1                 ; no conditions please
        BL      AESPAC
        ORR     R1,R1,#&F5000000
        ORR     R1,R1,#&000FF000
        ORR     R1,R1,#&6F
        ;check for optional 'SY'
        BIC     R10,R10,#" "
        TEQ     R10,#"S"
        LDREQB  R10,[AELINE]
        BICEQ   R10,R10,#" "
        TEQEQ   R10,#"Y"
        ADDEQ   AELINE,AELINE,#1
        SUBNE   AELINE,AELINE,#1
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

; REV   c6BFrF3r
; REV16 c6BFrFBr
; REVSH c6FFrFBr

CASMREV LDRNEB  R10,[AELINE]
        ORR     R1,R1,#&06000000
        ORR     R1,R1,#&000F0000
        ORR     R1,R1,#&00000F30
        BEQ     CASMREVREGS
        ; check for '16' or 'SH' suffix
        TEQ     R10,#"1"
        BEQ     CASMREV16
        BIC     R10,R10,#" "
        TEQ     R10,#"S"
        LDREQB  R10,[AELINE,#1]
        BNE     CASMREVREGS
        BIC     R10,R10,#" "
        TEQ     R10,#"H"
        ORREQ   R1,R1,#&00400000
CASMREVCOND
        ORREQ   R1,R1,#&80
        ADDEQ   AELINE,AELINE,#2
        BICEQ   R1,R1,#&F0000000
        BLEQ    DOCOND
CASMREVREGS
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.
CASMREV16
        LDRB    R10,[AELINE,#1]
        TEQ     R10,#"6"
        B       CASMREVCOND

CASMUDF ORR     R1,R1,#&06000000
        ORR     R1,R1,#&80
CASMHVC ORR     R1,R1,#&01000000
        MOV     R2,R1,LSR #28
        ORR     R1,R1,#&70
        TEQ     R2,#&E
        BNE     ERASS1                 ; no non-AL conditions please
        BL      AESPAC
        BL      ASMIMEXPR
        CMP     R0,#&10000
        MOVLO   R0,R0,ROR #4
        BHS     ERASS2
        ORR     R1,R1,R0,LSR #28
        ORR     R1,R1,R0,LSL #8
        B       CASMICHK

CASMSMC BL      AESPAC
        CMP     R10,#"#"
        SUBNE   AELINE,AELINE,#1
CASMSMI BL      ASMEXPR
        CMP     R0,#&10
        BHS     ERASS2
        ORR     R1,R1,#&70
        ORR     R1,R1,R0
        B       CASMICHK

CASMWFI ORR     R1,R1,#&03000000
        ORR     R1,R1,#&0000F000
        ORR     R1,R1,#3
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMPKHTB
        ORR     R1,R1,#&40
CASMPKHBT
        STR     R1,[SP,#-4]!           ; remember whether TB/BT form
        ORR     R1,R1,#&10
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        BL      CHKREG
        BL      AESPAC
        CMP     R10,#","
        ANDNE   R2,R1,#&F000
        ORRNE   R1,R1,R0               ; complete Rm
        ORRNE   R1,R1,R2,LSL #4        ; replicate Rd as Rn
        BNE     CASMPKHUNSH

        ; test for shift specifier
        BL      AESPAC
        LDRB    R3,[AELINE]
        LDRB    R14,[AELINE,#1]
        BIC     R2,R10,#" "
        BIC     R3,R3,#" "
        BIC     R14,R14,#" "
        TEQ     R2,#"L"
        TEQEQ   R3,#"S"
        TEQEQ   R14,#"L"
        BEQ     CASMPKHSHTEST1
        TEQ     R2,#"A"
        TEQEQ   R3,#"S"
        TEQEQ   R14,#"R"
        BNE     CASMPKHRM
CASMPKHSHTEST1

        SUB     AELINE,AELINE,#1
        AND     R2,R1,#&F000
        ORR     R1,R1,R0               ; complete Rm
        ORR     R1,R1,R2,LSL #4        ; replicate Rd as Rn
        B       CASMPKHSH

CASMPKHRM

        ORR     R1,R1,R0,LSL #16       ; complete Rn
        BL      CHKREGSPC
        BL      AESPAC
        ORR     R1,R1,R0
        CMP     R10,#","
        BNE     CASMPKHUNSH
        ; Rm is shifted; use the same routine as DP/LDR instructions

CASMPKHSH
        BIC     R1,R1,#&50             ; callee expects to complete these bits
        BL      CASMDATASHIFT
        LDR     R2,[SP],#4             ; retrieve original encoding
        TST     R1,#&30                ; check LSL/ASR and constant shift
        ORR     R1,R1,#&10             ; NB. sense of this bit is inverted w.r.t. DP
        EOREQ   R2,R2,R1
        TSTEQ   R2,#&40                ; and correct choice of LSL/ASR
        BNE     ERASS2S
        B       CASMICHK
CASMPKHUNSH
        ; PKHTB unshifted is a pseudo-instruction - transpose the operands
        ;   and select LSL #0 (it is impossible to specify ASR #0)

        ADD     SP,SP,#4
        TST     R1,#&40
        MOVNE   R2,#&F0000
        ORRNE   R2,R2,#&4F
        ANDNE   R0,R2,R1,ROR #16
        BICNE   R1,R1,R2               ; clear Rn/Rm and switch to ...BT form
        ORRNE   R1,R1,R0
        SUB     AELINE,AELINE,#1
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMRBIT
        ORR     R1,R1,#&F0000
        ORR     R1,R1,#&F30
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMBFX ORR     R1,R1,#&50
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0
        BL      CHKCOM
        BL      ASMIMEXPR
        CMP     R0,#31
        BHI     ERASS2
        ORR     R1,R1,R0,LSL #7
        TEQ     R10,#','
        BNE     ERCOMM
        BL      AESPAC
        BL      ASMIMEXPR
        AND     R2,R1,#&F80
        TEQ     R0,#0
        BEQ     ERASS2
        CMP     R0,#32
        ADD     R2,R0,R2,LSR #7
        CMPLS   R2,#32
        BHI     ERASS2
        SUB     R0,R0,#1
        ORR     R1,R1,R0,LSL #16
        B       CASMICHK

CASMRFE ORR     R1,R1,#&A00
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #16
        BL      AESPAC
        CMP     R10,#"!"
        BNE     CASMICHK
        ORR     R1,R1,#&200000
        ADRL    R14,CASMICHK
        B       AESPAC

CASMSRS BL      CHKREGSPC
        TEQ     R0,#13                 ; Only save via stack pointer
        BNE     ERASS3
        BL      AESPAC
        TEQ     R10,#"!"
        ORREQ   R1,R1,#&200000
        SUBNE   AELINE,AELINE,#1
        BL      CHKCOM
        ORR     R1,R1,#&D0000
        ORR     R1,R1,#&500
        BL      ASMIMEXPR
        CMP     R0,#&20
        BHS     ERASS2
        ORR     R1,R1,R0
        B       CASMICHK

CASMERET
        ORR     R1,R1,#&6E
        ADRL    R14,CASMICHK
        B       AESPAC

CASMSETEND
        ORR     R1,R1,#&10000
        BL      AESPAC
        BIC     R10,R10,#" "
        TEQ     R10,#"B"
        ORREQ   R1,R1,#&200
        TEQNE   R10,#"L"
        LDREQB  R10,[AELINE],#1
        BICEQ   R10,R10,#" "
        TEQ     R10,#"E"
        BNE     ERSYNT
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

; these implement <U|UH|UQ|S|SH|Q>ADD<8|16>
CASMADD8
        ORR     R1,R1,#&80
CASMADD16
        ORR     R1,R1,#&F10
        B       CASMTWOTHREEREG

; these implement <U|UH|UQ|S|SH|Q>SUB<8|16>
CASMSUB8
        ORR     R1,R1,#&80
CASMSUB16
        ORR     R1,R1,#&F70
        B       CASMTWOTHREEREG

; these implement {U|UH|UQ|S|SH|Q}<AS|SA>X
CASMASX
        ORR     R1,R1,#&60
CASMSAX EOR     R1,R1,#&F50
        B       CASMTWOTHREEREG

; these implement <S|U>SAT{16}
CASMSAT16
        ORR     R1,R1,#&F20
CASMSAT ORR     R1,R1,#&10
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        CMP     R10,#"#"
        SUBNE   AELINE,AELINE,#1
        BL      ASMEXPR
        ; signed saturation accepts 1-16/32, unsigned 0-15/31
        ;   with the former encoding n-1 in the instruction

        TST     R1,#&400000
        SUBEQ   R0,R0,#1               ; adjust signed bit positions, making 0 invalid
        TST     R1,#&F00
        BICEQS  R2,R0,#&1F
        BICNES  R2,R0,#&F
        BNE     ERASS2                 ; fault too-high bit positions, and signed 0

        ORR     R1,R1,R0,LSL #16       ; bit position ('sat_imm')
        SUB     AELINE,AELINE,#1
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0               ; Rn
        BL      AESPAC

        ; non-16 form supports a LSL/ASR #imm5 shift specifier
        TST     R1,#&F00
        CMPEQ   R10,#","
        BNE     CASMICHK
        ; Rn is shifted; use the same routine as DP/LDR instructions

        BIC     R1,R1,#&50             ; callee expects to complete these bits
        BL      CASMDATASHIFT
        TST     R1,#&30
        BNE     ERASS2S                ; reject LSR/RRX and Rs forms
        ORR     R1,R1,#&10             ; NB. sense of this bit is inverted w.r.t. DP
        B       CASMICHK

CASMSUXT
        ORR     R1,R1,#&F0000
CASMSUXTA
        ORR     R1,R1,#&70
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12       ; Rd
        TST     R1,#&F0000
        BNE     CASMSUXTNA             ; non-A form excludes Rn

        ; 'A' form requires at least one more register
        BL      CHKCOM
        BL      CHKREG
        BL      AESPAC
        CMP     R10,#","
        ANDNE   R2,R1,#&F000
        ORRNE   R1,R1,R0               ; complete Rm
        ORRNE   R1,R1,R2,LSL #4        ; replicate Rd as Rn
        BNE     CASMICHK

        BL      CASMDATAROTB
        ANDEQ   R2,R1,#&F000
        ORREQ   R1,R1,R2,LSL #4        ; replicate Rd as Rn
        BEQ     CASMSUXTROR
        ORR     R1,R1,R0,LSL #16       ; complete Rn
CASMSUXT1

        BL      CHKREGSPC
        BL      AESPAC
        CMP     R10,#","
        ORRNE   R1,R1,R0               ; complete Rm
        BNE     CASMICHK
        BL      CASMDATAROTB
        BNE     ERSYNT
CASMSUXTROR

        ; Rm is rotated, read and validate shift amount
        ORR     R1,R1,R0               ; complete Rm
        BL      ASMEXPR

        MOVS    R2,R0,LSR #5
        TSTEQ   R0,#7
        BNE     ERASS2S
        ORR     R1,R1,R0,LSL #7
        B       CASMICHK
CASMSUXTNA

        BL      AESPAC
        CMP     R10,#","
        ORRNE   R1,R1,R0               ; complete Rm
        BNE     CASMICHK

        BL      CASMDATAROTB
        BEQ     CASMSUXTROR
        B       CASMSUXT1

; Check for presence of ROR#
; entry AELINE -> first char to be tested
; exit  R0,R1 preserved
;       EQ = ROR found, AELINE -> expected first char of shift amount
;       NE = not found, AELINE unmodified

CASMDATAROTB
        LDRB    R10,[AELINE]
        LDRB    R2,[AELINE,#1]
        LDRB    R3,[AELINE,#2]
        BIC     R10,R10,#" "
        BIC     R2,R2,#" "
        BIC     R3,R3,#" "
        TEQ     R10,#"R"
        TEQEQ   R2,#"O"
        TEQEQ   R3,#"R"
        MOVNE   PC,R14
        MOV     R2,R14
        ADD     AELINE,AELINE,#3
        BL      AESPAC
        CMP     R10,#"#"
        SUBNE   AELINE,AELINE,#1
        CMP     R0,R0                  ; set Z (EQ)
        MOV     PC,R2

CASMUMAAL
        ORR     R1,R1,#&90
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #12
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0,LSL #16
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0,LSL #8
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMWFE ORR     R1,R1,#&03000000
        ORR     R1,R1,#&F000
        ORR     R1,R1,#2
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMYIELD
        ORR     R1,R1,#&F000
        ORR     R1,R1,#1
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

; SDIV   c71rFr1r
; UDIV   c73rFr1r
; USAD8  c78rFr1r
; USADA8 c78rrr1r

CASMUSAD8
CASMDIV ORR     R1,R1,#&F000
CASMUSADA8
        ORR     R1,R1,#&10
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #16
        BL      CHKCOM
        BL      CHKREG
        BL      AESPAC
        CMP     R10,#","
        TSTNE   R1,#&F000              ; <S|U>DIV|USAD8 implicit Rd
        ANDNE   R2,R1,#&F0000
        ORRNE   R1,R1,R0,LSL #8
        ORRNE   R1,R1,R2,LSR #16
        BNE     CASMICHK
        ORR     R1,R1,R0
        BL      CHKREGSPC
        ORR     R1,R1,R0,LSL #8
        ; USADA8 requires a 4th register
        TST     R1,#&F000
        ADRNEL  R14,CASMICHK
        BNE     AESPAC                 ; t.c.o.
        BL      CHKCOM
        BL      CHKREG
        ORR     R1,R1,R0,LSL #12
        ADRL    R14,CASMICHK
        B       AESPAC                 ; t.c.o.

CASMFN  LDRB    R0,[ARGP,#BYTESM]
        STMFD   SP!,{R0-R3}
        BL      FN
        BL      AESPAC
        BL      ASMCHK
        LDMFD   SP!,{R0-R3}
        STRB    R0,[ARGP,#BYTESM]
        B       CASMX
GET2PC  LDR     R2,[ARGP,#ASSPC]
        ADD     R2,R2,#3
        BIC     R2,R2,#3
        MOV     PC,R14
ALIGN   LDRB    R0,[ARGP,#BYTESM]
        STR     R14,[SP,#-4]!
        TST     R0,#OPT_asm_to_O
        BEQ     ALIGN_1
        LDR     R0,[ARGP,#ASSPC-4]
        ANDS    R14,R0,#3
        BEQ     ALIGN_0
        CMP     R14,#2
        MOV     R14,#0
        STRB    R14,[R0],#1
        STRLSB  R14,[R0],#1
        STRLOB  R14,[R0],#1
        STR     R0,[ARGP,#ASSPC-4]
ALIGN_0 LDR     R0,[ARGP,#ASSPC]
        ADD     R0,R0,#3
        BIC     R0,R0,#3
        STR     R0,[ARGP,#ASSPC]
        LDR     PC,[SP],#4
ALIGN_1 LDR     R0,[ARGP,#ASSPC]
        ANDS    R14,R0,#3
        LDREQ   PC,[SP],#4
        CMP     R14,#2
        MOV     R14,#0
        STRB    R14,[R0],#1
        STRLSB  R14,[R0],#1
        STRLOB  R14,[R0],#1
        STR     R0,[ARGP,#ASSPC]
        LDR     PC,[SP],#4
ASMCHK  TEQ     R10,#":"
        TEQNE   R10,#13
        MOVEQ   PC,R14
        TEQ     R10,#";"
        TEQNE   R10,#"\\"
        TEQNE   R10,#TREM
        BNE     ERSYNT
ASMCHK2 LDRB    R10,[AELINE],#1
        TEQ     R10,#":"
        TEQNE   R10,#13
        BNE     ASMCHK2
        MOV     PC,R14

; evaluate immediate constant/expression,
;   optionally preceded by # as per UAL specification
;
; entry R10 = first character of constant/expression (may be #)
;       AELINE -> second character
; exit  R10 = first character following constant/expression
;       AELINE -> beyond first char
ASMIMEXPR
        CMP     R10,#"#"
        SUBNE   AELINE,AELINE,#1

; entry AELINE -> first character of expression
; exit  R10 = first character after constant/expression
;       AELINE -> beyond first char
ASMEXPR STMFD   SP!,{R1,R14}
        BL      EXPR
        TEQ     TYPE,#0
        BEQ     ERTYPEINT
        BLMI    INTEGB
        LDMFD   SP!,{R1,PC}
;check conditional mnemonic
;EQ if present, R1=R1 OR code, NE if not present R1=R1 OR AL
DOCOND  LDRB    R10,[AELINE]
        BIC     R2,R10,#" "
        LDRB    R0,[AELINE,#1]
        BIC     R0,R0,#" "
        ORR     R0,R0,R2,LSL #8
        MOV     R0,R0,LSL #8
        ADR     R2,CONDTAB
DOCOND1 LDR     R3,[R2],#4
        CMP     R0,R3,LSL #8
        BHI     DOCOND1
        BNE     DOCONDFL
        AND     R3,R3,#&F0000000
        ORR     R1,R1,R3
        ADD     AELINE,AELINE,#2       ;matched so advance
        MOV     PC,R14
DOCONDFL

        ORRS    R1,R1,#&E0000000
        MOV     PC,R14
CONDTAB =       "LA",0,&E0
        =       "CC",0,&30
        =       "SC",0,&20
        =       "QE",0,&00
        =       "EG",0,&A0
        =       "TG",0,&C0
        =       "IH",0,&80
        =       "SH",0,&20
        =       "EL",0,&D0
        =       "OL",0,&30
        =       "SL",0,&90
        =       "TL",0,&B0
        =       "IM",0,&40
        =       "EN",0,&10
        =       "VN",0,&F0
        =       "LP",0,&50
        =       "CV",0,&70
        =       "SV",0,&60
        DCD     -1
DOFPPREC

        LDRB    R10,[AELINE],#1
        BIC     R10,R10,#" "
        TEQ     R10,#"S"
        MOVEQ   PC,R14
        TEQ     R10,#"D"
        ORREQ   R1,R1,#&80
        MOVEQ   PC,R14
        TEQ     R10,#"E"
        BNE     ERASSFP1
        ORR     R1,R1,#&80000
        MOV     PC,R14
DOFPPRECDT

        LDRB    R10,[AELINE],#1
        BIC     R10,R10,#" "
        TEQ     R10,#"S"
        MOVEQ   PC,R14
        TEQ     R10,#"D"
        ORREQ   R1,R1,#&8000
        MOVEQ   PC,R14
        TEQ     R10,#"E"
        ORREQ   R1,R1,#&400000
        MOVEQ   PC,R14
        TEQ     R10,#"P"
        BNE     ERASSFP1
        ORR     R1,R1,#&400000
        ORR     R1,R1,#&8000
        MOV     PC,R14
DOFPROUND

        LDRB    R10,[AELINE],#1
        BIC     R10,R10,#" "
        TEQ     R10,#"P"
        ORREQ   R1,R1,#&20
        MOVEQ   PC,R14
        TEQ     R10,#"M"
        ORREQ   R1,R1,#&40
        MOVEQ   PC,R14
        TEQ     R10,#"Z"
        ORREQ   R1,R1,#&60
        SUBNE   AELINE,AELINE,#1
        MOV     PC,R14

CHKREG1 STR     R14,[SP,#-4]!
        B       CHKREG2        
CHKREGSPC
        LDRB    R10,[AELINE],#1
CHKREGSPCCONT
        TEQ     R10,#" "
        BEQ     CHKREGSPC
;check for R0-R15,SP or LR or PC otherwise call ASMEXPR
CHKREG  STR     R14,[SP,#-4]!
        BL      GETREG
        LDREQ   PC,[SP],#4
CHKREG2 SUB     AELINE,AELINE,#1
        STR     R1,[SP,#-4]!
        BL      FACTOR
        BL      INTEGZ
        CMP     R0,#15
        BHI     ERASS3
        LDMFD   SP!,{R1,PC}
; check for R0-R15,SP or LR or PC. Returns EQ with R0 = register number if found
GETREG  BIC     R0,R10,#" "
        CMP     R0,#"R"
        BNE     RDPC
CHKREGC LDRB    R10,[AELINE]
        CMP     R10,#"9"
        MOVHI   PC,R14
        SUBS    R0,R10,#"0"
        MOVCC   PC,R14
        TEQ     R0,#1
        BNE     RDPOST
        LDRB    R10,[AELINE,#1]
        CMP     R10,#"0"
        BCC     RDPOST
        CMP     R10,#"5"               ; If got > r15, could be part of a variable name
        SUBLS   R0,R10,#"0"-10
        ADDLS   AELINE,AELINE,#1
RDPOST  STMFD   SP!,{R0,R14}
        LDRB    R0,[AELINE,#1]
        BL      WORDCQ
        TEQCC   R0,R0                  ; EQ, next chr invalid in a variable name
        ADDCC   AELINE,AELINE,#1       ;     so Rn|PC|LR|SP can't be a substring
        MOVCSS  R0,#1                  ; NE
        LDMFD   SP!,{R0,PC}
RDPC    CMP     R0,#"P"
        BNE     RDLR
        LDRB    R10,[AELINE]
        BIC     R0,R10,#" "
        TEQ     R0,#"C"
        MOVEQ   R0,#15
        BEQ     RDPOST
        MOV     PC,R14
RDLR    CMP     R0,#"L"
        BNE     RDSP
        LDRB    R10,[AELINE]
        BIC     R0,R10,#" "
        TEQ     R0,#"R"
        MOVEQ   R0,#14
        BEQ     RDPOST
        MOV     PC,R14
RDSP    CMP     R0,#"S"
        MOVNE   PC,R14
        LDRB    R10,[AELINE]
        BIC     R0,R10,#" "
        TEQ     R0,#"P"
        MOVEQ   R0,#13
        BEQ     RDPOST
        MOV     PC,R14

CHKCOM  LDRB    R10,[AELINE],#1
        CMP     R10,#" "
        BEQ     CHKCOM
        CMP     R10,#","
        BEQ     AESPAC
        B       ERCOMM
CHKCOPROSPC

        LDRB    R10,[AELINE],#1
CHKCOPROSPCCONT

        TEQ     R10,#" "
        BEQ     CHKCOPROSPC
;check for CP0-CP15 otherwise call ASMEXPR
CHKCOPRO

        BIC     R0,R10,#" "
        CMP     R0,#"C"
        BNE     CHKREG1
        LDRB    R10,[AELINE]
        BIC     R0,R10,#" "
        CMP     R0,#"P"
        BNE     CHKREG1
        LDRB    R10,[AELINE,#1]
        CMP     R10,#"9"
        BHI     CHKREG1
        SUBS    R0,R10,#"0"
        BCC     CHKREG1
        TEQ     R0,#1
        BNE     RDCOPRO1
        LDRB    R10,[AELINE,#2]
        CMP     R10,#"0"
        BCC     RDCOPRO1
        CMP     R10,#"9"
        BHI     RDCOPRO1
        CMP     R10,#"5"
        BHI     CHKREG1
        SUB     R0,R10,#"0"-10
        ADD     AELINE,AELINE,#1
RDCOPRO1

        ADD     AELINE,AELINE,#2
        MOV     PC,R14
CHKCPREGSPC

        LDRB    R10,[AELINE],#1
CHKCPREGSPCCONT

        TEQ     R10,#" "
        BEQ     CHKCPREGSPC
;check for C0-C15 otherwise call ASMEXPR
CHKCPREG

        BIC     R0,R10,#" "
        CMP     R0,#"C"
        BEQ     CHKREGC
        B       CHKREG1
CHKFPREGSPC

        LDRB    R10,[AELINE],#1
CHKFPREGSPCCONT

        TEQ     R10,#" "
        BEQ     CHKFPREGSPC
;check for F0-F7 otherwise call ASMEXPR
CHKFPREG

        STR     R14,[SP,#-4]!
        BIC     R0,R10,#" "
        ADR     R14,CHKFPREG1
        CMP     R0,#"F"
        BEQ     CHKREGC
        B       CHKREG1
CHKFPREG1

        CMP     R0,#7
        BHI     ERASS3
        LDR     PC,[SP],#4

        LNK     VFP.s
