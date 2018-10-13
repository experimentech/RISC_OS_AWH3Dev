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

; Using the DMA controller to clear RAM is much faster than doing it with the CPU (with the cache/write buffer off, at least)
                 GBLL Use_DMA_Clear
Use_DMA_Clear    SETL {FALSE}

init_ram
        ; nothing to do here: SDCard loader has already done it

        ; Done!
        MOV     pc, lr



; a1 <= Highest physical address in RAM +1
get_end_of_ram
; do a dumb check ATM .. we know we can have
; DDR3 ram starts at 0x10000000 and continues upwards
; boot loader enables ram access up to 0x8effffff, so it is OK to poke beyond
; the end of RAM
; we'll assume we have ram at least as far as 0x17800000, as that is where ;
; we're currently running.
; check it is there at 0x10000000 intervals, etc, till not working
; set up data abort handler to point here
        mov     v1, lr
        adrl    a4, dabortloc              ; current data abort vector address stored here
        adr     a1, RAMDataAbortHandler
;        ldr     a2, [a4]
        str     a1, [a4]

;    DebugReg lr, " dabort addr "
;    DebugReg a2,"  was "
;    DebugReg a1,"  now "
;    adr     a2, RAMDataAbortHandler
;    DebugReg a2,"  should be "
;    MRC     p15,0,a1,c12,c0           ; get the vector base to us just here
;    DebugReg a1,"  vectors at "
;
        LDR     a1, =&10000000 ; ram start
        LDR     a3, =&10000000    ; 1/4gb
        ldr     a4, =&55aaaa55
filler
; DebugReg a1," Filling "
        STR     a4, [a1],a3                ; base
        add     a4,a4,a3
        teq     a1, #MaxCheckRAMBoundary   ; as far as we want to go
        bne     filler

        LDR     a1, =&10000000 ; ram start
        LDR     a3, =&10000000    ; 1/4gb
        ldr     a4, =&55aaaa55

ramstillOK
;  DebugReg a1," Checking "
        teq     a1, #MaxCheckRAMBoundary    ; as far as we want to go
        addeq   a1,a1,a3
        beq     endreached
        ldr     a2, [a1], a3            ; can we read what we wrote?
        teq     a4,a2
        add     a4,a4,a3
        beq     ramstillOK
endreached
        B       backfromthere

; recover the a1 value at abort, return to svce mode,
; restore original handler, and return to location in v1
RAMDataAbortHandler
        LDR     a2, =&10000000 ; ram start
        ldr     a2, [a2]       ; reread valid loc to stop re-aborting (!!!???)
        MSR     CPSR_c,#F32_bit+I32_bit+SVC32_mode
        mov     a2, a2
;  DebugReg a1," via data abort "

backfromthere
        adrl    a2, data_abort
        adrl    a4, dabortloc
        str     a2, [a4]

        sub     a1, a1, a3
;  DebugReg a1," gotto "
        mov     pc, v1
