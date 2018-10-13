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
; >DebugOpts

        TTL     "Debugging options"

        GBLL    BigDisc                 ; Increased space efficiency
BigDisc         SETL {TRUE}

        GBLL    BigShare                ; Look at share size in disc record
BigShare        SETL {TRUE}

        GBLL    BigFiles                ; Allow files up to 4G-1 in size
BigFiles        SETL {TRUE}

        GBLL    BigMaps                 ; Big free space maps (allowing idlen to be more than 15)
BigMaps         SETL {TRUE}

        GBLL    BigDir                  ; Big directories
BigDir          SETL {TRUE}

        GBLL    BigSectors              ; Allow sector sizes of 2kB and 4kB
BigSectors      SETL {TRUE}

        GBLL    DynamicMaps             ; Maps go in dynamic areas
DynamicMaps     SETL {TRUE}

        GBLL    BinaryChop              ; Faster search in big directories
BinaryChop      SETL {TRUE}

        GBLL    WriteCacheDir           ; Cached directories
WriteCacheDir   SETL {FALSE}

        GBLL    BigDirFullBackup
BigDirFullBackup SETL {FALSE}

        GBLL    DriveStatus             ; Use MiscOp_DriveStatus
DriveStatus     SETL {TRUE}

        GBLL    FullAtts                ; Extended attributes for new format dirs
FullAtts        SETL {TRUE}

        GBLL    NewErrors               ; Errors can be in top bit set addresses
NewErrors       SETL {TRUE}

        GBLL    ExtraSkew               ; Extra skew in F/G format floppies to suit Tungsten better
ExtraSkew       SETL {TRUE}

        GBLL    UseRMAForFCBs           ; Whether RMA or System heap is used for fcbs
UseRMAForFCBs   SETL {TRUE}

        GBLL    FixTBSAddrs             ; Updated semantics of scatter list to allow background transfer
FixTBSAddrs     SETL    {TRUE}          ; to/from top-bit set logical addresses
ScatterListNegThresh    *       &10000

        GBLL    FixTruncateOnBigDiscs
FixTruncateOnBigDiscs SETL {TRUE}

        GBLL    RO3Paths                ; Assume fileswitch does path resolution
RO3Paths SETL {TRUE}

        GBLL    ReadMapDuringIdentify   ; Save time by prereading the map
ReadMapDuringIdentify SETL {TRUE}

        GBLL    Dev                     ; Extra code to do postmortem when things go bang
Dev     SETL    {FALSE}

        GBLL    Debug                   ; Debugging printout
Debug   SETL    {FALSE} :LOR: Dev

        GBLL    ExceptionTrap
        GBLL    VduTrap
        GBLL    SpoolOff
        GBLL    IrqDebug
        GBLL    DebugSwitch
ExceptionTrap   SETL Dev :LAND: {FALSE}
ExceptionTrap   SETL Dev :LAND: {FALSE}
VduTrap         SETL Dev :LAND: {FALSE}
SpoolOff        SETL Dev :LAND: {TRUE}
IrqDebug        SETL Dev :LAND: {TRUE}
DebugSwitch     SETL Dev :LAND: {FALSE}

        MACRO
$a      switch  $b
        GBLL    $a
$a      SETL    $b :LAND: Debug
        MEND

