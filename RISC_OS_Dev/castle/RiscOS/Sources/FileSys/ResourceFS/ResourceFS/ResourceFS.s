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
; > Sources.ResourceFS

; *********************************
; ***    C h a n g e   L i s t  ***
; *********************************

; Date       Description
; ----       -----------
;  9-Feb-90             File created from old Desktop 2.23
; 22-Feb-90     0.01    Name changed from DeskFS to ResourceFS
; 28-Feb-90     0.02    Issue Service_ResourceFSStarted on DeregisterFiles
;  2-Mar-90     0.03    Issue UpCall_ModifyingFile when (de)registering
; 07-Nov-90     0.04    Fake "$" as existing
; 11-Mar-91     0.05    OSS  Internationalisation - just errors in this module
; 27-Mar-91     0.06    OSS  Changed to use some of the generic error tokens.
; 17-Apr-91     0.07    OSS  Fixed R1 corruption while translating errors.
; 24-Apr-91     0.08    OSS  Fixed potentional STR to ROM bug on errors.
; 10-Sep-91     0.09    BC   Changed version to not clash with 2.00 version
;                            converted for IHVs from the 0.08 version
; 14-Oct-91     0.11    JSR  Make use Territory_UpperCaseTable for uppercasing
;                            UpperCase in Compare_R10_R11
; ?????????     0.12         Faff with the messages file
; 10-Feb-92     0.13    JSR  Respond to readdiscname and *DIR to keep FileSwitch happy
;                            Remove redundent cataloging code
;                               (CD2-015, CD2-053, ROM space reduction)
;                            Generate a file index (speed enhancement)
; 12-Mar-92     0.14    JSR  Misc bugs from failure to initialise workspace. G-RO-5512.
; 16-Aug-95     0.15    RWB  Allow booting from ResourceFS, provides *Run !Boot as default and only option
; 08-Sep-98     0.17    KJB  Cope with registrations above &80000000.
; 09-Sep-98     0.18    KJB  Optimise word-aligned case of data reads.
; 19-Oct-98     0.19    KJB  Don't need to GET Hdr:CMOS.
; 04-Aug-99     0.20    KJB  Ursula branch merged (service call table)
; 25-Apr-00     0.21    KJB  Made 32-bit compatible.
; 04-Jul-00     0.22    JRF  Fixed !Test+ followed by !Test added bug.
;

        AREA |ResourceFS$$Code|, CODE, READONLY, PIC

Module_BaseAddr

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:Proc
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:LowFSI
        GET     Hdr:NewErrors
        GET     Hdr:Variables
        GET     Hdr:Wimp
        GET     Hdr:ResourceFS
        GET     Hdr:UpCall
        GET     Hdr:MsgTrans
        GET     Hdr:Territory

        GET     VersionASM

        GET     Hdr:NDRDebug

        GBLL    debug
        GBLL    debugrg
        GBLL    debugfs
        GBLL    debugxx
        GBLL    debuginit
        GBLL    debugdie
        GBLL    debugquickindex
        GBLL    hostvdu
	GBLL	allowbooting			; Added by Rich, 16-Aug-95, allows a !Boot to be registered and booted

debug           SETL false
debugrg         SETL true :LAND: debug
debugfs         SETL true :LAND: debug
debugxx         SETL false :LAND: debug
debuginit       SETL true :LAND: debug
debugdie        SETL true :LAND: debug
debugquickindex SETL true :LAND: debug
allowbooting	SETL true

hostvdu SETL    false


TAB     *       9
LF      *       10
FF      *       12
CR      *       13

; File format
        ^       0
ROMFile_Offset  # 4                     ; offset from here to next file
                                        ; 0 => terminator node (not a file)
ROMFile_Load    # 4                     ; load address
ROMFile_Exec    # 4                     ; exec address
ROMFile_Size    # 4                     ; size of file
ROMFile_Attr    # 4                     ; file attributes
ROMFile_Name    # 0                     ; null terminated file name
                                        ; file data follows (word-aligned)

                ^       0, wp

lastleafname        #   4               ; for directory enumeration
QuickIndexBlock     #   4               ; for rapid file finding
MiscFlags           #   4               ; Miscellaneous flags
StartedCallbackIssued * 1:SHL:0
ROMFSFileData       #   4               ; points to list of link_ items
message_file_block  #   16              ; File handle for MessageTrans
message_file_open   #   4               ; Opened message file flag
UpperCaseTable      #   4               ; Upper casing table
ROMFS_WorkspaceSize * :INDEX: @

                ^       0
link_data       #       4               ; points to list of files
link_next       #       4
link_size       #       0

        GBLS    UpperCaseReg
        MACRO
        Internat_UpperCaseLoad  $UR
UpperCaseReg    SETS    "$UR"
        LDR     $UR, UpperCaseTable
        MEND

        MACRO
        Internat_UpperCase      $Reg, $UR
        ASSERT  $UR = $UpperCaseReg
        TEQ     $UR, #0
        LDRNEB  $Reg, [$UR, $Reg]
        MEND

; **************** Module code starts here **********************

        ASSERT  (.-Module_BaseAddr) = 0

