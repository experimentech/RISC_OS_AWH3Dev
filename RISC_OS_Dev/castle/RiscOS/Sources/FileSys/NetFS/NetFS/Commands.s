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
        SUBT    ==> &.Arthur.NetFS.Commands

        ; ******************************
        ; ***  Utils grade commands  ***
        ; ******************************

Net_Code       ROUT
        MOV     r6, lr
        MOV     r0, #FSControl_SelectFS
        ADRL    r1, FilingSystemName
        SWI     XOS_FSControl
        MOV     pc, r6

        LTORG

        ; ***********************************************
        ; ***      Commands decoded by FileSwitch     ***
        ; ***********************************************
        ; ***         Preserve only R13 (sp)          ***
        ; ***  Entered with the link address at [sp]  ***
        ; ***********************************************

        [       OldOs
DoStarDir       ROUT
        ;       R1 => Directory name to select
        ;       R6 => Special field
        BL      DealWithR6AsStarFS
        BVS     ExitStarDir
        LDRB    r0, [ r1 ]
        CMP     r0, #" "
        BLT     StarDirByItself
        [ {TRUE}
        LDR     r2, =&20726944                          ; "Dir "
        |
        LD      r0, FSOpHandleFlags
        BIC     r0, r0, #4_0300                         ; Clear the LIB field
        ORR     r0, r0, #4_2100                         ; Set it to CSD, and set Swap
        ST      r0, FSOpHandleFlags
        LDR     r2, =&2062694C                          ; "Lib "
        ]
        MOV     r0, r1                                  ; Argument list
        ADR     r1, CommandBuffer
        STR     r2, [ r1 ]
        MOV     r2, #4
        BL      CopyPathNameInDoingTranslation
        LDRB    r0, [ r1, #4 ]                          ; Get leading character of argument
        TEQ     r0, #13                                 ; Is the argument null ??
        BNE     DoLibOrDirOp
        ; StarDirOfPseudoDir
        LD      r0, FSOpHandleFlags
        ANDS    r0, r0, #4_0030                         ; Get out the CSD field
        BEQ     StarDirOfURD
        TEQ     r0, #4_0020                             ; Look for LIB in CSD field
        BNE     StarDirOfCSD
        ; StarDirOfLIB
        MOV     r0, #4_0012                             ; Put LIB in URD, CSD in CSD
        B       StarDirByItselfSettingFlags

StarDirOfURD
        MOV     r0, #4_0210                             ; Defaults
        B       StarDirByItselfSettingFlags

DoStarLib
        ;       R1 => Library name to select
        ;       R6 => Special field
        BL      DealWithR6AsStarFS
        BVS     ExitStarLib
        LDRB    r0, [ r1 ]
        CMP     r0, #" "
        BLT     StarLibByItself
        LDR     r2, =&2062694C                          ; "Lib "
        MOV     r0, r1                                  ; Argument list
        ADR     r1, CommandBuffer
        STR     r2, [ r1 ]
        MOV     r2, #4
        BL      CopyPathNameInDoingTranslation
        LDRB    r0, [ r1, #4 ]                          ; Get leading character of argument
        TEQ     r0, #13                                 ; Is the argument null ??
        BEQ     StarLibOfPseudoDir
DoLibOrDirOp
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        BVS     ExitStarLib
        BL      ReadUsersEnvironment
StarLibOfLIB
StarDirOfCSD
ExitStarLib
ExitStarDir
        BL      ServiceNetFS                            ; Preserves all
        Pull    pc

StarLibByItself
        B       ExitStarLib

StarLibOfPseudoDir
        LD      r0, FSOpHandleFlags
        ANDS    r0, r0, #4_0030                         ; Get out the CSD field
        BEQ     StarLibOfURD
        TEQ     r0, #4_0020                             ; Look for LIB in CSD field
        BEQ     StarLibOfLIB
        ; StarLibOfCSD
        MOV     r0, #4_2021                             ; Put CSD in URD, LIB in CSD, and Swap
        B       StarDirByItselfSettingFlags

StarLibOfURD
        MOV     r0, #4_2120                             ; Put URD in URD, LIB in , and Swap
StarDirByItselfSettingFlags
        ST      r0, FSOpHandleFlags
StarDirByItself
        LDR     r2, =&0D726944                          ; "Dir", <CR>
        ADR     r1, CommandBuffer
        STR     r2, [ r1 ]
        MOV     r2, #4
        B       DoLibOrDirOp

DealWithR6AsStarFS
        ; Treat R6^ as if it were a *FS command rather than an
        ; indication of the context in which to execute the command
        Push    lr
        BL      ClearFSOpFlags
        TEQ     r6, #0
        Pull    pc, EQ
        Push    "r0-r4"
        MOV     r0, r6
        BL      SelectFileServer
        STRVS   r0, [ sp ]
        Pull    "r0-r4, pc"
        ]

        LTORG

DoStarOpt       ROUT
        ;       R1 => First argument
        ;       R2 => Second argument
        TEQ     r1, #4
        BEQ     SetBootOption
        TEQ     r1, #5
        BEQ     SetLibOption
BadOption
        ADR     r0, ErrorBadNetFSOption
        [       UseMsgTrans
        Pull    lr
        B       MakeError

ErrorBadNetFSOption
        DCD     ErrorNumber_BadNetFSOption
        DCB     "BadOpt", 0
        ALIGN
        |       ; UseMsgTrans
        SETV
        Pull    pc

        Err     BadNetFSOption
        ALIGN
        ]       ; UseMsgTrans

SetBootOption
        BL      MakeCurrentTemporary
        Pull    pc, VS
SetBootOptionOnTemporary
        ADR     r1, CommandBuffer
        STR     r2, [ r1 ]
        MOV     r5, r2
        MOV     r2, #1
        MOV     r0, #FileServer_SetLogOnOption
        BL      DoFSOp
        LDRVC   r4, Temporary
        STRVCB  r5, [ r4, #Context_BootOption ]
        Pull    pc

SetLibOption
        CMP     r2, #1
        BHI     BadOption
        Push    "r0-r4"                                 ; Correct entry conditions for Nasty...
        B       NastyConfigureLibOption

        LTORG

        [       OldOs
DoStarRename    ROUT
        ;       R1 ==> First argument
        ;       R2 ==> Second argument
        ;       R6 ==> Special field for first argument
        ;       R7 ==> Special field for second argument
        ;       The function entry code has already done;
        ;       BL UseNameToSetTemporary
        ;       Returning with an error if need be, or following that;
        ;       BL ClearFSOpFlags
        LDR     r3, Temporary
        MOV     r6, r7                                  ; Get the special field of the second argument
        BL      UseNameToSetTemporary
        BVS     ExitRename
        LDR     r0, Temporary                           ; Now compare with the second argument's file server
        TEQ     r3, r0
        BNE     BadRename
        MOV     r0, r1                                  ; First argument
        MOV     r7, r2                                  ; Second argument
        ADR     r1, CommandBuffer
        LDR     r3, =&616E6552                          ; "Rena"
        STR     r3, [ r1 ]
        LDR     r3, =&20656D                            ; "me "
        STR     r3, [ r1, #4 ]
        MOV     r2, #7
        BL      CopyObjectNameInDoingTranslation
        MOV     r3, #" "
        DEC     r2
        STRB    r3, [ r1, r2 ]
        INC     r2
        MOV     r0, r7                                  ; Second argument
        LD      r3, FSOpHandleFlags
        BL      CopyObjectNameInDoingTranslation
        LD      r0, FSOpHandleFlags
        TEQ     r3, r0                                  ; Were they both translated the same we ask ??
        BNE     BadRename
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        MOV     r1, #0
ExitRename
        Pull    pc

BadRename
        ADR     r0, ErrorBadNetRename
        SETV
        Pull    pc

        Err     BadNetRename
        ALIGN
        |       ; OldOs
DoStarRename    ROUT
        ;       R1 ==> First argument in cannonical form
        ;       R2 ==> Second argument in cannonical form
        ;       R6 and R7 will be zero since they are the two special fields
        ;       R1 <= 0 to say it was OK
        ;       May trash R0 and R2 to R12, LR already on stack

        ;       We need to scan the two names until they diverge, set the common part as
        ;       a directory to cache so that the sent rename command is as small as possible
        ;       E.g. *Rename &.x.y.z.Bill &.x.y.z.k.Jim becomes *Dir x.y.z *Rename Bill k.Jim
        ;       Note that *Rename &.a.b.c &.a.b.c.d is a Bad Rename and can be detected
        ;       because it would map to *Dir &.a.b.c *Rename "" d.

        MOV     r8, r2                                  ; The second argument
        BL      UseNameToSetTemporary                   ; Also converts to internal format
        BLVC    RemoveCachedDirectory
        BVS     ExitRename
        LDR     r9, Temporary                           ; Keep the context, to see if they are both the same
        MOV     r7, r1                                  ; Address of the remainder of the first argument
        MOV     r0, r1
        ADR     r1, TemporaryBuffer                     ; Make a copy so it can be modified
        MOV     r2, #0
        BL      CopyNameIn                              ; Internal first argument

        MOV     r1, r8                                  ; Restore the second canonical argument
        BL      UseNameToSetTemporary
        BVS     ExitRename

        LDR     r10, Temporary                          ; Now compare with the second argument's file server
        TEQ     r9, r10
        BNE     BadRename                               ; Arguments evaluate to different file servers!

        MOV     r2, r1                                  ; Internal second argument
        ADR     r1, TemporaryBuffer
        [       Debug
        DSTRING r1, "*Rename compares ", cc
        DSTRING r2, " with ", cc
        DLINE   "."
        ]
        MOV     r7, r1                                  ; Note the start of the string
        MOV     r8, r2                                  ; Keep the second argument as well
        LDR     r14, UpperCaseTable
RenameNameLoop
        TEQ     r14, #0
        LDRB    r3, [ r1 ], #1
        LDRNEB  r3, [ r14, r3 ]                         ; Map to upper case
        LDRB    r4, [ r2 ], #1
        LDRNEB  r4, [ r14, r4 ]                         ; Map to upper case
        CMP     r3, #" "
        MOVLE   r3, #0
        CMP     r4, #" "
        MOVLE   r4, #0
        TEQ     r3, r4
        BNE     RenameNameFails
        TEQ     r3, #0                                  ; Was this the exact match?
        BNE     RenameNameLoop                          ; If it was then that is OK
RenameNameFails
        DEC     r1                                      ; Move back to character that failed
        DEC     r2                                      ; Keep the second pointer in-sync
RenameScanBackLoop
        TEQ     r1, r7                                  ; No "." before getting back to the start
        BEQ     SkipRenameCache                         ; No equality at all
        LDRB    r14, [ r1, #-1 ]!
        DEC     r2                                      ; Keep the two pointers in-step
        EORS    r14, r14, #"."
        BNE     RenameScanBackLoop
        STRB    r14, [ r1, #0 ]                         ; Terminate the common part
        ADD     r7, r1, #1                              ; Point at the part which is different
        ADD     r8, r2, #1
        ADR     r1, TemporaryBuffer
        [       Debug
        DSTRING r1, "Common string is "
        DSTRING r7, "The first argument is now ", cc
        DSTRING r8, " the second "
        ]
        BL      CacheDirectoryName                      ; R5 is the value to use for FSOpHandleFlags
        BVS     ExitRename
        [       Debug
        BREG    r5, "CacheDirectoryName returns HandleFlags of &"
        ]
        ST      r5, FSOpHandleFlags
        ;       R7 is the pointer to the first name to use
        ;       R8 is the pointer to the second name to use
        ADR     r1, CommandBuffer
        MOV     r2, #7
        MOV     r0, r7                                  ; First argument
        BL      CopyNameIn
CopySecondNameIn
        MOV     r3, #" "
        DEC     r2
        STRB    r3, [ r1, r2 ]
        INC     r2
        MOV     r0, r8                                  ; Second argument
        BL      CopyNameIn
DoRename
        LDR     r3, =&616E6552                          ; "Rena"
        STR     r3, [ r1 ]
        LDRB    r14, [ r1, #7 ]                         ; First byte of first argument
        LDR     r3, =&0020656D                          ; "me " + CHR$0
        ORR     r3, r3, r14, LSL #24                    ; "me " + FirstByte$
        STR     r3, [ r1, #4 ]
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        MOV     r1, #0
ExitRename
        Pull    pc

SkipRenameCache
        ;       Names don't even start the same so it must be ":Name.$..." and "&..."
        ;       In this case use CopyNmaeInDoingTranslation on the "&" name
        [       Debug
        DLINE   "One name is ':Name.$...' and the other '&...'."
        ]
        ADR     r1, CommandBuffer
        MOV     r2, #7
        LDRB    r14, [ r7 ]
        TEQ     r14, #"&"                               ; Is the first name the "&" name?
        BEQ     TranslateOnlyTheFirstName
        MOV     r0, r7                                  ; First argument
        BL      CopyNameIn
        MOV     r3, #" "
        DEC     r2
        STRB    r3, [ r1, r2 ]
        INC     r2
        MOV     r0, r8                                  ; Second argument
        [       Debug
        DSTRING r0, "Translating name "
        ]
        BL      CopyObjectNameInDoingTranslation
        B       DoRename

TranslateOnlyTheFirstName
        MOV     r0, r7
        [       Debug
        DSTRING r0, "Translating name "
        ]
        BL      CopyObjectNameInDoingTranslation
        B       CopySecondNameIn

BadRename
        ADR     r0, ErrorBadNetRename
        Pull    lr
        B       MakeError

ErrorBadNetRename
        DCD     ErrorNumber_BadNetRename
        DCB     "BadRen", 0
        ALIGN
        ]       ; OldOs

        LTORG

DoStarAccess    ROUT
        ;       R1 => Object name
        ;       R2 => New access rights
        ;       R6 => Special field
        BL      UseNameToSetTemporary
        BLVC    ClearFSOpFlags
        MOVVC   r0, r1                                  ; First argument
        ADRVC   r1, CommandBuffer
        LDRVC   r3, =&65636341                          ; "Acce"
        STRVC   r3, [ r1 ]
        LDRVC   r3, =&207373                            ; "ss "
        STRVC   r3, [ r1, #4 ]
        MOVVC   r4, r2                                  ; Second argument
        MOVVC   r2, #7
        BLVC    CopyObjectNameInDoingTranslation
        MOVVC   r3, #" "
        SUBVC   r2, r2, #1
        STRVCB  r3, [ r1, r2 ]
        ADDVC   r2, r2, #1
        MOVVC   r0, r4                                  ; Second argument
        BLVC    CopyNameIn
        MOVVC   r0, #FileServer_DecodeCommand
        BLVC    DoFSOp
        MOVVC   r1, #0
        Pull    pc

        LTORG

CauseBootAction
        ADR     r0, BootCommand
        SWI     XOS_CLI
        Pull    pc

BootCommand
        DCB     "Net:%Logon Boot", 13
        ALIGN

        LTORG

        ; ***************************************
        ; ***  Normal filing system commands  ***
        ; ***************************************
        ; ***    Preserve R7-R11, R13 (sp)    ***
        ; ***************************************

AddFS_Code     ROUT
        ; R0 points to the argument(s)
        ; R1 is the number of arguments
        ; HelpForStarAddFS
        ;       *AddFS adds the given file server and disc name to those NetFS
        ;       currently knows about.  If only the station number is given then
        ;       that station will be removed from the list of known file servers.
        ; SyntaxOfStarAddFS
        ;       Syntax: *AddFS <station number> [<disc number> [:]<disc name>]
        LDR     wp, [ r12 ]
        Push    "r7-r8, lr"
        CMP     r1, #2                                  ; Check the number of arguments
        BEQ     MakeAddFSSyntaxError                    ; Legal values are 1 and 3
        BLT     RemoveGivenFS                           ; The one argument case
        MOV     r1, r0                                  ; Pointer to the station number
        BLVC    ReadStationNumber
        BVS     ExitStarAddFS
        CMP     r3, #-1                                 ; Enforce full addressing
        CMPNE   r4, #-1
        BEQ     AddFSFullStationRequired
        ORR     r4, r3, r4, LSL #8
        ADR     r5, CommandBuffer
        MOV     r0, #10 + BitTwentyNine                 ; Read in the default base (10)
        MOV     r2, #255
        SWI     XOS_ReadUnsigned
        BVS     ExitStarAddFS
        STRB    r2, [ r5 ]                              ; Store the drive number
10
        LDRB    r0, [ r1 ], #1
        TEQ     r0, #" "
        BEQ     %10                                     ; Skip spaces
        TEQ     r0, #":"                                ; Allowable first character to skip
        SUBNE   r1, r1, #1                              ; Step back if not skipping ":"
        MOV     r0, r1                                  ; The address of the disc name given
        BL      ValidateDiscName
        BVS     ExitStarAddFS
20
        LDRB    r0, [ r1 ], #1
        CMP     r0, #" "
        MOVLT   r0, #" "
        STRB    r0, [ r5, #1 ] !
        BGT     %20
        ADR     r5, CommandBuffer
        BL      UpdateCache
        B       ExitStarAddFS

ValidateDiscName                                        ; R0 points at the name
        [       UseMsgTrans
        Push    "r0, r1, r4, r5, r12, lr"               ; Push R12 to make four bytes of space
        |
        Push    "r0, r1, r4, lr"
        ]
        MOV     r4, r0                                  ; Keep original pointer, useful if error
        MOV     r1, #0
        LDRB    r0, [ r4, r1 ]
        B       FirstCharacter
ValidateNameLoop
        TEQ     r0, #"-"
        TEQNE   r0, #"_"
        TEQNE   r0, #"/"
        BEQ     ValidCharacter
        CMP     r0, #"0"
        BLT     InvalidCharacter
        CMP     r0, #"9"
        BLE     ValidCharacter
FirstCharacter
        CMP     r0, #"A"
        BLT     InvalidCharacter
        CMP     r0, #"Z"
        BLE     ValidCharacter
        CMP     r0, #"a"
        BLT     InvalidCharacter
        CMP     r0, #"z"
        BGT     InvalidCharacter
ValidCharacter
        INC     r1
        CMP     r1, #16                                 ; Test against maximum allowable length
        LDRLEB  r0, [ r4, r1 ]
        BLE     ValidateNameLoop
DiscNameTooLong
        ADR     r0, ErrorFileServerNameTooLong
        [       UseMsgTrans
        ADR     r5, TextOfSixteen
        ]
        B       ErrorInValidateDiscName

InvalidCharacter
        CMP     r0, #" "                                ; Clears V
        BLE     ExitValidateDiscName                    ; OK termination
        [       UseMsgTrans
        ADD     r5, sp, #16                             ; Address of evil character, in work frame
        STR     r0, [ r5 ]                              ; Includes terminator
        ]
        ADR     r0, ErrorBadName
ErrorInValidateDiscName
        [       UseMsgTrans
        BL      MessageTransErrorLookup2
        |
        SETV
        ]
ExitValidateDiscName
        STRVS   r0, [ sp, #0 ]
        [       UseMsgTrans
        Pull    "r0, r1, r4, r5, r12, pc"               ; Pull R12 to trash work frame
        |
        Pull    "r0, r1, r4, pc"
        ]

        [       UseMsgTrans
ErrorBadName
        DCD     ErrorNumber_BadName
        DCB     "BadName", 0
        ALIGN
ErrorFileServerNameTooLong
        DCD     ErrorNumber_FileServerNameTooLong
        DCB     "LongNam", 0
        ALIGN
TextOfSixteen
        DCB     "16", 0
        ALIGN
ErrorAddFSSyntax
        DCD     ErrorNumber_Syntax
        DCB     "SNFSAFS", 0
        ALIGN
        |
        Err     BadName
        Err     FileServerNameTooLong
        ALIGN
        ]

RemoveGivenFS
        MOV     r1, r0                                  ; Pointer to the station number
        BLVC    ReadStationNumber
        BVS     ExitStarAddFS
        CMP     r3, #-1                                 ; Enforce full addressing
        CMPNE   r4, #-1
        BEQ     AddFSFullStationRequired
        ADR     r1, NameCache - Cache_Link              ; Fake the parent pointer
RemoveGivenFSLoop
        LDR     r2, [ r1, #Cache_Link ]
        TEQ     r2, #NIL
        BEQ     ExitStarAddFS
        LDRB    r0, [ r2, #Cache_Station ]
        CMP     r0, r3                                  ; Clears V
        LDREQB  r0, [ r2, #Cache_Network ]
        CMPEQ   r0, r4
        BLEQ    DoRemoveFS
        BVS     ExitStarAddFS
        MOV     r1, r2                                  ; Keep address of parent for later
        B       RemoveGivenFSLoop

DoRemoveFS
        Push    lr
        LDR     r0, [ r2, #Cache_Link ]                 ; Next in the list
        STR     r0, [ r1, #Cache_Link ]                 ; Now pointed to by previous
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOV     r2, r1                                  ; Point back at previous so that the loop works
        Pull    pc

AddFSFullStationRequired
        ADRL    r0, ErrorUnableToDefault
        [       UseMsgTrans
        BL      MakeError
        ]
        B       ErrorExitStarAddFS

MakeAddFSSyntaxError
        [ UseMsgTrans
        ADR     r0, ErrorAddFSSyntax
        ADRL    r4, AddFSCommandName
        BL      MessageTransErrorLookup2
        |
        ADRL    r0, SyntaxOfStarAddFS
        BL      MakeSyntaxError
        ]
ErrorExitStarAddFS
        SETV
ExitStarAddFS
        Pull    "r7-r8, pc"

Free_Code      ROUT
        ; R0 points to the argument(s)
        ; R1 is the number of arguments
        LDR     wp, [ r12 ]
        Push    "r7, r8, r9, lr"
        LDRB    r1, [ r0 ]                              ; Get the first character on the line
        TEQ     r1, #":"                                ; If we have a colon then this is fsid
        MOVNE   r8, r0                                  ; Keep the UserId pointer
        LDRNE   r0, Current
        BNE     FreeOfThisContext
        ADD     r1, r0, #1                              ; Supply the first parameter as a special field
10
        LDRB    r2, [ r0 ]                              ; If the first argument is the file server name
        CMP     r2, #" "                                ; then skip to the second (optional) argument
        ADDGT   r0, r0, #1
        BGT     %10
15
        BNE     %20
        LDRB    r2, [ r0, #1 ] !
        TEQ     r2, #" "
        B       %15

20
        MOV     r8, r0                                  ; Keep the UserId pointer
        MOV     r0, r1                                  ; fsid
        LDRB    r1, [ r0 ]
        BL      IsItANumber
        MOV     r1, r0
        BNE     FreeOfNamedContext

        BL      ReadStationNumber                       ; Returns R4.R3
        BVS     ExitFromStarFree

        LDR     r0, Current
        TEQ     r0, #0
        BNE     %40                                     ; We are not in the default state so it is possible to default
        CMP     r3, #-1
        CMPNE   r4, #-1
        BNE     %45                                     ; No defaulting required
        ADRL    r0, ErrorUnableToDefault
        [       UseMsgTrans
        BL      MakeError
        ]
        B       ExitFromStarFree

40
        CMP     r3, #-1
        LDREQ   r3, [ r0, #Context_Station ]
        CMP     r4, #-1
        LDREQ   r4, [ r0, #Context_Network ]
45
        BL      FindNumberedContext                     ; Look for this context
        B       FreeOfThisContext

FreeOfNamedContext
        BL      ValidateDiscName
        BLVC    FindNamedContext                        ; From the command line (R1)
FreeOfThisContext
        BLVC    MakeContextTemporary
        BVS     ExitFromStarFree
        [       UseMsgTrans
        ADR     r1, Token_FreeHeading
        ADR     r2, TemporaryBuffer
        MOV     r3, #?TemporaryBuffer
        BL      MessageTransGSLookup0
        MOVVC   r0, r2                                  ; The passed buffer
        MOV     r1, r3                                  ; Length of the resultant string
        SWIVC   XOS_WriteN
        |       ; UseMsgTrans
        SWI     XOS_WriteS
        DCB     "Disc name       Drive  Bytes free", 10, 13, 0
        ALIGN
        BVS     ExitFromStarFree
        MOV     r0, #( DiscNameSize + 3 + 1 + 13 ) - :LEN: "Bytes used"
50
        SWI     XOS_WriteI + " "
        BVS     ExitFromStarFree
        DECS    r0
        BNE     %50
        SWI     XOS_WriteS
        DCB     "Bytes used", 10, 13, 0
        ALIGN
        ]       ; UseMsgTrans
        BVS     ExitFromStarFree
        MOV     r7, #0                                  ; Start at logical drive 0
        MOV     r9, #0                                  ; Flags, one for each drive, none yet
FreeLoop
        ADR     r1, TemporaryBuffer
        STRB    r7, [ r1, #0 ]
        MOV     r0, #(?TemporaryBuffer - 2) / 17
        STRB    r0, [ r1, #1 ]
        MOV     r2, #2
        MOV     r0, #FileServer_DiscName
        BL      DoFSOp
        BVS     ExitFromStarFree
        LDRB    r5, [ r1 ]                              ; Number to process
        TEQ     r5, #0                                  ; If there were none returned
        BEQ     PrintUserFreeSpace                      ; We have had them all
        ADD     r7, r7, r5                              ; Calculate where to start from next time
        ADD     r4, r1, #1                              ; Point to this record
        MOV     r14, #0                                 ; Flag for first entry, cleared by any "action"
FreeDiscLoop
        LDRB    r6, [ r4 ], #1                          ; The returned drive number
        MOV     r0, #1
        MOV     r0, r0, LSL r6                          ; A single bit for the drive number
        TST     r9, r0
        ORREQ   r9, r9, r0                              ; New drive number, mark as seen
        BEQ     %65
        ADD     r4, r4, #16                             ; Move past this old drive
        DECS    r5
        BNE     FreeDiscLoop
        TEQ     r14, #0                                 ; Did we do anything this time around
        BNE     FreeLoop                                ; Yes, get some more names
        B       PrintUserFreeSpace                      ; No so we must have done it all

65
        SWI     XOS_NewLine
        BVS     ExitFromStarFree
        MOV     r3, #0
70
        LDRB    r0, [ r4 ], #1
        SWI     XOS_WriteC
        BVS     ExitFromStarFree
        TEQ     r0, #" "
        MOVEQ   r0, #13
        STRB    r0, [ r1, r3 ]
        INC     r3
        MOVNE   r2, r3                                  ; Send only as much as up to the first CR
        TEQ     r3, #16
        BNE     %70
        INC     r2
        MOV     r0, #FileServer_ReadDiscFreeSpace
        BL      DoFSOp
        BVS     ExitFromStarFree
        MOV     r0, #"0"
75
        DECS    r6, 100
        ADDPL   r0, r0, #1
        BPL     %75
        INC     r6, 100
        TEQ     r0, #"0"
        MOVEQ   r0, #" "
        SWI     XOS_WriteC
        BVS     ExitFromStarFree
        MOV     r0, #"0"
80
        DECS    r6, 10
        ADDPL   r0, r0, #1
        BPL     %80
        INC     r6, 10
        TEQ     r0, #"0"
        MOVEQ   r0, #" "
        SWI     XOS_WriteC
        BVS     ExitFromStarFree
        MOV     r0, #"0"
85
        DECS    r6, 1
        ADDPL   r0, r0, #1
        BPL     %85
        SWI     XOS_WriteC
        BVS     ExitFromStarFree
        LDR     r0, [ r1 ]                              ; Get 24 bit free space (in sectors)
        MOV     r3, r0, ASR #16                         ; Move High byte to MidLow byte
        AND     r3, r3, #&0000FF00                      ; Leave for later
        myASL   r0, 8                                   ; Change a number of sectors to a number of bytes
        BL      PrintDecimalNumber
        BVS     ExitFromStarFree
        LDR     r6, [ r1, #4 ]
        myLSL   r6, 16
        ORR     r6, r6, r3                              ; Make the disc size, in bytes
        SUB     r0, r6, r0                              ; Calculate the amount used
        MOV     r3, #( DiscNameSize + 2 )
90
        SWI     XOS_WriteI + " "
        BVS     ExitFromStarFree
        DECS    r3
        BPL     %90
        BL      PrintDecimalNumber
        BVS     ExitFromStarFree
        DECS    r5                                      ; Have we finished processing this lot yet
        BNE     FreeDiscLoop                            ; No, process another one
        B       FreeLoop                                ; Yes, so get some more

PrintUserFreeSpace
        MOV     r0, r8                                  ; Get the UserId pointer
        ADR     r1, TemporaryBuffer
        MOV     r2, #0
        BL      CopyNameIn
        MOV     r0, #FileServer_ReadUserFreeSpace
        BL      DoFSOp
        BVS     ExitFromStarFree
        MOV     r0, #( DiscNameSize + 3 + 1 + 13 )
95
        SWI     XOS_WriteI + "-"
        BVS     ExitFromStarFree
        DECS    r0
        BNE     %95
        [       UseMsgTrans
        ADR     r1, Token_FreeSpace
        ADRL    r2, BigTextBuffer
        MOV     r3, #?BigTextBuffer
        BL      MessageTransGSLookup0
        MOVVC   r0, r2                                  ; The passed buffer
        MOVVC   r1, r3                                  ; Length of the resultant string
        SWIVC   XOS_WriteN
        |       ; UseMsgTrans
        SWI     XOS_WriteS
        DCB     10, 13, "User free space    ", 0
        ALIGN
        ]       ; UseMsgTrans
        LDRVC   r0, TemporaryBuffer
        BLVC    PrintDecimalNumber
ExitFromStarFree
        Pull    "r7, r8, r9, pc"

        [       UseMsgTrans
Token_FreeHeading
        DCB     "FreeHed", 0
Token_FreeSpace
        DCB     "FreeSpc", 0
        ALIGN
        ]       ; UseMsgTrans

PrintDecimalNumber ROUT
        ;       R0 = Number to be printed
        ;       Trashes R2, TextBuffer
        ;       Prints the string right justified in a 14
        ;       character field followed by a NewLine
        Push    "r0, r1, lr"
        ADR     r1, TextBuffer
        MOV     r2, #14
        [       OldOs
        SWI     XOS_ConvertSpacedCardinal4
        |
        BL      ConvertFormattedCardinal4
        ]
        BVS     %90
70
        DECS    r2
        BMI     %80
        SWI     XOS_WriteI + " "
        BVS     %90
        B       %70

80
        SWI     XOS_Write0
        SWIVC   XOS_NewLine
90
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r1, pc"

        [       :LNOT: OldOs
ConvertFormattedCardinal4 ROUT
        ;       R0 is the value to convert
        ;       R1 is the buffer to convert into
        ;       R2 is the buffer size
        ;       Returns
        ;       R0 entry value of R1
        ;       R1 pointer to terminating zero
        ;       R2 size remaining in buffer, R2'=R2-(R1'-R0')

FormatFrameSize * 16

        Push    "r1, r2, r3, r4-r9, lr"                 ; R3 only there to make frame right
        DEC     sp, FormatFrameSize                     ; Frame for doing the conversion into
        MOV     r1, sp
        MOV     r2, #FormatFrameSize - 1
        SWI     XOS_ConvertCardinal4
        SUBVC   r4, r1, r0                              ; Calculate the number of digits returned
        MOVVC   r0, #-1                                 ; Current territory
        MOVVC   r1, #1                                  ; Thousands separator
        SWIVC   XTerritory_ReadSymbols
        MOVVC   r5, r0                                  ; Save pointer
        MOVVC   r0, #-1                                 ; Current territory
        MOVVC   r1, #2                                  ; Character grouping
        SWIVC   XTerritory_ReadSymbols
        BVS     ExitConvertFormatted
        MOV     r6, r0                                  ; Save pointer
        SUB     r7, r5, #1                              ; Measure the separator string
SeparatorCountLoop
        LDRB    r0, [ r7, #1 ]!
        TEQ     r0, #0
        BNE     SeparatorCountLoop
        SUB     r7, r7, r5                              ; Compute the length
        ; Work out how long the result will be
        MOV     r8, r4                                  ; Length of result
        MOV     r9, r6                                  ; Grouping format pointer
        MOV     r2, #0                                  ; Current group size
        MOV     r1, #0                                  ; Distance along the source
FormatCountLoop
        LDRB    r14, [ r9 ]
        TEQ     r14, #0
        MOVNE   r2, r14                                 ; Use this grouping
        ADDNE   r9, r9, #1                              ; Ready for the next grouping
        TEQ     r2, #0                                  ; Don't do anything if format defective
        BEQ     FormatCountDone
        ADD     r1, r1, r2
        CMP     r1, r4                                  ; Would this group put us beyond the string?
        ADDCC   r8, r8, r7                              ; Add the separator length to the string
        BCC     FormatCountLoop
FormatCountDone
        ADD     r14, sp, #FormatFrameSize               ; Entry R1
        LDMIA   r14, { r1, r2 }
        SUB     r2, r2, r8
        CMP     r2, #1                                  ; Allow for the terminating zero
        ADRMIL  r0, ErrorCDATBufferOverflow
        BLMI    MakeError
        BVS     ExitConvertFormatted
        ADD     r1, r1, r8
        ADD     r14, sp, #FormatFrameSize + 4           ; Exit R1
        STMIA   r14, { r1, r2 }
        ADD     r4, sp, r4                              ; Trailing zero of converted source string
        MOV     r2, #0                                  ; Current group size
        STRB    r0, [ r1 ], #-1                         ; Put the terminator on the destination
FormatCopyLoop
        LDRB    r14, [ r6 ]
        TEQ     r14, #0
        MOVNE   r2, r14                                 ; Use this grouping
        ADDNE   r6, r6, #1                              ; Ready for the next grouping
        TEQ     r2, #0                                  ; Don't do anything if format defective
        MOVEQ   r2, #-1
        MOV     r9, r2                                  ; R2 is the number of chars to copy across
CharacterCopyLoop
        LDRB    r14, [ r4, #-1 ]!
        STRB    r14, [ r1 ], #-1
        TEQ     r4, sp                                  ; Have we reached the last character?
        BEQ     FinishConvertFormatted
        SUBS    r9, r9, #1
        BNE     CharacterCopyLoop
        MOVS    r0, r7                                  ; Length of the separator
        BEQ     CharacterCopyLoop                       ; No separator to copy
SeparatorCopyLoop
        SUBS    r0, r0, #1
        LDRB    r14, [ r5, r0 ]
        STRB    r14, [ r1 ], #-1
        BNE     SeparatorCopyLoop
        B       FormatCopyLoop                          ; Start back again

FinishConvertFormatted
        CLRV
ExitConvertFormatted
        INC     sp, FormatFrameSize
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r1, r2, r4-r9, pc"
        ]

FS_Code        ROUT
        ;       R0 => Pointer to the argument(s)
        ;       R1 => Count of the number of arguments
        LDR     wp, [ r12 ]
        TEQ     r1, #0
        BEQ     ReportFSNumbersAndNames
SelectFileServer                                        ; Called from *Dir/*Lib
        [       Debug
        DSTRING r0, "Do *FS "
        ]
        Push    lr
        LDRB    r1, [ r0 ]
        TEQ     r1, #":"                                ; Ignore leading colon
        ADDEQ   r0, r0, #1
        LDREQB  r1, [ r0 ]
        BL      IsItANumber
        BNE     %20
        MOV     r1, r0                                  ; Address of command tail
        BL      ReadStationNumber                       ; Returns R4.R3
        Pull    pc, VS                                  ; Return because of error
        LDR     r0, Current
        TEQ     r0, #0
        BNE     %10
        CMP     r3, #-1
        CMPNE   r4, #-1
        BNE     %10
        B       ExitUnableToDefault

10
        MOV     r1, r4
        CMP     r1, #-1
        LDREQ   r1, [ r0, #Context_Network ]
        MOV     r0, r3
        CMP     r0, #-1
        LDREQ   r0, [ r0, #Context_Station ]
        SWI     XNetFS_SetFSNumber
        Pull    pc

20
        SWI     XNetFS_SetFSName                        ; Find named FS
        Pull    pc

ReportFSNumbersAndNames ROUT
        Push    lr
        LDR     r10, Current
        TEQ     r10, #0                                 ; Have we never logged on before??
        BNE     %10                                     ; Not the easy case
        BL      TextualiseConfiguration
        ADR     r0, LogonDisc
        SWI     XOS_Write0
        SWIVC   XOS_NewLine
        B       ExitFromStarFSList
10
        LDR     r11, =ContextIdentifier
        LDR     r0, [ r10, #Context_Identifier ]
        TEQ     r0, r11
        BNE     FSListNoId

        LDR     r0, [ r10, #Context_RootDirectory ]
        TEQ     r0, #0
        BNE     %20                                     ; Treat current as a normal FS
        ADD     r0, r10, #Context_Station               ; Address of number to be converted
        DEC     sp, 12                                  ; Space for the result of the conversion
        MOV     r1, sp                                  ; Base of stack frame
        MOV     r2, #11
        SWI     XOS_ConvertFixedNetStation
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        INC     sp, 12                                  ; Get rid of the data
        BVS     ExitFromStarFSList
        B       FSListBegin

20
        BL      FSListPrintRegardless
FSListBegin
        LDR     r10, Contexts
FSListLoop
        TEQ     r10, #NIL
        BEQ     ExitFromStarFSList
        BL      FSListPrint
        BVS     ExitFromStarFSList
        LDR     r10, [ r10, #Context_Link ]
        B       FSListLoop

FSListNoId
        ADRL    r0, ErrorNetFSInternalError
        [       UseMsgTrans
        BL      MakeErrorWithModuleName
        |
        SETV
        ]
ExitFromStarFSList
        Pull    pc

FSListPrint
        LDR     r0, [ r10, #Context_Identifier ]
        TEQ     r0, r11
        BNE     FSListNoId
        LDR     r0, Current
        CMP     r10, r0
        MOVEQ   pc, lr
FSListPrintRegardless
        LDR     r0, [ r10, #Context_RootDirectory ]
        CMP     r0, #0
        MOVEQ   pc, lr
        Push    lr
        ADD     r0, r10, #Context_Station               ; Address of number to be converted
        DEC     sp, 12                                  ; Space for the result of the conversion
        MOV     r1, sp                                  ; Base of stack frame
        MOV     r2, #11
        SWI     XOS_ConvertFixedNetStation
        SWIVC   XOS_Write0
        INC     sp, 12                                   ; Get rid of the data
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     " :", 0
        ALIGN
        Pull    pc, VS
        ADD     r0, r10, #Context_DiscName
        TEQ     r0, #0
        Pull    pc, EQ
        MOV     r1, #0
70
        LDRB    r14, [ r0, r1 ]
        CMP     r14, #" "
        ADDGT   r1, r1, #1
        BGT     %70
        SWI     XOS_WriteN
        SWIVC   XOS_WriteI + " "
        Pull    pc, VS
        ADD     r0, r10, #Context_UserId
        TEQ     r0, #0
        Pull    pc, EQ
        MOV     r1, #0
80
        LDRB    r14, [ r0, r1 ]
        CMP     r14, #" "
        ADDGT   r1, r1, #1
        BGT     %80
        SWI     XOS_WriteN
        SWIVC   XOS_NewLine
        Pull    pc

        LTORG

Mount_Code     ROUT
SDisc_Code
        Push    "lr"
        ;       R0 => Pointer to the argument(s)
        ;       R1 => Count of the number of arguments
        LDR     wp, [ r12 ]
        MOV     r10, r0                                 ; Save the argument pointer
        BL      ValidateDiscName
        BLVC    MakeCurrentTemporary
        Pull    "pc",VS                                 ; Exit with error
        BL      ClearFSOpFlags
        ADR     r1, CommandBuffer
        LDR     r2, =&73694453                          ; "SDis"
        STR     r2, [ r1 ]
        LDR     r2, =&2063                              ; "c "
        STR     r2, [ r1, #4 ]
        MOV     r2, #6
        MOV     r0, r10                                 ; Pointer to the original argment
        BL      CopyLineIn
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        BLVC    ReadUsersEnvironment
        BLVC    SelectLibrary
        BL      ServiceNetFS                            ; Preserves all, including errors
        Pull    "pc"

        LTORG

Bye_Code       ROUT
        LDR     wp, [ r12 ]
        TEQ     r1, #0                                  ; Did we get an argument ??
        LDREQ   r0, Current                             ; No, so use the current FS
        BEQ     LogoffGivenFileServer
        Push    lr                                      ; Ready to call other procedures
        LDRB    r1, [ r0 ]
        TEQ     r1, #":"                                ; Ignore leading colon
        LDREQB  r1, [ r0, #1 ] !
        BL      IsItANumber
        MOV     r1, r0                                  ; Address of command tail
        BNE     LogoffByName
        BL      ReadStationNumber                       ; Returns R4.R3
        Pull    pc, VS                                  ; Return because of error

        LDR     r0, Current
        TEQ     r0, #0
        BNE     %10                                     ; We are not in the default state so it is possible to default
        CMP     r3, #-1
        CMPNE   r4, #-1
        BNE     %20                                     ; No defaulting required
        B       ExitUnableToDefault

10
        CMP     r3, #-1
        LDREQ   r3, [ r0, #Context_Station ]
        CMP     r4, #-1
        LDREQ   r4, [ r0, #Context_Network ]
20
        BL      FindNumberedContext                     ; Look for this context
        BLVS    CreateNumberedContext                   ; If it wasn't there make it
        Pull    pc, VS                                  ; Error here is fatal
        B       DoLogoff

LogoffByName
        BL      ValidateDiscName
        BLVC    FindNamedContext
        Pull    pc, VS
DoLogoff
        Pull    lr                                      ; Note the drop through

        ;       *************************************
        ;       ***   Logoff from a file server   ***
        ;       *************************************

        ;       R0 => Pointer to the context record, which is free'd
        ;       Trashed R0, R1, R2, R3, R4

LogoffGivenFileServer                                   ; Called from ShutDown
        [       Debug
        DREG    r0, "Log off the context at &"
        ]
        CMP     r0, #0                                  ; Is there a context here?
        MOVEQ   pc, lr                                  ; No, so exit
        Push    lr
        STR     r0, Temporary
        ADD     r0, r0, #Context_DiscName               ; Get a copy of the FS name
        ADR     r1, TextBuffer
        MOV     r2, #0
        BL      CopyNameIn
        DEC     r2
        MOV     r0, #0
        STRB    r0, [ r1, r2 ]
        MOV     r4, #10                                 ; Maximum number of times to call
30
        BL      PurgeFileServer
        BVC     %40                                     ; It went OK
        BL      ErrorAsLogoffWarning
        Pull    pc, VS                                  ; Return because of serious error
        DECS    r4
        BNE     %30                                     ; If not done; call again
40
        MOV     r0, #FileServer_LogOff
        ADR     r1, CommandBuffer
        MOV     r2, #0
        BL      DoFSOp                                  ; Change *Bye to always remove the context
        MOVVC   r4, #0                                  ; Indicate the no error situation
        MOVVS   r4, r0                                  ; Save error indication
        LDR     r0, Temporary
        LDR     r1, Current
        [       Debug
        DREG    r0, "Temporary = &"
        DREG    r1, "Current   = &"
        ]
        TEQ     r0, r1                                  ; Is it the current FS we are logging off?
        BEQ     %50
        BL      RemoveContext                           ; Not current so blow it away
        B       %60

50
        BL      EmptyContext                            ; Was current so leave only the number
60
        BVC     %70
        TEQ     r4, #0                                  ; Check for pre-existing error
        MOVEQ   r4, r0                                  ; There wasn't one so there is now
70
        BL      ServiceNetFS                            ; Preserves all
        MOVS    r0, r4
        SETV    NE
        Pull    pc                                      ; Return, maybe with error

        ; ****************************************************
        ; ***  Does a backdoor close on all open files     ***
        ; ***  associated with the Temporary file server.  ***
        ; ***  Also dismounts all the discs on the FS      ***
        ; ***  Called from *Bye and *Logon                 ***
        ; ****************************************************

PurgeFileServer ROUT
        [       OldOs
        Push    "r0, r1, lr"
        |
        Push    "r0-r5, lr"
        ]
        LDR     r3, Temporary
        ADD     r3, r3, #Context_Station
        LDMIA   r3, { r3, r4 }                          ; PurgeForThisFileServer
        [ :LNOT: OldOs
        DEC     sp, SmallBufferSize                     ; Local buffer space
        LDR     r0, =&3A74654E                          ; "Net:"
        STR     r0, [ sp, #0 ]
        MOV     r0, #":"
        STRB    r0, [ sp, #4 ]                          ; Now "Net::"

        ADR     r5, NameCache - Cache_Link

DismountServerLoop
        LDR     r5, [ r5, #Cache_Link ]
        TEQ     r5, #NIL
        BEQ     NoMoreDismounts
        LDRB    r14, [ r5, #Cache_Network ]
        TEQ     r14, r4                                 ; Check against the temporary network
        LDREQB  r14, [ r5, #Cache_Station ]
        TEQEQ   r14, r3                                 ; Check against the temporary station
        BNE     DismountServerLoop
        ADD     r0, r5, #Cache_Name                     ; Name to use
        ADD     r1, sp, #5                              ; Address to copy name to
DismountNameLoop
        LDRB    r14, [ r0 ], #1
        CMP     r14, #" "
        MOVLS   r14, #0
        STRB    r14, [ r1 ], #1
        BHI     DismountNameLoop
        MOV     r1, #Service_DiscDismounted
        MOV     r2, sp
        [       Debug
        DSTRING r2, "Dismounting disc "
        ]
        SWI     XOS_ServiceCall
        B       DismountServerLoop

NoMoreDismounts
        CLRV                                            ; Junk any error
        INC     sp, SmallBufferSize
        ]

10
        LDR     r3, Temporary
        ADD     r0, wp, #( ( :INDEX: FCBs ) - FCB_Link )
20
        LDR     r0, [ r0, #FCB_Link ]
        TEQ     r0, #NIL
        BNE     %30                                     ; This is a record
        CLRV
        B       ExitFromPurge

30
        LDR     r1, [ r0, #FCB_Context ]
        TEQ     r1, r3
        BNE     %20                                     ; Still no match
        LDRB    r1, [ r0, #FCB_TuTuHandle ]
        MOV     r0, #0                                  ; Do a close
        SWI     XOS_Find
        BVC     %10                                     ; See if there are any others
ExitFromPurge
        STRVS   r0, [ sp ]
        [       OldOs
        Pull    "r0, r1, pc"
        |
        Pull    "r0-r5, pc"
        ]

        LTORG

ListFS_Code    ROUT
        MOV     r6, lr
        LDR     wp, [ r12 ]
        TEQ     r1, #0                                  ; Check for an argument
        BLNE    FlushNameCache                          ; There is one (-force)
        BL      FillCache
        [       Debug
        BVC     %97
        ADD     r14, r0, #4
        DSTRING r14, "FillCache returns "
        MOV     pc, r6
97
        ]
        BLVC    StopCache
        [       Debug
        BVC     %98
        ADD     r14, r0, #4
        DSTRING r14, "StopCache returns "
98
        ]
        MOVVS   pc, r6
        LDR     r5, NameCache
        TEQ     r5, #NIL
        MOVEQ   pc, r6
ListFSLoop
        ADR     r1, TextBuffer
        MOV     r2, #?TextBuffer
        LDRB    r4, [ r5, #Cache_Network ]
        LDRB    r3, [ r5, #Cache_Station ]
        Push    "r3, r4"
        MOV     r0, sp
        SWI     XOS_ConvertFixedNetStation
        INC     sp, 8
        SWIVC   XOS_Write0
        SWIVC   XOS_WriteI + " "
        SWIVC   XOS_WriteI + ":"
        LDRVCB  r0, [ r5, #Cache_Drive ]
        ADRVC   r1, TextBuffer
        MOVVC   r2, #?TextBuffer
        SWIVC   XOS_ConvertCardinal1
        SWIVC   XOS_Write0
        SWIVC   XOS_WriteI + " "
        ADDVC   r0, r5, #Cache_Name
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        MOVVS   pc, r6
        LDR     r5, [ r5, #Cache_Link ]
        TEQ     r5, #NIL
        BNE     ListFSLoop
        BL      EnableCache
        CLRV
        MOV     pc, r6

FillCache
        Push    lr
        LDR     r14, NameCache
        TEQ     r14, #NIL
        Pull    pc, NE
ForceFillCache                                          ; Entered here with "LR" already on the stack
        Push    "r0, r4"
        BL      FlushAnotherTxList
        BL      BroadcastForNames
        [       Debug
        BVC     %99
        ADD     r14, r0, #4
        DSTRING r14, "BroadcastForNames returns an error "
99
        ]
        SWIVC   XOS_ReadMonotonicTime
        BVS     FillCacheFails
        LDR     r4, FSBroadcastDelay
        ADD     r4, r0, r4                              ; Work out end time for later
        MOV     r0, #NetFS_StartWait
        BL      DoUpCall
        BVS     FillCacheFails
        WritePSRc USR_mode, r0
FillCacheTimeLoop
        SWI     XOS_ReadMonotonicTime
        BVS     ExitFillCacheLoop
        CMP     r0, r4                                  ; Have the five seconds passed
        BLT     FillCacheTimeLoop
        SWI     XOS_EnterOS                             ; Return to SVC mode
        MOVVC   r0, #NetFS_FinishWait
        BLVC    DoUpCall
        BVS     FillCacheFails
 ; ExitFillCache
        CLRV
FillCacheFails
        STRVS   r0, [ sp ]
        Pull    "r0, r4, pc"

ExitFillCacheLoop
        MOV     r4, r0
        SWI     XOS_EnterOS                             ; Return to SVC mode
        MOV     r0, #NetFS_FinishWait
        BL      DoUpCall
        MOV     r0, r4
        SETV
        B       FillCacheFails

Pass_Code ROUT
        ;       R0 => Pointer to the argument(s)
        ;       R1 => Count of the number of arguments
        LDR     wp, [ r12 ]
        Push    lr
        MOV     r5, r1                                  ; Keep this so we know what to do
        MOV     r10, r0
        BL      MakeCurrentTemporary
        Pull    pc, VS
        BL      ClearFSOpFlags
        ADR     r1, CommandBuffer
        LDR     r2, =&73736150                          ; "Pass"
        STR     r2, [ r1 ]
        LDR     r2, =&20                                ; " "
        STR     r2, [ r1, #4 ]
        MOV     r2, #5
        MOV     r0, R10
        BL      CopyLineIn
        MOV     r14, #" "
        DEC     r2                                      ; Move back over the terminator
        STRB    r14, [ r1, r2 ]                         ; Stick in a space
        INC     r2                                      ; Include the space
        MOV     r14, #13
        STRB    r14, [ r1, r2 ]                         ; Terminate it just in case
        CMP     r5, #1                                  ; How many arguments on the original input line?
        ADDGT   r2, r2, #1                              ; Better send the CR
        BGT     SendPasswordsOff                        ; User supplied both on the command line
        BEQ     GetNewPassword
        Push    r2
        ADRL    r0, Password
        MOV     r1, #?Password
        BL      GetInvisibleOldPassword
        Pull    r2
        Pull    pc, VS
        TEQ     r1, #0                                  ; No input?
        BLEQ    AddNullPassword
        ADR     r1, CommandBuffer
        BL      CopyNameIn
        MOV     r14, #" "
        DEC     r2
        STRB    r14, [ r1, r2 ]
        INC     r2
GetNewPassword
        Push    r2
        ADRL    r0, Password
        MOV     r1, #?Password
        BL      GetInvisibleNewPassword
        Pull    r2
        Pull    pc, VS
        TEQ     r1, #0                                  ; No input?
        BLEQ    AddNullPassword
        ADR     r1, CommandBuffer
        BL      CopyNameIn
SendPasswordsOff
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        Pull    pc

AddNullPassword
        MOV     r3, #""""
        STRB    r3, [ r0, #0 ]
        STRB    r3, [ r0, #1 ]
        MOV     r3, #0
        STRB    r3, [ r0, #2 ]
        MOV     pc, lr

        LTORG

        ;       *************************
        ;       ***   Do Star Logon   ***
        ;       *************************
Logon_Code     ROUT
        ;       R0 => Pointer to the argument(s)
        ;       R1 => Count of the number of arguments
        Push    "lr"
        [       Debug
        DSTRING r0, "Logon command as passed in = "
        ]
        LDR     wp, [ r12 ]
        MOV     r14, #0
        STRB    r14, LogonDisc
        STRB    r14, Password
        BL      ClearFSOpFlags
        LDRB    r1, [ r0 ]                              ; Get the first byte of the first argument
        TEQ     r1, #":"                                ; Is the forcing character there?
        ADDEQ   r0, r0, #1                              ; Skip over the ":"
        BEQ     CopyAwayFileServerNameOrNumber
        BL      IsItANumber
        BNE     SortOutLogonName
CopyAwayFileServerNameOrNumber
        LDRB    r1, [ r0 ]                              ; Get the first byte of the actual argument
        BL      IsItANumber
        BEQ     DontValidateANumber
        MOV     r3, r0                                  ; Save pointer
        ADR     r1, CommandBuffer                       ; Copy to command buffer to terminate properly
        MOV     r2, #0
        BL      CopyNameIn
        ADR     r0, CommandBuffer                       ; Validate the terminated copy
        BLVC    ValidateDiscName
        BVS     ExitFromStarLogon
        MOV     r0, r3                                  ; Restore pointer
DontValidateANumber
        ADR     r1, LogonDisc
        MOV     r2, #0
        BL      CopyNameIn
        DEC     r0
FindLogonName
        LDRB    r1, [ r0 ]                              ; Scan looking for the next argument
        CMP     r1, #" "
        ADDEQ   r0, r0, #1
        BEQ     FindLogonName
        BLT     MakeLogonSyntaxError                    ; If it isn't found then go bang
SortOutLogonName
        ADR     r1, LogonName
        MOV     r2, #0
        BL      CopyNameIn
        DEC     r0
FindPassword
        LDRB    r1, [ r0 ]                              ; Scan looking for the next argument
        CMP     r1, #" "
        ADDEQ   r0, r0, #1
        BEQ     FindPassword
        BLT     LogonInputOrganised
        TEQ     r1, #":"
        BNE     PlainPassword
        ADRL    r0, Password
        MOV     r1, #?Password
        BL      GetInvisiblePassword
        BVS     ExitFromStarLogon
        B       LogonInputOrganised

MakeLogonSyntaxError
        [ UseMsgTrans
        ADR     r0, ErrorLogonSyntax
        ADRL    r4, LogonCommandName
        BL      MessageTransErrorLookup2
        |
        ADRL    r0, SyntaxOfStarLogon
        BL      MakeSyntaxError
        ]
AbortStarLogon
        SETV
        B       ExitFromStarLogon

        [ UseMsgTrans
ErrorLogonSyntax
        DCD     ErrorNumber_Syntax
        DCB     "SNFSLON", 0
        ALIGN
        |
MakeSyntaxError
        ;       R0 => Pointer to the relevant syntax message
        ;       R0 <= Pointer to an error block
        Push    "r1, lr"
        ADR     r1, ErrorBuffer
        LDR     r14, =ErrorNumber_Syntax
        STR     r14, [ r1 ], #4
SyntaxErrorLoop
        LDRB    r14, [ r0 ], #1
        STRB    r14, [ r1 ], #1
        TEQ     r14, #0
        BNE     SyntaxErrorLoop
        ADR     r0, ErrorBuffer
        Pull    "r1, pc"
        ]

PlainPassword
        ADRL    r1, Password
        MOV     r2, #0
        BL      CopyLineIn
LogonInputOrganised
        ; At this point the optional first field (the file server Id) is in
        ; 'LogonDisc' if there was none then the buffer has a zero in it.
        ; The user name is in 'LogonName', if a plain password was given
        ; or if a secret password was asked for then it is in 'Password'.
        ; If no password has been given then the buffer has a zero in it.
        ;
        ; We now need to resolve the file server number to use.
        ; If an Id was offered then use it.
        ; If there wasn't one and there is no current FS use the configuration
        ; as if it had been given (by copying it as text into LogonDisc).
        ; If there wasn't and Id, but there is a current FS use the current FS.
        [       Debug
        ADR     r0, LogonDisc
        DSTRING r0, "LogonDisc = "
        ADR     r0, LogonName
        DSTRING r0, "LogonName = "
        ADR     r0, Password
        DSTRING r0, "Password  = "
        ]
        ADR     r3, LogonDisc
        LDRB    r0, [ r3 ]                              ; Was a file server Id offered ??
        TEQ     r0, #0
        BNE     ResolveSuppliedFSId
        LDR     r14, Current
        [       Debug
        DREG    r14, "Current is at &"
        ]
        TEQ     r14, #0                                 ; Zero means there is no current FS
        STRNE   r14, Temporary
        BNE     LogonToTemporaryFileServer
        BL      TextualiseConfiguration
        [       Debug
        ADR     r14, LogonDisc
        DSTRING r14, "Default is "
        ]
ResolveSuppliedFSId
        LDRB    r1, LogonDisc                           ; Get the first byte of the supplied argument
        BL      IsItANumber
        BNE     LogonToNamedFileServer
        ADR     r1, LogonDisc                           ; LogonToNumberedFileServer
        BL      ReadStationNumber
        BVS     ExitFromStarLogon
        LDR     r14, Current
        TEQ     r14, #0
        BNE     DefaultFromCurrentContext
        CMP     r3, #-1
        BEQ     %70
        CMP     r4, #-1
        BNE     DefaultFromCurrentContext
70 ; An incomplete address is supplied as the first thing ever
        MOV     r1, #NetFSIDCMOS
        BL      MyReadCMOS
        BVS     ExitFromStarLogon
        TEQ     r2, #0                                  ; Stored station zero ??
        BEQ     ExitUnableToDefault                     ; Not able to default since configured FS is a name
        CMP     r3, #-1                                 ; Was it the station number that wasn't given?
        MOVEQ   r3, r2                                  ; Yes => default station
        BEQ     DefaultFromCurrentContext               ; Then go on as before
        MOV     r1, #NetFSIDCMOS + 1                    ; Else it MUST have been the net number not given
        BL      MyReadCMOS
        BVS     ExitFromStarLogon
        MOV     r4, r2                                  ; Default the network number
DefaultFromCurrentContext
        LDR     r14, Current
        CMP     r3, #-1
        LDREQ   r3, [ r14, #Context_Station ]
        CMP     r4, #-1
        LDREQ   r4, [ r14, #Context_Network ]
        B       FileServerNumberResolved

LogonToNamedFileServer ROUT
        [       Debug
        ADR     r14, LogonDisc
        DSTRING r14, "Resolving "
        ]
        BL      ResolveFileServerName
        BVS     ExitFromStarLogon
FileServerNumberResolved
        [       Debug
        BREG    r4, "Number is now &", cc
        BREG    r3, ".&"
        ]
        BL      FindNumberedContext
        BLVS    CreateNumberedContext                   ; If it wasn't there make it
        BVS     ExitFromStarLogon
        [       Debug
        DREG    r0, "Context is at &"
        ]
        STR     r0, Temporary
LogonToTemporaryFileServer
        ;       At this point the Temporary file server is a viable record
        ;       either it is a new record with only the number in or it is
        ;       the existing record for this file server (from a previous logon)
        BL      PeekFileServer
        BLVC    PurgeFileServer
        BVS     ExitFromStarLogon
        [       Debug
        DLINE   "Purged OK"
        ]
ReTryLogon
        [       Debug
        ADR     r0, LogonDisc
        DSTRING r0, "LogonDisc = "
        ADR     r0, LogonName
        DSTRING r0, "LogonName = "
        ADR     r0, Password
        DSTRING r0, "Password  = "
        ]
        ADR     r1, CommandBuffer
        LDR     r2, =&6d612049                          ; "I am"
        STR     r2, [ r1 ]
        LDR     r2, =&20                                ; " "
        STR     r2, [ r1, #4 ]
        MOV     r2, #5
        ADR     r0, LogonName
        BL      CopyNameIn
        DEC     r2
        MOV     r0, #" "
        STRB    r0, [ r1, r2 ]
        INC     r2
        ADRL    r0, Password
        BL      CopyLineIn
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        BVC     LogonIsOK                               ; Check the error status
        LDR     r1, [ r0 ]
        LDR     r14, =&000105BB                         ; The wrong password error number
        TEQ     r1, r14
        BNE     StarLogonFails
        LDRB    r14, Password                           ; Is there a password there ??
        TEQ     r14, #0                                 ; Never was a password
        BNE     StarLogonFails
        ADRL    r0, Password
        MOV     r1, #?Password
        BL      GetInvisiblePassword
        BVS     ExitFromStarLogon
        B       ReTryLogon

StarLogonFails
        LDR     r14, =&00FFFF00
        AND     r1, r14, r1                             ; Work out who caused the error
        LDR     r14, =&00010500
        TEQ     r1, r14                                 ; Was it the file server ??
        MOV     r1, r0                                  ; Preserve the error
        LDREQ   r0, Temporary
        BLEQ    EmptyContext                            ; Yes, so blat any context on this file server
        BL      ObliteratePassword
        MOV     r0, r1                                  ; Restore the original error
        B       AbortStarLogon                          ; No it wasn't so assume we might still be logged on

LogonIsOK
        [       Debug
        DLINE   "Logged on OK, obliterating password"
        ]
        BL      ObliteratePassword
        CLRV                                            ; In case we exit below
        LDR     r4, Temporary
        STR     r4, Current                             ; This is now the current FS
        ADR     r0, LogonName
        ADD     r1, r4, #Context_UserId
        MOV     r2, #0
        BL      CopyNameIn
        DEC     r2
        MOV     r0, #" "
UserIdCopyLoop
        TEQ     r2, #?Context_UserId - 1
        MOVEQ   r0, #0
        STRB    r0, [ r1, r2 ]
        ADDNE   r2, r2, #1
        BNE     UserIdCopyLoop
        [       Files32Bit :LAND: Files24Bit
        MOV     r0, #FileServer_ReadObjectInfo
        ADR     r1, CommandBuffer
        [ {TRUE}
        LDR     r14, =&0D2424BC                         ; Sus 32 bit capability
        STR     r14, [ r1, #0 ]
        MOV     r2, #4
        |
        MOV     r14, #&BC                               ; Sus 32 bit capability
        STRB    r14, [ r1, #0 ]
        MOV     r2, #1
        ]
        BL      DoFSOp
        [       Debug
        BVC     %24
        DLINE   "File server is 24 bit"
        B       %26
24
        DREG    r4, "File server is 32 bit, record is at &"
        LDRB    r14, [ r4, #Context_Flags ]
        ORR     r14, r14, #Context_Flags_32Bit
        STRB    r14, [ r4, #Context_Flags ]
26
        |
        LDRVCB  r14, [ r4, #Context_Flags ]
        ORRVC   r14, r14, #Context_Flags_32Bit
        STRVCB  r14, [ r4, #Context_Flags ]
        ]
        ]
        LDR     r14, [ r4, #Context_RootDirectory ]
        TEQ     r14, #0                                 ; Special case for maintenance mode
        BEQ     MaintenanceModeFS
        [       Debug
        DLINE   "Reading the users environment"
        ]
        BL      ReadUsersEnvironment
        BVS     ExitFromStarLogon
        LDRB    r1, LogonDisc
        CMP     r1, #" "
        BLE     NeedToUpdateFSList
        BL      IsItANumber
        BNE     DoTheSDisc
NeedToUpdateFSList
        LDR     r1, Current
        ADD     r1, r1, #Context_Station
        LDMIA   r1, { r0, r1 }
        BL      UpdateFSList
        BVS     ExitFromStarLogon
        B       NoNeedForSDisc

MaintenanceModeFS
        MOV     r1, #&00FFFFFF                          ; Three handles of -1, and an option of zero
        ASSERT  (Context_RootDirectory :MOD: 4) = 0
        ASSERT  Context_Directory  = Context_RootDirectory + 1
        ASSERT  Context_Library    = Context_RootDirectory + 2
        ASSERT  Context_BootOption = Context_RootDirectory + 3
        STR     r1, [ r4, #Context_RootDirectory ]
        MOV     r1, #"!"
        STRB    r1, [ r4, #Context_DiscName ]
        ADD     r0, r4, #Context_Station
        ADD     r1, r4, #Context_DiscName + 1
        MOV     r2, #DiscNameSize-1
        SWI     XOS_ConvertNetStation
        B       ExitFromStarLogon

DoTheSDisc
        ADR     r0, LogonDisc                           ; Now see if we are already on the right disc
        LDR     r1, Current
        ADD     r1, r1, #Context_DiscName
        BL      CompareTwoStrings
        BEQ     NoNeedForSDisc
        ADR     r1, CommandBuffer
        LDR     r2, =&73694453                          ; "SDis"
        STR     r2, [ r1 ]
        LDR     r2, =&2063                              ; "c "
        STR     r2, [ r1, #4 ]
        MOV     r2, #6
        BL      CopyLineIn
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        BVS     ExitFromStarLogon
        BLVC    ReadUsersEnvironment
NoNeedForSDisc                                          ; Enters here with V clear
        [       Debug
        BVS     ExitFromStarLogon
        LDR     r0, Current
        BL      ValidateContext
        ]
        BLVC    SelectLibrary                           ; Informs FileSwitch about dirs etc.
        [       Debug
        BVS     ExitFromStarLogon
        LDR     r0, Current
        BL      ValidateContext
        BVS     ExitFromStarLogon
        ]
        BL      ServiceNetFS                            ; Needed in case OS_CLI doesn't return
        LDR     r0, Current
        LDRB    r0, [ r0, #Context_BootOption ]
        AND     r0, r0, #2_11
        ADRL    r1, BootUpNOP
        LDR     r0, [ r1, r0, LSL #2 ]
        ADRL    r1, Module_BaseAddr
        ADD     r0, r1, r0
        SWI     XOS_CLI
ExitFromStarLogon
        BL      ServiceNetFS                            ; Preserves all
        Pull    pc

BootUpNOP                                               ; Things to do at boot time
        DCD     BootUpNOPString - Module_BaseAddr
        DCD     BootUpLoadString - Module_BaseAddr
        DCD     BootUpRunString - Module_BaseAddr
        DCD     BootUpExecString - Module_BaseAddr

        ;       16-Jan-92  Bruce Cockburn
        ;       -------------------------
        ;       Changed boot commands to be "Net:%<command> !ArmBoot"
        ;       rather than "%<command> Net:!ArmBoot" so that the Run$Path
        ;       will be used so that boot files can reside in the library

BootUpLoadString
        DCB     "Net:%Load !ArmBoot"
BootUpNOPString
        DCB     13
BootUpRunString
        DCB     "Net:%Run !ArmBoot", 13
BootUpExecString
        DCB     "Net:%Exec !ArmBoot", 13

        ALIGN

        ; *************************************
        ; ***  Subroutines for logon, etc.  ***
        ; *************************************

        [       UseMsgTrans
        ; Buffer in R0, length in R1
        ; Trashes R1, R2, R3, R4
GetInvisibleNewPassword ROUT
        MOV     r3, r1                                  ; Save the length
        ADR     r1, Token_NewPw
        B       CommonPassword

GetInvisibleOldPassword
        MOV     r3, r1                                  ; Save the length
        ADR     r1, Token_OldPw
        B       CommonPassword

GetInvisiblePassword
        MOV     r3, r1                                  ; Save the length
        ADR     r1, Token_PasWd
CommonPassword
        Push    "r0, lr"                                ; Save exit reg and return address
        MOV     r4, r3                                  ; Keep original length
        MOV     r2, r0                                  ; Buffer address
        BL      MessageTransGSLookup0
        MOVVC   r0, r2                                  ; The passed buffer
        MOV     r1, r3                                  ; Length of the resultant string
        SWIVC   XOS_WriteN
        BVS     %95
        MOV     r1, r4                                  ; Buffer length
        MOV     r2, #" "                                ; Min char
        MOV     r3, #"~"                                ; Max char
        MOV     r4, #"-"                                ; Reflect char
        TEQ     pc, pc
        BEQ     %FT25
        ORR     r0, r0, #BitThirtyOne + BitThirty
        SWI     XOS_ReadLine
        B       %FT30
25      ORR     r4, r4, #BitThirtyOne + BitThirty
        SWI     XOS_ReadLine32
30      BVS     %95                                     ; Error
        MOVCS   r0, #Status_Escape                      ; Exit by pressing ESCape
        MOVCS   r1, #0                                  ; No buffer
        BLCS    ConvertStatusToError
95
        STRVS   r0, [ sp ]
        Pull    "r0, pc"

Token_PasWd
        DCB     "PasWd", 0                              ; "Password: "
Token_OldPw
        DCB     "OldPw", 0                              ; "Old password: "
Token_NewPw
        DCB     "NewPw", 0                              ; "New password: "
        ALIGN
        |       ; UseMsgTrans
GetInvisibleNewPassword ROUT
        ; Buffer in R0, length in R1
        ; except where exiting with V set
        ; Trashes R2, R3, R4, R6
        MOV     r6, lr
        MOV     r2, r0
        ADRL    r0, NewPassword
        B       %20

GetInvisibleOldPassword
        MOV     r6, lr
        MOV     r2, r0
        ADR     r0, Old
        SWI     XOS_Write0
        MOVVS   pc, r6
        B       %10

GetInvisiblePassword
        MOV     r6, lr
        MOV     r2, r0
10
        ADR     r0, SimplePassword
20
        SWI     XOS_Write0
        MOVVS   pc, r6
        MOV     r0, r2
        MOV     r2, #" "                                ; Min char
        MOV     r3, #"~"                                ; Max char
        MOV     r4, #"-"                                ; Reflect char
        TEQ     pc, pc
        BEQ     %FT25
        ORR     r0, r0, #BitThirtyOne + BitThirty
        SWI     XOS_ReadLine
        B       %FT30
25      ORR     r4, r4, #BitThirtyOne + BitThirty
        SWI     XOS_ReadLine32
30      MOVVS   pc, r6
        MOVCS   r0, #Status_Escape
        BLCS    ConvertStatusToError
        MOV     pc, r6                                  ; Will already have V set

Old
        DCB     "Old ", 0
NewPassword
        DCB     "New "
SimplePassword
        DCB     "Password: ", 0
        ALIGN
        ]       ; UseMsgTrans

ObliteratePassword ROUT
        Push    "r0-r1, lr"
        MOV     r14, #0
        ADRL    r0, Password
        ADRL    r1, Password + ?Password
20
        STRB    r14, [ r0 ], #1
        TEQ     r0, r1
        BNE     %20
        ADR     r0, CommandBuffer
        ADR     r1, CommandBuffer + ?CommandBuffer
40
        STRB    r14, [ r0 ], #1
        TEQ     r0, r1
        BNE     %40
        Pull    "r0-r1, pc"

PeekFileServer  ROUT
        Push    "r1, r5-r7, lr"
        MOV     r0, #Econet_MachinePeek
        MOV     r1, #0
        LDR     r2, Temporary
        ADD     r2, r2, #Context_Station
        LDMIA   r2, { r2, r3 }
        [       Debug
        DREG    r3, "Peeking &",cc
        DREG    r2, ".&"
        ]
        MOV     r4, sp
        MOV     r5, #4
        LD      r6, MachinePeekCount
        LD      r7, MachinePeekDelay
        SWI     XEconet_DoImmediate
        BVS     ExitPeekFileServer
        TEQ     r0, #Status_NotListening
        MOVEQ   r0, #Status_NotPresent
        TEQ     r0, #Status_Transmitted
        BLNE    ConvertStatusToError
ExitPeekFileServer
        Pull    "r1, r5-r7, pc"

IsItANumber ROUT
        ; Character in R1
        ; Preserves all
        ; Returns EQ if a number

        Push    "r10, r11, lr"
        ADR     r10, %30                                ; List of characters
10
        LDRB    r11, [ r10 ], #1
        TEQ     r11, #0
        BEQ     %20                                     ; End of the list
        TEQ     r11, r1
        BNE     %10
        Pull    "r10, r11, pc"

20
        TEQ     r11, #1                                 ; Must set NE since we got here with BEQ
        Pull    "r10, r11, pc"

30
        DCB     ".&0123456789", 0
        ALIGN

        [       OldOs
SelectLibrary   ROUT                                    ; May trash R0-R6
        ;       Called after a *Logon or a *Mount
        Push    lr
        MOV     r0, #OsByte_ReadCMOS
        MOV     r1, #NetFilerCMOS
        SWI     XOS_Byte
        BVS     ExitSelectLibrary
        TST     r2, #BitOne
        BEQ     ExitSelectLibrary
        ; Now do the Old 'FindLib' of "$.ArthurLib" on all discs
        MOV     r5, #0                                  ; Start looking at logical disc zero
FindLibLoop
        ADRL    r1, BigTextBuffer
        STRB    r5, [ r1, #0 ]
        MOV     r0, #(?BigTextBuffer - 2) / 17
        STRB    r0, [ r1, #1 ]
        MOV     r2, #2
        MOV     r0, #FileServer_DiscName
        MOV     r3, #?BigTextBuffer
        BL      DoFSOpGivingSize
        BVS     ExitSelectLibrary
        LDRB    r6, [ r1, #0 ]                          ; Number of names returned
        CMP     r6, #0                                  ; Clears V
        BEQ     ExitSelectLibrary                       ; None returned so stop
        ADD     r5, r5, r6                              ; Calculate which drive is next
        ADD     r4, r1, #2                              ; R4 points at the list of names
FindLibDiscLoop
        ADR     r1, CommandBuffer
        LDR     r0, =&003A0101                          ; &0101 is OpenIn, &3A is ":"
        STR     r0, [ r1 ]
        MOV     r2, #3
        MOV     r0, r4
        BL      CopyNameIn
        DEC     r2
        ADR     r0, NewLibFullName
        BL      CopyNameIn
        MOV     r0, #FileServer_Open
        BL      DoFSOp
        BVC     NewLibraryOpenedOK
        LDRB    r1, [ r0 ]
        CMP     r1, #ErrorNumber_FileNotFound :AND: &FF
        SETV    NE
        BVS     ExitSelectLibrary
        INC     r4, 17                                  ; Move to the next disc name
        DECS    r6                                      ; Any more disc names
        BNE     FindLibDiscLoop                         ; Yes, process them
        B       FindLibLoop                             ; No, fetch more

NewLibraryOpenedOK
        LDR     r6, Current
        LDRB    r4, [ r1 ]                              ; New library handle
        LDRB    r0, [ r6, #Context_Library ]            ; Old library handle
        STRB    r0, [ r1 ]
        MOV     r2, #1
        MOV     r0, #FileServer_Close
        BL      DoFSOp
        BVS     ExitSelectLibrary
        STRB    r4, [ r6, #Context_Library ]
        ADR     r0, NewLibLeafName
        ADD     r1, r6, #Context_LibraryName
LibraryNameLoop
        LDRB    r2, [ r0 ], #1
        STRB    r2, [ r1 ], #1
        TEQ     r2, #0
        BNE     LibraryNameLoop
ExitSelectLibrary
        Pull    pc

NewLibFullName
        DCB     ".$."
NewLibLeafName
        DCB     NewLibName, 0
        ALIGN
        |       ; OldOs
SelectLibrary   ROUT                                    ; May trash R0-R6
        ;       Called after a *Logon or a *Mount
        ;       Tries to work out the path of the new library
        ;       to give FileSwitch a string value, if it can't
        ;       get a string for it it returns % and works as it
        ;       always did.
        Push    lr
        MOV     r0, #OsByte_ReadCMOS
        MOV     r1, #NetFilerCMOS
        SWI     XOS_Byte
        BVS     ExitSelectLibrary
        TST     r2, #BitOne
        BEQ     LibraryIsDefault
        ; Now do the Old 'FindLib' of "$.ArthurLib" on all discs
        MOV     r5, #0                                  ; Start looking at logical disc zero
FindLibLoop
        ADRL    r1, BigTextBuffer
        STRB    r5, [ r1, #0 ]
        MOV     r0, #(?BigTextBuffer - 2) / 17
        STRB    r0, [ r1, #1 ]
        MOV     r2, #2
        MOV     r0, #FileServer_DiscName
        MOV     r3, #?BigTextBuffer
        BL      DoFSOpGivingSize
        BVS     ExitSelectLibrary
        LDRB    r6, [ r1, #0 ]                          ; Number of names returned
        CMP     r6, #0                                  ; Clears V
        BEQ     LibraryIsDefault                        ; None returned so stop
        ADD     r5, r5, r6                              ; Calculate which drive is next
        ADD     r4, r1, #2                              ; R4 points at the list of names
FindLibDiscLoop
        ADR     r1, CommandBuffer
        LDR     r0, =&00003A04                          ; &04 is the argument, &3A is ":"
        STR     r0, [ r1 ]
        MOV     r2, #2
        MOV     r0, r4
        BL      CopyNameIn                              ; Add on the disc name
        DEC     r2
        ADR     r0, NewLibFullName
        BL      CopyNameIn                              ; Follow with the library name
        MOV     r0, #FileServer_ReadObjectInfo
        BL      DoFSOp
        BVS     ExitSelectLibrary
        LDRB    r0, [ r1, #0 ]                          ; The returned type
        TEQ     r0, #object_directory                   ; Is it a directory?
        BEQ     NewLibraryFound
        INC     r4, 17                                  ; Move to the next disc name
        DECS    r6                                      ; Any more disc names
        BNE     FindLibDiscLoop                         ; Yes, process them
        B       FindLibLoop                             ; No, fetch more

NewLibraryFound
        ADR     r1, CommandBuffer
        LDR     r0, =&003A0101                          ; &0101 is OpenIn, &3A is ":"
        STR     r0, [ r1 ]
        MOV     r2, #3
        MOV     r0, r4
        BL      CopyNameIn
        DEC     r2
        ADRL    r0, NewLibFullName
        BL      CopyNameIn
        MOV     r0, #FileServer_Open
        BL      DoFSOp
        BVC     NewLibraryOpenedOK
        LDRB    r1, [ r0 ]
        CMP     r1, #ErrorNumber_FileNotFound :AND: &FF
        SETV    NE
        BVS     ExitSelectLibrary
        INC     r4, 17                                  ; Move to the next disc name
        DECS    r6                                      ; Any more disc names
        BNE     FindLibDiscLoop                         ; Yes, process them
        B       FindLibLoop                             ; No, fetch more

DotDollarDot
        DCB     ".$.", 0
DotAmpersand
        DCB     "."
Ampersand
        DCB     "&", 0
NewLibFullName
        DCB     ".$."
        DCB     NewLibName, 0
        ALIGN

NewLibraryOpenedOK
        LDR     r6, Current
        LDRB    r5, [ r1 ]                              ; New library handle
        LDRB    r0, [ r6, #Context_Library ]            ; Old library handle
        STRB    r0, [ r1 ]
        MOV     r2, #1
        MOV     r0, #FileServer_Close
        BL      DoFSOp
        BVS     ExitSelectLibrary
        STRB    r5, [ r6, #Context_Library ]
        ;       Inform FileSwitch of the new name with a *Lib command
        ;       Assemble the various bits in the CommandBuffer
        ADR     r1, CommandBuffer
        MOV     r0, #":"
        STRB    r0, [ r1, #0 ]
        MOV     r2, #1
        MOV     r0, r4
        BL      CopyNameIn                              ; Then the disc name
        DEC     r2
        ADRL    r0, NewLibFullName
        BL      CopyNameIn                              ; Follow up with the library name
PathComplete
        ADR     r1, CommandBuffer
        MOV     r2, #Dir_Library
        [       Debug
        DSTRING r1, "Library (%) := "
        ]
        BL      SetDir
        LDRVC   r6, Current
        ADDVC   r4, r6, #Context_LibraryName
        ADRVC   r5, CommandBuffer                       ; Pointer to the name
        BLVC    SetString
        ADDVC   r4, r6, #Context_LIBHandleName
        ADRVC   r5, CommandBuffer                       ; Pointer to the name
        BLVC    SetString
        Pull    pc, VS
        ADR     r1, CommandBuffer
        MOV     r0, #":"
        STRB    r0, [ r1, #0 ]
        MOV     r2, #1
        ADD     r0, r6, #Context_DiscName
        BL      CopyNameIn                              ; Then the disc name
        DEC     r2
        ADR     r0, DotAmpersand
        BL      CopyNameIn
        MOVVC   r2, #Dir_Current
        [       Debug
        DSTRING r1, "C.S.D. (@) := "
        ]
        BL      SetDir
        ADDVC   r4, r6, #Context_DirectoryName
        ADRVC   r5, CommandBuffer                       ; Pointer to the name
        BLVC    SetString
        ADDVC   r4, r6, #Context_CSDHandleName
        [       Debug
        ADRVCL  r5, Ampersand                           ; Pointer to the name
        |
        ADRVC   r5, Ampersand                           ; Pointer to the name
        ]
        BLVC    SetString
        ADRVC   r1, CommandBuffer
        MOVVC   r2, #Dir_UserRoot
        [       Debug
        DSTRING r1, "User Root (&) := "
        ]
        BLVC    SetDir
ExitSelectLibrary
        Pull    pc

SetDir
        ;       Trashes R3
        Push    "r0, r6, lr"
        MOV     r0, #FSControl_SetDir
        ADRL    r3, FilingSystemName
        MOV     r6, #0
        SWI     XOS_FSControl
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r6, pc"


LibraryIsDefault
        ;       Try to work out what the full pathname of the library is
        ADR     r1, CommandBuffer
        MOV     r0, #":"
        STRB    r0, [ r1, #0 ]
        MOV     r6, #1                                  ; Index for how far we've got
        MOV     r0, #4_0222
        STRB    r0, FSOpHandleFlags                     ; Use the Library in all slots
        MOV     r0, #FileServer_ReadUserEnvironment
        ADRL    r1, BigTextBuffer
        MOV     r2, #0
        MOV     r3, #?BigTextBuffer
        BL      DoFSOpGivingSize
        BVS     ExitSelectLibrary
        ADRL    r0, BigTextBuffer + 1                   ; Start of the returned disc name
        ADR     r1, CommandBuffer
        MOV     r2, r6                                  ; Where we were up to
        BL      CopyNameIn
        DEC     r2
        ADR     r0, DotDollarDot                        ; Connecting characters
        BL      CopyNameIn
        DEC     r2
        LDRB    r0, BigTextBuffer + 17
        TEQ     r0, #"$"                                ; Is it already $?
        SUBEQ   r2, r2, #1                              ; Step back over the trailing dot
        MOVEQ   r0, #13                                 ; Terminate
        STREQB  r0, [ r1, r2 ]
        BEQ     PathComplete
        MOV     r6, r2                                  ; Hold index for inserting more path
        ADRL    r0, BigTextBuffer + 17                  ; Start of the returned leafname
        BL      CopyNameIn
        MOV     r5, #1                                  ; Number of "^"s in the name we seek
10
        MOV     r0, #4_0222
        STRB    r0, FSOpHandleFlags                     ; Use the Library in all slots
        MOV     r0, #FileServer_ReadObjectInfo
        ADRL    r1, BigTextBuffer
        MOV     r3, #6
        STRB    r3, [ r1, #0 ]                          ; Reason code for get dir name
        MOV     r4, r5                                  ; Number of "^"s to add
        MOV     r2, #0
20
        INC     r2
        MOV     r3, #"^"
        STRB    r3, [ r1, r2 ]
        INC     r2
        MOV     r3, #"."
        STRB    r3, [ r1, r2 ]
        DECS    r4
        BNE     %20
        MOV     r3, #13                                 ; Add the terminator
        STRB    r3, [ r1, r2 ]
        INC     r2
        MOV     r3, #?BigTextBuffer
        BL      DoFSOpGivingSize
        BVC     CheckNameOfParent
        LDR     r14, [ r0, #0 ]
        LDR     r5, =&000105D6                          ; Check for NotFound
        TEQ     r14, r5
        BNE     ExitSelectLibrary                       ; Nasty error if not this one
        B       PathComplete                            ; It must be in $ (could do better here later)

CheckNameOfParent
        ADRL    r1, BigTextBuffer + 3
        LDRB    r0, [ r1, #0 ]                          ; First character of the name
        TEQ     r0, #"$"
        BEQ     PathComplete
        ;       Insert the returned name (in BigTextBuffer +3)
        ;       into the current command and name string (in CommandBuffer)
        ;       at the position offset in R6
        ;       First find the end of the returned name, put "." on
        ;       the end of it and copy the following part onto it
        ;       Then copy the whole thing back
        MOV     r0, #" "
        STRB    r0, [ r1, #13 ]                         ; Ensure termination of dirname
        MOV     r2, #0
30
        LDRB    r0, [ r1, r2 ]
        TEQ     r0, #" "                                ; Spot termination
        MOVEQ   r0, #"."                                ; Replace with seperator
        STREQB  r0, [ r1, r2 ]
        INC     r2
        BNE     %30                                     ; Move on if not
        ADR     r0, CommandBuffer
        ADD     r0, r0, r6                              ; Address of remainder of original string
        BL      CopyNameIn
        ADRL    r0, BigTextBuffer + 3
        ADR     r1, CommandBuffer
        MOV     r2, r6
        BL      CopyNameIn
        INC     r5                                      ; Add another "^" to the name
        B       %10
        ]       ; OldOs

ResolveFileServerName ROUT
        ; Name in 'LogonDisc'
        ; Returns number in R4.R3
        ; Trashes R0, R1, R2, R6
        Push    "r5, r7-r9, lr"
        SWI     XOS_ReadMonotonicTime
        BVS     ExitFindFileServerEarly
        ADD     r9, r0, #200                            ; Re-broadcast again in 2 seconds if need be
        LDR     r7, FSBroadcastDelay
        ADD     r7, r0, r7                              ; Work out end time for later
        MOV     r8, #0                                  ; Flag to say try a broadcast if it fails
        MOV     r0, #NetFS_StartWait
        BL      DoUpCall
        BVS     ExitFindFileServer
ReTryFindNamedFileServer
        PHPSEI  r5
        ADR     r0, LogonDisc
        LDR     r1, NameCache
        B       FindNameEntry

FindNameLoop
        ADD     r1, r2, #Cache_Name
        BL      CompareTwoStrings
        BEQ     NamedFileServerFound
        LDR     r1, [ r2, #Cache_Link ]
FindNameEntry
        TEQ     r1, #NIL
        MOVNE   r2, r1
        BNE     FindNameLoop
        PLP     r5
        TEQ     r8, #0
        BEQ     DoBroadcast
        WritePSRc USR_mode, r0                          ; Go into User mode to allow callbacks
        SWI     XOS_ReadMonotonicTime
        MOVVS   r5, r0                                  ; Save the error
        MOVVC   r5, #0                                  ; Or make the no error state
        SWI     XOS_EnterOS                             ; Ignore errors from this SWI
        TEQ     r5, #0                                  ; Was there an error before?
        MOVNE   r0, r5                                  ; Restore the error
        SETV    NE
        BVS     ExitFindFileServer
        CMP     r0, r7                                  ; Has the delay expired
        BHS     FileServerNotFound
        CMP     r0, r9
        BLT     ReTryFindNamedFileServer
        ADD     r9, r9, #200                            ; Next broadcast scheduled for 2 seconds in the future
        B       DoBroadcastWithoutFlush

FileServerNotFound
        ADR     r0, ErrorStationNotFound
        [       UseMsgTrans
        MOV     r8, r4
        ADR     r4, LogonDisc
        MOV     r5, #0
        BL      MessageTransErrorLookup2
        MOV     r4, r8
        |       ; UseMsgTrans
        SETV
        ]       ; UseMsgTrans
ExitFindFileServer
        MOV     r8, r0
        SavePSR r7                                      ; Get the old state of V etc.
        MOV     r0, #NetFS_FinishWait
        BL      DoUpCall
        MOVVC   r0, r8
        RestPSR r7,VC,f
ExitFindFileServerEarly
        Pull    "r5, r7-r9, pc"

NamedFileServerFound
        PLP     r5
        LDRB    r3, [ r2, #Cache_Station ]
        LDRB    r4, [ r2, #Cache_Network ]
        CLRV
        B       ExitFindFileServer

        [       UseMsgTrans
ErrorStationNotFound
        DCD     ErrorNumber_StationNotFound
        DCB     "StNtFnd", 0
        ALIGN
        |
        Err     StationNotFound
        ALIGN
        ]       ; UseMsgTrans

DoBroadcast
        BL      FlushAnotherTxList
DoBroadcastWithoutFlush
        INC     r8
        BL      BroadcastForNames
        BVS     ExitFindFileServer
        B       ReTryFindNamedFileServer

BroadcastForNames ; Preserves all registers
        Push    "r0-r7, lr"
        LD      r0, BroadcastPort
        TEQ     r0, #0
        BNE     DontAllocateBroadcastPort
        SWI     XEconet_AllocatePort
        BVS     BroadcastForNamesFails
        ST      r0, BroadcastPort
DontAllocateBroadcastPort
        ORR     r1, r0, #FileServer_DiscName :SHL: 8
        STR     r1, BroadcastBuffer
        MOV     r1, #NumberOfDiscs :SHL: 16
        STR     r1, BroadcastBuffer + 4
        BL      EnableCache
        MOVVC   r0, #0
        MOV     r1, #Port_FileServerCommand
        MOV     r2, #255
        MOV     r3, #255
        ADR     r4, BroadcastBuffer

; Changed (back) to 8 bytes for Level III - CPartington 28-Feb-95
        MOV     r5, #8

        MOV     r6, #Econet_BroadcastCount
        MOV     r7, #Econet_BroadcastDelay
        SWIVC   XEconet_DoTransmit
        [       Debug
        BVC     %99
        ADD     r14, r0, #4
        DSTRING r14, "XEconet_DoTransmit returns "
99
        ]
        BVS     BroadcastForNamesFails
        TEQ     r0, #Status_Transmitted
        BLNE    ConvertStatusToError
BroadcastForNamesFails
        STRVS   r0, [ sp ]
        Pull    "r0-r7, pc"

EnableCache
        Push    lr
        LD      r14, BroadcastRxHandle
        TEQ     r14, #0                                 ; If non-zero then it's already running
        Pull    pc, NE
        LD      r14, BroadcastPort                      ; If port not allocated don't bother
        TEQ     r14, #0
        Pull    pc, EQ
        Push    r0-r4                                   ; Get some more work registers
        MOV     r0, r14                                 ; The port
        MOV     r1, #255                                ; Any station
        MOV     r2, #255                                ; Any network
        ADR     r3, CacheBuffer
        MOV     r4, #?CacheBuffer
        SWI     XEconet_CreateReceive
        STRVC   r0, BroadcastRxHandle
        STRVS   r0, [ sp ]
        Pull    "r0-r4, pc"

StartCache
        EntryS  "r0"
        BL      EnableCache
        EXITS

FlushNameCache ROUT                                     ; Preserves all
        Push    "r0-r4, lr"
        MOV     r4, #0                                  ; Collect errors in here
        MOV     r1, #0
        PHPSEI                                          ; Don't allow the event task in here
        LD      r0, BroadcastRxHandle
        ST      r1, BroadcastRxHandle
        PLP
        CMP     r0, #0                                  ; Clears V
        SWINE   XEconet_AbandonReceive
        MOVVS   r4, r0                                  ; Save away the error
        LD      r0, BroadcastPort
        MOV     r1, #0
        ST      r1, BroadcastPort
        CMP     r0, #0                                  ; Clears V
        SWINE   XEconet_DeAllocatePort
        MOVVS   r4, r0                                  ; Save away the error
        LDR     r2, NameCache
FlushNameCacheLoop
        TEQ     r2, #NIL                                ; Have we got to the end of the chain ??
        BEQ     FlushNameCacheFinish
        LDR     r3, [ r2, #Cache_Link ]                 ; Get the next link
        BL      MyFreeRMA
        BVS     FlushNameCacheError
        MOV     r2, r3                                  ; Meet the entry conditions
        B       FlushNameCacheLoop

FlushNameCacheFinish
        CLRV
FlushNameCacheError
        MOV     r2, #NIL
        STR     r2, NameCache
        BVS     FlushNameCacheExit
        TEQ     r4, #0
        MOVNE   r0, r4
        SETV    NE
FlushNameCacheExit
        STRVS   r0, [ sp ]
        Pull    "r0-r4, pc"

        ; *****************************************
        ; ***  The Event routine for building   ***
        ; ***  the NameCache in the background  ***
        ; *****************************************

Event   ROUT
        TEQ     r0, #Event_Econet_Rx
        MOVNE   pc, lr
        LDR     r0, BroadcastRxHandle
        TEQ     r0, r1                                  ; Is it for us
        MOVNE   r0, #Event_Econet_Rx
        MOVNE   pc, lr
        Push    "r3-r8"
        MOV     r0, r1                                  ; Handle
        SWI     XEconet_ReadReceive                     ; To get R4.R3 as the network address
        Pull    "r3-r8, pc", VS
        INC     r5, 1                                   ; Step over the RxHeader.CommandCode
        LDRB    r1, [ r5 ], #1                          ; RxHeader.ReturnCode
        TEQ     r1, #0
        BNE     EventReOpen
        LDRB    r6, [ r5 ], #1                          ; Number of names received
        TEQ     r6, #NumberOfDiscs                      ; Is this as much as we asked for?
        BLEQ    DoAnotherTx                             ; If so ask for more
        ORR     r4, r3, r4, LSL #8                      ; Combine station and network number
EventLoop
        DECS    r6
        BMI     EventReOpen
        BL      UpdateCache
        BVC     EventLoop
EventReOpen
        MOV     r1, #0
        LDR     r0, BroadcastRxHandle
        STR     r1, BroadcastRxHandle
        SWI     XEconet_AbandonReceive                  ; Don't worry about errors here
        LD      r0, BroadcastPort
        MOV     r1, #255                                ; Any station
        MOV     r2, #255                                ; Any network
        ADR     r3, CacheBuffer
        MOV     r4, #?CacheBuffer
        SWI     XEconet_CreateReceive
        STRVC   r0, BroadcastRxHandle
        Pull    "r3-r8, pc"

UpdateCache
        Push    lr
        ;       Entry conditions
        ;       R4 ==> 0000nnss                         ; Station and network numbers
        ;       R5 ==> Pointer to a disc record from the file server
        ;               00 = Drive number
        ;               01 = Name, space filled to 16 characters
        ;       Exit conditions
        ;       R0-R3 trashed
        ;       R4 preserved
        ;       R5 incremented by 17, i.e. pointing at next record from file server
        ;       R6 preserved
        ;       R7-R8 trashed
        ;       Interrupt state preserved, disabled while inside the routine

        MOV     r3, #Size_Cache
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        BVS     ExitUpdateCache
        LDR     r1, =CacheIdentifier
        STR     r1, [ r2, #Cache_Identifier ]
        STR     r4, [ r2, #Cache_Station ]              ; Stores the net as well
        LDRB    r1, [ r5 ], #1
        STRB    r1, [ r2, #Cache_Drive ]
        SUB     r5, r5, #Cache_Name
        MOV     r0, #Cache_Name
UpdateCacheCopyLoop
        LDRB    r1, [ r5, r0 ]
        CMP     r1, #" "
        MOVLE   r1, #0
        STRB    r1, [ r2, r0 ]
        INC     r0
        TEQ     r0, #Cache_Terminator
        BNE     UpdateCacheCopyLoop
        ADD     r5, r5, #Cache_Name + DiscNameSize
        MOV     r1, #0
        STRB    r1, [ r2, r0 ]
        MOV     r7, r2                                  ; Hold onto the new record
        ; At this point we will search the list to see if this disc
        ; (fs and drive) is already here, and if it is to remove it
        PHPSEI  r8                                      ; **  Interrupts OFF  **
        ADR     r1, NameCache - Cache_Link
        ASSERT  (Cache_Station :MOD: 4) = 0
        ASSERT  Cache_Network = Cache_Station + 1
        ASSERT  Cache_Drive   = Cache_Station + 2
        LDR     r14, [ r7, #Cache_Station ]             ; Picks up station, net, and drive
        BIC     r14, r14, #&FF000000
UpdateCacheSearchLoop
        LDR     r0, [ r1, #Cache_Link ]                 ; Get the address of the next record
        TEQ     r0, #NIL
        BEQ     UpdateCacheNewDisc
        LDR     r3, [ r0, #Cache_Station ]              ; Picks up station, net, and drive
        BIC     r3, r3, #&FF000000
        TEQ     r3, r14                                 ; Have we already got this one?
        MOVNE   r1, r0
        BNE     UpdateCacheSearchLoop
        ; Remove the record pointed to by R0
        [ {FALSE} ; Debug
        MOV     r14, #IRQsema
        LDR     r14, [ r14 ]
        TEQ     r14, #0
        BNE     %56
        DLINE   "Duplicate record being destroyed"
56
        ]
        MOV     r2, r0                                  ; Get the address of the record being removed
        LDR     r3, [ r0, #Cache_Link ]                 ; The next address in the chain
        STR     r3, [ r1, #Cache_Link ]                 ; Jump the chain over it
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module                              ; No way to deal with error so ignore
UpdateCacheNewDisc
        ADR     r1, NameCache - Cache_Link
        ; At this point we will search the list for the right point to insert
        ; this record at, this record is in R7. The list pointer is in R1
UpdateCacheFindLoop
        LDR     r0, [ r1, #Cache_Link ]                 ; Get the address of the next record
        TEQ     r0, #NIL
        BEQ     InsertDisc
        BL      CompareDiscs
        MOVLT   r1, r0
        BLT     UpdateCacheFindLoop
        [ {FALSE} ; Debug
        BL      %54
        ]
        [ {TRUE}                                        ; Put the same name in once, highest number wins
        BEQ     ChooseDisc
InsertDisc
        ; R1 points to the record before, R0 points to the record after
        STR     r0, [ r7, #Cache_Link ]
        STR     r7, [ r1, #Cache_Link ]
RestoreAndExitUpdateCache
        PLP     r8                                      ; Restore Interrupts
ExitUpdateCache
        Pull    "pc"

        [ {FALSE} ; Debug
54
        EntryS
        MOV     r14, #IRQsema
        LDR     r14, [ r14 ]
        TEQ     r14, #0
        BNE     %57
        DLINE   "Insertion point found"
        DREG    psr, "PSR = &"
57
        EXITS
        ]

ChooseDisc
        [ {FALSE} ; Debug
        MOV     r14, #IRQsema
        LDR     r14, [ r14 ]
        TEQ     r14, #0
        BNE     %58
        DLINE   "ChooseDisc called"
58
        ]
        LDRB    r2, [ r0, #Cache_Network ]              ; If the network number of the record
        LDRB    r3, [ r7, #Cache_Network ]              ; already in the list is greater than the
        CMP     r3, r2                                  ; new element, throw the new element away
        LDREQB  r2, [ r0, #Cache_Station ]
        LDREQB  r3, [ r7, #Cache_Station ]
        CMPEQ   r3, r2                                  ; If GT then use the new element
        LDRGT   r2, [ r0, #Cache_Link ]                 ; Get the tail of the list
        STRGT   r2, [ r7, #Cache_Link ]                 ; Connect it to the new element
        STRGT   r7, [ r1, #Cache_Link ]                 ; Make the new element the new tail
        MOVGT   r2, r0                                  ; The element to remove
        MOVLE   r2, r7                                  ; If not then trash the new element
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module                              ; No way to deal with error so ignore
        B       RestoreAndExitUpdateCache
        |
        [ {FALSE} ; Debug
        BNE     InsertDisc                              ; If the names are equal then more tests
        LDRB    r2, [ r0, #Cache_Network ]              ; If the network number of the record
        LDRB    r3, [ r7, #Cache_Network ]              ; already in the list is greater than the
        CMP     r2, r3                                  ; new element, put the new element in
        LDREQB  r2, [ r0, #Cache_Station ]              ; AFTER the existing one
        LDREQB  r3, [ r7, #Cache_Station ]              ; Same for the station number
        CMPEQ   r2, r3
        MOVGT   r1, r0                                  ; Get the next set so the insert is after
        LDRGT   r0, [ r1, #Cache_Link ]
        ]
InsertDisc
        ; R1 points to the record before, R0 points to the record after
        STR     r0, [ r7, #Cache_Link ]
        STR     r7, [ r1, #Cache_Link ]
        PLP     r8                                      ; Restore Interrupts
ExitUpdateCache
        Pull    "pc"
        ]

ReadUsersEnvironment ROUT
        Push    lr
        BL      ClearFSOpFlags
        MOV     r0, #FileServer_ReadUserEnvironment
        ADR     r1, CommandBuffer
        MOV     r2, #0
        BL      DoFSOp
        Pull    pc, VS
        MOV     r2, #1
        LDR     r14, Current
        ADD     r3, r14, #Context_DiscName
30
        LDRB    r0, [ r1, r2 ]
        STRB    r0, [ r3 ], #1
        INC     r2
        TEQ     r2, #17
        BNE     %30
        MOV     r0, #0
        STRB    r0, [ r3 ]
        [       OldOs
        ADD     r3, r14, #Context_DirectoryName
        |
        ADD     r3, r14, #Context_UserRootName
        LDRB    r0, [ r1, r2 ]
        TEQ     r0, #"$"
        MOVNE   r0, #"^"
        STRNEB  r0, [ r3 ], #1
        MOVNE   r0, #"."
        STRNEB  r0, [ r3 ], #1
        ]
45
        LDRB    r0, [ r1, r2 ]
        STRB    r0, [ r3 ], #1
        INC     r2
        TEQ     r2, #27
        BNE     %45
        MOV     r0, #0
        STRB    r0, [ r3 ]
        [       OldOs
        ADD     r3, r14, #Context_LibraryName
50
        LDRB    r0, [ r1, r2 ]
        STRB    r0, [ r3 ], #1
        INC     r2
        TEQ     r2, #37
        BNE     %50
        MOV     r0, #0
        STRB    r0, [ r3 ]
        ]
        Pull    pc

CompareDiscs
        ; Compare records pointed to by R0, and R7.  R7 is the new one
        ; Trashes R2 and R3
        Push    "r4, lr"
        MOV     r4, #Cache_Name
        [       OldOs
DiscCompareLoop
        LDRB    r2, [ r0, r4 ]
        uk_UpperCase r2, r14
        LDRB    r3, [ r7, r4 ]
        uk_UpperCase r3, r14
        |
        LDR     r14, UpperCaseTable
DiscCompareLoop
        TEQ     r14, #0
        LDRB    r2, [ r0, r4 ]
        LDRNEB  r2, [ r14, r2 ]                         ; Map to upper case
        LDRB    r3, [ r7, r4 ]
        LDRNEB  r3, [ r14, r3 ]                         ; Map to upper case
        ]
        CMP     r2, #" "
        MOVLE   r2, #0                                  ; Map to a proper terminator
        CMP     r3, #" "
        MOVLE   r3, #0                                  ; Map to a proper terminator
        CMP     r2, r3
        Pull    "r4, pc", NE
        CMP     r3, #0                                  ; Check for termination
        Pull    "r4, pc", EQ
        INC     r4
        CMP     r4, #Cache_Terminator                   ; Must set all flags here
        BNE     DiscCompareLoop
        Pull    "r4, pc"

DoAnotherTx     ROUT
        Push    "r0-r7, lr"
        ;       R3 = Station number
        ;       R4 = Network number
        ;       See if we can find an existing block
        ;       If not then create one
        ADR     r2, AnotherTxList - :INDEX: AnotherTx_Link
FindAnotherTx
        LDR     r2, [ r2, #AnotherTx_Link ]
        TEQ     r2, #NIL
        BEQ     MakeNewRecord
        LDR     r0, [ r2, #AnotherTx_Network ]
        TEQ     r0, r4
        LDREQ   r0, [ r2, #AnotherTx_Station ]
        TEQEQ   r0, r3
        BNE     FindAnotherTx
        LDR     r0, [ r2, #AnotherTx_Handle ]           ; See if this is an active Tx
        SWI     XEconet_PollTransmit
        BVS     ExitDoAnotherTx
        TEQ     r0, #Status_Transmitting
        TEQNE   r0, #Status_TxReady
        BEQ     ExitDoAnotherTx
        B       TxAnotherTx

MakeNewRecord
        MOV     r3, #Size_AnotherTx
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        BVS     ExitDoAnotherTx
        ASSERT  AnotherTx_Link = 0
        ASSERT  AnotherTx_Link + 4 = AnotherTx_Handle
        ASSERT  AnotherTx_Handle + 4 = AnotherTx_Station
        ASSERT  AnotherTx_Station + 8 = AnotherTx_Buffer
        LDR     r0, AnotherTxList                       ; Get the list pointer
        MOV     r1, #0                                  ; Show the handle as closed
        ADD     r3, sp, #12                             ; Base of  network address
        LDMIA   r3, { r3, r4 }                          ; Get from out of the stack
        ADD     r5, r2, #AnotherTx_Handle
        LD      r5, BroadcastPort                       ; Buffer is init'd as follows
        ORR     r5, r5, #FileServer_DiscName :SHL: 8    ; Port, FileServer_DiscName, 0, 0
        MOV     r6, #NumberOfDiscs :SHL: 16             ; 0, 0, NumberOfDiscs, 0
        STMIA   r2, { r0, r1, r3, r4, r5, r6 }          ; Initialise the record
        STR     r2, AnotherTxList                       ; Put this record at the head of the list
TxAnotherTx
        LDRB    r0, [ r2, #AnotherTx_Buffer+5 ]         ; The disc to start from
        INC     r0, NumberOfDiscs
        STRB    r0, [ r2, #AnotherTx_Buffer+5 ]         ; Where to start from this time
        MOV     r0, #0
        LDR     r1, [ r2, #AnotherTx_Handle ]           ; See if there is an open Tx
        STR     r0, [ r2, #AnotherTx_Handle ]           ; Make sure we don't do this twice
        CMP     r1, #0                                  ; Is it active? (Clears V)
        MOVNE   r0, r1
        SWINE   XEconet_AbandonTransmit
        MOVVC   r1, #Port_FileServerCommand
        ASSERT  AnotherTx_Station + 8 = AnotherTx_Buffer
        ADDVC   r4, r2, #AnotherTx_Station
        LDMVCIA r4!, { r2, r3 }                         ; Now R4 points at the buffer
        MOVVC   r5, #?AnotherTx_Buffer
        ADRVC   r6, FSTransmitCount
        LDMVCIA r6, { r6, r7 }
        SWIVC   XEconet_StartTransmit                   ; Note R4 comes out in R2
        STRVC   r0, [ r2, #AnotherTx_Handle - AnotherTx_Buffer ] ; Store for later
ExitDoAnotherTx
        Pull    "r0-r7, pc"

FlushAnotherTxList

        Push    "r0, r2, lr"
FlushAnotherTxLoop
        LDR     r2, AnotherTxList                       ; Get the head of the list
        CMP     r2, #NIL                                ; Is there a record here
        Pull    "r0, r2, pc", EQ
        LDR     r0, [ r2, #AnotherTx_Link ]             ; Get link before freeing the record
        STR     r0, AnotherTxList                       ; Take this record out of the list
        LDR     r0, [ r2, #AnotherTx_Handle ]
        TEQ     r0, #0                                  ; Is there a handle here?
        SWIEQ   XEconet_AbandonTransmit                 ; Yes, throw it away
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        B       FlushAnotherTxLoop

        LTORG

        ; *********************************************************************
        ; ***  Service unknown commands here by sending to the file server  ***
        ; *********************************************************************

FileServerCommand ROUT
        ;       WP is loaded, return address in LR
        ;       R0 => points at the command name
        ;       R0 <= 0 if OK else Error pointer
        ;       'Cause there's no Vset capability
        Push    "r0-r3, lr"
        [       Debug
        DSTRING r0, "Service unknown command "
        ]
        MOV     r0, #OSArgs_ReadPTR
        MOV     r1, #0
        SWI     XOS_Args                                ; See if we are the current filing system
        BVS     %10
        TEQ     r0, #fsnumber_net
        Pull    "r0-r3, pc", NE
        BL      MakeCurrentTemporary
        Pull    "r0-r3, pc", VS                         ; If not logged on ignore the call
        LDR     r0, [ sp ]
        ADR     r1, CommandBuffer
        MOV     r2, #0
        BL      CopyLineIn
        MOV     r0, #FileServer_DecodeCommand
        BL      DoFSOp
        BVS     %40
        TEQ     r0, #4
        BEQ     %20                                     ; Return from *Info
        TEQ     r0, #8                                  ; Return code for unrecognised command
        Pull    "r0, r1"
        MOVNE   r0, #0                                  ; No error
10
        MOVNE   r1, #Service_Serviced
        Pull    "r2-r3, pc"

20
        LDRB    r0, [ r1 ], #1
        TEQ     r0, #&80
        BEQ     %50
        TEQ     r0, #13
        BNE     %30
        SWI     XOS_NewLine
        BVC     %20
        B       %40

30
        SWI     XOS_WriteC
        BVC     %20
40
        INCS    sp, 8
        B       %10                                     ; Z clear

50
        INC     sp, 8                                   ; Trash R0, and R1 off the stack
        MOV     r0, #0                                  ; No error
        MOV     r1, #Service_Serviced
        Pull    "r2-r3, pc"

        LTORG

MakeCurrentTemporary ROUT
        ;       R0 <= Pointer to the context record
        ;       All registers preserved
        ;       Checks that the current context is valid
        ;       and that we are logged on to it
        LDR     r0, Current                             ; Note the drop through

MakeContextTemporary
        ;       R0 => Pointer to the context record to use
        ;       All registers preserved
        ;       Checks that the context is valid
        ;       and that we are logged on to it
        Push    "lr"
        CMP     r0, #0                                  ; Clears V
        BEQ     CurrentNotLoggedOn
        BL      ValidateContext
        BVS     ExitMakeCurrentTemporary
        LDR     r14, [ r0, #Context_RootDirectory ]
        CMP     r14, #0                                 ; Clears V
        STRNE   r0, Temporary
CurrentNotLoggedOn
        ADREQ   r0, ErrorNotLoggedOn
        [       UseMsgTrans
        BLEQ    MakeError
        |
        SETV    EQ
        ]
ExitMakeCurrentTemporary
        Pull    "pc"

        [       UseMsgTrans
ErrorNotLoggedOn
        DCD     ErrorNumber_NotLoggedOn
        DCB     "WhoRU", 0
        ALIGN
        |
        Err     NotLoggedOn
        ALIGN
        ]


ValidateContext ROUT
        ;       R0 => Pointer to a context
        ;       All registers preserved
        Push    "r1, r2"
        [       Debug
        LDR     r2, =ContextIdentifier
        RSB     r2, r2, #0
        LDR     r1, [ r0, #Size_Context ]
        TEQ     r1, r2
        LDREQ   r2, [ r0, #Size_Context + 4 ]
        TEQEQ   r1, r2
        BEQ     %30
        DREG    r0, "Validate &"
        ADR     r0, %20
        Pull    "r1, r2"
        RETURNVS

20
        DCD     &98765432
        DCB     "NetFS has just SHAT on a context guard word", 0
        ALIGN
30
        ]
        LDR     r2, =ContextIdentifier
        LDR     r1, [ r0, #Context_Identifier ]
        CMP     r1, r2
        Pull    "r1, r2"
        MOVEQ   pc, lr
        ADR     r0, ErrorNetFSInternalError
        [       UseMsgTrans
        B       MakeErrorWithModuleName

ErrorNetFSInternalError
        DCD     ErrorNumber_NetFSInternalError
        DCB     "Fatal", 0
        ALIGN
        |
        RETURNVS

        Err     NetFSInternalError
        ALIGN
        ]

ServiceNetFS                                            ; Preserves all
        EntryS  "r0, r1"
        MOV     r1, #Service_NetFS
        SWI     XOS_ServiceCall
        EXITS

        LTORG

        [       :LNOT: ReleaseVersion
NetFS_FCBs_Code
        Push    lr
        LDR     wp, [ r12 ]
        LDR     r10, FCBs
        LDR     r11, =FCBIdentifier
FCBsLoop
        TEQ     r10, #NIL
        BEQ     ExitFromStarFCBs
        BL      FCBPrint
        BVS     ExitFromStarFCBs
        LDR     r10, [ r10, #Context_Link ]
        B       FCBsLoop

FCBNoId
        ADRL    r0, ErrorNetFSInternalError
        [       UseMsgTrans
        BL      MakeErrorWithModuleName
        |
        SETV
        ]
ExitFromStarFCBs
        Pull    pc

FCBPrint        ROUT
        Push    lr
        LDR     r0, [ r10, #FCB_Identifier ]
        TEQ     r0, r11
        BNE     FCBNoId
        SWI     XOS_WriteS
        DCB     "LowFSI handle is: &", 0
        ALIGN
        LDRVC   r0, [ r10, #FCB_Handle ]
        BLVC    FCB_Word
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     ", user handle is: &", 0
        ALIGN
        LDRVCB  r0, [ r10, #FCB_TuTuHandle ]
        BLVC    FCB_Byte
        SWIVC   XOS_NewLine
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     "File server is: ", 0
        ALIGN
        LDRVC   r3, [ r10, #FCB_Context ]
        ADDVC   r0, r3, #Context_Station                ; Address of number to be converted
        DEC     sp, 12                                  ; Space for the result of the conversion
        MOV     r1, sp                                  ; Base of stack frame
        MOV     r2, #11
        SWIVC   XOS_ConvertFixedNetStation
        SWIVC   XOS_Write0
        INC     sp, 12                                   ; Get rid of the data
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     ", context record is at: &", 0
        ALIGN
        MOVVC   r0, r3
        BLVC    FCB_Word
        SWIVC   XOS_NewLine
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     "Sequence bit is ", 0
        ALIGN
        LDRVCB  r1, [ r10, #FCB_Status ]
        ANDVC   r0, r1, #1
        ADDVC   r0, r0, #"0"
        SWIVC   OS_WriteC
        SWIVC   XOS_NewLine
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     "The 32Bit flag is ", 0
        ALIGN
        Pull    pc, VS
        TST     r1, #FCB_Status_32Bit
        ADREQ   r0, FCB_False
        ADRNE   r0, FCB_True
        SWI     XOS_Write0
        Pull    pc, VS
        TST     r1, #FCB_Status_Directory
        BNE     FCBIsADirectory
        TST     r1, #FCB_Status_WriteOnly
        BNE     FCBIsWriteOnly
        SWI     XOS_WriteS
        DCB     "The object is a normal file.", 13, 10, 0
        ALIGN
        Pull    pc

FCB_True
        DCB     "TRUE", 13, 10, 0
FCB_False
        DCB     "FALSE", 13, 10, 0
        ALIGN

FCBIsWriteOnly
        SWI     XOS_WriteS
        DCB     "The object is a Write Only file.", 13, 10, 0
        ALIGN
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     "The pointer is: &", 0
        ALIGN
        LDRVC   r0, [ r10, #FCB_Pointer ]
        BLVC    FCB_Word
        SWIVC   XOS_NewLine
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     "The buffer is at: &", 0
        ALIGN
        LDRVC   r0, [ r10, #FCB_Buffer ]
        BLVC    FCB_Word
        SWIVC   XOS_NewLine
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     "The buffer extent is: &", 0
        ALIGN
        LDRVC   r0, [ r10, #FCB_BufferExtent ]
        BLVC    FCB_Word
        SWIVC   XOS_NewLine
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     "The buffer base is: &", 0
        ALIGN
        LDRVC   r0, [ r10, #FCB_BufferBase ]
        BLVC    FCB_Word
        SWIVC   XOS_NewLine
        Pull    pc

FCBIsADirectory
        SWI     XOS_WriteS
        DCB     "The object is a directory.", 13, 10, 0
        ALIGN
        Pull    pc

FCB_Word
        Entry   "r0"
        MOV     r0, r0, ROR #24
        BL      FCB_Byte
        MOV     r0, r0, ROR #24
        BL      FCB_Byte
        MOV     r0, r0, ROR #24
        BL      FCB_Byte
        MOV     r0, r0, ROR #24
        BL      FCB_Byte
        EXIT    ; No need for EXITS as FCB_Byte preserves flags

FCB_Byte
        EntryS  "r0"
        MOV     r0, r0, ROR #4
        BL      FCB_Nibble
        MOV     r0, r0, ROR #32-4
        BL      FCB_Nibble
        EXITS

FCB_Nibble
        Entry   "r0"
        AND     r0, r0, #15
        CMP     r0, #10
        ADDCC   r0, r0, #"0"
        ADDCS   r0, r0, #"A"-10
        SWI     XOS_WriteC
        EXIT

NetFS_Contexts_Code
        Push    lr
        LDR     wp, [ r12 ]
        SWI     XOS_WriteS
        DCB     "Configuration is: """, 0
        ALIGN
        BLVC    TextualiseConfiguration
        ADRVC   r0, LogonDisc
        SWIVC   XOS_Write0
        BVS     ExitFromStarContext
        SWI     XOS_WriteS
        DCB     """", 13, 10, 0
        ALIGN
        BVS     ExitFromStarContext
        LDR     r10, Contexts
        LDR     r11, =ContextIdentifier
ContextLoop
        TEQ     r10, #NIL
        BEQ     ExitFromStarContext
        BL      ContextPrint
        BVS     ExitFromStarContext
        LDR     r10, [ r10, #Context_Link ]
        B       ContextLoop

ContextNoId
        ADRL    r0, ErrorNetFSInternalError
        [       UseMsgTrans
        BL      MakeErrorWithModuleName
        |
        SETV
        ]
ExitFromStarContext
        Pull    pc

ContextPrint    ROUT
        LDR     r0, [ r10, #Context_Identifier ]
        TEQ     r0, r11
        BNE     ContextNoId
   ;     LDR     r0, Current
   ;     CMP     r10, r0
   ;     MOVEQ   pc, lr
        LDR     r0, [ r10, #Context_RootDirectory ]
        CMP     r0, #0
        MOVEQ   pc, lr
        Push    lr
        ADD     r0, r10, #Context_Station               ; Address of number to be converted
        DEC     sp, 12                                  ; Space for the result of the conversion
        MOV     r1, sp                                  ; Base of stack frame
        MOV     r2, #11
        SWI     XOS_ConvertFixedNetStation
        SWIVC   XOS_Write0
        INC     sp, 12                                   ; Get rid of the data
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     " :", 0
        ALIGN
        Pull    pc, VS
        ADD     r0, r10, #Context_DiscName
        TEQ     r0, #0
        Pull    pc, EQ
        MOV     r1, #0
70
        LDRB    r14, [ r0, r1 ]
        CMP     r14, #" "
        ADDGT   r1, r1, #1
        BGT     %70
        SWI     XOS_WriteN
        SWIVC   XOS_WriteI + " "
        Pull    pc, VS
        ADD     r0, r10, #Context_UserId
        TEQ     r0, #0
        Pull    pc, EQ
        MOV     r1, #0
80
        LDRB    r14, [ r0, r1 ]
        CMP     r14, #" "
        ADDGT   r1, r1, #1
        BGT     %80
        SWI     XOS_WriteN
        SWIVC   XOS_NewLine
        [       :LNOT: OldOs
        Pull    pc, VS
        LDR     r0, [ r10, #Context_DirectoryName ]
        TEQ     r0, #0
        BEQ     %90
        SWI     XOS_WriteS
        DCB     "        CSD        = ", 0
        ALIGN
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        Pull    pc, VS
90
        SWI     XOS_WriteS
        DCB     "        Dir handle = ", 0
        ALIGN
        Pull    pc, VS
        [       Debug
        LDRB    r0, [ r10, #Context_Directory ]
        BREG    r0, "(&", cc
        DLINE   ") ", cc
        ]
        LDR     r0, [ r10, #Context_CSDHandleName ]
        TEQ     r0, #0
        SWINE   XOS_Write0
        SWIVC   XOS_NewLine
        Pull    pc, VS
        LDR     r0, [ r10, #Context_LibraryName ]
        TEQ     r0, #0
        BEQ     %94
        SWI     XOS_WriteS
        DCB     "        LIB        = ", 0
        ALIGN
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
94
        SWI     XOS_WriteS
        DCB     "        Lib handle = ", 0
        ALIGN
        Pull    pc, VS
        [       Debug
        LDRB    r0, [ r10, #Context_Library ]
        BREG    r0, "(&", cc
        DLINE   ") ", cc
        ]
        LDR     r0, [ r10, #Context_LIBHandleName ]
        TEQ     r0, #0
        SWINE   XOS_Write0
        SWIVC   XOS_NewLine
        Pull    pc, VS
        SWI     XOS_WriteS
        DCB     "        User Root  = ", 0
        ALIGN
        Pull    pc, VS
        [       Debug
        LDRB    r0, [ r10, #Context_RootDirectory ]
        BREG    r0, "(&", cc
        DLINE   ") ", cc
        ]
        ADD     r0, r10, #Context_UserRootName
        LDRB    r14, [ r0 ]
        TEQ     r14, #"^"
        ADDEQ   r0, r0, #2                              ; If it starts ^. then skip that
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        Pull    pc, VS
        ]
        Pull    pc
        ]

        LTORG

        END
