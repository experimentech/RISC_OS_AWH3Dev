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

        TTL     The Podule manager.
        SUBT    SWI interfaces => Podule.s.Interface

; ***********************************
; ***    C h a n g e   L i s t    ***
; ***********************************

; Date       Name  Description
; ----       ----  -----------
; 08-Oct-87  BC    Fixed Error return from ReadBytes & WriteBytes
; 21-Apr-88  BC    Changed Syntax messages
; 11-May-88  BC    Made Loaders live in the same block as wp
; 12-May-88  BC    Protected Enumerations etc. against Simple Podules
; 09-Sep-88  SKS   Reversioned after changing NewErrors
; 20-Apr-90  BC    Loaders now load at a word address
; 08-Jan-91  TMD   Made SWIs only update V flag not other flags
;                  Started changes for extension ROMs
; 21-Mar-91  OSS   Internationalised, and added SWI Podule_ReturnNumber
; 17-Apr-91  OSS   Bug fixes to internationalisation (R1 corruption)
; 19-Apr-91  TMD   Fixed bug in LoadAllLoaders - needed AddressOfPrivateWord
;                   setting up, otherwise corrupted location zero (or worse)
; 16-Oct-91  TMD   Fixed bug G-RO-9079 (*PoduleSave/PoduleLoad with no
;                   loader gives exception)
; 14-Oct-92  TMD   Split off Victoria-specific version
; 25-Mar-95  JRH   changed  dline, dreg etc calls to DLINE, DREG since tutu is dead
; 11-Jan-00  PMS   Converted to work with objasm so we can pass options in from MakeFile
; 12-Jan-00  PMS   Added fake podule header for EtherI for Customer F Ethernet NC
; 29-Aug-02  RPS   Uses the values deduced at run time to decide what to allow

        OPT     OptPage

SWIEntry ROUT
  [ :LNOT: No32bitCode
        Push    "lr"
        BL      SWIEntry2
        TEQ     pc, pc
        Pull    "pc", EQ
        Pull    "pc", VC, ^
        Pull    "lr"
        ORRS    pc, lr, #V_bit

SWIEntry2
  ]
        LDR     wp, [ r12 ]
        CMP     r11, #( EndOfJumpTable - JumpTable ) / 4
        ADDCC   pc, pc, r11, LSL #2
        B       UnknownSWI

JumpTable
        B       ReadID                          ; 40280
        B       ReadHeader                      ; 40281
        B       EnumerateChunks                 ; 40282
        B       ReadChunk                       ; 40283
        B       ReadBytes                       ; 40284
        B       WriteBytes                      ; 40285
        B       CallLoader                      ; 40286
        B       RawRead                         ; 40287
        B       RawWrite                        ; 40288
        B       HardwareAddress                 ; 40289
        B       EnumerateChunksWithInfo         ; 4028A
        B       HardwareAddresses               ; 4028B
        B       ReturnNumber                    ; 4028C
        B       ReadInfo                        ; 4028D
        B       SetSpeed                        ; 4028E

EndOfJumpTable

        ASSERT  (EndOfJumpTable - JumpTable) / 4 = PoduleSWICheckValue - Podule_ReadID

UnknownSWI
        Push    "r1, lr"
        ADRL    Error, ErrorBlock_ModuleBadSWI
        ADR     r1, ModuleTitle
        BL      copy_error_one                  ; will set V
        Pull    "r1, pc"

SWINameTable
ModuleTitle ; Share the string
        =       "Podule", 0
        =       "ReadID", 0
        =       "ReadHeader", 0
        =       "EnumerateChunks", 0
        =       "ReadChunk", 0
        =       "ReadBytes", 0
        =       "WriteBytes", 0
        =       "CallLoader", 0
        =       "RawRead", 0
        =       "RawWrite", 0
        =       "HardwareAddress", 0
        =       "EnumerateChunksWithInfo", 0
        =       "HardwareAddresses", 0
        =       "ReturnNumber", 0
        =       "ReadInfo", 0
        =       "SetSpeed", 0
        =       0
        ALIGN

; ****************************************************************************
;
;       ReadID - Reads a podule's identity byte
;
; in:   R3 = podule number
;
; out:  R0 = podule ID byte
;

ReadID  Push    "r1-r3, lr"
        BL      ConvertR3ToPoduleNode
        BLVC    ResetLoader
        Pull    "r1-r3, pc"

; ****************************************************************************
;
;       ReadHeader - Reads a podule's header
;
; in:   R2 -> buffer to write to, 8 or 16 bytes
;       R3 = some unique podule identifier
;
;  Trashes R10, R11

