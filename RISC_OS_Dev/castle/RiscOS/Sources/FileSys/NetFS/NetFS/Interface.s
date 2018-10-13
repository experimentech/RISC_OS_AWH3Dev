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
        SUBT ==> &.Arthur.NetFS.Interface
        OPT     OptPage

SWIEntry        ROUT
        Push    lr
        BL      SWIEntry32
        TEQ     pc,pc
        Pull    pc,EQ
        Pull    pc,VC,^
        Pull    lr
        ORRS    pc,lr,#VFlag

SWIEntry32      ROUT
        LDR     wp, [ r12 ]
        CMP     r11, #( EndOfJumpTable - JumpTable ) / 4
        ADDCC   pc, pc, r11, LSL #2
        B       SWIOutOfRange

JumpTable
        B       ReadFileServer                          ; &40040
        B       SetFileServer                           ; &40041
        B       ReadFileServerName                      ; &40042
        B       SetFileServerName                       ; &40043
        MOV     pc, lr                                  ; &40044
        MOV     pc, lr                                  ; &40045
        B       ReadFSRetryDelay                        ; &40046
        B       SetFSRetryDelay                         ; &40047
        B       DoFileServerOp                          ; &40048
        B       EnumerateFSCache                        ; &40049
        B       EnumerateFSList                         ; &4004A
        B       ConvertDateForUser                      ; &4004B
        B       DoFSOpToGivenFS                         ; &4004C
        B       UpdateFSList                            ; &4004D
        B       EnumerateFSContexts                     ; &4004E
        B       ReadUserId                              ; &4004F
        B       GetObjectUID                            ; &40050
        B       EnableCache                             ; &40051
EndOfJumpTable

SWIOutOfRange
        ADR     r0, ErrorNoSuchSWI
        [ UseMsgTrans
        B       MakeErrorWithModuleName
        |
        RETURNVS
        ]       ; UseMsgTrans

        [       UseMsgTrans
ErrorNoSuchSWI
        DCD     ErrorNumber_NoSuchSWI
        DCB     "BadSWI", 0
        ALIGN
        |
        Err     NoSuchSWI
        ALIGN
        ]       ; UseMsgTrans

SWINameTable
        DCB     "NetFS", 0
        DCB     "ReadFSNumber", 0
        DCB     "SetFSNumber", 0
        DCB     "ReadFSName", 0
        DCB     "SetFSName", 0
        DCB     "4", 0
        DCB     "5", 0
        DCB     "ReadFSTimeouts", 0
        DCB     "SetFSTimeouts", 0
        DCB     "DoFSOp", 0
        DCB     "EnumerateFSList", 0
        DCB     "EnumerateFS", 0
        DCB     "ConvertDate", 0
        DCB     "DoFSOpToGivenFS", 0
        DCB     "UpdateFSList", 0
        DCB     "EnumerateFSContexts",0
        DCB     "ReadUserId",0
        DCB     "GetObjectUID", 0
        DCB     "EnableCache", 0
        DCB     0
        ALIGN

