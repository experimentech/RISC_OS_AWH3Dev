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
        SUBT    ==> &.Arthur.NetPrint.FileSystem

InfoBlock
        DCD     ModuleTitle - Module_BaseAddr
        DCD     0                                       ; No initialise string
        DCD     OpenStream - Module_BaseAddr
        DCD     GetByte - Module_BaseAddr
        DCD     PutByte - Module_BaseAddr
        DCD     Args - Module_BaseAddr
        DCD     CloseStream - Module_BaseAddr
        DCD     WholeFile - Module_BaseAddr
        [ OldOs
        DCD     fsinfo_special + fsinfo_nullnameok + fsnumber_netprint
        |
        DCD     fsinfo_special + fsinfo_nullnameok + fsinfo_alwaysopen + fsinfo_extrainfo + fsnumber_netprint
        ]
        DCD     FunctionEntry - Module_BaseAddr
        DCD     PutBytes - Module_BaseAddr
        [       :LNOT: OldOs
        DCD     fsextra_FSDoesCat+fsextra_FSDoesEx
        ]

WriteOnly
        Pull    lr
GetByte
        ADR     r0, ErrorWriteOnly
        [       UseMsgTrans
        B       MakeErrorWithModuleName
        |
        RETURNVS
        ]

ErrorWriteOnly
        DCD     &00010000 + &100*fsnumber_netprint + ErrorNumber_FSWriteOnly_Pre
        [       UseMsgTrans
        DCB     "FSNoRd"
        |
        DCB     ErrorString_FSWriteOnly_Pre
        DCB     ModuleName
        DCB     ErrorString_FSWriteOnly_Post
        ]
        DCB     0
        ALIGN

NotGoodEnough
        Pull    lr
        ADR     r0, ErrorUnableToDefault
        [       UseMsgTrans
        B       MessageTransErrorLookup
        |
        RETURNVS
        ]

LinkSearch ; Wander down linked list, looking for handle of R1
        ; List starts at FirstLink.
        ; Resultant record pointed to by R8
        ; Last valid record held in R11 used for deletion
        ; Trashes R0
        ; Set previous record address to a dummy so that removal works
        ADR     r11, ( FirstLink - :INDEX: Link )
        LDR     r8, FirstLink                           ; Get first one out
        TEQ     r8, #NIL                                ; Test for the special case
        BEQ     SearchFails
LinkLoop
        Push    r2
        LDR     r2, =Identifier
        LDR     r0, FCB_Identifier
        TEQ     r0, r2
        Pull    r2
        BNE     TragicErrorExit
        LDR     r0, Handle                              ; Handle is relative to R8
        CMP     r0, r1
        MOVEQ   pc, lr                                  ; Return with R8 pointing to found element
        MOV     r11, r8                                 ; Remember previous FCB address in R11
        LDR     r8, Link                                ; Get on to the next record
        TEQ     r8, #NIL                                ; If not at the end if the list, then chain down to next FCB
        BNE     LinkLoop
SearchFails
        ADR     r0, ErrorBadNetPrintHandle
        [       UseMsgTrans
        B       MessageTransErrorLookup

ErrorBadNetPrintHandle
        DCD     ErrorNumber_BadNetPrintHandle
        DCB     "Channel", 0
        ALIGN
        |
        RETURNVS                                        ; Exit with error

        Err     BadNetPrintHandle
        ]

TragicErrorExit
        ADR     r0, ErrorNetPrintInternalError
        [       UseMsgTrans
        B       MakeErrorWithModuleName

ErrorNetPrintInternalError
        DCD     ErrorNumber_NetPrintInternalError
        DCB     "Fatal", 0
        ALIGN
        |
        RETURNVS                                        ; Exit with error

        Err     NetPrintInternalError
        ]

FunctionEntry
        [       {FALSE}
        DLINE   "NetPrint - OsFunction"
        DREG    r0, "Function code                    = &"
        DREG    r1, "Address of args / First argument = &"
        DREG    r2, "Secondary argument               = &"
        DREG    r6, "Special field                    = &"
        ]
        TEQ     r0, #fsfunc_Ex
        BEQ     Examine
        TEQ     r0, #fsfunc_Cat
        BEQ     Catalog
        TEQ     r0, #fsfunc_ShutDown
        BEQ     ShutDown
        CMP     r0, #fsfunc_FileInfo                    ; This is the largest we know about
        RETURNVC HI                                     ; Anything higher, we must NOP
        ADR     r0, ErrorBadOperation
        [       UseMsgTrans
        B       MakeErrorWithModuleName
        |
        RETURNVS
        ]

ErrorBadOperation
        DCD     &00010000 + &100*fsnumber_netprint + ErrorNumber_NotSupported_Pre
        [       UseMsgTrans
        DCB     "BadFSOp"
        |
        DCB     ErrorString_NotSupported_Pre
        DCB     ModuleName
        DCB     ErrorString_NotSupported_Post
        ]
        DCB     0
        ALIGN

ShutDown
        Push    lr
        ADR     r0, ShutDownCommand
        SWI     XOS_CLI
        Pull    pc

ShutDownCommand
        =       ModuleName, ":%Close"
NullName
        =       13
        ALIGN

        LTORG

OpenStream ROUT
        ;       R0  => is the open mode
        ;       R1  => points to the name, null terminated
        ;       R3  => fileswitch internal handle
        ;       R6  => is the special field pointer
        ;       R8  <=
        ;       R11 <=
        Push    lr
        TEQ     r0, #fsopen_CreateUpdate                ; Handle OPENOUT
        TEQNE   r0, #fsopen_Update                      ; Handle OPENUP
        BNE     WriteOnly                               ; Not one of the acceptable modes of opening
        TEQ     r6, #0                                  ; Test the special field pointer
        BEQ     UseCurrent                              ; No special field
        LDRB    r0, [ r6 ]                              ; Get first character of special field
        BL      NameOrNumber                            ; Test the character
        BEQ     ParseNumber                             ; Number (as text)
        MOV     r0, r6                                  ; Pointer to passed string
OpenByName ; Passed in R0
        [ Debug :LOR: OSSDebug
        DSTRING r0, "NetPrint: Open by name: "
        ]
        BL      BindName
