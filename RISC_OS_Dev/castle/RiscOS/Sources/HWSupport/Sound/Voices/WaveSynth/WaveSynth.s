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
        TTL     Sound System v3.0 -> <wini>arm.WaveSynth.WaveSynth

;*************************************************
;**                                             **
;**       ARTHUR Sound System Software          **
;**                                             **
;**    MODULE: Sound System WaveTable           **
;**            Library module                   **
;**                                             **
;**    AUTHORS: David Flynn                     **
;**             Tim Dobson                      **
;**                                             **
;**    DESCRIPTION: wavesynth kernels           **
;**                 as voice install library    **
;**                                             **
;**    ENTRIES: Sound System Level1 Voice Entry **
;**                                             **
;*************************************************
; 1.00 EPROM version
; 1.01 0 length duration fixes
; 1.02 stack corruption problem on initialisation
; 1.03 fix update aborts (when voice not currently active)
; 1.04 fix smooth updates
; 1.05 fix RMTIDY problems
; 1.06 fix note off duration
; ---- Released for Arthur 1.20 ----
; 1.06 Modified header GETs so they work again
; 1.07 OSS Internationalisation - also removed null service entry
; 1.08 OSS Carefully reworked to avoid the need for any message lookups.
;          Removed SWI WaveSynth_Load (did nothing) and the ability to
;          load a wavetable file on RMLOADing the module (unused and
;          undocumented).
; 1.09 OSS Put the RMLoad/RMReinit read of wavetable file back in due
;          to user demand - it's documented in Archive magazine vol. 1
;          issue 8, also there are the WaveSynth-Brass and WaveSynth-Organ
;          wavetables. This entailed putting message handling code back in.
; 1.10 SMC Removed comment from Messages file and shortened token.
; 1.11  28 Feb 92  OSS  Changed to register voices with local name.
; 1.12  16 Mar 92  OSS  Now updates local names when Messages RAM loaded.
; 1.13  18 Mar 92  OSS  Fixed "Token not found" error on loading a wavetable
;                       with no local name in initialisation parameters.


        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ModHand
        GET     Hdr:PublicWS
        GET     Hdr:Sound
        GET     Hdr:Proc
        GET     Hdr:MsgTrans
        GET     Hdr:Services
        GET     Hdr:HighFSI

        GET     VersionASM

; Now we can start the module

        AREA |WaveSynth$$Code|, CODE, READONLY, PIC

Module_Base                ; label for calculating offsets
        DCD     0                                       ; not application
        DCD     Initialise_Module  - Module_Base
        DCD     Finalise_Module    - Module_Base
        DCD     Intercept_Services - Module_Base
        DCD     Module_Name        - Module_Base
        DCD     Help_String        - Module_Base
        DCD     0                                       ; no Keywords
        DCD     0                                       ; No SWI chunk base
        DCD     0
        DCD     0
        DCD     0
        DCD     0                                       ; no international messages
      [ :LNOT: No32bitCode
        DCD     Module_Flags       - Module_Base
      ]

Module_Name DCB "WaveSynth", 0

Help_String
        DCB     "WaveSynth"
        DCB     9
        DCB     "$Module_HelpVersion"
        DCB     0
        ALIGN

LoadFailBlock
        DCB     "LoadErr",0                             ; Message token for string printed if file not found
        ALIGN

      [ :LNOT: No32bitCode
Module_Flags
        DCD     ModuleFlag_32bit                        ; 32-bit OK
      ]

; the initialisation :

Initialise_Module Entry "r9-r11", 16    ; MessageTrans file block on stack
        MOV     r11, sp                      ; held in r11
        
        LDR     R2, [R12]     ; check for reinitialisation
        TEQ     R2, #0
        MOVNE   R0, #ModHandReason_Free
        SWINE   XOS_Module   ; Free existing workspace (may need different size)
        EXIT    VS
        
        BL      open_message_file_r11
        ; OSS No error exit - r11 is 0 if open failed and the other message file
        ; functions cope with this.
        
        ; OSS From here on, don't just bomb out to quit - you need to close the
        ; Messages file.

        ; parse env string, discarding leading spaces
