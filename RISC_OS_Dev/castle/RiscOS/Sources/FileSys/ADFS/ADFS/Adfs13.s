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
        SUBT    IDE Winchester driver entry points -> Adfs13

; Change record
; =============
;
; CDP - Christopher Partington, Cambridge Systems Design
; SBP - Simon Proven, Acorn Computers Ltd.
;
;
; 07-Jan-91  10:00  CDP
; IDE driver started.
;
; 11-Mar-91  17:10  CDP
; Reset added to DoSwiIDEUserOp
;
; 12-Mar-91  14:18  CDP
; Entry points now check whether IDE device has been claimed before
; attempting any access.
;
; 13-Mar-91  15:23  CDP
; DoSwiWinPowerControl now only checks for presence of IDE controller
; after confirming that the request is for an IDE drive.
; WinLowLevelIDE now checks for controller only after setting up the
; variables that the error exit uses.
;
; 14-Mar-91  12:31  CDP
; DoSwiWinPowerControl check for IDE controller had BNE instead of BEQ
; FIXED.
;
; 18-Mar-91  18:14  CDP
; Increments/decrements WinIDECommandActive on way into/out of
; low-level entry.
;
; 20-Mar-91  13:03  CDP
; InitDrive rewritten to initialise power state of drives on first
; access and take account of timer event routine doing same in
; background.
; WinIDEOpStatus renamed WinIDEAdjustStatus to avoid confusion (it
; is not an op).
;
; 26-Mar-91  15:01  JSR
; Internationalise the error messages
;
; 26-Mar-91  17:03  CDP
; Change internationalisation of DoSwiWinPowerControl error exit so as
; to substitute an error number into the error string.
;
; 27-Mar-91  17:19  CDP
; DoSwiIDEUserOp now stops data transfer to/from the controller when
; the count becomes <=0. Previously it carried on (without accessing
; user memory) in order to satisfy the controller. It is up to the
; user to get this right. Waiting until !DRQ has caused problems on
; a flaky system that refused to deassert DRQ. The next command will
; abort any pending I/O anyway. The only problem is leaving the access
; light on. Reset seems a bit aggressive since the drive can take quite
; some time to recover. I hope that the user will notice the DRQ status
; bit and act accordingly.
;
; 08-Apr-91  17:22  CDP
; Calls to WaitNotBusy now cancel timer afterwards if not busy to speed
; up ticker routine.
; Internationalised error return from DoSwiIDEUserOp.
; Code previously conditional on IDEUseRAMCode now made permanent.
; DoSwiIDEUserOp now waits for upto 20ms for DRQ to be asserted. This
; is necessary for CAM class 3 commands.
; Added checks for command active to DoSwiWinPowerControl and
; DoSwiIDEUserOp.
;
; 11-Apr-91  12:58  CDP
; DoSwiIDEUserOp now validates parameter block and buffer addresses.
; All other entry points assume that FileCore/FileSwitch etc. have
; validated the addresses passed.
;
; 10-Jan-92  12:02  CDP
; WinIDEInitDrive changed to use different data to determine whether to
; issue InitDriveParms to the drive (see change record of same date in
; Adfs12 for more details).
;
; 13-Jan-92  12:04  CDP
; DoSwiWinPowerControl, DoSwiIDEUserOp now call LockIDEController rather
; than just testing the CommandActive flag.
; WinLowLevelIDE now calls LockIDEController and calls UnlockIDEController
; on exit if no background transfer is still in progress.
;
; 09-Mar-92  11:17  CDP
; WinIDEInitDrive no longer issues InitialiseDriveParameters as this is done
; by mount entry point. State WinIDEDriveStateSpinning now redundant.
;
; 02-Apr-92  16:18  CDP
; WinIDEInitDrive now issues SpecifyOp when necessary (and parameters have
; been set up) so that the drive shape is reinitialised following a disc
; error (which resets the drive). This should restore all the disc shape
; initialisation that was originally in the driver but effectively disabled
; by changes to FileCore.
; Made WinLowLevelIDE check that it managed to lock controller. Previously
; it took priority but, when symmetrical locking was added 13Jan92, no
; check was added in WinLowLevelIDE that it actually got the lock.
;
; 06-Sep-1994 SBP
; Changed to make use of BigDisc option.
;
;*End of change record*

;*********************************************************************
;
; This file contains the following routines:
;
; DoSwiSetIDEController
;    Gives the IDE driver the details of an alternative controller.
;
; DoSwiWinPowerControl
;    Controls the power-saving features of IDE drives
;
; DoSwiIDEUserOp
;    Direct user interface for low-level IDE commands.
;
; WinLowLevelIDE
;    Handles a low-level call for the IDE discs.
;
; WinIDEAdjustStatus
;    Sorts out status at the end of an operation.
;
; WinIDEInitDrive
;    Initialises drive before access.
;
; WinIDEOpVerify
;    Carries out a verify op on an IDE disc.
;
; WinIDEOpFormatTrk
;    Carries out a format track op on an IDE disc.
;
; WinIDEOpSeek
;    Carries out a seek track op on an IDE disc.
;
; WinIDEOpRestore
;    Carries out a restore op on an IDE disc.
;
; WinIDEOpSpecify
;    Specify heads and sectors per track on drive.
;
; WinIDEOpWriteSecs
;    Carries out a write sectors op on an IDE disc.
;
; WinIDEOpReadSecs
;    Carries out a read sectors op on an IDE disc.
;
; WinIDEReadWriteSecs
;    The main body of code used to read and write sectors from/to an
;    IDE disc.
;
;*********************************************************************