NameResolved
        Pull    pc, VS
        ST      r0, TempStation
        ST      r1, TempNet
        B       Connect

UseCurrent
        [ Debug :LOR: OSSDebug
        DLINE   "NetPrint: Using current value"
        ]
        LD      r8, Mode                                ; -ve means no mode, 0 means name, +ve means number
        CMP     r8, #0
        BMI     NoMode
        ADREQ   r0, CurrentName
        BEQ     OpenByName
        LD      r0, CurrentStation
        LD      r1, CurrentNetwork
        B       OpenByNumber

NoMode
        ADR     r0, NullName
        BL      BindPSName
        B       NameResolved

ParseNumber
        MOV     r1, r6
        SWI     XEconet_ReadStationNumber
        Pull    pc, VS
        CMP     r2, #-1
        CMPNE   r3, #-1
        BEQ     NotGoodEnough
        MOV     r0, r2
        MOV     r1, r3
OpenByNumber                                            ; Station in R0, R1
        [ Debug :LOR: OSSDebug
        DLINE   "NetPrint: Open by number"
        ]
        BL      MultiStreamCapable
        STRVC   r0, TempStation
        STRVC   r1, TempNet
        MOVVC   r0, #Port_PrinterServerInquiryReply
        LD      r1, TempStation                         ; Station ID of Printer Server
        LD      r2, TempNet                             ; Net ID of Printer Server
        ADR     r3, RxBuffer                            ; Puts base of buffer into R3
        MOV     r4, #?RxBuffer
        [       Debug
        DREG    r0, "  Port    ", cc
        DREG    r1, "  Station ", cc
        DREG    r2, "  Network "
        DREG    r3, "  Buffer  ", cc
        DREG    r4, "  Size    "
        DREG    r12, "  wp = &"
        ]
        SWIVC   XEconet_CreateReceive                   ; Temporary handle is returned in R0
        [       Debug
        DREG    r0, "This comes back from XEconet_CreateReceive &"
        DREG    PSR, "psr = &"
        ]
        Pull    pc, VS                                  ; Pass the error back to FileSwitch
        MOV     r10, r0                                 ; Remember RX handle in R10
        [       Debug
        DREG    r0, "CreateReceive done, with handle of &"
        ]
        MOV     r0, #0                                  ; Flag byte, with sequence bit clear
        MOV     r1, #Port_PrinterServerInquiry
        LD      r2, TempStation
        LD      r3, TempNet
        ADRL    r4, PrintStr                            ; Points R4 at "PRINT " instruction to PS
        MOV     r5, #8                                  ; Size
        ADR     r6, TransmitCount
        LDMIA   r6, { r6, r7 }
        BL      DoTransmit
        BLVS    AbandonR10                              ; If an error, then abandon the receive block
        BLVC    WaitForReception
        Pull    pc, VS                                  ; Pass the error back to FileSwitch
        LDRB    r0, [ r5 ]                              ; Get status from buffer
        ANDS    r0, r0, #2_00000111                     ; Reduce to the size of the printer status field
        BEQ     Connect
        [       UseMsgTrans
        LDR     r1, [ r5 ]                              ; Station number if busy with ...
        Push    "r0-r11"
        ADR     r8, ErrorPrStat
        LDRB    r11, [ r5 ]                             ; Basic status
        LD      r0, TempStation
        ORR     r11, r11, r0, LSL #8
        LD      r0, TempNet
        ORR     r11, r11, r0, LSL #16
        B       ConnectErrorExit

ErrorPrStat
        DCD     ErrorNumber_NetPrinterBusy
        DCB     "PrStat", 0
        ALIGN
        |
        TEQ     r0, #1
        ADREQ   r0, ErrorNetPrinterBusy                 ; Could do better here
        BEQ     StatusNoGood
        TEQ     r0, #6
        ADREQ   r0, ErrorNetPrinterOffLine
        ADRNE   r0, ErrorNetPrinterJammed
StatusNoGood
        SETV
        Pull    pc

        Err     NetPrinterBusy
        Err     NetPrinterOffLine
        Err     NetPrinterJammed
        ]

; OSS 5.50 Error if connection is to old machine type hardware and a new
; server is running on this machine.

        [       UseMsgTrans
ErrorNetOldServer
        DCD     ErrorNumber_NetOldServer
        DCB     "OldServ", 0
        ALIGN
        |
        Err     NetOldServer
        ]

Connect ROUT ; The number is decided, and the status is OK
        MOV     r0, #ModHandReason_Claim
        LDR     r3, =( :INDEX: RecordSize )
        SWI     XOS_Module
        Pull    pc, VS
        MOV     r8, r2                                  ; Put address of record in the usual register
        LDR     r0, =Identifier
        STR     r0, FCB_Identifier
        LD      r0, TempStation
        LD      r1, TempNet
        [       Debug
        BREG    r1, "Station ", cc
        BREG    r0, "."
        ]
        ST      r0, Station
        ST      r1, Network
        ST      r8, Handle                              ; Save handle for FileSwitch
        [       Debug
        DREG    r2, "Workspace claimed at &"
        ]
        MOV     r2, #0                                  ; Valid initialisation of the Flag byte
        ST      r2, Flag
        ST      r2, Buffer                              ; No Buffer yet
        ST      r2, FileExt                             ; Start at beginning of PSBuffer

        LD      r3, FirstLink                           ; Get the address of the rest of the chain
        ST      r3, Link
        ST      r8, FirstLink
        ADR     r11, ( FirstLink - :INDEX: Link )       ; Remember in R11 for WholeFile
        MOV     r0, #Port_PrinterServerData             ; Start talking to printer
        ST      r0, DataPort                            ; Update my buffer, as all talking is now done
        MOV     r0, #(Feature_NewReplyPort :OR: Feature_DataPort) ; OSS: new reply port and data port
        ST      r0, Features                            ; Features we are going to try for

; OSS 5.50: From this point on, errors should branch to RemoveRecord since that
; will remove the control block from the chain and free the memory.

