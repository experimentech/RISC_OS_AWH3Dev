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
        GET     Hdr:HALSize.<HALSize>
        GET     Hdr:ImageSize.<ImageSize>

        GET     Hdr:MEMM.VMSAv6

        GET     Hdr:Proc
        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     Hdr:PL310

        GET     hdr.iMx6q
        GET     hdr.iMx6qMemMap
        GET     hdr.iMx6qReg
        GET     hdr.iMx6qIRQs
        GET     hdr.StaticWS
        GET     hdr.UART
        GET     hdr.Post
        GET     hdr.SDRC
        GET     hdr.Copro15ops
        GET     hdr.GPIO

; start of image now in LowBoot, so it has the ROMStart directive
; hence this is just Asm$$Code
;        AREA    |Asm$$Code|, CODE, READONLY, PIC

        AREA    |!!!ROMStart|, CODE, READONLY, PIC

        GET     s.LowBoot

        IMPORT  rom_checkedout_ok
        IMPORT  SoftCMOS
        EXPORT  HAL_Base
        EXPORT  HAL_WsBase
        IMPORT  HAL_UARTStartUp
        IMPORT  HAL_UARTLineStatus
        IMPORT  HAL_UARTTransmitByte
        IMPORT  HAL_DebugTX
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
 ]

; Using the DMA controller to relocate the ROM image is much faster than doing it with the CPU
             GBLL Use_DMA_Copy