15      LDRB    R0,[R10]
        CMP     R0,#" "
        ADDEQ   R10,R10,#1
        BEQ     %BT15

        ; R10 now points to first non-space character in environment string.

        ; check for NULL name string
        LDRB    r0, [r10]
        CMP     r0, #" "
        BLO     %80          ; No file (first char is terminator)

        ; Scan to end of filename
        MOV     r9, r10
15      LDRB    R0,[R9]
        CMP     R0,#" "
        ADDHI   R9,R9,#1
        BHI     %BT15

        ; R9 now points at first char after filename. Check for a space
        LDRB    r0, [r9]
        CMP     r0, #" "
        MOVNE   r9, #0       ; No - there is no local name
        BNE     %FT20
        
        ; discard spaces to get to first char of local name
15      LDRB    R0,[R9]
        CMP     R0,#" "
        ADDEQ   R9,R9,#1
        BEQ     %BT15
        ; R9 now points at the first character of the local voice name. The entire
        ; of the rest of the command line is used - spaces do not terminate this.

20
        MOV     R1,R10               ; point R1 to string
        ; check file
        MOV     R0,#OSFile_ReadInfo
        MOV     R2,#0
        MOV     R3,#0
        SWI     XOS_File
        BVS     %70                  ; Bad file
        CMP     R0,#object_file      ; FILE FOUND?
        BNE     %70                  ; Bad file
        TST     R4,#&FF              ; check multiple of 256 bytes
        BNE     %70                  ; Bad file
        ; allocate according to length (returned in R4)
        LDR     R0,WaveBase
        ADD     R3,R4,R0             ; add on length of code
        MOV     R0, #ModHandReason_Claim
        SWI     XOS_Module
        BVS     wavesynth_init_fail
        
        STR     R2, [R12]
        MOV     R1,R10               ; restore file name
        LDR     R0,WaveBase
        MOV     R3,#0                ; use R2 as load address
        ADD     R2,R2,R0             ; R2 = load address
        ; load file
        MOV     R0,#OSFile_Load
        SWI     XOS_File
        BVS     %60                  ; Failed to load
        ; check header...
        LDR     R3,WaveBase
        LDR     R6,[R12]             ; workspace start to R6
        ADD     R6,R6,R3             ; workspace wavetable offset
        LDR     R0,[R6],#4           ; get wavetable magic word (and R6 to NAME)
        LDR     R1,WaveTable0        ; compare with ROM copy
        CMP     R0,R1                ; check the "!WT:" word
        ; if here and match then valid wavetable, R6 points to name string
        BEQ     CopyWorkSpace
        ; else release this space

60      LDR     R2,[R12]
        MOV     R0, #ModHandReason_Free
        SWI     XOS_Module
        BVS     wavesynth_init_fail

        ; Come here if file given is no good. r10 -> filename.

70      ADR     r0, LoadFailBlock
        MOV     r1, r10
        BL      gs_lookup_print_string_one_file_r11
        BVS     wavesynth_init_fail

        ; Come here if zero length (ie. no) filename passed.

80      LDR     R3, BeepWorkSpaceSize
        MOV     R0, #ModHandReason_Claim
        SWI     XOS_Module
        BVS     wavesynth_init_fail
        
        STR     R2,[R12]
        MOV     r9, #1                       ; Local name flag to say the lookup
        MOV     R6,#0 ; NO NAME TO COPY        must succeed (we are Beep)
        LDR     R3, AmountToCopy
        ; copy code into our workspace.
        ; voice code MUST be in RAM for speed..
        ; all position independent.
        ; R3 is amount to copy...

CopyWorkSpace
        LDR     R12,[R12]                    ; R12 is the workspace pointer
        ADRL    R0, WorkSpaceImage           ; ROM copy base
CopyLoop
        SUBS    R3, R3, #4                   ; word copy
        LDRPL   R1, [R0, R3]
        STRPL   R1, [r12, R3]
        BPL     CopyLoop
        MOV     R0,#1
        MOV     R1,r12
        LDR     R2,AmountToCopy
        ADD     R2,r12,R2
        SUB     R2,R2,#4
        SWI     XOS_SynchroniseCodeAreas
        CMP     R6,#0
        BEQ     %90
        ADD     R1,r12,#Voice1Name
