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
        TTL     > Sources.FSCommon - common routines, heap stuff

; System heap used for: fscb, scb, stream buffers

; RMA used for: transients, copy buffers

 [ debugheapK
; Heap block filled out as:
; <length><check><client junk><check>

        MACRO
        MarkHeapBlockPrep
        ADD     r3, r3, #12+3
        BIC     r3, r3, #3
        MEND

        MACRO
        MarkHeapBlockAlloced $cc
        LDR$cc  lr, HeapChkWrd
        SUB$cc  r3, r3, #4
        STR$cc  lr, [r2, r3]
        STR$cc  r3, [r2], #4
        STR$cc  lr, [r2], #4
        MEND

        MACRO
        CheckHeapBlockFree
        LDR     lr, HeapChkWrd
        LDR     r0, [r2, #-4]!
        TEQ     r0, lr
        BEQ     %FT01
        DLINE   "***** HEAP BLOCK UNDERFLOWED *****"
01
        LDR     r0, [r2, #-4]!
        LDR     r0, [r2, r0]
        TEQ     lr, r0
        BEQ     %FT01
        ADD     r2, r2, #8+8
        DSTRING r2, "***** HEAP BLOCK OVERFLOWED *****"
        SUB     r2, r2, #8+8
01
        MEND

        MACRO
        CheckHeapBlock $rn,$pos
        Push    "r0,r1,lr"
        MOV     r0, $rn
        LDR     lr, HeapChkWrd
        LDR     r1, [r0, #-4]!
        TEQ     r1, r0
        BEQ     %FT01
        DLINE   "***** HEAP BLOCK UNDERFLOWED:$pos *****"
01
        LDR     r1, [r0, #-4]!
        LDR     r1, [r0, r1]
        TEQ     r1, r0
        BEQ     %FT01
        DSTRING "***** HEAP BLOCK OVERFLOWED:$pos *****"
01
        Pull    "r0,r1,lr"
        MEND

        MACRO
        CheckLinkedHeapBlock $rn,$pos
        Push    "r0,r1,lr"
        SUB     r0, $rn, #8
        ADRL    lr, HeapChkWrd
        LDR     lr, [lr]
        LDR     r1, [r0, #-4]!
        TEQ     r1, lr
        BEQ     %FT01
        DLINE   "***** HEAP BLOCK UNDERFLOWED:$pos *****"
01
        LDR     r1, [r0, #-4]!
        LDR     r1, [r0, r1]
        TEQ     r1, lr
        BEQ     %FT01
        ADD     r0, r0, #8+8
        DLINE   "***** HEAP BLOCK OVERFLOWED:$pos *****"
        SUB     r0, r0, #8+8
01
        Pull    "r0,r1,lr"
        MEND

HeapChkWrd DCD &656d7550       ;'Pume'
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                   S Y S   h e a p   m a n a g e m e n t
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SMustGetArea
; ============
;
; Get a new heap block

; In    r3 = size of area to get (should never be 0 !)
;       fp valid (never 0)

; Out   VC: ok, r2 -> block
;       VS: fail, r2 -> Nowt

SMustGetArea Entry "r0"

 [ debugheap
 DREG r3,"SMustGetArea "
 ]
        BL      SGetArea
        EXIT    NE                      ; NE -> block allocated (or error VS)

        STRVC   r0, globalerror         ; fp MUST be valid (will adx if not)
        SETV    VC
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SGetArea
; ========
;
; Get a new heap block, possibly failing because of lack of space

; In    r3 = size of area to get

; Out   VC, NE: ok, r2 -> block
;       VC, EQ: failed to claim block (no room), r2 -> Nowt; errorbuffer valid
;       VS    : bad fail, r2 -> Nowt

SGetArea Entry "r0, r1, r3"

 [ debugheap
        DREG r3,"SGetArea "
 ]
 [ debugheapK
        MarkHeapBlockPrep
 ]

        BL      STrySysHeap
 [ debugheapK
        MarkHeapBlockAlloced NE
 ]
        EXIT    NE                      ; r2 -> block (or VS fail)
        EXIT    VS                      ; VS -> bad fail

heap_magic         * 0
heap_freelist      * 4
heap_highwatermark * 8
heap_end           * 12

        LDR     r1, SysHeapStart
        ADD     r1, r1, #heap_highwatermark
        LDMIA   r1, {r1, r14}
        SUB     r1, r14, r1             ; Amount left at end of heap

        SUB     r1, r3, r1              ; Amount to grow heap by
        ADD     r1, r1, #8              ; Plus enough for housekeeping
        MOV     r0, #0                  ; System heap id
 [ debugheap
 DREG r1,"Doing ChangeDynamicArea(SysHeap) r1 = "
 ]
        SWI     XOS_ChangeDynamicArea
        BVC     %FT90
        CMP     r0, r0                  ; VC, EQ -> alloc failed
        STREQ   r0, [sp, #0*4]
        EXIT


90      BL      STrySysHeap             ; Try again
 [ debugheapK
        MarkHeapBlockAlloced NE
 ]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  [ MercifulToSysHeap
;
;these versions of routines are for initialise of HBlocks only
;

MTSH_SMustGetArea Entry "r0"
        BL      MTSH_SGetArea
        EXIT    NE                      ; NE -> block allocated (or error VS)

;not for this version - fp is NOT valid
;        STRVC   r0, globalerror

        SETV    VC
        EXIT

MTSH_SGetArea Entry "r0, r1, r3"
        BL      MTSH_STrySysHeap
        EXIT    NE                      ; r2 -> block (or VS fail)
        EXIT    VS                      ; VS -> bad fail

        LDR     r1, SysHeapStart
        ADD     r1, r1, #heap_highwatermark
        LDMIA   r1, {r1, r14}
        SUB     r1, r14, r1             ; Amount left at end of heap

        SUB     r1, r3, r1              ; Amount to grow heap by
        ADD     r1, r1, #8              ; Plus enough for housekeeping
        MOV     r0, #0                  ; System heap id
        SWI     XOS_ChangeDynamicArea
        BVC     %FT90
        CMP     r0, r0                  ; VC, EQ -> alloc failed
        STREQ   r0, [sp, #0*4]
        EXIT
90      BL      MTSH_STrySysHeap        ; Try again
        EXIT


MTSH_STrySysHeap Entry "r0, r1, r3"

        MOV     r0, #HeapReason_Get
        LDR     r1, SysHeapStart
        SWI     XOS_Heap                ; Corrupts r3 !
        CMPVC   pc, #0                  ; VC, NE -> ok
        EXIT    VC

;not for this version
;        ADR     r1, fsw_GetArea         ; Always copy into errorbuffer
;        BL      CopyErrorAppendingString

        MOV     r2, #Nowt               ; Give 'Address extinction' if used !

        LDR     r1, [r0]
        LDR     r14, =ErrorNumber_HeapFail_Alloc
        TEQ     r14, r1                 ; We permit this alone to be wrong
                                        ; VS -> bad fail

        SUBEQS  r14, r14, r14           ; SSwales does pervy things again!

;not for this version - fp is NOT valid
;        STREQ   r14, globalerror        ; VC, EQ !!! -> block not allocated

        EXIT

  ] ; MercifultoSysheap

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Primitive allocator for use ONLY by SGetArea

; Out   r2 -> allocated core if successful

STrySysHeap Entry "r0, r1, r3"

 [ debugheap
 DREG r3,"STrySysHeap ",cc
 ]

  [ MercifulToSysHeap

    [ MercifulTracing
        LDR     r1,NHB_total
        ADD     r1,r1,#1
        STR     r1,NHB_total
    ]

        LDR     r0,HBlocks_Valid
        CMP     r0,#0
        BEQ     %FT95
        MOV     r1,r3
        CMP     r1,#32
        BLS     %FT10
        CMP     r1,#64
        BLS     %FT20
        CMP     r1,#128
        BLS     %FT30
        CMP     r1,#1040
        BHI     %FT90
;try 1040
        LDR     r3,HBlockArray_1040
        BL      ClaimHBlock
        BVC     %FT80
        BVS     %FT90
;try 32
10      LDR     r3,HBlockArray_32
        BL      ClaimHBlock
        BVC     %FT80
        BVS     %FT90
;try 64
20      LDR     r3,HBlockArray_64
        BL      ClaimHBlock
        BVC     %FT80
        BVS     %FT90
;try 128
30      LDR     r3,HBlockArray_128
        BL      ClaimHBlock
        BVC     %FT80
; go to SysHeap for new block as last resort
90
    [ MercifulTracing
        LDR     r0,NHB_fail
        ADD     r0,r0,#1
        STR     r0,NHB_fail
        LDR     r0,HB_failmax
        CMP     r1,r0
        STRHI   r1,HB_failmax
    ]
        MOV     r3,r1
95
  ] ;MercifulToSysHeap

        MOV     r0, #HeapReason_Get
        LDR     r1, SysHeapStart
        SWI     XOS_Heap                ; Corrupts r3 !
 [ debugheap
 BVS %FT00
 DREG r2,"; returns "
00
 ]

80
        CMPVC   pc, #0                  ; VC, NE -> ok
        EXIT    VC

        ADR     r1, fsw_GetArea         ; Always copy into errorbuffer
        BL      CopyErrorAppendingString

        MOV     r2, #Nowt               ; Give 'Address extinction' if used !

        LDR     r1, [r0]
        LDR     r14, =ErrorNumber_HeapFail_Alloc
        TEQ     r14, r1                 ; We permit this alone to be wrong
                                        ; VS -> bad fail

        SUBEQS  r14, r14, r14           ; SSwales does pervy things again!
        STREQ   r14, globalerror        ; VC, EQ !!! -> block not allocated
        EXIT                            ; Again fp MUST be valid (adx if not)


fsw_GetArea
        DCB     "FSGAEr", 0  ; ": FileSwitch GetArea", 0
        ALIGN
        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SFreeArea
; =========
;
; Free an old heap block in either the system heap or RMA. Accumulate V

; In    r2 -> block to free. If r2 = 0 or Nowt then don't try to free anything

; Out   VC: r2 = Nowt, block freed
;       VS: r2 = Nowt, fail or VSet on entry

SFreeArea EntryS "r0, r1"

 [ debugheap
        DREG r2,"SFreeArea "
 ]
        CMP     r2, #0                  ; Must cope with 0 for non-existent
        CMPNE   r2, #Nowt               ; And Nowt -> nothing there. VC
        EXITS   EQ                      ; Restore caller V

 [ debugheapK
        CheckHeapBlockFree
 ]

        LDR     r1, SysHeapStart
        CMP     r1, r2                  ; if before start, then must be in RMA
        BHI     %FT50
        LDR     r0, [r1, #heap_end]     ; r0 = size of heap
        ADD     r0, r0, r1              ; r0 -> end of heap +1
        CMP     r2, r0                  ; if past end, then must be in RMA
        BCS     %FT50

  [ MercifulToSysHeap
        LDR     r1,HBlocks_Valid
        CMP     r1,#0
        BEQ     %FT25
        LDR     r1,HBlockArray_32
        BL      FreeHBlock
        BVC     %FT30
        LDR     r1,HBlockArray_64
        BL      FreeHBlock
        BVC     %FT30
        LDR     r1,HBlockArray_128
        BL      FreeHBlock
        BVC     %FT30
        LDR     r1,HBlockArray_1040
        BL      FreeHBlock
        BVC     %FT30
;free block to heap
25
        LDR     r1,SysHeapStart
  ] ;MercifulToSysHeap

        MOV     r0, #HeapReason_Free
        SWI     XOS_Heap

30      ADRVS   r1, %FT80               ; No distinction between heaps anymore
        MOV     r2, #Nowt               ; Ensure we don't use it again anyhow
        EXITS   VC                      ; Restore caller V

        BL      CopyErrorAppendingString
        EXIT


50      MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        B       %BT30

80
        DCB     "FSFAEr", 0  ; ": FileSwitch FreeArea", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SNewArea
; ========
;
; Free an old heap block and get a new one

; In    r0 -> address of pointer to block to free
;       r3 = size of block to get

; Out   VC: block freed and new one obtained; pointer to block updated
;       VS: fail

SNewArea Entry "r0, r2"

 [ debugheap
 DREG r3,"SNewArea "
 ]
        LDR     r2, [r0]                ; Address of block to free
        BL      SFreeArea
        BLVC    SMustGetArea            ; Get new block only if freed
        MOVVS   r2, #Nowt               ; Nowt pointer if either failed
        STR     r2, [r0]                ; Update block address in any case
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SNewString
; ==========
;
; Free an old string and copy a new one into some new workspace

; In    r0 -> address of pointer to block
;       r1 -> string (CtrlChar terminated) or 0

; Out   r1 -> Heap block, with string copied into it, or 0
;       pointer to block updated accordingly

SNewString Entry "r2, r3"

 [ debugheap
 DSTRING r1,"SNewString ",cc
 DREG r0," var "
 ]
        CMP     r1, #0
        BEQ     %FT50

        BL      strlen                  ; How big is the source name ?
        ADD     r3, r3, #1              ; +1 for terminating 0
        BL      SNewArea
        MOVVC   r2, r1                  ; src^
        LDRVC   r1, [r0]                ; New dest block
        BLVC    strcpy
 [ debugheap
 DREG r1,"SNewString returns "
 ]
        EXIT

50      LDR     r2, [r0]                ; Just free the existing string
        BL      SFreeArea
 [ debugheap
 DREG r1,"SNewString returns "
 ]
        STRVC   r1, [r0]                ; Make this 0 in case we look it up
        EXIT                            ; r1 still 0

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                L i n k e d   a r e a   m a n a g e m e n t
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

          ^     0
la_link   #     4
la_domain #     4       ; DomainId when resource allocated
la_hsize  #     0

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SGetLinkedArea
; ==============
;
; Claim a new heap block and add it to the global list

; In    r0 -> address of pointer to block
;       r3 = size of block to get

; Out   VC: r2 = !r0 -> new block obtained (past the link)
;       VS: fail

SGetLinkedArea Entry "r0, r3"

 [ debugheap
 DREG r0,"SGetLinkedArea: var ",cc
 DREG r3,", size "
 ]
        ADD     r3, r3, #la_hsize       ; extra info
        BL      SMustGetArea            ; Get new block

50      LDRVC   r3, LinkedAreas         ; Push old block^ in new block
        STRVC   r3, [r2, #la_link]
        STRVC   r2, LinkedAreas         ; Add new block to head of chain

        LDRVC   r3, ptr_DomainId
        LDRVC   r3, [r3]                ; Remember domain id where allocated
        STRVC   r3, [r2, #la_domain]

        ADDVC   r2, r2, #la_hsize       ; Caller gets this r2
        STRVC   r2, [r0]                ; Update block^ in local frame
 [ debugheap
 EXIT VS
 DREG r2,"SGetLinkedArea returns ",cc
 DREG r0," to var "
 ]
        EXIT

; .............................................................................

SGetLinkedTransientArea ALTENTRY

 [ debugheap
 DREG r3,"SGetLinkedTransientArea: size "
 ]
        ADD     r3, r3, #la_hsize       ; extra info
        BL      SGetRMA
        EXIT    EQ                      ; EQ -> failed to get block (or VS err)

        ADRVC   r0, TransientBlock
        B       %BT50

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SGetLinkedString
; ================
;
; Claim a new heap block for string, add it to the global list
; and stuff the string in too

; In    r0 -> address of pointer to block
;       r1 -> string to copy; CtrlChar terminator

; Out   VC: r1 -> new block obtained
;       VS: fail

SGetLinkedString Entry "r0, r2-r4"

        TEQ     r1, #NULL
        TEQNE   r1, #Nowt
        MOVEQ   r14, #NULL
        STREQ   r14, [r0]
        EXIT    EQ

        MOV     r4, #space-1

05      BL      strlenTS                ; ep for below
        ADD     r3, r3, #1              ; +1 for terminator

 [ debugheap
 DREG r0,"SGetLinkedString: var ",cc
 DREG r3,", size ",cc
 DSTRING r1,", string "
 ]
        BL      SGetLinkedArea          ; r2 := new block^, r0 = caller's var^
        EXIT    VS

        Swap    r1, r2                  ; Copy string into new block,
        BL      strcpyTS                ; exchanging caller's^ to the copy
 [ debugheap
 DREG r1,"SGetLinkedString returns "
 ]
        EXIT

; .............................................................................

SGetLinkedString_excludingspaces ALTENTRY

        MOV     r4, #space
        B       %BT05

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SNewLinkedString
; ================
;
; Replace an old linked string with a new one
;
; In    r0 -> address of pointer to block
;       r1 -> string to copy
;
; Out   VC: r1 -> new block obtained
;       VS: fail
;

SNewLinkedString Entry
        BL      SFreeLinkedString
        BLVC    SGetLinkedString
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SFreeLinkedArea
; ===============
;
; Free the given heap block; remove from global list. Accumulates V

; In the normal course of alloc/dealloc we add to and free from the head of
; the chain, so this new method doesn't incur any nasty overhead really, guv.

; As system heap block addresses are unique throughout the machine, there is
; no need to check domain id for explicit single deallocate.

; In    r0 -> address of pointer to block

; Out   VC: block freed
;       VS: failed to free block, or V set initially

SFreeLinkedArea EntryS "r0, r2"

        LDR     r2, [r0]                ; Get this block^
        SUB     r2, r2, #la_hsize       ; Get real memory^
 [ debugheap
 DREG r0,"SFreeLinkedArea: var "
 DREG r2,"Block to free is "
 ]
        ADR     r0, LinkedAreas - la_link

10      LDR     r14, [r0, #la_link]     ; Is this a pointer to the block we
                                        ; want to free ?
 [ debugheap
 DREG r14, "Trying against block at "
 ]
 [ paranoid
 CMP r14, #Nowt
 BNE %FT01
 ADR r0, %FT90
 BL CopyError
 EXIT
90
 DCD 0
 DCB "Linked area underflow !", 0
 ALIGN
01
 ]
        CMP     r14, #Nowt              ; End of list without finding it ?
        BEQ     %FT50                   ; [really bad stuff]

        CMP     r14, r2
        MOVNE   r0, r14
        BNE     %BT10                   ; Loop till we find it

        LDR     r14, [r2, #la_link]     ; Store block pointer in previous block
        STR     r14, [r0, #la_link]

50      BL      SFreeArea               ; Free this block

        EXITS   VC                      ; Restore caller V
        EXIT                            ; VSet

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SFreeLinkedString
; =================
;
; As SFreeLinkedArea, but checks for NULL/Nowt first

SFreeLinkedString EntryS
        LDR     r14, [r0]
        TEQ     r14, #NULL
        TEQNE   r14, #Nowt
        BLNE    SFreeLinkedArea
        MOVVC   r14, #NULL
        STRVC   r14, [r0]
        EXITS   VC
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SFreeAllLinkedAreas
; ===================
;
; Free all the linked heap blocks in this domain

; Out   VC: blocks freed
;       VS: failed to free all blocks

SFreeAllLinkedAreas EntryS "r0, r2, r3"

        ADR     r0, LinkedAreas - la_link
        LDR     r3, ptr_DomainId        ; Free blocks allocated in this domain
        LDR     r3, [r3]

10      LDR     r2, [r0, #la_link]
        CMP     r2, #Nowt               ; VClear
        BEQ     %FA90

        LDR     r14, [r2, #la_domain]   ; Is this in the right domain?
        TEQ     r14, r3
        MOVNE   r0, r2
        BNE     %BT10                   ; [nope, try next block]

        LDR     r14, [r2, #la_link]     ; Store block pointer in previous block
        STR     r14, [r0, #la_link]

50      BL      SFreeArea               ; Free this block
        BVC     %BT10                   ; Note that r0 is still the same and
                                        ; has been made good with new link etc.

90      EXITS   VC                      ; Restore caller V
        EXIT                            ; VSet

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SFreeAllLinkedAreasEverywhere
; =============================
;
; Free all the linked heap blocks in all domains. Only done at reset

; Out   VC: blocks freed
;       VS: failed to free all blocks

SFreeAllLinkedAreasEverywhere EntryS "r0, r2"

 [ debugheap
 DLINE "SFreeAllLinkedAreasEverywhere"
 ]

10      LDR     r2, LinkedAreas         ; Get this block^
        CMP     r2, #Nowt               ; End of list reached ?
        EXIT    EQ                      ; VClear

        LDR     r14, [r2, #la_link]     ; Get next block^
        STR     r14, LinkedAreas        ; Remove this block from list

        BL      SFreeArea               ; Free this block
        B       %BT10

; .............................................................................
; In    CommandLine to be thrown away

SFreeCommandLine ALTENTRY

 [ debugheap
 DLINE "Discarding CommandLine"
 ]
        ADR     r0, CommandLine
        BL      SFreeLinkedArea
        EXITS   VC                      ; Restore caller V
        EXIT                            ; VSet

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                   R M A   h e a p   m a n a g e m e n t
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SGetRMA
; =======
;
; Get a new RMA block, possibly failing because of lack of space

; In    r3 = size of area to get

; Out   VC, NE: ok, r2 -> block
;       VC, EQ: failed to claim block (no room), r2 -> Nowt
;       VS    : bad fail, r2 -> Nowt

SGetRMA Entry "r0-r1, r3"

 [ debugheap
        DREG r3,"SGetRMA ",cc
 ]
 [ debugheapK
        MarkHeapBlockPrep
 ]
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
 [ debugheap
        BVS %FT01
        DREG r2,": returns "
01
 ]
 [ debugheapK
        MarkHeapBlockAlloced VC
 ]
        CMPVC   pc, #0                  ; VC, NE -> ok
        EXIT    VC

        MOV     r2, #Nowt               ; Give 'Address extinction' if used !
        LDR     r1, [r0]
        LDR     r14, =ErrorNumber_MHNoRoom ; We permit this alone to be wrong
        CMP     r14, r1                 ; VC, EQ if so
        ADRNE   r1, %FT90
        BLNE    CopyErrorAppendingString ; VSet
 [ debugheap
 BVS %FT01
 DLINE ": claim failed"
01
 ]
        EXIT
90
        DCB     "FSGREr", 0  ; ": FileSwitch GetRMA", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                      C o m m o n   r o u t i n e s
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strlen, strlenTS
; ================
;
; Find the length of a string (exclusive of terminator, so can't HeapGet (0))

; In    r1 -> CtrlChar(/r4) terminated string

; Out   r3 = number of chars (can be used as size for Heap)

strlen EntryS "r0, r4"

        MOV     r4, #space-1

05      MOV     r3, #0                  ; ep for below

10      LDRB    r0, [r1, r3]
        CMP     r0, #delete             ; Order, you git! EQ -> ~HI
        CMPNE   r0, r4                  ; Any char <= r4 is a terminator
        ADDHI   r3, r3, #1
        BHI     %BT10
        EXITS

; .............................................................................

strlenTS ALTENTRY

        B       %BT05

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strlen_accumulate, strlenTS_accumulate
; ======================================
;
; Find the length of a string (exclusive of terminator, so can't HeapGet (0))

; In    r1 -> CtrlChar(/r4) terminated string
;       r3 = value to accumulate onto

; Out   r3 += number of chars (can be used as size for Heap)

strlen_accumulate EntryS "r0, r1"

        MOV     r14, #space-1

10      LDRB    r0, [r1], #1
        CMP     r0, #delete             ; Order, you git! EQ -> ~HI
        CMPNE   r0, r14                 ; Any char <= r14 is a terminator
        ADDHI   r3, r3, #1
        BHI     %BT10
        EXITS

; .............................................................................

  [ False
strlenTS_accumulate ALTENTRY

        B       %BT10
  ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strcat, strcatTS
; ================
;
; Concatenate two strings

; In    r1, r2 -> CtrlChar(/r4) terminated strings

; Out   new string in r1 = "r1" :CC: "r2" :CC: 0

strcat EntryS "r1, r2, r4"

        MOV     r4, #space-1

05      LDRB    r14, [r1], #1           ; Find where to stick the appendage
        CMP     r14, #delete            ; Order, you git! EQ -> ~HI
        CMPNE   r14, r4                 ; Any char <= r4 is a terminator
        BHI     %BT05
        SUB     r1, r1, #1              ; Point back to the term char

10      LDRB    r14, [r2], #1           ; Copy from *r2++
        CMP     r14, #delete            ; Order, you git! EQ -> ~HI
        CMPNE   r14, r4                 ; Any char <= r4 is a terminator
        MOVLS   r14, #0                 ; Terminate dst with 0
        STRB    r14, [r1], #1           ; Copy to *r1++
        BHI     %BT10

        EXITS

; ............................................................................

strcatTS ALTENTRY

        B       %BT05

; .............................................................................
;
; strcpy, strcpyTS
; ================
;
; Copy a string and terminate with 0

; In    r1 -> dest area
;       r2 -> CtrlChar(/r4) terminated src string

strcpy ALTENTRY

        MOV     r4, #space-1
        B       %BT10

; .............................................................................

strcpyTS ALTENTRY ; Match with strcatTS !!!

        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strcat_advance, strcatTS_advance
; ================================
;
; Concatenate two strings

; In    r1, r2 -> CtrlChar(/r4) terminated strings

; Out   new string in r1 = "r1" :CC: "r2" :CC: 0
;
; r1 advanced to end of new string (points at the terminator).

strcat_advance EntryS "r2, r4"

        MOV     r4, #space-1

05      LDRB    r14, [r1], #1           ; Find where to stick the appendage
        CMP     r14, #delete            ; Order, you git! EQ -> ~HI
        CMPNE   r14, r4                 ; Any char <= r4 is a terminator
        BHI     %BT05
        SUB     r1, r1, #1              ; Point back to the term char

10      LDRB    r14, [r2], #1           ; Copy from *r2++
        CMP     r14, #delete            ; Order, you git! EQ -> ~HI
        CMPNE   r14, r4                 ; Any char <= r4 is a terminator
        MOVLS   r14, #0                 ; Terminate dst with 0
        STRB    r14, [r1], #1           ; Copy to *r1++
        BHI     %BT10

        SUB     r1, r1, #1              ; Move back to terminator

        EXITS

; ............................................................................

  [ False
strcatTS_advance ALTENTRY

        B       %BT05
  ]

; .............................................................................
;
; strcpy_advance, strcpyTS_advance
; ================================
;
; Copy a string and terminate with 0

; In    r1 -> dest area
;       r2 -> CtrlChar(/r4) terminated src string

strcpy_advance ALTENTRY

        MOV     r4, #space-1
        B       %BT10

; .............................................................................

strcpyTS_advance ALTENTRY ; Match with strcatTS_advance !!!

        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strchr
; ======
;
; Finds the first occurence of a character in a string (excl. terminator)

; In    r0  = character
;       r1 -> string, CtrlChar

; Out   EQ: r1 -> character (found)
;       NE: r1 = 0 (not found)

strchr Entry

10      LDRB    r14, [r1], #1
        TEQ     r0, r14
        SUBEQ   r1, r1, #1
        EXIT    EQ
        CMP     r14, #delete            ; Order, you git !
        CMPNE   r14, #space-1
        BHI     %BT10

        MOV     r1, #0
 [ No26bitCode
        CMP     pc, #0                  ; NE
        EXIT
 |
        PullEnv
        BICS    pc, lr, #Z_bit          ; NE
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strcmp
; ======
;
; Compares two strings (case insensitive)

; In    r1 -> string, CtrlChar (Nowt==NULL)
;       r2 -> string, CtrlChar (Nowt==NULL)

; Out   EQ/NE as appropriate

strcmp Entry "r1-r4"

        TEQ     r1, #Nowt
        MOVEQ   r1, #0
        TEQ     r2, #Nowt
        MOVEQ   r2, #0
        ORRS    r14, r1, r2
        EXIT    EQ                      ; Both NULL
        Internat_CaseConvertLoad r14,Lower
        TST     r1, r2
        BNE     %FT10                   ; Both non-NULL
        MOVS    r1, #1                  ; NE as one is NULL and the other isn't
        EXIT

10      LDRB    r3, [r1], #1
        LDRB    r4, [r2], #1
        Internat_LowerCase r3, r14
        CMP     r3, #delete             ; Order, you git !
        CMPNE   r3, #space-1            ; Finished ?
        MOVLS   r3, #0
        Internat_LowerCase r4, r14
        CMP     r4, #delete             ; Order, you git !
        CMPNE   r4, #space-1            ; Finished ?
        MOVLS   r4, #0
        CMP     r3, r4                  ; Differ ?
        EXIT    NE

        CMP     r3, #0
        BNE     %BT10
        MOVS    r3, #0                  ; EQ
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strncmp
; =======
;
; Compares two strings (case insensitive) with length limit

; In    r1 -> string, CtrlChar
;       r2 -> string, CtrlChar
;       r3 = length

; Out   EQ/NE as appropriate

strncmp Entry "r1-r5"
        Internat_CaseConvertLoad r14,Lower

10      CMP     r3, #0
        EXIT    EQ                      ; same up to required length ?
        SUB     r3, r3, #1

        LDRB    r4, [r1], #1
        Internat_LowerCase r4, r14
        CMP     r4, #delete             ; Order, you git !
        CMPNE   r4, #space-1            ; Finished ?
        MOVLS   r4, #0

        LDRB    r5, [r2], #1
        Internat_LowerCase r5, r14
        CMP     r5, #delete             ; Order, you git !
        CMPNE   r5, #space-1            ; Finished ?
        MOVLS   r5, #0

        CMP     r4, r5                  ; Differ ?
        EXIT    NE

        CMP     r4, #0                  ; Both ended together ?
        BNE     %BT10                   ; [no, more chars to come]
        EXIT                            ; EQ

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; WildMatch
;
; In :
;       r1 = pointer to name to match (terminated by 0)
;       r2 = pointer to wildcard string (terminated by any char <= " ")
;               Wildcards are * (0 or more any) and # (one any)
;
; Out: EQ/NE for match (EQ if matches)

WildMatch Entry "r1-r4,r10,r11"

 [ debugname :LOR: debugdaftgbpb
 DSTRING r2,"WildMatch: trying to match ",cc
 DSTRING r1," against "
 ]

        Internat_CaseConvertLoad lr,Upper

        MOV     r11, #0         ; this is the wild backtrack pointer - initialised to 0 to
                                ; indicate no wild encountered yet
        ; r10 is the name wild backtrack pointer

01
        LDRB    r3, [r2], #1    ; nextwild
        TEQ     r3, #"*"
        BEQ     %FT02           ; IF nextwild = "*"

        LDRB    r4, [r1],#1     ; nextname
        TEQ     r4, #0
        BEQ     %FT03

        Internat_UpperCase r3, lr
        Internat_UpperCase r4, lr

        TEQ     r3, r4          ; IF nextwild=nextname
        TEQNE   r3, #"#"        ;   OR nextwild = #  (terminator checked already)
        BEQ     %BT01           ; THEN LOOP (stepped already)

        MOV     r1, r10         ; if * had at all
        MOVS    r2, r11         ; try backtrack
        BNE     %FT02

        CMP     PC, #0          ; set NE
04
        EXIT                    ; return NE (failed)

03
        ; Name terminated - has the wildcard done so too?
        CMP     r3, #" "
        TEQLS   r1, r1          ; set EQ in LS case - HI implies NE
        EXIT

02
        ; Come across a '*' char - find first non-'*' after it
        ; OR
        ; Found a mismatch after an active backtrack - re-read wild char backtrack

        ; Find first non-'*'
        LDRB   r3, [r2], #1     ; step wild
        CMP    r3, #"*"
        BEQ    %BT02            ; fujj **

        SUB    r11, r2, #1      ; wild backtrack ptr is char after *

        Internat_UpperCase r3, lr

05
        LDRB   r4, [r1], #1     ; step name
        TEQ    r4, #0           ; terminator?
        BEQ    %BT03
        Internat_UpperCase r4, lr
        TEQ    r3, r4
        TEQNE  r3, #"#"         ; match if #
        BNE    %BT05

        MOV    r10, r1          ; name backtrack ptr is char after match
        B      %BT01            ; LOOP

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; IsAChild
;
; In
; r1 -> parent (\0-terminated)
; r2 -> potential child (\0-terminated)

; Out
; EQ - yes, it's a child and r2 -> 1st char beyond match
; NE - no, it isn't and r2 -> 1st mismatch char

IsAChild_advance Entry "r0,r1,r3"
        Internat_CaseConvertLoad r14,Lower
30
        LDRB    r0, [r2], #1
        Internat_LowerCase r0, r14
        LDRB    r3, [r1], #1
        Internat_LowerCase r3, r14
        CMP     r3, #delete             ; Order, you git !
        CMPNE   r3, #space-1            ; Finished ?
        BLS     %FT40           ; prefix finished first
        CMP     r0, r3
        BEQ     %BT30           ; match and prefix not finished yet

        ; mismatch and prefix not finished
        SUB     r2, r2, #1
        EXIT

40
        ; Prefix finished - check which sort position the path finished at
        CMP     r0, #delete             ; Order, you git !
        CMPNE   r0, #space-1            ; Finished ?
        MOVLSS  r0, #0          ; <path> = <prefix>
        TEQNE   r0, #"."        ; <path> = <prefix>.<otherstuff>
        TEQNE   r0, #":"        ; <path> = <prefix>:<otherstuff>
        BLNE    IsAbsolute      ; <path> = <prefix>[@%$&\]<otherstuff>
        SUB     r2, r2, #1
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 -> string

; Out   flags from CMP r0, #space for eol detection

FS_SkipSpaces ROUT

10      LDRB    r0, [r1], #1
        CMP     r0, #space      ; Leave r1 -> ~space
        BEQ     %BT10
        SUB     r1, r1, #1
        MOV     pc, lr          ; r0 = first ~space

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SReadTime
; =========
;
; Read the RealTime into r2, r3 in a form useful for DateStamping

; In    r2 bottom 12 bits contains file type to put into date. Will be masked

; Out   r2,r3 updated, flags preserved

SReadTime EntryS "r0-r1, r4", 8 ; Uses local stack for block

        MOV     r4, #&FF000000          ; Create &FFFFFttt
        ORR     r2, r2, r4, ASR #12     ; Fill bits 31-12 with 1's
                                        ; Put type bits in bottom 12 bits
                                        ; Effectively masked by ORRing with 1's
        MOV     r1, sp
        MOV     r0, #3                  ; New OSWord RC - bought from Tim !
        STRB    r0, [r1]
        MOV     r0, #14
        SWI     XOS_Word                ; ReadTime shouldn't give error

        LDRB    r0, [r1, #4]            ; Top byte of date
        ORR     r2, r0, r2, LSL #8      ; &FFFFFttt -> &FFFtttdd
        LDR     r3, [r1]                ; Low word of date
        EXITS

anull           DCB     0
DotPlingRun     DCB     ".!Run", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SReadVariable
; =============
;
; Read a variable into a buffer with a default string if unset

; In    r0 -> variable name
;       r1 -> buffer
;       r2 =  buffer length
;       r3 -> default string to set in buffer if variable doesn't exist

; Out   VS: failed because buffer overflowed, but variable exists !
;       VC, NE: expanded variable in pathname
;       VC, EQ: variable is not set, null string set in buffer

SReadVariable Entry "r0-r4"

 [ debugpath
 DSTRING r0,"Reading variable ",cc
 DSTRING r3,", default value ",cc
 DREG r1," to buffer ",cc
 DREG r2,", length "
 ]
        SUB     r2, r2, #1      ; to leave room for our terminator
        MOV     r3, #0          ; We know what the name is
        MOV     r4, #VarType_Expanded ; Expand macros in variable
        SWI     XOS_ReadVarVal
        MOV     r3, #0          ; Terminate string in buffer
        MOVVS   r2, #0          ; Expansion forced to null on all errors
        STRB    r3, [r1, r2]
 [ debugpath
 BVS %FT42
 DSTRING r1,"Variable expands to "
42
 ]
        CMPVC   pc, #0          ; NE, VClear
        EXIT    VC


; See if variable was unset

50      LDR     r14, [r0]
        CMP     r14, #ErrorNumber_VarCantFind
        BLNE    CopyErrorExternal ; Otherwise tell us about it
        EXIT    VS

        LDR     r2, [sp, #4*3]  ; Copy default string into buffer
        BL      strcpy
 [ debugpath
        DLINE   "Variable not found, default used"
 ]
        EXIT                    ; VClear from CMP

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 -> path variable name
;       r3 -> default string

; Out   VC: r1 -> path string in stack
;           r2 = sp adjust needed after use
;       VS: fail, r2 = sp adjust needed

SReadVariableToBuffer Entry "r0,r1,r3,r4,r5"

        ; Remember where the stack was to start with
        ADD     r5, sp, #6*4
 [ debugsysvars
        DREG    r5, "Stack in is "
 ]

        ; Check for existance before we start
        MOV     r2, #-1
        MOV     r3, #0
        MOV     r4, #0
        SWI     XOS_ReadVarVal
        BVC     %FT50                   ; Unlikely, but possible
        LDR     r1, [r0]
        TEQ     r1, #ErrorNumber_VarCantFind
        BEQ     %FT10
        TEQ     r1, #ErrorNumber_BuffOverflow
        BEQ     %FT50

        ; Not an expected error - return it
        BL      CopyErrorExternal
        EXIT
10
        CLRV
        ; variable not found - use substitute string instead
        LDR     r1, [sp, #2*4]
        BL      strlen
        ADD     r3, r3, #1+3            ; 1 for \0, and 3 for rounding up
        BIC     r3, r3, #3
        SUB     sp, sp, r3
        MOV     r2, r1
        MOV     r1, sp
        BL      strcpy

        ;amg bugfix MED-01953 - update the returned R1 in this case too
        STR     sp, [r5, #-5*4]

        B       %FT90

50
        CLRV
        ; Generate the string "<variable>" on the stack
        LDR     r1, [sp, #0*4]
        MOV     r4, #space
        BL      strlenTS
        ADD     r3, r3, #1+1+1+3        ; 1 for <, 1 for >, 1 for \0 and 3 for rounding up
        BIC     r3, r3, #3
        SUB     sp, sp, r3
        MOV     r2, r1
        MOV     r1, sp
        MOV     lr, #"<"
        STRB    lr, [r1], #1
        BL      strcpyTS_advance
        MOV     lr, #">"
        STRB    lr, [r1], #1
        MOV     lr, #0
        STRB    lr, [r1]

        ; r3 -> place to stick characters on the stack
        MOV     r3, sp
        ; r4 -> beginning of string
        SUB     r4, sp, #1

        ; Copy the string backwards onto the stack
        ; Do it this way so only the amount of stack needed is allocated.
        MOV     r0, sp
 [ debugsysvars
        DSTRING r0,"About to GSTrans "
 ]
        MOV     r2, #1:SHL:31           ; don't strip quotes
        SWI     XOS_GSInit
        BVS     %FT90
60
        ; Ensure the stack pointer covers the variable
        CMP     r3, sp
        SUBLS   sp, sp, #4

        ; Pick up the next byte
        SWI     XOS_GSRead
        BVS     %FT90
        STRB    r1, [r3, #-1]!
 [ debugsysvars
        BREG    r1,",",cc
 ]
        BCC     %BT60
 [ debugsysvars
        DLINE   "..all done"
        DREG    r3, "r3 is now "
        DREG    r4, "r4 is now "
 ]

        ; Ensure the variable is terminated
        CMP     r3, sp
        SUBLS   sp, sp, #4
        MOV     r1, #0
        STRB    r1, [r3, #-1]!

        ; reverse the string
        MOV     r3, sp
        B       %FT80
70
        LDRB    r0, [r3]
        LDRB    lr, [r4]
        STRB    r0, [r4], #-1
        STRB    lr, [r3], #1
80
        CMP     r3, r4
        BLO     %BT70

 [ debugsysvars
        DLINE   "..all done"
 ]
        CLRV
        STR     sp, [r5, #-5*4]
 [ debugsysvars
        MOV     r0, sp
        DSTRING r0, "Result is ",cc
        DREG    r0, " at "
 ]
90
        ; exit sequence
        BLVS    CopyErrorExternal
        SUB     r2, r5, sp
 [ debugsysvars
        DREG    r2, "Stack adjust is "
 ]
        LDMDB   r5, {$Proc_RegList, pc}


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SSetVariable
;
; In    r0 = variable name^
;       r1 = variable value^
;       r4 = Variable type to set
;
SSetVariable Entry "r1-r6"
        MOV     r6, #NULL

        TEQ     r1, #Nowt
        TEQNE   r1, #NULL
        MOVNE   r2, #0
        MOVEQ   r2, #-1         ; Destroy if valptr is NULL or Nowt
        BEQ     %FT10

        ; CR terminate the string (Gak!)
        BL      strlen
        ADD     r6, r1, r3
        LDRB    r5, [r6]

        ; Don't reterminate already CR-terminated strings (they're probably in ROM!)
        TEQ     r5, #CR
        MOVEQ   r6, #NULL
        MOVNE   r14, #CR
        STRNEB  r14, [r6]

10
        MOV     r3, #0
        SWI     XOS_SetVarVal

        ; Restore the old terminator if pointer to it isn't NULL, indicating no initial change
        TEQ     r6, #NULL
        STRNEB  r5, [r6]

        ; Catch removal of non-existant variables errors
        LDRVS   r14, [r0]
        TEQ     r14, #ErrorNumber_VarCantFind
        CLRV    EQ

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SSetVariableIfMissing
;
; In    r0 = variable name^
;       r1 = variable value^
;       r4 = Variable type to set
;
SSetVariableIfMissing Entry "r0-r4"
        ; Test the variable exists, or not
        MOV     r1, #Nowt       ; To ensure address extinction, just in case
        MOV     r2, #-1
        MOV     r3, #0
        MOV     r4, #VarType_String
        SWI     XOS_ReadVarVal
        CLRV
        MOVS    r2, r2
        LDMPLIA sp, {r0-r4}
        BLPL    SSetVariable
        STRVS   r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ValidateR2R5_ReadFromCore
; =========================
;
; Check whether we can read from memory

; In    r2 -> start of block
;       r5 -> end of block

ValidateR2R5_ReadFromCore Entry "r0, r1"

 [ debugosfile
 DREG r2, "Validate for read from core: ",cc
 DREG r5
 ]
        CMP     r5, r2                  ; Prevent 5678 .. 1234 saves etc.
        BMI     %FA40                   ; as Sam doesn't check ordering

        MOV     r0, r2
        MOV     r1, r5
        SWI     XOS_ValidateAddress
        EXIT    CC

        TEQ     pc, pc                  ; 32-bit system?
        BEQ     %FT20

        CMP     r2, #&03800000          ; Is block within ROM area ?
        RSBCSS  r14, r5, #&04000000     ; Rare occurence, so don't put
        EXIT    CS                      ; before ValidateAddress call

40      addr    r0, ErrorBlock_CoreNotReadable
        B       %FT95

20      CMP     r2, #&FC000000          ; Is block within ROM area ?
        SUBCS   r14, r5, r2
        RSBCSS  r14, r14, #OSROM_ImageSize*1024
        EXIT    CS
        B       %BA40

; .............................................................................
;
; ValidateR2R5_WriteToCore
; ========================
;
; Check whether we can write to memory

; In    r2 -> start of block
;       r5 -> end of block

ValidateR2R5_WriteToCore ALTENTRY

 [ debugosfile
 DREG r2, "Validate for write to core: ",cc
 DREG r5
 ]
        CMP     r5, r2                  ; Prevent 5678 .. 1234 loads etc.
        BMI     %FA90                   ; as Sam doesn't check ordering

        MOV     r0, r2
        MOV     r1, r5
        SWI     XOS_ValidateAddress
        EXIT    CC

90      addr    r0, ErrorBlock_CoreNotWriteable

95      BL      CopyError
        EXIT

; .............................................................................
;
; ValidateR2R5_WriteToCoreCodeLoad
; ================================
;
; Check whether we can write to memory for loading an application.
; Works as ValidateR2R5_WriteToCore, but prevents a load which starts
; between &8000 and MemoryLimit and ends after MemoryLimit.

; In    r2 -> start of block
;       r5 -> end of block

ValidateR2R5_WriteToCoreCodeLoad ALTENTRY

        ; Be nice and try and allocate however much memory is needed
        ; First check if R2..R5 fits in application limit
        MOV     r0, #11
        SWI     XWimp_ReadSysInfo
        BVS     %FT96

        ; Start in &8000...ApplicationLimit ?
        CMP     r2, #&8000
        CMPHS   r0, r2
        BLO     %FT96           ; No

        ; Yes, start's in range, is end?
        CMP     r5, r0
        BHI     %BA90           ; No - give error

        ; Good, now check if wimp slot is already big enough
        Push    "r2,r4"
        MVN     r0, #0
        MVN     r1, #0
        SWI     XWimp_SlotSize
        BVS     %FT95
        SUB     r1, r5, #&8000
        CMP     r1, r0
        BLE     %FT95

        ; Attempt resize
        MOV     r0, r1
        MVN     r1, #0
        SWI     XWimp_SlotSize
95
        Pull    "r2,r4"
96
        CLRV
        
        ; Do standard check
        BL      ValidateR2R5_WriteToCore

        ; Read memory limit
        MOVVC   r0, #MemoryLimit
        MOVVC   r1, #0
        SWIVC   XOS_ChangeEnvironment
        EXIT    VS

        ; Start in &8000...MemoryLimit ?
        CMP     r2, #&8000
        CMPHS   r1, r2
 [ No26bitCode
        BLO     %FT97
 |
        EXITS   LO              ; No
 ]

        ; Yes, start's in range, is end?
        CMP     r5, r1
        BHI     %BA90           ; No - give error
 [ No26bitCode
97
        CLRV
        EXIT
 |
        EXITS
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


; .............................................................................
;
; XOS_NewLine_CopyError
; =====================
;
; As XOS_NewLine, except CopyError is performed on error and r0 is always preserved
;
XOS_NewLine_CopyError Entry "r0"
        SWI     XOS_NewLine
        BLVS    CopyErrorExternal
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        LTORG

        END