DoSwiSetIDEController   ROUT
;
; Gives the IDE driver the details of an alternative controller.
;
; Entry:
;    R2 -> IDE controller
;    R3 -> interrupt status of controller
;    R4 =  AND with status, NE => IRQ
;    R5 -> interrupt mask
;    R6 =  OR into mask enables IRQ
;    R7 -> data read routine (0 for default)
;    R8 -> data write routine (0 for default)
;    SB -> static workspace
;
; Exit:
;    VS => error
;          R0 = error
;    VC => no error
;          R0 preserved
;    All other registers preserved

        Push    "R0,R7-R9,LR"

 [ :LNOT:ByteAddressedHW ; Call assumes word-addressed HW

; Ignore all this if no drives configured

 [ :LNOT:AutoDetectIDE
        LDRB    R0,WinIDEDrives
        TEQS    R0,#0
        BEQ     %FT90
 ]

; Some IDE drives configured
; If currently using a device, release its IRQ

        sbaddr  R9,WinIDEHardware
        BL      WinReleaseIDEIRQs       ; (R9->R0,V)

; If data transfer routine addresses not passed, use default

        TEQS    R7,#0                   ; default data in routine?
        ADDR    R7,WinIDEReadASector,EQ ; if yes, set it up
        TEQS    R8,#0                   ; default data out routine?
        ADDR    R8,WinIDEWriteASector,EQ ; if yes, set it up

; Save info

      [ HAL
        ASSERT  WinIDEPtr = 4
      |
        ASSERT  WinIDEPtr = 0
      ]
        ASSERT  WinIDEPollPtr = WinIDEPtr + 4
        ASSERT  WinIDEPollBits = WinIDEPollPtr + 4
        ASSERT  WinIDEIRQPtr = WinIDEPollBits + 4
        ASSERT  WinIDEIRQBits = WinIDEIRQPtr + 4
        ASSERT  WinIDEReadPtr = WinIDEIRQBits + 4
        ASSERT  WinIDEWritePtr = WinIDEReadPtr + 4

      [ HAL
        STMIB   R9,{R2-R8}
      |
        STMIA   R9,{R2-R8}
      ]

 [ HAL
 [ Override_PDevNo <> -1
        MOV     R14, #Override_PDevNo
 |
        MOV     R14, #Podule_DevNo
 ]
        STRB    R14, WinIDEHardware+WinIDEHWDevNo
 ]
        MOV     R14, #WinIDEHW_Podule
        STRB    R14, WinIDEHardware+WinIDEHWType

 [ HAL
        ADD     R14,R2,#IDERegCtlDefaultOffset
        STR     R14,WinIDEHardware+WinIDECtrlPtr
 ]

; Claim the device vector

        BL      WinClaimIDEIRQs         ; (R9->R0,V)
        STRVS   R0,[SP]                 ; on error, return
        Pull    "R0,R7-R9,PC",VS

; Enable interrupts in the controller.
; This is ok as it is not until the IRQ is enabled in the podule that it
; will actually be able to interrupt.

 [ HAL
        LDR     R2,WinIDEHardware+WinIDECtrlPtr
 ]
        MOV     R0,#0                   ; IEN
        STRB    R0,[R2,#:INDEX:IDERegDevCtrl]

; Mark drives as uninitialised

        MOV     R0,#WinIDEDriveStateReset
        ASSERT  WinIDEMaxDrives = 2
        STRB    R0,WinIDEDriveState+0
        STRB    R0,WinIDEDriveState+1
 ] ; :LNOT: ByteAddressedHW
90
        CLRV
        Pull    "R0,R7-R9,PC"

;*********************************************************************

DoSwiWinPowerControl    ROUT
;
; Controls the power-saving features of the ADFS system
;
; Entry:
;    R0 = reason
;
;         0 => read drive spin status
;           Entry:
;              R1 = drive (4..7)
;           Exit:
;              R2 = 0 => drive is not spinning
;                  !0 => drive is spinning
;
;         1 => set drive autospindown
;           Entry:
;              R1 = drive (4..7)
;              R2 =  0 => disable autospindown and spinup drive
;                   !0 => set autospindown to R2*5 seconds
;           Exit:
;                 R3 = previous enable value
;
;         2 => manual control of drive spin without affecting autospindown
;           Entry:
;              R1 = drive (4..7)
;              R2 = 0 => spin down immediately
;                  !0 => spin up immediately

 [ HAL
        Push    "R3-R5,R9,IDECtrl,IDE,LR"
 |
        Push    "R3-R5,R9,IDE,LR"
 ]

; Get drive type (ST506/IDE)

        AND     LR,R1,#2_11
        ADD     LR,LR,#:INDEX:WinDriveTypes
        LDRB    R5,[SB,LR]              ; get type from map
        TEQS    R5,#&FF
        BEQ     %FT80                   ; branch if not installed

; Drive is present

        TSTS    R5,#bit3                ; 8/9 => ST506
        BNE     %FT80                   ; branch if not IDE

; Drive is IDE
; Check that we have an IDE controller

        sbaddr  R9,WinIDEHardware
 [ TwinIDEHardware
        TST     R5,#2
        ADDNE   R9,R9,#SzWinIDEHardware
        STR     R9,WinIDECurrentHW
 ]
        LDRB    LR,[R9,#WinIDEIRQDevNo]
        TEQS    LR,#0                   ; got controller ?
        BEQ     %FT80                   ; branch if not

; Lock controller

        BL      LockIDEController
        baddr   R0,DriverInUseErrBlk,VS ; if error, make R0 -> err block
        BVS     %FT89

; Get current power state

        STRB    R5,WinIDEDriveNum       ; save logical drive (0-3)

        sbaddr  R3,WinIDEPowerState     ; R3 -> drive power states
        LDRB    R3,[R3,R5]              ; R3 = state of this drive

 [ HAL
        ASSERT  WinIDECtrlPtr = 0
        LDMIA   R9,{IDECtrl,IDE}        ; set IDE -> IDE controller
 |
        LDR     IDE,[R9,#WinIDEPtr]     ; set IDE -> IDE controller
 ]


; Select drive

        Push    "R0"
        MOV     R0,#0                   ; head
        BL      WinIDESetDriveAndHead   ; (R0->R0)
        Pull    "R0"

; Set timeout register

        MOV     R5,#WinIDETimeoutMisc

; R0 = reason
; R1 = ADFS drive number
; R2 = parameter
; R3 = previous enable state
; R5 = timeout for command
; WinIDEDriveNum is IDE logical drive number (0/1)
; Switch(command)

        CMPS    R0,#3
        ADDCC   PC,PC,R0,LSL #2         ; dispatch if in range
        ASSERT  %FT05 = . + 4
        B       %FT84                   ; branch if not

;****** Insert nothing here
05
        B       %FT10                   ; read spin state
        B       %FT20                   ; set autospindown
        B       %FT30                   ; direct control

;****** Never fall through

10
; Case R0 = 0 - read drive spin status
;    Cmd(CheckPower), return SecCount

 [ IDEPower
;If drive is powered down, return a 'not spinning' indication.
;
;
        LDR     R0, Portable_Flags
        TST     R0, #PortableControl_IDEEnable
        MOVEQ   R2, #0                          ; power off, so not spinning
        BEQ     %FT15
;we know the drive is powered, so no need to call WinIDEcontrol to power it up
 ]
        MOV     R0,#IDECmdCheckPower
        BL      WinIDEPollCommand       ; (R0,R5->R0,V)
        BVS     %FT70                   ; branch if error
        LDRB    R2,IDERegSecCount       ; if ok, get power state
 [ IDEPower
15
 ]
        BL      UnlockIDEController
 [ HAL
        Pull    "R3-R5,R9,IDECtrl,IDE,PC"
 |
        Pull    "R3-R5,R9,IDE,PC"
 ]

;****** Never fall through

20
; Case R0 = 1 - set drive autospindown
;    Cmd(Idle,n)
;    Pstate = n
;    return old state

 [ IDEPower
        Push    "R1"
        MOV     R0, #1
        BL      WinIDEcontrol
        Pull    "R1"

        Push    "R5"
        LDRB    R0, WinIDEDriveNum
        MOV     R5,#WinIDETimeoutSpinup
        BL      WinIDEWaitReady
        Pull    "R5"
 ]

        STRB    R2,WinIDEParmSecCount   ; save parameter for command
        MOV     R0,#IDECmdIdle
        BL      WinIDEPollCommand       ; (R0,R5->R0,V)
        STR     R3,[SP]                 ; return old value
        BVS     %FT70                   ; branch if error

; command completed ok - update stored state

        LDRB    LR,WinIDEDriveNum       ; LR = drive number
        sbaddr  R3,WinIDEPowerState     ; R3 -> drive power states
        STRB    R2,[R3,LR]              ; write new state
        BL      UnlockIDEController
 [ HAL
        Pull    "R3-R5,R9,IDECtrl,IDE,PC"
 |
        Pull    "R3-R5,R9,IDE,PC"
 ]

;****** Never fall through

30
; Case R0 = 2 - control drive
;    Case R2 = 0 - spin down
;       Cmd(Standby,Pstate)
;    Case R2 != 0 - spin up
;       Cmd(Idle,Pstate)

 [ IDEPower
        LDR     R0, Portable_Flags
        TST     R0, #PortableControl_IDEEnable
        CMPEQ   R2, #0
        BEQ     %FT35
        Push    "R1"
        MOV     R0, #1
        BL      WinIDEcontrol
        Pull    "R1"

        Push    "R5"
        LDRB    R0, WinIDEDriveNum
        MOV     R5,#WinIDETimeoutSpinup
        BL      WinIDEWaitReady
        Pull    "R5"
 ]
        LDRB    LR,WinIDEDriveNum       ; LR = drive number
        sbaddr  R3,WinIDEPowerState     ; R3 -> drive power states
        LDRB    R0,[R3,LR]              ; R0 = power state of this drive
        STRB    R0,WinIDEParmSecCount   ; set up sector count for op

        TEQS    R2,#0                   ; spin down?
        MOVEQ   R0,#IDECmdStandby       ; if so, set standby mode
        MOVNE   R0,#IDECmdIdle          ; else set idle mode
        BL      WinIDEPollCommand       ; (R0,R5->R0,V)
 [ IDEPower
35
 ]
        BLVC    UnlockIDEController
 [ HAL
        Pull    "R3-R5,R9,IDECtrl,IDE,PC",VC ; return if no error
 |
        Pull    "R3-R5,R9,IDE,PC",VC       ; return if no error
 ]

; fall through on error

70
; error executing command (R0 = disc error number)
; convert disc error number to ASCII for substitution into
; error string

        SUB     sp,sp,#4                ; make space for xx<0>
        MOV     R1,sp                   ; R1 -> buffer
        MOV     R2,#4                   ; R2 = buffer size
        SWI     XOS_ConvertHex2         ; convert error code in R0

; call international stuff to do substitution etc.

        baddr   R0,DiscErrBlk           ; R0 -> error block
        MOVVC   R4,sp                   ; R4 -> parameter to substitute
        MOVVS   R4,#0                   ; no subst if convert failed
        BL      copy_error1             ; (R0,R4->R0)
        ADD     sp,sp,#4                ; collapse stack

        BL      UnlockIDEController

        SETV
 [ HAL
        Pull    "R3-R5,R9,IDECtrl,IDE,PC"
 |
        Pull    "R3-R5,R9,IDE,PC"
 ]

;****** Never fall through

84
; bad command (controller is locked)

        baddr   R0,BadComErrBlk         ; R0 -> error block
        BL      UnlockIDEController
        B       %FT89

;****** Never fall through

80
; drive not present or not IDE drive (controller not locked)

        baddr   R0,BadDriveErrBlk       ; R0 -> error block

89
; call international stuff to make R0 -> international error block

        BL      copy_error              ; (R0->R0)
        SETV
 [ HAL
        Pull    "R3-R5,R9,IDECtrl,IDE,PC"
 |
        Pull    "R3-R5,R9,IDE,PC"
 ]

;*********************************************************************

          GBLL  UserOpDMA
UserOpDMA SETL  {TRUE} :LAND: IDEDMA

DoSwiIDEUserOp  ROUT
;
; Direct user interface for low-level IDE commands.
; Must not be called in background.
;
; Entry:
;    R0 = b0 = action
;              1 => reset controller
;              0 => process command
;         b1 = don't wait for DRDY
;         b3 = 48-bit addressing command
;         b23..b16 = controller number
;         b25..b24 = transfer direction
;              00 => no transfer
;              01 => read
;              10 => write
;              11 reserved
;         b26 = transfer using DMA
;    R2 -> parameter block for command and results
;           original form: +0 Features          48-bit form: +0 Features
;                          +1 Sector Count                   +1 Sector Count Low
;                          +2 LBA Low/Sector No              +2 Sector Count High
;                          +3 LBA Mid/Cyl Low                +3 LBA 7..0
;                          +4 LBA High/Cyl High              +4 LBA 15..8
;                          +5 Device (+head)                 +5 LBA 23..16
;                          +6 Command                        +6 LBA 31..24
;                                                            +7 LBA 39..32
;                                                            +8 LBA 47..40
;                                                            +9 Device
;                                                           +10 Command
;    R3 -> buffer
;    R4 = length to transfer
;    R5 = timeout in centiseconds (0 = default)
;    SB -> static workspace
;    MODE: SVC
;    IRQ state: unknown
;
; Exit:
;    VS => error
;          R0 -> error block
;    VC => no error
;          R0 = command status (0 or a disc error number)
;          Parameter block updated
;    R3 updated
;    R4 updated
;    R5 undefined
;    All other registers preserved
;    IRQ state: preserved but IRQs enabled during call

 [ Debug21

        DLINE   "DoSwiIDEUserOp",cc
 ]

 [ HAL
        Push    "R1,R6,R7,R9,IDECtrl,IDE,LR"
 |
        Push    "R1,R6,R7,R9,IDE,LR"
 ]
        SavePSR LR
        Push    "LR"

; Check that we have an IDE controller

        AND     LR,R0,#&FF:SHL:WinIDEControllerShift
        sbaddr  R9,WinIDEHardware
 [ TwinIDEHardware
        CMP     LR,#1:SHL:WinIDEControllerShift
        ADDEQ   R9,R9,#SzWinIDEHardware
        LDRLSB  LR,[R9,#WinIDEIRQDevNo]
        MOVHI   LR,#0
 |
        TEQ     LR,#0
        LDREQB  LR,[R9,#WinIDEIRQDevNo]
        MOVNE   LR,#0
 ]

        TEQS    LR,#0                   ; got controller?
        baddr   R0,BadDriveErrBlk,EQ    ; if not, R0 -> error block
        BEQ     %FT89                   ; ...and branch

; We do have a controller to talk to - lock it

        BL      LockIDEController
        baddr   R0,DriverInUseErrBlk,VS ; if error, R0 -> error block
        BVS     %FT89                   ; ...and branch

; Check parameter block is valid address

        MOV     R7,R0                   ; save R0
        MOV     R0,R2
        TST     R7,#bit3
        ADDEQ   R1,R0,#7                ; bytes we need in parameter block
        ADDNE   R1,R0,#11
        SWI     XOS_ValidateAddress     ; check the addresses
        BCS     %FT82                   ; branch if invalid

; Enable interrupts so timers work

        WritePSRc SVC_mode,LR

; Set R5 = timeout

        TEQS    R5,#0                   ; default timeout?
        MOVEQ   R5,#WinIDETimeoutUser

; Set IDE -> IDE controller

 [ TwinIDEHardware
        STR     R9,WinIDECurrentHW
 ]
 [ HAL
        ASSERT  WinIDECtrlPtr = 0
        LDMIA   R9,{IDECtrl,IDE}
 |
        LDR     IDE,[R9,#WinIDEPtr]
 ]

; Check if user wants to issue command or reset controller
; R7 = original R0

        TSTS    R7,#bit0                        ; 0 => reset
        BNE     %FT30                           ; branch if reset

; Set up R6 to point to data transfer routine (or 0) and R1 to be either
; ReadSecsOp or WriteSecsOp for WinIDEInstallTransferCode

        MOV     R6,#0                           ; assume no data transfer
        AND     LR,R7,#WinIDEDirectionMask      ; direction bits
        TEQS    LR,#WinIDEDirectionWrite        ; write?
        LDREQ   R6,[R9,#WinIDEWritePtr]         ; if write, R6 -> write code
        MOVEQ   R1,#DiscOp_WriteSecs            ;           R1 = write sectors
        TEQS    LR,#WinIDEDirectionRead         ; else read?
        LDREQ   R6,[R9,#WinIDEReadPtr]          ; if read, R6 -> read code
        MOVEQ   R1,#DiscOp_ReadSecs             ;          R1 = read sectors

; If data transfer requested, validate buffer address, install transfer
; code and set R1 -> buffer

        TEQS    R6,#0                           ; data transfer requested?
        BEQ     %FT05                           ; branch if not

; R1 = value to determine what transfer code is needed
; R3 -> buffer
; R4 = buffer length
; R6 -> data transfer routine

 [ :LNOT: NewTransferCode
 [ Debug21

        DLINE   "Installing transfer code..."
 ]
        BL      WinIDEInstallTransferCode       ; install RAM code (R1->R0)
 [ Debug21

        DLINE   "Installation successful"
 ]
 ]

        MOV     R0,R3                           ; R0 -> start of buffer
        ADD     R1,R0,R4                        ; R1 -> end of buffer
        SWI     XOS_ValidateAddress             ; check the addresses
        BCS     %FT82                           ; branch if invalid

; buffer addresses are valid

        MOV     R1,R3                           ; R1 -> buffer
05
; Set up command

        TSTS    R7,#bit3                ; 48-bit?

        MOV     LR,R2

        LDRB    R0,[LR],#1              ; get precomp reg value
        STRB    R0,WinIDEParmPrecomp

        LDRB    R0,[LR],#1              ; get sector count reg value
        STRB    R0,WinIDEParmSecCount

        LDRNEB  R0,[LR],#1              ; get sector count high reg value
        STRNEB  R0,WinIDEParmSecCountHigh

        LDRB    R0,[LR],#1              ; get sector number/LBA0to7 reg value
        STRB    R0,WinIDEParmSecNumber

        LDRB    R0,[LR],#1              ; get cylinder low/LBA8to15 reg value
        STRB    R0,WinIDEParmCylLo

        LDRB    R0,[LR],#1              ; get cylinder high/LBA16to23 reg value
        STRB    R0,WinIDEParmCylHi

        LDRNEB  R0,[LR],#1              ; get LBA24to31 reg value
        STRNEB  R0,WinIDEParmLBA24to31

        LDRNEB  R0,[LR],#1              ; get LBA32to39 reg value
        STRNEB  R0,WinIDEParmLBA32to39

        LDRNEB  R0,[LR],#1              ; get LBA40to47 reg value
        STRNEB  R0,WinIDEParmLBA40to47

        LDRB    R0,[LR],#1              ; get drive/head reg value
        STRB    R0,WinIDEParmDrvHead

        LDRB    R0,[LR],#1              ; get command reg value

        ORRNE   R0,R0,#WinIDECmdFlag_48bit :SHL:8

; Start the command
        TSTS    R7,#bit1                ; pass through "ignore DRDY" flag
        ORRNE   R0,R0,#WinIDECmdFlag_NoDRDY:SHL:8
        MOV     LR,R0,LSR #8
        STRB    LR,WinIDECommandFlags
        STRB    R0,WinIDECommandCode

 [ UserOpDMA
        TSTS    R7,#bit26               ; DMA command?
        BNE     %FT40
 ]

        BL      WinIDECommandDisc       ; (R0->R0,V)
        BVS     %FT70

; Allow time for drive to go busy (upto 400ns according to CAM 2.1).

07      MOV     R0,#1*2                 ; 1/2 us units
        BL      DoMicroDelay

; Start timer

        STR     R5,WinTickCount

10
; Wait for !BSY or timeout
; !BSY rather than interrupt as not ALL commands end with interrupt

        BL      WinIDEWaitNotBusy       ; NE => busy
        MOVNE   R0,#WinIDEErrTimeout    ; if still busy, error...
        BNE     %FT70                   ; ...branch

; Drive no longer busy but other status bits not valid for 400ns so wait

        MOV     R0,#1*2                 ; 1/2 us units
        BL      DoMicroDelay

; Check for error

        LDRB    R0,IDERegStatus
        TSTS    R0,#IDEStatusErrorBits
        BEQ     %FT15
        BL      WinIDEDecodeDriveStatus ; if error, decode status...
        B       %FT70                   ; ...and branch

15
; No error, R0 = status
; Check if transfer requested

        TEQS    R6,#0                   ; any transfer routine?
        BEQ     %FT50                   ; branch if not

; Transfer requested - check data length

        CMPS    R4,#0                   ; any data (left) to move
        BLE     %FT50                   ; branch if not

; Transfer requested and data length > 0
; Wait for DRQ to become asserted: according to CAM 2.1, this can
; take as long as 20ms (class 3 command) although Conner drives appear
; to assert it immediately. This loop is inaccurate because the resolution
; of the delay routine is only 0.5us but it is good enough for this.

        MOV     R7,#&4F00                       ; counter for loop
                                                ; approx 20*1000
20
        LDRB    R0,IDERegStatus                 ; get status
        AND     R0,R0,#IDEStatusDRQ             ; mask bits except DRQ
        TEQS    R0,#IDEStatusDRQ                ; EQ => got DRQ
        SUBNES  R7,R7,#1                        ; if not, decrement count...
        MOVNE   R0,#1*2                         ; ...and wait (1/2 us units)
        BLNE    DoMicroDelay                    ; (preserves flags)
        BNE     %BT20

; Have got DRQ or are giving up waiting

        LDRB    R0,IDERegStatus                 ; get status
        TSTS    R0,#IDEStatusDRQ
        BEQ     %FT50                           ; branch if no DRQ

; DRQ and data transfer requested: move data

 [ Debug21

        DLINE   "Moving data",cc
 ]

        MOV     R0,R4                   ; R0 = limit on transfer...
        MOV     LR,PC                   ; set link
        MOV     PC,R6                   ; branch to routine

; data transfer routine returns here (all flags preserved)

        SUBS    R4,R4,#WinIDEBytesPerSector ; decrement count by 1 sector
        MOVMI   R4,#0                   ; if all done, set limit=0
        B       %BT10                   ; go again

;****** Never fall through

30
; Reset controller
; R2 -> where to return register contents
; R5 = timeout for drive !busy
; IDE -> controller

        BL      WinIDEResetDrives       ; preserves registers

; Start timer

        STR     R5,WinTickCount

; Wait for drive to be not busy so can return register contents

        BL      WinIDEWaitNotBusy       ; NE => busy
        MOVNE   R0,#WinIDEErrTimeout    ; if so, error...
        BNE     %FT70                   ; ...and branch

; Drive no longer busy but other status bits not valid for 400ns so wait

        MOV     R0,#1*2                 ; 1/2 us units
        BL      DoMicroDelay

; Check for error

        LDRB    R0,IDERegStatus
        TSTS    R0,#IDEStatusErrorBits
        BEQ     %FT50
        BL      WinIDEDecodeDriveStatus ; if error, decode status...
        B       %FT70                   ; ...and branch

 [ UserOpDMA
40
; DMA command - we just program up the transfer, and it's the DMA manager's
; job, together with our callbacks (in Adfs14), to tell us when it's finished.

        ORR     LR,LR,#WinIDECmdFlag_DMA
        STRB    LR,WinIDECommandFlags

        STR     R5,WinTickCount
        MOV     LR,#0
        STRB    LR,WinIDECommandCode_PIO        ; no PIO fallback

        TST     R7,#bit24                       ; read or write (Z flag also used
        MOVNE   R0,#0                           ; below)
        MOVEQ   R0,#1

        sbaddr  LR,WinIDEFakeScatterList        ; turn it into a scatter list
        STMIA   LR!,{R3,R4}

        MOV     R7,#WinIDEBytesPerSector        ; add in padding to make it a multiple
        SUB     R7,R7,#1                        ; of the sector size
        MOV     R3,R4
        ADD     R4,R4,R7                        ; R4 = length rounded up to
        BIC     R4,R4,R7                        ;      a sector
        SUB     R7,R4,R3                        ; R7 = amount of padding
        sbaddr  R3,WinIDEDMASink,NE             ; excess reads -> sink
        sbaddr  R3,WinIDEDMAZeroes,EQ           ; excess writes as 0
        STMIA   LR,{R3,R7}

        SUB     R3,LR,#8                        ; R3 -> scatter, R4 = rounded length
        BL      WinIDEQueueTransfer             ; DMA handlers will issue
        BVS     %FT48                           ; actual ATA command

41      LDRB    LR,WinIDEDMAStatus
        TST     LR,#DMAStat_Completed
        BNE     %FT45
        BL      WinIDEExamineTransfer           ; We need to "prod" the DMA manager
        BVS     %FT48                           ; like this, as the bus master
                                                ; has no interrupts of its own.

        LDR     R7,WinTickCount
        TEQS    R7,#0
        BNE     %BT41

        MOV     R0,#WinIDEErrTimeout
        BL      WinIDETerminateTransfer ; this will cause "Completed" status
        B       %BT41

45      LDR     R0,WinIDEDMAResult

48      TEQ     R0, #0                  ; R0 = error from DMA routine
        BEQ     %FT49                   ; if 0, check drive status
        CMP     R0, #256                ; if <256, it's already a status
        BLO     %FT70
        LDR     LR, [R0]                ; else if error = "Device error"
        LDR     R7, =&C36
        TEQ     LR, R7
        BEQ     %FT49                   ; then check drive status
        B       %FT88                   ; else return the error

49
        LDRB    R0,IDERegStatus
        ANDS    R0,R0,#IDEStatusErrorBits
        BLNE    WinIDEDecodeDriveStatus ; if error, decode status...
        B       %FT70                   ; ...and branch
 ]


50
; No error

        MOV     R0,#0                   ; all ok

70
; Transfer done or no data transfer requested
; R0 = status to return to user
; Cancel timer to speed up ticker routine

        MOV     LR,#0
        STR     LR,WinTickCount

; Update register block

        LDRB    LR,WinIDECommandFlags
        TST     LR,#WinIDECmdFlag_48bit

        MOV     R7,R2

        LDRB    LR,IDERegError
        STRB    LR,[R7],#1

        LDRB    LR,IDERegSecCount
        STRB    LR,[R7],#1
        ADDNE   R7,R7,#1                ; leave room for high byte

        LDRB    LR,IDERegLBALow
        STRB    LR,[R7],#1

        LDRB    LR,IDERegLBAMid
        STRB    LR,[R7],#1

        LDRB    LR,IDERegLBAHigh
        STRB    LR,[R7],#1
        ADDNE   R7,R7,#3                ; leave room for high bytes

        LDRB    LR,IDERegDrvHead
        STRB    LR,[R7],#1

        LDRB    LR,IDERegStatus
        STRB    LR,[R7],#1
        BEQ     %FT75

        MOV     LR,#IDEDevCtrlHOB       ; set High Order Byte bit
        STRB    LR,IDERegDevCtrl        ; (will be reset by next register write)

        LDRB    LR,IDERegSecCount
        STRB    LR,[R2,#2]

        LDRB    LR,IDERegLBALow
        STRB    LR,[R2,#6]

        LDRB    LR,IDERegLBAMid
        STRB    LR,[R2,#7]

        LDRB    LR,IDERegLBAHigh
        STRB    LR,[R2,#8]

75

; unlock IDE controller

        BL      UnlockIDEController

; Return

        Pull    "LR"
        BIC     LR,LR,#V_bit
        RestPSR LR,,cf
 [ HAL
        Pull    "R1,R6,R7,R9,IDECtrl,IDE,PC" ; restore IRQ state and return
 |
        Pull    "R1,R6,R7,R9,IDE,PC"       ; restore IRQ state and return
 ]

;****** Never fall through

88
; other error (controller is locked)
        BL      UnlockIDEController
        B       %FT98
82
; bad parameter block or buffer address (controller is locked)

        baddr   R0,BadAddressErrBlk     ; R0 -> error block
        BL      UnlockIDEController
89
; call international stuff to make R0 -> international error block

        BL      copy_error              ; (R0->R0)
98
        Pull    "LR"
        ORR     LR,LR,#V_bit
        RestPSR LR,,cf
 [ HAL
        Pull    "R1,R6,R7,R9,IDECtrl,IDE,PC"
 |
        Pull    "R1,R6,R7,R9,IDE,PC"
 ]

        LTORG

;*********************************************************************

 [ AutoDetectIDE

; DoSwiIDEDeviceInfo

; entry:

; r0 = flags/reason code.  any non-zero value will result in BadParmsErr

; R1 = physical device (0-3)

; on exit

; R0 = preserved

; R1 = type of device:
;       0 - no device
;       1 - non-packet
;       2 - packet device

; R2 = ADFS drive number of device, if applicable.  otherwise undefined

; R3 = pointer to device id info for this device, or zero

DoSwiIDEDeviceInfo ROUT
        Push    "R0,LR"

        ; check that the reason code/flags is zero

        TEQS    r0, #0

        BEQ     %FT10                   ; ok if zero

05
        ADRL    r0, BadParmsErrBlk      ; return bad parameters error
        BL      copy_error
        STR     r0, [SP]
        SETV
        Pull    "R0,PC"

10
        ; check the drive number is valid

        CMPS    r1, #WinIDEMaxDrives
        BHS     %BT05                   ; if greater than or equal then exit with error

        ; drive number checked

        ADRL    r3, WinIDEDeviceMappings
        LDRB    r2, [r3, r1]            ; get drive number (also gives type)

        ADR     r3, WinIDEDeviceNoIdFlags
        LDRB    r3, [r3, r1]            ; check it had Identify information
        TEQ     r3, #0
        ADREQ   r3, WinIDEDeviceIds
        ADDEQ   r3, r3, r1, LSL #9      ; point to device info
        MOVNE   r3, #0

        TEQS    r2, #WinIDEATAPIDevice  ; is it atapi
        MOVEQ   r1, #2
        BEQ     %FT90

        TEQS    r2, #WinIDENoDevice
        MOVEQ   r1, #0
        MOVEQ   r3, #0                  ; no device, so no info
        MOVNE   r1, #1                  ; ATA device

90
        CLRV
        Pull    "R0,PC"

 ]

;*********************************************************************
 [ IDEPower
WinIDEcontrol   ROUT
;
; Enable/Disable IDE hardware for power saving on the portable
;
; Entry:
;    R0 = New state, 0= disable, !0= enable
;
; Exit:
;    R1 = Portable_Flags
;
; Modifies:
;       R0
;       Updates Portable_Flags word

        LDR     R1, Portable_Flags
        TST     R1, #Portable_Present           ; Portable present?
        MOVEQ   PC, LR                          ; No then exit

        Push    "R2,LR"
        TEQ     R0, #0                          ; Disabling IDE?
        MOVNE   R0, #PortableControl_IDEEnable  ; No then set enable bit
        AND     LR, R1, #PortableControl_IDEEnable ; Get IDE enable bit
        TEQ     LR, R0                          ; Any change
        Pull    "R2,PC",EQ                      ; No then exit

        SETPSR  SVC26_mode, LR,, R2             ; Switch to SVC mode
        NOP
        Push    "LR"                            ; Save SVC_LR

        MOV     R1, #:NOT:PortableControl_IDEEnable ; IDE enable bit mask
        SWI     XPortable_Control               ; En/Disable IDE H/W
        ORRVC   R1, R1, #Portable_Present       ; No error -> portable
        MOVVS   R1, #PortableControl_FDCEnable  ; Error -> not portable, FDC enabled
        ORRVS   R1, R1, #PortableControl_IDEEnable ; Error -> not portable, IDE enabled

        Pull    "LR"                            ; Restore SVC_LR
        RestPSR R2,,cf                          ; Restore CPU mode
        NOP

 [ Debug10p
        DREG    R1,"New portable flags:"
 ]
        STR     R1, Portable_Flags              ; Save enable state
        Pull    "R2,PC"

;*********************************************************************
 ]
WinLowLevelIDE  ROUT
;
; Called from WinLowLevel when the drive number indicates that
; the drive is an IDE drive.
;
; Entry:
;    R1 = b0-3: reason code
;            0= verify, 1= read, 2= write sectors
;            3= verify track, 4= format track,
;            5= Seek, 6= Restore, 7= Step in, 8= Step out,
;            15= specify
;         b4 = Alternate defect map
;         b5 = R3 -> scatter list
;         b6 = Ignore escape
;         b7 = No ready timeout
;         b8 = Background op
 [ BigDisc
;    R2 = sector disc address (sector/track aligned), top 3 bits = drive (0-3)
 |
;    R2 = byte disc address (sector/track aligned), top 3 bits = drive (0-3)
 ]
;    R3 -> transfer buffer/scatter list
;    R4 = length in bytes
;    R5 -> disc record
;    R6 -> defect list
;    R12 = SB
;
; Exit:
;    VS => error
;          R0 = error pointer/code
;    VC => no error
;          R0 = 0 (definition)
;    R2 = disc address of next byte to transfer
;    R3 -> Next buffer address
;    R4 = Number of bytes left in buffer
;    R5-R9 undefined

 [ HAL
        Push    "R9,IDECtrl,IDE,LR"
 |
        Push    "R9,IDE,LR"
 ]

 [ IDEPower
;
; Ensure power is on,
;
        Push    "R0, R1"
        MOV     R0, #1
        BL      WinIDEcontrol           ; Enable IDE H/W
        Pull    "R0, R1"
 ]

; try to lock IDE controller

        BL      LockIDEController
        baddr   R0,DriverInUseErrBlk,VS ; if error, set R0 -> err block
        BLVS    copy_error              ; (R0->R0)
        BVS     %FT15                   ; ... and branch

; Set IDE -> IDE controller

        sbaddr  R9,WinIDEHardware
 [ TwinIDEHardware
        TST     R2,#1:SHL:30
        ADDNE   R9,R9,#SzWinIDEHardware
        STR     R9,WinIDECurrentHW
 ]
 [ HAL
        ASSERT  WinIDECtrlPtr = 0
        ASSERT  WinIDEPtr = WinIDECtrlPtr + 4
        LDMIA   R9,{IDECtrl,IDE}
 |
        LDR     IDE,[R9,#WinIDEPtr]
 ]

; Save drive number

        MOV     R0,R2,LSR #(32-3)               ; 0/1
        STRB    R0,WinIDEDriveNum

; Save op

        STR     R1,WinIDEFileCoreOp

; Remove the disc bits from the disc address

        BIC     R2,R2,#DiscBits

; Check if we have a controller to talk to

        LDRB    LR,[R9,#WinIDEIRQDevNo]
        TEQS    LR,#0                   ; got controller?
        MOVEQ   R0,#BadDriveErr         ; if not, return error
        BEQ     %FT30

; We do have a controller to talk to

        ASSERT  WinIDEBytesPerSector = 512
 [ BigDisc
 |
; Sector align the disc address
        MOV     R2,R2,LSR #9
        MOV     R2,R2,LSL #9
 ]
; save the disc address
        STR     R2,WinIDEDiscAddress
 [ BigDisc
        MOV     LR,#0
        STR     LR, WinIDESectorOffset
 ]

; Save some physical attributes of drive for later
; - Sectors per track

        LDRB    LR,[R5,#SecsPerTrk]
        STRB    LR,WinIDESecsPerTrk

; - Heads

        LDRB    LR,[R5,#Heads]
        STRB    LR,WinIDEHeads

; Disc size (limit on any transfer)

        LDR     LR,[R5,#DiscSize]               ; get disc size (bytes)
        STR     LR,WinIDEDiscSize               ; and save it
 [ BigDisc
        LDR     LR,[R5,#DiscSize2]              ; get disc size (bytes)
        STR     LR,WinIDEDiscSize2              ; and save it
 ]

; Check if drive needs initialising and handle it if so
; (check inline for speed during normal access)
; R0 = drive number (0/1)

        sbaddr  R8,WinIDEDriveState             ; R8 -> drive states
        LDRB    R9,[R8,R0]                      ; get this drive's state
        CLRV                                    ; as, on init, VS => error
        TEQS    R9,#WinIDEDriveStateActive      ; drive fully initialised?
        BLNE    WinIDEInitDrive                 ; (R0,R6,R8,R9->R0,R5-R7,R9,V)
        BVS     %FT30                           ; branch if error (no callback)

; Switch(op)

        AND     R0,R1,#DiscOp_Op_Mask
        CMPS    R0,#WinIDEJmpTableSize          ; check op in range
        BCS     %FT20                           ; branch if not
        MOV     LR,PC                           ; set return link
        ADD     PC,PC,R0,LSL #2                 ; dispatch if in range
        ASSERT  %FT10 = . + 4

; valid ops return here

        B       %FT30

;****** Do not insert anything here ******
10
        B       WinIDEOpVerify
        B       WinIDEOpReadSecs
        B       WinIDEOpWriteSecs
        B       %FT20                           ; unknown op
        B       WinIDEOpFormatTrk
        B       WinIDEOpSeek
        B       WinIDEOpRestore
WinIDEJmpTableSize      *       (.-%BT10)/4

;****** Never fall through

15 ; here if failed to lock controller - same as code below but leave controller locked

 [ :LNOT:NewErrors
        ORR     R0,R0,#ExternalErrorBit ; for FileCore
 ]
;        LDR     R1,WinIDEFileCoreOp     ; restore R1 = Op
;        DREG    R1, "WinIDEFileCoreOp:"
        TSTS    R1,#DiscOp_Op_BackgroundOp_Flag
;        BLEQ    UnlockIDEController     ; unlock controller if not bg
        TSTNES  R1,#DiscOp_Op_ScatterList_Flag
        TEQNES  R0,#0
        BLNE    WinIDECallbackBg_LockFailed ; unlocks controller
;       BL      LockIDEController       ; leave it locked

 [ HAL
        Pull    "R9,IDECtrl,IDE,LR"
 |
        Pull    "R9,IDE,LR"
 ]
        B       SetVOnR0
20
; Opcode not in table
; Check for specify

        TEQS    R0,#DiscOp_Specify              ; specify
        MOVNE   R0,#BadParmsErr                 ; if not, error
        BLEQ    WinIDEOpSpecify                 ; if so, do it


30
; R0 = completion code
; R2 = disc address (minus disc bits)
; R3 -> buffer/scatter list
; R4 = amount not transferred

; Unlock IDE controller if no background transfer still running
; If background not started due to foreground error, callback FileCore
; i.e.
;
; if !background
;    unlock IDE controller
; else
;    if scatter_list and foreground error (i.e. background not started)
;       do FileCore callback

        LDR     R1,WinIDEFileCoreOp     ; restore R1 = Op
        TSTS    R1,#DiscOp_Op_BackgroundOp_Flag
        BLEQ    UnlockIDEController     ; unlock controller if not bg
        TSTNES  R1,#DiscOp_Op_ScatterList_Flag
        TEQNES  R0,#0
        BLNE    WinIDECallbackBg        ; unlocks controller

 [ HAL
        Pull    "R9,IDECtrl,IDE,LR"
 |
        Pull    "R9,IDE,LR"
 ]
        ASSERT  .=WinIDEAdjustStatus

;****** Fall through to WinIDEAdjustStatus

;*********************************************************************

WinIDEAdjustStatus      ROUT
;
; Adjusts completion code to be in FileCore completion code format.
;
; Entry:
;    R0 = completion code
 [ BigDisc
;    R2 = sector disc address (minus disc bits)
 |
;    R2 = byte disc address (minus disc bits)
 ]
;    WinLogicalDrive = logical drive number (as passed by FileCore)
;    MODE: SVC (IRQ state unknown) or IRQ (IRQs disabled)
;
; Exit:
;    R0 = return value for FileCore
 [ BigDisc
;    R2 = sector disc address (including disc bits)
 |
;    R2 = byte disc address (including disc bits)
 ]
;    V is set/clear according to contents of R0
;    R5 undefined
;    All other registers preserved


 [ Debug20
        DREG    R0,"WinIDEAdjustStatus: R0="
 ]

 [ BigDisc
        LDRB    R5,WinLogicalDrive      ; get drive number (4..7)
        ORR     R2,R2,R5,LSL #(32-3)

        CMPS    R0,#0                   ; error?
        RSBHIS  R5,R0,#MaxDiscErr+1     ; if yes, is it a disc error ?
        BLS     %FT01
 [ NewErrors
        Push    "R1-R4"
        MOV     R1,R0,LSL #8
        ORR     R1,R1,R2,LSR #(32-3)
        BIC     R2,R2,#DiscBits
        ASSERT  WinIDEBytesPerSector = 512
        MOV     R3,R2,LSR #(32-9)
        MOV     R2,R2,LSL #9
        ADR     R0,WinIDEErrorNo
        STMIA   R0,{R1,R2,R3}
        ORR     R0,R0,#NewDiscErrorBit
        Pull    "R1-R4"
 |
        Push    "R1"
        MOV     R1, R0
        ADR     R0, WinIDEErrorNo       ;
        STMIA   R0, {R1,R2}
        ORR     R0,R0,#DiscErrorBit+ExternalErrorBit
        Pull    "R1"
 ]
01
 |
        LDRB    R5,WinLogicalDrive      ; get drive number (4..7)
        ORR     R2,R2,R5,LSL #(32-3)

        CMPS    R0,#0                   ; error?
        RSBHIS  R5,R0,#MaxDiscErr+1     ; if yes, is it a disc error ?
        MOVHI   R0,R0,LSL #24           ; if yes, put error number in place
        ORRHI   R0,R0,R2,LSR #8         ;         and disc address
        ORRHI   R0,R0,#DiscErrorBit     ;         and disc error bit
 ]

        B       SetVOnR0

;*********************************************************************

WinIDEInitDrive ROUT
;
; Initialises drive when it appears not to have been initialised
;
; Entry:
;    R0 = drive number 0=>master, 1=>slave
;    R6 -> defect list and drive-specific parameters
;    SB -> static workspace
;    R8 -> WinIDEDriveState (i.e. R8+R0 -> state for this drive)
;    R9 = initialisation flag for this drive != WinIDEDriveStateActive
;    IDE -> IDE controller (locked)
;    WinIDEDriveNum valid
;    MODE: SVC
;    IRQ state: enabled
;    TickerV: claimed
;
; Exit:
;    VS => error
;          R0 = error code
;    VC => all ok
;          R0 = 0
;    R5,R7,R9 undefined
;    All other registers preserved
;    Drive state of drive [R0] updated

        Push    "LR"

 [ Debug21
        DLINE    "WinIDEInitDrive"
 ]

; Ticker routine cannot get in to interfere as locked out by
; WinIDECommandActive so no need to disable interrupts etc.

        MOV     R7,R0                           ; save drive number

; If drive is still recovering from reset or has just received power
; command, wait for it to become ready. This is the only time that this
; happens. All other entry points expect the drive to be ready.

        MOV     R5,#WinIDETimeoutIdle           ; R5 = short timeout
        TEQS    R9,#WinIDEDriveStateReset       ; has drive just been reset?
        MOVEQ   R5,#WinIDETimeoutSpinup         ; if so, R5 = long timeout
        TEQNES  R9,#WinIDEDriveStateIdled       ; else, just idled?
        BNE     %FT20                           ; branch if not

; Need to wait for drive to become ready

        BL      WinIDEWaitReady                 ; (R0,R5->R0,V)
        Pull    "PC",VS                         ; return if error

; If drive recovering from reset, issue power command to it if it needs it

        TEQS    R9,#WinIDEDriveStateReset       ; just reset?
        BNE     %FT10                           ; branch if not

; Drive has just been reset

 [ Debug21
        BREG    R7,"InitIdle "
 ]
        sbaddr  LR,WinIDEPowerState             ; LR -> power states
        LDRB    LR,[LR,R7]                      ; get value for this drive
        TEQS    LR,#0                           ; drive needs idle cmd?
        BEQ     %FT10                           ; branch if not

; Drive *does* need idle command

        STRB    LR,WinIDEParmSecCount
        MOV     R0,#IDECmdIdle
        MOV     R5,#WinIDETimeoutIdle
        BL      WinIDEPollCommand               ; (R0,R5->R0,R5,V)

; Ignore any error as this must not prevent disc access

        MOV     R0,R7                           ; R0 = drive
        MOV     R5,#WinIDETimeoutIdle           ; R5 = short timeout
        BL      WinIDEWaitReady                 ; (R0,R5->R0,V) ignore error
 [ Debug21

        BVC     %FT01
        DLINE   "*Not* "
01
        DLINE   "Ready"
02
        ]
10

; Drive now spinning

        MOV     R9,#WinIDEDriveStateSpinning    ; move to next state

20

; See if have parameters to initialise it and whether it needs it
; R7 = IDE drive number (0/1)

        sbaddr  LR,WinIDEDriveSecsPerTrk        ; LR -> secs/trk for drives
        LDRB    R0,[LR,R7]                      ; R0 = secs/trk for this drive
        CMPS    R0,#0                           ; initialised yet?
        STREQB  R9,[R8,R7]                      ; if not, update state
        Pull    "PC",EQ                         ; ...and return

; Drive parameter variables have been initialised by Mount
; See if this drive needs initialisation

        sbaddr  LR,WinIDEDriveInitFlags         ; LR -> init flags for drives
        LDRB    R0,[LR,R7]                      ; R0 = flag for this drive
        TSTS    R0,#1                           ; needs init?
        MOVEQ   R9,#WinIDEDriveStateActive      ; if not, all done
        STREQB  R9,[R8,R7]                      ; update state
        Pull    "PC",EQ                         ; ...and return

; Drive does need initialisation
; Issue a Specify op to set up its shape
; Need to set up WinIDESecsPerTrk, WinIDEHeads for Specify but must preserve
; previous values for whatever op comes next as they will have been copied
; out of the disc record passed in the op

        LDRB    LR,WinIDESecsPerTrk
        LDRB    R0,WinIDEHeads
        Push    "R0,LR"

        sbaddr  LR,WinIDEDriveSecsPerTrk        ; set up WinIDESecsPerTrk
        LDRB    R0,[LR,R7]
        STRB    R0,WinIDESecsPerTrk

        sbaddr  LR,WinIDEDriveHeads             ; set up WinIDEHeads
        LDRB    R0,[LR,R7]
        STRB    R0,WinIDEHeads

; WinIDEDriveNum already set up by WinLowLevelIDE

        BL      WinIDEOpSpecify                 ; init the drive shape
        MOVVC   R9,#WinIDEDriveStateActive      ; flag active if ok

; Restore WinIDESecsPerTrk, WinIDEHeads

        Pull    "R5,LR"
        STRB    LR,WinIDESecsPerTrk
        STRB    R5,WinIDEHeads

; R9 = drive state
; R8+R7 -> state variable for this drive

        STRB    R9,[R8,R7]                      ; update state
        Pull    "PC"                            ; return result of specify

;*********************************************************************

WinIDEOpVerify          ROUT
;
; Verify sectors on an IDE drive.
; Called from WinLowLevelIDE.
;
; Entry:
;    R1 = b0-3: reason code
;            0= verify, 1= read, 2= write sectors
;            3= verify track, 4= format track,
;            5= Seek, 6= Restore, 7= Step in, 8= Step out,
;            15= specify
;         b4 = Alternate defect map
;         b5 = R3 -> scatter list
;         b6 = Ignore escape
;         b7 = No ready timeout
;         b8 = Background op
 [ BigDisc
;    R2 = sector disc address (sector/track aligned), top 3 bits = drive (0/1)
 |
;    R2 = byte disc address (sector/track aligned), top 3 bits = drive (0/1)
 ]
;    R4 = length in bytes
;    IDE -> IDE controller
;    SB -> static workspace
;    WinIDEDriveNum = physical drive number
;
; Exit:
;    VS => error
;          R0 = error pointer/code
;    VC => no error
;          R0 = 0
;    R2 = disc address of next byte to verify
;    R4 = number of bytes left to verify
;    R5 undefined
;    All other registers preserved

        Push    "R3,LR"

 [ EngineeringMode
        LDR     R0, IDEVerifyType
        LDR     LR, ECCData ;=&43434578          ; "xECC"
        TEQ     R0, LR
        MOVNE   R0, #IDECmdVerify
        MOVEQ   R0, #IDECmdVerifyEng
  [ Debug20
        DREG    R0, "Verify command used="
  ]
 |
        MOV     R0,#IDECmdVerify
 ]
 [ BigDisc
        ORR     R0,R0,#IDECmdVerifyExt:SHL:16
 ]
        BL      WinIDEReadWriteSecs             ; (R0-R4->R0,R2-R5,V)

        Pull    "R3,PC"

ECCData DCD &43434578

;*********************************************************************

WinIDEOpFormatTrk       ROUT
;
; Format a track on an IDE drive.
; Called from WinLowLevelIDE.
;
; Entry:
;    R1 = b0-3: reason code
;            0= verify, 1= read, 2= write sectors
;            3= verify track, 4= format track,
;            5= Seek, 6= Restore, 7= Step in, 8= Step out,
;            15= specify
;         b4 = Alternate defect map
;         b5 = R3 -> scatter list
;         b6 = Ignore escape
;         b7 = No ready timeout
;         b8 = Background op
 [ BigDisc
;    R2 = disc address (sector/track aligned), no disc bits
 |
;    R2 = disc address (sector/track aligned), no disc bits
 ]
;    R3 -> buffer/scatter list
;    R4 = bytes to transfer
;    IDE -> IDE controller
;    SB -> static workspace
;    WinIDEDriveNum = physical drive number
;
; Exit:
;    VS => error
;          R0 = error pointer/code
;    VC => no error
;          R0 = 0
;    R5 undefined
;    All other registers preserved

        Push    "R2-R4,LR"

; This must be a foreground op...

        TSTS    R1,#DiscOp_Op_BackgroundOp_Flag ; background ?

; ...with no scatter list

        TSTEQS  R1,#DiscOp_Op_ScatterList_Flag  ; if not bg, scatter list ?

; ...and exactly one sector of data to write

        TEQEQS  R4,#WinIDEBytesPerSector        ; if ok so far, check length

        MOVNE   R0,#BadParmsErr                 ; if wrong, return bad parms
        SETV    NE
        MOVVS   PC,LR

; OK so far

        MOV     R0,#IDECmdFormatTrk
        BL      WinIDEReadWriteSecs             ; (R0-R4->R0,R2-R5,V)

        Pull    "R2-R4,PC"

;*********************************************************************

WinIDEOpSeek            ROUT
;
; Seek to a specified track on an IDE drive.
; Called from WinLowLevelIDE.
;
; Entry:
 [ BigDisc
;    R2 = sector disc address (no disc bits)
 |
;    R2 = byte disc address (no disc bits)
 ]
;    IDE -> IDE controller
;    SB -> static workspace
;    WinIDEDriveNum = physical drive number
;
; Exit:
;    VS => error
;          R0 = error pointer/code
;    VC => no error
;          R0 = 0
;    R5 undefined
;    All other registers preserved

        Push    "LR"

; Set up the disk address

 [ BigDisc
; Quietly ignore seek requests to high (>28-bit) addresses, as
; there is no extended form of the seek command.
        CMP     R2,#&10000000
        BHS     %FT90
 ]

        MOV     LR,#0
        STRB    LR,WinIDECommandFlags

        BL      WinIDESetPhysAddress            ; (R2->R0)

; Cylinder, drive/head have already been set up in parameter block.
; Start command

        MOV     R0,#IDECmdSeek
        MOV     R5,#WinIDETimeoutMisc

        BL      WinIDEPollCommand               ; (R0,R5->R0,R5,V)

90      MOVVC   R0,#0

        Pull    "PC"

;*********************************************************************

WinIDEOpRestore         ROUT
;
; Restore (seek track 0 and recalibrate) an IDE drive.
; Called from WinLowLevelIDE.
;
; Entry:
;    IDE -> IDE controller
;    SB -> static workspace
;    WinIDEDriveNum = physical drive number
;
; Exit:
;    VS => error
;          R0 = error pointer/code
;    VC => no error
;          R0 = 0
;    R5 undefined
;    All other registers preserved

        Push    "LR"

; Select drive

        MOV     R0,#0
        BL      WinIDESetDriveAndHead           ; (R0->)

; Do command

        MOV     R0,#IDECmdRestore
        MOV     R5,#WinIDETimeoutMisc
        BL      WinIDEPollCommand               ; (R0,R5->R0,R5,V)

        MOVVC   R0,#0

        Pull    "PC"

;*********************************************************************

WinIDEOpSpecify ROUT
;
; Specify heads and sectors per track on drive.
; Called from WinLowLevelIDE.
;
; Entry:
;    IDE -> IDE controller
;    SB -> static workspace
;    WinIDEDriveNum = physical drive number
;    WinIDEHeads, WinIDESecsPerTrk valid
;
; Exit:
;    VS => error
;          R0 = error pointer/code
;    VC => no error
;          R0 = 0
;    R5 undefined
;    All other registers preserved

        Push    "LR"

 [ Debug21

        DLINE   "WinIDEOpSpecify"
 ]

; Setup IDE registers to say how many heads and how many sectors per track

        LDRB    R0,WinIDEHeads                  ; get requested heads
        SUB     R0,R0,#1                        ; spec says so
        BL      WinIDESetDriveAndHead           ; (R0->)

        LDRB    R0,WinIDESecsPerTrk             ; get sectors per track
        STRB    R0,WinIDEParmSecCount           ; save it for CommandDisc

; Do command

        MOV     R0,#IDECmdInitParms
        MOV     R5,#WinIDETimeoutMisc
        BL      WinIDEPollCommand               ; (R0,R5->R0,R5,V)

        MOVVC   R0,#0

        Pull    "PC"

;*********************************************************************

WinIDEOpWriteSecs       ROUT
;
; Write sectors to an IDE drive.
; Called from WinLowLevelIDE.
;
; Entry:
;    R1 = b0-3: reason code
;            0= verify, 1= read, 2= write sectors
;            3= verify track, 4= format track,
;            5= Seek, 6= Restore, 7= Step in, 8= Step out,
;            15= specify
;         b4 = Alternate defect map
;         b5 = R3 -> scatter list
;         b6 = Ignore escape
;         b7 = No ready timeout
;         b8 = Background op
 [ BigDisc
;    R2 = sector disc address (no disc bits)
 |
;    R2 = byte disc address (no disc bits)
 ]
;    R3 -> buffer/scatter list
;    R4 = bytes to transfer
;    IDE -> IDE controller
;    SB -> static workspace
;    WinIDEDriveNum = physical drive number
;
; Exit:
;    VS => error
;          R0 = error pointer/code
;    VC => no error
;          R0 = 0
 [ BigDisc
;    R2 = sector disc address of next byte to transfer
 |
;    R2 = byte disc address of next byte to transfer
 ]
;    R3 = updated buffer/scatter list pointer
;    R4 = bytes not transferred
;    R5 undefined
;    All other registers preserved

        LDR     R0,WinIDEWriteCmds
        B       WinIDEReadWriteSecs             ; (R0-R4->R0,R2-R5,V)

;*********************************************************************

WinIDEOpReadSecs        ROUT
;
; Read sectors from an IDE drive.
; Called from WinLowLevelIDE.
;
; Entry:
;    R1 = b0-3: reason code
;            0= verify, 1= read, 2= write sectors
;            3= verify track, 4= format track,
;            5= Seek, 6= Restore, 7= Step in, 8= Step out,
;            15= specify
;         b4 = Alternate defect map
;         b5 = R3 -> scatter list
;         b6 = Ignore escape
;         b7 = No ready timeout
;         b8 = Background op
 [ BigDisc
;    R2 = sector disc address (no disc bits)
 |
;    R2 = byte disc address (no disc bits)
 ]
;    R3 -> buffer/scatter list
;    R4 = bytes to transfer
;    IDE -> IDE controller
;    SB -> static workspace
;    WinIDEDriveNum = physical drive number
;
; Exit:
;    VS => error
;          R0 = error pointer/code
;    VC => no error
;          R0 = 0
 [ BigDisc
;    R2 = sector disc address of next byte to transfer
 |
;    R2 = byte disc address of next byte to transfer
 ]
;    R3 = updated buffer/scatter list pointer
;    R4 = bytes not transferred
;    R5 undefined
;    All other registers preserved

        LDR     R0,WinIDEReadCmds
        ASSERT  . = WinIDEReadWriteSecs

;****** Fall through to WinIDEReadWriteSecs

;*********************************************************************

WinIDEReadWriteSecs     ROUT
;
; Read, write, verify or format sectors on an IDE drive.
; Branched to from WinIDEOpReadSecs, WinIDEOpWriteSecs, WinIDEOpVerify
; and WinIDEOpFormatTrk.
;
; Entry:
;    R0 = IDE command code for the op.
;         bits 8..15 = DMA code (0 if none)
;         bits 15..23 = 48-bit addressing code (0 if none)
;         bits 24..31 = 48-bit DMA code (0 if none)
;    R1 = b0-3: reason code
;            0= verify, 1= read, 2= write sectors
;            3= verify track, 4= format track,
;            5= Seek, 6= Restore, 7= Step in, 8= Step out,
;            15= specify
;         b4 = Alternate defect map
;         b5 = R3 -> scatter list
;         b6 = Ignore escape
;         b7 = No ready timeout
;         b8 = Background op
 [ BigDisc
;    R2 = sector disc address (no disc bits)
 |
;    R2 = byte disc address (no disc bits)
 ]
;    R3 -> buffer/scatter list
;    R4 = bytes to transfer
;    IDE -> IDE controller
;    SB -> static workspace
;    WinIDEDriveNum = physical drive number
;
; Exit:
;    VS => error
;          R0 = error pointer/code
;    VC => no error
;          R0 = 0
;    R2 = disc address of next byte to transfer
;    R3 = updated buffer/scatter list pointer
;    R4 = bytes not transferred
;    R5 undefined
;    All other registers preserved

        Push    "LR"

; Save the command code for the IRQ routine

        MOV     LR,#0
 [ BigDisc
        ASSERT  WinIDEBytesPerSector = 512
        ADD     R5,R2,R4,LSR #9                 ; R5 = end disc address
        CMP     R5,#&10000000
        BLO     %FT05
        ; If end address is >= &10000000 then switch to a 48-bit command
        MOV     LR,#WinIDECmdFlag_48bit
        MOVS    R0,R0,LSR #16
        BNE     %FT05
        ; no 48-bit form? Then can't do command.
        MOV     R0,#BadParmsErr
        SETV
        Pull    "PC"
05
 ]
 [ IDEDMA
        TST     R0,#&FF:SHL:8                   ; if the command has a DMA form
        BEQ     %FT08
        LDRB    R5,WinIDEDriveNum
        Push    "R1"
        sbaddr  R1,WinIDEDriveDMAFlags          ; and DMA is enabled for this drive
        LDRB    R5,[R1,R5]
        Pull    "R1"
        TEQ     R5,#0
        BEQ     %FT08
        ORR     LR,LR,#WinIDECmdFlag_DMA        ; then use the DMA form (with a
        STRB    R0,WinIDECommandCode_PIO        ; PIO fallback)
        MOV     R0,R0,LSR #8
08
 ]
        STRB    R0,WinIDECommandCode
        STRB    LR,WinIDECommandFlags

; Install code in RAM to move data into/out of the IDE controller

 [ :LNOT:NewTransferCode
 [ Debug21

        DLINE   "Installing transfer code"
 ]
        BL      WinIDEInstallTransferCode       ; (R1->R0)
 [ Debug21

        DLINE   "Installation complete"
 ]
 ]

; See if there is anything to do in foreground

        TSTS    R1,#DiscOp_Op_BackgroundOp_Flag ; NE => background

; if background op, make it foreground if no scatter list

        TSTNES  R1,#DiscOp_Op_ScatterList_Flag  ; NE => scatter list

        TOGPSR  Z_bit,R8                        ; make NE => no fg bit

; if background op with scatter list,check for foreground bit

        TEQEQS  R4,#0
        BEQ     %FT20

; something to do in foreground

        BL      WinIDEDoForeground              ; (R1-R4->R0,R2-R5,V)
        Pull    "PC",VS                         ; return if error

; fall through to do background stuff

 [ Debug21
        DLINE   "Falling thru to background op"
 ]

20
; Here if no foreground or foreground completed ok
; See if there is anything to do in background

        TSTS    R1,#DiscOp_Op_BackgroundOp_Flag ; NE => background
        TSTNES  R1,#DiscOp_Op_ScatterList_Flag  ; NE => scatter

; NE => background AND scatter list

        MOVEQ   R0,#0                           ; if nothing to do, return 0
        Pull    "PC",EQ

; Background transfer requested

        BL      WinIDEDoBackground              ; (R2-R3->R0,R3,R5,V)

        MOVVC   R0,#0                           ; if no err, return 0
        Pull    "PC"

;*********************************************************************

WinIDEReadCmds
        =       IDECmdReadSecs, IDECmdReadDMA, IDECmdReadSecsExt, IDECmdReadDMAExt
WinIDEWriteCmds
        =       IDECmdWriteSecs,IDECmdWriteDMA,IDECmdWriteSecsExt,IDECmdWriteDMAExt

        END
