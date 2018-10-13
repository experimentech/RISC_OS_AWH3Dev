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
;>Adfs19
        SUBT    1772/765 Floppy Disk Driver Common Entry Points
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
;     25 Oct 90         Version 2.06 of ADFS                            ;
; 01  28 Nov 90  lrust  Added 82C710 floppy/IDE drivers                 ;
; 02  08 Mar 91  lrust  Alpha version                                   ;
; 03  15 Mar 91  lrust  RiscOS 2.09 release                             ;
; 04  28 May 91  lrust  Add seek track 3 after restore during init to   ;
;                       allow for drives shipped with head on -ve track ;
; 05  17 Sep 91  lrust  40 track drives don't double step when 40 track ;
;                       media bit in LowSector is set                   ;
; 06  16 Dec 91  lrust  Added portable power stuff                      ;
; 07  14 Jan 92  lrust  40 track detection algorithm fixed to cater for ;
;                       40T drives positioning to track 42              ;
; 08  05 Feb 92  lrust  DCB post processing re-enables IRQ's.           ;
;                       FlpErrNoIDs is not mapped by FlpADFSerror since ;
;                       the FDC status returned is invalid.             ;
;_______________________________________________________________________;
;
Adfs19Ed        * 08                    ; Edition number

        GBLL    Flp40Track
Flp40Track      SETL    {TRUE}          ; Enable 40 track drive detection

        GBLL    FlpPostIrqOn
FlpPostIrqOn    SETL    {TRUE}          ; Enable IRQ's in Post routines


;-----------------------------------------------------------------------;
; This file provides the following common entry points for the 82C710   ;
; and the older 1772 based floppy disk driver:                          ;
;                                                                       ;
; 1) FlpInit                                                            ;
;       Initialize the driver, hardware and claim any vectors.  Invoked ;
;       when the module receives the initialization call.               ;
;                                                                       ;
; 2) FlpDie                                                             ;
;       Finalise the driver, calm the hardware and release any system   ;
;       resources. Invoked when the module receives a finalisation call ;
;                                                                       ;
; 3) FlpReset                                                           ;
;       Claim vectors.  Invoked when the module receives a post soft    ;
;       reset service call.                                             ;
;                                                                       ;
; 4) FlpLowLevel                                                        ;
;       Perform disk operations.  Invoked when the module receives a    ;
;       FileCore DiskOp call with a drive number in the range 0 to 3.   ;
;                                                                       ;
; 5) FlpMount                                                           ;
;       Invoked when the module receives a FileCore miscellaneous call  ;
;       with a reason code of 0 (R0 = 0, mount disk).                   ;
;                                                                       ;
; 6) DoPollChanged                                                      ;
;       Check for disk changed status                                   ;
;                                                                       ;
; 7) DoLockDrive                                                        ;
;       Turn drive motor on permanently                                 ;
;                                                                       ;
; 8) DoUnlockDrive                                                      ;
;       Allow drive motor to turn off                                   ;
;                                                                       ;
; In addition the following support routines are included:              ;
;                                                                       ;
; a) FlpBuildDCB                                                        ;
;       Builds a "Disk Control Block" (DCB) from information passed to  ;
;       FlpLowLevel.                                                    ;
;                                                                       ;
; b) FlpADFSerror                                                       ;
;       Maps a '765 FDC error to an ADFS error code and disk address    ;
;                                                                       ;
; c) FlpComplete                                                        ;
;       Informs FileCore of a completed background operation and        ;
;       releases FIQ's.                                                 ;
;                                                                       ;
; d) FlpLowNdataPost                                                    ;
;       DCB post routine for non-data transfer disc-ops.                ;
;                                                                       ;
; e) FlpLowDataPost                                                     ;
;       DCB post routine for data transfer type disc-ops.               ;
;_______________________________________________________________________;


