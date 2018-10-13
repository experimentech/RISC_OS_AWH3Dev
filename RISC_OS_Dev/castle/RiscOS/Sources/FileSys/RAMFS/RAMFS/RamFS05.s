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
; >RamFS05

        TTL     "Optimised block move"

; BlockMove
; ---------
; Can't cope with overlapping source and dest
; Entry: R0 = Source start
;        R1 = Dest start
;        R2 = Byte length
BlockMove ROUT
      [ Debug9
        DLINE   "source  |dest    |length  - enter BlockMove"
        DREG    R0, " ",cc
        DREG    R1, " ",cc
        DREG    R2, " "
      ]
        MOVS    R2, R2
        MOVEQ   PC, LR
        Push    "R0-R12, LR"
        
        ; bytes at a time until source aligned
05                      
        TSTNE   R0, #2_11
        LDRNEB  LR, [R0], #1
        STRNEB  LR, [R1], #1
        SUBNES  R2, R2, #1
        BNE     %BT05

        ANDS    LR, R1, #2_11                   ; dest mis-alignment
        BEQ     %FT30                           ; same alignment

        ; mis-aligned move
        CMP     R2, #10*4                       ; enough left to worth being clever ?
        BLO     %FT40                           ; if not
        SUB     R2, R2, #10*4

        LDR     R3, [R0], #4                    ; get a word from source
10
        STRB    R3, [R1], #1                    ; put bytes to dest until aligned
        MOV     R3, R3, LSR #8
        TSTS    R1, #2_11
        BNE     %BT10
        MOV     LR, LR, LSL #3                  ; # bits left in R3
        RSB     R12, LR, #32                    ; # bits free in R3
15
        LDMIA   R0!,{R4-R11}                    ; load 8 words
                                                ; do 8 word shift, spare bits in R3
        ORR     R3, R3, R4, LSL LR
        MOV     R4, R4, LSR R12
                
        ORR     R4, R4, R5, LSL LR
        MOV     R5, R5, LSR R12
                
        ORR     R5, R5, R6, LSL LR
        MOV     R6, R6, LSR R12
                
        ORR     R6, R6, R7, LSL LR
        MOV     R7, R7, LSR R12

        ORR     R7, R7, R8, LSL LR
        MOV     R8, R8, LSR R12
                
        ORR     R8, R8, R9, LSL LR
        MOV     R9, R9, LSR R12
                
        ORR     R9, R9, R10,LSL LR
        MOV     R10,R10,LSR R12
                
        ORR     R10,R10,R11,LSL LR
        STMIA   R1!, {R3-R10}
        MOV     R3, R11, LSR R12

        SUBS    R2, R2, #8*4
        BPL     %BT15
        ADD     R2, R2, #9*4
20
        ; write out spare bytes from shift
        STRB    R3, [R1], #1
        MOV     R3, R3, LSR #8
        SUBS    LR, LR, #8
        BNE     %BT20
        B       %FT40                           ; do any bytes left

        ; aligned move
25
        LDMIA   R0!, {R3-R12, LR}               ; move 11 aligned words at a time
        STMIA   R1!, {R3-R12, LR}         
        LDMIA   R0!, {R3-R12, LR}               ; move 11 aligned words at a time
        STMIA   R1!, {R3-R12, LR}         
30
        SUBS    R2, R2, #22*4
        BPL     %BT25
        ADDS    R2, R2, #(22*4)-(3*4)
35
        LDMCSIA R0!, {R3-R5}
        STMCSIA R1!, {R3-R5}
        SUBCSS  R2, R2, #3*4
        BCS     %BT35
        ADD     R2, R2, #3*4
