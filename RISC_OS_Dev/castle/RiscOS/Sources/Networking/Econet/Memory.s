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
        SUBT            Arthur.  File ==> &.Arthur.Econet.Memory

TxCBIdentifier  *       &42437854
RxCBIdentifier  *       &42437858


         ^       0                                      ; Layout of RxCBs and TxCBs
        Word    Offset_Identifier
        Word    Offset_Link
        Byte    Offset_Status
        Byte    Offset_Station
        Byte    Offset_Network
        Byte    Offset_Port
        Byte    Offset_Control
        Byte    Offset_Local
        Byte    Offset_Broadcast
        Word    Offset_Event
        Word    Offset_Handle
        Word    Offset_Start
        Word    Offset_Size
        Byte    Size_CommonCB, 0

        ^       Size_CommonCB
        Word    Offset_Count
        Word    Offset_Delay
        Word    Offset_Time
        Word    Offset_ClaimTime
        Word    Offset_Destination
        Byte    Size_TxCB, 0

        ^       Size_CommonCB
        Word    Offset_RxSize
        Byte    Offset_RxStation
        Byte    Offset_RxNetwork
        Byte    Offset_RxPort
        Byte    Size_RxCB, 0

Event_NotReady  *       &FFFFFFFE                       ; A large number
Event_Done      *       &FFFFFFFF                       ; A larger number

        ^       &1C                                     ; This is all the FIQ space we use
        Word    FIQVector, 2                            ; This is LDR pc, .+4 and some data
        Word    NextJump                                ; This is for single level subroutines
        Word    ModuleWorkspace                         ; This is so the FIQ code can see Econet's variables
        Word    Registers, (16 + 2 + 2)                 ; Marshalling space for User + IRQ + SVC
        Byte    SmallTextBuffer, 12
        [       DebugFIQ
        Word    DebugSpacePointer
        Byte    DebugSpace, 124
        Word    DebugSpaceEnd, 0
        ]
        [       @ > &100
        !       0, "FIQ Variable overflow."
        ]

        ^       0, wp                                   ; These are all WORD aligned
        Word    Time                                    ; Local centi-second clock
        Word    TxCBList
        Word    RxCBList                                ; The address of the first RxCB
        Word    Protection
        Word    Record                                  ; Here we maintain a pointer to the current record
        Word    RxMode                                  ; Top byte has the mode bits,
                                                        ; bottom half word has the destination address
        Word    TxMode                                  ; Top byte has the mode bits,
        Word    PowerDownTime                           ; When "Time" >= to this then Power Down
        Word    MachinePeekData                         ; Computed at init-time

        Word    HardwareAddress                         ; MC68B54
        Word    InterruptAddress
        Byte    InterruptMask

        Byte    SWILock                                 ; Indicates, to FIQ code, we are servicing a SWI
        Byte    LockOut                                 ; Used to lock out more immediate ops when
                                                        ; the current one hasn't been serviced yet
        Byte    Status2                                 ; Last copy of SReg2, used to get the DCD state
        Byte    PortHint

        Byte    FIQBusy                                 ; Zero for not busy, non zero for busy
        Byte    PeekPokeFlag                            ; Non zero for doing a peek or poke downgrade
        Byte    FIQStatus                               ; 0 ==> Owner, 1 ==> Non-Owner, 2 ==> Powered Down

FIQ_Owner       *       0
FIQ_Released    *       1
FIQ_PoweredDown *       2

        Byte    LocalStation
        Byte    LocalNetwork
        Byte    LocalBridgeVersion                      ; Used (with previous byte) to receive the Bridge reply

        [       ReceiveInBackground
        Word    BridgeRxHandle                          ; For the bridge to reply into
        ]
        [       BroadcastByHand
        Word    BroadcastTime
        ]
        [       DebugFindLocalNet
        Word    InitTimer0
        ]
        Word    CurrentHandle                           ; Used for TxCBs and RxCBs, incremented by 4

        Word    EventSequenceNumber                     ; Used to ensure events are offered in the correct order

        Word    PortTable, 16                           ; 256 2bit set [ 0..255 ]

        Word    MessageBlockAddress
        Word    MessageBlock, 4                         ; Needed by MessageTrans

        Word
        Byte    ScoutBuffer, &410

        Word    ArgumentsAddressOrNumber
        Word    ArgumentsSize
        Byte    ArgumentsBuffer, &100

        Word
        ASSERT  Size_TxCB > Size_RxCB
        Byte    ImmediateRecord, Size_TxCB              ; Used while peek and poke happen

BroadcastBit    *       1 :SHL: 29
ImmediateBit    *       1 :SHL: 28
LongBit         *       1 :SHL: 27                      ; Immediate scout is longer (Peek or Poke)
ShortBit        *       1 :SHL: 26                      ; Immediate scout is shorter (Halt, Cont or GetRegs)
PeekBit         *       1 :SHL: 25                      ; Immediate operation is a two way 'Peek' type
TwoWayBit       *       1 :SHL: 24                      ; Immediate operation is a two way (Halt, Cont)
        [       ErrorInfo
        Word    ErrorLogArea, 0
        Word    RxErrors, Status_MaxValue + 1
        Word    RxCount
        Word    TxErrors, Status_MaxValue + 1
        Word    TxCount
        Word    TxFails
        Word    ErrorLogAreaEnd, 0
        ]
        [       ControlBlocks :LOR: ErrorInfo
        Byte    TextBuffer, &100
        ]
        [       Debug
        Word    NetErrorListPointer
        Word    NetErrorList, 1000
        ]

TotalRAMRequired * :INDEX: @

        ;       Hardware definitions for the MC68B54
        ;       Advanced Data Link Controller
        ^       0, r10
        Byte    CReg1                                   ; Control register 1
        Overlap CReg1, SReg1                            ; Status  register 1
        Word
        Byte    CReg2                                   ; Control register 2
        Overlap CReg2, CReg3                            ; Control register 3
        Overlap CReg2, SReg2                            ; Status  register 2
        Word
        Byte    TxByte                                  ; Transmit data byte
        Overlap TxByte, RxByte                          ; Receive  data byte
        Word
        Byte    CReg4                                   ; Control register 4
        Overlap CReg4, TxLast                           ; Transmit last data byte

        ;       Status register 1 bit assignments

RxDataAvailable *       BitZero
SReg2Req        *       BitOne                          ; Status register 2 request
LoopStatus      *       BitTwo
FlagDetected    *       BitThree
CTS             *       BitFour                         ; Clear to send
TxUnderrun      *       BitFive                         ; Transmitter underrun
TxDRA           *       BitSix                          ; Transmit data register available
FrameComplete   *       BitSix                          ; Transmited frame is complete
INT             *       BitSeven                        ; An interrupt is pending

        ;       Status register 2 bit assignments

AddressPresent  *       BitZero
FrameValid      *       BitOne
RxIdle          *       BitTwo
RxAbort         *       BitThree
CRC             *       BitFour                         ; Frame check sequence error
DCD             *       BitFive                         ; Data carier detect
OverRun         *       BitSix                          ; Receiver overrun
RxDA            *       BitSeven                        ; Receive data available

        END
