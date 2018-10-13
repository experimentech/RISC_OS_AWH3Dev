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
; > Sources.ModHead

        ASSERT  (.=Module_BaseAddr)

        DCD     0
        DCD     Init           - Module_BaseAddr
        DCD     Die            - Module_BaseAddr
        DCD     Service        - Module_BaseAddr
        DCD     Title          - Module_BaseAddr
        DCD     Helpstr        - Module_BaseAddr
        DCD     0
      [ :LNOT: No32bitCode
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     ModFlags       - Module_BaseAddr
      ]

; --------------------------------------------------------------------------

Title            DCB     "$Territory",0
Helpstr          DCB     "$Help",9,"$Module_HelpVersion"
      [ standalone
                 DCB     " Standalone"
      ]
                 DCB     0

Path             DCB     "$Territory$$Path",0
PathDefault      DCB     "Resources:$.Resources.$Territory..",0 ; NB first dot terminates substitution
message_filename DCB     "$Territory:Messages",0
                 ALIGN

      [ :LNOT: No32bitCode
ModFlags         DCD     ModuleFlag_32bit
      ]

; --------------------------------------------------------------------------
;       Module initialisation point
Init
        Push    "r0-r4,LR"

        ADR     r0, Path
        MOV     r2, #-1
        MOV     r3, #0
        MOV     r4, #VarType_Expanded
        SWI     XOS_ReadVarVal
        CMP     r2, #0

        ADREQ   r0, Path
        ADREQ   r1, PathDefault
        MOVEQ   r2, #?PathDefault
        MOVEQ   r3, #0
        MOVEQ   r4, #VarType_String
        SWIEQ   XOS_SetVarVal

      [ standalone
        ADRL    r0, ResourceFiles
        SWI     XResourceFS_RegisterFiles
      ]

        LDR     r0, [r12]
        CMP     r0, #0                  ; clears V
        MOVNE   r12,r0
        BNE     %FT01

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =max_running_work
        SWI     XOS_Module
        ADDVS   sp,sp,#4
        Pull    "r1-r4,PC",VS
        STR     r2, [r12]
        MOV     r12, r2
        MOV     r0, #0
        STRB    r0, message_file_open
01
      [ JapaneseEras
        ; Build era table.
        BL      SetUpEras
      ]

        ; Build entry table.
Register

        ADR     r14,scratch_buffer
        ADRL    r0,ReadTimeZones
        STR     r0,[r14],#4
        ADRL    r0,ConvertDateAndTime
        STR     r0,[r14],#4
        ADRL    r0,ConvertStandardDateAndTime
        STR     r0,[r14],#4
        ADRL    r0,ConvertStandardDate
        STR     r0,[r14],#4
        ADRL    r0,ConvertStandardTime
        STR     r0,[r14],#4
        ADRL    r0,ConvertTimeToOrdinals
        STR     r0,[r14],#4
        ADRL    r0,ConvertTimeStringToOrdinals
        STR     r0,[r14],#4
        ADRL    r0,ConvertOrdinalsToTime
        STR     r0,[r14],#4
        ADRL    r0,Alphabet
        STR     r0,[r14],#4
        ADR     r0,AlphabetIdent
        STR     r0,[r14],#4
        ADR     r0,SelectKeyboardHandler
        STR     r0,[r14],#4
        ADR     r0,WriteDirection
        STR     r0,[r14],#4
        ADR     r0,CharacterPropertyTable
        STR     r0,[r14],#4
        ADR     r0,GetLowerCaseTable
        STR     r0,[r14],#4
        ADR     r0,GetUpperCaseTable
        STR     r0,[r14],#4
        ADR     r0,GetControlTable
        STR     r0,[r14],#4
        ADR     r0,GetPlainTable
        STR     r0,[r14],#4
        ADR     r0,GetValueTable
        STR     r0,[r14],#4
        ADRL    r0,GetRepresentationTable
        STR     r0,[r14],#4
        ADRL    r0,Collate
        STR     r0,[r14],#4
        ADRL    r0,ReadSymbols
        STR     r0,[r14],#4
        ADRL    r0,GetCalendarInformation
        STR     r0,[r14],#4
        ADRL    r0,NameToNumber
        STR     r0,[r14],#4
        ADRL    r0,TransformString
        STR     r0,[r14],#4
        ADRL    r0,IME
        STR     r0,[r14],#4
        ADRL    r0,DaylightRules
        STR     r0,[r14],#4

        ASSERT  ?scratch_buffer >= 43*4
        ADR     r0,UnknownEntry         ; Fill remaining with error stubs
        ADR     r1,scratch_buffer+43*4
