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


        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:HALEntries
        GET     Hdr:OSEntries

        GET     hdr.StaticWS
        GET     hdr.AllWinnerH3
        GET     hdr.Registers


;        EXPORT  HAL_CleanerSpace
;        EXPORT  HAL_ExtMachineID

        EXPORT  HAL_ControllerAddress
        EXPORT  HAL_Reset
        EXPORT  DWCToSunXi
        IMPORT  HAL_Watchdog
 [ Debug
        IMPORT DebugHALPrint

         IMPORT HAL_DebugTX
         IMPORT HAL_DebugRX
 ]

        AREA    |Asm$$Code|, CODE, READONLY, PIC

;HAL_CleanerSpace

; 	mov a1, #-1
    
;    LDR a1, SRAM_A1_BaseAddr ;Have the SRAM. Let's see what happens!
    ;Only try this when the vectors have been moved.
;;Well, it was worth a try.
;	mov pc, lr

HAL_ExtMachineID    ;garbage

    CMP a1, #0
    ;LDRNE a1, =machID0
    MOVEQ a1, #8
    MOV pc, lr
    ALIGN
machID0      *     &01234567
machID1      *     &89ABCDEF
    ALIGN

HAL_ControllerAddress ;no controller.
    MOV a1, #0
    MOV pc, lr

HAL_Reset
    MRC p15, #0, a1, c1, c0, #0
    AND a1, a1, #2_1 ;bit0 is MMU state

    CMP a1, #0 ;is MMU on?
    BNE %FT10

    ;No, it is not on.
    LDR a1, =R_CPUCFG
    LDR a4, [a1, #CPU_SYS_RST_REG]
    BIC a4, a4, #2_1 ;That should kill it.
    STR a4, [a1, #CPU_SYS_RST_REG]
    ;BOOM!


    ;if the MMU is on
10  LDR    a1, =R_CPUCFG
    LDR    a2, =IO_Base
    LDR    a3, IO_BaseAddr
    SUB    a2, a2, a1
	ADD    a2, a3, a2  ;a2 now holds the logical address of the reset reg.
	LDR    a4, [a2, #CPU_SYS_RST_REG]
    BIC    a4, a4, #2_1 ;That should kill it.
	STR    a4, [a2, #CPU_SYS_RST_REG]
    B   .
    ;MOV a1, #1
    ;MOV a2, #1
    ;LDR a3,=&DEADDEAD
    ;BL  HAL_Watchdog
    ;B   .

;----------------------------------------------------------------------
;Changes DWC reg offsets to mangled SunXi reg offsets.

DWCToSunXi
    Push  "a2"
    RBIT   a2, a1
    ORR    a2, a2, a1
    LDR    a1, =&55555555
    AND    a2, a2, a1

    ORR    a2, a2, LSR#1
    LDR    a1, =&33333333
    AND    a2, a2, a1

    ORR    a2, a2, LSR#2
    LDR    a1, =&0f0f0f0f
    AND    a2, a2, a1

    ORR    a2, a2, LSR#4
    LDR    a1, =&00FF00FF
    AND    a2, a2, a1

    ORR    a2, a2, LSR#8
    LDR    a1, =&0000FFFF
    AND    a2, a2, a1
    MOV    a1, a2
    Pull  "a2"
    MOV    pc, lr

	END
