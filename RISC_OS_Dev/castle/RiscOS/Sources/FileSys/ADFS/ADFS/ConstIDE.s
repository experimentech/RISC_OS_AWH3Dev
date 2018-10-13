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
        SUBT    Constant definitions for IDE driver -> ConstIDE

; Change record
; =============
;
; CDP - Christopher Partington, Cambridge Systems Design
; SBP - Simon Proven
;
;
; 11-Jan-91  11:45  CDP
; File created.
;
; 08-Apr-91  17:20  CDP
; Added WinIDEMaxSectorsPerTransfer to make it easier to adjust the
; maximum transfer size to get around problems with some manufacturers'
; firmware.
; IDEUseRAMCode removed and code dependent on it made permanent.
; As needed to change bits or'ed in during drive/head selection to please
; various manufacturers, replaced literals with constant IDEDrvHeadMagicBits.
;
; 02-Apr-92  16:18  CDP
; WinIDETimeoutSpinup, WinIDETimeoutTransfer, WinIDETimeoutMisc changed from
; 15 to 30 seconds to allow for slower drives (RP-2001).
;
; 24-Aug-1994 SBP
; Added WinIDEUseLBA to allow selection of CHS or LBA addressing by examining
; the boot block.  WinIDEFileCoreOpFormat - code of Format operation.
; BootBlockAddr added to check if we are reading the boot block
;
;*End of change record*

;*********************************************************************

; Assembler flags
;
; IDEResetOnInit, if enabled, causes the drive to be reset when
; the module initialises. This should not be necessary unless
; something bad happened before and it adds a long delay before the
; drives can be used.
;
; IDEResetOnError, if enabled, causes the drive to be reset when
; an error occurs. This would be a good thing but for the fact that
; a drive can take 30 seconds to recover from reset.

                        GBLL    IDEResetOnInit
                        GBLL    IDEResetOnError

IDEResetOnInit          SETL    {FALSE}
IDEResetOnError         SETL    {TRUE}

;*********************************************************************

; Service calls used by ADFS to talk to ST506/IDE podules.
; ADFS defines WinnieService - this should be same as that
; allocated in $.Hdr.Services

        ASSERT  WinnieService = Service_ADFSPodule

; IDE uses Service_ADFSPoduleIDE

;*********************************************************************

 [ TwinIDEHardware
WinIDEMaxDrives *       4
 |
WinIDEMaxDrives *       2
 ]


; IDE registers - addressed using register "IDE".
; All registers are byte wide apart from data register.

IDE     RN      11
 [ HAL
IDECtrl RN      10
 ]

        GBLA    IDEReg_Spacing
 [ ByteAddressedHW
IDEReg_Spacing  SETA    1
 |
IDEReg_Spacing  SETA    4
 ]

                ^       0,IDE
; Command block registers

IDERegCmdBase   #       0
IDERegData      #       IDEReg_Spacing
IDERegFeatures  #       IDEReg_Spacing  ; write only
IDERegSecCount  #       IDEReg_Spacing  ; read/write
IDERegLBALow    #       IDEReg_Spacing
IDERegLBAMid    #       IDEReg_Spacing
IDERegLBAHigh   #       IDEReg_Spacing
IDERegDevice    #       IDEReg_Spacing
IDERegCommand   #       IDEReg_Spacing  ; write only

IDERegError     *       IDERegFeatures  ; read only
IDERegStatus    *       IDERegCommand   ; read only

IDERegSecNumber *       IDERegLBALow    ; (obsolete in ATA-6)
IDERegCylLo     *       IDERegLBAMid    ;         ""
IDERegCylHi     *       IDERegLBAHigh   ;         ""
IDERegDrvHead   *       IDERegDevice    ;         ""

; Bits which must be ORRed into the drive/head select bits

IDEDrvHeadMagicBits     *       2_10100000
IDEDrvLBA24to27MagicBits *      2_11100000
IDEDriveShift   *       4               ; bit number in RegDrvHead

; Stuff for choosing CHS or LBA addressing

WinIDEFileCoreOpFormat  *       4
BootEnd                 *       &E00

IDERegCtlDefaultOffset  * (&3F4 - &1F0) * IDEReg_Spacing

 [ HAL
                ^       0,IDECtrl
 |
                ^       IDERegCtlDefaultOffset,IDE
 ]
