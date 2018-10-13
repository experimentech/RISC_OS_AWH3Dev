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
        ; You'll often see these prefixed with Hdr: for historic reasons.
        ; This is no longer necessary, and in fact omitting them makes it
        ; possible to cross-compile your source code.
        GET     AHCI

; Initialise rest of chip and turn on relevant IRQ stuff
ChipInit        ROUT
        Entry   "r0-r9"
        ldr     r6, ChipBase
        mov     r0, #(1<<BIT_AHCI_GHC_HR)
        str     r0, [r6, #HW_AHCI_GHC_OFFSET]   ; Lets give the chip a global reset so
        ldr     r3, [r6, #HW_AHCI_GHC_OFFSET]   ;
        tst     r3, #(1<<BIT_AHCI_GHC_HR)       ; done?
        beq     %ft1                            ; yes

        MOV     r0, #1*1024 ; 1 msec ish
        bl      HAL_CounterDelay
        ldr     r3, [r6, #HW_AHCI_GHC_OFFSET]   ;
        tst     r3, #(1<<BIT_AHCI_GHC_HR)       ; done?
        EXIT    NE                              ; no.. faulty
1
; set up various regs in the ahci controller
        ; set for 1ms timer
        ldr     r0, =100000             ; 100 MHz value to give 1ms
        str     r0, [r6, #HW_AHCI_TIMER1MS_OFFSET]
        ; set OOBR register
        ldr     r0, = COM_Default+ (1<<BIT_AHCI_OOBR_WE)
        str     r0, [r6, #HW_AHCI_OOBR_OFFSET]  ; enable for writing
        bic     r0, r0, #(1<<BIT_AHCI_OOBR_WE)
        str     r0, [r6, #HW_AHCI_OOBR_OFFSET]  ; write, and disable for writing
        ; set staggered spinup
        ldr     r0, [r6, #HW_AHCI_CAP_OFFSET]
        orr     r3, r0, #(1<<BIT_AHCI_CAP_SSS)  ; support staggered spinup
        str     r3, [r6, #HW_AHCI_CAP_OFFSET]
        ; detemine how many ports are implemented
        and     r3, r3, #BIT_AHCI_CAP_NP_MASK   ; portmax - 1, (=0 for 1 port)
        mov     r2, r3
; DebugReg r2, "highest port Implemented "
        mov     r1, #1
001     subs    r2, r2, #1                      ; build bitmap of valid lanes
        movge   r1, r1, lsl #1
        orrge   r1, r1, #1
        bge     %bt001
        str     r1, [r6, #HW_AHCI_PI_OFFSET]    ; ensure controller knows
        ; now for each port, analyse, then set it idle
        ; r3 = ports present - 1 (0  for 1 port on wandboard)
        ; initialise r5 to compensate for port address offset if needed
        ldr     r1, [r6, #HW_AHCI_PI_OFFSET]    ; see what controller knows
        mov     r5, r6                          ; set for use with first port
002     bl      CheckAHCIIdle
;  DebugReg  r0, " 0 if port idle "
        teq     r0, #0                          ; idle?
        bne     %ft004                          ; no .. abort this one
; DebugReg r3, "idle port found at "
        ; spin up port
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        orr     r1, r1, #(1<< BIT_AHCI_P0CMD_SUD)
  orr   r1, r1, #(1<< BIT_AHCI_P0CMD_PMA) ; suggest port multiplier is attached
        str     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        ldr     r1, =  P0SCTL_Default
        str     r1, [r5, #HW_AHCI_P0SCTL_OFFSET] ; start the process
        MOV     r0, #3*512                      ; at least 1.5 msec ish
        BL      HAL_CounterDelay
; need A TIMEOUT LOOP
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        tst     r1, #(1<< BIT_AHCI_P0CMD_SUD)
; TO HERE this is NE when device spun up
        bne     %ft006                          ; ok it has spun up
        MOV     r0, #3*512                      ; at least 1.5 msec ish
        BL      HAL_CounterDelay                ; again
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        tst     r1, #(1<< BIT_AHCI_P0CMD_SUD)
        beq     %004                            ; no spinup reported
006
        ldr     r1, [r5, #HW_AHCI_P0SCTL_OFFSET]
        bic     r1, r1, #(AHCI_P0SCTL_clear<< BIT_AHCI_P0SCTL_DET)
        orr     r1, r1, #(AHCI_P0SCTL_DET_disable<< BIT_AHCI_P0SCTL_DET)
        str     r1, [r5, #HW_AHCI_P0SCTL_OFFSET] ; disable port
; claim some uncachable ram for the chip work buffers
; from the PCI_RAM store
        mov     r0, #(AHCI_RX_FIS_Size*MaxDevCount) + MAX_AHCI_PROTOCOL_SIZE
        mov     r1, #&400                       ; 1024 buffer alignment
        mov     r2, #0                          ; no mem addressing constraint
; DebugReg r0, "rq size  "
        str     r2, AHCIBuf_Log                 ; logical address
        str     r2, AHCIBuf_Phys                ; physical address
        swi     XPCI_RAMAlloc
        EXIT    VS                              ; claim failed
; DebugReg r0, "AHCIbuf_Log  "
; DebugReg r1, "AHCIbuf_Phys "

        str     r0, AHCIBuf_Log                 ; logical address
        str     r1, AHCIBuf_Phys                ; physical address
        sub     r2, r0, r1                      ; compute offset
        str     r2, ChipL2POffset

        ; tell it where its control structures are
        ; chip needs physical addresses
        str     r1, [r5, #HW_AHCI_P0CLB_OFFSET] ; AHCI_CMDHD_BASE
        add     r1, r1, #MAX_AHCI_PROTOCOL_SIZE
        str     r0, ChipP0CLB
        add     r0, r0, #MAX_AHCI_PROTOCOL_SIZE
        str     r0, ChipRXFis
        str     r1, [r5, #HW_AHCI_P0FB_OFFSET]  ; AHCI_RXFIS_BASE
        ; now enable the port
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        orr     r1, r1, #(1<< BIT_AHCI_P0CMD_FRE)
        str     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        ; clear any stale error/interrupt states
        mov     r1, #-1
        str     r1, [r5, #HW_AHCI_P0SERR_OFFSET]
        str     r1, [r5, #HW_AHCI_P0IS_OFFSET]
        str     r1, [r5, #HW_AHCI_IS_OFFSET]

        mov     r0, #&1f
        strb    r0, LastLoadedSlot
        strb    r0, LastClearedSlot


004
 [ Multi_AHCI_Ports
                                             ; any more ports to check?
        subs    r3, r3, #1
        addge   r5, r5, #AHCI_CLB_SIZE
        bge     %bt002
 ]



;  claim the IRQ vector

        adrl    r1, AHCIDevice
        ldr     r0, [r1, #HALDevice_Device]
        orr     r0, r0, #1<<31          ; pass to other possible claimants
        adr     r1, AHCIDriver_IRQHandler
; DebugReg r0, "AHCIdev  "
; DebugReg r1, "AHCIirqaddr "
        mov     r2, r12
        swi     XOS_ClaimDeviceVector
        EXIT    VS

        adrl    r1, AHCIDevice
        ldr     r0, [r1, #HALDevice_Device]
        mov     r8, #OSHW_CallHAL
        mov     r9, #EntryNo_HAL_IRQEnable
        Push    "r1-r3"
        swi     XOS_Hardware
        Pull    "r1-r3"







        mov     r3, #(1<<BIT_AHCI_GHC_AE)+(1<<BIT_AHCI_GHC_IE)  ; global IE mask enable
        str     r3, [r6, #HW_AHCI_GHC_OFFSET]   ;
; now our irq mask
        ldr     r3, =((1<<BIT_AHCI_P0IS_DHRS)+(1<<BIT_AHCI_P0IS_PCS)+(1<<BIT_AHCI_P0IS_PRCS)+(1<<BIT_AHCI_P0IS_PSS)+(1<<BIT_AHCI_P0IS_DSS)+(1<<BIT_AHCI_P0IS_SDBS)+(1<<BIT_AHCI_P0IS_IFS)+(1<<BIT_AHCI_P0IS_HBDS)+(1<<BIT_AHCI_P0IS_HBFS)+(1<<BIT_AHCI_P0IS_TFES))
        str     r3, [r6, #HW_AHCI_P0IE_OFFSET]


        EXIT
        LTORG

; kill chip and turn off any IRQs claimed, etc
ChipKill        ROUT
        Entry   "r0-r9"
; turn IRQs off
        ldr     r4, ChipBase
        mov     r0, #(1<<BIT_AHCI_GHC_HR)
        str     r0, [r4, #HW_AHCI_GHC_OFFSET]   ; Lets give the chip a global reset
        adrl    r1, AHCIDevice
        ldr     r0, [r1, #HALDevice_Device]
        mov     r8, #OSHW_CallHAL
        mov     r9, #EntryNo_HAL_IRQDisable
        Push    "r1-r3"
        swi     XOS_Hardware
        Pull    "r1-r3"

        bl      KillIDReCall

        ldrb    r0, CCcallbackstate     ; pending callback to AHCICommandRoutine?
        teq     r0, #cb_pending         ; still pending?
        adreql  r0, AHCICommandCompleter
        moveq   r1, r12
        swieq   XOS_RemoveCallBack      ; ok clean up

        adrl    r1, AHCIDevice
        ldr     r0, [r1, #HALDevice_Device]
        orr     r0, r0, #1<<31          ; pass to other possible claimants
        adr     r1, AHCIDriver_IRQHandler
        mov     r2, r12
        swi     XOS_ReleaseDeviceVector


; get rid of our extra storage
        ldr     r0, AHCIBuf_Log                 ; logical address
; DebugReg r0, "Freeing PCI ram "
        teq     r0, #0
        swine   XPCI_RAMFree                    ; free any ram claimed

        EXIT

ChipKillFromService
        Entry   "r0, r4, r12"
        ldr     r12, [r12]
        ldr     r4, ChipBase
        mov     r0, #(1<<BIT_AHCI_GHC_HR)
        str     r0, [r4, #HW_AHCI_GHC_OFFSET]   ; Lets give the chip a global
        EXIT

AHCIDriver_IRQHandler ROUT
        ldr     r1, ChipBase                    ; point to AHCI chip
        ldr     r2, [r1, #HW_AHCI_IS_OFFSET]    ; clear this bit
        teq     r2, #0                          ; passing on
        moveq   pc, lr                          ; not this irq src .. pass it on
        MSR     CPSR_c, #I32_bit + SVC32_mode   ; svce mode irq off
        DMB
        Push    "r0, r4, r5,r6,r7,r8, r9, lr"   ; inc svce mode lr
        mov     r5, r1
        mov     r3, #(1<<BIT_AHCI_GHC_AE)       ; global IE mask off
        str     r3, [r5, #HW_AHCI_GHC_OFFSET]   ; stop any more irqs for now
; acknowledge the irq
        ldr     r0, ChipIRQDevice
        Push    "r2,r12"
        ldr     r9, HAL_SB
        mov     lr, pc
        ldr     pc, HAL_IRQClear_p              ; n.b. r0-r3 corrupted
        Pull    "r2,r12"
        str     r2, [r5, #HW_AHCI_IS_OFFSET]    ; clear this bit
AHCIIrqNotDone
        ldr     r3, [r5, #HW_AHCI_P0IE_OFFSET]  ; current irq enable mask
        ldr     r1, [r5, #HW_AHCI_P0IS_OFFSET]  ; current irq status
; at this point
; r1 = P0IS contents
; r3 = P0IE value in use
        ands    r1, r1, r3                      ; only clear irqs that can
        beq     AHCIIrqDone                      ; its not interrupting
        MSR     CPSR_c, # SVC32_mode            ; svce mode irq on again

; we've got an acceptable irq ... process it
; r2 = active irq bits
        DMB                                     ; keep our knowledge current...
        ldr     r0, [r5, #HW_AHCI_P0SERR_OFFSET]; get a copy of the err bits
        str     r0, [r5, #HW_AHCI_P0SERR_OFFSET]; ; and clear them
        str     r1, [r5, #HW_AHCI_P0IS_OFFSET]     ; clear any active irq bits
; DebugRegNCR r0, "AHCI-p0serr bits "
; DebugReg r1, "AHCI-irqs "
; dispatch the interrupts
; DHRS, PSS and DSS (and SDBS?) are all indicators that commands have completed
        tst     r1, #(1<<BIT_AHCI_P0IS_DHRS) + (1<<BIT_AHCI_P0IS_PSS) + (1<<BIT_AHCI_P0IS_DSS) + (1<<BIT_AHCI_P0IS_SDBS)
        blne    AHCICommandCompleter
;       tst     r1, #(1<<BIT_AHCI_P0IS_UFS)
;       blne    IRQ_BIT_AHCI_P0IS_UFS
        tst     r1, #(1<<BIT_AHCI_P0IS_PRCS)
        blne    IRQ_BIT_AHCI_P0IS_PRCS
        tst     r1, #(1<<BIT_AHCI_P0IS_PCS)
        blne    IRQ_BIT_AHCI_P0IS_PCS
;       tst     r1, #(1<<BIT_AHCI_P0IS_IPMS)
;       blne    IRQ_BIT_AHCI_P0IS_IPMS
;       tst     r1, #(1<<BIT_AHCI_P0IS_OFS)     ; TODO error processing
;       blne    IRQ_BIT_AHCI_P0IS_OFS           ; TODO error processing
;       tst     r1, #(1<<BIT_AHCI_P0IS_INFS)
;       blne    IRQ_BIT_AHCI_P0IS_INFS
        tst     r1, #(1<<BIT_AHCI_P0IS_IFS) + (1<<BIT_AHCI_P0IS_HBDS) + (1<<BIT_AHCI_P0IS_HBFS) + (1<<BIT_AHCI_P0IS_TFES)
        blne    IRQ_FatalError
; check for more interrupts
;        mov    r2, #(1<<BIT_AHCI_IS_IPS)
;        str    r2, [r5, #HW_AHCI_IS_OFFSET]    ; clr master irq bit if set
;       ldr     r3, [r5, #HW_AHCI_P0IE_OFFSET]  ; current irq enable mask
;       ldr     r1, [r5, #HW_AHCI_P0IS_OFFSET]  ; current irq status
;
;; at this point
;; r1 = P0IS contents
;; r3 = P0IE value in use
;       ands    r1, r1, r3                      ; only check irqs that can
        b       AHCIIrqNotDone                   ; its  interrupting

; at this point r3 = mask register contents to restore
AHCIIrqDone     ROUT
        ;
; DebugReg r1,"done "
        MSR     CPSR_c, #I32_bit + SVC32_mode   ; svce mode irq off again
        mov     r3, #(1<<BIT_AHCI_GHC_AE)+(1<<BIT_AHCI_GHC_IE); global IE enable
        str     r3, [r5, #HW_AHCI_GHC_OFFSET]   ; let it irq now
        DMB
        Pull    "r0,r4,r5,r6,r7,r8,r9,lr"           ; regs + svce mode lr
        MSR     CPSR_c, #I32_bit + IRQ32_mode       ; back to irq32 mode
        Pull    "pc"

;
IRQ_BIT_AHCI_P0IS_PRCS ROUT
        Entry   "r0-r1"

; DebugTX "PRCS-IRQ "
        ldr     r1, =((1<<BIT_AHCI_P0SERR_DIAG_N)+(1<<BIT_AHCI_P0SERR_ERR_C))
        teq     r0, r1
        EXIT    NE
; default to dev 0
        ldr     r0, AHCIDevRdy
        bic     r0, r0, #1<<0           ;device 0
        str     r0, AHCIDevRdy

        bl      KillIDReCall

        ldrb    r0, CCcallbackstate     ; pending callback to AHCICommandRoutine?
        teq     r0, #cb_pending         ; still pending?
        adreql  r0, AHCICommandCompleter
        moveq   r1, r12
        swieq   XOS_RemoveCallBack      ; ok clean up
; assume device 0 ATM
        mov     r0, #0
        bl      SSRemove                ; remove any registered scsisoft device

; DebugTX " comms err, device gone"
        EXIT

; port change status
IRQ_BIT_AHCI_P0IS_PCS ROUT
        Entry   "r0-r1"
        mov     r0, #(1<<BIT_AHCI_P0SERR_DIAG_X)
        str     r0, [r5, #HW_AHCI_P0SERR_OFFSET] ; and clear them
        ldr     r0, [r5, #HW_AHCI_P0SSTS_OFFSET] ; read link state
        and     r0, r0, #&f                     ; isolate state bits
        teq     r0, #SSTS_DET_det               ; dev present, not initialised
        moveq   r1, #0                          ; no action requested
        streq   r1, [r5, #HW_AHCI_P0SCTL_OFFSET] ; tell it to go on
; DebugTXS "PCS-IRQ"
        teq     r0,#SSTS_DET_det
        bne     %ft2
; DebugTXS " dev there, not init "
        ldr     r0, [r5, #HW_AHCI_P0SCTL_OFFSET]
; DebugRegNCR r0, ""
        teq     r0, #AHCI_P0SCTL_DET_cominit
        EXIT    EQ
; DebugTXS " set it moving "
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        bic     r0, r1, #(1<<BIT_AHCI_P0CMD_ST)
        str     r0, [r5, #HW_AHCI_P0CMD_OFFSET] ; clear start bit
; DebugRegNCR r0, ""
        mov     r0, #AHCI_P0SCTL_DET_cominit    ; set so that when device seen it initialises
        str     r0, [r5, #HW_AHCI_P0SCTL_OFFSET]
; DebugRegNCR r0, ""
        orr     r1, r1, #(1<<BIT_AHCI_P0CMD_ST) ; force it to be active
        str     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        mov     r0, #1*1024               ; Wait 1ms for COMRESET signal
        bl      HAL_CounterDelay
; DebugReg r0, ""
        mov     r0, #0
 EXIT
2
 teq r0, #SSTS_DET_PhyRdy
 EXIT NE
; DebugTX " dev ready"
; default to dev 0
        ldr     r0, AHCIDevRdy
        tst     r0, #1<<0               ; check device 0
        EXIT    NE                      ; already ready
        orr     r0, r0, #1<<0
        str     r0, AHCIDevRdy          ; mark as ready
; device just became ready. set callback to do Identify command
; which will report device ready when done
        mov     r0, #0
;*************************
        strb    r0, IDcallbackport      ; ******** force port 0 atm
        bl      AddIDReCall

        EXIT

; Fatal error handling
; as per section 6.2.2.1 of AHCI spec
; Will need updating if we add NCQ support
IRQ_FatalError  ROUT
        Entry   "r0-r9"
;        DebugReg r1, "IRQ_FatalError PxIS="
        mov     r2, #0                  ; Flag that COMRESET is optional
        mov     r3, #0                  ; Resume all commands
001
;        swi     XOS_ReadMonotonicTime
;        DebugReg r0, "time="
        ; Read PxCI to see which commands are still outstanding
        ldr     r6, [r5, #HW_AHCI_P0CI_OFFSET]
;        DebugReg r6, "PxCI="
        bic     r6, r6, r3
        ; Read PxCMD.CCS to determine the slot that had the error
        ldr     r7, [r5, #HW_AHCI_P0CMD_OFFSET]
;        DebugReg r7, "PxCMD="
        ubfx    r8, r7, #BIT_AHCI_P0CMD_CCS, #5
        ; Reset PxCI
        bic     r7, r7, #(1<<BIT_AHCI_P0CMD_ST)
        str     r7, [r5, #HW_AHCI_P0CMD_OFFSET]
        mov     r3, #500                ; 500 ms max
003
        MOV     r0, #1*1024 ; 1 msec ish
        bl      HAL_CounterDelay
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        tst     r1, #(1<<BIT_AHCI_P0CMD_CR)
        beq     %ft004
        subs    r3, r3, #1
        bgt     %bt003                  ; not done yet
;        DebugTX "PxCI reset timeout!"
        ; AHCI spec 10.4.2 claims this isn't a fatal condition, so carry on
004
        ; Clear PxSERR and PxIS
        ; already handled by main IRQ code, but let's do it again just to make sure
        ldr     r0, [r5, #HW_AHCI_P0SERR_OFFSET]
        str     r0, [r5, #HW_AHCI_P0SERR_OFFSET]
        ldr     r1, [r5, #HW_AHCI_P0IS_OFFSET]
        str     r1, [r5, #HW_AHCI_P0IS_OFFSET]
        ; Check if we need to issue COMRESET
        ldr     r0, [r5, #HW_AHCI_P0TFD_OFFSET]
;        DebugReg r0, "PxTFD="
        tst     r0, #(1<<P0TFD_STA_busy) + (1<<P0TFD_STA_DRQ)
        teqeq   r2, #0
        beq     %ft050
;        DebugTX "COMRESET required"
        ; From AHCI spec 10.4.2 (Port Reset)
        ; ST is already cleared, so proceed with writing to SCTL to initiate COMRESET
        ldr     r1, [r5, #HW_AHCI_P0SCTL_OFFSET]
        bic     r1, r1, #AHCI_P0SCTL_clear
        orr     r0, r1, #AHCI_P0SCTL_DET_cominit
        str     r0, [r5, #HW_AHCI_P0SCTL_OFFSET]
        dsb
        mov     r0, #1*1024               ; Wait 1ms for COMRESET signal
        bl      HAL_CounterDelay
        orr     r0, r1, #AHCI_P0SCTL_DET_none
        str     r0, [r5, #HW_AHCI_P0SCTL_OFFSET]
        ; Wait for device to reconnect
        ; TODO wait for how long?
        mov     r2, #1024
010
        mov     r0, #1500                 ; 1.5ms
        bl      HAL_CounterDelay
        ldr     r0, [r5, #HW_AHCI_P0SSTS_OFFSET]
        and     r0, r0, #&f
        teq     r0, #SSTS_DET_PhyRdy
        beq     %ft040
        subs    r2, r2, #1
        bne     %bt010
;        DebugReg r0, "COMRESET timeout, DET="
040
        ; Clear any errors generated as part of the reset
        mov     r0, #-1
        str     r0, [r5, #HW_AHCI_P0SERR_OFFSET]
050
        ; Re-enable PxCMD
        ldr     r0, [r5, #HW_AHCI_P0CMD_OFFSET]
        orr     r0, r0, #(1<<BIT_AHCI_P0CMD_ST)
;        DebugReg r0, "PxCMD now="
        str     r0, [r5, #HW_AHCI_P0CMD_OFFSET]
        ; Re-issue the commands that were in progress
        ; First-pass: just reset the PxCI bits and PRD byte counts
        ; This should work fine as long as we don't have multiple commands
        ; queued against the same device (or we don't mind them being performed
        ; out-of-order). For other cases we'll have to re-order the commands
        ; to take into account the fact the controller will resume execution
        ; starting from slot 0.
        movs    r0, r6
        beq     %ft090                  ; Not sure if this can happen, but deal with it anyway
        mov     r2, #&80000000
        ldr     r3, ChipP0CLB
        add     r3, r3, #31*32          ; Point at last entry for clz usage
        mov     r4, #0
060
        clz     r1, r0
        bics    r0, r0, r2, lsr r1
        sub     r1, r3, r1, lsl #5
;        DebugReg r1, "Clearing "
        str     r4, [r1, #cmdH_prdbc]   ; Reset byte count
;      [ Debug
;        teq     r0, #0
;      ]
        bne     %bt060
;        DebugTX "Re-enabling channels"
        DMB_Write                       ; Ensure byte count reset
        str     r6, [r5, #HW_AHCI_P0CI_OFFSET]
090
;        swi     XOS_ReadMonotonicTime
;        DebugReg r0, "time="


        EXIT

IRQ_FatalError_AltEntry ALTENTRY
        mov     r2, #1                  ; Flag that COMRESET required
        mov     r3, #0                  ; Resume all commands
        b       %bt001

IRQ_FatalError_AltEntry2 ALTENTRY
        mov     r2, #0                  ; Flag that COMRESET optional
                                        ; r3 already set to mask of commands to not resume
        b       %bt001

; Issue a software reset to a port using the Register FIS method
; (used e.g. for resetting a specific device, or for detecting
;  the presence of a port multiplier)
; on entry, r0=port
; exit r0=0 if OK, else NZ
AHCI_SWReset    ROUT
        Entry   "r5, r8"
        ldr     r5, ChipBase
; 1 makesure all other stuff has completed, or been killed


; 2 clear ST bit and wait port idle (CR=0)
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        bic     r0, r1, #(1<<BIT_AHCI_P0CMD_ST)
        str     r0, [r5, #HW_AHCI_P0CMD_OFFSET]
1       ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        tst     r1, #(1<<BIT_AHCI_P0CMD_CR)
        bne     %bt1                            ; this ought 0 fairly quickly ****************
; set the slot logic to start at 0 again.. which it'll do when ST set 1
        mov     r8, #32
        strb    r8, LastLoadedSlot            ; restarts at 0

; build 2 H2D Reg  FIS
; ensure STS.Bsy and STS.DRQ cleared; if not then attempt port reset
; or set CLO bit for port, then set ST bit


        EXIT




;;;temp import.. not yet used
; on entry, r0=port
; exit r0=0 if OK, else NZ
AHCI_Reset      ROUT
        Entry   "r1-r3, r5,r8,r9"
        ldr     r5, ChipBase
        mov     r1, #AHCI_CLB_SIZE
        mul     r1, r0, r1
        add     r5, r5, r1                      ; compute required base address
001     ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
;   DebugReg r1, "P0CMD "
        bic     r1, r1, #(1<<BIT_AHCI_P0CMD_ST)
        str     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        mov     r3, #500                ; 500 ms max
003
        MOV     r0, #1*1024 ; 1 msec ish
        bl      HAL_CounterDelay
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        tst     r1, #(1<<BIT_AHCI_P0CMD_CR)
        beq     %ft004
        subs    r3, r3, #1
        bgt     %bt003                  ; not done yet
        ; timeout if here
        mov     r0, #1
        EXIT
004
        mov     r0, #AHCI_P0SCTL_DET_cominit    ; set so that when device seen it initialises
        str     r0, [r5, #HW_AHCI_P0SCTL_OFFSET]
        orr     r1, r1, #(1<<BIT_AHCI_P0CMD_ST)
        str     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        mov     r0, #0
        EXIT

; call the hal counter delay routine
; delay in r0 in uS
HAL_CounterDelay ROUT
        Entry   "r0-r3,r9,r12"
        ldr     r9, HAL_SB
        mov     lr, pc
        ldr     pc, HAL_CounterDelay_p
        EXIT

; done on a per-port basis..
; on entry, r5->port register set
; exit r0=0 if OK, else NZ
CheckAHCIIdle   ROUT
        Entry   "r1-r3, r5"
001     ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        tst     r1, #(1<< BIT_AHCI_P0CMD_HPCP)
        beq     %ft002                          ; hotplug not supported
;   DebugTX "HotPlug supported "
002
        ; check if idle
        ldr     r3, = ((1<<BIT_AHCI_P0CMD_ST)+(1<<BIT_AHCI_P0CMD_CR)+(1<<BIT_AHCI_P0CMD_FRE)+(1<<BIT_AHCI_P0CMD_FR))
        tst     r1, r3                          ; is it already idle?
        moveq   r0, #0
        EXIT    EQ
        ; OK.. so push port to idle
        ; 1 clear start bit and await CR bit 0
        bic     r1, r1, #(1<<BIT_AHCI_P0CMD_CR)
        str     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        mov     r3, #500                ; 500 ms max
003
        MOV     r0, #1*1024 ; 1 msec ish
        BL      HAL_CounterDelay
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        tst     r1, #(1<<BIT_AHCI_P0CMD_CR)
        beq     %ft004
        subs    r3, r3, #1
        bgt     %bt003                  ; not done yet
        ; timeout if here
        mov     r0, #1
        EXIT
004
        tst     r1, #(1<<BIT_AHCI_P0CMD_FRE) ; FIS rx enabled?
        beq     %ft005
        mov     r3, #500                ; 500 ms max
006
        MOV     r0, #1*1024 ; 1 msec ish
        BL      HAL_CounterDelay
        ldr     r1, [r5, #HW_AHCI_P0CMD_OFFSET]
        tst     r1, #(1<<BIT_AHCI_P0CMD_FR)
        beq     %ft005
        subs    r3, r3, #1
        bgt     %bt006                  ; not done yet
005
        mov     r0, #0
        EXIT

; get next available command slot starting at 'LastLoadedSlot'
; return EQ and r8 = slot number if OK
; else return NE
; r5->ChipBase
GetNextFreeSlot ROUT
        Entry   "r6,r7"
; find next unused slot from AHCI_P0CI register
        ldr     r5, ChipBase
        ldr     r7, [r5, #HW_AHCI_P0CI_OFFSET]
; DebugRegNCR r7, "CI at start "
        mov     r6, #0
        ldrb    r8, LastLoadedSlot
        mov     lr, #1
2       add     r8, r8, #1
        and     r8, r8, #32-1   ; cycle around
        tst     r7, lr, lsl r8
        EXIT    EQ              ; free slot found
        addne   r6, r6, #1
        cmp     r6, #31
        ble     %bt2
        EXIT

; BuildAHCICmd assembles a ahci command and first PRD
; and returns its command table index
; on entry
; fill in and trigger a command
; on entry
; r0 -> dma address
; r1 = LBA start address
; r2 = length in bytes + bit 31 = 1 if read, 0 if write
; r3 = ATAPI_Cmd + features<<8
; or if r3 > &ffff
; r3 -> word aligned rma buffer address with max 16 scsi command bytes in it
;       it should be an atapi packet scsi command
; r5 = timeout in centiseconds if foreground, or callbackhandle if background
; r6 -> routine to call back when done or 0 to wait in forground
; r7 = r12 value to use  if r6 nz
; r9 = scsi ID word for FG/BG and scatter flags and scsi ID
;
; return r0 = slot number, r9->CBTab for this command
; on error, return r0 = error info (SCSI status byte/error number), r9 = 0, V set/not set
;
BuildAHCICmd    ROUT
        Entry   "r1-r8, r10"
; DebugReg r7, "at start "
; DebugRegNCR r0, "In0: "
; DebugRegNCR r1, "1: "
; DebugRegNCR r2, "2: "
; DebugRegNCR r3, "3: "
; DebugRegNCR r4, "4: "
; DebugRegNCR r5, "5: "
; DebugRegNCR r6, "6: "
; DebugRegNCR r7, "7: "
; DebugRegNCR r8, "8: "
; DebugReg r9, "9: "
        bl      UnCache
        movvs   r9, #0
        EXIT    VS
      [ :LNOT: OSMem19 ; OSMem19 version has builtin check for this
        ldr     lr, [r2, #UcPblkC]
        cmp     lr, #MaxPRDTCount
        bhi     %ft90
      ]
; ahciCMDTab is 256byte aligned, and atleast 128 bytes long. followed by 1 or
; more 16byte ahciPRDs
; so if each cmdTab is 256 aligned, it can have up to 8 PRD things in each
; 256 aligned. so at 4 per K we need 8k of protocol space to have a hard
; mapping, giving MAX_AHCI_PROTOCOL_SIZE as 8 + 1k = 9k for ease
; build ahciCMDTab
        ASSERT  MAX_AHCI_PROTOCOL_SIZE >=(1024 + (32*512) +256)
; find next unused slot from AHCI_P0CI register
        bl      GetNextFreeSlot
        beq     %ft1

        ; Ran out of free slots
        ; Return QueueFull error
        ; TODO: This is only a valid error code if we already have a request queued for this SCSI device - will therefore be wrong if we have a port multiplier and all slots are taken by other devices
      [ OSMem19
        mov     r0, #-1
        str     r0, [r2, #Mem19Ctx_PRDTIndex]
      |
        mov     r0, #0
        str     r0, [r2, #UcSpRdAddr]
        mov     r0, #1<<31
        str     r0, [r2, #UcFlags]
      ]
        mov     r0, r2
        bl      ReCache                 ; ReCache without copying anything into output buffer
        XSCSIError SCSI_QueueFull
        mov     r9, #0
        EXIT

1
; DebugReg r8, "Use slot  "
; index to commandheader and populate as far as we can
        mov     r7, r9
        mov     r9, #CBBSize
        adrl    r6, CBTab
        mla     r9, r8, r9, r6          ; R9 -> current CBTab
        str     r2, [r9, #CBCachePtr-CBTab] ; ReCache ptr
        str     r7, [r9, #CBR0Value-CBTab]  ; R0 value at start
; recover and populate any callback stuff
        add     lr, sp, #4*4            ; index to r5, r6, r7 on stack
        ldmia   lr, {r4, r6, lr}        ; get the callback and timeout stuff
        stmia   r9, {r4, r6, lr}        ; to the CBTab
        tst     r7, #(1<<BackgroundBit)
        bne     %ft1                    ; r5 value not a timeout in background
        swi     XOS_ReadMonotonicTime
        cmp     r4, #0                  ; timeout supplied?
        moveq   r4, #MaxCmdTimeout      ; no... timeout anyway for safety
        add     r4, r4, r0              ; yes.. do some updating
        str     r4, [r9, #CBToutOrHandl-CBTab]  ; record value of our ticker
                                                ; at completion
; DebugReg r4, "usetimeout "
1       ldr     lr, ChipP0CLB
        add     r6, lr , r8, lsl #5     ; 32 bytes per header
; r6 = table address, r8 = table index
; DebugReg r6, "tab addr "
; r2 still -> os+memory0 pagetable stuff with a list of physical addresses
        str     r6, [r9, #CBSlotAddr-CBTab] ; remember
; DebugRegNCR r7, "SCSIID wrd: "
        tst     r7, #1<<4                       ; is ID a port num?
        and     r4, r7, #&f                     ; isolate SCSI ID
        adreql  lr, AHCIPortFields
        ldreqb  r4, [lr, r4]                    ; get port for this scsi ID
        ldr     lr, ChipRXFis
        mov     r7, #AHCI_RX_FIS_Size
        mul     r7, r7, r4
        add     r7, lr, r7
        str     r7, [r9, #CBRXFisAddr-CBTab]    ; remember rx FIS buffer
        mov     r4, r4, lsl #cmdH_info_pmp
; DebugReg r4, "port+ID "
      [ OSMem19
        ldr     lr, [r2, #Mem19Ctx_PRDTIndex]
        add     lr, lr, #1
      |
        ldr     lr, [r2, #UcPblkC]              ; recover prdt count
      ]
        orr     r4, r4, lr, lsl #cmdH_info_prdtl; PRDT count to place
        orr     r4, r4, #fisT_RFIS_H2D_len
        FRAMLDR lr,,r2                          ; get r2 value off stack
        tst     lr, #1<<31
        orreq   r4, r4, #(1<<cmdH_info_write)
        cmp     r3, #&10000                     ; pointer to scsibytes buffer?
        orrge   r4, r4, #(1<<cmdH_info_atapi)
        str     r4, [r6, #cmdH_info]
        bic     r4, lr, #1<<31          ; total byte count requested across all prds
; tst r4, #1
; addne r4, r4, #1
        str     r4, [r9, #CBR4Cnt-CBTab]
; DebugReg r4, "completed count expected "
; now get command table address .. 256 byte alignedchunk offset from end of header table
; now locate command table address and populate it
        ldr     r4, ChipP0CLB           ; logical mem address
        add     r4, r4 , r8, lsl #MaxPRDTl2shift        ;  bytes per table
        add     r4, r4, #AHCI_CMD_HEADER_SIZE * 32 ; 32 headers too
        str     r4, [r9, #CBCmdTabAddr-CBTab] ; remember
        ldr     lr, ChipL2POffset
        sub     lr, r4, lr              ; convert to physical for dma use
        str     lr, [r6, #cmdH_ctba]
        mov     lr, #0
        str     lr, [r6, #cmdH_prdbc]   ; init count of bytes transferred
        str     lr, [r6, #cmdH_ctba_u]
; r4 now -> cmd table base
; DebugReg r4, "commandtab base "
; clear it
        mov     r7, #ahciCMDT_SIZE-4
        mov     lr, #0                  ;
1       str     lr, [r4, r7]            ; blank before starting
        subs    r7, r7, #4
        bge     %bt1

        mov     lr, #fisT_RFIS_H2D
        strb    lr, [r4, #fisType]
        mov     lr, #&80
        strb    lr, [r4, #pmPort_Cbit]
; check if it is a scsi command
        cmp     r3, #&10000             ; test if scsicmd given
        blt     %ft2                    ; no.. atapi normal command
; looks like a scsi command
        ldr     lr, [r3]                ; copy it
        str     lr, [r4, #ahciCMDT_acmd]
        ldr     lr, [r3, #4]
        str     lr, [r4, #ahciCMDT_acmd+4]
        ldr     lr, [r3, #8]
        str     lr, [r4, #ahciCMDT_acmd+8]
        ldr     lr, [r3, #12]
        str     lr, [r4, #ahciCMDT_acmd+12]

        mov     r3, #ATAPI_COMMAND_PACKET
        ; at this point r3 contains command and feature byte(s)
        ; 8 bit command (byte0)
        ; 8 bit feature (byte1) for 28bit commands (then byte2=0)
        ; 16 bit feature (bytes 1 and 2) for 48 bit commands
2       ldr     lr, DevFeatures
        tst     lr, #DevFeature48bit    ; nz if 48bit addressing
        strb    r3, [r4, #command]
        mov     r3, r3, lsr #8
        strb    r3, [r4, #features]
        mov     r3, r3, lsr #8
        strb    r3, [r4, #featuresExp]
        strb    r1, [r4, #lbaLow]       ; LBA start address 32bit
        mov     r1, r1, lsr #8
        strb    r1, [r4, #lbaMid]
        mov     r1, r1, lsr #8
        strb    r1, [r4, #lbaHigh]
        mov     r1, r1, lsr #8
        biceq   r1, r1, #&c0
        mov     r3, #&40
        orreq   r3, r3, r1              ; top 6 bits combined into device field
        strb    r3, [r4, #device]       ; for 28bit addressing

        moveq   r1, #0                  ; set top bits to 0 if 28bit addressing
        strb    r1, [r4, #lbaLowExp]
        mov     r1, r1, lsr #8
        strb    r1, [r4, #lbaMidExp]
        mov     r1, r1, lsr #8
        strb    r1, [r4, #lbaHighExp]
; get the dma stuff to place before we continue further
; dma address to place
; get physical address first
; r0, r1, r3, r6, r7, lr available
;; at this point the physical table has already been built, with required byte count per entry
; attached to the address
; DebugRegNCR r2, "pointer "
      [ OSMem19
        ldr     r1, [r2, #Mem19Ctx_PRDTIndex]
        add     r1, r1, #1
        add     r3, r2, #Mem19Ctx_PRDT
      |
        ldr     r1, [r2, #UcPblkC]      ; prdt count
        add     r3, r2, #8 + LABOffset  ; offset to first physical address
      ]
; DebugReg r1, "prdtCount "
        add     r7, r4, #ahciPRD_dba+ahciCMDT_prdt
; now pointing at first prdt
2
; DebugRegNCR r1, "prdt left "
; DebugRegNCR r2, "TOTcount left "
      [ OSMem19
        ldmia   r3!, {r0, r6}           ; get address, length
        bic     r6, r6, #1:SHL:31       ; clear bounce flag
      |
        ldr     r0, [r3], #12           ; get address
        ldr     r6, [r3,# -20]          ; get byte count
      ]
; DebugRegNCR r7, "PrdtAdd "
; DebugRegNCR r0, "PAStart "
; DebugRegNCR r6, "PAcount "
        str     r0, [r7], #ahciPRD_dbau-ahciPRD_dba
        mov     r0, #0
        str     r0, [r7], #ahciPRD_info-ahciPRD_dbau
        sub     r0, r6, #1
; DebugReg r0, "dbcnt "
; Debug RamSave lr, r0
        subs     r1, r1, #1              ; count down
        str     r0, [r7], #ahciPRD_SIZE-ahciPRD_info
        bgt     %bt2                    ; more chunks
; whole list now done
; tst r0, #1
; bne %ft222
; FRAMLDR lr,,r2
; tst     lr, #1<<31
; beq %ft223
; DebugRegNCR r0, "final READ dbcnt not mod 16****** "
; b %ft224
;223
; DebugRegNCR r0, "final Write dbcnt not mod 16****** "
;224
222     str     r0, [r7,#-(ahciPRD_SIZE-ahciPRD_info)]
      [ OSMem19
        ldr     r10, [r2, #Mem19Ctx_PRDTLen]
      |
        ldr     r10, [r2, #UcXferCount] ; required byte count
      ]
; DebugRegNCR r0, "used"
; DebugReg r10, "Discovered bytecount2 "
        mov     r3, #SecLen
        sub     r3, r3, #1
        tst     r10, r3                 ; any partial sector?
        mov     r3, r10, lsr #L2SecSize ; shift down to sectors
        addne   r3, r3, #1              ; if partial sector, round up
; DebugRegNCR r10, "byte count "
; DebugReg r3, "sec count "
        strb    r3, [r4, #sectorNum]
        mov     r3, r3, lsr #8
        strb    r3, [r4, #sectorNumExp]

; DebugRegNCR r4, "cmdtab "

;        ldr     r7, [r5, #HW_AHCI_P0CMD_OFFSET]
;        orr     r7, r7, #(1<<BIT_AHCI_P0CMD_ST)
;        str     r7, [r5, #HW_AHCI_P0CMD_OFFSET] ; ensure ST bit set
; DebugRegNCR r1, "cmdtabx "
        mov     r4, #1
        mov     r7, r4, lsl r8
        strb    r4, [r9, #CBFGDone-CBTab]       ; flag command not completed
        strb    r8, LastLoadedSlot              ; remember
        DMB_Write                               ; ensure commands fully written
        str     r7, [r5, #HW_AHCI_P0CI_OFFSET]  ; set slot bit to trigger commnd
                                                ; (we can only write to 1..
        mov     r0, r8                          ; return slot number
; DebugReg r0, "Slot "
        CLRV
        EXIT

 [ :LNOT: OSMem19
90
        ; Too many PRDs
        ; so really need to break transfer into smaller chunks
;        DebugTX "Too many PRDs"
        mov     r0, #0
        str     r0, [r2, #UcSpRdAddr]
        mov     r0, #1<<31
        str     r0, [r2, #UcFlags]
        mov     r0, r2
        bl      ReCache                 ; ReCache without copying anything into output buffer
        XSCSIError SCSI_CC_UnKn
        mov     r9, #0
        EXIT
 ]

; AHCICommandCompleter
; called whenever a command complete irq happens
; determines which command slot is done, and calls back relevant
; routine if required .. done in irq time,
; anything that'll take a while will need to be done in a callback
; direct entry point
AHCICommandCompleterDirect ROUT
        Entry   "r0-r7"
        ldrb    r0, CCcallbackstate     ; pending callback to AHCICommandRoutine?
        teq     r0, #cb_pending         ; still pending?
        bne     %ft1
        adrl    r0, AHCICommandCompleter
        mov     r1, r12
        swi     XOS_RemoveCallBack      ; ok clean up
        B       %ft1
; entry from callback
AHCICommandCompleter
        ALTENTRY
1       mov     r0, #cb_unrequired      ; flag we got here
        strb    r0, CCcallbackstate
; DebugTXS  ">"
        ldr     r3, ChipBase
1       ldrb    r0, LastClearedSlot
; DebugRegNCR r0, "lcs was "
        ldrb    r1, LastLoadedSlot
; DebugReg r1, "lls was "
        teq     r0, r1                  ; if  the same, we've processed it
        bne %ft33
; DebugReg r1, "lls was "
; teq r0,r0


        EXIT    EQ
33
        add     r0, r0, #1
        and     r0, r0, #&1f            ; cycle
        strb    r0, LastClearedSlot
; DebugReg r0, "completerslot "
; now check if this slot has completed
        ldr     r2, [r3, #HW_AHCI_P0CI_OFFSET]
; DebugReg r2, "sldn "
        mov     r1, #1
        tst     r2, r1, lsl r0          ; check slot done
        EXIT    NE                      ; no .. not yet done

; do the completion stuff for this slot
; r0 = slot number
; r5 = ChipBase
; In particular, check how far it got and update any pointers
; with the result. or flag an error.
; if a further command is needed, trigger it
; get the slot callback base to r2
; DebugTXS ".."
; DebugReg r0, "completerslot "
        mov     r1, #CBBSize
        mul     lr, r1, r0                      ; compute buffer offset
        adrl    r2, CBTab
        add     r2, r2, lr
        ldr     r0, [r2, #CBCachePtr-CBTab]
        mov     lr, #0
        teq     lr, r0                          ; got a pointer?
        strne   lr, [r2, #CBCachePtr-CBTab]     ; yes.. null it and
        blne    ReCache                         ; use it
        ldr     r0, [r2, #CBSlotAddr-CBTab]
; DebugReg  r0, "SlotAddr "
; right.. where did we get to?
        ldr     r5, [r2, #CBCmdTabAddr-CBTab]
; DebugReg  r5, "CmdTabAddr "
        ldr     r5, [r0, #cmdH_prdbc]           ; bytes transferred
; DebugRegNCR r5, "transferred "
        ldr     r4, [r2, #CBR4Cnt-CBTab]
; DebugRegNCR r4, "Asked "
        subs    r4, r4, r5                      ; compute what is left
        movlt   r4, #0                          ; negative byte count unhelpful
; DebugRegNCR r4, "Bytes left "
        str     r4, [r2, #CBR4Cnt-CBTab]
        strleb  r4, [r2, #CBFGDone-CBTab]       ; flag command completed
; DebugReg r4, "final Bytes left "
        ldr     r0, [r2, #CBR0Value-CBTab]      ; lets see what was requested

; DebugTX ""  ; delineate command end

;
; ldrb  r5, [r2, #CBFGDone-CBTab]       ; flag command completed
; DebugByteReg r5,      "CompletedFlag? "

; DebugReg  r0, "R0 val "
        tst     r0, #(1<<BackgroundBit)         ; Background?
        beq     %bt1                            ; no ..
; DebugTX "Backgrounding not yet implemented "

; if command required a callback, arrange that too,
; and cancel any timeout stuff
        ldmia   r2, {r5, r6, r7}                ; get handle, CB addr and r12
; DebugRegNCR r5, "CBhandle "
; DebugRegNCR r6, "CHAddr"
; DebugReg r7, "User R12"
        mov     lr, #0
        str     lr, [r2, #CBAddr-CBTab]         ; ensure cancelled
        str     lr, [r2, #CBToutOrHandl-CBTab]  ; and its timeout
        teq     r6, #0                          ; something to call?
        beq     %bt1
; callback in svce irqoff mode
        MSR     CPSR_cf, #I32_bit + SVC32_mode  ; svce mode irq off, V clear
        Push    "r12"
        adr     lr, %ft11
        mov     r12, r7                         ; r4 is bytes left
        mov     r0, #TARGET_GOOD                ; r0 will be error status
        mov     pc, r6                          ; go to background callback
11
        Pull    "r12"
        MSR     CPSR_c, # SVC32_mode            ; svce mode irq on again
        b       %bt1                            ; look at the next

; Abort a command by resetting the port
; In: r9 -> command block
AbortCommand
        Entry   "r0-r5"
        ; Temp disable any controller IRQs
        ldr     r5, ChipBase
        mov     r3, #(1<<BIT_AHCI_GHC_AE)
        str     r3, [r5, #HW_AHCI_GHC_OFFSET]
        ; Work out which slot we're aborting
        ldr     r0, ChipP0CLB
        ldr     r4, [r9, #CBSlotAddr-CBTab]
        sub     r0, r4, r0
        mov     r0, r0, lsr #5
        mov     r3, #1
        mov     r3, r3, lsl r0
;        DebugReg r3, "AbortCommand slot mask="
        ; Reset port without restarting this slot
        bl      IRQ_FatalError_AltEntry2
        ; Restore IRQs
        mov     r3, #(1<<BIT_AHCI_GHC_AE)+(1<<BIT_AHCI_GHC_IE)
        str     r3, [r5, #HW_AHCI_GHC_OFFSET]
        ; Claim 0 bytes transferred
        mov     r0, #0
        str     r0, [r4, #cmdH_prdbc]
        ; Run command completer in order to ensure slot flagged as done
        ; TODO - IRQ hole here where slot could get reused before we finish with ReCache etc.?
        ; TODO - Will need updating if we add support for background transfers - to return proper status in callback
        bl      AHCICommandCompleter

        EXIT

        LTORG

; [ Debug
;        MACRO
;        DumpHWReg $reg
;        ldr     r0, [r1, #HW_AHCI_$reg._OFFSET]
;        DebugReg r0, "$reg="
;        MEND
;
;DumpAllHWRegs
;        ; Dump "all" regs (doesn't dump PHY regs)
;        Entry   "r0-r1"
;        ldr     r1, ChipBase
;        DumpHWReg CAP
;        DumpHWReg GHC
;        DumpHWReg IS
;        DumpHWReg PI
;        DumpHWReg VS
;        DumpHWReg CCC_CTL
;        DumpHWReg CCC_PORTS
;        DumpHWReg CAP2
;        DumpHWReg BISTAFR
;        DumpHWReg BISTCR
;        DumpHWReg BISTFCTR
;        DumpHWReg BISTSR
;        DumpHWReg OOBR
;        DumpHWReg GPCR
;        DumpHWReg GPSR
;        DumpHWReg TIMER1MS
;        DumpHWReg TESTR
;        DumpHWReg VERSIONR
;        PullEnv
;        ; Fall through into DumpP0Regs
;
;DumpP0Regs
;        Entry   "r0-r1"
;        ldr     r1, ChipBase
;        DumpHWReg P0CLB
;        DumpHWReg P0FB
;        DumpHWReg P0IS
;        DumpHWReg P0IE
;        DumpHWReg P0CMD
;        DumpHWReg P0TFD
;        DumpHWReg P0SIG
;        DumpHWReg P0SSTS
;        DumpHWReg P0SCTL
;        DumpHWReg P0SERR
;        DumpHWReg P0SACT
;        DumpHWReg P0CI
;        DumpHWReg P0SNTF
;        DumpHWReg P0DMACR
;        DumpHWReg P0PHYCR
;        DumpHWReg P0PHYSR
;        EXIT
; ]

        END
