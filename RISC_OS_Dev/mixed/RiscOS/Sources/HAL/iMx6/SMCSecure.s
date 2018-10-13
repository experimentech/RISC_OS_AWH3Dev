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
; Secure mode monitor required for turning on L2 cache in respose to SMC #0
; service call
;
;
; no GETs needed.. we are included using a GET
;
;        AREA    |Asm$$Code|, CODE, READONLY, PIC
;        EXPORT SecureInit

        ALIGN   32
SecureBase
        nop                      ; reset          not used
        nop                      ; undef          not used
        B       SMCCode
        nop                      ; prefetch       can be used
        nop                      ; data abort     can be used
        nop                      ; reserved
        nop                      ; irq            can be used
        nop                      ; fiq            can be used
        = "qqwweerrtt"
        ALIGN
; code run in secure mode as response to SMC #0 opcode
; runs in secure monitor mode, so can access L2 Cache controller enable bit
SMCCode
        ; assume a1 = enable/disable flag, a2 = PL310 address
        teq     a1, #0
        beq     %ft50

        ; L2 cache enable sequence:
        ; https://community.freescale.com/docs/DOC-94572
        ; First configure the cache
        ldr     a1, =&132
        str     a1, [a2, #PL310_REG1_TAG_RAM_CONTROL]
        str     a1, [a2, #PL310_REG1_DATA_RAM_CONTROL]
        ; N.B. not enabling double linefill due to errata 752271
        ; ldr     a1, =&40800000
        ; str     a1, [a1, #PL310_REG15_PREFETCH_CTRL]
        ; Invalidate
        ldr     a1, =&ffff
        str     a1, [a2, #PL310_REG7_INV_WAY]
        ; Wait for completion
10
        ldr     a1, [a2, #PL310_REG7_CACHE_SYNC]
        tst     a1, #1
        bne     %bt10
        ; Enable
        mov     a1, #1
        str     a1, [a2, #PL310_REG1_CONTROL] ; Enable cache
        ; Wait for completion
20
        ldr     a1, [a2, #PL310_REG7_CACHE_SYNC]
        tst     a1, #1
        bne     %bt20
        movs    pc, lr           ; exit, restoring state

50
        ; cache disable sequence
        ; Clean
        ldr     a1, =&ffff
        str     a1, [a2, #PL310_REG7_CLEAN_WAY]
        ; Wait for completion
60
        ldr     a1, [a2, #PL310_REG7_CLEAN_WAY]
        teq     a1, #0
        bne     %bt60
        ; Sync
        mov     a1, #0
        str     a1, [a2, #PL310_REG7_CACHE_SYNC]
70
        ldr     a1, [a2, #PL310_REG7_CACHE_SYNC]
        tst     a1, #1
        bne     %bt70
        ; Disable
        mov     a1, #0
        str     a1, [a2, #PL310_REG1_CONTROL]
        DSB     SY
        movs    pc, lr           ; exit, restoring state

; code to initialise this all and set it going
; this is set up before the MMU is on, we'll avoid using it until afterwards
;
; ****** ASSUMPTION******
;  it is assumed that the HAL starts on a megabyte boundary, and does not exceed
;  256 k in length.
;  it is also assumed that the logical HAL start address is &fc000000
;   (this address is defined in the components file, and KernelWS header file
;   in kernel)
SecureInit
        MRS     r1, CPSR          ; remember our mode
        MSR     CPSR_c, #F32_bit+I32_bit+(MON32_mode);   can we do this?
        adr     r0,SecureBase
        bic     r0,r0,#&03fc0000   ; clear any bits that are not needed
        orr     r0,r0,#&fc000000   ; bear in mind that we are at top of ram now
        MCR     p15,0,r0,c12,c0,1  ; set the Mon Mode vector base to us here
        MSR     CPSR_c, r1         ; and will be mapped to FC000000 and up
        mov     pc, lr

        END
