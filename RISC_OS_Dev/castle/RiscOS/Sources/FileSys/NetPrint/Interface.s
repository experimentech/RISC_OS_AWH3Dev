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
; > &.Arthur.NetPrint.Interface

ModuleTitle
SWINames
        =       ModuleName, 0
        =       "ReadPSNumber", 0
        =       "SetPSNumber", 0
        =       "ReadPSName", 0
        =       "SetPSName", 0
        =       "ReadPSTimeouts", 0
        =       "SetPSTimeouts", 0
        =       "BindPSName", 0
        =       "ListServers", 0
        =       "ConvertStatusToString", 0
        =       0

SWICode ROUT
        LDR     wp, [ r12 ]
        CMP     r11, #(EndOfJumpTab-JumpTab)/4
        ADDCC   pc, pc, r11, LSL #2                     ; Jump via jump table to correct SWI
        B       UnknownSWI

JumpTab
        B       ReadPSNumber
        B       SetPSNumber
        B       ReadPSName
        B       SetPSName
        B       ReadPSTimeouts
        B       SetPSTimeouts
        B       BindPSName
        B       ListServers
        B       ConvertStatusToString

EndOfJumpTab

UnknownSWI
        ADR     r0, ErrorNoSuchSWI
        [       UseMsgTrans
        B       MakeErrorWithModuleName
        |
        RETURNVS                                        ; Return to Sam, setting V
        ]       ; UseMsgTrans

        ASSERT  NetPrintSWICheckValue-NetPrint_ReadPSNumber=(EndOfJumpTab-JumpTab)/4

        [       UseMsgTrans
ErrorNoSuchSWI
        DCD     ErrorNumber_NoSuchSWI
        DCB     "BadSWI", 0
        ALIGN
        |
        Err     NoSuchSWI
        ]       ; UseMsgTrans

ReadPSTimeouts ROUT
        ; R0 <= Transmit count
        ; R1 <= Transmit delay
        ; R2 <= Machine peek count
        ; R3 <= Machine peek delay
        ; R4 <= Receive delay
        ; R5 <= Broadcast delay
        ADR     r10, TransmitCount
        LDMIA   r10, { r0-r5 }
        MOV     pc, lr

SetPSTimeouts
        ; R0 => Transmit count
        ; R1 => Transmit delay
        ; R2 => Machine peek count
        ; R3 => Machine peek delay
        ; R4 => Receive delay
        ; R5 => Broadcast delay
        ADR     r10, TransmitCount
        STMIA   r10, { r0-r5 }
        MOV     pc, lr

