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
; MultiFS format specific SWIs supplied by FileCore

; These SWIs are *NOT* considered 'inside' FileCore for the purposes of
; reentrance prohibition.


; entry: r0 = pointer to disc format structure to be filled in
;        r1 = SWI to vet the format
;        r2 = parameter to the vetting SWI
;        r3 = format specifier

; exit:  V, r0=error
;   or:  regs preserved
DoSwiDiscFormat ROUT
        Push    "r0-r11,lr"

        ; Check the specified format is one we know about
        TEQ     r3, #Format_Floppy :OR: Format_L
        TEQNE   r3, #Format_Floppy :OR: Format_D
        TEQNE   r3, #Format_Floppy :OR: Format_E
        TEQNE   r3, #Format_Floppy :OR: Format_F
        TEQNE   r3, #Format_Floppy :OR: Format_G
        MOVNE   r0, #BadParmsErr
        BNE     %FT90

        ; Choose the parameter block for the format specifier
        TEQ     r3, #Format_Floppy :OR: Format_L
        ADREQ   r4, FormatLFloppyPhysParams
        TEQ     r3, #Format_Floppy :OR: Format_D
        ADREQ   r4, FormatDFloppyPhysParams
        TEQ     r3, #Format_Floppy :OR: Format_E
        ADREQ   r4, FormatEFloppyPhysParams
        TEQ     r3, #Format_Floppy :OR: Format_F
        ADREQ   r4, FormatFFloppyPhysParams
        TEQ     r3, #Format_Floppy :OR: Format_G
        ADREQ   r4, FormatGFloppyPhysParams

        ; Fill in the disc format structure
        ASSERT  SzFormatBlock = 16*4
        MOV     lr, r4
        MOV     r11, r0
        LDMIA   lr!, {r5-r8}
        STMIA   r11!, {r5-r8}
        LDMIA   lr!, {r5-r8}
        STMIA   r11!, {r5-r8}
        LDMIA   lr!, {r5-r8}
        STMIA   r11!, {r5-r8}
        LDMIA   lr!, {r5-r8}
        STMIA   r11!, {r5-r8}

        ; Call the vetting SWI
        MOV     r11, r1
        MOV     r1, r2
        BL      CallASwi
        BVS     %FT95

        ; Check the record is still OK

        ; We care about:
        ; sector size
        ; sectors per track
        ; density
        ; options
        ; start sector
        ; tracks to format
        ; The rest is not critical to the operation of this format
        LDR     r1, [r0, #FormatSectorSize]
        LDR     r2, [r4, #FormatSectorSize]
        TEQ     r1, r2
 [ DebugO
 BEQ    %FT01
 DLINE  "Fail at A"
01
 ]
        LDREQB  r1, [r0, #FormatSectorsPerTrk]
        LDREQB  r2, [r4, #FormatSectorsPerTrk]
        TEQEQ   r1, r2
 [ DebugO
 BEQ    %FT01
 DLINE  "Fail at B"
01
 ]
        LDREQB  r1, [r0, #FormatDensity]
        LDREQB  r2, [r4, #FormatDensity]
        TEQEQ   r1, r2
 [ DebugO
 BEQ    %FT01
 DLINE  "Fail at C"
01
 ]
        LDREQB  r1, [r0, #FormatOptions]
        LDREQB  r2, [r4, #FormatOptions]
        EOREQ   lr, r1, r2
        BICEQ   lr, lr, #FormatOptIndexMark
        TEQEQ   lr, #0
 [ DebugO
 BEQ    %FT01
 DLINE  "Fail at D"
01
 ]
        LDREQ   r1, [r0, #FormatTracksToFormat]
        LDREQ   r2, [r4, #FormatTracksToFormat]
        TEQEQ   r1, r2
 [ DebugO
 BEQ    %FT01
 DLINE  "Fail at E"
01
 ]

        ; If any NE then format's not acceptable
        MOVNE   r0, #BadParmsErr
        MOVEQ   r0, #0

        ; return
90
        BL      SetVOnR0
95
        STRVS   r0, [sp]
        Pull    "r0-r11, pc"

FormatLFloppyPhysParams
        DCD     256     ; Sector Size
        DCD     42      ; Gap 1, side 0
        DCD     42      ; Gap 1, side 1
        DCD     57      ; Gap 3
        DCB     16      ; Sectors per track
        DCB     DensityDouble
        DCB     FormatOptSequenceSides
        DCB     0       ; LowSector
        DCB     0       ; Interleave
        DCB     0       ; Side/Side sector skew
        DCB     0       ; Track/Track sector skew
        DCB     &A5     ; Fill value
        DCD     160     ; Tracks to format (2 sides of 80 tracks)
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill

FormatDFloppyPhysParams
FormatEFloppyPhysParams
        DCD     1024    ; Sector Size
        DCD     32+271  ; Gap 1, side 0
        DCD     32+0    ; Gap 1, side 1
        DCD     90      ; Gap 3
        DCB     5       ; Sectors per track
        DCB     DensityDouble
        DCB     FormatOptInterleaveSides
        DCB     0       ; LowSector
        DCB     0       ; Interleave
        DCB     0       ; Side/Side sector skew
        DCB     0       ; Track/Track sector skew
        DCB     &A5     ; Fill value
        DCD     160     ; Tracks to format (2 sides of 80 tracks)
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill

FormatFFloppyPhysParams
        DCD     1024    ; Sector Size
        DCD     50      ; Gap 1, side 0
        DCD     50      ; Gap 1, side 1
        DCD     90      ; Gap 3 - large to allow head switching between sectors and for greater reliability
        DCB     10      ; Sectors per track
        DCB     DensityQuad
        DCB     FormatOptInterleaveSides
        DCB     0       ; LowSector
        DCB     0       ; Interleave
 [ ExtraSkew
        DCB     1       ; Side/Side sector skew - enough for Iyonix controller set-up
        DCB     3       ; Track/Track sector skew - enough for head settle + set-up
 |
        DCB     0       ; Side/Side sector skew
        DCB     2       ; Track/Track sector skew - enough for head settle
 ]
        DCB     &A5     ; Fill value
        DCD     160     ; Tracks to format (2 sides of 80 tracks)
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill

FormatGFloppyPhysParams
        DCD     1024    ; Sector Size
        DCD     50      ; Gap 1, side 0
        DCD     50      ; Gap 1, side 1
        DCD     90      ; Gap 3 - large to allow head switching between sectors and for greater reliability
        DCB     20      ; Sectors per track
        DCB     DensityOctal
        DCB     FormatOptInterleaveSides
        DCB     0       ; LowSector
        DCB     0       ; Interleave
 [ ExtraSkew
        DCB     1       ; Side/Side sector skew - enough for Iyonix controller set-up
        DCB     5       ; Track/Track sector skew - enough for head settle + set-up
 |
        DCB     0       ; Side/Side sector skew
        DCB     4       ; Track/Track sector skew - enough for head settle
 ]
        DCB     &A5     ; Fill value
        DCD     160     ; Tracks to format (2 sides of 80 tracks)
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill
        DCD     0       ; Fill


; ====================
; DoSwiLayoutStructure
; ====================

; entry: R0 = identifier of particular disc structure to lay down
;               (R5 from Service_IdentifyFormat)
;               (pointer to a disc record (in ROM))
;        R1 = Pointer to bad block list
;        R2 = Pointer to nul terminated disc name
;        R3 = FileSwitch file handle of image

; exit:  Error possible, regs preserved

; The disc size filled in on the disc is the size of the
; image file. The disc size in the supplied disc record
; determines the amount of accessible disc (the remainder
; being mapped out as bad blocks).

        ^       0, sp
LayoutDiscRec   #       SzDiscRec
LayoutSz        *       :INDEX:{VAR}

DoSwiLayoutStructure ROUT
        Push    "r0-r11,lr"

 [ DebugO
 MOV    r11, sp
 DREG   r11, "sp in is "
 ]

        SUB     sp, sp, #LayoutSz

        ; Make a copy of the disc record on the stack
        ASSERT  SzDiscRecSig = 8*4
        ADR     r8, LayoutDiscRec

        LDMIA   r0!, {r4-r7}
        STMIA   r8!, {r4-r7}
        LDMIA   r0!, {r4-r7}
        STMIA   r8!, {r4-r7}

 [ BigMaps :LOR: BigDir
        ASSERT  DiscRecord_BigMap_DiscSize2-SzDiscRecSig=4
        ASSERT  SzDiscRecSig2-DiscRecord_BigMap_DiscSize2=4*4

        ; copy extra fields
        ADD     r8, r8, #4
        ADD     r0, r0, #4
        LDMIA   r0!, {r4-r7}
        STMIA   r8!, {r4-r7}
 ]

        ; If density=0 or zones>1 then must have a boot block
        LDRB    lr, LayoutDiscRec + DiscRecord_Density
        RSBS    lr, lr, #1
 [ BigMaps
        LDRLSB  lr, LayoutDiscRec + DiscRecord_NZones
        LDRLSB  r0, LayoutDiscRec + DiscRecord_BigMap_NZones2   ; top byte of zones number
        ADDLS   lr, lr, r0, LSL #8
 |
        LDRLSB  lr, LayoutDiscRec + DiscRecord_NZones
 ]
  [ DebugO
        DREG    lr, "zones from rec: "
  ]

        CMPLS   lr, #1
        ADR     r0, LayoutDiscRec
        BLHI    LayoutBootBlock

 [ DebugO
 BVS    %FT01
 DLINE  "LayoutBootBlock went OK"
01
 ]

        BLVC    LayoutFreeSpaceMap

 [ DebugO
 BVS    %FT01
 DLINE  "LayoutFreeSpaceMap went OK"
01
 ]

        BLVC    LayoutRootDir

 [ DebugO
 BVS    %FT01
 DLINE  "LayoutRootDir went OK"
01
 ]

        ; return
95
        ADD     sp, sp, #LayoutSz
 [ DebugO
 MOV    r11, sp
 DREG   r11, "sp out is "
 ]
        STRVS   r0, [sp]
        Pull    "r0-r11, pc"

        LTORG

; ===============
; LayoutBootBlock
; ===============

; entry: r0 = pointer to disc record
;        r1 = Pointer to bad block list
;        r2 = Pointer to nul terminated disc name
;        r3 = FileSwitch file handle of image

; exit:  Boot block laid out

LayoutBootBlock ROUT
        Push    "r0-r5,lr"

    [ BigSectors
        ; Check the zones and sector size don't result in an invalid combination
      [ BigMaps
        LDRB    r4, [r0, #DiscRecord_NZones]
        LDRB    r14, [r0, #DiscRecord_BigMap_NZones2]
        ADD     r4, r4, r14, LSL #8
      |
        LDRB    r4, [r0, #DiscRecord_NZones]
      ]
        TEQ     r4, #1
        BNE     %FT10                   ; Not the 1 zone case, all combinations valid

        LDRB    r4, [r0, #DiscRecord_Log2SectorSize]
        CMP     r4, #10
        MOVHI   r0, #MapFullErr         ; For 2k and 4k the map overlaps the boot block
        BHI     %FT90
        BCC     %FT10                   ; 256 & 512 are always safe
      [ BigDir
        LDR     r14, [r0, #DiscRecord_BigDir_DiscVersion]
        TEQ     r14, #0
        MOVEQ   r0, #DirFullErr         ; For 1k new dirs the root dir overlaps the boot block
        BEQ     %FT90                   ; while big dirs are OK as the root is in another object
      |
        MOV     r0, #DirFullErr
        B       %FT90
      ]
10
    ]
        ; Somewhere to construct the boot block
        MOV     r4, #ScratchSpace

        ; Zero out the area
        MOV     lr, #0
        ADD     r5, r4, #SzDefectList
10
        STR     lr, [r5, #-4]!
        CMP     r5, r4
        BHI     %BT10

        ; Copy the defect list
        MOV     r5, #0
10
        LDR     lr, [r1, r5]
        STR     lr, [r4, r5]
        CMP     lr, #DefectList_End
        ADDLO   r5, r5, #4
        CMPLO   r5, #SzDefectList - MaxStruc
        BLO     %BT10

 [ BigDisc
        ; if there's a second defect list present, then do it
        LDRB    lr, [r0, #DiscRecord_BigMap_Flags]
        TSTS    lr, #DiscRecord_BigMap_BigFlag
        BEQ     %FT15                   ; no second defect list
12
        LDR     lr, [r1, r5]
        STR     lr, [r4, r5]
        CMP     lr, #DefectList_BigMap_End
        ADDLO   r5, r5, #4
        CMPLO   r5, #SzDefectList - MaxStruc
        BLO     %BT12

15
 ]

        ; Check for too many defects
        CMP     r5, #SzDefectList - MaxStruc
        MOVHS   r0, #TooManyDefectsErr
        BHS     %FT90

        ; Construct defect list check byte
        MOV     r1, #0
        MOV     r5, r4
20
        LDR     lr, [r5], #4
        TSTS    lr, #DefectList_End
        EOREQ   r1, lr, r1, ROR #13
        BEQ     %BT20
        EOR     r1, r1, r1, LSR #16
        EOR     r1, r1, r1, LSR #8
        STRB    r1, [r5, #-4]

 [ BigDisc
        ; check again for presence of the second defect list
        LDRB    lr, [r0, #DiscRecord_BigMap_Flags]
        TSTS    lr, #DiscRecord_BigMap_BigFlag
        BEQ     %FT30                   ; no second defect list

        MOV     r1, #0
        MOV     r5, r4
25
        LDR     lr, [r5], #4
        TSTS    lr, #DefectList_BigMap_End
        EOREQ   r1, lr, r1, ROR #13
        BEQ     %BT25
        EOR     r1, r1, r1, LSR #16
        EOR     r1, r1, r1, LSR #8
        STRB    r1, [r5, #-4]

30
 ]
        ; Copy the disc record fields of relevance
        ASSERT  DiscRecord_Log2SectorSize :MOD: 4 = 0
        ASSERT  DiscRecord_SecsPerTrk = DiscRecord_Log2SectorSize + 1
        ASSERT  DiscRecord_Heads = DiscRecord_SecsPerTrk + 1
        ASSERT  DiscRecord_Density = DiscRecord_Heads + 1
        LDR     lr, [r0, #DiscRecord_Log2SectorSize]
        STR     lr, [r4, #DefectStruc + DiscRecord_Log2SectorSize]
        LDRB    lr, [r0, #DiscRecord_IdLen]
        STRB    lr, [r4, #DefectStruc + DiscRecord_IdLen]
        LDRB    lr, [r0, #DiscRecord_Log2bpmb]
        STRB    lr, [r4, #DefectStruc + DiscRecord_Log2bpmb]
        LDRB    lr, [r0, #DiscRecord_Skew]
        STRB    lr, [r4, #DefectStruc + DiscRecord_Skew]
        ASSERT  DiscRecord_LowSector :MOD: 4 = 0
        ASSERT  DiscRecord_NZones = DiscRecord_LowSector + 1
        ASSERT  DiscRecord_ZoneSpare = DiscRecord_NZones + 1
        LDR     lr, [r0, #DiscRecord_LowSector]
        STR     lr, [r4, #DefectStruc + DiscRecord_LowSector]
        LDR     lr, [r0, #DiscRecord_Root]
 [ DebugL
        DREG    lr, "Setting RootDir to (FormSWIs/LayoutBootBlock): "
 ]
        STR     lr, [r4, #DefectStruc + DiscRecord_Root]

 [ BigDisc
        ; Make sure the DiscSize2 field is zero for people trying to lay out things smaller
        ; than 4GB (and for OS_Args). The accurate size is fixed up in LayoutFreeSpaceMap later.
        MOV     r2, #0
        STR     r2, [r4, #DefectStruc + DiscRecord_BigMap_DiscSize2]

        LDR     lr, [r0, #DiscRecord_BigMap_ShareSize]
        STR     lr, [r4, #DefectStruc + DiscRecord_BigMap_ShareSize]
 ]

 [ BigMaps
        LDR     lr, [r0, #DiscRecord_BigDir_DiscVersion]
        STR     lr, [r4, #DefectStruc + DiscRecord_BigDir_DiscVersion]
 ]

 [ BigDir
        ; we don't copy the RootSize field into the boot block as the boot
        ; block should only be being used to locate the disc record in the map
 ]

        ; Obtain the 'Disc' size
        MOV     r0, #OSArgs_ReadEXT
        MOV     r1, r3
        BL      DoXOS_Args
        BVS     %FT95
        STR     r2, [r4, #DefectStruc + DiscRecord_DiscSize]
 [ DebugO
        DREG    r2, "Disc size in LayoutBootBlock is:"
 ]
        ; Fill in the boot block check byte
        MOV     r0, r4
        MOV     r1, #SzDefectList
        BL      CheckSum
        SUB     r1, r1, #1
        STRB    r2, [r4, r1]

        ; Write the boot block
        MOV     r0, #OSGBPB_WriteAtGiven
        MOV     r1, r3
        MOV     r2, #ScratchSpace
        MOV     r3, #SzDefectList
        MOV     r4, #DefectListDiscAdd
 [ DebugO
 DREG   r0,"OS_GBPB(",cc
 DREG   r1,",",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DLINE  ")"
 ]
        BL      DoXOS_GBPB
        BVS     %FT95

        MOV     r0, #0
90
        BL      SetVOnR0
95
        STRVS   r0, [sp]
        Pull    "r0-r5,pc"

; ==================
; LayoutFreeSpaceMap
; ==================

; entry: r0 = pointer to disc record
;        r1 = Pointer to bad block list
;        r2 = Pointer to nul terminated disc name
;        r3 = FileSwitch file handle of image

; exit:  Free space map laid out

LayoutFreeSpaceMap ROUT
        Push    "r0-r10,lr"

 [ DebugO
 DREG   r0, ">LayoutFreeSpaceMap(",cc
 DREG   r1, ",",cc
 DREG   r2, ",",cc
 DREG   r3, ",",cc
 DLINE  ")"
 ]

        ; r5 = disc record; r6 = nzones
        MOV     r5, r0
 [ BigMaps
        LDRB    r6, [r5, #DiscRecord_NZones]
        LDRB    lr, [r5, #DiscRecord_BigMap_NZones2]
        ORR     r6, r6, lr, LSL #8
 |
        LDRB    r6, [r5, #DiscRecord_NZones]
 ]
        TEQ     r6, #0
        BNE     %FT20

        ; 0 zones - must be old map
 [ DebugO
 DLINE  "Old map"
 ]

        ; Somewhere to construct the free space blocks
        MOV     r4, #ScratchSpace

        ; Zero out the area
        MOV     lr, #0
        ADD     r3, r4, #SzOldFs
10
        STR     lr, [r3, #-4]!
        CMP     r3, r4
        BHI     %BT10

        ; Obtain the 'Disc' size
        MOV     r0, #OSArgs_ReadEXT
        LDR     r1, [sp, #3*4]
        BL      DoXOS_Args
        BVS     %FT95

        ; Store the disc size
        MOV     r2, r2, LSR #8
        ASSERT  OldSize :MOD: 4 = 0
        STR     r2, [r4, #OldSize]

        ; If 1 head and
        ;    double density and
        ;    256 byte sectors and
        ;    lowsector = SequenceSides then must be L format
        LDRB    lr, [r5, #DiscRecord_Heads]
        TEQ     lr, #1
        LDREQB  lr, [r5, #DiscRecord_Density]
        TEQEQ   lr, #DensityDouble
        LDREQB  lr, [r5, #DiscRecord_Log2SectorSize]
        TEQEQ   lr, #8
        LDREQB  lr, [r5, #DiscRecord_LowSector]
        TEQEQ   lr, #DiscRecord_SequenceSides_Flag

        ; Set first free space to be beyond the first directory
        SUBEQ   r2, r2, #(OldDirSize + L_Root) :SHR: 8
        SUBNE   r2, r2, #(NewDirSize + D_Root) :SHR: 8
        ASSERT  FreeLen :MOD: 4 = 0
        STR     r2, [r4, #FreeLen]
        MOVEQ   r2, #(OldDirSize + L_Root) :SHR: 8
        MOVNE   r2, #(NewDirSize + D_Root) :SHR: 8
        BEQ     %FT15

        ASSERT  DefectListDiscAdd = NewDirSize + D_Root

        ; If density == 0 (hard disc) then there's a boot block to leave space for
        LDRB    lr, [r5, #DiscRecord_Density]
        TEQ     lr, #DensityFixedDisc
        ADDEQ   r2, r2, #SzDefectList

15
        ASSERT  FreeStart :MOD: 4 = 0
        STR     r2, [r4, #FreeStart]

        ; Set the free space list end
        MOV     r2, #3
        STRB    r2, [r4, #FreeEnd]

        ; Next copy the name in
        LDR     r2, [sp, #2*4]
        TEQ     r2, #0
        baddr   r2, anull, EQ
        LDRB    lr, [r2, #0]
        TEQ     lr, #0
        STRNEB  lr, [r4, #OldName0+0]
        LDRNEB  lr, [r2, #1]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #OldName1+0]
        LDRNEB  lr, [r2, #2]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #OldName0+1]
        LDRNEB  lr, [r2, #3]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #OldName1+1]
        LDRNEB  lr, [r2, #4]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #OldName0+2]
        LDRNEB  lr, [r2, #5]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #OldName1+2]
        LDRNEB  lr, [r2, #6]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #OldName0+3]
        LDRNEB  lr, [r2, #7]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #OldName1+3]
        LDRNEB  lr, [r2, #8]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #OldName0+4]
        LDRNEB  lr, [r2, #9]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #OldName1+4]

        ; Give it a random Id
        BL      GetRandomId
        STRB    lr, [r4, #OldId]
        MOV     lr, lr, LSR #8
        STRB    lr, [r4, #OldId+1]

        ; Construct the check bytes
        MOV     r0, r4
        MOV     r1, #SzOldFs/2
        BL      CheckSum
        STRB    r2, [r0,#Check0]
        ADD     r0, r0, #SzOldFs/2
        BL      CheckSum
        ASSERT  Check1-Check0=SzOldFs/2
        STRB    r2, [r0,#Check0]

        ; Write the map out
        MOV     r0, #OSGBPB_WriteAtGiven
        LDR     r1, [sp, #3*4]
        MOV     r2, r4
        MOV     r3, #SzOldFs
        MOV     r4, #0
 [ DebugO
 DREG   r0,"OS_GBPB(",cc
 DREG   r1,",",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DLINE  ")"
 ]
        BL      DoXOS_GBPB

        B       %FT95

20
        ; More than 0 zones - new map
 [ DebugO
 DLINE  "New map"
 DREG   r6, "nzones is "
 ]

        ; For each zone
        MOV     r8, #0
30
 [ DebugO
 DREG   r8, "Zone "
 ]
        ; Hold sector size (in bytes) in r9
        MOV     r9, #1
        LDRB    lr, [r5, #DiscRecord_Log2SectorSize]
        MOV     r9, r9, ASL lr
 [ DebugO
 DREG   r9, "Sector size is "
 ]
        ; Clear out the area for this zone's map block
        MOV     r4, #ScratchSpace
        ADD     r3, r4, r9
        MOV     lr, #0
35
        STR     lr, [r3, #-4]!
        CMP     r3, r4
        BHI     %BT35

 [ DebugO
 DLINE  "Scratch cleared"
 ]
        ; Normally map bits start at the zone head
        MOV     r7, #ZoneHead * 8
        CMP     r8, #0
        BNE     %FT40

 [ DebugO
 DLINE  "Zone 0 processing..."
 ]
        ; Except for zone 0 which must carry the disc record so loses some more map bits
        ADD     r7, r7, #Zone0Bits
        ADD     lr, r4, #ZoneHead
        MOV     r0, r5

 [ BigMaps
        ASSERT  SzDiscRecSig2 = 52

        LDMIA   r0!, {r1-r3,r10}
        STMIA   lr!, {r1-r3,r10}
        LDMIA   r0!, {r1-r3,r10}
        STMIA   lr!, {r1-r3,r10}
        LDMIA   r0,  {r0,r1-r3,r10}
        STMIA   lr!, {r0,r1-r3,r10}
 |
        ASSERT  SzDiscRecSig = 32
 [ BigDisc
        LDR     r1, [r0, #DiscRecord_BigMap_DiscSize2]
        STR     r1, [lr, #DiscRecord_BigMap_DiscSize2]
 ]
        LDMIA   r0!, {r1-r3,r10}
        STMIA   lr!, {r1-r3,r10}
        LDMIA   r0!, {r1-r3,r10}
        STMIA   lr!, {r1-r3,r10}
 ]

 [ DebugO
 DLINE  "Copied disc record"
 ]

        ; Fill in the correct disc size
        MOV     r0, #OSArgs_ReadEXT
        LDR     r1, [sp, #3*4]
 [ DebugO
 DREG   r0, "XOS_Args(",cc
 DREG   r1, ",",cc
 DLINE  ")"
 ]
        BL      DoXOS_Args
        BVS     %FT95
 [ DebugO
 DREG   r2, "Disc size is "
 ]
        STR     r2, [r4, #ZoneHead + DiscRecord_DiscSize]
 [ BigDisc
        MOV     r2, #0
        STR     r2, [r4, #ZoneHead + DiscRecord_BigMap_DiscSize2]

        LDR     r2, [r5, #DiscRecord_BigMap_ShareSize]          ; (and BigFlag, Zones2)
        STR     r2, [r4, #ZoneHead+DiscRecord_BigMap_ShareSize]
 ]

 [ BigMaps
        LDR     r2, [r5, #DiscRecord_BigDir_DiscVersion]
        STR     r2, [r4, #ZoneHead+DiscRecord_BigDir_DiscVersion]
 ]

 [ BigDir
        CMP     r2, #0
        MOVNE   r2, #BigDirMinSize              ; if big dirs, then store a 2048 byte dir min size
        STR     r2, [r4, #ZoneHead+DiscRecord_BigDir_RootDirSize]       ; otherwise store zero
 ]

        ; Fill in the disc name
        LDR     r2, [sp, #2*4]
        TEQ     r2, #0
        baddr   r2, anull, EQ
        LDRB    lr, [r2, #0]
        TEQ     lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+0]
        LDRNEB  lr, [r2, #1]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+1]
        LDRNEB  lr, [r2, #2]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+2]
        LDRNEB  lr, [r2, #3]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+3]
        LDRNEB  lr, [r2, #4]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+4]
        LDRNEB  lr, [r2, #5]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+5]
        LDRNEB  lr, [r2, #6]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+6]
        LDRNEB  lr, [r2, #7]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+7]
        LDRNEB  lr, [r2, #8]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+8]
        LDRNEB  lr, [r2, #9]
        TEQNE   lr, #0
        STRNEB  lr, [r4, #ZoneHead+DiscRecord_DiscName+9]

 [ DebugO
 DLINE  "Copied disc name"
 ]

        ; Generate a unique DiscId
        BL      GetRandomId
        STRB    lr, [r4, #ZoneHead+DiscRecord_DiscId+0]
        MOV     lr, lr, LSR #8
        STRB    lr, [r4, #ZoneHead+DiscRecord_DiscId+1]

40
        ; If it's the map zone allocate space for the map and root dir
        TEQ     r8, r6, LSR #1          ; map zone is at nzones/2
        BNE     %FT50

 [ DebugO
 DLINE  "Map zone processing..."
 ]

        ; It's the root dir zone - allocate space for the root dir
        MOV     r10, r4
        LDRB    r2, [r5, #DiscRecord_IdLen]
        MOV     r1, r7
        MOV     r0, #2                  ; Object 2 is map and directory

 [ BigMaps
        BL      PrimitiveFragWrLinkBits
 |
        BL      PrimitiveWrLinkBits     ; (r0,r1,r2,r10->)
 ]

 [ DebugO
 DLINE  "Object 2 written out"
 ]

        ; Calculate map and directory total size (in bytes)
        LDRB    r14, [r5, #DiscRecord_Density]
        ORR     r14, r6, r14, LSL #16
        TEQ     r14, #1

        ; 1 zone, density=0 means has boot block and need to faff with that situation
        MOVEQ   r0, #DefectListDiscAdd + SzDefectList
        SUBEQ   r14, r9, #1
        ADDEQ   r0, r0, r14
        BICEQ   r0, r0, r14             ; round up after boot block to nearest sector

        ; Normal case, more than 1 zone or a floppy disc
        LDRNEB  lr, [r5, #DiscRecord_Log2SectorSize]
        MOVNE   r0, r6, ASL lr          ; Map size (single)
        MOVNE   r0, r0, ASL #1          ; Map size (2 copies)

 [ BigDir
        LDR     lr, [r5, #DiscRecord_Root]      ; check if have big dirs
        MOV     lr, lr, LSR #8          ; isolate fragment id
        TEQS    lr, #2                  ; is it in the map object?
        ASSERT  NewDirSize = BigDirMinSize
        ADDEQ   r0, r0, #NewDirSize     ; if it is, then we account for the root dir with the map
 |
        ADD     r0, r0, #NewDirSize
 ]
        BL      RoundToObjSize          ; (r0,r5)->(r0)
        MOV     r1, r7
        MOV     r10, r4
 [ DebugO
 DREG   r0, "Writing out len bits:"
 ]
 [ BigMaps
        BL      PrimitiveFragWrLenBits
 |
        BL      PrimitiveWrLenBits
 ]
 [ DebugO
 DLINE  "Len bits written out"
 ]

        ; Advance free pointer to beyond the map
        ADD     r7, r7, r0

 [ BigMaps
        ; if the root dir is in an object of its own, then it needs
        ; some space allocating.  the root dir disc address has already
        ; been passed in, mind you; we simply write out an object of
        ; the appropriate size

        LDR     r0, [r5, #DiscRecord_Root]

        MOV     r0, r0, LSR #8          ; isolate fragment id
        TEQS    r0, #2                  ; is it in the map object?
        BEQ     %FT50                   ; yes, already counted above

        MOV     r1, r7

        MOV     r10, r4

        BL      PrimitiveFragWrLinkBits ; write 'em out

        ; then write out the length of the root dir object

        MOV     r0, #BigDirMinSize
        BL      RoundToObjSize          ; (r0, r5)->(r0)

        MOV     r1, r7
        MOV     r10, r4
        BL      PrimitiveFragWrLenBits  ; and the length

        ADD     r7, r7, r0              ; and advance free pointer beyond the root dir
 ]

50
        ; Reserve space for the boot block
        TEQ     r8, #0
        BNE     %FT60                   ; This is not zone 0
        TEQ     r6, #1                  
        BEQ     %FT60                   ; 1-zone fixed discs accounted for the boot block already
                                        ; 1-zone floppies don't have boot blocks
        MOV     r0, #2
        MOV     r1, r7
        LDRB    r2, [r5, #DiscRecord_IdLen]
        MOV     r10, r4
 [ DebugO
 DREG   r1, "Writing out boot block object 2 at "
 ]
 [ BigMaps
        BL      PrimitiveFragWrLinkBits
 |
        BL      PrimitiveWrLinkBits     ; (r0,r1,r2,r10->)
 ]

        ; Calculate boot block size
        MOV     r0, #DefectListDiscAdd + SzDefectList
        BL      RoundToObjSize          ; (r0,r5)->(r0)
        MOV     r1, r7
        MOV     r10, r4
 [ BigMaps
        BL      PrimitiveFragWrLenBits
 |
        BL      PrimitiveWrLenBits
 ]

 [ DebugO
 DREG   r0, "Writing out boot block length of "
 ]

        ; Advance free space ptr
        ADD     r7, r7, r0

60
        ; Write out the free block after the header (+zone0bits+boot block+map)

 [ DebugO
 DREG   r7, "First free fragment at "
 ]

        ; Work out the last bit position in this map block
        ADD     r3, r9, #ZoneHead
        MOV     r3, r3, ASL #3
        ASSERT  DiscRecord_ZoneSpare :MOD: 4 = 2
        LDR     lr, [r5, #DiscRecord_ZoneSpare-2]
        SUB     r3, r3, lr, LSR #16     ; Bit position of first unused bit

 [ DebugO
 DREG   r3, "Zone end at "
 ]

        ; Map out the disc's tail as bad blocks
        LDR     r0, [r5, #DiscRecord_DiscSize]
 [ BigDisc
        LDRB    lr, [r5, #DiscRecord_Log2SectorSize]    ; adjust for sector sizing
        MOV     r0, r0, LSR lr
 ]
        SUB     r10, r5, #ZoneHead
        BL      DiscAddToMapPtr         ; (r0,r10->r11,lr)
 [ DebugO
 DREG   r11, "r11: "
 DREG   lr, "lr: "
 DREG   r8, "Compare versus zone:"
 ]
        CMP     lr, r8
        BHI     %FT62

 [ DebugO
 DREG   r11,"Mapping out end of disc at offset:"
 ]

        ; This zone is a candidate for truncation
        MOVLO   r1, r7                  ; Whole of zone needs mapping out
        MOVEQ   r1, r11                 ; End of zone needs mapping out
        MOV     lr, r9, ASL #3
        SUB     lr, lr, #1              ; Sector size  (in bits) -1
        AND     r1, r11, lr             ; Offset within zone of start of bit to map out
        BL      AllocBitWidth           ; (r10->lr)
        SUB     lr, lr, #1
        BIC     r1, r1, lr              ; Align start down to allowable boundary
 [ DebugO
 DREG   r1, "Rounded down map-out position is "
 ]
        BL      MinMapObj               ; (r10->lr)
        SUB     r0, r3, r1              ; Space to chop off at the end
        CMP     r0, lr
        SUBLO   r1, r3, lr              ; Must be at least a MinMapObj
 [ DebugO
 DREG   r1, "After push-down:"
 ]
        SUB     r0, r1, r7              ; Space left for free fragment
        CMP     r0, lr
        MOVLO   r1, r7                  ; Not enough for a free fragment - drop mapped out area to start
 [ DebugO
 DREG   r1, "After free fragment lower-bounding "
 DREG   r3, "Zone end still at "
 ]

        ; Now construct the bad block
        MOV     r0, #1                  ; Id 1 for bad block
        MOV     r10, #ScratchSpace
        LDRB    r2, [r5, #DiscRecord_IdLen]
 [ DebugO
 DREG   r0, "Writing link bits=",cc
 DREG   r1, " at ",cc
 DREG   r2, " idlen=",cc
 DREG   r10, " into space at "
 ]

 [ BigMaps
        BL      PrimitiveFragWrLinkBits
 |
        BL      PrimitiveWrLinkBits     ; (r0,r1,r2,r10->)
 ]

        SUB     r0, r3, r1
 [ DebugO
 DREG   r3, "Zone end still at "
 DREG   r0, "Writing len bits=",cc
 DREG   r1, " at ",cc
 DREG   r2, " idlen=",cc
 DREG   r10, " into space at "
 ]
        MOV     r3, r1                  ; New 'end' of this block

 [ BigMaps
        BL      PrimitiveFragWrLenBits
 |
        BL      PrimitiveWrLenBits
 ]
 [ DebugO
 DREG   r1, "End of disc starts at ",cc
 DREG   r0, " and has length "
 ]

62
        LDRB    r2, [r5, #DiscRecord_IdLen]
        MOV     r1, r7
 [ DebugO
 DREG   r3, "Zone end is "
 ]
        SUBS    r0, r3, r7              ; Length of 0 means no free block
        MOVNE   r10, r4
 [ DebugO
 DREG   r0,"Free block len is "
 DREG   r1
 DREG   r2
 DREG   r10
 ]

 [ BigMaps
        BLNE    PrimitiveFreeWrLenBits
        MOVNE   r0, #0
        BLNE    PrimitiveFreeWrLinkBits
 |
        BLNE    PrimitiveWrLenBits
        MOVNE   r0, #0
        BLNE    PrimitiveWrLinkBits     ; (r0,r1,r2,r10->)
 ]

 [ DebugO
 DLINE  "Free block written out"
 ]

        ; Link it to free chain
        SUBNE   r0, r7, #FreeLink * 8
        MOVEQ   r0, #0
        MOV     r1, #FreeLink * 8
 [ BigMaps
        BL      PrimitiveFreeWrLinkBits
        MOV     r0, #16
        BL      PrimitiveFreeWrLenBits
 |
        BL      PrimitiveWrLinkBits     ; (r0,r1,r2,r10->)
        MOV     r0, #16
        BL      PrimitiveWrLenBits
 ]

 [ DebugO
 DLINE  "Free link written out"
 ]

        ; Map out the defects
        LDR     r3, [sp, #1*4]
 [ BigDisc
        LDRB    r1, [r5, #DiscRecord_Log2SectorSize]   ; sector size in r1
 ]
65
        LDR     r0, [r3], #4
 [ BigDisc
        TST     r0, #DefectList_End
   [ BigMaps
        BNE     %FT70
   |
        BNE     %FT80
   ]
        MOV     r0, r0, LSR r1          ; sector address
 |
        TST     r0, #DefectList_End
        BNE     %FT80
 ]
        BL      MapOutADefect
        BVS     %FT95
        B       %BT65

 [ BigMaps
70
        ; here we do any second defect list processing, if needed
        LDRB    lr, [r5, #DiscRecord_BigMap_Flags]
        TSTS    lr, #DiscRecord_BigMap_BigFlag
        BEQ     %FT80                   ; no second defect list

75
        LDR     r0, [r3], #4
        TST     r0, #DefectList_BigMap_End
        BNE     %FT80                   ; end of second defect list

        BL      MapOutADefect
        BVS     %FT95
        B       %BT75
 ]

80
        ; If it's the last map then cross check=&ff
        ADD     lr, r8, #1
        TEQ     lr, r6
        MOVEQ   lr, #&ff
        STREQB  lr, [r4, #CrossCheck]

        ; evaluate the map's check byte
        MOV     r1, r9
        MOV     r0, r4
        BL      SetNewCheck

 [ DebugO
 DLINE  "Check bytes processed"
 ]
        ; Write out the map block (1st copy)
        MOV     r3, r1
        MOV     r0, #OSGBPB_WriteAtGiven
        LDR     r1, [sp, #3*4]
        LDRB    r7, [r5, #DiscRecord_Log2SectorSize]
        MOV     r9, r6                  ; nzones

        BL      MapDiscAdd              ; (R5,R7,R9->R2)
        BIC     r2, r2, #DiscBits
 [ BigDisc
        MOV     r2, r2, LSL r7
 ]
        ADD     r4, r2, r8, ASL r7
        MOV     r2, #ScratchSpace
 [ DebugO
 DREG   r0,"OS_GBPB(",cc
 DREG   r1,",",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DLINE  ")"
 ]
        BL      DoXOS_GBPB
        BVS     %FT95

        ; Write out the map block (2nd copy)
        MOV     lr, #1
        MOV     r3, lr, ASL r7

        BL      MapDiscAdd              ; (R5,R7,R9->R2)
        BIC     r2, r2, #DiscBits
 [ BigDisc
        MOV     r2, r2, LSL r7
 ]
        ADD     r4, r2, r8, ASL r7
        ADD     r4, r4, r9, ASL r7
        MOV     r2, #ScratchSpace
 [ DebugO
 DREG   r0,"OS_GBPB(",cc
 DREG   r1,",",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DLINE  ")"
 ]
        BL      DoXOS_GBPB
        BVS     %FT95

        ; Advance to the next map block
        ADD     r8, r8, #1
 [ DebugO
        DREG    r6, "Zones are: "
 ]
        CMP     r8, r6
        BLO     %BT30

95
        STRVS   r0, [sp]
        Pull    "r0-r10,pc"

; =============
; LayoutRootDir
; =============

; entry: r0 = pointer to disc record
;        r1 = Pointer to bad block list
;        r2 = Pointer to nul terminated disc name
;        r3 = FileSwitch file handle of image

; exit:  Root directory laid out in ScratchSpace

LayoutRootDir ROUT
        Push    "r0-r9,lr"

 [ BigDir
        LDR     lr, [r0, #DiscRecord_BigDir_DiscVersion]
        TEQ     lr, #0
        BNE     %FT40                   ; long file names
 ]

 [ BigMaps
        LDRB    lr, [r0, #DiscRecord_NZones]
        LDRB    r5, [r0, #DiscRecord_BigMap_NZones2]
        ORR     lr, lr, r5, LSL #8
 |
        LDRB    lr, [r0, #DiscRecord_NZones]
 ]
        MOV     r5, r0
        TEQ     LR, #0
        BNE     %FT10

        ; Old map
        LDRB    lr, [r5, #DiscRecord_Heads]
        TEQ     lr, #1
        MOVEQ   r2, #L_Root
        MOVEQ   r3, #OldDirSize
        MOVNE   r2, #D_Root
        MOVNE   r3, #NewDirSize
        MOV     r8, r2, LSR #8          ; Ind. disc address (for parent) = disc address

        B       %FT20

10
        ; New map
        MOV     r3, #NewDirSize
 [ BigMaps
        LDRB    r9, [r5, #DiscRecord_NZones]
        LDRB    r7, [r5, #DiscRecord_BigMap_NZones2]
        ORR     r9, r9, r7, LSL #8
 |
        LDRB    r9, [r5, #DiscRecord_NZones]
 ]
        LDRB    r7, [r5, #DiscRecord_Log2SectorSize]

        ; Ignore where the punter said the root directory was, work it out
        ; from geometry as the disc record could be wrong

        BL      MapDiscAdd              ; (R5,R7,R9->R2)
        BIC     r2, r2, #DiscBits
 [ BigDisc
        MOV     r2, r2, LSL r7          ; Convert sector address to byte address
 ]

        LDRB    r14, [r5, #DiscRecord_Density]
        ORR     r14, r9, r14, LSL #16
        TEQ     r14, #1                 ; EQ iff density=0 zones=1

        ADDNE   r2, r2, r9, ASL r7      ; Miss 1st copy of map
        ADDNE   r2, r2, r9, ASL r7      ; Miss 2nd copy of map
        MOVEQ   r14, r14, LSL r7
        SUBEQ   r14, r14, #1            ; For rounding up to nearest sector
        ADDEQ   r2, r14, #DefectListDiscAdd + SzDefectList
        BICEQ   r2, r2, r14

        ; Same again but as an indirect disc address
        MOVNE   r8, r9, LSL #1          ; Miss 1 sector per map zone for each of two maps
        MOVEQ   r8, r2, LSR r7          ; As calculated earlier but in sectors
        ADD     r8, r8, #1              ; Natural numbers
        ORR     r8, r8, #&200           ; Fragment id 2
        
20
        ; r2 = address of root dir
        ; r3 = size of root dir
        ; r8 = Ind. disc address of root dir (for filling into parent field)
 [ DebugO
 DREG   r2, "Location of root dir is "
 DREG   r3, "Size of root dir is "
 ]

        ; Location of dir in RAM
        MOV     r4, #ScratchSpace

        ; Zero out the dir
        ADD     r1, r4, r3
        MOV     r0, #0
30
        STR     r0, [r1, #-4]!
        CMP     r1, r4
        BHI     %BT30

        ; Store HugoNick as appropriate
        LDRB    lr, [r5, #DiscRecord_NZones]
        TEQ     lr, #0
 [ BigMaps
        LDREQB  lr, [r5, #DiscRecord_BigMap_NZones2]    ; check also that Zones2 is 0
        TEQEQ   lr, #0
 ]
        LDREQB  lr, [r5, #DiscRecord_Heads]
        TEQEQ   lr, #1

        ; Toggle the Z bit
        TOGPSR  Z_bit, lr

        MOV     r5, r4
        ADD     r6, r5, r3
        BL      WriteNames      ; Preserves Z

        LDR     r1, [sp, #2*4]  ; Disc name

        ADDEQ   r4, r6, #NewDirName
        ADDNE   r4, r6, #OldDirName
        BL      WriteName       ;enter name (r1,r4)
        ADDEQ   r4, r6, #NewDirTitle
        ADDNE   r4, r6, #OldDirTitle
        BL      WriteName       ;enter title=name (r1,r4)

        ; Parent address
        STREQB  r8, [r6, #NewDirParent]
        STRNEB  r8, [r6, #OldDirParent]
        MOV     r8, r8, LSR #8
        STREQB  r8, [r6, #NewDirParent+1]
        STRNEB  r8, [r6, #OldDirParent+1]
        MOV     r8, r8, LSR #8
        STREQB  r8, [r6, #NewDirParent+2]
        STRNEB  r8, [r6, #OldDirParent+2]

        BL      TestDirCheckByte;(r3,r5,r6->lr)
        STRB    lr, [r6,#DirCheckByte]

        MOV     r0, #OSGBPB_WriteAtGiven
        LDR     r1, [sp, #3*4]
        MOV     r4, r2
        MOV     r2, #ScratchSpace
 [ DebugO
 DREG   r0,"OS_GBPB(",cc
 DREG   r1,",",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DLINE  ")"
 ]
        BL      DoXOS_GBPB

        STRVS   r0, [sp]
        Pull    "r0-r9,pc"

 [ BigDir

; here if Big Dir

40
        MOV     r5, r0

        LDRB    r9, [r5, #DiscRecord_NZones]
        LDRB    lr, [r5, #DiscRecord_BigMap_NZones2]
        ORR     r9, r9, lr, LSL #8              ; total zones
        LDRB    r7, [r5, #DiscRecord_Log2SectorSize]

        BL      MapDiscAdd                      ; (R5,R7,R9->R2)
        BIC     r2, r2, #DiscBits

        MOV     r2, r2, LSL r7

        ; now need to work out the offset from the map to the root dir.
        LDRB    r14, [r5, #DiscRecord_Density]
        ORR     r14, r9, r14, LSL #16
        TEQ     r14, #1                         ; EQ iff density=0 zones=1

        MOVNE   r0, r9, LSL r7                  ; size of a single map copy
        MOVNE   r0, r0, LSL #1                  ; size of two copies of map
        MOVEQ   r0, #DefectListDiscAdd + SzDefectList

        BL      RoundToObjSize                  ; (R0,R5 -> R0)

        LDRB    lr, [r5, #DiscRecord_Log2bpmb]

        ADD     r2, r2, r0, LSL lr              ; disc byte address of root dir

        MOV     r3, #BigDirMinSize              ; size of root dir in r3

        MOV     r4, #ScratchSpace               ; use scratch space to build dir

 [ DebugO
 DREG   r2, "Location of root dir is "
 DREG   r3, "Size of root dir is "
 ]

        ; Zero out the dir
        ADD     r1, r4, r3
        MOV     r0, #0
50
        STR     r0, [r1, #-4]!
        CMP     r1, r4
        BHI     %BT50

        ; now construct the directory

        LDR     lr, SBProven2   ; start name
        STR     lr, [r4, #BigDirStartName]

        MOV     lr, #1          ; length of dir name
        STR     lr, [r4, #BigDirNameLen]

        MOV     lr, #BigDirMinSize      ; size of dir
        STR     lr, [r4, #BigDirSize]

        MOV     lr, #0          ; entries
        STR     lr, [r4, #BigDirEntries]

        MOV     lr, #0          ; no names
        STR     lr, [r4, #BigDirNamesSize]

        LDR     lr, [r5, #DiscRecord_Root]      ; ind disc add of root dir
        STR     lr, [r4, #BigDirParent]

        MOV     lr, #'$'        ; dir name
        ADD     lr, lr, #&D00   ; and terminator

        STR     lr, [r4, #BigDirName]

        ; now the tail

        ADD     r6, r4, r3              ; end name
        LDR     lr, SBProven2+4
        STR     lr, [r6, #BigDirEndName]

        ; now the check byte

        MOV     r5, r4
        BL      TestBigDirCheckByte     ; (R5, R6->LR, Z)
        STRB    lr, [r6, #BigDirCheckByte] ; check byte now stored

        MOV     r0, #OSGBPB_WriteAtGiven
        LDR     r1, [sp, #3*4]
        MOV     r4, r2
        MOV     r2, #ScratchSpace
 [ DebugO
 DREG   r0,"OS_GBPB(",cc
 DREG   r1,",",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DLINE  ")"
 ]
        BL      DoXOS_GBPB

        STRVS   r0, [sp]
        Pull    "r0-r9,pc"


SBProven2
 = "SBPr"
 = "oven"

 ]

; ==============
; RoundToObjSize
; ==============

; entry
;       r0 = size (in bytes) of object
;       r5 = pointer to disc record

; exit
;       r0 = size (now in map bits) rounded up to correct object size

RoundToObjSize ROUT
        Push    "r1,lr"

        ; Lower bound to (idlen+1)<<BitSize in size
        LDRB    r1, [r5, #DiscRecord_IdLen]
        ADD     r1, r1, #1
        LDRB    lr, [r5, #DiscRecord_Log2bpmb]
        CMP     r0, r1, ASL lr
        MOVLO   r0, r1, ASL lr
 [ DebugO
        DREG    R0, "Lower bound to min map obj gives "
 ]

        ; Work out AllocSize-1
        LDRB    r1, [r5, #DiscRecord_Log2SectorSize]
        LDRB    lr, [r5, #DiscRecord_Log2bpmb]
        CMP     r1, lr
        MOVLO   r1, lr
        MOV     lr, #1
        MOV     lr, lr, ASL r1
        SUB     lr, lr, #1

        ; Round up to AllocSize
        ADD     r0, r0, lr
        BIC     r0, r0, lr
 [ DebugO
        DREG    R0, "Round up gives "
 ]

        ; Convert to map bits
        LDRB    r1, [r5, #DiscRecord_Log2bpmb]
        MOV     r0, r0, LSR r1
 [ DebugO
        DREG    R0, "Convert to bits gives "
 ]

        Pull    "r1,pc"


; =============
; MapOutADefect
; =============

; entry
;       r0 = disc address of defect
;       r5 -> disc record
;       r8 = zone

; exit
;       error possible

; map block for zone <r8> assumed held in ScratchSpace

; This mapping out does not merge adjacent bad block fragments
MapOutADefect ROUT
        Push    "r0-r11,lr"

        SUB     r10, r5, #ZoneHead
        BL      DiscAddToMapPtr         ;(r0,r10->r11,lr)
        TEQ     lr, r8
        BNE     %FT95                   ; not this zone

        LDRB    r0, [r5, #DiscRecord_Log2SectorSize]
        MOV     lr, #8
        MOV     r0, lr, ASL r0
        SUB     r0, r0, #1
        AND     r6, r11, r0             ; Map ptr :MOD: sector size (in bits)

 [ DebugO
 DREG   r8, "Mapping out defect at zone ",cc
 DREG   r6, " offset "
 ]

        LDRB    r2, [r5, #DiscRecord_IdLen]
        MOV     r10, #ScratchSpace
        MOV     r3, #FreeLink*8         ; FreeLink
        MOV     r11, r3
        MOV     r0, r8
 [ BigMaps
        BL      PrimitiveFreeRdLinkBits ; (r10,r11->r8,Z)
 |
        BL      PrimitiveRdLinkBits     ; (r10,r11->r8,Z)
 ]
        ADD     r4, r3, r8              ; 1st free fragment
        MOV     r11, #ZoneHead * 8
        TEQ     r0, #0
        ADDEQ   r11, r11, #Zone0Bits    ; 1st fragment
        LDRB    r9, [r5, #DiscRecord_Log2SectorSize]
        MOV     lr, #8
        MOV     r9, lr, ASL r9
        ADD     r9, r9, #ZoneHead*8
        ASSERT  DiscRecord_ZoneSpare:MOD:4 = 2
        LDR     lr, [r5, #DiscRecord_ZoneSpare-2]
        SUB     r9, r9, lr, LSR #16     ; End of zone

10
 [ DebugO
 DREG   r11, "P:",cc
 DREG   r4, " F:",cc
 DREG   r3, " PF:"
 ]

 [ BigMaps
        BL      PrimitiveFragRdLenBits
 |
        BL      PrimitiveRdLenBits
 ]
        ADD     LR, R11, R7
        CMP     LR, R6
        BHI     %FT15                   ; Fragment encompasses bad block
        TEQ     R11, R4
        BNE     %FT12


 [ BigMaps
        BL      PrimitiveFreeRdLinkBits ; (r2,r10,r11->r8,Z) Next free fragment
 |
        BL      PrimitiveRdLinkBits     ; (r2,r10,r11->r8,Z) Next free fragment
 ]
        MOV     R3, R4
        ADD     R4, R4, R8

12
        ADD     r11, r11, r7            ; next fragment
        CMP     R11, R9                 ; Ended?
        BLO     %BT10                   ; No

 [ DebugO
 DLINE  "No fragment containing fragment - bad news!"
 ]

        ; Bad block not in zone after all - bad situation
        MOV     r0, #DefectErr
        SETV
        B       %FT95

15
        ; Defect found in a fragment:
        ; R2 - idlen
        ; R3 - previous free fragment
        ; R4 - this (next) free fragment
        ; R5 - ptr to disc record
        ; R6 - Bad block's map ptr
        ; R7 - this fragment's length
        ; R9 - Zone end (bit address)
        ; R10 - ScratchSpace
        ; R11 - fragment start
        ; LR - next fragment start

        TEQ     r11, r4
        BEQ     %FT20

 [ DebugO
 DLINE  "Fragment containing bad block isn't free"
 ]

        ; Fragment encompassing defect not free, but is it already a bad block?
 [ BigMaps
        BL      PrimitiveFragRdLinkBits
 |
        BL      PrimitiveRdLinkBits
 ]
        TEQ     r8, #1
        MOVNE   r0, #DefectErr
        SETV    NE
        B       %FT95

20
        ; Defect found in a free block

        ; Get some useful figures
        SUB     r10, r5, #ZoneHead
        BL      AllocBitWidth           ; (r10->lr)
        SUB     lr, lr, #1
        BIC     r6, r6, lr              ; Start of alloc unit containing defect
        BL      MinMapObj               ; (r10->lr)
        MOV     r1, lr

 [ DebugO
 DREG   r6, "Rounded down bad block location:"
 DREG   r1, "MinMapObj:"
 ]

        ; Push bad block position down if not enough room after it for a whole fragment
        ADD     r1, r11, r7             ; End of fragment containing bad block
        SUB     r0, r1, r6              ; Space after bad block
        CMP     r0, lr
        SUBLO   r6, r1, lr

 [ DebugO
 DREG   r6, "Bad location after push-down:"
 ]

        ; If no room for a fragment before the bad block
        ; move bad block start to start of free area.
        SUB     r0, r6, r11             ; space before bad block
        CMP     r0, lr
        MOVLO   r6, r11
        BLO     %FT30

        ; There is room before the bad block for a free block

 [ DebugO
 DLINE  "There's room before the bad block"
 ]

        ; Check the room after the bad block
        ADD     r0, r11, r7             ; End of free block containing defect
        SUB     r0, r0, r6              ; Space from start of defect fragment to end of free fragment
        SUB     r0, r0, lr              ; Space from end of defect fragment to end of free fragment (>=0 guaranteed)
        CMP     r0, #0
        CMPNE   r0, lr
        BHS     %FT25                   ; no space or enough space already for a fragment - don't move the bad block fragment
        ADD     r0, r0, r6
        SUB     r0, r0, r11             ; Added in space before the fragment
        CMP     r0, lr, ASL #1
        BLO     %FT25                   ; Not enough space for two fragments - don't move the bad block

 [ DebugO
 DLINE  "Bad block shuffle needed to give two free blocks"
 ]

        ; Move the bad fragment down to give room for a free fragment after it
        ADD     r6, r11, r7             ; End of free fragment
        SUB     r6, r6, lr, ASL #1      ; Less two MinMapObjs - one for the free fragment, one for the bad fragment

25
        ; Must detach the free fragment before the bad block fragment
 [ DebugO
 DLINE  "Shortening first free fragment"
 ]
        SUB     r0, r6, r11
        MOV     r1, r11
        MOV     r10, #ScratchSpace
 [ BigMaps
        BL      PrimitiveFreeWrLenBits
 |
        BL      PrimitiveWrLenBits
 ]

        ; Prev free is now this detached thingy
        MOV     r3, r11

        B       %FT40

30
        ; There isn't room before the bad block fragment for a free block

 [ DebugO
 DLINE  "No room for a free fragment before bad block - detaching free fragment from free chain"
 ]

        ; Detach the free block from the free chain
        MOV     r10, #ScratchSpace
 [ BigMaps
        BL      PrimitiveFreeRdLinkBits
 |
        BL      PrimitiveRdLinkBits
 ]
        TEQ     r8, #0
        MOVEQ   r0, #0
        ADDNE   r0, r8, r11
        SUBNE   r0, r0, r3
        MOV     r1, r3
 [ BigMaps
        BL      PrimitiveFreeWrLinkBits
 |
        BL      PrimitiveWrLinkBits     ; (r0,r1,r2,r10->)
 ]

        ; New start of bad block fragment
        MOV     r6, r11


40
        ; Deal with any free fragment after the bad block fragment:
        ; r2 - idlen
        ; r3 - previous free fragment
        ; r5 - ptr to disc record
        ; r6 = MapPtr of fragment containing the bad block (in its right place)
        ; r7 - this fragment's length
        ; r9 - Zone end (bit address)
        ; r11 = start of free fragment out of which the bad block fragment is being carved

        ; Generate the bad block
 [ DebugO
 DLINE  "Writing out bad block Id"
 ]
        MOV     r0, #1                  ; Bad block ID
        MOV     r1, r6
        MOV     r10, #ScratchSpace
 [ BigMaps
        BL      PrimitiveFragWrLinkBits
 |
        BL      PrimitiveWrLinkBits     ; (r0,r1,r2,r10->)
 ]

        ; Now determine its length
        ADD     r4, r11, r7             ; End of free fragment (end of bad block fragment later)
        SUB     r10, r5, #ZoneHead
        BL      MinMapObj               ; (r10->lr)
        ADD     r1, r6, lr              ; End of bad block fragment
        SUB     r0, r4, r1              ; Space after bad fragment left in free fragment
        CMP     r0, lr                  ; enough for a free block?
        BLO     %FT50                   ; No

        ; Enough space for a free fragment after the bad block - create it
 [ DebugO
 DLINE  "Room after bad block for a free fragment - attaching this into the free chain"
 ]

        ; Attach prev->next to this->next
        MOV     r11, r3
        MOV     r10, #ScratchSpace
 [ BigMaps
        BL      PrimitiveFreeRdLinkBits     ; (r2,r10,r11->r8)
 |
        BL      PrimitiveRdLinkBits     ; (r2,r10,r11->r8)
 ]
        TEQ     r8, #0
        MOVEQ   r0, r8
        ADDNE   r0, r8, r11
        SUBNE   r0, r0, r1
 [ BigMaps
        BL      PrimitiveFreeWrLinkBits ; (r0,r1,r2,r10->)
 |
        BL      PrimitiveWrLinkBits     ; (r0,r1,r2,r10->)
 ]
        MOV     r4, r1                  ; Hold end of bad block fragment

        ; Attach this to prev->next
        SUB     r0, r1, r3
        MOV     r1, r3
 [ BigMaps
        BL      PrimitiveFreeWrLinkBits
 |
        BL      PrimitiveWrLinkBits     ; (r0,r1,r2,r10->)
 ]

50
        ; r4 is end of bad block fragment

        ; Write the length of the bad block fragment
 [ DebugO
 DLINE  "Writing out bad block fragment's length"
 ]
        MOV     r10, #ScratchSpace
        SUB     r0, r4, r6
        MOV     r1, r6
 [ BigMaps
        BL      PrimitiveFragWrLenBits
 |
        BL      PrimitiveWrLenBits
 ]

95
        STRVS   r0, [sp]
        Pull    "r0-r11,pc"


; ========
; CallASwi
; ========

; entry: r11 = SWI number
;       other regs parameters to SWI

; exit:  As per SWI

CallASwi ROUT

        Push    "r10,lr"

        ; 'Leave' FileCore out the bottom - but allow reentry (once)
        TEQ     SB, #0
        BLNE    DoExternal
        
        ; OS_CallASWI uses r10 for SWI number, also ensure it's an X SWI
        ORR     r10,r11,#Auto_Error_SWI_bit  
        SWI     XOS_CallASWI

        ; 'Enter' FileCore.
        TEQ     SB, #0
        BLNE    Internal

        Pull    "r10,pc"

        END
