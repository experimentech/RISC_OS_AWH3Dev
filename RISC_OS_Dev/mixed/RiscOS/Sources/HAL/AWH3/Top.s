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

        GET     Hdr:MEMM.VMSAv6

        GET     Hdr:Proc
        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     Hdr:VIDCList


        GET     hdr.StaticWS
        GET     hdr.UART
;        GET     hdr.Post
;        GET     hdr.SDRC
;        GET     hdr.GPIO
        GET	hdr.board
    	GET	hdr.AllWinnerH3
    	GET hdr.Registers
    	GET	hdr.RAMMap
    	GET hdr.HDMI_Regs


        AREA    |!!!ROMStart|, CODE, READONLY, PIC

        IMPORT  rom_checkedout_ok
        IMPORT  clear_ram
        EXPORT  HAL_Base
;        IMPORT  HAL_DebugTX
;	    IMPORT  HAL_DebugRX
;        EXPORT  workspace
;        IMPORT  gic_clear
        IMPORT  ram_detector
 [ Debug
    GET     Debug
    GET     USB
    IMPORT  HAL_DebugTX
    IMPORT  HAL_DebugRX
    IMPORT  DebugHALPrint
    IMPORT  DebugHALPrintReg
    IMPORT  DebugMemDump
    IMPORT  DebugHALPrintByte
    IMPORT  DebugCallstack


 ]
; Using the DMA controller to relocate the ROM image is much faster than doing it with the CPU
             GBLL Use_DMA_Copy
