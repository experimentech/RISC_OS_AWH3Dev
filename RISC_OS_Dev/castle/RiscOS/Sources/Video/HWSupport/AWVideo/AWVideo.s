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
        ; You'll often see these prefixed with Hdr: for historic reasons.
        ; This is no longer necessary, and in fact omitting them makes it
        ; possible to cross-compile your source code.
        GET     ListOpts
        GET     Macros
        GET     System
        GET     ModHand
        GET     Services
        GET     ResourceFS
        GET     VersionASM
        GET     Proc
        GET     FSNumbers
        GET     HighFSI
        GET     NewErrors
        GET     VideoDevice
        GET     HALEntries
        GET     VidcList
        GET     PCI
        GET     GraphicsV
        GET     VduExt
        GET     AudioDevice
        GET     VFPSupport
        GET     OSMisc
        GET     MsgTrans
        GET     CMOS
        GET     ScrModes

        GBLL    Debug
Debug   SETL    {FALSE};{TRUE};

        ; Allow disable of hardware pointer for testing
        GBLL    HardwarePointer
HardwarePointer SETL {TRUE}

        GBLL    SupportInterlace
SupportInterlace SETL {FALSE} ; Interlaced modes aren't fully working at the moment - needs debugging

        ; Enable/disable HDMI audio code
        GBLL    HDMIAudio
HDMIAudio       SETL {TRUE}

        ; StereoReverse {TRUE} -> we perform stereo reversal
        ; StereoReverse {FALSE} -> OS performs stereo reversal
        ; Should generally be quicker for us to perform it, as it will save the
        ; OS from needing to do a post-process pass on the audio
        GBLL    StereoReverse
StereoReverse   SETL {TRUE}

        ; Support loading ontop of the HAL video driver
  [ :LNOT::DEF: HijackHAL
        GBLL    HijackHAL
HijackHAL       SETL {FALSE}
  ]

        ; Support ReadEDID command + builtin MDF
  [ :LNOT::DEF: CustomBits
         GBLL    CustomBits
CustomBits      SETL {FALSE}
  ]

  [ :LNOT::DEF:standalone
        GBLL    standalone
  ]

        ; Our headers
        GET     Debug
        GET     Video
        GET     iMx6qMemMap
        GET     iMx6qReg
        GET     cpmem
        GET     StaticWS


; Device-specific struct for the VDU device

                        ^ 0
VDUDevSpec_SizeField    # 4 ; Size field
VDUDevSpec_Flags        # 4 ; Misc flags
VDUDevSpec_HDMI_TX_INT  # 4 ; hdmi transmitter interrupt number
VDUDevSpec_CCM_Base     # 4 ; CCM base address
VDUDevSpec_IOMUXC_Base  # 4 ; IOMUXC base address
VDUDevSpec_HDMI_Log     # 4 ; HDMI base address
VDUDevSpec_SRC_Log      # 4 ; System Reset unit logical address
VDUDevSpec_IPU1_Log     # 4 ;
VDUDevSpec_IPU2_Log     # 4 ;
VDUDevSpec_CCMAn_Log    # 4 ;
VDUDevSpec_Size         # 0 ; Size value to write to size field


        ; Assembler modules are conventionally, but not necessarily,
        ; position-independent code. Area name |!| is guaranteed to appear
        ; first in link order, whatever your other areas are named.
        AREA    |!|, CODE, READONLY, PIC

        ENTRY

Module_BaseAddr
        DCD     0 ; Start
        DCD     Init - |Module_BaseAddr|
        DCD     Final - |Module_BaseAddr|
        DCD     ServiceCall - |Module_BaseAddr|; Service call handler
        DCD     Title - |Module_BaseAddr|
        DCD     Help - |Module_BaseAddr|
        DCD     HCKTab -  |Module_BaseAddr|; Keyword table
        DCD     0 ; SWI chunk
        DCD     0 ; SWI handler
        DCD     0 ; SWI table
        DCD     0 ; SWI decoder
        DCD     message_filename - |Module_BaseAddr|
        DCD     Flags - |Module_BaseAddr|

Title   =       Module_ComponentName, 0
Help    =       Module_ComponentName, 9, 9, Module_HelpVersion, 0
        ALIGN
Flags   &       ModuleFlag_32bit

HCKTab
      [ CustomBits
        Command "ReadEDID",  0, 0, 0
      ]
        Command "HDMIOn",  0, 0, International_Help
        Command "HDMIOff", 0, 0, International_Help
        DCB     0
      [ CustomBits
ReadEDID_Help
        DCB     "*ReadEDID loads the available modes from the current monitor's EDID file", 13
ReadEDID_Syntax
        DCB     "Syntax: *ReadEDID", 0
      ]
