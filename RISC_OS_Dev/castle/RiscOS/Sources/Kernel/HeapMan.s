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
        TTL     => HeapMan : Heap Allocation SWI

; Interruptible heap SWI.

; Look down the IRQ stack to see if anybody was in a heap operation.
; If they were, then (with IRQs off) the foreground call is done first, by
; picking up info from a fixed block. Patch the IRQ stack so that the heap SWI
; is returned to at a "it happened in the background" fixup routine. Current
; request can then be dealt with! Ta Nick.


; Also has an interlock on the register restore area; otherwise anybody
; with an IRQ process doing heap ops with interrupts enabled will cause
; trouble.

        GBLL    debheap
debheap SETL    1=0

    [ :LNOT: :DEF: HeapTestbed
              GBLL HeapTestbed
HeapTestbed   SETL {FALSE}
    ]

 [ DebugHeaps
FreeSpaceDebugMask * &04000000
UsedSpaceDebugMask * &08000000
 ]

Nil     *       0

hpd     RN      r1      ; The punter sees these
addr    RN      r2
size    RN      r3
work    RN      r4

HpTemp  RN      r10     ; But not these
tp      RN      r11
bp      RN      r12

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; +                     H E A P   O R G A N I S A T I O N                     +
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; A heap block descriptor (hpd) has the form

; +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+ -+ -+ -+ -+
; |   magic   |    free   |    base   |    end    |   debug   |
; +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+- +- +- +- +
;  0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20

         ^      0, hpd
hpdmagic #      4
hpdfree  #      4
hpdbase  #      4
hpdend   #      4       ; Needed for debugging heap, and top end validation
 [ debheap
hpddebug #      4       ; 0 -> No debug, ~0 -> Debug
 ]

hpdsize  *      @-hpdmagic

magic_heap_descriptor * (((((("p":SHL:8)+"a"):SHL:8)+"e"):SHL:8)+"H")

; hpdmagic is a unique identification field
; hpdfree  is the offset of the first block in the free space list
; hpdbase  is the offset of the byte above the last one used
; hpdend   is the offset of the byte above the last one usable

;                               | hpdbase
;                              \|/
;      +---+--------------------+--------+
;  low |hpd|     heap blocks    | unused | high
;      +---+--------------------+---------+
;              /|\                       /|\ 
;               | hpdfree                 | hpdend
;               | in here somewhere.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Blocks in the free space list have the form :

; +--+--+--+--+--+--+--+--+--+ ~ -+--+
; | long link | long size |          |
; +--+--+--+--+--+--+--+--+--+ ~ -+--+
;  0  1  2  3  4  5  6  7  8      (size-1)
;
; where the link field is an offset to the next free block

           ^    0 ; Can't use register relative unfortunately as many regs used
frelink    #    4
fresize    #    4
freblksize #    0

; The link field is Nil (0) for the last block in the list

; Block sizes must be forced to a minimum of 8 bytes for subsequent link and
; size information to be stored in them if they are disposed of by the user.

; They must also be capable of storing a 4 byte size field while allocated.
; This field is used to size the block to free when FreeArea is called.

; This is the threshold for minimum heap block fragmentation size.  Splitting a
; free block won't leave a free block which is <= than the size declared here.
; If by choosing to use a particular free block, allocating a new block would
; leave a free block of this size or less, add it on to the original size request
; to avoid generating lots of silly little blocks that slow things down so much.
; This value must not be too large because non-C callers may extend the block
; piecemeal based on their (now wrong) knowledge of the block size.  The C library
; reads the block size straight out of the heap block data, and will thus not
; be fooled.
minheapfragsize # 8

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; The Macros
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Check hpd valid

        MACRO
$label  ValidateHpd $faildest
$label  BL      ValidateHpdSubr
        BNE     $faildest._badhpd
        MEND


; Call XOS_Heap SWI

        MACRO
        CallXOSHeap
      [ HeapTestbed
        BL      DoCallXOSHeap
      |
        SWI     XOS_Heap
      ]
        MEND

;****************************************************************************

; These bits of ExtendBlock are outside the IRQ HeapOp range because they
; don't update the heap structure, so we can safely restore old IRQ status