MySWIBase       *       Module_SWISystemBase + ResourceFSSWI * Module_SWIChunkSize

        DCD     0 ; ROMFS_Start    - Module_BaseAddr
        DCD     ROMFS_Init     - Module_BaseAddr
        DCD     ROMFS_Die      - Module_BaseAddr
        DCD     ROMFS_Service  - Module_BaseAddr
        DCD     ROMFS_Title    - Module_BaseAddr
        DCD     ROMFS_HelpStr  - Module_BaseAddr
        DCD     ROMFS_HC_Table - Module_BaseAddr
        DCD     MySWIBase
        DCD     ROMFS_SWIdecode- Module_BaseAddr
        DCD     ROMFS_SWInames - Module_BaseAddr
        DCD     0
 [ International_Help <> 0
        DCD     message_filename - Module_BaseAddr
 |
        DCD     0
 ]
        DCD     ROMFS_Flags    - Module_BaseAddr

ROMFS_HelpStr
        =       "ResourceFS", TAB, "$Module_MajorVersion ($Module_Date)"
 [ Module_MinorVersion <> ""
        =       " $Module_MinorVersion"
 ]
        = 0
        ALIGN

ROMFS_Flags
 [ No32bitCode
        DCD     0
 |
        DCD     ModuleFlag_32bit
 ]

ROMFS_HC_Table
        Command ResourceFS, 0, 0, International_Help
        &       0

; *****************************************************************************
;
; In    R11 = SWI offset within chunk
;       R12 -> private word

ROMFS_SWIdecode ROUT

        LDR     R12, [R12]                      ; R12 -> workspace
        CMP     R11,#maxswi
        ADDCC   PC,PC,R11,LSL #2                ; go!
        B       err_badswi
jptable
        B       SWIROMFS_RegisterFiles
        B       SWIROMFS_DeregisterFiles
maxswi  *       (.-jptable) / 4

err_badswi
        ADR     R0, ErrorBlock_ModuleBadSWI
        Push    "r1, lr"
        ADR     r1, ROMFS_Title
        BL      copy_error_one          ; Always sets the V bit
        Pull    "r1, pc"

        MakeErrorBlock ModuleBadSWI

ROMFS_Title                             ; Title and SWI prefix shared
ROMFS_SWInames
        DCB     "ResourceFS", 0
        DCB     "RegisterFiles", 0
        DCB     "DeregisterFiles", 0
        DCB     0
        ALIGN

; *****************************************************************************
;
; Issue_Service_ResourceFSStarted
;
; In    -
; Out   - callback set to issue the above service call
;
Issue_Service_ResourceFSStarted Entry "r0,r1"
        LDR     lr, MiscFlags
        TST     lr, #StartedCallbackIssued
        EXIT    NE
        ADR     r0, StartedCallback
        MOV     r1, r12
        SWI     XOS_AddCallBack
        LDRVC   r0, MiscFlags
        ORRVC   r0, r0, #StartedCallbackIssued
        STRVC   r0, MiscFlags
        STRVS   r0, [sp]
        EXIT

StartedCallback Entry "r0-r9"
        LDR     r0, MiscFlags
        BIC     r0, r0, #StartedCallbackIssued
        STR     r0, MiscFlags
        Debug   init, "StartedCallBack:issue"
        MOV     r1, #Service_ResourceFSStarted
        SWI     XOS_ServiceCall
        Debug   init, "StartedCallBack:complete"
        EXIT

; *****************************************************************************

; In    R0 -> set of files to register

SWIROMFS_RegisterFiles Entry "R1"
        BL      registerfiles
        BLVC    Issue_Service_ResourceFSStarted
        EXIT

; .............................................................................

; In    R0 -> set of files to be registered
;       R3 -> workspace (called from Service_ResourceFSStarting)

SVCROMFS_RegisterFiles Entry "R12"
        MOV     R12, R3                         ; R3 = workspace pointer
        BL      registerfiles

        EXIT

; .............................................................................

; In    R0 -> set of files to be registered
;       R12 -> workspace

