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

        GET     hdr.iMx6q
        GET     hdr.StaticWS
        GET     hdr.Timers
        GET     hdr.CoPro15ops

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

 [ DebugInterrupts
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]

; Debug flag to cause the DebugInterrupts noncleared IRQ detection code to disable the source
; of the noncleared interrupt. This can be useful in debugging issues that cause the
; nonclearance of the IRQ, e.g. if an IRQ handler aborts before it's able to call IRQClear.
                        GBLL    DebugDisablePrevious
DebugDisablePrevious    SETL    {FALSE}

Interrupt_Init
; mov a4,lr
; DebugReg a1,"HIRQ init "
; mov lr,a4
        ; 1. disable Distributor Controller
        LDR     a1, IRQDi_Log
        MOV     a2, #0          ; disable ICDDCR
        STR     a2, [a1, #(ICDDCR - IC_DISTRIBUTOR_BASE_ADDR)]

        ; 2. set all global interrupts to be level triggered, active low
        ADD     a3, a1, #ICDICFR -IC_DISTRIBUTOR_BASE_ADDR
        ADD     a3, a3, #8
        MOV     a4, #IMX_INTERRUPT_COUNT
        MOV     ip, #32
10
        STR     a2, [a3], #4
        ADD     ip, ip, #16
        CMP     ip, a4
        BNE     %BT10

        ; 3. set all global interrupts to this CPU only
        ADD     a3, a1, #(ICDIPTR + 32  -IC_DISTRIBUTOR_BASE_ADDR)
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
        ADD     a3, a1, #(ICDIPR + 32 -IC_DISTRIBUTOR_BASE_ADDR)
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
        ADD     a3, a1, #ICDICER  -IC_DISTRIBUTOR_BASE_ADDR
        MOV     ip, #32
        MOV     a2, #-1
40
        STR     a2, [a3], #4
        ADD     ip, ip, #32
        CMP     ip, a4
        BNE     %BT40

        ; 6. enable Distributor Controller
        MOV     a2, #ICDDCR_ENABLE
        STR     a2, [a1, #(ICDDCR-IC_DISTRIBUTOR_BASE_ADDR)]

        ; 7. set PRIMASK in CPU interface
        LDR     a1, IRQC_Log
        MOV     a2, #&F0
        STR     a2, [a1, #(ICCPMR-IC_INTERFACES_BASE_ADDR)]

        ; 8. enable CPU interface
        MOV     a2, #ICCICR_ENABLE
        STR     a2, [a1, #(ICCICR - IC_INTERFACES_BASE_ADDR)]
        ; ... and everything else looks good?
 [ DebugInterrupts
        MOV     a1, #-1
        STR     a1, LastInterrupt_IRQ
        STR     a1, LastInterrupt_FIQ
  [ ExtraDebugInterrupts
        MOV     a1, #0
        STR     a1, ExtraDebugIRQEnabled
        str     a2, tickertimer
  ]
 ]
        MOV     pc, lr

HAL_IRQEnable
; teq   a1, #IMX_INT_UART1;Timer0_IRQ;IMX_INT_USBOH3_UH1   ; all but timer..
; teqne a1, #IMX_INT_UART2;IMX_INT_SDMA
; teqne a1, #IMX_INT_UART3;IMX_INT_IPU1_FUNC
;; teqne a1, #IMX_INT_I2C2
;; teqne a1, #IMX_INT_SATA
; bne %ft001
; mov a4,lr
; DebugReg a1,"HIRQ EN no:"
; mov lr,a4
;001
        CMP     a1, #IMX_INTERRUPT_COUNT
        MOVHS   a1, #0
        MOVHS   pc, lr
        ; Disable interrupts while we update the controller
        MRS     a4, CPSR
        ORR     a3, a4, #F32_bit+I32_bit
        MSR     CPSR_c, a3
        ; Unmask the interrupt
        LDR     a3, IRQDi_Log
        ADD     ip, a3, #(ICDISER - IC_DISTRIBUTOR_BASE_ADDR)
        AND     a2, a1, #31     ; bit   = intno % 32
        MOV     a1, a1, LSR #5  ; index = intno / 32
        ADD     ip, ip, a1, LSL #2
        MOV     a1, #1
        MOV     a2, a1, LSL a2  ; mask = (1 << bit)
        LDR     a1, [ip, #0]    ; get old state
        STR     a2, [ip, #0]    ; set new state
; mov a4,lr
; DebugReg a1,"HIRQ old reg value:"
;  LDR     a1, [ip, #0]    ; get old state
; DebugReg a1,"HIRQ now reg value:"
; mov lr,a4
        MSR     CPSR_c, a4      ; Re-enable interrupts
        AND     a1, a1, a2      ; Test if it was enabled or not
        MOV     pc, lr

HAL_IRQDisable
; teq   a1, #IMX_INT_UART1;Timer0_IRQ;IMX_INT_USBOH3_UH1   ; all but timer..
; teqne a1, #IMX_INT_UART2;IMX_INT_SDMA
; teqne a1, #IMX_INT_UART3;IMX_INT_IPU1_FUNC
;; teqne a1, #IMX_INT_I2C2
;; teqne a1, #IMX_INT_SATA
; bne %ft001
; mov a4,lr
; DebugReg a1,"HIRQ Dis no:"
; mov lr,a4
;001
        CMP     a1, #IMX_INTERRUPT_COUNT
        MOVHS   a1, #0
        MOVHS   pc, lr
        Push    "lr"
        ; Disable interrupts while we update the controller
        ; (not necessarily needed for disabling them?)
        MRS     a4, CPSR
        ORR     a3, a4, #F32_bit+I32_bit
        MSR     CPSR_c, a3
        ; Check if this is actually an IRQ
        LDR     a3, IRQDi_Log
;       ASSERT  INTCPS_ILR_SIZE = 4
;       ADD     a2, a3, a1, LSL #2
;       LDR     a2, [a2, #INTCPS_ILR]
;       TST     a2, #1
;       MOVNE   a1, #0 ; This is an FIQ, so don't disable it
;       MSRNE   CPSR_c, a4
;       Pull    "pc", NE
        ; Now mask the interrupt
        ADD     ip, a3, #(ICDICER - IC_DISTRIBUTOR_BASE_ADDR)
        AND     a2, a1, #31     ; bit   = intno % 32
        MOV     lr, a1, LSR #5  ; index = intno / 32
        ADD     ip, ip, lr, LSL #2
        MOV     lr, #1
        MOV     a2, lr, LSL a2  ; mask = (1 << bit)
        SUB     lr, ip, #(ICDICER - ICDISER)
        LDR     lr, [lr, #0]    ; get old state (from ENABLE_SET reg)
        STR     a2, [ip, #0]    ; mask the interrupt
  [ {FALSE} ; reading ICCIAR has side effects on the interrupt system !?
        ; Check if we just disabled the active interrupt ( interfaces and distributor addresses in same logical space)
        LDR     ip, [a3, #(ICCIAR -IC_INTERFACES_BASE_ADDR -(IC_DISTRIBUTOR_BASE_ADDR - IC_INTERFACES_BASE_ADDR))]
        CMP     ip, a1
        STREQ   ip, [a3, #(ICCEOIR -IC_INTERFACES_BASE_ADDR -(IC_DISTRIBUTOR_BASE_ADDR - IC_INTERFACES_BASE_ADDR))]
    [ DebugInterrupts
        MOVEQ   ip, #-1
        STREQ   ip, LastInterrupt_IRQ
    ]
  |
        ; Clear any pending state of this source
        STR     a2, [ip, #(ICDICPR - ICDICER)]
        ; Was it active?
        LDR     ip, [ip, #(ICDABR - ICDICER)]
        TST     ip, a2
        STRNE   a1, [a3, #(ICCEOIR - IC_DISTRIBUTOR_BASE_ADDR)]
    [ DebugInterrupts
        MOVNE   ip, #-1
        STRNE   ip, LastInterrupt_IRQ
    ]
  ]
        MSR     CPSR_c, a4      ; Re-enable interrupts
        AND     a1, lr, a2      ; Test if it was enabled or not
; mov a4,lr
; DebugReg a1,"HIRQ old reg value "
; mov lr,a4
        Pull    "pc"

HAL_IRQClear
; teq   a1, #IMX_INT_UART1;Timer0_IRQ;IMX_INT_USBOH3_UH1   ; all but timer..
; teqne a1, #IMX_INT_UART2;IMX_INT_SDMA
; teqne a1, #IMX_INT_UART3;IMX_INT_IPU1_FUNC
;; teqne a1, #IMX_INT_I2C2
;; teqne a1, #IMX_INT_SATA
; bne %ft001
;  mov a4,lr
;  DebugReg a1,"HIRQ CLR no:"
;  mov lr,a4
;001
        ; This routine is used to clear the vsync interrupt
        ; It must also restart the INTC priority sorting, as it is called after every
        ; OS IRQ handler silences the interrupting device
 [ ExtraDebugInterrupts
        LDR     a2, ExtraDebugIRQEnabled
        CMP     a2, #0
        BEQ     %FT101
        Push    "lr"
        DebugReg a1, "HAL_IRQClear: "
        Pull    "lr"
101
 ]              ;;;;;;;;;;  CODE NEEDS DONE
 [ VideoInHAL
        CMP     a1, #VIDEO_IRQ
        BEQ     %FT20
 ]
10
        ; signal End Of Interrupt
        LDR     a2, IRQC_Log
        STR     a1, [a2, #(ICCEOIR -IC_INTERFACES_BASE_ADDR)]
        ; Data synchronisation barrier to make sure INTC gets the message
        myDSB
 [ DebugInterrupts
        MOV     a1, #-1
        STR     a1, LastInterrupt_IRQ
 ]
        MOV     pc, lr

 [ VideoInHAL
20
        LDR     a2, IPU1_Log
        ADD     a2, a2, #IPU_REGISTERS_OFFSET
        MVN     a3, #0
        STR     a3, [a2, #IPU_IPU_INT_STAT_15_OFFSET-IPU_REGISTERS_OFFSET]
        B       %BT10
 ]

HAL_IRQSource
; mov a4,lr
; DebugTX "HIRQ src chk"
; mov lr,a4
 [ DebugInterrupts :LAND: {FALSE}
        LDR     a1, LastInterrupt_IRQ
        CMP     a1, #0
        BLT     %FT10
        Push    "lr"
        DebugReg a1, "HAL_IRQSource: Previous IRQ not cleared: "
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
        bne     %ft01
        STREQ   a1, LastInterrupt_IRQ
        mov a2,lr
        DebugTX "arm not being irq"
        mov lr,a2
        teq a2,a2
 ]
        MOVEQ   pc, lr
01      LDR     a2, IRQC_Log
        LDR     a3, [a2, #(ICCIAR -IC_INTERFACES_BASE_ADDR)] ; int ack reg.. read only
        BIC     a1, a3, #ICCIAR_CPUID
; teq   a1, #IMX_INT_UART1;Timer0_IRQ;IMX_INT_USBOH3_UH1   ; all but timer..
; teqne a1, #IMX_INT_UART2;IMX_INT_SDMA
; teqne a1, #IMX_INT_UART3;IMX_INT_IPU1_FUNC
;; teqne a1, #IMX_INT_I2C2
;; teqne a1, #IMX_INT_SATA
; bne %ft001
; mov a4,lr
; DebugReg a1,"HIRQ src is:"
; mov lr,a4
;001

        CMP     a1, #IMX_INTERRUPT_COUNT
 [ DebugInterrupts
        STRLO   a1, LastInterrupt_IRQ
 ]
        MOVLO   pc, lr                          ; ret irq no
        ; Authentic spurious interrupt - restart INTC and return -1
        STR     a3, [a2, #(ICCEOIR -IC_INTERFACES_BASE_ADDR)]  ; ack the spurious irq srce
        ; Data synchronisation barrier to make sure INTC gets the message
        myDSB
; mov a4,lr
; DebugReg a1,"HIRQ spurious:"
; mov lr,a4
        MOV     a1, #-1
 [ DebugInterrupts
        STR     a1, LastInterrupt_IRQ
 ]
        MOV     pc, lr

HAL_IRQStatus
        ; Test if IRQ is firing, irrespective of mask state
        CMP     a1, #IMX_INTERRUPT_COUNT
        MOVHS   a1, #0
        MOVHS   pc, lr

        ; First we need to make sure this is an IRQ, not an FIQ?
        LDR     a2, IRQDi_Log
        ; Now check if it's firing

        ADD     ip, a2, #(ICDABR -IC_INTERFACES_BASE_ADDR)
        MOV     a3, a1, LSR #5  ; index = intno / 32
        ADD     ip, ip, a3, LSL #2
        LDR     a3, [ip, #0]    ; get old state
        AND     a1, a1, #31     ; bit   = intno % 32
        MOV     a1, a3, LSR a1  ; Shift and invert so 1=active
        AND     a1, a1, #1      ; 0 = not firing, 1 = firing
; mov a4,lr
; DebugReg a1,"HIRQ status no:"
; mov lr,a4
        MOV     pc, lr


HAL_IRQMax
        MOV     a1, #IMX_INTERRUPT_COUNT
        MOV     pc, lr

;
; ToDo: do we have FIQs
;

HAL_FIQEnable
        MOV     a1, #0
        MOV     pc, lr

HAL_FIQDisable
        MOV     a1, #0
        MOV     pc, lr

HAL_FIQDisableAll
        MOV     pc, lr

HAL_FIQClear
        MOV     pc, lr

HAL_FIQStatus
        MOV     a1, #0
        MOV     pc, lr

HAL_FIQSource
        MOV     a1, #0
        MOV     pc, lr

        END
