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
        TTL   => TickEvents

; This file revised by TMD 28-Jan-94 to
; a) Correct internals to time n ticks not n+1
; b) Change externals to add 1 to compensate for user subtracting 1
; c) Fix RemoveTickerEvent to add this node's time onto the next one
; These fix bug MED-02498.

; There are two (centisecond) ticker SWIs :
; SWI CallAfter calls the given address once, after the given number of ticks
; SWI CallEvery  "     "    "    "      every N centiseconds

; In :  R0 is unsigned number of centiseconds
;       R1 is address to call
;       R2 is value of R12 to pass to code

CallEvery_Code
        ADD     r10, r0, #1             ; compensate for n+1 bug
        B       TickTockCommon
CallAfter_Code   ROUT
        MOV     r10, #0
TickTockCommon
        Push    "r0-r3, lr"
        ADD     r14, r0, #1024
        CMP     r14, #1024
        BLS     %FT99                   ; reject 0 and >= &FFFFFC00

  [ ChocolateSysHeap
        ASSERT  ChocolateTKBlocks = ChocolateBlockArrays + 8
        LDR     r3,=ZeroPage+ChocolateBlockArrays
        LDR     r3,[r3,#8]
        BL      ClaimChocolateBlock
        MOVVS   r3, #TickNodeSize
        BLVS    ClaimSysHeapNode
  |
        MOV     r3, #TickNodeSize
        BL      ClaimSysHeapNode
  ]
        BVS     %FT97

        MOV     r3, r2
        LDMFD   stack, {r0-r2}
        STR     r1,  [r3, #TickNodeAddr]
        STR     r10, [r3, #TickNodeRedo]
        STR     r2,  [r3, #TickNodeR12]
        MOV     r1, r3

        ADD     r0, r0, #1              ; compensate for n+1 bug
        BL      InsertTickerEvent

        Pull    "r0-r3, lr"
        ExitSWIHandler

99      ADR     r0, ErrorBlock_BadTime
      [ International
        BL      TranslateError
      ]
97
        ADD     sp, sp, #1*4            ; junk old R0
        Pull    "r1-r3, lr"
        B       SLVK_SetV

        MakeErrorBlock BadTime


; Data structure :
; chain of nodes
;
;       +----------------------------------+
;       |   Link to next node or 0         |
;       +----------------------------------+
;       |   Reload flag                    |
;       +----------------------------------+
;       |   Address to call                |
;       +----------------------------------+
;       |   Value of R12                   |
;       +----------------------------------+
;       |   No of ticks to go before call  |
;       +----------------------------------+
;
; The head node's no of ticks is decremented until 0
;  Subsequent nodes contain the no of ticks to wait when they reach the
;  chain head.
; If the reload flag is non-0, the node is reinserted at that number of ticks
; down the chain after every use.

             ^  0
TickNodeLink #  4        ;
TickNodeRedo #  4        ; These are together
TickNodeAddr #  4        ;
TickNodeR12  #  4        ;  so can LDM them

TickNodeLeft #  4

TickNodeSize #  0

InsertTickerEvent   ROUT
; R1 is node pointer, R0 ticks to wait
; R10-R12 corrupted

        Push    "r0,lr"
        PHPSEI  r14
        LDR     r10, =ZeroPage+TickNodeChain
01
        MOV     r11, r10
        LDR     r10, [r11, #TickNodeLink]
        CMP     r10, #0
        BEQ     %FT02                           ; end of chain
        LDR     r12,  [r10, #TickNodeLeft]
        CMP     r12, r0
        SUBLS   r0, r0, r12
        BLS     %BT01                           ; node R10 is earlier (or equal) to node R1 
        SUB     r12, r12, r0
        STR     r12, [r10, #TickNodeLeft]
02
        STR     r1, [r11, #TickNodeLink]
        STR     r0, [r1, #TickNodeLeft]
        STR     r10, [r1, #TickNodeLink]

        PLP     r14
        Pull    "r0,pc"

ProcessTickEventChain  ROUT
; R0-R3, R10-R12 corruptible
        LDR     r3, =ZeroPage+TickNodeChain

        LDR     r1, [r3, #TickNodeLink]
        CMP     r1, #0
        MOVEQ   pc, lr                          ; no timers

        LDR     r2, [r1, #TickNodeLeft]
        SUBS    r2, r2, #1
        STR     r2, [r1, #TickNodeLeft]
        MOVHI   pc, lr                          ; nothing to call yet (HI to cope with ordinary 1 -> 0 transition, and 0 -> -1 transition if re-entered while processing two or more events which are due to fire at the same time)

        Push    "lr"                            ; save IRQ_lr
        MSR     CPSR_c, #SVC32_mode+I32_bit     ; switch to SVC mode, IRQ's off
        Push    "lr"                            ; save SVC_lr
01
        LDMIA   r1, {r2, r10, r11, r12}         ; load next ptr, redo state,
                                                ;     address and R12val
        STR     r2, [r3]                        ; de-link from chain
      [ NoARMv5
        MOV     lr, pc
        MOV     pc, r11                         ; call event handler
      |
        BLX     r11                             ; call event handler
      ]

        MOVS    r0, r10                         ; CallEvery?
        BEQ     %FT05

        BL      InsertTickerEvent               ; yes, then re-insert timer
        B       %FT10

05
; Return spent ticker node to heap

        MSR     CPSR_c, #SVC32_mode             ; IRQ's ON for the  S L O W  bit
        MOV     r2, r1                          ; R2->node to free
  [ ChocolateSysHeap
        ASSERT  ChocolateTKBlocks = ChocolateBlockArrays + 8
        LDR     r1,=ZeroPage+ChocolateBlockArrays
        LDR     r1,[r1,#8]
        BL      FreeChocolateBlock
        LDRVS   r1, =SysHeapStart
        MOVVS   r0, #HeapReason_Free
        SWIVS   XOS_Heap
  |
        LDR     r1, =SysHeapStart
        MOV     r0, #HeapReason_Free
        SWI     XOS_Heap
  ]

; Check for more events at the same level in the list
10
        MSR     CPSR_c, #SVC32_mode+I32_bit     ; IRQ's off again (after returning node to heap, or after naughty CallEvery exits with IRQs on)

        LDR     r1, [r3, #TickNodeLink]         ; get top of list
        CMP     r1, #0                          ; list empty?
        BEQ     %FT02                           ; yes then exit

        LDR     r0, [r1, #TickNodeLeft]
        CMP     r0, #0                          ; zero time delta?
        BEQ     %BT01                           ; yes then jump
02
        Pull    "lr"                            ; restore SVC_lr
        MSR     CPSR_c, #IRQ32_mode+I32_bit     ; back to IRQ mode
        Pull    "pc"                            ; pull IRQ_lr from IRQ stack

RemoveTickerEvent_Code
; R0 is address of code to remove, R1 the R12 value
        MSR     CPSR_c, #SVC32_mode+I32_bit
        LDR     r10, =ZeroPage+TickNodeChain
01
        LDR     r11, [r10]
        CMP     r11, #0
        ExitSWIHandler EQ
        LDR     r12, [r11, #TickNodeAddr]
        CMP     r12, r0
        LDREQ   r12, [r11, #TickNodeR12]
        CMPEQ   r12, r1
        MOVNE   r10, r11
        BNE     %BT01

        Push    "r0-r2, lr"
        MOV     r2, r11
        LDR     r11, [r11, #TickNodeLink]       ; prev->link = this->link
        STR     r11, [r10]

        TEQ     r11, #0                         ; if next node exists
        LDRNE   r14, [r11, #TickNodeLeft]       ; then add our time-to-go onto its
        LDRNE   r0, [r2, #TickNodeLeft]
        ADDNE   r14, r14, r0
        STRNE   r14, [r11, #TickNodeLeft]

  [ ChocolateSysHeap
        ASSERT  ChocolateTKBlocks = ChocolateBlockArrays + 8
        LDR     r1,=ZeroPage+ChocolateBlockArrays
        LDR     r1,[r1,#8]
        BL      FreeChocolateBlock
        BLVS    FreeSysHeapNode
  |
        BL      FreeSysHeapNode
  ]
        Pull    "r0-r2, lr"
        B       %BT01

ReadMetroGnome
        LDR     r0, =ZeroPage
        LDR     r0, [r0, #MetroGnome]
        ExitSWIHandler

        LTORG

        END
