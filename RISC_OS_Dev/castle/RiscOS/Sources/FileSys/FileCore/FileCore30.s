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
; >FileCore30

        TTL     "Useful Routines"

; *********************************
; ***  CHANGE LIST AND HISTORY  ***
; *********************************
;
; 16-Jun-94   AMcC  Replaced ScratchSpaceSize with ?ScratchSpace
;

UseScratchSpace * 0     ;these are bit numbers
UseSpareScreen  * 1
UseWimpFree     * 2
UseRmaHeap      * 3
UseSysHeap      * 4

        ASSERT  DiscOp_Op_ScatterList_Flag=1 :SHL: 5

UseApplicArea   * 6

UseIndOp        * 7     ;set this bit if to use file start and offset
                        ;rather than physical disc address
UseDirSpace     * 8

;must have all files closed to use dir space as it includes file buffers

; ===============
; DefaultMoveData
; ===============

; MoveData using all possible RAM, and indirect disc addresses, from start

DefaultMoveData
        MOV     R0, #(1:SHL:UseScratchSpace) :OR: (1:SHL:UseSpareScreen) :OR: (1:SHL:UseWimpFree) :OR: (1:SHL:UseRmaHeap) :OR: (1:SHL:UseSysHeap) :OR: (1:SHL:UseIndOp) :OR: DiscOp_Op_ScatterList_Flag
        MOV     R4, #0   ;fall into MoveData

; ========
; MoveData
; ========

;entry
; R0 data move option bits, must have scatter bit set
; R1 source
; R2 dest
; R3 length
; R4 start offset if UseIndOp

;exit
; R0 IF error V set, R0 result
; R1 incremented by amount transferred if not UseIndOp
; R2 incremented by amount transferred if not UseIndOp
; R3 decremented by amount transferred
; R4 incremented by amount transferred if UseIndOp

MoveData
        Push    "R0-R11,LR"
 [ DebugD
        mess    ,"options |source  |dest    |length  |offset - enter MoveData",NL
        DREG    R0
        DREG    R1
        DREG    R2
        DREG    R3
        DREG    R4
        mess    ,,NL
 ]
        LDMIA   SP, {R6-R10}

        MOV     R3, R7
        BL      IncUsage        ;stops disc searching forgetting other disc
        BL      ReadAllocSize   ;(R3->LR) chunks must be multiple of larger alloc. size
        MOV     R1, LR
        MOV     R3, R8
        BL      IncUsage        ;(R3)
        BL      ReadAllocSize   ;(R3->LR)
        CMPS    R1, LR
        MOVHS   R3, R1
        MOVLO   R3, LR
        MOV     R1, R3
        CMPS    R9, R3
        MOVHS   R2, R9
        MOVLO   R2, R3
        BL      FindBuffer      ;(R0-R3->R0-R2,V)
        Push    "R1,R2"
        BVS     %FT95
10
        LDMIA   SP, {R3,R4}     ;scatter ptr, buffer length
        CMPS    R4, R9
        MOVHI   R4, R9
        MOV     R11,R4

        TSTS    R6, #1 :SHL: UseIndOp
        MOVNE   R5, R10
        Push    "R3-R5"
        MOV     R1, #DiscOp_ReadSecs :OR: DiscOp_Op_ScatterList_Flag :OR: DiscOp_Op_IgnoreEscape_Flag
        MOV     R2, R7
        BL      InitScatter
        BLNE    GenIndDiscOp    ;(R1-R5->R0,R3-R5,V)
        BLEQ    DoDiscOp        ;(R1-R4->R0,R2-R4,V)
        Pull    "R3-R5"
        BVS     %FT90

        TSTS    R6, #1 :SHL: UseIndOp
        MOV     R1, #DiscOp_WriteSecs :OR: DiscOp_Op_ScatterList_Flag :OR: DiscOp_Op_IgnoreEscape_Flag
        MOV     R2, R8
        BL      InitScatter
        BLNE    GenIndDiscOp    ;(R1-R5->R0,R3-R5,V)
        BLEQ    DoDiscOp        ;(R1-R4->R0,R2-R4,V)

        SUB     R11,R11,R4      ;amount transferred
 [ BigDisc
        MOVEQ   R3, R7          ; for ReadSectorSize
        BLEQ    ReadSectorSize  ; get sector size
        ADDEQ   R7, R7, R11, LSR LR
        ADDEQ   R8, R8, R11, LSR LR
        SUB     R9, R9, R11
        ADDNE   R10,R10,R11
 |
        ADDEQ   R7, R7, R11
        ADDEQ   R8, R8, R11
        SUB     R9, R9, R11
        ADDNE   R10,R10,R11
 ]
        BVS     %FT90
        TEQS    R9, #0          ;any left ?
        BNE     %BT10
90
        BL      ReturnBuffer
95
        ADD     SP, SP, #2*4      ;balance stack
        MOV     R3, R7
        BL      DecUsage
        MOV     R3, R8
        BL      DecUsage
        STMIB   SP, {R7-R10}
 [ DebugD
        mess    ,"source  |dest    |length  |offset  |result - leave MoveData",NL
        DREG    R1
        DREG    R2
        DREG    R3
        DREG    R4
        DREG    R0,VS
        mess    ,,NL
 ]
        STRVS   R0, [SP]
        Pull    "R0-R11,PC"


; ===========
; InitScatter
; ===========

; init scatter list from copy

InitScatter
        Push    "R0-R3,LR"
        SavePSR R3
        sbaddr  R1, ScatterList
        ADD     R0, R1, #ScatterCopy-ScatterList
        MOV     R2, #ScatterListLen
        BL      BlockMove
        RestPSR R3,,f
        Pull    "R0-R3,PC"

; =========
; ReadHex64
; =========

; Routine to convert a hex string to a 64bit cardinal value.
;
; entry
;    R0 - pointer to string to convert
;
; exit
;    R1 - ls word of value
;    R2 - ms word of value

; The routine uses OS_ReadUnsigned to read the two words
; of the value.  As the length of the number is not
; known when generating the value, the routine must
; perform some adjustment of the value to generate the
; appropriate information.

ReadHex64 ROUT
        Push    "R3,R4,LR"
        MOV     R1, #0
        MOV     R2, #0
        MOV     R4, #0

10
        LDRB    R3,[R0],#1
        CMP     R3,#'a'
        SUBHS   R3, R3, #32

        CMP     R3,#'0'
        RSBHSS  LR,R3,#'F'
        BLT     %FT90           ; not any sort of digit

        CMP     R3,#'9'
        SUBLE   R3, R3, #'0'
        BLE     %FT30           ; a number

        SUBS    R3,R3,#'A'
        RSBHSS  LR,R3,#'F'-'A'
        ADD     R3,R3,#10
        BLT     %FT90           ; not A-F

