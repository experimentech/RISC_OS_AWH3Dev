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
; > MemInfo

        LTORG

;----------------------------------------------------------------------------------------
; MemorySWI
;
;       In:     r0 = reason code and flags
;                       bits 0-7  = reason code
;                       bits 3-31 = reason specific flags
;       Out:    specific to reason codes
;
;       Perform miscellaneous operations for memory management.
;
MemorySWI       ROUT
        Push    lr                              ; Save real return address.
        AND     lr, r0, #&FF                    ; Get reason code.
        CMP     lr, #(%40-%30):SHR:2            ; If valid reason code then
        ADDCC   lr, lr, #(%30-%10):SHR:2        ;   determine where to jump to in branch table,
        ADDCC   lr, pc, lr, LSL #2
        Push    lr, CC                          ;   save address so we can
10
        ADRCC   lr, MemReturn                   ;   set up default return address for handler routines
        Pull    pc, CC                          ;   and jump into branch table.
20
        ADRL    r0, ErrorBlock_HeapBadReason    ; Otherwise, unknown reason code.
        SETV
        ; Drop through to...

MemReturn
 [ International
        BLVS    TranslateError
 ]
        Pull    lr                              ; Get back real return address.
        BVS     SLVK_SetV
        ExitSWIHandler

30
        B       MemoryConvertFIQCheck           ; 0
        B       %BT20                           ; Reason codes 1-5 are reserved.
        B       %BT20
        B       %BT20
        B       %BT20
        B       %BT20
        B       MemoryPhysSize                  ; 6
        B       MemoryReadPhys                  ; 7
        B       MemoryAmounts                   ; 8
        B       MemoryIOSpace                   ; 9
        B       %BT20                           ; Reason code 10 reserved (for free pool locking)
        B       %BT20                           ; Reason code 11 reserved (for PCImapping).
        B       RecommendPage                   ; 12
        B       MapIOpermanent                  ; 13
        B       AccessPhysAddr                  ; 14
        B       ReleasePhysAddr                 ; 15
        B       MemoryAreaInfo                  ; 16
        B       MemoryAccessPrivileges          ; 17
        B       FindAccessPrivilege             ; 18
        B       %BT20                           ; Reason code 19 reserved (for DMAPrep, on SMP branch)
        B       ChangeCompatibility             ; 20
        B       %BT20                           ; 21 |
        B       %BT20                           ; 22 | Reserved for us
        B       %BT20                           ; 23 |
        B       CheckMemoryAccess               ; 24
                                                ; 25+ reserved for ROL
40


;----------------------------------------------------------------------------------------
; MemoryConvert
;
;       In:     r0 = flags
;                       bit     meaning
;                       0-7     0 (reason code)
;                       8       page number provided when set
;                       9       logical address provided when set
;                       10      physical address provided when set
;                       11      fill in page number when set
;                       12      fill in logical address when set
;                       13      fill in physical address when set
;                       14-15   0,1=don't change cacheability
;                               2=disable caching on these pages
;                               3=enable caching on these pages
;                       16-31   reserved (set to 0)
;               r1 -> page block
;               r2 = number of 3 word entries in page block
;
;       Out:    r1 -> updated page block
;
;       Converts between representations of memory addresses. Can also set the
;       cacheability of the specified pages.
;

; Declare symbols used for decoding flags (given and wanted are used
; so that C can be cleared by rotates of the form a,b). We have to munge
; the flags a bit to make the rotates even.
;
ppn             *       1:SHL:0         ; Bits for address formats.
logical         *       1:SHL:1
physical        *       1:SHL:2
all             *       ppn :OR: logical :OR: physical
given           *       24              ; Rotate for given fields.
wanted          *       20              ; Rotate for wanted fields.
ppn_bits        *       ((ppn :SHL: 4) :OR: ppn)
logical_bits    *       ((logical :SHL: 4) :OR: logical)
physical_bits   *       ((physical :SHL: 4) :OR: physical)
cacheable_bit   *       1:SHL:15
alter_cacheable *       1:SHL:16

; Small wrapper to make sure FIQs are disabled if we're making pages uncacheable
; (Modern ARMs ignore unexpected cache hits, so big coherency issues if we make
; a page uncacheable which is being used by FIQ).
MemoryConvertFIQCheck ROUT
        AND     r11, r0, #3:SHL:14
        TEQ     r11, #2:SHL:14
        BNE     MemoryConvertNoFIQCheck
        Entry   "r0-r1"
        MOV     r1, #Service_ClaimFIQ
        SWI     XOS_ServiceCall
        LDMIA   sp, {r0-r1}
        BL      MemoryConvertNoFIQCheck
        FRAMSTR r0
        MRS     r11, CPSR
        MOV     r1, #Service_ReleaseFIQ
        SWI     XOS_ServiceCall
        MSR     CPSR_c, r11
        EXIT

MemoryConvertNoFIQCheck   ROUT
        Entry   "r0-r11"                ; Need lots of registers!!