; Control block registers

IDERegCtlBase   #       0
IDERegCtlUnused #       2 * IDEReg_Spacing
IDERegAltStatus #       IDEReg_Spacing  ; read only
IDERegDevCtrl   *       IDERegAltStatus ; write only
IDERegDriveAddr #       IDEReg_Spacing  ; read only (obsolete in ATA-2)

IDEDevCtrlHOB   *       bit7            ; High Order Byte (48-bit addressing)
IDEDevCtrlSRST  *       bit2            ; Software Reset
IDEDevCtrlnIEN  *       bit1            ; not Interrupt Enable


; Bits in status register

IDEStatusBSY    *       bit7            ; 1 => controller is busy
IDEStatusDRDY   *       bit6            ; 1 => drive is ready
IDEStatusDF     *       bit5            ; 1 => device fault
IDEStatusDSC    *       bit4            ; 1 => drive seek complete (obsolete in ATA-4)
IDEStatusDRQ    *       bit3            ; 1 => data request
IDEStatusCORR   *       bit2            ; 1 => corrected data (obsolete in ATA-4)
IDEStatusIDX    *       bit1            ; 1 => disc index (obsolete in ATA-4)
IDEStatusERR    *       bit0            ; 1 => some error, err reg is valid
IDEStatusErrorBits      *       IDEStatusBSY:OR:IDEStatusDF:OR:IDEStatusERR

ATAPIStatusBSY  *       bit7            ; 1 => controller is busy
ATAPIStatusDRDY *       bit6            ; 1 => drive is ready
ATAPIStatusDMRD *       bit5            ; 1 => DMA ready
ATAPIStatusDF   *       bit5            ; 1 => device fault
ATAPIStatusSERV *       bit4            ; 1 => another command ready to be serviced
ATAPIStatusDRQ  *       bit3            ; 1 => data request
ATAPIStatusCHK  *       bit0            ; 1 => error has occurred - check

; Bits in error register

IDEErrorBBK     *       bit7            ; 1 => bad block mark encountered (obsolete in ATA-2)
IDEErrorICRC    *       bit7            ; 1 => interface CRC error (Ultra DMA) (new in ATA-4)
IDEErrorUNC     *       bit6            ; 1 => uncorrectable data
IDEErrorMC      *       bit5            ; 1 => media changed
IDEErrorIDNF    *       bit4            ; 1 => sector id not found
IDEErrocMCR     *       bit3            ; 1 => media change requested
IDEErrorABRT    *       bit2            ; 1 => command aborted
IDEErrorNTK0    *       bit1            ; 1 => track 0 not found
IDEErrorNDAM    *       bit0            ; 1 => no data address mark (obsolete in ATA-4)

ATAPIErrorSense *       2_11110000
ATAPIErrorSenseShift *  4               ; sense key (command specific)
ATAPIErrorABRT  *       bit2            ; 1 => command aborted
ATAPIErrorEOM   *       bit1            ; command specific
ATAPIErrorILI   *       bit0            ; command specific

; Key: M = mandatory (for non-ATAPI)
;      O = optional (for non-ATAPI)
;      A = ATAPI only
;      m = mandatory, but hosts shouldn't use

;                                                  ATA spec
; IDE commands                          used?   1 2 3 4 5 6 7

