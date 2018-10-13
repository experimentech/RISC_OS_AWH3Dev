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
; Copyright (c) 2014, RISC OS Open Ltd
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;     * Redistributions of source code must retain the above copyright
;       notice, this list of conditions and the following disclaimer.
;     * Redistributions in binary form must reproduce the above copyright
;       notice, this list of conditions and the following disclaimer in the
;       documentation and/or other materials provided with the distribution.
;     * Neither the name of RISC OS Open Ltd nor the names of its contributors
;       may be used to endorse or promote products derived from this software
;       without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.
;

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>

        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     Hdr:HALDevice
        GET     Hdr:DMA
        GET     Hdr:DMADevice
        GET     Hdr:Proc

        GET     hdr.iMx6q
        GET     hdr.StaticWS

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        IMPORT  memcpy
        IMPORT  vtophys
        IMPORT  HAL_IRQClear
        IMPORT  dmb_st

        EXPORT  DMA_Init
        EXPORT  DMA_InitDevices

        MACRO
$class  HALDeviceField $field, $value
        LCLS    myvalue
      [ "$value" = ""
myvalue SETS    "$field"
      |
myvalue SETS    "$value"
      ]
        ASSERT  . - %A0 = HALDevice_$class$field
     [ ?HALDevice_$class$field = 2
        DCW     $myvalue
   ELIF ?HALDevice_$class$field = 4
        DCD     $myvalue
      |
        %       ?HALDevice_$class$field
      ]
        MEND

        GBLL    DMADebug
DMADebug SETL   {FALSE} :LAND: Debug

        GBLL    DMADebugIRQ
DMADebugIRQ SETL   {FALSE} :LAND: Debug
      [ DMADebug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
      ]

        GBLL    DeactivateImmediate
DeactivateImmediate SETL {FALSE} ; Whether the channel Deactivate call stops the transfer in the middle of a BD or whether it waits for the end (of the full scatter list)

; Template for DMA controller

DMACTemplate
0
        HALDeviceField Type,               HALDeviceType_SysPeri + HALDeviceSysPeri_DMAC
        HALDeviceField ID,                 HALDeviceID_DMAC_IMX6
        HALDeviceField Location,           HALDeviceBus_Sys + HALDeviceSysBus_AHB ; Guess
        HALDeviceField Version,            &10000 ; 1.0
        HALDeviceField Description,        DMAC_Description
        HALDeviceField Address,            0 ; filled in later
        HALDeviceField Reserved1,          0
        HALDeviceField Activate,           DMAC_Activate
        HALDeviceField Deactivate,         DMAC_Deactivate
        HALDeviceField Reset,              DMAC_Reset
        HALDeviceField Sleep,              DMAC_Sleep
        HALDeviceField Device,             IMX_INT_SDMA
        HALDeviceField TestIRQ,            0
        HALDeviceField ClearIRQ,           0
        HALDeviceField Reserved2,          0
DMAC    HALDeviceField Features,           DMAC_Features
DMAC    HALDeviceField Enumerate,          DMAC_Enumerate
DMAC    HALDeviceField Allocate,           DMAC_Allocate
DMAC    HALDeviceField Deallocate,         DMAC_Deallocate
DMAC    HALDeviceField TestIRQ2,           DMAC_TestIRQ2
        ASSERT  . - %A0 = HALDevice_DMAC_Size_0_1

; Template for DMA channels

DMALTemplate
0
        HALDeviceField Type,                 HALDeviceType_SysPeri + HALDeviceSysPeri_DMAL
        HALDeviceField ID,                   HALDeviceID_DMAL_IMX6
        HALDeviceField Location,             HALDeviceBus_Sys + HALDeviceSysBus_AHB ; Guess
        HALDeviceField Version,              &10000 ; 1.0
        HALDeviceField Description,          0 ; filled in later
        HALDeviceField Address,              0 ; filled in later
        HALDeviceField Reserved1,            0
        HALDeviceField Activate,             DMAL_Activate
        HALDeviceField Deactivate,           DMAL_Deactivate
        HALDeviceField Reset,                DMAL_Reset
        HALDeviceField Sleep,                DMAL_Sleep
        HALDeviceField Device,               -1 ; No per-channel IRQ
        HALDeviceField TestIRQ,              0
        HALDeviceField ClearIRQ,             0
        HALDeviceField Reserved2,            0
DMA     HALDeviceField Features,             DMAL_Features
DMA     HALDeviceField Controller,           0 ; filled in later
DMA     HALDeviceField Abort,                DMAL_Abort
DMA     HALDeviceField SetOptions,           DMAL_SetOptions
DMA     HALDeviceField SetListTransfer,      DMAL_SetListTransfer
DMA     HALDeviceField ListTransferProgress, DMAL_ListTransferProgress
DMA     HALDeviceField ListTransferStatus,   DMAL_ListTransferStatus
DMA     HALDeviceField CurtailListTransfer,  DMAL_CurtailListTransfer
        ASSERT  . - %A0 = HALDevice_DMAL_Size

