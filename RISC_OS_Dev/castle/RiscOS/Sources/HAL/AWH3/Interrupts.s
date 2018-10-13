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

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>

        GET     Hdr:OSEntries

        ;GET     hdr.omap543x
        GET     hdr.AllWinnerH3
        GET     hdr.StaticWS
        GET     hdr.Interrupts

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  Interrupt_Init
        EXPORT  HAL_IRQEnable
        EXPORT  HAL_IRQDisable
        EXPORT  HAL_IRQClear
        EXPORT  HAL_IRQSource
        EXPORT  HAL_IRQStatus
        EXPORT  HAL_FIQEnable
        EXPORT  HAL_FIQDisable
        EXPORT  HAL_FIQDisableAll
        EXPORT  HAL_FIQClear
        EXPORT  HAL_FIQSource
        EXPORT  HAL_FIQStatus
        EXPORT  HAL_IRQMax
 [ Debug
    IMPORT  HAL_DebugTX
    IMPORT  HAL_DebugRX
    IMPORT  DebugHALPrint
    IMPORT  DebugHALPrintReg
    IMPORT  DebugMemDump
    IMPORT  DebugHALPrintByte
    IMPORT  DebugCallstack
    
 ]

; Debug flag to cause the DebugInterrupts noncleared IRQ detection code to disable the source
; of the noncleared interrupt. This can be useful in debugging issues that cause the
; nonclearance of the IRQ, e.g. if an IRQ handler aborts before it's able to call IRQClear.
                        GBLL    DebugDisablePrevious
DebugDisablePrevious    SETL    {TRUE}

