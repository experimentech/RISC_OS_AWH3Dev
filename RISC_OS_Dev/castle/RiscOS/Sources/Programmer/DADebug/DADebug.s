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
; ***********************************
; ***    C h a n g e   L i s t    ***
; ***********************************

; Date       Version  Name  Description
; ----       -------  ----  -----------
; 24-May-99  0.01     BJGA  Initial version
; 28-Oct-99  0.02     BJGA  DADWriteC made APCS compliant
; 30-Mar-00  0.03     BJGA  Checks Escape state during DADPrint
; 01-Feb-01  0.04     BJGA  32-bit compatible
; 30-Jun-09  0.05     JL    Support for running from ROM, TickerPrint for keyboardless debugging
; 25-Nov-10  0.06     JL    Rewrote to store workspace & DADWriteC in the RMA instead of using a OS_Module 11 hack to allow for running from ROM


; Compile-time options

        GBLA    DAsize
DAsize  SETA    400 * 1024                      ; size of dynamic area to use

            GBLL TickerPrint
TickerPrint SETL {FALSE}     ; TRUE to call *dadprint at 60 second intervals (for tricky bugs where keyboard input isn't possible!)

            GBLL UseHAL
UseHAL      SETL {FALSE}     ; TRUE to cause *dadprint to use HAL_DebugTX instead of OS_WriteC

            GBLL NoWrap
NoWrap      SETL {FALSE}     ; TRUE to prevent wrapping of output buffer

; Includes

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:Proc
        GET     Hdr:ModHand
        GET     VersionASM
 [ UseHAL
        GET     Hdr:HALEntries
 ]


; Module header
                AREA      |DADebug$$Code|, CODE, READONLY, PIC

                ENTRY

Module_BaseAddr
        &       0; Start
        &       Initialise - Module_BaseAddr
        &       Finalise - Module_BaseAddr
        &       0; Service
        &       Title - Module_BaseAddr
        &       Help - Module_BaseAddr
        &       CommandTable - Module_BaseAddr
        &       DADebugSWI_Base
        &       SWIHandler - Module_BaseAddr
        &       SWITable - Module_BaseAddr
        &       0 ; SWI decoding code
        [ {FALSE} ; International_Help <> 0
        &       MessagesFile - Module_BaseAddr
        |
        &       0
        ]
        &       ModuleFlags - Module_BaseAddr

Help
        =       "DADebug", 9, "$Module_MajorVersion ($Module_Date)"
        [ Module_MinorVersion <> ""
        =       " $Module_MinorVersion"
        ]
        =       0
Title
SWITable
        =       "DADebug", 0
        =       "GetWriteCAddress", 0
        =       "Print", 0
        =       "Reset", 0
        =       0
        ALIGN

ModuleFlags
        [ No32bitCode
        &       0
        |
        &       ModuleFlag_32bit
        ]

; This bit gets copied into the RMA
Workspace_Begin
        & -1 ; ReadPtr
        & -1 ; WritePtr
        & -1 ; BufferStart
        & -1 ; DAnumber
Workspace_DADWriteC
; In: R0 = character to insert
;     R14 = return address
;     Assumed not in USR mode
; Out: all registers and flags must be preserved
        EntryS  "R0-R3"
        SETPSR  I_bit, R14

        ADR     R14, Workspace_Begin
        ASSERT  ReadPtr = 0
        LDMIA   R14, {R1-R3}     ; load ReadPtr, WritePtr, BufferStart

        STRB    R0, [R3, R2]     ; write the byte
        ADD     R2, R2, #1       ; increment write pointer
        TEQ     R2, #DAsize      ; with wrap
        MOVEQ   R2, #0

        TEQ     R1, R2           ; if WritePtr hasn't caught up with ReadPtr
        STRNE   R2, [R14, #WritePtr] ; just update WritePtr
      [ :LNOT: NoWrap
        EXITS   NE, cxsf         ; and exit restoring interrupt state

01      LDRB    R0, [R3, R1]     ; read byte at ReadPtr
        ADD     R1, R1, #1       ; increment ReadPtr
        TEQ     R1, #DAsize      ; with wrap
        MOVEQ   R1, #0
        TEQ     R0, #10          ; and repeat until we find the next LF
        TEQNE   R1, R2           ; or until we run back into the WritePtr (!)
        BNE     %BT01

        STMIA   R14, {R1, R2}    ; update ReadPtr and WritePtr
      ]
        EXITS   , cxsf           ; exit restoring interrupt state
Workspace_End

; Workspace. Contains a copy of the DADWriteC code, to allow DADebug to work from ROM without DADWriteC needing a workspace pointer
                ^ 0
ReadPtr         #       4
WritePtr        #       4
BufferStart     #       4
DAnumber        #       4
DADWriteC       #       Workspace_End-Workspace_DADWriteC
Workspace_Size  * @


Initialise
        Entry   "R7-R9"
        MOV     R0, #6
        MOV     R3, #Workspace_Size
        SWI     XOS_Module
        EXIT    VS
        STR     R2, [R12]
        ADR     R0, Workspace_Begin
        MOV     R1, R2
01
        LDR     R4, [R0],#4
        STR     R4, [R2],#4
        SUBS    R3, R3, #4
        BNE     %BT01
        MOV     R0, #1
        SWI     XOS_SynchroniseCodeAreas
        MOV     R9, R1
        MOV     R0, #0           ; create dynamic area
        MOV     R1, #-1
        MOV     R2, #DAsize
        MOV     R3, #-1
        MOV     R4, #&80         ; non-draggable
        MOV     R5, #DAsize
        MOV     R6, #0
        MOV     R7, #0
        ADRL    R8, Title
        SWI     XOS_DynamicArea
        EXIT    VS
        STR     R1, [R9, #DAnumber]
        STR     R3, [R9, #BufferStart]

        BL      DADReset_Code    ; preserves V (clear)
 [ TickerPrint
        MOV     R0, #&1780 ; 60 seconds (ish)
        ADR     R1, DADPrint_Code
        MOV     R2, R12
        SWI     XOS_CallEvery
 ]
        EXIT

Finalise
        Entry
        LDR     R2, [R12]
 [ TickerPrint
        ADR     R0, DADPrint_Code
        MOV     R1, R12
        SWI     XOS_RemoveTickerEvent
 ]
        MOV     R0, #1 ; remove dynamic area
        LDR     R1, [R2, #DAnumber]
        SWI     XOS_DynamicArea
        MOV     R0, #7
        SWI     XOS_Module
        CLRV
        EXIT

CommandTable
        Command DADPrint, 0, 0, 0
        Command DADReset, 0, 0, 0
        =       0

DADPrint_Help
        =       "*DADPrint prints all the debug output collected so far.", 13
DADPrint_Syntax
        =       27, 1, 0
        ALIGN

DADPrint_Code
 [ UseHAL
        Entry   "r0-r6,r8-r9"
        MOV     R8, #0
        MOV     R9, #EntryNo_HAL_DebugTX
 |
        Entry   "r0-r2,r4-r6"
 ]
        LDR     R14, [R12]
        ASSERT  ReadPtr = 0
        LDMIA   R14, {R4-R6}     ; load ReadPtr, WritePtr, BufferStart

01      LDRB    R0, [R6, R4]     ; read a byte
 [ UseHAL
        SWI     XOS_Hardware
 |
        SWI     XOS_WriteC
 ]
        CMN     R0, #0           ; clear C
        TEQ     R0, #10          ; at the end of each line,
        SWIEQ   XOS_ReadEscapeState ; check for Escape
        BCS     %FT02
        ADD     R4, R4, #1       ; increment read pointer
        TEQ     R4, #DAsize      ; with wrap
        MOVEQ   R4, #0
        TEQ     R4, R5
        BNE     %BT01            ; and loop until we reach WritePtr

02      MOV     R0, #126
        SWI     XOS_Byte         ; acknowledge any Escape event
        ; Note that we don't write anything back
        CLRV
        EXIT

DADReset_Help
        =       "*DADReset clears the store of debug output.", 13
DADReset_Syntax
        =       27, 1, 0
        ALIGN

DADReset_Code
        Entry   "r12"
        SETPSR  I_bit, R14,, R2  ; disable interrupts

        LDR     R12, [R12]
        MOV     R0, #0
        STR     R0, [R12, #ReadPtr]
        STR     R0, [R12, #WritePtr]

        ADR     R1, DefaultStartString
01      LDRB    R0, [R1], #1
        TEQ     R0, #0
        MOVNE   LR, PC
        ADDNE   PC, R12, #DADWriteC ; Preserves flags
        BNE     %BT01

        RestPSR R2               ; restore interrupt state
        EXIT                     ; V flag unchanged from entry

DefaultStartString
        =       "Debug start", 13, 10, 0

SWIHandler ROUT
        CMP     R11, #(EndOfJumpTable - JumpTable)/4
        ADDLO   PC, PC, R11, LSL #2
        B       UnknownSWIError
JumpTable
        B       SWIDADebug_GetWriteCAddress
        B       DADPrint_Code
        B       DADReset_Code
EndOfJumpTable

UnknownSWIError
        MOV     PC, LR           ; don't actually return an error for now

SWIDADebug_GetWriteCAddress
        LDR     R12, [R12]
        ADD     R0, R12, #DADWriteC
        MOV     PC, LR
        
Module_End

        END
