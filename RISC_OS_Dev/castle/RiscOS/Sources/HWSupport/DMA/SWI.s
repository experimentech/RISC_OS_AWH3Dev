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
; > Sources.SWI

SWInames
        DCB     "DMA",0
        DCB     "RegisterChannel",0
        DCB     "DeregisterChannel",0
        DCB     "QueueTransfer",0
        DCB     "TerminateTransfer",0
        DCB     "SuspendTransfer",0
        DCB     "ResumeTransfer",0
        DCB     "ExamineTransfer",0
      [ HAL
        DCB     "AllocateLogicalChannels",0
      ]
        DCB     0
                ALIGN

 [ :LNOT: HAL

; These are the tables for IOMD1.

;-----------------------------------------------------------------------------
; LogicalChannel table.
;
LogicalChannel
        DCD     &000    ; Podule 0, DMA line 0, channel 2
;       DCD     &001    ; Podule 0, DMA line 1, not supported
        DCD     &010    ; Podule 1, DMA line 0, channel 3
;       DCD     &011    ; Podule 1, DMA line 1, not supported
;       DCD     &020    ; Podule 2, DMA line 0, not supported
;       DCD     &021    ; Podule 2, DMA line 1, not supported
;       DCD     &030    ; Podule 3, DMA line 0, not supported
;       DCD     &031    ; Podule 3, DMA line 1, not supported
;       DCD     &040    ; Podule 4, DMA line 0, not supported
;       DCD     &041    ; Podule 4, DMA line 1, not supported
;       DCD     &050    ; Podule 5, DMA line 0, not supported
;       DCD     &051    ; Podule 5, DMA line 1, not supported
;       DCD     &060    ; Podule 6, DMA line 0, not supported
;       DCD     &061    ; Podule 6, DMA line 1, not supported
;       DCD     &070    ; Podule 7, DMA line 0, not supported
;       DCD     &071    ; Podule 7, DMA line 1, not supported
;       DCD     &100    ; On-board SCSI, not supported
        DCD     &101    ; On-board Floppy, channel 1
        DCD     &102    ; Parallel, channel 1
        DCD     &103    ; Sound out, channel 4
        DCD     &104    ; Sound in, channel 5
        DCD     &105    ; Network Card, channel 0

        ASSERT .-LogicalChannel = NoLogicalChannels :SHL: 2

;-----------------------------------------------------------------------------
; PhysicalChannel table.
;       Maps logical channel to physical channel.
;
PhysicalChannel
        DCB     2
        DCB     3
        DCB     1
        DCB     1
        DCB     4
        DCB     5
        ASSERT .-PhysicalChannel = NoPhysicalChannels
        DCB     0
        ALIGN

 ]

;---------------------------------------------------------------------------
;       Handle SWI calls to our module.
;
SWIhandler
        LDR     r12, [r12]
      [ HAL
        LDRB    r10, PreReset
        TEQ     r10, #0
        BNE     SWIPreResetError
      ]
        CMP     r11, #(SWItabend-SWItabstart):SHR:2
        ADDCC   pc, pc, r11, LSL #2
        B       SWIerror

SWItabstart
        B       SWIRegisterChannel
        B       SWIDeregisterChannel
        B       SWIQueueTransfer
        B       SWITerminateTransfer
        B       SWISuspendTransfer
        B       SWIResumeTransfer
        B       SWIExamineTransfer
      [ HAL
        B       SWIAllocateLogicalChannels
      ]
SWItabend

SWIerror
        ADR     r0, ErrorBlock_DMA_BadSWI
 [ international
        ADRL    r4, Title
 ]
        DoError

 [ HAL
SWIPreResetError
        ADR     r0, ErrorBlock_DMA_PreReset
        DoError
        MakeErrorBlock  DMA_PreReset
 ]

        MakeErrorBlock  DMA_BadSWI

