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
        GET     Hdr:ImageSize.<ImageSize>
        $GetIO

        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     Hdr:HALDevice
        GET     Hdr:AudioDevice
        GET     Hdr:MixerDevice
        GET     Hdr:Proc

        GET     hdr.imx6Q
        GET     hdr.StaticWS
        GET     hdr.sgtl5000

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  Audio_Init
        EXPORT  Audio_InitDevices

        IMPORT  memcpy
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
 ]
        IMPORT  HAL_IRQClear
        IMPORT  HAL_CounterDelay

        MACRO
        CallOS  $entry
        ASSERT  $entry <= HighestOSEntry
        MOV     lr, pc
        LDR     pc, OSentries + 4*$entry
        MEND



                GBLL    AudioDebug
AudioDebug      SETL    {FALSE}

; 32KHz clock source appears to be broken - selecting it results in garbled register reads and random noise as audio output
                GBLL    Allow_32kHz_Rates
Allow_32kHz_Rates SETL  {FALSE}

IOMuxPadGPIO0 * (  (HYS_ENABLED << 16) \
                 + (PUS_47KOHM_PU << 14) \
                 + (PUE_PULL << 13) \
                 + (PKE_ENABLED << 12) \
                 + (ODE_DISABLED << 11) \
                 + (DSE_80OHM << 3) \
                 + (SRE_FAST) \
                )

IOMuxPadAUD3  * (  (HYS_ENABLED << 16) \
                 + (PUS_100KOHM_PD << 14) \
                 + (PUE_PULL << 13) \
                 + (PKE_ENABLED << 12) \
                 + (ODE_DISABLED << 11) \
                 + (SPD_100MHZ << 6) \
                 + (DSE_40OHM << 3) \
                 + (SRE_SLOW) \
                )

; For the Wandboard:
; VDDIO = 3.3V
; VDDD = 0V
; VDDA = 2.5V
CHIP_REF_CTRL_VALUE * ((18<<4) + 0xf)
CHIP_LINE_OUT_CTRL_VALUE * &0322
CHIP_LINE_OUT_VOL_TUNING * &0A ; 40*log(VDDA/VDDIO)+15
CHIP_LINE_OUT_VOL_VALUE * CHIP_LINE_OUT_VOL_TUNING*&101

CHIP_CLK_TOP_CTRL_VALUE * 0

 [ UseLineOut
CHIP_ANA_CTRL_ON * &23
 |
CHIP_ANA_CTRL_ON * &123
 ]
CHIP_ANA_CTRL_MUTE * &133

        MACRO
        SGTLRead $reg, $val, $err
        Push    "a1"
        MOV     a1, #$reg
        BL      SGTL_Read
        BNE     $err
        Pull    "$val"
        MEND

        MACRO
        SGTLWrite $reg, $val, $err
        Push    "a1"
        MOV     a1, $val
        MOVT    a1, #$reg
        BL      SGTL_Write
        BNE     $err
        MEND

