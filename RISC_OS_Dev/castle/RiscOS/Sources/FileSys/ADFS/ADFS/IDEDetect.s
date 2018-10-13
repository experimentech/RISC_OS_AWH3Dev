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
        SUBT    IDE device detection code -> IDEDetect

;*********************************************************************

 [ AutoDetectIDE

MaxUDMAMode * 7


; ====================================================================

; ProbeIDEDevices

; the job of this routine is to locate all the IDE devices on an
; interface

ProbeIDEDevices ROUT
        Push    "R0-R3,R5-R9,IDECtrl,IDE, LR"

        MOV     R0, #WinIDENoDevice
        STRB    R0, WinIDEDeviceMappings+0
        STRB    R0, WinIDEDeviceMappings+1
      [ :LNOT: TwinIDEHardware
        ASSERT  WinIDEMaxDrives = 2
      |
        ASSERT  WinIDEMaxDrives = 4
        STRB    R0, WinIDEDeviceMappings+2
        STRB    R0, WinIDEDeviceMappings+3
      ]

        SWI     XOS_ReadMonotonicTime
        BVS     %FT95
        MOV     R8, R0

        MOV     R6, #0  ; controller number (*2)

; we have to wait until the IDE controller becomes ready...

        BL      LockIDEController
        baddr   R0,DriverInUseErrBlk,VS ; if error, make R0 -> err block
        BVS     %FT95

; Reset both ATA buses simultaneously (to save having TWO lots of 31s timeouts)

        sbaddr  R9, WinIDEHardware
 [ HAL
        ASSERT  WinIDECtrlPtr = 0
        ASSERT  WinIDEPtr = 4
        LDMIA   R9, {IDECtrl,IDE}
 |
        LDR     IDE, [R9, #WinIDEPtr]
 ]
 [ TwinIDEHardware
        ADD     R4, R9, #SzWinIDEHardware
 [ HAL
        ASSERT  :BASE:IDERegDevCtrl=IDECtrl
        LDR     R4, [R4, #WinIDECtrlPtr]
 |
        ASSERT  :BASE:IDERegDigOutput=IDE
        LDR     R4, [R4, #WinIDEPtr]    ; R5 = "IDE2"
 ]
 ]

        MOV     r0, #IDEDevCtrlSRST
        STRB    R0, IDERegDevCtrl       ; reset the drive
 [ TwinIDEHardware
        STRB    R0, [R4, #:INDEX:IDERegDevCtrl]
 ]

        MOV     r0, #5*2                ; keep SRST on for 5us
        BL      DoMicroDelay

        MOV     r0, #0
        STRB    r0, IDERegDevCtrl
 [ TwinIDEHardware
        STRB    R0, [R4, #:INDEX:IDERegDevCtrl]
 ]

        MOV     r0, #2048*2             ; wait 2ms
        BL      DoMicroDelay

 [ Debug23
        DLINE   "Done reset"
 ]

        BL      UnlockIDEController

; Now in HSR2:Check_status state (or HHR2:Check_status)
10
        sbaddr  R9, WinIDEHardware
        MOV     LR, #SzWinIDEHardware/2
        MLA     R9,R6,LR,R9
 [ Debug23
        DREG    R6,"R6=",cc,Integer
        DREG    R9," R9="
 ]
 [ HAL
        ASSERT  WinIDECtrlPtr = 0
        ASSERT  WinIDEPtr = 4
        LDMIA   R9, {IDECtrl,IDE}
 |
        LDR     IDE, [R9, #WinIDEPtr]
 ]
        LDRB    LR, [R9, #WinIDEIRQDevNo]
        TEQ     LR, #0
        BEQ     %FT90

        BL      LockIDEController
        baddr   R0,DriverInUseErrBlk,VS ; if error, make R0 -> err block
        BVS     %FT95

15      LDRB    R0,IDERegAltStatus      ; get contents of alternate status register

        ; if BSY is set then round we go again (if no devices present, BSY is pulled
        ; low by a motherboard pull-down).

        TSTS    R0,#IDEStatusBSY
        BEQ     Probe_BusyReleased
        SWI     XOS_ReadMonotonicTime
        BVS     %FT19
        SUB     R0, R0, R8
        CMPS    R0, #3200
        BLO     %BT15

        ; BSY not released - something wrong

19
 [ Debug23
        DLINE   "BSY timeout"
 ]
        MOV     R4, #WinIDENoDevice
        MOV     R5, #WinIDENoDevice
        BL      UnlockIDEController
        B       %FT70

Probe_BusyReleased

        MOV     r0, #10*2       ; wait 10us for luck - found to help with a number
        BL      DoMicroDelay    ; of drives

; Now check signatures

        LDRB    R5, IDERegError
        TEQ     R5, #&01        ; device 0 passed/not present, device 1 pass/not present
        TEQNE   R5, #&81        ; device 0 passed/not present, device 1 failed
        MOVNE   R0, #WinIDENoDevice
        BLEQ    ReadSignature   ; (->R0)
        MOV     R4, R0

        TEQ     R4, #WinIDENoDevice
        MOVEQ   R5, #WinIDENoDevice
        BEQ     %FT50

; Now device 1 (we will see device 0's again if absent)

        TST     R5, #&80        ; check device 1 didn't fail
        MOVNE   R5, #WinIDENoDevice
        BNE     %FT50

        MOV     R0,#IDEDrvHeadMagicBits + (1:SHL:IDEDriveShift)
        STRB    R0,IDERegDevice
        BL      ReadSignature
        MOV     R5, R0

; Got signatures
50
 [ Debug23
        BREG    R4, "Device 0 signature "
        BREG    R5, "Device 1 signature "
 ]

        BL      UnlockIDEController

; Send Identify Device / Identify Packet Device commands

; Device 1 first (to clear PDIAG-/CBLID-)

        TEQ     R4, #WinIDENoDevice
        BEQ     %FT70

        TEQ     R5, #WinIDENoDevice
        BEQ     %FT60

 [ Debug23
        DLINE   "Identifying device 1"
 ]
        ADD     R0, R6, #1
        MOV     R1, R5
        sbaddr  R3, WinIDEDeviceIds
        ASSERT  SzWinIDEId = 512
        ADD     R3, R3, R0, LSL #9
        BL      IdentifyDevice

 [ Debug23
        DREG    R0,"Return code = "
 ]
        MOVVS   R5, #WinIDENoDevice
        TEQ     R0, #WinIDEErrNoDRQ
        TEQNE   R0, #WinIDEErrCmdNotRdy
        MOVEQ   R5, #WinIDENoDevice
        TEQ     R0, #0
        ORRNE   R5, R5, #bit7

60
; Now device 0

 [ Debug23
        DLINE   "Identifying device 0"
 ]
        ADD     R0, R6, #0
        MOV     R1, R4
        sbaddr  R3, WinIDEDeviceIds
        ASSERT  SzWinIDEId = 512
        ADD     R3, R3, R0, LSL #9
        BL      IdentifyDevice
 [ Debug23
        DREG    R0,"Return code = "
 ]
        MOVVS   R4, #WinIDENoDevice
        TEQ     R0, #WinIDEErrNoDRQ
        MOVEQ   R4, #WinIDENoDevice
        TEQ     R0, #0
        ORRNE   R4, R4, #bit7

; Got signature and identification results
70
        TEQ     R4, #WinIDENoDevice             ; definitely enforce no Device 1-only
        MOVEQ   R5, #WinIDENoDevice             ; configurations
 [ Debug23
        BREG    R4, "Device 0 class=&"
        TST     R4, #bit7
        BNE     %FT110
        DLINE   "Device 0 is ",cc
        sbaddr  R0, WinIDEDeviceIds+WinIDEIdModel
        ADD     R0, R0, R6, LSL #9
        MOV     R1, #?WinIDEIdModel
        BL      DebugATAName
        DLINE
110
        BREG    R5, "Device 1 class=&"
        TST     R5, #bit7
        BNE     %FT120

        DLINE   "Device 1 is ",cc
        sbaddr  R0, WinIDEDeviceIds+SzWinIDEId+WinIDEIdModel
        ADD     R0, R0, R6, LSL #9
        MOV     R1, #?WinIDEIdModel
        BL      DebugATAName
        DLINE
120

        sbaddr  R0, WinIDEDeviceIds
        DREG    R0,"ID table at "
 ]
        sbaddr  LR, WinIDEDeviceMappings
        STRB    R4, [LR, R6]!
        STRB    R5, [LR, #1]

90      ADD     R6, R6, #2
        CMP     R6, #WinIDEMaxDrives
        BLO     %BT10
95
        STRVS   R0,[SP]
        BVS     %FT99

        ; Count total drives present, and fill in NoIdFlags table
        sbaddr  R3, WinIDEDeviceMappings
        sbaddr  R6, WinIDEDeviceNoIdFlags
        MOV     R4, #0
        MOV     R5, #0
98      LDRB    LR, [R3, R5]
        TST     LR, #bit7
        MOVEQ   R7, #0
        MOVNE   R7, #1
        STRB    R7, [R6, R5]
        BICS    LR, LR, #bit7
        STRB    LR, [R3, R5]
        ADDEQ   R4, R4, #1
        ADD     R5, R5, #1
        CMP     R5, #WinIDEMaxDrives
        BLO     %BT98
99
        Pull    "R0-R3,R5-R9,IDECtrl,IDE,PC"

; ========================================================

; Out: R0 = &00 if ATA signature
;           WinIDEATAPIDevice if ATAPI signature
;           WinIDENoDevice if bad signature
ReadSignature   ROUT
        LDRB    R0, IDERegSecCount
 [ Debug23
        BREG    R0,"Count=",cc
 ]
        TEQ     R0, #&01
        LDREQB  R0, IDERegLBALow
 [ Debug23
        BNE     %FT01
        BREG    R0,",Low=",cc
01
 ]
        TEQEQ   R0, #&01
        BNE     %FT90
        LDRB    R0, IDERegLBAMid
 [ Debug23
        BREG    R0,",Mid=",cc
 ]
        TEQ     R0, #&00
        BEQ     %FT10
        TEQ     R0, #&14
        BNE     %FT90
; Maybe ATAPI
        LDRB    R0, IDERegLBAHigh
 [ Debug23
        BREG    R0,",High="
 ]
        TEQ     R0, #&EB
        MOVEQ   R0, #WinIDEATAPIDevice
        MOVEQ   PC, LR
        B       %FT90
; Maybe ATA
10      LDRB    R0, IDERegLBAHigh
 [ Debug23
        BREG    R0,",High="
 ]
        TEQ     R0, #0
90      MOVNE   R0, #WinIDENoDevice
        MOV     PC, LR


; ========================================================

; this routine outputs a string from an ATA/ATAPI device
; identify.  each of the strings in the identify device
; data is held in an unusual form, where alternate characters
; are swapped; strings are padded with spaces to fill the
; field.

; for instance, the string "FUJITSU" would be represented
; as "UFIJST U", plus any padding with further spaces

; it is assumed that the name is a multiple of 2 chars in length,
; and is at least 2 characters.  all the padding spaces are
; printed in the message.

; entry

; R0 -> string
; R1  = number of characters


PrintATAName    ROUT
        Push    "R0-R3, LR"

        MOV     R2, R0
10
        LDRB    R0, [R2, #1]
        CMP     R0, #32
        RSBHSS  LR, R0, #126
        MOVLO   R0, #"."
        SWI     XOS_WriteC
        BVS     %FT90
        LDRB    R0, [R2], #2    ; get next thing and advance the pointer
        CMP     R0, #32
        RSBHSS  LR, R0, #126
        MOVLO   R0, #"."
        SWI     XOS_WriteC
        BVS     %FT90

; now check if we've nothing left to do
        SUBS    R1, R1, #2
        BGT     %BT10           ; go round again if we have more to do

        CLRV
90
        Pull    "R0-R3, PC"

 [ Debug23
DebugATAName    ROUT
        Push    "R0-R3, LR"

        MOV     R2, R0
10
        LDRB    R0, [R2, #1]
        CMP     R0, #32
        RSBHSS  LR, R0, #126
        MOVLO   R0, #"."
        DWriteC
        LDRB    R0, [R2], #2    ; get next thing and advance the pointer
        CMP     R0, #32
        RSBHSS  LR, R0, #126
        MOVLO   R0, #"."
        DWriteC

; now check if we've nothing left to do
        SUBS    R1, R1, #2
        BGT     %BT10           ; go round again if we have more to do

        CLRV
90
        Pull    "R0-R3, PC"
 ]

 [ {FALSE}
; ========================================================

; PrintDeviceInfo

; this rountine prints information about a given device; the

; entry:

; r0 -> ATA/ATAPI information structure
; r1  = device no
; r2  = ADFS drive no, or -1 if not an adfs drive (ie ATAPI)

PrintDeviceInfo ROUT
        Push    "R0-R4, LR"

        SUB     sp, sp, #8      ; size of buffer for output values

        MOV     r4, r0
        MOV     r3, r2
        MOV     r0, r1

        MOV     r1, sp
        MOV     r2, #8

        CMPS    r3, #-1
        BNE     %FT10

        ADR     r0, ATAPIString
        SWI     XOS_Write0
        BVS     %FT90

        B       %FT20

10
        MOV     r0, r3
        MOV     r1, sp
        MOV     r2, #8
        SWI     XOS_ConvertCardinal1
        SWIVC   XOS_Write0
        BLVC    %FT99           ; pad with spaces

        BVS     %FT90
        ADR     r0, ATAString
        SWI     XOS_Write0
        BVS     %FT90

20
; finally, we print the device name

        ADD     r0, r4, #WinIDEIdModelNo
        MOV     r1, #40         ; length of the string
        BL      PrintATAName

90
        ADD     sp, sp, #8
        Pull    "R0-R4, PC",,^

; subroutine to pad with spaces
99
        Push    "LR"
;       ADD     R2, R2, #1

        MOV     r0, #" "
01
        SWI     XOS_WriteC
        BVS     %FT02
        SUBS    R2, R2, #1
        BNE     %BT01

02
        Pull    "PC",,^

ATAPIString
        DCB     "-       ATAPI   ",0

ATAString
        DCB     "ATA     ",0

NoDriveString
        DCB     "-       -",10,13,0

        ALIGN

 ]


;*********************************************************************

; this routine identifies a given drive

; Entry

;   R0 = physical drive number (0-3)
;   R1 = &EB if ATAPI
;   R3 = buffer ptr

; exit

;   R0 = command status (0 or a disc error no.)

;   if other error, V set, R0 -> error block

IdentifyDevice ROUT
        Push    "R1-R6,R10,LR"

        MOV     R6, R0
        SWI     XOS_ReadMonotonicTime
        BVS     %FT95
        MOV     R10, R0

; first - try IDENTIFY PACKET DEVICE. This doesn't require DRDY,
; and should be aborted by non-ATAPI devices. If no device is
; present (ie a non-existant device 1 hidden by device 0), we
; will get a failure fast (failure to assert DRQ - which is
; actually returned by IDEUserOp as return code 0, but no
; data transferred).

; have to construct a parameter block; use the stack

        MOV     R4, #0
        MOV     R5, #0

        Push    "R4-R5"

        MOV     LR, #IDEDrvHeadMagicBits
        ORR     R1, LR, r6, LSL #IDEDriveShift
        STRB    R1, [sp, #5]
        MOV     LR, #IDECmdIdentifyPacket
        STRB    LR, [sp, #6]

        MOV     R6, R6, LSR #1
        MOV     R6, R6, LSL #WinIDEControllerShift
        ORR     R6, R6, #WinIDEDirectionRead
        ORR     R0, R6, #bit1                   ; ignore DRDY
        MOV     r2, sp
        MOV     r4, #512
        MOV     r5, #0

        BL      DoSwiIDEUserOp
        BVS     %FT90

        TEQ     R0,#0
        TEQEQ   R4,#0
        BEQ     %FT90                           ; ooh, it worked - got data

        TEQ     R0,#0                           ; no error, but data not transferred
        MOVEQ   R0,#WinIDEErrNoDRQ              ; probably an absent device
        BEQ     %FT90

        TEQ     R0,#WinIDEErrABRT
        BNE     %FT90

; It aborted the command - that means we know something is there.
; Now we can do the 30s wait for DRDY to go high before issuing IDENTIFY
; DEVICE.

        MOV     R0, #0
        STR     R0, [sp, #0]
        STR     R0, [sp, #4]
        STRB    R1, [sp, #5]
        MOV     LR, #IDECmdIdentify
        STRB    LR, [sp, #6]

10      MOV     R0, R6
        MOV     r2, sp
        MOV     r4, #512
        MOV     r5, #0

        BL      DoSwiIDEUserOp
        BVS     %FT90

        TEQ     r0, #0
        BNE     %FT70

 [ Debug23
        DREG    r0, "r0: "
        DREG    r4, "r4: "
 ]

        CMP     r4, #0                          ; return code 0 - check everything
        MOVNE   r0, #WinIDEErrNoDRQ             ; transferred (it doesn't return NoDRQ)

        ADD     sp, sp, #8
        Pull    "R1-R6,R10,PC"

70      TEQ     R0, #WinIDEErrCmdNotRdy
        BNE     %FT90
        SWI     XOS_ReadMonotonicTime
        BVS     %FT90
        SUB     R0, R0, R10
        CMP     R0, #3104
        BLO     %BT10
        MOV     R0, #WinIDEErrCmdNotRdy
90
 [ Debug23
        DREG    r0, "UserOp error, R0="
 ]
        ADD     sp, sp, #8

95
        Pull    "R1-R6,R10,PC"

 [ HAL

; Entry: R0=device number (ie 0 or 2)

WinIDESetTimings
        Push    "R1-R9,LR"
        SUB     SP,SP,#16

        sbaddr  R9,WinIDEHardware
 [ TwinIDEHardware
        TST     R0, #2
        ADDNE   R9,R9, #SzWinIDEHardware
 ]
        LDRB    LR,[R9,#WinIDEIRQDevNo]
        TEQ     LR, #0
        BEQ     %FT95

        sbaddr  LR,WinIDEDeviceNoIdFlags
        LDRB    R4,[LR,R0]!
        LDRB    R5,[LR,#1]
; R4 = 0 <=> have identify data for device 0
; R5 = 0 <=> have identify data for device 1
        sbaddr  LR,WinIDEDeviceIds
        TEQ     R4,#0
        ADDEQ   R4,LR,R0,LSL #9
        MOVNE   R4,#0
        TEQ     R5,#0
        ADDEQ   R5,LR,R0,LSL #9
        ADDEQ   R5,R5,#SzWinIDEId
        MOVNE   R5,#0
; R4->identify data for device 0 (or 0)
; R5->identify data for device 1 (or 0)
        sbaddr  LR,WinIDEDeviceMappings
        LDRB    R6,[LR,R0]!
        LDRB    R7,[LR,#1]
; R6 = drive number / type of device 0
; R7 = drive number / type of device 1

        CMP     R6, #8
        MOVLO   LR, #bit0               ; enable FIFO if our drive
        MOVHS   LR, #0
        STR     LR, [SP,#0]

        CMP     R7, #8
        MOVLO   LR, #bit0               ; enable FIFO if our drive
        MOVHS   LR, #0
        STR     LR, [SP,#8]

        MOV     LR, #&FFFFFF00          ; PIO mode 0, no DMA
        STR     LR, [SP,#4]
        STR     LR, [SP,#12]

        BL      WinIDEDetectCableType

        MOV     R1, SP
        MOV     R2, R4
        MOV     R3, R6
        BL      WinIDEGetTimingForDevice

        ADD     R1, SP, #8
        MOV     R2, R5
        MOV     R3, R7
        BL      WinIDEGetTimingForDevice

        Push    "R0-R3,R12"
        LDRB    R1, [R9,#WinIDEBusNo]
        TEQ     R6, #WinIDENoDevice
        MOVEQ   R2, #0
        ADDNE   R2, SP, #5*4+0
        TEQ     R7, #WinIDENoDevice
        MOVEQ   R3, #0
        ADDNE   R3, SP, #5*4+8
 [ Debug23
        DREG    R1,"Bus ",cc,Integer
        DREG    R2,", Block1=",cc
        DREG    R3,", Block2="
        LDR     R14,[R2,#0]
        DREG    R14,,cc
        LDR     R14,[R2,#4]
        DREG    R14," ",cc
        LDR     R14,[R3,#0]
        DREG    R14,", ",cc
        LDR     R14,[R3,#4]
        DREG    R14," "
 ]
        LDR     R0, HAL_IDEDevice_pointer
        MOV     LR, PC
        LDR     PC, [R0,#HALDevice_IDESetModes]
        Pull    "R0-R3,R12"

        MOV     R3, R0
        TEQ     R6, #WinIDENoDevice
        MOVNE   R1, SP
        BLNE    WinIDESetTransferModes

        ADD     R0, R3, #1
        TEQ     R7, #WinIDENoDevice
        ADDNE   R1, SP, #8
        BLNE    WinIDESetTransferModes

95
        ADD     SP, SP, #16
        Pull    "R1-R9,PC"

 ]

; In: R0 = bus number * 2
;     R4 -> identify block for device 0 (0 if none)
;     R5 -> identify block for device 1 (0 if none)
;     R6 = drive number / type of device 0
;     R7 = drive number / type of device 1
; Out: R8 = 40 or 80

; This follows the algorithm in the ATA spec. Basic idea is that
; a 40-way cable has CBLID- bussed between the host and the devices,
; which contain pull-ups. An 80-way cable has CBLID- in the host
; connector pulled low, isolated from the 2 drives.
;
; This is complicated by CBLID-'s other, older function as PDIAG-,
; a line that may be pulled low by device 1, but we get some backup
; from newer devices that can detect and report the state of CBLID-
; at their end of the cable.
;
; We deduce that it is an 80-way cable if we see CBLID- low, and
; we are confident that it's not a device (bugged or pre-ATA-3)
; pulling it low via a 40-way cable. See ATA-6 section C.6 for more
; details.

WinIDEDetectCableType ROUT
        Push    "R0-R5,LR"
        MOV     R1, R0, LSR #1
 [ Debug23
        DREG    R1, "Cable of bus ",cc,Integer
 ]
        LDR     R0, HAL_IDEDevice_pointer
        Push    "R12"
        MOV     LR, PC
        LDR     PC, [R0, #HALDevice_IDECableID]
        Pull    "R12"

        TEQ     R0, #0                  ; If we see CBLID- line high
        BEQ     %40                     ; then it's definitely 40-way

        TEQ     R4, #0
        LDRNE   R4, [R4, #WinIDEIdResetResult]
        AND     R4, R4, #2_111:SHL:13   ; R4 = cable detect from device 0 (if any)

        TEQ     R7, #WinIDENoDevice
        BNE     %FT10

        ; No device 1 present, CBLID- low. Almost certainly 80-way,
        ; unless device 0 says it's low, in which case something odd
        ; has happened.

        TEQ     R4, #2_010:SHL:13
        BEQ     %40
        BNE     %80

        ; Device 1 is present. More complex, as pre ATA-3 devices
        ; may be pulling PDIAG-:CBLID- low for too long.

10      TEQ     R5, #0
        LDRNE   R1, [R5, #WinIDEIdMajorATAVersion]
        MOVEQ   R1, #0
        LDRNE   R5, [R5, #WinIDEIdResetResult]
        LDR     LR, =&FFFF
        AND     R5, R5, #2_111:SHL:13   ; R5 = cable detect from device 1 (if any)
        TEQ     R1, LR                  ; check for &FFFF case (version not reported)
        MOVEQ   R1, #0                  ; R1 = bitmask of supported versions

        TEQ     R4, #2_010:SHL:13       ; if either device says CBLID- is low
        TEQNE   R5, #2_010:SHL:13       ; then something wrong - say 40-way
        BEQ     %40

        TEQ     R4, #2_011:SHL:13       ; else if either device says CBLID-
        TEQNE   R5, #2_011:SHL:13       ; is high then it's 80-way
        BEQ     %80

        TST     R1, #bit6+bit5+bit4+bit3; else if device 1 is ATA-3 to 6 compatible
        BNE     %80                     ; then it must� be 80-way (as these specs
                                        ; require device 1 to release PDIAG- after
                                        ; receiving its first command)

                                        ; else we don't know - device 1 may be old
                                        ; and may be interfering; say 40-way

40      MOV     R8, #40
 [ Debug23
        DLINE   " is 40-way"
 ]
        Pull    "R0-R5,PC"

80      MOV     R8, #80
 [ Debug23
        DLINE   " is 80-way"
 ]
        Pull    "R0-R5,PC"

        LTORG

; In: R1 -> speed setting block for device
;           (initially indicating PIO mode 0 only)
;     R2 -> identify block for device (or 0 if none)
;     R3 = drive number/type of device
;     R8 = 80 or 40 indicating cable type
;     R9 -> hardware block for controller
;
; Out: speed setting block updated to indicate capabilities
;      of device/cable combination (the HAL will reduce this
;      further if necessary when passed the setting block)

WinIDEGetTimingForDevice
        Push    "R0,R4,LR"
        TEQ     R2, #0
        BEQ     %FT99

        ; Get basic PIO mode (0,1 or 2)
        LDRB    R0, [R2, #WinIDEIdPIOTiming]
        CMP     R0, #2
        MOVHI   R0, #2

        ; Check for ATA-2 extra timing words
        LDR     LR, [R2, #WinIDEIdValidWordsFlags]
        TST     LR, #IIValid_Words64_70
        BEQ     %FT30

        ; Use "advanced" PIO modes 3 or 4 if available
        LDR     LR, [R2, #WinIDEIdPIOModes]
        TST     LR, #bit0
        MOVNE   R0, #3
        TST     LR, #bit1
        MOVNE   R0, #4

        ; Extra checks against cycle time - switch to a
        ; slower mode if necessary (eg if they do a slow
        ; mode 3, then just switch to mode 2). Check first
        ; whether we support IORDY.
        LDR     LR, [R9, #WinIDEHWFlags]
        TST     LR, #WinIDEHWFlag_IORDYSupported
        LDREQ   LR, [R2, #WinIDEIdMinPIOCycle]
        LDRNE   LR, [R2, #WinIDEIdMinPIOCycleIORDY]
        MOV     LR, LR, LSL #16
        MOV     LR, LR, LSR #16
        MOV     R4, #4
        CMP     LR, #120
        MOVGT   R4, #3
        CMP     LR, #180
        MOVGT   R4, #2
        CMP     LR, #240
        MOVGT   R4, #1
        SUB     LR, LR, #300
        CMP     LR, #83
        MOVGT   R4, #0

        CMP     R0, R4
        MOVHS   R0, R4

30
 [ Debug23
        DREG    R0, "PIO mode ",,Integer
 ]

        STRB    R0, [R1,#4]

        ; Now multiword DMA...

        LDR     LR, [R2, #WinIDEIdMultiwordDMAMode]
        MOV     R0, #-1
        TST     LR, #bit0
        MOVNE   R0, #0
        TST     LR, #bit1
        MOVNE   R0, #1
        TST     LR, #bit2
        MOVNE   R0, #2

        ; Check for ATA-2 extra timing words
        LDR     LR, [R2, #WinIDEIdValidWordsFlags]
        TST     LR, #IIValid_Words64_70
        BEQ     %FT60

        ; Extra checks against cycle time - switch to a
        ; slower mode if necessary (eg if they do a slow
        ; mode 2, then just switch to mode 1).
        LDR     LR, [R2, #WinIDEIdMinMultiwordDMACycle]
        MOV     LR, LR, LSL #16
        MOV     LR, LR, LSR #16
        MOV     R4, #2
        CMP     LR, #120
        MOVGT   R4, #1
        CMP     LR, #150
        MOVGT   R4, #0
        CMP     LR, #480
        MOVGT   R4, #-1

        CMP     R0, R4
        MOVGT   R0, R4

        ; Also check recommended cycle time - drop
        ; down a mode, if appropriate.
        LDR     LR, [R2, #WinIDEIdRecMultiwordDMACycle]
        MOV     LR, LR, LSL #16
        MOV     LR, LR, LSR #16
        MOV     R4, #2
        CMP     LR, #130                ; go to mode 1 (150ns) if recommended > 130ns
        MOVGT   R4, #1
        CMP     LR, #300                ; go to mode 0 (480ns) if recommended > 300ns
        MOVGT   R4, #0

        CMP     R0, R4
        MOVGT   R0, R4

60
 [ Debug23
        DREG    R0, "Multiword DMA mode ",,Integer
 ]

        STRB    R0, [R1,#5]

        ; And finally, Ultra DMA...

        LDR     LR, [R2, #WinIDEIdValidWordsFlags]
        TST     LR, #IIValid_Word88
        BEQ     %FT99

        LDR     LR, [R2, #WinIDEIdUltraDMAMode]
        MOV     R0, #-1
        TST     LR, #bit0
        MOVNE   R0, #0
        TST     LR, #bit1
        MOVNE   R0, #1
        TST     LR, #bit2
        MOVNE   R0, #2

        TEQ     R8, #80         ; if not an 80-way cable
        BNE     %FT90           ; limit to UltraDMA mode 2

        TST     LR, #bit3
        MOVNE   R0, #3
        TST     LR, #bit4
        MOVNE   R0, #4
        TST     LR, #bit5
        MOVNE   R0, #5
        TST     LR, #bit6
        MOVNE   R0, #6

90
 [ Debug23
        DREG    R0, "Ultra DMA mode ",,Integer
 ]

        STRB    R0, [R1,#6]

99
        Pull    "R0,R4,PC"


; In: R0 = physical device number
;     R1 -> speed descriptor block

WinIDESetTransferModes
        Push    "R0-R3,R5,LR"

        MOV     LR, #0
        STR     LR, [SP, #-4]!
        STR     LR, [SP, #-4]!

        MOV     LR, #3
        STRB    LR, [SP, #0]            ; Set transfer mode

        LDRB    R3, [R1, #4]
        CMP     R3, #7
        MOVHI   R3, #7
        ORR     LR, R3, #&08            ; PIO flow control mode <n>
        STRB    LR, [SP, #1]
        MOV     LR, R0, LSL #IDEDriveShift
        ORR     LR, LR, #IDEDrvHeadMagicBits
        STRB    LR, [SP, #5]
        MOV     LR, #IDECmdSetFeatures
        STRB    LR, [SP, #6]
 [ Debug23
        DREG    R0, "Setting PIO transfer mode for device ",cc,Integer
        DREG    R3, " to ",,Integer
 ]

        MOV     R0, R0, LSL #WinIDEControllerShift-1
        ASSERT  WinIDEDirectionNone = 0
        MOV     R2, SP
        MOV     R5, #0
        BL      DoSwiIDEUserOp

        LDR     R0, [SP, #8]            ; recover device number

        MOV     LR, #3
        STRB    LR, [SP, #0]            ; Set transfer mode

        LDRB    R3, [R1, #6]            ; Ultra DMA?
        TEQ     R3, #&FF
        BEQ     %FT30
        CMP     R3, #MaxUDMAMode
        MOVHI   R3, #MaxUDMAMode
        ORR     R3, R3, #&40            ; set Ultra DMA flag
        B       %FT40
30      LDRB    R3, [R1, #5]            ; else Multiword DMA?
        TEQ     R3, #&FF
        BEQ     %FT90
        CMP     R3, #7                  ; clamp to mode 7
        MOVHI   R3, #7
        ORR     R3, R3, #&20            ; set Multiword DMA flag
40
        STRB    R3, [SP, #1]
        MOV     LR, R0, LSL #IDEDriveShift
        ORR     LR, LR, #IDEDrvHeadMagicBits
        STRB    LR, [SP, #5]
        MOV     LR, #IDECmdSetFeatures
        STRB    LR, [SP, #6]
 [ Debug23
        DREG    R0, "Setting DMA transfer mode for device ",cc,Integer
        DLINE   " to ",cc
        TST     R3, #&40
        BEQ     %FT02
        DLINE   "Ultra",cc
        B       %FT04
02
        DLINE   "Multiword",cc
04
        AND     LR, R3, #7
        DREG    LR," DMA mode ",,Integer
 ]

        MOV     R0, R0, LSL #WinIDEControllerShift-1
        ASSERT  WinIDEDirectionNone = 0
        MOV     R2, SP
        MOV     R5, #0
        BL      DoSwiIDEUserOp
        TEQ     R0, #0
        BNE     %FT90

        ; If this command issued successfully, mark drive as being
        ; ready for DMA.
        MOV     R1, #1
        LDR     R0, [SP, #8]            ; recover device number
        sbaddr  R2, WinIDEDriveDMAFlags
        STRB    R1, [R2, R0]

90      ADD     SP, SP, #8

        Pull    "R0-R3,R5,PC"

 ]

 [ HAL
; Entry: R0=device number (0 or 2)

WinIDESetDefaultTimings
        Push    "R0-R3,LR"
        MOV     R2,#0
        MOV     R3,#&FFFFFF00
        STMFD   SP!,{R2,R3}
        STMFD   SP!,{R2,R3}
        MOV     R1,R0,LSR #1
        MOV     R2,SP
        ADD     R3,SP,#8
        LDR     R0,HAL_IDEDevice_pointer
        Push    "R12"
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_IDESetModes]
        LDR     R12, [SP], #20
        MOV     LR,#0
        LDR     R0,[SP]
        sbaddr  R1,WinIDEDriveDMAFlags
        STRB    LR,[R1,R0]!
        STRB    LR,[R1,#1]
        Pull    "R0-R3,PC"
 ]

        END
