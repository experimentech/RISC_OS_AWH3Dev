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
; >GenSWIs
;
; **************
; Change History
; **************
;
; 08-Sep-1994 SBP Improved commenting DoSwiCreate

        TTL     "General SWI routines"

        LTORG

; entry: R1=disc op
;        R2=disc address
;
; exit: VC->can do operation on this disc, R0 corrupt
;       VS->operation not permitted, R0 error

EnsureFSLock64 ROUT
        Push    "r1,r2,lr"
        LDRB    r2, [r2, #0]
        AND     r1, r1, #DiscOp_Op_Mask         ; get actual operation being done
; check this operation against list of write ops
        TEQ     r1, #DiscOp_WriteSecs
        TEQNE   r1, #DiscOp_WriteTrk
        BEQ     %FT04
        CLRV
        Pull    "r1, r2, pc"

EnsureFSLock
        Push    "r1,r2,lr"
        AND     r1, r1, #DiscOp_Op_Mask         ; get actual operation being done
; check this operation against list of write ops
        TEQ     r1, #DiscOp_WriteSecs
        TEQNE   r1, #DiscOp_WriteTrk
        BEQ     %FT01
        CLRV
        Pull    "r1, r2, pc"

; here when a write operation - check lock status
01
        MOV     r2, r2, LSR #(32-3)     ; get drive number
04      CMP     r2, #4
        Pull    "r1,r2,pc",LO           ; not hard disc - ignore

        SWI     Auto_Error_SWI_bit :OR: &44781 ; get the lock status
        BVC     %FT02
 [ :LNOT:NewErrors
        ORR     R0, R0, #ExternalErrorBit
 ]
        Pull    "r1,r2,pc"              ; if error then return it
02
; now check if FS is locked
        CMP     r0, #2
        BEQ     %FT03
        CLRV
 [ :LNOT:NewErrors
        ORR     R0,R0,#ExternalErrorBit
 ]
        Pull    "r1,r2,pc"              ; not locked

03
        LDRB    r0, FS_Id               ; get FSnumber
        CMP     r0, r1                  ; are they the same
        MOVEQ   r0, #FSLockedErr
        MOVNE   r0, #0
        BL      SetVOnR0
        Pull    "r1,r2,pc"


; Construct disc record from disc format structure
; entry: r4 -> format structure
; exit:  sp lowered by unknown amount
;        r5 -> disc record (contained in claimed stack)
;        other registers preserved

MakeDiscRecFromFormatStructure ROUT

        Push    "r1,r2,r3,lr"

 [ BigDisc
        SUB     sp, sp, #SzDiscRecSig2
 |
        SUB     sp, sp, #SzDiscRecSig
 ]
        LDR     lr, [r4, #DoFormatSectorSize]
        MOV     r3, #0
11
        MOVS    lr, lr, LSR #1
        ADDNE   r3, r3, #1
        BNE     %BT11
 [ DebugL :LOR: Debug2D
        DREG    r3, "SS=",cc
 ]
        STRB    r3, [sp, #DiscRecord_Log2SectorSize]
        LDRB    r3, [r4, #DoFormatSectorsPerTrk]
 [ DebugL :LOR: Debug2D
        DREG    r3, " SPT=",cc
 ]
        STRB    r3, [sp, #DiscRecord_SecsPerTrk]
        LDRB    r3, [r4, #DoFormatOptions]
        AND     r3, r3, #FormatOptSidesMask
        TEQ     r3, #FormatOptInterleaveSides
        MOVEQ   r3, #2
        MOVNE   r3, #1
 [ DebugL :LOR: Debug2D
        DREG    r3, " H=",cc
 ]
        STRB    r3, [sp, #DiscRecord_Heads]
        LDRB    r3, [r4, #DoFormatDensity]
 [ DebugL :LOR: Debug2D
        DREG    r3, " D=",cc
 ]
        STRB    r3, [sp, #DiscRecord_Density]
        MOV     r3, #0
        ASSERT  DiscRecord_IdLen :MOD: 4 = 0
        ASSERT  DiscRecord_Log2bpmb = DiscRecord_IdLen+1
        ASSERT  DiscRecord_Skew = DiscRecord_Log2bpmb+1
        ASSERT  DiscRecord_BootOpt = DiscRecord_Skew+1
        STR     r3, [sp, #DiscRecord_IdLen]

        MOV     r2, #&100
        LDRB    r3, [sp, #DiscRecord_SecsPerTrk]
        ADD     lr, r4, #DoFormatSectorList+2
12
        LDRB    r1, [lr], #4
        CMP     r1, r2
        MOVLO   r2, r1
        SUBS    r3, r3, #1
        BHI     %BT12

        LDRB    r3, [r4, #DoFormatOptions]
        AND     lr, r3, #FormatOptSidesMask
        TEQ     lr, #FormatOptInterleaveSides
        ORRNE   r2, r2, #DiscRecord_SequenceSides_Flag
        TST     r3, #FormatOptDoubleStep
        ORRNE   r2, r2, #DiscRecord_DoubleStep_Flag
 [ DebugL :LOR: Debug2D
        DREG    r2, " LS=",cc
 ]
        STRB    r2, [sp, #DiscRecord_LowSector]
        MOV     r1, #0
        STRB    r1, [sp, #DiscRecord_NZones]
 [ BigMaps
        STRB    r1, [sp, #DiscRecord_BigMap_NZones2]
 ]
        STRB    r1, [sp, #DiscRecord_ZoneSpare]
        STRB    r1, [sp, #DiscRecord_ZoneSpare+1]
 [ DebugL :LOR: Debug2D
        DREG    r1, "Setting RootDir to "
 ]
        STR     r1, [sp, #DiscRecord_Root]
        LDR     r1, [r4, #DoFormatCylindersPerDrive]

 [ BigDisc
; generate both parts of DiscSize
        LDRB    lr, [sp, #DiscRecord_SecsPerTrk]
        MUL     r1, lr, r1
        LDRB    lr, [sp, #DiscRecord_Log2SectorSize]
        ADD     lr, lr, #1
        RSB     r2, lr, #32
        MOV     r2, r1, LSR r2
        MOV     r1, r1, LSL lr
 [ DebugL :LOR: Debug2D
        DREG    r1, " DS1="
        DREG    r2, " DS2="
 ]
        STR     r2, [sp, #DiscRecord_BigMap_DiscSize2]
        STR     r1, [sp, #DiscRecord_DiscSize]
 |
        LDRB    lr, [sp, #DiscRecord_Log2SectorSize]
        ADD     lr, lr, #1
        MOV     r1, r1, ASL lr
        LDRB    lr, [sp, #DiscRecord_SecsPerTrk]
        MUL     r1, lr, r1
 [ DebugL :LOR: Debug2D
        DREG    r1, " DS="
 ]
        STR     r1, [sp, #DiscRecord_DiscSize]
 ]

        MOV     r1, #0
        STR     r1, [sp, #DiscRecord_DiscId]
        STR     r1, [sp, #DiscRecord_DiscName+2]
        STR     r1, [sp, #DiscRecord_DiscName+6]

        MOV     r5, sp

 [ BigDisc
        ADD     lr, sp, #SzDiscRecSig2
 |
        ADD     lr, sp, #SzDiscRecSig
 ]
        LDMIA   lr, {r1,r2,r3,pc}


DoSwiDiscOp ROUT
        Push    "r1,r5,r11,lr"
 [ Debug2 :LOR: Debug2D
        DREG    r1, "DiscOp(",cc
        DREG    r2, ",",cc
        DREG    r3, ",",cc
        DREG    r4, ",",cc
        DLINE   ")"
 ]
 [ BigDisc
        BL      EnsureFSLock            ; check that we can actually do this
        Pull    "r1,r5,r11,pc",VS       ; if v set then return with error
 ]
        MOV     r11, sp
        EOR     R2, R2, #bit31          ; Convert to internal drive numbering

        ASSERT  SzDiscRec :MOD: 4 = 0
        MOVS    R5, R1, LSR #8
        MOVNE   R5, R5, LSL #2

        AND     R1, R1, #&FF            ; Remove any embarrasing bits from the op

        BNE     %FT20                   ;if disc rec supplied by caller

10
        ; Disc record not supplied by the user

        AND     lr, r1, #DiscOp_Op_Mask
        TEQ     lr, #DiscOp_WriteTrk
        TEQEQ   r3, #0
        BNE     %FT15

        BL      MakeDiscRecFromFormatStructure
        B       %FT30

15
        ; We must identify the disc to supply a disc record
        Push    "R1-R3"
        MOV     R1, R2, LSR #(32-3)     ;drive
        BL      WhatDisc                ;(R1->R0-R3,V)
        MOV     R5, R3
        Pull    "R1-R3"

        ; If error from WhatDisc then disc unreadable
        BVS     %FT95

        ; If disc record is internal, then the defect
        ; list _Definitely_ does not prefixing it
        BIC     R1, R1, #DiscOp_Op_AltDefectList_Flag
        B       %FT30

20
        ; For the situation when a disc record is supplied we do a PollChange
        ; here so that our idea of when the disc has changed doesn't get corrupted
        ; by a head step clearing the (physical) drive's 'disc has changed' line.
        MOV     R0, R2, LSR #(32-3)
        BL      PollChange

30
 [ BigDisc
        Push    "R3,R4"
        LDRB    R3,[R5,#DiscRecord_Log2SectorSize]      ; get sector size
        AND     R4,R2,#DiscBits
        BIC     R2,R2,#DiscBits
        ORR     R2,R4,R2,LSR R3         ; sector addr

        Pull    "R3,R4"
 [ DebugL :LOR: Debug2D
        DREG    r1, "DriveOp(",cc
        DREG    r2, ",",cc
        DREG    r3, ",",cc
        DREG    r4, ",",cc
        DLINE   ")"
 ]
        BL      RetryDriveOp            ;
;       LDR     LR,DiscOp_ByteAddr      ; get end addr
        Push    "R3"
 [ DebugL :LOR: Debug2D
        DREG    R2, "Original address : "
 ]
        LDRB    R3,[R5,#DiscRecord_Log2SectorSize]
        BIC     LR,R2,#DiscBits
        AND     R2,R2,#DiscBits
        ORR     R2,R2,LR,LSL R3
 [ DebugL :LOR: Debug2D
        DREG    R3, "Log2SectorSize : "
        DREG    R2, "Result address : "
 ]
        Pull    "R3"
 |
        BL      RetryDriveOp            ;(R1-R6->R0,R2-R4,R6,V)
 ]

        MOVVC   R0, #0
95
        EOR     R2, R2, #bit31          ; Convert back to external drive numbering
        MOV     sp, r11
        Pull    "r1,r5,r11,PC"


DoSwiSectorDiscOp ROUT
        Push    "r1,r5,r11,lr"
 [ Debug2 :LOR: Debug2D
        DREG    r1, "SectorDiscOp(",cc
        DREG    r2, ",",cc
        DREG    r3, ",",cc
        DREG    r4, ",",cc
        DLINE   ")"
 ]
 [ BigDisc
        BL      EnsureFSLock            ; check that we can actually do this; if V set
                                        ; then return with error
        Pull    "r1,r5,r11,pc",VS
 ]
        MOV     r11, sp
        EOR     R2, R2, #bit31          ; Convert to internal drive numbering

        ASSERT  SzDiscRec :MOD: 4 = 0
        MOVS    R5, R1, LSR #8
        MOVNE   R5, R5, LSL #2

        AND     R1, R1, #&FF            ; Remove any embarasing bits from the op

        BNE     %FT20                   ;if disc rec supplied by caller

10
        ; Disc record not supplied by the user

        AND     lr, r1, #DiscOp_Op_Mask
        TEQ     lr, #DiscOp_WriteTrk
        TEQEQ   r3, #0
        BNE     %FT15

        BL      MakeDiscRecFromFormatStructure
        B       %FT30

15
        ; We must identify the disc to supply a disc record
        Push    "R1-R3"
        MOV     R1, R2, LSR #(32-3)     ;drive
        BL      WhatDisc                ;(R1->R0-R3,V)
        MOV     R5, R3
        Pull    "R1-R3"

        ; If error from WhatDisc then disc unreadable
        BVS     %FT95

        ; If disc record is internal, then the defect
        ; list _Definitely_ does not prefixing it
        BIC     R1, R1, #DiscOp_Op_AltDefectList_Flag
        B       %FT30

20
        ; For the situation when a disc record is supplied we do a PollChange
        ; here so that our idea of when the disc has changed doesn't get corrupted
        ; by a head step clearing the (physical) drive's 'disc has changed' line.
        MOV     R0, R2, LSR #(32-3)
        BL      PollChange

30
        BL      RetryDriveOp            ;(R1-R6->R0,R2-R4,R6,V)

        MOVVC   R0, #0
95
        EOR     R2, R2, #bit31          ; Convert back to external drive numbering
        MOV     sp, r11
        Pull    "r1,r5,r11,PC"


DoSwiDiscOp64 ROUT
        Push    "r1,r2,r5,r11,lr"
DO64_R2Offset * 4
 [ Debug2 :LOR: Debug2D
        DREG    r1, "DiscOp(",cc
        LDRB    lr, [r2, #ExtendedDiscAddress_DriveNumber]
        DREG    lr, ",:",cc,Byte
        LDR     lr, [r2, #ExtendedDiscAddress_LowWord]
        DREG    lr, "/",cc
        LDR     lr, [r2, #ExtendedDiscAddress_HighWord]
        DREG    lr,    ,cc
        DREG    r3, ",",cc
        DREG    r4, ",",cc
        DREG    r5, ",",cc
        DLINE   ")"
 ]
        LDRB    LR, [R2, #ExtendedDiscAddress_DriveNumber]

        MOV     r11, sp

        CMP     LR, #8
        BHS     DO64_BadDrive

 [ BigDisc
        BL      EnsureFSLock64          ; check that we can actually do this
        Pull    "r1,r2,r5,r11,pc",VS    ; if v set then return with error
 ]

        AND     R1, R1, #&FF            ; Remove any embarrasing bits from the op

        TEQ     R5, #0
        BNE     %FT20                   ;if disc rec supplied by caller

10
        ; Disc record not supplied by the user

        AND     lr, r1, #DiscOp_Op_Mask
        TEQ     lr, #DiscOp_WriteTrk
        TEQEQ   r3, #0
        BNE     %FT15

        BL      MakeDiscRecFromFormatStructure
        B       %FT30

15
        ; We must identify the disc to supply a disc record
        LDRB    LR, [R2, #ExtendedDiscAddress_DriveNumber]
        Push    "R1-R3"
        EOR     R1, LR, #bit2           ;convert to internal numbering
        BL      WhatDisc                ;(R1->R0-R3,V)
        MOV     R5, R3
        Pull    "R1-R3"

        ; If error from WhatDisc then disc unreadable
        BVS     %FT95

        ; If disc record is internal, then the defect
        ; list _Definitely_ does not prefixing it
        BIC     R1, R1, #DiscOp_Op_AltDefectList_Flag
        B       %FT30

20
        ; For the situation when a disc record is supplied we do a PollChange
        ; here so that our idea of when the disc has changed doesn't get corrupted
        ; by a head step clearing the (physical) drive's 'disc has changed' line.
        LDRB    R0, [R2, #ExtendedDiscAddress_DriveNumber]
        EOR     R0, R0, #bit2           ;convert to internal numbering
        BL      PollChange

30
 [ BigDisc
        Push    "R1,R3"
        LDRB    R3,[R5,#DiscRecord_Log2SectorSize]      ; get sector size
        LDMIB   R2,{R1,LR}              ; turn 64-bit byte address + drive into packed
        LDRB    R2,[R2,#ExtendedDiscAddress_DriveNumber]
        RSB     R0,R3,#32
        MOV     R1,R1,LSR R3
        ORR     R1,R1,LR,LSL R0
        MOVS    LR,LR,LSR R3            ; ensure no overflow
        TSTEQ   R1,#DiscBits
        BNE     DO64_Overflow
        ORR     R2,R1,R2,LSL #(32-3)    ; sector addr
        EOR     R2, R2, #bit31          ; Convert to internal drive numbering

 [ DebugL :LOR: Debug2D
        DREG    R2, "Original address : "
        DREG    R3, "Log2SectorSize : "
 ]

        Pull    "R1,R3"
 [ DebugL :LOR: Debug2D
        DREG    r1, "DriveOp(",cc
        DREG    r2, ",",cc
        DREG    r3, ",",cc
        DREG    r4, ",",cc
        DLINE   ")"
 ]
        BL      RetryDriveOp            ;
;       LDR     LR,DiscOp_ByteAddr      ; get end addr
        LDRB    R5,[R5,#DiscRecord_Log2SectorSize]
        LDR     R1,[SP, #DO64_R2Offset]
        BIC     R2,R2,#DiscBits
        RSB     LR,R5,#32
        MOV     LR,R2,LSR LR
        MOV     R2,R2,LSL R5
        STMIB   R1,{R2,LR}
 [ DebugL :LOR: Debug2D
        DREG    LR, "Result address : ",cc
        DREG    R2
 ]
 |
        LDRB    R0, [R2,#0]
        LDMIB   R2, {R2, LR}
        TST     R2, #DiscBits
        TEQEQ   LR, #0
        BNE     DO64_Overflow
        ORR     R2, R2, R0, LSL #(32-3)
        EOR     R2, R2, #bit31          ; Convert to internal drive numbering
        BL      RetryDriveOp            ;(R1-R6->R0,R2-R4,R6,V)
        LDR     LR, [sp, #DO64_R2Offset]
        BIC     R2, R2, #DiscBits
        STR     R2, [LR, #4]
 ]

        MOVVC   R0, #0
95
        MOV     sp, r11
        Pull    "r1,r2,r5,r11,PC"

DO64_BadDrive
        MOV     R0, #BadDriveErr
        BL      SetV
        B       %BT95

DO64_Overflow
        MOV     R0, #BadParmsErr
        BL      SetV
        B       %BT95


; ***************************************************************************
;
; SWI FileCore_Create, after a few centuries, arrives here.
;
; SBP:  This routine is simply a veneer, which puts the arguments for
;       FileCore_Create onto the stack, and then initialises a new
;       instantiation of filecore with the name 'FileCore%FSname'.
;       The address of the arguments is passed onto the new instantiation
;       as a string, ie the string passed to OS_Module is, for example,
;
;       'FileCore%ADFS <hex number>'

Dummy ROUT
00
 = "FileCore"
01
 = "%"
        ALIGN
DoSwiCreate
        TEQS    R0, #0          ;return if just dummy call to check Filecore's  existence
        MOVEQ   PC, LR
        Push    "R0-R6,LR"
        MOV     R6, SP          ;to restore stack at end
        MOV     R3, SP          ;to convert to hex string

        LDR     R4, [R0,#Create_Title]
        ADD     R4, R4, R1      ;name start
        MOV     R1, SP          ;to point to last byte of string built

        MOV     R5, #0          ;put string terminator
        BL      %FT99           ;R1,R5,SP->R1,SP
05                      ;put hex string for ptr to stacked regs
        AND     R5, R3, #&F
        CMPS    R5, #10
        ADDHS   R5, R5, #"A"-10
        ADDLO   R5, R5, #"0"
        BL      %FT99
        MOVS    R3, R3, LSR #4
        BNE     %BT05

        MOV     R5, #" "        ;put space separator
        BL      %FT99

        MOV     R3, R4
10                      ;find fs name end
        LDRB    R5, [R3],#1
        CMPS    R5, #" "
        BHI     %BT10

        SUB     R3, R3, #1
15                      ;copy fs name
        CMPS    R3, R4
        BLS     %FT18
        LDRB    R5, [R3,#-1] !
        BL      %FT99
        B       %BT15

18
        baddr   R3, %B00        ;copy FileCore%
        baddr   R4, %B01
20
        LDRB    R5, [R4],#-1
        BL      %FT99
        CMPS    R4, R3
        BHS     %BT20

        MOV     R0, #ModHandReason_NewIncarnation
        BL      OnlyXOS_Module
 [ Debug2
        DebugError "Create filecore instantiation: "
 ]
        MOVVC   R0, #ModHandReason_LookupName
        BLVC    OnlyXOS_Module
        LDRVC   R0, [R4,# :INDEX: PrivateWord]

        ADD     SP, R6, #4*4    ;return workspace
        ADRL    R1, FloppyOpDone
        ADRL    R2, WinnieOpDone
        ADR     R3, ParentFiqRelease
        Pull    "R4-R6,PC"

; SBP: I added the comments here because I found the code hard to follow.
;      Next time, it'll be easier :*)

; Entry:
;      R1: address of last pushed byte
;      R5: byte to store
;      SP: stack pointer, word aligned just below R1
;
; Exit:
;      R1 dropped 1 byte, points to stored value
;      SP updated to keep it at highest word boundary at or below R1

99
        TSTS    R1, #3                  ; are we going to cross a word boundary?
        SUBEQ   SP, SP, #4              ; yes, so drag SP down to next boundary
        STRB    R5, [R1,#-1] !          ; store byte and drop ptr
        MOV     PC, LR                  ; byebye



; <<<<<<<<<<<<<<<<
; ParentFiqRelease
; <<<<<<<<<<<<<<<<

ParentFiqRelease
        Push    "LR"
        getSB
 [ DebugI
        DLINE   " R1 ",cc
 ]
        BL      ReleaseFiq
        Pull    "PC"



DoSwiDrives ROUT
        LDRB    R0, Drive
        EOR     R0, R0, #4
        LDRB    R1, Floppies
        LDRB    R2, Winnies
        MOV     PC, LR


DoSwiFreeSpace ROUT
;entry R0 -> disc spec
;exit  R0 = total free space
;      R1 = largest obj that can be created
        Push    "r2,r3,r11,LR"

        MOV     r11, sp

        MOV     r1, r0
        BL      strlen
        MOV     r2, r3
        LDR     r1, FS_Title
        BL      strlen
        ADD     r3, r3, r2
        ADD     r3, r3, #2 + 1 + 3      ; 2 for ::, one for terminator, 3 for round-up
        BIC     r3, r3, #3

        SUB     sp, sp, r3
        MOV     r2, r1                  ; FS_Title
        MOV     r1, sp
        BL      strcpy
        BL      strlen
        ADD     r1, r1, r3
        MOV     lr, #":"
        STRB    lr, [r1], #1            ; ::
        STRB    lr, [r1], #1
        MOV     r2, r0
        LDRB    lr, [r2]                ; disc specifier (excluding : prefix)
        TEQ     lr, #":"
        ADDEQ   r2, r2, #1
        BL      strcpy

        MOV     r0, #FSControl_ReadFreeSpace
        MOV     r1, sp
 [ Debug2
        DSTRING r1, "FSControl_ReadFreeSpace(",cc
        DLINE   ")"
 ]
        BL      DoXOS_FSControl

        MOV     sp, r11

95
        Pull    "r2,r3,r11,PC"

 [ BigDisc

DoSwiFreeSpace64 ROUT
;entry R0 -> disc spec
;exit  R0 = total free space
;      R1 = largest obj that can be created
        Push    "r3,r4,r11,LR"

        MOV     r11, sp

        MOV     r1, r0
        BL      strlen
        MOV     r2, r3
        LDR     r1, FS_Title
        BL      strlen
        ADD     r3, r3, r2
        ADD     r3, r3, #2 + 1 + 3      ; 2 for ::, one for terminator, 3 for round-up
        BIC     r3, r3, #3

        SUB     sp, sp, r3
        MOV     r2, r1                  ; FS_Title
        MOV     r1, sp
        BL      strcpy
        BL      strlen
        ADD     r1, r1, r3
        MOV     lr, #":"
        STRB    lr, [r1], #1            ; ::
        STRB    lr, [r1], #1
        MOV     r2, r0
        LDRB    lr, [r2]                ; disc specifier (excluding : prefix)
        TEQ     lr, #":"
        ADDEQ   r2, r2, #1
        BL      strcpy

        MOV     r0, #FSControl_ReadFreeSpace64
        MOV     r1, sp
 [ Debug2
        DSTRING r1, "FSControl_ReadFreeSpace64(",cc
        DLINE   ")"
 ]
        BL      DoXOS_FSControl

        MOV     sp, r11

95
        Pull    "r3,r4,r11,PC"
 ]

DoSwiFloppyStructure ROUT
;entry
; R0 -> buffer
; R1 -> DiscRec
; R2    OldMapFlag, OldDirFlag set if appropriate
; R3 -> defect list
;exit
; R0, V set if error
; R3    structure size

        Push    "R0-R11,LR"
 [ Debug2
        DREG    R0, "", cc
        DREG    R1, ", ", cc
        DREG    R2, " ", cc
        DLINE   ">DoSwiFloppyStructure"
 ]
        LDMIA   SP, {R3,R4,R8,R9}
        CMPS    R8, #OldMapFlag
        MOVLO   R1, #SzNewFloppyFs*2    ;E
        MOVEQ   R1, #1*K                ;D
        MOVHI   R1, #SzOldFs            ;L
        BL      ZeroRam                 ;(R0,R1)
        ADD     R5, R3, R1
        BLO     %FT40           ;new map

;BUILD OLD MAP
 [ Debug2
        DLINE    "build old map"
 ]
        ADDEQ   LR, R1, #NewDirSize
        ADDHI   LR, R1, #OldDirSize
        STR     LR, [SP, #3*4]          ;exit R3
        ASSERT  FreeStart :MOD: 4 = 0
        MOV     LR, LR, LSR #8
        STR     LR, [R0, #FreeStart]
        LDR     R2, [R4, #DiscRecord_DiscSize]
        MOV     R2, R2, LSR #8
        ASSERT  OldSize :MOD: 4 =0
        STR     R2, [R0, #OldSize]
        SUB     LR, R2, LR
        ASSERT  FreeLen :MOD: 4 = 0
        STR     LR, [R0, #FreeLen]
        LDRB    LR, [R4, #DiscRecord_BootOpt]
        STRB    LR, [R0, #OldBoot]
        MOV     LR, #3
        STRB    LR, [R0, #FreeEnd]

        ADD     R1, R4, #DiscRecord_DiscName
        ADD     R2, R0, #OldName0
        MOV     R6, #NameLen
20
        LDRB    LR, [R1], #1
        STRB    LR, [R2], #OldName1-OldName0
        LDRB    LR, [R1], #1
        STRB    LR, [R2], #1-(OldName1-OldName0)
        SUBS    R6, R6, #2
        BNE     %BT20

        MOV     R1, #SzOldFs/2
        BL      CheckSum                ;(R0,R1->R2,V)
        STRB    R2, [R0, #Check0]
        BL      OldRandomId             ;(R0)
        B       %FT60

30                              ;(R4-R5,R8-R10->R7,R9)
        Push    "R0,R11,LR"
        LDR     R0, [R9]                ;get next defect
        CMPS    R0, #bit29              ;special case end marker to end of zone
        BLO     %FT35
        CLRV
        MOV     R7, R2
        Pull    "R0,R11,PC"             ;amg MED-03799  7th October 1994
                                        ;don't hang around if this is the end marker
                                        ;because the tests below eventually forget!
35
 [ BigDisc
        Push    "R1"
        LDRB    R1,[R10,#ZoneHead+DiscRecord_Log2SectorSize]
        MOV     R0, R0, LSR R1
        Pull    "R1"
 ]
        BL      DiscAddToMapPtr         ;(R0,R10->R11,LR)
        BIC     R7, R11,R5
        ADD     R9, R9, #4              ;advance in defect list if not end
        SUBS    R11,R8, R7
        CMPNES  R11,R4                  ;if defect too close to end of zone
        SUBLT   R7, R8, R4              ;then adjust
        SUBS    R11,R2, R7
        CMPNES  R11,R4
        SUBLO   R7, R2, R4
        CLRV
        Pull    "R0,R11,PC"

;BUILD NEW MAP
40
 [ Debug2
        DLINE    "build new map"
 ]
        ADD     LR, R1, #NewDirSize
        STR     LR, [SP, #3*4]          ;exit R3
        ADD     R1, R0, #ZoneHead       ;copy structure from disc rec
        MOV     R0, R4
        MOV     R2, #SzDiscRecSig
        BL      BlockMove               ;(R0-R2)

        SUB     R10,R1, #ZoneHead       ;First 4 bytes, free link etc
        MOV     LR, #1 :SHL: (FreeLink*8+15)
        ORR     LR, LR, #&FF :SHL: (CrossCheck*8)
        STR     LR, [R10]

 [ BigDisc
        MOV     R0, #((SzNewFloppyFs * 2) + NewDirSize)
        Push    "R1"
        LDRB    R1, [R10,#ZoneHead+DiscRecord_Log2SectorSize]   ; get the sector size
        MOV     R0, R0, LSR R1
        Pull    "R1"
 |
        MOV     R0, #(SzNewFloppyFs * 2) + NewDirSize
 ]
        BL      DiscAddToMapPtr         ;(R0,R10->R11,LR)

        MOV     R1, #(ZoneHead + ZoneDiscRecSz) * 8     ;entry for maps and root
        MOV     R0, #2
 [ BigMaps
        BL      FragWrLinkBits          ;(R0,R1,R10)
 |
        BL      WrLinkBits              ;(R0,R1,R10)
 ]
        SUB     R0, R11,R1
        Push    "R4,R5,R8"
        BL      MinMapObj               ;(R10->LR)
        CMPS    R0, LR
        MOVLO   R0, LR
        ADDLO   R11,R1, LR
 [ BigMaps
        BL      FragWrLenBits           ;(R0,R1,R10)
 |
        BL      WrLenBits               ;(R0,R1,R10)
 ]

        MOV     R3, R11                 ;init free start

        LDR     R0, [R4, #DiscRecord_DiscSize]

        SUB     R0, R0, #1
 [ BigDisc
        BL      ByteDiscAddToMapPtr     ;(R0,R10->R11,LR) (to fix RAMFS discs coming out truncated)
 |
        BL      DiscAddToMapPtr         ;(R0,R10->R11,LR)
 ]

        ADD     R2, R11,#1              ;disc end map ptr

        BL      AllocBitWidth           ;(R10->LR)
        SUB     R5, LR, #1
        BIC     R2, R2, R5
        BL      MinMapObj               ;(R10->LR)
        MOV     R4, LR
        MOV     R6, #FreeLink*8         ;init previous gap
        LDRB    R8, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        MOV     LR, #8
        MOV     R8, LR, LSL R8          ;bits in a sector
        BL      %BT30                   ;(R4-R5,R8-R10->R7,R9)
        SUBS    R11,R7, R3
        MOVMI   R0, #DefectErr
        ADDMI   SP, SP, #(3+1)*4
        BLMI    SetV
        Pull    "R1-R11,PC",MI
        CMPS    R11,R4                  ;if defect too close to free start
        MOVLO   R7, R3                  ;then adjust
42
        SUBS    R0, R7, R3              ;IF there is some free space
        MOVHI   R1, R3                  ;THEN
 [ BigMaps
        BLHI    FragWrLenBits           ; set its length (R0,R1,R10)
 |
        BLHI    WrLenBits               ; set its length (R0,R1,R10)
 ]
        MOVHI   R1, R6                  ; point previous free space at it
        SUBHI   R0, R3, R6
 [ BigMaps
        BLHI    FragWrLinkBits          ; (R0,R1,R10)
 |
        BLHI    WrLinkBits              ; (R0,R1,R10)
 ]
        MOVHI   R6, R3                  ; update previous free space

        MOV     R1, R7                  ;defect start map ptr
        CMPS    R7, R8
        BHS     %FT50
        ADD     R3, R7, R4              ;defect end map ptr
44
        SUB     LR, R2, R3
        CMPS    LR, R4
        MOVLT   R3, R8
        BLT     %FT48

46
        BL      %BT30                   ;(R4-R5,R8-R10->R7,R9)
        SUBS    LR, R7, R3
        BLO     %BT46
        CMPS    LR, R4
        ADDLO   R3, R7, R5
        ADDLO   R3, R3, #1
        BLO     %BT44

48
        SUB     R0, R3, R1
 [ BigMaps
        BL      FragWrLenBits           ;(R0,R1,R10)
 |
        BL      WrLenBits               ;(R0,R1,R10)
 ]
        MOV     R0, #1
 [ BigMaps
        BL      FragWrLinkBits          ;(R0,R1,R10)
 |
        BL      WrLinkBits              ;(R0,R1,R10)
 ]

        SUB     LR, R3, R2
        CMPS    LR, R4
        SUBGE   R0, R2, R1
        CMPGES  R0, R4
 [ BigMaps
        BLGE    FragWrLenBits           ;(R0,R1,R10)
 |
        BLGE    WrLenBits               ;(R0,R1,R10)
 ]
        MOVGE   R1, R2
        MOVGE   R0, #1
 [ BigMaps
        BLGE    FragWrLinkBits          ;(R0,R1,R10)
 |
        BLGE    WrLinkBits              ;(R0,R1,R10)
 ]

        CMPS    R3, R8
        BLO     %BT42
50
        Pull    "R4,R5,R8"

        MOV     R0, R10
        BL      NewRandomId             ;(R0)
        MOV     R2, #SzNewFloppyFs
        ADD     R1, R0, R2
        ASSERT  SzNewFloppyFs :MOD: 256 = 0
        BL      Move256n                ;(R0-R2->R0-R2)

;BUILD ROOT DIRECTORY
60
 [ Debug2
        DLINE    "build $"
 ]
        LDR     R2, [R4, #DiscRecord_Root]
        TSTS    R8, #OldMapFlag
        MOVNE   R2, R2, LSR #8

        MOV     R0, R5
        TSTS    R8, #OldDirFlag
        MOVEQ   R1, #NewDirSize
        MOVNE   R1, #OldDirSize
        BL      ZeroRam
        ADD     R6, R5, R1
        ADDNE   R7, R6, #OldDirLastMark+1       ;dir tail
        ADDEQ   R7, R6, #NewDirLastMark+1
        MOV     LR, #0
        STRB    LR, [R5]                ;zero byte corrupted by calls to MarkZone

        MOV     R0, #"$"
        STREQB  R0, [R6,#NewDirName]
        STREQB  R0, [R6,#NewDirTitle]
        STRNEB  R0, [R6,#OldDirName]
        STRNEB  R0, [R6,#OldDirTitle]
        ADDEQ   R0, R6, #NewDirParent
        ADDNE   R0, R6, #OldDirParent
        MOV     R1, R2
        Write3                                  ;(R0,R1)

        TSTS    R8, #OldMapFlag
        BL      WriteNames      ;(R5,R6,Z)

        BL      FormDirCheckByte                ;(R5-R7->LR,Z)
        STRB    LR, [R6,#DirCheckByte]

        CLRV
        Pull    "R0-R11,PC"

DoSwiDescribeDisc ROUT
;entry R0 -> disc spec
;      R1 -> 64 byte buffer to fill in with disc record
        Push    "R0-R9,LR"

        ; LookUp the disc name to get a disc address and record
        MOV     R1, R0
        MOV     R2, #MustBeDisc
        BL      FullLookUp      ;(R1,R2->R0-R6,V)
        BVS     %FT90

        ; Zero the disc record
        LDR     R0, [SP,#4]
        MOV     R1, #64
        BL      ZeroRam

        ; Get source and destination disc record addresses
        BL      DiscAddToRec    ;(R3->LR)
        LDR     R0, [SP,#4]

        ; Pick up the main body of the disc record
        ASSERT  SzDiscRecSig=8*4
        LDMIA   LR, {R2-R9}

        ; Correct the RootDir to be an external drive address
        ASSERT  DiscRecord_Root = 3*4
        BIC     R5, R5, #DiscBits
        LDRB    R1, [LR, #DiscsDrv]
        ORR     R5, R5, R1, ASL #(32-3)
        EOR     R5, R5, #bit31

        ; Plonk the contents of the disc record (corrected)
        STMIA   R0, {R2-R9}

        ; And the disc type
        LDR     R1, [LR, #DiscRecord_DiscType]
        ASSERT  DiscRecord_DiscType = SzDiscRecSig
        STR     R1, [R0, #DiscRecord_DiscType]

 [ BigDisc
        ; and the DiscSize2 field
        LDR     R1, [LR, #DiscRecord_BigMap_DiscSize2]
        STR     R1, [R0, #DiscRecord_BigMap_DiscSize2]
 ]
 [ BigShare
        LDR     R1, [LR, #DiscRecord_BigMap_ShareSize]
        STR     R1, [R0, #DiscRecord_BigMap_ShareSize]
 ]
 [ BigDir
        ;amg v3.17. Return DiscVersion and RootDirSize as per spec
        LDR     R1, [LR, #DiscRecord_BigDir_DiscVersion]
        STR     R1, [R0, #DiscRecord_BigDir_DiscVersion]
        LDR     R1, [LR, #DiscRecord_BigDir_RootDirSize]
        STR     R1, [R0, #DiscRecord_BigDir_RootDirSize]
 ]
90
        STRVS   R0, [SP]
        Pull    "R0-R9,PC"

DoSwiDiscardReadSectorsCache ROUT
        Push    "r0-r2,r6,LR"
        MOV     r0, #ModHandReason_Free
10
        MOVS    r2, r6
        Pull    "r0-r2,r6,PC",EQ
        LDR     r6, [r6, #SectorCache_Next]
        SWI     XOS_Module
        BVC     %BT10
        STR     r0, [sp]
        Pull    "r0-r2,r6,PC"

DoSwiMiscOp ROUT
        Push    "lr"
 [ BigDisc
        TEQS    R0,#MiscOp_ReadInfo
        BEQ     %FT01
 ]
        CMP     r0, #MiscOp_FirstUnknown
        MOVHS   r0, #BadParmsErr
        SETV    HS
        EORVC   r1, r1, #4
        BLVC    CheckDriveNumber
        BVS     %FT90
 [ BigDisc
01
 ]
        JumpAddress LR, %F10, forward
        ADD     PC, PC, R0, LSL #2
        NOP
05
        B       DoSwiMiscOp_Mount
        B       DoSwiMiscOp_PollChanged
        B       DoSwiMiscOp_LockDrive
        B       DoSwiMiscOp_UnlockDrive
        B       DoSwiMiscOp_PollPeriod
        B       DoSwiMiscOp_Eject
        B       DoSwiMiscOp_Info
 [ DriveStatus
        B       DoSwiMiscOp_DriveStatus
 ]
10

90
        Pull    "pc"

DoSwiMiscOp_Mount
        Push    "r0,r6,lr"
        MOV     r0, #DensityFixedDisc
        STRB    r0, [r5, #DiscRecord_Density]
        TST     r1, #4
        LDREQ   r0, WinnieProcessBlk
        MOVEQ   r6, #WinnieLock
        LDRNE   r0, FloppyProcessBlk
        MOVNE   r6, #FloppyLock
        BL      Mount
        STRVS   r0, [sp]
        Pull    "r0,r6,pc"
DoSwiMiscOp_PollChanged
        Push    "lr"
        BL      LowPollChange
        Pull    "pc"
DoSwiMiscOp_LockDrive
        Push    "lr"
        BL      LockDrive
        Pull    "pc"
DoSwiMiscOp_UnlockDrive
        Push    "lr"
        BL      UnlockDrive
        Pull    "pc"
DoSwiMiscOp_PollPeriod
        Push    "lr"
        BL      Parent_Misc
        Pull    "pc"
 [ DriveStatus
DoSwiMiscOp_DriveStatus
        Push    "lr"
        LDR     lr, FS_Flags
        TSTS    lr, #CreateFlag_DriveStatusWorks
        MOVEQ   r2, #0
        BLNE    Parent_Misc
        Pull    "pc"
 ]

; OSS Only eject if drive claims to support it and drive exists.

DoSwiMiscOp_Eject
        Push    "lr"
        LDR     lr, FS_Flags
        CMP     r1, #4
        BLO     eject_winnies

        CLRV
        TST     lr, #CreateFlag_FloppyEjects
        Pull    "pc", EQ
        LDRB    lr, Floppies
        ADD     lr, lr, #3
        B       eject_common

; simply point R0 at the appropriate information

DoSwiMiscOp_Info
        ADR     R0,FS_Flags
        MOV     pc,lr

eject_winnies
        TST     lr, #CreateFlag_FixedDiscEjects
        Pull    "pc", EQ
        LDRB    lr, Winnies
        SUB     lr, lr, #1              ; May become -1 at this point so:

eject_common
        CMP     r1, lr
        BLLE    Parent_Misc             ; Needs to be signed.
        Pull    "pc"

DoSwiFeatures
 [ NewErrors
        MOV     R0, #Feature_NewErrors
 |
        MOV     R0, #0
 ]
        ORR     R0, R0, #Feature_FloppyDiscsCanMountLikeFixed
        MOV     PC, LR

 [ VduTrap
DebugVduTrap
        Push    "R2"
        LDR     R2, [R12]
        SUB     LR, R2, R12
        CMPS    LR, #(1024-4)*K
        ADDHS   R2, R12,#4
        STRB    R0, [R2], #1
        STR     R2, [R12]
        MOV     R2, #0
        MRS     R2, CPSR
        TST     R2, #2_11100
        Pull    "R2,PC",NE
        Pull    "R2,PC",,^

DoDebugTrapVdu ROUT
        Push    "R0-R2,LR"
        MOV     R2, #16*M
        ADD     R2, R2, #4*K
        ADD     R1, R2, #4
        STR     R1, [R2]

        MOV     R0, #WrchV
        baddr   R1, DebugVduTrap
        SWI     XOS_Claim               ;(R0,R1->R0,V)
        Pull    "R0-R2,PC"

DoDebugUntrapVdu ROUT
        Push    "R0-R2,LR"
        MOV     R0, #WrchV
        baddr   R1, DebugVduTrap
        MOV     R2, #16*M
        ADD     R2, R2, #4*K
        SWI     XOS_Release             ;(R0,R1->R0,V)
        Pull    "R0-R2,PC"

 ]

; >>>>>>>>
; SwiEntry
; >>>>>>>>

SwiEntry ROUT
 [ Debug2
        DLINE   "FileCore SWI entry"
        regdump
 ]
        Push    "R0,R1,R12,LR"

        ; Check SWI range before doing other checks
        CMPS    R11,#FirstUnusedSwi
        BHS     BadSwi

        ; Check for r8-based SWIs with non-0 r8 and if so then use r8 instead of r12
        TEQ     r11, #FileCore_DiscOp - FileCoreSWI_Base
        TEQNE   r11, #FileCore_FreeSpace - FileCoreSWI_Base
        TEQNE   r11, #FileCore_FreeSpace64 - FileCoreSWI_Base
        TEQNE   r11, #FileCore_Drives - FileCoreSWI_Base
        TEQNE   r11, #FileCore_DescribeDisc - FileCoreSWI_Base
        TEQNE   r11, #FileCore_MiscOp - FileCoreSWI_Base
        TEQNE   r11, #FileCore_SectorDiscOp - FileCoreSWI_Base
        TEQNE   r11, #FileCore_DiscOp64 - FileCoreSWI_Base 
        ; Toggle Z bit to give NE if an r8-based SWI...
        TOGPSR  Z_bit, lr
        TEQNE   r8, #0
        MOVNE   r12, r8

        LDR     r0, [r12]
        TEQS    r0, #0
        MOVEQ   SB, r0
        Pull    "R0,R1",EQ
        BLNE    LightEntryFlagErr            ;leaves SB,LR stacked
        JumpAddress LR, %F10, forward
        ADD     PC, PC, R11,LSL #2
        NOP
05
        B       DoSwiDiscOp
        B       DoSwiCreate
        B       DoSwiDrives
        B       DoSwiFreeSpace

        B       DoSwiFloppyStructure
        B       DoSwiDescribeDisc
        B       DoSwiDiscardReadSectorsCache
        B       DoSwiDiscFormat
        B       DoSwiLayoutStructure
        B       DoSwiMiscOp
 [ BigDisc
        B       DoSwiSectorDiscOp
        B       DoSwiFreeSpace64
        B       DoSwiDiscOp64
        B       DoSwiFeatures
 ]
 [ VduTrap
        B       DoDebugTrapVdu
        B       DoDebugUntrapVdu
 ]

FirstUnusedSwi  * (.-%BT05)/4
10
        BLVS    FindErrBlock    ;(R0->R0,V)
        TEQS    SB, #0
        BLNE    FileCoreExit
 [ Debug2
        DLINE   "FileCore SWI exit"
        regdump
 ]
 [ Debug2
        DebugError "FileCore SWI error "
 ]
        Pull    "SB"
        SavePSR lr
        B       PullLinkKeepV

BadSwi
        Push    "r2,r4-r7"

        ; This exceedingly tedious piece of code is forced upon
        ; us as we don't always have a workspace

        ; Open the message file - return this error if this fails
        SUB     sp, sp, #16
        MOV     r0, sp
        ADRL    r1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        BVS     %FT50

        ; Lookup the error - who cares what comes back!
        ADR     r0, ErrorBlock_ModuleBadSWI
        MOV     r1, sp
        MOV     r2, #0
        ADRL    r4, Title
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup

        ; Save the lookup error and close the message file
        MOV     r1, r0
        MOV     r0, sp
        SWI     XMessageTrans_CloseFile
        MOV     r0, r1
        SETV
50
        ADD     sp, sp, #16
        Pull    "r2,r4-r7"
        STR     r0, [sp]
        Pull    "R0,R1,R12,PC"

        MakeInternatErrorBlock ModuleBadSWI,,BadSWI

SwiNames ROUT
 = "FileCore",0
 = "DiscOp",0
 = "Create",0
 = "Drives",0
 = "FreeSpace",0
 = "FloppyStructure",0
 = "DescribeDisc",0
 = "DiscardReadSectorsCache", 0
 = "DiscFormat", 0
 = "LayoutStructure", 0
 = "MiscOp", 0
 = "SectorDiscOp", 0
 = "FreeSpace64", 0
 = "DiscOp64", 0
 = "Features", 0
 [ VduTrap
 = "TrapVdu",0
 = "UntrapVdu",0
 ]
 = 0
        ALIGN

        END