Interrupt_Init
        ; 1. disable Distributor Controller
        LDR     a1, MPU_INTC_Log
        ADD     a1, a1, #GICD_BASE
        MOV     a2, #0          ; disable ICDDCR
        STR     a2, [a1, #GICD_CTLR]

        ; 2. set all global interrupts to be level triggered, active low
        ADD     a3, a1, #GICD_ICFGR
        ADD     a3, a3, #8
        MOV     a4, #INTERRUPT_MAX
        MOV     ip, #32
10
        STR     a2, [a3], #4
        ADD     ip, ip, #16
        CMP     ip, a4
        BNE     %BT10

        ; 3. set all global interrupts to this CPU only
        ADD     a3, a1, #(GICD_ITARGETSR + 32)
        MOV     ip, #32
        MOV     a2, #1
        ORR     a2, a2, a2, LSL #8
        ORR     a2, a2, a2, LSL #16
20
        STR     a2, [a3], #4
        ADD     ip, ip, #4
        CMP     ip, a4
        BNE     %BT20

        ; 4. set priority on all interrupts
        ADD     a3, a1, #(GICD_IPRIORITYR + 32)
        MOV     ip, #32
        MOV     a2, #&A0
        ORR     a2, a2, a2, LSL #8
        ORR     a2, a2, a2, LSL #16
30
        STR     a2, [a3], #4
        ADD     ip, ip, #4
        CMP     ip, a4
        BNE     %BT30

        ; 5. disable all interrupts
        ADD     a3, a1, #GICD_ICENABLER
        MOV     ip, #32
        MOV     a2, #-1
40
        STR     a2, [a3], #4
        ADD     ip, ip, #32
        CMP     ip, a4
        BNE     %BT40

        ; 6. enable Distributor Controller
        MOV     a2, #ICDDCR_ENABLE_GRP0
        STR     a2, [a1, #GICD_CTLR]

        ; 7. set PRIMASK in CPU interface
        LDR     a1, MPU_INTC_Log
        ADD     a1, a1, #GICC_BASE
        MOV     a2, #&F0
        STR     a2, [a1, #GICC_PMR]

        ; 8. enable CPU interface
        MOV     a2, #ICCICR_ENABLE_GRP1
        STR     a2, [a1, #GICC_CTLR]
        ; ... and everything else looks good?
  [ DebugInterrupts
        MOV     a1, #-1
        STR     a1, LastInterrupt_IRQ
        STR     a1, LastInterrupt_FIQ
   [ ExtraDebugInterrupts
        MOV     a1, #0
        STR     a1, ExtraDebugIRQEnabled
   ]
  ]
        MOV     pc, lr

HAL_IRQEnable
        CMP     a1, #INTERRUPT_MAX
        MOVHS   a1, #0
        MOVHS   pc, lr
        ; Disable interrupts while we update the controller
        MRS     a4, CPSR
        ORR     a3, a4, #F32_bit+I32_bit
        MSR     CPSR_c, a3
        ; Unmask the interrupt
        LDR     a3, MPU_INTC_Log
        ADD     ip, a3, #(GICD_BASE + GICD_ISENABLER)
        AND     a2, a1, #31     ; bit   = intno % 32
        MOV     a1, a1, LSR #5  ; index = intno / 32
        ADD     ip, ip, a1, LSL #2
        MOV     a1, #1
        MOV     a2, a1, LSL a2  ; mask = (1 << bit)
        LDR     a1, [ip, #0]    ; get old state
        STR     a2, [ip, #0]    ; set new state
        MSR     CPSR_c, a4      ; Re-enable interrupts
        AND     a1, a1, a2      ; Test if it was enabled or not
        MOV     pc, lr

HAL_IRQDisable
        CMP     a1, #INTERRUPT_MAX
        MOVHS   a1, #0
        MOVHS   pc, lr
        Push    "lr"
        ; Disable interrupts while we update the controller
        ; (not necessarily needed for disabling them?)
        MRS     a4, CPSR
        ORR     a3, a4, #F32_bit+I32_bit
        MSR     CPSR_c, a3
        ; Now mask the interrupt
        LDR     a3, MPU_INTC_Log
        ADD     ip, a3, #(GICD_BASE + GICD_ICENABLER)
        AND     a2, a1, #31     ; bit   = intno % 32
        MOV     lr, a1, LSR #5  ; index = intno / 32
        ADD     ip, ip, lr, LSL #2
        MOV     lr, #1
        MOV     a2, lr, LSL a2  ; mask = (1 << bit)
        LDR     lr, [ip, #0]    ; get old state
        STR     a2, [ip, #0]    ; mask the interrupt
  [ {FALSE} ; reading GICC_IAR has side effects on the interrupt system !?
        ; Check if we just disabled the active interrupt
        ADD     a3, a3, #GICC_BASE
        LDR     ip, [a3, #GICC_IAR]
        CMP     ip, a1
        STREQ   ip, [a3, #GICC_EOIR]
    [ DebugInterrupts
        MOVEQ   ip, #-1
        STREQ   ip, LastInterrupt_IRQ
    ]
  |
        ; Clear any pending state of this source
        STR     a2, [ip, #(GICD_ICPENDR - GICD_ICENABLER)]
        Push    "lr"
        ; Was it active?
        LDR     lr, [ip, #(GICD_ISACTIVER - GICD_ICENABLER)]
        TST     lr, a2
        Pull    "lr"
        ; Reset active state of this interrupt
        STR     a2, [ip, #(GICD_ICACTIVER - GICD_ICENABLER)]
        ADDNE   a3, a3, #GICC_BASE
        STRNE   a1, [a3, #GICC_EOIR]
    [ DebugInterrupts
        MOVNE   ip, #-1
        STRNE   ip, LastInterrupt_IRQ
    ]
  ]
        MSR     CPSR_c, a4      ; Re-enable interrupts
        AND     a1, lr, a2      ; Test if it was enabled or not
        Pull    "pc"

HAL_IRQClear
  [ ExtraDebugInterrupts
        LDR     a2, ExtraDebugIRQEnabled
        CMP     a2, #0
        BEQ     %FT10
        Push    "lr"
        DebugReg a1, "HAL_IRQClear: "
        Pull    "lr"
10
  ]
        ; Signal End Of Interrupt
        LDR     a2, MPU_INTC_Log
        ADD     a2, a2, #GICC_BASE
        STR     a1, [a2, #GICC_EOIR]
        ; Data synchronisation barrier to make sure INTC gets the message
        DSB     SY
  [ DebugInterrupts
        MOV     a1, #-1
        STR     a1, LastInterrupt_IRQ
  ]
        MOV     pc, lr

HAL_IRQSource
  [ DebugInterrupts
        LDR     a1, LastInterrupt_IRQ
        CMP     a1, #0
        BLT     %FT10
        Push    "lr"
        BL      DebugHALPrint
        =       "HAL_IRQSource: Previous IRQ not cleared: ", 0
        DebugReg a1
   [ DebugDisablePrevious
        BL      HAL_IRQDisable
   ]
   [ ExtraDebugInterrupts
    [ :LNOT: DebugDisablePrevious ; Doesn't play nice with this since it'll just spam the HAL_IRQClear messages
        STR     pc, ExtraDebugIRQEnabled ; any nonzero value will do
    ]
        MOV     lr, pc ; BL to the main routine so we can get the exit code
        B       %FT05
        DebugReg a1, "HAL_IRQSource: New IRQ: "
        Pull    "pc"
05
   |
        Pull    "lr"
   ]
10
  ]
        ; Does the ARM think an interrupt is occuring?
        MRC     p15, 0, a1, c12, c1, 0
        TST     a1, #I32_bit
        MOVEQ   a1, #-1
  [ DebugInterrupts
        STREQ   a1, LastInterrupt_IRQ
  ]
        MOVEQ   pc, lr
        LDR     a2, MPU_INTC_Log
        ADD     a2, a2, #GICC_BASE
        LDR     a3, [a2, #GICC_IAR]
        BIC     a1, a3, #ICCIAR_CPUID
        CMP     a1, #INTERRUPT_MAX
  [ DebugInterrupts
        STRLO   a1, LastInterrupt_IRQ
  ]
        MOVLO   pc, lr
        ; Authentic spurious interrupt - restart INTC and return -1
        STR     a3, [a2, #GICC_EOIR]
        ; Data synchronisation barrier to make sure INTC gets the message
        DSB     SY
        MOV     a1, #-1
  [ DebugInterrupts
        STR     a1, LastInterrupt_IRQ
  ]
        MOV     pc, lr

HAL_IRQStatus
        ; Test if IRQ is firing, irrespective of mask state
        CMP     a1, #INTERRUPT_MAX
        MOVHS   a1, #0
        MOVHS   pc, lr

        LDR     a2, MPU_INTC_Log
        ADD     ip, a2, #(GICD_BASE + GICD_ISACTIVER)
        MOV     a3, a1, LSR #5  ; index = intno / 32
        ADD     ip, ip, a3, LSL #2
        LDR     a3, [ip, #0]    ; get old state
        AND     a1, a1, #31     ; bit   = intno % 32
        MOV     a1, a3, LSR a1  ; Shift and invert so 1=active
        AND     a1, a1, #1      ; 0 = not firing, 1 = firing
        MOV     pc, lr


;
; ToDo: do we have FIQs in Non-Secure environment GIC ???
;    FIQ_Supported part contains register names from OMAP3 implementation;
;    this needs updating for GICv2 naming conventions!
;
                GBLL    FIQ_Supported
FIQ_Supported   SETL    {FALSE}

HAL_FIQEnable
  [ FIQ_Supported
        CMP     a1, #INTERRUPT_MAX
        MOVHS   a1, #0
        MOVHS   pc, lr
        ; Disable interrupts while we update the controller
        MRS     a4, CPSR
        ORR     a3, a4, #F32_bit+I32_bit
        MSR     CPSR_c, a3
        ; Set the interrupt type & priority, and then unmask it
        MOV     a2, #1 ; highest priority for all FIQs.
        LDR     a3, MPU_INTC_Log
        ADD     ip, a3, #INTCPS_ILR
        ASSERT  INTCPS_ILR_SIZE = 4
        STR     a2, [ip, a1, LSL #2]
        AND     a2, a1, #&1F ; Mask bit
        MOV     a1, a1, LSR #5 ; BITS index
        ASSERT  INTCPS_BITS_SIZE = 32
        ADD     ip, a3, a1, LSL #5
        MOV     a1, #1
        MOV     a2, a1, LSL a2
        LDR     a1, [ip, #INTCPS_BITS+INTCPS_BITS_MIR] ; Get old state
        STR     a2, [ip, #INTCPS_BITS+INTCPS_BITS_MIR_CLEAR] ; Write to clear reg to set new state
        MSR     CPSR_c, a4 ; Re-enable interrupts
        MVN     a1, a1 ; Invert so we get a mask of enabled interrupts
        AND     a1, a1, a2 ; Test if it was enabled or not
        MOV     pc, lr
  |
        MOV     a1, #0
        MOV     pc, lr
  ] ; FIQ_Supported

HAL_FIQDisable
  [ FIQ_Supported
        CMP     a1, #INTERRUPT_MAX
        MOVHS   a1, #0
        MOVHS   pc, lr
        Push    "lr"
        ; Disable interrupts while we update the controller (not necessarily needed for disabling them?)
        MRS     a4, CPSR
        ORR     a3, a4, #F32_bit+I32_bit
        MSR     CPSR_c, a3
        ; Check if this is actually an FIQ
        LDR     a3, MPU_INTC_Log
        ASSERT  INTCPS_ILR_SIZE = 4
        ADD     a2, a3, a1, LSL #2
        LDR     a2, [a2, #INTCPS_ILR]
        TST     a2, #1
        MOVEQ   a1, #0 ; This is an IRQ, so don't disable it
        MSREQ   CPSR_c, a4
        Pull    "pc", EQ
        ; Now mask the interrupt
        AND     a2, a1, #&1F ; Mask bit
        MOV     lr, a1, LSR #5 ; BITS index
        ASSERT  INTCPS_BITS_SIZE = 32
        ADD     ip, a3, lr, LSL #5
        MOV     lr, #1
        MOV     a2, lr, LSL a2
        LDR     lr, [ip, #INTCPS_BITS+INTCPS_BITS_MIR] ; Get old state
        STR     a2, [ip, #INTCPS_BITS+INTCPS_BITS_MIR_SET] ; Mask the interrupt
        ; Check if we just disabled the active interrupt
        LDR     ip, [a3, #INTCPS_SIR_FIQ]
        CMP     ip, a1
        MOVEQ   ip, #2
        STREQ   ip, [a3, #INTCPS_CONTROL]
    [ DebugInterrupts
        MOVEQ   ip, #-1
        STREQ   ip, LastInterrupt_FIQ
    ]
        MSR     CPSR_c, a4 ; Re-enable interrupts
        BIC     a1, a2, lr ; Clear the masked interrupts from a2 to get nonzero result if it was enabled
        Pull    "pc"
  |
        MOV     a1, #0
        MOV     pc, lr
  ] ; FIQ_Supported

HAL_FIQDisableAll
  [ FIQ_Supported
        ; This isn't particularly great, we need to scan the entire ILR array
        ; and work out which are FIQs, and then write to the ISR_SET registers
        ; We should probably keep our own array of enabled FIQs so this can be
        ; done more quickly
        MRS     a4, CPSR
        ORR     a3, a4, #F32_bit+I32_bit
        MSR     CPSR_c, a3
        LDR     a1, MPU_INTC_Log
        ADD     a1, a1, #INTCPS_ILR
        MOV     a2, #1 ; Mask to write
        ADD     a3, a1, #INTCPS_BITS+INTCPS_BITS_MIR_SET-INTCPS_ILR
HAL_FIQDisableAll_Loop1
        LDR     ip, [a1],#INTCPS_ILR_SIZE
        TST     ip, #1 ; 1=FIQ, 0=IRQ
        STRNE   a2, [a3] ; Disable it
        MOVS    a2, a2, LSL #1
        BCC     HAL_FIQDisableAll_Loop1
        ; Move on to next word
        MOV     a2, #1
        ADD     a3, a3, #INTCPS_BITS_SIZE
HAL_FIQDisableAll_Loop2
        LDR     ip, [a1],#INTCPS_ILR_SIZE
        TST     ip, #1 ; 1=FIQ, 0=IRQ
        STRNE   a2, [a3] ; Disable it
        MOVS    a2, a2, LSL #1
        BCC     HAL_FIQDisableAll_Loop2
        ; Move on to last word
        MOV     a2, #1
        ADD     a3, a3, #INTCPS_BITS_SIZE
HAL_FIQDisableAll_Loop3
        LDR     ip, [a1],#INTCPS_ILR_SIZE
        TST     ip, #1 ; 1=FIQ, 0=IRQ
        STRNE   a2, [a3] ; Disable it
        MOVS    a2, a2, LSL #1
        BCC     HAL_FIQDisableAll_Loop3
        ; Done
        ASSERT  INTCPS_BITS_COUNT = 3
        MSR     CPSR_c, a4
        ; FIQDisableAll is only called during emergency situations, so restart INTC priority
        ; sorting to avoid having to rewrite various bits of RISC OS code to query FIQ sources
        ; and call FIQClear on each one (which would otherwise be the only legal way of
        ; stopping all FIQs from firing)
        LDR     a2, MPU_INTC_Log
        MOV     a1, #2
        STR     a1, [a2, #INTCPS_CONTROL]
        ; Data synchronisation barrier to make sure INTC gets the message
        DSB     SY
    [ DebugInterrupts
        MOV     a1, #-1
        STR     a1, LastInterrupt_FIQ
    ]
  ] ; FIQ_Supported
        MOV     pc, lr

HAL_FIQClear
  [ FIQ_Supported
        ; Restart INTC priority sorting
        LDR     a2, MPU_INTC_Log
        MOV     a1, #2
        STR     a1, [a2, #INTCPS_CONTROL]
        ; Data synchronisation barrier to make sure INTC gets the message
        DSB     SY
     [ DebugInterrupts
        MOV     a1, #-1
        STR     a1, LastInterrupt_FIQ
     ]
  ] ; FIQ_Supported
        MOV     pc, lr

HAL_FIQStatus
  [ FIQ_Supported
        ; Test if FIQ is firing, irrespective of mask state
        CMP     a1, #INTERRUPT_MAX
        MOVHS   a1, #0
        MOVHS   pc, lr
        ; First we need to make sure this is an FIQ, not an IRQ?
        MRS     a4, CPSR
        ORR     a3, a4, #F32_bit+I32_bit
        MSR     CPSR_c, a3
        LDR     a2, MPU_INTC_Log
        ASSERT  INTCPS_ILR_SIZE = 4
        ADD     a3, a2, a1, LSL #2
        LDR     a3, [a3, #INTCPS_ILR]
        TST     a3, #1
        MOVEQ   a1, #0 ; This is an IRQ, so it can't fire for FIQ
        MSREQ   CPSR_c, a4
        MOVEQ   pc, lr
        ; Now check if it's firing
        ASSERT  INTCPS_BITS_SIZE = 32
        MOV     a3, a1, LSR #5
        ADD     a3, a2, a3, LSL #5
        LDR     a3, [a3, #INTCPS_BITS+INTCPS_BITS_ITR]
        MSR     CPSR_c, a4
        AND     a1, a1, #31
        MOV     a1, a3, LSR a1 ; Shift and invert so 1=active
        AND     a1, a1, #1 ; 0 = not firing, 1 = firing
        MOV     pc, lr
  |
        MOV     a1, #0
        MOV     pc, lr
  ] ; FIQ_Supported

HAL_FIQSource
  [ FIQ_Supported
    [ DebugInterrupts
        LDR     a1, LastInterrupt_FIQ
        CMP     a1, #0
        BLT     %FT10
        Push    "lr"
        BL      DebugHALPrint
        =       "HAL_FIQSource: Previous FIQ not cleared: ", 0
        DebugReg a1
        Pull    "lr"
10
    ]
        ; Does the ARM think an interrupt is occuring?
        MRC     p15, 0, a1, c12, c1, 0
        TST     a1, #F32_bit
        MOVEQ   a1, #-1
    [ DebugInterrupts
        STREQ   a1, LastInterrupt_FIQ
    ]
        MOVEQ   pc, lr
        LDR     a2, MPU_INTC_Log
        LDR     a1, [a2, #INTCPS_SIR_FIQ]
        CMP     a1, #INTERRUPT_MAX
        ANDLO   a1, a1, #&7F
    [ DebugInterrupts
        STRLO   a1, LastInterrupt_FIQ
    ]
        MOVLO   pc, lr
        ; Authentic spurious interrupt - restart INTC and return -1
        MOV     a1, #-1
    [ DebugInterrupts
        STR     a1, LastInterrupt_FIQ
    ]
        MOV     a3, #2
        STR     a3, [a2, #INTCPS_CONTROL]
        ; Data synchronisation barrier to make sure INTC gets the message
        DSB     SY
        MOV     pc, lr
  |
        MOV     a1, #0
        MOV     pc, lr
  ] ; FIQ_Supported

HAL_IRQMax
        MOV     a1, #INTERRUPT_MAX
        MOV     pc, lr

        END
