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
        TTL     => ArthurSWIs - ReadUnsigned, Vectors, Bits

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadUnsigned.
; ============
;
; Read an unsigned number from a string in decimal (no prefix), hex (&)
; or given base (nn_). Leading spaces are stripped.
; 'Bad base for number' is given if a base is not in 02..10_36
; 'Bad number' is given if
;      (i) No valid number was
;  or (ii) a '<base>_' or '&' has no following valid number
; 'Number too big' is given if the result overflowed a 32-bit word

; In    r1 -> string
;       r0 =     bits 0-7: base to read number in (0 means any based number allowed)
;                bit 31 set -> check term chars for ok-ness
;                bit 30 set -> restrict range to 00..FF
;                bit 29 set -> restrict range to 0..R2 (inclusive)
;                               (overrides bit 30)
;                bit 28 set -> read 64-bit value to R2,R3 and
;                               if applicable, range is in R2,R3
;       r4 != &45444957 ("WIDE") -> legacy mode: bits 8-28 are considered part of the base

; Out   VC : r1 -> first unused char, r2 = number
;       VS : r1 unchanged, r2 = 0, current error block set
;       either way, R4 = mask of flag bits supported

ReadUnsigned_Routine Entry "r0-r1, r3-r6, r9"

        WritePSRc SVC_mode, r9

        LDR     lr, =&45444957
        CMP     r4, lr
        MOVEQ   r4, #(2_1111 :SHL: 28)
        MOVNE   r4, #(2_111 :SHL: 29)
        STREQ   r4, [stack, #3*4]
        
        AND     r11, r0, r4       ; Remember the input flags
        ANDEQ   r12, r0, #255     ; r12 := base
        BICNE   r12, r0, r4

; first set range limit
        MOV     r9, r2            ; limit value lo word
        TST     r11, #1 :SHL: 28
        MOVEQ   r6, #0            ; limit value hi word
        MOVNE   r6, r3
        TST     r11, #3 :SHL: 29
        MOVEQ   r9, #-1           ; used unsigned; allows anything
        MOVEQ   r6, #-1
        TST     r11, #1 :SHL: 30
        MOVNE   r9, #&FF
        MOVNE   r6, #0

        CMP     r12, #2          ; If base nonsensical, default to 10
        RSBGES  r14, r12, #36    ; ie. try to match most generally
        MOVLT   r12, #10

01      LDRB    r0, [r1], #1    ; Skip spaces for Bruce
        TEQ     r0, #" "
        BEQ     %BT01
        SUB     r10, r1, #1      ; Keep ptr to start of string after spaces

        TEQ     r0, #"&"        ; '&' always forces hex read
        BNE     %FT20
        MOV     r4, #16
        TST     r11, #1 :SHL: 28
        ADR     lr, %FT09
        BEQ     ReadNumberInBase
        BNE     Read64BitNumberInBase
09      BVS     %FT95

10      STR     r1, [sp, #4]       ; Update string^
        TST     r11, #(1 :SHL: 31) ; Was the termcheck flag set ?
        BEQ     %FT15
        LDRB    r0, [r1]           ; What was the term char ?
        CMP     r0, #" "           ; CtrlChar + space all ok
        BGT     %FT85              ; For bad term errors

15      CMP     r9, r2
        SBCS    lr, r6, r5
        BCC     %FT80
        TST     r11, #1 :SHL: 28
        STRNE   r5, [stack, #4*2]
        PullEnv
        ExitSWIHandler          ; VClear already in lr


20      SUB     r1, r1, #1      ; Skip back to first char of string
        MOV     r4, #10         ; Try reading a decimal number
        BL      ReadNumberInBase
        MOVVS   r4, r12          ; If we failed to read a decimal number
        BVS     %FT30           ; then use the one supplied (r12). r1 ok
        LDRB    r0, [r1], #1    ; Is it base_number ?
        CMP     r0, #"_"        ; If not based, use supplied base
        MOVNE   r1, r10         ; to read from given start of string (spaces !)
        MOVNE   r4, r12         ; restore supplied base!
        MOVEQ   r4, r2          ; Use this as new base

; Reading number in base r4

30      CMP     r4, #2          ; Is base valid (2..36) ?
        RSBGES  r0, r4, #36     ; LT -> invalid
        BLT     %FT90
        TST     r11, #1 :SHL: 28
        ADR     lr, %FT39
        BEQ     ReadNumberInBase ; Read rest of number
        BNE     Read64BitNumberInBase
39      BVS     %FT95
        B       %BT10


80      ADR     r2, ErrorBlock_NumbTooBig
        B       %FT95

85      ADR     r2, ErrorBlock_BadNumb
        B       %FT95

90      ADR     r2, ErrorBlock_BadBase

95
      [ International
        Push    "r0,lr"
        MOV     r0,r2
        BL      TranslateError
        MOV     r2,r0
        Pull    "r0,lr"
      ]
        STR     r2, [stack]     ; Go set the current error
        MOV     r2, #0          ; Defined to return 0 on error
        TST     r11, #1 :SHL: 28
        STRNE   r2, [stack, #4*2] ; return MSB=0 on error too, if 64-bit read reqd
        PullEnv
        B       SLVK_SetV

        MakeErrorBlock BadBase

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadNumberInBase
; ================

; In    r1 -> string, r4 = base (valid)

; Out   VC : Number read in r2, r1 updated. r3 = number of chars used, r5 = 0
;       VS : r1 preserved, r2 -> error block

ReadNumberInBase Entry "r0, r1, r12"

        MOV     r2, #0          ; Result
        MOV     r3, #0          ; Number of valid digits read
        MOV     r5, #0

10      BL      GetCharForReadNumber
        BNE     %FT50           ; Finished ?

        TST     r2, #&F8000000  ; If EQ, can't possibly overflow in any base up to 26
        MLAEQ   r2, r4, r2, r0
        BEQ     %BT10
        
        MOV     r12, r4
        MOV     r14, #0         ; Multiply by repeated addition. Base <> 0 !
20      ADDS    r14, r14, r2
        BCS     %FT90           ; Now checks for overflow !
        SUBS    r12, r12, #1    ; result *:= base
        BNE     %BT20
        ADDS    r2, r14, r0     ; result +:= digit
        BCC     %BT10
        B       %FT90           ; Now checks for overflow here too!

50      CMP     r3, #0          ; Read any chars at all ? VClear
        STRNE   r1, [sp, #4]    ; Update string^
        EXIT    NE              ; Resultis r2

      [ International
        Push    "r0"
        ADR     r0, ErrorBlock_BadNumb
        BL      TranslateError
        MOV     r2,r0
        Pull    "r0"
      |
        ADR     r2, ErrorBlock_BadNumb
        SETV
      ]
        EXIT
        MakeErrorBlock BadNumb

90
      [ International
        Push    "r0"
        ADR     r0, ErrorBlock_NumbTooBig
        BL      TranslateError
        MOV     r2,r0
        Pull    "r0"
      |
        ADR     r2, ErrorBlock_NumbTooBig
        SETV
      ]
        EXIT
        MakeErrorBlock NumbTooBig

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Read64BitNumberInBase
; =====================

; In    r1 -> string, r4 = base (valid)

; Out   VC : Number read in r2 (lo) and r5 (hi), r1 updated. r3 = number of chars used
;       VS : r1 preserved, r2 -> error block, r5 corrupted

Read64BitNumberInBase ALTENTRY

        MOV     r2, #0          ; Result lo
        MOV     r3, #0          ; Number of valid digits read
        MOV     r5, #0          ; Result hi

10      BL      GetCharForReadNumber
        BNE     %BT50           ; Finished ?

      [ :LNOT: NoARMM
        TST     r5, #&F8000000  ; If EQ, can't possibly overflow in any base up to 26
        MULEQ   r5, r4, r5      ; r0,r5 = new_digit + (old_msw * base)<<32
        UMLALEQ r0, r5, r4, r2  ; r0,r5 += old_lsw * base
        MOVEQ   r2, r0
        BEQ     %BT10
      ]
                                ; Multiply by repeated addition. Base <> 0 !
        SUBS    r12, r4, #1     ; Final iteration has r2,r5 as dest, so one fewer main iterations
        MOV     r14, #0         ; r0,r14 is accumulator, initialised to new_digit,0
20      ADDS    r0, r0, r2
        ADCS    r14, r14, r5
        BCS     %BT90
        SUBS    r12, r12, #1
        BNE     %BT20
        ADDS    r2, r0, r2
        ADCS    r5, r14, r5
        BCC     %BT10
        B       %BT90           ; Checks for overflow here too!

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; GetCharForReadNumber
; ====================
;
; Read a digit and validate for reading in current base. Bases 2..36 are valid

; In    r1 -> string, r4 = base for number input

; Out   EQ -> r0 = valid number in [0..base-1], r1++
;       NE -> r0 invalid, r1 same

GetCharForReadNumber Entry

        LDRB    r0, [r1]
        CMP     r0, #"0"
        BLO     %FT95
        CMP     r0, #"9"
        BLS     %FT50
        UpperCase r0, r14
        CMP     r0, #"A"        ; Always hex it, even if reading in decimal
        RSBGES  r14, r0, #"Z"   ; Inverse compare as nicked from UpperCase
        BLT     %FT95           ; GE -> in range A..Z
        SUB     r0, r0, #"A"-("0"+10)
50      SUB     r0, r0, #"0"
        CMP     r0, r4          ; digit in [0..base-1] ?
        BHS     %FT95
        ADD     r1, r1, #1      ; r1++
        ADD     r3, r3, #1      ; Valid digit has been read
        CMP     r0, r0          ; EQ
        EXIT

95      CMP     r0, #-1         ; NE
        EXIT

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Initialise_vectors()
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

            ^ 0
TailPtr     # 4     ; order very carefully chosen!
VecWSpace   # 4
Address     # 4
VecNodeSize # 0

InitVectors

; for vec:=0 to NVECTORS-1 do vectab!(vec*4):= defaultvectab+8*vec

      MOV   R0, #NVECTORS
      ADR   R1, defaultvectab    ; Point at the default vector table
      LDR   R2, =ZeroPage+VecPtrTab ; Point at table of head pointers

VecInitLoop
      STR    R1, [R2], #4
      ADD    R1, R1, #VecNodeSize ; defaultvectab+vns*vec
      SUBS   R0, R0, #1             ; Next vec
      BGT    VecInitLoop

      MOV    PC, link
      LTORG

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Call_vector (n)
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In:   r10 = vector number
;       lr contains return address
;       cpsr contains flags/int state to set up before calling

; Out:  r10, r12, lr corrupted

CallVector ROUT

        MRS     r12, CPSR
        CMP     r10, #NVECTORS
        BHS     CallVecTooHigh          ; return - silly value

        MSR     CPSR_f, r12             ; put back caller's flags + int state
        Push    lr                      ; claimed return goes back to caller

        LDR     r14, =ZeroPage+VecPtrTab ; Point at table of head pointers
        LDR     r10, [r14, r10, LSL #2] ; nextblock:=vecptrtab!(n*4)

CallVecLoop
        MOV     lr, pc                  ; Set up the return address
        LDMIA   r10, {r10, r12, pc}     ; CALL the vectored routine, step chain

; NB. It is the responsibility of vector code NOT to corrupt flags that are
; part of the input conditions if they are going to pass the call on, eg. INSV
; must not do CMP as C,V are needed by old handler

        TEQ     r10, #0                 ; until nextblock points to zero
        BNE     CallVecLoop

        Pull    pc                      ; can't restore all flags. CV will be preserved

CallVecTooHigh
        MSR     CPSR_f, r12
        MOV     pc, lr

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;Add_To_vector(n, Addressess)
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Add_ToVector_SWICode   ROUT

      CMP   R0, #NVECTORS
      BCS   BadClaimNumber
      Push "R0-R4, link"
      B     GoForAddToVec

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;Claim_vector(n, Addressess)
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ClaimVector_SWICode   ROUT
 ; On Entry : R0 = Vector number, R1 = Address, R2 = workspace reqd

      CMP   R0, #NVECTORS
      BCS   BadClaimNumber

      Push "R0-R4, link"

        PHPSEI  R4, R14                 ; Disable IRQs

        MOV     R3, #0                  ; List of de-linked nodes is empty
        LDR     R11, =ZeroPage+VecPtrTab ; Get ptr to table of head pointers
        LDR     R10, [R11, R0, LSL #2]! ; R10 "nextblock" := *oldptr, R11= root ptr
01      BL      FindAndDelinkNode       ; R10,R11->R10,R11,R12
        STRVC   R3, [R12, #TailPtr]     ; Attach de-linked nodes onto this node
        MOVVC   R3, R12                 ; New head of de-linked nodes
        BVC     %BT01                   ; Repeat until all nodes de-linked

        PLP     R4                      ; Restore IRQ state

; Free the list of de-linked nodes, pointed to by R3, enter with VS

02      LDRVC   R3, [R3, #TailPtr]      ; Update head of de-linked nodes
        BLVC    FreeNode                ; Free the node pointed to by R12
        SUBS    R12, R3, #0             ; Any more nodes to free?
        BNE     %BT02                   ; Yes then jump

GoForAddToVec
      LDR   R11, =ZeroPage+VecPtrTab ; Point at table of head pointers

      ADD   R11, R11, R0, LSL #2
      MOV   R10, R1                 ; Address
      MOV   R4, R2                  ; TailPtr pointer is "nextblock"

  [ ChocolateSysHeap
      ASSERT  ChocolateSVBlocks = ChocolateBlockArrays + 4
      LDR   r3,=ZeroPage+ChocolateBlockArrays
      LDR   r3,[r3,#4]
      BL    ClaimChocolateBlock
      MOVVS R3, #VecNodeSize        ; Ask for this number of bytes
      BLVS  ClaimSysHeapNode        ; The result is in R2 : R12 corrupted
  |
      MOV   R3, #VecNodeSize        ; Ask for this number of bytes
      BL    ClaimSysHeapNode        ; The result is in R2 : R12 corrupted
  ]
      BVS   BadClaimVector          ; Failed : Exit

      WritePSRc SVC_mode+I_bit, R3  ; force noirq
      LDR   R3, [R11]               ; "nextblock" :=vecptrtab!(n*4)
      STMIA R2, {R3, R4, R10}       ; Atomic Operation thus links in the new
                                    ; routine
      STR   R2, [R11]               ; vectab!(n*4) := "thisblock"
BadClaimVector
      STRVS R0, [stack]
      Pull "R0-R4, link"
      B    SLVK_TestV

BadClaimNumber
      ADR    R0, ErrorBlock_BadClaimNum
    [ International
      Push   "lr"
      BL     TranslateError
      Pull   "lr"
    ]
      B      SLVK_SetV

      MakeErrorBlock BadClaimNum

;Release_vector(n, Addressess)
;+++++++++++++++++++++++++

ReleaseVector_SWICode
 ; On Entry : R0 = vector number, R1 = Address, R2 = workspace, SVC mode

      CMP   R0, #NVECTORS
      SETV  CS
      BVS   BadVectorRelease

        Push    "R0-R2,R9,link"

        PHPSEI  R9, R14                 ; Disable IRQs

        LDR     R11, =ZeroPage+VecPtrTab ; Get ptr to table of head pointers
        LDR     R10, [R11, R0, LSL #2]! ; R10 "nextblock" := *oldptr, R11= root ptr
        BL      FindAndDelinkNode       ; R10,R11->R10,R11,R12
        PLP     R9                      ; Restore IRQ state
        BLVC    FreeNode                ; If found, free the node in R12

        Pull    "R0-R2,R9,link"

BadVectorRelease
      ADRVS R0, ErrorBlock_NaffRelease
    [ International
      Push  "lr",VS
      BLVS  TranslateError
      Pull  "lr",VS
    ]
      B     SLVK_TestV

      MakeErrorBlock NaffRelease

; Find a node and de-link it from the vector chain
; In:
; R1 = code address
; R2 = workspace address
; R10 -> Node
; R11 -> Root ptr
; Out:
; VC:
; R10 -> Node following found
; R11 -> New root ptr
; R12 -> Node de-linked
; VS:
; R10,11,12 trashed - node not found

10      ADD     R11, R10, #TailPtr      ; oldptr := thisblock+TailPtr
        LDR     R10, [R11]              ; nextblock:=thisblock!TailPtr

FindAndDelinkNode
        CMP     R10, #0                 ; End of chain?
        RETURNVS EQ                     ; Yes, return error

        LDR     R12, [R10, #VecWSpace]
        CMP     R12, R2                 ; Workspace matches?
        LDREQ   R12, [R10, #Address]
        CMPEQ   R12, R1                 ; And code address matches?
        BNE     %BT10                   ; No then jump, try next node

; Remove node from vector chain

        MOV     R12, R10                ; R12-> node to de-link
        LDR     R10, [R12, #TailPtr]    ; Get link to next node
        STR     R10, [R11]              ; Previous node's link -> next node
        RETURNVC EQ                     ; Return no error

; Return node to heap space
; In:
; R12-> node to release

FreeNode
        Push    "R0-R2, lr"
        MOV     R2, R12
  [ ChocolateSysHeap
        ASSERT  ChocolateSVBlocks = ChocolateBlockArrays + 4
        LDR     r1,=ZeroPage+ChocolateBlockArrays
        LDR     r1,[r1,#4]
        BL      FreeChocolateBlock
        BLVS    FreeSysHeapNode
  |
        BL      FreeSysHeapNode
  ]
        STRVS   R0, [stack]
        Pull    "R0-R2, PC"                     ; returns Vset if sysheap poo'd.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      LTORG

defaultvectab
   & 0, 0, NaffVector           ; UserV  * &00
   & 0, 0, ErrHandler           ; ErrorV * &01
   & 0, 0, NOIRQ                ; IrqV   * &02
   & 0, ZeroPage+OsbyteVars, PMFWrch ; WrchV  * &03

   & 0, 0, NewRdch              ; RdchV  * &04  - start of VecNo=SWINo section
   & 0, 0, VecOsCli
   & 0, ZeroPage+OsbyteVars, OsByte
   & 0, ZeroPage+OsbyteVars, OsWord
   & 0, 0, NaffVector             ; filev
   & 0, 0, NaffVector             ; argsv
   & 0, 0, NaffVector             ; bgetv
   & 0, 0, NaffVector             ; bputv
   & 0, 0, NaffVector             ; gbpbv
   & 0, 0, NaffVector             ; findv
   & 0, ZeroPage+OsbyteVars, VecRdLine ; ReadlineV  * &0E - end of VecNo=SWINo

   & 0, 0, NaffVector           ; fscv

   & 0, ZeroPage+EvtHan_ws, DefEvent ; EventV * &10

   & 0, 0, NaffVector           ; UPTV   * &11
   & 0, 0, NaffVector           ; NETV   * &12

   & 0, 0, KeyVector            ; KEYV   * &13

   & 0, BuffParms+0, NewInsV    ; INSV   * &14
   & 0, BuffParms+0, NewRemV    ; REMV   * &15
   & 0, BuffParms+4, NewCnpV    ; CNPV   * &16     ; Count/Purge Buffer V

   & 0, 0, NaffVector           ; UKVDU23V * &17   ; ---| VDU23 (decimal)

   & 0, ZeroPage+HiServ_ws, HighSWI ; UKSWIV   * &18   ; ---| Unknown SWI numbers

   & 0, 0, NaffVector           ; UKPLOTV  * &19   ; ---| VDU25 (decimal)

   & 0, 0, ReadMouse            ; MouseV * &1A

   & 0, 0, NaffVector           ; VDUXV   * &1B
   & 0, 0, Def_100HZ            ; TickerV * &1C

   & 0, ZeroPage+UpCallHan_ws, CallUpcallHandler
                                ; UpCallV * &1D
   & 0, 0, AdjustOurSet         ; ChangeEnvironment * &1E

   & 0, ZeroPage+VduDriverWorkSpace, SpriteVecHandler ; SpriteV * &1F
   & 0, 0, NaffVector           ; DrawV * &20
   & 0, 0, NaffVector           ; EconetV * &21
   & 0, 0, NaffVector           ; ColourV * &22
   & 0, ZeroPage+VduDriverWorkSpace, MOSPaletteV ; PaletteV * &23
   & 0, 0, NaffVector           ; SerialV * &24

   & 0, 0, NaffVector           ; FontV * &25

   & 0, 0, PointerVector        ; PointerV * &26
   & 0, 0, NaffVector           ; TimeCodeV * &27
   & 0, 0, NaffVector           ; LowPriorityEventV &28
   & 0, 0, NaffVector           ; &29
   & 0, ZeroPage+VduDriverWorkSpace, MOSGraphicsV  ; GraphicsV * &2a
   & 0, 0, NaffVector           ; UnthreadV * &2b
   & 0, 0, NaffVector           ; &2c
   & 0, 0, NaffVector           ; SeriousErrorV * &2d
   & 0, 0, NaffVector           ; &2e
   & 0, 0, NaffVector           ; &2f
   & 0, 0, NaffVector           ; &30
   & 0, 0, NaffVector           ; &31
   & 0, 0, NaffVector           ; &32
   & 0, 0, NaffVector           ; &33
   & 0, 0, NaffVector           ; &34
   & 0, 0, NaffVector           ; &35
   & 0, 0, NaffVector           ; &36
   & 0, 0, NaffVector           ; &37
   & 0, 0, NaffVector           ; &38
   & 0, 0, NaffVector           ; &39
   & 0, 0, NaffVector           ; &3A
   & 0, 0, NaffVector           ; &3B
   & 0, 0, NaffVector           ; &3C
   & 0, 0, NaffVector           ; &3D
   & 0, 0, NaffVector           ; &3E
   & 0, 0, NaffVector           ; &3F
   & 0, 0, NaffVector           ; &40
   & 0, 0, NaffVector           ; &41
   & 0, 0, NaffVector           ; &42
   & 0, 0, NaffVector           ; &43
   & 0, 0, NaffVector           ; &44
   & 0, 0, NaffVector           ; &45
   & 0, 0, NaffVector           ; &46
   & 0, 0, NaffVector           ; &47
   & 0, 0, NaffVector           ; &48
   & 0, 0, NaffVector           ; &49
   & 0, 0, NaffVector           ; &4A
   & 0, 0, NaffVector           ; &4B
   & 0, 0, NaffVector           ; &4C
   & 0, 0, NaffVector           ; &4D
   & 0, 0, NaffVector           ; &4E
   & 0, 0, NaffVector           ; &4F
   & 0, 0, NaffVector           ; &50
   & 0, 0, NaffVector           ; &51
   & 0, 0, NaffVector           ; &52
   & 0, 0, NaffVector           ; &53
   & 0, 0, NaffVector           ; &54
   & 0, 0, NaffVector           ; &55
   & 0, 0, NaffVector           ; &56
   & 0, 0, NaffVector           ; &57
   & 0, 0, NaffVector           ; &58
   & 0, 0, NaffVector           ; &59
   & 0, 0, NaffVector           ; &5A
   & 0, 0, NaffVector           ; &5B
   & 0, 0, NaffVector           ; &5C
   & 0, 0, NaffVector           ; &5D
   & 0, 0, NaffVector           ; &5E
   & 0, 0, NaffVector           ; &5F

 assert (.-defaultvectab) = NVECTORS*VecNodeSize

NaffVector ROUT
Def_100HZ
        MRS     lr, CPSR
        BIC     lr, lr, #V_bit
        MSR     CPSR_f, lr              ; Clear V, preserve rest
        LDR     pc, [sp], #4            ; Claim vector, do nowt

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWIs to save any vector entries pointing into application workspace
;
; Delink SWI:
;   R0 pointer to buffer
;   R1 buffer size
; Returns R1 bytes left in buffer
;   V set if buffer not large enough

Application_Delink ROUT
      Push "R0, R2-R4, lr"

      CMP   R1, #4
      BLT   %FT99                   ; invalid buffer size

    [ ZeroPage = 0
      MOV   R3, #NVECTORS-1
      LDR   R4, [R3, #AplWorkSize-(NVECTORS-1)]
    |
      LDR   R4, =ZeroPage
      MOV   R3, #NVECTORS-1
      LDR   R4, [R4, #AplWorkSize]
    ]
      SETPSR I_bit, R2           ; IRQs off while holding context.

03    LDR   R11, =ZeroPage+VecPtrTab ; Point at table of head pointers
      ADD   R10, R11, R3, LSL #2
04    MOV   R11, R10             ; step chain
      LDR   R10, [R11]
05    CMP   R10, #0
      BNE   %FT02
      SUBS  R3, R3, #1
      BPL   %BT03                ; next vector
      MOV   R3, #-1
      STR   R3, [R0]
      SUB   R1, R1, #4
      Pull "R0, R2-R4, lr"
      ExitSWIHandler

02    LDR   R12, [R10, #Address]
      CMP   R12, R4
      BGT   %BT04
      CMP   R12, #AppSpaceStart
      BLT   %BT04

; appl entry found: put in buffer, free it
      CMP   R1, #12+4
      BLT   %FT99                ; no rheum
      LDR   R14, [R10, #VecWSpace]
      STMIA R0!, {R3, R12, R14}
      SUB   R1, R1, #12          ; buffer entry added

      LDR   R12, [R10, #TailPtr]
      STR   R12, [R11]           ; vector delinked

        Push    "R0-R2"
        MOV     R2, R10
        MOV     R10, R12                        ; keep updated thisblk
  [ ChocolateSysHeap
        ASSERT  ChocolateSVBlocks = ChocolateBlockArrays + 4
        LDR     r1,=ZeroPage+ChocolateBlockArrays
        LDR     r1,[r1,#4]
        BL      FreeChocolateBlock
        BLVS    FreeSysHeapNode
  |
        BL      FreeSysHeapNode
  ]
        MOVVS   lr, R0
        Pull    "R0-R2"
        BVC     %BT05

98    STR   lr, [stack]
      MOV   R3, #-1               ; terminate buffer even if error
      CMP   r1, #4
      STRGE R3, [R0]
      SUB   R1, R1, #4
      Pull "R0, R2-R4, lr"
      B    SLVK_SetV

99
    [ International
      Push  "r0"
      ADRL  r0, ErrorBlock_BuffOverflow
      BL    TranslateError
      MOV   lr,r0
      Pull  "r0"
    |
      ADRL  lr, ErrorBlock_BuffOverflow
    ]
      B     %BT98

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Relink SWI:
;   R0 pointer to buffer as set by Delink
; Returns V set if can't relink all

Application_Relink ROUT
 [ {TRUE}
; Run through the buffer BACKWARDS to ensure that the vectors are
; reinstalled in the same order.
      Push   "R0-R3, lr"
      MOV     R3, R0            ; R3 -> start of buffer
      MOV     R10, R0
01    LDR     R0, [R10], #12    ; search forwards to find terminator
      CMP     R0, #-1
      BNE     %BT01
      SUB     R10, R10, #12     ; R10 -> terminator
02    CMP     R10, R3           ; loop backwards until we get to start
      Pull   "R0-R3, lr", EQ
      ExitSWIHandler EQ

      LDMDB   R10!, {R0-R2}
      SWI     XOS_AddToVector
      BVC     %BT02
      STR     R0, [stack]
      Pull   "R0-R3, lr"
      B      SLVK_SetV
 |
      Push   "R0-R2, lr"
      MOV     R10, R0
02    LDR     R0, [R10], #4
      CMP     R0, #-1
      Pull   "R0-R2, lr", EQ
      ExitSWIHandler EQ

      LDMIA   R10!, {R1, R2}
      SWI     XOS_AddToVector
      BVC     %BT02
      STR     R0, [stack]
      Pull   "R0-R2, lr"
      B      SLVK_SetV
 ]

;********************************************************************
; Now the stuff that issues service calls; also deals with the MOS
;  being default default FIQ owner, and wanting to see application
;  startup.
;********************************************************************

        GBLL  DebugNeil
DebugNeil SETL {FALSE}          ; if TRUE, check R7-R11 preserved over services

Issue_Service ROUT             ; R1 is service number, R2 may be a parameter
                               ; registers preserved.
       Push    "R9-R12, lr"

       CMP      R1, #Service_ClaimFIQ
       CMPNE    R1, #Service_ClaimFIQinBackground
       BEQ      FIQclaim
       CMP      R1, #Service_ReleaseFIQ
       BEQ      test_FIQclaim_in_progress

       CMP      r1, #Service_NewApplication
       BEQ      checkmoshandlers

  [ ChocolateService
05
       CMP      R1,#ServMinUsrNumber
       BHS      %FT84
;call anyone on the appropriate Sys chain
       LDR      R10,=ZeroPage
       LDR      R10,[R10,#Serv_SysChains]
       CMP      R10,#0
       BEQ      %FT88
       LDR      R11,[R10,R1,LSL #2]             ;pick up the chain anchor
80
;call everyone on the chain, passing R1 value from chain if appropriate
       CMP      R11,#0
       BEQ      %FT88
       LDR      R10,[R11,#ServChain_Size]
       ADD      R11,R11,#ServChain_HdrSIZEOF    ;start of chain
       ADD      R10,R10,R11                     ;end of chain
82
       CMP      R11,R10
       BHS      %FT88

       Push     "R10"
       MOV      R10,R1
       LDR      R9,[R11,#ServEntry_R1]
       TEQ      R9,#0                           ; 0 means pass service number as normal
       MOVNE    R1,R9                           ; else pass R1 value from chain (will be service index)
       LDR      R12,[R11,#ServEntry_WSpace]
       LDR      R9,[R11,#ServEntry_Code]
     [ NoARMv5
       MOV      lr, pc                          ; link inc. PSR, mode
       MOV      pc, R9
     |
       BLX      R9
     ]
       CMP      R1, #Service_Serviced
       MOVNE    R1,R10                          ; restore R1 unless claimed
       Pull     "R10"
       BEQ      %FT01
       ADD      R11,R11,#ServEntry_SIZEOF
       B        %BT82
;
;call anyone on the appropriate Usr chain
84
       LDR      R10,=ZeroPage+Serv_UsrChains
       LDR      R10,[R10]
       CMP      R10,#0
       BEQ      %FT88
       ServHashFunction R9,R1
       LDR      R11,[R10,R9,LSL #2]             ;pick up the chain-array anchor
       CMP      R11,#0
       BEQ      %FT88
       LDR      R10,[R11,#ServUChArray_Size]
       ADD      R11,R11,#ServUChArray_HdrSIZEOF ;start of list
       ADD      R10,R10,R11                     ;end of list
86
       CMP      R11,R10
       BHS      %FT88
       LDR      R9,[R11,#ServUChEntry_ServiceNo]
       TEQ      R9,R1
       ADDNE    R11,R11,#ServUChEntry_SIZEOF
       BNE      %BT86
       LDR      R11,[R11,#ServUChEntry_ChainAnchor]  ;found chain for this service number
       B        %BT80
;
;call everyone on the chain of Awkward modules, always passing service number in R1
88
       LDR      R10,=ZeroPage
       LDR      R11,[R10,#Serv_AwkwardChain]
       CMP      R11,#0
       BEQ      %FT01
       LDR      R10,[R11,#ServChain_Size]
       ADD      R11,R11,#ServChain_HdrSIZEOF    ;start of chain
       ADD      R10,R10,R11                     ;end of chain
90
       CMP      R11,R10
       BHS      %FT01
       LDR      R12,[R11,#ServEntry_WSpace]
       LDR      R9,[R11,#ServEntry_Code]
     [ NoARMv5
       MOV      lr, pc                          ; link inc. PSR, mode
       MOV      pc, R9
     |
       BLX      R9
     ]
       CMP      R1, #Service_Serviced
       BEQ      %FT01
       ADD      R11,R11,#ServEntry_SIZEOF
       B        %BT90

  | ;IF/ELSE ChocolateService

05     LDR      R10, =ZeroPage+Module_List
03     LDR      R10, [R10, #Module_chain_Link]
       CMP      R10, #0
       BEQ      %FT01
       LDR      R9, [R10, #Module_code_pointer]
       LDR      R11, [R9, #Module_Service]
       CMP      R11, #0
       BEQ      %BT03
 [ DebugROMPostInit
       CMP      R1, #Service_PostInit           ; If it is a Service_PostInit call
       BEQ      display_pre_postinit_calls      ; Go and display the postinit call
83
 ]
       ADD      R9, R9, R11
       ADD      R11, R10, #Module_incarnation_list - Incarnation_Link
04     LDR      R11, [R11, #Incarnation_Link]
       CMP      R11, #0
       BEQ      %BT03

       [ DebugNeil
       Push     "R7-R11"
       ]

       ADD      R12, R11, #Incarnation_Workspace
     [ NoARMv5
       MOV      lr, pc               ; link inc. PSR, mode
       MOV      pc, R9
     |
       BLX      R9
     ]

       [ DebugNeil
       ! 0, "Debug code included to check R7-R11 are preserved over services"
       MOV      lr, sp
       Push     "R1-R5"
       LDMIA    lr, {R1-R5}
       TEQ      R1, R7
       TEQEQ    R2, R8
       TEQEQ    R3, R9
       TEQEQ    R4, R10
       TEQEQ    R5, R11
       MOVNE    PC, #0
       Pull     "R1-R5"
       ADD      sp, sp, #5*4
       ]

 [ DebugROMPostInit
       CMP      R1, #Service_PostInit           ; If it is a Service_PostInit call
       BEQ      display_post_postinit_calls     ; Go and display the postinit call
87
 ]

       CMP      R1, #Service_Serviced
       BNE      %BT04
       Pull    "R9-R12, PC"

  ] ;ChocolateService

01     CMP      R1, #Service_ReleaseFIQ
       Pull    "R9-R12, PC",NE

     assert (Service_ReleaseFIQ :AND: &FF) <> 0
     [ ZeroPage = 0
       LDRB     R9, [R1, #MOShasFIQ-Service_ReleaseFIQ]
       STRB     R1, [R1, #MOShasFIQ-Service_ReleaseFIQ]
     |
       LDR      R1, =ZeroPage+MOShasFIQ
       ASSERT ((ZeroPage+MOShasFIQ) :AND: 255) <> 0
       LDRB     R9, [R1]
       STRB     R1, [R1]
     ]
       TEQ      R9, #0
       BNE      %FT06

       ADR      R1, FIQKiller
       MOV      R10, #FIQKiller_ws - FIQKiller
       LDR      R11, =ZeroPage+&1C
04     LDR      LR, [R1], #4
       SUBS     R10, R10, #4
       STR      LR, [R11], #4
       BNE      %BT04
     [ ZeroPage <> 0
       LDR      R10, =ZeroPage
     ]
       AddressHAL R10
       LDR      R14, [R9, #-(EntryNo_HAL_FIQDisableAll+1)*4]
       STMIA    R11, {R9, R14}
       Push     "R0"
       LDR      R0, =ZeroPage
       ADD      R1, R0, #&100
       ARMop    IMB_Range,,,R0
       Pull     "R0"

                                        ; MOS is default owner if nobody
06     MOV      R1, #Service_Serviced   ; else wants it.
       Pull    "R9-R12, PC"

FIQclaim
       LDR      R10, =ZeroPage

  ; first refuse request if a claim is currently in action

       LDRB     R9, [R10, #FIQclaim_interlock]
       CMP      R9, #0
       Pull    "R9-R12, PC",NE                 ; no can do

; have to issue a genuine FIQ claim call: set interlock to prevent another
; one passing round at an awkward moment.

       MOV      r9, #1
       STRB     r9, [r10, #FIQclaim_interlock]

; now safe to inspect our FIQ state

       LDRB     R9, [R10, #MOShasFIQ]
       CMP      R9, #0
       ASSERT   (ZeroPage :AND: 255) = 0
       STRNEB   R10, [R10, #MOShasFIQ]
       MOVNE    r1, #Service_Serviced
fakeservicecall
        ; do it this way to cope with ARM v4/v3 differences on storing PC
       SUBEQ    stack,stack,#20
       STREQ    PC,[stack,#16]
       BEQ      %BT05
       MOV      r0, r0
       LDR      r10, =ZeroPage
       LDRB     r9, [r10, #FIQclaim_interlock]
       ASSERT   (ZeroPage :AND: 255) = 0
       STRB     r10, [r10, #FIQclaim_interlock]

       CMP      r9, #1                         ; test for background release
; if background release happened, there are 3 possibilities:
;   foreground claim; this is defined to have succeeded. Discard release
;   background claim, that succeeded: releaser gave it away anyway. Discard
;       "        "     "   failed; we are holding a giveaway of FIQ, therefore
;                                  claim service call!
; therefore, if background release happened, always claim the service.

       MOVNE    r1, #Service_Serviced
       Pull    "r9-r12, PC"                    ; all done

test_FIQclaim_in_progress

       LDR      r10, =ZeroPage
       LDRB     r9, [r10, #FIQclaim_interlock]
       CMP      r9, #0

       MOVEQ    r9, #1
       STREQB   r9, [r10, #FIQclaim_interlock] ; lock out background calls
       BEQ      fakeservicecall                ; issue call, clear flag

       MOV      r9, #2                         ; mark release as occurring

       STRB     r9, [r10, #FIQclaim_interlock]
       Pull    "r9-r12, PC"

; r9-r12, lr corruptible
checkmoshandlers
     [ ZeroPage = 0
       LDR      r9, [r1, #SExitA-Service_NewApplication]
     |
       LDR      r9, =ZeroPage
       LDR      r9, [r9, #SExitA]
     ]
       ADRL     r10, CLIEXIT
       CMP      r9, r10
       BNE      %BT05
       Push    "r0-r7"
       BL       DEFHAN
       BL       DEFHN2
       Pull    "r0-r7"
       B        %BT05

 [ DebugROMPostInit
 ; Display the title of the current module in the chain.
 ; R9 contains the module pointer.
display_pre_postinit_calls
       SWI     XOS_WriteS
       =       "postinit service call to mod ",0
       Push    "r0-r7"
       LDR     R0, [R9, #Module_TitleStr]
       ADD     R0, R9, R0
       SWI     XOS_Write0
       SWI     XOS_WriteS
       =       " sent"
       SWI     XOS_NewLine
       Pull    "r0-r7"
       B        %BT83

 ; Display a message stating that we have finished the postinit service call.
 ; This will appear once for every module called on postinit.
display_post_postinit_calls
       SWI     XOS_WriteS
       =       "returned from postinit service call.",0
       SWI     XOS_NewLine
       B        %BT87
 ]

FIQKiller
       SUB     R14, R14, #4
       ADR     R13, FIQKiller-&1C+&100
       ADR     R10, FIQKiller_ws
       STMFD   R13!, {R0-R3,R14}
       MOV     R14, PC
       LDMIA   R10, {R9,PC}
       MyCLREX R0, R1
       LDMFD   R13!, {R0-R3,PC}^
FIQKiller_ws


;************************************************
; SWI to call a vector
;************************************************
CallAVector_SWI  ; R9 is the vector number (!!)
       STR       lr, [sp, #-4]!         ; save caller PSR on stack
       MOV       R10, R9
       MSR       CPSR_f, R12            ; restore caller CCs (including V)
       BL        CallVector
       MRS       r10, CPSR              ; restore CCs
       LDR       lr, [sp], #4
     [ NoARMT2
       AND       r10, r10, #&F0000000
       BIC       lr, lr, #&F0000000
       ORR       lr, lr, r10
     |
       MOV       r10, r10, LSR #28
       BFI       lr, r10, #28, #4
     ]
       ExitSWIHandler

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; Now some bits for the dynamic areas

DoSysHeapOpWithExtension
       Push   "R0, lr"
       B       IntoSysHeapOp

ClaimSysHeapNode ROUT ; size in R3
       MOV     R0, #HeapReason_Get
       Push   "R0, lr"
IntoSysHeapOp
       LDR     R1, =SysHeapStart
       SWI     XOS_Heap
       Pull   "R0, PC", VC

       LDR     r14, [r0]                   ; look at error number
       TEQ     r14, #ErrorNumber_HeapFail_Alloc
       STRNE   r0, [stack]
       Pull   "r0, PC", NE                 ; can only retry if ran out of room

       Push    r3                          ; in case extension
       LDR     r1, [stack, #4]
       CMP     r1, #HeapReason_ExtendBlock
       BNE     notsysheapextendblock

       Push   "r5, r6"
       LDR     r5, =SysHeapStart
       LDR     r6, [r5, #:INDEX:hpdbase]
       ADD     r6, r6, r5                  ; free space
       LDR     r1, [r2, #-4]               ; pick up block size
       ADD     r5, r1, r2                  ; block end +4
       SUB     r5, r5, #4                  ; TMD 02-Aug-93: block size includes size field (optimisation was never taken)
       CMP     r5, r6                      ; does block butt against end?
       ADDNE   r3, r3, r1                  ; max poss size needed
       Pull   "r5, r6"

  ; note that this doesn't cope well with a block at the end preceded by a
  ; free block, but tough.

notsysheapextendblock
       LDR     r1, =SysHeapStart
       LDR     R0, hpdbase
       LDR     R1, hpdend
       SUB     R1, R1, R0          ; size left in heap
       SUB     R1, R3, R1          ; size needed
       Pull    r3
       ADD     R1, R1, #8          ; plus safety space.
       MOV     R0, #0
       SWI     XOS_ChangeDynamicArea
       LDRVC   R0, [stack]  ; and retry.
       LDRVC   R1, =SysHeapStart
       SWIVC   XOS_Heap
       Pull   "R0, PC", VC
SysClaimFail
       ADD     stack, stack, #4
       ADR     R0, ErrorBlock_SysHeapFull
     [ International
       BL      TranslateError
     ]
       Pull   "PC"
       MakeErrorBlock  SysHeapFull

;**************************************************************************
;
;       FreeSysHeapNode - Free a node in system heap
;
; in:   R2 -> node to free
;
; out:  R0 = HeapReason_Free or pointer to error if V=1
;       R1 = SysHeapStart
;

FreeSysHeapNode Entry
        MOV     R0, #HeapReason_Free
        LDR     R1, =SysHeapStart
        SWI     XOS_Heap
        EXIT

;**************************************************************************

; ValidateAddress_Code
; R0, R1 are limits of address range to check
; return CC for OK, CS for naff

ValidateAddress_Code ROUT
        Push    "r0-r3, lr"
        MOV     r2, r1
        MOV     r1, r0
        MOV     r0, #24
        SWI     XOS_Memory
        ; Pre-RISC OS 3.5, OS_ValidateAddress would return OK if the region was:
        ; (a) valid RAM in logical address space
        ; (b) the 2nd mapping of screen memory at the start of physical address space
        ; (c) anything claimed by Service_ValidateAddress
        ;
        ; Post-RISC OS 3.5, OS_ValidateAddress would return OK if the region was:
        ; (a) a dynamic area
        ; (b) screen memory
        ; (c) most special areas
        ; (d) anything claimed by Service_ValidateAddress
        ;
        ; RISC OS Select docs suggest that valid regions for their version are:
        ; (a) dynamic areas, including special areas which have been turned into DAs (e.g. ROM)
        ; (b) some special areas (e.g. zero page)
        ; (c) screen memory
        ; (d) anything claimed by Service_ValidateAddress (example given of sparse DA which uses OS_AbortTrap to map pages on demand)
        ; (e) NOT physically mapped areas (unless screen memory)
        ;
        ; Taking the above into account, our version will behave as follows:
        ; (a) anything completely accessible in any mode, which isn't physically mapped - dynamic areas, special areas, ROM, zero page, etc.
        ; (b) anything completely R/W in user mode, which is completely physically mapped (i.e. screen memory; this check should suffice until we decide on a better way of flagging screen memory/"IO RAM" as valid)
        ; (c) anything claimed by Service_ValidateAddress
        TST     r1, #CMA_Partially_Phys
        MOVEQ   r2, #1
        ANDEQ   r1, r1, #CMA_Completely_UserR+CMA_Completely_UserW+CMA_Completely_PrivR+CMA_Completely_PrivW
        LDRNE   r2, =CMA_Completely_UserR+CMA_Completely_UserW+CMA_Completely_Phys
        ANDNE   r1, r1, r2
        CMP     r1, r2
        BHS     AddressIsValid ; EQ case: At least one completely flag set
                               ; NE case: Flags match required value
        ; OS_Memory check failed, try the service call
        LDMIA   sp, {r2-r3}
        MOV     r1, #Service_ValidateAddress
        BL      Issue_Service
        TEQ     r1, #0                  ; EQ => service claimed, so OK
        Pull    "r0-r3,lr"
        ORRNE   lr, lr, #C_bit          ; return CS if invalid
        BICEQ   lr, lr, #C_bit          ; return CC if valid
        ExitSWIHandler

AddressIsValid
        Pull    "r0-r3,lr"
        BIC     lr, lr, #C_bit
        ExitSWIHandler        


        LTORG

        END