Use_DMA_Copy SETL {FALSE};{TRUE}

        MACRO
        CallOSM $entry, $reg
        LDR     ip, [v8, #$entry*4]
        MOV     lr, pc
        ADD     pc, v8, ip
        MEND


; iMx6 boot loader will load so HAL_Base is aligned to 4096 boundary
; We also need to ensure HAL itself is 64/96/128k long, hence prepend the loadlow stuff
        ENTRY
HAL_Base
reset   B       restart
undef   B       undefined_instr
swi     B       swi_instr
pabort  ldr     pc, dabortloc  ;B       prefetch_abort
dabort  ldr     pc, dabortloc  ;B       data_abort
irq     B       interrupt
fiq     B       fast_interrupt

;        ASSERT  . - HAL_Base < 0x60
;        %       0x60 - (. - HAL_Base)
;ROMsize
;        DCD     0                       ; patched in by build system
        ALIGN   256                      ;
dabortloc
        DCD      0;  here we store the data_abort address in early HAL time

        ALIGN   4096

end_stack
        EXPORT  HAL_WsBase
HAL_WsBase
        %       HAL_WsSize

        LTORG

        ; exception handlers just for use during HAL init,
        ;   in case something goes wrong

interrupt
        B       .

fast_interrupt
        B       .

swi_instr
        B       .

prefetch_abort
        B       .

data_abort               ; only truly get here if an abort for ram checking
        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode
        ADRL    sb,HAL_WsBase
        ADRL    R13,end_stack
        mov    a2,lr
;        DebugReg a2,"DataAbort lr "
;        DebugReg a1,"DataAbort a1 "
        mov    a1,pc
;        DebugReg a1,"DataAbort our pc "
        B       .

undefined_instr
        B       .

; ------------------------------------------------------------------------------
; Perform some Cortex-A9 specific CPU setup
; Then start looking for RAM
; In: sb = board config ptr
restart
;         BL      SecureInit
        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode
 [ HALDebug
         adrl lr, dabortloc
         stmdb lr,{r0-r13}     ; store re-entry dump registers on entry
 ]
         ; ENSURE all caches turned off
;        mrc     p15, 0, r0, c1, c0, 0    ; read CP15 register 1 into r0
;        bic     r0, r0, #(0x1  <<2)      ; disable D Cache
;        bic     r0, r0, #(0x1  <<12)     ; disable I Cache
;        bic     r0, r0, #(0x1  <<13)     ; Vectors low permit vector remapping
;        mcr     p15, 0, r0, c1, c0, 0    ; write CP15 register 1
;        ; Sync cache
;        MOV     a1, #0
;        MCR     p15, 0, a1, c7, c11, 1 ; Clean DCache by VA to PoU
;        myDSB ; wait for clean to complete
;        MCR     p15, 0, a1, c7, c5, 1 ; invalidate ICache entry (to PoC)
;        MCR     p15, 0, a1, c7, c5, 6 ; invalidate entire BTC
;        myDSB ; wait for cache invalidation to complete
;        myISB ; wait for BTC invalidation to complete?


        ADRL    v1, HAL_Base + OSROM_HALSize -IVTLoaderSize; v1->RISC OS image

        LDR     v8, [v1, #OSHdr_Entries]
        ADD     v8, v8, v1                      ; v8 -> RISC OS entry table

        ; Ensure CPU is set up
        MOV     a1, #0
        CallOSM OS_InitARM

        ; Enable the SCU
        mrc     p15, 4, r0, c15, c0, 0  ; Read periph base address
        ldr     r1, [r0, #0]            ; Read the SCU Control Register
        orr     r1, r1, #1              ; Set bit 0 (The Enable bit)
        str     r1, [r0, #0]            ; Write back modifed value

        ; Enable SMP mode for this core
        BL      smp_enable

        ; initialise abort handler for use in ram check
        adr     r0,data_abort
        adrl    lr,dabortloc
        str     r0,[lr]

        ADRL    sb,HAL_WsBase
        ADRL    R13,end_stack
        ADRL    r0,HAL_Base
        MCR     p15,0,r0,c12,c0           ; set the vector base to us just here

; enable module access
        ldr     a2, = AIPS1_BASE_ADDR
        ldr     a3, = AIPS2_BASE_ADDR
        ldr     a4, = 0x77777777                ; non secure supervisor write
        str     a4, [a2]
        str     a4, [a2, #4]
        str     a4, [a3]
        str     a4, [a3, #4]
        add     a2, a2, #AIPS_OPACR0_7_OFFSET
        add     a3, a3, #AIPS_OPACR0_7_OFFSET
        mov     a4, #0                         ; enable non secure write access
        str     a4, [a2],#4                    ; to all peripherals
        str     a4, [a2],#4                    ; to all peripherals
        str     a4, [a2],#4                    ; to all peripherals
        str     a4, [a2],#4                    ; to all peripherals
        str     a4, [a2],#4                    ; to all peripherals
        str     a4, [a3],#4
        str     a4, [a3],#4
        str     a4, [a3],#4
        str     a4, [a3],#4
        str     a4, [a3],#4
;
        ldr     a2, =(CCM_BASE_ADDR+CCM_CCGR0_OFFSET)
        ldr     a4, =0xffffffff               ; turn on all clocks
        str     a4, [a2],#4
        str     a4, [a2],#4
        str     a4, [a2],#4
        str     a4, [a2],#4
        str     a4, [a2],#4
        str     a4, [a2],#4
        str     a4, [a2],#4
        str     a4, [a2],#4

; Initialise a few pertinant physical addresses for later use
        ldr     a2,=CCM_BASE_ADDR
        str     a2, CCM_Base
        ldr     a2,=IOMUXC_BASE_ADDR
        str     a2, IOMUXC_Base
        ldr     a2,=UART1_BaseAddr
        ADRL    a4, UART_Base
        str     a2, [a4], #4
        ldr     a2,=UART2_BaseAddr
        str     a2, [a4], #4
        ldr     a2,=UART3_BaseAddr
        str     a2, [a4], #4
        ldr     a2,=UART4_BaseAddr
        str     a2, [a4], #4
        ldr     a2,=UART5_BaseAddr
        mov     a4, #UART_DebugNum
        ADRL    a2, UART_Base
        ldr     a2, [a2, a4, lsl #2]    ; get required debug uart address
        str     a2, DebugUART
        mov     a1, a4                  ; debug uart number, starting 0
        bl      HAL_UARTStartUp
        DebugTX "HAL is starting up"


        ADRL    r4, reset
        STR     r4, MMUOffBaseAddr
        LDR     r4,=IO_Base
        STR     r4,PeriBase
 [ HALDebug
        ; diagnostic printout in case we had to do a MMU off jump to
        ; physical ROM start to capture register state
        MRS     r0,CPSR
        DebugReg r0,"CPSR="
        MRC     p15, 0, r0, c12, c0, 0
        DebugReg r0,"VecBase="
        MRC     p15, 0, r0, c12, c0, 1
        DebugReg r0,"MonVecBase="
        ldr     a2, DebugUART
        DebugReg a2," DebugUart_Base "

        adrl    v5, dabortloc
        sub     v5, v5, #4
        DebugReg v5," store top at "
        ldr     a2, [v5], #-4
        DebugReg a2," r13= "
        ldr     a2, [v5], #-4
        DebugReg a2," r12= "
        ldr     a2, [v5], #-4
        DebugReg a2," r11= "
        ldr     a2, [v5], #-4
        DebugReg a2," r10= "
        ldr     a2, [v5], #-4
        DebugReg a2," r9 = "
        ldr     a2, [v5], #-4
        DebugReg a2," r8 = "
        ldr     a2, [v5], #-4
        DebugReg a2," r7 = "
        ldr     a2, [v5], #-4
        DebugReg a2," r6 = "
        ldr     a2, [v5], #-4
        DebugReg a2," r5 = "
        ldr     a2, [v5], #-4
        DebugReg a2," r4 = "
        ldr     a2, [v5], #-4
        DebugReg a2," r3 = "
        ldr     a2, [v5], #-4
        DebugReg a2," r2 = "
        ldr     a2, [v5], #-4
        DebugReg a2," r1 = "
        ldr     a2, [v5], #-4
        DebugReg a2," r0 = "
 ]
        ; Initialise RAM
        BL      init_ram

        ; The Initial load of riscos code is such that HAL_Base is at
        ; 0x17800000 in RAM. it is used by RISC OS's init code,
        ; and also contains the stack
        ; To keep things simple and safe, we'll relocate the HAL and OS image
        ; to the top end of RAM
        ; this code has been written so that it should work if running from ROM

; The loader image on disc has a copy of the CMOS loaded at &200 before
; the base of the HAL. This is in CMOS Physical format, whereas the  HAL
; internally is mapped to logical addressing for ease of preloading
; so map as follows:
; Physical    Logical     note
; 00-1f       f0-ff       not used
; 10-3e       c0-ee       top part
; 3f          ef          cmos checksum
; 40-ff       00-bf       bottom part
; checksum = sum of all bytes from 10-ff other than byte at 3f
; this sum + 1 = value at 3f
        ; first validate the cmos in rom
        adrl    v1, HAL_Base - &1f0
        mov     v2, #&ef
        mov     v3, #1
cmosckloop
        ldrb    v4, [v1, v2]
        add     v3, v3, v4
        subs    v2, v2, #1
        bge     cmosckloop
        ldrb    v4, [v1, #&2f]          ; actual &3f from base
;       DebugReg v4," v4 = "
;       DebugReg v3," v3 = "
        sub     v3, v3, v4, lsl #1
        tst     v3, #&ff                ; byte match?
        bne     nocmoscopy              ; checksum looks bad
        ; OK cmos is usable. copy into hal
;       DebugReg v3," cksum worked "
        adrl    v3, SoftCMOS + &c0
        adrl    v1, HAL_Base - &1f0
        mov     v2, #&2c
1       ldr     v4, [v1, v2]
        str     v4, [v3, v2]
        subs    v2, v2, #4
        bge     %bt1
        adrl    v3, SoftCMOS + &00
        adrl    v1, HAL_Base - &1c0
        mov     v2, #&bc
2       ldr     v4, [v1, v2]
        str     v4, [v3, v2]
        subs    v2, v2, #4
        bge     %bt2

nocmoscopy

        ; First, identify the top end of RAM
        ; Then check if we intersect it
        ; If we do, first copy ourselves down
        ; Then copy ourselves up

; [ Use_DMA_Copy
;        ; We'll use DMA for extra speed, so start by initialising the DMA controller
;        LDR     v5, =L4_sDMA
;;       MOV     v1, #2          ; this bit is reserved on OMAP4430 (!?)
;;       STR     v1, [v5, #DMA4_OCP_SYSCONFIG]
;5
;        LDR     v1, [v5, #DMA4_SYSSTATUS]
;        TST     v1, #DMA4_SYSSTATUS_RESETDONE
;        BEQ     %BT5
;        ; Set a sensible FIFO budget (as per SDMACReset)
;        LDR     a2, =((1 << DMA4_GCR_ARBITRAION_RATE_SHIFT) + 128)
;        STR     a2, [v5, #DMA4_GCR]
;        ; Configure channel 0 for the right settings
;        ADD     v5, v5, #DMA4_i
;        MOV     v1, #0          ; Disable channel linking
;        STR     v1, [v5, #DMA4_CLNK_CTRLi]
;        MOV     v1, #DMA4_CICR_LAST_IE
;        STR     v1, [v5, #DMA4_CICRi] ; frame end interrupt enabled
;        ; 32bit elements, 64 byte bursts with packing, last write non-posted
;        LDR     v1, =(DMA4_CSDP_DATA_TYPE_32BIT + DMA4_CSDP_SRC_PACKED + DMA4_CSDP_DST_BURST_EN_64B + DMA4_CSDP_DST_PACKED + DMA4_CSDP_DST_BURST_EN_64B + DMA4_CSDP_WRITE_MODE_LAST_WRNP)
;        STR     v1, [v5, #DMA4_CSDPi]
;        MOV     v1, #1
;        STR     v1, [v5, #DMA4_CFNi] ; 1 frame
; ]
relocate_code
        BL      get_end_of_ram    ; needs a couple of spaces on sp

;        DebugReg a1,"End of RAM: "

        ; How big are we?
        ADRL    v1, HAL_Base  + OSROM_HALSize- IVTLoaderSize; -iMx6LoadLowSize
;        DebugReg v1,"start of kernel ATM: "
        LDR     v2, [v1, #OSHdr_ImageSize]
        LDR     v3, [v1, #OSHdr_Flags]
        TST     v3, #OSHdrFlag_SupportsCompression
        LDRNE   v3, [v1, #OSHdr_CompressedSize]
        MOVEQ   v3, v2
        SUB     v1, v1, #OSROM_HALSize ; Start of HAL
        ADD     v2, v2, #OSROM_HALSize ; Size of HAL+OS
        ADD     v3, v3, #OSROM_HALSize ; Size of compressed HAL+OS
        ADD     v3, v1, v3 ; End of OS
        MOV     v4, a1 ; End of RAM
        SUB     v5, v4, v2 ; New start address of HAL
;        DebugReg v1, "OurStart "
;        DebugReg v5, "NewRamStart "
;        DebugReg v4, "END of RAM "
;        DebugReg v2, "Size of HAL & OS "
;        DebugReg v3, "end of code srce "
        CMP     v1, v5

        BEQ     %FT10   ; No copy needed
        CMP     v1, v4
        BHI     %FT20   ; We're in some ROM above RAM. OK to continue with copy.
        CMP     v3, v5
        BLS     %FT20   ; We're in some ROM/RAM below our copy destination.
                        ; OK to continue with copy.
                        ; Else we currently overlap the area we
                        ; want to copy ourselves into.
        SUB     v5, v5, v2, lsl #1 ; Copy the HAL+OS to just before itself
                                   ; (2 rom's worth to escape overlap)
;        DebugReg v5, "It overlapped .. temp copy to "

        ; copy code below where it is now
        bl       CopyRom
        ; Invalidate I-cache, branch predictors
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c5, 0
        MCR     p15, 0, a1, c7, c5, 6
        myDSB ; Wait for I-cache invalidation to complete
        myISB ; Wait for branch predictor invalidation to complete?
        ; Jump to our new copy
        ADR     a1, %FT100  ; continue from:
        SUB     a2, v5, v1
        ADD     a1, a1, a2 ; relocate our branch target
        ADD     v8, v8, a2 ; Update OS entry table ptr
;        DebugReg v8, "OS Entry table ptr "
        MOV     pc, a1
100

        ADRL    sb,HAL_WsBase
        ADRL    R13,end_stack
        ADRL    r0,HAL_Base
        MCR     p15,0,r0,c12,c0           ; set the vector base to us just here
        ; restore intended pointers
        mov     v1, v5
        add     v5, v5, v2, lsl #1 ; restore original destination
;        DebugReg v1, "OurStart "
;        DebugReg v5, "NewRamStart "
;        DebugReg v4, "END of RAM "
;        DebugReg v2, "Size of HAL & OS "
;        DebugReg v3, "end of code srce "

        ; now put it where it needs to be
20      bl       CopyRom
        ; Invalidate I-cache, branch predictors
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c5, 0
        MCR     p15, 0, a1, c7, c5, 6
        myDSB ; Wait for I-cache invalidation to complete
        myISB ; Wait for branch predictor invalidation to complete?
        ; Jump to our new copy
        ADR     a1, %FT102  ; continue from:
        SUB     a2, v5, v1
        ADD     a1, a1, a2 ; relocate our branch target
        ADD     v8, v8, a2 ; Update OS entry table ptr
        MOV     pc, a1
102
        ADRL    sb,HAL_WsBase
        ADRL    R13,end_stack
        ADRL    r0,HAL_Base-IVTLoaderSize
        MCR     p15,0,r0,c12,c0 ; set the vector base to us just here
10
        ; Copy completed OK.
        ; v2 = size of HAL+OS
        ; v4 = end of OS/RAM
        ; v5 = start of HAL
        ; v8 = OS entry table ptr
;        DebugReg v2 , "size of HAL+OS "
;        DebugReg v4 , "end of OS/RAM "
;        DebugReg v5 , "start of HAL "
;        DebugReg v8 , "OS entry table ptr "
;        DebugReg pc, "I'm running at "
;        DebugReg a1, "ROM relocated @ "

;
        ; Clear RAM up to v5
        mov     a2, #&10000000  ; ram start
        SUB     a1, v5 , a2     ; compensate for ram start point
;        DebugReg v5 , "Clearing RAM up to "
;        DebugReg a2, "starting at "
      [ ClearRAM
        BL      clear_ram
      ]
        ADRL    R13,end_stack   ; restore the stack as ram clear corrupts the sp
;        DebugTX " RAM cleared "
;        DebugReg a2," clear got to "
;        DebugTimeNoMMU a1, "RAM cleared @ "

        ; enable NEON for secure and non secure full access
        mrc    p15,0,r0,c1,c0,2  ; Read CPACR into r0
        orr    r0, r0, #(3<<20)  ; OR in User and Privileged access for CP10
        orr    r0,r0,#(3<<22)    ; OR in User and Privileged access for CP11
        bic    r0, r0, #(3<<30)  ; Clear ASEDIS/D32DIS if set
        mcr    p15,0,r0,c1,c0,2  ; Store new access permissions into CPACR
        mrc    p15,0,r0,c1,c1,2  ; Read NSACR into r0
        orr    r0, r0, #(1<<10)  ; enable access for CP10
        orr    r0,r0,#(1<<11)    ; enable access for CP11
        bic    r0, r0, #(3<<14)  ; Clear NSASEDIS/NSD32DIS if set
        mcr    p15,0,r0,c1,c1,2  ; Store new access permissions into NSPACR
        myISB                    ; Ensure side-effect of CPACR is visible
        mov    r0,#(1<<30)       ; FPEXC (bit 30) set in r0 and SIMD extensions
        ARM
        vmsr   fpexc,r0          ; enable VFP
        CODE32
;        DebugTX " NEON vfp turned on "

;        FLTS     f0,v7
;        DebugTX " 111 "
;        FLTS     f2,v8
;        DebugTX " 1111 "
;        FDVS     f3,f0,f2
;        DebugTX " 11111 "
;        MVFD     f0,f3
;        DebugTX " 111111 "
;        ADFD     f1,f0,#0.5
;        DebugTX " 1111111 "
;        FIXZ     a2,f1
;        DebugTX " 11111111 "


; TODO - NEON seems to be on by default, need to work out how to turn it off before I can test code to turn it on!
;       ; Enable power to the NEON unit, if present
;       LDR     a1, =&4800244C ; 'control OMAP status register'
;       LDR     a1, [a1]
;       TST     a1, #1<<4
;       BNE     %FT10
;;      ; NEON is available, make sure it's turned on
;       ; Enable CP10/CP11 access
;       MRC     p15, 0, a1, c1, c0, 2
;       ORR     a1, a1, #&F<<20
;       MCR     p15, 0, a1, c1, c0, 2
;       DCI     &F57FF06F ; ISB {SY}
;       ; Now enable the unit
;       MOV     a1, #1<<30 ; EN bit
;       DCI     &EEE80A10 ; VMSR FPEXC, a1

; SOME user code in the wild PRESUMES the ROM will start on a megabyte boundary
; so.. Include the bit of hal space used by the loader, and fabricate jumps
; from base of this code to real hal base... in case anything actually
; needs this programatically
; this then keeps the space before kernel start a multiple of 64k as
; historically it always has been.
        ldr     a1, =IVTLoaderSize
        sub     a1, a1, #8
        mov     a1, a1, lsr #2
        orr     a1, a1, #&ea << 24      ; create a branch instruction to past
        str     a1, [v5, #00]           ; populate vectors with jump to
        str     a1, [v5, #04]           ; relevant vector at start of real HAL
        str     a1, [v5, #08]           ; there are 7 vectors currently
        str     a1, [v5, #12]           ; populated.
        str     a1, [v5, #16]
        str     a1, [v5, #20]
        str     a1, [v5, #24]
BaseAdjustDone
; initialise the monitor mode handler now we're in our final hardware adderess
        bl      SecureInit
        MRC     p15,0,r0,c12,c0,1    ; get the Mon Mode vector base to us here
;        DebugReg r0," monvecbase "

        B       rom_checkedout_ok

; does not use stack
;
CopyRom
        mov     v3, lr                     ; preserve return address
;       DebugReg "sb", sb
 [ Use_DMA_Copy
        ; Transfer everything in one DMA frame;
        ; this gives us a max ROM size of 64MB-4 bytes
        LDR     a3, =(L4_sDMA + DMA4_i)
        LDR     a1, [a3, #DMA4_CSRi]
        STR     a1, [a3, #DMA4_CSRi] ; Clear status register
        MOV     a1, lr, LSR #2
        STR     a1, [a3, #DMA4_CENi]
        STR     v5, [a3, #DMA4_CDSAi]
        STR     v1, [a3, #DMA4_CSSAi]
        ; Enable channel with post-increment source & destination, prefetch
        LDR     a1, =(DMA4_CCR_ENABLE + DMA4_CCR_SRC_AMODE_POST_INC + DMA4_CCR_DST_AMODE_POST_INC + DMA4_CCR_PREFETCH)
        STR     a1, [a3, #DMA4_CCRi]
        ; Wait for copy to complete
30
        LDR     a1, [a3, #DMA4_CSRi]
        TST     a1, #DMA4_CICR_LAST_IE
        BEQ     %BT30
        ; Make doubly sure that it's finished by checking WR_ACTIVE/RD_ACTIVE
40
        LDR     a1, [a3, #DMA4_CCRi]
        TST     a1, #(DMA4_CCR_RD_ACTIVE + DMA4_CCR_WR_ACTIVE)
        BNE     %BT40
 |
        MOV     a1, v5
        MOV     a2, v1 ; Copy source
        MOV     a3, v2
;        DebugReg a2, "ROM Image copy from "
;        DebugReg a1, "copy to "
;        DebugReg a3, "size "
30
        LDR     a4, [a2], #4
        SUBS    a3, a3, #4
        STR     a4, [a1], #4
        BGT     %BT30
 ]
 [ HALDebug
        bl      DebugHALPrint
        DCB     "rom copied",10,0
        ALIGN
 ]
        mov     pc, v3

smp_enable
        ; Invalidate the SCU tag RAMs for this core
        mrc     p15, 0, r0, c0, c0, 5
        and     r0, r0, #3              ; Get CPU number
        mov     r0, r0, lsl #2          ; Convert into bit offset (four bits per core)
        mov     r1, #15
        mov     r1, r1, lsl r0          ; Set up way value
        mrc     p15, 4, r2, c15, c0, 0  ; Read periph base address
        str     r1, [r2, #&0c]          ; Write to SCU Invalidate register
        ; Enable SMP mode
        mrc     p15, 0, r0, c1, c0, 1   ; Read ACTLR
        orr     r0, r0, #&40            ; Set bit 6
        mcr     p15, 0, r0, c1, c0, 1   ; Write ACTLR
        mov     pc, lr

        LTORG
        GET     SMCSecure.s
        GET     RAM.s
        LTORG

        END
