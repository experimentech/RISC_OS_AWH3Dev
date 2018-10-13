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

; little assembler stub to buffer service routine

	AREA	|C$$data|, DATA

        EXPORT  BuffManService
BuffManService
        DCD     0

        EXPORT  BuffManWS
BuffManWS
        DCD     0

	AREA	|C$$code|, CODE, READONLY

	EXPORT	call_buffermanager
call_buffermanager
	STMFD	R13!,{R4,R5,r12,LR}
	MOV	R4,R0
	MOV	R5,R1
	MOV	R12,R2
	LDMIA	R4!,{R0-R3}
	MOV	LR,PC
	MOV	PC,R5
	STMDB	R4,{R2-R3}
	MRS	R0,CPSR
	LDMFD	R13!,{R4,R5,r12,PC}

        END
