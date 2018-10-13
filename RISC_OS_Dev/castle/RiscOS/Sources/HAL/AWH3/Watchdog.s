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


;This file could easily be a part of Timers.s but it isn't.

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:HALEntries
        GET     Hdr:OSEntries

        GET     hdr.AllWinnerH3
        GET     hdr.StaticWS
        GET     hdr.Timers
        GET     hdr.Interrupts
        GET     hdr.AWH3IRQs
        
 [ Debug
    IMPORT  HAL_DebugTX
    IMPORT  HAL_DebugRX
    IMPORT  DebugHALPrint
    IMPORT  DebugHALPrintReg
    IMPORT  DebugMemDump
    IMPORT  DebugHALPrintByte
    IMPORT  DebugCallstack
    
 ]


        AREA    |Asm$$Code|, CODE, READONLY, PIC
        EXPORT  HAL_Watchdog
        IMPORT  HAL_IRQClear
;        EXPORT  Init_Watchdog

;WDResolutionSteps = ms?
;This whole Watchdog thing is awful.
WDInfo  ;SPACE (7*4)
WDFlags    *      2_1011
WDResolution *    1000 ; What a pain. Doesn't quite match with the way it works.
WDMaxTimeout *    16 ;ARGH. 0.5, 1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 16
WDMaxToWarn  *    0
WDIRQNum     *    57 ;Tickle value is &A57. How about that.
WDNtickle    *    1
WDTickleData *    &A57

;Don't use this function. It'll just cause a reset after a second.

Init_Watchdog  ;probably won't get used.
    LDR    a4, TIMER_Log ;WD is a part of the timer block still.
;    MOV    a1, #2_1 ;whole system reset
    MOV    a1, #2_10 ;Just generate an interrupt.
    STR    a1, [a4, #WDOG0_CFG_REG]

;    MOV    a1, #2_10000 ;&10 Interval 1s
    MOV    a1, #5
    MOV    a1, a1, LSL #4 ;5sec. b7:4 are interval.
    STR    a1, [a4, #WDOG0_MODE_REG]

    LDR    a1, [a4, #WDOG0_MODE_REG]
    ORR    a1, a1, LSL#0
    STR    a1, [a4, #WDOG0_MODE_REG] ;enable watchdog.
    B      %FT40
;    mov pc, lr

;watchdog reset and restart are the same.
;floaty unused code.
;this is how we reset the watchdog.
;    LDR    a1, [a4, #WDOG0_CTRL_REG]
;    ORR    a1, a1, (#&A57<<1)
;    ORR    a1, a1, (#1<<0)
;    STR    a1, [a4, #WDOG0_CTRL_REG]



HAL_Watchdog
    Push "lr"

    CMP a1, #0    ;return information struct
    BEQ %FT5
    CMP a1, #1    ;start / stop timer
    BEQ %FT10
    CMP a1, #2    ;write watchdog tickle address
    BEQ %FT20
    CMP a1, #3    ;acknowledge timeout warning IRQ
    BEQ %FT30
    B   %FT40     ;This shouldn't happen
;--------------------------------------------------------------------

5     ;reason 0
    LDR    a1, WDInfo
    B      %FT40

;--------------------------------------------------------------------
10    ;reason 1
    ;let's check magic before reusing a4
    LDR    a3, =&DEADDEAD
    CMP    a4, a3
    BNE    %FT40

    LDR    a4, TIMER_Log
    CMP    a2, #0 ;timeout
    BEQ    %FT40
    ;all timeouts need the config set
    ;use a3?
    MOV    a3, #2_01 ;reset whole system! 10 is interrupt.
    STR    a3, [a4, #WDOG0_CFG_REG]
    BEQ    %FT40  ;can't stop the timer. Just incase something tries anyway.
    ;A 0 value gives 0.5s timeout from WD, which would be not good.
    CMP    a2, #6  ;timeout <=6
    BLE    %FT15
                   ;timeout > 6
    ;Surely this can be simplified. it looks silly!
    SUB    a2, a2, #6
    MOV    a2, a2, LSR #1
    ADD    a2, a2, #6

    ;Gives correct value to feed to register over 6, and removes odd numbered entries.
     ;That shouldn't have been there!
    ;STR    a2, [a4, WDOG0_MODE_REG]

    ;value > 6
    ;LSR >> 1

15  ; value <= 6
    MOV    a2, a2, LSL #4 ;bit shift time.
    ORR    a2, a2, #1 ;enable WDOG
    STR    a2, [a4, #WDOG0_MODE_REG]
    B      %FT40


;--------------------------------------------------------------------

20    ;reason 2
      ;Defeating half the purpose of a Watchdog here. Using canned tickle.
      ;TODO: Add proper sanity check.
    Push   "a3, a4"
    LDR    a1, [a4, #WDOG0_CTRL_REG]
    LDR    a2, =&A57
    ORR    a1, a2, LSL#1 ;(&A57<<1)
    ORR    a1, a1, #1
    STR    a1, [a4, #WDOG0_CTRL_REG]
    Pull    "a3, a4"
    B      %FT40

;--------------------------------------------------------------------

30    ;reason 3
    ;copypasted the top bit from above.
    ;This code should really never run as there is no warning IRQ.
    Push   "a2-a4"
    LDR    a1, [a4, #WDOG0_CTRL_REG]
    LDR    a2, =&A57
    ORR    a1, a2, LSL#1 ;(&A57<<1)
    ORR    a1, a1, #1
    STR    a1, [a4, #WDOG0_CTRL_REG]

    MOV    a1, #INT_WATCHDOG
    BL     HAL_IRQClear
    Pull   "a2-a4"
;--------------------------------------------------------------------

40
;fallthrough fail / common exit point.
    Pull "lr"
	MOV pc, lr

	END