HDMIOn_Help
        DCB     "CHON", 0
HDMIOn_Syntax
        DCB     "SHON", 0
HDMIOff_Help
        DCB     "CHOF", 0
HDMIOff_Syntax
        DCB     "SHOF", 0
        ALIGN
      [ CustomBits
ReadEDID_Code
        Entry   "sb"
        LDR     sb, [R12]
        ADR     r1, %FT20
        MOV     r0, #OSFile_ReadNoPath
        SWI     XOS_File
        MOVVS   r0, #object_nothing
        CMP     r0, #object_file
        ADREQ   r0, %FT10         ; obliges ScrModes to reload EDID
        ADRNEL  r0, ErrorBlock_FailedEDID
        BLNE    CopyError         ; sets V
        SWIVC   XOS_CLI
        EXIT
10
        DCB     "%LoadModeFile "
20
        DCB     "Resources:$.Resources.ScreenMode.Monitors.EDID0", 0
      ]
HDMIOn_Code
        Entry   "sb"
        MOV     R0, #1
        B       HDMIOnOff_Common

HDMIOff_Code
        ALTENTRY
        MOV     R0, #0
HDMIOnOff_Common
        LDR     sb, [R12]
        LDRB    R1, HDMIEnabled
        CMP     R0, R1
        EXIT    EQ
      [ HDMIAudio
        ; Shutdown audio device if HDMI is being disabled
        CMP     R0, #0
        BLEQ    Audio_Deregister
      ]
        ; Warn the OS that the available modes are about to change
        Push    "r0-r3"
        MOV     r0, #DisplayStatus_Changing
        MOV     r1, #Service_DisplayStatus
        LDRB    r2, GVinstance
      [ CustomBits
        MOV     r3, #0            ; subreason 0 - display changing
      ]
        SWI     XOS_ServiceCall
        Pull    "r0-r3"
        STRB    R0, HDMIEnabled
        ; Reprogram current mode in order to enact the change
        STR     R0, mHdmiDviSel
        BL      ReInitVideoMode
        ; Let the OS know that everything is OK
        Push    "r0-r3"
        MOV     r0, #DisplayStatus_Changed
        MOV     r1, #Service_DisplayStatus
        LDRB    r2, GVinstance
      [ CustomBits
        MOV     r3, #0            ; subreason 0 - display changing
      ]
        SWI     XOS_ServiceCall
        Pull    "r0-r3"
      [ HDMIAudio
        ; Re-register audio device if HDMI now on
        CMP     R0, #0
        BLNE    Audio_Register
      ]
        EXIT

        ASSERT  Service_PostInit < Service_ModulePostInit
        ASSERT  Service_ModulePostInit < Service_ModulePostFinal
ServiceCallTable
        DCD     0
        DCD     ServiceCallEntry - Module_BaseAddr
      [ CustomBits
        DCD     Service_PostInit
      ]
      [ HDMIAudio
        DCD     Service_ModulePostInit
        DCD     Service_ModulePostFinal
      ]
        DCD     0

        DCD     ServiceCallTable - Module_BaseAddr
ServiceCall     ROUT
        MOV     r0, r0
        TEQ     r1, #Service_PostInit
      [ HDMIAudio
        TEQNE   r1,#Service_ModulePostInit
        TEQNE   r1,#Service_ModulePostFinal
      ]
        MOVNE   pc, lr

ServiceCallEntry
        Entry   "r0-r1,sb"
        LDR     sb, [r12]
      [ HDMIAudio
        TEQ     r1, #Service_ModulePostInit
        TEQNE   r1, #Service_ModulePostFinal
        BNE     %FT80
        ADR     r0, Module_VFPSupport
        BL      mystrcmp
        BLEQ    VFPInitFinal
        B       %FT90
      ]
80
      [ CustomBits
        ; Service_PostInit
        adrl    r0, loadmodefilecommand         ; do this if EDID not configured
        swi     XOS_CLI
        ldrb    r0, MonitorType
        teq     r0, #MonitorTypeEDID
        bne     %ft90
        mov     r0, #0
        mov     r1, #Service_DisplayChanged
        ldrb    r2, GVinstance
        mov     r3, #1             ; r3=1 obliges ScrModes to reload EDID
        swi     XOS_ServiceCall
        MOV     r0, #1
        SWI     XOS_ScreenMode
        MOVVC   r0, #0
        SWIVC   XOS_ScreenMode
      ]
