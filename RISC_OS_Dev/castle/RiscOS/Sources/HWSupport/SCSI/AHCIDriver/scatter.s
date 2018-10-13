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

        GET     OSMem
        GET     AHCIStruct

                       ^ 0
; Input state
Mem19Ctx_DirectPtr     # 4 ; Direct pointer to use if no scatter list (actually forms mini-scatter with TotalLen)
Mem19Ctx_TotalLen      # 4 ; Total xfer length
Mem19Ctx_PRDTLen       # 4 ; Resulting PRDT/DMA length, will include padding for half-word/sector boundaries
Mem19Ctx_ScatterPtr    # 4 ; Pointer to current entry in scatter list
Mem19Ctx_ScatterOffset # 4 ; How much of current entry has been consumed
Mem19Ctx_Offset        # 4 ; How much of xfer has been consumed (out of PRDTLen)
Mem19Ctx_DiscRead      # 1 ; 1 = disc read (DMA write), 0 = disc write (DMA read)
DMAwrite               * 1
DMAread                * 0
Mem19Ctx_LastByte      # 1 ; Scratchpad to write last byte of DMA write operation to
Mem19Ctx_ForceBounce   # 1 ; =1 if forcing entire transfer via bounce buffer
                       # 1
Mem19Ctx_OrigScatter   # 4 ; Original scatter list ptr
; Output state
Mem19Ctx_BouncePtr     # 4 ; Logical address of bounce buffer
Mem19Ctx_BouncePhys    # 4 ; Physical address of bounce buffer
Mem19Ctx_BounceOffset  # 4 ; Offset into bounce buffer
Mem19Ctx_PRDTIndex     # 4 ; PRDT index being written
Mem19Ctx_PRDT          # MaxPRDTCount*8 ; Array of (phys, len) pairs
                                        ; Len has bit 31 set if using bounce buffer
Mem19Ctx_Size          # 0

        ; For scatter list usage
        ASSERT  Mem19Ctx_TotalLen = Mem19Ctx_DirectPtr + 4

        ; Ensure scatter list pointer points to a non-empty chunk
        ; Required before using ScatterCurrentChunk / ScatterConsume
        MACRO
        ScatterInit $ptr, $temp, $temp2
        ASSERT  $temp < $temp2
