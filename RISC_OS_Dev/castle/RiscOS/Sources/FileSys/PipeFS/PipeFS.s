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
; > Sources.PipeFS

; *********************************
; ***    C h a n g e   L i s t  ***
; *********************************

; Date       Description
; ----       -----------
; 27-Apr-1990     0.03    File created from ResourceFS 0.03
; 01-May-1990     0.04    OSFile_Load/Save allowed if file closed
; 08-May-1990     0.05    Fixed a storage leak in deletepipe
; 09-May-1990             Don't stop blocking if reader wants file size
;                 0.06    Fix bug: errors garbled from *PipeCopy
; 10-May-1990     0.07    Fix bug: don't extend file if blocking possible
; 11-May-1990     0.08    Fix bug: allow *Create if file only open for reading and empty
; 14-May-1990     0.09    Fix bug: *Create should zero file length, and mark "not written"
; 14-May-1990     0.10    Get case-equivalencing to work properly on directory enumeration
; 27-Mar-1991 ECN 0.11    Internationalised
; 09-Oct-1991 ECN 0.12    Fix open for update so it creates pipe
; 11-Dec-1991 SMC 0.13    Changed to use global messages BadFSOp, Escape, IsAFil
; 08-Feb-1993 SMC 0.14    Use Hdr: to get headers.
; 22-Jan-2001 ADH 0.19    File heap in private dynamic area; two different ways of issuing
;                         UpCall_ModifyingFile, much better than old "every byte" approach

        AREA |PipeFS$$Code|, CODE, READONLY, PIC

Module_BaseAddr

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:Machine.<Machine>
        GET     Hdr:CMOS
        GET     Hdr:Proc
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:LowFSI
        GET     Hdr:NewErrors
        GET     Hdr:FileTypes
        GET     Hdr:Variables
        GET     Hdr:Wimp
        GET     Hdr:UpCall
        GET     Hdr:MsgTrans
        GET     Hdr:Heap

        GET     VersionASM

        GET     Hdr:NDRDebug

        GBLL    debug
        GBLL    debugup
        GBLL    debugrg
        GBLL    debugfs
        GBLL    debugda
        GBLL    debugxx
        GBLL    hostvdu

debug   SETL    {FALSE}                  ; set to true, then turn on individual areas
debugup SETL    debug :LAND: {FALSE}
debugrg SETL    debug :LAND: {FALSE}
debugfs SETL    debug :LAND: {FALSE}
debugda SETL    debug :LAND: {FALSE}
debugxx SETL    debug :LAND: {FALSE}
hostvdu SETL    {FALSE}                  ; set to true to use TML (HostFS) output

        ; 22-Jan-2001 (ADH)
        ;
        ; Set dynamicareas to true to always use a dynamic area for the file heap
        ; or set to false to use RMA. There's no run-time detection.

        GBLL    dynamicareas
dynamicareas            SETL    {TRUE}

        ; 22-Jan-2001 (ADH)
        ;
        ; There's no OS_GBPB entry point, so PipeFS' individual get/put byte code
        ; gets called instead. Unfortunately this issues UpCall_ModifyingFile for
        ; every single byte read or written, which is horribly slow. If you use
        ; upcalloncallback (uncommenting relevant code throughout this file), then
        ; an array of filename pointers is constructed until eventually a callback
        ; goes off which scans the array and calls the "modifyingfile" routine for
        ; each of those R1 values.
        ;
        ; However, "modifyingfile" actually ignores the R1 value and sets a null
        ; filename instead (owing to auto directory creation headaches I think) so
        ; the array maintenance overhead is unnecessary. The array code is only
        ; present in case anyone comes up with better UpCall generation code. In
        ; the mean time, use "delayedupcall". This uses a simple flagged callback
        ; to raise the UpCall. It's not very efficient to use a null filename like
        ; this, of course, because all directories will be rescanned.

        GBLL    upcalloncallback
        GBLL    delayedupcall
upcalloncallback        SETL    {FALSE} ; otherwise, use "dynamicareas", *not* "true"
delayedupcall           SETL    :LNOT: upcalloncallback

    [ :LNOT: :DEF: international_help
        GBLL    international_help
international_help SETL {TRUE}          ; Default to RISC OS 3.60+ internationalisation
    ]

; File header format

                      ^ 0
PipeFile_Load         # 4                ; load address
PipeFile_Exec         # 4                ; exec address
PipeFile_Ext          # 4                ; total bytes written to file
PipeFile_Attr         # 4                ; file attributes
PipeFile_Size         # 4                ; size of file
PipeFile_usage        # 4                ; is file open for read/write?
PipeFile_readPTR      # 4                ; where to read bytes
PipeFile_writePTR     # 4                ; where to write bytes
PipeFile_wrapstart    # 4                ; buffer start
PipeFile_wrapend      # 4                ; buffer end
PipeFile_readblocked  * PipeFile_Size    ; block if attempting to read
PipeFile_writeblocked # 4                ; block if attempting to write
PipeFile_lenblocked   # 4                ; block if attempting to read length
PipeFile_Name         # 0                ; null terminated file name

PipeFS_BufferSize     * &100             ; fixed size minimum allocated for data
PipeFS_AllocSize      * &10              ; fixed size incremental allocation

; extra bits involved in a file handle

pipehandle_read       * 1 :SHL: 0        ; set => this is the read handle
pipehandle_write      * 1 :SHL: 1        ; set => this is the write handle
pipehandle_bits       * pipehandle_read :OR: pipehandle_write

; main workspace contents

                      ^ 0, wp

lastleafname          # 4                ; for directory enumeration
PipeFSFileData        # 4                ; points to list of link_ items
MessageFile_Block     # 16
MessageFile_Open      # 4

 [ dynamicareas
PipeFS_PageSize       # 4                ; heap is always at least 1 page
PipeFS_DAHandle       # 4                ; file heap dynamic area handle
PipeFS_DABase         # 4                ; area's base address
PipeFS_DASize         # 4                ; area's current size
 ]

 [ upcalloncallback
UpCallArray           # 4                ; base of array of R1 values
UpCallItems           # 4                ; number of items in the array
 ]

 [ upcalloncallback :LOR: delayedupcall
UpCallFlag            # 4                ; non-zero = callback has been set
 ]

PipeFS_WorkspaceSize  * :INDEX: @

                      ^ 0
link_data             # 4                ; points to list of files
link_next             # 4
link_size             # 0

; dynamic area reason codes aren't in a Hdr file currently

 [ dynamicareas
                      ^ 0
DAReason_Create       # 1
DAReason_Remove       # 1
DAReason_Information  # 1
DAReason_Enumerate    # 1
DAReason_Renumber     # 1
 ]

; **************** Module code starts here **********************

        ASSERT  (.-Module_BaseAddr) = 0

        DCD     0                    ; PipeFS_Start    - Module_BaseAddr
        DCD     PipeFS_Init     - Module_BaseAddr
        DCD     PipeFS_Die      - Module_BaseAddr
        DCD     PipeFS_Service  - Module_BaseAddr
        DCD     PipeFS_Title    - Module_BaseAddr
        DCD     PipeFS_HelpStr  - Module_BaseAddr
        DCD     PipeFS_HC_Table - Module_BaseAddr
        DCD     0                    ; MySWIBase
        DCD     0                    ; PipeFS_SWIdecode- Module_BaseAddr
        DCD     0                    ; PipeFS_SWInames - Module_BaseAddr
        DCD     0
 [ international_help
        DCD     message_filename - Module_BaseAddr
 |
        DCD     0
 ]
 [ :LNOT:No32bitCode
        DCD     module_flags    - Module_BaseAddr
 ]

PipeFS_Title
        =       "PipeFS", 0

PipeFS_HelpStr
        =       "PipeFS", 9, 9, "$Module_MajorVersion ($Module_Date)"
      [ Module_MinorVersion <> ""
        =       " $Module_MinorVersion"
      ]
        DCB     0
        ALIGN

 [ :LNOT:No32bitCode
module_flags
        DCD     ModuleFlag_32bit
 ]

 [ dynamicareas
PipeFS_DAName
        DCB     "PipeFS", 0
 ]

 [ international_help
PipeFS_HC_Table
        Command PipeCopy, 3, 2, International_Help
        DCB     0

PipeCopy_Help   DCB     "HPFSCPY", 0
PipeCopy_Syntax DCB     "SPFSCPY", 0
 |
PipeFS_HC_Table
        Command PipeCopy, 3, 2, 0
        DCB     0

PipeCopy_Help
        DCB     "*PipeCopy copies files one byte at a time", 13, 10

PipeCopy_Syntax
        DCB     "Syntax: *PipeCopy <inputfile> <outputfile> [<outputfile>]", 0
 ]
        ALIGN

; *****************************************************************************
;
; This command allows byte copying of one file to another
; *Copy will not work on pipes because it sometimes uses OS_File Load and Save
;

PipeCopy_Code   ROUT
        Push    "R1-R6,LR"

        MOV     R1, R0          ; R1 -> command tail

10      LDRB    R14, [R1], #1
        CMP     R14, #" "
        BEQ     %BT10
        SUB     R1, R1, #1

        MOV     R0, #OSFind_ReadFile
        SWI     XOS_Find        ; R0 = file handle
        BVS     %FT90
        MOVVC   R5, R0          ; R5 = input file handle

11      LDRB    R14, [R1], #1
        CMP     R14, #" "
        BHI     %BT11
        SUBLO   R1, R1, #1

        MOV     R0, #OSFind_OpenOut :OR: open_mustopen :OR: open_nodir
        SWI     XOS_Find        ; R0 = file handle
        BVS     %FT80
        MOVVC   R6, R0          ; R6 = output file handle

12      LDRB    R14, [R1], #1
        CMP     R14, #" "
        BHI     %BT12
        SUBLO   R1, R1, #1

        MOVLO   R0, #0
        MOVEQ   R0, #OSFind_OpenOut :OR: open_mustopen :OR: open_nodir
        SWIEQ   XOS_Find        ; R0 = file handle
        BVS     %FT70
        MOV     R7, R0          ; R7 = output file handle #2

20      MOV     R1, R5
        SWI     XOS_BGet
        BCS     %FT60           ; EOF
        MOVVC   R1, R6
        SWIVC   XOS_BPut        ; copy to file 1
        BVS     %FT60
        MOVS    R1, R7
        SWINE   XOS_BPut        ; copy to file 2
        BVC     %BT20

