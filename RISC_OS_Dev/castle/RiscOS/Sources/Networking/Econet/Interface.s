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
        SUBT    SWI entry code.  File => &.Arthur.Econet.Interface
        OPT     OptPage

SWIHandler      ROUT
        Push    "lr"
        LDR     wp, [ r12 ]
        LD      r14, SWILock
        INC     r14
        ST      r14, SWILock
      [ DebugSWIs
        SavePSR r10
53
        CMP     r14, #1
        BLE     %63
        DLINE   "   ", cc
        DECS    r14
        BGT     %53
63
        ADD     r14, r11, #MySWIChunkBase
        DREG    r14, "SWI &", cc
        DREG    r0, ", R0=&", cc
        DREG    r1, ", R1=&", cc
        DREG    r2, ", R2=&", cc
        DREG    r3, ", R3=&"
        RestPSR r10
      ]
        BL      SVCEntry
      [ DebugSWIs
        SavePSR r10
        LD      r14, SWILock                            ; Unwind entry count before exiting
54
        CMP     r14, #1
        BLE     %64
        DLINE   "   ", cc
        DECS    r14
        BGT     %54
64
        DLINE   "Exit", cc
        DREG    r0, ", R0=&"
        RestPSR r10
      ]
        LD      r14, SWILock                            ; Unwind entry count before exiting
        DEC     r14
        ST      r14, SWILock

        TEQ     pc, pc
        Pull    "pc", EQ                                ; 32-bit return corrupting flags
        Pull    "pc", VC,^                              ; 26-bit return without error
        Pull    "lr"                                    ; 26-bit return with error
        ORRS    pc, lr, #V_bit

