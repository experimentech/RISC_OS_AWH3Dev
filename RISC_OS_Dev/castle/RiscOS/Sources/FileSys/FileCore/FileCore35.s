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
;>FileCore35

        TTL     "FileCore35 - Free space map operations"

; ===============
; BeforeReadFsMap
; ===============

; This routine ensures that
;  1) that we have a valid free space map in RAM
;  2) that disc is locked in

; entry: R3 top 3 bits disc num
; exit:  If error V set, R0 result

BeforeReadFsMap ROUT
        Push    "R0-R2,R4-R8,LR"
 [ DebugN
        DLINE   "Enter BeforeReadFsMap(",cc
 ]
        MOVS    R7, #-1
        B       %FT05

; ================
; BeforeAlterFsMap
; ================

; This routine ensures that
;  1) we have found the drive for the relevant disc
;  2) that the disc is locked in
;  3) that we have a valid free space map in RAM
;  4) that ptrs to the disc & drv recs are in CritDiscRec & CritDrvRec

; 1), 2) ensure that
;  a) that the contents will not go uncertain causing WhatDisc to reload FS map
;  b) that the in use light remains on so the user knows not to remove disc

; entry: R3 top 3 bits disc num
; exit:  If error V set, R0 result code

BeforeAlterFsMap
        Push    "R0-R2,R4-R8,LR"
 [ DebugN
        DLINE   "Enter BeforeAlterFsMap(",cc
 ]
        MOVS    R7, #0
