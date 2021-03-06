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
        SUBT    ==> &.Arthur.NetFS.FileSystem

FSInfoBlock
        DCD     FilingSystemName - Module_BaseAddr
        DCD     -1                                      ; StartUpBanner is code
        DCD     Open - Module_BaseAddr
        DCD     GetBuffer - Module_BaseAddr
        DCD     PutBuffer - Module_BaseAddr
        DCD     Args - Module_BaseAddr
        DCD     Close - Module_BaseAddr
        DCD     File - Module_BaseAddr
        [       OldOs
        DCD     fsinfo_special+fsinfo_fsfilereadinfonolen+fsinfo_fileinfo+fsnumber_net+(5:SHL:fsinfo_nfiles_shift)
        |       ; OldOs
        DCD     fsinfo_special+fsinfo_fsfilereadinfonolen+fsinfo_fileinfo+fsinfo_multifsextensions+fsinfo_handlesurdetc+fsinfo_giveaccessstring+fsinfo_extrainfo+fsnumber_net+(5:SHL:fsinfo_nfiles_shift)
        ]
        DCD     Funct - Module_BaseAddr
        DCD     PutBytes - Module_BaseAddr
        [       :LNOT: OldOs
        DCD     fsextra_dirinformation+fsextra_FSDoesCat+fsextra_FSDoesEx
        ]

        [ international_help
NetFS_InterHelp * International_Help
        |
NetFS_InterHelp * 0
        ]        

FilingSystemName
UtilsCommands
        Command "Net",            0, 0, NetFS_InterHelp

        [ :LNOT: ReleaseVersion
        Command "NetFS_FCBs",     0, 0, 0
        Command "NetFS_Contexts", 0, 0, 0
        ]

        ; FilingSystemCommands
AddFSCommandName
        Command "AddFS",          3, 1, NetFS_InterHelp :OR: FS_Command_Flag
        Command "Bye",            1, 0, NetFS_InterHelp :OR: FS_Command_Flag
        Command "Free",           2, 0, NetFS_InterHelp :OR: FS_Command_Flag
        Command "FS",             1, 0, NetFS_InterHelp :OR: FS_Command_Flag
        Command "ListFS",         1, 0, NetFS_InterHelp :OR: FS_Command_Flag
LogonCommandName
        Command "Logon",          3, 1, NetFS_InterHelp :OR: FS_Command_Flag
        Command "Mount",          1, 1, NetFS_InterHelp :OR: FS_Command_Flag
        Command "Pass",           2, 0, NetFS_InterHelp :OR: FS_Command_Flag
        Command "SDisc",          1, 1, NetFS_InterHelp :OR: FS_Command_Flag

        ; Configuration and Status commands
        Command "FS",             1, 1, NetFS_InterHelp :OR: Status_Keyword_Flag, ConfigureFS
        Command "Lib",            1, 1, NetFS_InterHelp :OR: Status_Keyword_Flag, ConfigureLib

        DCD     0 ; Terminate table

PrintBanner     ROUT
        SWI     XEconet_PrintBanner
        Pull    pc

        ; ******************************************************
        ; ***  Internal routine for calling the file server  ***
        ; ******************************************************
        ;
        ; Inputs   R0 : File server function code
        ;          R1 : Buffer address
        ;          R2 : Size to be sent
        ; Outputs  R3 : Size received
        ; Trashed  R0

DoFSOp          ROUT
        MOV     r3, #BufferSize
DoFSOpGivingSize
        Push    "r10, r11, lr"
        BL      DoFileServerOpEntry
        Pull    "r10, r11, pc"

WaitForFSReply  ROUT
        ; Rx handle in R0, R7 - R14 preserved always
        ; Exit with V clear, and R0-R6 the result of the ReadReceive if all is OK
        ; Otherwise V set, R0^ := Error_NoReply
        ; Both exits have done an AbandonReceive
        ; This routine waits for FSReceiveDelay centiseconds

        Push    lr
        LDR     r1, FSReceiveDelay
        MOV     r2, #1                          ; Non zero => ESCapable
        SWI     XEconet_WaitForReception
        TEQ     r0, #Status_Received
        Pull    pc, EQ
        BL      ConvertStatusToError
        Pull    pc

ConvertProtectionFromFS
        ;       R1 => File server format protection
        ;       R5 <= Arthur format protection
        MOV     r5, #BitSeven                           ; Public locked
        TST     r1, #BitZero
        ORRNE   r5, r5, #BitFour                        ; Public read
        TST     r1, #BitOne
        ORRNE   r5, r5, #BitFive                        ; Public write
        TST     r1, #BitTwo
        ORRNE   r5, r5, #BitZero                        ; Owner read
        TST     r1, #BitThree
        ORRNE   r5, r5, #BitOne                         ; Owner write
        TST     r1, #BitFour
        ORRNE   r5, r5, #BitThree                       ; Owner lock
        TST     r1, #BitSix
        ORRNE   r5, r5, #BitTwo                         ; Private
        MOV     pc, lr

        LTORG

        ; ***************************************************
        ; ***  R E A D   A   S T A T I O N   N U M B E R  ***
        ; ***************************************************

        ;       R1 => Address of number
        ;       R1 <= Updated
        ;       R3 <= Station number (-1 for not found)
        ;       R4 <= Network number (-1 for not found), zero if the local is given
        ;       Trashes R0, R2

ReadStationNumber ROUT
        MOV     r4, lr
        MOV     r3, r1
        SWI     XEconet_ReadLocalStationAndNet
        MOVVC   r0, r1                                  ; Local net number
        MOVVC   r1, r3
        SWIVC   XEconet_ReadStationNumber
        MOVVS   pc, r4                                  ; Return error
        MOV     lr, r4                                  ; Return address
        MOV     r4, r3
        MOV     r3, r2
        TEQ     r4, r0                                  ; See if the number read is the local net number
        MOVEQ   r4, #0                                  ; Zero it if that is the case
        MOV     pc, lr

        ; ***********************************************
        ; ***  Find a numbered context from the list  ***
        ; ***********************************************

        ;       R3 => Station number
        ;       R4 => Network number
        ;       R0 <= Pointer to Context record
        ;       Trashes R1

