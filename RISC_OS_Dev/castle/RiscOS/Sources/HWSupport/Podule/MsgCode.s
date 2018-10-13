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

        TTL     The Podule manager.
        SUBT    Message handling code => Podule.s.MsgCode

; OSS Size of temporary block for when we do a lookup with subsitution.

temp_block_size         *       512

; OSS Print a GS Transed string from the Messages file, with four parameters.
; Temporarily claims a block of RMA for the buffer.

; In:           r0 -> token
;               r1-r2 -> %0-%1
; Out:          r3-r11 preserved, r0-r2 undefined, flags undefined
; Error:        r0 -> error block, V set

gs_lookup_print_string_two Entry "r3-r7"
        BL      open_message_file
        EXIT    VS
  [  DebugCommands
        DSTRING r0, "GSLookup on token: "
  ]

; Move input parameters. "Fortunately", OS_Module Claim needs r0, r2 and r3
; which just "happen" to be the ones we don't need yet. (I spy careful design
; of the MessageTrans interface!)

        MOV     r4, r1                          ; -> %0
        MOV     r5, r2                          ; -> %1
        MOV     r6, #0                          ; -> %2
        MOV     r7, #0                          ; -> %3
        MOV     r1, r0                          ; Message token

; Claim the temporary block

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #temp_block_size
        SWI     XOS_Module
        EXIT    VS
  [  DebugCommands
        DLINE   "Block claimed OK."
  ]

