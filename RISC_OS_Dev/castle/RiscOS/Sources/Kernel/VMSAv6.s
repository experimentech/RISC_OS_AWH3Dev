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
; > VMSAv6

; MMU interface file - VMSAv6 version

; Created from s.ARM600 by JL 18-Feb-09


; Make sure we aren't being compiled against a CPU that can't possibly support a VMSAv6 MMU

        ASSERT :LNOT: NoARMv6

        KEEP

        ; Convert given page flags to the equivalent temp uncacheable L2PT flags
        MACRO
        GetTempUncache $out, $pageflags, $pcbtrans, $temp
        ASSERT  $out <> $pageflags
        ASSERT  $out <> $pcbtrans
        ASSERT  $out <> $temp
        ASSERT  $temp <> $pcbtrans
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        AND     $out, $pageflags, #DynAreaFlags_NotCacheable + DynAreaFlags_NotBufferable
        AND     $temp, $pageflags, #DynAreaFlags_CPBits
        ORR     $out, $out, #XCB_TU<<4                      ; treat as temp uncacheable
        ORR     $out, $out, $temp, LSR #10-4
        MOV     $out, $out, LSR #3
        LDRH    $out, [$pcbtrans, $out]                     ; convert to C, B and TEX bits for this CPU
        MEND

