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

;Timers.s




     GET     Hdr:ListOpts
     GET     Hdr:Macros
     GET     Hdr:System
     GET     Hdr:OSEntries
     GET     Hdr:Machine.<Machine>
     GET     Hdr:ImageSize.<ImageSize>



    GET     hdr.AllWinnerH3
    GET     hdr.AWH3IRQs
    GET     hdr.Timers
    GET     hdr.StaticWS
    GET     hdr.Registers
 [ Debug
    GET     Debug
    IMPORT  HAL_DebugTX
    IMPORT  HAL_DebugRX
    IMPORT  DebugHALPrint
    IMPORT  DebugHALPrintReg
    IMPORT  DebugMemDump
    IMPORT  DebugHALPrintByte
    IMPORT  DebugCallstack

 ]

    EXPORT  Timers_Init
    EXPORT  HAL_Timers
    EXPORT  HAL_TimerDevice
    EXPORT  HAL_TimerGranularity
    EXPORT  HAL_TimerMaxPeriod
    EXPORT  HAL_TimerSetPeriod
    EXPORT  HAL_TimerPeriod
    EXPORT  HAL_TimerReadCountdown
    EXPORT  HAL_TimerIRQClear
    EXPORT  HAL_TimerIRQStatus

    EXPORT  HAL_CounterRate
    EXPORT  HAL_CounterPeriod
    EXPORT  HAL_CounterRead
    EXPORT  HAL_CounterDelay

    IMPORT  HAL_IRQEnable
    IMPORT  HAL_IRQDisable
    IMPORT  HAL_IRQClear

    AREA    |Asm$$Code|, CODE, READONLY, PIC


;need timer of granularity 1MHz or better and a period of 100Hz.
;period. How often it generates interrupts;
;therefore period = interval.
;Lots of memory barriers because the reads aren't always what
;they should be. These counters have no read latch.


