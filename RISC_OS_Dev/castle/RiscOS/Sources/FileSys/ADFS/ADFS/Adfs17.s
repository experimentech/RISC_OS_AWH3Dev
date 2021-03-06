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
;>Adfs17
        SUBT    82C710/'765 floppy disk drivers
;-----------------------------------------------------------------------;
; (C) Copyright 1990 Acorn Computers Limited,                           ;
; Fulbourn Road, Cambridge CB1 4JN, England.                            ;
; Telephone 0223 214411.                                                ;
;                                                                       ;
; All rights reserved.  The software code in this listing is proprietary;
; to Acorn Computers Ltd., and is covered by copyright protection.      ;
; The unauthorized copying, adaptation, distribution, use or display    ;
; is prohibited without prior consent.                                  ;
;-----------------------------------------------------------------------;
; Revision History:                                                     ;
; No.    Date    By     Reason                                          ;
;-----------------------------------------------------------------------;
; 01  10 Dec 90  lrust  Conception                                      ;
; 02  08 Mar 91  lrust  Alpha version                                   ;
; 03  15 Mar 91  lrust  RiscOS 2.09 release                             ;
; 04  22 Mar 91  lrust  Revised step rates, tidied comments             ;
; 05  24 May 91  lrust  Fixed bug in drive empty timeout                ;
; 06  16 Dec 91  lrust  Added portable power stuff                      ;
; 07  04 Feb 92  lrust  Re-entrant IRQ handlers                         ;
;_______________________________________________________________________;
;
Adfs17Ed        * 07                    ; Edition number

                GBLL    FlpIRQreenable
FlpIRQreenable  SETL    {TRUE}          ; T for re-entrant IRQ handlers

                GBLL    FlpUseFIFO
FlpUseFIFO      SETL    :LNOT:FloppyPCI ; T to use FIFO in the SMC '665

                GBLL    FlpUseVerify
FlpUseVerify    SETL    {TRUE}          ; T to use Verify command in '665

                GBLL    FlpMediaCheck
FlpMediaCheck   SETL    {FALSE}         ; T to check density from disc/drive

                GBLL    FlpFlushPBI     ; A dummy flush as XScale 80321 queues PBI writes
FlpFlushPBI     SETL    FloppyPodule :LOR: FloppyPCI

;-----------------------------------------------------------------------;
; This file provides routines to control the '765 FDC and the disk      ;
; drive sub-systems.  The following functions are implemented:          ;
;                                                                       ;
;       FlpFDCcontrol - Power control for portable                      ;
;       Flp765read -    Read a byte from the '765 FDC                   ;
;       Flp765write -   Write a byte to the '765 FDC                    ;
;       Flp765BlkWr -   Write a block of data to the '765 FDC           ;
;       FlpIRQstatus -  Issue "sense interrupt" command to '765,        ;
;                         returning ST0 and PCN.                        ;
;       Flp765specify - Issue "specify" command to '765 with SRT        ;
;                         calculated from configured step rate and      ;
;                         current clock selected.                       ;
;       Flp765reset -   Reset the '765 FDC and the FDC state system     ;
;       FlpGetDskChng - Read disk change status                         ;
;       FlpMediaID -    Read media ID/density                           ;
;       Flp765IRQ -     '765 FDC IRQ service                            ;
;       FlpIndexIRQ -   Index pulse IRQ service                         ;
;       FlpTickerV -    Centisecond clock tick service                  ;
;       FDC state system:                                               ;
;         FlpStateReset                                                 ;
;         FlpStateReady                                                 ;
;         FlpStateSeek                                                  ;
;         FlpStateRecal                                                 ;
;         FlpStateSettle                                                ;
;         FlpStateBusy                                                  ;
;       FlpDrvSelect -  Select a drive and start the drive motor        ;
;       Drive state system:                                             ;
;         FlpDriveOff                                                   ;
;         FlpDriveSpinup                                                ;
;         FlpDriveEmpty                                                 ;
;         FlpDriveReady                                                 ;
;_______________________________________________________________________;

; '765 Hardware Definitions
;--------------------------
;
;FlpBase         * CnTbase + (&3F0 *4)   ; Base address of '765 registers
;FlpDACK         * CnTbase + &2000       ; Base address of '765 DMA ACK space
;FlpDACK_TC      * CnTbase + &1A000      ; '765 DMA ACK with TC (to terminate DMA)
FlpDACK_Offset    * &02000              ; From SuperIO controller base
FlpDACK_TC_Offset * &18000              ; From FlpDACK

FlpHiDensity    bit 2                   ; Density i/p in IoControl

 [ FloppyPCI
FlpFintr        * 23                    ; Device number for '765 IRQ
FlpIndex        * 2                     ; Device number for Index pulse IRQ
 |
FlpDRQmaskbit   * 0                     ; '765 DRQ FIQ mask for IOC
 [ FloppyPodule
FlpFintr        * 13
FlpIndex        * 13
 |
FlpFintr        * 12                    ; Device number for '765 IRQ
FlpIndex        * 2                     ; Device number for Index pulse IRQ
 ]
 ]

        GBLA    FlpReg_Spacing
 [ ByteAddressedHW :LAND: :LNOT: FloppyPodule
FlpReg_Spacing  SETA    1
 |
FlpReg_Spacing  SETA    4
 ]

; FDC registers, offset from FlpBase
;
FlpStatusA      * 0 *FlpReg_Spacing     ; R/O Status reg A (PS/2 only)
FlpStatusB      * 1 *FlpReg_Spacing     ; R/O Status reg A (PS/2 only)
FlpDOR          * 2 *FlpReg_Spacing     ; W/O Digital o/p reg (drive select)
FlpStatus       * 4 *FlpReg_Spacing     ; R/O '765 status register
FlpData         * 5 *FlpReg_Spacing     ; R/W '765 data register
FlpDIR          * 7 *FlpReg_Spacing     ; R/O Digital i/p reg, b7= disk change, (b0= LoDen PS/2)
FlpCCR          * 7 *FlpReg_Spacing     ; W/O Config control reg, b0,1= data rate

; FDC implementation
;
FlpMaxWait      * 1000                  ; Max loop count waiting for ready, min 100 @ 8MHz
 [ fix_11
FlpMotorOnDelayIn * 60                  ; Internal drives centisecond motor on delay
                                        ; extended with empty timer to give in-spec
                                        ; total time (1 sec spinup + 1rev = 1.2 secs)
 |
FlpMotorOnDelayIn * 50                  ; Internal drives centisecond motor on delay
 ]
FlpMotorOnDelayEx * 100                 ; External drives centisecond motor on delay
 [ fix_11
FlpEmptyTimer   * 61                    ; Index pulse timeout for empty (200mS nom)
 |
FlpEmptyTimer   * 40                    ; Index pulse timeout for empty (200mS nom)
 ]
FlpIPidleOff    * 8                     ; Idle Index Pulse count for motor off
FlpMotorOffDelay * 200                  ; Centisecond motor off timeout from Empty
FlpCmdTimeOut   * 250                   ; Centisecond command timeout
FlpIdleTimer    * 250                   ; Centisecond FDC idle timeout
FlpResetTimer   * 25                    ; Centisecond FDC reset timer
FlpSettleDelay  * 3                     ; Centisecond head settling delay, >15mS

 [ {FALSE}
; Status A register bits
;
FlpSRAIRQ       bit 7                   ; IRQ pending
FlpSRADrv2      bit 6                   ; Drv 2 pin status
FlpSRAStep      bit 5                   ; Step pin status
FlpSRATrk0      bit 4                   ; Track 0 signal status
FlpSRAHdSel     bit 3                   ; Head select signal
FlpSRAIndx      bit 2                   ; index status
FlpSRAWP        bit 1                   ; WP status
FlpSRADir       bit 0                   ; Dir status
 ]

FlpMediaIDIRQ   bit 2                   ; media ID byte IRQ indicator

