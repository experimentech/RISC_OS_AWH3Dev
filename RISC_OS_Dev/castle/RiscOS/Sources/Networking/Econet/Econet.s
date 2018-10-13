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
        SUBT    Arthur.  File => &.Arthur.Econet.Econet
        TTL     Econet for Arthur.

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:IO.IOC-A1
        GET     Hdr:VIDC.VIDC1A ; VIDC20
        GET     Hdr:MEMM.MEMC1  ; ARM600
        GET     Hdr:Symbols
        GET     Hdr:OsBytes
        GET     Hdr:FSNumbers
        GET     Hdr:CMOS
        GET     Hdr:ModHand
        GET     Hdr:HostFS
        GET     Hdr:Debug
        GET     Hdr:Econet
        GET     Hdr:Services
        GET     Hdr:NewErrors
        GET     Hdr:ResourceFS
        GET     Hdr:Tokens
        GET     Hdr:MsgTrans
        GET     Hdr:Portable
        GET     Hdr:Podule
        GET     Hdr:PoduleReg

        GET     Macros.s

        GET     VersionASM

MySWIChunkBase  *       EconetSWI_Base
                ASSERT  MySWIChunkBase = Econet_CreateReceive

        ;       Code configuration constants

BridgeWaitTime  *       300                             ; Three seconds
ClaimTime       *       1000                            ; Ten seconds
PowerDownTimeout *      1600                            ; Sixteen seconds
MaxTxSize       *       8192                            ; 8Kbytes

        ;       Code configuration variables

                GBLL    StrongARM
                GBLL    ReleaseVersion
                GBLL    PerthPowerDown
                GBLL    UsePortableModule
                GBLL    ReceiveInBackground
                GBLL    BroadcastByHand

StrongARM       SETL    {TRUE}
ReleaseVersion  SETL    {TRUE}
PerthPowerDown  SETL    {TRUE}
UsePortableModule SETL  {TRUE}
ReceiveInBackground SETL {TRUE}
BroadcastByHand SETL    ReceiveInBackground :LAND: {TRUE}

    [ :LNOT: :DEF: standalone
                GBLL    standalone
standalone      SETL    {FALSE}                         ; Build-in Messages file and i/f to ResourceFS
    ]

        ;       Debug code configuration variables

                GBLL    ErrorInfo
                GBLL    ControlBlocks
                GBLL    PortInfo
                GBLL    Variables

ErrorInfo       SETL    (:LNOT: ReleaseVersion) :LAND: {TRUE}
ControlBlocks   SETL    (:LNOT: ReleaseVersion) :LAND: {TRUE}
PortInfo        SETL    (:LNOT: ReleaseVersion) :LAND: {TRUE}
Variables       SETL    (:LNOT: ReleaseVersion) :LAND: {TRUE}

        ;       Debugging controls

                GBLL    Debug
                GBLL    DebugIRQ
                GBLL    DebugSWIs
                GBLL    DebugFindHardware
                GBLL    DebugPowerDown
                GBLL    DebugFindLocalNet
                GBLL    NoAbandons
                GBLL    Host_Debug
                GBLL    Debug_MaybeIRQ
                GBLL    Analyser
                GBLL    DebugFIQ

Debug           SETL    (:LNOT: ReleaseVersion) :LAND: {FALSE}
DebugIRQ        SETL    (:LNOT: ReleaseVersion) :LAND: {FALSE}
DebugSWIs       SETL    (:LNOT: ReleaseVersion) :LAND: {FALSE}
DebugFindHardware SETL  (:LNOT: ReleaseVersion) :LAND: {FALSE}
DebugPowerDown  SETL    (:LNOT: ReleaseVersion) :LAND: {FALSE}  ; Using the border colours
DebugFindLocalNet SETL  (:LNOT: ReleaseVersion) :LAND: {FALSE}
NoAbandons      SETL    Debug :LAND: ControlBlocks :LAND: {FALSE}
Host_Debug      SETL    {FALSE}
Debug_MaybeIRQ  SETL    {TRUE}
Analyser        SETL    (:LNOT: ReleaseVersion) :LAND: {FALSE}
DebugFIQ        SETL    (:LNOT: ReleaseVersion) :LAND: {FALSE}

                GBLS    Alignment
Alignment       SETS    "16, 12"

        AREA    |Econet$$code|, CODE, READONLY, PIC
Origin
        DCD     0                                       ; Start
        DCD     InitModule - Origin                     ; Initialisation
        DCD     KillModule - Origin                     ; Die
        DCD     Service - Origin
        DCD     ModuleTitle - Origin
        DCD     HelpString - Origin
        DCD     HelpTable - Origin                      ; Command Table
        DCD     MySWIChunkBase
        DCD     SWIHandler - Origin
        DCD     SWINameTable - Origin
      [ :LNOT: No32bitCode
        DCD     0
        DCD     0
        DCD     ModuleFlags - Origin
      ]

        GET     Memory.s

        SUBT    Module entry stuff
        OPT     OptPage

HelpString
        DCB     "Econet", 9, 9, Module_HelpVersion, 0
        ALIGN
      [ :LNOT: No32bitCode
ModuleFlags
        DCD     ModuleFlag_32bit
      ]

MachineVersionNumber
        DCB     7                                       ; Archimedes type byte
        DCB     0                                       ; Acorn Computers
        ; The following converts a two character string expected to
        ; contain "00" to "99" to a BCD value ( in 'Vers' ).
        GBLA    Vers
Vers    SETA    16 * ((Module_Version/10):MOD:10) + (Module_Version:MOD:10)
        [       ReleaseVersion                          ; On release version use Vers
        DCB     Vers
        |                                               ; Otherwise use Vers + 01
        [       ( Vers :AND: &F ) = 9                   ; So that this has the same number
        DCB     Vers + 7                                ; as the release version to follow
        |
        DCB     Vers + 1
        ]
        ]
        DCB     5

        SUBT    Initialisation code
        OPT     OptPage

InitModule ROUT
        Push    lr
        ;       R0-R6 ==> Trashable
        ;       R7-R9 ==> Must be preserved
        ;       R10   ==> Pointer to environment string
        ;       R11   ==> I/O base or instantiation number
        ;       R12   ==> Pointer to private word
        ;       R13   ==> Valid stack pointer
        MOV     r6, r10                                 ; Save the environment string
        MOV     r0, #PortableControl_EconetEnable
        MVN     r1, #PortableControl_EconetEnable
        SWI     XPortable_Control                       ; Ignore possible error
      [ standalone
        ADRL    r0, ResourceFiles
        SWI     XResourceFS_RegisterFiles
        Pull    pc, VS                                  ; Give up now if failure
      ]
        PHPSEI  r5                                      ; Check for the hardware
        [       DebugFindHardware
        MOV     r4, #0
        ]
        LDR     r10, =Podule_BaseAddressANDMask
        AND     r10, r11, r10                           ; Get the pure base address
        [       DebugFindHardware
        DREG    r10, "Separated hardware address = &"
        ]
        CMP     r10, #&03000000
        BHI     AddressKnown                            ; I/O address (ROM loaded)
        SWI     XPodule_ReturnNumber                    ; Instance number (RAM loaded)
        BVS     AddressUnknown
        MOV     r3, r0                                  ; Number of podules
