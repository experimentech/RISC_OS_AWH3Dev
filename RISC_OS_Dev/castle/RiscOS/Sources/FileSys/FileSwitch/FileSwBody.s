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
        TTL     > s.FileSwBody - Top layer of Filing System rubbish

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Some FileSwitch specific macros

; Range check a register against (unsigned) register/immediate values
; CS if in [b1..b2], CC otherwise

        MACRO
$label  RangeCheck $reg, $wrk, $b1, $b2
$label  CMP     $reg, $b1
        RSBCSS  $wrk, $reg, $b2         ; inverse compare
        MEND

; For new Tutu style jump tables (4S + 2N cycles)

        MACRO
$label  JTAB    $dispreg, $cond, $name, $baseval
$label  ADD$cond pc, pc, $dispreg, LSL #2
JumpTableName SETS "$name.JumpTable"
$JumpTableName * .+4    ; Allow punter one instruction following JTAB condition
 [ "$baseval" = ""
JumpTableBaseValue SETA 0
 |
JumpTableBaseValue SETA $baseval
 ]
 [ ("$cond" = "") :LOR: ("$cond" = "AL")
        MOVNV   r0, r0
 ]
        MEND

        GBLS    JumpTableName
        GBLA    JumpTableBaseValue
        GBLL    ReportJumpTableError
ReportJumpTableError SETL {TRUE}

        MACRO
        JTE     $routine, $checkvalue
 [ "$checkvalue" <> ""
  [ (.-$JumpTableName) <> ($checkvalue-JumpTableBaseValue) :SHL: 2
   [ ReportJumpTableError
        !       1, "Error in jump table with value '$checkvalue'"
ReportJumpTableError SETL {FALSE}
   ]
  ]
 ]
        B       $routine
        MEND


; General initialisation for buffered file i/o

; In    scb^ valid
;       fileptr may be > extent if cached BPut, so correct if need to

; Out   status  = scb status bits
;       fileptr = PTR#
;       extent  = EXT# (corrected after effect of BPut cache)
;       bufmask = (size of file buffers - 1)
;       bcb     = first bcb or Nowt (optional)

        MACRO
$label  ReadStreamInfo $bcb
        ASSERT  :INDEX: scb_status = 0 ; For LDM
        ASSERT  fileptr > status
        ASSERT  scb_fileptr = scb_status + 4
        ASSERT  extent > fileptr
        ASSERT  scb_extent = scb_fileptr + 4
        ASSERT  bufmask > extent
        ASSERT  scb_bufmask = scb_extent + 4
 [ "$bcb" <> ""
        ASSERT  bcb > bufmask
        ASSERT  scb_bcb = scb_bufmask + 4
        ASSERT  $bcb = bcb
$label  LDMIA   scb, {status, fileptr, extent, bufmask, bcb}
 |
$label  LDMIA   scb, {status, fileptr, extent, bufmask}
 ]
        CMP     fileptr, extent
        MOVHI   extent, fileptr         ; If fileptr > extent, correct for
        STRHI   extent, scb_extent      ; having overshot (BPut cache effect)
        CLRV                            ; Extents > 2G might set V 
 [ debugstream
        Push    lr
        BL      DebugStreamInfo
        Pull    lr
 ]
        MEND

; General method of getting a chunk of stack as a buffer for those times
; when an indeterminately sized buffer is needed.
;
; In    $Reg - working register
;       $MinLump - Minimum stack chunk required
;       $MaxLump - Maximum stack chunk worth taking (must be word sized)
;       $MinStack - Minimum quantity of stack which must remain (must be word sized)
;       $NotEnoughLabel - where to go to if there wasn't 2k of stack spare
;
; Out   $Reg = amount claimed off the stack
;       sp -> hole in the stack
;
        MACRO
$Label  GetLumpOfStack  $Reg,$MinLump,$MaxLump,$MinStack,$NotEnoughLabel
        MOV     $Reg, sp, LSR #20
        SUB     $Reg, sp, $Reg, LSL #20         ; $Reg = Stack remaining
        SUB     $Reg, $Reg, $MinStack           ; $Reg = Stack available for buffer
        CMP     $Reg, $MinLump
        BLO     $NotEnoughLabel
        CMP     $Reg, $MaxLump
        MOVHI   $Reg, $MaxLump
        SUB     sp, sp, $Reg
        MEND

addr_verbose    SETA    0



        GBLS    CaseConvertReg
        GBLS    CaseConvertType
        MACRO
        Internat_CaseConvertLoad  $UR,$Type
CaseConvertReg SETS    "$UR"
CaseConvertType SETS   "$Type"
        LDR     $UR, $Type.CaseTable
        MEND

        MACRO
        Internat_UpperCase      $Reg, $UR
        ASSERT  $UR = $CaseConvertReg
        ASSERT  CaseConvertType = "Upper"
        TEQ     $UR, #Nowt
        LDRNEB  $Reg, [$UR, $Reg]
        MEND

        MACRO
        Internat_LowerCase      $Reg, $UR
        ASSERT  $UR = $CaseConvertReg
        ASSERT  CaseConvertType = "Lower"
        TEQ     $UR, #Nowt
        LDRNEB  $Reg, [$UR, $Reg]
        MEND



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