DMAC_Description
        = "i.MX6 Smart DMA controller", 0

DMAL_Description
        = "i.MX6 Smart DMA channel ", 0
        ASSERT (. - DMAL_Description)+2 <= ?DMACDesc

        ALIGN

DMA_Init ROUT
        ; Allocate our NCNB workspace before the keyboard scan code takes all
        ; the free space
        ; TODO - keyboard scan could/should probably free it again afterwards
        ; Allocate memory for control blocks, channel 0 descriptor
        LDR     a1, NCNBAllocNext
        STR     a1, DMACCB
        ADD     a1, a1, #32*SDMA_CCB_SIZE
        STR     a1, DMABD0
        ADD     a1, a1, #12+32*4 ; 1 descriptor + channel context
        STR     a1, NCNBAllocNext
        MOV     pc, lr

        ; Initialise our HAL devices
DMA_InitDevices ROUT
        Entry   "v1-v5"
        LDR     v5, =&FFFFFFFE ; 32 channels total, but channel 0 reserved for managing the others
        STR     v5, DMAFreeChannels
        ; Create DMA controller device
        ADR     a1, DMAController
        ADR     a2, DMACTemplate
        MOV     a3, #HALDevice_DMAC_Size_0_1
        BL      memcpy
        LDR     v4, SDMA_Log
        STR     v4, DMAController+HALDevice_Address
        ; Register controller device
        MOV     a1, #0
        ADR     a2, DMAController
        MOV     lr, pc
        LDR     pc, OSentries+4*OS_AddDevice
        ; Create devices for each channel
        MOV     v1, #0
        ADRL    v2, DMAChannelList
        ADRL    v3, DMAChannels