IDECmdNOP       *       &00             ; N     O O O O O O O
IDECmdDeviceReset *     &08             ; Y           A A A A
IDECmdRestore   *       &10             ; Y     M O O
IDECmdReadSecs  *       &20             ; Y     M M M M M M M
IDECmdReadSecsEng *     &21             ; N     M M M m
IDECmdReadLong  *       &22             ; N     M O O
IDECmdReadLongEng *     &23             ; N     M O O
IDECmdReadSecsExt *     &24             ; Y               O O
IDECmdReadDMAExt *      &25             ; Y               O O
IDECmdReadDMAQueuedExt * &26            ; N               O O
IDECmdReadNativeMaxAddrExt * &27        ; N               O O
IDECmdReadMultipleExt * &29             ; N               O O
IDECmdReadStreamDMA *   &2A             ; N                 O
IDECmdReadStreamPIO *   &2B             ; N                 O
IDECmdReadLogExt *      &2F             ; N                 O
IDECmdWriteSecs *       &30             ; Y     M M M M M M M
IDECmdWriteSecsEng *    &31             ; N     M M M m
IDECmdWriteLong  *      &32             ; N     M O O
IDECmdWriteLongEng *    &33             ; N     M O O
IDECmdWriteSecsExt *    &34             ; Y               O O
IDECmdWriteDMAExt *     &35             ; Y               O O
IDECmdWriteDMAQueuedExt * &36           ; N               O O
IDECmdSetMaxAddrExt *   &37             ; N               O O
IDECmdWriteMultipleExt * &39            ; N               O O
IDECmdWriteStreamDMA *  &3A             ; N                 O
IDECmdWriteStreamPIO *  &3B             ; N                 O
IDECmdWriteVerify *     &3C             ; N     O O O
IDECmdWriteDMAFUAExt *  &3D             ; N                 O
IDECmdWriteDMAQueuedFUAExt * &3E        ; N                 O
IDECmdWriteLogExt *     &3F             ; N               O O
IDECmdVerify    *       &40             ; Y     M M M M M M M
IDECmdVerifyEng *       &41             ; Y     M M M m
IDECmdVerifyExt *       &42             ; Y               O O
IDECmdFormatTrk *       &50             ; Y     M V V
IDECmdConfigureStream * &51             ; N                 O
IDECmdSeek      *       &70             ; Y     M M M M M M
IDECmdDiagnose  *       &90             ; N     M M M M M M M
IDECmdInitParms *       &91             ; Y     M M M M M
IDECmdDownloadMicrocode * &92           ; N       O O O O O O
IDECmdPacket    *       &A0             ; Y           A A A A
IDECmdIdentifyPacket *  &A1             ; Y           A A A A
IDECmdService   *       &A2             ; N           A A O O
IDECmdSMART     *       &B0             ; N         O O O O O
IDECmdDeviceConfig *    &B1             ; N               O O
IDECmdReadMultiple *    &C4             ; N     O O M M M M M
IDECmdWriteMultiple *   &C5             ; N     O O M M M M M
IDECmdSetMultiple *     &C6             ; N     O O M M M M M
IDECmdReadDMAQueued *   &C7             ; N           O O O O
IDECmdReadDMA   *       &C8             ; Y     O O M M M M M
IDECmdReadDMAEng *      &C9             ; N     O O M m
IDECmdWriteDMA  *       &CA             ; Y     O O M M M M M
IDECmdWriteDMAEng *     &CB             ; N     O O M m
IDECmdWriteDMAQueued *  &CC             ; N           O O O O
IDECmdWriteMultipleFUAExt * &CE         ; N                 O
IDECmdCheckMediaCardType * &D1          ; N               O O
IDECmdGetMediaStatus *  &DA             ; N           O O O O
IDECmdAckMediaChange *  &DB             ; N     O O
IDECmdBootPostBoot *    &DC             ; N     O O
IDECmdBootPreBoot *     &DD             ; N     O O
IDECmdMediaLock *       &DE             ; N     O O O O O O O
IDECmdMediaUnlock *     &DF             ; N     O O O O O O O
IDECmdStandbyImm *      &E0             ; N     O O O M M M M
IDECmdIdleImm   *       &E1             ; N     O O O M M M M
IDECmdStandby   *       &E2             ; Y     O O O M M M M
IDECmdIdle      *       &E3             ; Y     O O O M M M M
IDECmdReadBuffer *      &E4             ; N     O O O O O O O
IDECmdCheckPower *      &E5             ; Y     O O O M M M M
IDECmdSleep     *       &E6             ; N     O O O M M M M
IDECmdFlushCache *      &E7             ; N           O M M M
IDECmdWriteBuffer *     &E8             ; N     O O O O O O O
IDECmdWriteSame *       &E9             ; N     O O
IDECmdFlushCacheExt *   &EA             ; N               O O
IDECmdIdentify  *       &EC             ; Y     O M M M M M M (ATAPI will abort)
IDECmdMediaEject *      &ED             ; N       O O O O O O
IDECmdIdentifyDMA *     &EE             ; N         O
IDECmdSetFeatures *     &EF             ; Y     O O M M M M M
IDECmdSecSetPassword *  &F1             ; N         O O O O O
IDECmdSecUnlock *       &F2             ; N         O O O O O
IDECmdSecErasePrepare * &F3             ; N         O O O O O
IDECmdSecEraseUnit *    &F4             ; N         O O O O O
IDECmdSecFreezeLock *   &F5             ; N         O O O O O
IDECmdSecDisPassword *  &F6             ; N         O O O O O
IDECmdReadNativeMaxAddr * &F8           ; N           O O O O
IDECmdSetMaxAddr *      &F9             ; N           O O O O

