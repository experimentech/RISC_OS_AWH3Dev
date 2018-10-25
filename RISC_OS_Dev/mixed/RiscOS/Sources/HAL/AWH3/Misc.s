;Copyright (c) 2017, Tristan Mumford
;All rights reserved.
;
;Redistribution and use in source and binary forms, with or without
;modification, are permitted provided that the following conditions are met:
;
;1. Redistributions of source code must retain the above copyright notice, this
;   list of conditions and the following disclaimer.
;2. Redistributions in binary form must reproduce the above copyright notice,
;   this list of conditions and the following disclaimer in the documentation
;   and/or other materials provided with the distribution.
;
;THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
;ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
;ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
;ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
;The views and conclusions contained in the software and documentation are those
;of the authors and should not be interpreted as representing official policies,
;either expressed or implied, of the RISC OS project.

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

	END
