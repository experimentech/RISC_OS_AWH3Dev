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

; >FileCore00

        TTL     "Start of module, workspace allocation"

        AREA    |FileCore$$Code|, CODE, READONLY, PIC

        ENTRY

        ; Module Header
Module_BaseAddr
        DCD     0                               ; no start entry
        DCD     InitEntry - Module_BaseAddr     ; initialisation entry
        DCD     DieEntry - Module_BaseAddr
        DCD     ServiceEntry - Module_BaseAddr
        DCD     Title - Module_BaseAddr
        DCD     HelpString - Module_BaseAddr
        DCD     ComTab - Module_BaseAddr
        DCD     FileCoreSWI_Base
        DCD     SwiEntry - Module_BaseAddr
        DCD     SwiNames - Module_BaseAddr
anull
        DCD     0                               ; no SWI name decoding code
      [ International_Help <> 0
        DCD     message_filename - Module_BaseAddr
      |
        DCD     0
      ]
        DCD     ModFlags - Module_BaseAddr
        ASSERT  {PC} - Module_BaseAddr = 52

Title
        DCB     "FileCore", 0
        ALIGN

HelpString
        DCB     "FileCore", 9
      [ Dev
        DCB     Module_FullVersion, " Development version", 0
      |
        DCB     Module_MajorVersion, " (", Module_Date, ")", 0
      ]
        ALIGN

ModFlags
      [ :LNOT: No32bitCode
        DCD     ModuleFlag_32bit
      |
        DCD     0
      ]

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Data areas & register allocation
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SB              RN 12

                ^ 0, SB
PrivateWord     # 4           ; back ptr to private word ;MUST BE FIRST
DefectSpace     # 4           ; workspace relative
ptr_IRQsema     # 4           ; Pointer to kernel IRQsema var
ptr_CannotReset # 4           ; Pointer to kernel CannotReset var

DefGlobals                    ; Globals that get initialised
DefGlobStart    # 0

ReEntrance      # 1           ; bit 0 => dormant
                DCB 1         ; bit 1 => executing first incarnation
                              ; bit 2 => doing MOS call for first incarnation
                              ; bit 3 => executing reentered code
                              ; bit 4 => doing MOS call for reentered code
                              ; bit 6 set => no reentrance
NoReEnterBit    bit 6

LastReEnter     # 1           ; set non zero whenever FileCore entered
                DCB 0
ScatterEntries  # 1           ; # chunks claimed for data move scatter block
                DCB 0
Flags           # 1
                DCB 0
