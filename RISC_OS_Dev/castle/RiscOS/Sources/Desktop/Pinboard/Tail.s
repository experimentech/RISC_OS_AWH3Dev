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
; > Sources.Tail

ReportError
        Push    "r1-r3,lr"

        Debug   sa,"error reported."

        MOV     R14,R0                  ; usr mode

        [ {FALSE}                       ; just  a test
        MOV     R1,#1                   ; OK box
        ADRL    R2,Title
        SWI     XWimp_ReportError
        ]

        LDR     R0,mytaskhandle
        SWI     XTaskManager_TaskNameFromHandle       ; get task name
        MOVVC   R2,R0

        [ {FALSE}
        ADR     r0,message_file_block+4
        ADRL    r1,tasktitle
        ADR     r2,dataarea
        MOV     r3,#&100
        SWI     XMessageTrans_Lookup
        ]

        ADRVSL  r2,Title
        MOV     R0,R14
        MOV     R1,#1                   ; OK box
        SWI     XWimp_ReportError
        Pull    "r1-r3,pc"

msgtrans_openfile
        Push    "r0-r2,LR"
        LDR     r0,message_file_block
        TEQ     r0,#0                           ; Make sure it's not already open
        Pull    "r0-r2,PC",NE
        ADR     r0,message_file_block+4
        ADR     r1,message_filename
        MOV     r2,#0
        SWI     XMessageTrans_OpenFile
        STRVS   r0,[sp]
        MOVVC   r2,#-1
        STRVC   r2,message_file_block
        Pull    "r0-r2,PC"

message_filename
        DCB     "Pinboard:Messages",0
        ALIGN

msgtrans_closefile
        EntryS  "r0"
        LDR     r0,message_file_block
        TEQ     r0,#0
        MOVNE   r0,#0
        STRNE   r0,message_file_block
        ADRNE   r0,message_file_block+4
        SWINE   XMessageTrans_CloseFile
        EXITS

msgtrans_errorlookup
; In:   r0->token error block
;       r4-r6->parameters
; Out:  r0->error block & V set
        Push    "LR"
        LDR     r1,message_file_block
        TEQ     r1,#0                           ; Do Global lookup if message file not open
        ADRNE   r1,message_file_block+4
        MOV     r2,#0                           ; Use MessageTrans buffer
        SWI     XMessageTrans_ErrorLookup
        Pull    "PC"

      [ useECFforLCD
; Set up ECF for LCD backdrop
setupECF
        Push    "r0-r4,lr"
        Debug   bd,"Setting up ECF"

        LDR     r0,=&00000000
        SWI     XColourTrans_ReturnColourNumber
        MOV     r3,r0
        LDR     r0,=&FFFFFF00
        SWI     XColourTrans_ReturnColourNumber
        MOV     r4,r0

        MOV     r0,#-1
        MOV     r1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable
        MOV     r1,#1
        MOV     r2,r1,LSL r2

        ORR     r0,r3,r4,LSL r2
        ORR     r1,r4,r3,LSL r2

10      MOV     r2,r2,LSL #1
        ANDS    r2,r2,#31
        ORRNE   r0,r0,r0,LSL r2
        ORRNE   r1,r1,r1,LSL r2
        BNE     %BT10

        ADR     r2,backdropECF
        Debug   bd,"ECF at ",r2
        STMIA   r2!,{r0,r1}
        STMIA   r2!,{r0,r1}
        STMIA   r2!,{r0,r1}
        STMIA   r2!,{r0,r1}
        Pull    "r0-r4,pc"
      ]

; Set icon_bar_height depending on mode
set_icon_bar_height
        Push    "r0-r2,lr"
    [ noiconbar
        MOV     r0, #0
    |
        MOV     r0, #-1                 ; Get YEig for current mode
        MOV     r1, #VduExt_YEigFactor
        SWI     XOS_ReadModeVariable
        MOV     r0, #default_icon_bar_height
        MOVVC   r1, #1                  ; 1 unit top border
        ADDVC   r0, r0, r1, LSL r2      ; Convert to pixels
10
    ]
        Debug   bd,"Iconbar height = ",r0
        STR     r0, icon_bar_height
        Pull    "r0-r2,pc"

