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
;gic-disable.s
;mostly here to make sure pre-MMU GIC is init'd properly.

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Proc
        GET     Hdr:OSEntries

        GET     AllWinnerH3
        GET     Interrupts
        EXPORT  gic_clear

        AREA    |Asm$$Code|, CODE, READONLY, PIC

gic_clear
    Push "a1-a4, ip"
	MRC p15, 4, a1, c15, c0, 0  ;grab SCU base address.
	DSB ;These probably aren't needed. But I need to make 100% sure
	ISB ; a1 is correct.
	;a3 = temp for base + CPUIF or DIST
    ;below code poached from Interrupts.s
    ;Using it to ensure the GIC is squeaky clean before
    ;entering RISCOS_Start.
    ;GIC_DIST_Offset
    ;GIC_CPUIF_Offset
;Now we need to get the number of interrupts.
    ;gicd_typer mask 0x1f  2_11111 ITLinesNumber
    ADD a3, a1, #GIC_DIST_Offset
    LDR a4, [a1, #GICD_TYPER]
    AND a4, a4, #&1F ;ITLinesNumber mask. Ie # of supported IRQs.
;    ADD a4, a4, #1 ;I think I'm meant to add 1.
    ;now we have the number of interrupts in a1.
    ;start borrowed code (with minor alterations.)

        ; 1. disable Distributor Controller
;        LDR     a1, MPU_INTC_Log  ;Getting address direct from CoPro.
        ADD     a1, a1, #GICD_BASE
        MOV     a2, #0          ; disable ICDDCR
        STR     a2, [a1, #GICD_CTLR]

        ; 2. set all global interrupts to be level triggered, active low
        ADD     a3, a1, #GICD_ICFGR
        ADD     a3, a3, #8
        ;NOTE: View number of interrupts produced by query.
        ;Does not seem to be a clean multiple.
        MOV     a4, #INTERRUPT_MAX ;Already in a4 from CoPro.
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

        Pull    "a1-a4, ip"
        MOV     pc, lr

        END
