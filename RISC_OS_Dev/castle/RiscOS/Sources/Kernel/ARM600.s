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
; > ARM600

        ; Convert given page flags to the equivalent temp uncacheable L2PT flags
        ; n.b. temp not used here but included for VMSAv6 compatibility
        MACRO
        GetTempUncache $out, $pageflags, $pcbtrans, $temp
        ASSERT  $out <> $pageflags ; For consistency with VMSAv6 version
        ASSERT  $out <> $pcbtrans
      [ "$temp" <> ""
        ASSERT  $out <> $temp      ; For consistency with VMSAv6 version
        ASSERT  $temp <> $pcbtrans ; For consistency with VMSAv6 version
      ]
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        AND     $out, $pageflags, #DynAreaFlags_NotCacheable + DynAreaFlags_NotBufferable
        ORR     $out, $out, #DynAreaFlags_NotCacheable      ; treat as temp uncache
        LDRB    $out, [$pcbtrans, $out, LSR #4]             ; convert to X, C and B bits for this CPU
        MEND

TempUncache_L2PTMask * L2_X+L2_C+L2_B

; MMU interface file - ARM600 version

        KEEP

; **************** CAM manipulation utility routines ***********************************

; **************************************************************************************
;
;       BangCamUpdate - Update CAM, MMU for page move, coping with page currently mapped in
;
; mjs Oct 2000
; reworked to use generic ARM ops (vectored to appropriate routines during boot)
;
; First look in the CamEntries table to find the logical address L this physical page is
; currently allocated to. Then check in the Level 2 page tables to see if page L is currently
; at page R2. If it is, then map page L to be inaccessible, otherwise leave page L alone.
; Then map logical page R3 to physical page R2.
;
; in:   r2 = physical page number
;       r3 = logical address (2nd copy if doubly mapped area)
;       r9 = offset from 1st to 2nd copy of doubly mapped area (either source or dest, but not both)
;       r11 = PPL + CB bits
;
; out:  r0, r1, r4, r6 corrupted
;       r2, r3, r5, r7-r12 preserved
;

BangCamUpdate ROUT
        TST     r11, #DynAreaFlags_DoublyMapped ; if moving page to doubly mapped area
        SUBNE   r3, r3, r9                      ; then CAM soft copy holds ptr to 1st copy

        LDR     r1, =ZeroPage
        LDR     r1, [r1, #CamEntriesPointer]
        ADD     r1, r1, r2, LSL #CAM_EntrySizeLog2 ; point at cam entry (logaddr, PPL)
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        LDMIA   r1, {r0, r6}                    ; r0 = current logaddress, r6 = current PPL
        BIC     r4, r11, #PageFlags_Unsafe
        STMIA   r1, {r3, r4}                    ; store new address, PPL
        Push    "r0, r6"                        ; save old logical address, PPL
        LDR     r1, =ZeroPage+PhysRamTable      ; go through phys RAM table
        MOV     r6, r2                          ; make copy of r2 (since that must be preserved)
10
        LDMIA   r1!, {r0, r4}                   ; load next address, size
        SUBS    r6, r6, r4, LSR #12             ; subtract off that many pages
        BCS     %BT10                           ; if more than that, go onto next bank

        ADD     r6, r6, r4, LSR #12             ; put back the ones which were too many
        ADD     r0, r0, r6, LSL #12             ; move on address by the number of pages left
        LDR     r6, [sp]                        ; reload old logical address

; now we have r6 = old logical address, r2 = physical page number, r0 = physical address

        TEQ     r6, r3                          ; TMD 19-Jan-94: if old logaddr = new logaddr, then
        BEQ     %FT20                           ; don't remove page from where it is, to avoid window
                                                ; where page is nowhere.
        LDR     r1, =L2PT
        ADD     r6, r1, r6, LSR #10             ; r6 -> L2PT entry for old log.addr
        MOV     r4, r6, LSR #12                 ; r4 = word offset into L2 for address r6
        LDR     r4, [r1, r4, LSL #2]            ; r4 = L2PT entry for L2PT entry for old log.addr
        TST     r4, #3                          ; if page not there
        BEQ     %FT20                           ; then no point in trying to remove it

        LDR     r4, [r6]                        ; r4 = L2PT entry for old log.addr
        MOV     r4, r4, LSR #12                 ; r4 = physical address for old log.addr
        TEQ     r4, r0, LSR #12                 ; if equal to physical address of page being moved
        BNE     %FT20                           ; if not there, then just put in new page

        AND     r4, r11, #PageFlags_Unsafe
        Push    "r0, r3, r11, r14"              ; save phys.addr, new log.addr, new PPL, lr
        ADD     r3, sp, #4*4
        LDMIA   r3, {r3, r11}                   ; reload old logical address, old PPL
        LDR     r0, =DuffEntry                  ; Nothing to do if wasn't mapped in
        ORR     r11, r11, r4
        TEQ     r3, r0
        MOV     r0, #0                          ; cause translation fault
        BLNE    BangL2PT                        ; map page out
        Pull    "r0, r3, r11, r14"
20
        ADD     sp, sp, #8                      ; junk old logical address, PPL
        B       BangCamAltEntry                 ; and branch into BangCam code

; **************************************************************************************
;
;       BangCam - Update CAM, MMU for page move, assuming page currently mapped out
;
; This routine maps a physical page to a given logical address
; It is assumed that the physical page is currently not mapped anywhere else
;
; in:   r2 = physical page number
;       r3 = logical address (2nd copy if doubly mapped)
;       r9 = offset from 1st to 2nd copy of doubly mapped area (either source or dest, but not both)
;       r11 = PPL
;
; out:  r0, r1, r4, r6 corrupted
;       r2, r3, r5, r7-r12 preserved
;
; NB The physical page number MUST be in range.

BangCam ROUT
        TST     r11, #DynAreaFlags_DoublyMapped ; if area doubly mapped
        SUBNE   r3, r3, r9              ; then move ptr to 1st copy

        LDR     r1, =ZeroPage+PhysRamTable ; go through phys RAM table
        MOV     r6, r2                  ; make copy of r2 (since that must be preserved)
10
        LDMIA   r1!, {r0, r4}           ; load next address, size
        SUBS    r6, r6, r4, LSR #12     ; subtract off that many pages
        BCS     %BT10                   ; if more than that, go onto next bank

        ADD     r6, r6, r4, LSR #12     ; put back the ones which were too many
        ADD     r0, r0, r6, LSL #12     ; move on address by the number of pages left
BangCamAltEntry
        LDR     r4, =DuffEntry          ; check for requests to map a page to nowhere
        TEQ     r4, r3                  ; don't actually map anything to nowhere
        MOVEQ   pc, lr
        GetPTE  r0, 4K, r0, r11
 
        LDR     r1, =L2PT               ; point to level 2 page tables

        ;fall through to BangL2PT

;internal entry point for updating L2PT entry
;
; entry: r0 = new L2PT value, r1 -> L2PT, r3 = logical address (4k aligned), r11 = PPL
;
; exit: r0,r1,r4,r6 corrupted
;
BangL2PT                                        ; internal entry point used only by BangCamUpdate
        Push    "lr"
        MOV     r6, r0

        TST     r11, #PageFlags_Unsafe
        BNE     BangL2PT_unsafe

        ;In order to safely map out a cacheable page and remove it from the
        ;cache, we need to perform the following process:
        ;* Make the page uncacheable
        ;* Flush TLB
        ;* Clean+invalidate cache
        ;* Write new mapping (r6)
        ;* Flush TLB
        ;For uncacheable pages we can just do the last two steps
        ;
        TEQ     r6, #0                          ;EQ if mapping out
        TSTEQ   r11, #DynAreaFlags_NotCacheable ;EQ if also cacheable (overcautious for temp uncache+illegal PCB combos)
        LDR     r4, =ZeroPage
        BNE     %FT20
        LDR     lr, [r4, #MMU_PCBTrans]
        GetTempUncache r0, r11, lr
        LDR     lr, [r1, r3, LSR #10]           ;get current L2PT entry
        BIC     lr, lr, #TempUncache_L2PTMask   ;remove current attributes
        ORR     lr, lr, r0
        STR     lr, [r1, r3, LSR #10]!          ;Make uncacheable
        TST     r11, #DynAreaFlags_DoublyMapped
        BEQ     %FT19
        STR     lr, [r1, r9, LSR #10]           ;Update 2nd mapping too if required
        ADD     r0, r3, r9
        ARMop   MMU_ChangingEntry,,, r4
19
        MOV     r0, r3
        ARMop   MMU_ChangingEntry,,, r4
        LDR     r1, =L2PT

20      STR     r6, [r1, r3, LSR #10]!          ;update L2PT entry
        TST     r11, #DynAreaFlags_DoublyMapped
        BEQ     %FT21
        STR     r6, [r1, r9, LSR #10]           ;Update 2nd mapping
        MOV     r0, r3
        ARMop   MMU_ChangingUncachedEntry,,, r4 ; TLB flush for 1st mapping
        ADD     r3, r3, r9                      ;restore r3 back to 2nd copy
21
        Pull    "lr"
        MOV     r0, r3
        ARMop   MMU_ChangingUncachedEntry,,tailcall,r4

BangL2PT_unsafe
        STR     r6, [r1, r3, LSR #10]!          ; update level 2 page table (and update pointer so we can use bank-to-bank offset
        TST     r11, #DynAreaFlags_DoublyMapped ; if area doubly mapped
        STRNE   r6, [r1, r9, LSR #10]           ; then store entry for 2nd copy as well
        ADDNE   r3, r3, r9                      ; and point logical address back at 2nd copy
        Pull    "pc"

 [ ARM6support
PPLTransARM6
        &       (AP_Full * L2_APMult) + L2_SmallPage      ; R any W any
        &       (AP_Read * L2_APMult) + L2_SmallPage      ; R any W sup
        &       (AP_None * L2_APMult) + L2_SmallPage      ; R sup W sup
        &       (AP_Read * L2_APMult) + L2_SmallPage      ; R any W sup

PPLAccessARM6        ; EL1EL0
                     ; RWXRWX
        GenPPLAccess 2_111111
        GenPPLAccess 2_111101
        GenPPLAccess 2_111000
        GenPPLAccess 2_111101
        DCD     -1
 ]

PPLTrans
        &       (AP_Full * L2_APMult) + L2_SmallPage      ; R any W any
        &       (AP_Read * L2_APMult) + L2_SmallPage      ; R any W sup
        &       (AP_None * L2_APMult) + L2_SmallPage      ; R sup W sup
        &       (AP_ROM  * L2_APMult) + L2_SmallPage      ; R any W none

PPLTransX
        &       (AP_Full * L2X_APMult) + L2_ExtPage       ; R any W any
        &       (AP_Read * L2X_APMult) + L2_ExtPage       ; R any W sup
        &       (AP_None * L2X_APMult) + L2_ExtPage       ; R sup W sup
        &       (AP_ROM  * L2X_APMult) + L2_ExtPage       ; R any W none

PPLAccess            ; EL1EL0
                     ; RWXRWX
        GenPPLAccess 2_111111
        GenPPLAccess 2_111101
        GenPPLAccess 2_111000
        GenPPLAccess 2_101101
        DCD     -1

PageShifts
        =       12, 13, 0, 14           ; 1 2 3 4
        =       0,  0,  0, 15           ; 5 6 7 8

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; "ARM600"-specific OS_MMUControl code
;

; in:   r0 = 0 (reason code 0, for modify control register)
;       r1 = EOR mask
;       r2 = AND mask
;
;       new control = ((old control AND r2) EOR r1)
;
; out:  r1 = old value
;       r2 = new value
MMUControl_ModifyControl ROUT
        Push    "r0,r3,r4,r5"
        CMP     r1,#0
        CMPEQ   r2,#&FFFFFFFF
        BEQ     MMUC_modcon_readonly
        LDR     r3,=ZeroPage
        LDRB    r5,[r3, #ProcessorArch]
        PHPSEI  r4                      ; disable IRQs while we modify soft copy (and possibly switch caches off/on)

        CMP     r5,#ARMv4
        LDRLO   lr, [r3, #MMUControlSoftCopy]
        ARM_read_control lr,HS          ; if ARMv4 or later, we can read control reg. - trust this more than soft copy
        AND     r2, r2, lr
        EOR     r2, r2, r1
        MOV     r1, lr
        STR     r2, [r3, #MMUControlSoftCopy]
        BIC     lr, r2, r1              ; lr = bits going from 0->1
        TST     lr, #MMUC_C             ; if cache turning on then flush cache before we do it
        BEQ     %FT05

        ARMop   Cache_InvalidateAll,,,r3 ; D-cache turning on, I-cache invalidate is either necessary (both turning on) or a safe side-effect
        B       %FT10

05
        TST     lr, #MMUC_I
        ARMop   IMB_Full,NE,,r3         ; I-cache turning on, Cache_InvalidateAll could be unsafe

10
        BIC     lr, r1, r2              ; lr = bits going from 1->0
        TST     lr, #MMUC_C             ; if cache turning off then clean data cache first
        BEQ     %FT15
        ARMop   Cache_CleanAll,,,r3
15
        ARM_write_control r2
        BIC     lr, r1, r2              ; lr = bits going from 1->0
        TST     lr, #MMUC_C             ; if cache turning off then flush cache afterwards
        BEQ     %FT17
        LDR     r3,=ZeroPage
        ARMop   Cache_InvalidateAll,,,r3 ; D-cache turned off, can safely invalidate I+D
        B       %FT20
17
        TST     lr, #MMUC_I
        BEQ     %FT20
        LDR     r3,=ZeroPage
        ARMop   IMB_Full,,,r3           ; Only I-cache which turned off, clean D-cache & invalidate I-cache
20
        PLP     r4                      ; restore IRQ state
        Pull    "r0,r3,r4,r5,pc"

MMUC_modcon_readonly
        LDR     r3, =ZeroPage
        LDRB    r5, [r3, #ProcessorArch]
        CMP     r5, #ARMv4
        LDRLO   lr, [r3, #MMUControlSoftCopy]
        ARM_read_control lr,HS          ; if ARMv4 or later, we can read control reg. - trust this more than soft copy
        STRHS   lr, [r3, #MMUControlSoftCopy]
        MOV     r1, lr
        MOV     r2, lr
        Pull    "r0,r3,r4,r5,pc"

; If extended pages are supported:
; PPLTrans should contain L2X_AP + L2_ExtPage
; PCBTrans should contain L2_C+L2_B+L2_TEX (for an extended page)
; If extended pages aren't supported:
; PPLTrans should contain L2_AP + L2_SmallPage
; PCBTrans should contain L2_C+L2_B

; In:
; r0 = phys addr (aligned)
; r1 = page flags:
;      DynAreaFlags_APBits
;      DynAreaFlags_NotBufferable
;      DynAreaFlags_NotCacheable
;      DynAreaFlags_CPBits
;      PageFlags_TempUncacheableBits
; r2 -> PPLTrans
; r3 -> PCBTrans
; Out:
; r0 = PTE for 4K page ("small page" or "extended page" depending on PPLTrans)
Get4KPTE ROUT
        Entry   "r4"
        AND     lr, r1, #DynAreaFlags_APBits
        LDR     lr, [r2, lr, LSL #2]
        ; Insert AP bits, page type/size
        ORR     r0, r0, lr
        ; Insert CB+TEX bits
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        TST     r1, #PageFlags_TempUncacheableBits
        AND     r4, r1, #DynAreaFlags_NotCacheable + DynAreaFlags_NotBufferable
        AND     lr, r1, #DynAreaFlags_CPBits
        ORRNE   r4, r4, #DynAreaFlags_NotCacheable      ; if temp uncache, set NC bit, ignore P
        ORREQ   r4, r4, lr, LSR #10-4                   ; else use NC, NB and P bits
        LDRB    r4, [r3, r4, LSR #4]                    ; convert to X, C and B bits for this CPU
        ORR     r0, r0, r4
        EXIT

; In:
; As per Get4KPTE
; Out:
; r0 = PTE for 64K page ("large page")
Get64KPTE ROUT
        Entry   "r4"
        AND     lr, r1, #DynAreaFlags_APBits
        LDR     lr, [r2, lr, LSL #2]
        ; Force to large page
        ORR     r0, r0, #L2_LargePage
        ; Insert AP bits
        AND     lr, lr, #L2X_AP ; If extended pages are supported, we need to expand L2X_AP to L2_AP
        MOV     r4, #L2_APMult/L2X_APMult
        MLA     r0, r4, lr, r0
50
        ; Insert CB+TEX bits
        ; Shared with Get1MPTE
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        TST     r1, #PageFlags_TempUncacheableBits
        AND     r4, r1, #DynAreaFlags_NotCacheable + DynAreaFlags_NotBufferable
        AND     lr, r1, #DynAreaFlags_CPBits
        ORRNE   r4, r4, #DynAreaFlags_NotCacheable      ; if temp uncache, set NC bit, ignore P
        ORREQ   r4, r4, lr, LSR #10-4                   ; else use NC, NB and P bits
        LDRB    r4, [r3, r4, LSR #4]                    ; convert to X, C and B bits for this CPU
        ; Move TEX field up
        ORR     r4, r4, r4, LSL #L2L_TEXShift-L2_TEXShift
        BIC     r4, r4, #L2_TEX :OR: ((L2_C+L2_B) :SHL: (L2L_TEXShift-L2_TEXShift))
        ORR     r0, r0, r4
        EXIT

; In:
; As per Get4KPTE
; Out:
; r0 = PTE for 1M page ("section")
Get1MPTE
        ALTENTRY
        AND     lr, r1, #DynAreaFlags_APBits
      [ ARM6support
        ; Set U bit if cacheable and not ROM access
        ; (Because ROM access isn't supported, it'll get mapped to AP_Read.
        ;  Writes to ROM will presumably be ignored by the bus, but if we have
        ;  U set it will update the cache, effectively giving people the power
        ;  to temporarily overwrite ROM)
        CMP     lr, #2
        TSTLS   r1, #DynAreaFlags_NotCacheable        
        ORREQ   r0, r0, #L1_U
      ]
        LDR     lr, [r2, lr, LSL #2]
        ; Force to section map
        ORR     r0, r0, #L1_Section
        ; Insert AP bits
        ASSERT  L1_AP = L2X_AP :SHL: 6
        AND     lr, lr, #L2X_AP
        ORR     r0, r0, lr, LSL #6
        ; Insert CB+TEX bits
        ASSERT  L1_C = L2_C
        ASSERT  L1_B = L2_B
        ASSERT  L1_TEXShift = L2L_TEXShift
        B       %BT50

; In:
; r0 = L2PT entry
; Out:
; r0 = phys addr
; r1 = page flags
;      or -1 if fault
; r2 = page size (bytes)
DecodeL2Entry   ROUT
        ANDS    r2, r0, #3
        MOVEQ   r1, #-1
        MOVEQ   pc, lr
        Entry   "r3-r5"
        ; Get AP bits in low bits
        ASSERT  L2X_APMult = 1:SHL:4
        MOV     r1, r0, LSR #4
        ; Remap TEX+CB so that they're in the same position as an extended page entry
        ASSERT  L2_LargePage < L2_SmallPage
        ASSERT  L2_SmallPage < L2_ExtPage
        CMP     r2, #L2_SmallPage
        AND     r4, r0, #L2_C+L2_B
        ANDLT   lr, r0, #L2L_TEX
        ORRLT   r4, r4, lr, LSR #L2L_TEXShift-L2_TEXShift
        ANDGT   lr, r0, #L2_TEX
        ORRGT   r4, r4, lr
        ; Align phys addr to page size and set up R2
        MOV     r0, r0, LSR #12
        BICLT   r0, r0, #15
        MOV     r0, r0, LSL #12
        MOVLT   r2, #65536
        MOVGE   r2, #4096
20
        ; Common code shared with DecodeL1Entry
        ; Only four PPL possibilities, so just directly decode it
        ; ARM access goes 0 => all R/O, 1 => user none, 2 => user R/O, 3  => user R/W
        ; PPL access goes 0 => user R/W, 1 => user R/O, 2 => user none, 3 => all R/0
        ; i.e. just invert the bits
        AND     r1, r1, #3
        LDR     r3, =ZeroPage
        EOR     r1, r1, #3
        ; Search through PCBTrans for a match on TEX+CB
        ; Funny order is used so that NCNB is preferred over other variants (since NCNB is common fallback)
        LDR     r3, [r3, #MMU_PCBTrans]
        MOV     lr, #3
30
        LDRB    r5, [r3, lr]
        CMP     r5, r4
        BEQ     %FT40
        TST     lr, #2_11
        SUBNE   lr, lr, #1                      ; loop goes 3,2,1,0,7,6,5,4,...,31,30,29,28
        ADDEQ   lr, lr, #7
        TEQ     lr, #35  
        BNE     %BT30                           ; Give up if end of table reached
40
        ; Decode index back into page flags
        ; n.b. temp uncache is ignored (no way we can differentiate between real uncached)
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        AND     r4, lr, #XCB_NC+XCB_NB
        AND     lr, lr, #7*XCB_P
        ORR     r1, r1, r4, LSL #4
        ORR     r1, r1, lr, LSL #10
        EXIT

; In:
; r0 = L1PT entry
; Out:
; r0 = phys addr
; r1 = page flags if 1MB page
;      or -1 if fault
;      or -2 if page table ptr
DecodeL1Entry
        ALTENTRY
        AND     r1, r0, #3
        ASSERT  L1_Fault < L1_Page
        ASSERT  L1_Page < L1_Section
        CMP     r1, #L1_Page
        BGT     %FT50
        MOVLT   r1, #-1
        MOVEQ   r1, #-2
        MOVEQ   r0, r0, LSR #10
        MOVEQ   r0, r0, LSL #10
        EXIT
50
        ; Get AP bits in low bits
        ASSERT  L1_APMult = 1:SHL:10
        MOV     r1, r0, LSR #10
        ; Remap TEX+CB so that they're in the same position as an extended page entry
        ASSERT  L1_C = L2_C
        ASSERT  L1_B = L2_B
        AND     r4, r0, #L1_C+L1_B
        AND     lr, r0, #L1_TEX
        ORR     r4, r4, lr, LSR #L1_TEXShift-L2_TEXShift
        ; Align phys addr to page size
        MOV     r0, r0, LSR #20
        MOV     r0, r0, LSL #20
        ; Jump to common code to do AP decode + PCBTrans search
        B       %BT20

; In:
; r0 = phys addr (aligned)
; r1 -> ZeroPage
; Out:
; TTBR and any other related registers updated
; If MMU is currently on, it's assumed the mapping of ROM+stack will not be
; affected by this change
SetTTBR ROUT
        ARM_MMU_transbase r0
        MOV     pc, lr

 [ CacheablePageTables
; Out: R0 = desired page flags for the page tables
GetPageFlagsForCacheablePageTables ROUT
        ; For ARMv5 and below the MMU can't read from the L1 cache, so the
        ; best we can do is a write-through cache policy
        LDR     r0, =AreaFlags_PageTablesAccess :OR: (CP_CB_Writethrough :SHL: DynAreaFlags_CPShift)
        MOV     pc, lr
 ]

        END
