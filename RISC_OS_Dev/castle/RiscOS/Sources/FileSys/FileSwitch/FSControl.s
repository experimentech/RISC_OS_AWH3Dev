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
        SUBT    > Sources.FSControl

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; +                                                                           +
; +                     F S C O N T R O L    S W I                            +
; +                                                                           +
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; FSControlEntry. Vectored SWI level entry
; ==============
;
; Perform various actions in FileSwitch analogous to JMI (FSCV) on BBC micro

; Filename parameters are all GSTRANSed in the standard Filing System way

; In    r0 = action requested, various parms (NB. Not r0b)

; Out   VC: Action performed, r0 preserved (frequently)
;       VS: Something terrible has happened, r0 -> error block

FSControlEntry ROUT

 [ debugcontrolentry
 DREG r0,"Doing FSControl ",cc
 DREG r1," arg1 ",cc
 DREG sp,", sp = "
 ]
        CMP     r0, #FSControl_Max
        JTAB    r0, LO, FSControl       ; Good rc if LO
        B       FSControl_BadReason

                                  ; Check reason codes against &.Hdr.File

        JTE     DirEntry,                FSControl_Dir
        JTE     LibEntry,                FSControl_Lib
        JTE     StartApplicEntry,        FSControl_StartApplication
        JTE     RunTypeEntry,            FSControl_RunType
        JTE     RunEntry,                FSControl_Run
        JTE     CatEntry,                FSControl_Cat
        JTE     CatEntry,                FSControl_Ex   ; Same as Cat
        JTE     CatEntry,                FSControl_LCat
        JTE     CatEntry,                FSControl_LEx
        JTE     InfoEntry,               FSControl_Info ; Same as Cat
        JTE     OptEntry,                FSControl_Opt
        JTE     SetFromNameEntry,        FSControl_StarMinus
        JTE     AddFSEntry,              FSControl_AddFS
        JTE     LookupFSEntry,           FSControl_LookupFS
        JTE     SelectFSEntry,           FSControl_SelectFS
        JTE     BootupFSEntry,           FSControl_BootupFS
        JTE     RemoveFSEntry,           FSControl_RemoveFS
        JTE     AddSecondaryFSEntry,     FSControl_AddSecondaryFS
        JTE     ReadFileTypeEntry,       FSControl_ReadFileType
        JTE     RestoreCurrEntry,        FSControl_RestoreCurrent
        JTE     ReadTempModEntry,        FSControl_ReadModuleBase
        JTE     ReadFSHandle,            FSControl_ReadFSHandle
        JTE     ShutFilesEntry,          FSControl_Shut
        JTE     ShutDownEntry,           FSControl_ShutDown
        JTE     AccessEntry,             FSControl_Access
        JTE     RenameEntry,             FSControl_Rename
 [ hascopy
        JTE     CopyEntry,               FSControl_Copy
 |
        JTE     FSControl_BadReason
 ]
 [ haswipe
        JTE     WipeEntry,               FSControl_Wipe
 |
        JTE     FSControl_BadReason
 ]
 [ hascount
        JTE     CountEntry,              FSControl_Count
 |
        JTE     FSControl_BadReason
 ]
        JTE     FSControl_BadReason,     FSControl_CreateHandle
        JTE     ReadSecModEntry,         FSControl_ReadSecondaryModuleBase
        JTE     FileTypeFromStringEntry, FSControl_FileTypeFromString
        JTE     InfoEntry,               FSControl_FileInfo
        JTE     ReadFSNameEntry,         FSControl_ReadFSName
        JTE     FSControl_BadReason,     FSControl_SetContexts

        ; New reason codes introduced since 1.70
        JTE     AddImageFSEntry,         FSControl_RegisterImageFS
        JTE     RemoveImageFSEntry,      FSControl_DeRegisterImageFS
        JTE     CanonicalisePathEntry,   FSControl_CanonicalisePath
        JTE     InfoToFileTypeEntry,     FSControl_InfoToFileType
        JTE     URDEntry,                FSControl_URD
        JTE     BackEntry,               FSControl_Back
        JTE     DefectListEntry,         FSControl_DefectList
        JTE     AddDefectEntry,          FSControl_AddDefect
        JTE     NoDirEntry,              FSControl_NoDir
        JTE     NoURDEntry,              FSControl_NoURD
        JTE     NoLibEntry,              FSControl_NoLib
        JTE     UsedSpaceMapEntry,       FSControl_UsedSpaceMap
        JTE     ReadBootOptionEntry,     FSControl_ReadBootOption
        JTE     WriteBootOptionEntry,    FSControl_WriteBootOption
        JTE     ReadFreeSpaceEntry,      FSControl_ReadFreeSpace
        JTE     NameDiscEntry,           FSControl_NameDisc
        JTE     StampImageEntry,         FSControl_StampImage
        JTE     ObjectAtOffsetEntry,     FSControl_ObjectAtOffset
        JTE     SetDirEntry,             FSControl_SetDir
        JTE     ReadDirEntry,            FSControl_ReadDir
        JTE     ReadFreeSpace64Entry,    FSControl_ReadFreeSpace64
        JTE     DefectList64Entry,       FSControl_DefectList64
        JTE     AddDefect64Entry,        FSControl_AddDefect64

        ; New reason code introduced since 2.73
        JTE     EnumerateHandlesEntry,   FSControl_EnumerateHandles

FSControl_Max * (.-$JumpTableName) :SHR: 2


