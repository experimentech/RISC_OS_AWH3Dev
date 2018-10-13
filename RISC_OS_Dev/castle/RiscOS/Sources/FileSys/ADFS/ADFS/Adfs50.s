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
; >Adfs50

        TTL     "Initialisation and FS star commands"

; Change record
; =============
;
; CDP - Christopher Partington, Cambridge Systems Design
; LVR - Lawrence Rust, Cambridge Beacon
;
;
; 08-Mar-91  11:29  LVR
; Merge winchester and floppy driver code.
; IDE configuration and SWIs merged in.
;
; 08-Mar-91  14:13  LVR
; Moved 82C710 test/iniz code from ADFS19
;
; 11-Mar-91  13:43  LVR
; Moved 82C710 test/iniz code after workspace claimed
; Added FIQ claim/release option to SWI ADFS_ProcessDCB
; Added code to support SWI ADFS_ControllerType on floppies
;
; 11-Mar-91  14:54  CDP
; Surplus IDE configuration code removed; the rest tidied.
;
; 12-Mar-91  14:09  LVR
; Routines using MachineID use constants to identify type
;
; 12-Mar-91  14:39  CDP
; Service entry changed to handle Service_ADFSPoduleIDEDying.
;
; 13-Mar-91  11:34  LVR
; DoSwiFlpProcessDCB bug fixed
;
; 14-Mar-91  13:33  LSR
; Restore handling of separate FormatGap1SideN in ADFS_VetFormat
;  which needs updated Hdr.MultiFS
;
; 21-Mar-91  13:50  LVR
; Make iniz of 82C710 conditional on MOS_Version
;
; 22-Mar-91  10:51  JSR
; Make the skew optimisation after gap1 fixing, not before.
; Improve skew optimisation to approximate the skew to 30ms (512 Single density
; bytes; 1024 double density bytes; 2048 quad density bytes; 4096 octal density
; bytes).
;
; 25-Mar-91  16:47  JSR
; Internationalise this.
;
; 26-Mar-91  16:37  CDP
; copy_error1 added.
;
; 04-Apr-91  16:27  CDP
; Removed Debug20-dependent debug (IDE).
;
; 11-Apr-91  11:38  CDP
; Rewrite of code in InitEntry used to determine what FDC is present from
; the result of the OS_ReadSysInfo SWI.
;
; 16-Apr-91  17:02  CDP
; SWI entry point now returns error if SWI out of range (bug in all versions
; to date). Null SWIs also return an error now. The WTEST SWI ECCSandRetries
; now has a name, to be documented as "used for production".
;
; 16-Dec-91  12:10  LVR
; Add ServicePortable handler for FDC power down
;
; 07-Sep-1994 SBP
; Added support for BigDiscs
;
;*End of change record*


FSCreateBlock
 [ FloppyPCI
        DCB     CreateFlag_FloppyEjects
 |
        DCB     CreateFlag_FloppyNeedsFIQ :OR: CreateFlag_FloppyEjects
 ]
        DCB     (CreateFlag_DriveStatusWorks:SHR:8) :OR: (BigBit:SHR:8) :OR: (NewErrorBit:SHR:8)
        DCB     0, fsnumber_adfs
        DCD     AdfsTitle       - org
        DCD     AdfsBootText    - org
        DCD     LowLevelEntry   - org
        DCD     MiscEntry       - org

; >>>>>>>>>
; InitEntry
; >>>>>>>>>

InitEntry ROUT                           ; NO REENTRANCY CHECK NEEDED
        Push    "R7-R11,SB,LR"
        MOV     R11,R12

        BL      ReadNewCMOS0            ;(->R0,R2-R4,V) read #floppies & winnies

        Push    "R3,R4"
        MOV     R0, #ModHandReason_Claim
        LDR     R3,=:INDEX:AWorkSize
 [ DebugI
        DREG    r3, "Workspace size being claimed is "
 ]
        SWI     XOS_Module              ;claim workspace
        Pull    "R3,R4"
        BVS     ErrX                    ; Jump if error
 [ DebugI
        DREG    r2, "Workspace is at "
 ]
        MOV     SB, R2
        STR     SB, [R11]

;initialise most Globals

        baddr   R0, DefGlobals
        sbaddr  R1, DefGlobStart
        MOV     R2, #SzDefGlobals
        BL      BlockMove

;initialise drive records

        ASSERT  DrvFlags=0
        ASSERT  HeadPosition=4
        ASSERT  DrvSequenceNum=8
        ASSERT  SzDrvRec=12
        MOV     R0, #0
        MOV     R1, #PositionUnknown
        MOV     R2, #0
        sbaddr  R5, DrvRecs
        MOV     LR, #8
