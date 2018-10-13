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

        MACRO
        GVEntry $name
        ASSERT  . - GraphicsV_Table = GraphicsV_$name * 4
        B       GV_$name
        MEND

        MACRO
        RIEntry $name
        ASSERT  . - ReadInfo_Table = GVReadInfo_$name * 4
        B       RI_$name
        MEND

; Reason code is in R4 lower bytes. bits 31..24 = display number, default 0
GraphicsV_Handler
        Push    "lr"
        LDRB    lr, [r12, #:INDEX:GVinstance]
        EOR     lr, r4, lr, LSL #24  ; the below test will fail if this is the wrong driver
        CMP     lr, #(GraphicsV_TableEnd - GraphicsV_Table) / 4
        ADDLO   pc, pc, lr, LSL #2
        Pull    "pc"
GraphicsV_Table
        Pull    "pc"                 ;
        Pull    "pc"                 ; GV_VSync irq occurred
        GVEntry SetMode              ; GV_SetMode
        Pull    "pc"                 ; GV_SetInterlace
        GVEntry SetBlank             ; GV_SetBlank
        GVEntry UpdatePointer        ; GV_UpdatePointer
        GVEntry SetDMAAddress        ; GV_SetAddress
        GVEntry VetMode              ; GV_VetMode
        GVEntry DisplayFeatures      ; GV_Features
        Pull    "pc"                 ; GV_FramestoreAddress
        GVEntry WritePaletteEntry    ; GV_WritePaletteEntry
        GVEntry WritePaletteEntries  ; GV_WritePaletteEntries
        Pull    "pc"                 ; GV_ReadPaletteEntry
        Pull    "pc"                 ; GV_Render
        GVEntry IICOp                ; GV_IICOp
        Pull    "pc"                 ; GV_SelectHead
      [ CustomBits
        GVEntry StartupMode          ; GV_StartupMode
      |
        Pull    "pc"                 ; GV_StartupMode
      ]
        GVEntry PixelFormats         ; GV_PixelFormats
        GVEntry ReadInfo             ; GV_ReadInfo
GraphicsV_TableEnd

; Note: Most routines claim the vector by pulling lr+pc (but written as ip+pc to avoid deprecated instruction warnings)

GV_VetMode ROUT
        Push    "r1-r3,r5,r8,sb"
        MOV     sb, r12
        MOV     r4, #0
        LDR     r2, [r0, #VIDCList3_Type]
        CMP     r2, #3
        BNE     %FT90
        LDR     r2, [r0, #VIDCList3_PixelRate]
        LDR     lr, =MaxPermittedPixelKHz
        CMP     r2, lr
        BGT     %FT90
        BL      GetIPUFormat
        CMP     r1, #-1
        BEQ     %FT90
        CMP     r3, #0                  ; TODO: Support non-zero ExtraBytes values
        BNE     %FT90
        MOVS    r8, r2                  ; Interlace flag
        MOVNE   r8, #1
      [ SupportInterlace
        ; Interlaced modes require us to be running in HDMI mode
        LDRNEB  r14, HDMIEnabled
        CMPNE   r14, #1
      ]
        BNE     %FT90
        ; Check mode timings - see LoadVideoModeV3 for a reference for these
        ; different calculations

        ; mHActive (HDMI_FC_INHACTV0/1)
        LDR     r2, [r0, #VIDCList3_HorizDisplaySize]
        CMP     r2, #8192
        BHS     %FT90
        ; CPMem has 'stride line' limit of 16KB
        LDR     r5, [r0, #VIDCList3_PixelDepth]
        MOV     r2, r2, LSL r5
        CMP     r2, #16384*8
        BHI     %FT90
        ; Also must be byte multiple?
        TST     r2, #7
        BNE     %FT90
        ; mHSyncOffset (HDMI_FC_HSYNCINDELAY0/1)
        LDR     r2, [r0, #VIDCList3_HorizRightBorder]
        LDR     r5, [r0, #VIDCList3_HorizFrontPorch]
        ADD     r2, r2, r5
        CMP     r2, #8192
        BHS     %FT90
        ; mHSyncPulseWidth (HDMI_FC_HSYNCINWIDTH0/1)
        LDR     r5, [r0, #VIDCList3_HorizSyncWidth]
        CMP     r5, #1024
        BHS     %FT90
        ; mHBlanking (HDMI_FC_INHBLANK0/1)
        ADD     r2, r2, r5
        LDR     r5, [r0, #VIDCList3_HorizBackPorch]
        ADD     r2, r2, r5
        LDR     r5, [r0, #VIDCList3_HorizLeftBorder]
        ADD     r2, r2, r5
        CMP     r2, #8192
        BHS     %FT90

        ; mVActive (HDMI_FC_INVACTIV0/1)
        LDR     r2, [r0, #VIDCList3_VertiDisplaySize]
;        CMP     r2, #8192
;        BHS     %FT90
        ; CPMem has a limit of 4K, use that instead
        MOV     r2, r2, LSL r8
        CMP     r2, #4096
        BHI     %FT90 ; 4096 is valid
        ; mVSyncOffset (HDMI_FC_VSYNCINDELAY)
        LDR     r2, [r0, #VIDCList3_VertiBottomBorder]
        LDR     r5, [r0, #VIDCList3_VertiFrontPorch]
        ADD     r2, r2, r5
        CMP     r2, #256
        BHS     %FT90
        ; mVSyncPulseWidth (HDMI_FC_VSYNCINWIDTH)
        LDR     r5, [r0, #VIDCList3_VertiSyncWidth]
        CMP     r5, #64
        BHS     %FT90
        ; mVBlanking (HDMI_FC_INVBLANK)
        ADD     r2, r2, r5
        LDR     r5, [r0, #VIDCList3_VertiBackPorch]
        ADD     r2, r2, r5
        LDR     r5, [r0, #VIDCList3_VertiTopBorder]
        ADD     r2, r2, r5
        CMP     r2, #256
        BHS     %FT90
        
        MOV     r0,#0                   ; Mode OK
90
        Pull    "r1-r3,r5,r8,sb,ip,pc"

GV_SetMode
        Push    "r0-r3,sb"
        MOV     sb, r12
      [ HDMIAudio
        BL      Audio_PreModeChange     ; Returns flags in r4
      ]
        BL      VideoSetMode
      [ HDMIAudio
        BL      Audio_PostModeChange    ; Uses flags from r4
      ]
        MOV     r4, #0
        Pull    "r0-r3,sb,ip,pc"

; set DPMS style blanking on or off
; r0 = 1 for display normal, 0 for display blank
; r1 = 0..3 DPMS_State from mdf.
; 0 = no powersaving...
; 1 = standby
; 2 = suspend
; 3 = poweroff

GV_SetBlank
        Push    "r0-r3,sb"
        MOV     sb, r12
        teq     r0, #0
        ldr     r0, =&801f0000          ; clear the power on bit if off needed
        bicne   r0, r0, #&00100000
        bl      HDMI_PhyI2cWrite
        MOV     r4, #0
        Pull    "r0-r3,sb,ip,pc"

GV_UpdatePointer
        Push    "r0-r3,sb"
        MOV     sb, r12
        BL      VideoUpdatePointer
        CMP     r0, #0
        MOVNE   r4, #0
        Pull    "r0-r3,sb,ip,pc"

GV_SetDMAAddress
        Push    "r0-r3,sb"
        MOV     sb, r12
        BL      VideoSetDAG
        MOV     r4, #0
        Pull    "r0-r3,sb,ip,pc"

GV_DisplayFeatures
        Push    "sb"
        MOV     sb, r12
        MOV     r0, #0
      [ HardwarePointer
        ; Only claim full hardware pointer support if mode is <= 2048x2048
        LDR     r1, mwidth
        LDR     r2, mheight
        CMP     r1, #2048
        CMPLE   r2, #2048
        ORRLE   r0, r0, #GVDisplayFeature_HardwarePointer
      ]
        MOV     r1, #2_111100           ; 4,8,16,32bpp supported.
        MOV     r2, #4
        MOV     r4, #0
        Pull    "sb,ip,pc"

GV_WritePaletteEntry ROUT
        Push    "r0-r3,sb"
        MOV     sb, r12
        BL      VideoWritePaletteEntry
        MOV     r4, #0
        Pull    "r0-r3,sb,ip,pc"

GV_WritePaletteEntries ROUT
        Push    "r0-r3,sb"
        MOV     sb, r12
        BL      VideoWritePaletteEntries
        MOV     r4, #0
        Pull    "r0-r3,sb,ip,pc"

GV_IICOp ROUT
        ; => r0 = b0-15 offset to start at
        ;         b16-23 base address of IIC device
        ;    r1 = pointer to buffer
        ;    r2 = number of bytes to transfer
        ; <= r0 = 0 or error
        ;    r1 = advanced by number of bytes transferred
        ;    r2 = number of bytes not transferred
        ; Call through to the HAL
        Push    "r1-r3,r8-r9"
        Push    "r2" ; HAL writes bytes transferred via a pointer
        MOV     r2, sp
        MOV     r8, #OSHW_CallHAL
        MOV     r9, #EntryNo_HAL_VideoIICOp
        SWI     XOS_Hardware
        Pull    "r8"
        Pull    "r1-r3"
        ADD     r1, r1, r8 ; Advance pointer
        SUB     r2, r2, r8 ; Bytes not transferred
        MOV     r4, #0
        Pull    "r8-r9,ip,pc"

 [ CustomBits
GV_StartupMode
        Push    "sb"
        MOV     sb, r12
        LDRB    r0, MonitorType
        TEQ     r0, #MonitorTypeEDID
        ADRNEL  r0, startupmode     ; define if not EDID
        MOVNE   r4, #0
        Pull    "sb,ip,pc"
 ]

GV_PixelFormats
        ADRL    r0, VPFList
        MOV     r1, #VPFListEntries
        MOV     r4, #0
        Pull    "ip,pc"

GV_ReadInfo ROUT
        Push    "r0-r4"
        CMP     r0, #(ReadInfo_TableEnd - ReadInfo_Table) / 4
        ADDLO   pc, pc, r0, LSL #2
        Pull    "r0-r4,ip,pc"
ReadInfo_Table
        RIEntry Version
        RIEntry ModuleName
        RIEntry DriverName
        RIEntry HardwareName
        RIEntry ControlListItems
ReadInfo_TableEnd

        GBLA    VersionBCD
VersionBCD SETBCD Module_Version

VersionBCDVal DCD VersionBCD<<8

ControlListItems
        DCD     ControlList_Interlaced
        DCD     ControlList_ExtraBytes
        DCD     ControlList_NColour
        DCD     ControlList_ModeFlags
        DCD     ControlList_Terminator
ControlListItems_End

RI_Version
        ADR     r3, VersionBCDVal
        MOV     r4, #4
        B       %FT10

RI_ModuleName
RI_DriverName
        ADRL    r3, Title
        B       %FT05

RI_HardwareName
        LDR     r3, [r12, #:INDEX:HALDevice]
        TEQ     r3, #0
        LDRNE   r3, [r3, #HALDevice_Description]
05
        MOV     r4, #0
        TEQ     r3, #0
06
        LDRNEB  r0, [r3, r4]
        ADDNE   r4, r4, #1
        TEQNE   r0, #0
        BNE     %BT06
        B       %FT10

RI_ControlListItems
        ADRL    r3, ControlListItems
        MOV     r4, #ControlListItems_End-ControlListItems
10
        TEQ     r4, #0
        Pull    "r0-r4,pc", EQ
        CMP     r4, r2
        SUB     lr, r2, r4
        MOVLT   r2, r4
        STR     lr, [sp, #8]
20
        SUBS    r2, r2, #1
        LDRGEB  r0, [r3], #1
        STRGEB  r0, [r1], #1
        BGT     %BT20
        MOV     r4, #0
        STR     r4, [sp, #16]
        Pull    "r0-r4,ip,pc"

        END