05
 [ DebugN
        DREG    R3,,cc
        DLINE   ")"
 ]
        ; Obtain disc and drive numbers, then check for Floppy
        MOV     R2, R3, LSR #(32-3)
        DiscRecPtr  R5, R2
        LDRB    LR, [R5, #DiscFlags]
        TST     LR, #DiscNotFileCore
        CMPNE   R7, #-1                 ; Only reject if AlterFsMap
        MOVNE   R0, #DiscNotFileCoreErr
 [ {TRUE}                               ; is this the cause of our problems?
        BEQ     %FT01
        BL      SetVOnR0
        B       %FT99
01
 |
        BNE     %FT94
 ]
        LDRB    R1, [R5, #DiscsDrv]
        LDRB    LR, [R5, #DiscFlags]
        TST     LR, #FloppyFlag
   [ DebugN
        DLINE   "Locking map into drive"
   ]
        BL      DiscWriteBehindWait     ;(R3)
        LDRB    R4, Interlocks
        ORREQ   LR, R4, #WinnieLock
        ORRNE   LR, R4, #FloppyLock
        STRB    LR, Interlocks

        LDREQ   LR, WinnieProcessBlk
        LDRNE   LR, FloppyProcessBlk

        ; If no buffers,then no write-behind and fake up disc appropriately
        LDRB    R1, MaxFileBuffers
        TEQ     R1, #0
        LDRNEB  LR, [LR, #ProcessWriteBehindDrive]
        MOVEQ   LR, #&FF

        ; If write behind disc lock this disc, else just pick up our drive
        TEQS    LR, #&FF
        LDRNEB  R1, [R5, #DiscsDrv]
        BLEQ    LockDisc        ;(R3->R0,R1,V)
        STRVSB  R4, Interlocks
        BVS     %FT99

   [ DebugN
        DREG    R2, "Disc ",cc
        DREG    R1, " now assumed locked into drive "
   ]
        ; Winnie and floppy rejoin here with:
        ; R1 = drive
        ; EQ if floppy, otherwise NE
        ASSERT  :INDEX: LockedDrive :MOD: 4 = 0
        ASSERT  LockedDisc-LockedDrive=1
        ASSERT  ModifyDisc-LockedDisc=1
        MOV     R2, R3, LSR #(32-3)     ;disc
        ORR     LR, R1, R2, LSL #8      ;OR in locked disc
        ORR     LR, LR, R2, LSL #16     ;OR in modify disc
        STR     LR, LockedDrive
        STRB    R4, Interlocks
        STR     R5, CritDiscRec

        ; No map to read if on a non-FileCore disc
        LDRB    LR, [R5, #DiscFlags]
        TST     LR, #DiscNotFileCore
        BNE     %FT90

        DrvRecPtr  R6,R1
        STR     R6, CritDrvRec
 [ DynamicMaps
        LDR     LR, [R6,#DrvsFsMapFlags]
        TSTS    LR, #BadFs
        MOVNE   R0, #BadFsMapErr
        BNE     %FT94
        LDR     R8, [R6, #DrvsFsMapAddr]
 |
        LDR     R8, [R6,#DrvsFsMap]
        TSTS    R8, #BadFs
        MOVNE   R0, #BadFsMapErr
        BNE     %FT94
 ]
        BL      TestMap         ;(R3->Z)
        BNE     %FT10
        BL      LoadNewMap      ;(R5,R6,R8->R0,V)
        BVS     %FT95
        TEQS    R7, #0
        BNE     %FT90

 [ BigMaps
        LDRB    R2, [R5, #DiscRecord_NZones]                ;IF about to alter new map
        LDRB    R0, [R5, #DiscRecord_BigMap_NZones2]
        ADD     R2, R2, R0, LSL #8
 |
        LDRB    R2, [R5, #DiscRecord_NZones]                ;IF about to alter new map
 ]
        MOV     R0, R8
        LDRB    R1, [R5, #DiscRecord_Log2SectorSize]
        MOV     LR, #1
        MOV     R1, LR, LSL R1
09
        BL      NewCheck        ;(R0,R1->Z)      THEN checksum each zone
 [ DynamicMaps
        LDRNE   LR, [R6, #DrvsFsMapFlags]
        ORRNE   LR, LR, #BadFs
        STRNE   LR, [R6,#DrvsFsMapFlags]
 |
        ORRNE   R8, R8, #BadFs
        STRNE   R8, [R6,#DrvsFsMap]
 ]
        MOVNE   R0, #BadFsMapErr
        BNE     %FT94
        SUBS    R2, R2, #1
        BNE     %BT09
        LDRB    R0, [R5, #DiscFlags]            ;AND moan if only one good copy
        ANDS    R0, R0, #AltMapFlag
        MOVNE   R0, #OneBadFsMapErr
        B       %FT94

10
 [ DynamicMaps
        LDR     LR, [R6, #DrvsFsMapFlags]
        TSTS    LR, #EmptyFs
 |
        TSTS    R8, #EmptyFs
 ]
        BNE     %FT80
        CMPS    R7, #0
        BNE     %FT90

        Push    "R3"
        MOV     R3, R5          ;disc rec
        MOV     R4, R6          ;drv rec
        BL      CheckFsMap      ;(R3,R4->R0,V)
        Pull    "R3"
 [ DynamicMaps
        LDR     LR, [R6, #DrvsFsMapFlags]
        ORRVS   LR, LR, #BadFs
        STRVS   LR, [R6,#DrvsFsMapFlags]
 |
        ORRVS   LR, R8, #BadFs
        STRVS   LR, [R6,#DrvsFsMap]
 ]
        B       %FT95

80
;need to load FS map
        MOV     R1, #DiscOp_ReadSecs
        AND     R2, R3, #DiscBits       ;old Fs maps at 0
        Push    "R3"
 [ DynamicMaps
        MOV     R3, R8
 |
        BIC     R3, R8, #HiFsBits
 ]
        MOV     R4, #SzOldFs
        BL      RetryDiscOp             ;(R1-R4->R0-R4)
        MOVVC   R3, R5                  ;disc rec
        MOVVC   R4, R6                  ;drv rec
        BLVC    CheckFsMap              ;(R3,R4->R0,V)
        Pull    "R3"
  [ DynamicMaps
        LDRVC   LR, [R6, #DrvsFsMapFlags]
        BICVC   LR, LR, #NewHiFsBits
        STRVC   LR, [R6, #DrvsFsMapFlags]
  |
        BICVC   LR, R8, #HiFsBits
        STRVC   LR, [R6,#DrvsFsMap]
  ]
        BVS     %FT95
90
        TEQS    R7, #0
        STRNEB  R7, ModifyDisc
        MOVS    R0, #0
94
        BL      SetVOnR0
95
        BLVS    UnlockMap
99
 [ DebugN
        DLINE   "leave Before(Read/Alter)FsMap", cc
        BVC     %FT01
        DREG    R0," rc=(",cc
        DLINE   ")",cc
01
        DLINE   ""
 ]
        STRVS   R0, [SP]
        Pull    "R0-R2,R4-R8,PC"


; =========
; UnlockMap
; =========

UnlockMap ROUT

        Push    "R0-R3,LR"
        SavePSR R3
        LDRB    R1, LockedDrive
 [ DebugDR
        DREG    LR,"UnlockMap called from:"
        DREG    R1,"Drive number is:"
        Push    "R0"
        ADRL    R0, Module_BaseAddr
        DREG    R0, "Module base is:"
        Pull    "R0"
 ]
        TST     R1, #bit2

        ; lock up the controller
        LDRB    R2, Interlocks
        ORREQ   LR, R2, #WinnieLock
        ORRNE   LR, R2, #FloppyLock
        STRB    LR, Interlocks

        ; Unlock locked drive if no write behind disc on that controller
        LDREQ   LR, WinnieProcessBlk
        LDRNE   LR, FloppyProcessBlk

        ; If no write behind fake write behind disc to &FF
        LDRB    R0, MaxFileBuffers
        TEQ     R0, #0
        LDRNEB  LR, [LR, #ProcessWriteBehindDrive]
        MOVEQ   LR, #&FF

        TEQ     LR, #&FF
        BICEQS  LR, R1, #7      ; check that drive valid
        BLEQ    UnlockDrive

        ; clear out the locked disc details
        ASSERT  (:INDEX: LockedDrive) :MOD: 4 = 0       ;word write to be atomic
        ASSERT  LockedDisc - LockedDrive = 1
        ASSERT  ModifyDisc - LockedDisc = 1
        MOV     R0, #-1
        STR     R0, LockedDrive

        ; unlock the controller
        STRB    R2, Interlocks          ;restore interlocks
        RestPSR R3,,f
        Pull    "R0-R3,PC"


; ===========
; EnsureNewId
; ===========

; The very first write to a floppy after it has been recognised must be to
; alter the disc id in case it is also currently known in another machine

; entry: R3 disc id in top 3 bits

; exit:  If error V set, R0 result code

EnsureNewId ROUT
 [ Debug5 :LOR: DebugE
        DREG    R3, "EnsureNewId(",cc
        DLINE   ")"
 ]
        Push    "R0-R2,R11,LR"

        CLRV

        BL      DiscAddToRec            ;(R3->LR)
        LDRB    R0, [LR,#DiscFlags]
 [ DebugL
        DREG    R0, "DiscFlags picked up are "
 ]

        ; Check if new Id needed
        TST     R0, #NeedNewIdFlag
        BEQ     %FT99

        TST     R0, #DiscNotFileCore
        BNE     %FT50

        ; Stamp FileCore disc

        LDRB    R11,LockedDrive
 [ DebugL
        DREG    R11, "LockedDrive is "
 ]
        TEQS    R11,#&FF                ;are we already in a FS map routine
        BNE     %FT10
        BL      BeforeAlterFsMap        ;(R3->R0,V)
        BVS     %FT99
10
 [ DebugL
        DLINE   "So, writing out the map.."
 ]
        BL      WriteFsMap              ;(->R0,V)
        LDRB    LR, LockedDrive
        TEQS    LR, R11
        BLNE    UnlockMap
        B       %FT99

50
        ; Stamp non-filecore disc
        MOV     r1, #FSControl_StampImage_Now
        ADD     r2, lr, #DiscRecord_DiscName
        BL      StampImage

99
        STRVS   R0, [SP]
        Pull    "R0-R2,R11,PC"


; ===============
; PrelimFreeCheck
; ===============

; checks that after deleting old obj there will be room for new obj

;entry:
; R3 = ind disc address of dir
; R4 ->entry for old obj
; R5 ->dir start
; R6 ->dir end
; R10= size required

;exit:
;IF error V set, R0 result
;      ELSE C=1 => can use old obj space for new
;      R2 = old obj ind disc add if R0=0 and C=1, else corrupt


PrelimFreeCheck ROUT
 [ Debug5 :LOR: DebugE
        DREG    R10, "PrelimFreeCheck(",cc
        DLINE   ")"
 ]
        Push    "R0,R1,R3-R4,R7-R11,LR"
        BL      ReadLen         ;(R3,R4->LR)
        MOV     R0, LR
        BL      ReadIndDiscAdd  ;(R3,R4->LR)
        MOV     R2, LR

        AND     LR, R2, #&FF
        CMPS    LR, #1                          ;C=1 <=> shared or zero length
        BHI     %FT40                           ;don't reuse shared if not at frag start
        BLCC    TestMap         ;(R3->Z)
        BNE     %FT50           ;old map
        BLCC    RoundUpAlloc    ;(R0,R3->R0)
        BLCS    RoundUpSector   ;(R0,R3->R0)
        MOV     R4, R0                          ;R4 := deletion candidate len
        MOV     R0, R10                         ;R0 := required len
        BLCC    RoundUpAlloc    ;(R0,R3->R0)
        BLCS    RoundUpSector   ;(R0,R3->R0)
      [ BigFiles
        TEQS    R0, R4          ;exactly equal test also works when RoundedTo4G
      |
        TEQS    R0, R4
      ]
  [ No32bitCode
        TEQNEP  PC, #SVC_mode   ;if not same rounded size return C=0, V=0. Preserves Z
  |
        MSRNE   CPSR_f, #0      ;if not same rounded size return C=0, V=0. Preserves Z
  ]
        Pull    "R0,R1,R3-R4,R7-R11,PC",NE
        Pull    "R0,R1,R3-R4,R7-R11,PC",CS      ;C=1,V=0 same size and shared or 0 len

        Push    "R2,R5"
        MOV     R5, #0
        BL      DefFindFileFragment     ;(R2,R5->R2,R4,R9,LR)
        Pull    "R2,R5"         ;If contiguous will reuse same space
        CMPS    R4, R0          ;C=1 <=> contiguous, (first frag >= total), V=0
        Pull    "R0,R1,R3-R4,R7-R11,PC"

40      ADDS    R0, R0, #0      ;C=0, V=0
        Pull    "R0,R1,R3-R4,R7-R11,PC"
50
        ; Old map case
        BL      RoundUpAlloc    ;(R0,R3->R0) always < 2G old map
        MOV     R4, R0          ;old disc space
        MOV     R0, R10
        BL      RoundUpAlloc    ;(R0,R3->R0) always < 2G old map
        MOV     R1, R0          ;new disc space
;if new obj <= old obj then certainly will be space for new object
        CMPS    R1, R4          ;compare new space with old disc space
        MOVLS   R0, #0
        BLS     %FT95           ;if branch C=1 <=> same, ie can reuse old space

        MOV     R0, R4          ;will total free space+old space
        BL      InitReadOldFs   ;(R3->R9-R11)
        B       %FT85
80
        ADD     LR, R8, R7
        TEQS    R2, LR          ;IF space immediately before old obj
        MOVEQ   R2, R8          ;include space in old obj

        ADDNE   LR, R2, R4      ;IF space immediately after old obj
        TEQNES  R8, LR          ;include space in old obj

        ADDEQ   R4, R4, R7

        CMPS    R1, R7          ;compare space needed with this space
        BLS     %FT90           ;found a big enough space
85
        BL      NextOldFs       ;(R10,R11->R7,R8,R10,R11,Z)
        ADDNE   R0, R0, R7
        BNE     %BT80           ;loop until no more spaces

        CMPS    R1, R4          ;If no one space alone is big enough is old obj plus
                        ;spaces either side big enough
90
        MOVLSS  R0, #0,2        ;if success also set C=0
        BLS     %FT95
        CMPS    R1, R0          ;If cant find space is it > old obj + total space
        MOVLS   R0, #CompactReqErr
        MOVHI   R0, #DiscFullErr
95
; IF V=0 THEN C=1 <=> can reuse old space
        BL      SetVOnR0
 [ Debug5 :LOR: DebugE
        DLINE   "<-PrelimFreeCheck(",cc
        BVC     %FT01
        DREG    R0,,cc
01
        DLINE   ")"
 ]
        STRVS   R0, [SP]
        Pull    "R0,R1,R3-R4,R7-R11,PC"



; ==============
; ClaimFreeSpace
; ==============

; Find and claim free space for object

; entry
; R0 old extent   RandomAccessExtend Only
; R3 top 3 bits=disc num
; R4 -> dir entry RandomAccessExtend Only
; R5 -> dir start Save/Create/Close Only
; R10 size needed ( old size for OpenOutCreate )
; R11 fsfile_Save/fsfile_Create/UnsharedCreate/CloseSmall/CloseContig/RandomAccessCreate/RandomAccessExtend

;exit:
; IF error V set, R0 result
; ELSE
;  R2  ind disc address for file
;  R10 unchanged except for RandomAccess when it is length claimed

ClaimFreeSpace ROUT
 [ Debug5
        DREG    R10, "ClaimFreeSpace(",cc
        DREG    R11, ",",cc
        DLINE   ")"
 ]
         ^ 0
ClaimExt        # 4     ;R0
                # 4     ;R1
ClaimDirEntry   # 4     ;R4
ClaimDirStart   # 4     ;R5
                # 4     ;R6
                # 4     ;R7
                # 4     ;R8
                # 4     ;R9
ClaimLength     # 4     ;R10
ClaimReason     # 4     ;R11

        Push    "R0,R1,R4-R11,LR"
        ASSERT  RandomAccessCreate>fsfile_Save
        ASSERT  RandomAccessCreate>fsfile_Create
        ASSERT  RandomAccessCreate>UnsharedCreate
        ASSERT  RandomAccessCreate>CloseSmall
        ASSERT  RandomAccessCreate>CloseContig
        ASSERT  RandomAccessExtend>RandomAccessCreate

        CMPS    R11,#RandomAccessCreate ;C=1 <=> RandomAccess
        BL      TestMap                 ;(R3->Z) preserves C
        BEQ     NewClaimFree

        MOVS    R0, R10                 ;old map - quick exit for silly claims > 2G
        MOVMI   R0, #DiscFullErr        
        BMI     %FT95

        MOV     R4, #-1                 ;initialise best fit so far to rogue
        BCC     %FT20

        BL      RoundUpAlloc            ;(R0,R3->R0) always < 2G old map
        MOV     R1, R0
        BIC     LR, R1, #&00FF
        BIC     LR, LR, #&FF00
        ADD     LR, LR, #&10000         ;next 64K boundary after file size
        STR     LR, [SP,#ClaimLength]   ;overwrite stacked R10
        BL      InitReadOldFs           ;(R3->R9-R11)
        B       %FT10
05
        CMPS    R7, R1
        BLO     %FT10           ;too small
        LDR     LR, [SP,#ClaimLength]
        SUBS    LR, R7, LR
        RSBMI   LR, LR, #0      ;difference between gap size and 64K boundary
        CMPS    LR, R4          ;IF best so far note
        MOVLO   R4, LR          ;  goodness of fit
        MOVLO   R6, R7          ;  length
        MOVLO   R2, R8          ;  disc address
        SUBLO   R0, R10,#3      ;  position in map
        ADDLO   R5, R11,#3
10
        BL      NextOldFs       ;(R10-R11->R7,R8,R10,R11,Z)
        BNE     %BT05           ;loop while more free spaces
        CMPS    R4, #-1
        BNE     %FT12           ;space found
        TEQS    R1, #0
        STREQ   R1, [SP,#ClaimLength]
        BEQ     %FT20
        BL      TotalFree       ;(R3->R0)
        CMPS    R1, R0
        MOVHI   R0, #DiscFullErr ;no free space at all
        MOVLS   R0, #CompactReqErr
        B        %FT95
12
        LDR     R1, [SP,#ClaimLength]
        CMPS    R1, R6
        SUBCC   R6, R6, R1
        MOVCS   R1, R6
        STRCS   R1, [SP,#ClaimLength]
        MOVCSS  R6, #0  ;EQ <=> using whole gap
                ;R1 is length to use, R6 length unused
        BCC     %FT92
        MOV     R10,R0          ;restore position in FS map
        MOV     R11,R5
        B       %FT87

20
        ANDEQ   R2, R3, #DiscBits ;zero length request
        BEQ     %FT95
        BL      RoundUpAlloc    ;(R0,R3->R0) always < 2G old map
        MOV     R1, R0

        MOV     R5, #0          ;will total space
        BL      InitReadOldFs   ;(R3->R9-R11)
        B       %FT90
85
        CMPS    R1, R7          ;compare space needed with this space

;if an exact match
        MOVEQ   R2, R8
        SUBEQ   R10,R10,#3
        ADDEQ   R11,R11,#3
87
        BLEQ    RemoveOldFsEntry        ;(R3,R9,R10,R11)
        MOVEQ   R0, #0
        BEQ     %FT95

        CMPLOS  R7, R4          ;IF space needed < this space < best so far
        MOVLO   R4, R7          ;best length   := this length
        MOVLO   R2, R8          ;best disc add := this disc add
        SUBLO   R0, R10,#3      ;note position in FS map
        SUBLO   R6, R7, R1      ;and remaining space
90
        BL      NextOldFs       ;(R10,R11->R7,R8,R10,R11,Z)
        ADDNE   R5, R5, R7      ;add to total space
        BNE     %BT85           ;loop until no more spaces
        CMPS    R4, #-1         ;EQ <=> no space found
92
;if inexact match reduce free space
        BEQ     %FT93
        MOV     R10,R0
        MOV     R7, R6
        ADD     R8, R2, R1
        BL      WriteOldFsEntry ;(R3,R7,R8,R10)
        MOV     R0, #0
        B       %FT95

;if failed to find space compare space needed with total space
93      CMPS    R1, R5
        MOVLS   R0, #CompactReqErr
        MOVHI   R0, #DiscFullErr
95
        BL      SetVOnR0
        STRVS   R0, [SP]
 [ Debug5
        Pull    "R0,R1,R4-R10"
        DLINE   ""
        DREG    R2, "<-ClaimFreeSpace(Ind disc:",cc
        DREG    R10, ",length:",cc
        BVC     %FT01
        DREG    R0, ",Result:",cc
01
        DLINE   ")"
        Pull    "R11,PC"
 |
        Pull    "R0,R1,R4-R11,PC"
 ]


; ================
; ReturnWholeSpace
; ================

; As ReturnSpace but new length=0

ReturnWholeSpace
        MOV     R0, #0  ;fall through into ReturnSpace

; ===========
; ReturnSpace
; ===========

; entry:
;  R0 new file length in bytes
;  R1 old file length in bytes
;  R2 Ind Disc address of file
;  R3 dir ind disc add
;  R4 -> dir entry
;  R5 -> dir start, may be fudged only used to check sharing

; exit: IF error V set, R0 result

ReturnSpace ROUT
 [ Debug5 :LOR: DebugX
        DLINE   "new len :old len :ind disc:dir     :DirEntry:DirStart enter ReturnSpace"
        DREG   R0," ",cc
        DREG   R1," ",cc
        DREG   R2," ",cc
        DREG   R3," ",cc
        DREG   R4," ",cc
        DREG   R5," "
 ]
        Push    "R0-R4,R6-R11,LR"
        BL      RoundUpAlloc    ;(R0,R3->R0)
        MOV     R6, R0
        MOV     R0, R1
        BL      RoundUpAlloc    ;(R0,R3->R0)
      [ BigFiles
        TEQ     R6, #RoundedTo4G
        MOVEQ   R7, #&FFFFFFFF
        MOVNE   R7, R6
        TEQ     R0, #RoundedTo4G
        MOVEQ   R1, #&FFFFFFFF
        MOVNE   R1, R0

        SUBS    LR, R1, R7
      |
        SUBS    R1, R0, R6      ;length of returned space
      ]
        BLS     %FT90           ;nothing to return

        BL      TestMap         ;(R3->Z)
        BNE     %FT70           ;if old map

        TSTS    R2, #&FF
        BEQ     %FT15           ;not shared obj

        TEQS    R6, #0
        BNE     %FT90           ;IF not returning whole obj then done

        BL      ReallyShared    ;(R2-R5->Z)
        BEQ     %FT90           ;IF frag shared then done
        BIC     R2, R2, #&FF
15

        BL      CritInitReadNewFs   ;(->R10,R11)
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2bpmb]
      [ BigFiles
        TEQ     R6, #RoundedTo4G
        ASSERT  RoundedTo4G = 1
        MOVEQ   R6, R6, ROR LR
        MOVNE   R6, R6, LSR LR  ;new length in map bits
        TEQ     R0, #RoundedTo4G
        MOVEQ   R7, R0, ROR LR
        MOVNE   R7, R0, LSR LR  ;old length in map bits
      |
        MOV     R6, R6, LSR LR  ;new length in map bits
        MOV     R7, R0, LSR LR  ;old length in map bits
      ]
        MOV     R9, #-1         ;don't know about pre gaps yet
20
        MOV     R1, R6
        BL      FindFragment    ;(R1,R2,R9,R10->R1,R9,R11,LR)
        SUB     R0, R1, R11     ;new length
        ADD     R1, R0, LR      ;old length = new length + length returning
        Push    "R2"
        MOV     R2, R11
        SUB     R7, R7, LR      ;decrement length left, may go -ve due to having overallocated a frag
                                ;within a zone (to prevent stranding bits < idlen at the end)
        MOV     R3, R9
        BL      ShortenFrag     ;(R0-R3,R10)
        Pull    "R2"
        CMPS    R6, R7          ;loop until whole file returned
        BLT     %BT20           ;LT rather than LO as R7 may be -ve
        BL      InvalidateFragCache
        B       %FT90
70
        ; Old map case
        ADD     R6, R2, R6      ;start of returned space
        ADD     R0, R2, R0      ;end of returned space
        BL      InitReadOldFs   ;(R3->R9-R11)
        MOV     R4, R9          ;init ptr to first space after returned space
75
        BL      NextOldFs       ;(R10,R11->R7,R8,R10,R11,Z)
        BNE     %FT80
;returned space does not join any existing spaces
        SUB     R0, R10,R9
        CMPS    R0, #EndSpaceList
        MOVHS   R0, #MapFullErr
        BHS     %FT95
        MOV     R7, R1
        MOV     R8, R6

        BL      InvalidateFsMap ;(R3)
        ADD     R0, R0, #3
        STRB    R0, [R9,#FreeEnd]

        MOV     R0, R4          ;move up disc addresses of later spaces
        ADD     R1, R4, #3
        SUBS    R2, R10,R4
        BL      BlockMove

        ADD     R0, R0, #SzOldFs/2      ;also move up later space lengths
        ADD     R1, R1, #SzOldFs/2
        BL      BlockMove

        MOV     R10,R4          ;put returned space entry in gap just made
        BL      WriteOldFsEntry ;(R3,R7,R8,R10)
        B       %FT90
80
        CMPS    R8, R6          ;IF this space is before returned space
        MOVLS   R4, R10         ;THEN set next space as first space after
        TEQS    R8, R0          ;does this space join end of returned space
        MOVEQ   R8, R6
        ADDEQ   R7, R1, R7
        BEQ     %FT85

        ADD     LR, R8, R7      ;does this space join start of returned space
        TEQS    LR, R6
        BNE     %BT75
        MOV     R6, R8          ;if so does next space join end of returned space
        ADD     R1, R7, R1
        BL      NextOldFs       ;(R10,R11->R7,R8,R10,R11,Z)
        BEQ     %FT83           ;no next space
        SUB     R10,R10,#3
        ADD     R11,R11,#3
        TEQS    R8, R0
        ADDEQ   R1, R1, R7
        BLEQ    RemoveOldFsEntry        ;(R3,R9-R11)
83
        MOV     R8, R6
        MOV     R7, R1
85
        SUB     R10,R10,#3
        BL      WriteOldFsEntry ;(R3,R7,R8,R10)
90
        MOV     R0, #0
95
        BL      SetVOnR0
 [ Debug5 :LOR: DebugX
        BVC     %FT96
        DREG   R0," ",cc
96
        DLINE "leave ReturnSpace"
 ]
        STRVS   R0, [SP]
        Pull    "R0-R4,R6-R11,PC"


; ==================
; RemoveDirEntryOnly
; ==================

; as RemoveDirEntry but dont return space, always succeeds

RemoveDirEntryOnly ROUT
 [ Debug5
        DREG    R3, "", cc
        DREG    R4, " ", cc
        DREG    R5, " ", cc
        DREG    R6, " ", cc
        DLINE   "enter RemoveDirEntryOnly"
 ]
        Push    "R0-R2,LR"
        B       %FT10

; ==============
; RemoveDirEntry
; ==============

; Remove a directory entry, and the space associated with it. Used
; for example when deleting a file (renaming across directories would use
; function RemoveDirEntryOnly to keep the data in tact).

; entry:
;  R3 ind disc address of dir
;  R4 -> dir entry
;  R5 -> dir start
;  R6 -> dir end

; exit: IF error V set, R0 result

RemoveDirEntry
 [ Debug5
        DREG    R4, " ",cc
        DLINE   "enter RemoveDirEntry"
 ]
        Push    "R0-R2,LR"
        ;return space to map
        BL      ReadIndDiscAdd          ;(R3,R4->LR)
        MOV     R1, LR
        BL      MeasureFileAllocSize_GotMap ;(R1,R3,R4->R0)
      [ BigFiles
        TEQ     R0, #RoundedTo4G
        MOVEQ   R1, #&FFFFFFFF          ;ReturnWholeSpace rounds up internally anyway
        MOVNE   R1, R0
      |
        MOV     R1, R0
      ]
        BL      ReadIndDiscAdd          ;(R3,R4->LR)
        MOV     R2, LR
        BL      ReturnWholeSpace        ;(R1-R5->R0)
        BVS     %FT95
10
 [ BigDir
        BL      TestBigDir
        BNE     %FT90
        Push    "R7"

        BL      InvalidateBufDir
        ; if it's a big dir, we do two moves - first before bit, then the after

 [ DebugX
        LDR     LR, [R5, #BigDirEntries]
        DREG    LR, "entries:"
 ]

        BL      GetBigDirName           ; (R4,R5->LR)
        LDR     R7, [R4, #BigDirObNameLen]      ; length of name
        ADD     R7, R7, LR
        ADD     R7, R7, #4
        BIC     R7, R7, #3              ; bit after name
        ADD     R0, R4, #BigDirEntrySize; source
        MOV     R1, R4                  ;
        SUBS    R2, LR, R0              ; size of move

 [ DebugX
        DLINE   "first move:"
        DREG    R0, "source:"
        DREG    R1, "  dest:"
        DREG    R2, "  size:"
 ]
        BLNE    BlockMove               ; moved down first part

        MOV     R0, R7                  ; source of move
        ADD     R1, R1, R2              ; dest of move
        LDR     LR, [R5, #BigDirEntries]
        LDR     R2, [R5, #BigDirNamesSize]
        ADD     R2, R2, #BigDirHeaderSize

        ASSERT  BigDirEntrySize=28
        RSB     LR, LR, LR, LSL #3
        ADD     R2, R2, LR, LSL #2

        LDR     LR, [R5, #BigDirNameLen]
        ADD     R2, R2, LR
        ADD     R2, R2, #4
        BIC     R2, R2, #3
        ADD     R2, R2, R5

        SUBS    R2, R2, R0              ; now length

 [ DebugX
        DLINE   "second move:"
        DREG    R0, "source:"
        DREG    R1, "  dest:"
        DREG    R2, "  size:"
 ]
        BLNE    BlockMove

        LDR     LR, [R5, #BigDirEntries]
        SUB     LR, LR, #1
        STR     LR, [R5, #BigDirEntries]

 [ DebugX
        DREG    LR, "Entries now:"
 ]

        LDR     LR, [R5, #BigDirNamesSize]
        SUB     R1, R0, R1
        SUB     R1, R1, #BigDirEntrySize
        SUB     LR, LR, R1
        STR     LR, [R5, #BigDirNamesSize]

  [ DebugX
        DREG    R1, "names reduced by:"
  ]
        Push    "R4"
12
        BL      BigDirFinished
        BEQ     %FT15
        LDR     LR, [R4, #BigDirObNamePtr]
        SUB     LR, LR, R1
        STR     LR, [R4, #BigDirObNamePtr]
        ADD     R4, R4, #BigDirEntrySize
        B       %BT12

15
        Pull    "R4"
20
        Pull    "R7"
        MOV     R0, #0
        B       %FT95
90
 ]
        ; not a big directory - move down following entries
        SUB     R2, R4, R5
        BL      InvalidateBufDir
        BL      TestDir        ;(R3->LR,Z)
        RSBEQ   R2, R2, #(NewDirEntrySz*(NewDirEntries-1)+DirFirstEntry+1) :AND: &FF00
        ADDEQ   R2, R2, #(NewDirEntrySz*(NewDirEntries-1)+DirFirstEntry+1) :AND: &FF
        RSBNE   R2, R2, #(OldDirEntrySz*(OldDirEntries-1)+DirFirstEntry+1) :AND: &FF00
        ADDNE   R2, R2, #(OldDirEntrySz*(OldDirEntries-1)+DirFirstEntry+1) :AND: &FF
 [ NewDirEntrySz=OldDirEntrySz
        ADD     R0, R4, #NewDirEntrySz
 |
        ADDEQ   R0, R4, #NewDirEntrySz
        ADDNE   R0, R4, #OldDirEntrySz
 ]
        MOV     R1, R4
        BL      BlockMove
        MOV     R0, #0
95
        BL      SetVOnR0
99
        STRVS   R0, [SP]
 [ Debug5
        BVC     %FT01
        DREG    R0, " ",cc
01
        DLINE   "leave RemoveDirEntry(Only)"
 ]
        Pull    "R0-R2,PC"


; =========
; TotalFree
; =========

; Find total free space on disc

; entry:  R3 top 3 bits disc num

; exit:   R0=total free

TotalFree ROUT
        Push    "R7-R11,LR"
        MOV     R0,#0
        BL      InitReadFs              ;(R3->R9-R11)
10
        BL      NextFs                  ;(R3,R9-R11->R7-R11,Z)
        ADDNE   R0, R0, R7
        BNE     %BT10
        Pull    "R7-R11,PC"


; ===============
; SizeLessDefects
; ===============

; entry R3 top 3 bits disc bits

; exit LR disc size in bytes excluding defects

SizeLessDefects ROUT
        Push    "R0-R2,R6,LR"
        SavePSR R6

        ; Get the disc size
        MOV     R2, R3, LSR #(32-3)       ;disc
 [ DebugL
        DREG    R2, "SizeLessDefects(",cc
 ]
        DiscRecPtr  R1, R2
        LDR     LR, [R1, #DiscRecord_DiscSize]

        ; skip defect correction on NewMap discs
        LDRB    R0, [R1, #DiscFlags]
        TST     R0, #OldMapFlag
        BEQ     %FT20

        ; Get the drive
        LDRB    R0, [R1, #DiscsDrv]

        ; Don't correct for defects on DefectList-less discs
        DrvRecPtr  R2, R0
        LDRB    R2, [R2, #DrvFlags]
        TST     R2, #HasDefectList
        BEQ     %FT20

        ; Find the defect list and remove defects*1<<Log2SectorSize bytes from disc size
        LDR     R2, DefectSpace
        ADD     R2, SB, R2
        ASSERT  SzDefectList = (1 :SHL: 9)
        ADD     R2, R2, R0, LSL #9
        LDRB    R1, [R1, #DiscRecord_Log2SectorSize]
        MOV     R0, #1
        MOV     R1, R0, LSL R1
10
        LDR     R0, [R2],#4
        RSBS    R0, R0, #1 :SHL: 29
        SUBHI   LR, LR, R1
        BHI     %BT10
20
 [ DebugL
        MOV     R0, LR
        DREG    R0, ")="
 ]
        RestPSR R6,,f
        Pull    "R0-R2,R6,PC"

 [ BigDisc

; =================
; SizeLessDefects64
; =================

; entry R3 top 3 bits disc bits

; exit LR bottom 32 bits disc size in bytes
;      R0 top 32 bits disc size in bytes

SizeLessDefects64 ROUT
        Push    "R1-R2,R6,LR"
        SavePSR R6

        ; Get the disc size
        MOV     R2, R3, LSR #(32-3)       ;disc
 [ DebugL
        DREG    R2, "SizeLessDefects64(",cc
 ]
        DiscRecPtr  R1, R2
        LDR     LR, [R1, #DiscRecord_DiscSize]

        ; skip defect correction on NewMap discs
        LDRB    R0, [R1, #DiscFlags]
        TST     R0, #OldMapFlag
        LDREQ   R0, [R1, #DiscRecord_BigMap_DiscSize2]
        BEQ     %FT20

        ; Get the drive
        LDRB    R0, [R1, #DiscsDrv]

        ; Don't correct for defects on DefectList-less discs
        DrvRecPtr  R2, R0
        LDRB    R2, [R2, #DrvFlags]
        TST     R2, #HasDefectList
        MOVEQ   R0, #0
        BEQ     %FT20

        ; Find the defect list and remove defects*1<<Log2SectorSize bytes from disc size
        LDR     R2, DefectSpace
        ADD     R2, SB, R2
        ASSERT  SzDefectList = (1 :SHL: 9)
        ADD     R2, R2, R0, LSL #9
        LDRB    R1, [R1, #DiscRecord_Log2SectorSize]
        MOV     R0, #1
        MOV     R1, R0, LSL R1
10
        LDR     R0, [R2],#4
        RSBS    R0, R0, #1 :SHL: 29
        SUBHI   LR, LR, R1
        BHI     %BT10
        MOV     R0,#0
20
 [ DebugL
        DREG    R0, ")=", cc
        DREG    LR
 ]
        RestPSR R6,,f
        Pull    "R1-R2,R6,PC"

 ]

; =============
; InitReadOldFs
; =============

; prepare to read entries from old format FS map, ( assumes already in RAM )

; entry: R3 top 3 bits disc id

; exit:  R9,R10 -> first free space disc address entry
;        R11    =  number of free spaces * 3, MAY BE ZERO

InitReadOldFs
        MOV     R9, R3, LSR #(32-3)
        DiscRecPtr  R9,R9
        LDRB    R9, [R9,#DiscsDrv]
        DrvRecPtr  R9,R9
 [ DynamicMaps
        LDR     R9, [R9, #DrvsFsMapAddr]
 |
        LDR     R9, [R9,#DrvsFsMap]
        BIC     R9, R9, #HiFsBits ;for multiple map ops, eg extend by move
 ]
        MOV     R10,R9
        LDRB    R11,[R9,#FreeEnd]
 [ Debug5
        DREG    R3
        DREG    R9
        DREG    R10
        DREG    R11
        mess    ,"InitReadOldFs",NL
 ]
        MOV     PC,LR           ; Flags preserved


; =========
; NextOldFs
; =========

; read next free space from old format fs map

; entry:
;  R3  -> top 3 bits disc id
;  R10 -> free space disc address entry
;  R11 =  # free spaces left * 3

; exit:
;  IF no more spaces Z=1
;  ELSE
;   Z=0
;   R7 = length of free space
;   R8 = disc address of next space
;   R10  inc 3
;   R11  dec 3

NextOldFs
        Push    "R0,LR"
 [ Debug5
        DREG    R3
        DREG    R10
        DREG    R11
        mess    ,"enter NextOldFs",NL
 ]
        TEQS    R11,#0
        MOVNE   R0, R10
        Read3   NE
        ANDNE   R0, R3, #2_111 :SHL: (32-3)
        ORRNE   R8, R0, LR, LSL #8
        ADDNE   R0, R10,#SzOldFs / 2
        Read3   NE
        MOVNE   R7, LR, LSL #8
        ADDNE   R10,R10,#3
        SUBNE   R11,R11,#3
 [ Debug5
        DREG    R7, NE
        DREG    R8, NE
        mess    NE, "Next free space",NL
        mess    EQ, "No more free spaces",NL
 ]
        Pull    "R0,PC"


; ================
; RemoveOldFsEntry
; ================

; entry:
;  R3  -> top 3 bits disc id
;  R9  -> fs map
;  R10 -> free space disc address entry
;  R11 =  # free spaces after and including this entry

RemoveOldFsEntry
 [ Debug5
        mess    ,"RemoveOldFsEntry",NL
 ]
        Push    "R0-R2,R4,LR"
        SavePSR R4
        BL      InvalidateFsMap         ;(R3)
;move down rest of free space disc address entries
        ADD     R0, R10,#3
        MOV     R1, R10
        SUB     R2, R11,#3
        BL      BlockMove
;move down rest of free space length entries
        ADD     R1, R10,#SzOldFs/2
        ADD     R0, R1, #3
        BL      BlockMove
;update end of free space ptr
        LDRB    R2, [R9,#FreeEnd]
        SUBS    R2, R2, #3
        STRB    R2, [R9,#FreeEnd]
        RestPSR R4,,f
        Pull    "R0-R2,R4,PC"


; ===============
; WriteOldFsEntry
; ===============

; this does not create a new entry, just overwrites previous entry

; entry:
;  R3  top 3 bits disc id
;  R7  length
;  R8  disc address
;  R10 -> entry

WriteOldFsEntry
 [ Debug5
        DREG    R7
        DREG    R8
        mess    ,"Write old free space",NL
 ]
        Push    "R0,R1,LR"
        BL      InvalidateFsMap                 ;(R3)
        MOV     R0,R10
        BIC     R1,R8,#DiscBits
        MOV     R1,R1,LSR #8
        Write3
        ADD     R0,R10,#SzOldFs/2
 [ Dev
        TSTS    R7,#DiscBits
        mess    NE,"writing silly length to map",NL
 ]
        MOV     R1,R7,LSR #8
        Write3
        Pull    "R0,R1,PC"


; ===================
; UpdateFsMapCheckSum
; ===================

UpdateFsMapCheckSum
        Push    "R0-R2,LR"
        LDR     LR, CritDrvRec
 [ DynamicMaps
        LDR     R0, [LR,#DrvsFsMapAddr]
 |
        LDR     R0, [LR,#DrvsFsMap]
        BIC     R0, R0, #HiFsBits
 ]
        MOV     R1, #SzOldFs/2
        BL      CheckSum
        STRB    R2, [R0,#Check0]
        ADD     R0, R0, #SzOldFs/2
        BL      CheckSum
        ASSERT  Check1-Check0=SzOldFs/2
        STRB    R2, [R0,#Check0]
        Pull    "R0-R2,PC"


; ==========
; WriteFsMap
; ==========

WriteFsMap ROUT
 [ Debug5
        DLINE   "WriteFsMap"
 ]
        Push    "R0-R11,LR"
        BL      DisableBreak
        BL      CriticalWriteFsMap
        BL      RestoreBreak
        STRVS   R0,[SP]
        Pull    "R0-R11,PC"


; =================
; WriteDirThenFsMap
; =================

WriteDirThenFsMap ROUT
 [ Debug5
        DLINE   "WriteDirThenFsMap"
 ]
        Push    "R0-R11,LR"
        BL      DisableBreak
        BL      CriticalWriteDirThenFsMap
        BL      RestoreBreak
        STRVS   R0,[SP]
        Pull    "R0-R11,PC"


; =================
; WriteFsMapThenDir
; =================

WriteFsMapThenDir ROUT
 [ Debug5 ;:LOR: DebugXr
        DLINE   "WriteFsMapThenDir"
 ]
        Push    "R0-R11,LR"
        BL      DisableBreak
        BL      CriticalWriteFsMapThenDir
        BL      RestoreBreak
        STRVS   R0,[SP]
 [ DebugXr :LAND: {FALSE}
        DebugError "Error in WriteFsMapThenDir "
 ]
        Pull    "R0-R11,PC"

 [ WriteCacheDir
; ======================
; WriteFsMapThenMaybeDir
; ======================

WriteFsMapThenMaybeDir ROUT
 [ Debug5
        DLINE   "WriteFsMapThenMaybeDir"
 ]
        Push    "R0-R11,LR"
        BL      DisableBreak
        BL      CriticalWriteFsMapThenMaybeDir
        BL      RestoreBreak
        STRVS   R0,[SP]
        Pull    "R0-R11,PC"
 ]

; ===============
; InvalidateFsMap
; ===============

; Entry: R3 top 3 bits disc id

InvalidateFsMap
        Push    "R3,LR"
 [ Debug5
        DREG    R3
        mess    ,InvalidateFsMap,NL
 ]
        BL      DiscAddToRec    ;(R3->LR)
        LDRB    LR,[LR,#DiscsDrv]
        DrvRecPtr  LR,LR
 [ DynamicMaps
        LDR     R3,[LR,#DrvsFsMapFlags]
        ORR     R3,R3,#EmptyFs
        STR     R3,[LR,#DrvsFsMapFlags]
 |
        LDR     R3,[LR,#DrvsFsMap]
        ORR     R3,R3,#EmptyFs
        STR     R3,[LR,#DrvsFsMap]
 ]
        Pull    "R3,PC"                 ; Flags Preserved


; ============
; MakeDirEntry
; ============

; Fill in details of file in RAM copy of dir

; entry:
;  R0  atts
;  R1  -> name
;  R2  ind disc add of file
;  R3  ind disc add of dir
;  R4  -> entry
;  R5  -> dir start
;  R7  load address
;  R8  exec address
;  R10 length

MakeDirEntry
        Push    "R0,R9,R11,LR"
        SavePSR R9
 [ BigDir
        BL      TestBigDir
        BEQ     %FT50
 ]
        LDRB    R11,[R4]
        BL      WriteName       ;(R1,R4)
        BL      IncObjSeqNum    ;(R3-R5)
        BL      SetIntAtts      ;(R0,R3,R4)
 [ NewDirEntrySz=OldDirEntrySz
        ADD     R0, R4, #NewDirEntrySz
 |
        BL      TestDir         ;(R3->LR,Z)
        ADDEQ   R0, R4, #NewDirEntrySz
        ADDNE   R0, R4, #OldDirEntrySz
 ]
        TEQS    R11,#0          ;if this was last entry
        MOVEQ   LR, #0          ;make next entry last entry
        STREQB  LR, [R0]
        MOV     R0, R2
        BL      WriteIndDiscAdd ;(R0,R3,R4)
        MOV     R0, R7
        BL      WriteLoad       ;(R0,R3,R4)
        MOV     R0, R8
        BL      WriteExec       ;(R0,R4)
        MOV     R0, R10
        BL      WriteLen        ;(R0,R3,R4)

        RestPSR R9,,f
        Pull    "R0,R9,R11,PC"

 [ BigDir
50
        BL      WriteBigName    ;(R1,R4,R5)
        BL      SetIntAtts      ;(R0,R3,R4)
        MOV     R0, R2
        BL      WriteIndDiscAdd ;(R0,R3,R4)
        MOV     R0, R7
        BL      WriteLoad       ;(R0,R3,R4)
        MOV     R0, R8
        BL      WriteExec       ;(R0,R3,R4)
        MOV     R0, R10
        BL      WriteLen        ;(R0,R3,R4)
        RestPSR R9,,f
        Pull    "R0,R9,R11,PC"
 ]

; =========
; WriteName
; =========

; copy file name string to dir entry

; entry:
;  R1 -> name
;  R4 -> entry

WriteName ROUT
        Push    "R0-R2,R4,R5,LR"
        SavePSR R5
        ASSERT  DirObName=0
        MOV     R2, #NameLen
10
        BL      ThisChar        ;(R1->R0,C)
        ADD     R1, R1, #1
        MOVCS   R0, #CR         ;if terminator
        STRB    R0, [R4],#1
        BCS     %FT90
        SUBS    R2, R2, #1
        BNE     %BT10
90
        RestPSR R5,,f
        Pull    "R0-R2,R4,R5,PC"


; ================
; InvalidateBufDir
; ================

InvalidateBufDir
        Push    "R0,LR"
        SavePSR R0
        LDR     LR, BufDir
        CMPS    LR, #-1
        STRNE   LR, CritBufDir
        MOV     LR, #-1
        STRNE   LR, BufDir
        RestPSR R0,,f
        Pull    "R0,PC"


; ==============
; ValidateBufDir
; ==============

ValidateBufDir
        Push    "LR"
 [ Debug6
        DLINE    "ValidateBufDir"
 ]
        LDR     LR, CritBufDir
        CMPS    LR, #-1
        STRNE   LR, BufDir
        MOV     LR, #-1
        STRNE   LR, CritBufDir

 [ WriteCacheDir
        MOV     LR, #0
        STR     LR, BufDirDirty
 ]
        ADDS    R0,R0,#0                ; clear V
        Pull    "PC"


; ===================
; IdentifyCurrentDisc
; ===================

;exit NZC preserved
; IF error V set, R0 result
; R3 top 3 bits disc num

; Method:
; Find out from FileSwitch the full path of '$' which will be CSD-based

CSD_Path        DCB     "$",0
        ALIGN

IdentifyCurrentDisc ROUT
        Push    "R0-R7,LR"
        SavePSR R7

        MOV     r0, #FSControl_CanonicalisePath
        ADR     r1, CSD_Path
        MOV     r2, #0
        MOV     r3, #0
        MOV     r4, #0
        MOV     r5, #0
        BL      DoXOS_FSControl
        BVS     %FT90

        ; Round overflow up to whole word
        RSB     r5, r5, #3 + 1          ; + 1 for the terminator
        BIC     r5, r5, #3

 [ DebugQ
        DREG    r5, "Buffer space needed:"
 ]

        ; Get the buffer space off the stack
        MOV     r6, r5
        SUB     sp, sp, r5

        MOV     r2, sp

        BL      DoXOS_FSControl
        BVS     %FT85

        ; syntax *is* <fs>[#<special>]::<disc>.<other stuff>
        MOV     r0, #":"
        MOV     r1, sp
 [ DebugQ
        DSTRING r1,"String returned by FileSwitch is "
 ]
10
        LDRB    r14, [r1], #1
        TEQ     r14, #":"
        BNE     %BT10

        ; Skip the second :
        ADD     r1, r1, #1
        MOV     r2, r1

        ; Terminate at the next .
20
        LDRB    r14, [r1, #1]!
        TEQ     r14, #"."
        BNE     %BT20

        MOV     r14, #0
        STRB    r14, [r1]

        MOV     r1, r2

 [ DebugQ
        DSTRING r1, "Disc name used is "
 ]
        MOV     r2, #0
        BL      FindDiscByName
        ADD     sp, sp, r6
        STRVC   r3, [sp, #3*4]
        B       %FT90

85
        ADD     sp, sp, r6

90
        STRVS   R0, [SP]
        MOV     lr, r7
        Pull    "r0-r7"
        B       PullLinkKeepV

        LTORG

; ==========================
; IdentifyDiscInCurrentDrive
; ==========================

;exit NZC preserved
; IF error V set, R0 result
; R3 top 3 bits disc num

; Method:
; Find out from FileSwitch the full path of the CSD

IdentifyDiscInCurrentDrive ROUT
        Push    "r0-r2, r4, lr"
        SavePSR r4
        LDRB    r1, Drive
        BL      WhatDisc        ;(r1->r0-r3,V)
        MOVVC   r3, r2, LSL #(32-3)
        STRVS   r0, [sp, #0*4]
        MOV     lr, r4
        Pull    "r0-r2, r4"
        B       PullLinkKeepV

        LTORG
        END
