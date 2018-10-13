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
;>FileCore80


        TTL     "FileCore80 - random access file cache"

; >>>>>>>>>>>>>
; GetBytesEntry
; >>>>>>>>>>>>>

; entry:
;  R1   file handle
;  R2   start RAM address (no alignment guarantee)
;  R3   number of bytes to read (FileSwitch buffer multiple)
;  R4   file address (FileSwitch buffer multiple)

; exit:
;  R1-R4 ?
; V clear
;  R0   ?
; V set
;  R0   -> error block

GetBytesEntry ROUT
        SemEntry  Flag          ;allow reentrance, leaves R12,LR stacked
 [ DebugB :LOR: DebugBE
        DLINE   "handle  ,start   ,length  ,file ptr >GetBytesEntry"
        DREG    R1,,cc
        DREG    R2,,cc
        DREG    R3,,cc
        DREG    R4
 ]
 [ DebugBt
        DLINE   ">G",cc
 ]
 [ Debug3L
        DLINE   "G",cc
 ]
        Push    "R5-R11"
        BL      HandleCheck     ;(R1->R0,R1,LR,V)
        BVS     %FT00

      [ BigFiles
        ; If transfer ends at exactly 4G, use foreground
        ; If transfer ends near 4G, use foreground
        ADDS    R5, R3, R4
        CMPCC   R5, #-1*K
        BCS     %FT03
      ]
      [ BigSectors
        ; If sector size larger than buffer size, use foreground
        LDRB    R5, [r1, #FcbBufSz]
        CMP     R5, #1*K :SHR: BufSz
        BHI     %FT03
      ]
        ; Do in background if got some file buffers
        LDRB    R5, MaxFileBuffers
        TEQS    R5, #0
        BNE     %FT05
03
        ; Foreground
        MOV     R5, R4
        MOV     R4, R3
        MOV     R3, R2
        LDR     R2, [R1,#FcbIndDiscAdd]
        MOV     R1, #DiscOp_ReadSecs :OR: DiscOp_Op_IgnoreEscape_Flag
        BL      GenIndDiscOp    ;(R1-R5->R0-R5,V)
00
        BLVS    FindErrBlock    ; (R0->R0,V)
        BL      FileCoreExit
 [ Debug3L
        DLINE   "g",cc
 ]
 [ DebugBt
        DLINE   " <G"
 ]
 [ DebugB :LOR: DebugBE
        DLINE   "<GetBytes"
        DebugError "GetBytes error"
 ]
        Pull    "R5-R11,SB,PC"

;Stack workspace for read buffers

                ^ 0
PendingReadStart # 4
PendingReadEnd  # 4
ReadRamAdjust   # 4
ReadDiscRec     # 4
ReadCylLength   # 4             ;bytes per cylinder [BigDisc it's sectors]
ReadProcessBlock  # 4
LastDiscAdjust  # 4
LastType        # 4
TrkReadAheadLimit * LastType    ;shared
LastEnd         # 4
SeqReadAheadLimit * LastEnd     ;shared
LastStart       # 4
ReadBuffersWork # 0

; R1 FCB
; R2 RAM PTR
; R3 LENGTH
; R4 FILE PTR
; LR PREVIOUS FCB
05
        MOV     R8, LR
 [ DebugJ
        BL      Check
 ]
 [ DebugH
        DLINE   "R ",cc         ;Read
        DREG    R4,,cc
 ]

        MOV     R0, #1
        BL      GetPutCommon ;R0-R4->R0,R2,R3,BufSz,FileOff,R6,TransferEnd,Fcb,R10,Z,V
        BVS     %BT00
 [ DebugB
        CPBs
 ]

        LDRB    R11,[R6,#DiscRecord_SecsPerTrk]
        LDRB    LR, [R6,#DiscRecord_Heads]
 [ BigDisc
        MUL     LR, R11,LR      ; sectors per cylinder
 |
        MOV     R11,R11,LSL R10
        MUL     LR, R11,LR      ; bytes per cylinder - need to change to sectors?
 ]

        ; Build read buffers workspace on the stack
        MOV     R1, #0
        STR     R1, DirectError
        MOV     R1, #bit31      ; LastType = NOP
        ASSERT  LastType > ReadProcessBlock
        STR     R1, [SP,#LastType-ReadBuffersWork] !
        STR     R0, [SP,#ReadProcessBlock-LastType] !
        MOV     R1, #bit1       ; PendindReadEnd

        ASSERT  PendingReadEnd = 4
        ASSERT  ReadRamAdjust = PendingReadEnd+4
        ASSERT  ReadDiscRec = ReadRamAdjust+4
        ASSERT  ReadCylLength = ReadDiscRec+4
        Push    "R0-R2,R6,LR"   ; note R0 is junk value for PendingReadStart

;DEAL WITH SEQUENTIAL / NON SEQUENTIAL
        BL      ClaimFileCache
        LDRB    R1, [Fcb,#FcbFlags]
        AND     LR, R1, #Sequential
        CMP     LR, #0                  ;C<=>sequential
        LDR     LR, [Fcb,#FcbLastReadEnd]
        TEQS    LR, FileOff             ;does read start = last end ?
        BEQ     %FT14                   ;yes, so it can be sequential
        BCC     %FT16                   ;no, and CC, it wasn't sequential previously anyway

;HERE WHEN CONVERTING A FILE FROM SEQUENTIAL TO NON SEQUENTIAL
 [ DebugG
        DLINE   "end sequential"
 ]
        BIC     R1, R1, #Sequential
        STRB    R1, [Fcb,#FcbFlags]

;move position of Fcb in chain to be after all sequential files
        LDR     R1, [Fcb, #FcbNext]
        MOV     R2, Fcb                 ;will be last sequential
        MOV     R10,R1                  ;will be first non sequential
08
        CMPS    R10,#-1
        LDRNEB  LR, [R10,#FcbFlags]
        TSTNES  LR, #Sequential
        MOVNE   R2, R10
        LDRNE   R10,[R10,#FcbNext]
        BNE     %BT08

        TEQS    R2, Fcb                 ;nothing to do if already last sequential
        STRNE   R1, [R8, #FcbNext]
        STRNE   R10,[Fcb,#FcbNext]
        STRNE   Fcb,[R2, #FcbNext]

        LDR     R8, =AwaitsSeqRead*&1010101
        MOV     BufPtr, Fcb
        BL      LessValid
        B       %FT12
10
        LDR     R2, [BufPtr,#BufFlags]
        ANDS    LR, R2, R8                      ;convert any sub buffers awaiting
        ASSERT  NormalBuf=AwaitsSeqRead :SHR: 1 ;sequential read to normal
        SUBNE   R2, R2, LR, LSR #1
        BLNE    UpdateBufState  ;R2,BufSz,BufPtr
12
        LDR     BufPtr, [BufPtr,#NextInFile]
        TEQS    BufPtr, Fcb
        BNE     %BT10   ;loop if more buffers for this file

        BL      MoreValid
        LDRB    R8, [Fcb,#FcbRdAheadBufs]        ;halve read ahead
        MOVS    R8, R8, LSR #1
        STRNEB  R8, [Fcb,#FcbRdAheadBufs]
        B       %FT16

14
;READ AHEAD (BECOMES) SEQUENTIAL
        ORRCC   R1, R1, #Sequential
        STRCCB  R1, [Fcb,#FcbFlags]

        sbaddr  R6, FirstFcb-FcbNext    ;promote to start of Fcb chain if sequential
        TEQS    R6, R8                  ;already at start ?
        LDRNE   R1, [R6, #FcbNext]
        LDRNE   LR, [Fcb,#FcbNext]
        STRNE   LR, [R8, #FcbNext]
        STRNE   R1, [Fcb,#FcbNext]
        STRNE   Fcb,[R6, #FcbNext]

16
;CHECK IF WE HAVE WHOLE READ ALREADY CACHED
 [ DebugB
        CPBs
 ]
        MOV     R6, FileOff
        LDR     BufPtr,[Fcb,#PrevInFile]
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        MOV     FragEnd, TransferEnd
        BL      ScanBuffers     ;FileOff,FragEnd,BufSz,BufOff,BufPtr->FileOff,BufOff,BufPtr, LO/EQ/HI
        BHS     %FT17
        TEQS    FileOff, FragEnd
        BNE     %FT17

        MOV     FileOff, R6     ;Restore FileOff
        MOV     R2, TransferEnd
        LDR     R1, [SP,#ReadRamAdjust]
        BL      BufsToRam       ;R1,R2,BufSz,FileOff,Fcb
        BL      ReleaseFileCache
        LDR     R1, FloppyProcessBlk
        CMPS    R0, R1          ;V=0
        MOVEQ   R1, #FloppyLock
        MOVNE   R1, #WinnieLock
        BL      BackgroundOps   ;(R0,R1->R3-R11)
        ADD     SP, SP, #ReadBuffersWork
        B       %BT00           ;Exit (checking V)

17
; SCHEDULE A NEW READ TRANSFER
 [ DebugB
        CPBs
 ]
        MOV     FileOff, R6     ;Restore FileOff
        BL      ReleaseFileCache
        BL      DiscWriteBehindWait                  ;(R3)
 [ DebugB
        CPBs
 ]
        BL      ClaimFileCache
        LDR     BufPtr,[Fcb,#PrevInFile]
        STR     TransferEnd, [Fcb,#FcbLastReadEnd]

;CONSIDER WHETHER CURRENT READ AHEAD IF ANY COULD BE EXTENDED FOR THIS REQUEST

        BL      ClaimController ;(R0)
        LDRB    LR, [R0,#Process]
        TEQS    LR, #ReadAhead
        LDREQ   LR, [R0,#ProcessFcb]
        TEQEQS  LR, Fcb
        LDREQ   LR, [R0,#ProcessStatus]
        ANDEQ   LR, LR, #CanExtend
        TEQEQS  LR, #CanExtend
        BNE     %FT20           ;If not reading ahead or not able to extend

 [ DebugB
        CPBs
        DLINE   "GetBytesEntry : reading ahead and can extend"
 ]
        LDR     FileOff, [R0,#ProcessEndOff]
        CMPS    FileOff, R6                   
        CMPHS   TransferEnd, FileOff          
        LDRHI   FragEnd, [R0,#ProcessFragEnd]
        CMPHIS  FragEnd, FileOff
        BLS     %FT18           ;IF would not help request

        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        MOV     R2, FileOff
        CMPS    TransferEnd, FragEnd
        MOVLO   FragEnd, TransferEnd
        BL      ScanBuffers     ;FileOff,FragEnd,BufSz,BufOff,BufPtr->FileOff,BufOff,BufPtr, LO/EQ(/HI)
        BNE     %FT18           ;(R0-R2->Z)

        LDR     R1, [SP,#ReadRamAdjust]
        BL      AddPair         ;(R0,R1,FileOff->C)
        BCC     %FT18
 [ DebugH
        DLINE   "RFX ",cc       ;Read Foreground eXtend
 ]
        BL      IncReadAhead    ;(Fcb)
        ASSERT  PendingReadStart=0
        ASSERT  PendingReadEnd=4
        STMIA   SP, {FileOff,TransferEnd}
        MOV     TransferEnd,R2
18
        MOV     FileOff,R6      ;Restore FileOff
20
        BL      UpdateProcesses
        BL      BeforeReadFsMap ;(R3->R0,V)
        BVS     %FT70           ;Error exit, map not locked
;LOOP TO DO TWO PARTS OF READ IF SPLIT BY READ AHEAD TO MIDDLE
22
 [ DebugB
        CPBs
 ]
        CMPS    FileOff,TransferEnd
        BHS     %FT32
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        BL      DefFileFrag     ;FileOff,Fcb -> R0,DiscAdjust,FragEnd
        CMPS    FragEnd, TransferEnd
        MOVHI   FragEnd, TransferEnd

;LOOP TO DEAL WITH FRAGMENTS
24
        CMPS    FileOff,FragEnd
        BLO     %FT25
        BL      DefFileFrag     ;FileOff,Fcb -> R0,DiscAdjust,FragEnd
        CMPS    FragEnd, TransferEnd
        MOVHI   FragEnd, TransferEnd
25
        Push    "FileOff"
        BL      ScanBuffers     ;FileOff,FragEnd,BufSz,BufOff,BufPtr->FileOff,BufOff,BufPtr,LR, LO/EQ/HI
        Push    "FileOff,TransferEnd,FragEnd,BufOff,BufPtr"
        MOV     R3, FileOff
        LDR     FileOff,[SP,#5*4]       ;old FileOff

        ASSERT  LastType=LastDiscAdjust+4
        ASSERT  LastEnd=LastType+4
        ASSERT  LastStart=LastEnd+4

        ASSERT  TransferEnd=R7
        ASSERT  FragEnd=R8
        ASSERT  BufOff =R10
        ASSERT  BufPtr =R11
        ADD     R7, SP, #6*4+LastDiscAdjust
        LDMIA   R7, {R7,R8,R10,R11}     ; aka {LastDiscAdjust,LastType,LastEnd,LastStart} 
 [ DebugG
        DREG    R7,,cc
        DREG    R8,,cc
        DREG    R10,,cc
        DREG    R11,,cc
        DLINE   "Last"
 ]
        MOVLO   R2, R3
        BLO     %FT28                   ;cached

        MOVHI   R2, #ReadAhead
        MOVEQ   R2, #EmptyBuf

 [ DebugB
        CPBs
 ]
        STR     DiscAdjust, [SP, #6*4+LastDiscAdjust]
        ADD     LR, SP, #6*4+LastType
        STMIA   LR, {R2,R3,FileOff}     ; aka {LastType,LastEnd,LastStart}
        TSTS    R8, #bit31              ; check last type
        BMI     %FT30                   ; no last op
        TSTS    R8, #ReadAhead
        BNE     %FT26

;PREVIOUS EMPTY
 [ DebugH
        DLINE   "RPE ",cc         ;Read Previous Empty
 ]
        Push    "R4"
        MOV     R1, #DiscOp_ReadSecs :OR: DiscOp_Op_IgnoreEscape_Flag
 [ BigDisc
        LDR     LR, [Fcb, #FcbIndDiscAdd]
        MOV     LR, LR, LSR #(32-3)
        DiscRecPtr LR,LR                ; disc record pointer
        LDRB    LR, [LR,#DiscRecord_Log2SectorSize]    ; sector size
        ADD     R2, R7, R11, LSR LR     ; disc address
 |
        ADD     R2, R11,R7      ;disc address
 ]
        LDR     LR, [SP, #(1+6)*4 + ReadRamAdjust]
        ADD     R3, R11,LR      ;RAM ptr
        SUB     R4, R10,R11     ;length
 [ Debug3L
        DLINE   "H",cc
 ]
        BL      DoDiscOp        ;(R1-R4->R0,R2-R4,V)
 [ Debug3L
        DLINE   "h",cc
 ]
        Pull    "R4",VC
        BVC     %FT30
        ADDVS   SP, SP, #(1+6)*4
        BVS     %FT68           ;error exit, map needs unlocking

26
;PREVIOUS READING AHEAD
 [ DebugH
        DLINE   "RPR ",cc         ;Read Previous Reading Ahead
 ]
        BL      IncReadAhead            ;(Fcb)
        LDR     R0, [SP,#6*4+ReadProcessBlock]
        BL      WaitForControllerFree   ;(R0)

        LDR     R0, [R0, #ProcessError]
        TEQS    R0, #0
        ADDNE   SP, SP, #6*4
        BNE     %FT66

        MOV     FileOff,R11
        MOV     R2, R10
28
; GOT SOMETHING, COPY TO USER RAM
        LDR     R1, [SP,#6*4+ReadRamAdjust]
        BL      BufsToRam       ;R1,R2,BufSz,FileOff,Fcb

30
        Pull    "FileOff,TransferEnd,FragEnd,BufOff,BufPtr"
        ADD     SP, SP, #4
        CMPS    FileOff, TransferEnd
        BLO     %BT24

32
        ASSERT  PendingReadStart=0
        ASSERT  PendingReadEnd=4
        LDMIA   SP, {FileOff,TransferEnd}     ; aka {PendingReadStart,PendingReadEnd}
        MOV     LR, #bit1
        STR     LR, [SP,#PendingReadEnd]
        TEQS    TransferEnd, #bit1            ; flag not set, go round again
        BNE     %BT22
        LDR     LR, [SP,#LastType]
        LDR     DiscAdjust, [SP,#LastDiscAdjust]
        TSTS    LR, #bit31
        BMI     %FT36
        TSTS    LR, #ReadAhead
        BNE     %FT40

;FINAL EMPTY
 [ DebugH
        DLINE   "RFE ",cc         ;Read Final Empty
 ]
        LDR     FileOff, [SP,#LastEnd]
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        SUB     FileOff, FileOff, #1
        BL      DefFileFrag     ;FileOff,Fcb -> R0,DiscAdjust,FragEnd
        Push    "FragEnd"
        ADD     FileOff, FileOff, #1
        MOV     R3, R0          ;Frag start
        MOV     TransferEnd, FileOff

        Push    "FileOff,BufOff,BufPtr"
        BL      SkipEmpty       ;BufSz,FileOff,FragEnd,BufOff,BufPtr->FileOff,BufOff,BufPtr

        CMPS    FileOff, FragEnd
        MOVLO   FragEnd, FileOff
        LDMIA   SP, {FileOff,BufOff,BufPtr}

;round lower bound above first cached sub buf below read end
34
        SUBS    BufOff,BufOff,BufSz
        ADDMI   BufOff,BufOff,#32
        LDRMI   BufPtr,[BufPtr,#PrevInFile]
        ASSERT  BufFlags=0
        LDRB    LR, [BufPtr,BufOff,LSR #3]
        TSTS    LR, #EmptyBuf
        BNE     %BT34
        LDR     R0, [BufPtr,#BufFileOff]
        ADD     R0, R0, BufOff, LSL #5
        ADD     R0, R0, BufSz, LSL #5
        Pull    "FileOff,BufOff,BufPtr"
        CMPS    R0, R3
        MOVHI   R3, R0

;round lower bound above cylinder boundary below read end, old map winnie
;defect skipping may give wrong answer

 [ BigDisc
        SUB     R2, FileOff, #1

        LDR     LR, [Fcb, #FcbIndDiscAdd]
        MOV     LR, LR, LSR #(32-3)     ; reassess disc (DiscAdjust may contain incorrect number)
        DiscRecPtr LR,LR

        LDRB    LR, [LR, #DiscRecord_Log2SectorSize]

        MOV     R2, R2, LSR LR
        ADD     R0, DiscAdjust, R2
        BIC     R0, R0, #DiscBits
        LDR     R1, [SP,#4+ReadCylLength]
        Push    "LR"
        BL      Divide                  ; r0 := disc address / cylinder size
        Pull    "LR"                    ; r1 := remainder
      [ BigFiles
        CMP     R1, R2
        MOVHI   R0, #0
        SUBLS   R0, R2, R1
        MOVLS   R0, R0, LSL LR          ; cylinder round down underflowed
      |
        SUBS    R0, R2, R1
        MOVMI   R0, #0
        MOV     R0, R0, LSL LR
      ]
 |
        SUB     R2, FileOff, #1
        ADD     R0, R2, DiscAdjust
        BIC     R0, R0, #DiscBits
        LDR     R1, [SP,#4+ReadCylLength]
        BL      Divide
        SUBS    R0, R2, R1
        MOVMI   R0, #0
 ]
 [ {FALSE}
        BIC     R0, R0, #&3FC           ;force to 1K boundary for add buffer
 ]
        CMPS    R0, R3
        MOVHI   R3, R0

        ANDS    LR, TransferEnd, #&3FC  ;extend end to 1K boundary
        SUB     R1, TransferEnd, LR
        ADDNE   R1, R1, #1*K
        MOV     R2, R1
        MOVNE   R0, #NormalChain*2
 [ DebugG
        BEQ     %FT01
        DLINE   "Extend up to 1K boundary"
01
 ]
        BLNE    ExtendUp                ;(R0,R1,TransferEnd,FragEnd->R1,TransferEnd)

        MOV     R1, R2
        LDRB    R2, [Fcb,#FcbFlags]     ;if reading sequentially try to add read ahead
        TSTS    R2, #Sequential

        MOVNE   R0, #AwaitsSeqChain*2-1
        LDRNEB  LR, [Fcb,#FcbRdAheadBufs]
        ADDNE   R1, R1, LR, LSL #10
 [ DebugG
        BEQ     %FT01
        DLINE   "Extend for sequential"
01
 ]
        BLNE    ExtendUp                ;(R0,R1,TransferEnd,FragEnd->R1,TransferEnd)

 [ DebugB
        CPBs
 ]
        SUB     R1, FileOff, #&100
        BICS    R1, R1, #&3FC           ;IF first buffer (so small files get cached)
        TSTNES  R2, #Monotonic          ;OR not monotonic
        BNE     %FT35

        MOV     R0, #NormalChain*2      ;THEN extend down to 1K boundary
 [ DebugG
        DLINE   "Extend down to 1K boundary"
 ]
        BL      ExtendDown              ;(R0,R1,R3,FileOff->R1,FileOff)

        MOV     R0, #MonotonicChain*2
        LDR     R1, [SP,#4+LastStart]
        BIC     R1, R1, #&300
 [ DebugG
        DLINE   "Extend down to start"
 ]
        BL      ExtendDown              ;(R0,R1,R3,FileOff->R1,FileOff)
35
 [ BigDisc
        LDR     LR, [Fcb, #FcbIndDiscAdd]
        MOV     LR, LR, LSR #(32-3)     ; reassess disc (DiscAdjust may contain incorrect number)
        DiscRecPtr LR,LR

        LDRB    LR, [LR, #DiscRecord_Log2SectorSize]

        ADD     R0, DiscAdjust, TransferEnd, LSR LR
        BIC     R0, R0, #DiscBits
        LDR     R1, [SP,#4+ReadCylLength]
        Push    "LR"
        BL      Divide                  ; r0 := disc address / cylinder size
        Pull    "R0"                    ; r1 := remainder                    
      [ BigFiles
        CMPS    R1, #1
        SUB     R1, TransferEnd, R1, LSL R0
        LDRCS   LR, [SP,#4+ReadCylLength]
        ADDCSS  R1, R1, LR, LSL R0
        CMPCC   R1, #-1*K
        LDRCS   R1, =-1*K               ; cylinder round up went into dead-band
      |
        TEQS    R1, #0
        SUB     R1, TransferEnd, R1, LSL R0
        LDRNE   LR, [SP,#4+ReadCylLength]
        ADDNE   R1, R1, LR, LSL R0
      ]
 |
        ADD     R0, TransferEnd, DiscAdjust
        BIC     R0, R0, #DiscBits
        LDR     R1, [SP,#4+ReadCylLength]
        BL      Divide
        TEQS    R1, #0
        SUB     R1, TransferEnd, R1
        LDRNE   LR, [SP,#4+ReadCylLength]
        ADDNE   R1, R1, LR
 ]
 [ {FALSE}
        BIC     R1, R1, #&3FC           ;force to 1K boundary for add buffer
 ]
        MOV     R0, #MonotonicChain*2
 [ DebugG
        DLINE   "Extend up to cylinder end"
 ]
        BL      ExtendUp                ;(R0,R1,TransferEnd,FragEnd->R1,TransferEnd)

        TSTS    R2, #Monotonic
        MOVEQ   R0, #MonotonicChain*2
        MOVEQ   R1, R3
 [ DebugG
        BNE     %FT01
        DLINE   "Extend down to cylinder start"
01
 ]
        BLEQ    ExtendDown              ;(R0,R1,R3,FileOff->R1,FileOff)

        Pull    "FragEnd"
        LDR     R0, [SP,#ReadProcessBlock]
        LDR     LR, [SP,#LastStart]

        SUBS    R2, FileOff, LR
        MOVHI   FileOff, LR
        LDRHI   R1, [SP,#ReadRamAdjust]
        LDRLS   R1, [SP,#LastDiscAdjust]
        MOVLS   R2, #0
        MOV     R3, #DiscOp_ReadSecs
        LDR     R6, [SP, #LastEnd]
        SUB     R6, R6, FileOff
        BL      BackgroundFileCacheOp1  ;R0-R3,FileOff,R6,TransferEnd,FragEnd,Fcb,BufPtr -> R1,R3,R10,V
        BL      UpdateProcesses
        MOVVS   R0, R3
        BVS     %FT68                   ;error exit, map needs unlocking
 [ DebugB
        CPBs
 ]

        ADD     FileOff, FileOff, R2    ;end of direct read
        ASSERT  LastStart=LastEnd+4
        ADD     R2, SP, #LastEnd
        LDMIA   R2, {R2,LR}             ; aka {LastStart,LastEnd}
        CMPS    FileOff, LR
        MOVLO   FileOff, LR
        CMPS    R2, FileOff
        LDRHI   R1, [SP, #ReadRamAdjust]
        BLHI    BufsToRam               ;(R1,R2,BufSz,FileOff,Fcb)
        CLRV                            ; incase CMPs above set it
        B       %FT68                   ; exit, map needs unlocking

36
;MANAGED TO SATISY READ ONLY FROM BUFFERS AND/OR EXTENDING READ AHEAD
 [ DebugH
        DLINE   "RFC ",cc
 ]
 [ DebugB
        CPBs
 ]
        LDRB    LR, [Fcb,#FcbFlags]
        ANDS    R0, LR, #Sequential
        BEQ     %FT64

        BL      UnlockMap
        BL      ReleaseFileCache
        LDR     R0, [SP,#ReadProcessBlock]
        BL      ReleaseController       ;(R0)
        LDR     R1, FloppyProcessBlk
        TEQS    R0, R1
        MOVEQ   R1, #FloppyLock
        MOVNE   R1, #WinnieLock
        BL      BackgroundOps   ;(R0,R1->R3-R11)
        BL      ClaimController ;(R0)
38
        LDRB    LR, [R0,#ProcessDirect]
        TEQS    LR, #0
        BLNE    UpdateProcesses
        BNE     %BT38
        BL      ReleaseController       ;(R0)
        LDR     R0, DirectError
        BL      SetVOnR0
        ADD     SP, SP, #ReadBuffersWork
        B       %BT00

;FINAL READ AHEAD
40
 [ DebugH
        DLINE   "RFR ",cc         ;Read Final Reading ahead
 ]
 [ DebugB
        CPBs
 ]
        BL      IncReadAhead            ;(Fcb)
        LDR     R0, [SP, #ReadProcessBlock]
        LDR     FragEnd, [R0, #ProcessFragEnd]
        LDR     TransferEnd, [SP,#LastEnd]
        LDR     FileOff, [R0, #ProcessEndOff]
        MOV     R3, FileOff
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        BL      SkipEmpty       ;BufSz,FileOff,FragEnd,BufOff,BufPtr->FileOff,BufOff,BufPtr
        MOV     FragEnd, FileOff
        CMPS    FileOff, R3
        STRLS   R3, [SP,#SeqReadAheadLimit]
        STRLS   R3, [SP,#SeqReadAheadLimit]
        BLS     %FT44                   ;no scope for extending

        MOV     FileOff, R3
        LDRB    LR, [Fcb, #FcbFlags]
        MOV     R1, TransferEnd
        TSTS    LR, #Sequential
        BEQ     %FT42

        TSTS    R1, #&3FC
        BICNE   R1, TransferEnd, #&3FC
        ADDNE   R1, R1, #1*K
        LDRB    LR, [Fcb,#FcbRdAheadBufs]
        ADD     R1, R1, LR, LSL #10
        CMPS    R1, FragEnd
        MOVHI   R1, FragEnd

42
 [ DebugB
        CPBs
 ]

 [ BigDisc
 ; again, we have to round to a cylinder

        STR     R1, [SP,#SeqReadAheadLimit]

        LDR     LR, [Fcb, #FcbIndDiscAdd]
        MOV     LR, LR, LSR #(32-3)     ; reassess disc (DiscAdjust may contain incorrect number)
        DiscRecPtr LR,LR

        LDRB    LR, [LR, #DiscRecord_Log2SectorSize]
        SUB     FileOff, FileOff, #1
        MOV     R2, FileOff, LSR LR

        ADD     R0, R2, DiscAdjust
        BIC     R0, R0, #DiscBits
        LDR     R1, [SP,#ReadCylLength]
        Push    "LR"
        BL      Divide                  ; r0 := disc address / cylinder size
        Pull    "LR"                    ; r1 := remainder                    
        SUB     R2, R2, R1
        LDR     R1, [SP,#ReadCylLength]
        ADD     R2, R2, R1
        MOVS    LR, R2, LSL LR
      [ BigFiles
        CMPCC   LR, #-1*K
        LDRCS   LR, =-1*K               ; cylinder round up went into dead-band
      ]
        CMPS    LR, FragEnd
        MOVHI   LR, FragEnd

 |

        STR     R1, [SP,#SeqReadAheadLimit]

        SUB     FileOff, FileOff, #1
        ADD     R0, FileOff, DiscAdjust
        BIC     R0, R0, #DiscBits
        LDR     R1, [SP,#ReadCylLength]
        BL      Divide
        SUB     LR, FileOff, R1
        LDR     R1, [SP,#ReadCylLength]
        ADD     LR, LR, R1
        CMPS    LR, FragEnd
        MOVHI   LR, FragEnd
 ]
 [ {FALSE}
        BIC     LR, LR, #&3FC           ;force to 1K boundary for add buffer
 ]
        STR     LR, [SP,#TrkReadAheadLimit]

        LDR     R0, [SP, #ReadProcessBlock]
44
        BL      UpdateProcess   ;(R0)
;LOOP

;COPY ANY DATA THAT HAS APPEARED FROM READ AHEAD
 [ DebugB
        CPBs
 ]
        LDR     FileOff, [SP, #LastStart]
50
        LDR     R2, [R0, #ProcessStartOff]
        CMPS    R2, TransferEnd
        MOVHI   R2, TransferEnd
        CMPS    R2, FileOff
        LDRHI   R1, [SP, #ReadRamAdjust]
        BLHI    BufsToRam       ;(R1,R2,BufSz,FileOff,Fcb)
        STRHI   R2, [SP, #LastStart]

;ADD BUFFERS
        LDRB    LR, [R0,#Process]
        ASSERT  ReadAhead>Inactive
        ASSERT  WriteBehind>Inactive
        CMPS    LR, #Inactive+1
        BLO     %FT62                           ;process finished
        LDR     FileOff, [R0, #ProcessEndOff]
        BL      LessValid
52
 [ DebugB
        CPBs
 ]
        LDR     LR, [R0, #ProcessStatus]
        TSTS    LR, #CanExtend
        BEQ     %FT60
        SUBS    R3, FragEnd, FileOff            ;if extended to frag end
        BLS     %FT60                           ;don't consider more extension
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        CMPS    BufOff, #32
        LDRLO   R2, [BufPtr,#BufFlags]
        MOVLO   R6, #-1
        BLO     %FT56
        LDR     R3, [SP, #SeqReadAheadLimit]
        SUBS    R3, R3, FileOff
        MOVHI   R0, #AwaitsSeqChain*2-1         ;special
        BHI     %FT54
        LDR     R3, [SP, #TrkReadAheadLimit]
        SUBS    R3, R3, FileOff
        BLS     %FT60

        MOV     R0, #MonotonicChain*2
54
        BL      FindFreeBuf             ;(R0,FileOff,Fcb,BufPtr->R2,BufPtr,Z)
        LDR     R0, [SP, #ReadProcessBlock]
        BEQ     %FT60
        MOV     R6, R2
        BIC     LR, FileOff, #&3FC
        STR     LR, [BufPtr,#BufFileOff]
        STR     Fcb, [BufPtr,#BufFcb]
        LDR     R2, = EmptyBuf * &01010101
        AND     BufOff, FileOff, #&300
        MOV     BufOff, BufOff, LSR #5
56
        RSB     LR, BufOff, #32
        CMPS    R3, LR, LSL #5
        MOVHI   R3, LR, LSL #5
        BL      AddBuffer               ;(R0,R3,FileOff,BufOff,BufPtr->FileOff,C)
        BCC     %FT58

        MOV     R1, #ReadAhead
        MOV     LR, #AllBufFlags
57
        BIC     R2, R2, LR, LSL BufOff
        ORR     R2, R2, R1, LSL BufOff
        ADD     BufOff,BufOff,BufSz
        SUBS    R3, R3, BufSz, LSL #5
        BNE     %BT57

        BL      UpdateBufState          ;(R2,BufSz,BufPtr)
        MOVS    R2, R6
        BLPL    LinkFileChain           ;(R2,BufPtr)
        B       %BT52

58                              ;here if failed to add buffer
        TEQS    R2, #0
        LDRPL   R2, =EmptyBuf * &01010101
        BLPL    UpdateBufState          ;(R2,BufSz,BufPtr)
        LDRPL   BufPtr, [Fcb, #PrevInFile]
60
 [ DebugB
        CPBs
 ]
        BL      MoreValid
        BL      UpdateProcesses
        LDR     FileOff, [SP, #LastStart]
        CMPS    FileOff, TransferEnd
        BLO     %BT50

62
        LDRLO   FileOff, [SP, #LastStart]
        CMPLOS  FileOff, TransferEnd
        LDRLO   R0, [R0,#ProcessError]
        BLO     %FT66

64
        MOV     R0, #0
66
 [ DebugB
        CPBs
 ]
        BL      SetVOnR0
68                      ;FOLLOWING MUST PRESERVE V
 [ DebugB
        CPBs
 ]
        BL      UnlockMap
70
 [ DebugB
        CPBs
 ]
        BL      ReleaseFileCache
        MOV     R1, R0
        LDR     R0, [SP, #ReadProcessBlock]
72                              ;wait if necessary for direct part to complete
 [ DebugB
        CPBs
 ]
        LDRB    LR, [R0, #ProcessDirect]
        TEQS    LR, #&FF
        BLEQ    UpdateProcesses
        BEQ     %BT72
        BL      ReleaseController       ;(R0)
        MOVVS   R0, R1
        LDRVC   R0, DirectError
        BLVC    SetVOnR0
        ADD     SP, SP, #ReadBuffersWork
        B       %BT00                   ;Exit (checking V)

        LTORG


; >>>>>>>>>>>>>
; PutBytesEntry
; >>>>>>>>>>>>>

; entry:
;  R1   file handle
;  R2   start RAM address (no alignment guarantee)
;  R3   number of bytes to write (FileSwitch buffer multiple)
;  R4   file address (FileSwitch buffer multiple)

; exit:
;  R1-R4 ?
; V clear
;  R0   ?
; V set
;  R0   -> error block

PutBytesEntry ROUT
        SemEntry  Flag          ;allow reentrance, leaves SB,LR stacked
 [ Debug3L
        DLINE   "P",cc
 ]
 [ DebugB :LOR: DebugBE
        DLINE   "handle  |start   |length  |file ptr - PutBytesEntry"
        DREG    R1,,cc
        DREG    R2,,cc
        DREG    R3,,cc
        DREG    R4
 ]
 [ DebugBt
        DLINE   ">P",cc
 ]
        Push    "R5-R11"
        BL      HandleCheck     ;(R1->R0,R1,LR,V)
        BVS     %FT05
        LDR     R0, [R1,#FcbAllocLen]
      [ BigFiles
        TEQ     R0, #RoundedTo4G
        MOVEQ   R0, #&FFFFFFFF
        ADDS    LR, R4, R3
        BCC     %FT01           ; No carry out, proceed with comparison
        CMP     LR, #1          ; Allow carry out of only 4G exactly
        MOVCC   LR, R0          ; LR <=> 0, C=0, be sure to pass the test
01
      |
        ADDS    LR, R4, R3
      ]
        SUBCC   LR, LR, #1
        CMPCCS  LR, R0          ; Outside allocation?
        MOVCS   R0, #BadParmsErr
        BLCS    SetV
        BCS     %FT05

        ; Non filecore disc images - do transfer in foreground
        LDRB    r5, [r1, #FcbFlags]
        TST     r5, #FcbDiscImage
        BNE     %FT03

        ; Ensure a new Id on FileCore disc only
        Push    "r3"
        LDR     r3, [r1, #FcbIndDiscAdd]
        BL      EnsureNewId
        Pull    "r3"
        BVS     %FT05

      [ BigFiles
        ; If transfer ends at exactly 4G, use foreground
        ; If transfer ends near 4G, use foreground
        ADDS    R5, R3, R4
        CMPCC   R5, #-1*K
        BCS     %FT03
      ]
      [ BigSectors
        ; If sector size larger than buffer size, use foreground
        LDRB    R5, [r1, #FcbBufSz]
        CMP     R5, #1*K :SHR: BufSz
        BHI     %FT03
      ]
        ; Do in background if got some file buffers
        LDRB    R5, MaxFileBuffers
        TEQ     R5, #0
        BNE     %FT06
03
        ; Foreground
        Push    "R1,R3,R4"
        MOV     R5, R4
        MOV     R4, R3
        MOV     R3, R2
        LDR     R2, [R1,#FcbIndDiscAdd]
        MOV     R1, #DiscOp_WriteSecs :OR: DiscOp_Op_IgnoreEscape_Flag
        BL      GenIndDiscOp    ;(R1-R5->R0-R5,V)

        ; Discard any cached clashing read ahead buffers
        Pull    "R1,R3,R4"
        LDRB    r5, [r1, #FcbFlags]
      [ BigFiles
        SavePSR r6              ; V from GenIndDiscOp
        ASSERT  FcbDiscImage = 128
        MOVS    r5, r5, LSR #8  ; FcbDiscImage set => C set
        ADDCCS  r5, r3, r4      ; or foreground forced because write ended at 4G => C set
        BLCS    ReleaseFcbBuffersInRange ;(r1,r3,r4) drop all buffers in range
        RestPSR r6,,f
      |
        TST     r5, #FcbDiscImage
        BLNE    ReleaseFcbBuffersInRange ;(r1,r3,r4) drop all buffers in range
      ]
05
        BLVS    FindErrBlock    ; (R0->R0,V)
        BL      FileCoreExit
 [ Debug3L
        DLINE   "p",cc
 ]
 [ DebugBt
        DLINE   " <P"
 ]
 [ DebugB :LOR: DebugBE
        DLINE   "<PutBytes"
        DebugError "PutBytes error"
 ]
        Pull    "R5-R11,SB,PC"

;layout of write stack workspace
                        ^ 0
WriteProcessBlock       # 4
WriteRamAdjust          # 4
WriteBuffersWork        # 0

06

;INITIALISATION
 [ DebugJ
        BL      Check
 ]
 [ DebugB
        CPBs
 ]
 [ DebugH
        DLINE   "W ",cc
        DREG    R4,,cc
 ]
        MOV     R0, #2
        BL      GetPutCommon  ;R0-R4->R0,R2,R3,BufSz,FileOff,R6,TransferEnd,Fcb,R10,Z,V
        BVS     %BT05
        ASSERT  WriteProcessBlock = 0
        ASSERT  WriteRamAdjust = 4
        Push    "R0,R2"

;IF FLOPPY LET WRITE BEHIND ON ANY OTHER FLOPPY FINISH
        BL      DiscWriteBehindWait             ;(R3)
        BL      ClaimController                 ;(R0)

        MOV     R2, R3, LSR #(32-3)
        STRB    R2, WriteDisc
; ENSURE DISC PRESENT AND DRIVE LOCKED
        LDRB    LR, [R0, #ProcessWriteBehindDisc]
        TEQ     LR, R2
        BEQ     %FT09

        LDRB    LR, LockedDisc
        CMPS    LR, R2                  ;V=0
        BLEQ    DiscAddToRec            ;(R3->LR)
        LDREQB  R1, [LR, #DiscsDrv]
        BEQ     %FT07
        BL      LockDisc                ;(R3->R0,R1,V)
        MOVVS   R3, #&FF
        STRVSB  R3, WriteDisc
        MOVVS   R3, R0
        LDRVS   R0, [SP, #WriteProcessBlock]
        BLVS    ReleaseController       ;(R0)
        BVS     %FT93

07
; Set writebehind disc and drive"
        ASSERT  (ProcessWriteBehindDrive) :MOD: 4 =0      ;word write so atomic
        ASSERT  ProcessWriteBehindDisc-ProcessWriteBehindDrive=1
        ORR     LR, R1, R2, LSL #8
        STR     LR, [R0, #ProcessWriteBehindDrive]
09
 [ DebugB
        CPBs
 ]

 [ DebugBv
        DLINE   "Write behind finished, controller claimed, set write behind disc and drive"
 ]

;IF TRANSFER OVERLAPS ACTIVE BUFFERS WAIT FOR THEM TO FINISH
        LDR     LR, [R0,#ProcessFcb]    ; LR := file control block of current process on this controller
        TEQS    Fcb,LR
        BNE     %FT17
13
 [ DebugBv
        DLINE   "Process Fcb matches"
 ]
        ; Fcb matches Process Fcb
        ; Loop until process is inactive or transfer range doesn't
        ; intersect requested transfer

        LDRB    LR, [R0,#Process]
        TSTS    LR, #ReadAhead :OR: WriteBehind
        BEQ     %FT17
 [ DebugBv
        DLINE   "Process still active"
 ]
        ASSERT  ProcessEndOff = ProcessStartOff+4
        ADD     R2, R0, #ProcessStartOff
        LDMIA   R2, {R2,LR}
        CMPS    R2, TransferEnd
        CMPLOS  FileOff, LR
        BLLO    UpdateProcesses
 [ Debug3L
        BHS     %FT01
        DLINE   "w",cc
01
 ]
        BLO     %BT13

17
 [ DebugBv
        DLINE   "Process now quiet"
        CPBs
 ]
;CONVERT ANY SUB BUFFERS BETWEEN START AND END TO EMPTY
        BL      ClaimFileCache
        MOV     R6, FileOff
        BL      EmptyBuffers    ;R0,BufSz,FileOff,TransferEnd,Fcb->BufOff,BufPtr

;WORK BACKWARDS FROM END CLAIMING BUFFERS
 [ DebugBv
        DLINE   "FileCache claimed and buffers emptied"
        CPBs
 ]

;R6 - start  of transfer
;TransferEnd

        BL      UpdateProcesses
 [ DebugBv
        DLINE   "Processes updated"
 ]
        MOV     R8, TransferEnd
33
 [ DebugBv
        DLINE   "Stuff a buffer..."
 ]
 [ DebugJ
        CMPS    R6, R8
        BLO     %FT01

        DREG    R6, "", cc
        DREG    R8, "", cc
        MOV     LR, PC
        MOV     PC, #0
01
 ]
        SUB     FileOff, R8, BufSz, LSL #5
        BIC     FileOff, FileOff, #&3FC
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        TEQS    BufOff, #0
        LDREQ   R2, [BufPtr,#BufFlags]
        MOVEQ   R3, #-1
        BEQ     %FT37

        MOV     R0, #AwaitsSeqChain*2
        BL      FindFreeBuf             ;(R0,FileOff,Fcb,BufPtr->R2,BufPtr,Z)
        BEQ     %FT45                   ;couldn't get buffer
        MOV     R3, R2
        STR     Fcb, [BufPtr,#BufFcb]
        STR     FileOff, [BufPtr,#BufFileOff]
; MB FIX
; FindFreeBuf returns a buffer that has rubbish in its prev and next pointers
; so set them to 0 so that UpdateBufState can detect it. If it doesn't get into UpdateBufState
; then the machine is probably dead... Kill or cure...
        MOV     LR,#0
        STR     LR,[BufPtr,#NextInFile]
        STR     LR,[BufPtr,#PrevInFile]
; end MB FIX
        LDR     R2, =EmptyBuf * &01010101
37
        SUBS    R1, R6, FileOff
        MOVLO   R1, #0
        MOVLO   R0, FileOff
        MOVHS   R0, R6
41
        CMPS    FileOff, R6
        CMPHSS  R8, FileOff
        BICHI   R2, R2, #AllBufFlags
        ORRHI   R2, R2, #WriteBehind    ; turn that sub buffer from empty to write behind
        MOV     R2, R2, ROR BufSz
        ADD     FileOff, FileOff, BufSz, LSL #5
        TSTS    FileOff, #&300
        BNE     %BT41
        BL      UpdateBufState  ;(R2,BufSz,BufPtr)
        SUB     R2, R8, R0
        LDR     LR, [SP, #WriteRamAdjust]
        ADD     R0, R0, LR
        ADD     R1, R1, #BufferData
        ADD     R1, BufPtr, R1
        LDR     R8, [SP, #WriteProcessBlock]
        LDR     LR, [R8, #ProcessWriteBehindLeft]
        ADD     LR, LR, R2
        STR     LR, [R8, #ProcessWriteBehindLeft]
  [ DebugH :LOR: DebugBv
        DREG    R2,"+",cc
        Push    "r0"
        MOV     r0, LR
        DREG    r0," "
        Pull    "r0"
  ]
        TSTS    R0, #3
        BLEQ    Move256n        ;(R0-R2->R0-R2) copy data into buffer
        BLNE    BlockMove       ;(R0-R2)

        MOVS    R2, R3
        BLPL    LinkFileChain   ;(R2,BufPtr) must be done last for write behind

        SUB     R8, FileOff, #1*K       ; One more buffer filled and linked
        CMPS    R8, R6
        BHI     %BT33
 [ DebugBv
        DLINE   "Finished filling buffers"
 ]
        MOV     R8, R6
45
        MOV     R2, R8
        LDR     R0, [SP,#WriteProcessBlock]
        LDRB    R10,[R0,#Process]
        CMPS    R10,#WriteBehind        ;V=0
        LDREQ   LR, [R0,#ProcessFcb]
        TEQEQS  LR, Fcb
        LDREQ   LR, [R0,#ProcessEndOff]
        TEQEQS  LR, R6
        LDREQ   R1, [R0,#ProcessStatus]
        ANDEQ   R1, R1, #CanExtend
        TEQEQS  R1, #CanExtend
        BEQ     %FT62

 [ DebugBv
        DLINE   "Process inconvenient (wrong Fcb, not this bit of disc or can't extend)"
 ]
;HERE IF NOT CONTIGUOUS IN FILE WITH EXISTING WRITE BEHIND
48                      ;V=0
 [ DebugBv
        CPBs
 ]
        ASSERT  Inactive = bit0
        TEQS    R10,R10,LSR #1  ;C=1 <=> Inactive
        TEQS    R2, R6          ;Z=1 <=> all buffered, preserves C
 [ DebugH
        BNE     %FT01
        DLINE   "WB ",cc
01
 ]
        BHI     %FT49           ;(  C  ~Z ) Inactive unbuffered, write unbuffered and adjacent
        BNE     %FT58           ;((~C) ~Z ) Active unbuffered, wait for process to advance
        BCC     %FT85           ;( ~C  (Z)) Active buffered, just return

 [ DebugBv
        DLINE   "Process inactive and all data buffered"
 ]

        MOV     R1, #&FF        ;( (C) (Z)) Inactive buffered, consider restarting
        STRB    R1, WriteDisc
        LDRB    R1, [R0, #ProcessWriteBehindDisc]
        TEQ     R1, #&FF
        MOVNE   R1, #0
        BLNE    ReduceWriteBehind       ;(R0,R1)
        LDR     R1, FloppyProcessBlk
        TEQ     R0, R1
        MOVEQ   R1, #FloppyLock
        MOVNE   R1, #WinnieLock
        BL      ReleaseFileCache
 [ DebugBv
        DLINE   "FileCache released"
 ]
        BL      ReleaseController       ;(R0)
 [ DebugBv
        DLINE   "Controller released"
 ]
        BL      BackgroundOps           ;(R0,R1->R3-R11)
 [ DebugBv
        DLINE   "BackgroundOps performed"
        CPBs
 ]
        B       %FT95

49
 [ DebugBv
        DLINE   "Process inactive and not all the data has been buffered"
        CPBs
 ]
        LDR     R3, [Fcb, #FcbIndDiscAdd]
        BL      BeforeReadFsMap ;(R3->R0,V)
 [ DebugBv
        DLINE   "Got the FSMap (maybe!)"
 ]
50
 [ DebugBv
        CPBs
 ]
        MOVVS   R3, R0
        LDRVS   R0, [SP,#WriteProcessBlock]
        BVS     %FT87
53
 [ DebugBv
        DLINE   "FS map definitely got"
        CPBs
 ]
 [ DebugH
        DLINE   "WN ",cc
 ]

        MOV     FileOff, R6
        BL      DefFileFrag     ;FileOff,Fcb -> R0,DiscAdjust,FragEnd
        MOV     R6, FileOff

        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        BL      BackwardsSkipWriteBehind ;R0,BufSz,FileOff,BufOff,BufPtr->FileOff,BufOff,BufPtr
        MOV     R3, FileOff

        MOV     FileOff, R2
        BL      FragLeft        ;(FileOff,Fcb->LR,Z)
        ADD     FragEnd, R2, LR

        CMPS    FragEnd, TransferEnd
        MOVLS   TransferEnd, FragEnd
        BLS     %FT57

        MOV     FileOff, TransferEnd
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        BL      SkipWriteBehind ;BufSz, FileOff, FragEnd, BufOff, BufPtr -> FileOff, BufOff, BufPtr
        MOV     TransferEnd, FileOff
57
 [ DebugBv
        CPBs
 ]
        BL      UnlockMap
        ASSERT  WriteProcessBlock = 0
        ASSERT  WriteRamAdjust = 4
        LDMIA   SP, {R0,R1}
        SUB     R2, R2, R3
        MOV     FileOff, R3
        SUB     R10,R6,R3
        MOV     R3, #DiscOp_WriteSecs
        MOV     R6, R2

 [ DebugBv
        DLINE   "BackgroundFileCacheOp going off"
 ]
        BL      BackgroundFileCacheOp
;R0-R3,FileOff,R6,TransferEnd,FragEnd,Fcb,R10,BufPtr -> R1,R3,V
 [ DebugBv
        DLINE   "Updating processes..."
 ]
        BL      UpdateProcesses
 [ DebugBv
        DLINE   "Processes updated"
        CPBs
 ]
        B       %FT85


58                              ;wait for process to advance, freeing buffers
 [ DebugBv
        DLINE   "Process still active, but not all data buffered"
        DLINE   "Drum fingers waiting for change",cc
 ]
        LDR     R1, [R0, #ProcessStartOff]
        MOV     R1, R1, LSR #10
        LDRB    R8, [R0, #Process]
59
        BL      UpdateProcesses
        LDR     R3, [R0, #ProcessError]
        TEQS    R3, #0
        BLNE    SetV
        BNE     %FT87
        LDR     LR, [R0, #ProcessStartOff]
        TEQS    R1, LR, LSR #10
        LDREQB  LR, [R0, #Process]
        TEQEQS  R8, LR
 [ DebugBv
        DLINE   ".",cc
 ]
        BEQ     %BT59
        MOV     R8, R2
 [ DebugBv
        DLINE   "Aha!"
 ]
        B       %BT33           ;loop to fill any finished buffers
 [ DebugBv
        LTORG
 ]
60
 [ DebugBv
        CPBs
 ]
        Pull    "R2"
61
 [ DebugBv
        DLINE   "Resort to 'process inconvenient' path"
        CPBs
 ]
        MOV     R10, #WriteBehind
        CMPS    R10, R10        ;V=0
        B       %BT48

;HERE IF CONTIGUOUS IN FILE WITH EXISTING WRITE BEHIND
62
 [ DebugBv
        DLINE   "Process writing behind on this Fcb, ends at where we want to start and can be extended"
        CPBs
 ]
        LDR     FragEnd, [R0, #ProcessFragEnd]
        CMPS    R2, R6
        BLS     %FT72
        Push    "R2"
        SUBS    R2, FragEnd, R6
        BLS     %BT60           ;can't extend background process over frag end

 [ DebugH
        DLINE   "WC ",cc
 ]
 [ DebugBv
        DLINE   "Filling out any partial buffer at start"
 ]
;FILL OUT ANY PARTIAL BUFFER AT START
        ANDS    R1, R6, #&300
        BEQ     %FT66

        RSB     LR, R1, #&400
        CMPS    LR, R2
        MOVLO   R2, LR
        MOV     R3, R2
        MOV     FileOff, R6
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr

        LDR     R0, [SP, #4+WriteRamAdjust]
        ADD     R0, R0, FileOff
        ADD     R1, R1, #BufferData
        ADD     R1, R1, BufPtr
        TSTS    R0, #3
        BLEQ    Move256n        ;(R0-R2->R0-R2)
        BLNE    BlockMove       ;(R0-R2)
        LDR     R0, [SP, #4+WriteProcessBlock]
        BL      AddBuffer       ;(R0,R3,FileOff,BufOff,BufPtr->FileOff,C)
        BCC     %BT60

        LDR     LR, [R0, #ProcessWriteBehindLeft]
        ADD     LR, LR, R3
  [ DebugH :LOR: DebugBv
        DLINE   "P+",cc
        DREG    R3,,cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
  ]
        STR     LR, [R0, #ProcessWriteBehindLeft]
        LDR     R2, [BufPtr,#BufFlags]
        MOV     R1, #WriteBehind :EOR: EmptyBuf
64
        EOR     R2, R2, R1, LSL BufOff
        ADD     BufOff, BufOff, BufSz
        SUBS    R3, R3, BufSz, LSL #5
        BGT     %BT64           ;Loop for each sub-buffer
 [ DebugBv
        DLINE   "Shuffle buffer"
        CPBs
 ]

        BL      UpdateBufState  ;R2,BufSz,BufPtr
 [ DebugJ
        BL      Check
 ]
        MOV     R6, FileOff
        CMPS    FragEnd, R6
        BLS     %BT60

66
 [ DebugBv
        DLINE   "Now do the complete buffers"
        CPBs
 ]
        Pull    "R2"
        LDR     R10,[R0, #ProcessStartOff]
        BIC     R10,R10,#&3FC
        SUB     R10,R6, R10     ;length of buffers involved in write behind
        TSTS    R2, #&3FC
        BIC     LR, R2, #&3FC
        ADDNE   LR, LR, #&400
        SUB     LR, LR, R6      ;length of write as yet unbuffered
        SUBS    R10,LR, R10
        BLO     %FT70           ;wont need direct part
        MOVEQ   R10,#1*K        ;if same use 1K direct part to stop process ending
        ADD     FileOff, R6, R10
        CMPS    FileOff, R2
        MOVHI   FileOff, R2
        CMPS    FileOff, FragEnd
        MOVHI   FileOff, FragEnd
        LDR     R1, [SP, #WriteRamAdjust]
        BL      AddPair         ;(R0,R1,FileOff->C)
        BCC     %BT61           ;pair add fails
        SUB     LR, FragEnd, R6
        MOV     R6, FileOff

        CMPS    LR, R10
        BLO     %BT61           ;frag end prevented adding all direct

70
 [ DebugBv
        DLINE   "Direct part not needed"
        CPBs
 ]
        CMPS    R2, R6
        BNE     %BT58           ;not all buffered, wait for some buffers
72
 [ DebugH
        DLINE   "WX ",cc         ;write extend
 ]
 [ DebugBv
        DLINE   "Hoopdy-doopdy write extend"
        CPBs
 ]
        CMPS    TransferEnd, FragEnd
        MOVHS   TransferEnd, FragEnd
        BHS     %FT76
        MOV     FileOff, TransferEnd
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
;BufSz, FileOff, FragEnd, BufOff, BufPtr -> FileOff, BufOff, BufPtr
        BL      SkipWriteBehind
        MOV     TransferEnd,FileOff
76
 [ DebugBv
        CPBs
 ]
        MOV     FileOff, R6
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        MOV     R3, #1*K
        SUB     R3, R3, BufOff, LSL #5
        BL      LessValid
78
        SUBS    LR, TransferEnd, FileOff
        BLS     %FT81
        CMPS    LR, R3
        MOVLO   R3, LR
        BL      AddBuffer       ;(R0,R3,FileOff,BufOff,BufPtr->FileOff,C)
 [ DebugBv
        DLINE   "buffer added"
 ]

        MOVCS   BufOff, #0
        LDRCS   BufPtr,[BufPtr,#NextInFile]
        MOVCS   R3, #1*K
        BCS     %BT78
81
        BL      MoreValid
        CMPS    R0, R0          ;V=0
 [ DebugBv
        DLINE   "All buffers added"
        CPBs
 ]
85
        BL      ReleaseFileCache
 [ DebugBv
        DLINE   "FileCache released"
 ]
86
;WAIT IF NECESSARY FOR DIRECT PART TO BE TRANSFERRED
        LDRB    LR, [R0,#ProcessDirect]
        TEQS    LR, #0
        BLNE    UpdateProcesses
 [ DebugBv
        DLINE   "Wait:D ",cc
        CPBs
 ]
        BNE     %BT86
 [ DebugBv
        DLINE   ""
 ]
        B       %FT89

87
 [ DebugBv
        CPBs
 ]
        BL      ReleaseFileCache
 [ DebugBv
        DLINE   "FileCache released"
 ]
89
 [ DebugBv
        DLINE   "Go to reduce write behind.."
        CPBs
 ]
        MOV     R1, #&FF
        STRB    R1, WriteDisc
        LDRB    R1, [R0, #ProcessWriteBehindDisc]
        TEQ     R1, #&ff
        MOVNE   R1, #0
        BLNE    ReduceWriteBehind       ;(R0,R1)
93
 [ DebugBv
        DLINE   "Go to release controller.."
        CPBs
 ]
        BL      ReleaseController       ;(R0)
        MOVVS   R0, R3
95
 [ DebugBv
        DLINE   "Yo! all done"
        CPBs
 ]
        ADD     SP, SP, #WriteBuffersWork
        B       %BT05

        LTORG


; ++++++++++++
; GetPutCommon
; ++++++++++++

; entry
;  R0 1 read, 2 write
;  R1 file handle
;  R2 RAM start address (no alignment guarantee)
;  R3 number of bytes to transfer (FileSwitch buffer multiple)
;  R4 file offset (FileSwitch buffer multiple)

; exit R0,V if error
; NE <=> floppy
; R0 -> process block for device
; R2 RAM adjust        : such that target_ram_address = file_offset_in_bytes + ram_adjust
; R3 IndDiscAdd        : of file
; BufSz                : selected buffer size in bytes LSR by BufScale, usually an LFAU, but might be sharing size
; FileOff              : offset in bytes within file (FileSwitch buffer multiple)
; R6 disc rec          : relating to the disc on which the file resides
; TransferEnd          : offset in bytes when the transfer is done (FileSwitch buffer multiple)
; Fcb                  : file control block
; R10 log2 sector size : relating to the disc on which the file resides

GetPutCommon ROUT
 [ DebugB
        DREG    R1,,cc
        DREG    R2,,cc
        DREG    R3,,cc
        DREG    R4,,cc
        DLINE   ">GetPutCommon"
 ]
        LDRB    R6, [R1, #FcbDataLostFlag]      ;CHECK FOR DATA LOST
        TEQS    R6, #0
        MOVNE   R0, #DataLostErr
        SETV    NE                              ; preserves NE condition
        MOVNE   PC, LR

        SUB     R2, R2, R4                      ; R2 := RAM adjust
        MOV     FileOff, R4
        ADD     TransferEnd, FileOff, R3
        MOV     Fcb, R1

        LDR     R1, [Fcb,#FcbAccessHWM]
        CMPS    TransferEnd, R1
        STRHI   TransferEnd,[Fcb,#FcbAccessHWM] ; update high water mark

        CMPS    FileOff, R1
        CMPLOS  R0, #2                          ;Less than 2 <=> read 
        LDRLOB  R0, [Fcb,#FcbFlags]             ;ON READ CLEAR MONOTONIC BIT IF ACCESS BELOW HWM
        BICLO   R0, R0, #Monotonic
        STRLOB  R0, [Fcb,#FcbFlags]

        LDR     R3, [Fcb,#FcbIndDiscAdd]
        LDRB    BufSz, [Fcb,#FcbBufSz]
        MOV     R6, R3, LSR #(32-3)
        DiscRecPtr  R6, R6
        LDRB    R10,[R6,#DiscRecord_Log2SectorSize]

        CLRV                                    ;Incase the above CMPs set it by mistake

        LDRB    R0, [R6,#DiscFlags]
        TSTS    R0, #FloppyFlag
        LDRNE   R0, FloppyProcessBlk
        LDREQ   R0, WinnieProcessBlk

 [ DebugB
        DREG    R0,,cc
        DREG    R2,,cc
        DREG    R3,,cc
        DREG    BufSz,,cc
        DREG    FileOff,,cc
        DREG    R6,,cc
        DREG    TransferEnd,,cc
        DREG    Fcb,,cc
        DREG    R10,,cc
        BEQ     %FT01
        DLINE   "floppy <GetPutCommon"
        B       %FT02
01
        DLINE   "winnie <GetPutCommon"
02
 ]
        MOV     PC, LR


; ++++++++
; ExtendUp
; ++++++++

;Entry
; R0            maximum priority buffer willing to use*2(-1)
; R1            suggested end
; TransferEnd   current end
; FragEnd       maximum end

;Exit
; R1            corrupt
; TransferEnd   updated

ExtendUp ROUT
 [ DebugG
        DREG    R0,,cc
        DREG    R1,,cc
        DREG    TransferEnd,,cc
        DREG    FragEnd,,cc
        DLINE   ">ExtendUp"
 ]
        CMPS    FragEnd, R1
        MOVLO   R1, FragEnd
        CMPS    TransferEnd,R1
        MOVHS   PC, LR
        Push    "R2,R3,FileOff,R6,LR"
        MOV     FileOff,TransferEnd
10
        BL      FindSubBuf              ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        BIC     R6, FileOff, #&3FC      ;REUSING AS TEMP REGISTER
        CMPS    BufOff, #32
        LDRLO   R2, [BufPtr,#BufFlags]
        MOVLO   R3, #-1
        BLO     %FT30                   ;already have buffer
        BL      FindFreeBuf             ;(R0,FileOff,Fcb,BufPtr->R2,BufPtr,Z)
        BEQ     %FT90

        MOV     R3, R2
        STR     Fcb, [BufPtr,#BufFcb]
        STR     R6, [BufPtr,#BufFileOff]
        LDR     R2, =EmptyBuf * &01010101
30                      ;set ReadAhead flags for appropriate sub buffers
        CMPS    R6, FileOff
        CMPHSS  R1, R6
        BICHI   R2, R2, #AllBufFlags
        ORRHI   R2, R2, #ReadAhead
        MOV     R2, R2, ROR BufSz
        ADD     R6, R6, BufSz, LSL #5
        TSTS    R6, #&300
        BNE     %BT30
        BL      UpdateBufState  ;R2,BufSz,BufPtr
        MOVS    R2, R3          ;did we just claim a buffer ?
        BLPL    LinkFileChain   ;(R2,BufPtr) must be done last for write behind

        CMPS    R6, R1
        MOVLO   FileOff, R6
        BLO     %BT10
        MOVHS   FileOff, R1
90
        MOV     TransferEnd, FileOff
 [ DebugG
        DREG    R1,,cc
        DREG    TransferEnd,,cc
        DLINE   "<ExtendUp"
 ]
        Pull    "R2,R3,FileOff,R6,PC"


; ++++++++++
; ExtendDown
; ++++++++++
;entry
; R0            maximum priority buffer willing to use*2(-1)
; R1            suggested start
; R3            minimum start
; FileOff       current start

;exit
; R1            corrupt
; FileOff       updated

ExtendDown ROUT
 [ DebugG
        DREG    R0,,cc
        DREG    R1,,cc
        DREG    R3,,cc
        DREG    FileOff,,cc
        DLINE   ">ExtendDown"
 ]
        CMPS    R3, R1
        MOVHI   R1, R3
        CMPS    FileOff, R1
        MOVLS   PC, LR
        Push    "R2,R6,R7,LR"
10
        SUB     FileOff, FileOff, BufSz, LSL #5
        BL      FindSubBuf              ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        BIC     R6, FileOff, #&3FC      ;REUSING AS TEMP REGISTER
        CMPS    BufOff, #32
        LDRLO   R2, [BufPtr,#BufFlags]
        MOVLO   R7, #-1
        BLO     %FT30
        BL      FindFreeBuf             ;(R0,FileOff,Fcb,BufPtr->R2,BufPtr,Z)
        ADDEQ   FileOff, FileOff, BufSz, LSL #5
        Pull    "R2,R6,R7,PC",EQ        ;No buffer available

        MOV     R7, R2
        STR     Fcb, [BufPtr,#BufFcb]
        STR     R6, [BufPtr,#BufFileOff]
        LDR     R2, =EmptyBuf * &01010101
30                      ;set ReadAhead flags for appropriate sub buffers
        ADD     FileOff, FileOff, BufSz, LSL #5
40
        CMPS    R6, R1
        CMPHSS  FileOff, R6
        BICHI   R2, R2, #AllBufFlags
        ORRHI   R2, R2, #ReadAhead
        MOV     R2, R2, ROR BufSz
        ADD     R6, R6, BufSz, LSL #5
        TSTS    R6, #&300
        BNE     %BT40
        BL      UpdateBufState  ;R2,BufSz,BufPtr
        MOVS    R2, R7
        BLPL    LinkFileChain   ;(R2,BufPtr) must be done last for write behind

        SUB     R6, R6, #1*K
        CMPS    R1, R6
        MOVLO   FileOff, R6
        BLO     %BT10
        MOVHS   FileOff, R1
 [ DebugG
        DREG    R1,,cc
        DREG    FileOff,,cc
        DLINE   "<ExtendDown"
 ]
        Pull    "R2,R6,R7,PC"


; ============
; IncReadAhead
; ============

;entry Fcb

IncReadAhead
 [ DebugG
        DREG    R9,,cc
        DLINE   "IncReadAhead"
 ]
        Push    "R0,LR"
        LDRB    R0, [Fcb,#FcbRdAheadBufs]
        LDRB    LR, MaxFileBuffers
        CMPS    R0, LR
        ADDLO   R0, R0, #1
        STRLOB  R0, [Fcb,#FcbRdAheadBufs]
        Pull    "R0,PC"


; =====
; Flush
; =====

; entry R1 handle

Flush ROUT
        Push    "R0-R11,LR"
        LDRB    LR, MaxFileBuffers
        TEQS    LR, #0
        Pull    "R0-R11,PC",EQ

 [ DebugG
        DREG    R1,,cc
        DLINE   "Flush>"
 ]
        LDRB    LR, [R1,#FcbFlags]      ;to stop further read ahead restarts
        BIC     LR, LR, #Sequential
        STRB    LR, [R1,#FcbFlags]

        MOV     Fcb, R1

;WAIT FOR BACKGROUND PROCESSES TO FINISH
;initialisation
        LDRB    LR, [Fcb, #FcbFlags]
        TSTS    LR, #FcbFloppyFlag
        LDRNE   R0, FloppyProcessBlk
        MOVNE   R1, #FloppyLock
        LDREQ   R0, WinnieProcessBlk
        MOVEQ   R1, #WinnieLock
        BL      ClaimFileCache

;make this file's write behind buffers first to be done

        sbaddr  R2, BufChainsRoot + WriteBehindChain * ChainRootSz
        LDR     R3, = WriteBehind * &01010101
        MOV     R4, R2
        MOV     BufPtr, Fcb
        BL      LessValid
        B       %FT50

45
        LDRB    LR, [BufPtr, #BufPriority]
        TEQS    LR, #WriteBehindChain           ;IF buf has write behind left
        BLEQ    UnlinkAllocChain                ; make next youngest after R2

        LDREQ   LR, [R2,#YoungerBuf]
        STREQ   BufPtr,[LR,#OlderBuf]
        STREQ   LR, [BufPtr,#YoungerBuf]
        STREQ   R2, [BufPtr,#OlderBuf]
        STREQ   BufPtr,[R2,#YoungerBuf]
        MOVEQ   R2, BufPtr

50
        LDR     BufPtr, [BufPtr, #NextInFile]
        TEQS    BufPtr, Fcb
        BNE     %BT45
        BL      MoreValid

        EORS    R5, R2, R4      ;NE <=> some write behind left
        LDRNE   R5, FS_Flags
        ANDS    R5, R5, R1
 [ DebugI
        BEQ     %FT01
        DLINE   "C3",cc
01
 ]
        BLNE    ClaimFiq

 [ {FALSE}
;empty all buffers not involved in read ahead or write behind
        LDR     R2, = EmptyBuf * &01010101
 ]
55
        LDR     BufPtr, [BufPtr, #NextInFile]
        TEQS    BufPtr, Fcb
        BEQ     %FT70

        LDRB    LR, [BufPtr, #BufPriority]
        TEQS    LR, #ReadAheadChain
        TEQNES  LR, #WriteBehindChain

 [ {FALSE}
        BLNE    UpdateBufState          ;(R2,BufSz,BufPtr)
 ]
        BNE     %BT55

        MOV     LR, #1
        STR     LR, TickerState
        BL      ClaimController         ;(R0)
        BL      UpdateProcesses
        BL      ReleaseController       ;(R0)
        BL      ReleaseFileCache

60
        Push    "R5,Fcb,BufPtr"
        BL      BackgroundOps   ;(R0,R1->R3-R11)
        Pull    "R5,Fcb,BufPtr"
        LDRB    LR, [BufPtr, #BufPriority]
        TEQS    LR, #ReadAheadChain
        TEQNES  LR, #WriteBehindChain
        LDREQ   LR, [BufPtr, #BufFcb]
        TEQEQS  LR, Fcb
        BEQ     %BT60
        BL      ClaimFileCache
        MOV     BufPtr, Fcb
        B       %BT55

70
        BL      ReleaseFileCache
        TEQS    R5, #0
 [ DebugI
        BEQ     %FT01
        DLINE   "C3",cc
01
 ]
        BLNE    ReleaseFiq
 [ DebugG
        DLINE   "<Flush"
 ]
        Pull    "R0-R11,PC"

        LTORG

; =====================
; BackgroundFileCacheOp
; =====================

; Start a background disc transfer from/to file cache
; Controller must be claimed
; FIQ must be claimed if controller needs it

;entry
; R0 -> process control block
; R1 if R2 >0 RAM adjust for an initial direct transfer
;    if R2 =0 DiscAdjust
; R2 total length of initial transfer to buffer and initial direct transfer
; R3 DiscOp_ReadSecs / DiscOp_WriteSecs
; FileOff (R5) start offset in file
; R6 length of foreground transfer
; TransferEnd (R7) end offset in file
; FragEnd (R8) end of fragment containing file, (or file end if earlier)
; Fcb (R9)
; R10 length of initial transfer to buffer
; BufPtr (R11)

; <....FOREGROUND..........><..BACKGROUND.>

; -----------------------------------------
; |  BUFFER  |  DIRECT  |     BUFFER      |
; -----------------------------------------

; -- R10 ---->

; -- R2 ---------------->

; -- R6 ------------------->            0 <= R10 <= R2 <= R6

;exit
; R3 -> error block & V set if error
; R1 corrupt

BackgroundFileCacheOp2 ROUT
        MOV     R6, R2
BackgroundFileCacheOp1
        MOV     R10,#0
BackgroundFileCacheOp
 [ DebugH
        DLINE   "B",cc
        DREG    FileOff,,cc
        DREG    TransferEnd,,cc
        DREG    R2,,cc
 ]
        Push    "R0,R2-R6,R8,R10,R11,LR"
 [ Debug3L
        DLINE   "B",cc
 ]
 [ DebugG
        DLINE   "Proc Blk,adjust  ,Direct  ,Process ,Start  BackgroundFileCacheOp"
        DREG    R0,,cc
        DREG    R1,,cc
        DREG    R2,,cc
        DREG    R3,,cc
        DREG    R5
        DLINE   "ForeLen ,End     ,Fcb     ,Init len,BufPtr"
        DREG    R6,,cc
        DREG    R7,,cc
        DREG    R9,,cc
        DREG    R10,,cc
        DREG    R11
 ]
        BL      WaitForControllerFree   ;(R0)
        BL      LessValid

; don't think this needs changed for BigDisc - as the R6 value will only ever
; be used if R2!=0, and when R2!=0 the R6 value will be valid.  Oh well.

        ADD     R0, R0, #ProcessPairs
        ADD     R6, FileOff, R1

        ASSERT  ProcessRamAdjust=ProcessStartPtr+4
        ASSERT  ProcessStartOff=ProcessRamAdjust+4
        ASSERT  ProcessEndOff=ProcessStartOff+4
        ASSERT  ProcessFragEnd=ProcessEndOff+4
        ASSERT  ProcessFcb=ProcessFragEnd+4
        ASSERT  ProcessError=ProcessFcb+4
        ASSERT  ProcessStatus=ProcessError+4
        ASSERT  ProcessPairs=ProcessStatus+4
        ASSERT  TransferEnd=R7
        ASSERT  FragEnd=R8
        ASSERT  Fcb=R9

        MOV     R10,#0
        MOV     LR, #Active :OR: CanExtend
 [ DebugG
        DREG    R0,,cc
        DREG    R1,,cc
        DREG    FileOff,,cc
        DREG    TransferEnd,,cc
        DREG    FragEnd,,cc
        DREG    Fcb,,cc
        DREG    R10,,cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0
        Pull    "r0"
 ]
        STMDB   R0, {R0,R1,FileOff,TransferEnd,FragEnd,Fcb,R10,LR}

        LDRB    R1, MaxFileBuffers
 [ {TRUE}
 ; If pair extension disabled then number of entries must be 4*MaxFileBuffers
        MOV     R1, R1, ASL #2
 ]
        ADD     R1, R1, #ExtraPairs
        MOV     R1, R1, LSL #3
        BL      ZeroRam     ;(R0,R1)
        RSB     LR, R1, #0
        STR     LR, [R0, R1]    ;loop marker at end of pairs

        LDR     R1, [SP, #7*4]  ;entry R10, length initial transfer to buffer
        TEQS    R1, #0
        BLNE    %FT50           ;build scatter list for initial transfer

        SUBS    LR, R2, R1      ; is there any direct transfer to do?
        ADDNE   R6, R6, R1
 [ DebugG
        BEQ     %FT01
        DREG    R6,,cc
        DREG    LR,,cc
        DLINE   "direct (add,len)"
01
 ]
 [ DebugGs
        BEQ     %FT01
        DREG    R6," +",cc
        DREG    LR,",",cc
01
 ]
        STMNEIA R0!,{R6,LR}             ; yes, so chuck it in the scatter list.  R6 is the RAM addr
        ADDNE   FileOff, FileOff, LR    ; and update FileOff

        SUBS    R1, TransferEnd, FileOff        ; is there any background transfer to do?
        BLNE    %FT50                   ; if yes, place into scatter list
        LDR     LR, [R0]                ; if at end of scatter list then back to start
      [ FixTBSAddrs
        CMN     LR, #ScatterListNegThresh
        ADDCS   R0, R0, LR
      |
        TEQS    LR, #0
        ADDMI   R0, R0, LR
      ]

        MOV     R1, R3                  ; operation to do
        MOV     R3, R0                  ; scatter list ptr
        ASSERT  Process=0
        ASSERT  ProcessDirect = Process+1
        ASSERT  ProcessDrive = ProcessDirect + 1
        ASSERT  ProcessEndPtr=Process+4
        ASSERT  ProcessOldLength=ProcessEndPtr+4
        MOVS    R0, R2
        MOVNE   R0, #&FF00
        ORR     R0, R0, #Inactive
        ORR     R0, R0, #&FF0000
        LDR     R4, [SP]                        ;process block
        LDR     LR, [R4,#ProcessPairs+4]        ;first length
        STMIA   R4, {R0,R3,LR}

 [ BigDisc
        BNE     %FT30                           ;choose code on R2 value
        LDR     LR, [R4,#ProcessRamAdjust]      ;actually disc adjust

        ORR     R1, R1, #DiscOp_Op_BackgroundOp_Flag :OR: DiscOp_Op_IgnoreEscape_Flag :OR: DiscOp_Op_ScatterList_Flag
        ADD     R3, R4, #ProcessPairs
        LDR     R5, [SP,#4*4]   ;entry FileOff
        LDR     R10, [Fcb, #FcbIndDiscAdd]
        MOV     R10, R10, LSR #(32-3)
        DiscRecPtr R10,R10

        LDRB    R10, [R10, #DiscRecord_Log2SectorSize]
        ADD     R2, LR, R5, LSR R10
        LDR     R4, [SP,#5*4]   ;entry R6, foreground length
        BL      RetryDiscOp     ;(R1-R4->R0,R2-R4,V)
        B       %FT40
30
        ORR     R1, R1, #DiscOp_Op_BackgroundOp_Flag :OR: DiscOp_Op_IgnoreEscape_Flag :OR: DiscOp_Op_ScatterList_Flag
        ADD     R3, R4, #ProcessPairs
        LDR     R2, [Fcb,#FcbIndDiscAdd]
        LDR     R5, [SP,#4*4]   ;entry FileOff
        LDR     R4, [SP,#5*4]   ;entry R6, foreground length
        BL      GenIndDiscOp    ;(R1-R5->R0,R3-R5,V)

40
 |
        LDREQ   LR, [R4,#ProcessRamAdjust]      ;actually disc adjust
        ORR     R1, R1, #DiscOp_Op_BackgroundOp_Flag :OR: DiscOp_Op_IgnoreEscape_Flag :OR: DiscOp_Op_ScatterList_Flag
        ADD     R3, R4, #ProcessPairs
        LDRNE   R2, [Fcb,#FcbIndDiscAdd]
        LDR     R5, [SP,#4*4]   ;entry FileOff
        ADDEQ   R2, R5, LR
        LDR     R4, [SP,#5*4]   ;entry R6, foreground length
        BLNE    GenIndDiscOp    ;(R1-R5->R0,R3-R5,V)
        BLEQ    RetryDiscOp     ;(R1-R4->R0,R2-R4,V)
 ]
        STRVS   R0, [SP, #2*4]  ;exit R3
        BL      MoreValid
 [ Debug3L
        DLINE   "b",cc
 ]
        Pull    "R0,R2-R6,R8,R10,R11,PC"


;build scatter list
;entry
; R0 -> next entry in scatter block
; R1 length > 0
; FileOff
; BufPtr

;exit
; R0,FileOff updated
; R4,R8,R10 corrupt

50
 [ DebugG
        DREG    R0,,cc
        DREG    R1,,cc
        DREG    FileOff,,cc
        DLINE   "scatter ptr, length, FileOff"
 ]

        Push    "R1,R6,LR"

        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        MOV     R8, #1*K
60
 [ DebugJ
        LDR     R4, [BufPtr,#BufFcb]
        TEQS    R4, Fcb
        BEQ     %FT65

        DLINE   "BAD BUF",cc
 regdump
        MOV     PC, #0
65
 ]
        ADD     R4, BufPtr, #BufferData
        ADD     R4, R4, BufOff, LSL #5
        SUB     R6, R8, BufOff, LSL #5
        SUBS    R1, R1, R6
        ADDLO   R6, R1, R6
 [ DebugG
        DREG    R4,,cc
        DREG    R6,,cc
        DLINE   "(add,len)"
 ]
 [ DebugGs
        DREG    R4," +",cc
        DREG    R6,",",cc
;        DLINE   ")",cc
 ]
        STMIA   R0!,{R4,R6}
        ADD     FileOff, FileOff, R6
        MOVHI   BufOff, #0
        LDRHI   BufPtr, [BufPtr,#NextInFile]
        BHI     %BT60
        Pull    "R1,R6,PC"


; =============
; BackgroundOps
; =============

; Extend or restart read ahead / write behind
; caller must have checked there is at least one open file on this controller

;entry
; R0 -> controller process block
; R1 appropriate Floppy/winnie lock bit

;exit
; R3-R11 corrupt

BackgroundOps ROUT
        LDRB    R6, Interlocks

        Push    "R0-R2,LR"
        SavePSR lr
        TSTS    R6, R1
        BEQ     %FT00
        RestPSR lr,,f
        Pull    "R0-R2,PC"              ;give up if another thread owns the controller

00
        WritePSRc SVC_mode, R5,,LR      ;ensure IRQs enabled, old PSR into LR
        Push    "lr"
 [ {FALSE}                              ;FOR DEBUGGING
        ; Return if IRQsema set
        LDR     LR, ptr_IRQsema
        LDR     LR, [LR]
        TEQS    LR, #0
        BNE     BackgroundOpsExit
 ]
 [ DebugG
        DREG    r0,">BackgroundOps(",cc
        DREG    r1,",",cc
        DLINE   ")"
        Push    "r0"
        MOV     r0, sp
        DREG    r0,"                       sp="
        Pull    "r0"
 ]
        ORR     R1, R6, R1, LSL #30
        ORR     R6, R6, R1, LSR #30     ;claim controller
        ORR     R6, R6, #FileCacheLock  ;and ensure file cache claimed
        STRB    R6, Interlocks

        TSTS    R1, #FileCacheLock
        BLEQ    UpdateProcess           ;(R0)

 [ {FALSE}                              ;FOR DEBUGGING
        LDR     LR, ptr_IRQsema
        LDR     LR, [LR]
        TEQS    LR, #0
        STRNEB  R1, Interlocks
        BNE     BackgroundOpsExit
 ]

        LDRB    R5, [R0,#Process]
        TSTS    R5, #Inactive
 [ DebugG
        BEQ     %FT01
        DLINE   "Process inactive"
01
 ]
        BNE     %FT31

 [ DebugG
        DLINE   "BackgroundOps: process active"
 ]
        TSTS    R1, #FileCacheLock
        TSTEQS  R5, #WriteBehind        ;all write behind extension is done in
 [ DebugG
        BEQ     %FT01
        DLINE   "FileCacheLocked or WriteBehind"
01
 ]
        BNE     %FT90                   ;foreground

;CURRENTLY READING AHEAD, EXTEND IF NEEDED
        LDR     Fcb,[R0,#ProcessFcb]
        LDRB    R5, [Fcb,#FcbFlags]
        TSTS    R5, #Sequential         ;give up if not sequential
        LDRNE   R5, [R0,#ProcessStatus]
        TSTNES  R5, #CanExtend
        LDRNE   FragEnd, [R0, #ProcessFragEnd]
        LDRNE   FileOff,[R0,#ProcessEndOff]
        TEQNES  FragEnd, FileOff        ;or no more in fragment
        BEQ     %FT90

        BL      FcbCommon               ;Fcb -> R2, R3, BufSz, LR, C
        BCS     %FT90

;CHECK WHETHER ENOUGH ALREADY READ AHEAD

;(R2,BufSz,FileOff,FragEnd,Fcb->FileOff,TransferEnd,BufOff,BufPtr)
        BL      ReadAheadCommon
        BVS     %FT90
        SUB     R6, TransferEnd, FileOff
        BL      LessValid
19
        CMPS    BufOff, #32             ;have we already got buffer ?
        MOVLO   R2, BufPtr
        BLO     %FT22
        MOV     R7, R0
        MOV     R0, #NormalChain*2
        BL      FindFreeBuf             ;(R0,FileOff,Fcb,BufPtr->R2,BufPtr,Z)
        BEQ     %FT25
        MOV     R0, R7
        BIC     LR, FileOff, #&3FC
        STR     LR, [BufPtr,#BufFileOff]
        STR     Fcb, [BufPtr,#BufFcb]
        AND     BufOff, FileOff, #&300
        MOV     BufOff, BufOff, LSR #5
22
        MOV     R3, #1*K
        SUB     R3, R3, BufOff, LSL #5
        CMPS    R6, R3
        MOVLS   R3, R6
        BL      AddBuffer               ;(R0,R3,FileOff,BufOff,BufPtr->FileOff,C)
        TEQS    BufPtr,R2
        BCC     %FT28
 [ DebugH
        DLINE   "rbx ",cc         ;Read Background eXtend
 ]

        MOV     R7, R2
        LDRNE   R2, =EmptyBuf * &01010101
        LDREQ   R2, [BufPtr,#BufFlags]
        MOV     R2, R2, ROR BufOff
        MOV     LR, R3, LSR #5
        ADD     BufOff, BufOff, LR
23
        BIC     R2, R2, #AllBufFlags
        ORR     R2, R2, #ReadAhead
        MOV     R2, R2, ROR BufSz
        SUBS    LR, LR, BufSz
        BGT     %BT23           ;Loop for each sub-buffer

        RSB     LR, BufOff, #32
        MOV     R2, R2, ROR LR
        BL      UpdateBufState          ;(R2,BufSz,BufPtr)

        TEQS    BufPtr,R7
        MOVNE   R2, R7
        BLNE    LinkFileChain           ;(R2,BufPtr)

        MOV     LR, #1                  ;set background period to 1 tick on success
        STR     LR, TickerState
        SUBS    R6, R6, R3              ;see if more buffers needed to fulfil (TransferEnd - FileOff) bytes
        BLGT    FindSubBuf              ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        BGT     %BT19
25
        BL      MoreValid
        B       %FT90

28
        LDRNE   R2, =EmptyBuf * &01010101
        BLNE    UpdateBufState          ;(R2,BufSz,BufPtr)
        B       %BT25

;CURRENTLY INACTIVE, RESTART IF NEEDED
31
 [ DebugG
        DLINE   "Consider restarting some write behind"
 ]
;CONSIDER RESTARTING SOME WRITE BEHIND
        sbaddr  R7, BufChainsRoot + ( WriteBehindChain * ChainRootSz )
        MOV     BufPtr, R7
        AND     R5, R1, #FloppyLock :SHL: 30    ;mask to floppy bit
        MOV     Fcb, #NIL
34
        ; Move on a buffer and check for end of list
        LDR     BufPtr, [BufPtr, #YoungerBuf]
        TEQS    BufPtr, R7
        BEQ     %FT52

 [ DebugG
        DLINE   "Check a write behind buffer...",cc
 ]
        ; Skip buffer if it's in the same file as the previous buffer which was unsuitable
        LDR     LR, [BufPtr,#BufFcb]
        TEQS    Fcb, LR
 [ DebugG
        BNE     %FT01
        DLINE   "same Fcb as previous duff buffer"
01
 ]
        BEQ     %BT34

        ; Assume this buffer is unsuitable, unless...
        MOV     Fcb, LR

        ; Skip if on wrong controller
        LDRB    LR, [Fcb,#FcbFlags]
        ANDS    LR, LR, #FcbFloppyFlag
        MOVNE   LR, #FloppyLock :SHL: 30
        EORS    LR, R5, LR
 [ DebugG
        BEQ     %FT01
        DLINE   "wrong controller"
01
 ]
        BNE     %BT34           ;wrong controller

        ; Skip if map under modification
        BL      FcbCommon       ;Fcb -> R2, R3, BufSz, LR, C
 [ DebugG
        BCC     %FT01
        DLINE   "map under modification"
01
 ]
        BCS     %BT34            ;map being modified

        ; Check restartability based on locked/write behind drives
        BL      RestartCheck    ;R2,R3->LS/HI
 [ DebugG
        BLS     %FT01
        DLINE   "unrestartable from RestartCheck"
01
 ]
        BHI     %BT34

 [ DebugG
        DLINE   "good buffer, go for it"
 ]

        ; Pull in the map
        BL      R3LoadNewMap    ;(R3,BufSz,Fcb->R8,V)
        BVC     %FT35

 [ DebugG
        DLINE   "Cockup loading map"
 ]

        ; Oops, cockup - clean up and return/try again
        TSTS    R1, #FileCacheLock
        BNE     %FT90
        MOV     R3, #WriteBehind
        BL      BackgroundTidyUp        ;(R0,R3,BufSz,Fcb)
        B       %BT34

35
 [ DebugG
        DLINE   "Map in"
 ]
        ; Got the map, start it up..
        LDR     LR, FS_Flags
        ASSERT  WinnieLock = CreateFlag_FixedDiscNeedsFIQ
        ASSERT  FloppyLock = CreateFlag_FloppyNeedsFIQ
        TSTS    LR, R1, LSR #30
 [ DebugI
        BEQ     %FT01
        DLINE   "B1 ",cc
01
 ]
        BLNE    BackgroundClaimFiq      ;(->Z)
 [ DebugI
        BEQ     %FT01
        DLINE   "B1F ",cc
01
 ]
        BNE     %FT90                   ;give up restarting if need FIQ but cant get it

 [ DebugG
        DLINE   "Sort out the buffers"
 ]

        LDR     FileOff, [BufPtr,#BufFileOff]
        MOV     BufOff, #0
37
        LDR     R8, [BufPtr,BufOff,LSR #3]
        TSTS    R8, #WriteBehind
        ADDEQ   BufOff, BufOff, BufSz
        ADDEQ   FileOff, FileOff, BufSz, LSL #5
        MOVEQ   R8, R8, ROR BufSz
        BEQ     %BT37

        Push    "R0,R1"
        MOV     R3, R0
        BL      DefFileFrag     ;FileOff,Fcb -> R0,DiscAdjust,FragEnd
        MOV     R1, DiscAdjust
        Push    "FileOff,BufOff,BufPtr"

        BL      SkipWriteBehind          ;BufSz, FileOff, FragEnd, BufOff, BufPtr -> FileOff, BufOff, BufPtr
        MOV     TransferEnd, FileOff
        Pull    "FileOff,BufOff,BufPtr"

        BL      BackwardsSkipWriteBehind ;R0,BufSz,FileOff,BufOff,BufPtr->FileOff,BufOff,BufPtr

 [ DebugH
        DLINE   "WBR ",cc
 ]
        MOV     R0, R3
        MOV     R2, #0
        MOV     R3, #DiscOp_WriteSecs
;R0-R3,FileOff,TransferEnd,FragEnd,Fcb,BufPtr -> R1,R3,R6,R10,V
        BL      BackgroundFileCacheOp2
        Pull    "R0,R1"
 [ DebugG
        DLINE   "Got back from BackgroundFileCacheOp2"
 ]
        MOV     LR, #1                  ;set background period to 1 tick on success
        STR     LR, TickerState
        LDR     LR, FS_Flags
        ASSERT  WinnieLock = CreateFlag_FixedDiscNeedsFIQ
        ASSERT  FloppyLock = CreateFlag_FloppyNeedsFIQ
        TSTS    LR, R1, LSR #30
 [ DebugI
        BEQ     %FT01
        DLINE   " R4 ",cc
01
 ]
        BLNE    ReleaseFiq              ;cancel extra claim, see RetryDriveOp
        B       %FT90

;CONSIDER RESTARTING SOME READ AHEAD

52
        TSTS    R1 ,#FileCacheLock
        BNE     %FT90

        sbaddr  R6, BufChainsRoot + NormalChain * ChainRootSz
        LDR     LR, [R6, #YoungerBuf]
        TEQS    LR, R6

        SUBEQ   R6, R6, #(NormalChain-MonotonicChain)*ChainRootSz
        LDREQ   LR, [R6, #YoungerBuf]
        TEQEQS  LR, R6

        SUBEQ   R6, R6, #(MonotonicChain-EmptyChain)*ChainRootSz
        LDREQ   LR, [R6, #YoungerBuf]
        TEQEQS  LR, R6

 [ {TRUE}
        BLEQ    TestFileCacheGrowable
        MOVEQ   r6, #0
 |
        LDREQB  R6, UnclaimedFileBuffers        ;R6=0 <=> no suitable buffers
 ]

        sbaddr  Fcb, FirstFcb-FcbNext
55
        LDR     Fcb, [Fcb,#FcbNext]
        CMPS    Fcb, #-1
        LDRNEB  LR, [Fcb,#FcbFlags]
        TSTNES  LR, #Sequential
        LDRNEB  R5, [Fcb, #FcbExtHandle]
        TEQNES  R5, #0
        BEQ     %FT90

        ; Don't do it if FloppyFlag doesn't match FloppyLock, ie
        ; if it's for the wrong controller
        AND     LR, LR, #FcbFloppyFlag
        AND     R5, R1, #FloppyLock :SHL: 30
        ASSERT  FcbFloppyFlag = FloppyLock :SHL: 1
        TEQS    LR, R5, LSR #(30-1)
        BNE     %BT55                   ;wrong controller

        LDR     FileOff, [Fcb,#FcbLastReadEnd]
        TSTS    FileOff, #&300          ;if extension would need another buffer
        TEQEQS  R6, #0                  ;and no suitable buffers available
        BEQ     %BT55                   ;then loop for next file

        BL      FcbCommon               ;Fcb -> R2, R3, BufSz, LR, C
        BCS     %BT55

        BL      RestartCheck            ;R2,R3->LS/HI
        BHI     %BT55

        LDR     BufPtr, [Fcb,#PrevInFile]
        BL      FindSubBuf              ;(FileOff,Fcb,BufPtr->BufPtr,BufOff)
        LDR     FragEnd, [Fcb, #FcbAllocLen]
      [ BigFiles
        TEQ     FragEnd, #RoundedTo4G
        MOVEQ   FragEnd, #&FFFFFFFF
      ]
        Push    "FileOff,BufOff,BufPtr"
        BL      ScanBuffers             ;FileOff,FragEnd,BufSz,BufOff,BufPtr->FileOff,BufOff,BufPtr, LO/EQ(/HI)
        Pull    "FileOff,BufOff,BufPtr",HS
        ADDLO   SP, SP, #3*4

        MOV     FragEnd, #-1
;R2,BufSz,FileOff,FragEnd,Fcb,BufOff,BufPtr->TransferEnd,FragEnd,BufOff,BufPtr
        BL      ReadAheadCommon
        BVS     %BT55

        LDR     R3, [Fcb,#FcbIndDiscAdd]
        BL      R3LoadNewMap            ;(R3,BufSz,Fcb->R8,V)
        MOVVS   R3, #WriteBehind
        BLVS    BackgroundTidyUp        ;(R0,R3,BufSz,Fcb)
        BVS     %BT55

        Push    "R0,R1,FileOff"
        BL      DefFileFrag     ;FileOff,Fcb -> R0,DiscAdjust,FragEnd
        CMPS    TransferEnd, FragEnd
        MOVHI   TransferEnd, FragEnd
        CMPS    FileOff, TransferEnd    ;IF reached file end then clear
        LDRHSB  LR, [Fcb, #FcbFlags]    ; sequential to prevent restarts. May not
        BICHS   LR, LR, #Sequential     ; succeed immediately if FcbFlags is being
 [ DebugG
        BLO     %FT01
        DLINE   "clearing sequential (end of transfer)"
01
 ]
        STRHSB  LR, [Fcb, #FcbFlags]    ; modified in foreground but this is ok
        ADDHS   SP, SP, #3*4
        BHS     %FT90

        LDR     LR, FS_Flags
        ASSERT  WinnieLock = CreateFlag_FixedDiscNeedsFIQ
        ASSERT  FloppyLock = CreateFlag_FloppyNeedsFIQ
        TSTS    LR, R1, LSR #30
 [ DebugI
        BEQ     %FT01
        DLINE   "B2 ",cc
01
 ]
        BLNE    BackgroundClaimFiq      ;(->Z)
        ADDNE   SP, SP, #3*4
 [ DebugI
        BEQ     %FT01
        DLINE   "B2F ",cc
01
 ]
        BNE     %FT90                   ;give up restarting if need FIQ but cant get it

        BL      LessValid
58
        CMPS    BufOff, #32
        LDRLO   R2, [BufPtr, #BufFlags]
        MOVLO   R1, #-1
        BLO     %FT61                   ;already got buffer

        MOV     R0, #NormalChain*2
        BL      FindFreeBuf             ;(R0,FileOff,Fcb,BufPtr->R2,BufPtr,Z)
        BEQ     %FT67
        MOV     R1, R2
        BIC     LR, FileOff, #&3FC
        STR     LR, [BufPtr,#BufFileOff]
        STR     Fcb, [BufPtr,#BufFcb]
        AND     BufOff, FileOff, #&300
        MOV     BufOff, BufOff, LSR #5
        LDR     R2, = EmptyBuf * &01010101
61
        MOV     R3, #&FF
        MOV     LR, #ReadAhead
64
        BIC     R2, R2, R3, LSL BufOff
        ORR     R2, R2, LR, LSL BufOff
        ADD     BufOff, BufOff, BufSz
        ADD     FileOff, FileOff, BufSz, LSL #5
        CMPS    BufOff, #32
        CMPLO   FileOff, TransferEnd
        BLO     %BT64
        BL      UpdateBufState  ;R2,BufSz,BufPtr

        MOVS    R2, R1
        BLPL    LinkFileChain           ;(R2,BufPtr)
        MOV     LR, #1                  ;set background period to 1 tick on success
        STR     LR, TickerState
        CMPS    FileOff, TransferEnd
        BLLO    FindSubBuf              ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        BLO     %BT58
67
        BL      MoreValid
        MOV     TransferEnd, FileOff
        LDMIA   SP, {R0,R1,FileOff}
        CMPS    FileOff, TransferEnd
        MOVLO   R1, DiscAdjust
        MOVLO   R2, #0
        MOVLO   R3, #DiscOp_ReadSecs
 [ DebugH
        BHS     %FT01
        DLINE   "rbr ",cc      ;Read Background Restart
01
 ]
;R0-R3,FileOff,TransferEnd,FragEnd,Fcb,BufPtr -> R1,R3,R6,R10,V
        BLLO    BackgroundFileCacheOp2
        Pull    "R0,R1,FileOff"
        MOV     LR, #1                  ;set background period to 1 tick on success
        STR     LR, TickerState
        LDR     LR, FS_Flags
        ASSERT  WinnieLock = CreateFlag_FixedDiscNeedsFIQ
        ASSERT  FloppyLock = CreateFlag_FloppyNeedsFIQ
        TSTS    LR, R1, LSR #30
 [ DebugI
        BEQ     %FT01
        DLINE   " R5 ",cc
01
 ]
        BLNE    ReleaseFiq              ;cancel extra claim, see RetryDriveOp

90
        STRB    R1, Interlocks          ;interlocks owned on entry
 [ DebugG
        Push    "r0"
        MOV     r0, sp
        DREG    r0,"<BackgroundOps   sp="
        Pull    "r0"
 ]
BackgroundOpsExit
        Pull     "r0"
        BIC      r0, r0, #V_bit
        RestPSR  r0,,cf                 ;restore flags exc. V clear.  May re-disable IRQs/FIQs too.
        Pull    "R0-R2,PC"


 LTORG

 [ {TRUE}
; =====================
; TestFileCacheGrowable
; =====================

; Returns EQ for not growable (now) and NE for growable now

TestFileCacheGrowable ROUT
        Push    "r0,r8,r9,r10,r11,lr"
        LDREQB  R0, UnclaimedFileBuffers        ;R6=0 <=> no suitable buffers
        TEQ     r0, #0
        BEQ     %FT90

        SETPSR  I_bit, R0,, R9                  ;disable IRQ
        AND     R9, R9, #2_11111
        LDRB    R0, Interlocks
        EOR     R0, R0, #DirCacheLock
        TSTS    R0, #DirCacheLock
        LDRNEB  LR, Flags
        TSTNES  LR, #CacheGood
        ORREQ   R9, R9, #Z_bit
        RestPSR R9,EQ,cf                        ;if EQ reenable IRQ maintaining Z=1
        BEQ     %FT90
        STRB    R0, Interlocks  ;lock dir cache
        RestPSR R9,,cf          ;reenable IRQ

        LDR     R8, FileBufsStart
        SUB     R8, R8, #1*K
        SUB     R8, R8, #BufferData+CacheMin

00
;LOOP TO FIND LAST DIR IN CACHE
        sbaddr  R11,RootCache
        MOV     R10,R11
        MOV     R0, R11
05
        LDR     R11,[R11,#CacheYounger]
        ADD     R11,SB, R11
        CMPS    R11,R0
        MOVHI   R0, R11
        TEQS    R11,R10
        BNE     %BT05

        TEQS    R0, R10
        sbaddr  R10,DirCache, EQ
        LDRNE   R10,[R0,#CacheNext]
        ADDNE   R10,SB, R10
        SUBS    LR, R8, R10
        CMPGTS  LR, #CacheMin
        BGE     %FT45           ; no obstructing dir

        LDRB    LR, ReEntrance  ;cant be done if foregound threaded in
        TEQS    LR, #0
        LDRNE   LR, ptr_IRQsema
        LDRNE   LR, [LR]        ;and entering from background
        TEQNES  LR, #0
        TOGPSR  Z_bit, LR
        BEQ     %FT80

45
        CMP     pc, #0                  ; NE => OK to extend

80
        BL      UnlockDirCache

90
        Pull    "r0,r8,r9,r10,r11,pc"
 ]

; =========
; FcbCommon
; =========

;Entry Fcb (R9)

;Exit
; CS <=> not worth considering further
; R2 drive
; R3 ind disc add of file
; BufSz (R4)
; LR disc rec

FcbCommon ROUT
 [ DebugG
        DREG    R9,,cc
        DLINE   ">FcbCommon"
 ]
        Push    "R0,LR"
        LDR     R3, [Fcb,#FcbIndDiscAdd]
        LDRB    R0, ModifyDisc
        CMPS    R0, R3, LSR #(32-3)
        Pull    "R0,PC",EQ              ;return CS if map under modification
        BL      DiscAddToRec            ;(R3->LR)

        LDRB    BufSz, [Fcb, #FcbBufSz]

        LDRB    R2, [LR,#DiscsDrv]
        CMPS    R2, #8                  ;   or disc probably not in drive
 [ DebugG
        BCS     %FT01
        DREG    R2,,cc
        DREG    R3,,cc
        DREG    R4,,cc
01
        DLINE   "<FcbCommon"
 ]
        Pull    "R0,PC"


; ===============
; ReadAheadCommon
; ===============

;check some of details on whether read ahead is desirable and possible
;and claim buffers where necessary

;entry
; R2 drive
; BufSz (R4)
; FileOff (R5) start offset for read ahead
; FragEnd (R8) may be -1 if not known yet
; Fcb (R9)
; BufOff (R10) set up if FragEnd = -1
; BufPtr (R11) set up if FragEnd = -1

;exit V set if read ahead uneccessary or impossible
; TransferEnd (R7) suggested end for read ahead
; FragEnd corrupt if was -1
; BufOff (R10) & BufPtr (R11) set up from FileOff if FragEnd was <> -1 on entry

ReadAheadCommon ROUT
        Push    "R0-R3,LR"

;CHECK WHETHER ENOUGH ALREADY READ AHEAD

        LDR     TransferEnd, [Fcb,#FcbLastReadEnd]
        TSTS    TransferEnd, #&3FC
        BICNE   TransferEnd, TransferEnd, #&3FC
        ADDNE   TransferEnd, TransferEnd, #&400
        LDRB    LR, [Fcb,#FcbRdAheadBufs]
        ADD     TransferEnd, TransferEnd, LR, LSL #10
      [ BigFiles
        CMP     FragEnd, #-1
        MOVNE   LR, FragEnd
        LDREQ   LR, [Fcb, #FcbAllocLen]
        TEQEQ   LR, #RoundedTo4G
        MOVEQ   LR, #&FFFFFFFF          ;For later comparisons
      |
        MOVS    LR, FragEnd
        LDRMI   LR, [Fcb,#FcbAllocLen]
      ]
        CMPS    TransferEnd, LR
        MOVHI   TransferEnd, LR
        CMPS    FileOff, TransferEnd
        BHS     %FT90

;CHECK THAT EMPTY SUB BUFFERS FOLLOW END OF READ AHEAD
        CMPS    FragEnd, #-1
        LDRNE   BufPtr, [Fcb,#PrevInFile]
        BLNE    FindSubBuf              ;FileOff,Fcb,BufPtr -> BufOff,BufPtr

        Push    "FileOff,BufOff,BufPtr"
        LDREQ   FragEnd,[Fcb,#FcbAllocLen]
      [ BigFiles
        TEQEQ   FragEnd, #RoundedTo4G
        MOVEQ   FragEnd, #&FFFFFFFF
      ]
        BL      SkipEmpty               ;BufSz,FileOff,FragEnd,BufOff,BufPtr->FileOff,BufOff,BufPtr
        CMPS    FileOff, TransferEnd
        MOVLO   TransferEnd, FileOff
        Pull    "FileOff,BufOff,BufPtr"
        CMPS    TransferEnd, FileOff
        BLS     %FT90                   ;No empty sub bufs after read ahead end

;CHECK THAT KNOW WHERE DISC IS
        MOV     R1, R2
        DrvRecPtr  R2, R1
        LDR     R2, [R2,#ChangedSeqNum]
        BL      LowPollChange
        TSTS    R3, #MiscOp_PollChanged_NotChanged_Flag
        BEQ     %FT80
        CMPS    R0, R0          ;clear V
        Pull    "R0-R3,PC"

80                              ;IF uncertain where disc is then clear
        LDRB    LR, [Fcb, #FcbFlags]    ; sequential to prevent restarts. May not
        BIC     LR, LR, #Sequential     ; succeed immediately if FcbFlags is being
        STRB    LR, [Fcb, #FcbFlags]    ; modified in foreground but this is ok
90
        BL      SetV
        Pull    "R0-R3,PC"


; ++++++++++++
; RestartCheck
; ++++++++++++

;entry
; R2 drive
; R3 file ind disc add

;exit HI <=> Restart impossible

RestartCheck
        Push    "R2,R3,R5,LR"

 [ DriveStatus
        ; get drive status
        Push    "R0,R1,R2"
        MOV     R1, R2
        BL      GetDriveStatus          ; (R1->R2,LR)
        BVS     %FT10
        CMP     LR, #0                  ; check status supported
        BEQ     %FT10                   ; not supported
        ANDS    LR, R2, #MiscOp_DriveLocked_Flag ; check for drive reservation
        Pull    "R0,R1,R2"
 [ DebugDL
        BLS     %FT01
        DLINE   "RestartCheck: Drive reserved"
01
 ]
        Pull    "R2,R3,R5,PC",HI        ; drive reserved, come back later
 [ DebugDL
        DLINE   "RestartCheck: Drive not reserved"
 ]
        B       %FT20
10
 [ DebugDL
        DLINE   "RestartCheck: DriveStatus not supported or error"
 ]
        Pull    "R0,R1,R2"
20
 ]
                        ;IF
        LDRB    R5, LockedDrive
        RSBS    LR, R5, #&ff    ; there is a locked drive (HI=CS+NE)
        EORHI   LR, R5, R2
        EORHI   LR, LR, #bit2
        TSTHI   LR, #bit2       ; on the same controller (HI=CS+NE)
        TEQHI   R5, R2          ; which is a different drive (HI=CS+NE)
        Pull    "R2,R3,R5,PC",HI ;  THEN return HI
                        ; OR
        TST     R2, #bit2
        LDREQ   R5, WinnieProcessBlk
        LDRNE   R5, FloppyProcessBlk
        LDRB    R5, [R5, #ProcessWriteBehindDrive]
        RSBS    LR, R5, #&FF    ;      there is a write behind drive
        TEQHIS  R5, R2          ;  AND it is a different drive
        Pull    "R2,R3,R5,PC";  THEN return HI


; >>>>>>>>>>>>
; FloppyOpDone
; >>>>>>>>>>>>

FloppyOpDone ROUT
 [ DebugG
        DLINE   "FloppyOpDone"
        Push    "r0"
        DLINE   "Regs into FloppyOpDone:"
        DREG    r0,,cc
        DREG    r1,,cc
        DREG    r2,,cc
        DREG    r3,,cc
        DREG    r4,,cc
        DREG    r5,,cc
        DREG    r6,,cc
        DREG    r7
        DREG    r8,,cc
        DREG    r9,,cc
        DREG    r10,,cc
        DREG    r11,,cc
        DREG    r12,,cc
        MOV     r0, r13
        DREG    r0,,cc
        MOV     r0, r14
        DREG    r0
        Pull    "r0"
 ]
        Push    "R0-R11,LR"
        SavePSR R0
        Push    R0
        getSB

        LDR     R0, FloppyProcessBlk
        MOV     R1, #FloppyLock
 [ DebugGs
        DLINE   "D>"
 ]
        BL      BackgroundOps                   ;(R0,R1->R3-R11)

        LDRB    R2, Interlocks
        TSTS    R2, #NoOpenWinnie
        LDREQ   R0, WinnieProcessBlk
        MOVEQ   R1, #WinnieLock
        BLEQ    BackgroundOps                   ;(R0,R1->R3-R11)

        Pull    R0
        RestPSR R0,,f
 [ DebugG
        Pull    "R0-R11,LR"
        Push    "r0"
        DLINE   "Regs out of FloppyOpDone:"
        DREG    r0,,cc
        DREG    r1,,cc
        DREG    r2,,cc
        DREG    r3,,cc
        DREG    r4,,cc
        DREG    r5,,cc
        DREG    r6,,cc
        DREG    r7
        DREG    r8,,cc
        DREG    r9,,cc
        DREG    r10,,cc
        DREG    r11,,cc
        DREG    r12,,cc
        MOV     r0, r13
        DREG    r0,,cc
        MOV     r0, r14
        DREG    r0
        Pull    "r0"
        MOV     PC, LR
 |
        Pull    "R0-R11,PC"
 ]


; >>>>>>>>>>>>
; WinnieOpDone
; >>>>>>>>>>>>

WinnieOpDone ROUT
        Push    "R0-R11,LR"
        SavePSR R0
        Push    R0
 [ DebugG
        DLINE   "WinnieOpDone"
 ]
        getSB

        LDR     R0, WinnieProcessBlk
        MOV     R1, #WinnieLock
        BL      BackgroundOps                   ;(R0,R1->R3-R11)

        LDRB    R2, Interlocks
        TSTS    R2, #NoOpenFloppy
        LDREQ   R0, FloppyProcessBlk
        MOVEQ   R1, #FloppyLock
        BLEQ    BackgroundOps                   ;(R0,R1->R3-R11)

        Pull    R0
        RestPSR R0
        Pull    "R0-R11,PC"


; >>>>>>>>>>>
; TickerEntry
; >>>>>>>>>>>

; Each tick decrement count and process the BackgroundOps if reached 0
;
; If countdown occurs with TimerLock set then increase the countdown
; period by 1 tick.
;
; Period and Countdown are held in TickerState as follows:
;   TickerState = &ccccpppp
; where cccc is the countdown and pppp is the period.
;
TickerEntry ROUT
        Push    "R2,R3,LR"
        ; This code actually counts down the counter as per spec
        LDR     R3, TickerState
        SUBS    R3, R3, #1 :SHL: 16
        STRHS   R3, TickerState
        Pull    "R2,R3,PC",HS           ; Stop at 0, but not before

        LDRB    R2, Interlocks          ;also delay for mode change
        TSTS    R2, #TimerLock
        BNE     %FT95                   ;return if still doing a previous tick

        WritePSRc I_bit :OR: SVC_mode, LR ;go to supervisor mode, IRQs off
        ORR     R2, R2, #TimerLock      ;lock timer
        Push    "R0,R1,R4-R11,LR"
        STRB    R2, Interlocks
        ADD     R3, R3, R3, LSL #16     ;restart counter with same period
        STR     R3, TickerState

        TSTS    R2, #NoOpenFloppy
        LDREQ   R0, FloppyProcessBlk
        MOVEQ   R1, #FloppyLock
        BLEQ    BackgroundOps           ;(R0,R1->R3-R11)(IRQs on during BackgroundOps execution)

        TSTS    R2, #NoOpenWinnie
        LDREQ   R0, WinnieProcessBlk
        MOVEQ   R1, #WinnieLock
        BLEQ    BackgroundOps           ;(R0,R1->R3-R11)(IRQs on during BackgroundOps execution)

        Pull    "R0,R1,R4-R11,LR"
        WritePSRc I_bit :OR: IRQ_mode, R3
        BIC     R2, R2, #TimerLock
        STRB    R2, Interlocks
        Pull    "R2,R3,PC"

95
        ; Entered with TickerState set, so increase the period
        ; and start counting again.
        ADD     R3, R3, #1              ; inc period
        TST     R3, #&8000              ; and upper bound and &7fff
        SUBNE   R3, R3, #1
        ADD     R3, R3, R3, LSL #16     ; Restart the timer
        STR     R3, TickerState
        Pull    "R2,R3,PC"

 LTORG

; ++++++++++++
; R3LoadNewMap
; ++++++++++++

;If disc has new map ensure it is loaded
;assumes no disc changed only to be used for extending background ops

;entry
; R3 ind disc address, V=0
; BufSz
; Fcb
;exit  R8 corrupt
;      V set if error, BUT R0 PRESERVED

R3LoadNewMap ROUT
 [ DebugG
        DREG    R3,,cc
        DLINE   ">R3LoadNewMap"
 ]
        Push    "R0,R5,R6,LR"
        CMPS    R0,R0   ;V=0
        BL      TestMap                 ;(R3->Z)
        Pull    "R0,R5,R6,PC",NE
        BL      DiscAddToRec            ;(R3->LR)
        MOV     R5, LR
        LDRB    R6, [R5,#DiscsDrv]
        DrvRecPtr  R6,R6
 [ DynamicMaps
        LDR     R8, [R6,#DrvsFsMapAddr]
        LDR     LR, [R6,#DrvsFsMapFlags]
        TSTS    LR, #BadFs
 |
        LDR     R8, [R6,#DrvsFsMap]
        TSTS    R8, #BadFs
 ]
        BLNE    SetV
        BLEQ    LoadNewMap              ;(R5,R6,R8->R0,V)
 [ DebugG
        BVC     %FT01
        DREG    R0,,cc
01
        DLINE   "R3<LoadNewMap"
 ]
        Pull    "R0,R5,R6,PC"


; =========
; BufsToRam
; =========

;File cache must be locked

;entry
; R1 RAM adjust
; R2 end file offset
; BufSz
; FileOff start offset
; Fcb

BufsToRam ROUT
 [ DebugG
        DREG    R1,,cc
        DREG    R2,,cc
        DREG    BufSz,,cc
        DREG    FileOff,,cc
        DREG    Fcb,,cc
        DLINE   "BufsToRam"
 ]
        Push    "R0-R3,FileOff,R6-R8,BufOff,BufPtr,LR"
        SavePSR LR
        Push    LR
        LDR     BufPtr, [Fcb, #PrevInFile]
        BL      FindSubBuf              ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
 [ DebugG
        BICS    LR, BufOff, #24
        BEQ     %FT03
        DLINE   "Bad BufOff in BufsToRam"
        regdump
03

        LDR     LR, [BufPtr, #BufFileOff]
        ADD     LR, LR, BufOff, LSL #5
        TEQS    FileOff, LR
        BEQ     %FT02
01
 FileBufs
02
 ]

        ; Move end file offset to R6
        MOV     R6, R2

        ; Get file's monotonic flag into R3
        LDRB    R3, [Fcb,#FcbFlags]
        ANDS    R3, R3, #Monotonic

        ; RAM address of start of section in buffer
        ADD     R1, FileOff, R1

10
        ; Point R0 at buffer data
        ADD     R0, BufPtr, #BufferData
        ADD     R0, R0, BufOff, LSL #5

        ; R7 used to hold first valid FileOff within buffer
        MOV     R7, FileOff

        ; Get sub-buffer flags into low byte of R2
        LDR     R2, [BufPtr,#BufFlags]
        MOV     R2, R2, ROR BufOff

20
        ; If sub-buffer is awaiting a sequential read then downgrade to filled+unused
        TSTS    R2, #AwaitsSeqRead
        EORNE   R2, R2, #AwaitsSeqRead :EOR: NormalBuf

        ; If file is monotonic and buffer is filled+unused then downgrade buffer to filled+used
        ASSERT  Monotonic :SHR: 1 = NormalBuf
        TSTS    R2, R3, LSR #1
        EORNE   R2, R2, #NormalBuf :OR: UsedMonotonic

 [ DebugG
        ; Barf if buffer is busy+read-ahead or unused
        TSTS    R2, #ReadAhead :OR: EmptyBuf
        BEQ     %FT22
        DLINE   "BAD FLAGS IN BUFS TO RAM"
 regdump
        LDR     lr, [sp, #11*4] ; sp offset OK.
        DREG    lr, "Caller return:"
21
        B       %BT21
22
 ]

        ; Move to next sub-buffer in buffer by:
        ; Rotating bufflags by required amount
        ; Adding required amount to bufoff
        ; Adding required amount to FileOff
        MOV     R2, R2, ROR BufSz
        ADD     BufOff, BufOff, BufSz
        ADD     FileOff, FileOff, BufSz, LSL #5

        ; Loop in this buffer if more in buffer and more to deal with in file
        CMPS    BufOff, #32
        CMPLOS  FileOff, R6
        BLO     %BT20

        ; Rotate adjusted flags back to original orientation
        RSBS    LR, BufOff, #32
        MOVNE   R2, R2, ROR LR

        ; Store the adjusted buffer flags (moving buffer between chains as appropriate)
        LDRB    R8, [BufPtr, #BufPriority]
        BL      UpdateBufState  ;R2,BufSz,BufPtr

        ; File end gets nearer
        SUB     R2, FileOff, R7

        ; Copy buffer contents to RAM as needed
        TSTS    R1, #3
        BLEQ    Move256n        ;(R0-R2->R0-R2)
        BLNE    BlockMove       ;(R0-R2)
        ADDNE   R1, R1, R2

        LDRB    LR, [BufPtr, #BufPriority]      ;If priority of buffer unchanged make
        TEQS    R8, LR                          ;buffer youngest at its priority level
        sbaddr  R2, BufChainsRoot, EQ           ;to maintain least recently used order
        ADDEQ   R2, R2, R8, LSL #3
        BLEQ    UnlinkAllocChain        ;BufPtr
        BLEQ    LinkAllocChain          ;R2,BufPtr

        ; If more in file move to next buffer and process it
        CMPS    FileOff, R6
        LDRLO   BufPtr, [BufPtr, #NextInFile]
        MOVLO   BufOff, #0
        BLO     %BT10

        Pull    LR
        RestPSR LR,,f
        Pull    "R0-R3,FileOff,R6-R8,BufOff,BufPtr,PC"


; ===============
; UpdateProcesses
; ===============

;filecache must not be owned by another thread

UpdateProcesses ROUT
        Push    "R0-R2,LR"
        SavePSR R2
        LDRB    R1, Interlocks
        LDR     R0, WinnieProcessBlk
        TST     R0, #BadPtrBits
        ORREQ   LR, R1, #WinnieLock
        STREQB  LR, Interlocks
        BLEQ    UpdateProcess
        LDR     R0, FloppyProcessBlk
        ORR     LR, R1, #FloppyLock
        STRB    LR, Interlocks
        BL      UpdateProcess
        STRB    R1, Interlocks
        RestPSR R2,,f
        Pull    "R0-R2,PC"


; =============
; UpdateProcess
; =============

;Controller must be claimed before calling
;And filecache must not be owned by another thread
;entry R0->Process block to update

        ASSERT  FileOff=R5      ;these get re-used
        ASSERT  DiscAdjust=R6
        ASSERT  TransferEnd=R7
        ASSERT  FragEnd=R8

UpdateProcess ROUT
        Push    "R0-R11,LR"
 [ DebugJ
        LDRB    R1, Interlocks
        TSTS    R1, #FloppyLock :OR: WinnieLock
        BNE     %FT01
        DREG    r1, "", cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
        DLINE   "US!",cc
01
        MOVEQ   PC, #SVC_mode
 ]
 [ Debug3L
        DLINE   "U",cc
 ]
 [ DebugGu
        DREG    r0,">UpdateProcess(",cc
        DLINE   ")"
 ]

        ; Nothing to do if process is neither reading ahead nor writing behind
        LDRB    R5, [R0,#Process]
        TSTS    R5, #ReadAhead :OR: WriteBehind
 [ DebugGu
        BNE     %FT01
        DLINE   "Process quiet"
01
 ]
        BEQ     %FT90

        ; Get Fcb, BufSz and address,length pair at ProcessStartPtr to R3,R6
        LDR     Fcb, [R0,#ProcessFcb]
        LDRB    BufSz,[Fcb,#FcbBufSz]
        LDR     R1, [R0,#ProcessStartPtr]
        LDMIA   R1, {R3,R6}

        ; R7 = OldLength - 1st length
        LDR     LR, [R0,#ProcessOldLength]
        SUB     R7, LR, R6

        ; if less than a buffer done and process still active then there's nothing to update
        CMPS    R7, BufSz, LSL #5       ;IF length done < buffer
        LDRCC   R2, [R0,#ProcessStatus]
        ASSERT  Active=bit31
        RSBCCS  R7, R2, #bit30          ;AND process not completed
 [ DebugGu
        BCS     %FT01
        DLINE   "length done < one buffer and not completed"
01
 ]
        BCC     %FT90                   ;THEN no updating needed
 [ DebugGs
        DREG    r3," -",cc
        DREG    r6,",",cc
;        DLINE   ")",cc
 ]
 [ DebugGs
;        LDR     lr, [r0, #ProcessStartPtr]
;        DREG    lr,"Start=",cc
;        LDR     lr, [r0, #ProcessStatus]
;        DREG    lr," status=",cc
;        LDR     lr, [r0, #ProcessEndPtr]
;        DREG    lr," End="
 ]

 [ DebugGu
        DREG    R1,,cc
        DREG    R3,,cc
        DREG    R6,,cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
        DLINE   "ptr add len old: Updating needed"
 ]

        ; Some sort of updating needed - lock the file cache and make lessvalid
        LDRB    R2, Interlocks          ;If updating needed ensure file cache claimed
        ORR     LR, R2, #FileCacheLock
        STRB    LR, Interlocks
        Push    "R2"
        BL      LessValid

        ; Construct the toggle mask for any completed sub-buffers into R5.
        ; Buffers by default get mapped to NormalBuf, but, ReadAhead buffers
        ; attached to Sequential files get mapped to AwaitsSeqRead, and WriteBehind
        ; buffers attached to Monotonic files get mapped to UsedMonotonic buffers.
        LDR     BufOff, [R0,#ProcessStartOff]
        AND     BufOff,BufOff,#&300
        MOV     BufOff,BufOff,LSR #5
        EOR     R5, R5, #NormalBuf
        LDRB    LR, [Fcb,#FcbFlags]

        TSTS    R5, #ReadAhead
        TSTNES  LR, #Sequential
        EORNE   R5, R5, #AwaitsSeqRead :EOR: NormalBuf

        TSTS    R5, #WriteBehind
        TSTNES  LR, #Monotonic
        EORNE   R5, R5, #UsedMonotonic :EOR: NormalBuf

        MOV     R7, #0          ;will total length of transfers TO BUFFER updated
        MOV     R8, BufSz,LSL #5
        SUB     R8, R8, #1      ;BufSz mask (gets offset into sub buffer)

        ANDS    LR, R6, R8      ;ProcessStartPtr offset into sub buffer
        RSBNE   LR, LR, BufSz, LSL #5 ; remains of sub buffer
        SUBNE   R3, R3, LR            ; subtract the remains from the start
        ADDNE   R6, R6, LR            ; add the remains to the length
10
        ; Check for carnage - is the start within the FileBufs area
        LDR     R2, FileBufsStart
        CMPS    R3, R2
        LDRHS   LR, FileBufsEnd
        CMPHSS  LR, R3
        MOVLO   BufPtr,#bit31
        MOVLO   BufOff,#0
        BLO     %FT30

        ; Find out the start of the buffer corresponding to R3
        ; This works on the basis that if the buffer wanted in the Nth, then
        ; R3 will be within the Nth, and hence it will be between
        ; N*(1024+1<<BufScale) and N*(1024+1<<BufScale)+1023, lets say
        ; N*(1024+1<<BufScale)+O
        ; hence dividing by 1024 gives
        ; N + (N<<BufScale+O)/1024
        ; Which will be inaccurate by
        ; (N<<BufScale+O)/1024
        ; As BufScale is 5 and 1024 is (1<<(5+5)), then the error will be
        ; about >>BufScale of the original N+(N<<BufScale+O)/1024. This will
        ; start going wrong if N is about 1024. This is not a problem as the
        ; maximum number of buffers is 255 anyway!
        ;
        ; So, BufPtr points to the buffer containing R3 and R3 is the offset into it
        ASSERT  BufScale=5
        ADD     BufPtr, R2, #BufferData
        SUB     LR, R3, BufPtr
        MOV     LR, LR, LSR #10
        SUB     LR, LR, LR, LSR #BufScale
        ADD     BufPtr, BufPtr, LR, LSL #10
        ADD     BufPtr, BufPtr, LR, LSL #BufScale
        SUBS    LR, R3, BufPtr
        SUBMI   BufPtr, BufPtr,#1*K+BufferData
        CMPS    LR, #1*K
        ADDGT   BufPtr, BufPtr, #1*K+BufferData
        SUB     R3, R3, BufPtr

        ; Correct back to the buffer's start
        SUB     BufPtr, BufPtr, #BufferData

        ; Get amount left in the buffer, and, if 0 goto 30
        SUBS    R2, R3, BufOff, LSL #5
        BEQ     %FT30

        ; Accumulate the amount left
        ADD     R7, R7, R2
 [ DebugJ
        TSTS    R7, #&FF
        BEQ     %FT15
        Push    "R0"
        MOV     R0, #IOC                ;disable floppy FIQs
        STRB    R0, [R0,#IOCFIQMSK]
        Pull    "R0"

        DLINE   "BAD UPDATE",cc
 regdump
        MOV     PC, #0
15
 ]
 [ DebugG
        CMPS    R3, #1*K
        BLS     %FT01
        DLINE   "BUFFER MAPPING FAILED"
01
 ]

; R3 = offset from BufPtr to scatter start - 0, &100, &200, &300
; BufPtr = start of buffer being processed
; BufOff = start offset>>5 into the buffer

        ; Toggle the flags of transfered sub buffers and reflect
        ; the changes in the buffer's state
        LDR     R2, [BufPtr,#BufFlags]
        B       %FT25

20
        EOR     R2, R2, R5, LSL BufOff
        ADD     BufOff, BufOff, BufSz
25
        CMPS    BufOff, R3, LSR #5
        BLO     %BT20
 [ DebugG
        DREG    r2, "BUFFER GOING TO STATE "
        TST     r2, #ReadAhead :OR: WriteBehind
        BEQ     %FT01
        DREG    r2,"BAD BUFFER MOVEMENT TO STATE "
01
 ]
        BL      UpdateBufState  ;R2,BufSz,BufPtr

30
        ; If needs, go around again
 [ NewErrors
        LDR     LR, FS_Flags
 ]
        LDR     R2, [R0, #ProcessStatus]
 [ NewErrors
        TST     LR, #CreateFlag_NewErrorSupport
        MOVNE   R2, R2, LSL #2
 ]
        Push    "R6"
        LDMIA   R1, {R3,R6}
        ANDS    LR, R6, R8              ; Sub buffer offset
        RSBNE   LR, LR, BufSz, LSL #5   ; remains
        SUBNE   R3, R3, LR              ; reduce start
        ADDNE   R6, R6, LR              ; increase length
        Pull    "LR"
        TEQS    R6, LR                  ; if changed go around again
        BNE     %BT10

        ; Adjust ProcessStartOff for the transfered data
        TEQS    BufPtr, BufPtr, LSR #32 ;C=1 <=> not going to buffer
 [ DebugGu
        BCC     %FT01
        DLINE   "direct"
        B       %FT02
01
        DREG    BufPtr,,cc
        DLINE   "buffer"
02
 ]
        LDRCS   LR, [R0,#ProcessRamAdjust]
 [ DebugGu
        BCC     %FT01
        DREG    R3,,cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
01
 ]
        SUBCS   LR, R3, LR
        LDRCC   LR, [BufPtr,#BufFileOff]
 [ DebugGu
        BCS     %FT01
        DREG    BufOff,,cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
01
 ]
        ADDCC   LR, LR, BufOff, LSL #5
 [ DebugGu
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
        DLINE   "new start off"
 ]
 [ DebugH
        DLINE   "U ",cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
 ]
        STR     LR, [R0,#ProcessStartOff]

        AND     BufOff,LR ,#&300
        MOV     BufOff,BufOff,LSR #5
        EORS    LR, R1, R2
 [ DebugGu
        BNE     %FT01
        DLINE   "clear direct"
01
 ]
        STREQB  LR, [R0,#ProcessDirect]
 [ DebugGu
        BNE     %FT01
        DLINE   "ERROR ABORT"
01
 ]
        BEQ     %FT40
        TEQS    R6, #0
 [ DebugGu
        BEQ     %FT01
        DLINE   "un",cc
01
        DLINE   "finished pair"
 ]
        BNE     %FT40           ;If unfinished pair

        ; Finished a pair - must have finished the direct transfer (if any)
        MOVCS   LR, #0
        STRCSB  LR, [R0,#ProcessDirect]

        ; Move to the next pair
        ADD     R1, R1, #2*4
35
        LDMIA   R1, {R3,R6}
 [ DebugGs
        LDR     lr, [R0, #ProcessEndPtr]
        TEQ     lr, r1
        BEQ     %FT01
        DREG    r3," =",cc
        DREG    r6,",",cc
;        DLINE   ")",cc
01
 ]
 [ DebugGu
        DREG    R1,,cc
        DREG    R3,,cc
        DREG    R6,,cc
        DLINE   "ptr add len"
 ]
      [ FixTBSAddrs
        CMN     R3, #ScatterListNegThresh
        ADDCS   R1, R1, R3
        BCS     %BT35
      |
        TEQS    R3, #0
        ADDMI   R1, R1, R3
        BMI     %BT35
      ]
        ANDS    LR, R6, R8
        RSBNE   LR, LR, BufSz, LSL #5
        SUBNE   R3, R3, LR
        ADDNE   R6, R6, LR
        LDR     LR, [R0,#ProcessEndPtr]
        TEQS    LR, R1
        BNE     %BT10
        B       %FT70

40
        STRNE   R6, [R0,#ProcessOldLength]
        BNE     %FT80
        LDRCS   LR, [R0, #ProcessError] ;take special note of errors in direct transfer
        STRCS   LR, DirectError
        LDRB    R3, [R0, #Process]
        BL      BackgroundTidyUp        ;(R0,R3,BufSz,Fcb) if error

70
        ; Process goes inactive - all done or error
        MOV     LR, #Inactive
 [ DebugP
        DREG    r0, "Process ",cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, " going inactive with "
        Pull    "r0"
 ]
        STRB    LR, [R0, #Process]
 [ Debug :LAND: {FALSE}
        MOV     BufPtr, Fcb

02
        LDR     BufPtr, [BufPtr, #NextInFile]
        TEQ     BufPtr, Fcb
        BEQ     %FT01
        LDRB    lr, [BufPtr, #BufPriority]
        TEQ     lr, #ReadAheadChain
        BNE     %BT02
        DREG    BufPtr, "Buffer still on read ahead chain after process gone inactive:"
        B       %BT02
01
 ]
 [ DebugGu
        DLINE   "done"
 ]
80
        STR     R1, [R0,#ProcessStartPtr]
 [ DebugGu
        DREG    R1,,cc
        DLINE   "new start ptr"
 ]
        TSTS    R5, #WriteBehind
        MOVNE   R1, R7
        BLNE    ReduceWriteBehind       ; (R0,R1->R1)
        BL      MoreValid
        Pull    "LR"
        STRB    LR, Interlocks
90
 [ DebugGu
        DLINE   "<UpdateProcess"
 ]
 [ Debug3L
        DLINE   "u",cc
 ]
        Pull    "R0-R11,PC"

 LTORG

; ================
; BackgroundTidyUp
; ================

; Tidy up a file's buffers after background error
;  If read ahead error mark read ahead buffers empty
;  If write behind error mark all buffers as empty and set data lost flag
;  clear sequential flag

;entry
; Need controller and filecache claimed
; R0 -> controller block
; R3 ReadAhead / WriteBehind
; BufSz
; Fcb

BackgroundTidyUp ROUT
        Push    "R0-R3,R5,R7,BufPtr,LR" ;IF uncertain where disc is then clear
        SavePSR R7
        LDRB    LR, [Fcb, #FcbFlags]    ; sequential to prevent restarts. May not
        BIC     LR, LR, #Sequential     ; succeed immediately if FcbFlags is being
        STRB    LR, [Fcb, #FcbFlags]    ; modified in foreground but this is ok
        BL      LessValid
        TEQS    R3, #WriteBehind
        ASSERT  WriteBehind<>0
        STREQB  R3, [Fcb,#FcbDataLostFlag]
        MOVEQ   R3, #AllBufFlags :EOR: EmptyBuf
        MOV     BufPtr, Fcb
        MOV     R1, #0
        B       %FT60

45
        LDR     R2, [BufPtr,#BufFlags]
        MOV     R5, #32
50
        TSTS    R2, #WriteBehind
        ADDNE   R1, R1, BufSz, LSL #5
        TSTS    R2, R3
        BICNE   R2, R2, R3
        ORRNE   R2, R2, #EmptyBuf
        MOV     R2, R2, ROR BufSz
        SUBS    R5, R5, BufSz
        BGT     %BT50           ;Loop for each sub-buffer
        BL      UpdateBufState  ;R2,BufSz,BufPtr
60
        LDR     BufPtr, [BufPtr,#NextInFile]
        TEQS    BufPtr, Fcb
        BNE     %BT45   ;loop if more and read ahead

        TEQS    R3, #AllBufFlags :EOR: EmptyBuf  ;If write
        BLEQ    ReduceWriteBehind               ;(R0,R1->R1)
        BL      MoreValid
        RestPSR R7,,f
        Pull    "R0-R3,R5,R7,BufPtr,PC"


; =================
; ReduceWriteBehind
; =================

;entry
;      R0 pointer to controller block
;      R1 amount to reduce (Floppy) Write Behind
;      (Floppy) Controller must be claimed
;exit R1 corrupt

ReduceWriteBehind ROUT
        Push    "R2,R3,LR"
        SavePSR R3

 [ DebugJ
        LDR     LR, FloppyProcessBlk
        TEQ     R0, LR
        LDRB    R2, Interlocks
        ASSERT  WinnieLock :SHL: 1 = FloppyLock
        MOVNE   R2, R2, ASL #1
        TSTS    R2, #FloppyLock
        BNE     %FT10
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
        LDR     LR, [SP, #(3+13)*4] ; sp offset OK.
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
        LDR     LR, [SP, #(3+2+13)*4] ; sp offset OK.
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
        DLINE   "UNLOCKED",cc
        MOVS    PC, #SVC_mode
10
 ]

        LDR     LR, [R0, #ProcessWriteBehindLeft]
 [ DebugJ
        TSTS    LR, #&FF
        TSTEQS  R1, #&FF
        BEQ     %FT42

        DLINE   " D3 ",cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
        LDR     LR, [SP,#8] ; sp offset OK.
 regdump
        MOV     PC, #0
42
 ]
        SUBS    LR, LR, R1
 [ DebugH
        DLINE   "-",cc
        DREG    R1,,cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
 ]
        STR     LR, [R0, #ProcessWriteBehindLeft]
 [ DebugJ
        BL      Check
 ]
        BNE     %FT95

        ; All done if WriteDisc is same as WriteBehindDisc
        LDRB    R2, [R0, #ProcessWriteBehindDisc]
        LDRB    LR, WriteDisc
        TEQS    R2, LR

        BEQ     %FT95

        ; Cancel writing behind
        LDRB    R1, [R0, #ProcessWriteBehindDrive]
        MOV     LR, #-1
        ASSERT  ProcessWriteBehindDrive :MOD: 4 = 0
        ASSERT  ProcessWriteBehindDisc-ProcessWriteBehindDrive = 1
        STR     LR, [R0, #ProcessWriteBehindDrive]

        ; If WriteBehindDrive isn't LockedDrive then Unlock it
        LDRB    LR, LockedDrive
        TEQ     LR, R1
        BLNE    UnlockDrive
95
        RestPSR R3,,f
        Pull    "R2,R3,PC"


; =========
; AddBuffer
; =========

;Extend background read write with an extra buffer

;entry
; R0      -> process block
; R3      Length
; FileOff
; BufOff
; BufPtr  buffer to link

;exit C set <=> succeeds
; FileOff updated

AddBuffer ROUT
 [ DebugG
        DREG    R0,,cc
        DREG    R3,,cc
        DREG    FileOff,,cc
        DREG    BufOff,,cc
        DREG    BufPtr,,cc
        DLINE   ">AddBuffer",cc,NL
 ]

        Push    "R1,R2,R4,R6,LR"
 [ DebugJ
        LDR     R6, [BufPtr,#BufFcb]
        TEQS    R6, Fcb
        BEQ     %FT05

        DLINE   "BAD ADD BUF",cc
 regdump
        MOV     PC, #0
05
 ]
        ADD     R1, BufPtr,#BufferData
        ADD     R1, R1, BufOff, LSL #5
        BL      LessValid
        LDR     LR, [R0,#ProcessEndPtr]

 [ {FALSE}
 ; This section deals with stretching the last scatter entry - this causes
 ; horrible headaches for driver writers so it's conditioned out.

        SUB     R2, LR, R0              ;point R2 at previous pair
        TEQS    R2, #ProcessPairs       ;taking wrapping into account
        SUB     R2, LR, #8
        LDREQB  R4, MaxFileBuffers
        ADDEQ   R4, R4, #ExtraPairs
        ADDEQ   R2, R2, R4, LSL #3
        LDMIA   R2, {R4,R6}             ;pick up previous address,length pair

        TEQ     R6, #0
        BEQ     %FT10                   ;scatter length=0 hence gone beyond this?
        ADD     R4, R4, R6
        TEQS    R4, R1                  ;last end = this start ?
        BNE     %FT10

        WritePSRc F_bit :OR: I_bit :OR: SVC_mode, R4 ;disable FIQ and IRQ
        LDR     R4, [R0,#ProcessStatus]
        ASSERT  CanExtend=bit30
        TEQS    R4, R4, LSR #31         ;C=1 <=> can extend
        LDRCS   R6, [R2, #4]
        ADDCS   R6, R6, R3
        STRCS   R6, [R2, #4]
        WritePSRc SVC_mode, LR
        ASSERT  CanExtend=bit30
        TEQS    R4, R4, LSR #31         ;C=1 <=> can extend
        B       %FT20
 ]

10
        WritePSRc F_bit :OR: I_bit :OR: SVC_mode, R4    ;disable FIQ and IRQ
        LDR     R4, [R0,#ProcessStatus]                 ;to make these atomic
        TEQS    R4, R4, LSR #31         ;C=1 <=> can extend
        STMCSIA  LR!,{R1,R3}
        WritePSRc SVC_mode, R1
 [ DebugGs
        DREG    r1," +",cc
        DREG    r3,",",cc
;        DLINE   ")",cc
 ]

        ASSERT  CanExtend=bit30
      [ FixTBSAddrs
        LDR     R1, [LR]
        CMN     R1, #ScatterListNegThresh
        MOVCC   R1, #0
        MOVS    R4, R4, LSR #31         ;C=1 <=> still active
        ADDCS   LR, LR, R1
      |
        MOVS    R4, R4, LSR #31         ;C=1 <=> still active, also sets N=0
        LDRCS   R1, [LR]
        TEQCSS  R1, #0                  ;preserves C
        ADDMI   LR, LR, R1
      ]
        STRCS   LR, [R0,#ProcessEndPtr]
20
        ADDCS   FileOff, FileOff, R3
        STRCS   FileOff, [R0,#ProcessEndOff]
        BL      MoreValid
 [ DebugG
        DREG    FileOff,,cc
        BCC     %FT01
        DLINE   "<AddBuffer succeeded"
        B       %FT02
01
        DLINE   "<AddBuffer failed"
02
 ]
 [ DebugH
        BCC     %FT01
        DLINE   "ay ",cc
        DREG    FileOff,,cc
        DREG    BufPtr,,cc
        B       %FT02
01
        DLINE   "an ",cc
02
 ]
        Pull    "R1,R2,R4,R6,PC"


; =======
; AddPair
; =======

;Extend background read write with address length pair

;entry
; R0      -> process block
; R1      RamAdjust
; FileOff end offset

;exit C set <=> succeeds

AddPair ROUT
 [ DebugG
        DREG    R0,,cc
        DREG    R1,,cc
        DREG    FileOff,,cc
        DLINE   ">AddPair"
 ]
        Push    "R2-R4,LR"
        LDR     R2, [R0,#ProcessEndOff]
        BL      LessValid
        SUB     LR, FileOff, R2
        ADD     R2, R2, R1
        LDR     R3, [R0,#ProcessEndPtr]

 [ DebugGs
        DREG    r2," +",cc
        DREG    lr,",",cc
;        DLINE   ")",cc
 ]
        WritePSRc F_bit :OR: I_bit :OR: SVC_mode, R4    ;disable FIQ and IRQ
        LDR     R4, [R0,#ProcessStatus]                 ;to make these atomic
        TEQS    R4, R4, LSR #31         ;C=1 <=> can extend
        STMCSIA  R3!,{R2,LR}
        WritePSRc SVC_mode, LR

        ASSERT  CanExtend=bit30
      [ FixTBSAddrs
        LDR     LR, [R3]
        CMN     LR, #ScatterListNegThresh
        MOVCC   LR, #0
        MOVS    R4, R4, LSR #31         ;C=1 <=> can extend
        ADDCS   R3, R3, LR
      |
        MOVS    R4, R4, LSR #31         ;C=1 <=> can extend
        LDRCS   LR, [R3]
        TEQCSS  LR, #0
        ADDMI   R3, R3, LR
      ]
        STRCS   R1, [R0,#ProcessRamAdjust]
        STRCS   R3, [R0,#ProcessEndPtr]
        MOVCS   LR, #&FF
        STRCSB  LR, [R0,#ProcessDirect]
        STRCS   FileOff, [R0,#ProcessEndOff]
        BL      MoreValid
 [ DebugG
        BCC     %FT01
        DLINE   "<AddPair succeeded"
        B       %FT02
01
        DLINE   "<AddPair failed"
02
 ]
 [ DebugH
        BCC     %FT01
        DLINE   "AY ",cc
        DREG    FileOff,,cc
        DREG    BufPtr,,cc
        B       %FT02
01
        DLINE   "AN ",cc
02
 ]
        Pull    "R2-R4,PC"


; ===========
; ScanBuffers
; ===========

;Entry
; BufSz
; FileOff
; FragEnd
; BufOff
; BufPtr

;Exit
; FileOff
; BufOff
; BufPtr
; LO/EQ/HI       ;this type cached / empty / ReadAhead

ScanBuffers ROUT
 [ DebugG :LOR: Debug3L
        DLINE   "FileOff ,BufOff  ,BufPtr  ,BufSz   ,FragEnd >ScanBuffers"
        DREG    FileOff,,cc
        DREG    BufOff,,cc
        DREG    BufPtr,,cc
        DREG    BufSz,,cc
        DREG    FragEnd
 ]
        Push    "R0-R2,LR"
        LDR     R1, [BufPtr,#BufFlags]
        MOVS    R0, R1, LSR BufOff
        MOVEQ   R0, #EmptyBuf           ;deals with BufOff=32
        AND     R0, R0, #ReadAhead :OR: EmptyBuf
        CMPS    R0, #EmptyBuf
        BNE     %FT15
        BL      SkipEmpty               ;BufSz,FileOff,FragEnd,BufOff,BufPtr->FileOff,BufOff,BufPtr
        B       %FT80

15      MOV     R2, #ReadAhead :OR: EmptyBuf

20
        CMPS    FileOff, FragEnd
        BHS     %FT60
        AND     LR, R2, R1, LSR BufOff
        TEQS    R0, LR
        BNE     %FT60
40
        ADD     FileOff, FileOff, BufSz, LSL #5
        ADD     BufOff, BufOff, BufSz
        CMPS    BufOff, #32
        BLO     %BT20

        LDR     BufPtr, [BufPtr,#NextInFile]
        LDR     R1, [BufPtr,#BufFlags]
        LDR     LR, [BufPtr,#BufFileOff]
        TEQS    LR, FileOff
        MOVEQ   BufOff, #0
        BEQ     %BT20
        LDR     BufPtr, [BufPtr,#PrevInFile]
60
        CMPS    R0, #EmptyBuf
80
 [ DebugG :LOR: Debug3L
        DLINE   "FileOff ,BufOff  ,BufPtr <ScanBuffers"
        DREG    FileOff,,cc
        DREG    BufOff,,cc
        DREG    BufPtr,,cc
        BHS     %FT01
        DLINE   "cached"
01
        BNE     %FT02
        DLINE   "empty"
02
        BLS     %FT03
        DLINE   "read ahead"
03
 ]
        Pull    "R0-R2,PC"


; =========
; SkipEmpty
; =========

;Entry
; BufSz
; FileOff
; FragEnd
; BufOff
; BufPtr

;Exit
; FileOff
; BufOff
; BufPtr

SkipEmpty ROUT
        Push    "LR"
        SavePSR lr
        Push    lr
 [ DebugG :LOR: Debug3L
        DLINE   "FileOff ,BufOff  ,BufPtr  ,BufSz   ,FragEnd >SkipEmpty"
        DREG    FileOff,,cc
        DREG    BufOff,,cc
        DREG    BufPtr,,cc
        DREG    BufSz,,cc
        DREG    FragEnd
 ]
        B       %FT40
20
        CMPS    FileOff, FragEnd
        BHS     %FT80
        ASSERT  BufFlags=0
        LDRB    LR, [BufPtr,BufOff,LSR #3]
        TSTS    LR, #EmptyBuf
        BEQ     %FT80
        ADD     BufOff, BufOff, BufSz
        ADD     FileOff, FileOff, BufSz, LSL #5
40
        CMPS    BufOff,#32
        BLO     %BT20
        LDR     BufPtr, [BufPtr,#NextInFile]
        LDR     FileOff, [BufPtr,#BufFileOff]
        CMPS    FileOff, FragEnd
        MOVLS   BufOff, #0
        BLO     %BT20

        LDRHI   BufPtr, [BufPtr,#PrevInFile]
        MOVHI   FileOff, FragEnd
80
 [ DebugG :LOR: Debug3L
        DLINE   "FileOff ,BufOff  ,BufPtr  <SkipEmpty"
        DREG    FileOff,,cc
        DREG    BufOff,,cc
        DREG    BufPtr
 ]
        Pull    lr
        RestPSR lr,,f
        Pull    "PC"


; ===============
; SkipWriteBehind
; ===============

;Entry
; BufSz
; FileOff
; FragEnd
; BufOff
; BufPtr

;Exit
; FileOff
; BufOff
; BufPtr

SkipWriteBehind ROUT
        CMPS    BufOff, #32
        MOVHS   PC, LR
        Push    "LR"

 [ DebugG
        DLINE   "FileOff ,BufOff  ,BufPtr  ,BufSz   ,FragEnd >SkipWriteBehind"
        DREG    FileOff,,cc
        DREG    BufOff,,cc
        DREG    BufPtr,,cc
        DREG    BufSz,,cc
        DREG    FragEnd
 ]
        LDR     LR, [BufPtr,#BufFlags]
        MOV     LR, LR, LSR BufOff
05
        TSTS    LR, #WriteBehind
        TEQNES  FileOff, FragEnd
        Pull    "PC",EQ
        MOV     LR, LR, LSR BufSz
        ADD     FileOff, FileOff, BufSz, LSL #5
        ADD     BufOff, BufOff, BufSz
        CMPS    BufOff, #32
        BLO     %BT05

        LDR     BufPtr, [BufPtr,#NextInFile]
        LDR     LR, [BufPtr,#BufFileOff]
        TEQS    LR, FileOff
        MOVEQ   BufOff, #0
        LDREQ   LR, [BufPtr,#BufFlags]
        BEQ     %BT05
        LDR     BufPtr, [BufPtr,#PrevInFile]
 [ DebugG
        DLINE   "FileOff ,BufOff  ,BufPtr  <SkipWriteBehind"
        DREG    FileOff,,cc
        DREG    BufOff,,cc
        DREG    BufPtr
 ]
        Pull    "PC"


; ========================
; BackwardsSkipWriteBehind
; ========================

;Entry
; R0 Frag Start
; BufSz
; FileOff
; BufOff
; BufPtr

;Exit
; FileOff
; BufOff
; BufPtr

BackwardsSkipWriteBehind ROUT
        Push    "R1,LR"
 [ DebugG
        DLINE   "FragBeg ,BufSz   ,FileOff ,BufOff  ,BufPtr >BackwardsSkipWriteBehind"
        DREG    R0,,cc
        DREG    BufSz,,cc
        DREG    FileOff,,cc
        DREG    BufOff,,cc
        DREG    BufPtr
 ]
        TSTS    BufOff, #32             ;IF haven't got buffer
        TSTNES  FileOff,#&3FC           ;AND not at start of buffer
        Pull    "R1,PC",NE              ;THEN no chance of extending backwards

        LDR     LR, [BufPtr, #BufFlags]
        MOV     LR, LR, ROR BufOff
        RSB     R1, BufSz, #32
10
        CMPS    FileOff, R0             ;cant extend backward if at frag start
        BLS     %FT40
        TSTS    FileOff, #&300
        BEQ     %FT20
        MOV     LR, LR, ROR R1
        TSTS    LR, #WriteBehind
        SUBNE   FileOff, FileOff, BufSz, LSL #5
        BNE     %BT10
        B       %FT40

20
        TEQS    BufOff, #32
        LDRNE   BufPtr, [BufPtr,#PrevInFile]
        LDR     LR,     [BufPtr,#BufFileOff]
        SUB     LR, FileOff, LR
        TEQS    LR, #&400
        BNE     %FT30
        LDR     LR, [BufPtr,#BufFlags]
        MOV     LR, LR, ROR R1
        TSTS    LR, #WriteBehind
        SUBNE   FileOff, FileOff, BufSz, LSL #5
        MOVNE   BufOff, #0
        BNE     %BT10
30
        TEQS    BufOff, #32
        Pull    "R1,PC",EQ
        LDR     BufPtr, [BufPtr,#NextInFile]
40
        AND     BufOff, FileOff, #&300
        MOV     BufOff, BufOff, LSR #5
 [ DebugG
        DLINE   "FileOff ,BufOff  ,BufPtr  <BackwardsSkipWriteBehind"
        DREG    FileOff,,cc
        DREG    BufOff,,cc
        DREG    BufPtr
 ]
        Pull    "R1,PC"


; ===========
; DefFileFrag
; ===========

DefFileFrag ROUT
        MOV     R0, #0

; ========
; FileFrag
; ========

;entry
; R0 Read Start
; FileOff (R5)
; Fcb (R9)

;exit
; R0 Frag Start
; DiscAdjust (R6)
; FragEnd (R8)

FileFrag ROUT
 [ DebugG
        DREG    R0,,cc
        DREG    FileOff,,cc
        DREG    Fcb,,cc
        DLINE   ">FileFrag"
 ]
 [ BigDisc
        Push    "R2-R4,FileOff,R7,R9,LR"
 |
        Push    "R2-R4,FileOff,R9,LR"
 ]
        LDR     FragEnd, [Fcb,#FcbAllocLen]
      [ BigFiles
        TEQ     FragEnd, #RoundedTo4G
        MOVEQ   FragEnd, #&FFFFFFFF     ; For compares below, FragEnd shouldn't escape
      ]                                 ; into the wild non sector aligned
        LDR     R2, [Fcb,#FcbIndDiscAdd]
 [ DebugG
        DREG    FragEnd,"FcbAllocLen: "
        DREG    R2,"FcbIndDiscAdd: "
 ]
        MOV     R3, R2
        BL      TestMap                 ;(R3->Z)
 [ BigDisc
; disc record ptr in LR, get sector size, make DiscAdjust point to file start
        LDRB    R7, [LR, #DiscRecord_Log2SectorSize]    ; get our old friend, SectorSize
        ANDNE   LR, R2, #DiscBits
        BICNE   DiscAdjust, R2, #DiscBits
        ORRNE   DiscAdjust, LR, DiscAdjust, LSR R7
 |
        MOVNE   DiscAdjust, R2
 ]
        BNE     %FT90
 [ BigDisc
        TEQS    FileOff,FragEnd
        SUBEQ   FileOff,FileOff,#1      ;nasty - non sector aligned
        MOV     FileOff,FileOff, LSR R7 ;realign file offset - to keep arithmetic valid later
        MOV     FileOff,FileOff, LSL R7

        ASSERT  FileOff=R5
        BL      DefFindFileFragment     ;(R2,R5->R2,R4,R9,LR)
      [ BigFiles
        ADDS    R4, FileOff, R4         ;frag end file offset
        LDRCS   FragEnd, =-1*K          ;ceiling is background transfer dead-band
        CMPCC   R4, FragEnd
        MOVCC   FragEnd, R4             ;pick smaller of end-of-this-fragment and end-of-alloclen
      |
        ADD     R4, FileOff, R4         ;frag end file offset
        CMPS    R4, FragEnd
        MOVLO   FragEnd, R4             ;pick smaller of end-of-this-fragment and end-of-alloclen
      ]

        SUB     LR, R2, LR              ;length of frag before FileOff (in sectors)
        RSB     LR, LR, FileOff, LSR R7 ;project back to what FileOff would be at frag start (in sectors)
        CMPS    LR, R0, LSR R7          ;pick larger of R0 (reexpressed in sectors) and projected start
        MOVGT   R0, LR, LSL R7          ;a -ve projected start is allowed as shared files may not start at frag start
        SUB     DiscAdjust, R2, FileOff, LSR R7
 |
        TEQS    FileOff,FragEnd
        SUBEQ   FileOff,FileOff,#1      ;nasty - non sector aligned?

        BL      DefFindFileFragment     ;(R2,R5->R2,R4,R9,LR)
        ADD     R4, FileOff, R4         ;frag end file offset
        CMPS    R4, FragEnd
        MOVLO   FragEnd, R4

        SUB     LR, R2, LR              ;length of frag before FileOff
        SUB     LR, FileOff, LR         ;frag start file offset
        CMPS    LR, R0
        MOVGT   R0, LR                  ;signed compare as shared files may not start
        SUB     DiscAdjust, R2, FileOff ;at frag start
 ]
90
 [ DebugG
        DREG    R0,,cc
        DREG    DiscAdjust,,cc
        DREG    FragEnd,,cc
        DLINE   "<FileFrag"
 ]
 [ BigDisc
        Pull    "R2-R4,FileOff,R7,R9,PC"
 |
        Pull    "R2-R4,FileOff,R9,PC"
 ]


; ========
; FragLeft
; ========

;entry FileOff (R5), Fcb (R9)
;exit
; LR=rest of frag length
; EQ <=> new frag discontinuity

FragLeft ROUT
        Push    "R2-R4,R9,LR"
        LDR     R2, [Fcb,#FcbIndDiscAdd]
        MOV     R3, R2
        BL      TestMap                 ;(R3->Z)
        LDRNE   LR, [Fcb,#FcbAllocLen]  ;always < 2G old map
        SUBNE   LR, LR, FileOff
        Pull    "R2-R4,R9,PC",NE
        BL      DefFindFileFragment     ;(R2,R5->R2,R4,R9,LR)
        TEQS    R2, LR
        MOVEQ   LR, #0
        MOVNE   LR, R4
        Pull    "R2-R4,R9,PC"


; ===========
; FindFreeBuf
; ===========

; entry
;  R0 highest priority allowed to free * 2
;   special case AwaitsSeqChain*2-1
;   => of free buffers awaiting seq read, only free those owned by other files
;  FileOff,BufPtr
;  Fcb
;  FileCache must be claimed
; exit  NE <=> success
;  R2 old BufPtr, modified if was buffer claimed
;  BufPtr buffer claimed

FindFreeBuf ROUT
 [ DebugG
        DREG    R0,,cc
        DREG    FileOff,,cc
        DREG    BufPtr,,cc
        DREG    Fcb,,cc
        DLINE   ">FindFreeBuf"
 ]
        Push    "R0-R3,BufOff,BufPtr,LR"

        MOV     R2, BufPtr
        sbaddr  R1, BufChainsRoot
        ASSERT  ChainRootSz=4*2
        ADD     R0, R1, R0, LSL #2
        LDR     BufPtr, [R1,#YoungerBuf]        ;Check if empty buffer free
        TEQS    BufPtr, R1
        BNE     %FT70

        ADD     R1, R1, #ChainRootSz            ;Check if monotonic read buffer is free
        LDR     BufPtr, [R1,#YoungerBuf]
        TEQS    BufPtr, R1
        BNE     %FT65

;try to extend filecache by one block from dir cache
        LDRB    R3, UnclaimedFileBuffers
        TEQS    R3, #0
        BLNE    ExtendFileCache ;(->BufPtr,Z)
        BEQ     %FT90           ;If fails
        SUB     R3, R3, #1
        STRB    R3, UnclaimedFileBuffers
        LDR     LR, = EmptyBuf * &01010101
        STR     LR, [BufPtr,#BufFlags]
        MOV     LR, #EmptyChain
        STRB    LR, [BufPtr,#BufPriority]
        MOV     R3, R2
        SUB     R2, R1, #ChainRootSz
        BL      LinkAllocChain  ;(R2,BufPtr)
        MOV     R2, R3
        B       %FT70

60
        LDRB    LR, [BufPtr,#BufPriority]
        TEQS    LR, #AwaitsSeqChain
        BNE     %FT65

        LDR     R3, [BufPtr, #BufFcb]           ;Only throw away a buffer awaiting
        TEQS    R0, R1                          ;sequential read
        BEQ     %FT63                           ;if not special

        TEQS    R3, Fcb                         ;and for another file
        BEQ     %FT95

63
        LDRB    LR, [R3, #FcbRdAheadBufs]       ;decrement read ahead for buffer's file
        SUBS    LR, LR, #1
        STRNEB  LR, [R3, #FcbRdAheadBufs]

65
        BL      UnlinkFileChain                 ;BufPtr

70
        STR     BufPtr,[SP,#5*4]
 [ DebugH
        DLINE   "F ",cc
        LDR     LR, [BufPtr,#BufFileOff]
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
 ]
        TEQS    R2, BufPtr              ;IF removing current buffer
        LDREQ   BufPtr,[Fcb,#PrevInFile]
        BLEQ    FindSubBuf              ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        MOVEQS  R2, BufPtr              ;also ensure return NE for success
        STR     R2, [SP,#2*4]
 [ DebugG
        LDR     R2, [SP,#2*4]
        DREG    R2,,cc
        LDR     BufPtr, [SP,#5*4]
        DREG    BufPtr,,cc
        DLINE   "<FindFreeBuf"
 ]
        Pull    "R0-R3,BufOff,BufPtr,PC"

80
        ADD     R1, R1, #ChainRootSz
        LDR     BufPtr, [R1,#YoungerBuf]
        TEQS    BufPtr, R1
        BNE     %BT60
90
        CMPS    R1, R0
        BLO     %BT80
        TEQS    R0, R0                  ;Return EQ for FAIL
95
 [ DebugG
        DLINE   "<FindFreeBuf"
 ]
        Pull    "R0-R3,BufOff,BufPtr,PC"

 LTORG

; ==========
; FindSubBuf
; ==========

; Entry FileOff, Fcb, BufPtr
; Exit  BufPtr, BufOff

;Assuming that BufPtr already points to a valid buffer for this file (or FCB)
;This routine finds the (sub)buffer relevant to FileOff if this buffer is not
;claimed BufPtr points to next lowest claimed buffer and BufOff = 32

FindSubBuf ROUT
 [ DebugG
        DREG    FileOff,,cc
        DREG    BufPtr,,cc
        DLINE   ">FindSubBuf"
 ]
        Push    "R0-R2,LR"
        SavePSR R2
        EOR     R0, Fcb, FileOff, LSR #8
        LDRB    R1, BufHashMask
        AND     R0, R0, R1, LSL #2
        LDR     R1, BufHash
        LDR     BufOff, [R1, R0]        ;actually BufPtr for hash entry
        ADD     R1, BufOff, #BufFileOff
        ASSERT  BufFcb = BufFileOff + 4
        LDMIA   R1, {R1,LR}
        BIC     R0, FileOff,#&3FC
        TEQS    R0, R1
        TEQEQS  LR, Fcb
        MOVEQ   BufPtr, BufOff
 [ DebugG
        BEQ     %FT01
        DLINE   "hash miss"
        B       %FT02
01
        DREG    BufPtr, "", cc
        DLINE   "hash match"
02
 ]

; KJB fix - with a nearly 2GB file, we may be asked
; to look up &80000000 - this used to lock up. This
; search has been converted to handle full 32-bit
; file addressing by checking for the Fcb terminator
; explicitly. We lose the oh-so-cunning signed
; comparison when going backwards, and unsigned when
; going forwards (phew).
;
; If we went to 4GB files, we would have another
; problem, in that such a look-up would be impossible.
; We might have to restrict files to 4GB-1KB.

        LDR     R1, [BufPtr,#BufFileOff]
        CMPS    R1, R0
        BLO     %FT20
        BEQ     %FT30

10
        LDR     BufPtr, [BufPtr,#PrevInFile]
        LDR     R1, [BufPtr,#BufFileOff]
        TEQS    BufPtr, Fcb
        BEQ     %FT45
        CMPS    R1, R0
        BHI     %BT10
        BLO     %FT45
        B       %FT30

20
        LDR     BufPtr, [BufPtr,#NextInFile]
        LDR     R1, [BufPtr,#BufFileOff]
        TEQS    BufPtr, Fcb
        BEQ     %FT40
        CMPS    R1, R0
        BLO     %BT20
        BHI     %FT40
30
        SUB     BufOff, FileOff, R0
        MOV     BufOff, BufOff, LSR #5

 [ DebugG
        DREG    BufOff,,cc
        DREG    BufPtr,,cc
        DLINE   "<FindSubBuf"
 ]
        RestPSR R2,,f
        Pull    "R0-R2,PC"

40      LDR     BufPtr, [BufPtr,#PrevInFile]
45      MOV     BufOff, #32
 [ DebugG
        DREG    BufOff,,cc
        DREG    BufPtr,,cc
        DLINE   "<FindSubBuf"
 ]
        RestPSR R2,,f
        Pull    "R0-R2,PC"

PriorityBlock
 = 0                    ; 0     -> 0
 = 1                    ; 1     -> 1
 = 2,2                  ; 2,3   -> 2
 = 3,3,3,3              ; 4-7   -> 3
 = 4,4,4,4,4,4,4,4      ; 8-15  -> 4
 = 5,5,5,5,5,5,5,5      ; 16-31 -> 5
 = 5,5,5,5,5,5,5
 ALIGN

; ==============
; UpdateBufState
; ==============

;entry
; R2 new state
; BufSz
; BufPtr set up

UpdateBufState ROUT
 [ DebugG
        DREG    R2,,cc
        DREG    BufSz,,cc
        DREG    BufPtr,,cc
        DREG    lr,,cc
        DLINE   "UpdateBufState"
 ]
        Push    "R0,R2,R3,LR"
        SavePSR R3
        STR     R2, [BufPtr,#BufFlags]
        baddr   LR, PriorityBlock
        CMPS    BufSz, #512 :SHR: 5
        ORRLS   R2, R2, R2, LSR #16     ;if 512 or 256 byte sub buffer
        ORRLO   R2, R2, R2, LSR #8      ;if 256 byte sub buffer
        AND     R2, R2, #AllBufFlags
        LDRB    R2, [LR,R2,LSR #3]      ;new priority of whole buffer
        LDRB    R0, [BufPtr,#BufPriority]
 [ DebugG
        DREG    R0,,cc
        DREG    R2,,cc
        DLINE   "old, new"
 ]
        TEQS    R2, R0
        BEQ     %FT90
        STRB    R2, [BufPtr,#BufPriority]
        BL      UnlinkAllocChain        ;BufPtr
        RSBS    LR, R2, #0              ;IF changing to empty (C=1)
        TEQCSS  R0, #0                  ;AND was non empty (Z=0)
        BLHI    UnlinkFileChain         ;THEN unlink file chain
        CMPS    R2, #AwaitsSeqChain
        BLO     %FT80
        CMPS    R2, #ReadAheadChain     ;IF new priority AwaitsSeq or WriteBehind
        TEQNES  R0, #0                  ;AND wasn't empty
        BEQ     %FT80
                                ;THEN special case

; *** SBP: Fri 30th January 1998 ***
;
; The code in here was completely shafted for the special
; case if this is the only buffer on the chain for this
; file (someone wasn't thinking about this, were they?)
;
; added code that checks if the PrevInFile and NextInFile
; pointers are the same; if so then we don't use them, as
; they must point to the fcb (which doesn't have the fields
; that LinkAllocChain uses.

;       LDR     R0, [BufPtr, #PrevInFile]
;       LDR     LR, [BufPtr, #NextInFile]

;       TEQS    LR, R0          ; is it the only buffer in the file?
;       BEQ     %FT80

; *** SBP: Fri 30th January 1998 *** (end)

 [ DebugG
        DREG    R0, "PrevInFile: "
        DREG    LR, "NextInFile: "
 ]
        ASSERT  WriteBehindChain > ReadAheadChain
        ASSERT  ReadAheadChain > AwaitsSeqChain
        LDRLO   LR, [BufPtr,#PrevInFile]        ;IF new priority AwaitsSeq
        LDRHI   LR, [BufPtr,#NextInFile]        ;IF new priority WriteBehind

; MB FIX
; If we found a free buffer then its next and prev pointers will be 0.
        TEQS    LR,#0
        BEQ     %FT80
; end MB FIX

; SBP: better fix to the FCB-confused-with-buffer problem!
        LDR     R0, [BufPtr,#BufFcb]            ;get the FCB ptr
        TEQS    LR, R0
        BEQ     %FT80                           ;don't attempt to link to the FCB!!!
; SBP: end of betterfix

        LDRB    R0, [LR,#BufPriority]
        TEQS    R0, R2
        MOVEQ   R2, LR
 [ DebugG
        DREG    R2, "ptr: "
 ]
        BEQ     %FT85

80
        sbaddr  R0, BufChainsRoot
        ASSERT  ChainRootSz=8
 [ DebugG
        DREG    R2, "pri: "
 ]
        ADD     R2, R0, R2, LSL #3
85

        BL      LinkAllocChain                  ;R2,BufPtr

90
        RestPSR R3,,f
        Pull    "R0,R2,R3,PC"


; ============
; EmptyBuffers
; ============

; File cache and controller must be claimed

;entry
; R0            pointer to process
; BufSz
; FileOff       start
; TransferEnd   end
; Fcb

;exit
; BufOff        corrupt
; BufPtr        any valid for this file

EmptyBuffers ROUT
 [ DebugG
        DREG    BufSz,,cc
        DREG    FileOff,,cc
        DREG    TransferEnd,,cc
        DREG    Fcb,,cc
        DLINE   "EmptyBuffers"
 ]
        Push    "R1,R2,FileOff,LR"
        LDRB    LR, MaxFileBuffers
        TEQ     LR, #0          ;no buffers to empty
        Pull    "R1,R2,FileOff,PC",EQ

        MOV     R1, #0          ;to count write behind freed
        LDR     BufPtr, [Fcb,#PrevInFile]
        BL      LessValid
21
        BL      FindSubBuf      ;FileOff,Fcb,BufPtr -> BufOff,BufPtr
        RSBS    LR, BufOff, #32

        LDRLS   BufPtr, [BufPtr,#NextInFile]
        LDRLS   FileOff, [BufPtr,#BufFileOff]
        BLS     %FT29

        LDR     R2, [BufPtr,#BufFlags]
        MOV     R2, R2, ROR BufOff
25
        TSTS    R2, #WriteBehind
        ADDNE   R1, R1, BufSz, LSL #5
        BIC     R2, R2, #AllBufFlags
        ORR     R2, R2, #EmptyBuf
        MOV     R2, R2, ROR BufSz
        ADD     FileOff,FileOff,BufSz,LSL #5
        SUBS    LR, LR, BufSz
        CMPHIS  TransferEnd, FileOff
        BHI     %BT25

        MOV     R2, R2, ROR LR
        BL      UpdateBufState  ;R2,BufSz,BufPtr
29
        CMPS    FileOff,TransferEnd
        BLO     %BT21

        TEQS    R1, #0
        BLNE    ReduceWriteBehind ;(R0,R1->R1)

        BL      MoreValid
        LDR     BufPtr, [Fcb,#PrevInFile]
        Pull    "R1,R2,FileOff,PC"


; ================
; UnlinkAllocChain
; ================

;entry BufPtr

UnlinkAllocChain ROUT
 [ DebugG
        DREG    BufPtr,,cc
        DLINE   "UnlinkAllocChain"
 ]
        Push    "R0,R1,LR"
        SETPSR  I_bit, LR,, R1                  ;for write behind
        LDR     R0, [BufPtr,#YoungerBuf]
        LDR     LR, [BufPtr,#OlderBuf]
        STR     R0, [LR,#YoungerBuf]
        STR     LR, [R0,#OlderBuf]
        RestPSR R1,,cf
        Pull    "R0,R1,PC"


; ==============
; LinkAllocChain
; ==============

; link as buffer older than buffer R2

; entry R2,BufPtr

LinkAllocChain ROUT
 [ DebugG
        DREG    R2,,cc
        DREG    BufPtr,,cc
        DLINE   "LinkAllocChain"
 ]
        Push    "R0,LR"
        SETPSR  I_bit, LR,, R0                  ;for write behind
        LDR     LR, [R2,#OlderBuf]
        STR     BufPtr,[LR,#YoungerBuf]
        STR     LR, [BufPtr,#OlderBuf]
        STR     R2, [BufPtr,#YoungerBuf]
        STR     BufPtr,[R2,#OlderBuf]
        RestPSR R0,,cf
        Pull    "R0,PC"


; ===============
; UnlinkFileChain
; ===============

;entry BufPtr

UnlinkFileChain ROUT
 [ DebugG
        DREG    BufPtr,,cc
        DLINE   "UnlinkFileChain"
 ]
        Push    "R0,R1,LR"
        SETPSR  I_bit, LR,, R1                  ;for write behind
        STR     BufPtr, [BufPtr, #BufFcb]       ;invalidate so hash lookup fails
        LDR     R0, [BufPtr,#NextInFile]
        LDR     LR, [BufPtr,#PrevInFile]
        STR     R0, [LR,#NextInFile]
        STR     LR, [R0,#PrevInFile]

        TEQS    R0, LR                   ;IF removing last buffer from FCB
        LDREQ   LR, [R0, #FcbExtHandle]  ;AND FCB for file not currently open file
        TEQEQS  LR, #0
        MOVEQ   LR, #-1                  ;THEN mark FCB for deletion
        STREQ   LR, [R0, #FcbIndDiscAdd]

        RestPSR R1,,cf
        Pull    "R0,R1,PC"


; =============
; LinkFileChain
; =============

; link as buffer after buffer R2

; entry R2,BufPtr

LinkFileChain ROUT
 [ DebugG
        DREG    R2,,cc
        DREG    BufPtr,,cc
        DLINE   "LinkFileChain"
 ]
        Push    "R0,R1,LR"
        ADD     R0, BufPtr, #BufFileOff
        SETPSR  I_bit, LR,, R1                  ;for write behind
        ASSERT  BufFcb = BufFileOff + 4
        LDMIA   R0, {R0,LR}
        EOR     R0, LR, R0, LSR #8
        LDRB    LR, BufHashMask
        AND     R0, R0, LR, LSL #2
        LDR     LR, BufHash
        STR     BufPtr, [LR,R0]

        LDR     LR, [R2,#NextInFile]
        STR     BufPtr,[LR,#PrevInFile]
        STR     LR, [BufPtr,#NextInFile]
        STR     R2, [BufPtr,#PrevInFile]
        STR     BufPtr,[R2,#NextInFile]
        RestPSR R1,,cf
        Pull    "R0,R1,PC"


; =========
; LessValid
; =========

LessValid ROUT
 [ DebugG
        DLINE   "LessValid"
 ]
        Push    "R0,R1,LR"
        SETPSR  I_bit, LR,, R1
        LDR     R0, ptr_CannotReset
        LDRB    LR, [R0]
        ADD     LR, LR, #1
        STRB    LR, [R0]
        RestPSR R1,,cf
        Pull    "R0,R1,PC"


; =========
; MoreValid
; =========

MoreValid ROUT
 [ DebugG
        DLINE   "MoreValid"
 ]
        Push    "R0,R1,LR"
        SETPSR  I_bit, LR,, R1
        LDR     R0, ptr_CannotReset
        LDRB    LR, [R0]
        SUB     LR, LR, #1
        STRB    LR, [R0]
        RestPSR R1,,cf
        Pull    "R0,R1,PC"


; =====================
; WaitForControllerFree
; =====================

;controller must be claimed
;write behind on different floppy must have been allowed to finish

;entry R0 -> controller process block

WaitForControllerFree ROUT
        Push    "LR"
 [ DebugG
        DREG    R0,,cc
        DLINE   "start wait for controller free"
 ]
05
        LDRB    LR, [R0,#Process]
        TSTS    LR, #Inactive
 [ DebugG
        BEQ     %FT01
        DREG    R0,,cc
        DLINE   "end wait for controller free"
01
 ]
        Pull    "PC",NE
        BL      UpdateProcess           ;(R0)
        B       %BT05

; ===================
; DiscWriteBehindWait
; ===================

;wait if necessary for write behind to finish on a different (not necessarily) floppy disc
;must not have controller claimed if waiting is necessary

;entry R3 top 3 bits disc

DiscWriteBehindWait ROUT
  [ DebugG
        DREG    R3, ">DiscWriteBehindWait(",cc
        DLINE   ")"
  ]
        Push    "R0-R2,LR"
        SavePSR R2

        ; No waiting if no write behind
        LDRB    LR, MaxFileBuffers
        TEQ     LR, #0
        BEQ     %FT90

        ; Get relevant process block into R0, and relevant NeedFiq bit number into R1
        MOV     R0, R3, LSR #(32-3)
        DiscRecPtr R0, R0
        LDRB    R1, [R0, #DiscFlags]
        TST     R1, #FloppyFlag
        LDREQ   R0, WinnieProcessBlk
        ASSERT  CreateFlag_FixedDiscNeedsFIQ = bit0
        MOVEQ   R1, #0+1
        LDRNE   R0, FloppyProcessBlk
        ASSERT  CreateFlag_FloppyNeedsFIQ = bit1
        MOVNE   R1, #1+1

        ; Don't wait for write behind to finish if not currently going, or if
        ; on the same disc
        LDRB    LR, [R0, #ProcessWriteBehindDisc]
        TEQS    LR, #&FF
        TEQNES  LR, R3, LSR #(32-3)
        BEQ     %FT90


        ; Claim Fiq if needed for this controller - move flag into C bit
        LDRB    LR, FS_Flags
        MOVS    LR, LR, LSR R1
  [ DebugI
        BCC     %FT01
        DLINE   " C6 ",cc
01
  ]
        BLCS    ClaimFiq
 [ Debug3L
        DLINE   "Wbw",cc
 ]

60
        LDR     LR, [R0, #ProcessWriteBehindLeft]
        TEQS    LR, #0
        MOVNE   LR, #1               ;ensure restarts considered soon
        STRNE   LR, TickerState
        BNE     %BT60
 [ Debug3L
        DLINE   "x",cc
 ]

        ; Release Fiq if was claimed above
  [ DebugI
        BCC     %FT01
        DLINE   " R6 ",cc
01
  ]
        BLCS    ReleaseFiq

90
  [ DebugG
        DREG    R3, "<DiscWriteBehindWait(",cc
        DLINE   ")"
  ]
        RestPSR R2,,f
        Pull    "R0-R2,PC"


; ==========================
; FloppyDriveWriteBehindWait
; ==========================

;wait if necessary for write behind to finish on a different floppy disc
;must not have controller claimed if waiting is necessary

; entry R1 drive

DriveWriteBehindWait ROUT
        Push    "R0,R2,R3,LR"
        SavePSR R3
  [ DebugG
        DREG    R1,,cc
        DLINE   ">DriveWriteBehindWait"
  ]

        ; No waiting if no write behind
        LDRB    LR, MaxFileBuffers
        TEQ     LR, #0
  [ DebugG
        BNE     %FT01
        DLINE   "no wait"
01
  ]
        BEQ     %FT90

        ; Get process address into R0, and NeedFiq shift into R2
        TSTS    R1, #bit2                       ;If drive is floppy
        LDREQ   R0, WinnieProcessBlk
        ASSERT  CreateFlag_FixedDiscNeedsFIQ = bit0
        MOVEQ   R2, #0+1
        LDRNE   R0, FloppyProcessBlk
        ASSERT  CreateFlag_FloppyNeedsFIQ = bit1
        MOVNE   R2, #1+1

        LDRB    LR, [R0, #ProcessWriteBehindDrive]
        TEQ     LR, #&FF                        ;AND floppy write behind in progress
        TEQNE   LR, R1                          ;    on different drive
  [ DebugG
        BNE     %FT01
        DLINE   "no wait"
01
  ]
        BEQ     %FT90

        LDRB    LR, FS_Flags
        ASSERT  CreateFlag_FloppyNeedsFIQ = bit1
        MOVS    LR, LR, LSR R2          ;C=1 <=> FIQ needed
  [ DebugI
        BCC     %FT01
        DLINE   " C6 ",cc
01
  ]
        BLCS    ClaimFiq
50
        LDRB    LR, [R0, #ProcessWriteBehindDrive]
        TEQ     LR, #&FF
        MOVNE   LR, #1               ;ensure restarts considered soon
        STRNE   LR, TickerState
        BNE     %BT50
  [ DebugI
        BCC     %FT01
        DLINE   " R6 ",cc
01
  ]
        BLCS    ReleaseFiq

90
  [ DebugG
        DREG    R1,,cc
        DLINE   "<DriveWriteBehindWait"
  ]
        RestPSR R3,,f
        Pull    "R0,R2,R3,PC"


; ========
; LockDisc
; ========

; entry R3 top 3 bits disc
; exit
;  R0,V if error
;  R1 drive

LockDisc ROUT
        Push    "R0,R2-R5,LR"
 [ DebugN
        DREG    R3,">LockDisc(",cc
        DLINE   ")"
 ]
        MOV     R1, R3, LSR #(32-3)
        ; Check for winnie properly
        DiscRecPtr R1, R1
        LDRB    R1, [R1, #DiscFlags]
        TST     R1, #FloppyFlag

        BL      DiscWriteBehindWait             ;(R3)
        LDRB    R4, Interlocks
        ORREQ   LR, R4, #WinnieLock
        ORRNE   LR, R4, #FloppyLock
        STRB    LR, Interlocks                  ;ensure (floppy) controller claimed

        LDREQ   R0, WinnieProcessBlk
        LDRNE   R0, FloppyProcessBlk
        LDRB    LR, [R0,#Process]
        TSTS    LR, #ReadAhead :OR: WriteBehind
        LDRNE   LR, [R0,#ProcessFcb]    ;If background floppy op
        LDRNE   LR, [LR,#FcbIndDiscAdd]
        EORNE   LR, LR, R3
        ANDNES  LR, LR, #DiscBits
        BLNE    WaitForControllerFree   ;(R0) on other disc let it finish
05
        BL      FindDisc        ;(R3->R0,R1,V)
        BVS     %FT90

        BL      LockDrive

        DrvRecPtr  R5, R1
        LDR     R2, [R5,#ChangedSeqNum]
        BL      LowPollChange

        TSTS    R3, #MiscOp_PollChanged_NotChanged_Flag
        STREQ   R2, [R5,#ChangedSeqNum]
        BLEQ    UnlockDrive
        LDREQ   R3, [SP,#2*4]
        BEQ     %BT05

90
        STRB    R4, Interlocks  ;restore entry interlocks
        STRVS   R0, [SP]
 [ DebugG
        DREG    R1,"<LockDisc(",cc
        BVC     %FT01
        DREG    R0,",",cc
01
        DLINE   ")"
 ]
        Pull    "R0,R2-R5,PC"


; ========
; FindDisc
; ========

; entry R3 top 3 bits disc
; exit  R0,V if error else R1 drive

FindDisc ROUT
        Push    "R0,R2-R7,LR"
 [ DebugG :LOR: Debug4
        DREG    R3, ">FindDisc(",cc
        DLINE   ")"
 ]

        ; Disc number in R5, disc record in R6
        MOV     R5, R3, LSR #(32-3)
        BL      DiscAddToRec    ;(R3->LR)
        MOV     R6, LR

        ; ensure disc cant be forgotten by FindDiscRec
        BL      IncUsage        ;(R3)

        ; UpCall_MediaNotPresent iteration count
        MOV     R4, #0
00
;IF we think disc is in drive
        LDRB    R1, [R6,#DiscsDrv]
        CMPS    R1, #8                  ;V=0

;AND certain of drive contents
        MOVCC   R0, R1
        BLCC    PollChange      ;(R0->LR)
        CMPCCS  LR, #8
                        ;V=0
;THEN no need to search for disc
 [ Debug4
        BCS     %FT01
        DLINE   "Certain where disc is"
01
 ]
        BCC     %FT60   ;V=0

; uncertain
 [ Debug4
        DLINE   "Not certain where disc is"
 ]

;first consider old drive
        LDRB    R1, [R6,#DiscsDrv]      ;may have been altered by PollChange
        CMPS    R1, #8          ;if disc is probably still in drive, try it first
        BHS     %FT05           ; Branch if disc not attached to drive

 [ Debug4
        DREG    R1,"Checking old drive "
 ]
        BL      WhatDisc        ;(R1->R0-R2,R3,V)
        BVS     %FT05

        ; branch if same disc in drive
        CMPS    R2, R5          ;also V=0
        BEQ     %FT60           ;disc is still in that drive

        ; Check for ambiguous disc
        BL      %FT90
        BVS     %FT50

05
        ; Here if either disc not attached to drive, or different disc in drive

 [ Debug4
        DLINE   "No idea where disc is - checking all drives"
 ]

        ; Construct mask of discs to WhatDisc in R7 - bit is 0 means WhatDisc the drive
        MOV     R7, #-1         ;must be at least one floppy if here
        LDRB    R0, Floppies    ;identify uncertain drives
        ADD     R0, R0, #4
15
        ; Set carry and skip pollchange if bad drive, otherwise drop through to pollchange
        SUB     R0, R0, #1
        RSBS    LR, R0, #3      ; CS if R0 is 3 or less, ie not a floppy
        LDRCSB  LR, Winnies
        CMPCS   R0, LR
        BCS     %FT17           ; CS if R0<=3 and R0>=Winnies

        ; If different drive to original do PollChange
        CMPS    R0, R1          ; CS if EQ
        BLNE    PollChange      ;(R0->LR)
        RSBNES  LR, LR, #7      ; set carry if returned disc is certain

17
        ; Combine carry into R7
        ADC     R7, R7, R7      ;bit 0 set <=> certain
        CMPS    R0, #0
        BHI     %BT15

;now check other drives in turn
 [ Debug4
        DREG    R7, "Mask of drives which don't need checking is "
 ]
        MOV     R1, #0          ; Start at drive 0
20
        ; Skip doing WhatDisc if not flagged from above loop
        MOVS    R7, R7, ASR #1
        BCS     %FT40

        BL      WhatDisc        ;(R1->R0-R3,V)
        BVS     %FT40
                        ;If successfully examined disc
        TEQS    R2, R5          ;and it was the one we wanted
        BEQ     %FT60           ;then dont need to look any further

        ; Check for ambiguous disc
        BL      %FT90
        BVS     %FT50

40
        ; Move to next drive and stop if not more drives to check
        ADD     R1, R1, #1
        CMPS    R7, #-1
        BNE     %BT20           ;loop until all uncertain drives tried

        ; If here, then media not in any drive
        MOV     R0, #UpCall_MediaNotPresent
        ADD     R1, R6, #DiscRecord_DiscName
 [ Debug4
        DREG    r6, "R6 Before UpCall in FindDisc is "
        DSTRING r1, "This gives a disc name of "
 ]
        BL      UpCall          ;(R0,R1,R4->R2-R4,C)
        BCS     %BT00           ;try again if claimed

        ; UpCall not claimed so return disc not present
        MOV     R0, #DiscNotPresentErr
        BL      SetV

50
        STRVS   R0, [SP]

60
        ; If UpCall was issued then tell everybody the search's ended
        TEQS    R4, #0
        SavePSR R4              ;save V
        MOVNE   R0, #UpCall_MediaSearchEnd
        BLNE    OnlyXOS_UpCall
        RestPSR R4,,f           ;restore V

        ; Release the disc record
        LDR     R3, [SP,#2*4]
        BL      DecUsage        ;(R3) protection from FreeDiscRec off

 [ DebugG :LOR: Debug4
        DREG    R1, "<FindDisc (",cc
        DLINE   ")"
        DebugError "    error from FindDisc"
 ]
        Pull    "R0,R2-R7,PC"

; Subroutine to check whether disc number r2 matches disc number r5 in name
90
        ;Was it a disc with the same name?, if so give ambigdiscerr
        Push    "r1,r3,r4,r5,lr"
        DiscRecPtr r1, r2
        DiscRecPtr r4, r5
        LDR     r3, [r4, #DiscRecord_Root]
        BL      TestDir
        MOVEQ   r5, #&ff
        MOVNE   r5, #&7f
        ADD     r1, r1, #DiscRecord_DiscName
        ADD     r4, r4, #DiscRecord_DiscName
 [ Debug4
        DSTRING r1, "Trying found disc ",cc
        DSTRING r4, " against required disc "
 ]
        BL      LexEqv
        MOVEQ   r0, #AmbigDiscErr
        BLEQ    SetV
        Pull    "r1,r3,r4,r5,pc"


; =======
; FreeFcb
; =======

; Free a file control block, having first marked any file cache buffers as empty

;entry
; R8 -> previous FCB in chain
; R9 -> FCB
; assumes FileCache not claimed and no background transfers for FCB

; exit R0,V if error else R0 corrupt

FreeFcb
        Push    "R1,R2,BufPtr,BufSz,LR"
        SavePSR lr
        Push    "lr"
        BL      ClaimFileCache
        LDR     R2, = EmptyBuf * &01010101
        MOV     BufSz, #1*K :SHR: 5
        MOV     BufPtr, Fcb
10
        LDR     BufPtr, [BufPtr, #NextInFile]
        TEQS    BufPtr, Fcb
        BLNE    UpdateBufState    ;(R2,BufSz,BufPtr)
        BNE     %BT10
        BL      ReleaseFileCache
        LDR     LR, [R9, #FcbNext]
        STR     LR, [R8, #FcbNext]
 [ UseRMAForFCBs
        MOV     R0, #ModHandReason_Free
        MOV     R2, R9
        BL      OnlyXOS_Module    ;and return to heap (R0,R2->R0,V)
 |
        MOV     R0, #HeapReason_Free
        MOV     R2, R9
        BL      OnlySysXOS_Heap   ;and return to heap (R0,R2->R0,V)
 ]
        Pull    "lr"
        Pull    "R1,R2,BufPtr,BufSz"
        B       PullLinkKeepV


; ===============
; ClaimController
; ===============

; Only to be called if not already claimed, and in supervisor mode

;entry R0 -> Controller process block

ClaimController ROUT
 [ DebugG
        DREG    R0,,cc
        DLINE   "ClaimController"
 ]
        Push    "LR"
        LDR     LR, FloppyProcessBlk
        TEQS    R0, LR
        LDRB    LR, Interlocks
        ORREQ   LR, LR, #FloppyLock
        ORRNE   LR, LR, #WinnieLock
        STRB    LR, Interlocks
        Pull    "PC"

; =================
; ReleaseController
; =================

; Only to be called in supervisor mode

;entry R0 -> Controller process block

ReleaseController ROUT
 [ DebugG
        DREG    R0,,cc
        DLINE   "ReleaseController"
 ]
        Push    "R1,LR"
        SavePSR R1
        LDR     LR, FloppyProcessBlk
        TEQS    R0, LR
        LDRB    LR, Interlocks
        BICEQ   LR, LR, #FloppyLock
        BICNE   LR, LR, #WinnieLock
        STRB    LR, Interlocks
        RestPSR R1,,f
        Pull    "R1,PC"


; ==============
; ClaimFileCache
; ==============

; Only to be called if not already claimed

ClaimFileCache ROUT
 [ DebugG
        DLINE   "ClaimFileCache"
 ]
        Push    "LR"
        LDRB    LR, Interlocks
        ORR     LR, LR, #FileCacheLock
        STRB    LR, Interlocks
        Pull    "PC"


; ================
; ReleaseFileCache
; ================

; Only to be called if not already claimed

ReleaseFileCache ROUT
 [ DebugG
        DLINE   "ReleaseFileCache"
 ]
        Push    "LR"
        LDRB    LR, Interlocks
        BIC     LR, LR, #FileCacheLock
        STRB    LR, Interlocks
        Pull    "PC"



 [ DebugJ
; Check process blocks, see also CPBs in FileCore70
; entry FCB

Check ROUT
        Push    "R0-R3,BufSz,R5,R6,Fcb,BufPtr,LR"
        WritePSRc SVC_mode :OR: I_bit,R5,,R1
        Push    R1

        MOV     R1, #0  ;count buffers
        LDR     R5, [R1, #&FFC]
        STR     R1, [R1, #&FFC]

        ; 1st check:
        ; Go through the WriteBehind chain and ensure that all the buffers
        ; in that chain belong to the current WriteBehindDisc for the relevant
        ; controller.
        sbaddr  R0, BufChainsRoot + ( WriteBehindChain * ChainRootSz )
        MOV     BufPtr, R0
        B       %FT15
10
        LDR     R2, [BufPtr, #BufFcb]
        LDRB    R3, [R2, #FcbFlags]
        TST     R3, #FcbFloppyFlag
        LDREQ   R3, WinnieProcessBlk
        LDRNE   R3, FloppyProcessBlk
        LDRB    R3, [R3, #ProcessWriteBehindDisc]
        LDR     R2, [R2, #FcbIndDiscAdd]
        TEQ     R3, R2, LSR #(32-3)
        BNE     %FT15

        ; If here have found a buffer in the write behind chain
        ; which _isn't_ attached to the write behind disc for the
        ; relevant controller.
        DLINE   "BAD WBdisc"
        B       %FT90

15
        LDR     BufPtr, [BufPtr, #YoungerBuf]
        TEQS    BufPtr, R0
        BNE     %BT10

        ; 2nd check:
        ; Go through all chains checking that the buffers attached to that
        ; chain have the right priority.
        ; In this loop the buffers are counted
        MOV     R3, #WriteBehindChain
        sbaddr  R0, BufChainsRoot + ( WriteBehindChain * ChainRootSz )
20
        MOV     BufPtr, R0
        B       %FT40

30
        ADD     R1, R1, #1
        LDRB    LR, [BufPtr, #BufPriority]
        TEQS    LR, R3
        BEQ     %FT40
        DLINE   "BAD PRIORITY",cc
        DREG    R3,,cc
        DREG    BufPtr,,cc
        B       %FT90
40
        ; Next buffer
        LDR     BufPtr, [BufPtr, #YoungerBuf]
        TEQS    BufPtr, R0
        BNE     %BT30

        ; Next chain
        SUBS    R3, R3, #1
        SUBPL   R0, R0, #ChainRootSz
        BPL     %BT20

        ; 3rd check:
        ; Ensure the number of buffers attached to chains corresponds
        ; exactly to the space allocated to these buffers (ie make
        ; sure no extras nor dropouts occur)
        LDR     R0, FileBufsStart
        ADD     R3, R0, R1, LSL #10
        ADD     R3, R3, R1, LSL #5
        LDR     LR, FileBufsEnd
        TEQS    R3, LR
        BEQ     %FT50

        DLINE   "BAD ALLOC",cc
        DREG    R1,,cc
        DREG    R0,,cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
        B       %FT90

50

        ; 4th check:
        ; For each Fcb ensure the buffers attached to it have valid
        ; priorities for buffers attached to Fcbs.
        ; This loop accumulates the WriteBehind quantities for the
        ; two controllers. The calculation is based on the number of buffers
        ; attached, not the filled-in WriteBehind quantity
        MOV     R0, #0  ; Floppy WriteBehind
        MOV     R1, #0  ; Winnie WriteBehind
        sbaddr  Fcb, FirstFcb-FcbNext
        B       %FT80
55
        LDRB    R6, [Fcb, #FcbFlags]
        MOV     BufPtr,Fcb
        LDRB    BufSz, [Fcb,#FcbBufSz]
        B       %FT70
60
        LDRB    R3, [BufPtr,#BufPriority]
        CMPS    R3, #EmptyChain
        CMPNES  R3, #WriteBehindChain + 1
        BLO     %FT65

        DLINE   "BAD PRIORITY"
        DREG    R2,,cc
        DREG    R3,,cc
        DREG    Fcb,,cc
        DREG    BufPtr,,cc

65
        TSTS    R6, #FcbFloppyFlag
        BEQ     %FT68
        LDR     R2, [BufPtr,#BufFlags]
67
        TSTS    R2, #WriteBehind
        ADDNE   R0, R0, BufSz, LSL #5
        MOVS    R2, R2, LSR BufSz
        BNE     %BT67
        B       %FT70
68
        LDR     R2, [BufPtr, #BufFlags]
69
        TSTS    R2, #WriteBehind
        ADDNE   R1, R1, BufSz, LSL #5
        MOVS    R2, R2, LSR BufSz
        BNE     %BT69
        B       %FT70

70
        ; Next buffer in file
        LDR     BufPtr, [BufPtr,#NextInFile]
        TEQS    BufPtr, Fcb
        BNE     %BT60
80
        ; Next file
        LDR     Fcb, [Fcb,#FcbNext]
        CMPS    Fcb, #-1
        BNE     %BT55

        ; Check the WriteBehind quantities for both controllers
        LDR     R2, FloppyProcessBlk
        TST     R2, #BadPtrBits
        LDREQ   R2, [R2, #ProcessWriteBehindLeft]
        MOVNE   R2, R0
        TEQS    R0, R2
        BNE     %FT85
        LDR     R2, WinnieProcessBlk
        TST     R2, #BadPtrBits
        LDREQ   R2, [R2, #ProcessWriteBehindLeft]
        MOVNE   R2, R1
        TEQS    R1, R2
85
        BNE     %FT88
        MOV     R1, #0
        STR     R5, [R1, #&FFC]
        Pull    R1
        RestPSR R1,,cf
        Pull    "R0-R3,BufSz,R5,R6,Fcb,BufPtr,PC"
88
        DLINE   "BAD WB",cc
        DREG    R0,,cc
        DREG    R2,,cc
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"
        LDR     LR, [SP,#10*4] ; sp offset OK.
        Push    "r0"
        MOV     r0, lr
        DREG    r0, "", cc
        Pull    "r0"

90
        PullEnv

 regdump
        MOV     PC, #0
 ]

        LTORG
        END
