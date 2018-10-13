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
  ;      GET     Hdr:ListOpts
  ;      GET     Hdr:Macros
  ;      GET     Hdr:System
  ;      $GetCPU
  ;      $GetMEMM

  ;      GET     hdr.Options

  ;      GET     Hdr:PublicWS
  ;      GET     Hdr:KernelWS

  ;      GET     hdr.Copro15ops
  ;      GET     hdr.ARMops

v7      RN      10

  ;      EXPORT  Init_ARMarch
  ;      EXPORT  ARM_Analyse
  ;      EXPORT  ARM_PrintProcessorType

 ;       AREA    KernelCode,CODE,READONLY

; ARM keep changing their mind about ID field layout.
; Here's a summary, courtesy of the ARM ARM:
;
; pre-ARM 7:   xxxx0xxx
; ARM 7:       xxxx7xxx where bit 23 indicates v4T/~v3
; post-ARM 7:  xxxanxxx where n<>0 or 7 and a = architecture (1=v4,2=v4T,3=v5,4=v5T,5=v5TE,6=v5TEJ,7=v6)
;

; int Init_ARMarch(void)
; Returns architecture, as above in a1. Also EQ if ARMv3, NE if ARMv4 or later.
; Corrupts only ip, no RAM usage.
Init_ARMarch
        ARM_read_ID ip
        ANDS    a1, ip, #&0000F000
        MOVEQ   pc, lr                          ; ARM 3 or ARM 6
        TEQ     a1, #&00007000
        BNE     %FT20
        TST     ip, #&00800000                  ; ARM 7 - check for Thumb
        MOVNE   a1, #ARMv4T
        MOVEQ   a1, #ARMv3
        MOV     pc, lr
20      ANDS    a1, ip, #&000F0000              ; post-ARM 7
        MOV     a1, a1, LSR #16
        MOV     pc, lr

