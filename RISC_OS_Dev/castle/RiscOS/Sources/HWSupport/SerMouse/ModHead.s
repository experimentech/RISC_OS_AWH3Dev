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

        DCD     0                               ; Start
        DCD     Init           - Module_BaseAddr
        DCD     Die            - Module_BaseAddr
        DCD     Service        - Module_BaseAddr
        DCD     Title          - Module_BaseAddr
        DCD     Helpstr        - Module_BaseAddr
        DCD     0                               ; Helptable
        DCD     0                               ; SWIbase
        DCD     0                               ; SWIhandler
        DCD     0                               ; SWInames
        DCD     0                               ; SWIdecode
        DCD     0
        DCD     ModFlags       - Module_BaseAddr

;---------------------------------------------------------------------------
Title   DCB     "SerialMouse",0
Helpstr DCB     "SerialMouse",9,"$Module_HelpVersion",0
                ALIGN
ModFlags
        DCD     ModuleFlag_32bit

;---------------------------------------------------------------------------
;       Module initialisation point.
;
Init
        Entry

        LDR     r2, [r12]                       ; Have we already got a workspace?
        CMP     r2, #0
        BNE     %FT01

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =max_running_work
        SWI     XOS_Module                      ; Claim workspace.
        EXIT    VS

        STR     r2, [r12]                       ; Store workspace pointer.
01
        MOV     r12, r2

 [ standalone
        ADR     r0, resourcefsfiles
        SWI     XResourceFS_RegisterFiles
 ]

        MOV     r0, #0                          ; Initialise workspace.
 [ international
        STR     r0, message_file_open
 ]
        STR     r0, SerialInHandle

        BL      StartUp

        BLVS    ShutDown
        EXIT

;---------------------------------------------------------------------------
;       Start up code.
;
StartUp
        Entry   "r1,r2"

        Debug   mod,"SM_StartUp"

        MOV     r0, #PointerV           ; Claim PointerV during lifetime.
        ADR     r1, PointerRequest
        MOV     r2, r12
        SWI     XOS_Claim

        MOVVC   r0, #0                  ; Get current pointer type.
        SWIVC   XOS_Pointer
        MOVVC   r1, r0
        BLVC    PointerSelected         ; Enable if one of ours.

        EXIT

;---------------------------------------------------------------------------
;       Service handler.
;
ServiceTable
	DCD	0			; flag word
	DCD     ServiceUrsula - Module_BaseAddr
	DCD	Service_Reset
 [ standalone
	DCD	Service_ResourceFSStarting
 ]
	DCD	0
	DCD	ServiceTable - Module_BaseAddr

Service
	MOV	r0,r0			; nop to indicate service table present
        TEQ     r1, #Service_Reset
 [ standalone
        TEQNE   r1, #Service_ResourceFSStarting
 ]
        MOVNE   pc, lr

ServiceUrsula
        LDR     r12, [r12]

        TEQ     r1, #Service_Reset
        BEQ     StartUp

 [ standalone
        TEQ     r1, #Service_ResourceFSStarting
        MOVNE   pc, lr

        Entry   "r0-r3"
        ADR     r0, resourcefsfiles
        MOV     lr, pc
        MOV     pc, r2
        EXIT
 |
        MOV     pc, lr
 ]

;---------------------------------------------------------------------------
;       Killing the module.
;
Die
        Entry

        LDR     r12, [r12]
        CMP     r12, #0
        Pull    "pc",EQ

        BL      ShutDown

        EXIT

;---------------------------------------------------------------------------
;       Tidy up before dying.
;       out:  preserves all registers and flags.
;
ShutDown
        EntryS  "r0-r2"

        Debug   mod,"SM_ShutDown"

        BL      Disable                         ; Disable if we are enabled.

        MOV     r0, #PointerV
        ADR     r1, PointerRequest
        MOV     r2, r12
        SWI     XOS_Release

 [ international
        LDR     r0, message_file_open           ; Close the message file if it's open.
        TEQ     r0, #0
        ADRNE   r0, message_file_block
        SWINE   XMessageTrans_CloseFile
 ]

 [ standalone
        ADR     r0, resourcefsfiles
        SWI     XResourceFS_DeregisterFiles
 ]

        EXITS                                   ; Ignore errors, preserve flags

        END