ReadHeader ROUT
        Push    "r0-r4, lr"
        BL      ConvertR3ToPoduleNode
        BLVC    ResetLoader
        BLVC    OnlyExtended
        BVS     ExitReadHeader
        MOV     r11, r1                                 ; r11 = hardware address
        ADD     r4, wp, r3                              ; Address of node record
        LDRB    r1, [ r4, #PoduleNode_Flags ]
        TST     r1, #BitOne                             ; Is this ROM in EASI space?
        MOVNE   r1, #1<<31                              ; Flag as read from EASI space
        MOVEQ   r1, #0                                  ; No, so read from Podule space
        MOV     r2, #8                                  ; read 8 bytes to start
        LDR     r10, [ sp, #8 ]                         ; reload pointer to core
        BL      ReadDevice
        BVS     ExitReadHeader
        LDRB    r14, [ r10, #4 ]                        ; High byte of type
  [  DebugInterface
        BREG    r14, "ReadHeader finds the type is &", cc
  ]
        STRB    r14, [ r4, #PoduleNode_Type + 1 ]       ; And store it away
        LDRB    r14, [ r10, #3 ]                        ; Low byte of type
  [  DebugInterface
        BREG    r14, ""
  ]
        STRB    r14, [ r4, #PoduleNode_Type ]           ; And store it away
        LDRB    r14, [ r10, #1 ]                        ; read low byte of status
        TST     r14, #2_00000011                        ; if interrupt pointers or chunk directory
        ADDNE   r1, r1, #8                              ; then read another 8 bytes from address 8
        ADDNE   r10, r10, #8                            ; to buffer+8
        BLNE    ReadDevice
ExitReadHeader
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r4, pc"

; ****************************************************************************
;
;       EnumerateChunks - Reads information about a chunk from the chunk directory
;
; in:   R0 = chunk number (zero to start)
;       R3 = podule number
;
; out:  R0 = next chunk number (zero for end)
;       R1 = size in bytes
;       R2 = type byte
;       R4 -> a copy of module name if an RM else preserved
;

EnumerateChunks ROUT
        Push    "r7, lr"
        MOV     r7, #0                                          ; Indicate EnumerateChunks, not EnumerateChunksWithInfo
        BL      DoEnumerate
        Pull    "r7, pc"


; ****************************************************************************
;
;       EnumerateChunksWithInfo - Reads information (including help string + ROM address)
;                                 about a chunk from the chunk directory
;
; in:   R0 = chunk number (zero to start)
;       R3 = podule number
;
; out:  R0 = next chunk number (zero for end)
;       R1 = size in bytes
;       R2 = type byte
;       R4 -> a copy of module name if an RM else preserved
;       R5 -> a copy of help string if an RM else preserved
;       R6 = address of module if a directly executable RM, otherwise 0
;

EnumerateChunksWithInfo ROUT
        Push    "r7, lr"
        MOV     r7, #1                                          ; Indicate EnumerateChunksWithInfo, not EnumerateChunks
        BL      DoEnumerate
        Pull    "r7, pc"

; ****************************************************************************

DoEnumerate ROUT
        ;       Internal routine common to EnumerateChunks and EnumerateChunksWithInfo
        ;       Flags on entry as provided by user, and only affects V on exit
        Push    "r0-r3, lr"
  [  DebugInterface
        BREG    r0, "Enumerating chunk &", cc
        DREG    r3, " from 'podule' &"
  ]
        BL      ConvertR3ToPoduleNode
        BLVC    OnlyExtended
        LDRVC   r0, [ sp, #0 ]                                  ; which segment to get
  [  DebugInterface
        BVS     %43
        DREG    r0, "Getting segment header &"
43
  ]
        BLVC    GetSegmentHeader
  [  DebugInterface
        BVC     %56
        ADD     r14, r0, #4
        DSTRING r14, "GetSegmentHeader returns the error "
56
  ]
        BVS     ExitEnumerate
        LDR     r2, [ r10, #0 ]                                 ; OS ID byte + (size << 8)
        ANDS    r0, r2, #&FF                                    ; if at end (ID=0) then set chunk number back to 0 and exit
  [  DebugInterface
        BREG    r0, "OS id = &"
  ]
        STREQ   r0, [ sp, #0 ]                                  ; store 0 in exit R0
        BEQ     ExitEnumerate
        STR     r0, [ sp, #8 ]                                  ; OS ID byte, exit R2
        MOV     r2, r2, LSR #8                                  ; get size
        STR     r2, [ sp, #4 ]                                  ; poked into the stack for exit purposes
        LDR     r1, [ r10, #4 ]                                 ; offset of segment
  [  DebugInterface
        DREG    r2, "Length  = &"
        DREG    r1, "Offset  = &"
        ADD     r14, r11, r1, LSL #2
        DREG    r14, "Address = &"
  ]
        TEQ     r0, #OSType_Loader
        BNE     CheckForDescription
  [ DebugInterface
        DREG    r1, "Found a loader at &"
  ]
        ADD     r14, r3, #PoduleNode_LoaderOffset
        LDR     r14, [ wp, r14 ]
        CMP     r14, #-1
        ADDNE   r14, wp, r14
        BNE     IncrementAndExit                                ; Loader already loaded
        TEQ     r2, #0
        BEQ     IncrementAndExit                                ; Loader is of zero length

; OSS We are about to extend (ie. MOVE) the workspace. MessageTrans remembers
; the address of our message_file_block in the workspace. This address may
; change, so we had better close the message file if it is open. It will
; get re-opened on demand the next time it is needed.

        BL      close_message_file                              ; close message file, and mark it closed
        BVS     ExitEnumerate

        Push    "r1, r3"
        ADD     r3, r2, #3                                      ; round up size to a word
        BIC     r3, r3, #3
        MOV     r2, wp
        MOV     r0, #ModHandReason_ExtendBlock
        SWI     XOS_Module                                      ; => address in R2
 [ DebugInterface
        DREG    wp, "Old workspace = &"
        DREG    r2, "New workspace = &"
 ]
        MOVVC   wp, r2                                          ; update my idea of my workspace
        LDRVC   r1, AddressOfMyPrivateWord
        STRVC   wp, [r1]                                        ; update the MOS's idea of my workspace
        Pull    "r1, r3"
        BVS     ExitEnumerate

        MOV     r0, #0
        SWI     XOS_SynchroniseCodeAreas
        CLRV

 [ DebugInterface
        DLINE   "Loading the loader"
 ]
        LDR     r14, OffsetOfNextLoader
        ADD     r10, wp, r14                                    ; calculate the start address of this segment

        LDR     r2, [ sp, #4 ]                                  ; size
        ADD     r14, r2, r14                                    ; calculate the next start
        ADD     r14, r14, #3                                    ; round up to a word boundary
        BIC     r14, r14, #3                                    ; in case someone has a non-word size loader
        STR     r14, OffsetOfNextLoader
 [ DebugInterface
        DREG    r11, "Base of podule = &"
        DREG    r1, "Address of segment = &"
        DREG    r10, "Address of core = &"
        DREG    r2, "Size of core area = &"
 ]
        BL      ReadDevice
        BVS     ExitEnumerate
        ADD     r3, wp, r3                                      ; make into an address
        SUB     r14, r10, wp                                    ; Compute offset of loader
        STR     r14, [ r3, #PoduleNode_LoaderOffset ]           ; Store the offset of the Loader

        MOV     r14, #0
        MRS     r14, CPSR                                       ; NOP pre ARMv3, hence skips the 32OK check
        TST     r14, #2_11100
        BEQ     %FT59

; if we're on a 32-bit system, we need to make sure that the loader is 32-bit compatible.
; if it isn't we sneakily redirect to our dummy loader that says "not 32-bit compatible" for
; all entries.
        LDR     r14, [r10, #16]                                 ; 5th word should be magic value '32OK'
        LDR     r0, MagicWord32bit
        TEQ     r0, r14
        LDRNE   r14, =:INDEX: Not32bitLoader
        STRNE   r14, [ r3, #PoduleNode_LoaderOffset ]
        ADDNE   r10, wp, r14
59
        MOV     r0, #0                                          ; just loaded some code,
        SWI     XOS_SynchroniseCodeAreas                        ; so synchronise everything
        CLRV

; now do a dummy read from location 0 in pseudo-space (it's promised that we do this)

        MOV     r1, #0                                          ; address to read
        LDR     r11, [ r3, #PoduleNode_CombinedAddress ]        ; hardware+CMOS, or ROM address
 [ DebugInterface
        DREG    r11, "Calling loader with combined address = &"
 ]
        MOV     lr, pc
        ADD     pc, r10, #0                                     ; call read entry
 [ DebugInterface
        BVC     %62
        ADD     r0, r0, #4
        DSTRING r0, "Loader returns error: "
        SUB     r0, r0, #4
        B       %69
62
        DLINE   "Loader returns without error"
69
 ]
        CLRV                    ;BC and RCM put this in to fix MED-04273
                                ; we don't care if the dummy read failed, as we are only
                                ; enumerating Podule type.
        B       IncrementAndExit

MagicWord32bit
        =       "32OK"

; Check next special type

CheckForDescription
        TEQ     r0, #DeviceType_Description
        BNE     CheckForModule
 [ DebugInterface
        DREG    r1, "Description found at &"
 ]
        ADD     r14, r3, #PoduleNode_DescriptionOffset
        LDR     r14, [ wp, r14 ]
        TEQ     r14, #0
        ADDNE   r14, wp, r14
        BNE     IncrementAndExit                                ; Description is already loaded
        TEQ     r2, #0
        BEQ     IncrementAndExit                                ; Description is of zero length

; OSS We are about to extend (ie. MOVE) the workspace. MessageTrans remembers
; the address of our message_file_block in the workspace. This address may
; change, so we had better close the message file if it is open. It will
; get re-opened on demand the next time it is needed.

        BL      close_message_file              ; close message file, and mark it closed
        BVS     ExitEnumerate

        Push    "r1, r3"
        ADD     r3, r2, #3                                      ; round up size to a word
        BIC     r3, r3, #3
        MOV     r2, wp
        MOV     r0, #ModHandReason_ExtendBlock
        SWI     XOS_Module                                      ; => address in R2
 [ DebugInterface
        DREG    wp, "Old workspace = &"
        DREG    r2, "New workspace = &"
 ]
        MOVVC   wp, r2                                          ; update my idea of my workspace
        LDRVC   r1, AddressOfMyPrivateWord
        STRVC   wp, [ r1 ]                                      ; update the MOS's idea of my workspace
        Pull    "r1, r3"
        BVS     ExitEnumerate
 [ DebugInterface
        DLINE   "Loading the description"
 ]

        MOV     r0, #0
        SWI     XOS_SynchroniseCodeAreas
        CLRV

        LDR     r14, OffsetOfNextLoader
        ADD     r10, r3, #PoduleNode_DescriptionOffset
        STR     r14, [ wp, r10 ]                                ; store away the offset
        ADD     r10, wp, r14                                    ; calculate the start address of this segment
        LDR     r2, [ sp, #4 ]                                  ; size
        ADD     r14, r2, r14                                    ; calculate the next start
        ADD     r14, r14, #3                                    ; round up to a word boundary
        BIC     r14, r14, #3                                    ; in case someone has a non-word size description
        STR     r14, OffsetOfNextLoader
 [ DebugInterface
        DREG    r11, "Base of podule = &"
        DREG    r1, "Address of segment = &"
        DREG    r10, "Address of core = &"
        DREG    r2, "Size of core area = &"
 ]
        BL      ReadDevice
        BVS     ExitEnumerate
  [  DebugInterface
        DSTRING r10, "Description is: "
  ]
        B       IncrementAndExit

CheckForModule
        TEQ     r0, #OSType_Module
        BNE     IncrementAndExit
 [ DebugInterface
        DREG    r1, "Module found at &"
 ]
        MOV     r0, r2                                          ; save size for later
        MOV     r2, #Module_TitleStr                            ; offset for entry to read
        ADRL    r10, RMName                                     ; buffer to put it
        BL      GetModuleInfo
        BVS     ExitEnumerate
  [  DebugInterface
        DSTRING r10, "Module title is: "
  ]
        MOV     r4, r10                                         ; return pointer to name

        CMP     r7, #0                                          ; return help string etc?
        BEQ     IncrementAndExit                                ; no, then skip

        MOV     r2, #Module_HelpStr                             ; offset for entry to read
        ADRL    r10, RMHelp                                     ; buffer to put it
        BL      GetModuleInfo
        BVS     ExitEnumerate
  [  DebugInterface
        DSTRING r10, "Module help string is: "
  ]
        MOV     r5, r10                                         ; return pointer to name

; now work out whether ROM is directly executable

        ADD     r14, wp, r3
        LDR     r6, [ r14, #PoduleNode_WordOffset ]             ; read word offset
        TEQ     r6, #4                                          ; if 4 then it's a directly executable extension ROM
        TSTEQ   r1, #&80000000                                  ; but pseudo part is assumed not directly executable
        LDREQ   r6, [ r14, #PoduleNode_ROMAddress ]             ; load ROM address
        ADDEQ   r6, r6, r1                                      ; and add on offset to module (NB it must be one-to-one
                                                                ; mapping because the ROM is directly executable!)
        MOVNE   r6, #0                                          ; else return 0

IncrementAndExit
        LDR     r0, [ sp, #0 ]                                  ; get entry chunk number
        ADD     r0, r0, #1                                      ; move onto next chunk
80
        STR     r0, [ sp, #0 ]                                  ; store in exit register frame
ExitEnumerate
        STRVS   r0, [ sp, #0 ]                                  ; Shove error pointer into stack
  [  DebugInterface
        Pull    "r0"
        DREG    r0, "Enumerate returns R0=&"
        BVS     %92
        DLINE   "V is Clear"
        B       %93
92
        DLINE   "V is Set"
93
        Pull    "r1-r3, pc"
  |
        Pull    "r0-r3, pc"
  ]

GetModuleInfo   ROUT
        Push    "r1, lr"
        ADD     r1, r1, r2                                      ; read the offset for this entry
        MOV     r2, #4                                          ; read one word's worth
        BL      ReadDevice
        BVS     ExitGetModuleInfo
        LDR     r1, [ sp, #0 ]                                  ; reload pointer to start of module
        LDR     r2, [ r10 ]                                     ; The offset value just read
        [       DebugModule
        DREG    r2, "Offset is &"
        ]
        TEQ     r2, #0                                          ; if offset to value is zero (ie no string)
        BEQ     ExitGetModuleInfo                               ; then exit with V=0 and with a zero byte (in fact a word) at R10
        ADD     r1, r2, r1                                      ; address of title or help string
        SUB     r14, r0, r2                                     ; maximum read from module title start
        MOV     r2, #InfoBufLength - 1                          ; size of buffer
        CMP     r14, r2
        MOVLO   r2, r14                                         ; use the smaller of the two, assume size is OK wrt total size
        BL      ReadDevice
        MOVVC   r14, #0                                         ; terminate name if longer than buffer
        STRVCB  r14, [ r10, #InfoBufLength - 1 ]
ExitGetModuleInfo
        Pull    "r1, pc"

        NOP
        NOP

; ****************************************************************************
;
;       ReadChunk - Reads a chunk from a podule
;
; in:   R0 = chunk number
;       R2 -> buffer to write to, assumed big enough
;       R3 = podule number
;

ReadChunk ROUT
        Push    "r0-r3, lr"
        BL      ConvertR3ToPoduleNode
        BLVC    OnlyExtended
        LDRVC   r0, [ sp, #0 ]                                  ; which segment to get
        BLVC    GetSegmentHeader
        BVS     ExitReadChunk
        ADR     r10, SegmentHeader
        LDR     r2, [ r10, #0 ]                                 ; OS ID byte + (size << 8)
        TST     r2, #&FF                                        ; are we at the end
        BEQ     ExitBadChunk
        LDR     r1, [ r10, #4 ]                                 ; offset, includes bits for which space
        MOV     r2, r2, LSR #8                                  ; get size
        LDR     r10, [ sp, #8 ]                                 ; the old R2 the core pointer
        BL      ReadDevice
ExitReadChunk
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r3, pc"

ExitBadChunk
        ADRL    r0, ErrorBlock_BadChnk
        BL      copy_error_zero                                 ; Always sets the V bit
        B       ExitReadChunk


; ****************************************************************************
;
;       ReadBytes - Reads bytes from within a podule's code space
;
; in:   R0 = psuedo address
;       R1 = count in bytes
;       R2 -> buffer to write to
;       R3 = podule number
;
;       Trashes R10 and R11
;

ReadBytes ROUT
        Push    "r0-r3, lr"
        BL      ConvertR3ToPoduleNode
        BLVC    OnlyExtended
        MOVVC   r11, r1
        LDMVCIA sp, { r1, r2, r10 }                     ; load pseudo address, byte count, address
        BICVC   r1, r1, #BitThirtyOne + BitThirty
        ORRVC   r1, r1, #BitThirty                      ; Force the use of the loader
        BLVC    ReadDevice
  [  DebugInterface
        BVC     %56
        ADD     r14, r0, #4
        DSTRING r14, "ReadDevice returns the error "
56
  ]
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r3, pc"

; ****************************************************************************
;
;       WriteBytes - Writes bytes to within a podule's code space
;
; in:   R0 = psuedo address
;       R1 = count in bytes
;       R2 -> buffer to read from
;       R3 = podule number
;
;       Trashes R10 and R11
;

WriteBytes Entry "r0-r3"
        BL      ConvertR3ToPoduleNode
        BLVC    OnlyExtended
        MOVVC   r11, r1
        LDRVC   r1, [ sp, #0*4 ]                        ; load pseudo address
        BICVC   r1, r1, #BitThirtyOne + BitThirty
        ORRVC   r1, r1, #BitThirty                      ; Force the use of the loader
        LDRVC   r2, [ sp, #1*4 ]                        ; load byte count
        LDRVC   r10, [ sp, #2*4 ]                       ; load buffer address
        BLVC    WriteDevice
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r3, pc"

; ****************************************************************************
;
;       CallLoader - Calls a podule's loader
;
; in:   R0-R2 = user data
;       R3 = podule number, or base address
;
; out:  R0-R2, NZCV as returned by loader
;
;       Trashes R10 and R11
;

CallLoader ROUT
        Push    "r0-r3, lr"
        BL      ConvertR3ToPoduleNode
        BLVC    OnlyExtended
        BVS     ExitCallLoader
        ADD     r3, wp, r3                              ; make r3 -> podule node
        LDR     r10, [ r3, #PoduleNode_LoaderOffset ]
        CMP     r10, #-1
        BEQ     ExitNoLoader
        ADD     r10, wp, r10
        LDR     r11, [ r3, #PoduleNode_CombinedAddress ]
        LDMIA   sp, { r0-r2 }                           ; restore entry registers
        MOV     lr, pc                                  ; get the return link
        ADD     pc, r10, #12                            ; call the routine
        STMIA   sp, { r0-r2 }                           ; Ready for exit
        BVS     ProcessLoaderError
ExitCallLoader
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r3, pc"

ProcessLoaderError                                      ; V is clear on entry
        TEQ     r0, #0                                  ; Check for special case, we supply error message
        ADREQL  r0, ErrorBlock_InLdr
        BLEQ    copy_error_zero                         ; Always sets the V bit
        B       ExitCallLoader

ExitNoLoader
        ADRL    r0, ErrorBlock_NoLdr
        BL      copy_error_zero                         ; Always sets the V bit
        B       ExitCallLoader


; ****************************************************************************
;
;       RawRead - Reads bytes directly within a podule's address space
;
; in:   R0 = podule address (0..&3FFF)
;       R1 = count in bytes
;       R2 -> buffer to write to
;       R3 = podule number
;
;       Trashes R10 and R11
;

RawRead ROUT
        Push    "r0-r3, lr"
        BL      ConvertR3ToPoduleNode
        MOVVC   r11, r1
        LDRVC   r1, [ sp, #0*4 ]                        ; load address
        LDRVC   r2, [ sp, #1*4 ]                        ; load byte count
        LDRVC   r10, [ sp, #2*4 ]                       ; load buffer address
        BLVC    ReadDevice
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r3, pc"

; ****************************************************************************
;
;       RawWrite - Write bytes directly within a podule's address space
;
; in:   R0 = podule address (0..&3FFF)
;       R1 = count in bytes
;       R2 -> buffer to read from
;       R3 = podule number
;
;       Trashes R10 and R11
;

RawWrite ROUT
        Push    "r0-r3, lr"
        BL      ConvertR3ToPoduleNode
        MOVVC   r11, r1
        LDRVC   r1, [ sp, #0*4 ]                        ; load address
        LDRVC   r2, [ sp, #1*4 ]                        ; load byte count
        LDRVC   r10, [ sp, #2*4 ]                       ; load buffer address
        BLVC    WriteDevice
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r3, pc"

; ****************************************************************************
;
;       HardwareAddress - Returns a podule's combined hardware and CMOS address
;                         (or extension ROM node address in the case of an extension ROM)
;
; in:   R3 = podule number or partial hardware address
;
; out:  R3 = combined hardware address
;

HardwareAddress ROUT
        Push    "r0-r2, lr"
        BL      ConvertR3ToPoduleNode
        ADDVC   r3, wp, r3                              ; Address of node record
        LDRVC   r3, [ r3, #PoduleNode_CombinedAddress ]
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r2, pc"

; ****************************************************************************
;
;       HardwareAddresses - Returns a podule's raw and combined hardware addresses
;
; in:   R3 = podule number or partial hardware address
;
; out:  R0 = raw hardware address
;       R1 = combined hardware address
;

HardwareAddresses ROUT
        Push    "r2, r3, lr"
        BL      ConvertR3ToPoduleNode
        ADDVC   r3, wp, r3
        LDRVC   r0, [ r3, #PoduleNode_BaseAddress ]
        LDRVC   r1, [ r3, #PoduleNode_CombinedAddress ]
        Pull    "r2, r3, pc"

; ****************************************************************************
;
;       ReturnNumber - return the number of Podules and Extension ROMs
;
; in:   Nothing
;
; out:  R0 = number of Podules
;       R1 = number of Extension ROMs
;
; The number of Podules is determined by which IOMD we have
; The number of Extension ROMs was worked out at initialisation in
; FindExtensionROMs().

ReturnNumber ROUT
        LDR     r0, Capabilities
        LDR     r0, [r0, #Capability_PodCount]
        [       ExtensionROMs
        LDR     r1, NumberOfExtROMs
        |
        MOV     r1, #0
        ]
        MOV     pc, lr


; ****************************************************************************
;
;       ReadInfo - return various words about Podules and Extension ROMs
;
;       On entry
;         R0  Bitset of required results
;         R1  Pointer to buffer to receive word aligned word results
;         R2  Length in bytes of buffer
;         R3  Any recognisable part of podule addressing;
;             e.g.  Podule number
;                   Base address
;                   CMOS address
;                   New base address
;
;       On exit
;         R0  Preserved
;         R1  Preserved, a pointer to results in order (lowest bit number
;             at the lowest address)
;         R2  Length of results
;         R3  Preserved
;
;       Bitset in R0, values;
;
;         Bit  0 ==> Podule/Extension ROM number
;         Bit  1 ==> Normal (syncronous) base address
;         Bit  2 ==> CMOS address
;         Bit  3 ==> CMOS size in bytes
;         Bit  4 ==> Extension ROM base address
;         Bit  5 ==> Podule ID
;         Bit  6 ==> Podule product type
;         Bit  7 ==> Combined hardware address
;         Bit  8 ==> Pointer to description
;         Bit  9 ==> Logical address of EASI space
;         Bit 10 ==> Size of the EASI space in bytes
;         Bit 11 ==> Logical number of the primary DMA channel
;         Bit 12 ==> Logical number of the secondary DMA channel
;         Bit 13 ==> Address of Interrupt Status Register
;         Bit 14 ==> Address of Interrupt Request Register
;         Bit 15 ==> Address of Interrupt Mask Register
;         Bit 16 ==> Interrupt Mask value
;         Bit 17 ==> Device Vector number (for IRQ)
;         Bit 18 ==> Address of FIQ as Interrupt Status Register
;         Bit 19 ==> Address of FIQ as Interrupt Request Register
;         Bit 20 ==> Address of FIQ as Interrupt Mask Register
;         Bit 21 ==> FIQ as Interrupt Mask value
;         Bit 22 ==> Device Vector number (for FIQ as IRQ)
;         Bit 23 ==> Address of Fast Interrupt Status Register
;         Bit 24 ==> Address of Fast Interrupt Request Register
;         Bit 25 ==> Address of Fast Interrupt Mask Register
;         Bit 26 ==> Fast Interrupt Mask value
;         Bit 27 ==> Ethernet address (low 32 bits)
;         Bit 28 ==> Ethernet address (high 16 bits)
;         Bit 29 ==> MEMC space

ReadInfo ROUT
        Push    "r0-r5, lr"
        BL      ConvertR3ToPoduleNode
        BVS     ExitReadInfo
        LDMIA   sp, { r0, r1, r10 }                     ; Entry values of R0, R1 & R2
        ADD     r3, wp, r3
        MOV     r4, r2                                  ; Podule number
        MOV     r5, #0                                  ; Number of bytes used so far
        MOV     r11, #-1                                ; Initialise the bit counter
ReadInfoLoop
        BVS     ExitReadInfo
        INC     r11
        TEQ     r11, #(ReadInfoTableEnd-ReadInfoTable)/4
        BEQ     TestRemainingBits
        ;       R0  = Bitset of things to do
        ;       R1  = Pointer to the word to write to
        ;       R3  = Pointer to the podule_node
        ;       R4  = Podule number
        ;       R5  = Number of bytes used so far
        ;       R10 = Size of the buffer in bytes
        ;       R11 = The number we are up to 0, 1, 2, 3, 4 ...

        MOV     r14, #1
        ANDS    r14, r0, r14, LSL r11
        BEQ     ReadInfoLoop
        INC     r5, 4
        CMP     r5, r10
        BGT     ReadTooMuchInfo
  [  DebugInterface
        DREG    r1, "Calling with a data pointer of &"
  ]
        CLRV
        JumpAddress lr, ReadInfoTableEnd, Forward
        ADD     pc, pc, r11, LSL #2
        NOP
ReadInfoTable
        MOV     pc, lr                                  ; ReadInfo_PoduleNumber
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_SyncBase
        B       ReadInfo_BaseAddress
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_CMOSAddress
        B       ReadInfo_CMOSAddress
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_CMOSSize
        B       ReadInfo_CMOSSize
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_ROMAddress
        B       ReadInfo_ROMAddress
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_ID
        B       ReadInfo_ID
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_Type
        B       ReadInfo_Type
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_CombinedAddress
        B       ReadInfo_Combined
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_Description
        B       ReadInfo_DescriptionZero
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_EASILogical
        B       ReadInfo_EASIAddress
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_EASISize
        B       ReadInfo_EASISize
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_DMAPrimary
        B       ReadInfo_DMAPrimary
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_DMASecondary
        B       ReadInfo_DMASecondary
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_IntStatus
        B       ReadInfo_IntStatus
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_IntRequest
        B       ReadInfo_IntRequest
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_IntMask
        B       ReadInfo_IntMask
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_IntValue
        B       ReadInfo_IntValue
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_IntDeviceVector
        B       ReadInfo_IntDeviceVector
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_FIQasIntStatus
        B       ReadInfo_FIQasIntStatus
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_FIQasIntRequest
        B       ReadInfo_FIQasIntRequest
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_FIQasIntMask
        B       ReadInfo_FIQasIntMask
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_FIQasIntValue
        B       ReadInfo_FIQasIntValue
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_FIQasIntDeviceVector
        B       ReadInfo_FIQasIntDeviceVector
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_FIQStatus
        B       ReadInfo_FIQStatus
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_FIQRequest
        B       ReadInfo_FIQRequest
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_FIQMask
        B       ReadInfo_FIQMask
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_FIQValue
        B       ReadInfo_FIQValue
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_EthernetAddressLow
        B       ReadInfo_EthernetLow
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_EthernetAddressHigh
        B       ReadInfo_EthernetHigh
        ASSERT  (1 :SHL: ((.-ReadInfoTable)/4)) = Podule_ReadInfo_MEMC
        B       ReadInfo_MEMCAddress

ReadInfoTableEnd
  [  DebugInterface
        BVS     %57
        DREG    r2, "Data returned is &"
        B       %58
57
        ADD     r14, r0, #4
        DSTRING r14, "Error from ReadInfo_<thing>: "
58
  ]
        STRVC   r2, [ r1 ], #4
        B       ReadInfoLoop


TestRemainingBits
  [  DebugInterface
        DREG    wp, "WP = &"
  ]
        MOVS    r0, r0, ASR r11
        STREQ   r5, [ sp, #8 ]                          ; Poke the exit value of R2
        BNE     UnexpectedBitsSet
ExitReadInfo
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r5, pc"

UnexpectedBitsSet
        ADRL    r0, ErrorBlock_BadRead
        B       ErrorExitReadInfo

ReadTooMuchInfo
        ADRL    r0, ErrorCDATBufferOverflow
ErrorExitReadInfo
  [  DebugInterface
        DREG    r0, "Error is at &"
  ]
        BL      copy_error_zero
        B       ExitReadInfo

        ;       Implementation of the various bits, return the value in R2

ReadInfo_BaseAddress
        LDR     r2, [ r3, #PoduleNode_BaseAddress ]
        MOV     pc, lr

ReadInfo_CMOSAddress
        LDR     r2, [ r3, #PoduleNode_CMOS ]
        MOV     pc, lr

ReadInfo_CMOSSize
        CMP     r2, #0                  ; don't have CMOS on extension ROM
        MOVLT   r2, #0                  ; we don't have no CMOS
        MOVGE   r2, #4                  ; otherwise fixed amount
        MOV     pc, lr

ReadInfo_ROMAddress
        LDR     r2, [ r3, #PoduleNode_ROMAddress ]
        MOV     pc, lr

ReadInfo_ID
        LDRB    r2, [ r3, #PoduleNode_IDByte ]
        MOV     pc, lr

ReadInfo_Type
        LDR     r2, [ r3, #PoduleNode_Type ]
        BIC     r2, r2, #&FF000000                      ; Clear out the top two bytes
        BIC     r2, r2, #&00FF0000                      ; Leaving only the valid 16 bits
        MOV     pc, lr

ReadInfo_Combined
        LDR     r2, [ r3, #PoduleNode_CombinedAddress ]
        MOV     pc, lr

ReadInfo_DescriptionZero
        ;       In:  R3 is a pointer to the PoduleNode
        ;       Out: R2 is a pointer to the Description if it exists
        ;       All other registers preserved
        LDR     r2, [ r3, #PoduleNode_DescriptionOffset ]
        TEQ     r2, #0
        ADDNE   r2, wp, r2                              ; The actual address of the string
        MOVNE   pc, lr
MightBeSimple
        Push    "r0, r1, r3, r4, r5, lr"
        DEC     sp, 8                                   ; Stack frame for token lookup
        MOV     r5, r3                                  ; Keep the address of the node
        LDRB    r0, [ r5, #PoduleNode_IDByte ]
        MOVS    r0, r0, LSR #3                          ; Move id to bottom bits
        BEQ     ExtendedPoduleFound
  [  DebugInterface
        BREG    r0, "Simple podule found: &"
  ]
        CMP     r0, #9
        ADDLS   r0, r0, #"0"
        ADDHI   r0, r0, #"A"-10                         ; Convert to single hex digit
        LDR     r14, =&706d6953                         ; "Simp"
        STR     r14, [ sp, #0 ]
        LDR     r14, =&0000656C                         ; "le" + CHR$0 + CHR$0
        ADD     r14, r14, r0, LSL #16                   ; Put digit between "e" and CHR$0
        STR     r14, [ sp, #4 ]
        ADD     r1, sp, #0                              ; Token is in the stack frame
  [  DebugModule
        DSTRING r1, "Lookingup token: "
  ]
        MOV     r4, #0                                  ; No %0
        BL      EasyLookup
  [  DebugModule
        BVC     %93
        ADD     r14, r0, #4
        DSTRING r14, "Error from EasyLookup: "
93
  ]
        BVC     DescriptionLookedUp
        ADR     r1, Token_PodSimp                       ; Set up MessageTrans token
        ADD     r4, sp, #6                              ; Address of the single digit
        B       DoEasyLookup

ExtendedPoduleFound
        LDR     r14, =&00747845                         ; "Ext" + CHR$0
        STR     r14, [ sp, #0 ]
        LDR     r0, [ r5, #PoduleNode_Type ]            ; Only 16 bits count
        ADD     r1, sp, #3
        MOV     r2, #5
        SWI     XOS_ConvertHex4
        BVS     ExitReadInfo_DescriptionZero
        ADD     r1, sp, #0                              ; Token is in the stack frame
  [  DebugModule
        DSTRING r1, "Lookingup token: "
  ]
        MOV     r4, #0                                  ; No %0
        BL      EasyLookup
  [  DebugModule
        BVC     %33
        ADD     r14, r0, #4
        DSTRING r14, "Error from EasyLookup: "
33
  ]
        BVC     DescriptionLookedUp
        ADR     r1, Token_PodExtd                       ; Set up MessageTrans token
        ADD     r4, sp, #3                              ; Address of the four digits
DoEasyLookup
  [  DebugModule
        DSTRING r1, "Lookingup token: "
  ]
        BL      EasyLookup
        BVS     ExitReadInfo_DescriptionZero
DescriptionLookedUp
  [  DebugModule
        DSTRING r2, "Description is: "
        DREG    r3, "Length is &"
  ]
        ADD     r3, r3, #3                              ; Round up
        BIC     r3, r3, #3                              ; To a word size
        BL      close_message_file                      ; Close message file, and mark it closed
        BVS     ExitReadInfo_DescriptionZero
        SUB     r5, r5, wp                              ; Change node address back to an offset
        MOV     r4, r2                                  ; Message buffer address
        MOV     r2, wp
        MOV     r0, #ModHandReason_ExtendBlock
        SWI     XOS_Module                              ; => address in R2
  [  DebugModule
        DREG    wp, "Old workspace = &"
        DREG    r2, "New workspace = &"
  ]
        MOVVC   wp, r2                                  ; update my idea of my workspace
        LDRVC   r1, AddressOfMyPrivateWord
        STRVC   wp, [ r1 ]                              ; update the MOS's idea of my workspace
        ADD     r5, wp, r5                              ; Change node offset back to an address
        BVS     ExitReadInfo_DescriptionZero

        MOV     r0, #0
        SWI     XOS_SynchroniseCodeAreas

        LDR     r3, OffsetOfNextLoader
        STR     r3, [ r5, #PoduleNode_DescriptionOffset ] ; store away the offset
        ADD     r3, r3, wp                              ; calculate the start address of this segment
        MOV     r2, r3                                  ; Exit value
ScanForTerminator
        LDRB    r0, [ r4 ], #1
        CMP     r0, #32                                 ; Look for the terminator
        MOVLT   r0, #0
        STRB    r0, [ r3 ], #1
        BGE     ScanForTerminator
        ADD     r3, r3, #3                              ; round up to a word boundary
        BIC     r3, r3, #3                              ; in case someone has a non-word size description
        SUB     r3, r3, wp                              ; Change back to an offset
        STR     r3, OffsetOfNextLoader

ExitReadInfo_DescriptionZero
        INC     sp, 8
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r1, r3, r4, r5, pc"

Token_PodSimp
        DCB     "PodSimp", 0
        ALIGN

Token_PodExtd
        DCB     "PodExtd", 0
        ALIGN

ReadInfo_EASIAddress
        [       EASISpace
        LDR     r2, [ r3, #PoduleNode_EASIAddress ]
        |
        MOV     r2, #0
        ]
        MOV     pc, lr

ReadInfo_EASISize
        [       EASISpace
        LDR     r2, [ r3, #PoduleNode_EASIAddress ]
        TEQ     r2, #0
        MOVNE   r2, #16*1024*1024       ; using EASI space, get a fixed amount
        |
        MOV     r2, #0
        ]
        MOV     pc, lr

ReadInfo_DMAPrimary
        LDR     r2, [ r3, #PoduleNode_DMA ]
        MOV     pc, lr

ReadInfo_DMASecondary
        MOV     r2, #-1
        MOV     pc, lr

ReadInfo_IntStatus
        LDR     r2, [ r3, #PoduleNode_IntStatus ]
        MOV     pc, lr

ReadInfo_IntRequest
        LDR     r2, [ r3, #PoduleNode_IntRequest ]
        MOV     pc, lr

ReadInfo_IntMask
        LDR     r2, [ r3, #PoduleNode_IntMask ]
        MOV     pc, lr

ReadInfo_IntValue
        LDRB    r2, [ r3, #PoduleNode_IntValue ]
        MOV     pc, lr

ReadInfo_IntDeviceVector
        LDR     r2, [ r3, #PoduleNode_IntDeviceVector ]
        MOV     pc, lr

ReadInfo_FIQasIntStatus
        LDR     r2, [ r3, #PoduleNode_FIQasIntStatus ]
        MOV     pc, lr

ReadInfo_FIQasIntRequest
        LDR     r2, [ r3, #PoduleNode_FIQasIntRequest ]
        MOV     pc, lr

ReadInfo_FIQasIntMask
        LDR     r2, [ r3, #PoduleNode_FIQasIntMask ]
        MOV     pc, lr

ReadInfo_FIQasIntValue
        LDRB    r2, [ r3, #PoduleNode_FIQasIntValue ]
        MOV     pc, lr

ReadInfo_FIQasIntDeviceVector
        LDR     r2, [ r3, #PoduleNode_FIQasIntDeviceVector ]
        MOV     pc, lr

ReadInfo_FIQStatus
        LDR     r2, [ r3, #PoduleNode_FIQStatus ]
        MOV     pc, lr

ReadInfo_FIQRequest
        LDR     r2, [ r3, #PoduleNode_FIQRequest ]
        MOV     pc, lr

ReadInfo_FIQMask
        LDR     r2, [ r3, #PoduleNode_FIQMask ]
        MOV     pc, lr

ReadInfo_FIQValue
        LDRB    r2, [ r3, #PoduleNode_FIQValue ]
        MOV     pc, lr

ReadInfo_EthernetLow
        Push    "r0-r1, lr"
        LDR     r0, Capabilities
        LDR     r1, [r0, #Capability_Features]
        TST     r1, #Capability_NIC
        MOVEQ   r1, #0                               ; there's no NIC support,only podule 0 can ask for a MAC address
        LDRNE   r1, [r0, #Capability_PodCount]       ; there is NIC support,so compare it with MaximumPodule-1
        SUBNE   r1, r1, #1
        CMP     r1, r4
        ADRNEL  r0, ErrorBlock_ECNoNet
        BLNE    copy_error_zero

        MOVVC   r0, #4
        SWIVC   XOS_ReadSysInfo
        BVS     ExitReadInfo_EthernetLow

        ORRS    lr, r0, r1                           ; MAC all zero is duff
        MOVNE   r2, r0
        ADREQL  r0, ErrorBlock_NDallas
        BLEQ    copy_error_zero
ExitReadInfo_EthernetLow
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r1, pc"

ReadInfo_EthernetHigh
        Push    "r0-r1, lr"
        LDR     r0, Capabilities
        LDR     r1, [r0, #Capability_Features]
        TST     r1, #Capability_NIC
        MOVEQ   r1, #0                               ; there's no NIC support,only podule 0 can ask for a MAC address
        LDRNE   r1, [r0, #Capability_PodCount]       ; there is NIC support,so compare it with MaximumPodule-1
        SUBNE   r1, r1, #1
        CMP     r1, r4
        ADRNEL  r0, ErrorBlock_ECNoNet
        BLNE    copy_error_zero

        MOVVC   r0, #4
        SWIVC   XOS_ReadSysInfo
        BVS     ExitReadInfo_EthernetHigh

        ORRS    lr, r0, r1                           ; MAC all zero is duff
        MOVNE   r2, r1
        ADREQL  r0, ErrorBlock_NDallas
        BLEQ    copy_error_zero
ExitReadInfo_EthernetHigh
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r1, pc"

ReadInfo_MEMCAddress
        LDR     r2, [ r3, #PoduleNode_MEMCAddress ]
        MOV     pc, lr

; ****************************************************************************
;
;       SetSpeed - Sets the access speed of podules in EASI space
;
;        On entry
;            R0  Enumerated type for the speed required.
;                R0 = 0    ==> No change
;                R0 = 1..8 ==> Timing type A..H
;            R3  Any recognisable part of podule addressing;
;
;        On exit
;            R0  Current speed setting
;            R1  Preserved
;            R2  Preserved
;            R3  Preserved

SetSpeed ROUT
        Push    "r0-r3, lr"
        BL      ConvertR3ToPoduleNode
        BVS     ExitSetSpeed

        LDR     r0, [ sp, #0 ]                          ; Reload entry value of R0
        LDR     r1, Capabilities
        LDR     r10, SSpaceStart
        ADD     pc, r1, #Capability_SpeedHelper

HelperIOMD1
        CMP     r0, #Podule_Speed_TypeD                 ; Check for the known range
        BHI     BadSpeed

        [       NetworkPodule
        ;       The network podule supports all four timing values.
        TEQ     r2, #NumberOfNetworkPodule
        BNE     %FT10                                   ; Might be EASI
        PHPSEI
        LDRB    r1, [ r10, #IOMD_IOTCR ]                ; Get current timing value
        AND     r2, r1, #3                              ; Mask, leaving only the network card timing
        ADD     r2, r2, #1                              ; Translate to external format
        STR     r2, [ sp, #0 ]                          ; Poke into exit frame
        SUBS    r0, r0, #1                              ; Test for zero and map to 0..3
        BICPL   r1, r1, #3                              ; Mask off the network card timing
        ORRPL   r1, r1, r0                              ; Add in the new timing value
        STRPLB  r1, [ r10, #IOMD_IOTCR ]                ; Set the new value
        PLP
        CLRV
        B       ExitSetSpeed
10
        ]
        [       EASISpace
        ;       EASI space only supports timings A and C.
        TEQ     r0, #0                                  ; Is this a read?
        TEQNE   r0, #Podule_Speed_TypeA                 ; Is the timing Type_A
        TEQNE   r0, #Podule_Speed_TypeC                 ; Is the timing Type_C
        BNE     SpeedNotAvailable

        LDR     r11, [ sp, #0 ]                         ; Original R0
        PHPSEI
        LDRB    r0, [ r10, #IOMD_ECTCR ]                ; Get the current speed value
        MOV     r3, r0, ASR r2                          ; Move bit to bottom
        TST     r3, #1
        MOVEQ   r3, #Podule_Speed_TypeA
        MOVNE   r3, #Podule_Speed_TypeC
        STR     r3, [ sp, #0 ]                          ; Poke into exit frame
        MOV     r3, #1
        SUBS    r11, r11, #1                            ; Map speed 0,1,3 to -1,0,2
        MOVPL   r11, r11, ASR #1                        ; Map 0,2 to 0,1
        BICPL   r0, r0, r3, ASL r2                      ; Bit mask for the new value
        ORRPL   r0, r0, r11, ASL r2
        STRPLB  r0, [ r10, #IOMD_ECTCR ]                ; Store the new value
        PLP
        CLRV
        B       ExitSetSpeed
        ]

HelperIOMDT
        CMP     r0, #Podule_Speed_TypeH                 ; We'll accept anything up to H
        BHI     BadSpeed

        PHPSEI
        SUBS    r0, r0, #1

        LDRB    r3, [r10, #&AC]                         ; bit 2
        MOVPL   r1, #1
        MOVPL   r1, r1, LSL r2
        BICPL   r1, r3, r1                              ; clear the bit relating to this podule
        MOV     r3, r3, LSR r2
        AND     r11, r3, #1
        MOVPL   r3, r0, LSR#2                           ; get bit 2 of the speed
        ANDPL   r3, r3, #1
        MOVPL   r3, r3, LSL r2                          ; promote to the appropriate place
        ORRPL   r3, r1, r3
        STRPLB  r3, [r10, #&AC]

        LDRB    r3, [r10, #&C8]                         ; bit 1
        MOVPL   r1, #1
        MOVPL   r1, r1, LSL r2
        BICPL   r1, r3, r1                              ; clear the bit relating to this podule
        MOV     r3, r3, LSR r2
        AND     r3, r3, #1
        ORR     r11, r3, r11, LSL#1
        MOVPL   r3, r0, LSR#1                           ; get bit 1 of the speed
        ANDPL   r3, r3, #1
        MOVPL   r3, r3, LSL r2                          ; promote to the appropriate place
        ORRPL   r3, r1, r3
        STRPLB  r3, [r10, #&C8]

        LDRB    r3, [r10, #&A8]                         ; bit 0
        MOV     r3, r3, LSR r2
        AND     r3, r3, #1
        ORR     r11, r3, r11, LSL#1
        ANDPL   r3, r0, #1
        MOVPL   r3, r3, LSL r2                          ; promote to the appropriate place
        ORRPL   r3, r1, r3
        STRPLB  r3, [r10, #&A8]

        PLP
        ADD     r11, r11, #1
        STR     r11, [ sp, #0 ]                         ; Poke into exit frame
        CLRV
        B       ExitSetSpeed

SpeedNotAvailable
        ADRL    r0, ErrorBlock_SpeedNo
        B       ErrorExitSetSpeed

BadSpeed
        ADRL    r0, ErrorBlock_BdSpeed
ErrorExitSetSpeed
      [ DebugInterface
        DREG    r0, "Error is at &"
      ]
        BL      copy_error_zero
ExitSetSpeed
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r3, pc"

        LTORG

; ****************************************************************************

OnlyExtended ROUT
; Leaf routine BL'd to (with V clear)
; in:   R0 is the ID byte
; out:  error if not extended

        TST     r0, #BitSeven
        BNE     NonConformant
        ANDS    r0, r0, #2_01111000                     ; Mask out the Id field
        MOVEQ   pc, lr
        ADRL    Error, ErrorBlock_NotExt
        B       copy_error_zero                         ; Will set the V bit and return to LR
NonConformant
        ADRL    Error, ErrorBlock_NotAcrn
        B       copy_error_zero                         ; Will set the V bit and return to LR

SearchNodesForMatch ROUT
; in:   R2 = what we're hoping to match
;       R1 = node entry we're interested in (must be a 32 bit one)
;       wp = workspace
; out:  Z  = 1 = zero found,R1 & R2 preserved
;    or Z  = 0 = successful match,R1=node offset,R2=podule number

        Push    "r5,r7,lr"
        MOV     r5, #:INDEX:NodeListHead
        LDR     r7, Capabilities
        LDR     r7, [r7, #Capability_PodCount]
10
        SUB     r7, r7, #1
        CMP     r7, #-1
        MOVEQ   r7, #-2                                 ; the system ROM (-1) wont be in the list
        LDR     r5, [wp, r5]
        TEQ     r5, #0
        BEQ     %FT15                                   ; exit Z=1
        ADD     r14, wp, r5                             ; convert back to absolute
        LDR     r14, [r14, r1]
        TEQ     r14, r2                                 ; match?
        BNE     %BT10
        MOV     r2, r7
        MOVS    r1, r5                                  ; exit Z=0 as r5<>0
15
        Pull    "r5,r7,pc"

; ****************************************************************************
;
;   ConvertR3ToPoduleNode - Internal routine to convert one of the following;
;                               i)   A hardware base address (slow/med/fast/sync)
;                               ii)  A combined address
;                               iii) A CMOS address
;                               iv)  A module space address
;                               v)   An EASI space address
;                               vi)  A Podule number
;                               vii) The NIC hardware base address or ROM
;                           Into an address of the podule node.
;
; in:   R3 = hardware base address
;
; out:  R0 = ID byte
;       R1 = base (ROM) address of podule
;       R2 = Podule number
;       R3 = offset in workspace of podule descriptor
;

ConvertR3ToPoduleNode ROUT
        Push    "lr"
      [ DebugInterface
        DREG    r3,"CR3TPN entered with r3=&"
      ]
        ASSERT  (PoduleCMOS > 31) :LAND: (PoduleExtraCMOS > 31)
        CMP     r3, #32                                   ; Check for podule/extROM (vi)
        BCS     %FT04
        CMP     r3, #-16
        BLT     %FT04

        ; Value in -16 < R3 < 32,so scan the list
        LDR     r2, Capabilities
        LDR     r2, [r2, #Capability_PodCount]
        MOV     r1, #:INDEX:NodeListHead
01
        SUB     r2, r2, #1
        CMP     r2, #-1
        MOVEQ   r2, #-2                                   ; the system ROM (-1) wont be in the list
        LDR     r1, [wp, r1]
        TEQ     r1, #0
        BEQ     DuffR3                                    ; end of list,nothing found
        TEQ     r3, r2
        BNE     %BT01
        B       CheckNode

04
        ; Our policy will be to simply match the address part of the value of R3
        LDR     r1, =Podule_BaseAddressANDMask
        AND     r2, r3, r1
        ORR     r2, r2, #&180000                          ; promote slow/med/fast to sync
        MOV     r1, # :INDEX: PoduleNode_BaseAddress      ; Check IOC podule sync address (i)
        BL      SearchNodesForMatch

        LDREQ   r1, =Podule_CMOSAddressANDMask            ; Check for CMOS (iii)
        ANDEQ   r2, r3, r1
        MOVEQ   r1, # :INDEX: PoduleNode_CMOS
        BLEQ    SearchNodesForMatch

        MOVEQ   r2, r3
        MOVEQ   r1, # :INDEX: PoduleNode_CombinedAddress  ; Check for combined (ii)
        BLEQ    SearchNodesForMatch

        MOVEQ   r1, # :INDEX: PoduleNode_MEMCAddress      ; Check for MEMC space (iv)
        BLEQ    SearchNodesForMatch

        MOVEQ   r1, # :INDEX: PoduleNode_EASIAddress      ; Check for EASI space (v)
        BLEQ    SearchNodesForMatch
        BNE     CheckNode

      [ NetworkPodule
        LDR     r1, Capabilities
        LDR     r1, [r1, #Capability_Features]
        TST     r1, #Capability_NIC                       
        BEQ     DuffR3                                    ; No NIC

        LDR     r1, =Podule_BaseAddressANDMask
        AND     r2, r3, r1
        ASSERT  NumberOfNetworkPodule = MaximumPodule-1
        LDR     r1, NodeListHead                          ; NIC must always be the highest numbered podule
        ADD     r1, r1, wp
        LDR     r14, [r1, #PoduleNode_ROMAddress]
        TEQ     r14, r2
        LDRNE   r14, [r1, #PoduleNode_BaseAddress]        ; Check for NIC hardware base address or ROM (vii)
        TEQNE   r14, r2
        SUBEQ   r1, r1, wp                                ; Turn back into an offset
        MOVEQ   r2, #NumberOfNetworkPodule
        BEQ     CheckNode
      ]

DuffR3
        ADRL    Error, ErrorBlock_BadPod
        BL      copy_error_zero
        BVS     ExitConvertR3ToPoduleNode

CheckNode
        ;       Registers so far
        ;       R1 node offset
        ;       R2 podule number
        ;       R0,R3 preserved
40
        ADD     r3, r1, wp                              ; Change to an absolute pointer
        [       DebugModule
        DREG    r3, "Address of Node record is &"
        ]
        MOV     r0, #BitOne                             ; require a default podule id in r0
        LDR     r1, [ r3, #PoduleNode_ROMAddress ]      ; the base address of the podule in question
        TEQ     r1, #0                                  ; no IOC podules,try EASI space
        [       EASISpace
        BEQ     %FT45
        |
        BEQ     %FT50
        ]
        LDRB    r0, [ r3, #PoduleNode_IDByte ]
        TST     r0, #BitOne                             ; Set in the uninitialised state
        BEQ     %50                                     ; Clear in a conformant podule
        LDRB    r0, [ r1 ]                              ; read the actual ID byte (NB assumes that ByteOffset0 = 0)
        [       DebugModule
        DREG    r1, " Podule ROM address of ID byte is &"
        BREG    r0, " ID Byte as read is &"
        ]
        TST     r0, #BitOne                             ; Test bit 1, clear implies this is a ROM
        LDREQB  r14, [ r3, #PoduleNode_Flags ]
        ORREQ   r14, r14, #BitZero                      ; Set the "ROM is Podule" bit
        STREQB  r14, [ r3, #PoduleNode_Flags ]
        [       EASISpace
        BEQ     %50                                     ; There is an ID Byte here
45
        LDR     r1, [ r3, #PoduleNode_EASIAddress ]
        TEQ     r1, #0                                  ; not autodetected,give up
        BEQ     %50
        LDRB    r0, [ r1 ]                              ; read the actual ID byte (NB assumes that ByteOffset0 = 0)
        [       DebugModule
        DREG    r1, " EASI ROM address of ID byte is &"
        BREG    r0, " ID Byte as read is &"
        ]
        TST     r0, #BitOne                             ; Test bit 1, clear implies this is a ROM
        LDREQB  r14, [ r3, #PoduleNode_Flags ]
        ORREQ   r14, r14, #BitOne                       ; Set the "ROM is EASI" bit
        STREQB  r14, [ r3, #PoduleNode_Flags ]
        ]
50
        TST     r0, #BitOne                             ; Test bit 1, clear implies this is a ROM
        BIC     r0, r0, #BitZero + BitTwo               ; clear the interrupt bits
        STREQB  r0, [ r3, #PoduleNode_IDByte ]          ; Store away in our node if OK
        SUB     r3, r3, wp                              ; Restore R3 to an offset
55
        ADRNEL  Error, ErrorBlock_NoPod                 ; then not a podule
        BLNE    copy_error_zero                         ; Will set the V bit and return to LR
  [  DebugInterface
        BVS     %76
        BREG    r0, "PoduleID      = &"
        DREG    r1, "Base address  = &"
        BREG    r2, "Podule number = &"
        DREG    r3, "Node offset   = &"
        ADD     r14, wp, r3
        LDRB    r14, [ r14, #PoduleNode_Flags ]
        BREG    r14, "Flags byte    = &"
76
  ]
ExitConvertR3ToPoduleNode
        Pull    "pc"

; ****************************************************************************
;
;       ReadDevice - Internal routine to read data from podule
;
; in:   R1  = address to read, top two bits say from where:
;               00 ==> From the base of the ROM in Podule space
;               01 ==> From the loader
;               10 ==> From the base of the ROM in EASI space
;                      (in the NON-EASI version the implementation equates this to 00)
;               11 ==> Reserved (implementation equates this to 00)
;             this is safe only because no expansion card area is > 16M
;       R2  = number of bytes to move
;       R3  = podule descriptor offset
;       R10 = address to write data to
;       R11 = hardware base address
;

ReadDevice Entry "r0-r4, r7-r11"
        [       DebugInterface
        DREG    r1, "ReadDevice from &", cc
        DREG    r2, " for &"
        ]
        ADD     r3, wp, r3                              ; r3 -> node
        LDR     r9, [ r3, #PoduleNode_LoaderOffset ]    ; offset from wp to loader, for ROM loader's benefit
        [       NetworkPodule
        LDR     r4, =:INDEX: NetworkLoader
        TEQ     r4, r9                                  ; Is this the network card
        BICEQ   r1, r1, #BitThirtyOne
        ORREQ   r1, r1, #BitThirty                      ; Force the use of the internal loader
        ]
        [       EASISpace
        MOV     r14, r1, ROR #28                        ; Move bits 30 and 31 to bits 2 and 3
        BIC     r1, r1, #BitThirtyOne + BitThirty       ; Make R1 a pure offset
        AND     r14, r14, #2_00001100                   ; Reduce to 0, 4, 8, 12
        ADD     pc, pc, r14
        NOP
        B       ReadDevice_PoduleROM
        B       ReadDevice_Loader
        B       ReadDevice_EASIROM
        |
        AND     r14, r1, #BitThirtyOne + BitThirty      ; Get just the type bits
        BIC     r1, r1, #BitThirtyOne + BitThirty       ; Make R1 a pure offset
        TEQ     r14, #&40000000
        BEQ     ReadDevice_Loader
        ]
ReadDevice_PoduleROM                                    ; Destination of reserved code 11
        BL      DoResetLoader
        ADD     r14, r3, #PoduleNode_WordOffset
        ASSERT  PoduleNode_ByteOffsets = PoduleNode_WordOffset +4
        LDMIA   r14, { r0, r3, r4, r7, r8 }             ; r0 = word offset; r3 = offset 0; r4 = offset 1
                                                        ; r7 = offset 2; r8 = offset 3
        [       DebugInterface
        DREG    r0, "Word Offset   = &"
        DREG    r3, "Byte Offset 0 = &"
        DREG    r4, "Byte Offset 1 = &"
        DREG    r7, "Byte Offset 2 = &"
        DREG    r8, "Byte Offset 3 = &"
        ]
        MOV     r9, r1, LSR #2                          ; r9 = number of words to 1st byte
        MLA     r11, r9, r0, r11                        ; address of start of 1st word
        MOVS    r14, r1, LSL #31
        BCC     %FT05                                   ; [start at byte 0 or 1]
        BPL     %FT12                                   ; [start at byte 2]
        BMI     %FT13                                   ; [start at byte 3]
05
        MOVS    r14, r14, LSL #1                        ; set carry if byte 1
        BCS     %FT11                                   ; [start at byte 1]
10
        SUBS    r2, r2, #1
        LDRCSB  r14, [ r11, r3 ]
        STRCSB  r14, [ r10 ], #1
11
        SUBCSS  r2, r2, #1
        LDRCSB  r14, [ r11, r4 ]
        STRCSB  r14, [ r10 ], #1
12
        SUBCSS  r2, r2, #1
        LDRCSB  r14, [ r11, r7 ]
        STRCSB  r14, [ r10 ], #1
13
        SUBCSS  r2, r2, #1
        LDRCSB  r14, [ r11, r8 ]
        STRCSB  r14, [ r10 ], #1
        ADDCS   r11, r11, r0
        BCS     %BT10
ExitReadDeviceOK
        CLRV
30
        STRVS   r0, [ sp, #0 ]
        EXIT

ReadDevice_Loader
        ADDS    r7, r2, #0                              ; count (and clear V)
        MOV     r8, r10                                 ; destination (r10 can be altered by loader)
        CMP     r9, #-1                                 ; if no loader
        ADREQL  Error, ErrorBlock_NoLdr                 ; then return error
        BLEQ    copy_error_zero                         ; Always sets the V bit
        BVS     %BT30
        ADD     r9, wp, r9
        LDR     r11, [r3, #PoduleNode_CombinedAddress ] ; get (hardware address + CMOS address)
                                                        ; or ROM address in case of extension ROMs
        [       DebugModule
        DREG    r9, "Address of loader is &"
        DREG    r11, "Base address passed to loader is &"
        DREG    r8, "Core transfer address is &"
        ]
50
        [       DebugLoader
        Push    "r5, r6, r7"
        MOV     r5, #0
        ]
        MOV     lr, pc
        ADD     pc, r9, #0                              ; call the read entry of the loader
ReadDeviceReturnFromLoader
        [       DebugLoader
        BVS     %62
        DREG    r10, "Page counter value is &"
        DREG    r11, "Reference address is  &"
        TEQ     r5, #0
        BEQ     %62
        DREG    r6, "Loader has reset and read &", cc
        DREG    r7, ", and &"
62
        Pull    "r5, r6, r7"
        ]
        BVS     %60
        [       DebugLoader
        DREG    r1, "Loader: Address &", cc
        BREG    r0, " ==> Data &"
        ]
        STRB    r0, [ r8 ], #1
        INC     r1
        DECS    r7
        BNE     %50
        B       ExitReadDeviceOK

60
        TEQ     Error, #0
        ADREQL  Error, ErrorBlock_InLdr
        BLEQ    copy_error_zero                         ; Always sets the V bit
        SETV
        B       %30

        [       EASISpace
ReadDevice_EASIROM
        LDR     r14, [ r3, #PoduleNode_EASIAddress ]
        CMP     r14, #0                                 ; Check for no EASI space (clears V)
        ADREQL  Error, ErrorBlock_NotEASI               ; then return error
        BLEQ    copy_error_zero                         ; Always sets the V bit
        BVS     %30
        ADD     r14, r14, r1, ASL #2                    ; Add in the base address
70
        DECS    r2
        BMI     ExitReadDeviceOK
        LDRB    r0, [ r14 ], #4
        STRB    r0, [ r10 ], #1
        B       %70
        ]

; ****************************************************************************
;
;       WriteDevice - Internal routine to write data to podule
;
; in:   R1  = address to write, top two bits say from where:
;               00 ==> To the base of the ROM in Podule space
;               01 ==> To the loader
;               10 ==> To the base of the ROM in EASI space
;                      (in the NON-EASI version the implementation equates this to 00)
;               11 ==> Reserved
;       R2  = number of bytes to move
;       R3  = podule descriptor offset
;       R10 = address to read data from
;       R11 = hardware base address
;

WriteDevice Entry "r0-r4, r7-r11"
        ADD     r3, wp, r3                              ; r3 -> node
        LDR     r9, [ r3, #PoduleNode_LoaderOffset ]    ; offset from wp to loader, for ROM loader's benefit
        [       NetworkPodule
        LDR     r4, =:INDEX: NetworkLoader
        TEQ     r4, r9                                  ; Is this the network card
        BICEQ   r1, r1, #BitThirtyOne + BitThirty
        ORREQ   r1, r1, #BitThirty                      ; Force the use of the internal loader
        ]
        [       EASISpace
        MOV     r14, r1, ROR #28                        ; Move bits 30 and 31 to bits 2 and 3
        BIC     r1, r1, #BitThirtyOne + BitThirty       ; Make R1 a pure offset
        AND     r14, r14, #2_00001100                   ; Reduce to 0, 4, 8, 12
        ADD     pc, pc, r14
        NOP
        B       WriteDevice_PoduleROM
        B       WriteDevice_Loader
        B       WriteDevice_EASIROM
        |
        AND     r14, r1, #BitThirtyOne + BitThirty      ; Get just the type bits
        BIC     r1, r1, #BitThirtyOne + BitThirty       ; Make R1 a pure offset
        TEQ     r14, #&40000000
        BEQ     WriteDevice_Loader
        ]
WriteDevice_PoduleROM                                   ; Destination of reserved code 11
        BL      DoResetLoader
        ADD     r14, r3, #PoduleNode_WordOffset
        ASSERT  PoduleNode_ByteOffsets = PoduleNode_WordOffset +4
        LDMIA   r14, { r0, r3, r4, r7, r8 }             ; r0 = word offset; r3 = offset 0; r4 = offset 1
                                                        ; r7 = offset 2; r8 = offset 3
        MOV     r9, r1, LSR #2                          ; r9 = number of words to 1st byte
        MLA     r11, r9, r0, r11                        ; address of start of 1st word
        MOVS    r14, r1, LSL #31
        BCC     %FT05                                   ; [start at byte 0 or 1]
        BPL     %FT12                                   ; [start at byte 2]
        BMI     %FT13                                   ; [start at byte 3]
05
        MOVS    r14, r14, LSL #1                        ; set carry if byte 1
        BCS     %FT11                                   ; [start at byte 1]
10
        SUBS    r2, r2, #1
        LDRCSB  r14, [ r10 ], #1
        STRCSB  r14, [ r11, r3 ]
11
        SUBCSS  r2, r2, #1
        LDRCSB  r14, [ r10 ], #1
        STRCSB  r14, [ r11, r4 ]
12
        SUBCSS  r2, r2, #1
        LDRCSB  r14, [ r10 ], #1
        STRCSB  r14, [ r11, r7 ]
13
        SUBCSS  r2, r2, #1
        LDRCSB  r14, [ r10 ], #1
        STRCSB  r14, [ r11, r8 ]
        ADDCS   r11, r11, r0
        BCS     %BT10
20
        CLRV
30
        STRVS   r0, [sp]
        EXIT

WriteDevice_Loader
        ADDS    r7, r2, #0                              ; count (and clear V)
        MOV     r8, r10                                 ; source (r10 can be altered by loader)
        ADD     r3, wp, r3                              ; prepare to pass in address of podule node
                                                        ; (for ROM loader's benefit)
        LDR     r9, [r3, #PoduleNode_LoaderOffset]      ; offset from wp to loader
        CMP     r9, #-1                                 ; if no loader
        ADREQL  Error, ErrorBlock_NoLdr                 ; then return error
        BLEQ    copy_error_zero                         ; Always sets the V bit
        BVS     %FT60
        ADD     r9, wp, r9
        LDR     r11, [r3, #PoduleNode_CombinedAddress]  ; get (hardware address + CMOS address)
                                                        ; or ROM address in case of extension ROMs
50
        LDRB    r0, [ r8 ], #1
        MOV     lr, pc                                  ; get the return address
        ADD     pc, r9, #4                              ; call the write entry of the loader
        BVS     %60
        INC     r1
        DECS    r7
        BNE     %50
        B       %20                                     ; exit OK

60
        TEQ     Error, #0
        ADREQL  Error, ErrorBlock_InLdr
        BLEQ    copy_error_zero                         ; Always sets the V bit
        SETV
        B       %30

        [       EASISpace
WriteDevice_EASIROM
        LDR     r14, [ r3, #PoduleNode_EASIAddress ]
        CMP     r14, #0                                 ; Check for no EASI space (clears V)
        ADREQL  Error, ErrorBlock_NotEASI               ; then return error
        BLEQ    copy_error_zero                         ; Always sets the V bit
        BVS     %30
        ADD     r14, r14, r1, ASL #2                    ; Add in the base address
70
        DECS    r2
        BMI     %20
        LDRB    r0, [ r10 ], #1
        STRB    r0, [ r14 ], #4
        B       %70
        ]

; ****************************************************************************
;
;       ResetLoader - Internal routine to call the reset entry in the loader
;
; in:   R3 = podule descriptor offset
;

ResetLoader ROUT
        Push    "r3, lr"
        ADD     r3, wp, r3                              ; r3 -> node
        BL      DoResetLoader
        Pull    "r3, pc"

; ****************************************************************************
;
;       DoResetLoader - Internal routine to call the reset entry in the loader
;
; in:   R3 = address of podule node record
;

DoResetLoader
        Push    "r0, r10, r11, lr"
 [ DebugInterface
        DREG    r3, "Resetting Loader in node &"
 ]
        CLRV
        LDR     r10, [ r3, #PoduleNode_LoaderOffset ]
        CMP     r10, #-1                                ; No loader to call return without error
 [ DebugInterface
        BNE     %34
        DLINE   "No Loader to reset"
34
 ]
        BEQ     ExitResetLoader
        ADD     r10, wp, r10                            ; convert offset to address
        LDR     r11, [ r3, #PoduleNode_CombinedAddress ]
        Push    "r2-r4"
        MOV     lr, pc
        ADD     pc, r10, #8                             ; reset entry trashes R0, R2, R3, R4, R10
        Pull    "r2-r4"
        BVC     ExitResetLoader
 [ DebugInterface
        DLINE   "Loader returns an error"
 ]
        TEQ     r0, #0                                  ; V still set
        ADREQL  r0, ErrorBlock_InLdr
        BLEQ    copy_error_zero                         ; Always sets the V bit
ExitResetLoader
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r10, r11, pc"

; ****************************************************************************
;
;       GetSegmentHeader - Internal routine to read header for a chunk

        [       EASISpace
GetSegmentHeader ROUT
; in:   R0 = chunk number (0 to n)
;       R1 = hardware address (no CMOS part)
;       R3 = podule descriptor offset
;
; out:  R1,R2 corrupted
;       R10 -> SegmentHeader
;       R11 = hardware address (no CMOS part)
;       SegmentHeader contains header, or 0 in first word if read fails

        Push    "r7, r8, r9, lr"
; Use R7 to count how many we have enumerated so far
; Use R8 to keep the address within area of the current directory entry
; Use R9 to keep the area in 0 ==> Podule ROM, bit30 set ==> Loader, bit31 set ==> EASI, others silly
 [ DebugInterface
        DREG    r0, "GetSegmentHeader &"
 ]
        MOV     r7, #0
        MOV     r8, #16
        ADD     r9, wp, r3                              ; Address of Node record
        LDRB    r9, [ r9, #PoduleNode_Flags ]           ; Get the flags
        TST     r9, #BitOne                             ; Is this an EASI ROM?
        MOVNE   r9, #1<<31                              ; Yes, start there
        MOVEQ   r9, #0                                  ; No, start in Podule space
  [  DebugInterface
        DREG    r9, "Area chosen is &"
  ]
        ADR     r10, SegmentHeader
        MOV     r11, r1                                 ; R11 now is the base address
        MOV     r1, #0                                  ; Let's zero the header in case of error
        STR     r1, [ r10 ]
        CMP     r0, #0
        BMI     ExitSegmentHeader                       ; No funny business with negative segments!
GetSegmentHeaderLoop
        ADD     r1, r8, r9                              ; Make the full address
        MOV     r2, #8
 [ DebugInterface
        DREG    r7, "Read SegmentHeader &"
 ]
        BL      ReadDevice
        BVS     ExitSegmentHeader
        LDRB    r14, [ r10, #0 ]
        TEQ     r14, #0                                 ; Is this an end of directory marker?
 [ DebugInterface
        BREG    r14, "First byte of header is &"
 ]
        BEQ     ChangeAreas
        TEQ     r0, r7                                  ; Is this the one we want?
        LDREQ   r14, [ r10, #4 ]                        ; Start address
        ADDEQ   r14, r14, r9                            ; Add the area part
        STREQ   r14, [ r10, #4 ]
        BEQ     ExitSegmentHeader                       ; Yes, so return to the caller
        INC     r7
        INC     r8, 8                                   ; Skip to the next directory entry
        B       GetSegmentHeaderLoop

ChangeAreas
        INC     r9, 1<<30
 [ DebugInterface
        DREG    r9, "Changing to area &"
 ]
        TEQ     r9, #1<<30                              ; Have we just entered Loader space?
        BNE     NotChangedToLoader
        ADD     r8, wp, r3                              ; r8 -> node
        LDR     r8, [ r8, #PoduleNode_LoaderOffset ]
        CMP     r8, #-1                                 ; No loader to call; return without error
        BEQ     NotChangedToLoader
        MOV     r8, #0                                  ; Start at the begining of the new directoory
        BL      ResetLoader                             ; must be safe
        BVS     ExitSegmentHeader
        B       GetSegmentHeaderLoop

NotChangedToLoader
 [ DebugInterface
        DLINE   "No more areas"
 ]
        CLRV
ExitSegmentHeader
        Pull    "r7, r8, r9, pc"
        |       ; EASISpace
;
; in:   R0 = chunk number (0 to n)
;       R1 = hardware address (no CMOS part)
;       R3 = podule descriptor offset
;
; out:  R1,R2 corrupted
;       R10 -> SegmentHeader
;       R11 = hardware address (no CMOS part)
;       SegmentHeader contains header, or 0 in first word if read fails
;
; PoduleLimit starts off at maxint - when we have seen the highest segment in
; podule space, then PoduleLimit is set to the number of that segment
;
; EnumerationLimit is the highest numbered segment we've seen in podule space
; - starts off at -1
;
; IF R0 > PoduleLimit THEN
;  Scan pseudo space, starting at segment (PoduleLimit+1) at address 0
; ELSE
;  IF R0 > EnumerationLimit THEN
;   Scan podule space, starting at segment (EnumerationLimit+1) at address 16+8*(EnumerationLimit+1)
;  ELSE
;   Read segment from address 16+8*R0
;  ENDIF
; ENDIF
;
GetSegmentHeader Entry "r7, r8"
        ADD     r8, wp, r3                              ; Node record address
        MOV     r11, r1                                 ; R11 now is the base address
        ADR     r10, SegmentHeader
        MOV     r1, #0                                  ; Let's zero the header in case of error
        STR     r1, [ r10 ]
        CMP     r0, #0
        EXIT    MI                                      ; no funny business with negative segments!
        LDR     r7, [ r8, #PoduleNode_PoduleLimit ]     ; the value of PoduleLimit
 [ DebugInterface
        BREG    r0, "This one    = &"
        BREG    r7, "PoduleLimit = &"
 ]
        MOV     r1, r11                                 ; where ResetLoader expects it
        BL      ResetLoader                             ; must be safe
        EXIT    VS
        CMP     r0, r7                                  ; is the user into pseudo space?
        BGT     %20                                     ; yes, then use loader

        LDR     r7, [ r8, #PoduleNode_EnumerationLimit ]
        CMP     r0, r7
        BGT     %10

; we've already read at least up to here, so it's safe to just read it

        MOV     r1, #16
        ADD     r1, r1, r0, LSL #3                      ; =16+8*n
        MOV     r2, #8
        BL      ReadDevice
        EXIT

; we're past the point we've previously read up to, so continue from here

10
        ADD     r7, r7, #1                              ; check the next one
        MOV     r1, #16
        ADD     r1, r1, r7, LSL #3                      ; =16+8*n
        MOV     r2, #8
        BL      ReadDevice
        EXIT    VS
        LDRB    r2, [ r10 ]
        TEQ     r2, #0                                  ; have we just read the last one ??
        BEQ     %15                                     ; better get this one from pseudo space then
        TEQ     r7, r0                                  ; is this the one we want ??
        BNE     %10
        STR     r0, [ r8, #PoduleNode_EnumerationLimit ] ; update the enumeration limit value
        EXIT

; we've just seen the last one in podule space, so update PoduleLimit

15
        SUB     r7, r7, #1                              ; previous one was last proper one in podule space
        STR     r7, [ r8, #PoduleNode_PoduleLimit ]

; requested segment is in pseudo space, r7 = last one is in podule space

20
 [ DebugInterface
        DLINE   "Going into pseudo space."
 ]
        LDR     r1, [ r8, #PoduleNode_LoaderOffset ]
        CMP     r1, #-1
        BEQ     %40
        MOV     r1, #0 + BitThirtyOne
30
        ADD     r7, r7, #1                              ; move onto next one
        MOV     r2, #8
        BL      ReadDevice
        EXIT    VS
        ADD     r1, r1, #8
        LDRB    r2, [ r10 ]
        TEQ     r2, #0                                  ; have we just read the last one ??
        BEQ     %40                                     ; better go home then
        TEQ     r7, r0                                  ; is this the one we want ??
        BNE     %30
        LDR     r7, [ r10, #4 ]                         ; Start address
        ORR     r7, r7, #BitThirtyOne
        STR     r7, [ r10, #4 ]
40
        CLRV
        EXIT
        ]       ; EASISpace


        END
