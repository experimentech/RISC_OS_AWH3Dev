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
        TTL     Sound System v3.0 -> <wini>arm.Sound0.Sound0

; *************************************************
; **                                             **
; **       ARTHUR Sound System Software          **
; **                                             **
; **    MODULE: SoundDMAHandler                  **
; **            Level0 Sound System Module       **
; **                                             **
; **    AUTHORS: David Flynn (alas, no more)     **
; **             Stuart Swales (ditto)           **
; **             Tim Dobson                      **
; **             Mark Taunton                    **
; **                                             **
; **    DESCRIPTION: all the privileged access   **
; **            to hardware/physical addresses   **
; **                                             **
; **    ENTRIES: IRQ  from Sound Buffer IRQ      **
; **             SWIs for system level interface **
; **             CLI  commands interface         **
; **                                             **
; *************************************************

; 1.05  EPROM release
; 1.06  Change help messages to add full stops
; 1.07  prevent ROM code linking to vector twice!
; 1.08  fix ROUT bug which corrupted Overrun fix
; 1.09  Service call reset IRQ problem...
; 1.10  Stereo help text fix
; 1.11  Tokenise help. SKS. Was looping freeing in death, not necessary
;       shorter exit sequences with {pc}^. Common error exits. Silly error
;       from irq claim failure. New irq scheme makes shorter + sexier
;       moved audio bug fix to proper place
;       Use spare registers in SWI handler
; 1.12  Fixed more places where IRQ could get in
; 1.13  Pass SoundLevel0Base around - a useful constant indeed!
;       Fixed RESET disabling sound problem. IRQ code neater, faster
; 1.14  Stereo can take optional '+' sign, does services
; 1.15  Had to take out overrun capability as it was much too dangerous
; ---- Released for Arthur 2.00 ----
; 1.16  Added code to cope with Fox VIDC clock speed adjustment
;       Modified header GETs so they work again
; 1.17  Internationalised
; 1.18  OSS  Added assemble time code for A500 which modifies the DMA
;            buffer for VIDC1 (rather than VIDC1a). Code courtesy of JRoach.
; 1.20  01 Mar 92  OSS  Changed to execute A500 buffer modify code in RAM to
;                       minimise the chance of overruns.
; 1.21  07-Aug-92  TMD  Re-added MEMC2 option
; 1.22  27-Aug-92  TMD  Put in VIDC20 option
; 1.23  16-Feb-93  TMD  Corrected for rotation of stereo image registers on VIDC20
; 1.24  25-May-93  MT   Added IOMD support; also conditionals (defined in xxHdr
;                       file) to handle loudspeaker on/off control (SpkControl)
;                       and sound clock frequency variation with video mode
;                       (VarSndClock). Older machines have both: Medusa has
;                       neither.
; 1.25  02-Jul-93  MT   Sound0Hack flag (defined in JordanHdr) now
;                       checked when assembling IOMD version, to avoid
;                       use of OS_Memory (not yet available), and
;                       OS_ClaimDeviceVector with IOMD DMA channels as
;                       devices (since that is also not yet ready).
;                       We use privileged knowledge about kernel's
;                       memory addressing variables to circumvent the
;                       first problem, and IrqV instead of the real
;                       IRQ vector, for the second.
; 1.26  09-Jul-93  TMD  Fix stack imbalance in unknown IRQ code.
; 1.27  15-Jul-93  JSR  Switch to new headers system.
; 1.28  06-Aug-93  MT   Fix bug in IOMD code where overrun (e.g. when
;                       interrupts were disabled for more than a
;                       buffer time) caused system lockup because of
;                       failure to program the correct buffer.
; 1.29  06-Aug-93  MT   No software change - merely getting version number
;                       right here.
; 1.30  11-Aug-93  MT   Fix handling of service call (bug MED-00362)
; 1.31  11-Aug-93  MT   Add the above line and this one, forgotten before (no
;                       code change).
; 1.32  26-Aug-93  OL   Libra mods: International_Help bit set for *audio,
;                       *speaker, *stereo. (These log lines added by MT.)
; 1.33  02-Sep-93  MT   Turned off Sound0Hack (no longer needed, but left in
;                       source for now); fixed stack imbalance bug in code for
;                       exit on XOS_Memory failure; added log entry for 1.32.
; 1.34  05-Oct-93  MT   Corrected flags to XOS_Memory, to fix bug MED-00621.
; 1.35  11-Nov-93  JSR  Fix MED-00820 - fix international help for *Stereo command.
;                       Install, but leave disabled, sound quenching code to quieten
;                       the quiet bits.
; 1.36  14-Feb-94  TMD  Fix MED-02859 - don't call InitResetCommon on Service_Reset
;                       unless it's a soft reset.
; 1.37  30-Jun-94  MT   Removed Sound0Hack, no longer needed, and JSR's sound quenching
;                       code - newer hardware fixes this `properly'.  Major surgery
;                       throughout, to support 16-bit output (set up by CMOS config).
; 1.38  12-Jul-94  MT   Fix problem with Sound_SampleRate setting new rate without VIDC
;                       programming offset of 2.  Also cure duff error on bad param.
; 1.40  18-Oct-94  RCM  Add power saving calls for Stork see 'StorkPower'.
; 1.41  21-Oct-94  SMC  Fixed bug in level0 fill where code could ask for more than would
;                       be played.
;                       Fixed MIN-00087 - Sound_Configure code allowed buffer size to be set
;                       too large for 16bit sound. Also WorkOutVIDCParams called process_oversample
;                       which used the OLD buffer size to determine whether to oversample rather than
;                       the new one given in the SWI call.
;                       Fixed MIN-00022 - Added *Configure SoundSystem for 8bit/16bit sound.
;
; ********************  See SrcFiler log file for changes since version 1.41.
;
; 1.53 14-Apr-97  MT    Merge in changes for StrongARM compatibility, mono output and
;                       oversampling performance improvement.  Change default sample rate
;                       to 22.05Khz, if hardware support is available for this (STB/NC).
; 1.54 22-Apr-97  MT    Fix to allow mono output to be controlled (Sound_Mode 3) - although
;                       the implementation was present, the code to recognise and act on
;                       the specific SWI function code had been omitted by accident in the
;                       code merge.
; 1.59 22-Feb-01  SBF   Obsolete STB flag removed; default frequency of 20.8333kHz used in all cases
;

              GBLL    StrongARM
StrongARM     SETL    {TRUE}

        GET     Hdr:ListOpts
        OPT     OptNoList
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        $GetVIDC
        $GetMEMM
        $GetIO
        GET     Hdr:CMOS
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:PublicWS
        GET     Hdr:Tokens
        GET     Hdr:DevNos
        GET     Hdr:Proc
        GET     Hdr:VduExt
        GET     Hdr:MsgTrans
        GET     Hdr:HostFS
        GET     Hdr:DDVMacros
        GET     Hdr:NDRDebug
        GET     Hdr:HALEntries
        GET     Hdr:DMA
        GET     Hdr:CPU.Arch
        GET     Hdr:RTSupport

        OPT     OptList
        OPT     OptPage

        GET     Hdr:Sound
        GET     Hdr:Portable
        GET     Hdr:PCI

        GET     Version
        GET     VersionASM

        GET     Hdr:HALDevice
        GET     Hdr:AudioDevice
        GET     Hdr:MixerDevice
        GET     Hdr:SoundCtrl

; On IOMD-based systems, to support sound DMA "cheaply" in terms of
; software complexity, we must have physical sound buffers no bigger
; than the maximum DMA buffer IOMD supports (i.e. number of bytes
; transferred per DMA interrupt).  This is 4Kbytes: the size of a page
; on ARM{6,7}00 machines.  In addition, for each sound DMA buffer,
; either it must all lie within a single physical page, or else the
; pages which contain it must be physically contiguous.  We could
; survive any combination of values for SoundDMABufferSize and
; SoundDMABuffers which satisfied both these conditions. However it is
; simpler here (e.g. no need for physical contiguity check) just to
; use the tighter condition that the SoundDMABufferSize is *exactly*
; 4096 and that the base address of the sound buffers is on a 4096
; byte boundary. This was true for the original values as used on
; MEMC1 systems, and is unlikely to need to change. Therefore this
; tighter restriction is OK.

    [ SoundDMABufferSize /= 4096
        ! 1, "SoundDMABufferSize must be exactly 4096 for Sound0 on IOMD"
    ]
    [ SoundDMABuffers :MOD: 4096 /= 0
        ! 1, "SoundDMABuffers must be 4096-byte-aligned for Sound0 on IOMD"
    ]

; In addition, for yet more simplification, and minimum code change to
; support IOMD, we assume here that the two 4Kb sound buffer pages are
; physically contiguous (in the right order!), so that we can continue
; to use only one word [Level0Base,#Phys0] to hold the base address.
; This assumption cannot currently (21-May-93) be tested at assembly
; time.

        GBLL    debug
debug           SETL    {FALSE}

        GBLL    hostvdu
hostvdu         SETL    {TRUE}

swi     SETD    {FALSE}
devlist SETD    {FALSE}

; Timing code uses a HAL timer to measure time spent in various bits of buffer
; fill code. Use *SoundTiming to see the results (and to reset the counters)
        GBLL    TimingCode
TimingCode      SETL    {FALSE}

 [ TimingCode
TimingTimer     * 1 ; Which HAL timer to use
 ]   

;

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Level0 data structure

; Sound0Segment:  Sound DMA Control Block
;
; Total of 16 words available.  First 9 must NOT be reordered without also
; fixing static copy (ProtoS0S) and init code, since an LDM/STM pair is used
; with specific registers known to match particular fields
          ^ 0
Semaphore # 4   ; 0 = sound enabled, &80000000 = sound disabled
Phys1     # 4   ; physical address of buffer 1
Buff0     # 4   ; logical page addresses...
Buff1     # 4
Config    # 0
BuffLen   # 2   ; 16-bit Buffer Length (in samples)
Period    # 1   ; 8-bit SFG period
NChannels # 0   ; Log channels (3 bit) AND sundry flags
Flags     # 1   ; Name for flags byte
Level1Ptr # 4
Images    # 8   ; (8) byte image positions, full 8-bit resolution of user value (-127..127)
Level2Ptr # 4   ; scheduler

; End of order-critical section. From here on, items are initialised
; dynamically and one item at a time, hence order is not significant.

; Code to handle stereo 16-bit linear emulation of N-channel mu-law needs to
; keep track of how many channels are in use.
Log2nchan_C # 1 ; Log2(currently active channel count), as compiled into 16-bit conv code

Spare0    # 3

ImagesC_N # 4   ; compacted (new) version of Images, for prog'ing conv. routine
ImagesC_H # 4   ; value which IRQ code will load into conv. routine on next irq
ImagesC_C # 4   ; softcopy of value currently programmed into conv. routine
SoundRMA  # 4   ; pointer to remaining data/dynamic code items held in RMA
SoundGain # 1   ; value of additional gain (0..7) -> +0 .. 21dB in 3dB steps, for mu-law
SoundGain_C # 1 ; value of additional gain as currently compiled into conv code

; Currently 2 bytes free

        ASSERT  @ <= SoundLevel0Reserved

; Constants
; SC prefix for SoundConstant
SCPeriod     * 45                       ; default, i.e. 22050 Hz

SCBufferLen  * 224                      ; 224 bytes/channel (&E0: multiple of 16)
SCLogChannel * 0                        ; default log2nchan = 0 -> 1 channel
SCSoundGain  * 0                        ; default soundgain is 0

; Flags bits in NChannels/Flags byte: bottom 2 bits are log2nchan, top bit for
; handler call "Level0 updated" flag, remaining bits are free for general flags
 [ SupportSoftMix
DoSoftMix       *       &40             ; software mixer (volume control) flag
 ]
DoReverse       *       &20             ; stereo reverse bit
DoMono          *       &10             ; mono-isation control bit
DoOversample    *       &08             ; oversampling active bit
OversampleFlag  *       &04             ; AutoOversampling flag from CMOS

 [ SupportSoftMix
DoFlags         * DoMono+DoOversample+DoReverse+DoSoftMix
 |
DoFlags         * DoMono+DoOversample+DoReverse
 ]

; Definition of cut-off point for oversampling
MinOSPeriod     *       42              ; do not oversample if period < 42 (f > 24kHz)

; Level0 constants

; Physical address of sound DMA buffers is not fixed on HAL systems, but
; needs to be determined at initialisation time.


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        SUBT    Sound DMA Module Header
        OPT     OptPage

        AREA    |Sound0$$Code|, CODE, READONLY, PIC

Module_Base
        DCD     0                    ; NOT AN APPLICATION
        DCD     Initialise_Module    - Module_Base
        DCD     Finalise_Module      - Module_Base
        DCD     Intercept_Services   - Module_Base
        DCD     Module_Name          - Module_Base
        DCD     Help_String          - Module_Base
        DCD     Module_Keywords      - Module_Base
        DCD     Module_SWISystemBase + Sound0SWI * Module_SWIChunkSize
        DCD     Sound_SWI_Code       - Module_Base
        DCD     Module_SWIDecodeBase - Module_Base
        DCD     0                    ; No decoding code.
 [ International_Help <> 0
        DCD     message_filename     - Module_Base
 |
        DCD     0
 ]
 [ :LNOT: No32bitCode
        DCD     Module_Flags         - Module_Base
 ]

Module_Name
        DCB     "SoundDMA", 0

Help_String
        DCB     "SoundDMA"
        DCB     9
        DCB     "$Module_MajorVersion ($Module_Date)"
 [ Module_MinorVersion <> ""
        DCB     " $Module_MinorVersion"
 ]
        DCB     " HAL version"
        DCB     0

Module_SWIDecodeBase
        DCB     "Sound",0
        DCB     "Configure",0
        DCB     "Enable",0
        DCB     "Stereo",0
        DCB     "Speaker",0
        DCB     "Mode",0
        DCB     "LinearHandler",0
        DCB     "SampleRate",0
        DCB     "ReadSysInfo",0
        DCB     "SelectDefaultController",0
        DCB     "EnumerateControllers",0
        DCB     "ControllerInfo",0
        DCB     0

Module_Keywords

        DCB     "Audio", 0
        ALIGN
        DCD     Audio_Code   - Module_Base
        DCB     1, 0, 1, 0:OR:(International_Help:SHR:24)   ; all flags clear, and one parameter ONLY
        DCD     Audio_Syntax - Module_Base
        DCD     Audio_Help   - Module_Base

        DCB     "Speaker", 0
        ALIGN
        DCD     Speaker_Code   - Module_Base
        DCB     1, 0, 1, 0:OR:(International_Help:SHR:24)   ; all flags clear, and one parameter ONLY
        DCD     Speaker_Syntax - Module_Base
        DCD     Speaker_Help   - Module_Base

        DCB     "Stereo", 0
        ALIGN
        DCD     Stereo_Code   - Module_Base
        DCB     2, 0, 2, 0:OR:(International_Help:SHR:24)   ; all flags clear, two parameters ONLY
        DCD     Stereo_Syntax - Module_Base
        DCD     Stereo_Help   - Module_Base

        DCB     "SoundGain", 0
        ALIGN
        DCD     SoundGain_Code   - Module_Base
        DCB     1, 0, 1, 0:OR:(International_Help:SHR:24)
        DCD     SoundGain_Syntax - Module_Base
        DCD     SoundGain_Help   - Module_Base

        DCB     "SoundSystem", 0
        ALIGN
        DCD     SoundSystem_Code   - Module_Base
        DCB     1, 0, 2, 0:OR:(International_Help:SHR:24):OR:(Status_Keyword_Flag:SHR:24)
        DCD     SoundSystem_Syntax - Module_Base
        DCD     SoundSystem_Help   - Module_Base

      [ TimingCode
        DCB     "SoundTiming", 0
        ALIGN
        DCD     SoundTiming_Code   - Module_Base
        DCB     0, 0, 0, 0
        DCD     0
        DCD     0
      ]

        DCB     0            ; no more entries.

        GET     TokHelpSrc.s

        ALIGN

 [ :LNOT: No32bitCode
Module_Flags
        DCD     ModuleFlag_32bit
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 [ UseNEON
        GET     Sound0NEON.s
 |
        GET     Sound0ARM.s
 ]

; Define RMA sound workspace now we know how big the A500 or mu-law-to-linear code is.

        ^       0

MessageFile_Block # 16
MessageFile_Open  #  4

; 16-bit linear support data
HALSRIndex        #  4                  ; Softcopy of sample rate index programmed in HAL device
HALBuffLen        #  2                  ; Softcopy of BuffLen programmed in HAL device, *2 if oversampling
UserOSFlag        #  1                  ; see UpdateHALParams 
ResetPending      #  1                  ; Flag for whether HAL-requested audio reset is pending
ReenableFlag      #  1                  ; Whether we're going to attempt to automatically reenable sound if a required service restarts
                  #  3
SavedSample       #  4                  ; Preserved stereo value from end of last buffer, for
                                        ; 2:1 linear interpolation (if configured).
Lin16GenR0        #  4                  ; Value to be passed in R0 to ...
Lin16Gen          #  4                  ; User-supplied 16-bit sound generator(/mixer) code
CurSRValue        #  4                  ; Current sample frequency in 1/1024 Hz units
CurSRIndex        #  4                  ; index into set of available frequencies
CurSRIndex_OS     #  4                  ; index after taking into account oversampling
 [ UseNEON
VFPSup_Context    #  4                  ; VFP context pointer
VFPSup_ChangeCtx  #  4                  ; VFPSupport context change function ptr
VFPSup_WS         #  4                  ; Context change function WS ptr
NEON_Q0_Q1        #  32                 ; R & L channel scale factors
 |
LinConvCode       #  MAXLinConvCodeSize ; Space for the dynamically-compiled mu-law to
                                        ; 16-bit-linear conversion code
 ]
 [ SupportSoftMix
SoftMixAmount     #  4                  ; Current software mix level (as volume multiplier for buffer fill code)
 ]
Sound_device      #  4                  ; IRQ number
HALDevice         #  4                  ; Pointer to current HAL audio controller device
DMAChannel        #  4                  ; DMA channel handle. 0 if device doesn't use DMAManager
DMATag            #  4                  ; DMA tag
DMARoutines       #  20                 ; Pointers to DMA routines
DMAScatter        #  16                 ; DMA scatter list

RTSup_Pollword    #  4                  ; RTSupport pollword
RTSup_Handle      #  4                  ; Our handle with RTSupport
DeviceList        #  4                  ; All detected (+ supported) HAL devices

 [ TimingCode
TimeGran          #  4                  ; Granularity, for display
TimeFunc          #  4                  ; HAL_Timer_ReadCountdown
TimeWS            #  4
TimeMaxPeriod     #  4                  ; Max period of timer
TimeTotal         #  4                  ; Total accumulated time
TimeLevel2        #  4                  ; Time spent in level 2 code
TimeNuke          #  4                  ; Time spent nuking old buffer
TimeLevel1        #  4                  ; Time spent in level 1 code
TimeMuLaw         #  4                  ; Time spent in mu-law to linear
TimeLinear        #  4                  ; Time spent in linear handler
TimeMonoOversample # 4                  ; Time spent in mono/oversample code
TimeTemp0         #  4
TimeTemp1         #  4
 ]

WorkSpaceSize     * @

                         ^ 0
DeviceList_Next          # 4
DeviceList_AudioDevice   # 4
 [ SupportSoftMix
DeviceList_SoftMixDevice # 4
 ]
DeviceList_ID            # 0            ; ID string for device - is last member of struct

  [ TimingCode
        ; Get current time into r0
        ; SoundRMA in $ws
        ; Corrupts r0-r3,r9,r12,lr
        MACRO
        GetTime   $ws
        ASSERT    $ws <> 12
        ASSERT    $ws <> 0
        LDR       r9,[$ws,#TimeWS]
        MOV       r0,#TimingTimer
        MOV       lr,pc
        LDR       pc,[$ws,#TimeFunc]
        MEND
  ]

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

Audio_Code Entry

        LDR     r12, [r12]
        BL      DeviceList_FindByID
        CMP     r3, #0
        BEQ     %FT10
        SWI     XSound_SelectDefaultController
        EXIT
10
        BL      DecodeOnOrOff
        SWI     XSound_Enable
        EXIT

; .............................................................................

Speaker_Code ALTENTRY

        LDR     r12, [r12]
        BL      DecodeOnOrOff
        SWI     XSound_Speaker
        EXIT

; .............................................................................
; Out   r0 = 1,2 (ON/OFF)
;       r12 = workspace pointer

DecodeOnOrOff ROUT

        LDRB    r1, [r0], #1            ; Spaces skipped already
        CMP     r1, #"O"
        CMPNE   r1, #"o"
        BNE     Bad_Parameter_Error
        LDRB    r1, [r0], #1
        CMP     r1, #"N"
        CMPNE   r1, #"n"
        BNE     %FT50
        LDRB    r1, [r0], #1            ; Ensure no trailing junk
        CMP     r1, #" "
        BHI     Bad_Parameter_Error
        MOV     r0, #2                  ;  2 -> ON
        MOV     pc, lr                  ; flags irrelevant on *-command exit

50      CMP     r1, #"F"
        CMPNE   r1, #"f"
        BNE     Bad_Parameter_Error
        LDRB    r1, [r0], #1
        CMP     r1, #"F"
        CMPNE   r1, #"f"
        CMPNE   r1, #"."
        BNE     Bad_Parameter_Error

        LDRB    r1, [r0], #1            ; Ensure no trailing junk
        CMP     r1, #" "
        BHI     Bad_Parameter_Error
        MOV     r0, #1                  ;  1 -> OFF
        MOV     pc, lr                  ; flags irrelevant on *-command exit

Bad_Parameter_Error
        ADR     r0, ErrorBlock_BadSoundParameter

ReturnError ; For star commands

        BL      CopyError
        PullEnv
        RETURNVS

        MakeInternatErrorBlock BadSoundParameter,,M00

; .............................................................................

Stereo_Code ALTENTRY

        LDR     r12, [r12]              ; Get workspace pointer
        MOV     r1, r0
        MOV     r0, #10 + (2_100 :SHL: 29) ; Fault bad terminators
        SWI     XOS_ReadUnsigned
        BVS     Stereo_Channel_Error

        SUB     r14, r2, #1             ; Ensure in 1..SoundPhysChannels
        CMP     r14, #SoundPhysChannels
        BHS     Stereo_Channel_Error

        MOV     r4, r2                  ; preserve

10      LDRB    r3, [r1], #1            ; strip spaces
        CMP     r3, #" "
        BEQ     %BT10

        TEQ     r3, #"-"                ; signed?
        TEQNE   r3, #"+"
        SUBNE   r1, r1, #1              ; retrace our steps

        MOV     r0, #10 + (2_100 :SHL: 29) ; Fault bad terminators
        SWI     XOS_ReadUnsigned
        BVS     Stereo_Position_Error

        CMP     r2, #127
        BHI     Stereo_Position_Error

        TEQ     r3, #"-"                ; invert now if -ve
        RSBEQ   r2, r2, #0

        MOV     r0, r4                  ; channel no.
        MOV     r1, r2                  ; Position
        SWI     XSound_Stereo
        EXIT


Stereo_Channel_Error
        ADR     r0, ErrorBlock_BadSoundChannel
        B       ReturnError

        MakeInternatErrorBlock BadSoundChannel,,M01


Stereo_Position_Error
        ADR     r0, ErrorBlock_BadSoundStereo
        B       ReturnError

        MakeInternatErrorBlock BadSoundStereo,,M02

; .............................................................................

SoundSystem_Code
; In:   r0 = 0  => print syntax only
;       r0 = 1  => print current status
;       r0 > 1  => configure new value
;
        LDR     r12, [r12]

        Entry   "r1-r3"

        CMP     r0, #1
        BEQ     %FT10
        BCS     %FT20

        SWI     XOS_WriteS                      ; Print syntax only.
soundsystem_string
        DCB     "SoundSystem  ",0
        ALIGN
        SWI     XOS_WriteS
        DCB     "16bit [Oversampled] | <D>",0
        SWIVC   XOS_NewLine
        EXIT

10
        MOV     r0, #161                        ; Print status so read CMOS.
        MOV     r1, #PrintSoundCMOS
        SWI     XOS_Byte
        ADRVC   r0, soundsystem_string
        SWIVC   XOS_Write0
        EXIT    VS

        ADR     r0, parameter_16bit
        SWI     XOS_Write0
        EXIT    VS

        TST     r2, #&80
        BEQ     %FT15
        SWI     XOS_WriteI+" "
        ADRVC   r0, parameter_oversampled
        SWIVC   XOS_Write0
15
        SWIVC   XOS_NewLine
        EXIT

20
        MOV     r3, r0                          ; Save pointer to first parameter.

30
        MOV     r0, r3
        ADR     r1, parameter_16bit
        BL      strcmp_advance
        BNE     %FT40

        BL      skip_spaces                     ; "16bit" given so check for second parameter.
        MOVCC   r3, #1                          ; None, so no oversample.
        BCC     set_new_value

        ADR     r1, parameter_oversampled       ; Must be "oversampled".
        BL      strcmp_advance
        MOVEQ   r3, #5
        BEQ     set_new_value

        MOV     r0, #0                          ; Bad configure option.
exit_error
        SETV
        EXIT

40
        MOV     r0, #10:OR:(1:SHL:31):OR:(1:SHL:29)     ; Read unsigned, limit range, check terminator.
        MOV     r1, r3
        MOV     r2, #7
        SWI     XOS_ReadUnsigned
        EXIT    VS

        MOV     r0, r1                          ; Make sure number is not followed by another parameter.
        BL      skip_spaces
        MOVCS   r0, #3
        BCS     exit_error

        MOV     r3, r2
set_new_value
        MOV     r0, #161                        ; Read current value.
        MOV     r1, #PrintSoundCMOS
        SWI     XOS_Byte

        BICVC   r2, r2, #7:SHL:5                ; Set new value.
        ORRVC   r2, r2, r3, LSL #5
        MOVVC   r0, #162
        SWIVC   XOS_Byte
        EXIT


parameter_16bit
        DCB     "16bit",0
parameter_oversampled
        DCB     "Oversampled",0
        ALIGN

strcmp_advance
; In:   r0 -> string 1 (space or control char terminated)
;       r1 -> string 2 (space or control char terminated)
; Out:  EQ => strings match (no case)
;       r0 -> terminator of string 1
;       OR
;       NE => strings do not match
;
        Entry   "r2"
10
        LDRB    r2, [r0], #1
        LDRB    lr, [r1], #1
        CMP     r2, #" "                ; If found both terminators then strings are equal.
        CMPLE   lr, #" "
        BLE     %FT20

        BIC     r2, r2, #1:SHL:5
        BIC     lr, lr, #1:SHL:5
        TEQ     r2, lr
        BEQ     %BT10
        EXIT                            ; Not same so exit NE.
20
        SUB     r0, r0, #1              ; Point to terminator.
        CMP     r0, r0                  ; Same so exit EQ.
        EXIT

skip_spaces
; In:   r0 -> string
; Out:  r0 -> first non-space in string
;       CC => control char found
;       CS => printable char found
;
        Entry
10
        LDRB    lr, [r0], #1
        CMP     lr, #" "
        BEQ     %BT10
        SUB     r0, r0, #1
        EXIT


; .............................................................................

SoundGain_Code  ALTENTRY

        LDR     r12, [r12]              ; Get workspace pointer

        MOV     r1, r0
        MOV     r0, #10 + (2_100 :SHL: 29) ; Fault bad terminators
        SWI     XOS_ReadUnsigned        ; complain if not a number or bad term
        BVS     Bad_Parameter_Error
        CMP     r2, #7                  ; if >7, complain about range
        BHI     SoundGain_Error
        LDR     r1, =SoundLevel0Base
        STRB    r2, [r1, #SoundGain]   ; else store out for compilation on next irq
        EXIT

SoundGain_Error
        ADR     r0, ErrorBlock_BadSoundGain
        B       ReturnError

        MakeInternatErrorBlock BadSoundGain,,M03

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        SUBT    Sound DMA Module Data Structure and Constants
        OPT     OptPage

; DMA physical address pointer

; Prototype of part of Sound0Segment from Buff 0 .. Scheduler

ProtoS0S
        DCD     SoundDMABuffers                         ; Buff 0
        DCD     SoundDMABuffers + SoundDMABufferSize    ; Buff 1
; Config word, comprised of buffer length (16 bits), period (8 bits),
; log2nchan (2 bits), misc config flags (5 bits)
; Last bit reserved for level1 config changed flag
        DCW     SCBufferLen
        DCB     SCPeriod
        DCB     SCLogChannel

        DCD     SoundSystemNIL                          ; channel handler
        DCB     &80, &80, &80, &80, &80, &80, &80, &80  ; Images (2 words worth)
        DCD     SoundSystemNIL                          ; scheduler

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        SUBT    Sound DMA Module SWI Interface
        OPT     OptPage

Sound_SWI_Code ROUT
        MRS     R10, CPSR
        Push    "R10,R14"
        SEI     SVC32_mode
        BL      Original_SWI_Code
        Pull    "R10,R14"
        MSR     CPSR_c, R10             ; restore interrupts
        MOV     PC,R14                  ; 32-bit exit: NZ corrupted, CV passed back

Original_SWI_Code
        LDR     r10, =SoundLevel0Base
        CMP     r11, #(EndOfJumpTable-JumpTable)/4
        ADDCC   pc, pc, r11, LSL #2
        MOV     pc, lr

JumpTable
        B       Sound0Config            ; configuration
        B       Sound0Enable            ; enable control
        B       Sound0Stereo            ; stereo positioning
        B       Sound0Speaker           ; loudspeaker control
        B       Sound0Mode              ; mode control/status (16-bit/mu-law etc)
        B       Sound0LinearHandler     ; 16-bit sound generator interface
        B       Sound0SampleRate        ; new sample rate control interface
        B       Sound0ReadSysInfo       ; Read info
        B       Sound0SelectDefaultController
        B       Sound0EnumerateControllers
        B       Sound0ControllerInfo
EndOfJumpTable

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0  = no. of channels (rounded up to power of two)
;       r1  = samples per buffer
;       r2  = uS per sample
;       r3  = Level1 Handler   (normally 0!)
;       r4  = Level2 Scheduler (normally 0!)
;       r10 = SoundLevel0Base
;       0 -> don't change!
;       IRQs disabled
;
; Constraints:
;              1 <= r0             <= 8
;             16 <= r1 * NChannels <= SoundDMASize
;  3 * NChannels <= r2 * NChannels <= 255

; Out   Return old r0,r1,r2,r3,r4

Sound0Config Entry

        Debug   swi,"Sound0Config",r0,r1,r2,r3,r4

        CMP     r0, #0                  ; r0 processing
        LDREQB  r0, [r10, #NChannels]
        ANDEQ   r0, r0, #3
        BEQ     %FT10

        SUB     r0, r0, #1              ; 1=>0, 2=>1 FOR LOGS!
        CMP     r0, #3
        MOVEQ   r0, #2                  ; 2,3 => 2
        MOVGT   r0, #3                  ; 4,5,6,7 => 3

10 ; MUST UPDATE STEREO POSITIONS

        Push    "r0-r3"
        LDRB    r3, [r10, #NChannels]
        STRB    r0, [r10, #NChannels]
        MOV     r2, #1
        MOV     r2, r2, LSL r0          ; number of channels

; for r0 = 1 to NChannels
        MOV     r0, #1
15      MOV     r1, #-128               ; read stereo pos
        SWI     XSound_Stereo           ; get previous
        SWI     XSound_Stereo           ; force set to new channels
        ADD     r0, r0, #1
        CMP     r0, r2
        BLE     %BT15                   ; loop for N active channels

        STRB    r3, [r10, #NChannels]
        Pull    "r0-r3"

16
        CMP     r1, #0                  ; r1 processing
        LDREQ   r1, [r10, #Config]      ; bottom 16 bits
        BIC     r1, r1, #&FF000000
        BIC     r1, r1, #&00FF0000

        MOV     r1, r1, LSL r0          ; scale for NChannels of 8bit data
     [ UseNEON
        ADD     r1, r1, #15             ; Must be multiple of 16 for NEON code
        BIC     r1, r1, #15
     ]
        CMP     r1, #SoundDMABufferSize ; can't be > buffer size
        MOVGT   r1, #SoundDMABufferSize
        MOV     r1, r1, LSR r0          ; back to per channel

        ; Get minimum buffer size + granularity
        ; TODO - This could be improved for the case where oversampling is enabled. Unfortunately restructuring the code to allow oversampling to influence the buffer size could be a bit tricky.
        Push    "r2-r3"
        LDR     r2, [r10, #SoundRMA]
        LDR     r2, [r2, #HALDevice]
        CMP     r2, #1                  ; Use default limits if no device
        LDRHS   r3, [r2, #HALDevice_Version]
        CMPHS   r3, #2:SHL:16           ; Only available with API 2+
        LDRHS   r3, [r2, #HALDevice_AudioMinBuffSize]
        LDRHS   r2, [r2, #HALDevice_AudioBuffAlign]
        MOVLO   r3, #0
        MOVLO   r2, #0
        CMP     r3, #32                 ; ensure enough 8bit/16bit samples for >= 32bytes of data (sensible default minimum)
        MOVLO   r3, #32

        CMP     r1, r3, LSR #2          ; Apply min buffer size requirement
        MOVLT   r1, r3, LSR #2

        CMP     r2, #0                  ; Mono/oversample code processes 4 words of (non-oversampled) linear data at a time, so ensure granularity is a multiple of 16
        MOVEQ   r2, #16
20
        TST     r2, #&f
        MOVNE   r2, r2, LSL #1
        BNE     %BT20
        MOV     r2, r2, LSR #2          ; Get granularity in terms of stereo sample pairs

        DivRem  r3, r1, r2, lr
        CMP     r1, #0
        MOVNE   r1, r2                  ; Apply granularity requirement (round remainder up to granularity)
        MLA     r1, r2, r3, r1

        ; Check (non-oversampled) linear data doesn't overflow buffer
        ; Oversampled data is checked by process_oversample
        CMP     r1, #SoundDMABufferSize :SHR: 2
        BLE     %FT21
        MOV     r1, #SoundDMABufferSize :SHR: 2
        DivRem  r3, r1, r2, lr, norem   ; Work out how many multiples of granularity we can fit, and use that (assumed to be >= min buffer size)
        MUL     r1, r2, r3
21
        Pull    "r2-r3" 

        Debug   swi,"per channel bufsz =",r1

        CMP     r2, #0                  ; r2 processing
        LDREQB  r2, [r10, #Period]       ; if 0 then substitute current

        BL      WorkOutVIDCParams       ; but still go through update procedure

30      CMP     r3, #0                  ; r3 processing
        LDREQ   r3, [r10, #Level1Ptr]    ; old if 0

        CMP     r4, #0                  ; r4 processing
        LDREQ   r4, [r10, #Level2Ptr]    ; old if 0

40 ; merge into reg

        ORR     r11,  r1, r2, LSL #16
        ORR     r11, r11, r0, LSL #24

        LDR     r0, [r10, #Config]      ; Get return params
        AND     r1, r0, #&FC000000      ; extract current flags from nchan/flags byte
        ORR     r11, r11, r1            ; combine into new config value to store
        BIC     r1, r0, #&FF000000      ; mask out flags etc, leaving per-chan buflen
        BIC     r1, r1, #&00FF0000

        MOV     r2, r0, LSR #16
        AND     r2, r2, #&FF            ; current period value in r2

        ; produce channel count in r0, starting from config word in r0.
        MOV     r0, r0, LSR #24
        AND     r0, r0, #3
        ORR     r0, r0, #&01000000
        MOV     r0, r0, LSL r0          ; relies on LSL reg using only bits 7:0 of reg!
        MOV     r0, r0, LSR #24

        STR     r11, [r10, #Config]     ; store new buflen, period, log2nchan, flags

        LDR     r11, [r10, #Level1Ptr]  ; SSCB base
        STR     r3,  [r10, #Level1Ptr]  ; Install new Level1 handler
        MOV     r3,  r11                ; Return old

        LDR     r11, [r10, #Level2Ptr]  ; SSCB base
        STR     r4,  [r10, #Level2Ptr]  ; Install new Level2 handler
        MOV     r4,  r11                ; Return old

        PullEnv
        B       UpdateHALParams         ; Update HAL now that BuffLen is up to date

; Alternate entry point used during module initialisation
; This skips out the XSound_Stereo calls which would fail (and potentially loop forever) due to our SWIs not being hooked up yet
Sound0InitConfig ALTENTRY
        B       %BT16

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       WorkOutVIDCParams - Compute sample rate index from
;       present configuration: no. of channels, sample period.
;
; in:   r0 = log2(no of channels)
;       r1 = samples per buffer
;       r2 = desired sample period in microseconds, if < 256,
;       r10 = SoundLevel0Base
;
; out:  r2 = effective per-channel sample rate used (in microseconds)
;       CurSRIndex, CurSRValue updated
;

WorkOutVIDCParams ROUT
        Entry   "r0,r1,r3-r8"

        Debug   swi,"WorkOutVIDCParams",r0,r1,r2

20

; 16-bit output hardware in place: must use one of the subset of sample rates
; supported in this configuration. Scan the set of tabulated frequencies,
; looking for a suitable match.
; This could be reworked a bit for oversampling (i.e. look for r2/2 instead of
; making process_oversample look for closest_sample_rate*2)

        LDR     r5, [r10, #SoundRMA]
        LDR     r5, [r5, #HALDevice]
        CMP     r5, #0
        BEQ     %FT99
        LDR     r4, [r5, #HALDevice_AudioRateTable]
        LDR     r5, [r5, #HALDevice_AudioNumRates]
        SUB     r4, r4, #AudioRateTableSize ; address 0th entry of main freq info table
        MOV     lr, #1                  ; start with entry 1 in map
        ASSERT  AudioRateTableSize = 8
22      ADD     r1, r4, lr, LSL #3      ; address entry in table
        LDRB    r3, [r1, #AudioRateTable_Period] ; pick up nominal period

        SUBS    r7, r3, r2              ; place (entry - freq) in r7
        BEQ     %FT26                   ; if =, go do it
        BPL     %FT24                   ; else if freq > entry, then look at next entry

                                        ; here, freq < entry, so test for closest match ie

                                        ;      (last_entry > freq < this_entry)

        CMP     lr, #1                  ; accept if at start of table
        BEQ     %FT26
        SUB     lr, lr, #1              ; otherwise back up to previous entry
        ASSERT  AudioRateTableSize = 8
        ADD     r1, r4, lr, LSL #3      ; address entry in table
        LDRB    r3, [r1, #AudioRateTable_Period] ; pick up nominal period

        SUB     r8, r2, r3              ; place (freq - entry) in r8

        CMP     r7, r8                  ; if r7 < r8 (they're negative) then we have best
        BLT     %FT26                   ; match so accept the current entry

        ADD     lr, lr, #1              ; otherwise go back up to next entry
        ASSERT  AudioRateTableSize = 8
        ADD     r1, r4, lr, LSL #3      ; address entry in table
        LDRB    r3, [r1, #AudioRateTable_Period] ; pick up nominal period
        B       %FT26                   ; and accept it


24      CMP     lr, r5                  ; if at end of list, accept this one
        BEQ     %FT26
        ADD     lr, lr, #1
        B       %BT22

26      LDRB    r2, [r1, #AudioRateTable_Period] ; pick up period to report back to user
        LDR     r0, [r1, #AudioRateTable_Frequency] ; get frequency value
        ; and drop into final code

; Store computed values and exit:
; lr is sample rate index
; r2 is user-visible per-channel period,
; r0 is sample frequency in Hz/1024
98
        Debug   swi,"computed values are",lr,r2,r0

        LDR     r5, [r10, #SoundRMA]
        STR     r0, [r5, #CurSRValue]   ; update frequency
        STR     lr, [r5, #CurSRIndex]   ; and index of frequency
        MOV     r3, lr
        LDRB    r0, [r10, #Flags]
        LDR     r1, [sp, #4]            ; get back current/new samples per buffer
        BL      process_oversample      ; go set up to do oversampling iff we can
        STRB    r0, [r10, #Flags]       ; store back possibly updated flags
        STR     r3, [r5, #CurSRIndex_OS] ; store back oversampled freq index 
        EXIT                            ; return with updated period in R2

99
; No HAL device, so don't allow sample rate to be changed from previous value
        LDRB    r2, [r10, #Period]      ; Assuming Period hasn't been prematurely overwritten
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       UpdateHALParams - Reprograms the HAL device with the current sample rate
;       and DMA buffer size. Typically, this function must be called shortly
;       after calling WorkOutVIDCParams.
;
;       Currently, if sound is enabled we must disable it and then re-enable it.
;       This is because (unlike on IOMD) most modern machines don't allow the
;       sample rate to be changed on the fly. Devices are generally more
;       flexible when it comes to changing DMA buffer size, but DMAManager
;       doesn't provide the ability to update the parameters of a running
;       transfer (and neither to seamlessly chain two transfers together), so
;       for buffer size changes we have to stop and start playback also.
;
;       To avoid spurious updates (e.g. when Sound_Configure is called with all
;       0's) we first check a shadow copy of the HAL state.
;
;       in: r10 = SoundLevel0Base
;       out: All regs preserved
;
UpdateHALParams Entry "r0-r6,r12"
        LDR     r6, [r10, #SoundRMA]
        LDR     r0, [r6, #HALDevice]
        CMP     r0, #0
        EXIT    EQ ; No device active; ignore update
        LDRB    r4, [r10, #Flags]
        ANDS    r4, r4, #DoOversample
 [ UseLDRSH
        LDRH    r0, [r6, #HALBuffLen]
        LDRH    r3, [r10, #BuffLen]
        MOVNE   r3, r3, LSL #1 ; Double buffer length if oversampling
        CMP     r0, r3
        STRNEH  r3, [r6, #HALBuffLen]
 |
        LDR     r0, [r6, #HALBuffLen]
        LDR     r3, [r10, #BuffLen]
        MOVNE   r3, r3, LSL #17 ; Double buffer length if oversampling
        MOVEQ   r3, r3, LSL #16
        CMP     r3, r0, LSL #16
        ; Avoid overwriting UserOSFlag & ResetPending. Having those as 1 byte variables is probably more hassle than it's worth :(
        MOV     r3, r3, LSR #16
        STRNEB  r3, [r0, #HALBuffLen]
        MOVNE   r2, r3, LSR #8
        STRNEB  r2, [r0, #HALBuffLen+1]
 ]
        LDREQ   r0, [r6, #HALSRIndex]
        LDR     r5, [r6, #CurSRIndex_OS]
        CMPEQ   r0, r5
        BEQ     %FT10
        STR     r5, [r6, #HALSRIndex]
        STRB    r4, [r6, #UserOSFlag]

        TST     r4, #DoOversample
        MOVNE   r3, r3, LSR #1 ; Get non-oversampled buffer size back, ready for service call
        LDR     r4, [r10, #Semaphore]
        TST     r4, #&80000000
        MOVEQ   r0, #1
        SWIEQ   XSound_Enable ; Sound off

        ; Issue service call to let everyone know the parameters are changing
        MOV     r0, #Service_SoundConfigChanging
        MOV     r1, #Service_Sound
        LDR     r2, [r6, #CurSRValue]
        ; r3 already contains buffer size
        SWI     XOS_ServiceCall

        LDR     r0, [r6, #HALDevice]
        SUB     r1, r5, #1              ; 0-based index for HAL
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_AudioSetRate]
        TST     r4, #&80000000
        MOVEQ   r0, #2
        SWIEQ   XSound_Enable ; Sound back on again
        CLRV ; TODO - Error reporting
        EXIT

10
        ; No HAL update required, but if the user turned off oversampling at
        ; the same time as doubling the sample rate and buffer size then we'll
        ; have skipped out a required Service_SoundConfigChanging call
        ; So use UserOSFlag to track the previous oversampling state and
        ; trigger the service call if oversampling has been toggled
        LDRB    r0, [r6, #UserOSFlag]
        CMP     r0, r4
        EXIT    EQ
        STRB    r4, [r6, #UserOSFlag]
        ; Issue service call to let everyone know the parameters are changing
        MOV     r0, #Service_SoundConfigChanging
        MOV     r1, #Service_Sound
        LDR     r2, [r6, #CurSRValue]
        MOVLT   r3, r3, LSR #1 ; LT if oversampling currently on
        SWI     XOS_ServiceCall
        CLRV
        EXIT        

; process_oversample
; in:  r0 = flags value
;      r1 = samples per buffer
;      r2 = user-visible period
;      r3 = 1-based sample rate index
;      r10 = SoundLevel0Base
; out: r0 = new flags value reflecting oversampling state
;      r1 unchanged
;      r2 unchanged
;      r3 = updated sample rate index reflecting oversampling state
process_oversample Entry "r1,r2,r4,r5"
        Debug   swi,"process_oversample, default off"
        BIC     r0, r0, #DoOversample   ; clear out o/s active flag, assuming not possible
        TST     r0, #OversampleFlag     ;   && auto oversample flag is set)
        EXIT    EQ                      ; else return - can't oversample
        CMP     r2, #MinOSPeriod        ; check sample period value against oversample limit
        EXIT    LT                      ; if too small (f too high), can't oversample
        ; check buffer size: may be too big to handle double-length (4KB max)
        CMP     r1, #SoundDMABufferSize/8 ; check against size limit at Fs*2
        EXIT    HI                      ; don't oversample if gets too big
        ; Check if audio device can support Fs*2
        ; Do a simple linear search for now
        LDR     r1, [r10, #SoundRMA]
        LDR     r1, [r1, #HALDevice]
        CMP     r1, #0
        EXIT    EQ                      ; no device, so o/s flag is irrelevant
        LDR     r2, [r1, #HALDevice_AudioNumRates]
        LDR     r1, [r1, #HALDevice_AudioRateTable]
        ASSERT  AudioRateTableSize = 8
        SUB     r1, r1, #8-AudioRateTable_Frequency
        LDR     r4, [r1, r3, LSL #3]    ; Get current rate
        MOV     r5, r3
01
        ADD     r5, r5, #1
        CMP     r5, r2
        EXIT    HI
        LDR     lr, [r1, r5, LSL #3]
        CMP     r4, lr, LSR #1          ; Assume bottom bit of Fs*2 irrelevant (for inexact sample rates, e.g. 20.833kHz)
        BHI     %BT01
        EXIT    LO
        Debug   swi,"oversampling on"
        MOV     r3, r5                  ; Select new rate index
        ORR     r0, r0, #DoOversample   ; and inform IRQ level through flags
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = 0 -> leave (and return previous)
;            1 -> OFF
;          >=2 -> ON
;       r10 = SoundLevel0Base
;       SVC mode, IRQs disabled

; Out   r0 = previous enable state / error block
;       All other regs preserved
;       IRQs potentially enabled!

Sound0Enable Entry "r1,r4,r11,r12"

        LDR     r11, [r10, #Semaphore]
        TST     r11, #&80000000
        MOVEQ   r11, #2                 ; return ON
        MOVNE   r11, #1                 ; or OFF

        CMP     r0, #1
        BLT     %FT20                   ; [just return value]

; Any state change request causes us to clear ReenableFlag
        LDR     r4, [r10, #SoundRMA]
        MOV     lr, #0
        STRB    lr, [r4, #ReenableFlag]

        BGT     %FT10

; Turn OFF

        TEQ     r11, #1
        BEQ     %FT20

        MOV     r14, #&80000000         ; Set semaphore
        STR     r14, [r10, #Semaphore]
        
        ; Enable IRQs so we can call the potentially slow HAL device
        ; Thankfully the RISC OS 3 PRMs describe Sound_Enable as having undefined re-entrancy (and undefined IRQ status), so we don't have to worry about attempting to behave in a sane manner if we should get re-entered while the device does its stuff.
        CLI     SVC32_mode

        LDR     r4, [r10, #SoundRMA]

        LDR     r0, [r4, #HALDevice]
        Push    "r2-r3"
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_AudioPreDisable]

        MOV     r0, #0
        LDR     r1, [r4, #DMATag]
        CMP     r1, #0
        SWINE   XDMA_TerminateTransfer
        ; TODO - Handle error better - need to undo PreDisable somehow?
        STRVC   r0, [r4, #DMATag]
        Pull    "r2-r3",VS
        EXIT    VS

        LDR     r0, [r4, #HALDevice]
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_AudioPostDisable]
        Pull    "r2-r3"

        ; Get off RTSupport
        MOV     r12, r4
        BL      Finalise_RTSupport

        ; Indicate sound has stopped
        MOV     r1, #Service_Sound
        MOV     r0, #Service_SoundDisabled
        SWI     XOS_ServiceCall

        ; Disallow reset callbacks (not that we should receive any once sound is off)
        MOV     r0, #1
        STRB    r0, [r12, #ResetPending]
        ; Cancel any pending callbacks
        BL      RemoveCallbacks

        CLRV
        B       %FT20


10 ; Turn ON - turning on when already damages sample rate!

        CMP     r11, #2                 ; Exit if turning on when already on
        BEQ     %FT20                   ; This is the proper place to fix
                                        ; the bug, not at the *Audio level!

15
        MOV     r14, #0                 ; Clear semaphore. Common ep
        STR     r14, [r10, #Semaphore]
        
        ; Enable IRQs so we can call the potentially slow HAL device
        CLI     SVC32_mode

        LDR     r12, [r10, #SoundRMA]
        ; Make sure DMA & device are ready
        BL      Initialise_DMA
        ; Register with RTSupport
        BLVC    Initialise_RTSupport
      [ UseNEON
        ; ... and VFPSupport
        BLVC    Initialise_NEON
      ]
        BVS     %FT40

        ; Indicate sound is starting
        MOV     r1, #Service_Sound
        MOV     r0, #Service_SoundEnabled
        SWI     XOS_ServiceCall

        Push    "r2-r3,r5-r7"

        ; Build scatter list
        ADD     r5, r12, #DMAScatter+8
        LDR     r0, [r10, #Buff1]        
        LDR     r6, [r10, #Config]
        TST     r6, #DoOversample :SHL: 24 ; Check for oversampling
        MOV     r6, r6, LSL #16        ; 16-bit buffer length in r6
        MOVEQ   r6, r6, LSR #14        ; 4 bytes/sample if no o/s
        MOVNE   r6, r6, LSR #13        ; but 8 bytes/sample if o/s
        STMIA   r5, {r0,r6}
        LDR     r0, [r10, #Buff0]
        STMDB   r5!, {r0,r6} ; End with r5=scatter list start

        BL      RemoveCallbacks
        ; Allow reset attempts
        MOV     r0, #0
        STRB    r0, [r12, #ResetPending]

        ; Is DMAManager in use?
        MOV     r4, r12
        LDR     r0, [r4, #HALDevice]
        LDR     r2, [r0, #HALDevice_Version]
        CMP     r2, #2:SHL:16 ; API 2+?
        LDRHS   r2, [r0, #HALDevice_AudioCustomDMAEnable]
        CMPHS   r2, #1 ; With AudioCustomDMAEnable?
        MOV     r1, r6
        BHS     %FT21

        ; DMAManager is in use, so call PreEnable
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_AudioPreEnable]
        MOV     r12, r4

        ; Start the DMA transfer
        MOV     r0, #7 ; write, circular, call DMASync
        LDR     r1, [r12, #DMAChannel]
        MOV     r3, r5
        MOV     r4, #0 ; infinite length
        MOV     r5, r6, LSL #1 ; Circular buffer references this much data
        SWI     XDMA_QueueTransfer
        Pull    "r2-r3,r5-r7", VS
        BVS     %FT30
        STR     r0, [r12, #DMATag]

        ; Call PostEnable
        LDR     r0, [r12, #HALDevice]
        MOV     r1, r6
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_AudioPostEnable]
        Pull    "r2-r3,r5-r7"
19
        CLRV

20      MOV     r0, r11                 ; Return previous enable state
        EXIT                            ; Restores ints to caller state, maybe
                                        ; get IRQ'ed here too.

21
        ; DMAManager isn't in use, so call CustomDMAEnable
        ; Already have R1 = buffer size, R0 = hal device, r4 = SoundRMA, r5 = scatter list, r10 = SoundLevel0Base
        LDR     r2, [r5]
        LDR     r3, [r5, #8]
        LDR     r11, [r0, #HALDevice_AudioFlags]
        TST     r11, #AudioFlag_Synchronous
        ADREQL  r11, CustomDMASync_Async
        ADRNEL  r11, CustomDMASync_Sync
        STMFD   r13!,{r4,r11}
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_AudioCustomDMAEnable]
        ADD     r13, r13, #8
        MOV     r12, r4
        Pull    "r2-r3,r5-r7"
        CMP     r0, #0
        BEQ     %BT19
        ; Fall through with R0 = error ptr

30
        ; Initialisation failed
        ; TODO - Decide on how to shutdown HAL device (AudioPostDisable?)
        MOV     r4, r0
        ; Broadcast that sound isn't starting after all
        MOV     r1, #Service_Sound
        MOV     r0, #Service_SoundDisabled
        SWI     XOS_ServiceCall
        ; Deregister with RTSupport
        BL      Finalise_RTSupport
        MOV     r0, r4
        SETV
40
        ; Set semaphore again
        MOV     r14, #&80000000
        STR     r14, [r10, #Semaphore]
        EXIT
        
        

; .............................................................................
; Called at RESET time
; in: r10 = SoundLevel0Base

Sound0Reenable ALTENTRY

        LDR     r11, [r10, #Semaphore]
        TST     r11, #&80000000
        EXIT    NE                      ; was OFF, stays OFF

        B       %BT15                   ; Turn it on again

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = 0 -> leave (and return previous)
;            1 -> OFF
;          >=2 -> ON
;       r10 = SoundLevel0Base
;       IRQs disabled

; Out   r0 = previous speaker state

Sound0Speaker ROUT
        Entry   "r0-r4"
        LDR     r12, [r10, #SoundRMA]
        LDR     r0, [r12, #HALDevice]
        TEQ     r0, #0
        LDRNE   r0, [r0, #HALDevice_AudioMixer]
        TEQNE   r0, #0
        MOVEQ   r0, #2
        BEQ     %FT90           ; if no mixer attached, cannot control speaker
                                ; else mixer attached to our controller will be number 0
        MOV     r0, #0
        MOV     r1, #MixerCategory_Speaker
        MOV     r2, #0
        SWI     XSoundCtrl_GetMix
        BVS     %FT80
        TST     r3, #1          ; already muted?
        MOVEQ   lr, #2
        MOVNE   lr, #1
        LDR     r3, [sp, #Proc_RegOffset] ; get new state
        STR     lr, [sp, #Proc_RegOffset] ; return old state in R0
        CMP     r3, #1
        EXIT    LO
        MOVEQ   r3, #1
        MOVHI   r3, #0
        SWI     XSoundCtrl_SetMix
        BVS     %FT90
        EXIT

80
        ; Sound mixer present, but no speaker channel (or some other error)
        ; Act as if mixer wasn't there and just report ON
        MOV     r0, #2
        CLRV

90      STR     r0, [sp, #Proc_RegOffset]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0  = channel number (1-8)
;       r1  = -127 for left, 0 centre, 127 right (-128 DON'T CHANGE)
;       r10 = SoundLevel0Base
;       IRQs disabled

; Attempts to be slightly clever...
; programs at interleave factor from r0 upwards...
; note pipeline delay on NChannels...!

; Out   r0 preserved
;       r1 is stereo position allocated (-128 for none/invalid)
;       -128 indicates invalid channel

Sound0Stereo Entry "r0, r2"

        SUB     r0, r0, #1              ; 1..8 -> 0..7
        CMP     r0, #SoundPhysChannels
        MOVHS   r1, #-128
        EXIT    HS

        ADD     r2, r1, #&80            ; add new offset
        LDRB    r14, [r10, #NChannels]
        AND     r14, r14, #3            ; get rid of extra flag bits
        MOV     r11, #1
        MOV     r14, r11, LSL r14       ; convert log

        ADD     r12, r10, #Images
        LDRB    r1, [r12, r0]           ; current pos
        SUB     r1, r1, #&80            ; map back to -127..+127

        CMP     r2, #0
        CMPNE   r2, #&100               ; force range
        EXIT    HS

        ADD     r11, r12, #8            ; end
        ADD     r12, r12, r0            ; base channel
05      STRB    r2, [r12], r14          ; store new pos
        CMP     r12, r11
        BLT     %BT05

        ADD     r0, r10, #Images        ; address full-size image set
        BL      ConvImages              ; produce compacted form...
        STR     r0, [r10, #ImagesC_N]   ; for programming on appropriate IRQ
        EXIT                            ; go back to caller


; Sound0Mode - implements Sound_Mode SWI
;
; In:
;
;   R0: function code
;     = 0: read current mode, returning information in r0/r1.  This code must
;          be used first, to determine the availability of other functions.
;     = 1: set/clear oversampling mode, returning previous state (0 or 1)
;          R1 = 0: disable linear 2x oversampling
;          R1 <> 0: enable linear 2x oversampling
;     = 2: (NOT YET IMPLEMENTED) set external sound clock handler
;          function (for format/status value 3)
;          R1 = external sound clock handler address, or 0 to cancel
;     = 3: set/clear mono flag, returning previous state (0 or 1)
;	   R1 = 0: stereo mode
;	   R1 <> 0: mono mode (convert stereo to mono for output)
;     other function code values not defined
;
;   R10 = SoundLevel0Base
;   IRQs disabled
;
; Out:
;  For function code 0:
;       R0      = 0: mu-law sound system only; SWIs Sound_LinearHandler and
;                    Sound_SampleRate, and all other functions of Sound_Mode, are
;                    not supported.  Contents of r1 are unchanged.
;       R0      = 1: 16-bit capable sound system: SWIs Sound_LinearHandler and
;                    Sound_SampleRate, and full Sound_Mode functionality are all
;                    available.
;
;       R1[3:0]: sound output format and clock control status (from CMOS RAM)
;               = 1: 16-bit linear output, 44k1, 22k05, 11k025 and selected original rates
;               = 2: 16-bit linear output, internal clock, selected original rates only
;               = 3: 16-bit linear output, external master clock source, custom rates only
;               = 4...15: reserved values
;       R1[4]: oversampling control
;               = 0: automatic linear 2x oversampling disabled
;               = 1: automatic linear 2x oversampling enabled
;       R1[5]   = 0: stereo output
;		= 1: mono conversion on output
;       R1[31:6]: reserved for expansion
;
; For all rates <= 25kHz, if auto-oversampling is on, the output data stream
; will be oversampled by 2x, by simple linear interpolation.
;
Sound0Mode      Entry   "r2"
        LDRB    r2, [r10, #Flags]

        CMP     r0, #0
        BNE     %FT10
; Function code 0: read mode information
        MOV     r0, #1                  ; new system, 16-bit
        MOV     r1, #1                  ; all sorts of clocks
        TST     r2, #OversampleFlag     ; check for oversampling
        ORRNE   r1, r1, #1 :SHL: 4      ; set flag if so
        TST	r2, #DoMono		; check for mono mode
        ORRNE	r1, r1, #1 :SHL: 5	; set flag if enabled
        EXIT

10      CMP     r0, #1
        BNE     %FT20
; Function code 1: enable/disable automatic oversampling (allows overriding CMOS value)
        LDR     r0, [r10, #Config]
        MOV     r2, r0, LSR #24
        MOV     lr, r2                  ; preserve original value
        BIC     r2, r2, #OversampleFlag ; clear o/s bit, but NOT DoOversample for now
        CMP     r1, #0                  ; check requested state
        ORRNE   r2, r2, #OversampleFlag ; set bit if required
        ANDS    r1, lr, #OversampleFlag ; get old state of flag into r1 (wrong bit pos)
        MOVNE   r1, #1                  ; if not zero, set 1, else 0 already there...
        ; Need to fix up for oversampling if now enabled.
        Push    "r1,r3,r4"
        MOV     r1, r0, LSL #16         ; r1 = samples per buffer
        MOV     r1, r1, LSR #16
        MOV     r0, r2                  ; r0 = new flags
        LDRB    r2, [r10, #Period]      ; and user-visible sample period into r2
        LDR     r4, [r10, #SoundRMA]
        LDR     r3, [r4, #CurSRIndex]   ; and user-visible SR index into r3
        BL      process_oversample      ; determine whether to use o/s
        STRB    r0, [r10, #Flags]       ; store final flags
        STR     r3, [r4, #CurSRIndex_OS] ; and required SR index
        Pull    "r1,r3,r4"
        MOV     r0, #1
        PullEnv
        B       UpdateHALParams         ; Update HAL on way out

20      CMP     r0, #2
        BNE     %FT30
; FUNCTION CODE 2: NOT YET IMPLEMENTED!
	B	%FT99
30	CMP	r0, #3
	BNE	%FT40
; Function code 3: enable/disable mono-isation (allows overriding CMOS value)
        LDRB    r2, [r10, #Flags]       ; get flags byte
        MOV     lr, r2                  ; preserve original value
        CMP     r1, #0                  ; check requested state
        ORRNE   r2, r2, #DoMono         ; set bit if enabling mono conversion
        BICEQ   r2, r2, #DoMono         ; or clear bit if disabling it
        ANDS    r1, lr, #DoMono         ; get old state of flag into r1 (wrong bit pos)
        MOVNE   r1, #1                  ; if not zero, set 1, else 0 already there...
        STRB    r2, [r10, #Flags]       ; store out new flag value
        EXIT
40
99
        EXIT


; Sound0LinearHandler: implements Sound_LinearHandler SWI.
;
; In: (r0-r2 from user SWI)
;  r0 is function code:
;    r0 = 0: return current handler as {routine, param} pair in r1, r2
;         no side effects, all regs except r1, r2 preserved
;         a null handler is recorded as a routine address of 0, param of -1
;    r0 = 1: install new handler
;         r1 =  0: set null handler (initial, default state), r2 is ignored
;         r1 != 0: set r1 as routine to call, r2 as parameter value to pass
;                  to it in r0, with following call rules:
;               r0 = value specified on installation of routine (r2 here)
;               r1 = base of word-aligned buffer, to fill with 16-bit stereo
;                    data, stored as pairs of signed (2's complement) 16-bit
;                    values; each word has bits 31:16 left channel data, bits
;                    15:0 right channel data.
;               r2 = end of buffer (address of first word beyond buffer)
;               r3 = flag for initial buffer contents:
;                    0 => data in buffer is invalid and MUST be overwritten
;                    1 => data has been converted from N-channel mu-law sound
;                         system and may be either overwritten or (preferably)
;                         mixed with new data produced by routine.
;                    2 => data in buffer is all 0: if routine would generate
;                         silent output, it may simply return.
;               r4 = sample frequency at which data will be played, in Hz/1024
;                    (e.g. for 20kHz, r4 would be 20000*1024 = 20480000).
;    else (r0 = any other value): ignored (do nothing, not even error...)
;
;  r1 = as determined by value in r0
;  r2 = as determined by value in r0
;
;  r10 = SoundLevel0Base (set up locally)
;
;  IRQs are disabled
;
; Out:
;  r0 preserved
;  r1 = previous/current routine address
;  r2 = previous/current value to pass to routine
;
Sound0LinearHandler Entry "r3,r4,r5"
        LDR     r3, [r10, #SoundRMA]
        LDR     r4, [r3, #Lin16Gen]
        LDR     r5, [r3, #Lin16GenR0]
        CMP     r0, #1
        BHI     %FT10
        STREQ   r1, [r3, #Lin16Gen]     ; if r0 = 1, store new value for routine
        STREQ   r2, [r3, #Lin16GenR0]   ;            and new value for r0 param to routine
        MOVS    r1, r4                  ; set previous routine address in r1
        MOVNE   r2, r5                  ; if not null, put param to pass into r2
        MVNEQ   r2, #0                  ; else set -1 into r2
10
        EXIT                            ; and go home


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Sound0SampleRate: implements Sound_SampleRate SWI.  This SWI is only
; useable when SoundDevice is configured non-0, i.e. when there is 16-bit sound output
; hardware.  Otherwise it returns 0 in r1 and r2 for all calls.
;
; In: (r0,r1 from user SWI)
;   r0 is function code:
;      0: return in r1 the total number of available sample rates, NSR.
;         Available sample rates are indexed by numbers in the range 1..NSR,
;         and increase with increasing index number.  R2 is preserved.
;      1: return in r1 the index of the current sample rate, and in r2
;         the current sample rate, measured in units of 1/1024 Hz, e.g.
;         20kHz would be 20480000;
;      2: return in r2, as value measured in 1/1024ths of Hz, the sample
;         rate defined by index given in r1 (in range 1..NSR).
;      3: select new sample rate via index in r1, in range 1..NSR; return
;         index and value of previous rate in r1 and r2 respectively.
;
;   r1 = as determined by value in r0.
;   r2 = as determined by value in r0.
;
;  r10 = SoundLevel0Base (set up locally, not from SWI)
;
;  IRQs disabled
;
; Out:
;   r0 preserved
;   r1 = index of previous/current rate, or NSR;
;   r2 = previous/current/rate, measured in 1/1024ths of Hz, or preserved (r0 = 0)
;
Sound0SampleRate Entry "r3,r4"
        LDR     r3, [r10, #SoundRMA]
        CMP     r0, #0                  ; check function code
        LDR     r4, [r3, #HALDevice]
        BNE     %FT10

; Function code 0: read NSR (as configured at module init or via clock handler)
        TEQ     r4, #0
        LDRNE   r1, [r4, #HALDevice_AudioNumRates]
        MOVEQ   r1, #1                  ; only claim 1 rate if no device
        EXIT

10      CMP     r0, #1
        BNE     %FT20
; Function code 1: read current sample rate index and sample rate
15
        LDR     r2, [r3, #CurSRValue]
        LDR     r1, [r3, #CurSRIndex]
        EXIT

20      CMP     r0, #2
        BNE     %FT30
; Function code 2: return in r2 the sample rate for specified index in r1
        TEQ     r4, #0
        LDREQ   r2, [r3, #CurSRValue]
        EXIT    EQ                      ; just return last used if no device
        BL      SR_maptab               ; go get address of freq table entry
        CMP     r2, #0                  ; check for error
        BEQ     SR_badpar               ; handle error if any
        LDR     r2, [r2, #AudioRateTable_Frequency] ; pick up frequency
        EXIT                            ; all done!

30      CMP     r0, #3
        BNE     %FT40
; Function code 3: set sample rate as specified by index in r1
        TEQ     r4, #0
        BEQ     %BT15                   ; just return last used if no device
        BL      SR_maptab               ; get address of relevant main table entry
        MOVS    r4, r2                  ; move register, check for error (r2=0)
        BEQ     SR_badpar               ; handle error if any
        Push    "r1,r3"                 ; save new index
        LDRB    r2, [r4, #AudioRateTable_Period] ; get nominal period from table entry
        STRB    r2, [r10, #Period]      ; store away for Sound_Configure calls
        MOV     r3, r1                  ; r3 = new sample rate index
        LDR     r1, [r10, #Config]
        MOV     r0, r1, LSR #24         ; r0 = current flags
        MOV     r1, r1, LSL #16
        MOV     r1, r1, LSR #16         ; r1 = samples per buffer
        BL      process_oversample      ; work out whether o/s needed, fix SR index if so
        STRB    r0, [r10, #Flags]       ; and update flags
        ; Tell the HAL device about the new index
        Pull    "r0,lr"                 ; recover new index, SoundRMA
        STR     r3, [lr, #CurSRIndex_OS] ; save off oversampled index
        LDR     r1, [lr, #CurSRIndex]   ; get previous samplerate index for return to user
        STR     r0, [lr, #CurSRIndex]   ; save off new Sample Rate index
        LDR     r2, [lr, #CurSRValue]   ; get previous samplerate value for return to user
        LDR     r0, [r4, #AudioRateTable_Frequency] ; pick up frequency value from table entry
        STR     r0, [lr, #CurSRValue]   ; and save that too
        MOV     r0, #3
        PullEnv
        B       UpdateHALParams         ; update HAL on the way out
                                                

40                                      ; function code not 0..3: complain
SR_badpar
        ADR     r0, badparblock
        MOV     r1, #0
        MOV     r2, #0
        SWI     XMessageTrans_ErrorLookup
        PullEnv
        MOV     pc, lr                  ; SWI will always set V

badparblock
        DCD     ErrorNumber_BadParameters
        DCB     "BadParm",0
        ALIGN

; SR_maptab: subroutine to convert r1 SR index to address of relevant
; entry in ftab, in r2.  Assumes r4 contains HAL device pointer.
; r2 is set to 0 on error. Doesn't alter any other registers.
SR_maptab
        LDR     r2, [r4, #HALDevice_AudioNumRates] ; get max
        SUB     r1, r1, #1              ; reduce index to 0-based range
        CMP     r1, r2                  ; check against limit (unsigned)
        MOVHS   r2, #0                  ; if out of range, mark error
        LDRLO   r2, [r4, #HALDevice_AudioRateTable] ; get table ptr
        ASSERT  AudioRateTableSize = 8
        ADDLO   r2, r2, r1, LSL #3      ; index into main table (8 bytes each)
        ADD     r1, r1, #1              ; put index back again always
        MOV     pc, lr                  ; return


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Sound0ReadSysInfo: implements Sound_ReadSysInfo SWI.
;
; In:
;   r0 = reason code
;        1 -> return SoundDMA features
;        2 -> get current controller device name
; Other registers dependent on reason code
;
Sound0ReadSysInfo
        CMP     r0, #Sound_RSI_DefaultController
        LDR     r12, [r12]
        ADDLS   pc, pc, r0, LSL #2
        MOV     pc, lr
        MOV     pc, lr                              ; 0
        B       Sound0ReadSysInfo_Features          ; 1
        B       Sound0ReadSysInfo_DefaultController ; 2

; In:
;   r0 = 1 (reason code)
;
; Out:
;   r0 = 0
;   r1 = flags:
;        bit 0: Service_SoundRateChanging, Service_SoundEnabled, Service_SoundDisabled generated
;        bit 1: SelectDefaultController, EnumerateControllers, ControllerInfo SWIs supported
Sound0ReadSysInfo_Features
        MOV     r0, #0
        MOV     r1, #Sound_RSI_Feature_Service8910 :OR: Sound_RSI_Feature_ControllerSelection
        MOV     pc, lr

; In:
;   r0 = 2 (reason code)
;   r1 -> buffer
;   r2 = buffer length
;
; Out:
;   r0 = 0, or error (e.g. buffer overflow)
;   r2 updated with actual data length
;   buffer filled in with null-terminated controller device ID
Sound0ReadSysInfo_DefaultController ROUT
        Entry  "r2-r4"
        LDR     r2, [r12, #HALDevice]
        BL      DeviceList_FindByDevice
        CMP     r4, #0
        BEQ     SoundDevNotFoundErr
        ADD     r0, r4, #DeviceList_ID
        FRAMLDR r2
        BL      CopyStrToBuffer
        FRAMSTR r2
        MOVVC   r0, #0
        EXIT
SoundDevNotFoundErr
        PullEnv
        ADR     r0, ErrorBlock_SoundDevNotFound
        B       CopyError

        MakeInternatErrorBlock SoundDevNotFound,,M07


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Sound0SelectDefaultController: implements Sound_SelectDefaultController SWI.
;
; In:
;   r0 -> space/control-terminated terminated controller device ID
;
; Out:
;   r0 = 0, or error
;
; Switches the current audio controller device
Sound0SelectDefaultController ROUT
        ALTENTRY
        LDR     r12, [r12]
        BL      DeviceList_FindByID
        CMP     r3, #0
        BEQ     SoundDevNotFoundErr
        ; Do nothing if this is already the active device
        LDR     r4, [r12, #HALDevice]
        LDR     r2, [r3, #DeviceList_AudioDevice]
        EORS    r0, r4, r2
        EXIT    EQ
        ; Stop current device - similar to Service_Hardware handling
        LDR     r10, =SoundLevel0Base
        CMP     r4, #0
        BEQ     %FT20
        Push    "r3"
        BL      PostFinal_DisableSound  ; (Corrupts r0,r2-r4)
        LDRB    r0, [r12, #ReenableFlag]
        BL      Finalise_Device
        STRB    r0, [r12, #ReenableFlag]
        Pull    "r3"
20
        ; Start new device
        MOV     r0, r3
        BL      TryInitialise_Device
        BLVC    Try_Reinit              ; (Corrupts R3)
        MOVVC   r0, #0
        ; Note - we don't fall back to the old device if this fails!
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Sound0EnumerateControllers: implements Sound_EnumerateControllers SWI.
;
; In:
;   r0 = pointer to controller ID string to start from, or 0 or an empty string to start enumeration
;   r1 -> buffer for result (can be == r0)
;   r2 = length of buffer
;
; Out:
;   r0 = 0, buffer at r1 filled in with null-terminated ID of next controller. Buffer will be empty if end of list reached.
;   or r0 = error (e.g. buffer overflow)
;   r2 updated with actual data length
;
; Enumerates available controllers
Sound0EnumerateControllers ROUT
        ALTENTRY
        LDR     r12, [r12]
        CMP     r0, #0
        LDRNEB  r3, [r0]
        CMPNE   r3, #0
        ADDEQ   r3, r12, #DeviceList-DeviceList_Next
        BLNE    DeviceList_FindByID
        CMP     r3, #0
        LDRNE   r3, [r3, #DeviceList_Next]
        CMPNE   r3, #0
        ADREQ   r0, NullStr
        ADDNE   r0, r3, #DeviceList_ID
        BL      CopyStrToBuffer
        FRAMSTR r2
        MOVVC   r0, #0
        EXIT

NullStr
        DCB     0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Sound0ControllerInfo: implements Sound_ControllerInfo SWI.
;
; In:
;   r0 -> space/control terminated controller device ID
;   r1 -> buffer for result
;   r2 = length of buffer
;   r3 = value to read:
;        0 -> read null terminated device name for display to user
;        1 -> read mixer device ptr
;        2 -> read supported sample rates (1 word per sample rate, Hz*1024)
;
; Out:
;   r0 = 0, buffer at r1 filled in with given value
;   or r0 = error (e.g. buffer overflow)
;   r2 updated with actual length of data
;
; Read info for a given controller device
Sound0ControllerInfo ROUT
        ALTENTRY
        LDR     r12, [r12]
        BL      DeviceList_FindByID
        CMP     r3, #0
        BEQ     SoundDevNotFoundErr
        FRAMLDR r4,,r3
        CMP     r4, #Sound_CtlrInfo_SampleRates
        ADDLS   pc, pc, r4, LSL #2
        B       %FT90
        B       Sound0ControllerInfo_DisplayName
        B       Sound0ControllerInfo_MixerDevice
        B       Sound0ControllerInfo_SampleRates

Sound0ControllerInfo_DisplayName
        LDR     r3, [r3, #DeviceList_AudioDevice]
        LDR     r0, [r3, #HALDevice_Description]
        ; See if we have a translation available for the device name
        BL      TranslateDeviceDescription
        BL      CopyStrToBuffer
        FRAMSTR r2
        MOVVC   r0, #0
        EXIT

Sound0ControllerInfo_MixerDevice
        LDR     r0, [r3, #DeviceList_AudioDevice]
        ADD     r0, r0, #HALDevice_AudioMixer
      [ SupportSoftMix
        LDR     lr, [r0]
        CMP     lr, #0
        ADDEQ   r0, r3, #DeviceList_SoftMixDevice
      ]
        MOV     r3, #4
        BL      CopyDataToBuffer
        FRAMSTR r2
        MOVVC   r0, #0
        EXIT

Sound0ControllerInfo_SampleRates
        LDR     r3, [r3, #DeviceList_AudioDevice]
        LDR     r0, [r3, #HALDevice_AudioRateTable]
        LDR     r3, [r3, #HALDevice_AudioNumRates]
        MOV     r3, r3, LSL #2
        BL      CopySampleRatesToBuffer
        FRAMSTR r2
        MOVVC   r0, #0
        EXIT      

90
        PullEnv
        ADR     r0, badparblock
        B       CopyError

TranslateDeviceDescription
        ; In: r0 = description
        ;     r3 = device
        ;     r12 = SoundRMA
        ; Out: r0 updated if possible
        Entry   "r0-r3", 32
        BL      open_messagefile
        ADRVC   r0, DisplayNameTok
        MOVVC   r1, sp
        MOVVC   r2, #Proc_LocalStack
        BLVC    CopyStrToBuffer
        SUBVC   r2, r2, #1
        ADDVC   r1, r1, r2
        RSBVC   r2, r2, #Proc_LocalStack
      [ UseLDRSH
        LDRVCH  r0, [r3, #HALDevice_ID]
      |
        LDRVCB  r0, [r3, #HALDevice_ID]
        LDRVCB  lr, [r3, #HALDevice_ID+1]
        ORRVC   r0, r0, lr, LSL #8
      ]
        SWIVC   XOS_ConvertHex4
        ADDVC   r0, r12, #MessageFile_Block
        MOVVC   r1, sp
        MOVVC   r2, #0
        SWIVC   XMessageTrans_Lookup
        FRAMSTR r2,VC,r0
        EXIT

DisplayNameTok
        DCB     "HAL_Name_", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In:
;   r0 -> control-terminated string
;   r1 -> destination buffer, or 0 just to check length
;   r2 = buffer length
;   r12 = SoundRMA
;
; Out:
;   Buffer updated (with null terminated string) if length sufficient
;   r2 = required length
;   r0 preserved or error (buffer overflow)
;
CopyStrToBuffer ROUT
        Entry   "r3"
        ; Calculate required length
        MOV     r3, #0
10
        LDRB    lr, [r0, r3]
        ADD     r3, r3, #1
        CMP     lr, #32
        BHS     %BT10
        ; Check
        CMP     r1, #&4000 ; Basic sanity test
        CMPHS   r2, r3
        MOV     r2, r3
        BLO     %FT90
        ; Copy
        SUBS    r3, r3, #1
        MOV     lr, #0 ; Null terminate
        STRB    lr, [r1, r3]
        EXIT    EQ
20
        SUBS    r3, r3, #1
        LDRB    lr, [r0, r3]
        STRB    lr, [r1, r3]
        BNE     %BT20
        EXIT
90
        PullEnv
        ADR     r0, ErrorBlock_BuffOverflow
        B       CopyError

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In:
;   r0 -> source value
;   r1 -> destination buffer, or 0 just to check length
;   r2 = buffer length
;   r3 = source length
;   r12 = SoundRMA
;
; Out:
;   Buffer updated if length sufficient
;   r2 = required length
;   r0 preserved or error (buffer overflow)
;
CopyDataToBuffer
        ALTENTRY
        ; Check
        CMP     r1, #&4000 ; Basic sanity test
        CMPHS   r2, r3
        MOV     r2, r3
        BLO     %BT90
        ; Copy
        B       %BT20

; Special-case CopyDataToBuffer for copying the sample rate list
CopySampleRatesToBuffer
        ALTENTRY
        ; Check
        CMP     r1, #&4000 ; Basic sanity test
        CMPHS   r2, r3
        MOV     r2, r3
        BLO     %BT90
        ; Copy
30
        SUBS    r3, r3, #4
        ASSERT  AudioRateTableSize = 8
        ASSERT  AudioRateTable_Frequency = 0
        LDR     lr, [r0, r3, LSL #1]
        STR     lr, [r1, r3]
        BNE     %BT30
        EXIT

        MakeInternatErrorBlock BuffOverflow,,BufOFlo

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

Initialise_Module Entry "r7, r8, r10, r11"

        LDR     r2, [r12]
        TEQ     r2, #0
        BNE     %FT00 ; (should probably make sure workspace is right size!)

        LDR     r3, =WorkSpaceSize
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        EXIT    VS

        STR     r2, [r12]

00      LDR     r10, =SoundLevel0Base
        MOV     r12, r2
        STR     r2, [r10, #SoundRMA]    ; keep separate record of RMA area base
        MOV     r0, #0
05
        SUBS    r3, r3, #4
        STR     r0, [r2, r3] ; clear RMA workspace to 0
        BNE     %BT05
        MOV     r5, r2

  [ TimingCode
        Push    "r9"
        MOV     r0, #TimingTimer
        MOV     r8, #OSHW_CallHAL
        MOV     r9, #EntryNo_HAL_TimerMaxPeriod
        SWI     OS_Hardware
        STR     r0, [r5, #TimeMaxPeriod]
        MOV     r1, r0
        MOV     r0, #TimingTimer
        MOV     r9, #EntryNo_HAL_TimerSetPeriod
        SWI     OS_Hardware
        MOV     r0, #TimingTimer
        MOV     r9, #EntryNo_HAL_TimerGranularity
        SWI     OS_Hardware
        STR     r0, [r5, #TimeGran]
        MOV     r8, #OSHW_LookupRoutine
        MOV     r9, #EntryNo_HAL_TimerReadCountdown
        SWI     OS_Hardware
        STR     r0, [r5, #TimeFunc]
        STR     r1, [r5, #TimeWS]
        Pull    "r9"
  ]

; Zero DMA buffer
        LDR     r4, =SoundDMABuffers
        ADD     r14, r4, #SoundDMABufferSize * 2
        MOV     r0, #0
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
10      STMIA   r4!, {r0-r3}
        STMIA   r4!, {r0-r3}
        STMIA   r4!, {r0-r3}
        STMIA   r4!, {r0-r3}
        CMP     r4, r14
        BLT     %BT10

; Get physical address of sound buffer 0.  This is fixed at a single
; value on both MEMC1 and MEMC2 systems, but variable (obtained via new
; SWI) on IOMD systems.  The logical address is fixed (at &01F06000) on
; all systems.

        LDR     r2, =SoundDMABuffers    ; fixed logical address of 2 soundbuffers
        SUB     sp, sp, #12             ; get temp space for a single-entry Page Block
        STR     r2, [sp, #1*4]          ; write addr into l.a. slot of page block
        MOV     r1, sp                  ; point at Page Block as SWI arg
        MOV     r2, #1                  ; 1 entry to update
        MOV     r0, #&2200              ; convert log address to phys address
        SWI     XOS_Memory              ; go do the conversion
        LDR     r1, [sp, #2*4]          ; pick up physical address into R1
        ADD     sp, sp, #12             ; release temp space
        EXIT    VS                      ; ought never to fail!
        MOV     r0, #0                  ; Semaphore ON (so reenable wakens it)
        ADD     r1, r1, #SoundDMABufferSize
        ADRL    r2, ProtoS0S            ; address sound0segment prototype
        LDMIA   r2, {r2,r3,r4,r5,r6,r7,r8}; load it up (from Buff0 onwards)
        STMIA   r10, {r0-r8}            ; Set up Sound0Segment, first 9 words

        ADD     r0, r10, #Images        ; address user-level image positions
        BL      ConvImages              ; convert to compact version for prog'ing
        STR     r0, [r10, #ImagesC_N]   ; compacted form, into top of pipeline
        STR     r0, [r10, #ImagesC_H]   ; and for next buffer

        ; Build device list
        BL      Initialise_DeviceList

        ; Set up DMA (+ select default device)
        BL      Initialise_DMA
 [ UseNEON
        ; Get our VFPSupport context
        BLVC    Initialise_NEON
 ]
        BVS     %FT90

        ; go fetch 16-bit sound control info from CMOS
        MOV     r0, #161                ; CMOS read OSBYTE
        MOV     r1, #PrintSoundCMOS     ; get extended (VIDC20) sound bits
        SWI     XOS_Byte                ; "won't" fail

; R2 is byte from CMOS
; bit 7 is quality bit (do interpolation to maximise quality)
; bit 6:5  form 16-bit sound control value (VIDC20 specific, irrelevant to us)
        TST     r2, #&80                ; Extract oversample setting
        ORRNE   r4, r4, #OversampleFlag :SHL: 24

; Get stereo reverse flag from HAL device
        LDR     r2, [r12, #HALDevice]
        LDR     lr, [r2, #HALDevice_Version]
        CMP     lr, #2:SHL:16
        LDRGE   lr, [r2, #HALDevice_AudioFlags]
        ASSERT  AudioFlag_StereoReverse = 1
        ASSERT  DoReverse = &20
        ANDGE   lr, lr, #AudioFlag_StereoReverse
        ORRGE   r4, r4, lr, LSL #5+24

        STR     r4, [r10, #Config]      ; store config, with correct flags in

20      MOV     r0, r4, LSR #24         ; get log2nchan + flags byte
        AND     r0, r0, #3              ; get log2nchan alone into r0
        LDR     r1, [r10, #SoundRMA]
      [ :LNOT: UseNEON
        ADD     r1, r1, #LinConvCode    ; get address to put code
      ]
        MOV     r2, #SCSoundGain        ; set up default soundgain value
        STRB    r2, [r10, #SoundGain]
        STRB    r2, [r10, #SoundGain_C]
        LDR     r2, [r10, #ImagesC_H]   ; address stereo position set
        STR     r2, [r10, #ImagesC_C]   ; mark as current set
        STRB    r0, [r10, #Log2nchan_C] ; do same for log2nchan
        ORR     r2, r2, #SCSoundGain :SHL: 24 ; combine default soundgain into r2
        BL      compile                 ; go call compiler to set it all up
30
        MOV     r6, r4, LSL #16         ; build 16-bit Length (in sample times)
        MOV     r6, r6, LSR #16
        MOV     r7, r4, LSR #24         ; build LogChannel count in r7
        AND     r7, r7, #3
        MOV     r6, r6, LSL r7          ; build DAG End (i.e. length in bytes) in r6

        MOV     r0, r7                  ; r0:= log2(channels)
        MOV     r1, r4, LSL #16         ; r1 = samples per buffer
        MOV     r1, r1, LSR #16
        MOV     r2, r4, LSR #16         ; 8-bit period
        AND     r2, r2, #&FF
        MOV     r3, #0
        MOV     r4, #0
        SEI     SVC32_mode              ; IRQ off please
        BL      Sound0InitConfig        ; Configure sample rate & buffer size, taking into account any constraints
        BL      Sound0Reenable          ; Turn on system
        CLI     SVC32_mode              ; Reenabled IRQs
        BVS     %FT90                   ; May fail, e.g. RTSupport unavailable

        MOV     r0, #Service_SoundLevel0Alive
        MOV     r1, #Service_Sound
        SWI     XOS_ServiceCall
        CLRV
        EXIT

90
        ; We can't initialise for some reason
        ; Shutdown everything and throw an error
        Push    "r0"
        BL      Finalise_Device ; Also shuts down DMA
      [ UseNEON
        BL      Finalise_NEON
      ]
        BL      close_messagefile
        Pull    "r0"
        SETV
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Module_RTSupport
        = "RTSupport", 0
Module_DMAManager
        = "DMAManager", 0
 [ UseNEON
Module_VFPSupport
        = "VFPSupport", 0
 ]
        ALIGN

;Ursula format
;
; We need to use service calls to watch out for the following events:
; * Init/finalisation of RTSupport
; * Init/finalisation of DMAManager (if required by HAL device)
; * Init/finalisation of HAL device
 [ UseNEON
; * Init/finalisation of VFPSupport
 ]
; If any of the above die, we release the relevant resources, and make sure
; sound is disabled. If the service then becomes available again, without any
; intermediate calls to Sound_Enable, we automatically re-enable sound output
; to ensure a simple *RMEnsure of an updated module doesn't result in sound
; being left off
       ASSERT   Service_Hardware < Service_ModulePostInit 
       ASSERT   Service_ModulePostInit < Service_ModulePostFinal
;
UServTab
        DCD     0
        DCD     UService - Module_Base
        DCD     Service_Hardware
        DCD     Service_ModulePostInit
        DCD     Service_ModulePostFinal
        DCD     0
        DCD     UServTab - Module_Base
Intercept_Services ROUT
        MOV     r0,r0
        TEQ     r1,#Service_Hardware
        TEQNE   r1,#Service_ModulePostInit
        TEQNE   r1,#Service_ModulePostFinal
        MOVNE   PC,LR
UService
        Entry   "r0,r2-r6,r10"
        LDR     r12, [r12]
        TEQ     r1,#Service_Hardware
        BEQ     UService_Hardware
        ; Which module is this?
        ADR     r0, Module_RTSupport
        ADR     r3, PostFinal_RTSupport
        BL      strcmp_branch
        ADR     r0, Module_DMAManager
        ADR     r3, PostFinal_DMAManager
        BL      strcmp_branch
      [ UseNEON
        ADR     r0, Module_VFPSupport
        ADR     r3, PostFinal_VFPSupport
        BL      strcmp_branch
      ]
UService_Exit
        CLRV
        EXIT

UService_Hardware ROUT
        CMP     r0, #1
        BHI     UService_Exit
        ; Only pay attention to audio controller devices
      [ UseLDRSH
        LDRH    r4, [r2, #HALDevice_Type]
      |
        LDR     r4, [r2, #HALDevice_Type]
        MOV     r4, r4, LSL #16
        MOV     r4, r4, LSR #16
      ]
        LDR     r3, =HALDeviceType_Audio :OR: HALDeviceAudio_AudC
        CMP     r4, r3
        BNE     UService_Exit
        ; Is the API version suitable?
        LDR     lr, [r2, #HALDevice_Version]
        CMP     lr, #(MaxDeviceVersion+1):SHL:16
        BHS     UService_Exit
        CMP     lr, #MinDeviceVersion:SHL:16
        BLO     UService_Exit
        ; Device has passed our initial sanity checks - process for addition/removal
        CMP     r0, #1        
        BLO     %FT50
        ; Device stopping. Is it our sound device?
        LDR     r0, [r12, #HALDevice]
        CMP     r0, r2
        BNE     %FT10
        LDR     r10, =SoundLevel0Base
        BL      PostFinal_DisableSound ; Disable sound, set reenable flag
        LDRB    r0, [r12, #ReenableFlag] ; Preserve flag (device release will indirectly clobber it via Sound0Enable)
        BL      Finalise_Device ; Release device
        STRB    r0, [r12, #ReenableFlag]
10
        ; Remove from device list if present there
        FRAMLDR r2 ; Corrupted by PostFinal_DisableSound above
        BL      DeviceList_Remove
        B       UService_Exit

50
        ; Device starting. Add to device list.
        BL      DeviceList_Add
        BVS     UService_Exit
        ; Are we looking for a sound device?
        LDR     r2, [r12, #HALDevice]
        CMP     r2, #0
        BNE     UService_Exit
        ; Does it work? (r0 = new device list entry)
        BL      TryInitialise_Device
        BVS     UService_Exit
        ; Yes; turn sound back on if necessary
        LDR     r10, =SoundLevel0Base
        ADR     lr, UService_Exit
        B       Try_Reinit
        

strcmp_branch   ROUT
        ; Case-sensitive comparison of r0 with r2
        ; Returns if strings differ
        ; Else branches to Try_Reinit if module is initialising, or r3 if module finalising
        ; r0,r4-r6 corruptible
        MOV     r4, r2
10
        LDRB    r5, [r4], #1
        LDRB    r6, [r0], #1
        CMP     r5, r6
        MOVNE   pc, lr
        CMP     r5, #0
        BNE     %BT10
        ADR     lr, UService_Exit ; Go straight to service exit on return
        LDR     r10, =SoundLevel0Base ; Set up for Sound0Enable calls (sigh)
        CMP     r1, #Service_ModulePostFinal
        BNE     Try_Reinit
        MOV     pc, r3

        ; r0, r2-r6 corruptible in following routines
        ; r10 = SoundLevel0Base
        ; r12 = SoundRMA

PostFinal_RTSupport ROUT
        ; Only need to disable if RTSupport is in use
        LDR     r0, [r12, #RTSup_Handle]
        CMP     r0, #0
        MOVEQ   pc, lr
PostFinal_DisableSound ; Corrupts r0,r2-r4
        ; Ensure sound off
        MOV     r3, lr
        MOV     r0, #1
        PHPSEI  r2
        LDRB    r4, [r12, #ReenableFlag] ; Get flag before we call Sound0Enable (as Sound0Enable will clear it)
        BL      Sound0Enable
        PLP     r2
        ORR     r4, r4, r0, LSR #1 ; Set flag if sound was on, preserve otherwise
        STRB    r4, [r12, #ReenableFlag]
        MOV     pc, r3

PostFinal_DMAManager ROUT
        ; Are we actually using DMAManager?
        LDR     r0, [r12, #DMAChannel]
        MOVEQ   pc, lr
        ; Ensure sound is off
        ; (We should have received a DMACompleted callback, which would have
        ; triggered a SoundDiedFunc OS callback, but if DMAManager is dying that
        ; callback won't have happened yet. Luckily we're in the foreground
        ; here, so we can cancel the callback and stop sound now.)
        MOV     r5, lr
        BL      PostFinal_DisableSound
        ; Forget our DMA channel handle
        MOV     r0, #0
        STR     r0, [r12, #DMAChannel]
        MOV     pc, r5

 [ UseNEON
PostFinal_VFPSupport ROUT
        ; VFPSupport issues Service_ModulePostFinal from within its finalisation code, allowing us to clean up properly
        ; Ensure sound is off
        MOV     r5, lr
        BL      PostFinal_DisableSound
        ; Release our VFPSupport context
        BL      Finalise_NEON
        ; Done!
        MOV     pc, r5
 ]        

Try_Reinit ROUT
        ; Try reinitialising sound if appropriate
        ; In: r10 = SoundLevel0Base, r12 = SoundRMA
        ; Out: r0 = error
        ;      Corrupts r3
        LDRB    r3, [r12, #ReenableFlag]
        Debug   swi,"Try_Reinit: flag=", r3
        CMP     r3, #0
        MOVEQ   pc, lr
        Entry   "r0,r5,r11"
        ; Initialise device
        BL      Initialise_Device
        FRAMSTR r0, VS
        EXIT    VS
        ; Re-enable sound
        MOV     r0, #2
        PHPSEI  r5
        BL      Sound0Enable
        PLP     r5
        MOVVC   r3, #0 ; Something else might still be dead; only clear flag on success
        Debug   swi,"Try_Reinit: new flag=", r3
        STRB    r3, [r12, #ReenableFlag]
        FRAMSTR r0, VS
        EXIT

RemoveCallbacks ROUT
        ; Remove any pending sound reset/died callbacks
        ; In: r12 = SoundRMA
        Entry   "r0,r1"
        ADRL    r0, SoundResetFunc
        MOV     r1, r12
        SWI     XOS_RemoveCallBack
        ADRL    r0, SoundDiedFunc
        SWI     XOS_RemoveCallBack
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable, r10 = fatality indication

Finalise_Module Entry "r10, r11"

        LDR     r12, [r12]

        LDR     r10, =SoundLevel0Base

        MOV     r0, #Service_SoundLevel0Dying
        MOV     r1, #Service_Sound
        SWI     XOS_ServiceCall         ; Can't stop me!

; Shutdown the audio device (also stops sound, releases DMA)
        BL      Finalise_Device

; Free device list
        BL      Finalise_DeviceList

      [ UseNEON
; Release the VFP context
        BL      Finalise_NEON
      ]

        BL      close_messagefile

        CLRV
        EXIT                            ; Don't refuse to die


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


 [ UseNEON
Initialise_NEON ROUT
        ; Ensure we have a VFPSupport context and that NEON is available
        ; In: r12 = SoundRMA
        ; Out: Error on failure, else all regs preserved
        Entry   "r0-r4"
        LDR     r0, [r12, #VFPSup_Context]
        CMP     r0, #0
        EXIT    NE
        ; Check that VFPSupport + NEON is available
        MOV     r0, #VFPSupport_Features_SystemRegs
        SWI     XVFPSupport_Features
        BVS     %FT10
        ; Check FPSID for VFPv3+
        TST     r0, #&700000 ; These bits are set for non-ARM subarchitecture, or VFPv1
        BNE     %FT10
        TST     r0, #&0e0000 ; These bits are zero for VFPv1/v2
        ; Must be VFPv3+, with MVFR0/MVFR1 available. Check MVFR1 for NEON
        TSTNE   r2, #&f000
        BEQ     %FT10
        ; Get the FastAPI routines
        SWI     XVFPSupport_FastAPI
        STRVC   r0, [r12, #VFPSup_WS]
        STRVC   r4, [r12, #VFPSup_ChangeCtx]
        ; Create a context
        MOVVC   r0, #0
        MOVVC   r1, #32
        MOVVC   r2, #0
        MOVVC   r3, #0
        SWIVC   XVFPSupport_CreateContext
        STRVC   r0, [r12, #VFPSup_Context]
        STRVS   r0, [sp]
        EXIT
10
        ADR     r0, ErrorBlock_VFPSupport_NoHW2
        BL      CopyError
        STR     r0, [sp]
        SETV
        EXIT

        MakeInternatErrorBlock VFPSupport_NoHW2,,M05

Finalise_NEON ROUT
        ; Release our VFPSupport context
        ; In: r12 = SoundRMA
        ; Out: Error on failure, else all regs preserved
        ; Sound must be off!
        Entry   "r0-r1"
        LDR     r0, [r12, #VFPSup_Context]
        CMP     r0, #0
        EXIT    EQ
        MOV     r1, #0
        STR     r1, [r12, #VFPSup_Context] ; Even if we fail, we want to forget the old context
        SWI     XVFPSupport_DestroyContext
        STRVS   r0, [sp]
        EXIT
 ]

TryInitialise_Device ROUT
        ; Try initialising the given audio device
        ; In: r0 -> device list entry
        ;     r12 = SoundRMA
        ; Out: V clear -> OK
        ;      V set, R0 -> error
        Entry   "r0-r5,r8-r12"
        LDR     r4, [r0, #DeviceList_AudioDevice]
        Debug   swi,"TryInitialise_Device",r4
        ; Try to activate it
        MOV     r5, r12 ; r5 becomes SoundRMA
        MOV     r0, r4
        MOV     lr, pc
        LDR     pc, [r4, #HALDevice_Activate]
        CMP     r0, #0                  ; successful?
        BEQ     %FT90 ; Go back and look for another
        ; Else device is good, use it
        LDR     r0, [r4, #HALDevice_Device]
        STR     r4, [r5, #HALDevice]
        STR     r0, [r5, #Sound_device]
        ; Update our stereo reverse flag
        LDR     r8, =SoundLevel0Base
        LDRB    r9, [r8, #Flags]
        BIC     r9, r9, #DoReverse
        LDR     lr, [r4, #HALDevice_Version]
        CMP     lr, #2:SHL:16
        LDRGE   lr, [r4, #HALDevice_AudioFlags]
        ASSERT  AudioFlag_StereoReverse = 1
        ASSERT  DoReverse = &20
        ANDGE   lr, lr, #AudioFlag_StereoReverse
        ORRGE   r9, r9, lr, LSL #5
        STRB    r9, [r8, #Flags]
      [ SupportSoftMix
        ; Update software mix setting
        FRAMLDR lr,,r0 ; Can't FRAMLDR within the Push block
        Push    "r0-r3"
        LDR     r0, [lr, #DeviceList_SoftMixDevice]
        CMP     r0, #0
        LDRNE   r2, [r0, #SoftMixMute]
        LDRNE   r3, [r0, #SoftMixGain]
        MOVEQ   r2, #0 ; Set to 0 gain if software mix not required
        MOVEQ   r3, #0
        BL      SoftMixDev_Apply
        Pull    "r0-r3"
      ]
        ; Claim its vector and enable interrupts
        MOV     r8, #OSHW_CallHAL
        CMP     r0, #-1
        BEQ     %FT08
        ADR     r1, Module_VectorCode
        LDR     r2, =SoundLevel0Base
        SWI     XOS_ClaimDeviceVector
        BICVC   r0, r0, #1:SHL:31
        MOVVC   r9, #EntryNo_HAL_IRQEnable
        SWIVC   XOS_Hardware
        BVS     %FT80
08
        STRB    r8, [r5, #ResetPending] ; Allow reset callbacks to be registered

        ; If HALSRIndex is -1, it means we previously lost a device and this is the new device that's replacing it
        ; Checking HALSRIndex is important in order to avoid trying to reprogram the first device we find during module init (that happens later on during startup)
        LDR     r0, [r5, #HALSRIndex]
        CMP     r0, #-1
        BNE     %FT70
        ; We need to reset our buffer size & sample rate to work with this new device
        ; Scan sample rate table for closest match to previous rate
        LDR     r1, [r4, #HALDevice_AudioNumRates]
        LDR     r0, [r4, #HALDevice_AudioRateTable]
        ASSERT  AudioRateTableSize = 8
        ASSERT  AudioRateTable_Frequency = 0
        ADD     r0, r0, r1, LSL #3
        LDR     r2, [r5, #CurSRValue]
10
        LDR     r3, [r0, #-AudioRateTableSize]!
        CMP     r3, r2
        CMPHI   r1, #1
        SUBHI   r1, r1, #1
        BHI     %BT10
        ; Set rate
        ; Note - must be done via Sound0Config, as this will also cause buffer size to be verified against device limits
        LDRB    r2, [r0, #AudioRateTable_Period-AudioRateTable_Frequency]
        MOV     r0, #0
        MOV     r1, #0
        MOV     r3, #0
        MOV     r4, #0
        LDR     r10, =SoundLevel0Base
        PHPSEI  r5
        Debug   swi,"TryInitialise_Device switching to sample period ",r2
        LDR     r8, [r10, #Semaphore]
        MOV     r9, #&80000000
        STR     r9, [r10, #Semaphore] ; Ensure semaphore set to prevent Sound_Enable calls from within Sound_Config
        BL      Sound0Config
        STR     r8, [r10, #Semaphore]
        PLP     r5
70
        Debug   swi,"TryInitialise_Device OK"
        CLRV    ; Clobbers error from Sound0Config - is this wise?
        EXIT
80
        ; Something bad happened; release vector and shutdown device
        STR     r0, [sp]
        MOV     r12, r5 ; Restore WS ptr
        BL      Finalise_Device
        SETV
        EXIT

90
        PullEnv
        ADR     r0, ErrorBlock_BadSoundDevice
        SETV
        B       CopyError

Initialise_Device ROUT
        ; Search for and initialise a HAL audio device
        ; In: r12 = SoundRMA
        ; Out: Error on failure, else all regs preserved
        Entry   "r0-r2,r8"
        LDR     r0, [r12, #HALDevice]
        CMP     r0, #0
        EXIT    NE
        ; Look through our device list for a device which will initialise OK
        LDR     r1, [r12, #DeviceList]
10
        MOVS    r0, r1
        BNE     %FT20
        ADR     r0, ErrorBlock_NoSoundDevices
        BL      CopyError
        SETV
        B       %FT15
20
        BL      TryInitialise_Device
        EXIT    VC
        LDR     r1, [r1, #DeviceList_Next]
        TEQ     r1, #0
        BNE     %BT10 ; Try next device if there is one, else return this error        
15
        STR     r0, [sp]
        EXIT

        MakeInternatErrorBlock NoSoundDevices,,M04
        MakeInternatErrorBlock BadSoundDevice,,M06 ; TODO should be generic OS error?

Finalise_Device ROUT
        ; Disable sound and release the HAL device (+ DMA)
        ; In: r12 = SoundRMA
        ; Out: Error on failure, else all regs preserved
        Entry   "r0-r5,r12"
        LDR     r0, [r12, #HALDevice]
        CMP     r0, #0
        EXIT    EQ
        Debug   swi,"Finalise_Device",r0
        ; Check for any pending reset callbacks
        PHPSEI  r5, r0
        BL      RemoveCallbacks
        MOV     r0, #1
        STRB    r0, [r12, #ResetPending] ; Avoid any further callback registrations
        BL      Sound0Enable            ; Ensure sound off
        PLP     r5                      ; Reenable IRQs
        ; Release the IRQ handler
        ADR     r1, Module_VectorCode
        LDR     r2, =SoundLevel0Base
        LDR     r0, [r12, #Sound_device]
        CMP     r0, #-1
        SWINE   XOS_ReleaseDeviceVector ; release device vector
        ; Release the DMA channel
        BL      Finalise_DMA
        ; Deactivate the device
        LDR     r0, [r12, #HALDevice]
        MOV     r1, #0
        STR     r1, [r12, #HALDevice]
        MOV     r1, #1
        STR     r1, [r12, #CurSRIndex] ; claim we're using first SR index (while we have no device, we only report that we support one rate)
        MVN     r1, #0
        STR     r1, [r12, #HALSRIndex] ; and flag that we should reprogram the device upon re-registration
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_Deactivate] ; remember this corrupts r12
        CLRV
        EXIT                            ; Don't refuse to die        

Initialise_DMA ROUT
        ; Register with DMAManager (+ find/init HAL device)
        ; In: r12 = SoundRMA
        ; Out: Error on failure, else all regs preserved
        Entry   "r0-r7"
        LDR     r0, [r12, #DMAChannel]
        CMP     r0, #0
        EXIT    NE
        BL      Initialise_Device ; We need to know which channel to use
        BVS     %FT10
        ; Does this device need DMAManager?
        LDR     r7, [r12, #HALDevice]   
        LDR     r0, [r7, #HALDevice_Version]
        CMP     r0, #2:SHL:16 ; API 2+?
        LDRHS   r0, [r7, #HALDevice_AudioCustomDMAEnable]
        CMPHS   r0, #1 ; With AudioCustomDMAEnable?
        EXIT    HS
        ; Register with DMAManager
        LDR     r7, [r12, #HALDevice]   
        ADD     r7, r7, #HALDevice_AudioDMAParams
        ADD     r4, r12, #DMARoutines ; Use our DMA routines
        ADR     r0, DMAEnable
        ADR     r1, DMADisable
        ADR     r2, DMAStart
        ADR     r3, DMACompleted
        ADR     lr, DMASync
        STMIA   r4,{r0-r3,lr}
        LDMIA   r7, {r0,r1,r2,r3,r7} ; Get remaining DMA_RegisterChannel params
        MOV     r5, r12
        SWI     XDMA_RegisterChannel
        STRVC   r0, [r12, #DMAChannel]
        EXIT    VC
10
        STR     r0, [sp]
        EXIT        

Finalise_DMA
        ; Deregister with DMAManager
        ; In: r12 = SoundRMA
        ; Out: Error on failure, else all regs preserved
        ; Sound must be disabled!
        Entry   "r0"
        LDR     r0, [r12, #DMAChannel]
        CMP     r0, #0
        EXIT    EQ
        SWI     XDMA_DeregisterChannel
        STRVS   r0, [sp]
        MOV     r0, #0
        STR     r0, [r12, #DMAChannel] ; Forget handle even if we failed?
        EXIT

Initialise_RTSupport
        ; Register with RTSupport
        ; In: r12 = SoundRMA
        ; Out: Error on failure, else all regs preserved
        Entry   "r0-r7"
        LDR     r1, [r12, #HALDevice]
        LDR     r0, [r1, #HALDevice_Version]
        CMP     r0, #3:SHL:16 ; API 3+?
        MOVLO   r0, #0
        LDRHS   r0, [r1, #HALDevice_AudioFlags]
        TST     r0, #AudioFlag_Synchronous ; Don't need RTSupport if device is happy with synchronous processing
        LDREQ   r0, [r12, #RTSup_Handle]
        CMPEQ   r0, #0
        EXIT    NE
        MOV     r0, #0
        ADRL    r1, RTSup_Code
        MOV     r2, r12 ; R0 gets SoundRMA
        LDR     r3, =SoundLevel0Base ; R12 gets SoundLevel0Base
        MOV     r4, r12
        STR     r0, [r4, #RTSup_Pollword]!
        MOV     r5, #0 ; R10 is buffer index to fill
        MOV     r6, #0 ; No SYS stack needed
        ADR     r7, RTSup_Prio
        SWI     XRT_Register
        STRVC   r0, [r12, #RTSup_Handle]
        STRVS   r0, [sp]
        EXIT

Finalise_RTSupport
        ; Deregister with RTSupport
        ; In: r12 = SoundRMA
        ; Out: Error on failure, else all regs preserved
        Entry   "r0-r1"
        LDR     r1, [r12, #RTSup_Handle]
        CMP     r1, #0
        EXIT    EQ
        MOV     r0, #0
        STR     r0, [r12, #RTSup_Handle]
        SWI     XRT_Deregister
        STRVS   r0, [sp]
        EXIT

RTSup_Prio
        = "AudioFill:192",0
        ALIGN

        LTORG
        

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        SUBT    Sound DMA Module Interrupt Service Routine and DMA handlers
        OPT     OptPage

Module_VectorCode
        ; IRQ from audio controller. Find out what's up!
        ; r12 = SoundLevel0Base
        ; r0-r3, r12 trashable
        Entry   "r4,r8-r9"
        ; Drop into SVC mode so we can call SWIs
        SetMode SVC32_mode,,,I32_bit
        Push    "lr"
        LDR     r4, [r12, #SoundRMA]
        LDR     r0, [r4, #HALDevice]
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_AudioIRQHandle]
        CMP     r0, #1
        LDREQB  r1, [r4, #ResetPending]
        CMPEQ   r1, #0
        BNE     %FT10
        ADR     r0, SoundResetFunc
        MOV     r1, r4
        SWI     XOS_AddCallBack
        MOVVC   r0, #1
        STRVCB  r0, [r4, #ResetPending]
10
        LDR     r0, [r4, #Sound_device]
        MOV     r8, #OSHW_CallHAL
        MOV     r9, #EntryNo_HAL_IRQClear
        BIC     r0, r0, #1:SHL:31
        SWI     XOS_Hardware
        ; Back to IRQ
        Pull    "lr"
        SetMode IRQ32_mode,,,I32_bit
        EXIT

SoundResetFunc
        ; r12 = SoundRMA
        Entry   "r0-r1"
        MOV     r0, #1
        SWI     XSound_Enable
        ; Sound (should) be disabled now, so clear reset flag
        MOV     r1, #0
        STRB    r1, [r12, #ResetPending]
        EXIT    VS
        CMP     r0, #1 ; Only re-enable if we were enabled to start with
        MOVNE   r0, #2
        SWINE   XSound_Enable
        EXIT

SoundDiedFunc
        ; r12 = SoundRMA
        ; Disable sound and update the reenable flag
        Entry   "r0,r2-r4,r10"
        LDR     r10, =SoundLevel0Base
        BL      PostFinal_DisableSound
        EXIT
        

; DMAManager callbacks
; For each of these routines:
; r12 = SoundRMA

DMAStart
        CLRV
DMAEnable
DMADisable
        MOV     pc, lr

DMACompleted
        Entry   "r0-r1"
        ; Forget our DMA tag
        MOV     r1, #0
        STR     r1, [r12, #DMATag]
        EXIT    VC
        ; Something bad happened
        ; This is most likely DMAManager about to die on us
        ; We might not be able to stop sound output from here, so set a callback
        SetModeSEI SVC32_mode,,r2 ; Switch to SVC with IRQs off
        Push    "r2,lr"
        ; Prevent any new reset attempts
        MOV     r0, #1
        STRB    r0, [r12, #ResetPending]
        ; Cancel any existing callbacks
        BL      RemoveCallbacks
        ; Now register new callback
        ADR     r0, SoundDiedFunc
        MOV     r1, r12
        SWI     XOS_AddCallBack
        Pull    "r2,lr"
        MSR     CPSR_c, r2
        ; TODO - Make a note of the error so we can report it sometime later?
        EXIT

DMASync
        ; Wake up our RTSupport routine
        Entry
        ; Atomic increment of pollword
        PHPSEI  r0
        LDR     lr, [r12, #RTSup_Pollword]
        ADD     lr, lr, #1
        STR     lr, [r12, #RTSup_Pollword]
        PLP     r0
        MOV     r0, #0
        EXIT

; Custom DMA callback (asynchronous)
; On entry:
;  r0 = reason (reserved, should be 0)
;  r1 = SoundRMA
;  SWI-safe privileged mode, IRQ status undefined
; On exit:
;  r0-r3, r12 corrupted
CustomDMASync_Async
        ; Wake up our RTSupport routine
        Entry
        ; Atomic increment of pollword
        PHPSEI  r0
        LDR     r2, [r1, #RTSup_Pollword]
        ADD     r2, r2, #1
        STR     r2, [r1, #RTSup_Pollword]
        PLP     r0
        CMP     r2, #1 ; Just woken up?
        EXIT    NE
        ; Try yielding, we may have been called from foreground
        MOV     r1, pc ; Any non-zero pollword will do
        SWI     XRT_Yield
        EXIT        

; Custom DMA callback (synchronous)
; On entry:
;  r0 = bit 0: buffer index to fill
;       other bits: reserved (should be 0)
;  r1 = SoundRMA
;  SWI-safe privileged mode, IRQ status undefined
; On exit:
;  r0-r3, r12 corrupted
CustomDMASync_Sync
        Entry   "r4-r11"
        MOV     r11, r1
        MRS     r9, CPSR
        LDR     r12, =SoundLevel0Base
        MOV     r1, #1
        ADR     lr, %FT10 ; Return address needs to be specified for mode r9
        AND     r10, r0, #1
        SetModeSEI IRQ32_mode
        B       RTSup_Sync ; Exits with PSR = r9
10
        EXIT

RTSup_Code      ROUT
        ; Called with:
        ;  R0 = SoundRMA
        ;  R10 = Next buffer to fill
        ;  R12 = SoundLevel0Base
        ;  R13 = zero!
        ;  SYS mode, IRQs enabled
        ; Exit with:
        ;  R0 = flags (0)
        ;  R10 updated
        ;  SYS mode
        ;  R1-R9, R11, R12, R14_svc corrupt
        ; Guaranteed to not be re-entered 

        MOV    r11, r0
        MRS    r9, CPSR
        MOV    r0, #0
        ; Switch into IRQ mode with IRQs disabled
        SetModeSEI IRQ32_mode
        ; Check pollword to see how many buffers need filling
        LDR    r1, [r11, #RTSup_Pollword]
        CMP    r1, #8
        ANDHS  r1, r1, #1 ; Skip ahead if we get too far behind with DMA
        STR    r0, [r11, #RTSup_Pollword]
        ; Any work to do?
        CMP    r1, #0
        BEQ    RTSup_Exit
RTSup_Sync
        ; In:
        ; R1 = fill count
        ; R9 = return PSR
        ; R10 = Next buffer to fill
        ; R11 = SoundRMA
        ; R12 = SoundLevel0Base
        ; IRQ mode, IRQs disabled
        Push   "r9,r14"

 [ UseNEON
        ; Enable our VFP context
        Push    "r1,wp"
        LDR     r12,[r11,#VFPSup_WS]
        LDR     r0,[r11,#VFPSup_Context]
        MOV     r1,#0
        MOV     lr,pc
        LDR     pc,[r11,#VFPSup_ChangeCtx]
        ; Assume it succeeded!
        Pull    "r1,r14"
        Push    "r0" ; Remember old context
 |
        MOV    r14, wp
 ]

RTSup_Loop        
        ; Preserve crucial regs (fill count, next buffer)
        EOR    r12, r10, #1
        Push   "r1,r12"

; Level0Swap

; IRQ mode, IRQs disabled
; r0-r10  free
; r11     SoundRMA
; r12     Buffer flag
; r13     IRQ stack
; r14     SoundLevel0Base

; Level0 Go

 ASSERT Phys1     = 4  ; r5
 ASSERT Buff0     = 8  ; r6
 ASSERT Buff1     = 12 ; r7
 ASSERT Config    = 16 ; r8
 ASSERT Level1Ptr = 20 ; r9
 ASSERT Images    = 24 ; r10, r11 NB. Two words
        LDMIB   r14, {r5-r9}            ; Sound0Segment params, skip semaphore
        TST     r12, #1
        MOVNE   r12, r6                 ; we fill the opposite
        MOVEQ   r12, r7
        MOV     r6, r8                  ; get config (incl. flags) in r6
        MOV     r0, r6, LSR #24         ; get configured log2nchan & flags
        AND     r0, r0, #3              ; mask out just current req'd log2nchan
        LDRB    r1, [r14, #Log2nchan_C] ; pick up current value in use
        CMP     r0, r1                  ; if different, mark update for Level1
        ORRNE   r6, r6, #1 :SHL: 31     ; by setting sign bit in r6
        STRNEB  r0, [r14, #Log2nchan_C] ; and also update log2nchan

        LDRB    r1, [r14, #SoundGain_C] ; get current value of mu-law->linear conv gain
        LDRB    r2, [r14, #SoundGain]   ; get last-set value
        CMP     r2, r1                  ; check if different, and if so mark fact...
        ORRNE   r6, r6, #1 :SHL: 31     ; ..by setting sign bit in r6
        STRNEB  r2, [r14, #SoundGain_C] ; and also update recorded value

        ; Handle 16-bit mode conversion routine re-compile if needed.  NB we
        ; change the compiled code directly on THIS interrupt, rather than
        ; with a one-buffer delay as is applied when updating the hardware.
        ; This is because the stereo positioning is already dealt with in the
        ; data put into the buffer, rather than when the buffer is read out
        ; (after next interrupt) by the hardware.
        ; Get currently required log2nchan value + flags

        ; Check whether any stereo position value has changed.
        ; Shuffle ImagesC FIFO first, since there is no buffer delay for
        ; software stereo
        LDR     r2, [r14, #ImagesC_N]   ; get wanted value of ImagesC
        STR     r2, [r14, #ImagesC_H]   ; (force skipping of 1-buffer delay)
        LDR     r1, [r14, #ImagesC_C]   ; check current value of ImagesC
        CMP     r2, r1                  ; check for being the same
        BNE     %FT55                   ; go recompile if different

        ; No change in stereo, but check whether number of active channels has
        ; changed, => recompile needed.  This was tested above, and marked in bit
        ; 31 of r6, so it's easy to re-check.  This bit may alternatively/also
        ; indicate change of soundgain value, with same consequence.
        TST     r6, #1 :SHL: 31
        BEQ     %FT65                   ; no re-compilation needed if bit 31 clear

55      ; Compile for updated configuration/stereo position/soundgain value.
        STR     r2, [r14, #ImagesC_C]   ; record req'd ImagesC value as current
        LDRB    r1, [r14, #SoundGain_C] ; pick up newest soundgain value
        ORR     r2, r2, r1, LSL #24     ; and combine into r2
      [ :LNOT: UseNEON
        ADD     r1, r11, #LinConvCode   ; address code buffer in SoundRMA workspace
      |
        MOV     r1, r11
      ]
        MOV     r4, r14
        BL      compile                 ; go compile it (R0 = log2nchan)
        MOV     r14, r4                 ; (reset local vars pointer after BL)
65  ; Reprogram ASD, if required

        ! 0, "TODO - Reimplement sample rate pipelining (to cope with HW DMA double buffering etc.)"
        ; if delta values change, need to set bit 31 of r6?

; level0 MEMC update

70

80

; Level0Updated - any events to dispatch?
   [ TimingCode
        Push    "r0-r4,r9,r12,r14"
        LDR     r4,[r14,#SoundRMA]
        GetTime r4
        LDR     r1,[r4,#TimeTemp0]
        STR     r0,[r4,#TimeTemp0] ; Time at last total update
        STR     r0,[r4,#TimeTemp1] ; Time at level 2 update
        LDR     r2,[r4,#TimeTotal]
        SUBS    r0,r1,r0
        LDRLT   r1,[r4,#TimeMaxPeriod]
        ADDLT   r0,r0,r1
        ADD     r2,r2,r0
        STR     r2,[r4,#TimeTotal]
        Pull    "r0-r4,r9,r12,r14"
   ]

        Push    "r8-r12, r14"           ; r1-r7 preserved by scheduler
        LDR     r12, [r14, #Level2Ptr]
        TST     r12, #SoundSystemNIL    ; test for installed scheduler
        LDREQ   r0, [r12]
        TSTEQ   r0, #SoundSystemNIL     ; Valid Level2?
        MOVEQ   lr, pc
        MOVEQ   pc, r0                  ; Call Level2
        SEI     IRQ32_mode              ; Don't trust it to preserve IRQ state
        Pull    "r8-r12, r14"

   [ TimingCode
        Push    "r0-r4,r9,r12,r14"
        LDR     r4,[r14,#SoundRMA]
        GetTime r4
        LDR     r1,[r4,#TimeTemp1]
        LDR     r2,[r4,#TimeLevel2]
        SUBS    r0,r1,r0
        LDRLT   r1,[r4,#TimeMaxPeriod]
        ADDLT   r0,r0,r1
        ADD     r2,r2,r0
        STR     r2,[r4,#TimeLevel2]
        Pull    "r0-r4,r9,r12,r14"
   ]

; Level0 ready to fill

        MOV     r11, r6, LSR #24        ; get log2nchan + flags
        TST     r11, #DoOversample      ; 16-bit: check for oversampling
        MOVEQ   r11, #2                 ; 4 bytes/sample if no o/s
        MOVNE   r11, #3                 ; but 8 bytes/sample if o/s
81
        AND     r11, r11, #3            ; get just log2nchan
        MOV     r10, r6, LSL #16        ; get logical buffer length/channel
        MOV     r10, r10, LSR #16       ; (16 bits worth)
        MOV     r4, r10, LSL r11        ; work out physical length into r4
        BIC     r4, r4, #&F             ; must be a multiple of 16
        MOV     r10, r4, LSR r11        ; may need to adjust logical buffer len
        MOV     r4, r10, LSL #2         ; work out physical length into r4 (Fs*1, 16-bit stereo)
        MOV     r11, r6, LSR #24        ; get back real log2nchan (asking for 8bit data)
        AND     r11, r11, #3
        ADD     r10, r12, r10, LSL r11  ; r10 = logical buffer end
        MOV     r0, #1                  ; convert log to buffer inc
        MOV     r11, r0, LSL r11        ; r11 = N channels

82      ; Convert mu-law N-channel data in logical buffer to 16-bit stereo physical data

        TST     r9, #SoundSystemNIL     ; Valid Level1? Loaded only once, above
        MOVNE   r3, #0                  ; if not, mark no valid data in physical buffer
        BNE     %FT86                   ;         and go do 16-bit handling

        STMFD   sp!, {r4,r6,r10,r12,r14} ; save off physlen, config, logend, buffstart, ws

   [ TimingCode
        Push    "r9,r12"
        LDR     r4,[r14,#SoundRMA]
        GetTime r4
        STR     r0,[r4,#TimeTemp1]
        Pull    "r9,r12"
   ]

        CLI     IRQ32_mode              ; enable IRQs

        ; Zap the logical buffer to 0 before calling level 1 code to fill it.
        ; This is necessary for compatibility, since the standard channel
        ; handler assumes that any channel which is silent will have 0 data in
        ; its entries in the logical buffer.  But since we overwrite the
        ; logical data with 16-bit physical data after filling it, this will
        ; not hold in general.  So fill the logical buffer with all 0 now.
        ;
        ; KJB - surely better to have separate logical and physical buffers?
        ; maybe not - more cache thrashing?

    [ :LNOT: UseNEON
        MOV     r0, #0
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        MOV     r8, r12

        ; Zero 4*8 words = 128 bytes each loop.  Slightly overrunning the
        ; logical buffer end is not a problem, and since the physical
        ; buffers are a multiple of 128 bytes in length, we won't overrun
        ; those either.

84      STMIA   r8!, {r0-r7}
        STMIA   r8!, {r0-r7}
        STMIA   r8!, {r0-r7}
        STMIA   r8!, {r0-r7}
        CMP     r8, r10
        BLO     %BT84
    |
        ARM ; Avoid UAL syntax warnings
        VMOV.I32   Q0, #0
        VMOV.I32   Q1, #0
        VMOV.I32   Q2, #0
        VMOV.I32   Q3, #0
        MOV        r8, r12
84      VSTMIA     r8!, {Q0-Q3} ; 64 bytes at once
        VSTMIA     r8!, {Q0-Q3}
        CMP        r8, r10
        BLO        %BT84
        CODE32
    ]

        SEI     IRQ32_mode              ; IRQs off again

        ; Call Level1: don't change mode, flags

        LDR     r6, [sp, #4]            ; reload config value, including update flag r6:31
        MOV     r8, r6, LSR #16         ; get current per-channel period in r8,
        AND     r8, r8, #&FF            ; for Level1 fill code

   [ TimingCode
        LDR     r14,[sp,#16]
        Push    "r9,r12"
        LDR     r4,[r14,#SoundRMA]
        GetTime r4
        LDR     r1,[r4,#TimeTemp1]
        LDR     r2,[r4,#TimeNuke]
        STR     r0,[r4,#TimeTemp1]
        SUBS    r0,r1,r0
        LDRLT   r1,[r4,#TimeMaxPeriod]
        ADDLT   r0,r0,r1
        ADD     r2,r2,r0
        STR     r2,[r4,#TimeNuke]
        Pull    "r9,r12"
   ]

        MOV     lr, pc
        LDR     pc, [r9, #SoundLevel1FillPtr]
        SEI     IRQ32_mode              ; Don't trust it to preserve IRQ state

        LDMFD   sp, {r4,r6,r10,r12,r14} ; restore saved values. NB leave on stack: no `!'

   [ TimingCode
        Push    "r0-r4,r9,r12,r14"
        LDR     r4,[r14,#SoundRMA]
        GetTime r4
        LDR     r1,[r4,#TimeTemp1]
        LDR     r2,[r4,#TimeLevel1]
        STR     r0,[r4,#TimeTemp1]
        SUBS    r0,r1,r0
        LDRLT   r1,[r4,#TimeMaxPeriod]
        ADDLT   r0,r0,r1
        ADD     r2,r2,r0
        STR     r2,[r4,#TimeLevel1]
        Pull    "r0-r4,r9,r12,r14"
   ]

        ; Convert mu-law to 16-bit linear data.
        ; have: physical length in r4,
        ;       logical buffer end in r10
        ;       logical buffer start in r12
        ; want: r10 and r12 as they are,
        ;       r11 = physical buffer start or end, according to logical buffer size
 [ :LNOT: UseNEON
        ;       r9 = address of 256-entry mu-law to 16-bit conversion table
        ;       r8 = &FF for byte masking in conversion routine
        ;       r5 = &7FFF for overflow test
        TST     r6, #2 :SHL: 24         ; 4 or 8 channels in use?
        MOV     r8, #&FF                ; set up byte mask used in routine
        MOVNE   r11, r12                ; write 16-bit data forwards from start if so
        ADDEQ   r11, r12, r4            ; else write 16-bit data backwards from phys buff end
        ADRL    r9, convtable           ; address conversion table for routine to use
        ORR     r5, r8, #&7F00          ; and also mask for limit check
        LDR     r0, [r14, #SoundRMA]    ; go get RMA space address
        MOV     r7, #&70000003          ; put impossible 16-bit output value in r7
   [ UseLDRSH
        MOV     r8, r8, LSL #1          ; Must use mask of 0x1fe in r8
   ]
        CLI     IRQ32_mode              ; enable IRQs
        Push    pc                      ; set up return address
        ADD     pc, r0, #LinConvCode    ; call conversion code
        NOP

        SEI     IRQ32_mode              ; IRQs off again

        LDMFD   sp!, {r4,r6,r10,r12,r14}; again restore values, clearing stack this time

        CMP     r7, #&70000003          ; if impossible value still in r7, all data was 0
        MOVNE   r3, #1                  ; mark that there is valid (non-0) data in buffer
        MOVEQ   r3, #2                  ; else mark that 16-bit data in buffer is all 0
 |
        TST     r6, #2 :SHL: 24         ; 4 or 8 channels in use?
        LDR     r0, [r14, #SoundRMA]    ; go get RMA space address
        MOVNE   r11, r12                ; write 16-bit data forwards from start if so
        ADDEQ   r11, r12, r4            ; else write 16-bit data backwards from phys buff end
        BL      MuLawNEON_code
        LDMFD   sp!, {r4,r6,r10,r12,r14}; again restore values, clearing stack this time
 ]

   [ TimingCode
        Push    "r0-r4,r9,r12,r14"
        LDR     r4,[r14,#SoundRMA]
        GetTime r4
        LDR     r1,[r4,#TimeTemp1]
        LDR     r2,[r4,#TimeMuLaw]
        STR     r0,[r4,#TimeTemp1]
        SUBS    r0,r1,r0
        LDRLT   r1,[r4,#TimeMaxPeriod]
        ADDLT   r0,r0,r1
        ADD     r2,r2,r0
        STR     r2,[r4,#TimeMuLaw]
        Pull    "r0-r4,r9,r12,r14"
   ]

86      ; We're now dealing with a physical buffer containing 16-bit stereo
        ; data (it will still contain old data from last time, if no level 1
        ; handler is present).  Check whether there is a 16-bit sound
        ; generator/mixer, and if so, call it.  Note that r3 determines
        ; whether there is valid 16-bit data in the buffer already:
        ;
        ;     0 => old/invalid (*must* overwrite) - jumped here directly, no level 1 handler
        ;     1 => yes, valid, not all 0, but may overwrite to ignore
        ;     2 => yes, and known to be all 0, so can simply return if silent

        LDR     r5, [r14, #SoundRMA]    ; address RMA workspace
        LDR     r11, [r5, #Lin16Gen]    ; pick up code address
        LDR     r0, [r5, #Lin16GenR0]   ; pick up paramter to pass it in r0
        MOV     r1, r12                 ; pass base of buffer in r1
        ADD     r2, r12, r4             ; and end of buffer in r2
        CMP     r11, #0                 ; check for valid entry, if so.....
        STMFD   sp!, {r1,r2,r14}        ; save base/limit for oversampler below
        BEQ     %FT87
        LDR     r4, [r5, #CurSRValue]   ; load up current frequency value into r4

        MOV     lr, pc                  ; and go call
        MOV     pc, r11

   [ TimingCode
        LDR     r14,[sp,#8]
        Push    "r2-r4,r9,r12"
        LDR     r4,[r14,#SoundRMA]
        GetTime r4
        LDR     r1,[r4,#TimeTemp1]
        LDR     r2,[r4,#TimeLinear]
        STR     r0,[r4,#TimeTemp1]
        SUBS    r0,r1,r0
        LDRLT   r1,[r4,#TimeMaxPeriod]
        ADDLT   r0,r0,r1
        ADD     r2,r2,r0
        STR     r2,[r4,#TimeLinear]
        Pull    "r2-r4,r9,r12"
   ]

87
        LDMFD   sp, {r0,r1,r11}         ; reload (no pop) phys base & limit now

        CLI     IRQ32_mode              ; enable IRQs (watch out for r14)

        ; Finally, perform any post-processing required:
        ; * Mono mix-down
        ; * Oversampling
        ; * Stereo reversal
        ; * Software mixer (volume control)

        LDRB    r3, [r11, #Flags]
        ANDS    r3, r3, #DoFlags
        BEQ     BufferDone              ; nowt to do if all bits clear (r3 = 0)
        TEQ     r3, #DoReverse          ; just stereo reversal?
        BEQ     DoFunc_Reverse

        LDR     r7, [r11, #SoundRMA]

        ; OK, doing some sort of filtering operation.  Set up some constants
        ; used in all cases...
 [ :LNOT: UseNEON :LAND: NoARMv6
        ; Set up 0x80008000 in r12, to perform signed/unsigned swap overs
        MOV     r12, #1<<15
        ORR     r12, r12, #1<<31

        ; Create 0xFFFEFFFE in r11 for masking off LSBs, to isolate LH and RH
        ; parts during parallel additions.
        MVN     r11, r12, ROR #15       ; can derive from r12 in one go!
 ]
        TST     r3, #DoOversample
        BEQ     %FT88                   ; below only needed for oversampling
        SUB     r2, r1, r0              ; determine phys length of buffer at Fs*1
        ADD     r2, r0, r2, LSL #1      ; and compute end of buffer at Fs*2
        STR     r2, [sp, #4]            ; store out for later use also
                                        ; switch to appropriate oversampling code
        LDR     r6, [r7, #SavedSample]  ; get saved sample in R6

88
      [ SupportSoftMix
        ASSERT  DoSoftMix = &40
      ]        
        ASSERT  DoReverse = &20
        ASSERT  DoMono = &10
        ASSERT  DoOversample = &08        
        ADD     pc, pc, r3, LSR #1          ; branch to right code
        NOP
        B       BufferDone              ; flags=0 (shouldn't happen)
        ; Build the rest of the table using a loop
        GBLA    doflags
        GBLS    dofunc
doflags SETA    DoOversample
        WHILE   doflags <= DoFlags
dofunc  SETS    "DoFunc"
     [ SupportSoftMix
       [ (doflags :AND: DoSoftMix) <> 0
dofunc  SETS    "$dofunc" :CC: "_SoftMix"
       ]
     ]
       ; Reverse flag can be ignored if mono flag present
       [ (doflags :AND: DoMono) <> 0
dofunc  SETS    "$dofunc" :CC: "_Mono"
       ELIF (doflags :AND: DoReverse) <> 0
dofunc  SETS    "$dofunc" :CC: "_Reverse"
       ]
       [ (doflags :AND: DoOversample) <> 0
dofunc  SETS    "$dofunc" :CC: "_Oversample"
       ]
        B       $dofunc
doflags SETA    doflags + DoOversample
        WEND
        

BufferDone	; return here after any buffer processing
                ; NOTE: May be in IRQ or SVC!
        SetModeSEI IRQ32_mode           ; redisable IRQs
	Pull	"r3,r4,r14"             ; pop phys base+real limit (@Fs*2 if oversampling)
	LDR	r6, [r4, #-4]		; pick up last sample pair from this buffer
	LDR	r11, [r14, #SoundRMA]	; address RMA area
	STR	r6, [r11, #SavedSample]	; save sample pair for possible oversampling next time

   [ TimingCode
        Push    "r12,r14"
        GetTime r10
        LDR     r1,[r11,#TimeTemp1]
        LDR     r2,[r11,#TimeMonoOversample]
        SUBS    r0,r1,r0
        LDRLT   r1,[r11,#TimeMaxPeriod]
        ADDLT   r0,r0,r1
        ADD     r2,r2,r0
        STR     r2,[r11,#TimeMonoOversample]
        Pull    "r12,r14"
   ]

        ; All done for this IRQ
        ; IRQ mode, IRQs disabled
        ; r11 = SoundRMA
        ; r14 = SoundLevel0Base
        Pull    "r1,r10" ; Recover fill count, next buffer
        SUBS    r1, r1, #1
        BNE     RTSup_Loop        

   [ UseNEON
        ; Restore previous VFP context
        Pull    "r0"
        MOV     r1, #0
        LDR     r12, [r11, #VFPSup_WS]
        MOV     lr, pc
        LDR     pc, [r11, #VFPSup_ChangeCtx]
   ]
        ; IRQ32 mode, IRQs disabled
        ; r10 = next buffer
        Pull    "r9,lr"
RTSup_Exit
        MSR     CPSR_c, r9 ; Restore correct CPU mode (SYS for RTSupport routine, or caller's mode for CustomDMASync_Sync)
        MOV     r0, #0
        MOV     pc, lr


;
; ConvImages
;
; Passed in a pointer in r0 to 8 bytes (Images), returns in r0 a word
; having bits 31:24 zero and with 24:0 being compacted image data for
; programming (8 x 3 bits, chan 0 in bits 2:0, 1 = MAX L, 7 =
; MAX R).  r1-r13 preserved.
ConvImages Entry r1
        ADD     r1, r0, #7              ; start with channel 7
        MOV     r0, #0                  ; initialise output in r0
10      LDRB    lr, [r1], #-1           ; get one byte
        CMP     lr, #&E0                ; convert from linear pos to SIR value
        ADDLT   lr, lr, #&10
        MOVS    lr, lr, LSR #5
        MOVEQ   lr, #1                  ; correct for min
        MOV     r0, r0, LSL #3          ; shift previous values left one channel pos
        ORR     r0, r0, lr              ; merge in this channel into bottom
        TST     r0, #7 :SHL: (7*3)      ; shifted channel 7 value into place yet?
                                        ; (all output values are 1..7, i.e. not 0)
        BEQ     %BT10                   ; go round again if not
        EXIT                            ; all done, go home

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CopyError Entry r1-r7
        BL      open_messagefile
        EXIT    VS
        ADD     R1, R12, #MessageFile_Block
        MOV     R2, #0
        MOV     R4, #0
        MOV     R5, #0
        MOV     R6, #0
        MOV     R7, #0
        SWI     XMessageTrans_ErrorLookup
        EXIT

message_filename
        DCB     "Resources:$.Resources.SoundDMA.Messages", 0
        ALIGN

open_messagefile Entry r0-r2
        LDR     r0, [r12, #MessageFile_Open]
        CMP     r0, #0
        EXIT    NE
        ADD     R0, r12, #MessageFile_Block
        ADR     R1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        EXIT    VS
        MOV     r0, #1
        STR     r0, [r12, #MessageFile_Open]
        EXIT

close_messagefile Entry "r0"
        LDR     r0, [r12, #MessageFile_Open]
        CMP     r0, #0
        ADDNE   r0, r12, #MessageFile_Block
        SWINE   XMessageTrans_CloseFile
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 [ TimingCode
        MACRO
        WriteVal $name,$val
        SWI     OS_WriteS
        DCB     "$name",0
        ALIGN
      [ "$val" <> "r0"
        MOV     r0, $val
      ]
        MOV     r1, sp
        MOV     r2, #12
        SWI     OS_ConvertCardinal4
        SWI     OS_Write0
        SWI     OS_NewLine
        MEND

SoundTiming_Code
        Entry   "r0-r10", 12
        LDR     r12, [r12]
        LDR     r0, [r12, #TimeGran]
        ADD     r3, r12, #TimeTotal
        LDMIA   r3, {r4-r10} ; Grab times in one go to avoid IRQs updating them
        ASSERT  TimeLevel2 = TimeTotal+4
        ASSERT  TimeNuke = TimeTotal+8
        ASSERT  TimeLevel1 = TimeTotal+12
        ASSERT  TimeMuLaw = TimeTotal+16
        ASSERT  TimeLinear = TimeTotal+20
        ASSERT  TimeMonoOversample = TimeTotal+24
        WriteVal "Granularity: ",r0
        WriteVal "Total time: ",r4
        WriteVal "Level2 time: ",r5
        WriteVal "Nuke time: ",r6
        WriteVal "Level1 time: ",r7
        WriteVal "MuLaw time: ",r8
        WriteVal "Linear time: ",r9
        WriteVal "MonoOversample time: ",r10
        ; Now nuke the existing times
        MOV     r4,#0
        MOV     r5,#0
        MOV     r6,#0
        MOV     r7,#0
        MOV     r8,#0
        MOV     r9,#0
        MOV     r10,#0
        STMIA   r3, {r4-r10}
        EXIT        
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 [ debug
        InsertNDRDebugRoutines
 ]

 [ SupportSoftMix
        GET     s.SoftMix
 ]
        GET     s.DeviceList

        END