FSControl_BadReason

        addr    r0, ErrorBlock_BadFSControlReason
        BL      copy_error
 [ No26bitCode
        Pull    pc                              ; copy_error sets V
 |
        Pull    lr
        ORRS    pc, lr, #V_bit
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; RunEntry. Top level FSControl entry
; ========
;
; Run a file from the temporary Filing System

; In    r1 -> filename (space, CtrlChar term) and command line (CtrlChar term)

; Out   if it doesn't return:
;            current FS restored, program running or aborted
;       if it does return:
;            VC: file has been run ok (eg. *EXECed OR PIC transient)
;            VS: error in running or file returned badly

RunTypeEntry ; for the mo.

RunEntry NewSwiEntry "r0-r3"

 [ debugrun
 DREG sp,"run sp in = "
 ]
        BL      FS_SkipSpaces           ; Saves code to have this here
                                        ; Allows */ fred etc.
        BCC     %FA99                   ; [*/ with no arg]

        ADR     r0, CommandLine
        BL      SGetLinkedString        ; May have spaces in it, so watch out !
        BVS     %FA98                   ; Nothing to deallocate

 [ debugrun
 DSTRING r1,"Trying to run "
 ]
        BL      SkipOverNameAndSpaces
        STR     r1, commandtailptr

        LDR     r1, CommandLine
        BL      TryRunningFile

        BL      SFreeCommandLine

98
        SwiExit


99      addr    r0, ErrorBlock_BadCommand
        BL      CopyError
        B       %BT98

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; TryRunningFile
; ==============
;
; Split off from main RUN entry for ease of error handling / exiting

; In    r1 -> filename (space, CtrlChar term) and command line (CtrlChar term)

; Out   if it doesn't return:
;            current FS restored, program running or aborted
;       if it does return:
;            VS: error has been set
;            VC: file has been run ok (eg. *EXECed OR PIC transient)

TryRunningFile Entry "r0-r6,fscb" ; Try not to keep too much stacked for RUN

 [ debugrun
        DSTRING r1, "tryrunning "
 ]
        ; Process the path.
        ; Result is definitely a pure file.
        BL      TopPath_DoBusinessToPathForRun
        BVS     RunExit

 [ debugrun
        DREG r0, "ft after business is "
 ]

        ; Translate L=0or-1 and E=-1 to L=&fffffeff and E=-1 for old style command files
        CMP     r2, #0
        CMPNE   r2, #-1
        CMPEQ   r3, #-1
        LDREQ   r2, =&FFFFFE00+&FF

        ; Is the file typed?
        BL      IsFileTyped
        BNE     Run_UndatedFile


        MOV     r0, r2, ASR #8          ; File type now in the lowest 12 bits
        CMP     r0, #&FFFFFFF8          ; Type FF8 ?
        BEQ     Run_Absolute8000File
        CMP     r0, #&FFFFFFFC          ; Type FFC ?
        BEQ     Run_TransientFile

; .............................................................................
; In    r2 = load address to decode

; If a temporary filing system was specified,
; and [FullFilename] doesn't contain a filing system prefix,
; then prefix FullFilename with the temporary filing system name.

Run_UnrecognisedFile

        LDR     r3, commandtailptr      ; Can supply a command tail to append
        ADR     r4, RunActionPrefix
        addr    r5, ErrorBlock_UnknownRunAction
        BL      ReadActionVariable      ; Leaves r0 -> action vbl (pushed)
        BVS     RunExit_FF

 [ debugrun
        DSTRING r0, "OS_CLI on "
        LDR     r14, globalerror
        TEQ     r14, #0
        BEQ     %FT01
        DLINE   "Error given before OS_CLI"
        B       %FT02
01
        DLINE   "No error before OS_CLI"
02
 ]

        SWI     XOS_CLI
        BLVS    CopyErrorExternal
 [ debugrun
        LDR     r14, globalerror
        TEQ     r14, #0
        BEQ     %FT01
        DLINE   "Error given after OS_CLI"
        B       %FT02
01
        DLINE   "No error after OS_CLI"
02
 ]

        ADR     r0, ActionVariable
        BL      SFreeLinkedArea         ; Accumulate V

; .............................................................................

Run_Common_NoCopy

        CMPVC   r0, r0                  ; EQ -> file run ok

; .............................................................................
; In    CommandLine, PassedFilename, FullFilename and SpecialField
;       to be deallocated

RunExit_FF

        BL      JunkFileStrings

RunExit

        EXIT


RunActionPrefix         DCB     "Alias$@RunType_" ; Shared zero with ...
66
        DCB     0

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Type FF8

Run_Absolute8000File

        MOV     r2, #&8000              ; Load at &8000
        MOV     r3, r2                  ; And execute it there

; .............................................................................

Run_UndatedFile

 [ debugrun
 DREG r3,"Running file at &"
 ]
        CMP     r2, #&8000              ; Can't load anything below 32K now
        BLO     %FA92
;        BIC     r3, r3, #ARM_CC_Mask    ; Form sensible ARM address for exec
        ADD     r5, r2, r4              ; Does exec address live in the code ?
        SUB     r14, r5, #1             ; Stops zero length files running too
        CMP     r3, r2                  ; ie. start <= exec < (start+length)
        RSBGES  r14, r3, r14
        BLT     %FA93                   ; LT -> not in range (ie. not in code)

        BL      ValidateR2R5_WriteToCoreCodeLoad
        BVS     RunExit_FF

        MOV     r7, r4
        MOV     r4, r2
        LDR     r5, PassedFilename
        addr    r0, anull               ; Null command tail fudge
        MOV     r2, r3                  ; CAO address := entry point of file
        LDR     r3, CommandLine
        BL      StartUpTheApplication   ; Which restores current FS
        BVS     RunExit_FF

 [ AssemblingArthur
        LDR     r0, =EnvString          ; r0 -> copy of run string
 |
        LDR     r0, EnvStringAddr       ; r0 -> copy of run string
 ]
        MOV     r1, r0                  ; NB. Our strings are all dead now
        BL      SkipOverNameAndSpaces   ; r1 -> copy of command tail

        LDR     r10, SVCSTK             ; remember top of stack

        ;Check whether it's a squeezed app.
        CMP     r2, #&8000
        BNE     %FT77                   ;Not an 'APP' (type FF8)

 [ StrongARM

        LDR     lr, [r2]

        ;To save unnecessary hassle, weed out the uncompressed cases...
        MOV     r3,     #&E1000000
        ORR     r3, r3, #&00A00000      ; Gives us 'MOV R0,R0' in R5
        TEQ     lr, #&FB000000          ; BLNV 0 at &8000? If so, it's C rel 5 vintage.
        TEQNE   lr, R3                  ; MOV R0,R0?
        MOVEQ   r3, r7                  ; Bung the code size in R3.
        BEQ     %FT76                   ; Not compressed, so skip the pre-decompression call

        [ debugsarm
        DLINE "It's a compressed App"
        ]

  [ {FALSE} ; leave this up to client module(s)
        ;Are we on a StrongARM?
        MOV     r0, #0
        SWI     XOS_PlatformFeatures
        TST     r0, #1                  ; Is the 'synchronise code areas' bit set?
        ;If so, turn the caches & WB off...
        MOVNE   r2, #&FFFFFFF9          ; Caches/WB off
        MOVEQ   r2, #-1                 ; Leave 'em as-is
        MOV     r0, #0
        MOV     r1, #0
        SWI     XOS_MMUControl
        Push    "r1"                    ; Remember the old cache setting
  ]

        ; Check memory before decompression, since decompression code is dumb
        MOV     r2, #&8000
        BL      CheckAIFMemoryLimit     ; Ignore any returned error since nonstandard compression may confuse our memory usage calculations

        MOV     r0, #0                  ; Pre-decompression service call
        MOV     r1, #Service_UKCompression
        MOV     r3, r7
        MOV     r4, #&8000
        SWI     XOS_ServiceCall         ; A claimant of this does the decompression

  [ {FALSE} ; leave this up to client module(s)
        ;Switch the caches back to the previous state and fire off another service call.
        Pull    "r1"
        MOV     r0, #0
        MOV     r2, #0
        SWI     XOS_MMUControl
  ]


76      MOV     r0, #1                  ; Post-decompression service call
        MOV     r1, #Service_UKCompression
        MOV     r2, #&8000
        SWI     XOS_ServiceCall

        ;unsqueezer or patcher(s) are responsible for any code synchronising which
        ;is neccessary for internal code/poking handling, but we do a Synchronise here
        ;to sync with the finally unsqueezed and patched up code
        MOV     r0, #1
        MOV     r1, #&8000
        ADD     r2, r3, #&8000          ; Trust that they've given the right size back
        SWI     XOS_SynchroniseCodeAreas
        MOV     r2, #&8000
 ]

        BL      CheckAIFMemoryLimit
        BVC     %FT71
        ; /* dead here - need to generate an error */
        addr    r0, ErrorBlock_CoreNotWriteable
        MOV     r1, #0
        SWI     XMessageTrans_ErrorLookup
        SWI     OS_GenerateError
71

 [ StrongARM
        ;Finally, prepare to run the thing!
        MOV     r2, r4                  ; We're gonna jump in where we're told!.
 ]

77
        MOV     sp, r10                 ; Flatten superstack, we don't return

        WritePSRc 0, r12                ; USR mode, all ints on
        MOV     r12, #&80000000         ; Cause address extinction if used
        MOV     r13, #&80000000         ; (keep 1.20 compat capable)
        ADR     lr, ReturnFromAbsoluteCode
        MOV     pc, r2                  ; Go to it !

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Type FFC

; Offsets in transient PIC RMA block

                        ^       0
transient_savearea      #       4*6     ; SaveArea for r6-r9, r13_usr, r14_usr
transient_code          #       0

transient_ws * &0400

Run_TransientFile

; Claim a RMA block for the transient

        ADD     r5, r4, #transient_code ; Need length of file + my block size
        ADD     r5, r5, #3              ; Word align for wp,sp_usr below
        BIC     r5, r5, #3              ; Remember r5: used for ws below !
        ADD     r3, r5, #transient_ws   ; Plus some workspace for it

        BL      SGetLinkedTransientArea
        BVS     RunExit_FF
        BEQ     %FA94                   ; No room ?

; Need to preserve any registers that haven't been saved for EXIT so that
; transients may call other transients, preserving all registers + state
; Use a save area on the front of the code block for these.
; r10-r12 assumed to be preserved by the main SWI handler.

        ASSERT  transient_savearea = 0 
  [ SASTMhatbroken
        STMIA   r2!,{r6-r9}
        STMIA   r2, {r13,r14}^   ; Must preserve r13_usr and r14_usr
        SUB     r2, r2, #4*4     ; r0-r5 already stacked
  |
        STMIA   r2, {r6-r9, r13-r14}^   ; Must preserve r13_usr and r14_usr
                                        ; r0-r5 already stacked
  ]
        ; Load the code after the info block
        MOV     r0, #object_file
        ADD     r3, r2, #transient_code
 [ StrongARM
        [ debugsarm
        DLINE   "Loading a StrongARM transient"
        ]
        MOV     r2, #1
        STRB    r2, codeflag
 ]
        LDR     r2, PassedFilename
        BL      int_DoLoadFile
        BVS     %FT88

        LDR     r0, CommandLine
        addr    r1, %BA66               ; Null command tail fudge (shared)
        BL      CopyCommandLineAndReadTime

; Don't flatten superstack for PIC objects as they return to me !

        Push    "fp, wp"                ; Need to remember these for return

        LDR     r0, CommandLine
        LDR     r1, commandtailptr

        WritePSRc 0, wp                 ; USR mode, all ints on
        ADD     r5, r3, r5              ; r12 -> transient workspace. Not bank
        SUB     wp, r5, #transient_code ; Must correct as r5 = info + code
                                        ; and r2 = code^
        ADD     sp, wp, #transient_ws   ; r13 -> small stack in the above ws
        ADR     lr, ReturnFromPIC       ; No point in having mode bits set
        MOV     pc, r3                  ; Go to it !


; Failed to load transient after allocating space

88      LDR     r0, globalerror         ; fp is valid, of course ...
        MOV     r1, #V_bit
        B       DeleteTransient

; *****************************************************************************
; Foulup time during runs

92      addr    r0, ErrorBlock_ExecAddrTooLow
        B       %FT98

93      addr    r0, ErrorBlock_ExecAddrNotInCode
        B       %FT98

94      addr    r0, ErrorBlock_NoRoomForTransient

98      BL      CopyError               ; VSet too
        B       RunExit_FF

        LTORG

CheckAIFMemoryLimit ROUT
        Entry   "r5"
        ; Check absolute AIF memory limits
        ; R2 = &8000
        ; R0-R1 corruptible
        ; V set/clear on exit for bad/good
        LDR     lr, [r2, #&0C]
        AND     lr, lr, #&FF000000
        TEQ     lr, #&EB000000          ; is this instruction a branch
        BNE     %FT90                   ; nope - not executable AIF then
        LDR     lr, [r2, #&10]!         ; should be SWI OS_Exit (&EF000011 for AIF), R2 := R2 + 16
        SUB     lr, lr, #&EF000000
        TEQ     lr, #&00000011          ; OS_Exit check worked?
        LDMEQIB r2, {r0,r1,r5,lr}       ; load RO size, RW size, Debug size, ZI size
        MOV     r2, #&8000              ; R2 := &8000 like it was before
        BNE     %FT90                   ; not AIF then

        ADD     lr, lr, r5              ; lr := debug + zero init
        ADD     r0, r0, r1              ; R0 := read only + read write
        ADD     r0, r0, lr              ; R0 := read only + read write + debug + zero init
        ADD     r0, r0, #&2000          ; 8K extra to avoid "Not enough memoy for C library" from silly C stubs
        ADD     r5, r2, r0              ; R5 := base address + size required
        BL      ValidateR2R5_WriteToCoreCodeLoad
        EXIT
90
        CLRV
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; This is where position independent code will return to if it does MOV pc, lr

; Error may be in transient's workspace, so copy before deleting block

ReturnFromPIC

        SavePSR r1                      ; Remember V, you whalley (SWI clears)

        SWI     XOS_EnterOS             ; Get back to superstate in all cases

        Pull    "fp, wp"                ; Sanity slowly restoring ...

; .............................................................................
; In    fp, wp valid
;       r1 = psr
;       r0 -> error block if r1 has V set

DeleteTransient

; Delink this block from the transient list now that it has returned

; Restore saved registers from the block

        LDR     r2, TransientBlock
        LDMIA   r2, {r6-r9, r13-r14}^   ; Writing to r13,r14_usr

        TST     r1, #V_bit              ; Did it report error ?
        BLNE    CopyErrorExternal

        ADR     r0, TransientBlock
        BL      SFreeLinkedArea         ; Accumulates V

        B       Run_Common_NoCopy       ; Lots of deallocation there

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; This is where absolute code will return to if it does MOV pc, lr
; If it did an Exit then the guy with the exit handler has it !
; We'd better do the SWI Exit for it; as the superstack is flat we can't return
;
; In    r0-r2 optionally set such that a return code may be set by called code

ReturnFromAbsoluteCode

        SWI     OS_Exit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadActionVariable
; ==================
;
; Reads Alias$@xxxType_ttt for given ttt and substitutes filename and cmdline
; into the variable as read.

; In    r1 = path tail
;       r2 = load address to decode (000ttt00)
;       r3 -> command tail to append after FullFilename
;       r4 -> variable prefix, eg 'Alias$@LoadType_'
;       r5 -> bit of text to put in error if variable unset
;       r6 = special/scb
;       fscb^ set
; filename plugged in is canonical form

; Out   VC: r0 -> string to do with as you wish
;       string is in ActionVariable, just dying to be freed

ReadActionVariable Entry "r1-r4, r6" ; r0 result

 [ debugcontrol :LOR: debugrun
        DREG    r2, "Action variable for load=",cc
        DSTRING r3, " with command tail ",cc
        DSTRING r4, " onto variable with prefix ",cc
        DSTRING r5, " with error text "
 ]

             ^  0, sp
rav_varname  #  32                      ; Variable name is small
                                        ; as it might be a macro variable
rav_size     *  :INDEX: @

        SUB     sp, sp, #rav_size       ; Room for the variable string + result

        ADR     r3, rav_varname
05      LDRB    r14, [r4], #1           ; Copy variable name in
        TEQ     r14, #0
        STRNEB  r14, [r3], #1           ; No terminator; leave r3 -> next byte
        BNE     %BT05

        MOV     r2, r2, LSR #8          ; Shift -> 00000ttt for common code
        BL      ConvertHex3

; Get alias$@runtype_xxx filename commandline in a buffer

        ADR     r0, rav_varname         ; Point at string again
        MOV     r3, #0

20      MOV     r2, #-1
        SWI     XOS_ReadVarVal          ; Does it exist ? VSet misleading

        CMP     r4, #VarType_Number     ; Set if it's a number (that's silly)
        BEQ     %BT20                   ; Loop if so (maybe others)

        MOVS    r2, r2                  ; -ve -> exists
        BPL     %FA90                   ; [nope, -> Unknown run type]

; Variable exists, so copy RunType_xxx filename commandline to buffer

        LDR     r1, =ScratchSpace
        ADR     r2, rav_varname + (:LEN: "Alias$")
        BL      strcpy_advance

        ADR     r2, s_space
        BL      strcpy_advance

        RSB     r3, r1, #ScratchSpace + ?ScratchSpace
        MOV     r2, r1
        LDR     r1, [sp, #rav_size + 0*4]       ; r1 in
        BL      int_ConstructFullPathWithError
        BVS     %FT88

        MOV     r1, #ScratchSpace
        LDR     r2, [sp, #rav_size+4*2] ; Rest of line from caller r3
        BL      AppendStringIfNotNull

 [ debugrun
 DSTRING r1, "Substituted string is "
 ]
        ADR     r0, ActionVariable      ; Wop this into a string
        BL      SGetLinkedString        ; May have spaces in it
        LDRVC   r0, ActionVariable      ; And return a pointer to it. Phew !

88      ADD     sp, sp, #rav_size
        EXIT

s_space DCB     " ", 0                  ; insert before filing system name
s_colon DCB     ":", 0                  ; insert after filing system name
s_hash  DCB     "#", 0                  ; Inserted before special field
        ALIGN

90      MOV     r0, r5                  ; Stick the appropriate bit in
        BL      CopyError
        B       %BT88                   ; Get out

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r2 =  number
;       r3 -> core

; Out   r2, r3 preserved
;       core contains 'abc', 0

ConvertHex3 Entry "r1"

        MOV     r1, #8                  ; MSN at base bit 8
        BL      NibbleToText
        STRB    r1, [r3, #0]
        MOV     r1, #4                  ; CSN at base bit 4
        BL      NibbleToText
        STRB    r1, [r3, #1]
        MOV     r1, #0                  ; LSN at base bit 0
        STRB    r1, [r3, #3]            ; Terminate string too
        BL      NibbleToText
        STRB    r1, [r3, #2]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 = bitfield base
;       r2 = number

; Out   r1 = nibble at bitfield converted to base 16

NibbleToText Entry

        MOV     r1, r2, ROR r1
        AND     r1, r1, #15
        CMP     r1, #10
        ADDLO   r1, r1, #"0"
        ADDHS   r1, r1, #"A"-10
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; StartApplicEntry. Top level FSControl entry
; ================

; In    r1 -> command tail to append to EnvString
;       r2 = CAO ptr to write
;       r3 -> command name (first bit) to copy to EnvString

StartApplicEntry NewSwiEntry "r0"
 [ debugrun
        DLINE   "StartApplicEntry"
 ]

        MOV     r0, r1
        MOV     r1, #0
        BL      StartUpTheApplication
 [ debugrun
        LDR     r14, globalerror
        TEQ     r14, #0
        BEQ     %FT01
        DLINE   "Globalerror at end of startapplicentry"
        B       %FT02
01
        DLINE   "No error after startapplicentry"
02
 ]
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; StartUpTheApplication
; =====================

; In    r0 -> command tail to append to EnvString
;       r1 -> file to load (at fileblock_load) if non zero
;       r2 =  CAO ptr to write
;       r3 -> command name (first bit) to copy to EnvString
;       r4 = address to load file to if r1!=0
;       r5 -> filename to quote on error if r1!=0
;       r6 = file handle/special field^ if r1!=0
;       r7 = length of file if r1!=0
;       fscb^ if r1!=0

; Out   VC: all ready to go
;       else error raised with OS_GenerateError as application destroyed
;       All linked areas in this domain freed
;       Current FS restored

StartUpTheApplication Entry "r0-r7,fscb"

        ; Copy command line *before* UpCalling etc to ensure it
        ; doesn't get destroyed before needed
        MOV     r1, r0
        MOV     r0, r3
        BL      CopyCommandLineAndReadTime

 [ debugrun
 DREG r2,"StartUpTheApplication: CAO ",cc
 DSTRING r1, ", filename ",cc
 DSTRING r3, ", ComName ",cc
 DSTRING r0, ", ComTail "
 ]
        MOV     r0, #UpCall_NewApplication
        SWI     XOS_UpCall              ; After application gets called
        CMP     r0, #UpCall_Claimed     ; to release handlers we can't give
        BEQ     %FA95                   ; it a VSet return - it's not there

        MOV     r1, #Service_NewApplication
        SWI     XOS_ServiceCall         ; Can never give error
        CMP     r1, #Service_Serviced
        BEQ     %FA96                   ; Must give serious exception type err

 ; try out the pervy scheme for removing handlers
        Push   "r0-r5"
        MOV     r0, #MemoryLimit
        MOV     r1, #0
        SWI     XOS_ChangeEnvironment
        MOV     r5, r1
        MOV     r0, #ExitHandler
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        SWI     XOS_ChangeEnvironment
        CMP     r1, r5
        BLT     application_is_shelling
        MOV     r0, #UndefinedHandler
remove_naff_handlers
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        SWI     XOS_ChangeEnvironment
        CMP     r1, r5
        SWILT   XOS_ReadDefaultHandler
        SWILT   XOS_ChangeEnvironment
        ADD     r0, r0, #1
        CMP     r0, #ExceptionDumpArea
        MOVEQ   r0, #UpCallHandler
        CMP     r0, #UpCallHandler
        BLS     remove_naff_handlers

 ASSERT UpCallHandler+1=MaxEnvNumber  ; any added handlers need consideration

application_is_shelling
        Pull   "r0-r5"

        LDR     r1, [sp, #4]            ; Use passed name as flag
        CMP     r1, #0                  ; Sam calling ? VClear
        BEQ     %FT10

        ; Load file as requested
        ADD     r14, sp, #4*4
        LDMIA   r14, {r3,r5-r7,fscb}
        MOV     r0, #object_file
        MOV     r2, r5
 [ StrongARM
        [ debugsarm
        DLINE   "Loading a StrongARM app"
        ]
        MOV     r4, #1
        STRB    r4, codeflag
 ]
        MOV     r4, r7
        BL      int_DoLoadFile
        BVS     %FT97

        ; Restore r2,r3 afterwards
        ADD     r14, sp, #2*4
        LDMIA   r14, {r2,r3}
10


; Can now set CAO, copy the string + read time for GetEnv

        MOV     r0, #CAOPointer
        MOV     r1, r2
 [ debugrun
        DREG    r2, "Setting CAO pointer to "
 ]
        SWI     XOS_ChangeEnvironment

        BL      SFreeAllLinkedAreas     ; Only in the current domain

        ; Restore TempFS to be CurrentFS
        BL      ReadCurrentFS
        MOVVC   r2, r0
        BL      SetTempFS
        EXIT


95      addr    r0, ErrorBlock_CantStartApplication ; UpCall claimed
        BL      CopyError
        EXIT


96      addr    r0, ErrorBlock_CantStartApplication ; Service claimed
        BL      CopyError

97      BL      SFreeAllLinkedAreas     ; Only in the current domain

        ; Restore TempFS to be CurrentFS
        BL      ReadCurrentFS
        MOVVC   r2, r0
        BL      SetTempFS

        LDR     r0, globalerror         ; Must explode as application has
        SWI     OS_GenerateError        ; got its hooks out

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 -> command first bit
;       r1 -> command tail to append

CopyCommandLineAndReadTime Entry "r0-r2"

 [ debugrun
 DSTRING r0, "CopyCommandLineAndReadTime: First bit ",cc
 DSTRING r1, ", command tail "
 ]
 [ AssemblingArthur
        LDR     r1, =EnvString
 |
        LDR     r1, EnvStringAddr
 ]
        MOV     r2, r0                  ; Command name^
        BL      strcpy
        LDR     r2, [sp, #4]            ; Append command tail to that
        BL      AppendStringIfNotNull
 [ debugrun
 DSTRING r1, "EnvString now "
 ]

        MOV     r0, #14
 [ AssemblingArthur
        LDR     r1, =EnvTime
 |
        LDR     r1, EnvTimeAddr
 ]
        MOV     r14, #3
        STR     r14, [r1]
        SWI     XOS_Word                ; ReadTime shouldn't give error
        CLRV                            ; So make like it didn't !
        EXIT

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r2 -> string (CtrlChar term) to append to r1 string

AppendStringIfNotNull Entry "r2"

 [ debugrun
 DSTRING r2, "AppendStringIfNotNull: "
 ]
        CMP     r2, #1
        LDRHSB  r14, [r2]               ; Is string empty ?
        CMPHS   r14, #space
        ADRHS   r2, %FT90               ; space
        BLHS    strcat
        LDRHS   r2, [sp]                ; string
        BLHS    strcat
        EXIT
90
        DCB     space, 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                       Ones that can be commoned up
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; LibEntry. Top level FSControl entry
; ========

; In    r1 -> command tail

LibEntry NewSwiEntry "r0,r2,r7,fscb" ; FSFunc only preserves r6 up
        ; LibD = user's request
        MOV     r2, #Dir_Library
        BL      ChangeDirectory
        SwiExit

; .............................................................................
;
; CatEntry. Top level FSControl entry
; ========

; In    r1 -> command tail (for Cat, Ex, Info)

CatEntry NewSwiEntry "r0-r7,fscb"

        ; Set up a mask for Cat/Ex
        TEQ     r0, #FSControl_Cat
        TEQNE   r0, #FSControl_LCat
        MOVEQ   r7, #fsextra_FSDoesCat
        MOVNE   r7, #fsextra_FSDoesEx

        TEQ     r0, #FSControl_Cat
        TEQNE   r0, #FSControl_Ex
        MOVEQ   r5, #0                          ; Relative to @ (default)
        MOVNE   r5, #TopPath_RelativeToLib      ; Relative to %
        MOV     r2, #NULL
        addr    r3, anull
        BL      TopPath_DoBusinessForDirectoryRead
        BVS     %FT90

        LDR     lr, [fscb, #fscb_extra]
        TST     lr, r7
        BNE     %FT20

        BL      int_CatExTitle
        BVS     %FT80

        ; Set up the parameters
        TEQ     r7, #fsextra_FSDoesCat
        MOVEQ   r0, #0                  ; Cat-style body
        MOVNE   r0, #1                  ; Ex-style body
        addr    r2, fsw_wildstar
        BL      int_CatExBody
        B       %FT80

20
        ; FS does the operation - send it through
        TEQ     r7, #fsextra_FSDoesCat
        MOVEQ   r0, #fsfunc_Cat
        MOVNE   r0, #fsfunc_Ex
        BL      CallFSFunc_Given

80
        BL      JunkFileStrings
90
        SwiExit

; .............................................................................
;
; InfoEntry. Top level FSControl entry
; ==========

; In    r1 -> command tail

; Performs *Info or *FileInfo

InfoEntry NewSwiEntry "r0-r8,fscb"

        BL      Process_WildPathnameMustExist
        BVS     %FT97
        TEQ     r7, #NULL
        BEQ     %FT10

        ; Wildcard enumeration required
        MOV     r2, r7
        LDR     r14, [fp, #0]
        TEQ     r14, #FSControl_Info
        MOVEQ   r0, #1                  ; Ex-style body
        MOVNE   r0, #2                  ; FileInfo-style body
        BL      int_CatExBody
        BL      JunkFileStrings
        B       %FT97

10
        ; Check for FileInfo on filing systems which do it themselves
        LDR     r14, [fp, #0]
        TEQ     r14, #FSControl_Info
        LDRNE   r14, [fscb, #fscb_info]
        TSTNE   r14, #fsinfo_fileinfo
        BEQ     %FT15

        MOV     r0, #fsfunc_FileInfo
        BL      CallFSFunc_Given
        B       %FT95


15
        ; It's an absolute or non-wildcard which needs Infoing, so
        ; let's do it by hand

        GetLumpOfStack r8, #CatStringSpace, #CatStringSpace, #2048, %FA80

        ; Find the last . in the tail to get a leaf name
        MOV     r6, r1
20
        LDRB    r14, [r6], #1
        TEQ     r14, #"."
        MOVEQ   r1, r6
        TEQ     r14, #0
        BNE     %BT20

        ; Construct the cat and FileInfo parts in the stack buffer
        MOV     r6, sp
        ADD     r7, r6, r8

 [ CatExLong
        Push    "r8,r10"

	Push	"r0-r4"

        SUB     sp, sp, #16
        MOV     r2, #15
        MOV     r1, sp
        MOV     r3, #0
        MOV     r4, #3                          ; we want to convert it to a string (so that Macros will be sorted)

        ADRL     r0, CatExMaxWidthStr            ; variable name

        SWI     XOS_ReadVarVal                  ; get the variable back

 [ debugcontrol
        DREG    r1, "ptr: "
 ]

        MOVVS   r2, #255                        ; maximum limit
        BVS     %FT30                           ; variable not found or too long - ignore it

        CMPS    r4, #1

        LDREQ   r2, [sp]
        BEQ     %FT30


        ; convert its value

        MOV     r0, #0                          ; terminate the string
        STRB    r0, [sp, r2]                    ;

        MOV     r0, #10+(1<<30)                 ; base 10, restrict range 0-255
        MOV     r1, sp

 [ debugcontrol
        DSTRING r1, "string: "
 ]

        SWI     XOS_ReadUnsigned                ; get the value

 [ debugcontrol
        DREG    r2, "converted to: "
 ]

        MOVVS   r2, #255

30      ; here, r2 should contain the max width, or zero
        ADD     sp, sp, #16

        CMPS    r2, #255
        MOVHI   r2, #255

        MOVS    r2, r2
        MOVMI   r2, #12

 [ debugcontrol
        DREG    r2, "init width: "
 ]

        ; now compare screen with and entry width

	SUB	sp, sp, #4
        ADRL    r0, CatExBody_WindBlock
        MOV	r1, sp
        SWI     XOS_ReadVduVariables
	LDRVC	r0, [sp]
	ADD	sp, sp, #4
	STRVS	r0, [sp]
        BVS     %FT40

        LDR     r14, [fp, #0]


        TEQ     r14, #FSControl_Info
        SUBEQ   r0, r0, #63-12
        TEQ     r14, #FSControl_FileInfo
        SUBEQ   r0, r0, #68-12

 [ debugcontrol
        DREG    r0, "width available from screen "
 ]

	LDR	r1, [sp, #4]
	BL	strlen

        CMPS    r3, r0
        MOVGT   r3, r0

        CMPS    r3, r2                          ; set the min width
        MOVGT   r3, r2

        CMPS    r3, #CatExMinWidth              ; and if it's <12, make it 12
        MOVLT   r3, #CatExMinWidth

        MOV     r10, R3        			; and now we have a width!

	CLRV
40
	STRVS	r0, [sp]
	Pull	"r0-r4"
	BVS	%FT60
 |
	Push	"R8"

 ]

        LDR     r14, [fp, #0]
        TEQ     r14, #FSControl_Info
        MOVEQ   r8, #1                  ; Ex item
        TEQ     r14, #FSControl_FileInfo
        MOVEQ   r8, #2                  ; FileInfo item
        BL      int_CatExItem

 [ CatExLong
60
        Pull    "r8,r10"
 |
        Pull    "r8"
 ]

        ; output them
        MOVVC   r0, sp
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        ADD     sp, sp, r8
        B       %FT85

80
        addr    r0, ErrorBlock_NotEnoughStackForFSEntry
        BL      CopyError
        B       %FT95

85
        BLVS    CopyErrorExternal

95
        BL      JunkFileStrings
97
        SwiExit

; .............................................................................
;
; AccessEntry. Top level FSControl entry
; ===========
;
; The attribute string is not checked and may contain any old junk, and should
; be assumed to be space or CtrlChar terminated

; In    r1 -> filename
;       r2 -> attribute string (space terminated)
AccessEntry NewSwiEntry "r0-r9,fscb"
 [ debugcontrol
        DSTRING r1, "Access ",cc
        DSTRING r2, " to "
 ]
        MOV     r9, r2

        ; Find the file(s)
        BL      Process_WildPathnameMustExist
        SwiExit VS
 [ debugcontrol
        DSTRING r1, "Tail from process etc is "
        DSTRING r7, "Leaf from .. is "
 ]

        LDR     lr, [fscb, #fscb_info]
        TST     lr, #fsinfo_giveaccessstring
        MOVNE   r8, r9
        BNE     %FT30

        ; Process the access string syntax: [lLwWrR]*/[wWrR]*
        MOV     r8, #0
10
        LDRB    r14, [r9], #1
        CMP     r14, #space
        TEQHI   r14, #delete
        BLS     %FT30
        TEQ     r14, #"l"
        TEQNE   r14, #"L"
        ORREQ   r8, r8, #locked_attribute
        BEQ     %BT10
        TEQ     r14, #"w"
        TEQNE   r14, #"W"
        ORREQ   r8, r8, #write_attribute
        BEQ     %BT10
        TEQ     r14, #"r"
        TEQNE   r14, #"R"
        ORREQ   r8, r8, #read_attribute
        BEQ     %BT10
        TEQ     r14, #"/"
        BNE     %FT95

20
        LDRB    r14, [r9], #1
        CMP     r14, #space
        TEQHI   r14, #delete
        BLS     %FT30
        TEQ     r14, #"w"
        TEQNE   r14, #"W"
        ORREQ   r8, r8, #public_write_attribute
        BEQ     %BT20
        TEQ     r14, #"r"
        TEQNE   r14, #"R"
        ORREQ   r8, r8, #public_read_attribute
        BEQ     %BT20
        B       %FT95

30
 [ debugcontrol
        DREG    r8, "Access value calculated is "
 ]

        TEQ     r7, #NULL
        BNE     %FT40

        LDR     lr, [fscb, #fscb_info]
        TST     lr, #fsinfo_giveaccessstring
        BNE     %FT35

        ; Set access, single object, using fsfile_WriteInfo
        MOV     r5, r8
        MOV     r0, #fsfile_WriteInfo
        BL      CallFSFile_Given
        B       %FT72

35
        ; Set access, single object, using *Access entry
        MOV     r2, r8
        MOV     r0, #fsfunc_Access
        BL      CallFSFunc_Given
        B       %FT72

40
        ; Wildcard operation
        GetLumpOfStack r5, #CatSpace, #CatSpace, #2048, %FA90

        MOV     r4, #0
50
        ADD     r14, sp, r5
        MOV     r0, #fsfunc_ReadDirEntriesInfo
        MOV     r2, sp
        MOV     r3, #CatSpace + CatSpaceAdjustForNFS
        Push    "r1,r5"
        MOV     r5, #CatSpace + CatSpaceAdjustForNFS
        BL      CallFSFunc_Given
        Pull    "r1,r5"
        BVS     %FT85

 [ debugcontrol
        DSTRING r1, "Tail after read entries is "
        DSTRING r7, "Leaf after read entries is "
 ]
        TEQ     r3, #0
        BEQ     %FT75

        Push    "r1,r3,r4,r5"
        ADD     r1, sp, #4*4
55
        ; Fill the buffer on the stack

        ; pick out load, execute, length, Attributes, objecttype, advancing r1 to the object name
        LDMIA   r1!, {r2,r3,r4,r5,r14}

        MOV     r0, r2
        MOV     r2, r7
        BL      WildMatch
        BNE     %FT60
        MOV     r2, r0

        ; Construct <Tail>.<leaf> on a new piece of linked string
        SUB     sp, sp, #4
        Push    "r1,r2,r3"
 [ debugcontrol
        DSTRING r1, "leaf for strlen is "
 ]
        BL      strlen                  ; <leaf>
        LDR     r1, [sp, #3*4 + 4 + 0*4]
 [ debugcontrol
        DSTRING r1, "tail for strlen is "
 ]
        BL      strlen_accumulate       ; <Tail>
        ADD     r3, r3, #1 + 1          ; 1 for the ., and one for the terminator
        ADD     r0, sp, #3*4
 [ debugheap
        DLINE   "AccessEntry:",cc
 ]
        BL      SGetLinkedArea
        ADDVS   sp, sp, #3*4 + 4
        BVS     %FT65
        Swap    r1, r2
 [ debugcontrol
        DSTRING r2, "tail for strcpy is "
 ]
        ; If in root dir of partition then tail will be nul
        LDRB    r14, [r2]
        TEQ     r14, #0
        BLNE    strcpy_advance          ; <Tail>
        MOVNE   r2, #"."
        STRNEB  r2, [r1], #1            ; .
        LDR     r2, [sp, #0*4]
 [ debugcontrol
        DSTRING r2, "leaf for strcpy is "
 ]
        BL      strcpy                  ; <Leaf>
        Pull    "r1,r2,r3"

        ; Having constructed <Tail>.<Leaf> change its access.
        Push    "r1"

        LDR     r1, [sp, #1*4]          ; <Tail>.<Leaf>

        LDR     lr, [fscb, #fscb_info]
        TST     lr, #fsinfo_giveaccessstring
        BNE     %FT56

        MOV     r0, #fsfile_WriteInfo
 [ debugcontrol
        DSTRING r1, "Path for WriteInfo is "
 ]
        MOV     r5, r8
        BL      CallFSFile_Given
        B       %FT58

56
        MOV     r0, #fsfunc_Access
        MOV     r2, r8
        BL      CallFSFunc_Given

58
        Pull    "r1"
        MOV     r0, sp
        BL      SFreeLinkedArea
        ADD     sp, sp, #4
        BVS     %FT65

60
        ; Advance to the next item (skip over the name and round up to a word)
        ADD     r3, r1, #1 + 3          ; 1 for the nul terminator, 3 for the rounding
        BL      strlen_accumulate
        BIC     r1, r3, #3

        ; Any more items in this batch?
        LDR     r3, [sp, #1*4]
        SUBS    r3, r3, #1
        STR     r3, [sp, #1*4]
        BNE     %BT55

65
        ; General end of Push - BVS for those error branches
        Pull    "r1,r3,r4,r5"
        BVS     %FT85

        CMP     r4, #-1
        BNE     %BT50

70
        ; Drop the stack chunk used for reading the entries
        ADD     sp, sp, r5

72
        ; No more items to read
        BL      JunkFileStrings
        SwiExit

75
        ; No items read

        ; Was it the end?
        CMP     r4, #-1
        BEQ     %BT70

        ; Wasn't end, so must be buffer overflow
        addr    r0, ErrorBlock_BuffOverflow
80
        BL      CopyError
85
        B       %BT70

90
        ; Not enough stack for *Access
        addr    r0, ErrorBlock_NotEnoughStackForFSEntry
        BL      CopyError
        B       %BT72

95
        ; Bad access attributes
        addr    r0, MagicErrorBlock_BadAccessAttributes
        LDR     r1, [fp, #2*4]          ; r2 in
        BL      MagicCopyError
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DirEntry. Top level FSControl entry
; ========

; In    r1 -> command tail
PSDPath DCB "\\", 0
        ALIGN

BackEntry
        ADR     r1, PSDPath

DirEntry NewSwiEntry "r0,r2,r7,fscb"

 [ debugcontrol
        DSTRING r1, "Setting CSD to "
 ]

        MOV     r2, #Dir_Current
        BL      ChangeDirectory
        SwiExit VS
        TEQ     r7, #0
        SwiExit EQ
        MOV     r2, fscb
        BL      SetCurrentFS
        BL      SetTempFS
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CanonicalisePathEntry. Top level FSControl entry
; =====================
;
; In    r1 -> filename to be canonicalised
;       r2 = pointer to buffer to be filled in
;       r3 = Pointer to system variable name of path to use, or 0 if none
;       r4 = Pointer to default path to use if no system variable is specified
;               or if that variable doesn't exist, or 0 if no path is the default
;       r5 = buffer length
;
; Out   r5 = space left in buffer including the
;               terminator.
;
CanonicalisePathEntry NewSwiEntry "r0-r6,fscb"
 [ debugcontrolentry
        DSTRING r1, "CanonicalisePath(",cc
        DREG    r2, ",",cc
        DSTRING r3, ",",cc
        DSTRING r4, ",",cc
        DREG    r5, ",",cc
        DLINE   ""
 ]
        ADR     r0, PassedFilename
        MOV     r2, r3
        MOVS    r3, r4
        addr    r3, anull, EQ
        ADR     r4, FullFilename
        MOV     r5, #TopPath_Canonicalise
        ADR     r6, SpecialField
        BL      TopPath_DoBusinessToPath
        SwiExit VS
        LDR     r2, [fp, #2*4]
        LDR     r3, [fp, #5*4]
        BL      int_ConstructFullPath
        STR     r3, [fp, #5*4]
        BL      JunkFileStrings
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; InfoToFileTypeEntry. Top level FSControl entry
; ===================
;
; In    r1 -> filename
;       r2 = load address
;       r3 = execute address
;       r4 = length
;       r5 = attributes
;       r6 = objecttype
;
; Out   r2 = filetype
;       Special file types:
;       -1      untyped
;       &1000   directory
;       &2000   application
;
InfoToFileTypeEntry NewSwiEntry
        BL      InfoToFileType
        SwiExit

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; InfoToFileType
;
; In    r1 -> filename
;       r2 = load address
;       r3 = execute address
;       r4 = length
;       r5 = attributes
;       r6 = objecttype
;
; Out   r2 = filetype
;       Special file types:
;       -1      untyped
;       &1000   directory
;       &2000   application
;
InfoToFileType Entry "r3"
        TEQ     r6, #object_file
        BNE     %FT10

        ; It's a file
        BL      IsFileTyped
        BLEQ    ExtractFileType
        MOVNE   r2, #-1
        EXIT

10
        ; It's not a file
        TST     r6, #object_directory
        MOVEQ   r2, #-1                 ; Not a directory
        BEQ     %FT20

        ; It's a directory, check leaf for starting with a !
        BL      strlen
12
        LDRB    r14, [r1, r3]
        TEQ     r14, #"."
        BEQ     %FT15
        SUBS    r3, r3, #1
        BPL     %BT12
15
        ADD     r3, r3, #1
        LDRB    r14, [r1, r3]
        TEQ     r14, #"!"
        MOVEQ   r2, #&2000
        MOVNE   r2, #&1000

20
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; URDEntry. Top level FSControl entry
; ========

; In    r1 -> command tail

URDEntry NewSwiEntry "r2,r7,fscb"

        MOV     r2, #Dir_UserRoot
        BL      ChangeDirectory

        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; NoURDEntry. Top level FSControl entry
; ==========
; NoLibEntry. Top level FSControl entry
; ==========
; NoDirEntry. Top level FSControl entry
; ==========

; In    r1 -> command tail

NoURDEntry
NoLibEntry
NoDirEntry NewSwiEntry "r0,r2,fscb"

        TEQ     r0, #FSControl_NoDir
        MOVEQ   r2, #Dir_Current
        TEQ     r0, #FSControl_NoURD
        MOVEQ   r2, #Dir_UserRoot
        TEQ     r0, #FSControl_NoLib
        MOVEQ   r2, #Dir_Library

        BL      ReadTempFS
        TEQVS   r0, r0          ; set EQ if VS
        TEQVC   r0, #Nowt
        MOVNE   fscb, r0
        BLNE    UnsetDir        ; If VC and NE

        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                   Ones that can't really be commoned up
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; OptEntry. Top level FSControl entry
; ========
;
; Filing System action control

; In    r1 = first parm, r2 = second parm

OptEntry NewSwiEntry "r0-r5, r6, fscb" ; FSFunc only preserves r6 up

        BL      ReadTempFS
        BVS     %FA90
        MOV     fscb, r0
        TEQ     fscb, #Nowt             ; Give 'No sel FS' error lower down
        BEQ     %FT10

        CMP     r1, #1                  ; Keep a note of OPT 1 setting ?
        MOVLO   r2, #0                  ; Default setting is 0 / CMOS ?
        STRLSB  r2, [fscb, #fscb_opt1]  ; Keep a note of/Reset OPT 1 setting ?
        BEQ     %FA90 ; SwiExit         ; Don't tell Filing System EVER

10      MOV     r0, #fsfunc_Opt         ; Numeric arguments
        MOV     r6, #0                  ; Use current context
        BL      CallFSFunc_Given        ; Use fscb^

90
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; RenameEntry. Top level FSControl entry
; ===========

; In    r1 -> path to rename
;       r2 -> new name for file(s)

RenameEntry NewSwiEntry "r0-r8,scb,fscb"

 [ debugcontrol
	DSTRING	r1, "source pathname: "
	DSTRING	r2, "new pathname: "
 ]


        ; Do business to source and check it exists
        ADR     r0, PassedFilename
        MOV     r2, #NULL
        addr    r3, anull
        ADR     r4, FullFilename
        MOV     r5, #TopPath_NoMultiParts
        ADR     r6, SpecialField
        BL      TopPath_DoBusinessToPath
        SwiExit VS
        TEQ     r0, #object_nothing
        BEQ     %FT90

        ; Hold source fscb, special and path tail for a while
        MOV     r7, r6
        MOV     r8, fscb
        MOV     r9, r1          ; r9 is also scb which isn't needed yet

        ; Do business to destination and check it doesn't exist
        LDR     r1, [fp, #2*4]          ; r2 in
        ADR     r0, PassedFilename2
        MOV     r2, #NULL
        addr    r3, anull
        ADR     r4, FullFilename2
        MOV     r5, #TopPath_NoMultiParts
        ADR     r6, SpecialField2
        BL      TopPath_DoBusinessToPath
        BVS     %FT95

        ; Check the fscbs match
        TEQ     r8, fscb
        BNE     %FT75

        ; r8 now freed as its the same as fscb

        ; Hold destination path tail in r8
        MOV     r8, r1

        ; Check the special fields match

        LDRB    r14, [fscb, #fscb_info]
        TEQ     r14, #0
        BEQ     %FT10

        ; Check special fields on ordinary filing systems
        MOV     r1, r6
        MOV     r2, r7
        BL      strcmp
        B       %FT20

10
        ; Check special fields on MultiFS filing systems
        TEQ     r6, r7

20
        BNE     %FT75           ; Branch on special field mismatch

        ; As the special fields match there is no need to worry about their order
        ; In fact, at the moment the special fields are the wrong way round!

        ; Now we know the fscb and special fields match, check for rename to existing, different
        ; object
        MOV     r1, r9          ; source path tail
        MOV     r2, r8          ; Destination path tail
        TEQ     r0, #object_nothing
        BLNE    strcmp
        BNE     %FT85           ; Branch if destination exists and it isn't the source

        BL      TryGetFileClosed
        BVS     %FT94

        ; Filing systems and special fields match - do the rename
        MOV     r0, #fsfunc_Rename
        Push    "r2-r5"
        BL      CallFSFunc_Given
        Pull    "r2-r5"
        BVS     %FT94

        ; Check if FS managed it
        TEQ     r1, #0
        BNE     %FT75

        ; The rename has worked - sort out the carnage to the internals of FileSwitch!

        ; Move source and destination tail down to r1 and r2
        MOV     r1, r9          ; source path tail
        MOV     r2, r8          ; Destination path tail

        BL      SortOutRenameCarnage

        B       %FT94

75
        ; Special fields don't match
        ; Filing systems don't match
        addr    r0, ErrorBlock_BadRename
        BL      CopyError
        B       %FT94

85
        ; Destination is found
        addr    r0, MagicErrorBlock_RenameDestinationFound
        LDR     r1, PassedFilename2
        BL      MagicCopyError

94
        ; Exit if both sets of path strings are still allocated
        ADR     r0, SpecialField2
        BL      SFreeLinkedString
        ADR     r0, FullFilename2
        BL      SFreeLinkedString
        ADR     r0, PassedFilename2
        BL      SFreeLinkedString
        B       %FT95

90
        ; Source not found
        LDR     r1, PassedFilename
        BL      SetMagicPlainNotFound

95
        BL      JunkFileStrings
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SortOutRenameCarnage
; ====================
;
; Sorts out the carnage to FileSwitch's internals after a rename has happened.
; Used by Rename and NameDisc.

; In
; r1 = source path tail
; r2 = destination path tail
; r6 = special of renamed
; fscb = fscb of renamed
;
; Out
; FileSwitch's internals updated to keep up-to-date with the change

SortOutRenameCarnage Entry "r0,r3,r4,scb"

        ; For each open file check whether it's one that's been renamed, and change its name if it is

        MOV     r0, #MaxHandle          ; Allocate handles from MaxHandle..1
        ADRL    r3, UnallocatedStream   ; Indicator of unused stream
        ADR     r4, streamtable
10      LDR     scb, [r4, r0, LSL #2]   ; Empty slot found ?
        TEQ     scb, r3
        BLNE    SortOutRenameCarnage_OneFile
       ; BVS     %FT30 IGNORE ERRORS WE WANT TO PROCESS ALL FILES
        SUBS    r0, r0, #1
        BNE     %BT10                   ; If reached handle 0 that's all

        ; For each of the relevant directory system variables check whether it needs changing

        BL      SortOutRenameCarnage_TheDirs

        EXIT

; SortOutRenameCarnage_OneFile
; ============================
;
; Subroutine of SortOutRenameCarnage which deals with a single file
;
; In    r1 = source tail of renamed
;       r2 = destination tail of renamed
;       r6 = special of renamed
;       scb -> candidate renamee
;       fscb = fscb of renamed
;
; Out   If has been renamed, then contents of scb have been updated
;
SortOutRenameCarnage_OneFile Entry "r0-r3"

        ; Check fscb
        LDR     r14, scb_fscb
        TEQ     r14, fscb
        EXIT    NE              ; Exit if fscb mismatches

 [ debugcontrol
 DREG   scb, "scb ",cc
 DLINE  " matched fscb"
 ]

        ; Check special field
        LDR     r2, scb_special         ; Don't care if we trample r1 & r2 - they're on the stack
        LDRB    r14, [fscb, #fscb_info]
        TEQ     r14, #0
        BEQ     %FT10

        ; Special field check for non-MultiFS
        MOV     r1, r6
 [ debugcontrol
 DSTRING r1, "Comparing special ",cc
 DSTRING r2, " against "
 ]
        BL      strcmp
        B       %FT50

10
        ; Special field check for a MultiFS
 [ debugcontrol
 DREG   r1, "Comparing special ",cc
 DREG   r2, " against "
 ]
        TEQ     r2, r6

50
        EXIT    NE              ; Exit if special mismatches

        ; It's an fscb and special field match - now check the names
        LDR     r1, [sp, #1*4]          ; Source path tail
        LDR     r2, scb_path
 [ debugcontrol
 DSTRING r1, "Comparing path ",cc
 DSTRING r2, " against "
 ]
        BL      IsAChild_advance
        EXIT    NE              ; Exit if rename source path mismatches file's name

        ; It's been renamed - change the path
        MOV     r1, r2
 [ debugcontrol
 DSTRING r1, "Accumulating path tail "
 ]
        BL      strlen                  ; Length of scb's name's tail
        LDR     r1, [sp, #2*4]          ; Destination path tail
 [ debugcontrol
 DSTRING r1, "Accumulating rename destination "
 ]
        BL      strlen_accumulate       ; + length of destination
        ADD     r3, r3, #1              ; + 1 for the terminator
        MOV     r0, r2                  ; preserve path tail
        BL      SMustGetArea
        EXIT    VS                      ; failed to get new area

 [ debugcontrol
 DREG   r2, "Got area "
 ]

        MOV     r1, r2                  ; Start of new area for copying into
        MOV     r3, r2                  ; for storing as a replacement
        LDR     r2, [sp, #2*4]          ; destination path tail
 [ debugcontrol
 DSTRING r2, "Appending "
 ]
        BL      strcpy_advance          ; Copy destination name
        MOV     r2, r0
 [ debugcontrol
 DSTRING r2, "Appending "
 ]
        BL      strcpy_advance          ; Copy path tail
        LDR     r2, scb_path
 [ debugcontrol
 DREG   r2, "Freeing old path "
 ]
        BL      SFreeArea               ; free the old tail
        MOVVS   r2, r3
        BLVS    SFreeArea               ; if error free the new tail
 [ debugcontrol
 BVS    %FT01
 DREG   r3, "Storing new path "
01
 ]
        STRVC   r3, scb_path            ; if no error store the new tail

        EXIT                            ; return

; SortOutRenameCarnage_TheDirs
; ============================
;
; Subroutine of SortOutRenameCarnage which deals with the dirs
;
; In    r1 = source tail of renamed
;       r2 = destination tail of renamed
;       r6 = special of renamed
;       fscb = fscb of renamed
;
; Out   If has been renamed, then dirs updated
;
SortOutRenameCarnage_TheDirs Entry "r0-r4,r8"
        MOV     r8, sp

        ; Construct on the stack a suitable prefix
        MOV     r2, #Nowt
        MOV     r3, #0
        BL      int_ConstructPathWithoutFS
        RSB     r3, r3, #3 + 1
        BIC     r3, r3, #3
        SUB     sp, sp, r3
        MOV     r2, sp
        BL      int_ConstructPathWithoutFS
        MOV     r0, sp

        ; Construct on the stack a new prefix
        LDR     r1, [r8, #2*4]
        MOV     r2, #Nowt
        MOV     r3, #0
        BL      int_ConstructPathWithoutFS
        RSB     r3, r3, #3 + 1
        BIC     r3, r3, #3
        SUB     sp, sp, r3
        MOV     r2, sp
        BL      int_ConstructPathWithoutFS

        MOV     r1, r0
        MOV     r2, sp
        ADD     r3, fscb, #fscb_name

        BL      AlterMatchingDirs

        MOV     sp, r8
        EXIT



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DefectListEntry. Top level FSControl entry
; ===============

; In    r1 -> path for defect list to assessed
;       r2 -> buffer to fill
;       r5 = buffer length

; Out   regs preserved

; AddDefectEntry. Top level FSControl entry
; ==============

; In    r1 = path for defect
;       r2 = defect address

; Out   regs preserved

; ReadFreeSpaceEntry. Top level FSControl entry
; ==================

; In    r0 = 49
;       r1 = pointer to nul-terminated name of object on thing whose free space is to be read

; Out   r0 = free space
;       r1 = biggest creatable object
;       r2 = disc size

; ReadFreeSpace64Entry. Top level FSControl entry
; ====================

; In    r0 = 55
;       r1 = pointer to nul-terminated name of object on thing whose free space is to be read

; Out   r0 = free space (low)
;       r1 = free space (high)
;       r2 = largest creatable object
;       r3 = disc size (low)
;       r4 = disc size (high)

; DefectList64Entry.  Top level FSControl entry
; ==================

; In    r0 = 56
;       r1 -> path for defect list
;       r2 -> buffer to fill
;       r5 = buffer length

; Out   r1 = number of defects returned

; AddDefect64Entry.  Top level FSControl entry
; =================

; In    r0 = 57
;       r1 -> path for defect
;       r2 = ls word of byte offset to defect
;       r3 = ms word of byte offset to defect

; Out   all preserved

; UsedSpaceMapEntry. Top level FSControl entry
; =================

; In    r0 = 46
;       r1 = pointer to nul-terminated name of image
;       r2 = start of buffer in memory
;       r5 = buffer length

; Out   regs preserved

; StampImageEntry. Top level FSControl entry
; ===============

; In    r1 = path of file on disc to be image-stamped
;       r2 = sub-reason:
;               0       Stamp on next update
;               1       Stamp now

; Out   regs preserved

; ObjectAtOffsetEntry. Top level FSControl entry
; ===================

; In    r1 = path of file on disc to be searched
;       r2 = offset into image
;       r3 = pointer to buffer for name
;       r4 = buffer length

; Out   r2 = kind of thing found:
;               0       free/defect/off end of image
;               1       allocated, not a file or directory
;               2       found, unique owner
;               3       found, shared
;       buffer filled with found file/directory name

DefectListEntry
AddDefectEntry
ReadFreeSpaceEntry
UsedSpaceMapEntry
StampImageEntry
ObjectAtOffsetEntry
ReadFreeSpace64Entry
DefectList64Entry
AddDefect64Entry
        NewSwiEntry "r0-r6,fscb"
        MOV     r2, #0
        addr    r3, anull
        MOV     r5, #TopPath_WantPartition
        BL      TopPath_DoBusinessForDirectoryRead
        SwiExit VS
        LDR     r0, [fscb, #fscb_info]
        TST     r0, #&ff
        BEQ     %FT10
        TST     r0, #fsinfo_multifsextensions
        BNE     %FT10
        addr    r0, ErrorBlock_UnsupportedFSEntry
        BL      CopyError
        B       %FT90

10
        LDR     r2, [fp, #2*4]          ; buffer/defect address
        LDR     r3, [fp, #3*4]          ; top32 of defect addr for AddDefect64
        LDR     r5, [fp, #5*4]          ; buffer size
        LDR     lr, [fp, #0*4]          ; Op
        TEQ     lr, #FSControl_DefectList
        MOVEQ   r0, #fsfunc_DefectList
        TEQ     lr, #FSControl_AddDefect
        MOVEQ   r0, #fsfunc_AddDefect
        TEQ     lr, #FSControl_ReadFreeSpace
        MOVEQ   r0, #fsfunc_ReadFreeSpace
        TEQ     lr, #FSControl_ReadFreeSpace64
        MOVEQ   r0, #fsfunc_ReadFreeSpace64
        TEQ     lr, #FSControl_StampImage
        MOVEQ   r0, #fsfunc_StampImage
        TEQ     lr, #FSControl_UsedSpaceMap
        MOVEQ   r0, #fsfunc_UsedSpaceMap
        TEQ     lr, #FSControl_ObjectAtOffset
        MOVEQ   r0, #fsfunc_ObjectAtOffset
        TEQ     lr, #FSControl_DefectList64
        MOVEQ   r0, #fsfunc_DefectList64
        TEQ     lr, #FSControl_AddDefect64
        MOVEQ   r0, #fsfunc_AddDefect64

        TEQ     r0, #fsfunc_UsedSpaceMap
        BNE     %FT20

        ; Zero out the buffer for UsedSpaceMap
        MOV     lr, #0
        MOV     r4, #0
15
        STRB    r4, [r2, lr]
        ADD     lr, lr, #1
        CMP     lr, r5
        BLO     %BT15

20
        TEQ     r0, #fsfunc_ObjectAtOffset
        BNE     %FT60

        LDR     r3, [fp, #3*4]          ; buffer
        LDR     r4, [fp, #4*4]          ; length

        ; Push into the buffer the path prefix
        Push    "r2"
        BL      fscbscbTofscb
        ADD     r2, r2, #fscb_name
25
        SUBS    r4, r4, #1
        ADDLS   sp, sp, #1*4
        BLS     %FT55
        LDRB    lr, [r2], #1
        STRB    lr, [r3], #1
        TEQ     lr, #0
        BNE     %BT25
        Pull    "r2"

        SUBS    r4, r4, #1
        BLS     %FT55
        MOV     lr, #":"
        STRB    lr, [r3, #-1]


        LDRB    lr, [fscb, #fscb_info]
        TEQ     lr, #0
        BEQ     %FT45

 [ debugcontrol
        DLINE   "Prefix for non-MultiFS"
 ]

        ; Ordinary filing system
        Push    "r0,r1"

        ; Copy prefix up to absolute

40
        SUBS    r4, r4, #1
        ADDLS   sp, sp, #2*4
        BLS     %FT55
        LDRB    r0, [r1], #1
        STRB    r0, [r3], #1
        TEQ     r0, #0
        BLNE    IsAbsolute
        BNE     %BT40

        Pull    "r0,r1"
 [ debugcontrol
        MOV     lr, #0
        STRB    lr, [r3]
        Push    "r3"
        LDR     r3, [fp, #3*4]
        DSTRING r3, "String prefix is "
        Pull    "r3"
 ]
        B       %FT60

45
 [ debugcontrol
        DLINE   "Prefix for MultiFS"
 ]

        ; Processing for a MultiFS
        Push    "r1,r2,r3"
        MOV     r2, r3
        LDR     lr, FullFilename
        SUB     r3, r1, lr
        LDRB    r1, [r1]
        TEQ     r1, #0
        SUBNE   r3, r3, #1
        MOV     r1, lr
        SUBS    r4, r4, r3
        ADDLS   sp, sp, #3*4
        BLS     %FT55
        LDR     lr, [sp, #2*4]
        ADD     lr, lr, r3
        STR     lr, [sp, #2*4]
        BL      MoveBytes
        MOV     r0, #fsfunc_ObjectAtOffset

50
        Pull    "r1,r2,r3"
 [ debugcontrol
        MOV     lr, #0
        STRB    lr, [r3]
        Push    "r3"
        LDR     r3, [sp, #3*4 + 1*4]
        DSTRING r3, "String prefix is "
        Pull    "r3"
 ]
        B       %FT60

55
        addr    r0, ErrorBlock_BuffOverflow
        BL      CopyError
        B       %FT90

60
        BL      CallFSFunc_Given
        BVS     %FT90

        ; Return parameters in ReadFreeSpace
        LDR     lr, [fp, #0*4]          ; Op

        TEQ     lr, #FSControl_ReadFreeSpace
        STMEQIA fp, {r0,r1,r2}
        TEQ     lr, #FSControl_ReadFreeSpace64
        STMEQIA fp, {r0-r4}
        TEQ     lr, #FSControl_ObjectAtOffset
        STREQ   r2, [fp, #2*4]
        TEQ     lr, #FSControl_DefectList64
        STREQ   r1, [fp, #1*4]

90
        BL      JunkFileStrings
        SwiExit

; EnumerateHandlesEntry. Top level FSControl entry
; =====================

; In    r0 = 58
;       r1 = last handle enumerated, or -1 to start

; Out   r0 = stream status word
;       r1 = handle number, or -1 for no more
;       r2 = filing system info word

EnumerateHandlesEntry
        NewSwiEntry "scb"
10
        ADD     r1, r1, #1
        CMP     r1, #MaxHandle
        MOVHI   r1, #-1
        BHI     %FT90

        ADR     r14, streamtable
        LDR     scb, [r14, r1, LSL #2]
        ADRL    r14, UnallocatedStream
        CMP     scb, r14
        BEQ     %BT10

        LDR     r0, scb_status
        LDR     r14, scb_fscb
        LDR     r2, [r14, #fscb_info]
90
        SwiExit

; NameDiscEntry. Top level FSControl entry
; =============

; In    r1 = path of file on disc to be renamed
;       r2 = new name for disc

; Out   regs preserved

NameDiscEntry
        NewSwiEntry "r0-r6,fscb"

        ; Check new disc name is OK
        MOV     r3, r2
        B       %FT07
05
        BL      IsBad
        BEQ     %FT95
07
        LDRB    r0, [r3], #1
        TEQ     r0, #0
        BNE     %BT05

        ; Check name isn't too short or long
        ; Length allowed: 2 to 10
        SUB     r14, r3, r2
        CMP     r14, #10+1
        RSBLSS  r14, r14, #2+1
        BHI     %FT95

        ; Find the destination
        MOV     r2, #0
        addr    r3, anull
        MOV     r5, #TopPath_WantPartition
        BL      TopPath_DoBusinessForDirectoryRead
        SwiExit VS
        LDR     r0, [fscb, #fscb_info]
        TST     r0, #&ff
        BEQ     %FT10
        TST     r0, #fsinfo_multifsextensions
        BNE     %FT10
        addr    r0, ErrorBlock_UnsupportedFSEntry
        BL      CopyError
        B       %FT90

10
        LDR     r2, [fp, #2*4]          ; new disc name
        MOV     r0, #fsfunc_NameDisc

 [ debugmultifs
        DSTRING r1, "Calling namedisc from ",cc
        DSTRING r2, " to ",cc
        DREG    r1, " r1=",cc
        DREG    r2, " r2=",cc
 ]
        ; Save regs as some filing systems (DOSFS) trash them!!
        Push    "r1,r2,r6,fscb"
        BL      CallFSFunc_Given
        Pull    "r1,r2,r6,fscb"
 [ debugmultifs
        DLINE   "return from namedisc ",cc
        DREG    r1, " r1=",cc
        DREG    r2, " r2=",cc
 ]
        BVS     %FT90

20
        ; Now check if we've just renamed the root object MultiFS-style in which
        ; case we want to inform the 'parent' filing system too.
        ; Whilst we doing these sort of checks sort out FileSwitch's internals too.
        LDRB    lr, [fscb, #fscb_info]
        TEQ     lr, #0
        BLNE    NameDiscSortOutCarnage
        BNE     %FT90

        ; Reject if path tail is non-nul
        LDRB    lr, [r1]
        TEQ     lr, #0
        BNE     %FT90

        Push    "r1,r6,fscb"

 [ debugmultifs
        DLINE   "Considering informing parent"
 ]

        ; ToParent
        LDR     r1, [r6, #:INDEX:scb_path]
        LDR     fscb, [r6, #:INDEX:scb_fscb]
        LDR     r6, [r6, #:INDEX:scb_special]

        ; reject if parent is a MultiFS or an ordinary FS which can't handle MultiFS stuff
        LDR     lr, [fscb, #fscb_info]
        TST     lr, #&ff
        TSTNE   lr, #fsinfo_multifsextensions
        BEQ     %FT80

        ; reject if parent path doesn't end in "$"
        BL      strlen
        SUB     r3, r3, #1
        LDRB    lr, [r1, r3]
        TEQ     lr, #"$"
        BNE     %FT80

        ; OK, parent is a MultiFS-handling ordinary filing system and the
        ; path ended in $, so lets tell the parent about the rename.

        ; Make a copy of the path which will get freed in NameDiscSortOutCarnage
        ADD     r3, r3, #1 + 1 + 3      ; 1 for the SUB above, 1 for \0 and 3 for round-up
        BIC     r3, r3, #3
        SUB     sp, sp, r3
        MOV     r0, r2
        MOV     r2, r1
        MOV     r1, sp
        BL      strcpy
        MOV     r2, r0

        BL      NameDiscSortOutCarnage

 [ debugmultifs
        DSTRING r1, "Informing parent of namedisc from ",cc
        DSTRING r2, " to "
 ]
        MOV     r0, #fsfunc_NameDisc
        Push    "r3"
        BL      CallFSFunc_Given
        Pull    "r3"

        ADD     sp, sp, r3

80
        Pull    "r1,r6,fscb"


90
        BL      JunkFileStrings
        SwiExit

95
        MOV     r1, r2
        addr    r0, MagicErrorBlock_BadDiscName
        BL      MagicCopyError
        SwiExit

; NameDiscSortOutCarnage
; ======================
;
; In
; r1 = path tail on non-MultiFS where namedisc worked
; r2 = new disc name
; r6 = special
; fscb set
;
; Out
;
NameDiscSortOutCarnage Entry "r1,r2,r3,r4,r5"

 [ debugmultifs
        DSTRING r1, "NameDiscSortOutCarnage from ",cc
        DSTRING r2, " to "
 ]

        ; Construct new name on stack
        MOV     r1, r2
        BL      strlen
        ADD     r3, r3, #4+3    ; 4 for : prefix and .$\0 postfile
        BIC     r3, r3, #3
        SUB     sp, sp, r3

        MOV     r1, sp
        MOV     lr, #":"
        STRB    lr, [r1], #1
        BL      strcpy_advance
        MOV     lr, #"."
        STRB    lr, [r1], #1
        MOV     lr, #"$"
        STRB    lr, [r1], #1
        MOV     lr, #0
        STRB    lr, [r1], #1


        ; Terminate the source after the .$
        LDR     r1, [sp, r3]
        MOV     r4, r1
10
        LDRB    lr, [r4], #1
        TEQ     lr, #0
        MOVEQ   r4, #0
        BEQ     %FT20
        TEQ     lr, #"$"
        BNE     %BT10

        LDRB    r5, [r4]
        MOV     lr, #0
        STRB    lr, [r4]
20

        MOV     r2, sp
 [ debugmultifs
        DSTRING r1, "SortOutRenameCarnage on ",cc
        DSTRING r2, " to ",cc
        DREG    r1, " r1=",cc
        DREG    r2, " r2="
        DREG    r4, " r4=",cc
        DREG    r5, " r5="
 ]
        BL      SortOutRenameCarnage
 [ debugmultifs
        DSTRING r1, "return from SortOutRenameCarnage on ",cc
        DSTRING r2, " to ",cc
        DREG    r1, " r1=",cc
        DREG    r2, " r2="
        DREG    r4, " r4=",cc
        DREG    r5, " r5="
 ]

        ; Restore the rest of the path tail to the source
        TEQ     r4, #0
        STRNEB  r5, [r4]

        ADD     sp, sp, r3
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadBootOptionEntry. Top level FSControl entry
; ===================

; In    r1 = path for boot option

; Out   regs preserved, except
;       r2 = boot option

ReadBootOptionEntry
        NewSwiEntry     "r0,r1,r3-r6,fscb"
        BL      faff_boot_option_startup
        BVS     %FT95
        BL      int_ReadBootOptionGiven
        BL      JunkFileStrings
95
        SwiExit

; =======================
; int_ReadBootOptionGiven
; =======================

; In    r0 <> 0 means FS which understands fsfunc_ReadBootOption
;       r1 = path tail
;       r6 = special
;       fscb

; Out   regs preserved, except
;       r2 = boot option

int_ReadBootOptionGiven Entry   "r0,r1,r3-r5"           ; Don't trust the lower layers AT ALL

        TEQ     r0, #0
        BEQ     %FT50

 [ debugcontrol
        DSTRING r1, "Read boot option new style using tail "
 ]

        ; Fs understands sensible FSControls
        MOV     r0, #fsfunc_ReadBootOption
        BL      CallFSFunc_Given
        B       %FT90

50
 [ debugcontrol
        DLINE   "Reading boot option old style"
 ]
        ; Fs old style brain damaged

        ; Carve stack chunk for name and boot option of disc
        SUB     sp, sp, #64             ; should be enough

        MOV     r0, #fsfunc_ReadDiscName
        MOV     r2, sp
        BL      CallFSFunc_Given
        LDRVCB  r2, [sp, #0]
        ADDVC   r2, r2, #1
        LDRVCB  r2, [sp, r2]
        MOVVS   r2, #0

        ; Discard any error
        MOV     lr, #0
        STR     lr, globalerror
        CLRV

        ADD     sp, sp, #64

90
 [ debugcontrol
        DREG    r2, "Boot option is "
 ]
        STRVS   r0, [sp]        ; SBP: 02-Mar-95 pass back error ptr to avoid mess
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; WriteBootOptionEntry. Top level FSControl entry
; ====================

; In    r1 = path for boot option
;       r2 = boot option

; Out   regs preserved

WriteBootOptionEntry
        NewSwiEntry     "r0-r6,fscb"
        BL      faff_boot_option_startup
        BVS     %FT95

        LDR     r2, [fp, #2*4]
        TEQ     r0, #0
        BEQ     %FT50

        ; Fs understands sensible FSControls
        MOV     r0, #fsfunc_WriteBootOption
        B       %FT90

50
        ; Fs old style brain damaged
        ; Use *OPT 4,n to set boot option
        MOV     r0, #fsfunc_Opt
        MOV     r1, #4
90
        BL      CallFSFunc_Given
        BL      JunkFileStrings
95
        SwiExit

; ========================
; faff_boot_option_startup
; ========================

; In    r1 = path for boot option

; Out   r0 <> 0 for good FSs and =0 for bad FSs
;       r1 = path to send to FS
;       r6 = special
;       fscb

faff_boot_option_startup
        Entry   "r2-r5"

        ; Standard PathMunge sequence
        MOV     r2, #0
        addr    r3, anull
        MOV     r5, #TopPath_WantPartition
        BL      TopPath_DoBusinessForDirectoryRead
        EXIT    VS

        BL      faff_boot_option_startup_given

        BLVS    JunkFileStrings

        EXIT

; ==============================
; faff_boot_option_startup_given
; ==============================

; In    r1 = path tail for directory
;       r6 = special
;       fscb

; Out   r0 <> 0 for good FSs and =0 for bad FSs

faff_boot_option_startup_given Entry "r2,r3"

        ; Check if FS supports the entry
        LDR     r0, [fscb, #fscb_info]
        TST     r0, #&ff
        MOVEQ   r0, #1          ; not bad old FS
        BEQ     %FT90
        TST     r0, #fsinfo_multifsextensions
        BNE     %FT90

        ; Duff old FS

 [ debugcontrol
        DLINE   "Duff old FS"
 ]

        ; Truncate after the absolute
        ; The path *will* contain an absolute
        MOV     r2, r1
10
        LDRB    r0, [r2], #1
        BL      IsAbsolute
        BNE     %BT10
        MOV     r0, #0
        LDRB    r3, [r2]
        STRB    r0, [r2]

 [ debugcontrol
        DSTRING r1, "Setting dir to "
 ]
        ; Now set the directory to that
        MOV     r0, #fsfunc_Dir
        Push    "r0-r5"
        BL      CallFSFunc_Given
        Pull    "r0-r5"
        STRB    r3, [r2]

        ; Ignore any error - it probably doesn't matter
        MOV     r3, #0
        STR     r3, globalerror
        CLRV

        ; Duff FS indicator, and the opt interfaces allow no context
        MOV     r0, #0

90
 [ debugcontrol
        DLINE   "Finished initial faff"
 ]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SetDirEntry Top level FSControl entry
; ===========
; On entry
;  r0 = 53
;  r1 = pointer to rest of path
;  r2 = which directory to set
;  r3 = filing system
;  r6 = pointer to special field

; On exit
;  registers preserved


SetDirEntry
        NewSwiEntry     "r0-r6,fscb"

        ; Sanity check the directory specified
        TEQ     r2, #Dir_Current
        TEQNE   r2, #Dir_Previous
        TEQNE   r2, #Dir_UserRoot
        TEQNE   r2, #Dir_Library
        addr    r0, ErrorBlock_BadSetDirDir, NE
        BLNE    CopyError
        BVS     %FT95

        ; Check the filing system name
        MOV     r0, #1
        MOV     r1, r3
        BL      LookupFSName
        BVS     %FT95
        TEQ     fscb, #Nowt
        LDREQ   r1, [fp, #3*4]
        BLEQ    SetMagicFSDoesntExist
        BVS     %FT95

        LDR     r1, [fp, #1*4]
        TEQ     r1, #0
        BEQ     %FT80
        BL      SetDirFromObject
        B       %FT95
80
        BL      int_UnsetDir

95
        SwiExit


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadDirEntry Top level FSControl entry
; ============
; On entry
;  r0 = 54
;  r1 = pointer to buffer
;  r2 = which directory to read
;  r3 = filing system
;  r5 = size of buffer
;
;On exit
;  r1 = 0 if directory unset, else points to start of rest of path if managed
;        to be placed into buffer.
;  r5 reduced by length total size of directory string including terminator
;  r6 = pointer to special field or 0 if not present


ReadDirEntry
        NewSwiEntry     "r0-r6,fscb"

        ; Sanity check the directory specified
        TEQ     r2, #Dir_Current
        TEQNE   r2, #Dir_Previous
        TEQNE   r2, #Dir_UserRoot
        TEQNE   r2, #Dir_Library
        addr    r0, ErrorBlock_BadSetDirDir, NE
        BLNE    CopyError
        BVS     %FT95

        ; Check the filing system name
        MOV     r0, #1
        MOV     r1, r3
        BL      LookupFSName
        BVS     %FT95
        TEQ     fscb, #Nowt
        LDREQ   r1, [fp, #3*4]
        BLEQ    SetMagicFSDoesntExist
        BVS     %FT95

        LDR     r1, [fp, #1*4]
        BL      SimpleReadDir
        BVS     %FT95

        STR     r5, [fp, #5*4]

        CMP     r5, #0
        BLT     %FT95

        TEQ     r1, #0
        BEQ     %FT80

        LDRB    lr, [r1]
        TEQ     lr, #"#"
        MOVNE   r6, #0
        BNE     %FT70

        ADD     r6, r1, #1
20
        LDRB    lr, [r1, #1]!
        TEQ     lr, #":"
        TEQNE   lr, #0
        BNE     %BT20

        TEQ     lr, #0
        MOVNE   lr, #0
        STRNEB  lr, [r1], #1

70
        STR     r6, [fp, #6*4]

80
        STR     r1, [fp, #1*4]

95
        SwiExit

        END