; Identify block
                        ^       0
WinIDEIdGeneral         #       2       ; 0
IIGeneral_Removable     * bit7          ;       F F F F F F
IIGeneral_PacketLength  * bit1+bit0
IIGeneral_Packet12      * 0
IIGeneral_Packet16      * 1
WinIDEIdCylinders       #       2       ; 1     F F F F f
                        #       2       ; 2
WinIDEIdHeads           #       2       ; 3     F F F F f
                        #       4       ; 4-5
WinIDEIdSectors         #       2       ; 6     F F F F f
                        #       6       ; 7-9
WinIDEIdSerialNumber    #       20      ; 10-19 F F F F F F
                        #       4       ; 20-21
WinIDEIdECCBytes        #       2       ; 22
WinIDEIdFirmwareRevision #      8       ; 23-26 F F F F F F
WinIDEIdModel           #       40      ; 27-46 F F F F F F
WinIDEIdMaxMultiple     #       1       ; 47    F F F
                        #       1
                        #       2       ; 48
WinIDEIdCapabilities    #       2       ; 49
IICap_LBA * bit8                        ;       F F (ATA-3 mandates LBA)
IICap_DMA * bit9                        ;       F F (ATA-3 removed single word DMA)
IICap_IORDYdisable * bit10              ;         F F F
IICap_IORDY * bit11                     ;         F F F
IICap_StandbyTimer * bit13              ;         F F F
WinIDEIdCapabilities2   #       2       ; 50            F
                        #       1       ; 51
WinIDEIdPIOTiming       #       1       ;       F F F
                        #       1       ; 52
WinIDEIdDMATiming       #       1       ;       F F (ATA-3 removed single word DMA)
WinIDEIdValidWordsFlags #       2       ; 53
IIValid_Words54_58 * bit0               ;       V V V V V
IIValid_Words64_70 * bit1               ;         F F F F F
IIValid_Word88     * bit2               ;             F F F

WinIDEIdCurrentCylinders #      2       ; 54    v v v v v
WinIDEIdCurrentHeads    #       2       ; 55    v v v v v
WinIDEIdCurrentSectors  #       2       ; 56    v v v v v
WinIDEIdCurrentCHSCapacity #    4       ; 57-58 v v v v v

WinIDEIdCurrentMultiple #       2       ; 59    V V V V V V
WinIDEIdLBAAddressable  #       4       ; 60-61 F F F F F F
WinIDEIdDMAMode         #       2       ; 62    V V
WinIDEIdMultiwordDMAMode #      2       ; 63    V V V V

WinIDEIdPIOModes        #       2       ; 64      f f f f f
WinIDEIdMinMultiwordDMACycle #  2       ; 65      f f f f f
WinIDEIdRecMultiwordDMACycle #  2       ; 66      f f f f f
WinIDEIdMinPIOCycle     #       2       ; 67      f f f f f
WinIDEIdMinPIOCycleIORDY #      2       ; 68      f f f f f
                        #       12      ; 69-74
WinIDEIdQueueDepth      #       2       ; 75            f f
                        #       8       ; 76-79
WinIDEIdMajorATAVersion #       2       ; 80        F F F F
WinIDEIdMinorATAVersion #       2       ; 81        F F F F
WinIDEIdCommandSets1    #       2       ; 82        F F F F
WinIDEIdCommandSets2    #       2       ; 83        F F F F
IICS2_48bit * bit10
WinIDEIdCommandSets3    #       2       ; 84          F F F
WinIDEIdCommandEnabled1 #       2       ; 85          V V V
WinIDEIdCommandEnabled2 #       2       ; 86          V V V
WinIDEIdCommandDefaults #       2       ; 87          V V V
WinIDEIdUltraDMAMode    #       2       ; 88            v v
                        #       8       ; 89-92