FindNumberedContext ROUT
        LDR     r0, Contexts
10
        TEQ     r0, #NIL
        BEQ     %80
        LDR     r1, [ r0, #Context_Station ]
        CMP     r1, r3
        LDREQ   r1, [ r0, #Context_Network ]
        CMPEQ   r1, r4
        LDRNE   r0, [ r0, #Context_Link ]
        BNE     %10
        MOV     pc, lr

FindValidNumberedContext
        LDR     r0, Contexts
50
        TEQ     r0, #NIL
        BEQ     %80
        LDR     r1, [ r0, #Context_Station ]
        TEQ     r1, r3
        LDREQ   r1, [ r0, #Context_Network ]
        TEQEQ   r1, r4
        LDRNE   r0, [ r0, #Context_Link ]
        BNE     %50
        LDR     r1, [ r0, #Context_RootDirectory ]
        CMP     r1, #0
        LDREQ   r0, [ r0, #Context_Link ]
        BEQ     %50
        MOV     pc, lr

80
        ADR     r0, ErrorUnknownStationNumber
        [       UseMsgTrans
        B       MakeError
        |
        RETURNVS
        ]

        ; ********************************************
        ; ***  Find a named context from the list  ***
        ; ********************************************

        ;       R1 => Pointer to the context name to find
        ;       R0 <= Pointer to context record

FindNamedContext ROUT
        Push    "r1-r4, lr"
        [       Debug
        DSTRING r1, "Find a context named "
        ]
        [ {FALSE} ; Debug
        LDRB    r14, [ r1, #0 ]
        TEQ     r14, #"*"                               ; Is this a wild one?
        LDREQ   r0, Current
        Pull    "r1-r4, pc", EQ, ^
        ]
        LDR     r2, Contexts
FindNamedContextLoop
        TEQ     r2, #NIL
        BEQ     NamedContextNotFound            ; End of the list
        ADD     r0, r2, #Context_DiscName       ; Compare names
        BL      CompareTwoStrings
        LDRNE   r2, [ r2, #Context_Link ]
        BNE     FindNamedContextLoop
        MOV     r0, r2                          ; Return the record pointer
        CLRV
        Pull    "r1-r4, pc"

NamedContextNotFound                            ; Now look in the NameCache
        [       Debug
        DLINE   "Looking in name cache"
        ]
        LDR     r2, NameCache                   ; To see what the error should be
60
        TEQ     r2, #NIL
        BEQ     NameNotFoundAtAll
        ADD     r0, r2, #Cache_Name             ; Compare names
        BL      CompareTwoStrings
        LDRNE   r2, [ r2, #Cache_Link ]
        BNE     %60
        LDRB    r3, [ r2, #Cache_Station ]
        LDRB    r4, [ r2, #Cache_Network ]
        [       Debug
        BREG    r4, "Found name, FS = &", cc
        BREG    r3, ".&"
        ]
        BL      FindValidNumberedContext
        Pull    "r1-r4, lr"
        MOVVC   pc, lr
        [       UseMsgTrans
        ADR     r0, ErrorNotLoggedOnTo
        B       MakeErrorWithContextName
        |       ; UseMsgTrans
        ADRL    r0, ErrorNotLoggedOn
        RETURNVS
        ]       ; UseMsgTrans

NameNotFoundAtAll                               ; The error exit
        ADR    r0, ErrorUnknownStationName
        [       UseMsgTrans
        Pull    "r1-r4, lr"
MakeErrorWithContextName
        Push    "r4, r5, lr"
        MOV     r4, r1
        MOV     r5, #0
        BL      MessageTransErrorLookup2
        Pull    "r4, r5, pc"

ErrorUnknownStationNumber
        DCD     ErrorNumber_UnknownStationNumber
        DCB     "UnkNmbr", 0
        ALIGN

ErrorNotLoggedOnTo
        DCD     ErrorNumber_NotLoggedOn
        DCB     "NtLogOn", 0
        ALIGN

ErrorUnknownStationName
        DCD     ErrorNumber_UnknownStationName
        DCB     "UnkName", 0
        ALIGN
        |       ; UseMsgTrans
        SETV
        Pull    "r1-r4, pc"

        Err     UnknownStationNumber
        Err     UnknownStationName
        ALIGN
        ]       ; UseMsgTrans

        [       OldOs

UseNameToSetTemporary ROUT
        ; ******************************************************
        ; ***   Take an object name as passed by FileSwitch  ***
        ; ***  as a pair of pointers (R1/R6) and look up     ***
        ; ***  the associated context, validate it, and set  ***
        ; ***  it as the temporary FS                        ***
        ; ***   Then return a pointer to a normalised name   ***
        ; ***  as used by the file server after translation  ***
        ; ******************************************************
        ;       R1 => Pointer to the object name
        ;       R6 => Pointer to the special field
        ;       All registers preserved
        Push    "r0-r4, lr"
        [       Debug
        SWI     OS_WriteS
        DCB     "UseNameToSetTemporary called with ""Net", 0
        ALIGN
        TEQ     r6, #0
        BEQ     %02
        SWI     OS_WriteI + "#"
        MOV     r0, r6
        SWI     OS_Write0
02
        SWI     OS_WriteI + ":"
        MOV     r0, r1
        SWI     OS_Write0
        SWI     OS_WriteI + """"
        SWI     OS_NewLine
        ]
        CMP     r6, #0                                  ; Get the special field
        LDRNEB  r1, [ r6 ]                              ; Get the first byte of the argument
        CMPNE   r1, #0                                  ; No argument given or empty string; use current
        LDREQ   r0, Current
        BEQ     ContextFoundForTemporary
        BL      IsItANumber                             ; See what we got
        MOV     r1, r6                                  ; Restore argument pointer
        BNE     FindNamedContextForTemporary
        BL      ReadStationNumber                       ; Returns R4.R3
        BVS     ExitUseName
        CMP     r3, #-1
        CMPNE   r4, #-1
        BNE     FindNumberedContextForTemporary         ; Neither needs defaulting
        LDR     r0, Current
        TEQ     r0, #0
        BEQ     FindNumberedContextForTemporary         ; No context, make error by lookup
        BL      ValidateContext
        BVS     ExitUseName
        CMP     r3, #-1
        LDREQB  r3, [ r0, #Context_Station ]
        CMP     r4, #-1
        LDREQB  r4, [ r0, #Context_Network ]
FindNumberedContextForTemporary
        BL      FindNumberedContext
        B       ContextFoundForTemporary

FindNamedContextForTemporary                            ; Argument given was not numeric
        BL      FindNamedContext
ContextFoundForTemporary
        BLVC    MakeContextTemporary
ExitUseName
        STRVS   r0, [ sp, #0 ]
        [       Debug
        BVC     %97
        ADD     r0, r0, #4
        DSTRING r0, "UseNameToSetTemporary returns an error: "
        B       %98
97
        LDR     r0, Temporary
        ADD     r0, r0, #Context_DiscName
        DSTRING r0, "Context name: "
98
        ]
        Pull    "r0-r4, pc"

CopyPathNameInDoingTranslation ROUT                     ; Terminates at the first space
        ; **************************************************************
        ; ***  Calls 'SetFSOpURDFlag' if the string starts with a    ***
        ; ***  "&" and doesn't copy it or its trailing ".".          ***
        ; **************************************************************
        ; ***  Calls 'SetFSOpLIBFlag' if the string starts with a    ***
        ; ***  "%" and doesn't copy it or its trailing ".".          ***
        ; **************************************************************
        ; ***  Calls 'SetFSOpCSDFlag' if the string starts with a    ***
        ; ***  "@" and doesn't copy it or its trailing ".".          ***
        ; **************************************************************
        ; ***  Legal leadin sequences are :                          ***
        ; ***      "<char><.>"                                       ***
        ; ***      "<char><term>"                                    ***
        ; ***  All other sequences are passed straight through       ***
        ; **************************************************************
        Push    "r3, r4, lr"
        LDRB    r3, [ r0 ]                              ; The first character
        TEQ     r3, #"&"                                ; Is it the URD character?
        LDREQB  r3, FSOpHandleFlags
        BICEQ   r3, r3, #CSDSlotMask                    ; Clear the CSD field
        [       UseURDHandle <> 0
        ORREQ   r3, r3, #UseURDHandle :SHL: CSDSlotShift ; Set it to URD
        ]
        STREQB  r3, FSOpHandleFlags
        BEQ     %20
        TEQ     r3, #"%"                                ; Is it the LIB character
        BLEQ    SetFSOpLIBFlag
        BEQ     %20
        TEQ     r3, #"@"                                ; Is it the CSD character?
        BNE     DoCopyNameIn
        BL      SetFSOpCSDFlag
20
        LDRB    r3, [ r0, #1 ]                          ; The second character
        TEQ     r3, #"."                                ; Must be followed by a dot, or a terminator
        BEQ     %30
        CMP     r3, #" "                                ; Check for terminator
        BGT     NotASpecialCase
        DEC     r0, 1                                   ; Point to the rest of the string
30
        INC     r0, 2                                   ; Point to the rest of the string
        B       DoCopyNameIn

NotASpecialCase                                         ; So revert to normal mode
        BL      SetFSOpCSDFlag
        B       DoCopyNameIn

CopyObjectNameInDoingTranslation ROUT
        ; Inputs   R0 => Input string
        ;          R1 => Address of output buffer
        ;          R2 => Current offset in that buffer
        ; Outputs  R0 <= Updated to point to byte after terminator
        ;          R1 <= Preserved
        ;          R2 <= Updated to point to byte after <CR>

        Push    "r2, r3, r4, lr"
        BL      CopyPathNameInDoingTranslation
        Pull    r14                                     ; Get the initial pointer, was R2
        LDRB    r3, [ r1, r14 ]                         ; Get the first character of the translation
        CMP     r3, #13
        Pull    "r3, r4, pc", NE                        ; It didn't reduce to a ""
        MOV     r2, r14
        ;       If the special character was either "@" or "%", then we have the name
        ;       as the CurrentDirectoryName or CurrentLibraryName.  If it was "&"
        ;       then we have a hard case and have to look it up on the file server.
        ;       If (in either case) the name is "$" then "$" is returned otherwise
        ;       we return "^.<name>".
        LD      r0, FSOpHandleFlags
        ANDS    r0, r0, #CSDSlotMask                    ; Separate out just the CSD part
        BEQ     HereIsTheURD
        TEQ     r0, #4_0010                             ; Is it the CSD => "@"
        LDR     r0, Current
        ADDEQ   r0, r0, #Context_DirectoryName
        ADDNE   r0, r0, #Context_LibraryName
        B       NameOfHereResolved

HereIsTheURD
        ;       Since we are going to use the CommandBuffer here we must preserve it's
        ;       contents, since we know where this routine is called from we are sure
        ;       that 8 bytes will do
        LDMIA   r1, { r3, r4 }
        Push    "r1, r2, r3, r4"
        MOV     r0, #6                                  ; Reason code 6
        STRB    r0, [ r1 ]
        MOV     r0, #13                                 ; On directory ""
        STRB    r0, [ r1, #1 ]
        MOV     r2, #2
        MOV     r0, #FileServer_ReadObjectInfo
        BL      DoFSOp
        BVC     NameIsOK
        Pull    "r1, r2, r3, r4"
        STMIA   r1, { r3, r4 }
        Pull    "r3, r4, pc"

NameIsOK                                                ; Copy name to TemporaryBuffer
        ADD     r0, r1, #3                              ; Address of name
        ADR     r1, TemporaryBuffer
        MOV     r2, #0
        BL      CopyNameIn
        Pull    "r1, r2, r3, r4"
        STMIA   r1, { r3, r4 }
        ADR     r0, TemporaryBuffer
NameOfHereResolved
        LDRB    r14, [ r0 ]                             ; Get first character
        TEQ     r14, #"$"
        MOVNE   r14, #"^"
        STRNEB  r14, [ r1, r2 ]
        ADDNE   r2, r2, #1
        MOVNE   r14, #"."
        STRNEB  r14, [ r1, r2 ]
        ADDNE   r2, r2, #1
        B       DoCopyNameIn                            ; Tail recursion

        |       ; OldOs

UseNameToSetTemporary ROUT
        ; ******************************************************
        ; ***   Take an object name as passed by FileSwitch  ***
        ; ***  as a pair of pointers (R1/R6) and look up     ***
        ; ***  the associated context, validate it, and set  ***
        ; ***  it as the temporary FS                        ***
        ; ***   Then return a pointer to a normalised name   ***
        ; ***  as used by the file server after translation  ***
        ; ******************************************************
        ;       R1 => Pointer to the Canonical name (:<disc/FS>.{$|&}...)
        ;       R6 => Pointer to the Canonical special field
        ;       R1 <= Pointer to the ":" if the dir is "$"
        ;                  else it points at the dir &
        ;       All registers preserved
        Push    "r0, r1, lr"
        [       Debug
        SWI     OS_WriteS
        DCB     "UseNameToSetTemporary called with ""Net", 0
        ALIGN
        TEQ     r6, #0
        BEQ     %02
        SWI     OS_WriteI + "#"
        MOV     r0, r6
        SWI     OS_Write0
02
        SWI     OS_WriteI + ":"
        MOV     r0, r1
        SWI     OS_Write0
        SWI     OS_WriteI + """"
        SWI     OS_NewLine
        ]
        INC     r1                                      ; Skip the colon
        DEC     sp, SmallBufferSize                     ; Space to copy the disc name to terminate it
        MOV     r14, #0                                 ; Index
10
        CMP     r14, #SmallBufferSize - 1               ; Clears V
        ADREQL  r0, ErrorNetFSInternalError
        BLEQ    MakeErrorWithModuleName
        BVS     %30
        LDRB    r0, [ r1 ], #1
        TEQ     r0, #"."                                ; Char before dir
        MOVEQ   r0, #0                                  ; Terminator
        STRB    r0, [ sp, r14 ]                         ; Copy away, as a stand alone string
        ADDNE   r14, r14, #1                            ; Move the index
        BNE     %10
        LDRB    r0, [ r1 ]
        TEQ     r0, #"$"                                ; Is this a full disc name spec?
        STRNE   r1, [ sp, #SmallBufferSize + 4 ]        ; No, point exit R1 at dir char
        MOV     r1, sp
        BL      FindNamedContext                        ; Look for the disc name
30
        INC     sp, SmallBufferSize
        BLVC    MakeContextTemporary
        STRVS   r0, [ sp, #0 ]
        [       Debug
        BVC     %97
        ADD     r0, r0, #4
        DSTRING r0, "UseNameToSetTemporary returns an error: "
        B       %98
97
        LDR     r0, Temporary
        ADD     r0, r0, #Context_DiscName
        DSTRING r0, "Context name: "
        LDR     r1, [ sp, #4 ]
        DSTRING r1, "Normalised object name: "
98
        ]
        Pull    "r0, r1, pc"

CopyPathNameInDoingTranslation ROUT                     ; Terminates at the first space
        [       Debug
        DLINE   "CopyPathNameInDoingTranslation called"
        ]
        Push    "r3, r4, lr"
        ;       Compare the input string, pointed to by R0 with the
        ;       context strings CSDHandleName and LIBHandleName.
        ;       If a leading substring match terminates at a "." and
        ;       is longer than two characters long then set the
        ;       appropriate handle flag, remove the common substring,
        ;       and copy in the remainder. e.g.
        ;       CSDHandleName = "&.Fred.Jim"
        ;       LIBHandleName = "$.ArthurLib"
        ;       Input: "$"              Flags: URD      Output: "$"
        ;       Input: "$.Bill"         Flags: URD      Output: "$.Bill"
        ;       Input: "$.ArthurLib"    Flags: LIB      Output: ""
        ;       Input: "$.ArthurLib.X"  Flags: LIB      Output: "X"
        ;       Input: "&"              Flags: URD      Output: ""
        ;       Input: "&.Bill"         Flags: URD      Output: "Bill"
        ;       Input: "&.Fred"         Flags: URD      Output: "Fred"
        ;       Input: "&.Fred.Jim"     Flags: CSD      Output: ""
        ;       Input: "&.Fred.Jim.X"   Flags: CSD      Output: "X"
        ;       Note the string compares are done case insensitively
        ;       Always do both compares to find out which is "best"

FSCommandMax    *       60

        LD      r3, FSOpHandleFlags                     ; Default the flags to URD
        BIC     r3, r3, #CSDSlotMask                    ; Clear the CSD field
        [       UseURDHandle <> 0
        ORR     r3, r3, #UseURDHandle :SHL: CSDSlotShift ; Set it to URD
        ]
        ST      r3, FSOpHandleFlags

        LDR     r3, Temporary
        LDR     r3, [ r3, #Context_LIBHandleName ]
        Push    r0
        BL      DoHandleName                            ; Returns EQ if a match is found
        LDREQB  r3, FSOpHandleFlags
        [       UseURDHandle <> 0
        BICEQ   r3, r3, #CSDSlotMask                    ; Clear the CSD field
        ]
        ORREQ   r3, r3, #UseLIBHandle :SHL: CSDSlotShift ; Set it to LIB
        STREQB  r3, FSOpHandleFlags
        Pull    r3
        Push    "r0, r4"                                ; Keep the quality value
        MOV     r0, r3

        LDR     r3, Temporary
        LDR     r3, [ r3, #Context_CSDHandleName ]
        BL      DoHandleName                            ; Returns EQ if a match is found
        Pull    "r3, r14"
        BNE     CheckPrevious
        TEQ     r14, #0                                 ; Was previous (LIB) a match?
        BEQ     SetForCSD                               ; No, so use this one
        CMP     r14, r4                                 ; Yes, so compare the match size
        MOVGT   r0, r3
        BGT     CopyPathIn                              ; First was best
SetForCSD
        LDRB    r3, FSOpHandleFlags
        BIC     r3, r3, #CSDSlotMask                    ; Clear the CSD field
        ORR     r3, r3, #UseCSDHandle :SHL: CSDSlotShift ; Set it to CSD
        STRB    r3, FSOpHandleFlags
        B       CopyPathIn

CheckPrevious
        TEQ     r14, #0                                 ; Was previous (LIB) a match?
        MOVNE   r0, r3
        BNE     CopyPathIn                              ; Yes, substring nonzero length
SkipNameCompare
        LDRB    r3, [ r0 ]                              ; The first character
        TEQ     r3, #"&"                                ; Is it the URD character?
        BNE     CopyPathIn                              ; If it is & then the HandleFlags are right
        LDRB    r3, [ r0, #1 ]                          ; The second character
        TEQ     r3, #"."                                ; Must be followed by a dot, or a terminator
        BEQ     %30
        CMP     r3, #" "                                ; Check for terminator
        BGT     NotASpecialCase
        DEC     r0, 1                                   ; Point to the rest of the string
30
        INC     r0, 2                                   ; Point to the rest of the string
        B       CopyPathIn

NotASpecialCase                                         ; So revert to normal mode
        BL      SetFSOpCSDFlag
CopyPathIn
        ADD     r3, r1, r2                              ; Address of result
        BL      CopyNameIn
        [       Debug
        DSTRING r3, "Path name translates to "
        DREG    r2, "Resultant command length is &"
        ]
        [ {FALSE} ; Debug
        CMP     r2, #FSCommandMax                       ; Is the result too large?
        Pull    "r3, r4, pc", LS                        ; No, so return
        [       Debug
        DLINE   "Which is too long!"
        ]

        SUB     r14, r3, r1                             ; Length of header
        RSB     r14, r14, #FSCommandMax                 ; Maximum resultant path part
        SUB     r2, r2, r14                             ; Skip back to make such a command
40
        DEC     r2                                      ; Skip forwards
        LDRB    r14, [ r1, r2 ]
        TEQ     r14, #"."                               ; Looking for a separator
        BNE     %40
        ADD     r4, r1, r2
        INC     r4                                      ; Pointer to the new leaf part
        MOV     r14, #0
        STRB    r14, [ r1, r2 ]
        [       Debug
        DSTRING r3, "New directory to cache"
        ]
        Push    "r0, r1, r2, r4, r5"
        MOV     r1, r3                                  ; New name to use
        BL      CacheDirectoryName
        ST      r5, FSOpHandleFlags
        Pull    "r0, r1, r2, r4, r5"
        [       Debug
        DSTRING r4, "New leaf part"
        ]
50
        LDRB    r14, [ r4 ], #1
        STRB    r14, [ r3 ], #1
        CMP     r14, #" "
        BGT     %50
        SUB     r2, r3, r1                              ; Compute new length
        ]       ; False
        Pull    "r3, r4, pc"

CopyObjectNameInDoingTranslation ROUT
        ;       R0 => Input string
        ;       R1 => Address of output buffer
        ;       R2 => Current offset in that buffer
        ;       R0 <= Updated to point to byte after terminator
        ;       R1 <= Preserved
        ;       R2 <= Updated to point to byte after <CR>
        ;
        ;       This differs from CopyPathNameInDoingTranslation in that
        ;       it always returns a string of non zero length.
        [       Debug
        DSTRING r0, "CopyObjectNameInDoingTranslation called with: "
        ]
        Push    "r1-r4, lr"
        ADR     r1, TemporaryBuffer                     ; Make a copy to mutilate
        MOV     r2, #0
        BL      CopyNameIn
        MOV     r4, r0                                  ; Keep exit value of R0
        TEQ     r2, #2                                  ; If the length is 2 then it must be "&"<CR>
        BEQ     NameIsURD
        ADD     r3, r1, r2                              ; Address of terminating <CR>
SplitNameLoop
        LDRB    r0, [ r3, #-1 ]!                        ; Scan backwards looking for the "."
        EORS    r0, r0, #"."
        BNE     SplitNameLoop
        STRB    r0, [ r3 ], #1                          ; Terminate the pathname, point at the leafname
        ADR     r0, TemporaryBuffer
        [       Debug
        DSTRING r0, "Pathname is "
        DSTRING r3, "Leafname is "
        ]
        Pull    "r1, r2"                                ; Entry values of R1 and R2
        Push    "r4"                                    ; Exit is now Pull "r0, r3-r4, pc"
        ADD     r4, r1, r2                              ; Address for the result
        LDRB    r14, [ r3, #0 ]                         ; Check first character of leafname
        TEQ     r14, #"$"
        MOVEQ   r14, #"."
        STREQB  r14, [ r3, #-1 ]                        ; Join pathname and leafname back together ":Name.$"
        [       Debug
        BNE     %71
        DSTRING r0, "Pathname and leafname joined "
71
        ]
        BEQ     SkipTranslation
        BL      CopyPathNameInDoingTranslation
        SUB     r0, r2, #1                              ; Point at the character following the translation
        LDRB    r14, [ r4, #0 ]                         ; Look for ""
        TEQ     r14, #13                                ; IF Str$="" THEN = Str$+Leaf$ ELSE =Str$+"."+Leaf$
        MOVEQ   r2, r0
        MOVNE   r14, #"."
        STRNEB  r14, [ r1, r0 ]
        MOV     r0, r3                                  ; The leafname
SkipTranslation
        BL      CopyNameIn
        [       Debug
        DSTRING r4, "Object name translates to: "
        ]
        Pull    "r0, r3-r4, pc"

NameIsURD
        Pull    "r1, r2"                                ; Entry values of R1 and R2
        Push    "r4"                                    ; Exit is now Pull "r0, r3-r4, pc"
        [       Debug
        ADD     r4, r1, r2                              ; Address for the result
        ]
        LDR     r0, Temporary
        ADD     r0, r0, #Context_UserRootName
        B       SkipTranslation

DoHandleName    ROUT
        ;       R0 => Pointer to a name
        ;       R3 => Pointer to a name
        ;       R4 <= Number of matching characters
        ;       Compares the name pointed to by R3 with the name pointed to by R0
        ;       IFF the R3 name is a substring of R0 then EQ is returned and R0 is
        ;       updated to point to the difference string, and R4 is the number of
        ;       characters in the common substring ELSE R0 is preserved and NE
        ;       is returned.
        ;       Preserve: R1, R2
        ;       Trash:    R3, R4
        Push    "r2, r5, lr"
        [       Debug
        DSTRING r3, "Comparing handle name: ", cc
        DSTRING r0, " with file name: ", cc
        DLINE   ".", cc
        ]
        MOV     r4, r0                                  ; Preserve in case of no match
        LDR     r14, UpperCaseTable
HandleNameLoop
        TEQ     r14, #0
        LDRB    r2, [ r0 ], #1
        LDRNEB  r2, [ r14, r2 ]                         ; Map to upper case
        LDRB    r5, [ r3 ], #1
        LDRNEB  r5, [ r14, r5 ]                         ; Map to upper case
        CMP     r2, #" "
        MOVLE   r2, #0
        CMP     r5, #" "
        MOVLE   r5, #0
        TEQ     r2, r5
        BNE     HandleNameFails
        TEQ     r2, #0                                  ; Was this the exact match?
        BNE     HandleNameLoop
        DEC     r0                                      ; Point back at the terminator
        B       ExitDoHandleName

HandleNameFails
        ;       There is some mismatch, look for terminator and "."
        TEQ     r5, #0
        TEQEQ   r2, #"."
        MOVNE   r0, r4                                  ; No match, restore R0
ExitDoHandleName
        [       Debug
        BEQ     %87
        DLINE   "  Exit with NE."
        B       %88
87
        DSTRING r0, "  Exit with EQ, file name is now: ", cc
        DLINE   "."
88
        ]
        SUB     r4, r0, r4
        Pull    "r2, r5, pc"

CacheDirectoryName ROUT
        ;       R1 => Name to cache
        ;       R5 <= FSOpHandleFlags to use for this name
        ;       R0, R1, R2, R4, R5 Trashed
        ;       Note that this is re-entrant
        Push    "r3, r6, lr"
        LDR     r2, =&2062694C                          ; "Lib "
        MOV     r0, r1                                  ; Name of directory to select
        BL      ConvertNameToInternal
        MOV     r5, r1                                  ; Save name for a later SetString
        MOV     r6, sp                                  ; Used to get rid of the frame later
        MOV     r4, #0
20
        LDRB    r14, [ r1, r4 ]                         ; Count the incoming string
        INC     r4
        CMP     r14, #" "
        BGT     %20
        CMP     r4, #&80
        MOVLT   r4, #&80
        ADD     r4, r4, #4+4                            ; Account for "Lib " and word rounding
        BIC     r4, r4, #3
        SUB     sp, sp, r4
        MOV     r1, sp
        STR     r2, [ r1 ]
        MOV     r2, #4
        BL      CopyPathNameInDoingTranslation
        LDRB    r0, [ r1, #4 ]                          ; Get leading character of argument
        CMP     r0, #13                                 ; Is the argument null ??
        [       Debug
        BNE     %76
        DLINE   "Cache hit!"
76
        ]
        LDREQB  r5, FSOpHandleFlags                     ; Yes, then return its flags
        BEQ     ExitCacheDirectoryName                  ; Don't bother, we already have this handle
        [       Debug
        LD      r14, FSOpHandleFlags
        AND     r0, r14, #URDSlotMask
        [       URDSlotShift <> 0
        myASR   r0, URDSlotShift
        ]
        BREG    r0, "URD = &", cc
        AND     r0, r14, #CSDSlotMask
        myASR   r0, CSDSlotShift
        BREG    r0, "  CSD = &", cc
        AND     r0, r14, #LIBSlotMask
        myASR   r0, LIBSlotShift
        BREG    r0, "  LIB = &"
        ]
        LDR     r4, Temporary
        LDRB    r14, [ r4, #Context_Flags ]
        EOR     r14, r14, #Context_Flags_CacheLRU       ; Flip the UseCSD/UseLIB bit
        STRB    r14, [ r4, #Context_Flags ]
        ANDS    r14, r14, #Context_Flags_CacheLRU       ; Now test it
        BEQ     DoItToTheLIB                            ; No extra action required
        [       Debug
        DLINE   "Cache technology uses the CSD"
        ]
        LD      r14, FSOpHandleFlags
        BIC     r14, r14, #LIBSlotMask + FlipLibDirBit  ; Keep the CSD and URD
        ORR     r14, r14, #(UseCSDHandle :SHL: LIBSlotShift) + FlipLibDirBit
        ST      r14, FSOpHandleFlags
        ADD     r4, r4, #Context_CSDHandleName
        HandleFlags r3, URD, CSD, LIB
        B       SelectCachedDirectory

DoItToTheLIB
        [       Debug
        DLINE   "Cache technology uses the LIB"
        ]
        ADD     r4, r4, #Context_LIBHandleName
        HandleFlags r3, URD, LIB, CSD
SelectCachedDirectory
        MOV     r0, #FileServer_DecodeCommand
        Push    r3
        BL      DoFSOp
        BLVC    SetString
        Pull    r5
ExitCacheDirectoryName
        [       Debug
        AND     r3, r5, #URDSlotMask
        [       URDSlotShift <> 0
        myASR   r3, URDSlotShift
        ]
        BREG    r3, "URD = &", cc
        AND     r3, r5, #CSDSlotMask
        myASR   r3, CSDSlotShift
        BREG    r3, "  CSD = &", cc
        AND     r3, r5, #LIBSlotMask
        myASR   r3, LIBSlotShift
        BREG    r3, "  LIB = &"
        ]
        MOV     sp, r6                                  ; Removes the frame as well
        Pull    "r3, r6, pc"

RemoveCachedDirectory
        Push    "r0-r2, r4, r5, lr"                     ; Name pointer in R1
        MOV     r0, r1
        ADR     r1, CommandBuffer
        MOV     r2, #0
        BL      CopyPathNameInDoingTranslation          ; Look for zero length result
        CMP     r2, #1                                  ; Empty string is just a CR
        BNE     NameNotInCache
        [       Debug
        LDR     r14, [ sp, #4 ]
        DSTRING r14, "Remove the cached path: "
        ]
        ;       Currently this is done by changing the cache to "&"
        ;       An improvement might be to attempt to remove two elements
        ;       from the path e.g. "&.fred.bill.sam.jill" becomes "&.fred.bill"
        ;       This could be done with *Dir ^.^ and writing a zero on the dot
        ;       in the string e.g. "&.fred.bill"+CHR$0+"sam.jill"
        LDRB    r14, FSOpHandleFlags
        AND     r0, r14, #CSDSlotMask
        CMP     r0, #UseCSDHandle :SHL: CSDSlotShift
        BLT     NameNotInCache                          ; Name is "&" so let it go wrong
        LDR     r4, Temporary
        ADDEQ   r4, r4, #Context_CSDHandleName
        ADDNE   r4, r4, #Context_LIBHandleName
        ORRNE   r14, r14, #FlipLibDirBit
        STRNEB  r14, FSOpHandleFlags
        LDR     r0, =&0D726944                          ; "Dir", <CR>
        STR     r0, [ r1, #0 ]
        MOV     r2, #4
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        ADRL    r5, Ampersand
        BLVC    SetString
NameNotInCache
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r2, r4, r5, pc"

        ]       ; OldOs

        ; ********************************
        ; ***  Let's copy a file name  ***
        ; ********************************

        ;       R0 => Input string
        ;       R1 => Address of output buffer
        ;       R2 => Current offset in that buffer
        ;       R0 <= Updated to point to byte after terminator
        ;       R1 <= Preserved
        ;       R2 <= Updated to point to byte after <CR>

        ; **************************************************************
        ; ***  The terminator is always translated into a <CR>       ***
        ; **************************************************************

CopyLineIn      ROUT                                    ; Terminates at the first control character
        Push    "r3, r4, lr"
        MOV     r4, #" " - 1
        B       CopyIn

CopyNameIn                                              ; Terminates at the first space
        Push    "r3, r4, lr"
DoCopyNameIn
        MOV     r4, #" "
CopyIn                                                  ; Common part of all the routines
        LDRB    r3, [ r0 ], #1
        CMP     r3, r4
        MOVLE   r3, #13
        STRB    r3, [ r1, r2 ]
        INC     r2
        BGT     CopyIn
        CLRV
        Pull    "r3, r4, pc"

        LTORG

CreateNumberedContext ROUT
        ;       R3 => Station number
        ;       R4 => Network number
        ;       R0 <= Pointer to the record created
        ;       All fields are filled with zeros
        Push    "r1-r3, lr"
        [       Debug
        BREG    r4, "Creating numbered context &", cc
        BREG    r3, ".&"
        MOV     r3, #Size_Context + &60
        |
        MOV     r3, #Size_Context
        ]
        BL      MyClaimRMA
        BVS     ExitCreateNumberedContext
        MOV     r1, r2                                  ; Address of the block
        MOV     r2, #0
10
        DECS    r3
        STRB    r2, [ r1, r3 ]                          ; Zero every byte
        BNE     %10
        LDR     r2, =ContextIdentifier
        STR     r2, [ r1, #Context_Identifier ]
        [       Debug
        RSB     r2, r2, #0
        STR     r2, [ r1, #Size_Context ]               ; Mark the edge of the known universe
        STR     r2, [ r1, #Size_Context + 4 ]           ; So that transgressors can be found
        ]
        LDR     r3, [ sp, #8 ]                          ; Original R3
        ADD     r2, r1, #Context_Station
        STMIA   r2, { r3, r4 }
        MOV     r0, r3                                  ; Station number
        MOV     r3, r1                                  ; Pointer to the record
        MOV     r1, r4                                  ; Network number
        MOV     r2, #0                                  ; Must initialise for unknown type
        SWI     XEconet_PacketSize
        MOVVS   r2, #&400                               ; An error means the transport type is unknown
        MOV     r0, #10                                 ; Ten packets to a block
        MUL     r1, r2, r0
        MOV     r2, #5                                  ; Five blocks is the threshold
        MUL     r0, r1, r2
        ADD     r2, r3, #Context_Threshold              ; Start of the pair of values
        STMIA   r2, { r0, r1 }                          ; Put them into the context record
        MOV     r0, r3                                  ; Pointer to the record
        LDR     r2, Contexts                            ; Head of the list
        STR     r2, [ r0, #Context_Link ]               ; Now pointed to by this record
        STR     r0, Contexts                            ; This one is now the new head
        CLRV
ExitCreateNumberedContext
        Pull    "r1-r3, pc"

        LTORG

        ;       **********************************************
        ;       ***   Remove and delete a context record   ***
        ;       **********************************************

        ;       R0 => Pointer to the context to remove
        ;       Trashed R0

RemoveContext   ROUT
        Push    "r2, lr"
        BL      EmptyContext                            ; Throw all the leaves away
        BVS     ExitRemoveContext
        [       Debug
        DLINE   "Context emptied OK"
        ]
        ADR     r14, Contexts - Context_Link
10
        LDR     r2, [ r14, #Context_Link ]
        TEQ     r2, #NIL
        BEQ     RemoveContextError                      ; Record not found
        TEQ     r2, r0                                  ; Is this the one?
        BEQ     %20
        MOV     r14, r2                                 ; Skip down the list
        B       %10

20                                                      ; Record found, previous in R14
        LDR     r0, [ r2, #Context_Link ]               ; Address of the next
        STR     r0, [ r14, #Context_Link ]              ; Link our record out
        BL      MyFreeRMA                               ; Throw the record away
ExitRemoveContext
        Pull    "r2, pc"

RemoveContextError
        ADRL    r0, ErrorNetFSInternalError
        [       UseMsgTrans
        BL      MakeErrorWithModuleName
        |
        SETV
        ]
        B       ExitRemoveContext


EmptyContext    ROUT
        Push    "r0-r3, lr"
        [       Debug
        DREG    r0, "Empty context record at &"
        ]
        BL      ValidateContext
        BVS     ExitEmptyContext
        LDR     r1, Contexts
10
        TEQ     r1, #NIL
        BEQ     EmptyContextError                       ; Record not found
        TEQ     r1, r0                                  ; Is this the one?
        BEQ     %20
        LDR     r1, [ r1, #Context_Link ]               ; Skip down the list
        B       %10

20
        MOV     r0, #0
        STR     r0, [ r1, #Context_RootDirectory ]
        STRB    r0, [ r1, #Context_DiscName ]
        [       OldOs
        STRB    r0, [ r1, #Context_DirectoryName ]
        STRB    r0, [ r1, #Context_LibraryName ]
        |
        ADD     r3, r1, #Context_DirectoryName
        BL      FreeString
        ADDVC   r3, r1, #Context_LibraryName
        BLVC    FreeString
        ADDVC   r3, r1, #Context_CSDHandleName
        BLVC    FreeString
        ADDVC   r3, r1, #Context_LIBHandleName
        BLVC    FreeString
        ]
ExitEmptyContext
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r3, pc"

        [       :LNOT: OldOs
FreeString
        ;       R0 =  0
        ;       R3 => Address of the string pointer
        Push    lr
        LDR     r2, [ r3 ]
        STR     r0, [ r3 ]
        CMP     r2, #0                                  ; Clears V
        [       Debug
        Pull    pc, EQ
        DSTRING r2, "Freeing string ", cc
        DREG    r2, " at &"
        ]
        BLNE    MyFreeRMA
        Pull    pc
        ]       ; OldOs

EmptyContextError
        ADRL    r0, ErrorNetFSInternalError
        [       UseMsgTrans
        BL      MakeErrorWithModuleName
        |
        SETV
        ]
        B       ExitEmptyContext

        ;       *******************************
        ;       ***   Compare two strings   ***
        ;       *******************************

        ;       R0 => Pointer to the first string
        ;       R1 => Pointer to the second string
        ;       PSR <= EQ or NE

CompareTwoStrings ROUT
        Push    "r2-r4, lr"
        MOV     r4, #0                                  ; Index
        [       OldOs
30
        LDRB    r2, [ r0, r4 ]                          ; Supplied character
        uk_UpperCase r2, r14
        LDRB    r3, [ r1, r4 ]                          ; Context character
        uk_UpperCase r3, r14
        |
        LDR     r14, UpperCaseTable
30
        TEQ     r14, #0
        LDRB    r2, [ r0, r4 ]                          ; Supplied character
        LDRNEB  r2, [ r14, r2 ]                         ; Map to upper case
        LDRB    r3, [ r1, r4 ]                          ; Context character
        LDRNEB  r3, [ r14, r3 ]                         ; Map to upper case
        ]
        CMP     r2, #" "
        MOVLE   r2, #0                                  ; Force terminator to 0
        CMP     r3, #" "
        MOVLE   r3, #0                                  ; Force terminator to 0
        INC     r4
        TEQ     r2, r3
        Pull    "r2-r4, pc", NE
        TEQ     r2, #0
        BNE     %30
        Pull    "r2-r4, pc"

AddString ROUT
        Push    r1
        RSB     r0, pc, pc                              ; r0 = psr (if 26-bit)
        SUB     lr, lr, r0                              ; Remove PSR
10
        LDRB    r0, [ lr ], #1
        STRB    r0, [ r1 ], #1
        TEQ     r0, #0
        BNE     %10
        SUB     r1, r1, #1                              ; Point back at the zero
        ADD     lr, lr, #3                              ; Get to the right word boundary
        Pull    r0
        BIC     pc, lr, #3                              ; Implicit

        LTORG

        END
