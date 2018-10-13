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
;>FileCore70

; *********************************
; ***  CHANGE LIST AND HISTORY  ***
; *********************************
;
; 28 May 1997 SBP   Changed for idlen>15
;
; 16-Jun-94   AMcC  Replaced ScratchSpaceSize with ?ScratchSpace
;

        TTL     "FileCore70 - Random Access"

 [ DebugB
CheckProcessBlks ROUT
        Push    "r5-r7,lr"
        SavePSR r7
        LDRB    r5, MaxFileBuffers
        TEQ     r5, #0
        BEQ     %FT90

        LDR     r5, WinnieProcessBlk
        TST     r5, #BadPtrBits
        BNE     %FT01
        LDRB    R6, [R5,#Process]
        TSTS    R6, #ReadAhead :OR: WriteBehind
        BEQ     %FT01
        LDR     r6, [R5, #ProcessEndPtr]
        TST     r6, #BadPtrBits
        LDREQ   r6, [R5, #ProcessStartPtr]
        TSTEQ   r6, #BadPtrBits
        LDREQ   r6, [R5, #ProcessFcb]
        TSTEQ   r6, #BadPtrBits
        BEQ     %FT01
        MOV     r0, #0
        MOV     r1, #0
        SWI     XOS_ChangeRedirection
        LDR     r5, [sp, #3*4] ; sp offset OK.
        DREG    r5, "WinnieProcessBlk bad at "
        MOV     pc, #0
01
        LDR     r5, FloppyProcessBlk
        TST     r5, #BadPtrBits
        BNE     %FT02
        LDRB    R6, [R5,#Process]
        TSTS    R6, #ReadAhead :OR: WriteBehind
        BEQ     %FT02
        LDR     r6, [R5, #ProcessEndPtr]
        TST     r6, #BadPtrBits
        LDREQ   r6, [R5, #ProcessStartPtr]
        TSTEQ   r6, #BadPtrBits
        LDREQ   r6, [R5, #ProcessFcb]
        TSTEQ   r6, #BadPtrBits
        BEQ     %FT02
        MOV     r0, #0
        MOV     r1, #0
        SWI     XOS_ChangeRedirection
        LDR     r5, [sp, #3*4] ; sp offset OK.
        DREG    r5, "FloppyProcessBlk bad at "
        MOV     pc, #0
02
90
        RestPSR r7,,f
        Pull    "r5-r7,pc"

        MACRO
        CPBs
        Push    "lr"
        BL      CheckProcessBlks
        Pull    "lr"
        MEND
 ]

; >>>>>>>>>>>>>
; OpenFileEntry
; >>>>>>>>>>>>>

; entry:
;  R0   0=>open for read, 1=>[create and] open for update, 2=>open for update
;  R1   ->filename
;  R3   external handle
;  R6   ->special field UNUSED

; exit:
; V clear
;  R0   b0-b7   filing system no
;       b8-b15  device no
;       b29/b30/b31 set if D/R/W access
;  R1   handle
;  R2   buffer size for FileSwitch to use (powers of 2)
;  R3   extent
;  R4   allocated size
; V set
;  R0   -> error block

OpenFileEntry ROUT
        SemEntry  Flag,Dormant  ;leaves R12,LR stacked
        BL      MyOpenFile      ;(R0-R1,R3,R6->R0-R4,LR)
        MOVVC   R0, LR          ;device number
        BLVS    FindErrBlock    ; (R0->R0,V)
        BL      FileCoreExit
 [ DebugB
        DebugError "Open error"
 ]
        Pull    "SB,PC"

DummyBuf * .-BufFileOff
        ASSERT  BufFcb=BufFileOff + 4
 & -1
 & -1

; ==========
; MyOpenFile
; ==========

; entry:
;  R0   0=>open for read, 1=>[create and] open for update, 2=>open for update
;  R1   ->filename
;  R3   external handle
;  R6   ->special field

; exit:
; IF error V set, R0 result
; ELSE
;  R1   handle
;  R2   buffer size
;  R3   extent
;  R4   allocated size
;  LR   b0-b7   filing system no
;       b8-b15  device no
;       b29/b30/b31 set if D/R/W

MyOpenFile ROUT
 [ DebugB
        DLINE   "reason  |name    |ext handle - >MyOpenFile"
        DREG    R0,,cc
        DREG    R1,,cc
        DREG    R3
        CPBs

        Push    "r8,lr"
        sbaddr  lr, FirstFcb-FcbNext
        B       %FT02
01
        LDR     r8, [lr, #FcbIndDiscAdd]
        DREG    r8, "File in chain:"
02
        LDR     lr, [lr,#FcbNext];get next FCB
        CMPS    lr, #-1
        BNE     %BT01           ;file matches no FCB so not open, return EQ

        Pull    "r8,lr"
 ]
        Push    "R1-R3,R5-R11,LR"
        MOV     R11,R0
        MOV     R2, #NotNulName
        TEQS    R11,#fsopen_CreateUpdate
        ORREQ   R2, R2, #DirToBuffer :OR: NotLastWild
        BL      FullLookUp      ;(R1,R2->R0-R6,C,V)

        BVC     %FT05
        TEQS    R0, #NotFoundErr
        BNE     %FT99           ;error other than not found V=1
        TEQS    R11,#fsopen_CreateUpdate  ;should I create it ?
        MOVNE   R1, #0          ;if not return with 0 handle
        BNE     %FT90
        BL      ThisChar        ;(R1->R0,C)
        MOVCC   R1, #0          ;not terminator => not last term => cant create
        BCC     %FT90
        LDR     R0, [SP]        ;string start
        BL      TermStart       ;backtrack to start of last term (R0,R1->R1)
        MOV     R2, #WriteBit :OR: ReadBit         ;atts
        BL      ReadTimeDate    ;(->R7,R8)
        MOVS    LR, #0, 2                       ;Z=1, C=0
        MOV     R9, #0
        MOV     R10,#0                          ;old length (R10-R9)=0
        MOV     R11,#RandomAccessCreate         ;reason code
        BL      SaveCreate                      ;(R1-R11,Z,C->R0,V)
        BVS     %FT99
        MOVS    R11,#fsopen_CreateUpdate :SHL: 2,2        ;also C=0
05
 [ DebugB
        DREG    R3, "File found: ",cc
        DREG    R4, ","
        CPBs
 ]
        ASSERT  fsopen_ReadOnly<&100           ;to preserve C
        TEQCS   R11,#fsopen_ReadOnly
        MOVHI   R0, #TypesErr
        BHI     %FT95                   ;if dir and other than OpenIn
        BL      ReadIntAtts             ;(R3,R4->LR)
        TSTS    LR, #IntLockedBit       ;if locked then haven't got write access
        BICNE   LR, LR, #WriteBit
        TEQS    R11,#fsopen_ReadOnly
        BICEQ   LR, LR, #WriteBit       ;deny write access if read only requested
        ANDS    R10,LR,#DirBit :OR: WriteBit :OR: ReadBit   ;for later
        MOVEQ   R0, #AccessErr
        BEQ     %FT95           ;hasn't got necessary atts
        TEQS    R11,#fsopen_CreateUpdate
        ORREQ   R10,R10,#ExtFlag
        TSTS    R10,#DirBit
        ORRNE   R10,R10,#bit31
        ; If disc is in floppy drive set FCB floppy flag
        BL      DiscAddToRec    ;(R3->LR)
        LDRB    LR, [LR, #DiscFlags]
        TST     LR, #FloppyFlag
        ORRNE   R10, R10, #FcbFloppyFlag

        ; If disc not filecore set FCB disc image
        TST     LR, #DiscNotFileCore
        ORRNE   R10, R10, #FcbDiscImage
 [ DebugK
        mess    ,"DiscAddr|Winnies |R10     - MyOpenFile",NL
        DREG    R3
        DREG    LR
        DREG    R10
        DLINE   " "
 ]

 [ DebugB
        DREG    R10, "Initial FcbFlags+ are "
        CPBs
 ]

        BL      OpenCheck       ;(R3,R4,R5->R0,R8,R9,Z)
        BEQ     %FT20           ;no FCB for object

        LDR     R7, [R9,#FcbExtHandle]
        CMPS    R7, #0
        BEQ     %FT10           ;not really open, V=0
                                ;IF file was already open AND
        TEQS    R11,#fsopen_CreateUpdate          ;  openout
        BEQ     %FT95
        TSTS    R10,#WriteBit           ;  OR (requesting write access
        LDREQB  LR, [R9,#FcbFlags]      ;       OR  file had write access)
        TSTEQS  LR, #WriteBit
        BNE     %FT95                   ;THEN moan
        BL      %FT15           ;R7,R9 -> R0,R5,V
        BVS     %FT99
        STR     R5, [R9, #FcbExtHandle]
        B       %FT85

10                      ;V=0
        TEQS    R11,#fsopen_CreateUpdate
        BLEQ    FreeFcb         ;(R8,R9->R0,V)
        BVS     %FT99
        BEQ     %FT20

        MOV     LR, #0
        STRB    LR, [R9, #FcbDataLostFlag]
        LDRB    LR, [R9, #FcbFlags]
        AND     LR, LR, #Monotonic
        ORR     R10,R10,LR
        STRB    R10,[R9, #FcbFlags]
        TSTS    R10,#WriteBit
        LDRNE   R5, [SP, #2*4]
        BLEQ    %FT15           ;(R7,R9->R0,R5,V)
        BVS     %FT99
        STR     R5, [R9, #FcbExtHandle]
        MOV     R2, #-1         ;FCB linked flag
        B       %FT60           ;R8 = predecessor Fcb, R9 = Fcb, R10 = flags

;build a handle block
;entry
; R7 next handle block or 0
; R9 Fcb

;exit R0,V if error
;R5 HandleBlock

15
        Push    "R2,R3,LR"
 [ UseRMAForFCBs
        MOV     R0, #ModHandReason_Claim
        MOV     R3, #HandleBlkSize
        BL      OnlyXOS_Module
 |
        MOV     R0, #HeapReason_Get
        MOV     R3, #HandleBlkSize
        BL      OnlySysXOS_Heap         ;(R0,R2,R3->R0,R2,R3,V)
 ]
        STRVC   R7, [R2,#NextHandleBlk]
        STRVC   R9, [R2,#HandleBlkFcb]
        LDRVC   LR, [SP, #(3+2)*4]
        STRVC   LR, [R2, #ExtHandle]
        MOVVC   R5, R2
        Pull    "R2,R3,PC"


20
 [ DebugB
        DLINE   "Constructing new Fcb"
        CPBs
 ]
        ORR     R10,R10,#Monotonic
        Push    "R3"
 [ UseRMAForFCBs
        MOV     R0, #ModHandReason_Claim
        MOV     R3, #FcbSize
        BL      OnlyXOS_Module          ;(R0,R2,R3->R0,R2,R3,V)
 |
        MOV     R0, #HeapReason_Get
        MOV     R3, #FcbSize
        BL      OnlySysXOS_Heap         ;(R0,R2,R3->R0,R2,R3,V)
 ]
        Pull    "R3"
        BVS     %FT99                   ;couldn't get Fcb from system heap
 [ BigDir
        Push    "R5"
 [ DebugX
        DREG    R5, "pushing dir pointer:"
 ]
 ]

        MOV     R9, R2
        TSTS    R10,#WriteBit
 [ BigDir
        LDRNE   R5, [SP,#2*4+4]         ;external handle
 |
        LDRNE   R5, [SP,#2*4]           ;external handle
 ]
        BNE     %FT25
        MOV     R7, #0
        BL      %BT15                   ;R7,R9 -> R0,R5,V
        BVC     %FT25

 [ UseRMAForFCBs
        MOV     R0, #ModHandReason_Free
        BL      OnlyXOS_Module
 |
        MOV     R0, #HeapReason_Free           ;return Fcb if failed to claim handle block
        BL      OnlySysXOS_Heap         ;(R0,R2->R0,V)
 ]
 [ BigDir
        ADD     SP, SP, #4
 ]
        B       %FT95

25
 [ DebugB
        DREG    r5, "Filling in ExtHandle to "
 ]
        STR     R5, [R9, #FcbExtHandle]
;NOW FILL IN FILE CONTROL BLOCK
        ; Find the last sequential open file
        MOVS    R5, R9                  ;sets NE
        sbaddr  R7, FirstFcb-FcbNext
        B       %FT35
30
        CMPS    R7, #-1
        LDRNEB  LR, [R7, #FcbFlags]
        TSTNES  LR, #Sequential
        LDRNE   LR, [R7, #FcbExtHandle]
        TEQNES  LR, #0
35
        MOVNE   R8, R7
        LDRNE   R7, [R7, #FcbNext]
        BNE     %BT30

        MOV     R0, #0
        MOV     R6, #1*K
        RSB     R6, R6, #0
        ASSERT  BufFlags = 0
        ASSERT  NextInFile = BufFlags + 4
        ASSERT  PrevInFile = NextInFile + 4
        ASSERT  BufFileOff = PrevInFile + 4
        ASSERT  FcbNext    = BufFileOff + 4
        ASSERT  FcbFlags   = FcbNext + 4
        STMIA   R9, {R0,R2,R5-R7,R10}
        MOV     R1, #0
        MOV     LR, #2
        ADD     R6, R9, #FcbLastReadEnd
        ASSERT  FcbAccessHWM = FcbLastReadEnd + 4
        ASSERT  FcbRdAheadBufs = FcbAccessHWM + 4
        ASSERT  FcbDataLostFlag = FcbRdAheadBufs + 1
        STMIA   R6, {R0,R1,LR}

 [ BigDir
        Pull    "R5"                    ;restore dir pointer
        BL      TestBigDir              ;(R3->LR,Z)
        BNE     %FT50
        ADD     R7, R9, #FcbName
        TEQS    R4, #0
        STREQB  R4, [R7]
        BEQ     %FT55
        Push    "R4"                    ;slow?
        LDR     R6, [R4, #BigDirObNameLen]
        BL      GetBigDirName           ;(R4,R5->LR)
        MOV     R4, LR                  ;->name
 [ DebugB
        DREG    R4, "name from:"
        DREG    R6, "name len:"
 ]
        BL      PutMaskedString         ;(R3,R4,R6,R7->R7)
        MOV     LR, #0
        STRB    LR, [R7]
 [ DebugB
        ADD     LR, R9, #FcbName
        DSTRING LR, "name is"
 ]

        Pull    "R4"                    ;slow?
        B       %FT55
50
        MOV     R6, #NameLen
        ADD     R7, R9, #FcbName
        BL      PutMaskedString         ;(R3,R4,R6,R7->R7)
        MOV     LR, #0
        STRB    LR, [R7]
55
 |
        MOV     R6, #NameLen
        ADD     R7, R9, #FcbName
        BL      PutMaskedString         ;(R3,R4,R6,R7->R7)
 ]
        MOV     R2, #0                  ;FCB not linked flag
60
        BL      ReadIndDiscAdd          ;file address (R3,R4->LR)
        ASSERT  FcbIndDiscAdd = FcbDir + 4
        ADD     R6, R9, #FcbDir
        STMIA   R6, {R3,LR}
 [ DebugB
        DREG    R3, "Dir+Object stored are ",cc
        MOV     R1, LR
        DREG    R1, ","
        CPBs
 ]
 ; get the new map file size right
        MOV     R1, LR
        BL      ReadLen                 ;(R3,R4->LR)
        STR     LR, [R9,#FcbExtent]
        BL      MeasureFileAllocSize    ;(R1,R3,R4->R0)
        BVS     %FT75
        STR     R0, [R9, #FcbAllocLen]

        EORS    R0, R11,#fsopen_CreateUpdate
        STREQ   R0, [R9, #FcbExtent]    ;Created files start out 0 length

        TEQS    R2, #0
        BNE     %FT70                   ;IF FCB already linked

        ; Lock disc into drive to ensure disc doesn't change
        ; whilst we're accessing it (we can't find it again if
        ; it does change because its unidentifyable).
        BL      LockUnidentifyableDisc

        TEQS    R1, #0
        BLNE    DiscAddToRec            ;(R3->LR)
        LDRNEB  R1, [LR, #DiscRecord_Log2SectorSize]
        MOVNE   LR, #1
        MOVNE   LR, LR, LSL R1
        BLEQ    ReadAllocSize           ;(R3->LR)
      [ BigSectors
        CMPS    LR, #4*K
        MOVHI   LR, #4*K                ; because FcbBufSz is only 1 byte
      |
        CMPS    LR, #1*K
        MOVHI   LR, #1*K
      ]
        MOV     LR, LR, LSR #BufScale
        STRB    LR, [R9, #FcbBufSz]

        STR     R9, [R8, #FcbNext]
70
        LDRB    R6, Interlocks
 [ DebugK
        mess    ,"MyOpenFile(1) Interlocks="
        DREG    R6
        DLINE   " "
 ]
        TSTS    R6, #NoOpenFloppy       ;IF first open file
        TSTNES  R6, #NoOpenWinnie
        LDRNEB  LR, MaxFileBuffers      ;AND able to run in background
        TEQNES  LR, #0
        BEQ     %FT80

        MOV     LR, #1                  ;THEN start scheduler
        STR     LR, TickerState
        MOV     R0, #TickerV
        ADRL    R1, TickerEntry
        BL      OnlyXOS_Claim           ;(R0,R1->R0,V)
        BVC     %FT80

75
        ; Error exit with discard
        Push    "R0"
        LDR     LR, [R9, #FcbNext]
        STR     LR, [R8, #FcbNext]
 [ UseRMAForFCBs
        MOV     R0, #ModHandReason_Free        ;return Fcb if failed to claim handle block
        LDR     R2, [R9, #FcbExtHandle]
        CMPS    R2, #NotHandle
        BLHS    OnlyXOS_Module          ;(R0,R2->R0,V)
        MOV     R2, R9
        BL      OnlyXOS_Module          ;(R0,R2->R0,V)
 |
        MOV     R0, #HeapReason_Free           ;return Fcb if failed to claim handle block
        LDR     R2, [R9, #FcbExtHandle]
        CMPS    R2, #NotHandle
        BLHS    OnlySysXOS_Heap         ;(R0,R2->R0,V)
        MOV     R2, R9
        BL      OnlySysXOS_Heap         ;(R0,R2->R0,V)
 ]
        Pull    "R0"
        B       %FT95

80
        TSTS    R10,#FcbFloppyFlag
        BICNE   R6, R6, #NoOpenFloppy
        BICEQ   R6, R6, #NoOpenWinnie
        STRB    R6, Interlocks
 [ DebugK
        mess    ,"MyOpenFile(2) sets Interlocks to "
        DREG    R6
        DLINE   " "
 ]
85
        TSTS    R10,#WriteBit
        LDREQ   R1, [R9,#FcbExtHandle]
        ORREQ   R1, R1, #HandleBlkBit
        MOVNE   R1, R9
        LDRB    R2, [R9, #FcbBufSz]
        MOV     R2, R2, LSL #BufScale
        LDR     R3, [R9, #FcbExtent]
        LDR     R4, [R9, #FcbAllocLen]
      [ BigFiles
        TEQ     R4, #RoundedTo4G
        MOVEQ   R4, #&FFFFFFFF  ;limit of the FileSwitch API
      ]
90
        MOV     R0, #0
95
        BL      SetVOnR0
        LDRB    LR, FS_Id
        MOV     R10,R10,ROR #2
        AND     R10,R10,#&E0000000
        ORR     LR, R10,LR
99
        ADD     SP, SP, #3*4    ;discard entry R1-R3
 [ DebugB
        DLINE   "result  |handle  |buf siz |  extent|  length|device - <MyOpenFile"
        DREG    R0,,cc
        DREG    R1,,cc
        DREG    R2,,cc
        DREG    R3,,cc
        DREG    R4,,cc
        MOV     R5, LR
        DREG    R5
        CPBs
        BVC     %FT01
        ADD     R0, R0, #4
        DSTRING R0, "Error from MyOpenFile was: "
        SUB     R0, R0, #4
01
 ]
        Pull    "R5-R11,PC"

; ======================
; LockUnidentifyableDisc
; ======================

; entry: Fcb

; If the disc is unidentified then lock
; the associated drive (it is not possible to have
; a detached unidentified disc)
LockUnidentifyableDisc ROUT
        Push    "r0,r1,lr"
        LDR     r1, [Fcb, #FcbIndDiscAdd]
        MOV     r1, r1, LSR #(32-3)
        DiscRecPtr lr, r1

        ; Data disc?
        LDR     r0, [lr, #DiscRecord_DiscType]
        LDR     r1, =FileType_Data
        TEQ     r0, r1
        BNE     %FT90

        ; Lock the drive (and swallow any error)
        LDRB    r1, [lr, #DiscsDrv]
 [ DebugN
 DREG   r1, "Locking unidentified disc in drive "
 ]
        BL      LockDrive               ;(r1->V,r0)

90
        Pull    "r0,r1,pc"

; ========================
; UnlockUnidentifyableDisc
; ========================

; entry: Fcb

; If the disc is unidentified then unlock
; the associated drive (it is not possible to have
; a detached unidentified disc)
UnlockUnidentifyableDisc ROUT
        Push    "r0,r1,lr"
        LDR     r1, [Fcb, #FcbIndDiscAdd]
        MOV     r1, r1, LSR #(32-3)
        DiscRecPtr lr, r1

        ; Data disc?
        LDR     r0, [lr, #DiscRecord_DiscType]
        LDR     r1, =FileType_Data
        TEQ     r0, r1
        BNE     %FT90

        ; Unlock the drive (and swallow any error)
        LDRB    r1, [lr, #DiscsDrv]
 [ DebugN
 DREG   r1, "Unlocking unidentified disc in drive "
 ]
        BL      UnlockDrive               ;(r1->V,r0)

        ; Release any Fcb buffers associated with it
        MOV     r1, Fcb
        BL      ReleaseAllFcbBuffers    ;(r1)

90
        Pull    "r0,r1,pc"


; >>>>>>>>>>>>>>
; CloseFileEntry
; >>>>>>>>>>>>>>

; entry:
;  R1   handle
;  R2   load add
;  R3   exec add, if both R2 & R3 zero leave load & exec alone

; exit:
; IF error V set, R0->error block else corrupt
; R1 corrupt

CloseFileEntry ROUT
        SemEntry  Flag          ;allow reentrance, leaves R12,LR stacked
        BL      MyCloseFile     ;(R1->R0)
        BLVS    FindErrBlock    ;(R0->R0,V)
        BL      FileCoreExit
 [ DebugB
        DebugError "CloseFileEntry error"
 ]
        Pull    "SB,PC"


; ===========
; MyCloseFile
; ===========

; entry:
;  R1    handle
;  R2,R3 date stamp, or 0 if none

; exit:
;  IF error V set, R0 result else corrupt
;  R1 corrupt

MyCloseFile ROUT
 [ DebugB
        DREG    R1, ">MyCloseFile(",cc
        DLINE   ")"
 ]
        Push    "R2-R11,LR"
        MOV     R11,R1
        BL      HandleCheck     ;(R1->R0,R1,LR,V)
        BVS     %FT99

        TSTS    R11,#HandleBlkBit
        BEQ     %FT01
        BIC     R11,R11,#HandleBlkBit
        ADD     R10,R1, #FcbExtHandle-NextHandleBlk
        MOV     R9, R10
00
        LDR     R2, [R10,#NextHandleBlk]
        TEQS    R2, R11
        MOVNE   R10,R2
        BNE     %BT00

        LDR     R11,[R2, #NextHandleBlk]
        STR     R11,[R10,#NextHandleBlk]
 [ UseRMAForFCBs
        MOV     R0, #ModHandReason_Free
        BL      OnlyXOS_Module
 |
        MOV     R0, #HeapReason_Free
        BL      OnlySysXOS_Heap         ;(R0,R2->R0,V)
 ]
        CMPS    R9, R10                 ;IF file open more than once       ,V=0
        CMPEQS  R11,#0
        Pull    "R2-R11,PC",NE          ;THEN just return

01
        MOV     Fcb, R1
        LDRB    LR, MaxFileBuffers
        TEQS    LR, #0
        BEQ     %FT10           ;No read ahead/write behind buffers in use
        BL      Flush           ;(R1)

;IF LAST OPEN FILE RELEASE TICKERV

        sbaddr  LR, FirstFcb-FcbNext
02
        LDR     LR, [LR,#FcbNext]
        TEQS    LR, Fcb
        BEQ     %FT03
        LDR     R0, [LR, #FcbExtHandle]
        TEQS    R0, #0
        BEQ     %BT02
        B       %FT08

03
        LDR     LR, [LR,#FcbNext]
        TSTS    LR, #BadPtrBits
        BNE     %FT05
        LDR     R0, [LR, #FcbExtHandle]
        TEQS    R0, #0
        BEQ     %BT03
        B       %FT08

05
        MOV     R0, #TickerV
        ADRL    R1, TickerEntry
        BL      OnlyXOS_Release         ;(R0,R1->R0,V)
 [ DebugJ
        ; Check write behind left on winnie and floppy
        LDR     LR, WinnieProcessBlk
        TST     LR, #BadPtrBits
        LDREQ   LR, [LR, #ProcessWriteBehindLeft]
        MOVNE   LR, #0
        TEQ     LR, #0
        BNE     %FT01
        LDR     LR, FloppyProcessBlk
        TST     LR, #BadPtrBits
        LDREQ   LR, [LR, #ProcessWriteBehindLeft]
        MOVNE   LR, #0
        TEQ     LR, #0
01
        BEQ     %FT10
        MOV     R0, LR
        DREG    R0, "WRITE LEFT:"
        MOV     PC, #SVC_mode
10
 ]

  [ {FALSE}
;AND RETURN FILE BUFFERS TO DIR CACHE

        sbaddr  R0, FileBufsStart
        BL      ClaimFileCache
        ASSERT  FileBufsEnd = FileBufsStart + 4
        LDMIA   R0, {R0,R1}
        BL      LockDirCache
        BL      CheckDirCache
        BL      InvalidateDirCache
        BL      LessValid

        sbaddr  LR, BufChainsRoot
        STR     LR, [LR, #YoungerBuf]
        STR     LR, [LR, #OlderBuf]
        LDRB    LR, MaxFileBuffers
        STRB    LR, UnclaimedFileBuffers
        STR     R1, FileBufsStart

        ASSERT  CacheNext = 0
        ASSERT  CachePriority = 4
        ASSERT  CacheMin = 8
        CMPS    R0, R1
        MOVLO   R2, #bit31
        MOVLO   LR, #bit31
        STMLODB  R1!,{R2,LR}     ;create new rogue end mark

        SUBLO   R2, R1, SB
        MOVLO   LR, #0
        STMLODB  R0!,{R2,LR}

        BL      MoreValid
        BL      ValidateDirCache
        BL      UnlockDirCache
        BL      ReleaseFileCache
  ]

08
        MOV     R1, Fcb
10

        LDMIA   SP, {R2,R3}
        LDRB    R4, [R1,#FcbFlags]
        ; If DiscImage or ~ExtFlag or ~date stamp then skip setting these values
        AND     R0, R4, #FcbDiscImage
        EORS    R0, R0, #FcbDiscImage   ; EQ if FcbDiscImage, NE if not
        ANDNE   R0, R4, #ExtFlag
        ORRNE   R0, R0, R2
        ORRNES  R0, R0, R3
        BEQ     %FT40           ;EXT ensured & date stamp ok - branch must be taken with R0=0 to indicate no error

        BL      GetFilesDir     ;(R1->R0,R3-R6,V)
        BVS     %FT40

        LDR     R0, [SP,#4]     ;update date stamp if necessary
        ORRS    LR, R2, R0
        BEQ     %FT11
        BL      WriteExec       ;(R0,R4)
        MOV     R0, R2
        BL      WriteLoad       ;(R0,R3,R4)

11      BL      ReadLen         ;(R3,R4->LR)
        LDR     R7, [R1,#FcbExtent]
        EORS    R0, R7, LR
        BNE     %FT12

        BL      WriteDir        ;(->R0,V) will ensure new Id if needed
        B       %FT40           ;EXT matches length

12
        LDR     R8, [R1,#FcbAllocLen]
        BL      BeforeAlterFsMap;(R3->R0,V)
        BVS     %FT40

        BL      TestMap         ;(R3->Z)
        BNE     %FT15

        ; New map handling

        ; Load up current IndDiscAdd
        LDR     R2, [R1, #FcbIndDiscAdd]

        MOV     R0, R7
        BL      WriteLen        ;(R0,R3,R4)

        TEQ     R0, #0
        ; If length now 0 then IndDiscAdd = 1, object length to 0, release all buffers
 [ DebugE
        BNE     %FT01
        DLINE   "new length 0"
01
 ]
        MOVEQ   R7, #1          ; new IndDiscAdd
        MOVEQ   R0, #0          ; Old object's new length
        BLEQ    ReleaseAllFcbBuffers ;(r1) drop all buffers having effectively detached them from the file
        BEQ     %FT25           ;and nothing to consider moving

        ; If object was already shared then no conversion on close needed
        TSTS    R2, #&FF        ;don't try to move if was shared
 [ DebugE
        BEQ     %FT01
        DLINE   "was shared"
01
 ]
        MOVNE   R7, R2          ; no change in IndDiscAdd
        BNE     %FT25

        ; Closing an unshared file - try to convert to shared

        Push    "R1,R2,R4-R8"

        BL      CritInitReadNewFs       ;(->R10,R11)
        BL      RoundUpAlloc    ;(R0,R3->R0)
        LDRB    R6, [R10,#ZoneHead+DiscRecord_Log2bpmb]
      [ BigFiles
        TEQ     R0, #RoundedTo4G
        ASSERT  RoundedTo4G = 1
        MOVEQ   R0, R0, ROR R6
        MOVNE   R0, R0, LSR R6
      |
        MOV     R0, R0, LSR R6
      ]
        SUB     R1, R0, #1
        BL      DefFindFragment ;(R1,R2,R10->R1,R9,R11,LR)
        ADD     R4, R1, LR      ;frag end
        ADD     R1, R1, #1
        MOV     R2, R1
        BL      MinMapObj       ;(R10->LR)
        MOV     R5, LR
        SUBS    LR, R1, R11
        CMPHIS  R5, LR
 [ DebugE
        BLS     %FT01
        DLINE   "waste at start"
01
 ]
        ADDHI   R1, R11,R5
        MOV     R11,R9
        BL      NextFree_Quick  ;(R10,R11->R9,R11,Z,C)
        TEQS    R11,R4          ;does next gap join end of frag
 [ BigMaps
        BLEQ    FreeRdLenBits   ;(R10,R11->R7)
 |
        BLEQ    RdLenBits       ;(R10,R11->R7)
 ]
        ADDEQ   R4, R4, R7
        SUBS    LR, R4, R1
        CMPHIS  R5, LR
 [ DebugE
        BLS     %FT01
        DLINE   "waste at end"
01
 ]
        MOVHI   R1, R4
        SUBS    R1, R1, R2              ;necessary wasted map bits
        MOVEQ   R11,#CloseSmall         ;no waste => only move to shared frag
        MOVNE   R11,#CloseContig        ;   waste => only move to contiguous frag
        ADD     R0, R0, R1              ;length to leave allocated in map bits
      [ BigFiles
        MOVS    R9, R0, LSL R6
        MOVCS   R9, #RoundedTo4G
      |
        MOV     R9, R0, LSL R6
      ]
 [ DebugE
      [ BigFiles
        BCC     %FT01
        DLINE   "alloc left = 4G"
        B       %FT02
      ]
01
        DREG    R9,"alloc left = "      ;in bytes
02
 ]
        RSBS    LR, R0, R5, LSL #1      ;IF MinMapObj*2 > Allocation left

        Pull    "R1,R2,R4-R8"

        MOVHI   R0, R7
        BLHI    RoundUpSector           ;(R0,R3->R0)
        TEQHIS  R0 ,R9                  ;AND some allocation wasted
        MOVHI   R11,#CloseSmall         ;THEN convert to shared and only move to shared

 [ DebugE
        BLS     %FT01
        DLINE   "convert to shared obj"
01
 ]
        MOV     R10,R7

        MOV     R7, R2
        ORRHI   R7, R7, #1      ;THEN convert to shared object

        ; Change FcbBufSz to match change to shared object
        BL      DiscAddToRec            ; (R3->LR)
        LDRB    LR, [lr, #DiscRecord_Log2SectorSize]
        MOV     r0, #1
        MOV     r0, r0, ASL lr
        MOV     r0, r0, LSR #BufScale
        STRB    r0, [r1, #FcbBufSz]

        ; Change FcbAllocLen to match change to shared object
        MOV     R0, R10
 [ BigShare
        BL      RoundUpShare    ;(R0,R3->R0) always < 2G for shared
 |
        BL      RoundUpSector   ;(R0,R3->R0) always < 2G for shared
 ]
        STR     R0, [R1, #FcbAllocLen]

        BL      ClaimFreeSpace  ;(R3,R5,R6,R10,R11->R0,R2,V)

        MOVVS   R0, R9
        BVS     %FT25           ;cant find a suitable move

        Push    "R1-R4"
        LDR     R1, [R1,#FcbIndDiscAdd]
        MOV     R3, R10
        BL      DefaultMoveData         ;(R1-R3->R0-R4,V)
        Pull    "R1-R4"
        BVS     %FT30

        ; Changing IndDiscAdd
        MOV     R7, R2
        LDR     R2, [R1, #FcbIndDiscAdd]
        MOV     R0, #0          ;return all old space

        B       %FT25

15
        ; Old map handling
        MOV     R0, R7
        BL      WriteLen        ;(R0,R3,R4)
        TEQ     R0, #0
        LDR     R2, [R1,#FcbIndDiscAdd]
        MOVNE   R7, R2          ; New disc add is old disc add if not freeing whole thing, else ends at 0

25
        ; At this point:
        ; R0 = New length of object R2 in bytes
        ; R1 = Fcb
        ; R2 = IndDiscAdd of object to have space returned from
        ; R3 = dir IndDiscAdd
        ; R4 = dir entry^
        ; R5 = dir start^
        ; R7 = new IndDiscAdd to give to file
        ; R8 = Old allocated length of object R2

        ; Release space from shortened (maybe) or moved elsewhere (to be shared) file
        Push    "R1"
      [ BigFiles
        TEQ     R8, #RoundedTo4G
        MOVEQ   R1, #&FFFFFFFF  ;ReturnSpace rounds up internally anyway
        MOVNE   R1, R8
        TEQ     R0, #RoundedTo4G
        MOVEQ   R0, #&FFFFFFFF  ;R0 can get rounded up calculating the length to leave allocated
      |
        MOV     R1, R8
      ]
        BL      ReturnSpace     ;(R0-R3{also R4,R5 if new map}->R0,V)
        Pull    "R1"
        BVS     %FT30

        MOV     r0, r7
        BL      WriteIndDiscAdd ; (r0,r3,r4)

        ; Keep Fcb up to date with file (only if Fcb is still alive)
        LDR     r0, [r1, #FcbIndDiscAdd]
        CMP     r0, #-1
        STRNE   r7, [r1, #FcbIndDiscAdd]

        BL      WriteDirThenFsMap       ;(->R0,V)

30
        BL      UnlockMap
        MOVVC   R0, #0
40
        MOV     Fcb, R1

        ; Unlock disc in drive to ensure disc doesn't change
        ; whilst we're accessing it (we can't find it again if
        ; it does change because its unidentifyable).
        BL      UnlockUnidentifyableDisc

        LDRB    R4, [Fcb, #FcbDataLostFlag]
        LDRB    R5, [Fcb, #FcbFlags]
        AND     R5, R5, #FcbFloppyFlag
        EOR     R5, R5, #FcbFloppyFlag
        MOV     R7, #0

        MOV     R6, R0
        sbaddr  R10,FirstFcb-FcbNext ;search FCB chain for previous FCB
        B       %FT93
92
        LDRB    R2, [R10,#FcbFlags]     ;count open files on same controller
        AND     R2, R2, #FcbFloppyFlag
        TEQS    R2, R5
        LDRNE   R2, [R10,#FcbExtHandle]
        TEQNES  R2, #0
        ADDNE   R7, R7, #1
93
        LDR     R2, [R10,#FcbNext]
        EORS    R11,R9, R2
        MOVNE   R10,R2
        BNE     %BT92

        BL      ClaimFileCache
        LDR     LR, [R9, #NextInFile]
        CMPS    LR, R9
        LDREQ   LR, [R9, #PrevInFile]
        CMPEQS  LR, R9                  ;EQ <=> no buffers attached to Fcb, V=0
        LDR     R9, [R9, #FcbNext]
        STREQ   R9, [R10,#FcbNext]      ;IF no buffers remove FCB from list
        STRNE   R11,[R2, #FcbExtHandle] ;ELSE mark FCB closed
        BL      ReleaseFileCache
 [ UseRMAForFCBs
        MOVEQ   R0, #ModHandReason_Free
        BLEQ    OnlyXOS_Module
 |
        MOVEQ   R0, #HeapReason_Free
        BLEQ    OnlySysXOS_Heap         ;(R0,R2->R0,V)
 ]
        MOVVS   R6, R0
 [ DebugB
        mess    VS,"Free Heap err"
 ]

        B       %FT95
94
        LDRB    LR, [R9, #FcbFlags]     ;count open files on same controller
        AND     LR, LR, #FcbFloppyFlag
        TEQS    LR, R5
        LDRNE   LR, [R9, #FcbExtHandle]
        TEQNES  LR, #0
        ADDNE   R7, R7, #1
        LDR     R9, [R9,#FcbNext]
95
        CMPS    R9, #-1
        BNE     %BT94
        TEQS    R7, #0
        BNE     %FT96
        LDRB    LR, Interlocks
 [ DebugK
        Push    r0
        MOV     r0, lr
        DREG    r0, "MyCloseFile(1) Interlocks="
        Pull    r0
 ]
        TSTS    R5, #FcbFloppyFlag
        ORREQ   LR, LR, #NoOpenFloppy
        ORRNE   LR, LR, #NoOpenWinnie
        STRB    LR, Interlocks
 [ DebugG
;        mess    EQ, "last floppy",NL
;        mess    NE, "last winnie",NL
 ]
 [ DebugK
        Push    r0
        MOV     r0, lr
        DREG    r0, "MyCloseFile(2) sets Interlocks to "
        Pull    r0
 ]
96
        MOV     R0, R6
        TEQS    R4, #0
        MOVNE   R0, #DataLostErr
        BL      SetVOnR0
99
 [ DebugB
        DLINE   "<MyCloseFile"
        DebugError "  with error:"
 ]
        Pull    "R2-R11,PC"

 LTORG

; ====================
; ReleaseAllFcbBuffers
; ====================

; In
;       r1 = Fcb
;       FileCache not claimed
;
; Out
;       All buffers released from Fcb, [R1, #FcbIndDiscAdd] may well be -1
ReleaseAllFcbBuffers ROUT
        Push    "r3-r5,lr"
        SavePSR r5
 [ DebugB
        DREG    R1, "ReleaseAllFcbBuffers(",cc
        DLINE   ")"
 ]
        MOV     r3, #&ffffffff
        MOV     r4, #0
        BL      ReleaseFcbBuffersInRange
        RestPSR r5,,f
        Pull    "r3-r5,pc"


; ========================
; ReleaseFcbBuffersInRange
; ========================

; In
;       r1 = Fcb
;       r3 = number of bytes
;       r4 = start byte offset within file
;       FileCache not claimed
;
; Out
;       All buffers covered by specified range released from Fcb, [R1, #FcbIndDiscAdd] may well be -1
ReleaseFcbBuffersInRange ROUT
        Push    "R0,R2,R3,BufSz,r6,BufPtr,LR"
        SavePSR lr
        Push    lr
 [ DebugB
        DREG    R1, "ReleaseFcbBuffersInRange(",cc
        DREG    R3, ",",cc
        DREG    R4, ",",cc
        DLINE   ")"
 ]
        ; First ensure there aren't any buffers which are active on this Fcb
        LDRB    lr, [r1, #FcbFlags]
        TST     lr, #FcbFloppyFlag
        LDRNE   r0, FloppyProcessBlk
        MOVNE   lr, #FloppyLock
        LDREQ   r0, WinnieProcessBlk
        MOVEQ   lr, #WinnieLock
        LDRB    r6, Interlocks
        ORR     lr, r6, lr
        STRB    lr, Interlocks

        LDR     lr, [r0, #ProcessFcb]
        TEQ     lr, r1
        BNE     %FT05

        ; Wait for the controller to finish and move buffers as appropriate
        BL      WaitForControllerFree
        BL      UpdateProcess

05
        ; Process quiet or not active on this Fcb

        ADD     r3, r3, r4      ; exclusive top end
        BL      ClaimFileCache
        LDR     R2, = EmptyBuf * &01010101
        MOV     BufPtr, R1
        LDRB    BufSz, [R1, #FcbBufSz]
        B       %FT20
10
        ; If buffer is within range junk it
        LDR     lr, [BufPtr, #BufFileOff]
        CMP     lr, r3          ; If buffer start < transfer end
      [ BigFiles
        BHS     %FT20
        ADD     lr, lr, #1*K
        SUB     lr, lr, #1      ; (generate inclusive buffer end)
        CMP     r4, lr          ; and transfer start <= buffer end Then
        BLLS    UpdateBufState  ;(R2,BufSz,BufPtr) junk the buffer

        ; And back to the list's start
        MOVLS   BufPtr, R1
      |
        ADD     lr, lr, #1*K    ; (generate exclusive buffer end)
        CMPLO   r4, lr          ; and transfer start < buffer end Then
        BLLO    UpdateBufState  ;(R2,BufSz,BufPtr) junk the buffer

        ; And back to the list's start
        MOVLO   BufPtr, R1
      ]
20
        LDR     BufPtr, [BufPtr, #NextInFile]
        TEQS    BufPtr, R1
        BNE     %BT10
        BL      ReleaseFileCache

        STRB    r6, Interlocks

        Pull    lr
        RestPSR lr,,cf
        Pull    "R0,R2,R3,BufSz,r6,BufPtr,PC"

        LTORG

; ==============
; CloseAllByDisc
; ==============

; close all files (on a given disc)

; entry R1=disc, if R1=8 all discs

; exit IF error V set, R0 result

CloseAllByDisc ROUT
        Push    "R1,R2,R5-R9,LR"
 [ DebugBc
        DREG    R1, ">CloseAllByDisc(",cc
        DLINE   ")"
 ]
        MOV     R6, R1
        MOV     R7, #0
        sbaddr  R8, FirstFcb-FcbNext
10
        LDR     R9, [R8,#FcbNext]
 [ DebugBc
        DREG    r8, "Rover is ",cc
        DREG    r9, " Next is "
 ]
        TSTS    R9, #BadPtrBits
        MOVNE   R0, R7
        BLNE    SetVOnR0
 [ DebugBc
        BEQ     %FT01
        DREG    R0, "<CloseAllByDisc(",cc
        DLINE   ")"
01
 ]
        Pull    "R1,R2,R5-R9,PC",NE   ;EXIT HERE
        CMPS    R6, #8
        LDRNE   LR, [R9,#FcbDir]
        TEQNES  R6, LR, LSR #(32-3)
        MOVNE   R8, R9          ;EQ <=> close this file
        BNE     %BT10

        LDR     R2, [R9, #FcbExtHandle]
        CMPS    R2, #NotHandle
        BLO     %FT16

        LDR     R5, [R2, #NextHandleBlk]
        MOV     R0, #0
        LDR     R1, [R2, #ExtHandle]
 [ DebugBc
        DREG    r1, "Close Multi "
 ]
        BL      DoXOS_OsFind    ;THEN close (R0,R1->R0,V) preserves Z
        BVC     %FT14
        TEQS    R7, #0
        MOVEQ   R7, R0
        MOVNE   R7, #MultipleCloseErr
14
        LDR     LR, [R9, #FcbExtHandle]
        TEQS    LR, R5                  ;IF close failed to remove from handle chain
        STRNE   R5, [R9, #FcbExtHandle] ;THEN remove from chain
 [ UseRMAForFCBs
        MOVNE   R0, #ModHandReason_Free
        BLNE    OnlyXOS_Module
 |
        MOVNE   R0, #HeapReason_Free
        BLNE    OnlySysXOS_Heap         ;and return to heap (R0,R2->R0,V)
 ]
        B       %BT10

16
        MOVS    R1, R2          ;IF this FCB not for an open file
 [ DebugBc
        BEQ     %FT01
        DREG    r1, "Close single "
        B       %FT02
01
        DREG    r9, "Close unopenned "
02
 ]
        BLEQ    FreeFcb         ;THEN free (R8,R9->R0,V) preserves Z
        MOVNE   R0, #0
        BLNE    DoXOS_OsFind    ;THEN close (R0,R1->R0,V)
        BVC     %FT20
        TEQS    R7, #0
        MOVEQ   R7, R0
        MOVNE   R7, #MultipleCloseErr
20
        LDR     LR, [R8,#FcbNext]
        TEQS    LR, R9           ;IF close has failed to remove from FCB chain
        BNE     %BT10
 [ DebugBc
        DLINE   "Close failed - force flush and close"
 ]
        MOV     R1, R9
        BL      Flush           ;(R1)
        BL      FreeFcb         ;THEN free (R8,R9->R0,V)
        B       %BT10


 MACRO
        OsArgsEntry  $name
 [ "$name"<>"Bad"
        ASSERT  {PC}-OsArgsJump-8=fsargs_$name*4
 ]
        B       DoOsArgs$name
 MEND

; >>>>>>>>>>>
; OsArgsEntry
; >>>>>>>>>>>

OsArgsEntry ROUT
        SemEntry  Flag          ;allow reentrance, leaves R12,LR stacked
 [ DebugB
        DREG    R0, "OsArgsEntry(",cc
        DREG    R1, ",",cc
        DREG    R2, ",",cc
        DREG    R3, ",",cc
        DLINE   ")"
 ]
        Push    "R3-R11"
        BL      HandleCheck     ;(R1->R0,R1,LR,V)
        BVS     OsArgsExit3
        LDRB    LR, [R1, #FcbDataLostFlag]         ;CHECK FOR DATA LOST
        TEQS    LR, #0
        MOVNE   R0, #DataLostErr
        BNE     OsArgsExit2
        LDR     R7, [R1,#FcbAllocLen]
        LDR     R8, [R1,#FcbIndDiscAdd]
        LDRB    R10,[R1,#FcbFlags]
        CMPS    R0, #FirstUnknown_fsargs
OsArgsJump
        ADDCC   PC, PC, R0, LSL #2
        B       DoOsArgsBad

        OsArgsEntry  Bad         ;0
        OsArgsEntry  Bad         ;1
        OsArgsEntry  Bad         ;2
        OsArgsEntry  SetEXT      ;3
        OsArgsEntry  Bad         ;4
        OsArgsEntry  Bad         ;5
        OsArgsEntry  Flush       ;6
        OsArgsEntry  EnsureSize  ;7
        OsArgsEntry  WriteZeroes ;8
        OsArgsEntry  ReadLoadExec;9
        OsArgsEntry  ImageStampIs;10
        ASSERT  {PC}-OsArgsJump-8=FirstUnknown_fsargs*4

DoOsArgsBad ROUT
 [ DebugB
        DLINE   "Bad OsArgs"
 ]
        MOV     R0, #BadParmsErr
        B       OsArgsExit2

DoOsArgsSetEXT ROUT
 [ DebugB
        DREG    R1, "OsArgs SetExt(",cc
        DREG    R2, ",",cc
        DLINE   ")"
 ]
      [ BigFiles
        TEQ     R7, #RoundedTo4G
        MOVEQ   R7, #&FFFFFFFF  ;near enough for 'HI' comparison purposes
      |
        MOVS    R2, R2
        MOVMI   R0, #FileTooBigErr
        BMI     OsArgsExit2
      ]
        CMPS    R2, R7
        MOVHI   R0, #BadParmsErr
        BHI     OsArgsExit2
        ORR     R10,R10,#ExtFlag
        STRB    R10,[R1,#FcbFlags]
        STR     R2, [R1,#FcbExtent]
        B       OsArgsExit1

DoOsArgsFlush ROUT
 [ DebugB
        DREG    R1, "OsArgs Flush(",cc
        DLINE   ")"
 ]
        BL      Flush   ;(R1)
        LDRB    R0, [R1, #FcbDataLostFlag]
        TEQS    R0, #0
        MOVNE   R0, #DataLostErr
        B       OsArgsExit2

DoOsArgsEnsureSize ROUT
 [ DebugB :LOR: DebugBe
        DREG    R1,"OsArgs CheckSize(",cc
        DREG    R2, ",",cc
        DREG    R3, ",",cc
        DLINE   ")"
 ]
      [ BigFiles
        TEQ     R7, #RoundedTo4G
        MOVEQ   R7, #&FFFFFFFF  ;near enough for 'LS' comparison purposes
      ]
        CMPS    R2, R7
        BLS     OsArgsExit1     ;ok if no bigger than present allocation

        TST     R10, #FcbDiscImage
        MOVNE   R0, #NotToAnImageYouDontErr
        BNE     OsArgsExit2

        BL      GetFilesDir     ;(R1->R0,R3-R6,V)
      [ BigFiles
        BL      TestMap         ;(R3->Z)
        BEQ     %FT65
      ]
        MOVS    R2, R2
        MOVMI   R0, #FileTooBigErr      ; Cheap exit, old map must be < 2G
        BMI     OsArgsExit2
65
        BLVC    BeforeAlterFsMap        ;(R3->R0,V)
        BVS     OsArgsExit3
        BL      TestMap         ;(R3->Z)
        BNE     %FT70

        ; New map
        TSTS    R8, #&FE        ;IF in shared frag and not at start
        BNE     %FT90
        TEQS    R7, #0          ;           OR length 0
        Push    "R2"
        LDRNE   R2, [R1,#FcbIndDiscAdd]
        BLNE    ReallyShared    ;(R2-R5->Z) OR frag shared by another obj
        Pull    "R2"
        BEQ     %FT90           ;do extend by moving

        TSTS    R8, #1          ;If alone at start of shared frag convert to non shared
        BICNE   R0, R8, #&FF
        BLNE    WriteIndDiscAdd ;(R0,R4)
        MOV     R10,R2
        MOV     R11,#RandomAccessExtend
        LDR     R0, [SP]        ;old extent according to fileswitch
        BL      ClaimFreeSpace  ;(R0,R3,R4,R10,R11->R0,R2,R10,V)
        BVS     %FT85
        MOV     R7, R2   ;ind disc add
        MOV     R2, R10  ;on disc length
        B       %FT80
70
        ; Old map case
        ADD     R0, R8, R7                ;SEARCH FOR SPACE FOLLOWING FILE
 [ DebugB :LOR: DebugBe
        DLINE   "new size|old size|file add|file end"
        DREG    R2,,cc
        DREG    R7,,cc
        DREG    R8,,cc
        DREG    R0
 ]
        BL      InitReadOldFs           ;(R3->R9-R11)
75
        BL      NextOldFs               ;(R3,R10,R11->R7,R8,R10,R11,Z)
        BEQ     %FT90                   ;spaces exhausted
 [ DebugB :LOR: DebugBe
        DLINE   "free length, free disc add ",cc
        DREG    R7,,cc
        DREG    R8
 ]
        CMPS    R8, R0                  ;loop if earlier space
        BLO     %BT75                   ;loop
        BHI     %FT90

;here if space following file found

        LDR     LR, [R1,#FcbAllocLen]
        ADD     R8, R8, R7              ;end of possible extension
        ADD     R7, R7, LR              ;old length+possible extension
 [ DebugB :LOR: DebugBe
        DLINE   "total length, end disc add "
        DREG    R7,,cc
        DREG    R8
 ]
        CMPS    R2, R7
        BHI     %FT90

        SUB     LR, R7, R2              ;spare length
 [ DebugB :LOR: DebugBe
        Push    r0
        MOV     r0, LR
        DREG    r0, "spare len="
        Pull    r0
 ]
        SUB     R10,R10,#3
        ADD     R11,R11,#3
        CMPS    LR, #&10000
        MOVLS   R2, R7                  ;IF <=64K spare
        BLLS    RemoveOldFsEntry        ; use all spare (R3,R9-R11)
        ADDHI   R2, R2, #&10000         ;ELSE
        BICHI   R2, R2, # &00FF         ; round length up to next 64K boundary
        BICHI   R2, R2, # &FF00
        SUBHI   R7, R7, R2              ; unused length
        SUBHI   R8, R8, R7              ; start of shortened space
 [ DebugB :LOR: DebugBe
        DREG    R2,"new size|gap size|gap disc add",cc
        BLS     %FT01
        DREG    R7,,cc
        DREG    R8,,cc
01
        DLINE   ""
 ]
        BLHI    WriteOldFsEntry         ;(R3,R7,R8,R10)
        LDR     R7, [R1,#FcbIndDiscAdd]
80
        MOV     R8, R2                  ;internal allocation
      [ BigFiles
        TEQ     R2, #RoundedTo4G
        MOVEQ   R2, #&FFFFFFFF          ;Saturate on external interfaces
      ]
        MOV     R0, R2
 [ DebugB :LOR: DebugBe
        DREG    R0,"New length = "
 ]
        BL      WriteLen                ;(R0,R3,R4)
        MOV     R0, R7
        BL      WriteIndDiscAdd         ;(R0,R3,R4)
        BL      WriteFsMapThenDir       ;(->R0,V)
        LDRVCB  LR, [R1,#FcbFlags]
        ORRVC   LR, LR, #ExtFlag
        STRVCB  LR, [R1,#FcbFlags]
        STRVC   R8, [R1,#FcbAllocLen]
        STRVC   R7, [R1,#FcbIndDiscAdd]
85
        BL      UnlockMap
 [ DebugB :LOR: DebugBe
        DLINE   "Leaving ensure size"
        CPBs
 ]
        B       OsArgsExit3

90
 [ DebugB :LOR: DebugBe
        DLINE   "Try extend by moving"
 ]
        MOV     R10,R2          ;size
        MOV     R11,#RandomAccessCreate
        BL      ClaimFreeSpace  ;(R3,R10,R11->R0,R2,R10,V)
        BVS     %BT85
        MOV     R7, R2

        Push    "R3,R4"
        MOV     R8, R1          ;->fcb

        LDR     R1, [R8,#FcbIndDiscAdd] ;source
        MOV     R2, R7                  ;dest
        LDR     LR, [R8,#FcbAllocLen]   ;old allocated length
      [ BigFiles
        TEQ     LR, #RoundedTo4G
        MOVEQ   LR, #&FFFFFFFF          ;near enough for 'HI' comparison purposes
      ]
        LDR     R3, [SP,#2*4]           ;old extent according to fileswitch
        CMPS    R3, LR
        MOVHI   R3, LR                  ;SHOULD NEVER HAPPEN
        BL      DefaultMoveData         ;(R1-R3->R0-R4,V)

        LDMVCFD SP, {R3,R4}
        LDRVC   R1, [R8,#FcbAllocLen]
        LDRVC   R2, [R8,#FcbIndDiscAdd]
      [ BigFiles
        TEQ     R1, #RoundedTo4G
        MOVEQ   R1, #&FFFFFFFF          ;ReturnWholeSpace rounds up internally anyway
      ] 
        BLVC    ReturnWholeSpace        ;(R1-R3 [,R4,R5 IF new map ]->R0,V)

        Pull    "R3,R4"
        MOV     R1, R8
        MOVVC   R2, R10
        BVC     %BT80
        B       %BT85

DoOsArgsWriteZeroes ROUT
 [ DebugB
        DREG    R1,"OsArgs Write0s(",cc
        DREG    R2, ",",cc              ;is FileSwitch buffer aligned
        DREG    R3, ",",cc              ;a FileSwitch buffer multiple
        DLINE   ")"
 ]
      [ BigFiles
        TEQ     R7, #RoundedTo4G
        MOVEQ   R7, #&FFFFFFFF
        ADDS    LR, R3, R2
        BCC     %FT05                   ;no carry out, proceed with comparison
        CMP     LR, #1                  ;allow carry out of only 4G exactly
        MOVCC   LR, R7                  ;LR <=> 0, C=0, be sure to pass the test
05
      |
        ADDS    LR, R3, R2
      ]
        SUBCC   LR, LR, #1
        CMPCCS  LR, R7
        MOVCS   R0, #BadParmsErr
        BCS     OsArgsExit2

        MOV     Fcb, R1
        LDRB    R0, [Fcb, #FcbFlags]
        TSTS    R0, #FcbFloppyFlag
        LDRNE   R0, FloppyProcessBlk
        LDREQ   R0, WinnieProcessBlk
        MOV     R4, R3
        MOV     R3, R8
        BL      DiscWriteBehindWait             ;(R3)
        MOV     R3, R4
        BL      ClaimController         ;(R0)
        BL      WaitForControllerFree   ;(R0)
        LDRB    BufSz, [Fcb, #FcbBufSz]
        MOV     FileOff, R2
      [ BigFiles
        CMP     FileOff, #-1*K          ; Start point is in the write behind dead-band
        BCS     %FT10
        ADDS    TransferEnd, FileOff, R3
        CMPCC   TransferEnd, #-1*K
        LDRCS   TransferEnd, =-1*K      ; End point clamped to dead-band
      |
        ADD     TransferEnd, FileOff, R3
      ]
        BL      ClaimFileCache
        BL      EmptyBuffers    ;R0,BufSz,FileOff,TransferEnd,Fcb->BufOff,BufPtr
        BL      ReleaseFileCache
10
        MOV     R4, R0

        MOV     R7, R2                  ;start offset
        MOV     R9, R3                  ;length
        BL      WriteZeroes             ;(R7-R9->R0,V)

        MOV     R5, R0
        MOV     R0, R4
        BL      ReleaseController       ;(R0)
        MOV     R0, R5

        B       OsArgsExit3

DoOsArgsImageStampIs ROUT
        MOV     r5, r8, LSR #(32-3)
        DiscRecPtr r5, r5
        LDRB    lr, [r5, #DiscFlags]
        TST     lr, #DiscNotFileCore
        BEQ     OsArgsExit1             ; No it isn't!

        ; Non-filecore disc - set the DiscId from the supplied value
 [ DebugLi
        Push    "r0"
        MOV     r0, r8, LSR #(32-3)
        DREG    r0, "ImageStampIs: Disc ID on disc ",cc
        DREG    r2, " is "
        Pull    "r0"
 ]
        STRB    r2, [r5, #DiscRecord_DiscId+0]
        MOV     r2, r2, LSR #8
        STRB    r2, [r5, #DiscRecord_DiscId+1]
        B       OsArgsExit1

DoOsArgsReadLoadExec ROUT
 [ DebugB
        DREG    R1,"OsArgs ReadLoadExec(",cc
        DLINE   ")"
 ]
; Osargs Read Load & Exec
; exit R2 load R3 exec
        ; GetFilesDir will return R3=Object and R4=0 for disc images
        BL      GetFilesDir             ;(R1->R0,R3-R6,V)
        BVS     OsArgsExit3
        BL      ReadLoad                ;(R3,R4->LR)
        MOV     R2, LR
        BL      ReadExec                ;(R4->LR)
        MOV     R3, LR

OsArgsExit1
        MOV     R0, #0
OsArgsExit2
        BL      SetVOnR0
OsArgsExit3
 [ DebugB
        DREG    R0,"OsArgsEntry done(",cc
        DREG    R1, ",",cc
        DREG    R2, ",",cc
        DREG    R3, ",",cc
        DLINE   ")"
        DebugError "OsArgsExit3 error"
 ]
        BLVS    FindErrBlock    ; (R0->R0,V)
        BL      FileCoreExit
        ADD     SP,SP,#4        ;throw away stacked R3 on entry
        Pull    "R4-R11,SB,PC"


; ===========
; WriteZeroes
; ===========

; write zeroes to a file

; entry
;  R7 start offset
;  R8 Ind Disc Address of file
;  R9 length, NON ZERO MULTIPLE OF ALLOCATION SIZE

; exit IF error V set, R0 result

WriteZeroes ROUT
 [ DebugB :LOR: DebugBA
        DLINE   "beg off |file add|length - WriteZeroes"
        DREG    R7,,cc
        DREG    R8,,cc
        DREG    R9
 ]
        ASSERT  ?ScratchSpace >= 2*1024
        ASSERT  ?ScratchSpace :MOD: 8 = 0
        Push    "R1-R9,LR"
10
        MOV     R3,R8
 [ {TRUE}
        BL      ReadAllocSize   ;(R3->LR)
15      ; SBP: fix to make this work when Bytes per map bit very large - reduces chunk
        ; size if too large
        CMPS    LR, #?ScratchSpace/4
        MOVHI   LR, LR, LSR #1
        BHI     %BT15
 |
        BL      ReadAllocSize   ;(R3->LR)
 ]
        MOV     R4,#0
20
        ADD     R4,R4,LR                ;increase length of zeroes
        CMPS    R4,#?ScratchSpace/2     ;until it fills half of buffer
        CMPLOS  R4,R9                   ;or long enough
        BLO     %BT20

        LDR     R0,=ScratchSpace
        MOV     R1,R4
        BL      ZeroRam
                                 ;form (address,length) pairs
        MOV     R6,#0
        ADD     R1,R0,R4                ;start of (address,length) pairs
        MOV     R3,R1
        ADD     R2,R0,#?ScratchSpace ;buffer end
30
 [ DebugBA
        DREG    r0, "A/L=",cc
        DREG    r4, ",",cc
        DREG    r1, " at "
 ]
        STMIA   R1!,{R0,R4}
        ADD     R6,R6,R4        ;increase effective length by length of zeroes
        CMPS    R6,R9
        MOVHS   R6,R9
        CMPLOS  R1,R2
        BLO     %BT30           ;loop until enough or scatterlist buffer full

        MOV     R1, #DiscOp_WriteSecs :OR: DiscOp_Op_ScatterList_Flag :OR: DiscOp_Op_IgnoreEscape_Flag
        MOV     R2, R8
        MOV     R4, R6
        MOV     R5, R7
 [ DebugBA
        DREG    R1, "GenIndDiscOp(",cc
        DREG    r2, ",",cc
        DREG    r3, ",",cc
        DREG    r4, ",",cc
        DREG    r5, ",",cc
        DLINE   ")"
 ]
        BL      GenIndDiscOp   ;(R1-R5->R0-R5)
        BVS     %FT95
        ADD     R7, R7, R6
        SUBS    R9, R9, R6
        BNE     %BT10           ;loop if more zeroes
95
 [ DebugB :LOR: DebugBA
        DebugError "Write0s error"
        DLINE   "leave WriteZeroes"
 ]
        Pull    "R1-R9,PC"


; ===========
; HandleCheck
; ===========

; check handle from fileswitch is valid

; entry R1 = handle

; exit
;  IF R1 -> handle block then R1 replaced by relevant Fcb
;  if good V=0, R0 preserved, LR -> next earlier fcb in chain
;  if bad  V=1, R0 ChannelErr

HandleCheck ROUT
        Push    "R2,LR"
 [ DebugB
        DREG    R1,">HandleCheck(",cc
        DLINE   ")"
 ]
        TSTS    R1, #HandleBlkBit
        BICNE   R1, R1, #HandleBlkBit
        LDRNE   R1, [R1,#HandleBlkFcb]
        sbaddr  LR, FirstFcb-FcbNext
10
        LDR     R2, [LR,#FcbNext]
        TSTS    R2, #BadPtrBits
        MOVNE   R0, #ChannelErr
        BLNE    SetV
        BNE     %FT20   ;bad V=1
        CMPS    R2, R1
        MOVNE   LR, R2
        BNE     %BT10
20
 [ DebugB
        BVC     %FT01
        DLINE   "Bad handle"
01
 ]
 [ DebugB
        DREG    R1,"<HandleCheck(",cc
        MOV     R2, LR
        DREG    R2,",",cc
        DLINE   ")"
 ]
        Pull    "R2,PC"


; ===========
; GetFilesDir
; ===========

; get an open file's dir to the buffer

; entry R1=file handle

; exit
;  IF error V set, R0 result
;  R3 dir ind disc address
;  R4 ->dir entry
;  R5 ->dir start
;  R6 ->dir end

; For the root object when treated as a file to work correctly this will
; return R3=Object ind disc address and R4=0 in this case.

GetFilesDir ROUT
 [ DebugB
        DREG    R1,"Get files dir(",cc
        DLINE   ")"
 ]
        Push    "R1,R2,R7,LR"
        LDRB    LR, [R1, #FcbFlags]
        TST     LR, #FcbDiscImage
        LDRNE   R3, [R1, #FcbIndDiscAdd]
        MOVNE   R4, #0
        BLNE    ClearV                  ; V=0
        BNE     %FT95

        ASSERT  NameLen<12
        LDR     R3, [R1,#FcbDir]
        BL      GetDir          ;(R3->R0,R5,R6,V)
        BVS     %FT95
        ADD     R1, R1, #FcbName
        MOV     R2, #MustBeFile
 [ BigDir
        BL      GetDirFirstEntry        ; (R3,R5->R4)
        BL      TestBigDir
        BNE     %FT01
        ADDS    R0, R0, #0              ; C=0, V=0
        BL      LookUpBigDir            ; (R1-R4,C->R4,Z,C)
        B       %FT02
01
        ADDS    R0, R0,#0               ; C=0, V=0
        BL      LookUp                  ; (R1-R4,C->R4,Z,C)
02
 |
        ADDS    R4, R5, #DirFirstEntry  ;also C=0, V=0
        BL      LookUp          ;(R1-R4,C->R4,Z,C)
 ]

        LDR     R1, [SP]                        ;check FCB matches dir
        LDREQ   R7, [R1,#FcbIndDiscAdd]
        BLEQ    ReadIndDiscAdd                  ;(R3,R4->LR)
        TEQEQS  R7, LR
        MOVNE   R0, #WorkspaceErr
        BLNE    SetV
95
 [ DebugB
        DLINE   "Dir     |Entry   |Dir Beg |Dir End |result - leave GetFilesDir"
        DREG    R3,,cc
        DREG    R4,,cc
        DREG    R5,,cc
        DREG    R6
        DebugError "GetFilesDir error"
 ]
        Pull    "R1,R2,R7,PC"


; =========
; OpenCheck
; =========

; Check if file is open

; entry:
;  R3 =  ind disc add of file
;  R4 -> dir entry

 [ BigDir
; if it's a Big dir then R5->dir
 ]


; exit: IF open R8 -> previous FCB, R9 -> FCB ,Z=0 , R0 error code
;       ELSE    R8 corrupt,         R9=-1     ,Z=1 , R0 =0

OpenCheck ROUT
        Push    "R1,R2,R5-R7,R10,LR"
 [ DebugB
        DREG    R3,"OpenCheck(",cc
        DREG    R4, ",",cc
        DLINE   ")"
 ]
        BL      ReadIndDiscAdd  ;(R3,R4->LR)
        MOV     R10,LR
        BL      TestDir         ;(R3->LR,Z)
        MOVEQ   R5, #&FF
        MOVNE   R5, #&7F
        sbaddr  R8, FirstFcb-FcbNext
        B       %FT10
05
        MOV     R8, R9
10
        LDR     R9, [R8,#FcbNext];get next FCB
        CMPS    R9, #-1
        BEQ     %FT90           ;file matches no FCB so not open, return EQ
        LDR     R6, [R9, #FcbIndDiscAdd]
        CMPS    R6, #-1
        BLEQ    FreeFcb         ;(R8,R9->R0,V) ignore error, preserves Z
        BEQ     %BT10
        TEQS    R6, R10
        LDREQ   R6, [R9,#FcbDir]
        TEQEQS  R6, R3
        BNE     %BT05           ;loop if dir mismatch
        ADD     R1, R9, #FcbName
 [ BigDir
 [ DebugB
        DSTRING R1, "fcbname:"
 ]
        BL      TestBigDir      ;(R3->LR,Z)
        BNE     %FT50

 [ DebugB
        DLINE   "big dir"
 ]

        LDR     R5, [SP, #8]    ; get back dir ptr
        Push    "R4"
        LDR     R6, [R4, #BigDirObNameLen]
        BL      GetBigDirName
        MOV     R4, LR
        MOV     R5, #&ff        ; mask always ff for big dirs
        BL      BigLexEqv       ; is it a match?
        Pull    "R4"
        B       %FT60
50
        BL      LexEqv
60
 |
        ASSERT  FcbAllocLen=FcbName+NameLen   ;for 0 terminator
        BL      LexEqv          ;(R1,R4,R5->C,Z)
 ]
        BNE     %BT05           ;loop if names mismatch
        TEQS    PC, #0          ;return NE if match

90
        MOVNE   R0, #OpenErr
        MOVEQ   R0, #0
 [ DebugB
        BNE     %FT01
        DLINE   "not open"
        B       %FT02
01
        DREG    R9,"FCB exists = "
02
 ]
        Pull    "R1,R2,R5-R7,R10,PC"


; ================
; HasDiscOpenFiles
; ================

; entry: R0 = disc number
; exit:  Z=1 <=> open files on disc

HasDiscOpenFiles ROUT
        Push    "R1,LR"
 [ DebugB
        DREG    R0, "HasDiscOpenFiles(",cc
        DLINE   ")"
 ]
        sbaddr  LR, FirstFcb-FcbNext
10
        LDR     LR, [LR,#FcbNext]       ;get next FCB
        TSTS    LR, #BadPtrBits
        BNE     %FT90
        LDR     R1, [LR, #FcbExtHandle]
        TEQS    R1, #0
        BEQ     %BT10
        LDR     R1, [LR,#FcbIndDiscAdd]
        MOV     R1, R1, LSR #(32-3)
        TEQS    R1, R0
        BNE     %BT10           ;loop if file not on this disc
90
 [ DebugB
        BEQ     %FT01
        DLINE   "disc has no open files"
        B       %FT02
01
        DLINE   "disc has open files"
02
 ]

        Pull    "R1,PC"

        LTORG
        END
