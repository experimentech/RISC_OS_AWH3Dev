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
; >RamFS50

        TTL     "Initialisation and FS star commands"
; SecPerTrack needs to be larger than 1 to prevent track count
; exceeding its max and 'blowing' part of RAMFSFiler

SkeletonDiscRec         ; fields marked * need filling in
        DCB     MyLog2SectorSize ; Log2SectorSize
        DCB     128     ; SecPerTrk (this is a RAM disc)
        DCB     1       ; Heads
        DCB     DensitySingle  ; Density
        DCB     0       ; * IdLen
        DCB     0       ; * Log2bpmb
        DCB     0       ; Skew
        DCB     0       ; BootOpt
        DCB     0       ; LowSector
        DCB     0       ; * NZones
        DCW     0       ; * ZoneSpare
        DCD     0       ; * Root
        DCD     0       ; * DiscSize
        DCW     0       ; DiscId
        DCB     "RamDisc0",0,0 ; DiscName (padded to 10 bytes)
        DCD     0       ; DiscType
        DCD     0       ; DiscSize2
        DCB     0       ; ShareSize
        DCB     0       ; Flags
      [ BigDir
        DCB     0       ; NZones2
        DCB     0       ; Reserved
        DCD     1       ; DiscVersion
        DCD     BigDirMinSize  ; RootDirSize
      |
        DCB     0       ; NZones2
        DCB     0       ; Reserved
        DCD     0       ; DiscVersion
        DCD     0       ; RootDirSize
      ]
        ASSERT  {PC} - SkeletonDiscRec = SzDiscRecSig2

FullTitle
        DCB     "FileCore%RAM", 0

RAMdiscName
        DCB     "RAM::RamDisc0",0

RamFSString     = "RAM",0
        ALIGN

FSCreateBlock
      [ BigDisc2
        DCB     CreateFlag_NoBigBuf, (CreateFlag_NewErrorSupport + CreateFlag_BigDiscSupport):SHR:8, 0
      |
        DCB     CreateFlag_NoBigBuf, CreateFlag_NewErrorSupport:SHR:8, 0
      ]
        DCB     fsnumber_ramfs
        DCD     RamFSString     - Module_BaseAddr
        DCD     RamFSBootText   - Module_BaseAddr
        DCD     LowLevelEntry   - Module_BaseAddr
        DCD     MiscEntry       - Module_BaseAddr

EmptyDefectList
        DCD     DefectList_End
      [ BigDisc2
        DCD     DefectList_BigMap_End
      ]

InitRAMDisc ROUT
        Push    "R0-R11, LR"
        ADRL    r0, RAMDisc_DismountStr
        SWI     XOS_CLI

        SWI     XOS_ReadRAMFsLimits             ; (->R0,R1)

        SUBS    r6, r1, r0
        BEQ     %FT85

        MOV     r1, #MyMinSupportedDriveSize:SHR:2
        MOV     r2, #0
10
        STR     r2, [r0], #4                    ; Wipe out where the disc record will go
        SUBS    r1, r1, #4
        BNE     %BT10

        SUB     sp, sp, #SzDiscRecSig2

        ADRL    R0, SkeletonDiscRec             ; source

        MOV     R1, SP                          ; dest
        MOV     R2, #SzDiscRecSig2              ; length

