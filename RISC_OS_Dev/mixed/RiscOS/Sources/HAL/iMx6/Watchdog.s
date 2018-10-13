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
;

        GET     ListOpts
        GET     Macros
        GET     System
        GET     Machine.<Machine>
        GET     ImageSize.<ImageSize>

        GET     Proc
        GET     OSEntries

        GET     iMx6q
        GET     StaticWS
        GET     AHCI
        GET     HALDevice
        GET     AHCIDevice

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  HAL_Watchdog
        IMPORT  HAL_CounterDelay
        IMPORT  memcpy
        IMPORT  vtophys

 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]


        MACRO
        CallOS  $entry, $tailcall
        ASSERT  $entry <= HighestOSEntry
 [ "$tailcall"=""
        MOV     lr, pc
 |
   [ "$tailcall"<>"tailcall"
        ! 0, "Unrecognised parameter to CallOS"
   ]
 ]
        LDR     pc, OSentries + 4*$entry
        MEND

; HAL_Watchdog exposes access to the watchdog timers
; We will expose WDOG2 to the outside world

; On entry, a1 = reason code
; a1 = 0 report capabilities etc
; a1 = 1 Claim/initialise things
; a1 = 2 write watchdog tickle address
; a1 = 3 acknowledge timeout warning irq.

HAL_Watchdog
        cmp     a1, #1
        blt     WDInfo
        bgt     WDTickle
        beq     WDSetup
        cmp     a1, #4
        blt     WDIRQAck
        mov     pc, lr

; WDTickle writes the contents of a2 to the tickle address.
; it is up to the client to provide the correct write data
; which is indicated in the WDInfo response
WDTickle
        ldr     a1, WDOG1_Log
        strh    a2, [a1, #WDOG_WSR_OFFSET] ; write the tickle register
        MOV     pc, lr
; WDInfo returns a1-> a structure as follows
; flag field to indicate capabilities
; max timeout in 1/2 sec uniits
; max irq warning time prior to watchdog reset , or 0 if no warning irq
; warning irq number
; tickle value count(TVC)
; list of tickle values to use .. TVC words long
;
WDInfo
        adr     a1, WDInfoList
        mov     pc, lr
; flag field values
WDFlag_HardReset        *       (1<<0)
WDFlag_HasTimeout       *       (1<<1)
WDFlag_HasWarnIRQ       *       (1<<2)
WDFlag_WontTurnOff      *       (1<<3)

WDFlags * (WDFlag_HardReset + WDFlag_HasTimeout + WDFlag_HasWarnIRQ + WDFlag_WontTurnOff)

WDInfoList
        DCD     WDFlags         ; flag field
        DCD     500             ; unit size in ms for timeouts below
        DCD     255             ; max timeout in steps above
        DCD     255             ; max warning in steps above
        DCD     IMX_INT_WDOG1   ; watchdog 1
        DCD     2               ; 2 tickle values to reset timer
        DCD     &5555           ; successive tickle values required
        DCD     &aaaa

; WDSetup is called either with a2 = 0 to turn off the watchdog,
; or with a2 = timeout value to turn the watchdog on
; if a2 <> 0 then if a3 <> 0 also set up the warning irq
; according to a3 value.
; for any change a4 = &deaddead; else changes ignored
; This assumes the client has already claimed the IRQ
; In the iMx6 the watchdog bits, once enabled, cannot be turned off
; so the turnoff call is irrelevant; Even turning it off in the SCU
; would lead to a reset once it is turned back on
WDSetup
        ldr     a1, =&deaddead
        teq     a4, a1
        movne   pc, lr
        ands    a2, a2, #&ff
        bne     WDTurnOn
        ldr     a1, WDOG1_Log
        mov     a2, #0          ; all off
        strh    a2, [a1, #WDOG_WCR_OFFSET] ; write the tickle register
        mov     pc, lr

WDTurnOn
        ldr     a1, WDOG1_Log
        ands    a3, a3, #&ff
        and     a2, a2, #&ff
        mov     a2, a2, lsl #8
        orr     a2, a2, #&34            ; enable
        strh    a2, [a1, #WDOG_WCR_OFFSET] ; write the tickle register
        moveq   pc, lr
        orr     a3, a3, #&c000          ; IRQ enable and clear IRQ status
        strh    a3, [a1, #WDOG_WICR_OFFSET] ; write the IRQ register
        mov     pc, lr

; Acknowledge the timeout warning irq bit
WDIRQAck
        ldr     a1, WDOG1_Log
        mov     a3, #&4000              ; IRQ enable and clear IRQ status
        strh    a3, [a1, #WDOG_WICR_OFFSET] ; write the IRQ register
        mov     pc, lr


        END