30
        MOV     R2, R2, LSL #4
        ADD     R2, R2, R1, LSR #28
        ADD     R1, R3, R1, LSL #4
        B       %BT10

90
 [ DebugQ
        DREG    R1, "L.S. word"
        DREG    R2, "M.S. word"
 ]
        Pull    "R3,R4,PC"

; ==========
; FindBuffer
; ==========

; find some RAM to use as buffer

; entry
;  R0 data move option bits
;  R1 min length MUST BE NON ZERO
;  R2 max length
;  R3 all chunks must be multiple of this length, which is a power of 2

; exit
; IF error V set, R0 result
; ELSE
;  R0 ?
;  R1 start RAM address or ptr to scatter list if scatter requested
;  R2 length claimed
;  R3 ?

FindBuffer ROUT
        Push    "R0-R3,R4-R11,LR"
 [ DebugD
        mess    ,"options |min buf |max buf |blk size - FindBuffer",NL
        DREG    R0, " ", cc
        DREG    R1, " ", cc
        DREG    R2, " ", cc
        DREG    R3, " "
 ]
        BL      ReturnBuffer    ;return any chunks still claimed
        Pull    "R4-R7"

        LDR     LR, FS_Flags
        TSTS    LR, #CreateFlag_NoBigBuf
        ANDNE   R4, R4, #DiscOp_Op_ScatterList_Flag :OR: (1 :SHL: UseScratchSpace)

        SUB     R7, R7, #1      ;make a mask

        CMP     R6, #1*K*M      
        MOVHI   R6, #1*K*M      ;clamp at 1G RAM claim
        ADDLS   R6, R6, R7
        BICLS   R6, R6, R7      ;or round up to nearest chunk multiple

        MOV     R8, #0          ;init chunk ctr
        MOV     R9, #0          ;init total length
00
        MOV     R11,#0          ;init max length this pass

        TSTS    R4, #1 :SHL: UseScratchSpace
        MOVNE   R0, #UseScratchSpace
        MOVNE   R2, #?ScratchSpace
        BLNE    %FT90

        TSTS    R4, #1 :SHL: UseSpareScreen
        BEQ     %FT05
        MOV     R0, #ClaimSpareScreen
        MOV     R1, #&ffffffff          ;force claim fail in order to read free
        BL      OnlyXOS_ClaimScreenMemory      ;(R0,R1->R1,R2,C)
        MOV     R0, #UseSpareScreen
        MOV     R2, R1
        BL      %FT90

05
        TSTS    R4, #1 :SHL: UseWimpFree
        BEQ     %FT07
        MOV     R0, #1
        MOV     R1, #&ffffffff          ; Much too much to get claimed
        BL      OnlyXWimp_ClaimFreeMemory
        BVS     %FT07                   ;no wimp
        CMPS    R1, #0
        BEQ     %FT07                   ;already claimed/none available
        MOV     R0, #UseWimpFree
        MOV     R2, R1
        BL      %FT90

07
        TSTS    R4, #1 :SHL: UseRmaHeap
        BEQ     %FT10
        MOV     R0, #ModHandReason_RMADesc
        BL      OnlyXOS_Module          ;(R0->R0,R2,R3,V)
        BVS     %FT10
        SUBS    r2, r2, #2048
        MOVGT   R0, #UseRmaHeap
        BLGT    %FT90

10
        TSTS    R4, #1 :SHL: UseSysHeap
        BEQ     %FT15
        MOV     R0, #HeapReason_Desc
        BL      OnlySysXOS_Heap         ;(R0->R0,R2,R3,V)
        BVS     %FT15
        SUBS    r2, r2, #2048
        MOVGT   r0, #UseSysHeap
        BLGT    %FT90

15
        TSTS    R4, #1 :SHL: UseApplicArea
        BLNE    OnlyXOS_GetEnv
        MOVNE   R0, #UseApplicArea
        SUBNE   R2, R1, #AppSpaceStart
        BLNE    %FT90

        TSTS    R4, #1 :SHL: UseDirSpace
        MOVNE   R0, #UseDirSpace
        LDRNE   R2, FileBufsStart
        SUBNE   R2, R2, SB
 [ BigDir
        SUBNE   R2, R2, #(:INDEX:DirCache) :AND: :NOT: 255
        SUBNE   R2, R2, #(:INDEX:DirCache) :AND: 255
 |
        SUBNE   R2, R2, #:INDEX:DirBuffer
 ]
        BLNE    %FT90

        ; With modern kernels not supporting free pool locking, our original
        ; tactic of just claiming free space without actively growing DAs isn't
        ; going to work, because we no longer have the free pool to fall back on
        ; as a source of 'infinite' free memory.
        ; So if we've failed to find enough free space, and claiming from the
        ; RMA is allowed, try growing the RMA to be large enough and then give
        ; it another chance.
        CMP     R11, R5                 ;failed to get min length
        CMPLO   R9, #1                  ;and haven't claimed any yet
        BHS     %FT17
        TST     R4, #1 :SHL: UseRmaHeap ;and RMA available
        BEQ     %FT17
        ; Try and limit max claim to 1MB so that we don't completely empty the
        ; free pool. I.e. claim max(min(1MB,max_length),min_length)
        CMP     R6, #1 :SHL: 20
        MOVHS   R1, #1 :SHL: 20
        MOVLO   R1, R6
        CMP     R1, R5
        MOVLO   R1, R5
        ; Round up to size multiple
        ADD     R1, R1, R7
        BIC     R1, R1, R7
        ; Add safety net to ensure background claimants have a little bit of
        ; free memory to work with
        ADD     R1, R1, #4096
        ; Grow dynamic area (will probably leave us with more space than we
        ; need, but will avoid us claiming all the spare heap space and causing
        ; issues for background claimants)
        MOV     R0, #1
 [ DebugD
        DREG    R1, "trying to grow RMA by "
 ]
        SWI     XOS_ChangeDynamicArea
 [ DebugD
        DREG    R1, "managed to grow RMA by "
 ]
        ; Check RMA again if any grow was performed
        CMP     R1, #0
        BEQ     %FT17
        MOV     R0, #ModHandReason_RMADesc
        BL      OnlyXOS_Module          ;(R0->R0,R2,R3,V)
        BVS     %FT17
        SUBS    r2, r2, #2048
        MOVGT   R0, #UseRmaHeap
        BLGT    %FT90

17
        TSTS    R4, #DiscOp_Op_ScatterList_Flag
        BEQ     %FT20
        TEQS    R11,#0                  ;scatter case, claim any
        BEQ     %FT18
        BL      %FT45
        TEQS    R8,#ScatterMax
        BNE     %BT00                   ;loop until no more or list full