SetPSName ROUT
        ; R0 => Pointer to new name
        Push    "r0, lr" ;
        DEC     sp, 8
        ASSERT  PSNameSize+1 < 8                        ; Will the name fit in the stack frame?
        BL      ValidateNameIntoStack
        BVS     ExitName
        LDMIA   sp, {r10, r11}                          ; Get the name
        ADR     r14, CurrentName
        STMIA   r14, {r10, r11}                         ; Store it
        MOV     r10, #0
        STR     r10, [ r14, #CurrentStation-CurrentName ]
        STR     r10, [ r14, #CurrentNetwork-CurrentName ]
        ST      r10, Mode                               ; Zero means name
        CLRV
ExitName
        INC     sp, 8                                   ; Trash stack frame
        STRVS   r0, [ sp ]
        Pull    "r0, pc"

BindPSName ROUT
        ; R0      => Pointer to new name
        ; R0      <= Station number
        ; R1      <= Network number
        ; R10+R11 <= Bound name, case preserved
        Push    "r0, lr" ;
        DEC     sp, 8
        ASSERT  PSNameSize+1 < 8                        ; Will the name fit in the stack frame?
        BL      ValidateNameIntoStack
        BVS     ExitName
        MOV     r0, sp
        LDMIA   r0, { r10, r11 }
        BL      BindName
        STR     r0, [ sp, #8 ]
        B       ExitName

SetPSNumber ROUT
        ; R0 => Station number
        ; R1 => Network number
        TEQ     r0, #0
        BNE     StationNotZero
ExitBadStation
        ADR     r0, ErrorBadStation
        [       UseMsgTrans
        B       MessageTransErrorLookup

ErrorBadStation
        DCD     ErrorNumber_BadStation
        DCB     "BadStn", 0
        ALIGN

ExitBadNetwork
        ADR     r0, ErrorBadNetwork
        B       MessageTransErrorLookup

ErrorBadNetwork
        DCD     ErrorNumber_BadNetwork
        DCB     "BadNet", 0
        ALIGN
        |
        RETURNVS

        Err     BadStation
        Err     BadNetwork
        ]

StationNotZero
        CMP     r0, #255
        BHS     ExitBadStation
        CMP     r1, #255
        [       UseMsgTrans
        BHS     ExitBadNetwork
        |
        ADRHS   r0, ErrorBadNetwork
        RETURNVS HS
        ]
        ; Trap the case where the given net number is the local one.
        MOV     r10, r0                                 ; Save station number
        MOVS    r11, r1                                 ; Save network number
        BEQ     NetworkNumberTranslated                 ; Don't bother if the network number is zero
        Push    lr
        SWI     XEconet_ReadLocalStationAndNet
        Pull    lr
        MOVVS   pc, lr
        TEQ     r1, r11                                 ; Is the given net number the local net number?
        MOVEQ   r11, #0                                 ; If so make it zero
NetworkNumberTranslated
        ST      r10, CurrentStation
        ST      r11, CurrentNetwork
        ST      sp, Mode                                ; Positive means number
        MOV     r0, #0
        STR     r0, CurrentName
ReadPSNumber
        ; R0 <= Station number
        ; R1 <= Network number
        LDRB    r0, CurrentStation
        LDRB    r1, CurrentNetwork
        RETURNVC

ReadPSName ROUT
        ; R0 => Don't care
        ; R1 => Pointer to core
        ; R2 => Limit count
        ; R0 <= Entry value of R1
        ; R1 <= Updated
        ; R2 <= Updated

        MOV     r11, lr                                 ; Store return address
        MOV     r0, r1                                  ; Make a note of the start of the buffer
        ADD     r1, r1, r2                              ; Work out the end of the buffer
        BL      ValidateWriteAddress
        MOVVS   pc, r11
        MOV     r1, r0                                  ; Address of users buffer
        ADR     r12, CurrentName                        ; Last use of R12 as WP
ReadPSLoop
        DECS    r2                                      ; Less space left in buffer
        BPL     StillRoomInBuffer
        ADR     r0, ErrorCDATBufferOverflow
        [       UseMsgTrans
        MOV     lr, r11
        B       MakeErrorWithModuleName

ErrorCDATBufferOverflow
        DCD     ErrorNumber_CDATBufferOverflow
        DCB     "BufOFlo", 0
        ALIGN
        |
        RETURNVS                                         ; Set V for error return

        Err     CDATBufferOverflow
        ]       ; UseMsgTrans

StillRoomInBuffer
        LDRB    r10, [ r12 ], #1                        ; Get byte of name or terminator
        CMP     r10, #" "                               ; Is this the terminator
        MOVLE   r10, #0                                 ; Set the required terminator
        STRB    r10, [ r1 ], #1                         ; Continually update R1 to point to the end
        BGT     ReadPSLoop                              ; Store in the user's buffer
        DEC     r1                                      ; Point back at the terminator
        INC     r2                                      ; Adjust the reaining space accordingly
        RETURNVC                                        ; Clear V for good return

ValidateNameIntoStack
        ; R0 => Pointer to name
        ; SP => destination for name
        ; IF name="" then use the configured name
        ; IF configuration is not a name then use "PRINT "
        ; Trashes R10, & R11
        MOV     r10, sp                                 ; Destination pointer
        Push    "r0-r2, lr"
ReEnterValidation
        MOV     r1, r0
ValidationLoop
        INC     r1
        SUB     r11, r1, r0                             ; How far have we got?
        CMP     r11, #PSNameSize + 1
        BHI     ValidatedNameTooBig
        BL      ValidateReadAddress
        BVS     ExitNameValidation
        LDRB    r11, [ r1, #-1 ]
        CMP     r11, #" "
        MOVLE   r11, #0
        STRB    r11, [ r10 ], #1
        BGT     ValidationLoop
        SUB     r11, r1, r0                             ; How far have we got?
        TEQ     r11, #1                                 ; Is the name null
        BNE     ExitNameValidation
        SUB     r10, r10, #1                            ; Restore pointer
        MOV     r0, #OsByte_ReadCMOS
        MOV     r1, #NetPSIDCMOS
        SWI     XOS_Byte
        BVS     ExitNameValidation
        TEQ     r2, #0                                  ; Is the default a name?
        ADRL    r0, PrintStr
        BNE     ReEnterValidation
        BL      ReadConfiguredName
        B       ExitNameValidation

ValidatedNameTooBig                                     ; Jump'd to from GSTransName
        ;       Name pointed to by R0
        [       UseMsgTrans
        Push    "r4, r5"
        MOV     r4, r0                                  ; Name to put in error string
        ADR     r0, ErrorPrinterServerNameTooLong
        ADR     r5, String6
        BL      MessageTransErrorLookup2
        Pull    "r4, r5"
ExitNameValidation
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r2, pc"

ErrorPrinterServerNameTooLong
        DCD     ErrorNumber_PrinterServerNameTooLong
        DCB     "LongNam", 0

String6 DCB     "6", 0
        ALIGN
        |
        ADR     r0, ErrorPrinterServerNameTooLong
        SETV
ExitNameValidation
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r2, pc"

        Err     PrinterServerNameTooLong
        ]       ; UseMsgTrans

BindName ROUT
        ; Name of printer server pointed to by R0
        ; If name bound OK then station & net in R0 and R1
        ; If not able to bind then returns an error;
        ; "Printer '<thing>' not found" if there were no replies at all.
        ; "Printer '<thing>' <printer status>" if one wasn't ready.
        ; "All '<thing>' printers busy" if more than one wasn't ready.

        Push    "r0-r11, lr"                            ; Pointer to original name is now [ sp, #0 ]
        [       Debug
        DSTRING r0, "Binding ",cc
        DREG    r0, " at &", cc
        DREG    r13, " at [SP], SP = &"
        ]
        ADR     r4, TempPSName
        ADD     r1, r4, #PSNameSize                     ; End address
getpara
        LDRB    r2, [ r0 ], #1                          ; Get character from buffer
        ASCII_UpperCase r2, r14
        CMP     r2, #" "
        MOVCC   r2, #" "                                ; Convert character to space if control
padout
        STRB    r2, [ r4 ], #1                          ; Must do this for early PS implementations
        TEQ     r4, r1                                  ; if at end
        BHI     getpara                                 ; if C=1 and not at end then copy more chars
        BNE     padout                                  ; if C=0 and not at end then pad out with space
        MOV     r2, #1                                  ; Reason code 1 for status about PS
        STRB    r2, [ r4 ], #1
        MOV     r2, #0
        STRB    r2, [ r4 ]                              ; Got name now, so broadcast it
        MOV     r10, #0                                 ; Initialise the RxHandle
        MOV     r11, #0                                 ; Setup station cache so that no receptions have occured
        SWI     XOS_ReadMonotonicTime
        BVS     ExitBindName
        LD      r9, BroadcastDelay
        ADD     r9, r9, r0                              ; Termination time
        MOV     r8, r0                                  ; Next broadcast time
ReBroadcast
        [       Debug
        LDR     r0, [ sp ]
        DSTRING r0, "Binding ",cc
        DREG    r0, " at &", cc
        DREG    r13, " at [SP], SP = &"
        ]
        ADD     r8, r8, #200                            ; Next broadcast time
        MOV     r0, #0                                  ; Flag byte, with sequence bit clear
        MOV     r1, #Port_PrinterServerInquiry
        ADR     r4, TempPSName                          ; Points R4 at name for PS to respond to
        BL      DoBroadcast                             ; Sets the remainder of the registers (up to R7)
        BVS     ExitBindName
ReOpenRx
        BL      AbandonR10
        MOV     r0, #Port_PrinterServerInquiryReply
        MOV     r1, #0                                  ; Means any station, any net
        MOV     r2, #0
        ADD     r3, sp, #4                              ; Use space in stack, return R1 setup later
        MOV     r4, #4                                  ; Only use one word/register
        TEQ     r10, #0                                 ; Is there an RxCB already open?
        BNE     PollRx                                  ; Yes, so skip the open
        SWI     XEconet_CreateReceive
        BVS     ExitBindName
        MOV     r10, r0                                 ; Remember the handle for this block
        [       Debug
        DREG    r0, "Bind Rx handle is &"
        ]
PollRx
        MOV     r0, r10
        SWI     XEconet_ExamineReceive
        BVS     ExitBindName
        TEQ     r0, #Status_Received
        BEQ     ExamineReply
        WritePSRc USR_mode,r3,,r4                       ; Enable all interrupts and go to user mode
        SWI     XOS_ReadMonotonicTime
        MOVVC   r3, #0                                  ; Record no error state
        MOVVS   r3, r0                                  ; Record error
        SWI     XOS_EnterOS                             ; Get back to SVC mode, ignore error
        RestPSR r4                                      ; Restore interrupts and mode (might be IRQ)
        CMP     r3, #0                                  ; Test of the error, clears V
        MOVNE   r0, r3                                  ; There was an error
        SETV    NE                                      ; So go to the error state
        BVS     ExitBindName
        CMP     r0, r9                                  ; Have we finished altogether?
        BHS     BindTimeExpired
        CMP     r0, r8                                  ; Is it time for another broadcast?
        BHS     ReBroadcast
        B       PollRx

ExamineReply
        MOV     r0, r10
        SWI     XEconet_ReadReceive
        BVS     ExitBindName
ReTryStatus
        [       Debug
        LDR     r0, [ r5 ]                              ; Get the status 24bits
        BIC     r0, r0, #&FF000000
        DREG    r0, "Status = &", cc
        BREG    r4, " from station = ", cc
        BREG    r3, "."
        AND     r0, r0, #&FF
        |
        LDRB    r0, [ r5 ]                              ; Get the status byte
        ]
        TST     r0, #2_00000111                         ; Test the input status
        BEQ     ThisPrinterOK
        CMP     r11, #0                                 ; Check state of "how many etc." flag
        BMI     ReOpenRx                                ; We have already had two different replies
        ORR     r3, r3, r4, LSL #8                      ; Join net and station numbers together
        ORR     r3, r3, r0, LSL #16                     ; Add in the status
        ; Top byte=zero, MidHi byte=status, MidLo byte=net, Low byte=stn
        MOVEQ   r11, r3                                 ; If this is the first then it is the new flag
        BEQ     ReOpenRx
        EOR     r0, r11, r3
        BICS    r0, r0, #&00FF0000                      ; Clear out the status
        MOVNE   r11, #-1                                ; It was a second station replying so indicate
        B       ReOpenRx

ThisPrinterOK
        MOV     r0, r3
        MOV     r1, r4
        BL      MultiStreamCapable
        MOVVS   r0, #7                                  ; Special status for already open
        STRVS   r0, [ r5 ]
        BVS     ReTryStatus
ExitBindName
        BL      AbandonR10                              ; Remove RxCB
        INC     sp, 8                                   ; Trash data part of stack frame
        Pull    "r2-r11, pc"

BindTimeExpired
        ; R11 tells us what happened
        ; [ SP, #0 ] holds the printer's name
        [       Debug
        LDR     r0, [ sp ]
        DSTRING r0, "Binding ",cc
        DREG    r0, " at &", cc
        DREG    r13, " at [SP], SP = &"
        ]
        BL      AbandonR10
        [       :LNOT: UseMsgTrans
        ADR     r1, ErrorBuffer
        MOV     r2, #?ErrorBuffer - 4
        LDR     r0, =ErrorNumber_AllPrintersBusy
        STR     r0, [ r1 ], #4
        ]
        CMP     r11, #0
        BEQ     NoneFoundAtAll
        BMI     TooManyFound
        [       UseMsgTrans
        ADR     r8, ErrorPSStatus
ConnectErrorExit                                        ; Jump'd to from OpenByNumber
        ADR     r1, TempPSName                          ; A buffer to make the station number
        MOV     r2, #?TempPSName                        ; string into
        AND     r3, r11, #&FF                           ; Get the station number back
        myLSR   r11, 8                                  ; Throw station number away
        AND     r4, r11, #&FF                           ; Get the network number back
        Push    "r3, r4"                                ; Put station address in stack
        MOVVC   r0, sp
        SWIVC   XOS_ConvertNetStation
        INC     sp, 8                                   ; Throw stack frame away
        BVS     ExitBindName
        ADD     r0, sp, #4                              ; Get the address of the last returned status
        ADR     r1, TemporaryBuffer                     ; A different place to make this
        MOV     r2, #?TemporaryBuffer                   ; string into
        BL      ConvertStatusToString
        MOV     r0, r8
        LDR     r4, [ sp, #0 ]                          ; Address of the supplied name argument %0
        ADR     r5, TempPSName                          ; The buffer where the station number is %1
        ADR     r6, TemporaryBuffer                     ; The buffer where the status is %2
        BL      MessageTransErrorLookup3
        B       ExitBindName

ErrorPSStatus
        DCD     ErrorNumber_AllPrintersBusy
        DCB     "PSStat", 0
        ALIGN
        |
        BL      AddString
        DCB     ErrorString_AllPrintersBusyPre1
        DCB     0
        ALIGN
        LDRVC   r0, [ sp ]
        BLVC    CopyString
        BVS     ExitBindName
        BL      AddString
        DCB     ErrorString_AllPrintersBusyMid
        DCB     0
        ALIGN
        AND     r3, r11, #&FF                           ; Get the station number back
        myLSR   r11, 8                                  ; Throw station number away
        AND     r4, r11, #&FF                           ; Get the network number back
        Push    "r3, r4"                                ; Put station address in stack
        MOVVC   r0, sp
        SWIVC   XOS_ConvertNetStation
        INC     sp, 8                                   ; Throw stack frame away
        BVS     ExitBindName
        BL      AddString
        DCB     ErrorString_AllPrintersBusyPost1
        DCB     0
        ALIGN
        LDRVC   r0, [ sp, #4 ]                          ; Get the last returned status
        BLVC    AddStatus
        BVS     ExitBindName
        B       ExitBindWithError
        ]

TooManyFound
        [       UseMsgTrans
        ADR     r0, ErrorPSBusy
        B       BindErrorNameOnly

ErrorPSBusy
        DCD     ErrorNumber_AllPrintersBusy
        DCB     "PSBusy", 0
        ALIGN
        |
        BL      AddString
        DCB     ErrorString_AllPrintersBusyPre2
        DCB     0
        ALIGN
        LDRVC   r0, [ sp ]
        BLVC    CopyString
        BVS     ExitBindName
        BL      AddString
        DCB     ErrorString_AllPrintersBusyPost3
        DCB     0
        ALIGN
        BVS     ExitBindName
        B       ExitBindWithError
        ]

NoneFoundAtAll
        [       UseMsgTrans
        ADR     r0, ErrorPSNotFound
BindErrorNameOnly
        LDR     r4, [ sp, #0 ]                          ; Address of the supplied name argument %0
        BL      MessageTransErrorLookup1
        B       ExitBindName

ErrorPSNotFound
        DCD     ErrorNumber_NetPrinterNotFound
        DCB     "PSNtFnd", 0
        ALIGN
        |
        BL      AddString
        DCB     ErrorString_AllPrintersBusyPre1
        DCB     0
        ALIGN
        LDRVC   r0, [ sp ]
        BLVC    CopyString
        BVS     ExitBindName
        BL      AddString
        DCB     ErrorString_AllPrintersBusyPost2
        DCB     0
        ALIGN
        BVS     ExitBindName
ExitBindWithError
        ADR     r0, ErrorBuffer
        SETV
        B       ExitBindName
        ]

MultiStreamCapable
        ; Now find if this printer server has been opened before, and,
        ; if it has, whether it supports multiple streams.
        ; Printer in R1.R0, preserved if OK else error
        Push    "r8, r11, lr"
        CLRV
        LDR     r8, FirstLink                           ; Get first one out
        TEQ     r8, #NIL                                ; Test for the special case
        BEQ     ExitCapability                          ; If first file, then PS isn't known about
CapabilitySearch
        LDR     r11, Station
        TEQ     r11, r0
        LDREQ   r14, Network
        TEQEQ   r14, r1
        BEQ     CapabilityCheck
        LDR     r8, Link                                ; Get on to the next record
        TEQ     r8, #NIL                                ; If r8 <> 0, then chain down list
        BNE     CapabilitySearch
        B       ExitCapability                          ; End if list so give up the search

CapabilityCheck
        LDR     r14, Flag                               ; If this has a zero for the stream, then
        ANDS    r14, r14, #2_01111000                   ; It cannot support multiple streams
        BNE     ExitCapability                          ; Non zero means OK
NotCapable
        ADR     r0, ErrorSingleStream                   ; Get error message
        [       UseMsgTrans
        BL      MessageTransErrorLookup
        |
        SETV
        ]
ExitCapability
        Pull    "r8, r11, pc"

        [       UseMsgTrans
ErrorSingleStream
        DCD     ErrorNumber_SingleStream
        DCB     "PSInUse", 0
        ALIGN
        |
        Err     SingleStream
        ]

ListServers     ROUT
        ;       In:
        ;
        ;       R0  Format code:
        ;               0 ==> Names and numbers.
        ;               1 ==> Names only, sorted, no duplicates.
        ;               2 ==> Names, numbers and status.
        ;               Others treated as format 0
        ;       R1  Pointer to a buffer in which data will be returned.
        ;       R2  Length of the buffer in bytes.
        ;       R3  Time to take before returning, in centi-seconds.
        ;
        ;       Out:
        ;
        ;       R0  Number of entries returned.
        ;       R1  Preserved.
        ;       R2  Preserved.
        ;       R3  Return code, 0 for timed out, 1 for buffer full.

        Push    "r1, r2, r4-r10, lr"
        SWI     XHourglass_On
        [       Debug
        DREG    r0, "ListServers called, format = &"
        DREG    r1, "Buffer at &", cc
        DREG    r2, " is &", cc
        DLINE   " bytes long."
        DREG    r3, "The timeout is &"
        ]
        MOV     r11, r0                                 ; Keep the format code
        SWI     XOS_ReadMonotonicTime
        ADD     r10, r0, r3                             ; Calculate the return time
        MOVVC   r0, r1                                  ; Buffer start address
        ADD     r1, r1, r2                              ; Compute buffer end address
        [       Debug
        BVS     ExitListServers
        DLINE   "XOS_ReadMonotonicTime OK"
        ]
        BLVC    ValidateWriteAddress
        [       Debug
        BVS     ExitListServers
        DLINE   "ValidateWriteAddress OK"
        ]
        BLVC    BroadcastForNames
        BVS     ExitListServers
        [       Debug
        DLINE   "BroadcastForNames OK"
        ]
        LDR     r1, [ sp ]                              ; Get the start of the buffer
        MOV     r9, #0                                  ; Number of entries returned
ListServersLoop
        [       Debug
        DREG    r9, "Number of entries returned = &"
        ]
        WritePSRc USR_mode,r7,,r8                       ; Enable all interrupts and go to user mode
        SWI     XOS_ReadMonotonicTime
        MOVVC   r7, #0                                  ; Record no error state
        MOVVS   r7, r0                                  ; Record error
        SWI     XOS_EnterOS                             ; Get back to SVC mode, ignore error
        RestPSR r8                                      ; Restore interrupts and mode (might be IRQ)
        CMP     r7, #0                                  ; Test of the error, clears V
        MOVNE   r0, r7                                  ; There was an error
        SETV    NE                                      ; So go to the error state
        BVS     ExitListServers
        [       Debug
        DLINE   "XOS_ReadMonotonicTime OK"
        ]
        CMP     r0, r10                                 ; Check against the return time
        BHS     ListServersTimesOut
        TEQ     r11, #2                                 ; Check if format includes status
        BNE     %40                                     ; Skip status handles if not
        ADR     r8, StatusHandles
20
        LDR     r0, [ r8 ], #4
        TEQ     r0, #NIL                                ; No handle?
        BEQ     %30
        [       Debug
        DREG    r0, "Checking status handle &"
        ]
        SWI     XEconet_ExamineReceive
        BVS     ExitListServers
        TEQ     r0, #Status_Received
        BLEQ    ProcessServerStatus
        BVS     ExitListServers
30
        ADR     r14, ( StatusHandles + 4 * NumberOfBuffers )
        TEQ     r8, r14
        BNE     %20
40
        ADR     r8, BroadcastHandles
50
        [       Debug
        DREG    r8, "Fetching from &", cc
        ]
        LDR     r0, [ r8 ], #4
        [       Debug
        DREG    r0, "; handle is &"
        ]
        SWI     XEconet_ExamineReceive             ; These handles are always open
        BVS     ExitListServers
        TEQ     r0, #Status_Received
        BLEQ    ProcessServerName                       ; Something has happened!
        BVS     ExitListServers
        ADR     r14, ( BroadcastHandles + 4 * NumberOfBuffers )
        TEQ     r8, r14
        BNE     %50
        B       ListServersLoop

ListServersFillsBuffer
        MOV     r3, #1                                  ; Return code for buffer overflowed
        B       GoodExitListServers
ListServersTimesOut
        MOV     r3, #0                                  ; Return code for timed out
GoodExitListServers
        MOV     r0, r9                                  ; Number of entries returned
ExitListServers
        SavePSR r10
        SWI     XHourglass_Off
        BL      AbandonReceptions                       ; Preserves R0
        TST     r10, #VFlag
        SETV    NE
        Pull    "r1, r2, r4-r10, pc"

ProcessServerName ROUT
        ;       R1 is the current buffer pointer, increment by the amount used
        ;       R2 is the space remaining, decrement by the amount used
        ;       R8, #-4 is the address of the handle, must be preserved
        ;       R9 is the number of entries, probably incremented
        ;       R10 must be preserved
        ;       R11 is the format, must be preserved
        LDR     r0, [ r8, #-4 ]                         ; Get the handle again
        [       Debug
        DREG    r0, "Reception on handle &", cc
        DREG    r8, ", stored at &", cc
        DLINE   " - 4"
        ]
        TEQ     r11, #2                                 ; Is this "full info" format?
        BEQ     ProcessGetStatus
        [       Debug
        DREG    r1, "Writing record at &"
        ]
        Push    "r1, r2, lr"
        SWI     XEconet_ReadReceive                ; Use this to get the buffer address in R5
        Pull    "r1, r2, lr"
        BVS     ExitProcessServer
        TEQ     r11, #1                                 ; Is this "names only" format?
        BEQ     ProcessNameOnly
ProcessNameAndNumber
        CMP     r2, #1+1+PSNameSize+1
        BLO     ListServersFillsBuffer
        STRB    r3, [ r1 ], #1                          ; Station number
        STRB    r4, [ r1 ], #1                          ; Network number
        [       Debug
        BREG    r4, "Station &", cc
        BREG    r3, ".&", cc
        DLINE   " '", cc
        ]
        MOV     r6, #0                                  ; Index and termination condition
        DEC     r2, 2                                   ; Account for the space used so far
20
        LDRB    r0, [ r5, r6 ]
        CMP     r0, #" "                                ; Is this padding for the server?
        MOVLS   r0, #0
        TEQ     r6, #PSNameSize                         ; Is this over the end?
        MOVEQ   r0, #0
        STRB    r0, [ r1 ], #1                          ; Give it to the client
        [       Debug
        Push    lr
        SWI     OS_WriteC
        Pull    lr
        ]
        INC     r6                                      ; Move to the next byte
        DEC     r2                                      ; One more byte used
        TEQ     r0, #0                                  ; Was that the last byte?
        BNE     %20
        INCS    r9                                      ; Clears V
        [       Debug
        DLINE   "'"
        ]

ExitProcessServer
        Push    "r1, r2, lr"                            ; Save the exit values
        LDRVC   r0, [ r8, #-4 ]                         ; Get the handle again
        [       Debug
        DREG    r0, "Abandoning handle &", cc
        DREG    r8, ", stored at &"
        ]
        SWIVC   XEconet_AbandonReceive
        MOVVS   r1, #NIL
        STRVS   r1, [ r8, #-4 ]
        MOVVC   r0, #Port_PrinterServerInquiryReply
        MOVVC   r1, #0                                  ; Any station
        MOVVC   r2, #0                                  ; Any net
        MOVVC   r3, r5                                  ; Buffer address
        MOVVC   r4, #8                                  ; Buffer size is 8
        STMVCIA r3, { r1, r2 }                          ; Zero the reception area
        SWIVC   XEconet_CreateReceive
        STRVC   r0, [ r8, #-4 ]
        Pull    "r1, r2, pc"

ProcessNameOnly ROUT
        ;       R1 is the current buffer pointer, increment by the amount used
        ;       R2 is the space remaining, decrement by the amount used
        ;       R3 is the station number
        ;       R4 is the network number
        ;       R5 is the receive buffer address and must be preserved
        ;       R8, #-4 is the address of the handle, must be preserved
        ;       R9 is the number of entries, probably incremented
        ;       R10 must be preserved
        ;       R11 is the format, must be preserved
        CMP     r2, #8                                  ; Max of PSNameSize+1 and LEN("nnn.sss")+1
        BLO     ListServersFillsBuffer
        MOV     r0, #0                                  ; Put a terminator on the name in the buffer
10
        TEQ     r0, #PSNameSize                         ; If this is the end of the name then terminate
        MOVEQ   r6, #0
        LDRNEB  r6, [ r5, r0 ]                          ; If not get the character
        CMP     r6, #" "                                ; See if we have reached the end of it yet
        MOVLE   r6, #0                                  ; If so terminate it
        STRLEB  r6, [ r5, r0 ]
        INC     r0
        BGT     %10                                     ; If not, get the next character
        TEQ     r0, #1
        BNE     %15                                     ; Non zero length, continue
        Push    "r1, r2, lr"                            ; Preserve
        Push    "r3, r4"                                ; Put arguments for conversion into RAM
        MOV     r0, sp
        MOV     r1, r5
        MOV     r2, #8
        SWI     XOS_ConvertNetStation
        INC     sp, 8
        Pull    "r1, r2, lr"
        BVS     ExitProcessServer
15
        [       Debug
        DSTRING r5
        ]
        ;       Now search the existing list for the right place to insert
        ;       If this is a repeat then don't bother
        MOV     r6, r1                                  ; Save the buffer end address
        MOV     r7, r2                                  ; And the space remaining
        MOV     r1, r5                                  ; The string entry just returned
        LDR     r2, [ sp ]                              ; The list of names returned so far
        MOV     r3, #1                                  ; OSS 5.51: ignore case, accents significant
        TEQ     r2, r6                                  ; Check for the special first case
        BEQ     %40

20
        MOV     r0, #-1                                 ; Use the current territory
        Push    "lr"
        [       Debug
        DSTRING r1, "Comparing ", cc
        DSTRING r2, " and "
        ]
        SWI     XTerritory_Collate
        [       Debug
        DREG    r0, "Returns R0 = &"
        ]
        Pull    "lr"
        BVS     ExitProcessServer
        BEQ     ExitProcessNameOnly                     ; Identical, so exit without any action
        BLT     InsertThisEntry
30
        LDRB    r0, [ r2 ], #1                          ; Now move to the next string
        TEQ     r0, #0
        BNE     %30
        CMP     r2, r6                                  ; Are we at the end of the buffer?
        BLO     %20                                     ; No, so try the next string in the buffer
40
        LDRB    r0, [ r1 ], #1                          ; If yes then copy this string to the end of the buffer
        STRB    r0, [ r6 ], #1
        DEC     r7                                      ; Alter the space remaining
        TEQ     r0, #0                                  ; Check for termination of the string
        BNE     %40
        INC     r9                                      ; We have added an entry
ExitProcessNameOnly
        MOV     r1, r6                                  ; Restore the buffer end address
        MOV     r2, r7                                  ; And the space remaining
        B       ExitProcessServer

InsertThisEntry
        ;       First we need to count the string to be inserted
        MOV     r1, r6                                  ; The current end address
        MOV     r4, r5                                  ; Begining of the string
50
        LDRB    r0, [ r4 ], #1                          ; Get char from string to insert
        INC     r1                                      ; Move end pointer
        DEC     r7                                      ; Less space left
        TEQ     r0, #0                                  ; Is it the terminator
        BNE     %50
        MOV     r3, r1                                  ; Destination for move of names after this new entry
60
        LDRB    r0, [ r6, #-1 ] !
        STRB    r0, [ r3, #-1 ] !
        TEQ     r6, r2
        BNE     %60
        MOV     r2, r7                                  ; Exit value of remaing space
        MOV     r3, r5
70
        LDRB    r0, [ r3 ], #1
        STRB    r0, [ r6 ], #1
        TEQ     r0, #0
        BNE     %70
        INC     r9                                      ; We have added an entry
        B       ExitProcessServer

ProcessGetStatus ROUT
        ;       R1 is the current buffer pointer, preserve
        ;       R2 is the space remaining, preserve
        ;       R8, #-4 is the address of the handle, must be preserved
        ;       R9 is the number of entries
        ;       R10 must be preserved
        ;       R11 is the format, must be preserved
        ;       Definition of the state record
        ^       0
        Word    State_TxHandle
        Byte    State_Name, PSNameSize                  ; This is the address transmitted
        Byte    State_Reason, 2
        Byte    State_Status, 3                         ; This is the address on the RxCB
        Byte    State_Size, 0

        CMP     r2, #PSNameSize+1+3+2
        BLO     ListServersFillsBuffer
        ADR     r7, StatusHandles
10
        LDR     r0, [ r7 ], #4
        TEQ     r0, #NIL                                ; No handle?
        BEQ     %20
        ADR     r6, ( StatusHandles + 4 * NumberOfBuffers )
        TEQ     r7, r6
        BNE     %10
        MOV     pc, lr                                  ; No spare handles

20
        Push    "r1, r2, r10, lr"
        LDR     r0, [ r8, #-4 ]                         ; Get the handle again
        [       Debug
        DREG    r0, "Reception on handle &", cc
        DREG    r8, ", stored at &", cc
        DLINE   " - 4"
        ]
        SWI     XEconet_ReadReceive                     ; Use this to get the buffer address in R5
        MOV     r6, r3                                  ; Save the station number
        MOVVC   r0, #ModHandReason_Claim
        MOV     r3, #State_Size
        SWIVC   XOS_Module
        [       Debug
        BVS     %91
        DREG    r2, "State record claimed at &"
91
        ]
        MOVVC   r0, #Port_PrinterServerInquiryReply
        ADD     r3, r2, #State_Status
        MOV     r1, r6                                  ; Station number
        MOV     r2, r4                                  ; Network number
        MOV     r4, #?State_Status
        SWIVC   XEconet_CreateReceive
        [       Debug
        BVS     %92
        DREG    r0, "Reception opened on handle &"
92
        ]
        STRVC   r0, [ r7, #-4 ]                         ; Handle for the status reception
        LDMIA   r5, { r0, r1 }                          ; Get the printer name as returned
        MOV     r10, r5                                 ; Keep the buffer address
        ADD     r4, r3, #State_Name - State_Status
        STMIA   r4, { r0, r1 }
        MOVVC   r0, #1
        STRVCB  r0, [ r4, #State_Reason - State_Name ]
        MOVVC   r0, #0
        STRVCB  r0, [ r4, #State_Reason - State_Name + 1 ]
        MOV     r1, #Port_PrinterServerInquiry
        MOV     r3, r2                                  ; Network number
        MOV     r2, r6                                  ; Station number
        MOV     r5, #?State_Name + ?State_Reason
        ADR     r6, TransmitCount
        LDMIA   r6, { r6, r7 }
        SWIVC   XEconet_StartTransmit
        [       Debug
        BVS     %93
        DREG    r0, "Transmission started on handle &"
93
        ]
        STRVC   r0, [ r2, #State_TxHandle - State_Name ]
        MOV     r5, r10                                 ; Restore the Receive buffer address
ExitProcessGetStatus
        Pull    "r1, r2, r10, lr"
        B       ExitProcessServer

ProcessServerStatus ROUT
        ;       R1 is the current buffer pointer, increment by the amount used
        ;       R2 is the space remaining, decrement by the amount used
        ;       R8, #-4 is the address of the handle, must be filled with NIL, and preserved
        ;       R9 is the number of entries, probably incremented
        ;       R10 must be preserved
        ;       R11 is the format, must be preserved
        CMP     r2, #PSNameSize+1+3+2
        BLO     ListServersFillsBuffer
        LDR     r0, [ r8, #-4 ]                         ; Get the handle again
        [       Debug
        DREG    r0, "Status reception on handle &", cc
        DREG    r8, ", stored at &", cc
        DLINE   " - 4"
        DREG    r1, "Writing record at &"
        ]
        Push    "r1, r2, lr"
        SWI     XEconet_ReadReceive                     ; Use this to get the buffer address in R5
        MOV     r1, #NIL                                ; Mark for an unused handle
        LDRVC   r0, [ r8, #-4 ]                         ; Get the handle
        STR     r1, [ r8, #-4 ]                         ; Mark the slot unused
        SWIVC   XEconet_AbandonReceive
        [       Debug
        BVS     %92
        DLINE   "Reception abandoned OK"
92
        ]
        LDRVC   r0, [ r5, #State_TxHandle - State_Status ]
        SWIVC   XEconet_AbandonTransmit
        [       Debug
        BVS     %93
        DLINE   "Transmission abandoned OK"
93
        ]
        Pull    "r1, r2, lr"
        MOVVS   pc, lr
        SUB     r7, r5, #State_Status                   ; Calculate the address for freeing later
        [       Debug
        DREG    r7, "Address of state record to free is &"
        ]
        STRB    r3, [ r1 ], #1                          ; Station number
        STRB    r4, [ r1 ], #1                          ; Network number
        LDRB    r0, [ r5 ], #1                          ; Actual status
        STRB    r0, [ r1 ], #1
        LDRB    r0, [ r5 ], #1                          ; Status station number
        STRB    r0, [ r1 ], #1
        LDRB    r0, [ r5 ], #1                          ; Status network number
        STRB    r0, [ r1 ], #1
        SUB     r2, r2, #5                              ; Account for stuff put in so far
        DEC     r5, (State_Status+3) - State_Name       ; Calculate the address of the name
10
        LDRB    r0, [ r5 ], #1                          ; Copy the name
        CMP     r0, #" "                                ; Is this a termination condition
        MOVLS   r0, #0                                  ; Yes, so terminate as expected
        STRB    r0, [ r1 ], #1
        DEC     r2                                      ; Account for the space used
        BHI     %10
        INC     r9                                      ; Add an entry
        Push    "r2, lr"
        MOV     r0, #ModHandReason_Free
        MOV     r2, r7
        SWI     XOS_Module
        Pull    "r2, pc"

AbandonReceptions ROUT
        Push    "r0, lr"
        MOV     r4, #( NumberOfBuffers - 1 )
        ADR     r1, BroadcastHandles
        ADR     r2, StatusHandles
50
        LDR     r0, [ r1 ], #4
        TEQ     r0, #NIL
        MOVNE   r14, #NIL
        STRNE   r14, [ r1, #-4 ]
        SWINE   XEconet_AbandonReceive             ; Ignoring errors
        LDR     r0, [ r2 ], #4
        TEQ     r0, #NIL
        MOVNE   r14, #NIL
        STRNE   r14, [ r1, #-4 ]
        SWINE   XEconet_AbandonReceive             ; Ignoring errors
        DECS    r4
        BPL     %50
        Pull    "r0, pc"

ConvertStatusToString
;       In:
;
;       R0  Pointer to a status value byte, followed by two optional bytes
;           containing the station and network number associated with the
;           status.
;       R1  Pointer to a buffer.
;       R2  Length of the buffer in bytes.
;
;       Out:
;
;       R0  The entry value of R1
;       R1  Pointer to the terminating zero.
;       R2  Updated to reflect the number of bytes in the buffer after the
;           terminating zero.

        ROUT
        Push    "r1-r7, lr"
        [       Debug
        DREG    r0, "Adding status from &"
        ]
        LDW     r7, r0, r6, r14
        B       DoConvertStatus

AddStatus                                               ; This entry has the status in R0
        Push    "r1-r7, lr"
        MOV     r7, r0                                  ; Keep the full status
DoConvertStatus
        [       Debug
        DREG    r7, "Adding status &"
        ]
        MOV     r0, r1                                  ; Buffer start address
        ADD     r1, r1, r2                              ; Compute buffer end address
        BL      ValidateWriteAddress
        LDMIA   sp, { r1, r2 }                          ; Restore buffer pointer and length
        BVS     StatusExit
        MOV     r6, r7, LSR #8                          ; Save the station and net number away for later
        ANDS    r0, r7, #&FF                            ; Reduce status to a byte value
        BNE     StatusIsNotReady
        [       UseMsgTrans
        ADR     r1, StatusReady
StatusLookup
        MOV     r4, #0                                  ; No substitution for %0
StatusLookupWithNumber
        LDMIA   sp, { r2, r3 }                          ; Get buffer address and length from stack
        BL      MessageTransGSLookup1
        LDR     r7, [ sp, #4 ]                          ; Original buffer length
        SUB     r6, r7, r3                              ; Calculate the remaining space in the buffer
        STR     r6, [ sp, #4 ]                          ; Exit R2
        ADD     r1, r2, r3
        |
        BL      AddString
        DCB     "ready", 0
        ALIGN
        ]
StatusExit
        [       :LNOT: UseMsgTrans
        STRVC   r2, [ sp, #4 ]
        ]
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r2-r7, pc"

StatusIsNotReady
        TEQ     r0, #Status_Busy
        BNE     StatusIsNotBusy
        [       UseMsgTrans
        ANDS    r5, r6, #&FF                            ; Get station ID of printer user
        ADREQ   r1, StatusBusy
        BEQ     StatusLookup                            ; Station number invalid
        MOV     r6, r6, LSR #8
        AND     r6, r6, #&FF                            ; Get network number
        Push    "r5, r6"
        MOV     r0, sp
        ADR     r1, StationNumberBuffer
        MOV     r2, #?StationNumberBuffer
        SWI     XOS_ConvertNetStation
        INC     sp, 8
        BVS     StatusExit
        ADR     r1, StatusBusyWithStation
        ADR     r4, StationNumberBuffer
        B       StatusLookupWithNumber
        |
        BL      AddString
        DCB     "busy", 0
        ALIGN
        BVS     StatusExit
        ANDS    r5, r6, #&FF                            ; Get station ID of printer user
        BEQ     StatusExit                              ; Station number invalid
        MOV     r6, r6, LSR #8
        AND     r6, r6, #&FF
        Push    "r5, r6"
        BL      AddString
        DCB     " with ", 0
        ALIGN
        MOVVC   r0, sp
        SWIVC   XOS_ConvertNetStation
        INC     sp, 8
        B       StatusExit
        ]
StatusIsNotBusy
        TEQ     r0, #Status_OffLine
        [       UseMsgTrans
        ADREQ   r1, StatusOffLine
        BEQ     StatusLookup
        |
        BNE     StatusIsNotOffLine
        BL      AddString
        DCB     "off line", 0
        ALIGN
        B       StatusExit
        ]
StatusIsNotOffLine
        TEQ     r0, #Status_AlreadyOpen                 ; Special status for already open
        [       UseMsgTrans
        ADREQ   r1, StatusOpen
        ADRNE   r1, StatusJammed                        ; Default
        B       StatusLookup

StatusReady
        DCB     "Ready", 0
StatusBusy
        DCB     "Busy", 0
StatusBusyWithStation
        DCB     "BusyStn", 0
StatusOffLine
        DCB     "OffLine", 0
StatusOpen
        DCB     "Open", 0
StatusJammed
        DCB     "Jammed", 0
        ALIGN
        |
        BNE     StatusIsNotAlreadyOpen
        BL      AddString
        DCB     "already open", 0
        ALIGN
        B       StatusExit

StatusIsNotAlreadyOpen
        BL      AddString
        DCB     "jammed", 0
        ALIGN
        B       StatusExit
        ]

        LTORG

        END
