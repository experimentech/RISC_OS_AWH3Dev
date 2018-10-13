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
; >FileCore60

; 28 May 1997: SBP: Changed for idlen>15

        TTL     "OsFun"


;Each entry in OsFun table is offset to code

        GBLA    OsFunCtr

        MACRO
        OsFunEntry  $Name
        ASSERT  fsfunc_$Name=OsFunCtr
OsFunCtr SETA   OsFunCtr+1
        B       DoOsFun$Name
        MEND


; >>>>>>>>>>
; OsFunEntry
; >>>>>>>>>>

; entry
;  R0    reason code
;  R1,R2 params

; exit as defined for OsFun

OsFunEntry
 [ DebugA :LOR: DebugXd
        DREG    r0, "OsFunEntry(r0=",cc
        DREG    r1, ",r1=",cc
        DREG    r2, ",r2=",cc
        DREG    r3, ",r3=",cc
        DREG    r4, ",r4=",cc
        DREG    r5, ",r5=",cc
        DLINE   ")"
 ]
        ; List of 'safe' fsfuncs
        TEQ     r0, #fsfunc_CanonicaliseSpecialAndDisc
        BEQ     %FT15
        TEQ     r0, #fsfunc_ReadFreeSpace
        BEQ     %FT10
        SemEntry  Flag, Dormant         ;leaves R12,LR stacked
        B       %FT20
10
        SemEntry  Flag                  ;leaves R12,LR stacked
        B       %FT20
15
        SemEntry  Flag,Light            ;leaves R12,LR stacked
20
        CMPS    R0, #FirstUnknown_fsfunc
        MOV     LR, PC
        ADDLO   PC, PC, R0,LSL #2
        B       OsFunBack
OsFunTable
        OsFunEntry      Dir                    ; Now defunct
        OsFunEntry      Lib                    ; Now defunct
        OsFunEntry      Cat                    ; Now defunct
        OsFunEntry      Ex                     ; Now defunct
        OsFunEntry      LCat                   ; Now defunct
        OsFunEntry      LEx                    ; Now defunct
        OsFunEntry      Info                   ; Now defunct
        OsFunEntry      Opt
        OsFunEntry      Rename
        OsFunEntry      Access                 ; Now defunct
        OsFunEntry      Bootup
        OsFunEntry      ReadDiscName           ; Now defunct
        OsFunEntry      ReadCSDName            ; Now defunct
        OsFunEntry      ReadLIBName            ; Now defunct
        OsFunEntry      ReadDirEntries
        OsFunEntry      ReadDirEntriesInfo
        OsFunEntry      ShutDown
        OsFunEntry      PrintBanner            ; (does nothing)
        OsFunEntry      SetContexts            ; Now defunct
        OsFunEntry      CatalogObjects
        OsFunEntry      FileInfo               ; Now defunct
        OsFunEntry      NewImage               ; not applicable
        OsFunEntry      ImageClosing           ; not applicable
        OsFunEntry      CanonicaliseSpecialAndDisc
        OsFunEntry      ResolveWildcard
        OsFunEntry      DefectList
        OsFunEntry      AddDefect
        OsFunEntry      ReadBootOption
        OsFunEntry      WriteBootOption
        OsFunEntry      UsedSpaceMap
        OsFunEntry      ReadFreeSpace
        OsFunEntry      NameDisc
        OsFunEntry      StampImage              ; not applicable
        OsFunEntry      ObjectAtOffset
        OsFunEntry      DirIs                   ; not applicable
 [ BigDisc
        OsFunEntry      ReadFreeSpace64
        OsFunEntry      DefectList64
        OsFunEntry      AddDefect64
 ]
        ASSERT          (.-OsFunTable)=FirstUnknown_fsfunc*4

