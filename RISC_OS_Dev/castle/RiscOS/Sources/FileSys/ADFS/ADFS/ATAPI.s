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
;*********************************************************************

DoSwiATAPIOp  ROUT
;
; Direct user interface for ATAPI commands.
; Must not be called in background.
;
; Entry:
;    R0 = b0 = action
;              1 => reset device (R1-R4 unused)
;              0 => process command
;         b15 = device
;         b23..b16 = controller number
;         b25..b24 = transfer direction
;              00 => no transfer (R3-R4 unused)
;              01 => read
;              10 => write
;              11 reserved
;    R1 = length of control block (control block must be 12)
;    R2 -> control block
;    R3 -> buffer for data transfer
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
;    All other registers preserved
;    IRQ state: preserved but IRQs enabled during call

 [ Debug21

        DLINE   "DoSwiATAPIOp",cc
 ]

 [ Debug24
        DREG    R0,"(",cc
        DREG    R1,",",cc
        DREG    R2,",",cc
        DREG    R3,",",cc
        DREG    R4,",",cc
        DREG    R5,",",cc
        DLINE   ")"
 ]

 [ HAL
        Push    "R1,R2,R6,R7,R9,IDECtrl,IDE,LR"
 |
        Push    "R1,R2,R6,R7,R9,IDE,LR"
 ]
        SavePSR LR
        Push    "LR"



ATAPIOp_EntryR1 * 4

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

 [ {TRUE}
        TST     R0,#bit0
; KJB just a quicky to prevent blow-ups while locked - see below
        LDREQB  LR,[R2]                 ; abort now rather than later
        SUBEQ   LR,R1,#1
        LDREQB  LR,[R2,LR]
 ]

; We do have a controller to talk to - lock it

        BL      LockIDEController
        baddr   R0,DriverInUseErrBlk,VS ; if error, R0 -> error block
        BVS     %FT89                   ; ...and branch

        MOV     R7,R0                   ; save R0
 [ {FALSE}
; KJB - don't do this for now - CDFSSoftATAPI passes blocks from ROM

; Check parameter block is valid address
        TST     R7,#bit0
        BNE     %FT03
        MOV     R0,R2
        ADD     R1,R0,R1                ; bytes we need in parameter block
        SWI     XOS_ValidateAddress     ; check the addresses
        BCS     %FT82                   ; branch if invalid
03
 ]

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

; Check if user wants to issue command or reset device
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

05
; Set up PACKET command

        MOV     R0,#0
        STRB    R0,WinIDEParmPrecomp    ; DMA and OVL bits 0
        STRB    R0,WinIDEParmSecCount   ; tag = 0
        STRB    R0,WinIDEParmLBA0to7    ; n/a
        MOV     R0,#WinIDEATAPIByteCount:AND:&FF
        STRB    R0,WinIDEParmLBA8to15   ; byte count low
        MOV     R0,#WinIDEATAPIByteCount:SHR:8
        STRB    R0,WinIDEParmLBA16to23  ; byte count high
        TST     R7,#bit15
        MOVEQ   R0,#IDEDrvHeadMagicBits+0:SHL:IDEDriveShift
        MOVNE   R0,#IDEDrvHeadMagicBits+1:SHL:IDEDriveShift
        STRB    R0,WinIDEParmDrvHead
        MOV     R0,#IDECmdPacket:OR:(WinIDECmdFlag_NoDRDY:SHL:8)
        STRB    R0,WinIDECommandCode    ; so transfer routines know
        BL      WinIDECommandDisc       ; (R0->R0,V)
        BVS     %FT70

; Allow time for drive to go busy (upto 400ns according to ATA spec).

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

        LDRB    R0,IDERegStatus
        TSTS    R0,#ATAPIStatusDRQ      ; ready for data?
        BNE     %FT15

; Not ready for data - check for error

        BL      WinIDEDecodeATAPIStatus ; if error, decode status...
        B       %FT70                   ; ...and branch

15

