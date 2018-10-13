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
        GET     Hdr:GraphicsV

        GET     hdr.iMx6q
        GET     hdr.iMx6qIRQs
        GET     hdr.StaticWS
        GET     hdr.PRCM
        GET     hdr.GPIO
        GET     hdr.CoPro15ops
        GET     hdr.Timers
        GET     hdr.CPUSpeed

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  CPU_Speed_Init
        IMPORT  HAL_CounterDelay
        IMPORT  memcpy
        IMPORT  udivide

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

; this table is used to interpolate the various voltages to get best fit
; for a given clock. Presumption is that Highest frequency is first entry
KnowCPUTab
Kct1    DCD     1200                    ;MHz Clock
KctIndx DCD     1200/12                 ; arm PLL setting
KctVPU  DCD     1275-700                    ;mV  Vdd-VPU
KctSOC  DCD     1275-700                    ;mV  Vdd-SOC
KctARM  DCD     1275-700                    ;mV  Vdd-ARM
KctLen  *       (.-Kct1)
        ;
Kct2    DCD     996                     ;MHz
        DCD     996/12
        DCD     1250-700                    ;mV
        DCD     1250-700                    ;mV
        DCD     1250-700                    ;mV
        ;
Kct4    DCD     792                     ;MHz
        DCD     792/12
        DCD     1175-700                    ;mV
        DCD     1175-700                    ;mV
        DCD     1150-700                    ;mV
        ;
Kct5min DCD     672                     ;MHz    ; min freq .. index=1
        DCD     672/12
        DCD     1175-700                    ;mV
        DCD     1175-700                    ;mV
        DCD     1100-700                    ;mV     ; jb interpolated
        ;