CopyBackwardsInSafeZone
        LDR     work, [stack, #3*4]     ; get user link
        ANDS    work, work, #I_bit      ; look at I_bit

        WritePSRc SVC_mode, work, EQ    ; if was clear then clear it now

        ADD     bp, bp, #4              ; new block pointer
        STR     bp, [stack]             ; return to user

; copy wackbords: HpTemp-4 bytes from addr+4 to bp, in appropriate order!
cpe_prev
        SUBS    HpTemp, HpTemp, #4
        LDRGT   work, [addr, #4]!
        STRGT   work, [bp], #4
        BGT     cpe_prev

        WritePSRc SVC_mode + I_bit, work; disable IRQs before we venture back
        B       GoodExtension           ; into danger zone

ReallocateInSafeZone
        LDR     work, [addr, hpd]!      ; get block size, set block addr
        ADD     size, size, work
        SUB     size, size, #4          ; block size to claim
        ADD     addr, addr, #4
        MOV     bp, addr                ; address to copy from
        Push    addr                    ; save for later freeing

        MOV     R0, #HeapReason_Get
        CallXOSHeap
        Pull    addr, VS
        BVS     SafeNaffExtension

 [ debheap
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT06
 DREG work, "got new block : copying "
06
 ]

        STR     addr, [stack, #4]

; claimed : copy work-4 bytes from bp to addr
CopyForExtension
        SUBS    work, work, #4
        LDRGT   HpTemp, [bp],#4
        STRGT   HpTemp, [addr],#4
        BGT     CopyForExtension

; free the old block!

 [ debheap
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT08
 WRLN "freeing old block"
08
 ]

; recursive SWI to free old block; we have invalidated any held information

        MOV     R0, #HeapReason_Free
        Pull    addr                    ; heap block addr
        CallXOSHeap

        MOVVC   R0, #HeapReason_ExtendBlock
        WritePSRc SVC_mode + I_bit,work ; disable IRQs before we venture back
        BVC     GoodExtension           ; into danger zone

SafeNaffExtension
        WritePSRc SVC_mode + I_bit,work  ; disable IRQs before we venture back
        B       NaffExtension           ; into danger zone


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Here's the bit that gets returned to if the heap op was done in the
; background. Pick up the registers, look at the saved PSR to see if error
; return or OK.
; This bit musn't be in range of the IRQ Heap Op checking!!!
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

heapopdoneinbackground ROUT
        LDR        R12, =ZeroPage+HeapReturnedReg_R0

        LDMIA     R12, {R0-R4, R10, R11}
        MOV       stack, R10
        MOV       R10, #0
        STR       R10, [R12, #HeapReturnedReg_PSR-HeapReturnedReg_R0]
                                      ; clear the interlock
        TST       R11, #V_bit         ; look at returned error
        BEQ       GoodHeapExit
        ; Recover the error from our buffer
        LDR       R0,=HeapBackgroundError
        LDR       R10,[R0]
        SWI       XMessageTrans_CopyError
        ; Check that it worked - MessageTrans may be dead
        LDR       R11,[R0]
        TEQ       R10,R11
        LDRNE     R0,=HeapBackgroundError ; Just return our internal buffer if MessageTrans couldn't provide one
        B         NaffHeapExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; HeapEntry. SWI level entry
; =========
;
; Perform actions on the heap block described by r1(hpd)

; In    r0       =  heap action requested
;       r1(hpd)  -> heap block
;       r2(addr) -> start of block, or required alignment
;       r3(size) =  size of block
;       r4(work) =  boundary limitation

; Out   VClear -> Action performed
;       VSet   -> Something terrible has happened, error set
;       Rest of universe ok

HeapEntry ROUT
        Push    lr
        SavePSR lr                      ; hang on to interrupt state

 ; First check that we aren't in an interrupted Heap Op
        WritePSRc SVC_mode+I_bit, R11
        LDR     R11, =ZeroPage+IRQsema
inspect_IRQ_stack
        LDR     R11, [R11]
        CMP     R11, #0
        BEQ     iis_end
        LDR     R10, [R11, #4*8]        ; Get LR from IRQ stack
        ADR     R12, first_heap_address_to_trap
        CMP     R10, R12
        ADRGEL  R12, HeapCode_end
        CMPGE   R12, R10
        BLT     inspect_IRQ_stack

    ; somebody's in the heap code! Time for perversion.
    ; Pick up registers, do foreground op, poke IRQstack return address

         ADRL   R10, heapopdoneinbackground
         STR    R10, [R11, #4*8]               ; return address zapped
         LDR    R10, [R11, #4*6]               ; get stored SPSR
         BIC    R10, R10, #&FF
         ORR    R10, R10, #I32_bit:OR:SVC2632
         STR    R10, [R11, #4*6]               ; return into SVC26/32 mode with IRQs disabled

         Push  "R0-R4, lr"

         LDR    R10, =ZeroPage+HeapSavedReg_R0

; This can't happen: heap ops are non-interruptible while foreground ops
; are waiting to complete
;         LDR    R12, [R10, #HeapReturnedReg_PSR-HeapSavedReg_R0]
;         CMP    R12, #0
;         BNE    HeapInUse

         LDMIA  R10, {R0-R4, R11}
         SWI    XOS_Heap                ; with interrupts off!
         LDR    R12, =ZeroPage+HeapReturnedReg_R0

   ; Could we poke these into the IRQ stack too...?
   ; would allow interruptible IRQ processes to do heap ops!!!
         MRS    lr, CPSR
         STMIA  R12, {R0-R4, R11, lr}
; Any errors that were generated by the foreground operation may have ended up
; using one of MessageTrans' IRQ buffers. Trouble is, any number of IRQ errors
; could occur between now and when the foreground task gets the error. Avoid
; the error getting clobbered by copying it into a special kernel buffer, and
; then copy it back to a MessageTrans buffer once we're back in the foreground.
         BVC    noheapbackgrounderror
         LDR    R1,=HeapBackgroundError
         MOV    LR,#256
heapbackgrounderrorloop
         LDMIA  R0!,{R2-R4,R12}
         SUBS   LR,LR,#16
         STMIA  R1!,{R2-R4,R12}
         BNE    heapbackgrounderrorloop
         
noheapbackgrounderror
         Pull  "R0-R4, lr"

iis_end                                 ; store the registers in the info block
        LDR     R12, =ZeroPage+HeapSavedReg_R0
        STMIA   R12, {R0-R4}
        STR     stack, [R12, #5*4]

first_heap_address_to_trap              ; because register saveblock now set.
        LDR     R12, [R12, #HeapReturnedReg_PSR-HeapSavedReg_R0]
        CMP     R12, #0
        RestPSR lr, EQ                  ; restore callers interrupt state
                                        ; only if no foreground waiting to
                                        ; complete

        CMP     r0, #MaxHeapCode        ; now despatch it.
        ADDLS   pc, pc, r0, LSL #2      ; Tutu : faster & shorter
        B       NaffHeapReason          ; Return if unknown call reason

HeapJumpTable ; Check reason codes against Hdr:Heap defs

 assert ((.-HeapJumpTable) :SHR: 2) = HeapReason_Init
        B       InitHeap
 assert ((.-HeapJumpTable) :SHR: 2) = HeapReason_Desc
        B       DescribeHeap
 assert ((.-HeapJumpTable) :SHR: 2) = HeapReason_Get
        B       GetArea
 assert ((.-HeapJumpTable) :SHR: 2) = HeapReason_Free
        B       FreeArea
 assert ((.-HeapJumpTable) :SHR: 2) = HeapReason_ExtendBlock
        B       ExtendBlock
 assert ((.-HeapJumpTable) :SHR: 2) = HeapReason_ExtendHeap
        B       ExtendHeap
 assert ((.-HeapJumpTable) :SHR: 2) = HeapReason_ReadBlockSize
        B       ReadBlockSize
 assert ((.-HeapJumpTable) :SHR: 2) = HeapReason_GetAligned
        B       GetAreaAligned
 [ debheap
        B       ShowHeap
 ]
MaxHeapCode * (.-HeapJumpTable-4) :SHR: 2 ; Largest valid reason code


NaffHeapReason
        ADR     R0, ErrorBlock_HeapBadReason
      [ International
        BL      TranslateError
      ]
NaffHeapExit                            ; get here with R0 = error ptr
        SETV
GoodHeapExit                            ; V cleared on entry to SWI dispatch
        SETPSR  I_bit, R12              ; IRQs off
        Pull    lr
        ORRVS   lr, lr, #V_bit          ; VSet Exit

      [ HeapTestbed
        MSR     CPSR_cxsf, lr           ; Fake exit for testbed
        Pull    "r10-r12,pc"
      |
        ExitSWIHandler                  ; Like all good SWI handlers
      ]

; Errors
       MakeErrorBlock  HeapBadReason
       MakeErrorBlock  HeapFail_Init
       MakeErrorBlock  HeapFail_BadDesc
       MakeErrorBlock  HeapFail_BadLink
       MakeErrorBlock  HeapFail_Alloc
       MakeErrorBlock  HeapFail_NotABlock
       MakeErrorBlock  HeapFail_BadExtend
       MakeErrorBlock  HeapFail_ExcessiveShrink
;       MakeErrorBlock  HeapFail_HeapLocked

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Subroutine to validate heap pointer
; checks hpd points at existing LogRam
; and also that internal offsets fall into the same block of RAM

ValidateHpdSubr
        Push   "R0-R3, lr"

        SavePSR R3
        WritePSRc SVC_mode+I_bit, R0 ; interrupts off for validation
        MOV     R0, hpd
        ADD     R1, hpd, #hpdsize+freblksize
        SWI     XOS_ValidateAddress
        BCS     vhpds_fail

        TST     R0, #3              ; check alignment
        LDREQ   HpTemp, =magic_heap_descriptor
        LDREQ   tp, [R0, #:INDEX: hpdmagic]
        CMPEQ   tp, HpTemp
        BNE     vhpds_fail           ; failure

        LDR     R1, [R0, #:INDEX: hpdend]
        ADD     R1, R1, R0
        SWI     XOS_ValidateAddress
        BCS     vhpds_fail           ; failure

        ORR     R3, R3, #Z_bit       ; success
        RestPSR R3
        Pull   "R0-R3, PC"

vhpds_fail
        BIC     R3, R3, #Z_bit       ; NE returned ; fails
        RestPSR R3
        Pull   "R0-R3, PC"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; InitHeap. Top level HeapEntry
; ========
;
; Initialise a heap descriptor block

; In : hpd -> block to initialise, size = size of block

; Out : VClear -> Block initialised
;       VSet   -> Something terrible has happened
;       Rest of universe ok

; To initialise (or even reinitialise) a heap descriptor:
; $(
;   hpd!magic := magic_heap_descriptor
;   hpd!free  := Nil
;   hpd!base  := hpdsize
;   hpd!end   := size
; $)

InitHeap ROUT
        CMP     size,#hpdsize+freblksize
        BLT     NaffHeapInitialise        ; can't get hpd and 1 block in

        Push   "R0, R1"
        MOV     R0, hpd
        ADD     R1, hpd, size
        SWI     XOS_ValidateAddress
        Pull   "R0, R1"
        BCS     NaffHeapInitialise

 [ DebugHeaps
        ORR     lr, hpd, #FreeSpaceDebugMask    ; form word to store throughout heap
        ADD     HpTemp, hpd, size               ; HpTemp -> end of heap
10
        STR     lr, [HpTemp, #-4]!              ; store word, pre-decrementing
        TEQ     HpTemp, hpd                     ; until we get to start
        BNE     %BT10
 ]

        LDR     HpTemp, =magic_heap_descriptor
        STR     HpTemp, hpdmagic          ; hpd!magic := magic_heap_desc
        MOV     HpTemp, #Nil
        STR     HpTemp, hpdfree           ; hpd!free  := Nil
        MOV     HpTemp, #hpdsize
        STR     HpTemp, hpdbase           ; hpd!base  := hpdsize
        STR     size,   hpdend            ; hpd!end   := size

 [ debheap
 MOV HpTemp, #0 ; No debugging until the punter sets this Word
 STR HpTemp, hpddebug
 ]
        B       GoodHeapExit

NaffHeapInitialise
 [ debheap
 WRLN "Unaligned/too big hpd/size: InitHeap failed"
 ]
        ADR     R0, ErrorBlock_HeapFail_Init
      [ International
        BL      TranslateError
      ]
        B       NaffHeapExit               ; VSet exit

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DescribeHeap. Top level HeapEntry
; ============
;
; Return information about the heap whose descriptor is pointed to by hpd

; In : hpd -> heap descriptor

; Out : VClear -> addr = max block size claimable, size = total free store
;       VSet   -> Something wrong
;       Rest of universe ok

DescribeHeap ROUT
        ValidateHpd describefailed

 [ debheap
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT00
 Push  link
 WRLN "DescribeHeap"
 BL iShowHeap
 Pull link
00
 ]
        LDR     addr, hpdend
        LDR     HpTemp, hpdbase

        SUB     addr, addr, HpTemp        ; unused area at base to end
        MOV     size, addr

        LDR     bp, hpdfree
        ADR     tp, hpdfree
        ADD     HpTemp, HpTemp, hpd      ; address of end of allocated memory
        B       %FT20


; Main loop chaining up free space list. size = total, addr = maxvec

15      ADD     tp, tp, bp              ; get address of next
        CMP     tp, HpTemp
        BHS     describefailed_badlink  ; points outside allocated memory
        LDR     bp, [tp, #fresize]      ; Size of this block.
        CMP     bp, addr                ; if size > maxvec then maxvec := size
        MOVHI   addr, bp
        ADD     size, size, bp          ; tfree +:= size
        LDR     bp, [tp, #frelink]      ; Get offset to next block
20      CMP     bp,#Nil                 ; we know Nil is 0!
        BLT     describefailed_badlink  ; -ve are naff
        BNE     %BT15

        CMP     addr, #0
        SUBGT   addr, addr, #4          ; max block claimable
        B       GoodHeapExit            ; VClear Exit


describefailed_badhpd
 [ debheap
 WRLN "Invalid heap descriptor: DescribeHeap failed"
 ]
        ADR     R0, ErrorBlock_HeapFail_BadDesc
      [ International
        BL      TranslateError
      ]
        B       NaffHeapExit            ; VSet Exit

describefailed_badlink
 [ debheap
 WRLN "Invalid heap link: DescribeHeap failed"
 ]
        ADR     R0, ErrorBlock_HeapFail_BadLink
      [ International
        BL      TranslateError
      ]
        B       NaffHeapExit            ; VSet Exit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; GetArea. Top level HeapEntry
; =======
;
; Allocate a block of memory from the heap

; This will allocate the first block of sufficiently large size in the free
; list, with an oversize block being split.
; Failure to find a large enough block on the free list will try to claim
; space out of the heap block.
; Fails if requesting size = 0

; In : hpd -> heap pointer, size = size of block required

; Out : VClear : addr -> got a block
;       VSet   : addr = 0, couldn't get block
;       Rest of universe ok

GetArea ROUT
        Push   "size"
        ValidateHpd garfailed

 [ debheap
; HpTemp not critical
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT00
 Push  "r0, link"
 MOV r0, size
 DREG r0, "GetArea "
 BL iShowHeap
 Pull "r0, link"
00
 ]

        CMP     size, #0                        ; Can't deallocate 0, so there!
        BLE     garfailed_zero                  ; And -ve is invalid as well!
     ; note sizes of many megabytes thrown out by looking.

        ADD     size, size, #3+4                ; Make block size multiple of 4
        BIC     size, size, #3                  ; including header

        ADR     addr, hpdfree-frelink           ; addr:= @(hpd!free)-frelink

garloop
        LDR     tp, [addr, #frelink]        ; tp := addr!fre.link
        CMP     tp, #Nil                    ; Is this the end of the chain ?
        BEQ     garmore                     ;  - so try main blk
        ADD     addr, addr, tp              ; convert offset
        LDR     HpTemp, [addr, #fresize]    ; If length < size then no good
        SUBS    HpTemp, HpTemp, size        ; In case this works, for below split
        BLO     garloop

;
; Try and stop very small blocks appearing due to fragmentation - if we fitted with
; a minimal amount of overhead, pretend we had an exact match
;
        CMPNE   HpTemp, #minheapfragsize+1  ; set LO if we can salvage this tiny block
        ADDLO   size, size, HpTemp          ; increment the size to encompass the block
        MOVLOS  HpTemp, #0                  ; pretend we fitted exactly, set EQ

; Now addr -> a block on the free space list that our item will fit in
; If we have an exact fit (or as close as the granularity of the free list will
; allow), unlink this block and return it

        CMP     HpTemp, #freblksize
        BGE     SplitFreeBlock

; Increase allocation size if there wasn't enough space to split the free block
        ADD     size, size, HpTemp

 [ debheap
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT60
 WRLN "Got an exact fit block"
60
 ]

        LDR     HpTemp, [addr, #frelink]  ; Move this block's link field
        CMP     HpTemp, #Nil
        ADDNE   HpTemp, HpTemp, tp        ; convert offset into offset from
                                          ; previous block
        WritePSRc SVC_mode+I_bit, lr
        ASSERT  frelink=0
        STR     HpTemp, [addr, -tp]       ; store in link of previous block
        B       ResultIsAddrPlus4

SplitFreeBlock
; Need to split the free block, returning the end portion to the caller

 [ debheap
; HpTemp critical
 Push  HpTemp
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT70
 WRLN "Splitting free block"
70
 Pull HpTemp
 ]

        WritePSRc SVC_mode+I_bit, lr
        STR     HpTemp, [addr, #fresize]  ; Adjust size of free block remaining
        ADD     addr, addr, HpTemp        ; addr -> free block just deallocated

ResultIsAddrPlus4
 [ DebugHeaps
        ORR     lr, hpd, #UsedSpaceDebugMask    ; form word to store throughout block
        ADD     HpTemp, addr, size              ; HpTemp -> end of block
75
        STR     lr, [HpTemp, #-4]!              ; store word, pre-decrementing
        TEQ     HpTemp, addr
        BNE     %BT75
 ]

        STR     size, [addr], #4        ; Store block size and increment addr
        Pull    "size"                  ; Return original value to the punter
                                    ; Note : real size got would be an option!
        CLRV
        B       GoodHeapExit            ; RESULTIS addr


; Got no more free blocks of length >= size, so try to allocate more heap space
; out of the block described by hpd

garmore
 [ debheap
; HpTemp not critical
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT80
 WRLN "Trying to get more from main block"
80
 ]

        LDR     addr, hpdbase
        ADD     tp, addr, size        ; addr := (hpd!base +:= size)
        LDR     HpTemp, hpdend
        WritePSRc SVC_mode+I_bit, lr
        CMP     tp, HpTemp            ; See if we'd fall out of the bottom
        STRLS   tp, hpdbase           ; Only adjust hpdbase if valid alloc
        ADDLS   addr, addr, hpd       ; offset conversion
        BLS     ResultIsAddrPlus4
 [ debheap
 STRIM "Not enough room to allocate in main block"
 ]

garfailed
        ADRL    R0, ErrorBlock_HeapFail_Alloc
      [ International
        BL      TranslateError
      ]
 [ debheap
 WRLN " : GetArea failed"
 ]
garfail_common
        MOV     addr, #0                ; addr := 0 if we couldn't allocate
        Pull    "size"                  ; RESULTIS 0
        B       NaffHeapExit            ; VSet Exit

garfailed_badhpd
 [ debheap
 STRIM "Invalid heap descriptor"
 ]
        ADRL    R0, ErrorBlock_HeapFail_BadDesc
      [ International
        BL      TranslateError
      ]
        B garfail_common

 [ debheap
garfailed_zero
 STRIM "Can't allocate 0 or less bytes"
 B garfailed
 |
garfailed_zero * garfailed
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; GetAreaAligned. Top level HeapEntry
; ==============
;
; Allocate an aligned block of memory from the heap

; This is the same as GetArea, except it will only allocate areas with the given
; (power-of-two) alignment.
; Fails if requesting size = 0

; In : hpd -> heap pointer
;      size = size of block required
;      addr = alignment (power of 2)
;      work = boundary (power of 2, 0 for none)

; Out : VClear : addr -> got a block
;       VSet   : addr = 0, couldn't get block
;       Rest of universe ok

GetAreaAligned ROUT
        Push   "size,work"
        ValidateHpd garafailed

 [ debheap
; HpTemp not critical
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT00
 Push  "r0, link"
 MOV r0, size
 DREG r0, "GetAreaAligned "
 MOV r0, addr
 DREG r0, "alignment "
 MOV r0, work
 DREG r0, "boundary "
 BL iShowHeap
 Pull "r0, link"
00
 ]

        CMP     size, #0                        ; Can't deallocate 0, so there!
        BLE     garafailed_zero                 ; And -ve is invalid as well!
     ; note sizes of many megabytes thrown out by looking.

        ADD     size, size, #3                  ; Make block size multiple of 4
        BIC     size, size, #3                  ; excluding header

        SUB     bp, addr, #1                    ; Store alignment-1 in bp
        TST     bp, addr
        BNE     garafailed_align                ; Must be power of 2!
        CMP     bp, #3
        MOVLT   bp, #3                          ; Minimum alignment is 4

        SUB     r0, work, #1                    ; Store boundary-1 in r0
        TST     r0, work
        BNE     garafailed_boundary             ; Must be power of 2!

        ADR     addr, hpdfree-frelink           ; addr:= @(hpd!free)-frelink

        ; If we have a boundary, it must be >= alignment, and >= size
        CMP     r0, #-1
        BEQ     garaloop
        CMP     r0, bp
        CMPHS   work, size
        BLO     garafailed_boundary2

garaloop
        LDR     tp, [addr, #frelink]        ; tp := addr!fre.link
        CMP     tp, #Nil                    ; Is this the end of the chain ?
        BEQ     garamore                    ;  - so try main blk
        ADD     addr, addr, tp              ; convert offset
        LDR     HpTemp, [addr, #fresize]

; Calculate start and end addresses as if we were to allocate from this block
        ADD     work,addr,#4 ; 4 bytes for storing block size
        ADD     HpTemp,HpTemp,addr ; End of free block
        ADD     work,work,bp
garaloop2
        BIC     work,work,bp ; work = start of user block
        SUB     lr,work,addr
        CMP     lr,#4
        BEQ     garastartok ; Start alignment is exact
        CMP     lr,#freblksize+4
        BGE     garastartok ; Enough space to fit a free block at the start

; We need a free block, but there isn't enough space for it.
; Shift 'work' up by one unit of alignment and try again.

        ADD     work,work,bp,LSL #1
        B       garaloop2

garastartok
; Calculate block end address
        ADD     lr,work,size ; End of user block
        SUBS    lr,HpTemp,lr ; Gap after user block
        BLO     garaloop ; Not big enough

; Check boundary requirement
        CMP     r0,#-1
        BEQ     garaboundaryok
        AND     lr,work,r0 ; Start offset within boundary
        ADD     lr,lr,size
        SUB     lr,lr,#1 ; Last byte of allocation
        CMP     lr,r0
        BLS     garaboundaryok

; This allocation crosses a boundary. Shift 'work' up to be boundary aligned.
        ADD     work,work,r0
        BIC     work,work,r0
        B       garaloop2 ; Loop back round to recheck everything (with small boundary sizes, we may have created a situation where we can't fit an initial free block)

garaboundaryok

; We have a suitable space to allocate from.
        ADD     size,size,#4 ; Correct size to store
        SUB     work,work,#4 ; Correct block start

 [ debheap
 LDR lr, hpddebug
 CMP lr, #0
 BEQ %FT60
 WRLN "Using existing free block"
60
 ]

; Note: bp now being used as scratch

        ADD     bp,work,size ; End of user block
        SUB     bp,HpTemp,bp ; Gap after user block

        WritePSRc SVC_mode+I_bit, lr

; Work out if we need a new free block afterwards
        CMP     bp, #freblksize
        ADDLT   size, size, bp ; Not enough space, so enlarge allocated block
        BLT     %FT10

; Create a new free block that will lie after our allocated block
        SUB     HpTemp, HpTemp, bp
        STR     bp, [HpTemp, #fresize]    ; Write size
        LDR     bp, [addr, #frelink]
        CMP     bp, #Nil
        ADDNE   bp, bp, addr
        SUBNE   bp, bp, HpTemp
        STR     bp, [HpTemp, #frelink]    ; Write next ptr
        SUB     HpTemp, HpTemp, addr
        STR     HpTemp, [addr, #frelink]  ; Fix up link from previous block
10

; Shrink this free block to take up the space preceeding the allocated block.
        SUBS    bp,work,addr
        STRNE   bp, [addr, #fresize]
        BNE     ResultIsWorkPlus4 

; No space for an initial free block. Get rid of it.
        ASSERT  frelink=0 ; otherwise LDR bp,[addr,#frelink]!
        LDR     bp, [addr]
        CMP     bp, #0
        ADDNE   bp, bp, tp
        STR     bp, [addr, -tp]
        B       ResultIsWorkPlus4
 
; Got no more free blocks of length >= size, so try to allocate more heap space
; out of the block described by hpd

garamore
 [ debheap
 LDR work, hpddebug
 CMP work, #0
 BEQ %FT80
 WRLN "Trying to get more from main block"
80
 ]
        LDR     work, hpdbase
        ADD     work, work, hpd
        ADD     tp, work, #4
        ADD     tp, tp, bp
garamoreloop
        BIC     tp, tp, bp            ; tp = pointer to return to user

; Make sure there's enough space for a free block if necessary
        SUB     HpTemp, tp, work      ; HpTemp = tp-(hpd+hpdbase)
        CMP     HpTemp, #4
        BEQ     garamoreok
        CMP     HpTemp, #freblksize+4
        ADDLT   tp, tp, bp, LSL #1 ; Not enough space for free block
        BLT     garamoreloop

garamoreok
; Boundary check
        CMP     r0, #-1
        BEQ     garamoreboundaryok
        AND     HpTemp, tp, r0
        ADD     HpTemp, HpTemp, size
        SUB     HpTemp, HpTemp, #1
        CMP     HpTemp, r0
        BLS     garamoreboundaryok

; Shift 'tp' up to be boundary aligned
        ADD     tp, tp, r0
        BIC     tp, tp, r0
        B       garamoreloop

garamoreboundaryok
        ADD     HpTemp, tp, size      ; New heap end
        SUB     HpTemp, HpTemp, hpd   ; New heap size
        LDR     lr, hpdend
        CMP     HpTemp, lr
        BGT     garafailed

        WritePSRc SVC_mode+I_bit, lr

; Set up the block to return to the user
        ADD     size, size, #4
        STR     size, [tp, #-4]!

; Grow the heap
        STR     HpTemp, hpdbase

; Create preceeding free block if necessary
        SUBS    HpTemp, tp, work
        BEQ     ResultIsTpPlus4

; Write the free block
        STR     HpTemp, [work, #fresize]
        MOV     HpTemp, #Nil
        STR     HpTemp, [work, #frelink]

; Patch up the preceeding block
        SUB     HpTemp, work, addr
        STR     HpTemp, [addr, #frelink]

ResultIsTpPlus4
; Block size is already stored
        ADD     addr, tp, #4
        Pull    "size,work"
        MOV     r0,#HeapReason_GetAligned
        CLRV
        B       GoodHeapExit        
        
ResultIsWorkPlus4
        STR     size, [work]           ; Store block size
        ADD     addr, work, #4         ; Move to correct return reg & add offset
        Pull    "size,work"
        MOV     r0,#HeapReason_GetAligned
        CLRV
        B       GoodHeapExit

garafailed
        ADRL    R0, ErrorBlock_HeapFail_Alloc     
      [ International
        BL      TranslateError
      ]
 [ debheap
 WRLN " : GetAreaAligned failed"
 ]
garafail_common
        MOV     addr, #0                ; addr := 0 if we couldn't allocate
        Pull    "size,work"             ; RESULTIS 0
        B       NaffHeapExit            ; VSet Exit

garafailed_badhpd
 [ debheap
 STRIM "Invalid heap descriptor"
 ]
        ADRL    R0, ErrorBlock_HeapFail_BadDesc
      [ International
        BL      TranslateError
      ]
        B garafail_common

 [ debheap
garafailed_zero
 STRIM "Can't allocate 0 or less bytes"
 B garafailed
garafailed_align
 STRIM "Alignment not power of 2"
 B garafailed
garafailed_boundary
 STRIM "Boundary not power of 2"
 B garafailed
garafailed_boundary2
 STRIM "Boundary too small"
 B garafailed
 |
garafailed_zero * garafailed
garafailed_align * garafailed
garafailed_boundary * garafailed
garafailed_boundary2 * garafailed
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; FreeArea. Top level HeapEntry
; ========
;
; Return an area of store to the heap

; In : hpd -> heap descriptor, addr -> block to free

; Out : VClear -> block freed
;       VSet   -> failed to free block, size invalid
;       Rest of universe ok

; The block to be freed is matched against those on the free list and inserted
; in it's correct place, with the list being maintained in ascending address
; order. If possible, the freed block is merged with contigous blocks above
; and below it to give less fragmentation, and if contiguous with main memory,
; is merged with that. If the latter, check to see if there is a block which
; would be made contiguous with main memory by the former's freeing, and if so,
; merge that with main memory too. Phew !

FreeArea ROUT
        Push    "addr, size, work"

 [ debheap
; HpTemp not critical
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT00
 Push  "r0, link"
 STRIM "FreeArea "
 SUB r0, addr, hpd
 SUB r0, r0, #4
 BL PrintOffsetLine
 BL iShowHeap
 Pull "r0, link"
00
 ]
        BL      FindHeapBlock
        BLVC    FreeChunkWithConcatenation

        Pull    "addr, size, work"
        BVC     GoodHeapExit
        B       NaffHeapExit            ; VSet Exit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ExtendBlock. Top level HeapEntry
; ===========
;
; Extend or reallocate existing block

; In : hpd -> heap descriptor, addr -> block, size = size to change by

; Out : VClear -> block freed, addr new block pointer
;       VSet   -> failed to extend block
;       Rest of universe ok

ExtendBlock

        Push    "addr, size, work"

 [ debheap
; HpTemp not critical
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT00
 Push  "r0, link"
 DREG size, "ExtendBlock by ",cc
 STRIM " block  at "
 SUB r0, addr, hpd
 SUB r0, r0, #4
 BL PrintOffsetLine
 BL iShowHeap
 Pull "r0, link"
00
 ]
        BL      FindHeapBlock
        BVS     NaffExtension

        ADD     size, size, #3             ; round size as appropriate :
        BICS    size, size, #3             ; round up to nearest 4

        BEQ     GoodExtension              ; get the easy case done.
        BPL     MakeBlockBigger

        RSB     size, size, #0
        LDR     bp, [addr, hpd]          ; get block size
        WritePSRc SVC_mode+I_bit, R14
        SUB     bp, bp, size             ; size of block left
        CMP     bp, #4

 [ debheap
; HpTemp not critical, GE/LT critical
 BLE %FT01
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT01
 WRLN "Freeing part of block"
01
 CMP bp, #4  ; restore GE/Lt
 ]

        MOVLE    HpTemp, #-1               ; if discarding block, then
        STRLE    HpTemp, [stack]           ; make pointer really naff.
        BLE      GoodShrink

        ; If we're only shrinking 4 bytes, only allow the shrink to go ahead
        ; if there's a free block (or hpdbase) after us
        CMP      size, #4
        BGT      DoShrink
        LDR      HpTemp, [hpd, tp]
        CMP      HpTemp, #Nil
        ADDNE    HpTemp, HpTemp, tp        ; Offset of next free block
        LDREQ    HpTemp, hpdbase
        SUB      HpTemp, HpTemp, addr      ; Offset from start of this block
        SUB      HpTemp, HpTemp, size      ; Apply shrink amount to match bp
        CMP      HpTemp, bp
        MOVGT    size, #0                  ; Used block after us. Deny shrink.
        BGT      GoodExtension
        BLT      CorruptExtension          ; Heap corrupt! Next free block is before us
        ; Else there's a free block (or hpdbase) directly after us
DoShrink
        STR      bp, [addr, hpd]           ; update size of block left
        ADD      addr, addr, bp            ; offset of block to free
        STR      size, [addr, hpd]         ; construct block for freeing

GoodShrink
        BL      FreeChunkWithConcatenation ; work still set from block lookup
GoodExtension
        Pull    "addr, size, work"
 [ DebugHeaps
        MOVS    lr, size                        ; work out how much we actually extended by
        BEQ     %FT99                           ; if zero or negative
        BMI     %FT99                           ; then nothing to do
        LDR     HpTemp, [addr, #-4]             ; get new block size
        SUB     HpTemp, HpTemp, #4              ; Exclude size word itself
        ADD     HpTemp, addr, HpTemp            ; end of new block
        SUB     lr, HpTemp, lr                  ; start of new extension
        ORR     bp, hpd, #UsedSpaceDebugMask
98
        STR     bp, [HpTemp, #-4]!              ; store word
        TEQ     HpTemp, lr
        BNE     %BT98
99
 ]
        CLRV
        B        GoodHeapExit

MakeBlockBigger
        LDR      HpTemp, [addr, hpd]       ; get size
        ADD      HpTemp, HpTemp, addr      ; block end
; TMD 01-Mar-89: FindHeapBlock now never returns tp=Nil, only tp=hpdfree,
; so no need for check
        LDR      bp, [tp, hpd]             ; next free
        CMP      bp, #Nil
        ADDNE    bp, bp, tp
        LDREQ    bp, hpdbase

; bp is potential following block
        CMP      HpTemp, bp
        BNE      try_preceding_block

; now get size available, see if fits

        LDR      HpTemp, hpdbase
        CMP      bp, HpTemp
        ADDNE    HpTemp, bp, hpd
        LDRNE    HpTemp, [HpTemp, #fresize]
        LDREQ    HpTemp, hpdend
        SUBEQ    HpTemp, HpTemp, bp
        BICEQ    HpTemp, HpTemp, #3
                                           ; force it to a sensible blocksize
        MRS      lr, CPSR                  ; save EQ/NE state

        CMP      HpTemp, size
        BLT      try_add_preceding_block

        ORR      lr, lr, #I32_bit          ; disable IRQs
        MSR      CPSR_cf, lr

 [ debheap
; HpTemp, EQ/NE critical
 Push "HpTemp,lr"
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT02
 STRIM "Extending block into "
02
 Pull "HpTemp,lr"
 msr CPSR_f, lr
 ]

        LDR      work, [addr, hpd]         ; get size back
        ADD      work, work, size          ; new size
        STR      work, [addr, hpd]         ; block updated

; now see which we're extending into
        BNE      IntoFreeEntry

 [ debheap
 Push HpTemp
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT03
 WRLN "base-end area"
03
 Pull HpTemp
 ]
        ADD      work, work, addr
        STR      work, hpdbase
        B        GoodExtension

IntoFreeEntry

 [ debheap
 Push HpTemp
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT04
 WRLN "free entry"
04
 Pull HpTemp
 ]

        SUB      HpTemp, HpTemp, size      ; new freblk size
        CMP      HpTemp, #4
        BGT      SplitFreeBlockForExtend

; Not enough space for a free block. Increase the grow amount a bit.
        ADDEQ    work, work, #4
        STREQ    work, [addr, hpd]

; free entry just right size : remove from free list
        LDR      HpTemp, [bp, hpd]         ; free link
        CMP      HpTemp, #Nil
        ADDNE    HpTemp, HpTemp, bp        ; offset from heap start
        SUBNE    HpTemp, HpTemp, tp
        STR      HpTemp, [tp, hpd]         ; free list updated
        B        GoodExtension

SplitFreeBlockForExtend
        LDR      work, [tp, hpd]
        ADD      work, work, size
        STR      work, [tp, hpd]           ; prevnode points at right place
        ADD      work, work, tp            ; offset of new free entry
        ADD      work, work, hpd
        STR      HpTemp, [work, #fresize]
        LDR      HpTemp, [bp, hpd]
        CMP      HpTemp, #Nil
        SUBNE    HpTemp, HpTemp, size      ; reduced offset for free link
        STR      HpTemp, [work, #frelink]
        B        GoodExtension

try_preceding_block
; TMD 01-Mar-89: FindHeapBlock now never returns tp=Nil, only tp=hpdfree,
; so no need for check
        CMP      tp, #:INDEX: hpdfree  ; no real preceder?
        BEQ      got_to_reallocate
        ADD      bp, tp, hpd
        LDR      bp, [bp, #fresize]
        ADD      bp, bp, tp            ; end of preceding block
        CMP      addr, bp
        BNE      got_to_reallocate

; now get size available, see if fits

        SUB      bp, bp, tp           ; freblk size
        SUBS     bp, bp, size         ; compare, find free size left
        BLT      got_to_reallocate

 [ debheap
 Push "HpTemp,lr"
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT10
 CMP bp, #0
 BEQ %FT11
 STRIM "Extending block into previous free"
 B   %FT12
11
 STRIM "Previous free perfect fit"
12
 SWI XOS_NewLine
10
 Pull "HpTemp,lr"
 ]

        WritePSRc SVC_mode+I_bit, HpTemp   ; IRQs off

hack_preceder
; bp is new size of preceding block
; tp is prevfree offset
; work is prevprevfree offset
; size is amount block grows by
; addr is block offset
        CMP      bp, #freblksize
        ADDGE    HpTemp, tp, hpd
        STRGE    bp, [HpTemp, #fresize]    ; prevblock shrunk
        BGE      copy_backwards

 ; free freblk: work is still prevprevblk pointer
        LDR      HpTemp, [tp, hpd]
        ADDNE    size, size, bp            ; Increase grow amount by any remainder
        MOVNE    bp, #0                    ; And make sure the block does die
        CMP      HpTemp, #Nil
        ADDNE    HpTemp, HpTemp, tp        ; offset from heap start
        SUBNE    HpTemp, HpTemp, work
        STR      HpTemp, [work, hpd]       ; free list updated

copy_backwards
        ADD      bp, bp, tp
        LDR      HpTemp, [addr, hpd]!      ; current block size
        ADD      size, HpTemp, size
        STR      size, [bp, hpd]!          ; update blocksize

 [ debheap
 Push r0
 LDR r0, hpddebug
 CMP r0, #0
 BEQ %FT06
 DREG HpTemp, "copying -4+",cc
 STRIM " from "
 SUB  R0, addr, hpd
 BL   PrintOffset
 STRIM " to "
 SUB  R0, bp, hpd
 BL   PrintOffsetLine
06
 Pull r0
 ]

; TMD 02-Mar-89: We've finished messing about with the heap structure
; so we can branch outside danger zone and restore IRQ status while doing copy
        B       CopyBackwardsInSafeZone

try_add_preceding_block
    [ {TRUE}
; HpTemp is size of following block
        CMP      tp, #:INDEX: hpdfree  ; no real preceder?
        BEQ      got_to_reallocate
        Push    "work, size"           ; need prevprevblk ptr
        SUB      size, size, HpTemp    ; size still needed
        ADD      HpTemp, tp, hpd
        LDR      HpTemp, [HpTemp, #fresize]
        ADD      HpTemp, HpTemp, tp        ; end of preceding block
        CMP      addr, HpTemp
        BNE      got_to_reallocate2

; now get size available, see if fits

        SUB      HpTemp, HpTemp, tp    ; freblk size
        SUBS     HpTemp, HpTemp, size
        BLT      got_to_reallocate2

 [ debheap
 Push "HpTemp,lr"
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT10
 Pull HpTemp
 CMP HpTemp, #0
 BEQ %FT11
 STRIM "Extending block into previous free and block after"
 B   %FT12
11
 STRIM "Previous free+nextblock perfect fit"
12
 SWI XOS_NewLine
10
 Pull "lr"
 ]

        WritePSRc SVC_mode+I_bit, work ; IRQs off
   ; delink block at bp
        LDR      work, hpdbase
        CMP      bp, work              ; extend into free, or delink block?
        BNE      ext_delink
        LDR      work, hpdend
        SUB      work, work, bp        ; get back real size
        BIC      work, work, #3
        ADD      work, work, bp
        STR      work, hpdbase         ; all free allocated
        B        ext_hack
ext_delink
        LDR      work, [bp, hpd]
        CMP      work, #Nil
        ADDNE    work, work, bp
        SUBNE    work, work, tp
        STR      work, [tp, hpd]       ; block delinked
ext_hack
        MOV      bp, HpTemp
        Pull    "work, size"
; bp is new size of preceding block
; tp is prevfree offset
; work is prevprevfree offset
; size is amount block grows by
; addr is block offset
        B        hack_preceder

got_to_reallocate2
       Pull     "work, size"
  ]
got_to_reallocate
; claim block of new size ; copy data
; Done by recursive SWIs: somewhat inefficient, but simple.

 [ debheap
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT05
 WRLN "reallocating block"
05
 ]

        B       ReallocateInSafeZone

CorruptExtension
        ADRL    R0,ErrorBlock_HeapFail_BadLink
      [ International
        BL      TranslateError
      ]

NaffExtension
        Pull    "addr, size, work"
        B       NaffHeapExit


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ExtendHeap. Top level HeapEntry
; ==========
;
; Extend or shrink heap

; In : hpd -> heap descriptor, size = size to change by

; Out : VClear -> heap size changed OK
;       VSet   -> failed to change by specified amount
;       size = amount changed by

ExtendHeap       ROUT
        ValidateHpd  ExtendHeap

        CMP      r3, #0
        ADDMI    r3, r3, #3          ; round towards 0
        BIC      R3, R3, #3          ; ensure word amount

        LDR      HpTemp, hpdend
        ADD      HpTemp, HpTemp, R3  ; HpTemp := new size
        LDR      tp, hpdbase
        CMP      tp, HpTemp
        BGT      ExtendHeap_badshrink

        WritePSRc SVC_mode+I_bit, lr
        Push    "R0, R1"
        MOV      R0, hpd             ; Ensure heap will be in valid area
        ADD      R1, hpd, HpTemp
        SWI      XOS_ValidateAddress
        Pull    "R0, R1"
        BCS      ExtendHeap_nafforf

 [ DebugHeaps
        CMP     R3, #0                  ; if shrunk or stayed same
        BLE     %FT15                   ; then nothing to do
        ADD     tp, hpd, HpTemp         ; tp -> end of heap
        SUB     bp, tp, R3              ; bp -> start of new bit
        ORR     lr, hpd, #FreeSpaceDebugMask
10
        STR     lr, [tp, #-4]!          ; store word
        TEQ     tp, bp
        BNE     %BT10
15
 ]

        STR      HpTemp, hpdend      ; uppy date him
        B        GoodHeapExit        ; moved all the size asked for

ExtendHeap_badhpd
        ADRL     R0, ErrorBlock_HeapFail_BadDesc
      [ International
        BL       TranslateError
      ]
        MOV      size, #0
        B        NaffHeapExit

ExtendHeap_nafforf
        ADRL     R0, ErrorBlock_HeapFail_BadExtend
      [ International
        BL      TranslateError
      ]
        MOV      size, #0
        B        NaffHeapExit

ExtendHeap_badshrink
        LDR      HpTemp, hpdend
        STR      tp, hpdend          ; update heap
        SUB      size, HpTemp, tp    ; size managed to change by
        ADRL     R0, ErrorBlock_HeapFail_ExcessiveShrink
      [ International
        BL       TranslateError
      ]
        B        NaffHeapExit        ; and sort of fail

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadBlockSize. Top level HeapEntry
; =============
;

ReadBlockSize

        Push    "addr, work"
        BL      FindHeapBlock
        LDRVC   size, [addr, hpd]
        Pull   "addr, work"
        BVC     GoodHeapExit
        B       NaffHeapExit

;**************************************************************************
; Common routines for free/extend

FindHeapBlock   ROUT
; Convert addr to address
; Validate heap
; check block is an allocated block
; return tp = free list entry before the block (hpdfree if none)
;      work = free list before that (if exists)
; corrupts HpTemp, bp

        Push    lr

        ValidateHpd findfailed

        SUB     addr, addr, hpd     ; convert to offset
        SUB     addr, addr, #4      ; real block posn

; Find block in heap by chaining down freelist, stepping through blocks

; TMD 01-Mar-89
; no need to check explicitly for null free list, code drops thru OK

 [ debheap
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT03
 Push lr
 WRLN "Scanning freelist"
 Pull lr
03
 ]

; step down free list to find appropriate chunk
; get tp = free block before addr
; HpTemp =  "     "   after   "
;   work = block before tp

        MOV     tp, #:INDEX: hpdfree
StepDownFreeList
        LDR     HpTemp, [hpd, tp]     ; link offset
        CMP     HpTemp,#Nil
        BEQ     ListEnded             ; EQ state used!
        ADD     HpTemp, HpTemp, tp
        CMP     HpTemp, addr
        MOVLS   work, tp
        MOVLS   tp, HpTemp
        BLS     StepDownFreeList
ListEnded
        LDREQ   HpTemp, hpdbase      ; if EQ from CMP HpTemp, addr
                                     ; then bad block anyway
        CMP     tp, #:INDEX: hpdfree
        MOVEQ   bp, #hpdsize         ; is this a fudge I see before me?
        BEQ     ScanAllocForAddr
        ADD     bp, tp, #fresize
        LDR     bp, [hpd, bp]
        ADD     bp, tp, bp

ScanAllocForAddr
; bp     -> start of allocated chunk
; HpTemp -> end    "   "        "
; scan to find addr, error if no in here

       Push    work       ; keep prevlink ptr

  [ debheap
; HpTemp critical
 Push "HpTemp, R0, link"
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT02
 STRIM "Scan for addr from "
 MOV   R0, bp
 BL    PrintOffset
 STRIM " to "
 LDR   R0,[stack,#4]  ; HpTemp
 BL    PrintOffsetLine
02
 Pull "HpTemp, r0, link"
 ]
        B       CheckForNullAllocn

ScanAllocForAddrLoop
        CMP     bp, addr
        BEQ     ValidBlock
        LDR     work, [bp, hpd]    ; get size
        ADD     bp, bp, work
CheckForNullAllocn
        CMP     bp, HpTemp
        BLT     ScanAllocForAddrLoop

 [ debheap
 Push lr
 STRIM "Given pointer not a block"
 Pull lr
 ]
       ADRL    R0, ErrorBlock_HeapFail_NotABlock
     [ International
       BL      TranslateError
     |
       SETV
     ]
       Pull   "work, pc"

ValidBlock    ; tp = free link offset, addr = block offset
       CLRV
       Pull   "work, pc"

findfailed_badhpd
 [ debheap
 Push   lr
 STRIM "Invalid heap descriptor"
 Pull   lr
 ]
        ADRL    R0, ErrorBlock_HeapFail_BadDesc
      [ International
        BL      TranslateError
      |
        SETV
      ]
        Pull    PC

;****************************************************************************

FreeChunkWithConcatenation ROUT
; in : addr -> block
;      tp   -> preceding free list entry
; out : block freed, concatenated with any free parts on either side,
;       base reduced if can do
; corrupts HpTemp, bp, size, addr

; TMD 01-Mar-89: FindHeapBlock now never returns tp=Nil, only tp=hpdfree,
; so no need for check, code will get there eventually!

; attempt concatenation with free blocks on both/either side
 [ debheap
 Push "R0, lr"
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT04
 STRIM "concatenation attempt with free ptr "
 MOV   R0,tp
 BL    PrintOffsetLine
04
 Pull  "R0, lr"
 ]

 [ DebugHeaps
        ORR     bp, hpd, #FreeSpaceDebugMask
        LDR     size, [addr, hpd]!
        ADD     HpTemp, addr, size
        SUB     HpTemp, HpTemp, #4      ; HpTemp -> last word of block
10
        STR     bp, [HpTemp], #-4       ; store word, then go back
        TEQ     HpTemp, addr            ; loop until done, but don't overwrite size field
        BNE     %BT10                   ; otherwise we might get an IRQ with a duff heap
        SUB     addr, addr, hpd         ; make addr an offset again
 ]

        LDR     size, [addr, hpd]      ; block size
        ADD     bp, size, addr         ; eob offset
        LDR     HpTemp, [tp, hpd]      ; Nil doesn't matter here!
        ADD     HpTemp, HpTemp, tp     ; offset of free block after ours
        CMP     HpTemp, bp             ; if tp was hpdfree then <> bp
        BNE     NoConcatWithNext       ; so will take branch

 [ debheap
 Push lr
 LDR bp, hpddebug
 CMP bp, #0
 BEQ %FT05
 WRLN "concatenating with block after"
05
 Pull lr
 ]
        ADD    bp, hpd, HpTemp
        LDR    bp, [bp, #fresize]
        ADD    bp, bp, size
        WritePSRc SVC_mode+I_bit, size
        STR    bp, [addr, hpd]       ; enlarge our block
        LDR    bp, [HpTemp, hpd]     ; offset in free list
        CMP    bp, #Nil
        ADDNE  bp, HpTemp, bp        ; offset from heap start
        SUBNE  bp, bp, tp            ; free list offset
        STR    bp, [tp, hpd]         ; free list updated, our block bigger
                                     ; - but not in the free list yet!

NoConcatWithNext  ; tp = free link offset, addr = block offset
                  ; now try for concatenation with previous block
        CMP    tp, #:INDEX: hpdfree  ; are we before any real free blocks?
        BEQ    NoConcatenation       ; yup

        ADD    HpTemp, tp, hpd
        LDR    size, [HpTemp, #fresize]
        ADD    bp, size, tp
        CMP    bp, addr
        BNE    NoConcatenation
 [ debheap
 Push lr
 LDR bp, hpddebug
 CMP bp, #0
 BEQ %FT06
 WRLN "concatenating with block before"
 STRIM "prevfree = "
 Push  R0
 MOV   R0, work
 BL    PrintOffsetLine
 Pull  R0
06
 Pull lr
 ]
        LDR    bp, [addr, hpd]         ; get block size
        ADD    size, bp, size          ; new free block size
        WritePSRc SVC_mode+I_bit, bp
        STR    size, [HpTemp, #fresize]
; now check for butts against base : work is still prevnode to tp
        ADD    HpTemp, size, tp
        LDR    bp, hpdbase
        CMP    bp, HpTemp
        BNE    %FT06                 ; all done : exit keeping IRQs off
        SUB    bp, bp, size
        STR    bp, hpdbase           ; step unused bit back
        MOV    bp, #Nil              ; this MUST have been last free block!
        STR    bp, [work, hpd]
06
        CLRV
        MOV    PC, lr                ; Whew!

NoConcatenation ; check if block butts against base
; tp = previous freelink offset
        LDR     size, [addr, hpd]
        ADD     HpTemp, size, addr
        LDR     bp, hpdbase
        CMP     bp, HpTemp
        BNE     AddToFreeList
        SUB     bp, bp, size
        WritePSRc SVC_mode+I_bit, HpTemp
        STR     bp, hpdbase
        CLRV
        MOV     PC, lr

AddToFreeList  ; block at addr, previous free at tp
 [ debheap
 Push "R0, lr"
 LDR HpTemp, hpddebug
 CMP HpTemp, #0
 BEQ %FT07
 STRIM "add to free list : free link "
 MOV   R0,tp
 BL    PrintOffset
 STRIM ", block "
 MOV   R0, addr
 BL    PrintOffsetLine
07
 Pull "R0, lr"
 ]
        LDR    size, [addr, hpd]!
        WritePSRc SVC_mode+I_bit, HpTemp
        STR    size, [addr, #fresize]
        SUB    addr, addr, hpd
        LDR    size, [hpd, tp]      ; prevlink
        CMP    size, #Nil
        SUBNE  size, size, addr
        ADDNE  size, size, tp       ; form offset if not eolist
        STR    size, [addr, hpd]
        SUB    size, addr, tp
        STR    size, [tp, hpd]
        CLRV
        MOV    PC, lr

;*****************************************************************************

 [ debheap
;
; ShowHeap. Top level HeapEntry
; ========
;
; Dump the heap pointed to by hpd

ShowHeap
        Push    link
        BL      iShowHeap       ; Needed to fudge link for SVC mode entry
        Pull    link
        B       GoodHeapExit


iShowHeap ROUT ; Internal entry point for debugging heap

        Push    "r0, hpd, addr, size, work, bp, tp, link"

        ValidateHpd showfailed  ; debugging heaps won't work interruptibly

        LDR     tp, hpdfree
        CMP     tp, #Nil
        ADDNE   tp, tp, #:INDEX: hpdfree
        LDR     bp, hpdbase
        MOV     addr, #hpdsize
        LDR     work, hpdend

        SWI     OS_NewLine              ; Initial blurb about hpd contents
        DREG    hpd, "**** Heap map **** : hpd "
        STRIM   "->  free"
        MOV     r0, tp
        BL      PrintOffset
        STRIM   ", base"
        MOV     r0, bp
        BL      PrintOffsetLine
        STRIM   "-> start"
        MOV     r0, addr
        BL      PrintOffset
        STRIM   ",  end"
        MOV     r0, work
        BL      PrintOffsetLine

        SUB     r0, work, bp            ; hpdend-hpdbase
        DREG    r0,"Bytes free: ",cc, Word
        SUB     r0, bp, addr            ; hpdbase-hpdsize
        DREG    r0,", bytes used: ",, Word
        SWI     XOS_NewLine

        CMP     tp, #Nil                ; No free blocks at all ?
        BNE     %FT10
        WRLN    "No Free Blocks"

        CMP     bp, addr                ; Is a block allocated at all ?
        MOVNE   r0, addr ; hpdsize
        BNE     %FT40
        WRLN    "No Used Blocks"
        B       %FT99


10      CMP     tp, addr ; hpdsize       ; Allocated block below first free ?
        BEQ     %FT15

        MOV     r0, addr ; hpdbase
        BL      HexUsedBlk
        SUB     r0, tp, addr ; hpdfree-hpdsize
        DREG    r0
        SWI     XOS_NewLine

; Main loop chaining up free space list

15      ADD     addr, tp, hpd             ; convert to address
        LDR     size, [addr, #fresize]    ; Size of this block
        LDR     addr, [addr, #frelink]    ; offset to next block

        STRIM   "Free Block "
        MOV     r0, tp
        BL      PrintOffset
        DREG    size, ", size "

        ADD     r0, tp, size ; r0 -> eob. Adjacent free blocks don't exist

        CMP     addr, #Nil ; If last block, then must we see if we're = hpdbase
        BEQ     %FT40

; Used block starts at r0, ends at addr+tp - so size = (addr+tp)-r0

        BL      HexUsedBlk
        SUB     r0, addr, r0  ; addr-r0
        ADD     r0, r0, tp    ; used block size
        DREG    r0
        SWI     XOS_NewLine

        ADD     tp, addr, tp  ; step down free list
        B       %BT15         ; And loop


40      CMP     r0, bp      ; Is there any allocated space after this block ?
        BEQ     %FT99
        BL      HexUsedBlk
        SUB     r0, bp, r0  ; hpdbase-sob
        DREG    r0
        SWI     XOS_NewLine

99
        CLRV
        Pull   "r0, hpd, addr, size, work, bp, tp, pc"


showfailed_badhpd
        WRLN    "Invalid heap descriptor : ShowHeap failed"
        Pull    "r0, hpd, addr, size, work, bp, tp, pc"


HexUsedBlk
        Push   "lr"
        STRIM  "Used Block "
        BL      PrintOffset
        STRIM  ", size"
        Pull   "lr"
        MOV     PC, R14

PrintOffset
        Push   "r0, lr"
        DREG    r0
        CMP     R0, #0
        ADDNE   R0, R0, hpd
        DREG    r0," (",cc
        STRIM   ")"
        Pull   "R0, PC"

PrintOffsetLine
        Push   "lr"
        BL      PrintOffset
        SWI     XOS_NewLine
        Pull   "PC"

 ]

HeapCode_end

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        END