Debug1  switch  {FALSE} ; communication with parent module
Debug2  switch  {FALSE} ; SWI call processing
Debug2D switch  {FALSE} ; DiscOp SWI call processing
Debug3  switch  {FALSE} ; disc accesses
Debug3L switch  {FALSE} ; low level discops into parent
Debug4  switch  {FALSE} ; disc and drive record operations
Debug5  switch  {FALSE} ; old free space map operations
Debug6  switch  {FALSE} ; pathname and directory operations
Debug6f switch  {FALSE} ; FindDiscByName
Debug7  switch  {FALSE} ; OsFile operations
Debug8  switch  {FALSE} ; File Level Disc Ops
Debug9  switch  {FALSE} ; Misc useful routines
DebugA  switch  {FALSE} ; OsFun operations
DebugB  switch  {FALSE} ; Random access files
DebugBA switch  {FALSE} ; OS_Args specifically
DebugBE switch  {FALSE} ; BPut/BGet entry
DebugBc switch  {FALSE} ; CloseAllByDisc
DebugBe switch  {FALSE} ; Ensure file size
DebugBv switch  {FALSE} ; Random access files verbose - details of PutBytes and GetBytes
DebugBs switch  {FALSE} ; Open file new map allocated size
DebugBt switch  {FALSE} ; Random access file I/O terse
DebugC  switch  {FALSE} ; Directory cache
DebugD  switch  {FALSE} ; Scatter buffer
DebugE  switch  {FALSE} ; new free space map
DebugEa switch  {FALSE} ; new free space map random extension
DebugEx switch  {FALSE} ; verbose new free space map
DebugEs switch  {FALSE} ; debugging of SortDir use in NewClaimFree
DebugF  switch  {FALSE} ; new free space map: auto compact
DebugFx switch  {FALSE} ; new free space map: check for this bug [switch broken!]
DebugG  switch  {FALSE} ; verbose file cache
DebugGu switch  {FALSE} ; UpdateProcess only
DebugGs switch  {FALSE} ; UpdateProcess scatter list ends only
DebugH  switch  {FALSE} ; terse file cache
DebugI  switch  {FALSE} ; terse FIQ claim/release
DebugJ  switch  {FALSE} ; file cache consistency checks
DebugK  switch  {FALSE} ; setting of Interlocks
DebugL  switch  {FALSE} ; Mounting/Identifying/Dismounting/Verifying
DebugLi switch  {FALSE} ; Changes to DiscId information in disc records
DebugLm switch  {FALSE} ; matching disc against other records
DebugM  switch  {FALSE} ; CachedReadSector disc op
DebugMt switch  {FALSE} ; MultiFS extensions (terse)
DebugN  switch  {FALSE} ; Disc insertion / request for insertion thread
DebugO  switch  {FALSE} ; MultiFS extensions - formatting SWIs
DebugP  switch  {FALSE} ; Process activation/deactivation
DebugQ  switch  {FALSE} ; *-commands
DebugR  switch  {FALSE} ; reentrance
DebugU  switch  {FALSE} ; UpCall
Debugb  switch  {FALSE} ; break key action updates
DebugDR switch  {FALSE} ; check array bounds on drive and disc record ptr calculation
DebugDL switch  {FALSE} ; check for data lost problems with atapi
DebugX  switch  {FALSE} ; debug long filenames
DebugXg switch  {FALSE} ; debug long filenames - growin dirs
DebugXm switch  {FALSE} ; debug long filenames - memory problems
DebugXb switch  {FALSE} ; debug long filenames - binary chop dir search
DebugXr switch  {FALSE} ; debug long filenames - rename
DebugXd switch  {FALSE} ; debug long filenames - directory names
DebugCW switch  {FALSE} ; debug write cacheing of dirs

        MACRO
        DumpDiscRecs
        Push    "r0-r2"
        MOV     r0,#0
01
        BREG    r0,"DiscRec ",cc
        DiscRecPtr r1,r0
        LDRB    r2,[r1,#DiscFlags]
        BREG    r2," DiscFlags ",cc
        LDRB    r2,[r1,#Priority]
        BREG    r2," Priority ",cc
        LDRB    r2,[r1,#DiscsDrv]
        BREG    r2," DiscsDrv ",cc
        LDRB    r2,[r1,#DiscUsage]
        BREG    r2," DiscUsage "
        ADD     r0,r0,#1
        CMP     r0,#8
        BNE     %BT01
        Pull    "r0-r2"
        MEND

        MACRO
        DumpDrvRecs
        Push    "r0-r2"
        MOV     r0,#0
01
        BREG    r0,"DrvRec ",cc
        DrvRecPtr r1,r0
        LDRB    r2,[r1,#DrvsDisc]
        BREG    r2," DrvsDisc ",cc
        LDRB    r2,[r1,#DrvFlags]
        BREG    r2," DrvFlags ",cc
        LDRB    r2,[r1,#LockCount]
        BREG    r2," LockCount ",cc
        LDR     r2,[r1,#ChangedSeqNum]
        DREG    r2, " ChangedSeqNum "
        ADD     r0,r0,#1
        CMP     r0,#8
        BNE     %BT01
        Pull    "r0-r2"
        MEND

        GBLS    NeedHdrDebug
        GBLS    NeedHdrProc
        GBLS    NeedHdrHostFS
      [ Debug
NeedHdrProc     SETS "GET Hdr:Proc"
NeedHdrDebug    SETS "GET Hdr:Debug"
      |
NeedHdrDebug    SETS "; No"
NeedHdrProc     SETS "; No"
      ]
      [ :DEF: Host_Debug
Host_Debug      SETL {FALSE}
Debug_MaybeIRQ  SETL {FALSE}
NeedHdrHostFS   SETS "GET Hdr:HostFS"
      |
NeedHdrHostFS   SETS "; No"
      ]
        $NeedHdrProc
        $NeedHdrDebug
        $NeedHdrHostFS

        END