90
        CLRV
        EXIT

mystrcmp ROUT
        ; Compare r0 with r2
        ; Exit EQ if equal
        Entry   "r0-r2"
10
        LDRB    r1, [r0], #1
        LDRB    lr, [r2], #1
        CMP     r1, lr
        EXIT    NE
        CMP     r1, #0
        BNE     %BT10
        EXIT

 [ HDMIAudio
Module_VFPSupport
        DCB     "VFPSupport", 0
        ALIGN
VFPInitFinal ROUT
        Entry
        CMP     r1, #Service_ModulePostInit
        BEQ     %FT50
        ; ModulePostFinal
        ; VFPSupport actually issues this manually, just before it shuts down
        ; This allows us to clean up properly (unlike a real PostFinal)
        BL      Audio_Deregister ; Deregistering is the easiest way of stopping playback
        BL      Finalise_NEON
        EXIT
50
        ; ModulePostInit
        ; Attempt to re-register if HDMI is enabled (will automatically create VFP context)
        LDRB    lr, HDMIEnabled
        CMP     lr, #0
        BLNE    Audio_Register
        EXIT
 ]


Init    ROUT
        Entry   "r8,sb"
        IMPORT  __RelocCode
        BL      __RelocCode

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =TotalRAMRequired
        SWI     XOS_Module
        EXIT    VS

        STR     r2, [r12]
        mov     sb, r2
        MOV     r6, #0
01
        SUBS    r3, r3, #4
        STR     r6, [r2], #4
        BGT     %BT01

; Get DMB_Write ARMop
        LDR     r0, =MMUCReason_GetARMop+(ARMop_DMB_Write:SHL:8)
        SWI     XOS_MMUControl
        ADRVSL  r0, NullFunc
        STR     r0, DMB_Write

      [ standalone :LOR: CustomBits
; register an MDF with our default startup mode in it so HAL_VideoStartupMode
; or GraphicsV_VideoStartupMode can be to our liking
        ADRL    R0,resourcefsfiles
        SWI     XResourceFS_RegisterFiles
        BVS     ExitInitModule
        ORR     R6, R6, #InitFlag_ResFiles
      ]

; locate the Video device address.. HAL should have registered it by now
        mov     r1, #0                  ; first time through
05
        ldr     r0, = HALDeviceType_Video + HALDeviceVideo_VDU +(HALDeviceID_VDU_IMX6<<16)
        mov     r8, #OSHW_DeviceEnumerate
        swi     XOS_Hardware
        CMP     r1, #-1                 ; if -1, no find the Video device
        BNE     %FT10
        ADRL    r0, ErrorBlock_HardwareDepends ; else we cannot do anything here
        BL      CopyError
        B       ExitInitModule
