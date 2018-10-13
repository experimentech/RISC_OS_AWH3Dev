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
        TTL     Sound System v3.0 -> <wini>arm.Sound1.Sound1

; *************************************************
; **                                             **
; **       ARTHUR Sound System Software          **
; **                                             **
; **    MODULE: SoundChannelHandler              **
; **            Level1 Sound System Module       **
; **                                             **
; **    AUTHORS: David Flynn (alas, no more)     **
; **             Stuart Swales (ditto)           **
; **             Tim Dobson                      **
; **                                             **
; **    DESCRIPTION: Multi-channel interface     **
; **                 plus Volume and Pitch       **
; **                 and Forground control       **
; **                                             **
; **    ENTRIES: SWIs for system level interface **
; **             CLI  commands interface         **
; **                                             **
; *************************************************

; 1.07  EPROM release
; 1.08  help text full-stops fixed
;       string copy bug in *channelvoice n <string> fixed
; 1.09  wasted bandwidth on null voices fixed
; 1.10  *volume 0 fix
; 1.11  IRQ latency fix for flush buffer code
; 1.12  Note Off/Note On/Update flags fix for MIDI and 255 duration
; 1.13  Fix dangling pointer on module first init
; 1.14  Clean up Overrun disgnostics
; 1.15  INIT problems
; 1.16  power-on initialisation fixes continue
; 1.17  FIX BUGS 239,305,310 (text messages/WRCH error..)
;       AND MAKE *TUNING relative and useful!
; 1.18  Tokenise help, remove init error
; 1.19  Turn IRQ off on SWI entry, fix InstallVoice problem
;       Fixed InstallNamedVoice
; ---- Released for Arthur 2.00 ----
; 1.19  Modified header GETs so they work again (doesn't affect object)
; 1.20  *Sound now allows 8 as channel number
; 1.21  Internationalised
; 1.22  27 Feb 92  OSS  Added ability to have localised voice names,
;                       but only for display purposes. It cannot be quoted
;                       at other SWIs/commands for setting channels etc.
; 1.23  16 Mar 92  OSS  Added ability to change local name to cope with
;                       RAM loading a localisation.
; 1.24  30 Mar 92  OSS  Fix bug - OS_Module extend r2 is amount to extend
;                       by and not new size as given in RO2 PRM!
; 1.25  09 Apr 92  SMC  Voice instantiation code now called when a voice is
;                       installed or removed for every channel it is assigned to.
; 1.26  09 Apr 92  SMC  Fixed register corruption in CheckAttachments (new in 1.25).
; 1.27  22 Apr 92  TMD  Removed wildcards from message filename (fixes RP-2371).
;       08-Feb-93  BC   Changed GETs to use Hdr: rather than &.Hdr.
;

        GET     Hdr:ListOpts
        OPT     OptNoList
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:PublicWS
        GET     Hdr:Proc
        GET     Hdr:CMOS
        GET     Hdr:Tokens
        GET     Hdr:MsgTrans
        GET     Hdr:Debug
        GET     Hdr:OSRSI6
        GET     Hdr:CPU.Arch

        OPT     OptList
        OPT     OptPage

        GET     Hdr:Sound
        GET     VersionASM

        GBLL    debug
debug   SETL    False

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Workspace layout

                ^       0, wp           ; Stored in claimed RMA block
MessageFile_Block #     16
MessageFile_Open  #     4
SoundSuppressAddr #     4               ; @FX210 flag
AutoTuneFlag      #     4               ; 0/1 for auto tuning
BuffersPer5cs     #     4               ; Number of buffer fills per 5 cs, 20.12 fixed point

; OSS Added array of pointers to local name for each voice. Note that
; element 0 is wastage as the array is accessed 1 to 32 in the same way
; as the voice array in the sound global workspace.
LocalNameArray  #       4 * (1 + MaxNVoices)

; Big tables go last
AmpTableSize    *       256
AmpTable        #       AmpTableSize

LogTableSize    *       8192
LogTable        #       LogTableSize

WorkSpaceSize   *       :INDEX: @

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        SUBT    Sound Channel Module Header
        OPT     OptPage

        AREA    |Sound1$$Code|, CODE, READONLY, PIC

Module_Base
        DCD     0 ; NOT AN APPLICATION
        DCD     Initialise_Module    - Module_Base
        DCD     Finalise_Module      - Module_Base
        DCD     Intercept_Services   - Module_Base
        DCD     Module_Name          - Module_Base
        DCD     Help_String          - Module_Base
        DCD     Module_Keywords      - Module_Base
        DCD     Module_SWISystemBase + Sound1SWI * Module_SWIChunkSize
        DCD     Sound_SWI_Code       - Module_Base
        DCD     Module_SWIDecodeBase - Module_Base
        DCD     0
 [ International_Help <> 0
        DCD     message_filename     - Module_Base
 |
        DCD     0
 ]
 [ :LNOT: No32bitCode
        DCD     ModuleFlags          - Module_Base
 ]

Module_Name
        DCB     "SoundChannels", 0

Help_String
        DCB     "SoundChannels"
        DCB     9
        DCB     "$Module_HelpVersion"
        DCB     0

Module_SWIDecodeBase
        DCB     "Sound",0
        DCB     "Volume",0
        DCB     "SoundLog",0
        DCB     "LogScale",0
        DCB     "InstallVoice",0
        DCB     "RemoveVoice",0
        DCB     "AttachVoice",0
        DCB     "ControlPacked",0
        DCB     "Tuning",0
        DCB     "Pitch",0
        DCB     "Control",0
        DCB     "AttachNamedVoice",0
        DCB     "ReadControlBlock",0
        DCB     "WriteControlBlock",0
        DCB     0

Module_Keywords
        DCB     "Volume", 0
        ALIGN
        DCD     Volume_Code   - Module_Base
        DCB     1,0,1,0:OR:(International_Help:SHR:24)                 ; 1 parameter
        DCD     Volume_Syntax - Module_Base
        DCD     Volume_Help   - Module_Base

        DCB     "Voices", 0
        ALIGN
        DCD     Voices_Code   - Module_Base
        DCD     0:OR:International_Help                       ; no parameters
        DCD     Voices_Syntax - Module_Base
        DCD     Voices_Help   - Module_Base

        DCB     "ChannelVoice", 0
        ALIGN
        DCD     Attach_Code   - Module_Base
        DCB     2,0,2,0:OR:(International_Help:SHR:24)                 ; 2 parameters
        DCD     Attach_Syntax - Module_Base
        DCD     Attach_Help   - Module_Base

        DCB     "Sound", 0
        ALIGN
        DCD     Sound_Code   - Module_Base
        DCB     4,0,4,0:OR:(International_Help:SHR:24)                 ; 4 parameters
        DCD     Sound_Syntax - Module_Base
        DCD     Sound_Help   - Module_Base

        DCB     "Tuning",0
        ALIGN
        DCD     Tuning_Code   - Module_Base
        DCB     1,0,2,0:OR:(International_Help:SHR:24)                 ; 1-2 parameters
        DCD     Tuning_Syntax - Module_Base
        DCD     Tuning_Help   - Module_Base

        DCB     "SoundDefault", 0
        ALIGN
        DCD     SoundDefault_Code   - Module_Base
        DCB     0,0,3,&40:OR:(International_Help:SHR:24)               ; 3 parameters, configuration bit
        DCD     SoundDefault_Syntax - Module_Base
        DCD     SoundDefault_Help   - Module_Base

        DCB     0                       ; No more entries

        GET     TokHelpSrc.s

        ALIGN

 [ :LNOT: No32bitCode
ModuleFlags
        DCD     1       ; 32-bit compatible
 ]
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

Volume_Code Entry

        LDR     wp, [r12]
        MOV     r1, r0
        MOV     r0, #10 + (2_100 :SHL: 29) ; No bad terminators please
        SWI     XOS_ReadUnsigned
        BVS     Bad_Parameter_Error
        MOVS    r0, r2                  ; 0 and >= 128 unacceptable
        CMPNE   r0, #128
        BHS     Bad_Parameter_Error

        SWI     XSound_Volume
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

Tuning_Code ALTENTRY

        LDR     wp, [r12]
        CMP     r1, #2
        BEQ     AutoTuning_Code
        MOV     r1, r0
        LDRB    r3, [r1]
        TEQ     r3, #"-"                ; signed?
        TEQNE   r3, #"+"
        ADDEQ   r1, r1, #1

        MOV     r0, #10 + (2_100 :SHL: 29) ; No bad terminators please
        SWI     XOS_ReadUnsigned
        BVS     Bad_Parameter_Error
        MOVS    r0, r2, LSR #14
        BNE     Bad_Parameter_Error

        TEQ     r3, #"-"                ; if it was -ve, invert now
        RSBEQ   r2, r2, #0

        Push    "r10,r11"
        MOV     r0, #0
        BL      SoundTuning             ; no need to call the SWI!
        CMP     r2, #0
        LDREQ   r0, =DefMasterPitch
        ADDNE   r0, r0, r2              ; offset by given amount
        BL      SoundTuning
        Pull    "r10,r11"
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

AutoTuning_Code
        LDW     r2, r0, r1, r3
        LDR     r1, =&4f545541
        LDR     r6, =&20202020
        BIC     r2, r2, r6
        CMP     r1, r2 ; 'AUTO'?
        BNE     Bad_Parameter_Error
        ADD     r0, r0, #4
10
        LDRB    r2, [r0], #1
        CMP     r2, #32
        BEQ     %BT10
        BLT     Bad_Parameter_Error
        LDRB    r3, [r0], #1
        CMP     r3, #32
        ORRGT   r2, r2, r3, LSL #8
        LDRGTB  r3, [r0], #1
        CMPGT   r3, #32
        ORRGT   r2, r2, r3, LSL #16
        LDRGTB  r3, [r0], #1
        CMPGT   r3, #32
        BGT     Bad_Parameter_Error
        BIC     r2, r2, r6
        MOV     r0, r1
        LDR     r3, OnStr
        CMP     r2, r3
        MOVEQ   r2, #2
        BEQ     %FT20
        LDR     r3, OffStr
        CMP     r2, r3
        BNE     Bad_Parameter_Error
        MOV     r2, #1
20
        MOV     r1, r2
        BL      SoundTuning
        EXIT    VS
        CMP     r0, r2
        EXIT    EQ
        ADR     r0, ErrorBlock_AutoTuningUnavailable
        B       ReturnError

OnStr
        DCB "ON",0,0
OffStr
        DCB "OFF",0

        MakeInternatErrorBlock AutoTuningUnavailable,,M08

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

; List the current voice allocation

Voices_Code ALTENTRY

        LDR     wp, [r12]               ; get workspace
        BL      message_writes
        DCB     "M03", 0
        SWIVC   XOS_NewLine
        EXIT    VS

        LDR     r6, =SoundLevel1Base + SoundLevel1VoiceTable
        ADD     r5, r6, #(SoundLevel1ChannelTable+SoundChannelVoiceIndexB)-SoundLevel1VoiceTable

        MOV     r4, #1                  ; voice ptr

10      LDR     r3, [r6, r4, LSL #2]
        CMP     r3, #0
        BEQ     %FT40                   ; if zero then ignore

        MOV     r2, #0

20      LDRB    r1, [r5, r2, LSL #SoundChannelCBLSL] ; check channels
        CMP     r1, r4                  ; voice assigned to this channel?
        MOVNE   r0, #" "
        ADDEQ   r0, r2, #"1"
        SWI     XOS_WriteC
        EXIT    VS
        ADD     r2, r2, #1
        CMP     r2, #SoundPhysChannels
        BLT     %BT20

        SWI     XOS_WriteI+" "
        SWIVC   XOS_WriteI+" "
        EXIT    VS

        CMP     r4, #9                  ; VClear
        SWILE   XOS_WriteI+" "          ; Extra space if less than 10

        SUB     sp, sp, #20
        MOVVC   r0, r4                  ; print voice no.
        MOVVC   r1, sp
        MOVVC   r2, #20
        SWIVC   XOS_ConvertInteger4
        SWIVC   XOS_Write0
        ADD     sp, sp, #20

        SWIVC   XOS_WriteI+" "
        SWIVC   XOS_WriteI+" "
        SWIVC   XOS_WriteI+" "

        LDRVC   r0, [r3, #SoundVoiceTitle] ; print voice title
        ADDVC   r0, r3, r0              ; make address
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        EXIT    VS

40      ADD     r4, r4, #1
        CMP     r4, #MaxNVoices
        BLE     %BT10

        BL      message_writes
        DCB     "M04", 0
        SWIVC   XOS_NewLine
        EXIT


Bad_Parameter_Error
        ADR     r0, ErrorBlock_BadSoundParameter

ReturnError ; For star commands

        BL      CopyError
        PullEnv
        SETV
        MOV     pc, lr

        MakeInternatErrorBlock BadSoundParameter,,M00

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

Attach_Code ALTENTRY

        LDR     wp, [r12]
        MOV     r1, r0
        MOV     r0, #10 + (2_100 :SHL: 29) ; No bad terminators please
        SWI     XOS_ReadUnsigned
        BVS     Bad_Parameter_Error

        CMP     r2, #0                  ; Ensure in 1..SoundPhysChannels
        CMPNE   r2, #SoundPhysChannels+1
        BHS     Bad_Channel_Error

        MOV     r3, r2                  ; preserve

        SWI     XOS_ReadUnsigned

        MOV     r0, r3                  ; channel no. wanted in either case
        BVS     %FT90

        MOV     r1, r2                  ; voice
        SWI     XSound_AttachVoice
        EXIT


90 ; Try string if number fails: enter with r1 -> string, r0 is channel

 [ debug
 DSTRING r1, "given named voice at cli level "
 ]
        SWI     XSound_AttachNamedVoice
        EXIT


Bad_Channel_Error
        ADR     r0, ErrorBlock_BadSoundChannel
        B       ReturnError

        MakeInternatErrorBlock BadSoundChannel,,M01

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

Sound_Code ALTENTRY

        LDR     wp, [r12]
        MOV     r1, r0
        MOV     r0, #10 + (2_100 :SHL: 29) ; No bad terminators please
        SWI     XOS_ReadUnsigned        ; read channel
        BVS     Bad_Parameter_Error

        CMP     r2, #0                  ; Ensure in 1..SoundPhysChannels
        CMPNE   r2, #SoundPhysChannels+1 ; *** TMD 24-Jan-90 - '+1' added
        BHS     Bad_Channel_Error
        MOV     r4, r2                  ; preserve

        SWI     XOS_ReadUnsigned        ; read amplitude
        MOVVC   r5, r2                  ; preserve

        SWIVC   XOS_ReadUnsigned        ; read pitch
        MOVVC   r3, r2                  ; preserve

        SWIVC   XOS_ReadUnsigned        ; read duration
        BVS     Bad_Parameter_Error

        Swap    r2, r3                  ; sort out regs
        MOV     r0, r4
        MOV     r1, r5
        SWI     XSound_Control
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = 0 for help
;            1 for status
;         else pointer to command tail

; Out   VSet and 0 for bad parameter error

SoundDefault_Code Entry "r0-r2"

        LDR     wp, [r12]
        CMP     r0, #0
        BNE     %FT10

        BL      message_writes
        DCB     "M05", 0
        SWIVC   XOS_NewLine

05      STRVS   r0, [sp]
        EXIT


10      CMP     r0, #1
        BNE     %FT20

        BL      message_writes
        DCB     "M06", 0
        ALIGN

        MOVVC   r0, #161                ; CMOS read OSBYTE
        MOVVC   r1, #SoundCMOS
        SWIVC   XOS_Byte
; R2 is 8 bit CMOS flags
; bit 7 is speaker on/off
; bit 6,5,4 is loudness
; bit 3,2,1,0 is default channel 0 voice
        MOVVC   r0, r2, LSR #7          ; speaker status
        ADDVC   r0, r0, #"0"
        SWIVC   XOS_WriteC
        SWIVC   XOS_WriteI+" "

        ANDVC   r0, r2, #2_01110000     ; loudness
        MOVVC   r0, r0, LSR #4
        ADDVC   r0, r0, #"0"
        SWIVC   XOS_WriteC
        SWIVC   XOS_WriteI+" "

        SUB     sp, sp, #32
        ANDVC   r0, r2, #&0F            ; channel 0 voice
        ADDVC   r0, r0, #1
        MOVVC   r1, sp
        MOVVC   r2, #32
        SWIVC   XOS_ConvertInteger1
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        ADD     sp, sp, #32
        B       %BT05


20      MOV     r1, r0                  ; text pointer to r1
        MOV     r0, #10 + (2_100 :SHL: 29) ; No bad terms, restrict range
        MOV     r2, #1
        SWI     XOS_ReadUnsigned        ; speaker status (0..1 allowed)
        MOVVC   r3, r2, LSL #7
        MOVVC   r0, #10 + (2_101 :SHL: 29) ; No bad terms, restrict range
        MOVVC   r2, #7
        SWIVC   XOS_ReadUnsigned        ; loudness (0..7 allowed)
        ORRVC   r3, r3, r2, LSL #4
        MOVVC   r2, #16
        SWIVC   XOS_ReadUnsigned        ; channel 0 voice (1..16 allowed)
        BVS     %BT05
        SUBS    r2, r2, #1
        BMI     %FT95                   ; [bad parm]

90      LDRB    r0, [r1], #1            ; make sure no junk on EOL
        CMP     r0, #" "
        BEQ     %BT90
        BHI     %FT95                   ; [bad parm]

        MOV     r0, #162                ; CMOS write OSBYTE
        MOV     r1, #SoundCMOS
        ORR     r2, r3, r2
        SWI     XOS_Byte
        B       %BT05


95      MOV     r0, #0                  ; Bad configure parameter
        SETV
        B       %BT05

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r10, r11 trashable
;       r12 = private word^

Sound_SWI_Code ROUT
        LDR     wp, [r12]
        Push    R14
        PHPSEI  R14, R10
        BL      Original_SWI_Code
        Pull    R14
        MOV     R10,#0
        MRS     R10,CPSR                ; NOP on pre-ARM6
        TST     R10,#2_11100            ; EQ if in 26-bit mode - C,V unaltered
        MOVNE   PC,R14                  ; 32-bit exit: NZ corrupted, CV passed back
        MOVVCS  PC,R14                  ; 26-bit exit: NZC preserved, V clear
        ORRVSS  PC,R14,#V_bit           ; 26-bit exit: NZC preserved, V set

Original_SWI_Code
        CMP     r11, #(EndOfJumpTable-JumpTable)/4
        ADDCC   pc, pc, r11, LSL #2
        MOV     pc, lr

JumpTable
        B       SoundVol     ; set master volume
        B       SoundLog     ; lin->log
        B       SoundScale   ; log amp scaling
        B       InstallVoice ; add/interogate entry
        B       RemoveVoice  ; deallocate voice
        B       AttachVoice  ; attach channel to voice
        B       SoundPacked  ; PACKED as OSWORD
        B       SoundTuning  ; pitch base
        B       SoundPitch   ; pitch conversion
        B       SoundControl ; UNPACKED version of OSWORD!
        B       AttachNamedVoice ; attach named voice if match found
        B       ReadWord
        B       WriteWord
EndOfJumpTable

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Set master volume (and build tables)

; In    r0 = new volume (MOD 128). 0 -> no change
;       r10, r11 trashable

; Out   r0 = old volume

SoundVol Entry

        LDR     r11, =SoundLevel1Base
        LDRB    r10, [r11, #SoundLevel1MaxAmp]

        AND     r0, r0, #&7F
        CMP     r0, #0
        STRNEB  r0, [r11, #SoundLevel1MaxAmp]
        BLNE    BuildLogTable

        ADDS    r0, r10, #0               ; return old, clears V
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Linear -> Log transform

; In    r0 is integer
;       r10, r11 trashable

; Out   r0 is log value scaled by current MaxAmp

SoundLog ROUT

        LDR     r11, =SoundLevel1Base
        LDR     r10, [r11, #SoundLevel1LogTable]

        LDRB    r0, [r10, r0, LSR #19]  ; 2's comp to index
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Log amplitude modulation

; In    r0b is log sample
;       r10, r11 trashable

; Out   r0  is log value scaled by current MaxAmp

SoundScale ROUT

        LDR     r11, =SoundLevel1Base
        LDR     r10, [r11, #SoundLevel1AmpTable]

        AND     r0, r0, #&FF            ; byte ONLY
        LDRB    r0, [r10, r0]           ; index includes sign
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = 0: return tuning value
;       r0 <> 0: new master pitch value (16-bit)
;       r0 = "AUTO" (&4f545541) to control auto tuning:
;          r1 = 0: read state
;          r1 = 1: disable auto tuning
;          r1 = 2: enable auto tuning
;       r10, r11 trashable
;       Does nothing if auto tuning is enabled

; Out   r0 <> "AUTO":
;            r0 = previous tuning value (1-&7fff)
;       r0 = "AUTO":
;            r0 = new auto tuning state (1=off, 2=on)
;            r1 = previous auto tuning value (1=off, 2=on)
;         or r0 = error, r1 = corrupt

SoundTuning ROUT
        LDR     r10,=&4f545541
        CMP     r10, r0
        BEQ     %FT10

        MOVS    r10, r0, ROR #16        ; mask to 16-bit, avoiding CMP r0, #0
        MOVNE   r10, r10, LSR #16

        LDRNE   r0,  AutoTuneFlag
        LDR     r11, =SoundLevel1Base
        CMPNE   r0,  #1
        LDR     r0,  [r11, #SoundLevel1MasterPitch]
        STRNE   r10, [r11, #SoundLevel1MasterPitch]
        MOV     pc, lr

10
        MOVS    r0, r1
        LDR     r1, AutoTuneFlag
        ADD     r1, r1, #1
        ; Just checking?
        MOVEQ   r0, r1
        ; New state matches old state?
        TEQNE   r0, r1
        MOVEQ   pc, lr
        Push    "r1-r4,lr"
        ; Disabling?
        SUBS    r10, r0, #1
        STREQ   r10, AutoTuneFlag
        MOVEQ   r10, #5<<12
        STREQ   r10, BuffersPer5cs
        BEQ     %FT90
        ; Attempting to enable auto tuning, and auto tuning currently disabled
        ; Must check if it's supported
        MOV     r0, #Sound_RSI_Features
        SWI     XSound_ReadSysInfo      ; See if SoundDMA notifies us of rate changes
        MOVVS   r1, #0
        CLRV
        TEQ     r0, #Sound_RSI_Features
        TSTNE   r1, #Sound_RSI_Feature_Service8910
        MOVEQ   r0, #1
        Pull    "r1-r4,pc",EQ
        ; Calculate initial values
        MOV     r0, #0
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        MOV     r4, #0
        SWI     XSound_Configure        ; Read selected bytes/channel
        Pull    "r1-r4,pc",VS
        MOV     r3, r1
        MOV     r4, r2
        MOV     r0, #0
        SWI     XSound_Mode             ; Check if 16 bit sound/Sound_SampleRate supported
        TEQ     r0, #1
        BNE     %FT40
        SWI     XSound_SampleRate       ; Read selected sample rate (r0=1)
        B       %FT50
40
        ; Sound_SampleRate not supported
        ; Calculate the sample rate from the sample period
        LDR     lr, =1024*1000000
        DivRem  r2, lr, r4, r1, norem
50
        STR     r0, AutoTuneFlag
        BL      AutoTune
        MOV     r0, #2 
90
        ; Issue service call to notify the rest of the sound system about the
        ; auto tuning state change
        Push    "r0"
        MOV     r2, r0
        MOV     r1, #Service_Sound
        MOV     r0, #Service_SoundAutoTune
        SWI     XOS_ServiceCall
        CLRV
        Pull    "r0-r4,pc"


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

;Sound_InstallVoice
;------------------

;Entry:  R0 -> voice generator to install
;        R1 = voice slot to install in (or 0 for first empty slot)
;Exit:   R0 -> name of previous voice
;        R1 = voice number allocated (or 0 for fail)

;Entry:  R0 = 0
;        R1 = slot number to interrogate
;Exit:   R0 -> name of voice
;        R1 = (preserved)

;New flavours
;------------
;Entry:  R0 = 1
;        R1 = voice slot to install in (or 0 for first empty slot)
;        R2 -> voice generator to install
;        R3 -> voice name in local language (data is copied so can vanish
;              as soon as the SWI has returned) or 0 for no local name
;Exit:   R0 = (preserved)
;        R1 = voice number allocated (or 0 for fail)
;        R2 -> name of previous voice
;        R3 = (preserved)

;Entry:  R0 = 2
;        R1 = slot number to interrogate
;Exit:   R0 = (preserved)
;        R1 = (preserved)
;        R2 -> name of voice
;        R3 -> name of voice in local language (gaurunteed none zero and
;              valid if R2 is none zero)

;Entry:  R0 = 3
;        R1 = voice slot to change local name of (0 not allowed)
;        R2 = 0 (this is required)
;        R3 -> new voice name in local language, replaces any peviously
;              specified or gives it a local name if none exists.
;Exit:   R0 = (preserved)
;        R1 = (preserved)
;        R2 = (preserved)
;        R3 = (preserved)

;       r10, r11 trashable

InstallVoice Entry

 [ debug
 DREG r0, "InstallVoice: r0 = ",cc
 DREG r1, ", r1 = ",,Integer
 ]
        LDR     r11, =SoundLevel1Base + SoundLevel1VoiceTable

        CMP     r1, #MaxNVoices
        BLE     installvoice1

        ADR     r0, ErrorBlock_IllegalVoice
        BL      CopyError
        EXIT

installvoice1
        TEQ     r1, #0                          ; If "next" slot then always
        BEQ     %FT50                           ; treat as install (Maestro
        TEQ     r0, #3                          ; does SYS Install 0,0)
        BEQ     install_change
        TEQ     r0, #0
        TEQNE   r0, #2
        BNE     installvoice2

; Inquiry  0 = old flavour 2 = give local name also

        LDR     r14, [r11, r1, LSL #2]          ; voice generator
        CMP     r14, #0
        MOVEQ   r10, #0
        LDRNE   r10, [r14, #SoundVoiceTitle]    ; voice title offset
        ADDNE   r10, r14, r10                   ; make address

        TEQ     r0, #0                          ; Old style interrogate
        MOVEQ   r0, r10                         ; so return name in R0
        EXIT    EQ

        MOV     r2, r10                         ; Name in R2 for new style
        ADRL    r3, LocalNameArray
        LDR     r3, [r3, r1, LSL #2]            ; Local name
        TEQ     r3, #0                          ; If no local name then
        MOVEQ   r3, r2                          ; return invariant name
        EXIT

installvoice2
        LDR     r14, [r11, r1, LSL #2]  ; check if any existing voice here
        CMP     r14, #0
        LDRNE   r0, [r14, #SoundVoiceTitle]     ; voice title offset
        ADDNE   r0, r14, r0                     ; make address
        BNE     %FT80                           ; fail if already allocated

40 ; insert here...

        TEQ     r0, #1
; OSS New flavour insert.
        MOVEQ   r0, r2                          ; voice in r2 for new style
        STR     r0, [r11, r1, LSL #2]           ; r0in - allocate voice
        BL      CheckAttachments                ; MUST PRESERVE FLAGS - actually only Z
        EXIT    NE
        MOV     r0, #1

; OSS Jumps to here to change an existing local name

install_change
        MOVS    r10, r3                         ; local name now in r10
        EXIT    EQ                              ; Give up if no local name

        MOV     r3, #0
42      LDRB    r14, [r10, r3]                  ; Count length of local name
        ADD     r3, r3, #1
        CMP     r14, #31                        ; <32 terminates
        BHI     %BT42

; r3 is length of new version - allocate or extend existing block

        MOV     r11, r2                         ; Need to preserve r2
        ADRL    r14, LocalNameArray
        LDR     r2, [r14, r1, LSL #2]           ; Get old pointer
        TEQ     r2, #0
        MOVEQ   r0, #ModHandReason_Claim        ; No old block so claim.
        BEQ     %FT45

        MOV     r0, #0
43      LDRB    r14, [r2, r0]                   ; Count length of old name
        ADD     r0, r0, #1
        CMP     r14, #31                        ; <32 terminates (0 actually)
        BHI     %BT43

; r0 is length of old block - calculate amount to extend by

        SUBS    r3, r3, r0
        BEQ     %FT46                           ; Optimise same size
        MOV     r0, #ModHandReason_ExtendBlock  ; Extend the old block
45
        SWI     XOS_Module
        BVS     %FT48
46
        ADRL    r14, LocalNameArray
        STR     r2, [r14, r1, LSL #2]           ; Store block in array

        MOV     r3, #-1                         ; Copy local name across
47      ADD     r3, r3, #1
        LDRB    r14, [r10, r3]                  ; Get char
        STRB    r14, [r2, r3]                   ; Store char
        CMP     r14, #31                        ; <32 terminates
        BHI     %BT47

        SUBS    r14, r14, r14                   ; R14=0, V cleared
        STRB    r14, [r2, r3]                   ; Null terminate our copy

; restore registers and exit
48      MOV     r3, r10
        MOVS    r2, r11                         ; set up Z - check voice point zero
        EXIT    VS

        MOVEQ   r0, #3                          ; It was a name change
        MOVNE   r0, #1                          ; It was an install
        EXIT


50 ; scan looking for first space to insert into
        MOV     r1, #1

60      LDR     r14, [r11, r1, LSL #2]
 [ debug
 DREG r1, "Voice ",cc,Integer
 DREG r14, " has module^ "
 ]
        CMP     r14, #0
        BEQ     %BT40

        ADD     r1, r1, #1
        CMP     r1, #MaxNVoices
        BLE     %BT60
80
        MOV     r1, #0
        EXIT

NullVoice
        DCB     "NullVoice", 0
        ALIGN                           ; Else can't ADR this one !

        MakeInternatErrorBlock IllegalVoice,,M07
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Go through all channels looking for voice we are about to install and attach
; the voice to each such channel.
; In:   r0 -> voice generator
;       r1 = voice number
; Out:  Preserve everything (especially flags) - well, only Z really
;
CheckAttachments Entry "r0-r5,r10"
        MOVEQ   r5, #0
        MOVNE   r5, #1
        MOV     r3, #SoundPhysChannels          ; start at last channel and work down to channel 1
        MOV     r4, r1
        LDR     r10, =SoundLevel1Base + SoundLevel1ChannelTable + SoundChannelVoiceIndexB - (1 :SHL: SoundChannelCBLSL)
10      LDRB    r2, [r10, r3, LSL #SoundChannelCBLSL]
        EORS    lr, r4, r2                      ; if this channel is using this voice
        STREQB  lr, [r10, r3, LSL #SoundChannelCBLSL] ; then zero the voice number for this channel
                                                ; (so we don't attempt to call free entry)
        MOVEQ   r0, r3                          ; and attach it again
        MOVEQ   r1, r4
        SWIEQ   XSound_AttachVoice
        SUBS    r3, r3, #1
        BNE     %BT10
        MOVS    r5, r5                          ; restore Z
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 is don't care
;       r1 is voice number 1-MaxNVoices for specified (0 for don't install)
;       r10, r11 trashable

; Out   r0 is String Pointer - name of Last Voice (or error message)
;       r1 is voice number de-allocated (0 for fail)

RemoveVoice Entry "r2-r3"

 [ debug
 DREG r1, "RemoveVoice: r1 = ",,Integer
 ]
        LDR     r11, =SoundLevel1Base + SoundLevel1VoiceTable

        CMP     r1, #0
        CMPNE   r1, #MaxNVoices+1
        BLO     removevoice0
        ADR     r0, ErrorBlock_IllegalVoice
        BL      CopyError
        EXIT

removevoice0
        LDR     r10, [r11, r1, LSL #2]  ; what's there ?
        CMP     r10, #0
        ADREQ   r0, NullVoice           ; [wasn't allocated]
        EXIT    EQ

        BL      CheckRemovals

; OSS De-allocate the local name in the RMA if present.

        MOV     r0, #ModHandReason_Free
        ADRL    r3, LocalNameArray
        LDR     r2, [r3, r1, LSL #2]
        TEQ     r2, #0
        SWINE   XOS_Module
        EXIT    VS

        LDR     r0, [r10, #SoundVoiceTitle] ; voice title offset
        ADD     r0, r10, r0
        MOV     r10, #0
        STR     r10, [r11, r1, LSL #2]  ; deallocate voice
        STR     r10, [r3, r1, LSL #2]   ; zero out local name
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; If a voice is removed then this is called to call the free entry of the
; voice for each channel which it is attached to.
; In:   r1 = voice number
; Out:  Preserve everything (except flags)
;
CheckRemovals   Entry "r0-r4,r10"
        MOV     r3, #SoundPhysChannels          ; start at last channel and work down to channel 1
        MOV     r4, r1
        LDR     r10, =SoundLevel1Base + SoundLevel1ChannelTable + SoundChannelVoiceIndexB - (1 :SHL: SoundChannelCBLSL)
10      LDRB    r2, [r10, r3, LSL #SoundChannelCBLSL]
        CMP     r4, r2
        BNE     %FT20
        MOV     r0, r3
        MOV     r1, #0
        SWI     XSound_AttachVoice                      ; detach the voice from this channel
        STRB    r4, [r10, r3, LSL #SoundChannelCBLSL]   ; but keep the voice number
20
        SUBS    r3, r3, #1
        BNE     %BT10
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 is channel number (1-8)
;       r1 is voice number (0 for DETACH)
;       r10, r11 trashable

; Out   r0 preserved if VClear
;       r1 is previous voice number allocated (0 for none/invalid)
;             0 indicates voice already allocated

AttachVoice Entry "r2, r5"

        LDR     r11, =SoundLevel1Base + SoundLevel1VoiceTable
        ADD     r10, r11, #(SoundLevel1ChannelTable+SoundChannelVoiceIndexB)-SoundLevel1VoiceTable

        SUB     r0, r0, #1              ; 0-7 from now on...check channel

        CMP     r0, #SoundPhysChannels
        addr    r0,ErrorBlock_BadSoundChannel, HS
        MOVHS   r1, #0
        BHS     %FA90

        MOV     r2, r1                  ; copy

; get last voice
        LDRB    r1, [r10, r0, LSL #SoundChannelCBLSL] ; *SoundChannelBlock size
        MOV     r14, #0                 ; mark detached
        STRB    r14, [r10, r0, LSL #SoundChannelCBLSL] ; *SoundChannelBlock size

        CMP     r2, #MaxNVoices         ; check voice number
        MOVHI   r1, #0
        BHI     %FA85                   ; [bad voice]

; detach last voice...
        LDR     r5, [r11, r1, LSL #2]   ; get voice pointer
        CMP     r5, #0                  ; not loaded?
        BEQ     %FT10                   ; then attach

        ADD     lr, pc, #4              ; just in case, points to the NOP
        Push    pc                      ; @%FT10 + bits - force detach
        ADD     pc, r5, #SoundVoiceFree ; call voice free, with r0=realChannel

; Attempt to instantiate voice for channel r0
	NOP
10      CMP     r2, #0                  ; just detach? return last if so
        STRNEB  r2, [r10, r0, LSL #SoundChannelCBLSL] ; * SoundChannelb size
        LDRNE   r5, [r11, r2, LSL #2]   ; get new voice pointer
        CMPNE   r5, #0                  ; not loaded?
        BEQ     %FT80                   ; exit

        MOV     r2, r0                  ; remember channel no
        ADD     lr, pc, #4              ; just in case, points to the NOP
        Push    pc                      ; @%FT20 + bits
        ADD     pc, r5, #SoundVoiceInst ; call voice inst, with R0=Channel

	NOP
20      CMP     r0, r2                  ; = if OK, changed if fail!
        SUBEQ   r10, r10, #SoundChannelVoiceIndexB ; if = then success
        ADDEQ   r10, r10, #SoundChannelFlagsB
        MOVEQ   r2, #SoundChannelForceFlush
        STREQB  r2, [r10, r0, LSL #SoundChannelCBLSL]
        BEQ     %FT80                   ; exit

        MOV     r0, r2                  ; mark channel failed to attach
        MOV     r2, #0                  ; and mark no voice...
        STRB    r2, [r10, r0, LSL #SoundChannelCBLSL]
        B       %FA85                   ; [bad voice]


80      ADDS    r0, r0, #1              ; renormalise channel no.
        EXIT                            ; VClear


85      ADR     r0, ErrorBlock_BadSoundVoice

90      BL      CopyError               ; Will set V
        PullEnv
        MOV     pc, lr

        MakeInternatErrorBlock BadSoundVoice,,M02

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 is channel number (1-8)
;       r1 is pointer to voice name string (CtrlChar terminated)
;       r10, r11 trashable

; Out   r0 preserved, or 0 for FAIL

AttachNamedVoice Entry "r1, r3-r5"

        CMP     r0, #0                  ; Ensure in 1..PhysChannels
        CMPNE   r0, #SoundPhysChannels+1
        addr    r0, ErrorBlock_BadSoundChannel, HS
        BHS     %FA90

; Do string search

15      LDRB    r14, [r1], #1           ; skip spaces here
        TEQ     r14, #" "
        BEQ     %BT15
        SUB     r5, r1, #1              ; r5 -> stripped string
 [ debug
 DSTRING r5, "given named voice "
 ]

        MOV     r10, #1                 ; start with voice 1
        LDR     r11, =SoundLevel1Base + SoundLevel1VoiceTable

10      LDR     r4, [r11, r10, LSL #2]  ; get pointer
        TEQ     r4, #0
        BEQ     %FT40

        LDR     r14, [r4, #SoundVoiceTitle]
        ADD     r4, r4, r14             ; point to name string
 [ debug
 DSTRING r4, "comparing against "
 ]

        MOV     r1, r5                  ; Restore stripped string^

20      LDRB    r3, [r1], #1            ; Make life easier for clients
        CMP     r3, #" "                ; (that includes our star command too!)
        MOVLS   r3, #0
        LDRB    r14, [r4], #1           ; compare strings
        CMP     r14, r3
        BNE     %FT40                   ; [fail, try next voice]
        CMP     r14, #0                 ; ended our string ?
        BNE     %BT20

        B       %FT50                   ; [attach by number, matched]


40      ADD     r10, r10, #1
        CMP     r10, #MaxNVoices
        BLE     %BT10

        MOV     r10, #0

50 ; r10 is voice number (maybe 0), r0 is valid channel, r1 is string pointer

        CMP     r10, #0                 ; Voice not found
        addr    r0, ErrorBlock_BadSoundVoice, EQ
        BEQ     %FA90

        MOV     r1, r10                 ; attach voice by number
        SWI     XSound_AttachVoice      ; r0 is still channel number
        PullEnv
        MOV     pc, lr                  ; V alreay set how we want it!

90      BL      CopyError               ; sets V
        PullEnv
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; R0,R1 are copy of OSWORD params
;       r10, r11 trashable

SoundPacked Entry "r0-r6"

        MOV     r3, r1, LSR #16 ; byte 7,8 to low R3
        MOV     r2, r1, LSL #16
        MOV     r2, r2, LSR #16 ; bytes 5,6 to low R2
        MOV     r1, r0, ASR #16 ; sign extend bytes 3,4 to R1
        MOV     r0, r0, LSL #16 ; bytes 0,1 in R0
        MOV     r0, r0, LSR #16
        B       SoundShared

; ..............................................................................
; R0 - R3 as packed SoundOSWORD?
;       r10, r11 trashable

SoundControl ALTENTRY


SoundShared ; channel processing

        AND     r4, r0, #&0F            ; r0b = channel number
        SUB     r4, r4, #1
        CMP     r4, #SoundPhysChannels
        EXIT    HS

 [ True
        LDR     r14, SoundSuppressAddr  ; @FX210 flag
        LDRB    r14, [r14]
        TEQ     r14, #0                 ; FX210 ~0 -> Nob off sound
        EXIT    NE
 ]

        LDR     r11, =SoundLevel1Base + SoundLevel1ChannelTable
        ADD     r6, r11, r4, LSL #SoundChannelCBLSL ; address

; r1 amp processing

        MOV     r4, r1, LSR #8
        ANDS    r4, r4, #&FF
        CMPNE   r4, #&FF
        BEQ     %FT10

        CMP     r4, #1                  ; my expansion
        BEQ     %FT20
        EXIT                            ; otherwise unrecognised

10 ; emulation of amp/(env !)

        MOV     r1, r1, LSL #16
        MOV     r1, r1, ASR #16         ; sign extend
        CMP     r1, #0
        EXIT    GT                      ; ENVELOPE!

        SUB     r1, r1, #1              ; 0000 => -1
        AND     r1, r1, #&0F            ; accept -1 to -16 (&F to &0)
        MOV     r1, r1, LSL #2 ; make 7 bit
        EOR     r1, r1, #&7F            ; convert to amp + GATE!
        MOVEQ   r1, #0                  ; but mute 0 amp!

20 ; expansion amp:
; 00000001GAAAAAAA
; where G is GATE
; AAAAAAA is 7-bit AMP
; coding...
; &100 , &180 = Gate Off
; &101 - &17F = Gate on + amp
; &181 - &1FF = Smooth Update

        AND     r4, r1, #&7F            ; amp
        STRB    r4, [r6, #SoundChannelAmpGateB]

30 ; r2 pitch
; IF < 256 THEN BBC emulation
; IF > &8000 then direct value to install
;            else 15-bit pitch
;  3-bit octave, 12-bit 1/4096 octave inc (8-bit significant!)
; &4000 is middle C nominally, normally!

        CMP     r2, #&8000
        BGE     %FT55
        CMP     r2, #256
        BGE     %FT50

        LDR     r4, =BBCPitchInc16              ; mul by note no.
        MUL     r5, r2, r4

        MOV     r5, r5, LSR #16                 ; renormalise
        LDR     r4, =BBCPitchBase
        ADD     r2, r5, r4                      ; pitch in r2


50      LDR     r11, =SoundLevel1Base
        LDR     r11, [r11, #SoundLevel1MasterPitch]
        ADD     r2, r2, r11
        MOV     r2, r2, ROR #12         ; octave to bottom 4 bits
        ADR     r4, PitchTab
        BIC     r2, r2, #&00FF0000      ; force to word index
        LDR     r4, [r4, r2, LSR #22]   ; get 32-bit frac
        EOR     r2, r2, #&1F            ; invert octave
        MOV     r2, r4, LSR r2          ; build


55      LDR     r4, [r6, #SoundChannelPitch]
        MOV     r4, r4, LSR #16         ; merge, preserving phase
        ORR     r2, r4, r2, LSL #16
        MOV     r2, r2, ROR #16
        STR     r2, [r6, #SoundChannelPitch]


60 ; duration. 0 will fall through...

        CMP     r3, #&FF                ; forever!
        MVNEQ   r3, #&80000000
        BEQ     %FT65

        LDR     r4, BuffersPer5cs
     [ NoARMM
        CMP     r3, #0 ; Shortcut for 0 duration, since this could take a while
        BEQ     %FT70
        MOV     r0, r3, LSR #16
        MOV     r2, r4, LSR #16
        BIC     r3, r3, r0, LSL #16
        BIC     r4, r4, r2, LSL #16
        MUL     r5, r0, r2 ; r3hi*r4hi
        MUL     lr, r3, r4 ; r3lo*r4lo
        MUL     r0, r4, r0 ; r3hi*r4lo
        MUL     r3, r2, r3 ; r3lo*r4hi
        ADDS    r0, r0, r3
        ADDCS   r5, r5, #1<<16
        ADDS    lr, lr, r0, LSL #16
        ADC     r5, r5, r0, LSR #16
     |
        UMULL   lr, r5, r3, r4
     ]
        ; Result in lr, r5
        CMP     r5, #1<<19 ; Should be 1<<20, but avoid setting top bit just in case
        MVNHS   r3, #&80000000 ; Forever
        MOVLO   r3, lr, LSR #12
        ORRLO   r3, r3, r5, LSL #20

65
        CMP     r3, #0
        
        STRNE   r3, [r6, #SoundChannelDuration]

70
        LDRB    r4, [r6, #SoundChannelFlagsB] ; mark as changed
        AND     r4, r4, #&1F
        TST     r1, #&7F
        ORREQ   r4, r4, #SoundChannelGateOff
        TST     r1, #&80
        ORREQ   r4, r4, #SoundChannelGateOn ; +SoundChannelGateOff
        ORRNE   r4, r4, #SoundChannelUpdate
        STRB    r4, [r6, #SoundChannelFlagsB]
        CLRV
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 is channel
;       r1 is offset to read from
;       r10, r11 trashable

; Out   word in r2 OR return r0 unchanged or 0 if error

ReadWord ROUT

        CMP     r1, #SoundChannelCBSize-1
        SUBLO   r10, r0, #1             ; Ensure in 1..SoundPhysChannels
        CMPLO   r10, #SoundPhysChannels
        BHS     ReadWriteWordError

        LDR     r11, =SoundLevel1Base + SoundLevel1ChannelTable
        ADD     r11, r11, r10, LSL #SoundChannelCBLSL ; address
        LDR     r2, [r11, r1]           ; get old
        CLRV
        MOV     pc, lr

; ..............................................................................
; In    r0 is channel
;       r1 is offset to read from
;       r2 is data word to write
;       r10, r11 trashable

; Out   previous word in r2 OR return r0 unchanged or 0 if error

WriteWord ROUT

        CMP     r1, #SoundChannelCBSize-1
        SUBLO   r10, r0, #1             ; Ensure in 1..SoundPhysChannels
        CMPLO   r10, #SoundPhysChannels
        BHS     ReadWriteWordError

        LDR     r11, =SoundLevel1Base + SoundLevel1ChannelTable
        ADD     r11, r11, r10, LSL #SoundChannelCBLSL ; address
        LDR     r10, [r11, r1]          ; get old
        STR     r2,  [r11, r1]
        ADDS    r2, r10, #0                 ; return last, clears V
        MOV     pc, lr


ReadWriteWordError
        SUBS    r0, r0, r0              ; return error (R0=0, clear V - apparently!)
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 is pitch
;       if > &8000 then direct value to install
;                  else 15-bit pitch
;       3-bit octave, 12-bit 1/4096 octave inc (8-bit significant!)

;       &4000 is middle C nominally, normally!

;       r10, r11 trashable

SoundPitch ROUT

        CMP     r0, #&8000

        LDRLT   r11, =SoundLevel1Base
        LDRLT   r11, [r11,#SoundLevel1MasterPitch]

        ADDLT   r0, r0, r11
        MOVLT   r0, r0, ROR #12         ; octave to bottom 4 bits
        BICLT   r0, r0, #&00FF0000      ; force to word index
        ADRLT   r11, PitchTab
        LDRLT   r11, [r11, r0, LSR #22] ; get 32-bit frac
        EORLT   r0, r0, #&F             ; invert octave
        MOVLT   r0, r11, LSR r0         ; build
        MOV     pc, lr                  ; V will be clear

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

AutoTune_Service
        LDR     r12, [r12]
AutoTune ROUT
        ; Calculate correct tuning value, if auto tuning enabled
        ; In:
        ;  r2 = sample rate, 1/1024Hz
        ;  r3 = buffer size
        ; Out:
        ;  All regs preserved
        Entry   "r0-r3"
        LDR     r0, AutoTuneFlag
        CMP     r0, #0
        EXIT    EQ

        ; Recalc buffers-per-5cs:
        ; R2/(20*1024*buffer size)
        ; For simplicity, just divide R2 by 5*buffer size
        ; This will give a 20.12 fixed point number, which should be accurate enough for most purposes
        ADD     r3,r3,r3,LSL #2
        ADD     lr,r2,r3,LSR #1 ; Add 0.5*denominator to round to nearest
        DivRem  r0,lr,r3,r1,norem
        STR     r0, BuffersPer5cs

        ; Recalc tuning value:
        ;  r2 = sample rate, 1/1024Hz
        LDR     r1, Reference_freq ; r1 = reference frequency
        ; Algorithm:
        ; 1. Calculate r1/r2
        ; 2. Shift result left until we get a value between &40000000 and &80000000
        ; 3. The shift count forms the octave
        ; 4. Binary search through PitchTab to find the entry closest to the shifted result. This forms the fraction
        ; 5. As an extra step, perform linear interpolation between the two closest PitchTab values to calculate the bottom 4 bits of the fraction

        ; Since we're using integer math, we'll start off by shifting R2 left until Reference_freq >= R2 > Reference_freq*0.5
        ; This will simplify the division code a bit, as we'll be guaranteed to get a result suitable for the PitchTab search
      [ NoARMv5
        ; Borrowed from AsmUtils, and tweaked a bit to get rid of all-zeros case
        ORR     r0, r2, r2, LSR #1
        ORR     r0, r0, r0, LSR #2
        ORR     r0, r0, r0, LSR #4
        LDR     r3, =&06C9C57D
        ORR     r0, r0, r0, LSR #8
        ADR     lr, clz_table
        ORR     r0, r0, r0, LSR #16
        MLAS    r0, r3, r0, r3
        LDRNEB  r0, [lr, r0, LSR #27]
      |
        CLZ     r0,r2
      ]
        MOV     r2,r2,LSL r0

        MOV     r3,#0 ; Division result
        MOV     lr,#31 ; Loop count
        ; Ensure Reference_freq >= R2 > Reference_freq*0.5
        CMP     r2,r1
        MOVHI   r2,r2,LSR #1
        SUBHI   r0,r0,#1
        ; Perform the division
        ; We want a 31 bit fractional result, so rather than shifting the denominator right in each iteration (as per DivRem macro) we'll shift the numerator left
        ; This ensures we won't lose accuracy due to losing the low bits of the denominator
        ; There's no possibility of the numerator overflowing, as we know the initial value is no more than twice the denominator, and the division loop itself ensures it stays within that range
10
        CMP     r1,r2
        SUBCS   r1,r1,r2
        ADC     r3,r3,r3
        SUBS    lr,lr,#1
        MOV     r1,r1,LSL #1
        BNE     %BT10

        ; Now binary search PitchTab for R3
        ADR     r1,PitchTab
        MOV     r2,#128
20
        LDR     lr,[r1,r2,LSL #2]
        CMP     lr,r3
        ADDLT   r1,r1,r2,LSL #2
        MOVS    r2,r2,LSR #1
        BNE     %BT20
        ADR     r2,PitchTab
        SUB     r2,r1,r2

        ; Bias octave (r0) and add in fraction (r2)
        MOV     r0,r0,LSL #12
        ADD     r0,r0,r2,LSL #2

        ; Calculate bottom 4 bits of fraction via linear interpolation
        ; DivRem used for simplicity
        LDMIA   r1,{r1,r2}
        SUB     r2,r2,r1
        SUB     r3,r3,r1
        ADD     r3,r3,r3,LSL #5 ; *31, but gets treated as *16.5 due to shift below (using *16.5 so result is rounded to nearest)
        DivRem  r1,r3,r2,lr,norem
        ADD     r0,r0,r1,LSR #1

        ; Clamp the result and store it 
        CMP     r0,#0
        MOVLE   r0,#1 ; 1 is the lowest value the user can set
        CMP     r0,#&8000
        LDRGE   r0,=&7FFF
        LDR     r1, =SoundLevel1Base
        STR     r0, [r1, #SoundLevel1MasterPitch]
        EXIT

 [ NoARMv5
clz_table
        = 32, 31, 14, 30, 22, 13, 29, 19,  2, 21, 12, 10, 25, 28, 18,  8
        =  1, 15, 23, 20,  3, 11, 26,  9, 16, 24,  4, 27, 17,  5,  6,  7
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

BBCPitchInc16 * (65536 * 4096 / 48) ; << 16 for accuracy
BBCPitchBase  *  &4000 - (53*4096/48) ; offset from middle C

DefMasterPitch * &AAB0 - &4000 ; 66E >> 5 = 261.625525 Hz!

Reference_freq
        DCD     &82D01134 ; middle C, minus 4 octaves, << 27

; Pitch table Builder
; This is (2^(x/256))<<30, for x from 0 to 255

PitchTab
        DCD     &40000000,&402C6BEA,&4058F6A8,&4085A051
        DCD     &40B268FA,&40DF50B9,&410C57A2,&41397DCC
        DCD     &4166C34D,&41942839,&41C1ACA8,&41EF50AE
        DCD     &421D1462,&424AF7DA,&4278FB2B,&42A71E6D
        DCD     &42D561B4,&4303C518,&433248AE,&4360EC8D
        DCD     &438FB0CC,&43BE9580,&43ED9AC0,&441CC0A4
        DCD     &444C0741,&447B6EAE,&44AAF702,&44DAA054
        DCD     &450A6ABB,&453A564E,&456A6323,&459A9152
        DCD     &45CAE0F2,&45FB521B,&462BE4E2,&465C9961
        DCD     &468D6FAE,&46BE67E1,&46EF8210,&4720BE55
        DCD     &47521CC6,&47839D7B,&47B5408C,&47E70611
        DCD     &4818EE22,&484AF8D6,&487D2646,&48AF768A
        DCD     &48E1E9BA,&49147FEE,&4947393F,&497A15C5
        DCD     &49AD1598,&49E038D1,&4A137F88,&4A46E9D7
        DCD     &4A7A77D5,&4AAE299C,&4AE1FF44,&4B15F8E6
        DCD     &4B4A169C,&4B7E587E,&4BB2BEA5,&4BE7492B
        DCD     &4C1BF829,&4C50CBB8,&4C85C3F1,&4CBAE0EF
        DCD     &4CF022CA,&4D25899C,&4D5B157F,&4D90C68C
        DCD     &4DC69CDD,&4DFC988D,&4E32B9B4,&4E69006E
        DCD     &4E9F6CD4,&4ED5FF00,&4F0CB70D,&4F439514
        DCD     &4F7A9931,&4FB1C37D,&4FE91413,&50208B0E
        DCD     &50582888,&508FEC9C,&50C7D765,&50FFE8FE
        DCD     &51382182,&5170810B,&51A907B5,&51E1B59A
        DCD     &521A8AD7,&52538787,&528CABC4,&52C5F7AA
        DCD     &52FF6B55,&533906E1,&5372CA68,&53ACB608
        DCD     &53E6C9DB,&542105FD,&545B6A8C,&5495F7A1
        DCD     &54D0AD5B,&550B8BD4,&5546932A,&5581C378
        DCD     &55BD1CDB,&55F89F70,&56344B53,&567020A0
        DCD     &56AC1F75,&56E847EF,&57249A2A,&57611643
        DCD     &579DBC57,&57DA8C84,&581786E6,&5854AB9C
        DCD     &5891FAC1,&58CF7475,&590D18D4,&594AE7FB
        DCD     &5988E20A,&59C7071D,&5A055751,&5A43D2C7
        DCD     &5A82799A,&5AC14BEA,&5B0049D5,&5B3F7378
        DCD     &5B7EC8F2,&5BBE4A62,&5BFDF7E6,&5C3DD19C
        DCD     &5C7DD7A4,&5CBE0A1C,&5CFE6923,&5D3EF4D8
        DCD     &5D7FAD59,&5DC092C7,&5E01A540,&5E42E4E3
        DCD     &5E8451D0,&5EC5EC26,&5F07B405,&5F49A98C
        DCD     &5F8BCCDC,&5FCE1E13,&60109D51,&60534AB7
        DCD     &60962665,&60D9307B,&611C6919,&615FD05F
        DCD     &61A3666D,&61E72B65,&622B1F66,&626F4292
        DCD     &62B39509,&62F816EC,&633CC85B,&6381A978
        DCD     &63C6BA64,&640BFB41,&64516C2E,&64970D4F
        DCD     &64DCDEC3,&6522E0AE,&6569132F,&65AF766A
        DCD     &65F60A80,&663CCF92,&6683C5C3,&66CAED36
        DCD     &6712460B,&6759D065,&67A18C68,&67E97A34
        DCD     &683199EE,&6879EBB6,&68C26FB1,&690B2601
        DCD     &69540EC9,&699D2A2C,&69E6784D,&6A2FF94F
        DCD     &6A79AD56,&6AC39485,&6B0DAF00,&6B57FCE9
        DCD     &6BA27E66,&6BED3399,&6C381CA6,&6C8339B3
        DCD     &6CCE8AE1,&6D1A1057,&6D65CA38,&6DB1B8A8
        DCD     &6DFDDBCC,&6E4A33C9,&6E96C0C3,&6EE382DF
        DCD     &6F307A41,&6F7DA710,&6FCB0970,&7018A185
        DCD     &70666F76,&70B47368,&7102AD80,&71511DE4
        DCD     &719FC4BA,&71EEA226,&723DB650,&728D015E
        DCD     &72DC8374,&732C3CBA,&737C2D56,&73CC556E
        DCD     &741CB528,&746D4CAC,&74BE1C20,&750F23AB
        DCD     &75606374,&75B1DBA2,&76038C5B,&765575C8
        DCD     &76A79810,&76F9F359,&774C87CC,&779F5591
        DCD     &77F25CCE,&78459DAD,&78991854,&78ECCCED
        DCD     &7940BB9E,&7994E492,&79E947EF,&7A3DE5DF
        DCD     &7A92BE8B,&7AE7D21A,&7B3D20B6,&7B92AA89
        DCD     &7BE86FBA,&7C3E7073,&7C94ACDE,&7CEB2524
        DCD     &7D41D96E,&7D98C9E6,&7DEFF6B7,&7E476009
        DCD     &7E9F0607,&7EF6E8DB,&7F4F08AE,&7FA765AD
        DCD     &7FFFFFFF

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Now the Installed Level1 handler

; Level1
;  R6 is -ve if updated Level0
;  R8 = sample period in uS
;  R9 = pointer to LEVEL1 SEGMENT BASE
; R10 = DMA Buffer End (+1)
; R11 = DMA Buffer Inc
; R12 = DMA Buffer Base
; USAGE:
;  R7 = Channel counter
;  R0-5 (AND preserved R6-12 for Channel fill)
;  channel code receives R4=code, R5=data segment

Level1Fill ROUT

   Push    "R14"
   STRB    R11,[R9,#SoundLevel1NChannels] ; update active channel count
   MOV     R7,#0         ; channel index
   ADD     R5,R9,#SoundLevel1VoiceTable   ; voice module pointers
   ADD     R9,R9,#SoundLevel1ChannelTable    ; SCCB table
10 LDRB    R4,[R9,#SoundChannelFlagsB]  ; get flags byte
   CMP     R6,#0
   ORRMI   R4,R4,#SoundChannelFlush2  ; set flush pending if Level0 change
   BICMI   R4,R4,#SoundChannelFlush1  ; xxxxxx10 ; flush count 2
   CMP     R4,#SoundChannelActive       ; Quiet?
   BGE     %50                 ; not Quiet so fill
20 TST     R4,#SoundChannelFlushPending ; xxxxxx00 ; flushed
   BEQ     %90
30 ; force flush
   SUB     R4,R4,#SoundChannelFlush1    ; decrement flush count
   STRB    R4,[R9,#SoundChannelFlagsB]  ; update flags byte

; run flush code with IRQs re-enabled
; to reduce IRQ latency
   ADR     R1,%45 ; return address (to IRQ DISABLE CODE)
   ADR     R2,%40 ; flush code
; Level1Fill - R2 is Voice entry address
   STMFD   R13!,{R1,R5,R6,R7,R8,R9,R10,R11,R12}
;; {R1} return address MUST BE LAST ON STACK!
   ADD     R12,R12,R7    ; R12 is Channel dma base
   WritePSRc IRQ_mode, r5
   MOV     PC,R2        ; MUST return with LDMFD R13!,{PC} to re-disable IRQs

40 MOV     R1,#0
41 ; Level1FlushLoop
   STRB    R1,[R12],R11 ; clear out channel
   STRB    R1,[R12],R11
   STRB    R1,[R12],R11
   STRB    R1,[R12],R11
   CMP     R12,R10
   BLT     %41 ; Level1FlushLoop
   Pull    "PC"
45
   WritePSRc I_bit :OR: IRQ_mode, r5
   MOV     R0,R0
   LDMFD   R13!,{R5,R6,R7,R8,R9,R10,R11,R12}
   B       %90 ; Next

50 ; R4 is active channel flags
   LDRB    R2,[R9,#SoundChannelVoiceIndexB]  ; get control word
   CMP     R2,#MaxNVoices
   BGE     %80           ; fix erroneous voice?
; valid voice index in R2
   LDR     R0,[R5,+R2,LSL #2]  ; get module pointer
   CMP     R0,#0    ; not loaded?
   BEQ     %80
; R0 is code pointer base
; priority encode the actual entry point in R2
   TST     R4,#SoundChannelActive  ; for Active - continuation filling
   ADDNE   R2,R0,#SoundVoiceFill
   TST     R4,#SoundChannelUpdate  ; for update current voice params
   ADDNE   R2,R0,#SoundVoiceUpdate
   TST     R4,#SoundChannelGateOn  ; for Init
   ADDNE   R2,R0,#SoundVoiceGateOn
   TST     R4,#SoundChannelGateOff ; for Kill
   ADDNE   R2,R0,#SoundVoiceGateOff
; R2 is code entry
; R9 is SCCB
   ADR     R1,%60 ; return address (to IRQ DISABLE CODE)
; Level1Fill - R2 is Voice entry address
   STMFD   R13!,{R1,R5,R6,R7,R8,R9,R10,R11,R12}
;; {R1} return address MUST BE LAST ON STACK!
   ADD     R12,R12,R7    ; R12 is Channel dma base
   WritePSRc IRQ_mode, r5
   MOV     PC,R2        ; MUST return with LDMFD R13!,{PC} to re-disable IRQs
60
   WritePSRc I_bit :OR: IRQ_mode, r5
   MOV     R0,R0 ; wait while bank settles!
   LDMFD   R13!,{R5,R6,R7,R8,R9,R10,R11,R12}
   LDRB    R1,[R9,#SoundChannelFlagsB]  ; update flags byte
; patch up flags in case pending OFF and ON!
   TST     R1,#SoundChannelGateOff
   BICNE   R1,R1,#SoundChannelGateOff
   BNE     %70
   TST     R1,#SoundChannelGateOn
   BICNE   R1,R1,#SoundChannelGateOn + 3
   BNE     %70
   MOV     R1,#0 ; otherwise only use return flags
70 ORR     R1,R1,R0
   STRB    R1,[R9,#SoundChannelFlagsB]  ; update flags byte

90 ; Advance to next channel
   ADD     R9,R9,#SoundChannelCBSize ; advance...
   ADD     R7,R7,#1
   CMP     R7,R11
   BLT     %10 ; Level1Loop
   Pull    "PC"

; fix error
80
;; ORR     R4,R4,#SoundChannelFlush2      ; force flush inactive
;; BIC     R4,R4,#SoundChannelFlush1      ; xxxxxx10 ; flush count 2
;; force flush only once fix - DWF 22-Jun-87
   MOV     R4,#SoundChannelFlush2
   B       %30
;


Level1Fixup
; Level1Fixup
; r14 is return
; r12 is stack mark (TOP) ** THIS MUST BE PRESERVED **
; r11 is Level1 base (code entered at  base + 4)
; my stack (words) is:
;       R10   )               <---- TOP-1
;        R9   )
;        R8   )
;        R7   )
;        R6   )    Level 0
;        R5   ) reg save area
;        R4   )
;        R3   )
;        R2   )
;        R1   )
;        R0   )              <---- TOP-11
;----------------------
;     return  to Level 0     <---- TOP-12
;       R12   DMA Base                -13
;       R11   DMA Interleave          -14
;       R10   DMA Limit               -15
;        R9   Sound Stream Base       -16
;        R8   Sample rate period      -17
;        R7   Channel Number          -18
;        R6   Update (flush) flag     -19
;        R5   Voice module table      -20
;        Stream Link return           -21

;----------------------
;   any current Stream rubbish....
;----------------------
;     int return          new SIRQ entry!
;       R12
;       R11                <------ R13
;----------------------
;
; r11 is Level1 base (code entered at  base + 4)
;
   STMFD   R13!,{R11,R12,R14}
   LDR     R14,[R12,#-21*4] ; get offending return
   STR     R14,[R11,#-12]
   LDR     R14,[R12,#-18*4] ; get offending Channel no.!
   STR     R14,[R11,#-4]
   ADD     R14,R11,R14,LSL #SoundChannelCBLSL
   ADD     R14,R14,#SoundLevel1ChannelTable + SoundChannelFlagsB
   STR     R14,[R11,#-8]
   LDRB    R11,[R14]
   ORR     R11,R11,#SoundChannelOverrun ; mark overrun
   STRB    R11,[R14]
; now, having marked the problem Channel,
; the buffer will be swapped, the stack patched
; and Level1Fill is imminent
   LDMFD   R13!,{R11,R12,PC}


;**************************************
;*   LOG TABLE  SEGMENT INSTALL CODE  *
;**************************************
; build the 8k lin -> log table
; scaled to system attenuation factor
; use R0-R8
BuildLogTable ROUT
   STMFD   R13!,{R0-R8,R14}
   LDR     R3,=SoundLevel1Base
   LDR     R7,[R3,#SoundLevel1LogTable] ; pointer to table
   LDRB    R0,[R3,#SoundLevel1MaxAmp]
   AND     R6,R0,#&7F      ; R6 is volume
   RSB     R6,R6,#&7F      ; make attenuation
; table build
;  R0 pos amp byte value
;  R1 neg amp byte value
;  R2 bytes/step counter
;  R3 steps/chord counter
;  R4 chord step length counter
;  R5 incremental amplitude
;  R6 is attenuation factor
;  R7 positive table ptr (from 0) UP
;  R8 negative table ptr (from -1) DOWN

   ADD     R8,R7,#LogTableSize ; from both ends!
   MOV     R5,#0           ; current amp

 [ VIDC_Type <> "VIDC1"
   STRB    R5,[R7],#1     ; 0 is special case
   MOV     R4,#1           ; bytes/step
10 ; InitChord
   MOV     R3,#15          ; 16 steps per chord
20 ; InitStep
   MOV     R2,R4           ; R2 is bytes/step
   ADD     R5,R5,#2        ; inc current amp
   CMP     R5,#&FE         ; fix overflow
   MOVGT   R5,#&FE
   SUBS    R0,R5,R6,LSL #1 ; amp scale
   MOVMI   R0,#0         ; underflow correct
   ORR     R1,R0,#1        ; make neg entry
30 ; InitLoop
   STRB    R0,[R7],#1     ; pos entry
   STRB    R1,[R8,#-1]!   ; neg entry
   CMP     R7,R8           ; stop if the middle
   BGE     %40 ; InitDone
   SUBS    R2,R2,#1       ; repeat R4 times
   BNE     %30 ; InitLoop
   SUBS    R3,R3,#1       ; repeat for 16 steps
   BPL     %20 ; InitStep
   MOV     R4,R4,LSL #1    ; double bytes/step
   B       %10 ; InitChord         ; next chord
 ]
 [ VIDC_Type = "VIDC1"
   STRB    R5,[R7],#1     ; 0 is special case
   MOV     R4,#1           ; bytes/step
10 ; InitChord
   MOV     R3,#15          ; 16 steps per chord
20 ; InitStep
   MOV     R2,R4           ; R2 is bytes/step
   ADD     R5,R5,#1        ; inc current amp
   CMP     R5,#&7F         ; fix overflow
   MOVGT   R5,#&7F
   SUBS    R0,R5,R6       ; amp scale
   MOVMI   R0,#0         ; underflow correct
   ORR     R1,R0,#&80      ; make neg entry
30 ; InitLoop
   STRB    R0,[R7],#1     ; pos entry
   STRB    R1,[R8,#-1]!   ; neg entry
   CMP     R7,R8           ; stop if the middle
   BGE     %40 ; InitDone
   SUBS    R2,R2,#1       ; repeat R4 times
   BNE     %30 ; InitLoop
   SUBS    R3,R3,#1       ; repeat for 16 steps
   BPL     %20 ; InitStep
   MOV     R4,R4,LSL #1    ; double bytes/step
   B       %10 ; InitChord         ; next chord
 ]
40 ; BuildAmpLUT ; amp look-up-table
   LDR     R3,=SoundLevel1Base
   LDR     R7,[R3,#SoundLevel1AmpTable] ; pointer to table
   MOV     R5,#0
50 ; loop
   SUBS    R0,R5,R6,LSL #1 ; amp scale
   MOVMI   R0,#0         ; underflow correct
   STRB    R0,[R7],#1
   ADD     R5,R5,#1
   CMP     R5,#256
   BLT     %50

InitDone
   LDMFD   R13!,{R0-R8,PC}

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

        LTORG

Initialise_Module Entry

        LDR     r5, =SoundLevel1Base    ; pointer to RAM SCCB page

        ADR     r0, Level1Fill          ; initialise dynamic pointers
        STR     r0, [r5, #SoundLevel1FillPtr]
        ADR     r0, Level1Fixup
        STR     r0, [r5, #SoundLevel1FixupPtr]
        MOV     r0, #SoundSystemNIL
        STR     r0, [r5, #SoundLevel1Queue]

        MOV     r0, #0
        STRB    r0, [r5, #SoundLevel1NVoices]
        ADD     r1, r5, #SoundLevel1VoiceTable ; clear out voice pointers
        ADD     r3, r1, #MaxNVoices*4   ; limit (inclusive)
10      STR     r0, [r1], #4
        CMP     r1, r3
        BLE     %BT10

        LDR     r2, [r12]               ; Check for reinitialisation
        CMP     r2, #0
        MOVNE   wp, r2                  ; Get ws^
        BNE     SoftStart

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =WorkSpaceSize
        SWI     XOS_Module
        EXIT    VS
        STR     r2, [r12]
        MOV     wp, r2                  ; Get ws^

; SCCB table
        MOV     r0, #&03000000 ; flush channel
        ADD     r1, r5, #SoundLevel1ChannelTable
        ADD     r3, r5, #SoundLevel1ChannelTableEnd
20      STR     r0, [r1], #SoundChannelCBSize
        CMP     r1, r3
        BLT     %BT20

        MOV     r0, #0
        STRB    r0, [r5, #SoundLevel1NChannels]

        LDR     r0, =DefMasterPitch
        STR     r0, [r5, #SoundLevel1MasterPitch]

; Store table pointers prior to calling BuildLogTable

        ADD     r1, wp, #:INDEX: LogTable
        STR     r1, [r5, #SoundLevel1LogTable] ; save log table pointer
        ADD     r1, wp, #:INDEX: AmpTable
        STR     r1, [r5, #SoundLevel1AmpTable] ; save logamp table pointer

        MOV     r0, #161                ; CMOS read OSBYTE
        MOV     r1, #SoundCMOS
        SWI     XOS_Byte
; R2 is 8 bit CMOS flags
; bit 7 is speaker on/off
; bit 6,5,4 is loudness
; bit 3,2,1,0 is default channel 0 voice
        MOV     r0, r2, LSR #7          ; Set speaker on/off
        ADD     r0, r0, #1
        SWI     XSound_Speaker          ; Level0 SWI, won't give error

        AND     r0, r2, #&0F            ; Set channel 0 voice
        ADD     r0, r0, #1              ; 0..15 -> voice 1..16
        STRB    r0, [r5, #SoundLevel1ChannelTable + SoundChannelVoiceIndexB]

        AND     r0, r2, #2_01110000     ; Set default loudness 0..7 -> &01..&7F
        ORR     r0, r0, r0, LSR #3      ; -> 00,12,23,36,48,5A,6C,7E
        ORR     r0, r0, #&01            ; Must always be some volume ...
        STRB    r0, [r5, #SoundLevel1MaxAmp]
        BL      BuildLogTable


SoftStart ; Just relink to Level0

        MOV     r0, #0
        STR     r0, MessageFile_Open

; OSS Clear out the array of local names (including the 0 excess entry)

        ADRL    r1, LocalNameArray
        ADD     r2, r1, #(4 * MaxNVoices)       ; limit (inclusive)
10      STR     r0, [r1], #4
        CMP     r1, r2
        BLE     %BT10

        ADD     r1, wp, #:INDEX: LogTable       ; Tables may have been reloc'd
        STR     r1, [r5, #SoundLevel1LogTable]  ; Save log table pointer
        ADD     r1, wp, #:INDEX: AmpTable
        STR     r1, [r5, #SoundLevel1AmpTable]  ; Save logamp table pointer

        ; Read address of OSByte variables. Try new OS_ReadSysInfo 6 first to
        ; cope with zero page protection.
        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_OSByteVars
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        CMP     r2, #0
        BNE     %FT20

        ; Fall back to old (and undocumented!) OS_Byte &A6
        MOV     r0, #&A6
        MOV     r1, #&00
        MOV     r2, #&FF
        SWI     XOS_Byte
        ORR     r2, r1, r2, LSL #8
20
        ADD     r2, r2, #210            ; @FX210 flag
        STR     r2, SoundSuppressAddr

        ; Try enabling auto tuning
        MOV     r0, #0
        STR     r0, AutoTuneFlag
        MOV     r0, #5<<12
        STR     r0, BuffersPer5cs
        LDR     r0, =&4f545541
        MOV     r1, #2
        BL      SoundTuning

        MOV     r0, #0
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, r5                  ; Install Level1 handler
        MOV     r4, #0
        SWI     XSound_Configure        ; Level0 SWI, won't give error

        MOV     r0, #Service_SoundLevel1Alive
        MOV     r1, #Service_Sound
        SWI     XOS_ServiceCall
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

Finalise_Module Entry
        LDR     r12, [r12]

; OSS Free the array of local names (including the 0 excess entry)

        ADRL    r1, LocalNameArray
        ADD     r3, r1, #(4 * MaxNVoices)       ; limit (inclusive)
10      MOV     r0, #ModHandReason_Free         ; Errors will corrupt R0
        LDR     r2, [r1], #4                    ; so set it each time round
        TEQ     r2, #0
        SWINE   XOS_Module                      ; Ignore errors - we are
        CMP     r1, r3                          ; going to die regardless
        BLE     %BT10

        LDR     r0, MessageFile_Open
        CMP     r0, #0
        ADRNE   r0, MessageFile_Block
        SWINE   XMessageTrans_CloseFile

        MOV     r0, #Service_SoundLevel1Dying
        MOV     r1, #Service_Sound
        SWI     XOS_ServiceCall         ; Can't stop me!

        MOV     r0, #0
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #SoundSystemNIL     ; Remove Level1 handler
        MOV     r4, #0
        SWI     XSound_Configure        ; Level0 SWI, won't give error
        CLRV
        EXIT                            ; Mustn't refuse to die

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

;Ursula format
;
        ASSERT  Service_Reset < Service_Sound
UServTab
        DCD     0
        DCD     UService - Module_Base
        DCD     Service_Reset
        DCD     Service_Sound
        DCD     0
        DCD     UServTab - Module_Base
Intercept_Services ROUT
        MOV     r0,r0
        CMP     r1, #Service_Reset
        CMPNE   r1, #Service_Sound
        MOVNE   pc, lr
UService
        CMP     r1, #Service_Sound
        BNE     ServiceReset
        CMP     r0, #Service_SoundConfigChanging
        BEQ     AutoTune_Service
        CMP     r0, #Service_SoundLevel0Alive
        BEQ     ToggleAutoTune
        MOV     pc, lr

ServiceReset
        Entry   "r0-r2"                              ; Flush out all channels
        MOV     r0, #SoundChannelForceFlush
        MOV     r1, #SoundPhysChannels-1             ; channel counter
        LDR     r2, =SoundLevel1Base + SoundLevel1ChannelTable + SoundChannelFlagsB

10      STRB    r0, [r2, r1, LSL #SoundChannelCBLSL] ; update channel
 [ debug
 DREG r1,"flushing channel ",,Integer
 ]
        SUBS    r1, r1, #1
        BPL     %BT10                                ; loop for each channel
        EXIT                                         ; No error returnable

ToggleAutoTune
        ; Toggle auto tuning on/off, for when level 0 (re)starts
        ; Required because new level 0 may not support auto tuning
        Entry   "r0-r1,r10-r11"
        LDR     r12, [r12]
        LDR     r0, AutoTuneFlag
        SUBS    r0, r0, #1
        EXIT    NE
        STR     r0, AutoTuneFlag ; Force off
        LDR     r0, =&4f545541
        MOV     r1, #2
        BL      SoundTuning ; Turn back on again
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

lookup_r0 Entry r1-r7
        BL      open_messagefile
        EXIT    VS
        MOV     r1, r0
        ADR     r0, MessageFile_Block
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_Lookup
        MOVVC   r0, r2
        EXIT

message_writes
        Entry   r0-r7
        SUB     r0, lr, pc
        ADD     r0, pc, r0
        SUB     r0, r0, #4
        MOV     r2, r0
10      LDRB    r1, [r2], #1
        CMP     r1, #0
        BNE     %B10
        SUB     r2, r2, r0
        ADD     r2, r2, #3
        BIC     r2, r2, #3
        ADD     lr, lr, r2
        STR     lr, [sp, #8 * 4]
        BL      open_messagefile
        STRVS   r0, [sp]
        EXIT    VS
        MOV     r1, r0
        ADR     r0, MessageFile_Block
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_Lookup
        EXIT    VS
10      LDRB    r0, [r2], #1
        CMP     r0, #32
        EXIT    CC
        SWICS   XOS_WriteC
        BVC     %B10
        EXIT

CopyError Entry r1-r7
        BL      open_messagefile
        EXIT    VS
        ADR     R1, MessageFile_Block
        MOV     R2, #0
        MOV     R4, #0
        MOV     R5, #0
        MOV     R6, #0
        MOV     R7, #0
        SWI     XMessageTrans_ErrorLookup
        EXIT

message_filename
        DCB     "Resources:$.Resources.SoundChann.Messages", 0
        ALIGN

open_messagefile Entry r0-r2
        LDR     r0, MessageFile_Open
        CMP     r0, #0
        EXIT    NE
        ADR     R0, MessageFile_Block
        ADR     R1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        STRVS   r0, [sp]
        EXIT    VS
        MOV     r0, #1
        STR     r0, MessageFile_Open
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        LTORG

 [ debug
 InsertDebugRoutines
 ]

        END

