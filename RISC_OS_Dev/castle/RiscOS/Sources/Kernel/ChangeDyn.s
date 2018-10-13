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
        TTL   => ChangeDyn

        ; OS_ChangeDynamicArea optimisations:

        GBLL  FastCDA_Bulk ; Do all cache/TLB maintenance in bulk instead of on a per-page basis
FastCDA_Bulk SETL {TRUE}

        GBLL  FastCDA_FIQs ; Don't thrash ClaimFIQ/ReleaseFIQ in DoTheGrowPagesSpecified
FastCDA_FIQs SETL {TRUE}

        GBLL  FastCDA_Unnecessary ; Avoid unnecessary cache cleaning in DoTheGrowPagesSpecified
FastCDA_Unnecessary SETL {TRUE}

        ; DoTheGrowPagesSpecified profiling code
        ; Written to use Cortex-A8 cycle count performance counter - will need modifying for other CPUs!

        GBLL  FastCDA_Prof
FastCDA_Prof SETL {FALSE}

      [ FastCDA_Prof
        ; Squeeze profiling workspace into "free space after envstring"
                                 ^ ExtendedROMFooter+4
        ! 0, "FastCDA_Prof workspace at ":CC::STR:@
FastCDA_Prof_DoTheGrowInit           # 4
FastCDA_Prof_MarkRequired            # 4
FastCDA_Prof_PagesUnsafe             # 4
FastCDA_Prof_DoublyRemoveCacheability # 4
FastCDA_Prof_DoublyMovePages         # 4
FastCDA_Prof_FindSpare               # 4
FastCDA_Prof_ClaimFIQ                # 4
FastCDA_Prof_AccessPhysical          # 4
FastCDA_Prof_CopyPage                # 4
FastCDA_Prof_ReleasePhysical         # 4
FastCDA_Prof_MoveReplacement         # 4
FastCDA_Prof_MoveNeeded              # 4
FastCDA_Prof_ReleaseFIQ              # 4
FastCDA_Prof_PagesSafe               # 4
FastCDA_Prof_CallPreGrow             # 4
FastCDA_Prof_CallPostGrow            # 4
FastCDA_Prof_MMUChangingCached       # 4 ; MMU_ChangingUncached followed by Cache_CleanInvalidateaAll
FastCDA_Prof_MMUChangingUncached     # 4 ; MMU_ChangingUncached followed by nothing
FastCDA_Prof_ChangingEntry           # 4
        ASSERT @ <= &500
      ]

        MACRO
        FastCDA_ProfInit $temp
      [ FastCDA_Prof
        MVN     $temp,#0
        MCR     p15,0,$temp,c9,c12,2
        MOV     $temp,#1<<31
        MCR     p15,0,$temp,c9,c12,1
        MOV     $temp,#7
        MCR     p15,0,$temp,c9,c12,0
      ]
        MEND

        MACRO
        FastCDA_ProfStart $var,$temp,$temp2,$temp3,$cc
      [ FastCDA_Prof
        LDR$cc  $temp,=ZeroPage+FastCDA_Prof_$var
        LDR$cc  $temp2,[$temp]
        MRC$cc  p15,0,$temp3,c9,c13,0
        SUB$cc  $temp2,$temp2,$temp3
        STR$cc  $temp2,[$temp]
      ]
        MEND

        MACRO
        FastCDA_ProfEnd $var,$temp,$temp2,$temp3,$cc
      [ FastCDA_Prof
        MRC$cc  p15,0,$temp3,c9,c13,0
        LDR$cc  $temp,=ZeroPage+FastCDA_Prof_$var
        LDR$cc  $temp2,[$temp]
        ADD$cc  $temp2,$temp2,$temp3
        STR$cc  $temp2,[$temp]
      ]
        MEND

;******************************************************************************
; ChangeDynamic SWI
; In  : R0 =  0 => System Heap,
;             1 => RMA
;             2 => Screen
;             3 => Sprite area
;             4 => Font cache
;             5 => RAM disc
;             6 => Free pool
;       R1 = no of bytes to change by
;
; Out : V set if CAO in AplWork or couldn't move all the bytes requested.
;       R1 set to bytes moved.
;******************************************************************************

; OS access privileges (OSAP_ to differentiate from AP_ used in Hdr:MEMM.*)
OSAP_Full * 0 ; user r/w/x, priv r/w/x
OSAP_Read * 1 ; user r/x, priv r/w/x
OSAP_None * 2 ; user none, priv r/w/x
OSAP_ROM  * 3 ; user r/x, priv r/x

; Corresponding values for OS_Memory 24
; (n.b. - XN flag is inverted)
CMA_ROM  * CMA_Partially_UserR+CMA_Partially_UserXN+CMA_Partially_PrivR+CMA_Partially_PrivXN
CMA_Read * CMA_ROM+CMA_Partially_PrivW
CMA_Full * CMA_Read+CMA_Partially_UserW
CMA_None * CMA_Partially_PrivR+CMA_Partially_PrivW+CMA_Partially_PrivXN

; Convenience macro for defining DA/page flags and corresponding CMA value
        MACRO
$area   DefAreaFlags $ap, $extra
AreaFlags_$area * OSAP_$ap :OR: ($extra + 0)
CMA_$area * CMA_$ap
        MEND

; Flags for kernel-managed DAs
AppSpace         DefAreaFlags Full
SysHeap          DefAreaFlags Full
RMA              DefAreaFlags Full
Screen           DefAreaFlags Full, DynAreaFlags_NotCacheable :OR: DynAreaFlags_DoublyMapped :OR: DynAreaFlags_NeedsSpecificPages
Sprites          DefAreaFlags Full
FontArea         DefAreaFlags None
RAMDisc          DefAreaFlags None, DynAreaFlags_NotCacheable
RAMDisc_SA       DefAreaFlags None ; StrongARM-specific (~CB gives poor performance for current StrongARMs)
FreePool         DefAreaFlags None, DynAreaFlags_NotCacheable :OR: DynAreaFlags_NotBufferable :OR: DynAreaFlags_PMP

; Flags for other kernel managed areas

Duff                 DefAreaFlags None, DynAreaFlags_NotCacheable :OR: DynAreaFlags_NotBufferable
CursorChunkCacheable DefAreaFlags Read, PageFlags_Unavailable ; Should be OSAP_None?
CursorChunk          DefAreaFlags Read, PageFlags_Unavailable :OR: DynAreaFlags_NotCacheable
PageTablesAccess     DefAreaFlags None ; n.b. just the AP value, for full page flags use PageTable_PageFlags workspace var
HALWorkspace         DefAreaFlags Read, PageFlags_Unavailable
HALWorkspaceNCNB     DefAreaFlags None, DynAreaFlags_NotCacheable :OR: DynAreaFlags_NotBufferable :OR: PageFlags_Unavailable
ZeroPage             DefAreaFlags Read, PageFlags_Unavailable
ScratchSpace         DefAreaFlags Read, PageFlags_Unavailable
DCacheClean          DefAreaFlags None ; ideally, svc read only, user none but hey ho
CAM                  DefAreaFlags None, PageFlags_Unavailable
SVCStack             DefAreaFlags Read, PageFlags_Unavailable
IRQStack             DefAreaFlags None, PageFlags_Unavailable
ABTStack             DefAreaFlags None, PageFlags_Unavailable
UNDStack             DefAreaFlags None, PageFlags_Unavailable
Kbuffs               DefAreaFlags Read, PageFlags_Unavailable
DebuggerSpace        DefAreaFlags Read, PageFlags_Unavailable

  [ DA_Batman
ChangeDyn_Batcall    * -3               ; special DA number to select Batman usage of OS_ChangeDynamicArea
  ]
; -2 was an internal value, now no longer used
ChangeDyn_AplSpace   * -1
ChangeDyn_SysHeap    * 0
ChangeDyn_RMA        * 1
ChangeDyn_Screen     * 2
ChangeDyn_SpriteArea * 3
ChangeDyn_FontArea   * 4
ChangeDyn_RamFS      * 5
ChangeDyn_FreePool   * 6
ChangeDyn_MaxArea    * 6

; Number of entries in page block on stack

NumPageBlockEntries *   63
PageBlockSize   *       NumPageBlockEntries * 12
PageBlockChunk  *       NumPageBlockEntries * 4096

;
; mjs - performance enhancements (from Ursula, merged into HALised kernel June 2001)
; Workspace for acceleration of operations on a DA, by reducing need to traverse DA list.
;
; - accelerates allocating non-quick DA numbers to O(n) instead of laughable O(n*n), where n is no. of DAs
; - accelerates enumeration to O(n) instead of laughable O(n*n)
; - allocation of a quick handle (DA number) is O(1)
; - access of a DA node from a quick handle is O(1)
; - access of a DA node from a non-quick handle is O(1), if it repeats the most recent non-quick handle access (else O(n))
;
; - creation of a DA still has some O(n) work (requires search for address space), but is now rather quicker
; - removal of a DA is still O(n) (requires traversal of list in order to get previous node)
; - other uses of a DA with a quick handle (eg. get info, change size) avoid any O(n) work
;
; - all system handles will be quick.
; - non-system handles will be quick, except for very large numbers of DAs, or silly modules like the Wimp who insist on
;   their own silly DA number (the latter can still benefit from LastTreacleHandle - see below)
;
; Limitations:
; - does not allow anyone to choose their own DA number that clashes with the quick handle set - should not
;   be a problem since choosing own number reserved for Acorn use
; - does not allow anyone to renumber a DA with a quick handle - again, reserved for system use
; - DA names will be truncated to a maximum of 31 characters (or as defined below)
;
                                  GBLL DynArea_QuickHandles
DynArea_QuickHandles              SETL {TRUE}
;
      ;various bad things happen if DynArea_QuickHandles is FALSE (eg. some new API disappears)
      ;should remove FALSE build option to simplify source code next time kernel is updated (kept for reference/testing now)
      ASSERT DynArea_QuickHandles

                                  GBLL DynArea_NullNamePtrMeansHexString
DynArea_NullNamePtrMeansHexString SETL {TRUE} :LAND: DynArea_QuickHandles
;
  [ DynArea_QuickHandles
DynArea_MaxNameLength     * 31                      ;maximum length of DA name, excluding terminator (multiple of 4, -1)
DynArea_NumQHandles       * 256                     ;maximum no. of non-system quick handles available simultaneously
DynArea_AddrLookupBits    * 8                       ;LUT covers entire 4G logical space, so 4G>>8 = 16M granularity
DynArea_AddrLookupSize    * 1<<(32-DynArea_AddrLookupBits) ; Address space covered by each entry
DynArea_AddrLookupMask    * &FFFFFFFF-(DynArea_AddrLookupSize-1)
;
                          ^  0,R11
DynArea_TreacleGuess      # 4                       ;guess for next non-quick handle to allocate, if needed, is TreacleGuess+1
DynArea_CreatingHandle    # 4                       ;handle proposed but not yet committed, during DynArea_Create, or -1 if none
DynArea_CreatingPtr       # 4                       ;ptr to proposed DANode during DynArea_Create (invalid if CreatingHandle = -1)
DynArea_LastTreacleHandle # 4                       ;last non-quick handle accessed by a client (usually the Wimp), or -1 if none
DynArea_LastTreaclePtr    # 4                       ;ptr to DANode for last non-quick handle accessed (invalid if LastTreacleHandle = -1)
DynArea_LastEnumHandle    # 4                       ;last handle enumerated, or -1 if none
DynArea_LastEnumPtr       # 4                       ;ptr to DANode for last handle enumerated (invalid if LastEnumHandle = -1)
DynArea_ShrinkableSubList # 4                       ;sub list of dynamic areas that are Shrinkable (0 if none)
DynArea_OD6Signature      # 4                       ;signature of changes to non-system DAs since last call to OS_DynamicArea 6
                                                    ;bit  0 = 1 if any DAs have been created
                                                    ;bit  1 = 1 if any DAs have been removed
                                                    ;bit  2 = 1 if any DAs have been resized (excluding grow or shrink at creation or removal)
                                                    ;bit  3 = 1 if any DAs have been renumbered
                                                    ;bits 4-30   reserved (0)
                                                    ;bit 31 = 1 if next resize is not to update signature (used during create, remove)
DynArea_OD6PrevSignature  # 4                       ;previous signature, used to distinguish single from multiple changes
DynArea_OD6Handle         # 4                       ;handle of last DA that affected signature
DynArea_OD8Clamp1         # 4                       ;clamp value on area max size for OS_DynamicArea 0 with R5 = -1
                                                    ;(default -1, set by R1 of OS_DynamicArea 8)
DynArea_OD8Clamp2         # 4                       ;clamp value on area max size for OS_DynamicArea 0 with R5 > 0 (not Sparse)
                                                    ;(default -1, set by R2 of OS_DynamicArea 8)
DynArea_OD8Clamp3         # 4                       ;clamp value on area max size for OS_DynamicArea 0 for a Sparse area
                                                    ;(default 4G-4k, set by R3 of OS_DynamicArea 8)
DynArea_SortedList        # 4                       ;alphabetically sorted list of non-system areas, or 0 if none
DynArea_SysQHandleArray   # 4*(ChangeDyn_MaxArea+1) ;for system areas 0..MaxArea, word = ptr to DANode, or 0 if not created yet
DynArea_FreeQHandles      # 4                       ;index of first free quick handle, starting at 1 (or 0 for none)
DynArea_QHandleArray      # 4*DynArea_NumQHandles   ;1 word per quick handle
                                                    ; - if free, word = index of next free quick handle (or 0 if none)
                                                    ; - if used, word = ptr to DANode (must be > DynArea_NumQHandles)
DynArea_AddrLookup        # 4<<DynArea_AddrLookupBits ; Lookup table for fast logaddr -> dynarea lookup
;
DynArea_ws_size           *  :INDEX:@               ;must be multiple of 4
;
            ASSERT DynArea_QHandleArray = DynArea_FreeQHandles +4
  ]
;


;        InsertDebugRoutines

; Exit from ChangeDynamicArea with error Not all moved