HSP     *       31
space   *       " "
quote   *       """"
solidus *       "|"
delete  *       &7F
CR      *       13
NULL    *       0
Nowt    *       &40000000               ; Such that CMP ptr, #Nowt gives VClear
                                        ; &80000000 is a very BAD choice !

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Register allocation

; r0 generally used for data/reason codes
; r1 mainly used as handle for stream ops, filename/string^ for named ops
; r2 used for OSARGS data, GBPB memory address
status  RN      r3
fileptr RN      r4 ; Relied on by GBPB
extent  RN      r5 ; Relied on by GBPB
bufmask RN      r6
        GBLS    streaminfo
streaminfo SETS "r3-r6"
; r7 seems mostly unused
bcb     RN      r8  ; Buffer cb^
scb     RN      r9  ; Stream cb^
fscb    RN      r10 ; Filing System cb^
; fp RN r11 ; Local workspace^
; wp RN r12 ; Global workspace^
; sp RN r13 ; FD SVC stack^
; lr RN r14

        ASSERT  fp + 1 = wp ; For LDMIA rn, {fp, wp} in LowLevel

; *****************************************************************************
; *** Enter a vectored SWI handler saving registers, fp but not lr (already ***
; *** assumed stacked eg. by the CallVector routine). Setup fp, clear error ***
; *** PullSwiEnv will leave lr stacked for exit                             ***
; *****************************************************************************

; +------------+
; |     lr     |
; +------------+ <- vector entry sp
; |     fp     |
; +------------+
; |            |
; -            -  } Stacked registers, accessed using [fp, #rn*4]
; |            |
; +------------+
; |    r(0)    |
; +------------+ <- fp
; |            |
; | Local vbls |  } Accessed using [fp, #-offset]
; |            |
; +------------+ <- fp - lfsz (also initial sp)

; $extra option for FSUtils, which need more local state

        MACRO
$label  NewSwiEntry $reglist,$extra,$savecode
 [ "$reglist" = ""
Proc_RegList    SETS "fp"
 |
Proc_RegList    SETS "$reglist, fp"
 ]
Proc_LocalStack SETA $extra.localframesize
 [ "$label" <> ""
  [ Proc_Debug
        B       $label
        DCB     "$label", 0
  ]
$label  ROUT
 |
        ASSERT  (.-Module_BaseAddr :AND: 3) = 0
 ]
        Push    "$Proc_RegList"
 [ "$savecode" = ""
        InitialiseFrame
 ]
 [ debugreturnparams
        DREG    r0, "Regs in:",cc
        DREG    r1, ",",cc
        DREG    r2, ",",cc
        DREG    r3, ",",cc
        DREG    r4, ",",cc
        DREG    r5, ",",cc
        DREG    r6, ",",cc
        DREG    r7, ",",cc
        DREG    r8, ",",cc
        DREG    r9, ",",cc
        DREG    r10, ",",cc
        DREG    r11, ","
 ]
        MEND


        MACRO
$label  InitialiseFrame
$label  WritePSRc SVC_mode, fp          ; Reenable interrupts
        MOV     fp, sp                  ; Point to dumped registers
 [ No26bitCode
        ; ensure V clear
        SUBS    sp, sp, #Proc_LocalStack ; Never zero for main entry frame
 |
        SUB     sp, sp, #Proc_LocalStack ; Never zero for main entry frame
 ]
 [ debugframe
 DREG fp,"InitialiseFrame: fp := "
 ]
        MOV     r14, #0                 ; No error this level
        STR     r14, globalerror        ; Don't poke into the frame until
        MEND                            ; we've created it !

; *****************************************************************************
; *** Restore stack and saved registers to values on entry to SWI handler   ***
; *** lr left stacked                                                       ***
; *****************************************************************************
        MACRO
$label  PullSwiEnv $cond
$label
 [ debugframe
 DREG fp,"Exiting frame: fp = "
 ]
 [ Proc_LocalStack <> 0
        ADD$cond sp, sp, #Proc_LocalStack
 ]
 [ "$Proc_RegList" <> ""
        Pull    "$Proc_RegList", $cond
 ]
        MEND


; Labels 99xx reserved for below purpose - ensure consistency

        MACRO
$label  SwiExit $cond
$label
 [ debugframe
 B$cond %FT9900
 B %FT9901
9900
 DREG fp,"SwiExit: fp = "
9901
 ]
        LDR$cond r14, globalerror       ; do this before frame destroyed
9999    PullSwiEnv $cond
        B$cond  FileSwitchExit
        MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Record for copy block

                ^       0
copy_name       #       4       ; Filename for copy (dirprefix + leafname)
copy_special    #       4       ; Special field for copy
copy_fscb       #       4       ; Filing System for copy
copy_dirprefix  #       4       ; Dir prefix to use
copy_leafname   #       4       ; Leafname to copy
copy_size       #       0

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; FileSwitch global area workspace definitions

                ^       0, wp ; Workspace accesses are wp register relative

BGet_shiftedbase # 4            ; BGet cache data must be at offset 0
BGet_bufferdata  # 4
BGet_scb         # 4
BGet_shift       # 4
BGet_handle      # 4

BPut_shiftedbase # 4
BPut_bufferdata  # 4
BPut_scb         # 4
BPut_shift       # 4
BPut_handle      # 4

message_file_block #    16

FileSwitch_FirstNowtVar # 0     ; First var to initialise to Nowt on hard reset

message_file_flags #    4       ; Interlocks on the message file
message_file_open * 1
message_file_busy * 2
message_error_lookup_threads * 2
message_error_lookup_threads_mask * 7
message_max_error_threads * 7

LinkedAreas     #       4       ; Points to chain of linked areas
 [ :INDEX: LinkedAreas <> &128
 ! 0, "Change ShowHeap linkedareas to &":CC:(:STR:(:INDEX: LinkedAreas))
 ]

; Most global variables accessed using LDR - larger range than ADR in general

fschain         #       4       ; Ptr to chain of known Filing Systems
 [ :INDEX: fschain <> &12C
 ! 0, "Change ShowHeap fschain to &":CC:(:STR:(:INDEX: fschain))
 ]

UpperCaseTable  #       4
LowerCaseTable  #       4

 [ osfile5cache
OsFile5Cache    #       4
 ]

FileSwitch_LastNowtVar # 0

 [ MercifulToSysHeap
HBlocks_Valid     #     4
HBlockArray_32    #     4
HBlockArray_64    #     4
HBlockArray_128   #     4
HBlockArray_1040  #     4

NHBlocks_32   *  64
NHBlocks_64   *  64
NHBlocks_128  *  64
NHBlocks_1040 *  12

    [ MercifulTracing
NHB_total   # 4       ;total block claims
NHB_fail    # 4       ;total block claims that gave up and went to OS_Heap
HB_failmax  # 4       ;largest size of block that had to come from OS_Heap
    ]

 ] ;MercifulToSysHeap

           AlignSpace   16      ; So we don't have to ADRL these objects

MaxHandle       *       255     ; Biggest valid handle that I will return
streamtable_size *      256*4   ; Table is still indexable with 00..FF though
streamtable     #       streamtable_size
 [ :INDEX: streamtable <> &140
 ! 0, "Change ShowHeap streamtable to &":CC:(:STR:(:INDEX: streamtable))
 ]

EnvStringAddr   #       4       ; Only needed when we're not bound to kernel
EnvTimeAddr     #       4
SVCSTK          #       4
SysHeapStart    #       4

ptr_DomainId    #       4       ; Pointer to kernel's DomainId var

; Byte size global variables

copy_n_upcalls  #       1       ; Reference count on UpCallV
                                ; Must be initialised to 0 at init and reset

 [ StrongARM
codeflag	#	1	; 0 if data being loaded, 1 if code
 ]
                #       1       ; Pad
 [ sparebuffer
SpareBufferFree #       1       ; Flag, non zero denotes free for use
           AlignSpace   16
SpareBufferArea #       0       ; Must be last, it's Max_BuffSize long
 ]

; No need to align end of global workspace; saves alloc when rounded!

 [ :INDEX: @ > 4096
 ! 1, "FileSwitch global workspace is out of LDR range by ":CC:(:STR:((:INDEX: @)-4096)):CC:" bytes"
 ]

 [ anyfiledebug
 ! 0, "FileSwitch global area is ":CC:(:STR:(:INDEX: @)):CC:" bytes"
 ]

FileSwitchWorkspace_size * :INDEX: @


StaticName_length *     1024    ; Limits size of input filename, path etc.
                                ; was 256 (changed for Ursula)

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Local workspace allocation: done bottom up!


; ******************************************************
; ******************************************************
; ** How this bit works...                            **
; ** ---------------------                            **
; **                                                  **
; ** Everytime you want to add anything to any of the **
; ** sections below, increment the following value by **
; ** the amount you add. Simple...                    **
; ******************************************************
; ******************************************************
;
; Stuff that only wants to be local during Copy

; MB fix 15/3/99
; size of buffer for enumerating dirs has been increased to allow filenames up to 256 characters

 [ UseDynamicAreas
copylocalframesize *    &210    ; Change this if changing ANY frame size
 |
copylocalframesize *    &208    ; Change this if changing ANY frame size
 ]

                ^       -copylocalframesize, fp

 [ (:INDEX: @) :AND: 3 <> 0
 ! 1, "FileSwitch local copy frame is not word aligned"
 ]


copy_startedtime #      8       ; Top 3 bytes cleared to zero when used

dst_copy_block  #       copy_size

copy_area       #       4       ; Address of block (rma,apl,user,wimp) used in copying
copy_blocksize  #       4

copy_userbuffer     #   4
copy_userbuffersize #   4

 [ UseDynamicAreas
copy_dynamicarea	#	4	; dynamic area ptr
copy_dynamicnum		#	4	; dynamic area number
copy_dynamicmaxsize	#	4	; dynamic area max size
copy_dynamicsize	#	4	; dynamic area current size
 |
copy_wimpfreearea   #   4
copy_wimpfreesize   #   4
 ]

copy_aplsize    #       4
copy_rmasize    #       4

copy_realload   #       4       ; Copy of info that we read so we can do
copy_realexec   #       4       ; date comparison after possible restamp

copy_srchandle  #       4       ; Handle of file if copying by GBPB
copy_dsthandle  #       4

; Byte sized variables

copy_src_dst_flag #     1       ; States as below:
copy_at_source  * 0
copy_at_dest    * 1
copy_at_unknown * &FF

copy_owns_apl_flag #    1       ; 0 -> apl unused, NE -> apl claimed

           AlignSpace   4

; .............................................................................
; Stuff that only wants to be local during FSUtils

 [ (:INDEX: @) :AND: 3 <> 0
 ! 1, "FileSwitch local utils frame is not word aligned"
 ]

utilslocalframesize *   0 - :INDEX: @


util_block      #       copy_size ; Used for src in copy. Ptrs to curr strings

util_times      #       0
util_starttime  #       8       ; Top 3 bytes cleared to zero when used
util_endtime    #       8       ; Top 3 bytes cleared to zero when used

util_ndir       #       4       ; Global to util operation
util_nfiles     #       4
util_totalsize  #       8       ; 64 bit totals
util_popsize    #       8       ; Size of last directory popped

util_bitset     #       4       ; Localled in dir recursion
util_direntry   #       4
util_nskipped   #       4

util_load       #       4       ; Info on object (those that we will put on
util_exec       #       4       ; the dest in copy; possibly restamped)
util_length     #       4
util_attr       #       4
util_objecttype #       4

; MB fix 15/3/99
; size of buffer for enumerating dirs has been increased to allow filenames up to 256 characters
util_objectname #       256+1

           AlignSpace   4       ; ROMFS does word align at odd places
util_objblksize *       @ - util_load

           AlignSpace   4

; .............................................................................
; Standard local frame workspace definitions

 [ (:INDEX: @) :AND: 3 <> 0
 ! 1, "FileSwitch local frame is not word aligned"
 ]

localframesize  *       0 - :INDEX: @


; Local variables always accessed using LDR - larger range than ADR in general

globalerror     #       4       ; Tell us if an error has happened this call
                                ; (what a silly name for a local variable !)

commandtailptr      #   4       ; Points after filename in CommandLine in RUN

endptr          #       4       ; Extent to set after good GBPB op completion
memadr_filebase #       4       ; Core base of where fileptr 0 would be


; Byte size variable(s)

lowfile_opt1    #       1       ; Used for OPT 1 state in CallFSFile

           AlignSpace   4


; Linked area objects for reentrancy. Pointed to using ADR as well as LDR

; NB. Must only have one use per local frame as these are not themselved linked

TransientBlock  #       4       ; Ptr to current transient block
PassedFilename  #       4       ; Ptr to passed filename after translation
                                ; and copying into buffer
PassedFilename2 #       4       ; For copy
FullFilename    #       4       ; Ptr to full filename of current file
                                ; after copying into buffer
FullFilename2   #       4       ; Ptr to 2nd full filename for rename
SpecialField      #     4       ; Ptr to a copy of the special field (or 0)
SpecialField2     #     4       ; Ptr to a copy of the other special field
                                ; eg for Rename, Copy
CommandLine       #     4       ; Ptr to a copy of command line for *RUN
ActionVariable    #     4       ; Ptr to Load/Run action string
OptFilenameString #     4       ; Ptr to leafname returned for OPT


; Local blocks accessed by ADR

fileblock_base  #       0       ; OSFile parm dump area
fileblock_load  #       4
fileblock_exec  #       4
fileblock_length #      4
fileblock_attr  #       4
fileblock_start *       fileblock_length ; For save/create ops
fileblock_end   *       fileblock_attr

gbpbblock_base  #       0       ; OSGBPB parm dump area
gbpb_memadr     #       4
gbpb_nbytes     #       4
gbpb_fileptr    #       4


 [ anyfiledebug
 ! 0,"FileSwitch local frame is ":CC:(:STR:localframesize):CC:" bytes"
 ! 0,"FileSwitch local utils frame is ":CC:(:STR:utilslocalframesize):CC:" bytes"
 ! 0,"FileSwitch local copy frame is ":CC:(:STR:copylocalframesize):CC:" bytes"
 ]

 [ :INDEX: @ <> 0
 ! 1,"FileSwitch frame sizes out by ":CC:(:STR:(:INDEX:@)):CC:" bytes"
 ]

        ASSERT  :INDEX: @ = 0           ; Local frames must all end here

; *****************************************************************************
; ***                                                                       ***
; ***                  FileSwitch Module code starts here                   ***
; ***                                                                       ***
; *****************************************************************************

; Header bits for gluing into Arthur ROM or running standalone in RAM

        AREA    |FileSwitch$$Code|, CODE, READONLY, PIC
        ENTRY

Module_BaseAddr * .

        DCD     0 ; Not an application
        DCD     FileSwitch_Init     - Module_BaseAddr
        DCD     FileSwitch_Die      - Module_BaseAddr
        DCD     FileSwitch_Service  - Module_BaseAddr
        DCD     FileSwitch_Title    - Module_BaseAddr
        DCD     FileSwitch_HelpText - Module_BaseAddr
        DCD     FileSwitch_HC_Table - Module_BaseAddr
 [ International_Help <> 0 :LOR: No26bitCode
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     message_filename    - Module_BaseAddr
 ]
 [ No26bitCode
        DCD     FileSwitch_ModFlags - Module_BaseAddr
 ]

        GBLS    FileSwitchMinor

FileSwitch_HelpText
        DCB     "FileSwitch", 9, "$Module_MajorVersion.$FileSwitchMinor ($Module_Date)"
 [ anyfiledebug
        DCB     " Debugging version"
 ]
        DCB     0


FileSwitch_HC_Table ; Name Max Min

        Command Access,    2, 1, International_Help
        Command Cat,       1, 0, International_Help         ; >>>a186<<< had wrong no of args
        Command CDir,      2, 1, International_Help
 [ hascopy
        Command Copy,    &FF, 2, International_Help         ; Interprets options on line
 ]
 [ hascount
        Command Count,   &FF, 1, International_Help         ; Interprets options on line
 ]
        Command Dir,       1, 0, International_Help
        Command EnumDir,   3, 2, International_Help
        Command Ex,        1, 0, International_Help
        Command FileInfo,  1, 1, International_Help
        Command Info,      1, 1, International_Help
        Command LCat,      1, 0, International_Help         ; >>>a186<<< had wrong no of args
        Command LEx,       1, 0, International_Help
        Command Lib,       1, 0, International_Help
        Command Rename,    2, 2, International_Help
        Command Run,     &FF, 1, International_Help         ; Passes rest of line to command
        Command SetType,   5, 2, International_Help         ; Could have 'a b c d' as file type
        Command Shut,      0, 0, International_Help
        Command ShutDown,  0, 0, International_Help
        Command Stamp,     1, 1, International_Help
        Command Up,        1, 0, International_Help
 [ haswipe
        Command Wipe,    &FF, 1, International_Help         ; Interprets options on line
 ]
        Command Back,      0, 0, International_Help
        Command URD,       1, 0, International_Help
        Command NoDir,     0, 0, International_Help
        Command NoURD,     0, 0, International_Help
        Command NoLib,     0, 0, International_Help

; Configuration commands

        Command FileSystem, 0, 0, Status_Keyword_Flag :OR: International_Help
        Command Truncate, 0, 0, Status_Keyword_Flag :OR: International_Help

        DCB     0                       ; That's all folks !

        GBLS    GetHelpSrc
 [ International_Help <> 0
GetHelpSrc      SETS    "GET HelpSrc"
 |
GetHelpSrc      SETS    "GET s.TokHelpSrc"
 ]
        $GetHelpSrc

FileSwitch_Title
        DCB     "FileSwitch", 0

        ALIGN

 [ No26bitCode
FileSwitch_ModFlags
        DCD     1       ; 32-bit compatible
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Possible startup / reset sequences :
;
; 1) Hard-Break  : rom_HardInit, rom_ResetService
;
; 2) Load image  : old_HardDie, new_HardInit
;
; 3) Reinitialise: HardDie, HardInit
;
; 4) Soft-Break  : ResetService
;
; 5) RMA Tidy    : SoftDie, SoftInit
;
; 6) RMFaster    : rom_HardDie, rma_HardInit - which we must fault
;
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Init entry. r0-r6 trashable

; I can now just about survive RMTidy, I guess !

FileSwitch_Init Entry "r7"

        ; Macro to disallow rip-off RAM loaded version (te he ;-)
        ChkKernelVersion

        LDR     r2, [r12]               ; Is this a hard initialisation ?
        CMP     r2, #0                  ; r2 = 0 -> hard. VClear
        BEQ     %FT01

        MOV     wp, r2                  ; SoftInit
 [ debuginit
 DLINE "Soft Init"
 ]
        B       %FT40



01 ; Get some workspace from the RMA first of all

 [ debuginit
        DLINE "Hard Init"
 ]
        MOV     r0, #ModHandReason_Claim
 [ sparebuffer
        LDR     r3, =FileSwitchWorkspace_size + Max_BuffSize + (4*4)
        ASSERT  bcb_size = (4*4)
        ASSERT  :INDEX:SpareBufferArea = FileSwitchWorkspace_size 
 |
        LDR     r3, =FileSwitchWorkspace_size
 ]
        SWI     XOS_Module
        EXIT    VS

01      STR     r2, [r12]               ; Update ptr to workspace
        MOV     wp, r2

 [ debuginittime
        DLINE   "Internal vars ",cc
        SWI     XOS_ReadMonotonicTime
        Push    "r0"
 ]

        SWI     XOS_GetEnv              ; Read these to gain MOS independence
        STR     r0, EnvStringAddr       ; in soft loaded version
        STR     r2, EnvTimeAddr

        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_SVCSTK
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        TEQ     r2, #0
        MOVEQ   r2, #&01C00000
        ADDEQ   r2, r2, #&2000
        STR     r2, SVCSTK

        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_DomainId
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        TEQ     r2, #0
        LDREQ   r2, =Legacy_DomainId
        STR     r2, ptr_DomainId

        MOV     r0, #0
        SWI     XOS_ReadDynamicArea
        EXIT    VS
        STR     r0, SysHeapStart

; Initialise lots of pointers to Nowt

        MOV     r0, #Nowt

 [ FileSwitch_LastNowtVar - FileSwitch_FirstNowtVar > 5*4
 ! 0, "Initialising ws with loop"
        ADR     r1, FileSwitch_FirstNowtVar
        ADD     r2, r1, #(FileSwitch_LastNowtVar - FileSwitch_FirstNowtVar)
05      STR     r0, [r1], #4
        TEQ     r1, r2
        BNE     %BT05
 |
 ! 0, "Initialising ws with several inline STR"
        GBLA    fsw_varcount
        WHILE   fsw_varcount < FileSwitch_LastNowtVar - FileSwitch_FirstNowtVar
        STR     r0, [wp, #:INDEX: FileSwitch_FirstNowtVar + fsw_varcount]
fsw_varcount SETA fsw_varcount + 4
        WEND
 ]

   [ MercifulToSysHeap
        BL      InitHBlocks
   ]

; No streams present yet

        ADRL    r0, UnallocatedStream   ; fwd ref
        ADR     r1, streamtable
        ADD     r2, r1, #streamtable_size
10      STR     r0, [r1], #4            ; Nowt scb^
        TEQ     r1, r2
        BNE     %BT10

 [ sparebuffer
        MVN     r14, #0                 ; Nobody owns this yet
        STRB    r14, SpareBufferFree
        ADR     r14, SpareBufferArea
        MOV     r0, #Max_BuffSize       ; bufmask for this buffer is permanent
        SUB     r0, r0, #1
        STR     r0, [r14, #:INDEX:bcb_actualsize]
 ]
 [ debuginittime
        Pull    "r1"
        SWI     XOS_ReadMonotonicTime
        SUB     r0, r0, r1
        SUB     sp, sp, #16
        MOV     r1, sp
        MOV     r2, #16
        SWI     XOS_ConvertCardinal4
        DSTRING r0, ""
        ADD     sp, sp, #16
        DLINE   "External vars ",cc
        SWI     XOS_ReadMonotonicTime
        Push    "r0"
 ]

; Loop creating variables used by FileSwitch

 [ debuginit
 DLINE "Creating variables"
 ]
        ADR     r5, FileSwitch_FirstVariableToCreate
20      MOV     r0, r5                  ; Keep pointer to start of var name
 [ debuginit
 DSTRING r0,"This variable: "
 ]
        MOV     r7, r5
25      LDRB    r14, [r7], #1           ; Find start of variable value
        CMP     r14, #&FF               ; End of list ?
        BEQ     %FT40
        CMP     r14, #CR                ; End of variable name ?
        BNE     %BT25                   ; r7 -> variable value

        LDRB    r4, [r7]                ; see if next char = var type
        CMP     r4, #CR
        ADDLO   r7, r7, #1              ; r7 -> variable value to set
        MOVHS   r4, #VarType_String     ; default type
        Push    "r4"                ; <== save for later

        MOV     r5, r7                  ; Find start of next variable name
30      LDRB    r14, [r5], #1
        CMP     r14, #CR                ; End of variable value ?
        BNE     %BT30                   ; r5 -> next variable name
 [ debuginit
 DSTRING r0,"Creating variable: ",cc
 DSTRING r7,", value: "
 DSTRING r5,"Next variable: "
 ]

        MOV     r1, r7
        Pull    "r4"
        BL      SSetVariableIfMissing
        BVC     %BT20
 [ debuginittime
        Pull    "r1"
 ]
        EXIT


40
 [ debuginittime
        Pull    "r1"
        SWI     XOS_ReadMonotonicTime
        SUB     r0, r0, r1
        SUB     sp, sp, #16
        MOV     r1, sp
        MOV     r2, #16
        SWI     XOS_ConvertCardinal4
        DSTRING r0,""
        ADD     sp, sp, #16
 ]
        BL      FileSwitch_ResetInitCommon

 [ debuginit
 DLINE "Issuing Service_FSRedeclare"
 ]
        MOVVC   r1, #Service_FSRedeclare ; Ask any Filing Systems to
        SWIVC   XOS_ServiceCall          ; (re)declare themselves to FileSwitch
                                         ; after we're on the vectors
 [ debuginit
 DLINE "Calling Init_InvalidateBGetCache"
 ]
        BL      Init_InvalidateBGetCache
        EXIT

FileSwitch_FirstVariableToCreate * .

; ************************** Path variables ***********************************

RunPathVariableNameCR   DCB     "Run$$Path", CR
RunPathVariableDefault  DCB     ",%.", CR       ; null then library

FilePathVariableNameCR  DCB     "File$$Path", CR
FilePathVariableDefault DCB     "", CR          ; just null

; ************************** Utility Options **********************************

 [ hascopy
CopyOptsVariableNameCR  DCB     "Copy$$Options", CR
CopyOptsVariableDefault DCB     "A C ~D ~F ~L ~N ~P ~Q ~R ~S ~T V", CR
 ]

 [ haswipe
WipeOptsVariableNameCR  DCB     "Wipe$$Options", CR
WipeOptsVariableDefault DCB     "C ~F ~R V", CR
 ]

 [ hascount
CountOptsVariableNameCR  DCB    "Count$$Options", CR
CountOptsVariableDefault DCB    "~C R ~V", CR
 ]

; ************************** Aliases for Run actions **************************

; (need space on end of ones without %*1 to get syntax error out of command
;  line decoder; would just append to file arg otherwise)

; No run action for BBC BBC ROM
;                   FE0 DeskUtil

; FE1..FE9 not yet allocated

        DCB     "Alias$$@RunType_FEA", CR  ; Desktop
        DCB     "Desktop -file %*0", CR

        DCB     "Alias$$@RunType_FEB", CR  ; Obey
        DCB     "Obey %0 ", CR

; No run action for FEC Template

        DCB     "Alias$$@RunType_FED", CR  ; Palette
        DCB     "WimpPalette %0 ", CR

; No run action for FEE Note pad
;                   FEF Diary

; FF0..FF1 not yet allocated

; FF3 not yet allocated

; No run action for FF4 PrintOut

; No run action for FF5 PoScript

; No run action for FF6 Font

        DCB     "Alias$$@RunType_FF7", CR  ; BBC font
        DCB     "Print %0 ", CR

; No run action for FF8 Absolute (can't be aliased)

        DCB     "Alias$$@RunType_FF9", CR
        DCB     "ScreenLoad %0 ", CR

        DCB     "Alias$$@RunType_FFA", CR  ; Module
        DCB     "RMRun %*0", CR

        DCB     "Alias$$@RunType_FFB", CR  ; Basic
        DCB     "Basic -quit ""%0"" %*1", CR

; No run action for FFC Transient (can't be aliased)
;                   FFD Data

        DCB     "Alias$$@RunType_FFE", CR  ; Command
        DCB     "Exec %0 ", CR

        DCB     "Alias$$@RunType_FFF", CR  ; Text
        DCB     "Type %0 ", CR

; *********************** Aliases for Load actions ****************************

; No load action for BBC BBC ROM
;                    FE0 DeskUtil deprecated

; FE1..FEA not yet allocated

; No load action for FEB Obey
;                    FEC Template
;                    FED Palette
;                    FEE Note pad deprecated
;                    FEF Diary    deprecated

; FF0..FF4 not yet allocated

; No load action for FF5 PoScript

; No load action for FF6 Font

        DCB     "Alias$$@LoadType_FF7", CR ; BBC font
        DCB     "Print %0 ", CR

; No load action for FF8 Absolute (can't be aliased)

        DCB     "Alias$$@LoadType_FF9", CR ; Sprite
        DCB     "SLoad %0 ", CR

        DCB     "Alias$$@LoadType_FFA", CR ; Module
        DCB     "RMLoad %*0", CR

        DCB     "Alias$$@LoadType_FFB", CR ; Basic
        DCB     "Basic -load ""%0"" %*1", CR

; No load action for FFC Transient (can't be aliased)
;                    FFD Data
;                    FFE Exec
;                    FFF Text

; ****************************** File type ************************************

; put application suite stuff in here (disc as well as ROM ones)

        DCB     "File$$Type_AFF", CR
        DCB     "DrawFile", CR

        DCB     "File$$Type_BBC", CR
        DCB     "BBC ROM", CR

        DCB     "File$$Type_F95", CR
        DCB     "Code", CR

        DCB     "File$$Type_FAE", CR   ; AMcC 27-Feb-95: for Toolbox
        DCB     "Resource", CR

; FE0 DeskUtil deprecated

; FE1..FE9 not yet allocated

        DCB     "File$$Type_FEA", CR
        DCB     "Desktop", CR

        DCB     "File$$Type_FEB", CR
        DCB     "Obey", CR

        DCB     "File$$Type_FEC", CR
        DCB     "Template", CR

        DCB     "File$$Type_FED", CR
        DCB     "Palette", CR

; FEE Note pad  deprecated
; FEF Diary     deprecated

; FF0..FF1 not yet allocated

        DCB     "File$$Type_FF2", CR
        DCB     "Config", CR

; FF3 LaserJet  deprecated

        DCB     "File$$Type_FF4", CR
        DCB     "Printout", CR

        DCB     "File$$Type_FF5", CR
        DCB     "PoScript", CR

        DCB     "File$$Type_FF6", CR
        DCB     "Font", CR

        DCB     "File$$Type_FF7", CR
        DCB     "BBC font", CR

        DCB     "File$$Type_FF8", CR
        DCB     "Absolute", CR

        DCB     "File$$Type_FF9", CR
        DCB     "Sprite", CR

        DCB     "File$$Type_FFA", CR
        DCB     "Module", CR

        DCB     "File$$Type_FFB", CR
        DCB     "BASIC", CR

        DCB     "File$$Type_FFC", CR
        DCB     "Utility", CR

        DCB     "File$$Type_FFD", CR
        DCB     "Data", CR

        DCB     "File$$Type_FFE", CR
        DCB     "Command", CR

        DCB     "File$$Type_FFF", CR
        DCB     "Text", CR

        DCB     &FF             ; End of variable (name,value) list
        ALIGN

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; FileSwitch_ResetInitCommon
; ==========================

; In    no parms

; Out   VC -> ok
;       VS -> fail
;       r0-r2 trashed

FileSwitch_ResetInitCommon Entry

 [ debuginit
 DLINE "ResetInitCommon"
 ]
 [ debuginittime
        DLINE   "Vectors and case table ",cc
        SWI     XOS_ReadMonotonicTime
        Push    "r0"
 ]
        MOV     r14, #0                 ; Not on UpCallV
        STRB    r14, copy_n_upcalls

        BL      SitOnVectors

        BL      ReadCaseTables
 [ debuginittime
        Pull    "r1"
        SWI     XOS_ReadMonotonicTime
        SUB     r0, r0, r1
        SUB     sp, sp, #16
        MOV     r1, sp
        MOV     r2, #16
        SWI     XOS_ConvertCardinal4
        DSTRING r0,""
        ADD     sp, sp, #16
 ]

        EXIT

        LTORG

FileSwitch_Service_TerritoryStarted
        LDR     R12,[R12]
ReadCaseTables EntryS
        BL      open_message_file
        MOV     r0, #-1
        SWI     XTerritory_UpperCaseTable
        MOVVS   r0, #Nowt
        STR     r0, UpperCaseTable
        MOV     r0, #-1
        SWI     XTerritory_LowerCaseTable
        MOVVS   r0, #Nowt
        STR     r0, LowerCaseTable
        EXITS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Die entry. r0-r6 trashable

; I think I can survive RMTidy now !

FileSwitch_Die Entry   "fp"
        ASSERT  fp <> r10
        MOV     fp, #0                  ; No frame, so don't set globalerror

        LDR     wp, [r12]

        LDR     r0, LinkedAreas         ; Can't be killed whilst threaded
        TEQ     r0, #Nowt
        ADRNEL  r0, ErrorBlock_FileSwitchCantBeKilledWhilstThreaded
        BLNE    copy_error
        EXIT    VS

 [ osfile5cache
        ; Discard file5 cache
        LDR     r2, OsFile5Cache
        MOV     lr, #Nowt
        STR     lr, OsFile5Cache
        BL      SFreeArea
 ]

        ; Close message file if open, ignore errors and zap the flags
        LDR     r0, message_file_flags
        TST     r0, #message_file_open
        ADRNE   r0, message_file_block
        SWINE   XMessageTrans_CloseFile
        MOV     r0, #0
        STR     r0, message_file_flags

 [ False ; By virtue of the above test, this can never be of use >>>a186<<<
        BL      SFreeAllLinkedAreasEverywhere ; ALL domains dying
 ]
        BL      DelinkTheLot            ; Need to devector during any death

 [ debuginit
        DLINE   "FileSwitch fatal death"
 ]
        BL      CloseAllFilesEverywhere ; Just make sure they're all dead

        LDR     r2, fschain             ; Point to first fscb
        B       %FT50
40
        LDR     r3, [r2, #fscb_link]    ; Remove link before deallocation
        BL      SFreeArea
        MOV     r2, r3                  ; Ignore errors, keep on going
50
        CMP     r2, #Nowt
        BNE     %BT40

        STR     r2, fschain             ; fschain empty

  [ MercifulToSysHeap
        BL      ReleaseHBlocks
  ]

        EXIT

        LTORG


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Service entry. No trashable registers. Services can't give errors back

        ASSERT  Service_Memory           <  Service_StartUpFS
        ASSERT  Service_StartUpFS        <  Service_Reset
        ASSERT  Service_Reset            <  Service_CloseFile
        ASSERT  Service_CloseFile        <  Service_TerritoryStarted
        ASSERT  Service_TerritoryStarted <  Service_DiscDismounted

FileSwitch_ServTab                                    ; Ursula format service table
        DCD     0                                     ; flags word
        DCD     FileSwitch_UService - Module_BaseAddr ; offset to handler (skip rapid rejection)
        DCD     Service_Memory                        ; service calls...
        DCD     Service_StartUpFS
        DCD     Service_Reset
        DCD     Service_CloseFile
        DCD     Service_TerritoryStarted
        DCD     Service_DiscDismounted                ; ...in ascending numerical order
        DCD     0                                     ; terminator
        DCD     FileSwitch_ServTab - Module_BaseAddr  ;anchor for table

FileSwitch_Service ROUT                               ; Rapid service rejection

        MOV     r0, r0                                ; magic instruction indicates Ursula format
        TEQ     r1, #Service_Memory
        TEQNE   r1, #Service_Reset
        TEQNE   r1, #Service_StartUpFS
        TEQNE   r1, #Service_DiscDismounted
        TEQNE   r1, #Service_CloseFile
        TEQNE   r1, #Service_TerritoryStarted
        MOVNE   pc, lr

FileSwitch_UService                                   ; Now go to the various service handlers...

        TEQ     r1, #Service_Memory
        BEQ     FileSwitch_Service_Memory

        TEQ     r1, #Service_DiscDismounted
        BEQ     FileSwitch_Service_DiscDismounted

        TEQ     r1, #Service_CloseFile
        BEQ     FileSwitch_Service_CloseFile

        TEQ     r1, #Service_TerritoryStarted
        BEQ     FileSwitch_Service_TerritoryStarted

        CMP     r1, #Service_Reset      ; CSet,EQ
        TEQNE   r1, #Service_StartUpFS*4,2 ; CClear,EQ. Dead sexy, huh ?
        MOVNE   pc, lr

        BCS     FileSwitch_Service_Reset ; Occurs infrequently!


; Select Filing System by number

FileSwitch_Service_StartUpFS Entry "r0, r2"

        MOV     r0, #FSControl_SelectFS
        AND     r1, r2, #&FF
        SWI     XOS_FSControl           ; Default -> no error, but may be vect.
        MOV     r1, #Service_Serviced   ; Claim the service
        EXIT

; .............................................................................

FileSwitch_Service_Reset Entry "r0-r2, fscb, fp"

        LDR     wp, [r12]
        MOV     fp, #0                  ; No frame, so don't set globalerror

        BL      SFreeAllLinkedAreasEverywhere ; Ensure clean start

        BL      FileSwitch_ResetInitCommon

        BL      ReadCurrentFS
        MOVVC   fscb, r0
 [ :LNOT: Embedded_UI                   ; Don't print FS on STB (non-desktop) type products
        BLVC    PrintFilingSystemText
 ]
        EXIT

; .............................................................................
; We must forbid memory being taken away from us if we are using apl

; In    r0 = amount of memory to ADD to apl (may be -ve: normal)
;       r2 = CAO pointer

FileSwitch_Service_Memory ROUT

 [ debugservice
 DREG r2,"Memory moving service: CAO "
 ]
        CMP     r0, #0                  ; Can always ADD to apl size
        MOVPL   pc, lr                  ; when we own it, just forbid takeaway

; It would be nice to allow memory to be taken away up to the point where
; we are currently using for the copy buffer, but as we don't have any
; means of domain identification, I refuse to consider this.

        addr    r12, Module_BaseAddr    ; We are CAO when doing Copy Q
        CMP     r2, r12                 ; on a per domain basis
        ADRHSL  r12, FileSwitch_ModuleEnd
        CMPHS   r12, r2
        MOVHS   r1, #Service_Serviced   ; Claim service - CAO is us
 [ debugservice
 TEQ r1, #Service_Serviced
 BNE %FT00
 DLINE "Forbidding memory move: FileSwitch owns this domain's apl"
00
 ]
        MOV     pc, lr

; .............................................................................
; When a nice filing system has told us a disc's been dismounted, we aught to
; unset any directories on that disc.

; In    r2 = pointer to \0-terminated string of disc been dismounted:
;               <FS>[#<special>]::<disc>

; Out   service unclaimed and dirs unset as appropriate

FileSwitch_Service_DiscDismounted Entry "fp"
        MOV     fp, #0
        LDR     wp,[r12]
        BL      UnsetMatchingDirs
        EXIT

; .............................................................................
; Request to close any unneeded files

; In    r2 = pointer to \0-terminated path wanted closed
;       r3 = files closed so far

; Out   service unclaimed, applicable MultiFS files closed and
;       r3 incremented by number of files closed

FileSwitch_Service_CloseFile Entry "r0,r1,r2,r3,r6,scb,fscb,fp"
 [ debugservice
        DSTRING r2, "Service_CloseFile(",cc
        DLINE   ")"
 ]
        MOV     fp, #0
        LDR     wp, [r12]

        MOV     r1, #MaxHandle          ; Loop over handles in stream table

10      BL      FindStream              ; Get scb^ for this handle, VClear
        BEQ     %FT60

 [ debugservice
        DREG    r1, "Trying stream #"
 ]

        ; MultiFS image?
        LDR     lr, scb_fscbForContents
        TEQ     lr, #Nowt
        BEQ     %FT60

        Push    "r1"

        ; MultiFS image which is child of path supplied?
        LDR     r1, scb_path
        LDR     r6, scb_special
        LDR     fscb, scb_fscb
        MOV     r3, sp
        BL      int_ConstructFullPathOnStack

        LDR     r1, [r3, #1*4+2*4]
        MOV     r2, sp
 [ debugservice
        DSTRING r2, "Stream path ",cc
        DSTRING r1, " ? service path "
 ]
        BL      IsAChild_advance
        MOV     sp, r3
        BNE     %FT50

 [ debugservice
        DLINE   "It's a match - check for sub-files..."
 ]

        MOV     r2, scb

        ; File is a MultiFS - check whether we have only MultiFS children of this file
        MOV     r1, #MaxHandle
15
        BL      FindStream
        BEQ     %FT20

17
        ; MultiFS image?
        LDR     r0, scb_fscbForContents
        TEQ     r0, #Nowt
        BNE     %FT20

        ; Inside a MultiFS image?
        LDR     r0, scb_fscb
        LDRB    lr, [r0, #fscb_info]
        TEQ     lr, #0
        BNE     %FT20

        ; Inside the MultiFS image we're thinking about?
        LDR     scb, scb_special
        TEQ     scb, r2
        BEQ     %FT55
        B       %BT17

20
        SUBS    r1, r1, #1
        BHI     %BT15

        ; Only MultiFS images are children of this image - close it
        MOV     scb, r2

 [ debugservice
        DLINE   "It's a cop your honour - closing it now"
 ]

        BL      FlushAndCloseStream
 [ debugservice
        DLINE   "Closing done"
 ]

; Ignore any errors that this may give

        ; hah! closed one more
        LDR     r3, [sp, #3*4 + 1*4]
        ADD     r3, r3, #1
        STR     r3, [sp, #3*4+1*4]
        B       %FT55

50

55
        Pull    "r1"

60      SUBS    r1, r1, #1              ; Last valid handle = 1
        BNE     %BT10                   ; VClear from SUBS
 [ debugservice
        DLINE   "All files checked - returning"
 ]

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Vector claim/release routines

SitOnVectors Entry "r0-r4"

        ADR     r4, FileSwitch_VectorTable
        ADR     r3, FileSwitch_VectorNumberTable

10      LDRB    r0, [r3], #1            ; Load vector number
        CMP     r0, #&FF                ; End entry ?
        EXIT    EQ

        LDR     r14, [r4], #4           ; Form address of routine
        ADD     r1, r4, r14             ; NB. r2 advanced !
        MOV     r2, wp
 [ debugvector
 DREG r0, "Claiming vector ",cc,Byte
 DREG r1, ", address ",cc
 DREG r2, ", ws^ "
 ]
        SWI     XOS_Claim               ; Ensure on only once
        BVC     %BT10                   ; Loop if ok

        STR     r0, [sp]
        BL      DelinkTheLot            ; Preserves V
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   V preserved

DelinkTheLot EntryS "r0-r4"

        ADR     r4, FileSwitch_VectorTable
        ADR     r3, FileSwitch_VectorNumberTable

10      LDRB    r0, [r3], #1            ; Load vector number
        CMP     r0, #&FF                ; End entry ?
        EXITS   EQ

        LDR     r14, [r4], #4
        ADD     r1, r4, r14             ; Form address of routine
        MOV     r2, wp
 [ debugvector
 DREG r0, "Freeing vector ",cc,Byte
 DREG r1, ", address ",cc
 DREG r2, ", ws^ "
 ]
        SWI     XOS_Release
        B       %BT10                   ; Loop

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Vectors claimed (released) on FileSwitch initialisation and reset (death)

FileSwitch_VectorTable

        DCD     FSControlEntry  -.-4    ; Pretty naff addressing, huh ?
        DCD     FileEntry       -.-4    ; Goes with the pretty naff code
        DCD     FindEntry       -.-4    ; ie. LDR rn, [r2], #4
        DCD     MultipleEntry   -.-4
        DCD     ArgsEntry       -.-4
        DCD     BGetEntry       -.-4
        DCD     BPutEntry       -.-4

FileSwitch_VectorNumberTable

        DCB     FSCV
        DCB     FileV
        DCB     FindV
        DCB     GBPBV
        DCB     ArgsV
        DCB     BGetV
        DCB     BPutV

        DCB     &FF                     ; End of table marker
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                           E X I T   P O I N T S
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    lr(Punter) stacked. This has his NZVC state, so be careful.
;       r14 -> errorblock, 0 if no error

FileSwitchExit ROUT

 [ paranoid
 Push r14
 LDR r14,LinkedAreas ; Can only debug globals here !
 TEQ r14,#Nowt
 BEQ %FT00
 DLINE "LinkedAreas not empty",,inv
00
 Pull r14
 ]
 [ No26bitCode
        CMP     r14, #0                 ; clear V
 |
        TEQ     r14, #0
 ]
 [ anyfiledebug
 BEQ %FT00
 DREG r14, "globalerror on exit "
00
 ]
 [ debugreturnparams
        DREG    r0, "Returning: ",cc
        DREG    r1, ",",cc
        DREG    r2, ",",cc
        DREG    r3, ",",cc
        DREG    r4, ",",cc
        DREG    r5, ",",cc
        DREG    r6, ",",cc
        DREG    r7, ",",cc
        DREG    r8, ",",cc
        DREG    r9, ",",cc
        DREG    r10, ",",cc
        DREG    r11, ","
 ]
 [ No26bitCode
        Pull    pc, EQ                  ; don't preserve NZC on 32-bit systems
 |
        Pull    lr, EQ
        BICEQS  pc, lr, #V_bit          ; Return to punter, NZC flags intact
 ]
        ; Fall through for NE

; .............................................................................
; In    r14 -> error block

FileSwitchErrorExit

        MOV     r0, r14                 ; r0 -> error block
 [ No26bitCode
        SETV
        Pull    pc                      ; don't preserve NZC on 32-bit systems
 |
        Pull    lr
        ORRS    pc, lr, #V_bit          ; Return to punter, NZC flags intact
 ]

; .............................................................................
; In    C flag significant and should be returned to punter
;       r14 -> error block, 0 if no error

FileSwitchExitSettingC ROUT

        TEQ     r14, #0                 ; Careful to preserve C !
        BNE     FileSwitchErrorExit

 [ No26bitCode
        CLRPSR  V_bit, lr               ; clear V carefully, preserving C
        Pull    pc                      ; NZ corrupted
 |
        Pull    lr
        BIC     lr, lr, #V_bit          ; ??? Does this have VClear anyway ? (No - KJB)
        BICCCS  pc, lr, #C_bit          ; Return to punter, NZ flags intact
        ORRCSS  pc, lr, #C_bit
 ]

; .............................................................................

  [ MercifulToSysHeap

;mjs: these routines are similar to the ChocolateBlock stuff in Ursula
;     kernel - see s.ChangeDyn for more comments there

; CreateHBlockArray
; entry: r2 = No. of blocks to be created in array (N)
;        r3 = size of each block in bytes (S, must be multiple of 4)
;
; exit:
;        r2 = address of block array (parent SysHeap block address)
;        array is initialised to all blocks free
;   OR   V set, r0=error pointer, if error
;
CreateHBlockArray ROUT
        Push    "r0,r1,r3,r4,r5,lr"
        MOV     r5,r2                ;N
        ADD     r4,r3,#4             ;S+4
        MUL     r3,r5,r4
        ADD     r3,r3,#3*4
        BL      MTSH_SMustGetArea
        STRVS   r0,[SP]
        BVS     %FT50
        STR     r5,[r2]
        STR     r4,[r2,#4]
        ADD     r1,r2,#3*4
        STR     r1,[r2,#8]
        MOV     lr,r5
        ADD     r0,r2,#3*4
        MOV     r1,#&80000000        ;free flag
10
        STR     r1,[r0]
        ADD     r3,r0,r4
        STR     r3,[r0,#4]
        ADD     r1,r1,r4
        SUBS    lr,lr,#1
        MOVNE   r0,r3
        BNE     %BT10
        MOV     r1,#0
        STR     r1,[r0,#4]           ;end of free list
50
        Pull    "r0,r1,r3,r4,r5,pc"

;
; ClaimHBlock
;
; entry: r3 = address of parent HBlockArray (must be valid)
; exit:  r2 = address of allocated block
;        r3 = size of block
;  OR    V set, but no error ptr in R0 (no free blocks - must be dealt with silently)
;
ClaimHBlock ROUT
        Push    "r1,r4,lr"
        SavePSR r4
        SETPSR  I_bit, r1         ;protect critical manipulation from interrupt re-entry
        LDR     r2,[r3,#8]        ;pick up block container at front of free list
        CMP     r2,#0
        BEQ     ClaimHBlock_NoneFree
        LDR     r1,[r2]
        BIC     r1,r1,#&80000000  ;clear the free flag
        STR     r1,[r2]
        LDR     r1,[r2,#4]        ;next free block container
        STR     r1,[r3,#8]        ;put it at front
        ADD     r2,r2,#4          ;address of block
        LDR     r3,[r3,#4]
        SUB     r3,r3,#4          ;size of block
        BIC     r4,r4,#V_bit      ;return with V clear
        RestPSR r4,,cf            ;restore IRQ state
        Pull    "r1,r4,pc"
ClaimHBlock_NoneFree
        ORR     r4,r4,#V_bit      ;return with V set
        RestPSR r4,,cf            ;restore IRQ state
        Pull    "r1,r4,pc"

;
; FreeHBlock
;
; entry: r1 = address of parent HBlockArray (must be valid)
;        r2 = address of block to free (may be invalid)
; exit:  -
;   OR   V set, (not a valid HBlock), no error ptr in r0, but r1,r2 still preserved
;
FreeHBlock ROUT
        Push    "r2,r3,r4,lr"
        SavePSR r4
        SETPSR  I_bit,r3          ;protect critical manipulation from interrupt re-entry
        ADD     r3,r1,#12         ;r3 -> first block container
        SUB     r2,r2,#4          ;r2 -> container for block (if valid)
        CMP     r2,r3
        BLO     FreeHBlock_NaffOff
        LDR     lr,[r1,#-4]       ;OS_Heap's size word (naughty!)
        ADD     lr,lr,r1
        CMP     r2,lr
        BHS     FreeHBlock_NaffOff
        LDR     lr,[r2]           ;block container id
        TST     lr,#&80000000     ;free flag
        BNE     FreeHBlock_NaffOff
        ADD     lr,lr,r3          ;lr := address of block container, from container id
        CMP     lr,r2
        BNE     FreeHBlock_NaffOff
;
;we now believe caller is freeing a valid block, currently in use
;
        LDR     lr,[r2]
        ORR     lr,lr,#&80000000
        STR     lr,[r2]           ;set free flag in container id
        LDR     lr,[r1,#8]        ;current front of free list
        STR     lr,[r2,#4]        ;chain free list to block container we are freeing
        STR     r2,[r1,#8]        ;put freed block container at front
        BIC     r4,r4,#V_bit      ;return with V clear
        RestPSR r4,,cf            ;restore IRQ state
        Pull    "r2,r3,r4,pc"
FreeHBlock_NaffOff
        ORR     r4,r4,#V_bit      ;return with V set
        RestPSR r4,,cf            ;restore IRQ state
        Pull    "r2,r3,r4,pc"

; InitHBlocks
;
InitHBlocks ROUT
        Push    "r2,r3,lr"
        MOV     r2,#0
        STR     r2,HBlocks_Valid
        MOV     r2,#NHBlocks_32
        MOV     r3,#32              ;size
        BL      CreateHBlockArray
        BVS     %FT90
        STR     r2,HBlockArray_32
        MOV     r2,#NHBlocks_64
        MOV     r3,#64              ;size
        BL      CreateHBlockArray
        BVS     %FT90
        STR     r2,HBlockArray_64
        MOV     r2,#NHBlocks_128
        MOV     r3,#128             ;size
        BL      CreateHBlockArray
        BVS     %FT90
        STR     r2,HBlockArray_128
        MOV     r2,#NHBlocks_1040
        MOV     r3,#1040            ;size
        BL      CreateHBlockArray
        BVS     %FT90
        STR     r2,HBlockArray_1040
        MOV     r2,#-1
        STR     r2,HBlocks_Valid
  [ MercifulTracing
        MOV     r2,#0
        STR     r2,NHB_total
        STR     r2,NHB_fail
        STR     r2,HB_failmax
  ]
90
        Pull    "r2,r3,pc"

;
; ReleaseHBlocks
;
ReleaseHBlocks ROUT
        Push    "r0-r3,lr"
        MOV     r0,#0
        STR     r0,HBlocks_Valid
        MOV     r0,#HeapReason_Free
        LDR     r1,SysHeapStart
        MOV     r3,#0
        LDR     r2,HBlockArray_32
        STR     r3,HBlockArray_32
        CMP     r2,#0
        SWINE   XOS_Heap
        LDR     r2,HBlockArray_64
        STR     r3,HBlockArray_64
        CMP     r2,#0
        SWINE   XOS_Heap
        LDR     r2,HBlockArray_128
        STR     r3,HBlockArray_128
        CMP     r2,#0
        SWINE   XOS_Heap
        LDR     r2,HBlockArray_1040
        STR     r3,HBlockArray_1040
        CMP     r2,#0
        SWINE   XOS_Heap
        CLRV
        Pull    "r0-r3,pc"

  ] ;MercifulToSysHeap

        END
