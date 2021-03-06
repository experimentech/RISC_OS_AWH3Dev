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

; in:   r0 = logical address where page is now

GetPageFlagsForR0IntoR6 Entry "R0-R2, R4-R5, R7"
;
; code from MoveCAMatR0toR3
;
        LDR     r5, =L2PT
        ADD     r4, r5, r0, LSR #10             ; r4 -> L2PT for log addr r0
        MOV     r2, r4, LSR #12
        LDR     r2, [r5, r2, LSL #2]            ; r2 = L2PT entry for r4
        TST     r2, #3                          ; if no page there
        BEQ     %FT90                           ; then cam corrupt

        LDR     r4, [r4]                        ; r4 = L2PT entry for r0
        TST     r4, #3                          ; check entry is valid too
        BEQ     %FT91
        MOV     r4, r4, LSR #12                 ; r4 = phys addr >> 12

        LDR     r2, =ZeroPage
        LDR     r6, [r2, #MaxCamEntry]
        ADD     r5, r2, #PhysRamTable
      [ ZeroPage <> 0
        MOV     r2, #0
      ]
10
        CMP     r2, r6                          ; if page we've got to is > max
        BHI     %FT92                           ; then corrupt
        LDMIA   r5!, {r7, lr}                   ; get phys.addr, size
        SUB     r7, r4, r7, LSR #12             ; number of pages into this bank
        CMP     r7, lr, LSR #12                 ; if too many
        ADDCS   r2, r2, lr, LSR #12             ; then advance physical page no.
        BCS     %BT10                           ; and loop

        ADD     r2, r2, r7                      ; add on number of pages within bank
;
; code from BangCamUpdate
;
        LDR     r1, =ZeroPage
        LDR     r1, [r1, #CamEntriesPointer]
        ADD     r1, r1, r2, LSL #CAM_EntrySizeLog2 ; point at cam entry (logaddr, PPL)
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        LDMIA   r1, {r0, r6}                    ; r0 = current logaddress, r6 = current PPL
        EXIT

90
        ADR     lr, NoL2ForPageBeingRemovedError ; NB don't corrupt r0 yet - we need that in block as evidence
95
        STR     lr, [sp]                        ; update returned r0
        BL      StoreDebugRegs
        PullEnv                                 ; seriously broken memory
        SETV
        MOV     pc, lr

91
        ADR     lr, PageBeingRemovedNotPresentError
        B       %BT95

92
        ADR     lr, PhysicalAddressNotFoundError
        B       %BT95

; ***********************************************************************************
;
;       MovePageAtR0ToR1WithAccessR6
;
;       Internal routine, called by OS_ChangeDynamicArea
;
; in:   r0 = logical address where page is now
;       r1 = logical address it should be moved to
;       r6 = area flags (which contain access privileges, and cacheable/bufferable bits)
;
; out:  All registers preserved
;

MovePageAtR0ToR1WithAccessR6 Entry "r2-r5,r11"
        MOV     r3, r1
        MOV     r11, r6
        BL      MoveCAMatR0toR3         ; use old internal routine for now
        EXIT

; Same as above, but returns with r2 = page number of page that moved

MovePageAtR0ToR1WithAccessR6ReturnPageNumber Entry "r3-r5,r11"
        MOV     r3, r1
        MOV     r11, r6
        BL      MoveCAMatR0toR3         ; use old internal routine for now
        EXIT

; MoveCAMatR0toR3
; in:   r0 = old logaddr
;       r3 = new logaddr
;       r9 = offset from 1st to 2nd copy of doubly mapped area (either source or dest, but not both)
;       r11 = page protection level
;
; out:  r2 = physical page number of page moved, unless there was a serious error
;       r0,r1,r3,r6-r12 preserved
;       r4,r5 corrupted

MoveCAMatR0toR3 Entry "r0,r1,r6,r7"
        LDR     r5, =L2PT
        ADD     r4, r5, r0, LSR #10             ; r4 -> L2PT for log addr r0
        MOV     r2, r4, LSR #12
        LDR     r2, [r5, r2, LSL #2]            ; r2 = L2PT entry for r4
        TST     r2, #3                          ; if no page there
        BEQ     %FT90                           ; then cam corrupt

        LDR     r4, [r4]                        ; r4 = L2PT entry for r0
        TST     r4, #3                          ; check entry is valid too
        BEQ     %FT91
        MOV     r4, r4, LSR #12                 ; r4 = phys addr >> 12

        LDR     r2, =ZeroPage
        LDR     r6, [r2, #MaxCamEntry]
        ADD     r5, r2, #PhysRamTable
      [ ZeroPage <> 0
        MOV     r2, #0
      ]
10
        CMP     r2, r6                          ; if page we've got to is > max
        BHI     %FT92                           ; then corrupt
        LDMIA   r5!, {r7, lr}                   ; get phys.addr, size
        SUB     r7, r4, r7, LSR #12             ; number of pages into this bank
        CMP     r7, lr, LSR #12                 ; if too many
        ADDCS   r2, r2, lr, LSR #12             ; then advance physical page no.
        BCS     %BT10                           ; and loop

        ADD     r2, r2, r7                      ; add on number of pages within bank
        BL      BangCamUpdate
        CLRV
        EXIT

90
        ADR     lr, NoL2ForPageBeingRemovedError ; NB don't corrupt r0 yet - we need that in block as evidence
95
        STR     lr, [sp]                        ; update returned r0
        BL      StoreDebugRegs
        PullEnv                                 ; seriously broken memory
        SETV
        MOV     pc, lr

91
        ADR     lr, PageBeingRemovedNotPresentError
        B       %BT95

92
        ADR     lr, PhysicalAddressNotFoundError
        B       %BT95

StoreDebugRegs ; Note: Corrupts R0,R1
        Push    "lr"
        LDR     lr, =ZeroPage+CamMapCorruptDebugBlock
        STMIA   lr, {r0-r12}
        STR     sp, [lr, #13*4]!
        LDMIA   sp, {r0,r1}                     ; reload stacked LR & return R0 (error pointer)
        STMIB   lr, {r0,r1}                     ; LR -> LR, error -> PC
        Pull    "pc"

NoL2ForPageBeingRemovedError
        &       0
        =       "Memory Corrupt: No L2PT for page being removed", 0
        ALIGN

PageBeingRemovedNotPresentError
        &       0
        =       "Memory Corrupt: Page being removed was not present", 0
        ALIGN

PhysicalAddressNotFoundError
        &       0
        =       "Memory Corrupt: Physical address not found", 0
        ALIGN

CamMapBroke
        &       0
        =       "!!!! CAM Map Corrupt !!!!", 0
        ALIGN

  [ FastCDA_Bulk
; RemoveCacheabilityR0ByMinusR2
; Make a range of pages (temporarily) uncacheable prior to (re)moving them
; in:   r0 = end of area
;       r2 = size of area (must be nonzero)
; out:  r6 has DynAreaFlags_NotCacheable set if entire region noncacheable
;              Flag clear if at least one page was cacheable
;       r0 points to start of area
;
;       4K page size assumed!
RemoveCacheabilityR0ByMinusR2 ROUT
        Entry   "r0-r5"
        MOV     r5, #DynAreaFlags_NotCacheable
        MOV     r1, #-1
10
        SUB     r0, r0, #4096
        BL      GetPageFlagsForR0IntoR6
        TST     r6, #DynAreaFlags_NotCacheable
        BNE     %FT90
        ; Work out required page flags - use cached flags from last page if possible
        CMP     r1, r6
        BEQ     %FT20
        LDR     r3, =ZeroPage
        MOV     r1, r6
        LDR     r3, [r3, #MMU_PCBTrans]
        GetTempUncache r4, r6, r3, lr
20
        ; Update the current L2PT entry
        LDR     r3, =L2PT
        LDR     lr, =TempUncache_L2PTMask
        LDR     r5, [r3, r0, LSR #10]
        BIC     r5, r5, lr
        ORR     r5, r5, r4
        STR     r5, [r3, r0, LSR #10]
        ; Clear the flag from R5
        MOV     r5, #0
90
        SUBS    r2, r2, #4096
        BNE     %BT10
        MOV     r6, r5
        FRAMSTR r0
        ; Perform the required cache/TLB maintenance
        LDR     r4, =ZeroPage
        FRAMLDR r1,,r2
        MOV     r1,r1,LSR #Log2PageSize
        TST     r6, #DynAreaFlags_NotCacheable
        ADR     lr, %FT91
        ARMop   MMU_ChangingEntries,EQ,tailcall,r4
        ARMop   MMU_ChangingUncachedEntries,NE,tailcall,r4
91
        EXIT
  ]

; Move pages at [R0-R4,R0) to [R1-R4,R1)
 [ FastCDA_Bulk
; Pages must be uncacheable
 ]
; R0 < R1
MoveUncacheableR0ToR1ByMinusR4 ROUT
        Entry   "r0,r1,r4,r6,r9"
        MOV     r9, #0                          ; no funny stuff while moving these pages
25
        SUB     r0, r0, #PageSize
        SUB     r1, r1, #PageSize
        BL      GetPageFlagsForR0IntoR6
 [ FastCDA_Bulk
        ORR     r6, r6, #PageFlags_Unsafe
 ]
        BL      MovePageAtR0ToR1WithAccessR6
        SUBS    r4, r4, #PageSize
        BNE     %BT25
      [ FastCDA_Bulk
        ; Flush the TLB for the shuffled pages
        ; R0 will be the lowest address we modified, and original R1 the highest (+1)
        FRAMLDR r1
        SUB     r1, r1, r0
        MOV     r1, r1, LSR #Log2PageSize
        LDR     r4, =ZeroPage
        ARMop   MMU_ChangingUncachedEntries,,,r4
      ]
        EXIT

; Move pages at [R0,R0+R4) to [R1,R1+R4)
 [ FastCDA_Bulk
; Pages must currently be uncacheable
 ]
; R0 > R1
MoveUncacheableR0ToR1ByR4WithAccessR6 ROUT
        Entry  "r0,r1,r4,r6,r9"
      [ FastCDA_Bulk
        ORR     r6, r6, #PageFlags_Unsafe
      ]
        MOV     r9, #0                          ; no funny business while moving these pages
15
        BL      MovePageAtR0ToR1WithAccessR6    ; move page
        ADD     r0, r0, #PageSize               ; advance src ptr
        ADD     r1, r1, #PageSize               ; advance dst ptr
        SUBS    r4, r4, #PageSize               ; one less page to move
        BNE     %BT15                           ; loop if more
      [ FastCDA_Bulk
        ; Flush the shuffled pages from the TLB
        ; Note we only flush the area containing pages which have been
        ; moved/removed; for pages which have been mapped in the only
        ; requirement is that (for VMSAv6) we issue a DSB+ISB, which we can
        ; assume the MMU_ChangingUnachedEntries op will do for us.
        MOV     r1, r0                          ; High end
        FRAMLDR r0,,r1                          ; Low end
        SUB     r1, r1, r0
        MOV     r1, r1, LSR #Log2PageSize
        LDR     r4, =ZeroPage
        ARMop   MMU_ChangingUncachedEntries,,,r4
      ]
        EXIT

; R1 = base of dynamic area (i.e. end of 1st copy)
; R2 = DA grow amount (how far to move pages)
; R4 = current DA size
; R6 = DA flags
ShuffleDoublyMappedRegionForGrow ROUT
        Entry   "r0,r1"
      [ FastCDA_Bulk
        ; Perform cache maintenance upfront
        MOV     r0, r1
        Push    "r2,r6"
        MOV     r2, r4
        BL      RemoveCacheabilityR0ByMinusR2
        Pull    "r2,r6"
      ]
        SUB     r0, r1, r4                      ; src starts at start of 1st copy = start of 2nd - old size
        SUB     r1, r0, r2                      ; dst start = src start - amount of room needed
        BL      MoveUncacheableR0ToR1ByR4WithAccessR6
        EXIT

; R2 = grow amount, bytes
; R3 = page list to add page numbers to, or null if not needed
; R11 = src DANode (free pool)
; R12 = dest DANode
DoTheGrowCommon ROUT
        Entry   "r0-r10"
; move pages starting from end of area

        LDR     r0, [r11, #DANode_PMP]
        LDR     r3, [r11, #DANode_PMPSize]
        ADD     r0, r0, r3, LSL #2              ; move r0 to point to after end of area
        SUB     r3, r3, r2, LSR #Log2PageSize   ; reduce by amount moving from area
        STR     r3, [r11, #DANode_PMPSize]      ; store reduced source size

        LDR     r1, [r12, #DANode_Base]
        LDR     r3, [r12, #DANode_Size]

        LDR     r6, [r12, #DANode_Flags]        ; r6 = dst flags
        LDR     lr, =DynAreaFlags_AccessMask
        AND     r6, r6, lr
        TST     r6, #DynAreaFlags_DoublyMapped  ; check if dst is doubly mapped
        BEQ     %FT25                           ; [it's not, so skip all this]

; we must shunt all existing pages in dest area down

        MOVS    r4, r3                          ; amount to do
        BLNE    ShuffleDoublyMappedRegionForGrow
        ADD     r9, r3, r2                      ; set up offset from 1st copy to 2nd copy (= new size)
25
        ADD     r1, r1, r3                      ; r1 -> address of 1st extra page
   [ FastCDA_Bulk
        ORR     r6, r6, #PageFlags_Unsafe                
   ]
        MOV     r4, #0                          ; amount done so far
        MOV     r10, r2                         ; move amount to do into r10
        FRAMLDR r3                              ; recover page list pointer
30
        LDR     r2, [r0, #-4]!                  ; pre-decrement source pointer
 [ DebugCDA2
        DREG    r2, "Moving page number ", cc
        DREG    r1, " to ", cc
        DREG    r6, " with PPL "
 ]
        Push    "r0-r1,r3-r4,r6,r11"
        MOV     r11, #-1
        MOV     r3, r1
        STR     r11, [r0]                       ; Remove from free pool PMP
        MOV     r11, r6
        BL      BangCamUpdate
        Pull    "r0-r1,r3-r4,r6,r11"
        ADD     r1, r1, #PageSize
        TEQ     r3, #0
        ADD     r4, r4, #PageSize
        STRNE   r2, [r3], #12                   ; store page number and move on
        CMP     r4, r10                         ; have we done all of it?
        BNE     %BT30                           ; [no, so loop]
      [ FastCDA_Bulk
        PageTableSync
      ]
35
        LDR     r3, [r12, #DANode_Size]
        ADD     r3, r3, r10
        STR     r3, [r12, #DANode_Size]         ; store increased destination size
      [ ZeroPage = 0
        TEQ     r12, #AppSpaceDANode            ; check if dest = appspace
      |
        LDR     lr, =ZeroPage+AppSpaceDANode
        TEQ     r12, lr                         ; check if dest = appspace
      ]
        STREQ   r3, [r12, #MemLimit-AppSpaceDANode] ; update memlimit if so
        EXIT

; r2 = shrink amount
; r11 = src DANode
; r12 = dest DANode (free pool)
DoTheShrink ROUT
        Entry   "r0-r10"
; Move pages starting from end of area

        LDR     r0, [r11, #DANode_Base]
        LDR     r3, [r11, #DANode_Size]
        LDR     r6, [r11, #DANode_Flags]        ; r6 = src flags
        Push    "r3, r6"                        ; save src old size, src flags for later
        TST     r6, #DynAreaFlags_DoublyMapped  ; if src is doubly mapped
        MOVNE   r9, r3                          ; then set up offset from 1st copy to 2nd copy = old src size
        ADD     r0, r0, r3                      ; move r0 to point to after end of area (2nd copy)
        SUB     r3, r3, r2
        STR     r3, [r11, #DANode_Size]         ; store reduced source size
      [ ZeroPage = 0
        TEQ     r11, #AppSpaceDANode            ; check if src = appspace
      |
        LDR     lr, =ZeroPage+AppSpaceDANode
        TEQ     r11, lr                         ; check if src = appspace
      ]
        STREQ   r3, [r11, #MemLimit-AppSpaceDANode] ; update memlimit if so
      [ PMPDebug
        DebugReg r3, "< src size"
      ]

        LDR     r3, [r12, #DANode_PMPSize]      ; r3 -> index of 1st extra page

      [ FastCDA_Bulk
        Push    "r0"
        BL      RemoveCacheabilityR0ByMinusR2
        LDR     r6, [r11, #DANode_Flags]
        TST     r6, #DynAreaFlags_DoublyMapped
        BEQ     %FT19
        ; Interacting with doubly-mapped region - make entireity of lower mapping uncacheable too
        LDR     r0, [r11, #DANode_Base]
        MOV     r1, r2
        LDR     r2, [sp, #4]                    ; Grab old source size (pushed r3)
        BL      RemoveCacheabilityR0ByMinusR2
        MOV     r2, r1
19
        Pull    "r0"
      ]        

        LDR     lr, =DynAreaFlags_AccessMask
        MOV     r4, r2
        LDR     r6, [r12, #DANode_Flags]        ; r6 = dst flags
        AND     r6, r6, lr
      [ FastCDA_Bulk
        ORR     r6, r6, #PageFlags_Unsafe
      ]
20
        SUB     r0, r0, #PageSize               ; pre-decrement source pointer
 [ DebugCDA2
        DREG    r0, "Moving page at ", cc
        DREG    r3, " to free pool index ", cc
        DREG    r6, " with PPL "
 ]
        Push    "r2"
        LDR     r1, =Nowhere
        BL      MovePageAtR0ToR1WithAccessR6ReturnPageNumber
        ; Update PMP association
        LDR     r1, [r12, #DANode_PMP]
        STR     r2, [r1, r3, LSL #2]            ; Store in free pool PMP
        LDR     lr, =ZeroPage
        LDR     lr, [lr, #CamEntriesPointer]
        ADD     lr, lr, r2, LSL #CAM_EntrySizeLog2
        STR     r12, [lr, #CAM_PMP]              ; Store PMP in CAM
        STR     r3, [lr, #CAM_PMPIndex]
        ADD     r3, r3, #1
        Pull    "r2"

        SUBS    r4, r4, #PageSize
        BNE     %BT20
      [ FastCDA_Bulk
        ; Flush the TLB for the removed pages
        Push    "r0-r1,r3"
        MOV     r1, r2, LSR #Log2PageSize
        LDR     r3, =ZeroPage
        ARMop   MMU_ChangingUncachedEntries,,,r3 ; src region
        LDR     r6, [r11, #DANode_Flags]        ; r6 = src flags
        TST     r6, #DynAreaFlags_DoublyMapped
        LDRNE   r0, [sp]
        SUBNE   r0, r0, r9
        ARMop   MMU_ChangingUncachedEntries,NE,,r3 ; doubly mapped src region
        Pull    "r0-r1,r3"
      ]

        STR     r3, [r12, #DANode_PMPSize]      ; store increased destination size

        Pull    "r3, r6"                        ; restore src old size, src flags
        TST     r6, #DynAreaFlags_DoublyMapped  ; if src doubly mapped
        SUBNES  r4, r3, r2                      ; then set r4 = number of pages to shuffle up
        BEQ     %FT30                           ; [not doubly mapped, or no pages left, so skip]

        SUB     r0, r0, r3                      ; move r0 back to end of 1st copy of pages remaining
        ADD     r1, r0, r2                      ; r1 is end of where they're moving to (should be src base address!)
        BL      MoveUncacheableR0ToR1ByMinusR4

30
        EXIT

 [ CacheablePageTables
MakePageTablesCacheable ROUT
        Entry   "r0,r4-r5,r8-r9"
        BL      GetPageFlagsForCacheablePageTables
        ; Update PageTable_PageFlags
        LDR     r1, =ZeroPage
        STR     r0, [r1, #PageTable_PageFlags]
        ; Adjust the logical mapping of the page tables to use the specified page flags
        LDR     r1, =L1PT
        LDR     r2, =16*1024
        BL      AdjustMemoryPageFlags
        LDR     r1, =L2PT
        LDR     r2, =4*1024*1024
        BL      AdjustMemoryPageFlags
        ; Update the TTBR
        LDR     r4, =L1PT
        LDR     r8, =L2PT
        BL      logical_to_physical
        MOV     r0, r5
        LDR     r1, =ZeroPage
        BL      SetTTBR
        ; Perform a full TLB flush to make sure the new mappings are visible
        ARMop   TLB_InvalidateAll,,,r1
        EXIT

MakePageTablesNonCacheable ROUT
        Entry   "r0-r1,r4-r5,r8-r9"
        ; Flush the page tables from the cache, so that when we update the TTBR
        ; below we can be sure that the MMU will be seeing the current page
        ; tables
        LDR     r0, =L1PT
        ADD     r1, r0, #16*1024
        LDR     r4, =ZeroPage
        ARMop   Cache_CleanRange,,,r4
        LDR     r0, =L2PT
        ADD     r1, r0, #4*1024*1024
        ARMop   Cache_CleanRange,,,r4
        ; Update the TTBR so the MMU performs non-cacheable accesses
        LDR     r0, =AreaFlags_PageTablesAccess :OR: DynAreaFlags_NotCacheable :OR: DynAreaFlags_NotBufferable
        STR     r0, [r4, #PageTable_PageFlags]
        LDR     r4, =L1PT
        LDR     r8, =L2PT
        BL      logical_to_physical
        MOV     r0, r5
        LDR     r1, =ZeroPage
        BL      SetTTBR
        ; Perform a full TLB flush just in case
        ARMop   TLB_InvalidateAll,,,r1
        ; Now we can adjust the logical mapping of the page tables to be non-cacheable
        LDR     r0, [r1, #PageTable_PageFlags]
        LDR     r1, =L1PT
        LDR     r2, =16*1024
        BL      AdjustMemoryPageFlags
        LDR     r1, =L2PT
        LDR     r2, =4*1024*1024
        BL      AdjustMemoryPageFlags
        EXIT

; In:
; R0 = new page flags
; R1 = base of area
; R2 = size of area
AdjustMemoryPageFlags ROUT
        Entry   "r0-r12"
        LDR     r8, =L2PT
        LDR     r12, =ZeroPage
        LDR     r7, [r12, #MaxCamEntry]
        MOV     r4, r1
10
        BL      logical_to_physical ; CC if page exists, r5 = phys addr
        BLCC    physical_to_ppn
        BCS     %FT90
        ; r9-r11 corrupt, r3 = page number, r5 = phys addr
        Push    "r0,r2,r4"
        MOV     r2, r3
        MOV     r3, r4
        ; Get the current page flags, so that we can retain the Unavailable flag
        ; (L2PT is a mix of locked and unlocked pages - potentially this is
        ; redundant and just a side-effect of ConstructCAMFromPageTables, but
        ; for now I'll play it safe and keep the current flag setting.
        ; N.B. If this is changed, be sure to make sure the flag is retained for
        ; L1PT)
        LDR     r11, [r12, #CamEntriesPointer]
        ADD     r11, r11, #CAM_PageFlags
        LDR     r11, [r11, r2, LSL #CAM_EntrySizeLog2]
        AND     r11, r11, #PageFlags_Unavailable
        ORR     r11, r0, r11
        BL      BangCamUpdate ; r0, r1, r4, r6 corrupted
        ; When making the pages non-cacheable, we need to be extra vigorous in
        ; order to make sure the cache and TLB aren't left in inconsistent
        ; states.
        TST     r11, #DynAreaFlags_NotCacheable
        BEQ     %FT50
        ; The MMU will be performing non-cacheable accesses, but the CPU will
        ; be performing cacheable accesses, so the maintenance performed by
        ; BangCamUpdate won't have done anything useful.
        ; So start by flushing the L2PT word from the cache.
        ADD     r0, r8, r3, LSR #10 ; -> L2PT entry we modified
        LDRB    r2, [r12, #Cache_Type]
        CMP     r2, #CT_ctype_WB_CR7_Lx ; DCache_LineLen lin or log?
        LDRB    r2, [r12, #DCache_LineLen]
        MOVEQ   lr, #4
        MOVEQ   r2, lr, LSL r2
        SUB     r2, r2, #1
        BIC     r0, r0, r2
        ADD     r1, r0, r2
        ADD     r1, r1, #1
        ARMop   Cache_CleanRange,,,r12
        ; Now that we know the page table write has gone to main memory, we can
        ; do regular TLB+cache maintenance for the area and have it take effect
        MOV     r0, r3
        ARMop   MMU_ChangingEntry,,,r12
50
        Pull    "r0,r2,r4"
90
        SUBS    r2, r2, #PageSize
        ADD     r4, r4, #PageSize
        BNE     %BT10
        EXIT
 ]

        END