SVCEntry        ROUT
        [       PerthPowerDown
        Push    lr
        PHPSEI                                          ; Hold IRQ state in R14
        ; Turn IRQs off so that a centi-second tick
        ; can't turn it off when we think it's on
        LD      r10, Time
        ADD     r10, r10, #PowerDownTimeout             ; Compute new down time
        ST      r10, PowerDownTime
        LD      r10, FIQStatus
        PLP
        TEQ     r10, #FIQ_PoweredDown
        [       DebugPowerDown
        LDREQ   r14, =Border_Cyan                       ; Powering up
        LDRNE   r14, =Border_Green                      ; Resetting timer only
        ADR     r10, VIDC
        STR     r14, [ r10, #0 ]
        ]
        BNE     PoweredUp
        [       UsePortableModule
        Push    "r0, r1"
        MOV     r0, #PortableControl_EconetEnable
        MVN     r1, #PortableControl_EconetEnable
        SWI     XPortable_Control                       ; Ignore error
        Pull    "r0, r1"
        |
        Push    "r0-r3"
        MOV     r1, #Service_Portable
        MOV     r2, #ServicePortable_PowerUp
        MOV     r3, #PortableControl_EconetEnable
        SWI     XOS_ServiceCall
        Pull    "r0-r3"
        ]
PoweredUp
        Pull    lr
        ]
        CMP     r11, #( EndOfJumpTable - JumpTable ) / 4
        ADRCS   r0, ErrorOutOfRange
        ADDCC   pc, pc, r11, LSL #2
        B       MakeErrorWithModuleName                 ; Only one instruction after the ADD pc, pc
JumpTable                                               ; Then the jump table
        B       CreateReceive                           ; &40000, 0
        B       ExamineReceive                          ; &40001, 1
        B       ReadReceive                             ; &40002, 2
        B       AbandonReceive                          ; &40003, 3
        B       WaitForReception                        ; &40004, 4
        B       EnumerateRxCBs                          ; &40005, 5
        B       StartTransmit                           ; &40006, 6
        B       PollTransmit                            ; &40007, 7
        B       AbandonTransmit                         ; &40008, 8
        B       DoTransmit                              ; &40009, 9
        B       ReadLocalStation                        ; &4000A, 10
        B       ConvertStatusToString                   ; &4000B, 11
        B       ConvertStatusToError                    ; &4000C, 12
        B       ReadProtection                          ; &4000D, 13
        B       SetProtectionMask                       ; &4000E, 14
        B       ReadStationNumber                       ; &4000F, 15
        B       PrintBanner                             ; &40010, 16
        B       ReadTransportType                       ; &40011, 17
        B       ReleasePort                             ; &40012, 18
        B       AllocatePort                            ; &40013, 19
        B       DeAllocatePort                          ; &40014, 20
        B       ClaimPort                               ; &40015, 21
        B       StartImmediate                          ; &40016, 22
        B       DoImmediate                             ; &40017, 23
        B       AbandonAndReadReceive                   ; &40018, 24
        B       Version                                 ; &40019, 25
        B       NetworkState                            ; &4001A, 26
        B       PacketSize                              ; &4001B, 27
        B       ReadTransportName                       ; &4001C, 28
        B       InetRxDirect                            ; &4001D, 29
        B       EnumerateMap                            ; &4001E, 30
        B       EnumerateTransmit                       ; &4001F, 31
        B       HardwareAddresses                       ; &40020, 32
        B       NetworkParameters                       ; &40021, 33
EndOfJumpTable

        ASSERT  EconetSWICheckValue-Econet_CreateReceive=(EndOfJumpTable-JumpTable)/4

        LTORG

ErrorOutOfRange
        DCD     ErrorNumber_OutOfRange
        DCB     "BadSWI", 0
        ALIGN

ModuleTitle
SWINameTable
        DCB     EconetSWI_Name, 0
        DCB     "CreateReceive", 0
        DCB     "ExamineReceive", 0
        DCB     "ReadReceive", 0
        DCB     "AbandonReceive", 0
        DCB     "WaitForReception", 0
        DCB     "EnumerateReceive", 0
        DCB     "StartTransmit", 0
        DCB     "PollTransmit", 0
        DCB     "AbandonTransmit", 0
        DCB     "DoTransmit", 0
        DCB     "ReadLocalStationAndNet", 0
        DCB     "ConvertStatusToString", 0
        DCB     "ConvertStatusToError", 0
        DCB     "ReadProtection", 0
        DCB     "SetProtection", 0
        DCB     "ReadStationNumber", 0
        DCB     "PrintBanner", 0
        DCB     "ReadTransportType", 0
        DCB     "ReleasePort", 0
        DCB     "AllocatePort", 0
        DCB     "DeAllocatePort", 0
        DCB     "ClaimPort", 0
        DCB     "StartImmediate", 0
        DCB     "DoImmediate", 0
        DCB     "AbandonAndReadReceive", 0
        DCB     "Version", 0
        DCB     "NetworkState", 0
        DCB     "PacketSize", 0
        DCB     "ReadTransportName", 0
        DCB     "InetRxDirect", 0
        DCB     "EnumerateMap", 0
        DCB     "EnumerateTransmit", 0
        DCB     "HardwareAddresses", 0
        DCB     "NetworkParameters", 0
        DCB     0
        ALIGN

        SUBT    SWI Interface routines.
        OPT     OptPage

        ; ***************************************************
        ; ***   S W I   R e c e i v e   R o u t i n e s   ***
        ; ***************************************************

CreateReceive   ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Port
        ;       R1 => Station
        ;       R2 => Net
        ;       R3 => Buffer Address
        ;       R4 => Size
        ;       R0 <= Handle
        ;       Trashes R10 and R11

        CMP     r0, #255
        BHI     BadPortExit
        CMP     r1, #255
        BHI     BadStationExit
        CMP     r2, #255
        BHI     BadNetExit
        BNE     %10
        TEQ     r1, #255                                ; The only legal partner (255.255)
        BEQ     %50                                     ; Its OK so go ahead
        TEQ     r1, #0
        BEQ     BadStationExit
        B       BadNetExit

10
        TEQ     r2, #0                                  ; Net number 0 is always legal
        BEQ     %55
        TEQ     r1, #0                                  ; Station 0 illegal with non-zero net number
        BEQ     BadStationExit
50
        LD      r11, LocalNetwork
        TEQ     r11, r2
        MOVEQ   r2, #0
55
        Push    "r1-r3, lr"
        MOV     r1, r0                                  ; The port number
        MOV     r0, #ModHandReason_Claim                ; Preserves R1
        MOV     r3, #Size_RxCB
        SWI     XOS_Module
        BVS     ExitCreateReceive
        PHPSEI                                          ; Do the atomic part with IRQs off
        LDR     r0, =RxCBIdentifier
        STR     r0, [ r2, #Offset_Identifier ]
        LD      r0, CurrentHandle
        INC     r0, 4
        ST      r0, CurrentHandle
        STR     r0, [ r2, #Offset_Handle ]
        TEQ     r1, #0                                  ; Map port number zero to 255
        MOVEQ   r1, #255
        STRB    r1, [ r2, #Offset_RxPort ]
        MOV     r3, #Status_RxReady
        STRB    r3, [ r2, #Offset_Status ] 
        LDMIA   sp, { r3, r11 }                         ; Station (R1), Net (R2)
        ORRS    r10, r3, r11                            ; Check for 0.0, only flags important
        MOVEQ   r3, #255                                ; Map to 255.255
        MOVEQ   r11, #255
        STRB    r3, [ r2, #Offset_RxStation ]
        STRB    r11, [ r2, #Offset_RxNetwork ]
        TEQ     r1, #255                                ; Check for wild port
        TEQNE   r3, #255                                ; Or wild station
        LDR     r3, [ sp, #8 ]                          ; Buffer
        ADD     r1, r2, #Offset_Start                   ; Calculate the address of the pair in the record
        STMIA   r1, { r3, r4 }                          ; R4 still has the size
        MOV     r1, #-1                                 ; True
        STRB    r1, [ r2, #Offset_Station ]
        STRB    r1, [ r2, #Offset_Network ]
        STRB    r1, [ r2, #Offset_Port ]
        MOV     r1, #Event_NotReady                     ; Not yet needing eventing
        STR     r1, [ r2, #Offset_Event ]               ; It is still waiting for it's Event
        ; NE means NOT wild stick in the middle of the list
        ; EQ means that some part was wild so it goes at the end
        ADR     r10, RxCBList - Offset_Link             ; Head of the list
        BEQ     InsertAtTheEnd
60                                                      ; Find either the tail of the list or the first wild one
        LDR     r11, [ r10, #Offset_Link ]              ; Look for the end of the list
        TEQ     r11, #NIL                               ; Is this the end of the list?
        BEQ     InsertInList                            ; There were no wilds so insert at the end 
        LDRB    r3, [ r11, #Offset_RxStation ]
        TEQ     r3, #255                                ; Look for a 255 in any one of these
        LDRNEB  r3, [ r11, #Offset_RxPort ]
        TEQNE   r3, #255                                ; two fields; that means it is 'wild'
        MOVNE   r10, r11                                ; Move on to the next record
        BNE     %60
        B       InsertInList

InsertAtTheEnd
        LDR     r11, [ r10, #Offset_Link ]              ; Look for the end of the list
        TEQ     r11, #NIL
        MOVNE   r10, r11                                ; Get the next one
        BNE     InsertAtTheEnd
InsertInList
        STR     r11, [ r2, #Offset_Link ]               ; Make us point to the next (may be NIL)
        STR     r2, [ r10, #Offset_Link ]               ; Make the this one point at us, may be RxCBList
        PLP                                             ; Restore the IRQ state
ExitCreateReceive
        Pull    "r1-r3, pc"

ExamineReceive  ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Handle
        ;       R0 <= Status
        ;       Trashes R10 and R11

        Push    "r9, lr"                                ; Save IRQ state on stack
        PHPSEI                                          ; Also keep in R14
        ADR     r10, RxCBList - Offset_Link             ; Must be done with interrupts OFF
        LDR     r9, =RxCBIdentifier
ExamineLoop                                             ; Jumped to from PollTransmit
        LDR     r10, [ r10, #Offset_Link ]
        TEQ     r10, #NIL
        BEQ     PLPBadHandleExit
        LDR     r11, [ r10, #Offset_Identifier ]
        TEQ     r11, r9
        BNE     PLPInternalErrorExit
        LDR     r11, [ r10, #Offset_Handle ]
        TEQ     r0, r11
        BNE     ExamineLoop
        LDRB    r0, [ r10, #Offset_Status ]
        PLP                                             ; Restore IRQ state from R14
        Pull    "r9, lr"
        RETURNVC

PLPBadHandleExit
        PLP                                             ; Restore IRQ state from R14
        Pull    "r9, lr"
        B       BadHandleExit

PLPInternalErrorExit
        PLP                                             ; Restore IRQ state from R14
        Pull    "r9, lr"
InternalErrorExit
        ADR     r0, ErrorInternal
        B       MakeErrorWithModuleName

ErrorInternal
        DCD     ErrorNumber_EconetInternalError
        DCB     "Fatal"
        DCB     0
        ALIGN


ReadReceive     ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Handle
        ;       R0 <= Status byte
        ;       R1 <= Control byte
        ;       R2 <= Port
        ;       R3 <= Station
        ;       R4 <= Net
        ;       R5 <= Buffer Address
        ;       R6 <= Size
        ;       R10 is trashed
        ;       R11 is preserved
        
        Push    "r9, lr"                                ; Save IRQ state on stack
        PHPSEI                                          ; Also keep in R14
        ADR     r10, RxCBList - Offset_Link             ; Must be done with interrupts OFF
        LDR     r9, =RxCBIdentifier
ReadLoop
        LDR     r10, [ r10, #Offset_Link ]
        TEQ     r10, #NIL
        BEQ     PLPBadHandleExit
        LDR     r1, [ r10, #Offset_Identifier ]
        TEQ     r1, r9
        BNE     PLPInternalErrorExit
        LDR     r1, [ r10, #Offset_Handle ]
        TEQ     r0, r1
        BNE     ReadLoop
        PLP                                             ; Restore IRQ state from R14
        Pull    "r9, lr"
ReadReceptionRecord                                     ; In R10 into R0-R6
        LDRB    r0, [ r10, #Offset_Status ] 
        TEQ     r0, #Status_Received                    ; Received ?
        LDREQB  r1, [ r10, #Offset_Control ]
        ANDEQ   r1, r1, #2_01111111                     ; Only the bottom seven bits
        LDREQB  r2, [ r10, #Offset_Port ]
        LDREQB  r3, [ r10, #Offset_Station ]
        LDREQB  r4, [ r10, #Offset_Network ]
        LDREQ   r5, [ r10, #Offset_Start ]
        LDREQ   r6, [ r10, #Offset_RxSize ]
        RETURNVC EQ
        MOV     r1, #0                                  ; Fake control value
        LDRB    r2, [ r10, #Offset_RxPort ]
        LDRB    r3, [ r10, #Offset_RxStation ]
        LDRB    r4, [ r10, #Offset_RxNetwork ]
        ADD     r5, r10, #Offset_Start
        LDMIA   r5, { r5, r6 }                          ; Start and Size
        RETURNVC

AbandonReceive ROUT
        ;       R0 => Handle
        ;       R0 <= Status
        ;       R10 is trashed
        ;       R11 is trashed
        Push    "r1-r6, lr"
        BL      AbandonAndReadReceive
        Pull    "r1-r6, pc"

AbandonAndReadReceive
        ;       R0 => Handle
        ;       R0 <= Status byte
        ;       R1 <= Control byte
        ;       R2 <= Port
        ;       R3 <= Station
        ;       R4 <= Net
        ;       R5 <= Buffer Address
        ;       R6 <= Size
        ;       R10 is trashed
        ;       R11 is trashed
        Push    "r9, lr"
        PHPSEI
        ADR     r10, RxCBList - Offset_Link
        LDR     r9, =RxCBIdentifier
AbandonLoop
        MOV     r11, r10                                ; Keep the previous pointer
        LDR     r10, [ r10, #Offset_Link ]
        TEQ     r10, #NIL
        BEQ     PLPBadHandleExit
        LDR     r1, [ r10, #Offset_Identifier ]
        TEQ     r1, r9
        BNE     PLPInternalErrorExit
        LDR     r1, [ r10, #Offset_Handle ]
        TEQ     r0, r1
        BNE     AbandonLoop
        [       NoAbandons
        ORR     r1, r1, #NIL
        STR     r1, [ r10, #Offset_Handle ]             ; Mark the handle as EVIL
        |
        LDR     r0, [ r10, #Offset_Link ]               ; The next link
        STR     r0, [ r11, #Offset_Link ]               ; Unlink it
        ]
        PLP                                             ; Restore IRQ state
        LDRB    r14, [ r10, #Offset_Status ]
        TEQ     r14, #Status_Receiving
        BNE     %97                                     ; Not active
95
        LD      r14, FIQBusy                            ; See if we are busy
        TEQ     r14, #0
        BNE     %95                                     ; It is busy, probably with this record
97
        BL      ReadReceptionRecord
        [       ErrorInfo
        ADRL    r14, RxErrors
        LDR     r11, [ r14, #:INDEX:RxCount - :INDEX:RxErrors ]
        INC     r11
        STR     r11, [ r14, #:INDEX:RxCount - :INDEX:RxErrors ]
        LDR     r11, [ r14, r0, ASL #2 ]
        INC     r11
        STR     r11, [ r14, r0, ASL #2 ]
        ]
        Push    "r0, r2"
        MOV     r0, #ModHandReason_Free
        MOV     r2, r10                                 ; The address of the record
        [       NoAbandons
        CLRV
        |
        SWI     XOS_Module
        ]
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r2, r9, pc"


WaitForReception ROUT                                   ; Now able to cope with IRQs enabled
        ;       R0 => Handle
        ;       R1 => Delay
        ;       R2 => ESCapableFlag : zero for inESCapable, non-zero for ESCapable
        ;       R0 <= Status byte
        ;       R1 <= Control byte
        ;       R2 <= Port
        ;       R3 <= Station
        ;       R4 <= Net
        ;       R5 <= Buffer Address
        ;       R6 <= Size
        ;       Trashes R11, and R10 indirectly

        Push    "r9, lr"
        MOV     r11, r0
        MOV     r0, #Econet_StartReception
        MOV     r9, #EconetV
        SWI     XOS_CallAVector                         ; Turn on the hourglass
        SWIVC   XOS_ReadMonotonicTime
        Pull    "r9, pc", VS
        ADD     r1, r1, r0                              ; Calculate the finish time
        WritePSRc USR_mode, lr,, r9                     ; Enable all interrupts go to user mode, keep old mode
ReceptionWaitLoop
        MOV     r0, r11
        SWI     XEconet_ExamineReceive
        BVS     RxPollError                             ; Most likely a BadHandle
        TEQ     r0, #Status_Received
        BEQ     ReceptionCompleted
        SWI     XOS_ReadMonotonicTime
        BVS     RxPollError                             ; Very unlikely
        CMP     r0, r1
        MOVPL   r0, #Status_NoReply
        BPL     ReceptionCompleted
        TEQ     r2, #0                                  ; Are we checking for ESCape?
        BEQ     ReceptionWaitLoop
        SWI     XOS_ReadEscapeState                     ; Doesn't enable IRQ, ignore the error
        CLC     VS
        BCC     ReceptionWaitLoop
EscapedOutOfWait
        MOV     r0, #OsByte_AcknowledgeEscape
        SWI     XOS_Byte                                ; Doesn't enable IRQ, ignore the error
        MOV     r0, #Status_Escape
ReceptionCompleted
        SWI     XOS_EnterOS                             ; Get back to SVC mode, ignore error
        RestPSR r9                                      ; Restore interrupts and mode (might be IRQ)
        MOV     r1, r0                                  ; The final status to return
        MOV     r0, #Econet_FinishReception
        MOV     r9, #EconetV                            ; Turn off the hourglass
        SWI     XOS_CallAVector                         ; Ignore error
        MOV     r9, r1
        MOV     r0, r11                                 ; The handle
        BL      AbandonAndReadReceive
        TEQ     r0, #Status_Received
        MOVNE   r0, r9                                  ; In the event it has just arrived
        Pull    "r9, pc"                                ; dont't return Escape or NoReply

RxPollError
        MOV     r11, r0                                 ; Keep the error
        SWI     XOS_EnterOS                             ; Get back to SVC mode, ignore error
        RestPSR r9                                      ; Restore interrupts and mode (might be IRQ)
        MOV     r0, #Econet_FinishReception
        MOV     r9, #EconetV                            ; Turn off the hourglass
        SWI     XOS_CallAVector
        MOV     r0, r11                                 ; Restore the original error
        SETV                                            ; Indicate that it was an error
        Pull    "r9, pc"


EnumerateRxCBs  ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Index
        ;       R0 <= Handle
        ;       Trashes R10
        ;       Trashes R11

        TEQ     r0, #0
        RETURNVC EQ
        Push    "r1-r4"
        PHPSEI  r4
        ADR     r1, RxCBList - Offset_Link
        LDR     r2, =RxCBIdentifier
EnumerateControlBlockLoop                               ; Common to EnumerateTransmit
        LDR     r1, [ r1, #Offset_Link ]
        TEQ     r1, #NIL
        MOVEQ   r0, #0
        BEQ     ExitEnumerateControlBlocks
        LDR     r3, [ r1, #Offset_Identifier ]
        TEQ     r3, r2
        BNE     ErrorExitEnumerateControlBlocks
        DECS    r0
        BNE     EnumerateControlBlockLoop
        LDR     r0, [ r1, #Offset_Handle ]
ExitEnumerateControlBlocks
        PLP     r4                                      ; Restore IRQ state
        Pull    "r1-r4"
        RETURNVC

ErrorExitEnumerateControlBlocks
        PLP     r4                                      ; Restore IRQ state
        Pull    "r1-r4"
        B       InternalErrorExit

        OPT     OptPage
        ; *****************************************************
        ; ***   S W I   T r a n s m i t   R o u t i n e s   ***
        ; *****************************************************

StartTransmit   ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Flag byte
        ;       R1 => Port
        ;       R2 => Station
        ;       R3 => Net
        ;       R4 => Buffer Address
        ;       R5 => Size
        ;       R6 => Count
        ;       R7 => Delay
        ;       R0 <= Handle
        ;       R2 <= Buffer Address
        ;       R3 <= Station
        ;       R4 <= Net

        ORR     r0, r0, #BitSeven
        CMP     r0, #255
        BHI     BadControlExit
        CMP     r1, #255
        BLO     %20
BadPortExit
        ADR     r0, ErrorBadPort
        B       MakeError

ErrorBadPort
        DCD     ErrorNumber_BadPort
        DCB     "BadPort", 0
        ALIGN
20
        TEQ     r1, #0
        BEQ     BadPortExit
        CMP     r2, #255                                ; Check the station number, it must be (1..255)
        BLS     %30                                     ; Well, it is small enough
BadStationExit
        ADRL    r0, ErrorBadStation
        B       MakeError
30
        TEQ     r2, #0                                  ; Zero is illegal
        BEQ     BadStationExit
        CMP     r3, #255                                ; Check the network number, it must be (0..255)
        BLS     %40
BadNetExit
        ADRL    r0, ErrorBadNetwork
        B       MakeError
40
        LD      r11, LocalNetwork
        TEQ     r3, r11                                 ; Are we trying to transmit on the local net
        MOVEQ   r3, #0
45
        CMP     r5, #MaxTxSize
        BLS     %50
BadSizeExit
        ADR     r0, ErrorBadSize
        B       MakeError

ErrorBadSize
        DCD     ErrorNumber_BadSize
        DCB     "TooBig", 0
        ALIGN
50
        Push    "r0-r3, lr"                             ; Preserve over SWI
        MOV     r0, #ModHandReason_Claim
        MOV     r3, #Size_TxCB
        SWI     XOS_Module
        MOV     r10, r2
        STRVS   r0, [ sp ]                              ; Put heap error into stack for exit conditions
        Pull    "r0-r3, lr"
        MOVVS   pc, lr
        STRB    r0, [ r10, #Offset_Control ]
        STRB    r1, [ r10, #Offset_Port ]
        [       DebugIRQ
        LDR     r0, =Border_Red
        ADR     r1, VIDC
        STR     r0, [ r1, #0 ]
        ]
AddTxRecordToList
        LDR     r0, = TxCBIdentifier
        STR     r0, [ r10, #Offset_Identifier ]
        MOV     r0, #-1
        STRB    r2, [ r10, #Offset_Station ]
        STRB    r3, [ r10, #Offset_Network ]
        TEQ     r2, #255
        BNE     %70                                     ; Station number <> 255 ==> is not a broadcast
        TEQ     r3, #0                                  ; Network number = 0    ==> is a broadcast
        CMPNE   r3, #&FC                                ; Network number >= &FC ==> is a broadcast
        BLT     %70
        MOV     r0, #0                                  ; It is a broadcast
70
        STRB    r0, [ r10, #Offset_Broadcast ]          ; Zero for "is a broadcast"
        ADDS    r0, r10, #Offset_Start                  ; Clears V, so that R5 is OK later
        STMIA   r0, { r4, r5, r6, r7 }                  ; Start, Size, Count, Delay
        MOV     r0, r4                                  ; Save start address
        MOV     r4, r3                                  ; LDR r4, [ r10, #Offset_Network ]
        MOV     r3, r2                                  ; LDR r3, [ r10, #Offset_Station ]
        MOV     r2, r0                                  ; Start address
        LD      r0, Time
        STR     r0, [ r10, #Offset_Time ]
        ADD     r11, r0, #ClaimTime                     ; Ten seconds to poll for line free
        STR     r11, [ r10, #Offset_ClaimTime ]
        MOV     r11, #-1                                ; True
        STRB    r11, [ r10, #Offset_Local ]             ; No local transmission occured yet
        MOV     r11, #Event_NotReady                    ; Not yet needing eventing
        STR     r11, [ r10, #Offset_Event ]
        MOV     r11, #Status_TxReady                    ; Set it going
        STRB    r11, [ r10, #Offset_Status ]
        Push    "r2-r7, lr"                             ; Note use of Non FIQ registers

        SETPSR  I_bit, r14,, r5                         ; Set IRQ flag for this atomic stuff

        LD      r0, CurrentHandle
        INC     r0, 4
        ST      r0, CurrentHandle
        STR     r0, [ r10, #Offset_Handle ]
        ADR     r11, TxCBList - Offset_Link             ; Head of the list
FindEndOfTxList
        LDR     r1, [ r11, #Offset_Link ]               ; Check the next entry
        TEQ     r1, #NIL                                ; Is it the end?
        MOVNE   r11, r1                                 ; No, so skip on to the next
        BNE     FindEndOfTxList                         ; And try again
        STR     r1, [ r10, #Offset_Link ]               ; Mark as the new end of list
        STR     r10, [ r11, #Offset_Link ]              ; Make this one the new tail
        LD      r6, Time
        MOV     r7, r10                                 ; The record to start
        [       DebugSWIs
        LDRB    r4, [ r7, #Offset_Network ]
        BREG    r4, "DoTransmit to station &", cc
        LDRB    r4, [ r7, #Offset_Station ]
        BREG    r4, ".&"
        ]
        B       RestartRecord                           ; Restores mode and flags from R5

DoTransmit      ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Flag byte
        ;       R1 => Port
        ;       R2 => Station
        ;       R3 => Net
        ;       R4 => Buffer Address
        ;       R5 => Size
        ;       R6 => Count
        ;       R7 => Delay
        ;       R0 <= Status
        ;       R2 <= Buffer Address
        ;       R3 <= Station
        ;       R4 <= Net

        Push    "r9, lr"
        BL      StartTransmit                           ; Returns with the record in R10
PollToCompletion
        MOVVC   r0, #Econet_StartTransmission
        MOVVC   r9, #EconetV
        SWIVC   XOS_CallAVector
        Pull    "r9, pc", VS
        LDR     r10, [ r10, #Offset_Handle ]            ; Keep the handle for polling with
        WritePSRc USR_mode, lr,, r9                     ; Enable all interrupts go to user mode, keep old mode
TxPollLoop
        SWI     XOS_ReadEscapeState                     ; Doesn't enable IRQ, ignore the error
        CLC     VS
        BCS     EscapedOutOfTx
        MOV     r0, r10
        SWI     XEconet_PollTransmit
        BVS     TxPollError                             ; Most likely a BadHandle
        TEQ     r0, #Status_TxReady
        TEQNE   r0, #Status_Transmitting
        BEQ     TxPollLoop
        SWI     XOS_EnterOS                             ; Get back to SVC mode, ignore error
        RestPSR r9                                      ; Restore interrupts and mode (might be IRQ)
        MOV     r0, #Econet_FinishTransmission
        MOV     r9, #EconetV                            ; Turn off the hourglass
        SWI     XOS_CallAVector
        MOV     r0, r10
        BL      AbandonTransmit                         ; Find out how it finished up
        Pull    "r9, pc"

EscapedOutOfTx
        SWI     XOS_EnterOS                             ; Get back to SVC mode, ignore error
        RestPSR r9                                      ; Restore interrupts and mode (might be IRQ)
        MOV     r0, #Econet_FinishTransmission
        MOV     r9, #EconetV                            ; Turn off the hourglass
        SWI     XOS_CallAVector
        MOV     r0, r10
        BL      AbandonTransmit
        MOV     r0, #OsByte_AcknowledgeEscape
        SWI     XOS_Byte                                ; Doesn't enable IRQ, ignore the error
        MOV     r0, #Status_Escape
        CLRV
        Pull    "r9, pc"

TxPollError
        MOV     r10, r0                                 ; Keep the error
        SWI     XOS_EnterOS                             ; Get back to SVC mode, ignore error
        RestPSR r9                                      ; Restore interrupts and mode (might be IRQ)
        MOV     r0, #Econet_FinishTransmission
        MOV     r9, #EconetV                            ; Turn off the hourglass
        SWI     XOS_CallAVector
        MOV     r0, r10                                 ; Restore the original error
        SETV                                            ; Indicate that it was an error
        Pull    "r9, pc"

PollTransmit    ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Handle
        ;       R0 <= Status
        ;       Trashes R10 and R11

        Push    "r9, lr"                                ; Save IRQ state on stack
        PHPSEI                                          ; Also keep in R14
        ADR     r10, TxCBList - Offset_Link
        LDR     r9, =TxCBIdentifier
        B       ExamineLoop

AbandonTransmit ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Handle
        ;       R0 <= Status
        ;       Trashes R10 and R11

        Push    "r1-r3, lr"
        PHPSEI
        ADR     r2, TxCBList - Offset_Link
        LDR     r10, =TxCBIdentifier
AbandonTxLoop
        MOV     r1, r2
        LDR     r2, [ r2, #Offset_Link ]
        TEQ     r2, #NIL
        BNE     AbandonTxCheckIdentifier
        PLP
        Pull    "r1-r3, lr"
BadHandleExit
        ADR     r0, ErrorBadEconetHandle
        B       MakeError

ErrorBadEconetHandle
        DCD     ErrorNumber_BadEconetHandle
        DCB     "Channel", 0
        ALIGN

AbandonTxCheckIdentifier
        LDR     r11, [ r2, #Offset_Identifier ]
        TEQ     r11, r10
        BEQ     AbandonTxCheckHandle
        PLP
        Pull    "r1-r3, lr"
        B       InternalErrorExit

AbandonTxCheckHandle
        LDR     r11, [ r2, #Offset_Handle ]
        TEQ     r0, r11
        BNE     AbandonTxLoop
        [       NoAbandons
        ORR     r11, r11, #NIL
        STR     r11, [ r2, #Offset_Handle ]             ; Mark the handle as EVIL
        |
        LDR     r11, [ r2, #Offset_Link ]               ; Get the next item in the list
        STR     r11, [ r1, #Offset_Link ]               ; Link this record out
        ]
        PLP                                             ; Restore IRQs as soon as possible
        LDRB    r10, [ r2, #Offset_Status ] 
        TEQ     r10, #Status_Transmitting
        BNE     %97
95
        LD      r11, FIQBusy                            ; See if we are busy
        TEQ     r11, #0
        BNE     %95                                     ; It is busy
        LDRB    r11, [ r2, #Offset_Status ]
        TEQ     r11, #Status_Transmitted
        MOVEQ   r10, r11
97
        [       ErrorInfo
        ADRL    r3, TxErrors
        LDR     r11, [ r3, #:INDEX:TxCount - :INDEX:TxErrors ]
        INC     r11
        STR     r11, [ r3, #:INDEX:TxCount - :INDEX:TxErrors ]
        LDR     r11, [ r3, r10, ASL #2 ]
        INC     r11
        STR     r11, [ r3, r10, ASL #2 ]
        ]
        MOV     r0, #ModHandReason_Free
        [       NoAbandons
        CLRV
        |
        SWI     XOS_Module
        ]
        MOVVC   r0, r10                                 ; The final status
        Pull    "r1-r3, pc"

EnumerateTransmit ROUT                                  ; Now able to cope with IRQs enabled
        ;       R0 => Index
        ;       R0 <= Handle

        TEQ     r0, #0
        RETURNVC EQ
        Push    "r1-r4"
        PHPSEI  r4
        ADR     r1, TxCBList - Offset_Link
        LDR     r2, =TxCBIdentifier
        B       EnumerateControlBlockLoop               ; Common code in EnumerateReceive

        OPT     OptPage
        ; ***********************************************************
        ; ***   S W I   I m m e d i a t e   O p e r a t i o n s   ***
        ; ***********************************************************

StartImmediate  ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Flag byte
        ;       R1 => Destination Address (if needed)
        ;       R2 => Station
        ;       R3 => Net
        ;       R4 => Buffer Address
        ;       R5 => Size
        ;       R6 => Count
        ;       R7 => Delay
        ;       R0 <= Handle
        ;       R2 <= Buffer Address
        ;       R3 <= Station
        ;       R4 <= Net

        ORR     r0, r0, #BitSeven
        CMP     r0, #255
        BLS     %10                                     ; Control value OK (0..255) => (128..255)
BadControlExit
        ADR     r0, ErrorBadControl
        B       MakeError

ErrorBadControl
        DCD     ErrorNumber_BadControl
        DCB     "BadFlag", 0
        ALIGN
10                                                      ; Now check the port number, it must be (1..255)
        TEQ     r2, #0
        BEQ     BadStationExit
        CMP     r2, #255
        BHS     BadStationExit
        CMP     r3, #255
        BHS     BadNetExit
        LD      r11, LocalNetwork
        TEQ     r3, r11                                 ; Are we trying to transmit on the local net
        MOVEQ   r3, #0
45
        CMP     r5, #MaxTxSize
        BHI     BadSizeExit
        Push    "r0-r3, lr"                             ; Preserve over SWI
        MOV     r0, #ModHandReason_Claim
        MOV     r3, #Size_TxCB
        SWI     XOS_Module
        MOV     r10, r2
        STRVS   r0, [ sp, #0 ]                          ; Put heap error into stack for exit conditions
        Pull    "r0-r3, lr"
        MOVVS   pc, lr
        STRB    r0, [ r10, #Offset_Control ]
        STR     r1, [ r10, #Offset_Destination ]
        MOV     r0, #0
        STRB    r0, [ r10, #Offset_Port ]
        B       AddTxRecordToList

DoImmediate     ROUT                                    ; Now able to cope with IRQs enabled
        ;       R0 => Flag byte
        ;       R1 => Destination Address (if needed)
        ;       R2 => Station
        ;       R3 => Net
        ;       R4 => Buffer Address
        ;       R5 => Size
        ;       R6 => Count
        ;       R7 => Delay
        ;       R0 <= Status
        ;       R2 <= Buffer Address
        ;       R3 <= Station
        ;       R4 <= Net

        Push    "r9, lr"
        BL      StartImmediate                          ; Returns with the record in R10
        B       PollToCompletion

        LTORG

ErrorBadStation
        DCD     ErrorNumber_BadStation
        DCB     "BadStn", 0
        ALIGN
ErrorBadNetwork
        DCD     ErrorNumber_BadNetwork
        DCB     "BadNet", 0
        ALIGN

        ; *********************************************
        ; ***   S W I   M i s c   R o u t i n e s   ***
        ; *********************************************

ReadTransportType ROUT
        MOV     r2, #2
        RETURNVC

Version         ROUT
        LDR     r2, =Module_Version
        RETURNVC

NetworkState    ROUT
        LD      r2, Status2
        ANDS    r2, r2, #DCD
        MOVNE   r2, #1
        RETURNVC

PacketSize      ROUT
        MOV     r2, #&500
        RETURNVC

ReadTransportName
        ADRL    r2, ModuleTitle
        RETURNVC

ConvertStatusToError ROUT                               ; Now able to cope with IRQs enabled
        ; R0 => Status number
        ; R1 => Pointer to core if required (or used)
        ; R2 => Maximum buffer size
        ; R3 => Station number (if used) or a pointer to text
        ; R4 => Network number (if used)
        ; R0 <= Error pointer (maybe R1, maybe ROM)
        AND     r0, r0, #&FF                            ; Only bother with the bottom byte
        CMP     r0, #Status_MaxValue
        BGT     BadStatus
        Push    "r1-r4, lr"
        TEQ     r0, #Status_NotListening
        ADREQ   r11, ErrorStationNotListening
        BEQ     ConvertErrorWithArgument
        TEQ     r0, #Status_NoReply
        ADREQ   r11, ErrorNoReplyFromStation
        BEQ     ConvertErrorWithArgument
        TEQ     r0, #Status_NotPresent
        ADREQ   r11, ErrorStationNotPresent
        BEQ     ConvertErrorWithArgument
        TEQ     r0, #Status_NetError
        BNE     StandardError
        ADR     r11, ErrorStationNetError
        TEQ     r3, #&FF                                ; Is this a broadcast?
        BNE     ConvertErrorWithArgument                ; No, so add number to message
        MOV     r0, #Status_BroadcastNetError
StandardError
        ADR     r14, TokenTable
        ADD     r14, r14, r0, LSL #3                    ; TokenTable + Status * 8
        ADD     r0, r14, r0, LSL #2                     ; TokenTable + Status * 12
        MOV     r4, #0
        MOV     r3, r2                                  ; Buffer size
        MOV     r2, r1                                  ; Buffer address
        BL      MessageTransErrorLookup
        Pull    "r1-r4, pc"

BadStatus
        ADR     r0, ErrorBadStatus
        B       MakeError

ConvertErrorWithArgument
        TEQ     r3, #0                                  ; Is the station number zero?
        BEQ     StandardError                           ; Yes so no substitution
        Push    "r0-r6"                                 ; Inputs to conversion
        CMP     r3, #255                                ; Is this an invalid station number?
        BHI     TryErrorWithText                        ; Yes, give up treating as station number
        ADD     r0, sp, #12                             ; Point at the input parameters
        ADD     r1, sp, #20                             ; Point at the output string space
        MOV     r2, #8                                  ; String size
        SWI     XOS_ConvertNetStation
        BVS     ErrorWithTextFails
        ADD     r4, sp, #20
ErrorWithText
        Pull    "r0-r2"
        MOV     r0, r11                                 ; Selected error block
        MOV     r3, r2                                  ; Buffer size
        MOV     r2, r1                                  ; Buffer address
        BL      MessageTransErrorLookup
        INC     sp, 16                                  ; Remove stack frame
        Pull    "r1-r4, pc"

TryErrorWithText
        MOV     r0, r3
        MOV     r1, r3
ErrorWithTextLoop
        SWI     XOS_ValidateAddress
        BVS     ErrorWithTextFails
        BCS     ErrorWithTextFails
        LDRB    r2, [ r1 ], #1
        TEQ     r2, #0                                  ; Is this the terminator?
        BNE     ErrorWithTextLoop
        MOV     r4, r0                                  ; The argument pointer
        B       ErrorWithText

ErrorWithTextFails
        Pull    "r0-r2"
        INC     sp, 16                                  ; Remove stack frame
        B       StandardError                           ; Do it as normal

ConvertStatusToString ROUT                              ; Now able to cope with IRQs enabled
        ;       R0 => Status number
        ;       R1 => Destination core
        ;       R2 => Number of bytes remaining in the buffer
        ;       R3 => Station number (if used) or a pointer to text
        ;       R4 => Network number (if used)
        ;       R0 <= Input value of R1
        ;       R1 <= Updated pointer
        ;       R2 <= Bytes remaining, updated
        AND     r0, r0, #&FF                            ; Only bother with the bottom byte
        CMP     r0, #Status_MaxValue
        BGT     BadStatus
        Push    "r3-r4, lr"
        TEQ     r0, #Status_NotListening
        ADREQ   r11, TokenStationNotListening
        BEQ     ConvertStringWithArgument
        TEQ     r0, #Status_NoReply
        ADREQ   r11, TokenNoReplyFromStation
        BEQ     ConvertStringWithArgument
        TEQ     r0, #Status_NotPresent
        ADREQ   r11, TokenStationNotPresent
        BEQ     ConvertStringWithArgument
        TEQ     r0, #Status_NetError
        BNE     StandardConvert
        ADR     r11, TokenStationNetError
        TEQ     r3, #&FF                                ; Is this a broadcast?
        BNE     ConvertStringWithArgument               ; No, so add number to message
        MOV     r0, #Status_BroadcastNetError
StandardConvert
        Push    r2                                      ; Save the buffer length for later
        MOV     r3, r2                                  ; Buffer size
        MOV     r2, r1                                  ; Buffer address
        ADR     r14, TokenTable + 4                     ; Skip the error numbers
        ADD     r14, r14, r0, LSL #3                    ; TokenTable + Status * 8
        ADD     r1, r14, r0, LSL #2                     ; TokenTable + Status * 12
        MOV     r4, #0
        BL      MessageTransGSLookup
        MOVVC   r0, r2                                  ; Address of result
        ADDVC   r1, r0, r3                              ; Point at the message
        Pull    r2
        SUBVC   r2, r2, r3                              ; Work out how much space is left
        Pull    "r3-r4, pc"

ConvertStringWithArgument
        TEQ     r3, #0                                  ; Is the station number zero?
        BEQ     StandardConvert                         ; Yes so no substitution
        Push    "r0-r6"                                 ; Inputs to conversion
        CMP     r3, #255                                ; Is this an invalid station number?
        BHI     TryStringWithText                       ; Yes, give up treating as station number
        ADD     r0, sp, #12                             ; Point at the input parameters
        ADD     r1, sp, #20                             ; Point at the output string space
        MOV     r2, #8                                  ; String size
        SWI     XOS_ConvertNetStation
        BVS     StringWithTextFails
        ADD     r4, sp, #20
StringWithText
        Pull    "r0-r1"
        LDR     r3, [ sp, #0 ]                          ; Buffer size
        MOV     r2, r1                                  ; Buffer address
        MOV     r1, r11                                 ; Selected token
        ADD     r4, sp, #12
        BL      MessageTransGSLookup
        MOVVC   r0, r2                                  ; Address of result
        ADDVC   r3, r3, #1                              ; Allow for the terminator
        ADDVC   r1, r0, r3                              ; Point at the message
        Pull    r2
        SUBVC   r2, r2, r3                              ; Work out how much space is left
        INC     sp, 16                                  ; Remove stack frame
        Pull    "r3-r4, pc"

TryStringWithText
        MOV     r0, r3
        MOV     r1, r3
StringWithTextLoop
        SWI     XOS_ValidateAddress
        BVS     StringWithTextFails
        BCS     StringWithTextFails
        LDRB    r2, [ r1 ], #1
        TEQ     r2, #0                                  ; Is this the terminator?
        BNE     StringWithTextLoop
        MOV     r4, r0                                  ; The argument pointer
        B       StringWithText

StringWithTextFails
        Pull    "r0-r2"
        INC     sp, 16                                  ; Remove stack frame
        B       StandardConvert                         ; Do it as normal

ValidateReadAddress
        Push    lr
        SWI     XOS_ValidateAddress
        Pull    pc, VS
        ADRCS   Error, ErrorCoreNotReadable
ValidateExit
        BLCS    MakeError
        Pull    pc

ErrorCoreNotReadable
        DCD     ErrorNumber_CoreNotReadable
        DCB     "BadRead", 0
        ALIGN

ErrorBadStatus
        DCD     ErrorNumber_BadStatus
        DCB     "BadStat", 0
        ALIGN

TokenTable
        DCD     ErrorNumber_Transmitted
        DCB     "TxOK", 0
        ALIGN
        ASSERT  ( Status_LineJammed * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_LineJammed
        DCB     "LineJam", 0
        ALIGN
        ASSERT  ( Status_NetError * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_NetError
        DCB     "NetErr", 0
        ALIGN
        ASSERT  ( Status_NotListening * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_NotListening
        DCB     "NotLstn", 0
        ALIGN
        ASSERT  ( Status_NoClock * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_NoClock
        DCB     "NoClk", 0
        ALIGN
        ASSERT  ( Status_TxReady * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_TxReady
        DCB     "TxReady", 0
        ALIGN
        ASSERT  ( Status_Transmitting * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_Transmitting
        DCB     "Txing", 0
        ALIGN
        ASSERT  ( Status_RxReady * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_RxReady
        DCB     "RxReady", 0
        ALIGN
        ASSERT  ( Status_Receiving * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_Receiving
        DCB     "Rxing", 0
        ALIGN
        ASSERT  ( Status_Received * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_Received
        DCB     "Rxd", 0, 0
        ALIGN
        ASSERT  ( Status_NoReply * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_NoReply
        DCB     "NoReply", 0
        ALIGN
        ASSERT  ( Status_Escape * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_Escape
        DCB     "Escape", 0
        ALIGN
        ASSERT  ( Status_NotPresent * 12 ) = ( . - TokenTable )
        DCD     ErrorNumber_NotPresent
        DCB     "NotPres", 0
        ALIGN
        ASSERT  ( ( Status_MaxValue + 1 ) * 12 ) = ( . - TokenTable )
Status_BroadcastNetError * Status_MaxValue + 1
        DCD     ErrorNumber_NetError
        DCB     "BrdcstE", 0
        ALIGN

ErrorStationNotListening
        DCD     ErrorNumber_NotListening
TokenStationNotListening
        DCB     "StnNLsn", 0
        ALIGN
ErrorNoReplyFromStation
        DCD     ErrorNumber_NoReply
TokenNoReplyFromStation
        DCB     "StnNRpy", 0
        ALIGN
ErrorStationNotPresent
        DCD     ErrorNumber_NotPresent
TokenStationNotPresent
        DCB     "StnNPrs", 0
        ALIGN
ErrorStationNetError
        DCD     ErrorNumber_NetError
TokenStationNetError
        DCB     "StnNErr", 0
        ALIGN

ReadProtection
        LD      r0, Protection
        RETURNVC

SetProtectionMask
        LD      r10, Protection
        AND     r11, r10, r1
        EOR     r11, r11, r0
        TST     r11, #Econet_Prot_Continue :OR: Econet_Prot_MachinePeek
        BNE     ExitBadMask
        BIC     r11, r11, #Econet_Prot_WriteThrough     ; Don't let the write through bit in
        ST      r11, Protection
        TST     r0, #Econet_Prot_WriteThrough
        MOVEQ   r0, r10
        RETURNVC EQ
        Push    "r1, r2, lr"
        MOV     r0, #OsByte_WriteCMOS
        MOV     r1, #ProtectionCMOS
        MOV     r2, r11
        TST     r2, #Econet_Prot_GetRegisters
        EORNE   r2, r2, #BitEight :OR: BitSix           ; Set BitSix, clear BitEight
        TST     r2, #BitNine                            ; Save the reserved bit as well
        EORNE   r2, r2, #BitNine :OR: BitSeven          ; Set BitSeven, clear BitNine
        SWI     XOS_Byte
        MOVVC   r0, r10
        Pull    "r1, r2, pc"

ExitBadMask
        ADR     r0, ErrorBadMask
        B       MakeError

ErrorBadMask
        DCD     ErrorNumber_BadMask
        DCB     "BadMask", 0
        ALIGN

ReadLocalStation
        LD      r0, LocalStation
        LD      r1, LocalNetwork
        RETURNVC

; ***************************************************
; ***  R E A D   A   S T A T I O N   N U M B E R  ***
; ***************************************************
;
; Inputs   R1 : Address of number
; Outputs  R1 : Updated
;          R2 : Station number (-1 for not found)
;          R3 : Network number (-1 for not found)

ReadStationNumber ROUT                                  ; Now able to cope with IRQs enabled
        Push    "r0, lr"
        MOV     r10, #-1                                ; Set up the default values
        MOV     r11, #-1
        MOV     r2, #0                                  ; Handle no text at all
        LDRB    r0, [ r1 ]                              ; Check the first character
        TEQ     r0, #"."                                ; In case we have the special case
        BEQ     DefaultLeadingZero
        CMP     r0, #" "
        BLE     ReadCompleted
        MOV     r0, #10                                 ; Default base
        SWI     XOS_ReadUnsigned                        ; First number, could be either type
        BVS     ExitReadStation
        LDRB    r0, [ r1 ]                              ; Check the terminating character
        TEQ     r0, #"."
        ADDEQ   r1, r1, #1
        MOVEQ   r11, r2                                 ; It was a net nunber
        BEQ     ReadStationNumberPart
ReadCompleted
        CMP     r2, #-1
        BEQ     %10
        LDRB    r0, [ r1 ]                              ; Check the terminating character again
        CMP     r0, #" "
        BGT     %50                                     ; Must be bad
        MOV     r10, r2                                 ; It was a station number
DoneReadingStation
        CMP     r10, #-1
        BEQ     %30                                     ; No station number to check
        TEQ     r10, #0
        BEQ     %10
        CMP     r10, #254
        BLS     %30
10
        ADRL    r0, ErrorBadStation
20
        BL      MakeError
ExitReadStation
        STRVS   r0, [ sp ]
        MOV     r2, r10
        MOV     r3, r11
        Pull    "r0, pc"

60
        ADRL    r0, ErrorBadNetwork
        B       %20

30
        CMP     r11, #-1
        BEQ     %40
        CMP     r11, #254
        BHI     %60
40
        CLRV
        B       ExitReadStation

DefaultLeadingZero
        MOV     r11, #0
        INC     r1
ReadStationNumberPart
        CMP     r2, #-1
        BEQ     %60
        LDRB    r0, [ r1 ]                              ; Check the first character
        CMP     r0, #" "
        BLE     DoneReadingStation                      ; Exit if not any more characters
        MOV     r0, #10                                 ; Default base
        SWI     XOS_ReadUnsigned                        ; Second number will be station
        BVS     ExitReadStation
        B       ReadCompleted

50
        ADR     r0, ErrorBadNumb
        B       %20

ErrorBadNumb
        DCD     ErrorNumber_BadNumb
        DCB     "BadNumb", 0
        ALIGN

HardwareAddresses ROUT
        ;       R0 ==> Address of the MC68B54
        ;       R1 ==> Address of the FIQ mask register
        ;       R2 ==> Bit mask to use on the FIQ mask register

        ASSERT  InterruptAddress - HardwareAddress = 4
        ASSERT  InterruptMask - InterruptAddress = 4
        ADR     r0, HardwareAddress
        LDMIA   r0, {r0, r1, r2}                        ; Hardware, Interrupt, Mask
        [       ?InterruptMask = 1
        AND     r2, r2, #&FF
        |
        [       ?InterruptMask <> 4
        !       1, "InterruptMask is neither a byte or a word"
        ]
        ]
        RETURNVC

        LTORG

InetRxDirect
        RETURNVC

EnumerateMap
        ;       R0 <== Flags, all reserved must be zero
        ;       R4 <== Enumeration reference, 0 to start
        ;       R1 ==> Net number
        ;       R2 ==> Pointer to the net name
        ;       R3 ==> IP subnetwork address
        ;       R4 ==> Next enumeration reference, -1 for no more
        MOV     r4, #-1
        RETURNVC

NetworkParameters ROUT
        ;       R0 ==>  Network clock period in quarter micro seconds
        ;               e.g. 5 micro seconds is &16
        ;       R1 ==>  Network clock frequency in KHz
        ;               e.g. &C8
        ;       R2 ==>  Reserved
        ;       R3 ==>  Reserved
        [       BroadcastByHand
        LD      r0, BroadcastTime
        TEQ     r0, #0
        MOVEQ   r1, #0
        BEQ     ExitNetworkParameters
        MOV     r2, #4000
        DivRem  r1, r2, r0, r3
        |
        MOV     r0, #0
        MOV     r1, #0
        ]
ExitNetworkParameters
        [       DebugFindLocalNet
        DREG    r0, "Period in 250ns: "
        DREG    r1, "Frequency in KHz: "
        ]
        RETURNVC

        OPT     OptPage

AllocatePort    ROUT
        ;       R0 <= Port
        ;       Ports are stored in an array of words, each Port has an enumerated type
        ;       representing its state, 2_00 for not allocated, 2_01 for allocated and
        ;       2_10 for permanently allocated.  These are stored 16 to a word in 16 words
        ;       the first word contains Ports 0 to 15 etc. and within each word the Ports
        ;       are stored low Port in low bits so bits 2 and 3 have Port 1's data.

        Push    "r1-r4, lr"
        LD      r0, PortHint
        MOV     r4, r0                                  ; Save hint for limit check
TryNextPort
        INC     r0
        [       {TRUE}                                  ; New Port allocation strategy
        TEQ     r0, #Port_AllocationMaximum + 1
        MOVEQ   r0, #Port_AllocationMinimum
        |
        AND     r0, r0, #&FF                            ; Keep it down to a byte
        ]
        TEQ     r0, r4
        BEQ     NoMorePortsExit
        BL      FindPort
        LDR     r14, [ r1 ]
        MOV     r3, #2_11                               ; Mask value
        TST     r14, r3, LSL r2                         ; Check
        BNE     TryNextPort
        MOV     r3, #2_01                               ; New value
        ORR     r14, r14, r3, LSL r2                    ; OR is OK since field must have been zero
        ST      r0, PortHint
UpdatePortTable
        STR     r14, [ r1 ]
        CLRV
        Pull    "r1-r4, pc"

DeAllocatePort
        ;       R0 => Port
        Push    lr
        BL      CheckPort
        BL      FindPort
        LDR     r14, [ r1 ]
        MOV     r3, r14, LSR r2                         ; Put old state at the bottom
        AND     r3, r3, #2_11                           ; Mask to get only this value
        TEQ     r3, #2_01
        BNE     PortNotAllocatedExit
ClearPort
        MOV     r3, #2_11                               ; Clearance mask
        BIC     r14, r14, r3, LSL r2
        B       UpdatePortTable

ClaimPort
        ;       R0 => Port
        Push    lr
        BL      CheckPort
        BL      FindPort
        LDR     r14, [ r1 ]
        MOV     r3, #2_11                               ; Mask
        TST     r14, r3, LSL r2
        BNE     PortAllocatedExit
        MOV     r3, #2_10                               ; New value
        ORR     r14, r14, r3, LSL r2                    ; OR is OK since field must have been zero
        B       UpdatePortTable

ReleasePort
        ;       R0 => Port
        Push    lr
        BL      CheckPort
        BL      FindPort
        LDR     r14, [ r1 ]
        MOV     r3, r14, LSR r2                         ; Put old state at the bottom
        AND     r3, r3, #2_11                           ; Mask to get only this value
        TEQ     r3, #2_10
        BEQ     ClearPort
PortNotReservedExit
PortNotAllocatedExit
        ADR     Error, ErrorPortNotAllocated
        B       PortExit

FindPort        ROUT
        ;       Takes a Port and returns the address and shift value
        ;       R0 => Port
        ;       R1 <= Address
        ;       R2 <= Shift value [ 0, 2, 4, ... 28, 30 ]
        AND     r2, r0, #2_11110000                     ; Mask off the offset part
        ADR     r1, PortTable
        ADD     r1, r1, r2, LSR #2                      ; Add in the offset
        AND     r2, r0, #2_00001111
        MOV     r2, r2, LSL #1                          ; Calculate the shift value
        MOV     pc, lr

CheckPort       ROUT
        TEQ     r0, #0
        BEQ     PortBadExit
        CMP     r0, #254
        BHI     PortBadExit
        Push    "r1-r4"
        MOV     pc, lr

PortAllocatedExit
        ADR     Error, ErrorPortAllocated
        B       PortExit

NoMorePortsExit
        ADR     Error, ErrorNoMorePorts
PortExit
        BL      MakeError
        Pull    "r1-r4, pc"

PortBadExit
        ADRL    r0, ErrorBadPort
        BL      MakeError
        Pull    pc

ErrorPortNotAllocated
        DCD     ErrorNumber_PortNotAllocated
        DCB     "PtNtAlc", 0
        ALIGN
ErrorPortAllocated
        DCD     ErrorNumber_PortAllocated
        DCB     "PortAlc", 0
        ALIGN
ErrorNoMorePorts
        DCD     ErrorNumber_NoMorePorts
        DCB     "NoPorts", 0
        ALIGN

        LTORG

        END