18      CMPS    R9, R5
        BLO     %FT35                   ;if failed to get min
        BL      InitScatter
        sbaddr  R1,ScatterList
        B       %FT25

20
        CMPS    R11,R5
        BLO     %FT40
        BL      %FT45
25
        MOV     R0, #0
        MOV     R2, R9
        B       %FT42

35
        BL      ReturnBuffer
40
        MOV     R0, #BufferErr
42
        BL      SetVOnR0
 [ DebugD
        mess    ,"options |buffer  |length  - leave FindBuffer",NL
        DREG    R0
        DREG    R1
        DREG    R2
        mess    ,,NL
 ]
        Pull    "R4-R11,PC"

Sink
        Pull    "PC"

45                                      ;CLAIM CHUNK
 [ DebugD
        DREG    R10
        DREG    R11
        mess    ,"Claim Chunk",NL
 ]
        MOV     R2,R11
        Push    "LR"
        CMPS    R10,#UseScratchSpace
        LDREQ   R1, =ScratchSpace
        BICEQ   R4, R4, #1 :SHL: UseScratchSpace  ;cant use it again

        CMPS    R10,#UseSpareScreen
        BNE     %FT50
        MOV     R0, #ClaimSpareScreen
        MOV     R1, R11
        BL      OnlyXOS_ClaimScreenMemory       ;(R0,R1->R1,R2,C)
        ADDCS   SP, SP, #4
        BCS     %BT00                   ;unexpected space claim failure
        MOV     R0, #WrchV
        baddr   R1, Sink
        BL      OnlyXOS_Claim           ;(R0,R1->R0,V) ignore errors
        MOV     R1, R2
        BIC     R4, R4, #1 :SHL: UseSpareScreen

50
        CMPS    R10,#UseWimpFree
        BNE     %FT52
        MOV     R0, #1
        MOV     R1, R11
        BL      OnlyXWimp_ClaimFreeMemory
        BIC     R4, R4, #1 :SHL: UseWimpFree
        MOV     R1, R2
52

        MOV     R3, R11
        CMPS    R10,#UseRmaHeap
        BNE     %FT55
        MOV     R0, #ModHandReason_Claim
        BL      OnlyXOS_Module
        B       %FT60

55
        CMPS    R10,#UseSysHeap
        BNE     %FT65
        MOV     R0, #HeapReason_Get
        BL      OnlySysXOS_Heap         ;(R0,R3->R0,R2,V)
60
        ADDVS   SP, SP, #4
        BVS     %BT00                   ;unexpected space claim failure
        MOV     R1, R2