10
        LDMIA   $ptr!, {$temp, $temp2}
        CMP     $temp, #ScatterListThresh
        TEQHS   $temp2, #0
        ADDEQ   $ptr, $ptr, $temp
        SUBEQ   $ptr, $ptr, #8 ; Allow for earlier increment
        TEQNE   $temp2, #0
        BEQ     %BT10
        SUB     $ptr, $ptr, #8
        MEND

        ; Return current $addr, $len pair from scatter list
        ; Returns 0 length if no more data
        MACRO
        ScatterCurrentChunk $addr, $len, $ctx, $temp, $temp2
        ; Check how much of xfer is remaining
        LDR     $temp, [$ctx, #Mem19Ctx_TotalLen]
        LDR     $len, [$ctx, #Mem19Ctx_Offset]
        SUBS    $temp2, $temp, $len
        BGT     %FT10
        ; Reached the end of the scatter list, but we may have some extra padding still
        LDRB    $temp2, [$ctx, #Mem19Ctx_DiscRead]
        LDR     $temp, [$ctx, #Mem19Ctx_PRDTLen]
        TEQ     $temp2, #DMAread ; DMA read gets padding from NullWrBuffer, DMA write uses LastByte
        LDREQ   $addr, NullWrBuffer
        SUB     $len, $temp, $len
        ADDEQ   $addr, $addr, #SecLen
        ADDNE   $addr, $ctx, #Mem19Ctx_LastByte
        SUBEQ   $addr, $addr, $len
        B       %FT90
10
        ; Get current chunk
        ; (assume ScatterPtr is pointing to a non-empty chunk)
        LDR     $temp, [$ctx, #Mem19Ctx_ScatterPtr]
        ASSERT  $addr < $len
        LDMIA   $temp, {$addr, $len}
        ; Offset by ScatterOffset, to cope with partially consumed chunks
        LDR     $temp, [$ctx, #Mem19Ctx_ScatterOffset]
        ADD     $addr, $addr, $temp
        SUB     $len, $len, $temp
        ; Limit length to $temp2
        CMP     $len, $temp2
        MOVHI   $len, $temp2
90
        MEND

        ; Advance scatter state by $len bytes
        ; Out: $len + temp regs corrupt
        MACRO
        ScatterConsume $len, $ctx, $temp, $temp2, $temp3
        ; Advance xfer offset
        LDR     $temp, [$ctx, #Mem19Ctx_Offset]
        ADD     $temp, $temp, $len
        LDR     $temp2, [$ctx, #Mem19Ctx_PRDTLen]
        ; Clamp to max length
        CMP     $temp, $temp2
        MOVHI   $temp, $temp2
        STR     $temp, [$ctx, #Mem19Ctx_Offset]
        ; If end of scatter list reached, skip scatter ptr update
        LDR     $temp2, [$ctx, #Mem19Ctx_TotalLen]
        CMP     $temp, $temp2
        MOVHS   $len, #0
        BHS     %FT90
        ; Advance scatter ptr / offset as necessary
        LDR     $temp, [$ctx, #Mem19Ctx_ScatterPtr]
        LDR     $temp2, [$ctx, #Mem19Ctx_ScatterOffset]
        ADD     $len, $len, $temp2
10
        LDR     $temp2, [$temp, #4]
        CMP     $len, #1
        CMPHS   $len, $temp2
        BLO     %FT90
        ; Consume this entire chunk, advancing to next valid scatter chunk
        SUB     $len, $len, $temp2
        ADD     $temp, $temp, #8
        ScatterInit $temp, $temp2, $temp3
        STR     $temp, [$ctx, #Mem19Ctx_ScatterPtr]
        B       %BT10
90
        STR     $len, [$ctx, #Mem19Ctx_ScatterOffset]
        MEND


; In:
; r0 = start address or scatter pointer
; r2 = total length
;      bit 31 set if read op
; r9 bit 26 set if its a scatterlist
; Out:
; r2-> rma block with pagelist to reenable caching subsequently
UnCache ROUT
        Entry   "r0-r10"
      [ Debug :LAND: {FALSE}
        DebugRegNCR r0, "UnCache "
        DebugRegNCR r2, "len RW "
        DebugReg r9, "flag "
        TST     r9, #1:SHL:ScatterListBit
        BEQ     %FT04
        MOV     r3,#4
01
        LDMIA   r0!,{r1,r4}
        DebugRegNCR r1, "addr "
        DebugReg r4, "len "
        SUBS    r3, r3, #1
        BNE     %BT01
        FRAMLDR r0
04
      ]
        ; Allocate RMA for the block
        MOV     r3, #Mem19Ctx_Size
        MOV     r0, #ModHandReason_Claim
        BIC     r1, r2, #1:SHL:31
        MOV     r4, r2, LSR #31
        SWI     XOS_Module
        FRAMSTR r0, VS
        EXIT    VS
        FRAMSTR r2
        MOV     r3, #0
        STRB    r3, [r2, #Mem19Ctx_ForceBounce]
        FRAMLDR r0
        TST     r9, #1:SHL:ScatterListBit
        ASSERT  Mem19Ctx_DirectPtr = 0
        ASSERT  Mem19Ctx_TotalLen = 4
        STMIA   r2, {r0, r1}
        MOVEQ   r0, r2
        BEQ     %FT05
        ScatterInit r0, r10, lr
05
        STR     r0, [r2, #Mem19Ctx_ScatterPtr]
        STR     r0, [r2, #Mem19Ctx_OrigScatter]
        ; Round DMA reads up to sector length, DMA write to halfword multiple
        TEQ     r4, #DMAread
        LDREQ   r0, =SecLen-1
        MOVNE   r0, #1
        ADD     r1, r1, r0
        BIC     r1, r1, r0
;        DebugReg r1, "PRDTLen "
        STR     r1, [r2, #Mem19Ctx_PRDTLen]
        MOV     r1, #0
        STR     r1, [r2, #Mem19Ctx_ScatterOffset]
        STR     r1, [r2, #Mem19Ctx_Offset]
        STRB    r4, [r2, #Mem19Ctx_DiscRead]
        MOV     r0, #-1
        STR     r0, [r2, #Mem19Ctx_PRDTIndex]
        STR     r1, [r2, #Mem19Ctx_BouncePtr]
        STR     r1, [r2, #Mem19Ctx_BounceOffset]
        ; Call OS_Memory 19, or our fake
        LDRB    r3, [r2, #Mem19Ctx_ForceBounce]
        CMP     r3, #1
        BEQ     %FT10
        MOV     r0, #OSMemReason_DMAPrep
        TEQ     r4, #DMAwrite
        ORREQ   r0, r0, #DMAPrep_Write
        MOV     r1, r12
        ADR     r3, Mem19InFunc
        MOV     r4, r2
        ADRL    r5, Mem19OutFunc
        SWI     XOS_Memory
        BVC     %FT30
        ; If we got an "Address not recognised" error then we're probably being asked to transfer to/from an area which the kernel doesn't consider to be regular RAM, e.g. ROM or an IO region
        LDR     r1, [r0]
        LDR     lr, =ErrorNumber_BadAddress
        CMP     r1, lr
        BNE     %FT90
        ; Set the "force bounce" flag and go round again
        MOV     r0, #1
        STRB    r0, [r2, #Mem19Ctx_ForceBounce]
        B       %FT35

10
        ; Drive the input & output functions manually and force everything to go via a bounce buffer
        MOV     r9, r2
20
        BL      Mem19InFunc
        BVS     %FT85
        ORR     r3, r2, #DMAPrep_UseBounceBuffer
        MOVS    r2, r1
        MOVEQ   r2, r9
        BEQ     %FT30
        ; Note phys addr doesn't matter here, due to forcing bounce buffer
        BL      Mem19OutFunc
        BVC     %BT20
        B       %FT85

30
        ; Allocate bounce buffer and fix up PRDT if necessary
        LDR     r0, [r2, #Mem19Ctx_BounceOffset]
;        DebugReg r0, "BounceOffset "
        TEQ     r0, #0
        EXIT    EQ
        MOV     r1, #0
        MOV     r2, #0
        ; Hack: Rather than tracking our page usage properly, we use a simple flag to detect calls to Service_PagesUnsafe
        ; Reset Service_PagesUnsafe flag
        STRB    r1, PagesUnsafeSeen
        SWI     XPCI_RAMAlloc
        FRAMLDR r2
        BVS     %FT90
        ; If Service_PagesUnsafe occurred, throw away this bounce buffer and try again (PCI RAM may have grown and caused some of the pages involved in the transfer to be replaced)
        LDRB    r3, PagesUnsafeSeen
        CMP     r3, #0
        BEQ     %FT40
;        DebugTX "Unsafe!"
        SWI     XPCI_RAMFree
35
        LDR     r0, [r2, #Mem19Ctx_OrigScatter]
        LDR     r1, [r2, #Mem19Ctx_TotalLen]
        LDRB    r4, [r2, #Mem19Ctx_DiscRead]
        B       %BT05

40
;        DebugRegNCR r0, "BouncePtr "
;        DebugReg r1, "phys "
        STR     r0, [r2, #Mem19Ctx_BouncePtr]
        STR     r1, [r2, #Mem19Ctx_BouncePhys]
        LDR     r6, [r2, #Mem19Ctx_PRDTIndex]
        ADD     r3, r2, #Mem19Ctx_PRDT
        ADD     r3, r3, #4 ; Point at length values
        LDRB    r7, [r2, #Mem19Ctx_DiscRead]
        ; Reset scatter list state
        LDR     lr, [r2, #Mem19Ctx_OrigScatter]
        STR     lr, [r2, #Mem19Ctx_ScatterPtr]
        MOV     lr, #0
        STR     lr, [r2, #Mem19Ctx_ScatterOffset]
        STR     lr, [r2, #Mem19Ctx_Offset]
50
        LDR     r4, [r3], #8 ; Get length / bounce flag
        TST     r4, #1:SHL:31
        BIC     r4, r4, #1:SHL:31
        BNE     %FT60
        ; Skip non-bounce
        TEQ     r7, #DMAread
        BNE     %FT80
        ScatterConsume r4, r2, r8, r9, lr
        B       %FT80

60
        ; Patch bounce buffer address
        LDR     r9, [r3, #-12]
        ADD     r9, r9, r1
        STR     r9, [r3, #-12]
        TEQ     r7, #DMAread
        BNE     %FT80
        ; DMA read operation, so copy data into bounce buffer
70
        ScatterCurrentChunk r8, r9, r2, r10, lr
        CMP     r9, r4
        MOVHI   r9, r4
        BL      memcpy_r0_r8_r9
        SUB     r4, r4, r9
        ScatterConsume r9, r2, r8, r10, lr
        CMP     r4, #0
        BNE     %BT70
80
        SUBS    r6, r6, #1
        BGE     %BT50
;        DebugTX "done"
        EXIT

85
        MOV     r2, r9
90
        FRAMSTR r0
        LDR     r0, [r2, #Mem19Ctx_BouncePtr]
        CMP     r0, #0
        SWINE   XPCI_RAMFree
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        SETV
        EXIT

; In:
; r9 -> ctx
; r12 = workspace
; Out:
; r0 = start address
; r1 = length
; r2 = flags
Mem19InFunc ROUT
        MOV     r1, #0
        Entry   "r1,r3-r4"
        ; Work out how much of current chunk we can return
        ScatterCurrentChunk r0, r1, r9, r2, lr
        CMP     r1, #0
        MOV     r2, #0
        EXIT    EQ
        ; If the start addr or current offset aren't aligned, we need to use a bounce buffer
        LDR     r3, [r9, #Mem19Ctx_Offset]
        TST     r0, #1
        TSTEQ   r3, #1
        BEQ     %FT50
        MOV     r2, #DMAPrep_UseBounceBuffer
        ; If they're both offset we can get by with only sending one byte via the bounce buffer
        TST     r0, #1
        TSTNE   r3, #1
        MOVNE   r1, #1
        B       %FT90
50
        ; If the end isn't aligned, force last byte via bounce buffer
        ADD     r3, r0, r1
        TST     r3, #1
        BEQ     %FT90
        CMP     r1, #1
        SUBHI   r1, r1, #1
        MOVEQ   r2, #DMAPrep_UseBounceBuffer
90
        ; Consume bytes
;        DebugRegNCR r0, "InFunc addr "
;        DebugRegNCR r1, "len "
;        DebugReg r2, "flags "
        FRAMSTR r1
        ScatterConsume r1, r9, r3, r4, lr
        CLRV
        EXIT

; In:
; r0 = logical address of start of region
; r1 = physical address of start of region
; r2 = length of region
; r3 = flags
; r9 -> ctx
; r12 = workspace
; Out: r0-r3 corrupt
Mem19OutFunc ROUT
        Entry   "r4-r8,r10-r11"
;        DebugRegNCR r0, "OutFunc log "
;        DebugReg r3, "flags "
        AND     r3, r3, #DMAPrep_UseBounceBuffer
        LDR     r4, [r9, #Mem19Ctx_PRDTIndex]
        ADD     r5, r9, r4, LSL #3
        ADD     r5, r5, #Mem19Ctx_PRDT
        LDR     r10, [r9, #Mem19Ctx_BounceOffset]
        LDMIA   r5, {r6, r7}
10
;        DebugRegNCR r1, "phys "
;        DebugReg r2, "len "
        BIC     r8, r7, #1:SHL:31
        ; Start a new PRDT entry if:
        ; * We don't have any entries yet
        CMP     r4, #-1
        BEQ     %FT20
        ; * We're switching from bounce to non-bounce
        ASSERT  DMAPrep_UseBounceBuffer = 1
        TEQ     r3, r7, LSR #31
        BNE     %FT20
        ; * Current entry is full
        CMP     r8, #PRDT_MAX_LEN
        BEQ     %FT20
        ; * Non-contigous non-bounce
        ADD     lr, r8, r6
        CMP     r3, #DMAPrep_UseBounceBuffer
        CMPNE   r1, lr
        BEQ     %FT60
20
        ; New PRDT entry required
;        DebugTX "New PRDT"
        ADD     r4, r4, #1
        ADD     r5, r5, #8
        CMP     r4, #MaxPRDTCount
        BEQ     %FT99
        TST     r3, #DMAPrep_UseBounceBuffer
        MOVEQ   r6, r1
        ; If using bounce buffer, ensure halfword aligned
        ADDNE   r10, r10, #1
        BICNE   r10, r10, #1
        MOVNE   r6, r10 ; Store current bounce offset as address
        MOV     r7, r3, LSL #31
        MOV     r8, #0
;        DebugRegNCR r6, "addr "
;        DebugReg r7, "flag/len "
        STR     r6, [r5]
60
        ; Don't overflow PRDT max size
        RSB     r8, r8, #PRDT_MAX_LEN
        CMP     r8, r2
        MOVGT   r8, r2
        ADD     r7, r7, r8
;        DebugRegNCR r8, "add "
;        DebugReg r7, "new flag/len "
        STR     r7, [r5, #4]
        TST     r3, #DMAPrep_UseBounceBuffer
        ADDNE   r10, r10, r8
        SUBS    r2, r2, r8
        ADD     r1, r1, r8
        BNE     %BT10
        STR     r4, [r9, #Mem19Ctx_PRDTIndex]
        STR     r10, [r9, #Mem19Ctx_BounceOffset]
        EXIT

99
        ADR     r0, ErrTooComplex
        SETV
        EXIT

; Borrow one of DMAManager's errors
ErrTooComplex
        DCD     ErrorBase_DMA + 20
        = "DMA transfer too complex", 0
        ALIGN

; In:
; r0 -> pointer to UnCache output block
ReCache ROUT
        Entry   "r0-r10"
;        DebugTX "ReCache"
        MOV     r2, r0
        ; Reset scatter list state
        LDR     lr, [r2, #Mem19Ctx_OrigScatter]
        STR     lr, [r2, #Mem19Ctx_ScatterPtr]
        MOV     lr, #0
        STR     lr, [r2, #Mem19Ctx_ScatterOffset]
        STR     lr, [r2, #Mem19Ctx_Offset]
        ; Call OS_Memory 19 if necessary
        LDRB    lr, [r2, #Mem19Ctx_ForceBounce]
        CMP     lr, #1
        LDRB    r7, [r2, #Mem19Ctx_DiscRead]
        BEQ     %FT10
        LDR     r0, =OSMemReason_DMAPrep + DMAPrep_End
        TEQ     r7, #DMAwrite
        ORREQ   r0, r0, #DMAPrep_Write
        MOV     r1, r12
        ADR     r3, Mem19InFunc
        SWI     XOS_Memory
        BVS     %FT90
10
        TEQ     r7, #DMAwrite
        BNE     %FT90
        ; Copy out of bounce buffer
        LDR     r8, [r2, #Mem19Ctx_BouncePtr]
        CMP     r8, #0
        BEQ     %FT90
        LDR     r9, [r2, #Mem19Ctx_BouncePhys]
        SUB     r1, r8, r9 ; phys -> log offset
        LDR     r6, [r2, #Mem19Ctx_PRDTIndex]
        ADD     r3, r2, #Mem19Ctx_PRDT
        CMP     r6, #-1 ; Will be -1 if we want to suppress copying out of bounce buffer
        ADD     r3, r3, #4 ; Point at length values
        BEQ     %FT90
        ; Reset scatter list state
        LDR     lr, [r2, #Mem19Ctx_OrigScatter]
        STR     lr, [r2, #Mem19Ctx_ScatterPtr]
        MOV     lr, #0
        STR     lr, [r2, #Mem19Ctx_ScatterOffset]
        STR     lr, [r2, #Mem19Ctx_Offset]
20
        LDR     r4, [r3], #8 ; Get length / bounce flag
        TST     r4, #1:SHL:31
        BIC     r4, r4, #1:SHL:31
        BNE     %FT50
        ScatterConsume r4, r2, r0, r10, lr
        B       %FT80
50
        ; Convert bounce phys addr to logical
        LDR     r8, [r3, #-12]
        ADD     r8, r8, r1
60
        ScatterCurrentChunk r0, r9, r2, r10, lr
        CMP     r9, r4
        MOVHI   r9, r4
        BL      memcpy_r0_r8_r9
        SUB     r4, r4, r9
        ScatterConsume r9, r2, r0, r10, lr
        CMP     r4, #0
        BNE     %BT60
80
        SUBS    r6, r6, #1
        BGE     %BT20        
90
        FRAMSTR r0,VS
        MRS     r1, CPSR
;        DebugTX "done"
        FRAMLDR r2,,r0
        LDR     r0, [r2, #Mem19Ctx_BouncePtr]
        CMP     r0, #0
        SWINE   XPCI_RAMFree
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MSR     CPSR_f, r1
        EXIT

; Copy r9 bytes from r8 to r0
; Out: r0, r8 updated
memcpy_r0_r8_r9 ROUT
        ; Branch to more optimal routine if we've got a reasonable amount of data
        CMP     r9, #32
        Entry   "r9"
        BHI     %FT20
;        DebugRegNCR r0, "memcpy "
;        DebugRegNCR r8, ""
;        DebugReg r9
10
        LDRB    lr, [r8], #1
        SUBS    r9, r9, #1
11
        STRB    lr, [r0], #1
12
        LDRNEB  lr, [r8], #1
        STRNEB  lr, [r0], #1
        SUBNES  r9, r9, #1
        BNE     %BT10
        EXIT

20
        ; Dest will typically be bufferable, but source might not be cacheable
        ; So optimise for reading from source
        Push    "r1-r4"
        ; Start by aligning source
        TST     r8, #1
        LDRNEB  lr, [r8], #1
        SUBNE   r9, r9, #1
        STRNEB  lr, [r0], #1
        TST     r8, #2
        LDRNEH  lr, [r8], #2
        SUBNE   r9, r9, #2
        STRNEB  lr, [r0], #1
        MOVNE   lr, lr, LSR #8
        STRNEB  lr, [r0], #1
        ; Now branch to right variant depending on dest alignment
        AND     lr, r0, #3
        ADD     pc, pc, lr, LSL #2
        DCD     0
        B       %FT40 ; +0
        B       %FT50 ; +1
        B       %FT60 ; +2
30                    ; +3
        LDMIA   r8!, {r1-r4}
        SUBS    r9, r9, #32
        STRB    r1, [r0], #1
31
        MOV     r1, r1, LSR #8
        ORR     r1, r1, r2, LSL #24
        MOV     r2, r2, LSR #8
        STR     r1, [r0], #4
        ORR     r2, r2, r3, LSL #24
        MOV     r3, r3, LSR #8
        STR     r2, [r0], #4
        ORR     r3, r3, r4, LSL #24
        MOV     lr, r4, LSR #8
        STR     r3, [r0], #4
        BLT     %FT32
        LDMIA   r8!, {r1-r4}
        ORR     lr, lr, r1, LSL #24
        SUBS    r9, r9, #16
        STR     lr, [r0], #4
        B       %BT31
32
        STRH    lr, [r0], #2
        MOV     lr, lr, LSR #16
        ADDS    r9, r9, #16
        Pull    "r1-r4"
        B       %BT11

40      ; +0
        SUB     r9, r9, #16
41
        LDMIA   r8!, {r1-r4}
        SUBS    r9, r9, #16
        STMIA   r0!, {r1-r4}
        BGE     %BT41
        ADDS    r9, r9, #16
        Pull    "r1-r4"
        B       %BT12

50      ; +1
        LDMIA   r8!, {r1-r4}
        SUBS    r9, r9, #32
        STRB    r1, [r0], #1
        MOV     r1, r1, LSR #8
        STRH    r1, [r0], #2
        MOV     r1, r1, LSR #16
51
        ORR     r1, r1, r2, LSL #8
        MOV     r2, r2, LSR #24
        STR     r1, [r0], #4
        ORR     r2, r2, r3, LSL #8
        MOV     r3, r3, LSR #24
        STR     r2, [r0], #4
        ORR     r3, r3, r4, LSL #8
        MOV     lr, r4, LSR #24
        STR     r3, [r0], #4
        BLT     %FT52
        LDMIA   r8!, {r1-r4}
        ORR     lr, lr, r1, LSL #8
        SUBS    r9, r9, #16
        STR     lr, [r0], #4
        MOV     r1, r1, LSR #24
        B       %BT51
52
        ADDS    r9, r9, #16
        Pull    "r1-r4"
        B       %BT11

60      ; +2
        LDMIA   r8!, {r1-r4}
        SUBS    r9, r9, #32
        STRH    r1, [r0], #2
61
        MOV     r1, r1, LSR #16
        ORR     r1, r1, r2, LSL #16
        MOV     r2, r2, LSR #16
        STR     r1, [r0], #4
        ORR     r2, r2, r3, LSL #16
        MOV     r3, r3, LSR #16
        STR     r2, [r0], #4
        ORR     r3, r3, r4, LSL #16
        MOV     lr, r4, LSR #16
        STR     r3, [r0], #4
        BLT     %FT62
        LDMIA   r8!, {r1-r4}
        ORR     lr, lr, r1, LSL #16
        SUBS    r9, r9, #16
        STR     lr, [r0], #4
        B       %BT61
62
        STRH    lr, [r0], #2
        ADDS    r9, r9, #16
        Pull    "r1-r4"
        B       %BT12

        END
