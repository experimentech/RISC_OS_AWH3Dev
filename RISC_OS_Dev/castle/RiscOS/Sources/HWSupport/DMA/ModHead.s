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
; > Sources.ModHead

        ENTRY

        ASSERT  (.=Module_BaseAddr)

        DCD     0                               ; Start
        DCD     Init           - Module_BaseAddr
        DCD     Die            - Module_BaseAddr
        DCD     Service        - Module_BaseAddr
        DCD     Title          - Module_BaseAddr
        DCD     Helpstr        - Module_BaseAddr
      [ HAL
        DCD     Command        - Module_BaseAddr
      |
        DCD     0                               ; Helptable
      ]
        DCD     Module_SWISystemBase + DMAManagerSWI * Module_SWIChunkSize
        DCD     SWIhandler     - Module_BaseAddr
        DCD     SWInames       - Module_BaseAddr
        DCD     0                               ; SWIdecode
        ASSERT  international
        DCD     message_filename - Module_BaseAddr
        DCD     ModFlags       - Module_BaseAddr

;---------------------------------------------------------------------------
Title   DCB     "DMAManager",0
Helpstr DCB     "DMAManager",9,"$Module_HelpVersion",0
                ALIGN

; GET Hdr:Debug
; InsertDebugRoutines

ModFlags
      [ No32bitCode
        DCD     0
      |
        DCD     ModuleFlag_32bit
      ]

      [ HAL
Command
        Command DMAChannels, 0, 0, International_Help
        &       0

        ASSERT  International_Help<>0

DMAChannels_Help   = "HDMADCH", 0
DMAChannels_Syntax = "SDMADCH", 0

        ALIGN
      ]

;---------------------------------------------------------------------------
;       Module initialisation point.
;
Init
        Entry

        Debug   mod,"Init"

 [ debug
        Debug_Open
 ]

        LDR     r2, [r12]                       ; Have we already got a workspace ?
        TEQ     r2, #0
        BNE     %FT01

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =max_running_work
        SWI     XOS_Module                      ; Claim workspace.
        EXIT    VS

        STR     r2, [r12]                       ; Store workspace pointer.
01
        MOV     r12, r2

      [ HAL
        MOV     r0, #0
        STR     r0, NextLogicalChannel          ; Ensure uninitialised.
      ]
 [ standalone
        ADRL    r0, resourcefsfiles
        SWI     XResourceFS_RegisterFiles
 ]
        BLVC    InitWS
        BLVC    InitHardware

        BLVS    ShutDown
        EXIT