; r2 -> block, r3 = size of block as required by MessageTrans

        ADR     r0, message_file_block          ; Message file handle
  [  DebugCommands
        DREG    r0, "R0 = &", cc
        Push    r14
        LDR     r14, [ r0, #0 ]
        DREG    r14, ", &", cc
        LDR     r14, [ r0, #4 ]
        DREG    r14, ", &", cc
        LDR     r14, [ r0, #8 ]
        DREG    r14, ", &", cc
        LDR     r14, [ r0, #12 ]
        DREG    r14, ", &"
        Pull    r14
        DREG    r1, "R1 = &", cc
        DSTRING r1, " token is: "
        DREG    r2, "R2 = &"
        DREG    r3, "R3 = &"
        DREG    r4, "R4 = &", cc
        DSTRING r4, " %0 is: "
        DREG    r5, "R5 = &", cc
        DSTRING r5, " %1 is: "
        DREG    r6, "R6 = &", cc
        DSTRING r6, " %2 is: "
        DREG    r7, "R7 = &", cc
        DSTRING r7, " %3 is: "
        DREG    r8, "R8 = &"
        DREG    r9, "R9 = &"
        DREG    r10, "R10 = &"
        DREG    r11, "R11 = &"
        DREG    r12, "R12 = &"
        DREG    r13, "R13 = &"
        DREG    r14, "R14 = &"
        DREG    r15, "R15 = &"
  ]
        SWI     XMessageTrans_GSLookup
  [  DebugCommands
        DLINE   "SWI XMessageTrans_GSLookup returns ", cc
        BVS     %16
        DLINE   "OK"
        B       %17
16
        DLINE   "an error: ", cc
        ADD     r14, r0, #4
        DSTRING r14
17
  ]
        MOVVS   r6, r0                          ; Squirrel error away
        BVS     free_block
        MOV     r6, #0                          ; Flag no error

; Now print the string from the block

        MOV     r0, r2                          ; Resulting string
        MOV     r1, r3                          ; String length
        SWI     XOS_WriteN
        MOVVS   r6, r0                          ; Squirrel error away

free_block ; r2 still points to the block!

        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        TEQ     r6, #0                          ; Was there an earlier error?
        MOVNE   r0, r6                          ; Restore it and set V
        SETV    NE

; If there was no earlier error (ie. r6 = 0) then any error from the
; OS_Module Free call is returned.

        EXIT


; OSS Translate an error block, with one substituted parameter.

; In:   r0 -> Error block containing the token
;       r1 -> %0 parameter to substitute

; Out:  r0 -> Translated error block or another error (token no found etc.)
;       All other registers preserved, V always set, other flags undefined

copy_error_one Entry "r2-r7"
  [  DebugModule
        DLINE   "Copy_Error_One called"
  ]
        BL      open_message_file               ; Ensure file is open
        EXIT    VS                              ; Return the error

        MOV     r4, r1                          ; Move input %0
        ADR     r1, message_file_block          ; Messages file handle
        MOV     r2, #0                          ; Use MessageTrans buffer
        MOV     r5, #0                          ; No %1
        MOV     r6, #0                          ; No %2
        MOV     r7, #0                          ; No %3
        SWI     XMessageTrans_ErrorLookup       ; Always sets the V flag

        MOV     r1, r4                          ; Preserve input r1
        EXIT

; Same as copy_error_one() but with no parameter.

copy_error_zero Entry "r1"
        MOV     r1, #0                          ; No %0
        BL      copy_error_one
        EXIT

message_filename
        DCB     "Resources:$.Resources.Podule.Messages", 0
        ALIGN


; OSS Open the messages file if it is closed.

open_message_file
        ROUT
        Push    "r0-r2, lr"
        LDR     r14, message_file_open
        CMP     r14, #0                         ; Check the open flag, clearing V
        BNE     ExitOpenMessageFile             ; Return - it is open
        ADR     r0, message_file_block          ; Messages file handle
        ADR     r1, message_filename            ; Messages filename
        MOV     r2, #0                          ; Buffer in RMA/access direct
        SWI     XMessageTrans_OpenFile
        MOVVC   r1, #1
        STRVC   r1, message_file_open           ; Flag the file as open
ExitOpenMessageFile
        STRVS   r0, [ sp, #0 ]                  ; Return the error
        Pull    "r0-r2, pc"

; TMD Close the messages file if it is open.
; All registers preserved except if we get an error, in which case R0 -> error

close_message_file
        ROUT
        Push    "r0, lr"
        LDR     r0, message_file_open
        CMP     r0, #0                          ; NB clears V
        MOVNE   r0, #0
        STRNE   r0, message_file_open           ; always mark as closed even if we're going to get error
        ADRNE   r0, message_file_block
        SWINE   XMessageTrans_CloseFile
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, pc"

SoftloadErrorMssg
        ; in:  r0=pointer to message token
        ;      r2=pointer to target block
        ;      wp=pointer to workspace
        ; out: all registers preserved (except r0 if the message file is duff)

        Entry   "r0-r7"
        BL      open_message_file               ; Ensure file is open
        STRVS   r0, [ sp, #0 ]
        EXIT    VS                              ; Return the error
        ADR     r1, message_file_block
        MOV     r3, #InfoBufLength
      [ DebugInit
        DREG    r0,"Error block at &"
        DREG    r1,"MessageTrans block at &"
        DREG    r2,"Target buffer &"
      ]
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
      [ DebugInit
        DREG    r0,"R0 now points to &"         ; Quick look for a token not found error
      ]
        CLRV
        EXIT

EasyLookup ROUT
        ;       In:  R1 Pointer to token
        ;       In:  R4 Single parameter to substitute
        ;       Out: R2 Pointer to looked up message in an error buffer
        ;       Out: R3 Length including terminator

        Push    "r0, r1, r3, r5, r6, r7, lr"
        BL      open_message_file
  [  DebugMssgs
        BVC     %71
        ADD     r14, r0, #4
        DSTRING r14, "Error from open_message_file: "
71
  ]
        ADRVC   r0, message_file_block                  ; Message file handle
        MOV     r2, #0                                  ; No buffer, expand in place
        MOV     r3, #0
        MOV     r5, #0                                  ; No %1
        MOV     r6, #0                                  ; No %2
        MOV     r7, #0                                  ; No %3
  [ DebugMssgs :LOR:  DebugCommands
        BVS     ExitEasyLookup
        DREG    r0, "R0 = &", cc
        Push    r14
        LDR     r14, [ r0, #0 ]
        DREG    r14, ", &", cc
        LDR     r14, [ r0, #4 ]
        DREG    r14, ", &", cc
        LDR     r14, [ r0, #8 ]
        DREG    r14, ", &", cc
        LDR     r14, [ r0, #12 ]
        DREG    r14, ", &"
        Pull    r14
        DREG    r1, "R1 = &", cc
        DSTRING r1, " token is: "
        DREG    r2, "R2 = &"
        DREG    r3, "R3 = &"
        DREG    r4, "R4 = &", cc
        DSTRING r4, " %0 is: "
        DREG    r5, "R5 = &", cc
        DSTRING r5, " %1 is: "
        DREG    r6, "R6 = &", cc
        DSTRING r6, " %2 is: "
        DREG    r7, "R7 = &", cc
        DSTRING r7, " %3 is: "
        DREG    r8, "R8 = &"
        DREG    r9, "R9 = &"
        DREG    r10, "R10 = &"
        DREG    r11, "R11 = &"
        DREG    r12, "R12 = &"
        DREG    r13, "R13 = &"
        DREG    r14, "R14 = &"
        DREG    r15, "R15 = &"
  ]
        SWIVC   XMessageTrans_Lookup
  [  DebugMssgs
        BVC     %76
        ADD     r14, r0, #4
        DSTRING r14, "Error from XMessageTrans_Lookup: "
76
  ]
        BVS     ExitEasyLookup
        ADD     r3, r3, #1                              ; Allow for the terminator
        STR     r3, [ sp, #8 ]                          ; Poke into the return frame
        LDR     r0, [ sp, #4 ]                          ; Get the token pointer
        DEC     r0, 4                                   ; Pretend it is an error pointer
        ADR     r1, message_file_block                  ; Message file handle
        MOV     r2, #0                                  ; No buffer, expand into a buffer
        MOV     r3, #0
        SWI     XMessageTrans_ErrorLookup
  [  DebugModule
        ADD     r14, r0, #4
        DSTRING r14, "Error from XMessageTrans_ErrorLookup: "
  ]
        CLRV
        ADD     r2, r0, #4                              ; Skip over the error number
ExitEasyLookup
  [ DebugMssgs :LOR:  DebugCommands
        Push    "r0, r1"
        ADR     r0, message_file_block                  ; Message file handle
        DREG    r0, "R0 = &", cc
        LDR     r1, [ r0, #0 ]
        DREG    r1, ", &", cc
        LDR     r1, [ r0, #4 ]
        DREG    r1, ", &", cc
        LDR     r1, [ r0, #8 ]
        DREG    r1, ", &", cc
        LDR     r1, [ r0, #12 ]
        DREG    r1, ", &"
        Pull    "r0, r1"
  ]
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r1, r3, r5, r6, r7, pc"

        ROUT

        LTORG

        [ :LNOT: ReleaseVersion
        InsertDebugRoutines
        ]

        END
