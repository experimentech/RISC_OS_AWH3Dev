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
;>MsgsStuff

        TTL     "Message file handling"

; Message file handling code

; ----------
; copy_error
; ----------
;
; In    r0 = pointer to error block with text <tag>
;       r1 = error number
; Out   r0 = pointer to translated error block
copy_error ROUT
        Push    "r1-r7,lr"
        MOV     R4, #0
10
 [ Debug
        ADD     r0, r0, #4
        DSTRING r0, "copy_error in: "
        SUB     r0, r0, #4
 ]
        MOV     R5, #0
        MOV     R6, #0
30
        MOV     R7, #0
        CLRV                    ; To avoid interaction with any V set on entry
        BL      open_message_file
        Pull    "r1-r7,pc",VS

        ; Hold the old error number
        LDR     r3, [r0]

        ; Lookup the error
        ADR     R1, message_file_block
        MOV     R2, #0
        BL      DoXMessageTrans_ErrorLookup
 [ :LNOT:NewErrors
        BIC     r0, r0, #ExternalErrorBit
 ]

        ; Adjust the error number if it's unchanged from entry
        LDR     r1, [r0]
        TEQ     r1, r3
        Pull    "r1"
        STREQ   r1, [r0]

 [ Debug
        ADD     r0, r0, #4
        DSTRING r0, "copy_error out: "
        SUB     r0, r0, #4
 ]

        Pull    "r2-r7,pc"

; -----------
; copy_error1
; -----------
;
; In    r0 = pointer to error block with text <tag>
;       r1 = error number
;       r4 = 1st parameter
; Out   r0 = pointer to translated error block
copy_error1
        Push    "r1-r7,lr"
        B       %BT10

; -----------
; copy_error3
; -----------
;
; In    r0 = pointer to error block with text <tag>
;       r1 = error number
;       r4 = 1st parameter
;       r5 = 2nd parameter
;       r6 = 3rd parameter
; Out   r0 = pointer to translated error block
copy_error3
        Push    "r1-r7,lr"
        B       %BT30

; ------------------------
; message_lookup_to_buffer
; ------------------------
;
; In    r0 = pointer to nul-terminated tag
;       r2 = buffer
;       r3 = buffer size
; Out   r0 = pointer to \0 terminated string in buffer
;       error possible
message_lookup_to_buffer ROUT
        Push    "r0-r7,lr"
        MOV     r4, #0
10
        MOV     r5, #0
20
        MOV     r6, #0
        MOV     r7, #0
        MOV     r1, r0
        ADR     r0, message_file_block
        BL      open_message_file
        SWI     XMessageTrans_Lookup
        STRVC   r2, [sp]
        STRVS   r0, [sp]
        Pull    "r0-r7,pc"

; --------------------------
; message_lookup_to_buffer01
; --------------------------
;
; In    r0 = pointer to nul-terminated tag
;       r2 = buffer
;       r3 = buffer size
;       r4 = pointer to substitute string
; Out   r0 = pointer to \0 terminated string in buffer
;       error possible

message_lookup_to_buffer01
        Push    "r0-r7,lr"
        B       %BT10

; --------------------------
; message_lookup_to_buffer02
; --------------------------
;
; In    r0 = pointer to nul-terminated tag
;       r2 = buffer
;       r3 = buffer size
;       r4 = pointer to substitute string
;       r5 = pointer to substitute string
; Out   r0 = pointer to \0 terminated string in buffer
;       error possible

message_lookup_to_buffer02
        Push    "r0-r7,lr"
        B       %BT20

; ----------------
; message_gswrite0
; ----------------
;
; In    r0 = pointer to nul-terminated <tag>
; Out   all regs preserved unless error
message_gswrite0 ROUT
        Push    "r0-r7,lr"
        MOV     r4, #0
10
        MOV     r5, #0
20
        MOV     r6, #0
        MOV     r7, #0
        SUB     sp, sp, #1024
        BL      open_message_file
        BVS     %FT30
        MOVVC   r1, r0
        ADRVC   r0, message_file_block
        MOVVC   r2, sp
        MOVVC   r3, #1024
        BLVC    DoXMessageTrans_GSLookup
        BVS     %FT30
        MOVVC   r0, r2
        MOVVC   r1, r3
        BLVC    DoXOS_WriteN
30
        STRVS   r0, [sp, #1024 + 0*4]
        ADD     sp, sp, #1024
        Pull    "r0-r7,pc"

; -----------------
; message_gswrite01
; -----------------
;
; In    r0 = pointer to nul-terminated <tag>
;       r4 = pointer to substitute string
; Out   all regs preserved unless error
message_gswrite01
        Push    "r0-r7,lr"
        B       %BT10


; -----------------
; message_gswrite02
; -----------------
;
; In    r0 = pointer to nul-terminated <tag>
;       r4 = pointer to substitute string
;       r5 = pointer to substitute string
; Out   all regs preserved unless error
message_gswrite02
        Push    "r0-r7,lr"
        B       %BT20


message_filename
        DCB     "Resources:$.Resources.FileCore.Messages", 0
        ALIGN

; -----------------
; open_message_file
; -----------------
;
; In    -
; Out   -
open_message_file ROUT
        Push    "r0-r7,lr"

        ; Ensure file not open already
        LDR     r1, message_file_open
        TEQ     r1, #0
        BNE     %FT01
01
        Pull    "r0-r7,pc",NE

        ; Open it
        ADR     R0, message_file_block
        ADR     R1, message_filename
        MOV     r2, #0
        BL      DoXMessageTrans_OpenFile

        LDR     r1, message_file_block
        LDR     r1, message_file_block+4
        LDR     r1, message_file_block+8
        LDR     r1, message_file_block+12

        MOVVC   r1, #1
        STRVC   r1, message_file_open

        STRVS   r0, [sp]
        Pull    "r0-r7,pc"

        END
