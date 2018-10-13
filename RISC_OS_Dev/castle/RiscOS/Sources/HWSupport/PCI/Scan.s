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

ScanConfigRead
        Push    "r0,r3,r10-r12,lr"
        ORR     r0, r0, r5, LSL #16
        ORR     r0, r0, r6, LSL #8
        MOV     r3, #0
        BL      ConfigurationRead
        Pull    "r0,r3,r10-r12,pc"

ScanConfigWrite
        Push    "r0,r3,r10-r12,lr"
        ORR     r0, r0, r5, LSL #16
        ORR     r0, r0, r6, LSL #8
        MOV     r3, #0
        BL      ConfigurationWrite
        Pull    "r0,r3,r10-r12,pc"

; Our abort handler - if it's an external abort, then ignore it
; (HAL is expected to ensure that reads return all 1s if such an abort
; handler is installed).
; Otherwise pass it to the other handlers.
AbortHandlerStart
        Push    "r0,r1"
        MRS     r0, CPSR
        ReadCop r1, CR_FaultStatus
        AND     r1, r1, #2_1101
        TEQ     r1, #2_0100
        Pull    "r0,r1",EQ
        SUBEQS  pc, lr, #4
        MSR     CPSR_cxsf, r0
        Pull    "r0,r1"
        LDR     pc, OldHandler
OldHandler
        DCD     0
AbortHandlerEnd

        ASSERT  AbortHandlerEnd-AbortHandlerStart = ?ram_abort_handler

ScanPCI
        Entry   "r0-r4"

        ; Put in an abort handler in case aborted PCI configuration
        ; transactions actually cause a Data Abort (as on the 80321).
        ADR     r0, ram_abort_handler
        ADR     r1, AbortHandlerStart
        ADD     r2, r0, #AbortHandlerEnd - AbortHandlerStart
05      LDR     r14, [r1], #4
        STR     r14, [r0], #4
        TEQ     r0, r2
        BNE     %BT05

        MOV     r0, #1
        ADR     r1, ram_abort_handler
        SUB     r2, r2, #4
        SWI     XOS_SynchroniseCodeAreas

        PHPSEI  r2, r0
        MOV     r0, #4
        ORR     r0, r0, #&100           ; Claim data abort vector
        ADR     r1, ram_abort_handler
        SWI     XOS_ClaimProcessorVector
        STR     r1, ram_abort_handler + (OldHandler - AbortHandlerStart)
        PLP     r2
        BVS     %FT99

        MOV     r0, #0                  ; Work down from bus 0
        BL      ScanBus

        SavePSR r3                      ; Remember error
        MOVVS   r4, r0

        MOV     r0, #4                  ; Release data abort vector
        LDR     r1, ram_abort_handler + (OldHandler - AbortHandlerStart)
        ADR     r2, ram_abort_handler
        SWI     XOS_ClaimProcessorVector

        RestPSR r3,,f
        MOVVS   r0, r4
99
        STRVS   r0, [sp]
        EXIT

; In    R0 = bus number
ScanBus
        Entry   "r0-r8"

        MOV     r3, #0                          ; R3 = PCI handle
        MOV     r5, r0                          ; R5 = bus
        MOV     r6, #0                          ; R6 = dev/fn
        MOV     r7, #0                          ; multifunction flag