;---------------------------------------------------------------------------
; InitWS
;
;       Out:    r0 corrupted
;
;       Initialise our workspace.
;
InitWS
      [ HAL
        Entry   "r0-r4,r8"
      |
        Entry   "r1,r2"
      ]

        Debug   mod,"InitWS"

        MOV     r0, #0                          ; Initialise workspace.
 [ international
        STR     r0, message_file_open
 ]
        STR     r0, DMABlockHead
        STR     r0, FreeBlock
        STR     r0, TagIndex
        STR     r0, UnsafePageTable
        STR     r0, UnsafePageCount

      [ HAL

        STR     r0, ChannelList                 ; Don't free anything silly in error cases.
        STR     r0, CtrlrList
        STRB    r0, PreReset

        SUB     sp, sp, #4
        ADR     r0, NextLogicalChannelSysVar
        MOV     r1, sp
        MOV     r2, #4
        MOV     r4, #0
        SWI     XOS_ReadVarVal                  ; Try to read last unassigned logical channel
        Pull    "r1"                            ;   from a previous life.
        TEQ     r4, #VarType_Number
        SETV    NE
        MOVVS   r1, #&1000                      ; Default, assume this is the first time.
        STR     r1, NextLogicalChannel
        ADR     r0, NextLogicalChannelSysVar
        MOV     r2, #-1
        MOV     r4, #VarType_Number
        SWI     XOS_SetVarVal                   ; Delete the variable, we no longer need it.

        ADR     r3, CtrlrList - ctrlr_Next
        LDR     r0, =(1:SHL:16) + HALDeviceType_SysPeri + HALDeviceSysPeri_DMAC
        MOV     r1, #0
        MOV     r8, #OSHW_DeviceEnumerate
05      SWI     XOS_Hardware
        ADRVS   r0, ErrorBlock_DMA_BadHard
        PullEnv VS
        DoError VS
        CMP     r1, #-1
        BLNE    AddController
        CMP     r1, #-1
        STRNE   r2, [r3, #ctrlr_Next]           ; Append new controller to end of list
        MOVNE   r3, r2                          ; (maintains order returned by search).
        BNE     %BT05
        ; V will be clear

      |

        ADR     r1, ChannelBlock + lcb_Flags    ; Initialise logical channel table.
        MOV     r2, #NoLogicalChannels
10
        SUBS    r2, r2, #1
        STRCS   r0, [r1], #LCBSize              ; Initialise all lcb_Flags to 0.
        BCS     %BT10

        ADR     r1, DMAQueues                   ; Initialise DMA queues.
        MOV     r2, #NoPhysicalChannels * DMAQSize / 4
20
        SUBS    r2, r2, #1
        STRCS   r0, [r1], #4                    ; Zero all pointers.
        BCS     %BT20

      ]

 [ debugtab
        MOV     r0, #0
        DebugTabInit r0,r1,lr
        Debug   tab,"Debug table at",r1
 ]

        EXIT

 [ HAL
NextLogicalChannelSysVar
        =       "DMAManager$$NextLogicalChannel", 0
        ALIGN
 ]

;---------------------------------------------------------------------------
; InitHardware
;
;       Out:    r0 corrupted
;     [ HAL
;               r1-r6 corrupted
;     ]
;
;       Initialise DMA hardware.
;
InitHardware
      [ HAL
        Entry
        ; Check for bad hardware now done in InitWS
        LDR     r4, CtrlrList
        TEQ     r4, #0
        EXIT    EQ                              ; Don't error here -
                                                ; controller(s) may now be declared later!
01      BL      InitController
        LDR     r4, [r4]
        TEQ     r4, #0
        BNE     %BT01
      |
        Entry   "r1,r2"

        MOV     r0, #2                          ; Read system information.
        SWI     XOS_ReadSysInfo
        EXIT    VS
        AND     r0, r0, #&0000FF00
        TEQ     r0, #&00000100                  ; If no IOMD
        ANDEQS  r2, r2, #&0000FF00              ;   or IOMD variant does not support DMA
        ADRNE   r0, ErrorBlock_DMA_BadHard      ; then return error.
        PullEnv NE
        DoError NE

        IOMDBase r1

        IRQOff  r2, lr
        LDRB    r0, [r1, #IOMD_DMAMSK]          ; Disable all but sound channels.
        BIC     r0, r0, #IOMD_DMA_IO0 :OR: IOMD_DMA_IO1 :OR: IOMD_DMA_IO2 :OR: IOMD_DMA_IO3
        STRB    r0, [r1, #IOMD_DMAMSK]
        SetPSR  lr

        MOV     r0, #&0C                        ; Channels 2 and 3 are external peripherals.
        STRB    r0, [r1, #IOMD_DMAEXT]

        BL      ClaimVectors
      ]

        EXIT

        MakeErrorBlock  DMA_BadHard

 [ HAL
;---------------------------------------------------------------------------
; ServiceDevice
;
;       In:     r0 bits 0-7 = 0 => device added
;                           = 1 => device about to be removed
;               r2 -> device
;       Out:    r1 = 0 and r0 -> error if we object to removal, else all registers preserved
;
ServiceDevice
        TST     r0, #&FF
        BEQ     DeviceAdded
        TST     r0, #&FE
        MOVNE   pc, r14

DeviceRemove
        Push    "r14"
        LDR     r14, [r2, #HALDevice_Version]
        TST     r14, #&FF:SHL:24
        TSTEQ   r14, #&FE:SHL:16
        Pull    "pc", NE        ; We only understand major versions 0 & 1 of any device type
        Push    "r3-r6"
        LDR     r14, [r2, #HALDevice_Type]
        LDR     r4, =(HALDeviceType_SysPeri + HALDeviceSysPeri_DMAC) :SHL: 16
        LDR     r5, =(HALDeviceType_SysPeri + HALDeviceSysPeri_DMAB) :SHL: 16
        LDR     r6, =(HALDeviceType_SysPeri + HALDeviceSysPeri_DMAL) :SHL: 16
        CMP     r4, r14, LSL #16
        CMPNE   r5, r14, LSL #16
        CMPNE   r6, r14, LSL #16
        Pull    "r3-r6,pc", NE
        CMP     r4, r14, LSL #16
        BNE     %FT50

        ; r2 -> DMA controller device being removed - are any of its channels in use?
        ADR     r6, CtrlrList - ctrlr_Next
10      LDR     r4, [r6, #ctrlr_Next]
        LDR     r5, [r4, #ctrlr_Device]
        TEQ     r5, r2
        MOVNE   r6, r4
        BNE     %BT10

        LDR     r5, [r4, #ctrlr_PhysicalChannels]
        ADD     r3, r4, #ctrlr_DMAQueues + dmaq_Usage
20      LDR     r14, [r3], #DMAQSize
        TEQ     r14, #0
        BNE     %FT30
        SUBS    r5, r5, #1
        BNE     %BT20

        ; No channels in use, remove controller
        Push    "r0-r2"
        LDR     r14, [r4, #ctrlr_Next]
        STR     r14, [r6, #ctrlr_Next]
        BL      ForgetController
        MOV     r0, #ModHandReason_Free
        MOV     r2, r4
        SWI     XOS_Module
        Pull    "r0-r6,pc"

30      ; Channel(s) in use
        Pull    "r3-r6,r14"
        ADR     r0, ErrorBlock_DMA_CtrlrInUse
        MOV     r1, #0
        DoError

50      ; r2 -> DMA channel being removed - is it in use?
        LDR     r6, [r2, #HALDevice_DMAController]
        LDR     r4, CtrlrList
60      TEQ     r4, #0
        BEQ     %FT78
        LDR     r5, [r4, #ctrlr_Device]
        TEQ     r5, r6
        LDRNE   r4, [r4, #ctrlr_Next]
        BNE     %BT60

        ADD     r3, r4, #ctrlr_DMAQueues + dmaq_DMADevice
70      LDR     r5, [r3], #DMAQSize
        TEQ     r5, r2
        BNE     %BT70

        LDR     r14, [r3, #-(DMAQSize + dmaq_DMADevice) + dmaq_Usage]
        TEQ     r14, #0
        BNE     %FT80

78      ; Channel not in use
        Pull    "r3-r6,pc"

80      ; Channel in use
        Pull    "r3-r6,r14"
        ADR     r0, ErrorBlock_DMA_ChanInUse
        MOV     r1, #0
        DoError

DeviceAdded
        Push    "r14"
        LDR     r14, [r2, #HALDevice_Version]
        TST     r14, #&FF:SHL:24
        TSTEQ   r14, #&FE:SHL:16
        Pull    "pc", NE        ; We understand major versions 0 & 1
        Push    "r6"
        LDR     r14, [r2, #HALDevice_Type]
        LDR     r6, =(HALDeviceType_SysPeri + HALDeviceSysPeri_DMAC) :SHL: 16
        CMP     r6, r14, LSL #16
        Pull    "r6,pc", NE
        Push    "r0-r5"
        BL      AddController
        BVS     %FT90
        MOV     r4, r2
        BL      InitController
        LDRVC   r0, CtrlrList
        STRVC   r0, [r4, #ctrlr_Next]
        STRVC   r4, CtrlrList   ; Add to start of list (that's where it would be enumerated)
        MOVVS   r0, #ModHandReason_Free
        MOVVS   r2, r4
        SWIVS   XOS_Module
90
        Pull    "r0-r6,pc"

        MakeErrorBlock DMA_CtrlrInUse
        MakeErrorBlock DMA_ChanInUse

;---------------------------------------------------------------------------
; AddController
;
;       In:     r2 -> HAL device for new controller
;       Out:    r2 -> controller block
;               controller not linked into list (we don't whether to add at start or end)
;
AddController
        Entry   "r0-r1,r3-r5"
        MOV     r4, r2
        MOV     r0, r4
        CallHAL DMACEnumerate
        ADD     r5, r0, r1, LSL #2

        ASSERT  DMAQSize=112
        MOV     r0, #ModHandReason_Claim   ; Create and initialise controller block.
        MOV     r3, r1, LSL #7
        SUB     r3, r3, r1, LSL #4
        ADD     r3, r3, #CtrlrSize
        SWI     XOS_Module
        STRVS   r0, [sp]
        EXIT    VS

        MOV     r0, r4
        ASSERT  ctrlr_Device = 4
        ASSERT  ctrlr_PhysicalChannels = 8
        STMIB   r2, {r0,r1}
        MOV     r4, #0
        STR     r4, [r2], #ctrlr_DMAQueues
        SUB     r3, r3, #CtrlrSize

10      SUBS    r3, r3, #4
        STRCS   r4, [r2, r3]
        BCS     %BT10

        ASSERT  DMAQSize=112
        MOV     r3, r1, LSL #7
        SUB     r3, r3, r1, LSL #4
        SUB     r3, r3, #DMAQSize - dmaq_DMADevice
15      LDR     lr, [r5, #-4]! ; Make sure that channel 0 is at the start of the block, for the TestIRQ2-based trampolines to work cleanly 
        STR     lr, [r2, r3]
        SUBS    r3, r3, #DMAQSize
        BPL     %BT15

        SUB     r2, r2, #ctrlr_DMAQueues
        EXIT

;---------------------------------------------------------------------------
; InitController
;
;       In:     r4 -> controller block
;       Out:    r0-r3,r5-r6 corrupted
;
InitController
        Entry   "r4"

01      LDR     r5, [r4, #ctrlr_PhysicalChannels]
        ADD     r6, r4, #ctrlr_DMAQueues

        LDR     r0, [r4, #ctrlr_Device]
        CallHAL Activate                        ; Activate controller.

02      LDR     r0, [r6, #dmaq_DMADevice]
        CallHAL DMAFeatures
        STR     r0, [r6, #dmaq_DeviceFeatures]  ; Cache channel features.
        ADD     r6, r6, #DMAQSize
        SUBS    r5, r5, #1
        BNE     %BT02

        BL      ClaimVectors

        EXIT
 ]

;---------------------------------------------------------------------------
; ClaimVectors
;
;     [ HAL
;       In:     r4 -> controller block
;     ]
;       Out:    r0 corrupted
;     [ HAL
;               r1-r6 corrupted
;     ]
;
;       Claim device vectors for DMA interrupts.
;
ClaimVectors
      [ HAL
        Entry   ; r0-r6 trashable
        ; For controller API version 0.0, only the channels can be used to detect the source of an IRQ.
        ; However for API version 0.1+, a new entry point was added to allow the controller
        ; to detect the IRQ source.
        LDR     r6, [r4, #ctrlr_Device]
        LDR     r1, [r6, #HALDevice_Version]
        CMP     r1, #0
        LDRNE   r1, [r6, #HALDevice_DMACTestIRQ2]
        CMPNE   r1, #0
        BNE     %FT10           ; Controller TestIRQ2 supported
        
        ADD     r1, r4, #ctrlr_DMAQueues + dmaq_Trampoline
        LDR     r4, [r4, #ctrlr_PhysicalChannels]

01      ; For each channel on this controller...
        LDR     r6, [r1, #-dmaq_Trampoline + dmaq_DMADevice]
        LDR     r5, [r6, #HALDevice_Device]
        CMP     r5, #-1         ; no interrupt for this channel?
        BEQ     %FT08

        ; Create trampoline
        TST     r5, #1:SHL:31   ; Shared vector?
        ADREQ   lr, TrampolineTemplate
        ADRNE   lr, TrampolineTemplate_Vectored
        LDRB    r0, [r6, #HALDevice_Type + 0]
        STR     r6, [r1, #12*4] ; Store channel device ptr
        TEQ     r0, #HALDeviceSysPeri_DMAL
        ; Copy 12 words of code for the trampoline
        LDMIA   lr!, {r0,r2,r3,r6}
        STMIA   r1!, {r0,r2,r3,r6}
        LDMIA   lr!, {r0,r2,r3,r6}
        STMIA   r1!, {r0,r2,r3,r6}
        LDMIA   lr!, {r0,r2,r3,r6}
        STMIA   r1!, {r0,r2,r3,r6}
        SUB     r1, r1, #12*4
        ADRNEL  lr, DMAInterruptCommon
        ADREQL  lr, DMAInterruptList
        STR     lr, [r1, #11*4] ; Store handler ptr
        SUB     r6, r1, #dmaq_Trampoline
        STR     r6, [r1, #10*4] ; Store DMA queue ptr
        LDR     r6, [r6, #dmaq_DeviceFeatures]
        LDREQ   r6, [r6, #DMAFeaturesBlock_Flags]

        MOV     r0, #1
        ADD     r2, r1, #12*4-4
        SWI     XOS_SynchroniseCodeAreas

        MOV     r0, r5
        MOV     r2, r12
        SWI     XOS_ClaimDeviceVector
        BVS     %FT09

        TST     r6, #DMAFeaturesFlag_NoInitIRQ
        BEQ     %FT08

        ; There's no initial IRQ pending when Activate is called
        ; so enable the IRQ all the time for this channel
        Push    "r1,r8,r9"
        BIC     r0, r5, #1:SHL:31
        MOV     r8, #OSHW_CallHAL
        MOV     r9, #EntryNo_HAL_IRQEnable
        SWI     XOS_Hardware
        Pull    "r1,r8,r9"
        BVS     %FT09

08      ADD     r1, r1, #DMAQSize
        SUBS    r4, r4, #1
        BNE     %BT01           ; ...next channel
        ; V will be clear
09
        EXIT
                

TrampolineTemplate
        STMDB   sp!, {r12, lr}
        LDR     a1, TChan
        MOV     lr, pc
        LDR     pc, [a1, #HALDevice_TestIRQ]
        LDR     r12, [sp], #4   ; retrieve module wsptr for the likely case that IRQ is genuine
        TEQ     a1, #0
        ADRNE   a1, TArgs       ; no flags if we're ever run in 26-bit mode
        LDMNEIA a1, {a1, pc}    ; interrupt handler now entered with return address on stack
        LDR     pc, [r13], #4   ; else return if bogus IRQ (can't pass on)
        NOP                     ; so next three words are at same position as in vectored case
TArgs   DCD     0               ; needs patching with address of DMA queue
        DCD     0               ; needs patching with DMAInterruptCommon or DMAInterruptList
TChan   DCD     0               ; needs patching with address of DMA channel HAL device

TrampolineTemplate_Vectored
        STMDB   sp!, {r12, lr}
        LDR     a1, TVChan
        MOV     lr, pc
        LDR     pc, [a1, #HALDevice_TestIRQ]
        TEQ     a1, #0
        ADDEQ   sp, sp, #4      ; junk module wsptr and
        LDREQ   pc, [sp], #4    ; pass on if not claimed
        LDR     r12, [sp], #8   ; else retrieve module wsptr and junk pass-on address
        ADR     a1, TVArgs      ; no flags if we're ever run in 26-bit mode
        LDMIA   a1, {a1, pc}    ; interrupt handler now entered with return address on stack
TVArgs  DCD     0               ; needs patching with address of DMA queue
        DCD     0               ; needs patching with DMAInterruptCommon or DMAInterruptList
TVChan  DCD     0               ; needs patching with address of DMA channel HAL device


10
        ; Create one single trampoline to service all the channels for this controller
        ; The trampoline will be stored in the trampoline slot for the first channel
        ; On entry (via ClaimVectors):
        ; r4 = controller block
        ; r6 = controller device
        ; Return address on stack
        ; On exit:
        ; r0-r6 trashed
        ADD     r1, r4, #ctrlr_DMAQueues + dmaq_Trampoline
        LDR     r5, [r6, #HALDevice_Device]
        TST     r5, #1:SHL:31   ; Shared vector?
        ADREQ   lr, TrampolineTemplate_Controller
        ADRNE   lr, TrampolineTemplate_Controller_Vectored
        ; The type of the first channel is the type of all the channels
        LDR     r0, [r1, #-dmaq_Trampoline + dmaq_DMADevice]
        LDRB    r0, [r0, #HALDevice_Type + 0]
        STR     r6, [r1, #12*4] ; Store controller device ptr
        TEQ     r0, #HALDeviceSysPeri_DMAL
        ; Copy 11 words of code for the trampoline
        LDMIA   lr!, {r0,r2,r3,r6}
        STMIA   r1!, {r0,r2,r3,r6}
        LDMIA   lr!, {r0,r2,r3,r6}
        STMIA   r1!, {r0,r2,r3,r6}
        LDMIA   lr!, {r0,r2,r3}
        STMIA   r1!, {r0,r2,r3}
        SUB     r1, r1, #11*4
        ADRNEL  lr, DMAInterruptCommon
        ADREQL  lr, DMAInterruptList
        STR     lr, [r1, #11*4] ; Store handler ptr

        MOV     r0, #1
        ADD     r2, r1, #11*4-4
        SWI     XOS_SynchroniseCodeAreas

        MOV     r0, r5
        MOV     r2, r12
        SWI     XOS_ClaimDeviceVector
        BVS     %FT19

        ; We know TestIRQ2 is supported, so this controller can't have initially
        ; set IRQs otherwise all the channels would interrupt and swamp DMAManager.
        ; So, enable the IRQ that corresponds to this controller.
        Push    "r8,r9"
        BIC     r0, r5, #1:SHL:31
        MOV     r8, #OSHW_CallHAL
        MOV     r9, #EntryNo_HAL_IRQEnable
        SWI     XOS_Hardware
        Pull    "r8,r9"
19
        EXIT

TrampolineTemplate_Controller
        STMDB   sp!, {r12, lr}
        LDR     a1, TCCont
        MOV     lr, pc
        LDR     pc, [a1, #HALDevice_DMACTestIRQ2]
        LDR     r12, [sp], #4   ; retrieve module wsptr for the likely case that IRQ is genuine
        ASSERT  DMAQSize=112
        RSBS    a1, a1, a1, LSL #3 ; a1=a1*7, so still negative if a1=-1
        SUBPL   a2, pc, #8*4+(:INDEX:dmaq_Trampoline) ; Get ptr to DMA queue 0. This relies on the trampolines being stored as part of the queue list!
        ADDPL   a1, a2, a1, LSL #4
        LDRPL   pc, TCHand      ; interrupt handler now entered with return address on stack
        LDR     pc, [r13], #4   ; else return if bogus IRQ (can't pass on)
        NOP                     ; so next two words words are at same position as in vectored case
TCHand  DCD     0               ; needs patching with DMAInterruptCommon or DMAInterruptList
TCCont  DCD     0               ; needs patching with address of DMA controller HAL device

TrampolineTemplate_Controller_Vectored
        STMDB   sp!, {r12, lr}
        LDR     a1, TCVCont
        MOV     lr, pc
        LDR     pc, [a1, #HALDevice_DMACTestIRQ2]
        ASSERT  DMAQSize=112
        RSBS    a1, a1, a1, LSL #3
        ADDMI   sp, sp, #4      ; junk module wsptr and
        LDRMI   pc, [sp], #4    ; pass on if not claimed
        LDR     r12, [sp], #8   ; else retrieve module wsptr and junk pass-on address
        SUB     a2, pc, #10*4+(:INDEX:dmaq_Trampoline) ; Get ptr to DMA queue 0. This relies on the trampolines being stored as part of the queue list!
        ADD     a1, a2, a1, LSL #4
        LDR     pc, TCVHand     ; interrupt handler now entered with return
TCVHand DCD     0               ; needs patching with DMAInterruptCommon or DMAInterruptList
TCVCont DCD     0               ; needs patching with address of DMA controller HAL device
      |
        Entry   "r1,r2"

        MOV     r0, #IOMD_DMAChannel0_DevNo
        ADRL    r1, DMAInterruptChannel0
        MOV     r2, r12
        SWI     XOS_ClaimDeviceVector

        MOVVC   r0, #IOMD_DMAChannel1_DevNo
        ADRVCL  r1, DMAInterruptChannel1
        SWIVC   XOS_ClaimDeviceVector

        MOVVC   r0, #IOMD_DMAChannel2_DevNo
        ADRVCL  r1, DMAInterruptChannel2
        SWIVC   XOS_ClaimDeviceVector

        MOVVC   r0, #IOMD_DMAChannel3_DevNo
        ADRVCL  r1, DMAInterruptChannel3
        SWIVC   XOS_ClaimDeviceVector

        EXIT
      ]

 [ HAL
;---------------------------------------------------------------------------
; ForgetController
;
;       In:     r4 -> controller block
;       Out:    r0-r3,r5-r6 corrupted
;
ForgetController
        Entry

01      LDR     r5, [r4, #ctrlr_PhysicalChannels]
        ADD     r6, r4, #ctrlr_DMAQueues

        LDR     r0, [r4, #ctrlr_Device]
        CallHAL Deactivate                      ; Deactivate controller.

02      LDR     r0, [r6, #dmaq_BounceBuff + ptab_Logical]
        TEQ     r0, #0
        SWINE   PCI_RAMFree
        LDR     r0, [r6, #dmaq_DescBlockLogical]
        TEQ     r0, #0
        SWINE   PCI_RAMFree

        ADD     r6, r6, #DMAQSize
        SUBS    r5, r5, #1
        BNE     %BT02

        BL      ReleaseVectors

        EXIT
 ]

;---------------------------------------------------------------------------
; ReleaseVectors
;
;     [ HAL
;       In:     r4 -> controller block
;     ]
;       Out:    all registers preserved
;     [ HAL
;               r0-r3 corrupted
;     ]
;
;       Release device vectors for DMA interrupts.
;
ReleaseVectors
      [ HAL
        Entry   ; r0-r6 trashable
        ADD     r1, r4, #ctrlr_DMAQueues + dmaq_Trampoline
        LDR     r0, [r4, #ctrlr_Device]
        LDR     r3, [r0, #HALDevice_Version]
        CMP     r3, #0
        LDRNE   r3, [r6, #HALDevice_DMACTestIRQ2]
        CMPNE   r3, #0
        LDREQ   r3, [r4, #ctrlr_PhysicalChannels] ; Controller doesn't support TestIRQ2, so has full compliment of trampolines
        MOVNE   r3, #1 ; Controller does support TestIRQ2, so only has 1 trampoline
        MOV     r2, r12
        BNE     %FT02 ; Skip device lookup, we want to deregister the nonshared controller IRQ, not the shared channel IRQ (which devices retain for backwards compatability)

01      LDR     r0, [r1, #-dmaq_Trampoline + dmaq_DMADevice]
02      LDR     r0, [r0, #HALDevice_Device]
        CMP     r0, #-1         ; no interrupt for this channel?
        SWINE   XOS_ReleaseDeviceVector

        ADD     r1, r1, #DMAQSize
        SUBS    r3, r3, #1
        BNE     %BT01
        EXIT
      |
        Entry   "r0-r2"

        MOV     r0, #IOMD_DMAChannel0_DevNo
        ADRL    r1, DMAInterruptChannel0
        MOV     r2, r12
        SWI     XOS_ReleaseDeviceVector

        MOV     r0, #IOMD_DMAChannel1_DevNo
        ADRL    r1, DMAInterruptChannel1
        SWI     XOS_ReleaseDeviceVector

        MOV     r0, #IOMD_DMAChannel2_DevNo
        ADRL    r1, DMAInterruptChannel2
        SWI     XOS_ReleaseDeviceVector

        MOV     r0, #IOMD_DMAChannel3_DevNo
        ADRL    r1, DMAInterruptChannel3
        SWI     XOS_ReleaseDeviceVector

        EXIT
      ]

;---------------------------------------------------------------------------
;       Service handler.
;
ServiceTable
        DCD     0                          ; flags
        DCD     Service2 - Module_BaseAddr
        DCD     Service_Reset              ; &27
      [ HAL
        DCD     Service_PreReset           ; &45
      [ international
        DCD     Service_MessageFileClosed  ; &5E
      ]
      ]
 [ standalone
        DCD     Service_ResourceFSStarting ; &60
 ]
        DCD     Service_PagesUnsafe        ; &8E
        DCD     Service_PagesSafe          ; &8F
      [ HAL
        DCD     Service_Hardware           ; &D9
      ]
        DCD     0                          ; terminator

        DCD     ServiceTable - Module_BaseAddr
Service
        MOV     r0, r0
        TEQ     r1, #Service_Reset
      [ HAL
        TEQNE   r1, #Service_PreReset
      [ international
        TEQNE   r1, #Service_MessageFileClosed
      ]
      ]
 [ standalone
        TEQNE   r1, #Service_ResourceFSStarting
 ]
        TEQNE   r1, #Service_PagesUnsafe
        TEQNE   r1, #Service_PagesSafe
      [ HAL
        TEQNE   r1, #Service_Hardware
      ]
        MOVNE   pc, lr

Service2
        LDR     r12, [r12]

        TEQ     r1, #Service_PagesUnsafe
        BEQ     DMAPagesUnsafe
        TEQ     r1, #Service_PagesSafe
        BEQ     DMAPagesSafe
      [ HAL
        TEQ     r1, #Service_Hardware
        BEQ     ServiceDevice
      [ international
        TEQ     r1, #Service_MessageFileClosed
        BEQ     ServiceMessageFileClosed
      ]
      ]
 [ standalone
        TEQ     r1, #Service_ResourceFSStarting
        BNE     %FT10
        Entry   "r0-r3"
        ADR     r0, resourcefsfiles
        MOV     lr, pc
        MOV     pc, r2
        EXIT
10
 ]
      [ HAL
        TEQ     r1, #Service_PreReset
        BNE     %FT10
        ASSERT  (Service_PreReset :AND: 255) != 0
        STRB    r1, PreReset

        Entry   "r0-r4"
        LDR     r4, CtrlrList
        TEQ     r4, #0
        EXIT    EQ
01      LDR     r0, [r4, #ctrlr_Device]
        CallHAL Reset
        LDR     r4, [r4, #ctrlr_Next]
        TEQ     r4, #0
        BNE     %BT01
        EXIT
10
      ]

        Debug   mod,"Service_Reset"

        Entry   "r0-r2"
        MOV     r0, #&FD                        ; Read last reset type.
        MOV     r1, #0
        MOV     r2, #&FF
        SWI     XOS_Byte
        TEQ     r1, #0
        EXIT    NE                              ; Do nothing if hard reset.

        Debug   mod," soft"

      [ HAL
        BL      ShutDown
      |
        BL      FreePageTables
        BL      FreeBuffers
      ]
        BL      InitWS
      [ HAL
        BL      InitHardware
      ]
        EXIT

;---------------------------------------------------------------------------
;       Killing the module.
;
Die
        Entry

        Debug   mod,"Die"

        LDR     r12, [r12]
        CMP     r12, #0
        EXIT    EQ

        BL      ShutDown

        CLRV
        EXIT

;---------------------------------------------------------------------------
; ShutDown
;
;       Out:    preserves all registers and flags
;
;       Tidy up before dying.
;
ShutDown
        Entry   "r0"

        Debug   mod,"Shutdown"

        BL      DeregisterChannels
        BL      FreeBuffers

      [ HAL
        LDR     r4, CtrlrList
        TEQ     r4, #0
        BEQ     %FT10
01      BL      ForgetController
        MOV     r0, #ModHandReason_Free
        MOV     r2, r4
        LDR     r4, [r4, #ctrlr_Next]
        SWI     XOS_Module
        TEQ     r4, #0
        BNE     %BT01
10
        LDR     lr, NextLogicalChannel
        Push    "lr"
        ADRL    r0, NextLogicalChannelSysVar
        MOV     r1, sp
        MOV     r2, #4
        MOV     r4, #VarType_Number
        SWI     XOS_SetVarVal                   ; Save the channel number seed for later use.
        ADD     sp, sp, #4
      |
        BL      ReleaseVectors
      ]

 [ international
        LDR     r0, message_file_open           ; Close the message file if it's open.
        TEQ     r0, #0
        ADRNE   r0, message_file_block
        SWINE   XMessageTrans_CloseFile
 ]

 [ standalone
        ADR     r0, resourcefsfiles
        SWI     XResourceFS_DeregisterFiles
 ]

        SETV
        EXIT                                    ; Flags ignored by Die, V must be set for Init

;---------------------------------------------------------------------------
;       Deregister all registered logical DMA channels, purge their queues
;       and free any page tables.
;
DeregisterChannels
        Entry   "r6-r8"

        MOV     r7, #-1                         ; On DMAPurge calls do not start new transfers.
      [ HAL
        LDR     r8, ChannelList
        MOV     lr, #0
        STR     lr, ChannelList                 ; Don't allow any new transfers to be queued.
10      TEQ     r8, #0
        EXIT    EQ

        BL      DMAPurge                        ; Purge the queue of requests for this channel.

        MOV     r0, #ModHandReason_Free
        MOV     r2, r8
        LDR     r8, [r8, #lcb_Next]
        SWI     XOS_Module
        B       %BT10
      |
        MOV     r6, #NoLogicalChannels
        ADR     r8, ChannelBlock-LCBSize
10
        SUBS    r6, r6, #1                      ; If no more channels to do then
        EXIT    CC                              ;   exit.

        ADD     r8, r8, #LCBSize
        LDR     lr, [r8, #lcb_Flags]
        TST     lr, #lcbf_Registered            ; If this channel has not been registered then
        BEQ     %BT10                           ;   try next.
        MOV     lr, #0                          ; Mark channel as no longer registered.
        STR     lr, [r8, #lcb_Flags]
        BL      DMAPurge                        ; Purge the queue of requests for this channel.
        B       %BT10
      ]

;---------------------------------------------------------------------------
;       Free any page tables attached to DMA requests.
;
FreePageTables
      [ HAL
        Entry   "r0-r2,r9-r11"

        LDR     r11, CtrlrList
01
        TEQ     r11, #0
        EXIT    EQ
        LDR     r1, [r11, #ctrlr_PhysicalChannels]
        ADD     r9, r11, #ctrlr_DMAQueues - DMAQSize
10
        SUBS    r1, r1, #1
        LDRCC   r11, [r11, #ctrlr_Next]
        BCC     %BT01
      |
        Entry   "r0-r2,r9,r10"

        MOV     r1, #NoPhysicalChannels
        ADR     r9, DMAQueues-DMAQSize
10
        SUBS    r1, r1, #1
        EXIT    CC
      ]

        ADD     r9, r9, #DMAQSize
        LDR     r10, [r9, #dmaq_Head]
        TEQ     r10, #0
        BEQ     %BT10
20
        LDR     r2, [r10, #dmar_PageTable]
        TEQ     r2, #0
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
        LDR     r10, [r10, #dmar_Next]
        TEQ     r10, #0
        BNE     %BT20
        B       %BT10

;---------------------------------------------------------------------------
;       Free DMA request block buffers.
;
FreeBuffers
        Entry   "r0-r2"
        LDR     r2, DMABlockHead                ; Free all DMA request block buffers.
10
        TEQ     r2, #0
        EXIT    EQ
        LDR     r1, [r2, #block_Next]
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOV     r2, r1
        B       %BT10
        EXIT

        LTORG

        END
