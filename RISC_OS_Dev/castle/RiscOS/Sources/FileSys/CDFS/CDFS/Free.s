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
; Support code for the Free module
;



Free_Entry
        TEQ     r0, #FreeReason_ComparePath
        BEQ     Free_ComparePath ; special fast case

        CMP     r0, #0
        CMPNE   r0, #FreeReason_GetSpace64 + 1
        Pull    "pc", HS        ; unsupported reason code

        Pull    "r14"
        PushAllWithReturnFrame

        MOV     r1, #1          ; need a leading ':' character
        LDRB    r0, [r3]
        TEQ     r0, #':'        ; already has a leading ':'?
        ADDEQ   r3, r3, #1
01      LDRB    r0, [r3], #1
        CMP     r0, #' '
        ADDHI   r1, r1, #1
        BHI     %BT01

        LDR     r3, [sp, #3*4]
        ADD     r2, r1, #1+3
        BIC     r2, r2, #3
        SUB     sp, sp, r2      ; make space on the stack for a copy of the device

        MOV     lr, sp
        LDRB    r0, [r3]
        TEQ     r0, #':'
        MOVNE   r0, #':'
        STRNEB  r0, [lr], #1
        SUBNE   r1, r1, #1
02      SUBS    r1, r1, #1
        LDRPLB  r0, [r3], #1
        STRPLB  r0, [lr], #1
        BPL     %BT02
        MOV     r0, #0
        STRB    r0, [lr]

        MOV     r0, sp
        BL      FindDriveNumber ; r1 = drive
        ADD     sp, sp, r2      ; junk copy of device name
        BVS     ErrorExit

        MOV     r6, r1          ; r6 = drive number
        LDMIA   sp, {r0-r3}     ; get original registers back

        TEQ     r0, #FreeReason_GetName
        BEQ     Free_GetName
        TEQ     r0, #FreeReason_GetSpace
        BEQ     Free_GetSpace
;        TEQ     r0, #FreeReason_ComparePath
;        BEQ     Free_ComparePath
        TEQ     r0, #FreeReason_GetSpace64
        BEQ     Free_GetSpace64

        PullAllFromFrameAndExit

;-----------------------------------------------------------------------
; Free_GetName
;
; Put the name of the drive specified in r6 into the buffer at r2
;
Free_GetName ROUT
        MOV     r3, r2          ; keep buffer pointer safe
        MOV     r0, r6
        BL      TestKnowDisc    ; r1 -> buffer for disc
        BVS     ErrorExit
        MOV     r0, #0
        ADD     r1, r1, #DiscBuff_DiscName
10      LDRB    r2, [r1], #1
        ADD     r0, r0, #1
        CMP     r2, #' '
        STRHIB  r2, [r3], #1
        BHI     %BT10
        MOV     r2, #0
        STRB    r2, [r3]        ; null-terminate just in case

        PullAllFromFrameAndExit AL, 1

;-----------------------------------------------------------------------
; Free_GetSpace
;
; Put the free space on the drive specified in r6 into the buffer at r2
;
Free_GetSpace ROUT
        BL      Free_GetSpace_Common
        BVS     ErrorExit
        TEQ     r1, #0
        MOVNE   r0, #-1         ; use big number if doesn't fit in a word
        MOV     r3, #0
        MOV     lr, r0
        STMIA   r2, {r0,r3,lr}  ; store disc size, free space, used space
        PullAllFromFrameAndExit

;-----------------------------------------------------------------------
; Free_GetSpace64
;
; Put the free space on the drive specified in r6 into the buffer at r2
;
Free_GetSpace64 ROUT
        BL      Free_GetSpace_Common
        BVS     ErrorExit
        MOV     r3, #0
        MOV     r6, #0
        MOV     r7, r0
        MOV     lr, r1
        STMIA   r2, {r0-r3,r6-r7,lr} ; store disc size, free space, used space
        PullAllFromFrameAndExit

Free_GetSpace_Common
; On entry, r6 = drive
; On exit,  r0,r1 are lsw,msw of disc size, r3,r7 corrupt
        Push    "r14"
        MOV     r0, r6
        BL      PreConvertDriveNumberToDeviceID

        SUBVC   sp, sp, #8
        MOVVC   r0, #LBAFormat
        MOVVC   r1, sp
        SWIVC   XCD_DiscUsed
        BVS     ErrorExit       ; flattens stack

        Pull    "r1,r3"

        MOV     r14, r1, LSL #16
        MOV     r1, r1, LSR #16 ; r1 = mshw of block count
        MOV     r0, r14, LSR #16 ; r0 = lshw of block count

        MUL     r14, r1, r3
        MUL     r0, r3, r0
        MOV     r1, r14, LSR #16
        ADDS    r0, r0, r14, LSL #16
        ADC     r1, r1, #0
        Pull    "pc"

;-------------------------------------------------------------------------
; Free_ComparePath
;
; Since we're a read-only filing system, we never need to update
;
Free_ComparePath ROUT
        CMP     pc, #0
        Pull    "pc"

        END
