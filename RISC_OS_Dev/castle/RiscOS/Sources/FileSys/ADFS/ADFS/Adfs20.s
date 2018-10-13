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
; >Adfs20
;
; Change record
; =============
;
; CDP - Christopher Partington, Cambridge Systems Design
; LVR - Lawrence Rust, Cambridge Beacon
;
; 21-Mar-91  09:09  LVR
; 82710 drivers always use 1 second poll period
;
; 04-Apr-91  16:15  CDP
; Removed Debug20-dependent debug (IDE).
;
;
;*End of change record*

 LTORG

; =============
; LowLevelEntry
; =============

;entry
; R1  reason
 [ BigDisc
; R2  sector disc address top 3 bits drive
 |
; R2  byte disc address top 3 bits drive
 ]
; R3  RAM ptr
; R4  length
; R5  -> disc rec
; R6  -> defect list
; R12 -> private word

LowLevelEntry ROUT
 CMPS   R4, #0                  ;IF 0 length
 BICEQ  R0, R1, #DiscOp_Op_Atomic_Flag :OR: DiscOp_Op_ScatterList_Flag :OR: DiscOp_Op_AltDefectList_Flag
 ASSERT  DiscOp_Verify < DiscOp_ReadTrk
 ASSERT  DiscOp_ReadSecs < DiscOp_ReadTrk
 ASSERT  DiscOp_WriteSecs < DiscOp_ReadTrk
 CMPEQS R0, #DiscOp_ReadTrk     ;AND verify, read/write secs, not background
 MOVLO  PC, LR                  ;THEN nothing to do

 getSB
 Push   "LR"

 [ Debug3

 DREG  R1," ",cc
 DREG  R2," ",cc
 DREG  R3," ",cc
 DREG  R4," ",cc
 DREG  R5," ",cc
 DREG  R6," ",cc
 DLINE "*>LowLevel"
 ]
 TSTS   R2, #bit31              ; Drives 0..3?
 [ BigDisc
        BNE     %FT01
        Push    "R10"                   ; get some workspace
        LDRB    LR, [R5, #SectorSize]   ; get the sector size
        BIC     R10, R2, #DiscBits      ; sector offset
        AND     R2, R2, #DiscBits       ; drive
        ORR     R2, R2, R10, LSL LR     ; combine back as a byte offset addr
        BL      FlpLowLevel             ; FlpLowLevel still uses byte addresses; just munge addrs to work
        LDRB    LR, [R5, #SectorSize]   ; get the sector size back again
        BIC     R10, R2, #DiscBits      ; convert disc addr back
        AND     R2, R2, #DiscBits       ;
        ORR     R2, R2, R10, LSR LR     ;
        Pull    "R10"
        B       %FT02
01
        BL      WinLowLevel     ; winnie code has been changed to handle BigDisc properly
02
 |
        JumpAddress lr,LowLevelExit,forward
        BEQ     FlpLowLevel     ; Yes then do floppy operation
        BNE     WinLowLevel     ; Else winchester
LowLevelExit
 ]

 [ NewErrors
 BLVS   ConvertErrorForParent
 ]
 [ Debug3

 DREG  R0," ",cc
 DREG  R1," ",cc
 DREG  R2," ",cc
 DREG  R3," ",cc
 DREG  R4," ",cc
 DLINE "*<LowLevel"
 ]
 Pull   "PC"

 MACRO
 Misc   $str
 ASSERT MiscOp_$str=(.-MiscTable) :SHR: 2
 B      Do$str
 MEND

; =========
; MiscEntry
; =========

MiscEntry ROUT
        Push    "LR"
        getSB
 [ Debug4 :LOR: Debug10f
  [ :LNOT: Debug4
        TST     R1, #4
        BNE     %FT01
  ]
        DREG    R0," ",cc
        DREG    R1," ",cc
        DREG    R2," ",cc
        DREG    R3," ",cc
        DREG    R4," ",cc
        DREG    R5," ",cc
        DLINE   "*>Misc"
01
 ]

        CMPS    R0, #MiscOp_FirstUnknown
        BLO     %FT10
        MOV     R0, #BadParmsErr
        BL      SetV
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
        Misc    Eject
        Misc    ReadInfo           ; this is done by FileCore
        Misc    DriveStatus

90
 [ NewErrors
        BLVS    ConvertErrorForParent
 ]
 [ Debug4

        DREG    R0," ",cc
        DREG    R1," ",cc
        DREG    R2," ",cc
        DREG    R3," ",cc
        DREG    R4," ",cc
        DREG    R5," ",cc
        DLINE   "*<Misc"
 ]
        Pull    "PC"


; =======
; DoMount
; =======

;entry
; R1 drive
; R2 disc address
; R3 -> buffer
; R4 length
; R5 -> disc rec to fill in for floppies

;exit R0,V internal error

DoMount ROUT
 [ Debug4
 DREG   r2, "Misc mount address:"
 ]
 TSTS   R2, #bit31                      ; Drives 0..3?
 BEQ    FlpMount                        ; Yes then jump, mount floppy
 B      WinMount                        ; Else mount winchester


DiscString
 = "disc",0
 ALIGN

; ============
; DoEject - Eject the drive in r1 if on A500 (or drive 0 if top bit set).
; ============
DoEject ROUT
        MOV     pc, lr

; ==========
; DoReadInfo
; ==========

; this miscop is handled entirely by filecore

DoReadInfo ROUT
        Push    "lr"
        MOV     R0, #BadParmsErr
        BL      SetV
        Pull    "pc"

; =============
; DoDriveStatus
; =============

DoDriveStatus ROUT
        Push    "lr"
        TSTS    r1, #4
        LDRNE   r2, WinIDECommandActive
        TEQNE   r2, #0
        MOVNE   r2, #1
        MOVEQ   r2, #0
        Pull    "pc"

; ============
; DoPollPeriod
; ============
DoPollPeriod ROUT
 [ fix_2
        Push    "R1,R2,LR"

        LDR     LR, MachineID
        TEQS    LR, #MachHas82710       ; 82710 controller?
        MOVEQ   R5, #PollPeriodLong     ; Yes then always poll slowly
        BEQ     %FT30

        MOV     R5, #3
        LDRB    R1, Floppies
        sbaddr  R2, DrvRecs+DrvFlags
        B       %FT20
10
        LDRB    LR, [R2], #SzDrvRec
        TST     LR, #MiscOp_PollChanged_ChangedWorks_Flag   ;RCM>>> Arn't these bits always
        TSTNE   LR, #MiscOp_PollChanged_EmptyWorks_Flag     ;       set the same
        MOVEQ   R5, #0
        TST     LR, #ResetChangedByWrite
        BICEQ   R5, R5, #2
20
        SUBS    R1, R1, #1
        BPL     %BT10

; R5 is 3 = Drive has a 'disc changed reset' line so poll quickly
;       1 = 'Disc changed' reset by step, so poll slowly cos DBell prefers it
;       0 = No disc changed line, so don't poll

        CMP     R5, #1
        MOVGT   R5, #PollPeriodShort
        MOVEQ   R5, #PollPeriodLong
        MOVLT   R5, #-1                 ;Infinite
30
        baddr   R6, DiscString
        Pull    "R1,R2,PC"
 |
        Push    "R1,R2,LR"
        MOV     R5, #PollPeriod
        LDRB    R1, Floppies
        sbaddr  R2, DrvRecs+DrvFlags
        B       %FT20
10
        LDRB    LR, [R2], #SzDrvRec                     ;RCM>>> equivalant to
        ASSERT  MiscOp_PollChanged_ChangedWorks_Flag = bit7 ; ==> NOT Zero  ; LDRB   LR, [R2], #SzDrvRec
        ASSERT  MiscOp_PollChanged_EmptyWorks_Flag   = bit6 ; ==> Carry     ; TST    LR, #MiscOp_PollChanged_ChangedWorks_Flag
        MOVS    LR, LR, LSR #7                          ; TSTNE  LR, #MiscOp_PollChanged_EmptyWorks_Flag
        MOVLS   R5, #-1 ; Test C=0 or Z=1               ; MOVEQ  R5, #-1
20
        SUBS    R1, R1, #1
        BPL     %BT10
        baddr   R6, DiscString
        Pull    "R1,R2,PC"
 ]

 [ NewErrors
; =====================
; ConvertErrorForParent
; =====================
; in: R0 = new-style FileCore error
; out: R0 = old- or new-style FileCore error, as appropriate
;      V preserved
ConvertErrorForParent ROUT
        Push    "LR"
        LDRB    LR, NewErrorsFlag
        TEQS    LR, #0                  ; new FileCore? then leave untouched
        Pull    "PC", NE
        BICS    LR, R0, #&FF            ; (CMP would corrupt V flag)
        Pull    "PC", EQ                ; < 256? Then standard error, leave untouched
        TSTS    R0, #NewDiscErrorBit    ; not a disc error?
        ORREQ   R0, R0, #ExternalErrorBit
        Pull    "PC", EQ                ; then set external error bit, and return
        Push    "R1,R2"
        BIC     R3, R0, #3              ; Knock out the 2 flags
        LDMIA   R3, {R1,R2,R3}
 [ BigDisc
        TSTS    R2, #DiscBits
        TEQEQS  R3, #0                  ; return old-style error if address is small
        BEQ     %FT05
        ; only IDE hard drives handle such large addresses, so..
        ASSERT  WinIDEBytesPerSector = 512
        MOV     R2, R2, LSR #9
        ORR     R2, R2, R3, LSL #(32-9)
        BIC     R2, R2, #DiscBits
        ORR     R2, R2, R1, LSL #(32-3)
        MOV     R1, R1, LSR #8
        AND     R1, R1, #&FF
        ADR     R0, WinIDEErrorNo
        STMIA   R0, {R1,R2}
        ORR     R0, R0, #DiscErrorBit+ExternalErrorBit
        B       %FT90
05
 ]
        BIC     R2, R2, #DiscBits
        MOV     R0, R2, LSR #8
        AND     LR, R1, #7
        ORR     R0, R0, LR, LSL #21
        AND     LR, R1, #MaxDiscErr:SHL:8
        ORR     R0, R0, LR, LSL #(24-8)
        ORR     R0, R0, #DiscErrorBit
90
        Pull    "R1,R2,PC"
 ]

 END