; Called pre-MMU to set up some (temporary) PCBTrans and PPLTrans pointers,
; and the initial PageTable_PageFlags value
; Also used post-MMU for VMSAv6 case
; In:
;   a1 -> ZeroPage
; Out:
;   a1-a4, ip corrupt
Init_PCBTrans   ROUT
        LDR     a2, =AreaFlags_PageTablesAccess :OR: DynAreaFlags_NotCacheable :OR: DynAreaFlags_NotBufferable
        STR     a2, [a1, #PageTable_PageFlags]
 [ MEMM_Type = "VMSAv6"
        ADRL    a2, XCBTableVMSAv6
        STR     a2, [a1, #MMU_PCBTrans]

        ; Use shareable pages if we're a multicore chip
        ; N.B. it's important that we get this correct - single-core chips may
        ; treat shareable memory as non-cacheable (e.g. ARM11)

        ADRL    a4, PPLTransNonShareable
        ; Look at the cache type register to work out whether this is ARMv6 or ARMv7+
        MRC     p15, 0, a2, c0, c0, 1   ; Cache type register
        TST     a2, #1<<31              ; EQ = ARMv6, NE = ARMv7+
        MRC     p15, 0, a2, c0, c0, 5   ; MPIDR
        BNE     %FT50
        MRC     p15, 0, a3, c0, c0, 0   ; ARMv6: MPIDR is optional, so compare value against MIDR to see if it's implemented. There's no multiprocessing extensions flag so assume the check against MIDR will be good enough.
        TEQ     a2, a3
        ADDNE   a4, a4, #PPLTransShareable-PPLTransNonShareable
        B       %FT90
50
        AND     a2, a2, #&c0000000      ; ARMv7+: MPIDR is mandatory, but multicore not guaranteed. Check if multiprocessing extensions implemented (bit 31 set), and not uniprocessor (bit 30 clear).
        TEQ     a2, #&80000000
        ADDEQ   a4, a4, #PPLTransShareable-PPLTransNonShareable
90
        STR     a4, [a1, #MMU_PPLTrans]
 |
        ; Detecting the right PCBTrans table to use is complex
        ; However we know that, pre-MMU, we only use the default cache policy,
        ; and we don't use CNB memory
        ; So just go for a safe PCBTrans, like SA110, and the non-extended
        ; PPLTrans
        ADRL    a2, XCBTableSA110
        STR     a2, [a1, #MMU_PCBTrans]
        ADRL    a2, PPLTrans
     [ ARM6support
        ARM_6   a3
        ADDEQ   a2, a2, #PPLTransARM6-PPLTrans
     ]
        STR     a2, [a1, #MMU_PPLTrans]
 ]
        MOV     pc, lr

ARM_Analyse
        MOV     a2, lr
        BL      Init_ARMarch
        MOV     lr, a2
 [ MEMM_Type = "VMSAv6"
        CMP     a1, #ARMvF
        BEQ     ARM_Analyse_Fancy ; New ARM; use the feature regs to perform all the setup
 ]
        Push    "v1,v2,v5,v6,v7,lr"
        ARM_read_ID v1
        ARM_read_cachetype v2
        LDR     v6, =ZeroPage

        ADRL    v7, KnownCPUTable
FindARMloop
        LDMIA   v7!, {a1, a2}                   ; See if it's a known ARM
        CMP     a1, #-1
        BEQ     %FT20
        AND     a2, v1, a2
        TEQ     a1, a2
        ADDNE   v7, v7, #8
        BNE     FindARMloop
        TEQ     v2, v1                          ; If we don't have cache attributes, read from table
        LDREQ   v2, [v7]

20      TEQ     v2, v1
        BEQ     %BT20                           ; Cache unknown: panic

        CMP     a1, #-1
        LDRNEB  a2, [v7, #4]
        MOVEQ   a2, #ARMunk
        STRB    a2, [v6, #ProcessorType]

        ASSERT  CT_Isize_pos = 0
        MOV     a1, v2
        ADD     a2, v6, #ICache_Info
        BL      EvaluateCache
        MOV     a1, v2, LSR #CT_Dsize_pos
        ADD     a2, v6, #DCache_Info
        BL      EvaluateCache

        AND     a1, v2, #CT_ctype_mask
        MOV     a1, a1, LSR #CT_ctype_pos
        STRB    a1, [v6, #Cache_Type]

        MOV     v5, #CPUFlag_32bitOS
        [ HiProcVecs
        ORR     v5, v5, #CPUFlag_HiProcVecs
        ]

        TST     v2, #CT_S
        ORRNE   v5, v5, #CPUFlag_SplitCache+CPUFlag_SynchroniseCodeAreas

        [ CacheOff
        ORR     v5, v5, #CPUFlag_SynchroniseCodeAreas
        |
        ARM_read_control a1                     ; if Z bit set then we have branch prediction,
        TST     a1, #MMUC_Z                     ; so we need OS_SynchroniseCodeAreas even if not
        ORRNE   v5, v5, #CPUFlag_SynchroniseCodeAreas   ; split caches
        ]

        ; Test abort timing (base restored or base updated)
        MOV     a1, #&8000
        LDR     a2, [a1], #4                    ; Will abort - DAb handler will continue execution
        TEQ     a1, #&8000
        ORREQ   v5, v5, #CPUFlag_BaseRestored

        ; Check store of PC
30      STR     pc, [sp, #-4]!
        ADR     a2, %BT30 + 8
        LDR     a1, [sp], #4
        TEQ     a1, a2
        ORREQ   v5, v5, #CPUFlag_StorePCplus8

35

        BL      Init_ARMarch
        STRB    a1, [v6, #ProcessorArch]

        TEQ     a1, #ARMv3                      ; assume long multiply available
        ORRNE   v5, v5, #CPUFlag_LongMul        ; if v4 or later
        TEQNE   a1, #ARMv4                      ; assume 26-bit available
        ORRNE   v5, v5, #CPUFlag_No26bitMode    ; iff v3 or v4 (not T)
        TEQNE   a1, #ARMv5                      ; assume Thumb available
        ORRNE   v5, v5, #CPUFlag_Thumb          ; iff not v3,v4,v5

        MSR     CPSR_f, #Q32_bit
        MRS     lr, CPSR
        TST     lr, #Q32_bit
        ORRNE   v5, v5, #CPUFlag_DSP

        TEQ     a1, #ARMv6
        ORREQ   v5, v5, #CPUFlag_LoadStoreEx    ; Implicit clear of CPUFlag_NoSWP for <= ARMv6

        LDRB    v4, [v6, #ProcessorType]

        TEQ     v4, #ARMunk                     ; Modify deduced flags
        ADRNEL  lr, KnownCPUFlags
        ADDNE   lr, lr, v4, LSL #3
        LDMNEIA lr, {a2, a3}
        ORRNE   v5, v5, a2
        BICNE   v5, v5, a3

 [ XScaleJTAGDebug
        TST     v5, #CPUFlag_XScale
        BEQ     %FT40

        MRC     p14, 0, a2, c10, c0             ; Read debug control register
        TST     a2, #&80000000
        ORRNE   v5, v5, #CPUFlag_XScaleJTAGconnected
        MOVEQ   a2, #&C000001C                  ; enable hot debug
        MCREQ   p14, 0, a2, c10, c0
        BNE     %FT40
40
 ]

        ORR     v5, v5, #CPUFlag_ExtraReasonCodesFixed
        STR     v5, [v6, #ProcessorFlags]

        ; Now, a1 = processor architecture (ARMv3, ARMv4 ...)
        ;      v4 = processor type (ARM600, ARM610, ...)
        ;      v5 = processor flags

        LDRB    a2, [v6, #Cache_Type]

 [ MEMM_Type = "ARM600"
        CMP     a1, #ARMv4
        BLO     Analyse_ARMv3                   ; eg. ARM710

        TEQ     a2, #CT_ctype_WT
        TSTEQ   v5, #CPUFlag_SplitCache
        BEQ     Analyse_WriteThroughUnified     ; eg. ARM7TDMI derivative

        TEQ     a2, #CT_ctype_WB_Crd
        BEQ     Analyse_WB_Crd                  ; eg. StrongARM

        TEQ     a2, #CT_ctype_WB_Cal_LD
        BEQ     Analyse_WB_Cal_LD               ; assume XScale
 ] ; MEMM_Type = "ARM600"

        TEQ     a2, #CT_ctype_WB_CR7_LDa
        BEQ     Analyse_WB_CR7_LDa              ; eg. ARM9

        ; others ...

WeirdARMPanic
        B       WeirdARMPanic                   ; stiff :)

 [ MEMM_Type = "ARM600"
Analyse_ARMv3
        ADRL    a1, NullOp
        ADRL    a2, Cache_Invalidate_ARMv3
        ADRL    a3, DSB_ReadWrite_ARMv3
        ADRL    a4, TLB_Invalidate_ARMv3
        ADRL    ip, TLB_InvalidateEntry_ARMv3

        STR     a1, [v6, #Proc_Cache_CleanAll]
        STR     a1, [v6, #Proc_Cache_CleanRange]
        STR     a2, [v6, #Proc_Cache_CleanInvalidateAll]
        STR     a2, [v6, #Proc_Cache_CleanInvalidateRange]
        STR     a2, [v6, #Proc_Cache_InvalidateAll]
        STR     a2, [v6, #Proc_Cache_InvalidateRange]
        STR     a1, [v6, #Proc_ICache_InvalidateAll]
        STR     a1, [v6, #Proc_ICache_InvalidateRange]
        STR     a3, [v6, #Proc_DSB_ReadWrite]
        STR     a3, [v6, #Proc_DSB_Write]
        STR     a1, [v6, #Proc_DSB_Read]
        STR     a3, [v6, #Proc_DMB_ReadWrite]
        STR     a3, [v6, #Proc_DMB_Write]
        STR     a1, [v6, #Proc_DMB_Read]
        STR     a4, [v6, #Proc_TLB_InvalidateAll]
        STR     ip, [v6, #Proc_TLB_InvalidateEntry]
        STR     a1, [v6, #Proc_IMB_Full]
        STR     a1, [v6, #Proc_IMB_Range]
        STR     a1, [v6, #Proc_IMB_List]

        ADRL    a1, MMU_Changing_ARMv3
        ADRL    a2, MMU_ChangingEntry_ARMv3
        ADRL    a3, MMU_ChangingUncached_ARMv3
        ADRL    a4, MMU_ChangingUncachedEntry_ARMv3
        STR     a1, [v6, #Proc_MMU_Changing]
        STR     a2, [v6, #Proc_MMU_ChangingEntry]
        STR     a3, [v6, #Proc_MMU_ChangingUncached]
        STR     a4, [v6, #Proc_MMU_ChangingUncachedEntry]

        ADRL    a1, MMU_ChangingEntries_ARMv3
        ADRL    a2, MMU_ChangingUncachedEntries_ARMv3
        ADRL    a3, Cache_RangeThreshold_ARMv3
        ADRL    a4, Cache_Examine_Simple
        STR     a1, [v6, #Proc_MMU_ChangingEntries]
        STR     a2, [v6, #Proc_MMU_ChangingUncachedEntries]
        STR     a3, [v6, #Proc_Cache_RangeThreshold]
        STR     a4, [v6, #Proc_Cache_Examine]

        ADRL    a1, XCBTableWT
        STR     a1, [v6, #MMU_PCBTrans]
        B       %FT90

Analyse_WriteThroughUnified
        ADRL    a1, NullOp
        ADRL    a2, Cache_InvalidateUnified
        TST     v5, #CPUFlag_NoWBDrain
        ADRNEL  a3, DSB_ReadWrite_OffOn
        ADREQL  a3, DSB_ReadWrite
        ADRL    a4, TLB_Invalidate_Unified
        ADRL    ip, TLB_InvalidateEntry_Unified

        STR     a1, [v6, #Proc_Cache_CleanAll]
        STR     a1, [v6, #Proc_Cache_CleanRange]
        STR     a2, [v6, #Proc_Cache_CleanInvalidateAll]
        STR     a2, [v6, #Proc_Cache_CleanInvalidateRange]
        STR     a2, [v6, #Proc_Cache_InvalidateAll]
        STR     a2, [v6, #Proc_Cache_InvalidateRange]
        STR     a1, [v6, #Proc_ICache_InvalidateAll]
        STR     a1, [v6, #Proc_ICache_InvalidateRange]
        STR     a3, [v6, #Proc_DSB_ReadWrite]
        STR     a3, [v6, #Proc_DSB_Write]
        STR     a1, [v6, #Proc_DSB_Read]
        STR     a3, [v6, #Proc_DMB_ReadWrite]
        STR     a3, [v6, #Proc_DMB_Write]
        STR     a1, [v6, #Proc_DMB_Read]
        STR     a4, [v6, #Proc_TLB_InvalidateAll]
        STR     ip, [v6, #Proc_TLB_InvalidateEntry]
        STR     a1, [v6, #Proc_IMB_Full]
        STR     a1, [v6, #Proc_IMB_Range]
        STR     a1, [v6, #Proc_IMB_List]

        ADRL    a1, MMU_Changing_Writethrough
        ADRL    a2, MMU_ChangingEntry_Writethrough
        ADRL    a3, MMU_ChangingUncached
        ADRL    a4, MMU_ChangingUncachedEntry
        STR     a1, [v6, #Proc_MMU_Changing]
        STR     a2, [v6, #Proc_MMU_ChangingEntry]
        STR     a3, [v6, #Proc_MMU_ChangingUncached]
        STR     a4, [v6, #Proc_MMU_ChangingUncachedEntry]

        ADRL    a1, MMU_ChangingEntries_Writethrough
        ADRL    a2, MMU_ChangingUncachedEntries
        ADRL    a3, Cache_RangeThreshold_Writethrough
        ADRL    a4, Cache_Examine_Simple
        STR     a1, [v6, #Proc_MMU_ChangingEntries]
        STR     a2, [v6, #Proc_MMU_ChangingUncachedEntries]
        STR     a3, [v6, #Proc_Cache_RangeThreshold]
        STR     a4, [v6, #Proc_Cache_Examine]

        ADRL    a1, XCBTableWT
        STR     a1, [v6, #MMU_PCBTrans]
        B       %FT90
 ] ; MEMM_Type = "ARM600"

Analyse_WB_CR7_LDa
        TST     v5, #CPUFlag_SplitCache
        BEQ     WeirdARMPanic             ; currently, only support harvard caches here (eg. ARM920)

        ADRL    a1, Cache_CleanInvalidateAll_WB_CR7_LDa
        STR     a1, [v6, #Proc_Cache_CleanInvalidateAll]

        ADRL    a1, Cache_CleanInvalidateRange_WB_CR7_LDa
        STR     a1, [v6, #Proc_Cache_CleanInvalidateRange]

        ADRL    a1, Cache_CleanAll_WB_CR7_LDa
        STR     a1, [v6, #Proc_Cache_CleanAll]

        ADRL    a1, Cache_CleanRange_WB_CR7_LDa
        STR     a1, [v6, #Proc_Cache_CleanRange]

        ADRL    a1, Cache_InvalidateAll_WB_CR7_LDa
        STR     a1, [v6, #Proc_Cache_InvalidateAll]

        ADRL    a1, Cache_InvalidateRange_WB_CR7_LDa
        STR     a1, [v6, #Proc_Cache_InvalidateRange]

        ADRL    a1, Cache_RangeThreshold_WB_CR7_LDa
        STR     a1, [v6, #Proc_Cache_RangeThreshold]

        ADRL    a1, Cache_Examine_Simple
        STR     a1, [v6, #Proc_Cache_Examine]

        ADRL    a1, ICache_InvalidateAll_WB_CR7_LDa
        STR     a1, [v6, #Proc_ICache_InvalidateAll]

        ADRL    a1, ICache_InvalidateRange_WB_CR7_LDa
        STR     a1, [v6, #Proc_ICache_InvalidateRange]

        ADRL    a1, TLB_InvalidateAll_WB_CR7_LDa
        STR     a1, [v6, #Proc_TLB_InvalidateAll]

        ADRL    a1, TLB_InvalidateEntry_WB_CR7_LDa
        STR     a1, [v6, #Proc_TLB_InvalidateEntry]

 [ MEMM_Type = "ARM600"
        ; <= ARMv5, just use the drain write buffer MCR
        ADRL    a1, DSB_ReadWrite_WB_CR7_LDa
        ADRL    a2, NullOp
        STR     a1, [v6, #Proc_DSB_ReadWrite]
        STR     a1, [v6, #Proc_DSB_Write]
        STR     a2, [v6, #Proc_DSB_Read]
        STR     a1, [v6, #Proc_DMB_ReadWrite]
        STR     a1, [v6, #Proc_DMB_Write]
        STR     a2, [v6, #Proc_DMB_Read]
 |
        ; ARMv6(+), use the ARMv6 barrier MCRs
        ADRL    a1, DSB_ReadWrite_ARMv6
        STR     a1, [v6, #Proc_DSB_ReadWrite]
        STR     a1, [v6, #Proc_DSB_Write]
        STR     a1, [v6, #Proc_DSB_Read]
        ADRL    a1, DMB_ReadWrite_ARMv6
        STR     a1, [v6, #Proc_DMB_ReadWrite]
        STR     a1, [v6, #Proc_DMB_Write]
        STR     a1, [v6, #Proc_DMB_Read]
 ]

        ADRL    a1, IMB_Full_WB_CR7_LDa
        STR     a1, [v6, #Proc_IMB_Full]

        ADRL    a1, IMB_Range_WB_CR7_LDa
        STR     a1, [v6, #Proc_IMB_Range]

        ADRL    a1, IMB_List_WB_CR7_LDa
        STR     a1, [v6, #Proc_IMB_List]

        ADRL    a1, MMU_Changing_WB_CR7_LDa
        STR     a1, [v6, #Proc_MMU_Changing]

        ADRL    a1, MMU_ChangingEntry_WB_CR7_LDa
        STR     a1, [v6, #Proc_MMU_ChangingEntry]

        ADRL    a1, MMU_ChangingUncached_WB_CR7_LDa
        STR     a1, [v6, #Proc_MMU_ChangingUncached]

        ADRL    a1, MMU_ChangingUncachedEntry_WB_CR7_LDa
        STR     a1, [v6, #Proc_MMU_ChangingUncachedEntry]

        ADRL    a1, MMU_ChangingEntries_WB_CR7_LDa
        STR     a1, [v6, #Proc_MMU_ChangingEntries]

        ADRL    a1, MMU_ChangingUncachedEntries_WB_CR7_LDa
        STR     a1, [v6, #Proc_MMU_ChangingUncachedEntries]

        LDRB    a2, [v6, #DCache_Associativity]

        MOV     a3, #256
        MOV     a4, #8           ; to find log2(ASSOC), rounded up
Analyse_WB_CR7_LDa_L1
        MOV     a3, a3, LSR #1
        SUB     a4, a4, #1
        CMP     a2, a3
        BLO     Analyse_WB_CR7_LDa_L1
        ADDHI   a4, a4, #1

        RSB     a2, a4, #32
        MOV     a3, #1
        MOV     a3, a3, LSL a2
        STR     a3, [v6, #DCache_IndexBit]
        LDR     a4, [v6, #DCache_NSets]
        LDRB    a2, [v6, #DCache_LineLen]
        SUB     a4, a4, #1
        MUL     a4, a2, a4
        STR     a4, [v6, #DCache_IndexSegStart]

        MOV     a2, #64*1024                         ; arbitrary-ish
        STR     a2, [v6, #DCache_RangeThreshold]

 [ MEMM_Type = "ARM600"
        ADRL    a1, XCBTableWBR                      ; assume read-allocate WB/WT cache
        STR     a1, [v6, #MMU_PCBTrans]
 ]

        B       %FT90

 [ MEMM_Type = "ARM600"
Analyse_WB_Crd
        TST     v5, #CPUFlag_SplitCache
        BEQ     WeirdARMPanic             ; currently, only support harvard

        ADRL    a1, Cache_CleanInvalidateAll_WB_Crd
        STR     a1, [v6, #Proc_Cache_CleanInvalidateAll]

        ADRL    a1, Cache_CleanInvalidateRange_WB_Crd
        STR     a1, [v6, #Proc_Cache_CleanInvalidateRange]

        ADRL    a1, Cache_CleanAll_WB_Crd
        STR     a1, [v6, #Proc_Cache_CleanAll]

        ADRL    a1, Cache_CleanRange_WB_Crd
        STR     a1, [v6, #Proc_Cache_CleanRange]

        ADRL    a1, Cache_InvalidateAll_WB_Crd
        STR     a1, [v6, #Proc_Cache_InvalidateAll]

        ADRL    a1, Cache_InvalidateRange_WB_Crd
        STR     a1, [v6, #Proc_Cache_InvalidateRange]

        ADRL    a1, Cache_RangeThreshold_WB_Crd
        STR     a1, [v6, #Proc_Cache_RangeThreshold]

        ADRL    a1, Cache_Examine_Simple
        STR     a1, [v6, #Proc_Cache_Examine]

        ADRL    a1, ICache_InvalidateAll_WB_Crd
        STR     a1, [v6, #Proc_ICache_InvalidateAll]

        ADRL    a1, ICache_InvalidateRange_WB_Crd
        STR     a1, [v6, #Proc_ICache_InvalidateRange]

        ADRL    a1, TLB_InvalidateAll_WB_Crd
        STR     a1, [v6, #Proc_TLB_InvalidateAll]

        ADRL    a1, TLB_InvalidateEntry_WB_Crd
        STR     a1, [v6, #Proc_TLB_InvalidateEntry]

        ADRL    a1, DSB_ReadWrite_WB_Crd
        ADRL    a2, NullOp
        STR     a1, [v6, #Proc_DSB_ReadWrite]
        STR     a1, [v6, #Proc_DSB_Write]
        STR     a2, [v6, #Proc_DSB_Read]
        STR     a1, [v6, #Proc_DMB_ReadWrite]
        STR     a1, [v6, #Proc_DMB_Write]
        STR     a2, [v6, #Proc_DMB_Read]

        ADRL    a1, IMB_Full_WB_Crd
        STR     a1, [v6, #Proc_IMB_Full]

        ADRL    a1, IMB_Range_WB_Crd
        STR     a1, [v6, #Proc_IMB_Range]

        ADRL    a1, IMB_List_WB_Crd
        STR     a1, [v6, #Proc_IMB_List]

        ADRL    a1, MMU_Changing_WB_Crd
        STR     a1, [v6, #Proc_MMU_Changing]

        ADRL    a1, MMU_ChangingEntry_WB_Crd
        STR     a1, [v6, #Proc_MMU_ChangingEntry]

        ADRL    a1, MMU_ChangingUncached_WB_Crd
        STR     a1, [v6, #Proc_MMU_ChangingUncached]

        ADRL    a1, MMU_ChangingUncachedEntry_WB_Crd
        STR     a1, [v6, #Proc_MMU_ChangingUncachedEntry]

        ADRL    a1, MMU_ChangingEntries_WB_Crd
        STR     a1, [v6, #Proc_MMU_ChangingEntries]

        ADRL    a1, MMU_ChangingUncachedEntries_WB_Crd
        STR     a1, [v6, #Proc_MMU_ChangingUncachedEntries]

        LDR     a2, =DCacheCleanAddress
        STR     a2, [v6, #DCache_CleanBaseAddress]
        STR     a2, [v6, #DCache_CleanNextAddress]
        MOV     a2, #64*1024                       ;arbitrary-ish threshold
        STR     a2, [v6, #DCache_RangeThreshold]

        LDRB    a2, [v6, #ProcessorType]
        TEQ     a2, #SA110
        TEQNE   a2, #SA110_preRevT
        ADREQL  a2, XCBTableSA110
        BEQ     Analyse_WB_Crd_finish
        TEQ     a2, #SA1100
        TEQNE   a2, #SA1110
        ADREQL  a2, XCBTableSA1110
        ADRNEL  a2, XCBTableWBR
Analyse_WB_Crd_finish
        STR     a2, [v6, #MMU_PCBTrans]
        B       %FT90

Analyse_WB_Cal_LD
        TST     v5, #CPUFlag_SplitCache
        BEQ     WeirdARMPanic             ; currently, only support harvard

        ADRL    a1, Cache_CleanInvalidateAll_WB_Cal_LD
        STR     a1, [v6, #Proc_Cache_CleanInvalidateAll]

        ADRL    a1, Cache_CleanInvalidateRange_WB_Cal_LD
        STR     a1, [v6, #Proc_Cache_CleanInvalidateRange]

        ADRL    a1, Cache_CleanAll_WB_Cal_LD
        STR     a1, [v6, #Proc_Cache_CleanAll]

        ADRL    a1, Cache_CleanRange_WB_Cal_LD
        STR     a1, [v6, #Proc_Cache_CleanRange]

        ADRL    a1, Cache_InvalidateAll_WB_Cal_LD
        STR     a1, [v6, #Proc_Cache_InvalidateAll]

        ADRL    a1, Cache_InvalidateRange_WB_Cal_LD
        STR     a1, [v6, #Proc_Cache_InvalidateRange]

        ADRL    a1, Cache_RangeThreshold_WB_Cal_LD
        STR     a1, [v6, #Proc_Cache_RangeThreshold]

        ADRL    a1, Cache_Examine_Simple
        STR     a1, [v6, #Proc_Cache_Examine]

        ADRL    a1, ICache_InvalidateAll_WB_Cal_LD
        STR     a1, [v6, #Proc_ICache_InvalidateAll]

        ADRL    a1, ICache_InvalidateRange_WB_Cal_LD
        STR     a1, [v6, #Proc_ICache_InvalidateRange]

        ADRL    a1, TLB_InvalidateAll_WB_Cal_LD
        STR     a1, [v6, #Proc_TLB_InvalidateAll]

        ADRL    a1, TLB_InvalidateEntry_WB_Cal_LD
        STR     a1, [v6, #Proc_TLB_InvalidateEntry]

        ADRL    a1, DSB_ReadWrite_WB_Cal_LD
        ADRL    a2, NullOp ; Assuming barriers are only used for non-cacheable memory, a read barrier routine isn't necessary on XScale because all non-cacheable reads complete in-order with read/write accesses to other NC locations
        STR     a1, [v6, #Proc_DSB_ReadWrite]
        STR     a1, [v6, #Proc_DSB_Write]
        STR     a2, [v6, #Proc_DSB_Read]
        STR     a1, [v6, #Proc_DMB_ReadWrite]
        STR     a1, [v6, #Proc_DMB_Write]
        STR     a2, [v6, #Proc_DMB_Read]

        ADRL    a1, IMB_Full_WB_Cal_LD
        STR     a1, [v6, #Proc_IMB_Full]

        ADRL    a1, IMB_Range_WB_Cal_LD
        STR     a1, [v6, #Proc_IMB_Range]

        ADRL    a1, IMB_List_WB_Cal_LD
        STR     a1, [v6, #Proc_IMB_List]

        ADRL    a1, MMU_Changing_WB_Cal_LD
        STR     a1, [v6, #Proc_MMU_Changing]

        ADRL    a1, MMU_ChangingEntry_WB_Cal_LD
        STR     a1, [v6, #Proc_MMU_ChangingEntry]

        ADRL    a1, MMU_ChangingUncached_WB_Cal_LD
        STR     a1, [v6, #Proc_MMU_ChangingUncached]

        ADRL    a1, MMU_ChangingUncachedEntry_WB_Cal_LD
        STR     a1, [v6, #Proc_MMU_ChangingUncachedEntry]

        ADRL    a1, MMU_ChangingEntries_WB_Cal_LD
        STR     a1, [v6, #Proc_MMU_ChangingEntries]

        ADRL    a1, MMU_ChangingUncachedEntries_WB_Cal_LD
        STR     a1, [v6, #Proc_MMU_ChangingUncachedEntries]

        LDR     a2, =DCacheCleanAddress
        STR     a2, [v6, #DCache_CleanBaseAddress]
        STR     a2, [v6, #DCache_CleanNextAddress]

  [ XScaleMiniCache
        !       1, "You need to arrange for XScale mini-cache clean area to be mini-cacheable"
        LDR     a2, =DCacheCleanAddress + 4 * 32*1024
        STR     a2, [v6, #MCache_CleanBaseAddress]
        STR     a2, [v6, #MCache_CleanNextAddress]
  ]


  ; arbitrary-ish values, mini cache makes global op significantly more expensive
  [ XScaleMiniCache
        MOV     a2, #128*1024
  |
        MOV     a2, #32*1024
  ]
        STR     a2, [v6, #DCache_RangeThreshold]

        ; enable full coprocessor access
        LDR     a2, =&3FFF
        MCR     p15, 0, a2, c15, c1

        LDR     a2, [v6, #ProcessorFlags]
        TST     a2, #CPUFlag_ExtendedPages
        ADREQL  a2, XCBTableXScaleNoExt
        ADRNEL  a2, XCBTableXScaleWA ; choose between RA and WA here
        STR     a2, [v6, #MMU_PCBTrans]

        B       %FT90
 ] ; MEMM_Type = "ARM600"

 [ MEMM_Type = "VMSAv6"
Analyse_WB_CR7_Lx
        TST     v5, #CPUFlag_SplitCache
        BEQ     WeirdARMPanic             ; currently, only support harvard caches here

        ; Read smallest instruction & data/unified cache line length
        MRC     p15, 0, a1, c0, c0, 1 ; Cache type register
        MOV     v2, a1, LSR #16
        AND     a4, a1, #&F
        AND     v2, v2, #&F
        STRB    a4, [v6, #ICache_LineLen] ; Store log2(line size)-2
        STRB    v2, [v6, #DCache_LineLen] ; log2(line size)-2
        
        ; Read the cache info into Cache_Lx_*
        MRC     p15, 1, a1, c0, c0, 1 ; Cache level ID register
        MOV     v2, v6 ; Work around DTable/ITable alignment issues
        STR     a1, [v2, #Cache_Lx_Info]!
        ADD     a2, v2, #Cache_Lx_DTable-Cache_Lx_Info
        MOV     a3, #0
10
        ANDS    v1, a1, #6 ; Data or unified cache at this level?
        BEQ     %FT11
        MCRNE   p15, 2, a3, c0, c0, 0 ; Program cache size selection register
        myISB   ,v1
        MRCNE   p15, 1, v1, c0, c0, 0 ; Get size info (data/unified)
11      STR     v1, [a2]
        ADD     a3, a3, #1
        ANDS    v1, a1, #1 ; Instruction cache at this level?
        BEQ     %FT12
        MCRNE   p15, 2, a3, c0, c0, 0 ; Program cache size selection register
        myISB   ,v1
        MRCNE   p15, 1, v1, c0, c0, 0 ; Get size info (instruction)
12      STR     v1, [a2, #Cache_Lx_ITable-Cache_Lx_DTable]
        ; Shift the cache level ID register along to get the type of the next
        ; cache level
        ; However, we need to stop once we reach the first blank entry, because
        ; ARM have been sneaky and started to reuse some of the bits from the
        ; high end of the register (the Cortex-A8 TRM lists bits 21-23 as being
        ; for cache level 8, but the ARMv7 ARM lists them as being for the level
        ; of unification for inner shareable memory). The ARMv7 ARM does warn
        ; about making sure you stop once you find the first blank entry, but
        ; it doesn't say why!
        TST     a1, #7
        ADD     a3, a3, #1
        MOVNE   a1, a1, LSR #3
        CMP     a3, #Cache_Lx_MaxLevel*2 ; Stop at the last level we support
        ADD     a2, a2, #4
        BLT     %BT10

        ; Calculate DCache_RangeThreshold
        MOV     a1, #128*1024 ; Arbitrary-ish
        STR     a1, [v6, #DCache_RangeThreshold]        

        ADRL    a1, Cache_CleanInvalidateAll_WB_CR7_Lx
        STR     a1, [v6, #Proc_Cache_CleanInvalidateAll]

        ADRL    a1, Cache_CleanInvalidateRange_WB_CR7_Lx
        STR     a1, [v6, #Proc_Cache_CleanInvalidateRange]

        ADRL    a1, Cache_CleanAll_WB_CR7_Lx
        STR     a1, [v6, #Proc_Cache_CleanAll]

        ADRL    a1, Cache_CleanRange_WB_CR7_Lx
        STR     a1, [v6, #Proc_Cache_CleanRange]

        ADRL    a1, Cache_InvalidateAll_WB_CR7_Lx
        STR     a1, [v6, #Proc_Cache_InvalidateAll]

        ADRL    a1, Cache_InvalidateRange_WB_CR7_Lx
        STR     a1, [v6, #Proc_Cache_InvalidateRange]

        ADRL    a1, Cache_RangeThreshold_WB_CR7_Lx
        STR     a1, [v6, #Proc_Cache_RangeThreshold]

        ADRL    a1, Cache_Examine_WB_CR7_Lx
        STR     a1, [v6, #Proc_Cache_Examine]

        ADRL    a1, ICache_InvalidateAll_WB_CR7_Lx
        STR     a1, [v6, #Proc_ICache_InvalidateAll]

        ADRL    a1, ICache_InvalidateRange_WB_CR7_Lx
        STR     a1, [v6, #Proc_ICache_InvalidateRange]

        ADRL    a1, TLB_InvalidateAll_WB_CR7_Lx
        STR     a1, [v6, #Proc_TLB_InvalidateAll]

        ADRL    a1, TLB_InvalidateEntry_WB_CR7_Lx
        STR     a1, [v6, #Proc_TLB_InvalidateEntry]

        ADRL    a1, DSB_ReadWrite_ARMv7
        ADRL    a2, DSB_Write_ARMv7
        STR     a1, [v6, #Proc_DSB_ReadWrite]
        STR     a2, [v6, #Proc_DSB_Write]
        STR     a1, [v6, #Proc_DSB_Read]

        ADRL    a1, DMB_ReadWrite_ARMv7
        ADRL    a2, DMB_Write_ARMv7
        STR     a1, [v6, #Proc_DMB_ReadWrite]
        STR     a2, [v6, #Proc_DMB_Write]
        STR     a1, [v6, #Proc_DMB_Read]

        ADRL    a1, IMB_Full_WB_CR7_Lx
        STR     a1, [v6, #Proc_IMB_Full]

        ADRL    a1, IMB_Range_WB_CR7_Lx
        STR     a1, [v6, #Proc_IMB_Range]

        ADRL    a1, IMB_List_WB_CR7_Lx
        STR     a1, [v6, #Proc_IMB_List]

        ADRL    a1, MMU_Changing_WB_CR7_Lx
        STR     a1, [v6, #Proc_MMU_Changing]

        ADRL    a1, MMU_ChangingEntry_WB_CR7_Lx
        STR     a1, [v6, #Proc_MMU_ChangingEntry]

        ADRL    a1, MMU_ChangingUncached_WB_CR7_Lx
        STR     a1, [v6, #Proc_MMU_ChangingUncached]

        ADRL    a1, MMU_ChangingUncachedEntry_WB_CR7_Lx
        STR     a1, [v6, #Proc_MMU_ChangingUncachedEntry]

        ADRL    a1, MMU_ChangingEntries_WB_CR7_Lx
        STR     a1, [v6, #Proc_MMU_ChangingEntries]

        ADRL    a1, MMU_ChangingUncachedEntries_WB_CR7_Lx
        STR     a1, [v6, #Proc_MMU_ChangingUncachedEntries]

        B       %FT90
 ] ; MEMM_Type = "VMSAv6"
 
90
 [ MEMM_Type = "VMSAv6"
        ; Reuse Init_PCBTrans
        MOV     a1, v6
        BL      Init_PCBTrans
        ADRL    a1, PPLAccess
        STR     a1, [v6, #MMU_PPLAccess]
 |
        TST     v5, #CPUFlag_ExtendedPages
        ADRNEL  a1, PPLTransX
        ADREQL  a1, PPLTrans
     [ ARM6support
        ARM_6   lr
        ADREQL  a1, PPLTransARM6
     ]
        STR     a1, [v6, #MMU_PPLTrans]
        ADRL    a1, PPLAccess
     [ ARM6support
        ADREQL  a1, PPLAccessARM6
     ]
        STR     a1, [v6, #MMU_PPLAccess]
 ]
        Pull    "v1,v2,v5,v6,v7,pc"


; This routine works out the values LINELEN, ASSOCIATIVITY, NSETS and CACHE_SIZE defined
; in section B2.3.3 of the ARMv5 ARM.
EvaluateCache
        AND     a3, a1, #CT_assoc_mask+CT_M
        TEQ     a3, #(CT_assoc_0:SHL:CT_assoc_pos)+CT_M
        BEQ     %FT80
        MOV     ip, #1
        ASSERT  CT_len_pos = 0
        AND     a4, a1, #CT_len_mask
        ADD     a4, a4, #3
        MOV     a4, ip, LSL a4                  ; LineLen = 1 << (len+3)
        STRB    a4, [a2, #ICache_LineLen-ICache_Info]
        MOV     a3, #2
        TST     a1, #CT_M
        ADDNE   a3, a3, #1                      ; Multiplier = 2 + M
        AND     a4, a1, #CT_assoc_mask
        RSB     a4, ip, a4, LSR #CT_assoc_pos
        MOV     a4, a3, LSL a4                  ; Associativity = Multiplier << (assoc-1)
        STRB    a4, [a2, #ICache_Associativity-ICache_Info]
        AND     a4, a1, #CT_size_mask
        MOV     a4, a4, LSR #CT_size_pos
        MOV     a3, a3, LSL a4
        MOV     a3, a3, LSL #8                  ; Size = Multiplier << (size+8)
        STR     a3, [a2, #ICache_Size-ICache_Info]
        ADD     a4, a4, #6
        AND     a3, a1, #CT_assoc_mask
        SUB     a4, a4, a3, LSR #CT_assoc_pos
        AND     a3, a1, #CT_len_mask
        ASSERT  CT_len_pos = 0
        SUB     a4, a4, a3
        MOV     a4, ip, LSL a4                  ; NSets = 1 << (size + 6 - assoc - len)
        STR     a4, [a2, #ICache_NSets-ICache_Info]
        MOV     pc, lr


80      MOV     a1, #0
        STR     a1, [a2, #ICache_NSets-ICache_Info]
        STR     a1, [a2, #ICache_Size-ICache_Info]
        STRB    a1, [a2, #ICache_LineLen-ICache_Info]
        STRB    a1, [a2, #ICache_Associativity-ICache_Info]
        MOV     pc, lr


; Create a list of CPUs, 16 bytes per entry:
;    ID bits (1 word)
;    Test mask for ID (1 word)
;    Cache type register value (1 word)
;    Processor type (1 byte)
;    Architecture type (1 byte)
;    Reserved (2 bytes)
        GBLA    tempcpu

        MACRO
        CPUDesc $proc, $id, $mask, $arch, $type, $s, $dsz, $das, $dln, $isz, $ias, $iln
        LCLA    type
type    SETA    (CT_ctype_$type:SHL:CT_ctype_pos)+($s:SHL:CT_S_pos)
tempcpu CSzDesc $dsz, $das, $dln
type    SETA    type+(tempcpu:SHL:CT_Dsize_pos)
        [ :LNOT:($s=0 :LAND: "$isz"="")
tempcpu CSzDesc $isz, $ias, $iln
        ]
type    SETA    type+(tempcpu:SHL:CT_Isize_pos)
        ASSERT  ($id :AND: :NOT: $mask) = 0
        DCD     $id, $mask, type
        DCB     $proc, $arch, 0, 0
        MEND

        MACRO
$var    CSzDesc $sz, $as, $ln
$var    SETA    (CT_size_$sz:SHL:CT_size_pos)+(CT_assoc_$as:SHL:CT_assoc_pos)+(CT_len_$ln:SHL:CT_len_pos)
$var    SETA    $var+(CT_M_$sz:SHL:CT_M_pos)
        MEND


; CPUDesc table for ARMv3-ARMv6
KnownCPUTable
;                                                        /------Cache Type register fields-----\.
;                              ID reg   Mask     Arch    Type         S  Dsz Das Dln Isz Ias Iln
 [ MEMM_Type = "ARM600"
        CPUDesc ARM600,        &000600, &00FFF0, ARMv3,   WT,         0,  4K, 64, 4
        CPUDesc ARM610,        &000610, &00FFF0, ARMv3,   WT,         0,  4K, 64, 4
        CPUDesc ARMunk,        &000000, &00F000, ARMv3,   WT,         0,  4K, 64, 4
        CPUDesc ARM700,        &007000, &FFFFF0, ARMv3,   WT,         0,  8K,  4, 8
        CPUDesc ARM710,        &007100, &FFFFF0, ARMv3,   WT,         0,  8K,  4, 8
        CPUDesc ARM710a,       &047100, &FDFFF0, ARMv3,   WT,         0,  8K,  4, 4
        CPUDesc ARM7500,       &027100, &FFFFF0, ARMv3,   WT,         0,  4K,  4, 4
        CPUDesc ARM7500FE,     &077100, &FFFFF0, ARMv3,   WT,         0,  4K,  4, 4
        CPUDesc ARMunk,        &007000, &80F000, ARMv3,   WT,         0,  8K,  4, 4
        CPUDesc ARM720T,       &807200, &FFFFF0, ARMv4T,  WT,         0,  8K,  4, 4
        CPUDesc ARMunk,        &807000, &80F000, ARMv4T,  WT,         0,  8K,  4, 4
        CPUDesc SA110_preRevT, &01A100, &0FFFFC, ARMv4,   WB_Crd,     1, 16K, 32, 8, 16K, 32, 8
        CPUDesc SA110,         &01A100, &0FFFF0, ARMv4,   WB_Crd,     1, 16K, 32, 8, 16K, 32, 8
        CPUDesc SA1100,        &01A110, &0FFFF0, ARMv4,   WB_Crd,     1,  8K, 32, 8, 16K, 32, 8
        CPUDesc SA1110,        &01B110, &0FFFF0, ARMv4,   WB_Crd,     1,  8K, 32, 8, 16K, 32, 8
        CPUDesc ARM920T,       &029200, &0FFFF0, ARMv4T,  WB_CR7_LDa, 1, 16K, 64, 8, 16K, 64, 8
        CPUDesc ARM922T,       &029220, &0FFFF0, ARMv4T,  WB_CR7_LDa, 1,  8K, 64, 8,  8K, 64, 8
        CPUDesc X80200,        &052000, &0FFFF0, ARMv5TE, WB_Cal_LD,  1, 32K, 32, 8, 32K, 32, 8
        CPUDesc X80321,    &69052400, &FFFFF700, ARMv5TE, WB_Cal_LD,  1, 32K, 32, 8, 32K, 32, 8
 ] ; MEMM_Type = "ARM600"
        DCD     -1

 [ MEMM_Type = "VMSAv6"
; Simplified CPUDesc table for ARMvF
; The cache size data is ignored for ARMv7.
KnownCPUTable_Fancy
        CPUDesc ARM1176JZF_S,  &00B760, &00FFF0, ARMvF,   WB_CR7_LDc, 1, 16K,  4, 8, 16K,  4, 8
        CPUDesc Cortex_A5,     &00C050, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 16K, 32,16, 16K, 32,16
        CPUDesc Cortex_A7,     &00C070, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 16K, 32,16, 16K, 32,16
        CPUDesc Cortex_A8,     &00C080, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 16K, 32,16, 16K, 32,16
        CPUDesc Cortex_A9,     &00C090, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 32K, 32,16, 32K, 32,16
        CPUDesc Cortex_A12,    &00C0D0, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 32K, 32,16, 32K, 32,16
        CPUDesc Cortex_A15,    &00C0F0, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 32K, 32,16, 32K, 32,16
        CPUDesc Cortex_A17,    &00C0E0, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 32K, 32,16, 32K, 32,16
        CPUDesc Cortex_A53,    &00D030, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 32K, 32,16, 32K, 32,16
        CPUDesc Cortex_A57,    &00D070, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 32K, 32,16, 32K, 32,16
        CPUDesc Cortex_A72,    &00D080, &00FFF0, ARMvF,   WB_CR7_Lx,  1, 32K, 32,16, 32K, 32,16
        DCD     -1
 ] ; MEMM_Type = "VMSAv6"

; Peculiar characteristics of individual ARMs not deducable otherwise. First field is
; flags to set, second flags to clear.
KnownCPUFlags
        DCD     0,                            0    ; ARM 600
        DCD     0,                            0    ; ARM 610
        DCD     0,                            0    ; ARM 700
        DCD     0,                            0    ; ARM 710
        DCD     0,                            0    ; ARM 710a
        DCD     CPUFlag_AbortRestartBroken+CPUFlag_InterruptDelay,   0    ; SA 110 pre revT
        DCD     CPUFlag_InterruptDelay,       0    ; SA 110 revT or later
        DCD     0,                            0    ; ARM 7500
        DCD     0,                            0    ; ARM 7500FE
        DCD     CPUFlag_InterruptDelay,       0    ; SA 1100
        DCD     CPUFlag_InterruptDelay,       0    ; SA 1110
        DCD     CPUFlag_NoWBDrain,            0    ; ARM 720T
        DCD     0,                            0    ; ARM 920T
        DCD     0,                            0    ; ARM 922T
        DCD     CPUFlag_ExtendedPages+CPUFlag_XScale,  0    ; X80200
        DCD     CPUFlag_XScale,               0    ; X80321
        DCD     0,                            0    ; ARM1176JZF_S
        DCD     0,                            0    ; Cortex_A5
        DCD     0,                            0    ; Cortex_A7
        DCD     0,                            0    ; Cortex_A8
        DCD     0,                            0    ; Cortex_A9
        DCD     0,                            0    ; Cortex_A12
        DCD     CPUFlag_NoDCacheDisable,      0    ; Cortex_A15
        DCD     0,                            0    ; Cortex_A17
        DCD     CPUFlag_NoDCacheDisable,      0    ; Cortex_A53
        DCD     0,                            0    ; Cortex_A57
        DCD     0,                            0    ; Cortex_A72

 [ MEMM_Type = "VMSAv6"
; --------------------------------------------------------------------------
; ----- ARM_Analyse_Fancy --------------------------------------------------
; --------------------------------------------------------------------------
;
; For ARMv7 ARMs (arch=&F), we can detect everything via the feature registers
; TODO - There's some stuff in here that can be tidied up/removed

; Things we need to set up:
; ProcessorType     (as listed in hdr.ARMops)
; Cache_Type        (CT_ctype_* from hdr:MEMM.ARM600)
; ProcessorArch     (as reported by Init_ARMarch)
; ProcessorFlags    (CPUFlag_* from hdr.ARMops)
; Proc_*            (Cache/TLB/IMB/MMU function pointers)
; MMU_PCBTrans      (Points to lookup table for translating page table cache options)
; ICache_*, DCache_* (ICache, DCache properties - optional, since not used externally?)

ARM_Analyse_Fancy
        Push    "v1,v2,v5,v6,v7,lr"
        ARM_read_ID v1
        LDR     v6, =ZeroPage
        ADRL    v7, KnownCPUTable_Fancy
10
        LDMIA   v7!, {a1, a2}
        CMP     a1, #-1
        BEQ     %FT20
        AND     a2, v1, a2
        TEQ     a1, a2
        ADDNE   v7, v7, #8
        BNE     %BT10
20
        LDR     v2, [v7]
        CMP     a1, #-1
        LDRNEB  a2, [v7, #4]
        MOVEQ   a2, #ARMunk
        STRB    a2, [v6, #ProcessorType]

        AND     a1, v2, #CT_ctype_mask
        MOV     a1, a1, LSR #CT_ctype_pos
        STRB    a1, [v6, #Cache_Type]

        ; STM should always store PC+8
        ; Should always be base restored abort model
        ; 26bit has been obsolete for a long time
        MOV     v5, #CPUFlag_StorePCplus8+CPUFlag_BaseRestored+CPUFlag_32bitOS+CPUFlag_No26bitMode
        [ HiProcVecs
        ORR     v5, v5, #CPUFlag_HiProcVecs
        ]

        ; Work out whether the cache info is in ARMv6 or ARMv7 style
        ; Top 3 bits of the cache type register give the register format
        ARM_read_cachetype v2
        MOV     a1, v2, LSR #29
        TEQ     a1, #4
        BEQ     %FT25
        TEQ     a1, #0
        BNE     WeirdARMPanic

        ; ARMv6 format cache type register.
        ; CPUs like the ARM1176JZF-S are available with a range of cache sizes,
        ; so it's not safe to rely on the values in the CPU table. Fortunately
        ; all ARMv6 CPUs implement the register (by contrast, for the "plain"
        ; ARM case, no ARMv3 CPUs, some ARMv4 CPUs and all ARMv5 CPUs, so it
        ; needs to drop back to the table in some cases).
        MOV     a1, v2, LSR #CT_Isize_pos
        ADD     a2, v6, #ICache_Info
        BL      EvaluateCache
        MOV     a1, v2, LSR #CT_Dsize_pos
        ADD     a2, v6, #DCache_Info
        BL      EvaluateCache

        TST     v2, #CT_S
        ORRNE   v5, v5, #CPUFlag_SynchroniseCodeAreas+CPUFlag_SplitCache

        B       %FT27

25
        ; ARMv7 format cache type register.
        ; This should(!) mean that we have the cache level ID register,
        ; and all the other ARMv7 cache registers.
               
        ; Do we have a split cache?
        MRC     p15, 1, a1, c0, c0, 1
        AND     a2, a1, #7
        TEQ     a2, #3
        ORREQ   v5, v5, #CPUFlag_SynchroniseCodeAreas+CPUFlag_SplitCache

27
        [ CacheOff
        ORR     v5, v5, #CPUFlag_SynchroniseCodeAreas
        |
        ARM_read_control a1                     ; if Z bit set then we have branch prediction,
        TST     a1, #MMUC_Z                     ; so we need OS_SynchroniseCodeAreas even if not
        ORRNE   v5, v5, #CPUFlag_SynchroniseCodeAreas   ; split caches
        ]

        BL      Init_ARMarch
        STRB    a1, [v6, #ProcessorArch]

        MRC     p15, 0, a1, c0, c2, 2
        TST     a1, #&FF0000                    ; MultU_instrs OR MultS_instrs
        ORRNE   v5, v5, #CPUFlag_LongMul

        MRC     p15, 0, a1, c0, c1, 0
        TST     a1, #&F0                        ; State1
        ORRNE   v5, v5, #CPUFlag_Thumb

        MRC     p15, 0, a1, c0, c2, 3
        TST     a1, #&F                         ; Saturate_instrs
        ORRNE   v5, v5, #CPUFlag_DSP

        MRC     p15, 0, a1, c0, c2, 0
        TST     a1, #&F                         ; Swap_instrs
        MRC     p15, 0, a1, c0, c2, 4
        TSTEQ   a1, #&F0000000                  ; SWP_frac
        ORREQ   v5, v5, #CPUFlag_NoSWP

        MRC     p15, 0, a2, c0, c2, 3
        AND     a2, a2, #&00F000                ; SynchPrim_instrs
        AND     a1, a1, #&F00000                ; SynchPrim_instrs_frac
        ORR     a1, a2, a1, LSR #12
        TEQ     a1, #2_00010000:SHL:8
        ORREQ   v5, v5, #CPUFlag_LoadStoreEx
        TEQ     a1, #2_00010011:SHL:8
        TEQNE   a1, #2_00100000:SHL:8
        ORREQ   v5, v5, #CPUFlag_LoadStoreEx :OR: CPUFlag_LoadStoreClearExSizes

        ; Other flags not checked for above:
        ; CPUFlag_InterruptDelay          
        ; CPUFlag_VectorReadException     
        ; CPUFlag_ExtendedPages           
        ; CPUFlag_NoWBDrain               
        ; CPUFlag_AbortRestartBroken      
        ; CPUFlag_XScale                  
        ; CPUFlag_XScaleJTAGconnected     

        LDRB    v4, [v6, #ProcessorType]

        TEQ     v4, #ARMunk                     ; Modify deduced flags
        ADRNEL  lr, KnownCPUFlags
        ADDNE   lr, lr, v4, LSL #3
        LDMNEIA lr, {a2, a3}
        ORRNE   v5, v5, a2
        BICNE   v5, v5, a3

        ORR     v5, v5, #CPUFlag_ExtraReasonCodesFixed
        STR     v5, [v6, #ProcessorFlags]

        ; Cache analysis

        LDRB    a2, [v6, #Cache_Type]

        TEQ     a2, #CT_ctype_WB_CR7_LDa        ; eg. ARM9
        TEQNE   a2, #CT_ctype_WB_CR7_LDc        ; eg. ARM1176JZF-S - differs only in cache lockdown
        BEQ     Analyse_WB_CR7_LDa

        TEQ     a2, #CT_ctype_WB_CR7_Lx
        BEQ     Analyse_WB_CR7_Lx               ; eg. Cortex-A8, Cortex-A9

        ; others ...

        B       WeirdARMPanic                   ; stiff :)
 ] ; MEMM_Type = "VMSAv6"
 
; --------------------------------------------------------------------------
; ----- ARMops -------------------------------------------------------------
; --------------------------------------------------------------------------
;
; ARMops are the routines required by the kernel for cache/MMU control
; the kernel vectors to the appropriate ops for the given ARM at boot
;
; The Rules:
;   - These routines may corrupt a1 and lr only
;   - (lr can of course only be corrupted whilst still returning to correct
;     link address)
;   - stack is available, at least 16 words can be stacked
;   - a NULL op would be a simple MOV pc, lr
;

; In:  r1 = cache level (0-based)
; Out: r0 = Flags
;           bits 0-2: cache type:
;              000 -> none
;              001 -> instruction
;              010 -> data
;              011 -> split
;              100 -> unified
;              1xx -> reserved
;           Other bits: reserved
;      r1 = D line length
;      r2 = D size
;      r3 = I line length
;      r4 = I size
;      r0-r4 = zero if cache level not present
Cache_Examine_Simple
        TEQ     r1, #0
        MOVNE   r0, #0
        MOVNE   r1, #0
        MOVNE   r2, #0
        MOVNE   r3, #0
        MOVNE   r4, #0
        MOVNE   pc, lr
        LDR     r4, =ZeroPage
        LDR     r0, [r4, #ProcessorFlags]
        TST     r0, #CPUFlag_SplitCache
        MOVNE   r0, #3
        MOVEQ   r0, #4
        LDRB    r1, [r4, #DCache_LineLen]
        LDR     r2, [r4, #DCache_Size]
        LDRB    r3, [r4, #ICache_LineLen]
        LDR     r4, [r4, #ICache_Size]
NullOp  MOV     pc, lr

 [ MEMM_Type = "ARM600"

; --------------------------------------------------------------------------
; ----- ARMops for ARMv3 ---------------------------------------------------
; --------------------------------------------------------------------------
;
; ARMv3 ARMs include ARM710, ARM610, ARM7500
;

Cache_Invalidate_ARMv3
        MCR     p15, 0, a1, c7, c0
        MOV     pc, lr

DSB_ReadWrite_ARMv3
        ;swap always forces unbuffered write, stalling till WB empty
        SUB     sp, sp, #4
        SWP     a1, a1, [sp]
        ADD     sp, sp, #4
        MOV     pc, lr

TLB_Invalidate_ARMv3
        MCR     p15, 0, a1, c5, c0
        MOV     pc, lr

; a1 = page entry to invalidate (page aligned address)
;
TLB_InvalidateEntry_ARMv3
        MCR     p15, 0, a1, c6, c0
        MOV     pc, lr

MMU_Changing_ARMv3
 [ CacheablePageTables
        SUB     sp, sp, #4
        SWP     a1, a1, [sp]
        ADD     sp, sp, #4
 ]
        MCR     p15, 0, a1, c5, c0      ; invalidate TLB
        MCR     p15, 0, a1, c7, c0      ; invalidate cache
        MOV     pc, lr

MMU_ChangingUncached_ARMv3
 [ CacheablePageTables
        SUB     sp, sp, #4
        SWP     a1, a1, [sp]
        ADD     sp, sp, #4
 ]
        MCR     p15, 0, a1, c5, c0      ; invalidate TLB
        MOV     pc, lr

; a1 = page affected (page aligned address)
;
MMU_ChangingEntry_ARMv3
 [ CacheablePageTables
        Push    "a1"
        SWP     a1, a1, [sp]
        ADD     sp, sp, #4
 ]
        MCR     p15, 0, a1, c6, c0      ; invalidate TLB entry
        MCR     p15, 0, a1, c7, c0      ; invalidate cache
        MOV     pc, lr

; a1 = first page affected (page aligned address)
; a2 = number of pages
;
MMU_ChangingEntries_ARMv3 ROUT
        CMP     a2, #16                 ; arbitrary-ish threshold
        BHS     MMU_Changing_ARMv3
        Push    "a2"
 [ CacheablePageTables
        SWP     a2, a2, [sp]
 ]
10
        MCR     p15, 0, a1, c6, c0      ; invalidate TLB entry
        SUBS    a2, a2, #1              ; next page
        ADD     a1, a1, #PageSize
        BNE     %BT10
        MCR     p15, 0, a1, c7, c0      ; invalidate cache
        Pull    "a2"
        MOV     pc, lr

; a1 = page affected (page aligned address)
;
MMU_ChangingUncachedEntry_ARMv3
 [ CacheablePageTables
        Push    "a1"
        SWP     a1, a1, [sp]
        ADD     sp, sp, #4
 ]
        MCR     p15, 0, a1, c6, c0      ; invalidate TLB entry
        MOV     pc, lr

; a1 = first page affected (page aligned address)
; a2 = number of pages
;
MMU_ChangingUncachedEntries_ARMv3 ROUT
        CMP     a2, #16                 ; arbitrary-ish threshold
        BHS     MMU_ChangingUncached_ARMv3
        Push    "a2"
 [ CacheablePageTables
        SWP     a2, a2, [sp]
 ]
10
        MCR     p15, 0, a1, c6, c0      ; invalidate TLB entry
        SUBS    a2, a2, #1              ; next page
        ADD     a1, a1, #PageSize
        BNE     %BT10
        Pull    "a2"
        MOV     pc, lr

Cache_RangeThreshold_ARMv3
        ! 0, "arbitrary Cache_RangeThreshold_ARMv3"
        MOV     a1, #16*PageSize
        MOV     pc, lr

        LTORG

; --------------------------------------------------------------------------
; ----- generic ARMops for simple ARMs, ARMv4 onwards ----------------------
; --------------------------------------------------------------------------
;
; eg. ARM7TDMI based ARMs, unified, writethrough cache
;

Cache_InvalidateUnified
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c7
        MOV     pc, lr

DSB_ReadWrite_OffOn
        ; used if ARM has no drain WBuffer MCR op
        Push    "a2"
        ARM_read_control a1
        BIC     a2, a1, #MMUC_W
        ARM_write_control a2
        ARM_write_control a1
        Pull    "a2"
        MOV     pc, lr

DSB_ReadWrite
        ; used if ARM has proper drain WBuffer MCR op
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4
        MOV     pc, lr

TLB_Invalidate_Unified
        MOV     a1, #0
        MCR     p15, 0, a1, c8, c7
        MOV     pc, lr

; a1 = page entry to invalidate (page aligned address)
;
TLB_InvalidateEntry_Unified
        MCR     p15, 0, a1, c8, c7, 1
        MOV     pc, lr

MMU_Changing_Writethrough
 [ CacheablePageTables
        ; Yuck - this is probably going to be quite slow. Something to fix
        ; properly if/when we port to a system that uses this type of CPU.
        Push    "lr"
        LDR     a1, =ZeroPage
        ARMop   DSB_ReadWrite,,,a1
        Pull    "lr"
 ]
        MOV     a1, #0
        MCR     p15, 0, a1, c8, c7      ; invalidate TLB
        MCR     p15, 0, a1, c7, c7      ; invalidate cache
        MOV     pc, lr

MMU_ChangingUncached
 [ CacheablePageTables
        Push    "lr"
        LDR     a1, =ZeroPage
        ARMop   DSB_ReadWrite,,,a1
        Pull    "lr"
 ]
        MOV     a1, #0
        MCR     p15, 0, a1, c8, c7      ; invalidate TLB
        MOV     pc, lr

; a1 = page affected (page aligned address)
;
MMU_ChangingEntry_Writethrough
 [ CacheablePageTables
        Push    "a1,lr"
        LDR     a1, =ZeroPage
        ARMop   DSB_ReadWrite,,,a1
        Pull    "a1,lr"
 ]
        MCR     p15, 0, a1, c8, c7, 1   ; invalidate TLB entry
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c7      ; invalidate cache
        MOV     pc, lr

; a1 = first page affected (page aligned address)
; a2 = number of pages
;
MMU_ChangingEntries_Writethrough  ROUT
        CMP     a2, #16                 ; arbitrary-ish threshold
        BHS     MMU_Changing_Writethrough
        Push    "a2"
 [ CacheablePageTables
        Push    "a1,lr"
        LDR     a1, =ZeroPage
        ARMop   DSB_ReadWrite,,,a1
        Pull    "a1,lr"
 ]
10
        MCR     p15, 0, a1, c8, c7, 1   ; invalidate TLB entry
        SUBS    a2, a2, #1              ; next page
        ADD     a1, a1, #PageSize
        BNE     %BT10
        MCR     p15, 0, a2, c7, c7      ; invalidate cache
        Pull    "a2"
        MOV     pc, lr

; a1 = page affected (page aligned address)
;
MMU_ChangingUncachedEntry
 [ CacheablePageTables
        Push    "a1,lr"
        LDR     a1, =ZeroPage
        ARMop   DSB_ReadWrite,,,a1
        Pull    "a1,lr"
 ]
        MCR     p15, 0, a1, c8, c7, 1   ; invalidate TLB entry
        MOV     pc, lr

; a1 = first page affected (page aligned address)
; a2 = number of pages
;
MMU_ChangingUncachedEntries ROUT
        CMP     a2, #16                 ; arbitrary-ish threshold
        BHS     MMU_ChangingUncached
        Push    "a2"
 [ CacheablePageTables
        Push    "a1,lr"
        LDR     a1, =ZeroPage
        ARMop   DSB_ReadWrite,,,a1
        Pull    "a1,lr"
 ]
10
        MCR     p15, 0, a1, c8, c7, 1   ; invalidate TLB entry
        SUBS    a2, a2, #1              ; next page
        ADD     a1, a1, #PageSize
        BNE     %BT10
        Pull    "a2"
        MOV     pc, lr

Cache_RangeThreshold_Writethrough
        ! 0, "arbitrary Cache_RangeThreshold_Writethrough"
        MOV     a1, #16*PageSize
        MOV     pc, lr

 ] ; MEMM_Type = "ARM600"

; --------------------------------------------------------------------------
; ----- ARMops for ARM9 and the like ---------------------------------------
; --------------------------------------------------------------------------

; WB_CR7_LDa refers to ARMs with writeback data cache, cleaned with
; register 7, lockdown available (format A)
;
; Note that ARM920 etc have writeback/writethrough data cache selectable
; by MMU regions. For simpliciity, we assume cacheable pages are mostly
; writeback. Any writethrough pages will have redundant clean operations
; applied when moved, for example, but this is a small overhead (cleaning
; a clean line is very quick on ARM 9).

Cache_CleanAll_WB_CR7_LDa ROUT
;
; only guarantees to clean lines not involved in interrupts (so we can
; clean without disabling interrupts)
;
; Clean cache by traversing all segment and index values
; As a concrete example, for ARM 920 (16k+16k caches) we would have:
;
;    DCache_LineLen       = 32         (32 byte cache line, segment field starts at bit 5)
;    DCache_IndexBit      = &04000000  (index field starts at bit 26)
;    DCache_IndexSegStart = &000000E0  (start at index=0, segment = 7)
;
        Push    "a2, ip"
        LDR     ip, =ZeroPage
        LDRB    a1, [ip, #DCache_LineLen]        ; segment field starts at this bit
        LDR     a2, [ip, #DCache_IndexBit]       ; index field starts at this bit
        LDR     ip, [ip, #DCache_IndexSegStart]  ; starting value, with index at min, seg at max
10
        MCR     p15, 0, ip, c7, c10, 2           ; clean DCache entry by segment/index
        ADDS    ip, ip, a2                       ; next index, counting up, CS if wrapped back to 0
        BCC     %BT10
        SUBS    ip, ip, a1                       ; next segment, counting down, CC if wrapped back to max
        BCS     %BT10                            ; if segment wrapped, then we've finished
        MOV     ip, #0
        MCR     p15, 0, ip, c7, c10, 4           ; drain WBuffer
        Pull    "a2, ip"
        MOV     pc, lr

Cache_CleanInvalidateAll_WB_CR7_LDa ROUT
;
; similar to Cache_CleanAll, but does clean&invalidate of Dcache, and invalidates ICache
;
        Push    "a2, ip"
        LDR     ip, =ZeroPage
        LDRB    a1, [ip, #DCache_LineLen]        ; segment field starts at this bit
        LDR     a2, [ip, #DCache_IndexBit]       ; index field starts at this bit
        LDR     ip, [ip, #DCache_IndexSegStart]  ; starting value, with index at min, seg at max
10
        MCR     p15, 0, ip, c7, c14, 2           ; clean&invalidate DCache entry by segment/index
        ADDS    ip, ip, a2                       ; next index, counting up, CS if wrapped back to 0
        BCC     %BT10
        SUBS    ip, ip, a1                       ; next segment, counting down, CC if wrapped back to max
        BCS     %BT10                            ; if segment wrapped, then we've finished
        MOV     ip, #0
        MCR     p15, 0, ip, c7, c10, 4           ; drain WBuffer
        MCR     p15, 0, ip, c7, c5, 0            ; invalidate ICache
        Pull    "a2, ip"
        MOV     pc, lr

;  a1 = start address (inclusive, cache line aligned)
;  a2 = end address (exclusive, cache line aligned)
;
 [ MEMM_Type = "ARM600"
Cache_CleanInvalidateRange_WB_CR7_LDa ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c14, 1             ; clean&invalidate DCache entry
        MCR     p15, 0, a1, c7, c5, 1              ; invalidate ICache entry
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
        MCR     p15, 0, a1, c7, c5, 6              ; flush branch predictors
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       Cache_CleanInvalidateAll_WB_CR7_LDa

Cache_CleanRange_WB_CR7_LDa ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c10, 1             ; clean DCache entry
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       Cache_CleanAll_WB_CR7_LDa
        
Cache_InvalidateRange_WB_CR7_LDa ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3, LSL #1                     ;assume clean+invalidate slower than just invalidate
        BHS     %FT30
        ADD     a2, a2, a1                         ;end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c6, 1              ; invalidate DCache entry
        MCR     p15, 0, a1, c7, c5, 1              ; invalidate ICache entry
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
        MCR     p15, 0, a1, c7, c5, 6              ; flush branch predictors
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       Cache_CleanInvalidateAll_WB_CR7_LDa
 |
; Bodge for ARM11
; The OS assumes that address-based cache maintenance operations will operate
; on pages which are currently marked non-cacheable (so that we can make a page
; non-cacheable and then clean/invalidate the cache, to ensure prefetch or
; anything else doesn't pull any data for the page back into the cache once
; we've cleaned it). For ARMv7+ this is guaranteed behaviour, but prior to that
; it's implementation defined, and the ARM11 in particular seems to ignore
; address-based maintenance which target non-cacheable addresses.
; As a workaround, perform a full clean & invalidate instead
;
; Note that this also provides us protection against erratum 720013 (or possibly
; it's that erratum which I was experiencing when I first made this change)
Cache_CleanInvalidateRange_WB_CR7_LDa * Cache_CleanInvalidateAll_WB_CR7_LDa
Cache_CleanRange_WB_CR7_LDa * Cache_CleanAll_WB_CR7_LDa
Cache_InvalidateRange_WB_CR7_LDa * Cache_CleanInvalidateAll_WB_CR7_LDa
 ]

Cache_InvalidateAll_WB_CR7_LDa ROUT
;
; no clean, assume caller knows what's happening
;
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c7, 0           ; invalidate ICache and DCache
        MOV     pc, lr


Cache_RangeThreshold_WB_CR7_LDa ROUT
        LDR     a1, =ZeroPage
        LDR     a1, [a1, #DCache_RangeThreshold]
        MOV     pc, lr

ICache_InvalidateAll_WB_CR7_LDa ROUT
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c5, 0            ; invalidate ICache + branch predictors
        MOV     pc, lr

 [ MEMM_Type = "ARM600"
;  a1 = start address (inclusive, cache line aligned)
;  a2 = end address (exclusive, cache line aligned)
;
ICache_InvalidateRange_WB_CR7_LDa ROUT
        SUB     a2, a2, a1
        CMP     a2, #32*1024                     ; arbitrary-ish range threshold
        ADD     a2, a2, a1
        BHS     ICache_InvalidateAll_WB_CR7_LDa
        Push    "lr"
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #ICache_LineLen]
10
        MCR     p15, 0, a1, c7, c5, 1            ; invalidate ICache entry
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c5, 6            ; flush branch predictors
        Pull    "pc"
 |
; ARM11 erratum 720013: I-cache invalidation can fail
; One workaround (for MVA ops) is to perform the operation twice, but that would
; presumably need interrupts to be disabled to be fully safe. So go with the
; other workaround of doing a full invalidate instead.
ICache_InvalidateRange_WB_CR7_LDa * ICache_InvalidateAll_WB_CR7_LDa
 ]


MMU_ChangingUncached_WB_CR7_LDa ROUT
 [ CacheablePageTables
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer
   [ MEMM_Type = "VMSAv6"
        MCR     p15, 0, a1, c7, c5, 4           ; ISB
   ]
 ]
TLB_InvalidateAll_WB_CR7_LDa
        MOV     a1, #0
        MCR     p15, 0, a1, c8, c7, 0           ; invalidate ITLB and DTLB
        MOV     pc, lr


; a1 = page affected (page aligned address)
;
MMU_ChangingUncachedEntry_WB_CR7_LDa ROUT
 [ CacheablePageTables
        Push    "a1"
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer
   [ MEMM_Type = "VMSAv6"
        MCR     p15, 0, a1, c7, c5, 4           ; ISB
   ]
        Pull    "a1"
 ]
TLB_InvalidateEntry_WB_CR7_LDa
        MCR     p15, 0, a1, c8, c5, 1           ; invalidate ITLB entry
        MCR     p15, 0, a1, c8, c6, 1           ; invalidate DTLB entry
        MOV     pc, lr


DSB_ReadWrite_WB_CR7_LDa ROUT
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer
        MOV     pc, lr


IMB_Full_WB_CR7_LDa ROUT
;
; do: clean DCache; drain WBuffer, invalidate ICache
;
        Push    "lr"
        BL      Cache_CleanAll_WB_CR7_LDa       ; also drains Wbuffer
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c5, 0           ; invalidate ICache
        Pull    "pc"

;  a1 = start address (inclusive, cache line aligned)
;  a2 = end address (exclusive, cache line aligned)
;
IMB_Range_WB_CR7_LDa ROUT
        SUB     a2, a2, a1
        CMP     a2, #32*1024                     ; arbitrary-ish range threshold
        ADD     a2, a2, a1
        BHS     IMB_Full_WB_CR7_LDa
        Push    "lr"
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c10, 1           ; clean DCache entry by VA
 [ MEMM_Type = "ARM600"
        MCR     p15, 0, a1, c7, c5, 1            ; invalidate ICache entry
 ]
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4           ; drain WBuffer
 [ MEMM_Type = "ARM600"
        MCR     p15, 0, a1, c7, c5, 6            ; flush branch predictors
 |
        MCR     p15, 0, a1, c7, c5, 0            ; invalidate ICache + branch predictors (erratum 720013)
 ]
        Pull    "pc"

;  a1 = pointer to list of (start, end) address pairs
;  a2 = pointer to end of list
;  a3 = total amount of memory to be synchronised
;
IMB_List_WB_CR7_LDa ROUT
        CMP     a3, #32*1024                     ; arbitrary-ish range threshold
        BHS     IMB_Full_WB_CR7_LDa
        Push    "v1-v2,lr"
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen]
05
        LDMIA   a1!, {v1-v2}
10
        MCR     p15, 0, v1, c7, c10, 1           ; clean DCache entry by VA
 [ MEMM_Type = "ARM600"
        MCR     p15, 0, v1, c7, c5, 1            ; invalidate ICache entry
 ]
        ADD     v1, v1, lr
        CMP     v1, v2
        BLO     %BT10
        CMP     a1, a2
        BNE     %BT05
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4           ; drain WBuffer
 [ MEMM_Type = "ARM600"
        MCR     p15, 0, a1, c7, c5, 6            ; flush branch predictors
 |
        MCR     p15, 0, a1, c7, c5, 0            ; invalidate ICache + branch predictors (erratum 720013)
 ]
        Pull    "v1-v2,pc"

MMU_Changing_WB_CR7_LDa ROUT
 [ CacheablePageTables
        Push    "a1"
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer
   [ MEMM_Type = "VMSAv6"
        MCR     p15, 0, a1, c7, c5, 4           ; ISB
   ]
        Pull    "a1"
 ]
        MOV     a1, #0
        MCR     p15, 0, a1, c8, c7, 0           ; invalidate ITLB and DTLB
        B       Cache_CleanInvalidateAll_WB_CR7_LDa

; a1 = page affected (page aligned address)
;
MMU_ChangingEntry_WB_CR7_LDa ROUT
 [ CacheablePageTables
        Push    "a1"
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer
   [ MEMM_Type = "VMSAv6"
        MCR     p15, 0, a1, c7, c5, 4           ; ISB
   ]
        Pull    "a1"
 ]
 [ MEMM_Type = "ARM600"
        Push    "a2, lr"
        MCR     p15, 0, a1, c8, c6, 1           ; invalidate DTLB entry
        MCR     p15, 0, a1, c8, c5, 1           ; invalidate ITLB entry
        ADD     a2, a1, #PageSize
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c14, 1          ; clean&invalidate DCache entry
        MCR     p15, 0, a1, c7, c5, 1           ; invalidate ICache entry
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
        MOV     lr, #0
        MCR     p15, 0, lr, c7, c10, 4          ; drain WBuffer
        MCR     p15, 0, a1, c7, c5, 6           ; flush branch predictors
        Pull    "a2, pc"
 |
; See above re: ARM11 cache cleaning not working on non-cacheable pages
        MCR     p15, 0, a1, c8, c6, 1           ; invalidate DTLB entry
        MCR     p15, 0, a1, c8, c5, 1           ; invalidate ITLB entry
        B       Cache_CleanInvalidateAll_WB_CR7_LDa
 ]

; a1 = first page affected (page aligned address)
; a2 = number of pages
;
MMU_ChangingEntries_WB_CR7_LDa ROUT
        Push    "a2, a3, lr"
 [ CacheablePageTables
        MOV     a3, #0
        MCR     p15, 0, a3, c7, c10, 4          ; drain WBuffer
   [ MEMM_Type = "VMSAv6"
        MCR     p15, 0, a3, c7, c5, 4           ; ISB
   ]
 ]
        MOV     a2, a2, LSL #Log2PageSize
        LDR     lr, =ZeroPage
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
        MOV     lr, a1
10
        MCR     p15, 0, a1, c8, c6, 1              ; invalidate DTLB entry
        MCR     p15, 0, a1, c8, c5, 1              ; invalidate ITLB entry
        ADD     a1, a1, #PageSize
        CMP     a1, a2
        BLO     %BT10
 [ MEMM_Type = "ARM600"
        MOV     a1, lr                             ; restore start address
20
        MCR     p15, 0, a1, c7, c14, 1             ; clean&invalidate DCache entry
        MCR     p15, 0, a1, c7, c5, 1              ; invalidate ICache entry
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT20
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
        MCR     p15, 0, a1, c7, c5, 6              ; flush branch predictors
        Pull    "a2, a3, pc"
;
 |
; See above re: ARM11 cache cleaning not working on non-cacheable pages
        B       %FT40
 ]
30
        MOV     a1, #0
        MCR     p15, 0, a1, c8, c7, 0              ; invalidate ITLB and DTLB
40
        BL      Cache_CleanInvalidateAll_WB_CR7_LDa
        Pull    "a2, a3, pc"

; a1 = first page affected (page aligned address)
; a2 = number of pages
;
MMU_ChangingUncachedEntries_WB_CR7_LDa ROUT
 [ CacheablePageTables
        Push    "a1"
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer
   [ MEMM_Type = "VMSAv6"
        MCR     p15, 0, a1, c7, c5, 4           ; ISB
   ]
        Pull    "a1"
 ]
        CMP     a2, #32                            ; arbitrary-ish threshold
        BHS     %FT20
        Push    "a2"
10
        MCR     p15, 0, a1, c8, c6, 1              ; invalidate DTLB entry
        MCR     p15, 0, a1, c8, c5, 1              ; invalidate ITLB entry
        ADD     a1, a1, #PageSize
        SUBS    a2, a2, #1
        BNE     %BT10
        Pull    "a2"
        MOV     pc, lr
;
20
        MCR     p15, 0, a1, c8, c7, 0              ; invalidate ITLB and DTLB
        MOV     pc, lr


 [ MEMM_Type = "ARM600"

; --------------------------------------------------------------------------
; ----- ARMops for StrongARM and the like ----------------------------------
; --------------------------------------------------------------------------

; WB_Crd is Writeback data cache, clean by reading data from cleaner area

; Currently no support for mini data cache on some StrongARM variants. Mini
; cache is always writeback and must have cleaning support, so is very
; awkward to use for cacheable screen, say.

; Global cache cleaning requires address space for private cleaner areas (not accessed
; for any other reason). Cleaning is normally with interrupts enabled (to avoid a latency
; hit), which means that the cleaner data is not invalidated afterwards. This is fine for
; RISC OS - where the private area is not used for anything else, and any re-use of the
; cache under interrupts is safe (eg. a page being moved is *never* involved in any
; active interrupts).

; Mostly, cleaning toggles between two separate cache-sized areas, which gives minimum
; cleaning cost while guaranteeing proper clean even if previous clean data is present. If
; the clean routine is re-entered, an independent, double sized clean is initiated. This
; guarantees proper cleaning (regardless of multiple re-entrancy) whilst hardly complicating
; the routine at all. The overhead is small, since by far the most common cleaning will be
; non-re-entered. The upshot is that the cleaner address space available must be at least 4
; times the cache size:
;   1 : used alternately, on 1st, 3rd, ... non-re-entered cleans
;   2 : used alternately, on 2nd, 4th, ... non-re-entered cleans
;   3 : used only for first half of a re-entered clean
;   4 : used only for second half of a re-entered clean
;
;   DCache_CleanBaseAddress   : start address of total cleaner space
;   DCache_CleanNextAddress   : start address for next non-re-entered clean, or 0 if re-entered


Cache_CleanAll_WB_Crd ROUT
;
; - cleans data cache (and invalidates it as a side effect)
; - can be used with interrupts enabled (to avoid latency over time of clean)
; - can be re-entered
; - see remarks at top of StrongARM ops for discussion of strategy
;

        Push    "a2-a4, v1, v2, lr"
        LDR     lr, =ZeroPage
        LDR     a1, [lr, #DCache_CleanBaseAddress]
        LDR     a2, =DCache_CleanNextAddress
        LDR     a3, [lr, #DCache_Size]
        LDRB    a4, [lr, #DCache_LineLen]
        MOV     v2, #0
        SWP     v1, v2, [a2]                        ; read current CleanNextAddr, zero it (semaphore)
        TEQ     v1, #0                              ; but if it is already zero, we have re-entered
        ADDEQ   v1, a1, a3, LSL #1                  ; if re-entered, start clean at Base+2*Cache_Size
        ADDEQ   v2, v1, a3, LSL #1                  ; if re-entered, do a clean of 2*Cache_Size
        ADDNE   v2, v1, a3                          ; if not re-entered, do a clean of Cache_Size
10
        LDR     lr, [v1], a4
        TEQ     v1, v2
        BNE     %BT10
        ADD     v2, a1, a3, LSL #1                  ; compare end address with Base+2*Cache_Size
        CMP     v1, v2
        MOVEQ   v1, a1                              ; if equal, not re-entered and Next wraps back
        STRLS   v1, [a2]                            ; if lower or same, not re-entered, so update Next
        MCR     p15, 0, a1, c7, c10, 4              ; drain WBuffer
        Pull    "a2-a4, v1, v2, pc"


Cache_CleanInvalidateAll_WB_Crd ROUT
IMB_Full_WB_Crd
;
;does not truly invalidate DCache, but effectively invalidates (flushes) all lines not
;involved in interrupts - this is sufficient for OS requirements, and means we don't
;have to disable interrupts for possibly slow clean
;
        Push    "lr"
        BL      Cache_CleanAll_WB_Crd               ;clean DCache (wrt to non-interrupt stuff)
        MCR     p15, 0, a1, c7, c5, 0               ;flush ICache
        Pull    "pc"

Cache_InvalidateAll_WB_Crd
;
; no clean, assume caller knows what is happening
;
        MCR     p15, 0, a1, c7, c7, 0               ;flush ICache and DCache
        MCR     p15, 0, a1, c7, c10, 4              ;drain WBuffer
        MOV     pc, lr

Cache_RangeThreshold_WB_Crd
        LDR     a1, =ZeroPage
        LDR     a1, [a1, #DCache_RangeThreshold]
        MOV     pc, lr

MMU_ChangingUncached_WB_Crd
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
 ]
TLB_InvalidateAll_WB_Crd
        MCR     p15, 0, a1, c8, c7, 0              ;flush ITLB and DTLB
        MOV     pc, lr

MMU_ChangingUncachedEntry_WB_Crd
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
 ]
TLB_InvalidateEntry_WB_Crd
        MCR     p15, 0, a1, c8, c6, 1              ;flush DTLB entry
        MCR     p15, 0, a1, c8, c5, 0              ;flush ITLB
        MOV     pc, lr

DSB_ReadWrite_WB_Crd
        MCR     p15, 0, a1, c7, c10, 4             ;drain WBuffer
        MOV     pc, lr


IMB_Range_WB_Crd ROUT
        SUB     a2, a2, a1
        CMP     a2, #64*1024                       ;arbitrary-ish range threshold
        ADD     a2, a2, a1
        BHS     IMB_Full_WB_Crd
        Push    "lr"
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c10, 1             ;clean DCache entry
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
        MCR     p15, 0, a1, c7, c10, 4             ;drain WBuffer
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        Pull    "pc"


IMB_List_WB_Crd ROUT
        CMP     a3, #64*1024                       ;arbitrary-ish range threshold
        BHS     IMB_Full_WB_Crd
        Push    "v1-v2,lr"
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen]
05
        LDMIA   a1!, {v1-v2}
10
        MCR     p15, 0, v1, c7, c10, 1             ;clean DCache entry
        ADD     v1, v1, lr
        CMP     v1, v2
        BLO     %BT10
        CMP     a1, a2
        BNE     %BT05
        MCR     p15, 0, a1, c7, c10, 4             ;drain WBuffer
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        Pull    "v1-v2,pc"

MMU_Changing_WB_Crd
        Push    "lr"
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
 ]
        MCR     p15, 0, a1, c8, c7, 0               ;flush ITLB and DTLB
        BL      Cache_CleanAll_WB_Crd               ;clean DCache (wrt to non-interrupt stuff)
        MCR     p15, 0, a1, c7, c5, 0               ;flush ICache
        Pull    "pc"

MMU_ChangingEntry_WB_Crd ROUT
;
;there is no clean&invalidate DCache instruction, however we can do clean
;entry followed by invalidate entry without an interrupt hole, because they
;are for the same virtual address (and that virtual address will not be
;involved in interrupts, since it is involved in remapping)
;
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
 ]
        Push    "a2, lr"
        ADD     a2, a1, #PageSize
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen]
        MCR     p15, 0, a1, c8, c6, 1              ;flush DTLB entry
        MCR     p15, 0, a1, c8, c5, 0              ;flush ITLB
10
        MCR     p15, 0, a1, c7, c10, 1             ;clean DCache entry
        MCR     p15, 0, a1, c7, c6, 1              ;flush DCache entry
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
        SUB     a1, a1, #PageSize
        MCR     p15, 0, a1, c7, c10, 4             ;drain WBuffer
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        Pull    "a2, pc"

MMU_ChangingEntries_WB_Crd ROUT
;
;same comments as MMU_ChangingEntry_WB_Crd
;
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
 ]
        Push    "a2, a3, lr"
        MOV     a2, a2, LSL #Log2PageSize
        LDR     lr, =ZeroPage
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
        MOV     lr, a1
10
        MCR     p15, 0, a1, c8, c6, 1              ;flush DTLB entry
        ADD     a1, a1, #PageSize
        CMP     a1, a2
        BLO     %BT10
        MCR     p15, 0, a1, c8, c5, 0              ;flush ITLB
        MOV     a1, lr                             ;restore start address
20
        MCR     p15, 0, a1, c7, c10, 1             ;clean DCache entry
        MCR     p15, 0, a1, c7, c6, 1              ;flush DCache entry
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT20
        MCR     p15, 0, a1, c7, c10, 4             ;drain WBuffer
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        Pull    "a2, a3, pc"
;
30
        MCR     p15, 0, a1, c8, c7, 0              ;flush ITLB and DTLB
        BL      Cache_CleanAll_WB_Crd              ;clean DCache (wrt to non-interrupt stuff)
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        Pull    "a2, a3, pc"

Cache_CleanRange_WB_Crd ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c10, 1             ;clean DCache entry
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
        MCR     p15, 0, a1, c7, c10, 4             ;drain WBuffer
        Pull    "a2, a3, pc"
;
30
        BL      Cache_CleanAll_WB_Crd              ;clean DCache (wrt to non-interrupt stuff)
        Pull    "a2, a3, pc"

Cache_InvalidateRange_WB_Crd ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3, LSL #1                     ;assume clean+invalidate slower than just invalidate
        BHS     %FT30
        ADD     a2, a2, a1                         ;end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c6, 1              ;flush DCache entry
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
        MCR     p15, 0, a1, c7, c10, 4             ;drain WBuffer
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        Pull    "a2, a3, pc"
;
30
        BL      Cache_CleanAll_WB_Crd              ;clean DCache (wrt to non-interrupt stuff)
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        Pull    "a2, a3, pc"

Cache_CleanInvalidateRange_WB_Crd ROUT
;
;same comments as MMU_ChangingEntry_WB_Crd
;
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c10, 1             ;clean DCache entry
        MCR     p15, 0, a1, c7, c6, 1              ;flush DCache entry
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
        MCR     p15, 0, a1, c7, c10, 4             ;drain WBuffer
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        Pull    "a2, a3, pc"
;
30
        BL      Cache_CleanAll_WB_Crd              ;clean DCache (wrt to non-interrupt stuff)
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        Pull    "a2, a3, pc"

MMU_ChangingUncachedEntries_WB_Crd ROUT
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
 ]
        CMP     a2, #32                            ;arbitrary-ish threshold
        BHS     %FT20
        Push    "lr"
        MOV     lr, a2
10
        MCR     p15, 0, a1, c8, c6, 1              ;flush DTLB entry
        ADD     a1, a1, #PageSize
        SUBS    lr, lr, #1
        BNE     %BT10
        MCR     p15, 0, a1, c8, c5, 0              ;flush ITLB
        Pull    "pc"
;
20
        MCR     p15, 0, a1, c8, c7, 0              ;flush ITLB and DTLB
        MOV     pc, lr

ICache_InvalidateAll_WB_Crd ROUT
ICache_InvalidateRange_WB_Crd
        MCR     p15, 0, a1, c7, c5, 0              ;flush ICache
        MOV     pc, lr

        LTORG

; ARMops for XScale, mjs Feb 2001
;
; WB_Cal_LD is writeback, clean with allocate, lockdown
;
; If the mini data cache is used (XScaleMiniCache true), it is assumed to be
; configured writethrough (eg. used for RISC OS screen memory). This saves an ugly/slow
; mini cache clean for things like IMB_Full.
;
; Sadly, for global cache invalidate with mini cache, things are awkward. We can't clean the
; main cache then do the global invalidate MCR, unless we tolerate having _all_ interrupts
; off (else the main cache may be slightly dirty from interrupts, and the invalidate
; will lose data). So we must reluctantly 'invalidate' the mini cache by the ugly/slow
; mechanism as if we were cleaning it :-( Intel should provide a separate global invalidate
; (and perhaps a line allocate) for the mini cache.
;
; We do not use lockdown.
;
; For simplicity, we assume cacheable pages are mostly writeback. Any writethrough
; pages will be invalidated as if they were writeback, but there is little overhead
; (cleaning a clean line or allocating a line from cleaner area are both fast).

; Global cache cleaning requires address space for private cleaner areas (not accessed
; for any other reason). Cleaning is normally with interrupts enabled (to avoid a latency
; hit), which means that the cleaner data is not invalidated afterwards. This is fine for
; RISC OS - where the private area is not used for anything else, and any re-use of the
; cache under interrupts is safe (eg. a page being moved is *never* involved in any
; active interrupts).

; Mostly, cleaning toggles between two separate cache-sized areas, which gives minimum
; cleaning cost while guaranteeing proper clean even if previous clean data is present. If
; the clean routine is re-entered, an independent, double sized clean is initiated. This
; guarantees proper cleaning (regardless of multiple re-entrancy) whilst hardly complicating
; the routine at all. The overhead is small, since by far the most common cleaning will be
; non-re-entered. The upshot is that the cleaner address space available must be at least 4
; times the cache size:
;   1 : used alternately, on 1st, 3rd, ... non-re-entered cleans
;   2 : used alternately, on 2nd, 4th, ... non-re-entered cleans
;   3 : used only for first half of a re-entered clean
;   4 : used only for second half of a re-entered clean
;
; If the mini cache is used, it has its own equivalent cleaner space and algorithm.
; Parameters for each cache are:
;
;    Cache_CleanBaseAddress   : start address of total cleaner space
;    Cache_CleanNextAddress   : start address for next non-re-entered clean, or 0 if re-entered


                 GBLL XScaleMiniCache  ; *must* be configured writethrough if used
XScaleMiniCache  SETL {FALSE}


; MACRO to do Intel approved CPWAIT, to guarantee any previous MCR's have taken effect
; corrupts a1
;
        MACRO
        CPWAIT
        MRC      p15, 0, a1, c2, c0, 0               ; arbitrary read of CP15
        MOV      a1, a1                              ; wait for it
        ; SUB pc, pc, #4 omitted, because all ops have a pc load to return to caller
        MEND


Cache_CleanAll_WB_Cal_LD ROUT
;
; - cleans main cache (and invalidates as a side effect)
; - if mini cache is in use, will be writethrough so no clean required
; - can be used with interrupts enabled (to avoid latency over time of clean)
; - can be re-entered
; - see remarks at top of XScale ops for discussion of strategy
;
        Push    "a2-a4, v1, v2, lr"
        LDR     lr, =ZeroPage
        LDR     a1, [lr, #DCache_CleanBaseAddress]
        LDR     a2, =ZeroPage+DCache_CleanNextAddress
        LDR     a3, [lr, #DCache_Size]
        LDRB    a4, [lr, #DCache_LineLen]
        MOV     v2, #0
        SWP     v1, v2, [a2]                        ; read current CleanNextAddr, zero it (semaphore)
        TEQ     v1, #0                              ; but if it is already zero, we have re-entered
        ADDEQ   v1, a1, a3, LSL #1                  ; if re-entered, start clean at Base+2*Cache_Size
        ADDEQ   v2, v1, a3, LSL #1                  ; if re-entered, do a clean of 2*Cache_Size
        ADDNE   v2, v1, a3                          ; if not re-entered, do a clean of Cache_Size
10
        MCR     p15, 0, v1, c7, c2, 5               ; allocate address from cleaner space
        ADD     v1, v1, a4
        TEQ     v1, v2
        BNE     %BT10
        ADD     v2, a1, a3, LSL #1                  ; compare end address with Base+2*Cache_Size
        CMP     v1, v2
        MOVEQ   v1, a1                              ; if equal, not re-entered and Next wraps back
        STRLS   v1, [a2]                            ; if lower or same, not re-entered, so update Next
        MCR     p15, 0, a1, c7, c10, 4              ; drain WBuffer (waits, so no need for CPWAIT)
        Pull    "a2-a4, v1, v2, pc"

  [ XScaleMiniCache

Cache_MiniInvalidateAll_WB_Cal_LD ROUT
;
; similar to Cache_CleanAll_WB_Cal_LD, but must do direct reads (cannot use allocate address MCR), and
; 'cleans' to achieve invalidate as side effect (mini cache will be configured writethrough)
;
        Push    "a2-a4, v1, v2, lr"
        LDR     lr, =ZeroPage
        LDR     a1, [lr, #MCache_CleanBaseAddress]
        LDR     a2, =ZeroPage+MCache_CleanNextAddr
        LDR     a3, [lr, #MCache_Size]
        LDRB    a4, [lr, #MCache_LineLen]
        MOV     v2, #0
        SWP     v1, v2, [a2]                        ; read current CleanNextAddr, zero it (semaphore)
        TEQ     v1, #0                              ; but if it is already zero, we have re-entered
        ADDEQ   v1, a1, a3, LSL #1                  ; if re-entered, start clean at Base+2*Cache_Size
        ADDEQ   v2, v1, a3, LSL #1                  ; if re-entered, do a clean of 2*Cache_Size
        ADDNE   v2, v1, a3                          ; if not re-entered, do a clean of Cache_Size
10
        LDR     lr, [v1], a4                        ; read a line of cleaner data
        TEQ     v1, v2
        BNE     %BT10
        ADD     v2, a1, a3, LSL #1                  ; compare end address with Base+2*Size
        CMP     v1, v2
        MOVEQ   v1, a1                              ; if equal, not re-entered and Next wraps back
        STRLS   v1, [a2]                            ; if lower or same, not re-entered, so update Next
        ; note, no drain WBuffer, since we are really only invalidating a writethrough cache
        Pull    "a2-a4, v1, v2, pc"

  ] ; XScaleMiniCache


Cache_CleanInvalidateAll_WB_Cal_LD ROUT
;
; - cleans main cache (and invalidates wrt OS stuff as a side effect)
; - if mini cache in use (will be writethrough), 'cleans' in order to invalidate as side effect
;
        Push    "lr"
        BL      Cache_CleanAll_WB_Cal_LD
  [ XScaleMiniCache
        BL      Cache_MiniInvalidateAll_WB_Cal_LD
  ]
        MCR     p15, 0, a1, c7, c5, 0                ; invalidate ICache and BTB
        CPWAIT
        Pull    "pc"


Cache_InvalidateAll_WB_Cal_LD ROUT
;
; no clean, assume caller knows what's happening
;
        MCR     p15, 0, a1, c7, c7, 0           ; invalidate DCache, (MiniCache), ICache and BTB
        CPWAIT
        MOV     pc, lr


Cache_RangeThreshold_WB_Cal_LD ROUT
        LDR     a1, =ZeroPage
        LDR     a1, [a1, #DCache_RangeThreshold]
        MOV     pc, lr


MMU_ChangingUncached_WB_Cal_LD ROUT
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer (waits, so no need for CPWAIT)
 ]
TLB_InvalidateAll_WB_Cal_LD
        MCR     p15, 0, a1, c8, c7, 0           ; invalidate ITLB and DTLB
        CPWAIT
        MOV     pc, lr


MMU_ChangingUncachedEntry_WB_Cal_LD ROUT
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer (waits, so no need for CPWAIT)
 ]
TLB_InvalidateEntry_WB_Cal_LD
        MCR     p15, 0, a1, c8, c5, 1           ; invalidate ITLB entry
        MCR     p15, 0, a1, c8, c6, 1           ; invalidate DTLB entry
        CPWAIT
        MOV     pc, lr


DSB_ReadWrite_WB_Cal_LD ROUT
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer (waits, so no need for CPWAIT)
        MOV     pc, lr


IMB_Full_WB_Cal_LD
        Push    "lr"
        BL      Cache_CleanAll_WB_Cal_LD             ; clean DCache (wrt to non-interrupt stuff)
        MCR     p15, 0, a1, c7, c5, 0                ; invalidate ICache and BTB
        CPWAIT
        Pull    "pc"


IMB_Range_WB_Cal_LD ROUT
        SUB     a2, a2, a1
        CMP     a2, #32*1024                     ; arbitrary-ish range threshold
        ADD     a2, a2, a1
        BHS     IMB_Full_WB_Cal_LD
        Push    "lr"
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c10, 1           ; clean DCache entry
 [ :LNOT:XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 1            ; invalidate ICache entry
 ]
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
 [ XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 0            ; invalidate ICache and BTB
 |
        MCR     p15, 0, a1, c7, c5, 6            ; invalidate BTB
 ]
        MCR     p15, 0, a1, c7, c10, 4           ; drain WBuffer (waits, so no need for CPWAIT)
        Pull    "pc"


IMB_List_WB_Cal_LD ROUT
        CMP     a3, #32*1024                     ; arbitrary-ish range threshold
        BHS     IMB_Full_WB_Cal_LD
        Push    "v1-v2,lr"
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen]
05
        LDMIA   a1!, {v1-v2}
10
        MCR     p15, 0, v1, c7, c10, 1           ; clean DCache entry
 [ :LNOT:XScaleJTAGDebug
        MCR     p15, 0, v1, c7, c5, 1            ; invalidate ICache entry
 ]
        ADD     v1, v1, lr
        CMP     v1, v2
        BLO     %BT10
        CMP     a1, a2
        BNE     %BT05
 [ XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 0            ; invalidate ICache and BTB
 |
        MCR     p15, 0, a1, c7, c5, 6            ; invalidate BTB
 ]
        MCR     p15, 0, a1, c7, c10, 4           ; drain WBuffer (waits, so no need for CPWAIT)
        Pull    "v1-v2,pc"


MMU_Changing_WB_Cal_LD ROUT
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer (waits, so no need for CPWAIT)
 ]
        Push    "lr"
        MCR     p15, 0, a1, c8, c7, 0           ; invalidate ITLB and DTLB
        BL      Cache_CleanAll_WB_Cal_LD
        MCR     p15, 0, a1, c7, c5, 0           ; invalidate ICache and BTB
        CPWAIT
        Pull    "pc"

MMU_ChangingEntry_WB_Cal_LD ROUT
;
;there is no clean&invalidate DCache instruction, however we can do clean
;entry followed by invalidate entry without an interrupt hole, because they
;are for the same virtual address (and that virtual address will not be
;involved in interrupts, since it is involved in remapping)
;
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer (waits, so no need for CPWAIT)
 ]
        Push    "a2, lr"
        ADD     a2, a1, #PageSize
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen]
        MCR     p15, 0, a1, c8, c6, 1           ; invalidate DTLB entry
        MCR     p15, 0, a1, c8, c5, 1           ; invalidate ITLB entry
10
        MCR     p15, 0, a1, c7, c10, 1          ; clean DCache entry
        MCR     p15, 0, a1, c7, c6, 1           ; invalidate DCache entry
 [ :LNOT:XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 1           ; invalidate ICache entry
 ]
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
        MCR     p15, 0, a1, c7, c10, 4          ; drain WBuffer
 [ XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 0           ; invalidate ICache and BTB
 |
        MCR     p15, 0, a1, c7, c5, 6           ; invalidate BTB
 ]
        CPWAIT
        Pull    "a2, pc"


MMU_ChangingEntries_WB_Cal_LD ROUT
;
;same comments as MMU_ChangingEntry_WB_Cal_LD
;
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer (waits, so no need for CPWAIT)
 ]
        Push    "a2, a3, lr"
        MOV     a2, a2, LSL #Log2PageSize
        LDR     lr, =ZeroPage
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
        MOV     lr, a1
10
        MCR     p15, 0, a1, c8, c6, 1              ; invalidate DTLB entry
        MCR     p15, 0, a1, c8, c5, 1              ; invalidate ITLB entry
        ADD     a1, a1, #PageSize
        CMP     a1, a2
        BLO     %BT10
        MOV     a1, lr                             ; restore start address
20
        MCR     p15, 0, a1, c7, c10, 1             ; clean DCache entry
        MCR     p15, 0, a1, c7, c6, 1              ; invalidate DCache entry
 [ :LNOT:XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 1              ; invalidate ICache entry
 ]
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT20
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
 [ XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 0              ; invalidate ICache and BTB
 |
        MCR     p15, 0, a1, c7, c5, 6              ; invalidate BTB
 ]
        CPWAIT
        Pull    "a2, a3, pc"
;
30
        MCR     p15, 0, a1, c8, c7, 0              ; invalidate ITLB and DTLB
        BL      Cache_CleanInvalidateAll_WB_Cal_LD
        CPWAIT
        Pull    "a2, a3, pc"


Cache_CleanRange_WB_Cal_LD ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c10, 1             ; clean DCache entry
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer (waits, so no need for CPWAIT)
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       Cache_CleanAll_WB_Cal_LD


Cache_InvalidateRange_WB_Cal_LD ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3, LSL #1                     ;assume clean+invalidate slower than just invalidate
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c6, 1              ; invalidate DCache entry
 [ :LNOT:XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 1              ; invalidate ICache entry
 ]
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
 [ XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 0              ; invalidate ICache and BTB
 |
        MCR     p15, 0, a1, c7, c5, 6              ; invalidate BTB
 ]
        CPWAIT
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       Cache_CleanInvalidateAll_WB_Cal_LD


Cache_CleanInvalidateRange_WB_Cal_LD ROUT
;
;same comments as MMU_ChangingEntry_WB_Cal_LD
;
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
        MCR     p15, 0, a1, c7, c10, 1             ; clean DCache entry
        MCR     p15, 0, a1, c7, c6, 1              ; invalidate DCache entry
 [ :LNOT:XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 1              ; invalidate ICache entry
 ]
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer
 [ XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 0              ; invalidate ICache and BTB
 |
        MCR     p15, 0, a1, c7, c5, 6              ; invalidate BTB
 ]
        CPWAIT
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       Cache_CleanInvalidateAll_WB_Cal_LD

MMU_ChangingUncachedEntries_WB_Cal_LD ROUT
 [ CacheablePageTables
        MCR     p15, 0, a1, c7, c10, 4             ; drain WBuffer (waits, so no need for CPWAIT)
 ]
        CMP     a2, #32                            ; arbitrary-ish threshold
        BHS     %FT20
        Push    "lr"
        MOV     lr, a2
10
        MCR     p15, 0, a1, c8, c6, 1              ; invalidate DTLB entry
        MCR     p15, 0, a1, c8, c5, 1              ; invalidate ITLB entry
        SUBS    lr, lr, #1
        ADD     a1, a1, #PageSize
        BNE     %BT10
        CPWAIT
        Pull    "pc"
;
20
        MCR     p15, 0, a1, c8, c7, 0              ; invalidate ITLB and DTLB
        CPWAIT
        MOV     pc, lr


ICache_InvalidateRange_WB_Cal_LD ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen]
10
 [ :LNOT:XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 1              ; invalidate ICache entry
 ]
        ADD     a1, a1, a3
        CMP     a1, a2
        BLO     %BT10
 [ XScaleJTAGDebug
        MCR     p15, 0, a1, c7, c5, 0              ; invalidate ICache and BTB
 |
        MCR     p15, 0, a1, c7, c5, 6              ; invalidate BTB
 ]
        CPWAIT
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       ICache_InvalidateAll_WB_Cal_LD


ICache_InvalidateAll_WB_Cal_LD
        MCR     p15, 0, a1, c7, c5, 0                ; invalidate ICache and BTB
        CPWAIT
        MOV     pc, lr

 ] ; MEMM_Type = "ARM600"

 [ MEMM_Type = "VMSAv6" ; Need appropriate myIMB, etc. implementations if this is to be removed
 
; --------------------------------------------------------------------------
; ----- ARMops for Cortex-A8 and the like ----------------------------------
; --------------------------------------------------------------------------

; WB_CR7_Lx refers to ARMs with writeback data cache, cleaned with
; register 7, and (potentially) multiple cache levels
;
; DCache_LineLen = log2(line len)-2 for smallest data/unified cache line length
; ICache_LineLen = log2(line len)-2 for smallest instruction cache line length
; DCache_RangeThreshold = clean threshold for data cache
; Cache_Lx_Info = Cache level ID register
; Cache_Lx_DTable = Cache size identification register for all 7 data/unified caches
; Cache_Lx_ITable = Cache size identification register for all 7 instruction caches

; ARMv7 cache maintenance routines are a bit long-winded, so we use this macro
; to reduce the risk of mistakes creeping in due to code duplication
;
; $op: Operation to perform ('clean', 'invalidate', 'cleaninvalidate')
; $levels: Which levels to apply to ('lou', 'loc', 'louis') 
; Uses r0-r8 & lr as temp
; Performs the indicated op on the indicated data & unified caches
;
; Code based around the alternate/faster code given in the ARMv7 ARM (section
; B2.2.4, alternate/faster code only in doc revision 9), but tightened up a bit
;
; Note that HAL_InvalidateCache_ARMvF uses its own implementation of this
; algorithm, since it must cope with different temporary registers and it needs
; to read the cache info straight from the CP15 registers
;
        MACRO
        MaintainDataCache_WB_CR7_Lx $op, $levels
        LDR     lr, =ZeroPage
        LDR     r0, [lr, #Cache_Lx_Info]!
        ADD     lr, lr, #Cache_Lx_DTable-Cache_Lx_Info
      [ "$levels"="lou"
        ANDS    r3, r0, #&38000000
        MOV     r3, r3, LSR #26 ; Cache level value (naturally aligned)
      |
      [ "$levels"="loc"
        ANDS    r3, r0, #&07000000
        MOV     r3, r3, LSR #23 ; Cache level value (naturally aligned)
      |
      [ "$levels"="louis"
        ANDS    r3, r0, #&00E00000
        MOV     r3, r3, LSR #20 ; Cache level value (naturally aligned)
      |
        ! 1, "Unrecognised levels"
      ]
      ]
      ]
        BEQ     %FT50
        MOV     r8, #0 ; Current cache level
10 ; Loop1
        ADD     r2, r8, r8, LSR #1 ; Work out 3 x cachelevel
        MOV     r1, r0, LSR r2 ; bottom 3 bits are the Cache type for this level
        AND     r1, r1, #7 ; get those 3 bits alone
        CMP     r1, #2
        BLT     %FT40 ; no cache or only instruction cache at this level
        LDR     r1, [lr, r8, LSL #1] ; read CCSIDR to r1
        AND     r2, r1, #CCSIDR_LineSize_mask ; extract the line length field
        ADD     r2, r2, #4 ; add 4 for the line length offset (log2 16 bytes)
        LDR     r7, =CCSIDR_Associativity_mask:SHR:CCSIDR_Associativity_pos
        AND     r7, r7, r1, LSR #CCSIDR_Associativity_pos ; r7 is the max number on the way size (right aligned)
        CLZ     r5, r7 ; r5 is the bit position of the way size increment
        LDR     r4, =CCSIDR_NumSets_mask:SHR:CCSIDR_NumSets_pos
        AND     r4, r4, r1, LSR #CCSIDR_NumSets_pos ; r4 is the max number of the index size (right aligned)
20 ; Loop2
        MOV     r1, r4 ; r1 working copy of the max index size (right aligned)
30 ; Loop3
        ORR     r6, r8, r7, LSL r5 ; factor in the way number and cache number into r6
        ORR     r6, r6, r1, LSL r2 ; factor in the index number
      [ "$op"="clean"
        DCCSW   r6 ; Clean
      |
      [ "$op"="invalidate"
        DCISW   r6 ; Invalidate
      |
      [ "$op"="cleaninvalidate"
        DCCISW  r6 ; Clean & invalidate
      |
        ! 1, "Unrecognised op"
      ]
      ]
      ]
        SUBS    r1, r1, #1 ; decrement the index
        BGE     %BT30
        SUBS    r7, r7, #1 ; decrement the way number
        BGE     %BT20
        DSB                ; Cortex-A7 errata 814220: DSB required when changing cache levels when using set/way operations. This also counts as our end-of-maintenance DSB.
40 ; Skip
        ADD     r8, r8, #2
        CMP     r3, r8
        BGT     %BT10
50 ; Finished
        MEND

Cache_CleanAll_WB_CR7_Lx ROUT
; Clean cache by traversing all sets and ways for all data caches
        Push    "r1-r8,lr"
        MaintainDataCache_WB_CR7_Lx clean, loc
        Pull    "r1-r8,pc"


Cache_CleanInvalidateAll_WB_CR7_Lx ROUT
;
; similar to Cache_CleanAll, but does clean&invalidate of Dcache, and invalidates ICache
;
        Push    "r1-r8,lr"
        MaintainDataCache_WB_CR7_Lx cleaninvalidate, loc
        ICIALLU                       ; invalidate ICache + branch predictors
        DSB                           ; Wait for cache/branch invalidation to complete
        ISB                           ; Ensure that the effects of the completed cache/branch invalidation are visible
        Pull    "r1-r8,pc"


Cache_InvalidateAll_WB_CR7_Lx ROUT
;
; no clean, assume caller knows what's happening
;
        Push    "r1-r8,lr"
        MaintainDataCache_WB_CR7_Lx invalidate, loc
        ICIALLU                       ; invalidate ICache + branch predictors
        DSB                           ; Wait for cache/branch invalidation to complete
        ISB                           ; Ensure that the effects of the completed cache/branch invalidation are visible 
        Pull    "r1-r8,pc"


Cache_RangeThreshold_WB_CR7_Lx ROUT
        LDR     a1, =ZeroPage
        LDR     a1, [a1, #DCache_RangeThreshold]
        MOV     pc, lr


; In:  r1 = cache level (0-based)
; Out: r0 = Flags
;           bits 0-2: cache type:
;              000 -> none
;              001 -> instruction
;              010 -> data
;              011 -> split
;              100 -> unified
;              1xx -> reserved
;           Other bits: reserved
;      r1 = D line length
;      r2 = D size
;      r3 = I line length
;      r4 = I size
;      r0-r4 = zero if cache level not present
Cache_Examine_WB_CR7_Lx ROUT
        Entry   "r5"
        LDR     r5, =ZeroPage
        LDR     r0, [r5, #Cache_Lx_Info]!
        ADD     r5, r5, #Cache_Lx_DTable-Cache_Lx_Info
        BIC     r0, r0, #&00E00000
        ; Shift the CLIDR until we hit a zero entry or the desired level
        ; (could shift by exactly the amount we want... but ARM say not to do
        ; that since they may decide to re-use bits)
10
        TEQ     r1, #0
        TSTNE   r0, #7
        SUBNE   r1, r1, #1
        MOVNE   r0, r0, LSR #3
        ADDNE   r5, r5, #4
        BNE     %BT10
        ANDS    r0, r0, #7
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        MOV     r4, #0
        EXIT    EQ
        TST     r0, #6 ; Data or unified cache present?
        BEQ     %FT20
        LDR     lr, [r5]
        LDR     r1, =CCSIDR_NumSets_mask:SHR:CCSIDR_NumSets_pos
        LDR     r2, =CCSIDR_Associativity_mask:SHR:CCSIDR_Associativity_pos
        AND     r1, r1, lr, LSR #CCSIDR_NumSets_pos
        AND     r2, r2, lr, LSR #CCSIDR_Associativity_pos
        ADD     r1, r1, #1
        ADD     r2, r2, #1
        MUL     r2, r1, r2
        AND     r1, lr, #CCSIDR_LineSize_mask
        ASSERT  CCSIDR_LineSize_pos = 0
        MOV     lr, #16
        MOV     r1, lr, LSL r1
        MUL     r2, r1, r2
20
        TEQ     r0, #4 ; Unified cache?
        MOVEQ   r3, r1
        MOVEQ   r4, r2
        TST     r0, #1 ; Instruction cache present?
        EXIT    EQ
        LDR     lr, [r5, #Cache_Lx_ITable-Cache_Lx_DTable]        
        LDR     r3, =CCSIDR_NumSets_mask:SHR:CCSIDR_NumSets_pos
        LDR     r4, =CCSIDR_Associativity_mask:SHR:CCSIDR_Associativity_pos
        AND     r3, r3, lr, LSR #CCSIDR_NumSets_pos
        AND     r4, r4, lr, LSR #CCSIDR_Associativity_pos
        ADD     r3, r3, #1
        ADD     r4, r4, #1
        MUL     r4, r3, r4
        AND     r3, lr, #CCSIDR_LineSize_mask
        ASSERT  CCSIDR_LineSize_pos = 0
        MOV     lr, #16
        MOV     r3, lr, LSL r3
        MUL     r4, r3, r4
        EXIT


MMU_ChangingUncached_WB_CR7_Lx
        DSB            ; Ensure the page table write has actually completed
        ISB            ; Also required
TLB_InvalidateAll_WB_CR7_Lx ROUT
        TLBIALL                       ; invalidate ITLB and DTLB
        BPIALL                        ; invalidate branch predictors
        DSB                           ; Wait for cache/branch invalidation to complete
        ISB                           ; Ensure that the effects of the completed cache/branch invalidation are visible         
        MOV     pc, lr


; a1 = page affected (page aligned address)
;
MMU_ChangingUncachedEntry_WB_CR7_Lx
        DSB
        ISB
TLB_InvalidateEntry_WB_CR7_Lx ROUT
        TLBIMVA a1                    ; invalidate ITLB & DTLB entry
        BPIALL                        ; invalidate branch predictors
        DSB                           ; Wait for cache/branch invalidation to complete
        ISB                           ; Ensure that the effects of the completed cache/branch invalidation are visible         
        MOV     pc, lr


IMB_Full_WB_CR7_Lx ROUT
;
; do: clean DCache; drain WBuffer, invalidate ICache/branch predictor
; Luckily, we only need to clean as far as the level of unification
;
        Push    "r1-r8,lr"
        MaintainDataCache_WB_CR7_Lx clean, lou
        ICIALLU                       ; invalidate ICache
        DSB                           ; Wait for cache/branch invalidation to complete
        ISB                           ; Ensure that the effects of the completed cache/branch invalidation are visible
        Pull    "r1-r8,pc"

;  a1 = start address (inclusive, cache line aligned)
;  a2 = end address (exclusive, cache line aligned)
;
IMB_Range_WB_CR7_Lx ROUT
        SUB     a2, a2, a1
        CMP     a2, #32*1024 ; Maximum L1 cache size on Cortex-A8 is 32K, use that to guess what approach to take
        ADD     a2, a2, a1
        BHS     IMB_Full_WB_CR7_Lx
        Push    "a1,a3,lr"
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen] ; log2(line len)-2
        MOV     a3, #4
        MOV     lr, a3, LSL lr
10
        DCCMVAU a1                    ; clean DCache entry by VA to PoU
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
        DSB          ; Wait for clean to complete
        Pull    "a1" ; Get start address back
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #ICache_LineLen] ; Use ICache line length, just in case D&I length differ
        MOV     lr, a3, LSL lr
10
        ICIMVAU a1                    ; invalidate ICache entry
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
        BPIALL                        ; invalidate branch predictors
        DSB                           ; Wait for cache/branch invalidation to complete
        ISB                           ; Ensure that the effects of the completed cache/branch invalidation are visible
        Pull    "a3,pc"

;  a1 = pointer to list of (start, end) address pairs
;  a2 = pointer to end of list
;  a3 = total amount of memory to be synchronised
;
IMB_List_WB_CR7_Lx ROUT
        CMP     a3, #32*1024 ; Maximum L1 cache size on Cortex-A8 is 32K, use that to guess what approach to take
        BHS     IMB_Full_WB_CR7_Lx
        Push    "a1,a3,v1-v2,lr"
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen] ; log2(line len)-2
        MOV     a3, #4
        MOV     lr, a3, LSL lr
05
        LDMIA   a1!, {v1-v2}
10
        DCCMVAU v1                    ; clean DCache entry by VA to PoU
        ADD     v1, v1, lr
        CMP     v1, v2
        BLO     %BT10
        CMP     a1, a2
        BNE     %BT05
        DSB          ; Wait for clean to complete
        Pull    "a1" ; Get start address back
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #ICache_LineLen] ; Use ICache line length, just in case D&I length differ
        MOV     lr, a3, LSL lr
05
        LDMIA   a1!, {v1-v2}
10
        ICIMVAU v1                    ; invalidate ICache entry
        ADD     v1, v1, lr
        CMP     v1, v2
        BLO     %BT10
        CMP     a1, a2
        BNE     %BT05
        BPIALL                        ; invalidate branch predictors
        DSB                           ; Wait for cache/branch invalidation to complete
        ISB                           ; Ensure that the effects of the completed cache/branch invalidation are visible
        Pull    "a3,v1-v2,pc"

MMU_Changing_WB_CR7_Lx ROUT
        DSB                           ; Ensure the page table write has actually completed
        ISB                           ; Also required
        TLBIALL                       ; invalidate ITLB and DTLB
        DSB                           ; Wait for TLB invalidation to complete
        ISB                           ; Ensure that the effects are visible
        B       Cache_CleanInvalidateAll_WB_CR7_Lx

; a1 = page affected (page aligned address)
;
MMU_ChangingEntry_WB_CR7_Lx ROUT
        Push    "a2, lr"
        DSB                           ; Ensure the page table write has actually completed
        ISB                           ; Also required
        TLBIMVA a1                    ; invalidate DTLB and ITLB
        DSB                           ; Wait for TLB invalidation to complete
        ISB                           ; Ensure that the effects are visible
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #DCache_LineLen] ; log2(line len)-2
        MOV     a2, #4
        MOV     lr, a2, LSL lr
        ADD     a2, a1, #PageSize
10
        DCCIMVAC a1                   ; clean&invalidate DCache entry to PoC
        ADD     a1, a1, lr
        CMP     a1, a2
        BNE     %BT10
        DSB     ; Wait for clean to complete
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #ICache_LineLen] ; Use ICache line length, just in case D&I length differ
        MOV     a1, #4
        MOV     lr, a1, LSL lr
        SUB     a1, a2, #PageSize ; Get start address back
10
        ICIMVAU a1                    ; invalidate ICache entry to PoU
        ADD     a1, a1, lr
        CMP     a1, a2
        BNE     %BT10
        BPIALL                        ; invalidate branch predictors
        DSB
        ISB
        Pull    "a2, pc"

; a1 = first page affected (page aligned address)
; a2 = number of pages
;
MMU_ChangingEntries_WB_CR7_Lx ROUT
        Push    "a2, a3, lr"
        DSB     ; Ensure the page table write has actually completed
        ISB     ; Also required
        MOV     a2, a2, LSL #Log2PageSize
        LDR     lr, =ZeroPage
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT90
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen] ; log2(line len)-2
        MOV     lr, #4
        MOV     a3, lr, LSL a3
        MOV     lr, a1
10
        TLBIMVA a1                    ; invalidate DTLB & ITLB entry
        ADD     a1, a1, #PageSize
        CMP     a1, a2
        BNE     %BT10
        DSB
        ISB
        MOV     a1, lr                ; Get start address back
20
        DCCIMVAC a1                   ; clean&invalidate DCache entry to PoC
        ADD     a1, a1, a3
        CMP     a1, a2
        BNE     %BT20
        DSB     ; Wait for clean to complete
        LDR     a3, =ZeroPage
        LDRB    a3, [a3, #ICache_LineLen] ; Use ICache line length, just in case D&I length differ
        MOV     a1, #4
        MOV     a3, a1, LSL a3
        MOV     a1, lr                ; Get start address back
30
        ICIMVAU a1                    ; invalidate ICache entry to PoU
        ADD     a1, a1, a3
        CMP     a1, a2
        BNE     %BT30
        BPIALL                        ; invalidate branch predictors
        DSB
        ISB
        Pull    "a2, a3, pc"
;
90
        TLBIALL                       ; invalidate ITLB and DTLB
        DSB                           ; Wait TLB invalidation to complete
        ISB                           ; Ensure that the effects are visible 
        BL      Cache_CleanInvalidateAll_WB_CR7_Lx
        Pull    "a2, a3, pc"

;  a1 = start address (inclusive, cache line aligned)
;  a2 = end address (exclusive, cache line aligned)
;
Cache_CleanRange_WB_CR7_Lx ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen] ; log2(line len)-2
        MOV     lr, #4
        MOV     a3, lr, LSL a3
        MOV     lr, a1
10
        DCCMVAC a1                    ; clean DCache entry to PoC
        ADD     a1, a1, a3
        CMP     a1, a2
        BNE     %BT10
        DSB     ; Wait for clean to complete
        ISB
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       Cache_CleanAll_WB_CR7_Lx

;  a1 = start address (inclusive, cache line aligned)
;  a2 = end address (exclusive, cache line aligned)
;
Cache_InvalidateRange_WB_CR7_Lx ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3, LSL #1                     ;assume clean+invalidate slower than just invalidate
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen] ; log2(line len)-2
        MOV     lr, #4
        MOV     a3, lr, LSL a3
        MOV     lr, a1
10
        DCIMVAC a1                    ; invalidate DCache entry to PoC
        ADD     a1, a1, a3
        CMP     a1, a2
        BNE     %BT10
        LDR     a3, =ZeroPage
        LDRB    a3, [a3, #ICache_LineLen] ; Use ICache line length, just in case D&I length differ
        MOV     a1, #4
        MOV     a3, a1, LSL a3
        MOV     a1, lr ; Get start address back
10
        ICIMVAU a1                    ; invalidate ICache entry to PoU
        ADD     a1, a1, a3
        CMP     a1, a2
        BNE     %BT10
        BPIALL                        ; invalidate branch predictors
        DSB
        ISB
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       Cache_CleanInvalidateAll_WB_CR7_Lx

;  a1 = start address (inclusive, cache line aligned)
;  a2 = end address (exclusive, cache line aligned)
;
Cache_CleanInvalidateRange_WB_CR7_Lx ROUT
        Push    "a2, a3, lr"
        LDR     lr, =ZeroPage
        SUB     a2, a2, a1
        LDR     a3, [lr, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     a2, a3
        BHS     %FT30
        ADD     a2, a2, a1                         ;clean end address (exclusive)
        LDRB    a3, [lr, #DCache_LineLen] ; log2(line len)-2
        MOV     lr, #4
        MOV     a3, lr, LSL a3
        MOV     lr, a1
10
        DCCIMVAC a1                   ; clean&invalidate DCache entry to PoC
        ADD     a1, a1, a3
        CMP     a1, a2
        BNE     %BT10
        DSB     ; Wait for clean to complete
        LDR     a3, =ZeroPage
        LDRB    a3, [a3, #ICache_LineLen] ; Use ICache line length, just in case D&I length differ
        MOV     a1, #4
        MOV     a3, a1, LSL a3
        MOV     a1, lr ; Get start address back
10
        ICIMVAU a1                    ; invalidate ICache entry to PoU
        ADD     a1, a1, a3
        CMP     a1, a2
        BNE     %BT10
        BPIALL                        ; invalidate branch predictors
        DSB
        ISB
        Pull    "a2, a3, pc"
;
30
        Pull    "a2, a3, lr"
        B       Cache_CleanInvalidateAll_WB_CR7_Lx

; a1 = first page affected (page aligned address)
; a2 = number of pages
;
MMU_ChangingUncachedEntries_WB_CR7_Lx ROUT
        Push    "a2,lr"
        DSB     ; Ensure the page table write has actually completed
        ISB     ; Also required
        CMP     a2, #32               ; arbitrary-ish threshold
        BLO     %FT10
        TLBIALL                       ; invalidate ITLB and DTLB
        B       %FT20
10
        TLBIMVA a1                    ; invalidate DTLB & ITLB entry
        ADD     a1, a1, #PageSize
        SUBS    a2, a2, #1
        BNE     %BT10
20
        BPIALL                        ; invalidate branch predictors
        DSB
        ISB
        Pull    "a2,pc"

;  a1 = start address (inclusive, cache line aligned)
;  a2 = end address (exclusive, cache line aligned)
;
ICache_InvalidateRange_WB_CR7_Lx ROUT
        SUB     a2, a2, a1
        CMP     a2, #32*1024 ; Maximum L1 cache size on Cortex-A8 is 32K, use that to guess what approach to take
        ADD     a2, a2, a1
        BHS     ICache_InvalidateAll_WB_CR7_Lx
        Push    "a3,lr"
        MOV     a3, #4
        LDR     lr, =ZeroPage
        LDRB    lr, [lr, #ICache_LineLen]
        MOV     lr, a3, LSL lr
10
        ICIMVAU a1                    ; invalidate ICache entry
        ADD     a1, a1, lr
        CMP     a1, a2
        BLO     %BT10
        BPIALL                        ; invalidate branch predictors
        DSB                           ; Wait for cache/branch invalidation to complete
        ISB                           ; Ensure that the effects of the completed cache/branch invalidation are visible
        Pull    "a3,pc"

ICache_InvalidateAll_WB_CR7_Lx ROUT
        ICIALLU                       ; invalidate ICache
        BPIALL                        ; invalidate branch predictors
        DSB                           ; Wait for cache/branch invalidation to complete
        ISB                           ; Ensure that the effects of the completed cache/branch invalidation are visible         
        MOV     pc, lr
 
; --------------------------------------------------------------------------
; ----- ARMops for PL310 L2 cache controller--------------------------------
; --------------------------------------------------------------------------

; These are a hybrid of the standard ARMv7 ARMops (WB_CR7_Lx) and the PL310
; cache maintenance ops. Currently they're only used on Cortex-A9 systems, so
; may need modifications to work with other systems.
; Specifically, the code assumes the PL310 is being used in non-exclusive mode.
;
; To make the code fully re-entrant and MP-safe, we avoid using the background
; operations (INV_WAY, CLEAN_WAY, CLEAN_INV_WAY).

        MACRO
        PL310Sync $regs, $temp
        ; Errata 753970 requires us to write to a different location when
        ; performing a sync operation for r3p0
        LDR     $temp, [$regs, #PL310_REG0_CACHE_ID]
        AND     $temp, $temp, #&3f
        TEQ     $temp, #PL310_R3P0
        MOV     $temp, #0
        STREQ   $temp, [$regs, #PL310_REG7_CACHE_SYNC_753970]
        STRNE   $temp, [$regs, #PL310_REG7_CACHE_SYNC]
        MEND

PL310Threshold * 1024*1024 ; Arbitrary threshold for full clean

Cache_CleanInvalidateAll_PL310 ROUT
        ; Errata 727915 workaround - use CLEAN_INV_INDEX instead of CLEAN_INV_WAY
        ; Also, CLEAN_INV_WAY is a background op, while CLEAN_INV_INDEX is atomic.
        Entry   "a2-a4"
        LDR     a2, =ZeroPage
        LDR     a2, [a2, #Cache_HALDevice]
        LDR     a2, [a2, #HALDevice_Address]
        ; Clean ARM caches
        BL      Cache_CleanAll_WB_CR7_Lx
        ; Determine PL310 way, index count        
        LDR     a1, [a2, #PL310_REG1_AUX_CONTROL]
        AND     a3, a1, #1<<16
        AND     a1, a1, #7<<17
        MOV     a3, a3, LSL #15
        MOV     a1, a1, LSR #17
        LDR     a4, =&FF<<5
        ORR     a3, a3, #7<<28          ; a3 = max way number (inclusive)
        ORR     a4, a4, a4, LSL a1      ; a4 = max index number (inclusive)
10
        ORR     a1, a3, a4
20
        STR     a1, [a2, #PL310_REG7_CLEAN_INV_INDEX]
        SUBS    a1, a1, #1<<28          ; next way
        BCS     %BT20                   ; underflow?
        SUBS    a4, a4, #1<<5           ; next index
        BGE     %BT10
        ; Ensure the ops are actually complete
        DSB
        ; Clean & invalidate ARM caches
        PullEnv
        B       Cache_CleanInvalidateAll_WB_CR7_Lx

Cache_CleanAll_PL310 ROUT
        Entry   "a2-a4"
        LDR     a2, =ZeroPage
        LDR     a2, [a2, #Cache_HALDevice]
        LDR     a2, [a2, #HALDevice_Address]
        ; Clean ARM caches
        BL      Cache_CleanAll_WB_CR7_Lx
        ; Determine PL310 way, index count        
        LDR     a1, [a2, #PL310_REG1_AUX_CONTROL]
        AND     a3, a1, #1<<16
        AND     a1, a1, #7<<17
        MOV     a3, a3, LSL #15
        MOV     a1, a1, LSR #17
        LDR     a4, =&FF<<5
        ORR     a3, a3, #7<<28          ; a3 = max way number (inclusive)
        ORR     a4, a4, a4, LSL a1      ; a4 = max index number (inclusive)
10
        ORR     a1, a3, a4
20
        STR     a1, [a2, #PL310_REG7_CLEAN_INDEX]
        SUBS    a1, a1, #1<<28          ; next way
        BCS     %BT20                   ; underflow?
        SUBS    a4, a4, #1<<5           ; next index
        BGE     %BT10
        ; Ensure the ops are actually complete
        DSB
        EXIT

; This op will be rarely (if ever) used, just implement as clean + invalidate
Cache_InvalidateAll_PL310 * Cache_CleanInvalidateAll_PL310

Cache_RangeThreshold_PL310 ROUT
        MOV     a1, #PL310Threshold
        MOV     pc, lr

Cache_Examine_PL310 ROUT
        ; Assume that the PL310 is the level 2 cache
        CMP     r1, #1
        BLT     Cache_Examine_WB_CR7_Lx
        MOVGT   r0, #0
        MOVGT   r1, #0
        MOVGT   r2, #0
        MOVGT   r3, #0
        MOVGT   r4, #0
        MOVGT   pc, lr
        LDR     r0, =ZeroPage
        LDR     r0, [r0, #Cache_HALDevice]
        LDR     r0, [r0, #HALDevice_Address]
        LDR     r0, [r0, #PL310_REG1_AUX_CONTROL]
        AND     r2, r0, #&E0000 ; Get way size
        TST     r0, #1:SHL:16 ; Check associativity
        MOV     r2, r2, LSR #17
        MOVEQ   r1, #8*1024*8 ; 8KB base way size with 8 way associativity
        MOVNE   r1, #8*1024*16 ; 8KB base way size with 16 way associativity
        MOV     r2, r1, LSL r2
        ; Assume this really is a PL310 (32 byte line size, unified architecture)
        MOV     r0, #4
        MOV     r1, #32
        MOV     r3, #32
        MOV     r4, r2
        MOV     pc, lr

DSB_ReadWrite_PL310 ROUT
        Entry
        LDR     lr, =ZeroPage
        LDR     lr, [lr, #Cache_HALDevice]
        LDR     lr, [lr, #HALDevice_Address]
        ; Drain ARM write buffer
        DSB     SY
        ; Drain PL310 write buffer
        PL310Sync lr, a1
        ; Ensure the PL310 sync is complete
        DSB     SY
        EXIT

DSB_Write_PL310 ROUT
        Entry
        LDR     lr, =ZeroPage
        LDR     lr, [lr, #Cache_HALDevice]
        LDR     lr, [lr, #HALDevice_Address]
        ; Drain ARM write buffer
        DSB     ST
        ; Drain PL310 write buffer
        PL310Sync lr, a1
        ; Ensure the PL310 sync is complete
        DSB     ST
        EXIT

DMB_ReadWrite_PL310 ROUT
        Entry
        LDR     lr, =ZeroPage
        LDR     lr, [lr, #Cache_HALDevice]
        LDR     lr, [lr, #HALDevice_Address]
        ; Drain ARM write buffer
        DMB     SY
        ; Drain PL310 write buffer
        PL310Sync lr, a1
        ; Ensure the PL310 sync is complete
        DMB     SY
        EXIT

DMB_Write_PL310 ROUT
        Entry
        LDR     lr, =ZeroPage
        LDR     lr, [lr, #Cache_HALDevice]
        LDR     lr, [lr, #HALDevice_Address]
        ; Drain ARM write buffer
        DMB     ST
        ; Drain PL310 write buffer
        PL310Sync lr, a1
        ; Ensure the PL310 sync is complete
        DMB     ST
        EXIT

MMU_Changing_PL310 ROUT
        DSB     ; Ensure the page table write has actually completed
        ISB     ; Also required
        TLBIALL ; invalidate ITLB and DTLB
        DSB     ; Wait for TLB invalidation to complete
        ISB     ; Ensure that the effects are visible
        B       Cache_CleanInvalidateAll_PL310

; a1 = virtual address of page affected (page aligned address)
;
MMU_ChangingEntry_PL310 ROUT
        Push    "a1-a2,lr"
        ; Do the TLB maintenance
        BL      MMU_ChangingUncachedEntry_WB_CR7_Lx
        ; Keep the rest simple by just calling through to MMU_ChangingEntries
        MOV     a2, #1
        B       %FT10

; a1 = virtual address of first page affected (page aligned address)
; a2 = number of pages
;
MMU_ChangingEntries_PL310
        Push    "a1-a2,lr"
        ; Do the TLB maintenance
        BL      MMU_ChangingUncachedEntries_WB_CR7_Lx
10      ; Arrive here from MMU_ChangingEntry_PL310
        LDR     a1, [sp]
        ; Do PL310 clean & invalidate
        ADD     a2, a1, a2, LSL #Log2PageSize
        BL      Cache_CleanInvalidateRange_PL310
        Pull    "a1-a2,pc"

; a1 = start address (inclusive, cache line aligned)
; a2 = end address (exclusive, cache line aligned)
;
Cache_CleanInvalidateRange_PL310 ROUT
        Entry   "a2-a4,v1"
        ; For simplicity, align to page boundaries
        LDR     a4, =PageSize-1
        ADD     a2, a2, a4
        BIC     a1, a1, a4
        BIC     a3, a2, a4
        SUB     v1, a3, a1
        CMP     v1, #PL310Threshold
        BHS     %FT90
        MOV     a4, a1
        ; Behave in a similar way to the PL310 full clean & invalidate:
        ; * Clean ARM
        ; * Clean & invalidate PL310
        ; * Clean & invalidate ARM

        ; a4 = base virtual address
        ; a3 = end virtual address
        ; v1 = length

        ; Clean ARM
        LDR     a1, =ZeroPage
        LDR     lr, [a1, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     lr, v1
        ADRLE   lr, %FT30
        BLE     Cache_CleanAll_WB_CR7_Lx
        ; Clean each page in turn
        LDRB    a2, [a1, #DCache_LineLen] ; log2(line len)-2
        MOV     lr, #4
        MOV     a2, lr, LSL a2
20
        DCCMVAC a4                      ; clean DCache entry to PoC
        ADD     a4, a4, a2
        CMP     a4, a3
        BNE     %BT20
        DSB     ; Wait for clean to complete
        SUB     a4, a3, v1

30
        ; Clean & invalidate PL310
        LDR     a1, =ZeroPage
        LDR     a2, [a1, #Cache_HALDevice]
        LDR     a2, [a2, #HALDevice_Address]
        ; Clean & invalidate each line/index of the pages
50
        ; Convert logical addr to physical.
        ; Use the ARMv7 CP15 registers for convenience.
        PHPSEI
        MCR     p15, 0, a4, c7, c8, 0   ; ATS1CPR
        ISB
        MRC     p15, 0, a1, c7, c4, 0   ; Get result
        PLP
        TST     a1, #1
        ADD     a4, a4, #PageSize
        BNE     %FT75                   ; Lookup failed - assume this means that the page doesn't need cleaning from the PL310
        ; Point to last line in page, and mask out attributes returned by the
        ; lookup
        ORR     a1, a1, #&FE0
        BIC     a1, a1, #&01F
60
        STR     a1, [a2, #PL310_REG7_CLEAN_INV_PA]
        TST     a1, #&FE0
        SUB     a1, a1, #1<<5           ; next index
        BNE     %BT60
75
        CMP     a4, a3
        BNE     %BT50
        ; Sync
        DSB
        ; Clean & invalidate ARM
        SUB     a1, a3, v1
        MOV     a2, a3
        BL      Cache_CleanInvalidateRange_WB_CR7_Lx
        EXIT

90        
        ; Full clean required
        PullEnv
        B       Cache_CleanInvalidateAll_PL310

; a1 = start address (inclusive, cache line aligned)
; a2 = end address (exclusive, cache line aligned)
;
Cache_CleanRange_PL310 ROUT
        Entry   "a2-a4,v1"
        ; For simplicity, align to page boundaries
        LDR     a4, =PageSize-1
        ADD     a2, a2, a4
        BIC     a1, a1, a4
        BIC     a3, a2, a4
        SUB     v1, a3, a1
        CMP     v1, #PL310Threshold
        BHS     %FT90
        MOV     a4, a1
        ; a4 = base virtual address
        ; a3 = end virtual address
        ; v1 = length

        ; Clean ARM
        LDR     a1, =ZeroPage
        LDR     lr, [a1, #DCache_RangeThreshold]   ;check whether cheaper to do global clean
        CMP     lr, v1
        ADRLE   lr, %FT30
        BLE     Cache_CleanAll_WB_CR7_Lx
        ; Clean each page in turn
        LDRB    a2, [a1, #DCache_LineLen] ; log2(line len)-2
        MOV     lr, #4
        MOV     a2, lr, LSL a2
20
        DCCMVAC a4                      ; clean DCache entry to PoC
        ADD     a4, a4, a2
        CMP     a4, a3
        BNE     %BT20
        DSB     ; Wait for clean to complete
        SUB     a4, a3, v1

30
        ; Clean PL310
        LDR     a1, =ZeroPage
        LDR     a2, [a1, #Cache_HALDevice]
        LDR     a2, [a2, #HALDevice_Address]
        ; Clean & invalidate each line/index of the pages
50
        ; Convert logical addr to physical.
        ; Use the ARMv7 CP15 registers for convenience.
        PHPSEI
        MCR     p15, 0, a4, c7, c8, 0   ; ATS1CPR
        ISB
        MRC     p15, 0, a1, c7, c4, 0   ; Get result
        PLP
        TST     a1, #1
        ADD     a4, a4, #PageSize
        BNE     %FT75                   ; Lookup failed - assume this means that the page doesn't need cleaning from the PL310
        ; Point to last line in page, and mask out attributes returned by the
        ; lookup
        ORR     a1, a1, #&FE0
        BIC     a1, a1, #&01F
60
        STR     a1, [a2, #PL310_REG7_CLEAN_PA]
        TST     a1, #&FE0
        SUB     a1, a1, #1<<5           ; next index
        BNE     %BT60
75
        CMP     a4, a3
        BNE     %BT50
        ; Sync
        DMB
        EXIT

90        
        ; Full clean required
        PullEnv
        B       Cache_CleanInvalidateAll_PL310

Cache_InvalidateRange_PL310 * Cache_CleanInvalidateRange_PL310 ; TODO: Need a ranged invalidate implementation that doesn't round to page size

; --------------------------------------------------------------------------
; ----- Generic ARMv6 and ARMv7 barrier operations -------------------------
; --------------------------------------------------------------------------

; Although the ARMv6 barriers are supported on ARMv7, they are deprected, and
; they do give less control than the native ARMv7 barriers. So we prefer to use
; the ARMv7 barriers wherever possible.

DSB_ReadWrite_ARMv6 ROUT
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 4
        MOV     pc, lr

DMB_ReadWrite_ARMv6 ROUT
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c10, 5
        MOV     pc, lr

DSB_ReadWrite_ARMv7 ROUT
        DSB     SY
        MOV     pc, lr

DSB_Write_ARMv7 ROUT
        DSB     ST
        MOV     pc, lr

DMB_ReadWrite_ARMv7 ROUT
        DMB     SY
        MOV     pc, lr     

DMB_Write_ARMv7 ROUT
        DMB     ST
        MOV     pc, lr

 ] ; MEMM_Type = "VMSAv6"

        LTORG

; --------------------------------------------------------------------------

LookForHALCacheController ROUT
        Entry   "r0-r3,r8,r12"
        ; Look for any known cache controllers that the HAL has registered, and
        ; replace our ARMop routines with the appropriate routines for that
        ; controller
        LDR     r0, =(0:SHL:16)+HALDeviceType_SysPeri+HALDeviceSysPeri_CacheC
        MOV     r1, #0
        LDR     r12, =ZeroPage
        STR     r1, [r12, #Cache_HALDevice] ; In case none found
10
        MOV     r8, #OSHW_DeviceEnumerate
        SWI     XOS_Hardware
        EXIT    VS
        CMP     r1, #-1
        EXIT    EQ
        ; Do we recognise this controller?
        ASSERT  HALDevice_ID = 2
      [ NoARMv4
        LDR     lr, [r2]
        MOV     lr, lr, LSR #16
      |
        LDRH    lr, [r2, #HALDevice_ID]
      ]
        ADR     r8, KnownHALCaches
20
        LDR     r12, [r8], #8+Proc_MMU_ChangingUncachedEntries-Proc_Cache_CleanInvalidateAll
        CMP     r12, #-1
        BEQ     %BT10
        CMP     lr, r12
        BNE     %BT20
        ; Cache recognised. Disable IRQs for safety, and then try enabling it.
        Push    "r2"
        MOV     r0, r2
        MSR     CPSR_c, #SVC32_mode+I32_bit
        MOV     lr, pc
        LDR     pc, [r2, #HALDevice_Activate]
        CMP     r0, #1
        Pull    "r2"
        MSRNE   CPSR_c, #SVC32_mode
        BNE     %BT10
        ; Cache enabled OK - remember the device pointer and patch our maintenance ops
        LDR     r0, =ZeroPage
        STR     r2, [r0, #Cache_HALDevice]
        ADD     r0, r0, #Proc_Cache_CleanInvalidateAll
        MOV     r1, #Proc_MMU_ChangingUncachedEntries-Proc_Cache_CleanInvalidateAll
30
        LDR     r3, [r8, #-4]!
        TEQ     r3, #0
        STRNE   r3, [r0, r1]
        SUBS    r1, r1, #4
        BGE     %BT30
        ; It's now safe to restore IRQs
        MSR     CPSR_c, #SVC32_mode
        EXIT                        

KnownHALCaches ROUT
      [ MEMM_Type = "VMSAv6"
        DCD     HALDeviceID_CacheC_PL310
01
        DCD     Cache_CleanInvalidateAll_PL310
        DCD     Cache_CleanInvalidateRange_PL310
        DCD     Cache_CleanAll_PL310
        DCD     Cache_CleanRange_PL310
        DCD     Cache_InvalidateAll_PL310
        DCD     Cache_InvalidateRange_PL310
        DCD     Cache_RangeThreshold_PL310
        DCD     Cache_Examine_PL310
        DCD     0 ; ICache_InvalidateAll
        DCD     0 ; ICache_InvalidateRange
        DCD     0 ; TLB_InvalidateAll
        DCD     0 ; TLB_InvalidateEntry
        DCD     DSB_ReadWrite_PL310
        DCD     DSB_Write_PL310
        DCD     0 ; DSB_Read
        DCD     DMB_ReadWrite_PL310
        DCD     DMB_Write_PL310
        DCD     0 ; DMB_Read
        DCD     0 ; IMB_Full
        DCD     0 ; IMB_Range                   
        DCD     0 ; IMB_List                   
        DCD     MMU_Changing_PL310
        DCD     MMU_ChangingEntry_PL310
        DCD     0 ; MMU_ChangingUncached
        DCD     0 ; MMU_ChangingUncachedEntry
        DCD     MMU_ChangingEntries_PL310
        DCD     0 ; MMU_ChangingUncachedEntries
        ASSERT  . - %BT01 = 4+Proc_MMU_ChangingUncachedEntries-Proc_Cache_CleanInvalidateAll 
      ]
        DCD     -1

; --------------------------------------------------------------------------

        MACRO
        ARMopPtr $op
        ASSERT  . - ARMopPtrTable = ARMop_$op * 4
        DCD     ZeroPage + Proc_$op
        MEND
        
; ARMops exposed by OS_MMUControl 2
ARMopPtrTable
        ARMopPtr Cache_CleanInvalidateAll
        ARMopPtr Cache_CleanAll
        ARMopPtr Cache_InvalidateAll
        ARMopPtr Cache_RangeThreshold
        ARMopPtr TLB_InvalidateAll
        ARMopPtr TLB_InvalidateEntry
        ARMopPtr DSB_ReadWrite
        ARMopPtr IMB_Full
        ARMopPtr IMB_Range
        ARMopPtr IMB_List
        ARMopPtr MMU_Changing
        ARMopPtr MMU_ChangingEntry
        ARMopPtr MMU_ChangingUncached
        ARMopPtr MMU_ChangingUncachedEntry
        ARMopPtr MMU_ChangingEntries
        ARMopPtr MMU_ChangingUncachedEntries
        ARMopPtr DSB_Write
        ARMopPtr DSB_Read
        ARMopPtr DMB_ReadWrite
        ARMopPtr DMB_Write
        ARMopPtr DMB_Read
        ARMopPtr Cache_CleanInvalidateRange
 [ {FALSE} ; Not fully tested yet, so keep out of the public API
        ARMopPtr Cache_CleanRange
        ARMopPtr Cache_InvalidateRange
        ARMopPtr ICache_InvalidateAll
        ARMopPtr ICache_InvalidateRange
 ]
ARMopPtrTable_End
        ASSERT ARMopPtrTable_End - ARMopPtrTable = ARMop_Max*4

;        IMPORT  Write0_Translated

ARM_PrintProcessorType
        LDR     a1, =ZeroPage
        LDRB    a1, [a1, #ProcessorType]
        TEQ     a1, #ARMunk
        MOVEQ   pc, lr

        Push    "lr"
        ADR     a2, PNameTable
        LDHA    a1, a2, a1, a3
        ADD     a1, a2, a1
      [ International
        BL      Write0_Translated
      |
        SWI     XOS_Write0
      ]
        SWI     XOS_NewLine
        SWI     XOS_NewLine
        Pull    "pc"

PNameTable
        DCW     PName_ARM600    - PNameTable
        DCW     PName_ARM610    - PNameTable
        DCW     PName_ARM700    - PNameTable
        DCW     PName_ARM710    - PNameTable
        DCW     PName_ARM710a   - PNameTable
        DCW     PName_SA110     - PNameTable      ; pre rev T
        DCW     PName_SA110     - PNameTable      ; rev T or later
        DCW     PName_ARM7500   - PNameTable
        DCW     PName_ARM7500FE - PNameTable
        DCW     PName_SA1100    - PNameTable
        DCW     PName_SA1110    - PNameTable
        DCW     PName_ARM720T   - PNameTable
        DCW     PName_ARM920T   - PNameTable
        DCW     PName_ARM922T   - PNameTable
        DCW     PName_X80200    - PNameTable
        DCW     PName_X80321    - PNameTable
        DCW     PName_ARM1176JZF_S - PNameTable
        DCW     PName_Cortex_A5 - PNameTable
        DCW     PName_Cortex_A7 - PNameTable
        DCW     PName_Cortex_A8 - PNameTable
        DCW     PName_Cortex_A9 - PNameTable
        DCW     PName_Cortex_A17 - PNameTable     ; A12 rebranded as A17
        DCW     PName_Cortex_A15 - PNameTable
        DCW     PName_Cortex_A17 - PNameTable
        DCW     PName_Cortex_A53 - PNameTable
        DCW     PName_Cortex_A57 - PNameTable
        DCW     PName_Cortex_A72 - PNameTable     ; A58 rebranded as A72

PName_ARM600
        =       "600:ARM 600 Processor",0
PName_ARM610
        =       "610:ARM 610 Processor",0
PName_ARM700
        =       "700:ARM 700 Processor",0
PName_ARM710
        =       "710:ARM 710 Processor",0
PName_ARM710a
        =       "710a:ARM 710a Processor",0
PName_SA110
        =       "SA110:SA-110 Processor",0
PName_ARM7500
        =       "7500:ARM 7500 Processor",0
PName_ARM7500FE
        =       "7500FE:ARM 7500FE Processor",0
PName_SA1100
        =       "SA1100:SA-1100 Processor",0
PName_SA1110
        =       "SA1110:SA-1110 Processor",0
PName_ARM720T
        =       "720T:ARM 720T Processor",0
PName_ARM920T
        =       "920T:ARM 920T Processor",0
PName_ARM922T
        =       "922T:ARM 922T Processor",0
PName_X80200
        =       "X80200:80200 Processor",0
PName_X80321
        =       "X80321:80321 Processor",0
PName_ARM1176JZF_S
        =       "ARM1176JZF_S:ARM1176JZF-S Processor",0
PName_Cortex_A5
        =       "CA5:Cortex-A5 Processor",0
PName_Cortex_A7
        =       "CA7:Cortex-A7 Processor",0
PName_Cortex_A8
        =       "CA8:Cortex-A8 Processor",0
PName_Cortex_A9
        =       "CA9:Cortex-A9 Processor",0
PName_Cortex_A15
        =       "CA15:Cortex-A15 Processor",0
PName_Cortex_A17
        =       "CA17:Cortex-A17 Processor",0
PName_Cortex_A53
        =       "CA53:Cortex-A53 Processor",0
PName_Cortex_A57
        =       "CA57:Cortex-A57 Processor",0
PName_Cortex_A72
        =       "CA72:Cortex-A72 Processor",0
        ALIGN


; Lookup tables from DA flags PCB (bits 14:12,5,4, packed down to 4:2,1,0)
; to XCB bits in page table descriptors.

XCB_CB  *       0:SHL:0
XCB_NB  *       1:SHL:0
XCB_NC  *       1:SHL:1
XCB_P   *       1:SHL:2
 [ MEMM_Type = "VMSAv6"
XCB_TU  *       1:SHL:5 ; For VMSAv6, deal with temp uncacheable via the table
 ]

        ALIGN 32

 [ MEMM_Type = "ARM600"

; WT read-allocate cache (eg ARM720T)
XCBTableWT                                      ; C+B        CNB   NCB         NCNB
        = L2_C+L2_B, L2_C, L2_B, 0              ;        Default
        = L2_C+L2_B, L2_C, L2_B, 0              ; WT,         WT, Non-merging, X
        = L2_C+L2_B, L2_C, L2_B, 0              ; WB/RA,      WB, Merging,     X
        = L2_C+L2_B, L2_C, L2_B, 0              ; WB/WA,      X,  Idempotent,  X
        = L2_C+L2_B, L2_C, L2_B, 0              ; Alt DCache, X,  X,           X
        = L2_C+L2_B, L2_C, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B, L2_C, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B, L2_C, L2_B, 0              ; X,          X,  X,           X

; SA-110 in Risc PC - WB only read-allocate cache, non-merging WB
XCBTableSA110                                   ; C+B        CNB   NCB         NCNB
        = L2_C+L2_B,    0, L2_B, 0              ;        Default
        =      L2_B,    0, L2_B, 0              ; WT,         WT, Non-merging, X
        = L2_C+L2_B,    0, L2_B, 0              ; WB/RA,      WB, Merging,     X
        = L2_C+L2_B,    0, L2_B, 0              ; WB/WA,      X,  Idempotent,  X
        = L2_C+L2_B,    0, L2_B, 0              ; Alt DCache, X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X

; ARMv5 WB/WT read-allocate cache, non-merging WB (eg ARM920T)
XCBTableWBR                                     ; C+B        CNB   NCB         NCNB
        = L2_C+L2_B,    0, L2_B, 0              ;        Default
        = L2_C     ,    0, L2_B, 0              ; WT,         WT, Non-merging, X
        = L2_C+L2_B,    0, L2_B, 0              ; WB/RA,      WB, Merging,     X
        = L2_C+L2_B,    0, L2_B, 0              ; WB/WA,      X,  Idempotent,  X
        = L2_C+L2_B,    0, L2_B, 0              ; Alt DCache, X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X

; SA-1110 - WB only read allocate cache, merging WB, mini D-cache
XCBTableSA1110                                  ; C+B        CNB   NCB         NCNB
        = L2_C+L2_B,    0, L2_B, 0              ;        Default
        =      L2_B,    0,    0, 0              ; WT,         WT, Non-merging, X
        = L2_C+L2_B,    0, L2_B, 0              ; WB/RA,      WB, Merging,     X
        = L2_C+L2_B,    0, L2_B, 0              ; WB/WA,      X,  Idempotent,  X
        = L2_C     ,    0, L2_B, 0              ; Alt DCache, X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X

; XScale - WB/WT read or write-allocate cache, merging WB, mini D-cache
;          defaulting to read-allocate
XCBTableXScaleRA                                ; C+B        CNB   NCB         NCNB
        =      L2_C+L2_B,    0,      L2_B, 0    ;        Default
        =      L2_C     ,    0, L2_X+L2_B, 0    ; WT,         WT, Non-merging, X
        =      L2_C+L2_B,    0,      L2_B, 0    ; WB/RA,      WB, Merging,     X
        = L2_X+L2_C+L2_B,    0,      L2_B, 0    ; WB/WA,      X,  Idempotent,  X
        = L2_X+L2_C     ,    0,      L2_B, 0    ; Alt DCache, X,  X,           X
        =      L2_C+L2_B,    0,      L2_B, 0    ; X,          X,  X,           X
        =      L2_C+L2_B,    0,      L2_B, 0    ; X,          X,  X,           X
        =      L2_C+L2_B,    0,      L2_B, 0    ; X,          X,  X,           X

; XScale - WB/WT read or write-allocate cache, merging WB, mini D-cache
;          defaulting to write-allocate
XCBTableXScaleWA                                ; C+B        CNB   NCB         NCNB
        = L2_X+L2_C+L2_B,    0,      L2_B, 0    ;        Default
        =      L2_C     ,    0, L2_X+L2_B, 0    ; WT,         WT, Non-merging, X
        =      L2_C+L2_B,    0,      L2_B, 0    ; WB/RA,      WB, Merging,     X
        = L2_X+L2_C+L2_B,    0,      L2_B, 0    ; WB/WA,      X,  Idempotent,  X
        = L2_X+L2_C     ,    0,      L2_B, 0    ; Alt DCache, X,  X,           X
        = L2_X+L2_C+L2_B,    0,      L2_B, 0    ; X,          X,  X,           X
        = L2_X+L2_C+L2_B,    0,      L2_B, 0    ; X,          X,  X,           X
        = L2_X+L2_C+L2_B,    0,      L2_B, 0    ; X,          X,  X,           X

; XScale - WB/WT read-allocate cache, merging WB, no mini D-cache/extended pages
XCBTableXScaleNoExt                             ; C+B        CNB   NCB         NCNB
        = L2_C+L2_B,    0, L2_B, 0              ;        Default
        = L2_C     ,    0,    0, 0              ; WT,         WT, Non-merging, X
        = L2_C+L2_B,    0, L2_B, 0              ; WB/RA,      WB, Merging,     X
        = L2_C+L2_B,    0, L2_B, 0              ; WB/WA,      X,  Idempotent,  X
        = L2_C+L2_B,    0, L2_B, 0              ; Alt DCache, X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X
        = L2_C+L2_B,    0, L2_B, 0              ; X,          X,  X,           X

 ] ; MEMM_Type = "ARM600"

 [ MEMM_Type = "VMSAv6"

; VMSAv6/v7 L2 memory attributes (short descriptor format, TEX remap disabled)

L2_SO_S     * 0                             ; Strongly-ordered, shareable
L2_Dev_S    * L2_B                          ; Device, shareable
L2_Dev_nS   * 2:SHL:L2_TEXShift             ; Device, non-shareable

; For Normal memory types, use the form that is explicit about inner and outer
; cacheability. This provides a nice mapping to the way cacheability is
; specified in the TTBR (see SetTTBR)
VMSAv6_Cache_NC * 0
VMSAv6_Cache_WBWA * 1
VMSAv6_Cache_WT * 2
VMSAv6_Cache_WBRA * 3
        ASSERT L2_C = L2_B:SHL:1
        MACRO
        VMSAv6_Nrm_XCB $inner, $outer
L2_Nrm_$inner._$outer * ((4+VMSAv6_Cache_$outer):SHL:L2_TEXShift) + (VMSAv6_Cache_$inner * L2_B)
      [ "$outer" == "$inner"
L2_Nrm_$inner * L2_Nrm_$inner._$outer
      ]
        MEND

        VMSAv6_Nrm_XCB WT, WT               ; Normal, WT/RA, S bit determines shareability
        VMSAv6_Nrm_XCB WBRA, WBRA           ; Normal, WB/RA, S bit determines shareability
        VMSAv6_Nrm_XCB NC, NC               ; Normal, non-cacheable (but bufferable), S bit determines shareability
        VMSAv6_Nrm_XCB WBWA, WBWA           ; Normal, WB/WA, S bit determines shareability
        VMSAv6_Nrm_XCB WT, WBWA             ; Normal, inner WT, outer WB/WA, S bit determines shareability

; Generic XCB table for VMSAv6/v7

; * NCNB is roughly equivalent to "strongly ordered".
; * NCB with non-merging write buffer is equivalent to "Device".
; * NCB with merging write buffer is also mapped to "Device". "Normal" is
;   tempting but may result in issues with read-sensitive devices (see below).
; * For NCB with devices which aren't read-sensitive, we introduce a new
;   "Merging write buffer with idempotent memory" policy which maps to the
;   Normal, non-cacheable type. This will degrade nicely on older OS's and CPUs,
;   avoiding some isses if we were to make NCB with merging write buffer default
;   to Normal memory. This policy is also the new default, so that all existing
;   NCB RAM uses it (so unaligned loads, etc. will work). No existing code seems
;   to be using NCB for IO devices (only for IO RAM like VRAM), so this change
;   should be safe (previously, all NCB policies would have mapped to Device
;   memory)
; * CNB has no equivalent - there's no control over whether the write buffer is
;   used for cacheable regions, so we have to downgrade to NCNB.

; The caches should behave sensibly when given unsupported attributes
; (downgrade WB to WT to NC), but we may end up doing more cache maintenance
; than needed if the hardware downgrades some areas to NC.

XCBTableVMSAv6                                       ; C+B        CNB   NCB         NCNB
        DCW L2_Nrm_WBWA, L2_SO_S, L2_Nrm_NC, L2_SO_S ;        Default
        DCW L2_Nrm_WT,   L2_SO_S, L2_Dev_S,  L2_SO_S ; WT,         WT, Non-merging, X     
        DCW L2_Nrm_WBRA, L2_SO_S, L2_Dev_S,  L2_SO_S ; WB/RA,      WB, Merging,     X
        DCW L2_Nrm_WBWA, L2_SO_S, L2_Nrm_NC, L2_SO_S ; WB/WA,      X,  Idempotent,  X
        DCW L2_Nrm_WT_WBWA,L2_SO_S,L2_Nrm_NC,L2_SO_S ; Alt DCache, X,  X,           X
        DCW L2_Nrm_WBWA, L2_SO_S, L2_Nrm_NC, L2_SO_S ; X,          X,  X,           X     
        DCW L2_Nrm_WBWA, L2_SO_S, L2_Nrm_NC, L2_SO_S ; X,          X,  X,           X     
        DCW L2_Nrm_WBWA, L2_SO_S, L2_Nrm_NC, L2_SO_S ; X,          X,  X,           X
        ; This second set of entries deals with when pages are made
        ; temporarily uncacheable - we need to change the cacheability without
        ; changing the memory type.
        DCW L2_Nrm_NC,   L2_SO_S, L2_Nrm_NC, L2_SO_S ;        Default
        DCW L2_Nrm_NC,   L2_SO_S, L2_Dev_S,  L2_SO_S ; WT,         WT, Non-merging, X     
        DCW L2_Nrm_NC,   L2_SO_S, L2_Dev_S,  L2_SO_S ; WB/RA,      WB, Merging,     X
        DCW L2_Nrm_NC,   L2_SO_S, L2_Nrm_NC, L2_SO_S ; WB/WA,      X,  Idempotent,  X     
        DCW L2_Nrm_NC,   L2_SO_S, L2_Nrm_NC, L2_SO_S ; Alt DCache, X,  X,           X     
        DCW L2_Nrm_NC,   L2_SO_S, L2_Nrm_NC, L2_SO_S ; X,          X,  X,           X     
        DCW L2_Nrm_NC,   L2_SO_S, L2_Nrm_NC, L2_SO_S ; X,          X,  X,           X     
        DCW L2_Nrm_NC,   L2_SO_S, L2_Nrm_NC, L2_SO_S ; X,          X,  X,           X

 ] ; MEMM_Type = "VMSAv6"

        END