DoOsFunDirIs
DoOsFunPrintBanner
DoOsFunDir
DoOsFunLib
DoOsFunCat
DoOsFunEx
DoOsFunLCat
DoOsFunLEx
DoOsFunInfo
DoOsFunAccess
DoOsFunReadDiscName
DoOsFunReadCSDName
DoOsFunReadLIBName
DoOsFunSetContexts
DoOsFunFileInfo
DoOsFunNewImage
DoOsFunImageClosing
OsFunBack
 [ DebugA
        DREG    r0, "OsFunExit(r0=",cc
        DREG    r1, ",r1=",cc
        DREG    r2, ",r2=",cc
        DREG    r3, ",r3=",cc
        DREG    r4, ",r4=",cc
        DREG    r5, ",r5=",cc
        BVC     %FT01
        DLINE   ",V Set",cc
01
        DLINE   ")"
 ]
        BLVS    FindErrBlock    ; (R0->R0,V)
        BL      FileCoreExit
        Pull    "SB,PC"

 [ {FALSE}
; SMC: no longer used
UnsetText
 =       """Unset""   ",0
 ]

LoadText
 =       "LOAD &.!BOOT",0,0,0,0
RunText
 =       "RUN &.!BOOT",0,0,0,0,0
ExecText
 =       "EXEC &.!BOOT",0
RetryText
 =       "RetryBoot",0
        ALIGN

; ===============
; PutMaskedString
; ===============

; copy string into buffer masking out b7 for old format, fill out with spaces

; entry:
;  R3 top 3 bits disc num
;  R4 -> string
;  R6 max length
;  R7 -> string buffer

; exit:
;  R7 inc by max length

PutMaskedString ROUT
        Push    "R0,R4-R6,R8,LR"
        SavePSR R8

        ; NULL string maps to "" for Root object of disc
        TEQ     R4, #0
        baddr   R4, anull, EQ

        BL      TestDir         ;which mask
        MOVEQ   R5, #&FF
        MOVNE   R5, #&7F
PutStrCommon1
        MOV     R0, #" "
PutStrCommon2
05
        LDRB    LR, [R4], #1
        AND     LR, LR, R5
        CMPS    LR, R0
        TEQHIS  LR, #DeleteChar
        STRHIB  LR, [R7],#1     ;note name char if not terminator or space
        SUBHIS  R6, R6, #1      ;check for max length
        BHI     %BT05
10                      ;pad name with spaces
        SUBS    R6, R6, #1
        BLPL    PutSpace
        BPL     %BT10
        RestPSR R8,,f
        Pull    "R0,R4-R6,R8,PC"


; =======
; PutHex2
; =======

; as PutHexWord but leading zeroes replaced by spaces

PutHex2 ROUT
        Push    "R0-R3,LR"
        MOV     R1, #0
        B       %FT05

; ==========
; PutHexWord
; ==========

; add space followed by 8 char hex string to string in buffer

; entry:
;  R0 number
;  R7 -> where to put

; exit:
;  R0 corrupt
;  R7 incremented

PutHexWord
        Push    "R0-R3,LR"
        MOV     R1, #1
05
        MOV     R2, R0
        MOV     R3, #32-4
10
        MOV     R0, R2, LSR R3
        ANDS    R0, R0, #&F
        TEQEQS  R1, #0
        ADD     R1, R1, R0
        BLEQ    PutSpace
        BLNE    PutHexChar      ;(R0,R7->R7)
        SUBS    R3, R3, #4
        MOVEQ   R1, #1
        BPL     %BT10
        Pull    "R0-R3,PC"


; ==========
; PutHexChar
; ==========

; add hex char to string in buffer

; entry:
;  R0 number
;  R7 -> where to put

; exit:
;  R7 incremented

PutHexChar ROUT
        Push    "R0,LR"
        CMPS    R0, #10
        ADDLO   R0, R0, #"0"
        ADDHS   R0, R0, #"A"-10
        STRB    R0, [R7], #1
        Pull    "R0,PC"


; ========
; PutSpace
; ========

; add space to string in buffer

; entry: R7 -> where to put

; exit:
;  R7 incremented

PutSpace
        Push    "LR"
        MOV     LR, #" "
        STRB    LR, [R7], #1
        Pull    "PC"


; ============
; ScreenFormat
; ============

; given a field width it calculates the number of such fields and by how much
; this can be increased by without decreasing number of fields

; entry: R0 field width

; exit:
;  R9   number of fields
;  R10  amount can increase width by
;  R11  as R9 (init fields left ctr)

ScreenFormat ROUT
        Push    "R0-R1,LR"               ;calculate screen width
        MOV     R0, #VduExt_WindowWidth
        MOV     R1, #-1
        Push    "R0,R1"
        MOV     R0, SP
        MOV     R1, SP
        BL      OnlyXOS_ReadVduVariables        ;(R0,R1)
        Pull    "R0,R1"
        ADD     R0, R0, #1
        LDR     R1, [SP]
        BL      Divide          ;how many fields fit ? (R0,R1->R0,R1)
        TEQS    R0, #0
        MOVEQ   R9, #1
        MOVNE   R9, R0
        MOV     R0, R1          ;redistribute spare columns
        MOV     R1, R9
        BL      Divide          ;(R0,R1->R0,R1)
        MOV     R10,R0

        MOV     R11,R9
        Pull    "R0-R1,PC"

; =========
; NextField
; =========

; count a field and write separating spaces or new line

; entry:
;  R9  fields per row
;  R10 # separating spaces
;  R11 fields left on line including this one (may be 0)

; exit:
; IF error V=1, R0 error code, R11 ?
; ELSE     V=0,              , R11 adjusted

NextField ROUT
        Push    "R0,R1,LR"
        SUBS    R11,R11,#1      ;line done ?
        BHI     %FT05
        MOV     R11,R9
        BL      DoXOS_NewLine   ;(->R0,V)
        B       %FT95
05
        MOV     R1, R10
10
        MOV     R0, #" "
        SUBS    R1, R1, #1
        BMI     %FT95
        BL      DoXOS_WriteC    ;(R0->R0,V)
        BVC     %BT10
95
        STRVS   R0, [SP]
        Pull    "R0,R1,PC"


; ===========
; WriteString
; ===========

; send a string to VDU drivers

; entry: R7->zero terminated string

; exit: IF error V=1, R0 err
;       ELSE     V=0


WriteString ROUT
        Push    "R0,R7,LR"
10
        LDRB    R0, [R7],#1
        TEQS    R0, #0
        BEQ     %FT95
        BL      DoXOS_WriteC
        BVC     %BT10
95
        STRVS   R0, [SP]
        Pull    "R0,R7,PC"

ParseDir
        Push    "LR"
        MOV     R2,#DirItself :OR: MustBeDir
        BL      FullLookUp      ;(R1,R2->R0-R6,C,V)
        Pull    "PC"


DoOsFunOpt ROUT
; R1 param 1
; R2 param 2
        TEQS    R1, #4
        MOVNE   R0, #0
        MOVNE   PC, LR
        AND     R2, R2, #3
        Push    "R3,LR"
        BL      IdentifyCurrentDisc     ;(->R0,R3,V)
        BLVC    WriteBootOption         ;(r2,r3->r0,V)
        Pull    "R3,PC"

DoOsFunRename ROUT
; R1->old pathname
; R2->new pathname
        Push    "R1-R11,LR"
        MOV     R2, #NotLastUp :OR: NotLastWild :OR: NotNulName
        BL      FullLookUp      ;(R1,R2->R0-R6,C,V)
        BLVC    LockedOrOpen    ;(R3,R4->R0,V) $ is locked and thus rejected
        BVS     %FT95

 [ BigDir
        BL      TestBigDir      ;is it a big dir?
        BNE     %FT01

        ; if it's a big dir then recover R2
        LDR     R2, [SP, #4]
        BL      DoOsFunRenameBigDir
        B       %FT91           ; and exit with whatever it returned
01
 ]

        MOV     R7, R3
        SUB     R8, R4, R5
        BL      ReadIndDiscAdd  ;(R3,R4->LR)
        MOV     R9, LR
        BL      ReadIntAtts     ;(R3,R4->LR)
        MOV     R11,LR
        BL      ReadLen         ;(R3,R4->LR)
        MOV     R10,LR
        MOV     R2, R9
        BL      ReallyShared    ;(R2-R5->Z)
        ORREQ   R11,R11,#1 :SHL: 31
        BL      IncUsage        ;(R3)

        ASSERT  NewDirEntrySz=OldDirEntrySz
        ASSERT  NewDirEntrySz-NameLen<=16
        SUB     SP, SP, #16+4   ;also space for ptr to new final component

        ADD     R0, R4, #NameLen        ;save old dir entry
        MOV     R1, SP
        ASSERT  NewDirEntrySz=OldDirEntrySz
        MOV     R2, #NewDirEntrySz-NameLen
        BL      BlockMove       ;(R0-R2)

        LDR     R1, [SP,#16+4+4] ;new name string
        AND     R2, R3, #DiscBits
        ORR     R2, R2, #MustBeRefDisc
        ORR     R2, R2, #DirToBuffer :OR: NotLastUp :OR: NotLastWild :OR: NotNulName
        BL      FullLookUp      ;(R1,R2->R0-R6,C,V)
        BVS     %FT05
        TEQS    R7, R3          ;if new obj already exists is it old obj
        SUB     LR, R4, R5
        TEQEQS  LR, R8
        BEQ     %FT07
        MOVNE   R0, #ExistsErr
05
        TEQS    R0, #NotFoundErr
        BNE     %FT85
        BL      ThisChar        ;(R1->R0,C)
        MOVCC   R0, #NotFoundErr
        BCC     %FT85           ;not terminator => not last term
07
        ; No need to explicitly ensure a new Id as this will be handled by WriteDir
        ; or writing the FSMap out.

        LDR     R0, [SP,#16+4+4];string start
        BL      TermStart       ;backtrack to start of last term (R0,R1->R1)

        STR     R1, [SP,#16]    ;final component new name
        BL      InvalidateBufDir
        ADD     R8, R8, R5      ;convert old entry offset to ptr
        TEQS    R3, R7
        BNE     %FT20           ;not in same dir

        SUBS    R2, R8, R4                ;move other entries in dir
        ASSERT  NewDirEntrySz=OldDirEntrySz
        ADDLO   R0, R8, #NewDirEntrySz
        MOVLO   R1, R8
        SUBLO   R2, R4, R0
        MOVHI   R0, R4
        ASSERT  NewDirEntrySz=OldDirEntrySz
        ADDHI   R1, R4, #NewDirEntrySz
        BLNE    BlockMove       ;(R0-R2)

        ASSERT  NewDirEntrySz=OldDirEntrySz
        SUBLO   R4, R4, #NewDirEntrySz
        BL      %FT15
        MOVVC   R1, R3
        BLVC    %FT10           ;renaming dir common code
        B       %FT90

10
; Subroutine:
;
; Job: If renaming a directory then adjust its parent information and its name

; R1  new parent dir
; R9  dir to rename, if <> 0
; R11 attributes
        Push    "R3,R4,R6,R7,LR"
        TSTS    R11,#DirBit
        BEQ     %FT14
        MOVS    R3, R9
        LDR     R4, [SP,#5*4+16] ;final component new name

        BL      GetDir          ;(R3->R0,R5,R6,V)
        BLVC    InvalidateBufDir
        MOVVC   R3, R1
        BLVC    WriteParent     ;(R3,R6)
        BL      TestDir      ;(R3->LR,Z) preserves V
        ADDEQ   R7, R6, #NewDirName
        ADDNE   R7, R6, #OldDirName
        MOV     R6, #NameLen
        BLVC    PutMaskedString ;(R3,R4,R6,R7->R7)
        BLVC    WriteDir        ;(->R0,V)
        BVS     %FT14

14
        Pull    "R3,R4,R6,R7,PC"


15
; Subroutine:
;
; Job: Fill in and write out new parent dir
;
        Push    "R1,LR"
        LDR     R1, [SP,#2*4+16]  ;new name final component
        BL      WriteName       ;(R1,R4)
        ADD     R0, SP, #8      ;move copy of old dir entry back into new place
        ADD     R1, R4, #NameLen
        ASSERT  NewDirEntrySz=OldDirEntrySz
        MOV     R2, #NewDirEntrySz-NameLen
        BL      BlockMove       ;(R0-R2)
        AND     R0, R11,#IntAttMask
        BL      SetIntAtts      ;(R0,R3,R4) only needed for old format
        BL      IncObjSeqNum    ;(R3-R5)
        BL      WriteDir        ;(->R0,V)
        Pull    "R1,PC"

20
; If we reach here we're renaming to a different directory
;

 [ DebugA
        mess    ,"Rename across dirs",NL
 ]
        BL      IsDirFull      ;(R3,R5,R6->R0,V)
        BVS     %FT90
        TSTS    R11,#DirBit
        BEQ     %FT35

; If we're here then we're renaming a directory into a different directory
;
; Check not doing a duff rename

        MOV     R1, R3         ;if renaming dir walk up new path pathname
25
        BL      DiscAddToRec   ;(R3->LR)
        LDR     R0, [LR,#DiscRecord_Root]
        TEQS    R3, R0          ;if meet root dir
        TEQNES  R3, R7          ;or old parent dir
        BEQ     %FT30           ;then ok
        TEQS    R3, R9          ;but if meet dir to rename
        MOVEQ   R0, #BadRenameErr;then moan
        BEQ     %FT85
        BL      ToParent        ;(R3,R6->R3)
        BL      FindDir         ;(R3->R0,R5,R6,V)
        BVS     %FT90
        B       %BT25
30
        MOV     R3, R1          ;retreive new parent dir
        BL      GetDir          ;(R3->R0,R5,R6,V)
        BVS     %FT90
35
; If we're here then we're renaming something into a different directory
; and its safe to do so (ie duff directory renames have been checked for)
;
        BL      MakeDirSpace    ;(R3-R6)
        TSTS    R11,#1 :SHL: 31
        BEQ     %FT40

; If we're here then object being renamed is shared with something else. This
; means we've got to claim new space in the destination directory for it and copy
; the renamee across.

        BL      BeforeAlterFsMap
        BVS     %FT90
        Push    "R3,R4,R11"
        MOV     R11,#fsfile_Create
        BL      ClaimFreeSpace  ;(R3-R6,R10,R11->R0,R2,V)
        MOV     R6, R2

        MOVVC   R1, R9
        MOVVC   R3, R10
        BLVC    DefaultMoveData ;(R1-R3->R0-R4,V)
        Pull    "R3,R4,R11"

        LDRVC   R1, [SP,#16]            ;new name final component
        BLVC    WriteName               ;(R1,R4)
        MOVVC   R0, SP                  ;move copy of old dir entry back into new place
        ADDVC   R1, R4, #NameLen
        ASSERT  NewDirEntrySz=OldDirEntrySz
        MOVVC   R2, #NewDirEntrySz-NameLen
        BLVC    BlockMove               ;(R0-R2)
        MOVVC   R0, R6                          ;adjust ind disc add to new value
        BLVC    WriteIndDiscAdd ;(R0,R3,R4)

        BLVC    WriteFsMapThenDir       ;(->R0,V)
        BL      UnlockMap
        B       %FT45

40
        BL      %BT15
45
; Renaming object between directories and its already been placed in the
; destination.

        MOVVC   R3, R7          ;old parent dir
        BLVC    GetDir          ;(R3->R0,R5,R6,V)
        MOVVC   R4, R8
        BLVC    RemoveDirEntryOnly      ;(R3-R6->R0,V) always succeeds
        BLVC    WriteDir        ;(->R0,V)
        BLVC    %BT10
        B       %FT90
85
        BL      SetVOnR0
90
        ADD     SP, SP, #16+4   ;return dir entry buffer
 [ BigDir
91
 ]
        MOVVC   R0, #0
        STRVC   R0, [SP,#0]     ;zero return R1 to indicate success
        MOV     R3, R7
        BL      DecUsage        ;(R3)
95
        Pull    "R1-R11,PC"


        GBLL    ReadBootOptFromFileSwitch
ReadBootOptFromFileSwitch SETL {TRUE}

 [ ReadBootOptFromFileSwitch
dollar  =       "$", 0 ; we can only boot from the current drive on the current filing system, so there's no point constructing a more elaborate path
        ALIGN
 ]

DoOsFunBootup ROUT
        Push    "R1-R7"
      [ ReadBootOptFromFileSwitch
        BL      FileCoreExit            ; not peeking internal FileCore workspace any more, so no need for interlock
      ]
        MOV     R7,#0
85
        SWI     XOS_ReadEscapeState
        BCS     %FT90
        
      [ ReadBootOptFromFileSwitch
        MOV     R0, #FSControl_ReadBootOption
        ADR     R1, dollar
        SWI     XOS_FSControl
        BVS     %FT96
        ANDS    R0, R2, #3
      |
        BL      IdentifyCurrentDisc
        BVS     %FT96
        BL      DiscAddToRec            ;(R3->LR)
        LDRB    R0, [LR,#DiscRecord_BootOpt]
        ANDS    R0, R0, #3
        BLEQ    FileCoreExit            ;if boot option 0 just return
      ]
        Pull    "R1-R7,SB,PC",EQ
        baddr   R1, (LoadText-16)
        ASSERT  RunText-LoadText=16*(2-1)
        ASSERT  ExecText-LoadText=16*(3-1)
        ADD     R0, R1, R0, LSL #4
      [ :LNOT: ReadBootOptFromFileSwitch
        BL      FileCoreExit
      ]
        SWI     XOS_CLI
        Pull    "R1-R7,SB,PC"

90
        MOV     R0,#OsByte_AcknowledgeEscape
        SWI     XOS_Byte        ; ack the escape
        MOV     R0, #IntEscapeErr

95
        BL      FindErrBlock    ; (R0->R0,V)
      [ :LNOT: ReadBootOptFromFileSwitch
        BL      FileCoreExit
      ]
        Pull    "R1-R7,SB,PC"

96
        ; If SCSIFS returns a 'drive empty' error, it might be that we're
        ; attempting to boot from something like a USB device which hasn't
        ; fully woken up yet.
        ; So under the assumption that the user knew what he was doing when
        ; he said to boot from this drive, print out a warning message and
        ; retry indefinitely.
        ; TODO - This should probably be made into a standard check which
        ; other filesystems can opt-in on too.
        CMP     R0,#256
        BLS     %BT95 ; Not an error block; must still be an internal error number (in which case it's highly unlikely to be the error we're interested in)
        LDR     R1,[R0]
        LDR     R2,=&11AD3 ; SCSIFS drive empty error
        TEQ     R1,R2
        BNE     %BT95
        CMP     R7,#0 ; Only print the warning once
        MOVEQ   R7,#1
        ADREQL  R0,RetryText
        BLEQ    message_gswrite0
      [ :LNOT: ReadBootOptFromFileSwitch
        BLVS    FileCoreExit
      ]
        Pull    "R1-R7,SB,PC",VS
        ; Trigger callbacks otherwise the USB/SCSI system won't accept any new devices
        SWI     XOS_LeaveOS
        SWI     XOS_EnterOS
        B       %BT85

;Read dir entries

;Entry
; R1 -> dir name
; R2 -> buffer
; R3    # names
; R4    start index in dir (from 0)
; R5    buffer length

Exit
; R3    number of names read
; R4    index of first name not read, -1 if exhausted

DoOsFunReadDirEntries ROUT
DoOsFunReadDirEntriesInfo
DoOsFunCatalogObjects
        Push    "R0-R11,LR"
        BL      SkipSpaces      ;(R1->R0,R1,C)
        baddr   R1, CsdText,CS  ;if no param use CSD
        Pull    "R11"
        LDMIB   SP, {R7-R10}    ;move R2-R5 to R7-R10
        ADD     R10,R7, R10

; R1  dir string
; R7  buffer ptr
; R8  number of names to transfer
; R9  start number in dir
; R10 buffer end
; R11 fsfunc reason code

        MOV     R2, #DirItself :OR: MustBeDir
        BL      FullLookUp      ;(R1,R2->R0-R6,C,V)

 [ BigDir
        BL      TestBigDir
        BNE     %FT01

        BVS     %FT95           ; result of FullLookup

        BL      ReadBigDirEntries
        B       %FT90
01
 ]

        BL      TestDir      ;preserves V
        ASSERT  NewDirEntrySz=OldDirEntrySz
        SUB     R4, R5, #NewDirEntrySz-DirFirstEntry
        MOV     R5, #0                  ;names transferred
        BVS     %FT95                   ;result of FullLookUp

        MOV     LR, #0
05
        ASSERT  NewDirEntrySz=OldDirEntrySz
        LDRB    R0, [R4,#NewDirEntrySz] !
        TEQS    R0, #0
        MOVEQ   R9, #-1
        BEQ     %FT90                   ;names exhausted before transfer starts
        CMPS    LR, R9
        ADDLO   LR, LR, #1
        BLO     %BT05                   ;loop if not reached start name

10                                      ;main loop
        TEQS    R11,#fsfunc_ReadDirEntries
        BEQ     %FT15
        ANDS    LR, R7, #3      ;word align buffer ptr
        BICNE   R7, R7, #3
        ADDNE   R7, R7, #4
        SUB     LR, R10,R7
        TEQS    R11,#fsfunc_CatalogObjects
        MOV     R0, #5*4+2
        ADDEQ   R0, R0, #4+5
        CMPS    LR, R0          ;room left for 5 words and name ?
        BLT     %FT90           ;done if not
        BL      ReadIntAtts     ;(R3,R4->LR)
        TSTS    LR, #DirBit
        MOVEQ   R0, #1
        MOVNE   R0, #2
        BL      ReadLoad        ;(R3,R4->LR)
        STR     LR, [R7],#4
        CMNS    LR, #1 :SHL: 20 ;C=1 <=> stamped
        ANDCS   R1, LR, #&FF
        MOVCC   R1, #0
        BL      ReadExec        ;(R4->LR)
        MOVCS   R2, LR
        MOVCC   R2, #0
        STR     LR, [R7],#4
        BL      ReadLen         ;(R3,R4->LR)
        STR     LR, [R7],#4
        BL      ReadExtAtts     ;(R3,R4->LR)
        STR     LR, [R7],#4
        STR     R0, [R7],#4     ;atts
        TEQS    R11,#fsfunc_CatalogObjects
        BLEQ    ReadIndDiscAdd  ;(R3,R4->LR)
        BICEQ   LR, LR, #DiscBits
        STREQ   LR, [R7], #4
        STREQ   R2, [R7], #4
        STREQB  R1, [R7], #1

15
        ASSERT  DirObName=0
        MOV     R6, #NameLen
        BL      PutStringToBuf  ;(R3,R4,R6,R7,R10->R7,C)
        BLCC    Put0ToBuf

        ADDCC   R5, R5, #1
        ADDCC   R9, R9, #1
        CMPCCS  R5, R8
        MOVCC   LR, R9
        BCC     %BT05
90
        MOV     R0, #0
        BL      ClearV
95
        STR     R5, [SP,#(3-1)*4]       ;R3 exit = names transferred
        STR     R9, [SP,#(4-1)*4]       ;R4 exit = next name index
        Pull    "R1-R11,PC"

DoOsFunShutDown
        Push    "R0-R4,LR"

        ; Accumulate the last error into r4
        MOV     r4, #0

        ; WhatDisc all the Winnies so we know where to park them
        LDRB    r1, Winnies
        B       %FT10
05
        BL      WhatDisc        ;(r1->r0-r3,V) so know where to park winnies
 [ {FALSE}
        MOVVS   r4, r0          ;ONLY REPORT LAST ERROR AT PRESENT
 |
        BVC     %FT10
        TEQ     r0, #DriveEmptyErr
        MOVNE   r4, r0
 ]
10
        SUBS    r1, r1, #1
        BPL     %BT05

        ; Dismount each used disc
        MOV     r1, #7
20
        DiscRecPtr lr, r1
        LDRB    lr, [lr, #Priority]
        TEQ     lr, #0
        BLNE    ActiveDismountDisc
        SUBS    r1, r1, #1
        BPL     %BT20

        ; Make sure all the drive contents are now unknown
        MOV     R0, #7
30
        BL      DriveContentsUnknown
        SUBS    R0, R0, #1
        BPL     %BT30

; OSS Power eject all drives that support it

        MOV     r0, #MiscOp_Eject
        MOV     r1, #7
40
        BL      DoSwiMiscOp_Eject
        SUBS    r1, r1, #1
        BPL     %BT40

        MOV     R0, R4
        BL      SetVOnR0
        STRVS   R0, [SP]
        Pull    "R0-R4,PC"


; ==============
; PutStringToBuf
; ==============

; entry
;  R3  top 3 bits = disc
;  R4  -> string
;  R6  max string length
;  R7  -> buffer
;  R10 -> buffer end

; exit
;  R7 incremented by length copied, C=1 <=> buffer too small

PutStringToBuf ROUT
        Push    "R0,R1,R4,R6,LR"
        BL      TestDir
        MOVEQ   R1, #&FF        ;char mask
        MOVNE   R1, #&7F
        RSB     R6, R6, #0
10
        CMPS    R7, R10
        BCS     %FT95

        LDRB    R0, [R4],#1
        AND     R0, R0, R1
        CMPS    R0, #DeleteChar
        RSBNES  LR, R0, #" "

        STRCCB  R0, [R7],#1
        ADDCCS  R6, R6, #1
        BCC     %BT10
        MOVS    R0, #0,2         ;C=0
95
        Pull    "R0,R1,R4,R6,PC"

; =========
; Put0ToBuf
; =========

Put0ToBuf
        MOV     R0,#0   ;fall through to PutByteToBuf

; ============
; PutByteToBuf
; ============

; entry
;  R0  byte
;  R7  -> buffer
;  R10 -> buffer end

; exit
;  R7 incremented by length copied, C=1 <=> buffer too small

PutByteToBuf ROUT
        CMPS    R7,R10
        STRCCB  R0,[R7],#1
        MOV     PC,LR


; =================================
; DoOsFunCanonicaliseSpecialAndDisc
; =================================

; entry
;  r1 -> special field (or 0)
;  r2 -> disc name (or 0)
;  r3 -> special field buffer (or 0)
;  r4 -> disc name buffer (or 0)
;  r5 = special field buffer size
;  r6 = disc name buffer size

; exit
;  Error, or:
;  r1 = 0 (to indicate no special field)
;  r2 -> disc name buffer (or 0)
;  r3 = 0 (no special field overflow)
;  r4 = disc name length or overflow (if r4in = 0)
;  r5 preserved
;  r6 preserved

DoOsFunCanonicaliseSpecialAndDisc ROUT
        Push    "r0-r11,lr"

        ; Stack to construct <n>\0 for found, unnamed discs
        SUB     sp, sp, #4      ; for "<n>\0"

        ; Get from disc name to DiscRecPtr in r5
        MOVS    r1, r2
        BNE     %FT10

        BL      IdentifyDiscInCurrentDrive
        B       %FT50

10
        ; Disc name specified
        MOV     r2, #0
        BL      ParseDrive
        BVC     %FT40           ; 1-char valid drive
        BEQ     %FT99           ; 1-char invalid drive - barf

20
        ; Disc name - check for wildcards
        MOV     lr, #0
30
        LDRB    r0, [r1, lr]
        CMP     r0, #"#"
        CMPNE   r0, #"*"
        BEQ     %FT40
        CMP     r0, #0
        ADDNE   lr, lr, #1
        BNE     %BT30

        ; No wildcards in disc name
        MOV     lr, #&ff
        STRB    lr, PreferredDisc

        BL      ThisChar
        B       %FT60

40
        ; No preferred disc - we're starting afresh
        MOV     lr, #&ff
        STRB    lr, PreferredDisc

        BL      FindDiscByName          ;(R1,R2->R0-R3,V)
50
        BVS     %FT99

        ; Set the preferred disc to the one found
        MOV     lr, r3, LSR #(32-3)
        STRB    lr, PreferredDisc

        ; Convert to DiscRecordP in r5
        BL      DiscAddToRec            ;(R3->LR)
        MOV     R5, LR

        ; Convert that to DiscNameP in r1
        ADD     r1, r5, #DiscRecord_DiscName
        BL      ThisChar
        BCC     %FT60

        ; Convert unnamed discs into <n>\0
        MOV     r0, #0
        STRB    r0, [sp, #1]
        LDRB    r0, [r5, #DiscsDrv]
        EOR     r0, r0, #4              ; Convert to external numbering
        ADD     r0, r0, #"0"
        STRB    r0, [sp]
        MOV     r1, sp
60
        ; Copy the disc name into the destination buffer
        LDR     r4, [sp, #4+4*4]        ; r4 in (buffer start)
        LDR     r6, [sp, #4+6*4]        ; r6 in (buffer size)
        TEQ     r4, #0
        MOVEQ   r6, #0
        MOV     r7, #?DiscRecord_DiscName

70
        SUBS    r6, r6, #1
        STRPLB  r0, [r4], #1
        SUBS    r7, r7, #1
        BEQ     %FT80
        BLCS    NextChar
        BCC     %BT70

80
        MOV     r0, #0
        SUBS    r6, r6, #1
        STRPLB  r0, [r4], #1

        ; Convert negative mount of buffer left to an overflow
        CMP     r6, #0
        RSBLT   r6, r6, #0
        SUBHI   r6, r6, #1

        ; Set up return values
        MOV     r1, #0
        STR     r1, [sp, #4+1*4]
        STR     r1, [sp, #4+3*4]
        LDR     r1, [sp, #4+4*4]
        STR     r1, [sp, #4+2*4]
        STR     r6, [sp, #4+4*4]

        ; return
99
        STRVS   r0, [sp, #4+0*4]
        ADD     sp, sp, #4
        Pull    "r0-r11,pc"

; ======================
; DoOsFunResolveWildcard
; ======================

; In
;  r1 -> directory
;  r2 -> Result buffer address, or 0
;  r3 -> wildcarded object name
;  r5 = size of result block
;  r6 -> special field (is 0 for FileCore)
; Out
;  r1 unchanged
;  r2 = -1 for not found, or preserved
;  r3 unchanged
;  r4 = overflow if OK, or -1 for FileSwitch to do the business
;  r5 unchanged
;  r6 unchanged

DoOsFunResolveWildcard ROUT
        Push    "r0-r11,lr"
 [ DebugMt
        DSTRING r3, "Looking up ",cc
        DSTRING r1, " in "
 ]

        MOV     r2, #NotNulName :OR: MustBeDir :OR: DirItself
        BL      FullLookUp
        BVC     %FT30

        ; Error looking up directory - check whether it was not found, or something worse
        CMP     r0, #NotFoundErr                ; Lose the V bit here
        BEQ     %FT40

        SETV
        B       %FT90

30
        ; Directory found - hunt the entry
        LDR     r1, [sp, #3*4]
        MOV     r2, #0
 [ BigDir
        BL      GetDirFirstEntry ;(R3,R5->R4)
        BL      TestBigDir
        BNE     %FT35

; big dir
        CLC
        BL      LookUpBigDir  ; (r1-r4->r4,Z,C)
        BCC     %FT50
        B       %FT40

35      ; not a big dir
 |
        ADD     r4, r5, #DirFirstEntry
 ]
        CLC
        BL      LookUp  ; (r1-r4->r4,Z,C)
        BCC     %FT50

40
        ; Entry not found
        MOV     r2, #-1
        STR     r2, [sp, #2*4]
        B       %FT90

50
        ; Entry found - copy it
        ADD     r4, r4, #DirObName
 [ DebugMt
        DSTRING r4, "Entry found of value "
 ]
        ; Get mask
 [ BigDir
        BL      TestBigDir              ; (R3->Z)
        BNE     %FT01

        BL      GetBigDirName           ; (R4, R4->LR)
        LDR     R3, [R4, #BigDirObNameLen]
        SUB     R3, R3, #1
        MOV     R5, #&FF
        MOV     R4, LR                  ; R4->name
        B       %FT02
01
        BL      TestDir                 ; (R3->Z)
        MOVEQ   R5, #&FF
        MOVNE   R5, #&7F                ;old format dirs cant have bit 7 set chars
        MOV     r3, #NameLen - 1
02
 |
        BL      TestDir
        MOVEQ   R5, #&FF
        MOVNE   R5, #&7F                ;old format dirs cant have bit 7 set chars
        MOV     r3, #NameLen - 1
 ]

60
        LDRB    r0, [r4, r3]
        TEQ     r0, #DeleteChar
        RSBNES  r0, r0, #" "
        SUBHSS  r3, r3, #1
        BHS     %BT60
        ADD     r3, r3, #1

        ; Was a buffer specified?
        LDR     r1, [sp, #2*4]
        TEQ     r1, #0
        MOVEQ   r2, #0
        LDRNE   r2, [sp, #5*4]
        CMP     r2, r3
        BHI     %FT70

        ; Buffer too small - return the overflow
        ADD     r3, r3, #1
        SUB     r3, r3, r2
        STR     r3, [sp, #4*4]
        B       %FT90

70
        ; Buffer present and big enough
        MOV     r0, #0
        STRB    r0, [r1, r3]
80
        SUBS    r3, r3, #1
        LDRPLB  r0, [r4, r3]
        AND     r0, r0, r5
        STRPLB  r0, [r1, r3]
        BPL     %BT80

        MOV     r2, #0
        STR     r2, [sp, #4*4]

90
        STRVS   r0, [sp]
        Pull    "r0-r11,pc"

; =================
; DoOsFunDefectList
; =================

; In
;  r1 -> root object of disc
;  r2 -> Result buffer address
;  r5 = size of result buffer
;  r6 -> special field (is 0 for FileCore)
; Out
;  r0 unchanged or error
;  r1-r6 unchanged
DoOsFunDefectList ROUT
        Push    "r0-r11,lr"
        BL      DiscForPath             ; (r1)->(r0,r3,V)
        BLVC    BeforeReadFsMap         ; (r3)->(r0,V) and disc must be FileCore too
        BVS     %FT95

        ; Got the disc identified and its map locked in

        ; Sort out whether it has an explicit defect list
        BL      DiscAddToRec            ; (r3->lr)
        MOV     r5, lr
        LDRB    r1, [r5, #DiscsDrv]
        DrvRecPtr r4, r1
        LDR     r2, [sp, #2*4]          ; supplied buffer
        LDR     r6, [sp, #5*4]          ; buffer's size
        LDRB    lr, [r4, #DrvFlags]
        TST     lr, #HasDefectList
        BEQ     %FT20

 [ DebugQ
        DLINE   "Drive has a defect list"
 ]

        ; Disc has a real defect list - copy it
        LDR     r3, DefectSpace
        ADD     r3, r3, SB
        ASSERT  SzDefectList = (1 :SHL: 9)
        ADD     r3, r3, r1, ASL #9

10
        SUBS    r6, r6, #4
        BLO     %FT70                   ; buffer overflow
        LDR     lr, [r3], #4
        TST     lr, #DiscBits
        STREQ   lr, [r2], #4
        BEQ     %BT10

        B       %FT25

20
 [ DebugQ
        DLINE   "No explicit defect list"
 ]
        ; Disc has no defect list
        BL      TestMap                 ;(R3->Z)
        BEQ     %FT30

 [ DebugQ
        DLINE   "Old map"
 ]

        ; Generate an old map defect list without any defects
        SUBS    r6, r6, #4
        BLO     %FT70                   ; buffer overflow
 [ DebugQ
        DLINE   "with enough room"
 ]

25
 [ DebugQ
        DLINE   "Terminate the list"
 ]
        ; Terminate the list
        MOV     lr, #DefectList_End
        STR     lr, [r2]
        B       %FT90

30
        ; Disc is E format floppy:
        ;       no defect list and a new map

        ; Go through disc enumerating bad blocks to the bad block list
 [ DynamicMaps
        LDR     r10, [r4, #DrvsFsMapAddr]
 |
        LDR     r10, [r4, #DrvsFsMap]
 ]
        MOV     r0, #0
40
        BL      InitZoneObj
        MOV     r5, lr
45
 [ BigMaps
        CMP     R9, R11                 ; is it a gap?
        BNE     %FT46
                                        ; gap

        BL      FreeRdLenLinkBits
        ADD     r9,r9,r8
        B       %FT60
46                                      ; not gap
        BL      FragRdLenLinkBits
 |
        BL      RdLenLinkBits
 ]
        TEQ     r8, #1
        BNE     %FT60


        ; Bad block - map out enough Alloc units of disc to cover it

        ; Save zone number
        MOV     r8, r0

50
        BL      MapPtrToDiscAdd         ; (r3,r10,r11)->(r0)
        SUBS    r6, r6, #4
        BLO     %FT70                   ; buffer overflow
        BIC     r0, r0, #DiscBits
        STR     r0, [r2], #4

        BL      AllocBitWidth
        CMP     r7, lr
        ADDHI   r11, r11, lr
        SUBHI   r7, r7, lr
        BHI     %BT50                   ; Another Alloc unit to cover with

        MOV     r0, r8

60
        ADD     r11, r11, r7            ; advance over the fragment
        CMP     r11, r5                 ; check for zone end
        BLO     %BT45                   ; More fragments in this zone
        ADD     r0, r0, #1              ; next zone
        LDRB    lr, [r10, #ZoneHead + DiscRecord_NZones]
        CMP     r0, lr
        BLO     %BT40                   ; More zones in this map

        ; Terminate the list
        B       %BT25

70
        ; Buffer overflow error
        MOV     r0, #TooManyDefectsErr
        SETV

90
        BL      UnlockMap
95
        STRVS   r0, [sp, #0*4]
        Pull    "r0-r11,pc"

 [ BigDisc

; ===================
; DoOsFunDefectList64
; ===================

; In
;  r1 -> root object of disc
;  r2 -> Result buffer address
;  r5 = size of result buffer
;  r6 -> special field (is 0 for FileCore)
; Out
;  r0 unchanged or error
;  r1 number of pairs placed in the list
;  r2-r6 unchanged

DoOsFunDefectList64 ROUT
        Push    "r0-r11,lr"
        BL      DiscForPath             ; (r1)->(r0,r3,V)
        BLVC    BeforeReadFsMap         ; (r3)->(r0,V) and disc must be FileCore too
        BVS     %FT95

        ; Got the disc identified and its map locked in

        ; Sort out whether it has an explicit defect list
        BL      DiscAddToRec            ; (r3->lr)
        MOV     r5, lr
        LDRB    r1, [r5, #DiscsDrv]
        DrvRecPtr r4, r1
        LDR     r2, [sp, #2*4]          ; supplied buffer
        LDR     r6, [sp, #5*4]          ; buffer's size
        LDRB    lr, [r4, #DrvFlags]
        TST     lr, #HasDefectList
        BEQ     %FT20

 [ DebugQ
        DLINE   "Drive has a defect list"
 ]

        ; Disc has a real defect list - copy it
        LDR     r3, DefectSpace
        ADD     r3, r3, SB
        ASSERT  SzDefectList = (1 :SHL: 9)
        ADD     r3, r3, r1, ASL #9
        MOV     r1, #0

10
        LDR     lr, [r3], #4
        TST     lr, #DiscBits
        BNE     %FT15                   ; onto second defect list
        SUBS    r6,r6,#8
        BLO     %FT70                   ; buffer overflow
        STR     lr, [r2], #4
        MOV     lr, #0
        STR     lr, [r2], #4            ; zero the top word of this entry
        ADD     r1, r1, #1
        B       %BT10

15
        LDRB    lr, [r5, #DiscRecord_BigMap_Flags]      ; get flag
        TSTS    lr, #DiscRecord_BigMap_BigFlag
        BEQ     %FT25                   ; no second defect list

        LDRB    r11,[r5,#DiscRecord_Log2SectorSize]
        RSB     r10,r11,#32

16
        LDR     lr, [r3], #4
        TST     lr, #DiscBits
        BNE     %FT25                   ; fini
        SUBS    r6,r6,#8
        BLO     %FT70                   ; buffer overflow
        MOV     r9,lr,LSR r10
        MOV     r8, lr, LSL r11
        STMIA   r2!,{r8,r9}
        ADD     r1, r1, #1
        B       %BT16

20
 [ DebugQ
        DLINE   "No explicit defect list"
 ]
        ; Disc has no defect list
        MOV     r1, #0
        BL      TestMap                 ;(R3->Z)
        BEQ     %FT30

 [ DebugQ
        DLINE   "Old map"
 ]

        ; Generate an old map defect list without any defects
 [ DebugQ
        DLINE   "with enough room"
 ]

25
        B       %FT90

30
        ; Disc is E format floppy:
        ;       no defect list and a new map


        ; Go through disc enumerating bad blocks to the bad block list
 [ DynamicMaps
        LDR     r10, [r4, #DrvsFsMapAddr]
 |
        LDR     r10, [r4, #DrvsFsMap]
 ]
        MOV     r0, #0
40
        BL      InitZoneObj
        MOV     r5, lr
45
 [ BigMaps
        CMP     R9, R11                 ; is it a gap?
        BNE     %FT46
                                        ; gap

        BL      FreeRdLenLinkBits
        ADD     r9,r9,r8
        B       %FT60
46                                      ; not gap
        BL      FragRdLenLinkBits
 |
        BL      RdLenLinkBits
 ]
        TEQ     r8, #1
        BNE     %FT60

        ; Bad block - map out enough Alloc units of disc to cover it

        ; Save zone number
        MOV     r8, r0

50
        BL      MapPtrToDiscAdd         ; (r3,r10,r11)->(r0)
        SUBS    r6, r6, #8
        BLO     %FT70                   ; buffer overflow
        BIC     r0, r0, #DiscBits
        LDRB    r9, [r10,#ZoneHead+DiscRecord_Log2SectorSize]
        RSB     lr,r9,#32
        MOV     lr, r0, LSR lr
        MOV     r0, r0, LSL r9
        STMIA   r2!,{r0,lr}
        ADD     r1, r1, #1

        BL      AllocBitWidth
        CMP     r7, lr
        ADDHI   r11, r11, lr
        SUBHI   r7, r7, lr
        BHI     %BT50                   ; Another Alloc unit to cover with

        MOV     r0, r8

60
        ADD     r11, r11, r7            ; advance over the fragment
        CMP     r11, r5                 ; check for zone end
        BLO     %BT45                   ; More fragments in this zone
        ADD     r0, r0, #1              ; next zone
        LDRB    lr, [r10, #ZoneHead + DiscRecord_NZones]
        CMP     r0, lr
        BLO     %BT40                   ; More zones in this map

        ; Terminate the list
        B       %BT25

70
        ; Buffer overflow error
        MOV     r0, #TooManyDefectsErr
        SETV

90
        BL      UnlockMap
95
        STRVS   r0, [sp, #0*4]
; calculate number of buffer entries used
        STR     r1, [sp, #1*4]
        Pull    "r0-r11,pc"

 ]

; ================
; DoOsFunAddDefect
; ================

; In
;  r1 -> name of thing with defect
;  r2 = address of defect
;  r6 -> special field (is 0 for FileCore)
; Out
;  regs preserved
DoOsFunAddDefect ROUT
        Push    "r0,r3,r8,lr"
        BL      DiscForPath             ; (r1)->(r0,r3,V)
        BLVC    BeforeAlterFsMap        ; (r3)->(r0,V) and disc must be FileCore too
        BVS     %FT95

 [ BigDisc
        MOV     lr, r3, LSR #(32-3)
        DiscRecPtr lr,lr
        LDRB    lr,[lr,#DiscRecord_Log2SectorSize]
        MOV     r0, r2, LSR lr
        BL      DoDefectMapOut          ; (r0,r3)->(r0,r8,V)
 |
        MOV     r0, r2
        BL      DoDefectMapOut          ; (r0,r3)->(r0,r8,V)
 ]
90
        BL      UnlockMap               ; ()->(r0,V)
95
        STRVS   r0, [sp, #0*4]
        Pull    "r0,r3,r8,pc"

 [ BigDisc

; ==================
; DoOsFunAddDefect64
; ==================

; In
;  r1 -> name of thing with defect
;  r2 = lower 32 bits address of defect
;  r3 = upper 32 bits address of defect
;  r6 -> special field (is 0 for FileCore)
; Out
;  regs preserved
DoOsFunAddDefect64 ROUT
        Push    "r0,r3,r8,lr"
        BL      DiscForPath             ; (r1)->(r0,r3,V)
        BLVC    BeforeAlterFsMap        ; (r3)->(r0,V) and disc must be FileCore too
        BVS     %FT95

        MOV     lr, r3, LSR #(32-3)     ; get number of disc
        DiscRecPtr lr,lr                ; get disc record
        LDRB    lr,[lr,#DiscRecord_Log2SectorSize]      ; get sector size
        MOV     r0, r2, LSR lr          ; shift bottom 32 bits down
        LDR     r8,[sp,#4]              ; and get top 32 bits
        RSB     lr,lr,#32               ; generate shift
        ORR     r0,r0,r8,LSL lr         ; and mask into disc address
        BL      DoDefectMapOut          ; (r0,r3)->(r0,r8,V)
90
        BL      UnlockMap               ; ()->(r0,V)
95
        STRVS   r0, [sp, #0*4]
        Pull    "r0,r3,r8,pc"

 ]

; =====================
; DoOsFunReadBootOption
; =====================

; In
;  r1 -> object on disc with boot option
;  r6 -> special field (is 0 for FileCore)
; Out
;  r1 unchanged
;  r2 = boot option
;  r6 unchanged
DoOsFunReadBootOption ROUT
        Push    "r0,r2,r3,lr"
        BL      DiscForPath     ; (r1)->(r0,r3,V)
        BLVC    DiscAddToRec    ; (r3)->(lr)
        LDRVCB  r2, [lr, #DiscRecord_BootOpt]
        STRVC   r2, [sp, #1*4]
        STR     r0, [sp, #0*4]
        Pull    "r0,r2,r3,pc"

; ======================
; DoOsFunWriteBootOption
; ======================

; In
;  r1 -> object on disc with boot option
;  r2 = boot option
;  r6 -> special field (is 0 for FileCore)
; Out
;  r1 unchanged
;  r2 unchanged
;  r6 unchanged
DoOsFunWriteBootOption ROUT
        Push    "r0,r2,r3,lr"
        BL      DiscForPath             ; (r1)->(r0,r3,V)
        LDRVC   r2, [sp, #1*4]
        ANDVC   r2, r2, #3
        BLVC    WriteBootOption
        STRVS   r0, [sp, #0*4]
        Pull    "r0,r2,r3,pc"

; ===============
; WriteBootOption
; ===============

; In
;  r2 = boot option
;  r3 = top 3 bits disc number
; Out
;  r1 unchanged
;  r2 unchanged
;  r6 unchanged
WriteBootOption ROUT
        Push    "r3,r4,r10,lr"

 [ DebugA
        DREG    r2, "WriteBootOption(",cc
        DREG    r3,",",cc
        DLINE   ")"
 ]

        MOV     R4, R3, LSR #(32-3)
        DiscRecPtr  R4,R4
        LDRB    LR, [R4,#DiscRecord_BootOpt]
        CMPS    LR, R2
        BEQ     %FT95                   ;not changing boot option V=0

        BL      BeforeAlterFsMap        ;(R3->R0,V)
        BVS     %FT95

        ; Get to the map
        LDRB    R0, [R4,#DiscsDrv]
        DrvRecPtr  R0,R0
 [ DynamicMaps
        LDR     R10,[R0,#DrvsFsMapAddr]
 |
        LDR     R10,[R0,#DrvsFsMap]
        BIC     R10,R10,#HiFsBits
 ]
        BL      TestMap                 ;(R3->Z)

        ; New map gumph
        MOVEQ   R1, #(ZoneHead*8)+Zone0Bits
        BLEQ    MarkZone                ;(R1,R10)
        STREQB  R2, [R10,#ZoneHead+DiscRecord_BootOpt]

        ; Old map gumph
        BLNE    InvalidateFsMap         ;(R3)
        STRNEB  R2, [R10,#OldBoot]

        ; Shared gumph
        BL      WriteFsMap              ;(->R0,V)
        STRVCB  R2, [R4,#DiscRecord_BootOpt]

90
        BL      UnlockMap
95
        Pull    "r3,r4,r10,pc"
        LTORG

; ===================
; DoOsFunUsedSpaceMap
; ===================

; In
;  r1 -> object on disc with boot option
;  r2 = buffer for map
;  r5 = buffer size
;  r6 -> special field (is 0 for FileCore)
; Out
;  r1 unchanged
;  r2 unchanged
;  r5 unchanged
;  r6 unchanged
DoOsFunUsedSpaceMap ROUT
        Push    "r0-r11,lr"
        BL      DiscForPath             ; (r1)->(r0,r3,V)
        BLVC    BeforeReadFsMap
        BVS     %FT95

        ; Get map address
        BL      DiscAddToRec            ; (r3)->(lr)
        MOV     r4, lr
        LDRB    lr, [r4, #DiscsDrv]
        DrvRecPtr lr, lr
 [ DynamicMaps
        LDR     r10, [lr, #DrvsFsMapAddr]
 |
        LDR     r10, [lr, #DrvsFsMap]
        BIC     r10, r10, #HiFsBits
 ]

        BL      TestMap                 ;(R3->Z)
        BEQ     %FT50

        ; Old map
        MOV     r11, #0                 ; Allocated start
        MOV     r9, r10                 ; position in start half of map
        LDRB    r0, [r10, #FreeEnd]
        ADD     r0, r0, r10             ; map end in start half of map
        B       %FT20

10
        ; Pick up free start into r8
        LDRB    r8, [r9], #1
        LDRB    lr, [r9], #1
        ORR     r8, r8, lr, ASL #8
        LDRB    lr, [r9], #1
        ORR     r8, r8, lr, ASL #16

        ; If size of allocated bit is non-zero map it in
        SUBS    r7, r8, r11
        BLNE    MarkObjMappedIn

        ; Next allocated start = free start + free len
        LDRB    r7, [r9, #FreeLen-3]
        LDRB    lr, [r9, #FreeLen-2]
        ORR     r7, r7, lr, ASL #8
        LDRB    lr, [r9, #FreeLen-1]
        ORR     r7, r7, lr, ASL #16
        ADD     r11, r8, r7

20
        ; More free space entries?
        CMP     r9, r0
        BLO     %BT10

        ; Map in any used space at the disc's end
        ASSERT  FreeLen :MOD: 4 = 0
        LDR     r8, [r10, #OldSize]
        BIC     r8, r8, #&ff000000
        SUBS    r7, r8, r11
        BLNE    MarkObjMappedIn

        B       %FT90

50
        ; New map
        MOV     r0, #0

55
        ; Start new zone
        BL      InitZoneObj             ; (r0,r10)->(r8,r9,r11,lr)
        MOV     r4, lr

60
        ; Next fragment in zone
 [ BigMaps
        TEQ     r9,r11
        BLEQ    FreeRdLenLinkBits
        BLNE    FragRdLenLinkBits
        ADDEQ   r9, r9, r8              ; Advance free pointer
        TEQNE   r8, #1                  ; Check not bad block
        BLNE    MarkObjMappedIn         ; (r2,r3,r5,r7,r10,r11)->() If not bad block area
 |
        BL      RdLenLinkBits           ; (r10,r11)->(r7,r8)
        TEQ     r9, r11
        ADDEQ   r9, r9, r8              ; Advance free pointer
        TEQNE   r8, #1                  ; Check not bad block
        BLNE    MarkObjMappedIn         ; (r2,r3,r5,r7,r10,r11)->() If not bad block area
 ]
        ; Move to next fragment
        ADD     r11, r11, r7
        CMP     r11, r4
        BLO     %BT60

        ; Move to next zone
        ADD     r0, r0, #1
        LDRB    lr, [r10, #ZoneHead + DiscRecord_NZones]
        CMP     r0, lr
        BLO     %BT55

        ; All done

90
        BL      UnlockMap               ; ()->(r0,V)
95
        STRVS   r0, [sp, #0*4]
        Pull    "r0-r11,pc"

; ===============
; MarkObjMappedIn
; ===============

; entry r2 = allocated space map
;       r3 = top 3 bits disc num
;       r5 = allocated space map size
;       r7 = allocated space size (map bits or 256 byte units)
;       r10 = map start
;       r11 = allocated space start (map bits or 256 byte units)

; exit
;       allocate space marked as mapped in

MarkObjMappedIn ROUT
        Push    "r0-r11,lr"

 [ DebugQ
        DREG    r11, "Mark obj start ",cc
        DREG    r7, " len "
 ]

        BL      TestMap                 ;(R3->Z)
        BEQ     %FT10

        ; Old map
        BL      DiscAddToRec            ;(R3->LR)
        LDRB    lr, [lr, #DiscRecord_Log2SectorSize]
        SUB     lr, lr, #8
        B       %FT20

10
        ; New map

        ; Convert start and length in bits to start and length in bytes
        BL      MapPtrToDiscAdd         ; (r3,r10,r11)->(r0)
        BIC     r11, r0, #DiscBits
        LDRB    lr, [r10, #ZoneHead + DiscRecord_Log2bpmb]
        MOV     r7, r7, LSL lr

        ; Find allocation size (in bytes)
        LDRB    lr, [r10, #ZoneHead + DiscRecord_Log2SectorSize]
 [ BigDisc
        MOV     r11, r11, LSL lr
 ]
        LDRB    r0, [r10, #ZoneHead + DiscRecord_Log2bpmb]
        CMP     lr, r0
        MOVLO   lr, r0

20
        ; r7, r11 are length,start of the allocated area in (alloc units<<lr)
        MOV     r7, r7, LSR lr
        MOV     r11, r11, LSR lr

 [ DebugQ
        DREG    r11, "Allocation obj start ",cc
        DREG    r7, " len "
 ]

        ; r7,r11 and length, start of the allocated area in alloc units
        MOV     lr, #1
        B       %FT40
30
        LDRB    r0, [r2, r11, LSR #3]
        AND     r1, r11, #7
        ORR     r0, r0, lr, ASL r1
        STRB    r0, [r2, r11, LSR #3]
        ADD     r11, r11, #1
        SUBS    r7, r7, #1
        BEQ     %FT50

40
        CMP     r11, r5, ASL #3
        BLO     %BT30

50
        ; All done

        Pull    "r0-r11,pc"

; ====================
; DoOsFunReadFreeSpace
; ====================

; In
;  r1 -> object on disc with boot option
;  r6 -> special field (is 0 for FileCore)
; Out
;  r0 = total free
;  r1 = biggest allocatable object
;  r2 = disc size
;  r6 unchanged
;

 [ :LNOT:BigDisc

DoOsFunReadFreeSpace ROUT
        Push    "r3,r7-r11,lr"
 [ DebugA
        DSTRING r1, "ReadFreeSpace on "
 ]
        BL      DiscForPath     ; (r1)->(r0,r3,V)
        BLVC    BeforeReadFsMap         ;(R3->R0,V)
        BVS     %FT80

        BL      InitReadFs      ;(R3->R9-R11)
        MOV     R0, #0          ; Total free
        MOV     R1, #0          ; Largest free block
        B       %FT10
05
;       DREG    R0, "Total Free Space="
        ADD     R0, R0, R7
        CMPS    R7, R1
        MOVHI   R1, R7
10
        BL      NextFs          ;(R3,R9-R11->R7-R11,Z)
        BNE     %BT05

        ; Tidy up at end
        BL      TestMap         ;(R3->Z)
        MOVEQ   R1, R0          ; If new map max alloc size is whole free space

        BL      SizeLessDefects ;(R3->LR)
        MOV     R2, LR

        BL      UnlockMap
80
        Pull    "r3,r7-r11,pc"

 |
DoOsFunReadFreeSpace ROUT
        Push    "r3,r4,lr"
        BL      DoOsFunReadFreeSpace64
        TEQ     r1, #0
        MOVNE   r0, #&FFFFFFFF
        MOV     r1, r2
        TEQ     r4, #0
        MOVEQ   r2, r3
        MOVNE   r2, #&FFFFFFFF
        Pull    "r3,r4,pc"

; ======================
; DoOsFunReadFreeSpace64
; ======================

; In
;  r1 -> object on disc with boot option
;  r6 -> special field (is 0 for FileCore)
; Out
;  r0 = total free bits 0..31
;  r1 = total free bits 32..63
;  r2 = biggest allocatable object
;  r3 = disc size bits 0..31
;  r4 = disc size bits 32..63
;  r6 unchanged

DoOsFunReadFreeSpace64 ROUT
        Push    "r7-r11,lr"
 [ DebugA
        DSTRING r1, "ReadFreeSpace on "
 ]
        BL      DiscForPath     ; (r1)->(r0,r3,V)
        BLVC    BeforeReadFsMap         ;(R3->R0,V)
        BVS     %FT80

        BL      InitReadFs      ;(R3->R9-R11)
        MOV     R0, #0          ; Total free
        MOV     R1, #0          ;
        MOV     R2, #0          ; Largest free block
        B       %FT10
05
        ADDS    R0, R0, R7
        ADCS    R1, R1, #0
        CMPS    R7, R2
        MOVHI   R2, R7
10
        BL      NextFs          ;(R3,R9-R11->R7-R11,Z)
        BNE     %BT05

        ; Tidy up at end
        BL      TestMap         ;(R3->Z)
        BNE     %FT15

        ; If new map, max alloc size is whole free space (but limited to 2GB-1)
        ORRS    LR, R1, R0, LSR #31     ; NE if > &7FFFFFFF
        MOVEQ   R2, R0
        MOVNE   R2, #&7fffffff

15
        Push    "R0"
        BL      SizeLessDefects64 ;(R3->LR,R0)
        MOV     R3, LR
        MOV     R4, R0
        Pull    "R0"

        BL      UnlockMap
80
        Pull    "r7-r11,pc"
 ]

; ===============
; DoOsFunNameDisc
; ===============

; In
;  r1 -> object on disc with boot option
;  r2 -> New disc name
;  r6 -> special field (is 0 for FileCore)

; Out
;   regs preserved
DoOsFunNameDisc ROUT
        Push    "r0-r11,lr"
 [ DebugA
        DSTRING r1, "NameDisc on ",cc
        DSTRING r2, " to "
 ]
        ; Find the disc
        BL      DiscForPath     ; (r1)->(r0,r3,V)
        BVS     %FT99

        BL      DiscMustBeFileCore
        BVC     %FT10

        ; Well, actually it doesn't have to be.
        ; If here, then we're being told about a disc name change, so keep
        ; ourselves up to date with the name.
        CLRV
        MOV     r4, r2
        MOV     r6, #NameLen
        BL      DiscAddToRec            ;(R3->LR)
        ADD     r7, lr, #DiscRecord_DiscName
        BL      PutMaskedString         ;(R3,R4,R6,R7->R7)
        B       %FT99

10


        ; Check new name is vaguely correct
        LDR     r1, [sp, #2*4]
        MOV     r2, #NotDrvNum :OR: MustBeDisc :OR: NotLastWild
        BL      CheckPath               ;(r1,r2->r0,C,V)
        BVS     %FT99

        ; Check new name matches variety of disc
        BL      TestDir                 ;(r3->lr,Z)
        MOVEQ   r5, #&FF
        MOVNE   r5, #&7F
        MOVHI   r0, #BadNameErr         ;if old Format and b7 set chars
        BLHI    SetV
        BHI     %FT99

        ; Pull in the map and lock the disc for alteration
        BL      BeforeAlterFsMap        ;(r3->r0,V)
        BVS     %FT99

        MOV     r7, r1
        LDR     r10, CritDrvRec
 [ DynamicMaps
        LDR     r10, [r10, #DrvsFsMapAddr]
 |
        LDR     r10, [r10, #DrvsFsMap]
        BIC     r10, r10, #HiFsBits
 ]
        BL      TestMap                 ;(r3->Z)

        MOVEQ   r1, #(ZoneHead*8)+Zone0Bits
        BLEQ    MarkZone                ;(r1,r10)
        ADDEQ   r2, r10, #ZoneHead+DiscRecord_DiscName

        BLNE    InvalidateFsMap ;(r3)
        ADDNE   r2, r10, #OldName0
        MOV     r1, r7
;copy new disc name into FS Map
        MOV     r4, #NameLen
50
        BL      ThisChar                ;(r1->r0,r1,C)
        ADDCC   r1, r1, #1
        MOVCS   r0, #" "                ;IF terminator replace by space
        AND     r0, r0, r5
        BL      TestMap                 ;(r3->Z)
        STREQB  r0, [r2],#1
        BEQ     %FT55

        ASSERT  NameLen :MOD: 2 =0
        TSTS    r4, #1
        STREQB  r0, [r2], #OldName1-OldName0
        STRNEB  r0, [r2], #OldName0+1-OldName1
55
        SUBS    r4, r4, #1
        BNE     %BT50

60
        BL      WriteFsMap              ;(->R0,V)
        BL      UnlockMap

        MOVVC   r4, r7
        MOVVC   r6, #NameLen
        LDRVC   r7, CritDiscRec
        ADDVC   r7, r7, #DiscRecord_DiscName
        BLVC    PutMaskedString         ;(R3,R4,R6,R7->R7)

99
        STRVS   r0, [sp]
        Pull    "r0-r11,pc"

; =================
; DoOsFunStampImage
; =================

; In
; r1 = pointer to nul-terminated name of an object on the disc to be stamped
; r2 = type of image stamping to take place
; r6 = special field

; Out
;   regs preserved
DoOsFunStampImage ROUT
        Push    "r0-r11,lr"
 [ DebugA
        DSTRING r1, "StampImage on ",cc
        DREG    r2, " of type "
 ]
        ; Find the disc
        BL      DiscForPath     ; (r1)->(r0,r3,V)

        TEQ     r2, #0
        BNE     %FT10

        ; Update stamp next update
        MOV     r5, r3, LSR #(32-3)
        DiscRecPtr      r5, r5
        LDRB    lr, [r5, #DiscFlags]
        ORR     lr, lr, #NeedNewIdFlag
        STRB    lr, [r5, #DiscFlags]
        B       %FT99

10
        ; Stamp image *NOW*

        ; Pull in the map and lock the disc for alteration
        BL      BeforeAlterFsMap        ;(r3->r0,V)
        BVS     %FT99

        ; Get where we want to go
        LDR     r10, CritDrvRec
 [ DynamicMaps
        LDR     r10, [r10, #DrvsFsMapAddr]
 |
        LDR     r10, [r10, #DrvsFsMap]
        BIC     r10, r10, #HiFsBits
 ]
        BL      TestMap                 ;(r3->Z)

        ; Invalidate the map/zone as we're about to trample it
        MOVEQ   r1, #(ZoneHead*8)+Zone0Bits
        BLEQ    MarkZone                ;(r1,r10)
        BLNE    InvalidateFsMap         ;(r3)

        ; Set a new (random) Id
        BL      GetRandomId             ;(->lr)
        STREQB  lr, [r10, #ZoneHead+DiscRecord_DiscId+0]
        STRNEB  lr, [r10, #OldId+0]
        MOV     lr, lr, LSR #8
        STREQB  lr, [r10, #ZoneHead+DiscRecord_DiscId+1]
        STRNEB  lr, [r10, #OldId+1]

        ; Write it all out
        BL      WriteFsMap              ;(->R0,V)
        BL      UnlockMap

99
        STRVS   r0, [sp]
        Pull    "r0-r11,pc"


; =====================
; DoOsFunObjectAtOffset
; =====================

; In
;  r1 -> object on disc of interest
;  r2 =  offset on disc
;  r3 -> buffer
;  r4 =  buffer length
;  r6 -> special field (is 0 for FileCore)

; Out
;  r2 = 0 if is free, or is defect, or is beyond end of media
;       1 if not free, not defect, but is allocated
;       2 if found and object is definitely only object associated with that address
;       3 if found and object may share offset with other objects

DoOsFunObjectAtOffset ROUT
        Push    "r0-r11,lr"

 [ DebugA
        DSTRING r1, "ObjectAtOffset on ",cc
        DREG    r2, " at "
 ]
        ; Find the disc
        BL      DiscForPath     ; (r1)->(r0,r3,V)
 [ DebugA
        BVC     %FT01
        DLINE   "Error from DiscForPath"
01
 ]
        BVS     %FT90

        BL      DiscAddToRec    ; (r3->lr)
        MOV     r5, lr

 [ BigDisc
        LDR     lr, [r5, #DiscRecord_BigMap_DiscSize2]
        MOVS    lr, lr                          ; is the disc huge?
        BNE     %FT02                           ; yes, so don't bother checking offset
        ; Check address against disc size
        LDR     lr, [r5, #DiscRecord_DiscSize]
        CMP     r2, lr
        MOVHS   r2, #0          ; beyond end of media
        BHS     %FT80
02
 |
        ; Check address against disc size
        LDR     lr, [r5, #DiscRecord_DiscSize]
        CMP     r2, lr
        MOVHS   r2, #0          ; beyond end of media
        BHS     %FT80
 ]

 [ DebugA
        DLINE   "Address not beyond end of disc"
 ]

        ; Convert offset to disc address
        AND     r3, r3, #DiscBits
 [ BigDisc
        LDRB    lr, [r5, #DiscRecord_Log2SectorSize]
        ORR     r3, r3, r2, LSR lr
 |
        ORR     r3, r3, r2
 ]

        BL      BeforeReadFsMap
        BVS     %FT90

 [ DebugA
        DLINE   "Map in"
 ]

        BL      IsAddressNotFile
        BVS     %FT85
 [ DebugA
        BNE     %FT01
        DLINE   "free or defect"
01
 ]
        MOVEQ   r2, #0          ; free or defect
        BEQ     %FT80

 [ DebugA
        DREG    r8, "Hunting "
 ]

        LDR     r3, [r5, #DiscRecord_Root] ; root dir
        LDR     r0, [sp, #3*4]
        LDR     r1, [sp, #4*4]
        ADD     r1, r1, r0

        BL      TestDir         ;(R3->LR,Z)
        MOVEQ   R9, #&FF        ;set up bit 7 chars mask
        MOVNE   R9, #&7F

15
        ; Start of loop, here:
        ; r0 = object name buffer start
        ; r1 = object name buffer end
        ; r3 = directory disc address
        ; r8 = indirect disc address to find
        ; r9 = mask for names

        ; Go into a directory
 [ DebugA
        DREG    r3, "Going into ",cc
        MOV     r2, #0
        STRB    r2, [r0]
        LDR     r2, [sp, #3*4]
        DSTRING r2, " = "
 ]

        BL      FindDir         ;(R3->R0,R5,R6,V)
        BVS     %FT85
 [ BigDir
        BL      GetDirFirstEntry        ; (R3,R5->R4)
        BL      TestBigDir              ; (R3->LR,Z)
        SUBNE   R4, R4, #NewDirEntrySz  ; small dir
        SUBEQ   R4, R4, #BigDirEntrySize; big dir
 |
        ASSERT  OldDirEntrySz = NewDirEntrySz
        SUB     R4, R5, #NewDirEntrySz-DirFirstEntry
 ]
        B       %FT45

20
        ; Check one directory entry

        BL      ReadIntAtts     ;(R3,R4->LR)
        ANDS    R7, LR, #DirBit

        ; Put directory name into buffer
        BLNE    %FT96
        BVS     %FT85

        ; Check if Ind disc address matches fragment found
        BL      ReadIndDiscAdd  ;(R3,R4->LR)
        MOV     R2, LR
        BL      TestMap         ;(R3->Z)
        BEQ     %FT30

        ; Old map check
        CMP     r2, r8
        BHI     %FT40           ; branch if starts after address
        BL      ReadLen         ;(R3,R4->LR)
        ADD     lr, lr, r2      ; generate end of object
        CMP     lr, r8
        BLS     %FT40           ; branch if ends before address
        B       %FT65           ; branch if got a hit

30
        ; New map check
        EOR     lr, r2, r8      ; Like a TEQ
        BICS    lr, lr, #&ff    ; but not interested in bits to do with sharing
        BEQ     %FT65           ; branch if got a candidate

40
        ; Check if want to recurse into directory here

        TEQ     R7, #DirBit
        MOVEQ   R3, R2
        BEQ     %BT15

45
        ; Check for end of directory

 [ BigDir
        BL      TestBigDir              ; (R3->LR,Z)
        BNE     %FT01                   ; not big dir

        ; big dir
        ADD     R4, R4, #BigDirEntrySize        ; go to next entry
        BL      BigDirFinished          ; (R4,R5->Z)
        BNE     %BT20                   ; more to do
        B       %FT02                   ; finished
01
        ; not big dir
        LDRB    LR, [R4, #NewDirEntrySz] !
        AND     lr, lr, r9
        CMPS    LR, #" "
        BHI     %BT20           ; branch if entry not empty
02
 |
        ASSERT  OldDirEntrySz = NewDirEntrySz
        LDRB    LR, [R4, #NewDirEntrySz] !
        AND     lr, lr, r9
        CMPS    LR, #" "
        BHI     %BT20           ; branch if entry not empty
 ]

        ; Processing for end of scanning one directory

        MOV     R7, R3
        BL      ToParent        ;(R3,R6->R3)
        CMP     R3, R7
        MOVEQ   r2, #1          ; not found - part of disc management area
        BEQ     %FT80           ;V=0 end when back to root if no match found

        BL      FindDir         ;(R3->R0,R5,R6,V)
        BVS     %FT85

        ; To avoid cache thrash
        BL      AgeDir          ;(R7)

        ; Remove the directory's name from the buffer
50
        LDRB    r2, [r0, #-1]!
        TEQ     r2, #"."
        BNE     %BT50

        ; Re-find where we're up to in this directory
 [ BigDir
        BL      GetDirFirstEntry        ; (R3,R5->R4)
        BL      TestBigDir              ; (R3->LR,Z)
        SUBNE   R4, R4, #NewDirEntrySz
        SUBEQ   R4, R4, #BigDirEntrySize
 |
        ASSERT  OldDirEntrySz = NewDirEntrySz
        SUB     R4, R5, #NewDirEntrySz-DirFirstEntry
 ]
55
 [ BigDir
        BL      TestBigDir              ; (R3->LR,Z)
        ADDEQ   R4, R4, #BigDirEntrySize
        ADDNE   R4, R4, #NewDirEntrySz
 |
        ASSERT  OldDirEntrySz = NewDirEntrySz
        ADD     r4, r4, #NewDirEntrySz
 ]
        BL      ReadIndDiscAdd  ;(R3,R4->LR)
        TEQS    LR, R7
        BNE     %BT55

        B       %BT45

65
        ; Found a candidate exit

        ; Fill in its name if not a directory (r7=0)
        CMPS    R7, #0          ;V=0
        BLEQ    %FT96
        BVS     %FT85

        ; Terminate the name
        MOV     r2, #0
        BL      %FT95
        BVS     %FT85

        ; work out return parameter
        BL      TestMap         ;(R3->Z)
        MOVNE   r2, #2          ; unshared
        BNE     %FT80
        TST     r2, #&ff
        MOVEQ   r2, #2          ; unshared
        MOVNE   r2, #3          ; may be shared

80
        STR     r2, [sp, #2*4]

85
        BL      UnlockMap

90
        STRVS   r0, [sp]
        Pull    "r0-r11,pc"


; In r0 = pointer to buffer position
;    r1 = end of buffer + 1
;    r2 = character to place in buffer
95
        Push    "lr"
        CMP     r0, r1
        STRLOB  r2, [r0], #1
        Pull    "pc",LO
        MOV     r0, #BufferErr
        BL      SetV
        Pull    "pc"

; In r0 = pointer to buffer position
;    r1 = end of buffer + 1
;    r4 = pointer to direntry to copy into buffer
; BigDir R3 = disc address
;        R5 = directory start
;
; places .<EntryName> into buffer
96
        Push    "r2,r4,r11,lr"
 [ DebugA
        DREG    r0, "(",cc
        DREG    r1, ",",cc
        DLINE   ")"
 ]
        MOV     r2, #"."
        BL      %BT95
        Pull    "r2,r4,r11,pc",VS       ; 000524 KJB - was lr instead of pc
 [ BigDir
        BL      TestBigDir      ;(R3->LR,Z)
        BNE     %F98            ; when not a big dir use simpler code
        
        LDR     R11, [R4, #BigDirObNameLen]
        BL      GetBigDirName   ; (R4,R5->LR) get the name ptr
        MOV     r4, lr
97
        LDRB    r2, [r4], #1
        AND     r2, r2, r9
        BL      %BT95
        SUBS    r11, r11, #1
        BHI     %BT97
        Pull    "r2,r4,r11,pc"
98
 ]
        MOV     r11, #NameLen
        ADD     r4, r4, #DirObName
97
        LDRB    r2, [r4], #1
        AND     r2, r2, r9
        CMP     r2, #" "
        BLHI    %BT95
        Pull    "r2,r4,r11,pc",VS
        SUBHIS  r11, r11, #1
        BHI     %BT97
        Pull    "r2,r4,r11,pc"


; ================
; IsAddressNotFile
; ================

; In
; r3 = disc address
; disc has been BeforeReadFSMapped

; Out
; Z set if not in a file/directory, clear if is
; r8 = match tag if found:
;       New map: fragment Id
;       Old map: r3 in

IsAddressNotFile ROUT
        Push    "r0,r5,r7-r11,lr"

        BL      TestMap         ;(R3->Z)
        BNE     %FT50

        ; New map check

        BL      InitReadNewFs   ;(R3->R10,R11,LR)

        MOV     r0, r3
        BL      DiscAddToMapPtr         ;(R0,R10->R11,LR)
        MOV     R1, R11
        MOV     R0, LR

        BL      InitZoneObj     ;(R0,R10->R8,R9,R11,LR)
        MOV     R5, LR
        TEQS    R9, R8
        MOVEQ   R9, #0

05
 [ BigMaps
        TEQ     r9,r11
        BLEQ    FreeRdLenLinkBits
        BLNE    FragRdLenLinkBits
 |
        BL      RdLenLinkBits       ;(R10,R11->R7,R8)
 ]
        ADD     lr, r11, r7

        ; Check if fragment spans address
        CMP     lr, r1
        BHI     %FT10           ;skip out of loop if reached fragment

        ; Advance free space
        TEQ     r9, r11
        ADDEQ   r9, r9, r8

        MOV     r11, lr

        ; Check for end of zone
        CMP     r11, r5
        BLO     %BT05           ;loop if not reached end of zone

        ; Ran off end of zone
        MOV     r0, #BadParmsErr
        BL      SetV
        B       %FT99

10
        ; Found fragment containing address
        TEQ     r11, r9         ; Is it free?
        TEQNE   r8, #1          ; Is it defect?

        ; Convert r8 into thing to hunt for
        AND     lr, r3, #DiscBits
        ORR     r8, lr, r8, ASL #8

        ; Z now set as per spec
        B       %FT90

50
        ; Old map check
        BL      InitReadOldFs           ;(R3->R9-R11)
        B       %FT60
55
        SUBS    lr, r3, r8
        BLO     %FT70           ; branch if next free beyond disc address; LO implies NE
        CMP     lr, r7
        BLO     %FT80           ; branch if (addr-start of free) < length of free, ie if free

60
        BL      NextOldFs       ;(R10-R11->R7,R8,R10,R11,Z)
        BNE     %BT55           ;loop while more free spaces

70
        ; Not free - generate an NE situation
        MOVS    r0, #-1
        MOV     r8, r3
        B       %FT90

80
        ; Is free - generate an EQ situation
        MOVS    r0, #0
        MOV     r8, r3

90
        ; Make sure V is clear and return r8
        CLRPSR  V_bit,lr

        STR     r8, [sp, #3*4]

99
        STRVS   r0, [sp]
        Pull    "r0,r5,r7-r11,pc"


; ===========
; DiscForPath
; ===========

; entry r1 = path

; exit  r3 = disc address of root, r0,V for error

DiscForPath ROUT
        Push    "r1,r2,lr"
        LDRB    lr, [r1]
        TEQ     lr, #":"
        ADDEQ   r1, r1, #1
        MOV     r2, #0
        BL      FindDiscByName  ; (r1,r2)->(r0,r1,r3,V)
        Pull    "r1,r2,pc"

        END