TempUncache_L2PTMask * L2_B+L2_C+L2_TEX

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
        ; Potentially we could just map as strongly-ordered + XN here
        ; But for safety just go for temp uncacheable (will retain memory type + shareability)
        LDR     lr, [r4, #MMU_PCBTrans]
        GetTempUncache r0, r11, lr, r4
        LDR     lr, [r1, r3, LSR #10]           ;get current L2PT entry
        LDR     r4, =TempUncache_L2PTMask
        BIC     lr, lr, r4                      ;remove current attributes
        ORR     lr, lr, r0
        STR     lr, [r1, r3, LSR #10]!          ;Make uncacheable
        TST     r11, #DynAreaFlags_DoublyMapped
        LDR     r4, =ZeroPage
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


PPLTransNonShareable                                          ; EL1 EL0
        DCW     (AP_Full * L2_APMult)+L2_SmallPage            ; RWX RWX
        DCW     (AP_Read * L2_APMult)+L2_SmallPage            ; RWX R X
        DCW     (AP_None * L2_APMult)+L2_SmallPage            ; RWX
        DCW     (AP_ROM  * L2_APMult)+L2_SmallPage            ; R X R X
        DCW     (AP_PROM * L2_APMult)+L2_SmallPage            ; R X
        DCW     (AP_Full * L2_APMult)+L2_SmallPage+L2_XN      ; RW  RW 
        DCW     (AP_Read * L2_APMult)+L2_SmallPage+L2_XN      ; RW  R  
        DCW     (AP_None * L2_APMult)+L2_SmallPage+L2_XN      ; RW     
        DCW     (AP_ROM  * L2_APMult)+L2_SmallPage+L2_XN      ; R   R  
        DCW     (AP_PROM * L2_APMult)+L2_SmallPage+L2_XN      ; R

PPLTransShareable                                             ; EL1 EL0
        DCW     (AP_Full * L2_APMult)+L2_SmallPage      +L2_S ; RWX RWX
        DCW     (AP_Read * L2_APMult)+L2_SmallPage      +L2_S ; RWX R X
        DCW     (AP_None * L2_APMult)+L2_SmallPage      +L2_S ; RWX
        DCW     (AP_ROM  * L2_APMult)+L2_SmallPage      +L2_S ; R X R X
        DCW     (AP_PROM * L2_APMult)+L2_SmallPage      +L2_S ; R X
        DCW     (AP_Full * L2_APMult)+L2_SmallPage+L2_XN+L2_S ; RW  RW 
        DCW     (AP_Read * L2_APMult)+L2_SmallPage+L2_XN+L2_S ; RW  R  
        DCW     (AP_None * L2_APMult)+L2_SmallPage+L2_XN+L2_S ; RW     
        DCW     (AP_ROM  * L2_APMult)+L2_SmallPage+L2_XN+L2_S ; R   R  
        DCW     (AP_PROM * L2_APMult)+L2_SmallPage+L2_XN+L2_S ; R

PPLAccess            ; EL1EL0
                     ; RWXRWX
        GenPPLAccess 2_111111
        GenPPLAccess 2_111101
        GenPPLAccess 2_111000
        GenPPLAccess 2_101101
        GenPPLAccess 2_101000
        GenPPLAccess 2_110110
        GenPPLAccess 2_110100
        GenPPLAccess 2_110000
        GenPPLAccess 2_100100
        GenPPLAccess 2_100000
        DCD     -1

PageShifts
        =       12, 13, 0, 14           ; 1 2 3 4
        =       0,  0,  0, 15           ; 5 6 7 8

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; "VMSAv6"-specific OS_MMUControl code
;

        ; Make current stack page(s) temporarily uncacheable to make cache disable operations safer
        ; In: R0 = OS_Memory 0 flags
ModifyStackCacheability
        Entry   "r1-r2", 24             ; Make up to two pages uncacheable
        ADD     lr, sp, #24+12          ; Get original SP
        STR     lr, [sp, #4]            ; Make current page uncacheable
        ASSERT  (SVCStackAddress :AND: ((1<<20)-1)) = 0 ; Assume MB aligned stack
        TST     lr, #(1<<20)-4096       ; Zero if this is the last stack page
        SUBNE   lr, lr, #4096
        STRNE   lr, [sp, #12+4]         ; Make next page uncacheable
        MOVNE   r2, #2
        MOV     r1, sp
        MOVEQ   r2, #1
        BL      MemoryConvertNoFIQCheck ; Bypass FIQ disable logic within OS_Memory (we've already claimed the FIQ vector)
        EXIT

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
        MOV     r3, r1
        MOV     r1, #Service_ClaimFIQ
        SWI     XOS_ServiceCall         ; stop FIQs for safety
        MOV     r1, r3
        LDR     r3,=ZeroPage
        MRS     r4, CPSR
        CPSID   if                      ; disable IRQs while we modify soft copy (and possibly switch caches off/on)

        ; We're ARMv6+, just read the real control reg and ignore the soft copy
        ARM_read_control lr
        AND     r2, r2, lr
        EOR     r2, r2, r1
        MOV     r1, lr

        ; On some CPUs LDREX/STREX only work on cacheable memory. Allowing the
        ; D-cache to be disabled in this situation is likely to result in near-
        ; instant failure of the OS.
        LDR     r5, [r3, #ProcessorFlags]
        TST     r5, #CPUFlag_NoDCacheDisable
        ORRNE   r2, r2, #MMUC_C

        ; If we have multiple cache levels, assume it's split caches ontop of a
        ; unified cache. In which case, having mismatched I+D cache settings can
        ; be pretty dangerous due to the IMB ARMops assuming that cleaning to
        ; PoU is sufficient (D-cache on but I-cache off will fail due to the
        ; instruction fetches bypassing the unified cache, D-cache off but
        ; I-cache on will fail because the I-cache will pull code into the
        ; unified cache which an IMB won't clean)
        ; If we have the ability to disable the L2 cache then this would be OK,
        ; but we can't guarantee that ability
        Push    "r1-r4"
        MOV     r1, #1
        ARMop   Cache_Examine,,,r3
        CMP     r0, #0
        Pull    "r1-r4"
        BEQ     %FT04        
        LDR     lr, =MMUC_C+MMUC_I
        TST     r2, lr
        ORRNE   r2, r2, lr              ; If one cache is on, force both on

04
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
        ; If I+D currently enabled, and at least one is turning off, turn off
        ; HAL L2 cache
        TST     r1, #MMUC_C
        TSTNE   r1, #MMUC_I
        BEQ     %FT11
        TST     r2, #MMUC_C
        TSTNE   r2, #MMUC_I
        BNE     %FT11
        LDR     r0, [r3, #Cache_HALDevice]
        TEQ     r0, #0
        BEQ     %FT11
        Push    "r1-r3,r12"
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_Deactivate]
        Pull    "r1-r3,r12"
11
        BIC     lr, r1, r2              ; lr = bits going from 1->0
        TST     lr, #MMUC_C             ; if cache turning off then clean data cache first
        BEQ     %FT15
        ; When disabling the data cache we have the problem that modern ARMs generally ignore unexpected cache hits, so any stack usage between us disabling the cache and finishing the clean + invalidate is very unsafe
        ; Solve this problem by making the current pages of the SVC stack temporarily uncacheable for the duration of the dangerous bit
        ; (n.b. making the current stack page uncacheable has the same problems as turning off the cache globally, but OS_Memory 0 has its own workaround for that)
        MOV     r0, #(1<<9)+(2<<14)
        BL      ModifyStackCacheability
        ARMop   Cache_CleanAll,,,r3
15
        ARM_write_control r2
        myISB   ,lr ; Must be running on >=ARMv6, so perform ISB to ensure CP15 write is complete
        BIC     lr, r1, r2              ; lr = bits going from 1->0
        TST     lr, #MMUC_C             ; if cache turning off then flush cache afterwards
        BEQ     %FT17
        LDR     r3,=ZeroPage
        ARMop   Cache_InvalidateAll,,,r3 ; D-cache turned off, can safely invalidate I+D
        B       %FT19
17
        TST     lr, #MMUC_I
        BEQ     %FT20
        LDR     r3,=ZeroPage
        ARMop   IMB_Full,,,r3           ; Only I-cache which turned off, clean D-cache & invalidate I-cache
19
        ; Undo any stack uncaching we performed above
        BIC     lr, r1, r2
        TST     lr, #MMUC_C
        MOVNE   r0, #(1<<9)+(3<<14)
        BLNE    ModifyStackCacheability
20
        ; If either I+D was disabled, and now both are turned on, turn on HAL
        ; L2 cache
        TST     r1, #MMUC_C
        TSTNE   r1, #MMUC_I
        BNE     %FT30
        TST     r2, #MMUC_C
        TSTNE   r2, #MMUC_I
        BEQ     %FT30
        LDR     r0, [r3, #Cache_HALDevice]
        TEQ     r0, #0
        BEQ     %FT30
        Push    "r1-r3,r12"
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_Activate]
        Pull    "r1-r3,r12"
30
        MSR     CPSR_c, r4              ; restore IRQ state
        MOV     r3, r1
        MOV     r1, #Service_ReleaseFIQ
        SWI     XOS_ServiceCall         ; allow FIQs again
        MOV     r1, r3
        CLRV
        Pull    "r0,r3,r4,r5,pc"

MMUC_modcon_readonly
        LDR     r3, =ZeroPage
        ; We're ARMv6+, just read the real control reg and ignore the soft copy
        ARM_read_control r1
        STR     r1, [r3, #MMUControlSoftCopy]
        MOV     r2, r1
        Pull    "r0,r3,r4,r5,pc"

; PPLTrans should contain L2_AP + L2_XN + L2_S + L2_SmallPage
; PCBTrans should contain L2_C + L2_B + L2_TEX

; In:
; r0 = phys addr (aligned)
; r1 = page flags:
;      APBits
;      NotBufferable
;      NotCacheable
;      CPBits
;      PageFlags_TempUncacheableBits
; r2 -> PPLTrans
; r3 -> PCBTrans
; Out:
; r0 = PTE for 4K page ("small page")
Get4KPTE ROUT
        Entry   "r4"
        AND     lr, r1, #DynAreaFlags_APBits
        MOV     lr, lr, LSL #1
        LDRH    lr, [r2, lr]
        ; Insert AP bits, page type/size, etc.
        ORR     r0, r0, lr
        ; Insert CB+TEX bits
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        TST     r1, #PageFlags_TempUncacheableBits
        AND     r4, r1, #DynAreaFlags_NotCacheable + DynAreaFlags_NotBufferable
        AND     lr, r1, #DynAreaFlags_CPBits
        ORRNE   r4, r4, #XCB_TU<<4                      ; if temp uncache, set TU bit
        ORR     r4, r4, lr, LSR #10-4
        MOV     r4, r4, LSR #3
        LDRH    r4, [r3, r4]                            ; convert to TEX, C and B bits for this CPU
        ORR     r0, r0, r4
        EXIT

; In:
; As per Get4KPTE
; Out:
; r0 = PTE for 64K page ("large page")
Get64KPTE ROUT
        Entry   "r4"
        AND     lr, r1, #DynAreaFlags_APBits
        MOV     lr, lr, LSL #1
        LDRH    lr, [r2, lr]
        ; Remap XN bit, page type
        AND     r4, lr, #L2_XN
        BIC     lr, lr, #3
        ORR     r0, r0, #L2_LargePage
        ASSERT  L2L_XN = L2_XN :SHL: 15
        ORR     r0, r0, r4, LSL #15
        ; Insert AP, S bits
        ORR     r0, r0, lr
50
        ; Insert CB+TEX bits
        ; Shared with Get1MPTE
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        TST     r1, #PageFlags_TempUncacheableBits
        AND     r4, r1, #DynAreaFlags_NotCacheable + DynAreaFlags_NotBufferable
        AND     lr, r1, #DynAreaFlags_CPBits
        ORRNE   r4, r4, #XCB_TU<<4                      ; if temp uncache, set TU bit
        ORR     r4, r4, lr, LSR #10-4
        MOV     r4, r4, LSR #3
        LDRH    r4, [r3, r4]                            ; convert to TEX, C and B bits for this CPU
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
        MOV     lr, lr, LSL #1
        LDRH    lr, [r2, lr]
        ; Remap XN bit, page type
        AND     r4, lr, #L2_XN
        AND     lr, lr, #L2_AP + L2_S
        ORR     r0, r0, #L1_Section
        ASSERT  L1_XN = L2_XN :SHL: 4
        ORR     r0, r0, r4, LSL #4
        ; Insert AP, S bits
        ASSERT  L1_APShift-L2_APShift=6
        ASSERT  L1_S = L2_S :SHL: 6
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
        TST     r0, #3
        MOVEQ   r1, #-1
        MOVEQ   pc, lr
        Entry   "r3-r5"
        ; Find entry in PPL table
        LDR     r3, =ZeroPage
        LDR     r2, =L2_AP+L2_XN ; L2_S ignored, pages should either be all shareable or all not shareable
        LDR     r3, [r3, #MMU_PPLTrans]
        AND     r4, r2, r0
        ; Get XN
        ASSERT  L2_XN = 1
        ASSERT  L2_SmallPage = 2
        ASSERT  L2_LargePage = 1
        TST     r0, #L2_SmallPage ; EQ if LargePage
        TSTEQ   r0, #L2L_XN
        BICEQ   r4, r4, #L2_XN ; Large page with no XN, so clear the fake XN flag we picked up earlier
        MOV     r1, #0
10
        LDRH    r5, [r3, r1]
        AND     r5, r5, r2
        CMP     r5, r4
        ADDNE   r1, r1, #2
        BNE     %BT10
        ; Remap TEX+CB so that they're in the same position as a small page entry
        TST     r0, #L2_SmallPage ; EQ if LargePage
        MOV     r4, #L2_C+L2_B
        ORRNE   r4, r4, #L2_TEX
        AND     r4, r0, r4
        ANDEQ   lr, r0, #L2L_TEX
        ORREQ   r4, r4, lr, LSR #L2L_TEXShift-L2_TEXShift
        ; Align phys addr to page size and set up R2
        MOV     r0, r0, LSR #12
        BICEQ   r0, r0, #15
        MOV     r0, r0, LSL #12
        MOVEQ   r2, #65536
        MOVNE   r2, #4096
20
        ; Search through PCBTrans for a match on TEX+CB (shared with L1 decoding)
        ; Funny order is used so that NCNB is preferred over other variants (since NCNB is common fallback)
        LDR     r3, =ZeroPage
        MOV     r1, r1, LSR #1
        LDR     r3, [r3, #MMU_PCBTrans]
        MOV     lr, #3*2
30
        LDRH    r5, [r3, lr]
        CMP     r5, r4
        BEQ     %FT40
        TST     lr, #2_11*2
        SUBNE   lr, lr, #1*2                    ; loop goes 3,2,1,0,7,6,5,4,...,31,30,29,28
        ADDEQ   lr, lr, #7*2
        TEQ     lr, #35*2
        BNE     %BT30                           ; Give up if end of table reached
40
        ; Decode index back into page flags
        ; n.b. temp uncache is ignored (no way we can differentiate between real uncached)
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        AND     r4, lr, #(XCB_NC+XCB_NB)*2
        AND     lr, lr, #7*XCB_P*2
        ORR     r1, r1, r4, LSL #4-1
        ORR     r1, r1, lr, LSL #10-1
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
        ; Find entry in PPL table
        LDR     r3, =ZeroPage
        LDR     lr, =L2_AP
        LDR     r3, [r3, #MMU_PPLTrans]
        ASSERT  L1_APShift = L2_APShift+6
        AND     r4, lr, r0, LSR #6
        TST     r0, #L1_XN
        ORRNE   r4, r4, #L2_XN
        ORR     lr, lr, #L2_XN
        MOV     r1, #0
60
        LDRH    r5, [r3, r1]
        AND     r5, r5, lr
        CMP     r5, r4
        ADDNE   r1, r1, #2
        BNE     %BT60
        ; Remap TEX+CB so that they're in the same position as a small page entry
        ASSERT  L1_C = L2_C
        ASSERT  L1_B = L2_B
        AND     r4, r0, #L1_C+L1_B
        AND     lr, r0, #L1_TEX
        ORR     r4, r4, lr, LSR #L1_TEXShift-L2_TEXShift
        ; Align phys addr to page size
        MOV     r0, r0, LSR #20
        MOV     r0, r0, LSL #20
        ; Now search through PCBTrans for a match
        B       %BT20

; In:
; r0 = phys addr (aligned)
; r1 -> ZeroPage
; Out:
; TTBR0 and any other related registers updated
; If MMU is currently on, it's assumed the mapping of ROM+stack will not be
; affected by this change
SetTTBR ROUT
        Entry   "r0,r2-r3"
        ; Do static setup of some registers
        MOV     lr, #0
        MCR     p15, 0, lr, c2, c0, 2           ; TTBCR: Ensure only TTBR0 is used
        ; Check if security extensions are supported
        ARM_read_ID r2
        AND     r2, r2, #&F<<16
        CMP     r2, #ARMvF<<16
        BNE     %FT01
        MRC     p15, 0, r2, c0, c1, 1           ; ID_PFR1
        TST     r2, #15<<4
        BEQ     %FT01
        MCR     p15, 0, lr, c12, c0, 0          ; VBAR: Ensure exception vector base is 0 (security extensions)
01
        ; Now update TTBR0
        ; If we're using shareable pages, set the appropriate flag in the TTBR to let the CPU know the page tables themselves are shareable
        LDR     lr, [r1, #MMU_PPLTrans]
        LDRH    lr, [lr]
        TST     lr, #L2_S
        ORRNE   r0, r0, #2
        ; Deal with specifying the cache policy
        ; First get the XCBTable entry that corresponds to the page flags
        ; n.b. temp uncacheability is ignored here
        LDR     lr, [r1, #PageTable_PageFlags]
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        AND     r2, lr, #DynAreaFlags_NotCacheable + DynAreaFlags_NotBufferable
        AND     lr, lr, #DynAreaFlags_CPBits
        LDR     r3, [r1, #MMU_PCBTrans]
        ORR     r2, r2, lr, LSR #10-4
        MOV     r2, r2, LSR #3
        LDRH    r2, [r3, r2]                    ; convert to C, B and TEX bits for this CPU
        ; Now decode the inner & outer cacheability specified in these flags
        TST     r2, #4:SHL:L2_TEXShift
        BEQ     %FT50                           ; Not Normal memory, or not using expected flag encodings, so leave as NC
        AND     r3, r2, #3:SHL:L2_TEXShift      ; Get outer cacheability ...
        ASSERT  L2_TEXShift > 3
        ORR     r0, r0, r3, LSR #L2_TEXShift-3  ; ... put in bits 3 & 4
        ; For inner cacheability, the TTBR format is different depending on
        ; whether the multiprocessing extensions are implemented
        MRC     p15, 0, lr, c0, c0, 1           ; Cache type register
        TST     lr, #1<<31                      ; EQ = ARMv6, NE = ARMv7+
        MRCNE   p15, 0, lr, c0, c0, 5           ; MPIDR
        TSTNE   lr, #1<<31                      ; NE = MP extensions present
        BEQ     %FT20
        ; MP extensions present
        TST     r2, #L2_B                       ; Inner cacheability bit 0 ...
        ORRNE   r0, r0, #1:SHL:6                ; ... goes in IRGN[0]
        TST     r2, #L2_C                       ; Inner cacheability bit 1 ...
        ORRNE   r0, r0, #1                      ; ... goes in IRGN[1]
        B       %FT50
20
        ; MP extensions not present
        ASSERT  VMSAv6_Cache_NC = 0
        TST     r2, #L2_B+L2_C
        ORRNE   r0, r0, #1                      ; Set C bit if any type of inner cacheable
50
        ARM_MMU_transbase r0
        EXIT

 [ CacheablePageTables
; Out: R0 = desired page flags for the page tables
GetPageFlagsForCacheablePageTables ROUT
        ; The ID_MMFR3 register indicates whether the MMU can read from the L1
        ; data cache.
        ; If it can, it means we can use an inner & outer write-back policy.
        ; If it can't, it means the best we can do is inner write-through and
        ; outer write-back (without performing extra cache maintenance, at
        ; least)
        ARM_read_ID r0
        AND     r0, r0, #&F<<16
        CMP     r0, #ARMvF<<16                  ; Check that feature registers are implemented
        BNE     %FT90
        MRC     p15, 0, r0, c0, c1, 7           ; ID_MMFR3
        TST     r0, #&F<<20
        BEQ     %FT90
        ; MMU can read from the L1 cache, so go for default cache policy
        LDR     r0, =AreaFlags_PageTablesAccess
        MOV     pc, lr
90
        ; MMU can't read from the L1 cache, so use inner write-through, outer write-back
        LDR     r0, =AreaFlags_PageTablesAccess :OR: (CP_CB_AlternativeDCache :SHL: DynAreaFlags_CPShift)
        MOV     pc, lr
 ]

        END
