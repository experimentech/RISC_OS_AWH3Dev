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

        AREA    |Asm$$Data|,DATA,READWRITE
DMBWrPtr DCD    0        

        AREA    |Asm$$Code|,CODE,READONLY

        GET     ListOpts
        GET     Macros
        GET     System
        GET     OSMisc

        EXPORT  asm_calldriver
        IMPORT  module_error
        
        EXPORT  asm_ReadDMB
        EXPORT  asm_DMBInit

; insert DMBWrite pointer in supplied pointer
asm_DMBInit
        STMFD   R13!, {R0,R4-R11,LR}
        LDR     R0, =(ARMop_DMB_Write:SHL:8)+MMUCReason_GetARMop
        SWI     XOS_MMUControl
        ADRVS   R0, My_DMB_Write        ; old kernel?
        LDR     LR, [r13], #4
        STR     R0, [LR]
        LDMFD   R13!, {R4-R11,PC}

My_DMB_Write
        DMB     ST
        MOV     pc, lr
asm_ReadDMB 
        DMB
        mov     pc, lr       

; APCS
; In: R0 = routine
;     R1 = their R12
;     R2 = their R8
;     R3 = their R11
;     [SP,#0] -> parameter block (R0-R7)
; Out: R0 = error pointer (if V set) else 0
;      R0-R7 of parameter block updated
asm_calldriver
        STMFD   R13!, {R4-R11,LR}
        LDR     R9, [R13, #36]
        MOV     R10, R0
        MOV     R11, R3
        MOV     R12, R1
        MOV     R8, R2
        LDMIA   R9, {R0-R7}
        MOV     LR, PC
        MOV     PC, R10
        STMIA   R9, {R0-R7}
        MOVVC   R0, #0
        LDMVCFD R13!, {R4-R11,PC}
        LDMFD   R13!, {R4-R11,LR}       ; handles translation of low
        B       module_error            ; error numbers

        EXPORT  asm_callrelease

; APCS
; In: R0 = routine
;     R1 = their R12
;     R2 -> parameter block
; Out: R0 = error pointer (if V set) else 0
asm_callrelease
        STMFD   R13!, {R4-R10,LR}
        MOV     R10, R0
        MOV     R9, R2
        MOV     R12, R1
        LDMIA   R9, {R0-R8}
        MOV     LR, PC
        MOV     PC, R10
        MOVVC   R0, #0
        LDMFD   R13!, {R4-R10,PC}

        EXPORT  asm_callcallback

; APCS
; In: R0 = routine
;     R1 = their R12
;     R2 -> parameter block
asm_callcallback
        STMFD   R13!, {R4-R9,LR}
        CMP     R0, #0
        BEQ     %FT10
        CMP     R0, #&80000000
        CMNVC   R0, #&80000000
10      MOV     R9, R0
        MOV     R8, R2
        MOV     R12, R1
        LDMIA   R8, {R0-R7}
        MOV     LR, PC
        MOV     PC, R9
        MOVVC   R0, #0
        LDMFD   R13!, {R4-R9,PC}

; Keep in sync with C code
IDLE            EQU &00000000
RUNNING         EQU &00000004
STALLED         EQU &00000008
WAITING         EQU &00000010
INITIALISING    EQU &00000020
INITIALISED     EQU &00000040
ERROR           EQU &00000080

        EXPORT  asm_callbackhandler
; SPI_Op background callback routine used for foreground ops
asm_callbackhandler
        ; keep layout in sync with C code
        MOVVC   R5,#IDLE
        MOVVS   R5,#ERROR
        STMIA   R12,{R0,R1,R2,R3,R4,R5}
        MOV     PC,LR

; Entry point for callbacks from drivers
        IMPORT  driver_callback_entry
        IMPORT  driver_error_entry
        EXPORT  asm_driver_callback
asm_driver_callback
        BVC     driver_callback_entry
        BVS     driver_error_entry

        END