WinIDEIdResetResult     #       2       ; 93            F F
                        #       12      ; 94-99
WinIDEIdLBA48Addressable #      8       ; 100-103         f
                        #       48      ; 104-127
WinIDEIdSecurityStatus  #       2       ; 128         v
                        #       252     ; 129-254
WinIDEIdIntegritySig    #       1       ; 255
WinIDEIdChecksum        #       1

        ASSERT  @ = 512

SzWinIDEId              *       512





; IDE drive parameters

WinIDEBytesPerSector    *       512     ; bytes per sector
WinIDELowSector         *       1       ; lowest-numbered sector


; WinIDEMaxSectorsPerTransfer is a limit on the number of sectors that
; can be requested for any transfer. This *should* be 256 according to
; the CAM spec. but several drive manufacturers (Seagate, Sony etc.) have
; firmware bugs that causes this to fail. Most manufacturers seem to
; handle 255 ok.

WinIDEMaxSectorsPerTransfer     *       256

;*********************************************************************

; Error numbers (0 < n <= MaxDiscErr)
; =============
;
; I have attempted to map as many as possible onto the error numbers
; returned by the ST506 driver. The error codes for these are shown
; in brackets.

WinIDEErrABRT           *       &02     ; (IVC) command aborted by controller
WinIDEErrWFT            *       &07     ; (WFL) write fault
WinIDEErrCmdNotRdy      *       &08     ; (NRY) drive not ready
WinIDEErrNTK0           *       &09     ; (NSC) track 0 not found
WinIDEErrUNC            *       &13     ; (DFE) uncorrected data error
WinIDEErrIDNF           *       &16     ; (TOV) sector id field not found
WinIDEErrBBK            *       &17     ; (NIA) bad block mark detected
WinIDEErrNDAM           *       &18     ; (NDA) no data address mark


; Errors which cannot be mapped onto the error codes returned
; by the ST506 controller.

WinIDEErrNoDRQ          *       &20     ; no DRQ when expected
WinIDEErrCmdBusy        *       &21     ; drive busy when commanded
WinIDEErrBusy           *       &22     ; drive busy on command completion
WinIDEErrTimeout        *       &23     ; controller did not respond
WinIDEErrUnknown        *       &24     ; unknown code in error reg
WinIDEErrPacket         *       &25     ; other error in Packet command
WinIDEErrICRC           *       &26     ; interface CRC error

;*********************************************************************

; Hardware-dependent fields in the boot block addressed from the
; register pointing to the defect list.


WinIDENeedsInit *       ParkDiscAdd - 1 ; !0 => drive needs init before use
WinIDEUseLBA    *       ParkDiscAdd - 2 ; !0 => drive accessed using LBA addressing

;*********************************************************************

; Timeouts in centiseconds - most set large enough to allow for drive
; spinning up after autospindown. Could change this in future to be
; short when drive known to be spinning.

WinIDETimeoutSpinup     *       &C00    ; ~30 seconds spinup
WinIDETimeoutIdle       *       &C00    ; ~30 seconds recovery from idle cmd
WinIDETimeoutTransfer   *       &C00    ; ~30 seconds data transfer ops
WinIDETimeoutMisc       *       &C00    ; ~30 seconds seek, restore etc.

WinIDETimeoutUser       *       10*100  ; 10 seconds user ops

;*********************************************************************

; States of IDE drives to control spinup and parameter initialisation
; (stored in WinIDEDriveState variables)

WinIDEDriveStateReset           *       0       ; has been reset
WinIDEDriveStateIdled           *       1       ; rcvd idle cmd
WinIDEDriveStateSpinning        *       2       ; needs parm init
WinIDEDriveStateActive          *       3       ; ready for access

;*********************************************************************

; ATAPI constants

WinIDEATAPIByteCount    *       4096    ; max data per DRQ

;*********************************************************************

; Data direction stuff

WinIDEControllerShift   *       16
WinIDEDirectionRead     *       bit24
WinIDEDirectionWrite    *       bit25
WinIDEDirectionNone     *       0
WinIDEDirectionMask     *       bit24 :OR: bit25

;*********************************************************************

; Bit in podule interrupt status that tells OS that podule is
; interrupting

WinIDEPodIRQRequest     *       bit0

;*********************************************************************

        END