;GO OVER THIS CODE CAREFULLY!
;Find the reason "Timer 0 current value" is uninit'd sometimes.
Timers_Init
    Push "a1-a3, lr"
    LDR a1, TIMER_Log
    ;a1 = TIMER_Log
    ;a2 = scratch
    ;a3 = scratch
    ;LDR a1, [a1]
    ;3 000 000 ticks is 1sec. Set clock divider to 8 (3MHz)
    LDR a3, =30000 ;30 000 interval gives us 100Hz.
    DSB ;First read of the timer is reported as being way out of range sometimes.
    ;Trying to force the issue.
    STR a3, [a1, #TMR0_INTV_VALUE_REG] ; value stored.
    MOV a3, #2_00110100 ;24MHz osc, 8x prescale, repeating.
    STR a3, [a1, #TMR0_CTRL_REG]
    ;set interrupt for Timer 0
    LDR a3, [a1, #TMR_IRQ_EN_REG]
    ORR a3, a3, #2_01 ; Enable interrupt on timer 0
    STR a3, [a1, #TMR_IRQ_EN_REG]
    DSB
    ISB
;---loop waiting for reload bit to clear.
    ;set reload bit
    LDR a3, [a1, #TMR0_CTRL_REG]
    ORR a3, a3, #2_00000010 ;Set reload bit
    STR a3, [a1, #TMR0_CTRL_REG]
    DSB
10
    LDR a3, [a1, #TMR0_CTRL_REG]
    DSB
    AND a3, a3, #2_00000010 ;bit 1
    CMP a3, #0
    MOV a1, a1 ;burn another cycle.
    BNE %BT10 ; waiting for reaload to turn 0;
    DSB
    LDR a3, [a1, #TMR0_CTRL_REG]
    ORR a3, a3, #2_00000001 ;enable timer0
    STR a3, [a1, #TMR0_CTRL_REG]
    DSB
 ;Timer test
 [ Debug


    LDR a2, [a1, #TMR0_CUR_VALUE_REG]
    DSB ;The value below isn't always sane. trying a DSB.
    ;Push "lr"
    DebugReg a2, "Timer 0 current value= "
    ;Pull "lr"
    LDR a2, =50000
20
    ;a little delay
    SUB a2, a2, #1
    CMP a2, #0
    BNE %BT20

    ;Now let's see if it changed.
    LDR a2, [a1, #TMR0_CUR_VALUE_REG]
    ;Push "lr"
    DebugReg a2, "Timer 0 value now = "
    ;Pull "lr"
 ]
    ;let's see if we need to give it a kick.
;    PUSH {lr}
;    MOV a1, #INT_TIMER_0
;    BL  HAL_IRQEnable
;    MOV a1, #INT_TIMER_1
;    BL  HAL_IRQEnable
;    POP  {lr}

    Pull "a1-a3, lr"
    MOV pc, lr
;-----------------------------------------------------------------------------

HAL_Timers
    MOV a1, #2; borrowing one for counter for now ;Two standard timers. Not including HS timer, Watchdog etc.
    mov pc, lr
;-----------------------------------------------------------------------------

HAL_TimerDevice
    ;a1 = timer requested.
    Push "lr"
    DebugTX "HAL_TimerDevice"
    DebugReg a1, "Requested Timer number= "
    CMP a1, #0
    MOVEQ a1, #INT_TIMER_0
    MOVNE a1, #INT_TIMER_1
    ;so lazy :(
    DebugReg a1, "Requested Timer IRQ number= "
    Pull "lr"
    mov pc, lr

;unsigned int HAL_TimerGranularity(int timer)
;The registers are all mixed in.
;-----------------------------------------------------------------------------


HAL_TimerGranularity
;TODO: Add proper code. See cTimers.c for reference code.
     Push "lr"
;Hardcoding granularity value for now.
     LDR a1, =3000000 ;3MHz.
 [ Debug
   Push "a1, lr"
   DebugTX "HAL_TimerGranularity"
   Pull  "a1, lr"
 ]
    ;work out timer specific base
;    CMP a1, #0
;    MOVEQ a2, #TMR0_CTRL_REG
;    MOVNE a2, #TMR1_CTRL_REG
    ;There are common registers below these, so be careful when applying base
    ;address.
    ;granularity is tick speed. # ticks per second.
    ;get the source and prescale.
;    LDR a3, TIMER_Log ;we can always reload this
;    ADD a2, a2, a3 ;a2 is now absolute
    ;let's reuse a1
;    AND a1, a2, #TMR0_CLK_PRES

    ;return the result.
    ;remember SDIV is hardware divide.
    ;maybe just save granularity in StaticWS?
    Pull  "lr"
    MOV    pc, lr
;-----------------------------------------------------------------------------

HAL_TimerMaxPeriod
    Push  "lr"
    ;32 bit timers, so...
    DebugReg a1, "MaxPeriod requested on Timer "
    LDR    a1, =&FFFFFFFF
    Pull  "lr"
    mov    pc, lr
;-----------------------------------------------------------------------------
;void HAL_TimerSetPeriod(int timer, unsigned int period);
HAL_TimerSetPeriod
    Push  "a3, a4, lr"

    ;this DebugReg was corrupted. Why?
    DebugReg a1, "HAL_TimerSetPeriod timer num: "

    LDR    a3, TIMER_Log
    CMP    a1, #0 ;which timer?
;same as TimerPeriod. Same register. Just a write instead.
    DebugReg a2, "HAL_TimerSetPeriod new period: "

    ;let's disable the timer.
    ;a4 = timer specific register
    ;MOVEQ a4, #TMR0_CTRL_REG
    ;MOVNE a4, #TMR1_CTRL_REG
    DSB
    LDREQ a4, [a3, #TMR0_CTRL_REG]
    LDRNE a4, [a3, #TMR1_CTRL_REG]
    BIC   a4, a4, #2_00000001 ;Disable timer
    STREQ a4, [a3, #TMR0_CTRL_REG]
    STRNE a4, [a3, #TMR1_CTRL_REG]
    DSB
    ;new interval stored.
    STREQ a2, [a3, #TMR0_INTV_VALUE_REG]
    STRNE a2, [a3, #TMR1_INTV_VALUE_REG]
    DSB
    MOV   a4, #2_00110100 ;24MHz osc, 8x prescale, repeating.
    STREQ a4, [a3, #TMR0_CTRL_REG]
    STRNE a4, [a3, #TMR1_CTRL_REG]
    DSB
    ;now we need to get it ready to start again.
    ;set reload bit
    ;a1 = timer # /RO
    ;a2 = period. Can be reused from here on as scratch.
    ;a3 = TIMER_Log
    ;a4 = temp register offset / scratch.

    CMP   a1, #0
    ;set interrupt for Timer
    LDR   a4, [a3, #TMR_IRQ_EN_REG]
    ORREQ a4, a4, #2_01 ; Enable interrupt on timer 0
    ORRNE a4, a4, #2_10 ; Enable interrupt on timer 1
    STR   a4, [a3, #TMR_IRQ_EN_REG]
    DSB
    ;getting ready to watch reload bit.
    CMP   a1, #0
    MOVEQ a4, #TMR0_CTRL_REG
    MOVNE a4, #TMR1_CTRL_REG
    LDR   a2, [a3, a4]   ;
    ORR   a2, a2, #2_00000010 ;Set reload bit
    STR   a2, [a3, a4]
10
    DSB
    LDR   a2, [a3, a4]   ;TMRn_CTRL_REG
    AND   a2, a2, #2_00000010 ;bit 1 = reload. bit0 = enable.
    CMP   a2, #0
    BNE   %BT10 ; waiting for reload to turn 0;

    ; Bit cleared. Ready to go!
    LDR   a2, [a3, a4] ;grab current state because previous was fiddled
    ORR   a2, a2, #2_00000001 ;enable timer
    STR   a2, [a3, a4]   ;And... GO!
    DSB     ;Most of these are probably unnecessary.
    Pull   "a3, a4, lr"

    MOV   pc, lr
;-----------------------------------------------------------------------------

;unsigned int HAL_TimerPeriod(int timer)

HAL_TimerPeriod
    Push "a2, lr"
    LDR a2, TIMER_Log
    CMP a1, #0
    LDREQ a1, [a2, #TMR0_INTV_VALUE_REG]
    LDRNE a1, [a2, #TMR1_INTV_VALUE_REG]
    DSB
    DebugReg a1, "HAL_TimerPeriod"

    Pull "a2, lr"
    mov pc, lr
;-----------------------------------------------------------------------------

HAL_TimerReadCountdown ;treat all nonzero timers as 1
    Push  "a2, lr"
    LDR    a2, TIMER_Log
    CMP    a1, #0
    LDREQ  a1, [a2, #TMR0_CUR_VALUE_REG]
    LDRNE  a1, [a2, #TMR1_CUR_VALUE_REG]
    DSB
    DebugReg a1, "HAL_TimerReadCountdown"
    Pull  "a2, lr"
    MOV    pc, lr
;-----------------------------------------------------------------------------

;WTH. This never gets called!
HAL_TimerIRQClear
    Push  "a2, a3, lr"
    LDR    a2, TIMER_Log
    LDR    a3, [a2, #TMR_IRQ_STA_REG]
    CMP    a1, #0
    ;like TimerIRQStatus except we OR, and write back to the register.
    ORREQ  a3, a3, #2_01 ;masked bit 0 for timer 0
    ORRNE  a3, a3, #2_10 ;timer 1
    STR    a3, [a2, #TMR_IRQ_STA_REG]


   ;DebugTX "Timer IRQ Clear"
   ;Spams the terminal. Hopefully at 100Hz

    ;NOT NEEDED. Code is in Kernel to call it.
    ;now let's clear the IRQ in the GIC.
;    CMP a1, #0
;    MOVEQ a1, #INT_TIMER_0
;    MOVNE a1, #INT_TIMER_1
;    BL HAL_IRQClear
    Pull  "a2, a3, lr"
    mov    pc, lr

;-----------------------------------------------------------------------------
HAL_TimerIRQStatus
    Push  "a2, lr"
    LDR    a2, TIMER_Log
    LDR    a2, [a2, #TMR_IRQ_STA_REG]
    CMP    a1, #0
    ANDEQ  a1, a2, #2_01 ;masked bit 0 for timer 0
    ANDNE  a1, a2, #2_10 ;timer 1
    DebugTX "HAL_TimerIRQStatus"
    Pull  "a2, lr"
    mov    pc, lr

;------------------------------------------------------------
;Okay so it's the system counter for the generic timer.
;Perfect. We have over 40 years of timer so not worrying
;about timer wraparound.

;64 bit counter starts automatically at powerup.
;I guess it counts at 24MHz.
;nothing else really needs doing.
HAL_CounterRate
    MRC    p15, 0, a1, c14, c0, 0 ;read CNTFRQ
    MOV    pc, lr
;------------------------------------------------------------

HAL_CounterPeriod
    ;it's a 64 bit counter. I'm leaving it at the full 32b duration.
    ;Working with CNT64_LO
    LDR    a1, =&FFFFFFFF
    MOV    pc, lr
;------------------------------------------------------------
HAL_CounterRead
    Push "a2, lr"
;    Entry "a2"
    MRRC   p15, 0, a1, a2, c14 ;a1 low word, a2 high word.
    ISB
    ;returning the low word.
    Pull "a2, lr"
    MOV pc, lr
;    Exit
;------------------------------------------------------------
HAL_CounterReadOld  ;There is an easier way
    Push  "a2, a3"
    LDR    a2, CPUCFG_BaseAddr
    LDR    a3, [a2, #CNT64_CTRL_REG]
    AND    a3, a3, #2_01
    STR    a3, [a2, #CNT64_CTRL_REG]
    ;now a tight loop to wait for that bit to clear.
10  LDR    a3, [a2, #CNT64_CTRL_REG]
    AND    a3, a3, #2_01
    CMP    a3, #0
    BNE    %BT10
    ;cleared. Latch is ready. Let's read it.
    LDR    a1, [a2, #CNT64_LOW_REG]
    ;Done!
    Pull  "a2, a3"
    MOV    pc, lr
;------------------------------------------------------------
;Not a HAL entry. ONLY call this after HAL_CounterRead.
;Solely to grab high word for HAL_CounterDelay
CounterReadHigh   ;prob. useless.
    Push  "a2"
    LDR    a2, CPUCFG_BaseAddr
    LDR    a1, [a2, #CNT64_HIGH_REG]
    Pull  "a2"
    MOV    pc, lr
;------------------------------------------------------------
HAL_CounterDelay
;    Entry "a2-a4"
    Push "a2-a4, lr"
    Push "a1" ;put this safely away for now.
    ;ohh right. It's in microseconds. as in millionths.
    BL HAL_CounterRate
    ;a1 has clock tick rate. In Hz probably.
    ;divide by 1 000 000 to get multiplier I guess.
    LDR    a2, =1000000 ;1MHz. No danger of dbz here.
    UDIV   a1, a1, a2
    MOV    a2, a1 ;stick the result in a3 because...?
    ;we need to multiply the requested counter delay by the clock multiplier     ;then
    ;add it to the originally loaded value.
    ;it could be a 64 bit number.
    ;a2 = multiplier
    ;a1 = delay
    Pull "a1"
    ;UMULL or MULL?
    UMULL    a3, a4, a2, a1
    ;Boom! a3 and a4 have the 64 bit delta.
    ;pull the counter value
    MRRC   p15, 0, a1, a2, c14
    ISB
    ;store it. Maybe leave it in a1, a2

    ;add delta to the counter value
    ADDS   a3, a3, a1
    ADCS   a4, a4, a2
    ;a3, a4 now contain target value
    ; poll until counter >= calculated value.
    ;a1, a2 can be reused for counter reads.

20
    MRRC   p15, 0, a1, a2, c14
    ISB

    CMP    a2, a4 ;high words
    BGT    %FT40 ;We overslept!
    ;on to the low word.
    CMP    a1, a3
    BGE    %FT40 ;Done! Let's get out of here.
    ;not yet
    NOP
    NOP
    NOP
    NOP ;arbitrary number of operations to kill a little time.
    NOP
    NOP
    NOP
    NOP
    B      %BT20




40
;    Exit
    Pull "a2-a4, lr"
    MOV pc, lr


    END