registerfiles Entry "R1-R3"

        Debug   rg,"ResourceFS_RegisterFiles:",R0

        BL      findlink_r0                     ; R2 -> matched block (if any)
        TEQ     R2, #0
        ADRNE   R0, ErrorBlock_RFSReg
        ADRNE   r1, ROMFS_Title
        BLNE    copy_error_one                  ; Always sets the V bit

        MOVVC   R1, R0                          ; R1 -> new block
        MOVVC   R0, #ModHandReason_Claim
        MOVVC   R3, #link_size
        SWIVC   XOS_Module

        STRVC   R1, [R2, #link_data]
        LDRVC   R14, ROMFSFileData
        STRVC   R14, [R2, #link_next]
        STRVC   R2, ROMFSFileData

        BLVC    JunkQuickIndexBlock

      [ Module_Version >= 3
        MOVVC   R0, #upfsfile_Create
        BLVC    modifyingfiles                  ; R2 -> link block
      ]

        EXIT

        MakeInternatErrorBlock RFSReg           ; "ResourceFS files already registered"

; *****************************************************************************

; In    R0 -> set of files to deregister

SWIROMFS_DeregisterFiles Entry "R1-R2"

        Debug   rg,"ResourceFS_DeregisterFiles:",R0

        BL      findlink_r0                     ; R2 -> matched block (if any)
        TEQ     R2, #0                          ; R1 -> block before
        ADREQ   R0, ErrorBlock_RFSDreg
        ADREQ   r1, ROMFS_Title
        BLEQ    copy_error_one                  ; Always sets the V bit

        BLVC    JunkQuickIndexBlock

        MOVVC   R0, #upfsfile_Delete            ; files are disappearing
        BLVC    modifyingfiles                  ; does all files in [R2,#link_data]

        LDRVC   R14, [R2, #link_next]           ; de-link block
        STRVC   R14, [R1, #link_next]
        MOVVC   R0, #ModHandReason_Free         ; and free it
        SWIVC   XOS_Module

 [ {TRUE}
        BLVC    Issue_Service_ResourceFSStarted
 |
        MOVVC   R1, #Service_ResourceFSStarted      ; in case anyone
        SWIVC   XOS_ServiceCall                     ; was using these files
 ]

        EXIT

        MakeInternatErrorBlock RFSDreg              ; "ResourceFS files not registered"

; .............................................................................

; In    R0 -> ResourceFS files to be found
; Out   Match: [R1, #link_next] = R2
;              [R2, #link_data] = R0
;       No match: R2 = 0

findlink_r0 Entry

        ADR     R1, ROMFSFileData - link_next

01      LDR     R2, [R1, #link_next]
        TEQ     R2, #0
        MOVEQ   R1, #0                          ; no match
        EXIT    EQ

        LDR     R14, [R2, #link_data]
        TEQ     R14, R0
        MOVNE   R1, R2
        BNE     %BT01

        EXIT                                    ; R1 -> block before matched one

; *****************************************************************************

 [ International_Help=0
ResourceFS_Help
        =       "*ResourceFS selects the ResourceFS filing system.",13
ResourceFS_Syntax
        =       "Syntax: *ResourceFS",0
 |
ResourceFS_Help         DCB     "HRFSRFS", 0
ResourceFS_Syntax       DCB     "SRFSRFS", 0
 ]

StringROM
        =       "Resources",0                   ; FS name is "Resources:"
StringROMFS
        =       "Acorn ResourceFS",0
        ALIGN

FSInfoBlock     DCD     StringROM-Module_BaseAddr
                DCD     StringROMFS-Module_BaseAddr
                DCD     ROMFS_Open-Module_BaseAddr      ; open files
                DCD     ROMFS_MediaToBuffer-Module_BaseAddr ; media -> buffer
                DCD     0                               ; buffer -> media (NYI!)
                DCD     0                               ; OSARGS
                DCD     ROMFS_Close-Module_BaseAddr     ; close files
                DCD     ROMFS_OSFile-Module_BaseAddr    ; osfile etc
fsinfoword      DCD     fsnumber_resourcefs :OR: fsinfo_readonly
                DCD     ROMFS_FSFunc-Module_BaseAddr    ; fs func
                DCD     0                               ; OSGBPB

; *****************************************************************************
;
;       ROMFS_Init - Initialisation entry
;

ROMFS_Init Entry

        LDR     R2, [R12]               ; have we got workspace yet ?
        TEQ     R2, #0
        BNE     %FT05

        MOV     R0, #ModHandReason_Claim
        MOV     R3, #ROMFS_WorkspaceSize
        SWI     XOS_Module
        EXIT    VS
        ChkKernelVersion
        STR     R2, [R12]               ; save address in my workspace pointer,
                                        ; so Tutu can free it for me when I die
05      MOV     R12, R2

        MOV     R14, #0                 ; no files yet
        STR     R14, lastleafname
        STR     R14, ROMFSFileData
        STR     R14, message_file_open  ; Our Messages file is closed
        STR     R14, MiscFlags
        STR     R14, QuickIndexBlock

; Zero block out, since we may just try to do a Lookup with a block that
; is not open yet (see MsgCode file for more details).

        STR     R14, message_file_block
        STR     R14, message_file_block+4
        STR     R14, message_file_block+8
        STR     R14, message_file_block+12

        Debug   init, "Init:Read upper case table"
        BL      ReadUpperCaseTable

        Debug   init, "Init:Declare"
        BL      ROMFS_Declare           ; call FileSwitch

        Debug   init, "Init:ResourceFSStarting"
        MOVVC   R1, #Service_ResourceFSStarting
        ADRVC   R2, SVCROMFS_RegisterFiles      ; Service call entry address
        MOVVC   R3, R12
        SWIVC   XOS_ServiceCall         ; get files re-created

        Debug   init, "Init:ResourceFSStarted"
 [ :LNOT: debug
        BLVC    Issue_Service_ResourceFSStarted
 ]

        Debug   init, "Init:Complete"

        EXIT

;..............................................................................

; Declare ResourceFS: to FileSwitch (called on Init and Service_FSRedeclare)

ROMFS_Declare Entry "R1-R3"

        MOV     R0, #FSControl_AddFS    ; add this filing system
        addr    R1, Module_BaseAddr
        MOV     R2, #FSInfoBlock-Module_BaseAddr
        MOV     R3, R12
        Debug   fs,"OS_FSControl (AddFS)",R0,R1,R2,R3
        SWI     XOS_FSControl

        EXIT

;..............................................................................

SVC_ReadUpperCaseTable
        LDR     R12,[R12]
ReadUpperCaseTable Entry
        MOV     r0, #-1
        SWI     XTerritory_UpperCaseTable
        MOVVS   r0, #0
        STR     r0, UpperCaseTable
        BL      JunkQuickIndexBlock
        EXIT

; *****************************************************************************
;
;       ROMFS_Die - Die entry
;
; Deallocate link blocks, issue Service_ResourceFSDying and FSControl_RemoveFS

ROMFS_Die Entry

        LDR     R12, [R12]              ; R12 -> workspace

        BL      JunkQuickIndexBlock

        ; Junk the started callback if present
        LDR     r0, MiscFlags
        TST     r0, #StartedCallbackIssued
        addr    r0, StartedCallback, NE
        MOVNE   r1, r12
        SWINE   XOS_RemoveCallBack

; OSS Close our own Messages file if it is open, and then flag it as closed.
; OK so even if it is closed I flag it as closed, but this is hardly speed
; critical code.

; Note that caution is needed here, since we ARE ResourceFS. If we close the
; file too late, it will not exist. However, we must also not translate any
; errors after the file is closed. If the need arises, such errors will have
; to be pre-cached.

        LDR     r0, message_file_open
        TEQ     r0, #0
        ADRNE   r0, message_file_block
        SWINE   XMessageTrans_CloseFile
        MOV     r0, #0
        STR     r0, message_file_open

        Debug   die,"Messages file closed"

; Zero block out, since we may just try to do a Lookup with a block that
; is not open yet (see MsgCode file for more details).

        STR     R0, message_file_block
        STR     R0, message_file_block+4
        STR     R0, message_file_block+8
        STR     R0, message_file_block+12

        TEQ     R12, #0
        BEQ     %FT05

        LDR     R2, ROMFSFileData
        TEQ     R2, #0
        BEQ     %FT05

01      LDR     R3, [R2, #link_next]
        STR     R3, ROMFSFileData       ; remove link
        MOV     R0, #upfsfile_Delete    ; tell the Filer
        BL      modifyingfiles
        MOV     R0, #ModHandReason_Free
        SWI     XOS_Module
        MOVS    R2, R3
        BNE     %BT01

05      MOV     R1,#Service_ResourceFSDying        ; Resources: is disappearing!
        SWI     XOS_ServiceCall

        Debug   die,"Service_ResourceFSDying done"

        MOV     R0, #FSControl_RemoveFS
        addr    R1, StringROM           ; ADR or ADRL as appropriate
        SWI     XOS_FSControl

        Debug   die,"FSControl_RemoveFS done"

        CLRV
        EXIT                            ; return V clear

; *****************************************************************************
;
; JunkQuickIndexBlock
;
; In    -
; Out   - and quick index block junked
;

JunkQuickIndexBlock Entry "r0,r2"
        Debug   quickindex,"JunkQuickIndexBlock"

        MOV     r14, #0
        LDR     r2, QuickIndexBlock
        STR     r14, QuickIndexBlock
        CMP     r2, r14
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
        EXIT    VC
        STR     r0, [sp]
        EXIT

; *****************************************************************************
;
; ConstructQuickIndexBlock
;
; In    - quick index block junked
; Out   - and quick index block constructed. Ignore exit V.
;

ConstructQuickIndexBlock Entry "r0-r9"
        Debug   quickindex,"ConstructQuickIndexBlock"

        ; Count the files in resourcefs
        MOV     r3, #0
        ADR     r0, ROMFSFileData - link_next
        B       %FT30
15
        ADD     r3, r3, #1
        ADD     r1, r1, r2
20
        LDR     r2, [r1, #ROMFile_Offset]
        TEQ     r2, #0
        BNE     %BT15
30
        LDR     r0, [r0, #link_next]
        TEQ     r0, #0
        LDRNE   r1, [r0, #link_data]
        BNE     %BT20

        Debug   quickindex,"Number of files:",r3

        ; Preserve the number of entries
        MOVS    r9, r3
        EXIT    EQ                      ; No index block in 0-element case

        ; Claim a block for the data
        MOV     r0, #ModHandReason_Claim
        MOV     r3, r9, ASL #2          ; 4 bytes for index
        ADD     r3, r3, #4              ; for the number of entries
        SWI     XOS_Module
        EXIT    VS                      ; Doesn't matter if fails - simply works slowly

        MOV     r8, r2                  ; the index
        STR     r9, [r2]                ; number of entries

        MOV     r3, r9, ASL #3          ; 8 bytes for things to look for
        SWI     XOS_Module
        BVS     %FT90                   ; drat!

        MOV     r6, r2                  ; Things we're sorting

        ; Construct the data unsorted
        MOV     r3, #0
        ADD     r4, r8, #4
        MOV     r5, r6
        ADR     r0, ROMFSFileData - link_next
        B       %FT50
35
        STR     r5, [r4], #4
        ADD     r1, r1, #ROMFile_Name
;        DebugS  quickindex,"Unsorted:",r1
        STMIA   r5!, {r1,r3}            ; Store the name and the index for duplicates
        SUB     r1, r1, #ROMFile_Name
        ADD     r3, r3, #1
        ADD     r1, r1, r2
40
        LDR     r2, [r1, #ROMFile_Offset]
        TEQ     r2, #0
        BNE     %BT35
50
        LDR     r0, [r0, #link_next]
        TEQ     r0, #0
        LDRNE   r1, [r0, #link_data]
        BNE     %BT40

        Debug   quickindex,"Heap sort started"

        MOV     r0, r9
        ADD     r1, r8, #4
        ADR     r2, QuickIndexCompare
        MOV     r3, r12
        MOV     r7, #0
        SWI     XOS_HeapSort32
        BVS     %FT85                   ; Drat drat drat drat!

        Debug   quickindex,"Heap sort completed"

        ; burn down the now sorted index to give the index array we're after
        MOV     r3, r9
        ADD     r2, r8, #4
        B       %FT60
55
        LDR     r0, [r2]
        LDR     r0, [r0]
;        DebugS  quickindex,"Sorted:",r0
        STR     r0, [r2], #4
60
        SUBS    r3, r3, #1
        BHS     %BT55

        ; QuickIndexBlock now ready
        STR     r8, QuickIndexBlock

        ; Junk the temporary array - error not important
        MOV     r2, r6
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        EXIT

85
        ; Error from OS_HeapSort - junk both arrays
        MOV     r2, r6
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

90
        ; Error claiming 2nd block - junk quickindex block
        MOV     r2, r8
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        ; Errors not important - just run slowly
        EXIT

QuickIndexCompare Entry "r4,r5"
        Internat_UpperCaseLoad LR

        ; StrCmp the names
        LDR     r2, [r0, #0]
        LDR     r3, [r1, #0]
10
        LDRB    r4, [r2], #1
        LDRB    r5, [r3], #1
        Internat_UpperCase R4,LR
        Internat_UpperCase R5,LR
        CMP     r4, r5
        EXIT    NE
        TEQ     r4, #0
        BNE     %BT10

        ; Else compare the positions in the registrations
        LDR     r4, [r0, #4]
        LDR     r5, [r1, #4]
        CMP     r4, r5
        EXIT

; *****************************************************************************
;
; QuickIndexFind
;
; In    r1->filename to find (non-wildcard)
; Out   r1->best match and condition codes set for equality
;
; Assumes QuickIndexBlock already set up.
; Best match is least entry >= one requested
;
QuickIndexFind Entry "r0,r2-r10"

        ; Binary chop our way down to the relevant index

        DebugS  quickindex,"QuickIndexFind:",r1

        LDR     r9, QuickIndexBlock
        LDR     r8, [r9]                ; Number of elements (X)
        ORRS    r7, r8, r8, LSR #1
        ORR     r7, r7, r7, LSR #2
        ORR     r7, r7, r7, LSR #4
        ORR     r7, r7, r7, LSR #8
        ORR     r7, r7, r7, LSR #16
        BICS    r7, r7, r7, LSR #1      ; least 2^n <= X
        MOV     r6, #0

        Debug   quickindex,"Initial values:",r6,r7,r8

        Internat_UpperCaseLoad LR

        B       %FT60
10
        ADD     r5, r6, r7
        CMP     r5, r8
        BHI     %FT50

        Debug   quickindex,"Try values:",r5,r6,r7,r8

        LDR     r0, [r9, r5, ASL #2]
        MOV     r2, r1
        DebugS  quickindex,"Compare:",r0
        DebugS  quickindex," against:",r1

20
        LDRB    r3, [r0], #1
        LDRB    r4, [r2], #1
        Internat_UpperCase R3,LR
        Internat_UpperCase R4,LR
        CMP     r3, r4
        BNE     %FT30
        CMP     r3, #0
        BNE     %BT20
30
        SavePSR r10, HS                 ; preserve last HS result we got
        MOVLO   r6, r5
50
        MOVS    r7, r7, LSR #1
60
        BNE     %BT10

        ; If r6<r8 then we want the element above us with the preserved result
        ; else we want this element with the result LO
        SUB     r8, r8, #1
        CMP     r8, r6
        ADDHS   r6, r6, #1
        RestPSR r10, HS
        LDR     r1, [r9, r6, ASL #2]
        DebugS  quickindex,"Found:",r1
        Debug   quickindex,"Final results:",r6,r8,r10
        EXIT


; *****************************************************************************
;
; modifyingfiles - tell the Filer that files are being created / deleted
;
; In    R0 = reason code to pass in R9 to upcall
;       R2 -> link block at head of file list
; Out   UpCall_ModifyingFile called for ""
;       This causes all directories to be re-scanned!
;       It's hard to work out which directories are being created / deleted

modifyingfiles Entry "R0-R10"

        LDR     R8, fsinfoword          ; R8 = fs info word
        MOV     R9, R0                  ; R9 = reason code
        ADR     R1, null                ; R1 -> filename ("") - R2-R5 corrupt
        MOV     R6, #0                  ; no special field
        MOV     R0, #UpCall_ModifyingFile
        SWI     XOS_UpCall              ; ignore errors
        CLRV
        EXIT

null    DCB     0
        ALIGN

; *****************************************************************************
;
;       ResourceFS_Code - Process *ResourceFS command
;
; in:   R0 -> rest of line
;       R1 = number of parameters
;
; out:  R0-R6, R12 corrupted
;

ResourceFS_Code Entry
        MOV     R0, #FSControl_SelectFS
        addr    R1, StringROM           ; ADR or ADRL as appropriate
        SWI     XOS_FSControl           ; select filing system
        EXIT

; *****************************************************************************
;
;       ROMFS_Service - Main entry point for services
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
        ASSERT  Service_FSRedeclare < Service_TerritoryStarted
;
ROMFS_UServTab
        DCD     0
        DCD     ROMFS_UService - Module_BaseAddr
        DCD     Service_FSRedeclare
        DCD     Service_TerritoryStarted
        DCD     0
        DCD     ROMFS_UServTab - Module_BaseAddr
ROMFS_Service ROUT
        MOV     r0, r0
ROMFS_UService
        TEQ     R1, #Service_TerritoryStarted
        BEQ     SVC_ReadUpperCaseTable
        TEQ     R1, #Service_FSRedeclare        ; has someone reinited Stu ?
        MOVNE   PC, LR                          ; no, then exit

        LDR     R12, [R12]

svc_fsredeclare Entry   "R0-R3"

        BL      ROMFS_Declare                   ; else redeclare myself

        EXIT

; *****************************************************************************
;
;       ROMFS_OSFile - Entry point for OSFILE operations
;
; in:   R0 = reason code
;       R1-R? parameters
;

ROMFS_OSFile Entry
        Debug   fs, "ResourceFS:OS_File"
        TEQ     R0, #fsfile_Load
        BEQ     %FT10                   ; load file
        TEQ     R0, #fsfile_ReadInfo
        BEQ     %FT20                   ; read file info
        TEQ     R0, #fsfile_WriteInfo
        TEQNE   R0, #fsfile_WriteLoad
        TEQNE   R0, #fsfile_WriteExec
        TEQNE   R0, #fsfile_WriteAttr
        TEQNE   R0, #fsfile_Save
        TEQNE   R0, #fsfile_Delete
        TEQNE   R0, #fsfile_Create
        TEQNE   R0, #fsfile_CreateDir
        BEQ     ReadOnlyError

NotSupportedError
        ADR     R0, ErrorBlock_BadFilingSystemOperation
        Push    "r1"
        addr    r1, StringROM
        BL      copy_error_one          ; Always sets the V bit
        Pull    "r1,pc"

        MakeErrorBlock BadFilingSystemOperation

ReadOnlyError
        ADR     R0, ErrorBlock_FilingSystemReadOnly
        Push    "r1"
        addr    r1, StringROM
        BL      copy_error_one          ; Always sets the V bit
        Pull    "r1, pc"

        MakeErrorBlock FilingSystemReadOnly

; load file
; in:   R1 -> wildcarded filename
;       R2 = address to load file
;
; out:  R0 = object type
;       R2 = load address
;       R3 = exec address
;       R4 = size
;       R5 = attributes
;       R6 -> string to print for OPT 1,1
;

10
        MOV     R7, R2                  ; save address to load it to
        BL      FindFile

        MOV     R8, R6                  ; isolate leafname
11
        LDRB    R14, [R8], #1
        TEQ     R14, #'.'               
        MOVEQ   R6, R8                  ; update latest leaf start
        TEQ     R14, #0
        BNE     %BT11

        MOVS    R8, R4                  ; length into R8
        EXIT    EQ                      ; zero length, we've finished

12
        LDRB    R9, [R1], #1
        STRB    R9, [R7], #1
        SUBS    R8, R8, #1
        BNE     %BT12
        EXIT

; read file info
; in:   R1 -> wildcarded filename
;
; out:  R0 = object type
;       R2 = load address
;       R3 = exec address
;       R4 = size
;       R5 = attributes
;

20
        DebugS  fs,"Resourcefs:ReadInfo",r1
        BL      FindFileOrDirectory

        EXIT

; *****************************************************************************
;
;       ROMFS_FSFunc - Various functions
;
; in:   R0 = reason code
;

ROMFS_FSFunc Entry

        Debug   fs,"FSFunc",R0

        ; Do nothing on *Dir to keep FileSwitch happy
        TEQ     r0, #fsfunc_Dir
        EXIT    EQ

        TEQ     R0, #fsfunc_ReadDiscName
        BEQ     %FT30

 [ allowbooting							; Added by Rich, 16/8/95
	TEQ	R0, #fsfunc_Bootup				; Need to perform a boot option
	BEQ	%25
 ]
        TEQ     R0, #fsfunc_ReadDirEntries
        TEQNE   R0, #fsfunc_ReadDirEntriesInfo
        BEQ     romfs_fsfunc_readdirentries
        ASSERT  romfs_fsfunc_readdirentries = romfs_fsfunc_readdirentriesinfo
        TEQ     R0,#fsfunc_Lib
        TEQNE   R0,#fsfunc_Cat
        TEQNE   R0,#fsfunc_Ex
        TEQNE   R0,#fsfunc_LCat
        TEQNE   R0,#fsfunc_LEx
        TEQNE   R0,#fsfunc_Info
        TEQNE   R0,#fsfunc_ReadCSDName
        TEQNE   R0,#fsfunc_ReadLIBName
        TEQNE   R0,#fsfunc_PrintBanner
        TEQNE   R0,#fsfunc_SetContexts
        TEQNE   R0,#fsfunc_CatalogObjects
        TEQNE   R0,#fsfunc_FileInfo
        TEQNE   R0,#fsfunc_Opt
        BEQ     NotSupportedError

        TEQ     R0,#fsfunc_Rename
        TEQNE   R0,#fsfunc_Access
        BEQ     ReadOnlyError

        EXIT                    ; ignore any other reason codes (unknown)
                                ; ShutDown and Bootup are also ignored

 [ allowbooting							; Added by Rich, 16/8/95
25
	ADR	R0, runboot
	SWI	XOS_CLI
	EXIT

runboot  = "*Run &.!Boot",  0		 			; OPT 4 2
        ALIGN
 ]
30
        ; No disc name, no boot option
        MOV     r0, #0
        STRB    r0, [r2]

 [ allowbooting							; Added by Rich, 16/8/95
	MOV	r0, #2						; Only allow *Run, (OPT 4 2)
 ]
        STRB    r0, [r2, #1]
        EXIT

; .............................................................................

; in:   R1 -> wildcarded directory name
;       R2 -> buffer to put data
;       R3 = number of object names to read
;       R4 = offset of first item to read in directory
;       R5 = buffer length
;       R6 -> special field (ignored)
; out:  R3 = number of names read
;       R4 = offset of next item to read (-1 if end)


romfs_fsfunc_readdirentries      ROUT
romfs_fsfunc_readdirentriesinfo  ROUT

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
        BVS     %FT99                           ; R3 = offset to next
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
        ASSERT  ROMFile_Load = 4
        LDMNEIA R2, {R0-R4}
        STMNEIA R8!, {R1-R5}
        Pull    "R0-R5"

; now copy in the leafname, and word-align if R0 = fsfunc_ReadDirEntries

03      LDRB    R14, [R4], #1
        CMP     R14, #"."
        CMPNE   R14, #0                         ; zero-terminated in ResourceFS:
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
        STRVS   R0, [sp]
        Pull    "R0-R2, R5-R11, PC"

; *****************************************************************************
;
;       ROMFS_Open - Open a file
;
; in:   R0 = open reason code
;       R1 -> filename
;       R3 = handle
;       R6 -> special field (irrelevant)
;

ROMFS_Open Entry
        CMP     R0, #fsopen_Update
        BHI     NotSupportedError
        TEQ     R0, #fsopen_ReadOnly
        BNE     ReadOnlyError

        BL      FindFile                        ; return R1 -> file data
        MOV     R3, R4                          ; size of file
        MOV     R2, #&100                       ; buffer size
        MOV     R0, #fsopen_ReadPermission
        EXIT

; *****************************************************************************
;
;       ROMFS_Close - Close a file
;
; in:   R1 = my file handle = ptr to data
;

ROMFS_Close ROUT
        MOV     PC, R14

; *****************************************************************************
;
;       ROMFS_MediaToBuffer - Get bytes from file
;
; in:   R1 -> file data
;       R2 = memory address to put data
;       R3 = number of bytes to read
;       R4 = file offset to read from
;
; NB: ResourceFS is a buffered filing system, but files are not whole buffer lengths
;     FileSwitch will not call this with R4 > file length, but R4+R3 can be
;

ROMFS_MediaToBuffer Entry

        LDR     R14,[R1,#-4]            ; R14 = file length + 4
        SUB     R14,R14,#4              ; R14 = file length
        SUB     R14,R14,R4              ; R4 guaranteed to be within the file
        SUBS    R14,R14,R3              ; R14 = space at end: if negative,
        ADDLT   R3,R3,R14               ; reduce number of bytes to transfer

        ADD     R1, R1, R4              ; start of actual data

        ORR     R14, R1, R2             ; is it nicely word-aligned?
        ORR     R14, R14, R3
        TST     R14, #3
        BNE     %FT05

        TEQ     R3, #0
03
        LDRNE   R0, [R1], #4            ; all word aligned
        STRNE   R0, [R2], #4
        SUBS    R3, R3, #4
        BNE     %BT03
        EXIT

05      TEQ     R3, #0
10
        LDRNEB  R0, [R1], #1            ; not aligned
        STRNEB  R0, [R2], #1
        SUBS    R3, R3, #1
        BNE     %BT10
        EXIT

; *****************************************************************************
;
;       FindFile - Find a file of a particular name
;
; in:   R1 -> wildcarded filename to find
;
; out:  R0 = object type (0 => not found, 1 => file, 2 => directory)
;       R1 -> start of file data (if R0=1)
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

        EXIT

FindFileOrDirectory Entry

        LDRB    r14, [r1]
        TEQ     r14, #"$"
        LDREQB  r14, [r1, #1]
        TEQEQ   r14, #0
        BNE     %FT20

        MOV     r6, r1
        ADR     r14, %FT10
        LDMIA   r14, {r0-r5}
        EXIT

10
        ; FileInfo on $
        DCD     object_directory
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     read_attribute :OR: locked_attribute :OR: public_read_attribute

20
        BL      skipdollar                      ; remove "$." from wildcard

        ; Check for presence of a quick index block
        LDR     r0, QuickIndexBlock
        TEQ     r0, #0
        BLEQ    ConstructQuickIndexBlock
        LDR     r0, QuickIndexBlock
        CMP     r0, #0                          ; clear V (just in case)
        BEQ     %FT30

        ; Check for wildcards in filename
        MOV     r0, r1
25
        LDRB    lr, [r0], #1
        TEQ     lr, #"#"
        TEQNE   lr, #"*"
        BEQ     %FT30                           ; Has wildcards - do it by steam
        TEQ     lr, #0
        BNE     %BT25

        ; We have an index block and no wildcards - search for file/directory
        MOV     r0, r1                          ; preserve for WildMatch
        BL      QuickIndexFind
        MOV     r4, r1
        BL      WildMatch                       ; Check for directory matches
        MOVNE   r0, #object_nothing             ; not found
        MOVNE   r2, #0                          ; load=0
        MOVNE   r4, #0                          ; length=0
        EXIT    NE

        MOV     r6, r1                          ; filename
        ADD     R1, R4, #7                      ; word before data is length+4
        BIC     R1, R1, #3                      ; so the Font Manager can work

        LDRB    R14, [R4,#-1]                   ; if there's more
        TEQ     R14, #0
        ASSERT  ROMFile_Name-ROMFile_Load = 16
        LDMDB   R6, {R2-R5}                     ; get R2-R5
        MOVEQ   R0, #object_file                ; indicate file found
        MOVNE   R0, #object_directory           ; this must be a directory
        MOVNE   R4, #0                          ; length = 0
        MOVNE   R5, #0                          ; attributes = 0
        EXIT

30
        MOV     R0, R1                          ; R0 -> file name

        LDR     R3, ROMFSFileData

40
        CMP     R3, #0
        MOVEQ   R2, #0                          ; load = 0
        MOVEQ   R4, #0                          ; length = 0
        MOVEQ   R0, #object_nothing             ; indicate not found
        EXIT    EQ

        LDR     R1, [R3, #link_data]

50
        LDR     R2, [R1, #ROMFile_Offset]       ; is this a valid file ?
        TEQ     R2, #0                          ; if not, then
        LDREQ   R3, [R3, #link_next]
        BEQ     %BT40

        ADD     R4, R1, #ROMFile_Name           ; R4 -> name
        BL      WildMatch
        ADDNE   R1, R1, R2                      ; no match: update pointer
        BNE     %BT50                           ; and loop

; R4 -> byte after name terminator (not start of data unless file)

        ADD     R6, R1, #ROMFile_Name           ; R6 -> filename
        ADD     R1, R4, #7                      ; word before data is length+4
        BIC     R1, R1, #3                      ; so the Font Manager can work

        LDRB    R14, [R4,#-1]                   ; if there's more
        TEQ     R14, #0
        ASSERT  ROMFile_Name-ROMFile_Load = 16
        LDMDB   R6, {R2-R5}                     ; get R2-R5
        MOVEQ   R0, #object_file                ; indicate file found
        MOVNE   R0, #object_directory           ; this must be a directory
        MOVNE   R4, #0                          ; length = 0
        MOVNE   R5, #0                          ; attributes = 0

        EXIT

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

stk_R1  *       1 * 4           ; OSS Used to pick name up for errors
stk_R2  *       2 * 4           ; stack positions for return
stk_R4  *       3 * 4

FindDirEntry Entry "R0,R1,R2,R4,R9-R11"

        MOV     R0, R1                          ; R0 -> file name

        MOV     R14, #0                         ; latest candidate for return
        STR     R14, [sp, #stk_R4]

        LDR     R9, ROMFSFileData               ; R9 -> next link block

20      TEQ     R9, #0
        BEQ     returndirentry                  ; all done - what did we find?

        LDR     R2, [R9, #link_data]

10      LDR     R3, [R2, #ROMFile_Offset]       ; is this a valid file ?
        TEQ     R3, #0                          ; if not, then not found
        LDREQ   R9, [R9, #link_next]
        BEQ     %BT20

        ADD     R4, R2, #ROMFile_Name           ; R4 -> name
        LDRB    R14, [R0]                       ; special case - always match
        CMP     R14, #" "                       ; null directory
        BLS     %FT02

        BL      WildMatch                       ; R4 -> leafname

        ADDNE   R2, R2, R3                      ; R2 -> next file
        BNE     %BT10                           ; no match: loop

; error if no leafname - the "pathname" was really a file

        LDRB    R14, [R4, #-1]
        TEQ     R14, #"."
        ADRNE   R0, ErrorBlock_NotADirectory
        LDRNE   r1, [sp, #stk_R1]               ; %0 -> pathname R1 on stack
        BLNE    copy_error_one                  ; Always sets the V bit
        STRVS   R0, [sp]
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

        ADD     R2, R2, R3              ; R2 -> next file
        B       %BT10

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

        MakeErrorBlock NotADirectory

;......................................................................

; In    R10 -> filename1
;       R11 -> filename2
; Out   GT if R10 > R11, or (R10 or R11 is null)
;       LE if R10 <= R11

compare_R10_R11 Entry "R1,R2"

        Internat_UpperCaseLoad  R2

 [ {FALSE}
; KJB - fails if pointers are above &80000000
        RSBS    R14, R10, #1
        RSBLES  R14, R11, #1
        EXIT    GT                      ; GT <= either filename is null
 |
        TEQ     R10, #0
        TEQNE   R11, #0
        BEQ     %FT30                   ; jump if either filename null
 ]

        DebugS  fs,"compare_R10:",R10
        DebugS  fs,"compare_R11:",R11

10      LDRB    R14, [R10], #1
        LDRB    R1, [R11], #1
        Internat_UpperCase      R14, R2
        Internat_UpperCase      R1, R2
        CMP     R14, #"."
        CMPNE   R14, #0
        BEQ     %FT20                   ; filename1 terminated
; Fix for !Test+ then !Test added on top
        TEQ     R1, #"."
        MOVEQ   R1, #" "
; end fix
        CMP     R14, R1
        BEQ     %BT10
        EXIT

20      CMP     R1, #"."
        CMPNE   R1, #0                  ; EQ => same
        CMPNE   R1, #&100000            ; LT <= filename1 shorter
        EXIT

30      MOV     R1, #1
        CMP     R1, #0                  ; set GT
        EXIT

;.....................................................................

; in:   R1 -> wildcarded pathname
; out:  R1 -> pathname, with "$.", "@.", "%." or "\." removed

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

; In  : R0 is wildcard spec ptr, R4 is name ptr.
;       Wild Terminators are any ch <=" ",name terminator 0
;       Wildcards are *,#
; Out : EQ/NE for match (EQ if matches)
;       R4 points after name terminator for found
;       R10,R11 corrupted
;
; NB: new version also matches names whose leading pathnames match the wildcard spec.
;

WildMatch Entry "R0-R3"

        Internat_UpperCaseLoad R10

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
        Internat_UpperCase R1,R10
        Internat_UpperCase R2,R10
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
        Internat_UpperCase R1,R10

05      LDRB   R2,[R4],#1    ; step name
        CMP    R2,#0         ; terminator?
        BEQ    %BT03
        CMP    R2,#"."       ; if ".", can match wildcard terminator
        BEQ    %BT31
        Internat_UpperCase R2,R10
        CMP    R1,R2
        CMPNE  R1,#"#"       ; match if #
        BNE    %BT05
        MOV    R3,R4         ; name backtrack ptr is char after match
        B      %BT01         ; LOOP

; *****************************************************************************

        GET     MsgCode.s

      [ debug
        InsertNDRDebugRoutines
      ]

        END