60      MOV     R4, R0
        SavePSR R3
        SUBS    R0, R0, R0      ; clear V also
        MOVS    R1, R7          ; close output file #2
        SWINE   XOS_Find
        MOVVC   R0, R4
        RestPSR R3, VC

70      MOV     R4, R0
        SavePSR R3
        SUBS    R0, R0, R0      ; clear V also
        MOV     R1, R6          ; close output file
        SWI     XOS_Find
        MOVVC   R0, R4
        RestPSR R3, VC

80      MOV     R4, R0
        SavePSR R3
        SUBS    R0, R0, R0      ; clear V also
        MOV     R1, R5          ; close input file
        SWI     XOS_Find
        MOVVC   R0, R4
        RestPSR R3, VC
90
        Pull    "R1-R6,PC"

; *****************************************************************************

StringROM       =       "Pipe",0                   ; FS name is "Pipe:"
StringPipeFS     =       "Acorn PipeFS",0
                ALIGN

FSInfoBlock     DCD     StringROM-Module_BaseAddr
                DCD     StringPipeFS-Module_BaseAddr
                DCD     PipeFS_Open-Module_BaseAddr      ; open files
                DCD     PipeFS_GetByte-Module_BaseAddr   ; get byte
                DCD     PipeFS_PutByte-Module_BaseAddr   ; put byte
                DCD     PipeFS_Args-Module_BaseAddr      ; OSARGS
                DCD     PipeFS_Close-Module_BaseAddr     ; close files
                DCD     PipeFS_OSFile-Module_BaseAddr    ; osfile etc
fsinfoword      DCD     fsnumber_pipefs :OR: fsinfo_alwaysopen :OR: fsinfo_fsfilereadinfonolen :OR: fsinfo_dontuseload :OR: fsinfo_dontusesave
                DCD     PipeFS_FSFunc-Module_BaseAddr    ; fs func
                DCD     0                                ; OSGBPB

; *****************************************************************************
;
;       PipeFS_Init - Initialisation entry
;

PipeFS_Init Entry

        LDR     R2, [R12]               ; have we got workspace yet ?
        TEQ     R2, #0
        MOVNE   R12, R2
        BNE     %FT05

        MOV     R0, #ModHandReason_Claim
        MOV     R3, #PipeFS_WorkspaceSize
        SWI     XOS_Module
        EXIT    VS

        STR     R2, [R12]               ; save address in my workspace pointer,
                                        ; so Tutu can free it for me when I die
        MOV     R12, R2

 [ dynamicareas

        SWI     XOS_ReadMemMapInfo
        EXIT    VS
        STR     R0, PipeFS_PageSize
        MOV     R2, R0                  ; initial size for OS_DynamicArea, below

        MOV     R0, #DAReason_Create
        MVN     R1, #0                  ; must be -1
        MVN     R3, #0                  ; must be -1
        MOV     R4, #1<<7               ; flags: bit 7 set -> not resizeable from Task Manager
        MOV     R5, #&1000000           ; 16MB maximum size
        MOV     R6, #0                  ; no handler routine
        MOV     R7, #0
        ADR     R8, PipeFS_DAName
        SWI     XOS_DynamicArea
        EXIT    VS

        Debug  da, "PipeFS dynamic area created - handle, size, base:",R1,R2,R3

        STR     R1, PipeFS_DAHandle     ; remember the important details
        STR     R2, PipeFS_DASize
        STR     R3, PipeFS_DABase

        MOV     R0, #HeapReason_Init    ; initialise the area as a heap
        MOV     R1, R3
        LDR     R3, PipeFS_PageSize
        SWI     XOS_Heap
 ]

05      MOV     R14, #0                 ; no files yet
        STR     R14, PipeFSFileData
        STR     R14, MessageFile_Open

 [ upcalloncallback

        STR     R14, UpCallArray
        STR     R14, UpCallItems
 ]

 [ upcalloncallback :LOR: delayedupcall

        STR     R14, UpCallFlag
 ]
        BL      PipeFS_Declare           ; call FileSwitch
        EXIT

; *****************************************************************************
;
; Declare PipeFS: to FileSwitch (called on Init and Service_FSRedeclare)
;

PipeFS_Declare Entry "R1-R3"

        MOV     R0, #FSControl_AddFS    ; add this filing system
        ADR     R1, Module_BaseAddr
        MOV     R2, #FSInfoBlock-Module_BaseAddr
        MOV     R3, R12
        Debug   fs,"OS_FSControl (AddFS)",R0,R1,R2,R3
        SWI     XOS_FSControl

        EXIT

; *****************************************************************************
;
;       PipeFS_Die - Die entry
;
; Deallocate link blocks, issue FSControl_RemoveFS
;

PipeFS_Die Entry

        LDR     R12, [R12]              ; R12 -> workspace
        TEQ     R12, #0
        BEQ     %FT02
        LDR     r0, MessageFile_Open
        CMP     r0, #0
        ADRNE   r0, MessageFile_Block
        SWINE   XMessageTrans_CloseFile
        LDR     R2, PipeFSFileData
        TEQ     R2, #0