Use_DMA_Copy SETL {FALSE}

        MACRO
        CallOSM $entry, $reg
        LDR     ip, [v8, #$entry*4]
        MOV     lr, pc
        ADD     pc, v8, ip
        MEND

        ENTRY
HAL_Base
;OMAP5 based cargo cult programming.
;        BL      reset
;        BL      reset
;        BL      reset
;        BL      reset
;        BL      reset
;        BL      reset
;JumpTableEnd ;If I can get some info out of this later that's great!
;        ASSERT  . - HAL_Base < 0x60
;        %       0x60 - (. - HAL_Base)
;ROMsize
;        DCD     0
;        B       reset   ;not interested in info for board config yet

;Most of the following isn't really needed anymore.
simple_handler

reset   B       setup
undef   B       undef_handler
swi     B       swi_handler
pabort  B       pabort_handler
dabort  B       dabort_handler
irq     B       irq_handler
fiq     B       fiq_handler

fake_handler
    B setup ;soft reboot, sort of.

undef_handler
 [ Debug
        MOV a1, #'u'
        LDR a2, =&01C28000
        STRB a1, [a2, #0]
        MRC p15, #0, a1, c5, c0, #1 ;Read IFSR
        DebugReg a1, "\nIFSR contents: &"

 ]
    B setup
swi_handler
 [ Debug
        MOV a1, #'s'
        LDR a2, =&01C28000
        STRB a1, [a2, #0]
 ]
    B setup
pabort_handler
 [ Debug
        MOV a1, #'p'
        LDR a2, =&01C28000
        STRB a1, [a2, #0]
 ]
    SUBS pc, R14, #4
    B setup
dabort_handler
 [ Debug
        MOV a1, #'d'
        LDR a2, =&01C28000
        STRB a1, [a2, #0]
        ;We're doomed anyway.If it has the UART configured we'll try for
        ;some output
        MRC p15, #0, a1, c5, c0, #0 ;Read DFSR  data fault status register
        DebugReg a1, "DFSR contents: &"
 ]
    B setup
irq_handler
 [ Debug
        MOV a1, #'i'
        LDR a2, =&01C28000
        STRB a1, [a2, #0]
 ]
    B setup
fiq_handler
 [ Debug
        MOV a1, #'f'
        LDR a2, =&01C28000
        STRB a1, [a2, #0]
 ]
    B setup

setup
;Literally everything I find on disabling everything on a7 works differently.
;Let's just keep trying and see what sticks.
    MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode ; Get into SVC mode now, so we
    DSB
    ISB

	;let's throw everything at it.


;Cortex a7 needs a manual iterative cache invalidate though CP15
;using set/way. Boo :(
;Invalidate all also needs to be sent to ICU and TLB.
;I'm sure I had that part. Where is it?


    ;yet another approach...
;    MRC    p15, 0, a2, c1, c0, 0
    ;b0, MMU
    ;b2, DCache
    ;b12 ICache
    ;this disables them. They need to be cleared beforehand.
;    LDR    a1, =2_1000000000101
;    BIC    a2, a2, a1
;    MCR    p15, 0, a2, c1, c0, 0
    ;need to invalidate caches.
;	DSB
;	ISB

 ;This is interesting. Let's analyze this.
;why ip???
   ;MCR p15, 0, a2, c3, c0, 0       ;?
	;invalidate caches
	;MCR p15, 0, ip, c8, c7, 0      ; Invalidate caches.
	;Not sure the above 2 are a7 related.
	;Flush BTC
	;MCR p15, 0, ip, c7, c5, 6      ;BPIALL



;Changed so invalidation is BEFORE disabling.
;Still need proper invalidate

	;ICIALLUIS  ; Does ObjAsm have the SYS macros for these?
;Can we have a facepalm? What happened to the bits set for a2???
;Let's add what we need!

;What happens if I remove all of this???
;Oh my! My scry sees that the MMU is still on if I block all this out.
;On return it promptly throws an undefined instruction abort and
;infinite data aborts.
;Let's just try turning off the MMU and leaving almost everything else alone.

;U-Boot handles cache invalidation, clear etc.
;Going to try turning off everything to see how much it actually does.

;Set TTBR0 N to 0.
 [ False
   ;Turn off MMU only. Borrowed from code below.
    MOV    a1, #1
    MRC    p15, #0, a2, c1,  c0,  #0 ;read SCTLR
    BIC    a2,  a2, a1, LSL#0  ;(1 <<  0) ;Address translation bit.
    MCR    p15, #0, a2, c1, c0, #0 ;Write SCTLR
    DSB
    ;MRC    p15, #0, a2, c2, c0, #0   That's TTBR0. Do I need TTBCR?
    MRC    p15, #0, a2, c2, c0, #2 ;TTBCR
    BIC    a2, a2, #2_11 ;ARM 5, 6 compatible.
    MCR    p15, #0, a2, c2, c0, #2
    DSB

 ]
 [ False
   ;Disable FIQs and IRQs. Should be disabled anyway.
    MRS a2, CPSR
    ORR a2, a2, #&40 ;Disable FIQs
    ORR a2, a2, #&80 ;Disable IRQs
    MSR CPSR_c, a2
    DSB
 ]
;most of this section may still be needed for uImage
 [ False
  ;Disable caches
    MCR        p15,    #0,   a2, c7,  c5,   #0  ;ICIALLU
    DSB
    MCR        p15,    #0,   a1, c7,  c1,   #0  ;ICIALLUIS
    DSB
    MCR        p15,    #0,   a2, c7,  c5,   #6  ;BPIALL
    DSB
    MCR        p15,    #0,   a2, c7,  c10,  #1  ;DCCMVAC
    DSB

    ;TLB invalidation shotgun
    MCR p15, 0, a2, c8, c5, 0 ;ITLBIALL
    DSB
    ISB
    MCR p15, 0, a2, c8, c7, 0 ;TLBIALL
    ;MCR p15, 0, r2, c8, c6, 2 ;DTLBIASID
    DSB
    ISB
    MCR p15, 0, a2, c8, c3, 0;TLBIALLIS
    DSB
    ISB


    MOV   a1, #1
    MRC        p15,    #0,   a2,  c1,  c0,  #0 ;read SCTLR
    BIC    a2, a2, a1, LSL#2  ;(1 <<  2) ; Cache enable bit.
    BIC    a2, a2, a1, LSL#11 ; Branch prediction disabled
    BIC    a2, a2, a1, LSL#12 ;(1 << 12) ;ICache enable bit.
    MCR    p15, #0, a2, c1, c0, #0
    DSB
 ]
    ;All prerequisites for OS_InitARM reached.

    ADRL    v1, HAL_Base + OSROM_HALSize    ; v1 -> RISC OS image
    LDR     v8, [v1, #OSHdr_Entries]
    ADD     v8, v8, v1                      ; v8 -> RISC OS entry table

        ; Ensure CPU is set up
        MOV     a1, #0
        CallOSM OS_InitARM
 ;While I'm certain everything else needs to be dealt with, there has
 ;to be something in here causing coprocessor issues.
 [ False

        ;NO! Reserved bits on a7
        ;MOV    a1, #&70 ;grabbing from Tungsten, but why is this here?
        ;afaik a1 is garbage here.
	;Op1{cond} coproc, #op1, Rt, CRn, CRm,  {#op2}
        ;MCR        p15,    #0,   a1, c1,  c0
        MOV    a1, #0
        ;MCR        p15,    #0,   a1, c7,  c7 ;not valid for Cortex a7
        ;TLBIALL Invalidate unified TLB
        MCR        p15,    #0,   a1, c8,  c7 ;Invalidate caches.
        DSB
        ISB

    ;ICIALLUIS Instruction cache invalidate all
	;Op1{cond} coproc, #op1, Rt, CRn, CRm,  {#op2}
	MCR        p15,    #0,   a1, c7,  c1,   #0      ;Rt is ignored.
	;threw an undefined instruction.
	DSB    SY
	ISB    SY

    ;early boot undefined instruction on this one. Just once.
    ;BPIALL     ;flushing btc
    MCR        p15,    #0,   a2, c7,  c5,   #6      ;Rt is ignored.
    DSB    SY
    ISB    SY

    ;ICIALLU
    MCR        p15,    #0,   a2, c7,  c5,   #0      ;Rt is ignored.
    DSB    SY
    ISB    SY

    ;DCCMVAC. Data cache clean line by MVA to PoC
    ;Don't know about this one.
    MCR        p15,    #0,   a2, c7,  c10,  #1

    ;Op1{cond} coproc, #op1, Rt, CRn, CRm,  {#op2}
    MOV   a1, #1
    MRC        p15,    #0,   a2,  c1,  c0,  #0 ;read SCTLR
    BIC    a2, a2, a1, LSL#30 ;exceptions in ARM state.  ;Simple
    BIC    a2, a2, a1, LSL#12 ;(1 << 12) ;ICache enable bit.
    ORR    a2, a2, a1, LSL#10 ;Enable SWP and SWPB       ;Simple
    BIC    a2, a2, a1, LSL#2  ;(1 <<  2) ; Cache enable bit.
    BIC    a2, a2, a1, LSL#0  ;(1 <<  0) ;Address translation bit.
    MCR        p15,    #0,   a2,  c1,  c0,  #0 ;Write SCTLR
    DSB
    ISB

;below from Simple HAL
    ;Op1{cond} coproc, #op1, Rt, CRn, CRm,  {#op2}
    MOV    a1, #1
    MRC        p15,    #0,   a2,  c1,  c0,  #2 ;read CPACR
    BIC    a2, a2, a1, LSL#31 ;ensure SIMD is enabled
    BIC    a2, a2, a1, LSL#30 ;D0-D31 (VFP normal)
    MOV    a1, #2_11
    BIC    a2, a2, a1, LSL#22 ;copro11 rights full access
    BIC    a2, a2, a1, LSL#20 ;copro10 rights full access
    MCR        p15,    #0,   a2,  c1,  c0,  #2 ;write CPACR
    DSB SY
    ISB SY

 ]
;    MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode ; Get into SVC mode now, so we can write to sb without much fear of losing it (we may have been in FIQ)
	;let's throw everything at it.

;What the heck is this doing here?
 [ False
    MRS a2, CPSR
    ORR a2, a2, #&40 ;Disable FIQs
    ORR a2, a2, #&80 ;Disable IRQs
    MSR CPSR_c, a2
    DSB
 ]
    ;These seem to cause boot instability.
    ;disable FIQs
	;going to comment these out for the moment.
;	MRS	a2, CPSR
;	ORR	a2, a2, #&40
;	MSR	CPSR_c, a2
;        DSB
;	;disable IRQs
;	MRS	a2, CPSR
;	ORR	a2, a2, #&80 ;disable IRQs
;	MSR	CPSR_c, a2
;        DSB
;is this causing the undefined instruction abort?
    ;While I'm here. Let's give user access to the FPU.
	;Op1{cond} coproc, #op1, Rt, CRn, CRm,  {#op2}
;	MRC        p15,    #0,    a2, c1,  c0,   #2  ;CACR
;	ORR    a1, a2, (2_11 << 22) ;cp11 access rights
;   ORR    a1, a2, (2_11 << 20) ;cp10 access rights
;   MCR        p15,    #0,    a1, c1,  c0,   #2
;   DSB    SY
;   ISB    SY
;   PUSH   {lr} ;probably not needed.
;   BL     gic_clear
;   POP    {lr}





;Vectors left at &0 for now. Relocating them was of limited benefit.
;Fake handler code can stay.

; I'm stashing the workspace above the reloc'd RO for now.
;I left a 1MB gap.
;set stack location
    LDR sp, =PreMMU_Stack
    ;set location of workspace.
    ;relocated to after CPU state reset.
;workspace * PreMMU_Workspace ;this bothers me.
    LDR   sb, =PreMMU_Workspace


    ;vector location can stay in SRAM for now. They need to be
    ;rewritten though.
    ADRL    a1, simple_handler
    MCR     p15, #0, a1, c12, c0
    DSB
    ;set addres of interrupt controller to the physical address
    ;for now until the logical address is mapped in.
    ;we don't need it, but it's one less undefined state.
    LDR a1, =SCU
    STR a1, SCU_Log

    LDR a1, =GIC_DIST
    STR a1, IRQDi_Log

    LDR a1, =GIC_CPUIF
    STR a1, IRQC_Log

    ;physical address of UART for Pre-MMU debugging.
    ;temporary silly code.
    ;This just allows a single set of UART functions.svn u
    LDR	a1, =UART_0
	STR	a1, DebugUART
	STR	a1, HALUART_Log
	ADD a1, a1, #&400
	STR a1, UART_1_Log
	ADD a1, a1, #&400
	STR a1, UART_2_Log
    ADD a1, a1, #&400
	STR a1, UART_3_Log

	MOV	a1, #0
	STR	a1, DefaultUART

	BL	uart_fifo_enable
 [ Debug
 ;   Push "lr"
	DebugTX "PreMMU UART configured"
	ALIGN
 ;	Pull "lr"

;    ADRL sb, workspace
;	LDR a1, =UART_0
;	STR a1, DebugUART

;This is just for USB_ReportRegs
    LDR a1, =CCU
    STR a1, CCU_BaseAddr

;------------detect RAM
;    BL  ram_detect
    BL  ram_detector

    BL  cpu_scry
;    Push "lr"
    DebugTX "Returned from cpu_scry"
    ;---This is the last code known executing from UART readout.---
    ALIGN
;    Pull "lr"
;    BL Video_Twiddle
 ]
 [ DebugTiming

        ADD     sp, sb, #32768 ; Temp stack for debug code
        ; Ensure debug UART FIFO is enabled (assuming UART 3)
;        MOV     a1, #0
;        STRB    a1, UARTFCRSoftCopy+2
;        MOV     a1, #2
        STRB    a1, NumUART ; Hide UART from RO
        MOV     a2, #1
        IMPORT  HAL_UARTFIFOEnable
        BL      HAL_UARTFIFOEnable
        DebugTimeNoMMU a1, "@ "
 ]
        ; Now do common init
;        B       restart     ;not needed

;some funny looking bits because of removed OMAP code.

; [ Debug
;HelloWorld DCB "AWH3 HAL init",13,10,"Board config=",0
;        ALIGN
; ]

restart
;        DebugChar a3,a4,48
;        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode
;        DebugChar a3,a4,49
 [ False
        ADRL    v1, HAL_Base + OSROM_HALSize    ; v1 -> RISC OS image

        LDR     v8, [v1, #OSHdr_Entries]
        ADD     v8, v8, v1                      ; v8 -> RISC OS entry table

        ; Ensure CPU is set up
        MOV     a1, #0
        CallOSM OS_InitARM
 ]
        ;DebugChar a3,a4,50
        ;DebugChar a3, a4, 'X'
; [ Debug
;        MOV a1, #'A'
;        LDR a2, =&01C28000
;        STRB a1, [a2, #0]
;
; ]

 [ False
;         Push "lr"
         DebugTX "CallOSM OS_InitARM complete"
;         Pull "lr"
 ]

;Leaving commented out for now. Haven't added any multiprocessor support.
;Could be a cause of instability.
;iMx6 has some SCU enabling stuff. Interesting! Let's try it.
                ; Enable the SCU
	 ;Op1{cond} coproc, #op1, Rt, CRn, CRm,  {#op2}
;        MRC     p15,    #4,   a1, c15, c0,   #0  ; Read CBAR
;        LDR     a2, [a1, #0]            ; Read the SCU Control Register
;        ORR     a2, a2, #1              ; Set bit 0 (The Enable bit)
;        STR     a2, [a1, #0]            ; Write back modifed value
        ;hang on. What?


;---- Causes lockup, but why?
        ; Initialise RAM
;        BL      init_ram

;-------HARDCODED! FIXME
       ;  LDR a1, = BLOCK_1_START;bottom of clear range
       ;  LDR a2, =BLOCK_0_END
       ;  BL      clearram


        ; The first 4K of the first registered block of RAM is used by RISC OS's init code, and also contains the stack
        ; To keep things simple and safe, we'll relocate the HAL and OS image to the top end of RAM
        ; Although with the beagleboard we know we'll be booted from RAM, this code has been written so that it should work if running from ROM

        ; First, identify the top end of RAM
        ; Then check if we intersect it
        ; If we do, first copy ourselves down
        ; Then copy ourselves up



 [ Use_DMA_Copy
        ; We'll use DMA for extra speed, so start by resetting the DMA controller
        LDR     v5, =L4_sDMA
        MOV     v1, #2
        STR     v1, [v5, #DMA4_OCP_SYSCONFIG]
5
        LDR     v1, [v5, #DMA4_SYSSTATUS]
        TST     v1, #1
        BEQ     %BT5
        ; Set a sensible FIFO budget (as per SDMACReset)
        LDR     a2, =&100080
        STR     a2, [v5, #DMA4_GCR]
        ; Configure channel 0 for the right settings
        ADD     v5, v5, #DMA4_i
        LDR     v1, [v5, #DMA4_CLNK_CTRLi]
        BIC     v1, v1, #&8000 ; Disable channel linking
        STR     v1, [v5, #DMA4_CLNK_CTRLi]
        MOV     v1, #1<<4
        STR     v1, [v5, #DMA4_CICRi] ; frame end interrupt enabled
        LDR     v1, =&2E1C2 ; 32bit elements, 64 byte bursts with packing, last write non-posted
        STR     v1, [v5, #DMA4_CSDPi]
        MOV     v1, #1
        STR     v1, [v5, #DMA4_CFNi] ; 1 frame
 ]

relocate_code
;        DebugChar a1,a2,66
        BL      get_end_of_ram

;        DebugChar v1,v2,67

        ; How big are we?
        ADRL    v1, HAL_Base + OSROM_HALSize
        LDR     v2, [v1, #OSHdr_ImageSize]
        LDR     lr, [v1, #OSHdr_Flags]
        TST     lr, #OSHdrFlag_SupportsCompression
        LDRNE   lr, [v1, #OSHdr_CompressedSize]
        MOVEQ   lr, v2
        SUB     v1, v1, #OSROM_HALSize ; Start of HAL
        ADD     v2, v2, #OSROM_HALSize ; Size of HAL+OS
        ADD     lr, lr, #OSROM_HALSize ; Size of compressed HAL+OS
        ADD     v3, v1, lr ; End of OS
        ;------------I added the branch here so I can reuse size code.

;        B       bypass_rom_reloc

        MOV     v4, a1 ; End of RAM
        SUB     v5, v4, v2 ; New start address of HAL
        CMP     v1, v5
        BEQ     %FT10 ; No copy needed
        CMP     v1, v4
        BHI     %FT20 ; We're in some ROM above RAM. OK to continue with copy.
        CMP     v3, v5
        BLS     %FT20 ; We're in some ROM/RAM below our copy destination. OK to continue with copy.
        ; Else we currently overlap the area we want to copy ourselves into.
        SUB     v5, v1, lr ; Copy the HAL+OS to just before itself. TODO - This will fail with big ROMs (128MB beagleboard with >42MB ROM size)
20
 [ Use_DMA_Copy
        ; Transfer everything in one DMA frame; this gives us a max ROM size of 64MB-4 bytes
        LDR     a3, =L4_sDMA+DMA4_i
        LDR     a1, [a3, #DMA4_CSRi]
        STR     a1, [a3, #DMA4_CSRi] ; Clear status register
        MOV     a1, lr, LSR #2
        STR     a1, [a3, #DMA4_CENi]
        STR     v5, [a3, #DMA4_CDSAi]
        STR     v1, [a3, #DMA4_CSSAi]
        LDR     a1, =&805080 ; Enable channel with post-increment source & destination, prefetch
        STR     a1, [a3, #DMA4_CCRi]
        ; Wait for copy to complete
30
        LDR     a1, [a3, #DMA4_CSRi]
        TST     a1, #1<<4
        BEQ     %BT30
        ; Make doubly sure that it's finished by checking WR_ACTIVE/RD_ACTIVE
40
        LDR     a1, [a3, #DMA4_CCRi]
        TST     a1, #&600
        BNE     %BT40
 |
        MOV     a1, v5
        MOV     a2, v1 ; Copy source
        MOV     a3, lr
30
        LDR     a4, [a2], #4
        SUBS    a3, a3, #4
        STR     a4, [a1], #4
        BGT     %BT30
 ]
        ; Invalidate I-cache, branch predictors
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c5, 0
        MCR     p15, 0, a1, c7, c5, 6
        DSB     SY ; Wait for I-cache invalidation to complete
        ISB     SY ; Wait for branch predictor invalidation to complete?
        ;DebugChar a1,a2,68
        ; Jump to our new copy
        ADR     a1, relocate_code ; Keep things simple by just running through the same code again
        SUB     a2, v5, v1
        ADD     a1, a1, a2 ; relocate our branch target
        ADD     v8, v8, a2 ; Update OS entry table ptr
        MOV     pc, a1
10
        ; Copy completed OK.
        ; v2 = size of HAL+OS
        ; v4 = end of OS/RAM
        ; v5 = start of HAL
        ; v8 = OS entry table ptr
        DebugChar a1,a2,69
        DebugTimeNoMMU a1, "ROM relocated @ "
        ALIGN

bypass_rom_reloc
        ; Clear RAM up to v5
       ; MOV     a1, v5        ;hey, what?
;Again, the kernel. We'll deal with this later.
;        BL      clear_ram

         BL  get_end_of_ram   ;should be in a2
         MOV    a2, a1
         MOV    a1, v3
         ADD    a1, a1, #4
;         BL  clearram   ;Irritating pause. Doesn't seem to help anyway
         ;call my simple code. See if it affects stability.
         ;MOV a1, v4 ;bottom of clear range
;         LDR a1, =BLOCK_0_START
;         LDR a2, =BLOCK_1_START
;         BL      clearram
;Did this cause the lockup?

        ;DebugChar a1,a2,70
        ;DebugTimeNoMMU a1, "RAM cleared @ "

; TODO - NEON seems to be on by default, need to work out how to turn it off before I can test code to turn it on!
;        ; Enable power to the NEON unit, if present
;        LDR     a1, =&4800244C ; 'control OMAP status register'
;        LDR     a1, [a1]
;        TST     a1, #1<<4
;        BNE     %FT10
;;        ; NEON is available, make sure it's turned on
;        ; Enable CP10/CP11 access
;        MRC     p15, 0, a1, c1, c0, 2
;        ORR     a1, a1, #&F<<20
;        MCR     p15, 0, a1, c1, c0, 2
;        ISB     SY
;        ; Now enable the unit
;        MOV     a1, #1<<30 ; EN bit
;        DCI     &EEE80A10 ; VMSR FPEXC, a1


;this is the boot.s entry point.
;is this where the SCU address is coming from?
 [ Debug
	MRC p15, 4, a1, c15, c0, 0
	DebugReg a1
 ]
        B       rom_checkedout_ok

get_end_of_ram
	;hardcoded cheat for now to the beginning of VRAM.
	LDR    a1, =RO_RAM_END
	MOV    pc, lr

uart_fifo_enable   ;these are all write only.
;set FCR:0 to 1 to enable FIFO
   Push   "a1, a2"
   LDR    a1, =UART_Base
   ;LDR R1, [R0, #UART_FCR]
   ;ORR R1, R1, FCR_FIFOE ;set bit 0
   MOV    a2, #FCR_FIFOE
   STR    a2, [a1, #UART_FCR]

   Pull   "a1, a2"
   MOV    pc, lr
	;VRAM is still above this.
;        GET     RAM.s


;--------------------------------------
;Extremely simple code to zero RAM.
;void clearram(uint32 bottom, uint32 top)
;a1 = bottom
;a2 = top
clearram
     Push   "a1-a3"
     MOV    a3, #0
10
     STR    a3,[a1], #4
     CMP    a1, a2
     BNE    %BT10
     Pull   "a1-a3"
     MOV    pc, lr

;------------------------------------------------------------------------------
; Video_Twiddle
;------------------------------------------------------------------------------
;Otherwise useless function for messing with the video hardware
;and framebuffer.
;This is stomping on the ROM. DOn't execute it right now.
Video_Twiddle
    Push "a1-a3, lr"
    LDR    a1, =&7Fe79000 ;this /should/ be the base of the framebuffer.
    ;Use U-boot source to look deeper. This is just to see if we
    ;have VRAM available at that address.
    LDR    a2, =&178e00
    ADD    a2, a1, a2 ;get end address
    LDR    a3, =&2468BDF0 ;completely arbitrary number.
;this should fill the screen with the arbitrary colour.
10
    STR    a3, [a1, #0]
    CMP    a1, a2
    ADDLE a1, a1, #4
    BLE    %BT10
    Pull  "a1-a3, lr"
    MOV    pc, lr
;Compare this with ram_detector.s!
;------------------------------------------------------------------------------
; RAM Detect (or at least try to)
;------------------------------------------------------------------------------
ram_detect
    ;start off high and work our way down.
    ;RAM will probably be 2GB, 1GB, 512MB, 256MB
    ;I guess check the top word of each block?
    ;&100000 is 1MiB. (1048576 dec)  FFFFC (-1 word)
    ;RAM starts at 0x40000000
    ;b20 is where MiB begins?
    ;&100000 * &100 for 256MiB  &4FFFFFFC
    ;&100000 * &200 for 512MiB  &5FFFFFFC
    ;&100000 * &400 for 1GiB    &7FFFFFFC
    ;&100000 * &800 for 2GiB    &BFFFFFFC
    ;As I'd feared, we appear to have mirrored memory
    ;Might need to check for copies at certain addresses?

    Push "a1-a4, lr"

    LDR   a4, =&AAAAAAAA ;1010 etc.
    ;--2GiB
    LDR   a3, =&BFFFFFFC
    LDR   a1, [a3, #0] ;2GiB ;store word temporarily.

    STR   a4, [a3, #0] ;Store the pattern.
    ISB
    DSB
    LDR   a2, [a3, #0] ;load that word again
    CMP   a2, a4 ;did the data stick?
    BEQ   %FT10
    STR   a1, [a3, #0] ;put the original word back just in case.

    ;This could be done easily with a loop. Meh.
    ;--1GiB
    LDR   a3, =&7FFFFFFC
    LDR   a1, [a3, #0] ;2GiB ;store word temporarily.

    STR   a4, [a3, #0] ;Store the pattern.
    ISB
    DSB
    LDR   a2, [a3, #0] ;load that word again
    CMP   a2, a4 ;did the data stick?
    BEQ   %FT20
    STR   a1, [a3, #0] ;put the original word back just in case.

    ;--512MiB
    LDR   a3, =&5FFFFFFC
    LDR   a1, [a3, #0] ;2GiB ;store word temporarily.

    STR   a4, [a3, #0] ;Store the pattern.
    ISB
    DSB
    LDR   a2, [a3, #0] ;load that word again
    CMP   a2, a4 ;did the data stick?
    BEQ   %FT30
    STR   a1, [a3, #0] ;put the original word back just in case.

    ;256MiB
    LDR   a3, =&4FFFFFFC
    LDR   a1, [a3, #0] ;2GiB ;store word temporarily.

    STR   a4, [a3, #0] ;Store the pattern.
    ISB
    DSB
    LDR   a2, [a3, #0] ;load that word again
    CMP   a2, a4 ;did the data stick?
    BEQ   %FT40
    STR   a1, [a3, #0] ;put the original word back just in case.

    ;Didn't get any hits.
    B     %FT50

10 ;2GiB
   DebugTX "2GiB RAM detected"
   B      %FT70
20
   DebugTX "1GiB RAM detected"
   B      %FT70
30
   DebugTX "512MiB RAM detected"
   B      %FT70
40
   DebugTX "256MiB RAM detected"
   B      %FT70
50
   DebugTX "No RAM detected. This code must be broken."
   B      %FT70
70
    Pull "a1-a4, lr"
    MOV pc, lr


;------------------------------------------------------------------------------
; CPU Scry
;------------------------------------------------------------------------------

cpu_scry
 [ Debug
     Push  "a1-a4, lr"
     ;a4 base reg
     ;a3 offset reg
     MRC        p15,    #0,   a2,  c1,  c0,  #0 ;read SCTLR
     ;b0 is MMU state
     AND    a1, a2, #2_1 ;bit0 = MMU
     CMP    a1, #0
     BLEQ   DebugHALPrint
     =     "MMU is off.\r\n ", 0
     BLNE   DebugHALPrint
     =     "MMU is on.\r\n ",  0

     ;FIXME. Needs ADRL.
     LDR   a1, =HAL_Base
     DebugReg a1, "HAL_Base is at:"

;now gimme a reg dump of one of the USB HCI controllers.
;Something's different between go and bootm. go works. bootm doesn't.
     DebugTX "CCU registers:"
     LDR    a2, =CCU
     LDR    a3, [a2, #USBPHY_CFG_REG]
     DebugReg a3,    "USBPHY_CFG_REG      "
     LDR    a3, [a2, #AHB2_CLK_CFG]
     DebugReg a3,    "AHB2_CLK_CFG        "
     LDR    a3, [a2, #BUS_CLK_GATING_REG0]
     DebugReg a3,    "BUS_CLK_GATING_REG0 "
     LDR    a3, [a2, #BUS_SOFT_RST_REG0]
     DebugReg a3,    "BUS_SOFT_RST_REG0   "



     ;let's go HCI1
     LDR    a2, =USB_HCI1 ;good as any.
     ;I could loop this, but I want printed labels.
     DebugTX "EHCI Operational Register"
     LDR    a3, [a2, #EHCI_USBCMD]
     DebugReg a3,    "E_USBCMD           "
     LDR    a3, [a2, #EHCI_USBSTS]
     DebugReg a3,    "E_USBSTS           "
     LDR    a3, [a2, #EHCI_USBINTR]
     DebugReg a3,    "E_USBINTR          "
     LDR    a3, [a2, #EHCI_FRINDEX]
     DebugReg a3,    "E_FRINDEX          "
     LDR    a3, [a2, #EHCI_CTRLDSSEGMENT]
     DebugReg a3,    "E_CTRLDSSEGMENT    "
     LDR    a3, [a2, #EHCI_PERIODICLISTBASE]
     DebugReg a3,    "E_PERIODICLISTBASE "
     LDR    a3, [a2, #EHCI_ASYNCLISTADDR]
     DebugReg a3,    "E_ASYNCLISTADDR    "
     LDR    a3, [a2, #EHCI_CONFIGFLAG]
     DebugReg a3,    "E_CONFIGFLAG       "
     LDR    a3, [a2, #EHCI_PORTSC_0]
     DebugReg a3,    "E_PORTSC           "

;EHCI is a good start.
;     DebugTX "OHCI Control and Status Partition Register"
;     LDR    a3, [a2, #OHCI_HCREVISION]
;     DebugReg a3,    "OHCI_ "

;OHCI Control and Status Partition Register.
;TODO!


;Not going to be pretty.
     LDR    a4, =R_CPUCFG
     MOV    a3, #CPU0_STATUS_REG
     LDR    a2, [a4, a3]
     AND    a1, a2, #2_100 ;STANDBYWFI
     DebugTX "CPU 0:"
     ALIGN
     MOV    a1, a1, LSR#2
     DebugReg a1, "STANDBYWFI = "
     ALIGN
     AND    a1, a2, #2_10  ;STANDBYWFE
     MOV    a1, a1, LSR#1
     DebugReg a1, "STANDBYWFE = "
     ALIGN
;----
     LDR    a4, =R_CPUCFG
     MOV    a3, #CPU1_STATUS_REG
     LDR    a2, [a4, a3]
     AND    a1, a2, #2_100 ;STANDBYWFI
     DebugTX "CPU 1:"
     ALIGN
     MOV    a1, a1, LSR#2
     DebugReg a1, "STANDBYWFI = "
     ALIGN
     AND    a1, a2, #2_10  ;STANDBYWFE
     MOV    a1, a1, LSR#1
     DebugReg a1, "STANDBYWFE = "
     ALIGN
;----
     LDR    a4, =R_CPUCFG
     MOV    a3, #CPU2_STATUS_REG
     LDR    a2, [a4, a3]
     AND    a1, a2, #2_100 ;STANDBYWFI
     DebugTX "CPU 2:"
     ALIGN
     MOV    a1, a1, LSR#2
     DebugReg a1, "STANDBYWFI = "
     ALIGN
     AND    a1, a2, #2_10  ;STANDBYWFE
     MOV    a1, a1, LSR#1
     DebugReg a1, "STANDBYWFE = "
     ALIGN
;----
     LDR    a4, =R_CPUCFG
     MOV    a3, #CPU3_STATUS_REG
     LDR    a2, [a4, a3]
     AND    a1, a2, #2_100 ;STANDBYWFI
     DebugTX "CPU 3:"
     ALIGN
     MOV    a1, a1, LSR#2
     DebugReg a1, "STANDBYWFI = "
     ALIGN
     AND    a1, a2, #2_10  ;STANDBYWFE
     MOV    a1, a1, LSR#1
     DebugReg a1, "STANDBYWFE = "
     ALIGN
     ;so the cores aren't waiting. How do I tell if they are sleeping?
;----
     ;The idea here is to send any core besides #0 to a holding pen.
     ;use MPIDR b1:0 to grab CPU core #.
     MRC    p15, #0, a1, c0, c0, #5
     AND    a1, a1, #2_11
     CMP    a1, #0
     BNE    pen
     Pull  "a1-a4, lr"
 ]
     MOV    pc, lr

pen
     DebugTX "Gotta catch 'em all!"
10   WFI
     B       %BT10  ;just incase it's extra slippery / gets woken up.


        LTORG

        END