20
        LDR     R3, [R0], #4
        STR     R3, [R1], #4
        SUBS    R2, R2, #4
        BNE     %BT20

        STR     R6, [SP, #DiscRecord_DiscSize]  ; store away the size

        MOV     r5, SP
        BL      InitDiscRec                     ; fill in the disc record fields which need calculation

        MOV     r1, #DiscOp_WriteTrk
        SUB     sp, sp, #SzExtendedDiscAddress
        MOV     r2, sp
        ASSERT  MyMaxSupportedDrive = 0
        ASSERT  SzExtendedDiscAddress = 12
        MOV     r0, #0
        MOV     r3, #0
        MOV     r4, #0
        STMIA   r2, {r0,r3,r4}                  ; byte address 0 on drive 0
        MOV     r3, #0
        MOV     r4, #1:SHL:MyLog2SectorSize
        LDR     r8, FileCorePrivate
        SWI     XFileCore_DiscOp64
        ADD     sp, sp, #SzExtendedDiscAddress
        BVC     %FT30
        LDR     lr, [r0, #0]
        TEQ     lr, #ErrorNumber_ModuleBadSWI
        BNE     %FT75

        ORR     r1, r1, r5, LSL #6              ; point to alternative record in r1
        ASSERT  MyMaxSupportedDrive = 0
        MOV     r2, #0                          ; byte address 0 on drive 0
        SWI     XFileCore_DiscOp

        BVS     %FT75

30      MOV     r0, #open_update :OR: open_nopath :OR: open_nodir :OR: open_mustopen
        ADRL    r1, RAMDisc_RAMdiscName         ; name ptr
        SWI     XOS_Find                        ; find it

        BVS     %FT75                           ; failed to do so

        MOV     R3, R0

        MOV     r0, sp
        ADRL    r1, EmptyDefectList             ; no bad block list
        ADRL    r2, RAMDisc_JustDiscName        ; disc name

        SWI     XFileCore_LayoutStructure

        MOV     r0, #0
        MOV     r1, r3
        SWI     XOS_Find

        ADRL    r0, RAMDisc_DismountStr
        SWI     XOS_CLI

75
        ADD     sp, sp, #SzDiscRecSig2

85
        STRVS   r0, [sp]
        Pull    "R0-R11, PC"


RAMDisc_JustDiscName
        DCB     "RamDisc0",0
        ALIGN
RAMDisc_RAMdiscName
        DCB     "RAM::0",0
        ALIGN
RAMDisc_DismountStr
        DCB     "RAM:Dismount :0",0
RAMDisc_MountStr
        DCB     "RAM:mount :0",0
        ALIGN

; InitDiscRec
; -----------
; This routine generates the values in the disc record to suit the
; chosen size of the RAM disc.  We need to work out the values, and
; place them in a disc record
; Entry: R5 = pointer to disc record
; Exit : Disc record updated
InitDiscRec     ROUT
        Push    "R0-R11, LR"

        ; internal register allocation:
        ; r0 = current bitsize
        ; r1 = current zonespare
        ; r2 = current zones
        ; r3 = current idlen
        ; r4 = map allocation bits required to cover disc
        ; r5 = disc record
        ; r6 = number of bits in a zone
        ; r7 = number of allocation bits in the map
        ; r8 = ids per zone
Min_IdLen       *       MyLog2SectorSize + 3 ; min allowed idlen = log2(bits in a sector)
      [ BigMaps
Max_IdLen       *       19      ; max allowed idlen
      |
Max_IdLen       *       15      ; max allowed idlen
      ]
Min_Log2bpmb    *       7       ; min allowed bytes per map bit
Max_Log2bpmb    *       12      ; max allowed bytes per map bit
Min_ZoneSpare   *       32      ; min allowed zonespare
Max_ZoneSpare   *       64      ; max allowed zonespare
Min_Zones       *       1       ; min allowed zones
Max_Zones       *       16      ; max allowed zones

        MOV     r0, #Min_Log2bpmb                ; init log2bpmb

10      ; loop on log2bpmb
        LDR     r4, [r5, #DiscRecord_DiscSize]
        MOV     r4, r4, LSR r0                  ; map bits for disc

        MOV     r1, #Min_ZoneSpare              ; init ZoneSpare
20      ; loop on zonespare

        LDR     lr, [r5, #DiscRecord_Log2SectorSize]
        MOV     r6, #8
        MOV     r6, r6, LSL lr                  ; bits in a zone
        SUB     r6, r6, r1                      ; minus sparebits

        ; choose number of zones to suit

        MOV     r2, #Min_Zones                  ; minimum of one zone
      [ Min_Zones > 1
        MUL     r7, r6, r2
        SUB     r7, r7, #Zone0Bits              ; bits in zone 0
      |
        SUB     r7, r6, #Zone0Bits              ; bits in zone 0
      ]
30      ; loop for zones
        CMP     r7, r4                          ; do we have enough allocation bits yet?
        BHS     %FT35                           ; if we do, then accept this number of zones

        ADD     r7, r7, r6                      ; more map bits
        ADD     r2, r2, #1                      ; and another zone
        CMPS    r2, #Max_Zones
        BLS     %BT30                           ; still ok

        ; here when too many zones; try a higher Log2bpmb
        B       %FT80

35
        ; now we have to choose idlen.  we want idlen to be
        ; the smallest it can be for the disc.

        MOV     r3, #Min_IdLen                  ; minimum value of idlen

40      ; loop for IdLen

        Push    "R0, R1, R2"
        MOV     r0, r6                          ; allocation bits in a zone
        ADD     r1, r3, #1                      ; idlen+1
        DivRem  r8, r0, r1, r2, norem
        Pull    "R0, R1, R2"

        ; check that IdLen is enough for total possible ids
        MOV     r9, #1                          ; work out 1<<idlen
        MOV     r9, r9, LSL r3                  ;

        MUL     lr, r8, r2                      ; total ids needed
        CMPS    lr, r9                          ; idlen too small?
        BHI     %FT60                           ; yes!

        ; we're nearly there.  now work out if the last zone
        ; can be handled correctly.

        SUBS    lr, r7, r4
        BEQ     %FT50

        CMPS    lr, r3                          ; must be at least idlen+1 bits
        BLE     %FT60

        ; check also that we're not too close to the start of the zone

        SUB     lr, r7, r6                      ; get the start of the zone

        SUB     lr, r4, lr                      ; lr = bits available in last zone
        CMPS    lr, r3
        BLE     %FT60

        ; if the last zone is the map zone (ie nzones <= 2), check it's
        ; big enough to hold 2 copies of the map + the root directory
        CMP     r2, #2
        BGT     %FT50

        LDR     r10, [r5, #DiscRecord_Log2SectorSize]
        MOV     r9, #2
        MOV     r10, r9, LSL r10
        MUL     r10, r2, r10                    ; r10 = 2 * map size (in disc bytes)
        MOV     r11, #1
        RSB     r11, r11, r11, LSL r0           ; r11 = LFAU-1 (in disc bytes), for rounding up
        LDR     r9, [r5, #DiscRecord_BigDir_DiscVersion]
        TEQ     r9, #0
        ADDEQ   r10, r10, #NewDirSize           ; short filename: add dir size to map
        BEQ     %FT45

        ; long filename case - root directory is separate object in map zone
        ADD     r9, r11, #BigDirMinSize
        MOV     r9, r9, LSR r0                  ; r9 = directory size (in map bits)
        CMPS    r9, r3
        ADDLE   r9, r3, #1                      ; ensure at least idlen+1
        SUBS    lr, lr, r9
        BLT     %FT60
        ; fall through to consider map object

45      ADD     r10, r10, r11
        MOV     r10, r10, LSR r0                ; r10 = map (+dir) size (in map bits)
        CMPS    r10, r3
        ADDLE   r10, r3, #1                     ; ensure at least idlen+1
        CMPS    lr, r10
        BLT     %FT60

50      ; we've found a result - fill in the disc record!

        STRB    r3,[r5, #DiscRecord_IdLen]      ; => set idlen

        MOV     r1, r1, LSL #16
        ORR     r1, r1, r2, LSL #8
        STR     r1, [r5, #DiscRecord_ZoneSpare - 2]  ; => set ZoneSpare and NZones

        STRB    r0, [r5, #DiscRecord_Log2bpmb]  ; => set Log2bpmb

        LDR     lr, [r5, #DiscRecord_BigDir_DiscVersion]
        TEQ     lr, #1                          ; do we have long filenames?
        BNE     %FT01

        ; the root dir's ID is the first available ID in the middle
        ; zone of the map

        MOVS    r2, r2, LSR #1                  ; zones/2

        MULNE   lr, r2, r8                      ; *idsperzone
        MOVEQ   lr, #3                          ; if if zones/2=0, then only one zone, so the id is 3 (0,1,2 reserved)

        MOV     lr, lr, LSL #8                  ; construct full indirect disc address
        ORR     lr, lr, #1                      ; with sharing offset of 1

        B       %FT02
01
        ; not long filenames
        ; root dir is &2nn where nn is ((zones<<1)+1)

        MOV     lr, r2, LSL #1
        ADD     lr, lr, #1
        ADD     lr, lr, #&200
02
        STR     lr, [r5, #DiscRecord_Root]      ; => set Root

        ; other fields in the disc record are fixed-value
        B       %FT90

60      ; NEXT IdLen
        ADD     r3, r3, #1
        CMPS    r3, #Max_IdLen
        BLS     %BT40

70      ; NEXT ZoneSpare
        ADD     r1, r1, #1
        CMPS    r1, #Max_ZoneSpare
        BLS     %BT20

80      ; NEXT Log2bpmb
        ADD     r0, r0, #1
        CMPS    r0, #Max_Log2bpmb               ; is it too much?
        BLS     %BT10                           ; back around

90
      [ BigDisc2
        ; Ensure the big disc flag is set correctly
        LDR     r4, [r5, #DiscRecord_DiscSize]
        CMP     r4, #512<<20
        LDRB    r4, [r5, #DiscRecord_BigMap_Flags]
        BICLS   r4, r4, #DiscRecord_BigMap_BigFlag
        ORRHI   r4, r4, #DiscRecord_BigMap_BigFlag
        STRB    r4, [r5, #DiscRecord_BigMap_Flags]
      ]   
        Pull    "R0-R11, PC"

; InitEntry
; ---------
; Module initialisation
InitEntry ROUT
        Push    "R0-R11, SB, LR"

      [ Debug3
        DLINE   "RAMFS Init"
      ]

        SWI     XOS_ReadRAMFsLimits             ; (->R0,R1)
        SUB     R6, R1, R0                      ; RAM disc size
        Push    "R0"

        MOV     R9, #0                          ; error flag
        MOV     R10, #1                         ; init error reporting control flag
        MOV     R11, SB

        MOV     R0, #ModHandReason_Claim
        MOV     R3, #:INDEX: WorkSize
        SWI     XOS_Module                      ; claim workspace

        Pull    "R4"                            ; -> RAM disc start
        BVS     %FT95
        MOV     SB, R2

        ; OSS Flag that the message file is closed.
        MOV     r0, #0
        STR     r0, message_file_open
 [ PMP
        STR     r0, LRUCache
 ]

        CMPS    R6, #MyMinSupportedDriveSize    ; Only initialise if at least this must RAM
        BCC     %FT60

        ASSERT  :INDEX: BufferStart=0
        ASSERT  :INDEX: BufferSize=4
        STMIA   SB, {R4,R6}

        STR     R11, MyPrivate

        STR     SB, [R11]

 [ PMP
        ; Check if PMP is in use
        MOV     r0, #24
        MOV     r1, #ChangeDyn_RamFS
        SWI     XOS_DynamicArea
        BVS     %FT17
        TST     r4, #1:SHL:20
        BEQ     %FT17
        ; PMP enabled - store details and init the LRU cache
        MOV     r5, r5, LSR #12
        STR     r4, PageFlags                   ; These are the full DA flags rather than just the page flags, but the kernel will mask them down as necessary
        STR     r5, PMPSize
        MOV     r0, #ModHandReason_Claim
        MOV     r3, r5, LSL #3
        SWI     XOS_Module
        BVS     %FT85
        STR     r2, LRUCache
        ; Init LRU cache
        SUB     r0, r5, #1                      ; DA logical page index
        MOV     r1, #-1                         ; No physical page mapped there
10
        STMIA   r2!, {r0, r1}
        SUBS    r0, r0, #1
        BGE     %BT10
        ; Unmap anything which is already there, to ensure state matches cache
        MOV     r0, #0
        MOV     r2, #-1
        MOV     r4, #0
        Push    "r0,r2,r3"
        MOV     r0, #22
15
        MOV     r2, sp
        MOV     r3, #1
        SWI     XOS_DynamicArea
        BVS     %FT16
        ADD     r4, r4, #1
        CMP     r4, r5
        STRLT   r4, [sp]
        BLT     %BT15
16
        ADD     sp, sp, #12
17
 ]

        ADR     R0, FSCreateBlock
        ADRL    R1, Module_BaseAddr
        LDR     r2, MyPrivate
      [ BigDir
        ASSERT  MyMaxSupportedDrive = 0
        MOV     R3, #1                          ; 1 floppy, 0 fixed disc, default drive 0, dir
        MOV     R4, #65536                      ; dir cache size
      |
        ASSERT  MyMaxSupportedDrive = 0
        MOV     R3, #1                          ; 1 floppy, 0 fixed discs, default drive 0, dir
        MOV     R4, #0                          ; dir cache size
      ]
        MOV     R5, #0                          ; File cache buffers
        MOV     R6, #0                          ; fixed disc sizes
        SWI     XFileCore_Create                ; (R0-R6->R0-R2,V)
        BVS     %FT85                           ; Filecore_Create failed

        STR     R0, FileCorePrivate

        BL      InitRAMDisc                     ; just in case the Kernel hasn't done it

        CLRV
        Pull    "R0-R11, SB, PC"

60
        ; OSS Error handling code for "Ram Disc too small"
        ADR     R0, ErrSizeTooSmall
        MOV     R1, #0                          ; No %0
        BL      copy_error_one                  ; Always sets the V bit
        B       %FT85

ErrSizeTooSmall
        DCD     ErrorNumber_RAMDiscTooSmall
        DCB     "SizeErr", 0
        ALIGN

; InitEntry
; ---------
; Module finalisation
DieEntry
        Push    "R0-R11, SB, LR"

      [ Debug3
        DLINE   "RAMFS Die"
      ]
        LDR     SB, [SB]
        MOV     R9, #0                          ; error flag
        MOV     R10, #0                         ; die error reporting control flag

        ; Dismount the disk so filer windows close
        MOV     R1, #Service_DiscDismounted
        ADRL    R2, RAMdiscName                 ; Disc to dismount
        SWI     XOS_ServiceCall                 ; Dismount RAM

      [ Debug3
        DLINE   "Killing FileCore%RAM parent"
      ]

        MOV     R0, #ModHandReason_Delete
        ADRL    R1, FullTitle
        SWI     XOS_Module
      [ Debug3
        DLINE   "Killed parent"
      ]

85
        ; OSS Close the Messages file if it is open, and then flag it as closed.
        ; OK so even if it is closed I flag it as closed, but this is hardly speed
        ; critical code.
        MOVVS   r9, r0                          ; Hang onto any earlier error
        LDR     r0, message_file_open
        TEQ     r0, #0
        ADRNE   r0, message_file_block
        SWINE   XMessageTrans_CloseFile
        MOV     r0, #0
        STR     r0, message_file_open

      [ PMP
        MOV     R0, #ModHandReason_Free
        LDR     R2, LRUCache
        TEQ     R2, #0
        SWINE   XOS_Module
      ]

        MOV     R0, #ModHandReason_Free
        MOV     R2, SB
        SWI     XOS_Module                      ; Free workspace
      [ Dev
        BVC     %FT87
        DREG    R0, "Heap error "
87
      ]
95
        MOVVS   R9, R0
      [ Dev
        BVC     %FT97
        DREG    R9, "Error ",cc
        DREG    R10, " flag ="
97
      ]

        ADDS    R0, R9, #0                      ; clear V
        MOVNES  R10, R10                        ; only error on init
        Pull    "R0-R11, SB, PC",EQ

        SETV
        ADD     SP, SP, #4
        Pull    "R1-R11, SB, PC"


; InitEntry
; ---------
; Module SWI despatch
SwiEntry ROUT
        Push    "SB, LR"
        CLRPSR  I_bit, LR                       ; re-enable interrupts
        LDR     SB, [SB]
        CMPS    R11, #(SwiTableEnd - SwiTableStart) / 4
        BHS     SwiUnknown
        MOV     LR, PC
        ADD     PC, PC, R11,LSL #2
        B       %FT10
SwiTableStart
        B       DoSwiRetryDiscOp
        B       SwiUnknown
        B       DoSwiDrives
        B       DoSwiFreeSpace
        B       SwiUnknown
        B       DoSwiDescribeDisc
        B       DoSwiRetryDiscOp64
SwiTableEnd

SwiUnknown
        ; Bad SWI
        Push    "r1"
        ADRL    r0, ErrorBlock_ModuleBadSWI
        ADRL    r1, RamFSTitle
        BL      copy_error_one
        Pull    "r1"
10
        Pull    "SB, PC"

DoSwiRetryDiscOp ROUT
        Push    "R8, LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_DiscOp
        Pull    "R8, PC"

DoSwiRetryDiscOp64 ROUT
        Push    "R8, LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_DiscOp64
        Pull    "R8, PC"

DoSwiDrives ROUT
        Push    "R8, LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_Drives
        Pull    "R8, PC"

DoSwiFreeSpace ROUT
        Push    "R8, LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_FreeSpace
        Pull    "R8, PC"

DoSwiDescribeDisc ROUT
        Push    "R8, LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_DescribeDisc
        Pull    "R8, PC"


        MakeInternatErrorBlock  ModuleBadSWI,,BadSWI

SwiNames ROUT
        =  "RamFS",0
        =  "DiscOp",0
        =  "NOP",0
        =  "Drives",0
        =  "FreeSpace",0
        =  "NOP",0
        =  "DescribeDisc",0
        =  "DiscOp64",0
        =  0
        ALIGN

        MACRO
        ComEntry  $Com,$MinArgs,$MaxArgs,$GsTransBits,$HiBits
        ASSERT  $MinArgs<=$MaxArgs
Com$Com DCB     "$Com",0
        ALIGN
        DCD     Do$Com - Module_BaseAddr
        DCB     $MinArgs
        DCB     $GsTransBits
        DCB     $MaxArgs
        DCB     $HiBits
        DCD     Syn$Com - Module_BaseAddr
        DCD     Help$Com - Module_BaseAddr
        MEND

ComTab                                          ; general star commands
        ComEntry  Ram, 0, 0, 0, International_Help:SHR:24

        DCB     0
        ALIGN

; DoRam
; ---------
; Somebody typed *RAM
DoRam
        Push    "LR"
        MOV     R0, #FSControl_SelectFS
        ADRL    R1, RamFSString
        SWI     XOS_FSControl
        Pull    "PC"

        END
