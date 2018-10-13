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
        GET     Hdr:ModHand
        GET     Defs.s
        GET     Hdr:Proc
        GET     VersionASM

        GBLL    debug
debug   SETL    {FALSE}

        AREA    |Asm$$Code|, CODE, READONLY

Module_BaseAddr

; **************** Module code starts here **********************

        ASSERT  (.-Module_BaseAddr) = 0

        DCD     0 ; Messages_Start    - Module_BaseAddr
        DCD     Messages_Init     - Module_BaseAddr
        DCD     Messages_Die      - Module_BaseAddr
        DCD     Messages_Service  - Module_BaseAddr
        DCD     Messages_Title    - Module_BaseAddr
        DCD     Messages_HelpStr  - Module_BaseAddr
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     Messages_Flags    - Module_BaseAddr

Messages_Title          DCB     "Messages", 0
Messages_HelpStr        DCB     "UK Messages", 9, "$Module_HelpVersion", 0
                        ALIGN

Messages_Flags          DCD     ModuleFlag_32bit

; *****************************************************************************
;
;       Messages_Init - Initialisation entry
;

Messages_Init
        Entry
        BL      GetResourceAddress      ; r0 -> resource block list
        ADRVC   r2, Register
        BLVC    ResourceLoop
        EXIT

Register
        Entry
        SWI     XResourceFS_RegisterFiles
        EXIT

; *****************************************************************************
;
;       Messages_Die - Die entry
;

Messages_Die
        Entry
        BL      GetResourceAddress      ; r0 -> resource block list
        ADRVC   r2, Deregister
        BLVC    ResourceLoop
        ADDS    r0, r0, #0              ; clear V
        EXIT

Deregister
        Entry
        SWI     XResourceFS_DeregisterFiles
        EXIT

; *****************************************************************************
;
;       Messages_Service - Main entry point for services
;
; in:   r1 = service reason code
;       r2 = sub reason code
;       r3-r5 parameters
;
; out:  r1 = 0 if we claimed it
;       r2 preserved
;       r3-r5 = ???
;

; Ursula format

UServiceTable
        DCD     0
        DCD     UService - Module_BaseAddr
        DCD     Service_ResourceFSStarting
        DCD     0
        DCD     UServiceTable - Module_BaseAddr
Messages_Service ROUT
        MOV     r0, r0
        TEQ     r1, #Service_ResourceFSStarting
        MOVNE   pc, lr

UService

; In    r2 -> address inside ResourceFS module to call
;       r3 = workspace pointer for module
; Out   r2 called with r0 -> files, r3 -> workspace

svc_desktopstarting
        Entry   "r0-r5"
        BL      GetResourceAddress
        BL      ResourceLoop
        EXIT

; *****************************************************************************
;
;       ResourceLoop
;
; in:   r0 -> list of resource blocks
;       r2 -> routine to call on each block (may corrupt r0 only, VS for failure)
;       r3 = workspace for routine
;
; out:  r0 -> error if VS
;       r0-r5 corrupted
;

ResourceLoop
        Entry
        MOV     r4, r0
        SWI     XTerritory_Number
        MOVVS   r5, #0
        MOVVC   r5, r0                  ; r5 = territory number

        ADR     r6, TerritoryList       ; r6 = list of present territories

CT_loop
        LDRB    lr, [r6], #1            ; compare territories
        CMP     lr, #&FF                ; &FF = no more territories in list
        LDREQB  r5, TerritoryList       ; if not found, select the first one
        CMPNE   r5, lr                  ; does it exist in the rom?
        BNE     CT_loop

RL_blockloop
        LDR     lr, [r4], #4            ; for each block
        CMP     lr, #-1                 ; check for first word -1 terminator
        EXIT    EQ

RL_territoryloop
        TEQ     lr, r5                  ; loop through territory list -
        TEQNE   lr, #0                  ; is it for our territory, or common?
        BEQ     RL_forus

        CMP     lr, #-1                 ; territory list terminated by -1
        LDRNE   lr, [r4], #4            ; more territories to go?
        BNE     RL_territoryloop
        B       RL_nextblock            ; not for our territory

RL_forus                                ; our territory is in the list
        LDR     lr, [r4], #4            ; wind forward to end of list
        CMP     lr, #-1
        BNE     RL_forus

        MOV     r0, r4
        MOV     lr, pc
        MOV     pc, r2                  ; call the routine on this block
        EXIT    VS

RL_nextblock
        MOV     lr, #0                  ; loop to end of ResourceFS block
60      LDR     lr, [r4, lr]!
        TEQ     lr, #0
        BNE     %BT60

        ADD     r4, r4, #4              ; and move on to the next block
        B       RL_blockloop


        GET     LocaleList.s

        END