; Transfer the command packet


 [ Debug24
        DLINE   "Moving command packet"
 ]

        LDR     R1,[R13,#ATAPIOp_EntryR1]
16      CMP     R1,#1
        LDRHSB  LR,[R2],#1
        LDRHIB  R7,[R2],#1
        ORRHI   LR,LR,R7,LSL #8
        SUBHS   R1,R1,#2
 [ NewTransferCode
        STRHSH  LR,IDERegData
 |
        STRHS   LR,IDERegData
 ]
        BHI     %BT16

        MOV     R1,R3                   ; R1 -> buffer
20
        STR     R5,WinTickCount         ; reset timeout counter
        LDRB    LR,IDERegAltStatus      ; delay before checking result

        BL      WinIDEWaitNotBusy       ; NE => busy
        MOVNE   R0,#WinIDEErrTimeout    ; if still busy, error...
        BNE     %FT70                   ; ...branch

        LDRB    R0,IDERegStatus
        TST     R0,#ATAPIStatusDRQ
        BNE     %FT25

; Not ready for data - check for error

        BL      WinIDEDecodeATAPIStatus ; if error, decode status...
        B       %FT70                   ; ...and branch

25

; Check if transfer requested

        TEQS    R6,#0                   ; any transfer routine?
        BEQ     %FT50                   ; branch if not

; Transfer requested - check data length

        CMPS    R4,#0                   ; any data (left) to move
        BLE     %FT50                   ; branch if not

        LDRB    R0,IDERegLBAMid
        LDRB    LR,IDERegLBAHigh
        ORR     R7,R0,LR,LSL #8         ; R0 = length of this chunk
 [ Debug24
        DREG    R7,"Transfer size="
 ]
        ADD     R3,R3,R7
        SUB     R4,R4,R7

; DRQ and data transfer requested: move data
27      MOV     R0,R7
        MOV     LR,PC                   ; set link
        MOV     PC,R6                   ; branch to routine

; data transfer routine returns here (all flags preserved)

        SUBS    R7,R7,#512              ; it transferred 1 sector max
        BGT     %BT27                   ; if more to go, do it again

        B       %BT20                   ; back to Check_Status_B state

;****** Never fall through

30
; Reset device
; R5 = timeout for drive !busy
; IDE -> controller

; Send DEVICE RESET command (immediately)

        MOV     R0,#0
        TST     R7,#bit15
        MOVEQ   R0,#IDEDrvHeadMagicBits+0:SHL:IDEDriveShift
        MOVNE   R0,#IDEDrvHeadMagicBits+1:SHL:IDEDriveShift
        STRB    R0,IDERegDrvHead
        MOV     R0,#IDECmdDeviceReset
        STRB    R0,IDERegCommand

; Start timer

        STR     R5,WinTickCount

        MOV     R0,#1*2                 ; 1/2 us units
        BL      DoMicroDelay

; Wait for drive to be not busy so can return register contents

        BL      WinIDEWaitNotBusy       ; NE => busy
        MOVNE   R0,#WinIDEErrTimeout    ; if so, error...
        BNE     %FT70                   ; ...and branch

; Check for error

        LDRB    R0,IDERegStatus
        TSTS    R0,#IDEStatusErrorBits
        BEQ     %FT50
        BL      WinIDEDecodeATAPIStatus ; if error, decode status...
        B       %FT70                   ; ...and branch

50
; No error

        MOV     R0,#0                   ; all ok

70
 [ Debug24
        DREG    R0,"Completed - status=",,Byte
 ]
; Transfer done or no data transfer requested
; R0 = status to return to user
; Cancel timer to speed up ticker routine

        MOV     LR,#0
        STR     LR,WinTickCount

; unlock IDE controller

        BL      UnlockIDEController

; Return

        Pull    "LR"
        BIC     LR,LR,#V_bit
        RestPSR LR,,cf
 [ HAL
        Pull    "R1,R2,R6,R7,R9,IDECtrl,IDE,PC" ; restore IRQ state and return
 |
        Pull    "R1,R2,R6,R7,R9,IDE,PC"    ; restore IRQ state and return
 ]

;****** Never fall through

82
; bad parameter block or buffer address (controller is locked)

        baddr   R0,BadAddressErrBlk     ; R0 -> error block
        BL      UnlockIDEController
89
; call international stuff to make R0 -> international error block

        BL      copy_error              ; (R0->R0)
        Pull    "LR"
        ORR     LR,LR,#V_bit
        RestPSR LR,,cf
 [ HAL
        Pull    "R1,R2,R6,R7,R9,IDECtrl,IDE,PC"
 |
        Pull    "R1,R2,R6,R7,R9,IDE,PC"
 ]

        END