02      STR     r0,[r14],#4
        CMP     r14,r1
        BLO     %BT02

        MOV     r0,#TerrNum
        ADR     r1,scratch_buffer
        MOV     r2,r12
        SWI     XTerritory_Register     ; Ignore errors.

        CLRV
        Pull    "r0-r4,PC"

UnknownEntry
        Debug   xx,"Territory : Unknown entry"

        ADR     r0,ErrorBlock_OutOfRange
        B       message_errorlookup

ErrorBlock_OutOfRange
        DCD     ErrorNumber_OutOfRange
        DCB     "UnkSWI",0
        ALIGN

; --------------------------------------------------------------
;       Module service entry point
UservTab
        ASSERT  Service_ResourceFSStarting < Service_TerritoryManagerLoaded
        DCD     0                               ; flags
        DCD     UService - Module_BaseAddr
      [ standalone
        DCD     Service_ResourceFSStarting
      ]
        DCD     Service_TerritoryManagerLoaded
        DCD     0                               ; terminator
        DCD     UservTab - Module_BaseAddr      ; anchor
Service
        MOV     r0,r0                           ; magic instruction
        TEQ     r1,#Service_TerritoryManagerLoaded
      [ standalone
        TEQNE   r1,#Service_ResourceFSStarting
      ]
        MOVNE   PC,LR
UService
        LDR     R12, [R12]
        CMP     R12, #0
        MOVEQ   PC, LR

      [ standalone
        TEQ     r1, #Service_ResourceFSStarting
        BNE     %FT10                           ; must be territory manager loaded then
        Push    "r0, LR"
        ADRL    r0, ResourceFiles
        MOV     lr, pc
        MOV     pc, r2                          ; emulate ResourceFS_RegisterFiles
        Pull    "r0, PC"
10        
      ]
        Push    "r0-r4,LR"
        B       Register

; --------------------------------------------------------------
;       RMKill'ing the module
Die
        LDR     r12, [r12]
        CMP     r12, #0                 ; clears V
        MOVEQ   pc, lr

        Push    "lr"
        
        LDR     r0, message_file_open   ; Close the message file if open
        CMP     r0, #0
        ADRNE   r0, message_file_block
        SWINE   XMessageTrans_CloseFile
        MOVVC   r0, #0
        STRVCB  r0, message_file_open
        Pull    "pc", VS

        ; Deregister

        MOV     r0, #TerrNum
        SWI     XTerritory_Deregister

      [ standalone
        ADRL    r0, ResourceFiles
        SWI     XResourceFS_DeregisterFiles
      ]

        CLRV                            ; don't refuse to die
        Pull    "pc"

open_messages_file
        Entry   r0-r2
        LDRB    r0, message_file_open
        CMP     r0, #0
        EXIT    NE
        ADR     r0, message_file_block
        ADRL    r1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        STRVS   r0, [sp]
        MOVVC   r2, #-1
        STRVCB  r2, message_file_open
        EXIT

message_errorlookup
        Entry   r1-r7
        BL      open_messages_file
        EXIT    VS
        MOV     r4, r1
        ADR     r1, message_file_block
        MOV     r2, #0
        SWI     XMessageTrans_ErrorLookup
        EXIT

        LNK     Entries.s
