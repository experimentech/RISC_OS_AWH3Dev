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
;>BusMaster
        SUBT    OS_Hardware devices for Bus Master IDE function

; DMA controller device
                        ^       HALDevice_DMAC_Size
Ctrlr_Channels          #       4       ; number of associated channels
Ctrlr_LogicalTable      #       4 * 2   ; array of logical channel numbers
Ctrlr_PhysicalTable     #       4 * 2   ; array of pointers to channel devices
CtrlrSize               *       :INDEX: @

; DMA channel device
                        ^       HALDevice_DMAL_Size, a1
Chan_Registers          #       4       ; as passed to AddBusMasterChannel
Chan_ProgLength         #       4       ; total length programmed
Chan_DoneLength         #       4       ; length successfully transferred
Chan_CmdSoftCopy        #       1       ; soft copy of command register
Chan_ErrorFlags         #       1       ; DMAListTransferStatus flags
                        AlignSpace
ChanSize                *       :INDEX: @

; Bus master register block
BM_Command              *       0
BM_Status               *       2
BM_PRDTab               *       4

; Register bits
BMCommand_Direction     *       1:SHL:3
BMCommand_Enable        *       1:SHL:0

BMStatus_SimplexOnly    *       1:SHL:7
BMStatus_Dr1DMA         *       1:SHL:6
BMStatus_Dr0DMA         *       1:SHL:5
BMStatus_Interrupt      *       1:SHL:2
BMStatus_Error          *       1:SHL:1
BMStatus_Active         *       1:SHL:0

BMPRDTab_EOT            *       1:SHL:31

                        GBLL    ReportDeviceErrors
ReportDeviceErrors      SETL    {FALSE}

                        GBLL    RandomErrors
RandomErrors            SETL    {FALSE}

 [ RandomErrors
RandomErrorCounter      DCD     0
 ]

CreateBusMaster
;
; Entry:
;   R0 = 16-bit ID field for device, allocated from the DMA controller range
;   R1 = location bitfield for device
;   R2 -> statically held string description of DMA controller device
;         (eg "Acer M1535+ super I/O chip IDE controller bus master")
; Exit:
;   VS: R0 -> error block, R6 preserved
;   VC: R0 corrupt, R6 = handle to pass to other routines
;       other registers preserved
;
; This must be called before other routines in this file. It creates the structures
; for the controller device in an RMA block.
;
        Entry   "r1-r3"
        MOV     r1, r0, LSL #16
        MOV     r0, #ModHandReason_Claim
        MOV     r3, #CtrlrSize
        SWI     XOS_Module
        EXIT    VS
        MOV     r6, r2

        ORR     r0, r1, #HALDeviceType_SysPeri
        ORR     r0, r0, #HALDeviceSysPeri_DMAC
        LDMIA   sp, {r1,r3}             ; Location / Description
        MOV     r2, #0                  ; Version
        STMIA   r6!, {r0-r3}

        MOV     r0, #0                  ; Address
        MOV     r1, #0
        MOV     r3, #0
        STMIA   r6!, {r0-r3}

        ADR     r0, Controller_Activate
        ADR     r1, Controller_Deactivate
        ADR     r2, Controller_Reset
        ADR     r3, Controller_Sleep
        STMIA   r6!, {r0-r3}

        MOV     r0, #-1                 ; Device
        MOV     r1, #0                  ; TestIRQ
        MOV     r2, #0
        MOV     r3, #0
        STMIA   r6!, {r0-r3}

        ADR     r0, Controller_Features
        ADR     r1, Controller_Enumerate
        ADR     r2, Controller_Allocate
        ADR     r3, Controller_Deallocate
        STMIA   r6!, {r0-r3}

        ASSERT  HALDevice_DMAC_Size = 4*4*5

        MOV     r0, #0                  ; Ctrlr_Channels
        STR     r0, [r6]

        SUB     r6, r6, #HALDevice_DMAC_Size

        EXIT