; Digital output register bits
;
FlpDORme3       bit 7                   ; Motor enable 3
FlpDORme2       bit 6                   ; Motor enable 2
FlpDORme1       bit 5                   ; Motor enable 1
FlpDORme0       bit 4                   ; Motor enable 0
FlpDORirqEn     bit 3                   ; DMA/IRQ enable
FlpDORreset     bit 2                   ; '765 reset
FlpDORdrv1      bit 1                   ; MSB drive select
FlpDORdrv0      bit 0                   ; LSB drive select

; Digital input register bits
;
FlpDIRchanged   bit 7                   ; Disk changed if 1

; Configuration control register settings
;
FlpCCR250K      * 2_00000010            ; 250 Kbps MFM, 4MHz clock
FlpCCR300K      * 2_00000001            ; 300 Kbps MFM, 4.8MHz clock
FlpCCR500K      * 2_00000000            ; 500 Kbps MFM, 8MHz clock
FlpCCR1000K     * 2_00000011            ; 1000 Kbps MFM, 16MHz clock

; '765 status register bits
;
FlpStatRQM      bit 7                   ; Request for master, 1= data reg ready
FlpStatDIO      bit 6                   ; Data direction, 1= read
FlpStatEXM      bit 5                   ; Execution mode
FlpStatCIP      bit 4                   ; Command in progress
; Bits 0..3 are seek in progress on drives 0..3

