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
; >FileCore33
;
; 15 May 1997 SBP: Added Free versions of all the RdLenBits and WrLenBits etc functions.  Modified UnusedId,
;                  NextFree, ChainClaim, ShortenFrag, InitZoneObj.
;
; 19-Sep-1994 SBP: Added BigDisc support to FindFileFragment, MapDiscAdd, MapPtrToDiscAdd, DiscAddToMapPtr
;

        TTL     "New map small routines"

; ===================
; DefFindFileFragment
; ===================

DefFindFileFragment
        MOV     R9, #-1  ;fall through to FindFileFragment

; ================
; FindFileFragment
; ================

;entry
; R2 ind disc address of object start
; R5 offset from start of linked object
; R9 map ptr to a gap or -1

;exit
; R2 file offset disc add
; R4 length left in fragment
; R9 map ptr to gap before frag
; LR fragment start disc add

FindFileFragment
        Push    "R0,R1,R3,R5,R6,R10,R11,LR"
 [ DebugE
        DREG    R2, "FindFileFragment(file add:",cc
        DREG    R5, ", offset:",cc
        DREG    R9, ", gap ptr:",cc
        DLINE   ")"
 ]
        MOV     R3, R2
        BL      InitReadNewFs   ;(R3->R10,R11,LR)

; we move the sector offset from the ind disc addr to file offset - this
; makes finding the fragment simpler


        ANDS    R0, R2, #&FF    ;add any sector offset within frag
        BIC     R2, R2, #&FF
        SUBNE   R0, R0, #1

 [ BigDisc
  [ BigShare
        LDRB    R6, [LR,#DiscRecord_BigMap_ShareSize]     ; get sharing unit
        MOV     R0, R0, LSL R6          ; and multiply sharing stuff up
  ]
        LDRB    R6, [LR,#DiscRecord_Log2SectorSize]
        ADD     R5, R5, R0, LSL R6

        LDRB    R0, [LR,#DiscRecord_Log2bpmb]   ;bytes per map bit
        MOV     R1, R5, LSR R0          ;split offset into multiples of bytes per map bit
        SUB     R5, R5, R1, LSL R0      ;and spare bytes
        BL      FindFragment            ;(R1,R2,R9,R10->R1,R9,R11,LR)

        RSB     R4, R5, LR, LSL R0      ;remaining bytes in fragment
        BL      MapPtrToDiscAdd         ;(R3,R10,R11->R0)
        Push    "R0"                    ;frag start disc address

        MOV     R11,R1
        BL      MapPtrToDiscAdd         ;(R3,R10,R11->R0)
        ADD     R2, R0, R5, LSR R6      ;offset disc address
        Pull    "LR"
 |
        LDRNEB  R1, [LR,#DiscRecord_Log2SectorSize]
        ADDNE   R5, R5, R0, LSL R1

        LDRB    R0, [LR,#DiscRecord_Log2bpmb]   ;bytes per map bit
        MOV     R1, R5, LSR R0          ;split offset into multiples of bytes per map bit
        SUB     R5, R5, R1, LSL R0      ;and spare bytes
        BL      FindFragment            ;(R1,R2,R9,R10->R1,R9,R11,LR)

        RSB     R4, R5, LR, LSL R0      ;remaining bytes in fragment
        BL      MapPtrToDiscAdd         ;(R3,R10,R11->R0)
        Push    "R0"                    ;frag start disc address

        MOV     R11,R1
        BL      MapPtrToDiscAdd         ;(R3,R10,R11->R0)
        ADD     R2, R0, R5              ;offset disc address
        Pull    "LR"

 ]

 [ DebugE
        Push    "R0"
        DREG    R2, "<-FindFileFragment(file add:",cc
        DREG    R4, ", len left:",cc
        DREG    R9, ", gap:",cc
        MOV     R0, LR
        DREG    R0, ", frag:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,R1,R3,R5,R6,R10,R11,PC"


; ===============
; DefFindFragment
; ===============

DefFindFragment
        MOV     R9, #-1         ;fall through to FindFragment

; ============
; FindFragment
; ============

;entry
; R1  offset from start of linked object in map bits
; R2  ind disc address of frag start, bits 0-7 clear
; R9  map ptr to gap, may shortcut search for predecessor gap
; R10 -> map start

;exit
; R1  map ptr to desired offset
; R9  predecessor gap for frag
; R11 map ptr to start of fragment containing offset
; LR  length left in fragment in map bits

FindFragment ROUT
        Push    "R0,R3-R8,LR"
 [ DebugE
        DREG    R1, "FindFragment(offset:",cc
        DREG    R2, ", file add:",cc
        DREG    R9, ", gap:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        MOV     R3, R9
        sbaddr  R0, FragCache
        LDMIA   R0, {R4-R9}
 [ DebugE
        DREG    R4, "old frag - file:",cc
        DREG    R5, ", map:",cc
        DREG    R6, ", disc:"
        DREG    R7, "last frag - file:",cc
        DREG    R8, ", map:",cc
        DREG    R9, ", disc:"
 ]
        CMPS    R1, R7          ;IF  file offset >= last file offset
        CMPHS   R2, R9          ;AND ind disc add = last ind disc add
        MOVEQ   R4, R7          ;start from last entry
        MOVEQ   R5, R8
 [ DebugE
        BNE     %FT01
        DLINE   "start from last frag"
01
 ]
        BEQ     %FT05
        STMIA   R0!,{R7-R9}     ;old last := last, for next time
        CMPS    R1, R4          ;IF  file offset >= old last file offset
        CMPHS   R2, R6          ;AND ind disc add = old last ind disc add
                        ;start from old last entry
 [ DebugE
        BNE     %FT01
        DLINE   "start from old frag"
01
 ]
05
        MOVNE   R4, #0  ;EQ <=> R4 is file ptr, R5 is map ptr to start from

        BIC     R6, R2, #DiscBits
        MOV     R6, R6, LSR #8  ;id
        LDREQB  R0, [R10,#ZoneHead+DiscRecord_Log2SectorSize]  ;find zone to start at
        MOVEQ   R0, R5, LSR R0
        MOVEQ   R0, R0, LSR #3
        MOVNE   R0, R2
        BLNE    IndDiscAddToZone;(R0,R10->R0)
10
        BL      InitZoneObj     ;(R0,R10->R8,R9,R11,LR)
        Push    "LR"
        MOVNE   R3, R8
        BNE     %FT20           ;if start from beginning of zone

        CMPS    R8, R3          ;if dummy link gap < pre gap < frag map ptr
        CMPLOS  R3, R5          ;start gap search from pre gap
        MOVHS   R3, R8

        MOV     R11,R3
15
 [ BigMaps
        BL      FreeRdLinkBits  ;(R10,R11->R8,Z)
 |
        BL      RdLinkBits      ;(R10,R11->R8,Z)
 ]
        ADD     R11,R11,R8
        CMPS    R11,R3          ;WHILE more gaps
        CMPHIS  R5, R11         ;AND fragment after gap
        MOVHI   R3, R11         ;move onto next gap
        BHI     %BT15

        MOV     R9, R11
        MOV     R11,R5

20
        Pull    "R5"
25
 [ BigMaps
        TEQS    R11, R9         ; if gap
        BNE     %FT27

 ; gap
        BL      FreeRdLenLinkBits ; read free link
        MOV     r3,r9           ;  and just update gap before frag
        ADD     r9,r9,r8        ;  and gap after frag
        B       %FT30           ;
27
 ; not gap
        BL      FragRdLenLinkBits ; get the length
 |
        BL      RdLenLinkBits   ;(R10,R11->R7,R8)
        TEQS    R11,R9          ;if gap
        MOVEQ   R3, R9          ; just update gap before frag
        ADDEQ   R9, R9, R8      ; and gap after frag
        BEQ     %FT30
 ]
        TEQS    R8, R6
        BEQ     %FT40           ;if part of this file

30
        ADD     R11,R11,R7
        CMPS    R11,R5
        BLO     %BT25           ;loop while more objects in zone

        ADD     R0, R0, #1      ;otherwise move onto next zone
 [ BigMaps
        LDRB    LR, [R10,#ZoneHead+DiscRecord_NZones]
        LDRB    R11, [R10,#ZoneHead+DiscRecord_BigMap_NZones2]
        ADD     LR, LR, R11, LSL #8     ; R11 returned by InitZoneObj so is free for use here
 |
        LDRB    LR, [R10,#ZoneHead+DiscRecord_NZones]
 ]
        TEQS    R0, LR
        MOVEQ   R0, #0
        TEQS    PC, #0          ;set NE to start from beginning
        B       %BT10

40
        ADD     LR, R4, R7      ;file ptr of end of this fragment
        SUBS    LR, LR, R1      ;map bits after offset in this fragment
        ADDLS   R4, R4, R7      ;add frag len to file offset
        BLS     %BT30
                        ;HI <=> found fragment
        sbaddr  R7, LastFilePtr
        ASSERT  LastMapPtr = LastFilePtr + 4
        ASSERT  LastIndDiscAdd = LastMapPtr + 4
        MOV     R5, R11
        MOV     R6, R2
        STMIA   R7, {R4-R6}     ;must be atomic
        SUB     R1, R1, R4      ;convert offset in file
        ADD     R1, R1, R11     ;to offset in map
        MOV     R9, R3
 [ DebugE
        Push    "R0"
        DREG    R1, "<-FindFileFragment(offset:",cc
        DREG    R9, ", gap:",cc
        DREG    R11, ", frag:",cc
        MOV     R0, LR
        DREG    R0, ", len:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,R3-R8,PC"

; ==========
; LoadNewMap
; ==========

;assumes BadFsMapBit not set

;entry
; R5 -> disc rec
; R6 -> drive rec
; R8 -> map buffer

;exit R0,V

LoadNewMap ROUT
        Push    "R0-R2,R4,R7-R10,LR"
 [ DebugE
        DREG    R5, "LoadNewMap(disc rec:",cc
        DREG    R6, ", drive rec:",cc
        DREG    R8, ", map:",cc
        DLINE   ")"
 ]
 [ BigMaps
        LDRB    R9, [R5, #DiscRecord_NZones]
        LDRB    R7, [R5, #DiscRecord_BigMap_NZones2]
        ADD     R9, R9, R7, LSL #8
 |
        LDRB    R9, [R5,#DiscRecord_NZones]
 ]
        LDRB    R7, [R5,#DiscRecord_Log2SectorSize]
        ADD     R10,R8, R9, LSL R7      ;-> zone flags
05
        MOV     R1, #0                  ;loop to load invalid zones
10
        LDRB    LR, [R10,R1]
        TSTS    LR, #ZoneValid
        ADD     R2, R1, #1
        BNE     %FT30
15
        CMPS    R2, R9
        BHS     %FT20
        LDRB    LR, [R10,R2]
        TSTS    LR, #ZoneValid
        ADDEQ   R2, R2, #1
        BEQ     %BT15
20

        SUB     R4, R2, R1              ;zones to read in
        Push    "R1-R4"
        MOV     R4, R4, LSL R7          ;bytes to read in
        BL      MapDiscAdd              ;(R5,R7,R9->R2)
 [ BigDisc
        ADD     R2, R2, R1
 |
        ADD     R2, R2, R1, LSL R7
 ]
        LDRB    LR, [R5,#DiscFlags]     ;using alternate copy of map ?
        TSTS    LR, #AltMapFlag
 [ BigDisc
        ADDNE   R2, R2, R9
        ADD     R3, R8, R1, LSL R7
 |
        ADDNE   R2, R2, R9, LSL R7
        ADD     R3, R8, R1, LSL R7
 ]
        MOV     R1, #DiscOp_ReadSecs :OR: DiscOp_Op_IgnoreEscape_Flag
        BL      RetryDiscOp             ;(R1-R4->R0,R2-R4,V)
        Pull    "R1-R4"
        BVS     %FT45

        ADD     R0, R8, R1, LSL R7
        MOV     R1, #1
        MOV     R1, R1, LSL R7
25
        BL      NewCheck                ;(R0,R1->LR,Z)
        BNE     %FT40
        ADD     R0, R0, R1
        SUBS    R4, R4, #1
        BNE     %BT25

30
        MOV     R1, R2
        CMPS    R1, R9
        BLO     %BT10

; HAVING GOT ALL THE ZONES INTO RAM NOW CHECK CHECK BYTES

        ADD     R0, R8, #CrossCheck
        MOV     R1, #1          ;zone length
        MOV     R1, R1, LSL R7
        MOV     R2, #0          ;init cross check
        MOV     R4, R9          ;zone ctr
35
        LDRB    LR, [R0],R1
        EOR     R2, R2, LR
        SUBS    R4, R4, #1
        BGT     %BT35           ;loop while more zones
        CMPS    R2, #&FF
        MOVEQ   R1, #ZoneValid
        BEQ     %FT50
 [ DebugE
        DLINE   "bad cross check"
 ]
40
        MOV     R0, #BadFsMapErr
45
        MOV     R1, #0
50
        SUB     R2, R9, #1
55                              ;loop to set or clear zone valid flags
        LDRB    LR, [R10,R2]
        BIC     LR, LR, #ZoneValid
        ORR     LR, LR, R1
        STRB    LR, [R10,R2]
        SUBS    R2, R2, #1
        BPL     %BT55
        CMPS    R1, #ZoneValid
        BEQ     %FT95                   ;V=0
        LDRB    LR, [R5,#DiscFlags]     ;if failed and not using alternate copy
        TSTS    LR, #AltMapFlag         ;of map then start using it
        ORREQ   LR, LR, #AltMapFlag
        STREQB  LR, [R5,#DiscFlags]
        BEQ     %BT05
 [ DynamicMaps
        LDR     LR, [R6, #DrvsFsMapFlags]
        ORR     LR, LR, #BadFs
        STR     LR, [R6, #DrvsFsMapFlags]
 |
        ORR     R8, R8, #BadFs          ;if both copies bad give up
        STR     R8, [R6,#DrvsFsMap]
 ]
        BL      SetV
95
 [ DebugE
        DLINE   "<-LoadNewMap(",cc
        BVC     %FT01
        DREG    R0, ""
01
        DLINE   ")"
 ]
        STRVS   R0, [SP]
        Pull    "R0-R2,R4,R7-R10,PC"

; ===========================
; MeasureFileAllocSize_GotMap
; ===========================
MeasureFileAllocSize_GotMap ROUT
        Push    "r1,r2,r3,r5,r6,r7,r8,r9,r10,r11,lr"

        MVN     r2, #0          ; map is already loaded
        B       %FT02

; ====================
; MeasureFileAllocSize
; ====================

; entry
; r1 = FcbIndDiscAdd
; r3 = dir indirect disc address
; r4 -> dir entry

; exit
; r0 = alloc size of file in bytes

MeasureFileAllocSize
        Push    "r1,r2,r3,r5,r6,r7,r8,r9,r10,r11,lr"

        MOV     r2, #0          ; we aint got no map
02
        BL      TestMap         ;(R3->Z)
        TSTEQ   r1, #&ff
        BEQ     %FT05           ; branch if new map and not shared

        ; Shared (or old map). Size allocated = sectors occupied
        BL      ReadLen         ;(R3,R4->LR)
        MOV     r0, lr
 [ DebugBs
        DREG    r0, "Shared/Old map unrounded size = "
 ]
 [ BigShare
        BL      RoundUpShare    ;(R0,R3->R0) always < 2G
 |
        BL      RoundUpSector   ;(R0,R3->R0) always < 2G
 ]
        B       %FT95

05
        ; Unshared. Size allocated = fragments occupied
        MOV     r3, r1

        ; r1=Link
        BIC     r1, r1, #DiscBits       ; remove disc number
        MOV     r1, r1, LSR #8          ; remove shared offset

        ; unallocated/bad blocks mean size=0
        CMP     r1, #1
        MOVLS   lr, #0
        BLS     %FT95

        TEQ     r2, #0
        BNE     %FT08           ; map in hand

        BL      BeforeReadFsMap ;(R3->R0,V)
        BVS     %FT95
08
        BL      InitReadNewFs   ;(R3->R10,R11,LR)

        MOV     r0, #0          ; zone
        MOV     r6, #0          ; accumulated file size
        B       %FT60
10
        BL      InitZoneObj     ;(R0,R10->R8,R9,R11,LR)
        MOV     R5, LR          ; zone end
15
 [ BigMaps
        TEQ     R11, R9
        BNE     %FT16           ; gap?

        BL      FreeRdLenLinkBits ; gap
        ADD     r9,r11,r8
        B       %ft20

16                              ; not gap
        BL      FragRdLenLinkBits       ; just read the object

 |
        BL      RdLenLinkBits   ;(R10,R11->R7,R8)
        TEQ     R11, R9
        ADDEQ   R9, R11, R8     ; it's a free block
        BEQ     %FT20
 ]
        TEQ     R8, R1          ; One of ours?
        ADDEQ   R6, R6, R7      ; Yes, accumulate the length
20
        ADD     R11, R11, R7    ; next fragment
        CMP     R11, R5         ; end of zone?
        BLO     %BT15

        ADD     r0, r0, #1      ; next zone
60
 [ BigMaps
        LDRB    lr, [R10, #ZoneHead+DiscRecord_NZones]
        LDRB    R11, [R10, #ZoneHead+DiscRecord_BigMap_NZones2]
        ADD     LR, LR, R11, LSL #8     ; R11 returned by InitZoneObj so free for use here
 |
        LDRB    lr, [R10, #ZoneHead+DiscRecord_NZones]
 ]
        CMP     r0, lr
        BLO     %BT10

 [ DebugBs
        DREG    r6, "UnShared bit size="
 ]
        LDRB    lr, [r10, #ZoneHead+DiscRecord_Log2bpmb]
      [ BigFiles
        MOVS    r0, r6, LSL lr          ; convert to bytes in r0
        MOVCS   r0, #RoundedTo4G
      |
        MOV     r0, r6, ASL lr          ; convert to bytes in r0
      ]
        TEQ     r2, #0                  ; was the map already loaded?
        BLEQ    UnlockMap               ; no, so unlock it
95
 [ DebugBs
        BVS     %FT01
        DREG    r0, "Open allocated size="
01
 ]
        Pull    "r1,r2,r3,r5,r6,r7,r8,r9,r10,r11,pc"

; ==========
; MapDiscAdd
; ==========

;entry
; R5  -> disc rec
; R7  log2 sector size
; R9  zones

;exit R2 map disc address

MapDiscAdd ROUT
 [ BigDisc
        Push    "R0,R1,LR"
 |
        Push    "R0,LR"
 ]
        MOV     R0, #8                  ; bits in a byte
        MOV     R0, R0, LSL R7          ; bits in a zone
        LDR     LR, [R5,#DiscRecord_ZoneSpare-2]
        SUB     R0, R0, LR, LSR #16     ; bits used in a zone
        MOVS    LR, R9, LSR #1          ; zone containing map
        MULS    R2, R0, LR
        SUBNE   R2, R2, #Zone0Bits      ; adjust for zone 0 disc record
        LDRB    R0, [R5,#DiscRecord_Log2bpmb]
        LDR     LR, [R5,#DiscRecord_Root]
        AND     LR, LR,#DiscBits
 [ BigDisc
        SUBS    R0,R0,R7                ; get required shift
        RSBMI   R0,R0,#0                ; if negative then reverse.
        ORRMI   R2,LR,R2,LSR R0         ;
        ORRPL   R2,LR,R2,LSL R0         ;
 |
        ORR     R2, LR, R2, LSL R0      ; disc address of map start
 ]
 [ DebugE
        DREG    R2, "Map disc add:"
 ]
 [ BigDisc
        Pull    "R0,R1,PC"
 |
        Pull    "R0,PC"
 ]

; ===================
; InvalidateFragCache
; ===================

InvalidateFragCache
        Push    "LR"
 [ DebugE
        DLINE   "InvalidateFragCache()"
 ]
        MOV     LR, #-1
        STR     LR, LastIndDiscAdd
        STR     LR, OldLastIndDiscAdd
        Pull    "PC"

; ========
; NewCheck
; ========

;entry
; R0 -> start
; R1 length ( must be multiple of 32 )

;exit
; LR check byte, Z=1 <=> good

NewCheck ROUT
        Push    "R1-R9,LR"
 [ DebugE
        DREG    R0, "NewCheck(start:",cc
        DREG    R1, ", len:",cc
        DLINE   ")"
 ]
        MOV     LR, #0
        ADDS    R1, R1, R0              ;C=0
05                              ;loop optimised as winnies may have many zones
        LDMDB   R1!,{R2-R9}
        ADCS    LR, LR, R9
        ADCS    LR, LR, R8
        ADCS    LR, LR, R7
        ADCS    LR, LR, R6
        ADCS    LR, LR, R5
        ADCS    LR, LR, R4
        ADCS    LR, LR, R3
        ADCS    LR, LR, R2
        TEQS    R1, R0          ;preserves C
        BNE     %BT05
        AND     R2, R2, #&FF    ;ignore old sum
        SUB     LR, LR, R2
        EOR     LR, LR, LR, LSR #16
        EOR     LR, LR, LR, LSR #8
        AND     LR, LR, #&FF
        CMPS    R2, LR
 [ DebugE
        Push    "R0"
        MOV     R0, LR
        DREG    R0,"<-NewCheck(checkbyte:", cc
        BEQ     %FT01
        DLINE   ",NE (bad)", cc
        B       %FT02
01
        DLINE   ",EQ (good)", cc
02
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R1-R9,PC"


; ===========
; SetNewCheck
; ===========

;entry
; R0 -> start
; R1 length

SetNewCheck
        Push    "LR"
 [ DebugE
        DREG    R0, "SetNewCheck(start:",cc
        DREG    R1, ", length:",cc
        DLINE   ")"
 ]
        BL      NewCheck        ;(R0,R1->LR,Z,V)
        STRB    LR, [R0]
        Pull    "PC"


; ============
; RoundUpAlloc
; ============

; round up file length to multiple of allocation size

; entry:
;  R0 file length
;  R3 top 3 bits disc id

; exit:
;  R0 rounded file length

RoundUpAlloc ROUT
 [ Debug5 :LOR: DebugE
        DREG    R0, "RoundUpAlloc(value:",cc
        DREG    R3, ", disc:",cc
        DLINE   ")"
 ]
        Push    "R1,R4,LR"
        SavePSR R4
        BL      ReadAllocSize           ;(R3->LR)
RoundCommon
        SUB     R1, LR, #1
      [ BigFiles
        ADDS    LR, R0, R1
        BIC     R0, LR, R1
        MOVCS   R0, #RoundedTo4G        ;Carry out, so return special marker
      |
        TSTS    R0, R1
        BICNE   R0, R0, R1
        ADDNE   R0, R0, LR
      ]
 [ Debug5 :LOR: DebugE
      [ BigFiles
        BCC     %FT01
        DLINE   "<-RoundCommon(value:4G",cc
        B       %FT02
      ]
01
        DREG    R0, "<-RoundCommon(value:",cc
02
        DLINE   ")"
 ]
        RestPSR R4,,f
        Pull    "R1,R4,PC"


; =============
; RoundUpSector
; =============

; round up file length to multiple of sector size

; entry:
;  R0 file length
;  R3 top 3 bits disc id

; exit:
;  R0 rounded file length

RoundUpSector ROUT
 [ Debug5 :LOR: DebugE
        DREG    R0, "RoundUpSector(value:",cc
        DREG    R3, ", disc:",cc
        DLINE   ")"
 ]
        Push    "R1,R4,LR"
        SavePSR R4

        MOV     LR, R3, LSR #(32-3)
        DiscRecPtr  LR, LR
        LDRB    LR, [LR,#DiscRecord_Log2SectorSize]

        MOV     R1, #1
        MOV     LR, R1, LSL LR
        B       RoundCommon


 [ BigShare

; =============
; RoundUpShare
; =============

; round up file length to multiple of sharing size

; entry:
;  R0 file length
;  R3 top 3 bits disc id

; exit:
;  R0 rounded file length

RoundUpShare ROUT
 [ Debug5 :LOR: DebugE
        DREG    R0, "RoundUpShare(value:",cc
        DREG    R3, ", disc:",cc
        DLINE   ")"
 ]
        Push    "R1,R4,LR"
        SavePSR R4

        MOV     LR, R3, LSR #(32-3)
        DiscRecPtr  LR, LR
        LDRB    R1, [LR,#DiscRecord_Log2SectorSize]
        LDRB    LR, [LR, #DiscRecord_BigMap_ShareSize]
        ADD     LR, R1, LR

        MOV     R1, #1
        MOV     LR, R1, LSL LR
        B       RoundCommon

 ]

; =============
; ReadAllocSize
; =============

; entry R3 top 3 bits disc num
; exit LR allocation size for this disc always a power of 2

ReadAllocSize ROUT
        Push    "R0,R1,LR"
 [ Debug5 :LOR: DebugE
        DREG    R3, "ReadAllocSize(disc:",cc
        DLINE   ")"
 ]
        BL      DiscAddToRec            ;(R3->LR)
        LDRB    R0, [LR,#DiscRecord_Log2SectorSize]    ;max of sector size and map bit size
        LDRB    R1, [LR,#DiscRecord_Log2bpmb]
        CMPS    R1, R0
        MOVHI   R0, R1
        MOV     LR, #1
        MOV     LR, LR, LSL R0
 [ Debug5 :LOR: DebugE
        Push    "R0"
        MOV     R0, LR
        DREG    R0, "<-ReadAllocSize(alloc size:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,R1,PC"

; =============
; ReadSectorSize
; =============

; entry R3 top 3 bits disc num
; exit LR log2 sector size

ReadSectorSize ROUT
        Push    "R0,LR"
 [ Debug5 :LOR: DebugE
        DREG    R3, "ReadSectorSize(disc:",cc
        DLINE   ")"
 ]
        BL      DiscAddToRec            ;(R3->LR, flags preserved)
        LDRB    LR, [LR,#DiscRecord_Log2SectorSize]    ;max of sector size and map bit size
 [ Debug5 :LOR: DebugE
        Push    "R0"
        MOV     R0, LR
        DREG    R0, "<-ReadSectorSize(log2 sector size:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,PC"                 ; flags preserved

; ===============
; MapPtrToDiscAdd
; ===============

;entry
; R3  top 3 bits disc
; R10 -> map start
; R11 map ptr

;exit
; R0 disc add

MapPtrToDiscAdd ROUT
 [ BigDisc
        Push    "R10,LR"
 |
        Push    "LR"
 ]
 [ DebugE
        DREG    R3, "MapPtrToDiscAdd(disc:",cc
        DREG    R10, ", map:",cc
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        ADD     LR, LR, #3      ;log2 total bits in zone
        MOV     R0, R11,LSR LR  ;zone
        LDR     LR, [R10,#ZoneHead+DiscRecord_ZoneSpare-2]
        MOV     LR, LR, LSR #16
        MUL     R0, LR, R0
        SUB     R0, R11,R0
        SUB     R0, R0, #Zone0Bits+(ZoneHead*8)
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2bpmb]

; when we get here, we have the disc address in units map bits.  Just shift
; left by log2bpmb, and if bigdisc also adjust for the sector size

 [ BigDisc
        LDRB    R10,[R10,#ZoneHead+DiscRecord_Log2SectorSize]   ; log2 sector size
        SUBS    LR,LR,R10               ; get overall shift
        RSBMI   LR,LR,#0                ; if -ve shift then convert to +ve shift in other
        MOVMI   R0,R0,LSR LR            ; ...direction
        MOVPL   R0,R0,LSL LR            ; ...otherwise just do it
 |
        MOV     R0, R0, LSL LR          ; easy in comparison!
 ]
        AND     LR, R3, #DiscBits
        ORR     R0, R0, LR

 [ DebugE
        DREG    R0, "<-MapPtrToDiscAdd(disc add:",cc
        DLINE   ")"
 ]

 [ BigDisc
        Pull    "R10,PC"
 |
        Pull    "PC"
 ]


 [ BigDisc

; =================
; MapPtrToZoneStart
; =================

; Purpose:
;
; This function is provided in order to support DoCompMoves
; with BigDisc.

;entry
; R3  top 3 bits disc
; R10 -> map start
; R11 map ptr

;exit
; R0 zone base disc address (sector address)

MapPtrToZoneBase ROUT
        Push    "R10,R11,LR"
 [ DebugE
        DREG    R3, "MapPtrToDiscAdd(disc:",cc
        DREG    R10, ", map:",cc
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        ADD     LR, LR, #3      ;log2 total bits in zone
        MOV     R0, R11,LSR LR  ;zone
        MOV     R11, R0, LSL LR ;map ptr to zone start
        LDR     LR, [R10,#ZoneHead+DiscRecord_ZoneSpare-2]
        MOV     LR, LR, LSR #16
        MUL     R0, LR, R0
        SUB     R0, R11,R0
        SUBS    R0, R0, #Zone0Bits+(ZoneHead*8)
        MOVMI   R0, #0          ;if -ve disc address then must be on first zone
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2bpmb]

; when we get here, we have the disc address in units map bits.  Just shift
; left by log2bpmb, and if bigdisc also adjust for the sector size

        LDRB    R10,[R10,#ZoneHead+DiscRecord_Log2SectorSize]   ; log2 sector size
        SUBS    LR,LR,R10               ; get overall shift
        RSBMI   LR,LR,#0                ; if -ve shift then convert to +ve shift in other
        MOVMI   R0,R0,LSR LR            ; ...direction
        MOVPL   R0,R0,LSL LR            ; ...otherwise just do it

        AND     LR, R3, #DiscBits
        ORR     R0, R0, LR

 [ DebugE
        DREG    R0, "<-MapPtrToDiscAdd(disc add:",cc
        DLINE   ")"
 ]

        Pull    "R10,R11,PC"

 ]

; ===============
; DiscAddToMapPtr
; ===============

;entry
; R0 disc address
; R10 ->map start
;exit
; R11 offset in map
; LR  zone number

DiscAddToMapPtr ROUT
        Push    "R0,R1,R3,LR"
 [ DebugE
        DREG    R0, "DiscAddToMapPtr(disc add:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        MOV     R3, R0
        BIC     R0, R0, #DiscBits

; could optimise this a bit later...

 [ BigDisc
        LDRB    LR,[R10,#ZoneHead+DiscRecord_Log2SectorSize]    ; get lg2 sector size
        LDRB    R1, [R10,#ZoneHead+DiscRecord_Log2bpmb] ; scale from sectors to map bits...
        SUBS    R1,R1,LR                        ; ...taking account of shift direction
        RSBMI   R1,R1,#0                        ;
        MOVPL   R0,R0,LSR R1                    ;
        MOVMI   R0,R0,LSL R1                    ;

 |
        LDRB    R1, [R10,#ZoneHead+DiscRecord_Log2bpmb]     ;scale from bytes to map bits
        MOV     R0, R0, LSR R1
 ]

        ADD     R0, R0, #Zone0Bits              ;adjust for zone 0
        LDRB    R1, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        MOV     R3, #8
        MOV     R1, R3, LSL R1                  ;total bits in a zone map
        LDR     R3, [R10,#ZoneHead+DiscRecord_ZoneSpare-2]
        MOV     R3, R3, LSR #16
        SUB     R1, R1, R3                      ;map bits actually used in a zone map
        MOV     R11,R0
        BL      Divide                          ;(R0,R1->R0,R1)
        MOV     LR, R0                          ;zone
        MLA     R11,R3, R0, R11                 ;add zone*spare, for non map bits
        ADD     R11,R11,#ZoneHead*8
 [ DebugE
        Push    "R0"
        DREG    R11, "<-DiscAddToMapPtr(map ptr:",cc
        MOV     R0, LR
        DREG    R0, "zone:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,R1,R3,PC"

; ===================
; ByteDiscAddToMapPtr
; ===================

;entry
; R0 disc address
; R10 ->map start
;exit
; R11 offset in map
; LR  zone number

ByteDiscAddToMapPtr ROUT
        Push    "R0,R1,R3,LR"
 [ DebugE
        DREG    R0, "ByteDiscAddToMapPtr(disc add:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        MOV     R3, R0
        BIC     R0, R0, #DiscBits

        LDRB    R1, [R10,#ZoneHead+DiscRecord_Log2bpmb]     ;scale from bytes to map bits
        MOV     R0, R0, LSR R1

        ADD     R0, R0, #Zone0Bits              ;adjust for zone 0
        LDRB    R1, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        MOV     R3, #8
        MOV     R1, R3, LSL R1                  ;total bits in a zone map
        LDR     R3, [R10,#ZoneHead+DiscRecord_ZoneSpare-2]
        MOV     R3, R3, LSR #16
        SUB     R1, R1, R3                      ;map bits actually used in a zone map
        MOV     R11,R0
        BL      Divide                          ;(R0,R1->R0,R1)
        MOV     LR, R0                          ;zone
        MLA     R11,R3, R0, R11                 ;add zone*spare, for non map bits
        ADD     R11,R11,#ZoneHead*8
 [ DebugE
        Push    "R0"
        DREG    R11, "<-ByteDiscAddToMapPtr(map ptr:",cc
        MOV     R0, LR
        DREG    R0, "zone:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,R1,R3,PC"

; =================
; CritInitReadNewFs
; =================

; exit
;  R10 -> map start
;  R11    ready for NextFree

CritInitReadNewFs ROUT
        LDR     R10,CritDrvRec
 [ DynamicMaps
        LDR     R10,[R10,#DrvsFsMapAddr]
 |
        LDR     R10,[R10,#DrvsFsMap]
        BIC     R10,R10,#HiFsBits
 ]
        MOV     R11,#FreeLink*8
 [ DebugE
        DREG    R10, "CritInitReadNewFs(map:",cc
        DREG    R11, ",freelink:",cc
        DLINE   ")"
 ]
        MOV     PC,LR                   ; Flags preserved


; =============
; InitReadNewFs
; =============

;entry
; R3  top 3 bits disc

;exit
; R10 -> map start
; R11    ready for NextFree
; LR  -> disc rec

InitReadNewFs ROUT
        Push    "LR"
 [ DebugE
        DREG    R3, "InitReadNewFs(disc:",cc
        DLINE   ")"
 ]
        MOV     LR, R3, LSR #(32-3)       ;disc
        DiscRecPtr  LR,LR
        LDRB    R10,[LR,#DiscsDrv]
        DrvRecPtr  R10,R10
 [ DynamicMaps
        LDR     R10,[R10,#DrvsFsMapAddr]
 |
        LDR     R10,[R10,#DrvsFsMap]
        BIC     R10,R10,#HiFsBits
 ]
        MOV     R11,#FreeLink*8
 [ DebugE
        Push    "R0"
        DREG    R10, "<-InitReadNewFs(map:",cc
        DREG    R11, ", freelink:",cc
        MOV     R0, LR
        DREG    R0, ", disc rec:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "PC"


; ==========
; InitReadFs
; ==========

;entry R3 top 3 bits disc

;exit R9-R11 ready for call of NextFs

InitReadFs ROUT
        Push    "LR"
        BL      TestMap         ;(R3->Z)
        BNE     %FT50
        BL      InitReadNewFs   ;(R3->R10,R11,LR)
        Pull    "PC"

50
        BL      InitReadOldFs   ;(R3->R9-R11)
        Pull    "PC"

; ======
; NextFs
; ======

;entry
; R3 top 3 bits disc
; R9-R11 map position

;exit
; R7 gap length
; R8 gap ind disc add
; R9-R11 map position
; Z=1 if done

NextFs  ROUT
        Push    "R0,LR"
        BL      TestMap         ;(R3->Z)
        BNE     %FT50
        BL      NextFree        ;(R10,R11->R9,R11,Z,C)
        Pull    "R0,PC",EQ
 [ BigMaps
        BL      FreeRdLenBits   ;(R10,R11->R7)
 |
        BL      RdLenBits       ;(R10,R11->R7)
 ]
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2bpmb]
        MOV     R7, R7, LSL LR  ;convert length from map bits to bytes
        BL      MapPtrToDiscAdd ;(R3,R10,R11->R0)
        MOV     R8, R0
        CMP     PC, #0          ;Z=0
        Pull    "R0,PC"

50
        BL      NextOldFs   ;(R3,R10,R11->R7,R8,R10,R11)
        Pull    "R0,PC"


; ===========
; InitZoneObj
; ===========

;entry
; R0  zone
; R10 -> map start

;exit
; R8  map bit of free link
; R9  map bit of first space (if none offset of free link)
; R11 map bit of first map entry
; LR  map bit of start of junk at end of this zone

InitZoneObj ROUT
        Push    "LR"
        BL      InitZoneFree    ;(R0,R10->R11)
        Push    "R7,R11"
        SavePSR R7
 [ BigMaps
        BL      FreeRdLinkBits  ;(R10,R11->R8)
 |
        BL      RdLinkBits    ;(R10,R11->R8)
 ]
        ADD     R9, R11,R8
        ADD     R11, R11, #(ZoneHead - FreeLink)*8
        LDRB    R8, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        MOV     LR, #8
        ADD     LR, R11, LR, LSL R8
        ASSERT  DiscRecord_ZoneSpare :MOD: 4 = 2
        LDR     R8, [R10, #ZoneHead + DiscRecord_ZoneSpare-2]
        SUB     LR, LR, R8, LSR #16
        TEQS    R0, #0
        ADDEQ   R11,R11,#Zone0Bits
; [ DebugE
;        Push    "R0"
;        DREG    R0, "<-InitZoneObj(zone:",cc
;        DREG    R8, ", freelink:",cc
;        DREG    R9, ", first space:",cc
;        DREG    R10, ", map:",cc
;        DREG    R11, ", first entry:",cc
;        MOV     R0, LR
;        DREG    R0, ", limit:",cc
;        DLINE   ")"
;        Pull    "R0"
; ]
        RestPSR R7,,f
        Pull    "R7,R8,PC"


; ============
; InitZoneFree
; ============

; entry:
;       R0 = zone
;       R10 -> map start
;
; exit:
;       R11 set for reading free spaces from zone R0 in map starting at R10

InitZoneFree ROUT
        LDRB    R11,[R10,#ZoneHead+DiscRecord_Log2SectorSize]
        MOV     R11,R0, LSL R11
        MOV     R11,R11,LSL #3
        ADD     R11,R11,#FreeLink*8
; [ DebugE
;        DREG    R0, "<-InitZoneFree(zone:",cc
;        DREG    R10, ", map:",cc
;        DREG    R11, ", freelink:",cc
;        DLINE   ")"
; ]
        MOV     PC,LR           ; flags preserved


; ========
; NextFree
; ========

;entry
; R10 -> map start
; R11 map ptr to space

;exit
; Z set <=> exhausted
; C set <=> exhausted or started new zone
; R9  map ptr to predecessor of next space
; R11 map ptr to next space

NextFree ROUT
 [ BigMaps
        Push    "R0,R8,LR"
 |
        Push    "R8,LR"
 ]
 [ DebugE
        DREG    R10, "NextFree(map:",cc
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
 [ BigMaps
        BL      FreeRdLinkBits          ;(R10,R11->R8,Z)
 |
        BL      RdLinkBits              ;(R10,R11->R8,Z)
 ]
        BEQ     %FT10                   ;zone done
        MOV     R9, R11
        ADDS    R11,R11,R8              ;Z=0, C=0
05
 [ DebugE
        DREG    R9, "<-NextFree(prev:",cc
        DREG    R11, ", this:",cc
        BCC     %FT01
        DLINE   ", next zone",cc
01
        BNE     %FT02
        DLINE   ", map end",cc
02
        DLINE   ")"
 ]
 [ BigMaps
        Pull    "R0,R8,PC"
 |
        Pull    "R8,PC"
 ]

10
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        ADD     LR, LR, #3
        MOV     R9, R11,LSR LR          ;zone
        ADD     R9, R9, #1
 [ BigMaps
        LDRB    R8, [R10,#ZoneHead+DiscRecord_NZones]
        LDRB    R0, [R10,#ZoneHead+DiscRecord_BigMap_NZones2]
        ADD     R8, R8, R0, LSL #8
 |
        LDRB    R8, [R10,#ZoneHead+DiscRecord_NZones]
 ]
        CMPS    R8, R9
        BEQ     %BT05                   ;exhausted Z=1, C=1
        MOV     R11,R9, LSL LR
        ADD     R11,R11,#FreeLink*8
 [ BigMaps
        BL      FreeRdLinkBits          ;(R10,R11->R8,Z)
 |
        BL      RdLinkBits              ;(R10,R11->R8,Z)
 ]
        BEQ     %BT10
        MOV     R9, R11
        ADD     R11,R11,R8
        CMPS    PC, #0                  ;Z=0, C=1
        B       %BT05



; ==============
; NextFree_Quick
; ==============

;entry
; R10 -> map start
; R11 map ptr to space

;exit
; C set <=> exhausted or started new zone
; R9  map ptr to predecessor of next space
; R11 map ptr to next space, unless started new zone or exhausted

NextFree_Quick ROUT
 [ BigMaps
        Push    "R0,R8,LR"
 |
        Push    "R8,LR"
 ]
 [ DebugE
        DREG    R10, "NextFree(map:",cc
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
 [ BigMaps
        BL      FreeRdLinkBits              ;(R10,R11->R8,Z)
 |
        BL      RdLinkBits              ;(R10,R11->R8,Z)
 ]
        BEQ     %FT10                   ;zone done
        MOV     R9, R11
        ADDS    R11,R11,R8              ;Z=0, C=0
05
 [ DebugE
        DREG    R9, "<-NextFree(prev:",cc
        DREG    R11, ", this:",cc
        BCC     %FT01
        DLINE   ", next zone",cc
01
        BNE     %FT02
        DLINE   ", map end",cc
02
        DLINE   ")"
 ]
 [ BigMaps
        Pull    "R0,R8,PC"
 |
        Pull    "R8,PC"
 ]

10
        CMPS    PC, #0                  ;Z=0, C=1
        B        %BT05


; =============
; RdLenLinkBits
; =============

;entry
; R10 -> new map start
; R11 bit ptr to map obj
;exit
; R7 len bits
; R8 link bits

 [ BigMaps
FragRdLenLinkBits ROUT
 |
RdLenLinkBits ROUT
 ]
        Push    "R0-R3,LR"
        SavePSR R3
 [ DebugEx
 [ BigMaps
        DREG    R10, "FragRdLenLinkBits(map:",cc
 |
        DREG    R10, "RdLenLinkBits(map:",cc
 ]
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
        LDRB    R7, [R10,#ZoneHead+DiscRecord_IdLen]
 [ BigMaps
10
 ]
        ADD     R0, R10,R11,LSR #3
      [ SupportARMv6
        BIC     R0, R0, #3      ;->word containing length start
      ]
        LDMIA   R0!,{R1,R2}
        ANDS    LR, R11, #31
        MOVNE   R1, R1, LSR LR
        RSB     LR, LR, #32
        ORRNE   R1, R1, R2, LSL LR
        MOV     R8, R1, LSR R7
        SUB     R8, R1, R8, LSL R7
        MOV     R7, #1
        SUBS    R1, R1, R8
        BNE     %FT05

        ADD     R7, R7, LR
        SUBS    R1, R2, R8, LSR LR
        BNE     %FT05
00
        LDMIA   R0!,{R1,R2}
        ADD     R7, R7, #32*2
        ORRS    LR, R1, R2
        BEQ     %BT00
        TEQS    R1, #0
        SUBNE   R7, R7, #32
        MOVEQ   R1, R2
        B       %FT05

 [ BigMaps
; =============
; FreeRdLenLinkBits
; =============

;entry
; R10 -> new map start
; R11 bit ptr to map obj (must be a free space)
;exit
; R7 len bits
; R8 link bits

FreeRdLenLinkBits

        Push    "R0-R3,LR"
        SavePSR R3
 [ DebugEx
 [ BigMaps
        DREG    R10, "FreeRdLenLinkBits(map:",cc
 |
        DREG    R10, "RdLenLinkBits(map:",cc
 ]
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
        LDRB    R7, [R10,#ZoneHead+DiscRecord_IdLen]
        CMP     r7, #MaxFreeLinkBits
        MOVHI   r7, #MaxFreeLinkBits
        B       %BT10           ; jump to common code
 ]

 [ BigMaps
; =============
; FreeRdLenBits
; =============

;entry
; R10 -> new map start
; R11 bit ptr to map obj (must be free space)
;exit
; R7 len bits

FreeRdLenBits
        Push    "R0-R3,LR"
        SavePSR R3
 [ DebugEx
 [ BigMaps
        DREG    R10, "FreeRdLenBits(map:",cc
 |
        DREG    R10, "RdLenBits(map:",cc
 ]
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
02
        LDRB    R7, [R10,#ZoneHead+DiscRecord_IdLen]
        CMP     r7, #MaxFreeLinkBits
        MOVHI   r7, #MaxFreeLinkBits
        B       %FT03
 ]

; =========
; RdLenBits
; =========

;entry
; R10 -> new map start
; R11 bit ptr to map obj
;exit
; R7 len bits

 [ BigMaps
FragRdLenBits
 |
RdLenBits
 ]
        Push    "R0-R3,LR"
        SavePSR R3
 [ DebugEx
 [ BigMaps
        DREG    R10, "FragRdLenBits(map:",cc
 |
        DREG    R10, "RdLenBits(map:",cc
 ]
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
02
        LDRB    R7, [R10,#ZoneHead+DiscRecord_IdLen]
 [ BigMaps
03
 ]
        ADD     R0, R11, R7
        ANDS    LR, R0, #31
        ADD     R7, R7, #1
        ADD     R0, R10,R0, LSR #3
      [ SupportARMv6
        BIC     R0, R0, #3      ;->word containing length start
      ]
        LDMIA   R0!,{R1,R2}
        MOVNE   R1, R1, LSR LR
        RSB     LR, LR, #32
        ORRS    R1, R1, R2, LSL LR
        BEQ     %FT10
05
        ; R1 is known to be non-zero
        ; Increment R7 by the number of trailing 0 bits in R1
      [ NoARMv5
        MOVS    LR, R1, LSL #16
        ADDEQ   R7, R7, #16
        MOVEQ   R1, R1, LSR #16

        TSTS    R1, #&FF
        ADDEQ   R7, R7, #8
        MOVEQ   R1, R1, LSR #8

        TSTS    R1, #&F
        ADDEQ   R7, R7, #4
        MOVEQ   R1, R1, LSR #4

        TSTS    R1, #&3
        ADDEQ   R7, R7, #2
        MOVEQ   R1, R1, LSR #2

        TSTS    R1, #&1
        ADDEQ   R7, R7, #1
      |
        SUB     LR, R1, #1
        BIC     LR, R1, LR ; identifies the bit position at which the borrow stopped
        CLZ     LR, LR
        ADD     R7, R7, #31
        SUB     R7, R7, LR
      ]
 [ DebugEx
        DREG    R7, "<-RdLenBits(len:", cc
        DLINE   ")"
 ]
        RestPSR R3,,f
        Pull    "R0-R3,PC"

10                              ;long obj
        ADD     R7, R7, LR
        MOVS    R1, R2
        BNE     %BT05
15
        LDMIA   R0!,{R1,R2}
        ADD     R7, R7, #32*2
        ORRS    LR, R1, R2
        BEQ     %BT15
        TEQS    R1, #0
        SUBNE   R7, R7, #32
        MOVEQ   R1, R2
        B       %BT05

 [ BigMaps
; ======================
; FreePrimitiveRdLenBits
; ======================

;entry
; R2 = idlen
; R10 -> new map start
; R11 bit ptr to map obj (must be free space)
;exit
; R7 len bits

PrimitiveFreeRdLenBits
        Push    "R0-R3,LR"
        SavePSR R3
        CMP     r2, #MaxFreeLinkBits
        MOVHI   r7, #MaxFreeLinkBits
        MOVLS   R7, R2
        B       %B02

 ]

; ==================
; PrimitiveRdLenBits
; ==================

;entry
; R2 = idlen
; R10 -> new map start
; R11 bit ptr to map obj
;exit
; R7 len bits
 [ BigMaps
PrimitiveFragRdLenBits
 |
PrimitiveRdLenBits
 ]
        Push    "R0-R3,LR"
        SavePSR R3
        MOV     R7, R2
        B       %B02

 [ BigMaps

; ==============
; FreeRdLinkBits
; ==============

;entry
; R10 -> new map start
; R11 bit ptr to map obj, must be free space
;exit
; R8 link bits, Z set if 0

FreeRdLinkBits ROUT
        Push    "R0,LR"
 [ DebugEx
 [ BigMaps
        DREG    R10, "FreeRdLinkBits(map:",cc
 |
        DREG    R10, "RdLinkBits(map:",cc
 ]
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
        ADD     LR, R10,R11,LSR #3
      [ SupportARMv6
        BIC     LR, LR,#3
      ]
        LDMIA   LR, {R8,LR}
        ANDS    R0, R11,#31
        MOVNE   R8, R8, LSR R0
        RSBNE   R0, R0, #32
        ORRNE   R8, R8, LR, LSL R0
        LDRB    LR, [R10,#ZoneHead+DiscRecord_IdLen]
        CMP     LR, #MaxFreeLinkBits
        MOVHI   LR, #MaxFreeLinkBits
        MOV     R0, R8, LSR LR
        SUBS    R8, R8, R0, LSL LR
 [ DebugEx
        DREG    R8, "<-RdLinkBits(link:",cc
        DLINE   ")"
 ]
        Pull    "R0,PC"

 ]

; ==========
; RdLinkBits
; ==========

;entry
; R10 -> new map start
; R11 bit ptr to map obj
;exit
; R8 link bits, Z set if 0
 [ BigMaps
FragRdLinkBits ROUT
 |
RdLinkBits ROUT
 ]
        Push    "R0,LR"
 [ DebugEx
 [ BigMaps
        DREG    R10, "FragRdLinkBits(map:",cc
 |
        DREG    R10, "RdLinkBits(map:",cc
 ]
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
        ADD     LR, R10,R11,LSR #3
      [ SupportARMv6
        BIC     LR, LR,#3
      ]
        LDMIA   LR, {R8,LR}
        ANDS    R0, R11,#31
        MOVNE   R8, R8, LSR R0
        RSBNE   R0, R0, #32
        ORRNE   R8, R8, LR, LSL R0
        LDRB    LR, [R10,#ZoneHead+DiscRecord_IdLen]
        MOV     R0, R8, LSR LR
        SUBS    R8, R8, R0, LSL LR
 [ DebugEx
        DREG    R8, "<-RdLinkBits(link:",cc
        DLINE   ")"
 ]
        Pull    "R0,PC"

 [ BigMaps
; =======================
; FreePrimitiveRdLinkBits
; =======================

;entry
; r2 = idlen
; R10 -> new map start
; R11 bit ptr to map obj, must be free space
;exit
; R8 link bits, Z set if 0

PrimitiveFreeRdLinkBits ROUT
        Push    "R0,LR"
 [ DebugEx
        DREG    R2, "PrimitiveRdLinkBits(LinkBits:",cc
        DREG    R10, ", map:",cc
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
        ADD     LR, R10,R11,LSR #3
      [ SupportARMv6
        BIC     LR, LR,#3
      ]
        LDMIA   LR, {R8,LR}
        ANDS    R0, R11,#31
        MOVNE   R8, R8, LSR R0
        RSBNE   R0, R0, #32
        ORRNE   R8, R8, LR, LSL R0
        CMP     r2, #MaxFreeLinkBits
        MOVHI   lr, #MaxFreeLinkBits
        MOVLS   lr, r2
        MOV     R0, R8, LSR lr
        SUBS    R8, R8, R0, LSL lr
 [ DebugEx
        DREG    R8, "<-PrimitiveRdLinkBits(link:",cc
        DLINE   ")"
 ]
        Pull    "R0,PC"
 ]


; ===================
; PrimitiveRdLinkBits
; ===================

;entry
; r2 = idlen
; R10 -> new map start
; R11 bit ptr to map obj
;exit
; R8 link bits, Z set if 0

 [ BigMaps
PrimitiveFragRdLinkBits ROUT
 |
PrimitiveRdLinkBits ROUT
 ]
        Push    "R0,LR"
 [ DebugEx
        DREG    R2, "PrimitiveRdLinkBits(LinkBits:",cc
        DREG    R10, ", map:",cc
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
        ADD     LR, R10,R11,LSR #3
      [ SupportARMv6
        BIC     LR, LR,#3
      ]
        LDMIA   LR, {R8,LR}
        ANDS    R0, R11,#31
        MOVNE   R8, R8, LSR R0
        RSBNE   R0, R0, #32
        ORRNE   R8, R8, LR, LSL R0
        MOV     R0, R8, LSR R2
        SUBS    R8, R8, R0, LSL R2
 [ DebugEx
        DREG    R8, "<-PrimitiveRdLinkBits(link:",cc
        DLINE   ")"
 ]
        Pull    "R0,PC"


; =========
; WrLenBits
; =========

;R0  len in bits
;R1  map ptr
;R10 -> map start

 [ BigMaps
FragWrLenBits ROUT
 |
WrLenBits ROUT
 ]
        Push    "R0-R6,LR"
        SavePSR R6
 [ DebugE
 [ BigMaps
        DREG    R0, "FragWrLenBits(len:",cc
 |
        DREG    R0, "WrLenBits(len:",cc
 ]
        DREG    R1, ", map ptr:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        BL      MarkZone        ;(R1,R10)
        LDRB    LR, [R10,#ZoneHead+DiscRecord_IdLen]
10
        SUB     R0, R0, LR              ;skip next field
        ADD     R1, R1, LR
        ADD     R2, R10,R1, LSR #3
        BIC     R2, R2, #3              ;word containing start of next field
        AND     R1, R1, #31             ;bit alignment
        RSB     LR, R1, #32
        SUBS    R0, R0, LR
        ADDLS   LR, R0, LR
        LDR     R3, [R2]                ;LR = field width in first word
        MOV     R4, #1
        RSB     R5, R4, R4, LSL LR      ;unshifted bits to clear 2^LR-1
        BIC     R3, R3, R5, LSL R1      ;clear old bits
        ADDLS   R5, R4, R5, LSR #1      ;if end in this word new bits 2^(LR-1)
        ORRLS   R3, R3, R5, LSL R1
        STR     R3, [R2],#4
        BLS     %FT90                   ;done if all in this word

        MOV     R5, #0
05                              ;loop to deal with middle zeroes
        SUBS    R0, R0, #32
        STRHI   R5, [R2],#4
        BHI     %BT05
        ADD     R0, R0, #32             ;R0 = field width in final word
        LDR     R3, [R2]
        RSB     R5, R4, R4, LSL R0      ;bits to clear 2^R0-1
        BIC     R3, R3, R5
        ADD     R5, R4, R5, LSR #1      ;bits to set 2^(R0-1)
        ORR     R3, R3, R5
        STR     R3, [R2]
90
        RestPSR R6,,f
        Pull    "R0-R6,PC"

 [ BigMaps

; =============
; FreeWrLenBits
; =============

;R0  len in bits
;R1  map ptr, must be free space
;R10 -> map start

FreeWrLenBits
        Push    "R0-R6,LR"
        SavePSR R6
 [ DebugE
 [ BigMaps
        DREG    R0, "FreeWrLenBits(len:",cc
 |
        DREG    R0, "WrLenBits(len:",cc
 ]
        DREG    R1, ", map ptr:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        BL      MarkZone        ;(R1,R10)
        LDRB    LR, [R10,#ZoneHead+DiscRecord_IdLen]
        CMP     LR, #MaxFreeLinkBits
        MOVHI   LR, #MaxFreeLinkBits
        B       %bt10
 ]

 [ BigMaps

; ======================
; FreePrimitiveWrLenBits
; ======================

;entry
; R0  next bits
; R1  map ptr, must be free space
; r2  idlen
; R10 -> map start

; As WrLenBits, but doesn't mark the zone
PrimitiveFreeWrLenBits
        Push    "R0-R6,LR"
        SavePSR R6
 [ DebugE
        DREG    R0, "PrimitiveWrLenBits(len:",cc
        DREG    R1, ", map ptr:",cc
        DREG    R2, ", LinkBits:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        CMP     r2, #MaxFreeLinkBits
        MOVHI   LR, #MaxFreeLinkBits
        MOVLS   LR, R2
        B       %BT10

 ]

; ==================
; PrimitiveWrLenBits
; ==================

;entry
; R0  next bits
; R1  map ptr
; r2  idlen
; R10 -> map start

; As WrLenBits, but doesn't mark the zone

 [ BigMaps
PrimitiveFragWrLenBits
 |
PrimitiveWrLenBits
 ]
        Push    "R0-R6,LR"
        SavePSR R6
 [ DebugE
        DREG    R0, "PrimitiveWrLenBits(len:",cc
        DREG    R1, ", map ptr:",cc
        DREG    R2, ", LinkBits:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        MOV     LR, R2
        B       %BT10

; ==========
; WrLinkBits
; ==========

;entry
; R0  next bits
; R1  map ptr
; R10 -> map start

 [ BigMaps
FragWrLinkBits ROUT
 |
WrLinkBits ROUT
 ]
        Push    "R1-R6,LR"
        SavePSR R6
 [ DebugE
  [ BigMaps
        DREG    R0, "FragWrLinkBits(link:",cc
  |
        DREG    R0, "WrLinkBits(link:",cc
  ]
        DREG    R1, ", map ptr:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        BL      MarkZone                ;(R1,R10)

        LDRB    R2, [R10,#ZoneHead+DiscRecord_IdLen]    ;form mask for clearing

10
        ADD     LR, R10, R1, LSR #3
      [ SupportARMv6
        BIC     LR, LR, #3
      ]

        MOV     R3, #1
        RSB     R2, R3, R3, LSL R2

        LDMIA   LR, {R3,R4}             ;64 bits containing old value
        AND     R1, R1, #31
        RSB     R5, R1, #32

        BIC     R3, R3, R2, LSL R1      ;clear old bits
        BIC     R4, R4, R2, LSR R5
        ORR     R3, R3, R0, LSL R1      ;OR in new bits
        ORR     R4, R4, R0, LSR R5

        STMIA   LR, {R3,R4}             ;write back modified 64 bits
        RestPSR R6,,f
        Pull    "R1-R6,PC"

 [ BigMaps

; ==============
; FreeWrLinkBits
; ==============

;entry
; R0  next bits
; R1  map ptr, must be free space
; R10 -> map start

FreeWrLinkBits
        Push    "R1-R6,LR"
        SavePSR R6
 [ DebugE
 [ BigMaps
        DREG    R0, "FreeWrLinkBits(link:",cc
 |
        DREG    R0, "WrLinkBits(link:",cc
 ]
        DREG    R1, ", map ptr:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        BL      MarkZone                ;(R1,R10)

        LDRB    R2, [R10,#ZoneHead+DiscRecord_IdLen]    ;form mask for clearing
        CMP     r2, #MaxFreeLinkBits
        MOVHI   r2, #MaxFreeLinkBits
        B       %BT10
 ]


; ===================
; PrimitiveWrLinkBits
; ===================

;entry
; R0  next bits
; R1  map ptr
; r2  idlen
; R10 -> map start

; As WrLinkBits, but doesn't mark the zone
 [ BigMaps
PrimitiveFragWrLinkBits
 |
PrimitiveWrLinkBits
 ]
        Push    "R1-R6,LR"
        SavePSR R6
 [ DebugE
        DREG    R0, "PrimitiveWrLinkBits(link:",cc
        DREG    R1, ", map ptr:",cc
        DREG    R2, ", idlen:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        B       %BT10

 [ BigMaps
; =======================
; PrimitiveFreeWrLinkBits
; =======================

;entry
; R0  next bits
; R1  map ptr, must be free space
; r2  idlen
; R10 -> map start

; As FreeWrLinkBits, but doesn't mark the zone
PrimitiveFreeWrLinkBits
        Push    "R1-R6,LR"
        SavePSR R6
 [ DebugE
        DREG    R0, "PrimitiveWrLinkBits(link:",cc
        DREG    R1, ", map ptr:",cc
        DREG    R2, ", idlen:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        CMP     r2,#MaxFreeLinkBits
        MOVHI   r2,#MaxFreeLinkBits

        B       %BT10
 ]

; ==========
; WrFreeNext
; ==========

; point R1 at R0, R0 may be 0 marking end
; R10 -> map start

WrFreeNext ROUT
        Push    "R0,R2,LR"
        SavePSR R2
 [ DebugE
        DREG    R0, "WrNextFree(dest ptr:",cc
        DREG    R1, ", source ptr:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        TEQS    R0, #0
        SUBNE   R0, R0, R1
 [ BigMaps
        BL      FreeWrLinkBits      ;(R0,R1,R10)
 |
        BL      WrLinkBits      ;(R0,R1,R10)
 ]
        RestPSR R2,,f
        Pull    "R0,R2,PC"


; ==========
; IdsPerZone
; ==========

;entry R10 -> map start

;exit  R1 = ids per zone

IdsPerZone ROUT
        Push    "R0,LR"
        LDRB    R0, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        MOV     R1, #8
        MOV     R0, R1, LSL R0          ;bits in a zone
        LDR     R1, [R10,#ZoneHead+DiscRecord_ZoneSpare-2]
        SUB     R0, R0, R1, LSR #16
        LDRB    R1, [R10,#ZoneHead+DiscRecord_IdLen]
        ADD     R1, R1, #1
        BL      Divide
        MOV     R1, R0
 [ DebugE
        DREG    R1, "<-IdsPreZone(ids:",cc
        DREG    R10, ", map:", cc
        DLINE   ")"
 ]
        Pull    "R0,PC"


; ================
; IndDiscAddToZone
; ================

;entry
; R0  ind disc address
; R10 -> map start

;exit R0 = zone

IndDiscAddToZone ROUT
        Push    "R1,R2,LR"
        SavePSR R2
 [ DebugE
        DREG    R0, "IndDiscAddToZone(disc add:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]

; SBP: need to change this code if going to be using large fragment ids

 [ BigMaps
        MOV     R0, R0, LSL #3
        MOV     R0, R0, LSR #3+8      ;just id bits left
 |
        MOV     R0, R0, LSL #8+1
        MOV     R0, R0, LSR #8+1+8      ;just id bits left
 ]

        TEQS    R0, #2                  ; ?? special case for id=2 (defective sectors) ??
        BEQ     %FT50

        BL      IdsPerZone              ;(R10->R1)
        BL      Divide                  ;(R0,R1->R0,R1)
 [ DebugE
        DREG    R0, "<-IndDiscAddToZone(zone:",cc
        DLINE   ")"
 ]
        RestPSR R2,,f
        Pull    "R1,R2,PC"


50
 [ BigMaps
        LDRB    R0, [R10,#ZoneHead+DiscRecord_NZones]
        LDRB    R1, [R10,#ZoneHead+DiscRecord_BigMap_NZones2]
        ADD     R0, R0, R1, LSL #8
 |        
        LDRB    R0, [R10,#ZoneHead+DiscRecord_NZones]
 ]
        MOV     R0, R0, LSR #1          ;the map zone
 [ DebugE
        DREG    R0, "<-IndDiscAddToZone(zone:",cc
        DLINE   ")"
 ]
        RestPSR R2,,f
        Pull    "R1,R2,PC"


; ========
; UnusedId
; ========

;entry
; R0 zone
; R10 -> map start
;exit LR an unused id for that zone

UnusedId ROUT
        Push    "R0-R3,R6-R9,R11,LR"
 [ DebugE
        DREG    R0, "UnusedId(zone:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        BL      InitZoneObj     ;(R0,R10->R8,R9,R11,LR)
        MOV     R3, LR          ;start of next zone
        BL      IdsPerZone      ;(R10->R1)
        MUL     R6, R0, R1      ;first id for this zone
        ADD     R2, R6, R1      ;first id in next zone
        MOV     R0, #ScratchSpace
        MOV     R1, R1, LSR #3  ;init bit table of used ids
        ADD     R1, R1, #1
        BL      ZeroRam
        TEQS    R6, #0          ;ids 0,1,2 are reserved
        MOVEQ   LR, #2_00000111
        STREQB  LR, [R0]
        MOV     R1, #1
10                              ;GO THROUGH ZONE NOTING IDS USED

 [ BigMaps
        TEQS    R11,R9          ;is this map obj a gap?
        BEQ     %FT15           ; gap

        ; not gap
        BL      FragRdLinkBits  ;(R11->R8,Z)
        SUBS    LR, R8, R6
        CMPHSS  R2, R8
        ADDHI   R8, R0, LR, LSR #3
        ANDHI   LR, LR, #7
        LDRHIB  R7, [R8]
        ORRHI   R7, R7, R1, LSL LR
        STRHIB  R7, [R8]
        BL      FragRdLenBits   ; length
        ADD     R11,R11,R7
        CMPS    R11,R3
        BLO     %BT10           ;loop while more frags in zone
        B       %FT16

15      ; it was a gap
        BL      FreeRdLinkBits  ;(R11->R8,Z)
        ADD     R9,R9,R8        ;next gap pointer
        BL      FreeRdLenBits   ; length
        ADD     R11,R11,R7
        CMPS    R11,R3
        BLO     %BT10           ;loop while more frags in zone

16      ; re-join here

 |
        BL      RdLinkBits      ;(R11->R8,Z)
        TEQS    R11,R9          ;is this map obj a gap ?
        ADDEQ   R9, R9, R8
        BEQ     %FT15
        SUBS    LR, R8, R6
        CMPHSS  R2, R8
        ADDHI   R8, R0, LR, LSR #3
        ANDHI   LR, LR, #7
        LDRHIB  R7, [R8]
        ORRHI   R7, R7, R1, LSL LR
        STRHIB  R7, [R8]
15
        BL      RdLenBits       ;(R11->R7)
        ADD     R11,R11,R7
        CMPS    R11,R3
        BLO     %BT10           ;loop while more frags in zone
 ]

        SUB     R0, R0, #4
20                              ;FIND FIRST UNUSED ID
        LDR     R7, [R0,#4] !
        CMPS    R7, #-1
        BEQ     %BT20           ;all these ids used
        SUB     LR, R0, #ScratchSpace
        ADD     LR, R6, LR, LSL #3
25
        MOVS    R7, R7, LSR #1
        ADDCS   LR, LR, #1
        BCS     %BT25

 [ DebugE
        Push    "R0"
        MOV     R0, LR
        DREG    R0, "<-UnusedId(Id:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0-R3,R6-R9,R11,PC"


; ==================
; DefFindIdThenClaim
; ==================

DefFindIdThenClaim
        MOV     R5,#-1

; ===============
; FindIdThenClaim
; ===============

;entry
; R3  top 3 bits disc
; R4  length to claim
; R5  do not use first gap of this size
; R6  predecessor gap of gap to start at
; R10 -> map start

;exit
; R2  ind disc address of obj
; R11 map ptr of obj
; LR number of map bits actually claimed

FindIdThenClaim
        Push    "R0,R7,LR"
        SavePSR R7
 [ DebugE
        DREG    R3, "FindIdThenClaim(disc:",cc
        DREG    R4, ", len:",cc
        DREG    R5, ", miss gap:",cc
        DREG    R6, ", pre gap:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        LDRB    R0, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        MOV     R0, R6, LSR R0
        MOV     R0, R0, LSR #3  ;zone
        BL      UnusedId        ;(R0,R10->LR)
        AND     R0, R3, #DiscBits
        ORR     R0, R0, LR, LSL #8
        MOV     R2, LR, LSL #8
        BL      ChainClaim      ;(R2,R4-R6,R10->R11)
        MOV     R2, R0
 [ DebugE
        DREG    R2, "<-FindIdThenClaim(disc add:",cc
        DREG    R11, ", map ptr:",cc
        DLINE   ")"
 ]
        RestPSR R7,,f
        Pull    "R0,R7,PC"


; =============
; DefChainClaim
; =============

DefChainClaim
        MOV     R5,#-1

; ==========
; ChainClaim
; ==========

;entry
; R2  link bits in bits 8-22 [BigMaps bits 8-28]
; R4  length to claim in map bits
; R5  do not use first gap of this size
; R6  predecessor gap of gap to start at
; R10 -> map start

;exit
; R11 map ptr of obj
; LR number of map bits actually claimed

ChainClaim ROUT
 [ DebugE :LOR: DebugEa
        DREG    R2, "ChainClaim(link:",cc
        DREG    R4, ", len:",cc
        DREG    R5, ", miss gap:",cc
        DREG    R6, ", pre gap:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        Push    "R0-R9,R11,LR"
        SavePSR R11
        Push    "R11"

        ; Convert to Id
 [ BigMaps
        MOV     R2, R2, LSL #3
        MOV     R2, R2, LSR #3+8
 |
        MOV     R2, R2, LSL #8+1
        MOV     R2, R2, LSR #8+1+8
 ]

        MOV     R11,R6
        MOV     R3, #0          ;amount claimed so far is 0

        ; Start searching for free space after the gap supplied
        BL      NextFree        ;(R10,R11->R9,R11,Z,C)
 [ BigMaps
        BLNE    FreeRdLenBits       ;(R10,R11->R7)
 |
        BLNE    RdLenBits       ;(R10,R11->R7)
 ]
        STR     R11,[sp, #11*4] ;map ptr of obj is first gap found (sp offset OK - used to be 10)
        B       %FT10
05
        BL      NextFree        ;(R10,R11->R9,R11,Z,C)
 [ BigMaps
        BLNE    FreeRdLenBits   ;(R10,R11->R7)
 |
        BLNE    RdLenBits       ;(R10,R11->R7)
 ]
10
        BCC     %FT15           ;still in same zone

        ; If changed zone then terminate the previous zone's free list
        MOV     R1, R6
        MOV     R0, #0
 [ BigMaps
        BL      FreeWrLinkBits      ;mark end of free chain in previous zone
 |
        BL      WrLinkBits      ;mark end of free chain in previous zone
 ]
        BNE     %FT14           ;not reached end of map

        ; reached end of map so wrap to the map start
        MOV     R11,#FreeLink*8 ;if end start again
        BL      NextFree        ;(R10,R11->R9,R11,Z,C)
 [ BigMaps
        BLNE    FreeRdLenBits   ;(R10,R11->R7)
 |
        BLNE    RdLenBits       ;(R10,R11->R7)
 ]
14
        MOV     R6, R9          ;re-init last unused gap

15
        TEQS    R7, R5          ;IF this is gap asked not to use
        MOVEQ   R1, R6
        MOVEQ   R0, R11
        BLEQ    WrFreeNext      ;(R0,R1,R10) point last unused gap at it
        MOVEQ   R6, R11         ; re-init last unused gap
        MOVEQ   R5, #-1         ; prevent further matches
        BEQ     %BT05

        MOV     R0, R2
        MOV     R1, R11
        SUBS    R4, R4, R7      ;desired -= gap size
        ADDHI   R3, R3, R7      ;claimed += gap size
        BLS     %FT20           ;if no more gaps needed
        BL      NextFree        ;(R10,R11->R9,R11,Z,C)
 [ BigMaps
        BLNE    FreeRdLenBits   ;(R10,R11->R7)
        BL      FragWrLinkBits  ;(R0,R1,R10) set fragment link bits
 |
        BLNE    RdLenBits       ;(R10,R11->R7)
        BL      WrLinkBits      ;(R0,R1,R10) set fragment link bits
 ]
        B       %BT10

20
        ; Have now claimed all the whole fragments so lets sort out the last
        ; fragment.
        ADD     R4, R4, R7      ;amount of this last frag needed
 [ BigMaps
        BL      FreeRdLinkBits  ;(R10,R11->R8,Z)
        BL      FragWrLinkBits  ;(R0,R1,R10) set fragment link bits
 |
        BL      RdLinkBits      ;(R10,R11->R8,Z)
        BL      WrLinkBits      ;(R0,R1,R10) set fragment link bits
 ]
        ADDNE   R8, R11, R8     ;next free in this zone

        ; Sort out how much of the last gap we want to claim
        BL      MinMapObj       ;(R10->LR)
        CMPS    R4, LR          ;round up to min size
        MOVLO   R4, LR
        SUB     R0, R7, R4      ;amount of frag left assuming we claim this size
        CMPS    R0, LR
        MOVLO   R4, R7          ;round up to whole of gap if too little left to split it

        ; LO=>not splitting this gap
        ; HS=>splitting this gap
        ; R3=amount in bits claimed so far
        ; R4=amount of this gap being given over to ChainClaim
        MOVHS   R0, R4          ;if can split put in new length
        MOVHS   R1, R11
 [ BigMaps
        BLHS    FragWrLenBits
 |
        BLHS    WrLenBits
 ]
        MOV     R1, R6          ;point previous gap at correct next
        MOVLO   R0, R8          ;not splitting=>next gap is new next gap
        ADDHS   R0, R11, R4     ;splitting=>2nd half of this gap is new next gap
        BL      WrFreeNext      ;(R0,R1,R10)
        MOVHS   R1, R0          ;if splitting point new fragment at next
        MOVHS   R0, R8
        BLHS    WrFreeNext      ;(R0,R1,R10)
        ADD     LR, R3, R4      ;return amount claimed in LR
 [ DebugE :LOR: DebugEa
        LDR     R11,[SP,#10*4]
        DREG    R11, "<-ChainClaim(map ptr:",cc
        DREG    LR, ",Bits:",cc
        DLINE   ")"
 ]
        Pull    "R11"
        RestPSR R11,,f
        Pull    "R0-R9,R11,PC"


; ===========
; ShortenFrag
; ===========

;entry
; R0  new len in map bits
; R1  old len in map bits
; R2  map bit of frag start
; R3  map bit of start of the gap before frag
; R10 -> map start

ShortenFrag ROUT
        Push    "R0,R1,R4-R8,R11,LR"
 [ DebugE
        DREG    R0, "ShortenFrag(new len:",cc
        DREG    R1, ", old len:",cc
        DREG    R2, ", frag start:",cc
        DREG    R3, ", pre gap:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
        MOV     R11,R3
 [ BigMaps
 ; R3 is a gap so we're working in Free spaces
        BL      FreeRdLenBits       ;(R10,R11->R7)
        BL      FreeRdLinkBits      ;(R10,R11->R8,Z)
 |
        BL      RdLenBits       ;(R10,R11->R7)
        BL      RdLinkBits      ;(R10,R11->R8,Z)
 ]
        ADDNE   R8, R3, R8      ;start of post gap
        ADD     R4, R3, R7      ;end of pre gap
        ADD     R5, R2, R0      ;new frag end
        ADD     R6, R2, R1      ;old frag end

        TEQS    R0, #0          ;if fragment not disappearing altogether
        MOVNE   R1, R2          ;set its new length
 [ BigMaps
        BLNE    FragWrLenBits   ;(R0,R1,R10)
 |
        BLNE    WrLenBits       ;(R0,R1,R10)
 ]

        CMPS    R4, R5          ;IF gap joins pre gap
        MOVEQ   R5, R3          ;adjust gap start
        MOVNE   R1, R3          ;ELSE point pre gap at gap
        MOVNE   R0, R5
        BLNE    WrFreeNext      ;(R0,R1,R10)

        TEQS    R6, R8          ;IF gap joins post gap
        BNE     %FT10
        MOV     R11,R8
 [ BigMaps
        BL      FreeRdLenBits   ;(R10,R11->R7)
        BL      FreeRdLinkBits  ;(R10,R11->R8,Z)
 |
        BL      RdLenBits       ;(R10,R11->R7)
        BL      RdLinkBits      ;(R10,R11->R8,Z)
 ]
        ADDNE   R8, R11,R8      ;adjust post gap
        ADD     R6, R6, R7      ;and gap end
10
        SUB     R0, R6, R5
        MOV     R1, R5
 [ BigMaps
        BL      FreeWrLenBits   ;(R0,R1,R10) set gap length
 |
        BL      WrLenBits       ;(R0,R1,R10) set gap length
 ]
        MOV     R0, R8
        BL      WrFreeNext      ;(R0,R1,R10) and successor

 [ DebugE
        DLINE   "<-ShortenFrag()"
 ]
        Pull    "R0,R1,R4-R8,R11,PC"


; ============
; ReallyShared
; ============

;entry
; R2 ind disc add
; R3 dir
; R4 -> dir entry
; R5 -> dir start, may be fudged as only used to check sharing

;exit EQ <=> file is in shared frag and at least one other obj is sharing frag

;CAN'T READ IN DISC ADD FROM DIR ENTRY AS CLOSE FILE WILL HAVE ALREADY MODIFIED
;THIS IF FILE IS ZERO LENGTH

ReallyShared ROUT
        Push    "R0,R1,R4,LR"
 [ DebugE
        DREG    R2, "ReallyShared(disc add:",cc
        DREG    R3, ", dir:",cc
        DREG    R4, ", entry:",cc
        DREG    R5, ", dir start:",cc
 ]
        MOV     R1, R2, LSR #8
        TSTS    R2, #&FF        ;If not in shared fragment
        TOGPSR  Z_bit,LR
        BNE     %FT95
        TEQS    R1, R3, LSR #8
        BEQ     %FT95           ;sharing with parent dir
        MOV     R0, R4
 [ BigDir
        BL      TestBigDir      ;test for big-dir ness
        BEQ     %FT99
 ]
        ADD     R4, R5, #DirFirstEntry
05
        TEQS    R4, R0
        BEQ     %FT10
        BL      ReadIndDiscAdd  ;(R3,R4->LR)
        TEQS    R1, LR, LSR #8
        BEQ     %FT95           ;sharing with file
10
        LDRB    LR, [R4,#NewDirEntrySz] !
        CMPS    LR, #" "+1
        BHS     %BT05           ;loop while more dir entries
                        ;NE if no sharers
95
 [ DebugE
        BEQ     %FT01
        DLINE   "<-ReallyShared(not really sharing)"
        B       %FT02
01
        DLINE   "<-ReallyShared(really sharing)"
02
 ]
        Pull    "R0,R1,R4,PC"

 [ BigDir
99
        BL      GetDirFirstEntry
        SUB     R4, R4, #BigDirEntrySize
        B       %FT10
05
        TEQS    R4, R0
        BEQ     %FT10
        BL      ReadIndDiscAdd  ;(R3,R4->LR)
        TEQS    R1, LR, LSR #8
        BEQ     %BT95           ;sharing with file
10
        ADD     R4, R4, #BigDirEntrySize
        BL      BigDirFinished
        BNE     %BT05           ;loop while more dir entries
        TOGPSR  Z_bit,LR
                        ;NE if no sharers
        B       %BT95
 ]

; ========
; MarkZone
; ========

; mark zone as changed and candidate for compaction

;entry
; R1     map ptr
; R10 -> map start

MarkZone ROUT
        Push    "R0-R1,LR"
 [ DebugE
        DREG    R1, "MarkZone(map ptr:",cc
        DREG    R10, ", map:",cc
        DLINE   ")"
 ]
 [ BigMaps
        LDRB    R0, [R10,#ZoneHead+DiscRecord_NZones]
        LDRB    LR, [R10,#ZoneHead+DiscRecord_BigMap_NZones2]
        ADD     R0, R0, LR, LSL #8
 |
        LDRB    R0, [R10,#ZoneHead+DiscRecord_NZones]
 ]
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        ADD     R0, R10,R0,LSL LR        ;-> zone flags
        ADD     LR, LR, #3
        MOV     R1, R1, LSR LR            ;zone
        LDRB    LR, [R0,R1]
        BIC     LR, LR, #ZoneValid :OR: ZoneCompacted
        STRB    LR, [R0,R1]
        Pull    "R0-R1,PC"              ; flags preserved


; ============
; ZoneFlagsPtr
; ============

;entry R10 -> map start
;exit LR -> zone flags table

ZoneFlagsPtr ROUT
        Push    "R0,LR"
 [ BigMaps
        LDRB    R0, [R10,#ZoneHead+DiscRecord_NZones]
        LDRB    LR, [R10,#ZoneHead+DiscRecord_BigMap_NZones2]
        ADD     R0, R0, LR, LSL #8
 |
        LDRB    R0, [R10,#ZoneHead+DiscRecord_NZones]
 ]
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        ADD     LR, R10,R0, LSL LR        ;-> zone flags
 [ DebugE
        Push    "R0"
        MOV     R0, LR
        DREG    R0, "<-ZoneFlagsPtr(ptr:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,PC"                 ; flags preserved


; =============
; Log2AllocBits
; =============

; entry R10 -> map start
; exit  LR  log2 # bits in map for an allocation unit

Log2AllocBits ROUT
        Push    "R0,LR"
        LDRB    R0, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2bpmb]
        SUBS    R0, R0, LR
        MOVLS   LR, #0
        MOVHI   LR, R0
 [ DebugE
        Push    "R0"
        MOV     R0, LR
        DREG    R0, "<-Log2AllocBits(log2bits:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,PC"


; =============
; AllocBitWidth
; =============

; entry R10 -> map start
; exit  LR  # bits in map for an allocation unit

AllocBitWidth ROUT
        Push    "R0,LR"
        LDRB    R0, [R10,#ZoneHead+DiscRecord_Log2SectorSize]
        LDRB    LR, [R10,#ZoneHead+DiscRecord_Log2bpmb]
        SUBS    R0, R0, LR
        MOV     LR, #1
        MOVHI   LR, LR, LSL R0
 [ DebugE
        Push    "R0"
        MOV     R0, LR
        DREG    R0, "<-AllocBitWidth(bitwidth:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,PC"


; =========
; MinMapObj
; =========

; entry R10 -> map start
; exit  LR  # bits in map for smallest map obj

MinMapObj ROUT
        Push    "R0,R1,LR"
        BL      AllocBitWidth   ;(->LR)
        MOV     R0, LR
        LDRB    R1, [R10,#ZoneHead+DiscRecord_IdLen]
05
        CMPS    LR, R1
        ADDLS   LR, LR, R0
        BLS     %BT05
 [ DebugE
        Push    "R0"
        MOV     R0, LR
        DREG    R0, "<-MinMapObj(bits:",cc
        DLINE   ")"
        Pull    "R0"
 ]
        Pull    "R0,R1,PC"

        LTORG
        END
