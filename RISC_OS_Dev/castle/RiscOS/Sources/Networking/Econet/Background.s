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
        SUBT    Interupt handler and Event generator. ==> &.Arthur.Econet.Background

        ALIGN   $Alignment
Interrupt       ROUT
        Push    "lr"
        MOV     r14, #IOC
        LDRB    r14, [ r14, #IOCIRQREQA ]               ; IRQ Request register
        TST     r14, #force_bit                         ; IRQ forced from FIQ
        Pull    "pc", EQ                                ; If it wasn't an FIQ to IRQ down-grade
        LD      r14, FIQStatus
        TEQ     r14, #FIQ_Owner                         ; Are we the owner of FIQ?
        Pull    "pc", NE                                ; If it wasn't us who did it, give it back
        Push    "r0"                                    ; Get a spare unbanked register
        WritePSRc I_bit+SVC_mode, r14,, r0              ; Goto SVC
        Push    "r0-r4, lr"                             ; On supervisor stack
        [       DebugIRQ
        LDR     r2, =Border_Pink
        ADR     r3, VIDC
        STR     r2, [ r3, #0 ]
        ]
InterruptLoop
        SETPSR  F_bit, lr,, r2                          ; Disable FIQ
        MOV     r1, #IOC                                ; Not banked
        LDRB    r0, [ r1, #IOCIRQMSKA ]                 ; IRQ Mask register
        BIC     r0, r0, #force_bit                      ; Must clear it first in case it happens again!
        STRB    r0, [ r1, #IOCIRQMSKA ]                 ; IRQ Mask register
        RestPSR r2                                      ; Enable FIQ
        LD      r0, PeekPokeFlag                        ; First look for a peek or a poke memory check
        TEQ     r0, #0                                  ; Are we down grading a peek or a poke?
        BEQ     InterruptImmediate
        [       DebugIRQ
        LDR     r2, =Border_Grey
        ADR     r3, VIDC
        STR     r2, [ r3, #0 ]
        ]
        MOV     r3, #0
        ST      r3, PeekPokeFlag                        ; Clear the flag
        ADR     r2, ScoutBuffer + 4                     ; Here lies the start and end address+1
        LDMIA   r2, { r0, r1 }
        SWI     XOS_ValidateAddress
        LDR     r1, HardwareAddress                     ; Get the address of our chip
        BVS     DontAllowPeekOrPoke
        BCS     DontAllowPeekOrPoke
        MOV     r0, #2_11100111                         ; RTS, CLRTxST, CLRRxST, FlagIdle, 2Byte, PSE
        STRB    r0, [ r1, #:INDEX:CReg2 ]
        MOV     r0, #2_01000100                         ; RxRS, TxIE ; Start the transmitter interrupting
        STRB    r0, [ r1, #:INDEX:CReg1 ]
        B       InterruptLoop

DontAllowPeekOrPoke
        ; This code is similar to the sequence in the ReInit routine
        ; but it is executed in SVC mode and doesn't exit with RTFIQ
        ; Violently re-initialise things, take no chances
        MOV     r0, #2_11000001                         ; TxReset, RxReset, AC=1
        STRB    r0, [ r1, #:INDEX:CReg1 ]
        MOV     r0, #2_00011110                         ; NRZ, Rx8bits, Tx8bits
        STRB    r0, [ r1, #:INDEX:CReg4 ]
        MOV     r0, #2_00000000                         ; DTR, NONLOOP
        ST      r0, FIQBusy                             ; Show that FIQ is not busy, by storing a zero
        STRB    r0, [ r1, #:INDEX:CReg3 ]
        MOV     r0, #2_10000010                         ; TxReset, RxIE, AC=0
        STRB    r0, [ r1, #:INDEX:CReg1 ]
        MOV     r0, #2_01100111                         ; ClrTxStatus, ClrRxStatus, FlagIdle, 2Byte, PSE
        STRB    r0, [ r1, #:INDEX:CReg2 ]
        SetFIQ  StartReception, r0, r1, Long, Init, r2
        B       InterruptLoop

InterruptImmediate                                      ; Then look for an immediate operation
        LD      r0, LockOut                             ; Get the lockout state
        TEQ     r0, #0
        BEQ     InterruptTxOrRx                         ; No immediate operation outstanding
        [       DebugIRQ
        LDR     r2, =Border_Beige
        ADR     r1, VIDC
        STR     r2, [ r1, #0 ]
        ]
        LDRB    r0, ImmediateRecord + Offset_Control
        ADRL    r1, ArgumentsSize
        LD      r2, ArgumentsAddressOrNumber            ; Procedure number or Call address
        LDRB    r3, ImmediateRecord + Offset_Station
        LDRB    r4, ImmediateRecord + Offset_Network
        TEQ     r0, #BitSeven + Econet_JSR
        BEQ     DoJSR
        MOV     r2, r2, ASL #16
        MOV     r2, r2, ASR #16                                  ; Clear the top 16 bits of the procedure number
        TEQ     r0, #BitSeven + Econet_UserProcedureCall
        MOVEQ   r0, #Event_Econet_UserRPC
        MOVNE   r0, #Event_Econet_OSProc
        [       {FALSE} ; Debug
        DREG    r0, "XOS_GenerateEvent called, R0 = &", cc
        DREG    r1, ", R1 = &", cc
        DREG    r1, ", R2 = &", cc
        DREG    r1, ", R3 = &", cc
        DREG    r1, ", R4 = &"
        ]
        SWI     XOS_GenerateEvent
CancelLockOut
        MOV     r1, #0
        ST      r1, LockOut                             ; Clear the lockout state
        B       InterruptLoop                           ; Start again

DoJSR
        CMP     r2, #-1                                 ; If the call address is -1 then call the buffer
        ADDEQ   r2, r1, #4
        ADR     lr, CancelLockOut
        MOV     pc, r2

InterruptTxOrRx                                         ; Scan both the Tx and Rx lists looking for
                                                        ; the oldest outstanding CB that needs eventing
        ; R0 => Event number to use
        ; R1 => Pointer to the CB to do
        ; R2 => Event sequence number
        [       DebugIRQ
        LDR     r2, =Border_Blue
        ADR     r1, VIDC
        STR     r2, [ r1, #0 ]
        ]
        MOV     r1, #0
        MOV     r2, #Event_NotReady

        ADR     r14, TxCBList - Offset_Link
InterruptTxLoop
        LDR     r14, [ r14, #Offset_Link ]
        TEQ     r14, #NIL                               ; Check for an empty list
        BEQ     InterruptRx
        LDR     r3, [ r14, #Offset_Event ]
        CMP     r3, r2
        MOVLO   r1, r14                                 ; Ready to be evented
        MOVLO   r0, #Event_Econet_Tx
        MOVLO   r2, r3                                  ; The number of the lowest encountered so far
        B       InterruptTxLoop

InterruptRx
        ADR     r14, RxCBList - Offset_Link
InterruptRxLoop
        LDR     r14, [ r14, #Offset_Link ]
        TEQ     r14, #NIL                               ; Check for an empty list
        BEQ     CheckForEvent
        LDR     r3, [ r14, #Offset_Event ]
        CMP     r3, r2
        MOVLO   r1, r14                                 ; Ready to be evented
        MOVLO   r0, #Event_Econet_Rx
        MOVLO   r2, r3                                  ; The number of the lowest encountered so far
        B       InterruptRxLoop

CheckForEvent
        MOVS    r14, r1                                 ; Possible CB pointer
        BEQ     InterruptFinished                       ; No CBs outstanding so start again
        [       DebugIRQ
        LDR     r2, =Border_White
        ADR     r3, VIDC
        STR     r2, [ r3, #0 ]
        ]
        MOV     r1, #Event_Done                         ; Event processed
        STR     r1, [ r14, #Offset_Event ]
        LDR     r1, [ r14, #Offset_Handle ]
        LDRB    r2, [ r14, #Offset_Status ]
        LDRB    r3, [ r14, #Offset_Port ]
        [       {FALSE} ; Debug
        DREG    r0, "XOS_GenerateEvent called, R0 = &", cc
        DREG    r1, ", R1 = &", cc
        DREG    r2, ", R2 = &", cc
        DREG    r3, ", R3 = &", cc
        DREG    r4, ", R4 = &"
        ]
        SWI     XOS_GenerateEvent
        B       InterruptLoop                           ; Start again

InterruptFinished
        [       DebugIRQ
        LDR     r2, =Border_Yellow
        ADR     r3, VIDC
        STR     r2, [ r3, #0 ]
        ]
        Pull    "r0-r4, lr"                             ; Off supervisor stack
        RestPSR r0
        Pull    "r0, lr, pc"                            ; Off IRQ stack

        ALIGN   $Alignment
Event           ROUT
        ;       This is the stuff that actually handles to OSRPCs
        ;       This code will be entered in SWI mode because I called it from SWI mode
        ;       so there is no need to go to SWI mode to preserve R14 in SWIs
        TEQ     r0, #Event_Econet_OSProc
        MOVNE   pc, lr
        TEQ     r2, #Econet_OSCharacterFromNotify       ; Bottom byte of RPC number is what to do
        BEQ     InsertCharacter
        TEQ     r2, #Econet_OSCauseFatalError
        BEQ     CauseFatalError
        MOVNE   pc, lr

InsertCharacter
        [       {FALSE} ; Debug
        DREG    r0, "InsertCharacter called, R0 = &", cc
        DREG    r1, ", R1 = &", cc
        DREG    r2, ", R2 = &", cc
        DREG    r3, ", R3 = &", cc
        DREG    r4, ", R4 = &"
        ]
        MOV     r0, #OsByte_InsertBufferedChar
        LDRB    r2, [ r1, #4 ]                          ; Pick up the character from the buffer
        MOV     r1, #0
        MOV     r3, lr
        SWI     XOS_Byte
        MOV     pc, r3

CauseFatalError
        MOV     r1, #0
        ST      r1, LockOut                             ; Clear the lockout state
        ADR     r0, ErrorRemoted
        ADR     lr, ExecuteFatalError
        B       MakeError
ExecuteFatalError
        SWI     OS_GenerateError

ErrorRemoted
        DCD     ErrorNumber_Remoted
        DCB     "Remoted", 0
        ALIGN

        LTORG

        OPT     OptPage
        ALIGN   $Alignment
Pacemaker       ROUT
        ;       Entered from the Ticker vector
        ;       And wp has the expected value, and doesn't need to be preserved
        ;       We will be in either IRQ or SVC mode with a valid stack
        Push    "r6, r7, lr"                            ; Note use of Non FIQ registers
        LD      r6, Time                                ; Also saves the IRQ state, which isn't assumed
        INC     r6
        ST      r6, Time
        LD      r7, FIQStatus
        TEQ     r7, #FIQ_PoweredDown                    ; Is it OK to do anything?
        Pull    "r6, r7, pc", EQ                        ; No we aren't even alive
        Push    "r2-r5"
        SavePSR r5                                      ; Save mode in r5, should be IRQ might just be SVC
        LD      r7, TxCBList                            ; Now check the transmit queue to see what needs restarting
        B       %30

CheckTxList
        LDRB    r14, [ r7, #Offset_Status ]
        TEQ     r14, #Status_TxReady
        BNE     %20
        LDR     r14, [ r7, #Offset_Time ]
        CMP     r6, r14
        BPL     RestartRecord
20
        LDR     r7, [ r7, #Offset_Link ]
30
        TEQ     r7, #NIL
        BNE     CheckTxList
    [ PerthPowerDown
        ;       Now check if it is Power Down time yet
        LDR     r7, PowerDownTime
        CMP     r7, r6
        BGT     NoPowerDownYet                          ; Not time yet
        LDR     r7, TxCBList
40
        TEQ     r7, #NIL
        BEQ     %50                                     ; No TxCBs, check for RxCBs
        LDRB    r14, [ r7, #Offset_Status ]
        TEQ     r14, #Status_TxReady
        TEQNE   r14, #Status_Transmitting               ; If they are active then
        BEQ     %60                                     ; Nothing we can do here
        LDR     r7, [ r7, #Offset_Link ]
        B       %40

50
        LDR     r7, RxCBList
        TEQ     r7, #NIL
        BEQ     %70                                     ; Its OK, so lets do it
        WritePSRc I_bit+SVC_mode, r2                    ; Goto SVC
        MOV     r2, #ServicePortable_TidyUp             ; Lets beg for it (non-mode dependent register)
        Push    "r1, lr"                                ; This may cause SWIs, which will change PowerDownTime
        MOV     r1, #Service_Portable
        SWI     XOS_ServiceCall
        Pull    "r1, lr"
        RestPSR r5                                      ; Restore mode and interrupt state
        LDR     r7, RxCBList
        TEQ     r7, #NIL
60
        ADDNE   r7, r6, #PowerDownTimeout               ; Calculate time to try again
        STRNE   r7, PowerDownTime
        Pull    "r2-r7, pc", NE                         ; Still got things to do
70
      [ DebugPowerDown
        LDR     r7, =Border_Magenta
        ADR     r14, VIDC
        STR     r7, [ r14, #0 ]
      ]
        WritePSRc I_bit+SVC_mode, r7                    ; Goto SVC
      [ UsePortableModule
        Push    "r0, r1, lr"                            ; On supervisor stack
        MOV     r0, #0                                  ; Turn it off
        MVN     r1, #PortableControl_EconetEnable
        SWI     XPortable_Control
        Pull    "r0, r1, lr"
      |
        Push    "r1-r3, lr"                             ; On supervisor stack
        MOV     r1, #Service_Portable
        MOV     r2, #ServicePortable_PowerDown
        MOV     r3, #PortableControl_EconetEnable
        SWI     XOS_ServiceCall
        Pull    "r1-r3, lr"
      ]
        RestPSR r5                                      ; Restore mode and interrupt state
NoPowerDownYet
    ]
        [       ReceiveInBackground
        LD      r2, BridgeRxHandle
        TEQ     r2, #0
        BEQ     %90                                     ; Bridge handle already abandoned
        CMP     r6, #BridgeWaitTime
        BLS     %90                                     ; Not time to abandon yet, unsigned CMP
        WritePSRc SVC_mode, r6                          ; Goto SVC, needed to call AbandonAndReadReceive
        Push    "r0, r1, r5, r10, r11, lr"
        MOV     r0, #0
        ST      r0, BridgeRxHandle
        ADDS    r0, r0, r2                              ; MOV r0, r2, clearing V: R2 is the handle to abandon
        BL      AbandonAndReadReceive                   ; Ignore errors returned
        [       DebugFindLocalNet
        BVS     %97
        TEQ     r0, #Status_Received
        LDRNE   r0, =Border_Grey
        LDREQ   r0, =Border_Brown
        ADR     r1, VIDC
        STR     r0, [ r1, #0 ]
97
        ]
        Pull    "r0, r1, r5, r10, r11, lr"
        RestPSR r5                                      ; Restore mode and interrupt state
90
        ]
ExitPacemaker
        Pull    "r2-r7, pc"

RestartRecord   ROUT                                    ; Called from StartTransmit and TickerV
        ;       R5 => Mode and flags to restore at the end
        ;       R6 => Time
        ;       R7 => Pointer to the record
        ;       SP => Has r2-r7, and the return address already pushed
        LD      r4, FIQStatus                           ; Test again because of being jumped to
        TEQ     r4, #FIQ_Owner                          ; Is it OK to do anything?
        BNE     ExitRestartRecord
        LDRB    r2, [ r7, #Offset_Station ]
        LD      r4, LocalStation                        ; Is it the same station number?
        TEQ     r2, r4                                  ; If it is then check the network number as well
        LDREQB  r2, [ r7, #Offset_Network ]
        TEQEQ   r2, #0                                  ; Is it this network?
        LDRNEB  r2, [ r7, #Offset_Broadcast ]
        TEQNE   r2, #0
        BNE     SendToWire                              ; Not for local loopback
        LDRB    r2, [ r7, #Offset_Port ]
        TEQ     r2, #0                                  ; Is this an immediate operation?
        LDRNEB  r2, [ r7, #Offset_Local ]               ; Have we already done this?
        TEQNE   r2, #0
        BEQ     SendToWire                              ; Yes, so "No way Hose!"
        LDR     r2, RxCBList                            ; Now compare the TxRecord with the RxList
ScanRxLoop
        TEQ     r2, #NIL
        BEQ     LocalNotListening
        LDRB    r3, [ r2, #Offset_Status ]
        TEQ     r3, #Status_RxReady
        BNE     SkipToNextRx                            ; Not ready, so it can't be this one
        LDRB    r3, [ r2, #Offset_RxPort ]
        TEQ     r3, #255
        LDRNEB  r4, [ r7, #Offset_Port ]                ; The transmission port
        TEQNE   r3, r4
        BNE     SkipToNextRx                            ; No port match or no wild reception port
        LDRB    r3, [ r2, #Offset_RxStation ]
        TEQ     r3, #255
        LD      r4, LocalStation, NE
        TEQNE   r3, r4
        BNE     SkipToNextRx                            ; No station match or no wild reception station
        LDRB    r3, [ r2, #Offset_RxNetwork ]
        TEQ     r3, #255
        TEQNE   r3, #0
        BNE     SkipToNextRx                            ; No network match or no wild reception network
        ; Now check that there is room for the transfer to take place
        LDR     r3, [ r2, #Offset_Size ]
        LDR     r4, [ r7, #Offset_Size ]
        CMP     r3, r4                                  ; Check the two buffer sizes
        MOVLT   r4, #Status_NetError
        BLT     LocalNetError                           ; No, not enough room
        Push    "r0, r1"
        [       DebugIRQ
        LDR     r0, =Border_Lime
        ADR     r1, VIDC
        STR     r0, [ r1, #0 ]
        ]
        LDR     r0, [ r2, #Offset_Start ]
        LDR     r1, [ r7, #Offset_Start ]
LocalCopyLoop
        LDRB    r3, [ r1 ], #1
        STRB    r3, [ r0 ], #1
        DECS    r4
        BNE     LocalCopyLoop
        Pull    "r0, r1"
        LDRB    r4, [ r7, #Offset_Station ]
        LDR     r4, [ r7, #Offset_Size ]
        STR     r4, [ r2, #Offset_RxSize ]
        LD      r4, LocalStation
        STRB    r4, [ r2, #Offset_Station ]
        MOV     r4, #0
        STRB    r4, [ r2, #Offset_Network ]
        LDRB    r4, [ r7, #Offset_Port ]
        STRB    r4, [ r2, #Offset_Port ]
        LDRB    r4, [ r7, #Offset_Control ]
        STRB    r4, [ r2, #Offset_Control ]
        MOV     r4, #Status_Received                    ; Mark the reception as completed
        STRB    r4, [ r2, #Offset_Status ]
        WritePSRc I_bit+F_bit+SVC_mode, r3,, r4         ; Disable all interrupts, save interrupt state
        LD      r3, EventSequenceNumber
        INC     r3                                      ; Get an event number
        ST      r3, EventSequenceNumber
        RestPSR r4                                      ; Restore interrupts and mode
        LDRB    r4, [ r7, #Offset_Broadcast ]
        TEQ     r4, #0                                  ; Is this a broadcast?
        MOVNE   r4, #Status_Transmitted                 ; Mark a normal transmit as completed
        STRNEB  r4, [ r7, #Offset_Status ]
        STRNE   r3, [ r7, #Offset_Event ]               ; Transmit event
        MOVNE   r7, r2                                  ; The RxCB
        BNE     DoEventAndExit                          ; And exit marking the RxCB for eventing
        STRB    r4, [ r7, #Offset_Local ]               ; Mark that we have done a local reception (0)
        STR     r3, [ r2, #Offset_Event ]               ; Receive event, will be triggered with the Tx
        B       SendToWire                              ; Now send the broadcast out on the wire as well

SkipToNextRx
        LDR     r2, [ r2, #Offset_Link ]
        B       ScanRxLoop                              ; Check the next RxRecord

LocalNotListening                                       ; No match on any RxCB
        MOV     r4, #Status_NotListening
LocalNetError
        LDRB    r2, [ r7, #Offset_Broadcast ]
        TEQ     r2, #0                                  ; If its a broadcast, send it out
        BEQ     SendToWire
        LDR     r2, [ r7, #Offset_Count ]
        DECS    r2
        STRLEB  r2, [ r7, #Offset_Status ]              ; Write the status if this was the last one
        BLE     DoEventAndExit                          ; Transmit is now complete
        STR     r2, [ r7, #Offset_Count ]
        LDR     r4, [ r7, #Offset_Delay ]
        LDR     r2, [ r7, #Offset_Time ]
        ADD     r2, r2, r4                              ; Compute next start time
        STR     r2, [ r7, #Offset_Time ]
        ;       Note that there is no need to adjust the ClaimTime
        B       ExitRestartRecord

SendToWire
    [   {FALSE}    ;       ****************  Bodge  ****************
    !   0, " ****  Bodge code assembled in SendToWire ****"
        Push    r10
        LDR     r10, HardwareAddress
        LDRB    r10, SReg2
        ST      r10, Status2
        Pull    r10
    ]
        LD      r4, Status2
        TST     r4, #DCD
        MOVNE   r4, #Status_NoClock
        STRNEB  r4, [ r7, #Offset_Status ]
        BNE     DoEventAndExit                          ; No mode change yet
        WritePSRc I_bit+F_bit+FIQ_mode, r4              ; Goto FIQ mode, disable all interrupts
        LD      r4, FIQBusy                             ; Get the FIQBusy flag
        TEQ     r4, #0                                  ; Test it
        BNE     ExitRestartRecord
        ST      r7, Record                              ; Save the address of the transmit control block

	MOV	r4, #-1
        ST      r4, FIQBusy				; Set the FIQ flag <> 0

        LDRB    r4, [ r7, #Offset_Station ]             ; Now set up the TxMode flags
        EORS    r4, r4, #255                            ; Z if it is 255 ==> broadcast
        ORREQ   r4, r4, #BroadcastBit
        BEQ     StoreModeWord
        LDRB    r9, [ r7, #Offset_Port ]
        TEQ     r9, #0
        BNE     StoreModeWord
        LDRB    r9, [ r7, #Offset_Control ]             ; This has bit seven set
        ADR     r13, ImmediateModeBits - ( BitSeven + Econet_Peek )
        LDRB    r9, [ r13, r9 ]
        ORR     r4, r4, r9, LSL #24
StoreModeWord
        ST      r4, TxMode
        LD      r13, SReg2                              ; Note R10 is always the address of the ADLC
        TST     r13, #RxIdle                            ; Now the line access stuff
        BEQ     NoLineAccess                            ; Line not idle
        TST     r13, #RxAbort
        BNE     NoLineAccess
        MOV     r13, #Status_Transmitting               ; Now mark the record as Transmitting
        STRB    r13, [ r7, #Offset_Status ]             ; Now we can start to prod the chip into action
        MOV     r13, #2_11100111                        ; RTS, CLRTxST, CLRRxST, FlagIdle, 2Byte, PSE
        ST      r13, CReg2
        MOV     r13, #2_01000100                        ; RxRS, TxIE
        ST      r13, CReg1
        [       Debug
        LDR     r8, =Border_Green                       ; Access to wire
        ADR     r9, VIDC
        STR     r8, [ r9, #0 ]
        ]
        SetFIQ  TxFromMe, r8, r9, Long, Init, r13
        SetJump TxControlAndPort, r8, r9, Long
ExitRestartRecord
        RestPSR r5                                      ; Return to correct mode, and interrupt state
        Pull    "r2-r7, pc"

ImmediateModeBits ; Stored as bytes to be put in the top bits
        DCB     2_00011010                              ; Peek
        DCB     2_00011000                              ; Poke
        DCB     2_00010000                              ; JSR
        DCB     2_00010000                              ; UserProcedureCall
        DCB     2_00010000                              ; OSProcedureCall
        DCB     2_00010101                              ; Halt
        DCB     2_00010101                              ; Continue
        DCB     2_00010010                              ; MachinePeek
        DCB     2_00010110                              ; GetRegisters
        ALIGN

NoLineAccess                                            ; Line jammed ??
        LDR     r8, [ r7, #Offset_ClaimTime ]
        CMP     r8, r6                                  ; Has the claim time expired ??
        ST      r13, Status2, MI                        ; Retain for later examination
        MOVPL   r6, #Status_TxReady                     ; Still keep trying
        MOVMI   r6, #Status_LineJammed                  ; Give up
        STRB    r6, [ r7, #Offset_Status ]
        MOV     r6, #0
        ST      r6, FIQBusy                             ; Must clear this since it is NOT busy no more
        BPL     ExitRestartRecord
        ;       Last time so must flag the event
DoEventAndExit
        ;       R7 <= Pointer to CB to event
        ;       Trashes R3 and R4
        WritePSRc I_bit+F_bit+SVC_mode, r3,, r4         ; Disable all interrupts, save interrupt state
        LD      r3, EventSequenceNumber
        INC     r3
        ST      r3, EventSequenceNumber
        RestPSR r4                                      ; Restore interrupts and mode
        STR     r3, [ r7, #Offset_Event ]
        MOV     r4, #IOC
        LDRB    r3, [ r4, #IOCIRQMSKA ]                 ; IRQ Mask register
        ORR     r3, r3, #force_bit
        STRB    r3, [ r4, #IOCIRQMSKA ]                 ; IRQ Mask register
        B       ExitRestartRecord

        LTORG

        END
