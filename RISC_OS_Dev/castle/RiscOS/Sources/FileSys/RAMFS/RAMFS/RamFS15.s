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
; >RamFS15

        TTL     "FileCore low level operations"

; LowLevelEntry
; -------------
; Called by FileCore to do primitives
; Entry: R1 = subreason
;        R2 = disc address, top 3 bits drive
;        R3 = RAM ptr
;        R4 = length
;        R5 = pointer to disc record
;        R6 = pointer to defect list
; Exit : R12= private word
;        Others subreason dependant
LowLevelEntry ROUT
        LDR     SB, [SB]
        Push    "R0, R1, R5, R6, LR"
      [ Debug3
        DREG    R1,",",cc
        DREG    R2,",",cc
        DREG    R3,",",cc
        DREG    R4,",",cc
        DREG    R5,",",cc
        DREG    R6," ",cc
        DLINE   "*>LowLevel"
      ]

      [ PMP
        MOV     R5, #0
        LDR     LR, BufferSize
      |
        ASSERT  :INDEX: BufferStart = 0
        ASSERT  :INDEX: BufferSize = 4
        LDMIA   SB, {R5, LR}
      ]

        ASSERT  MyMaxSupportedDrive = 0         ; No need to BIC out the drive bits in R2
      [ BigDisc2
        MOV     R2, R2, LSL #MyLog2SectorSize
      ]
        ADDS    R6, R2, R4                      ; end disc add
        SUBNE   R6, R6, #1
        CMPCCS  R6, LR

        ANDCC   LR, R1, #DiscOp_Op_Mask         ; Only Disc Op bits
        CMPCCS  LR, #MyMaxSupportedDiscOp
        MOVCS   R0, #BadParmsErr
        BCS     %FT90

        TEQS    R4, #0
        BEQ     %FT90

        TSTS    R1, #DiscOp_Op_ScatterList_Flag
        ADDEQ   R0, SB, #:INDEX: ScatterPair
        STMEQIA R0, {R3, R4}
        MOVEQ   R3, R0

        ASSERT  DiscOp_ReadSecs > DiscOp_Verify
        ASSERT  DiscOp_WriteSecs > DiscOp_ReadSecs
        CMPS    LR, #DiscOp_ReadSecs
        BEQ     Read
        BLO     Verify
        ; Fall through
Write
        ADD     R1, R5, R2
10
        LDMIA   R3, {R0, R6}
        CMPS    R6, R4
        MOVLS   R2, R6
        MOVHI   R2, R4
        BL      BlockWrite                      ; (R0-R2)
        BVS     %FT95
        ADD     R0, R0, R2
        ADD     R1, R1, R2
        SUBS    R6, R6, R2
        STMIA   R3, {R0, R6}
        ADDEQ   R3, R3, #4*2
        SUBS    R4, R4, R2
        BNE     %BT10
        SUB     R2, R1, R5
        B       %FT40

Verify
        MOV     R5, R2
20
        LDMIA   R3, {R1, R6}
        CMPS    R6, R4
        MOVLS   R2, R6
        MOVHI   R2, R4
        ADD     R5, R5, R2
        ADD     R1, R1, R2
        SUBS    R6, R6, R2
        STMIA   R3, {R1, R6}
        ADDEQ   R3, R3, #4*2
        SUBS    R4, R4, R2
        BNE     %BT20
        MOV     R2, R5

Read
        ADD     R0, R5, R2
30
        LDMIA   R3, {R1, R6}
        CMPS    R6, R4
        MOVLS   R2, R6
        MOVHI   R2, R4
        BL      BlockRead                       ; (R0-R2)
        BVS     %FT95
        ADD     R0, R0, R2
        ADD     R1, R1, R2
        SUBS    R6, R6, R2
        STMIA   R3, {R1, R6}
        ADDEQ   R3, R3, #4*2
        SUBS    R4, R4, R2
        BNE     %BT30
        SUB     R2, R0, R5
