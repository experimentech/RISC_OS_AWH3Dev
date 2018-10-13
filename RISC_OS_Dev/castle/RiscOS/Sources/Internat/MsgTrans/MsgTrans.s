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
;
; MsgTrans.s (MessageTrans)
;
; Copyright (C) Acorn Computers Ltd. 1989 - 2000
;

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:Symbols
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:NewErrors
        GET     Hdr:WimpSpace
        GET     Hdr:Messages
        GET     Hdr:Proc
        GET     Hdr:Services
        GET     Hdr:MsgTrans
        GET     Hdr:HostFS
        GET     Hdr:NDRDebug
        GET     Hdr:PublicWS
        GET     Hdr:Squash
        GET     Hdr:OSRSI6

        GET     VersionASM

        GBLL    debug
        GBLL    debugswi
        GBLL    debugxx
        GBLL    debugenum                               ; For MessageTrans_EnumerateTokens
        GBLL    debugservice
        GBLL    debugerr                                ; For MessageTrans_ErrorLookup
        GBLL    debugintr                               ; For internationalisation
        GBLL    debugFSW
        GBLL    debughash
        GBLL    debughashalloc
        GBLL    debugstats

        GBLL    keepstats                               ; keep use counts on files - view with ShowMsgs
keepstats       SETL   {TRUE}
    [ keepstats
        ! 0, "WARNING: Keeping usage count statistics"
    ]

debug           SETL   {FALSE}
debugswi        SETL   debug :LAND: {TRUE}
debugxx         SETL   debug :LAND: {TRUE}
debugenum       SETL   debug :LAND: {TRUE}
debugservice    SETL   debug :LAND: {TRUE}
debugerr        SETL   debug :LAND: {TRUE}
debugintr       SETL   debug :LAND: {TRUE}
debugFSW        SETL   debug :LAND: {TRUE}
debughash       SETL   debug :LAND: {TRUE}
debughashalloc  SETL   debug :LAND: {FALSE}
debugstats      SETL   debug :LAND: {TRUE} :LAND: keepstats

debug_module    SETL   {TRUE}                          ; to use DebugIt
hostvdu         SETL   :LNOT:debug_module

; The following macro is provided for assistance debugging MessageTrans.
; By setting it to true, the module title changes to DbgMessageTrans and
; the SWI chunk prefix changes similarly, the SWI chunk changes to &C0E00
; This enables it to be softloaded on a RISC OS machine without confusing
; all the applications and modules relying on MessageTrans services.
    [ :LNOT: :DEF: AltTitleAndSWI
        GBLL    AltTitleAndSWI
AltTitleAndSWI  SETL   {FALSE}
    ]

; If set to true, claims 32 32-byte blocks in our private workspace, to enable
; us to claim/release blocks very quickly
; DOES NOT WORK YET
        GBLL    ChocolateProxies
ChocolateProxies  SETL {FALSE}

; If set to true, attempt to construct a hash table for the kernel dictionary.
        GBLL    HashDictionary
HashDictionary    SETL {TRUE}

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Workspace layout
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                                ^       0, wp
wsorigin                        #       0
link_header                     #       4
current_ForegroundBuffer        #       1
current_IRQBuffer               #       1
ThreadNess                      #       1
    [ ChocolateProxies
ProxyCountdown                  #       1       ; don't use chocolate blocks until this gets to 0
    |
alignpadding                    #       13
    ]
ptr_IRQsema                     #       4
MessageFile_block               #       5*4
GlobalMessageFile_block         #       5*4
Dictionary                      #       4
    [ HashDictionary
DictionaryHash                  #       4*256
    ]

MaxThreadNess * 2

    [ ChocolateProxies
ProxyBlockSize                  *       32      ; cannot change!
ProxyBlocks                     *       32      ; one bit per block in ProxyAlloc
ProxyAlloc                      #       4
ProxyMemorySize                 *       ProxyBlockSize * ProxyBlocks
ProxyMemory                     #       ProxyMemorySize
ChocolateCountdown              *       0
    ]

        ASSERT  (link_header-wsorigin)=0

ForegroundBuffersNo             *       16
IRQBuffersNo                    *       4
Buffersize                      *       &100

        AlignSpace 16

; These two must appear consecutively in the workspace
ForegroundBuffers               #       Buffersize*ForegroundBuffersNo
IRQBuffers                      #       Buffersize*IRQBuffersNo

workspace_size  * @-wsorigin

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Module header
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        AREA    |MsgTrans$$Code|, CODE, READONLY, PIC

Module_BaseAddr

        DCD     0                                       ; Start
        DCD     Init             - Module_BaseAddr
        DCD     Die              - Module_BaseAddr
        DCD     Service          - Module_BaseAddr
        DCD     TitleString      - Module_BaseAddr
        DCD     HelpString       - Module_BaseAddr
        DCD     0                                       ; CommandTable
        [ AltTitleAndSWI
        DCD     &C0E00
        |
        DCD     MessageTransSWI_Base
        ]
        DCD     MySWIDecode      - Module_BaseAddr
        DCD     MySWINames       - Module_BaseAddr
        DCD     0
        DCD     0
   [ :LNOT: No32bitCode
        DCD     MyFlags          - Module_BaseAddr
   ]

