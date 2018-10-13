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
        GET     Hdr:Proc

        GET     Hdr:OSEntries

        GET     hdr.iMx6q
        GET     hdr.PRCM
        GET     hdr.StaticWS
        GET     hdr.Timers

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        IMPORT  Timer_Init
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]

        EXPORT  PRCM_SetClocks
        EXPORT  PRCM_GetFreqSel

PRCM_SetClocks
        Push    "v1-v4,lr"
        BL      Timer_Init ; Just (re)initialise all of them for simplicity
; DebugReg a1, "test "
        LDR     a3, Timers_Log          ; Timer_0, used for the ticker
; DebugReg a3, "Timers_Log "
;        MOV     a1, #0
;        STR     a1, [a3, #GPT_TLDR]     ; Start at 0
;        MOV     a1, #GPT_TCLR_ST
;        STR     a1, [a3, #GPT_TCLR]     ; Start timer
;;        LDR     a4, L4_32KTIMER_Log
;        LDR     a1, [a4, #REG_32KSYNCNT_CR]
;        ; Wait 20 ticks. But unlike u-boot, we'll properly take into account the chance of
;        ; the timer overflowing
;10
;        LDR     a2, [a4, #REG_32KSYNCNT_CR]
;        SUB     a2, a2, a1
;        CMP     a2, #20
;        BLT     %BT10
;        ; Now begin
;        LDR     a1, [a4, #REG_32KSYNCNT_CR]
;        LDR     v1, [a3, #GPT_TCRR]
;10
;        LDR     a2, [a4, #REG_32KSYNCNT_CR]
;        LDR     v2, [a3, #GPT_TCRR]
;        SUB     a2, a2, a1
;        CMP     a2, #20
;        BLT     %BT10
;        SUB     a1, v2, v1
;        ; Now search the lookup table for the right entry
;        ADR     a2, SysClkTable
;10
;        LDMIA   a2!,{a3,a4,v1,v2,v3}
;        CMP     a1, a3
;        BLE     %BT10
;        STR     a4, sys_clk
;        STR     v3, Timer_DelayMul
        Pull    "v1-v4,pc"

PRCM_GetFreqSel
        ; Return PLL FREQSEL value for a given clock frequency
        ; In: a1=Fint
        ; Out: a1=FREQSEL, 0 for error
        ; Corrupts a2-a4,ip
        ADR     ip, FreqSelTable
10
        LDMIA   ip!, {a2-a4}
        CMP     a1, a2
        CMPHS   a3, a1
        BLO     %BT10
        MOV     a1, a4
        MOV     pc, lr


SysClkTable
        ;       Counter Clock speed     SYS_CLKSEL      Divider DelayMul
        DCD     19000,  38400000,       7,              2,      384
        DCD     15200,  26000000,       5,              2,      260
        DCD     9000,   19200000,       4,              1,      192
        DCD     7600,   13000000,       1,              1,      130
        DCD     -1,     12000000,       0,              1,      120
        ; Where is 16.8MHz?

FreqSelTable
        ;   Min rate  Max rate   FREQSEL value
        DCD 750000,   1000000,   &3
        DCD 1000000,  1250000,   &4
        DCD 1250000,  1500000,   &5
        DCD 1500000,  1750000,   &6
        DCD 1750000,  2100000,   &7
        DCD 7500000,  10000000,  &B
        DCD 10000000, 12500000,  &C
        DCD 12500000, 15000000,  &D
        DCD 15000000, 17500000,  &E
        DCD 17500000, 21000000,  &F
        DCD 0,        &FFFFFFFF, 0 ; List terminator is catch-all for error case

        END
