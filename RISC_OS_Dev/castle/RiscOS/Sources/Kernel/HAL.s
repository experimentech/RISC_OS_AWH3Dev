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
        GBLL    MinorL2PThack
MinorL2PThack SETL {TRUE}

; Fixed page allocation is as follows

                        ^       0
DRAMOffset_FirstFixed   #       0
DRAMOffset_ScratchSpace #       16*1024
DRAMOffset_PageZero     #       16*1024
DRAMOffset_L1PT         #       16*1024         ; L1PT must be 16K-aligned
DRAMOffset_LastFixed    #       0

;        IMPORT  Init_ARMarch
;        IMPORT  ARM_Analyse

 [ MEMM_Type = "VMSAv6"
mmuc_init_new
        ; MMUC initialisation flags for ARMv6/ARMv7
        ; This tries to leave the reserved/unpredictable bits untouched, while initialising everything else to what we want
                ; ARMv7MP (probably) wants SW. ARMv6 wants U+XP (which should both be fixed at 1 on ARMv7)
        DCD     MMUC_SW+MMUC_U+MMUC_XP
                ; M+C+W+Z+I+L2 clear to keep MMU/caches off.
                ; A to keep alignment exceptions off (for now at least)
                ; B+EE clear for little-endian
                ; S+R+RR clear to match mmuc_init_old
                ; V+VE clear to keep processor vectors at &0
                ; FI clear to disable fast FIQs (interruptible LDM/STM)
                ; TRE+AFE clear for our VMSAv6 implementation
                ; TE clear for processor vectors to run in ARM mode
        DCD     MMUC_M+MMUC_A+MMUC_C+MMUC_W+MMUC_B+MMUC_S+MMUC_R+MMUC_Z+MMUC_I+MMUC_V+MMUC_RR+MMUC_FI+MMUC_VE+MMUC_EE+MMUC_L2+MMUC_TRE+MMUC_AFE+MMUC_TE
mmuc_init_old
        ; MMUC initialisation flags for ARMv5 and below, as per ARM600 MMU code
                ; Late abort (ARM6 only), 32-bit Data and Program space. No Write buffer (ARM920T
                ; spec says W bit should be set, but I reckon they're bluffing).
                ;
                ; The F bit's tricky. (1 => CPCLK=FCLK, 0=>CPCLK=FCLK/2). The only chip using it was the
                ; ARM700, it never really reached the customer, and it's always been programmed with
                ; CPCLK=FCLK. Therefore we'll keep it that way, and ignore the layering violation.
        DCD     MMUC_F+MMUC_L+MMUC_D+MMUC_P
                ; All of these bits should be off already, but just in case...
        DCD     MMUC_B+MMUC_W+MMUC_C+MMUC_A+MMUC_M+MMUC_RR+MMUC_V+MMUC_I+MMUC_Z+MMUC_R+MMUC_S
 ]

; void RISCOS_InitARM(unsigned int flags)
;
RISCOS_InitARM
        MOV     a4, lr
        ; Check if we're architecture 3. If so, don't read the control register.
        BL      Init_ARMarch
        MOVEQ   a3, #0
        ARM_read_control a3, NE
 [ MEMM_Type = "VMSAv6"
        CMP     a1, #ARMv6
        CMPNE   a1, #ARMvF
        ADREQ   a2, mmuc_init_new
        ADRNE   a2, mmuc_init_old
        LDMIA   a2, {a2, lr}
        ORR     a3, a3, a2
        BIC     a3, a3, lr     
 |
        ; Late abort (ARM6 only), 32-bit Data and Program space. No Write buffer (ARM920T
        ; spec says W bit should be set, but I reckon they're bluffing).
        ;
        ; The F bit's tricky. (1 => CPCLK=FCLK, 0=>CPCLK=FCLK/2). The only chip using it was the
        ; ARM700, it never really reached the customer, and it's always been programmed with
        ; CPCLK=FCLK. Therefore we'll keep it that way, and ignore the layering violation.
        ORR     a3, a3, #MMUC_F+MMUC_L+MMUC_D+MMUC_P
        ; All of these bits should be off already, but just in case...
        BIC     a3, a3, #MMUC_B+MMUC_W+MMUC_C+MMUC_A+MMUC_M
        BIC     a3, a3, #MMUC_RR+MMUC_V+MMUC_I+MMUC_Z+MMUC_R+MMUC_S
 ]

        ; Off we go.
        ARM_write_control a3
        MOV     a2, #0
 [ MEMM_Type = "VMSAv6"
        myISB   ,a2,,y ; Ensure the update went through
 ]

        ; In case it wasn't a hard reset
 [ MEMM_Type = "VMSAv6"
        CMP     a1, #ARMvF
        ; Assume that all ARMvF ARMs have multi-level caches and thus no single MCR op for invalidating all the caches
        ADREQ   lr, %FT01
        BEQ     HAL_InvalidateCache_ARMvF
        MCRNE   ARM_config_cp,0,a2,ARMv4_cache_reg,C7           ; invalidate I+D caches
01
 ]
        CMP     a1, #ARMv3
        BNE     %FT01
        MCREQ   ARM_config_cp,0,a2,ARMv3_TLBflush_reg,C0        ; flush TLBs
        B       %FT02
01      MCRNE   ARM_config_cp,0,a2,ARMv4_TLB_reg,C7             ; flush TLBs
02
 [ MEMM_Type = "VMSAv6"
        myDSB   ,a2,,y
        myISB   ,a2,,y
 ]

        ; We assume that ARMs with an I cache can have it enabled while the MMU is off.
        [ :LNOT:CacheOff
        ORRNE   a3, a3, #MMUC_I
        ARM_write_control a3, NE                                ; whoosh
 [ MEMM_Type = "VMSAv6"
        myISB   ,a2,,y ; Ensure the update went through
 ]
        ]

        ; Check if we are in a 26-bit mode.
        MRS     a2, CPSR
        ; Keep a soft copy of the CR in a banked register (R13_und)
        MSR     CPSR_c, #F32_bit+I32_bit+UND32_mode
        MOV     sp, a3
        ; Switch into SVC32 mode (we may have been in SVC26 before).
        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode

        ; If we were in a 26-bit mode, the lr value given to us would have had PSR flags in.
        TST     a2, #2_11100
        MOVNE   pc, a4
        BICEQ   pc, a4, #ARM_CC_Mask


; void *RISCOS_AddRAM(unsigned int flags, void *start, void *end, uintptr_t sigbits, void *ref)
;   Entry:
;     flags   bit 0: video memory (currently only one block permitted)
;             bit 1: video memory is not suitable for general use
;             bit 2: memory can't be used for DMA (sound, video, or other)
;             bits 8-11: speed indicator (arbitrary, higher => faster)
;             other bits reserved (SBZ)
;     start   = start address of RAM (inclusive) (no alignment requirements)
;     end     = end address of RAM (exclusive) (no alignment requirements, but must be >= start)
;     sigbits = significant address bit mask (1 => this bit of addr decoded, 0 => this bit ignored)
;     ref     = reference handle (NULL for first call)

; A table is built up at the head of the first block of memory.
; The table consists of (addr, len, flags) pairs, terminated by a count of those pairs; ref points to that
; counter.
; Twelve bits of flags are stored at the bottom of the length word.

        ROUT
RISCOS_AddRAM
        Push    "v1,v2,v3,v4,lr"
        LDR     v4, [sp, #5*4]          ; Get ref

        ; Round to pages. If we were extra sneaky we could not do this and chuck out incomplete
        ; pages after concatanation, but it would be a weird HAL that gave us pages split across
        ; calls.
        ;
        ADD     a2, a2, #4096           ; round start address up
        SUB     a2, a2, #1
        MOV     a2, a2, LSR #12
        MOV     a2, a2, LSL #12
        MOV     a3, a3, LSR #12         ; round end address down
        MOV     a3, a3, LSL #12

        CMP     a3, a2
        BLS     %FT90                   ; check we aren't now null

        CMP     v4, #0
        BEQ     %FT20

        ; We are not dealing with the first block since v4 != 0.  Make an attempt to merge this block
        ; with the previous block.
        LDMDB   v4, {v1, v2}            ; Get details of the previous block
        MOV     v3, v2, LSL #20         ; Isolate flags
        BIC     v2, v2, v3, LSR #20     ; And strip from length
        ADD     v2, v1, v2              ; Get the end address
        EOR     v2, v2, a2              ; Compare with the current block start address...
        TST     v2, a4                  ; ... but only check the decoded bits.
        EOR     v2, v2, a2              ; Restore the previous block end address.
        TEQEQ   v3, a1, LSL #20         ; And are the page flags the same?
        BNE     %FT10                   ; We can't merge it after the previous block

        ; v1 = previous start
        ; v2 = previous end
        ; The block is just after the previous block.  That means the start address is unchanged, but
        ; the length is increased.
        SUB     v2, v2, v1              ; Calculate the previous block length.
        SUB     a3, a3, a2              ; Find the length of the new block.
        ; a3 = length of block
        ADD     v2, v2, a3              ; Add it to the previous length.
        ORR     v2, v2, v3, LSR #20     ; And put the flags back in.
        STR     v2, [v4, #-4]           ; Update the block size in memory.
        MOV     a1,v4
        Pull    "v1,v2,v3,v4,pc"

        ; The block is not just after the previous block, but it may be just before.  This may be the
        ; case if we are softloaded.
10      SUB     v1, v1, #1              ; Compare the address before the previous block start ...
        SUB     a3, a3, #1              ; ... with the address of the last byte in this block ...
        EOR     v1, v1, a3
        TST     v1, a4                  ; ... but check only the decoded bits.
        ADD     a3, a3, #1              ; Restore the end address.
        TEQEQ   v3, a1, LSL #20         ; And are the page flags the same?
        BNE     %FT20                   ; Skip if we cannot merge the block.

        ; The block is just before the previous block.  The start address and length both change.
        LDR     v1, [v4, #-8]           ; Get the previous block start again.

        SUB     a3, a3, a2              ; Calculate the current block size.
        SUB     v1, v1, a3              ; Subtract from the previous block start address.
        SUB     v2, v2, v1              ; Calculate the new length=end-start
        ORR     v2, v2, v3, LSR #20     ; And put the flags back in.
        STMDB   v4, {v1, v2}            ; Update the block info in memory.
        MOV     a1,v4
        Pull    "v1,v2,v3,v4,pc"

        ; We now have a region which does not merge with a previous region.  We move it up to the
        ; highest address we can in the hope that this block will merge with the next block.
20      SUB     a3, a3, a2              ; Calculate the block size
        MOV     a1, a1, LSL #20
        ORR     a3, a3, a1, LSR #20     ; Put the flags at the bottom
        MVN     v1, a4                  ; Get the non-decoded address lines.
        ORR     a2, v1, a2              ; Set the non-decoded address bit in the start address.

30      CMP     v4, #0                  ; If the workspace has not been allocated...
        MOVEQ   v4, a2                  ; ... use this block.
        MOVEQ   v1, #0                  ; Initialise the counter.

        ; The block/fragment to be added is between a2 and a2+a3.
        LDRNE   v1, [v4]                ; Get the old counter if there was one.
        STMIA   v4!, {a2, a3}           ; Store address and size.
        ADD     v1, v1, #1              ; Increment the counter.
        STR     v1, [v4]                ; Store the counter.

90      MOV     a1,v4
        Pull    "v1,v2,v3,v4,pc"        ; We've done with this block now.



; Subtractv1v2fromRAMtable
;
; On entry: v1 = base of memory area
;           v2 = size of memory area
;           a4 = RAM table handle (ie pointer to terminator word containing number of entries)
;
; On exit:  a1-a3 preserved
;           a4 and RAM table updated
;           other registers corrupted
Subtractv1v2fromRAMtable
        ADD     v2, v1, v2              ; v2 = end address
        MOV     v1, v1, LSR #12
        MOV     v1, v1, LSL #12         ; round base down
        ADD     v2, v2, #4096
        SUB     v2, v2, #1
        MOV     v2, v2, LSR #12
        MOV     v2, v2, LSL #12         ; round end up

        LDR     v5, [a4]
        SUB     v8, a4, v5, LSL #3
10      TEQ     v8, a4
        MOVEQ   pc, lr
        LDMIA   v8!, {v3, v4}
        MOV     v6, v4, LSR #12
        ADD     v6, v3, v6, LSL #12     ; v6 = end of RAM block
        CMP     v2, v3                  ; if our end <= RAM block start
        CMPHI   v6, v1                  ; or RAM block end <= our start
        BLS     %BT10                   ; then no intersection

        MOV     v4, v4, LSL #20         ; extract flags

        CMP     v1, v3
        BHI     not_bottom

        ; our area is at the bottom
        CMP     v2, v6
        BHS     remove_block

        SUB     v6, v6, v2              ; v6 = new size
        ORR     v6, v6, v4, LSR #20     ; + flags
        STMDB   v8, {v2, v6}            ; store new base (= our end) and size
        B       %BT10

        ; we've completely covered a block. Remove it.
remove_block
        MOV     v7, v8
20      TEQ     v7, a4                  ; shuffle down subsequent blocks in table
        LDMNEIA v7, {v3, v4}
        STMNEDB v7, {v3, v4}
        ADDNE   v7, v7, #8
        BNE     %BT20
        SUB     v5, v5, #1
        SUB     a4, a4, #8
        STR     v5, [a4]
        SUB     v8, v8, #8
        B       %BT10

        ; our area is not at the bottom.
not_bottom
        CMP     v2, v6
        BLO     split_block

        ; our area is at the top
        SUB     v6, v1, v3              ; v6 = new size
        ORR     v6, v6, v4, LSR #20     ; + flags
        STMDB   v8, {v3, v6}            ; store original base and new size
        B       %BT10

split_block
        MOV     v7, a4
30      TEQ     v7, v8                  ; shuffle up subsequent blocks in table
        LDMDB   v7, {v3, v4}
        STMNEIA v7, {v3, v4}
        SUBNE   v7, v7, #8
        BNE     %BT30
        ADD     v5, v5, #1
        ADD     a4, a4, #8
        STR     v5, [a4]

        MOV     v4, v4, LSL #20         ; (re)extract flags

        SUB     v7, v1, v3              ; v7 = size of first half
        SUB     v6, v6, v2              ; v6 = size of second half
        ORR     v7, v7, v4, LSR #20
        ORR     v6, v6, v4, LSR #20     ; + flags
        STMDB   v8, {v3, v7}
        STMIA   v8!, {v2, v6}
        B       %BT10


;void RISCOS_Start(unsigned int flags, int *riscos_header, int *hal_header, void *ref)
;

; We don't return, so no need to obey ATPCS, except for parameter passing.
; register usage:   v4 = location of VRAM
;                   v6 = amount of VRAM

        ROUT
RISCOS_Start
        TEQ     a4, #0
01      BEQ     %BT01                           ; Stop here if no RAM

        ; subtract the HAL and OS from the list of RAM areas
        MOV     v1, a2
        LDR     v2, [a2, #OSHdr_ImageSize]
        BL      Subtractv1v2fromRAMtable
        LDR     v1, [a3, #HALDesc_Start]
        ADD     v1, a3, v1
        LDR     v2, [a3, #HALDesc_Size]
        BL      Subtractv1v2fromRAMtable

        LDR     v5, [a4]                        ; v5 = the number of RAM blocks
        SUB     v8, a4, v5, LSL #3              ; Jump back to the start of the list.

        ; Search for some VRAM
05      LDMIA   v8!, {v1, v2}                   ; Get a block from the list. (v1,v2)=(addr,size+flags)
        TST     v2, #OSAddRAM_IsVRAM            ; Is it VRAM?
        BNE     %FT20                           ; If so, deal with it below
        TEQ     v8, a4                          ; Carry on until end of list or we find some.
        BNE     %BT05

        ; Extract some pseudo-VRAM from first DMA-capable RAM block
        SUB     v8, a4, v5, LSL #3              ; Rewind again.
06      LDMIA   v8!, {v1, v2}
        TEQ     v8, a4                          ; End of list?
        TSTNE   v2, #OSAddRAM_NoDMA             ; DMA capable?
        BNE     %BT06
        MOV     v2, v2, LSR #12                 ; Remove flags
        MOV     v2, v2, LSL #12
        ; Is this the only DMA-capable block?
        MOV     v4, v8
        MOV     v6, #OSAddRAM_NoDMA
07      TEQ     v4, a4
        BEQ     %FT08
        LDR     v6, [v4, #4]
        ADD     v4, v4, #8
        TST     v6, #OSAddRAM_NoDMA
        BNE     %BT07
08
        ; v6 has NoDMA set if v8 was the only block
        TST     v6, #OSAddRAM_NoDMA
        MOV     v4, v1                          ; Allocate block as video memory
        MOV     v6, v2
        BEQ     %FT09
        SUBS    v6, v6, #16*1024*1024           ; Leave 16M if it was the only DMA-capable block
        MOVLS   v6, v2, LSR #1                  ; If that overflowed, take half the bank.
09
        CMP     v6, #32*1024*1024
        MOVHS   v6, #32*1024*1024               ; Limit allocation to 32M (arbitrary)

        ADD     v1, v1, v6                      ; Adjust the RAM block base...
        SUBS    v2, v2, v6                      ; ... and the size
        BEQ     %FT22                           ; pack array tighter if this block is all gone
        STR     v1, [v8, #-8]                   ; update base
        LDR     v1, [v8, #-4]
        MOV     v1, v1, LSL #20
        ORR     v1, v1, v2, LSR #12
        MOV     v1, v1, ROR #20                 ; merge flags back into size
        STR     v1, [v8, #-4]                   ; update size
        B       %FT30

        ; Note real VRAM parameters
20      MOV     v6, v2                          ; Remember the size and address
        MOV     v4, v1                          ; of the VRAM
22      TEQ     v8, a4                          ; if not at the end of the array
        LDMNEIA v8, {v1, v2}                    ; pack the array tighter
        STMNEDB v8, {v1, v2}
        ADDNE   v8, v8, #8
        BNE     %BT22
25      SUB     v5, v5, #1                      ; decrease the counter
        STR     v5, [a4, #-8]!                  ; and move the end marker down

30      SUB     v8, a4, v5, LSL #3              ; Rewind to start of list

        ; Scan forwards to find the fastest block of non-DMAable memory which is at least DRAMOffset_LastFixed size
        LDMIA   v8!, {v1, v2}
31
        TEQ     v8, a4
        BEQ     %FT32
        LDMIA   v8!, {v7, ip}
        CMP     ip, #DRAMOffset_LastFixed
        ANDHS   sp, ip, #&F*OSAddRAM_Speed+OSAddRAM_NoDMA
        ANDHS   lr, v2, #&F*OSAddRAM_Speed+OSAddRAM_NoDMA
        ASSERT  OSAddRAM_Speed = 1:SHL:8
        ASSERT  OSAddRAM_NoDMA < OSAddRAM_Speed
        MOVHS   sp, sp, ROR #8                  ; Give NoDMA flag priority over speed when sorting
        CMPHS   sp, lr, ROR #8
        MOVHI   v1, v7
        MOVHI   v2, ip
        B       %BT31
32        
        ; Fill in the Kernel's permanent memory table, sorting by speed and DMA ability
        ; Non-DMAable RAM is preferred over DMAable, as the kernel requires very little DMAable RAM, and we don't want to permanently claim DMAable RAM if we're not actually using it for DMA (in case machine only has a tiny amount available)
        ADD     ip, v1, #DRAMOffset_PageZero

        ADD     sp, v1, #DRAMOffset_ScratchSpace + ScratchSpaceSize

        Push    "a1,a2,a3"                      ; Remember our arguments

        SUB     v8, a4, v5, LSL #3              ; Rewind to start of list
        CMP     v5, #DRAMPhysTableSize          ; Don't overflow our table
        ADDHI   a4, v8, #DRAMPhysTableSize*8 - 8
        
        ; First put the VRAM information in to free up some regs
        ADD     v7, ip, #VideoPhysAddr
        STMIA   v7!, {v4, v6}

        ; Now fill in the rest
        ASSERT  DRAMPhysAddrA = VideoPhysAddr+8
        STMIA   v7!, {v1, v2}                   ; workspace block must be first
33
        TEQ     v8, a4
        BEQ     %FT39
        LDMIA   v8!, {v1, v2}
        CMP     v2, #4096                       ; skip zero-length sections
        BLO     %BT33
        ; Perform insertion sort
        ; a1-a3, v3-v6, ip, lr free
        ADD     a1, ip, #DRAMPhysAddrA
        LDMIA   a1!, {a2, a3}
        TEQ     v1, a2
        BEQ     %BT33                           ; don't duplicate the initial block
        AND     v3, v2, #&F*OSAddRAM_Speed+OSAddRAM_NoDMA
        ASSERT  OSAddRAM_Speed = 1:SHL:8
        ASSERT  OSAddRAM_NoDMA < OSAddRAM_Speed
        MOV     v3, v3, ROR #8                  ; Give NoDMA flag priority over speed when sorting
34
        AND     v4, a3, #&F*OSAddRAM_Speed+OSAddRAM_NoDMA
        CMP     v3, v4, ROR #8
        BHI     %FT35
        TEQ     a1, v7
        LDMNEIA a1!, {a2, a3}
        BNE     %BT34
        ADD     a1, a1, #8
35
        ADD     v7, v7, #8
        ; Insert at a1-8, overwriting {a2, a3}
36
        STMDB   a1, {v1, v2}                   ; store new entry
        TEQ     a1, v7
        MOVNE   v1, a2                         ; if not at end, shuffle
        MOVNE   v2, a3                         ; overwritten entry down one,
        LDMNEIA a1!, {a2, a3}                  ; load next to be overwritten,
        BNE     %BT36                          ; and loop
        B       %BT33

39
        ; Now we have to work out the total RAM size
        MOV     a2, #0
        ADD     v6, ip, #PhysRamTable
        MOV     a3, v6
40
        LDMIA   v6!, {v1, v2}                   ; get address, size
        ADD     a2, a2, v2, LSR #12             ; add on size
        TEQ     v6, v7
        BNE     %BT40
        MOV     a2, a2, LSL #12

        ; Work out how much DMAable RAM the HAL/kernel needs
        LDR     a1, [sp, #8]
        LDR     a1, [a1, #HALDesc_Flags]
        TST     a1, #HALFlag_NCNBWorkspace              ; do they want uncacheable workspace?
        LDRNE   a1, =SoundDMABuffers-CursorChunkAddress + ?SoundDMABuffers + 32*1024 + DRAMOffset_LastFixed
        LDREQ   a1, =SoundDMABuffers-CursorChunkAddress + ?SoundDMABuffers + DRAMOffset_LastFixed
        ; Scan PhysRamTable for a DMAable block of at least this size, extract it, and stash it in InitDMABlock
        ; Once the initial memory claiming is done we can re-insert it
        ADD     a4, a3, #DRAMPhysAddrA-VideoPhysAddr    ; don't claim VRAM
        
        ; First block needs special treatment as we've already claimed some of it
        LDMIA   a4!, {v1, v2}
        TST     v2, #OSAddRAM_NoDMA
        BNE     %FT41
        CMP     v2, a1
        BLO     %FT41
        ; Oh crumbs, the first block is a match for our DMA block
        ; Claim it as normal, but set InitDMAEnd to v1+DRAMOffset_LastFixed so
        ; that the already used bit won't get used for DMA
        ; We also need to be careful later on when picking the initial v2 value
        ADD     lr, v1, #DRAMOffset_LastFixed
        STR     lr, [ip, #InitDMAEnd]
        B       %FT43
41
        ; Go on to check the rest of PhysRamTable
        SUB     a1, a1, #DRAMOffset_LastFixed
42
        LDMIA   a4!, {v1, v2}
        TST     v2, #OSAddRAM_NoDMA
        BNE     %BT42
        CMP     v2, a1
        BLO     %BT42
        ; Make a note of this block
        STR     v1, [ip, #InitDMAEnd]
43
        STR     v1, [ip, #InitDMABlock]
        STR     v2, [ip, #InitDMABlock+4]
        SUB     lr, a4, a3
        STR     lr, [ip, #InitDMAOffset]
        ; Now shrink/remove this memory from PhysRamTable
        SUB     v2, v2, a1
        ADD     v1, v1, a1
        CMP     v2, #4096               ; Block all gone?
        STMHSDB a4, {v1, v2}            ; no, just shrink it
        BHS     %FT55
45
        CMP     a4, v7
        LDMNEIA a4, {v1, v2}
        STMNEDB a4, {v1, v2}
        ADDNE   a4, a4, #8
        BNE     %BT45
        SUB     v7, v7, #8

; a2 = Total memory size (bytes)
; a3 = PhysRamTable
; v7 = After last used entry in PhysRamTable

; now store zeros to fill out table

55
        ADD     v2, a3, #PhysRamTableEnd-PhysRamTable
        MOV     v3, #0
        MOV     v4, #0
57
        CMP     v7, v2
        STMLOIA v7!, {v3, v4}
        BLO     %BT57

; Time to set up the L1PT. Just zero it out for now.

        LDR     a4, =DRAMOffset_L1PT+16*1024-(PhysRamTable+DRAMOffset_PageZero) ; offset from a3 to L1PT end
        ADD     a3, a3, a4
        MOV     a4, #16*1024
        MOV     v2, #0
        MOV     v3, #0
        MOV     v4, #0
        MOV     v5, #0
        MOV     v6, #0
        MOV     v7, #0
        MOV     v8, #0
        MOV     ip, #0
60
        STMDB   a3!, {v2-v8,ip}                         ; start at end and work back
        SUBS    a4, a4, #8*4
        BNE     %BT60

        ADD     v1, a3, #DRAMOffset_PageZero - DRAMOffset_L1PT
        ADD     v2, a3, #DRAMOffset_LastFixed - DRAMOffset_L1PT
        STR     a2, [v1, #RAMLIMIT]                     ; remember the RAM size
        MOV     lr, a2, LSR #12
        SUB     lr, lr, #1
        STR     lr, [v1, #MaxCamEntry]
        MOV     lr, a2, LSR #12-CAM_EntrySizeLog2+12
        CMP     a2, lr, LSL #12-CAM_EntrySizeLog2+12
        ADDNE   lr, lr, #1
        MOV     lr, lr, LSL #12
        STR     lr, [v1, #SoftCamMapSize]
        STR     a3, [v1, #InitUsedStart]                ; store start of L1PT

        ADD     v1, v1, #DRAMPhysAddrA
        MOV     v3, a3

        ; Detect if the DMA claiming adjusted the first block
        ; If so, we'll need to reset v2 to the start of the block at v1
        LDR     a1, [v1]
        ADD     lr, a1, #DRAMOffset_LastFixed
        TEQ     lr, v2
        MOVNE   v2, a1

; For the next batch of allocation routines, v1-v3 are treated as globals.
; v1 -> current entry in PhysRamTable
; v2 -> next address to allocate in v1 (may point at end of v1)
; v3 -> L1PT (or 0 if MMU on - not yet)

; Set up some temporary PCBTrans and PPLTrans pointers, and the initial page flags used by the page tables
        ADD     a1, v3, #DRAMOffset_PageZero - DRAMOffset_L1PT
        BL      Init_PCBTrans

; Allocate the L2PT backing store for the logical L2PT space, to
; prevent recursion.
        LDR     a1, =L2PT
        MOV     a2, #&00400000
        BL      AllocateL2PT

; Allocate workspace for the HAL

        ADD     a4, v3, #DRAMOffset_PageZero - DRAMOffset_L1PT
        LDR     a3, [sp, #8]                            ; recover pushed HAL header
        LDR     a1, =HALWorkspace
        LDR     a2, =AreaFlags_HALWorkspace
        LDR     lr, [a3, #HALDesc_Workspace]            ; their workspace
        LDR     ip, [a3, #HALDesc_NumEntries]           ; plus 1 word per entry
        CMP     ip, #KnownHALEntries
        MOVLO   ip, #KnownHALEntries
        ADD     lr, lr, ip, LSL #2
        MOV     a3, lr, LSR #12                         ; round workspace up to whole
        MOV     a3, a3, LSL #12                         ; number of pages
        CMP     a3, lr
        ADDNE   a3, a3, #&1000
        STR     a3, [a4, #HAL_WsSize]                   ; Make a note of allocated space
        ADD     ip, a1, ip, LSL #2                      ; Their workspace starts
        STR     ip, [a4, #HAL_Workspace]                ; after our table of entries
        BL      Init_MapInRAM

        LDR     a3, [sp, #8]                            ; recover pushed HAL header
        LDR     lr, [a3, #HALDesc_Flags]
        TST     lr, #HALFlag_NCNBWorkspace              ; do they want uncacheable
        LDRNE   a1, =HALWorkspaceNCNB                   ; workspace?
        LDRNE   a2, =AreaFlags_HALWorkspaceNCNB
        LDRNE   a3, =32*1024
        BLNE    Init_MapInRAM_DMA

; Bootstrap time. We want to get the MMU on ASAP. We also don't want to have to
; clear up too much mess later. So what we'll do is map in the three fixed areas
; (L1PT, scratch space and page zero), the CAM, ourselves, and the HAL,
; then turn on the MMU. The CAM will be filled in once the MMU is on, by
; reverse-engineering the page tables?

        ; Map in page zero
        ADD     a1, v3, #DRAMOffset_PageZero - DRAMOffset_L1PT
        LDR     a2, =ZeroPage
        LDR     a3, =AreaFlags_ZeroPage
        MOV     a4, #16*1024
        BL      Init_MapIn

        ; Map in scratch space
        ADD     a1, v3, #DRAMOffset_ScratchSpace - DRAMOffset_L1PT
        MOV     a2, #ScratchSpace
        LDR     a3, =AreaFlags_ScratchSpace
        MOV     a4, #16*1024
        BL      Init_MapIn

        ; Map in L1PT
        MOV     a1, v3
        LDR     a2, =L1PT
        ADD     a3, v3, #DRAMOffset_PageZero - DRAMOffset_L1PT
        LDR     a3, [a3, #PageTable_PageFlags]
        ORR     a3, a3, #PageFlags_Unavailable
        MOV     a4, #16*1024
        BL      Init_MapIn

        ; Map in L1PT again in PhysicalAccess (see below)
        MOV     a1, v3, LSR #20
        MOV     a1, a1, LSL #20                 ; megabyte containing L1PT
        LDR     a2, =PhysicalAccess
        ADD     a3, v3, #DRAMOffset_PageZero - DRAMOffset_L1PT
        LDR     a3, [a3, #PageTable_PageFlags]
        ORR     a3, a3, #PageFlags_Unavailable
        MOV     a4, #1024*1024
        BL      Init_MapIn


        ; Examine HAL and RISC OS locations
        LDMFD   sp, {v4,v5,v6}                  ; v4 = flags, v5 = RO desc, v6 = HAL desc
        LDR     lr, [v6, #HALDesc_Size]
        LDR     v7, [v6, #HALDesc_Start]
        ADD     v6, v6, v7                      ; (v6,v8)=(start,end) of HAL
        ADD     v8, v6, lr

        LDR     v7, [v5, #OSHdr_ImageSize]
        ADD     v7, v5, v7                      ; (v5,v7)=(start,end) of RISC OS

        TEQ     v8, v5                          ; check contiguity (as in a ROM image)
        BNE     %FT70

        ; HAL and RISC OS are contiguous. Yum.
        MOV     a1, v6
        LDR     a2, =RISCOS_Header
        SUB     a2, a2, lr

        SUB     ip, a2, a1                      ; change physical addresses passed in
        LDMIB   sp, {a3, a4}                    ; into logical addresses
        ADD     a3, a3, ip
        ADD     a4, a4, ip
        STMIB   sp, {a3, a4}
        LDR     a3, [v5, #OSHdr_DecompressHdr]  ; check if ROM is compressed, and if so, make writeable
        CMP     a3, #0                          
        MOVNE   a3, #OSAP_None
        MOVEQ   a3, #OSAP_ROM
        SUB     a4, v7, v6
        BL      Init_MapIn
        MOV     a3, v6
        B       %FT75

70
        ; HAL is separate. (We should cope with larger images)
        LDR     a2, =ROM
        MOV     a1, v6
        SUB     ip, a2, a1                      ; change physical address passed in
        LDR     a3, [sp, #8]                    ; into logical address
        ADD     a3, a3, ip
        STR     a3, [sp, #8]
        SUB     a4, v8, v6
        MOV     a3, #OSAP_ROM
        BL      Init_MapIn

        ; And now map in RISC OS
        LDR     a2, =RISCOS_Header              ; Hmm - what if position independent?
        MOV     a1, v5
        SUB     ip, a2, a1                      ; change physical address passed in
        LDR     a3, [sp, #4]                    ; into logical address
        ADD     a3, a3, ip
        STR     a3, [sp, #4]
        SUB     a4, v7, v5
        LDR     a3, [v5, #OSHdr_DecompressHdr]
        CMP     a3, #0
        MOVNE   a3, #0
        MOVEQ   a3, #OSAP_ROM
        BL      Init_MapIn
        MOV     a3, v5
75
        ; We've now allocated all the pages we're going to before the MMU comes on.
        ; Note the end address (for RAM clear)
        ADD     a1, v3, #DRAMOffset_PageZero - DRAMOffset_L1PT
        STR     v1, [a1, #InitUsedBlock]
        STR     v2, [a1, #InitUsedEnd]
        STR     a3, [a1, #ROMPhysAddr]

        ; Note the HAL flags passed in.
        LDR     a2, [sp, #0]
        STR     a2, [a1, #HAL_StartFlags]

        ; Set up a reset IRQ handler (for IIC CMOS access)
        MSR     CPSR_c, #IRQ32_mode + I32_bit + F32_bit
        LDR     sp_irq, =ScratchSpace + 1024    ; 1K is plenty since Reset_IRQ_Handler now runs in SVC mode
        MSR     CPSR_c, #SVC32_mode + I32_bit + F32_bit
        LDR     a2, =Reset_IRQ_Handler
        STR     a2, [a1, #InitIRQHandler]

        ; Fill in some initial processor vectors. These will be used during ARM
        ; analysis, once the MMU is on. We do it here before the data cache is
        ; activated to save any IMB issues.
        ADRL    a2, InitProcVecs
        ADD     a3, a2, #InitProcVecsEnd - InitProcVecs
76      LDR     a4, [a2], #4
        CMP     a2, a3
        STR     a4, [a1], #4
        BLO     %BT76

MMU_activation_zone
; The time has come to activate the MMU. Steady now... Due to unpredictability of MMU
; activation, need to ensure that mapped and unmapped addresses are equivalent. To
; do this, we temporarily make the section containing virtual address MMUon_instr map
; to the same physical address. In case the code crosses a section boundary, do the
; next section as well.
;
        MOV     a1, #4_0000000000000001                         ; domain 0 client only
        ARM_MMU_domain a1

        ADR     a1, MMU_activation_zone
        MOV     a1, a1, LSR #20                 ; a1 = megabyte number (stays there till end)
        ADD     lr, v3, a1, LSL #2              ; lr -> L1PT entry
        LDMIA   lr, {a2, a3}                    ; remember old mappings
 [ MEMM_Type = "VMSAv6"
        LDR     ip, =(AP_ROM * L1_APMult) + L1_Section
 |
  [ ARM6support
        LDR     ip, =(AP_None * L1_APMult) + L1_U + L1_Section
  |
        LDR     ip, =(AP_ROM * L1_APMult) + L1_U + L1_Section
  ]
 ]
        ORR     a4, ip, a1, LSL #20             ; not cacheable, as we don't want
        ADD     v4, a4, #1024*1024              ; to fill the cache with rubbish
        STMIA   lr, {a4, v4}

        MOV     a4, a1
        Push    "a2,lr"
        MOV     a1, v3
        ADD     a2, v3, #DRAMOffset_PageZero-DRAMOffset_L1PT
        BL      SetTTBR
        Pull    "a2,lr"
        BL      Init_ARMarch                    ; corrupts a1 and ip
        MOV     ip, a1                          ; Remember architecture for later
        MOV     a1, a4

        MSREQ   CPSR_c, #F32_bit+I32_bit+UND32_mode ; Recover the soft copy of the CR
        MOVEQ   v5, sp
        ARM_read_control v5, NE
  [ CacheOff
        ORR     v5, v5, #MMUC_M                 ; MMU on
        ORR     v5, v5, #MMUC_R                 ; ROM mode enable
  |
        ORR     v5, v5, #MMUC_W+MMUC_C+MMUC_M   ; Write buffer, data cache, MMU on
        ORR     v5, v5, #MMUC_R+MMUC_Z          ; ROM mode enable, branch predict enable
  ]
  [ MEMM_Type = "VMSAv6"
        ORR     v5, v5, #MMUC_XP ; Extended pages enabled (v6)
        BIC     v5, v5, #MMUC_TRE+MMUC_AFE ; TEX remap, Access Flag disabled
        BIC     v5, v5, #MMUC_EE+MMUC_TE+MMUC_VE ; Exceptions = nonvectored LE ARM
      [ SupportARMv6 :LAND: NoARMv7
        ; Deal with a couple of ARM11 errata
        ARM_read_ID lr
        LDR     a4, =&FFF0
        AND     lr, lr, a4
        LDR     a4, =&B760
        TEQ     lr, a4
        BNE     %FT01
        ORR     v5, v5, #MMUC_FI ; Erratum 716151: Disable hit-under-miss (enable fast interrupt mode) to prevent D-cache corruption from D-cache cleaning (the other workaround, ensuring a DSB exists inbetween the clean op and the next store access to that cache line, feels a bit heavy-handed since we'd probably have to disable IRQs to make it fully safe)
        ; Update the aux control register
        MRC     p15, 0, lr, c1, c0, 1
        ; Bit 28: Erratum 714068: Set PHD bit to prevent deadlock from PLI or I-cache invalidate by MVA
        ; Bit 31: Erratum 716151: Set FIO bit to override some of the behaviour implied by FI bit
        ORR     lr, lr, #(1:SHL:28)+(1:SHL:31)
        MCR     p15, 0, lr, c1, c0, 1
        myISB   ,lr
01
      ]
  ]
  [ NoUnaligned
        ORR     v5, v5, #MMUC_A ; Alignment exceptions on
  ]
  [ HiProcVecs
        ORR     v5, v5, #MMUC_V ; High processor vectors enabled
  ]

MMUon_instr
; Note, no RAM access until we've reached MMUon_nol1ptoverlap and the flat
; logical-physical mapping of the ROM has been removed (we can't guarantee that
; the RAM mapping hasn't been clobbered, and SP is currently bogus).
        ARM_write_control v5
  [ MEMM_Type = "VMSAv6"
        MOV     lr, #0
        myISB   ,lr,,y ; Just in case
  ]
        MOVEQ   sp, v5
        MSREQ   CPSR_c, #F32_bit+I32_bit+SVC32_mode

  [ MEMM_Type = "VMSAv6"
        CMP     ip, #ARMvF
        BEQ     %FT01
        MCRNE   ARM_config_cp,0,lr,ARMv4_cache_reg,C7           ; junk MMU-off contents of I-cache (works on ARMv3)
        B       %FT02
01      MCREQ   p15, 0, lr, c7, c5, 0           ; invalidate instruction cache
        MCREQ   p15, 0, lr, c8, c7, 0           ; invalidate TLBs
        MCREQ   p15, 0, lr, c7, c5, 6           ; invalidate branch predictor
        myISB   ,lr,,y ; Ensure below branch works
        BLEQ    HAL_InvalidateCache_ARMvF       ; invalidate data cache (and instruction+TLBs again!)
02
  |
        MOV     lr, #0                                          ; junk MMU-off contents of I-cache
        MCR     ARM_config_cp,0,lr,ARMv4_cache_reg,C7           ; (works on ARMv3)
  ]

; MMU now on. Need to jump to logical copy of ourselves. Complication arises if our
; physical address overlaps our logical address - in that case we need to map
; in another disjoint copy of ourselves and branch to that first, then restore the
; original two sections.
        ADRL    a4, RISCOS_Header
        LDR     ip, =RISCOS_Header
        SUB     ip, ip, a4
        ADR     a4, MMU_activation_zone
        MOV     a4, a4, LSR #20
        MOV     a4, a4, LSL #20                 ; a4 = base of scrambled region
        ADD     v4, a4, #2*1024*1024            ; v4 = top of scrambled region
        SUB     v4, v4, #1                      ;      (inclusive, in case wrapped to 0)
        ADR     v5, MMUon_resume
        ADD     v5, v5, ip                      ; v5 = virtual address of MMUon_resume
        CMP     v5, a4
        BLO     MMUon_nooverlap
        CMP     v5, v4
        BHI     MMUon_nooverlap

        ASSERT  ROM > 3*1024*1024
; Oh dear. We know the ROM lives high up, so we'll mangle 00100000-002FFFFF.
; But as we're overlapping the ROM, we know we're not overlapping the page tables.
        LDR     lr, =L1PT                       ; accessing the L1PT virtually now
 [ MEMM_Type = "VMSAv6"
        LDR     ip, =(AP_ROM * L1_APMult) + L1_Section
 |
  [ ARM6support
        LDR     ip, =(AP_None * L1_APMult) + L1_U + L1_Section
  |
        LDR     ip, =(AP_ROM * L1_APMult) + L1_U + L1_Section
  ]
 ]
        ORR     v6, a4, ip
        ADD     ip, v6, #1024*1024
        LDMIB   lr, {v7, v8}                    ; sections 1 and 2
        STMIB   lr, {v6, ip}
        RSB     ip, a4, #&00100000
        ADD     pc, pc, ip
        NOP
MMUon_overlapresume                             ; now executing from 00100000
        ADD     ip, lr, a4, LSR #18
        STMIA   ip, {a2, a3}                    ; restore original set of mappings
        BL      Init_PageTablesChanged

        MOV     a2, v7                          ; arrange for code below
        MOV     a3, v8                          ; to restore section 1+2 instead
        MOV     a1, #1

MMUon_nooverlap
        ADRL    lr, RISCOS_Header
        LDR     ip, =RISCOS_Header
        SUB     ip, ip, lr
        ADD     pc, pc, ip
        NOP
MMUon_resume
; What if the logical address of the page tables is at the physical address of the code?
; Then we have to access it via PhysicalAccess instead.
        LDR     lr, =L1PT
        CMP     lr, a4
        BLO     MMUon_nol1ptoverlap
        CMP     lr, v4
        BHI     MMUon_nol1ptoverlap
; PhysicalAccess points to the megabyte containing the L1PT. Find the L1PT within it.
        LDR     lr, =PhysicalAccess
        MOV     v6, v3, LSL #12
        ORR     lr, lr, v6, LSR #12
MMUon_nol1ptoverlap
        ADD     lr, lr, a1, LSL #2
        STMIA   lr, {a2, a3}
        BL      Init_PageTablesChanged

; The MMU is now on. Wahey. Let's get allocating.

        LDR     sp, =ScratchSpace + ScratchSpaceSize - 4*3 ; 3 items already on stack :)

        LDR     a1, =ZeroPage

        ADD     lr, v3, #DRAMOffset_PageZero-DRAMOffset_L1PT   ; lr = PhysAddr of zero page
        SUB     v1, v1, lr
        ADD     v1, v1, a1                              ; turn v1 from PhysAddr to LogAddr

        LDR     a2, [a1, #InitUsedBlock]                ; turn this from Phys to Log too
        SUB     a2, a2, lr
        ADD     a2, a2, a1
        STR     a2, [a1, #InitUsedBlock]


; Store the logical address of the HAL descriptor
        LDR     a2, [sp, #8]
        STR     a2, [a1, #HAL_Descriptor]

        MOV     v3, #0                                  ; "MMU is on" signal

        BL      ARM_Analyse

        ChangedProcVecs a1

        MOV     a1, #L1_Fault
        BL      RISCOS_ReleasePhysicalAddress

        LDR     a1, =HALWorkspace
        LDR     a2, =ZeroPage
        LDR     a3, [a2, #HAL_WsSize]
      [ ZeroPage <> 0
        MOV     a2, #0
      ]
        BL      memset

        LDR     a2, =ZeroPage
        LDR     a1, =IOLimit
        STR     a1, [a2, #IOAllocLimit]
        LDR     a1, =IO
        STR     a1, [a2, #IOAllocPtr]

        BL      SetUpHALEntryTable

; Initialise the HAL. Due to its memory claiming we need to get our v1 and v2 values
; into workspace and out again around it.

        LDR     a1, =ZeroPage
        STR     v1, [a1, #InitUsedBlock]
        STR     v2, [a1, #InitUsedEnd]

        LDR     a1, =RISCOS_Header
        LDR     a2, =HALWorkspaceNCNB
        AddressHAL
        CallHAL HAL_Init

        DebugTX "HAL initialised"

        MOV     a1, #64 ; Old limit prior to OMAP3 port
        CallHAL HAL_IRQMax
        CMP     a1, #MaxInterrupts
        MOVHI   a1, #MaxInterrupts ; Avoid catastrophic failure if someone forgot to increase MaxInterrupts
        LDR     a2, =ZeroPage
        STR     a1, [a2, #IRQMax]        

        LDR     v1, [a2, #InitUsedBlock]
        LDR     v2, [a2, #InitUsedEnd]

; Start timer zero, at 100 ticks per second
        MOV     a1, #0
        CallHAL HAL_TimerGranularity

        MOV     a2, a1
        MOV     a1, #100
        BL      __rt_udiv

        MOV     a2, a1
        MOV     a1, #0
        CallHAL HAL_TimerSetPeriod

        DebugTX "IICInit"

        BL      IICInit

; Remember some stuff that's about to get zapped
        LDR     ip, =ZeroPage
        LDR     v4, [ip, #ROMPhysAddr]
        LDR     v5, [ip, #RAMLIMIT]
        LDR     v7, [ip, #MaxCamEntry]
        LDR     v8, [ip, #IRQMax]

        LDR     a1, [ip, #HAL_StartFlags]
        TST     a1, #OSStartFlag_RAMCleared
        BLEQ    ClearWkspRAM            ; Only clear the memory if the HAL didn't
         
; Put it back
        LDR     ip, =ZeroPage
        STR     v4, [ip, #ROMPhysAddr]
        STR     v5, [ip, #RAMLIMIT]
        STR     v7, [ip, #MaxCamEntry]
        STR     v8, [ip, #IRQMax]

; Calculate CPU feature flags
        BL      ReadCPUFeatures

        MOV     v8, ip

        DebugTX "HAL_CleanerSpace"

; Set up the data cache cleaner space if necessary (eg. for StrongARM core)
        MOV     a1, #-1
        CallHAL HAL_CleanerSpace
        CMP     a1, #-1          ;-1 means none needed (HAL only knows this if for specific ARM core eg. system-on-chip)
        BEQ     %FT20
        LDR     a2, =DCacheCleanAddress
        LDR     a3, =AreaFlags_DCacheClean
        ASSERT  DCacheCleanSize = 4*&10000                ; 64k of physical space used 4 times (allows large page mapping)
        MOV     a4, #&10000
        MOV     ip, #4
        SUB     sp, sp, #5*4       ;room for a1-a4,ip
10
        STMIA   sp, {a1-a4, ip}
        BL      Init_MapIn
        LDMIA   sp, {a1-a4, ip}
        SUBS    ip, ip, #1
        ADD     a2, a2, #&10000
        BNE     %BT10
        ADD     sp, sp, #5*4

20
; Decompress the ROM
        LDR     a1, =RISCOS_Header
        LDR     a2, [a1, #OSHdr_DecompressHdr]
        CMP     a2, #0
        BEQ     %FT30
        ADD     ip, a1, a2
        ASSERT  OSDecompHdr_WSSize = 0
        ASSERT  OSDecompHdr_Code = 4
        LDMIA   ip, {a3-a4}
        ADRL    a2, SyncCodeAreas
        CMP     a3, #0 ; Any workspace required?
        ADD     a4, a4, ip
   [ DebugHALTX
        BNE     %FT25
        DebugTX "Decompressing ROM, no workspace required"
      [ NoARMv5
        MOV     lr, pc
        MOV     pc, a4
      |
        BLX     a4
      ]
        DebugTX "Decompression complete"
        B       %FT27
25
   |
        ADREQ   lr, %FT27
        MOVEQ   pc, a4
   ]
        Push    "a1-a4,v1-v2,v5-v7"
; Allocate workspace for decompression code
; Workspace is located at a 4MB-aligned log addr, and is a multiple of 1MB in
; size. This greatly simplifies the code required to free the workspace, since
; we can guarantee it will have been section-mapped, and won't hit any
; partially-allocated L2PT blocks (where 4 L1PT entries point to subsections of
; the same L2PT page)
; This means all we need to do to free the workspace is zap the L1PT entries
; and rollback v1 & v2
; Note: This is effectively a MB-aligned version of Init_MapInRAM
ROMDecompWSAddr * 4<<20
        DebugTX "Allocating decompression workspace"
        LDR     v5, =(1<<20)-1
        ADD     v7, a3, v5
        BIC     v7, v7, v5 ; MB-aligned size
        STR     v7, [sp, #8] ; Overwrite stacked WS size
        MOV     v6, #ROMDecompWSAddr ; Current log addr
26
        ADD     v2, v2, v5
        BIC     v2, v2, v5 ; MB-aligned physram
        LDMIA   v1, {a2, a3}
        SUB     a2, v2, a2 ; Amount of bank used
        SUB     a2, a3, a2 ; Amount of bank remaining
        MOVS    a2, a2, ASR #20 ; Round down to nearest MB
        LDRLE   v2, [v1, #8]! ; Move to next bank if 0MB left
        BLE     %BT26
        CMP     a2, v7, LSR #20
        MOVHS   a4, v7
        MOVLO   a4, a2, LSL #20 ; a4 = amount to take
        MOV     a1, v2 ; set up parameters for MapIn call
        MOV     a2, v6
        MOV     a3, #OSAP_None
        SUB     v7, v7, a4 ; Decrease amount to allocate
        ADD     v2, v2, a4 ; Increase physram ptr
        ADD     v6, v6, a4 ; Increase logram ptr
        BL      Init_MapIn
        CMP     v7, #0
        BNE     %BT26
        Pull    "a1-a2,v1-v2" ; Pull OS header, IMB func ptr, workspace size, decompression code
        MOV     a3, #ROMDecompWSAddr
        DebugTX "Decompressing ROM"
      [ NoARMv5
        MOV     lr, pc
        MOV     pc, v2
      |
        BLX     v2
      ]
        DebugTX "Decompression complete"
; Before we free the workspace, make sure we zero it
        MOV     a1, #ROMDecompWSAddr
        MOV     a2, #0
        MOV     a3, v1
        BL      memset
; Flush the workspace from the cache so we can unmap it
; Really we should make the pages uncacheable first, but for simplicity we do a
; full cache+TLB clean+invalidate later on when changing the ROM permissions
        MOV     a1, #ROMDecompWSAddr
        ADD     a2, a1, v1
        ARMop   Cache_CleanInvalidateRange
; Zero each L1PT entry
        LDR     a1, =L1PT+(ROMDecompWSAddr>>18)
        MOV     a2, #0
        MOV     a3, v1, LSR #18
        BL      memset
; Pop our registers and we're done
        Pull    "v1-v2,v5-v7"
        DebugTX "ROM decompression workspace freed"
27
; Now that the ROM is decompressed we need to change the ROM page mapping to
; read-only. The easiest way to do this is to make another call to Init_MapIn.
; But before we can do that we need to work out if the HAL+OS are contiguous in
; physical space. To do this we can just check if the L1PT entry for the OS is a
; section mapping.
        LDR     a1, =L1PT+(ROM>>18)
        LDR     a1, [a1]
        ASSERT  L1_Section = 2
        ASSERT  L1_Page = 1
        TST     a1, #2
; Section mapped, get address from L1PT
        MOVNE   a1, a1, LSR #20
        MOVNE   a1, a1, LSL #20
        MOVNE   a2, #ROM
        MOVNE   a4, #OSROM_ImageSize*1024
        BNE     %FT29
; Page/large page mapped, get address from L2PT
        LDR     a2, =RISCOS_Header
        LDR     a1, =L2PT
        LDR     a1, [a1, a2, LSR #10]
        LDR     a4, [a2, #OSHdr_ImageSize]
        MOV     a1, a1, LSR #12
        MOV     a1, a1, LSL #12
29
        MOV     a3, #OSAP_ROM
        BL      Init_MapIn
; Flush & invalidate cache/TLB to ensure everything respects the new page access
; Putting a flush here also means the decompression code doesn't have to worry
; about IMB'ing the decompressed ROM
        ARMop   MMU_Changing ; Perform full clean+invalidate to ensure any lingering cache lines for the decompression workspace are gone
        DebugTX "ROM access changed to read-only"
30
; Allocate the CAM
        LDR     a3, [v8, #SoftCamMapSize]
        LDR     a2, =AreaFlags_CAM
        LDR     a1, =CAM
        BL      Init_MapInRAM

; Allocate the supervisor stack
        LDR     a1, =SVCStackAddress
        LDR     a2, =AreaFlags_SVCStack
        LDR     a3, =SVCStackSize
        BL      Init_MapInRAM

; Allocate the interrupt stack
        LDR     a1, =IRQStackAddress
        LDR     a2, =AreaFlags_IRQStack
        LDR     a3, =IRQStackSize
        BL      Init_MapInRAM

; Allocate the abort stack
        LDR     a1, =ABTStackAddress
        LDR     a2, =AreaFlags_ABTStack
        LDR     a3, =ABTStackSize
        BL      Init_MapInRAM

; Allocate the undefined stack
        LDR     a1, =UNDStackAddress
        LDR     a2, =AreaFlags_UNDStack
        LDR     a3, =UNDStackSize
        BL      Init_MapInRAM

; Allocate the system heap (just 32K for now - will grow as needed)
        LDR     a1, =SysHeapAddress
        LDR     a2, =AreaFlags_SysHeap
        LDR     a3, =32*1024
        BL      Init_MapInRAM_Clear

; Allocate the cursor/system/sound block - first the cached bit
        LDR     a1, =CursorChunkAddress
        LDR     a2, =AreaFlags_CursorChunkCacheable
        LDR     a3, =SoundDMABuffers - CursorChunkAddress
        BL      Init_MapInRAM_DMA
; then the uncached bit
        LDR     a1, =SoundDMABuffers
        LDR     a2, =AreaFlags_CursorChunk
        LDR     a3, =?SoundDMABuffers
        BL      Init_MapInRAM_DMA

        LDR     a1, =KbuffsBaseAddress
        LDR     a2, =AreaFlags_Kbuffs
        LDR     a3, =(KbuffsSize + &FFF) :AND: &FFFFF000  ;(round to 4k)
        BL      Init_MapInRAM_Clear

 [ HiProcVecs
        ; Map in DebuggerSpace
        LDR     a1, =DebuggerSpace
        LDR     a2, =AreaFlags_DebuggerSpace
        LDR     a3, =(DebuggerSpace_Size + &FFF) :AND: &FFFFF000
        BL      Init_MapInRAM_Clear
 ]

 [ MinorL2PThack
; Allocate backing L2PT for application space
; Note that ranges must be 4M aligned, as AllocateL2PT only does individual
; (1M) sections, rather than 4 at a time, corresponding to a L2PT page. The
; following space is available for dynamic areas, and ChangeDyn.s will get
; upset if it sees only some out of a set of 4 section entries pointing to the
; L2PT page.
        MOV     a1, #0
        MOV     a2, #AplWorkMaxSize             ; Not quite right, but the whole thing's wrong anyway
        ASSERT  AplWorkMaxSize :MOD: (4*1024*1024) = 0
        BL      AllocateL2PT
; And for the system heap. Sigh
        LDR     a1, =SysHeapAddress
        LDR     a2, =SysHeapMaxSize
        ASSERT  SysHeapAddress :MOD: (4*1024*1024) = 0 
        ASSERT  SysHeapMaxSize :MOD: (4*1024*1024) = 0
        BL      AllocateL2PT
 ]

        STR     v2, [v8, #InitUsedEnd]

        ; Put InitDMABlock back into PhysRamTable
        Push    "v1-v7"
        ASSERT  InitDMAOffset = InitDMABlock+8
        ADD     v1, v8, #InitDMABlock
        LDMIA   v1, {v1-v3}
        ADD     v3, v3, #PhysRamTable
        ADD     v3, v3, v8
        ; Work out whether the block was removed or merely shrunk
        LDMDB   v3, {v4-v5}
        ADD     v6, v1, v2
        ADD     v7, v4, v5
        STMDB   v3, {v1-v2}
        TEQ     v6, v7
        BEQ     %FT40                   ; End addresses match, it was shrunk
35
        LDMIA   v3, {v1-v2}             ; Shuffle following entries down
        STMIA   v3!, {v4-v5}
        MOV     v4, v1
        MOVS    v5, v2
        BNE     %BT35
40
        Pull    "v1-v7"

        MSR     CPSR_c, #F32_bit+I32_bit+IRQ32_mode
        LDR     sp, =IRQSTK
        MSR     CPSR_c, #F32_bit+I32_bit+ABT32_mode
        LDR     sp, =ABTSTK
        MSR     CPSR_c, #F32_bit+I32_bit+UND32_mode
        LDR     sp, =UNDSTK
        MSR     CPSR_c, #F32_bit+SVC2632
        LDR     sp, =SVCSTK

        LDR     ip, =CAM
        STR     ip, [v8, #CamEntriesPointer]

        BL      ConstructCAMfromPageTables

        MOV     a1, #4096
        STR     a1, [v8, #Page_Size]

        BL      CountPageTablePages

        B       Continue_after_HALInit

        LTORG

 [ MEMM_Type = "VMSAv6"
HAL_InvalidateCache_ARMvF
        ; Cache invalidation for ARMs with multiple cache levels, used before ARMop initialisation
        ; This function gets called before we have a stack set up, so we've got to preserve as many registers as possible
        ; The only register we can safely change is ip, but we can switch into FIQ mode with interrupts disabled and use the banked registers there
        MRS     ip, CPSR
        MSR     CPSR_c, #F32_bit+I32_bit+FIQ32_mode
        MOV     r9, #0
        MCR     p15, 0, r9, c7, c5, 0           ; invalidate instruction cache
        MCR     p15, 0, r9, c8, c7, 0           ; invalidate TLBs
        MCR     p15, 0, r9, c7, c5, 6           ; invalidate branch target predictor
        myDSB   ,r9,,y                          ; Wait for completion
        myISB   ,r9,,y
        ; Check whether we're ARMv7 (and thus multi-level cache) or ARMv6 (and thus single-level cache)
        MRC     p15, 0, r8, c0, c0, 1
        TST     r8, #&80000000 ; EQ=ARMv6, NE=ARMv7
        BEQ     %FT80

        ; This is basically the same algorithm as the MaintainDataCache_WB_CR7_Lx macro, but tweaked to use less registers and to read from CP15 directly
        MRC     p15, 1, r8, c0, c0, 1           ; Read CLIDR to r8
        TST     r8, #&07000000
        BEQ     %FT50
        MOV     r11, #0 ; Current cache level
10 ; Loop1
        ADD     r10, r11, r11, LSR #1 ; Work out 3 x cachelevel
        MOV     r9, r8, LSR r10 ; bottom 3 bits are the Cache type for this level
        AND     r9, r9, #7 ; get those 3 bits alone
        CMP     r9, #2
        BLT     %FT40 ; no cache or only instruction cache at this level
        MCR     p15, 2, r11, c0, c0, 0 ; write CSSELR from r11
        ISB
        MRC     p15, 1, r9, c0, c0, 0 ; read current CSSIDR to r9
        AND     r10, r9, #CCSIDR_LineSize_mask ; extract the line length field
        ADD     r10, r10, #4 ; add 4 for the line length offset (log2 16 bytes)
        LDR     r8, =CCSIDR_Associativity_mask:SHR:CCSIDR_Associativity_pos
        AND     r8, r8, r9, LSR #CCSIDR_Associativity_pos ; r8 is the max number on the way size (right aligned)
        CLZ     r13, r8 ; r13 is the bit position of the way size increment
        LDR     r12, =CCSIDR_NumSets_mask:SHR:CCSIDR_NumSets_pos
        AND     r12, r12, r9, LSR #CCSIDR_NumSets_pos ; r12 is the max number of the index size (right aligned)
20 ; Loop2
        MOV     r9, r12 ; r9 working copy of the max index size (right aligned)
30 ; Loop3
        ORR     r14, r11, r8, LSL r13 ; factor in the way number and cache number into r14
        ORR     r14, r14, r9, LSL r10 ; factor in the index number
        DCISW   r14 ; Invalidate
        SUBS    r9, r9, #1 ; decrement the index
        BGE     %BT30
        SUBS    r8, r8, #1 ; decrement the way number
        BGE     %BT20
        DSB                ; Cortex-A7 errata 814220: DSB required when changing cache levels when using set/way operations. This also counts as our end-of-maintenance DSB.
        MRC     p15, 1, r8, c0, c0, 1
40 ; Skip
        ADD     r11, r11, #2
        AND     r14, r8, #&07000000
        CMP     r14, r11, LSL #23
        BGT     %BT10        

50 ; Finished
        ; Wait for clean to complete
        MOV     r8, #0
        MCR     p15, 0, r8, c7, c5, 0           ; invalidate instruction cache
        MCR     p15, 0, r8, c8, c7, 0           ; invalidate TLBs
        MCR     p15, 0, r8, c7, c5, 6           ; invalidate branch target predictor
        myDSB   ,r8,,y                          ; Wait for completion
        myISB   ,r8,,y
        ; All caches clean; switch back to SVC, then recover the stored PSR from ip (although we can be fairly certain we started in SVC anyway)
        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode
        MSR     CPSR_cxsf, ip
        MOV     pc, lr
80 ; ARMv6 case
        MCR     ARM_config_cp,0,r9,ARMv4_cache_reg,C7 ; ARMv3-ARMv6 I+D cache flush
        B       %BT50
 ] ; MEMM_Type = "VMSAv6"

CountPageTablePages ROUT
        Entry
        LDR     a1, =ZeroPage
        LDR     a2, =CAM
        LDR     a3, [a1, #MaxCamEntry]
      [ ZeroPage <> 0
        MOV     a1, #0
      ]
        ADD     a3, a3, #1
        ADD     a4, a2, a3, LSL #CAM_EntrySizeLog2
        ASSERT  (L2PT :AND: &3FFFFF) = 0
        LDR     lr, =L2PT :SHR: 22
10      LDR     ip, [a4, #CAM_LogAddr-CAM_EntrySize]!
        TEQ     lr, ip, LSR #22
        ADDEQ   a1, a1, #4096
        TEQ     a4, a2
        BNE     %BT10
        LDR     a2, =ZeroPage
        STR     a1, [a2, #L2PTUsed]
        EXIT

; int PhysAddrToPageNo(void *addr)
;
; Converts a physical address to the page number of the page containing it.
; Returns -1 if address is not in RAM.

PhysAddrToPageNo
        MOV     a4, #0
        LDR     ip, =ZeroPage + PhysRamTable
10      LDMIA   ip!, {a2, a3}                   ; get phys addr, size
        MOVS    a3, a3, LSR #12                 ; end of list? (size=0)
        BEQ     %FT90                           ;   then it ain't RAM
        SUB     a2, a1, a2                      ; a2 = amount into this bank
        CMP     a2, a3, LSL #12                 ; if more than size
        ADDHS   a4, a4, a3, LSL #12             ;   increase counter by size of bank
        BHS     %BT10                           ;   and move to next
        ADD     a4, a4, a2                      ; add offset to counter
        MOV     a1, a4, LSR #12                 ; convert counter to a page number
        MOV     pc, lr

90      MOV     a1, #-1
        MOV     pc, lr


; A routine to construct the soft CAM from the page tables. This is used
; after a soft reset, and also on a hard reset as it's an easy way of
; clearing up after the recursive page table allocaton.

        ROUT
ConstructCAMfromPageTables
        Push    "v1-v8, lr"
        LDR     a1, =ZeroPage
        LDR     a2, [a1, #MaxCamEntry]
        LDR     v1, =CAM                        ; v1 -> CAM (for whole routine)
        ADD     a2, a2, #1
        ADD     a2, v1, a2, LSL #CAM_EntrySizeLog2

        LDR     a3, =DuffEntry                  ; Clear the whole CAM, from
        MOV     a4, #AreaFlags_Duff             ; the top down.
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        ASSERT  CAM_PMP=8
        ASSERT  CAM_PMPIndex=12
        ASSERT  CAM_EntrySize=16
        MOV     v2, #0
        MOV     v3, #-1
10      STMDB   a2!, {a3, a4, v2, v3}
        CMP     a2, v1
        BHI     %BT10

        MOV     v2, #0                          ; v2 = logical address
        LDR     v3, =L1PT                       ; v3 -> L1PT (not used much)
        LDR     v4, =L2PT                       ; v4 -> L2PT
30      LDR     a1, [v3, v2, LSR #18]           ; a1 = first level descriptor
        BL      DecodeL1Entry                   ; a1 = phys addr, a2 = page flags/type
        CMP     a2, #-2                         ; Only care about page table pointers
        BEQ     %FT40
        ADDS    v2, v2, #&00100000
        BCC     %BT30
        Pull    "v1-v8, pc"

40      LDR     a1, [v4, v2, LSR #10]           ; a1 = second level descriptor
        BL      DecodeL2Entry                   ; a1 = phys addr, a2 = flags (-1 if fault), a3 = page size (bytes)
        CMP     a2, #-1                         ; move to next page if fault
        BEQ     %FT80
        SUBS    a3, a3, #4096                   ; large pages get bits 12-15 from the virtual address
        ANDNE   lr, v2, a3
        ORR     v6, a2, #PageFlags_Unavailable
        ORRNE   a1, a1, lr
        BL      PhysAddrToPageNo                ; -1 if unknown page
        ADDS    a1, v1, a1, LSL #CAM_EntrySizeLog2 ; a1 -> CAM entry
        ASSERT  CAM_LogAddr=0
        ASSERT  CAM_PageFlags=4
        STMCCIA a1, {v2, v6}                    ; store logical address, PPL
 
80      ADD     v2, v2, #&00001000
        TST     v2, #&000FF000
        BNE     %BT40
        TEQ     v2, #0                          ; yuck (could use C from ADDS but TST corrupts C
        BNE     %BT30                           ; because of big constant)
        
        Pull    "v1-v8, pc"



; Allocate a physical page from DRAM
;
; On entry:
;    v1 -> current entry in PhysRamTable
;    v2 -> end of last used physical page
; On exit:
;    a1 -> next free page
;    v1, v2 updated
;
; No out of memory check...

Init_ClaimPhysicalPage
        MOV     a1, v2
        LDMIA   v1, {a2, a3}
        MOV     a3, a3, LSR #12
        ADD     a2, a2, a3, LSL #12             ; ip = end of this bank
        CMP     v2, a2                          ; advance v2 to next bank if
        LDRHS   a1, [v1, #8]!                   ; this bank is fully used
        ADD     v2, a1, #4096
        MOV     pc, lr

; Allocate and map in some RAM.
;
; On entry:
;    a1 = logical address
;    a2 = access permissions (see Init_MapIn)
;    a3 = length (4K multiple)
;    v1 -> current entry in PhysRamTable
;    v2 = next physical address
;    v3 -> L1PT
;
; On exit:
;    a1 -> physical address of start of RAM (deduce the rest from PhysRamTable)
;
; No out of memory check...
Init_MapInRAM ROUT
        Push    "v4-v8,lr"
        MOV     v8, #-1
        MOV     v5, a3                          ; v5 = amount of memory required
        MOV     v6, a1                          ; v6 = logical address
        MOV     v7, a2                          ; v7 = access permissions
10      LDMIA   v1, {v4, ip}                    ; v4 = addr of bank, ip = len+flags
        MOV     ip, ip, LSR #12
        SUB     v4, v2, v4                      ; v4 = amount of bank used
        RSBS    v4, v4, ip, LSL #12             ; v4 = amount of bank left
        LDREQ   v2, [v1, #8]!                   ; move to next bank if 0 left
        BEQ     %BT10

        CMP     v8, #-1                         ; is this the first bank?
        MOVEQ   v8, v2                          ; remember it

        CMP     v4, v5                          ; sufficient in this bank?
        MOVHS   a4, v5
        MOVLO   a4, v4                          ; a4 = amount to take

        MOV     a1, v2                          ; set up parameters for MapIn call
        MOV     a2, v6                          ; then move globals (in case MapIn
        MOV     a3, v7                          ; needs to allocate for L2PT)
        ADD     v2, v2, a4                      ; advance physaddr
        SUB     v5, v5, a4                      ; decrease wanted
        ADD     v6, v6, a4                      ; advance address pointer
        BL      Init_MapIn                      ; map in the RAM
        TEQ     v5, #0                          ; more memory still required?
        BNE     %BT10

        MOV     a1, v8
        Pull    "v4-v8,pc"

Init_MapInRAM_Clear ROUT                        ; same as Init_MapInRAM but also
        Push    "a1,a3,v5,lr"                   ; clears the mapped in result
        BL      Init_MapInRAM
        MOV     v5, a1
        Pull    "a1,a3"
        MOV     a2, #0
        BL      memset        
        MOV     a1, v5
        Pull    "v5,pc"

; Allocate and map a physically contigous chunk of some DMAable RAM.
;
; On entry:
;    a1 = logical address
;    a2 = access permissions (see Init_MapIn)
;    a3 = length (4K multiple)
;    v1 -> current entry in PhysRamTable
;    v2 = next physical address
;    v3 -> L1PT
;
; On exit:
;    a1 -> physical address of start of RAM (deduce the rest from PhysRamTable)
;
; Use this routine with caution - correct total amount of required DMA memory
; must have been calculated beforehand and stashed in InitDMABlock
Init_MapInRAM_DMA ROUT
        Push    "a1,a3,v4-v5,ip,lr"
        TEQ     v3, #0                          ; MMU on?
        LDREQ   v4, =ZeroPage                   ; get workspace directly
        ADDNE   v4, v3, #DRAMOffset_PageZero-DRAMOffset_L1PT ; deduce from L1PT
        LDR     v5, [v4, #InitDMAEnd]
        ADD     lr, v5, a3                      ; claim the RAM
        STR     lr, [v4, #InitDMAEnd]

        MOV     a4, a3
        MOV     a3, a2
        MOV     a2, a1
        MOV     a1, v5
        BL      Init_MapIn                      ; map it in
        ; DMA regions won't get cleared by ClearWkspRam, so do it manually
        ; Could potentially skip this if the HAL says RAM is already clear, but
        ; for now do it anyway (especially since startup flags haven't been set
        ; when we're first called)
        Pull    "a1,a3"
        TEQ     v3, #0
        MOVNE   a1, v5
        MOV     a2, #0
        BL      memset        
        MOV     a1, v5
        Pull    "v4-v5,ip,pc"

; Map a range of physical addresses to a range of logical addresses.
;
; On entry:
;    a1 = physical address
;    a2 = logical address
;    a3 = DA flags
;    a4 = area size (4K multiple)
;    v1 -> current entry in PhysRamTable
;    v2 = last used physical address
;    v3 -> L1PT (or 0 if MMU on)

Init_MapIn ROUT
        Entry   "v4-v7"
        MOV     v4, a1                          ; v4 = physaddr
        MOV     v5, a2                          ; v5 = logaddr
        MOV     v6, a3                          ; v6 = page flags
        MOV     v7, a4                          ; v7 = area size
        ; Set up a2-a4 for the Get*PTE functions
        TEQ     v3, #0
        LDREQ   a3, =ZeroPage
        ADDNE   a3, v3, #DRAMOffset_PageZero-DRAMOffset_L1PT
        MOV     a2, v6
        LDR     a4, [a3, #MMU_PCBTrans]
        LDR     a3, [a3, #MMU_PPLTrans]

        ORR     lr, v4, v5                      ; OR together, physaddr, logaddr
        ORR     lr, lr, v7                      ; and size.
        MOVS    ip, lr, LSL #12                 ; If all bottom 20 bits 0
        BEQ     %FT50                           ; it's section mapped

        MOV     a1, #0                          ; We don't want the address in the result

        MOVS    ip, lr, LSL #16                 ; If bottom 16 bits not all 0
        ADR     lr, %FT10
        BNE     Get4KPTE                        ; then small pages (4K)

        BL      Get64KPTE                       ; else large pages (64K)
10
        MOV     v6, a1                          ; v6 = access permissions

20      MOV     a1, v4
        MOV     a2, v5
        MOV     a3, v6
        BL      Init_MapInPage                  ; Loop through mapping in each
        ADD     v4, v4, #4096                   ; page in turn
        ADD     v5, v5, #4096
        SUBS    v7, v7, #4096
        BNE     %BT20
        EXIT

50
        BL      Get1MPTE
        MOVS    ip, v3                          ; is MMU on?
        LDREQ   ip, =L1PT                       ; then use virtual address
        ADD     a2, ip, v5, LSR #18             ; a2 -> L1PT entry
70      STR     a1, [a2], #4                    ; And store in L1PT
        ADD     a1, a1, #1024*1024              ; Advance one megabyte
        SUBS    v7, v7, #1024*1024              ; and loop
        BNE     %BT70
        EXIT

; Map a logical page to a physical page, allocating L2PT as necessary.
;
; On entry:
;    a1 = physical address
;    a2 = logical address
;    a3 = access permissions + C + B bits + size (all non-address bits, of appropriate type)
;    v1 -> current entry in PhysRamTable
;    v2 = last used physical address
;    v3 -> L1PT (or 0 if MMU on)
; On exit:
;    a1 = logical address
;    a2-a4, ip corrupt
;    v1, v2 updated
;

Init_MapInPage  ROUT
        Entry   "v4-v6"
        MOV     v4, a1                          ; v4 = physical address
        MOV     v5, a2                          ; v5 = logical address
        MOV     v6, a3                          ; v6 = access permissions
        MOV     a1, v5
        MOV     a2, #4096
        BL      AllocateL2PT
        TEQ     v3, #0                          ; if MMU on, access L2PT virtually...
        LDREQ   a1, =L2PT                       ; a1 -> L2PT virtual address
        MOVEQ   ip, v5                          ; index using whole address
        BEQ     %FT40
        MOV     ip, v5, LSR #20
        LDR     a1, [v3, ip, LSL #2]            ; a1 = level one descriptor
        MOV     a1, a1, LSR #10
        MOV     a1, a1, LSL #10                 ; a1 -> L2PT tables for this section
        AND     ip, v5, #&000FF000              ; extract L2 table index bits
40      AND     lr, v6, #3
        TEQ     lr, #L2_LargePage               ; strip out surplus address bits from
        BICEQ   v4, v4, #&0000F000              ; large page descriptors
        ORR     lr, v4, v6                      ; lr = value for L2PT entry
        STR     lr, [a1, ip, LSR #10]           ; update L2PT entry
        MOV     a1, v5
        EXIT



; On entry:
;    a1 = virtual address L2PT required for
;    a2 = number of bytes of virtual space
;    v1 -> current entry in PhysRamTable
;    v2 = last used physical address
;    v3 -> L1PT (or 0 if MMU on)
; On exit
;    a1-a4,ip corrupt
;    v1, v2 updated
AllocateL2PT ROUT
        Entry   "v4-v8"
        MOV     v8, a1, LSR #20                 ; round base address down to 1M
        ADD     lr, a1, a2
        MOV     v7, lr, LSR #20
        TEQ     lr, v7, LSL #20
        ADDNE   v7, v7, #1                      ; round end address up to 1M

        MOVS    v6, v3
        LDREQ   v6, =L1PT                       ; v6->L1PT (whole routine)

05      LDR     v5, [v6, v8, LSL #2]            ; L1PT contains 1 word per M
        TEQ     v5, #0                          ; if non-zero, the L2PT has
                                                ; already been allocated
        BNE     %FT40

        BIC     lr, v8, #3                      ; round down to 4M - each page
        ADD     lr, v6, lr, LSL #2              ; of L2PT maps to 4 sections
        LDMIA   lr, {a3,a4,v5,ip}               ; check if any are page mapped
        ASSERT  L1_Fault = 2_00 :LAND: L1_Page = 2_01 :LAND: L1_Section = 2_10
        TST     a3, #1
        TSTEQ   a4, #1
        TSTEQ   v5, #1
        TSTEQ   ip, #1
        BEQ     %FT20                           ; nothing page mapped - claim a page

        TST     a4, #1                          ; at least one of the sections is page mapped
        SUBNE   a3, a4, #1*1024                 ; find out where it's pointing to and
        TST     v5, #1                          ; derive the corresponding address for our
        SUBNE   a3, v5, #2*1024                 ; section
        TST     ip, #1
        SUBNE   a3, ip, #3*1024

        AND     lr, v8, #3
        ORR     a3, a3, lr, LSL #10
        STR     a3, [v6, v8, LSL #2]            ; fill in the L1PT entry
        B       %FT40                           ; no more to do

20      BL      Init_ClaimPhysicalPage          ; Claim a page to put L2PT in
        MOV     v4, a1

      [ MEMM_Type = "VMSAv6"
        ORR     a3, a1, #L1_Page
      |
        ORR     a3, a1, #L1_Page + L1_U         ; Set the U bit for ARM6 (assume L2 pages will generally be cacheable)
      ]
        AND     lr, v8, #3
        ORR     a3, a3, lr, LSL #10
        STR     a3, [v6, v8, LSL #2]            ; fill in the L1PT

; Need to zero the L2PT. Must do it before calling in MapInPage, as that may well
; want to put something in the thing we are clearing. If the MMU is off, no problem,
; but if the MMU is on, then the L2PT isn't accessible until we've called MapInPage.
; Solution is to use the AccessPhysicalAddress call.

        TEQ     v3, #0                          ; MMU on?
        MOVNE   a1, v4                          ; if not, just access v4
        MOVEQ   a1, #L1_B                       ; if so, map in v4
        MOVEQ   a2, v4
        SUBEQ   sp, sp, #4
        MOVEQ   a3, sp
        BLEQ    RISCOS_AccessPhysicalAddress

        MOV     a2, #0
        MOV     a3, #4*1024
        BL      memset

        TEQ     v3, #0
        LDREQ   a1, [sp], #4
        BLEQ    RISCOS_ReleasePhysicalAddress

        ; Get the correct page table entry flags for Init_MapInPage
        TEQ     v3, #0
        LDREQ   a3, =ZeroPage
        ADDNE   a3, v3, #DRAMOffset_PageZero-DRAMOffset_L1PT
        LDR     a2, [a3, #PageTable_PageFlags]
        LDR     a4, [a3, #MMU_PCBTrans]
        LDR     a3, [a3, #MMU_PPLTrans]        
        MOV     a1, #0
        BL      Get4KPTE

        MOV     a3, a1
        MOV     a1, v4                          ; Map in the L2PT page itself
        LDR     a2, =L2PT                       ; (can't recurse, because L2PT
        ADD     a2, a2, v8, LSL #10             ; backing for L2PT is preallocated)
        BIC     a2, a2, #&C00
        BL      Init_MapInPage


40      ADD     v8, v8, #1                      ; go back until all
        CMP     v8, v7                          ; pages allocated
        BLO     %BT05

        EXIT


; void *RISCOS_AccessPhysicalAddress(unsigned int flags, void *addr, void **oldp)
RISCOS_AccessPhysicalAddress ROUT
        ; Only flag user can ask for is bufferable
        ; Convert to appropriate DA flags
        ; (n.b. since this is an internal routine we should really change it to pass in DA flags directly)
        TST     a1, #L1_B
        LDR     a1, =OSAP_None + DynAreaFlags_NotCacheable ; SVC RW, USR none
        ORREQ   a1, a1, #DynAreaFlags_NotBufferable
RISCOS_AccessPhysicalAddressUnchecked                   ; well OK then, I trust you know what you're doing
        LDR     ip, =L1PT + (PhysicalAccess:SHR:18)     ; ip -> L1PT entry
        MOV     a4, a2, LSR #20                         ; rounded to section
        MOV     a4, a4, LSL #20
        GetPTE  a1, 1M, a4, a1                          ; a1 = complete descriptor
 [ MEMM_Type = "VMSAv6"
        ORR     a1, a1, #L1_XN                          ; force non-executable to prevent speculative instruction fetches
 ]
        TEQ     a3, #0
        LDRNE   a4, [ip]                                ; read old value (if necessary)
        STR     a1, [ip]                                ; store new one
        STRNE   a4, [a3]                                ; put old one in [oldp]

        LDR     a1, =PhysicalAccess
        MOV     a3, a2, LSL #12                         ; take bottom 20 bits of address
        ORR     a3, a1, a3, LSR #12                     ; and make an offset within PhysicalAccess
        Push    "a3,lr"
        ARMop   MMU_ChangingUncached                    ; sufficient, cause not cacheable
        Pull    "a1,pc"

; void RISCOS_ReleasePhysicalAddress(void *old)
RISCOS_ReleasePhysicalAddress
        LDR     ip, =L1PT + (PhysicalAccess:SHR:18)     ; ip -> L1PT entry
        STR     a1, [ip]
        LDR     a1, =PhysicalAccess
        ARMop   MMU_ChangingUncached,,tailcall          ; sufficient, cause not cacheable


; void Init_PageTablesChanged(void)
;
; A TLB+cache invalidation that works on all known ARMs. Invalidate all I+D TLB is the _only_ TLB
; op that works on ARM720T, ARM920T and SA110. Ditto invalidate all I+D cache.
;
; DOES NOT CLEAN THE DATA CACHE. This is a helpful simplification, but requires that don't use
; this routine after we've started using normal RAM.
;
Init_PageTablesChanged
        MOV     a3, lr
        BL      Init_ARMarch
        MOV     ip, #0
        BNE     %FT01
        MCREQ   ARM_config_cp,0,ip,ARMv3_TLBflush_reg,C0
        B       %FT02
01      MCRNE   ARM_config_cp,0,ip,ARMv4_TLB_reg,C7
02
 [ MEMM_Type = "VMSAv6"
        CMP     a1, #ARMvF
        ADREQ   lr, %FT01
        BEQ     HAL_InvalidateCache_ARMvF
        MCRNE   ARM_config_cp,0,ip,ARMv4_cache_reg,C7           ; works on ARMv3
01
 |
        MCR     ARM_config_cp,0,ip,ARMv4_cache_reg,C7           ; works on ARMv3
 ]
        MOV     pc, a3




;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       ClearWkspRAM - Routine to clear "all" workspace
;
; We have to avoid anything between InitUsedStart and InitUsedEnd - i.e.
; the page tables, HAL workspace, etc.
;
; Note that zero page workspace isn't included in InitUsedStart/InitUsedEnd.
; Sensitive areas of it (e.g. PhysRamTable, IRQ vector) are skipped via the
; help of RamSkipTable
;
; The bulk of RAM is cleared during the keyboard scan (ClearFreePoolSection).

;
; out:  r4-r11, r13 preserved
;

ClearWkspRAM ROUT
        MSR     CPSR_c, #F32_bit+FIQ32_mode             ; get some extra registers
        MOV     r8, #0
        MOV     r9, #0
        MOV     r10, #0
        MOV     r11, #0
        MOV     r12, #0
        MOV     r13, #0
        MOV     r14, #0
        MSR     CPSR_c, #F32_bit+SVC32_mode

        LDR     r0,=ZeroPage+InitClearRamWs             ;we can preserve r4-r11,lr in one of the skipped regions
        STMIA   r0,{r4-r11,lr}
 
        DebugTX "ClearWkspRAM"

        ; Start off by clearing zero page + scratch space, as these:
        ; (a) are already mapped in and
        ; (b) may require the use of the skip table
        LDR     r0, =ZeroPage
        ADD     r1, r0, #16*1024
        ADR     r6, RamSkipTable
        MSR     CPSR_c, #F32_bit+FIQ32_mode             ; switch to our bank o'zeros
        LDR     r5, [r6], #4                            ; load first skip addr
10
        TEQ     r0, r1
        TEQNE   r0, r5
        STMNEIA r0!, {r8-r11}
        BNE     %BT10
        TEQ     r0, r1
        BEQ     %FT20
        LDR     r5, [r6], #4                            ; load skip amount
        ADD     r0, r0, r5                              ; and skip it
        LDR     r5, [r6], #4                            ; load next skip addr
        B       %BT10
20
        LDR     r0, =ScratchSpace
        ADD     r1, r0, #ScratchSpaceSize
30
        TEQ     r0, r1
        STMNEIA r0!, {r8-r11}
        STMNEIA r0!, {r8-r11}
        BNE     %BT30

        MSR     CPSR_c, #F32_bit+SVC32_mode

        LDR     r0, =ZeroPage+InitClearRamWs
        LDMIA   r0, {r4-r11,r14}                        ;restore

      [ {FALSE} ; NewReset sets this later
        LDR     r0, =ZeroPage+OsbyteVars + :INDEX: LastBREAK
        MOV     r1, #&80
        STRB    r1, [r0]                                ; flag the fact that RAM cleared
      ]

        MSR     CPSR_c, #F32_bit + UND32_mode           ; retrieve the MMU control register
        LDR     r0, =ZeroPage                           ; soft copy
        STR     sp, [r0, #MMUControlSoftCopy]
        MSR     CPSR_c, #F32_bit + SVC32_mode

        MOV     pc, lr

        LTORG

        MACRO
        MakeSkipTable $addr, $size
        ASSERT  ($addr :AND: 15) = 0
        ASSERT  ($size :AND: 15) = 0
        ASSERT  ($addr-ZeroPage) < 16*1024
        &       $addr, $size
        MEND

        MACRO
        EndSkipTables
        &       -1
        MEND

RamSkipTable
        MakeSkipTable   ZeroPage, InitWsEnd
        MakeSkipTable   ZeroPage+SkippedTables, SkippedTablesEnd-SkippedTables
        EndSkipTables

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       ClearFreePoolSection - Routine to clear a section of the free pool
;
; During keyboard scanning we soak up slack time clearing the bulk of RAM
; by picking a section of the free pool, mapping it in, clearing & flushing.

;
; In:   r0 = CAM entry to continue from
; Out:  r0 = updated
;

ClearFreePoolSection ROUT
        Push    "r1-r3, lr"
        LDR     r1, =ZeroPage
        LDR     r1, [r1, #MaxCamEntry]
        LDR     r2, =ZeroPage+FreePoolDANode
        CMP     r0, r1
        BHI     %FT30

        LDR     r3, =CAM
        ADD     r1, r3, r1, LSL #CAM_EntrySizeLog2      ; top entry (inc)
        ADD     r3, r3, r0, LSL #CAM_EntrySizeLog2      ; starting entry
10
        LDR     r14, [r3, #CAM_PageFlags]
        TST     r14, #DynAreaFlags_PMP
        BEQ     %FT20

        LDR     r14, [r3, #CAM_PMP]
        TEQ     r14, r2
        BEQ     %FT40
20
        ADD     r3, r3, #CAM_EntrySize                  ; next
        CMP     r3, r1
        BLS     %BT10
30
        MOV     r0, #-1
        Pull    "r1-r3, pc"
40
        Push    "r0-r12"

        ; This is a PMP entry in the free pool
        LDR     r14, [r3, #CAM_PMPIndex]                ; list index
        LDR     r9, [r2, #DANode_PMP]                   ; PMP list base
        LDR     r3, [r9, r14, LSL #2]                   ; ppn
        BL      ppn_to_physical                         ; => r5 = PA

      [ MEMM_Type = "ARM600"
        ; Map in this section, cacheable + bufferable to ensure burst writes
        ; are performed (StrongARM will only perform burst writes to CB areas)
        MOV     a1, #OSAP_None
      |
        ; Map in this section with default NCB cache policy. Making it cacheable
        ; is liable to slow things down significantly on some platforms (e.g.
        ; PL310 L2 cache)
        LDR     a1, =OSAP_None + DynAreaFlags_NotCacheable
      ]
        MOV     a2, r5
        MOV     a3, #0
        BL      RISCOS_AccessPhysicalAddressUnchecked

        MOV     r4, #0                                  ; clear to this value
        MOV     r6, r4
        MOV     r7, r4
        MOV     r8, r4
        MOV     r12, r4
45
        MOV     r9, r4
        MOV     r10, r4
        MOV     r11, r4

        ; Fill that page
        ADD     r2, r0, #4096
50
        STMIA   r0!, {r4,r6-r12}
        STMIA   r0!, {r4,r6-r12}
        TEQ     r0, r2
        BNE     %BT50

        ; Step the CAM until there are no more pages in that section
        LDR     r1, [sp, #1*4]
        LDR     r2, [sp, #2*4]
        LDR     r11, [sp, #3*4]
        B       %FT65
60
        LDR     r14, [r11, #CAM_PageFlags]
        TST     r14, #DynAreaFlags_PMP
        BEQ     %FT65

        LDR     r14, [r11, #CAM_PMP]
        TEQ     r14, r2
        BEQ     %FT70
65
        ADD     r11, r11, #CAM_EntrySize                ; next
        CMP     r11, r1
        BLS     %BT60

        MOV     r14, #-1                                ; CAM top, no more
        B       %FT80
70
        MOV     r10, r5                                 ; previous PA

        ; Next PMP entry in the free pool
        LDR     r14, [r11, #CAM_PMPIndex]               ; list index
        LDR     r9, [r2, #DANode_PMP]                   ; PMP list base
        LDR     r3, [r9, r14, LSL #2]                   ; ppn
        BL      ppn_to_physical                         ; => r5 = PA

        MOV     r14, r10, LSR #20
        TEQ     r14, r5, LSR #20                        ; same MB as previous?
        LDRNE   r14, =CAM
        SUBNE   r14, r11, r14
        MOVNE   r14, r14, LSR #CAM_EntrySizeLog2        ; no, so compute continuation point
        LDREQ   r0, =PhysicalAccess
        MOVEQ   r14, r5, LSL #12
        ORREQ   r0, r0, r14, LSR #12
        STREQ   r11, [sp, #3*4]
        BEQ     %BT45                                   ; yes, so clear it
80
        STR     r14, [sp, #0*4]                         ; return value for continuation

 [ MEMM_Type = "ARM600" ; VMSAv6 maps as non-cacheable, so no flush required
        ; Make page uncacheable so the following is safe
        MOV     r4, r0

        MOV     r0, #L1_B
        MOV     r1, r10
        MOV     r2, #0
        BL      RISCOS_AccessPhysicalAddress

        MOV     r0, r4

        ; Clean & invalidate the cache before the 1MB window closes
      [ CacheCleanerHack
        ; StrongARM requires special clean code, because we haven't mapped in
        ; DCacheCleanAddress yet. Cheat and only perform a clean, not full
        ; clean + invalidate (should be safe as we've only been writing)
        ARM_read_ID r2
        AND     r2, r2, #&F000
        CMP     r2, #&A000
        BNE     %FT90
85
        SUB     r0, r0, #32                             ; rewind 1 cache line
        ARMA_clean_DCentry r0
        MOVS    r1, r0, LSL #12                         ; start of the MB?
        BNE     %BT85
        B       %FT91
90
      ]
        ARMop Cache_CleanInvalidateAll
 ]
91
        MOV     a1, #L1_Fault
        BL      RISCOS_ReleasePhysicalAddress           ; reset to default

        Pull    "r0-r12"

        Pull    "r1-r3, pc"

InitProcVecs
        BKPT    &C000                                   ; Reset
        BKPT    &C004                                   ; Undefined Instruction
        BKPT    &C008                                   ; SWI
        BKPT    &C00C                                   ; Prefetch Abort
        SUBS    pc, lr, #4                              ; ignore data aborts
        BKPT    &C014                                   ; Address Exception
        LDR     pc, InitProcVecs + InitIRQHandler       ; IRQ
        BKPT    &C01C                                   ; FIQ
InitProcVec_FIQ
        DCD     0
InitProcVecsEnd

;
; In:  a1 = flags  (L1_B,L1_C,L1_TEX)
;           bit 20 set if doubly mapped
;           bit 21 set if L1_AP specified (else default to AP_None)
;      a2 = physical address
;      a3 = size
; Out: a1 = assigned logical address, or 0 if failed (no room)
;
; Will detect and return I/O space already mapped appropriately, or map and return new space
; For simplicity and speed of search, works on a section (1Mb) granularity
;

        ASSERT  L1_B = 1:SHL:2
        ASSERT  L1_C = 1:SHL:3
 [ MEMM_Type = "VMSAv6"
        ASSERT  L1_AP = 2_100011 :SHL: 10
        ASSERT  L1_TEX = 2_111 :SHL: 12
 |
        ASSERT  L1_AP = 3:SHL:10
        ASSERT  L1_TEX = 2_1111 :SHL: 12
 ]
MapInFlag_DoublyMapped * 1:SHL:20
MapInFlag_APSpecified * 1:SHL:21

RISCOS_MapInIO ROUT
        TST     a1, #MapInFlag_APSpecified
        BICEQ   a1, a1, #L1_AP
        ; For VMSAv6, assume HAL knows what it's doing and requests correct settings for AP_ROM
        ORREQ   a1, a1, #L1_APMult * AP_None
        BIC     a1, a1, #3
 [ MEMM_Type = "VMSAv6"
        ORR     a1, a1, #L1_Section+L1_XN               ; force non-executable to prevent speculative instruction fetches
 |
        ORR     a1, a1, #L1_Section
 ]
RISCOS_MapInIO_PTE ; a1 bits 0-19 = L1 section entry flags, bits 20+ = our extra flags
        Entry   "v1-v5,v7"
        LDR     v7, =(1:SHL:20)-1
        AND     v4, a2, v7                              ; v4 = offset of original within section-aligned area
        ADD     a3, a2, a3                              ; a3 -> end (exclusive)
        BIC     a2, a2, v7                              ; round a2 down to a section boundary
        ADD     a3, a3, v7
        BIC     a3, a3, v7                              ; round a3 up to a section boundary

        ANDS    v5, a1, #MapInFlag_DoublyMapped
        SUBNE   v5, a3, a2                              ; v5 = offset of second mapping or 0

        LDR     ip, =ZeroPage
        LDR     a4, =L1PT
        AND     a1, a1, v7                              ; mask out our extra flags
        LDR     v2, =IO                                 ; logical end (exclusive) of currently mapped IO
        LDR     v1, [ip, #IOAllocPtr]                   ; logical start (inclusive)

        SUB     v1, v1, #&100000
10
        ADD     v1, v1, #&100000                        ; next mapped IO section
        CMP     v1, v2
        BHS     %FT32                                   ; no more currently mapped IO
        LDR     v3, [a4, v1, LSR #(20-2)]               ; L1PT entry (must be for mapped IO)
        MOV     lr, v3, LSR #20                         ; physical address bits
        CMP     lr, a2, LSR #20
        BNE     %BT10                                   ; no address match
        AND     lr, v3, v7
        TEQ     lr, a1
        BNE     %BT10                                   ; no flags match

        TEQ     v5, #0                                  ; doubly mapped?
        BEQ     %FT19

        ADD     lr, v1, v5                              ; address of second copy
        CMP     lr, v2
        BHS     %FT32
        LDR     v3, [a4, lr, LSR #(20-2)]
        MOV     lr, v3, LSR #20                         ; physical address bits
        CMP     lr, a2, LSR #20
        BNE     %BT10                                   ; no address match
        AND     lr, v3, v7
        TEQ     lr, a1
        BNE     %BT10                                   ; no flags match

19
;
; alright, found start of requested IO already mapped, and with required flags
;
        Push    "a2, v1"
20
        ADD     a2, a2, #&100000
        CMP     a2, a3
        Pull    "a2, v1", HS
        BHS     %FT40                                  ; its all there already!
        ADD     v1, v1, #&100000                       ; next mapped IO section
        CMP     v1, v2
        BHS     %FT30                                  ; no more currently mapped IO
        LDR     v3, [a4, v1, LSR #(20-2)]              ; L1PT entry
        MOV     lr, v3, LSR #20                        ; physical address bits
        CMP     lr, a2, LSR #20
        BNE     %FT29                                  ; address match failed
        AND     lr, v3, v7
        TEQ     lr, a1
        TEQEQ   v5, #0                                 ; doubly mapped?
        BEQ     %BT20                                  ; address and flags match so far
        ADD     lr, v1, v5                             ; where duplicate should be
        CMP     lr, v2
        BHS     %FT30                                  ; no more currently mapped IO
        LDR     v3, [a4, lr, LSR #(20-2)]
        MOV     lr, v3, LSR #20                        ; physical address bits
        CMP     lr, a2, LSR #20
        BNE     %FT29                                  ; address match failed
        AND     lr, v3, v7
        TEQ     lr, a1
        BEQ     %BT20
29
        Pull    "a2, v1"
        B       %BT10
30
        Pull    "a2, v1"
;
; request not currently mapped, only partially mapped, or mapped with wrong flags
;
32
        LDR     ip, =ZeroPage
        LDR     v2, [ip, #IOAllocPtr]
        ADD     v1, v2, a2
        SUB     v1, v1, a3                              ; attempt to allocate size of a3-a2
        SUB     v1, v1, v5                              ; double if necessary
        LDR     v3, [ip, #IOAllocLimit]                 ; can't extend down below limit
        CMP     v1, v3
        MOVLS   a1, #0
        BLS     %FT90
        STR     v1, [ip, #IOAllocPtr]
        ORR     a2, a2, a1                              ; first L1PT value
34
        STR     a2, [a4, v1, LSR #(20-2)]
        TEQ     v5, #0
        ADDNE   v2, v1, v5
        STRNE   a2, [a4, v2, LSR #(20-2)]
        ADD     a2, a2, #&100000
        ADD     v1, v1, #&100000                        ; next section
        CMP     a2, a3
        BLO     %BT34
        PageTableSync
        LDR     v1, [ip, #IOAllocPtr]
40
        ADD     a1, v1, v4                              ; logical address for request
90
        EXIT


; void RISCOS_AddDevice(unsigned int flags, struct device *d)
RISCOS_AddDevice
        ADDS    a1, a2, #0      ; also clears V
        B       HardwareDeviceAdd_Common

; uint32_t RISCOS_LogToPhys(const void *log)
RISCOS_LogToPhys ROUT
        Push    "r4,r5,r8,r9,lr"
        MOV     r4, a1
        LDR     r8, =L2PT
        BL      logical_to_physical
        MOVCC   a1, r5
        BCC     %FT10
        ; Try checking L1PT for any section mappings (logical_to_physical only
        ; deals with regular 4K page mappings)
        ; TODO - Add large page support
        LDR     r9, =L1PT
        MOV     r5, r4, LSR #20
        LDR     a1, [r9, r5, LSL #2]
        ASSERT  L1_Section = 2
        EOR     a1, a1, #2
        TST     a1, #3
        MOVNE   a1, #-1
        BNE     %FT10
        ; Apply offset from bits 0-19 of logical addr
      [ NoARMT2
        MOV     a1, a1, LSR #20
        ORR     a1, a1, r4, LSL #12
        MOV     a1, a1, ROR #12
      |
        BFI     a1, r4, #0, #20
      ]  
10
        Pull    "r4,r5,r8,r9,pc"

; int RISCOS_IICOpV(IICDesc *descs, uint32_t ndesc_and_bus)
RISCOS_IICOpV ROUT
        Push    "lr"
        BL      IIC_OpV
        MOVVC   a1, #IICStatus_Completed
        Pull    "pc", VC
        ; Map from RISC OS error numbers to abstract IICStatus return values
        LDR     a1, [a1]
        LDR     lr, =ErrorNumber_IIC_NoAcknowledge
        SUB     a1, a1, lr              ; 0/1/2 = NoAck/Error/Busy
        CMP     a1, #3
        MOVCS   a1, #3                  ; 3+ => unknown, either way it's an Error
        ADR     lr, %FT10
        LDRB    a1, [lr, a1]
        Pull    "pc"
10
        ASSERT    (ErrorNumber_IIC_Error - ErrorNumber_IIC_NoAcknowledge) = 1
        ASSERT    (ErrorNumber_IIC_Busy - ErrorNumber_IIC_NoAcknowledge) = 2
        DCB       IICStatus_NoACK, IICStatus_Error, IICStatus_Busy, IICStatus_Error
        ALIGN
        
SetUpHALEntryTable ROUT
        LDR     a1, =ZeroPage
        LDR     a2, [a1, #HAL_Descriptor]
        LDR     a3, [a1, #HAL_Workspace]
        LDR     a4, [a2, #HALDesc_Entries]
        LDR     ip, [a2, #HALDesc_NumEntries]
        ADD     a4, a2, a4                              ; a4 -> entry table
        MOV     a2, a4                                  ; a2 -> entry table (increments)
10      SUBS    ip, ip, #1                              ; decrement counter
        LDRCS   a1, [a2], #4
        BCC     %FT20
        TEQ     a1, #0
        ADREQ   a1, NullHALEntry
        ADDNE   a1, a4, a1                              ; convert offset to absolute
        STR     a1, [a3, #-4]!                          ; store backwards below HAL workspace
        B       %BT10
20      LDR     a1, =ZeroPage                           ; pad table with NullHALEntries
        LDR     a4, =HALWorkspace                       ; in case where HAL didn't supply enough
        ADR     a1, NullHALEntry
30      CMP     a3, a4
        STRHI   a1, [a3, #-4]!
        BHI     %BT30
        MOV     pc, lr


NullHALEntry
        MOV     pc, lr

; Can freely corrupt r10-r12 (v7,v8,ip).
HardwareSWI
        AND     ip, v5, #&FF

        CMP     ip, #OSHW_LookupRoutine
        ASSERT  OSHW_CallHAL < OSHW_LookupRoutine
        BLO     HardwareCallHAL
        BEQ     HardwareLookupRoutine

        CMP     ip, #OSHW_DeviceRemove
        ASSERT  OSHW_DeviceAdd < OSHW_DeviceRemove
        BLO     HardwareDeviceAdd
        BEQ     HardwareDeviceRemove

        CMP     ip, #OSHW_DeviceEnumerateChrono
        ASSERT  OSHW_DeviceEnumerate < OSHW_DeviceEnumerateChrono
        ASSERT  OSHW_DeviceEnumerateChrono < OSHW_MaxSubreason 
        BLO     HardwareDeviceEnumerate
        BEQ     HardwareDeviceEnumerateChrono
        BHI     HardwareBadReason

HardwareCallHAL
        Push    "v1-v4,sb,lr"
        ADD     v8, sb, #1                              ; v8 = entry no + 1
        LDR     ip, =ZeroPage
        LDR     v7, [ip, #HAL_Descriptor]
        AddressHAL ip                                   ; sb set up
        LDR     v7, [v7, #HALDesc_NumEntries]           ; v7 = number of entries
        CMP     v8, v7                                  ; entryno + 1 must be <= number of entries
        BHI     HardwareBadEntry2
        LDR     ip, [sb, -v8, LSL #2]
        ADR     v7, NullHALEntry
        TEQ     ip, v7
        BEQ     HardwareBadEntry2
      [ NoARMv5
        MOV     lr, pc
        MOV     pc, ip
      |
        BLX     ip
      ]
        ADD     sp, sp, #4*4
        Pull    "sb,lr"
        ExitSWIHandler

HardwareLookupRoutine
        ADD     v8, sb, #1                              ; v8 = entry no + 1
        LDR     ip, =ZeroPage
        LDR     v7, [ip, #HAL_Descriptor]
        AddressHAL ip
        LDR     v7, [v7, #HALDesc_NumEntries]
        CMP     v8, v7                                  ; entryno + 1 must be <= number of entries
        BHI     HardwareBadEntry
        LDR     a1, [sb, -v8, LSL #2]
        ADR     v7, NullHALEntry
        TEQ     a1, v7
        BEQ     HardwareBadEntry
        MOV     a2, sb
        ExitSWIHandler

HardwareDeviceAdd
        Push    "r1-r3,lr"
        BL      HardwareDeviceAdd_Common
        Pull    "r1-r3,lr"
        B       SLVK_TestV

HardwareDeviceRemove
        Push    "r1-r3,lr"
        BL      HardwareDeviceRemove_Common
        Pull    "r1-r3,lr"
        B       SLVK_TestV

HardwareDeviceAdd_Common
        Entry
        BL      HardwareDeviceRemove_Common             ; first try to remove any device already at the same address
        EXIT    VS
        LDR     lr, =ZeroPage
        LDR     r1, [lr, #DeviceCount]
        LDR     r2, [lr, #DeviceTable]
        TEQ     r2, #0
        BEQ     %FT80
        ADD     r1, r1, #1                              ; increment DeviceCount
        LDR     lr, [r2, #-4]                           ; word before heap block is length including length word
        TEQ     r1, lr, LSR #2                          ; block already full?
        BEQ     %FT81
        LDR     lr, =ZeroPage
10      STR     r1, [lr, #DeviceCount]
        ADD     lr, r2, r1, LSL #2
        SUB     lr, lr, #4
11      LDR     r1, [lr, #-4]!                          ; copy existing devices up, so new ones get enumerated first
        STR     r1, [lr, #4]
        CMP     lr, r2
        BHI     %BT11
        STR     r0, [r2]
        MOV     r2, r0
        MOV     r1, #Service_Hardware
        MOV     r0, #0
        BL      Issue_Service
        ADDS    r0, r2, #0                              ; exit with V clear
        EXIT

80      ; Claim a system heap block for the device table
        Push    "r0"
        MOV     r3, #16
        BL      ClaimSysHeapNode
        ADDVS   sp, sp, #4
        EXIT    VS
        Pull    "r0"
        LDR     lr, =ZeroPage
        MOV     r1, #1
        STR     r2, [lr, #DeviceTable]
        B       %BT10

81      ; Extend the system heap block
        Push    "r0"
        MOV     r0, #HeapReason_ExtendBlock
        MOV     r3, #16
        BL      DoSysHeapOpWithExtension
        ADDVS   sp, sp, #4
        EXIT    VS
        Pull    "r0"
        LDR     lr, =ZeroPage
        LDR     r1, [lr, #DeviceCount]
        STR     r2, [lr, #DeviceTable]
        ADD     r1, r1, #1
        B       %BT10

HardwareDeviceRemove_Common
        Entry   "r4"
        LDR     lr, =ZeroPage
        LDR     r3, [lr, #DeviceCount]
        LDR     r4, [lr, #DeviceTable]
        TEQ     r3, #0
        EXIT    EQ                                      ; no devices registered
01      LDR     r2, [r4], #4
        SUBS    r3, r3, #1
        TEQNE   r2, r0
        BNE     %BT01
        TEQ     r2, r0
        EXIT    NE                                      ; this device not registered
        MOV     r0, #1
        MOV     r1, #Service_Hardware
        BL      Issue_Service
        CMP     r1, #0                                  ; if service call claimed
        CMPEQ   r1, #1:SHL:31                           ; then set V (r0 already points to error block)
        EXIT    VS                                      ; and exit
        MOV     r0, r2
        SUBS    r3, r3, #1
02      LDRCS   r2, [r4], #4                            ; copy down remaining devices
        STRCS   r2, [r4, #-8]
        SUBCSS  r3, r3, #1
        BCS     %BT02
        LDR     lr, =ZeroPage
        LDR     r3, [lr, #DeviceCount]
        SUB     r3, r3, #1
        STR     r3, [lr, #DeviceCount]
        EXIT

HardwareDeviceEnumerate
        Push    "r3-r4,lr"
        LDR     lr, =ZeroPage
        LDR     r2, [lr, #DeviceCount]
        LDR     r3, [lr, #DeviceTable]
        SUBS    r4, r2, r1
        MOVLS   r1, #-1
        BLS     %FT90                                   ; if r1 is out of range then exit
        ADD     r3, r3, r1, LSL #2
10      ADD     r1, r1, #1
        LDR     r2, [r3], #4
        LDR     lr, [r2, #HALDevice_Type]
        EOR     lr, lr, r0
        MOVS    lr, lr, LSL #16                         ; EQ if types match
        SUBNES  r4, r4, #1
        BNE     %BT10
        TEQ     lr, #0
        MOVNE   r1, #-1
        BNE     %FT90
        LDR     lr, [r2, #HALDevice_Version]
        MOV     lr, lr, LSR #16
        CMP     lr, r0, LSR #16                         ; newer than our client understands?
        BLS     %FT90
        SUBS    r4, r4, #1
        BHI     %BT10
        MOV     r1, #-1
90
        Pull    "r3-r4,lr"
        ExitSWIHandler

HardwareDeviceEnumerateChrono
        Push    "r3-r4,lr"
        LDR     lr, =ZeroPage
        LDR     r2, [lr, #DeviceCount]
        LDR     r3, [lr, #DeviceTable]
        SUBS    r4, r2, r1
        MOVLS   r1, #-1
        BLS     %FT90                                   ; if r1 is out of range then exit
        ADD     r3, r3, r4, LSL #2
10      ADD     r1, r1, #1
        LDR     r2, [r3, #-4]!
        LDR     lr, [r2, #HALDevice_Type]
        EOR     lr, lr, r0
        MOVS    lr, lr, LSL #16                         ; EQ if types match
        SUBNES  r4, r4, #1
        BNE     %BT10
        TEQ     lr, #0
        MOVNE   r1, #-1
        BNE     %FT90
        LDR     lr, [r2, #HALDevice_Version]
        MOV     lr, lr, LSR #16
        CMP     lr, r0, LSR #16                         ; newer than our client understands?
        BLS     %FT90
        SUBS    r4, r4, #1
        BHI     %BT10
        MOV     r1, #-1
90
        Pull    "r3-r4,lr"
        ExitSWIHandler

HardwareBadReason
        ADR     r0, ErrorBlock_HardwareBadReason
 [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
 ]
        B       SLVK_SetV

HardwareBadEntry2
        ADD     sp, sp, #4*4
        Pull    "sb,lr"
HardwareBadEntry
        ADR     r0, ErrorBlock_HardwareBadEntry
 [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
 ]
        B       SLVK_SetV

        MakeErrorBlock HardwareBadReason
        MakeErrorBlock HardwareBadEntry

 [ DebugTerminal
DebugTerminal_Rdch
        Push    "a2-a4,sb,ip"
        WritePSRc SVC_mode, r1
        MOV     sb, ip
20
        CallHAL HAL_DebugRX
        CMP     a1, #27
        BNE     %FT25
        LDR     a2, =ZeroPage + OsbyteVars + :INDEX: RS423mode
        LDRB    a2, [a2]
        TEQ     a2, #0                  ; is RS423 raw data,or keyb emulator?
        BNE     %FT25
        LDR     a2, =ZeroPage
        LDRB    a1, [a2, #ESC_Status]
        ORR     a1, a1, #&40
        STRB    a1, [a2, #ESC_Status]   ; mark escape flag
        MOV     a1, #27
        SEC                             ; tell caller to look carefully at R0
        Pull    "a2-a4,sb,ip,pc"
25
        CMP     a1, #-1
        Pull    "a2-a4,sb,ip,pc",NE     ; claim it
        LDR     R0, =ZeroPage
        LDRB    R14, [R0, #CallBack_Flag]
        TST     R14, #CBack_VectorReq
        BLNE    process_callback_chain
        B       %BT20


DebugTerminal_Wrch
        Push    "a1-a4,sb,ip,lr"
        MOV     sb, ip
        CallHAL HAL_DebugTX
        Pull    "a1-a4,sb,ip,pc"        ; don't claim it
 ]


Reset_IRQ_Handler
        SUB     lr, lr, #4
        Push    "a1-a4,v1-v2,sb,ip,lr"
        MRS     a1, SPSR
        MRS     a2, CPSR
        ORR     a3, a2, #SVC32_mode
        MSR     CPSR_c, a3
        Push    "a1-a2,lr"

        ; If it's not an IIC interrupt, mute it
        LDR     v2, =ZeroPage
        AddressHAL v2
        CallHAL HAL_IRQSource
        ADD     v1, v2, #IICBus_Base
        MOV     ip, #0
10
        LDR     a2, [v1, #IICBus_Type]
        TST     a2, #IICFlag_Background
        BEQ     %FT20
        LDR     a2, [v1, #IICBus_Device]
        CMP     a2, a1
        ADREQ   lr, Reset_IRQ_Exit
        BEQ     IICIRQ
20
        ADD     ip, ip, #1
        ADD     v1, v1, #IICBus_Size
        CMP     ip, #IICBus_Count
        BNE     %BT10

        CallHAL HAL_IRQDisable ; Stop the rogue device from killing us completely

Reset_IRQ_Exit
        MyCLREX a1, a2
        Pull    "a1-a2,lr"
        MSR     CPSR_c, a2
        MSR     SPSR_cxsf, a1
        Pull    "a1-a4,v1-v2,sb,ip,pc",,^

 [ DebugHALTX
DebugHALPrint
        Push    "a1-a4,v1,sb,ip"
        AddressHAL
        MOV     v1, lr
10      LDRB    a1, [v1], #1
        TEQ     a1, #0
        BEQ     %FT20
        CallHAL HAL_DebugTX
        B       %BT10
20      MOV     a1, #13
;        CallHAL HAL_DebugTX
        MOV     a1, #10
;        CallHAL HAL_DebugTX
        ADD     v1, v1, #3
        BIC     lr, v1, #3
        Pull    "a1-a4,v1,sb,ip"
        MOV     pc, lr
 ]


 [ DebugHALTX
DebugHALPrintReg ; Output number on top of stack to the serial port
        Push    "a1-a4,v1-v4,sb,ip,lr"   ; this is 11 regs
        LDR     v2, [sp,#11*4]           ; find TOS value on stack
        ADR     v3, hextab
        MOV     v4, #8
05
       AddressHAL
10      LDRB    a1, [v3, v2, LSR #28]
       CallHAL  HAL_DebugTX
        MOV     v2, v2, LSL #4
        SUBS    v4, v4, #1
        BNE     %BT10
        MOV     a1, #13
       CallHAL  HAL_DebugTX
        MOV     a1, #10
       CallHAL  HAL_DebugTX

        Pull    "a1-a4,v1-v4,sb,ip,lr"
        ADD     sp, sp, #4
        MOV     pc, lr

hextab  DCB "0123456789abcdef"


 ]
;
;
; [ DebugHALTX
;HALDebugHexTX
;       stmfd    r13!, {r0-r3,sb,ip,lr}
;       AddressHAL
;       b        jbdt1
;HALDebugHexTX2
;       stmfd    r13!, {r0-r3,sb,ip,lr}
;       AddressHAL
;       mov      r0,r0,lsl #16
;       b        jbdt2
;HALDebugHexTX4
;       stmfd    r13!, {r0-r3,sb,ip,lr}
;       AddressHAL
;       mov      r0,r0,ror #24          ; hi byte
;       bl       jbdtxh
;       mov      r0,r0,ror #24
;       bl       jbdtxh
;jbdt2
;       mov      r0,r0,ror #24
;       bl       jbdtxh
;       mov      r0,r0,ror #24
;jbdt1
;       bl       jbdtxh
;       mov      r0,#' '
;       CallHAL  HAL_DebugTX
;       ldmfd    r13!, {r0-r3,sb,ip,pc}
;
;jbdtxh stmfd    r13!,{a1,v1,lr}        ; print byte as hex. corrupts a2-a4, ip, assumes sb already AddressHAL'd
;       and      v1,a1,#&f              ; get low nibble
;       and      a1,a1,#&f0             ; get hi nibble
;       mov      a1,a1,lsr #4           ; shift to low nibble
;       cmp      a1,#&9                 ; 9?
;       addle    a1,a1,#&30
;       addgt    a1,a1,#&37             ; convert letter if needed
;       CallHAL  HAL_DebugTX
;       cmp      v1,#9
;       addle    a1,v1,#&30
;       addgt    a1,v1,#&37
;       CallHAL  HAL_DebugTX
;       ldmfd    r13!,{a1,v1,pc}
; ]
;
        END