;        MRS     lr, CPSR
;        Push    "lr"
;        ORR     lr, lr, #I32_bit+F32_bit
;        MSR     CPSR_c, lr

        BIC     lr, r0, #all,given      ; Need to munge r0 to get rotates to work (must be even).
        AND     r0, r0, #all,given
        ORR     r0, r0, lr, LSL #1      ; Move bits 11-30 to 12-31.

        TST     r0, #all,given          ; Check for invalid argument (no fields provided)
        TEQNE   r2, #0                  ;   (no entries in table).
        ADREQL  r0, ErrorBlock_BadParameters
        BEQ     %FT95

        EOR     lr, r0, r0, LSL #given-wanted   ; If flag bits 8-10 and 12-14 contain common bits then
        AND     lr, lr, #all,wanted             ;   clear bits in 12-14 (ie. don't fill in fields already given).
        EOR     lr, lr, #all,wanted
        BIC     r0, r0, lr

        LDR     r6, =ZeroPage
        LDR     r7, [r6, #MaxCamEntry]
        LDR     r6, [r6, #CamEntriesPointer]
        LDR     r8, =L2PT
10
        SUBS    r2, r2, #1
        BCC     %FT70

        LDMIA   r1!, {r3-r5}            ; Get next three word entry (PN,LA,PA) and move on pointer.

   [ AMB_LazyMapIn
        BL      handle_AMBHonesty       ; may need to make page honest (as if not lazily mapped)
   ]

        TST     r0, #physical,wanted    ; If PA not wanted
        BEQ     %FT20                   ;   then skip.
        TST     r0, #logical,given      ; If LA given (rotate clears C) then
        ADR     lr, %FT15
        BNE     logical_to_physical     ; Get PA from LA
        BL      ppn_to_logical          ; Else get LA from PN (PA wanted (not given) & LA not given => PN given).
        BLCC    ppn_to_physical         ; And get PA from PN (more accurate than getting PA from LA - page may be mapped out)
15
        BCS     %FT80
        TST     r0, #logical,wanted
        STRNE   r4, [r1, #-8]           ; Store back LA if wanted.
        STR     r5, [r1, #-4]           ; Store back PA.
20
        TST     r0, #alter_cacheable    ; If altering cacheability
        EORNE   lr, r0, #ppn,given      ;   and PN not given
        TSTNE   lr, #ppn,given
        TSTEQ   r0, #ppn,wanted         ;   OR PN wanted then don't skip
        BEQ     %FT30                   ; else skip.
        TST     r0, #physical_bits,given        ; If PA not given and PA not wanted (rotate clears C) then
        BLEQ    logical_to_physical             ;   get it from LA (PN wanted/not given & PA not given => LA given).
        BLCC    physical_to_ppn         ; Get PN from PA.
        BCS     %FT80
        TST     r0, #ppn,wanted
        STRNE   r3, [r1, #-12]          ; Store back PN if wanted.
30
        TST     r0, #logical,wanted     ; If LA wanted
        EORNE   lr, r0, #physical,wanted
        TSTNE   lr, #physical,wanted    ;   and PA not wanted then don't skip
        BEQ     %FT40                   ; else skip.
        TST     r0, #alter_cacheable    ; If not changing cacheability (already have PN)
        TSTEQ   r0, #ppn_bits,given     ;   and PN not given and PN not wanted (rotate clears C) then
        BLEQ    physical_to_ppn         ;   get it from PA (LA wanted (not given) & PN not given => PA given).
        BLCC    ppn_to_logical          ; Get LA from PN.
        BCS     %FT80
        STR     r4, [r1, #-8]           ; Store back LA.
40
        TST     r0, #alter_cacheable
        BEQ     %BT10

        CMP     r7, r3                  ; Make sure page number is valid (might not have done any conversion).
        BCC     %FT80

        ADD     r3, r6, r3, LSL #CAM_EntrySizeLog2 ; Point to CAM entry for this page.
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        LDMIA   r3, {r4,r5}             ; Get logical address and PPL.

        AND     lr, r5, #PageFlags_TempUncacheableBits
        TST     r0, #cacheable_bit
        BNE     %FT50

        TEQ     lr, #PageFlags_TempUncacheableBits      ; Make uncacheable (increment count).
        BEQ     %BT10                                   ; If count has reached max then go no further (should not happen).
        TEQ     lr, #0                                  ; EQ => we have to change L2.
        ADD     r5, r5, #1:SHL:TempUncacheableShift
        B       %FT60
50
        TEQ     lr, #0                                  ; Make cacheable (decrement count).
        BEQ     %BT10                                   ; If count is already 0 then go no further (page already cacheable).
        SUB     r5, r5, #1:SHL:TempUncacheableShift
        TST     r5, #PageFlags_TempUncacheableBits      ; EQ => we have to change L2.
60
        STR     r5, [r3, #CAM_PageFlags] ; Write back new PPL.
        BNE     %BT10                   ; Do next entry if we don't have to change L2.

        MOV     r4, r4, LSR #12
        LDR     r3, =ZeroPage
        ADD     r4, r8, r4, LSL #2      ; Address of L2 entry for logical address.
 [ MEMM_Type = "VMSAv6"
        ; VMSAv6 is hard, use XCBTable/PCBTrans
        ASSERT  DynAreaFlags_CPBits = 7*XCB_P :SHL: 10
        ASSERT  DynAreaFlags_NotCacheable = XCB_NC :SHL: 4
        ASSERT  DynAreaFlags_NotBufferable = XCB_NB :SHL: 4
        TST     r0, #cacheable_bit      ; n.b. must match EQ/NE used by ARMop calls
        AND     lr, r5, #DynAreaFlags_NotCacheable + DynAreaFlags_NotBufferable
        AND     r5, r5, #DynAreaFlags_CPBits
        ORR     lr, lr, r5, LSR #10-4
        LDR     r5, [r3, #MMU_PCBTrans]
        ORREQ   lr, lr, #XCB_TU<<4      ; if temp uncache, set TU bit
        MOV     lr, lr, LSR #3
        LDRH    lr, [r5, lr]            ; convert to C, B and TEX bits for this CPU
        LDR     r5, [r4]                ; Get L2 entry (safe as we know address is valid).
        BIC     r5, r5, #TempUncache_L2PTMask ; Knock out existing attributes (n.b. assumed to not be large page!)
        ORR     r5, r5, lr              ; Set new attributes
 |
        LDR     r5, [r4]                ; Get L2 entry (safe as we know address is valid).
        TST     r0, #cacheable_bit
        BICEQ   r5, r5, #L2_C           ; Disable/enable cacheability.
        ORRNE   r5, r5, #L2_C
 ]
        BNE     %FT63
        ; Making page non-cacheable
        ; There's a potential interrupt hole here - many ARMs ignore cache hits
        ; for pages which are marked as non-cacheable (seen on XScale,
        ; Cortex-A53, Cortex-A15 to name but a few, and documented in many TRMs)
        ; We can't be certain that this page isn't being used by an interrupt
        ; handler, so if we're making it non-cacheable we have to take the safe
        ; route of disabling interrupts around the operation.
        ; Note - currently no consideration is given to FIQ handlers.
        ; Note - we clean the cache as the last step (as opposed to doing it at
        ; the start) to make sure prefetching doesn't pull data back into the
        ; cache.
        MRS     r11, CPSR
        ORR     lr, r11, #I32_bit       ; IRQs off
        ; Yuck, we also need to deal with the case where we're making the
        ; current SVC stack page uncacheable (coherency issue when calling the
        ; ARMops if cache hits to uncacheable pages are ignored). Deal with this
        ; by temporarily dropping into IRQ mode (and thus a different stack) if
        ; we think this is going to happen.
        MOV     r10, r4, LSL #10
        SUB     r10, sp, r10
        CMP     r10, #8192              ; Be extra cautious
        EORLO   lr, lr, #SVC32_mode :EOR: IRQ32_mode
        MSR     CPSR_c, lr              ; Switch mode
        Push    "r0, lr"                ; Preserve OS_Memory flags and (potential) IRQ lr
        STR     r5, [r4]                ; Write back new L2 entry.
        ASSERT  (L2PT :SHL: 10) = 0     ; Ensure we can convert r4 back to the page log addr
        MOV     r0, r4, LSL #10
        ARMop   MMU_ChangingEntry,,,r3  ; Clean TLB+cache
        Pull    "r5, lr"                ; Restore OS_Memory flags + IRQ lr
        MSR     CPSR_c, r11             ; Back to original mode + IRQ state
        B       %FT65
63
        ; Making page cacheable again
        ; Shouldn't be any cache maintenance worries
        STR     r5, [r4]                ; Write back new L2 entry.
        MOV     r5, r0
        ASSERT  (L2PT :SHL: 10) = 0     ; Ensure we can convert r4 back to the page log addr
        MOV     r0, r4, LSL #10
        ARMop   MMU_ChangingUncachedEntry,,,r3   ; Clean TLB
65
        MOV     r0, r5
        B       %BT10

70
        CLRV
        EXIT

80
        TST     r0, #alter_cacheable    ; If we haven't changed any cacheability stuff then
        BEQ     %FT90                   ;   just return error.

        AND     lr, r0, #all,wanted             ; Get wanted flags.
        LDMIA   sp, {r0,r1,r3}                  ; Get back original flags, pointer and count.
        ORR     r0, r0, lr, LSR #given-wanted   ; Wanted fields are now also given as we have done the conversion.
        BIC     r0, r0, #all:SHL:11             ; Clear wanted flags, we only want to change cacheability.
        EOR     r0, r0, #cacheable_bit          ; If we made them uncacheable then make them cacheable again & v.v.
        SUB     r2, r3, r2
        SUBS    r2, r2, #1              ; Change back the entries we have changed up to (but excluding) the error entry.
        BLNE    MemoryConvertNoFIQCheck
90
        ADRL    r0, ErrorBlock_BadAddress
95
        STR     r0, [sp, #Proc_RegOffset+0]
        SETV
        EXIT

   [ AMB_LazyMapIn
;
;  entry: r3,r4,r5 = provided PN,LA,PA triple for entry to make honest (at least one given)
;         r0 bits flag which of PN,LA,PA are given
;  exit:  mapping made honest (as if not lazily mapped) if necessary
handle_AMBHonesty  ROUT
        Push    "r0, r3-r5, lr"
        TST     r0, #logical,given
        BEQ     %FT10
        MOV     r0, r4
        BL      AMB_MakeHonestLA
        B       %FT90
10
        TST     r0, #ppn,given
        BEQ     %FT20
15
        MOV     r0, r3
        BL      AMB_MakeHonestPN
        B       %FT90
20
        TST     r0, #physical,given
        BEQ     %FT90
        Push    "r7, r9-r11"
        LDR     r14, =ZeroPage
        LDR     r7, [r14, #MaxCamEntry]
        BL      physical_to_ppn
        Pull    "r7, r9-r11"
        BCC     %BT15
90
        Pull    "r0, r3-r5, pc"

   ] ;AMB_LazyMapIn


;----------------------------------------------------------------------------------------
; ppn_to_logical
;
;       In:     r3 = page number
;               r5 = physical address if given
;               r6 = CamEntriesPointer
;               r7 = MaxCamEntry
;
;       Out:    r9 corrupted
;               CC => r4 = logical address
;               CS => invalid page number
;
;       Convert physical page number to logical address.
;
ppn_to_logical
        CMP     r7, r3                  ; Validate page number.
        BCC     meminfo_returncs        ; Invalid so return C set.

        ASSERT  CAM_LogAddr=0
        LDR     r4, [r6, r3, LSL #CAM_EntrySizeLog2] ; If valid then lookup logical address.
        TST     r0, #physical,given     ; If physical address was given then
        LDRNE   r9, =&FFF
        ANDNE   r9, r5, r9              ;   mask off page offset
        ORRNE   r4, r4, r9              ;   and combine with logical address.
        CLC
        MOV     pc, lr


;----------------------------------------------------------------------------------------
; logical_to_physical
;
;       In:     r4 = logical address
;               r8 = L2PT
;
;       Out:    r9 corrupted
;               CC => r5 = physical address
;               CS => invalid logical address, r5 corrupted
;
;       Convert logical address to physical address.
;
logical_to_physical
        MOV     r9, r4, LSR #12         ; r9 = logical page number
        ADD     r9, r8, r9, LSL #2      ; r9 -> L2PT entry for logical address
        MOV     r5, r9, LSR #12         ; r5 = page offset to L2PT entry for logical address
        LDR     r5, [r8, r5, LSL #2]    ; r5 = L2PT entry for L2PT entry for logical address
      [ MEMM_Type = "ARM600"
        ASSERT  ((L2_SmallPage :OR: L2_ExtPage) :AND: 2) <> 0
        ASSERT  (L2_LargePage :AND: 2) = 0
      |
        ASSERT  L2_SmallPage = 2
        ASSERT  L2_XN = 1               ; Because XN is bit 0, bit 1 is the only bit we can check when looking for small pages
      ]
        TST     r5, #2                  ; Check for valid (4K) page.
        BEQ     meminfo_returncs

        LDR     r5, [r9]                ; r5 = L2PT entry for logical address
        TST     r5, #2                  ; Check for valid (4K) page.
        BEQ     meminfo_returncs

        LDR     r9, =&FFF               ; Valid so
        BIC     r5, r5, r9              ;   mask off bits 0-11,
        AND     r9, r4, r9              ;   get page offset from logical page
        ORR     r5, r5, r9              ;   combine with physical page address.
        CLC
        MOV     pc, lr

meminfo_returncs_pullr5
        Pull    "r5"
meminfo_returncs
        SEC
        MOV     pc, lr

;----------------------------------------------------------------------------------------
; physical_to_ppn
;
;       In:     r5 = physical address
;               r7 = MaxCamEntry
;
;       Out:    r9-r11 corrupted
;               CC => r3 = page number
;               CS => invalid physical address, r3 corrupted
;
;       Convert physical address to physical page number.
;
physical_to_ppn ROUT
        Push    "r5"
        LDR     r9, =ZeroPage+PhysRamTable
        MOV     r3, #0                  ; Start at page 0.
        MOV     r5, r5, LSR #12
10
        CMP     r7, r3                  ; Stop if we run out of pages
        BCC     meminfo_returncs_pullr5

        LDMIA   r9!, {r10,r11}          ; Get start address and size of next block.
        SUB     r10, r5, r10, LSR #12   ; Determine if given address is in this block.
        CMP     r10, r11, LSR #12
        ADDCS   r3, r3, r11, LSR #12    ; Move on to next block.
        BCS     %BT10

        Pull    "r5"

        ADD     r3, r3, r10
        CLC
        MOV     pc, lr

;----------------------------------------------------------------------------------------
; ppn_to_physical
;
;       In:     r3 = page number
;
;       Out:    r9 corrupted
;               CC => r5 = physical address
;               CS => invalid page number, r5 corrupted
;
;       Convert physical page number to physical address.
;
ppn_to_physical ROUT
        Push    "r3,lr"
        LDR     r9, =ZeroPage+PhysRamTable
10
        LDMIA   r9!, {r5,lr}            ; Get start address and size of next block.
        MOVS    lr, lr, LSR #12
        BEQ     %FT20
        CMP     r3, lr
        SUBHS   r3, r3, lr
        BHS     %BT10

        ADD     r5, r5, r3, LSL #12
        Pull    "r3,pc"
20
        SEC
        Pull    "r3,pc"


;----------------------------------------------------------------------------------------
; Symbols used in MemoryPhysSize and MemoryReadPhys
;

; Shifts to determine number of bytes/words to allocate in table.
BitShift        *       10
ByteShift       *       BitShift + 3
WordShift       *       ByteShift + 2

; Bit patterns for different types of memory.
NotPresent      *       &00000000
DRAM_Pattern    *       &11111111
VRAM_Pattern    *       &22222222
ROM_Pattern     *       &33333333
IO_Pattern      *       &44444444
NotAvailable    *       &88888888


;----------------------------------------------------------------------------------------
; MemoryPhysSize
;
;       In:     r0 = 6 (reason code with flag bits 8-31 clear)
;
;       Out:    r1 = table size (in bytes)
;               r2 = page size (in bytes)
;
;       Returns information about the memory arrangement table.
;
MemoryPhysSize
        Entry   "r0-r1,r3,sb,ip"
        AddressHAL
        MOV     r0, #PhysInfo_GetTableSize
        ADD     r1, sp, #4
        CallHAL HAL_PhysInfo
        MOV     r2, #4*1024
        CLRV
        EXIT


;----------------------------------------------------------------------------------------
; MemoryReadPhys
;
;       In:     r0 = 7 (reason code with flag bits 8-31 clear)
;               r1 -> memory arrangement table to be filled in
;
;       Out:    r1 -> filled in memory arrangement table
;
;       Returns the physical memory arrangement table in the given block.
;
MemoryReadPhys  ROUT

        Entry   "r0-r12"
        AddressHAL
        MOV     r0, #PhysInfo_WriteTable
        SUB     sp, sp, #8
        MOV     r2, sp
        CallHAL HAL_PhysInfo            ; fills in everything except DRAM
        LDR     r0, [sp], #4
        LDR     r11, [sp], #4

        ; r0 to r11 is DRAM or not present.
        LDR     r1, [sp, #4]            ; Get table address back
        ADD     r1, r1, r0, LSR #ByteShift
        MOV     r2, r0                  ; Current physical address.
        MOV     r3, #0                  ; Next word to store in table.
        MOV     r4, #32                 ; How much more we have to shift r3 before storing it.
        LDR     r6, =ZeroPage+CamEntriesPointer
        LDR     r7, [r6]
        ADD     r7, r7, #CAM_PageFlags  ; Point to PPL entries.
        LDR     r8, [r6, #MaxCamEntry-CamEntriesPointer]
        MOV     r5, #0                  ; last block address processed + 1
        Push    "r5"

        ; Ugly logic to process PhysRamTable entries in address order instead of physical page order
10
        Pull    "r12"
        MVN     lr, #0
        MOV     r5, #0                  ; Current page number.
        Push    "r5,lr"
        LDR     r6, =ZeroPage+PhysRamTable
        MOV     r10, #0
11
        ADD     r5, r5, r10, LSR #12
        LDMIA   r6!, {r9,r10}           ; Get physical address and size of next block.
        CMP     r10, #0
        BEQ     %FT12

        CMP     r9, r0                  ; If not DRAM then
        CMPHS   r11, r9
        BLO     %BT11                   ; try next block.

        CMP     r9, r12                 ; have we processed this entry?
        CMPHS   lr, r9                  ; is it the lowest one we've seen?
        BLO     %BT11                   ; yes, try the next
        ; This is the best match so far
        STMIA   sp, {r5,r6}             ; Remember page number & details ptr
        MOV     lr, r9                  ; Remember base address
        B       %BT11
12
        Pull    "r5,r6"
        CMP     r6, #-1                 ; did we find anything?
        BEQ     %FT40
        LDMDB   r6,{r9,r10}
        ADD     r12, r9, #1        
        Push    "r12"                   ; Remember that we've processed up to here

        ; Now process this entry
        MOV     r10, r10, LSR #12
        ADD     r10, r9, r10, LSL #12   ; Add amount of unused space between current and start of block.
        SUB     r10, r10, r2            ; size = size + (physaddr - current)
20
        SUBS    r4, r4, #4              ; Reduce shift.
        MOVCS   r3, r3, LSR #4          ; If more space in current word then shift it.
        STRCC   r3, [r1], #4            ; Otherwise, store current word
        MOVCC   r3, #0                  ;   and start a new one.
        MOVCC   r4, #28

        CMP     r2, r9                  ; If not reached start of block then page is not present.
        ORRCC   r3, r3, #(NotPresent :OR: NotAvailable) :SHL: 28
        BCC     %FT30
        LDR     lr, [r7, r5, LSL #CAM_EntrySizeLog2] ; Page is there so get PPL and determine if it's available or not.
        TST     lr, #PageFlags_Unavailable
        ORREQ   r3, r3, #DRAM_Pattern :SHL: 28
        ORRNE   r3, r3, #(DRAM_Pattern :OR: NotAvailable) :SHL: 28
        ADD     r5, r5, #1              ; Increment page count.
30
        ADD     r2, r2, #&1000          ; Increase current address.
        SUBS    r10, r10, #&1000        ; Decrease size of block.
        BGT     %BT20                   ; Stop if no more block left.

        B       %BT10

40
        TEQ     r3, #0                          ; If not stored last word then
        MOVNE   r3, r3, LSR r4                  ;   put bits in correct position
        ADDNE   r2, r2, r4, LSL #BitShift       ;   adjust current address
        RSBNE   r4, r4, #32                     ;   rest of word is not present
        LDRNE   lr, =NotPresent :OR: NotAvailable
        ORRNE   r3, r3, lr, LSL r4
        STRNE   r3, [r1], #4                    ;   and store word.

        ; End of last block of DRAM to r11 is not present.
        MOV     r6, r0
        ADD     lr, r11, #1
        RSBS    r2, r2, lr
        MOVNE   r0, r1
        LDRNE   r1, =NotPresent :OR: NotAvailable
        MOVNE   r2, r2, LSR #ByteShift
        BLNE    memset

        ; If softloaded (ie ROM image is wholely within DRAM area returned
        ; by HAL_PhysInfo), mark that as unavailable DRAM.
        LDR     r0, =ZeroPage
        LDR     r0, [r0, #ROMPhysAddr]
        LDR     r1, [sp, #4]
        CMP     r0, r6
        ADDHS   lr, r0, #OSROM_ImageSize*1024
        SUBHS   lr, lr, #1
        CMPHS   r11, lr
        ADDHS   r0, r1, r0, LSR #ByteShift
        LDRHS   r1, =DRAM_Pattern :OR: NotAvailable
        MOVHS   r2, #(OSROM_ImageSize*1024) :SHR: ByteShift
        BLHS    memset

        CLRV
        EXIT


fill_words
        STR     r3, [r1], #4
        SUBS    r2, r2, #1
        BNE     fill_words
        MOV     pc, lr


;----------------------------------------------------------------------------------------
; MemoryAmounts
;
;       In:     r0 = flags
;                       bit     meaning
;                       0-7     8 (reason code)
;                       8-11    1=return amount of DRAM (excludes any soft ROM)
;                               2=return amount of VRAM
;                               3=return amount of ROM
;                               4=return amount of I/O space
;                               5=return amount of soft ROM (ROM loaded into hidden DRAM)
;                       12-31   reserved (set to 0)
;
;       Out:    r1 = number of pages of the specified type of memory
;               r2 = page size (in bytes)
;
;       Return the amount of the specified type of memory.
;
MemoryAmounts   ROUT
        Entry   "r3"

        BICS    lr, r0, #&FF            ; Get type of memory required (leave bits 12-31, non-zero => error).
        CMP     lr, #6:SHL:8
        ADDCC   pc, pc, lr, LSR #8-2
        NOP
        B       %FT99                   ; Don't understand 0 (so the spec says).
        B       %FT10                   ; DRAM
        B       %FT20                   ; VRAM
        B       %FT30                   ; ROM
        B       %FT40                   ; I/O
        B       %FT50                   ; Soft ROM

10
        LDR     r1, =ZeroPage
        LDR     r3, [r1, #VideoSizeFlags]
        TST     r3, #OSAddRAM_IsVRAM
        MOVNE   r3, r3, LSR #12         ; Extract size from flags when genuine VRAM
        MOVNE   r3, r3, LSL #12
        MOVEQ   r3, #0
        LDR     r1, [r1, #RAMLIMIT]
        SUB     r1, r1, r3              ; DRAM = RAMLIMIT - VRAMSize
        B       %FT97
20
        LDR     r1, =ZeroPage
        LDR     r1, [r1, #VideoSizeFlags]
        TST     r1, #OSAddRAM_IsVRAM
        MOVNE   r1, r1, LSR #12
        MOVNE   r1, r1, LSL #12         ; VRAM = VRAMSize
        MOVEQ   r1, #0
        B       %FT97
30
        Push    "r0, sb, ip"
        AddressHAL
        MOV     r0, #PhysInfo_HardROM
        SUB     sp, sp, #8
        MOV     r2, sp
        CallHAL HAL_PhysInfo
        LDMIA   sp!, {r0-r1}
        SUBS    r1, r1, r0
        ADDNE   r1, r1, #1              ; ROM = ROMPhysTop + 1 - ROMPhysBot
        Pull    "r0, sb, ip"
        B       %FT97
40
        LDR     r1, =ZeroPage
        LDR     r1, [r1, #IOAllocLimit]
        LDR     r3, =IO
        SUB     r1, r3, r1              ; IO = IO ceiling - IO floor
        B       %FT97
50
        Push    "r0"
        MOV     r0, #8
        SWI     XOS_ReadSysInfo         ; Are we softloaded?
        Pull    "r0"
        AND     r1, r1, r2
        ANDS    r1, r1, #1:SHL:4        ; Test OS-runs-from-RAM flag
        MOVNE   r1, #OSROM_ImageSize*1024
        B       %FT97
97
        MOV     r1, r1, LSR #12         ; Return as number of pages.
        MOV     r2, #4*1024             ; Return page size.
        CLRV
        EXIT
99
        PullEnv
        ; Fall through...
MemoryBadParameters
        ADRL    r0, ErrorBlock_BadParameters ; n.b. MemReturn handles internationalisation
        SETV
        MOV     pc, lr


;----------------------------------------------------------------------------------------
; MemoryIOSpace
;
;       In:     r0 = 9 (reason code with flag bits 8-31 clear)
;               r1 = controller ID
;                       bit     meaning
;                       0-7     controller sequence number
;                       8-31    controller type:
;                               0 = EASI card access speed control
;                               1 = EASI space(s)
;                               2 = VIDC1
;                               3 = VIDC20
;                               4 = S space (IOMD,podules,NICs,blah blah)
;                               5 = Extension ROM(s)
;                               6 = Tube ULA
;                               7-31 = Reserved (for us)
;                               32 = Primary ROM
;                               33 = IOMD
;                               34 = FDC37C665/SMC37C665/82C710/SuperIO/whatever
;                               35+ = Reserved (for ROL)
;
;       Out:    r1 = controller base address or 0 if not present
;
;       Return the location of the specified controller.
;

MemoryIOSpace   ROUT
        Entry   "r0,r2,r3,sb,ip"
        AddressHAL
        CallHAL HAL_ControllerAddress
        CMP     r0, #-1
        MOVNE   r1, r0
        PullEnv
        MOVNE   pc, lr
        B       MemoryBadParameters

;----------------------------------------------------------------------------------------
; MemoryFreePoolLock - removed now that free pool is a PMP

;----------------------------------------------------------------------------------------
;PCImapping - reserved for Acorn use (PCI manager)
;
; See code on Ursula branch


;----------------------------------------------------------------------------------------
;RecommendPage
;
;       In:     r0 bits 0..7  = 12 (reason code 12)
;               r0 bit 8 = 1 if region must be DMAable
;               r0 bits 9..31 = 0 (reserved flags)
;               r1 = size of physically contiguous RAM region required (bytes)
;               r2 = log2 of required alignment of base of region (eg. 12 = 4k, 20 = 1M)
;
;       Out:    r3 = page number of first page of recommended region that could be
;                    grown as specific pages by dynamic area handler (only guaranteed
;                    if grow is next page claiming operation)
;        - or error if not possible (eg too big, pages unavailable)
;
RecommendPage ROUT
        Push    "r0-r2,r4-r11,lr"
        CMP     r2,#30
        BHI     RP_failed         ;refuse to look for alignments above 1G
        ANDS    r11,r0,#1:SHL:8   ;convert flag into something usable in the loop
        MOVNE   r11,#OSAddRAM_NoDMA
;
        ADD     r1,r1,#&1000
        SUB     r1,r1,#1
        MOV     r1,r1,LSR #12
        MOVS    r1,r1,LSL #12     ;size rounded up to whole no. of pages
;
        CMP     r2,#12
        MOVLO   r2,#12            ;log2 alignment must be at least 12 (4k pages)
        MOV     r0,#1
        MOV     r4,r0,LSL r2      ;required alignment-1
;
        LDR     r0,=ZeroPage+PhysRamTable
        MOV     r3,#0            ;page number, starts at 0
        LDR     r5,=ZeroPage+CamEntriesPointer
        LDR     r5,[r5]
        ADD     r5,r5,#CAM_PageFlags ; [r5,<page no.>,LSL #3] addresses flags word in CAM
        LDMIA   r0!,{r7,r8}      ;address,size of video chunk (skip this one)
;
RP_nextchunk
        ADD     r3,r3,r8,LSR #12 ;page no. of first page of next chunk
        LDMIA   r0!,{r7,r8}      ;address,size of next physical chunk
        CMP     r8,#0
        BEQ     RP_failed
        TST     r8,r11           ;ignore non-DMA regions if bit 8 of R0 was set
        BNE     RP_nextchunk
;
        MOV     r8,r8,LSR #12
        ADD     r6,r7,r4
        MOV     r8,r8,LSL #12
        SUB     r6,r6,#1         ;round up
        MOV     r6,r6,LSR r2
        MOV     r6,r6,LSL r2
        SUB     r6,r6,r7         ;adjustment to first address of acceptable alignment
        CMP     r6,r8
        BHS     RP_nextchunk     ;negligible chunk
        ADD     r7,r3,r6,LSR #12 ;first page number of acceptable alignment
        SUB     r9,r8,r6         ;remaining size of chunk
;
;find first available page
RP_nextpage
        CMP     r9,r1
        BLO     RP_nextchunk
        LDR     r6,[r5,r7,LSL #CAM_EntrySizeLog2] ;page flags from CAM
        ;must not be marked Unavailable or Required
        TST     r6,#PageFlags_Unavailable :OR: PageFlags_Required
        BEQ     RP_checkotherpages
RP_nextpagecontinue
        CMP     r9,r4
        BLS     RP_nextchunk
        ADD     r7,r7,r4,LSR #12   ;next page of suitable alignment
        SUB     r9,r9,r4
        B       RP_nextpage
;
RP_checkotherpages
        ADD     r10,r7,r1,LSR #12
        SUB     r10,r10,#1         ;last page required
RP_checkotherpagesloop
        LDR     r6,[r5,r10,LSL #CAM_EntrySizeLog2] ;page flags from CAM
        TST     r6,#PageFlags_Unavailable :OR: PageFlags_Required
        BNE     RP_nextpagecontinue
        SUB     r10,r10,#1
        CMP     r10,r7
        BHI     RP_checkotherpagesloop
;
;success!
;
        MOV     r3,r7
        Pull    "r0-r2,r4-r11,pc"

RP_failed
        MOV     r3,#0
        ADR     r0,ErrorBlock_NoMemChunkAvailable
        SETV
        STR     r0,[sp]
        Pull    "r0-r2,r4-r11,pc"

        MakeErrorBlock NoMemChunkAvailable

;----------------------------------------------------------------------------------------
;MapIOpermanent - map IO space (if not already mapped) and return logical address
;
;       In:     r0 bits 0..7  = 13 (reason code 13)
;               r0 bit  8     = 1 to map bufferable space (0 is normal, non-bufferable)
;               r0 bit  9     = 1 to map cacheable space (0 is normal, non-cacheable)
;               r0 bits 10..12 = cache policy
;               r0 bits 13..15 = 0 (reserved flags)
;               r0 bit  16    = 1 to doubly map
;               r0 bit  17    = 1 if access privileges specified
;               r0 bits 18..23 = 0 (reserved flags)
;               r0 bits 24..27 = access privileges (if bit 17 set)
;               r0 bits 28..31 = 0 (reserved flags)
;               r1 = physical address of base of IO space required
;               r2 = size of IO space required (bytes)
;
;       Out:    r3 = logical address of base of IO space
;        - or error if not possible (no room)
;
MapIOpermanent ROUT
        Entry   "r0-r2,r12"
        ; Convert the input flags to some DA flags
        TST     r0, #1:SHL:17
        MOVEQ   r12, #2                 ; Default AP: SVC RW, USR none
        MOVNE   r12, r0, LSR #24        ; Else use given AP
        ANDNE   r12, r12, #DynAreaFlags_APBits
        AND     lr, r0, #&300
        EOR     lr, lr, #&300
        ASSERT  DynAreaFlags_NotBufferable = 1:SHL:4
        ASSERT  DynAreaFlags_NotCacheable = 1:SHL:5
        ORR     r12, r12, lr, LSR #4
        AND     lr, r0, #7:SHL:10
        ASSERT  DynAreaFlags_CPBits = 7:SHL:12
        ORR     r12, r12, lr, LSL #2
        ; Calculate the extra flags needed for RISCOS_MapInIO
        AND     r0, r0, #1:SHL:16
        ASSERT  MapInFlag_DoublyMapped = 1:SHL:20
        MOV     r0, r0, LSL #4
        ; Convert DA flags to page table entry
        GetPTE  r0, 1M, r0, r12
 [ MEMM_Type = "VMSAv6"
        ORR     r0, r0, #L1_XN          ; force non-executable to prevent speculative instruction fetches
 ]
        ; Map in the region
        BL      RISCOS_MapInIO_PTE
        MOV     r3, r0
        PullEnv
        CMP     r3, #0              ;MOV,CMP rather than MOVS to be sure to clear V
        ADREQ   r0, ErrorBlock_NoRoomForIO
        SETV    EQ
        MOV     pc, lr

        MakeErrorBlock NoRoomForIO

;----------------------------------------------------------------------------------------
;AccessPhysAddr - claim temporary access to given physical address (in fact,
;                 controls access to the 1Mb aligned space containing the address)
;                 The access remains until the next AccessPhysAddr or until a
;                 ReleasePhysAddr (although interrupts or subroutines may temporarily
;                 make their own claims, but restore on Release before returning)
;
;       In:     r0 bits 0..7  = 14 (reason code 14)
;               r0 bit  8     = 1 to map bufferable space, 0 for unbufferable
;               r0 bits 9..31 = 0 (reserved flags)
;               r1 = physical address
;
;       Out:    r2 = logical address corresponding to phys address r1
;               r3 = old state (for ReleasePhysAddr)
;
; Use of multiple accesses: it is fine to make several Access calls, and
; clean up with a single Release at the end. In this case, it is the old state
; (r3) of the *first* Access call that should be passed to Release in order to
; restore the state before any of your accesses. (The r3 values of the other
; access calls can be ignored.)
;
AccessPhysAddr ROUT
        Push    "r0,r1,r12,lr"
        TST     r0, #&100           ;test bufferable bit
        MOVNE   r0, #L1_B
        MOVEQ   r0, #0
        SUB     sp, sp, #4          ; word for old state
        MOV     r2, sp              ; pointer to word
        BL      RISCOS_AccessPhysicalAddress
        MOV     r2, r0
        Pull    r3                  ; old state
        Pull    "r0,r1,r12,pc"

;----------------------------------------------------------------------------------------
;ReleasePhysAddr - release temporary access that was claimed by AccessPhysAddr
;
;       In:     r0 bits 0..7  = 15 (reason code 15)
;               r0 bits 8..31 = 0 (reserved flags)
;               r1 = old state to restore
;
ReleasePhysAddr
        Push    "r0-r3,r12,lr"
        MOV     r0, r1
        BL      RISCOS_ReleasePhysicalAddress
        Pull    "r0-r3,r12,pc"

;----------------------------------------------------------------------------------------
;
;        In:    r0 = flags
;                       bit     meaning
;                       0-7     16 (reason code)
;                       8-15    1=cursor/system/sound
;                               2=IRQ stack
;                               3=SVC stack
;                               4=ABT stack
;                               5=UND stack
;                               6=Soft CAM
;                               7=Level 1 page tables
;                               8=Level 2 page tables
;                               9=HAL workspace
;                               10=Kernel buffers
;                               11=HAL uncacheable workspace
;                               12=Kernel 'ZeroPage' workspace
;                               13=Processor vectors
;                               14=DebuggerSpace
;                               15=Scratch space
;                               16=Compatibility page
;                       16-31   reserved (set to 0)
;
;       Out:    r1 = base of area
;               r2 = address space allocated for area (whole number of pages)
;               r3 = actual memory used by area (whole number of pages)
;               all values 0 if not present, or incorporated into another area
;
;       Return size of various low-level memory regions
MemoryAreaInfo ROUT
        Entry   "r0"
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        MOV     lr, r0, LSR #8
        AND     lr, lr, #&FF
        CMP     lr, #(MAI_TableEnd - MAI_TableStart)/4
        ADDLO   pc, pc, lr, LSL #2
        B       %FT70
MAI_TableStart
        B       %FT70
        B       MAI_CursSysSound
        B       MAI_IRQStk
        B       MAI_SVCStk
        B       MAI_ABTStk
        B       MAI_UNDStk
        B       MAI_SoftCAM
        B       MAI_L1PT
        B       MAI_L2PT
        B       MAI_HALWs
        B       MAI_Kbuffs
        B       MAI_HALWsNCNB
        B       MAI_ZeroPage
        B       MAI_ProcVecs
        B       MAI_DebuggerSpace
        B       MAI_ScratchSpace
        B       MAI_CompatibilityPage
MAI_TableEnd

70
        PullEnv
        B       MemoryBadParameters

MAI_CursSysSound
        LDR     r1, =CursorChunkAddress
        MOV     r2, #32*1024
        MOV     r3, r2
        EXIT

MAI_IRQStk
 [ IRQSTK < CursorChunkAddress :LOR: IRQSTK > CursorChunkAddress+32*1024
        LDR     r1, =IRQStackAddress
        MOV     r2, #IRQSTK-IRQStackAddress
        MOV     r3, r2
 ]
        EXIT

MAI_SVCStk
        LDR     r1, =SVCStackAddress
        MOV     r2, #SVCSTK-SVCStackAddress
        MOV     r3, r2
        EXIT

MAI_ABTStk
        LDR     r1, =ABTStackAddress
        MOV     r2, #ABTSTK-ABTStackAddress
        MOV     r3, r2
        EXIT

MAI_UNDStk
        LDR     r1, =UNDSTK :AND: &FFF00000
        LDR     r2, =UNDSTK :AND: &000FFFFF
        MOV     r3, r2
        EXIT

MAI_SoftCAM
        LDR     r0, =ZeroPage
        LDR     r1, [r0, #CamEntriesPointer]
        LDR     r2, =CAMspace
        LDR     r3, [r0, #SoftCamMapSize]
        EXIT

MAI_L1PT
        LDR     r1, =L1PT
        MOV     r2, #16*1024
        MOV     r3, r2
        EXIT

MAI_L2PT
        LDR     r0, =ZeroPage
        LDR     r1, =L2PT
        MOV     r2, #4*1024*1024
        LDR     r3, [r0, #L2PTUsed]
        EXIT

MAI_HALWs
        LDR     r0, =ZeroPage
        LDR     r1, =HALWorkspace
        MOV     r2, #HALWorkspaceSize
        LDR     r3, [r0, #HAL_WsSize]
        EXIT

MAI_HALWsNCNB
        LDR     r0, =ZeroPage
        LDR     r1, =HALWorkspaceNCNB
        MOV     r2, #32*1024
        LDR     r3, [r0, #HAL_Descriptor]
        LDR     r3, [r3, #HALDesc_Flags]
        ANDS    r3, r3, #HALFlag_NCNBWorkspace
        MOVNE   r3, r2
        EXIT

MAI_Kbuffs
        LDR     r1, =KbuffsBaseAddress
        MOV     r2, #KbuffsMaxSize
        LDR     r3, =(KbuffsSize + &FFF) :AND: :NOT: &FFF
        EXIT

MAI_ZeroPage
        LDR     r1, =ZeroPage
        MOV     r2, #16*1024
        MOV     r3, #16*1024
        EXIT

MAI_ProcVecs
      [ ZeroPage != ProcVecs
        LDR     r1, =ProcVecs
        MOV     r2, #4096
        MOV     r3, #4096
      ]
        EXIT

MAI_DebuggerSpace
        ; Only report if DebuggerSpace is a standalone page. The debugger module
        ; finds DebuggerSpace via OS_ReadSysInfo 6, this call is only for the
        ; benefit of the task manager.
      [ DebuggerSpace_Size >= &1000
        LDR     r1, =DebuggerSpace
        MOV     r2, #DebuggerSpace_Size
        MOV     r3, #DebuggerSpace_Size
      ]
        EXIT

MAI_ScratchSpace
        LDR     r1, =ScratchSpace
        MOV     r2, #16*1024
        MOV     r3, #16*1024
        EXIT

MAI_CompatibilityPage
      [ CompatibilityPage
        MOV     r1, #0
        MOV     r2, #4096
        LDR     r0, =ZeroPage
        LDRB    r3, [r0,#CompatibilityPageEnabled]
        CMP     r3, #0
        MOVNE   r3, #4096
      ]
        EXIT

;----------------------------------------------------------------------------------------
;
;        In:    r0 = flags
;                       bit     meaning
;                       0-7     17 (reason code)
;                       8-31    reserved (set to 0)
;               r1 = AP number to start search from (0 to start enumeration)
;                    increment by 1 on each call to enumerate all values
;
;       Out:    r1 = AP number (-1 if end of list reached)
;               r2 = Permissions:
;               bit 0: executable in user mode
;               bit 1: writable in user mode
;               bit 2: readable in user mode
;               bit 3: executable in privileged modes
;               bit 4: writable in privileged modes
;               bit 5: readable in privileged modes
;               bits 6+: reserved
;
;       Returns permission information for a given AP / enumerates all AP
MemoryAccessPrivileges ROUT
        CMP     r0, #17
        BNE     MemoryBadParameters
        Entry   "r3-r4"
        LDR     r3, =ZeroPage
        MOV     lr, r1
        LDR     r3, [r3, #MMU_PPLAccess]
        ; Currently we don't have any gaps in the table, so we can just index the r1'th element (being careful to not go past the table end)
10
        LDR     r4, [r3], #4
        CMP     r4, #-1
        BEQ     %FT98
        SUBS    lr, lr, #1
        BGE     %BT10
        BL      PPL_CMA_to_RWX             
        EXIT
98
        MOV     r1, #-1
        MOV     r2, #0
        EXIT

; In: r4 = CMA-style AP/PPL access flags (from MMU_PPLAccess)
; Out: r2 = RWX-style AP/PPL access flags (for OS_Memory 17/18)
PPL_CMA_to_RWX ROUT
        Entry
        AND     r2, r4, #CMA_Partially_UserR
        ASSERT  CMA_Partially_UserR = 1<<4
        ASSERT  MemPermission_UserR = 1<<2
        MOV     r2, r2, LSR #4-2
        AND     lr, r4, #CMA_Partially_UserW
        ASSERT  CMA_Partially_UserW = 1<<5
        ASSERT  MemPermission_UserW = 1<<1
        ORR     r2, r2, lr, LSR #5-1
        AND     lr, r4, #CMA_Partially_UserXN ; (internally, XN flags are stored inverted)
        ASSERT  CMA_Partially_UserXN = 1<<14
        ASSERT  MemPermission_UserX = 1<<0
        ORR     r2, r2, lr, LSR #14-0
        AND     lr, r4, #CMA_Partially_PrivR
        ASSERT  CMA_Partially_PrivR = 1<<6
        ASSERT  MemPermission_PrivR = 1<<5
        ORR     r2, r2, lr, LSR #6-5
        AND     lr, r4, #CMA_Partially_PrivW
        ASSERT  CMA_Partially_PrivW = 1<<7
        ASSERT  MemPermission_PrivW = 1<<4
        ORR     r2, r2, lr, LSR #7-4
        AND     lr, r4, #CMA_Partially_PrivXN
        ASSERT  CMA_Partially_PrivXN = 1<<15
        ASSERT  MemPermission_PrivX = 1<<3
        ORR     r2, r2, lr, LSR #15-3
        EXIT

;----------------------------------------------------------------------------------------
;
;        In:    r0 = flags
;                       bit     meaning
;                       0-7     18 (reason code)
;                       8-31    reserved (set to 0)
;               r1 = Permission flag values (as per OS_Memory 17)
;               r2 = Permission flag mask
;
;       Out:    r0 = AP number that gives closest permissions
;               r2 = Permission flags of that AP (== r1 if exact match)
;               Error if no suitable AP found
;
;       Searches for an AP where ((permissions AND r2) == r1), and which
;       grants the least extra permissions
;
;       Extra permissions are weighted as follows (least acceptable first):
;       * User write
;       * User execute
;       * User read
;       * Privileged write
;       * Privileged execute
;       * Privileged read
FindAccessPrivilege ROUT
        CMP     r0, #18 ; No extra flags in r0
        BICEQS  r0, r1, r2 ; r1 must be a subset of r2
        BICEQS  r0, r2, #63 ; Only 6 known permission flags
        BNE     MemoryBadParameters
        ; n.b. r0 is now 0
        Entry   "r3-r11"
        LDR     r3, =ZeroPage
        MOV     r5, r1
        LDR     r3, [r3, #MMU_PPLAccess]
        MOV     r6, r2
        MOV     r7, #-1 ; Best AP
        MOV     r8, #0 ; Best flags
        MOV     r9, #-1 ; Best difference
        ; Magic constants for weighting the difference
        LDR     r10, =(1<<1)+(1<<6)+(1<<12)+(1<<18)+(1<<24)+(1<<30)
        LDR     r11, =(MemPermission_PrivR<<1)+(MemPermission_PrivX<<6)+(MemPermission_PrivW<<12)+(MemPermission_UserR<<18)+(MemPermission_UserX<<24)+(MemPermission_UserW<<30)
10
        LDR     r4, [r3], #4
        CMP     r4, #-1
        BEQ     %FT50
        BL      PPL_CMA_to_RWX ; -> r2 = flags
        ; Check it satisfies the mask
        AND     lr, r2, r6
        CMP     lr, r5
        BNE     %FT40
        ; Calculate diff
        BIC     lr, r2, r6
        MUL     lr, r10, lr ; Replicate the six bits six times
        AND     lr, r11, lr ; Select just the bits that we care about
        CMP     lr, r9
        BEQ     %FT80       ; Exact match found
        MOVLO   r7, r0      ; Remember new result if better
        MOVLO   r8, r2
        MOVLO   r9, lr
40
        ADD     r0, r0, #1
        B       %BT10
50
        MOVS    r0, r7
        BMI     %FT90
        MOV     r2, r8
80
        CLRV
        EXIT

90
        MOV     r2, r6 ; Restore original r2        
        ADR     r0, ErrorBlock_AccessPrivilegeNotFound
        SETV
        EXIT

        MakeErrorBlock AccessPrivilegeNotFound


;----------------------------------------------------------------------------------------
;
;       In:     r0 = flags
;                       bit     meaning
;                       0-7     20 (reason code)
;                       8-31    reserved (set to 0)
;               r1 = 0 to disable compatibility page
;                    1 to enable compatibility page
;                    -1 to read state
;
;       Out:    r1 = new/current state:
;                    0 if disabled
;                    1 if enabled
;                    -1 if not supported
;
;       Controls the page zero compatibility page located at &0
;
;       If the compatibility page isn't supported, attempts to enable it will
;       silently fail, with a result of r1 = -1
;
ChangeCompatibility ROUT
        CMP     r1, #-1
        CMPNE   r1, #1
        CMPLS   r0, #255
        BHI     MemoryBadParameters
 [ :LNOT: CompatibilityPage
        MOV     r1, #-1
        MOV     pc, lr
 |
        Entry   "r0-r11", DANode_NodeSize
        LDR     r12, =ZeroPage
        LDRB    r0, [r12, #CompatibilityPageEnabled]
        FRAMSTR r0,,r1 ; return pre-change state in r1 (will be updated later, as necessary)
        CMP     r1, #-1
        CMPNE   r0, r1
        EXIT    EQ
        ; If we're attempting to enable it, make sure nothing else has mapped itself in to page zero
        LDR     r8, =L2PT
        CMP     r1, #0
        LDRNE   r0, [r8]
        CMPNE   r0, #0
        MOVNE   r1, #-1
        FRAMSTR r1,NE
        EXIT    NE
        ; Set up temp DANode on the stack so we can use a Batcall to manage the mapping
        MOV     r2, sp
        MOV     r0, #DynAreaFlags_NotCacheable
        STR     r0, [r2, #DANode_Flags]
        MOV     r0, #0
        STR     r0, [r2, #DANode_Base]
        STR     r0, [r2, #DANode_Handler]
        CMP     r1, #1
        STREQ   r0, [r2, #DANode_Size]
        MOV     r0, #4096
        STRNE   r0, [r2, #DANode_Size]
        STR     r0, [r2, #DANode_MaxSize]
        MOV     r0, #ChangeDyn_Batcall
        MOV     r1, #4096
        RSBNE   r1, r1, #0
        SWI     XOS_ChangeDynamicArea
        FRAMSTR r0,VS
        EXIT    VS
        ; If we just enabled the page, fill it with the special value and then change it to read-only
        FRAMLDR r1
        RSBS    r1, r1, #1 ; invert returned state, to be correct for the above action
        STRB    r1, [r12, #CompatibilityPageEnabled] ; Also update our state flag
        FRAMSTR r1
        EXIT    EQ
        MOV     r0, #0
        ADR     r1, %FT20
10
        CMP     r0, #%FT30-%FT20
        LDRLO   r2, [r1, r0]
        STR     r2, [r0], #4
        CMP     r0, #4096
        BNE     %BT10
        LDR     r7, [r12, #MaxCamEntry]
        MOV     r4, #0
        BL      logical_to_physical
        BL      physical_to_ppn
        ; r9-r11 corrupt, r3 = page number, r5 = phys addr
        MOV     r0, #OSMemReason_FindAccessPrivilege
        MOV     r1, #2_100100
        MOV     r2, #2_100100
        SWI     XOS_Memory ; Get AP number for read-only access (will make area XN on ARMv6+)
        ORRVC   r11, r0, #DynAreaFlags_NotCacheable
        MOVVC   r2, r3
        MOVVC   r3, #0
        BLVC    BangCamUpdate
        EXIT

20
        ; Pattern to place in compatibility page
        DCD     &FDFDFDFD ; A few of words of invalid addresses, which should also be invalid instructions on ARMv5 (ARMv6+ will have this page non-executable, ARMv4 and lower can't have high processor vectors)
        DCD     &FDFDFDFD
        DCD     &FDFDFDFD
        DCD     &FDFDFDFD
        = "!!!!NULL.POINTER.DEREFERENCE!!!!", 0 ; Readable message if interpretered as a string. Also, all words are unaligned pointers.
        ALIGN
        DCD     0 ; Fill the rest with zero (typically, most of ZeroPage is zero)
30
 ]

;----------------------------------------------------------------------------------------
;
;        In:    r0 = flags
;                       bit     meaning
;                       0-7     24 (reason code)
;                       8-31    reserved (set to 0)
;               r1 = low address (inclusive)
;               r2 = high address (exclusive)
;
;       Out:    r1 = access flags:
;               bit 0: completely readable in user mode
;               bit 1: completely writable in user mode
;               bit 2: completely readable in privileged modes
;               bit 3: completely writable in privileged modes
;               bit 4: partially readable in user mode
;               bit 5: partially writable in user mode
;               bit 6: partially readable in privileged modes
;               bit 7: partially writable in privileged modes
;               bit 8: completely physically mapped (i.e. IO memory)
;               bit 9: completely abortable (i.e. custom data abort handler)
;               bit 10: completely non-executable in user mode
;               bit 11: completely non-executable in privileged modes
;               bit 12: partially physically mapped
;               bit 13: partially abortable
;               bit 14: partially non-executable in user mode
;               bit 15: partially non-executable in privileged modes
;               bits 16+: reserved
;
;       Return various attributes for the given memory region

; NOTE: To make the flags easier to calculate, this routine calculates executability rather than non-executability. This means that unmapped memory has flags of zero. On exit we invert the sense of the bits in order to get non-executability (so that the public values are backwards-compatible with OS versions that didn't return executability information)
CMA_Completely_Inverted * CMA_Completely_UserXN + CMA_Completely_PrivXN

CMA_CheckL2PT          * 1<<31 ; Pseudo flag used internally for checking sparse areas
CMA_DecodeAP           * 1<<30 ; Used with CheckL2PT to indicate AP flags should be decoded from L2PT

; AP_ equivalents

CheckMemoryAccess ROUT
        Entry   "r0,r2-r10"
        CMP     r0, #24
        BNE     %FT99
        LDR     r10, =ZeroPage
        ; Set all the 'completely' flags, we'll clear them as we go along
        LDR     r0, =&0F0F0F0F
        ; Make end address inclusive so we don't have to worry so much about
        ; wrap around at 4G
        TEQ     r1, r2
        SUBNE   r2, r2, #1
        ; Split memory up into five main regions:
        ; * scratchspace/zeropage
        ; * application space
        ; * dynamic areas
        ; * IO memory
        ; * special areas (stacks, ROM, HAL workspace, etc.)
        ; All ranges are checked in increasing address order, so the
        ; completeness flags are returned correctly if we happen to cross from
        ; one range into another
        ; Note that application space can't currently be checked in DA block as
        ; (a) it's not linked to DAList/DynArea_AddrLookup
        ; (b) we need to manually add the abortable flag
        CMP     r1, #32*1024
        BHS     %FT10
        ; Check zero page
        ASSERT  ProcVecs = ZeroPage
     [ ZeroPage = 0
        MOV     r3, #0
        MOV     r4, #16*1024
        LDR     r5, =CMA_ZeroPage
        BL      CMA_AddRange
     |
      [ CompatibilityPage
        ; Zero page compatibility page
        LDR     r3, =ZeroPage
        LDRB    r3, [r3, #CompatibilityPageEnabled]
        CMP     r3, #0
        BEQ     %FT05
        MOV     r3, #0
        MOV     r4, #4096
        ; This represents our ideal access flags; it may not correspond to reality
        LDR     r5, =CMA_Partially_UserR+CMA_Partially_PrivR
        BL      CMA_AddRange
05
      ]
        ; DebuggerSpace
        ASSERT  DebuggerSpace < ScratchSpace
        LDR     r3, =DebuggerSpace
        LDR     r4, =(DebuggerSpace_Size + &FFF) :AND: &FFFFF000
        LDR     r5, =CMA_DebuggerSpace
        BL      CMA_AddRange
     ]
        ; Scratch space
        LDR     r3, =ScratchSpace
        MOV     r4, #16*1024
        LDR     r5, =CMA_ScratchSpace
        BL      CMA_AddRange
10
        ; Application space
        ; Note - checking AplWorkSize as opposed to AplWorkMaxSize to cope with
        ; software which creates DAs within application space (e.g. Aemulor)
        LDR     r4, [r10, #AplWorkSize]
        CMP     r1, r4
        BHS     %FT20
        LDR     r3, [r10, #AMBControl_ws]
        LDR     r3, [r3, #:INDEX:AMBFlags]
        LDR     r5, =CMA_AppSpace
        TST     r3, #AMBFlag_LazyMapIn_disable :OR: AMBFlag_LazyMapIn_suspend
        MOV     r3, #32*1024
        ORREQ   r5, r5, #CMA_Partially_Abort
        BL      CMA_AddRange2
20
        ; Dynamic areas
        LDR     r7, [r10, #IOAllocLimit]
        CMP     r1, r7
        BHS     %FT30
        ; Look through the quick lookup table until we find a valid DANode ptr
        LDR     r6, [r10, #DynArea_ws]
        MOV     r3, r1
        TEQ     r6, #0 ; We can get called during ROM init, before the workspace is allocated (pesky OS_Heap validating its pointers)
        ADD     r6, r6, #(:INDEX:DynArea_AddrLookup) :AND: &00FF
        LDREQ   r9, [r10, #DAList] ; So just start at the first DA
        ADD     r6, r6, #(:INDEX:DynArea_AddrLookup) :AND: &FF00
        BEQ     %FT22
21
        AND     r8, r3, #DynArea_AddrLookupMask
        LDR     r9, [r6, r8, LSR #30-DynArea_AddrLookupBits]
        TEQ     r9, #0
        BNE     %FT22
        ; Nothing here, skip ahead to next block
        ADD     r3, r8, #DynArea_AddrLookupSize
        CMP     r3, r2
        BHI     %FT90 ; Hit end of search area
        CMP     r3, r7
        BLO     %BT21
        ; Hit end of DA area and wandered into IO area
        B       %FT30
22
        ; Now that we've found a DA to start from, walk through and process all
        ; the entries until we hit the end of the list, or any DAs above
        ; IOAllocLimit
        LDR     r3, [r9, #DANode_Base]
        LDR     r6, [r9, #DANode_Flags]
        CMP     r3, r7
        BHS     %FT30
        ; Decode AP flags
        LDR     r5, [r10, #MMU_PPLAccess]
        AND     lr, r6, #DynAreaFlags_APBits
        LDR     r5, [r5, lr, LSL #2]
        TST     r6, #DynAreaFlags_PMP
        ORRNE   r5, r5, #CMA_DecodeAP
        TSTEQ   r6, #DynAreaFlags_SparseMap
        LDREQ   lr, [r9, #DANode_Size]
        LDRNE   r4, [r9, #DANode_SparseHWM] ; Use HWM as bounds when checking sparse/PMP areas
        ORRNE   r5, r5, #CMA_CheckL2PT ; ... and request L2PT check
        ADDEQ   r4, r3, lr
        TST     r6, #DynAreaFlags_DoublyMapped ; Currently impossible for Sparse/PMP areas - so use of lr safe
        SUBNE   r3, r3, lr
        BL      CMA_AddRange2
        LDR     r9, [r9, #DANode_Link]
        TEQ     r9, #0
        BNE     %BT22
        ; Hit the end of the list
30
        ; IO memory
        CMP     r1, #IO
        BHS     %FT40
        MOV     r3, r1, LSR #20
        LDR     r4, [r10, #IOAllocPtr]
        MOV     r3, r3, LSL #20 ; Get MB-aligned addr of first entry to check
        CMP     r3, r4
        LDR     r7, =L1PT
        MOVLO   r3, r4 ; Skip all the unallocated regions
31
        Push    "r0,r1"
        LDR     r0, [r7, r3, LSR #20-2]
        BL      DecodeL1Entry           ; TODO bit wasteful. We only care about access privileges, but this call gives us cache info too.
        LDR     r5, [r10, #MMU_PPLAccess]
        AND     lr, r1, #DynAreaFlags_APBits
        LDR     r5, [r5, lr, LSL #2]
        Pull    "r0,r1"
        ADD     r4, r3, #1<<20
        ORR     r5, r5, #CMA_Partially_Phys
        BL      CMA_AddRange2
        CMP     r4, #IO
        MOV     r3, r4
        BNE     %BT31
40
        ; Everything else!
        LDR     r3, =HALWorkspace
        LDR     r4, [r10, #HAL_WsSize]
        LDR     r5, =CMA_HALWorkspace
        BL      CMA_AddRange
        ASSERT  IRQStackAddress > HALWorkspace
        LDR     r3, =IRQStackAddress
        LDR     r4, =IRQStackSize
        LDR     r5, =CMA_IRQStack
        BL      CMA_AddRange
        ASSERT  SVCStackAddress > IRQStackAddress
        LDR     r3, =SVCStackAddress
        LDR     r4, =SVCStackSize
        LDR     r5, =CMA_SVCStack
        BL      CMA_AddRange
        ASSERT  ABTStackAddress > SVCStackAddress
        LDR     r3, =ABTStackAddress
        LDR     r4, =ABTStackSize
        LDR     r5, =CMA_ABTStack
        BL      CMA_AddRange
        ASSERT  UNDStackAddress > ABTStackAddress
        LDR     r3, =UNDStackAddress
        LDR     r4, =UNDStackSize
        LDR     r5, =CMA_UNDStack
        BL      CMA_AddRange
        ASSERT  PhysicalAccess > UNDStackAddress
        LDR     r3, =L1PT + (PhysicalAccess:SHR:18)
        LDR     r3, [r3]
        TEQ     r3, #0
        BEQ     %FT50
        LDR     r3, =PhysicalAccess
        LDR     r4, =&100000
        ; Assume IO memory mapped there
      [ MEMM_Type = "VMSAv6"
        LDR     r5, =CMA_Partially_PrivR+CMA_Partially_PrivW+CMA_Partially_Phys
      |
        LDR     r5, =CMA_Partially_PrivR+CMA_Partially_PrivW+CMA_Partially_PrivXN+CMA_Partially_Phys
      ]
        BL      CMA_AddRange
50
        ASSERT  DCacheCleanAddress > PhysicalAccess
        LDR     r4, =DCacheCleanAddress+DCacheCleanSize
        CMP     r1, r4
        BHS     %FT60
        ; Check that DCacheCleanAddress is actually used
        Push    "r0-r2,r9"
        AddressHAL r10
        MOV     a1, #-1
        CallHAL HAL_CleanerSpace
        CMP     a1, #-1
        Pull    "r0-r2,r9"
        BEQ     %FT60
        SUB     r3, r4, #DCacheCleanSize
        MOV     r4, #DCacheCleanSize
        ; Mark as IO, it may not be actual memory there
        LDR     r5, =CMA_DCacheClean+CMA_Partially_Phys
        BL      CMA_AddRange
60
        ASSERT  KbuffsBaseAddress > DCacheCleanAddress
        LDR     r3, =KbuffsBaseAddress
        LDR     r4, =(KbuffsSize + &FFF) :AND: &FFFFF000
        LDR     r5, =CMA_Kbuffs
        BL      CMA_AddRange
        ASSERT  HALWorkspaceNCNB > KbuffsBaseAddress
        LDR     r3, [r10, #HAL_Descriptor]
        LDR     r3, [r3, #HALDesc_Flags]
        TST     r3, #HALFlag_NCNBWorkspace
        BEQ     %FT70
        LDR     r3, =HALWorkspaceNCNB
        LDR     r4, =32*1024
        LDR     r5, =CMA_HALWorkspaceNCNB
        BL      CMA_AddRange
70
        ASSERT  L2PT > HALWorkspaceNCNB
        LDR     r3, =L2PT
        MOV     r4, #4*1024*1024
        LDR     r5, =CMA_PageTablesAccess+CMA_CheckL2PT ; L2PT contains gaps due to logical indexing
        BL      CMA_AddRange
        ASSERT  L1PT > L2PT
        LDR     r3, =L1PT
        MOV     r4, #16*1024
        LDR     r5, =CMA_PageTablesAccess
        BL      CMA_AddRange
        ASSERT  CursorChunkAddress > L1PT
        LDR     r3, =CursorChunkAddress
        MOV     r4, #32*1024
        LDR     r5, =CMA_CursorChunk
        BL      CMA_AddRange
        ASSERT  CAM > CursorChunkAddress
        LDR     r3, =CAM
        LDR     r4, [r10, #SoftCamMapSize]
        LDR     r5, =CMA_CAM
        BL      CMA_AddRange
        ASSERT  ROM > CAM
        LDR     r3, =ROM
        LDR     r4, =OSROM_ImageSize*1024
        LDR     r5, =CMA_ROM
        BL      CMA_AddRange
        ; Finally, high processor vectors/relocated zero page
        ASSERT  ProcVecs = ZeroPage
      [ ZeroPage > 0
        ASSERT  ZeroPage > ROM
        MOV     r3, r10
        LDR     r4, =16*1024
        LDR     r5, =CMA_ZeroPage
        BL      CMA_AddRange
      ]
90
        ; If there's anything else, we've wandered off into unallocated memory
        LDR     r3, =&0F0F0F0F
        BIC     r1, r0, r3
        B       CMA_Done

99
        PullEnv
        B       MemoryBadParameters

        ; Add range r3..r4 to attributes in r0
        ; Corrupts r8
CMA_AddRange ROUT ; r3 = start, r4 = length
        ADD     r4, r3, r4
CMA_AddRange2 ; r3 = start, r4 = end (excl.)
        LDR     r8, =&0F0F0F0F
        ; Increment r1 and exit if we hit r2
        ; Ignore any ranges which are entirely before us
        CMP     r1, r4
        MOVHS   pc, lr
        ; Check for any gap at the start, i.e. r3 > r1
        CMP     r3, r1
        BICHI   r0, r0, r8
        MOVHI   r1, r3 ; Update r1 for L2PT check code
        ; Exit if the range starts after our end point
        CMP     r3, r2
        BHI     %FT10
        ; Process the range
        TST     r5, #CMA_CheckL2PT
        BNE     %FT20
        CMP     r3, r4 ; Don't apply any flags for zero-length ranges
04      ; Note L2PT check code relies on NE condition here
        ORR     r8, r5, r8
        ORRNE   r0, r0, r5 ; Set new partial flags
        ANDNE   r0, r0, r8, ROR #4 ; Discard completion flags which aren't for this range
05
        CMP     r4, r2
        MOV     r1, r4 ; Continue search from the end of this range
        MOVLS   pc, lr
10
        ; We've ended inside this range
        MOV     r1, r0
CMA_Done
        ; Invert the sense of the executability flags
        ;               Completely_X Partially_X -> Completely_XN Partially_XN
        ; Completely X             1           1                0            0
        ; Partially X              0           1                0            1
        ; XN                       0           0                1            1
        ; I.e. swap the positions of the two bits and invert them
        EOR     r0, r1, r1, LSR #4      ; Completely EOR Partially
        MVN     r0, r0                  ; Invert as well as swap
        AND     r0, r0, #CMA_Completely_Inverted ; Only touch these bits
        EOR     r1, r1, r0              ; Swap + invert Completely flags
        EOR     r1, r1, r0, LSL #4      ; Swap + invert Partially flags
        CLRV
        EXIT

20
        ; Check L2PT for sparse region r1..min(r2+1,r4)
        ; r4 guaranteed page aligned
        CMP     r3, r4
        BIC     r5, r5, #CMA_CheckL2PT
        BEQ     %BT05
        Push    "r2,r4,r5,r8,r9,r10,lr"
        LDR     lr, =&FFF
        CMP     r4, r2
        ADDHS   r2, r2, #4096
        BICHS   r2, r2, lr
        MOVLO   r2, r4
        ; r2 is now page aligned min(r2+1,r4)
        LDR     r8, =L2PT
        TST     r5, #CMA_DecodeAP
        BIC     r4, r1, lr
        BNE     %FT35
        MOV     r10, #0
30
        BL      logical_to_physical
        ORRCC   r10, r10, #1
        ADD     r4, r4, #4096
        ORRCS   r10, r10, #2
        CMP     r4, r2
        BNE     %BT30
        CMP     r10, #2
        ; 01 -> entirely mapped
        ; 10 -> entirely unmapped
        ; 11 -> partially mapped
        Pull    "r2,r4,r5,r8,r9,r10,lr"
        BICHS   r0, r0, r8 ; Not fully mapped, clear completion flags
        BNE     %BT04 ; Partially/entirely mapped
        B       %BT05 ; Completely unmapped

35
        ; Check L2PT, with AP decoding on a per-page basis
40
        LDR     r10, =&0F0F0F0F
        BL      logical_to_physical
        BICCS   r0, r0, r10 ; Not fully mapped, clear completion flags
        BCS     %FT45
        ; Get the L2PT entry and decode the flags
        Push    "r0-r2"
        LDR     r0, [r8, r4, LSR #10]
        BL      DecodeL2Entry           ; TODO bit wasteful. We only care about access privileges, but this call gives us cache info too. Also, if we know the L2PT backing exists (it should do) we could skip the logical_to_physical call
        ; r1 = DA flags
        ; Extract and decode AP
        LDR     r0, =ZeroPage
        LDR     r5, [r0, #MMU_PPLAccess]
        AND     lr, r1, #DynAreaFlags_APBits
        LDR     r5, [r5, lr, LSL #2]
        Pull    "r0-r2"
        ORR     r10, r5, r10
        ORR     r0, r0, r5 ; Set new partial flags
        AND     r0, r0, r10, ROR #4 ; Discard completion flags which aren't for this range
45
        ADD     r4, r4, #4096
        CMP     r4, r2
        BNE     %BT40
        Pull    "r2,r4,r5,r8,r9,r10,lr"
        B       %BT05

        LTORG

        END