; OSS 5.50 SJ Research. There is a problem with the negotiation of the features
; byte. The SJ Research MDFS is so backwards compatible, it supports versions
; of the BBC B NFS before 3.60. Thus it takes a jobstart byte of 0 as meaning
; "new" protocol (ie. flag byte used to terminate job) and a jobstart byte of
; 2 (CTRL-B) as meaning "old" protocol ie. a data byte of 3 (CTRL-C) terminates
; the job. A jobstart byte of 1 slips through the net and is treated as 0, but
; anything greater that 2 is treated as invalid and the print job fails to
; start. The only sensible way round this I can think of is to do a machine
; type peek of the printer server, and only if it is an Archimedes, Risc PC
; or as yet unallocated type do we try to do features negotiation. Thus
; only !Spooler and SJ's !PrintJunr and !PrintServ need to be tested for
; features negotiation. Also note that the MDFS does not allow zero length
; jobstart packets, despite all versions of the protocol specification I have
; seen saying zero length is valid.

; OSS 5.51 SJ Research. Sigh, the vagaries of the different transport stacks
; is driving me potty. Local loopback does not work for immediate operations
; on hardware Econet. Hence if we are trying to print to the local machine
; then don't do the machine type peek. This is safe, since we know that
; we are an Archimedes or Risc PC.

        SWI     XEconet_ReadLocalStationAndNet          ; R0 = stn, R1 = net
        BVS     RemoveRecord                            ; Tidy up and return error
        LD      r2, Station                             ; Destination station
        LD      r3, Network                             ; Destination net

        TEQ     r2, r0
        BNE     mach_peek                               ; Station numbers don't match, so do peek
        TEQ     r3, #0                                  ; Net number is zero (local)
        TEQNE   r3, r1                                  ; or number matches (local)
        BEQ     mach_done                               ; so don't do peek