40
        ; move any odd bytes left
        SUBS    R2, R2, #1
        LDRPLB  LR, [R0],#1
        STRPLB  LR, [R1],#1
        BPL     %BT40
        Pull    "R0-R12, PC"

 [ PMP
; Entry: R0 = Source start (byte disc address)
;        R1 = Dest start (RAM address)
;        R2 = Byte length
BlockRead ROUT
        TEQ     r2, #0
        MOVEQ   pc, lr
        Entry   "r0-r5"
        MOV     r3, r0
        MOV     r4, r2
10
        BL      GetPageChunk
        BVS     %FT90
        MOV     r0, r5
        BL      BlockMove
        ADD     r1, r1, r2
        CMP     r4, #0
        BNE     %BT10
        EXIT
90
        FRAMSTR r0
        EXIT

; Entry: R0 = Source start (RAM address)
;        R1 = Dest start (byte disc address)
;        R2 = Byte length
BlockWrite ROUT
        TEQ     r2, #0
        MOVEQ   pc, lr
        Entry   "r0-r5"
        MOV     r3, r1
        MOV     r4, r2
10
        BL      GetPageChunk
        BVS     %FT90
        MOV     r1, r5
        BL      BlockMove
        ADD     r0, r0, r2
        CMP     r4, #0
        BNE     %BT10
        EXIT
90
        FRAMSTR r0
        EXIT

GetPageChunk ROUT
        Entry   "r0-r1,r6-r9"
        ; In:
        ; r3 = byte disc address
        ; r4 = byte length
        ; Out:
        ; r2 = chunk length
        ; r3 advanced
        ; r4 reduced
        ; r5 -> chunk
      [ DebugPMP
        DREG    r3,,cc
        DREG    r4,", ",cc
        DLINE   "*>GetPageChunk"
      ]
        LDR     r0, LRUCache
        LDR     r1, PMPSize
        CMP     r0, #0
        ADD     r1, r0, r1, LSL #3
        BEQ     %FT90
        ; First, find/create logical mapping of page
10
        LDMIA   r0, {r6, r7}            ; Get log page index, phys page index
        STMIA   r0!, {r8, r9}           ; Write previous entry over this one
        TEQ     r7, r3, LSR #12         ; Found the page?
        BEQ     %FT30
        MOV     r8, r6                  ; Shuffle things down
        TEQ     r0, r1
        MOV     r9, r7
        BNE     %BT10
        ; Didn't find it in the cache
        ; r8,r9 / r6,r7 = page to replace (last page in cache)
      [ DebugPMP
        DLINE   "Mapping in"
      ]
        MOV     r7, r3, LSR #12
        ; Remap the page
        LDR     lr, PageFlags
        Push    "r3,r6,r7,lr"           ; Page block
        MOV     r0, #22                 ; PMP_LogOp
        MOV     r1, #ChangeDyn_RamFS
        ADD     r2, sp, #4
        MOV     r3, #1
        SWI     XOS_DynamicArea
        LDR     r3, [sp], #16           ; Restore r3, junk page block
        BVS     %FT80
30
      [ DebugPMP
        DREG    r6,,cc
        DREG    r7,", ",cc
        DLINE   " Using this page"
      ]
        ; Found it in the cache
        ; r6,r7 = details
        LDR     r0, LRUCache
        STMIA   r0, {r6, r7}            ; Move entry to front of cache
        ; Now work out how much of a chunk we can return
        MOV     r0, r3, LSL #32-12
        MOV     r0, r0, LSR #32-12      ; Offset into page
        ADD     r1, r0, r4              ; End address
        CMP     r1, #4096
        MOVHI   r1, #4096
        SUB     r2, r1, r0              ; Length available
        ADD     r3, r3, r2
        SUB     r4, r4, r2
        LDR     r1, BufferStart
        ADD     r1, r1, r6, LSL #12     ; Base of page
        ADD     r5, r1, r0              ; Data pointer
      [ DebugPMP
        DREG    r2,,cc
        DREG    r3,", ",cc
        DREG    r4,", ",cc
        DREG    r5,", ",cc
        DLINE   "<*GetPageChunk"
      ]
        CLRV
        EXIT
80
        FRAMSTR r0
        EXIT

90
        ; PMP not in use.
        ; Just offset by DA base address and return the full block.
        LDR     r5, BufferStart
        MOV     r2, r4
        ADD     r5, r5, r3
        ADD     r3, r3, r4
        MOV     r4, #0
      [ DebugPMP
        DREG    r2,,cc
        DREG    r3,", ",cc
        DREG    r4,", ",cc
        DREG    r5,", ",cc
        DLINE   "<*GetPageChunk"
      ]
        EXIT
 |
BlockRead * BlockMove
BlockWrite * BlockMove
 ]

        END