SGTL_Read       ROUT
      [ AudioDebug
        Push    "lr"
        DebugReg a1, "SGTLRead:"
        Pull    "lr"
      ]
        ; In: a1 = reg, original a1 stacked
        ; Out: register value on stack & EQ cond
        ;      or a1 = IIC error, stack cleared, NE cond
        REV16   a1, a1
        Push    "a1-a4,ip,lr"
        ; Set up IIC transfer blocks on the stack
        MOV     a1, #&a*2+1
        ADD     a2, sp, #2
        MOV     a3, #2
        Push    "a1-a3"
        BIC     a1, a1, #1
        SUB     a2, a2, #2
        Push    "a1-a3"
        ; Do the transfer
        LDR     a2, BoardDetectInfo
        TST     a2, #1
        LDRNE   a2, =(AudioI2C_numD <<24)+2
        LDREQ   a2, =(AudioI2C_numBC<<24)+2
        MOV     a1, sp
        MOV     lr, pc
        LDR     pc, OSentries+4*OS_IICOpV
        ; Junk the descriptors
        ADD     sp, sp, #12*2
        ; Get the reg value
        LDRH    a2, [sp, #2]
        REV16   a2, a2
        TEQ     a1, #IICStatus_Completed
        ADD     sp, sp, #4 ; Junk register number
        LDREQ   a1, [sp, #5*4] ; Get original a1
        STREQ   a2, [sp, #5*4] ; Replace with register value
        Pull    "a2-a4,ip,lr"
        ADDNE   sp, sp, #4 ; Junk a1 if error
        MOV     pc, lr

SGTL_Write      ROUT
      [ AudioDebug
        Push    "lr"
        DebugReg a1, "SGTLWrite:"
        Pull    "lr"
      ]
        ; In: a1[16-31] = reg, a1[0-15] = value, original a1 stacked
        ; Out: EQ on success, stack cleared
        ;      or a1 = IIC error, stack cleared, NE cond
        REV     a1, a1
        Push    "a1-a4,ip,lr"
        ; Set up IIC transfer block on the stack
        MOV     a1, #&a*2
        MOV     a2, sp
        MOV     a3, #4
        Push    "a1-a3"
        ; Do the transfer
        LDR     a2, BoardDetectInfo
        TST     a2, #1
        LDRNE   a2, =(AudioI2C_numD <<24)+1
        LDREQ   a2, =(AudioI2C_numBC<<24)+1
        MOV     a1, sp
        MOV     lr, pc
        LDR     pc, OSentries+4*OS_IICOpV
        ; Junk the descriptor
        ADD     sp, sp, #12
        TEQ     a1, #IICStatus_Completed
        ADD     sp, sp, #4 ; Junk register number+value
        LDREQ   a1, [sp, #5*4] ; Get original a1
        Pull    "a2-a4,ip,lr"
        ADD     sp, sp, #4
        MOV     pc, lr

Audio_Init      ROUT
        Entry
  [ AudioDebug
        DebugTX "Audio_Init"
  ]
        ; Configure CLKO1 for 16.5MHz and output it via GPIO 0
        ; This will be the SGTL's SYS_MCLK clock
        LDR     a1, CCM_Base
        LDR     a2, [a1, #CCM_CCOSR_OFFSET]
        MOV     a3, #&fb ; CLKO1 = ahb_clk_root/8 = 132MHz/8 = 16.5MHz
        BFI     a2, a3, #0, #16
        STR     a2, [a1, #CCM_CCOSR_OFFSET]

        LDR     a1, IOMUXC_Base
        MOV     a2, #0
        STR     a2, [a1, #IOMUXC_SW_MUX_CTL_PAD_GPIO_0-IOMUXC_BASE_ADDR]
        LDR     a2, =IOMuxPadGPIO0
        STR     a2, [a1, #IOMUXC_SW_PAD_CTL_PAD_GPIO_0-IOMUXC_BASE_ADDR]

        ; SGTL should now be powered up
        ; Set up the mux settings for the AUD3 signals
        MOV     a2, #4
        STR     a2, [a1, #IOMUXC_SW_MUX_CTL_PAD_CSI0_DAT4-IOMUXC_BASE_ADDR]
        STR     a2, [a1, #IOMUXC_SW_MUX_CTL_PAD_CSI0_DAT5-IOMUXC_BASE_ADDR]
        STR     a2, [a1, #IOMUXC_SW_MUX_CTL_PAD_CSI0_DAT6-IOMUXC_BASE_ADDR]
        STR     a2, [a1, #IOMUXC_SW_MUX_CTL_PAD_CSI0_DAT7-IOMUXC_BASE_ADDR]
        LDR     a2, =IOMuxPadAUD3
        STR     a2, [a1, #IOMUXC_SW_PAD_CTL_PAD_CSI0_DAT5-IOMUXC_BASE_ADDR]
        STR     a2, [a1, #IOMUXC_SW_PAD_CTL_PAD_CSI0_DAT7-IOMUXC_BASE_ADDR]

  [ AudioDebug
        DebugTX "Audio_Init done"
  ]
        EXIT

Audio_InitDevices      ROUT
        Entry   "v1-v4"
  [ AudioDebug
        DebugTX "Audio_InitDevices"
  ]
        ; Now create the HAL devices

        ADRL    v1, AudioWS
        MOV     a1, v1
        ADR     a2, AudioTemplate
        MOV     a3, #Audio_DeviceSize
        BL      memcpy
        STR     sb, [v1, #:INDEX:AudioWorkspace]

        ADD     v2, v1, #Audio_DeviceSize
        MOV     a1, v2
        ADR     a2, MixerTemplate
        MOV     a3, #Mixer_DeviceSize
        BL      memcpy

        ; Fill in pointers to each other
        STR     v1, [v2, #HALDevice_MixerCtrlr]
        STR     v2, [v1, #HALDevice_AudioMixer]

        ; Register devices
        MOV     a2, v1
        MOV     a1, #0
        CallOS  OS_AddDevice
        MOV     a2, v2
        MOV     a1, #0
        CallOS  OS_AddDevice

  [ AudioDebug
        DebugTX "Audio_InitDevices done"
  ]
        EXIT




; Sample rate table
; The first 'reserved' byte is used to store the value that needs programming into the
; SGTL5000 CLK_CTRL register, the remaining two bytes are the value for the
; PLL_CTRL register

        GBLA    numrate
numrate SETA    0

int_rate_32000  * 0 :SHL: 2
int_rate_44100  * 1 :SHL: 2
int_rate_48000  * 2 :SHL: 2
int_rate_96000  * 3 :SHL: 2
divider_1       * 0 :SHL: 4
divider_2       * 1 :SHL: 4
divider_4       * 2 :SHL: 4
divider_6       * 3 :SHL: 4

        MACRO
$lab    audrate $int_rate, $divider
$lab    DCD     $int_rate*1024/$divider ; frequency value as reported by Sound_SampleRate
        DCB     (1000000+($int_rate/$divider)/2)/($int_rate/$divider) ; period as reported via Sound_Configure
        DCB     3 + int_rate_$int_rate + divider_$divider
      [ $int_rate = 44100
        DCW     &5794 ; (180.6336MHz/16.5MHz)*2048
      |
        DCW     &5F53 ; (196.608MHz/16.5MHz)*2048
      ]
numrate SETA    numrate+1
        MEND

;        ASSERT  HALDevice_AudioRateTableSize = 8
        ASSERT  AudioRateTableSize = 8

ratetab
      [ Allow_32kHz_Rates
        audrate 32000,4   ; 8kHz
      |
        audrate 48000,6   ; 8kHz
      ]
        audrate 44100,4   ; 11.025kHz
        audrate 48000,4   ; 12kHz
      [ Allow_32kHz_Rates
        audrate 32000,2   ; 16kHz
      |
        audrate 96000,6   ; 16kHz
      ]
        audrate 44100,2   ; 22.05kHz
        audrate 48000,2   ; 24kHz
;       audrate 96000,4)  ; 24kHz
      [ Allow_32kHz_Rates
        audrate 32000,1   ; 32kHz
      ]
        audrate 44100,1   ; 44.1kHz
        audrate 48000,1   ; 48kHz
;       audrate 96000,2   ; 48kHz
        audrate 96000,1   ; 96kHz

; Audio controller HAL device

AudioTemplate
        DCW     HALDeviceType_Audio + HALDeviceAudio_AudC
        DCW     HALDeviceID_AudC_SGTL5000
        DCD     HALDeviceBus_Ser + HALDeviceSerBus_IIC
        DCD     1:SHL:16        ; API version
        DCD     AudioDesc
        DCD     0               ; Address - N/A
        %       12              ; Reserved
        DCD     AudioActivate
        DCD     AudioDeactivate
        DCD     AudioReset
        DCD     AudioSleep
        DCD     IMX_INT_SSI2    ; Device
        DCD     0               ; TestIRQ cannot be called
        %       8
        DCD     0               ; Filled in during init
        DCD     1               ; Output channels (supported so far)
        DCD     0               ; Input channels (supported so far)
        ASSERT  (.-AudioTemplate) = HALDevice_Audio_Size
        ; DMA channel parameters
        DCD     0               ; flags
        DCD     42              ; logical channel (SSI2 TX0 DMA request)
        DCD     3               ; 'cycle speed'
        DCD     2               ; transfer unit size: 16 bit (2 byte)
        DCD     SSI2_BASE_ADDR+SSI_STX0_OFFSET ; DMA phys addr
        ; Enable/disable/IRQ routines
        DCD     PreEnable
        DCD     PostEnable
        DCD     PreDisable
        DCD     PostDisable
        DCD     IRQHandle       ; IRQHandle
        DCD     numrate         ; Number of sample rates
        DCD     ratetab         ; Sample rate table
        DCD     AudioSetRate    ; SetRate function
        ASSERT  (. - AudioTemplate) = HALDevice_Audio_Size_1
        DCD     0               ; AudioWorkspace: filled in during init
        DCD     0               ; AudioRate: filled in at runtime
        DCB     0               ; AudioEnabled
        DCB     0               ; AudioPower
        %       2               ; Spare
        ALIGN

        ASSERT  (. - AudioTemplate) = Audio_DeviceSize

; Mixer HAL device

MixerTemplate
        DCW     HALDeviceType_Audio + HALDeviceAudio_Mixer
        DCW     HALDeviceID_Mixer_TWL6040
        DCD     HALDeviceBus_Ser + HALDeviceSerBus_IIC
        DCD     1               ; API version
        DCD     MixerDesc
        DCD     0               ; Address - N/A
        %       12              ; Reserved
        DCD     MixerActivate
        DCD     MixerDeactivate
        DCD     MixerReset
        DCD     MixerSleep
        DCD     -1              ; Device
        DCD     0               ; TestIRQ cannot be called
        %       8
        DCD     0               ; Filled in during init
        DCD     MixerChannels
        DCD     MixerGetFeatures
        DCD     MixerSetMix
        DCD     MixerGetMix
        DCD     MixerGetMixLimits
        ASSERT  (.-MixerTemplate) = HALDevice_Mixer_Size + 4
        ; Default settings are for 0dB
        DCW     &3C3C           ; MixerDACVol
      [ UseLineOut
        DCW     CHIP_LINE_OUT_VOL_VALUE ; MixerLineOut
      ]
        DCW     &1818           ; MixerHP
        DCW     0               ; MixerADCDACMute
        DCW     0               ; MixerAnaMute
        ALIGN
        ASSERT  (.-MixerTemplate) = Mixer_DeviceSize

AudioDesc
        =       "SGTL5000-compatible audio controller", 0

MixerDesc
        =       "SGTL5000-compatible audio mixer", 0
        ALIGN

AudioActivate   ROUT
        Entry   "v1-v3,sb"
        LDR     sb, AudioWorkspace
      [ AudioDebug
        DebugTX "AudioActivate"
      ]
        LDR     v2, [a1, #HALDevice_AudioMixer]
        MOV     v3, a1

        ; Set up audmux. SSI running in slave mode, with internal port 2 routed to external port 3.
        LDR     a3, AudMux_Log
        LDR     a2, =(1<<31)+(2<<27)+(1<<26)+(2<<22)+(1<<11)
        STR     a2, [a3, #AUDMUX_PTCR2_OFFSET]
        LDR     a2, =(2<<13)+(0<<12)+(0<<8)
        STR     a2, [a3, #AUDMUX_PDCR2_OFFSET]
        LDR     a2, =(0<<31)+(0<<26)+(1<<11)
        STR     a2, [a3, #AUDMUX_PTCR3_OFFSET]
        LDR     a2, =(1<<13)+(0<<12)+(0<<8)
        STR     a2, [a3, #AUDMUX_PDCR3_OFFSET]

        ; Reset SSI
        BL      SSIReset

        ; Init SGTL
        ; Only do this once, doing it multiple times may cause problems
        LDRB      a2, SGTLInit
        TEQ       a2, #0
        BNE       %FT90
        ; Configure VDDD level to 1.2V
        SGTLWrite SGTL5000_CHIP_LINREG_CTRL, #8, ActivateErr
        ; Power up internal linear regular
        SGTLRead  SGTL5000_CHIP_ANA_POWER, v1, ActivateErr
        ORR       v1, v1, #SGTL5000_CHIP_ANA_POWER_LINEREG_D_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v1, ActivateErr
        ; Delay for stability
        LDR       a1, =100000
        BL        HAL_CounterDelay
        ; Disable simple power
        BIC       v1, v1, #SGTL5000_CHIP_ANA_POWER_LINREG_SIMPLE_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v1, ActivateErr
        ; Delay for stability
        LDR       a1, =100000
        BL        HAL_CounterDelay
        ; Enable more power
        ORR       v1, v1, #SGTL5000_CHIP_ANA_POWER_DAC_STEREO
        ORR       v1, v1, #SGTL5000_CHIP_ANA_POWER_ADC_STEREO + SGTL5000_CHIP_ANA_POWER_REFTOP_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v1, ActivateErr
        ; CHIP_REF_CTRL
        SGTLWrite SGTL5000_CHIP_REF_CTRL, #(CHIP_REF_CTRL_VALUE :AND: :NOT: 1), ActivateErr
        ; CHIP_LINE_OUT_CTRL
        SGTLWrite SGTL5000_CHIP_LINE_OUT_CTRL, #CHIP_LINE_OUT_CTRL_VALUE, ActivateErr
        ; Set initial volumes
        LDRH      a1, [v2, #:INDEX:MixerDACVol]
        SGTLWrite SGTL5000_CHIP_DAC_VOL, a1, ActivateErr
      [ UseLineOut
        LDRH      a1, [v2, #:INDEX:MixerLineOut]
        SGTLWrite SGTL5000_CHIP_LINE_OUT_VOL, a1, ActivateErr
      ]
        LDRH      a1, [v2, #:INDEX:MixerHP]
        SGTLWrite SGTL5000_CHIP_ANA_HP_CTRL, a1, ActivateErr
        ; Configure slow ramp up rate to minimise pop
        SGTLWrite SGTL5000_CHIP_REF_CTRL, #CHIP_REF_CTRL_VALUE, ActivateErr
        ; Enable short detect mode
        SGTLWrite SGTL5000_CHIP_SHORT_CTRL, #&1106, ActivateErr
        ; Enable zero-cross detect for HP_OUT and ADC. Keep outputs muted.
        SGTLWrite SGTL5000_CHIP_ANA_CTRL, #CHIP_ANA_CTRL_MUTE, ActivateErr
        ; Power down VAG
        SGTLRead  SGTL5000_CHIP_ANA_POWER, v1, ActivateErr
        BIC       v1, v1, #SGTL5000_CHIP_ANA_POWER_VAG_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v1, ActivateErr
        LDR       a1, =600000
        BL        HAL_CounterDelay
        ; Configure I2S
        SGTLWrite SGTL5000_CHIP_I2S_CTRL, #&1b0, ActivateErr
      [ {FALSE} ; Not using any DAP features at the moment, keep things simple and leave it disabled
        ; Set I2S->DAP->DAC route
        SGTLWrite SGTL5000_CHIP_SSS_CTRL, #&170, ActivateErr
        ; Enable DAP
        SGTLWrite SGTL5000_DAP_CTRL, #&11, ActivateErr
        ; Power up DAP
        SGTLRead  SGTL5000_CHIP_DIG_POWER, a1, ActivateErr
        ORR       a1, a1, #1<<4
        SGTLWrite SGTL5000_CHIP_DIG_POWER, a1, ActivateErr
      |
        ; Set I2S->DAC route
        SGTLWrite SGTL5000_CHIP_SSS_CTRL, #&10, ActivateErr
      ]

        ; Finished!
        MOV     a1, #1
        STRB    a1, [v3, #:INDEX:SGTLInit]
        EXIT

90
        ; Partial init. Just reset the volumes.
        LDRH      a1, [v2, #:INDEX:MixerDACVol]
        SGTLWrite SGTL5000_CHIP_DAC_VOL, a1, ActivateErr
      [ UseLineOut
        LDRH      a1, [v2, #:INDEX:MixerLineOut]
        SGTLWrite SGTL5000_CHIP_LINE_OUT_VOL, a1, ActivateErr
      ]
        LDRH      a1, [v2, #:INDEX:MixerHP]
        SGTLWrite SGTL5000_CHIP_ANA_HP_CTRL, a1, ActivateErr
        MOV       a1, #1
        EXIT

ActivateErr
        MOV     a1, #0
        EXIT

SSIReset
        Entry   "a1-a4"
        ; Reset SSI
        LDR     a1, SSI_Log+4
        LDR     a2, [a1, #SSI_SCR_OFFSET]
        BIC     a2, a2, #1
        STR     a2, [a1, #SSI_SCR_OFFSET]
        ADR     a2, ssi_reset_state
        MOV     a3, #SSI_SCR_OFFSET
10
        LDR     a4, [a2], #4
        CMP     a4, #-2
        STRLO   a4, [a1, a3]
        ADDNE   a3, a3, #4
        BNE     %BT10

        ; Configure SSI
        LDR     a2, [a1, #SSI_SCR_OFFSET]
        BIC     a2, a2, #3<<5
        ORR     a2, a2, #2<<5 ; I2S slave mode
        STR     a2, [a1, #SSI_SCR_OFFSET]
        LDR     a3, [a1, #SSI_STCR_OFFSET]
        BIC     a3, a3, #(1<<5) + (1<<6) ; External TX sync/clock signals
        STR     a3, [a1, #SSI_STCR_OFFSET]
        ORR     a2, a2, #(1<<9) + (1<<4)
        STR     a2, [a1, #SSI_SCR_OFFSET]
        ORR     a3, a3, #(1<<3) + (1<<2) + (1<<0)
        STR     a3, [a1, #SSI_STCR_OFFSET]
        LDR     a4, =(7<<13) + (1<<8)
        STR     a4, [a1, #SSI_STCCR_OFFSET]
        LDR     a4, =&00440044 ; Set FIFO watermarks to 4 words
        STR     a4, [a1, #SSI_SFCSR_OFFSET]

        ; Enable SSI
        ORR     a2, a2, #1
        STR     a2, [a1, #SSI_SCR_OFFSET]
        ORR     a3, a3, #1<<7
        STR     a3, [a1, #SSI_STCR_OFFSET]
        EXIT

ssi_reset_state
        DCD     &00000000 ; SCR
        DCD     -1        ; SISR
        DCD     &00000000 ; SIER
        DCD     &00000200 ; STCR
        DCD     &00000200 ; SRCR
        DCD     &00040000 ; STCCR
        DCD     &00040000 ; SRCCR
        DCD     &00810081 ; SFCSR
        DCD     -1        ; STR
        DCD     -1        ; SOR
        DCD     &00000000 ; SACNT
        DCD     &00000000 ; SACADD
        DCD     &00000000 ; SACDAT
        DCD     -1        ; SATAG
        DCD     &00000000 ; STMSK
        DCD     &00000000 ; SRMSK
        DCD     -1        ; SACCST
        DCD     &00000000 ; SACCEN
        DCD     &00000000 ; SACCDIS
        DCD     -2

AudioDeactivate ROUT
        Entry   "sb"
        LDR     sb, AudioWorkspace
      [ AudioDebug
        DebugTX "AudioDeactivate"
      ]
        ; Ensure powered down (assume sound already disabled)
        BL      PowerDown
        ; Disable SSI
        LDR     a1, SSI_Log+4
        MOV     a2, #0
        STR     a2, [a1, #SSI_SCR_OFFSET]
        EXIT

AudioReset
        MOV     pc, lr

AudioSleep
        MOV     a1, #0
        MOV     pc, lr

PreEnable       ROUT
        ; a2 = DMA buffer length
        Entry   "sb"
        LDR     sb, AudioWorkspace
      [ AudioDebug
        DebugTX "PreEnable"
      ]
        ; Ensure power is on
        BL      PowerUp
        ; Reset SSI. This is a convenient way of flushing any stale data from the FIFO.
        BL      SSIReset
        ; Preload FIFO with dummy data to reduce chance of underflow when we enable the audio output
        LDR     a1, SSI_Log+4
        LDR     a2, [a1, #SSI_SFCSR_OFFSET]
      [ AudioDebug
        DebugReg a2,"SFCSR="
      ]
        UBFX    a2, a2, #8, #4
        RSB     a2, a2, #15
        MOV     a3, #0
10
        SUBS    a2, a2, #1
        STRGE   a3, [a1, #SSI_STX0_OFFSET]
        BGT     %BT10
        EXIT


PostEnable      ROUT
        Entry   "v3-v4,sb"
        LDR     sb, AudioWorkspace
        MOV     v4, a1
        ; a2 = DMA buffer length
  [ AudioDebug
        DebugTX "PostEnable"
  ]
        LDR       v3, [a1, #HALDevice_AudioMixer]
        ; Reset IRQ state
        LDR       a1, SSI_Log+4
        MOV       a2, #-1
        STR       a2, [a1, #SSI_SISR_OFFSET]
        ; Enable SSI TX DMA request and FIFO underflow IRQ
        LDR       a2, [a1, #SSI_SIER_OFFSET]
        ORR       a2, a2, #(1<<20)+(1<<19) ; TX DMA enable, TX IRQ enable
        ORR       a2, a2, #1<<8 ; FIFO underflow IRQ
        STR       a2, [a1, #SSI_SIER_OFFSET]
        ; Power up desired digital blocks: DAC, I2S_IN
        SGTLRead  SGTL5000_CHIP_DIG_POWER, a2, PostEnableErr
        ORR       a2, a2, #&21
        SGTLWrite SGTL5000_CHIP_DIG_POWER, a2, PostEnableErr
        ; Unmute DAC, outputs
        LDRH      a2, [v3, #:INDEX:MixerADCDACMute]
        ORR       a2, a2, #&200
        SGTLWrite SGTL5000_CHIP_ADCDAC_CTRL, a2, PostEnableErr
        LDRH      a2, [v3, #:INDEX:MixerAnaMute]
        ORR       a2, a2, #CHIP_ANA_CTRL_ON :AND: &00FF
        ORR       a2, a2, #CHIP_ANA_CTRL_ON :AND: &FF00
        SGTLWrite SGTL5000_CHIP_ANA_CTRL, a2, PostEnableErr
        ; Enable SSI TX. Doing this after enabling the SGTL I2S interface seems
        ; to be crucial to avoid stereo going out of sync (maybe glitches when
        ; I2S enables causes SSI to send a sample?)
        LDR       a2, [a1, #SSI_SCR_OFFSET]
        ORR       a2, a2, #1<<1
        STR       a2, [a1, #SSI_SCR_OFFSET]
        ; Mark as enabled
        MOV       a1, #1
        STRB      a1, [v4, #:INDEX:AudioEnabled]
        EXIT

PostEnableErr
  [ AudioDebug
        DebugTX "PostEnableErr"
  ]
        EXIT

PreDisable      ROUT
        Entry   "sb"
        LDR     sb, AudioWorkspace
  [ AudioDebug
        DebugTX "PreDisable"
  ]
        ; Mark as disabled
        MOV     a2, #0
        STRB    a2, AudioEnabled
        ; Mute DAC, outputs
        SGTLWrite SGTL5000_CHIP_ADCDAC_CTRL, #&020c, PreDisableErr
        SGTLWrite SGTL5000_CHIP_ANA_CTRL, #CHIP_ANA_CTRL_MUTE, PreDisableErr
        ; Delay to avoid pop. 300ms seems to be about the minimum we can get away with to avoid pops when volume is at max.
        LDR       a1, =300*1000
        BL        HAL_CounterDelay
        ; Power down DAC, I2S_IN
        SGTLRead  SGTL5000_CHIP_DIG_POWER, a1, PreDisableErr
        BIC       a1, a1, #&21
        SGTLWrite SGTL5000_CHIP_DIG_POWER, a1, PreDisableErr
        ; Disable SSI TX DMA request, FIFO underflow IRQ
        LDR     a1, SSI_Log+4
        LDR     a2, [a1, #SSI_SIER_OFFSET]
        BIC     a2, a2, #(1<<20) + (1<<19)
        BIC     a2, a2, #1<<8
        STR     a2, [a1, #SSI_SIER_OFFSET]
        EXIT

PreDisableErr
  [ AudioDebug
        DebugTX "PreDisableErr"
  ]
        EXIT

PostDisable     ROUT
        Entry   "sb"
        LDR     sb, AudioWorkspace
  [ AudioDebug
        DebugTX "PostDisable"
  ]
        EXIT

AudioSetRate    ROUT
        ; a2 = sample rate index (0-based)
        Entry   "sb"
        LDR     sb, AudioWorkspace
  [ AudioDebug
        DebugReg a2, "AudioSetRate: "
  ]
        LDR     a3, [a1, #HALDevice_AudioRateTable]
;        ASSERT  HALDevice_AudioRateTableSize = 8
        ASSERT  AudioRateTableSize = 8
        LDR     a4, AudioRate
        ADD     a3, a3, a2, LSL #3
        TEQ     a3, a4
        EXIT    EQ
        STR     a3, AudioRate
        ; If power already down, nothing to do (new setting will be programmed when we re-enable power)
        LDRB    ip, AudioPower
        TEQ     ip, #0
        EXIT    EQ
        ; Check to see if the PLL rate needs changing
        LDRH    a2, [a3, #6]
        LDRH    ip, [a4, #6]
        TEQ     a2, ip
        BEQ     %FT50
        ; PLL needs changing, power down to force it to be reprogrammed when we next enable audio
        BL      PowerDown
        EXIT
50
        ; PLL doesn't need changing. Just go ahead and write the new CLK_CTRL value to select the new divisors.
        LDRB    a2, [a3, #5]
        SGTLWrite SGTL5000_CHIP_CLK_CTRL, a2, AudioSetRateErr
AudioSetRateErr
        EXIT

IRQHandle       ROUT
        Entry   "sb"
        LDR     sb, AudioWorkspace
        LDR     a1, SSI_Log+4
      [ AudioDebug
        LDR     a2, [a1, #SSI_SISR_OFFSET]
        DebugReg a2,"IRQHandle: SISR="
      ]
        ; Disable the IRQ to prevent it constantly firing (we can't guarantee
        ; that the OS is going to reset the audio)
        LDR     a2, [a1, #SSI_SIER_OFFSET]
        BIC     a2, a2, #1<<19
        STR     a2, [a1, #SSI_SIER_OFFSET]
        ; Acknowledge the IRQ
        MVN     a2, #0
        STR     a2, [a1, #SSI_SISR_OFFSET]
        ; Ask for an audio reset
        MOV     a1, #1
        EXIT

PowerUp ROUT
        ; In:
        ; a1 -> audio device
        ; sb -> HAL workspace
        ; Out:
        ; ip corrupt
        LDRB      ip, AudioPower
        TEQ       ip, #0
        MOVNE     pc, lr
        Entry     "a1-a4,v1-v2"
      [ AudioDebug
        DebugTX   "PowerUp"
      ]
        ; Configure and power up PLL & VCO amp
        LDR       v1, AudioRate
        LDRH      a2, [v1, #6]
        SGTLWrite SGTL5000_CHIP_PLL_CTRL, a2, PowerUpErr
        SGTLWrite SGTL5000_CHIP_CLK_TOP_CTRL, #CHIP_CLK_TOP_CTRL_VALUE, PowerUpErr
        SGTLRead  SGTL5000_CHIP_ANA_POWER, v2, PowerUpErr
        ORR       v2, v2, #SGTL5000_CHIP_ANA_POWER_PLL_POWERUP + SGTL5000_CHIP_ANA_POWER_VCOAMP_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v2, PowerUpErr
        LDRB      a2, [v1, #5]
        SGTLWrite SGTL5000_CHIP_CLK_CTRL, a2, PowerUpErr
        ; Power up analog blocks
        ORR       v2, v2, #SGTL5000_CHIP_ANA_POWER_LINE_OUT_POWERUP + SGTL5000_CHIP_ANA_POWER_DAC_POWERUP + SGTL5000_CHIP_ANA_POWER_HP_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v2, PowerUpErr
        ; Power up VAG
        ORR       v2, v2, #SGTL5000_CHIP_ANA_POWER_VAG_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v2, PowerUpErr
        ; Mark power as being on
        PullEnv   ; Recovers a1
        MOV       ip, #1
        STRB      ip, AudioPower
        MOV       pc, lr
PowerUpErr
        EXIT

PowerDown ROUT
        ; In:
        ; a1 -> audio device
        ; sb -> HAL workspace
        ; Out:
        ; ip corrupt
        LDRB      ip, AudioPower
        TEQ       ip, #0
        MOVEQ     pc, lr
        Entry     "a1-a4,v2"
      [ AudioDebug
        DebugTX   "PowerDown"
      ]
        ; Power down VAG
        SGTLRead  SGTL5000_CHIP_ANA_POWER, v2, PowerDownErr
        BIC       v2, v2, #SGTL5000_CHIP_ANA_POWER_VAG_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v2, PowerDownErr
        ; Wait for VAG power down. Theoretically this should only need to be a 400ms delay (due to SMALL_POP being enabled in REF_CTRL), but 650ms seems to be needed to avoid popping.
        LDR       a1, =650*1000
        BL        HAL_CounterDelay
        ; Power down analog blocks
        BIC       v2, v2, #SGTL5000_CHIP_ANA_POWER_LINE_OUT_POWERUP + SGTL5000_CHIP_ANA_POWER_DAC_POWERUP + SGTL5000_CHIP_ANA_POWER_HP_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v2, PowerDownErr
        ; Power down PLL & VCO amp
        SGTLWrite SGTL5000_CHIP_CLK_CTRL, #&08, PowerDownErr
        BIC       v2, v2, #SGTL5000_CHIP_ANA_POWER_PLL_POWERUP + SGTL5000_CHIP_ANA_POWER_VCOAMP_POWERUP
        SGTLWrite SGTL5000_CHIP_ANA_POWER, v2, PowerDownErr
        ; Mark power as being off
        PullEnv   ; Recovers a1
        MOV       ip, #0
        STRB      ip, AudioPower
        MOV       pc, lr
PowerDownErr
        EXIT

MixerActivate
        MOV     a1, #1
        ; Fall through...
MixerDeactivate
        MOV     pc, lr

MixerReset
        Entry   "a1"
        ; Program default mix params
        MOV     a2, #MixerChannel_DAC
        MOV     a3, #0
        MOV     a4, #0
        BL      MixerSetMix
      [ UseLineOut
        LDR     a1, [sp]
        MOV     a2, #MixerChannel_LineOut
        MOV     a3, #0
        MOV     a4, #0
        BL      MixerSetMix
      ]
        LDR     a1, [sp]
        MOV     a2, #MixerChannel_HP
        MOV     a3, #0
        MOV     a4, #0
        BL      MixerSetMix
        EXIT

MixerSleep
        ; TODO?
        MOV     a1, #0
        MOV     pc, lr

MixerGetFeatures
        ADR     a1, MixerFeaturesTab
        LDR     a1, [a1, a2, LSL #2]
        MOV     pc, lr

MixerFeaturesTab
        ; MixerChannel_DAC
        DCW     0
        DCW     MixerCategory_System
      [ UseLineOut
        ; MixerChannel_LineOut
        DCW     0
        DCW     MixerCategory_LineOut
      ]
        ; MixerChannel_HP
        DCW     0
        DCW     MixerCategory_Headphones

MixerGetMixLimits
        ADR     a1, MixerLimitsTab
        ADD     a1, a1, a2, LSL #3
        ADD     a1, a1, a2, LSL #2
        LDMIA   a1, {a1-a2,a4}
        STMIA   a3, {a1-a2,a4}
        MOV     pc, lr

MixerLimitsTab
        ; MixerChannel_DAC
        DCD     -90*16
        DCD     0
        DCD     8
      [ UseLineOut
        ; MixerChannel_LineOut
        DCD     -CHIP_LINE_OUT_VOL_TUNING*8
        DCD     (&1F-CHIP_LINE_OUT_VOL_TUNING)*8
        DCD     8
      ]
        ; MixerChannel_HP
        DCD     -824 ; -51.5dB
        DCD     0 ; Chip actually supports up to +12dB, but we currently limit to +0 to protect against clipping
        DCD     8

MixerSetMix     ROUT
        Entry   "v1,sb"
        LDR     v1, [a1, #HALDevice_MixerCtrlr]
        LDR     sb, [v1, #:INDEX:AudioWorkspace]
        ; a1 = mixer device
        ; a2 = channel
        ; a3 = mute flag
        ; a4 = gain, in dB*16
        CMP     a2, #MixerChannels
        ADDLO   pc, pc, a2, LSL #2
        EXIT
        B       SetMixDAC
      [ UseLineOut
        B       SetMixLineOut
      ]
        B       SetMixHP

SetMixDAC
        ; Compute DAC_VOL setting
        MOVS    a4, a4, ASR #3
        MOVGT   a4, #0
        RSB     a4, a4, #&3C
        CMP     a4, #&F0
        MOVHI   a4, #&F0
        ORR     a4, a4, a4, LSL #8
        ; Compare and program if different
        LDRH    ip, MixerDACVol
        TEQ     a4, ip
        BEQ     %FT20
        STRH    a4, MixerDACVol
        SGTLWrite SGTL5000_CHIP_DAC_VOL, a4, SetMixErr
20
        ; Now check mute
        ANDS    a3, a3, #1
        MOVNE   a3, #&c
        LDRH    ip, MixerADCDACMute
        TEQ     a3, ip
        BEQ     %FT30
        STRH    a3, MixerADCDACMute
        LDRB    ip, [v1, #:INDEX:AudioEnabled]
        TEQ     ip, #0
        BEQ     %FT30
        ORR     a3, a3, #&200
        SGTLWrite SGTL5000_CHIP_ADCDAC_CTRL, a3, SetMixErr
30
        EXIT

      [ UseLineOut
SetMixLineOut
        ; Compute LINE_OUT_VOL setting
        MOV     a4, a4, ASR #3
        ADDS    a4, a4, #CHIP_LINE_OUT_VOL_TUNING
        MOVLT   a4, #0
        CMP     a4, #&1f
        MOVHI   a4, #&1f
        ORR     a4, a4, a4, LSL #8
        ; Compare and program if different
        LDRH    ip, MixerLineOut
        TEQ     a4, ip
        BEQ     %FT40
        STRH    a4, MixerLineOut
        SGTLWrite SGTL5000_CHIP_LINE_OUT_VOL, a4, SetMixErr
40
        ; Now check mute
        LDRH    ip, MixerAnaMute
        TST     a3, #1
        BICEQ   a3, ip, #&100
        ORRNE   a3, ip, #&100
        TEQ     a3, ip
        BEQ     %FT50
        STRH    a3, MixerAnaMute
        LDRB    ip, [v1, #:INDEX:AudioEnabled]
        TEQ     ip, #0
        BEQ     %FT50
        ORR     a3, a3, #CHIP_ANA_CTRL_ON :AND: &00FF
        ORR     a3, a3, #CHIP_ANA_CTRL_ON :AND: &FF00
        SGTLWrite SGTL5000_CHIP_ANA_CTRL, a3, SetMixErr
50
SetMixErr
        EXIT
      ]

SetMixHP
        ; Compute ANA_HP_CTRL setting
        MOV     a4, a4, ASR #3
        RSBS    a4, a4, #&18
        MOVLT   a4, #0
        CMP     a4, #&7f
        MOVHI   a4, #&7f
        ORR     a4, a4, a4, LSL #8
        ; Compare and program if different
        LDRH    ip, MixerHP
        TEQ     a4, ip
        BEQ     %FT60
        STRH    a4, MixerHP
        SGTLWrite SGTL5000_CHIP_ANA_HP_CTRL, a4, SetMixErr
60
        ; Now check mute
        LDRH    ip, MixerAnaMute
        TST     a3, #1
        BICEQ   a3, ip, #&10
        ORRNE   a3, ip, #&10
        TEQ     a3, ip
        BEQ     %FT70
        STRH    a3, MixerAnaMute
        LDRB    ip, [v1, #:INDEX:AudioEnabled]
        TEQ     ip, #0
        BEQ     %FT70
        ORR     a3, a3, #CHIP_ANA_CTRL_ON :AND: &00FF
        ORR     a3, a3, #CHIP_ANA_CTRL_ON :AND: &FF00
        SGTLWrite SGTL5000_CHIP_ANA_CTRL, a3, SetMixErr
70
SetMixErr
        EXIT

MixerGetMix     ROUT
        ; a1 = mixer device
        ; a2 = channel
        CMP     a2, #MixerChannels
        ADDLO   pc, pc, a2, LSL #2
        MOV     pc, lr
        B       GetMixDAC
      [ UseLineOut
        B       GetMixLineOut
      ]
        B       GetMixHP

GetMixDAC
        ; Gain setting
        LDRB   a2, MixerDACVol ; n.b. LDRB because we only check one channel
        RSB    a2, a2, #&3C
        MOV    a2, a2, LSL #3
        ; Mute setting
        LDRH   a1, MixerADCDACMute
        ANDS   a1, a1, #&c
        MOVNE  a1, #1
        MOV    pc, lr

      [ UseLineOut
GetMixLineOut
        ; Gain setting
        LDRB   a2, MixerLineOut
        SUB    a2, a2, #CHIP_LINE_OUT_VOL_TUNING
        MOV    a2, a2, LSL #3
        ; Mute setting
        LDRH   a1, MixerAnaMute
        ANDS   a1, a1, #&100
        MOVNE  a1, #1
        MOV    pc, lr
      ]

GetMixHP
        ; Gain setting
        LDRB   a2, MixerHP
        RSB    a2, a2, #&18
        MOV    a2, a2, LSL #3
        ; Mute setting
        LDRH   a1, MixerAnaMute
        ANDS   a1, a1, #&10
        MOVNE  a1, #1
        MOV    pc, lr

        END