10
        STMIA   R5!,{R0-R2}
        SUBS    LR, LR, #1
        BNE     %BT10
 [ DebugI
        DLINE   "Statics installed in workspace"
 ]

 [ HAL
        MOV     R8, #OSHW_LookupRoutine

        MOV     R9, #EntryNo_HAL_IRQEnable
        SWI     XOS_Hardware
        BVS     Errfree
        STR     R0, HAL_IRQEnable_routine+4
        STR     R1, HAL_IRQEnable_routine

        MOV     R9, #EntryNo_HAL_IRQDisable
        SWI     XOS_Hardware
        BVS     Errfree
        STR     R0, HAL_IRQDisable_routine+4
        STR     R1, HAL_IRQDisable_routine

        MOV     R9, #EntryNo_HAL_IRQStatus
        SWI     XOS_Hardware
        BVS     Errfree
        STR     R0, HAL_IRQStatus_routine+4
        STR     R1, HAL_IRQStatus_routine

        MOV     R9, #EntryNo_HAL_CounterDelay
        SWI     XOS_Hardware
        BVS     Errfree
        STR     R0, HAL_CounterDelay_routine+4
        STR     R1, HAL_CounterDelay_routine

      [ :LNOT:FloppyPCI
        MOV     R9, #EntryNo_HAL_FIQDisableAll
        SWI     XOS_Hardware
        BVS     Errfree
        STR     R0, HAL_FIQDisableAll_routine+4
        STR     R1, HAL_FIQDisableAll_routine

        MOV     R9, #EntryNo_HAL_FIQEnable
        SWI     XOS_Hardware
        BVS     Errfree
        STR     R0, HAL_FIQEnable_routine+4
        STR     R1, HAL_FIQEnable_routine
      ]

        ; Latch onto the first IDE controller of API 0.00
        LDR     R0,=(HALDeviceType_ExpCtl + HALDeviceExpCtl_IDE) :OR: \
                    (&0000:SHL:16)
        MOV     R1,#0
        MOV     R8,#OSHW_DeviceEnumerate
        SWI     XOS_Hardware
        BVS     Errfree
        CMP     R1,#-1
        BEQ     %FT09                   ; No IDE device found
        STR     R2,HAL_IDEDevice_pointer
        Push    "R12"
        MOV     LR,PC
        LDR     PC,[R2,#HALDevice_Activate]
        Pull    "R12"
        CMP     R0,#0
        BNE     %FT10                   ; Activated OK
09
        ADR     R0,ErrorBlock_BadHard
        MOV     R1,#0
        MOV     R2,#0
        SWI     XMessageTrans_ErrorLookup
        BVS     Errfree
        
        MakeInternatErrorBlock BadHard,,"BadHard"
10
 ]

        MOV     R0,#6
        MOV     R1,#0
        MOV     R2,#OSRSI6_ESC_Status
        SWI     XOS_ReadSysInfo
        MOVVS   R2,#0
        CMP     R2,#0
        LDREQ   R2,=Legacy_ESC_Status
        STR     R2,ptr_ESC_Status

; Check what hardware there is for drivers to talk to

        Push    "R3,R4"
        MOV     R0,#2                   ; Reason code is get IOEB/82710 state
        SWI     XOS_ReadSysInfo         ; (R0->R0-R4)
        Pull    "R3,R4"
Errfree
        MOVVS   R9, R0                  ; Save error ptr
        BVS     ErrXfree                ; Error exit

 [ FloppyPodule:LOR:FloppyPCI
        MOV     R0,#MachHas82710
 |
        TEQS    R0,#0                   ; 0 => no IOEB
        MOVEQ   R0,#MachHas1772         ; if no IOEB, old machine
        MOVNE   R0,#MachHas82710        ; if IOEB, assume 710
        TEQNES  R1,#1                   ; ...and check that it's there
        MOVNE   R0,#MachHasNoFDC        ; if not, no FDC at all
 [ DebugI
        DREG    r0, "Machine ID is "
 ]
 ]
        STR     R0, MachineID           ; Save ID

; Call driver initialization code

        MOV     R9,#0                   ; Assume no errors
 [ DebugI
        DLINE   "FlpInit..."
 ]
        BL      FlpInit                 ; Init the floppy driver (R3->R0,R1,V)
        MOVVS   R9, R0                  ; Save any error
        MOV     R3, R1                  ; Number of responding floppies

 [ DebugI
        DLINE   "WinInit..."
 ]
        BL      WinInit                 ; Init the winchester driver (R4->R0,R1,V)
        MOVVS   R9, R0                  ; Save any error
        MOV     R6, R1                  ; Number of responding hard disks

        TEQS    R9, #0                  ; Any errors during iniz
        BNE     DeIniz                  ; Yes then jump

 [ DebugI
        DLINE   "Read CMOSes in preparation for FileCore_Create..."
 ]
        BL      ReadOldCMOS             ;(->R0,R2,R5,V) read default drive

        ASSERT  DriveConfig_FloppyCount_Shift = 0
        ORR     R3, R3, R6, LSL #DriveConfig_FixedDiscCount_Shift
        ORR     R3, R3, R5, LSL #DriveConfig_DefaultDrive_Shift
        BL      ReadDirCacheCMOS        ;(->R0,R4,V)
 [ FileCache
        BL      ReadFileCacheCMOS       ;(->R0,R5,V)
 |
        MOV     R5, #0
 ]

        MOV     R2, R11                 ;address of private word
 [ BigDisc
        MVN     R6, #0
 |
        LDR     R6, WinnieSizes
 ]
        baddr   R0, FSCreateBlock
        baddr   R1, org
 [ DebugI
        DREG    r0,"FileCore_Create(",cc
        DREG    r1,",",cc
        DREG    r2,",",cc
        DREG    r3,",",cc
        DREG    r4,",",cc
        DREG    r5,",",cc
        DREG    r6,",",cc
        DLINE   ")"
 ]
        SWI     XFileCore_Create        ;(R0-R6->R0-R2,V)
        MOVVS   R9, R0                  ; Save error
        BVS     DeIniz                  ; Jump if error

 [ FileCache
        sbaddr  LR, FileCorePrivate
        ASSERT  FloppyCallAfter = FileCorePrivate + 4
        ASSERT  WinnieCallAfter = FloppyCallAfter + 4
        ASSERT  FiqRelease = WinnieCallAfter + 4
  [ DebugI
        DREG    r0,"Returned from _Create:",cc
        DREG    r1,",",cc
        DREG    r2,",",cc
        DREG    r3,","
  ]
        STMIA   LR, {R0-R3}
 |
        STR     R0, FileCorePrivate
 ]

        SWI     XFileCore_Features
        ANDVC   R0, R0, #Feature_NewErrors
        STRVCB  R0, NewErrorsFlag

 [ DebugI
        DLINE   "ADFS initialised successfully"
 ]
        CLRV
        Pull    "R7-R11,SB,PC"

        LTORG

; Message file handling code

; ----------
; copy_error
; ----------
;
; In    r0 = pointer to error block with text <tag>
; Out   r0 = pointer to translated error block flags preserved
copy_error ROUT
        Push    "r1-r8,lr"
        SavePSR r8
        MOV     R4, #0
10
        CLRV                    ; To avoid interaction with any V set on entry
        BL      open_message_file
        ADRVC   R1, message_file_block
        MOVVC   R2, #0
        MOVVC   R5, #0
        MOVVC   R6, #0
        MOVVC   R7, #0
        SWIVC   XMessageTrans_ErrorLookup
        RestPSR r8
        Pull    "r1-r8,pc"


; In    r0 = pointer to error block with text <tag>
;       r4 = pointer to substitute string
; Out   r0 = pointer to translated error block
;       flags preserved
copy_error1
        Push    "r1-r8,lr"
        SavePSR r8
        B       %BT10


; ----------------
; message_gswrite0
; ----------------
;
; In    r0 = pointer to nul-terminated <tag>
; Out   all regs preserved unless error
message_gswrite0 ROUT
        Push    "r0-r7,lr"
        MOVVC   r4, #0
10
        MOVVC   r5, #0
        MOVVC   r6, #0
30
        MOVVC   r7, #0
        SUB     sp, sp, #256
        BL      open_message_file
        MOVVC   r1, r0
        ADRVC   r0, message_file_block
        MOVVC   r2, sp
        MOVVC   r3, #256
        SWIVC   XMessageTrans_GSLookup
        MOVVC   r0, r2
        MOVVC   r1, r3
        SWIVC   XOS_WriteN
        STRVS   r0, [sp, #256 + 0*4]
        ADD     sp, sp, #256
        Pull    "r0-r7,pc"

; -----------------
; message_gswrite01
; -----------------
;
; In    r0 = pointer to nul-terminated <tag>
;       r4 = pointer to substitute string
; Out   all regs preserved unless error
message_gswrite01
        Push    "r0-r7,lr"
        B       %BT10

; -----------------
; message_gswrite03
; -----------------
;
; In    r0 = pointer to nul-terminated <tag>
;       r4 = pointer to substitute string
;       r5 = pointer to substitute string
;       r6 = pointer to substitute string
; Out   all regs preserved unless error
message_gswrite03
        Push    "r0-r7,lr"
        B       %BT30


message_filename
        DCB     "Resources:$.Resources.ADFS.Messages", 0
        ALIGN

; -----------------
; open_message_file
; -----------------
;
; In    -
; Out   -
open_message_file ROUT
        Push    "r0-r7,lr"

        ; Ensure file not open already
        LDR     r1 , message_file_open
        TEQ     r1, #0
        Pull    "r0-r7,pc",NE

        ; Open it
        ADR     R0, message_file_block
        ADR     R1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile

        MOVVC   r1, #1
        STRVC   r1, message_file_open

        Pull    "r0-r7,pc"


FullTitle
        Text  "FileCore%ADFS"

; >>>>>>>>
; DieEntry
; >>>>>>>>

DieEntry ROUT
        Push    "R7-R11,SB,LR"
        getSB

        MOV     R0, #ModHandReason_Delete
        baddr   R1, FullTitle
        SWI     XOS_Module              ; Delete the module

        MOV     R9, #0                  ; No errors on dying

; DeIniz the drivers

DeIniz
 [ DebugI
        DLINE   "DeInitialise Flp..."
 ]
        BL      FlpDie                  ; Kill the floppy driver
 [ DebugI
        DLINE   "DeInitialise Win..."
 ]
        BL      WinDie                  ; Kill the Winchester driver

; Return static workspace

ErrXfree
 [ DebugI
        DLINE   "Close down messages file..."
 ]
        ; Release message file
        LDR     R0, message_file_open
        TEQ     R0, #0
        ADRNE   R0, message_file_block
        SWINE   XMessageTrans_CloseFile ; Ignore error from this

 [ DebugI
        DLINE   "Free module workspace..."
 ]
        MOV     R0, #ModHandReason_Free
        MOV     R2, SB
        SWI     XOS_Module              ; Free workspace
 [ Dev
        wrhex   R0, VS
        mess    VS,"Heap error",NL
 ]
        ADDS    R0, R9, #0              ; Restore error
        Pull    "R7-R11,SB,PC",EQ       ; if no err, restore regs and return
 [ DebugI
        DREG    r0, "Error block to return "
 ]

ErrX    Pull    "R7-R11,SB,LR"          ; Else restore caller's regs
        B       SetV                    ; And return with error


; >>>>>>>>>>>>
; ServiceEntry
; >>>>>>>>>>>>

        ASSERT  Service_Reset < Service_Portable
        ASSERT  Service_Portable < Service_ModulePostInit
        ASSERT  Service_ModulePostInit < Service_ModulePostFinal
        ASSERT  Service_ModulePostFinal < Service_ADFSPoduleIDEDying
ServiceTable
        DCD     0                               ; flags
        DCD     ServiceEntryUrsula - org
        DCD     Service_Reset
        DCD     Service_Portable
      [ FloppyPCI :LOR: IDEDMA
        DCD     Service_ModulePostInit
      ]
      [ IDEDMA
        DCD     Service_ModulePostFinal
      ]
        DCD     Service_ADFSPoduleIDEDying
        DCD     0

        DCD     ServiceTable - org
ServiceEntry ROUT
        MOV     r0, r0                          ; Fast service table present

        TEQS    R1,#Service_Reset               ; Post reset service call?
        TEQNES  R1,#Service_Portable            ; Portable service?
      [ FloppyPCI :LOR: IDEDMA
        TEQNES  R1,#Service_ModulePostInit      ; DMA manager starting?
      ]
      [ IDEDMA
        TEQNES  R1,#Service_ModulePostFinal     ; DMA manager gone?
      ]
        Push    "LR"
        LDRNE   LR,=Service_ADFSPoduleIDEDying  ; IDE podule dying?
        TEQNES  R1,LR
        Pull    "PC",NE                         ; if no, return
        B       %FT10

ServiceEntryUrsula
        Push    "LR"
10
        getSB

; Check service type again - done this way to speed up handling
; of services we don't want.

        TEQS    R1,#Service_Portable            ; Portable service?
        BEQ     ServicePortablePower            ; Yes then jump

      [ FloppyPCI :LOR: IDEDMA
        TEQS    R1,#Service_ModulePostInit      ; Module starting?
        BEQ     ServiceModulePostInit           ; Yes then jump
      ]

      [ IDEDMA
        TEQS    R1,#Service_ModulePostFinal     ; Module dead?
        BEQ     ServiceModulePostFinal          ; Yes then jump
      ]

        TEQS    R1,#Service_Reset               ; reset?
        Pull    "LR",NE                         ; else IDEPoduleDying
        BNE     WinIDEPoduleDying

; Reset service call - tell drivers

        BL      FlpReset                        ; Claim FDC vectors
        BL      WinReset                        ; Iniz winchester drivers
        Pull    "PC"                            ; Restore caller's regs/flags and return

 [ FloppyPCI :LOR: IDEDMA
; Direct-call re-registration
;
ServiceModulePostInit ROUT
        Push    "R0-R5,R9"
        ADR     R0,DMAManagerTitle
        MOV     R1,R2
        BL      StringCompare
        Pull    "R0-R5,R9,PC",NE
    [ FloppyPCI
        BL      FlpRegisterDMAChannel
    ]
    [ IDEDMA
        sbaddr  R9,WinIDEHardware
        BL      WinIDERegisterDMAChannel
      [ TwinIDEHardware
        ADD     R9,R9,#SzWinIDEHardware
        BL      WinIDERegisterDMAChannel
      ]
    ]
        Pull    "R0-R5,R9,PC"

DMAManagerTitle = "DMAManager", 0
        ALIGN
 ]

 [ IDEDMA
ServiceModulePostFinal ROUT
        Push    "R0-R5,R9"
        ADR     R0,DMAManagerTitle
        MOV     R1,R2
        BL      StringCompare
        Pull    "R0-R5,R9,PC",NE
        sbaddr  R9,WinIDEHardware
        MOV     R0,#-1
        STR     R0,[R9,#WinIDEDMAHandle]
      [ TwinIDEHardware
        STR     R0,[R9,#SzWinIDEHardware+WinIDEDMAHandle]
      ]
        Pull    "R0-R5,R9,PC"

 ]

; Portable power control
;
 [ IDEPower
ServicePortablePower

        TEQS    R2,#ServicePortable_PowerDown   ; Portable power down?
        TEQNES  R2,#ServicePortable_PowerUp     ; Or portable power up?
        Pull    "PC",NE                         ; No then exit

 [ Debug10p
        DREG    R2,"Portable service:"
        DREG    R3,"Units affected:"
 ]
        LDR     LR, Portable_Flags              ; Get power/enable bits
        ORR     LR, LR, #Portable_Present       ; Mark portable being present
        TEQS    R2, #ServicePortable_PowerUp    ; Portable power up?
        BNE     ServPortPwrDown
;Powering up
        ORR     LR, LR, R3                      ; Yes enable units
        STR     LR, Portable_Flags              ; And save new power/enable bits
       ;TST     R3, #PortableControl_FDCEnable
       ;BLNE    ResetFloppyStateMachine
        TST     R3, #PortableControl_IDEEnable
        BLNE    WinIDEResetDrives               ; Suck it and see!
        Pull    "PC"                            ; And exit

ServPortPwrDown
;Powering down
        TSTS    R3, #PortableControl_FDCEnable  ; Disabling FDC
        TSTNES  LR, #PortableControl_FDCEnable  ; And was enabled?
        BEQ     %FT11                           ; No

; Check if ok to disable FDC
        Push    "R9"
        LDRB    R9, FlpDORimage                 ; Get drive selects
        TST     R9, #&F3                        ; Any selects?
        ORRNE   LR, LR, #PortableControl_FDCEnable ; Yes.. ensure FDC enabled (this line redundent?)
        BICNE   R3, R3, #PortableControl_FDCEnable ; Reject powerdown request
        Pull    "R9"

11
; Check if ok to disable IDE
        TSTS    R3, #PortableControl_IDEEnable  ; Disabling IDE
        TSTNES  LR, #PortableControl_IDEEnable  ; And was enabled?
        BEQ     %FT21                           ; No

; check if drive is spinning, reject request if it is
        Push    "R0-R2,LR"
        MOV     R0,#0                           ; read drive spin status
        MOV     R1,#4                           ; drive (4..7)
        SWI     XADFS_PowerControl
        MOVVS   R2,#1                           ; error, assume drive spinning

        TEQ     R2,#0                           ; is drive spinning (0=No)
        Pull    "R0-R2,LR"

        ORRNE   LR, LR, #PortableControl_IDEEnable ; Yes.. ensure IDE enabled (this line redundent?)
        BICNE   R3, R3, #PortableControl_IDEEnable ; Reject powerdown request

21
        BIC     LR, LR, R3                      ; Disable units
        ORR     LR, LR, #Portable_Present       ; Mark portable being present
        STR     LR, Portable_Flags              ; And save power/enable bits

        TEQ     R3, #0
        MOVEQ   R1, #0                          ; Claim call if now 0
        Pull    "PC"                            ; And exit

 |
ServicePortablePower

        TEQS    R2,#ServicePortable_PowerDown   ; Portable power down?
        TEQNES  R2,#ServicePortable_PowerUp     ; Or portable power up?
        Pull    "PC",NE,^                       ; No then exit

 [ Debug10p
        DREG    R2,"Portable service:"
        DREG    R3,"Units affected:"
 ]
        LDR     LR, Portable_Flags              ; Get power/enable bits
        ORR     LR, LR, #Portable_Present       ; Mark portable being present
        TEQS    R2,#ServicePortable_PowerUp     ; Portable power up?
        ORREQ   LR, LR, R3                      ; Yes enable units
        STREQ   LR, Portable_Flags              ; And save new power/enable bits
        Pull    "PC",EQ,^                       ; And exit

        TSTS    R3, #PortableControl_FDCEnable  ; Disabling FDC
        TSTNES  LR, #PortableControl_FDCEnable  ; And was enabled?
        BICEQ   LR, LR, R3                      ; No then disable units
        STREQ   LR, Portable_Flags              ; And save power/enable bits
        Pull    "PC",EQ,^                       ; And exit

; Check if ok to disable FDC

        Push    "R9"
        LDRB    R9, FlpDORimage                 ; Get drive selects
        TST     R9, #&F3                        ; Any selects?
        ORRNE   LR, LR, #PortableControl_FDCEnable ; Yes.. ensure FDC enabled
        STR     LR, Portable_Flags              ; Save power/enable bits
 [ Debug10p
        BNE     %FT00
        DLINE   "Disable FDC"
00
 ]
        Pull    "R9,PC",EQ                      ; Exit if disable OK

 [ Debug10p
        DLINE   "Reject FDC disable"
 ]
        BICS    R3, R3, #PortableControl_FDCEnable ; Reject powerdown request
        MOVEQ   R1, #0                          ; Claim call if now 0
        Pull    "R9,PC"
 ]

DoSwiRetryDiscOp ROUT
        Push    "R8,LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_DiscOp
        Pull    "R8,PC"

 [ BigDisc
DoSwiRetrySectorDiscOp ROUT
        Push    "R8,LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_SectorDiscOp
        Pull    "R8,PC"

DoSwiFreeSpace64 ROUT
        Push    "R8,LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_FreeSpace64
        Pull    "R8,PC"
 ]

DoSwiRetryDiscOp64 ROUT
        Push    "R8,LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_DiscOp64
        Pull    "R8,PC"

DoSwiMiscOp ROUT
        Push    "R8,LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_MiscOp
        Pull    "R8,PC"

DoSwiHDC
        MOV     PC,LR


DoSwiDrives ROUT
        Push    "R8,LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_Drives
        Pull    "R8,PC"


DoSwiFreeSpace ROUT
        Push    "R8,LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_FreeSpace
        Pull    "R8,PC"

DoSwiLockIDE
        CMP     R0, #0                  ; Unlock if R0 = 0
        BEQ     UnlockIDEController

        Push    LR                      ; Else try to lock
        BL      LockIDEController
        Pull    PC, VC                  ; return if not already locked

        baddr   R0,DriverInUseErrBlk    ; Else return error
        Pull    LR
        B       copy_error

;Retry word = (Retry word BIC R0) EOR (R1 AND R0)
;exit R1 = R1 AND R0
; R2 old value, R3 new value

DoSwiRetries
        AND     R1, R1, R0
        ASSERT  :INDEX: WinnieRetries :MOD: 4 = 0
        ASSERT  FloppyRetries       = WinnieRetries + 1
        ASSERT  FloppyMountRetries  = FloppyRetries + 1
        ASSERT  FloppyDefectRetries = FloppyMountRetries + 1
        LDR     R2, WinnieRetries
        BIC     R3, R2, R0
        EOR     R3, R3, R1
        STR     R3, WinnieRetries
        MOV     PC, LR

DoSwiDescribeDisc ROUT
        Push    "R8,LR"
        LDR     R8, FileCorePrivate
        SWI     XFileCore_DescribeDisc
        Pull    "R8,PC"

        LTORG

;---------------------------------------------
;
; MultiFS specific SWI
;
; --------------------------------------------

DensityParameters ; Indexed by density (in bytes, assuming 1.5% speed variation)

        ; Unknown density...
        ^       0
Track_MinLength # 4
        DCD     0
Track_IMPrefixLength # 4
        DCD     0
Track_MinGap1 # 4
        DCD     0
Track_MinGap3 # 4
        DCD     0
Track_MinGap4 # 4
        DCD     0
Track_SectorOverhead # 4
        DCD     4
Track_SzInfo # 0

        ; Single density
        DCD     3125*1000/1015  ; short track size
        DCD     47              ; IM size
        DCD     16              ; Min. gap1
        DCD     11              ; Min. gap3
        DCD     37              ; Min. gap4
        DCD     33              ; Sector Overhead

        ; Double Density
        DCD     6250*1000/1015  ; short track size
        DCD     96              ; IM size
        DCD     32              ; Min. gap1
        DCD     24              ; Min. gap3
        DCD     40              ; Min. gap4
        DCD     62              ; Sector overhead

        ; Double+1 Density
        DCD     5208*1000/1015  ; short track size
        DCD     96              ; IM size
        DCD     32              ; Min. gap1
        DCD     24              ; Min. gap3
        DCD     30              ; Min. gap4
        DCD     62              ; Sector overhead

        ; Quad density
        DCD     12500*1000/1015 ; short track size
        DCD     96              ; IM size
        DCD     32              ; Min. gap1
        DCD     24              ; Min. gap3
        DCD     30              ; Min. gap4
        DCD     62              ; Sector overhead

        ; Unknown density
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     0

        ; Unknown density
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     0

        ; Unknown density
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     0

        ; Octal density
        DCD     25000*1000/1015 ; short track length
        DCD     96              ; IM size
        DCD     32              ; Min. gap1
        DCD     24              ; Min. gap3
        DCD     30              ; Min. gap4
        DCD     81              ; Sector overhead

ControllerParams_1772
        ^       0
Ctrlr_DensityMask # 4
        DCD     2_00000000000000000000000000000110       ; Density support mask
Ctrlr_g1ll # 4
        DCD     0       ; gap1 lower limit (for formatting)
Ctrlr_g1ul # 4
        DCD     &ffffffff ; gap1 upper limit
Ctrlr_g3ll # 4
        DCD     0       ; gap3 lower limit (for formatting)
Ctrlr_g3ul # 4
        DCD     &ffffffff ; gap3 upper limit
Ctrlr_sptl # 1
        DCB     1       ; sectors per track (low)
Ctrlr_spth # 1
        DCB     240     ; sectors per track (high)
Ctrlr_imo # 1
        DCB     0       ; Index mark optional
Ctrlr_tl # 1
        DCB     240     ; tracks limit
Ctrlr_l2ssl # 1
        DCB     7       ; Log2 sector length (low)
Ctrlr_l2ssh # 1
        DCB     10      ; Log2 sector length (high)
Ctrlr_snl # 1
        DCB     0       ; Sector numbering, low limit
Ctrlr_snh # 1
        DCB     255     ; Sector numbering, high limit
Ctrlr_fl # 1
        DCB     0       ; Fill value, low
Ctrlr_fh # 1
        DCB     &f4     ; Fill value, high

Ctrlr_ddfgap1 # 1
        DCB     0       ; gap1 fixed length for non-applicable density
        DCB     0       ; gap1 fixed value for single density
        DCB     0       ; gap1 fixed value for double density

        ALIGN

ControllerParams_82077
ControllerParams_710
        DCD     2_00000000000000000000000000011110       ; Density support mask
        DCD     0       ; gap1 lower limit  (for formatting)
        DCD     &ffffffff ; gap1 upper limit
        DCD     0       ; gap3 lower limit (for formatting)
        DCD     &ff     ; gap3 upper limit

        DCB     0       ; sectors per track (low)
        DCB     255     ; sectors per track (high)
        DCB     1       ; Index mark mandatory
        DCB     255     ; track limit
        DCB     7       ; Log2 sector length (low)
        DCB     14      ; Log2 sector length (high)
        DCB     0       ; Sector numbering, low limit
        DCB     255     ; Sector numbering, high limit
        DCB     0       ; Fill value, low
        DCB     &ff     ; Fill value, high

        DCB     0       ; gap1 fixed length for non-applicable density
        DCB     26      ; gap1 fixed value for single density
        DCB     50      ; gap1 fixed value for double density
        DCB     50      ; gap1 fixed length for double+1 density
        DCB     50      ; gap1 fixed length for quad density
        DCB     0       ; gap1 fixed length for non-applicable density
        DCB     0       ; gap1 fixed length for non-applicable density
        DCB     0       ; gap1 fixed length for non-applicable density
        DCB     50      ; gap1 fixed length for octal density

        ALIGN

; entry: r0 = Pointer to disc format structure to be vetted
;        r1 = Parameter passed to <Image>_DiscFormat in r2
;               (disc number)

; exit: disc format structure updated or error
;       otherwise regs preserved

DoSwiVetFormat ROUT
        Push    "r0-r11,lr"

        ; Reject winnies
        TST     r1, #bit2
        baddr   r0, FormatNotSupportedOnWinnieErrBlk, NE
 [ Debug30
 BEQ    %FT01
 DLINE  "Failed on 'not on a winnie'"
01
 ]
        BNE     %FT90

 [ Support1772
        ; Choose parameter block on machine type
        LDR     lr, MachineID
        TEQ     lr, #MachHas1772
        baddr   r11, ControllerParams_1772, EQ
        baddr   r11, ControllerParams_710, NE
 |
        baddr   r11, ControllerParams_710
 ]
 [ Debug30
 BEQ    %FT01
 DREG   r11,"Paramblock for 710 at "
 B %FT02
01
 DREG   r11,"Paramblock for 1772 at "
02
 ]

        ; Check density supported
        LDRB    r2, [r0, #FormatDensity]
        MOV     lr, #1
        MOV     r3, lr, ASL r2
        LDR     lr, [r11, #Ctrlr_DensityMask]
        TST     lr, r3
        baddr   r0, DensityNotSupportedErrBlk, EQ
 [ Debug30
 BNE    %FT01
 DLINE  "Failed on 'Bad density'"
01
 ]
        BEQ     %FT90

        ; Check sector size a power of 2
        LDR     r2, [r0, #FormatSectorSize]     ; eg 00111000100000 (bad) , or 00000000100000 (good)
        SUB     lr, r2, #1                      ;    00111000011111            00000000011111
        EOR     lr, r2, lr                      ;    00000000111111            00000000111111
        BICS    lr, r2, lr                      ;    00111000000000            00000000000000
        baddr   r0, SectorSizeNotSupportedErrBlk, NE
 [ Debug30
 BEQ    %FT01
 DLINE  "Failed on 'Bad sector size'"
01
 ]
        BNE     %FT90

        ; Check sector size supported
        LDRB    lr, [r11, #Ctrlr_l2ssl]
        MOVS    lr, r2, LSR lr
        baddr   r0, SectorSizeNotSupportedErrBlk, EQ
 [ Debug30
 BNE    %FT01
 DLINE  "Failed on 'Sector size too low'"
01
 ]
        BEQ     %FT90

        LDRB    lr, [r11, #Ctrlr_l2ssh]
        ADD     lr, lr, #1
        MOVS    lr, r2, LSR lr
        baddr   r0, SectorSizeNotSupportedErrBlk, NE
 [ Debug30
 BEQ    %FT01
 DLINE  "Failed on 'Sector size too high'"
01
 ]
        BNE     %FT90

        ; Sector size acceptable

        ; Bound the gap1 sizes
        LDR     r2, [r0, #FormatGap1Side0]
        LDR     lr, [r11, #Ctrlr_g1ll]
        CMP     r2, lr
        MOVLO   r2, lr
        LDR     lr, [r11, #Ctrlr_g1ul]
        CMP     r2, lr
        MOVHI   r2, lr
 [ Debug30
 DREG   r2, "Gap1, Side 0 set to "
 ]
        STR     r2, [r0, #FormatGap1Side0]
        LDR     r2, [r0, #FormatGap1Side1]
        LDR     lr, [r11, #Ctrlr_g1ll]
        CMP     r2, lr
        MOVLO   r2, lr
        LDR     lr, [r11, #Ctrlr_g1ul]
        CMP     r2, lr
        MOVHI   r2, lr
 [ Debug30
 DREG   r2, "Gap1, Side 1 set to "
 ]
        STR     r2, [r0, #FormatGap1Side1]

        ; Set the fixed gap1 values
        ADD     r10, r11, #Ctrlr_ddfgap1
        LDRB    lr, [r0, #FormatDensity]
        ADD     r10, r10, lr
        LDRB    r2, [r10]
        TEQ     r2, #0
 [ Debug30
 BEQ    %FT01
 DREG   r2, "Gap1, both sides forced to "
01
 ]
        STRNE   r2, [r0, #FormatGap1Side0]
        STRNE   r2, [r0, #FormatGap1Side1]

        ; For skew optimisation:
        ; If interleave=0 and side/side skew=0 and track/track skew=0 and gap1side0=gap1side1 then
        ;               set track/track skew= enough for 30 ms
        LDRB    lr, [r0, #FormatInterleave]
        TEQ     lr, #0
        LDREQB  lr, [r0, #FormatSideSideSkew]
        TEQEQ   lr, #0
        LDREQB  lr, [r0, #FormatTrackTrackSkew]
        TEQEQ   lr, #0
        LDREQ   lr, [r0, #FormatGap1Side0]
        LDREQ   r2, [r0, #FormatGap1Side1]
        TEQEQ   lr, r2
        BNE     %FT40

        ; No skewing at all, so work out a skew that works
        LDRB    r2, [r0, #FormatDensity]
        LDR     lr, [r0, #FormatSectorSize]
10
        MOVS    r2, r2, LSR #1
        MOVNE   lr, lr, LSR #1
        BNE     %BT10

        ; lr now contains sector size/density, divide 512 by this (approx)
        ; to give optimal skew (approx)
        ; This 'divide' loop simply shifts 512 right by enough times that shifting
        ; the (sector size/density) value by that much would give 0. This is
        ; good enough because the (sector size/density) value should be a power of 2.

        MOV     r2, #512
20
        MOVS    lr, lr, LSR #1
        MOVNES  r2, r2, LSR #1
        BNE     %BT20

        ; Lower bound to 1
        TEQ     r2, #0
        MOVEQ   r2, #1

 [ Debug30
        DREG    r2, "Give optimal skew of "
 ]
        STRB    r2, [r0, #FormatTrackTrackSkew]
40

        ; Bound the gap3 size
        LDR     r2, [r0, #FormatGap3]
        LDR     lr, [r11, #Ctrlr_g3ll]
        CMP     r2, lr
        MOVLO   r2, lr
        LDR     lr, [r11, #Ctrlr_g3ul]
        CMP     r2, lr
        MOVHI   r2, lr
 [ Debug30
 DREG   r2, "Gap3 set to "
 ]
        STR     r2, [r0, #FormatGap3]

        ; Bound the sectors per track
        LDRB    r2, [r0, #FormatSectorsPerTrk]
        LDRB    lr, [r11, #Ctrlr_sptl]
        CMP     r2, lr
        MOVLO   r2, lr
        LDRB    lr, [r11, #Ctrlr_spth]
        CMP     r2, lr
        MOVHI   r2, lr
 [ Debug30
 DREG   r2, "Sectors per track set to "
 ]
        STRB    r2, [r0, #FormatSectorsPerTrk]

        ; Set index mark if not optional
        LDRB    lr, [r11, #Ctrlr_imo]
        TEQ     lr, #0
        LDRNEB  r2, [r0, #FormatOptions]
        ORRNE   r2, r2, #FormatOptIndexMark
        STRNEB  r2, [r0, #FormatOptions]

        ; Bound the start sector number
        LDRB    r2, [r0, #FormatLowSector]
        LDRB    lr, [r11, #Ctrlr_snl]
        CMP     r2, lr
        MOVLO   r2, lr
        LDRB    lr, [r11, #Ctrlr_snh]
        LDRB    r3, [r0, #FormatSectorsPerTrk]
        SUB     lr, lr, r3
        ADD     lr, lr, #1      ; Upper value allowed for start sector number
        CMP     r2, lr
        MOVHI   r2, lr
 [ Debug30
 DREG   r2, "Low sector set to "
 ]
        STRB    r2, [r0, #FormatLowSector]

        ; Bound the fill value
        LDRB    r2, [r0, #FormatFillValue]
        LDRB    lr, [r11, #Ctrlr_fl]
        CMP     r2, lr
        MOVLO   r2, lr
        LDRB    lr, [r11, #Ctrlr_fh]
        CMP     r2, lr
        MOVHI   r2, lr
 [ Debug30
 DREG   r2, "Fill value set to "
 ]
        STRB    r2, [r0, #FormatFillValue]

        ; Bound the number of tracks
        LDR     r2, [r0, #FormatTracksToFormat]
        LDRB    lr, [r11, #Ctrlr_tl]
        CMP     r2, lr
        MOVHI   r2, lr
 [ Debug30
 DREG   r2, "Tracks to format set to "
 ]
        STR     r2, [r0, #FormatTracksToFormat]

        ; Now for the hard part: bounding the gaps so they work
        ;
        ; This is done if
        ;     the track usage:
        ;     <IM prefix size>+<gap1 size>+(sector overhead+sector size+gap3)*sectors - gap3 + min. gap4
        ; exceeds
        ;     the minimum track length
        ;
        ; Assuming the minimum track length has been exceeded, then the process proceeds to:
        ; Work out minimum/fixed gap sizes for gap1, gap3 and gap4
        ; Given these lowest tolerable gap sizes the track slack is calculated.
        ; The track slack is the difference between the minimum track length and the track usage
        ; If the track slack is negative the format is rejected (too much data to fit on the disc!)
        ; If the track slack is positive then it is divided equally between all the adjustable
        ; gaps (which are the gap3s, gap4, and, possibly, gap1), gap4 getting the remainder.

        ; For the second track if the track usage exceeds the minimum track length, then
        ; use the first track's parameters

        ; Find location of density parameters
        baddr   r9, DensityParameters
        ASSERT  Track_SzInfo = 24
        LDRB    lr, [r0, #FormatDensity]
        ADD     lr, lr, lr, ASL #1      ; *3
        ADD     r9, r9, lr, ASL #3      ; *8

        ; Calculate track usage for given values, for side 0
        MOV     r5, #0

        ; Index mark
        LDRB    r2, [r0, #FormatOptions]
        TST     r2, #FormatOptIndexMark
        LDRNE   lr, [r9, #Track_IMPrefixLength]
        ADDNE   r5, r5, lr
 [ Debug30
 DREG   r5, "Index = "
 ]

        ; - Gap3
        LDR     r2, [r0, #FormatGap3]
        SUB     r5, r5, r2
 [ Debug30
 DREG   r5, "-Gap3 = "
 ]

        ; (sector overhead + sector size + gap3)*Sectors
        LDR     lr, [r9, #Track_SectorOverhead]
        ADD     r2, r2, lr
        LDR     r3, [r0, #FormatSectorSize]
        ADD     r2, r2, r3
 [ Debug30
 DREG   r2, "...sector overhead + sector size + gap3 = "
 ]
        LDRB    r3, [r0, #FormatSectorsPerTrk]
 [ Debug30
 DREG   r3, "...Sectors = "
 ]
        MLA     r5, r2, r3, r5
 [ Debug30
 DREG   r5, "+(sector overhead + sector size + gap3)*Sectors = "
 ]

        ; min. gap4
        LDR     lr, [r9, #Track_MinGap4]
        ADD     r6, r5, lr              ; Hold value without Gap1Side0 in r6, for use on Side1
 [ Debug30
 DREG   r6, "+MinGap4 = "
 ]

        ; Gap1
        LDR     r2, [r0, #FormatGap1Side0]
        ADD     r5, r6, r2
 [ Debug30
 DREG   r5, "+Gap1Side0 = "
 ]

        ; MinLength
        LDR     r4, [r9, #Track_MinLength]

        ; Check
        CMP     r5, r4
 [ Debug30
 DREG   r5, "Track calculated length is "
 DREG   r4, "Track minimum safe length is "
 BLS    %FT01
 DLINE  "Track 0 doesn't fit"
01
 ]
        BLS     %FT50           ; Side 0 OK

        ; Side 0 not OK (what a pain!)

        ; Calculate track usage for minimum values
        MOV     r5, #0

        ; Index mark
        LDRB    r2, [r0, #FormatOptions]
        TST     r2, #FormatOptIndexMark
        LDRNE   lr, [r9, #Track_IMPrefixLength]
        ADDNE   r5, r5, lr
 [ Debug30
 DREG   r5, "Index = "
 ]

        ; Gap1
        LDR     r2, [r9, #Track_MinGap1]
        LDRB    lr, [r10]       ; fixed gap1 value
        TEQ     lr, #0
        ADDEQ   r5, r5, r2
        ADDNE   r5, r5, lr
 [ Debug30
 DREG   r5, "+gap1 = "
 ]

        ; - Gap3
        LDR     r2, [r9, #Track_MinGap3]
        SUB     r5, r5, r2
 [ Debug30
 DREG   r5, "-gap3 = "
 ]

        ; (sector overhead + sector size + gap3)*Sectors
        LDR     lr, [r9, #Track_SectorOverhead]
        ADD     r2, r2, lr
        LDR     r3, [r0, #FormatSectorSize]
        ADD     r2, r2, r3
        LDRB    r3, [r0, #FormatSectorsPerTrk]
        MLA     r5, r2, r3, r5
 [ Debug30
 DREG   r5, "- sectors = "
 ]

        ; min. gap4
        LDR     lr, [r9, #Track_MinGap4]
        ADD     r5, r5, lr
 [ Debug30
 DREG   r5, "+Min. gap4 = "
 ]

        ; Check again
        SUBS    r2, r4, r5      ; r2 has the track slack in it
 [ Debug30
 DREG   r2, "Track slack is "
 ]
        baddr   r0, TooManySectorsErrBlk, LO
 [ Debug30
 BHS    %FT01
 DLINE  "Failed on 'Too many sectors'"
01
 ]
        BLO     %FT90           ; Doesn't fit, even a little bit!

        ; Work out number of adjustable gaps
        LDRB    r3, [r0, #FormatSectorsPerTrk]
        LDRB    lr, [r10]
        TEQ     lr, #0
        ADDEQ   r3, r3, #1

        ; Divide slack by adjustable gaps
        DivRem  r5, r2, r3, lr

        ; If gap1 adjustable, set it to min. gap1 + slack
        LDRB    lr, [r10]
        TEQ     lr, #0
        LDREQ   r2, [r9, #Track_MinGap1]
        ADDEQ   r2, r2, r5
        STREQ   r2, [r0, #FormatGap1Side0]

        ; Adjust gap3 to Min. gap3 + slack
        LDR     r2, [r9, #Track_MinGap3]
        ADD     r2, r2, r5
        STR     r2, [r0, #FormatGap3]

        ; gap4 drops out of the wash!

50
        ; Now, calculate the track usage on side 1
        LDR     r2, [r0, #FormatGap1Side1]
        ADD     r5, r6, r2

        ; Check, and set side specific parameter if out of bounds
        CMP     r5, r4
        LDRHI   r2, [r0, #FormatGap1Side0]
        STRHI   r2, [r0, #FormatGap1Side1]

        ; No error
        MOV     r0, #0
90
        BL      SetVOnR0
        BLVS    copy_error
95
        STRVS   r0, [sp]

        Pull    "r0-r11,pc"

; ---------------------------------------------


;----------------------------------------------
; DoSwiControllerType
;
; Return the controller type for a given drive.
;
; Input:
;       R0 = Drive no., (0..3 floppy, 4..7 win)
;
; Output:
;       R0 = controller type
;         0 => drive not present
;         1 = 1772 floppy controller
;         2 = 765 floppy controller
;         3 => ST506
;         4 => IDE
;
; Modifies:
;       None, corrupts flags
;----------------------------------------------
;
DoSwiControllerType ROUT
        CMPS    R0, #4                  ; Winchester drive?
        BHS     DoSwiWinControllerType  ; Yes then jump

        LDR     R0, MachineID           ; Get h/w type
        ADDS    R0, R0, #1              ; 1= 1772, 2= 82C710, 0= none
        ASSERT  MachHas1772  = &00000000
        ASSERT  MachHas82710 = &00000001
        ASSERT  MachHasNoFDC = &FFFFFFFF
        MOV     PC, LR                  ; Return, no error


;----------------------------------------------
; DoSwiFlpProcessDCB
;
; Process a '765 specific disc control block
;
; Input:
;       R1-> Disk control block
;
; Output:
;       None, DCB contains results
;
; Modifies:
;       None, preserves flags
;----------------------------------------------
;
DoSwiFlpProcessDCB  ROUT
        Push    "R0,R1,LR"
 [ Debug10
        DREG    R1, "DoSwiFlpProcessDCB: "
 ]
        LDR     R0, MachineID           ; Get FDC type
        CMPS    R0, #MachHas82710       ; 82C710?
        MOVNE   R0, #BadParmsErr        ; No, then bad parameters error
        STRNE   R0, [R1, #FlpDCBstatus] ; And return it in DCB
        BNE     %FT20                   ; And exit

; Claim FIQ's if required

        LDRB    LR, [R1, #FlpDCBcmdLen]
        TSTS    LR, #bit7               ; Asynchronous command?
        MOVEQ   R1, #Service_ClaimFIQ
        SWIEQ   XOS_ServiceCall         ; No, claim FIQs
        LDR     R1, [SP, #4]            ; Restore R1

; Add DCB to active list

        BL      FlpAddDCB               ; (R1->R0,V)
        LDRB    LR, [R1, #FlpDCBcmdLen]
        TSTS    LR, #bit7               ; Async command?
        BNE     %FT20                   ; Yes, then jump

; Wait for command to complete

 [ Debug10
        DLINE   "Waiting for DCBstatus",cc
 ]
10      LDR     R0, [R1, #FlpDCBstatus] ; Get status
        CMPS    R0, #FlpDCBpending      ; Finished?
        BEQ     %BT10                   ; No, then wait
 [ Debug10
        DREG    R0," : "
 ]

; Release FIQ's

        MOV     R1, #Service_ReleaseFIQ
        SWI     XOS_ServiceCall         ; Release FIQs
20
 [ Debug10
        DREG    R1, "DoSwiFlpProcessDCB done: "
 ]
        CLRV
        Pull    "R0,R1,PC"


 [ WTEST
; In:
;  r0 = &43434578 ("xECC")
;         Use Engineering mode for verifies
;     = other
;         Don't use engineering mode for verifies
; Out
;  r0 = 0
;  r1 = number of ECCs taken
;  r2 = number of errors taken
ECCSandRetries ROUT
  [ EngineeringMode
        STR     R0, IDEVerifyType
  ]
        LDR     R1, ECCTotal
        LDR     R2, ErrorTotal
        MOV     R0, #0
        MOV     PC,LR
 ]


; >>>>>>>>
; SwiEntry
; >>>>>>>>

SwiEntry ROUT
        Push    "SB,LR"
        getSB
        CMPS    R11,#FirstUnusedSwi
        ADRLO   LR, %F10
        ADDLO   PC, PC, R11,LSL #2
        B       %FT20
05
        B       DoSwiRetryDiscOp
        B       DoSwiHDC
        B       DoSwiDrives
        B       DoSwiFreeSpace

        B       DoSwiRetries
        B       DoSwiDescribeDisc
        B       DoSwiVetFormat
        B       DoSwiFlpProcessDCB

        B       DoSwiControllerType
        B       DoSwiWinPowerControl
        B       DoSwiSetIDEController
        B       DoSwiIDEUserOp

        B       DoSwiMiscOp
 [ BigDisc
        B       DoSwiRetrySectorDiscOp
        B       %FT20
        B       %FT20
        B       ECCSandRetries
        B       DoSwiLockIDE
        B       DoSwiFreeSpace64
 |
        B       %FT20
        B       %FT20
        B       %FT20
        B       ECCSandRetries
        B       DoSwiLockIDE
        B       %FT20
 ]
 [ AutoDetectIDE
        B       DoSwiIDEDeviceInfo
 |
        B       %FT20
 ]
        B       DoSwiRetryDiscOp64
        B       DoSwiATAPIOp

FirstUnusedSwi  * (.-%BT05)/4

10      TEQ     PC,PC
        Pull    "SB,PC",EQ
        Pull    "SB,LR"
        MOVVCS  PC,LR
        ORRVSS  PC,LR,#V_bit

20
; SWI out of range: set R0 -> international error block

        Push    "R4"

        baddr   R0,BadSWIErrBlk         ; R0 -> error block
        ADR     R4,SwiNames             ; R4 -> parameter to substitute
        BL      copy_error1             ; (R0,R4->R0)

        Pull    "R4,SB,LR"              ; restore all registers
        TEQ     PC,PC
        ORRNES  PC,LR,#V_bit
        SETV
        MOV     PC,LR


SwiNames ROUT
 = "ADFS",0

 = "DiscOp",0
 = "HDC",0
 = "Drives",0
 = "FreeSpace",0

 = "Retries",0
 = "DescribeDisc",0
 = "VetFormat", 0
 = "FlpProcessDCB", 0

 = "ControllerType",0
 = "PowerControl",0
 = "SetIDEController",0
 = "IDEUserOp",0

 = "MiscOp",0
 [ BigDisc
 = "SectorDiscOp",0
 |
 = "13",0
 ]
 = "14",0
 = "15",0

 = "ECCSAndRetries",0
 = "LockIDE",0
 = "FreeSpace64",0
 [ AutoDetectIDE
 = "IDEDeviceInfo",0
 |
 = "19",0
 ]
 = "DiscOp64",0
 = "ATAPIOp",0
 = 0
        ALIGN

FsCom   bit     (31-24)
HelpCode bit    (29-24)
IntHelp * (International_Help:SHR:24)

        MACRO
        ComEntry  $Com,$MinArgs,$MaxArgs,$GsTransBits,$HiBits
        ASSERT  $MinArgs<=$MaxArgs
Com$Com DCB     "$Com",0
        ALIGN
        DCD     Do$Com          - org
 =       $MinArgs
 =       $GsTransBits
 =       $MaxArgs
 =       $HiBits
        DCD     Syn$Com         - org
        DCD     Help$Com        - org
        MEND


        MACRO
        Config  $Com
        DCB     "$Com",0
        ALIGN
        DCD     Con$Com         - org
        DCD     bit30 :OR: International_Help
        DCD     ConSyn$Com      - org
        DCD     ConHelp$Com     - org
        MEND

ComTab                                          ;general star commands
        ComEntry  ADFS,          0,0,0,IntHelp
        ComEntry  Format,        1,4,15,FsCom :OR: HelpCode :OR: IntHelp
                                         ;filing system star commands
                                         ;status/configure optioms
 [ FileCache
        Config  ADFSbuffers
 ]
        Config  ADFSDirCache
        Config  Drive
        Config  Floppies
 [ :LNOT:AutoDetectIDE
        Config  IDEDiscs
 ]
        Config  Step

 =      0
        ALIGN


; >>>>>>
; DoADFS
; >>>>>>

DoADFS
        Push    "LR"             ; NO REENTRANCY CHECK NEEDED
        MOV     R0, #FscSelectFs
        baddr   R1, AdfsTitle
        SWI     XOS_FSControl
        Pull    "PC"


; =======
; Confirm
; =======

; exit V=1 <=> error
; Z=1 <=> confirmed

ConfirmText Text "AYS"

Confirm ROUT
        Push    "r0,r1,lr"
        ADR     r0, ConfirmText
        BL      message_gswrite0

        MOVVC   r0, #OsByte_FlushInputBuffer
        MOVVC   r1, #1
        SWIVC   XOS_Byte
        SWIVC   XOS_Confirm
        BLVC    ConvertEscapeToError

        SavePSR r1
        SWIVC   XOS_WriteC
        SWIVC   XOS_NewLine

        ORRVS   r1, r1, #V_bit
        BICVS   r1, r1, #Z_bit  ; NE on error
        RestPSR r1,,f

        STRVS   r0,[sp]
        Pull    "r0,r1,pc"

; ====================
; ConvertEscapeToError
; ====================

; In: VC and C=escape was pressed
; Out: r0=escape error is CS in

ConvertEscapeToError ROUT
        MOVCC   pc, lr
        Push    "r1,r2,lr"

        ; Acknowledge the escape
        MOV     r0, #OsByte_AcknowledgeEscape
        SWI     XOS_Byte

        ; Convert to error
        baddr   r0, ExtEscapeErrBlk, VC
        BLVC    copy_error
        SETV

        Pull    "r1,r2,pc"


; CONFIGURE/STATUS HANDLERS

 [ FileCache

; >>>>>>>>>>>>>>
; ConADFSbuffers
; >>>>>>>>>>>>>>

ShortConSynADFSbuffers
 = "CSB",0
        ALIGN

ConADFSbuffers
        Push    "R0-R6,SB,LR"
        getSB
        MOVS    R1, R0
        BNE     %FT05

; print syntax message
        baddr   R0, ShortConSynADFSbuffers
        BL      message_gswrite0
        B       ConfigReturn

05
        TEQS    R1, #1
        BNE     %FT15

; print status message
        BL      ReadFileCacheCMOS    ;(->R0,R5,V)
        BVS     ConfigReturn
        SWI     XOS_WriteS
        Text    "ADFSbuffers"
        BVS     ConfigReturn
10
        MOV     R0, R5
        BL      WrDec           ;(R0->R0,V)
        SWIVC   XOS_NewLine     ;(->R0,V)
        B       ConfigReturn

; parse configure
15
        MOV     R0, #10 :OR: bit31 :OR: bit30
        SWI     XOS_ReadUnsigned        ;(R0-R2->R0-R2,V)
        BVS     ConfigReturn
        MOV     R1, #FileCacheCMOS
        B       ConWrite

 ]

; >>>>>>>>>>>>>>>
; ConADFSDirCache
; >>>>>>>>>>>>>>>

ShortConSynADFSDirCache
 = "CSC",0
        ALIGN

ConADFSDirCache
        Push    "R0-R6,SB,LR"
        getSB
        MOVS    R1, R0
        BNE     %FT05

; print syntax message
        baddr   R0, ShortConSynADFSDirCache
        BL      message_gswrite0
        B       ConfigReturn

05
        TEQS    R1, #1
        BNE     %FT15

; print status message
        BL      ReadDirCacheCMOS    ;(->R0,R4,V)
        BVS     ConfigReturn
        SWI     XOS_WriteS
        Text    "ADFSDirCache"
        BVS     ConfigReturn
10
        MOV     R0, R4, LSR #10
        BL      WrDec           ;(R0->R0,V)
        MOVVC   R0, #"K"
        SWIVC   XOS_WriteC
        SWIVC   XOS_NewLine     ;(->R0,V)
        B       ConfigReturn

; parse configure
15
        MOV     R0, #10 :OR: bit30
        SWI     XOS_ReadUnsigned        ;(R0-R2->R0-R2,V)
        BVS     ConfigReturn
        MOV     R1, #ADFSDirCacheCMOS
        B       ConWrite

ShortConSynDrive
 = "CSD",0
        ALIGN

; >>>>>>>>
; ConDrive
; >>>>>>>>

ConDrive ROUT
        Push    "R0-R6,SB,LR"
        getSB
        MOVS    R1, R0
        BNE     %FT05

; print syntax message
        baddr   R0, ShortConSynDrive
        BL      message_gswrite0
        B       ConfigReturn

05
        BL      ReadOldCMOS     ;(->R0,R2,R5,V)
        BVS     ConfigReturn
        TEQS    R1, #1
        BNE     %FT15

; print status message
        SWI     XOS_WriteS
        Text    "Drive     "
        BVS     ConfigReturn
10
        MOV     R0, R5
        BL      WrDec           ;(R0->R0,V)
        SWIVC   XOS_NewLine     ;(->R0,V)
        B       ConfigReturn

; parse configure
15
        BIC     R2, R2, #2_00000111                     ;clear old bits
        BL      ParseAnyDrive   ;(R1->R0,R1,V)
        BVS     ConfigReturn
        ORR     R2, R2, R0      ;form new byte
        MOV     R1, #StartCMOS
        B       ConWrite

; >>>>>>>>>>>
; ConFloppies
; >>>>>>>>>>>

ShortConSynFloppies
 = "CSF",0
        ALIGN

ConFloppies ROUT
        Push    "R0-R6,SB,LR"
        getSB
        MOVS    R1, R0
        BNE     %FT05

; print syntax message
        baddr   R0, ShortConSynFloppies
        BL      message_gswrite0
        B       ConfigReturn

05
        BL      ReadNewCMOS0    ;(->R0,R2-R4,V)
        BVS     ConfigReturn
        TEQS    R1, #1
        BNE     %FT15

; print status message
        SWI     XOS_WriteS
        Text    "Floppies  "
        BVS     ConfigReturn
10
        MOV     R0, R3
        BL      WrDec           ;(R0->R0,V)
        SWIVC   XOS_NewLine     ;(->R0,V)
        B       ConfigReturn

; parse configure
15
        BIC     R3, R2, #2_00000111                     ;clear old bits
        MOV     R0, #10 :OR: bit31 :OR: bit29
        MOV     R2, #4
        SWI     XOS_ReadUnsigned        ;(R0-R2->R0-R2,V)
        BVS     ConfigReturn
        ORR     R2, R3, R2              ;form new byte
        MOV     R1, #NewCMOS0
        B       ConWrite

 [ :LNOT:AutoDetectIDE
; >>>>>>>>>>>>
; ConIDEDiscs
; >>>>>>>>>>>>

ShortConSynIDEDiscs
        =       "CSI",0
        ALIGN

ConIDEDiscs     ROUT
        Push    "R0-R6,SB,LR"
        getSB
        MOVS    R1, R0
        BNE     %FT05

; print syntax message

        baddr   R0, ShortConSynIDEDiscs
        BL      message_gswrite0
        B       ConfigReturn

05
        BL      ReadNewCMOS0    ;(->R0,R2-R4,V)
        BVS     ConfigReturn
        TEQS    R1, #1
        BNE     %FT15

; print status message

        SWI     XOS_WriteS
        Text    "IDEDiscs  "
        BVS     ConfigReturn
10
        MOV     R0,R4,LSR #3
        BL      WrDec           ;(R0->R0,V)
        SWIVC   XOS_NewLine     ;(->R0,V)
        B       ConfigReturn

; parse configure

15
        BIC     R3, R2, #2_11000000     ;clear old bits
        MOV     R0, #10 :OR: bit31 :OR: bit29
        MOV     R2, #WinIDEMaxDrives
        SWI     XOS_ReadUnsigned        ;(R0-R2->R0-R2,V)
        BVS     ConfigReturn
        ORR     R2, R3, R2, LSL #6      ;form new byte
        MOV     R1, #NewCMOS0
        B       ConWrite
 ]


StepDelays
 = 6,12,2,3
MaxStepDelay * 12

; >>>>>>>
; ConStep
; >>>>>>>

ShortConSynStep
 = "CSS",0
        ALIGN

ConStep ROUT
        Push    "R0-R6,SB,LR"
        getSB
        MOVS    R1, R0
        BNE     %FT05

; print syntax message
        baddr   R0, ShortConSynStep
        BL      message_gswrite0
        B       ConfigReturn

; print status message
05
        BL      ReadNewCMOS0    ;(->R0,R2-R4,V) # floppies/winnies
        BVS     ConfigReturn
        BL      ReadStep        ;(->R0,R5,V)
        BVS     ConfigReturn
        baddr   R6, StepDelays
        TEQS    R1, #1
        BNE     %FT15

        SWI     XOS_WriteS
        Text    "Step      "
        BVS     ConfigReturn
10                      ;print step rates, always at least 1
        AND     R0, R5, #3      ;mask to this Drives step rate
        MOV     R5, R5, LSR #2  ;shift for next Drive
        LDRB    R0, [R6,R0]     ;look up step delay
        BL      WrDec           ;(R0->R0,V)
        BVS     ConfigReturn
        SUBS    R3, R3, #1      ;more Drives ?
        BHI     %BT10

        SWI     XOS_NewLine     ;(->R0,V)
        B       ConfigReturn

; parse configure
15
        MOV     R0, #10 :OR: bit31 :OR: bit29
        MOV     R2, #12
        MOV     R4, R2
        SWI     XOS_ReadUnsigned        ;(R0-R2->R0-R2,V)
        BVS     ConfigReturn

        MOV     LR, #3
20
        LDRB    R0, [R6,LR]
        CMPS    R0, R2          ;IF  this step delay >= param
        CMPCS   R4, R0          ;AND this step delay <= best so far
        MOVCS   R3, LR          ; note which delay
        MOVCS   R4, R0          ; best so far := this step delay
        SUBS    LR, LR, #1
        BPL     %BT20

        BL      SkipSpaces              ;(R1->R0,R1,C)
        ORRCS   R2, R3, R3, LSL #2      ;terminator => no Drive qualifier
        ORRCS   R2, R2, R2, LSL #4      ;so set all step rates
        BCS     %FT30

        SUB     R1, R1, #1
        BL      ParseAnyDrive           ;(R1->R0,R1,V)
        BVS     ConfigReturn

        CMPS    R0, #4
        MOVHS   R0, #BadDriveErr
        BLHS    SetV
        BLVS    copy_error
        BVS     ConfigReturn
        MOV     R0, R0, LSL #1
        MOV     R1, #3
        BIC     R2, R5, R1, LSL R0
        ORR     R2, R2, R3, LSL R0
30
        MOV     R1, #StepDelayCMOS
ConWrite
        MOV     R0, #OsByte_WriteCMOS
        SWI     XOS_Byte    ;(R0-R2->R0-R2,V)
ConfigReturn
        STRVS   R0, [SP]
        Pull    "R0-R6,SB,PC"

; C-compatible memcpy. R2-R3 corrupted, all other regs preserved.
memcpy
        ADD     R0,R0,R2
        ADD     R1,R1,R2
        ORR     R3,R0,R1
        ORR     R3,R3,R2
        TST     R3,#3
        BEQ     %FT10
01      SUBS    R2,R2,#1
        LDRCSB  R3,[R1,#-1]!
        STRCSB  R3,[R0,#-1]!
        BCS     %BT01
        MOV     PC,LR

; Same again, but word-aligned
_memcpy
        ADD     R0,R0,R2
        ADD     R1,R1,R2
10      SUBS    R2,R2,#4
        LDRCS   R3,[R1,#-4]!
        STRCS   R3,[R0,#-4]!
        BCS     %BT10
        MOV     PC,LR


        END
