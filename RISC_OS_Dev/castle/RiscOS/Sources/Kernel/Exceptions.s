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
; > Exceptions

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       Exception veneers

 [ AMB_LazyMapIn
;  Instruction fetch abort pre-veneer, just to field possible lazy AMB aborts
;
PAbPreVeneer    ROUT
        Push    "r0-r7, lr"               ; wahey, we have an abort stack
        SUB     r0, lr_abort, #4          ; aborting address
        MOV     r2, #1
        BL      AMB_LazyFixUp             ; can trash r0-r7, returns NE status if claimed and fixed up
        PageTableSyncNE
        Pull    "r0-r7, lr", NE           ; restore regs and
        SUBNES  pc, lr_abort, #4          ; restart aborting instruction if fixed up
        LDR     lr, [sp, #8*4]            ; (not a lazy abort) restore lr
        LDR     r0, =ZeroPage+PAbHan      ; we want to jump to PAb handler, in abort mode
        LDR     r0, [r0]
        STR     r0, [sp, #8*4]
        Pull    "r0-r7, pc"
 ]

; Preliminary layout of abort indirection nodes

        ^       0
AI_Link #       4
AI_Low  #       4
AI_High #       4
AI_WS   #       4
AI_Addr #       4

        EXPORT DAbPreVeneer

DAbPreVeneer    ROUT

        SUB     r13_abort, r13_abort, #17*4     ; we use stacks, dontcherknow
        STMIA   r13_abort, {r0-r7}              ; save unbanked registers anyway
        STR     lr_abort, [r13_abort, #15*4]    ; save old PC, ie instruction address

        MyCLREX r0, r1                          ; Exclusive monitor is in unpredictable state "after taking a data abort", clear it here

  [ MEMM_Type = "VMSAv6"
        ; Fixup code for MVA-based cache/TLB ops, which can abort on ARMv7 if the specified MVA doesn't have a mapping.
        ; Must come before AMBControl, else things can go very wrong during OS_ChangeDynamicArea
        ; MVA cache ops have the form coproc=p15, CRn=c7, opc1=0, opc2=1
        ; MVA TLB ops have the form coproc=p15, CRn=c8, opc1=0, opc2=1
        ; Note that some non-MVA ops also follow the above rules - at the moment we make no attempt to filter those false-positives out
        ; This code is also written from the perspective of running on an ARMv7 CPU - behaviour under ARMv6 hasn't been checked!
        
        ; Also, as wrong as it seems, attempting to load the aborting instruction could trigger an abort (something wrong with the prefetch handler? or cache flushes not being done properly?)
        ; So this code must protect DFAR, DFSR, spsr_abort, and lr_abort from being clobbered

        ; We also need to be careful about how AMBControl will react to the abort:
        ; If DFAR and lr_abort both point to the same page, when we try loading the instruction (and it triggers an abort), AMBControl will map in the page
        ; So when control returns to us (and we determine that it wasn't an MVA op) AMBControl will be called again (for DFAR), see that the page is mapped in, and claim that it's a real abort instead of the lazy fixup that it really is
        ; (The workaround for that issue probably makes the DFAR, DFSR, spsr_abort, lr_abort saving irrelevant, but it's better to be safe than sorry)
        
        CMP     lr, #AplWorkMaxSize             ; Assume that MVA ops won't come from application space (cheap workaround for above-mentioned AMBControl issue)
        BLO     %FT10
        MRS     r1, SPSR
        TST     r1, #T32_bit
        BNE     %FT10                           ; We don't cope with Thumb ATM. Should really check for Jazelle too!
        MOV     r2, lr                          ; LR is already saved on the stack, but we can't load from it because any recursive abort won't have a clue what address we're trying to access.
        ; Protect DFAR, DFSR
        ARM_read_FAR r3
        ARM_read_FSR r4
        LDR     r0, [r2, #-8]                   ; Get aborting instruction
        MSR     SPSR_cxsf, r1                   ; un-clobber SPSR, FAR, FSR
        ARM_write_FAR r3
        ARM_write_FSR r4
        CMP     r0, #&F0000000
        BHS     %FT10                           ; Ignore cc=NV, which is MCR2 encoding
        BIC     r0, r0, #&F000000F              ; Mask out the uninteresting bits
        BIC     r0, r0, #&0000F000
        EOR     r0, r0, #&0E000000              ; Desired value, minus CRn
        EOR     r0, r0, #&00000F30
        CMP     r0,     #&00070000              ; CRn=c7?
        CMPNE   r0,     #&00080000              ; CRn=c8?
        BNE     %FT10                           ; It's not an MVA-based op
        MOV     lr_abort, r2                    ; un-clobber LR (doesn't need un-clobbering if it wasn't an MVA op)
        LDMIA   r13_abort, {r0-r4}              ; Restore the regs we intentionally clobbered
        ADD     r13_abort, r13_abort, #17*4
        SUBS    pc, lr_abort, #4                ; Resume execution at the next instruction
10
  ]
 
  [ AMB_LazyMapIn
        ARM_read_FAR r0                         ; aborting address
        MOV     r2, #0
        BL      AMB_LazyFixUp                   ; can trash r0-r7, returns NE status if claimed and fixed up
        PageTableSyncNE
        LDR     lr_abort, [r13_abort, #15*4]    ; restore lr_abort
        LDMIA   r13_abort, {r0-r7}              ; restore regs
        ADDNE   r13_abort, r13_abort, #17*4     ; if fixed up, restore r13_abort
        SUBNES  pc, lr_abort, #8                ; and restart aborting instruction
  ]

        MRS     r0, SPSR                        ; r0 = PSR when we aborted
        MRS     r1, CPSR                        ; r1 = CPSR
        ADD     r2, r13_abort, #8*4             ; r2 -> saved register bank for r8 onwards

        LDR     r4, =ZeroPage+Abort32_dumparea+3*4 ;use temp area (avoid overwriting main area for expected aborts)
        ARM_read_FAR r3
        STMIA   r4, {r0,r3,lr_abort}            ; dump 32-bit PSR, fault address, 32-bit PC

        MOV     r4, lr_abort                    ; move address of aborting instruction into an unbanked register
        BIC     r1, r1, #&1F                    ; knock out current mode bits
        ANDS    r3, r0, #&1F                    ; extract old mode bits (and test for USR26_mode (=0))
        TEQNE   r3, #USR32_mode                 ; if usr26 or usr32 then use ^ to store registers
  [ SASTMhatbroken
        STMEQIA r2!,{r8-r12}
        STMEQIA r2 ,{r13,r14}^
        SUBEQ   r2, r2, #5*4
  |
        STMEQIA r2, {r8-r14}^
  ]
        BEQ     %FT05

        ORR     r3, r3, r1                      ; and put in user's
        MSR     CPSR_c, r3                      ; switch to user's mode

        STMIA   r2, {r8-r14}                    ; save the banked registers

        MRS     r5, SPSR                        ; get the SPSR for the aborter's mode
        STR     r5, [r2, #8*4]                  ; and store away in the spare slot on the end
                                                ; (this is needed for LDM with PC and ^)
        ORR     r1, r1, #ABT32_mode
        MSR     CPSR_c, r1                      ; back to abort mode for the rest of this
05
        Push    "r0"                            ; save SPSR_abort

  [ SASTMhatbroken
        SUB     sp, sp, #3*4
        STMIA   sp, {r13,r14}^                  ; save USR bank in case STM ^, and also so we can corrupt them
        NOP
        STMDB   sp!, {r8-r12}
  |
        SUB     sp, sp, #8*4                    ; make room for r8_usr to r14_usr and PC
        STMIA   sp, {r8-r15}^                   ; save USR bank in case STM ^, and also so we can corrupt them
  ]

        SUB     r11, r2, #8*4                   ; r11 -> register bank
        STR     r4, [sp, #7*4]                  ; store aborter's PC in user register bank

; Call normal exception handler

90

; copy temp area to real area (we believe this is an unexpected data abort now)

        LDR     r0, =ZeroPage+Abort32_dumparea
        LDR     r1, [r0,#3*4]
        STR     r1, [r0]
        LDR     r1, [r0,#4*4]
        STR     r1, [r0,#4]
        LDR     r1, [r0,#5*4]
        STR     r1, [r0,#2*4]

        LDR     r0, =ZeroPage                           ; we're going to call abort handler
      [ ZeroPage = 0
        STR     r0, [r0, #CDASemaphore]                 ; so allow recovery if we were in CDA
      |
        MOV     r2, #0
        STR     r2, [r0, #CDASemaphore]                 ; so allow recovery if we were in CDA
      ]

        LDR     r0, [r0, #DAbHan]                       ; get address of data abort handler

        ADD     r2, r11, #8*4                   ; point r2 at 2nd half of main register bank
        LDMIA   sp, {r8-r14}^                   ; reload user bank registers
        NOP                                     ; don't access banked registers after LDM^
        ADD     sp, sp, #9*4                    ; junk user bank stack frame + saved SPSR

        MRS     r1, CPSR

        MRS     r6, SPSR                        ; get original SPSR, with aborter's original mode
        AND     r7, r6, #&0F
        TEQ     r7, #USR26_mode                 ; also matches USR32
        LDMEQIA r2, {r8-r14}^                   ; if user mode then just use ^ to reload registers
        NOP
        BEQ     %FT80

        ORR     r6, r6, #I32_bit                ; use aborter's flags and mode but set I
        BIC     r6, r6, #T32_bit                ; and don't set Thumb
        MSR     CPSR_c, r6                      ; switch to aborter's mode
        LDMIA   r2, {r8-r14}                    ; reload banked registers
        MSR     CPSR_c, r1                      ; switch back to ABT32

80
        STR     r0, [r13_abort, #16*4]          ; save handler address at top of stack
        LDR     lr_abort, [r13_abort, #15*4]    ; get abort address back in R14

        LDMIA   r13_abort, {r0-r7}              ; reload r0-r7
        ADD     r13_abort, r13_abort, #16*4     ; we use stacks, dontcherknow

        Pull    pc

        END
