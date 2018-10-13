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
        SUBT    > HeapSort

; Old API - same as OS_HeapSort32 but flags in top bits of r1

; Just to make this more confusing, the old API always behaves as if bit 31
; of r1 mirrors bit 30 (ie. bit 30 set forces bit 31 set, see PRM 5a-662), so
; we preserve this for old API, but do originally intended thing for new API.

HeapSortRoutine
        Push    "r1,r7,lr"
        AND     r7, r1, #2_011 :SHL: 29
        BIC     r1, r1, #2_111 :SHL: 29
        TST     r7, #1 :SHL: 30
        ORRNE   r7, r7, #1 :SHL: 31
        SWI     XOS_HeapSort32
        Pull    "r1,r7,lr"
        B       SLVK_TestV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; HeapSort routine. Borrowed from Knuth by Tutu. Labels h(i) correspond to
; steps in the algorithm.

; In    r0 = n
;       r1 = array(n) of word size objects (r2 determines type)
;       r2 = address of comparison procedure
;              Special cases:
;                0 -> treat r(n) as array of cardinal
;                1 -> treat r(n) as array of integer
;                2 -> treat r(n) as array of cardinal*
;                3 -> treat r(n) as array of integer*
;                4 -> treat r(n) as array of char* (case insensitive)
;                5 -> treat r(n) as array of char* (case sensitive)
;       r3 = wsptr for comparison procedure (only needed if r2 > 5)
;       r4 = array(n) of things (only needed if r7 & &C0000000)
;       r5 = sizeof(element)    ( ---------  ditto  ---------- )
;       r6 = address of temp slot (only needed if r5 > 16K or r7 & &20000000)
;       r7 = flags
;              bit 31 set -> use r4,r5 on postpass
;              bit 30 set -> build (r1) from r4,r5 in prepass
;              bit 29 set -> use r6 as temp slot

; r10-r12 trashable

hs_array RN     r4
hs_procadr RN   r5
hs_i    RN      r6
hs_j    RN      r7
hs_K    RN      r8
hs_R    RN      r9
hs_l    RN      r10
hs_r    RN      r11
;wp     RN      r12

        GBLL DebugHeapSort
DebugHeapSort SETL {FALSE}