85      LDRB    R0,[R6],#1                   ; name pointer
        STRB    R0,[R1],#1
        CMP     R0,#0
        BNE     %85
90      ADD     R2,r12,#Voice1               ; WS IS LINK

        CMP     r9, #1                       ; Test if local name (and clear V)
        MOVHI   r0, r9                       ; Use local name.
        BHI     %FT93
        
        ADD     r0, r12, #Voice1Title        ; Lookup title in Messages file.
        BL      lookup_zero_file_r11
        BVC     %FT93                        ; Success!
        
        TEQ     r9, #1                       ; Check if we MUST have local name
        BEQ     wavesynth_init_fail          ; and generate an error if so.
        MOV     r0, #0                       ; No local voice name at all.
93
        MOV     r3, r0                       ; Move local name (0 if no file)
        MOV     R1,#0                        ; force load anywhere
        MOV     r0, #1                       ; install with local voice name
        SWI     XSound_InstallVoice
        BVS     wavesynth_init_fail
        ADD     R0,r12,#Voice1
        CMP     R1,#0                        ; fail?
        STRNE   R1,[R0,#SoundVoiceIndex]
        
        BL      close_message_file_r11
        EXIT

        ; OSS This code is only called when there has been an error - r0 points
        ; to the error block. Any extra errors on the close are ignored.
wavesynth_init_fail
        MOV     r1, r0                       ;�Preserve current error
        BL      close_message_file_r11       ; Close the file
        MOV     r0, r1                       ; Get old error back
        SETV                                 ; flag an error
        EXIT


Finalise_Module ROUT
        Push    "lr"
        LDR     R2,[R12]        ; workspace
        ADD     R0,R2,#Voice1   ; WS IS LINK
        LDR     R1,[R0,#SoundVoiceIndex]
        SWI     XSound_RemoveVoice
10      Pull    "lr" ; return - the release is assumed to work correctly!
        ; Note that we can leave the workspace as it is : if this is a fatal entry,
        ; the workspace will be deleted, while for a non-fatal entry, the workspace
        ; will be moved and [R12] updated.
        RETURNVC

; Ursula format service table
UServTab
        DCD     0
        DCD     UService - Module_Base
        DCD     Service_ResourceFSStarted
        DCD     0
        DCD     UServTab - Module_Base
Intercept_Services
        MOV     r0, r0
        TEQ     r1, #Service_ResourceFSStarted
        MOVNE   pc, r14
UService
        ; OSS Update local voice name whenever new files are registered with
        ; ResourceFS.
change_names Entry "r0-r3, r11", 16     ; MessageTrans file block on
        MOV     r11, sp                 ; stack held in r11.
        BL      open_message_file_r11
        EXIT    VS                      ; Give up if no file.

        LDR     r12, [r12]              ; Workspace - points at voices.
        MOV     r2, #0                  ; Required.

        ADD     r0, r12, #Voice1Title   ; Lookup title in Messages file.
        BL      lookup_zero_file_r11
        BVS     %FT10                   ; Skip if no local name.
        ADD     r1, r12, #Voice1
        LDR     r1, [r1, #SoundVoiceIndex]
        MOV     r3, r0                  ; Local name in R3.
        MOV     r0, #3                  ; Change name please.
        TEQ     r1, #0
        SWINE   XSound_InstallVoice     ; Dont change if no voice.
10
        BL      close_message_file_r11  ; OSS Remember to close it!
        EXIT


; now the workspace image : it consists purely of the voice code
; and the reserved table and data segment spaces.

WorkSpaceImage

Start_Of_Code
;**************************************
;*   VOICE CO-ROUTINE CODE SEGMENT    *
;**************************************
; On installation, point Level1 code
; pointer to one of the following voice tables.
;
; ALL CALLS return using PC on top of stack
;
Voice1 * .-WorkSpaceImage
Voice1Base
        B       FillOne
        B       UpdateFillOne
        B       GateOnOne
        B       GateOffOne
        B       Instantiate
        B       Free
        LDMFD   R13!,{PC}       ; dummy entry per PRM 4-13
        DCD     Voice1TitleString - Voice1Base
        DCD     0               ; wavetable size variable
        DCD     0               ; data segmentSSCB index at load time..

Voice1TitleString
        DCB     "WaveSynth-"
Voice1Title * Voice1TitleString-WorkSpaceImage
Voice1NameString
        DCB     "Beep",0,0,0,0,0,0,0,0,0,0,0,0,0
Voice1Name * Voice1NameString-WorkSpaceImage
        ALIGN

;**************************************
;*  VOICE BUFFER FILLS                *
;**************************************
; Fill
; Update
; GateOn
; GateOff
; Entry:
;   R6 -ve if the channel config changed
;   R7 is channel number
;   R8 sample period (�s)
;   R9 is SoundChannelControlBlock
;   R10 DMA buffer limit (+1)
;   R11 DMA buffer interleave increment
;   R12 DMA buffer base pointer
;   R13 Sound System Stack with return address and flags
;       on top of stack
;   NO r14 - IRQs are enabled and r14 cannot be trusted
; Return:
;   R0 flags byte 
FillOne
        ADRL    R8,WaveTable0
        B       Fill
UpdateFillOne
        ADRL    R8,WaveTable0
        LDRB    R0,[R9,#SoundChannelFlagsB]
        LDMIB   R9,{R2-R4}      ; get pitch, timbre, fill counter
        TST     R0,#SoundChannelActive
        BNE     Fill
        B       GateOff
GateOnOne
        ; Calculate scale factor to convert segment durations from the reference
        ; value of 48us to the current sample period
        MOV     R0, #48<<16
        DivRem  R1,R0,R8,R2,norem
        ; Abuse the timbre accumulator to store the result
        STR     R1,[R9,#SoundChannelTimbre]
        ADRL    R8,WaveTable0
        B       GateOn
GateOffOne
        ADRL    R8,WaveTable0
        B       GateOff

        MACRO
        FixDuration
        ; Fix the segment duration value contained in R6, using the scale
        ; factor in R3. Corrupts R0.
        MOV     R0,R6,LSR #9
        MUL     R0,R3,R0
        MOV     R6,R6,LSL #32-9
        ORR     R6,R6,R0,LSR #16
        MOV     R6,R6,ROR #32-9
        MEND

;**************************************
;*  VOICE INSTANTIATE                 *
;**************************************
; Entry:
;   R0 is channel number to instantiate (0-7)
; Return:
;   R0 preserved if success, R0 changed if fail
Instantiate ROUT
        Pull    "pc"

;**************************************
;*  VOICE FREE                        *
;**************************************
; Entry:
;   R0 is channel number to de-instantiate! (0-7)
; Return:
;   R0 preserved ; always works!
Free ROUT
        Pull    "pc"

; table of pitch indexes into WaveStart table
PitchStartMap
        DCB     5
        DCB     5
        DCB     6,6
        DCB     7,7,7,7
        DCB     8,8,8,8,8,8,8,8
        DCB     9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
        DCB     10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10
        DCB     10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10
        DCB     11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
        DCB     11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
        DCB     11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
        DCB     11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
        DCB     12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12
        DCB     12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12
        DCB     12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12
        DCB     12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12
        DCB     12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12
        DCB     12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12
        DCB     12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12
        DCB     12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12

; hardwired address of the log table
LogAmpPtr
        DCD     SoundLevel1Base + SoundLevel1AmpTable

; fill routines
GateOn ROUT
        STMFD   R13!,{R8,R9}    ; preserve SCCB and the wavetable instance
        LDR     R8,LogAmpPtr    ; volume table
        LDR     R8,[R8]
        LDRB    R1,[R9,#SoundChannelAmpGateB]
        AND     R1,R1,#&7F      ; note amp
        LDRB    R1,[R8,R1,LSL #1] ; get volume scaled amp
        MOV     R1,R1,LSR #1    ; R1 is volume scaled amp (0-127)
        RSB     R1,R1,#127      ; => 0 is max, 127 is min
        LDMIB   R9,{R2-R4}      ; get pitch, timbre, fill counter
        ; determine pitch related start pointer
        MOVS    R0,R2,LSL #18   ; sample rate/4
        ORRCS   R0,R0,#&FF000000 ; if sample rate/2 then force to top
        ADR     R8,PitchStartMap
        LDRB    R0,[R8,R0,LSR #24] ; 8-bit pitch inc
        Pull    "R9"            ; get wavetable descriptor
        LDR     R8,[R9,R0,LSL #2] ; word index the ramp descriptor
        MOV     R8,R8,LSL #3    ; scale to multiple of 8 bytes
        ADD     R0,R9,R8        ; get start ramp
        LDMIA   R0,{R6,R7}
        ; if R7 is zero then exit!
        TEQ     R7,#0           ; should never have null start ramp!
        BEQ     Finished
        FixDuration
        MOV     R0,R7,LSL #16   ; 256-byte segment index
        ADD     R5,R9,R0,LSR #8 ; set wavetable base
        ; R0 is temp
        ; R1 is amp (0-127)
        ; R2 is pitch phase acc
        ;       b31     : unused
        ;       b24-30  : 7 bit magnitude
        ;       b16-23  : phase
        ;       b0-15   : inc for amp.
        ; R3 is segment duration scale factor
        ; R4 is duration
        ; R5 is wavetable base
        ; R6 is N steps
        ; R7 is ptr/segment
        ;       b16-31  : next segment number
        ;       b0-15   : seg wave ptr (DIV 256)
        ; R8 is LogAmpTab/Envelope structure ptr
        ; R9 is data structure base
        MOV     R7,#0
        AND     R0,R6,#&FF
        CMP     R0,#&FF
        ORREQ   R7,R7,#&7F      ; except if full on!
        CMP     R4,#0
        MOVLE   R7,#0
        BLE     GateOffRamp
        B       FillBuffer

GateOff ROUT
        STMFD   R13!,{R8,R9}    ; preserve SCCB and the wavetable instance
        LDR     R8,LogAmpPtr    ; volume table
        LDR     R8,[R8]
        LDRB    R1,[R9,#SoundChannelAmpGateB]
        LDRB    R0,[R9,#SoundChannelFlagsB]
        TST     R0,#SoundChannelActive
        MOVEQ   R1,#0
        AND     R1,R1,#&7F      ; note amp
        MOV     R0,#0
        STR     R0,[R9,#SoundChannelDuration]
        LDRB    R1,[R8,R1,LSL #1]    ; get volume scaled amp
        MOV     R1,R1,LSR #1    ; R1 is volume scaled amp (0-127)
        RSB     R1,R1,#127      ; => 0 is max, 127 is min
        LDMIB   R9,{R2-R7}      ; get regs (should be sensible as on)
        Pull    "R9"            ; get wavetable base
        CMP     R4,#0
        MOVLE   R7,#0

GateOffRamp
        LDR     R8,[R9,#WaveEnd]
        MOV     R8,R8,LSL #3    ; point to segment descriptor
        ;; 5-June-87
        ADD     R0,R9,R8        ; address it
        AND     R5,R7,#&7F      ; preserve amp
        ;; fix
        LDMIA   R0,{R6,R7}      ; get next env. segment
        ; if top and bottom of R7 are zero then exit!
        TEQ     R7,#0
        BEQ     Finished
        FixDuration
        MOV     R0,R7,LSL #16   ; 256-byte segment index
        MOV     R7,R5           ; current amp
        ADD     R5,R9,R0,LSR #8 ; set wavetable base
        B       FillBuffer

Fill ROUT ; taking account of current volume!
        STMFD   R13!,{R8,R9}    ; preserve SCCB and the wavetable instance
        LDR     R8,LogAmpPtr    ; volume table
        LDR     R8,[R8]
        LDRB    R1,[R9,#SoundChannelAmpGateB]
        
        AND     R1,R1,#&7F      ; note amp
        LDRB    R1,[R8,R1,LSL #1] ; get volume scaled amp
        MOV     R1,R1,LSR #1    ; R1 is volume scaled amp (0-127)
        RSB     R1,R1,#127      ; => 0 is max, 127 is min
        LDMIB   R9,{R2-R8}
        
        Pull    "R9"            ; get wavetable base
        CMP     R4,#0
        BEQ     GateOffRamp

FillBuffer
        AND     R0,R7,#&7F
        RSB     R0,R0,#127
        BIC     R1,R1,#&FF000000
        ORR     R1,R1,R1,LSL #24
        ADD     R1,R1,R0,LSL #24 ; low half is volume scaled note amp
FillLoop
Fill0
        TST     R6,#&00000100   ; check for sample(x4) count
        BNE     Fill0A
        SUBS    R6,R6,#&00000200
        BMI     FillTime0
Fill0A
        CMP     R12,R10         ; check for end of buffer
        BGE     FillDone
        ; now the four samples
        LDRB    R0,[R5,R2,LSR #24] ; amplitude modulate the next four samples
        SUBS    R0,R0,R1,LSR #23
        MOVMI   R0,#0
      [ VIDC_Type = "VIDC1"
        ORR     R0,R0,R0,LSL #8
        MOV     R0,R0,LSR #1
      ]
        STRB    R0,[R12],R11
        ADDS    R2,R2,R2,LSL #16
        BCS     Fix1
Fill1
        LDRB    R0,[R5,R2,LSR #24]
        SUBS    R0,R0,R1,LSR #23
        MOVMI   R0,#0
      [ VIDC_Type = "VIDC1"
        ORR     R0,R0,R0,LSL #8
        MOV     R0,R0,LSR #1
      ]
        STRB    R0,[R12],R11
        ADDS    R2,R2,R2,LSL #16
        BCS     Fix2
Fill2
        LDRB    R0,[R5,R2,LSR #24]
        SUBS    R0,R0,R1,LSR #23
        MOVMI   R0,#0
      [ VIDC_Type = "VIDC1"
        ORR     R0,R0,R0,LSL #8
        MOV     R0,R0,LSR #1
      ]
        STRB    R0,[R12],R11
        ADDS    R2,R2,R2,LSL #16
        BCS     Fix3
Fill3
        LDRB    R0,[R5,R2,LSR #24]
        SUBS    R0,R0,R1,LSR #23
        MOVMI   R0,#0
      [ VIDC_Type = "VIDC1"
        ORR     R0,R0,R0,LSL #8
        MOV     R0,R0,LSR #1
      ]
        STRB    R0,[R12],R11
        ADDS    R2,R2,R2,LSL #16
        BCC     FillLoop        ; else fall through..
        
        ; R6 is count
        ; R7 is ptr,segment
        ; R8 is current segment descriptor
        ; R9 is wavetable base pointer
Fix0
        TST     R6,#&00000100   ; check for wave cycle count
        SUBNE   R6,R6,#&00000200
        CMP     R6,#0           ; underflow on time or wavecycles?
        BPL     Fill0
        ADR     R0,Fill0
        B       Advance
Fix1
        TST     R6,#&00000100
        SUBNE   R6,R6,#&00000200
        CMP     R6,#0
        BPL     Fill1
        ADR     R0,Fill1
        B       Advance
Fix2
        TST     R6,#&00000100
        SUBNE   R6,R6,#&00000200
        CMP     R6,#0
        BPL     Fill2
        ADR     R0,Fill2
        B       Advance
Fix3
        TST     R6,#&00000100
        SUBNE   R6,R6,#&00000200
        CMP     R6,#0
        BPL     Fill3
        ADR     R0,Fill3
        B       Advance
FillTime0
        ANDS    R0,R6,#&FF
        BEQ     Fill0A          ; return and wait for wave crossing
        CMP     R0,#&FF
        BEQ     Fill0A          ; return and wait for wave crossing
        TST     R0,#&80
        AND     R0,R0,#&7F      ; mask out direction
        BEQ     FillTimeRampUp
        SUB     R7,R7,#1
        CMP     R7,R0
        MOVLT   R7,R0           ; fix underflow
        BLT     Fill0A          ; return and wait for wave crossing
        B       FillTimeRampAmp
FillTimeRampUp
        ADD     R7,R7,#1
        CMP     R7,R0
        MOVGT   R7,R0           ; return and wait for wave crossing
        BGT     Fill0A
FillTimeRampAmp
        LDR     R6,[R9,R8]      ; get copy of R6 again
        FixDuration
        AND     R0,R7,#&7F
        RSB     R0,R0,#127
        BIC     R1,R1,#&FF000000
        ORR     R1,R1,R1,LSL #24
        ADD     R1,R1,R0,LSL #24 ; low half is volume scaled note amp
        B       Fill0A          ; return

Advance
        Push    "R0"            ; function to call after advancing
        ; check for reason
        ANDS    R0,R6,#&FF
        BEQ     NextSeg
        CMP     R0,#&FF
        BEQ     NextSeg
        TST     R0,#&80
        AND     R0,R0,#&7F      ; mask out direction
        BEQ     RampUp
RampDown
        SUB     R7,R7,#1
        CMP     R7,R0
        BLT     NextSeg
        B       RampAmp
RampUp
        ADD     R7,R7,#1
        CMP     R7,R0
        BGT     NextSeg
RampAmp
        LDR     R6,[R9,R8]      ; get copy of R6 again
        FixDuration
AmpScale
        AND     R0,R7,#&7F
        RSB     R0,R0,#127
        BIC     R1,R1,#&FF000000
        ORR     R1,R1,R1,LSL #24
        ADD     R1,R1,R0,LSL #24 ; low half is volume scaled note amp
        Pull    "pc"
NextSeg
        AND     R5,R6,#&7F      ; save amp (GOAL)
        ADD     R0,R8,#4        ; get word + 4
        LDR     R0,[R9,R0]      ; get ptr/seg descriptor
        MOV     R0,R0,LSR #16   ; extract next descriptor
        MOV     R8,R0,LSL #3    ; make byte index
        ADD     R0,R9,R8        ; address it
        LDMIA   R0,{R6,R7}      ; get next env. segment
        ; if R7 is zero then exit!
        TEQ     R7,#0
        ADDEQ   R13,R13,#4      ; if end then scrap return
        BEQ     Finished
        FixDuration
        MOV     R0,R7,LSL #16   ; 256-byte segment index
        MOV     R7,R5           ; restore amp
        ADD     R5,R9,R0,LSR #8 ; make wavetable base
        AND     R0,R6,#&FF
        CMP     R0,#&FF
        ORREQ   R7,R7,#&7F      ; except if full on!
        B       AmpScale

FillDone
        SUBS    R4,R4,#1        ; dec. duration
        BEQ     GateOffRamp
        MOV     R0,#SoundChannelActive
        Pull    "R9"            ; get SCCB
        STMIB   R9,{R2-R8}      ; R0 is set up
        Pull    "pc"            ; return to level 1

Finished ROUT
        Pull    "R9"            ; get SCCB
        MOV     R2,#0           ; clear phase!
        STMIB   R9,{R2-R8}
        CMP     R12,R10
10      STRLTB  R2,[R12],R11    ; clear remainder of buffer
        CMPLT   R12,R10
        STRLTB  R2,[R12],R11
        CMPLT   R12,R10
        STRLTB  R2,[R12],R11
        CMPLT   R12,R10
        STRLTB  R2,[R12],R11
        CMPLT   R12,R10
        BLT     %10
        MOV     R0,#SoundChannelFlush2
        Pull    "pc"            ; return to level 1

End_Of_Code

WaveTable0
        ; start of header
        DCB     "!WT:"          ; magic id word
WaveNameStart
        DCB     "Beep"
        DCB     0,0,0,0
        DCB     0,0,0,0         ; room for MAX 11-char name + 0 terminator
WaveLen * . - WaveTable0
        DCD     End_Of_WaveTable-WaveTable0   ; total length
WaveStart * . - WaveTable0
        DCD     8,8,8,8,8,8,8,8 ; for 'Beep' all pitches start with descriptor 8
WaveEnd * . - WaveTable0
        DCD     11              ; release ramp ptr
        DCD     0,0             ; padding
        ; end of header
        ASSERT  (. - WaveTable0) = 16*4

; Descriptor format
; --------
; b0-6    : amplitude target for this segment } special value &FF means "fully on
; b7      : ramp direction (1=down)           } with a ramp of 0 gradient"
; b8      : set to count samples rather than completed waves
; b9-b31  : duration of this portion of the ADSR envelope
; --------
; b0-15   : offset from magic word to wave table to use (multiple of 256)
; b16-b31 : next descriptor number
; --------

        ; offset 64 (index 8)
        ; descriptor 8 (ATTACK)
        DCD     &0000007F + 1:SHL:9
        DCD     &00090001
        ; descriptor 9 (DECAY)
        DCD     &000000F0 + 31:SHL:9
        DCD     &000A0001
        ; descriptor 10 (SUSTAIN)
        DCD     &00000080 + 500:SHL:9
        DCD     &000C0001
        ; descriptor 11 (release)
        DCD     &00000080 + 1:SHL:9
        DCD     &000C0001
        ; descriptor 12 (Dead)
        DCD     0
        DCD     0

        % 256 - (. - WaveTable0)

        ; One WaveTable data segment (in VIDC sample format, so bit 0 = sign)
        DCB     &40,&68,&80,&8C,&9A,&A2,&A8,&AE,&B6,&BC,&C0,&C4,&C6,&CA,&CC,&D0
        DCB     &D2,&D4,&D8,&DA,&DE,&E0,&E0,&E2,&E4,&E4,&E6,&E8,&E8,&EA,&EA,&EC
        DCB     &EE,&EE,&F0,&F0,&F2,&F2,&F4,&F4,&F4,&F6,&F6,&F8,&F8,&F8,&FA,&FA
        DCB     &FA,&FC,&FC,&FC,&FC,&FE,&FE,&FE,&FE,&FE,&FE,&FE,&FE,&FE,&FE,&FE
        DCB     &FE,&FE,&FE,&FE,&FE,&FE,&FE,&FE,&FE,&FE,&FE,&FC,&FC,&FC,&FC,&FA
        DCB     &FA,&FA,&F8,&F8,&F8,&F6,&F6,&F4,&F4,&F4,&F2,&F2,&F0,&F0,&EE,&EE
        DCB     &EC,&EA,&EA,&E8,&E8,&E6,&E4,&E4,&E2,&E0,&E0,&DE,&DA,&D8,&D4,&D2
        DCB     &D0,&CC,&CA,&C6,&C4,&C0,&BC,&B6,&AE,&A8,&A2,&9A,&8C,&80,&68,&40
        DCB     &41,&69,&81,&8D,&9B,&A3,&A9,&AF,&B7,&BD,&C1,&C5,&C7,&CB,&CD,&D1
        DCB     &D3,&D5,&D9,&DB,&DF,&E1,&E1,&E3,&E5,&E5,&E7,&E9,&E9,&EB,&EB,&ED
        DCB     &EF,&EF,&F1,&F1,&F3,&F3,&F5,&F5,&F5,&F7,&F7,&F9,&F9,&F9,&FB,&FB
        DCB     &FB,&FD,&FD,&FD,&FD,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF
        DCB     &FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FD,&FD,&FD,&FD,&FB
        DCB     &FB,&FB,&F9,&F9,&F9,&F7,&F7,&F5,&F5,&F5,&F3,&F3,&F1,&F1,&EF,&EF
        DCB     &ED,&EB,&EB,&E9,&E9,&E7,&E5,&E5,&E3,&E1,&E1,&DF,&DB,&D9,&D5,&D3
        DCB     &D1,&CD,&CB,&C7,&C5,&C1,&BD,&B7,&AF,&A9,&A3,&9B,&8D,&81,&69,&41
End_Of_WaveTable
CopyLimit
        ALIGN
AmountToCopy      DCD CopyLimit - WorkSpaceImage
BeepWorkSpaceSize DCD CopyLimit - WorkSpaceImage
WaveBase          DCD End_Of_Code - WorkSpaceImage

        GET     MsgCode.s

        END