;---------------------------------------------------------------------------
; SWIRegisterChannel
;       In:     r0  = flags
;                       bit     meaning
;             [ HAL
;                       0-3     post-transfer channel delay
;                       4       disable burst transfers
;                       5       disable DRQ synchronisation to clock
;                       6-31    reserved (set to 0)
;             |
;                       0-31    reserved (set to 0)
;             ]
;               r1  = logical channel
;               r2  = DMA cycle speed (0-3)
;               r3  = transfer unit size (1,2,4 or 16)
;               r4  ->vector routine
;               r5  = value to pass to vector routine in r12
;             [ HAL
;               r6  = peripheral read/receive physical address, or -1 to disallow reads
;               r7  = peripheral write/transmit physical address, or -1 to disallow writes
;             ]
;
;       Out:    r0  = channel handle
;               all other registers preserved
;
;       Register a channel handling vector with the DMA manager.
;
SWIRegisterChannel      ROUT
      [ HAL
        Entry   "r1-r4,r8-r9"

        Debug   swi,"SWIRegisterChannel",r1

        ; For now assume that we must fault re-registration of the same channel.
        ; (This will need to change when we support memory-to-memory DMA.)
        ADR     r9, ChannelList - lcb_Next
10      LDR     r8, [r9, #lcb_Next]
        TEQ     r8, #0
        BEQ     %FT15
        LDR     lr, [r8, #lcb_ChannelNo]
        TEQ     lr, r1
        MOVNE   r9, r8
        BNE     %BT10
        PullEnv
        ADR     r0, ErrorBlock_DMA_AlreadyClaimed
        DoError

15      ; We can safely register this channel.
        Push    "r0,r2-r3"
        MOV     r0, #ModHandReason_Claim
        MOV     r3, #LCBSize
        SWI     XOS_Module
        ADDVS   sp, sp, #3*4
        EXIT    VS
        MOV     r0, #0
        ASSERT  lcb_Next = 0
        ASSERT  lcb_ChannelNo = lcb_Next + 4
        STMIA   r2, {r0,r1}
        MOV     lr, r2
        ADD     r8, r2, #lcb_Flags
        Pull    "r0,r2-r3"

        CMP     r2, #4                          ; Validate cycle speed.
        PullEnv CS
        ADRCS   r0, ErrorBlock_DMA_BadCycleSpeed
        DoError CS

        CMP     r3, #32                         ; Validate transfer unit size.
        PullEnv CS
        ADRCS   r0, ErrorBlock_DMA_BadTransferUnit
        DoError CS

        TST     r4, #3                          ; Ensure vector table is word aligned.
        PullEnv NE
        ADRNE   r0, ErrorBlock_DMA_BadAddress
        DoError NE

        ORR     r0, r3, r0, LSL #8              ; Build flags in r0.
        ORR     r0, r0, r2, LSL #5

        ASSERT  lcb_Vector = lcb_Flags + 4
        ASSERT  lcb_R12 = lcb_Vector + 4

        STMIA   r8!, {r0,r4-r5}

        MOV     r5, r1                          ; r5 = logical channel number
        LDR     r4, CtrlrList
30      TEQ     r4, #0
        ADREQ   r0, ErrorBlock_DMA_BadChannel   ; Not found so return error.
        BEQ     %FT99
        LDR     r0, [r4, #ctrlr_Device]
        MOV     r1, r5
        CallHAL DMACAllocate, lr
        TEQ     r0, #0
        LDREQ   r4, [r4, #ctrlr_Next]
        BEQ     %BT30                           ; Not supported by this controller so try next one.

        ; Search for the DMA queue for this physical channel (there must be one)
        ADD     r3, r4, #ctrlr_DMAQueues
        LDR     r1, [r4, #ctrlr_PhysicalChannels]
80      LDR     r4, [r3, #dmaq_DMADevice]
        TEQ     r0, r4
        SUBNES  r1, r1, #1
        ADDNE   r3, r3, #DMAQSize
        BNE     %BT80                           ; Terminate loop anyway in case of broken HAL code.

        ASSERT  lcb_Queue = lcb_R12 + 4
        ASSERT  lcb_PeripheralRead = lcb_Queue + 4
        ASSERT  lcb_PeripheralWrite = lcb_PeripheralRead + 4

        STMIA   r8, {r3,r6-r7}

        LDR     r8, [r3, #dmaq_Usage]
        CMP     r8, #0                          ; Is this the first time we've used this physical channel?
        ADD     r8, r8, #1
        BNE     %FT85                           ; If not, no more physical memory is needed.
        LDRB    r0, [r4, #HALDevice_Type + 0]
        CMP     r0, #HALDeviceSysPeri_DMAL      ; List devices always need memory.
        LDRNE   r1, [r4, #HALDevice_Device]
        CMPNE   r1, #-1                         ; Buffer devices need a bounce buffer iff they have no interrupt.
        BNE     %FT85

        CMP     r0, #HALDeviceSysPeri_DMAL
        LDREQ   r2, [r3, #dmaq_DeviceFeatures]
        MOVNE   r0, #BOUNCEBUFFSIZE
        LDREQ   r0, [r2, #DMAFeaturesBlock_BlockSize]
        MOVNE   r1, #BOUNCEBUFFSIZE
        LDREQ   r1, [r2, #DMAFeaturesBlock_BlockAlign]
        MOVNE   r2, #BOUNCEBUFFSIZE
        LDREQ   r2, [r2, #DMAFeaturesBlock_BlockBound]
        Push    "lr"
        SWI     XPCI_RAMAlloc
        Pull    "lr"
        BVS     %FT90
        LDRB    r2, [r4, #HALDevice_Type + 0]
        CMP     r2, #HALDeviceSysPeri_DMAL
        STRNE   r0, [r3, #dmaq_BounceBuff + ptab_Logical]
        STREQ   r0, [r3, #dmaq_DescBlockLogical]
        STRNE   r1, [r3, #dmaq_BounceBuff + ptab_Physical]
        STREQ   r1, [r3, #dmaq_DescBlockPhysical]
85      STR     r8, [r3, #dmaq_Usage]

        ; Link this block on the end of the list, so system channels get found as quickly as possible.
        STR     lr, [r9, #lcb_Next]

        ; Return channel handle in r0.
        MOV     r0, lr

        Debug   swi," channel handle =",r0

        EXIT

90
        Push    "r0"
        MOV     r0, #ModHandReason_Free
        MOV     r2, r8
        SWI     XOS_Module
        Pull    "r0"
        SETV
        EXIT
99
        Push    "r0"
        MOV     r0, #ModHandReason_Free
        MOV     r2, r8
        SWI     XOS_Module
        Pull    "r0"
        PullEnv
        DoError

      |

        Entry   "r6-r8"

        Debug   swi,"SWIRegisterChannel",r1

        ADR     r6, LogicalChannel              ; Find the logical channel number.
        MOV     lr, #NoLogicalChannels * 4
10
        SUBS    lr, lr, #4                      ; Work back from end of table.
        PullEnv CC                              ; Not found so return error.
        ADRCC   r0, ErrorBlock_DMA_BadChannel
        DoError CC
        LDR     r7, [r6, lr]
        TEQ     r1, r7
        BNE     %BT10

        ASSERT  LCBSize = 20
        ADR     r8, ChannelBlock
        ADD     r8, r8, lr, LSL #2
        ADD     r8, r8, lr                      ; r8->logical channel block

        LDR     r6, [r8, #lcb_Flags]
        TST     r6, #lcbf_Registered
        PullEnv NE                              ; Return error if already claimed.
        ADRNE   r0, ErrorBlock_DMA_AlreadyClaimed
        DoError NE

        CMP     r2, #4                          ; Validate cycle speed.
        PullEnv CS
        ADRCS   r0, ErrorBlock_DMA_BadCycleSpeed
        DoError CS

        TEQ     r3, #1                          ; Validate transfer unit size.
        TEQNE   r3, #2
        TEQNE   r3, #4
        TEQNE   r3, #16
        PullEnv NE
        ADRNE   r0, ErrorBlock_DMA_BadTransferUnit
        DoError NE

        TST     r4, #3                          ; Ensure vector table is word aligned.
        PullEnv NE
        ADRNE   r0, ErrorBlock_DMA_BadAddress
        DoError NE

        ORR     r0, r3, r2, LSL #5              ; Build flags in r0.
        ORR     r0, r0, #lcbf_Registered

        ADR     r6, PhysicalChannel
        LDRB    r7, [r6, lr, LSR #2]            ; r7 = physical channel number
        PhysToDMAQ r6, r7                       ; r6->DMA queue

        ASSERT  lcb_Flags = 0
        ASSERT  lcb_Vector = lcb_Flags + 4
        ASSERT  lcb_R12 = lcb_Vector + 4
        ASSERT  lcb_Queue = lcb_R12 + 4
        ASSERT  lcb_Physical = lcb_Queue + 4

        STMIA   r8, {r0,r4-r7}                  ; Store flags, vector, r12 value, queue and physical channel.

        MOV     r0, lr, LSR #2                  ; Return channel handle in r0.

        Debug   swi," channel handle =",r0

        TEQ     r7, #4                          ; If not registering a sound channel then
        TEQNE   r7, #5
        EXIT    NE                              ;   exit.

        Push    "r0-r2"

        IOMDBase r8
        IRQOff  r6, lr

        LDRB    r6, [r8, #IOMD_IOTCR]           ; Otherwise set up transfer size/speed in IOTCR.
        AND     r6, r6, #&0F
        ORR     r6, r6, r3, LSL #6
        ORR     r6, r6, r2, LSL #4
        STRB    r6, [r8, #IOMD_IOTCR]

        LDRB    r6, [r8, #IOMD_DMAMSK]          ; Disable sound channel and set up to claim device.
        TEQ     r7, #4
        MOVEQ   r0, #IOMD_DMASound0_DevNo
        ADREQL  r1, DMAInterruptSound0
        BICEQ   r6, r6, #IOMD_DMA_SD0
        MOVNE   r0, #IOMD_DMASound1_DevNo
        ADRNEL  r1, DMAInterruptSound1
        BICNE   r6, r6, #IOMD_DMA_SD1
        STRB    r6, [r8, #IOMD_DMAMSK]

        SetPSR  lr

        Debug   swi," claiming device vector",r0

        MOV     r2, r12
        SWI     XOS_ClaimDeviceVector           ; Claim appropriate sound device vector.

        Pull    "r0-r2"
        EXIT
      ]

        MakeErrorBlock  DMA_BadChannel
        MakeErrorBlock  DMA_AlreadyClaimed
        MakeErrorBlock  DMA_BadCycleSpeed
        MakeErrorBlock  DMA_BadTransferUnit
        MakeErrorBlock  DMA_BadAddress

;---------------------------------------------------------------------------
; SWIDeregisterChannel
;       In:     r0  = channel handle
;
;       Out:    all registers preserved
;
;       Deregister a previously registered channel handling vector.
;
SWIDeregisterChannel
      [ HAL
        Entry   "r0-r3,r7-r9"
      |
        Entry   "r1,r7,r8"
      ]

        Debug   swi,"SWIDeregisterChannel",r0

      [ HAL
        ADR     r9, ChannelList - lcb_Next
01      LDR     lr, [r9, #lcb_Next]
        TEQ     lr, #0
        TEQNE   lr, r0
        MOVNE   r9, lr
        BNE     %BT01
        TEQ     lr, #0                          ; Was handle in list?
        PullEnv EQ
        ADREQ   r0, ErrorBlock_DMA_BadHandle    ; No, so generate error.
        DoError EQ
        LDR     lr, [lr, #lcb_Next]             ; Delink.
        STR     lr, [r9, #lcb_Next]
      |
        CMP     r0, #NoLogicalChannels          ; Ensure handle in range.
        PullEnv CS
        ADRCS   r0, ErrorBlock_DMA_BadHandle
        DoError CS
      ]

        LCBlock r8, r0
      [ :LNOT: HAL
        LDR     r7, [r8, #lcb_Flags]            ; Ensure it's been claimed.
        TST     r7, #lcbf_Registered
        PullEnv EQ
        ADREQ   r0, ErrorBlock_DMA_BadHandle
        DoError EQ
      ]

        MOV     r7, #0                          ; Mark logical channel as not claimed.
      [ :LNOT: HAL
        STR     r7, [r8, #lcb_Flags]
      ]
        BL      DMAPurge                        ; r7=0 so new transfers can start.

      [ HAL
        LDR     r9, [r8, #lcb_Queue]
        LDR     r2, [r9, #dmaq_DMADevice] ; API 1.x requires r2 to be channel device ptr
        LDR     r0, [r2, #HALDevice_DMAController]
        LDR     r1, [r8, #lcb_ChannelNo]
        CallHAL DMACDeallocate

        LDR     r1, [r9, #dmaq_Usage]           ; Free the bounce buffer if necessary.
        SUBS    r1, r1, #1
        STR     r1, [r9, #dmaq_Usage]
        BNE     %FT80
        LDR     r0, [r9, #dmaq_BounceBuff + ptab_Logical]
        TEQ     r0, #0
        STRNE   r1, [r9, #dmaq_BounceBuff + ptab_Logical]
        STRNE   r1, [r9, #dmaq_BounceBuff + ptab_Physical]
        SWINE   XPCI_RAMFree
        LDR     r0, [r9, #dmaq_DescBlockLogical]
        TEQ     r0, #0
        STRNE   r1, [r9, #dmaq_DescBlockLogical]
        STRNE   r1, [r9, #dmaq_DescBlockPhysical]
        SWINE   PCI_RAMFree
80
        MOV     r0, #ModHandReason_Free
        MOV     r2, r8
        SWI     XOS_Module
        CLRV
      |
        TEQ     r0, #4
        TEQNE   r0, #5
        EXIT    NE                              ; If not a sound channel then exit.

        TEQ     r0, #4                          ; Release appropriate sound device vector.
        MOVEQ   r0, #IOMD_DMASound0_DevNo
        ADREQL  r1, DMAInterruptSound0
        MOVNE   r0, #IOMD_DMASound1_DevNo
        ADRNEL  r1, DMAInterruptSound1
        MOV     r2, r12
        SWI     XOS_ReleaseDeviceVector
      ]
        EXIT

        MakeErrorBlock  DMA_BadHandle

;---------------------------------------------------------------------------
; SWIQueueTransfer
;       In:     r0  = flags
;                       bit     meaning
;                       0       transfer direction:
;                               0 = from device to memory (read)
;                               1 = from memory to device (write)
;                       1       1 = scatter list is circular buffer
;                       2       1 = call DMASync callback
;                       3-31    reserved (set to 0)
;               r1  = channel handle
;               r2  = value to pass to vector routine in r11
;               r3  ->word aligned scatter list
;               r4  = length of transfer (in bytes)
;               r5  = size of circular buffer (if used)
;               r6  = number of bytes between DMASync callbacks (if used)
;
;       Out:    r0  = DMA tag
;               all other registers preserved
;
;       Queues a DMA request for the specified channel.
;
SWIQueueTransfer
        Entry   "r5-r11"

        Debug   swi,"SWIQueueTransfer, channel handle =",r1

      [ HAL
        LDR     lr, ChannelList
01      TEQ     lr, #0
        TEQNE   lr, r1
        LDRNE   lr, [lr, #lcb_Next]
        BNE     %BT01
        TEQ     lr, #0                          ; Was handle in list?
        PullEnv EQ
        ADREQ   r0, ErrorBlock_DMA_BadHandle    ; No, so generate error.
        DoError EQ
      |
        CMP     r1, #NoLogicalChannels          ; Ensure handle in range.
        PullEnv CS
        ADRCS   r0, ErrorBlock_DMA_BadHandle
        DoError CS
      ]

        LCBlock r8, r1
        LDR     lr, [r8, #lcb_Flags]            ; Ensure it's been claimed.
      [ :LNOT: HAL
        TST     lr, #lcbf_Registered
        PullEnv EQ
        ADREQ   r0, ErrorBlock_DMA_BadHandle
        DoError EQ
      ]

        TST     r3, #3                          ; Ensure scatter list is word aligned.
        PullEnv NE
        ADRNE   r0, ErrorBlock_DMA_BadAddress
        DoError NE

        TST     r0, #dmarf_Circular             ; If not circular then
        MOVEQ   r5, #0                          ;   buff size = 0
        MOVEQ   r7, r4                          ;   test for zero length below
        MOVNE   r7, r5                          ; else test for zero buffer size below
        ORRNE   r0, r0, #dmarf_Infinite         ;   assume infinite
        TEQNE   r4, #0                          ;   but if length<>0 then
        BICNE   r0, r0, #dmarf_Infinite         ;     not infinite.

        TEQ     r7, #0
        PullEnv EQ
        ADREQ   r0, ErrorBlock_DMA_ZeroLength
        DoError EQ

      [ HAL
        LDR     r7, [r8, #lcb_Queue]
        LDR     r7, [r7, #dmaq_DescBlockLogical]
        TEQ     r7, #0
        BEQ     %FT05
        LDR     r7, [r8, #lcb_Queue]            ; If it's a list device,
        LDR     r7, [r7, #dmaq_DeviceFeatures]
        LDR     r7, [r7, #DMAFeaturesBlock_Flags]
        TST     r0, #dmarf_Circular             ;   ensure it can do circular transfers if appropriate,
        TSTNE   r7, #DMAFeaturesFlag_NotCircular
        PullEnv NE
        ADRNE   r0, ErrorBlock_DMA_NotCircular
        DoError NE
        TST     r0, #dmarf_Infinite             ;   and check infinite transfers likewise.
        TSTNE   r7, #DMAFeaturesFlag_NotInfinite
        PullEnv NE
        ADRNE   r0, ErrorBlock_DMA_NotInfinite
        DoError NE
        B       %FT06                           ; We know we're not using a bounce buffer, so skip next test.
05
        CMP     r4, #BOUNCEBUFFSIZE             ; If longer than bounce buffer length
        ANDLS   r7, r0, #dmarf_Infinite
        CMPLS   r7, #0                          ;   or infinite transfer
        LDRHI   r7, [r8, #lcb_Queue]
        LDRHI   r7, [r7, #dmaq_BounceBuff + ptab_Logical]
        CMPHI   r7, #0                          ;   and we're using a bounce buffer
        PullEnv HI
        ADRHI   r0, ErrorBlock_DMA_TransferTooLong
        DoError HI                              ;   then do error.
06
      ]

        TST     r0, #dmarf_Sync                 ; If not calling DMASync then
        MOVEQ   r6, #0                          ;   sync gap = 0
        BEQ     %FT10
        TEQ     r6, #0
        PullEnv EQ
        ADREQ   r0, ErrorBlock_DMA_ZeroLength
        DoError EQ
10
        AND     lr, lr, #lcbf_TransferSize      ; lr=flags from above
        SUB     lr, lr, #1
        TST     lr, r4                          ; Ensure length is multiple of transfer unit size.
        TSTEQ   lr, r5                          ; Ensure buff size is multiple of t.u.s.
        TSTEQ   lr, r6                          ; Ensure sync gap is multiple of t.u.s.
        PullEnv NE
        ADRNE   r0, ErrorBlock_DMA_BadSize
        DoError NE

        ASSERT  dmar_R11 = dmar_Flags + 4
        ASSERT  dmar_ScatterList = dmar_R11 + 4
        ASSERT  dmar_Length = dmar_ScatterList + 4
        ASSERT  dmar_BuffSize = dmar_Length + 4
        ASSERT  dmar_SyncGap = dmar_BuffSize + 4
        ASSERT  dmar_Done = dmar_SyncGap + 4
        ASSERT  dmar_LCB = dmar_Done + 4
        ASSERT  dmar_PageTable = dmar_LCB + 4

        BL      DMAGetRequestBlock              ; Set up request block (r10=pointer).
        EXIT    VS

        ADD     lr, r10, #dmar_Flags
        MOV     r7, #0                          ; Set amount done to 0.
        MOV     r9, #0                          ; Set no page table
        Debug   swi," flags,r11,scat,len,buffsz,gap,LCB =",r0,r2,r3,r4,r5,r6,r8
        STMIA   lr, {r0,r2-r9}                  ; Store flags, r11, scat list, length, buff size, gap, done, LCB, page table.
      [ HAL
        STR     r7, [lr, #dmar_DoneAtStart - dmar_Flags]
      ]

        LDR     r5, TagIndex                    ; Build DMA request tag in r0.
        ADD     r5, r5, #1
      [ HAL
        STR     r5, [r10, #dmar_TagBits01]
        AND     r0, r5, #3
        ORR     r0, r0, r10
      |
        LDR     lr, [r8, #lcb_Physical]
        ORR     r0, lr, r5, LSL #3
        STR     r0, [r10, #dmar_Tag]
      ]

        Debug   swi," DMA tag = ",r0

        LDR     r9, [r8, #lcb_Queue]            ; r9->DMA queue
      [ HAL
        STR     r9, [r10, #dmar_Queue]
      ]
        BL      DMALinkRequest                  ; Stick it on the queue.
      [ :LNOT: HAL
        IOMDBase r11
      ]
        BL      DMAActivate                     ; Try to activate it.
        STRVC   r5, TagIndex
        STRVS   r7, [r9, #dmaq_Active]          ; If activate returned error then unblock channel
        BLVS    DMAUnlinkRequest                ;   and delete request.
        BLVS    DMAFreeRequestBlock
        EXIT

        MakeErrorBlock  DMA_ZeroLength
      [ HAL
        MakeErrorBlock  DMA_NotCircular
        MakeErrorBlock  DMA_NotInfinite
        MakeErrorBlock  DMA_TransferTooLong
      ]
        MakeErrorBlock  DMA_BadSize

;---------------------------------------------------------------------------
; SWITerminateTransfer
;       In:     r0  ->error block
;               r1  = DMA tag
;
;       Out:    all registers preserved
;
;       Terminate a DMA transfer if it is active or just remove from the queue.
;
SWITerminateTransfer
        Entry   "r0,r8-r11"

        Debug   swi,"SWITerminateTransfer",r1

        BL      DMAFindTag
        STRVS   r0, [sp]
        EXIT    VS

        TEQ     r0, #0                          ; If caller provides no error then
        ADREQ   r0, ErrorBlock_DMA_Terminated   ;   use our own (or DMATerminate will think we're suspending).
        BLEQ    MsgTrans_ErrorLookup

        LDR     r8, [r10, #dmar_LCB]            ; r8->logical channel block
      [ :LNOT: HAL
        IOMDBase r11
      ]
        CLRV
        BL      DMATerminate                    ; Terminate (if active, physical channel remains blocked).
        STRVS   r0, [sp]
        EXIT    VS

        BL      DMAUnlinkRequest
        LDR     lr, [r10, #dmar_Flags]
        TST     lr, #dmarf_Blocking :OR: dmarf_Halted ; If it was blocking logical channel then
        LDRNE   lr, [r8, #lcb_Flags]            ;   unblock it.
        BICNE   lr, lr, #lcbf_Blocked
        STRNE   lr, [r8, #lcb_Flags]
        LDR     lr, [r9, #dmaq_Active]
        TEQ     lr, r10                         ; If it was active then
        BLEQ    DMASearchQueue                  ;   try to start something else (unblock physical channel).
        BL      DMAFreeRequestBlock

        EXIT

        MakeErrorBlock  DMA_Terminated

;---------------------------------------------------------------------------
; SWISuspendTransfer
;       In:     r0  = flags
;                       bit     meaning
;                       0       0 = don't start queued transfers
;                               1 = start next queued transfer
;                       1-31    reserved (set to 0)
;               r1  = DMA tag
;
;       Out:    all registers preserved
;
;       Suspend a DMA transfer.
;
SWISuspendTransfer
        Entry   "r0,r8-r11"

        Debug   swi,"SWISuspendTransfer",r1

        BL      DMAFindTag
        STRVS   r0, [sp]
        EXIT    VS

        LDR     r8, [r10, #dmar_LCB]            ; r8->logical channel block
      [ :LNOT: HAL
        IOMDBase r11
      ]
        MOV     r0, #0                          ; Suspend not terminate.
        BL      DMATerminate                    ; Terminate (physical channel should remain blocked).
        STRVS   r0, [sp]
        EXIT    VS

        LDR     lr, [r10, #dmar_Flags]
        TST     lr, #dmarf_Completed            ; If completed anyway then
        BLNE    DMAUnlinkRequest                ;   free block,
        BLNE    DMAFreeRequestBlock
        BNE     %FT10                           ;   and unblock physical channel.

      [ HAL
        ORR     lr, lr, #dmarf_Suspended        ; Mark as suspended.
      |
        ORR     lr, lr, #dmarf_Suspended :OR: dmarf_BeenActive  ; Mark as suspended and been active.
      ]
        LDR     r0, [sp]
        TST     r0, #&00000001                  ; If don't want queued transfers to start
        LDREQ   r0, [r8, #lcb_Flags]
        TSTEQ   r0, #lcbf_Blocked               ;     and the channel is not blocked already then
        ORREQ   r0, r0, #lcbf_Blocked           ;   block logical channel
        STREQ   r0, [r8, #lcb_Flags]
        ORREQ   lr, lr, #dmarf_Blocking         ;   and mark as blocking.
        STR     lr, [r10, #dmar_Flags]
10
        BL      DMASearchQueue                  ; Try to start another request (unblock physical channel).
        EXIT

;---------------------------------------------------------------------------
; SWIResumeTransfer
;       In:     r0  = flags
;                       bit     meaning
;                       0       1 = move to head of queue
;                       1-31    reserved (set to 0)
;               r1  = DMA tag
;
;       Out:    all registers preserved
;
;       Resume a previously suspended DMA transfer.
;
SWIResumeTransfer
        Entry   "r8-r11"

        Debug   swi,"SWIResumeTransfer",r1

        BL      DMAFindTag
        EXIT    VS

        LDR     lr, [r10, #dmar_Flags]          ; Make sure it's suspended.
        TST     lr, #dmarf_Suspended
        PullEnv EQ
        ADREQ   r0, ErrorBlock_DMA_NotSuspended
        DoError EQ

        LDR     r8, [r10, #dmar_LCB]            ; r8->logical channel block
        BIC     lr, lr, #dmarf_Suspended        ; Mark as not suspended.
        TST     lr, #dmarf_Blocking             ; If blocking then
        BICNE   lr, lr, #dmarf_Blocking         ;   clear blocking bit.
        STR     lr, [r10, #dmar_Flags]
        BEQ     %FT10
        TST     lr, #dmarf_Halted               ; If not now halted either then
        LDREQ   lr, [r8, #lcb_Flags]            ;   unblock logical channel.
        BICEQ   lr, lr, #lcbf_Blocked
        STREQ   lr, [r8, #lcb_Flags]
10
      [ :LNOT: HAL
        IOMDBase r11
      ]
        BL      DMAActivate
        MOVVS   lr, #0                          ; If Start callback returned error then
        STRVS   lr, [r9, #dmaq_Active]          ;   unblock channel
        BLVS    DMAUnlinkRequest                ;   and delete request.
        BLVS    DMAFreeRequestBlock
        EXIT

        MakeErrorBlock  DMA_NotSuspended

;---------------------------------------------------------------------------
; SWIExamineTransfer
;
;       In:     r0  = flags
;                       bit     meaning
;                       0-31    reserved (set to 0)
;               r1  = DMA tag
;
;       Out:    r0  = number of bytes transferred so far, or error pointer (eg "Bus error")
;               All other registers preserved
;
;       Examine the progress of an active DMA transfer.
;
SWIExamineTransfer
      [ HAL
        Entry   "r1,r6-r10"
      |
        Entry   "r1,r7-r10"
      ]

        Debug   swi,"SWIExamineTransfer",r1

        BL      DMAFindTag
        EXIT    VS

        IRQOff  lr, r7                          ; Stop interrupt routine finishing transfer.

      [ :LNOT: HAL
        LDR     lr, [r10, #dmar_Tag]            ; Make sure it's still there.
        TEQ     lr, r1
        ADRNE   r0, ErrorBlock_DMA_BadTag
        BNE     %FT10
      ]

        LDR     r1, [r10, #dmar_Done]           ; Get amount of transfer done.
        LDR     r8, [r10, #dmar_LCB]            ; r8->logical channel block
        LDR     lr, [r10, #dmar_Flags]
        TST     lr, #dmarf_Completed + dmarf_Suspended
        MOVNE   r0, #0                          ; If completed or suspended then just return dmar_Done.
        BNE     %FT05

        LDR     r0, [r9, #dmaq_Active]
        CMP     r0, r10
        MOVNE   r0, #0                          ; If not yet started then then just return dmar_Done (which will be 0).
      [ HAL
        BNE     %FT05
        LDR     r6, [r10, #dmar_Length]         ; Remember the amount that was to be done (DMAActiveDone may change this).
        TST     lr, #dmarf_Infinite
        MOVNE   r6, #-1                         ; If infinite, pretend an unlikely amount still to do.
        BL      DMAActiveDone                   ; If transfer is active then get amount of active buffer done.
        LDR     lr, [r9, #dmaq_DMADevice]
        LDR     lr, [lr, #HALDevice_Device]
        TestMinusOne lr
        BNE     %FT05                           ; If device has its own interrupt, then let it handle completion or errors.
        TEQVC   r0, r6
        BNE     %FT05                           ; If no error and stuff still to do, take no action.
        Push    "r0"
        MOVVC   r0, #0
        Push    "r0"
        BL      DMACompleted
        BL      DMAUnlinkRequest
        BL      DMAFreeRequestBlock
        BL      DMASearchQueue
        Pull    "r0"
        TEQ     r0, #0
        SETV    NE
        Pull    "r0"
      |
        BLEQ    DMAActiveDone                   ; If transfer is active then get amount of active buffer done.
      ]
05
        SetPSR  r7,, c
        ADDVC   r0, r0, r1                      ; Return total (if not error).
        EXIT

      [ :LNOT: HAL
10
        SetPSR  r7
        PullEnv
        DoError
      ]


 [ HAL
;---------------------------------------------------------------------------
; SWIAllocateLogicalChannels
;
;       In:     r0  = number of channels to allocate
;
;       Out:    r0  = number of first channel
;               All other registers preserved
;
;       Allocate one or more logical channels.
;
SWIAllocateLogicalChannels
        LDR     r10, NextLogicalChannel
        ADD     r11, r10, r0
        STR     r11, NextLogicalChannel
        MOV     r0, r10
        MOV     pc, lr
 ]


        END