;


 [ ClearRAM
; clears RAM manually, in 128 byte chunks
clear_ram ROUT
        ; Clear a1 bytes starting from a2
        ; Can clobber all regs except v4, v8 & sb
   [ Use_DMA_Clear
      [ Debug
        MOV     v5, lr
        DebugReg a2, "clear_ram base "
        DebugReg a1, "size "
        SUB     a3, a1, #4
        STR     pc, [a2, a3]
      ]
        LDR     a3, =SDMA_BASE_ADDR
        ; Reset SDMA
        LDR     a4, [a3, #SDMAARM_RESET]
        ORR     a4, a4, #2
        STR     a4, [a3, #SDMAARM_RESET]
        LDR     a4, [a3, #SDMAARM_RESET]
        ORR     a4, a4, #1
        STR     a4, [a3, #SDMAARM_RESET]
10
        LDR     a4, [a3, #SDMAARM_RESET]
        TST     a4, #1
        BNE     %BT10
        ; Configure
        LDR     a4, [a3, #SDMAARM_CONFIG]
        BIC     a4, a4, #16
        STR     a4, [a3, #SDMAARM_CONFIG]
        LDR     a4, [a3, #SDMAARM_CHN0ADDR]
        ORR     a4, a4, #1<<14
        STR     a4, [a3, #SDMAARM_CHN0ADDR]
        ; Clear channel enable matrix
        MOV     a4, #0
        MOV     v1, #48
        ADD     v2, a3, #SDMAARM_CHNENBL0
20
        SUBS    v1, v1, #1
        STR     a4, [v2, v1, LSL #2]
        BNE     %BT20
        ; Set channels 0 & 1 to be controlled by CPU
        MOV     a4, #0
        STR     a4, [a3, #SDMAARM_HOSTOVR]
        MOV     a4, #3
        STR     a4, [a3, #SDMAARM_EVTOVR]
        ; Use a2 as scratch space for the control blocks
        STR     a2, [a3, #SDMAARM_MC0PTR]
        MOV     a4, #0
        MOV     v1, #4+6+32 ; 4 words for control block, 6 words for buffer descriptors, 32 words for channel context
30
        SUBS    v1, v1, #1
        STR     a4, [a2, v1, LSL #2]
        BNE     %BT30
        ADD     v1, a2, #16
        STR     v1, [a2, #0] ; currentBDptr
        STR     v1, [a2, #4] ; baseBDptr
        ; Set up the block descriptors
        ; First descriptor uploads our scripts
        LDR     a4, =C0_SET_PM+((sdma_scriptend-sdma_scriptbase) >> 1)+SDMA_BD_DONE+SDMA_BD_CONT
        ADRL    v2, sdma_scriptbase
        LDR     v3, =6144
        STMIA   v1!, {a4,v2,v3}
        ; Second descriptor loads a context into channel 1
        LDR     a4, =C0_SETCTX+(1<<27)+32+SDMA_BD_DONE
        ADD     v2, v1, #12
        MOV     v3, #0
        STMIA   v1!, {a4,v2,v3}
        ; Now the channel 1 context which will cause the channel to run the script
        LDR     a4, =((sdma_rectfill-sdma_scriptbase) >> 1)+&1800
        STR     a4, [v1], #8 ; Set PC
        STR     a1, [v1, #4] ; R1 = rect width
        MOV     a4, #1
        STR     a4, [v1, #8] ; R2 = rect height
        STR     a2, [v1, #12] ; R3 = dest addr
        ; Run channel 0 to load everything up
        DebugTX "running..."
        MOV     a4, #7
        STR     a4, [a3, #SDMAARM_SDMA_CHNPRI0]
        MOV     a4, #1
        STR     a4, [a3, #SDMAARM_HSTART]
        ; Wait for completion
40
        LDR     a4, [a3, #SDMAARM_STOP_STAT]
        TST     a4, #1
        BNE     %BT40
        DebugTX "done ch0"
        ; Mark channel as free again
        MOV     a4, #0
        STR     a4, [a3, #SDMAARM_SDMA_CHNPRI0]
        ; Run channel 1 to run the RAM clear script
        MOV     a4, #7
        STR     a4, [a3, #SDMAARM_SDMA_CHNPRI0+4]
        MOV     a4, #2
        STR     a4, [a3, #SDMAARM_HSTART]
        ; Wait for completion
40
        LDR     a4, [a3, #SDMAARM_STOP_STAT]
        TST     a4, #2
        BNE     %BT40
        ; Mark channel as free again
        MOV     a4, #0
        STR     a4, [a3, #SDMAARM_SDMA_CHNPRI0+4]
        ; And that's it.
        DebugTX "done ch1"
      [ Debug
        LDR     a3, [a2]
        DebugReg a3, "word0 "
        SUB     a3, a1, #4
        LDR     a3, [a2, a3]
        DebugReg a3, "word1 "
        MOV     pc, v5
      |
        MOV     pc, lr
      ]
   |
        MOV     a3, #0
        MOV     a4, #0
        MOV     v1, #0
        MOV     v2, #0
        MOV     v3, #0
        MOV     v5, #0
        MOV     sp, #0
        MOV     ip, #0
20
        STMIA   a2!,{a3,a4,v1,v2,v3,v5,sp,ip} ; 32 bytes
        STMIA   a2!,{a3,a4,v1,v2,v3,v5,sp,ip} ; 64 bytes
        STMIA   a2!,{a3,a4,v1,v2,v3,v5,sp,ip} ; 96 bytes
        STMIA   a2!,{a3,a4,v1,v2,v3,v5,sp,ip} ; 128 bytes
        SUBS    a1, a1, #128
        BGT     %BT20
        MOV     pc, lr
   ] ; Use_DMA_Clear
 ] ; ClearRAM

 [ ClearRAM :LAND: Use_DMA_Clear
        GET      SDMAScripts.s
 ]

        END
