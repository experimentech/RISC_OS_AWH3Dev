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
        GET     SCSICMD
        GET     Portable
        GET     SCSIErr


; init any scsisoft stuff
SSInit  ROUT
        Entry
        adrl    r1, SCSIIDFields
        mov     lr, #-1
        str     lr, [r1, #0]
        str     lr, [r1, #4]
        str     lr, [r1, #8]
        str     lr, [r1, #12]
        adrl    r1, AHCIPortFields
        mov     lr, #-1
        str     lr, [r1, #0]
        str     lr, [r1, #4]
        str     lr, [r1, #8]
        str     lr, [r1, #12]
        EXIT

; SSKill  get the driver offline before anything else is disabled
SSKill  ROUT
        Entry   "r0-r2"
        adrl    r1, SCSIIDFields
        mov     r2, #0
1       ldrb    r0, [r1 ,r2]
; DebugReg r0, "killing "
        teq     r0, #&ff
        movne   r0, r2
        blne    SSRemove
        add     r2, r2, #1
        cmp     r2, #16
        blt     %bt1
        EXIT

; register device as scsisoft device
; SSRegister
; on entry
; r0 = (bus expander) port ID, or 0 if none there
; on exit
; r0 = SCSI Device ID assigned
SSRegister      ROUT
        Entry   "r1-r3, r7,r8"
        and     r0, r0, #&f
        mov     r7, r0
; DebugReg r7, "reg port "
        adrl    r3, SCSIIDFields
        add     r8, r3, r0              ; index to relevant scsiid store
        adrl    r1, SSHandler
        mov     r2, r12
        mov     r3, r8                  ; 'r8' value
        mov     r0, #0                  ; ensure register as device, not bus
; DebugRegNCR r0, "RegDevice "
; DebugRegNCR r1, "R1 "
; DebugRegNCR r2, "R2 "
; DebugRegNCR r3, "R3 "
        swi     XSCSI_Register
        movvs   r3, #&ff
        movvc   r3, r0
        strb    r3, [r8]                ; remember this port's scsi ID, or &ff
        adrl    r8, AHCIPortFields
        strvcb  r7, [r8, r0]            ; and remember this ID's AHCI port

; DebugRegNCR r3,"Registered scsi ID "
; DebugReg r7," to port "
        EXIT


; remove device as scsisoft device
; SSRemove
; on entry
; r0 = AHCIDev number (0..15)
SSRemove        ROUT
        Entry   "r1-r3, r8"
; DebugReg r0, "dereg  "
        and     r0, r0, #&f
        adrl    r3, SCSIIDFields
        add     r8, r3, r0              ; index to relevant scsiid store
        ldrb    r0, [r8]
        teq     r0, #&ff                ; check if it is registered
        EXIT    EQ                      ; no..
        adrl    r3, AHCIPortFields
        mov     lr, #&ff
        strb    lr, [r3, r0]            ; blank ahci port for this ID
        strb    lr, [r8]                ; map out the scsi ID


        adrl    r1, SSHandler
        mov     r2, r12
        mov     r3, r8                  ; 'r8' value
; DebugRegNCR r0, "DerregID "
; DebugRegNCR r1, "R1 "
; DebugRegNCR r2, "R2 "
; DebugRegNCR r3, "R3 "
        swi     XSCSI_Deregister
; DebugReg r0," now Removed "
        EXIT


SSHandler       ROUT
        Push    "r1-r3,r5-r12, lr"      ; 0 and 4 used for return data
; DebugRegNCR r0, "SShandlerR0 "
        cmp     r11,#7                  ; largest entry number
        addls   pc, pc, r11, lsl #2
        b       %ft1                    ; too big
        b       SSFeatures
        b       %ft1                    ; bus reset not required
        b       %ft1
        b       %ft1
        b       SSFGOp
        b       SSBGOp
        b       SSBGCancel
        b       %ft1                    ; host description not required
1
        XSCSIError SCSI_SWIunkn
        Pull    "r1-r3,r5-r12, pc"      ; 0 and 4 used for return data

; if background ops supported then set r1 bit 1 and all ops will be background
; if scatter lists supported set r1 bit 5, and scatter list always used
SSFeatures
; DebugTX "Features "
        mov     r1, #(1<<5);((1<<1)+(1<<5))     ; backgrnd op , scatter lists
        str     r1, [sp]                ; r1 = return data
        mov     r0, #TARGET_GOOD        ; no error
        CLRV
        Pull    "r1-r3,r5-r12, pc"      ; 0 and 4 used for return data

; foreground OP
; r0
; 15..00        Device ID
;     20        inhibit identify message (parallelscsi)
;     21        inhibit disconnect (parallel scsi)
; 25..24        00 no data xfer, 10 read, 01 write, 11 reserved
;     26        1 => r3 -> scatter list, else dma address
;     27        0 => poll esc and abort if found, 1 => ignore esc
;     29        0  (foreground operation)
; r1 = length of scsi command block
; r2 -> scsi command block
; r3 -> dma sddress or scatterlist address
; r4 = total transfer length in bytes
; r5 = timeout in centiseconds
; exit
; r0 = status byte or error ptr (VS)
; r4 = bytes not transferred
SSFGOp
        bl      scsicmddata     ; read scsi command
; r8 = byte or block count
; r1 = start LBA address
; r2 = command byte
; DebugByteRegNCR r2, "FgOp -  "
; DebugReg r0, "r0 "
; DebugRegNCR r3, "addr "
; DebugRegNCR r1, "LBA "
; DebugReg r4, "Count "
; DebugReg r0, "r0 "
; start dispatching the commands
        adr     lr, alldone     ; return address for these commands
                                ; so we can just jump there
        teq     r2, #&28
        beq     SCSIRead
        teq     r2, #&2a
        beq     SCSIWrite
        teq     r2, #&00
        beq     SCSITestRdy
        teq     r2, #&3
        beq     SCSISense
        teq     r2, #&1e
        beq     SCSIMediaLock
        teq     r2, #&12
        beq     SCSIInquiry
        teq     r2, #&25
        beq     SCSICapacity
        teq     r2, #&2f
        beq     SCSIVerify
;  DebugReg r2, "Unknown Command *************  "
        XSCSIError SCSI_CC_UnKn
        Pull    "r1-r3,r5-r12, pc"      ; 0 and 4 used for return data
alldone
; r4 = bytes left not transferred
; r0 = status
; DebugRegNCR r0,"ExitR0 "
; DebugReg r4, "left "
        Pull    "r1-r3,r5-r12, pc"      ; 0 and 4 used for return data


; scsicmddata
; get start address and count from command
; on entry r2-> cmd block, r1 = length
; on exit
; r8 = byte or block count
; r1 = start LBA address
; r2 = command byte
scsicmddata
        Entry   "r0, r3-r6"
        cmp     r1, #10
        beq     cmd10
        bgt     cmd12
cmd6    ldrb    r8, [r2, #4]
        ldrb    r3, [r2, #2]
        ldrb    r4, [r2, #3]
        orr     r1, r4, r3, lsl #8
        ldrb    r4, [r2, #1]
        and     r4, r4, #&1f
        orr     r1, r1, r4, lsl #16
        ldrb    r2, [r2]
; do the command
        b       %ft3

cmd10   ldrb    r8, [r2, #7]
        ldrb    r3, [r2, #8]
        orr     r8, r3, r8, lsl #8
        ldrb    r1, [r2, #5]
        ldrb    r3, [r2, #4]
        orr     r1, r1, r3, lsl #8
        ldrb    r3, [r2, #3]
        orr     r1, r1, r3, lsl #16
        ldrb    r3, [r2, #2]
        orr     r1, r1, r3, lsl #24
        ldrb    r2, [r2]
; DebugRegNCR r1, "LBAddr "
; DebugReg r8, "len "
; DebugRamSave lr, "r0,r8"
        b       %ft3


cmd12   ldrb    r8, [r2, #9]
        ldrb    r3, [r2, #10]
        orr     r8, r3, r8, lsl #8
        ldrb    r1, [r2, #5]
        ldrb    r3, [r2, #4]
        orr     r1, r1, r3, lsl #8
        ldrb    r3, [r2, #3]
        orr     r1, r1, r3, lsl #16
        ldrb    r3, [r2, #2]
        orr     r1, r1, r3, lsl #24
        ldrb    r2, [r2]

3
        EXIT


; entry as foreground OP except...
; r0 bit 29 set to indicate background op
; r3 -> scatterlist if r0 bit 26 is set
; r5 = handle to pass in r5 for background callback
; r6 -  callback address on completion
; r7 = r12 value to use for background  callback
; exit
; if completed immediately exit as foreground op
; if not completed then
; r0 = -1
;  r1 = driver handle for operation
SSBGOp
; Debug Reg r0, "Backgrnd OP "
 tst r0, #1<<26
 ldrne r4, [r3,#4]
 ldrne  r3, [r3]
 bic r0, r0, #1<<BackgroundBit
 mov r6, #0 ; oblige forground completion
 b SSFGOp
        Pull    "r1-r3,r5-r12, pc"      ; 0 and 4 used for return data


; cancel background operation.
; r0 bit 11 = timeout
;        12 = escape
;        13 = abort
; r1 = deviceID
; r2 = driver handle for OP
;
SSBGCancel
; DebugTX "Cancel Backgrnd Op "
        Pull    "r1-r3,r5-r12, pc"      ; 0 and 4 used for return data

; r3-> buffer for output, r4 = length.. assumed at least 36 here
; if ScatterListBit set in r0, then address is in a scatterlist
; on exit r4 = bytes not transferred
SCSIInquiry     ROUT
        Entry   "r1-r2,r5", 36
        mov     r2, sp
; DebugReg r0, "Inquiry on id "
        tst     r0, #&e0
        moveq   lr, #0                  ; 0 if LUN supported (0)
        movne   lr, #&7f                ; &7f if LUN not supported (all but 0)
        strb    lr, [r2], #1
        mov     lr, #&0                 ; no removable bit
;       movne   lr, #&0                 ; no removable bit
;       moveq   lr, #&80                ; removable bit
        strb    lr, [r2], #1
        mov     lr, #0
        strb    lr, [r2], #1
        mov     lr, #2                  ; normal data sense
        strb    lr, [r2], #1
        mov     lr, #32
        strb    lr, [r2], #1
        mov     lr, #0
        strb    lr, [r2], #1
        strb    lr, [r2], #1
        strb    lr, [r2], #1
        mov     r1, r2
        bl      IDVendor
        add     r1, r2, #8
        bl      IDProduct
        add     r1, r2, #24
        bl      IDRevision
        mov     r1, sp
        mov     r2, #36
        bl      CopyCmdResult
        mov     r0, #TARGET_GOOD        ; no error
        CLRV
        EXIT

;
; min 8 bytes, max 18
SCSISense       ROUT
        Entry   "r2,r5-r6", 20
        mov     r6, sp
; DebugRegTX "RqSense1 "
        mov     r0, #&70
        str     r0, [r6], #4
        mov     r0, #&0a000000
        str     r0, [r6], #4
        mov     lr, #0
        mov     r2, #&a
1       strb    lr, [r6], #1
        subs    r2, r2, #1
        bgt     %bt1
        mov     r1, sp
        mov     r2, #18
        bl      CopyCmdResult
        mov     r0, #TARGET_GOOD        ; no error
        CLRV
        EXIT

; return error status in r0
SCSITestRdy     ROUT
        Entry   ""
; DebugTX "TstRdy"
        mov     r0, #TARGET_GOOD        ; no error
        CLRV
        EXIT

; return error status in r0
SCSIMediaLock   ROUT
        Entry   ""
; DebugTX "MediaLock"
        mov     r0, #TARGET_GOOD        ; no error
        CLRV
        EXIT

; return error status in r0
SCSIVerify      ROUT
        Entry   ""
; DebugTX "VERIFY (10)"
        mov     r0, #TARGET_GOOD        ; no error
        CLRV
        EXIT

; r3-> buffer for output, r4 = length.. at least 8 here
; return data from words 60/61 of identify buffer for 28bit addressing
; return data from words100/101/102/103 for 40bit addressing.
; if > 2words used, return &ffffffff as max We can handle
SCSICapacity    ROUT
        Entry   "r1-r2,r5", 8
        mov     r2, sp
; DebugTX "READ CAPACITY (10)"
        bl      IDCapacity
        str     r1, [r2]
; DebugRegNCR r1, "Capacity "
        bl      IDBlocksize
        str     r1, [r2, #4]
; DebugReg r1, "Blocksize "
        mov     r1, sp
        mov     r2, #8
        bl      CopyCmdResult
        mov     r0, #TARGET_GOOD        ; no error
        CLRV
        EXIT

; Copy result for emulated SCSI command from the stack into the output buffer
; r0, r3-r4 = request parameters
; r1 -> our result
; r2 = our length
; Out:
; r1, r2 corrupt
; r4 = number of bytes not transferred to user
CopyCmdResult   ROUT
        cmp     r2, r4
        movhss  r2, r4 ; r2 = number of bytes to copy out
        sub     r4, r4, r2 ; r4 = number of bytes not transferred
        moveq   pc, lr ; Nothing to transfer out
        Entry   "r3,r5-r6"
        tst     r0, #1<<ScatterListBit
        bne     %ft10
        ; Scatter list not in use
05
        ldrb    lr, [r1], #1
        strb    lr, [r3], #1
        subs    r2, r2, #1
        bne     %bt05
        EXIT
10
        ; Scatter list in use, walk it
        NextScatter r3, r5, r6
20
        ldrb    lr, [r1], #1
        strb    lr, [r5], #1
        subs    r2, r2, #1
        EXIT    EQ
        subs    r6, r6, #1
        bne     %bt20
        b       %bt10



; r0 = scsiID word on entry
; r1 = start LBA address
; r3-> buffer for output, r4 = length..
; r8 = byte or block count
SCSIRead        ROUT
        Entry   "r1-r2"
        mov     r9, r0                  ; remember
        mov     r0, r3                  ; dma address
        orr     r2, r4, #(1<<31)        ; read
; DebugTXS "read-"
        ldr     lr, DevFeatures
        tst     lr, #DevFeature48bit    ; nz if 48bit addressing
        moveq   r3, #ATAPI_COMMAND_READ_DMA
        movne   r3, #ATAPI_COMMAND_READ_DMA48
        b       BuildandComplete

SCSIWrite
        ALTENTRY
        mov     r9, r0                  ; remember
        mov     r0, r3                  ; dma address
        bic     r2, r4, #(1<<31)        ; write
; DebugTXS "write-"
        ldr     lr, DevFeatures
        tst     lr, #DevFeature48bit    ; nz if 48bit addressing
        moveq   r3, #ATAPI_COMMAND_WRITE_DMA
        movne   r3, #ATAPI_COMMAND_WRITE_DMA48
        b       BuildandComplete


; entry point from ahciblock command
; needs to provide the same entry conditions as SCSIRead or SCSIWrite
; r0 = dma address
; r1 = LBA start address
; r2 = length + direction bit
; r3 = command bytes
; r5 - r8 from command entry need to be valid .. 0 for 'manual'
; r9 = scsi_op command word incl SCSI ID
; returns
; r0 = standard error stuff
; r4 = bytes not transferred
; r9 = modified
BuildandCompleteEntry
        ALTENTRY
        orr     r9, r9, #1<<4           ; flag ID on r9 is port# not scsiID
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


BuildandComplete
; r5 - r8 from command entry need to be valid

        bl      BuildAHCICmd

        teq     r9, #0                  ; did r9 get set up?
        bne     %ft221
;  [ Debug
;        mrs     r1, cpsr
;        DebugReg r0, "BuildAHCICmd failed, err="
;        msr     cpsr_f, r1
;  ]
        EXIT

221
; DebugRegNCR r9, "cbtab "
        ldrb    r2, [r9, #CBFGDone-CBTab]
        teq     r2, #0
        beq     %ft2
; check if it is background or foreground..
        ldr     r2, [r9, #CBR0Value-CBTab]
        tst     r2, #(1<<BackgroundBit)
        beq     %ft12
; DebugTX "bkg exit "
; tst   r2, #(1<<BackgroundBit)

        movne   r0, #-1                 ; it is background, so return
        movne   r1, r9
        EXIT    NE

1
        swi     XPortable_Idle          ; sleep CPU until IRQ pending
                                        ; Note IRQs disabled during sleep to avoid us sleeping unnecessarily if our IRQ fires before Portable_Idle can put us to sleep.
        PLP     r4                      ; restore IRQ state
        mov     lr, pc
        ldr     pc, IRQTrigger          ; ensure pending IRQ is dealt with

; Debug Reg r3, "T."
        ldr     r2, [r9, #CBToutOrHandl-CBTab]
; DebugReg r2, "Me."
        teq     r2, #0
        beq     %ft2                    ; no timeout
        swi     XOS_ReadMonotonicTime
        cmp     r2, r0
        bpl     %ft2                    ; not timed out yet
; here if timed out
; DebugTX "TimeOutll "
; [ Debug
;; bl     DumpP0Regs
; ]
; add a bit of extra delay as some things do seem rather slow
; and won't work unless DumpP0Regs is called
        mov     r0, #10*1024                 ; 10ms approx
        bl      HAL_CounterDelay

        ldr     r4, [r9, #CBR4Cnt-CBTab]
        bl      AbortCommand
        XSCSIError SCSI_Timeout2
        CLRV
        EXIT

2       ldrb    r0, CCcallbackstate     ; pending callback to AHCICommandRoutine?
        teq     r0, #cb_pending         ; still pending?
        bne     %ft12

        bl      AHCICommandCompleterDirect


12
        PHPSEI  r4, lr                  ; IRQs off to make state check atomic with Portable_Idle call
        ldrb    r2, [r9, #CBFGDone-CBTab]

        teq     r2, #0
        bne     %bt1                    ; just await finish
        PLP     r4

; here when command finished
        ldr     r4, [r9, #CBR4Cnt-CBTab]
        mov     r0, #TARGET_GOOD
; DebugRegNCR r0, "RdWr Done r0 "
; DebugReg r4, "Bytes left "
        CLRV
        EXIT

        END
