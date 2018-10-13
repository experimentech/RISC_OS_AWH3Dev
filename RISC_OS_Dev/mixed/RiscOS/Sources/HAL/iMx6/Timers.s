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
        $GetIO
        GET     Hdr:Proc

        GET     Hdr:OSEntries
        GET     Hdr:HALEntries

        GET     hdr.iMx6q
        GET     hdr.StaticWS
        GET     hdr.Timers
        GET     hdr.PRCM

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  HAL_Timers
        EXPORT  HAL_TimerDevice
        EXPORT  HAL_TimerGranularity
        EXPORT  HAL_TimerMaxPeriod
        EXPORT  HAL_TimerSetPeriod
        EXPORT  HAL_TimerPeriod
        EXPORT  HAL_TimerReadCountdown
        EXPORT  HAL_TimerIRQClear

        EXPORT  HAL_CounterRate
        EXPORT  HAL_CounterPeriod
        EXPORT  HAL_CounterRead
        EXPORT  HAL_CounterDelay

        EXPORT  Timer_Init

        IMPORT  __rt_udiv10
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]
        IMPORT  GetIPGClk

        MACRO
        SecureOn $r
        MRS     $r, CPSR          ; remember our mode
        MSR     CPSR_c, #F32_bit+I32_bit+(MON32_mode);
        MEND

        MACRO
        SecureOff $r
        MSR     CPSR_c, $r
        MEND

