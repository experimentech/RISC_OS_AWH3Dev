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
; > ExtraSWIs

;----------------------------------------------------------------------------------------
; ClaimProcVecSWI
;
;       In:     r0 = vector and flags
;                       bit     meaning
;                       0-7     vector number
;                               0 = 'Branch through 0' vector
;                               1 = Undefined instruction
;                               2 = SWI
;                               3 = Prefetch abort
;                               4 = Data abort
;                               5 = Address exception (only on ARM 2 & 3)
;                               6 = IRQ
;                               7+ = reserved for future use
;                       8       0 = release
;                               1 = claim
;                       9-31    reserved (set to 0)
;               r1 = replacement value
;               r2 = value which should currently be on vector (only needed for release)
;
;       Out:    r1 = value which has been replaced (only returned on claim)
;
;       Allows a module to attach itself to one of the processor vectors.
;
ClaimProcVecSWI ROUT
        Entry   "r3-r5"

        AND     r3, r0, #&FF            ; Get vector number.
        CMP     r3, #(ProcVec_End-ProcVec_Start):SHR:2
        ADRCSL  r0, ErrorBlock_BadClaimNum
        BCS     %FT30

        MOV     r4, r1                  ; r4 = replacement value
        LDR     r5, =ZeroPage+ProcVec_Start
        PHPSEI                          ; Disable IRQs while we mess around with vectors.

        TST     r0, #1:SHL:8
        LDRNE   r1, [r5, r3, LSL #2]!   ; If claiming then return current value (r5->vector to replace).
        BNE     %FT10

        LDR     r3, [r5, r3, LSL #2]!   ; Releasing so get current value (r5->vector to replace).
        TEQ     r2, r3                  ; Make sure it's what the caller thinks it is.
        ADRNEL  r0, ErrorBlock_NaffRelease
        BNE     %FT20
10
        STR     r4, [r5]                ; Store replacement value.
        PLP                             ; Restore IRQs.
        PullEnv
        ExitSWIHandler

20
        PLP                             ; Restore IRQs and return error.
30
  [ International
        BL      TranslateError
  ]
        PullEnv
        B       SLVK_SetV


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_UpdateMEMC: Read/write MEMC1 control register

SSETMEMC ROUT

        AND     r10, r0, r1
        LDR     r12, =ZeroPage
        WritePSRc SVC_mode+I_bit+F_bit, r0
        LDR     r0, [r12, #MEMC_CR_SoftCopy] ; return old value
        BIC     r11, r0, r1
        ORR     r11, r11, R10
        BIC     r11, r11, #&FF000000
        BIC     r11, r11, #&00F00000
        ORR     r11, r11, #MEMCADR
        STR     r11, [r12, #MEMC_CR_SoftCopy]

; mjs Oct 2000 kernel/HAL split
;
; The kernel itself should now never call this SWI, but grudgingly has
; to maintain at least bit 10 of soft copy
;
; Here, we only mimic action of bit 10 to control video/cursor DMA (eg. for ADFS)
; The whole OS_UpdateMEMC thing would ideally be withdrawn as archaic, but
; unfortunately has not even been deprecated up to now

; for reference, the bits of the MEMC1 control register are:
;
; bits 0,1 => unused
; bits 2,3 => page size, irrelevant since always 4K
; bits 4,5 => low ROM access time (mostly irrelevant but set it up anyway)
; bits 6,7 => hi  ROM access time (definitely irrelevant but set it up anyway)
; bits 8,9 => DRAM refresh control
; bit 10   => Video/cursor DMA enable
; bit 11   => Sound DMA enable
; bit 12   => OS mode

        Push  "r0,r1,r4, r14"
        TST   r11, #(1 :SHL: 10)
        MOVEQ r0, #1             ; blank (video DMA disable)
        MOVNE r0, #0             ; unblank (video DMA enable)
        MOV   r1, #0             ; no funny business with DPMS
        ADD   r4, r12, #VduDriverWorkSpace
        LDR   r4, [r4, #CurrentGraphicsVDriver]
        MOV   r4, r4, LSL #24
        ORR   r4, r4, #GraphicsV_SetBlank
        BL    CallGraphicsV
        Pull  "r0,r1,r4, r14"

        WritePSRc SVC_mode+I_bit, r11
        ExitSWIHandler


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       SWI OS_MMUControl
;
; in:   r0 = 0 (reason code 0, for modify control register)
;       r1 = EOR mask
;       r2 = AND mask
;
;       new control = ((old control AND r2) EOR r1)
;
; out:  r1 = old value
;       r2 = new value
;
; in:   r0 bits 1 to 28 = 0, bit 0 = 1  (reason code 1, for flush request)
;          r0 bit 31 set if cache(s) to be flushed
;          r0 bit 30 set if TLB(s) to be flushed
;          r0 bit 29 set if flush of entry only (else whole flush)
;          r0 bit 28 set if write buffer to be flushed (implied by bit 31)
;       r1 = entry specifier, if r0 bit 29 set
;       (currently, flushing by entry is ignored, and just does full flush)
;
; in:   r0 bits 0-7 = 2: reason code 2, read ARMop
;          r0 bits 15-8 = ARMop index
;
; out:  r0 = ARMop function ptr
;

MMUControlSWI   Entry
        BL      MMUControlSub
        PullEnv
        ORRVS   lr, lr, #V_bit
        ExitSWIHandler

MMUControlSub
        Push    lr
        AND     lr,r0,#&FF
        CMP     lr, #MMUCReason_Unknown
        ADDCC   pc, pc, lr, LSL #2
        B       MMUControl_Unknown
        B       MMUControl_ModifyControl ; -> See $MEMM_Type file
        B       MMUControl_Flush
        B       MMUControl_GetARMop

MMUControl_Unknown
        ADRL    r0, ErrorBlock_HeapBadReason
 [ International
        BL      TranslateError
 |
        SETV
 ]
        Pull    "pc"

MMUControl_Flush
        MOVS    r10, r0
        LDR     r12, =ZeroPage
        ARMop   Cache_CleanInvalidateAll,MI,,r12
        TST     r10,#&40000000
        ARMop   TLB_InvalidateAll,NE,,r12
        TST     r10,#&10000000
        ARMop   DSB_ReadWrite,NE,,r12
        ADDS    r0,r10,#0
        Pull    "pc"

MMUControl_GetARMop
        AND     r0, r0, #&FF00
        CMP     r0, #(ARMopPtrTable_End-ARMopPtrTable):SHL:6
        BHS     MMUControl_Unknown
        ADRL    lr, ARMopPtrTable
        LDR     r0, [lr, r0, LSR #6]
        LDR     r0, [r0]
        Pull    "pc"

;
; ---------------- XOS_SynchroniseCodeAreas implementation ---------------
;

;this SWI effectively implements IMB and IMBrange (Instruction Memory Barrier)
;for newer ARMs

;entry:
;   R0 = flags
;        bit 0 set ->  R1,R2 specify virtual address range to synchronise
;                      R1 = start address (word aligned, inclusive)
;                      R2 = end address (word aligned, inclusive)
;        bit 0 clear   synchronise entire virtual space
;        bits 1..31    reserved
;
;exit:
;   R0-R2 preserved
;
SyncCodeAreasSWI ROUT
        Push    "lr"
        BL      SyncCodeAreas
        Pull    "lr"                    ; no error return possible
        B       SLVK

SyncCodeAreas
        TST     R0,#1                   ; range variant of SWI?
        BEQ     SyncCodeAreasFull

SyncCodeAreasRange
        Push    "r0-r2, lr"
        MOV     r0, r1
        ADD     r1, r2, #4                 ;exclusive end address
        LDR     r2, =ZeroPage
        LDRB    lr, [r2, #Cache_Type]
        CMP     lr, #CT_ctype_WB_CR7_Lx ; DCache_LineLen lin or log?
        LDRB    lr, [r2, #DCache_LineLen]
        MOVEQ   r2, #4
        MOVEQ   lr, r2, LSL lr
        LDREQ   r2, =ZeroPage
        SUB     lr, lr, #1
        ADD     r1, r1, lr                 ;rounding up end address
        MVN     lr, lr
        AND     r0, r0, lr                 ;cache line aligned
        AND     r1, r1, lr                 ;cache line aligned
        ARMop   IMB_Range,,,r2
        Pull    "r0-r2, pc"

SyncCodeAreasFull
        Push    "r0, lr"
        LDR     r0, =ZeroPage
        ARMop   IMB_Full,,,r0
        Pull    "r0, pc"

        LTORG

        END