10
        ; Are we allowed to use this channel?
        MOV     a1, #1
        TST     v5, a1, LSL v1
        BEQ     %FT40
      [ DMADebug
        DebugTX "Create channel"
        DebugReg v1, "num="
        DebugReg v3, "addr="
      ]
        STR     v3, [v2], #4
        MOV     a1, v3
        ADR     a2, DMALTemplate
        MOV     a3, #HALDevice_DMAL_Size
        BL      memcpy
        MOV     a1, v3
        STR     v4, [a1, #HALDevice_Address]
        ADR     a2, DMACDesc
        STR     a2, [a1, #HALDevice_Description]
        ADRL    a3, DMAL_Description
20
        LDRB    a4, [a3], #1
        CMP     a4, #0
        STRNEB  a4, [a2], #1
        BNE     %BT20
        MOV     ip, #'0'
        MOV     lr, v1
25
        CMP     lr, #10
        SUBGE   lr, lr, #10
        ADDGE   ip, ip, #1
        BGT     %BT25
        CMP     ip, #'0'
        ADD     lr, lr, #'0'
        STRNEB  ip, [a2], #1
        STRB    lr, [a2], #1
        MOV     a4, #0
        STRB    a4, [a2], #1
        STRB    v1, DMACChanNum
        MOV     a4, #1
        MOV     a4, a4, LSL v1
        STR     a4, DMACChanMask
        ADR     a2, DMAController
        STR     a2, [a1, #HALDevice_DMAController]
        STR     sb, DMACWorkspace
        MOV     a1, #0
        MOV     a2, v3
        MOV     lr, pc
        LDR     pc, OSentries+4*OS_AddDevice
40
        ADD     v1, v1, #1
        ADD     v3, v3, #DMAC_DeviceSize
        CMP     v1, #DMA_CH_Count*4
        BLT     %BT10
        ; Work out how many channels we added
        ADRL    v3, DMAChannelList
        SUB     v2, v2, v3
        MOV     v2, v2, LSR #2
        STR     v2, DMANumChannels
      [ DMADebug
        Debug TX "DMA_InitDevices done"
      ]
        EXIT

; DMA controller device
; ---------------------

DMAC_Activate
        Entry   "v1-v5,sb"
        SUB     sb, a1, #:INDEX:DMAController
      [ DMADebug
        DebugTX "DMAC_Activate"
      ]
        LDR     a3, SDMA_Log
        ; Reset SDMA
        LDR     a4, [a3, #SDMAARM_RESET]
        ORR     a4, a4, #2
        STR     a4, [a3, #SDMAARM_RESET]
        LDR     a4, [a3, #SDMAARM_RESET]
        ORR     a4, a4, #1
        STR     a4, [a3, #SDMAARM_RESET]
10
        LDR     a4, [a3, #SDMAARM_RESET]
        TST     a4, #1
        BNE     %BT10
        ; Configure
        LDR     a4, [a3, #SDMAARM_CONFIG]
        BIC     a4, a4, #16
        STR     a4, [a3, #SDMAARM_CONFIG]
        LDR     a4, [a3, #SDMAARM_CHN0ADDR]
        ORR     a4, a4, #1<<14
        STR     a4, [a3, #SDMAARM_CHN0ADDR]
        ; Clear channel enable matrix
        MOV     a4, #0
        MOV     v1, #48
        ADD     v2, a3, #SDMAARM_CHNENBL0
20
        SUBS    v1, v1, #1
        STR     a4, [v2, v1, LSL #2]
        BNE     %BT20
        ; Set channel 0 to be controlled by CPU
        MOV     a4, #0
        STR     a4, [a3, #SDMAARM_HOSTOVR]
        MOV     a4, #1
        STR     a4, [a3, #SDMAARM_EVTOVR]
        ; Set control block base address
        LDR     a1, DMACCB
        Push    "a3"
        BL      vtophys
        Pull    "a3"
        STR     a1, [a3, #SDMAARM_MC0PTR]
        ; Set interrupt mask. Enable for all but channel 0.
        LDR     a1, =&FFFFFFFE
        STR     a1, [a3, #SDMAARM_INTRMASK]
        ; Done
        MOV     a1, #1
        EXIT

DMAC_Deactivate
        ; Just do the same as on a reset...
DMAC_Reset      ROUT
        Entry   "v1-v5,sb"
        SUB     sb, a1, #:INDEX:DMAController
      [ DMADebug
        DebugTX "DMAC_Reset"
      ]
        LDR     a3, SDMA_Log
        ; Reset SDMA
        LDR     a4, [a3, #SDMAARM_RESET]
        ORR     a4, a4, #2
        STR     a4, [a3, #SDMAARM_RESET]
        LDR     a4, [a3, #SDMAARM_RESET]
        ORR     a4, a4, #1
        STR     a4, [a3, #SDMAARM_RESET]
10
        LDR     a4, [a3, #SDMAARM_RESET]
        TST     a4, #1
        BNE     %BT10
        ; Done
        EXIT

        ; TODO?
DMAC_Sleep
        MOV     a1, #0
        MOV     pc, lr

DMAC_Features
        MOV     a1, #0
        MOV     pc, lr

DMAC_Enumerate
        LDR     a2, [a1, #DMANumChannels-DMAController]
        ADD     a1, a1, #DMAChannelList-DMAController
        MOV     pc, lr

DMAC_Allocate   ROUT
        ; a2 = DMA request signal
        Entry   "sb"
        SUB     sb, a1, #:INDEX:DMAController
        MRS     a4, CPSR
        ORR     lr, a4, #I32_bit
        MSR     CPSR_c, lr
        LDR     a3, DMAFreeChannels
        CLZ     lr, a3
        RSBS    lr, lr, #31
        MOVLT   a1, #0 ; No controllers left
        BLT     %FT10
        MOV     ip, #1
        BIC     a3, a3, ip, LSL lr
        STR     a3, DMAFreeChannels
        ADRL    a1, DMAChannels
        LDR     ip, =DMAC_DeviceSize
        MLA     a1, ip, lr, a1 ; Compute device address
        STRB    a2, DMACRequestNo
10
      [ DMADebug
        DebugReg a1, "DMAC_Allocate -> "
      ]
        MSR     CPSR_c, a4
        EXIT

DMAC_Deallocate ROUT
        ; a2 = DMA request signal
        ; a3 = channel ptr
        Entry
        MRS     lr, CPSR
        ORR     a4, lr, #I32_bit
        MSR     CPSR_c, a4
        LDR     ip, [a1, #DMAFreeChannels-DMAController]!
        LDR     a4, [a3, #:INDEX:DMACChanMask]
        ORR     ip, ip, a4
        STR     ip, [a1]
        ; Clear the enable signal
        LDR     a1, [a1, #HALDevice_Address]
        ADD     a2, a1, a2, LSL #2
        LDR     ip, [a2, #SDMAARM_CHNENBL0]
        BIC     ip, ip, a4
        STR     ip, [a2, #SDMAARM_CHNENBL0]
        ; Also clear its priority level?
        LDRB    a3, [a3, #:INDEX:DMACChanNum]
        ADD     a2, a1, a3, LSL #2
        MOV     ip, #0
        STR     ip, [a2, #SDMAARM_SDMA_CHNPRI0]
        MSR     CPSR_c, lr
        EXIT

DMAC_TestIRQ2   ROUT
        Entry   "sb"
        SUB     sb, a1, #:INDEX:DMAController
      [ DMADebugIRQ
        DebugTX "DMAC_TestIRQ2"
      ]
        LDR     a3, SDMA_Log
        ; Check error register - reading clears, so we must be careful with the
        ; result
        LDR     a1, [a3, #SDMAARM_EVTERR]
      [ DMADebugIRQ
        DebugReg a1, "EVTERR="
      ]
        ; TODO store result in controller so channels can access it
        ; Fetch interrupt status word
        LDR     a1, [a3, #SDMAARM_INTR]
        ; Find an interrupting controller. Might eventually need replacing with
        ; some kind of round-robin scheme if we start making heavy use of DMA.
        CLZ     a1, a1
        RSBS    a1, a1, #31
        ; Remap indices to match the list returned by Enumerate. This means
        ; ignoring controller 0.
        SUBGE   a1, a1, #1
      [ DMADebugIRQ
        DebugReg a1,"IRQ="
      ]
        EXIT

; DMA channel device
; ------------------

DMAL_Activate   ROUT
        Entry   "sb"
        LDR     sb, DMACWorkspace
        LDR     a3, [a1, #HALDevice_Address]
        MRS     a4, CPSR
        ORR     lr, a4, #I32_bit
        MSR     CPSR_c, lr
      [ DMADebug
        DebugReg a1, "DMAL_Activate:"
      ]
        ; Set priority level, enable the DMA signal mask, and then set the
        ; HSTART bit.
        ; Valid SDMA priorities are 1-7, but we want to reserve level 7 for
        ; channel 0.
        ASSERT  DMASetOptionsMask_Speed = 7 :SHL: DMASetOptionsShift_Speed
        LDR     a2, DMACOptions
        ANDS    a2, a2, #DMASetOptionsMask_Speed
        MOVEQ   a2, #1
        MOVNE   a2, a2, LSR #DMASetOptionsShift_Speed
        TEQ     a2, #7
        MOVEQ   a2, #6
        LDRB    ip, DMACChanNum
        ADD     ip, a3, ip, LSL #2
        STR     a2, [ip, #SDMAARM_SDMA_CHNPRI0]
        ; Configure the enable signal for this channel. This must be done after
        ; setting the priority, otherwise an error IRQ will be generated
        LDRB    ip, DMACRequestNo
        LDR     a2, DMACChanMask
        ADD     ip, a3, ip, LSL #2
        ; Set the HSTART bit
        ; TODO - want to avoid setting this multiple times
        STR     a2, [a3, #SDMAARM_HSTART]
        ; ORR in the enable signal, even though we'd rarely want more than one
        ; channel to respond to a given DMA request
        LDR     lr, [ip, #SDMAARM_CHNENBL0]
        ORR     lr, lr, a2
        STR     lr, [ip, #SDMAARM_CHNENBL0]
      [ DMADebug
        DebugTX "channel running"
      ]
        MSR     CPSR_c, a4
        MOV     a1, #1
        EXIT

  [ :LNOT: DeactivateImmediate
DMAL_Deactivate ROUT
        Entry   "sb"
        LDR     sb, DMACWorkspace
        LDR     a3, [a1, #HALDevice_Address]
      [ DMADebug
        DebugReg a1, "DMAL_Deactivate:"
      ]
        LDR     a2, DMACChanMask
        ; Check STOP_STAT to determine if the channel is currently running
        LDR     ip, [a3, #SDMAARM_STOP_STAT]
        TST     ip, a2
        BEQ     %FT90
        ; Although we can pause a transfer simply by disabling the mapping of
        ; the request signal, the way the channel state is handled makes it
        ; a bit tricky to determine exactly how far through the current
        ; descriptor we were. So rather than stop immediately, we act as if
        ; CurtailListTransfer was called, forcing the transfer to stop at the
        ; end of a descriptor.
        ; TODO - Is this necessary? It's always valid for ListTransferProgress
        ; to return an underestimate, so technically all we need to do is mask
        ; the enable signals and wait for the channel to stop.
        Push    "a1-a4"
        MOV     a2, #0
        BL      DMAL_CurtailListTransfer
        Pull    "a1-a4"
        ; Wait until transfer completes
10
        LDR     ip, [a3, #SDMAARM_STOP_STAT]
        TST     ip, a2
        BNE     %BT10
90
        MRS     a4, CPSR
        ORR     lr, a4, #I32_bit
        MSR     CPSR_c, lr
        ; Clear the enable signal
        LDRB    lr, DMACRequestNo
        ADD     lr, a3, lr, LSL #2
        LDR     ip, [lr, #SDMAARM_CHNENBL0]
        BIC     ip, ip, a2
        STR     ip, [lr, #SDMAARM_CHNENBL0]
        ; Also clear its priority level?
        LDRB    lr, DMACChanNum
        ADD     lr, a3, lr, LSL #2
        MOV     ip, #0
        STR     ip, [lr, #SDMAARM_SDMA_CHNPRI0]
        MSR     CPSR_c, a4
        DMB     SY ; If this was a write to RAM, ensure CPU sees the final data
      [ DMADebug
        DebugTX "Channel halted"
      ]
        EXIT
   |
DMAL_Deactivate
        ; When deactivating immediately, we just treat Deactivate as a call to
        ; Abort
      [ DMADebug
        Entry   "sb"
        LDR     sb, DMACWorkspace
        DebugReg a1, "DMAL_Deactivate:"
        PullEnv
      ]
        ; Fall through...
   ]

DMAL_Abort      ROUT
        Entry   "v1,sb"
        LDR     sb, DMACWorkspace
        LDR     a3, [a1, #HALDevice_Address]
        MRS     a4, CPSR
        ORR     lr, a4, #I32_bit
        MSR     CPSR_c, lr
      [ DMADebug
        DebugReg a1, "DMAL_Abort:"
      ]
        LDR     a2, DMACChanMask
        ; Clear the enable signal
        LDRB    lr, DMACRequestNo
        ADD     lr, a3, lr, LSL #2
        LDR     ip, [lr, #SDMAARM_CHNENBL0]
        BIC     ip, ip, a2
        STR     ip, [lr, #SDMAARM_CHNENBL0]
        ; Also clear its priority level
        LDRB    lr, DMACChanNum
        ADD     lr, a3, lr, LSL #2
        MOV     ip, #0
        STR     ip, [lr, #SDMAARM_SDMA_CHNPRI0]
        ; The channel won't be being scheduled anymore, so we must manually
        ; clear the HE bit to bring it to a full stop
        STR     a2, [a3, #SDMAARM_STOP_STAT]
        ; Wait for scheduler to indicate that the channel is no longer running
        ; (shouldn't take long)
        ; However, if the SDMA goes to sleep because it's run out of work to do,
        ; the PSW register will stay showing the previous state. To combat this
        ; problem we issue a dummy request to channel 0 (read a word of program
        ; memory)
        LDR     a3, DMABD0
        LDR     a2, =C0_GET_PM+1+SDMA_BD_DONE
        Push    "a1-a4"
        ADD     a1, a3, #12
        BL      vtophys
        MOV     ip, a1
      [ DMADebug
        DebugTX "channel BD:"
        LDR     a3, [sp, #8]
        DebugReg a3, "@"
        LDR     a2, [sp, #4]
        DebugReg a2
        DebugReg ip
        MOV     a1, #0
        DebugReg a1
      ]
        Pull    "a1-a4"
        MOV     lr, #0
        STMIA   a3, {a2, ip, lr}
        ; Set up the control block that runs the descriptor
        LDR     a3, DMACCB
      [ DMADebug
        DebugReg a3, "CCB @"
      ]
        SUB     ip, ip, #12
        STR     ip, [a3, #SDMA_CCB_currentBDptr]
        STR     ip, [a3, #SDMA_CCB_baseBDptr]
        ; chanDesc + status never used?
      [ DMADebug
        DebugTX "Running channel 0..."
      ]
        DMB     ST ; Although DMACCB, DMABD0 and the SDMA registers are NCNB, a DMB is needed because we may be crossing into a different 'peripheral' with the SDMA register writes. PL310 sync not necessary since it won't buffer NCNB.
        MOV     v1, #7
        LDR     a3, SDMA_Log
        STR     v1, [a3, #SDMAARM_SDMA_CHNPRI0]
        MOV     v1, #1
        STR     v1, [a3, #SDMAARM_HSTART]
        ; Wait for completion
10
        LDR     v1, [a3, #SDMAARM_STOP_STAT]
        TST     v1, #1
        BNE     %BT10
      [ DMADebug
        DebugTX "done ch0"
      ]
        ; Mark channel as free again
        MOV     v1, #0
        STR     v1, [a3, #SDMAARM_SDMA_CHNPRI0]

        ; Now wait for PSW to indicate that the channel is no longer scheduled/running
        LDRB    a2, DMACChanNum
20
        LDR     ip, [a3, #SDMAARM_PSW]
      [ DMADebug
        DebugReg ip, "PSW="
      ]
        ; Check priority of current channel - zero if nothing running
        TST     ip, #&e0
        BEQ     %FT30
        ; Check current channel number
        AND     lr, ip, #&1f
        TEQ     lr, a2
        BEQ     %BT20
30
        ; Check priority of pending channel - zero if nothing scheduled
        TST     ip, #&e000
        BEQ     %FT40
        ; Check next channel number
        AND     lr, ip, #&1f00
        TEQ     lr, a2, LSL #8
        BEQ     %BT20
40
      [ DMADebug
        DebugTX "Channel aborted"
      ]
        MSR     CPSR_c, a4
        DMB     SY ; If this was a write to RAM, ensure CPU sees the final data
        EXIT

DMAL_Reset      ROUT
        ; TODO?
        MOV     pc, lr

        ; TODO?
DMAL_Sleep
        MOV     a1, #0
        MOV     pc, lr

DMAL_Features
        ADR     a1, SDMA_features
        MOV     pc, lr

numcontrolblocks    * 128

SDMA_features
        DCD     DMAFeaturesFlag_NoInitIRQ ; Features
        DCD     12 * numcontrolblocks ; BlockSize
        DCD     4 ; BlockAlign
        DCD     0 ; BlockBound
        DCD     numcontrolblocks ; MaxTransfers
        DCD     &fffc ; TransferLimit. Keep it a multiple of the max transfer width to avoid misalignment issues when transfers get split into multiple segments.
        DCD     0 ; TransferBound
        ASSERT  (. - SDMA_features) = DMAFeaturesBlockSize

DMAL_SetOptions ROUT
        ; Just remember these for later
        STR     a2, DMACOptions
        STR     a3, DMACPeriAddress
        MOV     pc, lr

DMAL_SetListTransfer ROUT
        ; TODO - need to deal with non-infinite circular transfers
        ; a1 = HAL device
        ; a2 = ARM phys addr of scatter list
        ; a3 = log addr of scatter list
        ; a4 = number of entries in scatter list
        ; [sp, #0] = byte length of xfer, or 0 for infinite
        Entry   "v1-v4,sb"
        ; scatter list is a list of (addr, len) pairs
        ; Needs expanding to a list of DMA descriptors
        ; To avoid overwriting the list as we expand it, we'll have to work backwards
        LDR     sb, DMACWorkspace
      [ DMADebug
        DebugReg a1, "DMAL_SetListTransfer:"
        Push    "a1,a4"
        DebugReg a2, "phys scatter="
        DebugReg a3, "log scatter="
        DebugReg a4, "scatter len="
        LDR     a1, [sp, #8*4]
        DebugReg a1, "xfer len="
        ; Dump out the scatter list
        DebugTX "Scatter list:"
        MOV     v1, a4, LSL #1
        MOV     v2, a3
01
        LDR     a1, [v2], #4
        DebugReg a1
        SUBS    v1, v1, #1
        BNE     %BT01
        Pull    "a1"
      ]
        ADD     a3, a3, a4, LSL #3 ; End of source scatter list
        ADD     v1, a3, a4, LSL #2 ; End of descriptor list
        ; Work out word 0 value
        LDR     ip, DMACOptions
        TST     ip, #DMASetOptionsFlag_Circular
        MOVEQ   v4, #SDMA_BD_DONE+SDMA_BD_INT
        MOVNE   v4, #SDMA_BD_DONE+SDMA_BD_INT+SDMA_BD_WRAP
        ; Transfer width is encoded in the bottom two bits of the command byte
        ; 0 -> 32 bit, 1 -> 8 bit, 2 -> 16 bit, 3 -> 24 bit
        AND     ip, ip, #3 :SHL: DMASetOptionsShift_Width
        ASSERT  DMASetOptionsShift_Width < 24
        ORR     v4, v4, ip, LSL #24-DMASetOptionsShift_Width
10
        LDMDB   a3!, {v2, v3} ; Get (addr, len) pair
        ; Convert to buffer descriptor:
        ; Word 0:
        ;   Bits 0-15 = byte len
        ;   Bit 16 = Done flag
        ;            0 -> ARM owns descriptor
        ;            1 -> SDMA owns descriptor
        ;   Bit 17 = Wrap flag
        ;   Bit 18 = Continuous flag
        ;   Bit 19 = Interrupt flag
        ;   Bit 20 = Error flag
        ;   Bit 21 = Last BD flag (unused by us)
        ;   Bits 24-31 = Command
        ; Word 1: Buffer address
        ; Word 2: Extended buffer address
        ; For all the scripts we're interested in, the buffer address gives the
        ; address of the source/dest buffer, and extended buffer address is
        ; unused
        MOV     lr, #0 ; Extended buffer address
        MOV     ip, v2 ; Buffer address
        ORR     v3, v3, v4 ; Word 0
        STMDB   v1!, {v3, ip, lr}
        ; Wrap, Continuous & Int are used to control flow
        ; First block of descriptors should have Cont & Int flag set, last
        ; descriptor should have Int and (if circular xfer) Wrap set
        ; Since we're writing the list back to front, clear wrap & set cont
        BIC     v4, v4, #SDMA_BD_WRAP
        ORR     v4, v4, #SDMA_BD_CONT
        SUBS    a4, a4, #1
        BNE     %BT10
      [ DMADebug
        ; Dump out the descriptor list
        Push    "a3,v1-v2"
        DebugTX "Descriptor list:"
        LDR     v2, [sp, #12] ; Grab original a4 (still stashed from earlier debug)
        ADD     v2, v2, v2, LSL #1 ; *3
11
        LDR     ip, [a3], #4
        DebugReg ip
        ADD     v1, v1, #4
        SUBS    v2, v2, #1
        BNE     %BT11
        Pull    "a3,v1-v2,lr" ; junk stashed a4 into lr
      ]
        ; Remember log addr of descriptors
        STR     a3, DMACDescriptors
        STR     a3, DMACLastDescriptor
        ; And clear progress value
        MOV     a3, #0
        STR     a3, DMACLastProgress
        ; Set up the control block for this channel
        LDR     a3, DMACCB
        LDRB    ip, DMACChanNum
        ASSERT  SDMA_CCB_SIZE = 16
        ADD     a3, a3, ip, LSL #4
        STR     a2, [a3, #SDMA_CCB_currentBDptr]
        STR     a2, [a3, #SDMA_CCB_baseBDptr]
        ; chanDesc + status never used?
        ; Prepare a channel context for uploading
        MRS     a4, CPSR
        ORR     lr, a4, #I32_bit
        MSR     CPSR_c, lr
        ; For all the scripts we use:
        ; r0 = event2_mask
        ; r1 = event_mask
        ; r6 = peripheral FIFO address
        ; r7 = watermark level
        LDR     a3, DMABD0
        LDR     a2, DMACPeriAddress
        STR     a2, [a3, #12+8+6*4] ; r6
        MOV     a2, #4*2 ; XXXXX need proper watermark levels. This is hardcoded for the audio FIFO.
        STR     a2, [a3, #12+8+7*4] ; r7
        ; Event masks are simply 1<<DMACRequestNo
        ; However there are 48 signals, so the mask is split over two words
        LDRB    a2, DMACRequestNo
        MOV     ip, #1
        MOV     lr, ip, LSL a2
        SUBS    a2, a2, #32
        MOVGE   a2, ip, LSL a2
        MOVLT   a2, #0
        STR     a2, [a3, #12+8+0*4] ; r0
        STR     lr, [a3, #12+8+1*4] ; r1
        ; Set up the rest of the context
        ; PC needs to be programmed to the script base address
        LDR     a2, DMACOptions
        TST     a2, #DMASetOptionsFlag_Write
        LDRNE   a2, =SDMA_ROM_mcu_2_app
        LDREQ   a2, =SDMA_ROM_app_2_mcu
        STR     a2, [a3, #12]
        ; Now set up the buffer descriptor that's used to upload the context
        LDR     a2, =C0_SETCTX+32+SDMA_BD_DONE
        LDRB    lr, DMACChanNum
        ORR     a2, a2, lr, LSL #27 ; Specify channel to program
        Push    "a1-a4"
        ADD     a1, a3, #12
        BL      vtophys
        MOV     ip, a1
      [ DMADebug
        DebugTX "channel BD:"
        LDR     a3, [sp, #8]
        DebugReg a3, "@"
        LDR     a2, [sp, #4]
        DebugReg a2
        DebugReg ip
        MOV     a1, #0
        DebugReg a1
        DebugTX "channel context:"
        ADD     a3, a3, #12
        DebugReg a3, "@"
        MOV     a1, #32
20
        LDR     a2, [a3], #4
        DebugReg a2
        SUBS    a1, a1, #1
        BNE     %BT20
      ]
        Pull    "a1-a4"
        MOV     lr, #0
        STMIA   a3, {a2, ip, lr}
        ; Set up the control block that runs the descriptor
        LDR     a3, DMACCB
      [ DMADebug
        DebugReg a3, "CCB @"
      ]
        SUB     ip, ip, #12
        STR     ip, [a3, #SDMA_CCB_currentBDptr]
        STR     ip, [a3, #SDMA_CCB_baseBDptr]
        ; chanDesc + status never used?
        ; Now run channel 0 to load up the context
      [ DMADebug
        DebugTX "Running channel 0..."
      ]
        BL      dmb_st ; Ensure all DMA descriptor writes complete
        MOV     v1, #7
        LDR     a3, SDMA_Log
        STR     v1, [a3, #SDMAARM_SDMA_CHNPRI0]
        MOV     v1, #1
        STR     v1, [a3, #SDMAARM_HSTART]
        ; Wait for completion
40
        LDR     v1, [a3, #SDMAARM_STOP_STAT]
        TST     v1, #1
        BNE     %BT40
        LDR     ip, DMACCB
      [ DMADebug
        DebugTX "done ch0"
      ]
        ; Mark channel as free again
        MOV     v1, #0
        STR     v1, [a3, #SDMAARM_SDMA_CHNPRI0]
      [ DMADebug
        DebugTX "channel primed"
      ]
        MSR     CPSR_c, a4
        EXIT

DMAL_ListTransferProgress ROUT
        ; We can't easily get accurate progress information about a transfer.
        ; Just scan the descriptors until we find the first one that's marked as
        ; DONE (i.e. first one still under SDMA control), or until we hit the
        ; end (CONT not set)
        ; Also, we use this as an opportunity to reset the DONE bits of the
        ; descriptors when dealing with circular transfers.
        Entry   "v1-v3,sb"
        LDR     sb, DMACWorkspace
      [ DMADebugIRQ
        DebugReg a1, "DMAL_ListTransferProgress:"
      ]
        ; Interrupts off, to ensure value doesn't jump forwards or backwards
        MRS     v3, CPSR
        ORR     lr, v3, #I32_bit
        MSR     CPSR_c, lr
        ; Clear the IRQ. TODO - make DMAManager use the ClearIRQ entry point
        LDR     v1, [a1, #HALDevice_Address]
        LDR     v2, DMACChanMask
        STR     v2, [v1, #SDMAARM_INTR]
        ; Also need to call HAL_IRQClear ourselves
        Push    "a1"
        MOV     a1, #IMX_INT_SDMA
        BL      HAL_IRQClear
        Pull    "a1"
        LDR     a2, DMACLastProgress
        LDR     a3, DMACLastDescriptor
        LDR     a4, DMACOptions
        ; Scan the descriptors
10
        LDR     ip, [a3]
      [ DMADebugIRQ
        DebugReg a3, "BD addr="
        DebugReg ip, "word0="
      ]
        TST     ip, #SDMA_BD_DONE
        BNE     %FT50
        ; SDMA is done with this one, add its length to our total
        MOV     lr, ip, LSL #16
        ADD     a2, a2, lr, LSR #16
        ; Reset DONE flag if this is a circular transfer
        TST     a4, #DMASetOptionsFlag_Circular
        ORRNE   ip, ip, #SDMA_BD_DONE
        STRNE   ip, [a3]
        ; Loop back to start if CONT flag not set
        ; (Note - could check WRAP here, but CONT is safer for the case of
        ; ListTransferProgress being called after a non-wrapping transfer has
        ; completed)
        TST     ip, #SDMA_BD_CONT
        LDREQ   a3, DMACDescriptors
        ADDNE   a3, a3, #12
        B       %BT10
50
        ; If this is a circular transfer, we may need to poke HSTART to make
        ; sure the channel is still running (may have stalled completely if it
        ; ran out of DONE descriptors)
        TST     a4, #DMASetOptionsFlag_Circular
        BEQ     %FT90
        BL      dmb_st ; Ensure write has completed
        ; Note that although you might think a read-write barrier is needed here, a write barrier should be fine as well - if the DMA stops after we read STOP_STAT but before our descriptor write completes, then it will still fire the usual end-of-descriptor IRQ, and we'll soon get re-entered and be allowed to restart the transfer.
        LDR     ip, [v1, #SDMAARM_STOP_STAT]
        TST     ip, v2
        STREQ   v2, [v1, #SDMAARM_HSTART]
90
        ; Store updated state
        STR     a2, DMACLastProgress
        STR     a3, DMACLastDescriptor
        MSR     CPSR_c, v3
        DMB     SY ; If this is a write to RAM, ensure CPU sees the data we're saying is there
        MOV     a1, a2
      [ DMADebugIRQ
        DebugReg a1, "->"
      ]
        EXIT

DMAL_ListTransferStatus ROUT
        ; TODO - error reporting
        MOV     a1, #0
        MOV     pc, lr

DMAL_CurtailListTransfer ROUT
        Entry   "sb"
        LDR     sb, DMACWorkspace
      [ DMADebug
        DebugReg a1, "DMAL_CurtailListTransfer:"
      ]
        ; In: a2 = minimum number of bytes that must be transferred
        ; This implementation isn't very nice. Basically we just ignore a2 and
        ; clear the Circular flag. A better implementation would be able to
        ; stop at the end of a given descriptor (pause the channel and clear
        ; the CONT flags of all descriptors?), but this implementation should
        ; be sufficient for now.
        MRS     a4, CPSR
        ORR     lr, a4, #I32_bit
        MSR     CPSR_c, lr
        LDR     ip, DMACOptions
        BIC     ip, ip, #DMASetOptionsFlag_Circular
        STR     ip, DMACOptions
        ; Work out the final transfer length
        LDR     a2, DMACLastProgress
        LDR     a3, DMACDescriptors
10
        LDR     ip, [a3], #12
        MOV     lr, ip, LSL #16
        ADD     a2, a2, lr, LSR #16
        TST     ip, #SDMA_BD_CONT
        BNE     %BT10
        MSR     CPSR_c, a4
        MOV     a1, a2
        EXIT

        LTORG

        END