10
        LDR     lr, [r2, #HALDevice_VDUDeviceSpecificField]
      [ :LNOT: HijackHAL
        LDR     r0, [lr, #VDUDevSpec_Flags]
        TST     r0, #1                  ; Bit 1 will be set if video is in HAL - if we don't support that, look for another device (and most likely throw an error)
        BNE     %BT05
      ]

        STR     r2, HALDevice

        LDR     r0, [lr, #VDUDevSpec_CCM_Base]
        STR     r0, CCM_Base
        LDR     r0, [lr, #VDUDevSpec_IOMUXC_Base]
        STR     r0, IOMUXC_Base
        LDR     r0, [lr, #VDUDevSpec_HDMI_Log]
        STR     r0, HDMI_Log
        LDR     r0, [lr, #VDUDevSpec_SRC_Log]
        STR     r0, SRC_Log
        LDR     r0, [lr, #VDUDevSpec_IPU1_Log]
        STR     r0, IPU1_Log
        LDR     r0, [lr, #VDUDevSpec_IPU2_Log]
        STR     r0, IPU2_Log
        LDR     r0, [lr, #VDUDevSpec_CCMAn_Log]
        STR     r0, CCMAn_Log

 [ HardwarePointer
        ; Allocate some memory for the pointer image
        mov     a1, #HW_CURSOR_WIDTH*HW_CURSOR_HEIGHT*4
        mov     a2, #HW_CURSOR_WIDTH*4
        mov     a3, #0
        swi     XPCI_RAMAlloc
        bvs     ExitInitModule
        str     a1, PointerLog
        str     a2, PointerPhys
        ;DebugReg a1, "PointerLog "
        ;DebugReg a1, "PointerPhys "
 ]

      [ CustomBits
        MOV     r0, #ReadCMOS
        MOV     r1, #VduCMOS
        SWI     XOS_Byte
        MOV     r0, #MonitorType4       ; default to svga
        ANDVC   r0, r2, #MonitorTypeBits; clear out irrelevant bits
        STRB    r0, MonitorType         ; remember if EDID monitor configured
      ]

      [ HijackHAL
        ; Skip most of this if the HAL driver is active
        LDR     r0, HALDevice
        LDR     r0, [r0, #HALDevice_VDUDeviceSpecificField]
        LDR     r0, [r0, #VDUDevSpec_Flags]
        TST     r0, #1
        BEQ     %FT30
        MOV     r0, #0 ; Hijack the HAL GV driver number (should be 0)
        STRB    r0, GVinstance
        MOV     r0, #GraphicsV                          ; grab GraphicsV
        ADRL    r1, GraphicsV_Handler
        MOV     r2, sb
        SWI     XOS_Claim
        BVS     ExitInitModule
        ORR     r6, r6, #InitFlag_GVClaim+InitFlag_HALHijacked

        ; Trigger a mode change to make sure we're initialised correctly
        MOV     r0, #1
        SWI     XOS_ScreenMode
        MOVVC   r0, #0
        SWIVC   XOS_ScreenMode
        BVS     ExitInitModule
        B       %FT50
30
      ]
        MOV     r0, #ScreenModeReason_RegisterDriver
        MOV     r1, #0
        ADRL    r2, Title
        SWI     XOS_ScreenMode                          ; get a driver number
        BVS     ExitInitModule
        ORR     r6, r6, #InitFlag_GVRegistered
        STRB    r0, GVinstance

        ; Set up the VSync handler
        LDR     r3, HALDevice
        LDR     r0, [r3, #HALDevice_Device]
        ADRL    r1, VSync_Handler
        MOV     r2, sb
        SWI     XOS_ClaimDeviceVector
        BVS     ExitInitModule
        ORR     r6, r6, #InitFlag_VSyncClaim
        LDR     r0, [r3, #HALDevice_Device]
        MOV     r8, #OSHW_CallHAL
        Push    "sb"
        MOV     r9, #EntryNo_HAL_IRQEnable
        SWI     XOS_Hardware
        Pull    "sb"
        BVS     ExitInitModule

        MOV     r0, #GraphicsV                          ; grab GraphicsV
        ADRL    r1, GraphicsV_Handler
        MOV     r2, sb
        SWI     XOS_Claim
        BVS     ExitInitModule
        ORR     r6, r6, #InitFlag_GVClaim

        MOV     r0, #ScreenModeReason_StartDriver
        LDRB    r1, GVinstance
        SWI     XOS_ScreenMode                          ; let the OS know we're ready
        BVS     ExitInitModule
        ORR     r6, r6, #InitFlag_GVStarted

50
      [ HDMIAudio
        BL      Audio_ModInit
      ]
      [ CustomBits
        MOV     r0, #0
        MOV     r1, #Service_DisplayChanged
        LDRB    r2, GVinstance
        MOV     r3, #0
        SWI     XOS_ServiceCall          ; oblige ScrModes to readedid if poss
      ]
ExitInitModule
        STR     r6, InitFlags
        EXIT    VC
        ; Re-use finalisation code to perform a shutdown (but return our error)
        ; N.B. this only works because we don't touch R12 during init
        Push    "r0"
        BL      Final
        Pull    "r0"
        SETV
        EXIT

Final   ROUT
        Entry   "sb"
        LDR     sb, [r12]
        LDR     r6, InitFlags

      [ HDMIAudio
        BL      Audio_ModFinal
      ]

        CLRV
        TST     r6, #InitFlag_GVStarted
        MOVNE   r0, #ScreenModeReason_StopDriver
        LDRNEB  r1, GVinstance
        SWINE   XOS_ScreenMode                ; tell the OS we're leaving
        BVS     %FT90
        BIC     r6, r6, #InitFlag_GVStarted

        TST     r6, #InitFlag_GVClaim
        MOVNE   r0, #GraphicsV
        ADRNEL  r1, GraphicsV_Handler
        MOVNE   r2, sb
        SWINE   XOS_Release
        BVS     %FT90
        BIC     r6, r6, #InitFlag_GVClaim

      [ HijackHAL
        TST     r6, #InitFlag_HALHijacked
        BEQ     %FT40
        ; Trigger a mode change to make sure the HAL is back in control
        MOV     r0, #1
        SWI     XOS_ScreenMode
        MOVVC   r0, #0
        SWIVC   XOS_ScreenMode
        CLRV ; Ignore any error that comes through from this, it's not our fault if the kernel/HAL can't find a suitable mode
        BIC     r6, r6, #InitFlag_HALHijacked
40
      ]

        TST     r6, #InitFlag_VSyncClaim
        LDRNE   r0, HALDevice
        LDRNE   r0, [r0, #HALDevice_Device]
        ADRNEL  r1, VSync_Handler
        MOVNE   r2, sb
        SWINE   XOS_ReleaseDeviceVector
        BVS     %FT90
        BIC     r6, r6, #InitFlag_VSyncClaim

        TST     r6, #InitFlag_GVRegistered
        MOVNE   r0, #ScreenModeReason_DeregisterDriver
        LDRNEB  r1, GVinstance
        SWINE   XOS_ScreenMode
        BVS     %FT90
        BIC     r6, r6, #InitFlag_GVRegistered

        LDR     r0, PointerLog
        CMP     r0, #0
        SWINE   XPCI_RAMFree
        CLRV ; A potential memory leak isn't so bad, ignore any error from here
        MOV     r0, #0
        STR     r0, PointerLog
        STR     r0, PointerPhys

        BL      close_messagefile

      [ standalone :LOR: CustomBits
        TST     R6,#InitFlag_ResFiles
        ADRNEL  R0,resourcefsfiles
        SWINE   XResourceFS_DeregisterFiles
        BVS     %FT90
        BIC     R6,R6,#InitFlag_ResFiles
      ]

90
        STR     r6, InitFlags
        EXIT

HAL_CounterDelay ROUT
        Entry   "r8,r9"
        MOV     r8,#OSHW_CallHAL
        MOV     r9,#EntryNo_HAL_CounterDelay
        SWI     XOS_Hardware
        EXIT

VSync_Handler
        Entry   "r0-r5,r8,sb"
        ; Drop into SVC mode for SWI calls
        MRS     r5, CPSR
        ORR     r0, r5, #SVC32_mode
        MSR     CPSR_c, r0
        Push    "lr"
        MOV     sb, r12
        ; Clear the IRQ
        LDR     a2, IPU1_Log
        ADD     a2, a2, #IPU_REGISTERS_OFFSET
        MVN     a3, #0
        ; AW hardware differs to ImX6 IPU??????
        STR     a3, [a2, #IPU_IPU_INT_STAT_15_OFFSET-IPU_REGISTERS_OFFSET]
        LDR     r0, HALDevice
        LDR     r0, [r0, #HALDevice_Device]
        MOV     r8, #OSHW_CallHAL
        Push    "sb"
        MOV     r9, #EntryNo_HAL_IRQClear
        SWI     XOS_Hardware
        Pull    "sb"
        ; Trigger VSync in OS
        LDRB    r4, GVinstance
        MOV     r9, #GraphicsV
        MOV     r4, r4, LSL #24
        ORR     r4, r4, #GraphicsV_VSync
        SWI     XOS_CallAVector
        Pull    "lr"
        MSR     CPSR_c, r5
        EXIT

NullFunc
        MOV     pc, lr

CopyError ROUT
        Entry   "r0-r7"
        BL      open_messagefile
        EXIT    VS
        ADR     R1, MessageFile_Block
        MOV     R2, #0
        MOV     R4, #0
        MOV     R5, #0
        MOV     R6, #0
        MOV     R7, #0
        SWI     XMessageTrans_ErrorLookup
        STR     r0, [sp]
        EXIT

message_filename
        DCB     "Resources:$.Resources.IMXVideo.Messages", 0
        ALIGN

open_messagefile ROUT
        Entry   "r0-r2"
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

close_messagefile ROUT
        Entry   "r0"
        LDR     r0, MessageFile_Open
        CMP     r0, #0
        ADRNE   r0, MessageFile_Block
        SWINE   XMessageTrans_CloseFile
        CLRV
        MOV     r0, #0
        STR     r0, MessageFile_Open
        EXIT

        LTORG

      [ CustomBits
; make sure the command matches the resource file below!!
loadmodefilecommand
        DCB     "loadmodefile Resources:Resources.IMXVideo.IMX6Mon",0
        ALIGN
      ]

resourcefsfiles
      [ CustomBits
        ResourceFile    Resources.IMX6Mon, Resources.IMXVideo.IMX6Mon
      ]
      [ standalone
        ResourceFile    $MergedMsgs, Resources.IMXVideo.Messages
      ]
        DCD     0                   ; terminator
        GET     s.GraphicsV
        GET     s.Debug
        GET     s.Video
      [ HDMIAudio
        GET     s.Audio
      ]
        GET     s.Errors
        END