; '765 commands, MFM mode
;
FlpCmdFormat    * &4D                   ; Format track... drv, n, sc, gp3, d
FlpCmdRecal     * &07                   ; Recalibrate... drv
FlpCmdSeek      * &0F                   ; Seek... drv, track
FlpCmdReadID    * &4A                   ; Read sector ID... drv
FlpCmdSenseIRQ  * &08                   ; Sense interrupt status
FlpCmdSenseDrv  * &04                   ; Sense drive status
FlpCmdSpecify   * &03                   ; Specify... sat/hut, hlt/dma
FlpCmdRdTrack   * &42                   ; Read a track... drv,c,h,r,n,eot,gpl,dtl
FlpCmdScanLE    * &59                   ; Scan low or equal
FlpCmdScanEQ    * &51                   ; Scan equal
FlpCmdScanHE    * &5D                   ; Scan high or equal
FlpCmdRead      * &46                   ; Read sectors... drv,c,h,r,n,eot,gpl,dtl
FlpCmdVerify    * &56                   ; Verify sectors... drv,c,h,r,n,eot,gpl,sc
FlpCmdWrite     * &45                   ; Write sectors...drv,c,h,r,n,eot,gpl,dtl
FlpCmdRdDel     * &4C                   ; Read deleted data
FlpCmdWrDel     * &49                   ; Write deleted data
FlpCmdConfigure * &13                   ; Configure controller
FlpCmdVersion   * &10                   ; Read controller version ('665 = &90)

; '765 command modifiers, EOR with command
;
FlpCmdMT        bit 7                   ; Multitrack - not used by ADFS
FlpCmdFM        bit 6                   ; FM mode, set command byte
FlpCmdSK        bit 5                   ; Skip deleted data
FlpCmdHead      bit 2                   ; Head 0/1, in parameter 1


;-----------------------------------------------------------------------;
; FlpFDCcontol                                                          ;
;       Enable/Disable FDC hardware for power saving on the portable    ;
;                                                                       ;
; Input:                                                                ;
;       R0 = New state, 0= disable, !0= enable                          ;
;                                                                       ;
; Output:                                                               ;
;       R1 = Portable_Flags                                             ;
;                                                                       ;
; Modifies:                                                             ;
;       R0                                                              ;
;       Updates Portable_Flags word                                     ;
;_______________________________________________________________________;
;
FlpFDCcontrol   ROUT
        LDR     R1, Portable_Flags
        TST     R1, #Portable_Present           ; Portable present?
        MOVEQ   PC, LR                          ; No then exit

        Push    "R2,LR"
        TEQ     R0, #0                          ; Disabling FDC?
        MOVNE   R0, #PortableControl_FDCEnable  ; No then set enable bit
        AND     LR, R1, #PortableControl_FDCEnable ; Get FDC enable bit
        TEQ     LR, R0                          ; Any change
        Pull    "R2,PC",EQ                      ; No then exit

        WritePSRc SVC_mode,LR,,R2               ; Switch to SVC mode
        NOP
        Push    "LR"                            ; Save SVC_LR

        MOV     R1, #:NOT:PortableControl_FDCEnable ; FDC enable bit mask
        SWI     XPortable_Control               ; En/Disable FDC H/W
        ORRVC   R1, R1, #Portable_Present       ; No error -> portable
        MOVVS   R1, #PortableControl_FDCEnable  ; Error -> not portable, FDC enabled
 [ IDEPower
        ORRVS   R1, R1, #PortableControl_IDEEnable ; Error -> not portable, IDE enabled
 ]
        Pull    "LR"                            ; Restore SVC_LR
        RestPSR R2,,c                           ; Restore CPU mode
        NOP

 [ Debug10p
        DREG    R1,"New portable flags:"
 ]
        STR     R1, Portable_Flags              ; Save enable state
        Pull    "R2,PC"


;-----------------------------------------------------------------------;
; Flp765read                                                            ;
;       Read a byte from the '765 FDC                                   ;
;                                                                       ;
; Input:                                                                ;
;       None                                                            ;
;                                                                       ;
; Output:                                                               ;
;       R0 = Byte read                                                  ;
;       VC, No error                                                    ;
;       VS, Error                                                       ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
Flp765read      ROUT
        Push    "R2,R3,LR"              ; Save caller's regs
        SavePSR R3
        LDR     R2, FlpBase             ; FDC register base (&3F0 in PC/AT)
        MOV     R0, #FlpMaxWait         ; '765 ready timeout

; Wait for '765 to go ready for reading, or timeout

10      LDRB    LR, [R2, #FlpStatus]    ; Read '765 status
        AND     LR, LR, #FlpStatRQM :OR: FlpStatDIO
        CMPS    LR, #FlpStatRQM :OR: FlpStatDIO ; Ready to read?
        LDREQB  R0, [R2, #FlpData]      ; Yes then read '765
        SUBNES  R0, R0, #1              ; Else decrement timeout
        BNE     %BT10                   ; Loop if not ready and not timed out

        CMPS    LR, #FlpStatRQM :OR: FlpStatDIO ; Data valid?
        BICEQ   R3, R3, #V_bit          ; Yes then return with no error, VC
        ORRNE   R3, R3, #V_bit          ; else return with error
        RestPSR R3,,f
        Pull    "R2,R3,PC"              ; Restore caller's regs


;-----------------------------------------------------------------------;
; Flp765write                                                           ;
;       Write a byte to the '765 FDC                                    ;
;                                                                       ;
; Input:                                                                ;
;       R0 = data to write                                              ;
;                                                                       ;
; Output:                                                               ;
;       VC, No error                                                    ;
;       VS, Error                                                       ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
Flp765write     ROUT
        Push    "R1-R3,LR"              ; Save caller's regs
        SavePSR R3
        LDR     R2, FlpBase             ; FDC register base (&3F0 in PC/AT)
        MOV     R1, #FlpMaxWait         ; '765 ready timeout

; Wait for '765 to go ready for writing, or timeout

10      LDRB    LR, [R2, #FlpStatus]    ; Read '765 status
        AND     LR, LR, #FlpStatRQM :OR: FlpStatDIO
        CMPS    LR, #FlpStatRQM         ; Ready to write?
        STREQB  R0, [R2, #FlpData]      ; Yes then write '765
        SUBNES  R1, R1, #1              ; Else decrement timeout
        BNE     %BT10                   ; Loop if not ready and not timed out

        CMPS    LR, #FlpStatRQM         ; Write occurred?
        BICEQ   R3, R3, #V_bit          ; Yes then return with no error, VC
        ORRNE   R3, R3, #V_bit          ; else return with error
        RestPSR R3,,f
        Pull    "R1-R3,PC"              ; Restore caller's regs


;-----------------------------------------------------------------------;
; Flp765BlkWr                                                           ;
;       Write a block of data to the '765 FDC                           ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Byte count                                                 ;
;       R1 -> '765 data block                                           ;
;                                                                       ;
; Output:                                                               ;
;       VS = error, VC = no error                                       ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags (except V)                                ;
;_______________________________________________________________________;
;
Flp765BlkWr     ROUT
        Push    "R0-R3,LR"              ; Save caller's regs
        SavePSR R3
        AND     R2, R0, #&1F            ; R2 = count

 [ Debug10t :LOR: Debug10c
        DLINE   "Command:",cc
 ]
; Write command and parameters to '765

10      LDRB    R0, [R1], #1            ; Get next parameter, R1++
 [ Debug10t :LOR: Debug10c
        BREG    r0,",",cc
 ]
        BL      Flp765write             ; Write it to '765
        BVS     %FT20                   ; Jump if error
        SUBS    R2, R2, #1              ; Bytes remaining
        BNE     %BT10                   ; Loop until all sent
20
 [ Debug10t :LOR: Debug10c
        DLINE   " "
 ]
        BICVC   R3, R3, #V_bit          ; Return no error if all written
        ORRVS   R3, R3, #V_bit          ; Else return VS= error
        RestPSR R3,,f
        Pull    "R0-R3,PC"


;-----------------------------------------------------------------------;
; FlpIRQstatus                                                          ;
;       Issue sense interrupt status command.  Returns ST0 and PCN      ;
;                                                                       ;
; Input:                                                                ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       No error - VC                                                   ;
;         R1 = ST0                                                      ;
;         R0 = PCN                                                      ;
;       Error - VS                                                      ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpIRQstatus    ROUT
        Push    "LR"
        MOV     R0, #FlpCmdSenseIRQ     ; Sense interupt
        BL      Flp765write             ; Issue command (R0->V)
        BLVC    Flp765read              ; Get ST0 (->R0,V)
        MOV     R1, R0                  ; Save interrupt code
        BLVC    Flp765read              ; Get PCN (->R0,V)
        Pull    "PC"


;-----------------------------------------------------------------------;
; Flp765specify                                                         ;
;       Calculate step rate for current drive and issue specify         ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Clock select for CCR                                       ;
;       R12 -> static base                                              ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
; Step rate:    6mS 12+mS 2mS  3mS
FlpSRT                                  ; Step rate to SRT/HUT lookup table
        DCB     &AF, &4F, &EF, &DF      ; 500K,  6,   12, 2,   3mS
        DCB     &CF, &1F, &FF, &EF      ; 300K,  6.6, 25, 1.7, 3.3mS
        DCB     &DF, &3F, &FF, &EF      ; 250K,  6,   26, 2,   4mS
        DCB     &4F, &0F, &CF, &AF      ; 1000K, 6,  !!8, 2,   3mS
        ALIGN

Flp765specify   ROUT
        Push    "R0-R2,LR"
        SavePSR R2
        LDR     LR, FlpBase             ; R0-> FDC
        STRB    R0, FlpCCRimage         ; Update CCR image
        STRB    R0, [LR, #FlpCCR]       ; Set '765 FDC clock rate

; Map physical drive selected to logical drive

        LDRB    R1, FlpDrvNum           ; Get current physical drive
        sbaddr  R0, FlpDrvMap
10      LDRB    LR, [R0]                ; Get next physical drive #
        TEQS    LR, R1                  ; This drive?
        ADDNE   R0, R0, #1              ; No, next logical drive
        BNE     %BT10                   ; And repeat
        sbaddr  LR, FlpDrvMap
        SUB     R1, R0, LR              ; R1= logical drive

; Get step rate for logical drive

        LDRB    LR, StepRates           ; Get step rates for 4 logical drives
        MOV     LR, LR, LSR R1
        MOV     LR, LR, LSR R1          ; Get step rate for selected drive
        AND     LR, LR, #3              ; Isolate step bits

; Lookup SRT for current drive/clock/step rate

        LDRB    R0, FlpCCRimage         ; Get CCR
        AND     R0, R0, #3              ; Isolate clock select bits
        MOV     R0, R0, LSL #2          ; *4 step rates for each clock rate
        ADD     LR, LR, R0              ; LR indexes FlpSRT table
        baddr   R0, FlpSRT
        LDRB    R1, [R0, LR]            ; Get SRT/HUT for specify
        LDRB    R0, FlpSRTimage         ; Get last value used
        TEQS    R0, R1                  ; Any change?
        BNE     %FT20
        RestPSR R2,,f
        Pull    "R0-R2,PC"              ; No then exit

; Issue specify command
20
 [ {FALSE}
        DREG    R1, "New SRT: "
 ]
        MOV     R0, #FlpCmdSpecify      ; Specify command byte
        BL      Flp765write             ; Send command
        MOV     R0, R1                  ; New step rate
        BLVC    Flp765write             ; Send SRT/HUT
        MOV     R0, #2                  ; Minimum HLT, DMA mode
        BLVC    Flp765write             ; Send HLT
        STRVCB  R1, FlpSRTimage         ; Update SRT image
        RestPSR R2,,f
        Pull    "R0-R2,PC"


;-----------------------------------------------------------------------;
; Flp765reset                                                           ;
;       Soft reset the '765 FDC                                         ;
;                                                                       ;
; Input:                                                                ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
Flp765reset ROUT
        Push    "R0-R2,LR"              ; Save caller's regs
        SavePSR R2

; Set timeout for reset period

        ADDR    LR, FlpStateReset       ; R0-> Reset state handler
        STR     LR, FlpState            ; Change state to reset
        MOV     LR, #2                  ; Ensure at least 10mS reset
        STRB    LR, FlpStateTimer       ; Start reset timer

; Drive '765 reset bit in FlpDOR

        LDR     R1, FlpBase             ; R2-> FDC register base (&3F0 in PC/AT)
        LDRB    LR, FlpDORimage         ; Get DOR image
        BIC     LR, LR, #FlpDORreset    ; Assert reset
        STRB    LR, FlpDORimage         ; Update DOR image
        STRB    LR, [R1, #FlpDOR]       ; Reset '765

        MOV     LR, #FlpCCR500K         ; Default 500Kbps MFM data (8MHz clock)
        STRB    LR, FlpCCRimage         ; Setup CCR image
        STRB    LR, [R1, #FlpCCR]       ; Write configuration control register

; Set all head positions to unknown

        MOV     R0, #3                  ; Drives supported
        DrvRecPtr R1, R0                ; R2-> drive record
        MOV     LR, #PositionUnknown    ; Head position unknown
10      STR     LR, [R1, #HeadPosition] ; Set track unknown
        SUB     R1, R1, #SzDrvRec       ; Next drive record
        SUBS    R0, R0, #1              ; Decr loop counter
        BPL     %BT10                   ; For all drives

        RestPSR R2,,f
        Pull    "R0-R2,PC"              ; Restore caller's regs


;-----------------------------------------------------------------------;
; FlpGetDskChng                                                         ;
;       Read disk changed state                                         ;
;                                                                       ;
; Input:                                                                ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       R0 = DIR reading                                                ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpGetDskChng   ROUT
        LDR     R0, FlpBase             ; R0-> FDC register base (&3F0 in PC/AT)
        LDRB    R0, [R0, #FlpDIR]       ; Read DIR, changed = bit7
        MOV     PC, LR                  ; Return


;-----------------------------------------------------------------------;
; FlpMediaID                                                            ;
;       Read media type from drive                                      ;
;                                                                       ;
; Input:                                                                ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       R0 = Media ID, bit2 = Hi density                                ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpMediaID      ROUT
 [ HAL
        ; This bit always read as 1 in IOMD anyway
        MOV     R0, #FlpHiDensity
 |
        MOV     R0, #IoChip             ; R0-> IOC base
        LDRB    R0, [R0, #IOCControl]   ; Read ID
        AND     R0, R0, #FlpHiDensity   ; Get Density bit
 ]
        MOV     PC, LR                  ; Return


;-----------------------------------------------------------------------;
; Flp765IRQ                                                             ;
;       '765 interrupt service routine                                  ;
;                                                                       ;
; Input:                                                                ;
;       IRQ mode                                                        ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
Flp765IRQ ROUT
        Push    "R0-R2,LR"              ; Save caller's regs on IRQ stack
        LDR     R2, FlpBase             ; R2-> FDC register base (&3F0 in PC/AT)
        LDRB    R1, [R2, #FlpStatus]    ; Read '765 status
        TSTS    R1, #FlpStatRQM         ; '765 requesting data transfer?
        MOVNE   R0, #FlpEventIRQ        ; Yes then interrupt event
        MOVNE   LR, PC                  ;   save return address
        LDRNE   PC, FlpState            ;   and call FDC event handler (R0,R1->)
        Pull    "R0-R2,PC"              ; Restore caller's regs and return


;-----------------------------------------------------------------------;
; FlpIndexIRQ                                                           ;
;       Index pulse interrupt service routine                           ;
;                                                                       ;
; Input:                                                                ;
;       IRQ mode                                                        ;
;       R3->IOC                                                         ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       R0-R2                                                           ;
;_______________________________________________________________________;
;
FlpIndexIRQ     ROUT
 [ FlpIRQreenable
; Clear edge triggered interrupt

 [ FloppyPodule
        LDR     R1, FlpDACK_TC
        SUB     R1, R1, #&800000
01      MOV     R0, #bit2
        STRB    R0, [R1, #4]
      [ FlpFlushPBI
        LDRB    R0, [R1, #4]            ; for safety - 80321 gets a bit
        TST     R0, #bit2               ; ahead of itself
        BNE     %BT01
      ]
 |
        ASSERT  FlpIndex < 8
01      MOV     R0, #1:SHL:FlpIndex
        STRB    R0, [R3, #IOCIRQCLRA]   ; Clear edge triggered interrupt
      [ FlpFlushPBI
        LDRB    R0, [R3, #IOCIRQREQA]   ; for safety - 80321 gets a bit
        TST     R0, #1:SHL:FlpIndex     ; ahead of itself
        BNE     %BT01
      ]
 ]

; Enable IRQ's, SVC mode

        Push    "LR"                    ; Save IRQ_lr
        WritePSRc SVC_mode,LR,,R0       ; Save CPU mode and IRQ state
        NOP
        Push    "R0,LR"                 ; Save mode and SVC_lr

; Send index pulse event to drive state system

        MOV     R0, #FlpEventIP         ; Index pulse event
        MOV     LR, PC                  ; Save return address
        LDR     PC, FlpDrive            ; Call drive state system

; Restore CPU mode on entry

        Pull    "R0,LR"                 ; Restore SVC_lr
        RestPSR R0,,c                   ; Restore CPU mode/IRQ state
        NOP
        Pull    "PC"
 |
        Push    "R0-R2,LR"              ; Save caller's regs

; Clear edge triggered interrupt

 [ FloppyPodule
        LDR     R1, FlpDACK_TC
        MOV     R0, #bit2
        SUB     R1, R1, #&800000
        STRB    R0, [R1, #4]
 |
        ASSERT  FlpIndex < 8
        MOV     LR, #1:SHL:FlpIndex
        STRB    LR, [R3, #IOCIRQCLRA]   ; Clear edge triggered interrupt
 ]


; Send index pulse event to drive state system

        MOV     R0, #FlpEventIP         ; Index pulse event
        MOV     LR, PC                  ; Save return address
        LDR     PC, FlpDrive            ; Call drive state system

        Pull    "R0-R2,PC"              ; Restore regs and return
 ]


;-----------------------------------------------------------------------;
; FlpTickerV                                                            ;
;       Centisecond clock tick service routine                          ;
;                                                                       ;
; Input:                                                                ;
;       IRQ mode                                                        ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       R0, preserves flags                                             ;
;_______________________________________________________________________;
;
FlpTickerV      ROUT
 [ FlpIRQreenable
; Enable IRQ's, SVC mode

        Push    "LR"                    ; Save IRQ_lr
        WritePSRc SVC_mode,LR,,R0       ; Save CPU mode and IRQ state
        NOP
        Push    "R0,LR"                 ; Save mode and SVC_lr
 |
        Push    "R0,R1,LR"              ; Save caller's regs
 ]
; Process FDC state timer

        LDRB    LR, FlpStateTimer       ; State m/c time goal
        SUBS    LR, LR, #1              ; Decrement it
        STRPLB  LR, FlpStateTimer       ; Write back if >= 0

        MOV     R0, #FlpEventTimer      ; Timer event
        MOVEQ   LR, PC                  ; If timed out set return address
        LDREQ   PC, FlpState            ;   and call state event handler (R0->)

; Process motor timer

        LDRB    LR, FlpMotorTimer       ; Motor on/off timer
        SUBS    LR, LR, #1              ; Decrement it
        STRPLB  LR, FlpMotorTimer       ; Write back if >= 0

        MOV     R0, #FlpEventTimer      ; Timer event
        MOVEQ   LR, PC                  ; If timed out set return address
        LDREQ   PC, FlpDrive            ;   and call drive event handler (R0->)

; Check for escape key pressed

        LDR     LR, ptr_ESC_Status      ; Escape flag global address
        LDRB    LR, [LR]                ; Get escape flag
        TSTS    LR, #EscapeBit          ; Escape pressed?
        MOVNE   R0, #FlpMsgESC          ; Yes then escape message
        MOVNE   R1, #IntEscapeErr       ; and escape error #
        BLNE    FlpMessage              ; and send message to DCB's

 [ FlpIRQreenable
; Restore CPU mode on entry

        Pull    "R0,LR"                 ; Restore SVC_lr
        RestPSR R0,,c                   ; Restore CPU mode/IRQ state
        NOP
        Pull    "PC"
 |
        Pull    "R0,R1,PC"              ; Restore regs and return
 ]

;-----------------------------------------------------------------------;
; FDC state system                                                      ;
;       Sequence '765 FDC commands and time goals.                      ;
;       The following states exist:                                     ;
;       - FlpStateReset - FDC has been reset, awaiting drives ready IRQ ;
;       - FlpStateReady - FDC ready for commands                        ;
;       - FlpStateSeek  - FDC busy issuing step pulses                  ;
;       - FlpStateRecal - FDC busy restoring head to track 0            ;
;       - FlpStateSettle - Head settling time after seek                ;
;       - FlpStateBusy  - FDC busy executing a command                  ;
;                                                                       ;
;       The current state is maintained in 'FlpState' which holds the   ;
;       address of the current event handler.                           ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Event                                                      ;
;       R1 = Parameter                                                  ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       VS = error, VC = event acknowledged                             ;
;                                                                       ;
; Modifies:                                                             ;
;       Flags, R0                                                       ;
;_______________________________________________________________________;
;
; The following events are recognized:
;
FlpEventIRQ     * 1                     ; '765 interrupt, R1= FlpStatus
FlpEventTimer   * 2                     ; Time goal
FlpEventIP      * 3                     ; Index pulse
FlpEventDrvSel  * 4                     ; Drive select, R1 = phys. drive (>3 = none)
FlpEventSeek    * 5                     ; Seek request, R1= track
FlpEventCmd     * 6                     ; Command request, R1->DCB

; FDC reset error
;----------------
;
FlpStateErr     ROUT
        RETURNVS                        ; Return error


; FDC in reset
;-------------
;
FlpStateReset ROUT
        CMPS    R0, #FlpEventTimer      ; Time goal?
        BEQ     %FT20                   ; Yes then jump
        CMPS    R0, #FlpEventIRQ        ; IRQ event?
        RETURNVS NE                     ; No then return error

        TSTS    R1, #FlpStatDIO         ; '765 ready for reading?
        BNE     FlpMessage              ; Yes then jump, send message to DCB's

; Issue "interrupt status" for all 4 drives becoming ready (a '765 feature!?)

        Push    "R1-R2,LR"
        MOV     R2, #0
        STRB    R2, FlpStateTimer       ; Reset timer
        MOV     R2, #4                  ; For 4 drives

10      BL      FlpIRQstatus            ; Request interrupt status
        Pull    "R1-R2,LR",VS           ; Pull regs if error
        BVS     %FT30                   ; Jump if error

        AND     R1, R1, #&C0            ; Get interrupt code
        CMPS    R1, #&C0                ; Ready signal changed?
        SUBEQS  R2, R2, #1              ; Yes then decr loop count
        BNE     %BT10                   ; Loop until done

; '765 ready, reset complete

        BL      FlpFDCready             ; Set FDC ready state
 [ FlpUseFIFO
        ; Configure with the FIFO on
        MOV     r0, #FlpCmdConfigure
        BL      Flp765write
        MOVVC   r0, #&00
        BLVC    Flp765write
        MOVVC   r0, #&0D
        BLVC    Flp765write
        MOVVC   r0, #&00
        BLVC    Flp765write
        BVS     %FT30
 ]
        LDRB    R0, FlpCCRimage
        BL      Flp765specify           ; Set step rate if no error (R0->)
        MOV     R0, #FlpMsgResetOK
        BL      FlpMessage              ; Send message: reset OK
        Pull    "R1-R2,PC"              ; Return

; Process time goal event

20      LDRB    R0, FlpDORimage         ; Get DOR image
        TSTS    R0, #FlpDORreset        ; Reset bit on? (no reset)
        BNE     %FT30                   ; Yes then jump, reset timed out

; Release '765 from reset

        Push    "LR"
        LDR     LR, FlpBase             ; R1-> FDC register base (&3F0 in PC/AT)
        ORR     R0, R0, #FlpDORirqEn:OR:FlpDORreset ; No reset, enable IRQ
        STRB    R0, FlpDORimage         ; Update DOR image
        STRB    R0, [LR, #FlpDOR]       ; Release '765 from reset
        MOV     LR, #FlpResetTimer
        STRB    LR, FlpStateTimer       ; Start timeout
        Pull    "PC"

; Error during FDC reset
30
        Push    "LR"
 [ Debug
        DLINE   "FDC reset problem"
 ]
        BL      Flp765reset             ; Reset '765
        baddr   LR, FlpStateErr         ; FDC error
        STR     LR, FlpState            ; Goto the error state
        Pull    "PC"


; Change FDC state m/c to disabled
;---------------------------------
;
FlpFDCdisable   ROUT
        Push    "R0,R1,LR"
 [ Debug10p
        DLINE   "FDC idle timeout"
 ]
        MOV     R0, #0
        BL      FlpFDCcontrol           ; Attempt to disable FDC H/W
        TST     R1, #Portable_Present   ; Portable power control enabled?
        Pull    "R0,R1,PC",EQ           ; No then exit

        TST     R1, #PortableControl_FDCEnable ; FDC disabled?
        MOVNE   LR, #FlpIdleTimer       ; No then restart idle timeout
        STRNEB  LR, FlpStateTimer
        ADREQ   LR, FlpStateDisabled    ; Else get address of disabled state handler
        STREQ   LR, FlpState            ; And goto disabled state
        Pull    "R0,R1,PC"


; Change FDC state m/c to ready
;------------------------------
;
FlpFDCready     ROUT
        Push    "R0-R2,LR"
        SavePSR R2
        MOV     R0, #1
        BL      FlpFDCcontrol           ; Enable FDC H/W
        TST     R1, #Portable_Present   ; Portable power control enabled?
        MOVNE   LR, #FlpIdleTimer       ; Yes, set FDC H/W idle timeout
        MOVEQ   LR, #0                  ; Else disable timeout
        STRB    LR, FlpStateTimer
        ADDR    LR, FlpStateReady       ; Get address of ready state handler
        STR     LR, FlpState            ; Go to ready state
        RestPSR R2,,f
        Pull    "R0-R2,PC"


; FDC disabled for power saving
;------------------------------
;
FlpStateDisabled ROUT
        Push    "LR"
 [ Debug10p
        DLINE   "Re-enable FDC"
 ]
        BL      FlpFDCready             ; Goto ready state
        Pull    "LR"

; Fall thru' to FlpStateReady

; FDC ready for commands
;-----------------------
;
FlpStateReady   ROUT
        CMPS    R0, #FlpEventIRQ        ; '765 IRQ event?
        BEQ     FlpMessage              ; Yes then jump, send message
        CMPS    R0, #FlpEventCmd        ; Command request?, R1->command block?
        BEQ     %FT10                   ; Yes then jump
        CMPS    R0, #FlpEventTimer      ; Idle timeout?
        BEQ     FlpFDCdisable           ; Yes then jump
        CMPS    R0, #FlpEventSeek       ; Seek request?
        RETURNVS NE                     ; No then return error

; Seek request received, R1->DCB

        Push    "R1-R2,LR"
        LDRB    R0, [R1, #FlpDCBcdb+1]  ; Get drive requested
        AND     R0, R0, #3              ; 0..3
        DrvRecPtr R2, R0                ; R2-> drive record for current drive

        LDR     LR, [R1, #FlpDCBlength]
        TSTS    LR, #bit31              ; Write operation?
        MOVEQ   LR, #FlpSettleDelay     ; Yes, head settling time required
        MOVNE   LR, #0                  ; Else no settling
        STRB    LR, HeadSettle          ; Save settling time
 [ {FALSE}
        DREG    LR, "Settling time "
 ]

        LDRB    R0, [R1, #FlpDCBselect] ; Get clock requested
        LDRB    R1, [R1, #FlpDCBtrack]  ; Get required track
        LDR     LR, [R2, #HeadPosition] ; Get current track for selected drive
        TEQS    LR, R1                  ; On required track?
        MOVEQ   R0, #0                  ; Yes return seek done
 [ Debug10T
        DREG    r1, "Request seek to ",cc,Integer
        DREG    lr, " from ",cc,Integer
        BNE     %FT01
        DLINE   "...no move necessary"
        B       %FT02
01
        DLINE   ""
02
 ]
        BLEQ    FlpFDCready             ; Reset idle timeout
        Pull    "R1-R2,PC",EQ           ; And return

        TSTS    LR, #PositionUnknown    ; Unknown?
        MOV     LR, #0
        STRB    LR, FlpStateTimer       ; Disable FDC idle timeout
        BL      Flp765specify           ; Set drive step rate (R0->)
        BEQ     FlpSeek                 ; Jump if position known

; Restore drive, R1= track required, R2-> drive record

FlpRestore
        STRB    R1, [R2, #HeadPosition] ; Save track required, b31 set
        ADDR    R0, FlpStateRecal       ; Goto recalibrate state
        STR     R0, FlpState
        MOV     R0, #FlpCmdRecal
        BL      Flp765write             ; Issue recalibrate command
        LDRVCB  R0, FlpDrvNum           ; Get drive no.
        BLVC    Flp765write             ; Write drive selected to '765
        BLVS    Flp765reset             ; Reset '765 if error
        MOV     R0, #PositionUnknown    ; Restore in progress
        Pull    "R1-R2,PC"              ; Return, wait for recalibrate if VC

; Seek to requested track, R1=track, R2-> drive record

FlpSeek
        ADDR    R0, FlpStateSeek        ; Next state is seeking
        STR     R0, FlpState
        MOV     R0, #FlpCmdSeek
        BL      Flp765write             ; Give seek command
        LDRVCB  R0, FlpDrvNum           ; Get drive no.
        BLVC    Flp765write
        MOV     R0, R1                  ; Track number
        BLVC    Flp765write
        BLVS    Flp765reset             ; Reset '765 if error
        MOV     R0, #1                  ; Seek in progress
        Pull    "R1-R2,PC"              ; Return, wait for seek if VC


; Issue command to '765, R1->DCB
;*******************************
10
        Push    "R0,R1,LR"
        ADDR    LR, FlpStateBusy        ; Goto the busy state
        STR     LR, FlpState

        LDRB    LR, [R1, #FlpDCBselect] ; Get drive clock rate
        STRB    LR, FlpCCRimage         ; Update CCR image
        LDR     R0, FlpBase             ; R0-> FDC
        STRB    LR, [R0, #FlpCCR]       ; Set '765 FDC clock rate

        LDRB    LR, [R1, #FlpDCBtimeOut] ; Command timeout
        STRB    LR, FlpStateTimer       ; Set timeout
        LDRB    R0, [R1, #FlpDCBcmdLen]! ; Get command length
        ADD     R1, R1, #1              ; R1-> Command block
        BL      Flp765BlkWr             ; Issue command (R0,R1->V)
        Pull    "R0,R1,PC",VC           ; Exit if no error

; Error occurred whilst issuing command to '765
15
 [ Debug
        DLINE   "FDC command error"
 ]
        MOV     LR, #0
        STRB    LR, FlpStateTimer       ; Stop timer
        BL      Flp765reset             ; Reset '765, goto reset state
        Pull    "R0,R1,LR"              ; Restore regs
        RETURNVS                        ; Return with error - VS


; FDC busy seeking
;-----------------
;
FlpStateSeek    ROUT
        CMPS    R0, #FlpEventIRQ        ; '765 IRQ event?
        RETURNVS NE                     ; No then return error

        TSTS    R1, #FlpStatDIO         ; '765 ready for reading?
        BNE     FlpMessage              ; Yes then jump, send message to DCB's

; Issue sense interrupt status to find cause of the IRQ

        Push    "R1-R2,LR"
        LDRB    R0, FlpDrvNum           ; Get current drive
        DrvRecPtr R2, R0                ; R2-> drive record for current drive

        BL      FlpIRQstatus            ; Request interrupt status (->R0,R1,V)
        BVS     %FT10                   ; Jump if error

        STR     R0, [R2, #HeadPosition] ; Save new head position
        TSTS    R1, #bit6               ; Abnormal termination? (R1= ST0)
        BNE     %FT10                   ; Yes then jump
        TSTS    R1, #bit5               ; Seek end?
        BEQ     %FT10                   ; No then jump

; Seek done, start head settling timer

FlpSeekDone
        LDRB    LR, HeadSettle          ; Get settling time
        TEQS    LR, #0                  ; Settling required?
        Pull    "R1-R2,LR",EQ           ; No then restore regs
        BEQ     FlpSettled              ; And jump, heads settled

        ADDR    R1, FlpStateSettle      ; Yes, next state is settling
        STR     R1, FlpState
        STRB    LR, FlpStateTimer       ; And set time goal
        Pull    "R1-R2,PC"

; Seek failed

10      BLVS    Flp765reset             ; Reset '765 if in error
        BLVC    FlpFDCready             ; Else -> ready
 [ Debug10
        DREG    R1, "Seek error: "
 ]
        MOV     R1, #FlpErrSeekFault    ; Seek error
        MOV     R0, #FlpMsgError        ; Error message
        BL      FlpMessage              ; Send message
        Pull    "R1-R2,PC"


; FDC busy recalibrating
;-----------------------
;
FlpStateRecal   ROUT
        CMPS    R0, #FlpEventIRQ        ; '765 IRQ event?
        RETURNVS NE                     ; No then return error

        TSTS    R1, #FlpStatDIO         ; '765 ready for reading?
        BNE     FlpMessage              ; Yes then send message to current DCB

        Push    "R1-R2,LR"
        LDRB    R0, FlpDrvNum           ; Get current drive
        DrvRecPtr R2, R0                ; R2-> drive record for current drive

; Issue sense interrupt status to find cause of IRQ

        BL      FlpIRQstatus            ; Request interrupt status (->R0,R1,V)
        BVS     %FT20                   ; Jump if error

        TSTS    R1, #bit5               ; Seek end?
        BEQ     %FT10                   ; No then jump
        TSTS    R1, #bit4               ; Track 0 fault?
        BNE     %FT10                   ; Yes then jump

; Restore completed, R0 = PCN (should be 0)

        LDRB    R1, [R2, #HeadPosition] ; Get track required
        STR     R0, [R2, #HeadPosition] ; Save current position (track 0)
        TEQS    R0, R1                  ; On required track?
        BEQ     FlpSeekDone             ; Yes then seek done
        B       FlpSeek                 ; Else seek to track requested R0,R1->

; Restore failed, try twice because 82C710 only gives 77 step pulses

10      LDR     R1, [R2, #HeadPosition] ; Get track wanted
        TSTS    R1, #bit30              ; Previous restore failed?
        ORREQ   R1, R1, #bit30          ; Else first failure
        STREQ   R1, [R2, #HeadPosition]
        BEQ     FlpRestore              ;   and try second restore

20      BLVS    Flp765reset             ; Reset '765 if error
        BLVC    FlpFDCready             ; Else -> ready
 [ Debug10
        DLINE   "Restore fault"
 ]
        MOV     R0, #FlpMsgError        ; Error message
        MOV     R1, #FlpErrTrk0Fault    ; Track 0 fault
        BL      FlpMessage              ; Send message
        Pull    "R1-R2,PC"


; FDC ready, awaiting head settling delay
;----------------------------------------
;
FlpStateSettle  ROUT
        CMPS    R0, #FlpEventIRQ        ; '765 IRQ event?
        BEQ     FlpMessage              ; Yes then send message to current DCB
        CMPS    R0, #FlpEventTimer      ; Time goal?
        RETURNVS NE                     ; No then return error

; Disk is ready for read/write, NOTE! some 3.5" drives inhibit index pulses during seeks
; so reset empty time goal after seek done

FlpSettled
        Push    "LR"
        LDRB    LR, FlpDriveIP          ; Get pulse goal
        CMPS    LR, #1                  ; > 1, i.e. ready?
        MOVHI   LR, #FlpEmptyTimer      ; IP timeout
        STRHIB  LR, FlpMotorTimer       ; Yes reset drive empty time goal

        BL      FlpFDCready             ; Next state is ready
        MOV     R0, #FlpMsgSeekDone     ; Seek complete
        BL      FlpMessage              ; Send message
        Pull    "PC"


; FDC busy, command executing
;----------------------------
;
FlpStateBusy    ROUT
        CMPS    R0, #FlpEventTimer      ; Time goal?
        BEQ     %FT10                   ; Yes then jump
        CMPS    R0, #FlpEventIRQ        ; '765 IRQ event?
        RETURNVS NE                     ; No then return error

; FDC interrupt caused by command completion

        Push    "LR"
        LDRB    LR, FlpDriveIP          ; Get pulse goal
        CMPS    LR, #1                  ; > 1, i.e. ready?
        MOVHI   LR, #FlpEmptyTimer      ; IP timeout
        STRHIB  LR, FlpMotorTimer       ; Yes reset drive empty time goal
        BL      FlpFDCready             ; Goto ready state
        BL      FlpMessage              ; Send IRQ message to pending DCB (R0->)
        Pull    "PC"

; Command timed out
10
        Push    "R1,LR"
 [ Debug10
        DLINE   "DCB time out"
 ]
        BL      Flp765reset             ; Reset '765 to abort command
        MOV     R0, #FlpMsgError        ; Error message
        MOV     R1, #FlpErrTimeOut      ; Command timed out
        BL      FlpMessage              ; Tell DCB's (R0-R1->)
        Pull    "R1,PC"


;-----------------------------------------------------------------------;
; FlpDrvSelect                                                          ;
;       Select a drive and start the motor                              ;
;                                                                       ;
; Input:                                                                ;
;       R1 = Drive, 0..3, (&ff = none)                                  ;
;       R12 -> static base                                              ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpDrv2DOR    ; Dv0, Dv1, Dv2, Dv3, Off ; Drive number to DOR lookup table
;       DCB     &33, &10, &11, &33, &03 ; Perth: ME0=MotorOn, me1=sel0, drv0=SEL1, drv1=SEL2
;       DCB     &10, &21, &42, &83, &00 ; 'AT' type motor enables, reset negated
;          DS0+ME0 DS1+ME1 ME1 ME0+ME1
 [ FloppyPCI
        DCB     &F0, &F1, &F2, &F3, &00 ; Iyonix - software-OR the motors
 |
        DCB     &10, &21, &23, &33, &00 ; ME0= motor on, drive 2,3 decoded externally
 ]
        ALIGN

FlpDrvSelect    ROUT
        Push    "R0,LR"
        baddr   R0, FlpDrv2DOR          ; Get address of lookup table
        LDRB    LR, FlpDORimage         ; Get DOR image
        BIC     LR, LR, #&F3            ; Clear all drive/motor selects
        CMPS    R1, #4                  ; Drive# out of range
        LDRHSB  R0, [R0, #4]            ; Yes then all motors off
        LDRLOB  R0, [R0, R1]            ; Else get DOR bits for requested drive
        STRLOB  R1, FlpDrvNum           ; And save new selected drive
        ORR     LR, LR, R0              ; Get new DOR image
        LDR     R0, FlpBase             ; R0-> FDC register base (&3F0 in PC/AT)
        STRB    LR, FlpDORimage         ; Update DOR image
        STRB    LR, [R0, #FlpDOR]       ; Motors on
        Pull    "R0,PC"


;-----------------------------------------------------------------------;
; Drive state system                                                    ;
;       Sequence drive motor start/stop/select                          ;
;       The following states exist:                                     ;
;       - FlpDriveOff - Drive motor off                                 ;
;       - FlpDriveSpinup - Drive selected and accelerating              ;
;       - FlpDriveEmpty - Drive selected, no disk in (no index pulses)  ;
;       - FlpDriveReady - Drive selected and motor up to speed          ;
;                                                                       ;
;       The following events are recognized:                            ;
;       - FlpEventDrvSel - Drive select, R1= drive                      ;
;       - FlpEventIP - Index pulse detected                             ;
;       - FlpEventTimer - Motor time goal reached                       ;
;                                                                       ;
;       The current state is maintained in 'FlpDrive' which holds the   ;
;       address of the current event handler.                           ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Event                                                      ;
;       R1 = Drive number                                               ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       R0 = Drive status if drive select, else garbage                 ;
;       VC = no error, VS = error                                       ;
;                                                                       ;
; Modifies:                                                             ;
;       None, corrupts flags                                            ;
;_______________________________________________________________________;
;
; Drive motors off
;-----------------
;
FlpDriveOff     ROUT
        CMPS    R0, #FlpEventDrvSel     ; Drive select?
        RETURNVS NE                     ; No then return error

; Start drive motors, R1= physical drive number

 [ fix_12
        Push    "R0,R1,LR"
        MOV     R0, #1
        BL      FlpFDCcontrol           ; Enable FDC H/W
        Pull    "R0,R1,LR"
 ]

        B       FlpDriveChange          ; Select new drive (R1->R0)


; Drive motors starting
;----------------------
;
FlpDriveSpinup  ROUT
        CMPS    R0, #FlpEventIP         ; Index pulse?
        BEQ     %FT10
        CMPS    R0, #FlpEventDrvSel     ; Drive select?
        BEQ     FlpDriveChange          ; Yes select new drive (R1->R0)
        CMPS    R0, #FlpEventTimer      ; Motor time goal?
        RETURNVS NE                     ; No then return error

; Time goal

        LDRB    R0, FlpDriveIP          ; Get IP goal
        CMPS    R0, #1                  ; Awaiting first index pulse
        BEQ     FlpEmpty                ; Yes then jump, drive empty

; Motor startup time elapsed

        MOV     R0, #1                  ; 1 index pulse required
        STRB    R0, FlpDriveIP          ; Set pulse goal
        MOV     R0, #FlpEmptyTimer      ; Drive empty time goal
        STRB    R0, FlpMotorTimer       ; Set time goal
        MOV     PC, LR

; Timed out waiting for index pulses

FlpEmpty
        Push    "R0,R1,LR"
        MOV     R0, #FlpMotorOffDelay   ; Drive deselect time out
        STRB    R0, FlpMotorTimer       ; Set time goal
        ADDR    R0, FlpDriveEmpty       ; Drive selected, drive empty state
        STR     R0, FlpDrive            ; Save it

        LDRB    R1, FlpDrvNum           ; Get current drive
        DrvRecPtr R0, R1
        LDR     R1, [R0, #DrvFlags]     ; Get drive flags
        BIC     R1, R1, #MiscOp_PollChanged_Ready_Flag+MiscOp_PollChanged_MaybeChanged_Flag+MiscOp_PollChanged_Changed_Flag+MiscOp_PollChanged_NotChanged_Flag
        ORR     R1, R1, #MiscOp_PollChanged_Empty_Flag      ; Set Empty bit
        STR     R1, [R0, #DrvFlags]     ; Update flags

        MOV     R1, #DriveEmptyErr

        ;Check for stork w/out floppy here
        SWI     XPortable_Status        ; Ask the portable module if there is a FDD attached
        BVS     %FT09
        TST     R0, #PortableStatus_PrinterFloppy
        BNE     %FT09
        ADRL    R0, NoFloppyErrBlk      ; R1 points to the error block
        BL      copy_error
 [ NewErrors
        MOV     R1, R0
 |
        ORR     R1, R0, #ExternalErrorBit
 ]

09      MOV     R0, #FlpMsgError        ; Error message
        BL      FlpMessage              ; Send message to current DCB
        Pull    "R0,R1,PC"

; Index pulse received

10      LDRB    R0, FlpDriveIP          ; Get IP goal
        SUBS    R0, R0, #1
        STRPLB  R0, FlpDriveIP          ; Write back if >= 0
        MOVNE   PC, LR                  ; Exit if <> 0

; Drive now ready

        Push    "R1,R2,LR"
        MOV     R0, #FlpEmptyTimer      ; IP timeout
        STRB    R0, FlpMotorTimer       ; Reset time goal
        MOV     R0, #FlpIPidleOff       ; Drive idle IP count
        STRB    R0, FlpDriveIP          ; Set pulse goal

        ADDR    R0, FlpDriveReady       ; Go to ready state
        STR     R0, FlpDrive

        LDRB    R0, FlpDrvNum           ; Get current drive
        DrvRecPtr R1, R0
        LDR     R2, [R1, #DrvFlags]     ; Get drive flags
        ORR     R2, R2, #MiscOp_PollChanged_Ready_Flag      ; Set ready bit

        TSTS    R2, #MiscOp_PollChanged_ChangedWorks_Flag   ; Changed works?
        TSTNES  R2, #MiscOp_PollChanged_NotChanged_Flag     ; And not changed?
        BLNE    FlpGetDskChng           ; Yes read disk changed status (->R0)
        TSTNES  R0, #FlpDIRchanged      ; And disk changed?
        BICNE   R2, R2, #MiscOp_PollChanged_NotChanged_Flag ; Yes, reset not changed
        ORRNE   R2, R2, #MiscOp_PollChanged_Changed_Flag    ; And show changed
        MOVNE   LR, #PositionUnknown    ; And set position unknown
        STRNE   LR, [R1, #HeadPosition] ; And force restore

        STR     R2, [R1, #DrvFlags]     ; Update flags
        MOV     R1, R2                  ; Parameter is drive status
        MOV     R0, #FlpMsgIP           ; Drive IP message
        BL      FlpMessage              ; Send message to current DCB
        Pull    "R1,R2,PC"


; Current drive is empty
;-----------------------
;
FlpDriveEmpty   ROUT
        CMPS    R0, #FlpEventTimer      ; Time goal?
        BEQ     %FT20                   ; Yes then jump, drive off
        CMPS    R0, #FlpEventIP         ; Index pulse?
        BEQ     %FT10                   ; Yes then jump
        CMPS    R0, #FlpEventDrvSel     ; Drive select?
        RETURNVS NE                     ; No then return error

; Drive select, R1= drive

        Push    "LR"
        DrvRecPtr LR, R1
        LDRB    R0, FlpDrvNum           ; Get current drive
        TEQS    R0, R1                  ; Changed?
        LDREQ   R0, [LR, #DrvFlags]     ; No then get drive flags
        MOVEQ   LR, #FlpMotorOffDelay   ; And get drive deselect time out
        STREQB  LR, FlpMotorTimer       ; And restart time goal
        Pull    "PC",EQ                 ; And exit

        BL      FlpDriveChange          ; Select new drive (R1->R0)
        Pull    "PC"                    ; Return

; Drive empty, index pulse received
10
        Push    "R1,LR"
        LDRB    R1, FlpDrvNum           ; Get current drive no.
        BL      FlpDriveChange          ; Restart drive (R1->R0)
        Pull    "R1,PC"

; Drive off timeout reached
20
        Push    "R1,LR"
        MOV     R1, #-1                 ; Drive deselect
        BL      FlpDriveChange          ; New drive (R1->R0)
        Pull    "R1,PC"


; Drive ready, disk in
;---------------------
;
FlpDriveReady   ROUT
        CMPS    R0, #FlpEventDrvSel     ; Drive select?
        BEQ     %FT10                   ; Yes then select another drive
        CMPS    R0, #FlpEventTimer      ; Motor time goal, No IP's?
        BEQ     %FT20                   ; Yes then jump
        CMPS    R0, #FlpEventIP         ; Index pulse?
        MOVNE   PC, LR                  ; No then return

; Index pulse received

        Push    "R1,LR"
        MOV     R0, #FlpEmptyTimer      ; IP timeout
        STRB    R0, FlpMotorTimer       ; Reset time goal

        LDRB    R0, FlpDrvNum           ; Get current drive
        DrvRecPtr R1, R0
        LDR     R0, [R1, #DrvFlags]     ; Get drive flags
        TSTS    R0, #MiscOp_PollChanged_ChangedWorks_Flag   ; Changed works?
        TSTNES  R0, #MiscOp_PollChanged_NotChanged_Flag     ; And not changed?
        BLNE    FlpGetDskChng           ; Yes read disk changed status (->R0)
        TSTNES  R0, #FlpDIRchanged      ; And disk changed?
        BEQ     %FT05                   ; No then jump

        BIC     R0, R0, #MiscOp_PollChanged_NotChanged_Flag
        ORR     R0, R0, #MiscOp_PollChanged_Empty_Flag      ; Show drive empty, but ready!?
        STR     R0, [R1, #DrvFlags]     ; Update flags
        MOV     R1, #DriveEmptyErr

        ;Check for stork w/out floppy here
        SWI     XPortable_Status        ; Ask the portable module if there is a FDD attached
        BVS     %FT04
        TST     R0, #PortableStatus_PrinterFloppy
        BNE     %FT04
        ADRL    R0, NoFloppyErrBlk      ; R1 points to the error block
        BL      copy_error
 [ NewErrors
        MOV     R1, R0
 |
        ORR     R1, R0, #ExternalErrorBit
 ]

04      MOV     R0, #FlpMsgError        ; Error message
        BL      FlpMessage              ; Send message to current DCB

05      LDRB    R0, FlpDriveLock        ; Get drive lock bits
        TEQS    R0, #0                  ; Locked?
        BNE     %FT07                   ; Yes then jump

        LDRB    R0, FlpDriveIP          ; Get IP goal
        SUBS    R0, R0, #1              ; Decrement
        STRPLB  R0, FlpDriveIP          ; Write back if >= 0
        MOVEQ   R1, #-1                 ; Drives off
        BLEQ    FlpDriveChange          ; Turn drive off if 0
07      MOV     R0, #FlpMsgIP           ; Index pulse message
        BLNE    FlpMessage              ; Else send it (R0,R1->)
        Pull    "R1,PC"                 ; Return


; Drive select when ready
10
        Push    "LR"
        DrvRecPtr LR, R1
        LDRB    R0, FlpDrvNum           ; Get current drive
        TEQS    R0, R1                  ; Changed?
        LDREQ   R0, [LR, #DrvFlags]     ; No then get drive flags
        MOVEQ   LR, #FlpIPidleOff       ; And get drive idle IP count
        STREQB  LR, FlpDriveIP          ; And reset drive off pulse goal
        Pull    "PC",EQ                 ; And exit

        BL      FlpDriveChange          ; Select new drive (R1->R0)
        Pull    "PC"                    ; Return

; Index pulse not received in time

20      LDRB    R0, FlpDriveLock
        TSTS    R0, #bit2               ; Empty timer inhibited?
        BEQ     FlpEmpty                ; No, goto drive empty

        MOV     R0, #FlpEmptyTimer      ; IP timeout
        STRB    R0, FlpMotorTimer       ; Reset time goal
        MOV     PC, LR                  ; Return, ignore timeout


;-----------------------------------------------------------------------;
; FlpDriveChange                                                        ;
;       Change selected drive and goto correct state                    ;
;                                                                       ;
; Input:                                                                ;
;       R1 = New drive, 0..3                                            ;
;       R12 -> static base                                              ;
;                                                                       ;
; Output:                                                               ;
;       R0 = drive flags                                                ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpDriveChange  ROUT
        Push    "R2,R3,LR"
        SavePSR R3
        LDRB    LR, FlpDrvNum           ; Get last drive selected
        DrvRecPtr R2, LR                ; Get last drive record
        LDR     R0, [R2, #DrvFlags]     ; Get drive flags
        TSTS    R0, #MiscOp_PollChanged_Empty_Flag          ; Currently empty?
        BEQ     %FT05                   ; No then jump

        BIC     R0, R0, #MiscOp_PollChanged_Empty_Flag      ; Reset empty
        TSTS    R0, #MiscOp_PollChanged_ChangedWorks_Flag   ; Changed works?
        ORRNE   R0, R0, #MiscOp_PollChanged_Changed_Flag    ; Yes then disk changed
        ORREQ   R0, R0, #MiscOp_PollChanged_MaybeChanged_Flag ; Else maybe changed

05      BIC     LR, R0, #MiscOp_PollChanged_Ready_Flag      ; Reset drive ready
        STR     LR, [R2, #DrvFlags]     ; Update current drive flags

        CMPS    R1, #3                  ; Drive deselect?
        MOVHI   R0, LR                  ; Yes get current flags
        ADDR    LR, FlpDriveOff         ; And goto motor off state
        STRHI   LR, FlpDrive
        BHI     %FT20                   ; And jump

        DrvRecPtr R2, R1                ; Get new drive record
        TSTS    R0, #MiscOp_PollChanged_Ready_Flag          ; Current drive ready?
        LDR     R0, [R2, #DrvFlags]
        ORRNE   R0, R0, #MiscOp_PollChanged_Ready_Flag      ; Yes, new drive is ready
        MOV     LR, #FlpEmptyTimer      ; IP timeout
        STRNEB  LR, FlpMotorTimer       ; And reset empty timeout
        BNE     %FT10                   ; And jump, no state change

; Current drive is not ready so startup drive motor

        TSTS    R0, #MiscOp_PollChanged_ChangedWorks_Flag   ; Changed works?
        BICEQ   R0, R0, #MiscOp_PollChanged_NotChanged_Flag ; No then reset not changed
        ORREQ   R0, R0, #MiscOp_PollChanged_MaybeChanged_Flag ; And set maybe changed
        STREQ   R0, [R2, #DrvFlags]     ; And save drive flags

        CMPS    R1, #1                  ; Drives 0/1?
        MOVLS   LR, #FlpMotorOnDelayIn  ; Startup timer 3.5" (internal)
        MOVHI   LR, #FlpMotorOnDelayEx  ; Startup timer 5.25" (external)
        STRB    LR, FlpMotorTimer       ; Set time goal

        MOV     LR, #0
        STRB    LR, FlpDriveIP          ; Reset pulse goal
        ADDR    LR, FlpDriveSpinup      ; Go to spin up state
        STR     LR, FlpDrive

; Check if restore required on new drive

10      TSTS    R0, #MiscOp_PollChanged_Changed_Flag+MiscOp_PollChanged_MaybeChanged_Flag ; Disk changed?

 [ {FALSE}    ; Include to force restore on drive change
        LDREQ   LR, FlpDrvNum           ; Get last drive
        TEQEQS  LR, R1                  ; Or drive select changed?
 ]
        MOVNE   LR, #PositionUnknown    ; Yes set position unknown
        STRNE   LR, [R2, #HeadPosition] ; Yes force restore

20      BL      FlpDrvSelect            ; Physical select (R1->)
 [ 1 = 0
;>>>as an experiment, switch this code off
 [ fix_12
        CMPS    R1, #3                  ; Drive deselect?
        Pull    "R2,PC",LS,^            ; No, Return

        Push    "R0,R1"
        MOV     R0, #0
        BL      FlpFDCcontrol           ; Yes, disable FDC H/W
        Pull    "R0,R1"
 ]
 ]
        RestPSR R3,,f
        Pull    "R2,R3,PC"              ; Return


        LTORG

        END