scan_loop
        BL      ProbeFunction
        TEQ     r0, #0
        BEQ     %FT80

        ORR     r7, r7, r1
        BL      FindFreeHandle
        BVS     %FT90                   ; slight leak if error
        LDR     r2, pci_handle_table
        LDR     lr, pci_handles
        STR     r0, [r2, r3, LSL #2]
        CMP     r3, lr
        STRHI   r3, pci_handles

        LDRB    r0, [r0, #PCIDesc_HeaderType]
        TEQ     r0, #1                  ; PCI-PCI bridge
        BNE     %FT80

        MOV     r0, #PCIConf1_SecondaryBus
        MOV     r2, #1
        BL      ScanConfigRead
        MOV     r0, r1
        BL      ScanBus

80
        TST     r7, #&80
        ADDNE   r6, r6, #1              ; Go to next fn within this device
        ADDEQ   r6, r6, #8              ; Single fn, go to next device
        TST     r6, #7
        MOVEQ   r7, #0
        CMP     r6, #&FF                ; Done all devices/fns on this bus?
        BLS     scan_loop

90
        STRVS   r0, [sp]
        EXIT

; In: R5 = Bus
;     R6 = Device/function
; Out: R0 -> PCIDesc block if function present else 0
;      R1 = header type (all 8 bits) if function present, else undefined

ProbeFunction   ROUT
        Push    "r2-r4,r7,r11,lr"

 [ DebugScan
        DREG    R5,"Probing bus ",cc,Byte
        DREG    R6," device ",,Byte
 ]
        MOV     r11, #0
        MOV     r0, #PCIConf_VendorID
        MOV     r2, #4
        BL      ScanConfigRead
        CMP     r1, #&FFFFFFFF
        BEQ     %FT80

 [ DebugScan
        DREG    R1, "Found "
 ]
        MOV     r0, #ModHandReason_Claim
        MOV     r3, #PCIDesc_size
        SWI     XOS_Module
        BVS     %FT99
        MOV     r11, r2
        MOV     r0, #0
10      STR     r0, [r2], #4
        SUBS    r3, r3, #4
        BNE     %BT10
        STR     r1, [r11, #PCIDesc_VendorID]
        STRB    r5, [r11, #PCIDesc_Bus]
        STRB    r6, [r11, #PCIDesc_DevFn]
        MOV     r0, #255
        STRB    r0, [r11, #PCIDesc_Slot]

        MOV     r0, #PCIConf_RevisionID
        MOV     r2, #4
        BL      ScanConfigRead
        STRB    r1, [r11, #PCIDesc_RevisionID]
        MOV     r1, r1, LSR #8
        STR     r1, [r11, #PCIDesc_ClassCode]

        MOV     r0, #PCIConf_HeaderType
        MOV     r2, #1
        BL      ScanConfigRead
        MOV     r7, r1
        AND     r4, r1, #&7F            ; Knock out multi function bit
        STRB    r4, [r11, #PCIDesc_HeaderType]

        TEQ     r4, #0                  ; Standard layout
        TEQNE   r4, #1                  ; Bridge layout
        BNE     %FT80                   ; Cardbus or other layout

        ASSERT  PCIConf0_InterruptLine = PCIConf1_InterruptLine
        MOV     r0, #PCIConf0_InterruptLine
        BL      ScanConfigRead
        STRB    r1, [r11, #PCIDesc_IntLine]

        TEQ     r4, #0                  ; Only type 0 has subsystem
        MOVNE   r1, #0
        MOVEQ   r0, #PCIConf0_SubsystemVendorID
        MOVEQ   r2, #4
        BLEQ    ScanConfigRead
        STR     r1, [r11, #PCIDesc_SubsystemVendorID]

        MOV     r0, #PCIConf_Status
        MOV     r2, #2
        BL      ScanConfigRead
        ANDS    r3, r1, #PCISta_Capabilities
        BEQ     %FT30

        ASSERT  PCIConf0_Capabilities = PCIConf1_Capabilities
        MOV     r0, #PCIConf0_Capabilities
        MOV     r2, #1
        BL      ScanConfigRead
20      BICS    r3, r1, #3
        BEQ     %FT30

        ADD     r0, r3, #PCICap_ID
        MOV     r2, #2
        BL      ScanConfigRead
        AND     lr, r1, #&FF
        TEQ     lr, #Cap_MSI
        ASSERT  PCICap_NextPtr = PCICap_ID+1
        MOVNE   r1, r1, LSR #8
        BNE     %BT20

30      STRB    r3, [r11, #PCIDesc_MSICap]

        ASSERT  PCIConf0_BaseAddresses = PCIConf1_BaseAddresses
        MOV     r0, #PCIConf0_BaseAddresses
        TEQ     r4, #0
        MOVEQ   r3, #?PCIConf0_BaseAddresses / 4
        MOVNE   r3, #?PCIConf1_BaseAddresses / 4
        ADD     r8, r11, #PCIDesc_Addresses
        BL      ScanAddresses

        TEQ     r4, #0
        MOVEQ   r0, #PCIConf0_ROMAddress
        MOVNE   r0, #PCIConf1_ROMAddress
        MOV     r2, #4
        BL      ScanConfigRead

        MOV     r4, r1
        MOV     r1, #&FF
        ORR     r1, r1, #&700
        BICS    r4, r4, r1
        ADD     r8, r11, #PCIDesc_ROMAddress
        STR     r4, [r8, #PCIAddress_Base]
        BEQ     %FT40
        MOV     lr, #0
        STRB    lr, [r8, #PCIAddress_Flags]
        BL      SizeAddress
40

80
        MOV     r0, r11
        MOV     r1, r7
99
        Pull    "r2-r4,r7,r11,pc"

; In: r0 = first BAR
;     r3 = number of BARs to scan
;     r5 = bus
;     r6 = dev/fn
;     r8 -> address table to fill in
ScanAddresses   ROUT
        Push    "r0-r7,lr"
        MOV     r7, r0
10      MOV     r0, r7
        MOV     r2, #4
        BL      ScanConfigRead
        MOV     r4, r1
        TST     r4, #Address_IO
        MOVNE   r1, #2_11
        MOVEQ   r1, #2_1111
        AND     r14, r4, r1
        STRB    r14, [r8, #PCIAddress_Flags]
        BIC     r4, r4, r1
        ; Ignore reserved memory encoding
        AND     r14, r14, #2_0111
        TEQ     r14, #2_0110
        BEQ     %FT80

        STR     r4, [r8, #PCIAddress_Base]
        TEQ     r4, #0
        BEQ     %FT80

        ; Non-zero base register. Let's size it.
        MOV     r0, r7
        BL      SizeAddress
80
        LDRB    r14, [r8, #PCIAddress_Flags]
        ADD     r8, r8, #PCIAddress_size
        ADD     r7, r7, #4
        AND     r14, r14, #2_0111
        TEQ     r14, #2_0100
        ADDEQ   r8, r8, #PCIAddress_size
        ADDEQ   r7, r7, #4
        SUBEQ   r3, r3, #1
        SUBS    r3, r3, #1
        BGT     %BT10
        Pull    "r0-r7,pc"

; In:  nowt
; Out: R3 = next free handle
FindFreeHandle  ROUT
        Push    "r0-r2,lr"
        ; If no table yet, jump straight to claiming a block
        LDR     r2, pci_handle_table
        LDR     r1, pci_handle_table_size
        TEQ     r2, #0
        BEQ     %FT20

        ; Search table for a free entry (=-1)
        MOV     r3, #1
10      LDR     r14, [r2, r3, LSL #2]
        CMP     r14, #-1
        Pull    "r0-r2,pc",EQ
        ADD     r3, r3, #1
        CMP     r3, r1
        BLO     %BT10

        ; Table full - extend it please
        MOV     r0, #ModHandReason_ExtendBlock
        MOV     r3, #64*4
        SWI     XOS_Module
        BVC     %FT40           ; jump to common code below
99      ADD     sp, sp, #4
        Pull    "r1-r2,pc"

        ; Claim initial table
20      MOV     r0, #ModHandReason_Claim
        MOV     r3, #64*4
        SWI     XOS_Module
        BVS     %99

        ; 64 shiny new slots - update all our pointers
40      STR     r2, pci_handle_table
        MOVS    r3, r1
        ADDEQ   r3, r3, #1
        ADD     r1, r1, #64
        STR     r1, pci_handle_table_size

        ; fill in all the new slots with -1
        MOV     r14, #-1
        MOV     r0, r3
        STREQ   r14, [r2, #0]
50      STR     r14, [r2, r0, LSL #2]
        ADDS    r0, r0, #1
        CMP     r0, r1
        BNE     %BT50

        Pull    "r0-r2,pc"

; In: r0 = BAR address
;     r1 = mask of insignificant bits at bottom
;     r5 = bus
;     r6 = dev/fn
;     r8 -> address structure (address filled in)
; Out: r8->Size field updated
SizeAddress
        Push    "r0-r4,r10,lr"
        PHPSEI  r10, lr
        MOV     r0, #PCIConf_Command            ; Clear Mem+IO bits
        MOV     r2, #2
        BL      ScanConfigRead
        MOV     r4, r1                          ; R4 = old command reg
        BIC     r1, r1, #PCICmd_Memory+PCICmd_IO
        BL      ScanConfigWrite

        LDR     r0, [sp]                        ; Write all 1s
        LDMIA   sp, {r0, r1}
        MOV     lr, #-1
        BIC     r1, lr, r1
        MOV     r2, #4
        BL      ScanConfigWrite
        BL      ScanConfigRead                  ; Read it back
        MOV     r3, r1                          ; R3 = address mask
        LDR     r1, [r8, #PCIAddress_Base]
        BL      ScanConfigWrite                 ; Put back original
        MOV     r0, #PCIConf_Command
        MOV     r1, r4
        MOV     r2, #2
        BL      ScanConfigWrite                 ; Reenable Mem+IO
        PLP     r10

        LDR     r14, [sp, #4]
        BIC     r3, r3, r14
        MOV     r0, #1
50      MOVS    r3, r3, LSR #1
        MOVCC   r0, r0, LSL #1
        BCC     %BT50
        STR     r0, [r8, #PCIAddress_Size]
        Pull    "r0-r4,r10,pc"

; get the slot table from the HAL, and fill in info in our devices
NoteSlots ROUT
        Push    "r0-r12,lr"
        MOV     r10, sp
        MOV     r0, #0
        MOV     r1, #0          ; Query table size
        MOV     r8, #OSHW_CallHAL
        MOV     r9, #EntryNo_HAL_PCISlotTable
        SWI     XOS_Hardware
        BVS     %FT90
        ADD     r0, r0, #3
        BIC     r0, r0, #3
        SUB     sp, sp, r0
        MOV     r1, r0          ; Get the table
        MOV     r0, sp
        SWI     XOS_Hardware
        BVS     %FT90
        MOV     r0, sp
        LDR     r12, [r10, #12*4] ; get back workspace pointer
        LDR     r3, [r0], #4    ; r3 = number of slot entries
        TEQ     r3, #0
        BEQ     %FT90

        LDR     r4, pci_handles
        LDR     r5, pci_handle_table
        CMP     r4, #0
        BEQ     %FT90
10      LDR     r6, [r5, r4, LSL #2]
        CMP     r6, #-1
        BEQ     %FT60
        LDRB    r7, [r6, #PCIDesc_Bus]
        LDRB    r8, [r6, #PCIDesc_DevFn]
        MOV     r8, r8, LSR #3
        MOV     lr, #0
20      ADD     r9, r0, lr, LSL #3
        LDRB    r1, [r9, #0]    ; Bus
        LDRB    r2, [r9, #1]    ; Dev/Fn
        TEQ     r7, r1
        TEQEQ   r8, r2, LSR #3
        BNE     %FT50
        LDRB    lr, [r9, #7]    ; Slot
        LDRB    r9, [r9, #6]    ; Flags
        STRB    lr, [r6, #PCIDesc_Slot]
        STRB    r9, [r6, #PCIDesc_SlotFlags]
        B       %FT60
50      ADD     lr, lr, #1
        CMP     lr, r3
        BNE     %BT20

60      SUBS    r4, r4, #1
        BNE     %BT10

90      MOV     sp, r10
        STRVS   r0, [sp]
        Pull    "r0-r12,pc"

        END

