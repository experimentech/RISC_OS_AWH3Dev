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
; > s.Tail

;-----------------------------------------------------------------------------------------
; stricmp(char *r0, char *r1) returning Z=1 if equal
;
; compare the null terminated strings pointed to by r0 and r1 (case insensitive).
stricmp
       Push     "r0-r2,LR"

01
       LDRB     r14,[r0],#1
       BIC      r14,r14,#&20            ; Uppercasify
       LDRB     r2,[r1],#1
       BIC      r2,r2,#&20              ; Uppercasify
       CMP      r14,r2
       Pull     "r0-r2,PC",NE
       CMP      r14,#0
       BNE      %BT01

       Pull     "r0-r2,PC"

; ----------------------------------------------------------------------------------------------------------------------
;       Release linked lists of files/icons. Note - may be in USER mode or SVC mode - can't use USER stack,
;       though, as it may not be okay. Hence not allowed to use the stack at all.
;    R2 -> pointer to start of list to kill (active_ptr or buffered_ptr)
;        DANGER - CORRUPTS R0-R3
free_list
        MOV     R3, LR
        LDR     r1, [r2,#next_ptr]
        MOV     r0, #0
        STR     r0, [r2,#next_ptr]
; Get next file in the list
01
        MOV     r0, #ModHandReason_Free
        SUBS    r2, r1, #0
        MOVLE   PC, R3
; Free the workspace
        LDR     r1, [r2,#next_ptr]
        SWI     XOS_Module
        B       %BT01

; ----------------------------------------------------------------------------------------------------------------------

copy_r0r4r3_space

        Push    "r3,r4,LR"
01
        LDRB    r14, [r4], #1
        CMP     r14,#32
        MOVLE   R14,#0
        STRB    r14, [r0], #1
        SUBS    r3 , r3,#1
        CMPNE   r14, #0
        BNE     %BT01
        CMP     r3,#0
        STREQB  r3,[r0],#1
        SUB     r0, r0, #1

        Pull    "r3,r4,PC"

; ----------------------------------------------------------------------------------------------------------------------
copy_r0r4_null
01
        LDRB    r6, [r4], #1
        STRB    r6, [r0], #1
        CMP     r6, #0
        BNE     %BT01     
        SUB     r0, r0, #1
        MOV     PC, LR

; ----------------------------------------------------------------------------------------------------------------------

; MessageTrans routines

LookupError
        Push    "r1-r7,lr"
        BL      open_messages
        Pull    "r1-r7,pc",VS
        MOV     r4, r1
        ADR     r1, message_fblock
        MOV     r2, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
        Pull    "r1-r7,pc"

message_filename
        DCB     "Free:Messages",0
        ALIGN

open_messages
        Push    "r0-r2,lr"
        LDR     r0, message_fopen
        CMP     r0, #0
        Pull    "r0-r2,pc",NE
        ADR     r0, message_fblock
        ADR     r1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        STRVS   r0, [sp]
        STRVC   r0, message_fopen
        Pull    "r0-r2,pc"

Lookup_InPlace  ROUT
        Push    "r1-r7,LR"
        BL      open_messages
        Pull    "r1-r7,PC",VS
        MOV     r1,r0
        ADR     r0,message_fblock
        MOV     r2,#0
        MOV     R4,#0
        MOV     R5,#0
        MOV     R6,#0
        MOV     R7,#0
        SWI     XMessageTrans_Lookup
        MOVVC   r0,r2
        Pull    "r1-r7,PC"

Lookup  ROUT                            ; r0 -> token, r2 -> buffer , r3 = buf length ,r4 -> arg
        Push    "r1-r7,LR"
        BL      open_messages
        Pull    "r1-r7,PC",VS
        MOV     r1,r0
        ADR     r0,message_fblock
        MOV     R5,#0
        MOV     R6,#0
        MOV     R7,#0
        SWI     XMessageTrans_Lookup
        MOVVC   r0,r2
        STRVC   r3,[sp,#2*4]
        Pull    "r1-r7,PC"

; ----------------------------------------------------------------------------------------------------------------------



; Neil's debugging routines

      [ debug
        InsertNDRDebugRoutines
      ]

        END