; User sort procedure entered in SVC mode, interrupts enabled
; r0 = contents of array(1)
; r1 = contents of array(2)
; r0-r3 may be trashed
; wp = value requested (trash at your peril; you'll get the bad one next time)

; User sort procedure returns:
;       LT: if f(r0)  < f(r1)
;       GE: if f(r0) => f(r1)
; (ie. N_bit and V_bit only considered)

HeapSortRoutine32 ROUT

        CMP     r0, #2                  ; 0 or 1 elements? No data moved either
        ExitSWIHandler LO               ; VClear in lr and psr

        Push    "r0-r3, hs_array, hs_procadr, hs_i, hs_j, hs_K, hs_R, lr"

        CLRPSR  I_bit, r14              ; Enable interrupts (may take ages)

 [ DebugHeapSort
        STR     r0, ndump               ; For debugging porpoises
 ]
        TST     r7, #1 :SHL: 30         ; Are we to build the pointer array?
        BEQ     %FT01

; Build array of pointers to data blocks for the punter if he desires this
; (lazy slobs abound ...)

; for (i=0; i<n; i++) r(i) = &block + i*sizeof(element);

        MOV     r10, r0                 ; n
        MOV     r14, r1                 ; r14 -> base of pointer array
00      STR     r4, [r14], #4
        ADD     r4, r4, r5              ; r4 += sizeof(element)
        SUBS    r10, r10, #1
        BNE     %BT00


01      SUB     hs_array, r1, #4        ; HeapSort assumes r(1..n) not (0..n-1)

        MOV     hs_procadr, r2          ; Put proc address where we need it

        CMP     hs_procadr, #6          ; Special procedure ?
        ADRLO   r14, hs_Procedures
        LDRLO   hs_procadr, [r14, hs_procadr, LSL #2]
        ADDLO   hs_procadr, hs_procadr, r14

        MOV     wp, r3                  ; Can now use r3 temp. Keep set up
                                        ; for speed during execution

        MOV     hs_l, r0, LSR #1        ; l = floor(n/2) + 1
        ADD     hs_l, hs_l, #1
        MOV     hs_r, r0                ; r = n


h2      CMP     hs_l, #1
        BEQ     %FT10

        SUB     hs_l, hs_l, #1
        LDR     hs_R, [hs_array, hs_l, LSL #2] ; R = R(l)
        MOV     hs_K, hs_R
        B       %FT20

10      LDR     hs_R, [hs_array, hs_r, LSL #2] ; R = R(r)
        MOV     hs_K, hs_R
        LDR     r14, [hs_array, #4]     ; R(r) = R(1)
        STR     r14, [hs_array, hs_r, LSL #2]
        SUB     hs_r, hs_r, #1
        CMP     hs_r, #1                ; IF r=1 THEN R(1) = R
        STREQ   hs_R, [hs_array, #4]
20
 [ DebugHeapSort
 BL DoDebug
 ]

        CMP     hs_r, #1
        BEQ     %FT90                   ; [finished sorting the array]


h3      MOV     hs_j, hs_l


h4      MOV     hs_i, hs_j
        MOV     hs_j, hs_j, LSL #1

 [ DebugHeapSort
 DREG hs_i," i ",cc
 DREG hs_j," j "
 ]
        CMP     hs_j, hs_r
        BEQ     h6
        BHI     h8


h5      LDR     r0, [hs_array, hs_j, LSL #2]
                                        ; IF K(R(j)) < K(R(j+1)) THEN j +:= 1
        ADD     r14, hs_j, #1
        LDR     r1, [hs_array, r14, LSL #2]

      [ NoARMv5
        MOV     lr, pc                  ; r0, r1 for comparison
        MOV     pc, hs_procadr
      |
        BLX     hs_procadr
      ]

        ADDLT   hs_j, hs_j, #1          ; Assumes signed comparison done <<<<<<


h6      MOV     r0, hs_K                ; IF K >= K(R(j)) THEN h8
        LDR     r1, [hs_array, hs_j, LSL #2]

      [ NoARMv5
        MOV     lr, pc                  ; r0, r1 for comparison
        MOV     pc, hs_procadr
      |
        BLX     hs_procadr
      ]

        LDRLT   r14, [hs_array, hs_j, LSL #2] ; R(i) = R(j)
        STRLT   r14, [hs_array, hs_i, LSL #2]
        BLT     h4


h8      STR     hs_R, [hs_array, hs_i, LSL #2] ; R(i) = R
        B       h2


; Array now sorted into order

90      LDR     r14, [sp, #4*7]         ; r7in
        TST     r14, #1 :SHL: 31
        BEQ     %FA99                   ; [no shuffle required, exit]

; Reorder the blocks according to the sorted array of pointers

        LDR     r2, [sp, #4*1]          ; r2 -> list of pointers (r1in)

        ADD     r1, sp, #4*4
        LDMIA   r1, {r1, r8, r9}        ; r4,r5,r6in
                                        ; r1 -> list of blocks
 [ DebugHeapSort
 DREG r2, "pointer array   "
 DREG r1, "base of blocks  "
 DREG r8, "sizeof(element) "
 ]
        MOV     r3, r2                  ; r3 -> first item of current cycle
        LDR     r0, [sp, #0*4]          ; r0 = n
        ADD     r6, r2, r0, LSL #2      ; r6 -> end of array of pointers
        TST     r14, #1 :SHL: 29        ; punter forcing use of his temp slot?
        BNE     %FT94                   ; fine by me!
        CMP     r8, #ScratchSpaceSize
        LDRLS   r9, =ScratchSpace       ; r9 -> temp slot (normally ScratchSpc)
94
 [ DebugHeapSort
 DREG r9, "temp slot       "
 ]

91      SUB     r14, r3, r2
        MOV     r14, r14, LSR #2        ; r14 = index (0..n-1) of current item
        MLA     r4, r14, r8, r1         ; r4 -> current block

        MOV     r5, r3                  ; r5 -> current item
        BL      MoveToTempSlot          ; save first block in temp slot

92      LDR     r7, [r5]                ; r7 -> next block
        MOV     r14, #0
        STR     r14, [r5]               ; mark item 'done'

        SUB     r5, r7, r1              ; r14 := index of next item (r8 pres.)
        DivRem  r14, r5, r8, r0, norem  ; r5,r0 corrupt
        ADD     r5, r2, r14, LSL #2     ; r5 -> next item
 [ DebugHeapSort
 DREG r7, "  next block "
 DREG r5, "   next item "
 ]

        CMP     r5, r3                  ; reached start of cycle?
        MOVEQ   r7, r9                  ; get back from temp slot if last one
        BL      MoveFromGivenSlot       ; corrupts flags, but preserves r5, r3...

        CMP     r5, r3
        MOVNE   r4, r7                  ; update r4 (current block)
        BNE     %BT92

93      LDR     r14, [r3, #4]!          ; skip already-copied items
        CMP     r3, r6
        BCS     %FA99                   ; [reached end]
        CMP     r14, #0
        BEQ     %BT93

        B       %BT91                   ; [found one that hasn't been copied]


; No error return from HeapSort

99      Pull    "r0-r3, hs_array, hs_procadr, hs_i, hs_j, hs_K, hs_R, lr"

; SWIHandler exit takes flags + mode from lr, not psr !!!

        ExitSWIHandler

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r4 -> element to be copied
;       r8 = sizeof(element)
;       r9 -> temp slot

; Out   all preserved

MoveToTempSlot Entry "r4, r8, r9"

        TST     r4, #3                  ; If base and element size wordy
        TSTEQ   r8, #3                  ; then do faster copy. Also temp wordy
        BNE     %FT01

00      SUBS    r8, r8, #4
        LDRPL   r14, [r4], #4
        STRPL   r14, [r9], #4
        BPL     %BT00
        EXIT

01      SUBS    r8, r8, #1
        LDRPLB  r14, [r4], #1
        STRPLB  r14, [r9], #1
        BPL     %BT01
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r4 -> where element is to be copied
;       r7 -> element to be copied
;       r8 = sizeof(element)

; Out   all preserved

MoveFromGivenSlot Entry "r4, r7, r8"

        TST     r4, #3                  ; If dest and element size wordy
        TSTEQ   r8, #3                  ; then do faster copy. Also src wordy
        BNE     %FT01

00      SUBS    r8, r8, #4
        LDRPL   r14, [r7], #4
        STRPL   r14, [r4], #4
        BPL     %BT00
        EXIT

01      SUBS    r8, r8, #1
        LDRPLB  r14, [r7], #1
        STRPLB  r14, [r4], #1
        BPL     %BT01
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Built-in sorting procedures

hs_Procedures

        DCD     hs_CardinalCMP    - hs_Procedures
        DCD     hs_IntegerCMP     - hs_Procedures
        DCD     hs_CardinalPtrCMP - hs_Procedures
        DCD     hs_IntegerPtrCMP  - hs_Procedures
        DCD     hs_StringCMP      - hs_Procedures
        DCD     hs_StringSensCMP  - hs_Procedures

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0, r1 -> cardinals

; Out   flags set on (*r0) - (*r1)

hs_CardinalPtrCMP

        LDR     r0, [r0]
        LDR     r1, [r1]

; .............................................................................
; In    r0, r1 = cardinals

; Out   flags set on r0 - r1

hs_CardinalCMP

        CMP     r0, r1
        MSRCS   CPSR_f, #C_bit      ; CS -> GE (nv)
        MSRCC   CPSR_f, #N_bit      ; CC -> LT (Nv)
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0, r1 -> integers

; Out   flags set on (*r0) - (*r1)

hs_IntegerPtrCMP

        LDR     r0, [r0]
        LDR     r1, [r1]

; .............................................................................
; In    r0, r1 = integers

; Out   flags set on r0 - r1

hs_IntegerCMP

        CMP     r0, r1
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Case-insensitive string comparison

; In    r0, r1 -> strings - CtrlChar terminated (NB. Must be same CtrlChar !)

; Out   flags set on (char *)(r0) - (char *)(r1) compare

hs_StringCMP ROUT

10      LDRB    r2, [r0], #1
        LowerCase r2, r12
        LDRB    r3, [r1], #1
        LowerCase r3, r12
        CMP     r2, r3                  ; Differ ?
        MOVNE   pc, lr                  ; GE or LT
        CMP     r2, #space-1            ; Finished ?
        BHI     %BT10

        CMP     r2, r2                  ; return EQ (also GE)
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Case-sensitive string comparison

; In    r0, r1 -> strings - CtrlChar terminated (NB. Must be same CtrlChar !)

; Out   flags set on (char *)(r0) - (char *)(r1)

hs_StringSensCMP ROUT

10      LDRB    r2, [r0], #1
        LDRB    r3, [r1], #1
        CMP     r2, r3                  ; Differ ?
        MOVNE   pc, lr                  ; GE or LT
        CMP     r2, #space-1            ; Finished ?
        BHI     %BT10

        CMP     r2, r2                  ; return EQ (also GE)
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        LTORG

        END