failure_IRQgoingClearSemaphore
        LDR     r0, =ZeroPage
      [ ZeroPage = 0
        STR     r0, [r0, #CDASemaphore]
      |
        MOV     r10, #0
        STR     r10, [r0, #CDASemaphore]
      ]
failure_IRQgoing
        ADR     r0, ErrorBlock_ChDynamNotAllMoved
ChangeDynamic_Error
        MOV     r10, #0
        STR     r0, [stack]
        LDR     lr, [stack, #4*10]
        ORR     lr, lr, #V_bit
        STR     lr, [stack, #4*10]
CDS_PostServiceWithRestore
      [ International
        LDR     r0, [stack]
        BL      TranslateError
        STR     r0, [stack]
      ]

; and drop thru to ...

CDS_PostService
        MOV     r1, #Service_MemoryMoved
        MOV     r0, r10                 ; amount moved
        MOVS    r2, r11                 ; which way was transfer?
        BMI     %FT47                   ; [definitely a grow]
        CMP     r11, #ChangeDyn_FreePool
        BNE     %FT48                   ; [definitely a shrink]
        CMP     r12, #ChangeDyn_AplSpace
        BEQ     %FT48                   ; [a shrink]
47
        RSB     r0, r0, #0             ; APLwork or free was source
        MOV     r2, r12                ; r2 = area indicator
48
        BL      Issue_Service

        MOV     r1, r10                ; amount moved

        Pull    "r0, r2-r9, r10, lr"
        ExitSWIHandler

        MakeErrorBlock ChDynamNotAllMoved

; Call_CAM_Mapping
; in:   r2 = physical page number
;       r3 = logical address (2nd copy of doubly mapped area)
;       r9 = offset from 1st to 2nd copy of doubly mapped area (either source or dest, but not both)
;       r11 = PPL + CB bits
Call_CAM_Mapping
        Push    "r0, r1, r4, r6, lr"
        BL      BangCamUpdate
        Pull    "r0, r1, r4, r6, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 bits 0..6 = area number
;       r0 bit 7 set => return max area size in r2 (implemented 13 Jun 1990)
;                       this will return an error if not implemented
; Out   r0 = address of area
;       r1 = current size of area
;       r2 = max size of area if r0 bit 7 set on entry (preserved otherwise)

; TMD 19-May-93: When this is updated to new CDA list, change meaning as follows:

; r0 in range 0..&7F    return address, size of area r0
;             &80..&FF  return address, size, maxsize of area (r0-&80)
;             &100..    return address, size, maxsize of area r0

; TMD 20-Aug-93: New bit added - if r0 = -1 on entry, then returns info on application space
; r0 = base address (&8000)
; r1 = current size (for current task)
; r2 = maximum size (eg 16M-&8000)

ReadDynamicArea ROUT

readdyn_returnR2bit     *       &80
        ASSERT  ChangeDyn_MaxArea < readdyn_returnR2bit

        CMP     r0, #ChangeDyn_AplSpace         ; if finding out about app space
      [ ZeroPage = 0
        LDREQ   r1, [r0, #AplWorkSize+1]        ; then r1 = current size
      |
        LDREQ   r1, =ZeroPage
        LDREQ   r1, [r1, #AplWorkSize]
      ]
        LDREQ   r2, =AplWorkMaxSize             ; and r2 = max size
        MOVEQ   r0, #&8000                      ; r0 = base address
        SUBEQ   r1, r1, r0                      ; adjust size and maxsize
        SUBEQ   r2, r2, r0                      ; to remove bottom 32K
        ExitSWIHandler EQ

; first check if it's one of the new ones

        Push    "r1,lr"
        CMP     r0, #&100                       ; if area >= &100
        MOVCS   r1, r0                          ; then just use area
        BICCC   r1, r0, #readdyn_returnR2bit    ; else knock off bit 7
  [ DynArea_QuickHandles
        BL      QCheckAreaNumber                ; out: r10 -> node
  |
        BL      CheckAreaNumber                 ; out: r10 -> node
  ]
        Pull    "r1,lr"
        BCC     %FT05                           ; [not a new one, so use old code]

        LDR     r11, [r10, #DANode_Flags]
        TST     r11, #DynAreaFlags_PMP
        BNE     %FT01
        CMP     r0, #&80                        ; CS => load maxsize into R2
                                                ; (do this either if bit 7 set, or area >=&100)
        LDRCS   r2, [r10, #DANode_MaxSize]
        LDR     r1, [r10, #DANode_Size]         ; r1 = current size
        LDR     r0, [r10, #DANode_Base]         ; r0 -> base
        TST     r11, #DynAreaFlags_DoublyMapped
        SUBNE   r0, r0, r1                      ; if doubly mapped then return start of 1st copy for compatibility
        ExitSWIHandler
01
        ; Convert physical parameters into byte counts
        CMP     r0, #&80
        BCC     %FT02
        LDR     r2, [r10, #DANode_PMPMaxSize]
        CMP     r2, #DynArea_PMP_BigPageCount
        MOVLO   r2, r2, LSL #12
        LDRHS   r2, =DynArea_PMP_BigByteCount
02
        LDR     r1, [r10, #DANode_PMPSize]
        CMP     r1, #DynArea_PMP_BigPageCount
        MOVLO   r1, r1, LSL #12
        LDRHS   r1, =DynArea_PMP_BigByteCount
        LDR     r0, [r10, #DANode_Base]
        ExitSWIHandler
05
        ADRL    r0, ErrorBlock_BadDynamicArea
      [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
      ]
        B       SLVK_SetV

        MakeErrorBlock  BadDynamicArea

; *************************************************************************
; User access to CAM mapping
; ReadMemMapInfo:
; returns R0 = pagsize
;         R1 = number of pages in use  (= R2 returned from SetEnv/Pagesize)
; *************************************************************************

ReadMemMapInfo_Code
      LDR      R10, =ZeroPage
      LDR      R0, [R10, #Page_Size]
      LDR      R1, [R10, #RAMLIMIT]    ; = total memory size
      ADRL     R11, PageShifts-1
      LDRB     R11, [R11, R0, LSR #12]
      MOV      R1, R1, LSR R11
      ExitSWIHandler

; ************************************************************************
; SWI ReadMemMapEntries: R0 pointer to list.
;  Entries are three words long, the first of which is the CAM page number.
;  List terminated by -1.
; Returns pagenumber (unaltered)/address/PPL triads as below
; ************************************************************************

ReadMemMapEntries_Code  ROUT
        Push    "r0,r14"
        LDR     r14, =ZeroPage
        LDR     r10, [r14, #CamEntriesPointer]
        LDR     r14, [r14, #MaxCamEntry]
01
        LDR     r12, [r0], #4                   ; page number
        CMP     r12, r14
        Pull    "r0,r14", HI
        ExitSWIHandler HI

   [ AMB_LazyMapIn
        ;may need AMB to make mapping honest (as if not lazy), if page is in currently mapped app
        Push    "r0, lr"
        MOV     r0, r12                         ; page number to make honest
        BL      AMB_MakeHonestPN
        Pull    "r0, lr"
   ]

        ADD     r11, r10, r12, LSL #CAM_EntrySizeLog2
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        LDMIA   r11, {r11, r12}
        STMIA   r0!, {r11, r12}
        B       %BT01

; ************************************************************************
; SWI FindMemMapEntries:
; In:  R0 -> table of 12-byte page entries
;       +0      4       probable page number (0..npages-1) (use 0 if no idea)
;       +4      4       logical address to match with
;       +8      4       undefined
;       terminated by a single word containing -1
;
; Out: table of 12-byte entries updated:
;       +0      4       actual page number (-1 => not found)
;       +4      4       address (preserved)
;       +8      4       page protection level (3 if not found)
;       terminator preserved
;
; ************************************************************************

FindMemMapEntries_Code  ROUT

; Code for expanded CAM map version

        Push    "r0, r9, r14"
        LDR     r14, =ZeroPage
        LDR     r9, [r14, #MaxCamEntry]
        LDR     r14, [r14, #CamEntriesPointer]  ; r14 -> start of cam map
        ADD     r9, r14, r9, LSL #CAM_EntrySizeLog2 ; r9 -> first word of last entry in cam map
10
        LDR     r10, [r0, #0]                   ; r10 = guess page number (or -1)
        CMP     r10, #-1                        ; if -1 then end of list
        Pull    "r0, r9, r14", EQ               ; so restore registers
        ExitSWIHandler EQ                       ; and exit

        LDR     r11, [r0, #4]                   ; r11 = logical address

   [ AMB_LazyMapIn
        ;may need AMB to make mapping honest (as if not lazy), if page is in currently mapped app
        Push    "r0, lr"
        MOV     r0, r11                         ; logical address to make honest
        BL      AMB_MakeHonestLA                ; note, quickly dismisses non app space addresses
        Pull    "r0, lr"
   ]

        ADD     r10, r14, r10, LSL #CAM_EntrySizeLog2 ; form address with 'guess' page
        CMP     r10, r9                         ; if off end of CAM
        BHI     %FT20                           ; then don't try to use the guess

        LDR     r12, [r10, #CAM_LogAddr]        ; load address from guessed page
        TEQ     r11, r12                        ; compare address
        BEQ     %FT60                           ; if equal, then guessed page was OK
20

; for now, cheat by looking in L2PT, to see if we can speed things up

        Push    "r5-r8"                         ; need some registers here!
        LDR     r10, =L2PT
        MOV     r8, r11, LSR #12                ; r8 = logical page number
        ADD     r8, r10, r8, LSL #2             ; r8 -> L2PT entry for log.addr
        MOV     r5, r8, LSR #12                 ; r5 = page offset to L2PT entry for log.addr
        LDR     r5, [r10, r5, LSL #2]           ; r5 = L2PT entry for L2PT entry for log.addr
        TST     r5, #3                          ; if page not there
        SUBEQ   r10, r9, #CAM_EntrySize         ; then invalid page so go from last one
        BEQ     %FT45
        LDR     r8, [r8]                        ; r8 = L2PT entry for log.addr
        MOV     r8, r8, LSR #12                 ; r8 = physaddr / 4K

        LDR     r5, =ZeroPage+PhysRamTable
        SUB     r10, r14, #CAM_EntrySize
30
        CMP     r10, r9                         ; have we run out of RAM banks?
        BCS     %FT40                           ; then fail
        LDMIA   r5!, {r6,r7}                    ; load next address, size
        SUB     r6, r8, r6, LSR #12             ; number of pages into this bank
        CMP     r6, r7, LSR #12                 ; if more than there are
        ASSERT  CAM_EntrySizeLog2 <= 16
        BICCS   r7, r7, #&F00
        ADDCS   r10, r10, r7, LSR #12-CAM_EntrySizeLog2 ; then advance CAM entry position
        BCS     %BT30                           ; and loop to next bank

        ADD     r10, r10, r6, LSL #CAM_EntrySizeLog2 ; advance by 2 words for each page in this bank
40
        SUBCS   r10, r9, #CAM_EntrySize         ; search from last one, to fail quickly (if CS)
45
        Pull    "r5-r8"
50
        CMP     r10, r9                         ; if not just done last one,
        ASSERT  CAM_LogAddr=0
        LDRNE   r12, [r10, #CAM_EntrySize]!     ; then get logical address
        TEQNE   r11, r12                        ; compare address
        BNE     %BT50                           ; loop if not same and not at end

; either found page or run out of pages

        TEQ     r11, r12                        ; see if last one matched
                                                ; (we always load at least one!)
60
        LDREQ   r12, [r10, #CAM_PageFlags]      ; if match, then r12 = PPL
        SUBEQ   r10, r10, r14                   ; and page number=(r10-r14)>>3
        MOVEQ   r10, r10, LSR #CAM_EntrySizeLog2

        MOVNE   r10, #-1                        ; else unknown page number indicator
        MOVNE   r12, #3                         ; and PPL=3 (no user access)

        STMIA   r0!, {r10-r12}                  ; store all 3 words
        B       %BT10                           ; and go back for another one

;**************************************************************************
; SWI SetMemMapEntries: R0 pointer to list of CAM page/address/PPL triads,
;  terminated by -1.
; address of -1 means "put the page out of the way"
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; note, if ChocolateAMB, no MakeHonest consideration here, this SWI just
; changes the mapping of pages regardless of their current mapping, and
; assumes the caller knows what he is doing (ho ho)
;

SetMemMapEntries_Code  ROUT
        Push    "r0-r6, r9, lr"
        MOV     r12, r0

; BangCamUpdate takes entry no in r2, logaddr to set to in r3, r11 = PPL
; corrupts r0,r1,r4,r6

        LDR     r9, =ZeroPage
        LDR     r5, [r9, #MaxCamEntry]
        LDR     r9, [r9, #CamEntriesPointer]
        ADD     r9, r9, #CAM_PageFlags
01
        LDR     r2, [r12], #4
        CMP     r2, r5
        BHI     %FT02                   ; finished
        LDMIA   r12!, {r3, r11}
        CMP     r3, #-1
        LDRHS   r3, =DuffEntry
        MOVHS   r11, #AreaFlags_Duff
        ; Ensure PMP membership flag is retained - just in case caller doesn't
        ; know what he's doing
        LDR     r0, [r9, r2, LSL #CAM_EntrySizeLog2]
        AND     r0, r0, #DynAreaFlags_PMP
        BIC     r11, r11, #DynAreaFlags_PMP
        ORR     r11, r11, r0
        BL      BangCamUpdate
        B       %BT01
02
        Pull    "r0-r6, r9, lr"
        ExitSWIHandler

        LTORG



;**************************************************************************
;
;       DynamicAreaSWI - Code to handle SWI OS_DynamicArea
;
; in:   r0 = reason code
;       Other registers depend on reason code
;
; out:  Depends on reason code
;


DynArea_NewAreas *      &100            ; Allocated area numbers start here
DynArea_NewAreasBase *  &04000000       ; Allocated area addresses start here
DynArea_PMP_BigPageCount * 1:SHL:(31-12) ; If PMP has >= this many pages...
DynArea_PMP_BigByteCount * &7FFFF000     ; Then convert to this byte value

;
; Internal page flags (note - may overlap DA flags)
;
TempUncacheableShift            * 16
PageFlags_TempUncacheableBits   * 15 :SHL: TempUncacheableShift    ; temporary count of uncacheability, used by DMA mgr (via OS_Memory 0)
PageFlags_Required              *  1 :SHL: 21                      ; physical page asked for by handler (only set temporarily)

;
; Temporary flags only used by kernel (note - may overlap DA flags)
;
PageFlags_Unsafe                *  1 :SHL: 31                      ; skip cache/TLB maintenance in BangCamUpdate. flag not saved to CAM map.

; Mask to convert DANode_Flags to page flags (i.e. flags that are common between the two)
DynAreaFlags_AccessMask * DynAreaFlags_APBits :OR: DynAreaFlags_NotBufferable :OR: DynAreaFlags_NotCacheable :OR: DynAreaFlags_DoublyMapped :OR: DynAreaFlags_CPBits :OR: DynAreaFlags_PMP
; PMP LogOp can specify these flags
DynAreaFlags_PMPLogOpAccessMask * (DynAreaFlags_AccessMask :OR: PageFlags_Unavailable) :AND: :NOT: (DynAreaFlags_DoublyMapped :OR: DynAreaFlags_PMP)
; PMP PhysOp can specify these flags
DynAreaFlags_PMPPhysOpAccessMask * PageFlags_Unavailable


DynamicAreaSWI Entry
        BL      DynAreaSub
        PullEnv
        ORRVS   lr, lr, #V_bit
        ExitSWIHandler

DynAreaSub
        CMP     r0, #DAReason_Limit
        ADDCC   pc, pc, r0, LSL #2
        B       DynArea_Unknown
        B       DynArea_Create
        B       DynArea_Remove
        B       DynArea_GetInfo
        B       DynArea_Enumerate
        B       DynArea_Renumber
 [ ShrinkableDAs
        B       DynArea_ReturnFree
 |
        B       DynArea_Unknown
 ]
 [ DynArea_QuickHandles
        B       DynArea_GetChangeInfo
        B       DynArea_EnumerateInfo
        B       DynArea_SetClamps
 |
        B       DynArea_Unknown
        B       DynArea_Unknown
        B       DynArea_Unknown
 ]
 [ DA_Batman
        B       DynArea_SparseClaim
        B       DynArea_SparseRelease
 |
        B       DynArea_Unknown
        B       DynArea_Unknown
 ]
        B       DynArea_Unknown ; 11
        B       DynArea_Unknown ; |
        B       DynArea_Unknown ; |
        B       DynArea_Unknown ; | 
        B       DynArea_Unknown ; |--Reserved for ROL 
        B       DynArea_Unknown ; |
        B       DynArea_Unknown ; |
        B       DynArea_Unknown ; |
        B       DynArea_Unknown ; 19
        B       DynArea_Locate
        B       DynArea_PMP_PhysOp
        B       DynArea_PMP_LogOp
        B       DynArea_PMP_Resize
        B       DynArea_PMP_GetInfo
        B       DynArea_PMP_GetPages

;
; unknown OS_DynamicArea reason code
;
DynArea_Unknown
        ADRL    r0, ErrorBlock_HeapBadReason
DynArea_TranslateAndReturnError
      [ International
        Push    lr
        BL      TranslateError
        Pull    lr
      ]
DynArea_ReturnError
        SETV
        MOV     pc, lr

;**************************************************************************
;
;       DynArea_Create - Create a dynamic area
;
;       Internal routine called by DynamicAreaSWI and by reset code
;
; in:   r0 = reason code (0)
;       r1 = new area number, or -1 => RISC OS allocates number
;       r2 = initial size of area (in bytes)
;       r3 = base logical address of area, or -1 => RISC OS allocates address space
;       r4 = area flags
;               bits 0..3 = access privileges
;               bit  4 = 1 => not bufferable
;               bit  5 = 1 => not cacheable
;               bit  6 = 0 => area is singly mapped
;                      = 1 => area is doubly mapped
;               bit  7 = 1 => area is not user draggable in TaskManager window
;               bit  8 = 1 => area may require specific physical pages
;               bit  9 = 1 => area is shrinkable (only implemented if ShrinkableDAs)
;               bit 10 = 1 => area may be sparsely mapped (only implemented if DA_Batman)
;               bit 11 = 1 => area is bound to client application (allows areas to be overlayed in address space)
;                             not implemented yet, but declared in public API for Ursula
;               bits 12..14 => cache policy (if bits 4 or 5 set)
;               bit 15 = 1 => area requires DMA capable pages (is bit 12 in ROL's OS!)
;               bits 16-19 used by ROL
;               bit 20 = 1 => area is backed by physical memory pool
;               other bits reserved for future expansion + internal page flags (should be 0)
;
;       r5 = maximum size of logical area, or -1 for total RAM size
;       r6 -> area handler routine
;       r7 = workspace pointer for area handler (-1 => use base address)
;       r8 -> area description string (null terminated) (gets copied)
;       r9 = initial physical area size limit, in pages (physical memory pools), otherwise ignored
;
; out:  r1 = given or allocated area number
;       r3 = given or allocated base address of area
;       r5 = given or allocated maximum size
;       r0, r2, r4, r6-r9 preserved
;       r10-r12 may be corrupted
;

DynArea_Create Entry "r2,r6-r8"
        CMP     r1, #-1         ; do we have to allocate a new area number
        BEQ     %FT10

  [ DynArea_QuickHandles
        CMP     r1, #DynArea_NewAreas
        BLO     %FT06
        CMP     r1, #DynArea_NewAreas+DynArea_NumQHandles
        BLO     %FT08           ; can't choose your own quick handle
  ]

06
  [ DynArea_QuickHandles
        BL      QCheckAreaNumber ; see if area number is unique
  |
        BL      CheckAreaNumber ; see if area number is unique
  ]
        BCC     %FT20           ; didn't find it, so OK

08
        ADR     r0, ErrorBlock_AreaAlreadyExists
DynArea_ErrorTranslateAndExit
        PullEnv
        B       DynArea_TranslateAndReturnError

        MakeErrorBlock  AreaAlreadyExists
        MakeErrorBlock  AreaNotOnPageBdy
        MakeErrorBlock  OverlappingAreas
        MakeErrorBlock  CantAllocateArea
        MakeErrorBlock  CantAllocateLevel2
        MakeErrorBlock  UnknownAreaHandler
        MakeErrorBlock  BadDynamicAreaOptions
        MakeErrorBlock  BadPageNumber

; we have to allocate an area number for him

  [ DynArea_QuickHandles
10
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws ]
        LDR     r1, DynArea_FreeQHandles          ;get index of next available quick handle, if any free
        CMP     r1, #0
        ADDNE   r1, r1, #DynArea_NewAreas-1       ;compute quick handle from index
        BNE     %FT20
        LDR     r1, DynArea_TreacleGuess          ;last non-quick number allocated
12
        ADD     r1, r1, #1                        ; increment for next guess (collisions should be *very* rare)
        CMP     r1, #DynArea_NewAreas+DynArea_NumQHandles
        MOVLO   r1, #DynArea_NewAreas+DynArea_NumQHandles
        BL      QCheckAreaNumber
        BCS     %BT12                             ; and try again
  |
10
        MOV     r1, #DynArea_NewAreas
12
        BL      CheckAreaNumber
        ADDCS   r1, r1, #1      ; that area number already exists, so increment
        BCS     %BT12           ; and try again
  ]

20

; Check PMP settings
; If PMP is requested:
; * Must require specific pages
; * Mustn't be sparse
; * Mustn't be doubly mapped
; * Mustn't be requesting DMA auto-alloc
; * Must be zero initial size
; * Must have handler code
; Some of these restrictions may be lifted in future (e.g. if not requesting specific pages, kernel could implement OS_ChangeDynamicArea?)
        TST     r4, #DynAreaFlags_PMP
        BEQ     %FT21
        LDR     r11, =DynAreaFlags_DoublyMapped+DynAreaFlags_NeedsSpecificPages+DynAreaFlags_SparseMap+DynAreaFlags_NeedsDMA
        AND     r11, r4, r11
        TEQ     r11, #DynAreaFlags_NeedsSpecificPages
        TEQEQ   r2, #0
        ADRNE   r0, ErrorBlock_BadDynamicAreaOptions
        BNE     DynArea_ErrorTranslateAndExit
        TEQ     r6, #0
        ADREQ   r0, ErrorBlock_BadDynamicAreaOptions
        BEQ     DynArea_ErrorTranslateAndExit
21

; Check cacheable doubly-mapped area restrictions
; * On ARMv5 and below we disallow cacheable doubly-mapped areas outright, because the virtually tagged caches simply can't deal with them (at least when it comes to writes)
; * ARMv6 can support cacheable doubly-mapped areas, but only if we comply with the page colouring restrictions, which is something we currently don't do. So disallow there as well.
; * ARMv7+ doesn't have page colouring restrictions, but due to the potential of virtually tagged instruction caches (which would complicate OS_SynchroniseCodeAreas), for simplicity we only allow the area to be cacheable if it's non-executable
        AND     r11, r4, #DynAreaFlags_DoublyMapped+DynAreaFlags_NotCacheable
        TEQ     r11, #DynAreaFlags_DoublyMapped
        BNE     %FT22
        ; Cheesy architecture check: check the identified cache/ARMop type
        LDR     r11, =ZeroPage
        LDRB    lr, [r11, #Cache_Type]
        TEQ     lr, #CT_ctype_WB_CR7_Lx
        ADRNE   r0, ErrorBlock_BadDynamicAreaOptions
        BNE     DynArea_ErrorTranslateAndExit
        ; Check the supplied access policy is XN
        LDR     r11, [r11, #MMU_PPLAccess]
        AND     lr, r4, #DynAreaFlags_APBits
        LDR     r11, [r11, lr, LSL #2]
        TST     r11, #CMA_Partially_UserXN+CMA_Partially_PrivXN ; n.b. XN flag sense is inverted in PPLAccess, so NE means executable
        ADRNE   r0, ErrorBlock_BadDynamicAreaOptions
        BNE     DynArea_ErrorTranslateAndExit        
22

; now validate maximum size of area

  [ DynArea_QuickHandles
    ;
    ; apply clamps on max size, as set by last call to OS_DynamicArea 8
    ;
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
    [ DA_Batman
        TST     r4, #DynAreaFlags_SparseMap
        BEQ     DAC_notsparse
        LDR     r10, DynArea_OD8Clamp3   ; clamp for sparse dynamic area
        CMP     r5, r10                  ; if requested max size is > relevant clamp
        MOVHI   r5, r10                  ; then clamp it!
        LDR     r10, [sp]                ; requested initial size, from stack
        CMP     r5, r10
        MOVLO   r5, r10                  ; we must try to honour initial size (allowed to break clamp)
        LDR     r10, =ZeroPage
        LDR     r11, [r10, #Page_Size]
        B       DAC_roundup
DAC_notsparse
    ]
        CMP     r5, #-1
        LDREQ   r10, DynArea_OD8Clamp1   ; clamp for max size requested of -1
        LDRNE   r10, DynArea_OD8Clamp2   ; clamp for max size requested of some specific value
        CMP     r5, r10                  ; if requested max size is > relevant clamp
        MOVHI   r5, r10                  ; then clamp it!
        LDR     r10, [sp]                ; requested initial size, from stack
        CMP     r5, r10
        MOVLO   r5, r10                  ; we must try to honour initial size (allowed to break clamp)
  ]

        LDR     r10, =ZeroPage
        LDR     r11, [r10, #Page_Size]
        LDR     r10, [r10, #RAMLIMIT]   ; get total RAM size
        CMP     r5, r10                 ; if requested maximum size is > total
        MOVHI   r5, r10                 ; then set max to total (NB. -1 passed in always yields HI)

DAC_roundup
        SUB     r10, r11, #1            ; also round up to a page multiple
        ADD     r5, r5, r10
        BIC     r5, r5, r10

; now see if we have to allocate a logical address space
        TEQ     r5, #0                  ; If no logical size (i.e. purely physical PMP)
        MOVEQ   r3, #0                  ; Then set base addr to 0
        BEQ     %FT41                   ; And skip straight to claiming the DANode

        CMP     r3, #-1                 ; if we are to allocate the address space
        BEQ     %FT30                   ; then go do it

; otherwise we must check that the address does not clash with anything else

        TST     r3, r10                         ; does it start on a page boundary
        ADRNE   r0, ErrorBlock_AreaNotOnPageBdy ; if not then error
        BNE     DynArea_ErrorTranslateAndExit

        BL      CheckForOverlappingAreas        ; in: r3 = address, r4 = flags, r5 = size; out: if error, r0->error, V=1
        BVC     %FT40
25
        PullEnv
        B       DynArea_ReturnError

30
        BL      AllocateAreaAddress             ; in: r4 = flags, r5 = size of area needed; out: r3, or V=1, r0->error
        BVS     %BT25
40
        BL      AllocateBackingLevel2           ; in: r3 = address, r4 = flags, r5 = size; out: VS if error
        BVS     %BT25

41
        Push    "r0,r1,r3"
  [ DynArea_QuickHandles
    ;we save work and reduce stress on system heap by claiming only one block, consisting of node followed by
    ;string space (always maximum length, but typically not overly wasteful compared to 2nd block overhead)
    ;
        MOV     r3, #DANode_NodeSize + DynArea_MaxNameLength + 1
  |
        MOV     r3, #DANode_NodeSize
  ]
        BL      ClaimSysHeapNode                ; out: r2 -> node
        STRVS   r0, [sp]
        Pull    "r0,r1,r3"
        BVS     %BT25                           ; failed to claim node

; now store data in node (could probably use STM if we shuffled things around)

        CMP     r7, #-1                         ; if workspace ptr = -1
        MOVEQ   r7, r3                          ; then use base address

        STR     r1, [r2, #DANode_Number]
        STR     r3, [r2, #DANode_Base]
  [ DA_Batman
        ;disallow some awkward flag options if SparseMap set (no error), and temporarily create as not sparse
        ;also disallow a DA handler
        TST     r4, #DynAreaFlags_SparseMap
        STREQ   r4, [r2, #DANode_Flags]
        BICNE   r7, r4, #DynAreaFlags_DoublyMapped + DynAreaFlags_NeedsSpecificPages + DynAreaFlags_Shrinkable + DynAreaFlags_SparseMap
        ORRNE   r7, r7, #DynAreaFlags_NotUserDraggable
        STRNE   r7, [r2, #DANode_Flags]
        MOVNE   r6, #0
        MOVNE   r7, #0
  |
        STR     r4, [r2, #DANode_Flags]
  ]
        STR     r5, [r2, #DANode_MaxSize]
        STR     r6, [r2, #DANode_Handler]
        STR     r7, [r2, #DANode_Workspace]
        MOV     r7, #0                          ; initial size is zero
        STR     r7, [r2, #DANode_Size]          ; before we grow it
        TST     r4, #DynAreaFlags_PMP
        STR     r7, [r2, #DANode_PMP]
        STREQ   r7, [r2, #DANode_PMPMaxSize]
        STR     r7, [r2, #DANode_PMPSize]
        BEQ     %FT44
        STR     r3, [r2, #DANode_SparseHWM]
        TEQ     r9, #0
        STR     r9, [r2, #DANode_PMPMaxSize]
        BEQ     %FT44
        ; Allocate and initialise PMP for this DA
        Push    "r0-r3"
        LDR     r0, =ZeroPage
        LDR     r0, [r0, #MaxCamEntry]
        CMP     r9, r0
        ADDHI   r9, r0, #1
        MOV     r3, r9, LSL #2
        BL      ClaimSysHeapNode
        BVS     %FT43
        MOV     r10, r2
        MOV     r0, #-1
42
        SUBS    r3, r3, #4
        STR     r0, [r2], #4
        BNE     %BT42
        Pull    "r0-r3"
        STR     r10, [r2, #DANode_PMP]
        B       %FT44
43
        STR     r0, [sp]
        LDR     r2, [sp, #8]
        BL      FreeSysHeapNode
        Pull    "r0-r3"
        SETV
        B       %BT25
44

        ; update lower limit on IO space growth, if this DA exceeds previous limit
      [ ZeroPage <> 0
        LDR     r7, =ZeroPage
      ]
        LDR     r6, [r7, #IOAllocLimit]
        ADD     lr, r3, r5
        CMP     lr, r6
        STRHI   lr, [r7, #IOAllocLimit]

; now make copy of string - first find out length of string

  [ DynArea_QuickHandles

        ADD     r7, r2, #DANode_NodeSize
        STR     r7, [r2, #DANode_Title]
        Push    "r0"
        MOV     r0, #DynArea_MaxNameLength
        TEQ     r8, #0
    [ DynArea_NullNamePtrMeansHexString
        ASSERT  DynArea_MaxNameLength > 8
        BNE     %FT45
        Push    "r1, r2"
        MOV     r0, r1                          ;string is 8-digit hex of DA number
        MOV     r1, r7
        MOV     r2, #DynArea_MaxNameLength+1
        SWI     XOS_ConvertHex8
        Pull    "r1, r2"
        B       %FT55
    |
        BEQ     %FT50                           ;assume NULL ptr to mean no DA name
    ]
45
        LDRB    r6, [r8], #1
        STRB    r6, [r7], #1
        SUB     r0, r0, #1
        TEQ     r6, #0
        TEQNE   r0, #0
        BNE     %BT45
50
        MOV     r0, #0
        STRB    r0, [r7], #1
55
        Pull    "r0"

  |

        MOV     r7, r8
45
        LDRB    r6, [r7], #1
        TEQ     r6, #0
        BNE     %BT45

        Push    "r0-r3"
        SUB     r3, r7, r8                      ; r3 = length inc. term.
        BL      ClaimSysHeapNode
        STRVS   r0, [sp]
        MOV     r7, r2
        Pull    "r0-r3"
        BVS     StringNodeClaimFailed

        STR     r7, [r2, #DANode_Title]
50
        LDRB    r6, [r8], #1                    ; copy string into claimed block
        STRB    r6, [r7], #1
        TEQ     r6, #0
        BNE     %BT50

 ] ;DynArea_QuickHandles

; now put node on list - list is sorted in ascending base address order

        LDR     r8, =ZeroPage+DAList
        LDR     r6, [r2, #DANode_Base]
60
        MOV     r7, r8
        ASSERT  DANode_Link = 0                 ; For picking up pointer to first real node
        LDR     r8, [r7, #DANode_Link]          ; get next node
        TEQ     r8, #0                          ; if no more
        BEQ     %FT70                           ; then put it on here
        LDR     lr, [r8, #DANode_Base]
        CMP     lr, r6                          ; if this one is before ours
        BCC     %BT60                           ; then loop

70
        STR     r8, [r2, #DANode_Link]
        STR     r2, [r7, #DANode_Link]

  [ DynArea_QuickHandles
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        BL      AddDAToAddrLookupTable
        ;so XOS_ChangeDynamicArea can pick up the node we are still creating
        STR     r1, DynArea_CreatingHandle
        STR     r2, DynArea_CreatingPtr
        ;so initial grow won't leave resize signature
        LDR     lr, DynArea_OD6Signature
        ORR     lr, lr, #&80000000
        STR     lr, DynArea_OD6Signature
  ]

; now we need to grow the area to its requested size

        Push    "r0, r1, r2"
        LDR     r0, [r2, #DANode_Number]
        LDR     r1, [sp, #3*4]                  ; reload requested size off stack
        CMP     r1, #0                          ; skip redundant SWI
        SWINE   XOS_ChangeDynamicArea           ; deal with error - r0,r1,r2 still stacked
        BVS     %FT90
        Pull    "r0, r1, r2"

  [ DynArea_QuickHandles
;
; Now put node on alphabetically sorted list
;
        Push    "r3,r4,r5,r7,r8,r9"
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        ADR     r8, DynArea_SortedList - DANode_SortLink ;so that [r8, #DANode_SortLink] addresses list header)
75
        MOV     r7, r8                       ; previous
        LDR     r8, [r7, #DANode_SortLink]
        TEQ     r8, #0
        BEQ     %FT78
        ;ho hum, UK case insensitive string compare
        LDR     r3, [r2, #DANode_Title]
        LDR     r9, [r8, #DANode_Title]
76
        LDRB    r4, [r3],#1
        uk_LowerCase r4,r11
        LDRB    r5, [r9],#1
        uk_LowerCase r5,r11
        CMP     r4, r5
        BNE     %FT77
        CMP     r4, #0
        BNE     %BT76
77
        BHI     %BT75
78
        STR     r2, [r7, #DANode_SortLink]
        STR     r8, [r2, #DANode_SortLink]
79
        Pull    "r3,r4,r5,r7,r8,r9"
  ] ;DynArea_QuickHandles

  [ DA_Batman
        TST     r4, #DynAreaFlags_SparseMap
        LDRNE   r11, [r2, #DANode_Flags]
        ORRNE   r11, r11, #DynAreaFlags_SparseMap ; set this in node now (after initial grow)
        STRNE   r11, [r2, #DANode_Flags]
        LDRNE   r11, [r2, #DANode_Size]
        LDRNE   lr,  [r2, #DANode_Base]
        ADDNE   r11, r11, lr
        STRNE   r11, [r2, #DANode_SparseHWM]      ; initial high water mark
  ]

  [ DynArea_QuickHandles
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]

        TST     r4, #DynAreaFlags_Shrinkable
        LDRNE   lr, DynArea_ShrinkableSubList
        STRNE   lr, [r2, #DANode_SubLink]
        STRNE   r2, DynArea_ShrinkableSubList   ;link onto front of Shrinkable sublist if Shrinkable

        MOV     lr, #-1
        STR     lr, DynArea_CreatingHandle      ;invalidate this now
        CMP     r1, #ChangeDyn_MaxArea
        BHI     %FT72
        ADR     lr, DynArea_SysQHandleArray
        STR     r2, [lr, r1, LSL #2]            ;system handle - store ptr to node for quick reference
        B       %FT80
72
        LDR     lr, DynArea_OD6Signature
        STR     lr, DynArea_OD6PrevSignature
        ORR     lr, lr, #1
        STR     lr, DynArea_OD6Signature
        STR     r1, DynArea_OD6Handle
        CMP     r1, #DynArea_NewAreas
        BLO     %FT80
        CMP     r1, #DynArea_NewAreas+DynArea_NumQHandles
        BHS     %FT74
        SUB     r10, r1, #DynArea_NewAreas
        ADR     lr, DynArea_QHandleArray
        LDR     r6, [lr, r10, LSL #2]           ;pick up index of next free quick handle
        STR     r6, DynArea_FreeQHandles        ;store as index of first free quick handle
        STR     r2, [lr, r10, LSL #2]           ;store ptr to node for quick reference
        B       %FT80
74
        LDR     r10, DynArea_TreacleGuess
        ADD     r10, r10, #1
        STR     r10, DynArea_TreacleGuess       ;non-quick handle allocated, increment for next allocate
80
  ] ;DynArea_QuickHandles


; Now issue service to tell TaskManager about it

        Push    "r0, r1, r2"
        MOV     r2, r1                          ; r2 = area number
        MOV     r1, #Service_DynamicAreaCreate
        BL      Issue_Service
        Pull    "r0, r1, r2"

        CLRV
        EXIT

90

; The dynamic area is not being created, because we failed to grow the area to the required size.
; The area itself will have no memory allocated to it (since if grow fails it doesn't move any).
; We must delink the node from our list, free the string node, and then the area node itself.

        STR     r0, [sp, #0*4]                  ; remember error pointer in stacked r0
        STR     r8, [r7, #DANode_Link]          ; delink area
  [ :LNOT: DynArea_QuickHandles
        LDR     r2, [r2, #DANode_Title]
        BL      FreeSysHeapNode                 ; free title string node
  ]
        Pull    "r0, r1, r2"                    ; pull stacked registers, and drop thru to...

  [ :LNOT: DynArea_QuickHandles
; The dynamic area is not being created, because there is no room to allocate space for the title string
; We must free the DANode we have allocated
; It would be nice to also free the backing L2, but we'll leave that for now.

; in: r2 -> DANode

StringNodeClaimFailed
  ]

        Push    "r0, r1"
        BL      FreeSysHeapNode
        Pull    "r0, r1"
  [ DynArea_QuickHandles
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        MOV     lr, #-1
        STR     lr, DynArea_CreatingHandle
  ]
        PullEnv
        B       DynArea_ReturnError

        LTORG

; Add a dynamic area to the quick address lookup table
; In:
;  R2 = DANode ptr
;  R11 = DynArea_ws
AddDAToAddrLookupTable ROUT
        Entry   "r0-r1,r3,r6"
        LDR     r3, [r2, #DANode_MaxSize]
        ADRL    r0, DynArea_AddrLookup
        TEQ     r3, #0
        LDR     r1, [r2, #DANode_Flags]
        BEQ     %FT90
        LDR     r6, [r2, #DANode_Base]
        TST     r1, #DynAreaFlags_DoublyMapped
        SUBNE   r6, r6, r3                      ; Get true start address
        MOVNE   r3, r3, LSL #1
        AND     r1, r6, #DynArea_AddrLookupMask ; Round down start address
        ADD     lr, r6, r3
        AND     r3, lr, #DynArea_AddrLookupMask
        TEQ     lr, r3
        ADDNE   r3, r3, #DynArea_AddrLookupSize ; Round up end address
        SUB     r3, r3, r1
        ADD     r0, r0, r1, LSR #30-DynArea_AddrLookupBits
71
        LDR     lr, [r0], #4
        TEQ     lr, #0
        STREQ   r2, [r0, #-4]
        BEQ     %FT72
        LDR     lr, [lr, #DANode_Base]
        CMP     lr, r6
        STRHI   r2, [r0, #-4]                   ; Update LUT if current entry starts after us
72
        SUBS    r3, r3, #DynArea_AddrLookupSize
        BNE     %BT71
90
        EXIT

;**************************************************************************
;
;       DynArea_Remove - Remove a dynamic area
;
;       Internal routine called by DynamicAreaSWI
;
; in:   r0 = reason code (1)
;       r1 = area number
;
; out:  r10-r12 may be corrupted
;       All other registers preserved
;

DynArea_Remove Entry

        ;*MUST NOT USE QCheckAreaNumber* (need r11 = previous)
        BL      CheckAreaNumber         ; check that area is there
        BCC     UnknownDyn              ; [not found]

  [ DA_Batman
        LDR     lr,[r10,#DANode_Flags]
        TST     lr,#DynAreaFlags_SparseMap
        BEQ     DAR_notsparse
        Push    "r0,r2-r3"
        MOV     r0,#DAReason_SparseRelease
        LDR     r2,[r10,#DANode_Base]
        LDR     r3,[r10,#DANode_MaxSize]
        SWI     XOS_DynamicArea            ;release all pages in sparse area
        STRVS   r0,[SP]
        Pull    "r0,r2-r3"
        EXIT    VS
        B       DAR_delink
DAR_notsparse
        TST     lr, #DynAreaFlags_PMP
        BEQ     DAR_notPMP
        ; Unmap all pages from logical space
        ; This is a bit of a simplistic approach - request for everything to
        ; be unmapped and leave it to PMP_LogOp to detect which pages are and
        ; aren't there
        Push    "r1-r8"
        LDR     r6, [r10, #DANode_Base]
        MOV     r3, #0
        LDR     r4, [r10, #DANode_SparseHWM] ; Assume HWM valid
        MOV     r5, #-1
        SUB     r4, r4, r6
        MOV     r6, #0
        MOV     r4, r4, LSR #12
        MOV     r8, sp
DAR_PMP_logloop
        SUBS    r4, r4, #1
        BLT     DAR_PMP_logunmap
        STMDB   sp!, {r4-r6}
        ADD     r3, r3, #1
        CMP     r3, #85 ; Limit to 1K stack
        BLT     DAR_PMP_logloop
DAR_PMP_logunmap
        MOV     r0, #DAReason_PMP_LogOp
        MOV     r2, sp
        SWI     XOS_DynamicArea
        MOV     sp, r8
        Pull    "r1-r8", VS
        EXIT    VS
        CMP     r4, #0
        MOV     r3, #0
        BGT     DAR_PMP_logloop
        ; Pages are all unmapped, now release them from the PMP
        LDR     r4, [r10, #DANode_PMPMaxSize]
        LDR     r7, [r10, #DANode_PMP]
        MOV     r3, #0
DAR_PMP_physloop
        SUBS    r4, r4, #1
        BLT     DAR_PMP_physunmap
        LDR     lr, [r7, r4, LSL #2]
        CMP     lr, #-1                 ; Save some effort and only release pages which exist
        STMNEDB sp!, {r4-r6}
        ADDNE   r3, r3, #1
        CMP     r3, #85 ; Limit to 1K stack
        BLT     DAR_PMP_physloop
DAR_PMP_physunmap
        MOV     r0, #DAReason_PMP_PhysOp
        MOV     r2, sp
        SWI     XOS_DynamicArea
        MOV     sp, r8
        Pull    "r1-r7", VS
        EXIT    VS
        CMP     r4, #0
        MOV     r3, #0
        BGT     DAR_PMP_physloop
        ; All pages released, safe to free area
        Pull    "r1-r8"
        MOV     r0, #DAReason_Remove
        B       DAR_delink
DAR_notPMP
  ]

  [ DynArea_QuickHandles
        Push    "r11"
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        ;so final shrink won't leave resize signature
        LDR     lr, DynArea_OD6Signature
        ORR     lr, lr, #&80000000
        STR     lr, DynArea_OD6Signature
        Pull    "r11"
  ]

; First try to shrink area to zero size

        Push    "r0-r2"
        MOV     r0, r1                  ; area number
        LDR     r2, [r10, #DANode_Size] ; get current size
        RSBS    r1, r2, #0              ; negate it
        SWINE   XOS_ChangeDynamicArea
        BVS     %FT80
        Pull    "r0-r2"

DAR_delink

  [ DynArea_QuickHandles
;
; delink from sorted list
;
        Push    "r0-r4,r7,r8,r11"
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        ADR     r8, DynArea_SortedList - DANode_SortLink ;so that [r8, #DANode_SortLink] addresses list header)
DAR_sdloop
        MOV     r7, r8                      ;previous
        LDR     r8, [r7, #DANode_SortLink]
        TEQ     r8, #0                      ;just in case not on list, shouldn't happen
        BEQ     DAR_sddone
        TEQ     r8, r10
        BNE     DAR_sdloop
        LDR     r8, [r8, #DANode_SortLink]
        STR     r8, [r7, #DANode_SortLink]
DAR_sddone
; Delink from address lookup table
        LDR     r3, [r10, #DANode_MaxSize]
        ADRL    r0, DynArea_AddrLookup
        TEQ     r3, #0
        LDR     r1, [r10, #DANode_Flags]
        BEQ     DAR_addone
        LDR     r2, [r10, #DANode_Base]
        TST     r1, #DynAreaFlags_DoublyMapped
        SUBNE   r2, r2, r3                      ; Get true start address
        MOVNE   r3, r3, LSL #1
        AND     r1, r2, #DynArea_AddrLookupMask ; Round down start address
        ADD     lr, r2, r3
        AND     r3, lr, #DynArea_AddrLookupMask
        TEQ     lr, r3
        ADDNE   r3, r3, #DynArea_AddrLookupSize ; Round up end address
        SUB     r3, r3, r1
        ADD     r0, r0, r1, LSR #30-DynArea_AddrLookupBits
DAR_adloop
        LDR     lr, [r0], #4
        TEQ     lr, r10
        BNE     DAR_adnext
        ; Update to point to next DA, or null if next is outside this chunk
        LDR     lr, [lr, #DANode_Link]
        TEQ     lr, #0
        STREQ   lr, [r0, #-4]
        BEQ     DAR_adnext
        LDR     r4, [lr, #DANode_Flags]
        LDR     r2, [lr, #DANode_Base]
        TST     r4, #DynAreaFlags_DoublyMapped
        LDRNE   r4, [lr, #DANode_MaxSize]
        SUBNE   r2, r2, r4
        AND     r2, r2, #DynArea_AddrLookupMask
        TEQ     r2, r1
        MOVNE   lr, #0
        STR     lr, [r0, #-4]
DAR_adnext
        SUBS    r3, r3, #DynArea_AddrLookupSize
        ADD     r1, r1, #DynArea_AddrLookupSize
        BNE     DAR_adloop
DAR_addone
        Pull    "r0-r4,r7,r8,r11"

  ] ;DynArea_QuickHandles

; Now just de-link from list (r10 -> node, r11 -> prev)

        LDR     lr, [r10, #DANode_Link] ; store our link
        STR     lr, [r11, #DANode_Link] ; in prev link

  [ DynArea_QuickHandles
        ;if it is a Shrinkable area, find on Shrinkable sublist and remove it
        Push    "r0-r2, r11"
        LDR     r0, [r10, #DANode_Flags]
        TST     r0, #DynAreaFlags_Shrinkable
        BEQ     %FT06
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        ADR     r1, DynArea_ShrinkableSubList
        LDR     r2, [r1]
04
        CMP     r2, r10
        LDREQ   r2, [r2, #DANode_SubLink]
        STREQ   r2, [r1]
        BEQ     %FT06
        ADD     r1, r2, #DANode_SubLink
        LDR     r2, [r2, #DANode_SubLink]
        B       %BT04
06
        Pull    "r0-r2, r11"
  ]

        Push    "r0-r2"
  [ :LNOT: DynArea_QuickHandles
        LDR     r2, [r10, #DANode_Title]        ; free title string block
        BL      FreeSysHeapNode
  ]
        LDR     r2, [r10, #DANode_PMP]
        CMP     r2, #0
        BLNE    FreeSysHeapNode
        MOV     r2, r10                         ; and free node block
        BL      FreeSysHeapNode
        Pull    "r0-r2"

  [ DynArea_QuickHandles
        Push    "r2, r3"
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        MOV     r2,#-1
        STR     r2, DynArea_CreatingHandle                ; invalidate these, just in case
        STR     r2, DynArea_LastTreacleHandle
        STR     r2, DynArea_LastEnumHandle
        CMP     r1, #ChangeDyn_MaxArea
        BLS     %FT08                                     ; system area being removed
        LDR     r2, DynArea_OD6Signature
        STR     r2, DynArea_OD6PrevSignature
        ORR     r2, r2, #2
        STR     r2, DynArea_OD6Signature
        STR     r1, DynArea_OD6Handle
        CMP     r1, #DynArea_NewAreas
        BLO     %FT10
        CMP     r1, #DynArea_NewAreas+DynArea_NumQHandles
        BHS     %FT10
        SUB     r2, r1, #DynArea_NewAreas-1               ; index of quick handle
        ADR     r10, DynArea_FreeQHandles                 ; so we can index array from 1
        LDR     r3, DynArea_FreeQHandles
        STR     r3, [r10, r2, LSL #2]
        STR     r2, DynArea_FreeQHandles                  ; put on front of free list
        B       %FT10
08
        ADR     r10, DynArea_SysQHandleArray
        MOV     r2,  #0
        STR     r2,  [r10, r1, LSL #2]                    ; reset system Qhandle
10
        Pull    "r2, r3"

  ]

; Issue service to tell TaskManager

        Push    "r0, r1, r2"
        MOV     r2, r1
        MOV     r1, #Service_DynamicAreaRemove
        BL      Issue_Service
        Pull    "r0, r1, r2"

        CLRV
        EXIT

; come here if shrink failed - r0-r2 stacked

80
        STR     r0, [sp]                ; overwrite stacked r0 with error pointer
        LDR     r0, [sp, #1*4]          ; reload area number
        LDR     r1, [r10, #DANode_Size] ; get size after failed shrink
        SUB     r1, r2, r1              ; change needed to restore original size
        SWI     XOS_ChangeDynamicArea   ; ignore any error from this
        Pull    "r0-r2"
        SETV
        EXIT

UnknownDyn
        ADRL    r0, ErrorBlock_BadDynamicArea
 [ International
        BL      TranslateError
 |
        SETV
 ]
        EXIT

;**************************************************************************
;
;       DynArea_GetInfo - Get info on a dynamic area
;
;       Internal routine called by DynamicAreaSWI
;
; in:   r0 = reason code (2)
;       r1 = area number
;
; out:  r2 = current size of area
;       r3 = base logical address
;       r4 = area flags
;       r5 = maximum size of area
;       r6 -> area handler routine
;       r7 = workspace pointer
;       r8 -> title string
;       r10-r12 may be corrupted
;       All other registers preserved
;

DynArea_GetInfo ALTENTRY
  [ DynArea_QuickHandles
        BL      QCheckAreaNumber        ; check area exists
  |
        BL      CheckAreaNumber         ; check area exists
  ]
        BCC     UnknownDyn              ; [it doesn't]

; r10 -> node, so get info

        LDR     r4, [r10, #DANode_Flags]
        LDR     r3, [r10, #DANode_Base]
        LDR     r6, [r10, #DANode_Handler]
        TST     r4, #DynAreaFlags_PMP
        LDREQ   r2, [r10, #DANode_Size]
        LDREQ   r5, [r10, #DANode_MaxSize]
        BEQ     %FT10
        LDR     r2, [r10, #DANode_PMPSize]
        LDR     r5, [r10, #DANode_PMPMaxSize]
        CMP     r2, #DynArea_PMP_BigPageCount
        MOVLO   r2, r2, LSL #12
        LDRHS   r2, =DynArea_PMP_BigByteCount
        CMP     r5, #DynArea_PMP_BigPageCount
        MOVLO   r5, r5, LSL #12
        LDRHS   r5, =DynArea_PMP_BigByteCount
10
        LDR     r7, [r10, #DANode_Workspace]
        LDR     r8, [r10, #DANode_Title]
        CLRV
        EXIT

;**************************************************************************
;
;       DynArea_GetChangeInfo
;
;       Get info on changes to *non-system* dynamic areas
;       Reserved for Acorn use (intended for TaskManager, can only serve one client)
;
;       Internal routine called by DynamicAreaSWI
;
; in:   r0 = reason code (6)
;
; out:  r1 = Number of affected area, if a single change has occurred since last call,
;          = -1, if no changes or more than one change have occurred
;       r2 = signature of changes to non-system dynamic areas since last call to
;            OS_DynamicArea 6
;            bit 0 = 1 if any non-system areas have been created
;            bit 1 = 1 if any non-system areas have been removed
;            bit 2 = 1 if any non-system areas have been resized
;            bit 3 = 1 if any non-system areas have been renumbered
;            bits 4-31 reserved (undefined)
;
;Notes:
; (1) bit 2 of r2 excludes the initial grow of a created area, and the final
;     shrink of a removed area
; (2) if a single renumber has occurred, r1 is the old number

  [ DynArea_QuickHandles

DynArea_GetChangeInfo ROUT
        Push    "lr"
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        LDR     r1, DynArea_OD6Handle
        LDR     r2, DynArea_OD6Signature
        LDR     lr, DynArea_OD6PrevSignature
        CMP     lr, #0
        MOVNE   r1, #-1
        CMP     r2, #0
        MOVEQ   r1, #-1
        MOV     lr, #0
        STR     lr, DynArea_OD6Signature
        STR     lr, DynArea_OD6PrevSignature
        CLRV
        Pull    "PC"

  ] ;DynArea_QuickHandles

;**************************************************************************
;
;       DynArea_EnumerateInfo
;
;       Enumerate *non-system* dynamic areas, returning selected info
;       Reserved for Acorn use (intended for TaskManager)
;
; in:   r0 = reason code (7)
;       r1 = -1 to start enumeration, or area number to continue from
;
; out:  r1 = number of next area found, or -1 if no more areas
;       r2 = current size of area, if area found
;       r3 = base logical address, if area found
;       r4 = area flags, if area found
;       r5 = maximum size of area, if area found
;       r6 -> title string, if area found
;
;Notes:
; (1) r2-r6 on exit are undefined if r1 = -1
;

  [ DynArea_QuickHandles

DynArea_EnumerateInfo ROUT
        Push    "lr"

        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]

        CMP     r1, #-1                         ; if starting from beginning
        LDREQ   r10, DynArea_SortedList         ; then load pointer to 1st node on sorted list
        BEQ     %FT10                           ; and skip

        LDR     r10, DynArea_LastEnumHandle
        CMP     r10, r1
        LDREQ   r10, DynArea_LastEnumPtr        ; pick up where we left off
        BEQ     %FT08
        BL      QCheckAreaNumber                ; else check valid area number
        BCC     %FT14

08
        LDR     r10, [r10, #DANode_SortLink]    ; find next one
10
        TEQ     r10, #0                         ; if at end
        MOVEQ   r1, #-1                         ; then return -1
        BEQ     %FT12
        LDR     r1, [r10, #DANode_Number]       ; else return number
        CMP     r1, #ChangeDyn_MaxArea
        BLS     %BT08                           ; skip if system area

        LDR     r4, [r10, #DANode_Flags]        ; return rest of info
        LDR     r3, [r10, #DANode_Base]
        LDR     r6, [r10, #DANode_Title]
        TST     r4, #DynAreaFlags_PMP
        LDREQ   r2, [r10, #DANode_Size]
        LDREQ   r5, [r10, #DANode_MaxSize]
        BEQ     %FT11
        LDR     r2, [r10, #DANode_PMPSize]
        LDR     r5, [r10, #DANode_PMPMaxSize]
        CMP     r2, #DynArea_PMP_BigPageCount
        MOVLO   r2, r2, LSL #12
        LDRHS   r2, =DynArea_PMP_BigByteCount
        CMP     r5, #DynArea_PMP_BigPageCount
        MOVLO   r5, r5, LSL #12
        LDRHS   r5, =DynArea_PMP_BigByteCount
11

        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        STR     r1, DynArea_LastEnumHandle
        STR     r10, DynArea_LastEnumPtr        ; save a lot of messing about on next call
12
        CLRV
        Pull    "PC"

;it's a reserved call, so naff off internationalisation
14
        ADR     r0,DynArea_badei
        SETV
        Pull    "PC"
DynArea_badei
        DCD     0
        DCB     "bad DA number",0
        ALIGN

  ] ;DynArea_QuickHandles

;**************************************************************************
;
;       DynArea_SetClamps
;
;       Set clamps on max size of dynamic areas created by subsequent
;       calls to OS_DynamicArea 0
;
;   On entry
;       R0 = 8 (reason code)
;       R1 = limit on maximum size of (non-Sparse) areas created by
;            OS_DynamicArea 0 with R5 = -1, or 0 to read only
;       R2 = limit on maximum size of (non-Sparse) areas created by
;            OS_DynamicArea 0 with R5 > 0, or 0 to read only
;       R3 = limit on maximum size of Sparse areas created by
;            OS_DynamicArea 0 with R4 bit 10 set, or 0 to read only
;
;   On exit
;       R1 = previous limit for OS_DynamicArea 0 with R5 = -1
;       R2 = previous limit for OS_DynamicArea 0 with R5 > 0
;       R3 = previous limit for OS_DynamicArea 0 with R4 bit 10 set
;
;       Specifying -1 in R1 or R2 means the respective limit
;       is the RAM limit of the machine (this is the default).
;       Specifiying larger than the RAM limit in R1 or R2 is
;       equivalent to specifiying -1.
;
  [ DynArea_QuickHandles

DynArea_SetClamps ROUT
        Push    "r9,lr"

        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]

        LDR     r10, DynArea_OD8Clamp1
        LDR     lr,  DynArea_OD8Clamp2
        LDR     r9,  DynArea_OD8Clamp3

;insist on at least 1M for a clamp value (ignore anything lower)
;
        CMP     r1, #&100000
        STRHS   r1, DynArea_OD8Clamp1
        CMP     r2, #&100000
        STRHS   r2, DynArea_OD8Clamp2
        CMP     r3, #&100000
        STRHS   r3, DynArea_OD8Clamp3

        MOV     r1, r10
        MOV     r2, lr
        MOV     r3, r9

        CLRV
        Pull    "r9,PC"

  ] ;DynArea_QuickHandles

;**************************************************************************

;       DynArea_SparseClaim
;
;  Ensure region of sparse dynamic area is mapped to valid memory
;
; in:   r0 = reason code (9)
;       r1 = area number
;       r2 = base of region to claim
;       r3 = size of region to claim
;
; out:  r0-r3 preserved (error if not all of region successfully mapped)
;       r10-r12 may be corrupted
;
; action: - round base and size to page granularity
;         - scan the L2PT for each page covered
;         - find contiguous fragments of 1 or more pages that are not yet mapped-in
;         - pass each of these fragments as a psuedo DANode to OS_ChangeDynamicArea
;           via special Batcall), to 'grow' pages into each fragment
;
  [ DA_Batman

DynArea_SparseClaim ROUT
        Push    "r0-r9,lr"
        MOV     r4,#1                   ; flags operation as a claim

DynArea_SparseChange                    ; common entry point for claim and release

  [ DynArea_QuickHandles
        BL      QCheckAreaNumber        ; check area exists
  |
        BL      CheckAreaNumber         ; check area exists
  ]
        BCC     DA_naffsparse           ; area not there

        LDR     r9,[r10,#DANode_Flags]
        TST     r9,#DynAreaFlags_SparseMap
        BEQ     DA_naffsparse           ; area not sparse

        MOV     r9,#&1000               ;page size
        SUB     r9,r9,#1
        ADD     r3,r3,r2                ;base+size
        CMP     r4,#1
        BICEQ   r2,r2,r9                ;round base down to page granularity for claim
        ADDEQ   r3,r3,r9
        BICEQ   r3,r3,r9                ;round base+size up to page granularity for claim
        ADDNE   r2,r2,r9
        BICNE   r2,r2,r9                ;round base up to page granularity for release
        BICNE   r3,r3,r9                ;round base+size down to page granularity for release
        SUB     r3,r3,r2                ;rounded size

        ADD     r9,r3,r2
        LDR     r5,[r10,#DANode_Base]
        LDR     r6,[r10,#DANode_MaxSize]
        ADD     r6,r6,r5
        CMP     r2,r5
        CMPHS   r9,r5
        BLO     DA_naffsparse
        CMP     r2,r6
        CMPLS   r9,r6
        BHI     DA_naffsparse

        ADD     r5,r2,r3                   ;base+size of mapping
        LDR     r6,[r10,#DANode_SparseHWM] ;high water mark = highest claim base+size seen
        CMP     r4,#1
        BEQ     %FT08
        CMP     r5,r6
        SUBHI   r3,r6,r2                   ;for release we can save work by trimming to high water mark
        B       %FT09                      ;r3 is now trimmed size (may be <=0 for trim to nothing)
08
        CMP     r5,r6
        STRHI   r5,[r10,#DANode_SparseHWM] ;for claim remember highest base+size as high water mark
09
        SUB     SP,SP,#DANode_NodeSize  ;room for temporary DANode on stack
        MOV     r9,r10                  ;actual sparse area DANode
        MOV     r5,SP
        MOV     r6,#DANode_NodeSize
10
        LDR     r7,[r9],#4           ;copy sparse area node to temp node
        STR     r7,[r5],#4
        SUBS    r6,r6,#4
        BNE     %BT10
        ADD     r3,r2,r3             ;stop address
;
        LDR     r5,=L2PT
        ADD     r5,r5,r2,LSR #10     ;r5 -> L2PT for base (assumes 4k page)
        MOV     r8,r2                ;start address
;
;look for next fragment of region that needs to have mapping change
20
        CMP     r8,r3
        BHS     %FT50                ;done
        LDR     r6,[r5],#4           ;pick-up next L2PT entry
        CMP     r4,#0                ;if operation is a release...
        CMPEQ   r6,#0                ;...and L2PT entry is 0 (not mapped)...
        ADDEQ   r8,r8,#&1000         ;...then skip page (is ok)
        BEQ     %BT20
        CMP     r4,#0                ;if operation is a claim (not 0)...
        CMPNE   r6,#0                ;...and L2PT entry is non-0 (mapped)...
        ADDNE   r8,r8,#&1000         ;...then skip page (is ok)
        BNE     %BT20
        MOV     r1,#&1000            ;else we need to do a change (1 page so far)
30
        ADD     r9,r8,r1
        CMP     r9,r3
        BHS     %FT40
        LDR     r6,[r5],#4           ;pick-up next L2PT entry
        CMP     r4,#1                ;if operation is a release (not 1)...
        CMPNE   r6,#0                ;...and L2PT entry is non-0 (mapped)...
        ADDNE   r1,r1,#&1000         ;...then count page as needing change
        BNE     %BT30
        CMP     r4,#1                ;if operation is a claim...
        CMPEQ   r6,#0                ;...and L2PT entry is 0 (not mapped)...
        ADDEQ   r1,r1,#&1000         ;...then count page as needing change
        BEQ     %BT30
;set up pseudo DA and do Batcall to change mapping of fragment we have found
40
        MOV     r2,SP                  ;temp DANode
        STR     r8,[r2,#DANode_Base]
        ADD     r8,r8,r1
        ADD     r8,r8,#&1000           ;next address to check after fragment
        CMP     r4,#1
        MOVEQ   r9,#0                  ;start size of 0 for claim
        MOVNE   r9,r1                  ;start size of fragment size for release
        STR     r9,[r2,#DANode_Size]
        STR     r1,[r2,#DANode_MaxSize]
        MOV     r0,#ChangeDyn_Batcall
        CMP     r4,#0
        RSBEQ   r1,r1,#0               ;batshrink for release, batgrow for claim
        SWI     XOS_ChangeDynamicArea
        TEQ     r4,#0
        RSBEQ   r1,r1,#0
        LDR     r9,[r10,#DANode_Size]
        ADD     r9,r9,r1
        STR     r9,[r10,#DANode_Size]
        BVC     %BT20
;
50
        ADD     SP,SP,#DANode_NodeSize   ;drop temp DANode
        BVS     %FT52
        BL      DA_sparse_serviceandsig
        Pull    "r0-r9,PC"
;
52
        BL      DA_sparse_serviceandsig
        SETV
        STR     r0,[SP]
        Pull    "r0-r9,PC"

DA_naffsparse
        ADR     r0,DA_naffsparseinnit
        SETV
        STR     r0,[SP]
        Pull    "r0-r9,PC"
DA_naffsparseinnit
        DCD     0
        DCB     "invalid OS_DynamicArea sparse claim/release",0
        ALIGN

DA_sparse_serviceandsig ROUT
        Push    "r0,LR"
        LDR     r1,[r10,#DANode_Number]
   [ DynArea_QuickHandles
        LDR     r11,=ZeroPage
        LDR     r11,[r11, #DynArea_ws]
        LDR     r5,DynArea_OD6Signature
        STR     r5,DynArea_OD6PrevSignature
        ORR     r5,r5,#4                     ;signal a resize
        STR     r5,DynArea_OD6Signature
        STR     r1,DynArea_OD6Handle
   ]
        MOV     r2,r1                    ;area number
        MOV     r0,#0                    ;nominal 'grow/shrink' of 0 for service call
        MOV     r1,#Service_MemoryMoved
        BL      Issue_Service
        Pull    "r0,PC"

  ] ;DA_Batman

;**************************************************************************
;
;       DynArea_SparseRelease
;
;  Allow region of sparse dynamic area to release memory to free pool
;
; in:   r0 = reason code (10)
;       r1 = area number
;       r2 = base of region to release
;       r3 = size of region to release
;
; out:  r0-r3 preserved (error if not all of region successfully released)
;       r10-r12 may be corrupted
;
;
; action: - similar to DynArea_SparseClaim, but does 'shrinks' on fragments
;           that are mapped in

  [ DA_Batman

DynArea_SparseRelease ROUT
        Push    "r0-r9,lr"
        MOV     r4,#0                   ; flags operation as a release
        B       DynArea_SparseChange    ; jump to common code

  ] ;DA_Batman

;**************************************************************************
;
;       DynArea_Enumerate - Enumerate dynamic areas
;
;       Internal routine called by DynamicAreaSWI
;
; in:   r0 = reason code (3)
;       r1 = -1 to start enumeration, or area number to continue from
;
; out:  r1 = next area number or -1 if no next
;       r10-r12 may be corrupted
;       All other registers preserved

DynArea_Enumerate ALTENTRY
  [ DynArea_QuickHandles
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
  ]
        CMP     r1, #-1                         ; if starting from beginning
  [ DynArea_QuickHandles
        LDREQ   r10, DynArea_SortedList         ; then load pointer to 1st node on sorted list
  |
    [ ZeroPage = 0
        LDREQ   r10, [r1, #DAList+1]            ; then load pointer to 1st node
    |
        LDREQ   r10, =ZeroPage
        LDREQ   r10, [r10, #DAList]
    ]
  ]
        BEQ     %FT10                           ; and skip

  [ DynArea_QuickHandles
        LDR     r10, DynArea_LastEnumHandle
        CMP     r10, r1
        LDREQ   r10, DynArea_LastEnumPtr        ; pick up where we left off
        BEQ     %FT08
        BL      QCheckAreaNumber                ; else check valid area number
  |
        BL      CheckAreaNumber                 ; else check valid area number
  ]
        BCC     UnknownDyn                      ; complain if passed in duff area number

08
  [ DynArea_QuickHandles
        LDR     r10, [r10, #DANode_SortLink]    ; find next one
  |
        LDR     r10, [r10, #DANode_Link]        ; find next one
  ]
10
        TEQ     r10, #0                         ; if at end
        MOVEQ   r1, #-1                         ; then return -1
        BEQ     %FT12
        LDR     r1, [r10, #DANode_Number]       ; else return number

  [ DynArea_QuickHandles
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        STR     r1, DynArea_LastEnumHandle
        STR     r10, DynArea_LastEnumPtr        ; save a lot of messing about on next call
  ]
12
        CLRV
        EXIT

;**************************************************************************
;
;       DynArea_Renumber - Renumber dynamic area
;
;       Internal routine called by DynamicAreaSWI
;
; in:   r0 = reason code (4)
;       r1 = old area number
;       r2 = new area number
;

DynArea_Renumber ALTENTRY
        CMP     r1, #ChangeDyn_MaxArea
        BLS     %FT92                           ; can't renumber a system area
        CMP     r1, #ChangeDyn_MaxArea
        BLS     %FT92
  [ DynArea_QuickHandles
        CMP     r1, #DynArea_NewAreas
        BLO     %FT10
        CMP     r1, #DynArea_NewAreas+DynArea_NumQHandles
        BLO     %FT92                           ; can't renumber a quick handle
10
        CMP     r2, #DynArea_NewAreas
        BLO     %FT12
        CMP     r2, #DynArea_NewAreas+DynArea_NumQHandles
        BLO     %FT92                           ; can't choose your own quick handle
12
        BL      QCheckAreaNumber
  |
        BL      CheckAreaNumber                 ; check valid area number
  ]
        BCC     UnknownDyn                      ; [it's not]

        Push    "r1"
        MOV     r12, r10                        ; save pointer to node
        MOV     r1, r2
  [ DynArea_QuickHandles
        BL      QCheckAreaNumber                ; check area r2 doesn't already exist
  |
        BL      CheckAreaNumber                 ; check area r2 doesn't already exist
  ]
        Pull    "r1"
        BCS     %FT90                           ; [area r2 already exists]

        STR     r2, [r12, #DANode_Number]

; Now issue service to tell TaskManager

        Push    "r1-r3"
        MOV     r3, r2                          ; new number
        MOV     r2, r1                          ; old number
        MOV     r1, #Service_DynamicAreaRenumber
        BL      Issue_Service
        Pull    "r1-r3"

  [ DynArea_QuickHandles
        LDR     r11, =ZeroPage                         ; we know system areas cannot be renumbered
        LDR     r11, [r11, #DynArea_ws]
        MOV     r10, #-1
        STR     r10, DynArea_CreatingHandle     ; invalidate these, just in case
        STR     r10, DynArea_LastTreacleHandle
        STR     r10, DynArea_LastEnumHandle
        LDR     lr, DynArea_OD6Signature
        STR     lr, DynArea_OD6PrevSignature
        ORR     lr, lr, #8
        STR     lr, DynArea_OD6Signature
        STR     r1, DynArea_OD6Handle
  ]

        CLRV
        EXIT

90
        ADRL    r0, ErrorBlock_AreaAlreadyExists
 [ International
        BL      TranslateError
 |
        SETV
 ]
        EXIT

;if you think this is worth internationalising, I pity you
92
        ADR     r0, DynArea_NaughtyRenum
        SETV
        EXIT
DynArea_NaughtyRenum
        DCD     0
        DCB     "illegal DA renumber",0
        ALIGN

        LTORG

 [ ShrinkableDAs
;**************************************************************************
;
;       DynArea_ReturnFree - Return total free space, including shrinkables
;
;       Internal routine called by DynamicAreaSWI
;
; in:   r0 = reason code (5)
;       r1 = area number to exclude, or -1 to include all shrinkable areas
;
; out:  r2 = total amount of free memory
;

DynArea_ReturnFree ALTENTRY
        CMP     r1, #-1                         ; if no excluded area,
        MOVEQ   r10, r1                         ; then point r10 nowhere
        BEQ     %FT10

  [ DynArea_QuickHandles
        BL      QCheckAreaNumber                ; else check area number is valid
  |
        BL      CheckAreaNumber                 ; else check area number is valid
  ]
        BCC     UnknownDyn                      ; [unknown area]
10
        LDR     r2, =ZeroPage
        LDR     r2, [r2, #FreePoolDANode + DANode_PMPSize] ; start with current size of free pool
  [ DynArea_QuickHandles
        ;traverse the Shrinkable sublist
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        LDR     r11, DynArea_ShrinkableSubList
        B       %FT21
  |
        LDR     r11, =ZeroPage+DAList
  ]
20
  [ DynArea_QuickHandles
        LDR     r11, [r11, #DANode_SubLink]     ; load next area on sublist
  |
        LDR     r11, [r11, #DANode_Link]        ; load next area
  ]
21
        TEQ     r11, #0                         ; if end of list
        BEQ     %FT90                           ; then exit, with r2 = correct value

  [ DynArea_QuickHandles
        TEQ     r11, r10                        ; must not be the excluded area
  |
        LDR     lr, [r11, #DANode_Flags]        ; load area flags
        TST     lr, #DynAreaFlags_Shrinkable    ; must be shrinkable
        TEQNE   r11, r10                        ; and not excluded area
  ]
        BEQ     %BT20                           ; [don't try this one]

        Push    r3
        BL      CallTestShrink
        ADD     r2, r2, r3, LSR #12             ; add on amount if any
        Pull    r3
        B       %BT20                           ; then go back for more

90
        CMP     r2, #DynArea_PMP_BigPageCount
        MOVLO   r2, r2, LSL #12
        LDRHS   r2, =DynArea_PMP_BigByteCount
        EXIT
 ]

;**************************************************************************
;
;       DynArea_Locate - Return area number given an address
;
;       Internal routine called by DynamicAreaSWI
;
; in:   r0 = reason code (20)
;       r1 = logical address to locate
;
; out:  r0 = area type (0=dynamic, 1=system, others reserved)
;       r1 = area number
;       r10-r12 may be corrupted
;       All other registers preserved
;

DynArea_Locate Entry "r2-r5"
        MOV     r5, r1

        MOV     r4, #1
10
        MOV     r0, r4, LSL #8
        BL      MemoryAreaInfo
        BVS     %FT20                           ; no more system areas

        ADD     r2, r1, r2                      ; r1:=base r2:=top
        CMP     r5, r1
        CMPCS   r2, r5
        MOVHI   r1, r4                          ; number
        MOVHI   r0, #1                          ; system area
        EXIT    HI

        ADD     r4, r4, #1
        B       %BT10
20
  [ DynArea_QuickHandles
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]

        ADR     r3, DynArea_SysQHandleArray
        MOV     r4, #0
30
        LDR     r10, [r3, r4, LSL #2]
        TEQ     r10, #0
        BLNE    %FT60                           ; check system DA node

        ADD     r4, r4, #1
        CMP     r4, #ChangeDyn_MaxArea
        BLS     %BT30

        ADR     r3, DynArea_QHandleArray
        MOV     r4, #0
40
        LDR     r10, [r3, r4, LSL #2]
        CMP     r10, #DynArea_NumQHandles
        BLHI    %FT60                           ; check quick DA node

        ADD     r4, r4, #1
        CMP     r4, #DynArea_NumQHandles
        BCC     %BT40
  ]
        LDR     r10, =ZeroPage+DAList
        ASSERT  DANode_Link = 0                 ; because DAList has only link
50
        LDR     r10, [r10, #DANode_Link]
        TEQ     r10, #0
        PullEnv EQ
        ADREQL  r0, ErrorBlock_BadAddress
        BEQ     DynArea_TranslateAndReturnError

        BL      %FT60                           ; check treacle DA node
        B       %BT50
60
        LDR     r1, [r10, #DANode_Flags]
        LDR     r0, [r10, #DANode_MaxSize]
        TST     r1, #DynAreaFlags_DoublyMapped
        LDR     r1, [r10, #DANode_Base]
        ADD     r2, r1, r0                      ; r1:=base r2:=top
        SUBNE   r1, r1, r0                      ; doubly mapped is special
        CMP     r5, r1
        CMPCS   r2, r5
        LDRHI   r1, [r10, #DANode_Number]       ; number
        MOVHI   r0, #0                          ; dynamic area
        EXIT    HI

        MOV     pc, lr                          ; not within this one

;**************************************************************************
;
;       DynArea_PMP_PhysOp
;
;  Claim/release physical memory pages in physical memory pool
;
; in:   r0 = reason code (21)
;       r1 = area number
;       r2 = pointer to array of (PMP page index, phys page index, page flag) tuples
;            phys page index -1 to release
;            phys page index -2 to let kernel pick page
;            otherwise page number to use
;            page flags are defined by DynAreaFlags_PMPPhysOpAccessMask
;       r3 = number of entries
;
; out:  r0-r1 preserved (error if not all of region successfully updated)
;       r2 advanced to first entry not processed (or end of list)
;       r3 updated to number of entries not processed (or 0)
;       r10-r12 may be corrupted
;
DynArea_PMP_PhysOp ROUT
        ; Strategy:
        ; - Check free pool has enough pages to satisfy claim
        ; - Walk page list, comparing against current PMP state
        ; - If free required, check not in use and push straight into free pool
        ; - If kernel auto-alloc required, grab last page from free pool
        ; - If specific page required, batcall into OS_ChangeDynamicArea to let it deal with page reclaiming
        Entry   "r0-r9"
  [ DynArea_QuickHandles
        BL      QCheckAreaNumber        ; check area exists
  |
        BL      CheckAreaNumber         ; check area exists
  ]
        BCC     %FT90                   ; [it doesn't]
01
        ; r10 -> DANode
        LDR     r8, [r10, #DANode_PMP]
        CMP     r8, #0
        LDR     r9, [r10, #DANode_PMPMaxSize]
        BEQ     %FT90
        BL      ClaimCDASemaphore
        BNE     %FT91
        ; Before we begin, check to see if there's enough space in the free pool to satisfy any map in requests
        LDR     r7, =ZeroPage
        LDR     r11, [r7, #MaxCamEntry]
        LDR     r0, [r7, #FreePoolDANode+DANode_PMPSize]
        LDR     r7, [r7, #CamEntriesPointer]
        CMP     r0, r3
        BHS     %FT45
        ; Free pool may be too small - scan the page list and the PMP to work out exactly how many pages are required
        ; If there aren't enough, try growing the free pool (shrink app space, shrink shrinkables, etc.)
        MOV     r12, #0
        MOV     r1, #0
10
        SUBS    r3, r3, #1
        BLO     %FT20
        LDMIA   r2!, {r4-r6}
        ; Check for silly PMP page index
        CMP     r4, r9
        BHS     %FT92
        ; Check for silly phys page index
        CMP     r5, #-3
        CMPLS   r11, r5
        BLS     %FT92
        ; Look up the page that's currently in the PMP
        LDR     r0, [r8, r4, LSL #2]
        TEQ     r0, r5
        BEQ     %BT10
        ; Do we need to release the existing page?
        CMP     r0, #-1
        BEQ     %FT15
        CMP     r5, #-2
        BEQ     %BT10                   ; Page is currently there, and we want a kernel picked page -> no action required
        ; A page is currently there, but we either want to release it or to swap in a different page.
        SUB     r12, r12, #1            ; Count page release
15
        ; Map in new page if required
        CMP     r5, #-2
        BHI     %BT10 ; i.e. -1
        ADD     r12, r12, #1            ; Count page claim
        ; Because we process list entries in order, we actually need to keep track of the maximum number of pages needed in the free pool at any point in the list, rather than just the delta we'll have at the end
        CMP     r12, r1
        MOVGT   r1, r12
        B       %BT10
20
        ; r1 = number of pages needed in free pool
      [ PMPDebug
        DebugReg r1, "Want this many pages: "
      ]
        MOV     r12, r10
        BL      GrowFreePool
        BCC     %FT94
        ; Enough space is available, reset r2 & r3 and process the list properly
        FRAMLDR r2
        FRAMLDR r3

45
        LDR     r12, [r10, #DANode_PMPSize]
        ; Usage in main loop:
        ; r2 -> input page list
        ; r3 = length
        ; r4 = current entry PMP index
        ; r5 = current entry phys page index
        ; r6 = current entry flags
        ; r7 -> CAM
        ; r8 -> PMP
        ; r9 = PMPMaxSize
        ; r10 -> DANode
        ; r11 = MaxCamEntry
        ; r12 = current PMPSize
        ; r0, r1 temp
50
        SUBS    r3, r3, #1
        BLO     %FT80
        LDMIA   r2!, {r4-r6}
        ; Check for silly PMP page index
        CMP     r4, r9
        BHS     %FT93
        ; Check for silly phys page index
        CMP     r5, #-3
        CMPLS   r11, r5
        BLS     %FT93
        AND     r6, r6, #DynAreaFlags_PMPPhysOpAccessMask
        ; Look up the page that's currently in the PMP
        LDR     r0, [r8, r4, LSL #2]
        TEQ     r0, r5
        BNE     %FT52
        ; Page is there - check/update flags
        ADD     r0, r7, r0, LSL #CAM_EntrySizeLog2
        LDR     r1, [r0, #CAM_PageFlags]
        BIC     lr, r1, #DynAreaFlags_PMPPhysOpAccessMask
        ORR     lr, lr, r6
        TEQ     r1, lr
        STRNE   lr, [r0, #CAM_PageFlags]
        B       %BT50
52
        ; Do we need to release the existing page?
        CMP     r0, #-1
        BEQ     %FT55
        CMP     r5, #-2
        BEQ     %BT50                   ; Page is currently there, and we want a kernel picked page -> no action required
        ; A page is currently there, but we either want to release it or to swap in a different page. Start by releasing the existing page.
        ; TODO - if we're swapping with another page we'll probably want to preserve the contents (have a flag to control behaviour)
        ; Check page isn't mapped in
        ASSERT  CAM_LogAddr=0
        LDR     r1, [r7, r0, LSL #CAM_EntrySizeLog2]
      [ PMPDebug
        DebugReg r0, "Releasing page: "
        DebugReg r1, "Current addr: "
      ]
        LDR     lr, =Nowhere
        TEQ     r1, lr
        BNE     %FT95
        ; Add the page back into the free pool
        Push    "r2-r5,r12"
        LDR     r4, =ZeroPage+FreePoolDANode
        LDR     r12, [r4, #DANode_PMP]
        LDR     r5, [r4, #DANode_PMPSize]
        STR     r0, [r12, r5, LSL #2]
        ADD     r2, r7, r0, LSL #CAM_EntrySizeLog2
        LDR     r3, [r4, #DANode_Flags]
        LDR     lr, =DynAreaFlags_AccessMask
        AND     r3, r3, lr
        ASSERT  CAM_PageFlags=4
        ASSERT  CAM_PMP=8
        ASSERT  CAM_PMPIndex=12
        STMIB   r2, {r3-r5}
        ADD     r5, r5, #1
        STR     r5, [r4, #DANode_PMPSize]
        Pull    "r2-r5,r12"
        ; Page no longer owned by us
        MOV     r0, #-1
        STR     r0, [r8, r4, LSL #2]
        SUB     r12, r12, #1
55
        ; Map in new page if required
        CMP     r5, #-2
        BHI     %BT50 ; i.e. -1
        BLO     %FT60
      [ PMPDebug
        DebugTX "Kernel-picking page"
      ]
        ; Kernel-picked page required. Pick the last page from the free pool.
        LDR     r0, =ZeroPage+FreePoolDANode
        LDR     r1, [r0, #DANode_PMP]
        LDR     r5, [r0, #DANode_PMPSize]
        SUBS    r5, r5, #1
        BLO     %FT95                   ; Shouldn't happen
        STR     r5, [r0, #DANode_PMPSize]
        LDR     r5, [r1, r5, LSL #2]!
        MOV     r0, #-1
        STR     r0, [r1]
        ; Add to our PMP
59
        STR     r5, [r8, r4, LSL #2]
        ADD     r5, r7, r5, LSL #CAM_EntrySizeLog2
        LDR     r0, [r10, #DANode_Flags] ; Use default DA flags, modified by flags given in page list
        LDR     r1, =DynAreaFlags_AccessMask :AND: :NOT: DynAreaFlags_PMPPhysOpAccessMask
        MOV     lr, r4
        AND     r0, r0, r1
        ORR     r0, r0, r6
        ASSERT  CAM_PageFlags=4
        ASSERT  CAM_PMP=8
        ASSERT  CAM_PMPIndex=12
        STMIB   r5, {r0,r10,lr}
        ADD     r12, r12, #1
        B       %BT50
60
        ; Check that the requested page isn't locked
        ADD     r0, r7, r5, LSL #CAM_EntrySizeLog2
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        LDMIA   r0, {r0-r1}
      [ PMPDebug
        DebugReg r5, "Claiming page: "
        DebugReg r0, "Current addr: "
        DebugReg r1, "Current flags: "
      ]
        TST     r1, #PageFlags_Unavailable
        BNE     %FT95
        ; Construct a dummy DANode on the stack so we can use a Batcall to map
        ; in the page
        SUB     sp, sp, #DANode_NodeSize
        ; Copy over real node as basis
        MOV     r0, #DANode_NodeSize
61
        SUBS    r0, r0, #4
        LDR     r1, [r10, r0]
        STR     r1, [sp, r0]
        BGT     %BT61
        ; Adjust some parameters to ensure batcall is happy
        LDR     r0, =Nowhere
        STR     r0, [sp, #DANode_Base]
        LDR     lr, =ZeroPage
        MOV     r0, #0
        STR     r0, [lr, #CDASemaphore] ; Temporarily release so batcall will work
        STR     r0, [sp, #DANode_Size]
        MOV     r0, #4096
        STR     r0, [sp, #DANode_MaxSize]
        ; Because we're claiming the page via a Batcall, we need to make sure that the DA flags used for the call are valid as DA flags - i.e. don't touch any pageflags-only flags, because they might overlap the DA flags.
        ; Once the page is ours we'll fix up the other flags to be as the user requested.
    [ (DynAreaFlags_AccessMask :AND: DynAreaFlags_PMPPhysOpAccessMask) <> 0
        LDR     r0, [sp, #DANode_Flags]
      [ PMPDebug
        DebugReg r0, "Area flags: "
      ]
        LDR     lr, =DynAreaFlags_AccessMask :AND: DynAreaFlags_PMPPhysOpAccessMask
        BIC     r0, r0, lr
        AND     lr, r6, lr
        ORR     r0, r0, lr
      [ PMPDebug
        DebugReg r0, "Batcall flags: "
      ]
        STR     r0, [sp, #DANode_Flags]
    ]
        ; Replace handler routine with our own
        STR     r5, [sp, #DANode_Workspace] ; Required page number is handler param
        ADR     r0, PMPGrowHandler
        STR     r0, [sp, #DANode_Handler]
        ; Make the call
        Push    "r2"
        ADD     r2, sp, #4
        MOV     r0, #ChangeDyn_Batcall
        MOV     r1, #4096
        SWI     XOS_ChangeDynamicArea
        LDR     r2, =ZeroPage
        STR     sp, [r2, #CDASemaphore]
        Pull    "r2"
        ADD     sp, sp, #DANode_NodeSize
        BVS     %FT99
        ; Everything went OK, remember the new page as being ours
        B       %BT59

80
        BL      PMPMemoryMoved
        CLRV
        FRAMSTR r2
        MOV     r3, #0
        FRAMSTR r3
        EXIT

90
        PullEnv
        ADRL    r0, ErrorBlock_BadDynamicArea
 [ International
        B       TranslateError
 |
        SETV
        MOV     pc, lr
 ]

91
        ; Failed to claim CDASemaphore
        PullEnv
        ADRL    r0, ErrorBlock_ChDynamNotAllMoved
 [ International
        B       TranslateError
 |
        SETV
        MOV     pc, lr
 ]

92
        ; Error during initial list scan - reset parameters as if nothing's been moved
        FRAMLDR r2
        FRAMLDR r3
        ADD     r2, r2, #12
        SUB     r3, r3, #1
        LDR     r12, [r10, #DANode_PMPSize]
93
      [ PMPDebug
        DebugTX "-> bad physop page number"
      ]
        ADRL    r0, ErrorBlock_BadPageNumber
        B       %FT98

94
        ; Error during initial list scan - reset parameters as if nothing's been moved
        FRAMLDR r2
        FRAMLDR r3
        ADD     r2, r2, #12
        SUB     r3, r3, #1
        LDR     r12, [r10, #DANode_PMPSize]
95
      [ PMPDebug
        DebugTX "-> physop can't move"
      ]
        ADRL    r0, ErrorBlock_ChDynamNotAllMoved
        B       %FT98

98
 [ International
        BL      TranslateError
 |
        SETV
 ]
99
        BL      PMPMemoryMoved
        FRAMSTR r0
        ; Wind r2, r3 back one entry to point to the entry that's causing the problem
        SUB     r2, r2, #12
        ADD     r3, r3, #1
        FRAMSTR r2
        FRAMSTR r3
        EXIT

; r10 -> DANode
DynArea_PMP_PhysOp_WithNode ALTENTRY
        B       %BT01


PMPMemoryMoved ROUT
        EntryS  "r0-r2,r5,r11"
        ; In: r10 -> DANode
        ;     r12 = new size (pages)
        ; Update PMPSize, release CDASemaphore, and issue Service_MemoryMoved
        LDR     r0, [r10, #DANode_PMPSize]
        SUBS    r0, r0, r12
        STR     r12, [r10, #DANode_PMPSize]
        RSBLT   r0, r0, #0
        CMP     r0, #DynArea_PMP_BigPageCount
        MOVLO   r0, r0, LSL #12
        LDRHS   r0, =DynArea_PMP_BigByteCount
        LDR     r2, [r10, #DANode_Number]
        ; Release CDASemaphore
        LDR     r11, =ZeroPage
        MOV     r5, #0
        STR     r5, [r11, #CDASemaphore]
   [ DynArea_QuickHandles
        LDR     r11, [r11, #DynArea_ws]
        LDR     r5, DynArea_OD6Signature
        STR     r5, DynArea_OD6PrevSignature
        ORR     r5, r5, #4              ;signal a resize
        STR     r5, DynArea_OD6Signature
        STR     r2, DynArea_OD6Handle
   ]
        MOV     r1,#Service_MemoryMoved
        BL      Issue_Service
      [ PMPParanoid
        BL      ValidatePMPs
      ]
        EXITS
        

PMPGrowHandler ROUT
        TEQ     r0, #DAHandler_PreGrow
        STREQ   r12, [r1]
        MOV     pc, lr       

;**************************************************************************
;
;       DynArea_PMP_LogOp
;
;  Map/unmap pages from logical memory
;
; in:   r0 = reason code (22)
;       r1 = area number
;       r2 = pointer to array of (DA page number, PMP page index, page flags) tuples
;            PMP page index of -1 to unmap (page flags currently ignored)
;            else PMP page index + page flags must be valid
;       r3 = number of entries
;
; out:  r0-r1 preserved (error if not all of region successfully updated)
;       r2 advanced to first entry not processed (or end of list)
;       r3 updated to number of entries not processed (or 0)
;       r10-r12 may be corrupted
;
PMPLogOp_ChunkSize * 384 ; 384 pages = 1.5K stack, or 1.5MB of memory (larger than current max Cache_RangeThreshold - otherwise full cache clean optimisation won't be taken)

                              ^ 0, sp
PMPLogOp_PageList             # PMPLogOp_ChunkSize*4 ; List of pages to map out
PMPLogOp_UnsafeMapIn          # 4 ; Nonzero if we've done an 'unsafe' map in
PMPLogOp_GlobalTLBFlushNeeded # 4 ; Nonzero if a global TLB flush needed on exit
                              # 8 ; Padding!
PMPLogOp_FrameSize            # 0

DynArea_PMP_LogOp ROUT
        Entry   "r0-r9", :INDEX:PMPLogOp_FrameSize
  [ DynArea_QuickHandles
        BL      QCheckAreaNumber        ; check area exists
  |
        BL      CheckAreaNumber         ; check area exists
  ]
        BCC     %FT90                   ; [it doesn't]
01
        ; r10 -> DANode
        LDR     r7, [r10, #DANode_PMP]
        CMP     r7, #0
        LDR     r9, [r10, #DANode_PMPMaxSize]
        BEQ     %FT90
        BL      ClaimCDASemaphore
        BNE     %FT91
        LDR     r11, [r10, #DANode_MaxSize]
        LDR     r12, [r10, #DANode_Base]
        LDR     r8, =L2PT
        ; Usage in main loop:
        ; r0 = number of cacheable pages being umapped
        ; r1 = offset in temp page list
        ; r2 -> input page list
        ; r3 = length
        ; r4 = current entry DA page index
        ; r5 = current entry PMP page index
        ; r6 = current entry page flags
        ; r7 -> PMP
        ; r8 -> L2PT
        ; r9 -> PMPMaxSize
        ; r10 -> DANode
        ; r11 -> DA max size
        ; r12 -> DA base
        MOV     r0, #0
        STR     r0, PMPLogOp_UnsafeMapIn
        STR     r0, PMPLogOp_GlobalTLBFlushNeeded
        MOV     r1, #0
      [ PMPDebug
        DebugReg r3, "LogOp len "
      ]
05
        ; Examine the first entry and see if it's a request to map in or map out
        CMP     r3, #0
        BEQ     %FT70
06
        LDMIA   r2, {r4-r6}
      [ PMPDebug
        DebugReg r4, "DA page "
        DebugReg r5, "PMP page "
      ]
        ; Check for silly DA page index
        CMP     r4, r11, LSR #12
        BHS     %FT95
        CMP     r5, #-1
        BNE     %FT50
        ; Map out request - get current page
      [ PMPDebug
        DebugTX "-> Map out"
      ]
        ADD     r4, r12, r4, LSL #12
        BL      logical_to_physical
        MOVCS   r5, #-1
        BCS     %FT10
        Push    "r3,r10-r11"
        BL      physical_to_ppn
        MOV     r5, r3
        Pull    "r3,r10-r11"
        BCS     %FT95 ; TODO better error
        ; Check to see if the page is cacheable
        LDR     r6, =ZeroPage
        LDR     r6, [r6, #CamEntriesPointer]
        ADD     r6, r6, #CAM_PageFlags
        LDR     r6, [r6, r5, LSL #CAM_EntrySizeLog2]
        TST     r6, #DynAreaFlags_NotCacheable
        ADDEQ   r0, r0, #1
10
      [ PMPDebug
        DebugReg r5, "Current phys page="
      ]
        LDR     r9, [r10, #DANode_PMPMaxSize] ; restore after logical_to_physical clobbered it
        ; Only add to list if we're mapping out
        CMP     r5, #-1
        STRNE   r5, [sp, r1, LSL #2]
        ADDNE   r1, r1, #1
15
        ADD     r2, r2, #12
        SUB     r3, r3, #1
        CMP     r1, #PMPLogOp_ChunkSize
        BNE     %BT05
        BL      LogOp_MapOut
        MOV     r0, #0
        MOV     r1, #0
        B       %BT05

50
        CMP     r1, #0
        BLNE    LogOp_MapOut
55
        ; Request to map in - examine CAM to see if the page is already at the
        ; requested location (with requested flags)
        CMP     r5, r9
        BHS     %FT95
        LDR     r0, =ZeroPage
        LDR     r5, [r7, r5, LSL #2]
        LDR     r0, [r0, #CamEntriesPointer]
        CMP     r5, #-1
        BEQ     %FT95
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        ADD     r0, r0, r5, LSL #CAM_EntrySizeLog2
        LDMIA   r0, {r0, r1}
        LDR     lr, =DynAreaFlags_PMPLogOpAccessMask
      [ PMPDebug
        DebugTX "-> Map in "
      ]
        ADD     r4, r12, r4, LSL #12
      [ PMPDebug
        DebugReg r4, "Log addr "
        DebugReg r5, "Desired phys page "
        DebugReg r6, "Desired flags "
        DebugReg r0, "Page currently at "
        DebugReg r1, "With flags "
      ]
        AND     r6, r6, lr
        BIC     lr, r1, lr
        ORR     r6, r6, lr ; Preserve special flags (e.g. temp uncacheability, PMP membership)
        CMP     r0, r4
        CMPEQ   r6, r1
        BEQ     %FT65
        ; Page needs to be mapped/moved/updated
        Push    "r2-r4,r6,r9,r11"
        MOV     r2, r5
        ; Update our logical size if the page isn't already in position
        CMP     r0, r4
        BEQ     %FT60
        ORR     r6, r6, #PageFlags_Unsafe ; Do unsafe mapping if posible
        ; If the page is currently in our address space, decrease our logical size (-> that mapping is about to go away)
        LDR     r1, [r10, #DANode_Size]
        SUB     lr, r0, r12
        CMP     lr, r11
        SUBLO   r1, r1, #4096
        BICLO   r6, r6, #PageFlags_Unsafe
        ; If there's nothing at the target address, increase our logical size
        BL      logical_to_physical
        ADDCS   r1, r1, #4096
        BICCC   r6, r6, #PageFlags_Unsafe
        STR     r1, [r10, #DANode_Size]
        ; Also update HWM
        BCC     %FT57
      [ PMPDebug
        DebugTX "Nothing at dest addr"
      ]
        LDR     r1, [r10, #DANode_SparseHWM]
        ADD     lr, r4, #4096
        CMP     r1, r4
        STRLS   lr, [r10, #DANode_SparseHWM]
        B       %FT60
57
        ; There's already a page at the target address. Unmap it before we
        ; replace it (BangCamUpdate isn't smart enough to do this for us)
        Push    "r2,r4,r6,r7,r10"
        LDR     r2, =ZeroPage
        LDR     r7, [r2, #MaxCamEntry]
        BL      physical_to_ppn
        BCS     %FT94
      [ PMPDebug
        DebugReg r3, "Unmapping existing page first "
      ]
        LDR     r11, [r2, #CamEntriesPointer]
        MOV     r2, r3
        ADD     r11, r11, r3, LSL #CAM_EntrySizeLog2
        LDR     r3, =Nowhere
        LDR     r11, [r11, #CAM_PageFlags] ; Preserve flags
        ; We should be able to make this an unsafe op if the page isn't cacheable. But to avoid global TLB flushes when only one or two pages are being unmapped, only make it unsafe if we've already scheduled a global flush.
        TST     r11, #DynAreaFlags_NotCacheable
        LDRNE   r7, [sp, #:INDEX:PMPLogOp_GlobalTLBFlushNeeded + 6*4 + 4*4]
        TEQNE   r7, #0
        ORRNE   r11, r11, #PageFlags_Unsafe
        BL      BangCamUpdate
        Pull    "r2,r4,r6,r7,r10"
        ; If the above was unsafe, then it means the below can be unsafe too
        AND     r11, r11, #PageFlags_Unsafe
        ORR     r6, r6, r11
60
        ; Call BangCamUpdate
        MOV     r3, r4
        TST     r6, #PageFlags_Unsafe
        ORR     r11, r6, #DynAreaFlags_PMP
        STRNE   pc, [sp, #:INDEX:PMPLogOp_UnsafeMapIn + 6*4]
      [ PMPDebug
        DebugReg r11, "Actual flags "
      ]
        BL      BangCamUpdate
        Pull    "r2-r4,r6,r9,r11"
65
        MOV     r0, #0
        MOV     r1, #0
        ADD     r2, r2, #12
        SUBS    r3, r3, #1
        BNE     %BT06
70
        MOV     r4, #0
71      ; R4 = error
        ; Store back progress
        FRAMSTR r2
        FRAMSTR r3
        ; Flush any pending changes
        CMP     r1, #0
        BLNE    LogOp_MapOut
      [ PMPDebug
        DebugReg r3, "# not processed "
        LDR     r3, PMPLogOp_GlobalTLBFlushNeeded
        DebugReg r3, "GlobalTLBFlushedNeeded? "
        LDR     r3, PMPLogOp_UnsafeMapIn
        DebugReg r3, "UnsafeMapIn? "
        LDR     r3, [r10, #DANode_Size]
        DebugReg r3, "Size "
      ]
        ; Perform any necessary post maintenance
        LDR     r0, PMPLogOp_GlobalTLBFlushNeeded
        TEQ     r0, #0
        BEQ     %FT72
        ARMop   MMU_ChangingUncached
        B       %FT75
72
      [ SyncPageTables
        LDR     r0, PMPLogOp_UnsafeMapIn
        TEQ     r0, #0
        BEQ     %FT75
        PageTableSync
      ]
75
        ; Release CDASemaphore
        LDR     r1, =ZeroPage
        MOV     r2, #0
        STR     r2, [r1, #CDASemaphore]
      [ PMPParanoid
        BL      ValidatePMPs
      ]
        CLRV
        MOVS    r0, r4
 [ International
        BLNE    TranslateError
 |
        SETV    NE
 ]
        FRAMSTR r0,VS
        EXIT

90
        ADRL    r0, ErrorBlock_BadDynamicArea
        B       %FT92
91
        ADRL    r0, ErrorBlock_ChDynamNotAllMoved
92
 [ International
        BL      TranslateError
 |
        SETV
 ]
        FRAMSTR r0
        EXIT

94
      [ PMPDebug
        DebugTX "-> failed to find page which is currently mapped in"
      ]
        Pull    "r2,r4,r6,r7"
        Pull    "r2-r4,r6,r9,r11"
95
      [ PMPDebug
        DebugTX "-> bad logop page number"
      ]
        ADRL    r4, ErrorBlock_BadPageNumber
        B       %BT71

; r10 -> DANode
DynArea_PMP_LogOp_WithNode ALTENTRY
        B       %BT01

LogOp_MapOut ROUT
        Entry   "r0-r12"
        ADD     r3, sp, #14*4
        LDR     r12, =ZeroPage
      [ PMPDebug
        DebugReg r1, "Unmapping # pages "
        DebugReg r0, "With # cacheable "
      ]
        ; r0 = number of cacheable pages being unmapped
        ; r1 = number of pages being unmapped
        ; r3 -> list of physical pages to unmap
        ; r10 -> DANode
        ; First go through and make them all uncacheable
        CMP     r0, #0
        BEQ     %FT10

        ; Work out if a global cache flush makes sense
        MOV     r8, r1
        MOV     r6, r0, LSL #12
        ARMop   Cache_RangeThreshold,,,r12
        CMP     r6, r0
        ORRLS   r6, r6, #1

        MOV     r7, r3
        LDR     r12, [r12, #CamEntriesPointer]
        LDR     r3, =Nowhere
        LDR     r10, =L2PT
        MOV     r9, #-1
05
        LDR     r2, [r7], #4
      [ PMPDebug
        DebugReg r2, "Uncache page "
      ]
        ADD     r11, r12, r2, LSL #CAM_EntrySizeLog2
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        LDMIA   r11, {r11, lr}
        TEQ     r11, r3                 ; Check something actually there (mainly to stop DANode_Size going out of sync if page list requests for same page to be unmapped multiple times)
        BEQ     %FT08
        TST     lr, #DynAreaFlags_NotCacheable
        BNE     %FT08
        ; Calculate required page flags
        CMP     r9, lr
        BEQ     %FT06
        LDR     r1, =ZeroPage
        LDR     r1, [r1, #MMU_PCBTrans]
        GetTempUncache r2, lr, r1, r4
06
        ; Bypass BangCAM and update L2PT directly (avoids CAM gaining any unwanted temp uncacheability flags)
        LDR     r4, =TempUncache_L2PTMask
        LDR     lr, [r10, r11, LSR #10]
        BIC     lr, lr, r4
        ORR     lr, lr, r2
        STR     lr, [r10, r11, LSR #10]
        ; r6 bit 0 set if TLB+cache invalidation done on per-page basis
        TST     r6, #1
        BEQ     %FT07
        LDR     r4, =ZeroPage
        MOV     r0, r11
        ARMop   MMU_ChangingEntry,,,r4
07
        SUBS    r6, r6, #4096
        BLS     %FT09                   ; Can stop if that was the last cacheable page
08
        SUBS    r8, r8, #1
        BNE     %BT05

09
        ; Do global TLB+cache invalidate if required
        LDR     r12, =ZeroPage
        TST     r6, #1
        BNE     %FT10
      [ PMPDebug
        DebugTX "Global TLB+cache flush"
      ]
        ARMop   MMU_Changing,,,r12

10
        FRAMLDR r1
        ADD     r7, sp, #14*4
        ; Work out if we should do a global TLB flush after the unmap
        MOV     r5, #0
        LDR     r4, [r7, #:INDEX:PMPLogOp_GlobalTLBFlushNeeded]
        CMP     r4, #0
        BNE     %FT20
        CMP     r1, #32 ; Arbitrary TLB size
        BLO     %FT20
        ; Global TLB/uncached flush wanted - make BangCAM unsafe, request global flush from main code
        MOV     r5, #PageFlags_Unsafe
        STR     pc, [r7, #:INDEX:PMPLogOp_GlobalTLBFlushNeeded]
      [ PMPDebug
        DebugTX "Doing unsafe unmap"
      ]
20
        ; Now process the pages
        MOV     r8,r1
        FRAMLDR r10
        LDR     r12, [r12, #CamEntriesPointer]
        LDR     r3, =Nowhere
        LDR     r9, [r10, #DANode_Size]
25
        LDR     r2, [r7], #4
      [ PMPDebug
        DebugReg r2, "Umap page "
      ]
        ADD     r11, r12, r2, LSL #CAM_EntrySizeLog2
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        LDMIA   r11, {r11, lr}
        TEQ     r11, r3                 ; Check something actually there (mainly to stop DANode_Size going out of sync if page list requests for same page to be unmapped multiple times)
        ORR     r11, lr, r5             ; Retain current flags
        SUBNE   r9, r9, #4096
        BLNE    BangCamUpdate
        SUBS    r8, r8, #1
        BNE     %BT25
        STR     r9, [r10, #DANode_Size]
        EXIT

        LTORG

;**************************************************************************
;
;       DynArea_PMP_Resize
;
;  Physical resize of PMP - increase/decrease number of physical pages supported
;
; in:   r0 = reason code (23)
;       r1 = area number
;       r2 = resize amount (positive/negative page count)
;
; out:  r0-r1 preserved (error if not all of region successfully updated)
;       r2 = amount area has changed by (unsigned page count)
;       r10-r12 may be corrupted
;
DynArea_PMP_Resize ROUT
        Entry   "r0-r5"
  [ DynArea_QuickHandles
        BL      QCheckAreaNumber        ; check area exists
  |
        BL      CheckAreaNumber         ; check area exists
  ]
        BCC     %FT90                   ; [it doesn't]
01
        ; r10 -> DANode
      [ PMPDebug
        DebugReg r2, "Resize by: "
      ]
        ; Check CDASemaphore can be claimed, and then release it - we only make
        ; one call to external code so don't have too much to worry about
        ; (things can still go wrong though - e.g. if PMP resize triggers
        ; sys heap resize which then does something silly in
        ; Service_MemoryMoved)
        BL      ClaimCDASemaphore
        BNE     %FT91
        LDR     r3, =ZeroPage
        MOV     r4, #0
        STR     r4, [r3, #CDASemaphore]
        MOVS    r3, r2
        LDR     r5, [r10, #DANode_PMPMaxSize]
        MOVLT   r4, r2
        LDR     r2, [r10, #DANode_PMP]
        BLT     %FT50
        ; Grow by requested amount
        LDR     r4, =ZeroPage
        LDR     r4, [r4, #MaxCamEntry]
        SUB     r4, r4, r5
        ADD     r4, r4, #1              ; Max grow amount
        CMP     r3, r4
        MOVHI   r3, r4
        MOVS    r3, r3, LSL #2          ; -> byte count
        BEQ     %FT99                   ; Get rid of zero-change case
      [ PMPDebug
        DebugReg r3, "Clamped grow bytes: "
        DebugReg r2, "Current PMP: "
        DebugReg r5, "Current PMPMaxSize: "
      ]
        TEQ     r2, #0
        MOVEQ   r0, #HeapReason_Get
        MOVNE   r0, #HeapReason_ExtendBlock
        BL      DoSysHeapOpWithExtension
        BVS     %FT90
      [ PMPDebug
        DebugReg r2, "New PMP: "
      ]
        MOV     r3, r3, LSR #2
      [ PMPDebug
        DebugReg r3, "Return value: "
      ]
        FRAMSTR r3,,r2
        ; Success - initialise new space
        MOV     r4, #-1
10
        SUBS    r3, r3, #1
        STRGE   r4, [r2, r5, LSL #2]
        ADDGE   r5, r5, #1
        BGT     %BT10
        ; Store new details
        STR     r2, [r10, #DANode_PMP]
        STR     r5, [r10, #DANode_PMPMaxSize]
      [ PMPParanoid
        BL      ValidatePMPs
      ]
        EXIT

50
        ; Shrink request. Only shrink if there aren't any pages allocated to
        ; the end of the PMP.
        CMN     r5, r4
        RSBLO   r4, r5, #0              ; Can't shrink more than PMP size
      [ PMPDebug
        DebugReg r4, "Clamped shrink amount: "
      ]
        MOVS    r3, r4, LSL #2
        BEQ     %FT99                   ; No change to make
        ADD     r1, r2, r5, LSL #2
60
        LDR     lr, [r1, #-4]!
        CMP     lr, #-1
        BNE     %FT45
        ADDS    r4, r4, #1
        SUB     r5, r5, #1
        BNE     %BT60
45
        ; r5 = new size
        ; r4 = amount not changed (negative)
        ; r2 = PMP block
      [ PMPDebug
        DebugReg r5, "New size: "
        DebugReg r4, "Not changed: "
        DebugReg r2, "Current PMP: "
      ]
        SUB     r3, r3, r4, LSL #2      ; Calculate new shrink amount
        RSB     r4, r3, #0
        CMP     r5, #0
        MOV     r4, r4, LSR #2          ; Calculate return value
        MOVEQ   r0, #HeapReason_Free
        MOVNE   r0, #HeapReason_ExtendBlock
        BL      DoSysHeapOpWithExtension
        BVS     %FT91
        ; Operation success
        TEQ     r5, #0
        STR     r5, [r10, #DANode_PMPMaxSize]
        MOVEQ   r2, #0
      [ PMPDebug
        DebugReg r2, "New PMP: "
        DebugReg r4, "Return value: "
      ]
        STR     r2, [r10, #DANode_PMP]  ; Paranoia - store back even if we still have a size (just in case ExtendBlock shrink ops gain the ability to move blocks)
        FRAMSTR r4,,r2
      [ PMPParanoid
        BL      ValidatePMPs
      ]
        EXIT

90
        ADRL    r0, ErrorBlock_BadDynamicArea
        B       %FT92
91
        ADRL    r0, ErrorBlock_ChDynamNotAllMoved
92
        ; Failed for some reason.
        ; Note that we don't do anything fancy for grow failures (like try and
        ; do a partial grow) - a grow failure most likely indicates we're low
        ; on system heap space, which is a bad situation to be in.
 [ International
        BL      TranslateError
 |
        SETV
 ]
        FRAMSTR r0
98
      [ PMPParanoid
        BL      ValidatePMPs
      ]
        PullEnv
        MOV     r2, #0
        MOV     pc, lr

99
        CLRV
        B       %BT98

; r10 already contains node ptr
DynArea_PMP_Resize_WithNode ALTENTRY
        B       %BT01

;**************************************************************************
;
;       DynArea_PMP_GetInfo - Get info on a physical memory pool
;
;       Internal routine called by DynamicAreaSWI
;
;       Although designed for use with PMPs, this call works with regular DAs
;       too (just returns logical page counts for r6 & r7)
;
; in:   r0 = reason code (24)
;       r1 = area number
;
; out:  r2 = current logical size of area (bytes)
;       r3 = base logical address
;       r4 = area flags
;       r5 = maximum logical size of area (bytes)
;       r6 = current physical size of area (pages)
;       r7 = maximum physical size of area (pages)
;       r8 -> title string
;       r10-r12 may be corrupted
;       All other registers preserved
;

DynArea_PMP_GetInfo ROUT
        Entry
  [ DynArea_QuickHandles
        BL      QCheckAreaNumber        ; check area exists
  |
        BL      CheckAreaNumber         ; check area exists
  ]
        BCC     %FT90                   ; [it doesn't]

; r10 -> node, so get info

        LDR     r4, [r10, #DANode_Flags]
        LDR     r2, [r10, #DANode_Size]
        TST     r4, #DynAreaFlags_PMP
        LDR     r3, [r10, #DANode_Base]
        LDR     r5, [r10, #DANode_MaxSize]
        LDRNE   r6, [r10, #DANode_PMPSize]
        LDRNE   r7, [r10, #DANode_PMPMaxSize]
        MOVEQ   r6, r2, LSR #12
        MOVEQ   r7, r5, LSR #12
        LDR     r8, [r10, #DANode_Title]
        CLRV
        EXIT

90
        ADRL    r0, ErrorBlock_BadDynamicArea
 [ International
        BL      TranslateError
 |
        SETV
 ]
        EXIT

;**************************************************************************
;
;       DynArea_PMP_GetPages - Get page mapping info on a physical memory pool
;
;       Internal routine called by DynamicAreaSWI
;
; in:   r0 = reason code (25)
;       r1 = area number
;       r2 = pointer to input/output array:
;            +0: PMP page index
;            +4: phys page number
;            +8: DA page index
;            +12: page flags
;       r3 = number of entries
;
; out:  r0-r3 preserved
;       r10-r12 may be corrupted
;       All other registers preserved
;       Array updated with page details
;
; On entry, for each array entry either the PMP page index, phys page number, or
; DA page index must be provided, with the other indices set to -1 (page flags
; are ignored).
;
; On exit, if the page is a member of the PMP, the entries will be filled in as
; appropriate. If the page isn't mapped in (and it was a lookup by PMP page
; index/phys page number) the DA page index will be set to -1. If no physical
; page is allocated (or the page isn't a member of the PMP) the page flags will
; be set to 0.
;

DynArea_PMP_GetPages ROUT
        Entry   "r0-r9"
  [ DynArea_QuickHandles
        BL      QCheckAreaNumber        ; check area exists
  |
        BL      CheckAreaNumber         ; check area exists
  ]
        BCC     %FT90                   ; [it doesn't]
        ; r10 -> DANode
        LDR     r6, [r10, #DANode_PMP]
        CMP     r6, #0
        BEQ     %FT90
        LDR     r9, [r10, #DANode_PMPMaxSize]
        BEQ     %FT90
        LDR     r11, =ZeroPage
        LDR     r5, [r10, #DANode_Base]
        LDR     r7, [r11, #MaxCamEntry]
        LDR     r8, =L2PT
        LDR     r11, [r11, #CamEntriesPointer]
        LDR     r12, =DynAreaFlags_PMPLogOpAccessMask
        ; Usage in main loop:
        ; r2 -> input page list
        ; r3 = length
        ; r5 -> DA base
        ; r6 -> PMP
        ; r7 = MaxCamEntry
        ; r8 -> L2PT
        ; r9 = PMP size
        ; r10 -> DANode
        ; r11 -> CAM
        ; r12 = DynAreaFlags_PMPLogOpAccessMask
        ; r0, r1, r4 temp
10
        SUBS    r3, r3, #1
        BLT     %FT80
        ; Get the entry
        LDMIA   r2, {r0, r1, r4}
        ; PMP page provided?
        CMP     r0, #-1
        BNE     %FT50
        ; Phys page provided?
        CMP     r1, #-1
        BNE     %FT20
        ; DA page provided
        ; n.b. skipping any range check here since it won't hurt if the page
        ; doesn't belong to us
        Push    "r3, r5, r9-r11"
        ADD     r4, r5, r4, LSL #12
        BL      logical_to_physical
        BLCC    physical_to_ppn
        MOV     r0, r3
        Pull    "r3, r5, r9-r11"
        BCS     %FT15
        ; r0 = PPN, check to see if it belongs to us
        ADD     r1, r11, r0, LSL #CAM_EntrySizeLog2
        ASSERT  CAM_PageFlags=4
        ASSERT  CAM_PMP=8
        ASSERT  CAM_PMPIndex=12
        LDMIB   r1, {r1, r4, lr}
        TST     r1, #DynAreaFlags_PMP
        BEQ     %FT15
        CMP     r4, r10
        BNE     %FT15
        STR     lr, [r2], #4            ; Store PMP page index
        AND     r1, r1, r12
        STR     r0, [r2], #8            ; Store phys page number, skip DA page index
        STR     r1, [r2], #4            ; Store page flags
        B       %BT10
15
        ; Bad DA page index
        ; PMP page index & phys page number are already known to be -1, so just
        ; store flags
        MOV     r0, #0
        STR     r0, [r2, #12]
        ADD     r2, r2, #16
        B       %BT10

20
        ; Check for silly phys page number
        CMP     r1, r7
        BHI     %FT91
        ADD     r1, r11, r1, LSL #CAM_EntrySizeLog2
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        ASSERT  CAM_PMP=8
        ASSERT  CAM_PMPIndex=12
        LDMIA   r1, {r0, r1, r4, lr}
        TST     r1, #DynAreaFlags_PMP
        BEQ     %FT25
        CMP     r4, r10
        BNE     %FT25
        LDR     r4, =Nowhere
        STR     lr, [r2], #8            ; Store PMP page index, skip phys page number
        TEQ     r0, r4
        B       %FT55

25
        ; Bad phys page number
        ; PMP page index known to be -1, so store DA page index + flags
        ADD     r2, r2, #8
        MOV     r0, #-1
        MOV     r1, #0
        STMIA   r2!, {r0-r1}
        B       %BT10        

50
        ; Check for silly PMP page index
        CMP     r0, r9
        BHS     %FT91
        ; Look up the page that's currently in the PMP
        LDR     r0, [r6, r0, LSL #2]
        ADD     r2, r2, #4
        STR     r0, [r2], #4            ; Store phys page number
        ; Does the page exist?
        CMP     r0, #-1
        LDR     r4, =Nowhere
        ADDNE   r0, r11, r0, LSL #CAM_EntrySizeLog2
        MOVEQ   r1, #0                  ; No physical page, so no flags
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        LDMNEIA r0, {r0-r1}             ; Get log addr, flags from CAM
        TEQNE   r0, r4
55
        MOVEQ   r0, #-1                 ; No physical page, or not mapped
        SUBNE   r0, r0, r5
        MOVNE   r0, r0, LSR #12
        AND     r1, r1, r12             ; Mask returned flags
        STMIA   r2!, {r0-r1}            ; Store DA page index, flags
        B       %BT10

80
        CLRV
        EXIT

90
        ADRL    r0, ErrorBlock_BadDynamicArea
        B       %FT98
91
        ADRL    r0, ErrorBlock_BadPageNumber
98
 [ International
        BL      TranslateError
 |
        SETV
 ]
        FRAMSTR r0
        EXIT


;**************************************************************************
;
;       CheckAreaNumber - Try to find area with number r1
;
;       Internal routine called by DynArea_Create
;
; in:   r1 = area number to match
; out:  If match, then
;         C=1, r10 -> node, r11 -> previous node
;       else
;         C=0, r10,r11 corrupted
;       endif

CheckAreaNumber Entry
  [ DynArea_QuickHandles
QCheckAreaNumber_nonQ
  ]
        LDR     r10, =ZeroPage+DAList
        ASSERT  DANode_Link = 0                 ; because DAList has only link
10
        MOV     r11, r10                        ; save prev
        LDR     r10, [r10, #DANode_Link]        ; and load next
        CMP     r10, #1                         ; any more nodes?
        EXIT    CC                              ; no, then no match
        LDR     lr, [r10, #DANode_Number]       ; get number
        CMP     lr, r1                          ; does number match
        BNE     %BT10                           ; no, try next
  [ DynArea_QuickHandles
        Push    "r11"
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        STR     r1,  DynArea_LastTreacleHandle
        STR     r10, DynArea_LastTreaclePtr
        Pull    "r11"
  ]
        EXIT                                    ; (C=1 from CMP lr,r1)

  [ DynArea_QuickHandles

; QCheckAreaNumber - similar to CheckAreaNumber, but blisteringly quick for system or for quick
;                    numbers. However, DOES NOT return previous node in r11.
;
QCheckAreaNumber ROUT
        Push    "lr"
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        CMP     r1, #-1
        BEQ     QCheckAreaNumber_nonQ           ;just to protect against -1 as a proposed number
        LDR     lr, DynArea_LastTreacleHandle
        CMP     lr, r1
        LDREQ   r10, DynArea_LastTreaclePtr
        EXIT    EQ                              ;found node is slow one we handled last time (carry set)
        LDR     lr, DynArea_CreatingHandle
        CMP     lr, r1
        LDREQ   r10, DynArea_CreatingPtr
        EXIT    EQ                              ;found node is one we're creating (carry set)
        CMP     r1, #ChangeDyn_MaxArea
        BLS     %FT10
        CMP     r1,#DynArea_NewAreas
        BLO     QCheckAreaNumber_nonQ
        SUB     lr, r1, #DynArea_NewAreas
        CMP     lr, #DynArea_NumQHandles
        BHS     QCheckAreaNumber_nonQ
;quick handle
        ADR     r10, DynArea_QHandleArray
        LDR     r10, [r10, lr, LSL #2]
        CMP     r10, #DynArea_NumQHandles
        MOVLS   r10, #0                         ;not a valid pointer
        CMP     r10, #1
        Pull    "pc"                            ;handle free, carry clear
                                                ;or word is ptr to node, carry set
;system handle
10
        ADR     r10, DynArea_SysQHandleArray
        LDR     r10, [r10, r1, LSL #2]
        CMP     r10, #1
        Pull    "pc"                            ;DA does not exist, carry clear
                                                ;or word is ptr to node, carry set
  ] ;DynArea_QuickHandles

;**************************************************************************
;
;       CheckForOverlappingAreas - Check that given area does not overlap any existing ones
;
;       Internal routine called by DynArea_Create
;
; in:   r3 = base address
;       r4 = area flags (NB if doubly mapped, then have to check both halves for overlap)
;       r5 = size (of each half in doubly mapped areas)
;
; out:  If this area overlaps with an existing one, then
;         r0 -> error
;         V=1
;       else
;         r0 preserved
;         V=0
;       endif
;

CheckForOverlappingAreas Entry "r0-r5"
        TST     r4, #DynAreaFlags_DoublyMapped          ; check if doubly mapped
        BEQ     %FT05                                   ; [not, so don't mangle]

        SUBS    r3, r3, r5                              ; move start address back
        BCC     %FT20                                   ; oh dear! - it went back to below 0
        MOVS    r5, r5, LSL #1                          ; and double size
        BCS     %FT20                                   ; if that wrapped then that's bad, too
05
        ADDS    r5, r5, r3                              ; r5 -> end +1
        BHI     %FT20                                   ; if CS, indicating wrap, and not EQ (ie just ending at 0), then bad

        LDR     lr, =ZeroPage
        LDR     r0, [lr, #IOAllocPtr]
        CMP     r5, r0                                  ; end must be below I/O space (allocated down from high memory)
        BHI     %FT20

; check against list of fixed areas

        ADR     lr, FixedAreasTable
10
        LDMIA   lr!, {r0, r1}                           ; r0 = start addr, r1 = size
        CMP     r0, #-1                                 ; if at end of list
        BEQ     %FT30                                   ; then OK wrt fixed areas
        ADD     r1, r1, r0                              ; r1 = end addr+1
        CMP     r5, r0                                  ; if end of our area is <= start of fixed, then OK wrt fixed areas
        BLS     %FT30
        CMP     r3, r1                                  ; if start of our area is >= end of fixed, then go onto next area
        BCS     %BT10

20
        ADRL    r0, ErrorBlock_OverlappingAreas
 [ International
        BL      TranslateError
 |
        SETV
 ]
        STR     r0, [sp]
        EXIT

; Now, check against DAList

30
        LDR     lr, =ZeroPage+DAList
        ASSERT  DANode_Link = 0
40
        LDR     lr, [lr, #DANode_Link]
        CMP     lr, #0                                  ; if got to end of list (V=0)
        BEQ     %FT50                                   ; then exit saying OK
        LDR     r0, [lr, #DANode_Base]
        LDR     r1, [lr, #DANode_Flags]
        TST     r1, #DynAreaFlags_DoublyMapped
        LDR     r1, [lr, #DANode_MaxSize]
        SUBNE   r0, r0, r1                              ; if doubly mapped then move back
        MOVNE   r1, r1, LSL #1                          ; and double size
        ADD     r1, r1, r0                              ; r1 -> end
        CMP     r5, r0                                  ; if end of our area is <= start of dyn, then OK wrt dyn areas)
        BLS     %FT50
        CMP     r3, r1                                  ; if start of our area is >= end of dyn, then go onto next area
        BCS     %BT40
        B       %BT20                                   ; else it overlaps

50
        CLRV                                            ; OK exit
        EXIT


FixedAreasTable                                         ; table of fixed areas (address, size)
        &       0,                      AplWorkMaxSize  ; application space
 [ CursorChunkAddress < IO
        &       CursorChunkAddress,     64*1024                 ; 32K for cursor, 32K for "nowhere"
 ]
 [ ROM < IO
 [ OSROM_ImageSize > 8192
        &       &03800000,              OSROM_ImageSize*1024   ; ROM
 |
        &       &03800000,              8*1024*1024            ; ROM
 ]
 ]
        &       IO,                     &FFFFFFFF-IO    ; Kernel workspace (code will also check dynamic value IOAllocPtr)
        &       -1,                     0               ; termination

;**************************************************************************
;
;       AllocateAreaAddress - Find an area of logical space to use for this area
;
;       Internal routine called by DynArea_Create
;
; in:   r4 = area flags (NB if doubly mapped, we have to find space for both halves)
;       r5 = size (of each half in doubly mapped areas)
;
; out:  If successfully found an address, then
;         r0 preserved
;         r3 = logical address
;         V=0
;       else
;         r0 -> error
;         r3 preserved
;         V=1
;       endif

AllocateAreaAddress Entry "r0-r2,r4-r7"
        TST     r4, #DynAreaFlags_DoublyMapped          ; check if doubly mapped
        BEQ     %FT05                                   ; [not, so don't mangle]
        MOVS    r5, r5, LSL #1                          ; double size
        BCS     %FT90                                   ; if that wrapped then that's bad
05
        LDR     r3, =DynArea_NewAreasBase               ; r3 is our current attempt
        ADR     r0, FixedAreasTable                     ; r0 is ptr into fixed areas table
        LDR     r1, =ZeroPage+DAList                             ; r1 is ptr into dyn areas list
10
        ADDS    r7, r3, r5                              ; r7 is our end+1
        BHI     %FT90                                   ; if we wrapped (but not end+1=0) then we failed
        LDR     lr, =ZeroPage
        LDR     r2, [lr, #IOAllocPtr]
        CMP     r7, r2
        BHI     %FT90                                   ; if we walked into IOspace (assumed higher than any DA space) then we failed
15
        BL      GetNextRange                            ; get next range from either list (r2=start, r6=end+1)
        CMP     r7, r2                                  ; if end(ours) <= start(next) then this is OK
        BLS     %FT80                                   ; (note this also works when r2=-1)
        CMP     r3, r6                                  ; else if start(ours) >= end(next)
        BCS     %BT15                                   ; then get another
        MOV     r3, r6                                  ; else make start(ours) := end(next)
        B       %BT10                                   ; and go back for another try

; we've succeeded - just apply unbodge for doubly-mapped areas

80
        TST     r4, #DynAreaFlags_DoublyMapped          ; if doubly mapped
        MOVNE   r5, r5, LSR #1                          ; halve size again
        ADDNE   r3, r3, r5                              ; and advance base address to middle
        CLRV
        EXIT

90
        ADRL    r0, ErrorBlock_CantAllocateArea
  [ International
        BL      TranslateError
  |
        SETV
  ]
        STR     r0, [sp]
        EXIT                                    ; say we can't do it

        LTORG

;**************************************************************************
;
;       GetNextRange - Get next lowest range from either fixed or dynamic list
;
;       Internal routine called by AllocateAreaAddress
;
; in:   r0 -> next entry in fixed list
;       r1!0 -> next entry in dyn list
;
; out:  r2 = next lowest area base (-1 if none)
;       r6 = end of that range (undefined if none)
;       Either r0 or r1 updated to next one (except when r2=-1 on exit)
;

GetNextRange Entry "r7,r8"
        LDMIA   r0, {r2, r6}                            ; load start, size from fixed list
        ADD     r6, r6, r2                              ; r6 = end+1

        ASSERT  DANode_Link = 0
        LDR     r7, [r1, #DANode_Link]                  ; get next from dyn
        TEQ     r7, #0                                  ; if none
        MOVEQ   r8, #-1                                 ; then use addr -1
        BEQ     %FT10

        LDR     r8, [r7, #DANode_Flags]                 ; more double trouble
        TST     r8, #DynAreaFlags_DoublyMapped
        LDR     r8, [r7, #DANode_Base]
        LDR     lr, [r7, #DANode_MaxSize]
        SUBNE   r8, r8, lr
        MOVNE   lr, lr, LSL #1
        ADD     lr, lr, r8                              ; now r8 = start addr, lr = end+1
10
        CMP     r8, r2                                  ; if dyn one is earlier
        MOVCC   r2, r8                                  ; then use dyn start
        MOVCC   r6, lr                                  ; and end
        MOVCC   r1, r7                                  ; and advance dyn ptr
        EXIT    CC                                      ; then exit
        CMP     r2, #-1                                 ; else if not at end of fixed
        ADDNE   r0, r0, #8                              ; then advance fixed ptr
        EXIT

;**************************************************************************
;
;       AllocateBackingLevel2 - Allocate L2 pages for an area
;
;       Internal routine called by DynArea_Create
;
; in:   r3 = base address (will be page aligned)
;       r4 = area flags (NB if doubly mapped, then have to allocate for both halves)
;       r5 = size (of each half in doubly mapped areas)
;
; out:  If successfully allocated pages, then
;         All registers preserved
;         V=0
;       else
;         r0 -> error
;         V=1
;       endif

AllocateBackingLevel2 Entry "r0-r8,r11"
        TST     r4, #DynAreaFlags_DoublyMapped          ; if doubly mapped
        SUBNE   r3, r3, r5                              ; then area starts further back
        MOVNE   r5, r5, LSL #1                          ; and is twice the size

; NB no need to do sanity checks on addresses here, they've already been checked

; now round address range to 4M boundaries

        ADD     r5, r5, r3                              ; r5 -> end
        MOV     r0, #1 :SHL: 22
        SUB     r0, r0, #1
        BIC     r8, r3, r0                              ; round start address down (+ save for later)
        ADD     r5, r5, r0
        BIC     r5, r5, r0                              ; but round end address up

; first go through existing L2PT working out how much we need

        LDR     r7, =L2PT
        ADD     r3, r7, r8, LSR #10                     ; r3 -> start of L2PT for area
        ADD     r5, r7, r5, LSR #10                     ; r5 -> end of L2PT for area +1

        ADD     r1, r7, r3, LSR #10                     ; r1 -> L2PT for r3
        ADD     r2, r7, r5, LSR #10                     ; r2 -> L2PT for r5

        TEQ     r1, r2                                  ; if no pages needed
        BEQ     %FT30

        MOV     r4, #0                                  ; number of backing pages needed
10
        LDR     r6, [r1], #4                            ; get L2PT entry for L2PT
        TST     r6, #3                                  ; EQ if translation fault
        ADDEQ   r4, r4, #1                              ; if not there then 1 more page needed
        TEQ     r1, r2
        BNE     %BT10

; if no pages needed, then exit

        TEQ     r4, #0
        BEQ     %FT30

; now we need to claim r4 pages from the free pool, if possible; return error if not

        LDR     r1, =ZeroPage
        LDR     r6, [r1, #FreePoolDANode + DANode_PMPSize]
        SUBS    r6, r6, r4                              ; reduce free pool size by that many pages
        BCS     %FT14                                   ; if enough, skip next bit

; not enough pages in free pool currently, so try to grow it by the required amount

        Push    "r0, r1"
        MOV     r0, #ChangeDyn_FreePool
        RSB     r1, r6, #0                              ; size change we want (+ve)
        MOV     r1, r1, LSL #12
        SWI     XOS_ChangeDynamicArea
        Pull    "r0, r1"
        BVS     %FT90                                   ; didn't manage change, so report error

        MOV     r6, #0                                  ; will be no pages left in free pool after this
14
        STR     r6, [r1, #FreePoolDANode + DANode_PMPSize] ; if possible then update size

        LDR     r0, [r1, #FreePoolDANode + DANode_PMP]  ; r0 -> free pool page list
        ADD     r0, r0, r6, LSL #2                      ; r0 -> first page we're taking out of free pool

        LDR     lr, =L1PT
        ADD     r8, lr, r8, LSR #18                     ; point r8 at start of L1 we may be updating
        ADD     r1, r7, r3, LSR #10                     ; point r1 at L2PT for r3 again
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #PageTable_PageFlags]        ; access privs (+CB bits)
20
        LDR     r6, [r1], #4                            ; get L2PT entry again
        TST     r6, #3                                  ; if no fault
        BNE     %FT25                                   ; then skip

        Push    "r1-r2, r4"
        MOV     lr, #-1
        LDR     r2, [r0]                                ; get page number to use
        STR     lr, [r0], #4                            ; remove from PMP
        Push    "r0"
        BL      BangCamUpdate                           ; Map in to L2PT access window

; now that the page is mapped in we can zero its contents (=> cause translation fault for area initially)
; L1PT won't know about the page yet, so mapping it in with garbage initially shouldn't cause any issues

        ADD     r0, r3, #4096
        MOV     r1, #0
        MOV     r2, #0
        MOV     r4, #0
        MOV     r6, #0
15
        STMDB   r0!, {r1,r2,r4,r6}                      ; store data
        TEQ     r0, r3
        BNE     %BT15

        ; Make sure the page is seen to be clear before we update L1PT to make
        ; it visible to the MMU
        PageTableSync

        Pull    "r0-r2, r4"

        LDR     lr, =ZeroPage
        LDR     r6, [lr, #L2PTUsed]
        ADD     r6, r6, #4096
        STR     r6, [lr, #L2PTUsed]

; now update 4 words in L1PT (corresponding to 4M of address space which is covered by the 4K of L2)
; and point them at the physical page we've just allocated (r1!-4 will already hold physical address+bits now!)

        LDR     r6, [r1, #-4]                           ; r6 = physical address for L2 page + other L2 bits
        MOV     r6, r6, LSR #12                         ; r6 = phys.addr >> 12
 [ MEMM_Type = "VMSAv6"
        LDR     lr, =L1_Page
 |
        LDR     lr, =L1_Page + L1_U                     ; form other bits to put in L1
 ]
        ORR     lr, lr, r6, LSL #12                     ; complete L1 entry
        STR     lr, [r8, #0]                            ; store entry for 1st MB
        ADD     lr, lr, #1024                           ; advance L2 pointer
        STR     lr, [r8, #4]                            ; store entry for 2nd MB
        ADD     lr, lr, #1024                           ; advance L2 pointer
        STR     lr, [r8, #8]                            ; store entry for 3rd MB
        ADD     lr, lr, #1024                           ; advance L2 pointer
        STR     lr, [r8, #12]                           ; store entry for 4th MB
25
        ADD     r3, r3, #4096                           ; advance L2PT logical address
        ADD     r8, r8, #16                             ; move onto L1 for next 4M

        TEQ     r1, r2
        BNE     %BT20
        PageTableSync
30
        CLRV
        EXIT

; Come here if not enough space in free pool to allocate level2

90
        ADRL    r0, ErrorBlock_CantAllocateLevel2
  [ International
        BL      TranslateError
  |
        SETV
  ]
        STR     r0, [sp]
        EXIT

;**************************************************************************

  [ ChocolateSysHeap
;
; CreateChocolateBlockArray
;
; entry: r2 = No. of blocks to be created in array (N)
;        r3 = size of each block in bytes (S, must be multiple of 4)
;
; exit:
;        r2 = address of chocolate block array (parent SysHeap block address)
;        array is initialised to all blocks free
;   OR   V set, r0=error pointer, if error (from OS_Heap)
;
; - A Chocolate block array is only suitable for blocks of single fixed size.
;   These blocks may be allocated and freed in any order, but never resized.
; - Allocating and freeing blocks from a Chocolate block array is much faster
;   than OS_Heap, and the cost of operations is independent of N.
; - A Chocolate block array is a single block in the SysHeap, and looks like this
;   (excluding the internal structure of OS_Heap blocks):
;
;  - array header (3 words):
;    - word 0  =  total no. of blocks in array (N)
;    - word 1  =  size of each block container (S+4)
;    - word 2  -> first free block container in array, or 0 if none free
;  - followed immediately by N block containers, each of form:
;    - container header (1 word):
;      - word 0 :  bits  0..30 = container id (C)
;                                C = (S+4)*I, where I is array index, 0..N-1
;                  bit  31     = 1 if block is free, 0 if block is in use
;    - followed immediately by the S/4 words of the block itself
;      - if the block is in use, these words are as defined by the client
;      - if the block is free, the first word is a pointer to the next free
;        block container (or 0 if end of free list), and the other words
;        are undefined
;
; - A Chocolate block array requires a SysHeap block of 3*4 + N*(S + 4) bytes
;
CreateChocolateBlockArray ROUT
        Push    "r0,r1,r3,r4,r5,lr"
        MOV     r5,r2                ;N
        ADD     r4,r3,#4             ;S+4
        MUL     r3,r5,r4
        ADD     r3,r3,#3*4
        BL      ClaimSysHeapNode
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
; ClaimChocolateBlock
;
; entry: r3 = address of parent ChocolateBlockArray (must be valid)
; exit:  r2 = address of allocated block
;        r3 = size of block
;  OR    V set, R0=error (no free blocks)
;
ClaimChocolateBlock ROUT
        Push    "r1,r4,lr"
        MRS     r4,CPSR
        ORR     r1,r4,#I32_bit
        MSR     CPSR_c,r1         ;protect critical manipulation from interrupt re-entry
        LDR     r2,[r3,#8]        ;pick up block container at front of free list
        CMP     r2,#0
        BEQ     ClaimChocolateBlock_NoneFree
        LDR     r1,[r2]
        BIC     r1,r1,#&80000000  ;clear the free flag
        STR     r1,[r2]
        LDR     r1,[r2,#4]        ;next free block container
        STR     r1,[r3,#8]        ;put it at front
        ADD     r2,r2,#4          ;address of block
        LDR     r3,[r3,#4]
        SUB     r3,r3,#4          ;size of block
        BIC     r4,r4,#V_bit      ;return with V clear
        MSR     CPSR_cf,r4        ;restore IRQ state
        Pull    "r1,r4,pc"
;
;DON'T even think about internationalisation - this exit route must be fast
ClaimChocolateBlock_NoneFree
        ADR     R0,ChocolateBlock_NFError
        ORR     r4,r4,#V_bit      ;return with V set
        MSR     CPSR_cf,r4        ;restore IRQ state
        Pull    "r1,r4,pc"

;
; FreeChocolateBlock
;
; entry: r1 = address of parent ChocolateBlockArray (must be valid)
;        r2 = address of block to free (may be invalid)
; exit:  -
;   OR   V set, R0=error (not a ChocolateBlock), r1,r2 still preserved
;
FreeChocolateBlock ROUT
        Push    "r2,r3,r4,lr"
        MRS     r4,CPSR
        ORR     r3,r4,#I32_bit
        MSR     CPSR_c,r3         ;protect critical manipulation from interrupt re-entry
        ADD     r3,r1,#12         ;r3 -> first block container
        SUB     r2,r2,#4          ;r2 -> container for block (if valid)
        CMP     r2,r3
        BLO     FreeChocolateBlock_NaffOff
        LDR     lr,[r1,#-4]       ;OS_Heap's size word (naughty!)
        ADD     lr,lr,r1
        CMP     r2,lr
        BHS     FreeChocolateBlock_NaffOff
        LDR     lr,[r2]           ;block container id
        TST     lr,#&80000000     ;free flag
        BNE     FreeChocolateBlock_NaffOff
        ADD     lr,lr,r3          ;lr := address of block container, from container id
        CMP     lr,r2
        BNE     FreeChocolateBlock_NaffOff
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
        MSR     CPSR_cf,r4        ;restore IRQ state
        Pull    "r2,r3,r4,pc"
;
;DON'T even think about internationalisation - this exit route must be fast
FreeChocolateBlock_NaffOff
        ADR     R0,ChocolateBlock_NOError
        ORR     r4,r4,#V_bit      ;return with V set
        MSR     CPSR_cf,r4        ;restore IRQ state
        Pull    "r2,r3,r4,pc"

;
;forget internationalisation - if these errors aren't dealt with silently,
;                              the kernel's stuffed anyway
ChocolateBlock_NFError
        DCD     0
        DCB     "Chocolate SysHeap claim failed",0
        ALIGN
ChocolateBlock_NOError
        DCD     0
        DCB     "not a Chocolate SysHeap block",0
        ALIGN

  ] ;ChocolateSysHeap

;**************************************************************************
;
;       InitDynamicAreas - Initialise nodes for dynamic areas
;
;       It only initialises free pool, appspace and sysheap nodes
;       The other areas are created properly, after the screen area has been created (improperly)
;
; in:   -
; out:  -
;

InitDynamicAreas Entry "r0-r12"
        LDR     lr, =ZeroPage+AppSpaceDANode
        ADRL    r0, InitAppSpaceTable
        LDMIA   r0, {r0-r8}
        STMIA   lr, {r0-r8}

        LDR     lr, =ZeroPage+FreePoolDANode
        ADRL    r0, InitFreePoolTable
        LDMIA   r0, {r0-r8}                     ; copy initial data into node
        STMIA   lr, {r0-r8}

; Initialise the system heap first - we need it to store the PMP for the free
; pool

        LDR     r0, =SysHeapStart
        LDR     r1, =magic_heap_descriptor
        MOV     r2, #Nil
        MOV     r3, #hpdsize
        MOV     r4, #32*1024 - (SysHeapStart-SysHeapChunkAddress)
        STMIA   r0, {r1-r4}

        LDR     r0, =ZeroPage                   ; initialise module list to empty
      [ ZeroPage = 0
        STR     r0, [r0, #Module_List]
      |
        MOV     lr, #0
        STR     lr, [r0, #Module_List]
      ]

        LDR     lr, =ZeroPage+SysHeapDANode     ; initialise system heap node
        ADR     r0, InitSysHeapTable
        LDMIA   r0, {r0-r8}
        STMIA   lr, {r0-r8}
        LDR     r0, =ZeroPage
 [ FreePoolAddress < SysHeapStart
        LDR     lr, =ZeroPage+FreePoolDANode    ; cf comments above/below - what was old code? KJB
 ]
        STR     lr, [r0, #DAList]               ; store pointer to 1st node on list (either free pool or sys heap)

; TODO have asserts to check that this all fits OK
  [ ChocolateSysHeap
        ASSERT  ChocolateCBBlocks = ChocolateBlockArrays +  0
        ASSERT  ChocolateSVBlocks = ChocolateBlockArrays +  4
        ASSERT  ChocolateTKBlocks = ChocolateBlockArrays +  8
        ASSERT  ChocolateMRBlocks = ChocolateBlockArrays + 12
        ASSERT  ChocolateMABlocks = ChocolateBlockArrays + 16
        ASSERT  ChocolateMSBlocks = ChocolateBlockArrays + 20
        LDR     r1,=ZeroPage+ChocolateBlockArrays
        MOV     r2,#MaxChocolateCBBlocks
        MOV     r3,#3*4
        BL      CreateChocolateBlockArray       ; better not fail
        STR     r2,[r1,#0]
        MOV     r2,#MaxChocolateSVBlocks
        MOV     r3,#VecNodeSize
        BL      CreateChocolateBlockArray       ; better not fail
        STR     r2,[r1,#4]
        MOV     r2,#MaxChocolateTKBlocks
        MOV     r3,#TickNodeSize
        BL      CreateChocolateBlockArray       ; better not fail
        STR     r2,[r1,#8]
        MOV     r2,#MaxChocolateMRBlocks
        MOV     r3,#ROMModule_NodeSize
        BL      CreateChocolateBlockArray       ; better not fail
        STR     r2,[r1,#12]
        MOV     r2,#MaxChocolateMABlocks
        MOV     r3,#ModInfo + Incarnation_Postfix + 8
        BL      CreateChocolateBlockArray       ; better not fail
        STR     r2,[r1,#16]
        MOV     r2,#MaxChocolateMSBlocks
        MOV     r3,#ModSWINode_Size
        BL      CreateChocolateBlockArray       ; better not fail
        STR     r2,[r1,#20]

  ]

  [ Oscli_HashedCommands
        MOV     r3,#4*(Oscli_MHashValMask+1)
        BL      ClaimSysHeapNode                ; better not fail
        LDR     r0,=ZeroPage
      [ ZeroPage = 0
        STR     r0,[r0,#Oscli_CmdHashSum]
      |
        MOV     r3,#0
        STR     r3,[r0,#Oscli_CmdHashSum]
      ]
        STR     r2,[r0,#Oscli_CmdHashLists]
        MOV     r3,#Oscli_MHashValMask+1
      [ ZeroPage <> 0
        MOV     r0, #0
      ]
DynArea_OHinit_loop
        STR     r0,[r2],#4
        SUBS    r3,r3,#1
        BNE     DynArea_OHinit_loop
  ]

  [ DynArea_QuickHandles

        LDR     r3, =DynArea_ws_size
        BL      ClaimSysHeapNode                    ; should not give error - kernel boot
      [ PMPDebug
        DebugReg r2, "DynArea_ws="
      ]
        LDR     r0, =ZeroPage
        STR     r2, [r0, #DynArea_ws]
        MOV     r11, r2
        LDR     r3, =DynArea_ws_size
        ADD     r3, r3, r2
      [ ZeroPage <> 0
        MOV     r0, #0
      ]
DynArea_QHinit_loop1
        STR     r0, [r2], #4
        CMP     r2, r3
        BLO     DynArea_QHinit_loop1

        MOV     r1, #-1
        STR     r1, DynArea_CreatingHandle
        STR     r1, DynArea_LastTreacleHandle
        STR     r1, DynArea_LastEnumHandle
        STR     r1, DynArea_OD8Clamp1
        STR     r1, DynArea_OD8Clamp2
        MOV     r1, #&1000
        RSB     r1, r1, #0
        STR     r1, DynArea_OD8Clamp3               ; 4G - 4k

        ADR     r1, DynArea_QHandleArray            ; init all Qhandles as free, free list = 1..DynArea_NumQHandles
        MOV     r2, #1
        STR     r2, DynArea_FreeQHandles
DynArea_QHinit_loop2
        ADD     r2, r2, #1
        STR     r2, [r1], #4
        CMP     r2, #DynArea_NumQHandles
        BLO     DynArea_QHinit_loop2
        MOV     r2, #0
        STR     r2, [r1]                            ; 0 = end of free list

        MOV     r1, #DynArea_NewAreas-1
        ADD     r1, r1, #DynArea_NumQHandles        ; first non-quick DA number -1
        STR     r1, DynArea_TreacleGuess

        LDR     r1, =ZeroPage+FreePoolDANode
        STR     r1, DynArea_SortedList              ; initially, FreePool at front of sorted list,
        LDR     r2, =ZeroPage+SysHeapDANode
        STR     r2, [r1, #DANode_SortLink]          ; and SysHeap second...
        MOV     r1, #0
        STR     R1, [r2, #DANode_SortLink]          ; ...and last

        ADR     r1, DynArea_SysQHandleArray
        LDR     r2, =ZeroPage+SysHeapDANode
        STR     r2, [r1, #ChangeDyn_SysHeap:SHL:2]
        LDR     r2, =ZeroPage+FreePoolDANode
        STR     r2, [r1, #ChangeDyn_FreePool:SHL:2]

; Initialise the address lookup table for the current DA's
; Assumes we have at least one DA to start with!
        LDR     r2, =ZeroPage+DAList
        LDR     r2, [r2]
DynArea_AddrLookup_loop
        BL      AddDAToAddrLookupTable
        LDR     r2, [r2, #DANode_Link]
        TEQ     r2, #0
        BNE     DynArea_AddrLookup_loop

  |
        ASSERT  ZeroPage = 0
        MOV     r0, #0
        STR     r0, [r0, #DynArea_ws]

  ] ;DynArea_QuickHandles

        LDR     r0, =ZeroPage
      [ ZeroPage = 0
        STR     r0, [r0, #CDASemaphore]         ; clear CDASemaphore
      |
        MOV     r2, #0
        STR     r2, [r0, #CDASemaphore]         ; clear CDASemaphore
      ]

; Now that the system heap is initialised we can create a page list for the
; free pool and start pushing the free pages into it. However it's highly
; unlikely that we'll be able to build the full page list without having to
; grow the system heap - for which we'd want the fast pages to be available.

; So to cope with this we start by putting the fast pages into the page list,
; growing the system heap for every page we insert (a bit slow but reliable).
; After each grow we try to claim the memory needed for the full page list;
; on success we then switch to a different algorithm which fills the main page
; list.

        SUB     sp, sp, #4                      ; Store the initial list on the stack
        LDR     r5, =ZeroPage
        LDR     r6, =ZeroPage+FreePoolDANode
        STR     sp, [r6, #DANode_PMP]
        MOV     r0, #1
        STR     r0, [r6, #DANode_PMPMaxSize]
        MOV     r0, #0
        STR     r0, [r6, #DANode_PMPSize]
        MOV     r0, #-1
        STR     r0, [sp]

        LDR     r0, [r5, #InitUsedStart]
        ADD     r0, r0, #DRAMOffset_FirstFixed - DRAMOffset_L1PT
        BL      PhysAddrToPageNo
        MOV     r7, r0                          ; r7 = page number of start of static chunk
        LDR     r0, [r5, #InitUsedEnd]
        BL      PhysAddrToPageNo
        SUB     r8, r0, #1                      ; r8 = page number of last page in statics
        ADD     r9, r5, #PhysRamTable
        LDMIA   r9!, {r0, r10}                  ; get VRAM info
        MOV     r10, r10, LSR #12               ; r10 = current page number
        LDMIA   r9!, {r0, r11}                  ; get first regular RAM chunk
        SUB     r10, r10, #1                    ; set things up so the first call to NextFreePage will return the first page of the block
        MOV     r11, r11, LSR #12
        ADD     r11, r11, #1
        LDR     r4, [r5, #CamEntriesPointer]
10
        ; See if we have enough space
        LDR     r3, [r5, #MaxCamEntry]
        ADD     r3, r3, #1
        MOV     r3, r3, LSL #2
        Push    "r3"
        MOV     r0, #HeapReason_Desc
        BL      DoSysHeapOpWithExtension        ; HACK - check space before calling, to avoid crashing when the grow fails and tries to generate an error (vector table not initialised yet, so crashes when UKSWIV is invoked in order to call MessageTrans)
        Pull    "r3"
        SUB     r2, r2, #4096                   ; Paranoia
        CMP     r2, r3
        BLT     %FT20
        BL      ClaimSysHeapNode
        BVC     %FT40
20
        ; Find a page we can use to grow the system heap
        BL      NextFreePage                    ; n.b. no out-of-pages check
        STR     r10, [sp]
        LDR     lr, =AreaFlags_FreePool :AND: DynAreaFlags_AccessMask
        STR     lr, [r0, #CAM_PageFlags]
        STR     r6, [r0, #CAM_PMP]
        MOV     lr, #0
        STR     lr, [r0, #CAM_PMPIndex]
        MOV     lr, #1
        STR     lr, [r6, #DANode_PMPSize]
        ; Now grow the system heap by 4K. This had better consume the page!
        MOV     r0, #ChangeDyn_SysHeap
        MOV     r1, #4096
        SWI     XOS_ChangeDynamicArea
        B       %BT10

40
        ; We've successfully allocated the memory for the PMP - start filling
        ; it in. To ensure the pages are in the correct order we need to fill
        ; it from the last entry working backwards, but unfortunately we don't
        ; know exactly how many pages there are - so once we're done we'll have
        ; to shuffle the list down.
        MOV     r0, r3, LSR #2
      [ PMPDebug
        DebugReg r2, "FreePool PMP="
        DebugReg r0, "PMPMaxSize="
      ]
        STR     r0, [r6, #DANode_PMPMaxSize]
        ADD     r3, r2, r3                      ; -> end of list
        MOV     r1, r3
        STR     r2, [r6, #DANode_PMP]
45
        BL      NextFreePage
        CMP     r10, #-1
        STRNE   r10, [r3, #-4]!
        BNE     %BT45                           ; Keep going until we run out of pages
        ; Left with:
        ; r1 -> end of memory block
        ; r2 -> start of memory block
        ; r3 -> last used entry
        ; Calculate and store size
        SUB     r12, r1, r3
        MOV     r12, r12, LSR #2
        STR     r12, [r6, #DANode_PMPSize]
      [ PMPDebug
        DebugReg r12, "PMPSize="
      ]
        ; Shuffle everything down, and fill in the CAM entries (which we
        ; couldn't do earlier since we didn't know the final PMP indices)
        MOV     r12, #0
        LDR     lr, =AreaFlags_FreePool :AND: DynAreaFlags_AccessMask
56
        CMP     r3, r1
        LDRNE   r0, [r3], #4
        STRNE   r0, [r2], #4
        ADDNE   r0, r4, r0, LSL #CAM_EntrySizeLog2
        STRNE   lr, [r0, #CAM_PageFlags]
        STRNE   r6, [r0, #CAM_PMP]
        STRNE   r12, [r0, #CAM_PMPIndex]
        ADDNE   r12, r12, #1
        BNE     %BT56
60
        ; Now r2 -> end of used portion
        ; Fill empty space with -1 (although, we could probably free the space - I don't think it's possible it will ever get used)
        MOV     r0, #-1
61
        CMP     r2, r1
        STRNE   r0, [r2], #4
        BNE     %BT61

        ; Free pool should now be ready for business

        ADD     sp, sp, #4
      [ PMPDebug
        DebugTX "InitDynamicAreas done"
      ]
      [ PMPParanoid
        BL      ValidatePMPs
      ]
        EXIT

;
; NextFreePage - Find next page to insert into the free pool on startup
;
; In:
;   r4 -> CAM
;   r7 = page number of start of static chunk
;   r8 = page number of end of static chunk
;   r9 -> next PhysRamTable entry
;   r10 = Current page number
;   r11 = Number of pages left in current chunk
; Out:
;   r0 -> CAM entry for page
;   r10 = Next free page in optimal order, -1 if no more pages
;   r9, r11 updated
;
; We have to move all free pages (ie ones not occupied by the static pages)
; into the free pool.
; By default, pages will get taken from the end of the free pool when other
; dynamic areas are initialised or grown. So make sure that the slowest RAM
; is at the start of the free pool and the fastest is at the end; this is the
; reverse of the order in PhysRamTable. Also, within each group of pages (i.e.
; PhysRamTable entry), we want the pages to be in decreasing physical address
; order - so that when they are moved to a DA they end up in increasing address
; order, leading to more optimal DMA transfer lists.
;
; Also note that the VRAM block is kept at the start of the free pool, mainly
; to match old behaviour (it's not clear whether moving it elsewhere will have
; any significant impact on the system - especially when you consider that
; shrinking screen memory will end up adding the pages to the end of the pool
; rather than the start).
;
; Over time this optimal ordering will be lost, so at a later date it might be
; nice to re-sort pages as they are added back into the free pool (and move the
; VRAM block to the end of PhysRamTable, so that it's in order fast RAM -> slow
; RAM -> fast DMA -> slow DMA -> VRAM, so that sorting by page number is
; all that's required to deal with both contiguity and desirability)
;
; In terms of this routine, we fill the free pool from the highest entry down,
; so we want the first page returned to be the lowest-numbered page from the
; first (non-VRAM) PhysRamTable entry.
;
NextFreePage    ROUT
        Entry
10
        SUBS    r11, r11, #1
        ADD     r10, r10, #1
        BEQ     %FT30
20
        CMP     r10, r7
        CMPHS   r8, r10
        BHS     %BT10                           ; page is in statics
        ; Check the CAM map to see if the page is already taken - this will detect the DMA regions, which aren't included in InitUsedStart/InitUsedEnd
        ADD     r0, r4, r10, LSL #CAM_EntrySizeLog2
        LDR     lr, [r0, #CAM_PageFlags]
        TST     lr, #PageFlags_Unavailable
        BNE     %BT10
        ; Page is good
        EXIT

30
        ; Advance to next block
        LDR     lr, =ZeroPage+PhysRamTable+8
        CMP     lr, r9                          ; if we've just processed the VRAM block, we're done
        BEQ     %FT90
        LDMIA   r9!, {r0, r11}                  ; else get next block
        MOVS    r11, r11, LSR #12               ; if no more blocks left...
        BNE     %BT20
        MOV     r10, #0
        MOV     r9, lr
        LDMDB   lr, {r0, r11}                   ; ...then process VRAM
        MOVS    r11, r11, LSR #12               ; And if no VRAM...
        BNE     %BT20
90                                              ; ...then we're done
        MOV     r10, #-1
        EXIT
                

        LTORG

InitFreePoolTable
 [ FreePoolAddress > SysHeapStart
        &       0                               ; link: no more nodes on list
 |
        &       ZeroPage+SysHeapDANode
 ]
        &       ChangeDyn_FreePool
        &       FreePoolAddress
        &       AreaFlags_FreePool
        &       0                               ; size will be updated later
        &       0                               ; max size is computed
        &       0                               ; no workspace needed
        &       0                               ; no handler needed
        &       FreePoolString                  ; title

InitSysHeapTable
 [ FreePoolAddress > SysHeapStart
        &       ZeroPage+FreePoolDANode         ; link -> free pool node, since FreePoolAddress > SysHeapStart
 |
        &       0
 ]
        &       ChangeDyn_SysHeap
        &       SysHeapStart
        &       AreaFlags_SysHeap
        &       32*1024-(SysHeapStart-SysHeapChunkAddress) ; size
        &       SysHeapMaxSize
        &       SysHeapStart                    ; workspace pointer -> base of heap
        &       DynAreaHandler_SysHeap          ; area handler
        &       SysHeapString                   ; title

InitAppSpaceTable
        &       0                               ; link: not on list
        &       ChangeDyn_AplSpace
        &       0                               ; base address
        &       AreaFlags_AppSpace
        &       0                               ; size will be set up later
        &       AplWorkMaxSize
        &       0                               ; no workspace needed
        &       0                               ; no handler needed
        &       AppSpaceString                  ; title

FreePoolString
        =       "Free pool", 0
AppSpaceString
        =       "Application space", 0
SysHeapString
        =       "System heap", 0
        ALIGN



;**************************************************************************
;
;       ClaimCDASemaphore - Claims CDASemaphore if possible
;
; out:  EQ -> CDASemaphore claimed
;       NE -> not claimed
;
ClaimCDASemaphore
        Entry   "r10"
        LDR     r10, =ZeroPage                  ; check we're not in an IRQ
        LDR     lr, [r10, #IRQsema]
        TEQ     lr, #0
        LDREQ   lr, [r10, #CDASemaphore]       ; now also check whether ChangeDynamicArea is already threaded
        TEQEQ   lr, #0
        STREQ   pc, [r10, #CDASemaphore]     ; store non-zero value in CDASemaphore, to indicate we're threaded
        EXIT

;**************************************************************************
;
;       ChangeDynamicSWI - implement OS_ChangeDynamicArea (change the
;                          size of a dynamic area)
;
; in:   r0 = area number
;       r1 = size of change (in bytes, signed integer)
;
; out:  r0   preserved
;       r1 = actual amount moved (in bytes, unsigned integer)
;

  [ DA_Batman
;OR, a special call is allowed for internal use:
;
; in:   r0 = ChangeDyn_Batman (-3)
;       r1 = size of change (in bytes, signed integer)
;       r2 -> pseudo DANode for this call - base of DA will be base of fragment to map/unmap,
;             magnitude of r1 will give size of fragment, sign of r1 is +ve for map -ve for unmap
  ]

ChangeDynamicSWI ROUT
        Push    "r0, r2-r9, r10, lr"

        FastCDA_ProfInit r3

        BL      ClaimCDASemaphore
        BNE     failure_IRQgoing

 [ DebugCDA2
        DLINE   "Entering OS_ChangeDynamicArea (new code)"
 ]

  [ DA_Batman
    ;check for special Batman call (which uses OS_ChangeDynamicArea to map or unmap a fragment of a sparse DA)
        CMP     r0, #ChangeDyn_Batcall
        MOVEQ   r10, r2                         ; Batman call passes a pseudo DANode in r2
        BEQ     CDA_handlechecked
  ]

        Push    "r1"
        MOV     r1, r0
 [ DebugCDA2
        DREG    r1, "Checking list for area number "
 ]

  [ DynArea_QuickHandles
        BL      QCheckAreaNumber                ; check area number is on list
  |
        BL      CheckAreaNumber                 ; check area number is on list
  ]

        Pull    "r1"
        BCC     failure_IRQgoingClearSemaphore

 [ DebugCDA2
        DLINE   "Found entry on list"
 ]

  [ DA_Batman
        ;a sparse area is not allowed to do an ordinary grow or shrink
        ;
        LDR     r11, [r10, #DANode_Flags]
        TST     r11, #DynAreaFlags_SparseMap
        BNE     failure_IRQgoingClearSemaphore
        CMP     r0, #ChangeDyn_FreePool         ; Free pool is handled here. Other PMPs call through to their resize handler.
        TSTNE   r11, #DynAreaFlags_PMP
        BNE     CDA_PMP
  ]
      [ PMPParanoid
        BL      ValidatePMPs
      ]

CDA_handlechecked

  [ DynArea_QuickHandles
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #DynArea_ws]
        LDR     r5, DynArea_OD6Signature
        CMP     r0, #ChangeDyn_MaxArea
        BLS     daq_cda_od6done
        CMP     r0, #&FFFFFFF0                  ;don't count special DA numbers, such as ChangeDyn_AplSpace
        BHI     daq_cda_od6done
        TST     r5, #&80000000                  ;if set, disables resize signature for this call
        STREQ   r5, DynArea_OD6PrevSignature
        STREQ   r0, DynArea_OD6Handle
        ORREQ   r5, r5, #4
daq_cda_od6done
        BIC     r5, r5, #&80000000              ;clear any disable
        STR     r5, DynArea_OD6Signature
  ]

        LDR     r5, =ZeroPage
        LDR     r5, [r5, #Page_Size]            ; r5 = page size throughout
        SUB     r12, r5, #1                     ; r12 = page mask
        ADD     r1, r1, r12
        BICS    r1, r1, r12
        BEQ     IssueServiceMemoryMoved         ; zero pages! (r0 = area number, r1 = size change (0))
        BPL     AreaGrow

AreaShrink ROUT
        RSB     r1, r1, #0                      ; make size change positive
 [ DebugCDA2
        DREG    r0, "Shrinking area ", cc
        DREG    r1, " by "
 ]
        MOV     r11, r10                        ; source is area
        CMP     r0, #ChangeDyn_FreePool         ; if source is free pool
        BEQ     ShrinkFreePoolToAppSpace        ; then dest is appspace
        LDR     r12, =ZeroPage+FreePoolDANode   ; else dest is free pool

        ASSERT  DANode_PMPMaxSize = DANode_PMPSize +4
        ADD     r2, r12, #DANode_PMPSize
        LDMIA   r2, {r2, r3}

      [ PMPDebug
        DebugReg r0,"Shrinking area "
        DebugReg r1,"by "
        DebugReg r2,"FreePool PMPSize "
      ]
        SUB     lr, r3, r2                      ; lr = amount dest could grow

      [ ZeroPage = 0
        TEQ     r11, #AppSpaceDANode            ; check if src = appspace
      |
        LDR     r2, =ZeroPage+AppSpaceDANode
        TEQ     r11, r2                         ; check if src = appspace
      ]

        LDR     r2, [r11, #DANode_Size]         ; amount src could shrink
        SUBEQ   r2, r2, #&8000                  ; protect first 32K of app space because app space DANode is silly
        CMP     lr, r2, LSR #12
        MOVHI   lr, r2, LSR #12                 ; lr = min(amount dest could grow, amount src could shrink)

        CMP     lr, r1, LSR #12
        BHS     %FT15

; we can't move all that is required, so move smaller amount

        MOV     r1, lr, LSL #12                 ; move smaller amount

        BL      GenNotAllMovedError
        SUB     lr, r5, #1                      ; lr = pagesize mask
        BICS    r1, r1, lr                      ; a pagesize multiple
        BEQ     IssueServiceMemoryMoved
15
      [ ZeroPage = 0
        CMP     r11, #AppSpaceDANode            ; if src <> appspace
      |
        LDR     lr, =ZeroPage+AppSpaceDANode
        CMP     r11, lr                         ; if src <> appspace
      ]
        BNE     %FT17                           ; then don't call app
        Push    "r10"                           ; save -> to area we tried to shrink
        MOV     r10, r1
        BL      CheckAppSpace
        Pull    "r10"
        BVS     ChangeDynError
17
        BL      CallPreShrink
        BVS     ChangeDynError                  ; (r10 still points to area we tried to shrink)
        CMP     r2, r1                          ; can we move as much as we wanted?
        MOVCS   r2, r1                          ; if not, then move lesser amount (r2 = amount we're moving)
        BLCC    GenNotAllMovedError             ; store error, but continue

        TEQ     r2, #0                          ; if can't move any pages
        BEQ     NoMemoryMoved                   ; then exit, issuing Service_MemoryMoved

        BL      DoTheShrink                     ; Move all the pages around

        LDR     r4, =ZeroPage
      [ ZeroPage = 0
        STR     r4, [r4, #CDASemaphore]         ; OK to reenter now (we've done the damage)
      |
        MOV     lr, #0
        STR     lr, [r4, #CDASemaphore]
      ]
        BL      CallPostShrink
        RSB     r1, r2, #0
        LDR     r0, [r11, #DANode_Number]       ; reload dynamic area number
        B       IssueServiceMemoryMoved

GrowFreePoolFromAppSpace ROUT
        ; To reduce code complexity, we treat a grow of the free pool as a
        ; shrink of application space
        GetAppSpaceDANode r10
        LDR     r0, [r10, #DANode_Flags]
        TST     r0, #DynAreaFlags_PMP
        RSB     r1, r1, #0                      ; (AreaShrink assumes negative size on entry)
        MOVEQ   r0, #ChangeDyn_AplSpace
        BEQ     AreaShrink
        ; Shrink of PMP appspace - go via CDA_PMP
        B       CDA_PMP

ShrinkFreePoolToAppSpace ROUT
        ; To reduce code complexity, we treat a shrink of the free pool as a
        ; grow of application space
        MOV     r0, #ChangeDyn_AplSpace
        GetAppSpaceDANode r10
        ; Emulate old behaviour, when this case used to be part of AreaShrink:
        ; * If app space doesn't have enough free space, clamp amount and
        ; generate NotAllMoved error (Regular AreaGrow logic will only do this
        ; if dest is free pool - grows of other areas have always failed
        ; outright if they're incapable of growing that big)
        ; * If shrinking more than current free pool size, attempt to shrink
        ; shrinkable DAs so that as much memory as possible can be moved to app
        ; space
        ; * Call CheckAppSpace (rule seems to be that if app space is touched,
        ; CheckAppSpace must be called, except when it's an explicit grow of
        ; app space)
        MOV     r12, r10                        ; required by e.g. TryToShrinkShrinkables
        ASSERT  DANode_MaxSize = DANode_Size +4
        ADD     r2, r10, #DANode_Size
        LDMIA   r2, {r2, r3}
        SUB     lr, r3, r2                      ; lr = amount dest could grow
 [ ShrinkableDAs
        CMP     r1, lr
        MOVHI   r1, lr
        BLHI    GenNotAllMovedError
        SUB     lr, r5, #1                      ; lr = pagesize mask
        BICS    r1, r1, lr                      ; a pagesize multiple
        BEQ     IssueServiceMemoryMoved
 ]

        LDR     r11, =ZeroPage+FreePoolDANode
 [ ShrinkableDAs
        LDR     r2, [r11, #DANode_PMPSize]      ; amount src could shrink
        CMP     r2, r1, LSR #12
        BLCC    TryToShrinkShrinkables
        BCS     %FT15                           ; [we can now do it all]

; we can't move all that is required, so move smaller amount

        MOV     r1, r2, LSL #12                 ; move smaller amount
 |
        LDR     r2, [r11, #DANode_PMPSize]      ; amount src could shrink
        CMP     r2, lr, LSR #12
        MOVCC   lr, r2, LSL #12                 ; lr = min(amount dest could grow, amount src could shrink)

        CMP     r1, lr
        BLS     %FT15     

; we can't move all that is required, so move smaller amount

        MOV     r1, lr                          ; move smaller amount
 ]
        BL      GenNotAllMovedError
        SUB     lr, r5, #1                      ; lr = pagesize mask
        BICS    r1, r1, lr                      ; a pagesize multiple
        BEQ     IssueServiceMemoryMoved
15
        Push    "r10"                           ; save -> to area we tried to shrink
        MOV     r10, r1
        BL      CheckAppSpace
        Pull    "r10"
        BVS     ChangeDynError
        LDR     r12, [r10, #DANode_Flags]
        TST     r12, #DynAreaFlags_PMP
        BNE     CDA_PMP                         ; Make sure PMP AppSpace goes via PMP handler
        ; Fall through...

AreaGrow ROUT
 [ DebugCDA2
        DREG    r0, "Growing area ", cc
        DREG    r1, " by "
 ]
        MOV     r12, r10                        ; dest is area specified
        CMP     r0, #ChangeDyn_FreePool         ; if dest is free pool
        BEQ     GrowFreePoolFromAppSpace        ; then src is appspace
        LDR     r11, =ZeroPage+FreePoolDANode   ; else src is free pool (may later be free+apl)

        ASSERT  DANode_MaxSize = DANode_Size +4
        ADD     r2, r12, #DANode_Size
        LDMIA   r2, {r2, r3}

      [ PMPDebug
        DebugReg r0,"Growing area "
        DebugReg r1,"by "
        DebugReg r2,"dest size "
        DebugReg r3,"dest max size "
        Push    "r0"
        LDR     r0, [r11, #DANode_PMPSize]      ; amount src could shrink
        DebugReg r0, "FreePool PMPSize "
        Pull    "r0"
      ]

        SUB     lr, r3, r2                      ; lr = amount dest could grow

 [ DebugCDA2
        DREG    lr, "Dest could grow by "
 ]
        LDR     r2, [r11, #DANode_PMPSize]      ; amount src could shrink

 [ DebugCDA2
        DREG    r2, "Src could shrink by "
 ]

        CMP     lr, r1                          ; if enough room in dest
        CMPHS   r2, r1, LSR #12                 ; and enough space in src
        MOVHS   r3, r1                          ; then can do full amount
        BHS     %FT65                           ; so skip this bit

; we can't move all that is required
;
; check if adding shrinkables or aplspace would allow us to succeed
; if it does then adjust registers, else give error
;

 [ DebugCDA2
        DLINE   "Can't move all required using just free pool"
 ]
        B       %FT62

61
        BL      GenNotAllMovedError
        SUB     lr, r5, #1                      ; lr = pagesize mask
        BICS    r1, r1, lr                      ; a pagesize multiple
        BEQ     IssueServiceMemoryMoved
        MOV     r3, r1
        B       %FT65

62

 [ ShrinkableDAs
; growing another area from free pool
; insert code here to check for shrinking shrinkable areas

        CMP     r1, lr                          ; if dest can't grow by this amount,
        BHI     %FT64                           ; we're definitely not doing anything

        CMP     r2, r1, LSR #12                 ; this should definitely set C=0 as required by TryToShrinkShrinkables
        Push    "lr"
        BLCC    TryToShrinkShrinkables_Bytes
        Pull    "lr"
        MOVCS   r3, r1                          ; if succeeded set r3 to number of bytes to do
        BCS     %FT65                           ; and do it
64

; end of inserted code
 ]

        GetAppSpaceDANode r4
        EORS    r6, r4, r12                     ; only take from app space if dest isn't app space!
        LDRNE   r6, [r4, #DANode_Size]          ; get current size of apl space
        LDRNE   r4, [r4, #DANode_Flags]
        EORNE   r4, r4, #DynAreaFlags_PMP
        TSTNE   r4, #DynAreaFlags_PMP
        SUBNE   r6, r6, #&8000                  ; can't take away 0-&7FFF
        ADD     r3, r2, r6, LSR #12             ; add on to amount we could remove from free pool (pages)

 [ DebugCDA2
        DREG    r6, "Can get from app space an additional ", cc
        DREG    r3, " bytes making a total of ", cc
        DLINE   " pages"
 ]

        CMP     lr, r1                          ; if not enough room in dest
        CMPHS   r3, r1, LSR #12                 ; or src still doesn't have enough
        MOVLO   r1, #0                          ; then don't move any
        BLO     %BT61                           ; and return error

        ; To reduce code complexity, first shrink application space into the free pool, then take the combined chunk from the free pool
        Push    "r0-r1,r3"
        LDR     r3, =ZeroPage
        MOV     r0, #0
        STR     r0, [r3, #CDASemaphore]         ; Allow nested call
        RSB     r1, r1, r2, LSL #12             ; free pool size minus total amount = app space size change needed
        MOV     r0, #ChangeDyn_AplSpace
        SWI     XOS_ChangeDynamicArea
        STR     pc, [r3, #CDASemaphore]         ; reclaim semaphore
        MOVVS   r1, #1
        CMP     r1, #0                          ; if not all moved
        Pull    "r0-r1"
        MOVNE   r1, #0                          ; then claim nothing moved
        BNE     %BT61                           ; and return error
        ; Double-check that the free pool did actually grow large enough
        ; (just paranoia for now, but may be important in future)
        LDR     r3, [r11, #DANode_PMPSize]
        CMP     r3, r1, LSR #12
        MOVLO   r1, #0
        BLO     %BT61

        MOV     r3, r1                          ; amount actually doing (bytes)
65

        MOV     r7, r3                          ; set up r7 to be total amount

 [ DebugCDA2
        DREG    r3, "Amount actually moving into area = "
        DREG    r7, "Amount coming from 1st src area = "
 ]

; now split up grow into bite-size chunks, and call DoTheGrow to do each one

        Push    "r3"                            ; save original total amount

        LDR     lr, [r12, #DANode_Flags]        ; could this area require particular physical pages at all?
        TST     lr, #DynAreaFlags_NeedsSpecificPages+DynAreaFlags_NeedsDMA
        TSTEQ   lr, #DynAreaFlags_PMP           ; detect batcall from PMP PhysOp
        BNE     %FT70                           ; [yes it could, so do it in lumps]

        MOV     r1, #0                          ; no page block
        MOV     r2, r3, LSR #12                 ; number of pages to do
        BL      CallPreGrow
        LDRVS   r3, [sp]                        ; if error, haven't done any, so restore total as how much to do
        BVS     %FT95

        Push    "r3, r7"
        MOV     r2, r7, LSR #12
        BL      DoTheGrowNotSpecified
        Pull    "r3, r7"

        LDR     r3, [sp]                        ; restore total amount
        MOV     r1, #0                          ; indicate no page block (and ptr to semaphore)
      [ ZeroPage = 0
        STR     r1, [r1, #CDASemaphore]         ; OK to reenter now (we've done the damage)
      |
        LDR     r2, =ZeroPage
        STR     r1, [r2, #CDASemaphore]         ; OK to reenter now (we've done the damage)
      ]
        MOV     r2, r3, LSR #12
        BL      CallPostGrow
        BVS     %FT95
        B       %FT80

70
        Push    "r3, r7"
        CMP     r7, #PageBlockChunk             ; only do 1 area, so do min(r7,page)
        MOVHI   r7, #PageBlockChunk
        MOV     r2, r7, LSR #12                 ; number of entries to fill in in page block
        BL      DoTheGrow
        Pull    "r3, r7"
        BVS     %FT95
        CMP     r7, #PageBlockChunk             ; if 1st area is more than 1 page
        SUBHI   r3, r3, #PageBlockChunk         ; then reduce total
        SUBHI   r7, r7, #PageBlockChunk         ; and partial amounts by 1 page and do it again
        BHI     %BT70

80
        Pull    "r3"                            ; restore total amount

        MOV     r1, r3
        LDR     r0, [r12, #DANode_Number]       ; reload dynamic area number
        B       IssueServiceMemoryMoved

95
        Pull    "r1"                            ; restore total amount
        SUB     r1, r1, r3                      ; subtract off amount left, to leave done amount
        B       ChangeDynErrorSomeMoved

GenNotAllMovedError Entry "r0"
        ADRL    r0, ErrorBlock_ChDynamNotAllMoved
 [ International
        BL      TranslateError
 ]
        STR     r0, [sp, #2*4]          ; sp -> r0,lr, then stacked r0,r2-r9,r10,lr
        LDR     lr, [sp, #12*4]
        ORR     lr, lr, #V_bit
        STR     lr, [sp, #12*4]
        EXIT

        LTORG

ChangeDynError

; in:   r0 -> error
;       r10 -> area that we tried to shrink/grow

        MOV     r1, #0
ChangeDynErrorSomeMoved
        STR     r0, [sp]
        LDR     lr, [sp, #10*4]
        ORR     lr, lr, #V_bit
        STR     lr, [sp, #10*4]
        B       SomeMemoryMoved

NoMemoryMoved
        MOV     r1, #0                          ; nothing moved
SomeMemoryMoved
        LDR     r0, [r10, #DANode_Number]       ; reload area number

; and drop thru to...

IssueServiceMemoryMoved

; in:   r0 = area number that was shrunk/grown
;       r1 = amount moved (signed)
;
  [ DA_Batman
        CMP     r0, #ChangeDyn_Batcall
        BEQ     ISMM_BatCloak           ; cloaking device (no service issue)
  ]
        Push    "r1"
        MOV     r2, r0                  ; r2 = area number
        MOV     r0, r1                  ; amount moved (signed)
        MOV     r1, #Service_MemoryMoved
        BL      Issue_Service
        Pull    "r1"                    ; restore amount moved
  [ DA_Batman
ISMM_BatCloak
  ]
        TEQ     r1, #0
        RSBMI   r1, r1, #0              ; r1 on exit = unsigned amount

        LDR     r0, =ZeroPage
      [ ZeroPage = 0
        STR     r0, [r0, #CDASemaphore] ; clear CDASemaphore
      |
        MOV     lr, #0
        STR     lr, [r0, #CDASemaphore] ; clear CDASemaphore
      ]
        Pull    "r0, r2-r9, r10, lr"
        ExitSWIHandler

CDA_PMP ROUT
        ; OS_ChangeDynamicArea implementation for PMPs
        ; Call through to the areas handler routine and let it do all the work
        LDR     r2, =ZeroPage
        MOV     r0, #0
        STR     r0, [r2, #CDASemaphore] ; Ensure handler can call back into us to modify the PMP
        ASSERT  DANode_Handler = DANode_Workspace + 4
        ADD     r12, r10, #DANode_Workspace
        Pull    "r2"
        ; Call with:
        ; r0 = reason
        ; r1 = change amount (pages)
        ; r2 = DA number
        LDR     r11, [r10, #DANode_PMPSize] ; Remember current size
        MOV     r0, #DAHandler_ResizePMP
        MOV     r1, r1, ASR #12
        MOV     lr, pc
        LDMIA   r12, {r12, pc}          ; Call handler
        ; Exit without issuing service call - PhysOp should have triggered it for us
        MOVVC   r0, r2                  ; r0 = DA number if no error
        MRS     r2, CPSR
        LDR     r10, [r10, #DANode_PMPSize]
        SUBS    r1, r10, r11
        RSBLT   r1, r1, #0              ; get unsigned change for OS_ChangeDynamicArea return
        CMP     r1, #DynArea_PMP_BigPageCount ; even though unsigned, use same +2GB clamp
        MOVLO   r1, r1, LSL #12
        LDRHS   r1, =DynArea_PMP_BigByteCount
        TST     r2, #V_bit
        BNE     %FT90
        Pull    "r2-r9,r10,lr"
        ExitSWIHandler
90
        ; If no error pointer, generate can't move error
        TEQ     r0, #0
        ADREQL  r0, ErrorBlock_ChDynamNotAllMoved
 [ International
        BLEQ    TranslateError
 ]
        Pull    "r2-r9,r10,lr"
        ORR     lr, lr, #V_bit
        ExitSWIHandler

; ***********************************************************************************
;
;       GrowFreePool - Try and grow the free pool so it's at least the given size
;
; in:   r1 = desired page count
;       r12 -> dst area node (we won't try and shrink this one)
;
; out:  C=0 => failed to move as much as we wanted
;       C=1 => succeeded in moving as much as we wanted
GrowFreePool ROUT
        Entry   "r0-r2,r11"
        ; Check to see if there's already enough space
        LDR     r11, =ZeroPage+FreePoolDANode
        LDR     r2, [r11, #DANode_PMPSize]
        SUBS    r0, r2, r1
        BHS     %FT90
 [ ShrinkableDAs
        ; Try and shrink shrinkables
        CLC
        BL      TryToShrinkShrinkables
        EXIT    CS
        SUB     r0, r2, r1              ; Update how many pages still needed
 ]
        ; Try shrinking application space, if r12 != appspace
        LDR     lr, [r12, #DANode_Number]
        CMP     lr, #ChangeDyn_AplSpace
        BEQ     %FT80
        LDR     r2, [r11, #CDASemaphore-FreePoolDANode]
        MOV     r0, #0
        STR     r0, [r11, #CDASemaphore-FreePoolDANode] ; Allow nested call
        CMN     r0, #DynArea_PMP_BigPageCount ; r0 is negative
        MOVGT   r1, r0, LSL #12
        LDRLE   r1, =-DynArea_PMP_BigByteCount
        MOV     r0, #ChangeDyn_AplSpace
        SWI     XOS_ChangeDynamicArea
        STR     r2, [r11, #CDASemaphore-FreePoolDANode] ; reclaim semaphore
        MOVVS   r1, #1
        CMP     r1, #0                  ; if all moved
        BEQ     %FT90                   ; then success
        ; Fall through...
80
        CLC
        EXIT

90
        SEC
        EXIT

 [ ShrinkableDAs
; ***********************************************************************************
;
;       TryToShrinkShrinkables - Attempt to make more space by shrinking shrinkable areas if appropriate
;
; in:   r1 = total amount we wish to have in src area (page count, already limited by max_size of destination area)
;       r2 = current size of src area (pages, must be less than r1)
;       r11 -> src area node (we don't do anything unless this is the free pool)
;       r12 -> dst area node (we won't try and shrink this one)
;       C = 0
;
; out:  r2 = new size of src area (pages)
;       C=0 => failed to move as much as we wanted
;       C=1 => succeeded in moving as much as we wanted

TryToShrinkShrinkables ROUT
        Entry   "r0,r1,r10"
        LDR     lr, [r11, #DANode_Number]
        TEQ     lr, #ChangeDyn_FreePool
        EXIT    NE                              ; if src <> free pool, exit with C, V flags intact

        LDR     r10, [r11, #DynArea_ws-FreePoolDANode]
        ADD     r10, r10, #:INDEX:DynArea_ShrinkableSubList-DANode_SubLink ; get shrinkable DA list
10
        LDR     r10, [r10, #DANode_SubLink]     ; and load next
        CMP     r10, #1                         ; any more nodes?
        EXIT    CC                              ; no, then no match
        TEQ     r10, r12                        ; check area <> dest
        BEQ     %BT10                           ; if not, try next area

        LDR     lr, [r10, #DANode_Flags]
        TST     lr, #DynAreaFlags_PMP
        SUB     lr, r1, r2                      ; lr = amount we still need
        LDREQ   r1, [r10, #DANode_Size]         ; available size of this area
        MOVEQ   r1, r1, LSR #12
        LDRNE   r1, [r10, #DANode_PMPSize]
        CMP     lr, r1
        MOVLO   r1, lr                          ; min(amount we need, size of this area)
        CMP     r1, #DynArea_PMP_BigPageCount
        MOVLO   r1, r1, LSL #12
        RSBLO   r1, r1, #0                      ; make negative - it's a shrink
        LDRHS   r1, =-DynArea_PMP_BigByteCount
        MOV     r0, #0
        LDR     r2, [r11, #CDASemaphore-FreePoolDANode] ; preserve old CDASemaphore (may not be set, e.g. when called from AMBControl)
        STR     r0, [r11, #CDASemaphore-FreePoolDANode] ; momentarily pretend we're not threaded
        LDR     r0, [r10, #DANode_Number]
        SWI     XOS_ChangeDynamicArea
        STR     r2, [r11, #CDASemaphore-FreePoolDANode] ; we're threaded again
        FRAMLDR r1                              ; reload original r1
        LDR     r2, [r11, #DANode_PMPSize]      ; get new size of src area
        CMP     r2, r1
        BCC     %BT10                           ; if still too small, loop
        EXIT                                    ; exit CS indicating success

TryToShrinkShrinkables_Bytes ROUT
        Entry
        MOV     r1, r1, LSR #12
        MOV     r2, r2, LSR #12
        BL      TryToShrinkShrinkables
        MOV     r1, r1, LSL #12
        MOV     r2, r2, LSL #12                 ; n.b. may overflow!
        EXIT
 ]

; ***********************************************************************************
;
;       DoTheGrow - Do one chunk of growing, small enough to fit into the page block on the stack
;
; in:   r2 = number of entries to put in page block (for this chunk)
;       r5 = page size
;       r7 = amount taking from src area (in this chunk)
;       (r10 -> dest area)
;       r11 -> src area (always free pool)
;       r12 -> dest area
;
; out:  r0-r2,r4,r6-r9 may be corrupted
;       r3,r5,r10-r12 preserved
;
; Note: Removal is from one area only, the calling routine breaks the chunks up at free/app boundary.

; Temporary (stack frame) workspace used by this routine

                ^       0, sp
NumEntries      #       4                       ; Number of entries to do for this chunk
TotalAmount     #       4                       ; Total size of grow for this chunk (ie entry value of r3)
DestAddr        #       4                       ; Log addr of 1st page being added to dest
DestFlags       #       4                       ; Page flags for destination area
SavedPSR        #       4                       ; PSR before IRQs disabled
Offset1To2      #       4                       ; Offset from 1st to 2nd bank
PageBlock1      #       PageBlockSize           ; 1st page block, for original page numbers and phys. addrs
PageBlock2      #       PageBlockSize           ; 2nd page block, for new page numbers and phys. addrs

DoTheGrowStackSize *    :INDEX: @

; Offset1To2 is only used by the first half of the routine. Reuse the space as flags for the second half:
                    ^   :INDEX: Offset1To2, sp
NeedToMoveFlag      #   1                       ; Whether we still need to move the current page
                    #   3                       ; (spare)

DoTheGrow ROUT
        Entry "r3,r5,r10-r12", DoTheGrowStackSize

; First fill in the page block with -1 in the physical page number words

        STR     r2, NumEntries                  ; save number of entries for use later
        STR     r7, TotalAmount                 ; save amount growing by

        FastCDA_ProfStart DoTheGrowInit, r0, r1, lr
        ADR     r1, PageBlock1                  ; point at 1st page block on stack
        ADD     lr, r2, r2, LSL #1              ; lr = number of words in page block
        ADD     lr, r1, lr, LSL #2              ; lr -> off end of page block
        MOV     r0, #-1
10
        STR     r0, [lr, #-12]!                 ; store -1, going backwards
        STR     r0, [lr, #PageBlockSize]        ; and put -1 in 2nd page block as well
        TEQ     lr, r1                          ; until the end
        BNE     %BT10
        FastCDA_ProfEnd DoTheGrowInit, r0, r3, lr

; Now call the pre-grow handler

        MOV     r3, r7
        BL      CallPreGrow
        EXIT    VS

; now check to see if particular pages are required

        LDR     lr, [r1]                        ; load page number in 1st entry
        CMP     lr, #-1                         ; is it -1?
        BNE     DoTheGrowPagesSpecified         ; if not, then jump to special code

        MOV     r2, r3                          ; amount moving
        ADR     r3, PageBlock1
        BL      DoTheGrowCommon                 ; Move all the pages around
        MOV     r3, r2                          ; r3 = size of change
        LDR     r2, NumEntries                  ; restore number of entries in page block
        ADR     r1, PageBlock1                  ; point at page block 1 with page numbers filled in
        BL      CallPostGrow
        CLRV
        EXIT

DoTheGrowPageUnavailable ROUT

; Come here if a required page is not available
; First we need to go back thru all the part of the page block we've already done,
; marking the pages as not being used after all

        ADR     r2, PageBlock1
38
        LDR     r4, [r1, #-12]!                 ; r4 = physical page number
        ADD     r4, r0, r4, LSL #CAM_EntrySizeLog2 ; point at cam entry
        ASSERT  CAM_PageFlags=4
        LDMIA   r4, {r8, lr}
        BIC     lr, lr, #PageFlags_Required
        STMIA   r4, {r8, lr}
        TEQ     r1, r2
        BNE     %BT38

; since pre-grow handler exited without an error, we have to keep our promise
; to call the post-grow handler

        MOV     r3, #0                          ; no pages moved
        MOV     r2, #0                          ; no pages moved
        ADR     r1, PageBlock1                  ; not really relevant
        BL      CallPostGrow

        ADR     r0, ErrorBlock_CantGetPhysMem
 [ International
        BL      TranslateError
 |
        SETV
 ]
        EXIT

        MakeErrorBlock  CantGetPhysMem

DoTheGrowPagesSpecified ROUT

; First check if any of the pages requested are unavailable
; At the same time as we're doing this, we fill in the log. and phys. addresses in the block

        FastCDA_ProfStart MarkRequired, r0, r6, lr
        LDR     r0, =ZeroPage
        LDR     r0, [r0, #CamEntriesPointer]
05
        LDR     r3, [r1], #12                   ; r4 = physical page number
        ADD     r4, r0, r3, LSL #CAM_EntrySizeLog2 ; point at cam entry
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        LDMIA   r4, {r8, lr}                    ; r8 = log. addr, lr = PPL
        STR     r8, [r1, #4-12]                 ; store log. addr in page block
        STR     r8, [r1, #PageBlockSize+4-12]   ; and in 2nd page block

        TST     lr, #PageFlags_Unavailable :OR: PageFlags_Required ; if page in use by someone else, or by us, then return error
        BNE     DoTheGrowPageUnavailable
        ORR     lr, lr, #PageFlags_Required     ; set bit in flags to say page will be needed
        STR     lr, [r4, #CAM_PageFlags]        ; and store back

; work out physical address direct from physical page number, NOT from logical address, since log addr may be Nowhere (multiply mapped, or PMP)

        LDR     r4, =ZeroPage+PhysRamTable
06
        LDMIA   r4!, {r8, lr}                   ; load phys addr, size
        SUBS    r3, r3, lr, LSR #12             ; subtract off number of pages in this chunk
        BCS     %BT06

        ADD     r3, r3, lr, LSR #12             ; put back what could not be subtracted
        ADD     r8, r8, r3, LSL #12             ; and add onto base address
        STR     r8, [r1, #8-12]                 ; store physical address in page block

        SUBS    r2, r2, #1
        BNE     %BT05
        FastCDA_ProfEnd MarkRequired, r0, r6, lr

; now issue Service_PagesUnsafe

        FastCDA_ProfStart PagesUnsafe, r0, r6, lr
        ADR     r2, PageBlock1                  ; r2 -> 1st page block
        LDR     r3, NumEntries                  ; r3 = number of entries in page block
        MOV     r1, #Service_PagesUnsafe
        BL      Issue_Service
        FastCDA_ProfEnd PagesUnsafe, r0, r6, lr

; now move the pages

        LDR     r2, TotalAmount                 ; amount moving
        LDR     r0, [r11, #DANode_PMP]
        LDR     r3, [r11, #DANode_PMPSize]
        ADD     r0, r0, r3, LSL #2              ; move r0 to point to after end of area
        SUB     r3, r3, r2, LSR #12             ; reduce by amount moving from area
        STR     r3, [r11, #DANode_PMPSize]      ; store reduced source size

        LDR     r1, [r12, #DANode_Base]
        LDR     r3, [r12, #DANode_Size]

        LDR     r6, [r12, #DANode_Flags]        ; r6 = dst flags
        ; If dest is a PMP, then this must be the batcall made by PhysOp, and
        ; we don't need to mask the flags.
        TST     r6, #DynAreaFlags_PMP
        LDREQ   lr, =DynAreaFlags_AccessMask
        ANDEQ   r6, r6, lr
        ORREQ   r6, r6, #PageFlags_Unavailable  ; set unavailable bit if regular DA. For PMPs, PMP has control over this.
        STR     r6, DestFlags                   ; save for later
        TST     r6, #DynAreaFlags_DoublyMapped  ; check if dst is doubly mapped
        BEQ     %FT15                           ; [it's not, so skip all this, and r9 will be irrelevant]

; we must shunt all existing pages in dest area down

        MOVS    r4, r3                          ; amount to do
        BLNE    ShuffleDoublyMappedRegionForGrow
        ADD     r9, r3, r2                      ; set up offset from 1st copy to 2nd copy (= new size)
15
        STR     r9, Offset1To2                  ; store offset 1st to 2nd copy
        ADD     r1, r1, r3                      ; r1 -> address of 1st extra page
        STR     r1, DestAddr
        ADR     r8, PageBlock1                  ; r8 -> position in 1st page block
        SUB     r2, r0, r2, LSR #12-2           ; r2 = lowest address being removed from src
        LDR     r3, =ZeroPage
        LDR     r3, [r3, #CamEntriesPointer]
        MOV     r4, r0                          ; r4 is where we're at in allocating spare logical addresses
        LDR     r9, NumEntries                  ; number of entries still to do in 1st loop

; Now before we start, we must construct the second page block, with replacement page numbers

;        DLINE   "Start of 1st loop"
        FastCDA_ProfStart FindSpare, r6, r1, lr

20
        LDR     r6, [r8], #12                   ; r6 = page number required
        LDR     r10, [r8, #8-12]                ; r10 = phys addr

        ; r0 = End of area being removed from src (DANode_PMP+DANode_PMPSize*4)
        ; r1 = Spare
        ; r2 = Start of area being removed from src (DANode_PMP+(DANode_PMPSize-NumEntries)*4)
        ; r3 = CAM
        ; r4 = Where to look next for a replacement page (counts down, == r0)
        ; r5 = PageSize
        ; r6 = Required page number
        ; r7 = Spare
        ; r8 = PageBlock1
        ; r9 = NumEntries
        ; r10 = Required page phys addr
        ; r11 = Src DANode
        ; r12 = Dest DANode

        ; If the required page is in a PMP, then it might not be mapped in and
        ; any logical address checks we perform will be nonsensical.
        ; Considering that the only possible source area is the free pool, the
        ; rules for required pages are:
        ; * If it's not a member of a PMP, we need to find a replacement page
        ; * If it's a different PMP to the src DA, we need to find a replacement page
        ; * If it's the same PMP as the src DA, then we can take the page without looking for a replacement
        ADD     lr, r3, r6, LSL #CAM_EntrySizeLog2
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        ASSERT  CAM_PMP=8
        ASSERT  CAM_PMPIndex=12
        LDMIB   lr, {r1, r7, lr}
        TST     r1, #DynAreaFlags_PMP
        BEQ     %FT63                           ; Not a PMP, look for a replacement
        TEQ     r7, r11
        BNE     %FT63                           ; Different PMP/DA, look for a replacement
        ; Page is being taken from src PMP, so assume src is free pool and so no replacement needed
        ; However we need to make sure we don't introduce any gaps in the free pool page list - so if this page isn't within the range of pages being removed, we need to look for a replacement still
        LDR     r1, [r7, #DANode_PMP]
        ADD     r1, r1, lr, LSL #2

;        DREG    r6, "Checking page ", cc
;        DREG    r1, "at address "

        CMP     r1, r2                          ; check if address is one being taken from src anyway
        BCC     %FT63
        CMP     r1, r0
        BCS     %FT63

;        DLINE   "Page is being taken away anyway"
        B       %FT68                           ; [page is being taken anyway, so use same page number + phys addr in 2nd block]

; page is not one being taken away, so put in 1st replacement page that isn't required by area

63
;        DLINE   "Page is not being taken, looking for replacement"

64
        LDR     r6, [r4, #-4]!                  ; get next page being taken from src
;        DREG    r6, "Considering page "

        ADD     r1, r3, r6, LSL #CAM_EntrySizeLog2 ; r1 -> cam entry for this page
        LDR     r1, [r1, #CAM_PageFlags]        ; get PPL for this page
        TST     r1, #PageFlags_Required         ; if this page is required for the operation
        BNE     %BT64                           ; then try next page

        Push    "r3,r5,r9"
        MOV     r3, r6
        BL      ppn_to_physical
        MOV     r10, r5
        Pull    "r3,r5,r9"

;        DREG    r6, "Using page number "
68
        STR     r6, [r8, #PageBlockSize-12]     ; store page number in 2nd block
        STR     r10, [r8, #PageBlockSize+8-12]  ; and store phys addr

        SUBS    r9, r9, #1                      ; one less entry to do
        BNE     %BT20
        FastCDA_ProfEnd FindSpare, r7, r1, lr

        MOV     r7, r3                          ; r7 -> camentries

; Now we can go onto the 2nd loop which actually moves the pages

     [ FastCDA_FIQs
        ; Claim FIQs for this entire loop
        ; (With the old behaviour, for large grows, total time in ReleaseFIQ could be several centiseconds, since the kernel reinstalls the default handler each time)
        FastCDA_ProfStart ClaimFIQ, r6, r1, lr
        MOV     r1, #Service_ClaimFIQ
        BL      Issue_Service
        FastCDA_ProfEnd ClaimFIQ, r6, r1, lr
     ]

        LDR     r1, DestAddr
        MOV     r4, #0                          ; amount done
        MOV     r0, r7                          ; point r0 at camentries
        LDR     r7, TotalAmount                 ; amount to do
        ADR     r8, PageBlock1
        LDR     r9, Offset1To2
70
        MRS     r14, CPSR
        STR     r14, SavedPSR                   ; save old PSR (note: stack must be flat when we do this!)

        ; Grab the flags for the page we're replacing; in order to preserve the contents of the page we may map it to its destination early, causing the flags in the CAM map to be "wrong" when we read them back out later on
        LDR     r11, [r8, #0]                   ; need to get PPL for page being replaced
        ADD     lr, r0, #CAM_PageFlags          ; point at PPLs, not addresses
        LDR     r11, [lr, r11, LSL #CAM_EntrySizeLog2]
        MOV     lr, #1
        STRB    lr, NeedToMoveFlag

        Push    "r0-r4,r7-r12"                  ; save regs used during copy
    [ :LNOT: FastCDA_FIQs
        FastCDA_ProfStart ClaimFIQ, r6, r1, lr
        MOV     r1, #Service_ClaimFIQ
        BL      Issue_Service
        FastCDA_ProfEnd ClaimFIQ, r6, r1, lr
    ]

        WritePSRc I_bit+SVC_mode, r6            ; disable IRQs round here (we don't want interrupt code to update
                                                ; the old mapping behind us while we're trying to copy it)

        LDR     lr, [r8, #PageBlockSize+0]      ; lr = page number of replacement page

        ; The replacement page will be a member of the free pool PMP - remove it
        ; from the PMP now, before any CAM updates make it hard to get access
        ; to the original page flags
        LDR     r11, =ZeroPage+FreePoolDANode
        ADD     r4, r0, lr, LSL #CAM_EntrySizeLog2
        LDR     r2, [r11, #DANode_PMP]
        LDR     r6, [r4, #CAM_PMPIndex]!
        MOV     r3, #-1
        STR     r3, [r2, r6, LSL #2]
        ; If the required page is a member of a PMP, update its PMP to point to
        ; the replacement page (and update the CAM for the replacement)
        LDR     r6, [r8, #0]
        TEQ     r6, lr
        BEQ     %FT72                           ; Required == replacement, leave unassociated
        ADD     r6, r0, r6, LSL #CAM_EntrySizeLog2
        ASSERT  CAM_PageFlags=4
        ASSERT  CAM_PMP=8
        ASSERT  CAM_PMPIndex=12
        LDMIB   r6, {r2, r3, r6}
        TST     r2, #DynAreaFlags_PMP
        BEQ     %FT72
        STMDA   r4, {r3, r6}                    ; Update CAM for replacement to point to PMP of required page
        LDR     r4, [r3, #DANode_PMP]
        STR     lr, [r4, r6, LSL #2]            ; And update PMP of required page to point to replacement
72

        LDR     r6, [r8, #0]                    ; r6 = page number required
        TEQ     r6, lr                          ; if the same
        Pull    "r0-r4,r7-r12", EQ              ; then restore registers
        BEQ     %FT86                           ; and skip copy and first page move

        ;mjs
        ; - if the old page is currently mapped in, copy normally
        ; - if the old page is not mapped in, copy via temporary mapping
        ; The old scheme, always copying from other mapping, had interrupt cache coherency hole, at least for
        ; ARM with writeback cache (bug in 3.7, fixed in Ursula, then lost)

        LDR     r6, [r8, #4]                    ;logical address of src page

        ; If the required page is in the free pool, we don't need to preserve its contents
        ; TODO - have 'volatile' page flag which can be used to indicate that pages can just be taken? (so will work with any PMP)
        TST     r2, #DynAreaFlags_PMP
        BEQ     %FT73
        CMP     r3, r11
        BEQ     %FT84
73

        LDR     r2, =Nowhere

        ; If the required page isn't mapped in, see if we can map it in at the
        ; target address so that we can copy the contents out. If this fails
        ; we'll fall back to using a temporary mapping via AccessPhysicalAddress
        TEQ     r6, r2
        BNE     %FT75                           ; Source is mapped in, everything is fine
        LDR     r3, [sp, #4]                    ; Get stacked r1 (DestAddr)
        LDR     r11, [sp, #11*4+:INDEX:DestFlags]
        TEQ     r3, r2
        BEQ     %FT75                           ; Dest is Nowhere - must use temp mapping
        LDR     r2, [r8, #0]
        FastCDA_ProfStart MoveNeeded, lr, r4, r7
        BL      Call_CAM_Mapping                ; move needed page to destination
        FastCDA_ProfEnd MoveNeeded, lr, r4, r7
        MOV     r6, r3                          ; r6 = logical address of src for copy
        MOV     lr, #0
        LDR     r2, =Nowhere
        STRB    lr, [sp, #11*4+:INDEX:NeedToMoveFlag] ; Flag that page has been moved
75

        MOV     lr, #-1
        Push    "lr"                            ; Push dummy oldp flag for ReleasePhysicalAddress

        ; With the only source of replacement pages being the free pool, we only have two situations to deal with:
        ; * Source mapped, dest unmapped
        ; * Source unmapped, dest unmapped
        ; (where 'source' = copy source, i.e. required page, and 'dest' = copy dest, i.e. replacement page)
        TEQ     r6, r2
        BEQ     ReplacePage_BothUnmapped
        ; Fall through to DestUnmapped

ReplacePage_DestUnmapped
        Push    "r1"
        FastCDA_ProfStart AccessPhysical, r2, r1, lr
        MOV     r0, #L1_B
        LDR     r1, [r8, #PageBlockSize+8]      ; r1 = physical address of dest for copy
        ADD     r2, sp, #4
        BL      RISCOS_AccessPhysicalAddress
        ; r0 = logical address of dest for copy
        FastCDA_ProfEnd AccessPhysical, r2, r1, lr
        Pull    "r1"
        B       ReplacePage_BothMapped

ReplacePage_BothUnmapped
        ; We need to make temp mappings of both pages, but we only have one
        ; PhysicalAccess window. For now, take the easy way out and copy via
        ; a temporary buffer - it'll be a bit slower but since we only move
        ; one page at a time the cache should swallow most of the hit.
        ; Since OS_ChangeDynamicArea can't be used from an IRQ routine, we can
        ; assume that the IRQ stack has enough spare space - so use that rather
        ; than the SVC stack
        Push    "r0,r1"
        FastCDA_ProfStart AccessPhysical, r0, r1, lr
        MOV     r0, #L1_B
        LDR     r1, [r8, #8]                    ; r1 = physical address of src for copy
        ADD     r2, sp, #8
        BL      RISCOS_AccessPhysicalAddress
        MOV     r6, r0                          ; r6 = logical address of src for copy
        FastCDA_ProfEnd AccessPhysical, r0, r1, lr

        ; Copy to IRQ stack
        MSR     CPSR_c, #IRQ32_mode+I32_bit
        Push    "lr"
        SUB     sp, sp, r5
        MOV     r0, sp
        FastCDA_ProfStart CopyPage, r2, r3, r4
        ADD     lr, r6, r5                      ; lr = end src address
77
        LDMIA   r6!, {r2, r3, r4, r7, r9, r10, r11, r12}
        STMIA   r0!, {r2, r3, r4, r7, r9, r10, r11, r12}
        TEQ     r6, lr
        BNE     %BT77
        FastCDA_ProfEnd CopyPage, r2, r3, r4

        ; Now map in dest
        MOV     r0, #L1_B
        LDR     r1, [r8, #PageBlockSize+8]      ; r1 = physical address of src for copy
        MOV     r2, #0                          ; no oldp needed
        BL      RISCOS_AccessPhysicalAddress
        ; r0 = logical address of dest for copy
        MOV     r6, sp
        FastCDA_ProfStart CopyPage, r2, r3, r4
        ADD     lr, r6, r5                      ; lr = end src address
78
        LDMIA   r6!, {r2, r3, r4, r7, r9, r10, r11, r12}
        STMIA   r0!, {r2, r3, r4, r7, r9, r10, r11, r12}
        TEQ     r6, lr
        BNE     %BT78
        FastCDA_ProfEnd CopyPage, r2, r3, r4
        ; Switch back to SVC and clean up the temp mapping
        ADD     sp, sp, r5
        Pull    "lr"
        MSR     CPSR_c, #SVC32_mode+I32_bit
        Pull    "r0,r1"
        B       ReplacePage_Done

 [ {FALSE}
ReplacePage_SrcUnmapped
        Push    "r0,r1"
        FastCDA_ProfStart AccessPhysical, r0, r1, lr
        MOV     r0, #L1_B
        LDR     r1, [r8, #8]                    ; r1 = physical address of src for copy
        ADD     r2, sp, #8
        BL      RISCOS_AccessPhysicalAddress
        MOV     r6, r0                          ; r6 = logical address of src for copy
        FastCDA_ProfEnd AccessPhysical, r0, r1, lr
        Pull    "r0,r1"
 ]

ReplacePage_BothMapped
        FastCDA_ProfStart CopyPage, r2, r3, r4
        ADD     lr, r6, r5                      ; lr = end src address
79
        LDMIA   r6!, {r2, r3, r4, r7, r9, r10, r11, r12}
        STMIA   r0!, {r2, r3, r4, r7, r9, r10, r11, r12}
        TEQ     r6, lr
        BNE     %BT79

        FastCDA_ProfEnd CopyPage, r2, r3, r4

ReplacePage_Done
        ; Release the temp mapping if necessary
        Pull    "r0"
        CMP     r0, #-1
      [ FastCDA_Prof
        BEQ     %FT80
        FastCDA_ProfStart ReleasePhysical, r2, r3, r4
      ]
        BLNE    RISCOS_ReleasePhysicalAddress
      [ FastCDA_Prof
        FastCDA_ProfEnd ReleasePhysical, r2, r3, r4
80
      ]

; now check if page we're replacing is in L2PT, and if so then adjust L1PT entries (4 of these)

        LDR     r2, =L2PT
        LDR     r6, [r8, #4]                    ; look at logical address of page being replaced
        SUBS    r6, r6, r2
        BCC     %FT84                           ; address is below L2PT
        CMP     r6, #4*1024*1024
        BCS     %FT84                           ; address is above L2PT

        LDR     r2, =L1PT
        ADD     r2, r2, r6, LSR #(12-4)         ; address in L1 of 4 consecutive words to update
        LDR     r3, [r2]                        ; load 1st word, to get AP etc bits
        MOV     r3, r3, LSL #(31-9)             ; junk other bits
        LDR     r4, [r8, #PageBlockSize+8]      ; load new physical address for page
        ORR     r3, r4, r3, LSR #(31-9)         ; and merge with AP etc bits
        STR     r3, [r2], #4
        ADD     r3, r3, #&400
        STR     r3, [r2], #4
        ADD     r3, r3, #&400
        STR     r3, [r2], #4
        ADD     r3, r3, #&400
        STR     r3, [r2], #4
      [ MEMM_Type = "VMSAv6"
        ; In order to guarantee that the result of a page table write is
        ; visible, the ARMv6+ memory order model requires us to perform TLB
        ; maintenance (equivalent to the MMU_ChangingUncached ARMop) after we've
        ; performed the write. Performing the maintenance beforehand (as we've
        ; done traditionally) will work most of the time, but not always.
        LDR     r3, =ZeroPage
        ARMop   MMU_ChangingUncached,,,r3
      ]

84
        Pull    "r0-r4,r7-r12"                  ; restore registers

        ; mjs
        ; OK, what we are about to do is:
        ;   1) move replacement page in (to replace needed page)
        ;   2) move needed page to required destination
        ; This order means that we don't leave a temporary hole at the logical address we're substituting,
        ; which is vital at least in the horrendous case where the logical page is itself used for L2PT.
        ; However, this means there is a potential temporary degeneracy in the caches, two physical pages
        ; having been seen at the same logical address (undefined behaviour).
        ; So, to be safe, we do a MMUChangingEntry first, for the logical page, which will clean/invalidate
        ; caches and invalidate TLBs, to avoid degeneracy. This is slight overkill in some cases, but vital
        ; to avoid serious grief in the awkward cases. Fortunately, these page substitutions are relatively
        ; rare, so performance is not critical.

        BIC     r11, r11, #PageFlags_Required   ; knock off bits that indicate that it was a required page

        ADD     lr, r8, #PageBlockSize
        LDMIA   lr, {r2, r3}                    ; get page number, logical address
        
        LDR     lr, =Nowhere                    ; No need to clean if the page isn't mapped in
        TEQ     r3, lr
        BEQ     %FT85
      [ FastCDA_Unnecessary
        ; We only need to clean the cache/TLB if the page is cacheable
        TST     r11, #DynAreaFlags_NotCacheable
        BNE     %FT85
      ]        
        Push    "r0-r2, r4, r11"
        LDR     r4, =ZeroPage
      [ FastCDA_Prof
        FastCDA_ProfStart ChangingEntry, r6, lr, r4
      ]
        ; Use BangCam to remove the cacheability on the needed page
        LDR     r2, [r8, #0] ; Get page number of needed page
        ORR     r11, r11, #1<<TempUncacheableShift ; Make temp uncache
        BL      Call_CAM_Mapping ; This will flush the TLB for us, but won't flush the cache
        ; So now we flush the cache manually
        MOV     r0, r3
        ADD     r1, r3, #4096
        ARMop   Cache_CleanInvalidateRange,,,r4
      [ FastCDA_Prof
        FastCDA_ProfEnd ChangingEntry, r6, lr, r4
      ]
        Pull    "r0-r2, r4, r11"
85

        FastCDA_ProfStart MoveReplacement, r6, lr, r5
        BL      Call_CAM_Mapping                ; move replacement page in
        FastCDA_ProfEnd MoveReplacement, r6, lr, r5
86
        LDR     r2, [r8, #0]
        MOV     r3, r1
        LDR     r11, DestFlags
        LDRB    lr, NeedToMoveFlag
        TEQ     lr, #0
        BEQ     %FT87                           ; don't bother if page already been moved to dest
        FastCDA_ProfStart MoveNeeded, r6, lr, r5
        BL      Call_CAM_Mapping                ; move needed page to destination
        FastCDA_ProfEnd MoveNeeded, r6, lr, r5

87
        LDR     lr, SavedPSR
        MSR     CPSR_cf, lr

      [ :LNOT: FastCDA_FIQs
        Push    "r1"
        FastCDA_ProfStart ReleaseFIQ, r1, lr, r5
        MOV     r1, #Service_ReleaseFIQ
        BL      Issue_Service
        FastCDA_ProfEnd ReleaseFIQ, r1, lr, r5
        Pull    "r1"
      ]
      [ FastCDA_Prof
        MOV     r5, #4096
      ]

        ADD     r1, r1, r5                      ; advance dest ptr
        ADD     r4, r4, r5                      ; increment amount done
        ADD     r8, r8, #12                     ; advance page block ptr
        CMP     r4, r7                          ; have we done all?
        BNE     %BT70                           ; [no, so loop]

     [ FastCDA_FIQs
        FastCDA_ProfStart ReleaseFIQ, r1, lr, r2
        MOV     r1, #Service_ReleaseFIQ
        BL      Issue_Service
        FastCDA_ProfEnd ReleaseFIQ, r1, lr, r2
     ]

        LDR     r3, [r12, #DANode_Size]
        ADD     r3, r3, r7
        STR     r3, [r12, #DANode_Size]         ; store increased destination size
      [ ZeroPage = 0
        TEQ     r12, #AppSpaceDANode            ; check if dest = appspace
      |
        LDR     lr, =ZeroPage+AppSpaceDANode
        TEQ     r12, lr                         ; check if dest = appspace
      ]
        STREQ   r3, [r12, #MemLimit-AppSpaceDANode] ; update memlimit if so

; now issue Service_PagesSafe

        FastCDA_ProfStart PagesSafe, r1, r2, r3
        LDR     r2, NumEntries
        ADR     r3, PageBlock1
        ADR     r4, PageBlock2
        MOV     r1, #Service_PagesSafe
        BL      Issue_Service
        FastCDA_ProfEnd PagesSafe, r1, r2, r3

; now call Post_Grow handler

        LDR     r3, TotalAmount                 ; size of grow
        LDR     r2, NumEntries                  ; restore number of entries in page block
        ADR     r1, PageBlock1                  ; point at page block 1 with page numbers filled in
        BL      CallPostGrow
        CLRV
        EXIT

        LTORG

; ***********************************************************************************
;
;       DoTheGrowNotSpecified - Do one chunk of growing, with no page block
;                               But don't call pre-grow or post-grow either
;
; in:   r2 = number of pages to do (in this chunk)
;       r5 = page size
;       r7 = amount taking from src area (in this chunk)
;       r11 -> src area
;       r12 -> dest area
;
; out:  r0-r2,r4,r6-r9 may be corrupted
;       r3,r5,r10-r12 preserved
;
; Note: Removal is from one area only, the calling routine breaks the chunk at free/app boundary.


DoTheGrowNotSpecified ROUT
        Entry   "r3"
        MOV     r3, #0                          ; no dest page list
        MOV     r2, r7                          ; amount moving
        BL      DoTheGrowCommon                 ; Move all the pages around
        CLRV
        EXIT

; ***********************************************************************************
;
;       CheckAppSpace - If appspace involved in transfer, issue Service or UpCall
;
;       Internal routine, called by OS_ChangeDynamicArea
;
; in:   r0 = area number passed in to ChangeDyn
;       r10 = size of change (signed)
;       r11 -> node for src
;       r12 -> node for dest
;
; out:  If appspace not involved, or application said it was OK, then
;         V=0
;         All registers preserved
;       else
;         V=1
;         r0 -> error
;         All other registers preserved
;       endif
;

CheckAppSpace ROUT
        Entry "r0-r3"
        LDR     r2, =ZeroPage
        LDR     r3, [r2, #AplWorkSize]
        LDR     r2, [r2, #Curr_Active_Object]
        CMP     r2, r3                          ; check if CAO outside application space
        BHI     %FT20                           ; [it is so issue Service not UpCall]

; CAO in application space, so issue UpCall to check it's OK

        MOV     r0, #UpCall_MovingMemory :AND: &FF
        ORR     r0, r0, #UpCall_MovingMemory :AND: &FFFFFF00
        MOVS    r1, r10
        RSBMI   r1, r1, #0                      ; r1 passed in is always +ve (probably a bug, but should be compat.)

        SWI     XOS_UpCall
        CMP     r0, #UpCall_Claimed             ; if upcall claimed
        EXIT    EQ                              ; then OK to move memory, so exit (V=0 from CMP)

05
        ADR     r0, ErrorBlock_ChDynamCAO
10
 [ International
        BL      TranslateError
 |
        SETV
 ]
        STR     r0, [sp]
        EXIT

; IF service call claimed Then Error AplWSpaceInUse

20
        MOV     r0, r10                         ; amount removing from aplspace
        MOV     r1, #Service_Memory
        BL      Issue_Service
        CMP     r1, #Service_Serviced
        ADREQ   r0, ErrorBlock_AplWSpaceInUse   ; if service claimed, then return error
        BEQ     %BT10
        CLRV                                    ; else OK
        EXIT

        MakeErrorBlock AplWSpaceInUse
        MakeErrorBlock ChDynamCAO

; ***********************************************************************************
;
;       CallPreShrink - Call pre-shrink routine
;
; in:   r1 = amount shrinking by (+ve)
;       r5 = page size
;       r11 -> node for area being shrunk
;
; out:  If handler exits VC, then r2 = no. of bytes area can shrink by
;       else r0 -> error block or 0 for generic error, and r2=0
;

CallPreShrink Entry "r0,r3,r4, r12"
        LDR     r0, [r11, #DANode_Handler]              ; check if no handler
        CMP     r0, #0                                  ; if none (V=0)
        EXIT    EQ                                      ; then exit

        MOV     r0, #DAHandler_PreShrink                ; r0 = reason code
        MOV     r3, r1                                  ; r3 = amount shrinking by
        LDR     r4, [r11, #DANode_Size]                 ; r4 = current size
        ASSERT  DANode_Handler = DANode_Workspace +4
        ADD     r12, r11, #DANode_Workspace
        MOV     lr, pc
        LDMIA   r12, {r12, pc}                          ; load workspace pointer and jump to handler

; shrink amount returned by handler may not be page multiple (according to spec),
; so we'd better make it so.

        SUB     lr, r5, #1
        BIC     r2, r3, lr                              ; make page multiple and move into r2
        EXIT    VC
        TEQ     r0, #0                                  ; if generic error returned
        ADREQL  r0, ErrorBlock_ChDynamNotAllMoved       ; then substitute real error message
 [ International
        BLEQ    TranslateError
 ]
        STR     r0, [sp]
        EXIT

; ***********************************************************************************
;
;       CallPostShrink - Call post-shrink routine
;
; in:   r2 = amount shrinking by (+ve)
;       r5 = page size
;       r11 -> node for area being shrunk
;
; out:  All registers preserved
;

CallPostShrink Entry "r0,r3,r4, r12"
        LDR     r0, [r11, #DANode_Handler]              ; check if no handler
        CMP     r0, #0                                  ; if none (V=0)
        EXIT    EQ                                      ; then exit

        MOV     r0, #DAHandler_PostShrink               ; r0 = reason code
        MOV     r3, r2                                  ; r3 = amount shrunk by
        LDR     r4, [r11, #DANode_Size]                 ; r4 = new size
        ASSERT  DANode_Handler = DANode_Workspace +4
        ADD     r12, r11, #DANode_Workspace
        MOV     lr, pc
        LDMIA   r12, {r12, pc}                          ; load workspace pointer and jump to handler

        EXIT

; ***********************************************************************************
;
;       CallPreGrow - Call pre-grow routine
;
; in:   Eventually r1 -> page block (on stack)
;                  r2 = number of entries in block
;       but for now these are both undefined
;       r3 = amount area is growing by
;       r5 = page size
;       r12 -> node for area being grown
;
; out:  If can't grow, then
;         r0 -> error
;         V=1
;       else
;         page block may be updated with page numbers (but not yet!)
;         All registers preserved
;         V=0
;       endif
;

CallPreGrow ROUT
        Entry   "r0,r4, r12"
        LDR     r0, [r12, #DANode_Flags]
        TST     r0, #DynAreaFlags_NeedsDMA              ; if DMA needed
        BNE     %FT10                                   ; use special PreGrow

        LDR     r0, [r12, #DANode_Handler]              ; check if no handler
        CMP     r0, #0                                  ; if none (V=0)
        EXIT    EQ                                      ; then exit

        FastCDA_ProfStart CallPreGrow, r0, r4, lr
        MOV     r0, #DAHandler_PreGrow                  ; r0 = reason code
        LDR     r4, [r12, #DANode_Size]                 ; r4 = current size
        ASSERT  DANode_Handler = DANode_Workspace +4
        ADD     r12, r12, #DANode_Workspace
        MOV     lr, pc
        LDMIA   r12, {r12, pc}                          ; load workspace pointer and jump to handler
        FastCDA_ProfEnd CallPreGrow, r12, r4, lr
        EXIT    VC                                      ; if no error then exit

05
        TEQ     r0, #0                                  ; if generic error returned (V still set)
        ADREQL  r0, ErrorBlock_ChDynamNotAllMoved       ; then substitute real error message
 [ International
        BLEQ    TranslateError
 ]
        STR     r0, [sp]
        EXIT

10
        ; Instead of calling the users PreGrow handler, walk PhysRamTable and
        ; the CAM map to look for some free DMAable pages
        ; Note that we don't guarantee physical contiguity - if you want that,
        ; just use OS_Memory 12 or PCI_RAMAlloc instead
        Push    "r1-r3"
        LDR     r0,=ZeroPage+PhysRamTable+4
        MOV     r2,#0                    ; current page number
        LDR     r4,=ZeroPage+CamEntriesPointer
        LDR     r4,[r4]
        ADD     r4,r4,#CAM_PageFlags     ; -> base of PPLs
        LDR     r12,[r0],#8              ; get video chunk flags
20
        ADD     r2,r2,r12,LSR #12        ; advance page number
21
        LDR     r12,[r0],#8              ; get next chunk details
        CMP     r12,#0
        BEQ     %FT90
        TST     r12,#OSAddRAM_NoDMA
        BNE     %BT20
        ; Check the CAM map to see if any pages here are free
        MOV     r12,r12,LSR #12
30
        LDR     lr,[r4,r2,LSL #CAM_EntrySizeLog2]
        TST     lr,#PageFlags_Unavailable :OR: PageFlags_Required
        STREQ   r2,[r1],#12
        SUBEQS  r3,r3,#4096
        BEQ     %FT80
        SUBS    r12,r12,#1
        ADD     r2,r2,#1
        BNE     %BT30
        B       %BT21
80
        ; Success
        CLRV
        Pull    "r1-r3"
        EXIT
90
        ; Failure
        SETV
        Pull    "r1-r3"
        MOV     r0,#0                
        B       %BT05


; ***********************************************************************************
;
;       CallPostGrow - Call post-grow routine
;
; in:   Eventually, r1 -> page block with actual pages put in
;                   r2 = number of entries in block
;       r3 = size of change
;       r5 = page size
;       r12 -> node for area being grown
;
; out:  All registers preserved
;

CallPostGrow Entry "r0,r3,r4, r12"
        LDR     r0, [r12, #DANode_Handler]              ; check if no handler
        CMP     r0, #0                                  ; if none (V=0)
        EXIT    EQ                                      ; then exit

        FastCDA_ProfStart CallPostGrow, r0, r4, lr
        MOV     r0, #DAHandler_PostGrow                 ; r0 = reason code
        LDR     r4, [r12, #DANode_Size]                 ; r4 = new size
        ASSERT  DANode_Handler = DANode_Workspace +4
        ADD     r12, r12, #DANode_Workspace
        MOV     lr, pc
        LDMIA   r12, {r12, pc}                          ; load workspace pointer and jump to handler
        FastCDA_ProfEnd CallPostGrow, r12, r4, lr
        EXIT

 [ ShrinkableDAs
; ***********************************************************************************
;
;       CallTestShrink - Call test-shrink routine
;
; in:   r11 -> area node
;
; out:  If handler exits VC, then r3 = no. of bytes area can shrink by
;       else r0 -> error block or 0 for generic error, and r3=0
;

CallTestShrink Entry "r0,r4,r5, r12"
        LDR     r0, [r11, #DANode_Handler]              ; check if no handler
        CMP     r0, #0                                  ; if none (V=0)
        EXIT    EQ                                      ; then exit

        MOV     r0, #DAHandler_TestShrink               ; r0 = reason code
        LDR     r4, [r11, #DANode_Size]                 ; r4 = current size
        LDR     r5, =ZeroPage
        LDR     r5, [r5, #Page_Size]                    ; set r5 = page size
        ASSERT  DANode_Handler = DANode_Workspace +4
        ADD     r12, r11, #DANode_Workspace
        MOV     lr, pc
        LDMIA   r12, {r12, pc}                          ; load workspace pointer and jump to handler

; shrink amount returned by handler may not be page multiple (according to spec),
; so we'd better make it so.

        SUBVC   lr, r5, #1
        BICVC   r3, r3, lr                              ; make page multiple
        EXIT    VC
        TEQ     r0, #0                                  ; if generic error returned (V still set)
        ADREQL  r0, ErrorBlock_ChDynamNotAllMoved       ; then substitute real error message
 [ International
        BLEQ    TranslateError
 ]
        STR     r0, [sp]
        MOV     r3, #0                                  ; indicate no shrink possible
        SETV
        EXIT
 ]

; ***********************************************************************************
;
;       DynAreaHandler_SysHeap - Dynamic area handler for system heap
;       DynAreaHandler_RMA     - Dynamic area handler for RMA
;
; in:   r0 = reason code (0=>pre-grow, 1=>post-grow, 2=>pre-shrink, 3=>post-shrink)
;       r12 -> base of area
;

DynAreaHandler_SysHeap
DynAreaHandler_RMA ROUT
        CMP     r0, #4
        ADDCC   pc, pc, r0, LSL #2
        B       UnknownHandlerError
        B       PreGrow_Heap
        B       PostGrow_Heap
        B       PreShrink_Heap
        B       PostShrink_Heap

PostGrow_Heap
PostShrink_Heap
        STR     r4, [r12, #:INDEX:hpdend] ; store new size

; and drop thru to...

PreGrow_Heap
        CLRV                            ; don't need to do anything here
        MOV     pc, lr                  ; so just exit

PreShrink_Heap
        Push    "r0, lr"
        PHPSEI                          ; disable IRQs round this bit
        LDR     r0, [r12, #:INDEX:hpdbase]      ; get minimum size
        SUB     r0, r4, r0              ; r0 = current-minimum = max shrink
        CMP     r3, r0                  ; if requested shrink > max
        MOVHI   r3, r0                  ; then limit it
        SUB     r0, r5, #1              ; r0 = page mask
        BIC     r3, r3, r0              ; round size change down to page multiple
        SUB     r0, r4, r3              ; area size after shrink
        STR     r0, [r12, #:INDEX:hpdend] ; update size

        PLP                             ; restore IRQ status
        CLRV
        Pull    "r0, pc"

AreaName_RMA
        =       "Module area", 0
        ALIGN


UnknownHandlerError
        Push    "lr"
        ADRL    r0, ErrorBlock_UnknownAreaHandler
  [ International
        BL      TranslateError
  |
        SETV
  ]
        Pull    "pc"

DynAreaHandler_Sprites
        CMP     r0, #4
        ADDCC   pc, pc, r0, LSL #2
        B       UnknownHandlerError
        B       PreGrow_Sprite
        B       PostGrow_Sprite
        B       PreShrink_Sprite
        B       PostShrink_Sprite

PostGrow_Sprite
PostShrink_Sprite Entry "r0"

; in - r3 = size change (+ve), r4 = new size, r5 = page size

        LDR     lr, =ZeroPage+VduDriverWorkSpace
        TEQ     r4, #0                  ; if new size = 0
        STREQ   r4, [lr, #SpAreaStart]  ; then set area ptr to zero
        STRNE   r12, [lr, #SpAreaStart] ; else store base address

        LDR     r0, =ZeroPage
        LDR     lr, [r0, #SpriteSize]   ; load old size
        STR     r4, [r0, #SpriteSize]   ; and store new size
        BEQ     %FT10                   ; if new size is zero, don't try to update header

        STR     r4, [r12, #saEnd]       ; store new size in header
        TEQ     lr, #0                  ; if old size was zero
        STREQ   lr, [r12, #saNumber]    ; then initialise header (no. of sprites = 0)
        MOVEQ   lr, #saExten
        STREQ   lr, [r12, #saFirst]     ; ptr to first sprite -> after header
        STREQ   lr, [r12, #saFree]      ; ptr to first free byte -> after header

10
        CLRV                            ; don't need to do anything here
        EXIT                            ; so just exit

PreGrow_Sprite
        CLRV                            ; don't need to do anything here
        MOV     pc, lr                  ; so just exit

PreShrink_Sprite Entry "r0"
        TEQ     r4, #0                  ; if current size is zero
        BEQ     %FT10                   ; then any shrink is OK (shouldn't happen)

        LDR     r0, [r12, #saFree]      ; get used amount
        TEQ     r0, #saExten            ; if only header used,
        MOVEQ   r0, #0                  ; then none really in use

        SUB     r0, r4, r0              ; r0 = current-minimum = max shrink
        CMP     r3, r0                  ; if requested shrink > max
        MOVHI   r3, r0                  ; then limit it
        SUB     r0, r5, #1              ; r0 = page mask
        BIC     r3, r3, r0              ; round size change down to page multiple
10
        CLRV
        EXIT

AreaName_SpriteArea
        =       "System sprites", 0
        ALIGN


DynAreaHandler_RAMDisc ROUT
 [ PMPRAMFS
        CMP     r0, #DAHandler_ResizePMP
        BNE     UnknownHandlerError
        ; r1 = change amount (pages)
        ; r2 = DA number
        Entry   "r2-r11"
        MOV     r10, r1
        MOV     r11, r2
        ; Get current size
        MOV     r0, #DAReason_PMP_GetInfo
        MOV     r1, r2
        SWI     XOS_DynamicArea
        ; R6 = current phys page count
        ; R7 = max size
        ; Check if resizing is allowed
        BLVC    PreGrow_RAMDisc
        EXIT    VS
        CMP     r10, #0
        BLT     RAMDisc_Shrink
        EXIT    EQ
        ; Claim empty space
        MOV     r0, #DAReason_PMP_Resize
      [ {TRUE}
        ; Limit max size to ~512MB - RAMFS currently can't cope with more than that
        RSB     r2, r6, #508<<(20-12)
        CMP     r10, r2
        MOVGT   r10, r2
      ]
        SUB     r2, r6, r7 ; Take into account any mismatch between current max and current page count
        ADDS    r2, r2, r10
        MOV     r9, r2
        SWINE   XOS_DynamicArea
        EXIT    VS
        ; R2 = actual change, use that from now on
        CMP     r9, #0
        ADDGE   r10, r7, r2 ; New PMPMaxSize
        SUBLT   r10, r7, r2 ; Take into account the fact the result is unsigned
        SUB     r10, r10, r6 ; Amount we need to change PMPSize
        ; Claim pages
        MOV     r7, #-2
        MOV     r9, #0
10
        SUBS    r10, r10, #1
        BLT     RAMDisc_PostOp
        Push    "r6,r7,r9"
        MOV     r0, #DAReason_PMP_PhysOp
        MOV     r2, sp
        MOV     r3, #1
        SWI     XOS_DynamicArea
        ADD     sp, sp, #12
        ADDVC   r6, r6, #1
        BVC     %BT10
        B       RAMDisc_PostOp
RAMDisc_Shrink
        ; Unmap all pages (RAMFS will unmap everything on reinit anyway)
        MOV     r0, #0
        MOV     r2, #-1
        MOV     r4, #0
        Push    "r0,r2,r4"
        MOV     r0, #DAReason_PMP_LogOp
15
        MOV     r2, sp
        MOV     r3, #1
        SWI     XOS_DynamicArea
        BVS     %FT16
        ADD     r4, r4, #1
        CMP     r4, #PMPRAMFS_Size
        STRLT   r4, [sp]
        BLT     %BT15
16
        ADD     sp, sp, #12
        ; Release pages
        MOV     r7, #-1
        MOV     r9, #0
        RSB     r10, r10, #0
20              
        SUBS    r10, r10, #1
        SUBGES  r6, r6, #1
        BLT     RAMDisc_PostShrink
        Push    "r6,r7,r9"
        MOV     r0, #DAReason_PMP_PhysOp
        MOV     r2, sp
        MOV     r3, #1
        SWI     XOS_DynamicArea
        ADD     sp, sp, #12
        BVC     %BT20
RAMDisc_PostShrink
        ; Release empty space so that things should stay in sync
        MRS     r2, CPSR
        Push    "r0,r2"
        MOV     r0, #DAReason_PMP_GetInfo
        SWI     XOS_DynamicArea
        BVS     %FT30
        SUBS    r2, r6, r7 ; Release all spare page entries
        MOV     r0, #DAReason_PMP_Resize
        SWINE   XOS_DynamicArea
30             
        Pull    "r0,r2"
        MSR     CPSR_f, r2
RAMDisc_PostOp
        ; Re-init if necessary
        MRS     r2, CPSR
        BL      PostGrow_RAMDisc
        MSR     CPSR_f, r2
        EXIT
        
 | ; PMPRAMFS
        CMP     r0, #4
        ADDCC   pc, pc, r0, LSL #2
        B       UnknownHandlerError
        B       PreGrow_RAMDisc
        B       PostGrow_RAMDisc
        B       PreShrink_RAMDisc
        B       PostShrink_RAMDisc
 ] ; PMPRAMFS

PostGrow_RAMDisc
PostShrink_RAMDisc Entry "r0-r6"

; in - r3 = size change (+ve), r4 = new size, r5 = page size
; but we don't really care about any of these

; The only thing we have to do here is ReInit RAMFS, but NOT if
; a) no modules are initialised yet (eg when we're created), or
; b) RAMFS has been unplugged

        LDR     r0, =ZeroPage
        LDR     r0, [r0, #Module_List]
        TEQ     r0, #0                  ; any modules yet?
        BEQ     %FT90                   ; no, then don't do anything

        MOV     r0, #ModHandReason_EnumerateROM_Modules
        MOV     r1, #0
        MOV     r2, #-1                 ; enumerate ROM modules looking for RAMFS
10
        SWI     XOS_Module
        BVS     %FT50                   ; no more modules, so it can't be unplugged
        ADR     r5, ramfsname
20
        LDRB    r6, [r3], #1            ; get char from returned module name
        CMP     r6, #" "                ; if a terminator then we have a match
        BLS     %FT30                   ; so check for unplugged
        LowerCase r6, lr                ; else force char to lower case
        LDRB    lr, [r5], #1            ; get char from "ramfs" string
        CMP     lr, r6                  ; and if matches
        BEQ     %BT20                   ; then try next char
        B       %BT10                   ; else try next module

30
        CMP     r4, #-1                 ; is module unplugged?
        BEQ     %FT90                   ; if so, then mustn't reinit it
50
        MOV     r0, #ModHandReason_ReInit ; reinit module
        ADR     r1, ramfsname
        SWI     XOS_Module              ; ignore any errors from this
90
        CLRV
        EXIT

PreGrow_RAMDisc
PreShrink_RAMDisc Entry "r0-r5"
        LDR     r0, =ZeroPage
        LDR     r0, [r0, #Module_List]  ; first check if any modules going
        TEQ     r0, #0
        BEQ     %FT90                   ; if not, don't look at filing system

        MOV     r0, #5
        ADR     r1, ramcolondollardotstar
        SWI     XOS_File
        CMPVC   r0, #0
        BVS     %FT90                   ; if no RAMFS then change OK
        BEQ     %FT90                   ; or if no files, then change OK
        ADR     r0, ErrorBlock_RAMFsUnchangeable
 [ International
        BL      TranslateError
 |
        SETV
 ]
        STR     r0, [sp]
        EXIT

90
        CLRV
        EXIT

        MakeErrorBlock  RAMFsUnchangeable

AreaName_RAMDisc
        =       "RAM disc", 0
ramcolondollardotstar
        =       "ram:$.*", 0
ramfsname
        =       "ramfs", 0
        ALIGN


DynAreaHandler_FontArea
        CMP     r0, #4
        ADDCC   pc, pc, r0, LSL #2
        B       UnknownHandlerError
        B       PreGrow_FontArea
        B       PostGrow_FontArea
        B       PreShrink_FontArea
        B       PostShrink_FontArea

PostGrow_FontArea Entry "r0-r2"

; in - r3 = size change (+ve), r4 = new size, r5 = page size

        LDR     r1, =ZeroPage
        LDR     r1, [r1, #Module_List]  ; any modules active?
        TEQ     r1, #0
        MOVNE   r1, r4                  ; there are, so inform font manager of size change
        SWINE   XFont_ChangeArea
        CLRV
        EXIT

PostShrink_FontArea
PreGrow_FontArea
        CLRV                            ; don't need to do anything here
        MOV     pc, lr                  ; so just exit

PreShrink_FontArea Entry "r0-r2"
        MOV     r1, #-1                 ; ask font manager for minimum size of font area
        MOV     r2, #0                  ; default value if no font manager
        SWI     XFont_ChangeArea        ; out: r2 = minimum size

        SUB     r0, r4, r2              ; r0 = current-minimum = max shrink
        CMP     r3, r0                  ; if requested shrink > max
        MOVHI   r3, r0                  ; then limit it
        SUB     r0, r5, #1              ; r0 = page mask
        BIC     r3, r3, r0              ; round size change down to page multiple

        SUB     r1, r4, r3              ; r1 = new size
        SWI     XFont_ChangeArea        ; tell font manager to reduce usage

        CLRV
        EXIT

AreaName_FontArea
        =       "Font cache", 0
        ALIGN


; **** New screen stuff ****
;
;
; This source collects together all the new routines needed to make
; the screen into a new dynamic area.
;
; It has the following dependencies elsewhere in the kernel before
; it can be expected to work:
;
; * Definition of AP_Screen in ChangeDyn needs doubly_mapped and
;   name_is_token bits set
; * name_is_token handling needs adding (or scrap the bit designation)
; * Call to CreateNewScreenArea from NewReset to create area
; * Tim says doubly-mapped areas are broken - this must be fixed first
; * Old CDA routine may be retired, since screen is its last client
; * Has Tim completed the rest of this work?
;
; Once these routines work, they should be grafted into appropriate
; places in the kernel sources
;
; This source is not intended for stand-alone assembly: it should be
; plumbed into the kernel source build
;
; Version history - remove this once integrated with kernel sources
;
; Vsn  Date      Who  What
; ---  --------  ---  ----------------------------------------------
; 000  23/08/93  amg  Written
; 001  24/08/93  amg  Fixes and changes following review by TMD
; 002  03/09/93  tmd  Updated to work!

; *********************************************************************
; Create a new style dynamic area for the screen
; *********************************************************************

; Entry requirements
; none

AreaName_Screen
        =       "Screen memory",0               ;needs replacing with message token
        ALIGN

; *********************************************************************
; Handler despatch routine for screen dynamic area
; *********************************************************************

DynAreaHandler_Screen                           ;despatch routine for pre/post grow/shrink handlers
        CMP     r0, #4
        ADDCC   pc, pc, R0, LSL #2
        B       UnknownHandlerError             ;already defined in ChangeDyn
        B       PreGrow_Screen                  ;the rest are defined here
        B       PostGrow_Screen
        B       PreShrink_Screen
        B       PostShrink_Screen

;The sequence of events which these handlers must do is:
;
;Grow Screen
;
;Pre : Remove cursors
;      Work out which physical page numbers are needed and return a list
;CDA : Move existing pages lower in memory within first copy (ie change logical address
;        associated with physical pages)
;      Locate and free the next physical pages in line (if used a page swap must occur)
;      Assign the new pages logical addresses in the gap between the end of the present
;        logical range and the start of the second physical range
;Post: Adjust screen memory contents & screen start addresses to retain screen display
;
;Shrink Screen
;
;Pre : Remove cursors
;      Adjust screen memory contents & screen start addresses to retain screen display
;CDA : Move pages from screen to free pool (creates a gap in first logical range)
;      Close up the gap in logical addressing
;Post: Restore cursors
;

; ***********************************************************************************
; Handlers for the screen dynamic area
; ***********************************************************************************

;Pregrow entry parameters
; R0 = 0 (reason code)
; R1 -> page block (entries set to -1)
; R2 = number of entries in page block == number of pages area is growing by
; R3 = number of bytes area is growing by (r2 * pagesize)
; R4 = current size (bytes)
; R5 = page size
;
; exit with V clear, all preserved

PreGrow_Screen  Entry   "r0-r2,r4"
        LDR     r0, [WsPtr, #CursorFlags]       ; test if VDU inited yet
        LDRB    lr, [WsPtr, #ExternalFramestore]
        TEQ     r0, #0                          ; if not, CursorFlags will be zero
        BEQ     %FT05
        TEQ     lr, #0
        SWIEQ   XOS_RemoveCursors               ; if VDU inited, then remove cursors

05      ADRL    r0, PageShifts-1
        LDRB    r0, [r0, r5, LSR #12]           ; grab log2Pagesize for shifting
        MOV     r4, r4, LSR r0                  ; change present size into number of pages
                                                ; since page numbers are 0 to n-1 thus n
                                                ; is the first page number we want to insist on
10
        STR     r4, [r1], #12                   ; store physical page number and increment to next
        SUBS    r2, r2, #1                      ; one less to do
        ADDNE   r4, r4, #1                      ; next physical page number
        BNE     %BT10                           ; continue until all pages done
        CLRV                                    ; ok, so I'm paranoid...
        EXIT

; **********************************************************************

;PostGrow entry parameters
;R0 = 1 (reason code)
;R1 -> page block (only physical page numbers are meaningful)
;R2 = number of entries in page block (= number of pages area grew by)
;R3 = number of bytes area grew by
;R4 = new size of area (bytes)
;R5 = page size

PostGrow_Screen Entry   "r0,r5"
        LDR     r0, [WsPtr, #CursorFlags]       ; test if VDU inited (CursorFlags=0 => not)
        TEQ     r0, #0
        BEQ     %FT90                           ; if not inited, do nothing

        PHPSEI  r5                              ; disable IRQs

        MOV     r0, r3                          ; move number of bytes area grew by into r0
        BL      InsertPages                     ; only call InsertPages if VDU inited

        PLP     r5                              ; restore IRQ state
        SWI     XOS_RestoreCursors              ; and restore cursors
90
        CLRV
        EXIT

; ***********************************************************************

;PreShrink Entry parameters
;R0 = 2 (reason code)
;R3 = number of bytes area is shrinking by
;R4 = current size of area (bytes)
;R5 = page size
;R12 = vdu workspace

PreShrink_Screen Entry   "R0-R2,R4-R5"

        ;need to check whether the proposed shrink still leaves enough for
        ;the current amount needed by the vdu drivers, if it doesn't we
        ;reduce R3 to be the most we can spare (in whole pages)

        LDR     LR, =ZeroPage
        LDR     LR, [LR, #VideoSizeFlags]          ;is VRAM suitable for general use?
        TST     LR, #OSAddRAM_VRAMNotForGeneralUse ;if not - don't shrink screen memory
        MOVNE   R3, #0
        SUB     R2, R5, #1                      ;make a page mask

        LDRB    R14, [R12, #ExternalFramestore]
        TEQ     R14, #0                         ;okay to shrink if using external framestore
        BEQ     %FT12
        RSB     R0, R3, #0                      ;R0= -(number of bytes) for RemovePages
        BL      RemovePages
        CLRV
        EXIT

12      LDR     R5, [R12, #ScreenSize]          ;get current minimum size

        SUB     R1, R4, R5                      ;R1 = maximum shrink (current - screensize)
        CMP     R3, R1                          ;if requested shrink > max...
        MOVHI   R3, R1                          ;...then limit it, and...
        BICS    R3, R3, R2                      ;...round down to multiple of page size
        BEQ     %FT10                           ;don't shuffle screen data if resultant
                                                ;shrink is 0 bytes/0 pages
        SWI     XOS_RemoveCursors
        PHPSEI  R5                              ;disable interrupts
        RSB     R0, R3, #0                      ;R0= -(number of bytes) for RemovePages
        BL      RemovePages                     ;entry: R0 = -(number of bytes)
        PLP     R5                              ;restore interrupts
10
        CLRV
        EXIT

; ************************************************************************

;PostShrink Entry parameters
;R0 = 3 (reason code)
;R3 = number of bytes area shrank by
;R4 = new size of area (bytes)
;R5 = page size

PostShrink_Screen Entry
        SWI     XOS_RestoreCursors
        CLRV                                    ;ok, so I'm paranoid...
        EXIT

; ************************************************************************

        LTORG

      [ PMPParanoid
ValidatePMPs ROUT
        EntryS  "r0-r12"
        ; Validate PMPs against the CAM
        LDR     r0, =ZeroPage
        LDR     r1, [r0, #DAList]
        LDR     r2, [r0, #CamEntriesPointer]
        LDR     r3, [r0, #MaxCamEntry]
        MOV     lr, #0
10
        LDR     r4, [r1, #DANode_Flags]
        TST     r4, #DynAreaFlags_PMP
        BEQ     %FT25
        LDR     r5, [r1, #DANode_PMP]
        LDR     r6, [r1, #DANode_PMPSize]
        LDR     r7, [r1, #DANode_PMPMaxSize]
        LDR     r0, [r1, #DANode_Size]
        CMP     r6, r7
        BLHI    %FT90
15
        SUBS    r7, r7, #1
        BLO     %FT20
        LDR     r8, [r5, r7, LSL #2]
        CMP     r8, #-1
        BEQ     %BT15
        CMP     r8, r3
        BLHI    %FT90
        ADD     r9, r2, r8, LSL #CAM_EntrySizeLog2
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        ASSERT  CAM_PMP=8
        ASSERT  CAM_PMPIndex=12
        LDMIA   r9, {r9-r12}
        TST     r10, #DynAreaFlags_PMP
        BLEQ    %FT90
        CMP     r11, r1
        CMPEQ   r12, r7
        BLNE    %FT90
        SUBS    r6, r6, #1
        BLLO    %FT90
        LDR     r10, =Nowhere
        CMP     r9, r10
        SUBNE   r0, r0, #4096
        B       %BT15
20
        CMP     r6, #0
        CMPEQ   r0, #0
        BLNE    %FT90
25
        CMP     lr, #0
        BNE     %FT26
        ; Iterate through regular DAs
        LDR     r1, [r1, #DANode_Link]
        CMP     r1, #0
        BNE     %BT10
        ; Iterate through AMBControl nodes
        LDR     r12, =ZeroPage+AMBControl_ws
        LDR     r12, [r12]
        CMP     r12, #0
        BEQ     %FT29
        ADR     lr, AMBAnchorNode
        ADD     r1, lr, #AMBNode_DANode
26
        LDR     r1, [r1, #AMBNode_next-AMBNode_DANode]
        CMP     r1, lr
        ADDNE   r1, r1, #AMBNode_DANode
        BNE     %BT10
29
        ; Validate CAM against PMPs
        MOV     r0, #0
30
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        ASSERT  CAM_PMP=8
        ASSERT  CAM_PMPIndex=12
        LDMIA   r2!, {r4-r7}
        TST     r5, #DynAreaFlags_PMP
        BEQ     %FT35
        LDR     r8, [r6, #DANode_Flags]
        TST     r8, #DynAreaFlags_PMP
        BLEQ    %FT90
        LDR     r8, [r6, #DANode_PMP]
        LDR     r9, [r6, #DANode_PMPMaxSize]
        LDR     r10, [r6, #DANode_PMPSize]
        CMP     r7, r9
        BLHS    %FT90
        LDR     r8, [r8, r7, LSL #2]
        CMP     r0, r8
        BLNE    %FT90
35
        ADD     r0, r0, #1
        CMP     r0, r3
        BLS     %BT30
        EXITS

90
        Push    "lr"
        DebugTX "PMP corrupt"
        DebugReg r0
        DebugReg r1
        DebugReg r2
        DebugReg r3
        DebugReg r4
        DebugReg r5
        DebugReg r6
        DebugReg r7
        DebugReg r8
        DebugReg r9
        DebugReg r10
        DebugReg r11
        DebugReg r12
        Pull     "r0"
        DebugReg r0
        B        .
      ] ; PMPParanoid

        END