;-----------------------------------------------------------------------;
; FlpInit                                                               ;
;       Check type of FDC (original 1772 or later '765 in 82C710).      ;
;       Initialize the FDC hardware.                                    ;
;       Claim interrupt vectors.                                        ;
;                                                                       ;
; Input:                                                                ;
;       R3  = No. of floppies from CMOS                                 ;
;       R11 = -> Instantiation number, 0= first init                    ;
;       SB  = -> Local storage                                          ;
;       LR  = Return address                                            ;
;                                                                       ;
; Output:                                                               ;
;       R0 = 0, VC, No error                                            ;
;          = Error code, VS                                             ;
;       R1 = No. of responding drives                                   ;
;                                                                       ;
; Modifies:                                                             ;
;       R2                                                              ;
;_______________________________________________________________________;
;
FlpInit ROUT
        Push    "R5,LR"                 ; Save caller's regs
 [ Debug10
        DREG    R3,"FlpInit, Drives(R3): "
 ]

; Read drive step rates

        BL      ReadStep                ; (->R0,R5,V)
        STRB    R5, StepRates           ; Save for future use

02      LDR     R0, MachineID
 [ Support1772
        CMPS    R0, #MachHas1772        ; 1772 FDC?
        BEQ     FlpInit1772             ; Yes then jump
 ]
        CMPS    R0, #MachHas82710       ; 82C710 FDC?
        MOVNE   R1, #0                  ; No, then 0 floppies
        STRNEB  R1, Floppies
        BNE     %FT45

; Initialize '765 driver data structures

        MOV     LR, #0
        STR     LR, FlpDCBqueue         ; No DCB's queued
        STR     LR, FlpStateTimer       ; Disable all timers
        STR     LR, FlpMEMCstate        ; No MEMC state saved
        STRB    LR, Floppies            ; Assume no drives

        MOV     LR, #FlpDORirqEn+FlpDORreset
        STR     LR, FlpDORimage         ; Initialise all control reg images

 [ FloppyPCI
        Push    "R4"
        MOV     R0, #1:SHL:30
        MOV     R1, #&3F0
        MOV     R2, #8
        SWI     XPCI_LogicalAddress
        MOVVS   R0, #MachHasNoFDC
        STRVS   R0, MachineID
        BVS     %BT02
        MOV     R0, R4
        STR     R4, FlpBase
        Pull    "R4"
        MOV     LR, #-1
        STR     LR, FlpDMAHandle
        BL      Configure37C665
 |
 [ FloppyPodule
        Push    "R3"
        MOV     R0, #Podule_ReadInfo_EASILogical
        ADR     R1, FlpBase
        MOV     R2, #4
        MOV     R3, #0
        SWI     XPodule_ReadInfo
        Pull    "R3"
        MOVVS   R0, #MachHasNoFDC
        STRVS   R0, MachineID
        BVS     %BT02
        LDR     LR, FlpBase
        LDRB    R0, [LR]
        TEQ     R0, #&78
        MOVNE   R0, #MachHasNoFDC
        STRNE   R0, MachineID
        BNE     %BT02
        ADD     R0, LR, #&C00000
        STR     R0, FlpDACK_TC
        ADD     R0, LR, #&E00000
        ADD     LR, R0, #&3F0 * 4
        STR     LR, FlpBase
        BL      Configure37C665
 |
 [ HAL
        MOV     r0, #9
        MOV     r1, #34<<8
        SWI     XOS_Memory
        MOVVS   r1, #0
        CMP     r1, #0
        MOVEQ   r0, #MachHasNoFDC
        STREQ   r0, MachineID
        BEQ     %BT02
        ADD     r0, r1, #&3F0 * 4
        STR     r0, FlpBase
        ADD     r0, r1, #FlpDACK_Offset + FlpDACK_TC_Offset
        STR     r0, FlpDACK_TC
 |
        LDR     LR, =CnTbase + (&3F0 * 4)
        STR     LR, FlpBase
        LDR     LR, =CnTbase + FlpDACK_Offset + FlpDACK_TC_Offset
        STR     LR, FlpDACK_TC
 ]
 ]
 ]

        MOV     R0, #3                  ; Max drive number
        DrvRecPtr R1, R0                ; R1-> drive record
        MOV     LR, #MiscOp_PollChanged_EmptyWorks_Flag + MiscOp_PollChanged_MaybeChanged_Flag
        ORR     LR, LR, #MiscOp_PollChanged_ReadyWorks_Flag
05      STR     LR, [R1, #DrvFlags]     ; Update drive record
        SUB     R1, R1, #SzDrvRec       ; Next drive record
        SUBS    R0, R0, #1              ; Decr loop counter
        BPL     %BT05                   ; For all drives

        BL      FlpReset                ; Reset/init H/W and claim vectors

; Wait for FDC state system to become ready (FDC initialized)

        baddr   R0, FlpStateReset       ; R0->reset state handler
10      LDR     LR, FlpState            ; Get state
        TEQS    LR, R0                  ; '765 finished reset?
        BEQ     %BT10                   ; No then loop

        baddr   R0, FlpStateErr         ; Error state
        TEQS    LR, R0                  ; FDC error?
        BEQ     %FT99                   ; Yes then jump

; Check no. of floppies fitted and map physical to logical drive numbers

        MOV     R2, #0                  ; Start with physical drive 0
        sbaddr  R5, FlpDrvMap           ; R5-> drive map word
        MOV     LR, #&FFFFFFFF
        STR     LR, [R5]                ; Assume no logical drives

; Construct a "restore" DCB on the stack

        SUB     SP, SP, #FlpDCBsize     ; Allocate DCB on the stack
        MOV     R1, SP                  ; R1->DCB
        MOV     R0, #0
        STR     R0, [R1, #FlpDCBpost]   ; No post routine
        STRB    R0, [R1, #FlpDCBtimeOut] ; No DCB timeout == no spin-up
        MOV     R0, #FlpCCR1000K        ; Set for max clock
        STRB    R0, [R1, #FlpDCBselect] ; Set data rate

; Check if configured drive number found

15      LDRB    LR, Floppies            ; Number of floppy drives
        CMPS    R3, LR                  ; CMOS value less than that found?
        BLS     %FT40                   ; Yes then jump, don't test for any more

; Prepare a restore command

        MOV     R0, #1                  ; 1 retry
        STRB    R0, [R1, #FlpDCBretries]
        STRB    R0, [R1, #FlpDCBesc]    ; Disable escapes
        STRB    R2, [R1, #FlpDCBcdb+1]  ; Write drive/head data
        MOV     R0, #FlpCmdRecal        ; Recalibrate command code
        STRB    R0, [R1, #FlpDCBcdb]    ; Write command
        BL      FlpDoDCB                ; Process DCB (R1->R0,V)
        TEQS    R0, #0                  ; Good command
        BEQ     %FT17                   ; Yes, then continue as-is

        ;Hmm, is it a portable w/out floppy connected?
        ;If so, then it might be best to fake it...
        SWI     XPortable_Status
        BVS     %FT30                   ;Erky! Not a portable
        TST     R0, #PortableStatus_PrinterFloppy
        BNE     %FT30                   ;Eek! Drive already connected, so is error

        CMP     r2, #1                  ;UUURGH! Nasty fix 'cos FD0 is physical drive 1!!!!
        BEQ     %FT17                   ;Pretend this drive exists then

        B       %FT30                   ; It really _is_ a 'bad command', so jump

; Track 0 seen - drive is responding

17      STRB    R2, [R5], #1            ; Update drive map
        LDRB    R0, Floppies
        ADD     R0, R0, #1              ; 1 more floppy
        STRB    R0, Floppies
 [ Debug10
        DREG    R2, "Found drive: "
 ]

; Determine if drive is 40 track - First seek track 44

        MOV     R0, #FlpCmdSeek         ; Seek command code
        STRB    R0, [R1, #FlpDCBcdb]    ; Write command
 [ Flp40Track
        MOV     R0, #44
        STRB    R0, [R1, #FlpDCBcdb+2]  ; Write track no.
        BL      FlpDoDCB                ; Process DCB (R1->R0,V)
 ]
; Seek track 2 (step in 42 times - 3 more than necessary. Some 40Tdrives have 43 tracks!)

        MOV     R0, #2
        STRB    R0, [R1, #FlpDCBcdb+2]  ; Write track no.
        BL      FlpDoDCB                ; Process DCB (R1->R0,V)

; Check track 0 indication - Will be true for 40 track drives

 [ Flp40Track
        MOV     R0, #2                  ; 2 byte command
        STRB    R0, [R1, #FlpDCBcmdLen] ; Write command length
        MOV     R0, #FlpCmdSenseDrv     ; Sense drive status command code
        STRB    R0, [R1, #FlpDCBcdb]    ; Write command (no implied seek)
        BL      FlpDoDCB                ; Process DCB (R1->R0,V)
        DrvRecPtr R0, R2                ; Get-> drive record
        LDRB    LR, [R1, #FlpDCBresults] ; Get ST3
  [ {TRUE}
        TSTS    LR, #0                  ; Disable 40 track detection
  |
        TSTS    LR, #bit4               ; Track 0?
  ]
        LDRNE   LR, [R0, #DrvFlags]     ; Yes, get drive flags
        ORRNE   LR, LR, #MiscOp_PollChanged_40Track_Flag    ; And set 40 track bit
        STRNE   LR, [R0, #DrvFlags]     ; And save it
  [ Debug
        BEQ     %FT20
        DREG    R2, "40 track drive: "
20
  ]
 |
        DrvRecPtr R0, R2                ; Get-> drive record
 ]
        MOV     LR, #PositionUnknown
        STR     LR, [R0, #HeadPosition] ; Force restore on next op

; Try next drive

30      ADDS    R2, R2, #1              ; Next physical drive
        CMPS    R2, #4                  ; All done
        BLO     %BT15                   ; No then repeat

; All configured drives found

40      ADD     SP, SP, #FlpDCBsize     ; Deallocate DCB
        LDRB    R1, Floppies            ; Number of floppy drives detected

45      SUBS    R0, R0, R0              ; No error (R0 = 0, V clear)
        Pull    "R5,PC"                 ; Restore caller's regs and return


; '765 FDC hardware error - no interrupts from drive ready after reset

99      BL      FlpDie                  ; Uninstall
 [ Debug10
        DLINE   "FlpInit error, driver not installed"
 ]
        SUBS    R1, R1, R1              ; No floppies
        Pull    "R5,PC"

 [ FloppyPodule:LOR:FloppyPCI

ConfigSMCTable
 [ FloppyPCI
        DCB     &07, 0                  ; Access device 0 (FDC)
        DCB     &30, 1                  ; Enable device (default IO 03F0, DMA2)
        DCB     &70, 7                  ; IRQ7
        DCB     &BB                     ; Exit config mode
 |
        DCB     &01, 2_10000111         ; Enable config read, IRQ active low, parallel powered/extended, default addr.
        DCB     &02, 2_00011100         ; 2nd serial port disabled, 1st enabled at &3F8
        DCB     &03, &78                ; extra stuff for SMC
        DCB     &04, 2_00000011         ; allow extended parallel port modes
        DCB     &05, 0
        DCB     &06, &FF
        DCB     &07, 0
        DCB     &08, 0
        DCB     &09, 0
        DCB     &0A, 0
        DCB     &00, 2_10111011         ; Valid config, OSC/BR on, FDC enabled/powered, IDE AT,enabled
        DCB     &AA                     ; Exit config mode
 ]

        ALIGN

Configure37C665 Entry "r0-r2"
        SETPSR  I_bit + F_bit, lr,, r2  ; Disable FIQ and IRQ

; First try to configure the SMC665

 [ FloppyPCI
        MOV     lr, #&51
        STRB    lr, [r0, #0]            ; Write &51, &23 to &3F0
        MOV     lr, #&23
        STRB    lr, [r0, #0]
 |
        MOV     lr, #&55
        ADD     r0, r0, #&3F0*4
        STRB    lr, [r0, #0]            ; Write &55 to CRI711 twice
        STRB    lr, [r0, #0]            ; to enter configuration mode
 ]

        ADR     r1, ConfigSMCTable      ; R1-> SMC 665 configuration data
20
        LDRB    lr, [r1], #1            ; get config index
        STRB    lr, [r0, #0]
 [ FloppyPCI
        TEQ     lr, #&BB                ; end of table?
 |
        TEQ     lr, #&AA                ; end of table?
 ]
        LDRNEB  lr, [r1], #1            ; if not then get config data
        STRNEB  lr, [r0, #FlpReg_Spacing]; and write it
        BNE     %BT20

        RestPSR r2                      ; Restore IRQ/FIQ state

        EXIT
 ]

; Process a DCB (R1->R0,V)

FlpDoDCB        ROUT
        Push    "LR"
      [ {TRUE}
        MOV     R0, #256                ; For RPCEmu 0.8.9, the floppy controller is polled in a ratio
        BL      DoMicroDelay            ; to CPU instruction decode. Going too fast prevents rom init.
                                        ; Burn 128us of CPU cycles during each of the power on DCBs.
      ]
        BL      FlpAddDCB               ; Add DCB to queue (R1->R0,V)
10      LDR     R0, [R1, #FlpDCBstatus] ; Get command error
        CMPS    R0, #FlpDCBpending      ; DCB still pending?
        BEQ     %BT10                   ; Yes then loop
        Pull    "PC"


 [ Support1772

; Initialize 1772 FDC, as per V2.06

FlpInit1772     ROUT
 [ Debug10
        DLINE   "177X FDC found"
 ]
        STRB    R3, Floppies            ; Save no. of drives

        MOV     R0, #NotResetDiscChangedBit :OR: MotorBits :OR: SideBit :OR: DriveBits
        MOV     R1, #&FF
        BL      WrDiscLatch             ; Deselect all drives

        MOV     R0, #0
        MOV     R1, #FdcResetBit
        BL      WrSharedLatch           ; Reset the 1772

        MOV     R0, #75*2               ; 75 micro sec delay
        BL      SmallDelay

        MOV    R0, #FdcResetBit
        BL     WrSharedLatch            ; Release 1772 from reset

        BL      FlpReset                ; Claim interrupt vectors

        MOV     R1, R3                  ; Number of floppy drives from CMOS
        SUBS    R0, R0, R0              ; No error (R0 = 0, V clear)
        Pull    "R5,PC"                 ; Restore caller's regs and return
 ]


;-----------------------------------------------------------------------;
; FlpDie                                                                ;
;       Check type of FDC (original 1772 or later '765 in 82C710).      ;
;       Calm the FDC hardware.                                          ;
;       Release interrupt vectors                                       ;
;                                                                       ;
; Input:                                                                ;
;       R11 = -> Instantiation number                                   ;
;       SB  = -> Local storage                                          ;
;       LR  = Return address                                            ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpDie  ROUT
        Push    "R0-R2,LR"              ; Save caller's regs
 [ Debug10
        DREG    R11,"FlpDie, R11: "
 ]
        MOV     R2, SB                  ; R2-> local storage
        LDR     LR, MachineID           ; Get hardware ID
 [ Support1772
        CMPS    LR, #MachHas1772        ; 1772 FDC?
        BEQ     FlpDie1772              ; Yes then jump
 ]

        CMPS    LR, #MachHas82710       ; 82C710 FDC?
        Pull    "R0-R2,PC",NE           ; No, then exit

; Kill the '765 driver

        MOV     R0, #FlpIndex           ; Index pulse interrupt
 [ FloppyPodule
        Push    "R3,R4"
        LDR     R3, FlpDACK_TC
        SUB     R3, R3, #&800000
        LDRB    LR, [R3, #8]
        BIC     LR, LR, #bit2
        STRB    LR, [R3, #8]
        ADD     R3, R3, #4
        MOV     R4, #bit2
 ]
        baddr   R1, FlpIndexIRQ         ; Address of handler
        SWI     XOS_ReleaseDeviceVector ; Release vector (R0-R2->R0,V)
 [ FloppyPCI
        LDR     R0, FlpDMAHandle
        CMP     R0, #-1
        SWINE   XDMA_DeregisterChannel
        MOV     R0, #-1
        STR     R0, FlpDMAHandle
 ]

        MOV     R0, #FlpFintr           ; Floppy IRQ interrupt
        baddr   R1, Flp765IRQ           ; Address of handler
 [ FloppyPodule
        ADD     R3, R3, #&200000
        LDRB    LR, [R3, #8]
        BIC     LR, LR, #bit4
        STRB    LR, [R3, #8]
        MOV     R4, #bit4
 ]
        SWI     XOS_ReleaseDeviceVector ; Release vector (R0-R2->R0,V)
 [ FloppyPodule
        Pull    "R3,R4"
 ]
 [ FloppyPCI
 ]

        MOV     R0, #TickerV            ; 100Hz vector
        baddr   R1, FlpTickerV          ; Address of handler
        SWI     XOS_Release             ; Release vector (R0-R2->R0,V)

        MOV     R1, #-1                 ; De-Select all drives
        BL      FlpDrvSelect            ; All drives off

        MOV     R0, #0
        BL      FlpFDCcontrol           ; Disable FDC hardware

        CLRV
        Pull    "R0-R2,PC"              ; Restore regs and return - no error


 [ Support1772

; Kill the 1772 driver, as per V2.06

FlpDie1772
 [ FileCache
        MOV     R0, #IrqV               ; Interrupt vector
        baddr   R1, IrqVentry           ; Address of our handler
        SWI     XOS_Release             ; Release vector (R0-R2->R0,V)
 ]
        MOV     R0, #TickerV            ; 100Hz vector
        baddr   R1, MyTickerV           ; Address of our handler
        SWI     XOS_Release             ; Release vector (R0-R2->R0,V)

; Deselect all drives

        MOV     R0, #&FF
        BL      SelectFloppy            ; Select no drive

        CLRV
        Pull    "R0-R2,PC"
 ]


;-----------------------------------------------------------------------;
; FlpReset                                                              ;
;       Invoked when the module receives a post soft reset service call.;
;       Claims any vectors needed since these will have been destroyed  ;
;       by the reset.                                                   ;
;                                                                       ;
; Input:                                                                ;
;       R11 = -> Instantiation number                                   ;
;       SB  = -> Local storage                                          ;
;       LR  = Return address                                            ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpReset ROUT
        Push    "R0-R2,LR"              ; Save caller's regs
 [ Debug10
        DREG    R11,"FlpReset, R11: "
 ]
        MOV     R2, SB                  ; R2-> local storage
        LDR     LR, MachineID           ; Get hardware ID
 [ Support1772
        CMPS    LR, #MachHas1772        ; 1772 FDC?
        BEQ     FlpReset1772            ; Yes then jump
 ]

        CMPS    LR, #MachHas82710       ; 82C710 FDC?
        Pull    "R0-R2,PC",NE           ; No, then exit

; Claim vectors for '765 driver

        MOV     R0, #TickerV            ; Claim 100Hz Vector
        baddr   R1, FlpTickerV          ; Address of handler
        SWI     XOS_Claim               ; Claim vector (R0-R2->R0,V)

        MOV     R0, #FlpFintr           ; Floppy IRQ interrupt
 [ FloppyPodule
        Push    "R3,R4"
        LDR     R3, FlpDACK_TC
        SUB     R3, R3, #&600000
        ADD     R3, R3, #4
        MOV     R4, #bit4
 ]
        baddr   R1, Flp765IRQ           ; Address of handler
 [ Debug10
        DREG    R1,"Flp765IRQ is at "
 ]
        SWI     XOS_ClaimDeviceVector   ; Claim vector (R0-R2->R0,V)

        MOV     R0, #FlpIndex           ; Index pulse interrupt
 [ FloppyPodule
        SUB     R3, R3, #&200000
        MOV     R4, #bit2
 ]
        baddr   R1, FlpIndexIRQ         ; Address of handler
 [ Debug10
        DREG    R1,"FlpIndexIRQ is at "
 ]
        SWI     XOS_ClaimDeviceVector   ; Claim vector (R0-R2->R0,V)
 [ FloppyPodule
        Pull    "R3,R4"
 ]
 [ FloppyPCI
        LDR     R0, FlpDMAHandle
        CMP     R0, #-1
        SWINE   XDMA_DeregisterChannel
        Push    "R3-R5"
        baddr   R0, FlpDMAEnable
        baddr   R1, FlpDMADisable
        baddr   R2, FlpDMAStart
        baddr   R3, FlpDMACompleted
        baddr   R4, FlpDMASync
        ADR     R5, FlpDMAHandlers
        STMIA   R5, {R0-R4}
        BL      FlpRegisterDMAChannel
        Pull    "R3-R5"
 ]

; Initialize the hardware

        MOV     R0, #1
        BL      FlpFDCcontrol           ; Enable FDC hardware (if portable)

        MOV     R1, #-1
        BL      FlpDrvSelect            ; Deselect all drives

        baddr   LR, FlpDriveOff
        STR     LR, FlpDrive            ; Drive idle (motor off) state
        BL      Flp765reset             ; Reset '765 FDC

; Enable interrupts for claimed vectors

        PHPSEI  R1, R2                  ; Disable IRQs

 [ HAL
      [ FloppyPodule
        LDR     R0, FlpDACK_TC
        SUB     R0, R0, #&600000
        LDRB    LR, [R0, #8]
        ORR     LR, LR, #bit4
        STRB    LR, [R0, #8]

        SUB     R0, R0, #&200000
        LDRB    LR, [R0, #8]
        ORR     LR, LR, #bit2
        STRB    LR, [R0, #8]

        ASSERT  FlpFintr = FlpIndex     ; Following code results in a double enable
      ]
        Push    "R1,R3,R8,R9"
        MOV     R0, #FlpFintr
        MOV     R8, #OSHW_CallHAL
        MOV     R9, #EntryNo_HAL_IRQEnable
        SWI     XOS_Hardware            ; corrupts R0-R3
        MOV     R0, #FlpIndex
        SWI     XOS_Hardware            ; corrupts R0-R3
        Pull    "R1,R3,R8,R9"
 |
        MOV     R0, #IOC                ; R0-> IOC registers
        LDRB    LR, [R0, #IOCIRQMSKB]   ; Get IRQB mask bits
        ORR     LR, LR, #IOMD_floppy_IRQ_bit
        STRB    LR, [R0, #IOCIRQMSKB]   ; Enable '765 FDC interrupts

        LDRB    LR, [R0, #IOCIRQMSKA]   ; Get IRQA mask bits
        ASSERT  FlpIndex < 8            ; Index IRQ in IOC IRQA
        ORR     LR, LR, #1:SHL:FlpIndex ; Set Index pulse mask bit
        STRB    LR, [R0, #IOCIRQMSKA]   ; Enable Index pulse interrupts
 ]

        PLP     R1

        Pull    "R0-R2,PC"              ; Restore regs and return

 [ Support1772

; Claim vectors for 1772 driver, as per V2.06

FlpReset1772
        MOV     R0, #TickerV            ; Claim 100Hz Vector
        baddr   R1, MyTickerV           ; Address of handler
        SWI     XOS_Claim               ; Claim vector (R0-R2->R0,V)

 [ FileCache
        MOV     R0, #IrqV               ; Claim IRQ vector
        baddr   R1, IrqVentry           ; Address of handler
        SWI     XOS_Claim               ; Claim vector (R0-R2->R0,V)
 ]

; Tidy up drive status flags

        MOV     LR, #0
        STRB    LR, MotorLock           ; Unlock drive
        STRB    LR, FormatFlag          ; In case reset during format

        Pull    "R0-R2,PC"              ; Return to caller
 ]


 [ FloppyPCI
;-----------------------------------------------------------------------;
; FlpRegisterDMAChannel                                                 ;
;       Invoked when the module receives a post soft reset service call.;
;       Claims any vectors needed since these will have been destroyed  ;
;       by the reset.                                                   ;
;                                                                       ;
; Input:                                                                ;
;       None                                                            ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       R0-R5                                                           ;
;_______________________________________________________________________;
;
FlpRegisterDMAChannel
        Push    "LR"
        MOV     R0, #0
        LDR     R1, =DMALC_Floppy
        MOV     R2, #0
        MOV     R3, #1
        ADR     R4, FlpDMAHandlers
        MOV     R5, SB
        SWI     XDMA_RegisterChannel
        MOVVS   R0, #-1
        STR     R0, FlpDMAHandle
        MOV     R0, #-1
        STR     R0, FlpDMATag
        Pull    "PC"
 ]

        LTORG


;-----------------------------------------------------------------------;
; FlpBuildDCB                                                           ;
;       Builds a disk control block for the specified operation         ;
;                                                                       ;
; Input:                                                                ;
;       R0 = reason code                                                ;
;               0= verify, 1= read, 2= write sectors                    ;
;               3= verify track, 4= format track,                       ;
;               5= Seek, 6= Restore, 7= Step in, 8= Step out            ;
;               With background flag too                                ;
;       R1 -> DCB to build                                              ;
;       R2 = disc address (sector/track aligned), top 3 bits = drive    ;
;       R3 -> buffer address or scatter list for read/write ops         ;
;       R4 = Max transfer count in bytes, 0= 1 track                    ;
;       R5 -> disk record                                               ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       R0 = 0, VC, No error                                            ;
;          = Error code, VS                                             ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpOpTable                              ; DiscOp to '765 command lookup
 [ FlpUseVerify
        DCB     FlpCmdVerify            ; 0= verify
 |
        DCB     FlpCmdRead              ; 0= verify
 ]
        DCB     FlpCmdRead              ; 1= read sectors
        DCB     FlpCmdWrite             ; 2= write sectors
        DCB     FlpCmdReadID            ; 3= read all IDs (track)
        DCB     FlpCmdFormat            ; 4= format track
        DCB     FlpCmdSeek              ; 5= Seek
        DCB     FlpCmdRecal             ; 6= Restore
        DCB     BadComErr               ; 7= StepIn, not supported
        DCB     BadComErr               ; 8= StepOut, not supported
        DCB     BadComErr               ; 9= StepInVerify, not supported
        DCB     BadComErr               ; A= StepOutVerify, not supported
        ASSERT  {PC}-FlpOpTable = UnusedFloppyOp

FlpGPLtable                             ; Mode/sector size to gap3 lookup
        DCB     &00, &0E, &1B, &1B      ; 128-1024 Bytes per sector
        DCB     &99, &C8, &C8, &00      ; 2048-16384 MFM
        GBLA    FlpGPLsize
FlpGPLsize      SETA {PC} - FlpGPLtable ; GPL table size for 1 mode
        DCB     &07, &09, &1B, &47      ; 128-1024
        DCB     &C8, &C8, &00, &00      ; 2048-16384 FM

FlpGPLFtable                            ; Format gap3 lookup
        DCB     &00, &32, &54, &54      ; 128-1024 Bytes per sector
        DCB     &FF, &FF, &FF, &00      ; 2048-16384 MFM
        DCB     &1B, &0C, &3A, &8A      ; 128-1024
        DCB     &FF, &FF, &00, &00      ; 2048-16384 FM

        ALIGN

FlpBuildDCB     ROUT
        Push    "R1,R6-R8,LR"           ; Save caller's regs
        MOV     R7, R1                  ; R7->DCB
        MOV     R8, R0                  ; Save Opcode
        AND     R0, R0, #DiscOp_Op_Mask
        CMPS    R0, #UnusedFloppyOp     ; Opcode valid?
        MOVHS   R0, #BadComErr          ; No then bad command
        BHS     %FT90                   ; and exit

; Lookup '765 command for requested operation

        baddr   R6, FlpOpTable
        LDRB    R0, [R6, R0]            ; Lookup '765 command code
        TEQS    R0, #BadComErr          ; Illegal?
        BEQ     %FT90                   ; Yes then exit

; Set bgnd
        ANDS    LR, R8, #DiscOp_Op_BackgroundOp_Flag
        MOVNE   LR, #&ff
        STRB    LR, [R7, #FlpDCBbgnd]
        MOV     LR, #0
        STR     LR, [R7, #FlpDCBtxbytes]

; Get data rate from disk record

        MOV     R6, R0                  ; Save '765 command code
        TEQS    R8, #DiscOp_WriteTrk    ; Format track? (never in background)
        TEQEQS  R3, #0                  ; And buffer address 0?
        LDREQB  LR, [R4, #DoFormatDensity] ; Yes, get density from format spec
        LDRNEB  LR, [R5, #Density]      ; Else get density from disk rec
        CMPS    LR, #Quad               ; Quad density?
        MOVEQ   R0, #FlpCCR500K         ; Yes
        MOVNE   R0, #-1                 ; Else unknown
        CMPS    LR, #Double             ; Double density?
        MOVEQ   R0, #FlpCCR250K         ; Yes
        CMPS    LR, #8                  ; Octal density?
        MOVEQ   R0, #FlpCCR1000K        ; Yes
        CMPS    LR, #Single             ; Single density?
        MOVEQ   R0, #FlpCCR250K + FlpCmdFM ; Yes
        CMPS    LR, #Double+1           ; Double density 360RPM?
        MOVEQ   R0, #FlpCCR300K         ; Yes

        CMPS    R0, #-1                 ; Unknown density?
        MOVEQ   R0, #BadParmsErr        ; Yes then error, bad parameters
        BEQ     %FT90                   ;   And jump, error

 [ FlpMediaCheck
; Check if clock rate supported by disk/drive, R0= CCR, LR= density

        CMPS    LR, #Double+1           ; Double density (300K) or less
        BLS     %FT10                   ; Yes then jump, all discs do 250K
        AND     LR, R8, #DiscOp_Op_Mask
        TEQS    LR, #WriteSecsOp        ; Write sectors
        TEQNES  LR, #WriteTrkOp         ; Or write track
        BNE     %FT10                   ; No, then don't check drive density

        MOV     LR, R2, LSR #(32-3)     ; Get drive number
        sbaddr  R1, FlpDrvMap
        LDRB    LR, [R1, LR]            ; Map logical to physical drive
        DrvRecPtr R1, LR                ; Get-> drive record
        LDR     LR, [R1, #DrvFlags]     ; Get drive flags
        TSTS    LR, #MiscOp_PollChanged_DensityWorks_Flag   ; Media ID works?
        BEQ     %FT10                   ; No, then jump

        TSTS    LR, #MiscOp_PollChanged_HiDensity_Flag      ; Is disc hi density?
        MOVEQ   R0, #BadParmsErr        ; No then bad parameters
        BEQ     %FT90                   ; Error exit
10
 ]
        STRB    R0, [R7, #FlpDCBselect] ; Set data rate
        TSTS    R0, #FlpCmdFM           ; FM mode?
        BICNE   R6, R6, #FlpCmdFM       ; Yes then clear FM bit
        STRB    R6, [R7, #FlpDCBcdb]    ; Write command to DCB

; Check for MultiFS style write track

        TEQS    R8, #DiscOp_WriteTrk    ; Format track?
        TEQEQS  R3, #0                  ; And buffer address 0?
        BEQ     %FT60                   ; Yes then jump, MultiFS format

; Calculate drive/track/head/sector/amount

        BIC     R6, R2, #DiscBits       ; Remove drive no.
        LDRB    LR, [R5, #SectorSize]   ; Get Log2 sector size
        CMPS    LR, #16                 ; Sector size >= 2^16!?
        MOVHS   R0, #BadParmsErr        ; Yes, bad parameters
        BHS     %FT90                   ; Error exit

        MOV     R0, R6, LSR LR          ; Get sector no.
        SUBS    R6, R6, R0, LSL LR      ; Check address on sector boundary
        MOVNE   R0, #BadParmsErr        ; Error if not
        BNE     %FT90                   ; Error exit

        SUB     LR, LR, #7              ; Convert Log2 size to '765 size
        STRB    LR, [R7, #FlpDCBcdb+5]  ; N parameter

; Divide sector address by sectors per track to find track & sector

        LDRB    R1, [R5, #SecsPerTrk]   ; Sectors per track
        BL      Divide                  ; (R0/R1->R0,R1) R0= track, R1= sector
        LDRB    LR, [R5, #LowSector]    ; Get starting sector no.
        BIC     LR, LR, #bit7 + bit6    ; Discard sides/step
        ADD     R6, R1, LR              ; Real sector no.
        STRB    R6, [R7, #FlpDCBcdb+4]  ; R parameter
 [ {FALSE}
        DREG    R6, "Sector ",cc
 ]
        LDRB    R1, [R5, #SecsPerTrk]   ; Sectors per track
        ADD     LR, R1, LR              ; Add starting sector no.
        SUB     R6, LR, R6              ; Calc. sectors available
        SUB     LR, LR, #1              ; Make into last sector number
        STRB    LR, [R7, #FlpDCBcdb+6]  ; EOT parameter

; Ensure transfer size <= bytes available on track

        LDRB    R1, [R5, #SectorSize]
        MOV     R6, R6, LSL R1          ; Calc. bytes available on track
        CMPS    R4, #0                  ; 1 track?
        CMPNES  R6, R4                  ; No, want less than remaining track?
        MOVHI   R6, R4                  ; Yes, transfer less
        AND     LR, R8, #DiscOp_Op_Mask
        CMPS    LR, #DiscOp_ReadSecs    ; Read or verify?
        ORRLS   R6, R6, #FlpDCBread     ; Yes then set read bit
        MOVLO   LR, #&FF                ; Verify?, set verify flag
        MOVEQ   LR, #0                  ; Else set read flag
        STRLSB  LR, [R7, #FlpDCBcdb+9]  ; Pass flag
        AND     LR, R8, #DiscOp_Op_Mask
        ASSERT  DiscOp_Verify < DiscOp_ReadTrk
        ASSERT  DiscOp_ReadSecs < DiscOp_ReadTrk
        ASSERT  DiscOp_WriteSecs < DiscOp_ReadTrk
        CMPS    LR, #DiscOp_ReadTrk     ; Data transfer op?
        ORRLO   R6, R6, #FlpDCBscatter  ; Yes then use scatter list
        TEQS    R8, #DiscOp_ReadTrk     ; Read track ID's?
        MOVEQ   R6, #64*4               ; Yes maximum 64 ID's
        ORREQ   R6, R6, #FlpDCBread     ; And read
        STR     R3, [R7, #FlpDCBbuffer] ; Pass buffer/scatter ptr
        STR     R6, [R7, #FlpDCBlength] ; Save transfer size
 [ {FALSE}
        DREG    R6, " Amount: ",cc
 ]

; Calculate head/track for sequenced or interleaved sides, R0=track

        MOV     LR, R2, LSR #(32-3)     ; Get drive number
        sbaddr  R1, FlpDrvMap
        LDRB    LR, [R1, LR]            ; Map logical to physical drive
        DrvRecPtr R1, LR                ; Get-> drive record
        LDR     LR, [R1, #DrvFlags]     ; Get drive flags
        TSTS    LR, #MiscOp_PollChanged_40Track_Flag        ; 40 track drive?
        MOVEQ   R1, #TrksPerSide        ; No, then default tracks per side
        MOVNE   R1, #40                 ; Else 40 tracks per side
        Push    "R1"                    ; Save tracks/drive

        LDRB    LR, [R5, #LowSector]    ; Get LowSector
 [ {FALSE}
        DREG    LR, "LowSector ",cc
 ]
        TSTS    LR, #bit6               ; Sequenced sides?
        MOVNE   R6, #1                  ; Yes, assume 1 head
        LDREQB  R6, [R5, #Heads]        ; Else get head count
        TSTS    LR, #bit7               ; 40 track media?
        MOVNE   R1, #40                 ; Yes then tracks per side=40
        MOVS    R6, R6, LSR #1          ; Set C if 1 head, =seq sides
        ANDCC   R6, R0, #1              ; If not seq sides head= LSB of track
        MOVCC   R0, R0, LSR #1          ;   and trk = track/2
        CMPCSS  R0, R1                  ; Else if track> tracks per side
        MOVCS   R6, #1                  ; Then head 1
        SUBCS   R0, R0, R1              ; and track -= tracks per side

; Check for double stepping, LR = LowSector

        STRB    R0, [R7, #FlpDCBcdb+2]  ; C parameter
        STRB    R6, [R7, #FlpDCBcdb+3]  ; H parameter
        Pull    "R1"                    ; Get tracks/drive
        TSTS    LR, #bit7               ; 40 track media?
        CMPNES  R1, #40                 ; And not 40 track drive
        ADDNE   R0, R0, R0              ; Yes, then double track no.

        STRB    R0, [R7, #FlpDCBtrack]  ; Set track # for implied seek
 [ Debug10T
        DREG    R0, " Track ",cc
 ]
 [ {FALSE}
        DREG    R6, " Head "
 ]

; Setup drive/head bits

        MOV     R0, R2, LSR #32-3       ; Get drive no.
        sbaddr  LR, FlpDrvMap
        LDRB    R0, [LR, R0]            ; Map logical to physical drive
        TEQS    R6, #0                  ; Head 0?
        ORRNE   R0, R0, #FlpCmdHead     ; No then set head bit
        ORR     R0, R0, #bit7           ; Set implied seek bit
        STRB    R0, [R7, #FlpDCBcdb+1]  ; Write drive/head data

; Lookup GPL from FM/MFM mode and sector size

        baddr   R6, FlpGPLtable         ; R6-> lookup table
        LDRB    LR, [R7, #FlpDCBselect] ; Get clock rate
        TSTS    LR, #FlpCmdFM           ; FM mode?
        ADDNE   R6, R6, #FlpGPLsize     ; Yes then bump R6
        LDRB    LR, [R7, #FlpDCBcdb+5]  ; Get N (sector size) 0..
        LDRB    LR, [R6, LR]            ; Lookup GPL
        STRB    LR, [R7, #FlpDCBcdb+7]  ; Write GPL
 [ FlpUseVerify

; Verify takes Sector Count in place of DTL

        LDRB    LR, [R7, #FlpDCBcdb]
        ASSERT  DiscOp_Verify = 0
        TSTS    R8, #DiscOp_Op_Mask
        MOVNE   LR, #&ff                ; DTL= &ff
        BNE     %FT45
        LDR     R0, [R7, #FlpDCBlength] ; Transfer length plus flags
        LDRB    R1, [R5, #SectorSize]
        MOV     LR, R0, LSR R1          ; Round down to sectors
        TEQ     R0, LR, LSL R1          ; Was it exact?
        ADDNE   LR, LR, #1              ; If not, round up
        TST     LR, #&ff                ; Avoid 0 (-> 256); round up to 1
        MOVEQ   LR, #1
45
 |
        MOV     LR, #&ff                ; DTL= &ff
 ]
        STRB    LR, [R7, #FlpDCBcdb+8]

; Complete the DCB

        AND     LR, R8, #DiscOp_Op_Mask
        CMPS    LR, #DiscOp_ReadTrk     ; Read track?
        MOVEQ   LR, #2                  ; Yes, 2 byte ReadID command
        MOVLO   LR, #9                  ; 9 bytes for read/write sectors
        MOVHI   LR, #6                  ; Else 6 byte format track
        STRB    LR, [R7, #FlpDCBcmdLen] ; Write command length

        MOV     R0, #0                  ; No error
        STR     R0, [R7, #FlpDCBpost]   ; No post routine

        CMPS    R8, #DiscOp_WriteTrk    ; Write track?
        BNE     %FT90                   ; No then jump


; Old style format operation, R3-> track buffer, R5-> disk record
;----------------------------------------------------------------

        LDR     R0, [R7, #FlpDCBparam]  ; Get C, H, R, N
        LDRB    LR, [R5, #SecsPerTrk]   ; Sectors per track
        STRB    LR, [R7, #FlpDCBcdb+3]  ; Set SC
        MOV     R6, LR, LSL #2          ; Bytes to write
        STR     R6, [R7, #FlpDCBlength]

; Fill track buffer with ID's

        MOV     R6, #ScratchSpace       ; Use system space for track image
        STR     R6, [R7, #FlpDCBbuffer]
50      STR     R0, [R6], #4            ; Write ID to buffer
        ADD     R0, R0, #&10000         ; Next sector no.
        SUBS    LR, LR, #1
        BNE     %BT50                   ; For all sectors

; Set format parameters

        LDRB    R0, [R5, #SectorSize]   ; Get Log2 sector size
        SUB     R0, R0, #7              ; Adjust 0..
        STRB    R0, [R7, #FlpDCBcdb+2]  ; Set N parameter

; Lookup format GPL from FM/MFM mode and sector size

        baddr   R6, FlpGPLFtable        ; R6-> lookup table
        LDRB    LR, [R7, #FlpDCBselect] ; Get clock rate
        TSTS    LR, #FlpCmdFM           ; FM mode?
        MOVNE   LR, #&FF                ; Yes, fill byte= &FF
        MOVEQ   LR, #&5A                ; No, fill byte= &5A
        STRB    LR, [R7, #FlpDCBcdb+5]  ; Set D
        ADDNE   R6, R6, #FlpGPLsize     ; Yes then bump R6
        LDRB    LR, [R6, R0]            ; Lookup GPL
        STRB    LR, [R7, #FlpDCBcdb+4]  ; Write GPL
        MOV     R0, #0                  ; No errors
        B       %FT90                   ; Exit


; MultiFS style format, R4-> disk format specification structure
;---------------------------------------------------------------
60
; Calc. Log2 sector size

        LDR     R0, [R4, #DoFormatSectorSize] ; Get sector size
        TSTS    R0, #&7F                ; Check not odd size
        MOVNE   R0, #BadParmsErr        ; Error if so
        BNE     %FT90                   ; Error exit

        MOV     R1, #7                  ; Log2 of smallest sector size
62      MOVS    LR, R0, LSR R1
        MOVCS   R0, #BadParmsErr        ; Error if not power of 2
        BCS     %FT90                   ; Error exit
        TEQS    LR, #1                  ; R0 = 2^R1?
        ADDNE   R1, R1, #1              ; No then try next power of 2
        BNE     %BT62                   ; And repeat

; Calculate drive/track/head

        BIC     R6, R2, #DiscBits       ; Remove drive no.
        MOV     R0, R6, LSR R1          ; Get sector no.
        SUBS    R6, R6, R0, LSL R1      ; Check address on sector boundary
        MOVNE   R0, #BadParmsErr        ; Error if not
        BNE     %FT90                   ; Error exit

        SUB     R1, R1, #7              ; Convert Log2 size to '765 sector size
        STRB    R1, [R7, #FlpDCBcdb+2]  ; N parameter

; Divide sector address by sectors per track to find track#

        LDRB    R1, [R4, #DoFormatSectorsPerTrk] ; Sectors per track
        STRB    R1, [R7, #FlpDCBcdb+3]  ; SC parameter
        MOV     LR, R1, LSL #2          ; Bytes to write, no scatter list
        STR     LR, [R7, #FlpDCBlength]
        ADD     LR, R4, #DoFormatSectorList ; LR-> ID buffer
        STR     LR, [R7, #FlpDCBbuffer] ; Pass ID buffer ptr
        BL      Divide                  ; (R0/R1->R0,R1) R0= track, R1= sector
        TEQS    R1, #0                  ; Check address on track boundary
        MOVNE   R0, #BadParmsErr        ; Error if not
        BNE     %FT90                   ; Error exit

; Calculate head/track for sequenced or interleaved sides, R0=track

        LDRB    R1, [R4, #DoFormatOptions]
        MOVS    LR, R1, LSR #3          ; Set C if not alt sides
        MOVCCS  LR, R1, LSR #4          ;
        ANDCC   R6, R0, #1              ; If alt sides head= LSB of track
        MOVCC   R0, R0, LSR #1          ;   and trk = track/2
        MOVCS   R6, #0
        LDRCS   LR, [R4, #DoFormatCylindersPerDrive] ; Else get tracks per drive
        CMPCSS  R0, LR                  ; And if track> tracks per drive
        MOVCS   R6, #1                  ; Then head 1
        SUBCS   R0, R0, LR              ; and track -= tracks per drive

; Check for double stepping

        TSTS    R1, #FormatOptDoubleStep   ; Double stepping?
        BEQ     %FT70                   ; No then jump

        MOV     LR, R2, LSR #(32-3)     ; Get drive number
        sbaddr  R1, FlpDrvMap
        LDRB    LR, [R1, LR]            ; Map logical to physical drive
        DrvRecPtr R1, LR                ; Get-> drive record
        LDR     LR, [R1, #DrvFlags]     ; Get drive flags
        TSTS    LR, #MiscOp_PollChanged_40Track_Flag        ; 40 track drive?
        ADDEQ   R0, R0, R0              ; No, then double track no.

70      STRB    R0, [R7, #FlpDCBtrack]  ; Set track # for implied seek
 [ Debug10T
        DREG    r0, "Format on track "
 ]

; Setup drive/head bits

        MOV     R0, R2, LSR #32-3       ; Get drive no.
        sbaddr  LR, FlpDrvMap
        LDRB    R0, [LR, R0]            ; Map logical to physical drive
        TEQS    R6, #0                  ; Head 0?
        ORRNE   R0, R0, #FlpCmdHead     ; No then set head bit
        ORR     R0, R0, #bit7           ; Set implied seek bit
        STRB    R0, [R7, #FlpDCBcdb+1]  ; Write drive/head data

; Complete remainder of DCB

        LDR     LR, [R4, #DoFormatGap3]   ; Lookup GPL
        STRB    LR, [R7, #FlpDCBcdb+4]  ; Write GPL
        LDRB    LR, [R4, #DoFormatFillValue]   ; Lookup fill byte
        STRB    LR, [R7, #FlpDCBcdb+5]  ; Write fill byte

        MOV     LR, #6                  ; 6 byte format track
        STRB    LR, [R7, #FlpDCBcmdLen] ; Write command length
        MOV     R0, #0                  ; No error
        STR     R0, [R7, #FlpDCBpost]   ; No post routine


; Return any error to caller
90
        Pull    "R1,R6-R8,LR"           ; Restore caller's regs
        CMPS    R0, #0                  ; Any error?
        MOVEQ   PC, LR                  ; Return V clear
 [ Debug10
        DREG    R0,"!!! FlpBuildDCB ERROR: ",cc
        DREG    R1, " ",cc
        DREG    R2, " ",cc
        DREG    R3, " ",cc
        DREG    R4, " ",cc
        DREG    R5, " "
 ]
        RETURNVS                        ; Return V set == error


;-----------------------------------------------------------------------;
; FlpADFSerror                                                          ;
;       Convert '765 status register values to an ADFS error code       ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Error                                                      ;
;       R1 -> DCB                                                       ;
;       R2 = Disc address                                               ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       R0 = ADFS error code                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpADFSerror    ROUT
 [ NewErrors
        CMPS    R0, #MaxDiscErr
        BLO     %FT10
 ]
        CMPS    R0, #FlpDiscError       ; Controller status error?
        MOVNE   PC, LR                  ; No then return R0

; Get base error code

        LDRB    R0, [R1, #FlpDCBresults] ; Get ST0
 [ Debug10
        DREG    R0,"!!! Controller Error ST0: "
 ]
        TEQS    R0, #&80                ; Invalid command?
        MOVEQ   R0, #BadComErr          ; Yes then bad command error
        MOVEQ   PC, LR                  ; And exit

        TEQS    R0, #&90                ; Version command status?
        MOVEQ   R0, #0                  ; Yes then no error
        MOVEQ   PC, LR                  ; And exit

        TSTS    R0, #bit4               ; Track 0 fault?
        MOVNE   R0, #FlpErrTrk0Fault    ; Yes then Track 0 error
        MOVNE   PC, LR                  ; And exit

; Check ST1

        LDRB    R0, [R1, #FlpDCBresults+1] ; Get ST1
        TSTS    R0, #bit1               ; Write protect?
        MOVNE   R0, #WriteProtErr       ; Yes then error
        MOVNE   PC, LR                  ; And exit

        TSTS    R0, #bit2               ; Sector not found?
        MOVNE   R0, #FlpErrNotFound     ; Yes then error
        BNE     %FT10                   ; Jump if error found

        TSTS    R0, #bit4               ; Overrun
        MOVNE   R0, #FlpErrLost         ; Yes then lost data
        BNE     %FT10                   ; Jump if found

        TSTS    R0, #bit5               ; CRC error?
        MOVNE   R0, #FlpErrCRC          ; Yes then error
        BNE     %FT10                   ; Jump if error found

        TSTS    R0, #bit0               ; Missing address mark?
        MOVNE   R0, #FlpErrNoAM         ; Yes then error
        BNE     %FT10                   ; Jump if error found

; Try ST2 for cause of error

        LDRB    R0, [R1, #FlpDCBresults+2] ; Get ST2
        TSTS    R0, #bit4+bit1          ; Seek error?
        MOVNE   R0, #FlpErrSeekFault    ; Yes then error
        MOVEQ   R0, #FlpErrSoft         ; Else non specific soft error

10
 [ NewErrors
        Push    "R1,LR"
        MOV     R1, R0, LSL #8          ; shift error up to bit 8
        ORR     R1, R1, R2, LSR #(32-3) ; put drive number at bit 0
        BIC     LR, R2, #DiscBits       ; extract address
        ADR     R0, WinIDEErrorNo       ; store in error block
        STMIA   R0, {R1,LR}             ; (borrow IDE workspace)
        MOV     LR, #0
        STR     LR, [R0, #8]
        ORR     R0, R0, #NewDiscErrorBit
        Pull    "R1,PC"                 ; And exit
 |
        ORR     R0, R0, R2, LSR #8      ; Add disc address
        MOV     PC, LR                  ; And exit
 ]


;-----------------------------------------------------------------------;
; FlpComplete                                                           ;
;       Calls filecore to acknowledge background completion and to      ;
;       return FIQ's.  Entered in SVC mode                              ;
;                                                                       ;
; Input:                                                                ;
;       R6 = Opcode                                                     ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpComplete     ROUT
 [ No32bitCode
        Push    "R0,R1,SB,LR"           ; Save caller's regs
 |
        Push    "R0,R1,R4,SB,LR"        ; Save caller's regs
        SavePSR R4
 ]
 [ FloppyPCI
        BL      FlpDMATerminate
 ]
        TSTS    R6, #DiscOp_Op_BackgroundOp_Flag ; Background operation?
        BEQ     %FT10                   ; No then jump

; Tell FileCore that background op, if any, has completed

        ADD     SB, SB, # :INDEX: FileCorePrivate ; SB-> FileCore save area
        ASSERT  FloppyCallAfter = FileCorePrivate + 4
        MOV     LR, PC                  ; Set return address
        LDMIA   SB, {SB,PC}             ; Set SB & Call [FloppyCallAfter]

 [ No32bitCode
        LDR     SB, [SP, #8]            ; Restore SB, assume R0 TOS
 |
        LDR     SB, [SP, #12]           ; Restore SB, assume R0 TOS
 ]

10

 [ :LNOT:FloppyPCI
; Release FIQ

        LDR     R0, FiqRelease          ; Get address of release routine
        LDR     SB, FileCorePrivate     ; FileCore's private data
        MOV     LR, PC                  ; Set return address
        MOV     PC, R0                  ; Call [FiqRelease]
 ]

 [ No32bitCode
        Pull    "R0,R1,SB,PC",,^        ; Restore caller's regs and exit
 |
        RestPSR R4,,f
        Pull    "R0,R1,R4,SB,PC"        ; Restore caller's regs and exit
 ]


;-----------------------------------------------------------------------;
; FlpLowNdataPost                                                       ;
;       Post routine for non-data DCB's submitted by FlpLowLevel        ;
;       Entered from IRQ mode normally                                  ;
;                                                                       ;
; Input:                                                                ;
;       R0 = completion status                                          ;
;       R1-> DCB                                                        ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpLowNdataPost ROUT
        Push    "R2,LR"                 ; Save caller's regs
 [ FlpPostIrqOn
        WritePSRc SVC_mode,LR,,R2       ; Switch to SVC mode, IRQ's enabled
 |
        WritePSRc SVC_mode+I_bit,LR,,R2 ; Switch to SVC mode, IRQ's disabled
 ]
        NOP                             ; Delay for mode change
        Push    "R2,R6,LR"              ; Save old mode and SVC LR on SVC stack

; Test for errors

        TEQS    R0, #0                  ; An error?
        LDRNE   R2, FlpFgStatus+4       ; Yes get disc address
        BLNE    FlpADFSerror            ; and (R1,R2->R0) convert to ADFS error
 [ Debug10
        TEQS    R0, #0                  ; Any error
        BEQ     %FT900                  ; Yes then jump
        DREG    R0,"NonData Error status ", cc
        LDRB    LR, [R1, #FlpDCBresults] ; ST0
        DREG    LR, " ST0: ",cc
        LDRB    LR, [R1, #FlpDCBresults+1] ; ST1
        DREG    LR, " ST1: ",cc
        LDRB    LR, [R1, #FlpDCBresults+2] ; ST2
        DREG    LR, " ST2: "
;        LDRB    LR, [R1, #FlpDCBresults+3] ; C
;        DREG    LR, "C/H/R/N: ",cc
;        LDRB    LR, [R1, #FlpDCBresults+4] ; H
;        DREG    LR, " ",cc
;        LDRB    LR, [R1, #FlpDCBresults+5] ; R
;        DREG    LR, " ",cc
;        LDRB    LR, [R1, #FlpDCBresults+6] ; N
;        DREG    LR, " "
900
 ]
        STR     R0, FlpFgStatus         ; Foreground complete
        MOV     R6, #0                  ; Not background
        BL      FlpComplete             ; (R6->) Callback FileCore, No FIQs

        Pull    "R2,R6,LR"              ; Restore SVC regs
        RestPSR R2                      ; Restore IRQ mode
        NOP                             ; Delay for mode change
        Pull    "R2,PC"                 ; Return from post


;-----------------------------------------------------------------------;
; FlpLowDataPost                                                        ;
;       Post routine for data transfer DCB's submitted by FlpLowLevel   ;
;       Entered from IRQ mode normally                                  ;
;                                                                       ;
; Input:                                                                ;
;       R0 = completion status                                          ;
;       R1-> DCB                                                        ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpLowDataPost  ROUT
        Push    "R2,LR"                 ; Save caller's regs
        WritePSRc SVC_mode+I_bit,LR,,R2 ; Switch to SVC mode, IRQ's disabled
        NOP                             ; Delay for mode change
        Push    "R0-R9,LR"              ; Save old mode and SVC LR on SVC stack

        ADR     LR, FlpFiqMiscWs
        LDMIA   LR, {R2,R5,R6,R8}       ; Restore working registers
        LDR     R9, [R1, #FlpDCBtxbytes] ; Bytes transferred total
        LDR     R7, [R1, #FlpDCBbuffer] ; Updated scatter ptr
        LDMIA   R7, {R3,R4}             ; Updated final buffer entry

; R0= Status, R1-> DCB
; R2= disc address, R3-> buffer, R4= buffer size, R5-> disc record
; R6= opcode, R7-> scatter list, R8= foreground size, R9= bytes transferred

 [ Debug10a
        DREG    R0,"DCB status ", cc
        DREG    R9, " Len: ", cc
        LDRB    LR, [R1, #FlpDCBresults] ; ST0
        BREG    LR, " ST0: ",cc
        LDRB    LR, [R1, #FlpDCBresults+1] ; ST1
        BREG    LR, " ST1: ",cc
        LDRB    LR, [R1, #FlpDCBresults+2] ; ST2
        BREG    LR, " ST2: "
        LDRB    LR, [R1, #FlpDCBresults+3] ; C
        BREG    LR, "C/H/R/N: ",cc
        LDRB    LR, [R1, #FlpDCBresults+4] ; H
        BREG    LR, " ",cc
        LDRB    LR, [R1, #FlpDCBresults+5] ; R
        BREG    LR, " ",cc
        LDRB    LR, [R1, #FlpDCBresults+6] ; N
        BREG    LR, " "
        DREG    R2, "Disc address "
        DREG    R6, "Op "
        DREG    R7, " Scatter@",cc
        DREG    R3, "=(",cc
        DREG    R4, ",",cc
        DLINE   ")"
        Push    "r3,r4,r7"
        ADD     r7, r7, #8
        LDMIA   r7, {r3,r4}
        DREG    R7, " Scatter@",cc
        DREG    R3, "=(",cc
        DREG    R4, ",",cc
        DLINE   ")"
        Pull    "r3,r4,r7"
        DREG    R8, "Foreground length "
 ]

        ; Advance address
        ADD     r2, r2, r9

        TEQ     R0, #0                  ; Error?
        BEQ     %FT05

        ; Handling errors

        BL      FlpADFSerror

        ; Advance foreground length
        SUBS    r8, r8, r9
        MOVLO   r8, #0

        B       %FT10

05
        ; Non error CDB completion...

        ; If foreground already exhausted check for background continuation
        TEQ     R8, #0
        BEQ     %FT20

        ; Advance foreground length
        SUBS    r8, r8, r9
        MOVLO   r8, #0

        ; If still more foreground stuff resubmit CDB
        BHI     %FT70

10
 [ Debug10a
        DREG    R0, "Foreground op finished, R0="
 ]
        ; Foreground is now exhausted or finished due to error - mark it as so
        sbaddr  LR, FlpFgStatus
        STMIA   LR, {R0,R2,R7,R8}

20
        ; If foreground only op then whole op is complete
        TST     r6, #DiscOp_Op_BackgroundOp_Flag
        BEQ     %FT60

        ; If error terminated us then update process header too...
        TEQ     r0, #0
        BNE     %FT45

        ; Background op continuing perhaps

        ; If current entry has some more then restart the transfer
        TEQ     r4, #0
        BNE     %FT70

45
; Background op finished due to completion or error - update process header
 [ Debug10a
        DREG    R0, "Background op finished, R0="
 ]

        ; Search for end of list
        MOV     R9, R7                  ; Save pointer to last pair
50      LDR     R8, [R7, #8]!           ; Get next buffer address from list
 [ FixTBSAddrs
        CMN     R8,#ScatterListNegThresh; End of list?
        BCC     %BT50                   ; No then loop
 |
        TEQS    R8, #0                  ; End of list?
        BPL     %BT50                   ; No then loop
 ]
        ADD     R7, R7, R8              ; R7-> start of list

 [ NewErrors
        LDRB    LR, NewErrorsFlag
        TEQS    LR, #0                  ; new FileCore?
        MOVNE   R9, R9, LSR #2          ; then store ms 30 bits
        BLEQ    ConvertErrorForParent
 ]
        ; Update process status block
        STMDB   R7, {R0,R9}
 [ Debug10S
  [ NewErrors
        MOVNE   R9, R9, LSL #2
  ]
        LDR     lr, [r9, #8]
        DREG    lr,"S(",cc
        LDR     lr, [r9, #12]
        DREG    lr,",",cc
        DLINE   ") ",cc
 ]

60
; Whole transfer complete - tell FileCore about it

        BL      FlpComplete             ; (R6->) Callback FileCore, No FIQs
        B       %FT90                   ; Exit

70
; Setup for next transfer

 [ fix_9
        ; Interlock the DCB
        SUB     sp, sp, #FlpDCBsize
        ADR     lr, NulFunc
        STR     lr, [sp, #FlpDCBhandler]
        MOV     lr, #0
        STR     lr, [sp, #FlpDCBlink]
        LDR     R0, FlpDCBqueue
        TEQ     R0, #0
        STREQ   sp, FlpDCBqueue

        WritePSRc SVC_mode,R0           ; Enable IRQs during the long part with interlock on
 ]

        LDR     R0, =DiscOp_Op_Mask :OR: DiscOp_Op_BackgroundOp_Flag
        AND     R0, R6, R0              ; Get opcode
        TEQS    R0, #DiscOp_Verify      ; Verify? (never background)
        LDREQB  LR, FloppyDefectRetries ; Yes get verify retries
        LDRNEB  LR, FloppyRetries       ; Else normal retries
        STRB    LR, [R1, #FlpDCBretries] ; Write retries

        MOV     R4, R8                  ; Foreground length
        MOV     R3, R7                  ; Scatter ptr
 [ Debug10a
        DREG    R2, "PostBldDCB R2-R4: ",cc
        DREG    R3, " ",cc
        DREG    R4, " "
 ]
        BL      FlpBuildDCB             ; (R0-R5->R0,V) Build a DCB
 [ fix_9
        BVC     %FT71
        LDR     lr, FlpDCBqueue
        TEQ     lr, sp
        MOVEQ   lr, #0
        STREQ   lr, FlpDCBqueue
        ADD     sp, sp, #FlpDCBsize
        B       %BT10                   ; Jump if error
71
 |
        BVS     %BT10                   ; Jump if error
 ]

; Submit DCB for processing, R1->DCB

        baddr   LR, FlpLowDataPost
        STR     LR, [R1, #FlpDCBpost]   ; Save-> post routine, SB was set
        ADR     LR, FlpFiqMiscWs
        STMIA   LR, {R2,R5,R6,R8}       ; Save working registers

 [ fix_9
        WritePSRc SVC_mode+I_bit,R0     ; IRQs off whilst interlock off

        ; release interlock on the DCB
        LDR     R0, FlpDCBqueue
        TEQ     R0, sp
        MOVEQ   R0, #0                  ; Put back the standard queue end
        STREQ   R0, FlpDCBqueue
        ADD     sp, sp, #FlpDCBsize
 ]

        BL      FlpAddDCB               ; Add DCB to queue (R1->R0,V)
        BVS     %BT10                   ; Jump if error

; Return from post routine
90
        Pull    "R0-R9,LR"              ; Restore SVC regs
        RestPSR R2                      ; Restore IRQ mode
        NOP                             ; Delay for mode change
        Pull    "R2,PC"                 ; Restore caller's regs and exit

 [ fix_9
NulFunc MOV     pc, lr
 ]


;-----------------------------------------------------------------------;
; FlpLowLevel                                                           ;
;       Perform disk operations.  Invoked when the module receives a    ;
;       FileCore DiskOp call with a drive number in the range 0 to 3.   ;
;                                                                       ;
; Input:                                                                ;
;       R1 = b0-3: reason code                                          ;
;               0= verify, 1= read, 2= write sectors                    ;
;               3= verify track, 4= format track,                       ;
;               5= Seek, 6= Restore, 7= Step in, 8= Step out,           ;
;               15= specify                                             ;
;            b4 = Alternate defect map                                  ;
;            b5 = R3 -> scatter list                                    ;
;            b6 = Ignore escape                                         ;
;            b7 = No ready timeout                                      ;
;            b8 = Background op                                         ;
;       R2 = disc address (sector/track aligned), top 3 bits = drive    ;
;       R3 -> transfer buffer                                           ;
;       R4 = length in bytes                                            ;
;       R5 -> disk record                                               ;
;       R8 -> private word                                              ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       R0 = 0, VC, No error                                            ;
;          = Error code, VS                                             ;
;       R2 = Disk address of next byte to transfer                      ;
;       R3 -> Next buffer address                                       ;
;       R4 = Number of bytes left in buffer                             ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpLowLevel ROUT
        Push    "R0,R5-R8,LR"           ; Save caller's regs
        LDR     R6, MachineID           ; Get machine type
 [ Support1772
        CMPS    R6, #MachHas1772        ; 1772 FDC?
        BEQ     FlpLow1772              ; Yes, then do 1772 operation
 ]

        CMPS    R6, #MachHas82710       ; 82C710 FDC?
        Pull    "R0,R5-R8,PC",NE        ; No then exit

; Process DiscOp with '765 controller

 [ Debug10f
        DREG    R1,"FlpLowLevel, R1-R5: ",cc
        DREG    R2," ",cc
        DREG    R3," ",cc
        DREG    R4," Len=",cc
        DREG    R5

        TST     R1, #DiscOp_Op_BackgroundOp_Flag
        BNE     %FT01
        TST     R1, #DiscOp_Op_ScatterList_Flag
        BEQ     %FT01
        DLINE   " Scatter=",cc
        MOV     r6, r3
        MOV     r7, r4
02
        LDMIA   r6!, {r8}
        DREG    r8, " (",cc
        LDMIA   r6!, {r8}
        DREG    r8,",",cc
        DLINE   ")",cc
        SUBS    r7, r7, r8
        BHI     %BT02
        DLINE   ""
01
 ]
        MOV     R6, R1                  ; Save opcode
        sbaddr  R1, FlpDCB              ; R1-> static DCB

        LDR     R0, =DiscOp_Op_Mask :OR: DiscOp_Op_BackgroundOp_Flag
        AND     R0, R6, R0              ; Get opcode (incl background bit)
        TSTS    R6, #DiscOp_Op_ScatterList_Flag ; Is R3-> scatter list?
        MOVNE   R7, R3                  ; Yes get scatter ptr
        sbaddr  R7, FlpFgScatter, EQ    ; Else simulate scatter list
        STMEQIA R7, {R3,R4}             ; And set up a scatter list

        AND     LR, R6, #DiscOp_Op_Mask
        ASSERT  DiscOp_Verify < DiscOp_ReadTrk
        ASSERT  DiscOp_ReadSecs < DiscOp_ReadTrk
        ASSERT  DiscOp_WriteSecs < DiscOp_ReadTrk
        CMPS    LR, #DiscOp_ReadTrk     ; Data transfer op?
        MOVLO   R3, R7                  ; Yes, R3-> scatter list

; Setup DCB for required operation

        BL      FlpBuildDCB             ; (R0-R5->R0,V) Build a DCB
        BLVS    FlpComplete             ; Release FIQs if error
        BVS     %FT30                   ; Jump if error

        TSTS    R6, #DiscOp_Op_IgnoreEscape_Flag ; Escapes allowed?
        MOVNE   LR, #1                  ; No then disable them
        MOVEQ   LR, #0                  ; Else allowed
        STRB    LR, [R1, #FlpDCBesc]    ; Write escape enable flag

        TSTS    R6, #DiscOp_Op_IgnoreTimeout_Flag ; Timeouts disabled?
        MOVEQ   LR, #FlpCmdTimeOut      ; No then normal command timeout
        MOVNE   LR, #0                  ; Else none
        STRB    LR, [R1, #FlpDCBtimeOut] ; Set DCB timeout

; Submit DCB for processing

        AND     R0, R6, #DiscOp_Op_Mask ; Get opcode
        TEQS    R0, #DiscOp_Verify      ; Verify?
        LDREQB  LR, FloppyDefectRetries ; Yes get verify retries
        LDRNEB  LR, FloppyRetries       ; Else normal retries
        TEQS    R0, #DiscOp_Restore     ; Restoring?
        TEQEQS  LR, #0                  ; And no retries
        MOVEQ   LR, #1                  ; Then force at least 1
        STRB    LR, [R1, #FlpDCBretries] ; Set retries

        ASSERT  DiscOp_Verify < DiscOp_ReadTrk
        ASSERT  DiscOp_ReadSecs < DiscOp_ReadTrk
        ASSERT  DiscOp_WriteSecs < DiscOp_ReadTrk
        CMPS    R0, #DiscOp_ReadTrk     ; Data transfer operation?
        baddr   LR, FlpLowDataPost, LO  ; Yes then data post
        baddr   LR, FlpLowNdataPost, HS ; Else nondata post
        STR     LR, [R1, #FlpDCBpost]   ; Save-> post routine
        STR     SB, [R1, #FlpDCBsb]
        ADR     LR, FlpFiqMiscWs
        MOV     R7, R4
        STMLOIA LR, {R2,R5,R6,R7}       ; Save data transfer registers
        MOVHS   R0, #FlpDCBpending      ; Non data so wait for completion
        BHS     %FT15                   ; And jump

        TEQS    R4, #0                  ; Any foreground data?
        MOVEQ   R0, #0                  ; No then foreground done
        MOVNE   R0, #FlpDCBpending      ; Else foreground to wait
15
        sbaddr  LR, FlpFgStatus         ; LR-> results
        STMIA   LR, {R0,R2,R3,R4}       ; Write f/g state and transfer regs

        BL      FlpAddDCB               ; Add DCB to queue (R1->R0,V)
        BLVS    FlpComplete             ; Release FIQs if error
        BVS     %FT30                   ; Jump if error

20      LDR     R0, FlpFgStatus         ; Get foreground status
        CMPS    R0, #FlpDCBpending      ; Still processing?
        BEQ     %BT20                   ; Yes then loop

        sbaddr  LR, FlpFgStatus         ; LR-> results
        LDMIA   LR, {R0,R2,R3,R4}       ; Collect updated regs from post

; Tidy up after foreground operation completed, R0= error code

30      MOV     R1, R6                  ; Restore opcode
        TSTS    R6, #DiscOp_Op_ScatterList_Flag ; Is R3-> scatter list?
        LDREQ   R3, FlpFgScatter        ; No, return buffer address
 [ Debug10f
;        DREG    R1,"ForeGnd done R1-R4: ",cc
;        DREG    R2," ",cc
;        DREG    R3," ",cc
;        DREG    R4
 ]
        BL      SetVOnR0                ; Error?, then set V
 [ Support1772
        B       FlpLowExit              ; Exit

; Low level operation for 1772 driver

FlpLow1772
        AND     R0, R1, #DiscOp_Op_Mask ; Get Disc Op
        TEQS    R0, #WriteTrkOp         ; Write track?
        TEQEQS  R3, #0                  ; And buffer address 0?
        BNE     %FT10
        BL      Flp1772format           ; Yes do MultiFS format
 [ Debug10f
        DLINE   "MultiFS format done"
 ]
        B       FlpLowExit              ; And exit

10      TEQS    R0, #VerifyOp           ; Verify operation?
        LDREQB  R6, FloppyDefectRetries ; Yes then defect retries
        LDRNEB  R6, FloppyRetries       ; Else normal retries
        BL      RetryFloppyOp           ; Do op. (R1-R6->R0,R2,R3,R4,V)
 ]

; Common exit from FlpLowLevel

FlpLowExit
        STRVS   R0, [SP]                ; Return R0 if error
 [ Debug10f
        BVC     %FT90
        DREG    R0,"!!ERROR!! in FlpLowLevel, R0="
90
 ]
        Pull    "R0,R5-R8,PC"           ; Restore caller's regs


;-----------------------------------------------------------------------;
; FlpMount                                                              ;
;       Invoked when the module receives a FileCore miscellaneous call  ;
;       with a reason code of 0 (R0 = 0, mount disk).                   ;
;                                                                       ;
; Input:                                                                ;
;       R0 = 0                                                          ;
;       R1 = drive                                                      ;
;       R2 = disc address to read (sector aligned)                      ;
;       R3 -> transfer buffer                                           ;
;       R4 = length in bytes                                            ;
;       R5 -> disk record to fill in                                    ;
;             SectorSize      # 1     ;log2 sector size                 ;
;             SecsPerTrk      # 1                                       ;
;             Heads           # 1     ;1 for old adfs floppy format     ;
;             Density         # 1     ;1/2/4 single double quad         ;
;       R12 = SB                                                        ;
;       LR = Return address                                             ;
;                                                                       ;
; Output:                                                               ;
;       R0 = 0, VC, No error                                            ;
;          = Error code, VS                                             ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;                                                                       ;
; Algorithm explanation:                                                ;
; Tries density in disc record first then tries densities in            ;
; FlpCCRtable one after the other. The first that works is used.        ;
; Note: Double occurs twice in the table, once after Quad and once at   ;
; the end to allow the drive to slow down after Quad - 3 revolutions    ;
; of slow-down guaranteed for Octal. After a successful read sector IDs ;
; a sector is verified to confirm the density is right                  ;
;_______________________________________________________________________;
;
FlpCCRtable                             ; Table of densities/modes to mount
        DCB     FlpCCR500K, Quad        ; Quad density, 500Kbps
        DCB     FlpCCR250K, Double      ; Double density, 250Kbps
        DCB     FlpCCR1000K, 8          ; Octal density, 250Kbps
        DCB     FlpCCR250K + FlpCmdFM, Single ; Single density, 125Kbps
        DCB     FlpCCR300K, Double+1    ; Double density, 300Kbps for PC's
        DCB     FlpCCR250K, Double      ; Double density, 250Kbps
        DCB     &FF, &FF                ; End of list
        ALIGN

FlpMount ROUT
 [ Debug10
        DREG    R1,"FlpMount, R1-R5: ",cc
        DREG    R2," ",cc
        DREG    R3," ",cc
        DREG    R4," ",cc
        DREG    R5," "
 ]
        LDR     R0, MachineID           ; Get machine type
 [ Support1772
        CMPS    R0, #MachHas1772        ; 1772 FDC
        BEQ     OldDoMount              ; Yes, then mount with 1772 controller
 ]

        CMPS    R0, #MachHas82710       ; 82C710 FDC?
        MOVNE   PC, LR                  ; No then exit

; Mount disk using '765 FDC

        Push    "R1-R4,R6-R8,LR"
MountBufferSize * 512
        SUB     sp, sp, #MountBufferSize

        sbaddr  R7, FlpDCB              ; R7-> DCB for mount
        MOV     R0, #0
        STRB    R0, [R7, #FlpDCBesc]    ; Write escape enable flag

        MOV     R0, #60                 ; 600mS command timeout
        STRB    R0, [R7, #FlpDCBtimeOut] ; Set DCB timeout

; Get data rate from suggested density in drive record supplied

        baddr   R8, FlpCCRtable         ; R8->known disk formats
        LDRB    LR, [R5, #Density]      ; Get suggested density from disk rec

        CMPS    LR, #Quad               ; Quad density?
        MOVEQ   R0, #FlpCCR500K         ; Yes
        MOVNE   R0, #-1                 ; Else unknown
        CMPS    LR, #Double             ; Double density?
        MOVEQ   R0, #FlpCCR250K         ; Yes
        CMPS    LR, #8                  ; Octal density?
        MOVEQ   R0, #FlpCCR1000K        ; Yes
        CMPS    LR, #Single             ; Single density?
        MOVEQ   R0, #FlpCCR250K + FlpCmdFM ; Yes
        CMPS    LR, #Double+1           ; 300Kbps mode
        MOVEQ   R0, #FlpCCR300K         ; Yes

        CMPS    R0, #-1                 ; Unknown density
        BEQ     %FT25                   ; Yes then jump, use known formats

; Construct the mount DCB, R0= CCR/FM mode

05
 [ Debug10
        BREG    R0, "Try density setting "
 ]
        STRB    R0, [R7, #FlpDCBselect] ; Set data rate
        STR     SP, [R7, #FlpDCBbuffer] ; Save buffer address
        MOV     LR, #MountBufferSize    ; Read all ID's on track
        STR     LR, [R7, #FlpDCBlength] ;
        MOV     LR, #0
        STR     LR, [R7, #FlpDCBpost]   ; No post routine
        STRB    LR, [R7, #FlpDCBretries] ; No retries

; Prepare a ReadID command

        MOV     LR, #FlpCmdReadID       ; Read ID command code
        TSTS    R0, #FlpCmdFM           ; FM mode?
        BICNE   LR, LR, #FlpCmdFM       ; Yes then clear FM bit
        STRB    LR, [R7, #FlpDCBcdb]    ; Write command

        MOV     R1, R2, LSR #32-3       ; Get drive no.
        sbaddr  LR, FlpDrvMap
        LDRB    LR, [LR, R1]            ; Map logical to physical drive
        ADD     LR, LR, #FlpCmdHead*0   ; Head 0
        ORR     LR, LR, #bit7           ; Set implied seek bit
        STRB    LR, [R7, #FlpDCBcdb+1]  ; Write drive/head data
        MOV     LR, #0                  ; Track required
        STRB    LR, [R7, #FlpDCBtrack]  ; Save in DCB

; Wait for DCB to be processed

        MOV     R1, R7                  ; R1->DCB
        BL      FlpAddDCB               ; Add DCB to queue (R1->R0,V)
20      LDR     R0, [R1, #FlpDCBstatus] ; Get command error
        CMPS    R0, #FlpDCBpending      ; DCB still pending?
        BEQ     %BT20                   ; Yes then loop

        TEQS    R0, #0                  ; Any errors
        BEQ     %FT30                   ; No then jump

; ReadID failed, determine type of disk error, R0= error code

22      TEQS    R0, #0                  ; An error?
        BLNE    FlpADFSerror            ; Yes then map error (R1,R2->R0)
        CMPS    R0, #FlpErrSoft         ; Soft error?
        BLO     %FT99                   ; No then jump - fatal error

; Check for more formats to try

25      LDRB    R0, [R8], #1            ; Next CCR, R8++
        LDRB    LR, [R8], #1            ; Get FileCore density
        CMPS    R0, #&FF                ; All densities exhausted
        STRNEB  LR, [R5, #Density]      ; Update density
        BNE     %BT05                   ; No then try again

        MOV     R0, #BadDiscErr         ; Else bad disc error (unformatted)
        B       %FT99                   ; Return error

; Disk format found, construct drive record

30
 [ Debug10
        LDRB    lr, [r5, #Density]
        BREG    lr,"Density which worked:"
 ]
        LDR     LR, [R1, #FlpDCBbuffer] ; Get end of buffer address
        LDR     R1, [LR, #-4]           ; Get last ID
        SUB     LR, LR, sp              ; Bytes read
        MOV     R0, LR, LSR #2          ; /4 to get sectors
        LDR     LR, [sp]                ; Get 1st ID
        TEQS    R1, LR                  ; Identical?
        SUBEQ   R0, R0, #1              ; Yes discount last ID read during IP
        STRB    R0, [R5, #SecsPerTrk]   ; Write sectors per track

        MOV     R0, sp
        BL      DetermineTrackParameters

; Perform any data read requested

        LDR     r4, [sp, #MountBufferSize + 3*4]
        TEQS    R4, #0                  ; Any data to read?
        MOVEQ   R0, #DiscOp_Verify      ; No, then verify
        ANDEQ   r2, r2, #&e0000000      ; Mask off to give 1st sector on disc
        LDREQB  lr, [r5, #SectorSize]
        MOVEQ   r4, #1
        MOVEQ   r4, r4, ASL lr          ; 1xSector
        MOVNE   R0, #DiscOp_ReadSecs    ; Yes, request read of sectors

        MOV     R1, R7                  ; R1->DCB
        sbaddr  R6, FlpFgScatter        ; Scatter list
        STMIA   R6, {R3,R4}             ; And set it up
        MOV     R3, R6                  ; R3-> scatter list
        BL      FlpBuildDCB             ; (R0-R5->R0,V) Build a DCB
        BVS     %FT99                   ; Jump if error

        LDRB    R0, FloppyMountRetries  ; Get mount retries
        STRB    R0, [R1, #FlpDCBretries] ; Write retries

; Submit DCB for processing
 [ Debug10
        DLINE   "Add DCB for processing"
 ]

        BL      FlpAddDCB               ; Add DCB to queue (R1->R0,V)
70      LDR     R0, [R1, #FlpDCBstatus] ; Get command error
        CMPS    R0, #FlpDCBpending      ; DCB still pending?
        BEQ     %BT70                   ; Yes then loop
 [ Debug10
        DREG    r0,"DCB finished with status "
 ]

 [ NewErrors
        CMPS    R0, #256
        TSTHSS  R0, #NewDiscErrorBit    ; Disk error?
 |
        TSTS    R0, #DiscErrorBit       ; Disk error?
 ]
        LDRNE   R3, FlpFgScatter        ; Yes, restore buffer address
        BNE     %BT22                   ; And jump, try more formats

; Return any errors to FileCore, R0= error

99      BL      SetVOnR0                ; Any error?

        ADD     sp, sp, #MountBufferSize

 [ Debug10
        BVC     %FT97
        DREG    R0, "!!ERROR!! in FlpMount: "
97
 ]
        Pull    "R1-R4,R6-R8,PC"


; ========================
; DetermineTrackParameters
; ========================

; entry
; R0->Sector ID list
; R5->disc record (SecsPerTrk is size of ID list)
;
; exit
; LowSector, SectorSize, SecsPerTrk, RootDir, DiscSize set
;
; LowSector = lowest numbered sector on track (sequence sides set if 16x256 byte sectors per track)
; SectorSize = size of that sector (Log2 of course)
; SecsPerTrk = number of sectors that size
; RootDir = L_Root on 16x256 byte sectors on a track, else D_Root
; DiscSize similarly set
; Heads = 1 when 16x256 byte sectors, 2 otherwise
;
; Can't use raw SecsPerTrk as this may include some 'protection' sectors.
; It is assumed that protection sector IDs come after LowSector.
;

DetermineTrackParameters ROUT
        Push    "r1-r4,r6,lr"

        ; Find the lowest sector number and its size

        LDRB    r1, [r5, #SecsPerTrk]
        MOV     r2, #&FF                ; Min sector number
        MOV     r3, r0

10
 [ Debug1 :LOR: Debug1f
        Push    "r0"
        LDR     r0, [r3]
        DREG    r0, ",",cc
        Pull    "r0"
 ]
        LDRB    lr, [r3, #2]            ; Sector ID
        CMP     lr, r2
        MOVLO   r2, lr
        LDRLOB  r4, [r3, #3]            ; Sector size
        ADD     r3, r3, #4
        SUBS    R1, R1, #1
        BHI     %BT10
 [ Debug1 :LOR: Debug1f
        DLINE   ""
 ]

        ; r2 = lowsector
        ; r4 = sectorsize as read off the disc

        ; From SectorSize determine SecsPerTrk.

        MOV     r6, r2                  ; which sector number to find next
15
        LDRB    r1, [r5, #SecsPerTrk]
        MOV     r3, r0
20
        LDRB    lr, [r3, #3]            ; Sector Size
        TEQ     lr, r4
        LDREQB  lr, [r3, #2]            ; Sector ID
        TEQEQ   lr, r6
        ADDEQ   r6, r6, #1              ; Found so find next sector
        BEQ     %BT15
        ADD     r3, r3, #4
        SUBS    R1, R1, #1
        BHI     %BT20

        SUB     r6, r6, r2              ; convert to number of that size

        ; Store away SectorSize and SecsPerTrk
        ADD     r4, r4, #7              ; Convert to LOG2
        STRB    r4, [r5, #SectorSize]
        STRB    r6, [r5, #SecsPerTrk]

 [ Debug1 :LOR: Debug1f
        DREG    r6, "SPT: ",cc
        DREG    r4, " SectorSize: ", cc
        LDRB    LR, [r5, #Density]
        DREG    LR, " Density: ",cc
        DREG    r2, " LowSector: "
 ]
; Test for ADFS L format

        TEQ     r4, #8                  ; IF 256 byte sectors?
        TEQEQ   r6, #16                 ; AND 16 sectors per track?
        LDREQB  lr, [r5, #Density]
        TEQEQ   lr, #Double             ; AND double density?

        MOVEQ   lr, #1                  ; THEN Heads=1 rather than 2
        MOVNE   lr, #2
        STRB    lr, [r5, #Heads]

        ORREQ   r2, r2, #bit6           ; AND set sequence sides when storing LowSector
        STRB    r2, [r5, #LowSector]

        MOVEQ   lr, #L_Root             ; AND set L_Root rather than D_Root
        MOVNE   lr, #D_Root
        STR     lr, [r5, #RootDir]

        MOVEQ   lr, #L_Size             ; AND set L_Size rather than D_Size
        MOVNE   lr, #D_Size
        STR     lr, [r5, #DiscSize]
 [ BigDisc
        MOV     lr, #0
        STR     lr, [r5, #DiscSize2]
 ]

        Pull    "r1-r4,r6,pc"


;-----------------------------------------------------------------------;
; DoPollChanged                                                         ;
;       Invoked when the module receives a FileCore miscellaneous call  ;
;       with a reason code of 1 (R0 = 1, poll changed).                 ;
;                                                                       ;
; Input:                                                                ;
;       R0 = 1                                                          ;
;       R1 = drive                                                      ;
;       R2 = sequence no.                                               ;
;       R12 = SB                                                        ;
;       LR = Return address                                             ;
;                                                                       ;
; Output:                                                               ;
;       R2 = New sequence no. if disk changed                           ;
;       R3 = Change state                                               ;
;            b0 = not changed                                           ;
;            b1 = maybe changed                                         ;
;            b2 = changed                                               ;
;            b3 = empty                                                 ;
;            b6 = empty works                                           ;
;            b7 = changed works                                         ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
DoPollChanged   ROUT
        TSTS    R1, #4                  ; Winchester? (drives 4+)
        MOVNE   R2, #0                  ; Yes then sequence=0
        MOVNE   R3, #MiscOp_PollChanged_EmptyWorks_Flag :OR: MiscOp_PollChanged_ChangedWorks_Flag :OR: MiscOp_PollChanged_NotChanged_Flag
        MOVNE   PC, LR                  ; Return if winchester

; Determine floppy driver type

        LDR     R3, MachineID           ; Get machine type
 [ Support1772
        CMPS    R3, #MachHas1772        ; 1772 present?
        BEQ     OldDoPollChanged        ; Yes, then poll disk changed with 1772 H/W
 ]

        CMPS    R3, #MachHas82710       ; 82C710 FDC?
        MOVNE   R3, #MiscOp_PollChanged_EmptyWorks_Flag :OR: MiscOp_PollChanged_ChangedWorks_Flag :OR: MiscOp_PollChanged_NotChanged_Flag
        MOVNE   PC, LR                  ; No, return

; Poll changed with '765 FDC

 [ Debug10
        DREG    R1,"DoPollChanged, R1-R2: ",cc
        DREG    R2, " "
 ]

; Check for any logged drives.  This shouldn't be necessary but FileCore
; still calls this entry even if 0 drives are reported

        LDRB    R3, Floppies            ; Get drives found
        TEQS    R3, #0                  ; No drives?
        MOVEQ   R3, #MiscOp_PollChanged_EmptyWorks_Flag :OR: MiscOp_PollChanged_ChangedWorks_Flag :OR: MiscOp_PollChanged_NotChanged_Flag
        MOVEQ   PC, LR                  ; And exit

        Push    "R0,R1,R4,LR"
        sbaddr  LR, FlpDrvMap
        LDRB    R1, [LR, R1]            ; Map logical to physical drive
        DrvRecPtr R4, R1                ; R4-> drive record

; Check for sequence out of order

        LDR     R0, [R4, #DrvSequenceNum]
        TEQS    R0, R2                  ; Sequence same?
        BEQ     %FT05                   ; Yes
        MOV     R2, R0                  ; No, use new seq. number
        LDR     R3, [R4, #DrvFlags]     ; And get drive flags
        BIC     R3, R3, #MiscOp_PollChanged_Empty_Flag+MiscOp_PollChanged_MaybeChanged_Flag+MiscOp_PollChanged_NotChanged_Flag
        TST     R3, #MiscOp_PollChanged_ChangedWorks_Flag
        ORRNE   R3, R3, #MiscOp_PollChanged_Changed_Flag    ; And set changed
        ORREQ   R3, R3, #MiscOp_PollChanged_MaybeChanged_Flag
        B       %FT30                   ; And jump

05

; Quick exit if drive busy

        LDR     R0, FlpDCBqueue         ; Get queue status
        TEQS    R0, #0                  ; Idle?
        LDRNE   R3, [R4, #DrvFlags]     ;   Yes just read drive flags
        BNE     %FT20                   ;   And jump

; Drive idle so construct a drive status DCB

 [ {TRUE}
        SUB     sp, sp, #FlpDCBsize
        MOV     R3, sp
 |
        sbaddr  R3, FlpDCB              ; R3-> DCB for drive status
 ]
        MOV     LR, #0                  ; No data
        STR     LR, [R3, #FlpDCBpost]   ; No post routine
        STRB    LR, [R3, #FlpDCBretries] ; No retries

        MOV     LR, #FlpCmdTimeOut      ; Command timeout
        STRB    LR, [R3, #FlpDCBtimeOut] ; Set DCB timeout

        MOV     LR, #FlpCmdSenseDrv     ; Drive status command code
        STRB    LR, [R3, #FlpDCBcdb]    ; Write command
        ORR     LR, R1, #bit7           ; Set implied seek bit to request DskChng status
        STRB    LR, [R3, #FlpDCBcdb+1]  ; Write drive/head data

        MOV     LR, #2                  ; 2 byte command
        STRB    LR, [R3, #FlpDCBcmdLen] ; Write command length

; Wait for drive status DCB to be processed

        MOV     R1, R3                  ; R1->DCB
        BL      FlpAddDCB               ; Add DCB to queue (R1->R0,V)
10      LDR     R0, [R1, #FlpDCBstatus] ; Get command error
        CMPS    R0, #FlpDCBpending      ; DCB still pending?
        BEQ     %BT10                   ; Yes then loop

        LDR     R3, [R1, #FlpDCBresults+4] ; Get drive status
 [ {TRUE}
        ADD     sp, sp, #FlpDCBsize
 ]
20      TSTS    R3, #MiscOp_PollChanged_MaybeChanged_Flag + MiscOp_PollChanged_Changed_Flag ; Change detected
        ADDNE   R2, R2, #1              ; Yes then bump sequence no.
        STRNE   R2, [R4, #DrvSequenceNum] ;  and save it

30
 [ Debug10
        TSTS    R3, #MiscOp_PollChanged_Empty_Flag+MiscOp_PollChanged_Changed_Flag+MiscOp_PollChanged_MaybeChanged_Flag
        BEQ     %FT900
        DREG    R2," Change: ",cc
        DREG    R3," "
900
 ]
        Pull    "R0,R1,R4,PC"           ; Return


;-----------------------------------------------------------------------;
; DoLockDrive                                                           ;
;       Invoked when the module receives a FileCore miscellaneous call  ;
;       with a reason code of R0 = 2, (lock drive).                     ;
;                                                                       ;
; Input:                                                                ;
;       R0 = 2                                                          ;
;       R1 = drive                                                      ;
;       R12 = SB                                                        ;
;       LR = Return address                                             ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
DoLockDrive     ROUT
        Push    "R0,R1,LR"
 [ Debug10
        DREG    R1,"DoLockDrive, R1: "
 ]

; Determine floppy driver type

        LDR     R0, MachineID           ; Get machine type
 [ Support1772
        CMPS    R0, #MachHas1772        ; 1772 FDC?
        Pull    "R0,R1,LR",EQ
        BEQ     OldDoLockDrive          ; Yes, do motor on with 1772 H/W
 ]

        CMPS    R0, #MachHas82710       ; 82C710 FDC?
        Pull    "R0,R1,PC",NE           ; No, then exit

; Lock drive with '765 controller

     [ No32bitCode
        ORR     LR, LR, #I_bit
        TEQP    LR, #0                  ; Disable IRQ's
     |
        Push    "R2"
        MRS     R2, CPSR
        ORR     LR, R2, #I32_bit
        MSR     CPSR_c, LR
     ]

        LDRB    LR, FlpDriveLock        ; Get lock status
        ORR     LR, LR, #bit1           ; Set lock
        STRB    LR, FlpDriveLock        ; Disable drive timeout

        sbaddr  LR, FlpDrvMap
        LDRB    R1, [LR, R1]            ; Map logical to physical drive
        MOV     R0, #FlpEventDrvSel     ; Drive select event (R1= drive)
        MOV     LR, PC
        LDR     PC, FlpDrive            ; Call drive state system (R0,R1->V)

     [ :LNOT:No32bitCode
        MSR     CPSR_c, R2
        Pull    "R2"
     ]

        Pull    "R0,R1,PC"


;-----------------------------------------------------------------------;
; DoUnlockDrive                                                         ;
;       Invoked when the module receives a FileCore miscellaneous call  ;
;       with a reason code of R0 = 3, (unlock drive).                   ;
;                                                                       ;
; Input:                                                                ;
;       R0 = 3                                                          ;
;       R1 = drive                                                      ;
;       R12 = SB                                                        ;
;       LR = Return address                                             ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
DoUnlockDrive   ROUT
        Push    "R0,R1,LR"
 [ Debug10
        DREG    R1,"DoUnLockDrive, R1: "
 ]

; Determine floppy driver type

        LDR     R0, MachineID           ; Get machine type
 [ Support1772
        CMPS    R0, #MachHas1772        ; 1772 FDC?
        Pull    "R0,R1,LR",EQ
        BEQ     OldDoUnlockDrive        ; No, allow motor off with 1772 H/W
 ]

        CMPS    R0, #MachHas82710       ; 82C710 FDC?
        Pull    "R0,R1,PC",NE           ; No, then exit

; UnLock drive with '765 controller

     [ No32bitCode
        ORR     LR, LR, #I_bit
        TEQP    LR, #0                  ; Disable IRQ's
     |
        Push    "R2"
        MRS     R2, CPSR
        ORR     LR, R2, #I32_bit
        MSR     CPSR_c, LR
     ]

        LDRB    LR, FlpDriveLock        ; Get lock status
        BIC     LR, LR, #bit1           ; Reset lock
        STRB    LR, FlpDriveLock        ; Enable drive timeout

        sbaddr  LR, FlpDrvMap
        LDRB    R1, [LR, R1]            ; Map logical to physical drive
        MOV     R0, #FlpEventDrvSel     ; Drive select event (R1= drive)
        MOV     LR, PC
        LDR     PC, FlpDrive            ; Call drive state system (R0,R1->V)

     [ :LNOT:No32bitCode
        MSR     CPSR_c, R2
        Pull    "R2"
     ]

        Pull    "R0,R1,PC"


        END