; Read the mode variables
read_mode_variables     ROUT
        Entry   "R0-R6"
        ADR     r0, vdu_input_block
        SUB     SP,SP,#4*4
        MOV     r1, SP
        SWI     XOS_ReadVduVariables
        STRVS   r0, [sp, #4*4]!
        EXIT    VS
        LDMIA   sp!, {r2,r3,r4,r5}
        ADD     r2,r2,#1
        ADD     r3,r3,#1
        MOV     r4, r2, LSL r4
        MOV     r5, r3, LSL r5
        MOV     r2, #0
        MOV     r3, #0
        ADR     r1, bounding_box
        STMIA   r1, {r2,r3,r4,r5}
        EXIT

GetMonotonicID  ROUT
        Push    "LR"
        LDR     R4,MonotonicID
        ADD     R4,R4,#1
        STR     R4,MonotonicID
        Pull    "PC"

;-------------------------------------------------

Copy_r0r1       ROUT
        Push    "LR"
01
        LDRB    r14,[r0],#1
        STRB    r14,[r1],#1
        CMP     r14,#0
        BNE     %BT01

        SUB     r1,r1,#1        ; r1 -> Null
        Pull    "PC"

;-------------------------------------------------

Copy_r1r0       ROUT
        Push    "LR"
01
        LDRB    r14,[r1],#1
        STRB    r14,[r0],#1
        CMP     r14,#0
        BNE     %BT01

        SUB     r0,r0,#1        ; r0 -> Null
        Pull    "PC"

;-----------------------------------------------
;strlen
;
;Entry:
;       r2 -> string
;Exit:
;       r3 = length including null
;

strlen  ROUT

        EntryS
        MOV     r3,r2
01
        LDRB    r14,[r3],#1
        CMP     r14,#0
        BNE     %BT01

        SUB     r3,r3,r2
        EXIT
;--------------------------------------------------------------------------------------

read_copy_options
        Push    "R0-R4,LR"

        MOV     r0, #OsByte_ReadCMOS
        MOV     r1, #DesktopCMOS
        SWI     XOS_Byte
        ADDVS   sp, sp, #4
        Pull    "R1-R4,PC",VS
        ADR     r0, copy_options
        MOV     r1, #"~"
        MOV     r4, #0
; Force option (bit 4)
        MOV     r3, #"F"
        TST     r2, #2_00010000
        ORRNE   r4, r4, #2_0100
        STRB    r3, [r0], #1
; Confirm option (bit 5)
        MOV     r3, #"C"
        TST     r2, #2_00100000
        STREQB  r1, [r0], #1
        ORRNE   r4, r4, #2_0010
        STRB    r3, [r0], #1
; Verbose option (bit 6)
        MOV     r3, #"V"
        TST     r2, #2_01000000
        STREQB  r1, [r0], #1
        ORRNE   r4, r4, #2_0001
        STRB    r3, [r0], #1
; Newer option (bit 7)
        MOV     r3, #"N"
        TST     r2, #2_10000000
        STREQB  r1, [r0], #1
        ORRNE   r4, r4, #2_1000
        STRB    r3, [r0], #1
; Extra options
        ADR     r1, other_options
        BL      Copy_r1r0
        STR     r4, filer_action_copy_options
        Pull    "R0-R4,PC"
other_options
        DCB     "~L~P~QR~T",0
        ALIGN

;----------------------------------------------------------------------------------------------------------------

vdu_input_block
        DCD     VduExt_XWindLimit, VduExt_YWindLimit
        DCD     VduExt_XEigFactor, VduExt_YEigFactor
        DCD     -1
        ALIGN

; ----------------------------------------------------------------------------------------------------------------------
; Neil's debugging routines

      [ debug
        InsertNDRDebugRoutines
      ]

        END
