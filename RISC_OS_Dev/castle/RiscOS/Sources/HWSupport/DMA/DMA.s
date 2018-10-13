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
; > Sources.DMA

 [ HAL
;-----------------------------------------------------------------------------
; CopyToBounceBuffer
;       In:     r9  ->DMA queue
;               r10 ->DMA request block
;       Out:    Al registers preserved
;
;       Copies the contents of the scatter list to the bounce buffer.
;
CopyToBounceBuffer
        Entry   "r0-r9,r11-r12"
        LDR     r9, [r9, #dmaq_BounceBuff + ptab_Logical] ; r9 = address to copy to
        LDR     r12, [r10, #dmar_Length]        ; r12 = total length to copy
        LDR     lr, [r10, #dmar_Flags]
        TST     lr, #dmarf_Circular
        LDRNE   r11, [r10, #dmar_BuffSize]      ; r11 = length until we reload from start of scatter list
        MOVEQ   r11, r12
10      LDR     r8, [r10, #dmar_ScatterList]    ; (Re)Load scatter list pointer into r8.
20      LDMIA   r8!, {r6,r7}                    ; Load from, length
        CMP     r6, #ScatterListThresh
        TEQHS   r7, #0
        ADDEQ   r8, r8, r6
        SUBEQ   r8, r8, #8
        BEQ     %BT20                           ; Restart if looped scatter list.
        CMP     r7, r11
        MOVHI   r7, r11
        SUB     r11, r11, r7
        SUB     r12, r12, r7
        Push    "r11"                           ; Need one more working register to make eight.

        RSB     r0, r9, #0
        AND     r0, r0, #3                      ; Number of bytes to next word boundary at destination.
        CMP     r7, r0
        MOVLO   r0, r7                          ; May have to do even less for very short blocks.
        SUB     r7, r7, r0
        TEQ     r0, #0
        BEQ     %FT30
        CMP     r0, #2
        LDRB    r1, [r6], #1
        LDRHSB  r2, [r6], #1
        LDRHIB  r3, [r6], #1
        STRB    r1, [r9], #1
        STRHSB  r2, [r9], #1
        STRHIB  r3, [r9], #1
30      TST     r6, #3                          ; Is source now word-aligned?
        BEQ     %FT40                           ; Yes, use fast code.

31      SUBS    r7, r7, #16
        LDRPLB  r0, [r6], #1
        LDRPLB  r1, [r6], #1
        LDRPLB  r2, [r6], #1
        LDRPLB  r3, [r6], #1
        ORRPL   r0, r0, r1, LSL #8
        ORRPL   r0, r0, r2, LSL #16
        ORRPL   r0, r0, r3, LSL #24
        LDRPLB  r1, [r6], #1
        LDRPLB  r2, [r6], #1
        LDRPLB  r3, [r6], #1
        LDRPLB  r4, [r6], #1
        ORRPL   r1, r1, r2, LSL #8
        ORRPL   r1, r1, r3, LSL #16
        ORRPL   r1, r1, r4, LSL #24
        LDRPLB  r2, [r6], #1
        LDRPLB  r3, [r6], #1
        LDRPLB  r4, [r6], #1
        LDRPLB  r5, [r6], #1
        ORRPL   r2, r2, r3, LSL #8
        ORRPL   r2, r2, r4, LSL #16
        ORRPL   r2, r2, r5, LSL #24
        LDRPLB  r3, [r6], #1
        LDRPLB  r4, [r6], #1
        LDRPLB  r5, [r6], #1
        LDRPLB  r11, [r6], #1
        ORRPL   r3, r3, r4, LSL #8
        ORRPL   r3, r3, r5, LSL #16
        ORRPL   r3, r3, r11, LSL #24
        STMPLIA r9!, {r0-r3}
        BPL     %BT31
        ADD     r7, r7, #16
32      SUBS    r7, r7, #4
        LDRPLB  r0, [r6], #1
        LDRPLB  r1, [r6], #1
        LDRPLB  r2, [r6], #1
        LDRPLB  r3, [r6], #1
        ORRPL   r0, r0, r1, LSL #8
        ORRPL   r0, r0, r2, LSL #16
        ORRPL   r0, r0, r3, LSL #24
        STRPL   r0, [r9], #4
        BPL     %BT32
        ADDS    r7, r7, #4
        BEQ     %FT90
        B       %FT80

40      SUBS    r7, r7, #32
        LDMPLIA r6!, {r0-r5,r11,lr}
        STMPLIA r9!, {r0-r5,r11,lr}
        BPL     %BT40
        ADD     r7, r7, #32
        BIC     lr, r7, #3
        SUBS    r7, r7, lr
        ADD     pc, pc, lr, LSL #2
        NOP
        BEQ     %FT90
        B       %FT80
        NOP
        NOP
        LDR     r0, [r6], #4
        STR     r0, [r9], #4
        BEQ     %FT90
        B       %FT80
        LDMIA   r6!, {r0-r1}
        STMIA   r9!, {r0-r1}
        BEQ     %FT90
        B       %FT80
        LDMIA   r6!, {r0-r2}
        STMIA   r9!, {r0-r2}
        BEQ     %FT90
        B       %FT80
        LDMIA   r6!, {r0-r3}
        STMIA   r9!, {r0-r3}
        BEQ     %FT90
        B       %FT80
        LDMIA   r6!, {r0-r4}
        STMIA   r9!, {r0-r4}
        BEQ     %FT90
        B       %FT80
        LDMIA   r6!, {r0-r5}
        STMIA   r9!, {r0-r5}
        BEQ     %FT90
        B       %FT80
        LDMIA   r6!, {r0-r5,r11}
        STMIA   r9!, {r0-r5,r11}
        BEQ     %FT90
        B       %FT80
        LDMIA   r6!, {r0-r5,r11,lr}
        STMIA   r9!, {r0-r5,r11,lr}
        BEQ     %FT90

80      CMP     r7, #2
        LDRB    r1, [r6], #1
        LDRHSB  r2, [r6], #1
        LDRHIB  r3, [r6], #1
        STRB    r1, [r9], #1
        STRHSB  r2, [r9], #1
        STRHIB  r3, [r9], #1
90
        Pull    "r11"
        TEQ     r12, #0                         ; Finished?
        EXIT    EQ
        TEQ     r11, #0
        BNE     %BT20                           ; Do next scatter list entry if not at end of circular buffer
        B       %BT10                           ;   else restart scatter list.

;-----------------------------------------------------------------------------
; CopyFromBounceBuffer
;       In:     r9  ->DMA queue
;               r10 ->DMA request block
;       Out:    Al registers preserved
;
;       Copies the bounce buffer to the contents of the scatter list.
;
CopyFromBounceBuffer
        Entry   "r0-r9,r11-r12"
        LDR     r9, [r9, #dmaq_BounceBuff + ptab_Logical] ; r9 = address to copy from
        LDR     r12, [r10, #dmar_Length]        ; r12 = total length to copy
        LDR     lr, [r10, #dmar_Flags]
        TST     lr, #dmarf_Circular
        LDRNE   r11, [r10, #dmar_BuffSize]      ; r11 = length until we reload from start of scatter list
        MOVEQ   r11, r12
10      LDR     r8, [r10, #dmar_ScatterList]    ; (Re)Load scatter list pointer into r8.
20      LDMIA   r8!, {r6,r7}                    ; Load to, length
        CMP     r6, #ScatterListThresh
        TEQHS   r7, #0
        ADDEQ   r8, r8, r6
        SUBEQ   r8, r8, #8
        BEQ     %BT20                           ; Restart if looped scatter list.
        CMP     r7, r11
        MOVHI   r7, r11
        SUB     r11, r11, r7
        SUB     r12, r12, r7
        Push    "r11"                           ; Need one more working register to make eight.

        RSB     r0, r9, #0
        AND     r0, r0, #3                      ; Number of bytes to next word boundary at source.
        CMP     r7, r0
        MOVLO   r0, r7                          ; May have to do even less for very short blocks.
        SUB     r7, r7, r0
        TEQ     r0, #0
        BEQ     %FT30
        CMP     r0, #2
        LDRB    r1, [r9], #1
        LDRHSB  r2, [r9], #1
        LDRHIB  r3, [r9], #1
        STRB    r1, [r6], #1
        STRHSB  r2, [r6], #1
        STRHIB  r3, [r6], #1
30      TST     r6, #3                          ; Is destination now word-aligned?
        BEQ     %FT40                           ; Yes, use fast code.

31      SUBS    r7, r7, #16
        LDMPLIA r9!, {r0-r3}
        MOVPL   r4, r0, LSR #8
        MOVPL   r5, r0, LSR #16
        MOVPL   r11, r0, LSR #24
        STRPLB  r0, [r6], #1
        STRPLB  r4, [r6], #1
        STRPLB  r5, [r6], #1
        STRPLB  r11, [r6], #1
        MOVPL   r4, r1, LSR #8
        MOVPL   r5, r1, LSR #16
        MOVPL   r11, r1, LSR #24
        STRPLB  r1, [r6], #1
        STRPLB  r4, [r6], #1
        STRPLB  r5, [r6], #1
        STRPLB  r11, [r6], #1
        MOVPL   r4, r2, LSR #8
        MOVPL   r5, r2, LSR #16
        MOVPL   r11, r2, LSR #24
        STRPLB  r2, [r6], #1
        STRPLB  r4, [r6], #1
        STRPLB  r5, [r6], #1
        STRPLB  r11, [r6], #1
        MOVPL   r4, r3, LSR #8
        MOVPL   r5, r3, LSR #16
        MOVPL   r11, r3, LSR #24
        STRPLB  r3, [r6], #1
        STRPLB  r4, [r6], #1
        STRPLB  r5, [r6], #1
        STRPLB  r11, [r6], #1
        BPL     %BT31
        ADD     r7, r7, #16
32      SUBS    r7, r7, #4
        LDRPL   r0, [r9], #4
        MOVPL   r4, r0, LSR #8
        MOVPL   r5, r0, LSR #16
        MOVPL   r11, r0, LSR #24
        STRPLB  r0, [r6], #1
        STRPLB  r4, [r6], #1
        STRPLB  r5, [r6], #1
        STRPLB  r11, [r6], #1
        BPL     %BT32
        ADDS    r7, r7, #4
        BEQ     %FT90
        B       %FT80

40      SUBS    r7, r7, #32
        LDMPLIA r9!, {r0-r5,r11,lr}
        STMPLIA r6!, {r0-r5,r11,lr}
        BPL     %BT40
        ADD     r7, r7, #32
        BIC     lr, r7, #3
        SUBS    r7, r7, lr
        ADD     pc, pc, lr, LSL #2
        NOP
        BEQ     %FT90
        B       %FT80
        NOP
        NOP
        LDR     r0, [r9], #4
        STR     r0, [r6], #4
        BEQ     %FT90
        B       %FT80
        LDMIA   r9!, {r0-r1}
        STMIA   r6!, {r0-r1}
        BEQ     %FT90
        B       %FT80
        LDMIA   r9!, {r0-r2}
        STMIA   r6!, {r0-r2}
        BEQ     %FT90
        B       %FT80
        LDMIA   r9!, {r0-r3}
        STMIA   r6!, {r0-r3}
        BEQ     %FT90
        B       %FT80
        LDMIA   r9!, {r0-r4}
        STMIA   r6!, {r0-r4}
        BEQ     %FT90
        B       %FT80
        LDMIA   r9!, {r0-r5}
        STMIA   r6!, {r0-r5}
        BEQ     %FT90
        B       %FT80
        LDMIA   r9!, {r0-r5,r11}
        STMIA   r6!, {r0-r5,r11}
        BEQ     %FT90
        B       %FT80
        LDMIA   r9!, {r0-r5,r11,lr}
        STMIA   r6!, {r0-r5,r11,lr}
        BEQ     %FT90

80      CMP     r7, #2
        LDRB    r1, [r9], #1
        LDRHSB  r2, [r9], #1
        LDRHIB  r3, [r9], #1
        STRB    r1, [r6], #1
        STRHSB  r2, [r6], #1
        STRHIB  r3, [r6], #1
90
        Pull    "r11"
        TEQ     r12, #0                         ; Finished?
        EXIT    EQ
        TEQ     r11, #0
        BNE     %BT20                           ; Do next scatter list entry if not at end of circular buffer
        B       %BT10                           ;   else restart scatter list.
 ]

;-----------------------------------------------------------------------------
; DMAGetRequestBlock
;       Out:    r10 ->free DMA request block
;
;       Return a free DMA request block.
;
DMAGetRequestBlock
        Entry   "r1-r3"

        Debug   dma,"DMAGetRequestBlock"

        IRQOff  lr, r3                          ; Stop IRQs messing with free chain.

        LDR     r10, FreeBlock                  ; Get free block pointer.
        TEQ     r10, #0
        BLEQ    DMANewBuffer                    ; Need new buffer if no free space.
        ORRVS   r3, r3, #V_bit
        BVS     %FT10

        ASSERT  free_Next = 0
        ASSERT  free_Size = free_Next + 4
        LDMIA   r10, {r1,r2}                    ; r10->free block so get next and size.

        TEQ     r2, #DMARSize                   ; If only one request block then
        STREQ   r1, FreeBlock                   ;   point FreeBlock to next in list
        BEQ     %FT10                           ;   and return.

        SUB     r2, r2, #DMARSize               ; Otherwise, adjust size
        ADD     lr, r10, #DMARSize              ;   and set up remainder of free block.
        STMIA   lr, {r1,r2}
        STR     lr, FreeBlock                   ; Point FreeBlock to remainder.
10
        SetPSR  r3                              ; The world is consistent again so reenable IRQs.
        DebugIf VC,dma," block at ",r10
        EXIT

;-----------------------------------------------------------------------------
; DMAFreeRequestBlock
;       In:     r10 ->DMA request block to free
;
;       Link a DMA request block onto the head of the free list.
;
DMAFreeRequestBlock
        EntryS  "r0,r1"

        Debug   dma,"DMAFreeRequestBlock",r10

        IRQOff  lr                              ; Stop IRQs messing with queue.

        LDR     r0, FreeBlock
        MOV     r1, #DMARSize
        STMIA   r10, {r0,r1}
        STR     r10, FreeBlock

        EXITS   , cf

;-----------------------------------------------------------------------------
; DMANewBuffer
;       Out:    r10 ->free block
;
;       Link a new buffer into the DMA request block list.
;
DMANewBuffer
        Entry   "r0,r2,r3"

        MOV     r0, #ModHandReason_Claim        ; Claim new buffer block.
        MOV     r3, #BlockSize
        SWI     XOS_Module
        EXIT    VS

        LDR     r0, DMABlockHead                ; Link into DMA block buffer list.
        STR     r0, [r2, #block_Next]
        STR     r2, DMABlockHead

        ASSERT  free_Next = 0
        ASSERT  free_Size = free_Next + 4
        ADD     r10, r2, #block_Data            ; r10->free space
        MOV     r0, #0
        MOV     r3, #BlockSize - block_Data     ; Size of free space.
        STMIA   r10, {r0,r3}                    ; Set up free block.

        EXIT

;-----------------------------------------------------------------------------
; DMALinkRequest
;       In:     r9  ->DMA queue
;               r10 ->DMA request block
;
;       Link the DMA request block onto the tail of the queue.
;
DMALinkRequest
        EntryS

        Debug   dma,"DMALinkRequest",r10

        IRQOff  lr                              ; Stop IRQs changing queue.

        LDR     lr, [r9, #dmaq_Tail]            ; Link onto tail.
        TEQ     lr, #0
        STREQ   r10, [r9, #dmaq_Head]           ; If queue was empty then set up as head
        STRNE   r10, [lr, #dmar_Next]           ;   else link onto tail.
        STR     r10, [r9, #dmaq_Tail]           ; Point tail to new entry.
        STR     lr, [r10, #dmar_Prev]           ; Link back.
        MOVNE   lr, #0
        STR     lr, [r10, #dmar_Next]           ; Mark as end of queue.
      [ HAL
        LDR     lr, =dmar_MagicWord
        STR     lr, [r10, #dmar_Magic]
      ]

        EXITS   , cf                            ; Exit restoring IRQs.

      [ HAL
        LTORG
      ]

;-----------------------------------------------------------------------------
; DMAUnlinkRequest
;       In:     r9  ->DMA queue
;               r10 ->DMA request block
;
;       Unlink a DMA request block from a queue.
;
DMAUnlinkRequest
        EntryS  "r0"

        Debug   dma,"DMAUnlinkRequest",r10

        IRQOff  lr                              ; Stop IRQs changing queue.

        LDR     r0, [r10, #dmar_Prev]
        LDR     lr, [r10, #dmar_Next]
        TEQ     r0, #0
        STREQ   lr, [r9, #dmaq_Head]            ; If head of queue then set up next as new head
        STRNE   lr, [r0, #dmar_Next]            ;   else link previous to next.
        TEQ     lr, #0
        STREQ   r0, [r9, #dmaq_Tail]            ; If tail of queue then set up previous as new tail
        STRNE   r0, [lr, #dmar_Prev]            ;   else link next back to previous.
      [ HAL
        MOV     lr, #0                          ; Make this no longer a valid tag
        STR     lr, [r10, #dmar_Magic]
      ]

        EXITS   , cf                            ; Exit restoring IRQs.

;---------------------------------------------------------------------------
; DMAFindTag
;
;       In:     r1 = DMA request tag
;
;       Out:    VC =>   r9->DMA queue
;                       r10->DMA request block
;               VS =>   r0->error
;                       r9,r10 corrupted
;
;       Search the appropriate queue for the DMA request with the given tag.
;
DMAFindTag
      [ HAL
        Entry

        Debug   dma,"DMAFindTag",r1

        CMP     r1, #&01C00000
        BLO     %FT20                           ; obviously not an RMA pointer

        BIC     r10, r1, #3
        LDR     r9, [r10, #dmar_Magic]
        LDR     lr, =dmar_MagicWord
        CMP     r9, lr                          ; is magic word present?
        LDREQ   r9, [r10, #dmar_TagBits01]
        EOREQ   lr, r1, r9
        TSTEQ   lr, #3                          ; do bottom two bits match?
        BNE     %FT20

        LDR     r9, [r10, #dmar_Queue]
        EXIT

20
      |
        Entry   "r2"

        Debug   dma,"DMAFindTag",r1

        AND     r10, r1, #dmar_PhysBits
        CMP     r10, #NoPhysicalChannels
        PullEnv CS
        ADRCS   r0, ErrorBlock_DMA_BadTag
        DoError CS

        PhysToDMAQ r9, r10                      ; r9->DMA queue

        IRQOff  lr, r2                          ; Stop IRQs messing with queue.

        LDR     r10, [r9, #dmaq_Head]           ; Search the queue.
10
        TEQ     r10, #0                         ; If reached the end then
        BEQ     %FT20                           ;   return error.

        LDR     lr, [r10, #dmar_Tag]
        TEQ     lr, r1                          ; If tags don't match then
        LDRNE   r10, [r10, #dmar_Next]          ;   try next.
        BNE     %BT10

        SetPSR  r2

        Debug   dma," =",r10

        EXIT
20
        SetPSR  r2
      ]
        Debug   dma," tag not found"
        PullEnv
        ADR     r0, ErrorBlock_DMA_BadTag
        DoError

        MakeErrorBlock  DMA_BadTag

;-----------------------------------------------------------------------------
; DMACreatePageTable
;       In:     r8  ->logical channel block
;               r10 ->DMA request block
;       Out:    r1 -> page table
;
;       Creates a page table for the given transfer and fills it with
;       logical addresses and section lengths.
;
DMACreatePageTable
      [ HAL
        Entry   "r0,r2-r6"
      |
        Entry   "r0,r2-r5"
      ]

        Debug   dma,"DMACreatePageTable",r10

      [ HAL
        LDR     r6, [r8, #lcb_Flags]
        AND     r6, r6, #lcbf_TransferSize
        SUB     r6, r6, #1
      ]

        LDR     r1, [r10, #dmar_Length]         ; Get length of transfer.
        LDR     lr, [r10, #dmar_Flags]
        TST     lr, #dmarf_Circular             ; If not using a circular buffer then
        BEQ     %FT05                           ;   convert pages spanning length.
        LDR     lr, [r10, #dmar_BuffSize]
        TEQ     r1, #0                          ; Otherwise, if length = 0 (infinite transfer)
        CMPNE   lr, r1                          ;   or buffer size < total length then
        MOVLE   r1, lr                          ;   convert pages spanning buffer size.
05
        LDR     r0, [r10, #dmar_ScatterList]    ; Get scatter list pointer.
        MOV     r4, #0
        LDR     r5, =PAGESIZE-1
        MOV     lr, r1
10
        LDMIA   r0!, {r2,r3}                    ; Get address,length pair.
        CMP     r2, #ScatterListThresh
        TEQHS   r3, #0
        ADDEQ   r0, r0, r2
        SUBEQ   r0, r0, #8                      ; Restart if looped scatter list.
        TEQNE   r3, #0                          ; Skip 0 length entries.
        BEQ     %BT10
        SUBS    lr, lr, r3                      ; Adjust total transfer length.
        ADDCC   r3, lr, r3                      ; If total length < section length then use total length.
      [ HAL
        TST     r2, r6                          ; Check for non-multiples of transfer unit size.
        TSTEQ   r3, r6
        BNE     %FT90
      ]
        AND     r2, r2, r5                      ; Get start offset into page.
        ADD     r2, r2, r3                      ; Add on section length.
        ADD     r2, r2, r5                      ; Count page for possible end segment.
        ADD     r4, r4, r2, LSR #PAGESHIFT      ; Add no. of pages spanned by this section to total.
      [ HAL
        CMP     lr, #0
      ]
        BGT     %BT10

        Debug   dma," page count =",r4

        MOV     r0, #ModHandReason_Claim        ; Claim space for table (r4=no. of pages).
        MOV     r3, r4, LSL #2
        ADD     r3, r3, r3, LSL #1              ; 3 words per entry (r3=r4*12).
        SWI     XOS_Module
        STRVS   r0, [sp]                        ; If error then return r0.
        EXIT    VS

        Debug   dma," page table, size =",r2,r3

        STR     r2, [r10, #dmar_PageTable]
        STR     r4, [r10, #dmar_PageCount]

        LDR     r0, [r10, #dmar_ScatterList]    ; Fill length and logical address fields in table.
20
        LDMIA   r0!, {r4,lr}                    ; Get address,length pair.
        CMP     r4, #ScatterListThresh
        TEQHS   lr, #0
        ADDEQ   r0, r0, r4
        SUBEQ   r0, r0, #8                      ; Restart if looped scatter list.
        TEQNE   lr, #0                          ; Skip 0 length entries.
        BEQ     %BT20
        SUBS    r1, r1, lr                      ; Adjust total transfer length.
        ADDCC   lr, r1, lr                      ; If total length < section length then use total length.
        AND     r3, r4, r5                      ; Get start offset into page.
        RSB     r3, r3, #PAGESIZE               ; Convert to length to end of page.
30
        SUBS    lr, lr, r3                      ; Adjust section length.
        ADDCC   r3, lr, r3                      ; If section length < offset to page end then use section length.
        Debug   dma," length,address =",r3,r4
        STMIA   r2!, {r3,r4,r5}                 ; Store section entry (length, address, r5 just pads it out).
        ADDGT   r4, r4, r3                      ; If more to do then adjust logical address
        MOVGT   r3, #PAGESIZE                   ;   offset to end of page is PAGESIZE from now on
        BGT     %BT30                           ;   and do next page.
        CMP     r1, #0
        BGT     %BT20

        LDR     r1, [r10, #dmar_PageTable]
        EXIT

 [ HAL
90
        PullEnv
        ADRL    r0, ErrorBlock_DMA_BadSize
        DoError
 ]

        LTORG

;-----------------------------------------------------------------------------
; DMAConvertPageTable
;       In:     r8  ->logical channel block
;               r9  ->DMA queue
;               r10 ->DMA request block
;
;       Fill in physical addresses in page table and mark pages as uncacheable
;       if reading to memory.
;       However, if WriteBackCache true, then mark pages as uncacheable for either
;       direction of transfer (we could be running with a write-back data cache,
;       so DMA from memory to device can be out of date wrt cache).
;
DMAConvertPageTable
        Entry   "r0-r3"

        Debug   dma,"DMAConvertPageTable",r10

        MOV     r0, #Memory_LogicalGiven :OR: Memory_PhysicalWanted
        LDR     r1, [r10, #dmar_PageTable]
        TEQ     r1, #0                          ; If no page table yet then
        BLEQ    DMACreatePageTable              ;   create one.
        BVS     %FT90
        LDR     r2, [r10, #dmar_PageCount]
        LDR     r3, [r10, #dmar_Flags]
 [ WriteBackCache
        ORR     r3, r3, #dmarf_Uncacheable      ;   set uncacheable flag
        STR     r3, [r10, #dmar_Flags]

        ORR     r0, r0, #Memory_SetUncacheable  ;   and mark pages as uncacheable.
 |
        TST     r3, #dmarf_Direction            ; If reading to memory then
        ORREQ   r3, r3, #dmarf_Uncacheable      ;   set uncacheable flag
        STREQ   r3, [r10, #dmar_Flags]

        ORREQ   r0, r0, #Memory_SetUncacheable  ;   and mark pages as uncacheable if necessary.
 ]
        Debug   dma," OS_Memory flags,ptable,entries =",r0,r1,r2
        SWI     XOS_Memory
        BICVS   r3, r3, #dmarf_Uncacheable      ; If conversion failed then pages not uncacheable
        STRVS   r3, [r10, #dmar_Flags]
90      STRVS   r0, [sp]                        ;   and return error.

        EXIT

;-----------------------------------------------------------------------------
; DMAReleasePageTable
;       In:     r10 ->DMA request block
;
;       If the operation was read to memory then mark the specified pages
;       as cacheable.  If the transfer has been flagged as completed then
;       the memory for the page table is freed.
;
DMAReleasePageTable
        Entry   "r0-r3"

        LDR     r1, [r10, #dmar_PageTable]
        TEQ     r1, #0                          ; If no page table then
        EXIT    EQ                              ;   nothing to do.

        Debug   dma,"DMAReleasePageTable",r10

        LDR     r3, [r10, #dmar_Flags]
        TST     r3, #dmarf_Uncacheable          ; If pages have been marked as uncacheable then
        BICNE   r3, r3, #dmarf_Uncacheable      ;   clear uncacheable flag
        STRNE   r3, [r10, #dmar_Flags]
        MOVNE   r0, #Memory_LogicalGiven :OR: Memory_PhysicalGiven :OR: Memory_SetCacheable
        LDRNE   r2, [r10, #dmar_PageCount]
        SWINE   XOS_Memory                      ;   and make them cacheable again.
        TST     r3, #dmarf_Completed            ; If the transfer has completed then
        MOVNE   r0, #ModHandReason_Free         ;   free the page table.
        MOVNE   r2, r1
        SWINE   XOS_Module

        EXIT

;-----------------------------------------------------------------------------
; DMAActivate
;       In:     r8  ->logical channel block
;               r9  ->DMA queue
;               r10 ->DMA request block
;       [ :LNOT: HAL
;               r11 = IOMD base address
;       ]
;
;       Activate the specified DMA request.  The Start routine is only called
;       if the DMA is being activated for the first time.  If a DMA request is
;       already active on this channel or the channel is blocked then the
;       request is simply left in the queue.  If the Start callback returns an
;       error then the request is completed and the error passed back to the
;       caller, the channel also remains claimed so that the caller may try to
;       start another using DMAForceActivate.
;
DMAActivate
      [ HAL
        EntryS  "r0-r5,r11-r12"
      |
        EntryS  "r1-r4,r11,r12"
      ]

        Debug   dma,"DMAActivate",r10

        IRQOff  lr, r4                          ; Stop IRQs messing with queue.

        LDR     lr, [r9, #dmaq_Active]
        TEQ     lr, #0                          ; If there is an active DMA
        DebugIf NE,tmp,"DMA already active"
        LDREQ   lr, [r8, #lcb_Flags]
        TSTEQ   lr, #lcbf_Blocked               ;     or logical channel is blocked then
        DebugIf NE,tmp,"Aborting DMAActivate"
        EXITS   NE, cf                          ;   leave in queue and exit restoring IRQs.

        STR     r10, [r9, #dmaq_Active]         ; Otherwise, make active.
        SetPSR  r4                              ; Claimed channel so reenable IRQs.
        B       %FT05

; Entry point which skips above tests.
DMAForceActivate
        ALTENTRY

        Debug   dma,"DMAForceActivate"

        STR     r10, [r9, #dmaq_Active]         ; Make active.
05
        Debug   dma," activating"

      [ HAL
        LDR     r5, [r9, #dmaq_DMADevice]       ; r5 = HAL device for this channel
      |
        LDR     r1, [r8, #lcb_Physical]
        DMARegBlk r3, r1                        ; r3->DMA register block for this channel
      ]

        LDR     r11, [r10, #dmar_R11]           ; Set up r11 value.
        LDR     r12, [r8, #lcb_R12]             ; Set up r12 value.
        LDR     r1, [r8, #lcb_Vector]           ; r1->vector of routines

        SwpPSR  r4, SVC_mode+I_bit, r2          ; Ensure SVC mode, no IRQs for callbacks and address conversion (also clears V).
        Push    lr                              ; Save SVC_lr.

        Debug   tmp," r11,r12 =",r11,r12

        LDR     r2, [r10, #dmar_Flags]
        TST     r2, #dmarf_BeenActive           ; If not been active before then
        MOVEQ   lr, pc                          ;   call Start routine.
        LDREQ   pc, [r1, #vector_Start]
        BVS     %FT40

      [ HAL
        LDR     lr, [r9, #dmaq_BounceBuff + ptab_Logical]
        TEQ     lr, #0                          ; Only create page tables if not using a bounce buffer.
        LDREQ   r12, [sp, #4+28+Proc_RegOffset]
        BLEQ    DMAConvertPageTable
        LDR     r12, [r8, #lcb_R12]
      |
        BL      DMAConvertPageTable
      ]
        BVS     %FT40

        Debug   tmp," r11,r12 =",r11,r12

      [ HAL
        MOV     r0, r5
        CallHAL Reset
        LDR     r1, [r8, #lcb_Vector]           ; r1->vector of routines

        LDR     lr, [r9, #dmaq_DescBlockLogical]
        TEQ     lr, #0                          ; List-type device?
        BNE     %FT50                           ; Use alternate code if so.
      |
        MOV     lr, #IOMD_DMA_C_Bit             ; Clear DMA channel before calling Enable (stop extra transfers).
        STRB    lr, [r3, #IOMD_IOxCR]
      ]

        MOV     lr, pc                          ; Call Enable routine.
        LDR     pc, [r1, #vector_Enable]

        Debug   dma," start and enable called"

        Pull    lr                              ; Restore SVC_lr.
        SetPSR  r4                              ; Back to original mode/IRQs.

      [ HAL
        ADD     lr, r10, #dmar_CurrBuff         ; Initialise last buffer programmed.
      |
        ADD     lr, r10, #dmar_BuffA            ; Initialise last buffer programmed.
      ]
        STR     lr, [r9, #dmaq_LastBuff]

        LDR     r2, [r10, #dmar_Flags]
        TST     r2, #dmarf_BeenActive           ; If resuming a suspended request then
        BNE     %FT10                           ;   don't initialise any more.

        Debug   dma," initialising request block"

      [ HAL
        ADD     lr, r10, #dmar_CurrBuff         ; To initialise buffers.
        ASSERT  dmar_NextBuff = dmar_CurrBuff + 12
      ]
        MOV     r11, #0
        MOV     r12, #0

        LDR     r1, [r10, #dmar_PageTable]
        STMIA   lr!, {r1,r11,r12}               ; Initialise buff A.
        STMIA   lr, {r1,r11,r12}                ; Initialise buff B.

        TST     r2, #dmarf_Circular             ; Initialise data for circular buffer (if used).
        LDRNE   r1, [r10, #dmar_BuffSize]
        STRNE   r1, [r10, #dmar_BuffLen]

        TST     r2, #dmarf_Sync                 ; Initialise data for DMASync callback (if used).
        LDRNE   r1, [r10, #dmar_SyncGap]
        STRNE   r1, [r10, #dmar_ProgGap]
        STRNE   r12, [r10, #dmar_Gap]

10
      [ HAL
        ORR     r2, r2, #dmarf_BeenActive
        STR     r2, [r10, #dmar_Flags]

        LDR     r3, [r8, #lcb_Flags]
        ANDS    r1, r2, #dmarf_Direction        ; build flags word in r1
        ASSERT  dmarf_Direction = DMASetOptionsFlag_Write
        LDREQ   r2, [r8, #lcb_PeripheralRead]
        LDRNE   r2, [r8, #lcb_PeripheralWrite]
        ORR     r1, r1, r3, LSL #1              ; note lcbf_Registered is shifted off end, and lcbf_Blocked will be clear
        MOV     r0, r5
        CallHAL DMASetOptions
        LDR     r12, [sp, #28+Proc_RegOffset]   ; Restore our workspace pointer.
      |
        LDR     r4, [r8, #lcb_Flags]            ; Set up control register.
        AND     r1, r4, #lcbf_TransferSize
        ORR     r1, r1, #IOMD_DMA_C_Bit :OR: IOMD_DMA_E_Bit
        AND     r2, r2, #dmarf_Direction
        EOR     r2, r2, #dmarf_Direction        ; Someone screwed up, direction bit wrong way round!
        ORR     r1, r1, r2, LSL #6
        STRB    r1, [r3, #IOMD_IOxCR]           ; Set control register.
        Debug   dma," set control (cr,block) =",r1,r12

        MOV     r11, #IOMD_Base                 ; Restore r11=IOMD base address.
        LDR     r2, [r8, #lcb_Physical]         ; r2=physical channel number
        CMP     r2, #4                          ; If it's not one of the general IO channels then
        BCS     %FT20                           ;   no need to program DMATCR.

        MOV     r1, #&03                        ; Set cycle speed in DMATCR.
        MOV     r1, r1, LSL r2
        AND     r4, r4, #lcbf_DMASpeed
        MOV     r4, r4, LSR #5
        MOV     r4, r4, LSL r2
        IRQOff  lr, r12
        LDRB    lr, [r11, #IOMD_DMATCR]
        BIC     lr, lr, r1, LSL r2
        ORR     lr, lr, r4, LSL r2
        STRB    lr, [r11, #IOMD_DMATCR]
        SetPSR  r12
        Debug   dma," DMATCR =",lr
20
        LDR     r12, [sp, #20+Proc_RegOffset]   ; Restore our workspace pointer.
      ]
        LDR     r1, UnsafePageTable
        TEQ     r1, #0                          ; If no unsafe page table then
      [ HAL
        LDREQ   r1, [r10, #dmar_Flags]
      ]
        BEQ     %FT30                           ;   start the transfer.

      [ HAL
        LDR     lr, [r9, #dmaq_BounceBuff + ptab_Logical]
        TEQ     lr, #0                          ; If using a bounce buffer
        LDRNE   r1, [r10, #dmar_Flags]
        ORRNE   r1, r1, #dmarf_Halted           ;   then mark as halted, irrespective of which pages are unsafe
        STRNE   r1, [r10, #dmar_Flags]
        EXITS   NE, f                           ;   and restart when pages become safe again.
      ]
        MOV     r2, r1                          ; Otherwise, scan the page table for unsafe pages.
        LDR     r3, UnsafePageCount
        LDR     r1, [r10, #dmar_Flags]
        BL      DMAUnsafeScan
        TST     r1, #dmarf_Halted               ; If transfer is halted then
        EXITS   NE, f                           ;   wait for Service_PagesSafe to start it. (CPSR c bits don't need restoring)
      [ :LNOT: HAL
        LDR     r2, [r8, #lcb_Physical]
      ]
30
      [ HAL
        TST     r1, #dmarf_Direction            ; If a write operation
        LDRNE   lr, [r9, #dmaq_BounceBuff + ptab_Logical]
        TEQNE   lr, #0                          ;   and there's a bounce buffer for this physical channel
        BLNE    CopyToBounceBuffer              ;   then we need to fill in the bounce buffer.

        LDR     r0, [r5, #HALDevice_Device]     ; We only need to program the first transfer now
        CMP     r0, #-1                         ;    if the channel has no interrupt.
        BEQ     %FT32
                                                ; Otherwise we rely on the first interrupt to trigger programming.
        LDR     r0, [r9, #dmaq_DeviceFeatures]  ; Except not all DMA controllers can (sensibly) be made to trigger
        TST     r0, #DMAFeaturesFlag_NoInitIRQ  ; an interrupt when they've got no data, so we need to check the flags as well
        BEQ     %FT35

        ; We have an IRQ (so we don't want to use the bounce buffer), but the
        ; interrupt is not initially there - an initial transfer is needed.
        ; Use 'program' to do the initial setup to kickstart the process.
        Push    "r5-r10"                        ; Play it safe and store everything that 'program' might clobber (which hasn't already been stored on entry to DMAActivate)
        LDR     r0, [r10, #dmar_Length]
        MOV     r11, r5
        LDR     r3, [r9, #dmaq_LastBuff]
        LDR     r7, [r11, #HALDevice_DMASetCurrentTransfer]
        ADD     r5, r10, #dmar_CurrBuff
        LDR     r8, [r10, #dmar_Flags]
        BL      program
        ; Calling 'program' also updates the request structure and sets the first buffer running.
        ; So now we've no way of inferring from DMAStatus whether this controller supports a
        ; second buffer, and single buffered HAL implementations of DMASetNextTransfer are a
        ; dummy function, the feature flag is the only safe was to see if a next transfer is possible.
        LDR     r9, [sp, #4*4]
        LDR     lr, [r9, #dmaq_DeviceFeatures]
        TST     lr, #DMAFeaturesFlag_DoubleBuffered
        BEQ     %FT31                           ; Never call DMASetNextTransfer on a single buffered controller
        LDR     r10, [sp, #5*4]
        LDR     r8, [r10, #dmar_Flags]
        TST     r8, #dmarf_Infinite
        LDR     r0, [r10, #dmar_Length]
        TEQEQ   r0, #0
        BEQ     %FT31                           ; Finite with no bytes remaining
        LDR     r11, [sp, #0*4]                 ; Infinite, or finite with bytes remaining
        LDR     r7, [r11, #HALDevice_DMASetNextTransfer]
        ADD     r3, r10, #dmar_CurrBuff
        ADD     r5, r10, #dmar_NextBuff
        BL      program
        STR     r5, [r9, #dmaq_LastBuff]
31
        Pull    "r0,r6-r10"                     ; Reload device ptr in R0 so we can call the device
        CallHAL Activate
        EXITS   , f
        
32
        ADD     r3, r10, #dmar_CurrBuff         ; Program current buffer with a single transfer to/from the bounce buffer.
        ADD     r0, r9, #dmaq_BounceBuff
        MOV     r1, #0
        LDR     r2, [r10, #dmar_Length]
        STR     r2, [r0, #ptab_Len]
        STMIA   r3, {r0-r2}
        STR     r1, [r10, #dmar_NextBuff + buff_Len] ; Mark next buffer as not programmed.
        STR     r3, [r9, #dmaq_LastBuff]        ; Current buffer was most recently programmed.

        LDR     r1, [r0, #ptab_Physical]
        MOV     r0, r5
        ; r2 is already the transfer length
        MOV     r3, #DMASetTransferFlag_Stop
        CallHAL DMASetCurrentTransfer

35      MOV     r0, r5
        CallHAL Activate

        EXITS   , f
      |
        IRQOff  lr
        MOV     r4, #1                          ; Enable interrupt for this channel.
        LDRB    r1, [r11, #IOMD_DMAMSK]
        ORR     r1, r1, r4, LSL r2
        STRB    r1, [r11, #IOMD_DMAMSK]

        EXITS   , cf                            ; Exit restoring IRQs.
      ]

40
        ORR     r2, r2, #dmarf_Completed        ; If we got an error along the way then
        STR     r2, [r10, #dmar_Flags]          ;   set completed flag
        MOV     lr, pc                          ;   call Completed call back (r11,r12 still set up)
        LDR     pc, [r1, #vector_Completed]
        BL      DMAReleasePageTable             ;   free page table
        Pull    lr                              ;   restore SVC_lr
        SetPSR  r4                              ;   go back to original mode/IRQs

        Debug   dma," error in activate, complete called"

        SETV                                    ;   and pass error back to caller.
      [ HAL
        STR     r0, [sp, #Proc_RegOffset]
      ]
        EXIT


      [ HAL
50      ; Set up a transfer using a list-type device.
        LDR     r2, [r10, #dmar_Flags]
        TST     r2, #dmarf_BeenActive
        BNE     %FT51
        LDR     lr, [r9, #dmaq_DeviceFeatures]
        LDR     lr, [lr, #DMAFeaturesBlock_Flags]
        MOV     r12, #0
        TST     lr, #DMAFeaturesFlag_NoSyncIRQs
        LDREQ   lr, [r10, #dmar_SyncGap]
        MOVNE   lr, #0
        STR     lr, [r10, #dmar_PhysSyncGap]
        STR     r12, [r10, #dmar_Gap]
51      ORR     r2, r2, #dmarf_BeenActive
        STR     r2, [r10, #dmar_Flags]

        LDR     r12, [sp, #4+28+Proc_RegOffset]
        BL      BuildDescriptorTable            ; preserves r1
        LDR     r12, [r8, #lcb_R12]
        LDRVS   r2, [r10, #dmar_Flags]
        BVS     %BT40

        MOV     lr, pc                          ; Call Enable routine.
        LDR     pc, [r1, #vector_Enable]

        Debug   dma," start and enable called"

        Pull    lr                              ; Restore SVC_lr.
        SetPSR  r4                              ; Back to original mode/IRQs.

        LDR     lr, [r10, #dmar_Flags]
        LDR     r3, [r8, #lcb_Flags]
        ANDS    r1, lr, #dmarf_Direction        ; build flags word in r1
        ASSERT  dmarf_Direction = DMASetOptionsFlag_Write
        LDREQ   r2, [r8, #lcb_PeripheralRead]
        LDRNE   r2, [r8, #lcb_PeripheralWrite]
        TST     lr, #dmarf_Circular
        ORRNE   r1, r1, #DMASetOptionsFlag_Circular
        ORR     r1, r1, r3, LSL #1              ; note lcbf_Registered is shifted off end, and lcbf_Blocked will be clear
        MOV     r0, r5
        CallHAL DMASetOptions
        LDR     r12, [sp, #28+Proc_RegOffset]   ; Restore our workspace pointer.

        LDR     r2, UnsafePageTable
        TEQ     r2, #0                          ; If no unsafe page table then
        BEQ     %FT70                           ;   start the transfer.
        LDR     r3, UnsafePageCount
        LDR     r1, [r10, #dmar_Flags]
        BL      DMAUnsafeScan
        TST     r1, #dmarf_Halted               ; If transfer is halted then
        EXITS   NE, f                           ;   wait for Service_PagesSafe to start it. (CPSR c bits don't need restoring)

70      LDR     lr, [r10, #dmar_Done]
        LDR     r4, [r10, #dmar_Length]         ; Already holds 0 iff infinite.
        MOV     r0, r5
        LDR     r1, [r9, #dmaq_DescBlockPhysical]
        LDR     r2, [r9, #dmaq_DescBlockLogical]
        LDR     r3, [r9, #dmaq_DescBlockCount]
        STR     lr, [r10, #dmar_DoneAtStart]
        CallHAL DMASetListTransfer, "r4"        ; ATPCS arg 5 pushed

        MOV     r0, r5
        CallHAL Activate

        EXITS   , f
      ]

 [ HAL
;-----------------------------------------------------------------------------
; BuildDescriptorTable
;       In:     r9  ->DMA queue
;               r10 ->DMA request block
;       Out:    r0,r2,r3 corrupted, other registers preserved
;               may return error "Transfer too complex" if list won't fit in block
;
;       Creates an array of physical address/length pairs in the transfer descriptors block
;       * starting a distance into the page table dictated by dmar_Done,
;         (modulus dmar_BuffSize if circular)
;       * continuing for dmar_Length, or dmar_BuffSize if smaller or if an infinite transfer,
;         wrapping round to start of page table if circular
;       * splitting at multiples of dmar_PhysSyncGap (offset by dmar_Gap)
;       * splitting so as to obey device's TransferLimit and TransferBound restrictions
;
BuildDescriptorTable
        Entry   "r1,r4-r8,r11"

        LDR     lr, [r10, #dmar_Flags]
        LDR     r0, [r10, #dmar_Done]
        TST     lr, #dmarf_Circular
        LDREQ   r2, [r10, #dmar_Length]         ; r2 = amount remaining to be transferred (no wrap since non-circular)
        BEQ     %FT01
        LDR     r2, [r10, #dmar_BuffSize]       ; r2 = total amount of data referenced by page table
        DivRem  r6, r0, r2, r7                  ; r0 = r0 MOD BuffSize; r6,r7 corrupted
        SUB     r2, r2, r0                      ; r2 = amount until wrap (if any)
01                                              ; r0 = starting byte offset into page table
        LDR     r5, [r10, #dmar_PageTable]
10      LDR     r6, [r5], #ptab_Len
        SUBS    r0, r0, r6                      ; compare amount remaining to skip with this page table entry
        ADDLO   r0, r0, r6                      ; skipping ends before the end of this entry, so add length back on
        SUBLO   r5, r5, #ptab_Len               ;   and wind back page table pointer
        BHI     %BT10                           ; skipping continues into next entry (if EQ, break from loop pointing at next)

        LDR     r6, [r10, #dmar_PhysSyncGap]
        LDR     r7, [r10, #dmar_Gap]
        LDR     r11, [r9, #dmaq_DeviceFeatures]
        SUBS    r6, r6, r7
        MOVEQ   r6, #-1                         ; if both were zero (they cannot otherwise be equal), don't impose this limit
        LDR     r7, [r9, #dmaq_DescBlockLogical]
        LDR     r8, [r11, #DMAFeaturesBlock_MaxTransfers]

        LDR     r1, [r10, #dmar_BuffSize]
        LDR     r4, [r10, #dmar_Length]
        CMP     r4, r1                          ; assume circular: total data to create descriptors for = min(BuffSize, Length)
                                                ; this sets C if min(BuffSize, Length) = BuffSize
        TST     lr, #dmarf_Infinite, 0          ; preserves C
        ASSERT  dmarf_Infinite = 1:SHL:4
        TEQNE   lr, lr, LSR #4+1                ; if infinite, must create dmar_BuffSize-worth of descriptors, so set C
        TST     lr, #dmarf_Circular, 0          ; preserves C
        ASSERT  dmarf_Circular = 1:SHL:1
        TEQEQ   lr, lr, LSR #1+1                ; if not circular, must create dmar_Length-worth of descriptors, so clear C
        MOVCS   r4, r1

        SUBS    r1, r4, r2                      ; r1 = amount to do after wrap point (may be -ve if we don't reach it)
        MOVHI   r4, r2                          ; only do up to the wrap point if wrapping
        BL      BuildPartialDescriptorTable
        BVS     %FT90

        MOVS    r4, r1                          ; V is clear, so this can be treated as a signed comparison with 0
        MOVGT   r0, #0
        LDRGT   r5, [r10, #dmar_PageTable]
        BLGT    BuildPartialDescriptorTable     ; do the part after the wrap (if any)

        LDRVC   lr, [r11, #DMAFeaturesBlock_MaxTransfers]
        SUBVC   lr, lr, r8
        STRVC   lr, [r9, #dmaq_DescBlockCount]  ; store the number of transfer descriptors we used
90
        EXIT

;-----------------------------------------------------------------------------
; BuildPartialDescriptorTable
;       In:     r0  = amount of data to skip from the start of the first page table entry
;               r4  = total data count to build descriptors for
;               r5  ->input page table (may be some entries into the request block's original table)
;               r6  = data count until next sync gap
;               r7  ->output descriptor block
;               r8  = number of descriptors available in block
;               r9  ->DMA queue
;               r10 ->DMA request block
;               r11 ->device features block
;       Out:    r6-r8 updated
;               r1,r9-r11 preserved
;               r0,r2-r5 corrupted
;               may return error "Transfer too complex" if list won't fit in block
;
;       Does the work of BuildDescriptorTable for a contiguous group of entries in the page table.
BuildPartialDescriptorTable
        Entry   "r1,r12"
        LDR     r3, [r5, #ptab_Len]             ; build contiguous physical length in r3, starting with first page table entry
        LDR     lr, [r5, #ptab_Physical]
        SUB     r3, r3, r0
        ADD     r0, lr, r0                      ; r0 -> physical address to start from
        LDR     r12, [r11, #DMAFeaturesBlock_TransferBound]

20      CMP     r3, r4
        MOVHI   r3, r4                          ; if this page table entry exceeds data requested, trim down
        BHS     %FT30                           ; branch if we don't need any more page table entries
        LDR     r1, [r5, #PTABSize]!            ; length of next page table entry, and progress pointer
        ASSERT  ptab_Len = 0
        LDR     lr, [r5, #ptab_Physical]        ; physical address from same page table entry
        ADD     r2, r0, r3                      ; end of the block we have so far
        TEQ     lr, r2                          ; contiguous?
        ADDEQ   r3, r3, r1                      ; yes, so add on the length from this entry
        BEQ     %BT20                           ;   and loop
30      SUB     r4, r4, r3                      ; r3 = length of contiguous physical space, so decrement from total

        LDR     lr, [r11, #DMAFeaturesBlock_TransferLimit]
        SUB     r2, r12, #1
        ADD     r1, r0, r12
        BIC     r1, r1, r2
        SUB     r1, r1, r0                      ; r1 = distance to next address space boundary
        TEQ     lr, #0
        MOVEQ   lr, #-1                         ; ensure transfer limit isn't 0

40      SUBS    r8, r8, #1                      ; we're going to use another descriptor
        BMI     %FT90                           ; error if we've run out
        CMP     r1, lr
        MOVHS   r2, lr
        MOVLO   r2, r1
        CMP     r3, r2
        MOVLO   r2, r3
        CMP     r6, r2
        MOVLO   r2, r6                          ; r2 = distance to next descriptor boundary
        SUBS    r1, r1, r2
        MOVEQ   r1, r12
        SUBS    r6, r6, r2
        LDREQ   r6, [r10, #dmar_PhysSyncGap]
        STMIA   r7!, {r0, r2}                   ; fill in transfer decriptor
        ADD     r0, r0, r2
        SUBS    r3, r3, r2
        BNE     %BT40

        CMP     r4, #0
        LDRNE   r0, [r5, #ptab_Physical]
        LDRNE   r3, [r5, #ptab_Len]
        BNE     %BT20

        EXIT
90
        Debug   dma, "transfer too complex"
        PullEnv
        ADR     r0, ErrorBlock_DMA_TooComplex
        DoError

        MakeErrorBlock  DMA_TooComplex
 ]

;-----------------------------------------------------------------------------
; DMATerminate
;       In:     r0  = 0 (suspend) or ->error block (terminate)
;       [ :LNOT: HAL
;               r1  = DMA tag
;       ]
;               r8  ->logical channel block
;               r9  ->DMA queue
;               r10 ->DMA request block
;       [ :LNOT: HAL
;               r11 = IOMD base address
;       ]
;
;       Terminate the specified DMA request.  An error is returned if the
;       request block is invalid.  If the request is not active and we are
;       terminating then the Completed callback is called and the routine
;       exits.  If the request is not active and we are suspending then an
;       error is returned.  If the request is active then it is stopped,
;       the scatter list is updated and the appropriate action taken for
;       suspend or terminate.  The stopped request is left blocking the
;       physical channel and must be removed by the caller (usually by
;       calling DMASearchQueue).
;
DMATerminate
        Entry   "r0-r8,r11,r12"

        Debug   dma,"DMATerminate",r10

        IRQOff  lr, r7                          ; Stop IRQs messing with queue.

      [ HAL
        LDR     r1, =dmar_MagicWord
        LDR     lr, [r10, #dmar_Magic]          ; Make sure it's still there.
      |
        LDR     lr, [r10, #dmar_Tag]            ; Make sure it's still there.
      ]
        TEQ     lr, r1
        ADRNEL  r0, ErrorBlock_DMA_BadTag
        BNE     %FT90

        LDR     lr, [r9, #dmaq_Active]
        TEQ     lr, r10                         ; If not active then
        BNE     %FT91                           ;   deal with it.

      [ HAL
        LDR     r4, [r9, #dmaq_DMADevice]       ; r4 = HAL device for this channel
        TEQ     r0, #0                          ; Terminate or suspend?
        MOV     r0, r4
        ADR     lr, %FT01
        LDREQ   pc, [r0, #HALDevice_Deactivate] ; Disable DMA.
        LDRNE   pc, [r0, #HALDevice_DMAAbort]
01
        SetPSR  r7                              ; Reenable general IRQs.
      |
        LDR     r1, [r8, #lcb_Physical]         ; Otherwise, disable channel IRQ.
        MOV     r2, #1
        LDRB    lr, [r11, #IOMD_DMAMSK]
        BIC     lr, lr, r2, LSL r1
        STRB    lr, [r11, #IOMD_DMAMSK]

        SetPSR  r7                              ; Reenable general IRQs.

        DMARegBlk r2, r1                        ; r2->IOMD DMA register block
        LDRB    r1, [r2, #IOMD_IOxCR]
        BIC     r1, r1, #IOMD_DMA_E_Bit
        STRB    r1, [r2, #IOMD_IOxCR]           ; Disable DMA.
        Debug   term," transfer halted, CR =",r1
      ]

        LDR     r11, [r10, #dmar_R11]           ; Set up r11 value.
        LDR     r12, [r8, #lcb_R12]             ; Set up r12 value.
        LDR     r3, [r8, #lcb_Vector]           ; r3->vector of routines

        MOV     lr, pc                          ; Call Disable routine.
        LDR     pc, [r3, #vector_Disable]

      [ HAL
        LDR     lr, [r9, #dmaq_DescBlockLogical]
        TEQ     lr, #0                          ; List-type device?
        BNE     %FT70                           ; Use alternate code if so.

        MOV     r0, r4
        CallHAL DMAStatus
        MOV     r11, r0

        LDR     r8, [r10, #dmar_Flags]

        AND     lr, r8, #dmarf_Direction
        TEQ     lr, #dmarf_Direction            ; If a read operation
        LDRNE   lr, [r9, #dmaq_BounceBuff + ptab_Logical]
        TEQNE   lr, #0                          ;   and there's a bounce buffer for this physical channel then we need
        BLNE    CopyFromBounceBuffer            ;   to read from the bounce buffer now, before the scatter list is trashed.

        LDR     r3, [r9, #dmaq_LastBuff]
        SUB     r5, r3, r10
        EOR     r5, r5, #dmar_CurrBuff :EOR: dmar_NextBuff
        TST     r11, #DMAStatusFlag_NoUnstarted :OR: DMAStatusFlag_Overrun
        ADDEQ   r3, r5, r10                     ; If double-buffered and not interrupting, then not-last-programmed buffer has
                                                ;   been halted, and last-programmed buffer is programmed but hasn't started
                                                ;   transferring yet.
        ADDNE   r0, r5, r10                     ; Else if not in overrun then not-last-programmed buffer has either not been
                                                ;   programmed, or it has completed transfer; or if in overrun, then deal
        BLNE    update                          ;   with the older of the two completed buffers.

        LDMIA   r3, {r5,r6,r7}
        TST     r11, #DMAStatusFlag_Overrun     ; If in overrun state,
        MOVNE   r2, r7                          ;   then all of other buffer has also been transferred.
        BNE     %FT10
        MOV     r0, r4                          ; Otherwise account for halted buffer.
        MOV     r4, r3
        CallHAL DMATransferState
        MOV     r3, r4
        LDR     r2, [r5, #ptab_Physical]
        ADD     r2, r2, r6                      ; This is what the hardware was originally programmed with.
        SUB     r2, r0, r2                      ; Amount actually done.
        STR     r2, [r3, #buff_Len]             ; Fake up buffer info for the benefit of update.
10
        Debug   term," interrupted done =",r2
        MOV     r0, r3                          ; Update from interrupted buffer (or in overrun case, second buffer).
        BL      update

        TST     r11, #DMAStatusFlag_NoUnstarted :OR: DMAStatusFlag_Overrun
        LDREQ   r1, [r10, #dmar_NextBuff + buff_Len] ; If double-buffered and not interrupting, this much was also programmed.
        SUB     r0, r7, r2                      ; r0 = amount programmed but not transferred in interrupted buffer
        ADDEQ   r0, r0, r1                      ; Add on amount programmed in unused buffer (if applicable).
        Debug   term," not done =",r0

      |
        LDRB    r1, [r2, #IOMD_IOxST]           ; Get current state.
        Debug   term," ST =",r1

        TST     r1, #IOMD_DMA_B_Bit
        ADDEQ   r2, r2, #IOMD_IOxCURA           ; r2 -> active buffer
        ADDNE   r2, r2, #IOMD_IOxCURB
        ADDEQ   r3, r10, #dmar_BuffA            ; r3 -> active buffer info
        ADDNE   r3, r10, #dmar_BuffB
        ADDEQ   r4, r10, #dmar_BuffB            ; r4 -> inactive buffer info
        ADDNE   r4, r10, #dmar_BuffA

        LDR     r8, [r10, #dmar_Flags]

        TST     r1, #IOMD_DMA_I_Bit             ; If in interrupt state then
        MOVNE   r0, r4                          ;   update from inactive buffer.
        BLNE    update

        LDMIA   r3, {r5,r6,r7}                  ; Get active buffer ptp, off, len.
        Debug   term," active ptp,off,len =",r5,r6,r7

        TEQ     r7, #0                          ; If active buffer not programmed then
        LDREQ   r0, [sp]                        ;   must have completed.
        BEQ     %FT60

        TST     r1, #IOMD_DMA_O_Bit             ; If in overrun state then
        MOVNE   r2, r7                          ;   amount done = programmed length
        LDREQ   r2, [r2]                        ; else determine amount actually done
        BICEQ   r2, r2, #7:SHL:29               ;   clear top 3 bits of current address
        LDREQ   lr, [r5, #ptab_Physical]        ;   get start address from page table
        SUBEQ   r2, r2, lr
        SUBEQ   r2, r2, r6                      ;   amount done = current - start address - off
        STREQ   r2, [r3, #buff_Len]             ;   and pretend we programmed the amount actually done.
        Debug   term," active done =",r2

        MOV     r0, r3                          ; Update from the active buffer.
        BL      update

        LDR     r0, [sp]                        ; Get back err (or 0).
        TEQ     r0, #0                          ; If we have an error then
        BNE     %FT60                           ;   terminate not suspend.

        TST     r8, #dmarf_Sync                 ; If doing DMA sync then
        BEQ     %FT20
        BL      DMASync                         ;   do DMASync callbacks that should have happened,
        LDR     lr, [r10, #dmar_SyncGap]
        LDR     r0, [r10, #dmar_Gap]
        SUB     lr, lr, r0                      ;   new ProgGap = SyncGap - Gap.
        Debug   term," ProgGap =",lr
        STR     lr, [r10, #dmar_ProgGap]
20
        SUB     r0, r7, r2                      ; r0 = amount programmed but not transferred
        TST     r1, #IOMD_DMA_I_Bit             ; If not in interrupt state then
        LDREQ   lr, [r4, #buff_Len]             ;   add on inactive length programmed.
        ADDEQ   r0, r0, lr
        Debug   term," not done =",r0
      ]

        LDR     lr, [r10, #dmar_Length]         ; Add amount not done back onto total length.
        ADD     lr, lr, r0
        STR     lr, [r10, #dmar_Length]
        Debug   term," Length =",lr

        TST     r8, #dmarf_Circular             ; If not circular buffer then
        BEQ     %FT50                           ;   set up for resume.

        LDR     lr, [r10, #dmar_BuffLen]
        ADD     lr, lr, r0                      ; BuffLen left += amount not done
        LDR     r0, [r10, #dmar_BuffSize]
40
        CMP     lr, r0
        SUBCS   lr, lr, r0                      ; BuffLen left = BuffLen left mod BuffSize
        BCS     %BT40
        STR     lr, [r10, #dmar_BuffLen]
        Debug   term," BuffLen =",lr
50
      [ HAL ; these bits should really have been done at this later point all along...
        TST     r8, #dmarf_Sync
        BEQ     %FT55
        MOV     lr, #0                          ; Fake up buffer info for the benefit of DMASync.
        STR     lr, [r10, #dmar_CurrBuff + buff_Len]
        STR     lr, [r10, #dmar_NextBuff + buff_Len]
        BL      DMASync                         ;   do DMASync callbacks that should have happened,
        LDR     lr, [r10, #dmar_SyncGap]
        LDR     r0, [r10, #dmar_Gap]
        SUB     lr, lr, r0                      ;   new ProgGap = SyncGap - Gap.
        Debug   term," ProgGap =",lr
        STR     lr, [r10, #dmar_ProgGap]
55
        LDR     r0, [sp]                        ; Get back err (or 0).
        TEQ     r0, #0                          ; If we have an error then
        BNE     %FT60                           ;   terminate not suspend.

        TST     r11, #DMAStatusFlag_Overrun     ; If overrunning
        BEQ     %FT58
        TST     r8, #dmarf_Infinite             ;   and a finite transfer
        LDREQ   lr, [r10, #dmar_Length]
        TEQEQ   lr, #0                          ;   which has finished
        BEQ     %FT60                           ;   then call Completed vector with no error.
58
      ]
        ADD     r6, r6, r2                      ; Resume offset = old offset + active amount done
        MOV     r7, #0                          ; Resume len = 0
      [ HAL
        ADD     lr, r10, #dmar_NextBuff         ; Set up first Buff for resume.
        STR     lr, [r9, #dmaq_LastBuff]
        STMIA   lr, {r5,r6,r7}
        Debug   term," NextBuff =",r5,r6,r7
        STR     r7, [r10, #dmar_CurrBuff + buff_Len] ; Set CurrBuff as not programmed.
      |
        ADD     lr, r10, #dmar_BuffA            ; Set up BuffA for resume.
        STMIA   lr!, {r5,r6,r7}
        Debug   term," BuffA =",r5,r6,r7
        STR     r7, [lr, #buff_Len]             ; Set BuffB as not programmed.
      ]
        BL      DMAReleasePageTable             ; Will not free the table, only mark pages as cacheable (if reading).
        Debug   term," suspended"
        CLRV
        EXIT

60
        Debug   term," already completed"
        ORR     r8, r8, #dmarf_Completed        ; Tell the world it's completed.
        STR     r8, [r10, #dmar_Flags]
        TEQ     r0, #0                          ; If error then
        SETV    NE                              ;   set V.
        LDR     r8, [r10, #dmar_LCB]
      [ HAL
        LDR     r11, [r10, #dmar_R11]           ; Set up r11 value.
        LDR     r12, [r8, #lcb_R12]             ; Set up r12 value.
      ]
        LDR     r3, [r8, #lcb_Vector]           ; Call Completed (r11,r12 already set up).
        MOV     lr, pc
        LDR     pc, [r3, #vector_Completed]
        BL      DMAReleasePageTable             ; Free the page table.
        Debug   term," terminated"
        CLRV
        EXIT

      [ HAL
70      ; Tidy up after a transfer that used a list-type device.
        LDR     r8, [r10, #dmar_Flags]
        BL      PollList                        ; Ensure up-to-date.

        LDR     r0, [r9, #dmaq_DMADevice]
        CallHAL DMAListTransferStatus
        TST     r0, #DMAListTransferStatusFlag_MemoryError :OR: DMAListTransferStatusFlag_DeviceError
        BNE     %FT75                           ; Deal with any hardware errors.

        LDR     r0, [sp]                        ; Get back the error pointer.
        TEQ     r0, #0                          ; If we have an error then
        BNE     %BT60                           ;   terminate not suspend.

        TST     r8, #dmarf_Infinite             ; If a finite transfer
        LDREQ   lr, [r10, #dmar_Length]
        TEQEQ   lr, #0                          ;   which has finished
        BEQ     %BT60                           ;   then call Completed vector with no error.

        BL      DMAReleasePageTable             ; Free the page table.
        Debug   term," suspended"
        CLRV
        EXIT

75      TST     r0, #DMAListTransferStatusFlag_MemoryError
        ADRNEL  r0, ErrorBlock_DMA_MemoryError
        ADREQL  r0, ErrorBlock_DMA_DeviceError
      [ international
        LDR     r12, [sp, #40+Proc_RegOffset]
        BL      MsgTrans_ErrorLookup
      ]
        B       %BT60                           ; Call Completed vector with this error.
      ]

90
        SetPSR  r7
        Debug   term," error, tag changed"
        STR     r0, [sp]
        PullEnv
        DoError

91
        TEQ     r0, #0                          ; Not active so if terminating then
        LDRNE   lr, [r10, #dmar_Flags]          ;   stop it being activated when IRQs reenabled.
        ORRNE   lr, lr, #dmarf_Completed
        STRNE   lr, [r10, #dmar_Flags]

        SetPSR  r7                              ; Restore IRQ status.

        Debug   term," terminating inactive transfer"

        TEQ     r0, #0                          ; If suspending then
        PullEnv EQ                              ;   return error.
        ADREQ   r0, ErrorBlock_DMA_NotActive
        DoError EQ

        SETV
        LDR     r3, [r8, #lcb_Vector]           ; Call Completed call back.
        LDR     r11, [r10, #dmar_R11]
        LDR     r12, [r8, #lcb_R12]
        MOV     lr, pc
        LDR     pc, [r3, #vector_Completed]
        BL      DMAReleasePageTable             ; Free the page table.
        CLRV
        EXIT

        MakeErrorBlock  DMA_NotActive

;-----------------------------------------------------------------------------
; DMACompleted
;       In:     r0  = 0 or ->error block
;             [ HAL
;               bit 0 set => an inactive transfer is being terminated, so don't call Disable routine
;             |
;               this was the only possible cause of an error pointer, so test was for nonzero pointer
;             ]
;               r8  ->logical channel block
;               r9  ->DMA queue
;               r10 ->DMA request block
;
;       The specified DMA request has completed.  The Disable routine
;       is only called if no error is provided (ie. the DMA has completed
;       successfully).
;
DMACompleted
        EntryS  "r1,r2,r11,r12"

        Debug   dma,"DMACompleted",r10

        LDR     r11, [r10, #dmar_R11]           ; Set up r11 value.
        LDR     r12, [r8, #lcb_R12]             ; Set up r12 value.
        SwpPSR  r2, SVC_mode+I_bit, r1          ; Ensure SVC mode, no IRQs for callbacks and freeing page table.
        LDR     r1, [r8, #lcb_Vector]           ; r1->vector of routines
        Push    lr                              ; Save SVC_lr.

      [ HAL
        TST     r0, #1                          ; If transfer was inactive then don't call Disable routine.
      |
        TEQ     r0, #0                          ; If error then
        SETV    NE                              ;   set V flag for Completed routine
      ]
        MOVEQ   lr, pc                          ; else call Disable routine.
        LDREQ   pc, [r1, #vector_Disable]

      [ HAL
        BICS    r0, r0, #1
        SETV    NE                              ; Set V flag for Completed routine.
      ]
        LDR     lr, [r10, #dmar_Flags]
        TST     lr, #dmarf_BeenActive
        MOVNE   lr, pc                          ; Call Completed routine.
        LDRNE   pc, [r1, #vector_Completed]

        LDR     lr, [r10, #dmar_Flags]          ; Mark as completed.
        ORR     lr, lr, #dmarf_Completed
        STR     lr, [r10, #dmar_Flags]

        Pull    lr
        SetPSR  r2

        BL      DMAReleasePageTable             ; Free the page table.

        EXITS

;-----------------------------------------------------------------------------
; DMAPagesUnsafe
;       In:     r2  ->Page table with 3-word entries for each unsafe page
;               r3  = Number of entries in table
;
;       The DMA manager has received Service_PagesUnsafe and calls this
;       code to scan the page tables of all active DMA transfers.  If an
;       unsafe page is found then it is flagged as unsafe and the transfer
;       may be temporarily halted until Service_PagesSafe is received.
;
DMAPagesUnsafe
        Entry   "r0,r1,r8-r11"

        Debug   unsf,"DMAPagesUnsafe",r2,r3

        ASSERT  UnsafePageCount = UnsafePageTable + 4
        ADR     lr, UnsafePageTable             ; Store unsafe page table and count, to be checked
        STMIA   lr, {r2,r3}                     ;   when new transfers are activated.

      [ HAL
        ; Now that UnsafePageTable is set (until PagesSafe),
        ; * no more new bounce buffer transfers (either direction, irrespective of address) will be started
        ; * no more new list-device transfers (either direction, that address the unsafe region) will be started
        ; * any interrupt-driven buffer-device transfers in progress will halt if they hit the unsafe region

        ; Loop with interrupts on until all bounce buffer read transfers have completed
        ; (bounce buffer write transfers aren't a problem after the buffer is filled).
        ; Bounce buffer transfers are implicitly finite, so this is safe to do.
        LDR     r11, CtrlrList
01
        TEQ     r11, #0                         ; If no more channels to scan then
        BEQ     %FT20                           ;   deal with other channel types.
        LDR     r0, [r11, #ctrlr_PhysicalChannels]
        ADD     r9, r11, #ctrlr_DMAQueues - DMAQSize
10
        SUBS    r0, r0, #1
        LDRCC   r11, [r11, #ctrlr_Next]
        BCC     %BT01

        Debug   unsf," channel",r0
        ADD     r9, r9, #DMAQSize               ; Move on to next channel.
        LDR     lr, [r9, #dmaq_BounceBuff + ptab_Logical]
        TEQ     lr, #0                          ; If no bounce buffer then
        BEQ     %BT10                           ;   try next channel.
15      LDR     r10, [r9, #dmaq_Active]         ; Get pointer to active DMA request block.
        TEQ     r10, #0                         ; While transfer is active,
        BNE     %BT15                           ;   keep looping.
        B       %BT10                           ; Try next channel.

20      ; Locate and suspend list-device transfers that use the unsafe region at any point in the transfer.
        ; Ideally, this will eventually be done with interrupts on, in case an external interrupt has to be used
        ; to unblock the device Deactivate call.
        ; Locate and suspend any conventional buffer devices that are currently accessing the unsafe region.
        ; This requires turning interupts off.

        LDR     r11, CtrlrList
        IRQOff  lr, r8
21
        TEQ     r11, #0                         ; If no more channels to scan then
        SetPSR  r8, EQ, c                       ;   restore IRQ disable state and
        EXIT    EQ                              ;   exit.
        LDR     r0, [r11, #ctrlr_PhysicalChannels]
        ADD     r9, r11, #ctrlr_DMAQueues - DMAQSize
30
        SUBS    r0, r0, #1
        LDRCC   r11, [r11, #ctrlr_Next]
        BCC     %BT21
      |
        MOV     r0, #NoPhysicalChannels
        ADR     r9, DMAQueues-DMAQSize          ; Set r9 so that increment below points to first channel.
        IOMDBase r11
        IRQOff  lr, r8
30
        SUBS    r0, r0, #1                      ; If no more channels to scan then
        SetPSR  r8, CC, c                       ;   restore IRQ disable state and
        EXIT    CC                              ;   exit.
      ]

        Debug   unsf," channel",r0
        ADD     r9, r9, #DMAQSize               ; Move on to next channel.
        LDR     r10, [r9, #dmaq_Active]         ; Get pointer to active DMA request block.
        TEQ     r10, #0                         ; If nothing active then
        BEQ     %BT30                           ;   try next channel.
        LDR     r1, [r10, #dmar_Flags]
      [ {FALSE} ; I think this is over-cautious. BJGA 16/1/03
        TST     r1, #dmarf_Completed            ; If completed then
        BNE     %BT30                           ;   try next channel.
      ]
        BL      DMAUnsafeScan
        B       %BT30

;-----------------------------------------------------------------------------
; DMAUnsafeScan
;       In:     r1  = DMA request block flags
;               r2  ->Page table of unsafe pages
;               r3  = Number of entries in page table
;               r9  ->DMA queue
;               r10 ->DMA request block
;               r11 = IOMD base address
;       Out:    r1  = Possibly updated flags
;
;       Scan the page table for the given transfer looking for unsafe
;       pages.  The transfer is halted if transferring using an unsafe page.
;
DMAUnsafeScan
        Entry   "r2-r7"

        Debug   unsf,"DMAUnsafeScan"

        LDR     r4, [r10, #dmar_PageTable]      ; Get our page table pointer.
        LDR     r5, [r10, #dmar_PageCount]      ; Get the number of pages in our table.
        Debug   unsf," page table,count =",r4,r5
        ADD     r4, r4, #ptab_Physical          ; Point to the first physical address in our table.
        LDR     r7, =PAGESIZE-1
20
        LDR     r6, [r4], #PTABSize             ; Get physical address from our table and move on pointer.
        ADD     r2, r2, #ptab_Physical          ; Point to the first physical address in callers table.
30
        LDR     lr, [r2], #PTABSize             ; Get physical address from callers table and move on pointer.
        EOR     lr, lr, r6
        BICS    lr, lr, r7
        SUBNES  r3, r3, #1                      ; If not same address and still pages in callers table then
        BNE     %BT30                           ;   try next address in callers table.
        TEQ     lr, #0
        BLEQ    DMAHalt                         ; Mark page as unsafe, and halt transfer if necessary.

        SUBS    r5, r5, #1                      ; If more pages in our table then
        LDMNEIA sp, {r2,r3}                     ;   restore pointer to callers table and callers page count
        BNE     %BT20                           ;   try next address in our table
        EXIT                                    ; else exit.

;-----------------------------------------------------------------------------
; DMAHalt
;       In:     r1  = DMA request block flags
;               r4  = pointer to page table entry + PTABSize+ptab_Physical
;               r9  ->DMA queue
;               r10 ->DMA request block
;               r11 = IOMD base address
;       Out:    r1  = possibly updated flags
;
;       Determine if the given unsafe page is being used by the active
;       transfer and if it is then halt the transfer.
;
DMAHalt
      [ HAL
        Entry   "r0,r2-r3,r8"

        LDR     lr, [r4, #ptab_Len-(PTABSize+ptab_Physical)]    ; If same address then
        ORR     lr, lr, #ptabf_Unsafe                           ;   mark page as unsafe
        STR     lr, [r4, #ptab_Len-(PTABSize+ptab_Physical)]

        TST     r1, #dmarf_Halted               ; If already halted then
        EXIT    NE                              ;   nothing to do.

        Debug   unsf,"DMAHalt",r10

        LDR     lr, [r9, #dmaq_DescBlockLogical]
        TEQ     lr, #0
        BNE     %FT10                           ; If we won't be able to halt the transfer from the interrupt routine,
                                                ;   then any unsafe page in the list must cause a halt.

        LDR     r0, [r9, #dmaq_DMADevice]       ; r0 = HAL device for this channel
        CallHAL DMAStatus                       ; Get current state.

        TST     r0, #DMAStatusFlag_Overrun      ; If in overrun state then
        LDRNE   r1, [r10, #dmar_Flags]          ;   not active so leave to interrupt routine.
        EXIT    NE

        LDR     lr, [r10, #dmar_CurrBuff+buff_Ptp] ; Load current buffer page table pointer.
        ADD     lr, lr, #PTABSize + ptab_Physical
        TEQ     r4, lr                          ; If current on unsafe page then
        BEQ     %FT10                           ;   halt transfer.

        LDR     lr, [r10, #dmar_NextBuff+buff_Len]
        TEQ     lr, #0
        EXIT    EQ                              ; Nothing to do if next buffer has not been programmed.
        LDR     lr, [r10, #dmar_NextBuff+buff_Ptp] ; Load next buffer page table pointer.
        ADD     lr, lr, #PTABSize + ptab_Physical
        TEQ     r4, lr                          ; If next not on unsafe page then
        EXIT    NE                              ;   nothing to do.
10
        MOV     r0, #0
        LDR     r8, [r10, #dmar_LCB]
        BL      DMATerminate                    ; We now behave exactly as for a SuspendTransfer call (including callbacks).
        ; should not return V set since magic word and active checks should not fail!

        LDR     r1, [r10, #dmar_Flags]
        ORR     r1, r1, #dmarf_Halted           ; Mark as halted.
        STR     r1, [r10, #dmar_Flags]
        TST     r1, #dmarf_Completed            ; If completed anyway then
        BLNE    DMAUnlinkRequest                ;   free block,
        BLNE    DMAFreeRequestBlock
        BNE     %FT10                           ;   and unblock physical channel.

        LDR     r0, [r8, #lcb_Flags]
        TST     r0, #lcbf_Blocked               ; If logical channel is not blocked already then
        ORREQ   r0, r0, #lcbf_Blocked           ;   block it.
        STREQ   r0, [r8, #lcb_Flags]
10
        BL      DMASearchQueue                  ; Try to start another request (unblock physical channel).

        EXIT
      |
        Entry   "r0,r2,r3"

        LDREQ   lr, [r4, #ptab_Len-(PTABSize+ptab_Physical)]    ; If same address then
        ORREQ   lr, lr, #ptabf_Unsafe                           ;   mark page as unsafe
        STREQ   lr, [r4, #ptab_Len-(PTABSize+ptab_Physical)]

        TST     r1, #dmarf_Halted               ; If already halted then
        EXIT    NE                              ;   nothing to do.

        Debug   unsf,"DMAHalt",r10

        LDR     r0, [r10, #dmar_Tag]
        AND     r0, r0, #dmar_PhysBits          ; r0=physical channel number
        DMARegBlk r3, r0                        ; r3->IOMD DMA register set

        LDRB    r2, [r3, #IOMD_IOxST]           ; Get current state.
        Debug   unsf," ST =",r2
        TST     r2, #IOMD_DMA_O_Bit             ; If in overrun state then
        EXIT    NE                              ;   not active so leave to interrupt routine.

        TST     r2, #IOMD_DMA_B_Bit             ; Load active buffer page table pointer.
        LDREQ   lr, [r10, #dmar_BuffA+buff_Ptp]
        LDRNE   lr, [r10, #dmar_BuffB+buff_Ptp]
        ADD     lr, lr, #PTABSize + ptab_Physical
        Debug   unsf," test",r4,lr
        TEQ     r4, lr                          ; If active on unsafe page then
        BEQ     %FT10                           ;   halt transfer.

        TST     r2, #IOMD_DMA_I_Bit             ; If in interrupt state then
        EXIT    NE                              ;   inactive has completed or is not programmed.

        TST     r2, #IOMD_DMA_B_Bit             ; Load inactive buffer page table pointer.
        LDREQ   lr, [r10, #dmar_BuffB+buff_Ptp]
        LDRNE   lr, [r10, #dmar_BuffA+buff_Ptp]
        ADD     lr, lr, #PTABSize + ptab_Physical
        TEQ     r4, lr                          ; If inactive not on unsafe page then
        EXIT    NE                              ;   nothing to do.
10
        Debug   unsf," halting transfer"
        LDRB    lr, [r3, #IOMD_IOxCR]           ; Disable DMA state machine.
        BIC     lr, lr, #IOMD_DMA_E_Bit
        STRB    lr, [r3, #IOMD_IOxCR]
        LDRB    lr, [r11, #IOMD_DMAMSK]         ; Disable channel interrupt.
        MOV     r3, #1
        BIC     lr, lr, r3, LSL r0
        STRB    lr, [r11, #IOMD_DMAMSK]
        ORR     r1, r1, #dmarf_Halted           ; Flag transfer as halted.
        STR     r1, [r10, #dmar_Flags]

        EXIT
      ]

;-----------------------------------------------------------------------------
; DMAPagesSafe
;       In:     r2  = Number of entries in tables
;               r3  ->Page table with 3-word entries for old pages
;               r4  ->Page table with 3-word entries for new pages
;
;       The DMA manager has received Service_PagesSafe and calls this code
;       to scan the page tables of all active DMA transfers.  If a page
;       flagged as unsafe is now safe then the flag is removed and the
;       transfer may be continued if it had been halted by DMAPagesUnsafe.
;
DMAPagesSafe
      [ HAL
        Entry   "r2-r12", 4
      |
        Entry   "r2-r12"
      ]

        Debug   safe,"DMAPagesSafe"

        MOV     lr, #0                          ; Pages are now safe so
        STR     lr, UnsafePageTable             ;   allow new transfers to start up unchecked.

        LDR     r8, =PAGESIZE-1
      [ HAL
        LDR     r11, CtrlrList
01
        TEQ     r11, #0                         ; If no more channels to scan then
        EXIT    EQ                              ;   exit.
        STR     r11, [sp]
        LDR     r7, [r11, #ctrlr_PhysicalChannels]
        ADD     r9, r11, #ctrlr_DMAQueues - DMAQSize
10
        SUBS    r7, r7, #1
        LDRCC   r11, [sp]
        LDRCC   r11, [r11, #ctrlr_Next]
        BCC     %BT01
      |
        MOV     r7, #NoPhysicalChannels
        ADR     r9, DMAQueues-DMAQSize
10
        SUBS    r7, r7, #1                      ; If no more channels to scan then
        EXIT    CC                              ;   exit.
      ]

        ADD     r9, r9, #DMAQSize               ; Move on to next channel.
      [ HAL
        ; HAL has quite different requirements here: PagesUnsafe blocks the logical channel, not the physical channel, and so
        ; (a) the active transfer (if any) certainly wasn't unsafe, and (b) there may be many halted transfers in the queue.
        ADD     r10, r9, #dmaq_Head - dmar_Next
15      LDR     r10, [r10, #dmar_Next]          ; Get next request block for this physical channel.
        TEQ     r10, #0
        BEQ     %BT10
        LDR     lr, [r10, #dmar_Flags]
        TST     lr, #dmarf_Halted               ; If not halted then
        BEQ     %BT15                           ;   try next request block.
      |
        LDR     r10, [r9, #dmaq_Active]         ; Get pointer to active DMA request block.
        Debug   safe," transfer =",r10
        TEQ     r10, #0                         ; If nothing active then
        BEQ     %BT10                           ;   try next channel.
        LDR     lr, [r10, #dmar_Flags]
        Debug   safe," flags =",lr
        TST     lr, #dmarf_Completed            ; If completed then
        BNE     %BT10                           ;   try next channel.
        TST     lr, #dmarf_Halted               ; If not halted then
        BEQ     %BT10                           ;   try next channel.
      ]

        ASSERT  ptab_Len = 0
        LDR     r5, [r10, #dmar_PageTable]      ; Get our page table pointer
        LDR     r6, [r10, #dmar_PageCount]      ; Get the number of pages in our table.
        Debug   safe," scanning table,len =",r5,r6
20
        SUBS    r6, r6, #1                      ; If no more pages in our table then
      [ HAL
        LDRCC   r12, [sp, #40+Proc_RegOffset]
      ]
        BLCC    DMAContinue                     ;   get DMA going again if possible
      [ HAL
        BCC     %BT15                           ;   and try next request block.
      |
        BCC     %BT10                           ;   and try next channel.
      ]
        LDR     r11, [r5], #PTABSize            ; Get page table entry length and move on pointer.
        TST     r11, #ptabf_Unsafe              ; If this page is not unsafe then
        BEQ     %BT20                           ;   try next page.
        LDR     r12, [r5, #ptab_Physical-PTABSize]      ; Get physical address of our unsafe page.

        ADD     r3, r3, #ptab_Physical          ; Point to the first physical address in callers old table.
30
        LDR     lr, [r3], #PTABSize             ; Get physical address from callers old table.
        EOR     lr, lr, r12
        BICS    lr, lr, r8
        LDREQ   lr, [r4, #ptab_Physical]                ; If same address then get new physical address from callers new table
        ANDEQ   r12, r12, r8
        ORREQ   lr, lr, r12                             ;   or in the offset within the page
        STREQ   lr, [r5, #ptab_Physical-PTABSize]       ;   replace the old address in our table with the new address
        BICEQ   r11, r11, #ptabf_Unsafe                 ;   and mark page as safe.
        STREQ   r11, [r5, #ptab_Len-PTABSize]
        SUBNES  r2, r2, #1                      ; If not same address and still pages in callers table then
        ADDNE   r4, r4, #PTABSize               ;   move on new table pointer
        BNE     %BT30                           ;   and try next address in callers table.

      [ HAL
        ASSERT  Proc_RegOffset = 4
        LDMIB   sp, {r2-r4}                     ; Restore pointers to callers tables and callers page count.
      |
        LDMIA   sp, {r2-r4}                     ; Restore pointers to callers tables and callers page count.
      ]
        B       %BT20                           ; Try next page in our table.

;-----------------------------------------------------------------------------
; DMAContinue
;       In:     r8  = PAGESIZE-1
;               r9  ->DMA queue
;               r10 ->DMA request block
;
;       If the unsafe pages which caused a transfer to be halted are now
;       safe then the transfer is continued.
;
DMAContinue
      [ HAL
        EntryS  "r0,r8"

        Debug   safe,"DMAContinue",r10

        IRQOff  lr

        LDR     lr, [r10, #dmar_Flags]          ; Remove halted flag.
        BIC     lr, lr, #dmarf_Halted
        STR     lr, [r10, #dmar_Flags]

        LDR     r8, [r10, #dmar_LCB]
        TST     lr, #dmarf_Blocking             ; If this transfer was blocking the logical channel anyway
        BNE     %FT10                           ;   then can't restart this logical channel; leave logical channel blocked.

        LDR     r0, [r8, #lcb_Flags]
        BIC     r0, r0, #lcbf_Blocked           ; Else unblock logical channel.
        STR     r0, [r8, #lcb_Flags]

        LDR     lr, [r9, #dmaq_Active]
        TEQ     lr, #0
        BNE     %FT10                           ; Can't restart anything if physical channel is already in use.

        TST     lr, #dmarf_Suspended :OR: dmarf_Completed
        BNE     %FT05                           ; Can't restart this transfer if it's been suspended in the meantime.

        BL      DMAForceActivate
        EXITS   VC, cf                          ; Exit if started successfully.

        BL      DMAUnlinkRequest                ; If Start callback returned error then
        BL      DMAFreeRequestBlock             ;   free block.
05      BL      DMASearchQueue                  ;   and look for something else to do.
10
        EXITS   , cf
      |
        EntryS  "r0-r2,r11"

        Debug   safe,"DMAContinue",r10

        LDR     r0, [r10, #dmar_Tag]
        AND     r0, r0, #dmar_PhysBits          ; r0=physical channel number
        IOMDBase r11
        DMARegBlk r1, r0                        ; r1->IOMD DMA register set

        LDR     lr, [r10, #dmar_BuffA+buff_Len]
        TEQ     lr, #0                          ; If BuffA is not programmed then
        BEQ     %FT10                           ;   skip check.

        Debug   safe," reprogramming A"
        LDR     r2, [r10, #dmar_BuffA+buff_Ptp]
        LDR     lr, [r2, #ptab_Len]
        TST     lr, #ptabf_Unsafe               ; If the page is still unsafe then
        EXITS   NE                              ;   cannot continue transfer.
        LDR     lr, [r1, #IOMD_IOxCURA]         ; Get address currently programmed.
        AND     lr, lr, r8                      ; Only want the offset
        LDR     r2, [r2, #ptab_Physical]        ; Get the new address.
        BIC     r2, r2, r8                      ; Don't want the offset.
        ORR     lr, lr, r2                      ; Combine into continuation address.
        STR     lr, [r1, #IOMD_IOxCURA]         ; Reprogram IOMD.
        Debug   safe," with",lr
10
        LDR     lr, [r10, #dmar_BuffB+buff_Len]
        TEQ     lr, #0                          ; If BuffB is not programmed then
        BEQ     %FT20                           ;   skip check.

        Debug   safe," reprogramming B"
        LDR     r2, [r10, #dmar_BuffB+buff_Ptp]
        LDR     lr, [r2, #ptab_Len]
        TST     lr, #ptabf_Unsafe               ; If the page is still unsafe then
        EXITS   NE                              ;   cannot continue transfer.
        LDR     lr, [r1, #IOMD_IOxCURB]         ; Get address currently programmed.
        AND     lr, lr, r8                      ; Only want the offset
        LDR     r2, [r2, #ptab_Physical]        ; Get the new address.
        BIC     r2, r2, r8                      ; Don't want the offset.
        ORR     lr, lr, r2                      ; Combine into continuation address.
        STR     lr, [r1, #IOMD_IOxCURB]         ; Reprogram IOMD.
        Debug   safe," with",lr
20
        Debug   safe," restarting transfer"
        IRQOff  lr

        LDRB    lr, [r1, #IOMD_IOxCR]           ; Enable DMA state machine.
        ORR     lr, lr, #IOMD_DMA_E_Bit
        STRB    lr, [r1, #IOMD_IOxCR]
        LDRB    lr, [r11, #IOMD_DMAMSK]         ; Enable channel interrupt.
        MOV     r1, #1
        ORR     lr, lr, r1, LSL r0
        STRB    lr, [r11, #IOMD_DMAMSK]
        LDR     lr, [r10, #dmar_Flags]          ; Remove halted flag.
        BIC     lr, lr, #dmarf_Halted
        STR     lr, [r10, #dmar_Flags]

        EXITS   , cf
      ]

;-----------------------------------------------------------------------------
; DMASearchQueue
;       In:     r9  ->DMA queue
;               r11 = IOMD base address
;
;       Search queue for a DMA request which can be activated.  It is assumed
;       that a completed or terminated request is blocking the physical channel
;       so DMAForceActivate is called to start a new request.  IRQs are disabled
;       during this call because requests in the queue have tags in the outside
;       world and can be terminated/altered under interrupt.  We don't want the
;       queue to change or a request to be deleted in the middle of setting it up!
;
DMASearchQueue
        EntryS  "r7,r8,r10"

        Debug   dma,"DMASearchQueue",r9

        IRQOff  lr

        LDR     r7, [r9, #dmaq_Head]
15
        TEQ     r7, #0                          ; If end of queue then
        STREQ   r7, [r9, #dmaq_Active]          ;   no active DMA and return.
        EXITS   EQ, cf

        MOV     r10, r7
        LDR     r7, [r10, #dmar_Next]           ; Get next in case we need it later.

        LDR     lr, [r10, #dmar_Flags]
        TST     lr, #dmarf_Suspended + dmarf_Completed  ; If suspended or completed then
        BNE     %BT15                                   ;   try next.

        LDR     r8, [r10, #dmar_LCB]            ; r8->logical channel block
        LDR     lr, [r8, #lcb_Flags]
        TST     lr, #lcbf_Blocked               ; If logical channel is blocked then
        BNE     %BT15                           ;   try next.

        CLRV
        BL      DMAForceActivate
        EXITS   VC, cf                          ; Exit if started successfully.

        BL      DMAUnlinkRequest                ; If Start callback returned error then
        BL      DMAFreeRequestBlock             ;   free block
        B       %BT15                           ;   and try next.

;-----------------------------------------------------------------------------
; DMAPurge
;       In:     r7 <> 0 => don't try to start transfers on unblocked channels
;               r8  ->logical channel block
;       Out:    all registers preserved
;
;       Purge all DMA requests for the channel specified.  If the active DMA
;       on the appropriate physical channel is for this channel then it is
;       terminated.
;
DMAPurge
        EntryS  "r0-r2,r9-r11"

        Debug   purge,"DMAPurge",r8

        ADR     r0, ErrorBlock_DMA_Deregistered ; r0->deregistered error
      [ international
        BL      MsgTrans_ErrorLookup
      ]
      [ HAL
        ORR     r0, r0, #1                      ; Flag to DMACompleted not to do Disable callbacks.
      ]
        IRQOff  lr                              ; Stop interrupts messing around with queues.
        MOV     r2, #0

        LDR     r9, [r8, #lcb_Queue]            ; r9->DMA queue
        Debug   purge," queue = ",r9
        LDR     r10, [r9, #dmaq_Head]           ; Purge DMA queue.
20
        Debug   purge," DMA = ",r10
        TEQ     r10, #0                         ; If end of queue then stop.
        BEQ     %FT30

        LDR     r1, [r10, #dmar_Next]

        LDR     lr, [r10, #dmar_LCB]
        TEQ     lr, r8                          ; If different channel then
        MOVNE   r10, r1                         ;   skip to next.
        BNE     %BT20

        LDR     lr, [r9, #dmaq_Active]
        TEQ     lr, r10                         ; If this one is active then
        MOVEQ   r2, r10                         ;   remember for later
        BLNE    DMACompleted                    ; else just complete.
        BLNE    DMAUnlinkRequest
        BLNE    DMAFreeRequestBlock

        TEQ     r1, #0
        MOVNE   r10, r1                         ; Test next request block.
        BNE     %BT20
30
        TEQ     r2, #0                          ; If nothing to terminate then
        EXITS   EQ, cf                          ;   exit.

        MOV     r10, r2
      [ :LNOT: HAL
        IOMDBase r11
        LDR     r1, [r10, #dmar_Tag]
      ]
        BL      DMATerminate
        BL      DMAUnlinkRequest
        BL      DMAFreeRequestBlock
        TEQ     r7, #0
        BLEQ    DMASearchQueue
        EXITS   , cf

        MakeErrorBlock  DMA_Deregistered

;-----------------------------------------------------------------------------
; DMAActiveDone
;       In:     r8 -> logical channel block
;               r9  -> DMA queue
;               r10 -> DMA request block
;       Out     r0 = amount done (above the amount held in dmar_Done on entry)
;             [ HAL
;                r8 corrupted
;             ]
;
;       Return the amount of the active buffer which has been transferred.
;
DMAActiveDone
      [ HAL
        Entry   "r1-r5,r8,r11"

        Debug   dma,"DMAActiveDone",r10

        LDR     lr, [r9, #dmaq_DescBlockLogical]
        TEQ     lr, #0
        BNE     %FT50                           ; Use alternate code for list-type devices.

        LDR     r11, [r9, #dmaq_DMADevice]
        MOV     r0, r11
        CallHAL DMAStatus                       ; Read interrupt/overrun state.
        MOV     r4, r0
10
        MOV     r0, r11
        CallHAL DMATransferState                ; Read progress of current buffer.
        MOV     r5, r0

        MOV     r0, r11
        CallHAL DMAStatus                       ; Read interrupt/overrun state again.

        BICS    lr, r0, r4                      ; If state changed, we don't know which buffer we just sampled, so try again.
        MOVNE   r4, r0
        BNE     %BT10

        LDR     lr, [r10, #dmar_Queue]
        LDR     lr, [lr, #dmaq_LastBuff]
        SUB     r0, lr, r10
        EOR     r0, r0, #dmar_CurrBuff :EOR: dmar_NextBuff
        ADD     r0, r0, r10
        TST     r4, #DMAStatusFlag_NoUnstarted :OR: DMAStatusFlag_Overrun
        MOVEQ   lr, r0                          ; If double-buffered and not interrupting, then last-programmed has yet to
        MOVEQ   r0, #0                          ;   start transferring and we're only interested in progress of other buffer.
        LDRNE   r0, [r0, #buff_Len]             ; Otherwise, last-programmed is active or completed (depending on overrun)
                                                ;   but the other buffer is definitely completed.
        TST     r4, #DMAStatusFlag_Overrun
        LDRNE   r1, [lr, #buff_Len]             ; If in overrun, then last-programmed is completed.
        LDMEQIA lr, {r1,r2}                     ; Otherwise calculate progress of active buffer.
        LDREQ   lr, [r1, #ptab_Physical]
        ADDEQ   lr, lr, r2
        SUBEQ   r1, r5, lr

        ADD     r0, r0, r1

        LDR     lr, [r10, #dmar_Flags]
        EOR     lr, lr, #dmarf_Direction :OR: dmarf_Completed
        TST     lr, #dmarf_Direction            ; If a read operation
        TSTNE   lr, #dmarf_BeenActive           ;   and we've been active
        TSTNE   lr, #dmarf_Completed            ;   but not yet finished (and trashed the scatter list)
        LDRNE   lr, [r9, #dmaq_BounceBuff + ptab_Logical]
        TEQNE   lr, #0                          ;   and there's a bounce buffer for this physical channel, then we should ensure
        BLNE    CopyFromBounceBuffer            ;   that the scatter list contents reflect the amount we're saying is done!
        EXIT

50      LDR     r4, [r10, #dmar_Done]           ; What does caller think has already been transferred?
        LDR     r8, [r10, #dmar_Flags]

        BL      PollList                        ; Ensure up-to-date.

        LDR     r0, [r9, #dmaq_DMADevice]
        CallHAL DMAListTransferStatus

        TST     r0, #DMAListTransferStatusFlag_MemoryError :OR: DMAListTransferStatusFlag_DeviceError
        LDREQ   lr, [r10, #dmar_Done]
        SUBEQ   r0, lr, r4                      ; Return the difference.
        EXIT    EQ

        TST     r0, #DMAListTransferStatusFlag_MemoryError
        PullEnv
        ADRNE   r0, ErrorBlock_DMA_MemoryError  ; Or return error.
        ADREQ   r0, ErrorBlock_DMA_DeviceError
        DoError

      |
        Entry   "r1-r4,r11"

        Debug   dma,"DMAActiveDone",r10

        LDR     lr, [r8, #lcb_Physical]
        IOMDBase r11
        DMARegBlk r0, lr                        ; r0 -> DMA register block

        LDRB    lr, [r0, #IOMD_IOxST]           ; Get current state.
        TST     lr, #IOMD_DMA_B_Bit
        ADDEQ   r1, r10, #dmar_BuffA            ; r1 -> active buffer info
        ADDNE   r1, r10, #dmar_BuffB
        LDREQ   r4, [r10, #dmar_BuffB + buff_Len]       ; r4 = inactive buffer len
        LDRNE   r4, [r10, #dmar_BuffA + buff_Len]
        ADDEQ   r0, r0, #IOMD_IOxCURA           ; r0 -> active buffer
        ADDNE   r0, r0, #IOMD_IOxCURB

        LDMIA   r1, {r1-r3}                     ; Get active buffer ptp, off, len.

        TST     lr, #IOMD_DMA_O_Bit             ; If in overrun then both have completed so
        ADDNE   r0, r3, r4                      ;   return active len + inactive len.
        EXIT    NE

        LDR     r0, [r0]                        ; Get active buffer current.
        BIC     r0, r0, #7:SHL:29               ; Only want bits 0-28.
        LDR     r1, [r1, #ptab_Physical]        ; Get start address.
        SUB     r0, r0, r1                      ; Amount done = current - start - off
        SUB     r0, r0, r2

        TST     lr, #IOMD_DMA_I_Bit             ; If in interrupt state then inactive completed so
        ADDNE   r0, r0, r4                      ;   amount done += inactive len.
        EXIT
      ]

;-----------------------------------------------------------------------------
; DMASync
;       In:     r8 = DMA request flags
;               r9 -> DMA queue
;               r10 -> DMA request block
;       Out:    All registers preserved (except r8, if sync routine told us to stop)
;
;       Do any pending DMASync callbacks.
;
DMASync
        Entry   "r0-r3,r11,r12"

        Debug   int,"DMASync",r10

        LDR     r1, [r10, #dmar_Gap]
        LDR     r2, [r10, #dmar_SyncGap]
        CMP     r1, r2                          ; If Gap done < SyncGap then
        EXIT    CC                              ;   no callbacks to do.

        Debug   int," gap,syncgap =",r1,r2
        DebugTab r0,r3,#&31,r1,r2

        LDR     r0, [r10, #dmar_LCB]            ; r0 -> logical channel block
        LDR     r3, [r0, #lcb_Vector]           ; r3 -> vector of callback routines
        LDR     r11, [r10, #dmar_R11]           ; Get r11 value.
        LDR     r12, [r0, #lcb_R12]             ; Get r12 value.
10
        MOV     lr, pc                          ; Call DMASync routine.
        LDR     pc, [r3, #vector_DMASync]

        SUB     r1, r1, r2                      ; Gap remaining
        TEQ     r0, #0
        BNE     %FT20

        CMP     r1, r2
        BCS     %BT10

        STR     r1, [r10, #dmar_Gap]
        EXIT
20
        STR     r1, [r10, #dmar_Gap]

        SUBS    r0, r0, r1                      ; Subtract bit of next gap already done (if any).
      [ HAL
        LDRCS   lr, [r10, #dmar_CurrBuff+buff_Len] ; If still more to do then
      |
        LDRCS   lr, [r10, #dmar_BuffA+buff_Len] ; If still more to do then
      ]
        SUBCSS  r0, r0, lr                      ;   subtract amount programmed in BuffA (if any).
      [ HAL
        LDRCS   lr, [r10, #dmar_NextBuff+buff_Len] ; If still more to do then
      |
        LDRCS   lr, [r10, #dmar_BuffB+buff_Len] ; If still more to do then
      ]
        SUBCSS  r0, r0, lr                      ;   subtract amount programmed in BuffB (if any).
        LDRLS   r0, [r10, #dmar_LCB]            ; Unfortunately, we need something more to program as the last
        LDRLS   r0, [r0, #lcb_Flags]            ;   buffer to complete must have the Stop bit set in the end register
        ANDLS   r0, r0, #lcbf_TransferSize      ;   so if we've gone bust then just set length to the transfer unit size, not 0.

        TST     r8, #dmarf_Infinite
        STRNE   r0, [r10, #dmar_Length]         ; If this was an infinite length transfer then set new length,
        BNE     %FT30                           ;   update flags and exit.
        LDR     lr, [r10, #dmar_Length]
        CMP     r0, lr                          ; If we're being asked to do less than we've got left then
        STRCC   r0, [r10, #dmar_Length]         ;   set new length.
30
        BIC     r8, r8, #dmarf_Infinite :OR: dmarf_Sync
        STR     r8, [r10, #dmar_Flags]          ; No longer infinite and don't do any more sync callbacks.

        EXIT

 [ HAL

;-----------------------------------------------------------------------------
; PollList
;       In:     r8  = DMA request flags
;               r9 -> DMA queue
;               r10-> DMA request block
;       Out:    r0-r3 corrupt
;
;       Regular maintenance of state for list-type devices.
;
PollList
        Entry   "r4"

        LDR     r0, [r9, #dmaq_DMADevice]
        CallHAL DMAListTransferProgress         ; r0 = amount transferred since initiation

        LDR     lr, [r10, #dmar_DoneAtStart]
        ADD     r0, lr, r0                      ; r0 = total amount done for this request so far
        LDR     r1, [r10, #dmar_Done]
        SUBS    r4, r0, r1                      ; r4 = amount done since last time we looked
        EXIT    EQ                              ; Exit now if nothing done.

        STR     r0, [r10, #dmar_Done]           ; Update dmar_Done.
        TST     r8, #dmarf_Infinite
        LDREQ   lr, [r10, #dmar_Length]
        SUBEQ   lr, lr, r4
        STREQ   lr, [r10, #dmar_Length]         ; Update dmar_Length unless infinite.

        TST     r8, #dmarf_Circular :OR: dmarf_DontUpdate ; If circular, or so requested, then
        BNE     %FT30                           ;   don't update the scatter list.

        LDR     lr, [r10, #dmar_ScatterList]
        MOV     r2, r4
10
        LDMIA   lr, {r0,r1}                     ; Get scatter list addr,len.
        CMP     r0, #ScatterListThresh
        TEQHS   r1, #0
        ADDEQ   lr, lr, r0
        STREQ   lr, [r10, #dmar_ScatterList]
        BEQ     %BT10                           ; Restart if looped scatter list.
        TEQ     r1, #0                          ; If zero length entry then
        ADDEQ   lr, lr, #8                      ;   move on to next section.
        STREQ   lr, [r10, #dmar_ScatterList]
        BEQ     %BT10

        CMP     r2, r1
        MOVHI   r3, r1
        MOVLS   r3, r2                          ; r3 = amount to update this scatter entry by
        ADD     r0, r0, r3
        SUB     r1, r1, r3
        STMIA   lr, {r0,r1}
        EXIT    LS                              ; Do we need to update the next scatter entry too?
        SUB     r2, r2, r3
        ADD     lr, lr, #8
        STR     lr, [r10, #dmar_ScatterList]
        B       %BT10

30      TST     r8, #dmarf_Sync                 ; Are sync callbacks required?
        EXIT    EQ                              ; Exit if not.

        Push    "r11,r12"
        LDR     r1, [r10, #dmar_Gap]
        LDR     r2, [r10, #dmar_SyncGap]
        ADD     r1, r4, r1
        CMP     r1, r2
        BLO     %FT50

        LDR     r0, [r10, #dmar_LCB]            ; r0 -> logical channel block
        LDR     r3, [r0, #lcb_Vector]           ; r3 -> vector of callback routines
        LDR     r11, [r10, #dmar_R11]           ; Get r11 value.
        LDR     r12, [r0, #lcb_R12]             ; Get r12 value.

40      MOV     lr, pc                          ; Call DMASync routine.
        LDR     pc, [r3, #vector_DMASync]

        TEQ     r0, #0                          ; Terminate early?
        BNE     %FT80                           ; Yes, so branch.

        SUB     r1, r1, r2
        CMP     r1, r2
        BHS     %BT40

        STR     r1, [r10, #dmar_Gap]
50
        Pull    "r11,r12"
        EXIT

80      ; DMASync callback requested early termination.
        MOV     r1, r0
        LDR     r0, [r9, #dmaq_DMADevice]
        CallHAL DMACurtailListTransfer

        LDR     lr, [r10, #dmar_Done]
        BIC     r8, r8, #dmarf_Infinite :OR: dmarf_Sync
        STR     r8, [r10, #dmar_Flags]          ; No longer infinite, and don't do any more sync callbacks.
        SUB     lr, r0, lr
        STR     lr, [r10, #dmar_Length]         ; Total - done = amount remaining.
        Pull    "r11,r12"
        EXIT

;-----------------------------------------------------------------------------
; DMAInterruptList
;       In:     Privileged mode, IRQs disabled
;               r0 = DMA queue
;               r12 -> module workspace
;               [r13] = return address
;       Out:    r0-r3,r12 may be corrupted
;
;       Common list-type DMA interrupt handler.
;
DMAInterruptList
        Push    "r4-r11"                        ; Push the same registers that finished pulls. Return address already on stack.

        Debug   int,"DMAInterruptList"

        MOV     r9, r0                          ; r9->DMA queue
        LDR     r10, [r9, #dmaq_Active]         ; r10->active DMA request

        Debug   int," request",r10

        LDR     r8, [r10, #dmar_Flags]          ; r8 = DMA request flags
        LDR     r11, [r9, #dmaq_DMADevice]      ; r11->HAL device

        BL      PollList                        ; Update state.

        MOV     r0, r11
        CallHAL DMAListTransferStatus
        TST     r0, #DMAListTransferStatusFlag_MemoryError :OR: DMAListTransferStatusFlag_DeviceError
        BNE     %FT90

        TST     r8, #dmarf_Infinite             ; If a finite transfer
        LDREQ   lr, [r10, #dmar_Length]
        TEQEQ   lr, #0                          ;   which has finished
        Push    "r12", EQ
        BEQ     finished_altentry               ;   then move on to next queued transfer.

        Pull    "r4-r11,pc"

90      TST     r0, #DMAListTransferStatusFlag_MemoryError
        ADRNE   r0, ErrorBlock_DMA_MemoryError
        ADREQ   r0, ErrorBlock_DMA_DeviceError
      [ international
        BL      MsgTrans_ErrorLookup
      ]
        MOV     r4, r0
        Push    "r12"
        B       finished_witherror

        MakeErrorBlock  DMA_MemoryError
        MakeErrorBlock  DMA_DeviceError

;-----------------------------------------------------------------------------
; DMAInterruptCommon
;       In:     Privileged mode, IRQs disabled
;               r0 = DMA queue
;               r12 -> module workspace
;               [r13] = return address
;       Out:    r0-r3,r12 may be corrupted
;
;       Common buffer-type DMA interrupt handler.
;
DMAInterruptCommon
        Push    "r4-r11"

        Debug   int,"DMAInterrupt"

        MOV     r9, r0                          ; r9->DMA queue
        LDR     r10, [r9, #dmaq_Active]         ; r10->active DMA request

        Debug   int," request",r10

        LDR     r8, [r10, #dmar_Flags]          ; r8 = DMA request flags
        LDR     r11, [r9, #dmaq_DMADevice]      ; r11->HAL device

        Push    "r12"                           ; corrupted by HAL calls

testloop
        MOV     r0, r11
        CallHAL DMAStatus
        AND     r1, r0, #DMAStatusFlag_Overrun :OR: DMAStatusFlag_EarlyOverrun
        ASSERT  DMAStatusFlag_Overrun = 2
        ASSERT  DMAStatusFlag_EarlyOverrun = 4
        TST     r8, #dmarf_Infinite             ; If finite transfer
        LDR     r4, [r10, #dmar_Length]         ;   (this needs to be unconditional - non-HAL code is broken!)
        TEQEQ   r4, #0                          ;   and length = 0
        ORREQ   r1, r1, #1                      ;   then take alternate action.
        ADD     pc, pc, r1, LSL #2
        DCD     0
        B       nooverrun                       ; No overrun, more to program
        B       nooverrun_finished              ; No overrun, no more to program
        B       overrun                         ; Overrun, more to program
        B       overrun_finished                ; Overrun, no more to program
        DCD     0
        DCD     0
        B       earlyoverrun                    ; Early overrun, more to program
        B       finished                        ; Early overrun, no more to program

nooverrun_finished
        ADD     r3, r10, #dmar_CurrBuff
        LDR     r5, [r9, #dmaq_LastBuff]
        TEQ     r5, r3
        ADD     r5, r10, #dmar_NextBuff
        BEQ     %FT01                           ; If last time we programmed current transfer, then just set up next transfer.
        MOV     r0, r3
        BL      update                          ; Update from old (now completed) current buffer.
        LDMIA   r5, {r0-r2}
        STMIA   r3, {r0-r2}                     ; Copy next to current to reflect what's happened in the hardware.
01      MOV     r0, #0
        STR     r0, [r5, #buff_Len]             ; Mark next buffer as not programmed.
        MOV     r0, r11
        CallHAL DMAIRQClear
        B       %FT40

overrun
        MOV     r0, r11
        CallHAL DMAIRQClear
        LDR     r3, [r9, #dmaq_LastBuff]
        ADD     r5, r10, #dmar_CurrBuff
        MOV     r0, r5
        BL      update                          ; Update from old (now completed) current buffer.
        ADD     r0, r10, #dmar_NextBuff
        BL      update                          ; Update from old (now completed) next buffer.
        LDR     r7, [r11, #HALDevice_DMASetCurrentTransfer]
        MOV     r0, r4
        BL      program                         ; Program first transfer.
        STR     r5, [r9, #dmaq_LastBuff]
        MOV     r0, #0
        STR     r0, [r10, #dmar_NextBuff + buff_Len] ; Mark next buffer as not programmed.
        B       %FT40

overrun_finished
        ADD     r0, r10, #dmar_CurrBuff
        BL      update                          ; Update from old (now completed) current buffer.
        ADD     r0, r10, #dmar_NextBuff
        BL      update                          ; Update from old (now completed) next buffer.
        MOV     r0, #0
        STR     r0, [r10, #dmar_CurrBuff + buff_Len] ; Mark current buffer as not programmed.
        STR     r0, [r10, #dmar_NextBuff + buff_Len] ; Mark next buffer as not programmed.
        B       finished

earlyoverrun
        MOV     r0, r11
        CallHAL DMAIRQClear
        ADD     r3, r10, #dmar_CurrBuff
        ADD     r5, r10, #dmar_NextBuff
        LDMIA   r5, {r0-r2}
        STMIA   r3, {r0-r2}                     ; Copy next to current because we put it in the wrong place before.
        STR     r3, [r9, #dmaq_LastBuff]
        BL      reprogram
        B       %FT40

nooverrun
        MOV     r0, r11
        CallHAL DMAIRQClear
        ADD     r3, r10, #dmar_CurrBuff
        LDR     r5, [r9, #dmaq_LastBuff]
        TEQ     r5, r3
        ADD     r5, r10, #dmar_NextBuff
        BEQ     %FT01                           ; If last time we programmed current transfer, then just set up next transfer.
        MOV     r0, r3
        BL      update                          ; Update from old (now completed) current buffer.
        LDMIA   r5, {r0-r2}
        STMIA   r3, {r0-r2}                     ; Copy next to current to reflect what's happened in the hardware.
01      LDR     r7, [r11, #HALDevice_DMASetNextTransfer]
        MOV     r0, r4
        BL      program                         ; Program next transfer.
        STR     r5, [r9, #dmaq_LastBuff]
        ; drop through...
40
        TST     r8, #dmarf_Sync
        BLNE    DMASync

        TST     r8, #dmarf_Halted               ; If transfer has halted due to an unsafe page then
        BNE     exitirq                         ;   wait to be restarted by Service_PagesSafe.

        MOV     r0, r11
        CallHAL TestIRQ
        TEQ     r0, #0                          ; Test whether we're still interrupting.
        BNE     testloop
exitirq
        ADD     sp, sp, #4                      ; Skip r12 on stack.
        Pull    "r4-r11,pc"

 | ; HAL

;-----------------------------------------------------------------------------
;       Channel specific interrupt handler entry points.  These simply set
;       up some registers then branch to the common interrupt handler.
;
DMAInterruptSound1
        MOV     r1, #IOMD_SD1CURA
        MOV     r2, #5
        B       DMAInterruptCommon

DMAInterruptSound0
        MOV     r1, #IOMD_SD0CURA
        MOV     r2, #4
        B       DMAInterruptCommon

DMAInterruptChannel3
        MOV     r1, #IOMD_IO3CURA
        MOV     r2, #3
        B       DMAInterruptCommon

DMAInterruptChannel2
        MOV     r1, #IOMD_IO2CURA
        MOV     r2, #2
        B       DMAInterruptCommon

DMAInterruptChannel1
        MOV     r1, #IOMD_IO1CURA
        MOV     r2, #1
        B       DMAInterruptCommon

DMAInterruptChannel0
        MOV     r1, #IOMD_IO0CURA
        MOV     r2, #0
;       Drop through to...

;-----------------------------------------------------------------------------
; DMAInterruptCommon
;       In:     IRQ mode, IRQs disabled
;               r1  = offset to IOMD DMA registers for channel concerned
;               r2  = physical channel number
;               r0-r3,r11 trashable
;               r12->our workspace
;
;       Common DMA interrupt handler.
;
DMAInterruptCommon
        DebugTab r0,r3,#&01,sp,lr

        Entry   "r4-r10"

        IOMDBase r11

 [ debugint
        LDRB    r3, [r11, #IOMD_DMAMSK]
        MOV     lr, #0
        STRB    lr, [r11, #IOMD_DMAMSK]
        WritePSRc SVC_mode + I_bit, r10
        Push    "r3,lr"
 ]
        Debug   int,"DMAInterrupt"

        ADD     r1, r1, r11                     ; r1->IOMD DMA register block

        PhysToDMAQ r9, r2                       ; r9->DMA queue
        LDR     r10, [r9, #dmaq_Active]         ; r10->active DMA request

        Debug   int," request",r10

        LDR     r8, [r10, #dmar_Flags]

        LDRB    r2, [r1, #IOMD_IOxST]           ; Get state.
        Debug   int," block,state =",r1,r2
 [ debugint
        LDRB    lr, [r1, #IOMD_IOxCR]
        Debug   int," control =",lr
 ]

        TST     r2, #IOMD_DMA_B_Bit
        ADDEQ   r3, r10, #dmar_BuffA            ; r3 -> active buffer info
        ADDNE   r3, r10, #dmar_BuffB
        ADDEQ   r4, r10, #dmar_BuffB            ; r4 -> inactive buffer info
        ADDNE   r4, r10, #dmar_BuffA
        ADDEQ   r6, r1, #IOMD_IOxCURA           ; r6 -> active buffer
        ADDNE   r6, r1, #IOMD_IOxCURB
        ADDEQ   r7, r1, #IOMD_IOxCURB           ; r7 -> inactive buffer
        ADDNE   r7, r1, #IOMD_IOxCURA

testloop
        DebugTab r0,lr,#&02,r2
        LDR     lr, [r9, #dmaq_LastBuff]
        TEQ     lr, r3                          ; If last buffer programmed was current active buffer then
        MOVEQ   r0, r4                          ;   update from inactive (completed) buffer.
        BLEQ    update

        Debug   int," status =",r2
        TST     r2, #IOMD_DMA_O_Bit             ; If not in overrun state then
        BEQ     %FT30                           ;   deal with interrupt only.

        Debug   int," overrun"

        MOV     r0, r3                          ; Update from active (overrun) buffer.
        BL      update

        LDR     r0, [r9, #dmaq_LastBuff]
        TEQ     r0, r3                          ; If active buffer not last programmed then
        BNE     %FT10                           ;   copy inactive.

        TST     r8, #dmarf_Infinite             ; If finite transfer
        LDREQ   r0, [r10, #dmar_Length]
        TEQEQ   r0, #0                          ;     and nothing left to program then
        BEQ     finished                        ;   finished.

        MOV     r5, r3                          ; Program active buffer.
        BL      program
        B       %FT20

10
        Debug   int," copy"
        DebugTab r0,lr,#&03

        TST     r8, #dmarf_Infinite             ; If finite transfer
        LDREQ   r0, [r4, #buff_Len]
        TEQEQ   r0, #0                          ;     and inactive buffer not programmed then
        BEQ     finished                        ;   must have finished.

        LDMIA   r7, {r0,lr}                     ; Copy inactive buffer to active buffer.
        STMIA   r6, {r0,lr}

        LDMIA   r4, {r0,r5,lr}                  ; Copy inactive info to active info.
        STMIA   r3, {r0,r5,lr}

20
        MOV     r0, #0                          ; Mark inactive as not programmed.
        STR     r0, [r4, #buff_Len]
        STR     r3, [r9, #dmaq_LastBuff]        ; Active now last programmed.
        B       %FT40

30
        Debug   int," interrupt only"
        DebugTab r0,lr,#&04
        TST     r8, #dmarf_Infinite             ; If not infinite transfer
        LDREQ   r0, [r10, #dmar_Length]
        TEQEQ   r0, #0                          ;     and length = 0 then
        STREQ   r0, [r7, #4]                    ;   clear interrupt
        STREQ   r0, [r4, #buff_Len]             ;   and mark inactive as not programmed
        MOVNE   r5, r4                          ; else program inactive buffer.
        BLNE    program
        STR     r4, [r9, #dmaq_LastBuff]        ; Inactive now last programmed.
40
        TST     r8, #dmarf_Sync
        BLNE    DMASync

        TST     r8, #dmarf_Halted               ; If transfer has halted due to an unsafe page then
        EXIT    NE                              ;   wait to be restarted by Service_PagesSafe.

        LDRB    r2, [r1, #IOMD_IOxST]           ; Get new state.
        TST     r2, #IOMD_DMA_I_Bit             ; If not in interrupt state then
 [ debugint
        BNE     %FT45
        Pull    "r3,lr"
        WritePSRc IRQ_mode + I_bit, r12
        STRB    r3, [r11, #IOMD_DMAMSK]
        EXIT
45
 |
        EXIT    EQ                              ;   exit (give other IRQs a chance).
 ]

        TST     r2, #IOMD_DMA_B_Bit
        ADDEQ   r3, r10, #dmar_BuffA            ; r3 -> active buffer info
        ADDNE   r3, r10, #dmar_BuffB
        ADDEQ   r4, r10, #dmar_BuffB            ; r4 -> inactive buffer info
        ADDNE   r4, r10, #dmar_BuffA
        ADDEQ   r6, r1, #IOMD_IOxCURA           ; r6 -> active buffer
        ADDNE   r6, r1, #IOMD_IOxCURB
        ADDEQ   r7, r1, #IOMD_IOxCURB           ; r7 -> inactive buffer
        ADDNE   r7, r1, #IOMD_IOxCURA

        B       testloop

 ] ; HAL

finished
; In:
;     [ :LNOT: HAL
;       r0 = 0
;       r1 = ptr to DMA register block
;     ]
;       r8 = DMA request flags
;       r9 = ptr to DMA queue
;       r10 = ptr to DMA request block
;     [ :LNOT: HAL
;       r11 = IOMD base address
;     |
;       r11 = ptr to HAL device
;     ]
;
        Debug   int," finished"
        DebugTab r3,r4,#&05

        TST     r8, #dmarf_Sync                  ; Do any pending syncs.
        BLNE    DMASync

      [ HAL
finished_altentry                                ; For list-type devices.
        MOV     r4, #0
finished_witherror
        MOV     r0, r11
        CallHAL Deactivate

        Pull    "r12"                           ; Needed during the BL's below.
        MOV     r0, r4
      |
        LDRB    r2, [r1, #IOMD_IOxCR]           ; Disable DMA.
        BIC     r2, r2, #IOMD_DMA_E_Bit
        STRB    r2, [r1, #IOMD_IOxCR]
      ]

        ORR     r8, r8, #dmarf_Completed        ; Flag transfer as completed.
        STR     r8, [r10, #dmar_Flags]

        LDR     r8, [r10, #dmar_LCB]            ; r8->logical channel block
      [ :LNOT: HAL
        MOV     r1, #1                          ; Disable physical channel interrupt.
        LDR     r2, [r8, #lcb_Physical]
 [ debugint
        LDR     lr, [sp]
 |
        LDRB    lr, [r11, #IOMD_DMAMSK]
 ]
        BIC     lr, lr, r1, LSL r2
 [ debugint
        STR     lr, [sp]
 |
        STRB    lr, [r11, #IOMD_DMAMSK]
 ]
      ]

; Go into SVC mode as we will be calling SWIs in this last bit. The completed
; transfer remains blocking the physical channel until DMASearchQueue so new
; transfers queued from an interrupt will not jump the queue.

        SwpPSR  r2, SVC_mode + I_bit, lr_irq
        Push    lr

        Debug   dma,"DMAInterrupt - end of transfer"

        BL      DMACompleted                    ; r0=0 (successful)
        BL      DMAUnlinkRequest
        BL      DMAFreeRequestBlock
        BL      DMASearchQueue

        Pull    lr
        SetPSR  r2

 [ debugint
        Pull    "r3,lr"
        WritePSRc IRQ_mode + I_bit, r12
        STRB    r3, [r11, #IOMD_DMAMSK]
 ]

 [ debugtab
      [ HAL
        Pull    "r4-r11,lr"
      |
        PullEnv
      ]
        DebugTab r0,r1,#&06,sp,lr
        MOV     pc, lr
 |
      [ HAL
        Pull    "r4-r11,pc"
      |
        EXIT
      ]
 ]

update
; In:   r0 = buffer to update from
;       r8 = DMA request flags
;       r10 = ptr to DMA request block
;
      [ HAL
        Entry   "r0-r3"
      |
        Entry   "r0-r2"
      ]

        LDR     r2, [r0, #buff_Len]             ; Get amount done.
        Debug   int," update by",r2
        DebugTab r1,lr,#&11,r2
        TEQ     r2, #0                          ; If buffer not programmed then
        EXIT    EQ                              ;   nothing to update.

        LDR     lr, [r10, #dmar_Done]           ; Update amount done.
        ADD     lr, lr, r2
        STR     lr, [r10, #dmar_Done]

        TST     r8, #dmarf_Sync                 ; If doing sync callbacks then
        LDRNE   lr, [r10, #dmar_Gap]            ;   update gap.
        ADDNE   lr, lr, r2
        STRNE   lr, [r10, #dmar_Gap]

        TST     r8, #dmarf_Circular :OR: dmarf_DontUpdate ; If circular, or so requested, then
        EXIT    NE                              ;   don't update scatter list.

        LDR     lr, [r10, #dmar_ScatterList]
10
        LDMIA   lr, {r0,r1}                     ; Get scatter list addr,len.
        CMP     r0, #ScatterListThresh
        TEQHS   r1, #0
        ADDEQ   lr, lr, r0
        STREQ   lr, [r10, #dmar_ScatterList]
        BEQ     %BT10                           ; Restart if looped scatter list.
        TEQ     r1, #0                          ; If zero length entry then
        ADDEQ   lr, lr, #8                      ;   move on to next section.
        STREQ   lr, [r10, #dmar_ScatterList]
        BEQ     %BT10

      [ HAL
        CMP     r2, r1
        MOVHI   r3, r1
        MOVLS   r3, r2                          ; r3 = amount to update this scatter entry by
        ADD     r0, r0, r3
        SUB     r1, r1, r3
        STMIA   lr, {r0,r1}
        EXIT    LS                              ; Do we need to update the next scatter entry too?
        SUB     r2, r2, r3
        ADD     lr, lr, #8
        STR     lr, [r10, #dmar_ScatterList]
        B       %BT10
      |
        ADD     r0, r0, r2                      ; Update addr and len by amount done.
        SUB     r1, r1, r2
        STMIA   lr, {r0,r1}
        DebugTab r2,lr,#&12,r0,r1

        EXIT
      ]


program ROUT
; In:   r0 = length to do for this DMA request
;     [ HAL
;       r3 = ptr to current buffer info
;       r5 = ptr to buffer info for buffer that we're programming
;       r7 = ptr to routine to call (SetCurrentTransfer or SetNextTransfer)
;       r11 = HAL device
;     |
;       r1 = ptr to DMA register block
;       r3 = ptr to active buffer info - at this point, guaranteed to be last buffer programmed
;       r4 = ptr to inactive info
;       r5 = buffer to program
;       r6 = ptr to active buffer
;       r7 = ptr to inactive buffer
;     ]
;       r8 = DMA request flags
;       r9 = ptr to DMA queue
;       r10 = ptr to DMA request block
;
      [ HAL
        Entry   "r11"
      |
        Entry   "r2,r3,r11"
      ]

        Debug   int," program"
        DebugTab r2,lr,#&21,r3,r5

        TST     r8, #dmarf_Circular             ; If not circular buffer then
        BEQ     %FT10                           ;   don't wrap.

        LDR     lr, [r10, #dmar_BuffLen]
        Debug   int," bufflen =",lr
        TEQ     lr, #0                          ; If no buffer left to do then
        LDREQ   r2, [r10, #dmar_PageTable]      ;   page table wraps,
        MOVEQ   r3, #0                          ;   r3 = new offset = 0,
        LDREQ   lr, [r10, #dmar_BuffSize]       ;   whole buffer left to do.
        STREQ   lr, [r10, #dmar_BuffLen]
        BEQ     %FT20

10
        LDMIA   r3, {r2,r3,r11}                 ; Get active buffer ptp, off, len.
        ADD     r3, r3, r11                     ; r3 = amount programmed so far (new offset)
        LDR     lr, [r2, #ptab_Len]             ; Get page table entry length.

        TEQ     r3, lr                          ; If entry has completed
        MOVEQ   r3, #0                          ;   r3 = new offset = 0
        ADDEQ   r2, r2, #PTABSize               ;   and move on page table pointer.
20
        LDREQ   lr, [r2, #ptab_Len]             ; Get page table entry length.

        TST     lr, #ptabf_Unsafe               ; If we have reached an unsafe page then
        BNE     halt                            ;   the transfer must be halted until the page is safe.

        SUB     r11, lr, r3                     ; r11 = new len = page table entry len - new off

        TST     r8, #dmarf_Infinite             ; If infinite then
        BNE     %FT40                           ;   don't test against length.
        CMP     r0, r11                         ; If Length < new len then
        MOVCC   r11, r0                         ;   new len = Length
40
        TST     r8, #dmarf_Circular             ; If not circular then
        BEQ     %FT50                           ;   don't test against BuffLen.
        LDR     lr, [r10, #dmar_BuffLen]
        CMP     lr, r11                         ; If BuffLen < new len then
        MOVCC   r11, lr                         ;   new len = BuffLen
50
        TST     r8, #dmarf_Sync                 ; If not doing sync callbacks then
        BEQ     %FT60                           ;   don't test against ProgGap.
        LDR     lr, [r10, #dmar_ProgGap]
        CMP     r11, lr                         ; If ProgGap <= new len then
        MOVCS   r11, lr                         ;   new len = ProgGap,
        LDRCS   lr, [r10, #dmar_SyncGap]        ;   ProgGap = SyncGap
        SUBCC   lr, lr, r11                     ; else ProgGap -= new len.
        STR     lr, [r10, #dmar_ProgGap]
60
        Debug   int," off,len =",r3,r11
        STMIA   r5, {r2,r3,r11}                 ; Store buffer info.

      [ HAL
        LDR     r1, [r2, #ptab_Physical]        ; Get physical address from page table.
        ADD     r1, r1, r3                      ; r1 = start address
        MOV     r2, r11                         ; r2 = length
        MOV     r3, #0                          ; Default flag contents.
      |
        LDR     r2, [r2, #ptab_Physical]        ; Get physical address from page table.
        ADD     r2, r2, r3                      ; r2 = start address
        ADD     r3, r2, r11                     ; r3 = end address
        BIC     r3, r3, #IOMD_DMA_S_Bit + IOMD_DMA_L_Bit

        LDRB    lr, [r1, #IOMD_IOxCR]           ; Get transfer unit size.
        AND     lr, lr, #IOMD_DMA_IncMask
        SUB     r3, r3, lr                      ; Set real end address.
        TEQ     r11, lr                         ; If length of transfer = transfer unit size then
        ORREQ   r3, r3, #IOMD_DMA_L_Bit         ;   set Last bit.
      ]

        TST     r8, #dmarf_Infinite             ; If infinite then
        BNE     %FT80                           ;   just program buffer.

        SUBS    r0, r0, r11                     ; If adjusted length to do = 0 then
      [ HAL
        ORREQ   r3, r3, #DMASetTransferFlag_Stop ;  set Stop bit.
      |
        ORREQ   r3, r3, #IOMD_DMA_S_Bit         ;   set Stop bit.
      ]
        STR     r0, [r10, #dmar_Length]
80
      [ HAL
        LDR     r0, [sp]                        ; Retrieve device pointer from stack.
        MOV     lr, pc
        MOV     pc, r7
      |
        TEQ     r5, r4                          ; Program buffer.
        STMEQIA r7, {r2,r3}
        STMNEIA r6, {r2,r3}
      ]

        TST     r8, #dmarf_Circular             ; Adjust BuffLen if necessary.
        LDRNE   lr, [r10, #dmar_BuffLen]
        SUBNE   lr, lr, r11
        STRNE   lr, [r10, #dmar_BuffLen]

        DebugTab r2,lr,#&22
        EXIT

halt
        Debug   int," halt"
      [ HAL
        LDR     r0, [sp]                        ; Retrieve device pointer from stack.
        CallHAL Deactivate

        LDR     lr, [r10, #dmar_CurrBuff + buff_Len]
        TEQ     lr, #0                          ; If there was already a transfer in progress for the
        BEQ     %FT90                           ;   other buffer, then we need to stop it since PagesSafe
                                                ;   now requires both transfers to be inactive.

        Push    "r12"
        LDR     r3, [r10, #dmar_LCB]
        LDR     r11, [r10, #dmar_R11]
        LDR     r12, [r3, #lcb_R12]
        LDR     r3, [r3, #lcb_Vector]
        MOV     lr, pc
        LDR     pc, [r3, #vector_Disable]       ; Call Disable callback.
        Pull    "r12"

        ADD     r4, r10, #dmar_CurrBuff
        LDMIA   r4, {r4,r6,r7}

        LDR     r0, [sp]
        CallHAL DMATransferState

        LDR     r2, [r4, #ptab_Physical]
        ADD     r2, r2, r6                      ; This is what the hardware was originally programmed with.
        SUB     r2, r0, r2                      ; Amount actually done.
        STR     r2, [r10, #dmar_CurrBuff + buff_Len] ; Fake up buffer info for the benefit of update.

        ADD     r0, r10, #dmar_CurrBuff
        BL      update

        SUB     r0, r7, r2                      ; r0 = amount programmed but not transferred

        TST     r8, #dmarf_Infinite             ; If finite transfer,
        LDREQ   lr, [r10, #dmar_Length]         ;   add amount not done back onto total length.
        ADDEQ   lr, lr, r0
        STREQ   lr, [r10, #dmar_Length]

        TST     r8, #dmarf_Circular             ; If not circular buffer then
        BEQ     %FT85                           ;   set up for resume.

        LDR     lr, [r10, #dmar_BuffLen]
        ADD     lr, lr, r0                      ; BuffLen left += amount not done
        LDR     r0, [r10, #dmar_BuffSize]
84
        CMP     lr, r0
        SUBCS   lr, lr, r0                      ; BuffLen left = BuffLen left mod BuffSize
        BCS     %BT84
        STR     lr, [r10, #dmar_BuffLen]
85
        TST     r8, #dmarf_Sync                 ; There shouldn't be any outstanding DMASync callbacks at this point
        LDRNE   lr, [r10, #dmar_SyncGap]
        LDRNE   r0, [r10, #dmar_Gap]
        SUBNE   lr, lr, r0                      ;   but ensure ProgGap is valid.

        ADD     r3, r6, r2                      ; Ensure we are set up to resume part-way through the interrupted buffer.
        MOV     r2, r4
90
      ]
        MOV     r11, #0
        STMIA   r5, {r2,r3,r11}                 ; Set up new ptp, new offset and 0 length for the transfer to continue.
      [ :LNOT: HAL
        IOMDBase r11
 [ debugint
        LDR     lr, [sp, #12]
 |
        LDRB    lr, [r11, #IOMD_DMAMSK]         ; Disable channel interrupt.
 ]
        LDR     r2, [r10, #dmar_Tag]
        AND     r2, r2, #dmar_PhysBits
        MOV     r3, #1
        BIC     lr, lr, r3, LSL r2
 [ debugint
        STR     lr, [sp, #12]
 |
        STRB    lr, [r11, #IOMD_DMAMSK]
 ]
      ]
        ORR     r8, r8, #dmarf_Halted           ; Flag transfer as halted.
        STR     r8, [r10, #dmar_Flags]

        EXIT

 [ HAL
reprogram
; Reapply transfer settings that were just too late to make it last time using SetNextTransfer,
; but this time use SetCurrentTransfer.
; In:   r0,r1,r2 = ptp, off, len left by last call to program
;       r8 = DMA request flags
;       r10 = ptr to DMA request block
;       r11 = HAL device
;
        LDR     r3, [r0, #ptab_Physical]        ; Get physical address from page table.
        ADD     r1, r3, r1                      ; r1 = start address
                                                ; r2 = length already
        MOV     r3, #0                          ; Default flag contents.

        TST     r8, #dmarf_Infinite             ; If finite transfer and
        LDREQ   r0, [r10, #dmar_Length]         ;   amount to do
        TEQEQ   r0, #0                          ;   = 0
        ORREQ   r3, r3, #DMASetTransferFlag_Stop ;  then set Stop bit.

        MOV     r0, r11
        LDR     pc, [r11, #HALDevice_DMASetCurrentTransfer]
 ]

        END