mach_peek
        MOV     r0, #Econet_MachinePeek
        MOV     r1, #0                                  ; Address/procedure number (for paranoia)
        ADR     r4, InstanceRxBuffer                    ; Convenient buffer (need 4 bytes)
        MOV     r5, #?InstanceRxBuffer                  ; Length of buffer
        LD      r6, MachinePeekCount
        LD      r7, MachinePeekDelay
        SWI     XEconet_DoImmediate                     ; Returns R3=Stn R4=Net
        BVS     RemoveRecord                            ; Tidy up and return error

        CMP     r0, #Status_Transmitted                 ; Check success and clear V
        MOVNE   r1, #0                                  ; Use MessageTrans buffer
        SWINE   XEconet_ConvertStatusToError
        BVS     RemoveRecord                            ; Tidy up and return error

        LDRB    r0, [r2, #0]                            ; R0 = low byte
        LDRB    r1, [r2, #1]                            ; R1 = high byte
        [       OSSDebug :LOR: Debug
        BREG    r1, "NetPrint: machine type high &", cc
        BREG    r0, " low &"
        ]
        TEQ     r1, #&FF                                ; Check for SJ Research high byte
        BNE     mach_not_sj
        CMP     r0, #&F8                                ; From &F8 to &FF are defined for SJ
        MOVHS   r3, #0                                  ; so don't try for any features
        ST      r3, Features, HS
        B       mach_done
mach_not_sj
        TEQ     r1, #0                                  ; Check for Acorn high byte
        BNE     mach_done                               ; if not Acorn then try full features
        CMP     r0, #0                                  ; 0 is reserved
        CMPNE   r0, #7                                  ; 7 is Archimedes
        CMPNE   r0, #8                                  ; 8 is reserved
        CMPNE   r0, #15                                 ; Risc PC = 15, above = undefined
        MOVLO   r3, #0                                  ; if <15 and not 8,7,0 then no features
        ST      r3, Features, LO
mach_done

; OSS SJ Research. If the service call is claimed, then there is a printer server listening
; on port &D1 on this machine. In this case it is essential that we (NetPrint) don't also
; listen on port &D1 because we would get each other's data. This means that an Archimedes
; running a printer server cannot print to old printer servers on other machines which only
; send replies on port &D1 (eg. !Spooler). Printing to an SJ Research printer server on
; another Archimedes or printing to an SJ Research MDFS version 1.20 or later is fine
; because they send replies on port &D0.

; If the service call is not claimed, there is no printer server running and hence it is
; safe to listen on port &D1 as well as port &D0. Hence a machine which is not itself
; running a printer server can print to both old and new style servers. This is as
; much backwards compatibility as can be achieved.

; We actually fudge it a bit - we always put two listens up to keep the code simpler.
; Sometimes both of the listens are on port &D0 but this does not matter.

        LDR     r1, =Service_NetPrintCheckD1            ; OSS: Check if local server listening on port &D1
        SWI     XOS_ServiceCall
        BVS     RemoveRecord                            ; Tidy up and return error
        TEQ     r1, #Service_Serviced                   ; See if it was claimed
        MOVEQ   r0, #Port_PrinterServerDataReply        ; Yes, so must only use &D0
        MOVNE   r0, #Port_PrinterServerData             ; No, so one listen on port &D1

; OSS 5.50: Check if features byte indicates old server. If it
; does and the service was claimed, then the connection is gauranteed to
; fail since we will only listen on port &D0 and the server will only reply
; on port &D1 so we might as well give an error now saying so.

        LD      r3, Features, EQ
        TEQEQ   r3, #0                                  ; If service claimed, check if no features
        ADREQ   r0, ErrorNetOldServer                   ; Get error block or token
        [       UseMsgTrans
        BLEQ    MessageTransErrorLookup                 ; Lookup the error
        |
        SETV    EQ                                      ; Set V flag for error
        ]       ; UseMsgTrans
        BVS     RemoveRecord                            ; Tidy up and return error

; OSS: This receive is on either port &D1 or port &D0.

        [       OSSDebug :LOR: Debug
        BREG    r0, "NetPrint: Listening on port &D0 and &"
        ]
        LD      r1, Station
        LD      r2, Network
        ADR     r3, InstanceRxBuffer                    ; Puts base of buffer into R3
        MOV     r4, #?InstanceRxBuffer                  ; Length of buffer
        SWI     XEconet_CreateReceive
        BVS     RemoveRecord                            ; Tidy up and return error
        MOV     r10, r0                                 ; Keep RX handle in R10 for a while

; OSS: Now post receive which is definitely on port &D0.

        MOV     r0, #Port_PrinterServerDataReply        ; OSS: New reply port
        LD      r1, Station
        LD      r2, Network
        ADR     r3, InstanceRxBufferD0                  ; Puts base of buffer into R3
        MOV     r4, #?InstanceRxBufferD0                ; Length of buffer (two)
        SWI     XEconet_CreateReceive
        BLVS    AbandonR10                              ; OSS: If an error, then abandon the receive block
        BVS     RemoveRecord                            ; Tidy up and return error
        MOV     r9, r0                                  ; Keep RX handle in R9 for a while

; OSS: Now do the connect, trying for as many new features as possible.
; While the receives are open, errors should call AbandonR9R10 and then
; branch to RemoveRecord.

        MOV     r0, #2_01000010                         ; Flag byte, with sequence bit clear
        LD      r1, DataPort
        LD      r2, Station
        LD      r3, Network
        ADR     r4, Features                            ; OSS 5.50 features from machine peek
        MOV     r5, #1                                  ; Size of buffer to send
        ADR     r6, TransmitCount
        LDMIA   r6, { r6, r7 }                          ; Count and delay
        ADR     r14, TxStuff
        STMIA   r14, { r0-r7 }                          ; Store away all the registers
        BL      DoTransmit                              ; Calls XEconet_DoTransmit
        BLVS    AbandonR9R10                            ; OSS: If an error, then abandon the receive blocks
        BVS     RemoveRecord                            ; Tidy up and return error
        [       Debug
        DREG    r0, "Jobstart has been sent on port &D1 succesfully "
        ]

; OSS: We now need to poll the R9 and R10 RxCBs alternately until one of them completes
; or we timeout or the user presses Escape.

        SWI     XOS_ReadMonotonicTime                   ; Get current time
        BLVS    AbandonR9R10
        BVS     RemoveRecord                            ; Tidy up and return error
        LDR     r7, ReceiveDelay                        ; Delay before giving up
        ADD     r7, r7, r0                              ; Remember time to expire at

PollR9R10
        MOV     r0, r9                                  ; Definitely &D0 RxCB
        SWI     XEconet_ReadReceive
        BLVS    AbandonR9R10
        BVS     RemoveRecord                            ; Tidy up and return error
        TEQ     r0, #Status_Received
        BEQ     GotOneR9R10

        MOV     r0, r10                                 ; Either &D0 or &D1 RxCB
        SWI     XEconet_ReadReceive
        BLVS    AbandonR9R10
        BVS     RemoveRecord                            ; Tidy up and return error
        TEQ     r0, #Status_Received
        BEQ     GotOneR9R10

; OSS: Didn't get one this time. See if Escape has been pressed.

        SWI     XOS_ReadEscapeState                     ; See if Escape has been pressed
        BLVS    AbandonR9R10
        BVS     RemoveRecord                            ; Tidy up and return error
        BCC     NotEscapeR9R10                          ; Escape has not been pressed

; OSS: User pressed Escape. Acknowledge it and return an error to FileSwitch.

        BL      AbandonR9R10                            ; Ignore errors
        MOV     r0, #OsByte_AcknowledgeEscape
        SWI     XOS_Byte
        BVS     RemoveRecord                            ; Tidy up and return error

        MOV     r0, #Status_Escape
        MOV     r1, #0                                  ; No error buffer (so no len in R2)
        SWI     XEconet_ConvertStatusToError            ; Always sets V flag
        B       RemoveRecord                            ; Tidy up and return error

; OSS: See if we have timed out yet. We drop into USR mode to read the time to allow
; callbacks to go off.

NotEscapeR9R10
        WritePSRc USR_mode,r3                           ; Enable all interrupts and go to user mode
        SWI     XOS_ReadMonotonicTime
        MOVVC   r3, #0                                  ; Record no error state
        MOVVS   r3, r0                                  ; Record error
        SWI     XOS_EnterOS                             ; Get back to SVC mode
        BLVS    AbandonR9R10
        BVS     RemoveRecord                            ; Tidy up and return error
        CMP     r3, #0                                  ; Test of the error, clears V
        MOVNE   r0, r3                                  ; There was an error
        SETV    NE                                      ; So go to the error state
        BLVS    AbandonR9R10
        BVS     RemoveRecord                            ; Tidy up and return error

        CMP     r0, r7                                  ; See if need to give up yet
        BLO     PollR9R10                               ; Go round for another try

; OSS: Timed out. Abort the RxCBs, and construct a "No reply" error.

        BL      AbandonR9R10                            ; Ignore errors
        MOV     r0, #Status_NoReply
        MOV     r1, #0                                  ; No error buffer (so no len in R2)
        LD      r3, Station
        LD      r4, Network
        SWI     XEconet_ConvertStatusToError            ; Always sets V flag
        B       RemoveRecord                            ; Tidy up and return error


; OSS 5.49: If the reply came in on port &D0 then check the mode or protocol control bits.
; If they are incorrect, then we have picked up a duplicate data packet acknowledge from a
; previous print job, the most frequent one being the end of job packet.
; On port &D1 we cannot make this test because we cannot be certain
; that old servers follow the spec and reply with mode bits of either 2_01 or 2_10.

GotOneR9R10
        TEQ     r2, #Port_PrinterServerDataReply
        BNE     OK_R9R10
        AND     r14, r1, #2_00000110                    ; Get the protocol type bits
        TEQ     r14, #2_00000100                        ; Big packets
        TEQNE   r14, #2_00000010                        ; Small packets
        BEQ     OK_R9R10                                ; Mode bits are acceptable

; OSS 5.49: Got a bogus packet, probably a duplicate acknowledge. Need to repost
; this receive and go back for another look.

        [       OSSDebug :LOR: Debug :LOR: DuplicateDebug
        BREG    r2, "**NetPrint: Bad flag byte reply on port &"
        ]
        MOV     r0, r2                                  ; Port number
        MOV     r1, r3                                  ; Station number
        MOV     r2, r4                                  ; Net number
        MOV     r3, r5                                  ; Buffer address
        ADR     r6, InstanceRxBuffer                    ; Base of one of the buffers
        TEQ     r3, r6                                  ; See if that is the one we have reposted
        MOVEQ   r4, #?InstanceRxBuffer                  ; This one, so use its length
        MOVNE   r4, #?InstanceRxBufferD0                ; Other buffer, so use that one's length
        SWI     XEconet_CreateReceive
        BLVS    AbandonR9R10
        BVS     RemoveRecord                            ; Tidy up and return error

        TEQ     r3, r6                                  ; Check if port &D1 receive or not
        MOVEQ   r10, r0                                 ; Yes, so remember handle in R10
        MOVNE   r9, r0                                  ; No, so remember handle in R9
        B       PollR9R10


; OSS: One of them worked. Which RxCB worked is not important, but what is important is
; which port number it came in on. We also remember the features byte and sort out
; which reply port and which data port to use.

; OSS 5.50: From this point on, errors should branch to BufferClaimError since that
; will send a job end packet to the server and then tidy up.

OK_R9R10
        ST      r2, ReplyPort                           ; All replies on this port from now on
        TEQ     r2, #Port_PrinterServerDataReply        ; If port &D0 then returned features byte is valid
        LDREQB  r14, [r5]                               ; Get combined features from reply packet
        MOVNE   r14, #0                                 ; Reply on &D1, so there are no features
        ST      r14, Features                           ; Remember features for this connection

        [       OSSDebug :LOR: Debug
        BREG    r2, "NetPrint: Reply on port &"
        BREG    r1, "NetPrint: Control byte returned &"
        BREG    r14, "NetPrint: Features byte &"
        ]

        TST     r14, #Feature_DataPort                  ; OSS 5.49: check if data port is in use
        LD      r14, DataPort
        LDRNEB  r14, [r5, #1]                           ; OSS 5.49: get data port from reply packet
        CMP     r6, #2                                  ; OSS 5.49: check length is at least 2
        ST      r14, DataPort, HS                       ; OSS 5.49: store new port if at least 2 bytes

        [       OSSDebug :LOR: Debug
        BREG    r14, "NetPrint: Data on port &"
        ]

        BL      AbandonR9R10                            ; Get rid of both RxCBs
        SWIVC   XOS_ReadMonotonicTime
        BVS     BufferClaimError                        ; Send job end, tidy up, and return error
        STR     r0, LastAckTime                         ; OSS 5.46: Remember time of last "ack"

        BIC     r3, r1, #2_00000110                     ; Clear the protocol type bits
        EOR     r3, r3, #2_00000001                     ; Flip sequence bit
        BIC     r0, r3, #2_10000001                     ; Leave only the domain id
        TEQ     r0, #2_01000000                         ; Is it un-altered
        BICEQ   r3, r3, #2_01111000                     ; Clear out the domain id it is duff
        ST      r3, Flag
        AND     r3, r1, #2_00000110                     ; Get the protocol type bits
        TEQ     r3, #2_00000100                         ; Is this the new, fast, big, type server?
        MOV     r3, #SmallBufferSize                    ; Old style small buffer type server
        BNE     SetBufferSize
        ADR     r0, Station
        LDMIA   r0, { r0, r1 }                          ; Get the station and network numbers
        SWI     XEconet_PacketSize                      ; OSS 5.47: set the X bit as God intended
        MOVVC   r3, r2                                  ; Any error means use small buffers
SetBufferSize
        STR     r3, BufferSize
        [       Debug
        DREG    r3, "Buffer size chosen is &"
        ]
        MOV     r0, #ModHandReason_Claim                ; Get a buffer
        SWI     XOS_Module
        BVS     BufferClaimError                        ; Send job end, tidy up, and return error
        STR     r2, Buffer
        [       Debug
        DREG    r0, "Printer Server now fully opened "
        ]
        MOV     r0, #fsopen_WritePermission + fsopen_UnbufferedGBPB
        LD      r1, Handle                              ; Get FileSwitch handle back
        MOV     r2, #0                                  ; I'll do the buffering
        ST      r2, FileExt                             ; Start at beginning of PSBuffer
        CLRV
        ; R0 is the returned information word
        ; R1 is the returned handle (zero for not found)
        ; R2 is zero for unbuffered (by fileswitch)
        Pull    "pc"

BufferClaimError
        ADR     r1, InstanceRxBufferD0                  ; Give it some buffer to send the stream end char
        ST      r1, Buffer                              ; This will fail when free'd, but this is OK
        MOV     r1, #?InstanceRxBufferD0
        ST      r1, BufferSize
        Push    r0                                      ; Preserve the original error
        BL      CloseAndDie
        SETV
        Pull    "r0, pc"

CloseStream
        [       Debug
        DLINE   "NetPrint - Close"
        DREG    r1, "Handle = &"
        ]
        Push    lr
        BL      LinkSearch                              ; Establish context, based upon handle in R1
        Pull    lr
        MOVVS   pc, lr                                  ; Return to FileSwitch, if an error occurred
CloseAndDie                                             ; This entry used from ShutDown and WholeFile
        Push    lr
JustClose
        ;       R8  => Pointer to the record to close
        ;       R11 => Pointer to the record before the record to close
        ;       R8  <= Pointer to the record after the one just closed
        ;       Trashes; R0, R1, R2, R3, R4, R5, R6, R10
        [       Debug
        DREG    r8, "Closing record at &"
        ]
        MOV     r10, #3                                 ; Terminator for print file
        LD      r2, Flag
        ORR     r2, r2, #2_00000110                     ; Close stream
        ST      r2, Flag
        BL      SendChar                                ; Which might also flush the buffer, small chance
        [       Debug
        DLINE   "SendChar returns"
        ]
        BVS     RemoveRecord
        LD      r2, FileExt
        TEQ     r2, #0                                  ; See if there is anything still buffered
        BLNE    FlushFile                               ; Will use ending flag set up above
RemoveRecord ROUT
        [       Debug
        DREG    r11, "Previous record is at &"
        DREG    r8,  "Current  record is at &"
        ]
        MOV     r10, #0                                 ; Set the error state, no error
        MOVVS   r10, r0                                 ; Save the previous error state, if there was one
        LD      r14, Link                               ; Get next file, to rejoin chain
        STR     r14, [ r11, #:INDEX: Link ]             ; Put current link into previous
        Push    r14                                     ; Next entry in the chain is the record to return
        MOV     r0, #ModHandReason_Free                 ; Free up the data buffer
        LDR     r2, Buffer
        CMP     r2, #0                                  ; Is there a buffer to free? (Clears V)
        [       Debug
        BEQ     %83
        DREG    r2, "Freeing buffer at &"
83
        ]
        SWINE   XOS_Module                              ; Yes, so do it
        TEQ     r10, #0
        BNE     FreeInstance
        MOVVS   r10, r0                                 ; Save this (new) error
FreeInstance
        MOV     r0, #ModHandReason_Free                 ; Free up the instance record
        MOV     r2, r8                                  ; Record to free
        [       Debug
        DREG    r2, "Freeing instance at &"
        ]
        SWI     XOS_Module
        TEQ     r10, #0
        BNE     ExitRemoveRecord
        MOVVS   r10, r0                                 ; Save this (new) error
ExitRemoveRecord
        MOVS    r0, r10                                 ; Have we ever had an error?
        SETV    NE                                      ; Yes, so indicate
        Pull    "r8, pc"                                ; Return next entry in the chain in R8

Args    ROUT                                            ; OS_Args
        [       Debug
        DLINE   "NetPrint - Args"
        BREG    r0, "Function = &"
        DREG    r1, "Handle &"
        ]
        MOV     r9, lr
        MOV     r7, r0                                  ; Preserve the reason code
        BL      LinkSearch                              ; Establish context, based upon handle in R1
        MOVVS   pc, r9                                  ; Return to FileSwitch, if an error occurred
        CMP     r7, #(EndOfArgsJumpTab-ArgsJumpTab)/4
        ADDCC   pc, pc, r7, LSL #2                      ; Jump via jump table to correct routine
        B       UnknownArg

ArgsJumpTab
        B       ReadPTR
        B       SetPTR
        B       ReadEXT
        B       SetEXT
        B       ReadSize
        B       EOFCheck
        B       Flush
        B       EnsureSize
        B       WriteZeroes
        B       ReadLoadExec
EndOfArgsJumpTab

UnknownArg
        RETURNVC                                        ; NOP unknown operations

        ASSERT  fsargs_ReadLoadExec=((EndOfArgsJumpTab-ArgsJumpTab)/4)-1

ReadLoadExec
        MOV     r3, #0
ReadPTR
ReadEXT
ReadSize
EnsureSize
        MOV     r2, #0
SetPTR
SetEXT
WriteZeroes
ArgsGoodExit
        CLRV
ArgsExit
        [ Debug
        DLINE "NetPrint - Args - Exit"
        ]
        MOV     pc, r9

EOFCheck
        MOV     r2, #1                                  ; Nonzero means at the end of the file
        B       ArgsGoodExit

Flush
        BL      FlushFile
        B       ArgsExit

PutByte ROUT
        MOV     r10, r0                                 ; Preserve the byte
        ; Chain down through linked list, looking for handle match against R1
        MOV     r2, lr
        BL      LinkSearch                              ; Leave R8 pointing to correct file
        MOV     lr, r2
        MOVVS   pc, lr
SendChar
        Push    lr
        ADR     r2, Buffer
        LDMIA   r2, { r2-r3 }                           ; Load up the address of the buffer and the current extent
        [       Debug
        BREG    r10, "SendChar puts character &", cc
        DREG    r3, " at extent &"
        ]
        STRB    r10, [ r2, r3 ]                         ; Holds byte to send
        INC     r3
        ST      r3, FileExt
        BL      check_time_flush                        ; OSS 5.46: check for timeout or full packet
        Pull    pc

WholeFile
        TEQ     r0, #fsfile_Load
        Push    lr, EQ
        BEQ     WriteOnly
        TEQ     r0, #fsfile_Save
        BEQ     SaveFile
        CMP     r0, #fsfile_ReadInfoNoLen
        MOVLS   r0, #0                                  ; Only return a parameter for known reason codes
        RETURNVC                                        ; Return zero for 'No object'

SaveFile                                                ; Print whole file from R4 to R5
        CMP     r4, r5
        MOVEQ   pc, lr                                  ; Test for null file
        Push    "r4, r5, lr"
        MOV     r0, #1                                  ; Means "Create file"
        BL      OpenStream                              ; Opens a stream to the printer server
        Pull    "r4, r5"
        Pull    pc, VS                                  ; Bubble error up if there was one
        MOV     r9, r4                                  ; Start address
        MOV     r10, r4                                 ; Current address
        LDR     r7, Buffer                              ; Save the buffer to free later
        MOV     r0, #NetFS_StartSave
        SUB     r1, r5, r9                              ; Length
        BL      DoUpCall
        BVS     ErrorInSave
WholeLoop
        [       Debug
        DREG    r9,  "Start address   = &"
        DREG    r10, "Current address = &"
        DREG    r5, "End address     = &"
        ]
        STR     r10, Buffer                             ; Where to start this send from
        SUB     r14, r5, r10                            ; Data remaining
        LD      r6, BufferSize
        CMP     r14, r6                                 ; Is this bigger than the buffer
        MOVGT   r14, r6                                 ; If so use only one buffer's worth
        [       Debug
        DREG    r14, "Send size       = &"
        ]
        STR     r14, FileExt                            ; Show how much to send
        ADD     r10, r10, r14                           ; Set the next start position
        Push    r5
        BL      FlushFile
        Pull    r5
        MOVVC   r0, #NetFS_PartSave
        SUBVC   r1, r10, r9
        BLVC    DoUpCall
        BVS     ErrorInsideSave
        TEQ     r10, r5                                 ; Have we finished yet
        BNE     WholeLoop
        ST      r7, Buffer                              ; Restore the original buffer
        MOV     r14, #1                                 ; This is all that's needed
        ST      r14, BufferSize
        MOV     r14, #0
        ST      r14, FileExt
        MOV     r0, #NetFS_FinishSave
        BL      DoUpCall
        B       JustClose                               ; And return to FileSwitch

ErrorInsideSave
        Push    r0
        MOV     r0, #NetFS_FinishSave
        BL      DoUpCall
        Pull    r0
ErrorInSave
        Push    r0
        BL      CloseAndDie
        Pull    "r0, lr"
        RETURNVS

PutBytes
        ;       Entry from FileSwitch
        ;       R0 => Reason Code
        ;       R1 => Handle
        ;       R2 => Start address
        ;       R3 => Number of bytes to Put
        ;       R4 => FilePointer to put at (ignored)
        ;       R0 <= Preserved
        ;       R1 <= Preserved
        ;       R2 <= Updated
        ;       R3 <= Number of bytes not transferred
        ;       R4 <= Updated
        Push    lr
        TEQ     r0, #OSGBPB_WriteAtGiven
        TEQNE   r0, #OSGBPB_WriteAtPTR
        BNE     WriteOnly
        Push    "r0-r1"                                 ; Preserve for exit
        BL      LinkSearch
        BVS     ExitPutBytesEarly
        [       Debug
        DREG    r8, "PutBytes to record at &", cc
        LDR     r14, Buffer
        DREG    r14, ", buffer is at &"
        DREG    r3, "Put &", cc
        DREG    r2, " bytes from &"
        ]

        LD      r9, Buffer
        ;       Copy bytes into the existing buffer until it fills, send it
        ;       Send whole buffer-fulls direct from the transfer address
        ;       Copy any remaining bytes to the buffer
        LD      r10, BufferSize                         ; Keep this constant value
        LD      r0, FileExt
        SUB     r1, r10, r0                             ; Calculate the space remaining
        CMP     r3, r1
        BLS     FinishPutBytes                          ; It will fit
        [       Debug
        DLINE   "Start"
        ]
StartLoop
        LDRB    r14, [ r2 ]                             ; Get byte from user
        STRB    r14, [ r9, r0 ]                         ; Put into local buffer
        INC     r0                                      ; Move along the buffer
        INC     r2                                      ; Update for output
        DEC     r3                                      ; Update for output
        INC     r4                                      ; Update for output
        TEQ     r0, r10                                 ; Are we at the end yet?
        BNE     StartLoop
        ST      r0, FileExt
        Push    "r2, r3, r4"
        BL      FlushFile
        Pull    "r2, r3, r4"
        BVS     ExitPutBytes
        [       Debug
        DLINE   "Middle"
        ]
MiddleLoop
        CMP     r3, r10
        BLO     FinishPutBytes
        ST      r2, Buffer
        ST      r10, FileExt
        Push    "r2, r3, r4"
        BL      FlushFile
        Pull    "r2, r3, r4"
        BVS     ExitPutBytes
        ADD     r2, r2, r10
        SUBS    r3, r3, r10
        ADD     r4, r4, r10
        BEQ     ExitPutBytes
        B       MiddleLoop

FinishPutBytes
        [       Debug
        DLINE   "Finish"
        ]
        LD      r0, FileExt
        MOV     r1, #0
        ST      r9, Buffer
FinishLoop
        LDRB    r14, [ r2 ]                             ; Get byte from user
        STRB    r14, [ r9, r0 ]                         ; Put into local buffer
        INC     r0                                      ; Move along the buffer
        INC     r2                                      ; Update for output
        DECS    r3                                      ; Update for output
        INC     r4                                      ; Update for output
        BNE     FinishLoop
        ST      r0, FileExt
ExitPutBytes
        [       Debug
        DLINE   "Exit"
        ]
        ST      r9, Buffer
        BL      check_time_flush                        ; OSS 5.46: check for full buffer/time expiry
ExitPutBytesEarly
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r1, pc"


; OSS New subroutine. This will send the buffer either if it is full
; or if more than a minute has passed since we got the acknowledge
; for the previous packet. This is to prevent problems with servers
; timing out in the case that the dot matrix printer drivers spend
; a long time rendering white space and just keep dribbling carriage
; returns into our 1280 byte buffer.

check_time_flush Entry "r0-r6"
        LD      r0, FileExt
        LD      r14, BufferSize
        TEQ     r0, r14
        BEQ     %FT50

; Buffer not full, so check last ack time.

        SWI     XOS_ReadMonotonicTime
        BVS     %FT95
        LD      r14, LastAckTime
        SUB     r0, r0, r14
        LDR     r1, =(60 * 100)                         ; One minute
        CMP     r0, r1
        EXIT    LO

; Either the buffer is full or it is more than a minute since we got the
; ack for the last packet, so send the data.

50      BL      FlushFile
95      STRVS   r0, [sp]
        EXIT

        LTORG


FlushFile
        Push    "r7, r10, lr"
        LD      r0, ReplyPort                           ; Continue talking to printer on the PrinterPort
        LD      r1, Station
        LD      r2, Network
        ADR     r3, InstanceRxBuffer                    ; Puts base of buffer into R3
        MOV     r4, #?InstanceRxBuffer                  ; Size
        SWI     XEconet_CreateReceive
        BVS     ExitFlush                               ; Back to FileSwitch
        MOV     r10, r0                                 ; Preserve RX handle in R10
        ADR     r0, TxStuff
        LDMIA   r0, {r0 - r7}                           ; Load up all the registers
        MOV     r14, #0
        ST      r14, FileExt
        BL      DoTransmit                              ; Calls XEconet_DoTransmit
        BLVS    AbandonR10                              ; If an error, then abandon the receive block
        [       OSSDebug
        DLINE   "NetPrint: TX done, waiting for ack"
        ]
        [       Debug
        DREG    r0, "Done transmit "
        BVC     %98
        DREG    r0, "And an error was reported "
        B       %99
98
        DREG    r0, "About to wait for reception "
99
        ]

; OSS SJ Research. Waiting for the reply packet is not as simple as it was. If the reply
; is on port &D0, then the bottom 3 bits of the byte in the reply is a status. Status_Ready
; is as before ie. the next packet may be sent. Status_Busy means that the server has not
; crashed, but it can't accept another packet yet so we wait all over again. Other values
; should not be sent. At the moment they are treated as Status_Ready.

FlushBusy
        BLVC    WaitForReception
        BVS     ExitFlush                               ; Back to FileSwitch
        TEQ     r2, #Port_PrinterServerDataReply        ; Check if reply came in on new port
        BNE     FlushFinished                           ; No, so just accept things

; OSS 5.50: The spec says that on the new reply port, the ack packet must always have
; the same flag byte as the data packet it was for. We can therefore use this to discard
; duplicate ack packets from the previous data packet since they have a different
; sequence bit.

        LD      r14, Flag
        TEQ     r14, r1                                 ; Check flag byte matches
        [       Debug :LOR: OSSDebug :LOR: DuplicateDebug
        BEQ     flush_nodup
        BREG    r1, "**NetPrint: ignoring duplicate ack, flag &"
        B       flush_repost
flush_nodup
        |
        BNE     flush_repost                            ; If not, post another receive and wait
        ]


; Now check the status byte in the ack packet to see what the server is saying.

        TEQ     r6, #1                                  ; OSS 5.50: Check we got one byte of reply
        BNE     flush_repost                            ; No, so something went wrong so repost
        LDRB    r0, [r5]                                ; Get byte from packet
        AND     r0, r0, #2_00000111                     ; and get status from bottom 3 bits
        [       Debug :LOR: OSSDebug
        BREG    r0, "NetPrint: reply status of &"
        ]
        TEQ     r0, #Status_Busy                        ; Check if need to wait again
        BNE     FlushFinished

; OSS SJ Reseach. Now need to post another receive to wait for the next reply.
; There is of course a window here where we have no receive up. We rely
; on the window not being very large and on the server doing retries.

flush_repost
        MOV     r0, r2                                  ; Port of last receive
        MOV     r1, r3                                  ; Station number
        MOV     r2, r4                                  ; Net number
        ADR     r3, InstanceRxBuffer                    ; Puts base of buffer into R3
        MOV     r4, #?InstanceRxBuffer                  ; Size
        SWI     XEconet_CreateReceive
        BVS     ExitFlush                               ; Back to FileSwitch
        MOV     r10, r0                                 ; Preserve RX handle in R10
        B       FlushBusy

; OSS Finished waiting, so flip sequence bit and return to FileSwitch.

FlushFinished
        LD      r1, Flag
        EOR     r1, r1, #1                              ; Flip sequence bit
        ST      r1, Flag
        SWI     XOS_ReadMonotonicTime
        STRVC   r0, LastAckTime                         ; OSS 5.46: Store time of last ack if no error
ExitFlush
        Pull    "r7, r10, pc"

DoBroadcast
        MOV     r2, #&FF
        MOV     r3, #&FF
        MOV     r5, #8                                  ; Size
        MOV     r6, #5                                  ; Count
        MOV     r7, #5                                  ; Delay
DoTransmit
        [       Debug
        DREG    r0, "  Flag    ", cc
        DREG    r1, "  Port    ", cc
        DREG    r2, "  Station "
        DREG    r3, "  Net     ", cc
        DREG    r4, "  Buffer  ", cc
        DREG    r5, "  Size    "
        DREG    r6, "  Count   ", cc
        DREG    r7, "  Delay   "
        ]
        Push    lr
        SWI     XEconet_DoTransmit
        Pull    pc, VS
        TEQ     r0, #Status_Transmitted
        B       ExitConvertingStatusToError

WaitForReception                                        ; Of the handle in R10
        LDR     r1, ReceiveDelay                        ; Delay before giving up
WaitWithDelaySetUp
        MOV     r0, r10                                 ; Put RX handle back into R0
        MOV     r2, #1                                  ; OSS None-zero value to allow ESCAPE
        Push    lr
        SWI     XEconet_WaitForReception                ; Does an automatic AbandonReceive
        Pull    pc, VS
        TEQ     r0, #Status_Received
ExitConvertingStatusToError
        MOVNE   r1, #0
        MOVNE   r2, #0
        SWINE   XEconet_ConvertStatusToError
        Pull    pc

AbandonR10 ; Preserves R0-R1, and VFlag(out) := VFlag(in) :LOR: Error
        Entry   "r0, r1"
AbandonR10_Alt
        SavePSR r1                                      ; Save the previous error state
        MOVS    r0, r10                                 ; If R10 is zero then do nothing
        SWINE   XEconet_AbandonReceive
        TST     r1, #VFlag                              ; Was there an error before
        BNE     %10                                     ; If there was a pre-existing error
        STRVS   r0, [ sp ]                              ; Put new error into return frame
10
        SETV    NE
        MOV     r10, #0                                 ; Clear the handle so we may call again
        EXIT

; OSS New routine to abandon R9 as well as R10 receive.

AbandonR9R10 ALTENTRY
        SavePSR r1                                      ; Save the previous error state
        MOVS    r0, r9                                  ; If R9 is zero then do nothing
        SWINE   XEconet_AbandonReceive
        TST     r1, #VFlag                              ; Was there an error before
        BNE     %10                                     ; If there was a pre-existing error
        STRVS   r0, [ sp ]                              ; Put new error into return frame
10
        SETV    NE
        MOV     r9, #0                                  ; Clear the handle so we may call again
        B       AbandonR10_Alt                          ; Tail call


DoUpCall
        Push    "r9, lr"
        MOV     r9, #EconetV
        SWI     XOS_CallAVector
        Pull    "r9, pc"

NameOrNumber ROUT
        ; Character in R0
        ; Preserves all
        ; Returns EQ if a number

        Push    "r10, r11, lr"
        ADR     r10, CharacterList
10
        LDRB    r11, [ r10 ], #1
        TEQ     r11, #0
        BEQ     %20                                     ; End of the list
        TEQ     r11, r0
        BNE     %10
        Pull    "r10, r11, pc"

20
        TEQ     r11, #1                                 ; Must set NE since we got here with BEQ
        Pull    "r10, r11, pc"

CharacterList
        DCB     ".&0123456789", 0
        ALIGN

        LTORG

        END