KctSlow DCD     324                     ;MHz    ; frequency when switched to
        DCD     672/12
        DCD     1175-700                    ;mV     ; step clock
        DCD     1175-700                    ;mV
        DCD     1100-700                     ;mV (975 in ix, but need 1175 or freeze


;
; min to set ARM pll divider. data sheet says 54, give it a margin
; max to set is 108, also give it a margin; PLL speed is this * 12
; The CPUClk device traditionally has a table of speeds. This one is
; fully variable. Index 0 will be slowest clock by lots. It will be the slowest
; normal ARM clock. /2. (using arm_podf divider in CCM_CACRR)
; the rest of the clocks track through
CPUMinClkDivReg *       (54+2 ) ; 672MHz .. needs to be consistent with above
CPUMaxClkDivReg *       (108 - 4)       ; 1248MHz.. not guaranteed to work at this

CPUMaxProduction *      (1008)          ; max MHz for production
CPUMaxPrdClkDivReg *    (CPUMaxProduction/12)

; index for the max we'll let it set
                                ; in normal use

CPU_Speed_Init  ROUT
        Entry   "a1 - a4, v1"
        ; device to place
        adrl    v1, CPUClk_Device
        mov     a1, v1
        ADRL    a2, CPUClkDevTemplate
        MOV     a3, #HALDevice_CPUClk_Size
        BL      memcpy
        ; initial speed table to place - only report speeds up to known max
        MOV     a1, v1                  ; point to device again
        mov     a3, #(CPUMaxPrdClkDivReg-CPUMinClkDivReg)+2
        strb    a3, CPUClknSpeeds
        str     sb, HALClkSB
        strb    a3, CPUClkCurSpeedIdx      ; and poke
        mvn     a3, #0                     ; -1 to show speed is set
        strb    a3, CPUClkNewSpeedIdx      ; and poke
        MOV     a1, #0
        MOV     a2, v1
; DebugReg a2, "HAL CPUClk Dev Addr  "
        CallOS  OS_AddDevice

; DebugTX "Device added "
        EXIT

; on entry, a1-> HAL_Device in HAL RAM
; entry a2 = clock in MHz
; exit  a2 = Index for external use
;       a3 = clock value to use in ARM_Pll, with bit31 set if need podf/2
; If the clock requested does nor match an exact frequency, then it is
; rounded dow to the next one available.
CPUClkIndexFromClock ROUT
        EntryS  "a1, a3, sb"
        ldr     sb, HALClkSB
; DebugRegNCR a2,"ClkFreq="
        adr     a3, Kct1
        ldr     lr, [a3]
        cmp     a2, lr
        movgt   a2, lr          ; dont go too big
        adr     a3, KctSlow
        ldr     lr, [a3]
        cmp     a2, lr
        movlt   a2, lr          ; dont go too small
        bgt     %ft1            ; it isn't the slowest freq
;
        ldr     a3, [a3,#KctIndx-Kct1] ; get divider value
        orr     a3, a3, #1<<31  ; need to set arm_podf to 2 not 1
        mov     a2, #0          ; slowest is index 0
; DebugReg a2,"->"
        EXITS
1       mov     a1, a2
        mov     a2, #12
        bl      udivide         ; a1/a2 ..   ans in a2, remainder in a1
        mov     a3, a1
        sub     a2, a2, #(CPUMinClkDivReg-1) ; so min value has index 1
; DebugReg a2,"->"
        EXITS

; on entry, a1-> HAL_Device in HAL RAM
; entry a2 = Clock index (as returned above)
; exit  a2 = VddVPU             ; in mV
;       a3 = VddSOC             ; in mV
;       a4 = VddARM             ; in mV
CPUClkSettingsFromClockIndex  ROUT
        EntryS  "v1,v2"
        ldr     sb, HALClkSB
; DebugRegNCR a2, "ClkIndex="
        cmp     a2, #1          ; min speed or next
        bgt     %ft1            ; .. no.. need to interpolate
; using one of the bottom 2 settings in the table
        adrne   v1, KctSlow + (KctVPU-Kct1) ; its vv slow
        adreql  v1, Kct5min + (KctVPU-Kct1) ; its min on normal clock
        ldmia   v1, {a2, a3, v2}
        mov     a4, a2
        bl      doscale
        mov     a2, a4
        mov     a4, a3
        bl      doscale
        mov     a3, a4
        mov     a4, v2
        bl      doscale
; DebugRegNCR a2,"VddVPUr= "
; DebugRegNCR a3,"VddSOCr= "
; DebugReg v2,"VddARMr= "
        EXITS
; using an interpolated setting from the table points
1       add     a2, a2, #CPUMinClkDivReg ; so index matches
        adrl    v1, KctIndx     ; scan the table to bracket it
2       ldr     a4, [v1, #KctLen] ; lower value
        ldr     a3, [v1], #4      ; higher value .. then point at KctVPU
        cmp     a2, a4          ; in range .. a2 should be smaller than a4
        addle   v1, v1, #KctLen-4; look in the next pair
        ble     %bt2
        cmp     a2, a3          ; oops its top, or too big
        ble     Intrpl
        ldmia   v1, {a2-a4}     ; use fastest value

Intrpl                          ; do the interpolate
; VddVPU first
        mov     v2, v1
        mov     a1, a2          ; target value
        ldr     a3, [v1, #KctIndx-KctVPU]       ; hi value
        ldr     a4, [v1, #KctLen+(KctIndx-KctVPU)] ; low end value
        sub     a1, a1, a4      ; index start at 0
        sub     a2, a3, a4      ; number of steps betweem
        ldr     a3, [v1, #KctLen] ; fetch low end value
        ldr     a4, [v1]        ; hi value
        bl      InterpolateIt
        Push    "a4"            ; store desired Vdd on stack
        add     v1, v2, #KctSOC-KctVPU
        ldr     a3, [v1, #KctLen] ; fetch low end value
        ldr     a4, [v1]        ; hi value
        bl      InterpolateIt
        Push    "a4"            ; store desired Vdd on stack
        add     v1, v2, #KctARM-KctVPU
        ldr     a3, [v1, #KctLen] ; fetch low end value
        ldr     a4, [v1]        ; hi value
        bl      InterpolateIt
        Pull    "a2-a3"         ; recover rest from stack
; DebugRegNCR a2,"VddVPUi="
; DebugRegNCR a3,"VddSOCi="
; DebugReg a4,"VddARMi="
        EXITS

; entry:a1 = target value in this step
;       a2 = total count in this step
;       a3 = value at start
;       a4 = value at end
;
;
; exit: compute a4= a4 + (((a4-a3)*a1)/a2) rounded to nearest 25mv
;
InterpolateIt ROUT
        EntryS  "a1, a2, a3"
; DebugRegNCR a1,"Target-"
; DebugRegNCR a2,"counts-"
; DebugRegNCR a3,"s-val-"
; DebugReg    a4,"e-val-"
        mov     lr, a1
        mov     a1, a2
        mov     a2, lr          ; swap a1 and a2
        sub     a4, a4, a3      ; span
; DebugRegNCR a4,"Span-"
        mul     a2, a4, a2      ; *top of fraction
        mov     a4, a1, lsr #1  ; remember counts/2
; DebugRegNCR a2,"* tgt-"
        bl      udivide         ; a1 = a2/a1 ; remainder in a2
; DebugRegNCR a1,"/cnts-"
        cmp     a2, a4          ; need round up?
        addgt   a1, a1, #1      ; yes.. round up
        add     a4, a1, a3
        b       %ft1
; div 25 to get to required value
doscale ALTENTRY
1
; DebugReg a4,"result"
; now round up or down to nearest 25mv
        mov     a3, #25
        mov     a1, a3
        mov     a2, a4
; DebugRegNCR a2,"result-"
        bl      udivide
;        mul    a4, a1, a3      ; compute down to 25mv steps
        mov     a2, a2, lsl #1
        cmp     a2, a3          ; is remainder over 1/2
        mov     a4, a1
        addge   a4, a4, #1      ; yes.. round up
; DebugReg a4,"resultnorm-"
        EXITS


CPUClkDevTemplate
        DCW     HALDeviceType_SysPeri + HALDeviceSysPeri_CPUClk
        DCW     HALDeviceID_CPUClk_IMX6
        DCD     HALDeviceBus_Sys + HALDeviceSysBus_AXI
        DCD     0                     ; API version
        DCD     CPUClk_Desc           ; Description
        DCD     0                     ; Address - unused
        %       12                    ; Unused
        DCD     CPUClk_Activate
        DCD     CPUClk_Deactivate
        DCD     CPUClk_Reset
        DCD     CPUClk_Sleep
        DCD     -1                    ; Device - unused
        DCD     0                     ; TestIRQ
        DCD     0                     ; ClearIRQ
        %       4
        ASSERT  (.-CPUClkDevTemplate) = HALDeviceSize
        DCD     CPUClk_NumSpeeds
        DCD     CPUClk_Info
        DCD     CPUClk_Get
        DCD     CPUClk_Set
        DCD     CPUClk_Override
        ASSERT  (.-CPUClkDevTemplate) = HALDevice_CPUClk_Size

CPUClk_Desc
        =       "iMx6 CPU clock generator",0
        ALIGN
; on entry, a1-> HAL_Device in HAL RAM
CPUClk_Activate  ROUT
        ; Do nothing
        MOV     a1, #1
CPUClk_Deactivate ROUT
CPUClk_Reset ROUT
        MOV     pc, lr

CPUClk_Sleep ROUT
        MOV     a1, #0
        MOV     pc, lr

; on entry, a1-> HAL_Device in HAL RAM
CPUClk_NumSpeeds ROUT
        ; Out: a1 = num entries in table
        EntryS
        ldrb    a1, CPUClknSpeeds
        EXITS

; on entry, a1-> HAL_Device in HAL RAM
CPUClk_Info ROUT
        ; In: a2 = table index
        ; Out: a1 = MHz
        EntryS  "sb"
        ldr     sb, HALClkSB
; DebugRegNCR a2, "clkMHz for index "
        cmp     a2, #1                  ; slowest and min clk speeds
        bgt     %ft1
        adrl    a2, KctSlow
        adreql  a2, Kct5min
        ldr     a1, [a2]
        b       %ft2
; compute speed index
1       add     a2, a2, #CPUMinClkDivReg-1
        cmp     a2, #CPUMaxClkDivReg
        movgt   a2, #CPUMaxClkDivReg    ; clip to max
        mov     a1, #12
; DebugRegNCR a1, "Mult "
; DebugRegNCR a2, "by "
        mul     a1, a2, a1
2
; DebugReg a1, "gave "
        EXITS

; on entry, a1-> HAL_Device in HAL RAM
CPUClk_Get ROUT
        ; Return current table index
        EntryS  "sb"
        ldr     sb, HALClkSB
        ldrb    a2, CPUClkNewSpeedIdx
        CMP     a2, #-1 ; Are we changing speed?
        BLNE    CPUClk_Set ; Yes, complete the change so that the returned value is accurate
        ldrb    a1, CPUClkCurSpeedIdx
; DebugReg a1, "Reported speed index "
        EXITS

; on entry, a1-> HAL_Device in HAL RAM
CPUClk_Set ROUT
        ; a2 = new table index
        ; Return 0 on success, -1 on failure
        EntryS  "v1-v5,sb"
        mov     v3, a1          ; remember the haldev address
        add     v4, a2, #CPUMinClkDivReg ; so index matches + remember
        ldr     sb, HALClkSB
; DebugReg a2, "Set CPUSpeed index "
        mov     v1, #0
        add     v5, a1, #:INDEX:CPUClkNewSpeedIdx
        strb    v1, [v5]        ; flag speed changing
; now set the voltages, then the clock itself
        ldr     v1, CCMAn_Log   ; get logical address
        mov     a1, v3
        bl      CPUClkSettingsFromClockIndex
        ldr     v2, [v1, #HW_CCM_PMU_REG_CORE_ADDR] ; read regulator voltages
; DebugRegNCR a2,"aVddVPU="
; DebugRegNCR a3,"aVddSOC="
; DebugRegNCR a4,"aVddARM="
; First compute number of steps needed. it takes around 3uS per step, and
; when speeding up we need to wait longenough for the volttage to rise
; before changing the speed.
; DebugRegNCR v2,"ov="
        and     a1, v2, #(&1f<<0)
; DebugRegNCR a1, "old a2 "
        sub     a1, a2, a1
; DebugRegNCR a1, "a2 dif "
        and     v3, v2, #(&1f<<9)
        mov     v3, v3, lsr #9
; DebugRegNCR v3, "old a3 "
        sub     v3, a3, v3
; DebugRegNCR v3, "a3 diff "
        cmp     v3, a1
        movgt   a1, v3
        and     v3, v2, #(&1f<<18)
        mov     v3, v3, lsr #18
; DebugRegNCR v3, "old a4 "
        sub     v3, a4, v3
; DebugRegNCR v3, "a4 diff "
        cmp     v3, a1
        movgt   a1, v3
; DebugRegNCR a1, "VoltSteps "
; a1 is now largest voltage change step count
        ldr     v3, =((&1f<<18)+(&1f<<9)+(&1f<<0))
; DebugRegNCR v2,"before="
; DebugRegNCR v3,"mask="
        bic     v2, v2, v3          ; clear the bits we're doing
        orr     a4, a4, a2, lsl #18 ; vddVPU + VddARM
        orr     a4, a4, a3, lsl #09 ; VddSOC
        and     a4, a4, v3          ; ensure we can only do those bits
        orr     a4, a4, v2
; DebugRegNCR a4,"nv="
; a4 = new regulator voltage, v4 = clock speed
; now a decision.. If we are reducing the frequency,
;  shift the voltages first then the frequency
; If speeding up, it is voltage first
        ldr     v3, [v1,#HW_CCM_ANALOG_PLL_ARM_ADDR]
        and     v3, v3, #&7f            ; get just the speed bits
        cmp     v4, v3                  ; compare new speed to old speed
        beq     SpeedDone               ; no change
                                        ; new speed slower.. change speed first
                                        ; new speed faster. change volts first
        strlt   a4, [v1, #HW_CCM_PMU_REG_CORE_ADDR]; write regulator voltages

; bypass the pll
        ldr     a3, CCM_Base
        ldr     v2, [a3,#CCM_CCSR_OFFSET]
        orr     v2, v2, #1<<1           ; bypass armpll source
        str     v2, [a3,#CCM_CCSR_OFFSET]
; program the pll speed
        orr     v3, v4, #1<<13          ; ensure enabled!!
        ldr     lr, [v1,#HW_CCM_ANALOG_PLL_ARM_ADDR]
        str     v3, [v1,#HW_CCM_ANALOG_PLL_ARM_ADDR]
; if slowest speed, needs armpodf div 2 not 1  (our choice)
        teq     v4, #CPUMinClkDivReg
        bic     v4, lr, #&80000000      ; clear locked bit remember old
        moveq   a2, #1                  ;
        movne   a2, #0
        str     a2, [a3, #CCM_CACRR_OFFSET] ; set arm podf
; now wait for lock again
1       ldr     v3, [v1,#HW_CCM_ANALOG_PLL_ARM_ADDR]
        tst     v3, #&80000000          ; pll locked bit
        beq     %bt1                    ; wait for it
; and back to using pll
        bic     v2, v2, #1<<1           ; reset to armpll source
        str     v2, [a3,#CCM_CCSR_OFFSET]
        str     v2, [a3]

; now check.. if we're slower, then need to write volts now
        bic     v3, v3, #&80000000      ; clear locked bit
        cmp     v3, v4                  ; compare new speed to old speed
                                        ; new speed slower.. change speed first
                                        ; new speed faster. change volts first
        ble     %ft2                    ; we're slowing.. no delay needed
        str     a4, [v1, #HW_CCM_PMU_REG_CORE_ADDR]; write regulator voltages
        add     v3, a1, a1
        adds    a1, v3, a1              ; 3uS per step (64 clk of 24MHz)
; beq %ft2
;       blne    HAL_CounterDelay        ; only delay if changing
; DebugTX "did upvolt delay "
; b %ft1
2
; DebugTX "no upvolt delay "
1       sub     v4, v4, #CPUMinClkDivReg
        strb    v4, [v5, #:INDEX:CPUClkCurSpeedIdx-:INDEX:CPUClkNewSpeedIdx]
; DebugReg v4, "Speed: "

SpeedDone
        mvn     v1, #0
        strb    v1, [v5]        ; flag not changing
        EXITS

; Replace speed table
; on entry, a1-> HAL_Device in HAL RAM
CPUClk_Override  ROUT
        EntryS
        MOV     a1, #CPUST_Format ; Return expected table format
        EXITS

;

        END