AddBusMasterChannel
;
; Entry:
;   R0 = 16-bit ID field for device, allocated from the DMA channel (list-type) range
;   R1 = location bitfield for device
;   R2 -> statically held string description of DMA channel device
;         (eg "Acer M1535+ IDE interface bus master primary channel")
;   R3 = logical DMA channel number to assign to device
;   R5 = base address of bus master register block
;   R6 = controller device to assign channel to (as returned from CreateBusMaster)
;
; Exit:
;   VS: R0 -> error block
;   VC: R0 corrupt
;   other registers preserved
;
; This creates an RMA block for the channel device, and registers it with OS_Hardware.
; Up to two channels can currently be added per controller.
;
        Entry   "r1-r3,r8"
        MOV     r1, r0, LSL #16
        MOV     r0, #ModHandReason_Claim
        MOV     r3, #ChanSize
        SWI     XOS_Module
        EXIT    VS
        MOV     lr, r2

        ORR     r0, r1, #HALDeviceType_SysPeri :OR: HALDeviceSysPeri_DMAL
        LDMIA   sp, {r1,r3}             ; Location / Description
        MOV     r2, #0                  ; Version
        STMIA   lr!, {r0-r3}

        MOV     r0, #0                  ; Address
        MOV     r1, #0
        MOV     r3, #0
        STMIA   lr!, {r0-r3}

        ADR     r0, Channel_Activate
        ADR     r1, Channel_Deactivate
        ADR     r2, Channel_Reset
        ADR     r3, Channel_Sleep
        STMIA   lr!, {r0-r3}

        MOV     r0, #-1                 ; Device
        MOV     r1, #0                  ; TestIRQ
        MOV     r2, #0
        MOV     r3, #0
        STMIA   lr!, {r0-r3}

        ADR     r0, Channel_Features
        MOV     r1, r6
        ADR     r2, Channel_Abort
        ADR     r3, Channel_SetOptions
        STMIA   lr!, {r0-r3}

        ADR     r0, Channel_SetListTransfer
        ADR     r1, Channel_ListTransferProgress
        ADR     r2, Channel_ListTransferStatus
        ADR     r3, Channel_CurtailListTransfer
        STMIA   lr!, {r0-r3,r5}         ; Chan_Registers too

        ASSERT  HALDevice_DMAL_Size = 4*4*6

        ; Register device
        SUB     r2, lr, #HALDevice_DMAL_Size + 4*1
        MOV     r0, r2
        MOV     r8, #OSHW_DeviceAdd
        SWI     XOS_Hardware
        BVS     %FT90

        ; Add to controller's list of channels
        LDR     lr, [r6, #Ctrlr_Channels]
        LDR     r0, [sp, #4*2]
        ADD     r6, r6, #Ctrlr_LogicalTable
        STR     r0, [r6, lr, LSL #2]
        ADD     r6, r6, #Ctrlr_PhysicalTable - Ctrlr_LogicalTable
        STR     r2, [r6, lr, LSL #2]
        SUB     r6, r6, #Ctrlr_PhysicalTable
        ADD     lr, lr, #1
        STR     lr, [r6, #Ctrlr_Channels]

        EXIT

90      MOV     r8, r0
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOV     r0, r8
        SETV
        EXIT


RegisterBusMaster
;
; Entry:
;   R6 = handle returned from CreateBusMaster
;
; Exit:
;   VS: R0 -> error block
;   VC: R0 corrupt
;   other registers preserved
;
; This must be called when all channels have been added using AddBusMasterChannel.
; It registers the DMA controller device with OS_Hardware.
;
        Entry   "r8"
        MOV     r0, r6
        MOV     r8, #OSHW_DeviceAdd
        SWI     XOS_Hardware
        EXIT


DeleteBusMaster
;
; Entry:
;   R6 = handle returned from CreateBusMaster
; Exit:
;   VS: R0 -> error block
;   VC: R0 corrupt, R6 = 0
;   other registers preserved
;
; This deregisters all channel and controller devices with OS_Hardware, then frees
; their respective RMA blocks.
;
        Entry   "r1-r2,r8"
        ; Deregister the controller first -
        ; this should error if any of the channels are in use
        MOV     r0, r6
        MOV     r8, #OSHW_DeviceRemove
        SWI     XOS_Hardware
        EXIT    VS

        LDR     r1, [r6, #Ctrlr_Channels]
        ADD     r6, r6, #Ctrlr_PhysicalTable
        TEQ     r1, #0
        BEQ     %FT20

10      LDR     r2, [r6, r1, LSL #2]
        MOV     r0, r2
        SWI     XOS_Hardware
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        SUBS    r1, r1, #1
        BNE     %BT10

20      SUB     r6, r6, #Ctrlr_PhysicalTable
        MOV     r0, #ModHandReason_Free
        MOV     r2, r6
        SWI     XOS_Module
        MOV     r6, #0
        CLRV
        EXIT


; Now the device routines.

Controller_Activate
        MOV     a1, #1                          ; Always successful
Controller_Deactivate
Controller_Reset
        MOV     pc, lr

Controller_Sleep
        MOV     a1, #0                          ; Cannot power down
        MOV     pc, lr

Controller_Features
        MOV     a1, #0                          ; No flags defined yet

Controller_Enumerate
        LDR     a2, [a1, #Ctrlr_Channels]
        ADD     a1, a1, #Ctrlr_PhysicalTable
        MOV     pc, lr

Controller_Allocate
        LDR     a3, [a1, #Ctrlr_Channels]
        ADD     a1, a1, #Ctrlr_LogicalTable
        TEQ     a3, #0
01      MOVEQ   a1, #0
        MOVEQ   pc, lr
        LDR     ip, [a1], #4
        TEQ     ip, a2
        LDREQ   a1, [a1, #Ctrlr_PhysicalTable - Ctrlr_LogicalTable - 4]
        MOVEQ   pc, lr
        SUBS    a3, a3, #1
        B       %BT01

Controller_Deallocate
        MOV     pc, lr


Channel_Activate
        LDRB    a3, Chan_CmdSoftCopy
        LDR     ip, Chan_Registers
        ORR     a3, a3, #BMCommand_Enable
        STRB    a3, Chan_CmdSoftCopy
        STRB    a3, [ip, #BM_Command]           ; Start bus master
        MOV     a1, #1                          ; Assume always successful
        MOV     pc, lr

Channel_Deactivate
        LDRB    a3, Chan_CmdSoftCopy
        TST     a3, #BMCommand_Enable
        MOVEQ   pc, lr                          ; Don't bother if already inactive
        LDR     ip, Chan_Registers
01      LDRB    a4, [ip, #BM_Status]
        AND     a4, a4, #BMStatus_Interrupt :OR: BMStatus_Error :OR: BMStatus_Active
        EORS    a2, a4, #BMStatus_Active
        BEQ     %BT01                           ; Block while transferring (ieA)
        TST     a4, #BMStatus_Error :OR: BMStatus_Active
        LDREQ   a2, Chan_ProgLength
        STREQ   a2, Chan_DoneLength
 [ ReportDeviceErrors
        ASSERT  BMStatus_Interrupt :SHR: 2 = BMStatus_Active
        EOR     a2, a4, a4, LSR #2
        TST     a2, #BMStatus_Active            ; If these bits were set the same
        MOVNE   a2, #0                          ;   then we have a device error
        MOVEQ   a2, #DMAListTransferStatusFlag_DeviceError
 |
        MOV     a2, #0
 ]
        TST     a4, #BMStatus_Error             ; This bit set means a memory error
        MOVNE   a2, #DMAListTransferStatusFlag_MemoryError ; and overrides other bits
        STRB    a2, Chan_ErrorFlags             ; Remember error state
        BIC     a3, a3, #BMCommand_Enable
        STRB    a3, Chan_CmdSoftCopy
        STRB    a3, [ip, #BM_Command]           ; Stop bus master
        MOV     pc, lr

Channel_Reset
        LDR     ip, Chan_Registers
        MOV     a3, #0
        STR     a3, Chan_ProgLength
        STR     a3, Chan_DoneLength
        STRB    a3, Chan_CmdSoftCopy
        STRB    a3, Chan_ErrorFlags
        STRB    a3, [ip, #BM_Command]           ; Stop bus master
        MOV     a3, #BMStatus_Dr1DMA :OR: BMStatus_Dr0DMA \
                :OR: BMStatus_Interrupt :OR: BMStatus_Error
        STRB    a3, [ip, #BM_Status]
        MOV     pc, lr

Channel_Sleep
        MOV     a1, #0                          ; Cannot power down
        MOV     pc, lr

Channel_Features
        ADR     a1, FeaturesBlock
        MOV     pc, lr

Channel_Abort
        LDRB    a3, Chan_CmdSoftCopy
        TST     a3, #BMCommand_Enable
        MOVEQ   pc, lr                          ; Don't bother if already inactive
        LDR     ip, Chan_Registers
        LDRB    a4, [ip, #BM_Status]
        TST     a4, #BMStatus_Error :OR: BMStatus_Active
        LDREQ   a2, Chan_ProgLength
        STREQ   a2, Chan_DoneLength             ; If finished then mark as all done
 [ ReportDeviceErrors
        ASSERT  BMStatus_Interrupt :SHR: 2 = BMStatus_Active
        EOR     a2, a4, a4, LSR #2
        TST     a2, #BMStatus_Active            ; If these bits were set the same
        MOVNE   a2, #0                          ;   then we have a device error
        MOVEQ   a2, #DMAListTransferStatusFlag_DeviceError
 |
        MOV     a2, #0
 ]
        TST     a4, #BMStatus_Error             ; This bit set means a memory error
        MOVNE   a2, #DMAListTransferStatusFlag_MemoryError ; and overrides other bits
        STRB    a2, Chan_ErrorFlags             ; Remember error state
        BIC     a3, a3, #BMCommand_Enable
        STRB    a3, Chan_CmdSoftCopy
        STRB    a3, [ip, #BM_Command]           ; Stop bus master
        MOV     pc, lr

Channel_SetOptions
        TST     a2, #DMASetOptionsFlag_Write
        MOVNE   a3, #0
        MOVEQ   a3, #BMCommand_Direction
        STRB    a3, Chan_CmdSoftCopy            ; Don't program the real register yet
        MOV     pc, lr

Channel_SetListTransfer
 [ RandomErrors
        LDR     ip, RandomErrorCounter
        ADDS    ip, ip, #&04000000
        STR     ip, RandomErrorCounter
        LDRCS   ip, [a3, #0]
        EORCS   ip, ip, #&20000000
        STRCS   ip, [a3, #0]
 ]
        LDR     ip, [a3, #4]!
        SUBS    a4, a4, #1
        BIC     ip, ip, #&10000                 ; For 64K transfers, program 0
        ORREQ   ip, ip, #BMPRDTab_EOT           ; If last one then set EOT bit
        STR     ip, [a3], #4
        BNE     Channel_SetListTransfer         ; Loop until all entries processed
        LDR     ip, Chan_Registers
        LDR     a3, [sp]
        STR     a2, [ip, #BM_PRDTab]            ; Set PRDT location
        STR     a3, Chan_ProgLength             ; Remember the length programmed
        MOV     pc, lr

Channel_ListTransferProgress
        LDRB    a3, Chan_CmdSoftCopy
        TST     a3, #BMCommand_Enable
        LDREQ   a1, Chan_DoneLength             ; If not active
        MOVEQ   pc, lr                          ;   then return cached amount
        LDR     ip, Chan_Registers
        LDRB    a3, [ip, #BM_Status]
        TST     a3, #BMStatus_Error :OR: BMStatus_Active
        LDREQ   a1, Chan_ProgLength             ; Say it's all done if now inactive
        MOVNE   a1, #0                          ;   else say none of it's done
        MOV     pc, lr

Channel_ListTransferStatus
        LDRB    a3, Chan_CmdSoftCopy
        TST     a3, #BMCommand_Enable
        LDREQB  a1, Chan_ErrorFlags             ; If not active
        MOVEQ   pc, lr                          ;   then return cached status
        LDR     ip, Chan_Registers
        LDRB    a4, [ip, #BM_Status]            ;   else read from status register
 [ ReportDeviceErrors
        ASSERT  BMStatus_Interrupt :SHR: 2 = BMStatus_Active
        EOR     a2, a4, a4, LSR #2
        TST     a2, #BMStatus_Active            ; If these bits were set the same
        MOVNE   a1, #0                          ;   then we have a device error
        MOVEQ   a1, #DMAListTransferStatusFlag_DeviceError
 |
        MOV     a1, #0
 ]
        TST     a4, #BMStatus_Error             ; This bit set means a memory error
        MOVNE   a1, #DMAListTransferStatusFlag_MemoryError ; and overrides other bits
        MOV     pc, lr

Channel_CurtailListTransfer
        LDR     a1, Chan_ProgLength             ; Nothing can be done to
        MOV     pc, lr                          ;   shorten the transfer

FeaturesBlock
        DCD     DMAFeaturesFlag_NotCircular :OR: \
                DMAFeaturesFlag_NotInfinite :OR: \
                DMAFeaturesFlag_NoSyncIRQs
        DCD     64 * 1024       ; BlockSize
        DCD     64 * 1024       ; BlockAlign
        DCD     64 * 1024       ; BlockBound
        DCD     (64 * 1024) / 8 ; MaxTransfers
        DCD     64 * 1024       ; TransferLimit
        DCD     64 * 1024       ; TransferBound

        END
