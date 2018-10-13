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
;
; RMFind utility
;
; Syntax: RMFind <module name> <version> [<filename>]
;
; This will attempt to find a given version (or later) of a module
; either in the ROM or on disc. If in ROM and unplugged/inactive
; it will reinitialise it. If already loaded nothing happens. If
; not in ROM, it will attempt to load it from the given filename.
; If the relevant module does not exist anywhere it will say
; "Module <modulename> <version> not found"

;
; On entry R0 = pointer to command line
;          R1 = pointer to command tail
;          R12 = pointer to workspace
;          R13 = pointer to workspace end (stack)
;          R14 = return address
;          USR mode, interrupts enabled

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Proc

	AREA	|ObjAsm$$Code|,CODE,READONLY,PIC

	Entry
RMFind
	Push	"R14"
	MOV	R0,R1
; Skip spaces
0	LDRB	R2,[R0],#1
	CMPS	R2,#32
	BLT	SyntaxError
	BEQ	%B0
	SUB	R9,R0,#1		; R9->start of first parameter
; Continue to end of parameter
1	LDRB	R2,[R0],#1
	CMPS	R2,#32
	BLT	SyntaxError
	BNE	%B1
; Stick in a terminator
	MOV	R4,#0
	STRB	R4,[R0,#-1]
; Skip spaces
2	LDRB	R2,[R0],#1
	CMPS	R2,#32
	BLT	SyntaxError
	BEQ	%B2
	SUB	R10,R0,#1		; R10->start of second param
; Continue to end of parameter
3	LDRB	R2,[R0],#1
	CMPS	R2,#32
	MOVLT	R11,#0
	STRLTB	R11,[R0,#-1]
	BLT	FinishedParse
	BNE	%B3
; Stick in a terminator
	MOV	R5,#0
	STRB	R5,[R0,#-1]
; Skip spaces
4	LDRB	R2,[R0],#1
	CMPS	R2,#32
	BLT	SyntaxError
	BEQ	%B4
	SUB	R11,R0,#1		; R11->start of third param
; Continue to end of parameter
5	LDRB	R2,[R0],#1
	CMPS	R2,#32
	MOVLT	R6,#0
	STRLTB	R6,[R0,#-1]
	BLT	FinishedParse
	BNE	%B5
; Stick in a terminator
	MOV	R6,#0
	STRB	R6,[R0,#-1]
; Skip spaces
6	LDRB	R2,[R0],#1
	CMPS	R2,#32
	BEQ	%B6
	BLT	FinishedParse

SyntaxError
	ADR	R0,SyntaxErrorBlock
	SWI	XOS_GenerateError
	Pull	"PC"

SyntaxErrorBlock
	&	&DC
	=	"Syntax: RMFind <moduletitle> <version number> [<filename>]", 0
	ALIGN

FinishedParse
	MOV	R7,R10
	MOV	R0,R10
	BL	ConvertVersion
	MOV	R10,R0
	;MOV	PC,#0
	MOV	R0,#18		; Look up module name
	MOV	R1,R9
	SWI	XOS_Module
	BVS	NotLoaded
	; R3->module code
	LDR	R0,[R3,#20]	; R0->help string
	ADD	R0,R3,R0
	; skip to tabs
10	LDRB	R1,[R0],#1
	TEQS	R1,#9
	BNE	%B10
	; skip over tabs
11	LDRB	R1,[R0],#1
	TEQS	R1,#9
	BEQ	%B11
	SUB	R0,R0,#1
	BL	ConvertVersion
	CMPS	R0,R10
	Pull	"PC",HS

	; Right, we're not currently loaded
	; Lets enumerate the ROMs
NotLoaded
	MOV	R0,#20
	MOV	R1,#0
	MVN	R2,#0
12	SWI	XOS_Module
	BVS	NotInROM
	[ {FALSE}
	MOV	R0,R3
	SWI	XOS_Write0
	MOV	R0,#20
	]
	; Compare titles
	MOV	R8,R9
13	LDRB	R5,[R3],#1
	LDRB	R4,[R8],#1
	BIC	R5,R5,#&20
	BIC	R4,R4,#&20
	TEQS	R5,R4
	BNE	%B12         ; Doesn't match
	TEQS	R5,#0
	BNE	%B13         ; Haven't finished yet
	[ {FALSE}
	Push	"R0-R2"
	MOV	R0,R6
	MOV	R1,R12
	MOV	R2,#256
	SWI	XOS_ConvertHex8
	SWI	XOS_Write0
	SWI	&120
	MOV	R0,R10
	MOV	R1,R12
	MOV	R2,#256
	SWI	XOS_ConvertHex8
	SWI	XOS_Write0
	SWI	XOS_NewLine
	Pull	"R0-R2"
	]

	CMPS	R6,R10
	BLO	%B12	     ; Not new enough - Check next module

	; We've found it in a ROM!
	; Delete the current (out-of-date) instantiation
	MOV	R0,#4
	MOV	R1,R9
	SWI	XOS_Module
	; Reinitialise the ROM one (this chooses the newest from the
	; ROM)
	MOV	R0,#3
	SWI	XOS_Module
	Pull	"PC",VS
	; Ah, but now we've inserted all ones from the ROM. Yuck.
	MOV	R0,#19
	MOV	R1,#0
	MVN	R2,#0
20	SWI	XOS_Module
	BVS	%F29
	BL	CmpNam
	BNE	%B20
	TEQS	R4,#0
	BNE	%B20
	; Found a dormant instance of our module - unplug it
	Push	"R0-R2"
	ADR	R0,Unplug
	LDMIA	R0,{R0,R1}
	STMIA	R12,{R0,R1}
	MOV	R0,R3
	ADD	R1,R12,#7
22	LDRB	R14,[R0],#1
	STRB	R14,[R1],#1
	TEQS	R14,#0
	BNE	%B22
	MOV	R14,#" "
	STRB	R14,[R1,#-1]
	MOV	R0,R2		; ROM section
	MOV	R2,#16
	SWI	XOS_ConvertInteger4
	Pull	"PC",VS
	MOV	R0,R12
	[ {FALSE}
	SWI	XOS_Write0
	SWI	XOS_NewLine
	MOV	R0,R12
	]
	SWI	XOS_CLI
	Pull	"R0-R2"
	B	%B20

29	ADDS	R0,R0,#0	; clear V
	Pull	"PC"

	ROUT
CmpNam
	Push	"R0-R3"
	MOV	R0,R9
	MOV	R1,R3
0	LDRB	R2,[R0],#1
	LDRB	R3,[R1],#1
	BIC	R2,R2,#&20
	BIC	R3,R3,#&20
	TEQS	R2,R3
	Pull	"R0-R3",NE
	MOVNE	PC,LR
	TEQS	R2,#0
	Pull	"R0-R3",EQ
	MOVEQ	PC,LR
	B	%B0

RMEnsure
	= "RMEnsure ", 0
	ALIGN

Unplug
	= "Unplug ", 0
	ALIGN

	ROUT
NotInROM
	TEQS	R11,#0
	BEQ	NoFilename
	MOV	R0,#1
	MOV	R1,R11
	SWI	XOS_Module
	Pull	"PC",VS

NoFilename
	ADR	R0,RMEnsure
	LDMIA	R0,{R1-R3}
	STMIA	R12,{R1-R3}
	ADD	R0,R12,#9
0	LDRB	R1,[R9],#1
	STRB	R1,[R0],#1
	CMPS	R1,#32
	BGE	%B0
	MOV	R1,#32
1	STRB	R1,[R0,#-1]
	LDRB	R1,[R7],#1
	STRB	R1,[R0],#1
	CMPS	R1,#32
	BGE	%B1
	MOV	R1,#0
	STRB	R1,[R0,#-1]
	MOV	R0,R12
	SWI	XOS_CLI
	Pull	"PC"

	ROUT
ConvertVersion
	Push	"R1-R3,LR"
	MOV	R3,#16
	MOV	R2,#0
0	LDRB	R1,[R0],#1
	TEQS	R1,#'.'
	BEQ	%F1
	CMPS	R1,#' '
	BLT	%F2
	SUB	R1,R1,#'0'
	ADD	R2,R1,R2,LSL #4
	B	%B0
1	LDRB	R1,[R0],#1
	CMPS	R1,#' '
	BLE	%F2
	SUB	R1,R1,#'0'
	ADD	R2,R1,R2,LSL #4
	SUBS	R3,R3,#4
	BNE	%B1
2	MOV	R0,R2,LSL R3
	[ {FALSE}
	MOV	LR,R0
	MOV	R1,R12
	MOV	R2,#256
	SWI	XOS_ConvertHex8
	SWI	XOS_Write0
	MOV	R0,LR
	]
	Pull	"R1-R3,PC"

	= "RMFind 1.03 (19 Sep 2012)"

	END