FindPoduleLoop
        DECS    r3
        BMI     AddressUnknown
        [       DebugFindHardware
        BREG    r3, "Podule_ReadInfo: R3 = &"
        ]
        Push    "r10, r11, r14"
        MOV     r0, #Podule_ReadInfo_SyncBase + Podule_ReadInfo_ID + Podule_ReadInfo_Type
        MOV     r1, sp
        MOV     r2, #3*4
        SWI     XPodule_ReadInfo
        Pull    "r10, r11, r14"
        [       DebugFindHardware
        DREG    r10, "Synchronous base address = &"
        BREG    r11, "ID = &"
        DREG    r14, "Type = &"
        ]
        BVS     FindPoduleLoop
        BIC     r11, r11, #2_101                        ; Knock out FIQ/IRQ request bits
        TEQ     r11, #SimpleType_Econet:SHL:3
        BEQ     AddressKnown
        TEQ     r11, #SimpleType_Extended:SHL:3
        TEQEQ   r14, #ProdType_Econet
        BEQ     AddressKnown
        B       FindPoduleLoop

AddressUnknown
        LDR     r10, =EconetController                  ; Default for internal hardware
AddressKnown
        [       DebugFindHardware
        DREG    r10, "Address we are using = &"
        ]
        MOV     r0, #2_11111000                         ; TxRst, RxRst, FrDisc, TxDataSrvRq, RxDataSrvRq, -TIE, -RIE, -AC
        STRB    r0, CReg1
        MOV     r0, #2_01111111                         ; -RTS, ClrTxSt, ClrRxSt, TxLast, FrComp, Flag, 2Byte, PSE
        STRB    r0, CReg2
        LDRB    r1, SReg1
        [       DebugFindHardware
        BREG    r1, "Test #1  SReg1  = &"
        ]
        TST     r1, #2_11101101                         ; IRQ, FC, TxU, -CTS, FlagDet, Loop, -SR2Rq, RDA
        [       DebugFindHardware
        MOVNE   r4, #"1"
        ]
        BNE     NoHardware                              ; Any of these bits means no hardware
        MOV     r0, #2_01111111                         ; -RTS, ClrTxSt, ClrRxSt, TxLast, FrComp, Flag, 2Byte, PSE
        STRB    r0, CReg2
        LDRB    r2, SReg2
        [       DebugFindHardware
        BREG    r2, "Test #2  SReg2  = &"
        ]
        TST     r2, #2_11011011                         ; RxDataAvail, RxOverrun, -DCD, FCSErr, RxAbort, -Idle, FV, AP
        [       DebugFindHardware
        MOVNE   r4, #"2"
        ]
        BNE     NoHardware                              ; Any of these bits means no harware
        MOV     r0, #0                                  ; Write a zero out onto the bus
        STR     r0, CReg4
        LDRB    r0, SReg1                               ; Read them back in
        LDRB    r1, SReg2                               ; One by one to see
        [       DebugFindHardware
        BREG    r0, "Test #3  SReg1  = &"
        BREG    r1, "Test #3  SReg2  = &"
        ]
        TEQ     r0, r1                                  ; If they are all the same
        BNE     Hardware                                ; If they aren't then there is something there
        LDRB    r1, RxByte
        [       DebugFindHardware
        BREG    r1, "Test #3  RxByte = &"
        ]
        TEQ     r0, r1
        BNE     Hardware
        LDRB    r1, CReg4
        [       DebugFindHardware
        BREG    r1, "Test #3  RxByte = &"
        ]
        TEQ     r0, r1
        BNE     Hardware
        TEQ     r0, #0                                  ; Were they all zero ?
        [       DebugFindHardware
        MOVNE   r4, #"3"
        ]
        BNE     NoHardware                              ; All zero means that there was nothing there but empty space

        MOV     r0, #2_10000010                         ; TxReset, RxIE, AC=0
        STRB    r0, CReg1
        MOV     r0, #2_11100101                         ; RTS, ClrTxStatus, ClrRxStatus, FlagIdle, 1Byte, PSE
        STRB    r0, CReg2
        MOV     r0, #&100000                            ; A delay is needed here
26                                                      ; for the turning on of RTS to take effect ??
        DECS    r0
        BNE     %26
        LDRB    r1, SReg1
        [       DebugFindHardware
        BREG    r1, "Test #4  SReg1  = &"
        ]
        TST     r1, #2_11101101                         ; IRQ, FC, TxU, -CTS, FlagDet, Loop, -SR2Rq, RDA
        BNE     Hardware                                ; Any bits set means there was something there
        LDRB    r2, SReg2
        [       DebugFindHardware
        BREG    r2, "Test #4  SReg2  = &"
        ]
        TST     r2, #2_11011011                         ; RxDataAvail, RxOverrun, -DCD, FCSErr, RxAbort, -Idle, FV, AP
        BNE     Hardware                                ; Any bits set means there was something there
        [       DebugFindHardware
        MOV     r4, #"4"
        ]