01      LDRNE   R3, [R2, #link_next]
        STRNE   R3, PipeFSFileData      ; remove link
        MOVNE   R0, #upfsfile_Delete    ; tell the Filer
        BLNE    modifyingfiles          ; (preserves flags)
 [ :LNOT: dynamicareas
        MOVNE   R0, #ModHandReason_Free
        SWINE   XOS_Module
 ]
        MOVNES  R2, R3
        BNE     %BT01

 [ dynamicareas
        MOV     R0, #DAReason_Remove
        LDR     R1, PipeFS_DABase
        CMP     R1, #0
        LDRNE   R1, PipeFS_DAHandle
        SWINE   XOS_DynamicArea
 ]

 [ upcalloncallback :LOR: delayedupcall
        LDR     R0, UpCallFlag
        CMP     R0, #0
        ADRNEL  R0, modifyingpipecb
        MOVNE   R1, R12
        SWINE   XOS_RemoveCallBack
 ]

02      MOV     R0, #FSControl_RemoveFS
        addr    R1, StringROM           ; ADR or ADRL as appropriate
        SWI     XOS_FSControl

        CLRV
        EXIT

; *****************************************************************************
;
; modifyingfiles - tell the Filer that files are being created / deleted
;
; In    R0 = reason code to pass in R9 to upcall
; Out   UpCall_ModifyingFile called for ""
;       This causes all directories to be re-scanned!
;       It may be hard to work out which directories are being created / deleted
;

modifyingfiles EntryS "R1"

        ADR     R1, null                ; R1 -> filename ("") - R2-R5 corrupt
        BL      modifyingfile

        EXITS

null    DCB     0
        ALIGN

; *****************************************************************************
;
; In    R0 = reason code to pass in R9 to upcall
;       R1 -> filename being modified
; Out   UpCall_ModifyingFile called for [R1..]
;
; Use of the "delayedupcall" code assumes that R1 is ignored on entry and
; set to 'null' internally. Use "upcalloncallback" if R1 is actually read.
;

modifyingfile EntryS "R0-R10"

        LDR     R8, fsinfoword          ; R8 = fs info word
        MOV     R9, R0                  ; R9 = reason code
        ADR     R1, null                ; R1 -> filename ("") - R2-R5 corrupt
        MOV     R6, #0                  ; no special field
        MOV     R0, #UpCall_ModifyingFile
        SWI     XOS_UpCall              ; ignore errors

        EXITS

; *****************************************************************************
;
;       PipeFS_Code - Process *PipeFS command
;
; in:   R0 -> rest of line
;       R1 = number of parameters
;
; out:  R0-R6, R12 corrupted
;

PipeFS_Code Entry
        MOV     R0, #FSControl_SelectFS
        addr    R1, StringROM           ; ADR or ADRL as appropriate
        SWI     XOS_FSControl           ; select filing system
        EXIT

; *****************************************************************************
;
;       PipeFS_Service - Main entry point for services
;
; in:   R1 = service reason code
;       R2 = sub reason code
;       R3-R5 parameters
;
; out:  R1 = 0 if we claimed it
;       R2 preserved
;       R3-R5 = ???
;

;Ursula format
;
UServTab
        DCD     0
        DCD     UService - Module_BaseAddr
        DCD     Service_FSRedeclare
        DCD     0
        DCD     UServTab - Module_BaseAddr
PipeFS_Service ROUT
        MOV     r0,r0
        TEQ     R1, #Service_FSRedeclare        ; has someone reinited Stu ?
        MOVNE   PC, LR                          ; no, then exit
UService
        LDR     R12, [R12]

svc_fsredeclare Entry  "R0-R3"

        BL      PipeFS_Declare                   ; else redeclare myself

        EXIT

; *****************************************************************************
;
;       PipeFS_OSFile - Entry point for OSFILE operations
;
; in:   R0 = reason code
;       R1-R? parameters
;

PipeFS_OSFile EntryS "R1,R7,R9"

        CMP     R0, #fsfile_Load        ; can only load if file closed
        BEQ     %FT10

        CMP     R0, #fsfile_Save        ; can only save if file closed
        BEQ     %FT15

        CMP     R0, #fsfile_ReadInfo
        BEQ     %FT20                   ; read file info

        CMP     R0, #fsfile_ReadInfoNoLen
        BEQ     %FT25                   ; read file info without length

        CMP     r0, #fsfile_Delete      ; delete file
        BEQ     %FT30

        CMP     R0, #fsfile_Create
        BEQ     %FT40

        CMP     R0, #fsfile_CreateDir
        EXIT    EQ

        MOV     r9, #0
        CMP     r0, #fsfile_WriteInfo
        MOVEQ   r9, #2_111              ; write load, exec, attributes
        CMP     r0, #fsfile_WriteLoad
        MOVEQ   r9, #2_001              ; write load
        CMP     r0, #fsfile_WriteExec
        MOVEQ   r9, #2_010              ; write exec
        CMP     r0, #fsfile_WriteAttr
        MOVEQ   r9, #2_100              ; write attributes

        CMP     r9, #0
        EXITS   EQ                      ; none of the above

        Push    "r0,r2-r6"
        BL      FindFileOrDirectory
        CMP     r0, #object_file        ; can't do this with directories
        Pull    "r0,r2-r6"
        EXITS   NE

        TST     r9, #2_001
        STRNE   r2, [r1, #PipeFile_Load]
        TST     r9, #2_010
        STRNE   r3, [r1, #PipeFile_Exec]
        TST     r9, #2_100
        STRNE   r5, [r1, #PipeFile_Attr]

        EXITS


; load file
; done by opening the file and getting bytes from it
; not allowed if file is open already (length is unknown)
;
; in:   r1 -> filename
;       r2 -> buffer to load file to
; out:  r0 corrupted
;       r2-r5 contain file info
;       r6 -> filename for *OPT 1,1 info

10
        Push    "r2-r5"

        MOV     r0, #fsopen_ReadOnly
        BL      PipeFS_Open             ; only needs r0, r1
        BVS     %f90
        CMP     r1, #0
        ADREQ   r0, ErrorBlock_PipeFS_FileNotFound
        BLEQ    CopyError               ; r1 is already 0 for CopyError
        BVS     %f90

        BIC     r7, r1, #pipehandle_bits
        LDR     r14, [r7, #PipeFile_lenblocked]
        TEQ     r14, #0
        ADREQ   r0, ErrorBlock_PipeFS_FileOpen ; error if we're blocked here
        MOVEQ   r1, #0
        BLEQ    CopyError
        BVS     %f80

        LDR     r2, [sp]                    ; r2 -> output buffer
        LDR     r3, [r7, #PipeFile_Size]    ; r3 = number of bytes to transfer
11
        SUBS    r3, r3, #1
        BLT     %f80
        BL      PipeFS_GetByte          ; can't block as file must have been written
        STRVCB  r0, [r2], #1
        BVC     %b11
80
        MOV     r5, r0
        SavePSR r6
        ASSERT  PipeFile_Load = 0
        ASSERT  PipeFile_Exec = 4
        LDMIA   r7, {r2, r3}            ; don't affect datestamp
        BL      PipeFS_Close
        MOVVC   r0, r5
        RestPSR r6, VC
90
        Pull    "r2-r5"

        ASSERT  PipeFile_Load = 0
        LDMVCIA r7, {r2-r5}             ; get file info

        BLVC    getleafname             ; for *OPT 1,1

        EXIT

        MakeInternatErrorBlock PipeFS_FileNotFound,,M02

; save file
; done by opening the file and putting bytes to it
; not allowed if file is open for writing already
;
; in:   r1 -> filename
;       r2 = new file load address
;       r3 = new file exec address
;       r4 -> start of buffer
;       r5 -> end of buffer
;       r6 -> special field, if any
;
; out:  r6 -> filename for *OPT 1,1 info

15
        Push    "r2-r5"

        MOV     r0, #fsopen_CreateUpdate
        BL      PipeFS_Open
        BVS     %FT95                   ; no need to close file
        CMP     r1, #0
        ADREQ   r0, ErrorBlock_PipeFS_FileOpen ; assume file was already open
        BLEQ    CopyError               ; r1 is already 0 for CopyError
        BVS     %f95

        SUBVC   r2, r5, r4              ; new buffer size
        BLVC    try_ensuresize          ; do this in one go
        BVS     %f85

        BIC     r7, r1, #pipehandle_bits
        SUB     r3, r5, r4              ; r3 = number of bytes to transfer
16
        SUBS    r3, r3, #1
        BLT     %f85
        LDRB    r0, [r4], #1
        BL      PipeFS_PutByte          ; may attempt to block
        BVC     %b16
85
        MOV     r5, r0
        SavePSR r6
        LDMIA   sp, {r2, r3}            ; new load and exec addresses
        BL      PipeFS_Close
        MOVVC   r0, r5
        RestPSR r6, VC

        BLVC    getleafname             ; for *OPT 1,1
95
        Pull    "r2-r5"

        EXIT

; read file info
; If file still open, the length will not be very useful, as it may increase
; However, if the caller does an OS_File Load afterwards, he will get an error
; Unfortunately I can't return an error from this routine (it assumes its not a file)
;
; in:   R1 -> wildcarded filename
; out:  R0 = object type
;       R2 = load address
;       R3 = exec address
;       R4 = size
;       R5 = attributes

20
        Push    "r6"
        BL      FindFileOrDirectory
        Pull    "r6"
        EXIT    VS

        CMP     r0, #object_file        ; if file found, wait for it to close for writing
        EXIT    NE

        BL      blockifwriting          ; this may be bad news, if we are reading the file
        EXIT    VS                      ; since it will never be unblocked
        EXIT    EQ
        B       %b20                    ; file still open

; read file info without length
; in:   R1 -> wildcarded filename
; out:  R0 = object type
;       R2 = load address
;       R3 = exec address
;       R5 = attributes

25
        Push    "r4,r6"
        BL      FindFileOrDirectory
        Pull    "r4,r6"
        EXIT                            ; no need to block since length not returned

; delete file
; in:    R1 -> wildcarded filename

30
        Push    "R1-R6"

        BL      FindFile                ; R1 -> file header
        CMP     R1, #object_nothing
        BEQ     %FT31

        LDR     R14, [R1, #PipeFile_usage]
        TST     R14, #read_attribute :OR: write_attribute
        ADRNE   r0, ErrorBlock_PipeFS_FileOpen
        MOVNE   r1, #0
        BLNE    CopyError
        BLVC    deletepipe              ; R1 -> file header
31
        Pull    "R1-R6"

        EXIT

        MakeInternatErrorBlock PipeFS_FileOpen,,M01

; create file
; in:   R1 -> wildcarded filename
;       R2,R3 = new load/exec addresses
;       R5-R4 = size to create with
; out:  R6 -> filename

40
        Push    "R1-R5"

        BL      getpipe                 ; R1 -> file header
        BVS     %FT41

        LDR     R14, [R1, #PipeFile_usage]
        EOR     R14, R14, #notwritten   ; error if open for reading and has been written
        TST     R14, #notwritten
        TSTNE   R14, #read_attribute
        TSTEQ   R14, #write_attribute   ; error if open for output
        ADRNE   r0, ErrorBlock_PipeFS_FileOpen
        MOVNE   r1, #0
        BLNE    CopyError

        ORRVC   R14, R14, #notwritten   ; pretend file hasn't yet been written
        STRVC   R14, [R1, #PipeFile_usage]

        LDRVC   R14, [R1, #PipeFile_readPTR]     ; always produce zero-length file
        STRVC   R14, [R1, #PipeFile_writePTR]
        MOVVC   R14, #0
        STRVC   R14, [R1, #PipeFile_Size]
        STRVC   R14, [R1, #PipeFile_Ext]
        ASSERT  PipeFile_readblocked = PipeFile_Size
        MOVVC   R14, #1
        STRVC   R14, [R1, #PipeFile_writeblocked]
        STRVC   R14, [R1, #PipeFile_lenblocked]

        LDMVCIB sp, {R2-R5}             ; get load/exec addresses and size
        ASSERT  PipeFile_Load = 0
        ASSERT  PipeFile_Exec = 4
        STMVCIA r1, {r2,r3}
        SUBVC   r2, r5, r4              ; r2 = new size to ensure
        BLVC    try_ensuresize

        MOVVC   r7, r1
        BLVC    getleafname             ; for *OPT 1,1
41
        Pull    "R1-R5"

        EXIT


; in:   r1 -> file header
; out:  r0 corrupted
;       EQ => file not open for writing
;       NE => file was open for writing, and we blocked
;       VS => blocking not possible - r0 -> error

blockifwriting Entry "r1"

        LDR     r14, [r1, #PipeFile_lenblocked]!
        TEQ     r14, #1                 ; 1 => unblocked, 0 => blocked
        LDREQ   r14, [r1, #PipeFile_usage-PipeFile_lenblocked]
        BICEQ   r14, r14, #nowriteblock
        STREQ   r14, [r1, #PipeFile_usage-PipeFile_lenblocked]   ; can block on write now
        EXIT    EQ
        MOV     r0, #UpCall_Sleep       ; try to wait till file closed
        Debug   up,"PipeFS: OS_UpCall sleep (readlen)"
        SWI     XOS_UpCall
        TEQ     r0, #UpCall_Sleep
        ADREQ   r0, ErrorBlock_PipeFS_FileOpen ; can't block
        MOVEQ   r1, #0
        BLEQ    CopyError
        EXIT

; *****************************************************************************
;
;       PipeFS_FSFunc - Various functions
;
; in:   R0 = reason code
;

PipeFS_FSFunc Entry

        Debug   fs,"FSFunc",R0

        TEQ     R0, #fsfunc_Cat
        BEQ     %FT10

        TEQ     R0, #fsfunc_ReadDirEntries
        TEQNE   R0, #fsfunc_ReadDirEntriesInfo
        BEQ     PipeFS_fsfunc_readdirentries
        ASSERT  PipeFS_fsfunc_readdirentries = PipeFS_fsfunc_readdirentriesinfo
        TEQ     R0,#fsfunc_Dir
        TEQNE   R0,#fsfunc_Lib
        TEQNE   R0,#fsfunc_Ex
        TEQNE   R0,#fsfunc_LCat
        TEQNE   R0,#fsfunc_LEx
        TEQNE   R0,#fsfunc_Info
        TEQNE   R0,#fsfunc_Opt
        TEQNE   R0,#fsfunc_ReadDiscName
        TEQNE   R0,#fsfunc_ReadCSDName
        TEQNE   R0,#fsfunc_ReadLIBName
        TEQNE   R0,#fsfunc_PrintBanner
        TEQNE   R0,#fsfunc_SetContexts
        TEQNE   R0,#fsfunc_CatalogObjects
        TEQNE   R0,#fsfunc_FileInfo
        TEQNE   R0,#fsfunc_Rename
        TEQNE   R0,#fsfunc_Access
        BLEQ    NotSupportedError

        EXIT                    ; ignore any other reason codes (unknown)
                                ; ShutDown and Bootup are also ignored

; Returns a "Pipe: does not support this operation" error
; Out:  r0 -> error block, V set

NotSupportedError
        Push    "lr"
        ADR     r0, ErrorBlock_PipeFS_NotSupported
        ADRL    r1, StringROM
        BL      CopyError
        Pull    "lr"
        RETURNVS

        MakeInternatErrorBlock PipeFS_NotSupported,,BadFSOp

; *cat
; in: R1 -> dirname (ignored)
;

10
        Debug   fs,"*Cat: R1 =",R1

        LDR     R3, PipeFSFileData               ; head of chain

20      CMP     R3, #0                           ; no more files?
        EXIT    EQ
        LDR     R1, [R3, #link_data]

        ADD     R0, R1, #PipeFile_Name
        SWI     XOS_Write0
        SWIVC   XOS_NewLine

        LDRVC   R3, [R3, #link_next]
        BVC     %BT20

        EXIT

; *****************************************************************************
;
; in:   R1 -> wildcarded directory name
;       R2 -> buffer to put data
;       R3 = number of object names to read
;       R4 = offset of first item to read in directory
;       R5 = buffer length
;       R6 -> special field (ignored)
; out:  R3 = number of names read
;       R4 = offset of next item to read (-1 if end)
;

PipeFS_fsfunc_readdirentries      ROUT
PipeFS_fsfunc_readdirentriesinfo  ROUT

        Push    "R0-R2, R5-R11"                 ; LR already stacked

        MOVS    R6, R4                          ; R6 = no of entries to skip
        MOVLT   R6, #&100000                    ; convert -ve to large +ve

        ADD     R7, R6, R3                      ; R7 = no. to read / skip

        MOV     R8, R2                          ; R8 -> output buffer
        MOV     R9, #0                          ; R9 = files read so far

; read directory entries, skipping the first few (0..R4-1)

        BL      skipdollar                      ; R1 -> rest of name

        STR     R9, lastleafname                ; 0 => no names yet
01
        BL      FindDirEntry                    ; R2 -> current entry
        BVS     %FT99
        BNE     %FT04                           ; R4 -> leafname
        CMP     R9, R6
        ADDLT   R9, R9, #1
        BLT     %BT01

; count length of leafname and remember terminator

        MOV     R10, R4
02      LDRB    R14, [R10], #1
        CMP     R14, #"."
        CMPNE   R14, #0
        BNE     %BT02                           ; R14 = terminator of leafname
        SUB     R10, R10, R4                    ; R10 = length of leafname

; calculate space required for this entry and check space left

        TEQ     R0, #fsfunc_ReadDirEntries
        ADDNE   R10, R10, #5*4 + 3
        BICNE   R10, R10, #3                    ; R10 = length of this entry

        SUBS    R5, R5, R10
        BLT     %FT04                           ; won't fit

; write out file/dir info if required

        Push    "R0-R5"
        CMP     R14, #"."
        MOVNE   R5, #object_file                ; type = file
        MOVEQ   R5, #object_directory           ; type = directory
        TEQ     R0, #fsfunc_ReadDirEntries
        ASSERT  PipeFile_Load = 0
      [ PipeFile_Size > PipeFile_Attr
        LDRNE   R14, [R2, #PipeFile_Size]
      ]
        LDMNEIA R2, {R1-R4}
      [ PipeFile_Size > PipeFile_Attr
        MOVNE   R3, R14                         ; R3 = size (bytes in buffer)
      ]
        STMNEIA R8!, {R1-R5}
        Pull    "R0-R5"

; now copy in the leafname, and word-align if R0 = fsfunc_ReadDirEntries

03      LDRB    R14, [R4], #1
        CMP     R14, #"."
        CMPNE   R14, #0                         ; zero-terminated in PipeFS:
        MOVEQ   R14, #0
        STRB    R14, [R8], #1
        BNE     %BT03

        TEQ     R0,#fsfunc_ReadDirEntries
        ADDNE   R8, R8, #3
        BICNE   R8, R8, #3

        ADD     R9, R9, #1                      ; successfully read file
        CMP     R9, R7                          ; continue until all read
        BLT     %BT01

; buffer filled / no more files - set up correct registers for return

04      MOV     R4, R9                          ; R4 = index of next one
        SUBS    R3, R9, R6                      ; R3 = no of files read
        MOVLT   R3, #0
        MOVLE   R4, #-1                         ; no files read => all done
99
        STRVS   R0, [sp, #Proc_RegOffset]
        Pull    "R0-R2, R5-R11, PC"

; *****************************************************************************
;
;       PipeFS_Open - Open a file
;
; in:   R0 = open reason code
;       R1 -> filename
;       R3 = handle
;       R6 -> special field (irrelevant)
; out:  R0 = file information word (not FS info word)
;       R1 = internal file handle
;       R2 = buffer size for FileSwitch (0 if unbuffered)
;       R3,R4 irrelevant if no buffering
;

PipeFS_Open EntryS "R3-R6"

        CMP     R0, #fsopen_ReadOnly
        BEQ     openforreading

        CMP     R0, #fsopen_CreateUpdate
        BEQ     openforwriting

        CMP     R0, #fsopen_Update
        BLNE    NotSupportedError
        EXIT    VS

openforupdate
        BL      getpipe
        BVS     errnofile

        LDR     R14, [R1, #PipeFile_usage]
        TST     R14, #write_attribute
        BNE     errnofile                       ; can't open twice
        ORR     R14, R14, #write_attribute
        STR     R14, [R1, #PipeFile_usage]

        LDR     R0, =fsopen_WritePermission :OR: fsopen_Interactive
        B       openedforwriting

openforwriting
        BL      getpipe                         ; creates if not already there
        BVS     errnofile                       ; R1 -> file header on exit

        LDR     R14, [R1, #PipeFile_usage]
        TST     R14, #write_attribute
        BNE     errnofile                       ; can't open twice
        ORR     R14, R14, #write_attribute
        STR     R14, [R1, #PipeFile_usage]

        LDR     R14, [R1, #PipeFile_wrapstart]  ; throw away previous contents
        STR     R14, [R1, #PipeFile_readPTR]
        STR     R14, [R1, #PipeFile_writePTR]
        MOV     R14, #0
        STR     R14, [R1, #PipeFile_Size]       ; current bytes in buffer
        STR     R14, [R1, #PipeFile_Ext]        ; total bytes ever written

        LDR     R0, =fsopen_WritePermission :OR: fsopen_Interactive

openedforwriting
        MOV     r14, #0                         ; indicate that length can't be read
        STR     r14, [r1, #PipeFile_lenblocked]
        ORR     R1, R1, #pipehandle_write
        MOV     R2, #0                          ; no buffering
        EXITS
                                                ; and drop through to return handle=0
errnofile
        MOV     R1, #0                          ; no file opened
        MOV     R2, #0
        EXITS

openforreading
        BL      getpipe                         ; creates if not already there
        BVS     errnofile                       ; R1 -> file header on exit

        LDR     R14, [R1, #PipeFile_usage]
        TST     R14, #read_attribute
        BNE     errnofile                       ; can't open twice
        ORRVC   R14, R14, #read_attribute
        STRVC   R14, [R1, #PipeFile_usage]

        LDR     R0, =fsopen_ReadPermission :OR: fsopen_Interactive
        ORR     R1, R1, #pipehandle_read
        MOV     R2, #0                          ; no buffering

        EXITS
        LTORG

; *****************************************************************************
;
; in:   R1 -> filename
; out:  R1 -> file header (created if file didn't exist)
;       R2-R5 = load,exec,size,attr
;       R6 -> filename (for *OPT 1,1)
;

getpipe ROUT
        Push    "r1,lr"
        BL      FindFile
        TEQ     r1, #0
        ADDNE   sp, sp, #4
        Pull    "r1", EQ
        BLEQ    createpipe                      ; out: R1 -> file header
        Pull    "pc"

; *****************************************************************************
;
; in:   R1 -> filename
; out:  R1 -> file header (with a 'PipeFS_BufferSize' sized data buffer)
;

notread         *       1 :SHL: 5               ; file has not been closed for reading
notwritten      *       1 :SHL: 6               ; file has not been closed for writing
nowriteblock    *       1 :SHL: 7               ; don't block on write - expand buffer
                ASSERT  notread > write_attribute
                ASSERT  notread > read_attribute

createpipe Entry "r2-r5"

        BL      skipdollar                      ; don't store the "dollar"

        MOV     R3, R1
01      LDRB    R14, [R3], #1
        CMP     R14, #32
        BHI     %BT01

        SUB     R3, R3, R1
        ADD     R3, R3, #link_size + PipeFile_Name
        MOV     R0, #ModHandReason_Claim
 [ dynamicareas
        BL      claimheapchunk
 |
        SWI     XOS_Module
 ]
        EXIT    VS

        Push    "R2"

        MOV     R4, R1                          ; R4 -> filename

        ADD     R1, R2, #link_size
        STR     R1, [R2, #link_data]
        LDR     R14, PipeFSFileData
        STR     R14, [R2, #link_next]

        ADD     R5, R1, #PipeFile_Name
02      LDRB    R14, [R4], #1                   ; copy filename over
        CMP     R14, #32
        STRHIB  R14, [R5], #1
        BHI     %BT02
        MOV     R14, #0
        STRB    R14, [R5]

        LDR     R2, =&DEADDEAD                  ; initial load/exec addresses = "dead"
        LDR     R3, =&DEADDEAD
        MOV     R4, #0                          ; size = 0
        MOV     R5, #read_attribute :OR: write_attribute
        ASSERT  PipeFile_Load = 0
        STMIA   R1, {R2-R5}

        ASSERT  PipeFile_readblocked = PipeFile_Size ; this one's easy
        MOV     r14, #1
        STR     r14, [r1, #PipeFile_lenblocked]     ; not blocked, as file is not open
        STR     r14, [r1, #PipeFile_writeblocked]   ; not blocked, as there is space in the buffer

      [ PipeFile_Ext > PipeFile_Attr
        STR     R4, [R1, #PipeFile_Ext]         ; no bytes written to file yet
      ]
      [ PipeFile_Size > PipeFile_Attr
        STR     R4, [R1, #PipeFile_Size]        ; no bytes written to file yet
      ]

        MOV     R4, #notwritten :OR: notread    ; not yet finished writing or reading
        STR     R4, [R1, #PipeFile_usage]

        MOV     R3, #PipeFS_BufferSize

        MOV     R0, #ModHandReason_Claim
 [ dynamicareas
        BL      claimheapchunk
 |
        SWI     XOS_Module
 ]

        STRVC   R2, [R1, #PipeFile_wrapstart]
        ADDVC   R3, R2, R3
        STRVC   R3, [R1, #PipeFile_wrapend]
        STRVC   R2, [R1, #PipeFile_readPTR]
        STRVC   R2, [R1, #PipeFile_writePTR]

        Pull    "R2"
        BVS     %f90

        STR     R2, PipeFSFileData              ; add file to list if OK

        BL      modifyingpipe                   ; R1 -> file header
        EXIT

90      MOV     r4, r0
        SavePSR r5
        MOV     R0, #ModHandReason_Free
 [ dynamicareas
        BL      releaseheapchunk
 |
        SWI     XOS_Module                      ; error caused because no room for buffer
 ]
        MOVVC   r0, r4
        RestPSR r5, VC

        EXIT
        LTORG

; *****************************************************************************
;
;       PipeFS_Close - Close a file
;
; in:   R1 = file handle = file header pointer + read/write bits
;       R2 = new load address
;       R3 = new exec address
; out:  file closed if not open for reading or writing, and has at some
;       point been open for reading (this allows the file to be read later)
;

PipeFS_Close EntryS "R0-R2"

        TST     R1, #pipehandle_read
        MOVEQ   R0, #PipeFile_writeblocked
        MOVNE   R0, #PipeFile_readblocked
        BL      sleepnomore                     ; R1=handle, R0=offset
        BVS     %f99
        TEQ     R0, #PipeFile_readblocked
        MOVEQ   R0, #PipeFile_lenblocked        ; reader may be reading length
        BLEQ    sleepnomore
        BVS     %f99

        TST     R1, #pipehandle_read
        MOVNE   R0, #read_attribute :OR: notread :OR: notwritten
        MOVEQ   R0, #write_attribute :OR: notwritten
        BIC     R1, R1, #pipehandle_bits        ; R1 -> file header

        ASSERT  PipeFile_Load = 0
        ASSERT  PipeFile_Exec = 4
        STMIA   r1, {r2,r3}                     ; write back new datestamp

        LDR     R14, [R1, #PipeFile_usage]
        BIC     R14, R14, R0
        STR     R14, [R1, #PipeFile_usage]

        TST     R14, #write_attribute           ; if not open for writing,
        MOVEQ   R0, #1                          ; you can read the length again
        STREQ   R0, [R1, #PipeFile_lenblocked]

        TST     R14, #read_attribute :OR: write_attribute :OR: notread :OR: notwritten
        LDREQ   R14, [R1, #PipeFile_readPTR]    ; and no data remaining
        LDREQ   R2, [R1, #PipeFile_writePTR]
        CMPEQ   R2, R14

        BLEQ    deletepipe                      ; delete file if not open and it's empty

        EXITS   VC
99      STR     R0, [sp, #Proc_RegOffset]
        EXIT


; in:   R1 = internal file handle
;       R0 = offset of sleep word within header
; out:  any sleepers notified; error if sleeper objects

sleepnomore Entry "R0,R1"

        BIC     R1, R1, #pipehandle_bits
        ADD     R1, R1, R0
        MOV     R0, #UpCall_SleepNoMore
        SWI     XOS_UpCall

        STRVS   R0, [sp, #Proc_RegOffset]
        EXIT

; *****************************************************************************
;
; in:   R1 -> file header
; out:  file deleted, and UpCall_ModifyingFile called
;

deletepipe EntryS "R0-R3"

        BL      checkexists                     ; check R1 -> a valid file header
        MOVVC   R3, R0                          ; R2, R3 -> current/previous links
        MOVVC   R0, #PipeFile_lenblocked
        BLVC    sleepnomore                     ; forget about file length if it's deleted!
        BVS     %f99

        LDR     R14, [R2, #link_next]           ; remove from list
        STR     R14, [R3, #link_next]

        MOV     R0, #upfsfile_Delete
        ADD     R1, R1, #PipeFile_Name - PipeFile_lenblocked
        BL      modifyingfile                   ; file has gone!

        Push    "R2"
        LDR     R2, [R2, #link_data]            ; actually part of the same block
        LDR     R2, [R2, #PipeFile_wrapstart]
        MOV     R0, #ModHandReason_Free
 [ dynamicareas
        BL      releaseheapchunk
 |
        SWI     XOS_Module                      ; free buffer block
 ]
        Pull    "R2"
        MOV     R1, R0
        SavePSR R3
        MOV     R0, #ModHandReason_Free
 [ dynamicareas
        BL      releaseheapchunk
 |
        SWI     XOS_Module                      ; free header block
 ]
        MOVVC   R0, R1
        RestPSR R3, VC
99
        EXITS   VC
        STRVS   R0, [sp, #Proc_RegOffset]
        EXIT    VS

; in:   r1 -> file header (I think!)
; out:  r0 -> previous link, if header exists
;       r0 -> "Channel" error if the file no longer exists
;       r2 -> current link

checkexists Entry "r1"

        ADR     R0, PipeFSFileData - link_next
01      LDR     R2, [R0, #link_next]
        CMP     R2, #0
        ADREQ   r0, ErrorBlock_PipeFS_Channel
        MOVEQ   r1, #0
        BLEQ    CopyError
        EXIT    VS
        LDR     R14, [R2, #link_data]
        CMP     R14, R1
        MOVNE   R0, R2
        BNE     %BT01

        EXIT

        MakeInternatErrorBlock PipeFS_Channel,,M03

; *****************************************************************************
;
;       PipeFS_GetByte
;
; in:   R1 = file handle (pointer + read/write bits)
; out:  R0 = byte read, C clear
;       R0 = undefined, C set if EOF
;
; NB: If EOF is reached and the file is still open for writing, UpCall_Sleep
;     should be called to let the other end write some data.
;

PipeFS_GetByte Entry "R1,R4"

        BIC     R1, R1, #pipehandle_bits        ; ignore bits 0..1

get_loop
        LDR     R4, [R1, #PipeFile_readPTR]
        LDR     R14,[R1, #PipeFile_writePTR]
        CMP     R4,R14                  ; C set if PTR >= EXT
        BEQ     get_eof

        LDRB    R0, [R4], #1
        LDR     R14, [R1, #PipeFile_wrapend]
        CMP     R4, R14
        LDRCS   R4, [R1, #PipeFile_wrapstart]
        STR     R4, [R1, #PipeFile_readPTR]

        LDR     R14, [R1, #PipeFile_Size]
        SUB     R14, R14, #1
        STR     R14, [R1, #PipeFile_Size]

        ASSERT  PipeFile_readblocked = PipeFile_Size    ; read blocked if no bytes in buffer
        MOV     r14, #1
        STR     r14, [r1, #PipeFile_writeblocked]       ; must be able to write now

        BL      modifyingpipe

        MOVS    R14,R0,LSL #1           ; clear C
        EXIT
        LTORG

get_eof
        LDR     R14, [R1, #PipeFile_usage]
        TST     R14, #write_attribute :OR: notwritten   ; is file still open for writing?
        EXIT    EQ                      ; CS => EOF

        MOV     R0, #UpCall_Sleep
        ADD     R1, R1, #PipeFile_readblocked           ; 0 => blocked on read
        Debug   up,"PipeFS: OS_UpCall sleep (read)"
        SWI     XOS_UpCall
        SUB     R1, R1, #PipeFile_readblocked
        TEQ     R0, #UpCall_Sleep
        ADREQ   r0, ErrorBlock_PipeFS_NoBlocking
        MOVEQ   r1, #0
        BLEQ    CopyError
        BLVC    checkexists                     ; make sure we can find it again!
        EXIT    VS

        SWI     XOS_ReadEscapeState
        BCC     get_loop

        ADRCS   r0, ErrorBlock_Escape
        MOVCS   r1, #0
        BLCS    CopyError
        EXIT    VS

        MakeInternatErrorBlock PipeFS_NoBlocking,,M00
        MakeInternatErrorBlock Escape

; *****************************************************************************
;
; in:   R12 = pointer to workspace
;
; ** Only included if upcalloncallback = true.
;

 [ upcalloncallback

modifyingpipecb EntryS "R0-R10"

        MOV     R3, #0
        STR     R3, UpCallFlag          ; clear callback pending flag

        LDR     R3, UpCallItems
        CMP     R3, #0                  ; any items in the array?
        BEQ     %FT01
        LDRNE   R2, UpCallArray         ; get array base address in R2
        CMPNE   R2, #0                  ; sanity check...
        BEQ     %FT01

02      SUB     R3, R3, #4
        LDR     R1, [R2, R3]            ; load last item in array

        LDR     R0, =upfsopen_Update    ; cause dir recache
        ADD     R1, R1, #PipeFile_Name
        BL      modifyingfile

        CMP     R3, #0                  ; check for more items
        BGT     %BT02

        BL      releaseheapchunk        ; get rid of the array
        MOV     R0, #0
        STR     R0, UpCallArray
        STR     R0, UpCallItems
01
        EXITS
 ]

; *****************************************************************************
;
; in:   R12 = pointer to workspace
; out:
;
; ** Only included if delayedupcall = true
;

 [ delayedupcall

modifyingpipecb EntryS "R0-R10"

        MOV     R3, #0
        STR     R3, UpCallFlag          ; clear callback pending flag

        BL      modifyingfiles          ; issue the UpCall

        EXITS
 ]

; *****************************************************************************
;
; in:   R1 -> file header
; out:  modifyingfile called with appropriate filename, or callback to do
;       a similar action is set
;

modifyingpipe EntryS "R0-R3"

 [ upcalloncallback

        LDR     R2, UpCallArray         ; do we have an array for R1 values yet?
        CMP     R2, #0
        BNE     %FT02                   ; if not, check the array for our current R1 value

        MOV     R3, #4                  ; otherwise, need 4 bytes for 1 entry
        BL      claimheapchunk          ; claim space for the new array item
        BVS     %FT01

        B       %FT04

02      LDR     R3, UpCallItems         ; get number of items currently in array * 4
03      SUB     R3, R3, #4
        LDR     R0, [R2, R3]            ; get the last item in the array
        CMP     R0, R1                  ; same as our R1 value?
        BEQ     %FT01                   ; if so, there's nothing to do
        CMP     R3, #0
        BGT     %BT03                   ; get another item

        LDR     R3, UpCallItems         ; OK, we need to add the R1 value
        ADD     R3, R3, #4
        BL      extendheapchunk         ; extend the array for the new item
        BVS     %FT01

04      STR     R2, UpCallArray         ; store the new array details
        STR     R3, UpCallItems
        SUB     R3, R3, #4
        STR     R1, [R2, R3]            ; store R1 in the array
 ]

 [ upcalloncallback :LOR: delayedupcall

        LDR     R0, UpCallFlag
        CMP     R0, #0
        BNE     %FT01                   ; don't add a callback if it is already pending

        ADR     R0, modifyingpipecb     ; callback routine to call
        MOV     R1, R12                 ; (with the workspace pointer)
        SWI     XOS_AddCallBack
        BVS     %FT01
        MOV     R0, #1
        STR     R0, UpCallFlag          ; mark callback set
 |

        LDR     R0, =upfsopen_Update    ; cause dir recache
        ADD     R1, R1, #PipeFile_Name
        BL      modifyingfile
 ]

01
        EXITS

; *****************************************************************************
;
;       PipeFS_PutByte
;
; in:   R0 = byte to put to file
;       R1 = file handle (pointer + read/write handle bit)
;
; NB: If cyclic buffer is full, UpCall_Sleep should be called to let the
;     other end read some data.
;

PipeFS_PutByte EntryS "R0-R5"

        BIC     R1, R1, #pipehandle_bits        ; ignore bits 0..1

put_loop
        LDR     R4, [R1, #PipeFile_writePTR]
        LDR     R14, [R1, #PipeFile_wrapend]
        ADD     R5, R4, #1
        CMP     R5, R14
        LDRCS   R5, [R1, #PipeFile_wrapstart]

        LDR     R14, [R1, #PipeFile_readPTR]
        CMP     R5, R14
        STRNEB  R0, [R4]
        STRNE   R5, [R1, #PipeFile_writePTR]
        LDRNE   R14, [R1, #PipeFile_Size]
        ADDNE   R14, R14, #1
        STRNE   R14, [R1, #PipeFile_Size]
        LDRNE   R14, [R1, #PipeFile_Ext]
        ADDNE   R14, R14, #1
        STRNE   R14, [R1, #PipeFile_Ext]
        BLNE    modifyingpipe
        EXITS   NE

        LDR     r14, [r1, #PipeFile_usage]      ; don't block if the other end
        TST     r14, #nowriteblock              ; is trying to determine file size
        BNE     tryextend

        MOV     r14, #0
        STR     r14, [r1, #PipeFile_writeblocked]!   ; 0 => blocked on write
        Debug   up,"PipeFS: OS_UpCall sleep (write)"
        MOV     R0, #UpCall_Sleep
        SWI     XOS_UpCall
        SUB     R1, R1, #PipeFile_writeblocked
        MOV     R4, R0                          ; R4 = upcall claimed indicator
        BLVC    checkexists                     ; make sure we can find it again!
        BVS     %FT99

        CMP     R4, #UpCall_Sleep
        BEQ     tryextend                       ; if no blocking, try to extend buffer

        SWI     XOS_ReadEscapeState
        LDRCC   R0, [sp, #Proc_RegOffset]       ; recover byte to store
        BCC     put_loop

        ADRCS   r0, ErrorBlock_Escape
        MOVCS   r1, #0
        BLCS    CopyError
99
        STRVS   R0, [sp, #Proc_RegOffset]
        EXIT    VS

tryextend
        LDR     r2, [r1, #PipeFile_wrapend]
        LDR     r14, [r1, #PipeFile_wrapstart]
        SUB     r2, r2, r14
        ADD     r2, r2, #PipeFS_BufferSize
        BL      ensuresize                      ; try to grab another &100 bytes
        LDRVC   R0, [sp, #Proc_RegOffset]       ; recover byte to store
        BVC     put_loop
        BVS     %BT99

; Check whether we are allowed to block.
; If not, call ensuresize (more efficient this way)
;
; In:   R1 -> file header
;       R2 = new extent to ensure
; Out:  R2 = extent actually ensured (always the same - pretend we can do it)
;       Error if not enough room in RMA

try_ensuresize Entry "r0-r4"

        MOV     r0, #UpCall_Sleep
        ADD     r1, r1, #PipeFile_lenblocked
        Debug   up,"PipeFS: OS_UpCall sleep (ensuresize)"
        SWI     XOS_UpCall                      ; should return pretty quickly
        SUB     r1, r1, #PipeFile_lenblocked
        MOV     r4, r0
        BLVC    checkexists                     ; file may have disappeared
        BVS     %f99
        CMP     r4, #UpCall_Sleep
        LDMEQIA sp, {r0-r2}
        BLEQ    ensuresize                      ; only extend if no blocking possible
99
        STRVS   R0, [sp, #Proc_RegOffset]
        EXIT

; Allocate at least the given buffer size to a file
; Called from OSArgs_EnsureSize, OSFile_Create, and PipeFS_PutByte
;
; In:   R1 -> file header
;       R2 = new extent to ensure
; Out:  R2 = extent actually ensured (in fact always the same)
;       Error if not enough room in RMA

ensuresize Entry "r0,r2-r6"

        CMP     r2, #PipeFS_BufferSize          ; min buffer size
        MOVLT   r2, #PipeFS_BufferSize
        ADD     r2, r2, #PipeFS_AllocSize - 1   ; round up to a multiple of alloc size
        BIC     r6, r2, #PipeFS_AllocSize - 1   ; r6 = new block size

        LDR     r4, [r1, #PipeFile_wrapstart]
        LDR     r5, [r1, #PipeFile_wrapend]
        SUB     r14, r5, r4                     ; r14 = current size of buffer
        SUBS    r3, r6, r14                     ; r3 = difference
        EXIT    LS                              ; don't bother!

        MOV     r2, r4                          ; r2 -> current buffer
        MOV     r0, #ModHandReason_ExtendBlock  ; r3 = amount to extend by
 [ dynamicareas
        BL      extendheapchunk
 |
        SWI     XOS_Module
 ]
        BVS     %FT99

; now copy the bit between readPTR and wrapend up to the top of the block

        SUB     r14, r2, r4                     ; r14 = offset (movement of block)
        STR     r2, [r1, #PipeFile_wrapstart]
        ADD     r3, r2, r6
        STR     r3, [r1, #PipeFile_wrapend]     ; r3 = new end pointer

        ADD     r5, r5, r14                     ; r5 -> end of data to copy
        LDR     r4, [r1, #PipeFile_readPTR]     ; r4 = old read pointer
        ADD     r4, r4, r14                     ; r4 -> start of data to copy
        CMP     r4, r2                          ; if read is at start
        MOVEQ   r3, r2                          ; don't copy any data

        LDR     r2, [r1, #PipeFile_writePTR]
        ADD     r2, r2, r14
        STR     r2, [r1, #PipeFile_writePTR]

        BEQ     %f02                            ; and put at new start

01      CMP     r5, r4
        LDRHIB  r2, [r5, #-1]!
        STRHIB  r2, [r3, #-1]!
        BHI     %b01

02      STR     r3, [r1, #PipeFile_readPTR]     ; r3 = new read pointer

        MOV     r14, #1
        STR     r14, [r1, #PipeFile_writeblocked]    ; must be some space now

99      STRVS   R0, [sp, #Proc_RegOffset]
        EXIT

; *****************************************************************************
;
;       PipeFS_Args
;
; in:   R0 = reason code
;       R1 = internal file handle
;

PipeFS_Args ROUT

        CMP     r0, #fsargs_EOFCheck    ; EOF always
        BEQ     args_eofcheck

        Push    lr
        SavePSR lr
        BIC     lr, lr, #(V_bit+Z_bit)

        CMP     r0, #fsargs_Flush       ; nop
        ORREQ   lr, lr, #Z_bit          ; EQ
        BEQ     exit_args_quick
        Pull    lr

        CMP     r0, #fsargs_ReadLoadExec
        BEQ     args_readloadexec

        CMP     r0, #fsargs_ReadSize
        BEQ     args_readsize

        CMP     r0, #fsargs_SetEXT
        BEQ     args_setext

        CMP     r0, #fsargs_EnsureSize
        BEQ     args_ensuresize

        CMP     r0, #fsargs_ReadEXT
        BEQ     args_readext

        CMP     r0, #fsargs_ReadPTR     ; Return PTR# = 0
        BEQ     args_readptr

   ;    CMPNE   r0, #fsargs_SetPTR      ; nop

        MOV     pc, lr                  ; EQ/NE from above
exit_args_quick ROUT
        RestPSR lr,,f
        Pull    pc

args_readloadexec
        Push    "r1,lr"
        BIC     r1, r1, #pipehandle_bits
        ASSERT  PipeFile_Load = 0
        ASSERT  PipeFile_Exec = 4
        LDMIA   r1, {r2,r3}
        Pull    "r1,pc"

args_readsize                           ; actually reads space allocated to file
        Push    "r1,r3,lr"
        BIC     r1, r1, #pipehandle_bits
        LDR     r2, [r1, #PipeFile_wrapstart]
        LDR     r3, [r1, #PipeFile_wrapend]
        SUB     r2, r3, r2
        Pull    "r1,r3,pc"

; extent of file if you're writing it is the total number of bytes written
; extent of file if you're reading it is the number of bytes left in the buffer

args_readext                            ; read size of file
        Push    "r1,lr"
        TST     r1, #pipehandle_write
        BIC     r1, r1, #pipehandle_bits
        LDRNE   r2, [r1, #PipeFile_Ext] ; number of bytes written to file
        Pull    "r1,pc",NE

11      BL      blockifwriting          ; wait till stopped writing
        LDRVC   r2, [r1, #PipeFile_Size]
        SUBVSS  r2, r2, r2              ; don't return error, just extent = 0
        MOVEQ   r0, #fsargs_ReadEXT     ; preserve this
        Pull    "r1,pc", EQ             ; no blocking required - just return length

        BL      checkexists             ; in case someone's pulled the plug!
        Pull    "r1,pc", VS

        LDR     r14, [r1, #PipeFile_writeblocked]  ; if blocked on write, unblock it
        CMP     r14, #0
        LDREQ   r14, [r1, #PipeFile_usage]
        ORREQ   r14, r14, #nowriteblock         ; we want to know how big the file is
        STREQ   r14, [r1, #PipeFile_usage]      ; - so we must let it all be read in
        B       %b11

args_readptr                            ; read size of file
        Push    "r1,lr"
        TST     r1, #pipehandle_write
        BIC     r1, r1, #pipehandle_bits
        LDR     r2, [r1, #PipeFile_Ext] ; ptr if writing = number of bytes written to file
        LDREQ   r14, [r1, #PipeFile_Size]
        SUBEQ   r2, r2, r14             ; ptr if reading = total - current
        Pull    "r1,pc"

args_setext
        Push    "r0,r2,lr"              ; r2 = extent required
        BIC     r14, r1, #pipehandle_bits
        LDR     r14, [r14, #PipeFile_Ext] ; read bytes written so far
        SUBS    r2, r2, r14
        BLE     %f02
01
        MOV     r0, #0
        BL      PipeFS_PutByte
        BVS     %f02
        SUBS    r2, r2, #1              ; no need to recache R2
        BGT     %BT01                   ; (don't care if file is shrinking under our feet!)
02
        STRVS   R0, [sp, #Proc_RegOffset]
        Pull    "r0,r2,pc"

args_ensuresize
        Push    "r1,lr"
        BIC     r1, r1, #pipehandle_bits
        BL      try_ensuresize          ; also called for OSFile_Create
        Pull    "r1,pc"

args_eofcheck
        Entry   "r2-r4"

        BIC     r4, r1, #pipehandle_bits

        LDR     r2, [r4, #PipeFile_readPTR]
        LDR     r3, [r4, #PipeFile_writePTR]
        CMP     r2, r3                  ; EQ => EOF, unless not yet closed for writing
        LDREQ   r14, [r4, #PipeFile_usage]
        TSTEQ   r14, #write_attribute :OR: notwritten
        TSTNE   r1, #pipehandle_read    ; always EOF if writing

        MOVEQ   r2, #-1                 ; return R2 = -1 for EOF
        MOVNE   r2, #0                  ; return R2 = 0 for not EOF
        STR     r2, [sp]
        MOVS    r14, r2, LSR #1         ; set C depending on Z flag

        EXIT

; *****************************************************************************
;
;       FindFile - Find a file of a particular name
;
; in:   R1 -> wildcarded filename to find
;
; out:  R0 = object type (0 => not found, 1 => file, 2 => directory)
;       R1 -> file header
;       R2 = load address
;       R3 = exec address
;       R4 = size
;       R5 = attributes
;       R6 -> actual filename
;

FindFile Entry

        BL      FindFileOrDirectory
        TEQ     R0, #object_directory
        MOVEQ   R0, #object_nothing             ; can't accept directories
        TEQ     R0, #object_nothing
        MOVEQ   R1, #0                          ; no file header if object_nothing
        EXIT

FindFileOrDirectory Entry

        BL      skipdollar                      ; remove "$." from wildcard

        MOV     R0, R1                          ; R0 -> file name

        LDR     R3, PipeFSFileData

05      CMP     R3, #0
        MOVEQ   R2, #0                          ; load = 0
        MOVEQ   R4, #0                          ; length = 0
        MOVEQ   R0, #object_nothing             ; indicate not found
        EXIT    EQ

        LDR     R1, [R3, #link_data]

        ADD     R4, R1, #PipeFile_Name           ; R4 -> name
        BL      WildMatch
        LDRNE   R3, [R3, #link_next]            ; no match: try next
        BNE     %BT05

        ADD     R6, R1, #PipeFile_Name           ; R6 -> filename

        LDRB    R14, [R4,#-1]                   ; if there's more
        TEQ     R14, #0
        ASSERT  PipeFile_Load = 0
        ASSERT  PipeFile_Attr = 12
        LDMIA   R1, {R2-R5}                     ; get R2-R5
        MOVEQ   R0, #object_file                ; indicate file found
        EXIT    EQ

        MOV     R0, #object_directory           ; this must be a directory
        AND     R2, R2, #&FF
        LDR     R14, =FileType_Data :SHL: 20    ; set type to 'data' keeping high byte of timestamp
        ASSERT  (FileType_Data :AND: &800) <> 0 ; so the sign bit is copied down by ASR
        ORR     R2, R2, R14, ASR #12
        MOV     R4, #0                          ; length = 0
        MOV     R5, #0                          ; attributes = 0

        EXIT
        LTORG

; *****************************************************************************
;
;       FindDirEntry - Find a file/dir in the specified directory
;
; Searches all entries known, returning textually-sorted names.
; Always returns the minimum name found that is later than the last one
;
; in:   R1 -> wildcarded directory name to find (skipdollar called already)
;       [lastleafname] -> previous leafname returned (0 => none)
;
; out:  EQ => object found, else not
;       R2 -> start of file info block for this file
;       R4 -> leafname (terminated by "." or 0)
;             returns next leafname after [lastleafname]
;       [lastleafname] -> leafname (for next time)
;

stk_R2  *       2 * 4           ; stack positions for return
stk_R4  *       3 * 4

FindDirEntry Entry "R0,R1,R2,R4,R9-R11"

        MOV     R0, R1                          ; R0 -> file name

        MOV     R14, #0                         ; latest candidate for return
        STR     R14, [sp, #stk_R4]

        LDR     R9, PipeFSFileData              ; R9 -> next link block

20      TEQ     R9, #0
        BEQ     returndirentry                  ; all done - what did we find?

        LDR     R2, [R9, #link_data]

        ADD     R4, R2, #PipeFile_Name          ; R4 -> name
        LDRB    R14, [R0]                       ; special case - always match
        CMP     R14, #" "                       ; null directory
        BLS     %FT02

        BL      WildMatch                       ; R4 -> leafname
        BNE     %FT10                           ; no match: loop

; error if no leafname - the "pathname" was really a file

        LDRB    R14, [R4, #-1]
        TEQ     R14, #"."
        ADRNE   r0, ErrorBlock_IsAFile
        ADDNE   r1, r2, #PipeFile_Name
        BLNE    CopyError
        STRVS   R0, [sp, #Proc_RegOffset]
        EXIT    VS

; check leafname > lastleafname

02      MOV     R10, R4
        LDR     R11, lastleafname
        BL      compare_R10_R11

; check leafname < previous candidate (on stack)

        LDRGT   R10, [sp, #stk_R4]
        MOVGT   R11, R4
        BLGT    compare_R10_R11         ; returns GT if R10 or R11=0

        STRGT   R2, [sp, #stk_R2]       ; R7,R8 = new candidate
        STRGT   R4, [sp, #stk_R4]

10      LDR     R9, [R9, #link_next]    ; go on to next file
        B       %BT20

; now return the values stored in we have a new leafname - return it!

returndirentry
        LDR     R14, [sp, #stk_R4]
        STR     R14, lastleafname       ; for next time
        CMP     R14, #0
      [ debugxx
        BEQ     %FT00
        DebugS  fs,"Return dir entry:",R14
00
      ]
        TOGPSR  Z_bit, R14

        EXIT                            ; EQ => found

        MakeInternatErrorBlock IsAFile,,IsAFil

; *****************************************************************************
;
; In    R10 -> filename1
;       R11 -> filename2
; Out   GT if R10 > R11, or (R10 or R11 is null)
;       LE if R10 <= R11
; NB:   Comparisons are case-insensitive (both strings forced to be upper case)
;

compare_R10_R11 Entry "R1,R2"

        RSBS    R14, R10, #1
        RSBLES  R14, R11, #1
        EXIT    GT                      ; GT <= either filename is null

        DebugS  fs,"compare_R10:",R10
        DebugS  fs,"compare_R11:",R11

10      LDRB    R1, [R10], #1
        LDRB    R2, [R11], #1
        UpperCase R1, R14
        UpperCase R2, R14
        CMP     R1, #"."
        CMPNE   R1, #0
        BEQ     %FT20                   ; filename1 terminated
        CMP     R1, R2
        BEQ     %BT10
        EXIT

20      CMP     R2, #"."
        CMPNE   R2, #0                  ; EQ => same
        CMPNE   R2, #&100000            ; LT <= filename1 shorter
        EXIT

; *****************************************************************************
;
; in:   R1 -> wildcarded pathname
; out:  R1 -> pathname, with "$.", "@.", "%." or "\." removed
;

skipdollar Entry

        LDRB    R14, [R1]
        CMP     R14, #"$"
        CMPNE   R14, #"@"
        CMPNE   R14, #"%"
        CMPNE   R14, #"\\"
        EXIT    NE

        LDRB    R14, [R1, #1]
        CMP     R14, #" "
        ADDLS   R1, R1, #1              ; skip "$"
        CMP     R14, #"."
        ADDEQ   R1, R1, #2              ; skip "$."

        EXIT

; *****************************************************************************
;
; in:   R7 -> file header
; out:  R6 -> leafname for monitor
;       V preserved
;

getleafname Entry "r7"

        ADD     R7, R7, #PipeFile_Name
        MOV     R6, R7                  ; In case there are no dots
10
        LDRB    R14, [R7], #1
        TEQ     R14, #'.'
        MOVEQ   R6, R7                  ; Leaf starting after most recent dot
        TEQ     R14, #0
        BNE     %BT10

        EXIT

; *****************************************************************************
;
; In  : R0 is wildcard spec ptr, R4 is name ptr.
;       Wild Terminators are any ch <=" ",name terminator 0
;       Wildcards are *,#
; Out : EQ/NE for match (EQ if matches)
;       R4 points after name terminator for found
;       R10,R11 corrupted
;
; NB:   also matches names whose leading pathnames match the wildcard spec.
;

WildMatch Entry "R0-R3"

        MOV    R11,#0        ; this is the wild backtrack pointer
        MOV    R3,#0         ; and this is the name backtrack ptr.

01      LDRB   R1,[R0],#1    ; nextwild
        CMP    R1,#"*"
        BEQ    %FT02         ; IF nextwild = "*"
        LDRB   R2,[R4],#1    ; nextname
        CMP    R2,#0
        BEQ    %FT03         ; branch if nextname = 0
        CMP    R2,#"."       ; if ".", can match wildcard terminator
        BEQ    %FT31
        UpperCase R1,R10
        UpperCase R2,R10
        CMP    R1,R2         ; IF nextwild=nextname
        CMPNE  R1,#"#"       ;   OR nextwild = #  (terminator checked already)
        BEQ    %BT01         ; THEN LOOP (stepped already)

        MOV    R0,R11        ; try backtrack
        MOVS   R4,R3         ; if * had at all
        BNE    %FT02
        CMP    PC,#0         ; set NE
04
        EXIT                 ; return NE (failed)

31      CMP    R1,#"."       ; name "." : wildcard can be "." or terminator
        CMPNE  R1,#" "
        BHI    %BA04         ; no match
        CMP    R1,#"."
        BEQ    %BT01         ; carry on if more leafnames in wildcard

03      CMP    R1,#" "       ; name terminated : has wildcard?
        BHI    %BA04         ; note HI has NE set.
        CMP    R1,R1         ; set EQ
        EXIT                 ; return EQ (found)

02      MOV    R11,R0        ; wild backtrack ptr is char after *
        LDRB   R1,[R0],#1    ; step wild
        CMP    R1,#"*"
        BEQ    %BT02         ; fujj **
        UpperCase R1,R10

05      LDRB   R2,[R4],#1    ; step name
        CMP    R2,#0         ; terminator?
        BEQ    %BT03
        CMP    R2,#"."       ; if ".", can match wildcard terminator
        BEQ    %BT31
        UpperCase R2,R10
        CMP    R1,R2
        CMPNE  R1,#"#"       ; match if #
        BNE    %BT05
        MOV    R3,R4         ; name backtrack ptr is char after match
        B      %BT01         ; LOOP

 [ dynamicareas

; *****************************************************************************
;
; Tries to minimise the heap size, hides any errors (i.e. R0 and V preserved).
; PipeFS_DASize updated if required.
;
; R12 should hold the address of the workspace (i.e. value of the private
; word, not a pointer to it).
;
; ** Only included if dynamicareas = true.
;

shrinkheap EntryS "R0-R4"

        Debug  da, "shrinkheap: Called"

        LDR    R0, PipeFS_DABase
        LDR    R0, [R0, #8]  ; PRM 1-349; R0 = offset to first free word of unused area in heap

        LDR    R1, PipeFS_DASize
        Debug  da, "shrinkheap: DA size pre",R1

        SUB    R0, R1, R0    ; R0 = amount of free space in heap
                             ; We want to shrink it to the nearest page boundary

        Debug  da, "shrinkheap: Free amount pre",R0

        LDR    R1, PipeFS_PageSize
        SUB    R1, R1, #1    ; So R1 = e.g. 4095
        MVN    R2, #0        ; R2 = -1
        EOR    R1, R1, R2    ; So R1 = 4095 EOR -1, AKA R1 = NOT 4095 (ahem)
        AND    R0, R0, R1    ; R0 = (free in heap) AND NOT (page_size)

        CMP    R0, #0
        Debug  da, "shrinkheap: Shrink by",R0
        BEQ    %FT01         ; If zero, the heap is already as small as it can get (page boundarywise)

        MVN    R4, R0
        ADD    R4, R4, #1    ; R4 = -R0 (amount to alter by must be negative, we're shrinking it)

        MOV    R0, #HeapReason_ExtendHeap
        LDR    R1, PipeFS_DABase
        MOV    R3, R4
        SWI    XOS_Heap      ; First shrink the heap, then the dynamic area

        LDR    R0, PipeFS_DAHandle
        MOV    R1, R4
        SWI    XOS_ChangeDynamicArea

        LDR    R0, PipeFS_DASize
        SUB    R0, R0, R1    ; R1 = the actual size of change
        STR    R0, PipeFS_DASize

        Debug  da, "shrinkheap: DA size post",R0
01
        Debug  da, "shrinkheap: Exit"
        EXITS

; *****************************************************************************
;
; In  : R3 = amount of free space you want in the heap. The heap is extended
;       or possibly shrunk (if there's more free space in there than you
;       asked for) by the relevant amount.
;
; Out : V set on error, R0 points to error block
;       PipeFS_DASize updated otherwise
;
; R12 should hold the address of the workspace (i.e. value of the private
; word, not a pointer to it).
;
; ** Only included if dynamicareas = true.
;

extendheap Entry "R0-R5"

        Debug  da, "extendheap: R3 =",R3

        LDR    R2, PipeFS_DASize
        Debug  da, "extendheap: DA size pre",R2

        LDR    R1, PipeFS_DABase
        LDR    R4, [R1, #8]   ; PRM 1-349; R4 = offset to first free word of unused area in heap
        SUB    R2, R2, R4     ; R2 = total heap size - offset to unused area; -> R2 = free space in heap

        SUB    R1, R3, R2     ; R1 = required_total - current_free
        ADD    R1, R1, #4     ; R1 now holds required change plus 4 for caution
        MOV    R4, R1         ; keep a copy in R4 for after the SWI

        Debug  da, "extendheap: Change DA by",R1

        LDR    R0, PipeFS_DAHandle
        SWI    XOS_ChangeDynamicArea
        BVS    %FT01

        CMP    R2, #0         ; On exit, the SWI sets R1 to the amount changed by - unsigned
        MVNLT  R1, R1         ; so, make this a negative number if the size change we did
        ADDLT  R3, R1, #1     ; was negative initially (hence record of R2 earlier).
        MOVGE  R3, R1         ; Either way, end up with the change in R3 for OS_Heap 5.

        MOV    R4, R3         ; Keep a record of the change value in R4

        LDR    R0, PipeFS_DASize
        ADD    R0, R0, R4     ; Work out the new area size and store it
        STR    R0, PipeFS_DASize

        Debug  da, "extendheap: DA size post",R0

        MOV    R0, #HeapReason_ExtendHeap
        LDR    R1, PipeFS_DABase
        SWI    XOS_Heap
        BLVS   shrinkheap     ; If that fails, ensure the heap is shrunk back.

01      STRVS  R0, [sp, #Proc_RegOffset]       ; Store the error pointer, if required
        Debug  da, "extendheap: Exit"
        EXIT

; *****************************************************************************
;
; In  : R3 = size of heap chunk to claim
;
; Out : V set on error, R0 points to error block
;       Else
;       PipeFS_DASize will be updated if overall heap size increased
;       2 now points to base of new block
;
; R12 should hold the address of the workspace (i.e. value of the private
; word, not a pointer to it).
;
; ** Only included if dynamicareas = true.
;

claimheapchunk Entry "R0,R1,R3-R5"

        Debug  da, "claimheapchunk: R3 =",R3

        MOV    R0, #HeapReason_Get ; Claim block
        LDR    R1, PipeFS_DABase
        SWI    XOS_Heap      ; Gives pointer in R2, just where we want it

        BVC    %FT02         ; If there's no error, there's no problem
        LDR    R1, [R0]      ; Else load the error number into R1
        TEQ    R1, #ErrorNumber_HeapFail_Alloc  ; Error "Not enough memory (in heap)" (TEQ doesn't clear V)
        STRNE  R0, [sp, #Proc_RegOffset]        ; If not, bail out
        EXIT   NE

        BL     extendheap    ; Try extending the heap by the amount requested (which is still in R3)
        BVS    %FT01         ; Can't do it? Bail out. Otherwise try an OS_Heap claim call again.

        MOV    R0, #HeapReason_Get
        LDR    R1, PipeFS_DABase
        SWI    XOS_Heap

        BL     shrinkheap    ; This may be able to recover some space if we over-allocated

01      STRVS  R0, [sp, #Proc_RegOffset]
02
        Debug  da, "claimheapchunk: Exit with",R2
        EXIT

; *****************************************************************************
;
; In  : R2 = pointer to heap block to release
;
; Out : V set on error, R0 points to error block
;
; R12 should hold the address of the workspace (i.e. value of the private
; word, not a pointer to it).
;
; ** Only included if dynamicareas = true.
;

releaseheapchunk Entry "R0,R1"

        Debug  da, "releaseheapchunk: R2 =",R2

        MOV    R0, #HeapReason_Free
        LDR    R1, PipeFS_DABase
        SWI    XOS_Heap

        BLVC   shrinkheap

        STRVS  R0, [sp, #Proc_RegOffset]
        Debug  da, "releaseheapchunk: Exit"
        EXIT

; *****************************************************************************
;
; In  : R2 = pointer to heap block to resize
;       R3 = amount to resize by (signed value)
;
; Out : V set on error, R0 points to error block
;       Else
;       PipeFS_DASize will be updated if overall heap size increased
;       R2 will be updated if the block has moved
;
; R12 should hold the address of the workspace (i.e. value of the private
; word, not a pointer to it).
;
; ** Only included if dynamicareas = true.
;

extendheapchunk Entry "R0,R1,R3-R5"

        Debug  da, "extendheapchunk: R2/R3 =",R2,R3

        CMP    R2, #0        ; Sanity checks
        CMPNE  R3, #0
        BEQ    %FT02

        MOV    R0, #HeapReason_ExtendBlock
        LDR    R1, PipeFS_DABase
        SWI    XOS_Heap

        BLVC   shrinkheap    ; If it worked, make sure the heap is a minimum size...
        BVC    %FT02         ; ...then exit

        LDR    R4, [R0]      ; Else load the error number into R4

        LDR    R5, =ErrorNumber_HeapFail_Alloc     ; Error "Not enough memory (in heap)" (TEQ doesn't clear V)
        TEQ    R4, R5
        LDRNE  R5, =ErrorNumber_ChDynamNotAllMoved ; Error "Unable to move memory"
        TEQNE  R4, R5

        BEQ    %FT03         ; If one or the other matched, proceed.
        STR    R0, [sp, #Proc_RegOffset]      ; Otherwise, bail out.
        EXIT

03      MOV    R4, R3        ; Remember the amount we want to change by
        Debug  da, "extendheapchunk: Want to change by",R3
        MOV    R0, #HeapReason_ReadBlockSize
        SWI    XOS_Heap      ; R1 (heap base) and R2 (block ptr) should still be intact after the above stuff
        BVS    %FT01         ; If no error, the current block size is now in R3

        Debug  da, "extendheapchunk: Block size is",R3
        ADD    R3, R4, R3    ; Put current block size + amount to change the block by into R3
        BL     extendheap    ; Extend the heap
        MOV    R0, #HeapReason_ExtendBlock
        MOV    R3, R4        ; Restore our on-entry value of R3, i.e. R3 now = required change of size
        SWI    XOS_Heap      ; R1 (heap base) and R2 (block ptr) should still be intact after the above stuff

        BL     shrinkheap

01      STRVS  R0, [sp, #Proc_RegOffset]
02
        Debug  da, "extendheapchunk: Exit"
        EXIT

 ] ; from "[ dynamicareas"

; *****************************************************************************

CopyError Entry r1-r7
        BL      open_messagefile
        EXIT    VS
        ADR     R1, MessageFile_Block
        MOV     R2, #0
        LDR     R4, [sp]        ; R1 (parameter) -> R4
        MOV     R5, #0
        MOV     R6, #0
        MOV     R7, #0
        SWI     XMessageTrans_ErrorLookup
        EXIT

message_filename
        DCB     "Resources:$.Resources.PipeFS.Messages", 0
        ALIGN

open_messagefile Entry r0-r3
        LDR     r0, MessageFile_Open
        CMP     r0, #0
        EXIT    NE
        ADR     R0, MessageFile_Block
        ADR     R1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        STRVS   R0, [sp, #Proc_RegOffset]
        EXIT    VS
        MOV     r0, #1
        STR     r0, MessageFile_Open
        EXIT

; *****************************************************************************

      [ debug
        InsertNDRDebugRoutines
      ]

        END
