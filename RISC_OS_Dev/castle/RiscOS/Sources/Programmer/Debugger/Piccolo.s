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
; File:    Piccolo.s
; Purpose: Disassembly of the "Piccolo" instruction set
; Author:  K Bracey
; History: 02-May-00: KJB: architecture 5 extensions, fixes

        [ Piccolo

; In    r0 = instruction to disassemble
;       r9 = where it is

; Out   r1 -> core containing string
;       r2 = length of string excluding 0
;       r10,r11 corrupt

PiccoloInstruction
	Entry	"R0,R3-R9"

        MOV     R4, R0

        ADR     R0, StringBuffer        ; Always build into temp buffer

        ADD     PC,PC,R4,LSR #24
        NOP
        B       PiccoloAddSubParallel   ; 3.14
        B       PiccoloAddSubParallel   ; 3.14
        B       PiccoloAddSubParallel   ; 3.14
        B       PiccoloAddSubParallel   ; 3.14
 B PiccoloUndefined ;       B       PiccoloADDA     ; 3.13
 B PiccoloUndefined ;       B       PiccoloSADDA    ; 3.13
 B PiccoloUndefined ;       B       PiccoloMUL      ; 3.26
 B PiccoloUndefined ;       B       PiccoloSMUL     ; 3.26
        B       PiccoloAddSubParallel   ; 3.14
        B       PiccoloAddSubParallel   ; 3.14
        B       PiccoloAddSubParallel   ; 3.14
        B       PiccoloAddSubParallel   ; 3.14
 B PiccoloUndefined ;       B       PiccoloSUBA     ; 3.13
 B PiccoloUndefined ;       B       PiccoloSSUBA    ; 3.13
 B PiccoloUndefined ;       B       PiccoloRSB      ; 3.12
 B PiccoloUndefined ;       B       PiccoloSRSB     ; 3.12
 B PiccoloUndefined ;       B       PiccoloADD      ; 3.12
 B PiccoloUndefined ;       B       PiccoloSADD     ; 3.12
 B PiccoloUndefined ;       B       PiccoloADDN     ; 3.12
 B PiccoloUndefined ;       B       PiccoloSABS     ; 3.30
 B PiccoloUndefined ;       B       PiccoloADC      ; 3.12
 B PiccoloUndefined ;       B       PiccoloMIN      ; 3.20
 B PiccoloUndefined ;       B       PiccoloADCN     ; 3.12
 B PiccoloUndefined ;       B       PiccoloMAX      ; 3.20
 B PiccoloUndefined ;       B       PiccoloSUB      ; 3.12
 B PiccoloUndefined ;       B       PiccoloSSUB     ; 3.12
 B PiccoloUndefined ;       B       PiccoloSUBN     ; 3.12
 B PiccoloUndefined ;       B       PiccoloCLB      ; 3.17
 B PiccoloUndefined ;       B       PiccoloSBC      ; 3.12
 B PiccoloUndefined ;       B       PiccoloMINMIN   ; 3.21
 B PiccoloUndefined ;       B       PiccoloSBCN     ; 3.12
 B PiccoloUndefined ;       B       PiccoloMAXMAX   ; 3.21
 B PiccoloUndefined ;       B       PiccoloAND      ; 3.19
 B PiccoloUndefined ;       B       PiccoloORR      ; 3.19
 B PiccoloUndefined ;       B       PiccoloBIC      ; 3.19
 B PiccoloUndefined ;       B       PiccoloEOR      ; 3.19
 B PiccoloUndefined ;       B       PiccoloCAS      ; 3.16
 B PiccoloUndefined ;       B       PiccoloCASC     ; 3.16
        B       PiccoloUndefined
        B       PiccoloUndefined
 B PiccoloUndefined ;       B       PiccoloASL      ; 3.33
 B PiccoloUndefined ;       B       PiccoloLSR      ; 3.33
 B PiccoloUndefined ;       B       PiccoloASR      ; 3.33
        B       PiccoloUnpredictable
 B PiccoloUndefined ;       B       PiccoloSEL      ; 3.31
        B       PiccoloUndefined
 B PiccoloUndefined ;       B       PiccoloSELTT    ; 3.32
 B PiccoloUndefined ;       B       PiccoloSELTF    ; 3.32
 B PiccoloUndefined ;       B       PiccoloMULA     ; 3.24
 B PiccoloUndefined ;       B       PiccoloSMULA    ; 3.24
 B PiccoloUndefined ;       B       PiccoloMULS     ; 3.24
 B PiccoloUndefined ;       B       PiccoloSMULS    ; 3.24
        B       PiccoloUndefined
 B PiccoloUndefined ;       B       PiccoloSMLDA    ; 3.25
        B       PiccoloUndefined
 B PiccoloUndefined ;       B       PiccoloSMLDS    ; 3.25
        B       PiccoloUndefined
        B       PiccoloUndefined
        B       PiccoloUndefined
        B       PiccoloUndefined
 B PiccoloUndefined ;       B       PiccoloMOVN     ; 3.22
        B       PiccoloUndefined
 B PiccoloUndefined ;       B       PiccoloREPEAT   ; 3.29
 B PiccoloUndefined ;       B       PiccoloB        ; B 3.15, HALT/BREAK 3.18, ListOps 3.27, RMOV 3.28


        MACRO
        TestSat
        TestBit 26,"S"
        MEND


PiccoloAddSubParallel
        ; arrive here with 00x0 xxxx xxxx xxxx xxxx xxxx xxxx xxxx
        ; format is        00m0 msdd dddd daaa aaaa bbbb bbbb bbbb
        ;
        ; {S}<ADD|SUB><ADD|SUB> <dest_32>, <src1_32>, <src2_PAR>
        ;
        ; where  m m = Subtract/~Add for high and low halves respectively
        ;          s = saturation
        ;       dddd = destination
        ;       aaaa = source 1
        ;       bbbb = source 2

        TestSat
        TestStr 29,P_Add,P_Sub
        TestStr 27,P_Add,P_Sub
        BL      Tab_Dis_Picc_Dest
        BL      Comma_Dis_Picc_Src1
        BL      Comma_Dis_Picc_Src2
        B       InstructionEnd

P_Add   = "ADD", 0
P_Sub   = "SUB", 0
UnknownPiccolo
        = "M00", 0
UnpredPiccolo
        = "M65", 0
        ALIGN

PiccRegBanks
        = "AXYZ"

Dis_Picc_Register
        MOV     R10,R5,LSR #2
        ANDS    R10,R10,#3
        MOVEQ   R10,#"A"
        ADDNE   R10,R10,#"W"
        STRB    R10,[R0],#1
        AND     R10,R5,#3
        ADD     R10,R10,#"0"
        STRB    R10,[R0],#1
        MOV     PC,LR

PiccoloUndefined
	ADR	R10, UnknownPiccolo
10	BL	lookup_r10
        ADR     R0, StringBuffer
	BL	SaveString
	B	PiccoloInstEnd

PiccoloUnpredictable
	ADR	R10, UnpredPiccolo
	B	%B10

PiccoloInstEnd
        MOV     r14, #0
        STRB    r14, [r0]

        ADR     r1, StringBuffer
	SUBS	r2, r0, r1		; Clears V flag

	EXIT

Dis_Picc_Dest
        ENTRY   "R5,R8"
20      AND     R8,R4,#2_11:SHL:23
        TEQ     R8,#2_11:SHL:23
        BEQ     %FT50
        MOV     R5,R4,LSR #19
        BL      Dis_Picc_Register
        TestBit 24,,"."
        BNE     %FT30
        TestBit 23,"h","l"
30
        TestBit 25,"^"
        EXIT
50
        TestBit 25
        BEQ     PiccoloUnpredictable
        TST     R4,#2_11:SHL:19
        BNE     PiccoloUndefined
        TestBit 21
        AddChar ".",EQ
        AddChar "l",EQ
        TestBit 22,"^"
        EXIT

Tab_Dis_Picc_Dest
        ALTENTRY
        BL      Tab
        B       %B20

Dis_Picc_Src
        ENTRY   "R5"
10      MOV     R5,R8,LSR #1
        BL      Dis_Picc_Register
        TST     R8,#1:SHL:6
        BNE     %FT20
        AddChar "."
        TST     R8,#1:SHL:0
        MOVNE   R10,#"h"
        MOVEQ   R10,#"l"
        STR     R10,[R0],#1
        B       %FT30
20
        TST     R8,#1:SHL:0
        AddChar ".",NE
        AddChar "x",NE
30
        TST     R8,#1:SHL:5
        AddChar "^",NE
        EXIT

Dis_Picc_Src1
        ENTRY   "R8"
10      MOV     R8,R4,LSR #12
        BL      Dis_Picc_Src
        EXIT

Comma_Dis_Picc_Src1
        ALTENTRY
        BL      AddComma
        B       %B10


Dis_Picc_Src2
        ENTRY   "R2,R5"
10
        TestBit 11
        BNE     %F30

        MOV     R8,R4
        BL      Dis_Picc_Src
        BL      Comma_Dis_Picc_Scale
        EXIT
30
        TestBit 10
        BEQ     %FT60

        AddChar "#"
        MOV     R8,R4,LSR #4
        AND     R8,R8,#&3F
        MOV     R2,#8-4
        BL      StoreHex
        BL      Comma_Dis_Picc_Scale


        EXIT

60
        AND     R8,R4,#&FF
        AND     R2,R8,#2_11:SHL:8
        MOV     R2,R2,LSR #8-3
        MOV     R8,R8,ROR R2

        CMPS    R8,#10
        BLO     Rem_Number              ; If really simple, just display number
                                        ; ie. 0..9 unambiguous

        MOV     R2,#8-4                 ; default is byte
        CMPS    R8,#&100
        MOVHS   R2,#16-4                ; then halfword
        CMPS    R8,#&10000
        MOVHS   R2,#32-4                ; then fullword
        BL      StoreHex

        MOV     R2,#32-4
        BL      StoreHex
        EXIT

Comma_Dis_Picc_Src1
        ALTENTRY
        BL      AddComma
        B       %B10

	]


	END