ReadFileServer  ROUT
        LDR     r10, Current
        TEQ     r10, #0
        MOVEQ   r0, #0
        LDRNEB  r0, [ r10, #Context_Station ]
        MOVEQ   r1, #0
        LDRNEB  r1, [ r10, #Context_Network ]
        MOV     pc, lr

SetFileServer   ROUT
        Push    lr
        [       Debug
        BREG    r1, "Validate &", cc
        BREG    r0, ".&"
        ]
        BL      ValidateFSNumber
        Pull    pc, VS                                  ; Exit
        [       Debug
        BREG    r1, "Returns &", cc
        BREG    r0, ".&"
        ]
        Push    "r0, r1, r3, r4"                        ; Save two extra registers
        Pull    "r3, r4"                                ; Get the validated and translated value in R4.R3
        BL      FindNumberedContext
        [       OldOs
        STRVC   r0, Current
        |
        BLVC    EnforceContext
        ]
        Pull    "r3, r4, pc", VC
        [       Debug
        ADD     r14, r0, #4
        DSTRING r14, "FindNumberedContext returns an error: "
        ]
        BL      CreateNumberedContext
        [       OldOs
        STRVC   r0, Current
        |
        BLVC    EnforceContext
        ]
        Pull    "r3, r4, pc"

ReadFileServerName ROUT
        TEQ     r2, #0
        BEQ     %30                                     ; No buffer!
        Push    lr
        MOV     r0, r1                                  ; Set up entry for validation and general exit condition
        ADD     r1, r1, r2
        BL      ValidateWriteAddress
        Pull    pc, VS
        MOV     r1, r0
        LDR     r10, Current
        TEQ     r10, #0
        STREQB  r14, [ r1 ]                             ; No context, so write a null name
        Pull    pc, EQ
        LDR     r14, [ r10, #Context_Identifier ]
        LDR     r12, =ContextIdentifier
        TEQ     r12, r14
        ADRNEL  r0, ErrorNetFSInternalError
        SETV    NE
        [       UseMsgTrans
        Pull    lr, VS
        BVS     MakeError
        |
        Pull    pc, VS
        ]
        LDR     r14, [ r10, #Context_RootDirectory ]
        TEQ     r14, #0                                 ; Are we currently logged on??
        STREQB  r14, [ r1 ]                             ; No, so write a null name
        Pull    pc, EQ
        ADD     r14, r10, #Context_DiscName
10
        LDRB    r12, [ r14 ], #1                        ; Get byte of name or terminator
        DECS    r2                                      ; Less space left in buffer
        BMI     %20                                     ; Have we run out of space
        CMP     r12, #" "                               ; Is this the terminator
        MOVLE   r12, #0                                 ; Set the required terminator
        STRB    r12, [ r1 ], #1                         ; Store in the user's buffer
        BGT     %10                                     ; Loop back if not the terminator
        DEC     r1                                      ; Point back at the terminator
        INC     r2                                      ; Adjust the remaining space accordingly
        Pull    pc
20
        Pull    lr
30
        [       UseMsgTrans
        ADR     Error, ErrorCDATBufferOverflow
        B       MakeErrorWithModuleName

ErrorCDATBufferOverflow
        DCD     ErrorNumber_CDATBufferOverflow
        DCB     "BufOFlo", 0
        ALIGN
        |       ; UseMsgTrans
        ADRL    r0, ErrorCDATBufferOverflow
        RETURNVS

        Err     CDATBufferOverflow
        ALIGN
        ]       ; UseMsgTrans

SetFileServerName ROUT
        Push    "r0, r1, lr"                            ; Name in R0
        ADD     r1, r0, #2                              ; Minimum size for "#",<cr>
10
        BL      ValidateReadAddress
        BVS     %90
        LDRB    r14, [ r1 ], #1                         ; Get the last byte that we validated
        CMP     r14, #" "                               ; Was it a terminator
        BGT     %10                                     ; No, try next byte
        MOV     r1, r0
        BL      ValidateDiscName
        BLVC    FindNamedContext
        [       OldOs
        STRVC   r0, Current
        |
        BLVC    EnforceContext
        ]
90
        STRVS   r0, [ sp ]
        Pull    "r0, r1, pc"

        [       :LNOT: OldOs
EnforceContext  ROUT
        ;       R0 => Pointer to context to ensure
        ;       All registers preserved
        Push    "r0-r3, lr"
        BL      MaybeChangeFS
        BEQ     ExitEnforce                             ; No change required
        LDR     r0, Current
        LDR     r1, [ r0, #Context_LibraryName ]
        TEQ     r1, #0                                  ; Is there a name?
        MOV     r2, #Dir_Library
        [       Debug
        DSTRING r1, "Library (%) := "
        ]
        BL      SetDir
        LDRVC   r1, [ r0, #Context_DirectoryName ]
        TEQ     r1, #0
        MOVVC   r2, #Dir_Current
        [       Debug
        BVS     ExitEnforce
        DSTRING r1, "C.S.D. (@) := "
        ]
        BLVC    SetDir
ExitEnforce
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r3, pc"
        ]

ReadFSRetryDelay
        ADR     r12, FSTransmitCount
        LDMIA   r12, { r0 - r5 }
        MOV     pc, lr

SetFSRetryDelay
        ADR     r12, FSTransmitCount
        STMIA   r12, { r0 - r5 }
        MOV     pc, lr

DoFSOpToGivenFS ROUT
        ;       R0 => Function
        ;       R1 => Buffer address
        ;       R2 => Send size
        ;       R3 => Receive size
        ;       R4 => Station number
        ;       R5 => Network number
        ;       R0 <= CommandCode
        Push    "r0-r8, lr"
        MOV     r0, r4
        MOV     r1, r5
        BL      ValidateFSNumber
        BVS     FSOpExit
        MOV     r3, r4
        MOV     r4, r5
        BL      FindNumberedContext
        BLVS    CreateNumberedContext                   ; No existing context, so make one
        BLVC    ValidateContext
        STRVC   r0, Temporary
        B       DoFSOpCommon

DoFileServerOp
        ;       R0 => Function
        ;       R1 => Buffer address
        ;       R2 => Send size
        ;       R3 => Receive size
        ;       R0 <= CommandCode
        Push    "r0-r8, lr"
        BL      MakeCurrentTemporary
DoFSOpCommon
        [       :LNOT: OldOs
        BLVC    EnsureFSHandles                         ; Make sure the file server is in step
        ]
        BVS     FSOpExit
        BL      ClearFSOpFlags
        LDMIA   sp, { r0, r1, r2, r3 }                  ; Retore entry conditions
        B       DoFSOpRegsSaved

DoFileServerOpEntry
        Push    "r0-r8, lr"                             ; Now we get our args from the stack
DoFSOpRegsSaved
        MOV     r0, r1
        ADD     r1, r0, r2
        BL      ValidateReadAddress
        ADD     r1, r0, r3
        BLVC    ValidateWriteAddress
        BVS     FSOpExit
        LDR     r0, [ sp ]                              ; Not restoring R1
        [       True                                    ; Saves one instruction
        TEQ     r0, #FileServer_SaveFile
        BEQ     FunctionIsSave
        TEQ     r0, #FileServer_LoadFile
        BEQ     FunctionIsLoad
        TEQ     r0, #FileServer_LoadAsCommand
        BEQ     FunctionIsLoadAsCommand
        TEQ     r0, #FileServer_GetByte
        BEQ     FunctionIsGetByte
        TEQ     r0, #FileServer_PutByte
        BEQ     FunctionIsPutByte
        TEQ     r0, #FileServer_GetBytes
        BEQ     FunctionIsGetBytes
        TEQ     r0, #FileServer_PutBytes
        BEQ     FunctionIsPutBytes
        |
        CMP     r0, #12
        ADDCC   pc, pc, r0, LSL #2
        B       SimpleCase

        B       SimpleCase                              ; CLI
        B       FunctionIsSave
        B       FunctionIsLoad
        B       SimpleCase                              ; Examine
        B       SimpleCase                              ; Catalog header
        B       FunctionIsLoadAsCommand
        B       SimpleCase                              ; Find
        B       SimpleCase                              ; Shut
        B       FunctionIsGetByte
        B       FunctionIsPutByte
        B       FunctionIsGetBytes
        B       FunctionIsPutBytes
        ]
SimpleCase
        BL      InitialiseTxHeader
        ; On exit from 'InitialiseTxHeader'
        ; R0 is the reply port
        ; R3 is the reception buffer
        ; R5 is transmission buffer size
        ; R8 is the address of the transmit buffer, and hence the RMA block
EntryForDifferentHeader
        ADD     r2, r8, #5                              ; Point at the data part of the command
EntryForGetPutHeader
        LDR     r1, [ sp, #8 ]                          ; Get send size out of the stack
        LDR     r6, [ sp, #4 ]                          ; Get buffer address out of the stack
10
        LDRB    r4, [ r6, r1 ]
        STRB    r4, [ r2, r1 ]
        SUBS    r1, r1, #1
        BPL     %10
        LDR     r6, Temporary
        ADD     r14, r6, #Context_Station
        LDMIA   r14, { r1, r2 }
        LDR     r4, [ sp, #12 ]                         ; Receive size
        ADD     r4, r4, #2                              ; Allow for reception header
        SWI     XEconet_CreateReceive
        BVS     FSOpDeAllocateExit
        MOV     r10, r0                                 ; The RxHandle
        LD      r0, FSOpSequenceNumber
        BIC     r0, r0, #2_01111110                     ; Zero out the task part
        BIC     r0, r0, #BitSeven                       ; Flag or control byte
        MOV     r1, #Port_FileServerCommand
        LDR     r2, [ r6, #Context_Station ]
        LDR     r3, [ r6, #Context_Network ]
        MOV     r4, r8                                  ; Buffer length, 'R5' is already set up
        LD      r6, FSTransmitCount
        LD      r7, FSTransmitDelay
        [       False ; Debug
        LDRB    r14, [ r8, #1 ]
        BREG    r14, "Transmitting with function code &"
        ]
        SWI     XEconet_DoTransmit
        BVS     FSOpAbandonAndDeAllocateExit
        [       False ; Debug
        DREG    r0, "Transmit returns status &"
        ]
        TEQ     r0, #Status_Transmitted
        BEQ     WaitForReception
        BL      ConvertStatusToError                    ; Note the fall through
FSOpAbandonAndDeAllocateExit
        MOV     r11, r0                                 ; Preserve old error
        MOV     r0, r10                                 ; Receive handle
        SWI     XEconet_AbandonReceive                  ; Ignoring errors
        MOV     r0, r11                                 ; Old error
FSOpDeAllocateExit
        MOV     r11, r0                                 ; Preserve old error
        MOV     r2, r8                                  ; The block to free
        BL      MyFreeRMA                               ; Ignoring errors
        MOV     r0, r11                                 ; Old error
FSOpErrorExit
        MOV     r11, r0                                 ; Preserve old error
        BL      ReleasePorts
        MOV     r0, r11                                 ; Old error
        SETV
        B       FSOpExit

WaitForReception
        [       False ; Debug
        DLINE   "Waiting for reply from FS"
        ]
        LDR     r6, Temporary
        STR     r4, [ r6, #Context_Network ]            ; Update in case it was the local net
        MOV     r0, r10                                 ; Rx handle
        LD      r1, FSReceiveDelay
        MOV     r2, pc                                  ; Non-zero => ESCapable
        SWI     XEconet_WaitForReception
        BVS     FSOpAbandonAndDeAllocateExit
        [       False ; Debug
        DREG    r0, "Wait returns status &"
        ]
        TEQ     r0, #Status_Received                    ; If it was OK then process
        BEQ     CheckRxHeader                           ; Command codes only interpreted when it went OK
        BL      ConvertStatusToError
        B       FSOpDeAllocateExit

CheckRxHeader
        SUB     r6, r6, #2                              ; Calculate true size of returned data
        STR     r6, [ sp, #12 ]                         ; Poke the replied size into the return stack frame
        LDRB    r1, [ r5 ], #2                          ; The returned CommandCode
        LDRB    r7, [ sp ]                              ; Original function code
        STR     r1, [ sp ]                              ; Poke into the return stack frame
        SUB     r0, r5, #2                              ; R5 now pointing at the returned data
        BL      ConvertFSError
        BVS     FSOpDeAllocateExit
        TEQ     r7, #0
        BEQ     InterpretCommandCode
ReturnUserData
        LDR     r4, [ sp, #4 ]                          ; Original buffer address
20
        DECS    r6                                      ; Copy data if there is any
        LDRPLB  r2, [ r5, r6 ]
        STRPLB  r2, [ r4, r6 ]                          ; Into the user's buffer
        BPL     %20
NoActionRequired
        MOV     r2, r8                                  ; The block to free
        BL      MyFreeRMA
        BVS     FSOpErrorExit
        ; Now check the original function
        CMP     r7, #1                                  ; Save
        CMPNE   r7, #2                                  ; Load
        CMPNE   r7, #10                                 ; GetBytes
        CMPNE   r7, #11                                 ; PutBytes
        BLNE    ReleasePorts                            ; Don't release if further work is going to happen
FSOpExit
        STRVS   r0, [ sp ]
        Pull    "r0-r8, pc"

ConvertFSError
        ;       R0 => Reply from the file server
        ;       If the file server returns an error then;
        ;       R0 <= Error block, V is set
        ;       Else;
        ;       R0 <= Preserved, V is clear
        Push    "lr"
        LDRB    r14, [ r0, #1 ]                         ; Get the return code
        CMP     r14, #0                                 ; Clears V
        Pull    "pc", EQ
        Push    "r1"
        ADD     r14, r14, #&00010000                    ; Make file server errors &000105xx
        ADD     r14, r14, #fsnumber_net :SHL: 8         ; Make file server errors &000105xx
        ADD     r0, r0, #2                              ; Move to begining of message
        [       UseMsgTrans
        ADR     r1, TemporaryBuffer
        |
        ADR     r1, ErrorBuffer
        ]
        STR     r14, [ r1 ], #4
ConvertFSErrorLoop                                      ; Copy the error string if there is one
        LDRB    r14, [ r0 ], #1
        CMP     r14, #" "
        MOVLO   r14, #0
        STRB    r14, [ r1 ], #1
        BHS     ConvertFSErrorLoop
        [       UseMsgTrans
        ADR     r0, TemporaryBuffer
        SWI     XMessageTrans_CopyError
        |
        ADR     r0, ErrorBuffer
        ]
        SETV
        Pull    "r1, pc"

InterpretCommandCode                                    ; In R1
        LDR     r14, Temporary
        CMP     r1, #MaximumCommandCode
        ADDLS   pc, pc, r1, LSL #2
        B       ReturnUserData
CommandCodeTable                                        ; Command code dispatch table
        B       ReturnUserData                          ; 0, NoActionRequired
        B       ReturnUserData                          ; 1, SaveCommand
        B       ReturnUserData                          ; 2, LoadCommand
        B       ReturnUserData                          ; 3, StarCat
        B       ReturnUserData                          ; 4, StarInfo
        B       ReturnFromLogon                         ; 5
        B       ReturnFromMount                         ; 6
        B       ReturnFromSelectDirectory               ; 7
        B       ReturnUserData                          ; 8, UnrecognisedCommand
        B       ReturnFromSelectLibrary                 ; 9
        B       ReturnUserData                          ; 10, StarDiscs
        B       ReturnUserData                          ; 11, StarUsers

MaximumCommandCode * ( ( . - CommandCodeTable ) / 4 ) - 1

ReturnFromLogon
        LDRB    r2, [ r5, #3 ]                          ; Boot option
        STRB    r2, [ r14, #Context_BootOption ]
ReturnFromMount
        LDRB    r2, [ r5 ], #1                          ; URD
        STRB    r2, [ r14, #Context_RootDirectory ]
        LDRB    r2, [ r5 ], #1                          ; CSD
        STRB    r2, [ r14, #Context_Directory ]
        LDRB    r2, [ r5 ]                              ; LIB
        STRB    r2, [ r14, #Context_Library ]
        B       NoActionRequired

ReturnFromSelectDirectory
        LDRB    r2, FSOpHandleFlags
        EOR     r2, r2, #BitSeven                       ; Flip the bit since this is from a *Dir not a *Lib
        B       %60

ReturnFromSelectLibrary
        LD      r2, FSOpHandleFlags
60
        TST     r2, #BitSeven                           ; See if *Dir was executed using *Lib or Vica Versa
        LDRB    r2, [ r5 ]                              ; LIB/CSD
        STRNEB  r2, [ r14, #Context_Directory ]
        STREQB  r2, [ r14, #Context_Library ]
        B       NoActionRequired

        ; ***************************************
        ; ***  Non standard entry conditions  ***
        ; ***************************************

FunctionIsGetByte
FunctionIsPutByte
        ADD     r5, r2, #2                              ; Total transmit size, for later
        ADD     r3, r3, #2                              ; Total reception size
        ADD     r3, r3, r5                              ; Sum of Rx and Tx sizes
        BL      MyClaimRMA                              ; Claim space for all of the transaction
        BVS     FSOpErrorExit
        MOV     r8, r2                                  ; Address of transmission buffer
        ADD     r3, r2, r5                              ; Address of reception buffer
        LDR     r0, [ sp, #0 ]                          ; Recover Function code
        STRB    r0, [ r8, #1 ]                          ; Put in 'TxHeader'
        BL      GetReplyPort
        BVS     FSOpDeAllocateExit
        STRB    r0, [ r8, #0 ]                          ; Put reply port in 'TxHeader'
        ADD     r2, r8, #2                              ; Point at the data part of the command
        B       EntryForGetPutHeader

FunctionIsLoadAsCommand
        ADR     Error, ErrorBadCommandCode
        [       UseMsgTrans
        BL      MakeError
        B       FSOpErrorExit

ErrorBadCommandCode
        DCD     ErrorNumber_BadCommandCode
        DCB     "BadCode", 0
        ALIGN
        |       ; UseMsgTrans
        B       FSOpErrorExit

        Err     BadCommandCode
        ALIGN
        ]       ; UseMsgTrans

FunctionIsLoad
FunctionIsSave
FunctionIsGetBytes
FunctionIsPutBytes
        BL      InitialiseTxHeader
        MOV     r11, r0                                 ; Preserve ReplyPort
        BL      GetAuxiliaryPort
        STRB    r0, [ r8, #2 ]                          ; Put in 'TxHeader' where URD should be
        MOV     r0, r11
        B       EntryForDifferentHeader

InitialiseTxHeader ROUT
        MOV     r6, lr
        ADD     r5, r2, #5                              ; Total transmit size, for later
        ADD     r3, r3, #2                              ; Total reception size
        ADD     r3, r3, r5                              ; Sum of Rx and Tx sizes
        BL      MyClaimRMA                              ; Claim space for all of the transaction
        BVS     FSOpErrorExit
        MOV     r8, r2                                  ; Address of transmission buffer
        ADD     r3, r2, r5                              ; Address of reception buffer
        LDR     r0, [ sp, #0 ]                          ; Recover Function code
        STRB    r0, [ r8, #1 ]                          ; Put in 'TxHeader'

        LD      r7, FSOpHandleFlags
        ; Bits 0 & 1 => Offset of handle to use in URD slot
        ; Bits 2 & 3 => Offset of handle to use in CSD slot
        ; Bits 4 & 5 => Offset of handle to use in LIB slot
        ; Offset values => 0 for URD, 1 for CSD, 2 for LIB
        ; Bit 6
        ; Bit 7 => Return from *Lib is for CSD or *Dir is for LIB
        LDR     r1, Temporary
        ADD     r1, r1, #Context_RootDirectory
        AND     r2, r7, #2_00000011
        LDRB    r0, [ r1, r2 ]
        STRB    r0, [ r8, #2 ]                          ; URD slot in 'TxHeader'
        [       Debug
        BREG    r0, "URD handle is &", cc
        ]
        myASR   r7, 2
        AND     r2, r7, #2_00000011
        LDRB    r0, [ r1, r2 ]
        STRB    r0, [ r8, #3 ]                          ; CSD slot in 'TxHeader'
        [       Debug
        BREG    r0, ", CSD handle is &", cc
        ]
        myASR   r7, 2
        AND     r2, r7, #2_00000011
        LDRB    r0, [ r1, r2 ]
        STRB    r0, [ r8, #4 ]                          ; LIB slot in 'TxHeader'
        [       Debug
        BREG    r0, ", LIB handle is &"
        ]
        BL      GetReplyPort
        BVS     FSOpDeAllocateExit
        STRB    r0, [ r8, #0 ]                          ; Put reply port in 'TxHeader'
        MOV     pc, r6

GetReplyPort    ROUT
        LDRB    r0, CurrentReplyPort
        CMP     r0, #0
        MOVNE   pc, lr
        Push    lr
        SWI     XEconet_AllocatePort
        STRVCB  r0, CurrentReplyPort
        Pull    pc

GetAuxiliaryPort ROUT
        LDRB    r0, CurrentAuxiliaryPort
        CMP     r0, #0
        MOVNE   pc, lr
        Push    lr
        SWI     XEconet_AllocatePort
        STRVCB  r0, CurrentAuxiliaryPort
        Pull    pc

ReleasePorts    ROUT
        Push    "r0, lr"
        LDRB    r0, CurrentReplyPort
        CMP     r0, #0                                  ; Clears V
        BEQ     ReleaseAuxPort
        MOV     r14, #0
        STRB    r14, CurrentReplyPort
        SWI     XEconet_DeAllocatePort
        BVC     ReleaseAuxPort
        ADR     lr, ReleasePortFails
        Push    "r0, lr"
        B       ReleaseAuxPort
ReleasePortFails
        SETV
        B       ExitReleasePort

ReleaseAuxPort
        LDRB    r0, CurrentAuxiliaryPort
        CMP     r0, #0                                  ; Clears V
        BEQ     ExitReleasePort
        MOV     r14, #0
        STRB    r14, CurrentAuxiliaryPort
        SWI     XEconet_DeAllocatePort
ExitReleasePort
        STRVS   r0, [ sp ]
        Pull    "r0, pc"

        [       :LNOT: OldOs
EnsureFSHandles ROUT
        ;       R0 => Context to ensure from (also in Temporary)
        ;       May trash r0-r8
        Push    "lr"
        LDR     r1, [ r0, #Context_RootDirectory ]      ; Are we logged on here?
        CMP     r1, #0                                  ; Clears V
        BEQ     ExitEnsureFSHandles
        MOV     r8, r0
        [       True
        LDR     r1, [ r8, #Context_DirectoryName ]
        BL      CacheDirectoryName
        ]
        ;       Now ensure the current directory (CSD)
        ;       Posibilities;
        ;       Dir To Ensure           CSDHandleName           LIBHandleName           Action
        ;       :Name.&                 :Name.&                                         None
        ;       :Name.&                 <>:Name.&               :Name.&                 Swap LIB/CSD
        ;       :Name.&                 <>:Name.&               <>:Name.&               *Dir<CR> (of URD)
        ;       :Name.&.a               :Name.&                                         *Lib a (of URD)
        ;       :Name.&.a               :Name.&.a                                       None
        ;       :Name.&.a               <>:Name.&.a             <>:Name.&.a             *Lib a (of URD)
        ;       In general, if DirToEnsure and CSDHandleName are equal then do nothing
        ;                   if DirToEnsure and LIBHandleName are equal then swap DIR and LIB
        LDR     r0, [ r8, #Context_DirectoryName ]
        [       Debug
        DSTRING r0, "Directory to ensure is "
        ]
        BL      ConvertNameToInternal
        MOV     r5, r0                                  ; Keep a copy of the internal name
        LDR     r3, [ r8, #Context_CSDHandleName ]
        BL      DoHandleName                            ; Check for it being a leading sub-string
        LDREQB  r14, [ r0 ]                             ; Refine check to exact match
        TEQEQ   r14, #0
        [       Debug
        BNE     %62
        DLINE   "Exact match, no action required"
62
        ]
        BEQ     EnsureLIB                               ; It is already right
        LDR     r3, [ r8, #Context_LIBHandleName ]
        BL      DoHandleName                            ; Check for it being a leading sub-string
        LDREQB  r14, [ r0 ]                             ; Refine check to exact match
        TEQEQ   r14, #0
        BNE     CSDRequiresAction                       ; No match at all
        [       Debug
        DLINE   "Exact match (with library), swaping CSD and LIB"
        ]
        LDRB    r1, [ r8, #Context_Directory ]          ; Swap CSD handle and LIB handle
        LDRB    r2, [ r8, #Context_Library ]
        LDR     r3, [ r8, #Context_CSDHandleName ]      ; Swap the names as well
        LDR     r4, [ r8, #Context_LIBHandleName ]
        STRB    r2, [ r8, #Context_Directory ]
        STRB    r1, [ r8, #Context_Library ]
        STR     r4, [ r8, #Context_CSDHandleName ]
        STR     r3, [ r8, #Context_LIBHandleName ]
        B       EnsureLIB

CSDRequiresAction
        ;       At this point scan to see if the name we are ensuring
        ;       is of the form :<name>.$ or &
        ;       If is is & then point at the character after the & else stay pointing at the :
        LDRB    r1, [ r5 ]
        TEQ     r1, #"&"
        ADDEQ   r0, r5, #1                              ; Point at the char past the &
        MOVNE   r0, r5
        ;       R0 is now pointing at either :<name>.$...
        ;       or, if it was :<name>.&... at the URD relative name, might be ""
        ;       If it is "" then we must do a *Dir with StandardFlags
        ADR     r1, CommandBuffer
        LDRB    r2, [ r0 ]
        CMP     r2, #" "
        BGT     CSDNameNotNull                          ; We have to copy the name
        HandleFlags r4, URD, CSD, LIB
        MOV     r4, #StandardFlags
        LDR     r0, =&0D726944                          ; "Dir", <CR>
        STR     r0, [ r1, #0 ]
        MOV     r2, #4                                  ; Size of command to send
        [       Debug
        DLINE   "Doing *Dir<CR> with StandardFlags"
        ]
        B       DoEnsureDIR                             ; Send off to file server

CSDNameNotNull
        TEQ     r2, #"."
        ADDEQ   r0, r0, #1                              ; Was pointing at the "." after the &
        HandleFlags r4, URD, URD, CSD, Flip
        LDR     r2, =&2062694C                          ; "Lib "
        STR     r2, [ r1 ]
        MOV     r2, #4
        BL      CopyNameIn
DoEnsureDIR
        ST      r4, FSOpHandleFlags
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        ADDVC   r4, r8, #Context_CSDHandleName          ; Internal name still in R5
        BLVC    SetString
        BVS     ExitEnsureFSHandles

EnsureLIB
        LDR     r0, [ r8, #Context_LibraryName ]
        [       Debug
        DSTRING r0, "Library to ensure is "
        ]
        BL      ConvertNameToInternal
        MOV     r5, r0
        LDR     r3, [ r8, #Context_LIBHandleName ]
        BL      DoHandleName                            ; Check for it being a leading sub-string
        LDREQB  r14, [ r0 ]                             ; Refine check to exact match
        TEQEQ   r14, #0
        [       Debug
        BNE     %63
        DLINE   "Exact match, no action required"
63
        ]
        BEQ     ExitEnsureFSHandles

        ;       At this point scan to see if the name we are ensuring
        ;       is of the form :<name>.$ or &
        ;       If is is & then point at the character after the & else stay pointing at the :
        LDRB    r1, [ r5 ]
        TEQ     r1, #"&"
        ADDEQ   r0, r5, #1                              ; Point at the char past the &
        MOVNE   r0, r5
        ;       R0 is now pointing at either :<name>.$...
        ;       or, if it was :<name>.&... at the URD relative name, might be ""
        ;       If it is "" then we must do a *Dir with to copy the URD to LIB
        ADR     r1, CommandBuffer
        LDRB    r2, [ r0 ]
        TEQ     r2, #13
        BNE     LIBNameNotNull                          ; We have to copy the name
        HandleFlags r4, URD, LIB, LIB, Flip
        LDR     r0, =&0D726944                          ; "Dir", <CR>
        STR     r0, [ r1, #0 ]
        MOV     r2, #4                                  ; Size of command to send
        [       Debug
        DLINE   "Doing *Dir<CR> to copy URD to LIB"
        ]
        B       DoEnsureLIB                             ; Send off to file server

LIBNameNotNull
        TEQ     r2, #"."
        ADDEQ   r0, r0, #1                              ; Was pointing at the "." after the &
        HandleFlags r4, URD, CSD, LIB
        LDR     r2, =&2062694C                          ; "Lib "
        STR     r2, [ r1 ]
        MOV     r2, #4
        BL      CopyNameIn
DoEnsureLIB
        ST      r4, FSOpHandleFlags
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        ADDVC   r4, r8, #Context_LIBHandleName
        BLVC    SetString
ExitEnsureFSHandles
        Pull    "pc"

ConvertNameToInternal ROUT
        ;       Pointer to name in R0
        ;       If name is of the form ":Name.&..." then return
        ;       R0 pointing at the "&" else preserve R0
        Push    "r0, lr"
10
        LDRB    r14, [ r0, #1 ] !
        TEQ     r14, #0
        Pull    "r0, pc", EQ
        TEQ     r14, #"&"
        BNE     %BT10
        [       Debug
        DSTRING r0, "Name converted to "
        ]
        STR     r0, [sp]
        Pull    "r0, pc"

        ]

ClearFSOpFlags  ROUT
        Push    lr
        MOV     r14, #4_0210                            ; Defaults
10
        ST      r14, FSOpHandleFlags
        Pull    pc

SetFSOpCSDFlag
        Push    lr
        LD      r14, FSOpHandleFlags
        BIC     r14, r14, #4_0030                       ; Clear the CSD field
        ORR     r14, r14, #4_0010                       ; Set it to CSD
        B       %10

        [       OldOs
SetFSOpLIBFlag
        Push    lr
        LD      r14, FSOpHandleFlags
        BIC     r14, r14, #4_0030                       ; Clear the CSD field
        ORR     r14, r14, #4_0020                       ; Set it to LIB
        B       %10
        ]

EnumerateFSCache
        ;       R0 => Entry point to enumerate from
        ;       R1 => Pointer to buffer
        ;       R2 => Number of bytes in the buffer
        ;       R3 => Number of entries to enumerate
        ;       R0 <= Entry point to use next time (-1 indicates no more left)
        ;       R2 <= Space remaining in buffer
        ;       R3 <= Number of entries enumerated
        ;       Format of entries;
        ;       Byte  0 => Station number
        ;       Byte  1 => Network number
        ;       Byte  2 => Disc number
        ;       Byte  3 => Disc name padded to 16 characters with spaces
        ;       Byte 19 => Zero
        TEQ     r3, #0
        MOVEQ   pc, lr
        Push    "r0-r2, r4-r7, lr"
        BL      FillCache
        BLVC    StopCache
        BVS     ExitEnumerateCache
        LDR     r0, [ sp ]                              ; Entry point
        LDR     r4, NameCache
        MOV     r5, #0                                  ; The index of the current record
        MOV     r6, r3                                  ; Number to do
        MOV     r3, #0                                  ; Number actually done
10
        TEQ     r4, #NIL                                ; Have we got to the end of the chain ??
        MOVEQ   r0, #-1
        BEQ     ExitEnumerateCache
        TEQ     r0, r5                                  ; Are we ready to start
        ADDNE   r5, r5, #1
        LDRNE   r4, [ r4, #Cache_Link ]                 ; Get the next link
        BNE     %10
20
        SUBS    r5, r2, #NetFS_Enumeration_SmallSize    ; Number of bytes required for one record
        BLT     ExitEnumerateCache
        MOV     r2, r5
        INC     r3                                      ; We have done one more
        INC     r0                                      ; Move on to the next record
        MOV     r5, #NetFS_Enumeration_SmallSize
        ADD     r7, r4, #Cache_Station                  ; Move to first part of record
30
        LDRB    r14, [ r7 ], #1
        STRB    r14, [ r1 ], #1
        DECS    r5
        BNE     %30
        LDR     r4, [ r4, #Cache_Link ]
        TEQ     r4, #NIL                                ; Have we got to the end of the chain ??
        MOVEQ   r0, #-1
        BEQ     ExitEnumerateCache
        DECS    r6
        BGT     %20

ExitEnumerateCache
        STR     r0, [ sp ]
        Pull    "r0-r2, r4-r7, pc"

StopCache
        ; Trashes R0, and R4
        Push    lr
        MOV     r4, #0
        PHPSEI                                          ; Don't allow the event task in here
        LDR     r0, BroadcastRxHandle
        STR     r4, BroadcastRxHandle
        PLP
        CMP     r0, #0                                  ; Clears V
        SWINE   XEconet_AbandonReceive
        Pull    pc

ConvertDateForUser
        Push    "r0-r1, lr"                             ; Source pointer in R0, destination in R1
        MOV     r0, r1
        ADD     r1, r0, #5                              ; Compute end of destination address
        BL      ValidateWriteAddress
        LDRVC   r0, [ sp, #0 ]
        ADD     r1, r0, #5                              ; Compute end of source address
        BLVC    ValidateReadAddress
        LDRB    r10, [ r0, #1 ]
        LDRVCB  r0, [ r0 ]
        ORRVC   r0, r0, r10, ASL #8                     ; Add in the high byte
        BLVC    ConvertFileServerDate                   ; From R0 into R10 and R11b
        BVS     ExitConvertDate
        LDR     r0, [ sp, #0 ]                          ; Get source pointer
        LDRB    r14, [ r0, #2 ]                         ; Hours [0..23]
        CMP     r14, #24
        BHS     ExitBadDate
        LDR     r1, OneHour
        MUL     r14, r1, r14                            ; Compute hours as centiseconds
        ADDS    r10, r10, r14
        ADDCS   r11, r11, #1
        LDRB    r14, [ r0, #3 ]                         ; Minutes [0..59]
        CMP     r14, #60
        BHS     ExitBadDate
        LDR     r1, OneMinute
        MUL     r14, r1, r14                            ; Compute minutes as centiseconds
        ADDS    r10, r10, r14
        ADDCS   r11, r11, #1
        LDRB    r14, [ r0, #4 ]                         ; Seconds [0..59]
        CMP     r14, #60
        BHS     ExitBadDate
        MOV     r1, #100                                ; One second
        MUL     r14, r1, r14                            ; Compute seconds as centiseconds
        ADDS    r10, r10, r14
        ADDCS   r11, r11, #1                            ; Should clear V for later
        LDR     r1, [ sp, #4 ]
        STRB    r10, [ r1, #0 ]
        MOV     r10, r10, ASR #8
        STRB    r10, [ r1, #1 ]
        MOV     r10, r10, ASR #8
        STRB    r10, [ r1, #2 ]
        MOV     r10, r10, ASR #8
        STRB    r10, [ r1, #3 ]
        STRB    r11, [ r1, #4 ]
ExitConvertDate
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r1, pc"

ExitBadDate
        ADR     r0, ErrorBadFileServerDate
        [       UseMsgTrans
        BL      MakeError
        B       ExitConvertDate

ErrorBadFileServerDate
        DCD     ErrorNumber_BadFileServerDate
        DCB     "BadDate", 0
        ALIGN
        |       ; UseMsgTrans
        SETV
        B       ExitConvertDate

        Err     BadFileServerDate
        ALIGN
        ]       ; UseMsgTrans

ValidateReadAddress
        Push    lr
        SWI     XOS_ValidateAddress
        Pull    pc, VS
        ADRCS   r0, ErrorCoreNotReadable
        B       ValidateExit

        [       UseMsgTrans
ErrorCoreNotReadable
        DCD     ErrorNumber_CoreNotReadable
        DCB     "BadRead", 0
        ALIGN

ErrorCoreNotWriteable
        DCD     ErrorNumber_CoreNotWriteable
        DCB     "BadWrt", 0
        ALIGN
        |       ; UseMsgTrans
        Err     CoreNotReadable
        Err     CoreNotWriteable
        ALIGN
        ]       ; UseMsgTrans

ValidateWriteAddress
        Push    lr
        SWI     XOS_ValidateAddress
        Pull    pc, VS
        ADRCS   r0, ErrorCoreNotWriteable
        [       UseMsgTrans
ValidateExit
        BLCS    MakeError
        |       ; UseMsgTrans
ValidateExit
        SETV    CS
        ]       ; UseMsgTrans
        Pull    pc

OneHour
        DCD     &00057E40
OneMinute
        DCD     &00001770

EnumerateFSList ROUT
        ;       R0 => Entry point to enumerate from
        ;       R1 => Pointer to buffer
        ;       R2 => Number of bytes in the buffer
        ;       R3 => Number of entries to enumerate
        ;       R0 <= Entry point to use next time (-1 indicates no more left)
        ;       R3 <= Number of entries enumerated
        ;       If the returned entry (or one of the returned entries)
        ;       is the current FS then C will be set else C will be clear
        ;       Trashes R10, R11
        ;       Format of entries returned to the caller;
        ;       Byte  0 => Station number
        ;       Byte  1 => Network number
        ;       Byte  2 => Reserved (0)
        ;       Byte  3 => Disc name padded to 16 characters with spaces
        ;       Byte 19 => Zero
        TEQ     r3, #0
        MOVEQ   pc, lr
        Push    "r1, r2, r4-r8"                         ; Don't preserve exit regs, note LR not
                                                        ; pushed (see exit code)
        MOV     r6, #NetFS_Enumeration_SmallSize        ; Means don't get user name in the record
        B       CommonFSEnumeration

EnumerateFSContexts
        ;       R0 => Entry point to enumerate from
        ;       R1 => Pointer to buffer
        ;       R2 => Number of bytes in the buffer
        ;       R3 => Number of entries to enumerate
        ;       R0 <= Entry point to use next time (-1 indicates no more left)
        ;       R3 <= Number of entries enumerated
        ;       If the returned entry (or one of the returned entries)
        ;       is the current FS then C will be set else C will be clear
        ;       Trashes R10, R11
        ;       Format of entries returned to the caller;
        ;       Byte  0 => Station number
        ;       Byte  1 => Network number
        ;       Byte  2 => Reserved (0)
        ;       Byte  3 => Disc name padded to 16 characters with spaces
        ;       Byte 19 => Zero
        ;       Byte 20 => User name padded to 21 characters with spaces
        ;       Byte 41 => Zero
        ;       Byte 42 => Reserved (0)
        ;       Byte 43 => Reserved (0)
        TEQ     r3, #0
        MOVEQ   pc, lr
        Push    "r1, r2, r4-r8"                         ; Don't preserve exit regs, note LR not
                                                        ; pushed (see exit code)
        MOV     r6, #NetFS_Enumeration_FullSize         ; Means get user name in the record
CommonFSEnumeration
        LDR     r11, Contexts                           ; First we count R0 records in to the start place
        LDR     r10, Current                            ; Get the pointer to the record to flag with C
        MOV     r8, r3                                  ; Number to do
        LDR     r7, =ContextIdentifier
        MOV     r4, #0                                  ; The index of the current record, whilst we find the first
        MOV     r3, #0                                  ; Number actually done, for exit
EnumerateFSSkipIn
        [       Debug
        DREG    r11, "(Skip) Record &"
        ]
        TEQ     r11, #NIL                               ; Is this the end of the list?
        BEQ     EnumerateFSEnd                          ; Yes, so return after checking the current FS
        LDR     r14, [ r11, #Context_Identifier ]
        TEQ     r14, r7                                 ; Is this really a context?
        BNE     EnumerateFSNoId                         ; No, so return an error
        LDR     r14, [ r11, #Context_RootDirectory ]
        TEQ     r14, #0                                 ; Is this record active?
        LDREQ   r11, [ r11, #Context_Link ]             ; No, so don't count it, just get another
        BEQ     EnumerateFSSkipIn
        TEQ     r0, r4                                  ; Are we ready to start
        ADDNE   r4, r4, #1                              ; If we aren't count this one,
        LDRNE   r11, [ r11, #Context_Link ]             ; Get the next record in the chain,
        BNE     EnumerateFSSkipIn                       ; And keep trying
EnumerateFSLoop
        [       Debug
        DREG    r11, "(Loop) Record &"
        ]
        SUBS    r2, r2, r6                              ; Number of bytes required for one record
        BLT     EnumerateFSExit                         ; No room left for this record
        INC     r3                                      ; We have done one more
        INC     r0                                      ; Move on to the next record
        TEQ     r11, r10                                ; Is this the Current FS?
        MOVEQ   r10, #CFlag                             ; Yes, so indicate
        LDR     r14, [ r11, #Context_Station ]
        STRB    r14, [ r1, #NetFS_Enumeration_Station ]
        LDR     r14, [ r11, #Context_Network ]
        STRB    r14, [ r1, #NetFS_Enumeration_Network ]
        MOV     r14, #0
        STRB    r14, [ r1, #NetFS_Enumeration_DriveNumber ]
        SUB     r5, r6, #NetFS_Enumeration_DiscName     ; Either 17 or 41
        ADD     r4, r11, #Context_DiscName              ; Move to begining of the name
        INC     r1, NetFS_Enumeration_DiscName
EnumerateFSCopyLoop
        LDRB    r14, [ r4 ], #1
        STRB    r14, [ r1 ], #1
        DECS    r5
        BNE     EnumerateFSCopyLoop
        DECS    r8                                      ; Have we done the number the caller asked for?
        BLE     EnumerateFSExit                         ; Yes, so return
        LDR     r11, [ r11, #Context_Link ]             ; Get the link address
        [       Debug
        DREG    r11, "(Next) Record &"
        ]
        TEQ     r11, #NIL                               ; Have we got to the end of the chain ??
        BEQ     EnumerateFSEnd
        LDR     r14, [ r11, #Context_Identifier ]
        TEQ     r14, r7                                 ; Is this really a context?
        BEQ     EnumerateFSLoop
EnumerateFSNoId
        ADRL    r0, ErrorNetFSInternalError
        [       UseMsgTrans
        BL      MakeErrorWithModuleName
        |
        SETV
        ]
        B       EnumerateFSExit

EnumerateFSEnd
        MOV     r0, #-1                                 ; Indicate that this is the end of the line
EnumerateFSExit
        ; Silly nonesense to get C flag out through general veneer at top of file
        Pull    "r1, r2, r4-r8, lr"                     ; Pull REAL return address to Kernel
        TEQ     pc, pc
        BNE     EnumerateFSExit26
EnumerateFSExit32
        AND     r10, r10, #CFlag                        ; Set iff returning current FS
        MRS     r11, CPSR
        BIC     r11, r11, #CFlag
        ORR     r11, r11, r10
        MSR     CPSR_f, r11
        MOV     pc, lr

EnumerateFSExit26
        AND     r10, r10, #CFlag                        ; Set iff returning current FS
        ORRVS   r10, r10, #VFlag                        ; Indicate an error
        BIC     lr, lr, #CFlag + VFlag                  ; Clear in the soon-to-be-PSR
        ORR     lr, lr, r10                             ; Shove in new bits
        MOVS    pc, lr

        LTORG

UpdateFSList    ROUT
        ;       R0 => Station number
        ;       R1 => Network number
        Push    lr
        [       Debug
        DLINE   "SWI NetFS_UpdateFSList called."
        DREG    r0, "r0 = &"
        DREG    r1, "r1 = &"
        ]
        TEQ     r0, #0                                  ; Look out for the special case
        TEQEQ   r1, #0                                  ; Of station 0, and network 0
        BEQ     ForceFillCache                          ; Must have EXACTLY "LR" on the stack
        BL      ValidateFSNumber
        Pull    pc, VS
        [       Debug
        DLINE   "Station number OK"
        ]
        Push    "r0-r9"
        MOV     r3, r0
        MOV     r4, r1
        BL      FindNumberedContext
        BLVS    CreateNumberedContext                   ; No existing context, so make one
        BVS     ExitUpdate
        STR     r0, Temporary                           ; And make it temporary
        [       Debug
        DREG    r0, "Using context at &"
        ]
        BL      ClearFSOpFlags
NastyUpdateEntry                                        ; Should have "r0-r9, lr" on the stack
        MOV     r9, #0                                  ; Start at logical disc zero
UpdateListLoop
        ADR     r1, CommandBuffer
        STRB    r9, [ r1, #0 ]                          ; Disc to start with
        MOV     r0, #(?TemporaryBuffer - 2) / 17        ; Compute how many will fit in the buffer
        STRB    r0, [ r1, #1 ]
        MOV     r2, #2
        MOV     r0, #FileServer_DiscName
        BL      DoFSOp
        MOV     r5, r1
        LDRB    r6, [ r5 ], #1                          ; Number of names received
        TEQ     r6, #0
        BEQ     ExitUpdate
        ADD     r9, r9, r6                              ; Calculate which drive is next
        LDR     r1, Temporary
        ADD     r1, r1, #Context_Station
        LDMIA   r1, { r1, r4 }                          ; Pickup the station and network numbers
        ORR     r4, r1, r4, LSL #8                      ; Combine station and network number
UpdateListDiscLoop
        DECS    r6
        BMI     UpdateListLoop                          ; Time to get more from the file server
        BL      UpdateCache
        BVC     UpdateListDiscLoop                      ; Use the next record from the file server
ExitUpdate
        STRVS   r0, [ sp ]
        Pull    "r0-r9, pc"

ValidateFSNumber ROUT
        ; Takes a station and network number in R1.R0
        ; and checks that they are OK values, then, if
        ; need be, will translate the network number to
        ; zero to cope with the local network.
        ; All regs preserved, except R1 (sometimes)
        Push    "r0-r1, lr"
        TEQ     r0, #0
        BNE     %30
10
        ADR     r0, ErrorBadStation
20
        [       UseMsgTrans
        BL      MakeError
        B       %90

ErrorBadStation
        DCD     ErrorNumber_BadStation
        DCB     "BadStn", 0
        ALIGN

ErrorBadNetwork
        DCD     ErrorNumber_BadNetwork
        DCB     "BadNet", 0
        ALIGN
        |       ; UseMsgTrans
        SETV
        B       %90

        Err     BadStation
        Err     BadNetwork
        ALIGN
        ]       ; UseMsgTrans

30
        CMP     r0, #255
        BHS     %10
        CMP     r1, #255
        ADRHS   r0, ErrorBadNetwork
        BHS     %20
        ; Trap the case where the given net number is the local one.
        TEQ     r1, #0                                  ; Test the network number
        BEQ     %90                                     ; Don't bother if the network number is zero
        SWI     XEconet_ReadLocalStationAndNet
        BVS     %90
        LDR     r0, [ sp, #4 ]                          ; Get the given network number
        EORS    r1, r0, r1                              ; Is the given net number the local net number?
        STREQ   r1, [ sp, #4 ]                          ; If so make it zero
90
        STRVS   r0, [ sp ]
        Pull    "r0-r1, pc"

ReadUserId      ROUT
        ;       R1 => Pointer to buffer
        ;       R2 => Number of bytes in the buffer
        ;       R2 <= Space remaining in buffer
        ;       Trashes R0
        TEQ     r2, #0
        BEQ     %30                                     ; No buffer!
        Push    lr
        MOV     r0, r1                                  ; Set up entry for validation and general exit condition
        ADD     r1, r1, r2
        BL      ValidateWriteAddress
        Pull    pc, VS
        MOV     r1, r0
        LDR     r12, Current
        LDR     r14, [ r12, #Context_RootDirectory ]
        TEQ     r14, #0                                 ; Are we currently logged on??
        STREQB  r14, [ r1 ]                             ; No, so write a null name
        Pull    pc, EQ
        ADD     r12, r12, #Context_UserId
10
        LDRB    r14, [ r12 ], #1                        ; Get byte of name or terminator
        DECS    r2                                      ; Less space left in buffer
        BMI     %20                                     ; Have we run out of space
        CMP     r14, #" "                               ; Is this the terminator
        MOVLE   r14, #0                                 ; Set the required terminator
        STRB    r14, [ r1 ], #1                         ; Store in the user's buffer
        BGT     %10                                     ; Loop back if not the terminator
        DEC     r1                                      ; Point back at the terminator
        INC     r2                                      ; Adjust the remaining space accordingly
        Pull    pc

20
        Pull    lr
30
        ADRL    r0, ErrorCDATBufferOverflow
        [       UseMsgTrans
        B       MakeError
        |
        RETURNVS
        ]

GetObjectUID ROUT
        ; R1 => Pointer to the object name
        ; R6 => Pointer to the special field, zero for no special field
        ; R0 <= Object type
        ; R1 <= Preserved
        ; R2 <= Object's load address
        ; R3 <= Object's exec address
        ; R4 <= Object's length
        ; R5 <= Object's attributes
        ; R6 <= LSW of UID
        ; R7 <= MSW of UID
        Push    "r0-r8, lr"                             ; Preserve registers including those preserved inside OS_File
        [       Debug
        DSTRING r6, "SWI GetObjectUID of Net#", cc
        DSTRING r1, ":"
        ]
        BL      UseNameToSetTemporary
        BVS     ExitGetUID
        BL      ClearFSOpFlags
        ADR     lr, CreateUID                           ; Set up return address
        Push    "r0-r5, lr"                             ; And standard stack frame for OS_File operation
        MOV     r8, sp                                  ; Keep r8 pointing at the input and output registers
        B       OsFileReadCat                           ; Returns ownership in r8, pulls "r0-r5, pc"
CreateUID
        BVS     ExitGetUID
        STR     r0, [ sp ]                              ; Return the type
        TEQ     r0, #0                                  ; Is it "not found"
        Pull    "r0-r8, pc", EQ                         ; Yes, so exit immediately
        ADD     r6, sp, #8                              ; Point at R2 in exit stack frame
        STMIA   r6, { r2, r3, r4, r5 }                  ; Update the return registers
        MOV     r0, r1                                  ; Save the filename pointer, ready for later
        ADRL    r1, CommandBuffer + 3                   ; Helps the alignment of the results
        MOV     r2, #7                                  ; Reason code for ReadUID
        STRB    r2, [ r1, #0 ]
        MOV     r2, #1
        MOV     r5, r0                                  ; Keep the name pointer for later
        BL      CopyObjectNameInDoingTranslation
        MOV     r0, #FileServer_ReadObjectInfo
        BL      DoFSOp
        BVC     NewUIDInterface
        LDR     r1, [ r0 ]
        LDR     r2, =&0001054F                          ; Error from SJ file servers not supporting this call
        TEQ     r1, r2
        BEQ     NotAcornUID                             ; Must be unsupported
        LDR     r2, =&0001058E                          ; Error from Acorn file servers not supporting this call
        TEQ     r1, r2
        BNE     ExitGetUID                              ; V still set, R0 still OK
        ADR     r1, CommandBuffer
        LDR     r2, =&6F666E49                          ; "Info"
        STR     r2, [ r1 ]
        LDR     r2, =&20                                ; " "
        STR     r2, [ r1, #4 ]
        MOV     r2, #5
        MOV     r0, r5                                  ; Get the name pointer
        BL      CopyObjectNameInDoingTranslation        ; No need for specials, directories not allowed
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        BVS     ExitGetUID
        TEQ     r3, #&44                                ; Magic constant that tells the difference between Acorn and SJ
        BNE     NotAcornUID                             ; Probably an early SJ file server
        ADR     r1, CommandBuffer + 60                  ; SIN
        MOV     r0, #16                                 ; Base 16
        SWI     XOS_ReadUnsigned
        BVS     ExitGetUID
        MOV     r8, r2                                  ; Save SIN for encoding later
        LDR     r0, [ sp, #4 ]                          ; Get the name out of the input frame
        LDRB    r2, [ r0 ], #1                          ; Check the first character
        TEQ     r2, #":"                                ; If it was a ":" then a name was supplied
        LDRNE   r0, Temporary
        ADDNE   r0, r0, #Context_DiscName
        ADR     r1, TemporaryBuffer
DiscNameLoop
        LDRB    r2, [ r0 ], #1
        TEQ     r2, #"."
        MOVEQ   r2, #0
        CMP     r2, #" "
        MOVLE   r2, #0
        STRB    r2, [ r1 ], #1
        BGT     DiscNameLoop
        ; Now convert the name in TemporaryBuffer to a disc number
        ADR     lr, ReturnFromUpdate
        Push    "r0-r9, lr"
        B       NastyUpdateEntry                        ; Updates the cache for this (temporary) file server
ReturnFromUpdate
        BVS     ExitGetUID
        BL      StopCache                               ; Trashes R0 and R4
        ADR     r1, TemporaryBuffer
        LDR     r7, NameCache
        LDR     r2, Temporary
        ADD     r2, r2, #Context_Station
        LDMIA   r2, { r2, r3 }
        ADD     r4, r2, r3, LSL #8                      ; Make a word like the cache entry
UIDLookUpLoop
        TEQ     r7, #NIL
        BEQ     UIDInternalError
        LDR     r2, [ r7, #Cache_Station ]              ; Get station, net, and drive number
        EOR     r0, r4, r2
        myASL   r0, 16, S                               ; Throw away the top 16 bits, and set or clear Z
        BNE     NextUIDLookUp
        ADD     r0, r7, #Cache_Name
        BL      CompareTwoStrings
        myROR   r2, 16                                  ; Byte order is now (highest to lowest) Net, Station, ?, Drive
        AND     r2, r2, #&FFFF00FF                      ; We only want the Station, net, and drive numbers
        BEQ     EncodeUID
NextUIDLookUp
        LDR     r7, [ r7, #Cache_Link ]
        B       UIDLookUpLoop

NewUIDInterface
        LDR     r8, [ r1, #1 ]                          ; First four bytes of UID, Note R1 not word aligned
        LDR     r0, Temporary
        ADD     r0, r0, #Context_Station
        LDMIA   r0, { r0, r2 }
        ORR     r2, r0, r2, ASL #8
        LDRB    r0, [ r1, #5 ]                          ; Filing system used in the FS
        ORR     r2, r0, r2, ASL #8
        LDRB    r0, [ r1, #6 ]                          ; Drive number
        ORR     r2, r0, r2, ASL #8
EncodeUID
        ; Now encode UID.  Inputs R8 and R2, outputs R0 and R1, trashes r14
        MOV     r14, #32
UIDEncodeLoop
        myROR   r8, 29, S                               ; Get every third bit starting from the top
        myRRX   r0, S                                   ; Move it in
        myRRX   r1, S                                   ; and through
        myROR   r2, 5, S                                ; Get every fifth bit starting from the bottom
        myRRX   r0, S                                   ; Move it in
        myRRX   r1, S                                   ; and through
        DECS    r14                                     ; Have we been and done it all yet?
        BNE     UIDEncodeLoop
        ADD     r14, sp, #24
        STMIA   r14, { r0, r1 }                         ; Output as R6 and R7
ExitGetUID
        BL      StartCache
        STRVS   r0, [ sp ]
        Pull    "r0-r8, pc"

UIDInternalError
        ADRL    Error, ErrorNetFSInternalError
        [       UseMsgTrans
        BL      MakeErrorWithModuleName
        |
        SETV
        ]
        B       ExitGetUID


NotAcornUID                                             ; Maybe use date and length as SIN
        ADR     Error, ErrorFileServerNotCapable
95
        [       UseMsgTrans
        BL      MakeError
        B       ExitGetUID

ErrorFileServerNotCapable
        DCD     ErrorNumber_FileServerNotCapable
        DCB     "FSNtCap", 0
        ALIGN
        |
        SETV
        B       ExitGetUID

        Err     FileServerNotCapable
        ALIGN
        ]       ; UseMsgTrans

        LTORG

        END