CacheGood       bit 7
TruncateNames   bit 4         ; 0 means truncate, 1 means barf (yup, its the other way round to what's in CMOS)


message_file_open # 4         ; MessageTrans open flag
                DCD 0

 [ :LNOT: RO3Paths
UserRootDir     # 4
                DCD -1
LibDir          # 4
                DCD -1
CurDir          # 4
                DCD -1
BackDir         # 4
                DCD -1
 ]
CritBufDir      # 4           ; use when BufDir itself must be invalid
                DCD -1
BufDir          # 4           ; currently buffered directory
                DCD -1

              [ WriteCacheDir
BufDirDirty     # 4
                DCD 0
BufDirDirtyBit  * 1
ModifiedZones   # 4
                DCD 0
              ]

FirstFcb        # 4           ; link to first file control block
                DCD -1

FragCache       # 0
OldLastFilePtr  # 4
                DCD 0
OldLastMapPtr   # 4
                DCD 0
OldLastIndDiscAdd # 4
                DCD 0
LastFilePtr     # 4
                DCD 0
LastMapPtr      # 4
                DCD 0
LastIndDiscAdd  # 4
                DCD 0


PreferredDisc   # 1           ; Disc to use after canonicalise disc name
                DCB &FF
Interlocks      # 1
                DCB NoOpenFloppy :OR: NoOpenWinnie

WinnieLock      bit 0         ; DONT CHANGE THESE FOUR WHICH USE LSR #30 or LSR #28 TRICK
FloppyLock      bit 1
NoOpenWinnie    bit 2         ; Means: nothing open on winnie, so don't winnie BackgroundOp
NoOpenFloppy    bit 3         ; Means: nothing open on floppy, so don't floppy BackgroundOp
FileCacheLock   bit 4         ; Means: foreground is playing with the filecache, so hands off background!
DirCacheLock    bit 5
TimerLock       bit 6         ; Means: Ticker event is currently processing BackgroundOps

FiqOwnership    # 1
                DCB 0
BackgroundFiqLock # 1         ; set to &FF to stop attempts to claim FIQ
                DCB 0

                              ; One free space map is 'locked' at any time. When a map is locked the disc to
                              ; which it belongs is locked in its drive. The locked map may or not be being
                              ; modified. If being modified ModifyDisc will have the disc number in it,
                              ; otherwise it will be &ff. When no map is being read/modified these
                              ; map-specific values are set to &ff:
LockedDrive     # 1
                DCB &FF
LockedDisc      # 1
                DCB &FF
ModifyDisc      # 1           ; Disc whose map is unsafe due to being modifed or being read whilst disc is attached to drive
                DCB &FF
                # 1           ; Not free for other use
                DCB &FF

UpperCaseTable  # 4
                DCD 0

SzDefGlobals * {PC}-DefGlobals
                ASSERT {VAR} - DefGlobStart = SzDefGlobals

ParentBase      # 4           ; base of parent module
ParentPrivate   # 4           ; ptr to private word of parent module
Floppies        # 1           ; # floppy drives
Winnies         # 1           ; # winnie drives
Drive           # 1           ; default drive
StartUpOptions  # 1

              [ :LNOT: DynamicMaps
WinnieSizes     # 4
FloppySizes     # 4           ; Must follow WinnieSizes for indexing purposes
              ]
FS_Flags        # 3
FS_Id           # 1
FS_Title        # 4           ; FOLLOWING ARE STORED AS ABSOLUTE ADDRESSES
FS_BootText     # 4
FS_LowLevel     # 4
FS_Misc         # 4

DiscOp_ByteAddr # 4

message_file_block # 16       ; block for messagetrans

              [ NewErrors
ConvDiscErr     # 12
              ]

SysHeapStart    # 4

              [ BigDir
Opt1Buffer      # BigDirMaxNameLen + 1
              |
Opt1Buffer      # NameLen + 1
                # 1           ; filler
              ]

                # -CacheRootStart
RootCache       # CacheRootEnd


ScatterPtr      # 4           ;->Scatter block
ScatterAdd      * 0
ScatterLen      * 4

ScatterBlk      # 8

                              ; Critical subroutine management workspace
CriticalDepth   * 2           ; max levels of critical subroutine

CriticalGood1   # 1
                # 3
CriticalSP1     # 4
CriticalStack1  # (CriticalDepth + 1) * 4

CriticalGood2   # 1
                # 3
CriticalSP2     # 4
CriticalStack2  # (CriticalDepth + 1) * 4

CritDrvRec      # 4
CritDiscRec     # 4
CritResult      # 4

BreakAction     # 1
                # 3

MaxFileBuffers          # 1
UnclaimedFileBuffers    # 1
BufHashMask             # 1
WriteDisc               # 1   ; disc in use by put bytes or &FF so that floppy
                              ; write behind can't be unset if may add more
FileBufsStart           # 4     
FileBufsEnd             # 0   ; Same as FloppyProcessBlk
FloppyProcessBlk        # 4     
WinnieProcessBlk        # 4     
BufHash                 # 4     

TickerState     # 4           ; bottom 16 bits period, top 16 bits counter

        ASSERT  YoungerBuf = OlderBuf + 4
ChainRootSz     * 4 + 4       ; older and younger link
BufChainsRoot   * @-OlderBuf  ; roots of buffer allocation lists
                # 6 * ChainRootSz

DirectError     # 4           ; background error in direct transfer

CounterReadWs   # 4
CounterReadCall # 4

              [ BigDisc
DoCompZoneBase  # 4           ; Workspace for DoCompMoves
              ]

                ; Records
DrvRecs         # SzDrvRec * 8
DiscRecs        # SzDiscRec * 8

                ; Data move scatter list
ScatterMax      * 8           ; max # (address,length) pairs in buffer
ScatterListLen  * ScatterMax * (4 + 4)

ScatterSource   # ScatterMax
ScatterList     # ScatterListLen
ScatterCopy     # ScatterListLen

        ASSERT  :INDEX:{VAR}<&1000

        ASSERT NewDirSize > OldDirSize
DirBufSize      * NewDirSize
              [ BigDir
DirBufferPtr    # 4           ; pointer to dir buffer
DirBufferArea   # 4           ; dynamic area number of dir buffer
DirBufferSize   # 4           ; size of dir buffer
              |
DirBuffer       # DirBufSize
              ]

DirCache        # 0           ; MUST BE LAST

              [ Dev
                ! 0, "BufChainsRoot = " :CC: :STR: :INDEX: BufChainsRoot
                ! 0, "DirCache = " :CC: :STR: :INDEX: DirCache
                ! 0, "DrvRecs = " :CC: :STR: :INDEX: DrvRecs
                ! 0, "DiscRecs = " :CC: :STR: :INDEX: DiscRecs
              ]

        ALIGN
        LTORG
        
        END