Timer_Init
        Entry
        ; Make sure all the timers are actually enabled
        adrl    a1, Timers_Log
        ldr     a2, [a1], #4            ; get GPT timer address
        ldr     v2, [a2, #GPT_GPTCR_OFFSET]
        bic     v2, v1, #1
        str     v2, [a2, #GPT_GPTCR_OFFSET] ; disable
        ldr     a4, CCM_Base
        ldr     v1, [a4, #CCM_CCGR1_OFFSET]
        orr     v1, v1, #&f << 20       ; gpt ser clk en and gpt clk en
        str     v1, [a4, #CCM_CCGR1_OFFSET]  ; clocks on
        bic     v2, v2, #7 <<6
; iMX6 is normally driven by a 24MHz clock
        orr     v2, v2, #7 <<6          ; set to 24MHz clock reference
        bic     v2, v2, #1 << 9         ; force to restartmode
        mov     v1, #23
        str     v1, [a2, #GPT_GPTPR_OFFSET] ; prescale divide by 24
        ldr     v1, = 10000             ; 24MHz / 24 / 10000 = 100Hz
        str     v1, [a2, #GPT_GPTOCR1_OFFSET] ; prescale divide by 8
        orr     v2, v2, #1              ; enable
        str     v2, [a2, #GPT_GPTCR_OFFSET] ; enable

        ; Configure EPIT1 & 2 to use the IPG clock
        Push    "a1"
        BL      GetIPGClk
        STR     a1, EPITClk
        Pull    "a1"
        ldr     a2, [a1], #4            ; get EPIT1 timer address
        BL      EPIT_Init
        ldr     a2, [a1], #4            ; get EPIT2 timer address
        BL      EPIT_Init

 [ A9Timers
; this is within CPU, so assume powered and clocked
        ldr     a2, [a1], #4            ; private timers and watchdog address
; set for secure accessing for timer and registers (MON32_mode)
        SecureOn a3
        ldr     a4, SCU_Log
        mov     v1, #1                  ; only CPU1
        str     v1, [a4, # SCU_SAC - SCU_BASE_ADDR]
        mov     v1, #1                  ; CPU1 allowed global and private access
        str     v1, [a4, # SCU_SNSAC - SCU_BASE_ADDR]   ; in secure mode
        SecureOff a3
        ldr     a2, [a1], #4            ; get global timer address
; set for secure accessing for timer and registers
 ]
        EXIT

; In: a2 -> EPIT instance
EPIT_Init ROUT
        Entry   "a1"
        ; Reset the module
        MOV     a1, #1:SHL:16
        STR     a1, [a2, #EPIT_CR]
        ; Wait for completion
10
        LDR     a1, [a2, #EPIT_CR]
        TST     a1, #1:SHL:16
        BNE     %BT10
        ; Select IPG clock as source
        MOV     a1, #1:SHL:24
        ; Use reload mode with interrupt
        ORR     a1, a1, #(1:SHL:3) + (1:SHL:1) + (1:SHL:2)
        ORR     a1, a1, #1:SHL:17
        STR     a1, [a2, #EPIT_CR]
        EXIT

HAL_Timers
        MOV     a1, #TIMER_MAX
        MOV     pc, lr

; return IRQ number for timer
HAL_TimerDevice
; mov a2,lr
; DebugReg a1, "hal_timer no:"
; mov lr,a2
        CMP     a1, #TIMER_MAX
        MVNHS   a1, #0          ; Error!
        ADRLO   a2, TimerIRQTable
        LDRLO   a1, [a2, a1, lsl #2]
; mov a2,lr
; DebugReg a1, "hal_device is:"
; mov lr,a2
        MOV     pc, lr
TimerIRQTable
        DCD     Timer0_IRQ
        DCD     Timer1_IRQ
        DCD     Timer2_IRQ
 [ A9Timers
        DCD     Timer3_IRQ
        DCD     Timer4_IRQ
 ]

HAL_CounterRate
        LDR     a1, =1000000     ; with the timer input set to 1MHz .. ticks per second
        MOV     pc, lr

HAL_TimerGranularity
        CMP     a1, #TIMER_MAX
        LDRLO   pc, [pc, a1, LSL #2]
        MOV     pc, lr
        DCD     HAL_CounterRate
        DCD     EPIT_Granularity
        DCD     EPIT_Granularity
      [ A9Timers
        DCD     PVT_Granularity
        DCD     GBL_Granularity
      ]

EPIT_Granularity
        LDR     a1, EPITClk
        MOV     pc, lr

HAL_TimerMaxPeriod
        LDR     a1, = 0xffffffff
        MOV     pc, lr

HAL_TimerSetPeriod
        CMP     a1, #TIMER_MAX
        ; Get pointer to registers
        ADRL    a3, Timers_Log
        LDRLO   a3, [a3, a1, LSL #2]
        LDRLO   pc, [pc, a1, LSL #2]
        MOV     pc, lr
        DCD     GPT_SetPeriod
        DCD     EPIT_SetPeriod
        DCD     EPIT_SetPeriod
      [ A9Timers
        DCD     PVT_SetPeriod
        DCD     GBL_SetPeriod
      ]

GPT_SetPeriod
        ; Temporarily stop the timer to avoid the unexpected
        LDR     a4, [a3, #GPT_GPTCR_OFFSET]
        BIC     a4, a4, #Timer0En    ; Stop timer
        STR     a4, [a3, #GPT_GPTCR_OFFSET]
        ; If we actually wanted to stop the timer, we can exit now
        CMP     a2, #0
        MOVEQ   pc, lr
        CMP     a2, #1
        MOVEQ   a2, #2
        STR     a2, [a3, #GPT_GPTOCR1_OFFSET]   ; outpt compare value set
        MOV     a2, #Timer0IEN                  ; Enable compare1 interrupt
        STR     a2, [a3, #GPT_GPTIR_OFFSET]
        ; Re-enable the timer, in auto-reload mode
        BIC     a4, a4, #Timer0RstMode          ; start at 0 on reaching compare
        ORR     a4, a4, #Timer0En
        STR     a4, [a3, #GPT_GPTCR_OFFSET]
        MOV     pc, lr

EPIT_SetPeriod
        ; Temporarily stop the timer to avoid the unexpected
        LDR     a4, [a3, #EPIT_CR]
        BIC     a4, a4, #1
        STR     a4, [a3, #EPIT_CR]
        ; If we actually wanted to stop the timer, we can exit now
        CMP     a2, #0
        MOVEQ   pc, lr
        ; Set new reload value
        SUB     a2, a2, #1 ; Period is 1 tick longer than reload value
        STR     a2, [a3, #EPIT_LR]
        ; Compare value needs to match reload value to get the IRQ when we reload
        STR     a2, [a3, #EPIT_CMPR]
        ; Clear any previous IRQ
        MOV     a2, #1
        STR     a2, [a3, #EPIT_SR]
        ; Enable timer
        ORR     a4, a4, #1
        STR     a4, [a3, #EPIT_CR]
        MOV     pc, lr

HAL_CounterPeriod
        MOV     a1, #0
        ; Fall through

HAL_TimerPeriod
        CMP     a1, #TIMER_MAX
        ADRL    a2, Timers_Log
        LDRLO   a2, [a2, a1, LSL #2]
        MOVHS   a1, #0
        LDRLO   pc, [pc, a1, LSL #2]
        MOV     pc, lr
        DCD     GPT_Period
        DCD     EPIT_Period
        DCD     EPIT_Period
      [ A9Timers
        DCD     PVT_Period
        DCD     GBL_Period
      ]

GPT_Period
        LDR     a1, [a2, #GPT_GPTCR_OFFSET]
        ANDS    a1, a1, #Timer0En    ; =0 if timer is stopped
        ; if timer running, get output compare value
        LDRNE   a1, [a2, #GPT_GPTOCR1_OFFSET]
        MOV     pc, lr

EPIT_Period
        LDR     a1, [a2, #EPIT_CR]
        ANDS    a1, a1, #1 ; =0 if timer is stopped
        ; if timer running, get reload value
        LDRNE   a1, [a2, #EPIT_LR]
        ADDNE   a1, a1, #1
        MOV     pc, lr

; countdown counts between timer period-1 and 0
HAL_CounterRead
        MOV     a1, #0                                 ; counter is just timer 0
        ; Fall through

HAL_TimerReadCountdown
        CMP     a1, #TIMER_MAX
        ADRL    a2, Timers_Log
        LDRLO   a2, [a2, a1, LSL #2]
        MOVHS   a1, #0
        LDRLO   pc, [pc, a1, LSL #2]
        MOV     pc, lr
        DCD     GPT_ReadCountdown
        DCD     EPIT_ReadCountdown
        DCD     EPIT_ReadCountdown
      [ A9Timers
        DCD     PVT_ReadCountdown
        DCD     GBL_ReadCountdown
      ]

GPT_ReadCountdown
        LDR     a1, [a2, #GPT_GPTCNT_OFFSET]           ; current value
        LDR     a3, [a2, #GPT_GPTOCR1_OFFSET]          ;  max (roll around) value
        SUB     a1, a3, a1                             ; distance between current and max value
        MOV     pc, lr

EPIT_ReadCountdown
        LDR     a1, [a2, #EPIT_CNTR]
        ; The off-by-one nature of the registers might not be that important
        ; here, but deal with it anyway
        ADD     a1, a1, #1
        MOV     pc, lr

; If they want n ticks, wait until we've seen n+1 transitions of the clock.
; This function is limited to delays of around 223.6 seconds. Should be plenty!
; a tick is a microsecond!!
HAL_CounterDelay
        Push    "ip, lr"
;        LDR     a2, Timer_DelayMul
;     mov a2,#10
;        MUL     a1, a2, a1 ; Calculate required ticks*10
;        BL      __rt_udiv10 ; Actual required ticks
; DebugReg a1, "Ticks "
        LDR     a4, Timers_Log ; Get timer 0
        LDR     a2, [a4, #GPT_GPTCNT_OFFSET]  ; initial value
        LDR     a3, [a4, #GPT_GPTOCR1_OFFSET] ; compare value
10
        LDR     lr, [a4, #GPT_GPTCNT_OFFSET]  ; read again
        SUBS    ip, lr, a2
        ADDLO   ip, ip, a3                    ; if wrapped, then add wrap value
        SUBS    a1, a1, ip
        MOVHS   a2, lr
        BHS     %BT10
        Pull    "ip, pc"

HAL_TimerIRQClear
        CMP     a1, #TIMER_MAX
        ADRL    a3, Timers_Log
        LDRLO   a3, [a3, a1, LSL #2]
        LDRLO   pc, [pc, a1, LSL #2]
        MOV     pc, lr
        DCD     GPT_IRQClear
        DCD     EPIT_IRQClear
        DCD     EPIT_IRQClear
      [ A9Timers
        DCD     PVT_IRQClear
        DCD     GBL_IRQClear
      ]

GPT_IRQClear
        MOV     a2, #&3f          ; Ackn all possible GPTinterrupts
        STR     a2, [a3, #GPT_GPTSR_OFFSET]
        ; reenable.. in case
        LDR     a4, [a3, #GPT_GPTCR_OFFSET]
        BIC     a4, a4, #Timer0RstMode          ; start at 0 on reaching compare
        ORR     a4, a4, #Timer0En
        STR     a4, [a3, #GPT_GPTCR_OFFSET]
        MOV     pc, lr

EPIT_IRQClear
        MOV     a1, #1
        STR     a1, [a3, #EPIT_SR]
        MOV     pc, lr

        END
