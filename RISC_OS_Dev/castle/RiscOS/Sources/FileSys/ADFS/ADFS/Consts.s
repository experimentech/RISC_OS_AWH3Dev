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

bit0    bit 0
bit1    bit 1
bit2    bit 2
bit3    bit 3
bit4    bit 4
bit5    bit 5
bit6    bit 6
bit7    bit 7
bit8    bit 8
bit9    bit 9
bit10   bit 10
bit11   bit 11
bit12   bit 12
bit13   bit 13
bit14   bit 14
bit15   bit 15
bit16   bit 16
bit17   bit 17
bit18   bit 18
bit19   bit 19
bit20   bit 20
bit21   bit 21
bit22   bit 22
bit23   bit 23
bit24   bit 24
bit25   bit 25
bit26   bit 26
bit27   bit 27
bit28   bit 28
bit29   bit 29
bit30   bit 30
bit31   bit 31

EscapeBit       bit 6           ;escape if this bit set in ESC_Status

; BigDisc - if true then use sector addressing, false use byte

        GBLL    BigDisc
BigDisc SETL    {TRUE}

 [ BigDisc
BigBit * CreateFlag_BigDiscSupport
 |
BigBit * 0
 ]

; Hardware addresses

 [ :LNOT: HAL
CnTbase          * &03010000 ; Base address of 82C710 = PC/AT I/O 000H
BerlinFlpAddr    * &32000000 ; Blah blah blah
FdcAddress       * &03310000
 ]

FdcStatus        * 0
FdcMotorOnBit    bit 7
WProtBit         bit 6  ;write protect
RecTypeBit       bit 5  ;record type
WFaultBit        bit 5  ;write fault
RnfBit           bit 4  ;record not found
CrcBit           bit 3  ;crc error
LostBit          bit 2  ;lost data
Track0Bit        bit 2
BusyBit          bit 0
FdcCommand       * FdcStatus
FdcReadSec       * &88  ;no 15/30 ms delay
FdcWriteSec      * &AA  ;no 15/30 ms delay no pre comp
FdcReadTrk       * &E8  ;no 15/30 ms delay
FdcReadAddress   * &C8  ;no 15/30 mS delay
FdcWriteTrk      * &FE  ;15/30 ms delay, no pre comp
FdcSeek          * &18  ;no verify
FdcRestore       * &08  ;no verify
FdcStepIn        * &58  ;update, but no verify
FdcStepOut       * &78  ;update, but no verify
FdcStepInVerify  * &5C  ;update, but no verify
FdcStepOutVerify * &7C  ;update, but no verify
FdcAbort         * &D0  ;abort current command
NotType1Bit      bit 7
Delay15or30msBit bit 2
VerifyBit        bit 2
SettleBit        bit 2
NotPrecompBit    bit 1
PrecompTrk       * 80/2
FdcStepBits      * &03
FdcTrack         * 4
FdcSector        * 8
FdcData          * 12
TrksPerSide      * 80

 [ fix_2
                        ;centi seconds between upcalls when disc changed works
PollPeriodShort  * 10   ; if drive has disc changed reset line
PollPeriodLong   * 100  ; if disc changed reset by step
 |
PollPeriod       * 10   ;centi seconds between upcalls when disc changed works
 ]
FloppyEraseDelay * 1200 ;in micro secs
 [ TwinIDEHardware
MaxWinnies       * 0
 |
MaxWinnies       * 2
 ]

 [ :LNOT: HAL
IoChip          * &03200000
 ]
;IOCControl
ReadyBit        bit 2
DiscChangedBit  bit 4

;IRQA
FiqDowngradeBit bit 7

;IRQB
IoIrqBStatus    * &20
IoIrqBMask      * &28
PIRQ    bit 5           ;podule IRQ

IoFiqStatus     * &30
IoDrqBitNo      * 0
IoDrqBit        bit IoDrqBitNo
IoFloppyIrqBit  bit 1

FiqRequest      * &34

FiqMask         * &38
FdcFiqMaskBits  * &03
Timer0Period    * 20000

 [ :LNOT: HAL
SharedLatch     * &03350018
 ]
FdcResetBit     bit 3
HeadSelectBit3  bit 7
Single          * 1
Double          * 2
Quad            * 4
DensityBits     * &02
SingleBits      * &02
DoubleBits      * &00

 [ :LNOT: HAL
DiscLatch       * &03350040
 ]
Drive0          bit 0
Drive1          bit 1
Drive2          bit 2
Drive3          bit 3
DriveBits       * Drive0 :OR: Drive1 :OR: Drive2 :OR: Drive3
SideBit         bit 4
MotorBit        bit 5
InUseBit        bit 6
MotorBits       * MotorBit :OR: InUseBit
NotResetDiscChangedBit bit 7

;Various
K               * 1024
M               * K*K
LF              * 10
CR              * 13
DeleteChar      * 127

;Cpu
FiqVector        * &1C
FiqVectorMaxCode * &FC       ;last word allowed for FIQ code
BalOpHi          * &EA000000
SB               RN 12



;Disc Operation Reason Codes
 ! 0, "Internal floppy disc ops overlap FileCore allocations"
StepInVerifyOp  * 9     ;9 floppy only
StepOutVerifyOp * &A    ;A floppy only
UnusedFloppyOp  * &B
 [ fix_6
ReadSecsBackOp  * DiscOp_ReadTrk
WriteSecsBackOp * &B    ;B (only used internally)
 ]

        ASSERT (1:SHL:BackBitNo) = DiscOp_Op_BackgroundOp_Flag
BackBitNo       * 8
DiscBits        * 2_111 :SHL: (32-3)    ;In all disc addresses

; service reason codes

WinnieService           * &10800

; CMOS allocation

        ^       NewADFSCMOS
NewCMOS0 # 1
; b0-b2 = floppies (0 to 4)
; b3-b5 = ST506 drives winnies (0 to MaxWinnies)
; b6-b7 = IDE drives (0 to WinIDEMaxDrives)
StepDelayCMOS    # 1
; bits 2i,2i+1 are step rate bits for floppy i (i=0,1,2,3)
 [ FileCache
FileCacheCMOS    # 1    ;number of additional file cache buffers
 ]
 ASSERT ADFSDirCacheCMOS = &C7

        END