NoHardware
        PLP     r5
        [       DebugFindHardware
        TEQ     r4, #0
        BEQ     %92
        Push    "r1, r2"
        DEC     sp, 12
        SWI     OS_WriteS
        DCB     "SReg1 = &", 0
        ALIGN
        LDR     r0, [ sp, #12 ]
        MOV     r1, sp
        MOV     r2, #11
        SWI     OS_ConvertHex2
        SWI     OS_Write0
        SWI     OS_WriteS
        DCB     13, 10, "SReg2 = &", 0
        ALIGN
        LDR     r0, [ sp, #16 ]
        MOV     r1, sp
        MOV     r2, #11
        SWI     OS_ConvertHex2
        SWI     OS_Write0
        INC     sp, 12
        Pull    "r1, r2"
        SWI     OS_WriteS
        DCB     13, 10, "Failure #", 0
        ALIGN
        MOV     r0, r4
        SWI     OS_WriteC
        SWI     OS_WriteS
        DCB     ". Press a key to continue.", 13, 10, 0
        ALIGN
        SWI     OS_ReadC
92
        ]
        DEC     sp, ?MessageBlock
        MOV     r0, sp                                  ; Address of the temporary block
        ADRL    r1, MessageFileName
        MOV     r2, #0                                  ; Use the file where it is
        SWI     XMessageTrans_OpenFile
        BVS     ExitNoHardware                          ; Very tragic, exit immediately
        ADR     r0, ErrorNoHardware
        MOV     r1, sp                                  ; Address of the temporary block
        MOV     r2, #0                                  ; Allocate a buffer for me
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        [       {FALSE} ; Debug
        DREG    r0, "R0 = &", cc
        DREG    r1, "  R1 = &", cc
        DREG    r2, "  R2 = &", cc
        DREG    r3, "  R3 = &"
        DREG    r4, "R4 = &", cc
        DREG    r5, "  R5 = &", cc
        DREG    r6, "  R6 = &", cc
        DREG    r7, "  R7 = &"
        ]
        SWI     XMessageTrans_ErrorLookup               ; Always returns an error
        MOV     r7, r0                                  ; Keep the error pointer
        MOV     r0, sp                                  ; Address of the temporary block
        SWI     XMessageTrans_CloseFile
      [ standalone
        ADRL    r0, ResourceFiles
        SWI     XResourceFS_DeregisterFiles
      ]
        MOV     r0, r7                                  ; Get back the translated error
ExitNoHardware
        INC     sp, ?MessageBlock                       ; Restore the stack
        SETV
        Pull    pc

ErrorNoHardware
        DCD     ErrorNumber_NoHardware
        DCB     "NoHware", 0
        ALIGN

Hardware
        PLP     r5
        ;       R0-R5 ==> Trashable
        ;       R6    ==> Trashable, but contains the environment string pointer
        ;       R7-R9 ==> Must be preserved
        ;       R10   ==> Pointer to the hardware
        ;       R11   ==> Trashable
        ;       R12   ==> Pointer to private word
        ;       R13   ==> Valid stack pointer
        [       DebugFindHardware
        DLINE   "Hardware detected"
        ]
        LDR     r3, [ r12 ]                             ; Private word
        TEQ     r3, #0
        MOVNE   wp, r3
        BNE     ReInitialisation
        MOV     r0, #ModHandReason_Claim
        LDR     r3, =TotalRAMRequired
        SWI     XOS_Module
        Pull    pc, VS
        STR     r2, [ r12 ]
        MOV     wp, r2
        [       Debug
        LDR     r0, =&FCFCFCFC
        LDR     r1, =TotalRAMRequired
StoreInitLoop
        DECS    r3
        STR     r0, [ wp, r3 ]
        BNE     StoreInitLoop
        B       SkipReInitStore

ReInitialisation
        LDR     r0, =&FDFDFDFD
        LDR     r1, =TotalRAMRequired
StoreReInitLoop
        DECS    r3
        STR     r0, [ wp, r3 ]
        BNE     StoreReInitLoop
SkipReInitStore
        |
ReInitialisation
        ]
        [       Debug
        DREG    wp, "Store claimed at &"
        ]
        MOV     r0, #0
        ST      r0, SWILock
        ST      r0, MessageBlockAddress                 ; Mark message file as closed

        STR     r10, HardwareAddress
        MOV     r0, #IOC
        ADD     r0, r0, #IOCFIQMSK                      ; Defaults for internal hardware
        MOV     r1, #econet_FIQ_bit
        Push    "r0, r1"
        MOV     r0, #Podule_ReadInfo_FIQMask + Podule_ReadInfo_FIQValue
        MOV     r1, sp
        MOV     r2, #2*4
        MOV     r3, r10                                 ; Something podule specific
        SWI     XPodule_ReadInfo                        ; Ignore error (pre RISC OS 3.50)
        Pull    "r0, r1"
        ST      r0, InterruptAddress
        ST      r1, InterruptMask
        [       Debug
        DREG    r0, "FIQ Interrupt mask reg is at &"
        BREG    r1, "FIQ Interrupt mask value is  &"
        ]
        [       Debug
        ADRL    r14, NetErrorList
        STR     r14, NetErrorListPointer
        MOV     r14, #-1                                ; Initialise the first record
        STR     r14, NetErrorList
        ]
        MOV     r0, #OsByte_ReadCMOS
        MOV     r1, #ProtectionCMOS
        SWI     XOS_Byte
        ; The protection stored in CMOS doesn't have values for
        ; MachinePeek and Continue.
        ; The protection bits are stored in the protection word
        ; with the bits for MachinePeek and Continue always clear
        ; So; CMOS bits [ 0..5 ] go to Protection bits [ 0..5 ]
        ;                              Protection bits [ 6, 7 ] are 0
        ;     CMOS bits [ 6, 7 ] go to Protection bits [ 8, 9 ]
        TST     r2, #BitSix                             ; GetRegs protection
        EORNE   r2, r2, #BitEight :OR: BitSix           ; Set BitEight, clear BitSix
        TST     r2, #BitSeven                           ; Protection extra bit
        EORNE   r2, r2, #BitNine :OR: BitSeven          ; Set BitNine, clear BitSeven
        STRVC   r2, Protection
        MOVVC   r0, #OsByte_ReadCMOS                    ; Read the actual station number
        MOVVC   r1, #NetStnCMOS                         ; Station number
        SWIVC   XOS_Byte
        Pull    pc, VS
        TEQ     r2, #0
        TEQNE   r2, #255
        BNE     StationNumberValid
        [       Debug
        ADRL    r1, TokenBadConfig
        |
        ADR     r1, TokenBadConfig
        ]
        BL      PrettyPrintToken
        Pull    pc, VS
        MOV     r2, #1
StationNumberValid
        ST      r2, LocalStation
        [       Debug
        DREG    r12, "Initialisation, stage 1, WP = &"
        ]
        LDR     r5, MachineVersionNumber
        MOV     r0, #2
        SWI     XOS_ReadSysInfo
        BVS     DefaultMachineType
        AND     r0, r0, #&0000FF00                      ; Check type of IO chip
        TEQ     r0, #&00000100                          ; Is it IOMD?
        ADDEQ   r5, r5, #15-7                           ; Change the machine type byte
DefaultMachineType
        ST      r5, MachinePeekData

SetTicker                                               ; Branched to at Service_Reset
        PHPSEI  r5                                      ; Must be atomic
        MOV     r1, #FIQ_Released
        ST      r1, FIQStatus
        MOV     r1, #Service_ClaimFIQ                   ; Now claim the exclusive use of FIQ
        SWI     XOS_ServiceCall                         ; away from the Kernel
        BVC     %FT10
        PLP     r5
        Pull    pc
10
    [ PerthPowerDown
        MOV     r0, #PowerDownTimeout
        ST      r0, PowerDownTime                       ; So it won't go down on me
      [ DebugPowerDown
        LDR     r0, =Border_Yellow
        ADR     r14, VIDC
        STR     r0, [ r14, #0 ]
      ]
    ]
        MOV     r0, #0
        ASSERT  FIQ_Owner = 0
        ST      r0, FIQBusy                             ; Mark as busy
        ST      r0, FIQStatus                           ; We own it
        ST      r0, Time
        ST      r0, LockOut                             ; Set no lock out state
        ST      r0, CurrentHandle                       ; Initialise 'handle manager'
        ST      r0, PeekPokeFlag
        ST      r0, EventSequenceNumber
        [       ReceiveInBackground
        ST      r0, BridgeRxHandle
        ]
        [       BroadcastByHand
        ST      r0, BroadcastTime
        ]
        MOV     r1, #NIL                                ; Means it's the end of the list
        ST      r1, RxCBList                            ; Initialise the RxCBList & the TxCBList
        ST      r1, TxCBList
        PLP     r5                                      ; Restore the interrupt state
        [       Debug
        DREG    r12, "Initialisation, stage 2, WP = &"
        ]
        MOV     r0, #TickerV
        ADRL    r1, Pacemaker                           ; The entry address
        MOV     r2, wp                                  ; The value of R12 on entry
        SWI     XOS_Claim
        MOVVC   r0, #IrqV
        ADRVCL  r1, Interrupt                           ; The entry address
        MOVVC   r2, wp                                  ; The value of R12 on entry
        SWIVC   XOS_Claim
        MOVVC   r0, #EventV
        ADRVCL  r1, Event                               ; The entry address
        MOVVC   r2, wp                                  ; The value of R12 on entry
        SWIVC   XOS_Claim
        MOVVC   r0, #OsByte_EnableEvent
        MOVVC   r1, #Event_Econet_OSProc
        SWIVC   XOS_Byte                                ; Turn on the relevant event
        Pull    pc, VS

        [       Debug
        DREG    r12, "Initialisation, stage 3, WP = &"
        ]
        MOV     r0, #2_11                               ; Initialise the Port allocation
        ADR     r2, PortTable
        STR     r0, [ r2 ], #4

        MOV     r0, #0
        MOV     r1, #0
        STMIA   r2!, { r0, r1 }
        STMIA   r2!, { r0, r1 }
        STMIA   r2!, { r0, r1 }
        STMIA   r2!, { r0, r1 }
        STMIA   r2!, { r0, r1 }
        STMIA   r2!, { r0, r1 }
        STMIA   r2!, { r0, r1 }
        MOV     r0, #2_11 :SHL: 30
        STR     r0, [ r2 ]
        MOV     r0, #Port_AllocationMinimum
        ST      r0, PortHint
        [       Debug
        DREG    r12, "Initialisation, stage 4, WP = &"
        ]
        [       ErrorInfo
        ADRL    r0, ErrorLogArea
        ADRL    r2, ErrorLogAreaEnd
InitErrorsLoop
        STR     r1, [ r0 ], #4
        TEQ     r0, r2
        BNE     InitErrorsLoop
        ]
        MOV     r0, #UKSWIV                             ; Look for SWIs whilst not linked in
        ADR     r1, MySWIRoutine
        MOV     r2, wp
        SWI     XOS_Claim
        MOVVC   r1, #Service_ReAllocatePorts
        SWIVC   XOS_ServiceCall
        MOVVC   r0, #UKSWIV
        ADRVC   r1, MySWIRoutine
        MOVVC   r2, wp
        SWIVC   XOS_Release
        Pull    pc, VS
        [       Debug
        DREG    r12, "Initialisation, stage 5, WP = &"
        ]
        BL      DoReset                                 ; Trashes R1
        [       DebugFIQ
        Push    "r0-r2"
        ADR     r0, DebugSpace
        STR     r0, [ r0, #DebugSpacePointer - DebugSpace ] !
        DREG    r0, "Debug space starts at &", cc
        MOV     r1, #0
        ADR     r2, DebugSpaceEnd
DebugInitLoop
        STR     r1, [ r0, #4 ] !
        CMP     r0, r2
        BCC     DebugInitLoop
        DREG    r2, " and ends at &"
        Pull    "r0-r2"
        ]
        [       Debug
        DREG    r12, "Initialisation, stage 6, WP = &"
        ]
        BL      FindLocalNet                            ; Doesn't return errors, preserves all
        [       Debug
        DREG    r12, "Initialisation, stage 7, WP = &"
        ]
        Pull    pc

TokenBadConfig
        DCB     "BadConf", 0
        ALIGN

MySWIRoutine                                            ; Entered when not properly linked in
        LDR     r10, =Econet_ClaimPort
        TEQ     r10, r11
        Pull    lr, EQ
        [       Debug
        BNE     %81
        BREG    r0, "ReAllocate calls ClaimPort &"
81
        ]
        BEQ     ClaimPort
        LDR     r10, =Econet_AllocatePort
        TEQ     r10, r11
        Pull    lr, EQ
        [       Debug
        BNE     %82
        DLINE   "ReAllocate calls AllocatePort"
82
        ]
        BEQ     AllocatePort
        LDR     r10, =Econet_CreateReceive
        TEQ     r10, r11
        Pull    lr, EQ
        [       Debug
        BNE     %83
        DLINE   "ReAllocate calls CreateReceive"
83
        ]
        BEQ     CreateReceive
        LDR     r10, =Econet_HardwareAddresses
        TEQ     r10, r11
        Pull    lr, EQ
        [       Debug
        BNE     %84
        DLINE   "ReAllocate calls HardwareAddresses"
84
        ]
        BEQ     HardwareAddresses
        MOV     pc, r14

        LTORG

KillModule ROUT                                         ; Ignore all errors
        Push    lr
        LDR     wp, [ r12 ]
        MOV     r0, #TickerV
        ADRL    r1, Pacemaker                           ; The entry address
        MOV     r2, wp                                  ; The value of R12 on entry to Pacemaker
        SWI     XOS_Release
        MOV     r0, #OsByte_DisableEvent
        MOV     r1, #Event_Econet_OSProc
        SWI     XOS_Byte                                ; Turn off the relevant event
        MOV     r0, #EventV
        ADRL    r1, Event                               ; The entry address
        MOV     r2, wp                                  ; The value of R12 on entry
        SWI     XOS_Release
        MOV     r0, #IrqV
        ADRL    r1, Interrupt
        MOV     r2, wp
        SWI     XOS_Release

        LD      r0, MessageBlockAddress                 ; Is it open?
        MOV     r1, #0
        ST      r1, MessageBlockAddress                 ; Mark it as closed
        TEQ     r0, #0
        SWINE   XMessageTrans_CloseFile                 ; Close it if it was open

      [ standalone
        ADRL    r0, ResourceFiles
        SWI     XResourceFS_DeregisterFiles
      ]

        LD      r1, FIQStatus
        TEQ     r1, #FIQ_Owner                          ; Do we own FIQ?
        MOVEQ   r0, #1                                  ; Not able to do SWIs to myself no more
        MOVEQ   r1, #Service_ClaimFIQ                   ; Claim FIQ away if we own it
        BLEQ    ServiceBodge
TrashAllCBs                                             ; JMP'd to, expects LR at [ SP ]
        MOV     r1, #Service_EconetDying
        SWI     XOS_ServiceCall
        ADR     r2, TxCBList - Offset_Link
        LDR     r2, [ r2, #Offset_Link ]
TxDieLoop                                               ; DeAllocate all TxCBS
        TEQ     r2, #NIL
        BEQ     RxDie
        LDR     r3, [ r2, #Offset_Link ]
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        BVS     RxDie                                   ; Any errors cause us to stop
        MOV     r2, r3
        B       TxDieLoop

RxDie
        ADR     r2, RxCBList - Offset_Link
        LDR     r2, [ r2, #Offset_Link ]
RxDieLoop                                               ; DeAllocate all RxCBS
        TEQ     r2, #NIL
        BEQ     KillComplete
        LDR     r3, [ r2, #Offset_Link ]
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        BVS     KillComplete                            ; Any errors cause us to stop
        MOV     r2, r3
        B       RxDieLoop

KillComplete
        CLRV
        Pull    pc

ServiceTable
        DCD     0                                       ; Flags
        DCD     ServiceDecoder - Origin                 ; Handler

        ASSERT  Service_ClaimFIQ > Service_ReleaseFIQ   
        ASSERT  Service_Reset > Service_ClaimFIQ
        ASSERT  Service_ClaimFIQinBackground > Service_Reset 
        ASSERT  Service_ResourceFSStarting > Service_ClaimFIQinBackground
        ASSERT  Service_Portable > Service_ResourceFSStarting
        DCD     Service_ReleaseFIQ                      ; List of services
        DCD     Service_ClaimFIQ
        DCD     Service_Reset
        DCD     Service_ClaimFIQinBackground
      [ standalone
        DCD     Service_ResourceFSStarting
      ]
        DCD     Service_Portable
        DCD     0

        DCD     ServiceTable - Origin                   ; Anchor
Service ROUT
        MOV     r0, r0                                  ; Fast service table prsent
        TEQ     r1, #Service_ClaimFIQ
        TEQNE   r1, #Service_ReleaseFIQ
        TEQNE   r1, #Service_ClaimFIQinBackground
        TEQNE   r1, #Service_Reset
        TEQNE   r1, #Service_Portable
      [ standalone
        TEQNE   r1, #Service_ResourceFSStarting
      ]
        MOVNE   pc, lr
ServiceDecoder
        LDR     wp, [ r12 ]
ServiceBodge
        Push    lr
        [       {FALSE} ;Debug
        BREG    r1, "Service_&", cc
        DREG    r0, " R0 = &", cc
        DREG    r2, " R2 = &", cc
        DREG    r3, " R3 = &", cc
        DREG    r4, " R4 = &"
        ]
        TEQ     r1, #Service_ClaimFIQ
        BEQ     ClaimFIQ
        TEQ     r1, #Service_ReleaseFIQ
        BEQ     ReleaseFIQ
        TEQ     r1, #Service_ClaimFIQinBackground
        BEQ     BackgroundClaimFIQ
        TEQ     r1, #Service_Portable
        BEQ     PowerUpOrDown
      [ standalone
        TEQ     r1, #Service_ResourceFSStarting
        BEQ     ReRegisterResources
      ]
ServiceReset                                            ; Note the fall through
        Push    "r0-r6"
        MOV     r0, #0                                  ; Clear SWI lock on reset
        ST      r0, SWILock
        MOV     r0, #OsByte_RW_LastResetType            ; Now check reset was NOT hard
        MOV     r1, #0
        MOV     r2, #255
        SWI     XOS_Byte                                ; Read last reset type
        BVS     ExitReset                               ; Only do reset when it was soft
        CMP     r1, #0
        BNE     ExitReset                               ; Nowt to do, not a soft reset
        [       Debug
        DLINE   "Actually doing Service_Reset"
        ]
        Push r3
        JumpAddress lr, ReturnFromTrashCBs, Forward
        Push    lr
        B       TrashAllCBs                             ; Returns with Pull PC
ReturnFromTrashCBs
        Pull    r3
        JumpAddress lr, ExitReset, Forward
        Push    lr
        B       SetTicker                               ; Returns with Pull PC
ExitReset
        Pull    "r0-r6, pc"

    [ PerthPowerDown
PowerUpOrDown   ROUT
        TST     r3, #PortableControl_EconetEnable       ; Is this for our hardware?
        Pull    pc, EQ                                  ; No so return ASAP
        TEQ     r2, #ServicePortable_PowerUp
        BEQ     DoPowerUpSequence
        TEQ     r2, #ServicePortable_PowerDown
        BEQ     DoPowerDownSequence
        Pull    pc

DoPowerUpSequence
      [ Debug
        DLINE   "Power up"
      ]
      [ {TRUE}
        Push    "r0"                                    ; Delay to ensure the hardware is alive
        MOV     r0, #OsByte_Wait
        SWI     XOS_Byte
        MOV     r0, #OsByte_Wait
        SWI     XOS_Byte
        Pull    "r0"
      ]
        PHPSEI  r2                                      ; Must be atomic
        MOV     r14, #FIQ_Released
        ST      r14, FIQStatus
        MOV     r1, #Service_ClaimFIQ                   ; Back from the kernel
        SWI     XOS_ServiceCall                         ; Ignore errors
      [ Debug
        DREG    r1, "Service_ClaimFIQ (from kernel) returns &"
      ]
        MOV     r14, #FIQ_Owner
        ST      r14, FIQStatus                          ; We own FIQ
        BL      DoReset                                 ; Trashes R1
        PLP     r2
        MOV     r2, #ServicePortable_PowerUp
        B       ExitChangePower

DoPowerDownSequence
        LD      r14, FIQStatus
        TEQ     r14, #FIQ_Owner
        BNE     ExitDoPowerDown                         ; Nothing to do if not FIQ owner
      [ Debug
        DLINE   "Power down, we own FIQ"
      ]
        BL      ClaimFIQBodge                           ; Trashes R1
        MOV     r1, #FIQ_PoweredDown
        ST      r1, FIQStatus
        MOV     r1, #Service_ReleaseFIQ                 ; Back to the kernel
        SWI     XOS_ServiceCall                         ; Ignore errors
      [ Debug
        DREG    r1, "Service_ReleaseFIQ (to kernel) returns &"
      ]
ExitDoPowerDown
        MOV     r1, #FIQ_PoweredDown
        ST      r1, FIQStatus
        MOV     r2, #ServicePortable_PowerDown
ExitChangePower
        MOV     r1, #Service_Portable
      [ {FALSE} ; Debug
        BREG    r1, "Exit Service_&", cc
        DREG    r0, " R0 = &", cc
        DREG    r2, " R2 = &", cc
        DREG    r3, " R3 = &", cc
        DREG    r4, " R4 = &"
      ]
        Pull    "pc"
    | ; PerthPowerDown
PowerUpOrDown   ROUT
        TST     r3, #PortableControl_EconetEnable       ; Is this for our hardware?
        Pull    pc, EQ                                  ; No so return ASAP
        TEQ     r2, #ServicePortable_PowerDown          ; Is someone trying to power us down?
        BICEQS  r3, r3, #PortableControl_EconetEnable   ; Yes, so don't allow it
        MOVEQ   r1, #Service_Serviced                   ; And if there are no more bits set
        Pull    pc                                      ; Then claim the service to save time
    ]

      [ standalone
ReRegisterResources ROUT
        Push    "r0"
        ADRL    r0, ResourceFiles
        MOV     lr, pc                                  ; LR -> return address
        MOV     pc, r2                                  ; R2 -> address to call
        Pull    "r0,pc"
      ]

ReleaseFIQ      ROUT
        LD      r14, FIQStatus
        TEQ     r14, #FIQ_Released
        TEQNE   r14, #FIQ_Owner
        [       Debug
        BEQ     %06
        BREG    r14, "Service_ReleaseFIQ not accepted; FIQStatus = &"
        ]
        Pull    "pc", NE                                ; Nothing to do
        [       Debug
06
        DLINE   "Service_ReleaseFIQ accepted; FIQ taken from releasor"
        ]
        Push    "r0"
        MOV     r14, #FIQ_Owner
        ST      r14, FIQStatus                          ; We own FIQ
        BL      DoReset                                 ; Trashes R1
        B       ExitServiced

ClaimFIQBodge                                           ; Called with BL
        Push    lr
ClaimFIQ
        LD      r14, FIQStatus
        TEQ     r14, #FIQ_Owner
        [       Debug
        BEQ     %07
        BREG    r14, "Service_ClaimFIQ not accepted; FIQStatus = &"
        ]
        Pull    "pc", NE                                ; Nothing to do
        [       Debug
07
        DLINE   "Service_ClaimFIQ accepted; FIQ released to claimant"
        ]
        Push    "r0"
TryForNotBusy
        CLRPSR  F_bit, r1
WaitForNotBusy
        LD      r1, FIQBusy
        TEQ     r1, #0
        BNE     WaitForNotBusy
        SETPSR  F_bit, r1
        LD      r1, FIQBusy
        TEQ     r1, #0
        BNE     TryForNotBusy
DoClaimFIQ                                              ; Expects R0, LR on the stack
        MOV     r14, #FIQ_Released
        ST      r14, FIQStatus                          ; Show that we have released to the claimant
        LDR     r1, HardwareAddress
        MOV     r0, #2_11000000                         ; TxReset, RxReset
        STRB    r0, [ r1, #:INDEX: CReg1 ]
        LD      r0, InterruptAddress
        LD      r1, InterruptMask
        LDRB    r14, [ r0, #0 ]                         ; FIQ Mask register
        BIC     r14, r14, r1
        STRB    r14, [ r0, #0 ]
ExitServiced
        MOV     r1, #Service_Serviced
        Pull    "r0, pc"

BackgroundClaimFIQ
        LD      r14, FIQStatus                          ; Check that we do own FIQ
        TEQ     r14, #FIQ_Owner
        LD      r14, SWILock, EQ                        ; See if we are executing a SWI
        TEQEQ   r14, #0
        MOVEQ   r14, #IOC
        LDREQB  r14, [ r14, #IOCIRQREQA ]               ; IRQ Request register
        TSTEQ   r14, #force_bit                         ; If FIQ downgrade pending do not release FIQ
        Pull    "pc", NE
        Push    "r0"
        LD      r14, FIQBusy
        TEQ     r14, #0                                 ; Is it busy?
        BNE     BackgroundClaimFails                    ; Yes
        SETPSR  F_bit, r14                              ; Disable FIQ
        LD      r14, FIQBusy
        TEQ     r14, #0                                 ; Is it still not busy?
        BEQ     DoClaimFIQ                              ; Yes
        CLRPSR  F_bit, r14                              ; Re-enable FIQ because something has just started
BackgroundClaimFails
        MOV     r1, #Service_ClaimFIQinBackground
        Pull    "r0, pc"

DoReset ROUT                                            ; Install the FIQ code
      [ :LNOT: No32bitCode
        Push    "r2, lr"
        BL      InstallFIQHandler                       ; Trashes r1 & r2
        Pull    "r2, pc"

InstallFIQHandler ROUT
      ]
        ADR     r1, ModuleWorkspace                     ; Stored where FIQ code can find it
        STR     wp, [ r1 ]
        MOV     r1, lr                                  ; The return address, for RTFIQ (from SVC 'lr')
      [ :LNOT: No32bitCode
        MRS     r2, CPSR
      ]
        WritePSRc I_bit+F_bit+FIQ_mode, lr              ; Set FIQ flag and goto FIQ mode
        ADD     lr, r1, #4                              ; The return address, for RTFIQ (to FIQ 'lr')
      [ :LNOT: No32bitCode
        MSR     SPSR_cxsf, r2                           ; The return PSR, for RTFIQ
      ]
        ADR     r12, ModuleWorkspace
        LDR     r12, [ r12 ]                            ; FIQ_R12 points to Econet's workspace
        LDR     r10, HardwareAddress                    ; Initialise FIQ_R10
        [       Debug
        MOV     r13, #&F0                               ; A bodge stack
        DREG    r10, "H/W = &"
        ]
        MOV     r13, #NIL
        STR     r13, Record
        MOV     r13, #2_11000000                        ; TxReset, RxReset, AC=0
        STRB    r13, CReg1

        LD      r10, InterruptAddress
        LD      r11, InterruptMask
        [       Debug
        MOV     r13, #&F0                               ; A bodge stack
        DREG    r10, "FIQ reg = &"
        BREG    r11, "FIQ msk is = &"
        ]
        LDRB    r13, [ r10, #0 ]                        ; Now allow ADLC interrupts to actually give FIQs
        ORR     r11, r13, r11
        STRB    r11, [ r10, #0 ]                        ; FIQ Mask register
        [       Debug
        MOV     r13, #&F0                               ; A bodge stack
        BREG    r11, "Msk reg now = &"
        ]
ReInit  ; Violently re-initialise things, take no chances
        ; Note that this and the next entry point are
        ; also used as an exit from FIQ code after an
        ; error so it has to EXIT with RTFIQ
        ADR     r12, ModuleWorkspace
        LDR     r12, [ r12 ]                            ; FIQ_R12 points to Econet's workspace
        LDR     r10, HardwareAddress                    ; Initialise FIQ_R10

        MOV     r13, #2_11000001                        ; TxReset, RxReset, AC=1
        ST      r13, CReg1
        MOV     r13, #2_00011110                        ; NRZ, Rx8bits, Tx8bits
        ST      r13, CReg4
        MOV     r13, #2_00000000                        ; DTR, NONLOOP
        ST      r13, CReg3
Reset   ; Resets the world to the normal quiescent state
        [       Analyser
        MOV     r13, #2_10000011                        ; TxReset, RxIE, AC=1
        ST      r13, CReg1
        MOV     r13, #2_00000000                        ; -DTR, NONLOOP
        ST      r13, CReg3
        [       DebugFIQ
        LDR     r13, =Border_Grey
        ADR     r10, VIDC
        STR     r13, [ r10, #0 ]
        ]
        ]
        ADR     r12, ModuleWorkspace
        LDR     r12, [ r12 ]                            ; FIQ_R12 points to Econet's workspace
        LDR     r10, HardwareAddress                    ; Initialise FIQ_R10

        MOV     r13, #2_10000010                        ; TxReset, RxIE, AC=0
        ST      r13, CReg1
        MOV     r13, #2_01100111                        ; ClrTxStatus, ClrRxStatus, FlagIdle, 2Byte, PSE
        ST      r13, CReg2
        LD      r13, SReg2                              ; Ensure that we keep Status2 up-to-date
        ST      r13, Status2
Ready                                                   ; Restores FIQ_R10 and FIQ_R12
        ADR     r12, ModuleWorkspace
        LDR     r12, [ r12 ]                            ; FIQ_R12 points to Econet's workspace
        MOV     r13, #0
        ST      r13, FIQBusy                            ; Show that FIQ is not busy, by storing a zero
        SetFIQ  StartReception, r8, r9, Long, Init, r10 ; Inits the LDR pc, .+4 instruction as well
        LDR     r10, HardwareAddress                    ; Initialise FIQ_R10
        RTFIQ                                           ; Now wait patiently

FindLocalNet    ROUT
        Push    "r0-r11, lr"                            
        WritePSRc I_bit+SVC_mode, lr,, r0               ; Enable all interrupts (SVC mode assumed)
        Push    "r0"                                    ; Save the interrupt state psr/lr on the stack too

        MOV     r8, #0                                  ; Initialise the two handles to empty
        MOV     r9, #0

        MOV     r0, #Port_Bridge
        MOV     r1, #0                                  ; Any
        MOV     r2, #0                                  ; Any
        ADR     r3, LocalNetwork
        MOV     r4, #2                                  ; Local net and version numbers
        ST      r1, LocalNetwork                        ; Initialise to the state of a lonely net
        [       ReceiveInBackground
        ST      r1, BridgeRxHandle                      ; Initialise handle
        ]
        BL      CreateReceive                           ; Use internal routines directly
        [       DebugFindLocalNet
        BVS     ExitLocalNet
        DREG    r0, "Rx handle = &"
        ]
        [       ReceiveInBackground
        ST      r0, BridgeRxHandle, VC
        |
        MOVVC   r8, r0                                  ; Save the handle
        ]
        [       BroadcastByHand                         ; Do broadcast by hand
        [       DebugFindLocalNet
        LDR     r0, =Border_Black
        ADR     r1, VIDC
        STR     r0, [ r1, #0 ]
        ]
        BVS     ExitLocalNet

        MOV     r1, #Service_ClaimFIQ                   ; Claim FIQ away if we own it
        BL      ServiceBodge
        [       DebugFindLocalNet
        DLINE   "FIQ Claimed"
        ]
        ASSERT  InterruptAddress = HardwareAddress + 4
        ASSERT  InterruptMask = HardwareAddress + 8
        ADR     r7, HardwareAddress
        LDMIA   r7, { r7, r8, r9 }
        MOV     r10, r7
        MOV     r11, #IOC
        LDRB    r14, [ r8, #0 ]                         ; FIQ Mask register
        BIC     r14, r14, r9                            ; Disable FIQ from the ADLC
        STRB    r14, [ r8, #0 ]                         ; FIQ Mask register
        ADD     r8, r8, #IOCFIQSTA - IOCFIQMSK          ; Now point at the Status register
        [       DebugFindLocalNet
        DREG    r11, "IOC is at &"
        DREG    r10, "ADLC is at &"
        DREG    r8, "FIQ Status register is at &", cc
        BREG    r9, " and the mask value is &"
        ]

        ;       R0  = Data byte
        ;       R1  = Status register 1
        ;       R2  = Status register 2
        ;       R3  = Control values
        ;       R4  = Timer0 start value
        ;       R5  = Timer0 recent value (will be less than R4)
        ;       R6  = Pointer to byte to broadcast
        ;       R7  = Number of bytes remaining to broadcast
        ;       R8  = Address of FIQ Status register
        ;       R9  = Mask for FIQ Status register
        ;       R10 = Address of ADLC
        ;       R11 = Address of IOC/IOMD

        MOV     r3, #2_10000010                         ; TxReset, RxIE, AC=0
        ST      r3, CReg1
        MOV     r3, #2_01100111                         ; ClrTxStatus, ClrRxStatus, FlagIdle, 2Byte, PSE
        ST      r3, CReg2
        LD      r2, SReg2                               ; Ensure that we keep Status2 up-to-date
        ST      r2, Status2
        TST     r2, #DCD
        BEQ     BroadcastHasClock
        [       DebugFindLocalNet
        DLINE   "Broadcast for bridge detects no clock"
        BREG    r2, "Status register 2 is &"
        ]
BroadcastFails
        LD      r0, BridgeRxHandle
        MOV     r14, #0
        ST      r14, BridgeRxHandle
        BL      AbandonAndReadReceive
        B       ExitLocalNet

BroadcastHasClock
        STRB    r14, [ r11, #Timer0LR ]                 ; Latch the timer
        LDRB    r14, [ r11, #Timer0CH ]
        LDRB    r4, [ r11, #Timer0CL ]
        ORR     r4, r4, r14, LSL #8                     ; Now a single 16 bit value
        [       DebugFindLocalNet
        ST      r4, InitTimer0
        MOV     r0, #0
        ]
        MOV     r5, r4
WaitForLineAccess
        LD      r2, SReg2                               ; Note R10 is always the address of the ADLC
        TST     r2, #RxIdle                             ; Now the line access stuff
        BEQ     BroadcastNoLineAccess                   ; Line not idle
        TST     r2, #RxAbort
        BEQ     BroadcastLineAccess
BroadcastNoLineAccess
        BL      GetTimerValue                           ; Returns ticks in R0
        CMP     r0, #400                                ; 200 micro-seconds
        BLT     WaitForLineAccess
        [       DebugFindLocalNet
        DLINE   "Broadcast for bridge detects no line access"
        BREG    r2, "Status register 2 is &"
        ]

        ;       *************
        B       BroadcastFails

BroadcastLineAccess
        [       {FALSE} ; DebugFindLocalNet
        DREG    r0, "Line access took &", cc
        DLINE   " ticks."
        ]
        MOV     r4, r5                                  ; Throw that time away
        MOV     r3, #2_11100111                         ; RTS, CLRTxST, CLRRxST, FlagIdle, 2Byte, PSE
        ST      r3, CReg2
        MOV     r3, #2_01000100                         ; RxRS, TxIE
        ST      r3, CReg1
        [       DebugFindLocalNet
        ADRL    r6, BridgeData
        |
        ADR     r6, BridgeData
        ]
        MOV     r7, #BridgeDataSize
WaitForFirstInterrupt
        BL      GetTimerValue                           ; Returns ticks in R0
        LDRB    r1, [ r8, #0 ]                          ; Is there an interrupt?
        TST     r1, r9                                  ; From the ADLC?
        BNE     InterruptOK
        CMP     r0, #60                                 ; 30 micro-seconds
        BLT     WaitForFirstInterrupt
        [       DebugFindLocalNet
        BREG    r1, "No Interrupt: last Status read was &"
        LD      r3, InitTimer0
        DREG    r3, "Initial value of Timer0 was &"
        DREG    r4, "R4 = &"
        DREG    r5, "Timer0 is now &"
        DREG    r0, "Ticks = &"
        ]
        ;       ***********************
        ; Error return with Interrupt failure
        B       BroadcastFails

InterruptOK
        [       {FALSE} ; DebugFindLocalNet
        DREG    r0, "First interrupt took &", cc
        DLINE   " ticks."
        DREG    r5, "Timer0 is now &"
        ]
        LD      r1, SReg1
        TSTS    r1, #TxDRA                              ; TDRA OK ?
        BEQ     BroadcastNetError
        LDRB    r0, [ r6 ], #1
        TEQ     r0, #254                                ; Special value?
        LD      r0, LocalStation, EQ
        ST      r0, TxByte
        DECS    r7
        BEQ     BroadcastFinished
WaitForNextInterrupt
        LDRB    r14, [ r8, #0 ]                         ; Is there an interrupt?
        TST     r14, r9
        BNE     InterruptOK
        BL      GetTimerValue                           ; Returns ticks in R0
        CMP     r0, #6016                               ; 3 milli-seconds
        BLT     WaitForNextInterrupt
        B       InterruptTookTooLong

BroadcastNetError
        [       DebugFindLocalNet
        BREG    r1, "Status register 1 = &"
        LDR     r0, =Border_Blue
        ADR     r1, VIDC
        STR     r0, [ r1, #0 ]
        ]
        B       BroadcastFails

GetTimerValue
        ;       R4 ==> Start value of Timer0
        ;       R5 ==> Most recent value of Timer0
        ;       R0 <== Number of ticks since Start value
        ;       R3 Trashed
        ;       R4 <== Updated if Timer0 wrapped
        ;       R5 <== This value of Timer0
        STRB    r0, [ r11, #Timer0LR ]                  ; Latch the timer
        LDRB    r0, [ r11, #Timer0CH ]
        LDRB    r3, [ r11, #Timer0CL ]
        ORR     r3, r3, r0, LSL #8                      ; Now a single 16 bit value
        CMP     r3, r5                                  ; Current and previous
        ADDGT   r4, r4, r3                              ; Account for the clocking of Timer0
        MOV     r5, r3                                  ; Update most recent value into R5
        [       DebugFindLocalNet
        LDRGT   r0, =Border_Lime
        ADRGT   r3, VIDC
        STRGT   r0, [ r3, #0 ]
        ]
        SUB     r0, r4, r5                              ; How many ticks there have been now
        MOV     pc, lr

BroadcastFinished
        LDR     r1, =2_00111111                         ; -RTS, ClrRxST, TxLast, FC, FlagIdle, 2Byte, PSE
        ST      r1, CReg2
WaitForFinalInterrupt
        LDRB    r14, [ r8, #0 ]                          ; Is there an interrupt?
        TST     r14, r9
        BNE     FinalInterrupt
        BL      GetTimerValue                           ; Returns ticks in R0
        CMP     r0, #6016                               ; 3 milli-seconds
        BLT     WaitForFinalInterrupt
InterruptTookTooLong
        [       DebugFindLocalNet
        DLINE   "Interrupt took too long"
        LD      r3, InitTimer0
        DREG    r3, "Initial value of Timer0 was &"
        DREG    r4, "R4 = &"
        DREG    r5, "Timer0 is now &"
        DREG    r0, "Ticks = &"
        LDR     r0, =Border_Yellow
        ADR     r1, VIDC
        STR     r0, [ r1, #0 ]
        ]
        B       BroadcastFails

FinalInterrupt
        LD      r1, SReg1
        TSTS    r1, #FrameComplete
        BEQ     BroadcastNetError
        MOV     r1, #37                                 ; Magic value determined emperically
        DivRem  r2, r0, r1, r14
        INC     r2
        MOV     r2, r2, ASR #1
        ST      r2, BroadcastTime                       ; In quarters of a micro second
        [       {FALSE} ; DebugFindLocalNet
        DLINE   "Final interrupt OK"
        LD      r3, InitTimer0
        DREG    r3, "Initial value of Timer0 was &"
        DREG    r4, "R4 = &"
        DREG    r5, "Final value of Timer0 is now &"
        SUB     r1, r4, r5
        DREG    r1, "Ticks = &"
        DLINE   "Econet Clock frequency = ", cc
        MOV     r1, #4000
        DivRem  r0, r1, r2, r14
        ADR     r1, SmallTextBuffer
        MOV     r2, #?SmallTextBuffer
        SWI     OS_ConvertCardinal2
        SWI     OS_Write0
        DLINE   " KHz."
        ]
        |       ; BroadcastByHand
        MOVVC   r0, #2                                  ; Command code for "determine local net number"
        MOVVC   r1, #Port_Bridge
        MOVVC   r2, #255
        MOVVC   r3, #255
        ADRVC   r4, BridgeData
        MOVVC   r5, #BridgeDataSize
        MOVVC   r6, #5
        MOVVC   r7, #5
        BLVC    StartTransmit                           ; Use internal routines directly
        BVS     ExitLocalNet
        MOV     r9, r0                                  ; Save the handle
        [       DebugFindLocalNet
        DREG    r9, "Tx handle = &"
        ]
WaitForLocalNetTx
        MOV     r0, r9
        BL      PollTransmit                            ; Use internal routines directly
        BVS     ExitLocalNet
        TEQ     r0, #Status_TxReady
        TEQNE   r0, #Status_Transmitting
        [       DebugFindLocalNet
        BREG    r0, "Transmit Status is &"
        ]
        BEQ     WaitForLocalNetTx
        [       DebugFindLocalNet
        DREG    r0, "Tx finishes, status = &"
        ]
        ]       ; BroadcastByHand
        [       ReceiveInBackground
ExitLocalNet
        [       BroadcastByHand
        MOV     r1, #Service_ReleaseFIQ                 ; Restore  normal working
        BL      ServiceBodge
        [       DebugFindLocalNet
        DLINE   "FIQ Released"
        ]
        ]
        Pull    "r0"
        RestPSR r0
        Pull    "r0-r11, pc"                            ; Restore interrupt state
        |       ; ReceiveInBackground
WaitForLocalRx
        MOV     r0, r8
        [       DebugFindLocalNet
        DREG    r0, "ExamineReceive of &", cc
        ]
        BL      ExamineReceive                          ; Use internal routines directly
        BVS     ExitLocalNet
        [       DebugFindLocalNet
        DREG    r0, " returns &"
        Push    "r0-r2"
        MOV     r0, #OsByte_Wait
        SWI     XOS_Byte
        Pull    "r0-r2"
        ]
        TEQ     r0, #Status_Received
        BEQ     ExitLocalNet
        LD      r0, Time
        [       DebugFindLocalNet
        CMP     r0, #20
        |
        CMP     r0, #200                                ; Wait only two seconds at the most
        ]
        BLT     WaitForLocalRx
        [       DebugFindLocalNet
        DLINE   "Rx times out"
        ]
ExitLocalNet
        MOVS    r0, r8                                  ; Test the receive handle
        BLNE    AbandonAndReadReceive                   ; Use internal routines directly
        ]       ; ReceiveInBackground
        [       :LNOT: BroadcastByHand
        MOVS    r0, r9                                  ; Same for the transmit handle
        BLNE    AbandonTransmit                         ; Use internal routines directly
        Pull    "r0"
        RestPSR r0
        Pull    "r0-r11, pc"                            ; Restore interrupt state
        ]       ; BroadcastByHand

BridgeData
        [       BroadcastByHand
        DCB     255, 255                                ; Broadcast
        DCB     254                                     ; Special, means local station here
        DCB     0                                       ; Local net
        DCB     &82                                     ; Bridge command
        DCB     Port_Bridge                             ; Transmit port
        ]
        DCB     "Bridge"                                ; Identifier
        DCB     Port_Bridge                             ; Reply port
        DCB     0                                       ; Filler
BridgeDataSize  *       . - BridgeData

        LTORG

PrintBanner     ROUT
        Push    "r1, lr"
        LD      r1, Status2
        TST     r1, #DCD                                ; Test the NoClock bit
        ADREQ   r1, Token_Banner
        ADRNE   r1, Token_BannerNoClock
        BL      PrettyPrintToken
        Pull    "r1, pc"

Token_Banner
        DCB     "AcrnEco", 0
Token_BannerNoClock
        DCB     "EcoNClk", 0
        ALIGN

PrettyPrintFrame     *       100

PrettyPrintToken
        Push    "r0-r4, lr"
        DEC     sp, PrettyPrintFrame                    ; Put the string into the stack
        MOV     r2, sp
        MOV     r3, #PrettyPrintFrame - 1
        MOV     r4, #0                                  ; No parameters
        BL      MessageTransGSLookup
        MOVVC   r0, r2                                  ; The passed buffer
        MOV     r1, r3                                  ; Length of the resultant string
        SWIVC   XOS_PrettyPrint
        INC     sp, PrettyPrintFrame                    ; Clear the message away
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r4, pc"

MakeError       ROUT
        Push    "r1-r4, lr"
        MOV     r4, #0
DoMakeError1
        MOV     r2, #0                                  ; Make MessageTrans give me the space
        MOV     r3, #0
        BL      MessageTransErrorLookup
        Pull    "r1-r4, pc"

MakeErrorWithModuleName
        Push    "r1-r4, lr"
        ADRL    r4, ModuleTitle
        B       DoMakeError1

MessageTransGSLookup
        Push    "r5, lr"
        BL      MessageTransGSLookup2
        Pull    "r5, pc"

MessageTransGSLookup2
        Push    "r6, r7, lr"
        LD      r0, MessageBlockAddress
        CMP     r0, #0                                  ; Clears V
        BNE     DoGSLookup
        Push    "r1, r2"
        ADR     r0, MessageBlock
        ADR     r1, MessageFileName
        MOV     r2, #0                                  ; Use the file where she lies
        SWI     XMessageTrans_OpenFile
        ADRVC   r0, MessageBlock
        STRVC   r0, MessageBlockAddress
        Pull    "r1, r2"
DoGSLookup
        MOV     r6, #0
        MOV     r7, #0
        SWIVC   XMessageTrans_GSLookup
        Pull    "r6, r7, pc"

MessageTransErrorLookup
        Push    "r5, r6, r7, lr"
        LD      r1, MessageBlockAddress
        CMP     r1, #0                                  ; Clears V
        BNE     DoErrorLookup
        Push    "r0, r2"
        ADR     r0, MessageBlock
        ADR     r1, MessageFileName
        MOV     r2, #0                                  ; Use the file where she lies
        SWI     XMessageTrans_OpenFile
        ADRVC   r1, MessageBlock
        STRVC   r1, MessageBlockAddress
        Pull    "r0, r2"                                ; Preserve R0 even in the error case
DoErrorLookup
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWIVC   XMessageTrans_ErrorLookup
        Pull    "r5, r6, r7, pc"

MessageFileName
        DCB     "Resources:$.Resources.Econet.Messages", 0
        ALIGN

      [ standalone
ResourceFiles
        ResourceFile $MergedMsgs, Resources.Econet.Messages
        DCD     0
      ]
        LTORG

        GET     Interface.s
        GET     Commands.s
        GET     Receive.s
        GET     Transmit.s
        GET     Background.s

        [       :LNOT: ReleaseVersion
        InsertDebugRoutines
        ]

        END