65
        CMPS    R10,#UseApplicArea
        BNE     %FT70

        MOV     R0, #FSControl_StartApplication ; Start parent module up as application
        baddr   R1, anull               ; command tail
        LDR     R2, ParentBase          ; CAO pointer
        LDR     R3, [R2, #Module_TitleStr] ; command name
        BL      OnlyXOS_FSControl
        MOV     R1, #AppSpaceStart
        BIC     R4, R4, #1 :SHL: UseApplicArea

70
        CMPS    R10,#UseDirSpace
        BLEQ    LockDirCache
        BLEQ    InvalidateBufDir
        BLEQ    InvalidateDirCache
 [ BigDir
        sbaddr  R1, DirCache,EQ
 |
        sbaddr  R1, DirBuffer,EQ
 ]
        BICEQ   R4, R4, #1 :SHL: UseDirSpace

        MOV     R2, R11
        sbaddr  R3, ScatterSource
        STRB    R10,[R3,R8]
        ADD     R3, R3, #ScatterCopy-ScatterSource
        ADD     R3, R3, R8, LSL #3
 [ DebugD
        DREG    R1
        DREG    R2
        mess    ,"add len",NL
 ]
        STMIA   R3, {R1,R2}             ;save (address,length) pair
        ADD     R8, R8, #1
        ADD     R9, R9, R2
        STRB    R8, ScatterEntries

        Pull    "PC"

;  R0 chunk source
;  R2 chunk length
;  R4 option bits
;  R5 min length
;  R6 max length
;  R7 bits to clear to round length
;  R8 chunk ctr
;  R9 total length claimed
;  R10 source of max length chunk
;  R11 max length this pass

90                      ;FIND BIGGEST SOURCE
        SUB     R3, R6, R9      ;max amount still needed
        CMPS    R2, R3          ;if this chunk bigger than that
        MOVGT   R2, R3          ;reduce it
        BIC     R2, R2, R7      ;ensure multiple of correct length
        CMPS    R2, R11         ;IF bigger than largest this pass
        MOVGT   R11,R2          ; alter largest this pass
        MOVGT   R10,R0          ; note source
        MOV     PC, LR


; ============
; ReturnBuffer
; ============

; return chunks claimed from spare screen and system heap to form buffer

ReturnBuffer ROUT
        Push    "R0-R5,LR"
        SavePSR R5
        MOV     R0, #WrchV              ;release WrchV from sink even if not
        baddr   R1, Sink                ;claimed
        BL      OnlyXOS_Release         ;(R0,R1->R0,V) ignore errors
        LDRB    R4, ScatterEntries
        B        %FT10
05
        sbaddr  R0, ScatterCopy
        LDR     R2, [R0,R4,LSL #3]       ;->chunk
        SUB     R0, R0, #ScatterCopy-ScatterSource
        LDRB    R1, [R0,R4]

 [ DebugD
        DREG    R1
        DREG    R2
        mess    ,"return chunk",NL
 ]

        CMPS    R1, #UseSpareScreen
        MOVEQ   R0, #ReleaseSpareScreen
        BLEQ    OnlyXOS_ClaimScreenMemory

        CMPS    R1, #UseWimpFree
        MOVEQ   R0, #0
        BLEQ    OnlyXWimp_ClaimFreeMemory

        CMPS    R1, #UseRmaHeap
        MOVEQ   R0, #ModHandReason_Free
        BLEQ    OnlyXOS_Module          ;(R0,R2->R0,V)
 [ Dev
        mess    VS,"bad RMA return",NL
 ]
        CMPS    R1, #UseSysHeap
        MOVEQ   R0, #HeapReason_Free
        BLEQ    OnlySysXOS_Heap         ;(R2->R0,V)
 [ Dev
        mess    VS,"bad sys heap return",NL
 ]
        CMPS    R1, #UseDirSpace
        BLEQ    UnlockDirCache
        STRB    R4, ScatterEntries
10
        SUBS    R4, R4, #1
        BPL     %BT05
        RestPSR R5,,f
        Pull    "R0-R5,PC"


; ======
; UpCall
; ======

;common code for UpCall_MediaNotPresent and UpCall_MediaNotKnown
;OSS Now tells driver to eject the preffered drive, if the driver claims
;to support any ejects. This works even when auto insert detecting because
;FileCore always examines the disc and calls UpCall() only if the disc is
;not found, so we are in no danger of ejecting the new disc.

;entry
; R0    UpCall reason code
; R1 -> disc name (possibly not terminated if max length)
; R4    iteration counter

;exit   C=1 <=> upcall claimed
; R2,R3 corrupt
; R4    incremented

disc DCB "disc",0
        ALIGN
        ^ 0,sp
UpCall_NameBuffer       # NameLen+1
UpCall_MediaTypeBuffer  # 30
UpCall_FrameSize * :INDEX:@ + 3 :AND: :NOT: 3

UpCall
        Push    "r0,r1,r5,r6,lr"
 [ DebugU
        DREG    r0,"UpCall(",cc
        DSTRING r1,",",cc
        DREG    r4,",",cc
        DLINE   ")"
 ]
        SUB     sp, sp, #UpCall_FrameSize
        MOV     r0, #MiscOp_PollPeriod
        BL      Parent_Misc     ;(R0->R5,R6)
 [ DebugU
        DREG    r5, "PollPeriod = "
 ]
        CMPS    r5, #1
        BCC     %FT90           ;C=0 <=> r5=0, not worth doing upcall eg RAMFS

        ; Copy disc name to name buffer
        ADR     r2, UpCall_NameBuffer
        ADD     lr, r1, #NameLen
20
        CMPS    r1, lr
        LDRNEB  r0, [r1], #1
        CMPNES  r0, #DeleteChar
        CMPNES  r0, #DelimChar
        CMPNES  r0, #" "
        STRHIB  r0, [r2], #1
        BHI     %BT20

        MOV     r0, #0
        STRB    r0, [r2]

        ; Historically, FileCore ignored the media type string. ADFS and SCSIFS
        ; provided it (at least as far back as CVS goes) but didn't
        ; internationalise it. RAMFS doesn't provide it (but it specifies a
        ; zero timeout so we don't get this far). Let's be paranoid and check
        ; that it looks like a valid string, and if it's the string "disc" then
        ; assume it's not internationalised and look it up in FileCore's messages.
        RSBS    lr, r6, #&8000 ; low number means probably invalid
        MOVCC   r0, r6
        ADDCC   r1, r6, #99
        SWICC   XOS_ValidateAddress
        BCS     %FT30
        baddr   r2, disc
27      LDRB    r3, [r0], #1
        LDRB    lr, [r2], #1
        TEQ     r3, lr
        BNE     %FT28 ; string isn't "disc"
        TEQ     lr, #0
        BNE     %BT27
        B       %FT30 ; string is "disc", so internationalise it
28      MOV     r0, r6
29      LDRB    lr, [r0], #1
        TEQ     lr, #0
        BEQ     %FT40 ; found a null terminator, assume string at r6 is OK
        TEQ     lr, #&7F
        CMPNE   lr, #&1F
        BLS     %FT30 ; found other non-printing character, assume duff
        CMP     r0, r1
        BLS     %BT29
        ; No terminator found in first 100 bytes, assume duff so drop through
        
30      ; Generate media type string
        baddr   r0, disc
        ADR     r2, UpCall_MediaTypeBuffer
        MOV     r3, #?UpCall_MediaTypeBuffer
        BL      message_lookup_to_buffer
        BVS     %FT90
        ADR     r6, UpCall_MediaTypeBuffer
40

; OSS Tell driver to eject the preferred drive, if it supports ejects.
; Supported registers for the MiscOp are:
; r0 = Misc_Eject
; r1 = &80000000 (top bit set means preferred drive)
; r4 = iteration count (to allow driver to ignore some eg. only expel
;      on first call, only expel every 10 if fast polling etc.)
; r5 = minimum timeout period in centisceonds (to allow drive to work out
;      if expelling is sensible)

        LDR     lr, FS_Flags
        TST     lr, #CreateFlag_FloppyEjects :OR: CreateFlag_FixedDiscEjects
        BEQ     %FT50

        MOV     r0, #MiscOp_Eject
        MOV     r1, #((1 :SHL: 31) :EOR: 4)
        BL      Parent_Misc
50
        LDRB    r0, [sp, #UpCall_FrameSize + 0*4]
        LDRB    r1, FS_Id
        MOV     r2, sp
        MOV     r3, #-1         ;invalid device no
 [ DebugU
        DREG    r0,"OnlyXOS_UpCall(",cc
        DREG    r1,",",cc
        DSTRING r2,",",cc
        DREG    r3,",",cc
        DREG    r4,",",cc
        DREG    r5,",",cc
        DSTRING r6,",",cc
        DLINE   ")"
 ]
        BL      OnlyXOS_UpCall
 [ DebugU
        DLINE   "UpCall returned"
 ]
        ADD     r4, r4, #1
        RSBS    lr, r0, #0      ;C=1 <=> r0=0, upcall claimed

90
        ADD     sp, sp, #UpCall_FrameSize
        Pull    "r0,r1,r5,r6,pc"


; ========
; IncUsage
; ========

; R3 top 3 bits disc

IncUsage
        Push    "R0,LR"
        BL      DiscAddToRec    ;(R3->LR)
        LDRB    R0,[LR,#DiscUsage]
        ADD     R0,R0,#1
        STRB    R0,[LR,#DiscUsage]
        Pull    "R0,PC"


; ========
; DecUsage
; ========

; R3 top 3 bits disc

DecUsage
        Push    "R0,R1,LR"
        SavePSR R1
        BL      DiscAddToRec    ;(R3->LR)
        LDRB    R0,[LR,#DiscUsage]
        SUBS    R0,R0,#1
        STRPLB  R0,[LR,#DiscUsage]
        RestPSR R1,,f
        Pull    "R0,R1,PC"


; ============
; ReadTimeDate
; ============

; exit R7,R8 are load & exec addresses for data type with date&time stamp

ReadTimeDate
        Push    "R0,R1,LR"
        MOV     R0,#OsWord_ReadRealTimeClock
        SUB     SP,SP,#8        ;space for param block
        MOV     R1,SP
        MOV     LR,#3
        STRB    LR,[R1]
        BL      OnlyXOS_Word
        LDRVC   R8,[R1]
        LDRVCB  R7,[R1,#4]
        MOVVS   R8,#-1
        MOVVS   R7,#&FF
        LDR     LR,=Data_LoadAddr
        ORR     R7,R7,LR
        ADDS    SP,SP,#8        ; clear V
 [ Debug9
        DREG    R7
        DREG    R8
        mess    ,"date stamp",NL
 ]
        Pull    "R0,R1,PC"


; ============
; FindErrBlock
; ============

; entry: R0=internal error code
; exit:  R0->error block, V=1 OTHER FLAGS PRESERVED

FindErrBlock ROUT
        Push    "R1-R3,LR"
        SavePSR R3
 [ NewErrors
        ASSERT  BigDisc
        CMP     R0, #256
        BHS     %FT45
 |
        TSTS    R0, #ExternalErrorBit
        BICNE   R0, R0, #ExternalErrorBit
 [ BigDisc
        BNE     %FT45
 |
        BNE     %FT50
 ]
        TSTS    R0, #DiscErrorBit
        BNE     %FT40
 ]
 [ Debug3
        DLINE   "FindErrBlock: In error table bit"
 ]
        AND     LR, R0, #&FF
        TEQS    LR, #IntEscapeErr
        BNE     %FT05
        MOV     R0, #OsByte_AcknowledgeEscape ;If error was escape then acknowledge
        BL      DoXOS_Byte              ;(R0-R2->R0-R2,V)
        MOV     LR, #ExtEscapeErr       ;ignore any secondary error
05
        baddr   R0, ErrorTable
10
        LDRB    R1, [R0]
        TEQS    R1, LR
        BEQ     %FT30   ;match found
20
        LDR     R1, [R0,#4] !   ;mismatch so skip rest of entry
        BIC     R2, R1, #&FF
        ASSERT  (FileCoreModuleNum :AND: &FF)<32
        TEQS    R2, #FileCoreModuleNum :SHL: 8
        BNE     %BT20
        TEQS    R1, #FileCoreModuleNum :SHL: 8
        BNE     %BT10           ;loop if more entries

30
        ; Copy the error and fix up the FS number in the error number
        BIC     r1, r1, #&ff00
        ORR     r1, r1, #(FileCoreModuleNum :SHL: 8) :AND: &ffff0000
        LDRB    lr, FS_Id
        ORR     r1, r1, lr, ASL #8
        BL      copy_error
        B       %FT50

 [ :LNOT: NewErrors
40                              ;Form disc err string
        Push    "r0,r4-r6"
 [ Debug3
        DLINE   "FindErrBlock: 40"
 ]
        SUB     sp, sp, #20

        CLRV    ; to ensure we catch out errors

        ; Drive number
        MOV     r0, r0, LSR #(24-3)     ; drive number (external)
        AND     r0, r0, #7
        MOV     r1, sp
        MOV     r2, #4
        BL      OnlyXOS_ConvertCardinal4

        ; Disc error number
        LDRVC   r0, [sp, #20]
        MOVVC   r0, r0, LSR #24
        ANDVC   r0, r0, #MaxDiscErr
        ADDVC   r1, sp, #4
        MOVVC   r2, #4
        BLVC    OnlyXOS_ConvertHex2

        ; Address
        LDRVC   r0, [sp, #20]
        MOVVC   r0, r0, ASL #8
        BICVC   r0, r0, #DiscBits
        ADDVC   r1, sp, #8
        MOVVC   r2, #12
        BLVC    OnlyXOS_ConvertHex8

        ; Stitch it all together
        baddr   r0, DiscErrBlk, VC
        LDRVC   r1, [r0]
        BICVC   r1, r1, #&ff00
        LDRVCB  lr, FS_Id
        ORRVC   r1, r1, lr, ASL #8
        BICVC   r1, r1, #&ff000000
        LDRVC   lr, [sp, #20]
        ANDVC   lr, lr, #MaxDiscErr :SHL: 24
        ORRVC   r1, r1, lr
        ADDVC   r4, sp, #4
        MOVVC   r5, sp
        ADDVC   r6, sp, #8
        BLVC    copy_error3             ; VS always out of this

        ; apparent unbalanced stack pull is correct
        ADD     sp, sp, #24
        Pull    "r4-r6"
 ] ; :LNOT:NewErrors

 [ BigDisc
        B       %FT50
45
 [ Debug3
        DLINE   "FindErrBlock: 45"
 ]
 [ NewErrors
        TSTS    R0,#NewDiscErrorBit
 |
        TSTS    R0,#DiscErrorBit
 ]
        BEQ     %FT50
 [ NewErrors
        BIC     R0,R0,#NewDiscErrorBit
 |
        BIC     R0,R0,#DiscErrorBit
 ]
; here if using an extended process error block
        Push    "r0,r4-r6"
        SUB     sp, sp, #40

        CLRV    ; to ensure we catch out errors

        ; Drive number
 [ NewErrors
        LDRB    r0, [r0,#0]
 |
        LDR     r0, [r0,#4]
        MOV     r0, r0, LSR #(32-3)     ; drive number (external)
 ]
        MOV     r1, sp
        MOV     r2, #4
        BL      OnlyXOS_ConvertCardinal4

        ; Disc error number
        LDRVC   r0, [sp, #40]
 [ NewErrors
        LDRVCB  r0, [r0, #1]
 |
        LDRVC   r0, [r0]
 ]
        ANDVC   r0, r0, #MaxDiscErr
        ADDVC   r1, sp, #4
        MOVVC   r2, #4
        BLVC    OnlyXOS_ConvertHex2
        BVS     %FT47

        ; Address
        LDR     r0, [sp, #40]
 [ NewErrors
        LDR     r5, [r0, #4]
        LDR     r0, [r0, #8]
 |
        LDR     r1, [r0, #4]
        MOV     r0, r1, LSR #(32-3)     ; drive bits

        EOR     r0,r0,#4                ; external to internal
        DrvRecPtr lr,r0
        LDRB    lr, [lr,#DrvsDisc]
        AND     lr, lr, #7
        DiscRecPtr lr, lr


        LDRB    r4, [lr, #DiscRecord_Log2SectorSize]
        RSB     r6, r4, #32
        BIC     r5, r1, #DiscBits
        MOV     r0, r5, LSR r6
 ]
        MOV     r6, r0                  ; remember upper word
        ADD     r1, sp, #8
        MOV     r2, #12
        BL      OnlyXOS_ConvertHex8
        BVS     %FT47

 [ NewErrors
        MOV     r0, r5
 |
        MOV     r0, r5, LSL r4
 ]
        ADD     r1, sp, #16
        MOV     r2, #12
        BL      OnlyXOS_ConvertHex8
        BVS     %FT47

        ; Stitch it all together
        baddr   r0, DiscErrBlk, VC
        LDR     r1, [r0]
        BIC     r1, r1, #&ff00
        LDRB    lr, FS_Id
        ORR     r1, r1, lr, ASL #8
        BIC     r1, r1, #&ff000000
        LDR     lr, [sp, #40]
 [ NewErrors
        LDRB    lr, [lr, #1]
 |
        LDRB    lr, [lr, #0]
 ]
        ORR     r1, r1, lr, LSL #24
        ADD     r4, sp, #4
        MOV     r5, sp
        TEQ     r6, #0                  ; print 8 or 16 digits
        ADDNE   r6, sp, #8
        ADDEQ   r6, sp, #16
        BL      copy_error3             ; VS always out of this

        ; apparent unbalanced stack pull is correct
47      ADD     sp, sp, #44
        Pull    "r4-r6"
 ]

50
        ORR     R3, R3, #V_bit
        RestPSR R3,,f
        Pull    "R1-R3,PC"

; =====
; WrHex
; =====

; write R0 as 8 digit hex number

; exit IF error V set, R0 result

WrHex   ROUT
        Push    "R7,LR"
        SUB     SP, SP, #12
        MOV     R7, SP
        BL      PutHexWord
        MOV     LR, #0
        STRB    LR, [R7],#1
        MOV     R7, SP
        BL      WriteString     ;(R7->R0,V)
        ADD     SP, SP, #12
        Pull    "R7,PC"


; =====
; WrDec
; =====

; write a space followed by a zero supressed decimal number

; entry R0 number

; exit if error V set, R0 result

 [ {FALSE}
WrDec   ROUT
        Push    "R0,R1,LR"
        MOV     R1,#10
        BL      Divide  ;(R0,R1->R0,R1)
        TEQS    R0,#0
        BEQ     %FT10
        BL      WrDec   ;(R0->R0,V)
        B       %FT20
10
        BL      DoSpace ;(->R0,V)
20
        ADDVC   R0,R1,#"0"
        BLVC    DoXOS_WriteC    ;(R0->R0,V)
95
        STRVS   R0,[SP]
        Pull    "R0,R1,PC"

 |


WrDecWidth10 ROUT
        Push    "R0-R4,LR"
        MOV     R2,#" "
        B        WrDecCommon

WrDec   ROUT
        Push    "R0-R4,LR"
        BL      DoSpace
        BVS     %FT99
        LDR     R0,[SP]
        MOV     R2,#0
WrDecCommon
        MOV     R4,SP
        MOV     R3,#10
10
        MOV     R1,#10
        BL      Divide
        Push    "R1"
        SUBS    R3,R3,#1
        BNE     %BT10
20
        Pull    "R0"
        TEQS    SP,R4
        MOVEQ   R2,#"0"
        TEQS    R0,#0
        MOVNE   R2,#"0"
        ADDNE   R0,R0,R2
        MOVEQS  R0,R2
        BLNE    DoXOS_WriteC    ;(R0->R0,V)
        BVS     %FT95
        TEQS    SP,R4
        BNE     %BT20
95
        MOV     SP,R4
99
        STRVS   R0,[SP]
        Pull    "R0-R4,PC"

 ]


; ----- ENTRY CHECKING ROUTINES -----

; Almost all entry points must check whether FileCore is willing to be entered and
; if not whether to
;  0) just return
;  1) flag error       - return V set, R0->Error Block

; this is done by putting at each entry point
;       Push    "R0,R1,SB,LR"
;       BL      [Dormant]Entry(NoErr/FlagErr)

; Dormant indicates that the entry point will only accept entries if FileCore
; is dormant ie no reentrancy

; these routines also point SB at the static base

; there should be a BL FileCoreExit at the end of the routine and any calls to
; external MOS routines should be prefixed by 'BL [Do/Only]External' and
; followed by 'BL Internal'

; OK, but what does this give us:
; i) entrance prohibited from IRQ mode
; ii) entrance prohibited whilst 'inside' FileCore, except in a controlled
;      fashion.
; iii) 0 or 1 level of re-entrance. That is, depending on which form or Entry
;      FileCore will permit itself to reentered not at all or one time only.
; iv) under no circumstances will FileCore permit itself to be entered more
;      than twice (one original call and one reentrance).
;
; Translating the above into algorithms:
; NoErr means return to the caller (of FileCore) without setting an error.
; FlagErr means return to the caller with a 'FileCore in use' error.
; Dormant means only permit entry at this point if FileCore is threaded 0 times.
; no Dormant means permit entry to FileCore if FileCore is threaded 0 or 1 times.
;
; Why the need to 'BL [Do/Only]External'? These inform the Entry checking system that
; FileCore is going outside under its own control. This is necessary to avoid FileCore
; in use again. OnlyExternal prohibits any further FileCore reentrance until Internal
; has been called. DoExternal does not explicitly perform the same prohibition (but
; FileCore may not be reentereable as it's exceeded its threading count).
;
; LightEntryFlagErr is used when re-entrancy isn't a problem if there's a:
;       Locked disc
;       Interlock set
;
; Internals of the reentrance system:
; It holds a count. The count must be even to allow reentrance. An odd count indicates
; that FileCore has been reentered out of control. If the count is 2 or more
; DormantEntry is prohibited (FileCore isn't dormant). If the count is 4 or more all
; forms of entry are prohibited. bit6 is set in the count to prohibit reentry via
; calls FileCore makes to the rest of the system (set by BL OnlyExternal).


; *******************  NOTE  *******************

; All the above is a complete load of rubbish because I got so hacked off
; with re-entrancy problems I enabled *vast* numbers of reentrancy levels,
; whatever the type of call.  (JRoach)





EntryNoErr ROUT
        MOV     R0, #2_01000001
        B       %FT10

EntryFlagErr
        MOV     R0, #2_11000001
        B       %FT10

DormantEntryNoErr
        MOV     R0, #2_01000001
        B       %FT10

DormantEntryFlagErr
        MOV     R0, #2_11000001
        B       %FT10

LightEntryFlagErr
        MOV     R0, #2_11000001
        getSB
        TEQ     R0, R0          ; To set EQ
        B       %FT20

10
        getSB

        ; IF haven't got a locked drive
        LDRB    R1, LockedDrive
        TEQS    R1, #&FF                ;no reentrance while a drive locked
 [ DebugR
        DREG    R1, "L="
 ]

        ; AND not interesting interlocks set (those other than noopenwinnie or noopenfloppy)
        LDREQB  R1, Interlocks
        TSTEQS  R1, #&FF :EOR: NoOpenFloppy :EOR: NoOpenWinnie
 [ DebugR
        DREG    R1, "I="
 ]

20
        ; AND aren't entered from IRQ mode
        LDREQ   R1, ptr_IRQsema
        LDREQ   R1, [R1]
 [ DebugR
        DREG    R1, "S="
 ]
        TEQS    R1, #0                  ;colludes with locked drive check to give NE if got a locked drive

        ; AND none of the reentrance bits we're interested in are set
        LDREQB  R1, ReEntrance
        ASSERT  NoReEnterBit = 1 :SHL: 6
 [ DebugR
        DREG    R1, "R="
 ]
        TSTEQS  R1, R0

        ; THEN increment ReEntrance and return, everything being hunky-dory
        ADDEQ   R1, R1, #1
        STREQB  R1, ReEntrance
        STREQB  R1, LastReEnter
        Pull    "R0,R1",EQ
        MOVEQ   PC,LR

        ;ELSE we're re-entering too much...

        ;Construct error if been requested to and return to caller
        CMPS    R0, R0, LSR #8    ;V=0
;C=0 => just return
;C=1 => flag error, V set R0->error block
        MOVCS   R0, #InUseErr
        BLCS    FindErrBlock            ;(R0->R0,V)
        STRVS   R0, [SP]
        Pull    "R0-R1,SB,PC"


; ============
; FileCoreExit
; ============

; for use in conjuction with the entry routines above

FileCoreExit ROUT
        Push    "R0,LR"
        SavePSR R0
        LDRB    LR, ReEntrance
        SUBS    LR, LR, #1
        STRPLB  LR, ReEntrance
 [ Dev
        BNE     %FT01
        LDR     LR, ptr_CannotReset
        LDRB    LR, [LR]
        TEQS    LR, #0
        DREG    LR, NE
        mess    NE, "CannotReset",NL
        MOVNE   PC, #0
01
 ]
        RestPSR R0,,f
        Pull    "R0,PC"


; ==========
; DoExternal
; ==========

;prefixes external call

DoExternal ROUT
        Push    "LR"
        TEQ     SB, #0
        LDRNEB  LR, ReEntrance
        ADDNE   LR, LR, #1
        STRNEB  LR, ReEntrance
        Pull    "PC"

; ============
; OnlyExternal
; ============

;as DoExternal but forbids re-entrance

OnlyExternal ROUT
        Push    "LR"
        TEQ     SB, #0
        LDRNEB  LR, ReEntrance
        ADDNE   LR, LR, #1
        ORRNE   LR, LR, #NoReEnterBit
        STRNEB  LR, ReEntrance
        Pull    "PC"

; ========
; Internal
; ========

; should follow any MOS call preceeded by 'BL [Do/Only]External'
; assumes V set flags error

Internal ROUT
        Push    "R1,LR"
        SavePSR R1
 [ :LNOT:NewErrors
        ORRVS   R0, R0, #ExternalErrorBit
 ]
        CMP     SB, #0
        BEQ     %FT95
        LDRB    LR, ReEntrance
        BIC     LR, LR, #NoReEnterBit
        SUBS    LR, LR ,#1
        STRPLB  LR, ReEntrance
95
        RestPSR R1,,f
        Pull    "R1,PC"


; ==================
; InternalFromParent
; ==================

InternalFromParent
        Push    "R1,LR"
        SavePSR R1
        LDRB    LR, ReEntrance
        BIC     LR, LR, #NoReEnterBit
        SUBS    LR, LR ,#1
        STRPLB  LR, ReEntrance
        RestPSR R1,,f
 [ NewErrors
        Pull    "R1,PC",VC
; Error occurred - let's convert (if necessary) from old scheme to new.
        LDR     LR, FS_Flags
        TSTS    LR, #CreateFlag_NewErrorSupport
        BNE     %FT95                           ; Child returns new style errors
        TSTS    R0, #DiscErrorBit
        BNE     %FT50
        TSTS    R0, #ExternalErrorBit
        BICNE   R0, R0, #ExternalErrorBit
        ANDEQ   R0, R0, #&FF
        B       %FT95
50
        Push    "R2-R4"
        TSTS    R0, #ExternalErrorBit
        BNE     %FT60                           ; get R2 = disc error<<8 + drive number
        AND     R2, R0, #MaxDiscErr:SHL:24      ;     R4 = byte address (low)
        MOV     R3, R0, LSR #21                 ;     LR = byte address (high)
        AND     R3, R3, #7
        ORR     R2, R3, R2, LSR #16
        MOV     R4, R0, LSL #8
        BIC     R4, R4, #DiscBits
        MOV     LR, #0
        B       %FT70
        ; indirect (sector) error version
60      BIC     R0, R0, #ExternalErrorBit+DiscErrorBit
        LDRB    R2, [R0, #0]
        LDR     R4, [R0, #4]
        MOV     R3, R4, LSR #(32-3)
        ORR     R2, R3, R2, LSL #8
        BIC     R4, R4, #DiscBits
        EOR     LR, R3, #4
        DrvRecPtr LR, LR
        LDRB    LR, [LR, #DrvsDisc]
        AND     LR, LR, #7
        DiscRecPtr LR, LR
        LDRB    R3, [LR, #DiscRecord_Log2SectorSize]
        RSB     R0, R3, #32
        MOV     LR, R4, LSR R0
        MOV     R4, R4, LSL R3
70
        ADR     R0, ConvDiscErr
        STMIA   R0, {R2, R4, LR}                ; Fabricated new style error
        ORR     R0, R0, #NewDiscErrorBit
        Pull    "R2-R4"
95
        RestPSR R1,,f
 ]
        Pull    "R1,PC"


; ===========
; Parent_Misc
; ===========
;
; Call MiscEntry of child filing system
;
; In
;  r0=op
;  r1=drive number (internal)
;  Other parameters to MiscEntry
; Out
;  r1 unchanged

Parent_Misc ROUT
        Push    "R11,LR"
 [ Debug1
        DREG    R0, "", cc
        DREG    R1, " ", cc
        DREG    R2, " ", cc
        DREG    R3, " ", cc
        DREG    R4, " ", cc
        DREG    R5, " ", cc
        DLINE   ">Parent_Misc"
 ]
        EOR     R1, R1, #4      ;convert to external drive numbering
        MOV     R11, SB
        BL      OnlyExternal
        LDR     SB, ParentPrivate
        MOV     LR, PC
        LDR     PC, [R11,#:INDEX:FS_Misc]
        MOV     SB, R11
        BL      InternalFromParent
        EOR     R1, R1, #4      ;convert to internal drive numbering
 [ Debug1
        DREG    R0, "", cc
        DREG    R1, " ", cc
        DREG    R2, " ", cc
        DREG    R3, " ", cc
        DREG    R4, " ", cc
        DREG    R5, " ", cc
        DLINE   "<Parent_Misc"
 ]
        Pull    "R11,PC"


; ============
; DoXOS_WriteS
; ============

; as WriteS but with re-entrance checking

DoXOS_WriteS   ROUT
        Push    "R0-R2,LR"
        RSB     R0, PC, PC              ; remove any PSR flags from LR
        SUB     R0, LR, R0
        MOV     R1, R0
05
        LDRB    R2, [R1],#1
        TEQS    R2, #0
        BNE     %BT05
        TSTS    R1, #3
        BICNE   R1, R1, #3
        ADDNE   R1, R1, #4
        STR     R1, [SP,#12]
        BL      DoExternal
        BL      DoXOS_Write0
        BL      Internal
        STRVS   R0, [SP]
        Pull    "R0-R2,PC"


DoSpace ROUT
        MOV     R0, #" "        ;(->R0,V)

DoXOS_WriteC            ;(R0->R0,V)
        Push    "LR"
        BL      DoExternal
        SWI     XOS_WriteC
InternalCommon
        BL      Internal
        Pull    "PC"


DoXOS_Write0 ROUT       ;(R0->R0,V)
        Push    "LR"
        BL      DoExternal
        SWI     XOS_Write0
        B       InternalCommon

DoXOS_WriteN ROUT
        Push    "LR"
        BL      DoExternal
        SWI     XOS_WriteN
        B       InternalCommon

DoXOS_NewLine ROUT      ;(->R0,V)
        Push    "LR"
        BL      DoExternal
        SWI     XOS_NewLine
        B       InternalCommon


DoXOS_CLI ROUT          ;(->R0,V)
        Push    "LR"
        BL      DoExternal
        SWI     XOS_CLI
        B       InternalCommon


DoXOS_ReadC ROUT
        Push    "LR"
        BL      DoExternal
        SWI     XOS_ReadC
        B       InternalCommon


OnlyXOS_Byte ROUT
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_Byte
        B       InternalCommon

DoXOS_Byte ROUT
        Push    "LR"
        BL      DoExternal
        SWI     XOS_Byte
        B       InternalCommon

DoXOS_ServiceCall ROUT
        Push    "LR"
        BL      DoExternal
        SWI     XOS_ServiceCall
        B       InternalCommon

DoXOS_Args ROUT
        Push    "LR"
        TEQ     SB, #0
        BLNE    DoExternal
        SWI     XOS_Args
InternalSBChkCommon
        TEQ     SB, #0
        BLNE    Internal
        Pull    "PC"

DoXOS_GBPB ROUT
        Push    "LR"
        TEQ     SB, #0
        BLNE    DoExternal
        SWI     XOS_GBPB
        B       InternalSBChkCommon

DoXMessageTrans_ErrorLookup ROUT
        Push    "LR"
        BL      DoExternal
        SWI     XMessageTrans_ErrorLookup
        B       InternalCommon

DoXMessageTrans_GSLookup ROUT
        Push    "LR"
        BL      DoExternal
        SWI     XMessageTrans_GSLookup
        B       InternalCommon

DoXMessageTrans_OpenFile ROUT
        Push    "LR"
        BL      DoExternal
        SWI     XMessageTrans_OpenFile
        B       InternalCommon

OnlyXOS_Claim ROUT      ;(R0,R1->R0,V)
        Push    "R2,LR"
        MOV     R2,SB
        BL      OnlyExternal
        SWI     XOS_Claim
InternalCommonR2
        BL      Internal
        Pull    "R2,PC"


OnlyXOS_Release ROUT    ;(R0,R1->R0,V)
        Push    "R2,LR"
        MOV     R2,SB
        BL      OnlyExternal
        SWI     XOS_Release
        B       InternalCommonR2

DoXOS_FSControl ROUT
        Push    "LR"
        BL      DoExternal
        SWI     XOS_FSControl
        B       InternalCommon

OnlyXOS_FSControl ROUT
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_FSControl
        B       InternalCommon


DoXOS_OsFind             ;(R0,R1->R0,V)
        Push    "LR"
        BL      DoExternal
        SWI     XOS_Find
        B       InternalCommon


OnlySysXOS_Heap                 ;(R0,R2,R3->R0-R3,V)
        Push    "R1,LR"
        BL      OnlyExternal
        LDR     R1,SysHeapStart
        SWI     XOS_Heap
        BL      Internal
        Pull    "R1,PC"


OnlyXOS_Module
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_Module
        B       InternalCommon


OnlyXOS_ClaimScreenMemory       ;(R0-R2->R1,R2,C)
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_ClaimScreenMemory   ;assume no errors
        B       InternalCommon


OnlyXOS_Word
        Push    "R10,LR"
        SavePSR R10
        BL      OnlyExternal
        SWI     XOS_Word
InternalCommonHat
        BL      Internal
        RestPSR R10,,f
        Pull    "R10,PC"


OnlyXOS_GetEnv
        Push    "R10,LR"
        SavePSR R10
        BL      OnlyExternal
        SWI     XOS_GetEnv
        MOVVS   R2,#AppSpaceStart
        B       InternalCommonHat


OnlyXOS_ConvertDateAndTime      ;(R0-R3->R0-R2)
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_ConvertDateAndTime
        B       InternalCommon


OnlyXOS_ConvertStandardDateAndTime      ;(R0-R2->R0-R2)
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_ConvertStandardDateAndTime
        B       InternalCommon


OnlyXOS_UpCall
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_UpCall
        B       InternalCommon


OnlyXOS_ReadVduVariables
        Push    "R10,LR"
        SavePSR R10
        BL      OnlyExternal
        SWI     XOS_ReadVduVariables
        B       InternalCommonHat


DoXOS_Confirm
        Push    "LR"
        BL      DoExternal
        SWI     XOS_Confirm
        B       InternalCommon


OnlyXOS_ConvertFixedFileSize
        Push    "R10,LR"
        SavePSR R10
        BL      OnlyExternal
        SWI     XOS_ConvertFixedFileSize
        B       InternalCommonHat


OnlyXOS_ReadUnsigned
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_ReadUnsigned
        B       InternalCommon


OnlyXOS_ConvertHex8
        Push    "R10,LR"
        SavePSR R10
        BL      OnlyExternal
        SWI     XOS_ConvertHex8
        B       InternalCommonHat

OnlyXOS_ConvertHex2
        Push    "R10,LR"
        SavePSR R10
        BL      OnlyExternal
        SWI     XOS_ConvertHex2
        B       InternalCommonHat

OnlyXOS_ConvertCardinal4
        Push    "R10,LR"
        SavePSR R10
        BL      OnlyExternal
        SWI     XOS_ConvertCardinal4
        B       InternalCommonHat

OnlyXWimp_ClaimFreeMemory
        Push    "LR"
        BL      OnlyExternal
        SWI     XWimp_ClaimFreeMemory
        B       InternalCommon

 [ BigDir
OnlyXOS_DynamicArea
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_DynamicArea
        B       InternalCommon

OnlyXOS_ChangeDynamicArea
        Push    "LR"
        BL      OnlyExternal
        SWI     XOS_ChangeDynamicArea
        B       InternalCommon
 ]

        LTORG
        END
