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

AudioDevice_Desc
        =       "i.MX6 HDMI audio controller", 0
        ALIGN

Audio_ModInit ROUT
        ; Called on module init
        ; Set up the HAL device, but don't register it
        Entry   "r0-r2"
        ADR     r0, AudioDevice
        LDR     r1, =HALDeviceType_Audio+HALDeviceAudio_AudC
        STRH    r1, [r0, #HALDevice_Type]
        LDR     r1, =HALDeviceID_AudC_IMX6HDMI
        STRH    r1, [r0, #HALDevice_ID]
        LDR     r1, =HALDeviceBus_Sys + HALDeviceSysBus_AXI
        STR     r1, [r0, #HALDevice_Location]
        LDR     r1, =3:SHL:16 ; API 3.0
        STR     r1, [r0, #HALDevice_Version]
        ADRL    r1, AudioDevice_Desc
        STR     r1, [r0, #HALDevice_Description]
        ADRL    r1, AudioDevice_Activate
        STR     r1, [r0, #HALDevice_Activate]
        ADRL    r1, AudioDevice_Deactivate
        STR     r1, [r0, #HALDevice_Deactivate]
        ADRL    r1, AudioDevice_Reset
        STR     r1, [r0, #HALDevice_Reset]
        ADRL    r1, AudioDevice_Sleep
        STR     r1, [r0, #HALDevice_Sleep]
        LDR     r1, HALDevice
        LDR     r1, [r1, #HALDevice_VDUDeviceSpecificField]
        LDR     r1, [r1, #VDUDevSpec_HDMI_TX_INT]
        STR     r1, [r0, #HALDevice_Device]
        MOV     r1, #1
        STR     r1, [r0, #HALDevice_AudioChannelsOut]
        ADRL    r1, AudioDevice_PreDisable
        STR     r1, [r0, #HALDevice_AudioPreDisable]
        ADRL    r1, NullFunc
        STR     r1, [r0, #HALDevice_AudioPostDisable]
        ADRL    r1, Audio_IRQHandler
        STR     r1, [r0, #HALDevice_AudioIRQHandle]
        MOV     r1, #0
        STR     r1, [r0, #HALDevice_AudioNumRates]
        ADR     r1, AudioRateTable
        STR     r1, [r0, #HALDevice_AudioRateTable]
        ADRL    r1, AudioDevice_SetRate
        STR     r1, [r0, #HALDevice_AudioSetRate]
        ADRL    r1, AudioDevice_CustomDMAEnable
        STR     r1, [r0, #HALDevice_AudioCustomDMAEnable]
        MOV     r1, #AudioFlag_Synchronous
      [ :LNOT: StereoReverse
        ORR     r1, r1, #AudioFlag_StereoReverse
      ]
        STR     r1, [r0, #HALDevice_AudioFlags]
        MOV     r1, #192*4 ; 192 samples (IEC 60958 frame length) of stereo 16bit PCM (hardware only works with full IEC frames)
        STR     r1, [r0, #HALDevice_AudioMinBuffSize]
        STR     r1, [r0, #HALDevice_AudioBuffAlign]
        EXIT

Audio_ModFinal ROUT
        ; Called on module finalisation
        ; Shutdown and release memory
        Entry   "r0-r1"
        BL      Audio_Deregister
        LDR     r0, AudioBuffers+:INDEX:AudioBuffer_Log
        CMP     r0, #0
        SWINE   XPCI_RAMFree
        BL      Finalise_NEON
        EXIT

Initialise_NEON ROUT
        ; Ensure we have a VFPSupport context and that NEON is available
        ; In: sb -> workspace
        ; Out: Error on failure, else all regs preserved
        Entry   "r0-r4"
        LDR     r0, VFPSup_Context
        CMP     r0, #0
        EXIT    NE
        ; Get the FastAPI routines
        SWI     XVFPSupport_FastAPI
        STRVC   r0, VFPSup_WS
        STRVC   r4, VFPSup_ChangeCtx
        ; Create a context
        MOVVC   r0, #0
        MOVVC   r1, #3*2 ; Q0-Q2 are all we need
        MOVVC   r2, #0
        MOVVC   r3, #0
        SWIVC   XVFPSupport_CreateContext
        STRVC   r0, VFPSup_Context
        STRVS   r0, [sp]
        EXIT

Finalise_NEON ROUT
        ; Release our VFPSupport context
        ; In: sb -> workspace
        ; Out: Error on failure, else all regs preserved
        ; Sound must be off!
        Entry   "r0-r1"
        LDR     r0, VFPSup_Context
        CMP     r0, #0
        EXIT    EQ
        MOV     r1, #0
        STR     r1, VFPSup_Context ; Even if we fail, we want to forget the old context
        SWI     XVFPSupport_DestroyContext
        STRVS   r0, [sp]
        EXIT

Audio_Register ROUT
        Entry   "r0-r3,r6,r8"
        ; Work out which audio formats are supported, allocate DMA buffers and
        ; VFP context (if necessary), then register HAL device
        LDRB    r0, AudioRegistered
        CMP     r0, #0
        EXIT    NE
        LDRB    lr, HDMIEnabled
        CMP     lr, #0
        EXIT    EQ                      ; Only allow if running in HDMI mode
        LDR     r0, mPixelClock
        ADR     r2, AudioRateTable
        BL      Audio_GenRateTable
        STR     r3, AudioDevice+:INDEX:HALDevice_AudioNumRates
        STRB    r6, AudioRates
        CMP     r3, #0
        EXIT    EQ
        LDR     r0, AudioBuffers+:INDEX:AudioBuffer_Log
        CMP     r0, #0
        BNE     %FT10
        MOV     r0, #16384 ; Two 8K buffers needed
        MOV     r1, #1024 ; DMA has max burst length of 1K, optimise buffer placement for that
        MOV     r2, #0
        SWI     XPCI_RAMAlloc
        EXIT    VS
        STR     r0, AudioBuffers+:INDEX:AudioBuffer_Log
        STR     r1, AudioBuffers+:INDEX:AudioBuffer_Phys
        ADD     r0, r0, #8192
        ADD     r1, r1, #8192
        STR     r0, AudioBuffers+AudioBuffer_Size+:INDEX:AudioBuffer_Log
        STR     r1, AudioBuffers+AudioBuffer_Size+:INDEX:AudioBuffer_Phys
10
        BL      Initialise_NEON
        EXIT    VS
        ; Register HAL device
        ADR     r0, AudioDevice
        MOV     r8, #OSHW_DeviceAdd
        SWI     XOS_Hardware
        EXIT    VS
        MOV     r0, #1
        STRB    r0, AudioRegistered
        EXIT

Audio_Deregister ROUT
        ; Deregister the HAL device
        Entry   "r0,r8"
        LDRB    r0, AudioRegistered
        CMP     r0, #0
        EXIT    EQ
        ; Note that we don't need to stop playback, SoundDMA will do it for us
        ADR     r0, AudioDevice
        MOV     r8, #OSHW_DeviceRemove
        SWI     XOS_Hardware
        EXIT    VS
        MOV     r0, #0
        STRB    r0, AudioRegistered
        EXIT

Audio_PreModeChange ROUT
        ; In: r0 -> VIDC list
        ;     sb -> workspace
        ; Out: r4 = flags for PostModeChange
        Entry   "r0-r3,r6,r12"
        LDRB    r4, AudioRegistered
        CMP     r4, #0
        EXIT    EQ                      ; Do nothing if not registered
        ; Check if the new mode supports different audio rates to the current
        LDR     r0, [r0, #VIDCList3_PixelRate]
        MOV     r2, #0
        BL      Audio_GenRateTable
        LDRB    r0, AudioRates
        CMP     r0, r6
        PullEnv NE
        MOVNE   r4, #0
        BNE     Audio_Deregister        ; Rates are changing, deregister driver (then re-register in PostModeChange) - this is the easiest way of getting the OS to adapt to the new rates
        ; Rates aren't changing, but if we're currently playing audio we need to pause
        LDRB    r4, AudioOn
        CMP     r4, #0
        ADRNE   r0, AudioDevice
        BLNE    AudioDevice_PreDisable
        EXIT                            ; Exit with r4=unpause flag

Audio_PostModeChange ROUT
        ; In: r4 = flags from PreModeChange
        ;     sb -> workspace
        CMP     r4, #0
        BEQ     Audio_Register          ; If don't need to unpause, just try to register (will do nothing if already registered)
        Entry   "r0-r3,r12"
        ; Resume audio, using correct parameters for the new mode
        LDRB    r4, AudioBuffIndex
        EOR     r4, r4, #AudioBuffer_Size ; Replay the buffer we last played (to make sure we're in sync with the OS on the next sound IRQ)
        STRB    r4, AudioBuffIndex
        BL      Audio_Enable
        EXIT

        MACRO
        fmtinfo $rate, $csw_freq
        DCD     $rate     ; Sample rate in Hz
        DCB     $csw_freq ; IEC 60958-3 sampling frequency (channel status bits 24-27)
        %       3
        MEND
        
AudioFormatInfoTable
        ; Info for all frequencies supported by the iMX6
        fmtinfo  32000, 2_0011
        fmtinfo  44100, 2_0000
        fmtinfo  48000, 2_0010
        fmtinfo  88200, 2_1000
        fmtinfo  96000, 2_1010
        fmtinfo 176400, 2_1100
        fmtinfo 192000, 2_1110
        DCD     -1

BuildCSW ROUT
        Entry   "r0-r6"
        ; R0 = sample rate (Hz)
        ; R1 = channel count
        ; Find relevant CSW data
        ADR     r2, AudioFormatInfoTable
10
        LDR     lr, [r2], #8
        CMP     lr, r0
        BLO     %BT10
        EXIT    HI ; TODO return error? (this state should be impossible)
        ; Build channel status word
        LDRB    r2, [r2, #-4]
        EOR     r3, r2, #&f ; Value for the 'original sampling frequency' field can be determined just be inverting the 'sampling frequency' (assuming original freq = sampling freq)
        MOV     r2, r2, LSL #24
        MOV     r3, r3, LSL #36-32
        ORR     r2, r2, #1<<2 ; No copyright
        ORR     r2, r2, r1, LSL #16
        ORR     r3, r3, #2 ; 16bit
        ; r2, r3 is now the basic status word
        ; Use it to generate the iMX6/IEC C, P and B control bits for each
        ; channel, and write them out as a byte stream 40*channel count bytes
        ; in length
        ADR     r4, AudioCSW
        MOV     r5, #0 ; r5 = subframe index 
20
        MOV     r6, #1 ; r6 = channel index (is 1-based)
30
        ORR     r0, r2, r6, LSL #20 ; Mix in channel number
        ; Extract the current bit (based on subframe index)
        CMP     r5, #32
        MOVLO   r0, r0, LSR r5
        ANDHS   r0, r5, #31
        MOVHS   r0, r3, LSR r0
        AND     r0, r0, #1
        ; Generate the three important control bits
        MOV     r0, r0, LSL #2 ; C bit (current CSW bit)
        ORR     r0, r0, r0, LSL #1 ; P bit (parity)
        CMP     r5, #0
        ORREQ   r0, r0, #16 ; B bit (block start marker - not counted by parity bit)
        STRB    r0, [r4], #1
        ADD     r6, r6, #1
        CMP     r6, r1
        BLS     %BT30
        ADD     r5, r5, #1
        CMP     r5, #40
        BNE     %BT20
        ; Pad to multiple of 4 bytes
        MOV     r0, #0
40
        TST     r4, #3
        STRNEB  r0, [r4],#1
        BNE     %BT40
        STR     r4, AudioCSWEnd
        ; Make sure the next two words are 0 (will be used as the source for CSW bits 41-191)
        STR     r0, [r4]
        STR     r0, [r4, #4]
        EXIT

Audio_IRQHandler ROUT
        Entry   "r4,sb"
        SUB     sb, r0, #:INDEX:AudioDevice
        MRS     r4, CPSR
        LDR     r0, HDMI_Log
        ; Is it a DMA done IRQ?
        LDRB    r1, [r0, #HDMI_IH_AHBDMAAUD_STAT0-HDMI_BASE_ADDR]
        ANDS    r1, r1, #4
        BEQ     %FT90 ; Nope
        CPSID   i ; IRQs off
        ; Clear the IRQ
        STRB    r1, [r0, #HDMI_IH_AHBDMAAUD_STAT0-HDMI_BASE_ADDR]
        ; Start the next buffer - do this ASAP to reduce chance of underflow
        LDRB    r0, AudioBuffIndex
        EOR     r0, r0, #AudioBuffer_Size ; Play opposite buffer to the one we're about to fill
        BL      AudioPlayBuffer
        ; Clear the IRQ in the IRQ controller - so we can safely re-enable interrupts
        LDR     r0, AudioDevice+:INDEX:HALDevice_Device
        Push    "r8,r9"
        MOV     r8, #OSHW_CallHAL
        MOV     r9, #EntryNo_HAL_IRQClear
        SWI     XOS_Hardware
        Pull    "r8,r9"
        ; Are we meant to be playing?
        LDRB    r1, AudioOn
        BEQ     %FT90
        ; Is this a nested IRQ?
        LDRB    r0, AudioSemaphore
        CMP     r0, #0
        BNE     %FT90 ; Yes - don't tell SoundDMA (just keep playing same buffer until it catches up - matches legacy IOMD behaviour)
        STRB    r1, AudioSemaphore        
        CPSIE   i ; IRQs on
        ; Call SoundDMA to get a new buffer
        LDRB    r0, AudioBuffIndex
        ASSERT  AudioBuffer_Size = 12
        MOV     r0, r0, LSR #3 ; 0/1 buffer index
        LDR     r1, AudioCallbackParam
        MOV     lr, pc
        LDR     pc, AudioCallback ; Corrupts r0-r3, r12
        ; Convert the buffer we just filled
        LDRB    r0, AudioBuffIndex
        BL      AudioFill
        ; Flag as being ready
        CPSID   i ; IRQs off
        EOR     r0, r0, #AudioBuffer_Size
        STRB    r0, AudioBuffIndex
        ; Clear semaphore and exit
        MOV     r0, #0
        STRB    r0, AudioSemaphore
        MSR     CPSR_c, r4
        EXIT
90
        MSR     CPSR_c, r4
        MOV     r0, #0
        EXIT
         

AudioDevice_Activate ROUT
        Entry   "sb"
        SUB     sb, r0, #:INDEX:AudioDevice
        ; Flag that we're active
        MOV     r0, #1
        STRB    r0, AudioActive
        ; n.b. returning with r0=1
        EXIT

AudioDevice_Deactivate ROUT
        Entry   "sb"
        SUB     sb, r0, #:INDEX:AudioDevice
        ; Flag that we're no longer active
        MOV     r0, #0
        STRB    r0, AudioActive
        EXIT

AudioDevice_Reset ROUT
        MOV     pc, lr

AudioDevice_Sleep ROUT
        MOV     r0, #0
        MOV     pc, lr

AudioDevice_PreDisable ROUT
        Entry   "sb"
        SUB     sb, r0, #:INDEX:AudioDevice
        ; Mask the IRQ
        LDR     r3, HDMI_Log
        MOV     r1, #&ff
        STRB    r1, [r3, #HDMI_IH_MUTE_AHBDMAAUD_STAT0-HDMI_BASE_ADDR]
        ; Wait until DMA idle
10
        LDRB    r1, [r3, #HDMI_IH_AHBDMAAUD_STAT0-HDMI_BASE_ADDR]
        TST     r1, #4
        BEQ     %BT10
        ; Mute audio
        MOV     r1, #&f0
        ADD     r0, r3, #HDMI_FC_INVIDCONF-HDMI_BASE_ADDR
        STRB    r1, [r0, #HDMI_FC_AUDSCONF-HDMI_FC_INVIDCONF]
        ; Stop DMA
        MOV     r1, #1
        ADD     r0, r3, #HDMI_PHY_CONF0-HDMI_BASE_ADDR
        STRB    r1, [r0, #HDMI_AHB_DMA_STOP-HDMI_PHY_CONF0]
        ; Disable clock
        ADD     r0, r3, #HDMI_MC_SFRDIV-HDMI_BASE_ADDR
        LDRB    r1, [r0, #HDMI_MC_CLKDIS-HDMI_MC_SFRDIV]
        ORR     r1, r1, #1<<3
        STRB    r1, [r0, #HDMI_MC_CLKDIS-HDMI_MC_SFRDIV]         
        ; Flag that we're no longer playing
        MOV     r0, #0
        STRB    r0, AudioOn
        EXIT
        

AudioDevice_SetRate ROUT
        ; In: r1 = sample rate index (0-based)
        Entry   "sb"
        SUB     sb, r0, #:INDEX:AudioDevice
        LDR     r0, [r0, #HALDevice_AudioRateTable]
        ASSERT  AudioRateTableSize = 8
        ASSERT  AudioRateTable_Frequency = 0
        LDR     r0, [r0, r1, LSL #3]
        MOV     r0, r0, LSR #10
        STR     r0, AudioRate
        ; Build channel status word
        MOV     r1, #2 ; Always 2 channels
        BL      BuildCSW
        EXIT

AudioDevice_CustomDMAEnable ROUT
        ; In: R1=DMA buffer size
        ;     R2=first buffer
        ;     R3=second buffer
        ;     SP+0=callback param
        ;     SP+4=callback func
        ; Out: R0=error ptr, or 0 for OK
        MOV     ip, sp
        Entry   "sb"
        SUB     sb, r0, #:INDEX:AudioDevice
        ; Store params
        MOV     r1, r1, LSL #1
        STR     r1, AudioDestBuffSize
        STR     r2, AudioBuffers+:INDEX:AudioBuffer_Src
        STR     r3, AudioBuffers+AudioBuffer_Size+:INDEX:AudioBuffer_Src
        LDMIA   ip, {r0-r1}
        STR     r0, AudioCallbackParam
        STR     r1, AudioCallback
        ; Reset buffer index
        MOV     r0, #0
        STRB    r0, AudioBuffIndex
        ; Enable playback        
        BL      Audio_Enable
        EXIT

Audio_Enable ROUT
        Entry   "r4-r8"
        ; Work out the settings we need, and whether we can even do sound at this pixel rate
        LDR     r0, mPixelClock
        LDR     r1, AudioRate
        BL      Audio_CalcCTS
        BVS     %FT70
        ; Program the hardware
        LDR     r3, HDMI_Log
        MOV     r5, #&7f
        ADD     r0, r3, #HDMI_PHY_CONF0-HDMI_BASE_ADDR
        STRB    r5, [r0, #HDMI_AHB_DMA_MASK-HDMI_PHY_CONF0] ; Mask all except the DMA done interrupt
        MOV     r5, #&ff
        STRB    r5, [r0, #HDMI_AHB_DMA_POL-HDMI_PHY_CONF0] ; Set interrupt signal polarity
        LDRB    r5, [r0, #HDMI_AHB_DMA_CONF0-HDMI_PHY_CONF0]
        ORR     r5, r5, #128
        STRB    r5, [r0, #HDMI_AHB_DMA_CONF0-HDMI_PHY_CONF0] ; Flush FIFO
        Push    "r0-r3"
        MOV     lr, pc
        LDR     pc, DMB_Write
        MOV     r0, #2000 ; Hack - magic delay to avoid stereo channels sometimes being swapped on mode change (1ms was found to be sufficient, but using 2ms for safety)
        BL      HAL_CounterDelay
        Pull    "r0-r3"
        ; Write N
        STRB    r7, [r0, #HDMI_AUD_N1-HDMI_PHY_CONF0]
        MOV     r7, r7, LSR #8
        STRB    r7, [r0, #HDMI_AUD_N2-HDMI_PHY_CONF0]
        MOV     r7, r7, LSR #8
        STRB    r7, [r0, #HDMI_AUD_N3-HDMI_PHY_CONF0]
        ; Write CTS
        ORR     r4, r4, #1<<20
        STRB    r4, [r0, #HDMI_AUD_CTS1-HDMI_PHY_CONF0]
        MOV     r4, r4, LSR #8
        STRB    r4, [r0, #HDMI_AUD_CTS2-HDMI_PHY_CONF0]
        MOV     r4, r4, LSR #8
        STRB    r4, [r0, #HDMI_AUD_CTS3-HDMI_PHY_CONF0]
        ; Set DMA params
        MOV     r5, #1+8 ; forced burst mode (why?), INCR4, hlock enabled
        STRB    r5, [r0, #HDMI_AHB_DMA_CONF0-HDMI_PHY_CONF0]
        MOV     r5, #126
        STRB    r5, [r0, #HDMI_AHB_DMA_THRSLD-HDMI_PHY_CONF0]
        MOV     r5, #3 ; channels 0 & 1 enabled
        STRB    r5, [r0, #HDMI_AHB_DMA_CONF1-HDMI_PHY_CONF0]
        ; Set up the necessary infoFrame parameters
        ADD     r0, r3, #HDMI_FC_INVIDCONF-HDMI_BASE_ADDR
        MOV     r5, #&10 ; 2ch
        STRB    r5, [r0, #HDMI_FC_AUDICONF0-HDMI_FC_INVIDCONF]
        MOV     r5, #0
        STRB    r5, [r0, #HDMI_FC_AUDICONF1-HDMI_FC_INVIDCONF]
        STRB    r5, [r0, #HDMI_FC_AUDICONF2-HDMI_FC_INVIDCONF]
        STRB    r5, [r0, #HDMI_FC_AUDICONF3-HDMI_FC_INVIDCONF]
        ; Configure audio packet header
        MOV     r5, #0 ; Only 2ch, so packetlayout 0. All subpackets will contain data, so flat=0.
        STRB    r5, [r0, #HDMI_FC_AUDSCONF-HDMI_FC_INVIDCONF]
        ; Flag that we're running
        MOV     r5, #1
        STRB    r5, AudioOn
        ; Clear any current IRQs, and mute non-audio IRQs
        MOV     r5, #&ff
        STRB    r5, [r3, #HDMI_IH_AHBDMAAUD_STAT0-HDMI_BASE_ADDR]
        STRB    r5, [r3, #HDMI_IH_MUTE_FC_STAT0-HDMI_BASE_ADDR]
        STRB    r5, [r3, #HDMI_IH_MUTE_FC_STAT1-HDMI_BASE_ADDR]
        STRB    r5, [r3, #HDMI_IH_MUTE_FC_STAT2-HDMI_BASE_ADDR]
        STRB    r5, [r3, #HDMI_IH_MUTE_AS_STAT0-HDMI_BASE_ADDR]
        STRB    r5, [r3, #HDMI_IH_MUTE_PHY_STAT0-HDMI_BASE_ADDR]
        STRB    r5, [r3, #HDMI_IH_MUTE_I2CM_STAT0-HDMI_BASE_ADDR]
        STRB    r5, [r3, #HDMI_IH_MUTE_CEC_STAT0-HDMI_BASE_ADDR]
        STRB    r5, [r3, #HDMI_IH_MUTE_VP_STAT0-HDMI_BASE_ADDR]
        STRB    r5, [r3, #HDMI_IH_MUTE_I2CMPHY_STAT0-HDMI_BASE_ADDR]
        ; Convert the first two buffers and start playback
        LDRB    r0, AudioBuffIndex
        BL      AudioFill
        EOR     r0, r0, #AudioBuffer_Size
        BL      AudioFill
        EOR     r0, r0, #AudioBuffer_Size
        BL      AudioPlayBuffer
        ; Enable clock
        ADD     r0, r3, #HDMI_MC_SFRDIV-HDMI_BASE_ADDR
        LDRB    r1, [r0, #HDMI_MC_CLKDIS-HDMI_MC_SFRDIV]
        BIC     r1, r1, #1<<3
        STRB    r1, [r0, #HDMI_MC_CLKDIS-HDMI_MC_SFRDIV]
        ; Clear semaphore, and set r0=0 for return code
        MOV     r0, #0
        STRB    r0, AudioSemaphore
        ; Unmute 'audio done' IRQ
        MOV     r5, #&ff-4
        STRB    r5, [r3, #HDMI_IH_MUTE_AHBDMAAUD_STAT0-HDMI_BASE_ADDR]
        MOV     r5, #2
        STRB    r5, [r3, #HDMI_IH_MUTE-HDMI_BASE_ADDR]
        EXIT

70
        ADRL    r0, ErrorBlock_BadAudioMode
        BL      CopyError
        EXIT

AudioPlayBuffer ROUT
        ; R0 = buffer to play
        Entry   "r0-r2"
        ADR     r2, AudioBuffers+:INDEX:AudioBuffer_Phys
        LDR     r1, [r2, r0]
        LDR     r0, HDMI_Log
        LDR     r2, AudioDestBuffSize
        ADD     r0, r0, #HDMI_PHY_CONF0-HDMI_BASE_ADDR
        ADD     r2, r1, r2
        SUB     r2, r2, #1
        STRB    r1, [r0, #HDMI_AHB_DMA_STRADDR0-HDMI_PHY_CONF0]
        MOV     r1, r1, LSR #8
        STRB    r1, [r0, #HDMI_AHB_DMA_STRADDR1-HDMI_PHY_CONF0]
        MOV     r1, r1, LSR #8
        STRB    r1, [r0, #HDMI_AHB_DMA_STRADDR2-HDMI_PHY_CONF0]
        MOV     r1, r1, LSR #8
        STRB    r1, [r0, #HDMI_AHB_DMA_STRADDR3-HDMI_PHY_CONF0]
        STRB    r2, [r0, #HDMI_AHB_DMA_STPADDR0-HDMI_PHY_CONF0]
        MOV     r2, r2, LSR #8
        STRB    r2, [r0, #HDMI_AHB_DMA_STPADDR1-HDMI_PHY_CONF0]
        MOV     r2, r2, LSR #8
        STRB    r2, [r0, #HDMI_AHB_DMA_STPADDR2-HDMI_PHY_CONF0]
        MOV     r2, r2, LSR #8
        STRB    r2, [r0, #HDMI_AHB_DMA_STPADDR3-HDMI_PHY_CONF0]
        MOV     r1, #1
        STRB    r1, [r0, #HDMI_AHB_DMA_START-HDMI_PHY_CONF0]
        EXIT

        ARM ; Avoid UAL syntax warnings

AudioFill ROUT
        ; R0 = buffer to fill
        Entry   "r0-r6,r12"
        ; Enable our VFP context
        LDR     r12, VFPSup_WS
        LDR     r0, VFPSup_Context
        MOV     r1, #0
        MOV     lr, pc
        LDR     pc, VFPSup_ChangeCtx
        ; r0 = old context
        ; Get params needed for buffer fill
        LDRB    r6, [sp] ; Buffer index
        ADR     r1, AudioBuffers
        ADD     r6, r6, r1
        LDR     r2, [r6, #AudioBuffer_Log]
        LDR     r6, [r6, #AudioBuffer_Src]
        LDR     r1, AudioDestBuffSize
        MOV     r3, #(2*192)/4 ; Output quadwords in frame remaining
        ADR     r4, AudioCSW
        LDR     r5, AudioCSWEnd
10
        ; Note - VFP context is sized to be an exact fit for the number of registers used here
        VLDMIA      r6!, {d0}           ; Get 4 samples
        VLDMIA      r4, {s8}            ; Get 4 channel status bytes
      [ StereoReverse
        VREV32.16   d0, d0              ; Stereo reverse
      ]
        CMP         r4, r5
        VCNT.8      d2, d0              ; Start computing parity
        VSHLL.U16   q0, d0, #8          ; Expand to 32 bits per sample
        VSHLL.U8    q2, d4, #8          ; Channel status 16 bits
        VPADDL.U8   d2, d2              ; Bottom bit gives parity bit
        ADDNE       r4, r4, #4
        VSHLL.U16   q2, d4, #16         ; Channel status 32 bits
        VSHL.U16    d2, d2, #15         ; Parity in top bit
        SUBS        r3, r3, #1
        VSHLL.U16   q1, d2, #27-15      ; Expand parity to 32bit
        ADREQ       r4, AudioCSW
        VEOR        q1, q1, q0          ; Insert sample data
        MOVEQ       r3, #(2*192)/4
        VEOR        q1, q1, q2          ; Insert channel status
        SUBS        r1, r1, #16
        VSTMIA      r2!, {d2-d3}
        BNE         %BT10
        ; Restore old VFP context
        MOV     r1, #0         
        MOV     lr, pc
        LDR     pc, VFPSup_ChangeCtx
        ; Sync to ensure data is ready for DMA
        MOV     lr, pc
        LDR     pc, DMB_Write
        EXIT

        CODE32

Audio_GenRateTable ROUT
        ; In: r0 = TMDS clock (kHz)
        ;     r2 -> location to store rate table - NULL to just get mask in r6
        ; Out: r3 = count of supported formats
        ;      r6 = mask of supported rates
        Entry   "r0-r2,r4-r5,r7-r8"
        ; Ask ScreenModes which formats are supported, building up a mask in r6
        MOV     r0, #0                  ; Read in raw format (easier for us to work with)
        MOV     r1, #1                  ; Start with LPCM formats
        MOV     r2, #-1
        MOV     r6, #0
10
        SWI     XScreenModes_EnumerateAudioFormats
        MOVVS   r3, #0
        EXIT    VS
        CMP     r1, #1                  ; Only care about LPCM
        BNE     %FT20
        ; Skip entry if results look funny
        CMP     r3, #2
        BLT     %BT10
        CMP     r4, #128
        CMPLO   r5, #8
        BHS     %BT10
        ; If at least one bit depth supported, add it to the mask
        TST     r5, #7
        ORRNE   r6, r6, r4
        B       %BT10
20
        ; Now go through the mask word and check which rates are supported with
        ; this TMDS clock
        FRAMLDR r2
        MOV     r3, #0
        FRAMLDR r0
        ADR     r5, AudioDevice_FullRateTable
        MOV     r8, #1
30
        TST     r6, r8
        BEQ     %FT40
        LDR     r1, [r5, #AudioRateTable_Frequency]
        MOV     r1, r1, LSR #10         ; Get Fs in Hz
        BL      Audio_CalcCTS           ; V set if rate not possible
        BICVS   r6, r6, r8              ; Clear from mask if not supported
        BVS     %FT40
        CMP     r2, #0
        ASSERT  AudioRateTable_Frequency=0
        ASSERT  AudioRateTableSize=8
        MOVNE   r1, r1, LSL #10
        LDRNE   lr, [r5, #4]            ; Get the other word
        STMNEIA r2!, {r1, lr}
        ADDNE   r3, r3, #1
40
        MOV     r8, r8, LSL #1
        ADD     r5, r5, #AudioRateTableSize
        CMP     r8, r6
        BLS     %BT30
        EXIT


Audio_CalcCTS ROUT
        ; In: r0 = TMDS clock (kHz)
        ;     r1 = Fs (Hz)
        ; Out: r4 = CTS
        ;      r7 = N
        ;      Else V set if not possible
        Entry   "r0-r3,r6"
        ; Official way to calculate N and CTS is:
        ; N = Fs*128/X where 300 <= X <= 1500, and X ~= 1000
        ; CTS = (tmds*N)/(Fs*128)
        ; However some refactoring reveals that:
        ; CTS = tmds/X
        ; So we just need to find the value X which is closest to 1000, lies
        ; between 300 and 1500, and is a common factor of both Fs*128 and the
        ; TMDS clock.
        ; Since we specify the pixel rate (i.e. TMDS clock) in units of kHz,
        ; for audio frequencies which are a multiple of 1kHz we can go straight
        ; for X=1000. For other audio frequencies (44.1, 88.2, 176.4) we'll
        ; just use a simple brute-force approach to find X - the range of values
        ; is reasonably small, especially if we limit ourselves to known
        ; factors of Fs*128.
        MOV     r2, #1000
        ADR     r3, Audio_Factors
        MUL     r0, r2, r0 ; Get TMDS clock in Hz
;        DebugReg r0, "Desired clock "
        BL      CalcActualClock ; Get actual clock value - may not always match what was requested
        ; Round result to 1kHz - necessary when DI internal divider is in use (264MHz*16/&11 = 248470588, no valid CTS values for any audio rate). This will detune the audio slightly but I doubt anyone will notice!
        Push    "r1"
        MOV     r1, r0
        MOV     r0, #1000
        BL      udivide
        MUL     r0, r2, r0
        Pull    "r1"
;        DebugReg r0, "Actual clock "
10
        BL      Audio_TryCalcCTS
        EXIT    EQ
        LDRH    r2, [r3], #2
        CMP     r2, #0
        BNE     %BT10
        SETV
        EXIT

Audio_TryCalcCTS ROUT
        ; In: r0 = TMDS clock (Hz)
        ;     r1 = Fs (Hz)
        ;     r2 = candidate X
        ; Out: r6 corrupt
        ;      EQ: Valid CTS/N found, r4 = CTS, r7 = N
        ;      NE: Failed to find value, r4/r7 corrupt
        Entry
        ; Calculate Fs*128/X, tmds/X
        ; Test TMDS clock first (most likely one to fail)
        MOV     r6, r0
        DivRem  r4, r6, r2, lr
        CMP     r6, #0
        EXIT    NE
        MOV     r6, r1, LSL #7
        DivRem  r7, r6, r2, lr
        CMP     r6, #0
        EXIT

Audio_Factors
        ; Factors of 44100*128, 88200*128, 176400*128 which are between 300 and
        ; 1500, sorted by their distance from the ideal value of 1000
        ;
        ; PRINT "        DCW     ";
        ; FOR E%=0 TO 700
        ; FOR D%=-1 TO 1 STEP 2
        ; X%=1000+E%*D%
        ; IF X%<=1500 AND (44100*128 MOD X%=0 OR 88200*128 MOD X%=0 OR 176400*128 MOD X%=0) THEN PRINT ;X%;",";
        ; NEXT D%
        ; NEXT E%
        ; PRINT "0"
        ;
        DCW     1008,980,1024,960,1050,900,896,882,1120,1152,840,1176,800,1200,784,1225,768,1260,735,720,1280,700,672,1344,640,630,600,1400,588,576,560,1440,1470,525,512,504,490,480,450,448,441,420,400,392,384,360,350,336,320,315,300,0
        ALIGN

        MACRO
$lab    audrate $int_rate
$lab    DCD     $int_rate*1024 ; frequency value as reported by Sound_SampleRate
        DCB     (1000000+$int_rate/2)/$int_rate ; period as reported via Sound_Configure
        %       3 ; Reserved bytes not used yet
        MEND

; All LPCM audio rates supported by iMX6/HDMI
AudioDevice_FullRateTable
        audrate  32000
        audrate  44100
        audrate  48000
        audrate  88200
        audrate  96000
        audrate 176400
        audrate 192000

        END