40
        LDR     R1, [SP, #4]
        TSTS    R1, #DiscOp_Op_ScatterList_Flag
        LDREQ   R3, ScatterPair
        MOV     R4, #0
90
        CLRV
95
      [ BigDisc2
        MOV     R2, R2, LSR #MyLog2SectorSize
      ]
        STRVS   R0, [SP]
      [ Debug3
        BVC     %FT01
        DREG    R0," ",cc
01
        BVS     %FT01
        DLINE   "         ",cc
01
        DREG    R1," ",cc
        DREG    R2," ",cc
        DREG    R3," ",cc
        DREG    R4," ",cc
        DLINE   "*<LowLevel"
      ]
        Pull    "R0, R1, R5, R6, PC"

        MACRO
        Misc    $str
        ASSERT  MiscOp_$str=(.-MiscTable) :SHR: 2
        B       Do$str
        MEND

; MiscEntry
; ---------
; Called by FileCore to do misc operations
; Entry: R0 = subreason
;        R1 = drive
;        Others dependant on call
; Exit : R12= private word
;        Others subreason dependant
MiscEntry ROUT
      [ Debug4
        DREG    R0,", ",cc
        DREG    R1,", ",cc
        DREG    R2,", ",cc
        DREG    R3,", ",cc
        DREG    R4,", ",cc
        DREG    R5," ",cc
        DLINE   "*>Misc"
      ]
        Push    "LR"
        LDR     SB, [SB]
        CMPS    R0, #MiscOp_FirstUnknown
        BLO     %FT10
        MOV     R0, #BadParmsErr
        SETV    
        B       %FT90
10
        MOV     LR, PC
        ADD     PC, PC, R0, LSL #2
        B       %FT90
MiscTable
        Misc    Mount
        Misc    PollChanged
        Misc    LockDrive
        Misc    UnlockDrive
        Misc    PollPeriod

90
      [ Debug4
        DREG    R0, ", ",cc
        DREG    R1, ", ",cc
        DREG    R2, ", ",cc
        DREG    R3, ", ",cc
        DREG    R4, ", ",cc
        DREG    R5, " ",cc
        DLINE   "<*Misc"
      ]
        Pull    "PC"

; DoMount
; -------
; Misc op 0
; Entry: R1 = drive
;        R2 = disc address (in bytes)
;        R3 = pointer to buffer
;        R4 = length to read into buffer
;        R5 = pointer to disc record to populate (for floppies)
;        R12= private word
DoMount ROUT
        Push    "R0-R2, LR"

        SWI     XOS_ReadRAMFsLimits             ; (->R0,R1)
        SUB     R1, R1, R0                      ; RAM disc size
        STR     R0, BufferStart
        STR     R1, BufferSize

      [ BigDisc2
        MOV     R2, R2, LSL #MyLog2SectorSize
      ]

        MOV     R1, R3
        ASSERT  MyMaxSupportedDrive = 0         ; No need to BIC out the drive bits in R2
      [ PMP
        MOV     R0, R2
      |
        ADD     R0, R0, R2
      ]
        MOV     R2, R4
        BL      BlockRead                       ; (R0,R1,R2)
        BVS     %FT90

      [ BigDisc
        ; when we have big discs, we have a problem - the disc size
        ; field hasn't been filled in.  we copy SkeletonDiscRec instead
        ADR     R0, SkeletonDiscRec
        MOV     R1, R5
        MOV     R2, #SzDiscRecSig2
        BL      BlockMove                       ; (R0,R1,R2)
        BVS     %FT90
        LDR     r0, BufferSize
        STR     r0, [r5, #DiscRecord_DiscSize]
      [ BigDisc2
        ; Ensure the big disc flag is set correctly
        CMP     r0, #512<<20
        LDRB    r0, [r5, #DiscRecord_BigMap_Flags]
        BICLS   r0, r0, #DiscRecord_BigMap_BigFlag
        ORRHI   r0, r0, #DiscRecord_BigMap_BigFlag
        STRB    r0, [r5, #DiscRecord_BigMap_Flags]
      ]   
      |
        ; copy from the record in the map
      [ PMP
        MOV     R0, #ZoneHead
      |
        LDR     R0, BufferStart
        ADD     R0, R0, #ZoneHead
      ]
        MOV     R1, R5
        MOV     R2, #DiscRecSig
        BL      BlockRead
        BVS     %FT90
      ]

        CLRV
90
        STRVS   R0, [SP]
        Pull    "R0-R2, PC"

; DoPollChanged
; -------
; Misc op 1
; Entry: R1 = drive
;        R2 = sequence number
;        R12= private word
; Exit : R2 = sequence number
;        R3 = flags
DoPollChanged
        MOV     R3, #MiscOp_PollChanged_NotChanged_Flag :OR: MiscOp_PollChanged_EmptyWorks_Flag :OR: MiscOp_PollChanged_ChangedWorks_Flag
        ; Fall through
        
; DoLockDrive/DoUnlockDrive
; -------------------------
; Misc op 2/3
; Entry: R1 = drive
;        R12= private word
DoLockDrive
DoUnlockDrive
        MOV     PC, LR

; DoLockDrive/DoUnlockDrive
; -------------------------
; Misc op 4
; Entry: R1 = drive
;        R12= private word
; Exit : R5 = minimum poll period in cs
;        R6 = media type string (unused)
DoPollPeriod
        MOV     R5, #0
        MOV     PC, LR

        END