HelpString      DCB     "MessageTrans", 9, "$Module_HelpVersion", 0
                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Module flags.  Bit 0 set means module is 32-bit aware and safe
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   [ :LNOT: No32bitCode
MyFlags DCD     ModuleFlag_32bit
   ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; File control block format
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; Only the 32 byte blocks are ever linked into the MessageTrans chain.  MessageTrans always
; allocates blocks of 32 bytes long.  Clients will only pass 16 byte blocks normally, but
; can pass 32 byte blocks by specfiying R3 = FAST on the call to MessageTrans_OpenFile.  The
; client supplies certain guarantees by doing this too, notably: block will be safe (ie. NOT
; on the SVC stack); the client will call MessageTrans_CloseFile. If the client fails to do
; the latter, the hash table will be leaked.

                ^       0
fcb_link        #       4                               ; only linked in if not client buffer
fcb_flags       #       4                               ; flags in proxy blocks
fcb_fileptr     #       4                               ; pointer to file data: 0 => not loaded
fcb_filename    #       4                               ; pointer to filename
fcb_hash        #       4                               ; hash table (if fcb_flags & flg_hashing)
fcb_clnt_block  #       4                               ; pointer back to client's block
fcb_use_count   #       4                               ; usage counter (only if keepstats is true)
fcb_reserved    #       4                               ; reserved for future use
fcb_size        #       0

                ^       0
fcb_clnt_magic  #       4                               ; magic word in client's proxy block
fcb_clnt_flags  #       4                               ; flags in the client's block
fcb_real_block  #       4                               ; pointer to proxy descriptor
fcb_clnt_fname  #       4                               ; pointer to filename
fcb_clnt_size   #       0


flg_inresourcefs        *       1 :SHL: 0               ; file data is in resourcefs, else RMA
flg_ourbuffer           *       1 :SHL: 1               ; means that on closing we must free the buffer
flg_addtolist           *       1 :SHL: 2               ; means treat seeing as opening

flg_defer_hash_creation *       1 :SHL: 25              ; defer creation of the hash table
flg_new_api             *       1 :SHL: 26              ; client set R3 to magic value on OpenFile SWI
flg_worth_hashing       *       1 :SHL: 27              ; set if MessageTrans_OpenFile feels it's worth it
flg_hashing             *       1 :SHL: 28              ; the client's hash table pointer is valid
flg_freeblock           *       1 :SHL: 29              ; we allocated this descriptor in the RMA
flg_proxy               *       1 :SHL: 30              ; fcb_fileptr points to our own descriptor
flg_sqshinresourcefs    *       1 :SHL: 31              ; means a squashed file in resourcefs

flg_hidden_from_client  *       (2_1111111 :SHL: 25)    ; Mask for internal only flags.

MinimumHashableFileSize *       80                      ; minimum file size to enable hashing
MinimumTokenCount       *       8                       ; number of tokens required to enable hashing

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Init entry - claim and initialise workspace.
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Init    Entry

        LDR     r2, [r12]
        TEQ     r2,#0
        BNE     %FT01

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =workspace_size
        SWI     XOS_Module
        EXIT    VS

        STR     r2, [ r12 ]
01      MOV     wp, r2

    [ ChocolateProxies
        MVN     r0, #0
        STR     r0, ProxyAlloc
        MOV     r0, #ChocolateCountdown
        STRB    r0, ProxyCountdown
    ]
        MOV     r0, #0
        STR     r0, link_header
        STRB    r0, current_ForegroundBuffer
        STRB    r0, current_IRQBuffer
        STR     r0, MessageFile_block
        STR     r0, GlobalMessageFile_block
        STR     r0, Dictionary
        STRB    r0, ThreadNess

        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_IRQsema
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        CMP     r2, #0
        LDREQ   r2, =Legacy_IRQsema
        STR     r2, ptr_IRQsema

; Try to open message files
        BL      AttemptOpenMessagesFiles
        Debug   xx,"Module initialisation completed"
        CLRV
        EXIT

MessagesFileName         DCB     "Resources:$.Resources.MsgTrans.Messages", 0
GlobalMessagesFileName   DCB     "Resources:$.Resources.Global.Messages", 0
        ALIGN

; --------------------------------------------------------------------------------
;
; AttemptOpenMessagesFiles
;
; Attempt to open ours and the global messages files.
; Error not returned - failure simply means they're not open.
;

AttemptOpenMessagesFiles Entry "r0-r3"

        LDR     r0, MessageFile_block
        TEQ     r0, #0
        BNE     %FT50
        ADR     r0, MessageFile_block + 4
        ADR     r1, MessagesFileName
        DebugS   xx,"Opening MsgTrans message file", r1
        MOV     r2, #0
        BL      SWIMessageTrans_OpenFile
        MOVVS   r0, #0
        STR     r0, MessageFile_block                   ; Either 0 or the correct address

50
        LDR     r0, GlobalMessageFile_block
        CMP     r0, #0                                  ; clears V
        EXIT    NE
        ADR     r0, GlobalMessageFile_block + 4
        ADR     r1, GlobalMessagesFileName
        DebugS   xx,"Opening global message file", r1
        MOV     r2, #0
        BL      SWIMessageTrans_OpenFile
        MOVVS   r0, #0
        STR     r0, GlobalMessageFile_block             ; Either 0 or the correct address
        Debug   xx,"Global file opened",r0

        CLRV
        EXIT

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Die entry - throw away all blocks without telling anybody
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        ;       Allocated data for each block is freed (hash table, file data
        ;       and proxy) and flg_addtolist is set in the flags of the original
        ;       client block. Next time a lookup is performed the file will be
        ;       reopened. Note that accessing the client block is safe since
        ;       only files opened with R2=0 are on this list, and their client
        ;       descriptors must be in RMA.
        ;       The module workspace is freed by the kernel on exit.


Die     Entry

        ; Don't bother closing our own messages files because we're going to
        ; reopen them anyway on initialisation.

        LDR     wp, [ r12 ]
        LDR     r6, magicnumber_fast
DieLoop
        LDR     r0, link_header
        CMP     r0, #0                                  ; clears V
        EXIT    EQ
        LDR     r14, [ r0, #fcb_link ]                  ; Delete block from chain
        STR     r14, link_header
        LDR     r4, [ r0, #fcb_clnt_block ]             ; Get pointer back to client block

        BL      HashTableDelete                         ; Delete the hash table (if any)
        BL      CloseFileFreeData                       ; Free proxy block and file data (if any)

        LDR     r0, [ r4, #fcb_clnt_magic ]             ; Get the client magic word
        EORS    r0, r0, r6                              ; Check (and set r0 to 0)
        BNE     DieLoop                                 ; Don't attempt to modify client block if invalid
        STR     r0, [ r4, #fcb_real_block ]             ; Mark it as 'no valid data'
        STR     r0, [ r4, #fcb_clnt_magic ]             ; Clear the magic word
        LDR     r0, [ r4, #fcb_clnt_flags ]
        AND     r0, r0, #flg_worth_hashing:OR:flg_new_api  ; Preserve only these flags
        ORR     r0, r0, #flg_addtolist                  ; Magic flag to cope with a new MessageTrans
        STR     r0, [ r4, #fcb_clnt_flags ]             ; Set the flags to tell a new MessageTrans to reopen

        B       DieLoop

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Service call handling
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

;Ursula format
;
        ASSERT  Service_ResourceFSStarted < Service_ResourceFSDying
        ASSERT  Service_ResourceFSDying   < Service_TerritoryStarted
        ASSERT  Service_TerritoryStarted  < Service_ModulePostInit
;
UServTab
        DCD     0                              ;flags
        DCD     UService - Module_BaseAddr
        DCD     Service_ResourceFSStarted
        DCD     Service_ResourceFSDying
        DCD     Service_TerritoryStarted
        DCD     Service_ModulePostInit
        DCD     0                              ;terminator
        DCD     UServTab - Module_BaseAddr     ;anchor
Service
        MOV     r0,r0                          ;magic instruction
        Debug   service,"Service call entry: R0,R1,R2 =", r0, r1, r2
        TEQ     r1, #Service_ResourceFSDying
        TEQNE   r1, #Service_TerritoryStarted
        TEQNE   r1, #Service_ResourceFSStarted
        TEQNE   r1, #Service_ModulePostInit
        MOVNE   pc, lr
UService
        TEQ     r1, #Service_ModulePostInit
        BEQ     Service_ModulePostInit_Handler

        ;       It is possible that the contents of ResourceFS has now
        ;       changed.  We must now mark all message files that used
        ;       ResourceFS as being invalid i.e. the data pointer must be
        ;       set to zero so that when data is required the address of the
        ;       data will be re-computed.  If the service was either
        ;       TerritoryStarted or ResourceFSStarted then it is also
        ;       important to tell any clients that they must re-cache any
        ;       pointers into the message file and that they must re-open
        ;       any menu structures built from the message file, to do this
        ;       the service call Service_MessageFileClosed is issued.
        ;       All blocks remain "Open" and on the list.

        Push    "r0-r2, lr"
        LDR     wp, [ r12 ]
        MOV     r1, #Service_Serviced                   ; Keep a flag to see if any files have changed
        LDR     r2, link_header                         ; Look at the head of the chain
ResourceFSLoop
        Debug   service,"block",r2
        TEQ     r2, #0
        BEQ     FinishResourceFS
        LDR     r0, [ r2, #fcb_flags ]
        Debug   service,"flags",r0
        TST     r0, #flg_inresourcefs                   ; Is it in the ROM?
        BLNE    Service_CheckFileMoved                  ; has this change affected this file?
        MOVNE   r1, #Service_MessageFileClosed          ; Flag for later service call
        MOVNE   r0, #0
        STRNE   r0, [ r2, #fcb_fileptr ]                ; Mark data as 'not there'
        MOVNE   r0, r2
        BLNE    HashTableDelete
        LDR     r2, [ r2, #fcb_link ]
        B       ResourceFSLoop

FinishResourceFS
        TEQ     r1, #Service_Serviced                   ; Do we want to send a service call at all?
        MOVNE   r0, #0                                  
        LDRNE   r14, [ sp, #4 ]                         ; Get the actual service call type
        TEQNE   r14, #Service_ResourceFSDying           ; Don't prod clients on ResourceFS death
        [       debugservice
        BEQ     %76
        Debug   service,"Service_MessageFileClosed: in ",r0,r1
        SWI     XOS_ServiceCall                         ; can't return error
        Debug   service,"Service_MessageFileClosed: out",r0,r1
76
        |
        SWINE   XOS_ServiceCall                         ; can't return error
        ]

        ; just in case we hadn't got them open already, lets try again...
        LDR     r14, [sp, #4]
        TEQ     r14, #Service_ResourceFSStarted
        BLEQ    AttemptOpenMessagesFiles

ExitServiceResourceFS
        Pull    "r0-r2, pc"

Service_ModulePostInit_Handler
        ;       When we are first initialised we send round a
        ;       Service_MessageFileClosed. This is needed to tell clients
        ;       that had direct pointers into message data created by a
        ;       previous MessageTrans that these are no longer valid.

        ADRL    r12, Module_BaseAddr
        TEQ     r0, r12                                 ; is it us that has just been initialised?
        MOVNE   pc, lr                                  ; no
        Push    "r0-r1, lr"
        MOV     r0, #0
        MOV     r1, #Service_MessageFileClosed          ; Flag for later service call
        Debug   service,"Initial Service_MessageFileClosed: in ",r0,r1
        SWI     XOS_ServiceCall                         ; can't return error
        Debug   service,"Initial Service_MessageFileClosed: out",r0,r1
        Pull    "r0-r1, pc"

        ; This routine looks at the descriptor pointed to be R2 and determines
        ; whether the file has moved or not.  If it has not, then it returns with Z set.
        ; If it has, then it returns with Z clear.  All other flags are corrupted.
        ; The effect of this is that the service call Service_MessageFileClosed does not
        ; go around unnecessarily (ie. it only goes round if one of the message files
        ; currently open and buffered by MessageTrans from ResourceFS has actually changed).
        ; This optimisation will relieve RAMFSFiler of its need to commit suicide every time
        ; ResourceFS changes.  ShowMsgs will confirm that none of the data pointers are 0
        ; after a ResourceFS change.
Service_CheckFileMoved Entry "r1-r4"
        LDR     r4, [ r2, #fcb_fileptr ]
        LDR     r1, [ r2, #fcb_filename ]
        DebugS  service, "check_file_moved filename:", r1
        BL      internal_fileinfo
        TEQ     r0, #flg_inresourcefs                   ; error block won't be 1, will it? :)
        TEQEQ   r2, r4

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI decoding: R11 = SWI index to call
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        MACRO
$lab    MySWI   $swiname
        [ :LNOT: AltTitleAndSWI
        ASSERT  MessageTransSWI_Base+(.-jptable)/4 = $swiname
        ]
$lab    B       SWI$swiname
        MEND

MySWIDecode ROUT
        CMP     r11, #maxswi
        LDRCC   wp, [ r12 ]                             ; De-reference to workspace
        ADDCC   pc, pc, r11, LSL #2
        B       error_badswi

; jump table must follow immediately

jptable
        MySWI   MessageTrans_FileInfo                   ; &041500
        MySWI   MessageTrans_OpenFile                   ; &041501
        MySWI   MessageTrans_Lookup                     ; &041502
        MySWI   MessageTrans_MakeMenus                  ; &041503
        MySWI   MessageTrans_CloseFile                  ; &041504
        MySWI   MessageTrans_EnumerateTokens            ; &041505
        MySWI   MessageTrans_ErrorLookup                ; &041506
        MySWI   MessageTrans_GSLookup                   ; &041507
        MySWI   MessageTrans_CopyError                  ; &041508
        MySWI   MessageTrans_Dictionary                 ; &041509

maxswi  *       (.-jptable)/4

TitleString
MySWINames
        [ AltTitleAndSWI
        DCB     "Dbg"
        ]
        DCB     MessageTransSWI_Name, 0
        DCB     "FileInfo", 0
        DCB     "OpenFile", 0
        DCB     "Lookup", 0
        DCB     "MakeMenus", 0
        DCB     "CloseFile", 0
        DCB     "EnumerateTokens", 0
        DCB     "ErrorLookup", 0
        DCB     "GSLookup", 0
        DCB     "CopyError", 0
        DCB     "Dictionary", 0
        DCB     0
        ALIGN

error_badswi
        Push    "r1,r2,r4,lr"
        ADR     r0, ErrorBlock_NoSuchSWI
        MOV     r1, #0
        MOV     r2, #0
        ADR     r4, TitleString
        BL      SWIMessageTrans_ErrorLookup
        Pull    "r1,r2,r4,pc"

        MakeInternatErrorBlock NoSuchSWI,,BadSWI

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI definitions
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; SWI MessageTrans_FileInfo
; In    R1 -> filename
; Out   R0 = flag word:
;            bit 0 set => this file is in Resources: (can be accessed directly)
;            bits 1..31 reserved (ignore them)
;       R1   Preserved
;       R2 = size of buffer required to hold file
;            if R0 bit 0 set, the buffer is not required for read-only access

SWIMessageTrans_FileInfo Entry "r3"

    [ debugswi
        ADD     sp, sp, #1*4                            ; discard saved registers
        Debug   swi,"IN:  MessageTrans_FileInfo", r1
        DebugS  swi,"Filename =", r1
        BL      %FT55
        DebugE  swi,"ERR: MessageTrans_FileInfo"
        Debug   swi,"OUT: MessageTrans_FileInfo", r0, r1, r2
        Pull    "pc"
55
        ALTENTRY
    ]

        BL      internal_fileinfo
        BICVC   r0, r0, #flg_hidden_from_client         ; flags not for external consumption
        MOVVC   r2, r3                                  ; R2 = size of buffer required

        EXIT

; ..............................................................................

; In    R1 -> filename
; Out   R0 = flag word:
;            bit 0 set => this file is in Resources: (can be accessed directly)
;            bits 1..31 reserved (ignore them)
;       R1   Preserved
;       R2 = address of file data minus 4 (if resourcefs)
;       R3 = size of buffer that would be required to hold file data

ErrorBlock_Recurse
        DCD     ErrorNumber_MessageTrans_Recurse
        DCB     "Recursion in MessageTrans",0
        ALIGN

internal_fileinfo Entry "r1,r4-r7"

        LDRB    lr, ThreadNess
        CMP     lr, #MaxThreadNess
        XError  Recurse, HS
        EXIT    VS
        ADD     lr, lr, #1
        STRB    lr, ThreadNess

        DebugS  xx,"MessageTrans_FileInfo", r1
        DebugS  FSW,"MessageTrans:OSFind_ReadFile",r1

        MOV     r0, #OSFind_ReadFile
        SWI     XOS_Find
        BVS     %FT99
        MOV     r1, r0                                  ; R1 = file handle

        Debug   FSW,"Handle=",r0

        MOV     r3, r1                                  ; save for a moment
        MOV     r0, #FSControl_ReadFSHandle
        SWI     XOS_FSControl
        ANDVC   r4, r2, #&FF                            ; R4 = filing system number
        SUBVC   r5, r1, #4                              ; R5 -> file size, data
        MOVVC   r1, r3

        MOVVC   r0, #OSArgs_ReadEXT
        SWIVC   XOS_Args                                ; R2 = extent of file
        ADDVC   r3, r2, #4                              ; R3 = file size + 4
        BVS     %FT95

        TEQ     r4, #fsnumber_resourcefs
        MOVNE   r0, #0
        MOVNE   r2, #0
        BNE     %FT95

        MOV     r2, r5

        ; It's in resourcefs - check for squashed file
        LDR     lr, SQSHTag
        LDR     r0, [r2, #4]                            ; 'SQSH' tag at start of squash files
        TEQ     r0, lr
        LDREQ   lr, =&ffffff00                          ; filetype_text in load address
        LDREQ   r0, [r2, #12]
        BICEQ   r0, r0, #&ff
        TEQEQ   r0, lr

        MOVNE   r0, #flg_inresourcefs
        MOVEQ   r0, #flg_sqshinresourcefs
        LDREQ   r3, [r2, #8]                            ; Unsquashed size
        ADDEQ   r3, r3, #4

95      MVNVS   r7, #1 << 31
        MOVVC   r7, #0
        MOV     r6, r0
        MOV     r0, #0
        SWI     XOS_Find                                ; close file even if error
        MOVVC   r0, r6
        ADDS    r7, r7, #1                              ; preserve V

        Debug   xx,"Result: r0, r2, r3 =", r0, r2, r3

99
        Debug   FSW,"Out"
        LDRB    lr, ThreadNess
        SUB     lr, lr, #1
        STRB    lr, ThreadNess

        EXIT

SQSHTag DCB     "SQSH"
        ALIGN

; -----------------------------------------------------------------------------

; SWI MessageTrans_OpenFile
; In    R0 -> 4-word data structure
;             must be held in the RMA if R2=0 on entry
;       R1 -> filename, held in the RMA if R2=0 on entry
;       R2 -> buffer to hold file data
;             0 => allocate some space in the RMA,
;                  or use the file directly if it's in Resources:
;       If R3 = the constant "FAST" then the client is assumed
;             to have allocated a 32-byte block and guarantees to
;             call MessageTrans_CloseFile to allow us to free the
;             hash table.
;       If R3 = the constant "SLOW" then the client explicitly does
;             NOT want a hash table created (typically because only
;             one token is going to be looked up)


; Conditions for setting flg_worth_hashing:
;  "File is large enough" AND
;   ("Client used new API with magic constant in R3" OR "Client did not supply a buffer in R2")

; Conditions for generating a proxy block:
;  "Client did not supply a buffer in R2"

magicnumber_fast DCB     "FAST"
magicnumber_slow DCB     "SLOW"

SWIMessageTrans_OpenFile Entry "r0-r6"

    [ debugswi
        ADD     sp, sp, #7*4                            ; discard saved registers
        Debug   swi,"IN:  MessageTrans_OpenFile",r0,r1,r2,r3
        DebugS  swi,"Filename =",r1
        BL      %FT55
        DebugE  swi,"ERR: MessageTrans_OpenFile"
        Debug   swi,"OUT: MessageTrans_OpenFile",r0,r1,r2,r3
        Pull    "pc"
55
        ALTENTRY
    ]

        ; Check to see if the client descriptor refers to a proxy block on our list.
        LDR     r6, [ r0, #fcb_clnt_magic ]             ; read the client's magic word
        LDR     r5, magicnumber_fast
        CMP     r5, r6                                  ; clears V on match
        BNE     %FT20                                   ; magic word didn't match, so no proxy or hash table
        LDR     r5, [ r0, #fcb_clnt_flags ]             ; get client block flags
        TST     r5, #flg_proxy                          ; proxy flag set?
        BEQ     %FT15                                   ; no, so no proxy, but is 32-byte block so may have hash table
        LDR     r5, [ r0, #fcb_real_block ]             ; get pointer to proxy block
        ADR     r14, link_header - fcb_link             ; Check if the block is already in the list
OpenScanLoop
        LDR     r14, [ r14, #fcb_link ]
        TEQ     r14, #0                                 ; end of list?
        BEQ     %FT20                                   ; OK - didn't find it
        TEQ     r14, r5                                 ; is it the proxy we are looking for?
        BNE     OpenScanLoop                            ; no, so go round again
        LDR     r4, [ r5, #fcb_clnt_block ]
        TEQ     r4, r0                                  ; back pointer matches?
        BNE     %FT14                                   ; no - something odd has happened

        ; Descriptor is on list. If it's a directly accessed ResourceFS file,
        ; we just need to make sure the pointer is valid, otherwise we need to
        ; close the file before reloading to free allocated memory.
        LDR     r4, [ r5, #fcb_flags ]
        TST     r4, #flg_inresourcefs                   ; is it being directly accessed in ResourceFS?
        BEQ     %FT15                                   ; no, so force reload

        LDR     r4, [ r5, #fcb_filename ]               ; get filename pointer in proxy block
        TEQ     r1, r4                                  ; were we called with the same pointer?
        BNE     %FT15                                   ; no, so might be a different file

        LDR     r4, [ r5, #fcb_fileptr ]
        TEQ     r4, #0                                  ; is file pointer valid?
        EXIT    NE                                      ; yes, so nothing to do. Note V clear due to CMP above.
        
        Debug   xx, "Reloading ResourceFS file"
        BL      internal_fileinfo                       ; get file information
        BVS     ExitOpenQuick                           ; sorry - a problem occurred
        STR     r2, [ r5, #fcb_fileptr ]                ; set message data pointer
        EXIT
14
        Debug   xx, "ERROR: Proxy back pointer didn't match"
15
        Debug   xx, "Closing file and reloading"
        BL      SWIMessageTrans_CloseFile               ; close to discard allocated memory before continuing
20
        ADDS    r0, r1, #0                              ; R1=0? If so, R0=0,Z set,V clear; else R0 corrupt, Z+V clear
        LDREQ   r3, [r2, #0]                            ; Discover the length of the data
        BLNE    internal_fileinfo                       ; R0 = flags, R2 -> data, R3 = size
        BVS     ExitOpenQuick                           ; sorry - a problem occurred

        LDR     r4, stk_filedesc                        ; R4 -> file descriptor
        LDR     r5, stk_buffersize                      ; get caller's R3
        LDR     lr, magicnumber_fast                    ; get the magic word
        TEQ     lr, r5
        ORREQ   r0, r0, #flg_new_api+flg_worth_hashing  ; remember new API used.
        MOVEQ   lr, #0
        STREQ   lr, [r4, #fcb_clnt_block]               ; zero the back pointer
    [ keepstats
        STREQ   lr, [r4, #fcb_use_count]                ; zero the usage counter
    ]

        LDR     r14, magicnumber_slow                   ; get the magic word
        CMP     r14, r5                                 ; was it "SLOW" ?
        BICEQ   r0, r0, #flg_worth_hashing
        LDRNE   r14, stk_buffer                         ; get caller's R2
        CMP     r14, #0
        ORREQ   r0, r0, #flg_worth_hashing

        CMP     r3, #MinimumHashableFileSize            ; big enough to considering hashing this file?
        BICCC   r0, r0, #flg_worth_hashing              ; no - so forget that we'd like to do it

        STR     r0, [ r4, #fcb_clnt_flags ]
        STR     r1, [ r4, #fcb_filename ]
        STR     r5, [ r4, #fcb_clnt_magic ]             ; set magic word to caller's R3 (i.e. FAST if 32-byte block)

        LDR     r14, stk_buffer                         ; get caller's R2 again
        CMP     r14, #0                                 ; always clears V
        BNE     UseSuppliedBuffer

        BL      CopyDescriptorToRMA                     ; allocate a new descriptor, changes R4
        BVS     ExitOpenQuick                           ; failed to claim memory

        Debug   xx, "Proxy descriptor created in RMA OK"
        ; By now, R4 points to our own RMA proxy block if necessary, or the original
        ; client's block pointer.

        TST     r0, #flg_inresourcefs
        BEQ     FileNotDirectROM                        ; If it isn't in ResourceFS
        Debug   xx, "Use ResourceFS data directly"
        STR     r2, [ r4, #fcb_fileptr ]                ; R2 -> message data

ExitOpenFile
        LDRVC   r14, link_header                        ; If not an error, then link in to list
        STRVC   r14, [ r4, #fcb_link ]
        STRVC   r4, link_header
    [ debugservice
        BLVC    dump_chain
    ]
ExitOpenFile_NoLink
        MOVVC   r0, r4
        BLVC    HashTableAlloc                          ; allocate and construct the hash table if wanted
ExitOpenQuick
        STRVS   r0, [ sp, #0 ]                          ; If error store in exit frame
        EXIT

UseSuppliedBuffer                                       ; Doesn't matter which FS its from
        Debug   xx, "Using user-supplied buffer"
        BIC     r0, r0, #flg_inresourcefs               ; flg_inresourcefs means we're pointing
        STR     r0, [ r4, #fcb_flags ]                  ; at resourcefs now
        STR     r14, [ r4, #fcb_fileptr ]               ; Put its address in the block
        CMP     r1, #0                                  ; Did we get passed a filename?  (clear V always)
        MOVNE   r5, r2
        MOVNE   r2, r14
        BLNE    OpenFile_LoadIntoBuffer
        B       ExitOpenFile_NoLink

FileNotDirectROM
        ; r0=flags
        ; r1=filename
        ; r2=resourcefs address
        ; r3=size needed
        ; r4=messagefile block
        Debug   xx, "Make our own buffer for file in RMA"
        MOV     r6, r0
        MOV     r0, #ModHandReason_Claim                ; R3 is still size to claim
        SWI     XOS_Module
        MOVVC   r0, r6
        BLVC    OpenFile_LoadIntoBuffer
        LDRVC   r14, [ r4, #fcb_flags ]
        ORRVC   r14, r14, #flg_ourbuffer                ; Mark this as ours so we free it on Close
        STRVC   r14, [ r4, #fcb_flags ]
        STRVC   r2, [ r4, #fcb_fileptr ]                ; Put its address in the block
        BVC     ExitOpenFile
        MOV     r4, r0                                  ; Keep the error
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOV     r0, r4
        SETV
        B       ExitOpenQuick

    [ debugservice
dump_chain Entry "r0-r1"
        MRS     r1, CPSR
        LDR     r0, link_header
        Debug   service, "dump_chain: Head pointer",r0
dc_loop
        LDR     r0, [r0, #fcb_link]
        Debug   service, "dump_chain: Link pointer",r0
        CMP     r0, #0
        BNE     dc_loop
        MSR     CPSR_f, r1
        EXIT
    ]

    [ {FALSE}
        ; This error is not returned any more
err_alreadyopen
        Push    "r1, r2"
        ADR     r0, ErrorBlock_FileOpen
        LDR     r1, MessageFile_block                   ; Either 0 or the block address
        MOV     r2, #0
        BL      SWIMessageTrans_ErrorLookup
        Pull    "r1, r2"
        B       ExitOpenFile

ErrorBlock_FileOpen
        DCD     ErrorNumber_MessageTrans_FileOpen
        DCB     "FilOpen", 0
        ALIGN
    ]

CopyDescriptorToRMA Entry "r0-r3,r5,r6,r7"
    [ ChocolateProxies
        LDRB    r3, ProxyCountdown
        TEQ     r3, #0
        BNE     %FT10
        LDR     r1, ProxyAlloc                          ; bit set = array entry available
        RSB     r3, r1, r3
        ANDS    r3, r3, r1
        BEQ     %FT10                                   ; none left!
        BIC     r1, r1, r3
        STR     r1, ProxyAlloc
        ADR     r2, ProxyMemory
01
        MOVS    r3, r3, LSR #1
        ADDNE   r2, r2, #ProxyBlockSize
        BNE     %BT01
10
    ]
        MOV     r3, #fcb_size
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module                              ; Try and get a new RMA block for descriptor
        EXIT    VS                                      ; OK - leave it then
        LDMIA   r4, {r0,r1,r3,r5}                       ; get data from client's original descriptor block
        ORR     r1, r1, #flg_proxy                      ; Set flag that we allocated this block
        ASSERT  fcb_clnt_magic = 0                      ; place for magic word
        ASSERT  fcb_clnt_flags = 4                      ; Store flag so TranslateFindDescriptor knows about it
        ASSERT  fcb_real_block = 8                      ; link from client descriptor to our new descriptor
        ASSERT  fcb_clnt_fname = 12                     ; Store copy of filename pointer for now
        LDR     r0, magicnumber_fast                    ; get the magic word
        STMIA   r4, {r0, r1, r2, r5}
        MOV     r0, #0
        EOR     r1, r1, #flg_freeblock :OR: flg_proxy   ; set flg_freeblock, clears flg_proxy
        MOV     r6, #0                                  ; hash table pointer set to 0
        MOV     r7, r4                                  ; backwards pointer to client block
        STMIA   r2, {r0,r1,r3,r5,r6,r7}                 ; copy information to our own internal descriptor
    [ keepstats
        STR     r6, [r2, #fcb_use_count]                ; zero the usage counter
    ]
        MOV     r4, r2                                  ; replace caller's descriptor pointer
        EXIT                                            ; and return.

TranslateFindDescriptor Entry "r1"

        ; This routine checks a descriptor to see if it was a proxy that was set up previously
        ; by CopyDescriptorToRMA.  If it was, then the proxy pointer is dereferenced to get the
        ; real block's address.  Must preserve C and V.

        TEQ     r0, #0                                  ; a null pointer?
        LDRNE   r1, [ r0, #fcb_clnt_flags ]             ; get flags from descriptor block
        TSTNE   r1, #flg_proxy                          ; was it a proxy?
        LDRNE   r0, [ r0, #fcb_real_block ]             ; It was - follow the proxy link
        EXIT


; Subroutine for MessageTrans_OpenFile
;
; In  r0 = flags
;     r1 = filename
;     r2 = destination buffer
;     r3 = length
;     r5 = resourcefs source address (if relevant)
; Out r0 corrupt
OpenFile_LoadIntoBuffer Entry "r1-r6"

        ; Store buffer length at start of buffer
        STR     r3, [r2], #4

        TST     r0, #flg_sqshinresourcefs
        BEQ     %FT50

        MOV     r4, r2                                  ; destination

        ; Claim decompression workspace
        MOV     r0, #&8                                 ; how much workspace do we need?
        SWI     XSquash_Decompress
        EXIT    VS

        MOV     r3, r0
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        EXIT    VS

        ; Do the decompression
        MOV     r0, #0                                  ; decompress slow (with limits)
        MOV     r1, r2                                  ; workspace
        MOV     r2, r5                                  ; input
        LDR     r3, [r2], #24                           ; inbytes (and skip the SQSH header)
        SUB     r3, r3, #24                             ; discount the squash header
        LDR     r5, [r2, #-16]                          ; outbytes
        SWI     XSquash_Decompress

        ; Free the decompression workspace, ignoring errors
        SavePSR r5
        Push    "r0"

        MOV     r2, r1
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        Pull    "r0"
        RestPSR r5,,f
    [ No32bitCode
        NOP
    ]

        EXIT

50
        ; Load file without faff
        MOV     r0, #OSFile_Load
        MOV     r3, #0
        SWI     XOS_File

        EXIT

;......................................................................................

EnsureFileIsOpen
        ; In    R0 -> data structure
        ; Out   R3 -> pointer to data
        ;       R4 -> pointer to byte after data
        ;       R1, R2 Trashed
        ;       R0 may have been changed if file was reopened due to MessageTrans reinitialisation
        LDR     r3, [ r0, #fcb_fileptr ]
        CMP     r3, #0                                  ; Clears V
        LDRNE   r4, [ r3 ], #4                          ; R4 = size of file + 4
        ADDNE   r4, r4, r3
        SUBNE   r4, r4, #4                              ; R4 -> byte after end of file
        MOVNE   pc, lr                                  ; Return fast in easy case

        ;       Here there is no file, it is one of four possible cases
        ;       The data has been removed by a Service_ResourceFS(Dying|Started)
        ;       If this is the case then just look it up again, this will have the
        ;       Flag set flg_inresourcefs=1, flg_ourbuffer=0, flg_addtolist=0.
        ;       The other three cases all have the flg_addtolist=1

FileIsNotHere
        LDR     r3, [ r0, #fcb_flags ]
        TST     r3, #flg_addtolist
        BNE     ReOpenBlock
        TST    r3, #flg_inresourcefs
        BEQ    err_invaliddescriptor
        Push    "r0, lr"
        LDR     r1, [ r0, #fcb_filename ]
        DebugS  xx, "Reloading file",r1
        BL      internal_fileinfo                       ; get file information
        Pull    "r1, pc", VS                            ; exit on error
        Pull    "r0"                                    ; Pointer to data structure
        MOV     r3, r2                                  ; Address of data - 4
        STR     r3, [ r0, #fcb_fileptr ]                ; R2 -> message data
FileNowOpen
        LDR     r4, [ r3 ], #4                          ; R4 = size of file + 4
        ADD     r4, r4, r3
        SUB     r4, r4, #4                              ; R4 -> byte after end of file
        Pull    "pc"

ReOpenBlock
        Push    "lr"
        LDR     r1, [ r0, #fcb_filename ]               ; get filename pointer
        MOV     r2, #0
        TST     r3, #flg_new_api                        ; was new API flag set?
        LDRNE   r3, magicnumber_fast                    ; if so, re-open the same way
        TSTEQ   r3, #flg_worth_hashing                  ; was worth hashing flag set?
        LDREQ   r3, magicnumber_slow                    ; if not, re-open with SLOW
        DebugS  xx, "Reopening file",r1
        BL      SWIMessageTrans_OpenFile                ; reload file. Proxy and hash table will be created if necessary
        Pull    "pc", VS                                ; exit on error
        BL      TranslateFindDescriptor                 ; get the new file descriptor
        LDR     r3, [ r0, #fcb_fileptr ]                ; get the message data pointer
        B       FileNowOpen

err_invaliddescriptor
        Push    "r1, r2, lr"
        ADR     r0, ErrorBlock_BadDesc
        LDR     r1, MessageFile_block                   ; Either 0 or the block address
        MOV     r2, #0
        BL      SWIMessageTrans_ErrorLookup
        Pull    "r1, r2, pc"

ErrorBlock_BadDesc
        DCD     ErrorNumber_MessageTrans_BadDesc
        DCB     "BadDesc:Message file descriptor is invalid", 0
        ALIGN

; -----------------------------------------------------------------------------

; SWI MessageTrans_GSLookup
; In    R0 -> 4-word data structure passed to MessageTrans_LoadFile
;       R1 -> token, terminated by 0, 10 or 13, or "token:default"
;       R2 -> buffer to hold result (0 => don't copy it)
;       R3 = buffer size (if R2 non-0)
;       R4 -> parameter 0 (0 => don't substitute for "%0")
;       R5 -> parameter 1 (0 => don't substitute for "%1")
;       R6 -> parameter 2 (0 => don't substitute for "%2")
;       R7 -> parameter 3 (0 => don't substitute for "%3")
; Out   R0,R1 -> preserved.
;       R2 -> result string (read-only with no parameter substitution if R2=0 on entry)
;       R3 = size of result before terminator (character 10 if R2=0 on entry, else 0)

;       Same as MessageTrans_Lookup, only string is GSTransed before you get it back,
;       This needs an intermediate buffer, and so will fail if one cannot be allocated
;       from the RMA.

SWIMessageTrans_GSLookup

    [ debugswi
        Push    "lr"
        Debug   swi,"IN:  MessageTrans_GSLookup",r0,r1,r2,r3,r4,r5,r6,r7
        DebugS  swi,"Token =",r1
        BL      %FT55
        DebugE  swi,"ERR: MessageTrans_GSLookup"
        Debug   swi,"OUT: MessageTrans_GSLookup",r0,r1,r2,r3,r4,r5,r6,r7
        Pull    "pc"
55
    ]

;       If R2 = 0 this SWI is identical to MessageTrans_Lookup.

        CMP     r2, #0
        BEQ     SWIMessageTrans_Lookup

;       Else ...

        Push    "r0-r1, r4-r7, r8-r10, lr"

        MOV     r9, r2                                  ; Keep the user's buffer
        MOV     r10, r3

;       First allocate a buffer to hold the result to be the same
;       length as the buffer provided by the client.

        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r1, r4-r7, r8-r10, pc", VS

        MOV     r8, r2                                  ; Keep address of claimed buffer for later freeing
        LDMIA   sp, { r0, r1 }                          ; Restore entry values of R0 and R1

;       Now all registers are as on entry, but R2/R3 describes the new buffer

        BL      SWIMessageTrans_Lookup                  ; Go find the message
        MOVVC   r0, r2                                  ; Output of lookup
        MOVVC   r1, r9                                  ; User's buffer pointer
        MOVVC   r2, r10                                 ; User's buffer length
        SWIVC   XOS_GSTrans                             ; Now GSTrans the result
        BVS     FreeGSBufferAndExit

;       Free the buffer and return.

        Push    "r0, r1, r2"
        MOV     r0, #ModHandReason_Free
        MOV     r2, r8
        SWI     XOS_Module
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r2, r3"
        STRVS   r0, [ sp, #0 ]
 [ :LNOT:No32bitCode
        TEQ     pc, pc
        Pull    "r0-r1, r4-r7, r8-r10, pc", EQ          ; corrupt flags for 32-bit exit
 ]
        Pull    "r0-r1, r4-r7, r8-r10, pc", VS
        Pull    "r0-r1, r4-r7, r8-r10, pc",, ^

FreeGSBufferAndExit
        STR     r0, [ sp, #0 ]                          ; Shove error into stack
        MOV     r0, #ModHandReason_Free
        MOV     r2, r8
        SWI     XOS_Module
        SETV                                            ; Force error, cleared by SWI
        Pull    "r0-r1, r4-r7, r8-r10, pc"

; -----------------------------------------------------------------------------

; SWI MessageTrans_ErrorLookup
; In    R0 -> Error block (Word aligned) containing error number , token, terminated by 0 or error number , "token:default"
;       R1 -> 4-word data structure passed to MessageTrans_LoadFile
;       R2 -> buffer to hold result (0 => Use internal buffer)
;       R3 =  buffer size (if R2 non-0)
;       R4 -> parameter 0 (0 => don't substitute for "%0")
;       R5 -> parameter 1 (0 => don't substitute for "%1")
;       R6 -> parameter 2 (0 => don't substitute for "%2")
;       R7 -> parameter 3 (0 => don't substitute for "%3")
; Out   R0 -> Error buffer used
;       V Set

SWIMessageTrans_ErrorLookup Entry "r1-r8"

    [ debugswi
        ADD     sp, sp, #8*4                            ; discard saved registers
        Debug   swi,"IN:  MessageTrans_ErrorLookup", r0, r1, r2, r3, r4, r5, r6, r7
        BL      %FT55
        DebugE  swi,"ERR: MessageTrans_ErrorLookup"
        Debug   swi,"OUT: MessageTrans_ErrorLookup", r0, r1, r2, r3, r4, r5, r6, r7
        Pull    "pc"
55
        ALTENTRY
    ]

; Set things up for MessageTrans_Lookup

; First find a buffer to use:

        CMP     r2,#0
        BLEQ    AllocateInternalBuffer                  ; R2=0 means check IRQsema

        ;       Now R2 -> Buffer to use
        ;       R3 =  Buffer Size
        LDR     r14, [ r0 ], #4                         ; Copy error number.
        ADD     r2, r2, #4                              ; Point at text start.
        Push    "r14"                                   ; Stack error number.
        MOV     r8, r0
        MOV     r0, r1                                  ; 4 word data structure
        MOV     r1, r8                                  ; Pointer to the error token
        SUB     r3, r3, #4                              ; Adjust output buffer size, because we have already changed R2

; Now
;       R0 -> File block
;       R1 -> Token
;       R2 -> Where to put translation
;       R3 -> Buffer size - 4 for error number.
;       R4 .. R7 as on entry.

        BL      SWIMessageTrans_Lookup                  ; Get the translation
        SUBVC   r0, r2, #4                              ; Point back at the error number
        Pull    "r14"
        STRVC   r14, [ r0 ]                             ; Store error number last.

        SETV                                            ; Always exit with V set
        EXIT

; -----------------------------------------------------------------------------

; SWI MessageTrans_CopyError
; In    R0 -> Error block (Word aligned) containing error number ,and error text terminated by 0
; Out   R0 -> Error buffer used
;       V Set

SWIMessageTrans_CopyError Entry "r1-r3"

; First find a buffer to use:

        MOV     r2, #0                                  ; look at IRQsema
        BL      AllocateInternalBuffer
        SUB     r3, r3, #4
        MOV     r1, r2                                  ; Keep copy for exit

; Now R2 -> Buffer to use
;     R3 ~= Buffer Size

        Debug   err,"Using buffer at ", r2

        LDR     r14, [ r0 ], #4                         ; Copy error number.
        STR     r14, [ r2 ], #4

CopyErrorLoop
        DECS    r3
        STREQB  r3, [ r2 ]                              ; Terminate when buffer is about to overflow
        LDRNEB  r14, [ r0 ], #1
        STRNEB  r14, [ r2 ], #1
        TEQNE   r14, #0
        BNE     CopyErrorLoop

        SETV
        MOV     r0, r1

        EXIT

; -----------------------------------------------------------------------------

; SWI MessageTrans_EnumerateTokens
; In    R0 -> 4-word data structure passed to MessageTrans_OpenFile
;       R1 -> token, terminated by 0, 10, 13 or ":"
;             wildcards: ? = match 1 char, * = match 0 or more chars
;       R2 -> buffer to hold result
;       R3 = buffer size
;       R4 = place marker (0 for first call)
; Out   R2 -> buffer, containing next token if found, with terminator copied from input
;             R2=0 => no more tokens found (we've finished)
;       R3 = length of result excluding terminator (if R2<>0)
;       R4 = place marker for next call (non-0)

; NOTE: Absolutely do not change the meaning of R4.  The hash table construction
;       code relies on it being an index into the file data.

                ^       0, sp
stk_filedesc    #       4               ; r0            ; R0-R3 as for MessageTrans_Lookup
stk_token       #       4               ; r1
stk_buffer      #       4               ; r2
stk_buffersize  #       4               ; r3
stk_place       #       4               ; r4

SWIMessageTrans_EnumerateTokens Entry "r0-r9"

    [ debugswi
        ADD     sp, sp, #10*4                           ; discard saved registers
        Debug   swi,"IN:  MessageTrans_EnumerateTokens", r0, r1, r2, r3, r4
        BL      %FT55
        DebugE  swi,"ERR: MessageTrans_EnumerateTokens"
        Debug   swi,"OUT: MessageTrans_EnumerateTokens", r0, r1, r2, r3, r4
        TEQ     r2, #0
        DebugSIf NE, swi,"Token found =", r2
        Pull    "pc"
55
        ALTENTRY
    ]

        DebugS  enum,"Token to match =", r1

        BL      TranslateFindDescriptor

        MOV     r9, r1                                  ; Save a pointer to the client's token
        BL      EnsureFileIsOpen
        BVS     ExitEnumerateTokens

        LDR     r14, stk_place
        ADD     r3, r3, r14                             ; r3 -> where to scan from
        CMP     r3, r4                                  ; Check we are within the file
        BHS     FinishEnumerateTokens                   ; Exit now if past end

; search each line of the file in turn, looking for <token>:

matchtoken
        MOV     r1, r9                                  ; R1 -> token to match with
        MOV     r5, r3                                  ; R5 -> token in file
02
        BL      get_R0_R1                               ; R0 := [ R1 ], #1  and  LS => it's a terminator
        BLS     %FT03

        BL      getbyte                                 ; R8 = next char from file
        BVS     FinishEnumerateTokens

        CMP     r8, #"#"                                ; ignore comment lines completely
        BEQ     skipline2

        TEQ     r0, #"*"                                ; just match whole of rest of token for now
        BEQ     matchrest

        CMP     r8, #"/"                                ; stop if reached end of token
        CMPNE   r8, #":"                                ; if followed by ":", skip to end of line
        CMPNE   r8, #&1f                                ; if end of line, skip to next
        BLS     skiptoken2

        CMP     r8, #"?"                                ; wildcard
        CMPNE   r0, r8
        CMPNE   r0, #"?"                                ; input token can also be wildcarded on this call
        BEQ     %BT02

; skip to next token on line, or skip line if no more tokens

skiptoken2
        BL      skiptonexttoken                         ; R3 -> next char, R8 = current char
        BVC     matchtoken

skipline2
        BLVC    skiptonextline
        BVC     matchtoken

; error => EOF, so indicate that we've finished

FinishEnumerateTokens
        Debug   enum, "No more tokens to enumerate"
        SUBS    r14, r14, r14                           ; R14=0, clear V
        STR     r14, stk_buffer                         ; buffer ptr = 0 on exit => no more found
ExitEnumerateTokens
        STRVS   r0, [ sp, #0 ]
        EXIT

; "*" encountered in match token - currently this must be the last char

matchrest
        BL      get_R0_R1
        BLS     EnumerateFoundToken                     ; found it!
        ADR     r0, ErrorBlock_Syntax
        LDR     r1, MessageFile_block                   ; Either 0 or the block address
        MOV     r2, #0
        MOV     r4, r9
        BL      SWIMessageTrans_ErrorLookup
        B       ExitEnumerateTokens

ErrorBlock_Syntax
        DCD     ErrorNumber_MessageTrans_Syntax
        DCB     "Syntax", 0
        ALIGN

; reached end of token - matched if next char is ":", "/" or linefeed

03      BL      getbyte
        BVS     FinishEnumerateTokens
        CMP     r8, #"/"                                ; "/" or newline => alternatives
        CMPNE   r8, #":"                                ; token must be followed by ":"
        CMPNE   r8, #&1f
        BHI     skiptoken2

31      CMP     r8, #":"                                ; skip to ":", where message is
        BEQ     EnumerateFoundToken
        BL      getbyte
        BVC     %BT31
        B       FinishEnumerateTokens

EnumerateFoundToken
        ; Found token - R0 = terminator of match token copy the
        ; found token into the supplied buffer, and terminate with R0

        MOV     r3, r5                                  ; R3 -> start of token in file
        LDR     r2, stk_buffer                          ; R2 -> output buffer
        LDR     r6, stk_buffersize                      ; R6 = counter

35      BL      getbyte                                 ; error here => corrupt file
        BVS     ExitEnumerateTokens
        SUBS    r6, r6, #1                              ; watch for buffer overflow
        BLLT    err_buffoverflow
        BVS     ExitEnumerateTokens
        CMP     r8, #"/"                                ; finished if "/", ":" or newline
        CMPNE   r8, #":"
        CMPNE   r8, #&1f
        STRHIB  r8, [ r2 ], #1
        BHI     %BT35
        STRB    r0, [ r2 ]                              ; R2 -> terminator (use same one as input)

        LDR     r6, stk_buffer
        SUBS    r5, r2, r6                              ; R5 = number of bytes copied, excluding terminator
        BEQ     skiptoken2                              ; ignore null tokens (R8 = terminator)

        BL      skiptonexttoken                         ; ignore errors (EOF), since that's for next time

        LDR     r0, stk_filedesc
        BL      TranslateFindDescriptor
        LDR     r0, [ r0, #fcb_fileptr ]
        ADD     r0, r0, #4                              ; R0 -> start of file data (ignore size field)
        SUB     r3, r3, r0                              ; R3 = offset within file for next time
        STR     r3, stk_place                           ; place marker for next call
        STR     r5, stk_buffersize                      ; length of token excluding terminator

        CLRV
        B       ExitEnumerateTokens                     ; DON'T return V flag

;......................................................................................

; In    R1 -> input token
; Out   R0 = next character in token
;       R1 -> character after that
;       LS => R0 is a terminator

get_R0_R1 ROUT
        LDRB    r0, [ r1 ], #1                          ; token is terminated by 0, 10, 13 or ":"
        CMP     r0, #","                                ; terminate on ","
        CMPNE   r0, #")"                                ; terminate on ")"
        CMPNE   r0, #":"                                ; terminate on ":"
        CMPNE   r0, #" "                                ; terminate on ctrl-char or space
        MOV     pc, lr

; -----------------------------------------------------------------------------

; SWI MessageTrans_Lookup
; In    R0 -> 4-word data structure passed to MessageTrans_LoadFile
;       R1 -> token, terminated by 0, 10 or 13, or "token:default"
;       R2 -> buffer to hold result (0 => don't copy it)
;       R3 = buffer size (if R2 non-0)
;       R4 -> parameter 0 (0 => don't substitute for "%0")
;       R5 -> parameter 1 (0 => don't substitute for "%1")
;       R6 -> parameter 2 (0 => don't substitute for "%2")
;       R7 -> parameter 3 (0 => don't substitute for "%3")
; Out   R1 -> token terminator
;       R2 -> result string (read-only with no parameter substitution if R2=0 on entry)
;       R3 = size of result before terminator (character 10 if R2=0 on entry, else 0)

                ^       4*4, sp         ; r0-r3 as for MessageTrans_EnumerateTokens
stk_parameter0  #       4               ; r4
stk_parameter1  #       4               ; r5
stk_parameter2  #       4               ; r6
stk_parameter3  #       4               ; r7
stk_endpars     #       0

SWIMessageTrans_Lookup

    [ debugswi
        Push    "lr"
        Debug   swi,"IN:  MessageTrans_Lookup",r0,r1,r2,r3,r4,r5,r6,r7
        DebugS  swi,"Token =",r1
        BL      %FT55
        DebugE  swi,"ERR: MessageTrans_Lookup"
        Debug   swi,"OUT: MessageTrans_Lookup",r0,r1,r2,r3,r4,r5,r6,r7
        Pull    "pc"
55
    ]

        Push    "r0-r3,lr"                              ; Preserve the inputs in case it fails

        DebugS  FSW,">>",r1

        BL      TranslateFindDescriptor                 ; changes R0
        CMP     r0, #0                                  ; Were we given a message block? (clears V)
        CMPEQ   r0, #&80000000                          ; set V if Z was set
        BLVC    internal_lookup
        LDRVC   r0, [sp], #16                           ; Restore old R0 on success to not confuse client, junk R1-R3
        Pull    "pc", VC                                ; Match found so return
DoGlobalLookup
        LDR     r0, GlobalMessageFile_block
        BL      TranslateFindDescriptor
        Debug   xx,"Global file :", r0

        Pull    "lr"                                    ; pull caller's R0 into lr (to junk it or re-stack it)
        CMP     r0, #0                                  ; Clears V - was the global descriptor zero?
        Pull    "r1-r3"
        BEQ     NoGlobalMessageFile                     ; What an unlikely thing (requires return address on stack only)

        ; only got lr left stacked now
        Push    "lr"                                    ; re-stack caller's R0.  We've kept it safe now.
        BL      internal_lookup
        STRVS   r0, [sp]                                ; replace caller's R0 with an error block
        Pull    "r0,pc"                                 ; return

internal_lookup Entry "r0-r10"

        Debug   xx,"MessageTrans_Lookup",r0,r1,r2,r3,r4,r5
        DebugS  xx,"Token =",r1

        MOV     r9, r1                                  ; Pointer to the token for error insertion
        BL      EnsureFileIsOpen
        BVS     %FT80

        LDR     r1, [r0, #fcb_flags]
        AND     r8, r1, #flg_hashing :OR: flg_worth_hashing :OR: flg_defer_hash_creation
        TST     r8, #flg_defer_hash_creation            ; Create this time?  Clear flag for next time around
        BICNE   r1, r1, #flg_defer_hash_creation
        STRNE   r1, [r0, #fcb_flags]        
        TEQ     r8, #flg_worth_hashing
        BLEQ    HashTableAlloc
        LDR     r1, [r0, #fcb_flags]
        BICVS   r1, r1, #flg_worth_hashing :OR: flg_hashing :OR: flg_defer_hash_creation
        STRVS   r1, [r0, #fcb_flags]
        TST     r1, #flg_hashing
    [ keepstats
        ; We can only do stats when hashing as that's the only guaranteed case of having 32 byte block
        LDRNE   r8, [r0, #fcb_use_count]
        ADDNE   r8, r8, #1
        STRNE   r8, [r0, #fcb_use_count]
    ]
        LDRNE   r8, [r0, #fcb_hash]
        TEQNE   r8, #0
        BEQ     findtoken                               ; no hash table, behave as before

        DebugS   hash, "Looking up in hash table : ",r9

        Push    "r2,r3,r8"
        MOV     r1, r9                                  ; token we are searching for
        MOV     r2, r9
        MOV     r3, #0                                  ; length of the token
71      BL      get_R0_R1
        ADDHI   r3, r3, #1
        BHI     %BT71
        BL      AllocHashR2R3toR1
        Debug   hash, "Hash value",r1
        CMP     r1, #NumBuckets
        Pull    "r2,r3,r8",EQ
        BEQ     findtoken                               ; wildcarded :-(   We don't do those
        MOV     r7, r1                                  ; remember which hash chain for later
        LDR     r2, [r8, r7, LSL #2]!                   ; retrieve address of first hash entry
        LDR     r10, [r8, #4]                           ; get terminator
        Debug   hash, "Hash chain at address",r2
72
        MOV     r1, r9
        CMP     r2, r10                                 ; finished this list?
        BEQ     %FT78                                   ; done
        LDR     r3, [r2], #4                            ; get next hash entry
        Debug   hash, "Next hash address", r3
73
        BL      get_R0_R1
        BLS     %FT76                                   ; terminator?  this could be it!
        BL      getbyte
        BVS     %BT72                                   ; error? next!
       ;CMP     r8, #"*"                                ; wildcard?
       ;BEQ     %FT77
        CMP     r8, #":"                                ; if followed by ":", skip to end of line
        CMPNE   r8, #"/"                                ; also stop if reached end of token
        CMPNE   r8, #&1f
        BLS     %BT72                                   ; try next entry
        CMP     r8, #"?"
        CMPNE   r8, r0
        BEQ     %BT73
        B       %BT72

76      BL      getbyte
        BVS     %BT72                                   ; no
        CMP     r8, #":"                                ; token must be followed by ":"
        CMPNE   r8, #"/"                                ; "/" or newline => alternatives
        CMPNE   r8, #&1f
        BHI     %BT72
77
        LDR     r2, [sp], #12                           ; restore r2, trash stacked r3 & r8
        B       %FT31                                   ; we got it!

78
        Debug   hash, "Need to look down wildcard chain if r7 != 00000040.  r7 is", r7
        TEQ     r7, #NumBuckets                         ; which chain have we just searched?
        MOVNE   r7, #NumBuckets                         ; so we know next time we've tried the wildcard chain
        LDRNE   r8, [sp, #8]                            ; get hash table header pointer back
        ADDNE   r8, r8, #NumBuckets*4                   ; point at wildcard chain header
        LDMNEIA r8, {r2,r10}                            ; load wildcard chain head and terminator words
        TEQNE   r2, r10                                 ; quick pre-check to see if chain is empty
        BNE     %BT72                                   ; try wildcard chain if it's not empty
        LDR     r2, [sp], #12                           ; already tried wildcard token list, restore R2, trash r3,r8
        CMP     r0, #&100                               ; LO if we don't have the proper error message yet (R0 is a char)
        BHS     %FT98                                   ; give up with existing error block
80
        MOV     r4, r3                                  ; fake the EOF condition for getbyte
        BL      getbyte                                 ; get and translate the error message
        B       %FT98                                   ; and give up

; search each line of the file in turn, looking for <token>:

findtoken
        MOV     r1, r9                                  ; R1 -> token

02      BL      get_R0_R1                               ; LS => terminator
        BLS     %FT03

        BL      getbyte
        BVS     %FT98

        CMP     r8, #"#"                                ; ignore comment lines completely
        BEQ     skipline

        CMP     r8, #":"                                ; if followed by ":", skip to end of line
        CMPNE   r8, #"/"                                ; also stop if reached end of token
        CMPNE   r8, #&1f
        BLS     skiptokens

        CMP     r8, #"?"                                ; wildcard
        CMPNE   r0, r8
        BEQ     %BT02

; skip to next token on line, or skip line if no more tokens

skiptokens
        BL      skiptonexttoken
        BVC     findtoken

skipline
        BLVC    skiptonextline
        BVC     findtoken

; if error, see if there was a default value after the token

98
        MOVS    r3, r8                                  ; R3 -> start of default value (or 0 if there wasn't any)
        BEQ     %FT99
        Debug   intr,"default found in string"
        MOV     r4, r3                                  ; R3 -> start of default value
53      LDRB    r14, [ r4 ], #1
        CMP     r14, #10
        CMPNE   r14, #13
        CMPNE   r14, #0
        BNE     %BT53
        MOV     r1, r4                                  ; update R1
        DebugS  intr,"default is ", r3
        B       dosubstit                               ; and do parameter substitution

99
        STRVS   r0, [ sp, #0 ]
        EXIT

; reached end of token - matched if next char is ":", "/" or linefeed

03
        BL      getbyte
        BVS     %BT98
        CMP     r8, #":"                                ; token must be followed by ":"
        CMPNE   r8, #"/"                                ; "/" or newline => alternatives
        CMPNE   r8, #&1f
        BHI     skiptokens

31      CMP     r8, #":"                                ; skip to ":", where message is
        BEQ     %FT32
        BL      getbyte
        BVC     %BT31
        B       %BT98
32

; found token - read the rest of the line into the output buffer
; r1 -> one after terminator of token supplied

dosubstit

        SUB     r1, r1, #1                              ; return R1 -> token terminator
        STR     r1, stk_token

        ASSERT  :INDEX: stk_token = 4
        ASSERT  :INDEX: stk_buffer = 8
        ASSERT  :INDEX: stk_buffersize = 12

        LDMIB   sp, { r0-r1, r5 }                       ; R5 = counter
        CMP     r1, #0                                  ; if no buffer supplied,
        BNE     decode_string                           ; return a pointer to the string
        STR     r3, stk_buffer
33      BL      getbyte
        BVS     %BT99
        CMP     r8, #&1b
        ADDEQ   r3, r3, #1
        CMP     r8, #10
        CMPNE   r8,#13
        CMPNE   r8,#0
        BNE     %BT33

        SUB     r3, r3, #1                              ; R3 -> terminator
        LDR     r14, stk_buffer
        SUB     r3, r3, r14
        STR     r3, stk_buffersize
        B       %BT99

decode_string

        ;amg: don't call MessageTrans_Dictionary - just set R9=0 to indicate that
        ;     we don't have the value yet

        MOV     r9, #0
;        BL      SWIMessageTrans_Dictionary
;        MOV     r9, r0                                  ; R9 points to kernel dictionary

04      BL      getbyte
        BVS     %BT99
        CMP     r8, #"%"
        BEQ     %FT05
        CMP     r8, #&1b
        BEQ     expand_tok
41      CMP     r8, #10                                 ; stop on linefeed
        CMPNE   r8, #0
        CMPNE   r8, #13
        SUBNES  r5, r5, #1
        MOVEQ   r8, #0                                  ; terminate with 0
        STRB    r8, [ r1 ], #1
        BNE     %BT04
42
        LDR     r14, stk_buffer
        SUB     r14, r1, r14                            ; R14 = length of string
        SUB     r14, r14, #1                            ; excluding terminator
        STR     r14, stk_buffersize
        B       %BT99

; just read "%" - if next character is "0", expand parameter

05      BL      getbyte                                 ; R8 = "0" or "1" (hopefully)
        BVS     %BT99
        SUB     r14, r8, #"0"
        CMP     r14, #4                                 ; parameters 0..3 allowed
        BLO     %FT06
        CMP     r14, #"%"-"0"
        SUBNE   r3, r3, #1                              ; "%%" => "%", else "%x" => "%x"
51      MOV     r8, #"%"
        B       %BT41

; expand parameter into output buffer

06
        ADR     r0, stk_parameter0
        LDR     r0, [ r0, r14, LSL #2 ]                 ; R0 -> parameter
        CMP     r0, #0                                  ; if none, don't substitute
        SUBEQ   r3, r3, #1
        BEQ     %BT51
07      LDRB    r14, [ r0 ], #1
        CMP     r14, #0                                 ; stop on 0
        CMPNE   r14, #10                                ; or linefeed
        CMPNE   r14, #13                                ; or carriage return
        SUBNES  r5, r5, #1
        STRNEB  r14, [ r1 ], #1
        BNE     %BT07
        CMP     r5, #0                                  ; if buffer not full,
        BNE     %BT04                                   ; continue
        MOV     r14, #0                                 ; terminate with 0
        STRB    r14, [ r1 ], #1
        B       %BT42                                   ; else stop now

expand_tok
        LDR     r6, stk_parameter0
        BL      getbyte
        BL      expand_tok1
        CMP     r5, #0                                  ; any space left?
        BGT     %BT04
        B       %BT42

expand_tok1
        STMDB   sp!, {r0, lr}

        ;amg : ok, I give up. We need to make the call to SWIMessageTrans_Dictionary if
        ;      we've not done it already. Moving it to here ensure that it doesn't get
        ;      called when there's no need to call it.
    [ HashDictionary :LAND: {TRUE}
        ADDS    r0, r9, #0                              ; clear V
        BLEQ    SWIMessageTrans_Dictionary
        LDMVSIA sp!, {r0, pc}                           ; didn't find it?
        MOV     r9, r0                                  ; R9 points to kernel dictionary

explp   SUBS    r8, r8, #1                              ; dictionary entries are 1-255; 0 means use R6 string
        ADRCS   r14, DictionaryHash
        LDRCS   r0, [r14, r8, LSL #2]                   ; check hash table entry
        TEQCS   r0, #0                                  ; was it zero (no entry found) ? (must leave C set)
        LDMEQIA sp!, {r0, pc}                           ; exit if so (if R8 was 0 on entry, Z will be clear)
        SUBCCS  r0, r6, #1                              ; R8 was zero, so get R6-1 into R0.  Clear C if R6 was 0
        LDMCCIA sp!, {r0, pc}
    |
        MOVS    r0, r9
        BLEQ    SWIMessageTrans_Dictionary
        MOVEQ   r9, r0                                  ; R9 points to kernel dictionary

explp   SUBS    r8, r8, #1
        LDRHIB  r14, [r0]
        ADDHI   r0, r0, r14
        BHI     explp
        SUBCCS  r0, r6, #1
        LDMCCIA sp!, {r0, pc}
    ]
explp1  LDRB    r8, [r0, #1]!
        CMP     r8, #0
        LDMEQIA sp!, {r0, pc}
        CMP     r8, #&1b
        BEQ     explp2
        SUBS    r5, r5, #1
        MOVLE   r8, #0
        STRB    r8, [r1], #1
        LDMLEIA sp!, {r0, pc}
        B       explp1
explp2
        LDRB    r8, [r0, #1]!
        BL      expand_tok1
        CMP     r5, #0
        BNE     explp1
        LDMIA   sp!, {r0, pc}

NoGlobalMessageFile
        XError  TokenNotFound
        Pull    "pc"

ErrorBlock_TokenNotFound
        DCD     ErrorNumber_MessageTrans_TokenNotFound
        DCB     "TokNFnd", 0
        ALIGN

;...............................................................................

; In    r3 -> next byte in message file
;       r4 -> end-of-file
; Out   r8 = last char read, r3 -> next possible token
;       "Message token not found" error if read past EOF

        ; This version, of the same routines, is considerably faster.
        ; It's important to optimise these routines because when searching
        ; for a token, we spend a great deal of time here skipping over
        ; blank lines.
        ; The following two loops are almost identical - one looks for
        ; newline, the other for newline-or-slash.

skiptonexttoken
        CMP     r8, #"/"
        CMPNE   r8, #&1f
        BLS     skiptonextline4
        CMP     r8, #":"
        LDRB    r8, [r3], #1
        BNE     skiptonexttoken

skiptonextline
        CMP     r8, #&20
        BCC     skiptonextline3
skiptonextline0
        TST     r3, #3
        LDRNEB  r8, [r3], #1
        BNE     skiptonextline
        LDRB    r8, [r3], #1
        B       skiptonextline
skiptonextline1
        LDR     r8, [r3], #4
        CMP     r8, #&20000000
        BIC     r8, r8, #&ff000000
        CMPCS   r8, #&200000
        BIC     r8, r8, #&ff0000
        CMPCS   r8, #&2000
        BIC     r8, r8, #&ff00
        CMPCS   r8, #&20
        BCS     skiptonextline1
        SUB     r3, r3, #3
skiptonextline2
        CMP     r8, #&20
        LDRCSB  r8, [r3], #1
        BCS     skiptonextline2
skiptonextline3
        CMP     r8, #&1b          ; Skip over ESC <token>
        ADDEQ   r3, r3, #1        ; Must never have ESC <EOF>!
        CMPNE   r8, #9            ; Tabs allowed in messages
        CMPNE   r8, #31           ; Also hard space
        BEQ     skiptonextline0
skiptonextline4
        CMP     r3, r4
        BCS     getbyte
        CLRV
        MOV     pc, lr

;...............................................................................
; In    R3 -> next byte in message file
;       R4 -> end-of-file
;       R9 -> pointer to the token we are trying to find (for the error message)
; Out   R3 updated
;       R8 = next byte if not EOF
;       If read past EOF, V is set, R0 points to "Message token not found" error
;       and R8 points to the string after the ':' in the token, or is 0 if none.

getbyte                                                 ; This version does not push LR in the normal non-end-of-file case.
        CMP     r3, r4                                  ; Check we are within the file
        LDRLOB  r8, [ r3 ], #1                          ; Yes, so read the byte
 [ No32bitCode
        BICLOS  pc, lr, #VFlag                          ; Then return with V clear
 |
        MSRLO   CPSR_f, #0                              ; V clear, maintains LO condition
        MOVLO   pc, lr
 ]
        Push    "lr"                                    ; It's an error, get the error message
        ADR     r0, ErrorBlock_TokenNotFound
        ;       R9 is the token to be inserted into the error message
        ;       If a ":" follows the token then don't insert the token
        ;       in the error message.
        DebugS  intr,"Saved token is ",r9
        MOV     r8, r9                                  ; Copy the token pointer
01
        LDRB    r14, [ r8 ], #1
        CMP     r14, #" "                               ; Check for terminating condition
        BLT     %FT02
        CMP     r14, #":"                               ; Check for a ":"
        BNE     %BT01                                   ; Keep scanning if neither happened
        Debug   intr,": in token return"
        SETV
        Pull    "pc"

02
        Debug   intr,"no : in token"
        Push    "r1-r7"                                 ; Return frame is now R1-R7, PC
        LDR     r1, MessageFile_block                   ; Either 0 or the block address
        MOV     r2, #0                                  ; No supplied buffer
        MOV     r3, #0
        MOV     r4, r9                                  ; The token to insert as %0
        MOV     r5, #0                                  ; No more supplied parameters
        MOV     r6, #0
        MOV     r7, #0
        BL      SWIMessageTrans_ErrorLookup
        [       debugintr
        ADD     r1, r0, #4
        DebugS  intr, "getbyte: error lookup returned", r1
        ]
        MOV     r8, #0
        Pull    "r1-r7, pc"


; -----------------------------------------------------------------------------
; SWI MessageTrans_CloseFile
; In    R0 -> 4-word data structure passed to MessageTrans_OpenFile

SWIMessageTrans_CloseFile Entry "r0-r3"

    [ debugswi
        ADD     sp, sp, #4*4                            ; discard saved registers
        Debug   swi,"IN:  MessageTrans_CloseFile",r0
        BL      %FT55
        DebugE  swi,"ERR: MessageTrans_CloseFile"
        Debug   swi,"OUT: MessageTrans_CloseFile",r0
        Pull    "pc"
55
        ALTENTRY
    ]

        BL      TranslateFindDescriptor
        TEQ     r0, #0
        BEQ     %FT99
        ADR     r11, link_header - fcb_link
    [ debugstats
        LDR     r2, [ r0, #fcb_flags ]
        TST     r2, #flg_hashing
        BEQ     %F09
        LDR     r1, [ r0, #fcb_filename ]
        LDR     r2, [ r0, #fcb_use_count ]
        DebugS  stats, "MessageTrans file closed", r1
        Debug   stats, "Use count", r2
09
    ]
        BL      HashTableDelete                         ; delete hash table (if any)
CloseFileLoop
        LDR     r1, [ r11, #fcb_link ]
        CMP     r1, #0                                  ; clear V
        BEQ     %FT20                                   ; not on chain of allocated blocks
        TEQ     r1, r0
        MOVNE   r11, r1
        BNE     CloseFileLoop

        LDR     r14, [ r0, #fcb_link ]                  ; delete block from chain
        STR     r14, [ r11, #fcb_link ]

        BL      CloseFileFreeData
20
        LDR     r1, stk_filedesc                        ; get original client block (may = R0 though)
        LDR     r0, [r1]                                ; get client flags
        TST     r0, #flg_proxy:OR:flg_new_api           ; originally opened with R2 non-zero and old API?
        EXIT    EQ                                      ; leave descriptor alone so badly behaved programs can still do lookups
        MOV     r3, #0
        STR     r3, [ r1, #fcb_clnt_magic ]             ; blat the magic word
        STR     r3, [ r1, #fcb_clnt_flags ]             ; blat the flags
        STR     r3, [ r1, #fcb_real_block ]             ; blat the proxy pointer/data pointer

        EXIT
99
        Pull    "r0-r3, lr"
        B       err_invaliddescriptor

; Subroutine for MessageTrans_CloseFile and module Die
;
; In  r0 -> file descriptor
; Out r0-r3 corrupt (or V set and r0 is error)
CloseFileFreeData Entry
        LDR     r14, [ r0, #fcb_flags ]
        LDR     r3, [ r0, #fcb_fileptr ]
        TST     r14, #flg_ourbuffer
        MOVEQ   r3, #0                                  ; ensure R3 is set correctly to avoid later test
        TST     r14, #flg_freeblock
        BEQ     %FT20

    [ ChocolateProxies
        Push    "r3"
        ADR     r2, ProxyMemory
        SUBS    r2, r0, r2
        RSBCSS  r1, r2, #ProxyMemorySize
        LDRCS   r1, ProxyAlloc
        MOVCS   r2, r2, LSR #5
        MOVCS   r3, #1
        ORRCS   r1, r1, r3, LSL r2
        STRCS   r1, ProxyAlloc
        MOVCC   r2, r0
        MOVCC   r0, #ModHandReason_Free
        SWICC   XOS_Module
        Pull    "r3"
    |
        MOVNE   r2, r0
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
    ]
20
        ADDS    r2, r3, #0                              ; clears V and sets/clears Z appropriately
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module

        EXIT

; -----------------------------------------------------------------------------

; SWI MessageTrans_MakeMenus
; In    R0 -> 4-word data structure passed to MessageTrans_OpenFile
;       R1 -> menu definition (see below)
;       R2 -> RAM buffer to hold menu structure
;       R3 = size of RAM buffer
; Out   [R1..] = menu data
;       R2 -> end of menu structure
;       R3 = bytes remaining in buffer (should be 0 if you got it right)
;       "Buffer overflow" error if buffer is too small

SWIMessageTrans_MakeMenus Entry "r1, r4-r11"

    [ debugswi
        ADD     sp, sp, #9*4                            ; discard saved registers
        Debug   swi,"IN:  MessageTrans_MakeMenus", r0, r1, r2, r3
        BL      %FT55
        DebugE  swi,"ERR: MessageTrans_MakeMenus"
        Debug   swi,"OUT: MessageTrans_MakeMenus", r0, r1, r2, r3
        Pull    "pc"
55
        ALTENTRY
    ]

        Debug   xx,"MessageTrans_MakeMenus", r0, r1, r2, r3

        BL      TranslateFindDescriptor

loop1   LDRB    r14, [ r1 ]                             ; reached end if title token null
        TEQ     r14, #0
        EXIT    EQ

        CMP     r3, #m_headersize
        BLT     menuerr_buffoverflow

        MOV     r9, r2                                  ; R9 -> start of this menu

        MOV     r4, r3
        BL      int_lookup_nopars                       ; R4-R7 set to 0 automatically
        EXIT    VS

        ADD     r2, r2, #m_ti_fg_colour                 ; R2 -> next bit
        SUB     r8, r3, #3                              ; R8 = current max width (-3 for borders)

        ADD     r1, r1, #1                              ; skip token terminator

        LDRB    r14, [ r1 ], #1                         ; title fg
        STRB    r14, [ r2 ], #1
        LDRB    r14, [ r1 ], #1                         ; title bg
        STRB    r14, [ r2 ], #1
        LDRB    r14, [ r1 ], #1                         ; work fg
        STRB    r14, [ r2 ], #1
        LDRB    r14, [ r1 ], #1                         ; work bg
        STRB    r14, [ r2 ], #1 + 4                     ; (skip item width for now)
        ASSERT  m_itemheight = m_itemwidth + 4
        LDRB    r14, [ r1 ], #1                         ; height of items
        STR     r14, [ r2 ], #4
        LDRB    r14, [ r1 ], #1                         ; gap between items
        STR     r14, [ r2 ], #4
        ASSERT  m_headersize = m_ti_fg_colour + 16

        SUB     r3, r4, #m_headersize                   ; R3 = space left in buffer

loop2   CMP     r3, #mi_size
        BLT     menuerr_buffoverflow

        Push    "r1"
        BL      skiptoken                               ; R1 -> byte after token
        ADD     r1, r1, #3
        BIC     r6, r1, #3                              ; word-align (use R6 for later)
        Pull    "r1"

        LDMIA   r6!, { r5, r10, r11 }                   ; R5 = item flags for this item
                                                        ; R10 = submenu offset
                                                        ; R11 = icon flags
        Push    "r2, r3"
        TST     r5, #mi_it_writeable                    ; if writeable and indirected,
        TSTNE   r11, #if_indirected                     ; icon data set up already
        LDRNE   r3, [ r2, #mi_icondata + 8 ]            ; R3 = buffer size
        LDRNE   r2, [ r2, #mi_icondata + 0 ]            ; R2 -> buffer
        BNE     %FT01
        TST     r11, #if_indirected
        MOVEQ   r3, #12                                 ; 12 bytes allowed if direct
        ADDEQ   r2, r2, #mi_icondata
        MOVNE   r2, #0                                  ; else look up token in place
01      BL      int_lookup_nopars
        MOV     r4, r2                                  ; R4 -> text string
        MOV     r7, r3                                  ; R7 = text length
        Pull    "r2,r3"
        EXIT    VS

        MOV     r1, r6                                  ; R1 -> input data

        CMP     r10, #0
        ADDNE   r10, r9, r10                            ; make submenu pointer absolute

        STMIA   r2!, { r5, r10, r11 }                   ; itemflags, submenu, iconflags

        ADD     r2, r2, #12                             ; skip icondata

        TST     r11, #if_indirected                     ; done if not indirected
        BEQ     %FT02

        TST     r5, #mi_it_writeable
        STREQ   r4, [ r2, #-12 ]                        ; text string
        MOVEQ   r14, #0
        STREQ   r14, [ r2, #-8 ]                        ; no validation string
        ADDEQ   r14, r7, #1
        STREQ   r14, [ r2, #-4 ]                        ; length (with terminator)

02      CMP     r7, r8
        MOVGT   r8, r7

        TST     r5, #mi_it_lastitem
        BEQ     loop2

        MOV     r8, r8, LSL #4                          ; multiply by 16
        ADD     r8, r8, #12                             ; and add 12
        STR     r8, [ r9, #m_itemwidth ]                ; fill this in last

        B       loop1                                   ; continue until null token found

        EXIT

menuerr_buffoverflow
        BL      err_buffoverflow
        EXIT


err_buffoverflow
        ADR     r0, ErrorBlock_BuffOverflow
        Push    "r1, r2, lr"
        MOV     r1, #0                                  ; Force the global case
        MOV     r2, #0
        BL      SWIMessageTrans_ErrorLookup
        Pull    "r1, r2, pc"

ErrorBlock_BuffOverflow
        DCD     ErrorNumber_CDATBufferOverflow
        DCB     "BufOFlo", 0
        ALIGN

;......................................................................................

; In    r1 -> start of token
; Out   r1 -> byte after end of token

skiptoken Entry

01      LDRB    r14, [ r1 ], #1                         ; skip the token
        CMP     r14, #","
        CMPNE   r14, #")"
        CMPNE   r14, #32
        BHI     %BT01

        EXIT

;......................................................................................

; int_lookup_nopars: lookup with no parameters
; In    R0 -> 4-word data structure passed to MessageTrans_LoadFile
;       R1 -> token, terminated by <=32, "," or ")"
;       R2 -> buffer to hold result (0 => don't copy it)
;       R3 = buffer size (if R2 non-0)
; Out   R1 -> token terminator
;       R2 -> terminator (character 10 if R2=0 on entry, 0 otherwise)
;       R3 = size of result, excluding terminator

int_lookup_nopars Entry "r4-r7"

        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        BL      SWIMessageTrans_Lookup

        EXIT

DictionaryFileName       DCB     "Resources:$.Resources.Kernel.Dictionary", 0
        ALIGN

    [ HashDictionary
        ; Returns address of first byte of dictionary in R0 if V clear; error if V set
SWIMessageTrans_Dictionary Entry   "r0-r3"

    [ debugswi
        ADD     sp, sp, #4*4                            ; discard saved registers
        Debug   swi,"IN:  MessageTrans_Dictionary"
        BL      %FT55
        DebugE  swi,"ERR: MessageTrans_Dictionary"
        Debug   swi,"OUT: MessageTrans_Dictionary",r0
        Pull    "pc"
55
        ALTENTRY
    ]

        LDR     r2, Dictionary
        CMP     r2, #0
        ADREQ   r1, DictionaryFileName
        BLEQ    internal_fileinfo
        ADDVC   r0, r2, #4
        STR     r0, [sp]
        EXIT    VS
        LDR     r1, Dictionary
        STR     r2, Dictionary
        TEQ     r1, r2
        EXIT    EQ
        ADR     r3, DictionaryHash
        MOV     r1, #0
dichashloop
        LDRB    r2, [r0]              ; read length byte of R1'th entry
        TEQ     r2, #0                ; end of list?
        STRNE   r0, [r3, r1, LSR #22] ; store hash entry
        STREQ   r2, [r3, r1, LSR #22] ; store zero
        ADDNE   r0, r0, r2
        ADDS    r1, r1, #1 :SHL: 24
        BNE     dichashloop
        EXIT
    |
SWIMessageTrans_Dictionary
        STMDB   sp!, {r1, r2, r3, lr}
        LDR     r2, Dictionary
        CMP     r2, #0
        ADREQ   r1, DictionaryFileName
        BLEQ    internal_fileinfo
        MOVVC   r0, r2
        STRVC   r0, Dictionary
        ADDVC   r0, r0, #4
        LDMIA   sp!, {r1, r2, r3, pc}
    ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Hashing routines
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; The hash tables are pretty simple.  There are 64 main buckets plus a special
; bucket for tokens containing wildcards.  The data structure allocated from the
; RMA has the following structure (specified in C for clarity only)

; struct {
;   struct {
;     char **list;
;   } buckets[64 + 1 + 1];    /* buckets + wildcards + terminator */
;   char *token[number_of_tokens_in_file];
; } hashtable;

; Each entry in hashtable.token is a direct pointer into the messages file.

; hashtable.buckets[n].list points to the first entry in hashtable.token for a
; token which has a hash value of n.  All subsequent entries have the same hash
; value up to but excluding the entry to which hashtable.buckets[n+1].list
; points.  All the entries in buckets[].list are valid.  Empty buckets are
; signified by buckets[n+1].list having the same value as buckets[n].list.  The
; wildcard bucket (hashtable.buckets[64].list) works in the same way -
; terminating bucket #63 and marking the first entry in the wildcard bucket (ie
; bucket #64).   The terminator word (hashtable.buckets[65].list) is used as
; the terminator for bucket #64 only.

; sizeof(hashtable) will always be 264 + (4 * tokens).

; AllocHashR2R3toR1 generates the bucket number (0-63) for a normal token, or
; 64 for a wildcarded token.  Thus to lookup a token, calculate the hash value
; and search the appropriate bucket, then if not found, search the wildcard
; bucket, then if not found fail the lookup.  Unfortunately, you cannot do
; anything but a sequential file search if the client asks to lookup something
; with a wildcard in it - but this should be extremely rare.

NumBuckets      *       64                              ; MUST be a power of two
        ASSERT (NumBuckets * 4) <= Buffersize           ; must fit in a _kernel_oserror

HashTableDelete Entry "r0-r3"
        ; Delete the hash table in the descriptor pointed to by R0
        ; Preserves all registers; corrupts all flags.
        ; Must not write pointer unless we were hashing in case it was a
        ; small non-proxied descriptor.
        Debug   hash, "HashTableDelete", r0
        LDR     r2, [r0, #fcb_flags]                    ; check flags
        TST     r2, #flg_hashing                        ; hashing enabled?
        EXIT    EQ                                      ; no - don't touch hash pointer
        MOV     r1, #0
        BIC     r2, r2, #flg_hashing                    ; clear hash enable
        STR     r2, [r0, #fcb_flags]                    ; store flags
        LDR     r2, [r0, #fcb_hash]                     ; find location of table
        STR     r1, [r0, #fcb_hash]                     ; mark unused whatever
        TEQ     r2, #0                                  ; got a hash table?
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module                              ; release hash table
        EXIT

HashTableAlloc Entry "r0-r11"
        ; Allocate space in the hash table.  R0 is our internal descriptor.
        ; Preserves all registers.  Corrupts NZC, V clear if OK, V set on error
        BL      HashTableDelete
        LDR     r1, [r0, #fcb_flags]
        TST     r1, #flg_worth_hashing                  ; worth the effort and space in descriptor?
        BIC     r1, r1, #flg_hashing :OR: flg_worth_hashing
        STR     r1, [r0, #fcb_flags]
        EXIT    EQ
        Debug   hash, "HashTableAlloc - constructing hash table"

        MOV     r2, #-1                                 ; get a foreground buffer
        BL      AllocateInternalBuffer                  ; abuse of internal buffers - but pretty safe
        MOV     r8, r2                                  ; for safekeeping - a temporary buffer for the tokens
        MOV     r9, r3                                  ; ditto
        MOV     r2, #-1                                 ; get a foreground buffer
        BL      AllocateInternalBuffer                  ; actually need a couple of them :-)
        MOV     r6, r2                                  ; for safekeeping - this one holds the counters
        MOV     r7, #0                                  ; number of wildcard tags
        MOV     r11, #0                                 ; total number of tags
        MOV     r4, #NumBuckets                         ; index for enumeration - will be zero at end of 10 loop
10      SUBS    r4, r4, #1
        STR     r7, [r6, r4, LSL #2]
        BNE     %BT10
        ; ASSERT r4 contains 0 here
20
        ADRL    r1, StarToken                           ; we want everything
        MOV     r2, r8                                  ; Set buffer
        MOV     r3, r9                                  ; size of buffer
        Push    "r11"
        BL      SWIMessageTrans_EnumerateTokens         ; get next token
        Pull    "r11"
        BVS     %FT90
        TEQ     r2, #0                                  ; done?
        BEQ     %FT30                                   ; completed the enumeration
        ADD     r11, r11, #1                            ; inc total
        BL      AllocHashR2R3toR1                       ; hash R2[0..R3] into R1
        CMP     r1, #NumBuckets                         ; Got a wildcard?
        ADDEQ   r7, r7, #1                              ; yes - increment wildcard bucket counter
        LDRNE   r2, [r6, r1, LSL #2]                    ; no - increment counter for bucket
        ADDNE   r2, r2, #1
        STRNE   r2, [r6, r1, LSL #2]
        B       %BT20
30
        Debug   hash, "Tokens in file",r11
        CMP     r11, #MinimumTokenCount                 ; enough tokens to be worthwhile? Instruction also clears V
        LDRLO   r11, [r0, #fcb_flags]
        BICLO   r11, r11, #flg_worth_hashing            ; not worth the effort - don't bother in future
        STRLO   r11, [r0, #fcb_flags]
        EXIT    LO
        ADD     r3, r11, #NumBuckets+2                  ; tag count + one per bucket + wildcard bucket + final terminator
        MOV     r3, r3, LSL #2                          ; convert to bytes
        Debug   hash, "Claiming memory", r3
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module                              ; let's go!
        EXIT    VS
        LDR     r0, [sp, #0*4]                          ; get descriptor back into R0 back again
        STR     r2, [r0, #fcb_hash]                     ; store the hash table memory
        MOV     r4, #0                                  ; ready the index for enumeration again
40      SUBS    r3, r3, #4
        STR     r4, [r2, r3]
        BNE     %BT40
        ADD     r1, r2, #(NumBuckets+2)*4               ; skip the bucket pointers and final terminator to find chain mem
        ; ASSERT r3 and r4 contain 0 here
50      LDR     r0, [r6, r3, LSL #2]                    ; get r3'th entry from counter table
        Debug   hashalloc, "Bucket,Entries",r3,r0
        STR     r1, [r2, r3, LSL #2]                    ; write head pointer
        ADD     r1, r1, r0, LSL #2                      ; add number of entries
        ADD     r3, r3, #1                              ; increment r3
        TEQ     r3, #NumBuckets                         ; done?
        BNE     %BT50
        MOV     r11, r2                                 ; remember where the head pointer table is
        STR     r1, [r2, r3, LSL #2]!                   ; store final header pointer (for wildcard token chain)
        ADD     r1, r1, r7, LSL #2                      ; number of wildcard chain entries
        STR     r1, [r2, #4]                            ; store final terminator
        LDR     r0, [sp, #0*4]                          ; retrieve entry R0 - our internal descriptor
        LDR     r7, [r0, #fcb_fileptr]                  ; guaranteed valid!
        ADD     r7, r7, #4                              ; skip over the file size field
60      ADD     r6, r7, r4                              ; remember where we were at the moment
        ADR     r1, StarToken
        MOV     r2, r8
        MOV     r3, r9
        Push    "r11"
        BL      SWIMessageTrans_EnumerateTokens         ; we know what to do now
        Pull    "r11"
        BVS     %FT80
        CMP     r2, #0                                  ; clears V!
        BEQ     %FT70
        BL      HashAdvanceToRealToken                  ; updates R6 if necessary
        BL      AllocHashR2R3toR1
        Debug   hashalloc, "Storing in bucket",r1
        LDR     r1, [r11, r1, LSL #2]                   ; get the pointer
65      LDR     r2, [r1], #4                            ; look for a space in the table
        TEQ     r2, #0
        BNE     %BT65
        DebugS  hashalloc, "Storing token", r6
        STR     r6, [r1, #-4]!                          ; store in table
        B       %BT60                                   ; next!
70      LDR     r0, [sp, #0*4]                          ; retrieve client descriptor
        LDR     r1, [r0, #fcb_flags]                    ; mark the hash table valid
        ORR     r1, r1, #flg_hashing :OR: flg_worth_hashing
        STR     r1, [r0, #fcb_flags]
        Debug   hash, "HashTableAlloc exiting having set up the hash table"
        ; V must be clear - the only branch from above ensures this is the case
        EXIT

80      ; avoid leaking the hash table memory - cannot use HashTableDelete - flg_hashing isn't set yet
        LDR     r0, [sp, #0*4]                          ; get descriptor back into R0 back again
        LDR     r2, [r0, #fcb_hash]                     ; store the hash table memory
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
90
        Debug   hash,"ERROR returned by MessageTrans_EnumerateTokens"

        CLRV
        EXIT


StarToken
        DCB     "*", 0
        ALIGN

        ROUT

HashAdvanceToRealToken Entry "r0,r8"
        ; R2 is the buffer into which the token has been copied
        ; R4 points to EOF or to the byte following this token's value
        ; R6 is a pointer into the messages file at or after which the token lives
        ; Routine updates R6 if it didn't actually point to the token pointed to by R2
        LDRB    r0, [r2]                ; what we were given
10      LDRB    r8, [r6]
        TEQ     r0, r8
        TEQNE   r8, #"?"
       ;TEQNE   r8, #"*"
        EXIT    EQ                      ; Found the token OK.
        ADD     r6, r6, #1
        CMP     r6, r4                  ; EOF or past token value?  Cannot possibly happen? Something is
        EXIT    EQ                      ; terribly wrong if this safety valve is used - paranoia?
        CMP     r8, #"#"                ; comment to end of line?
        BNE     %BT10
20
        CMP     r8, #&20
25      LDRCSB  r8, [r6], #1
        BCS     %BT20
30
        CMP     r8, #27
        ADDEQ   r6, r6, #1
        CMPNE   r8, #9
        CMPNE   r8, #31
        BNE     %BT10                   ; don't like this character - treat as end of comment
        LDRB    r8, [r6], #1
        B       %BT20

        ROUT

AllocHashR2R3toR1 Entry "r0,r2-r4"
        ; Generates the hash of the token at address R2 length R3 into R1
        ; R1 is NumBuckets if the symbol contains wildcards, else in the
        ; range 0 to (NumBuckets-1)
        MOV     r1, #0
10      LDRB    r4, [r2], #1
        TEQ     r4, #"?"
       ;TEQNE   r4, #"*"
        MOVEQ   r1, #NumBuckets
        EXIT    EQ
        SUBS    r3, r3, #1
        EORPL   r1, r4, r1, ROR #1
        BPL     %BT10
        EOR     r1, r1, r1, LSR #30
        EOR     r1, r1, r1, LSR #24
        EOR     r1, r1, r1, LSR #12
        EOR     r1, r1, r1, LSR #6
        AND     r1, r1, #(NumBuckets-1)
        EXIT

AllocateInternalBuffer Entry "r8"
        ; Allocate one of MessageTrans's internal buffers from IRQ or foreground pools
        ; depending on the kernel's IRQsema flag.  Returns buffer in R2, length in R3
        ; Used when client does not supply a buffer to *Lookup and in HashTableAlloc
        ; If R2=0 on entry, the IRQsema is checked
        ; If R2=-1 on entry, a foreground buffer is used
        ; R2 anything else will not work
        ; On exit: R2 points to buffer, R3 is buffer size
        MVNS    r3, r2                                  ; R3=0, Z set => force foreground pool
        LDRNE   r3, ptr_IRQsema
        LDRNE   r3, [r3]                                ; If R3<>0 now, R2 must have been 0
        TEQNE   r3, #0                                  ; Z set => force foreground pool
        ADR     r2, ForegroundBuffers
        ADDNE   r2, r2, #Buffersize*ForegroundBuffersNo
        LDREQB  r14, current_ForegroundBuffer
        LDRNEB  r14, current_IRQBuffer
        ADD     r2, r2, r14, LSL #8                     ; Point at correct buffer to use
        ADD     r14, r14, #1
        MOVEQ   r8, #ForegroundBuffersNo
        MOVNE   r8, #IRQBuffersNo
        CMP     r14, r8
        MOVGE   r14, #0
        TEQ     r3, #0
        STREQB  r14, current_ForegroundBuffer
        STRNEB  r14, current_IRQBuffer                  ; And set new buffer number.
        MOV     r3, #Buffersize
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Debugging routines
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      [ debug
        InsertNDRDebugRoutines
      ]

        END
