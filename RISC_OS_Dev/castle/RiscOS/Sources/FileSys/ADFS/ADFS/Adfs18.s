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
;>Adfs18
        SUBT    82C710/'765 FDC FileCore Interface
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
; 01  11 Dec 90  lrust  Conception                                      ;
; 02  08 Mar 91  lrust  Alpha version                                   ;
; 03  15 Mar 91  lrust  RiscOS 2.09 release                             ;
;                       Added FlpMediaCheck assembler switch            ;
; 04  22 Mar 91  lrust  Drive Status turns off drive if drive wasn't    ;
;                       ready when started.                             ;
; 05  26 Mar 91  lrust  Drive status delays turning off empty drives to ;
;                       speed next poll changed request.                ;
; 06  28 May 91  lrust  Fixed bug in drive status processing            ;
; 07  09 Aug 91  jroach Fix the data transfer FIQ routines to not       ;
;                       suffer chronic latency problems and do the      ;
;                       scatter lists properly                          ;
; 08  17 Sep 91  lrust  Sector not found errors on side 1 are retried   ;
;                       with sector ID head number set to 0 for DFS and ;
;                       some protected discs (ZARCH,LOGO etc.)          ;
; 09  05 Feb 92  lrust  ReadID terminated by timeout returns FlpErrNoIDs;
;                       This allows 'PacMania' and other discs to be    ;
;                       mounted since the FDC hangs!! when attemping a  ;
;                       ReadID @ 500Kb on these media?? The new error is;
;                       non-fatal to allow further densities to be tried;
; 10  27 Feb 96  MJS    StrongARM changes for modifying code            ;
;_______________________________________________________________________;
;
Adfs18Ed        * 10            ; Edition number

;-----------------------------------------------------------------------;
; This file provides the support routines for the Disk Control Block    ;
; (DCB) messaging system.  The following routines are included:         ;
;                                                                       ;
;       FlpMessage      - Send message to current DCB                   ;
;       FlpHandlerData  - Handle messages for data transfer type DCB's  ;
;       FlpHandlerReadID - Handle messages for ReadID command           ;
;       FlpHandlerSeek  - Handle messages for seek/restore DCB's        ;
;       FlpHandlerDrv   - Handle messages for sense drive status DCB    ;
;       FlpGetDrvStatus - Gets drive status and handles disk change     ;
;       FlpHandlerImm   - Handle messages for immediate type DCB's      ;
;       FlpAddDCB       - Add a DCB to the active queue                 ;
;       FlpDqDCB        - Terminate a DCB and de-queue it               ;
;_______________________________________________________________________;


; DCB structure
;--------------
        ^ 0
FlpDCBbuffer    a4 4            ; Data buffer pointer
FlpDCBlength    a4 4            ; Data buffer size, bit31= read, bit30= scatter list
FlpDCBsb        a4 4            ; R12 for post routine
FlpDCBpost      a4 4            ; -> post routine (called on command completion)
FlpDCBstatus    a4 4            ; -1= pending, 0= no error else error code
FlpDCBpending   * -1            ; DCB pending
FlpDCBesc       # 1             ; Escape inhibit flag
FlpDCBtimeOut   # 1             ; Command timeout in centiseconds, 0= none
FlpDCBretries   # 1             ; Retries, 0= none
FlpDCBselect    # 1             ; Clock: 00=500K, 01=300K, 10=250K, 11=1000K
FlpDCBtrack     # 1             ; Track required
FlpDCBcmdLen    # 1             ; Command block length: 1..10 bytes, bit7= immediate
FlpDCBcdb       # 2             ; Command block
                                ; Offset 0= command byte
                                ; Offset 1= drive select, b7= implied seek
FlpDCBparam     a4 8            ; Offset 2..9 variable, offset9= &FF for verify
FlpDCBresults   a4 8            ; Result block

; flags in FlpDCBlength
FlpDCBread        * bit31
FlpDCBscatter     * bit30
FlpDCBflags       * bit31+bit30

;
; The following locations are reserved for driver use only
;
FlpDCBlink      a4 4            ; -> next DCB
FlpDCBhandler   a4 4            ; -> message handler for this command
FlpDCBphase     # 1             ; Current command phase
FlpDCBbgnd      # 1             ; non-zero if backgrounding transfer op
                # 2             ; Spare, align to word boundary
FlpDCBtxbytes   a4 4            ; location which accumulates number of bytes transfered (for use by client)
FlpDCBtxgobytes a4 4            ; initial txbytes in each step (for use by driver)
 ASSERT  {VAR} = FlpDCBsize     ; Total size 64 bytes


; Message types
;--------------
;
 ASSERT FlpEventIRQ = 1                 ; IRQ event == IRQ message
FlpMsgIP        * 2                     ; Drive ready index pulse
FlpMsgSeekDone  * 3                     ; Seek complete
FlpMsgError     * 4                     ; Command error
FlpMsgESC       * 5                     ; Escape message
FlpMsgStart     * 6                     ; Start command
FlpMsgResetOK   * 7                     ; FDC reset complete

; Driver error codes
;
        MACRO
$label  DrvErr  $num
        ASSERT  $num > 0
        ASSERT  $num <= MaxDiscErr
 [ NewErrors
$label  * $num
 |
$label  * DiscErrorBit + $num :SHL: 24
 ]
        MEND

; Prioritized controller errors
;
 [ NewErrors
FlpDiscError    *      DiscErr
 |
FlpDiscError    *      DiscErrorBit
 ]

; Fatal errors
;
FlpErrFDC       DrvErr &01              ; FDC H/W error
FlpErrTimeOut   DrvErr &02              ; Command timed out
FlpErrTrk0Fault DrvErr &03              ; Track 0 not found

; Critical errors
;
FlpErrSeekFault DrvErr &10              ; Seek fault
FlpErrDskChng   DrvErr &11              ; Disk changed

; Recoverable errors
;
FlpErrSoft      DrvErr &20              ; Non specific FDC error, see ST1/2
FlpErrLost      DrvErr &21              ; Data over/underrun
FlpErrCRC       DrvErr &22              ; Data CRC error
FlpErrNotFound  DrvErr &23              ; Sector or ID not found
FlpErrNoAM      DrvErr &24              ; Missing address mark
FlpErrNoIDs     DrvErr &25              ; Can't read sector ID's


; DCB command phases
;
FlpPhaseIdle    * 0                     ; DCB inactive
FlpPhaseDrv     * 1                     ; DCB awaiting drive ready
FlpPhaseSeek    * 2                     ; DCB awaiting seek done
FlpPhaseIRQ     * 3                     ; DCB awaiting IRQ
FlpPhaseReset   * 4                     ; DCB awaiting reset complete
FlpPhaseIP      * 5                     ; DCB awaiting index pulse
FlpPhaseIRQip   * 6                     ; DCB awaiting IRQ or index
FlpPhaseDone    * 7                     ; DCB complete
FlpPhaseRetry   * 8                     ; DCB reseeking during retry


;-----------------------------------------------------------------------;
; DCB Message system                                                    ;
;       Messages are sent to the current head of the DCB queue          ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Message                                                    ;
;       R1 = Parameter                                                  ;
;       R12 -> Local storage                                            ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpMessage      ROUT
        Push    "R2,LR"
        LDR     R2, FlpDCBqueue         ; Get start of DCB queue
        TEQS    R2, #0                  ; Any DCB's?
        MOVNE   LR, PC                  ; Yes then set return address
        LDRNE   PC, [R2, #FlpDCBhandler] ;   and call handler (R0-R2->)
        Pull    "R2,PC"                 ; Return

 [ Debug10v
SlowDownFactor * 10
 ]

 [ FloppyPCI
FlpDMAEnable
FlpDMADisable
FlpDMAStart
FlpDMASync
        MOV     PC, R14

FlpDMACompleted
        Push    "R14"
  [ Debug10d
        DLINE   "FlpDMACompleted (V ",cc
        BVS     %FT01
        DLINE   "clear)"
        B       %FT02
01
        DLINE   "set)"
02
  ]
        MOV     R14, #-1
        STR     R14, FlpDMATag
        LDRVC   R14, [r11, #FlpDCBtxgobytes]
        STRVC   R14, FlpDMACount
        Pull    "PC"
 |

;=======================================================================;
;                                                                       ;
;                                                                       ;
;                                                                       ;
;                                                                       ;
;                    F I Q   r o u t i n e s                            ;
;                                                                       ;
;                                                                       ;
;                                                                       ;
;                                                                       ;
;=======================================================================;

; The routines have a special copy routine to patch them up when
; they're copied into place.
;
; The 0 word terminating the code will have txcount's address patched into
; it.
; The word before the terminator will have FlpDCBbuffer put there.

;-----------------------------------------------------------------------;
; FlpVerifyFIQ                                                          ;
;       Verify data FIQ routine                                         ;
;                                                                       ;
; Input:                                                                ;
;  R9=temp reg                                                          ;
;  R11=bytes to TC                                                      ;
;  R12=bytes left                                                       ;
;  R13=DMA (bytes left>1) +TC(bytes left=1)                             ;
;                                                                       ;
; Output:                                                               ;
;       R12 -= 1                                                        ;
;                                                                       ;
; Modifies:                                                             ;
;       R8, R14, preserves flags                                        ;
;_______________________________________________________________________;
;
FlpVerifyFIQ    ROUT
 [ Debug10v
        STR     lr, %FT11
        MOV     lr, #SlowDownFactor
10
        STR     lr, %FT12
        SUBS    lr, lr, #1
        BNE     %BT10
        B       %FT20
11
        DCD     10
12
        DCD     10
20
        LDR     lr, %BT11
 ]
      [ FlpUseVerify
        MOV     R12, #0                 ; We should never get here
        ADD     R9, R13, #FlpDACK_TC_Offset
        LDRB    R9, [R9]                ; Try a terminal count? Can't hurt!
      |
        LDRB    R9, [R13]
        SUB     R12, R12, #1
        SUBS    R11, R11, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset
      ]
        retfiq
        DCD     1                       ; Where FlpDCBbuffer will be put
        DCD     0                       ; End of FIQ routine
        DCD     0                       ; End of instructions needing 1 x sector size
        DCD     0                       ; End of instructions needing 2 x sector size

;-----------------------------------------------------------------------;
; FlpReadNonScatter                                                     ;
;         Read data FIQ routine                                         ;
;                                                                       ;
; Input:                                                                ;
 [ FlpUseFIFO
; Input:
;   R8 = destination
;   R9 = temp
;   R10 = -
;   R11 = bytes to TC
;   R12 = bytes to end of transfer
;   R13 = DACK or DACK_TC
 |
;  R9=temp reg                                                          ;
;  R10=bytes left-1                                                     ;
;  R13=DMA (bytes left>1) +TC(bytes left=1)                             ;
;                                                                       ;
; Output:                                                               ;
;       R12 += 4                                                        ;
 ]
;                                                                       ;
; Modifies:                                                             ;
;       R8, R14, preserves flags                                        ;
;_______________________________________________________________________;
;
FlpReadNonScatter       ROUT
 [ Debug10v
        STR     lr, %FT11
        MOV     lr, #SlowDownFactor
10
        STR     lr, %FT12
        SUBS    lr, lr, #1
        BNE     %BT10
        B       %FT20
11
        DCD     10
12
        DCD     10
20
        LDR     lr, %BT11
 ]
 [ FlpUseFIFO
        LDRB    R9, [R13]
        SUBS    R11, R11, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset
        SUBS    R12, R12, #1
        STRGEB  R9, [R8], #1
        retfiq
 |
        LDRB    R9, [R13]
        STRB    R9, [R8], #1
        SUBS    R10, R10, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset
        retfiq
 ]
        DCD     1               ; Where FlpDCBbuffer will be put
        DCD     0
        DCD     0
        DCD     0

;-----------------------------------------------------------------------;
; FlpReadFIQ_FG                                                         ;
;       Read data FIQ routine                                           ;
;                                                                       ;
; Input:                                                                ;
 [ FlpUseFIFO
;       R8 = RAM destination                                            ;
;       R9 = temp                                                       ;
;       R10 = bytes left to scatter entry's end                         ;
;       R11 = bytes left to switch to DACK_TC (ie bytes left-1)         ;
;       R12 = bytes left to end of transfer to RAM                      ;
;       R13 = DACK or DACK_TC                                           ;
;                                                                       ;
; Output:                                                               ;
;       counts decremented and R13 might be DACK_TC                     ;
 |
;       CPU in FIQ mode                                                 ;
;       R8 ->  data destination                                         ;
;       R9 =   temporary data register                                  ;
;       R10 =  amount remaining in this scatter entry                   ;
;       R11 -> next scatter list entry                                  ;
;       R12=bytes left in transfer-1                                    ;
;       R13=DMA(bytes left>1) +TC(bytes left=1)                         ;
;                                                                       ;
; Output:                                                               ;
;       More to go:                                                     ;
;       R8 advanced to next destination                                 ;
;       R9 trashed                                                      ;
;       R10-- or length of new scatter entry as appropriate             ;
;       R11 unchanged or advanced to next scatter entry                 ;
;       R12--                                                           ;
;       R13 unchanged                                                   ;
;       Transfer was last                                               ;
;       R8++                                                            ;
;       R9 trashed                                                      ;
;       R10 = 0                                                         ;
;       R11 unchanged                                                   ;
;       R12 = 0                                                         ;
;       R13 unchanged                                                   ;
;       transfer stopped by asserting TC                                ;
 ]
;_______________________________________________________________________;
;
FlpReadFIQ_FG   ROUT
 [ Debug10v
        STR     lr, %FT11
        MOV     lr, #SlowDownFactor
10
        STR     lr, %FT12
        SUBS    lr, lr, #1
        BNE     %BT10
        B       %FT20
11
        DCD     10
12
        DCD     10
20
        LDR     lr, %BT11
 ]
 [ FlpUseFIFO
        LDRB    R9, [R13]
        SUBS    R11, R11, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset
        SUBS    R12, R12, #1
        STRGEB  R9, [R8], #1
        SUBS    R10, R10, #1
        retfiq  GT
        CMP     R12, #0
        LDRGT   R8, ReadNonScatterPtr
        ADDGT   R8, R8, #8
        STRGT   R8, ReadNonScatterPtr
        LDMGTIA R8, {R8,R10}
        retfiq
ReadNonScatterPtr
 |
        LDRB    R9, [R13]
        STRB    R9, [R8], #1
        SUBS    R12, R12, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset
        SUBS    R10, R10, #1
        retfiq  GT
        CMP     R12, #0
        LDMGEIA R11!, {R8,R10}
        retfiq
 ]
        DCD     1       ; Where FlpDCBbuffer will be put
        DCD     0       ; End of FIQ routine
        DCD     0       ; End of instructions needing SectorSize plugged in
        DCD     0       ; End of instructions needing 2 x sector size

;-----------------------------------------------------------------------;
; FlpReadFIQ_BG                                                         ;
;       Read data FIQ routine                                           ;
;                                                                       ;
;  well, actually it's for the '665 controller                          ;
; Input:                                                                ;
;       FIQ mode (FIQ pin asserted)                                     ;
;       R8 -> data destination                                          ;
;       R9 unused                                                       ;
;       R10 number of transfers to sector end                           ;
;       R11 number of transfers before switching to TC space            ;
;               Will be EOTrack or EOSector as appropriate              ;
;       R12 -> previous sector's scatter list entry                     ;
;               (=1 to indicate no previous sector)                     ;
;       R13 = FlpDACK or FlpDACK_TC as determined by R11 on             ;
;               previous FIQs                                           ;
;       FlpReadThisRover -> this sector's scatter list entry            ;
;                                                                       ;
; Output:                                                               ;
;       The byte gets transfered                                        ;
;       The above get advanced by one byte's worth                      ;
;_______________________________________________________________________;
;
FlpReadFIQ_BG   ROUT
 [ Debug10v
        STR     lr, %FT11
        MOV     lr, #SlowDownFactor
10
        STR     lr, %FT12
        SUBS    lr, lr, #1
        BNE     %BT10
        B       %FT20
11
        DCD     10
12
        DCD     10
20
        LDR     lr, %BT11
 ]

        ; Well, actually the '665
        ; The problem here is that late termination doesn't go on the '665, ho hum!
        ; So, how does it go:
        ; The idea is we've got big time gaps between sectors, so we use that to do
        ; the processing under FIQ. During a sector we do as little processing as possible.
        ; This involves counting down to TC which will only occur at the sector's end, and
        ; counting down to the sector's end itself.
        ; Once the sectors end has been reached we do this:
        ; * advance the previous sector (1)
        ; * advance txcount (1)
        ; * Find out where the next sector should be transfered to
        ; * Find out whether there's a sector after that waiting
        ; (1) These only happen if there was a previous sector and only happen for the
        ; previous sector and not this sector as just because we've picked a byte off the controller
        ; doesn't mean we haven't overrun or got a CRC error.

        ; Transfer the byte
        LDRB    R9, [R13]
        STRB    R9, [R8], #1

        ; Check for TC assertion next byte
        SUBS    R11, R11, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset

        ; Check for sector end
        SUBS    R10, R10, #1
        retfiq  GT

        ; Sector end reached

        ; Advance the prev sector (if there is a prev sector)
        ; Also advance txcount
        TEQ     R12, #1
        LDMNEIA R12, {R9,R10}
FlpReadFIQ_1xSectorSize1
        ADDNE   R9, R9, #&3FC0          ; 1xSectorSize
FlpReadFIQ_1xSectorSize2
        SUBNE   R10, R10, #&3FC0        ; 1xSectorSize
        STMNEIA R12, {R9,R10}
        LDRNE   R10, FlpReadFIQ_txcount
        LDRNE   R9, [R10]
FlpReadFIQ_1xSectorSize3
        ADDNE   R9, R9, #&3FC0          ; 1xSectorSize
        STRNE   R9, [R10]
        LDR     R12, FlpReadThisRover   ; This is next sector's prev thingy
                                        ; move on 1 sector's worth of scatter list

        ; Check if this was the TC transfer
        CMP     r11, #-1
        retfiq  EQ

        ; We haven't TCed the byte just transfered, hence there *is* a next sector

        ; Get this sector's scatter entry's address
        ; Need to determine:
        ; * next sector's start address
        ; * Whether there's more after the next sector

        ; Prepare standard goop for the next sector
FlpReadFIQ_1xSectorSize4
        MOV     R10, #&3FC0             ; 1xSectorSize

        LDR     R9, [R12, #4]
FlpReadFIQ_2xSectorSize1
        CMP     R9, #&3FC0              ; 2xSectorSize
        BLO     %FT50

        ; This sector's scatter entry has >= 2xSectorSize in it
        ; Hence: r8 is correct

        ; If This sector's scatter entry is > 2xSectorSize then
        ; there's definitely a sector after the next one and we
        ; can go for the next sector without any worries
        retfiq  HI

        ; This sector's entry has = 2xSectorSize hence we must check the next
        ; scatter entry for being present
        LDR     R9, [R12, #8]
 [ FixTBSAddrs
        CMN     R9, #ScatterListNegThresh
        ADDCS   R9, R12, R9
        LDRCS   R9, [R9, #8+4]
        LDRCC   R9, [R12, #8+4]
 |
        TEQ     R9, #0
        ADDMI   R9, R12, R9
        LDRMI   R9, [R9, #8+4]
        LDRPL   R9, [R12, #8+4]
 ]
20
        TEQ     R9, #0
        SUBEQ   R11, R10, #1            ; Terminate on last byte of next sector
        retfiq

50
        ; This scatter entry has 1xSectorSize in it, hence r8 is wrong
        ADD     R10, R12, #8
        LDR     R8, [R10]
 [ FixTBSAddrs
        CMN     R8, #ScatterListNegThresh
        LDRCS   R8, [R10, R8]!
 |
        TEQ     R8, #0
        LDRMI   R8, [R10, R8]!
 ]
        STR     R10, FlpReadThisRover
        LDR     R9, [R10, #4]
FlpReadFIQ_1xSectorSize5
        CMP     R9, #&3FC0              ; 1xSectorSize
FlpReadFIQ_1xSectorSize7
        MOVHI   R10, #&3FC0             ; 1xSectorSize
        retfiq  HI
        LDR     R9, [R10, #8]!
 [ FixTBSAddrs
        CMN     R9, #ScatterListNegThresh
        ADDCS   R10, R10, R9
 |
        TEQ     R9, #0
        ADDMI   R10, R10, R9
 ]
        LDR     R9, [R10, #4]
FlpReadFIQ_1xSectorSize6
        MOV     R10, #&3FC0             ; 1xSectorSize
        B       %BT20

FlpReadThisRover DCD 1  ; Where FlpDCBbuffer will be put
FlpReadFIQ_txcount
        DCD     0       ; End of FIQ routine
  [ {PC}-FlpReadFIQ_BG + FiqVector > FlpFiqStackBase
        ! 0,"Fiq overflow by ":CC::STR:(({PC}-FlpReadFIQ_BG + FiqVector) - FlpFiqStackBase)
  ]
        ASSERT  {PC}-FlpReadFIQ_BG + FiqVector <= FlpFiqStackBase

; List of locations needing 1xSectorSize plugged into instruction
        DCD     FlpReadFIQ_1xSectorSize1 - FlpReadFIQ_BG + FiqVector
        DCD     FlpReadFIQ_1xSectorSize2 - FlpReadFIQ_BG + FiqVector
        DCD     FlpReadFIQ_1xSectorSize3 - FlpReadFIQ_BG + FiqVector
        DCD     FlpReadFIQ_1xSectorSize4 - FlpReadFIQ_BG + FiqVector
        DCD     FlpReadFIQ_1xSectorSize5 - FlpReadFIQ_BG + FiqVector
        DCD     FlpReadFIQ_1xSectorSize6 - FlpReadFIQ_BG + FiqVector
        DCD     FlpReadFIQ_1xSectorSize7 - FlpReadFIQ_BG + FiqVector
        DCD     0

; List of locations needing 2xSectorSize plugged into instruction
        DCD     FlpReadFIQ_2xSectorSize1 - FlpReadFIQ_BG + FiqVector
        DCD     0       ; End of instructions needing 2 x sector size

; --------------------------------------------------------------;
; FlpWriteNonScatter                                            ;
;       Write data (non scatter) FIQ routine                    ;
;                                                               ;
 [ FlpUseFIFO
; Input:                                                        ;
;       R8 = RAM source                                         ;
;       R9 = byte for transfer                                  ;
;       R10 = -                                                 ;
;       R11 = bytes to TC                                       ;
;       R12 = bytes to end of transfer                          ;
;       R13 = DACK or DACK_TC                                   ;
; Output:                                                       ;
;       byte transfered                                         ;
;       counts decremented                                      ;
;       R13 may be switched to DACK_TC                          ;
 |
;                                                               ;
; In                                                            ;
; R8=RAM source                                                 ;
; R9=byte for transfer                                          ;
; R10=bytes left-1                                              ;
; R13=DMA(bytes left>1) +TC(bytes left=1)                       ;
 ]
;---------------------------------------------------------------;

FlpWriteNonScatter ROUT
 [ Debug10v
        STR     lr, %FT11
        MOV     lr, #SlowDownFactor
10
        STR     lr, %FT12
        SUBS    lr, lr, #1
        BNE     %BT10
        B       %FT20
11
        DCD     10
12
        DCD     10
20
        LDR     lr, %BT11
 ]
 [ FlpUseFIFO
        STRB    R9, [R13]
      [ FlpFlushPBI
        LDRB    R9, [R13, #4]
      ]
        SUBS    R11, R11, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset
        SUBS    R12, R12, #1
        LDRGTB  R9, [R8], #1
        MOVLE   R9, #0
        retfiq
 |
        STRB    R9, [R13]
      [ FlpFlushPBI
        LDRB    R9, [R13, #4]
      ]
        SUBS    R10, R10, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset
        LDRGE   R9, [R8], #1
        retfiq
 ]
        DCD     1       ; Where FlpDCBbuffer will be put
        DCD     0
        DCD     0
        DCD     0

;-----------------------------------------------------------------------;
; FlpWriteFIQ_FG                                                        ;
;       Write data FIQ routine                                          ;
;                                                                       ;
 [ FlpUseFIFO
;       R8 = RAM source                                                 ;
;       R9 = byte to transfer                                           ;
;       R10 = bytes left to scatter entry's end                         ;
;       R11 = bytes left to switch to DACK_TC (ie bytes left-1)         ;
;       R12 = bytes left to end of transfer to RAM                      ;
;       R13 = DACK or DACK_TC                                           ;
;                                                                       ;
; Output:                                                               ;
;       counts decremented and R13 might be DACK_TC                     ;
 |
; Input:                                                                ;
;       CPU in FIQ mode                                                 ;
;       R8 ->  (source address for R9)+1                                ;
;       R9 =   data ready to transfer to controller                     ;
;       R10 =  amount remaining in this scatter entry                   ;
;       R11 -> next scatter list entry                                  ;
;       R12=bytes left-1                                                ;
;       R13=DMA (bytes left>1) +TC(bytes left=1)                        ;
;                                                                       ;
; Output:                                                               ;
;       More to go:                                                     ;
;       R8 advanced to next destination                                 ;
;       R9 data ready for next transfer to controller                   ;
;       R10-- or length of new scatter entry as appropriate             ;
;       R11 unchanged or advanced to next scatter entry                 ;
;       R12--                                                           ;
;       R13 unchanged                                                   ;
;       Transfer was last                                               ;
;       R8++                                                            ;
;       R9 trashed                                                      ;
;       R10 = 0                                                         ;
;       R11 unchanged                                                   ;
;       R12 = 0                                                         ;
;       R13 unchanged                                                   ;
;       transfer stopped by asserting TC                                ;
 ]
;_______________________________________________________________________;
;
FlpWriteFIQ_FG  ROUT
 [ Debug10v
        STR     lr, %FT11
        MOV     lr, #SlowDownFactor
10
        STR     lr, %FT12
        SUBS    lr, lr, #1
        BNE     %BT10
        B       %FT20
11
        DCD     10
12
        DCD     10
20
        LDR     lr, %BT11
 ]
 [ FlpUseFIFO
        STRB    R9, [R13]
      [ FlpFlushPBI
        LDRB    R9, [R13, #4]
      ]
        SUBS    R11, R11, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset
        SUBS    R12, R12, #1
        LDRGTB  R9, [R8], #1
        MOVLE   R9, #0
        SUBS    R10, R10, #1
        retfiq  GT
        CMP     R12, #1
        LDRGT   R8, WriteNonScatterPtr
        ADDGT   R8, R8, #8
        STRGT   R8, WriteNonScatterPtr
        LDMGTIA R8, {R8,R10}
        retfiq
WriteNonScatterPtr
 |
        STRB    R9, [R13]
      [ FlpFlushPBI
        LDRB    R9, [R13, #4]
      ]
        SUBS    R12, R12, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset
        SUBS    R10, R10, #1
        LDRGTB  R9, [R8], #1
        retfiq  GT
        CMP     R12, #0
        LDMGEIA R11!, {R8, R10}
        LDRGEB  R9, [R8], #1
        retfiq
 ]
        DCD     1       ; Where FlpDCBbuffer will be put
        DCD     0       ; End of FIQ routine
        DCD     0       ; End of instructions needing 1 x sector size
        DCD     0       ; End of instructions needing 2 x sector size

;-----------------------------------------------------------------------;
; FlpWriteFIQ_BG                                                        ;
;       Write data FIQ routine for backgrounding                        ;
;                                                                       ;
;  well, actually it's for the '665 controller                          ;
; Input:                                                                ;
;       FIQ mode (FIQ pin asserted)                                     ;
;       R8 -> data destination                                          ;
;       R9 byte ready to transfer                                       ;
;       R10 number of transfers to sector end                           ;
;       R11 number of transfers before switching to TC space            ;
;               Will be EOTrack or EOSector as appropriate              ;
;       R12 -> previous sector's scatter list entry                     ;
;               (=1 to indicate no previous sector)                     ;
;       R13 = FlpDACK or FlpDACK_TC as determined by R11 on             ;
;               previous FIQs                                           ;
;       FlpWriteThisRover -> this sector's scatter list entry           ;
;                                                                       ;
; Output:                                                               ;
;       The byte gets transfered                                        ;
;       The above get advanced by one byte's worth                      ;
;_______________________________________________________________________;
;
FlpWriteFIQ_BG   ROUT

        ; Well, actually the '665
        ; The problem here is that late termination doesn't go on the '665, ho hum!
        ; So, how does it go:
        ; The idea is we've got big time gaps between sectors, so we use that to do
        ; the processing under FIQ. During a sector we do as little processing as possible.
        ; This involves counting down to TC which will only occur at the sector's end, and
        ; counting down to the sector's end itself.
        ; Once the sectors end has been reached we do this:
        ; * advance the previous sector (1)
        ; * advance txcount (1)
        ; * Find out where the next sector should be transfered to
        ; * Find out whether there's a sector after that waiting
        ; (1) These only happen if there was a previous sector and only happen for the
        ; previous sector and not this sector as just because we've picked a byte off the controller
        ; doesn't mean we haven't overrun or got a CRC error.

        ; Transfer the byte
        STRB    R9, [R13]
      [ FlpFlushPBI
        LDRB    R9, [R13, #4]
      ]

        ; Check for TC assertion next byte
        SUBS    R11, R11, #1
        ADDEQ   R13, R13, #FlpDACK_TC_Offset

        ; Check for sector end
        SUBS    R10, R10, #1
        LDRGTB  R9, [R8], #1
        retfiq  GT

        ; Sector end reached

        ; Advance the prev sector (if there is a prev sector)
        ; Also advance txcount
        TEQ     R12, #1
        LDMNEIA R12, {R9,R10}
FlpWriteFIQ_1xSectorSize1
        ADDNE   R9, R9, #&3FC0          ; 1xSectorSize
FlpWriteFIQ_1xSectorSize2
        SUBNE   R10, R10, #&3FC0        ; 1xSectorSize
        STMNEIA R12, {R9,R10}
        LDRNE   R10, FlpWriteFIQ_txcount
        LDRNE   R9, [R10]
FlpWriteFIQ_1xSectorSize3
        ADDNE   R9, R9, #&3FC0          ; 1xSectorSize
        STRNE   R9, [R10]
        LDR     R12, FlpWriteThisRover  ; Advance the scatter by 1 sector
                                        ; ie load the next sector's prev thingy

        ; Check if this was the TC transfer
        CMP     r11, #-1
        retfiq  EQ

        ; We haven't TCed the byte just transfered, hence there *is* a next sector

        ; Get this sector's scatter entry's address
        ; Need to determine:
        ; * next sector's start address
        ; * Whether there's more after the next sector

        ; Prepare standard goop for the next sector
FlpWriteFIQ_1xSectorSize4
        MOV     R10, #&3FC0             ; 1xSectorSize

        LDR     R9, [R12, #4]
FlpWriteFIQ_2xSectorSize1
        CMP     R9, #&3FC0              ; 2xSectorSize
        BLO     %FT50

        ; This sector's scatter entry has >= 2xSectorSize in it
        ; Hence: r8 is correct

        ; If This sector's scatter entry is > 2xSectorSize then
        ; there's definitely a sector after the next one and we
        ; can go for the next sector without any worries
        LDRHIB  r9, [r8], #1
        retfiq  HI

        ; This sector's entry has = 2xSectorSize hence we must check the next
        ; scatter entry for being present
        LDR     R9, [R12, #8]
 [ FixTBSAddrs
        CMN     R9, #ScatterListNegThresh
        ADDCS   R9, R12, R9
        LDRCS   R9, [R9, #8+4]
        LDRCC   R9, [R12, #8+4]
 |
        TEQ     R9, #0
        ADDMI   R9, R12, R9
        LDRMI   R9, [R9, #8+4]
        LDRPL   R9, [R12, #8+4]
 ]
20
        TEQ     R9, #0
        SUBEQ   R11, R10, #1            ; Terminate on last byte of next sector
        LDRB    R9, [R8], #1
        retfiq

50
        ; This scatter entry has 1xSectorSize in it, hence r8 is wrong
        ADD     R10, R12, #8
        LDR     R8, [R10]
 [ FixTBSAddrs
        CMN     R8, #ScatterListNegThresh
        LDRCS   R8, [R10, R8]!
 |
        TEQ     R8, #0
        LDRMI   R8, [R10, R8]!
 ]
        STR     R10, FlpWriteThisRover
        LDR     R9, [R10, #4]
FlpWriteFIQ_1xSectorSize5
        CMP     R9, #&3FC0              ; 1xSectorSize
        LDRHIB  R9, [R8], #1
FlpWriteFIQ_1xSectorSize7
        MOVHI   R10, #&3FC0             ; 1xSectorSize
        retfiq  HI
        LDR     R9, [R10, #8]!
 [ FixTBSAddrs
        CMN     R9, #ScatterListNegThresh
        ADDCS   R10, R10, R9
 |
        TEQ     R9, #0
        ADDMI   R10, R10, R9
 ]
        LDR     R9, [R10, #4]
FlpWriteFIQ_1xSectorSize6
        MOV     R10, #&3FC0             ; 1xSectorSize
        B       %BT20

FlpWriteThisRover DCD 1 ; Where FlpDCBbuffer will be put
FlpWriteFIQ_txcount
        DCD     0       ; End of FIQ routine
  [ {PC}-FlpWriteFIQ_BG + FiqVector > FlpFiqStackBase
        ! 0,"Fiq overflow by ":CC::STR:(({PC}-FlpWriteFIQ_BG + FiqVector) - FlpFiqStackBase)
  ]
        ASSERT  {PC}-FlpWriteFIQ_BG + FiqVector <= FlpFiqStackBase

; List of locations needing 1xSectorSize plugged into instruction
        DCD     FlpWriteFIQ_1xSectorSize1 - FlpWriteFIQ_BG + FiqVector
        DCD     FlpWriteFIQ_1xSectorSize2 - FlpWriteFIQ_BG + FiqVector
        DCD     FlpWriteFIQ_1xSectorSize3 - FlpWriteFIQ_BG + FiqVector
        DCD     FlpWriteFIQ_1xSectorSize4 - FlpWriteFIQ_BG + FiqVector
        DCD     FlpWriteFIQ_1xSectorSize5 - FlpWriteFIQ_BG + FiqVector
        DCD     FlpWriteFIQ_1xSectorSize6 - FlpWriteFIQ_BG + FiqVector
        DCD     FlpWriteFIQ_1xSectorSize7 - FlpWriteFIQ_BG + FiqVector
        DCD     0

; List of locations needing 2xSectorSize plugged into instruction
        DCD     FlpWriteFIQ_2xSectorSize1 - FlpWriteFIQ_BG + FiqVector
        DCD     0       ; End of instructions needing 2 x sector size


;=======================================================================;
;                                                                       ;
;                                                                       ;
;                                                                       ;
;                                                                       ;
;            E n d   o f   F I Q   r o u t i n e s                      ;
;                                                                       ;
;                                                                       ;
;                                                                       ;
;                                                                       ;
;=======================================================================;

 ] ; :LNOT:FloppyPCI


;-----------------------------------------------------------------------;
; FlpHandlerData                                                        ;
;       Message handler for data transfer type FDC commands             ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Message                                                    ;
;       R1 = Parameter                                                  ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpHandlerData  ROUT
 [ Debug10v :LOR: Debug10
        BREG    r0,"E",cc
        DLINE   " ",cc
 ]
 [ Debug10e
        Push    "R0,LR"
        SWI     XOS_ReadMonotonicTime
        DREG    R0,,cc,Integer
        Pull    "R0,LR"
        DREG    R0," ",,Byte
 ]
        CMPS    R0, #FlpEventIRQ        ; FDC interrupt?
        BEQ     %FT60                   ; Yes then jump
        CMPS    R0, #FlpMsgIP           ; Drive ready index pulse?
        BEQ     %FT20                   ; Yes then jump
        CMPS    R0, #FlpMsgSeekDone     ; Seek complete?
        BEQ     FlpHandlerData_SeekDone ; Yes then jump
        CMPS    R0, #FlpMsgStart        ; Initialise?
        BEQ     %FT10                   ; Yes then jump
        CMPS    R0, #FlpMsgResetOK      ; Reset complete?
        BEQ     %FT90                   ; Yes then jump
        CMPS    R0, #FlpMsgError        ; Fatal error?
        BEQ     %FT05                   ; Yes then jump
        CMPS    R0, #FlpMsgESC          ; Escape?
        MOVNE   PC, LR                  ; No then return

; Handle escape message

        Push    "LR"
        LDRB    LR, [R2, #FlpDCBesc]    ; Get escape enable flag
        TEQS    LR, #0                  ; Escapes enabled?
        Pull    "LR"
        MOVNE   PC, LR                  ; No then exit

; Handle error message, R1= error code
05
        Push    "R0,LR"
        LDRB    LR, [R2, #FlpDCBphase]
        TEQS    LR, #FlpPhaseIdle       ; Idle phase?
        BEQ     %FT06

        BL      Flp765reset             ; No then reset FDC

 [ FloppyPCI
        BL      FlpDMATerminate
 |
    [ HAL
        Push    "R0-R3,R9,R12"
        sbaddr  R1, HAL_FIQDisableAll_routine
        MOV     LR, PC
        LDMIA   R1,{R9,PC}
        Pull    "R0-R3,R9,R12"
      [ FloppyPodule
        LDR     LR, FlpDACK_TC
        SUB     LR, LR, #&400000
        MOV     R0, #0
        STRB    R0, [LR, #8]
      ]
    |
        MOV     LR, #IOC                ; LR-> IOC base address
        ASSERT  IOC :AND: &FF = 0
        STRB    LR, [LR, #IOCFIQMSK]    ; Disable Data ReQuest FIQs
    ]
 ]

06      MOV     LR, #0
        STR     LR, [R2, #FlpDCBlength] ; No data transferred
        MOV     R0, R1                  ; Get error code
        BL      FlpDqDCB                ; Terminate DCB (R0,R2->)
        Pull    "R0,PC"

; Process initialization message, R2->DCB
10
        Push    "R0,R1,R4,LR"
        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    R0, #FlpPhaseIdle       ; Idle phase?
        Pull    "R0,R1,R4,PC",NE        ; No then exit

; Select requested drive

        SETPSR  I_bit, LR,, R4          ; Disable IRQ's

        LDRB    R1, [R2, #FlpDCBcdb+1]  ; Get drive select
        AND     R1, R1, #3              ; Retain drive select bits
        MOV     R0, #FlpEventDrvSel     ; Drive select event
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpDrive            ; Call drive state system (R0,R1->R0)

        MOV     LR, #FlpPhaseDrv        ; Next phase is awaiting drive ready
        STRB    LR, [R2, #FlpDCBphase]  ; Update phase
        TSTS    R0, #MiscOp_PollChanged_Empty_Flag+MiscOp_PollChanged_Ready_Flag ; Drive empty or ready?
        BNE     %FT15
        RestPSR R4,,c                   ; No then restore regs and wait
        Pull    "R0,R1,R4,PC"

15      TSTS    R0, #MiscOp_PollChanged_Empty_Flag          ; Drive empty?
        BEQ     %FT18

        MOV     R0, #0                  ; Yes then no data transferred
        STR     R0, [R2, #FlpDCBlength] ; And update length
        MOV     R0, #DriveEmptyErr      ; And drive empty error
        BL      FlpDqDCB                ; And terminate DCB (R0,R2->)
        RestPSR R4,,c                   ; Restore IRQ's
        Pull    "R0,R1,R4,PC"           ; Restore regs and exit

18
        RestPSR R4,,c                   ; Restore IRQ's
        Pull    "R0,R1,R4,LR"

; Process index pulse message, R2->DCB
20
        Push    "R0,R1,LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
 [ Debug10
        DREG    lr, "Index pulse gotten and phase is "
 ]
        CMPS    LR, #FlpPhaseDrv        ; Phase is awaiting drive ready?
        Pull    "R0,R1,PC",NE          ; No then exit

; Ensure '765 FDC has completed reset

        MOV     LR, #FlpPhaseReset      ; Assume waiting for reset
        STRB    LR, [R2, #FlpDCBphase]  ; Update phase
        baddr   R0, FlpStateReset       ; Reset state address
        LDR     LR, FlpState            ; Get current FDC state
 [ Debug10
        DLINE   "Check we're not is FlpStateReset"
 ]
        CMPS    LR, R0                  ; Currently reset?
        Pull    "R0,R1,PC",EQ           ; Yes then wait

; Lock the drive during execution

        LDRB    LR, FlpDriveLock        ; Get lock state
        ORR     LR, LR, #bit0+bit2      ; Set command lock bit, inhibit empty
        STRB    LR, FlpDriveLock        ; Update lock state

; Implied seek required?

        LDRB    R0, [R2, #FlpDCBcdb+1]  ; Get drive/head/implied seek
        TSTS    R0, #bit7               ; Implied seek?
 [ Debug10
        DLINE   "Check for implied seek"
 ]
        Pull    "R0,R1,LR",EQ           ; No, then restore regs
        BEQ     FlpHandlerData_ExecuteCommand ; and jump, issue command

; Request seek to required track

25
        MOV     LR, #FlpPhaseSeek       ; Next phase is waiting for seek done
        STRB    LR, [R2, #FlpDCBphase]  ; Update command phase
        MOV     R1, R2                  ; Get->DCB
        MOV     R0, #FlpEventSeek
 [ Debug10 :LOR: Debug10T
        DLINE   "Do the seek"
 ]
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpState            ; Call state system (R0,R1->R0,V)
        BVS     FlpHandlerData_SeekFault

 [ Debug10 :LOR: Debug10T
        DREG    r0, "Seek in progress with flag "
 ]
        TEQS    R0, #0                  ; Seek in progress?
        Pull    "R0,R1,LR"
        MOVNE   PC, LR                  ; Yes then exit

; Process seek done message, R2->DCB
FlpHandlerData_SeekDone
 [ Debug10
        DLINE   "Seek done"
 ]
        Push    "LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
        TEQS    LR, #FlpPhaseRetry      ; Retrying?
        LDREQB  LR, [R2, #FlpDCBresults+7] ; Yes, get old track reg
        STREQB  LR, [R2, #FlpDCBtrack]  ; And restore track reg
        Pull    "LR",EQ                 ; And restore regs
        Push    "R0,R1,LR",EQ           ; And setup stack
        BEQ     %BT25                   ; And retry seek

        TEQS    LR, #FlpPhaseSeek       ; Phase is awaiting seek done?
        Pull    "LR"
        MOVNE   PC, LR                  ; No then exit

; Seek completed, setup for command execution, R2->DCB
FlpHandlerData_ExecuteCommand
        Push    "R0,R1,LR"

 [ Debug10
        DREG    r2, "ExecuteCommand with DCB="
 ]

        LDR     R0, [R2, #FlpDCBtxbytes]
        STR     R0, [R2, #FlpDCBtxgobytes]

        ; Length has all sort of useful flags in it...
        LDR     R0, [R2, #FlpDCBlength] ; Get transfer size and direction

 [ :LNOT:FloppyPCI
; Copy FIQ handler to FIQ vector

        ; Choose handler...

        TST     R0, #FlpDCBscatter
        BNE     %FT33

        TST     R0, #FlpDCBread
        baddr   R0, FlpWriteNonScatter, EQ
        baddr   R0, FlpReadNonScatter, NE
        B       %FT39

33
        TST     R0, #FlpDCBread
        BNE     %FT35

        ; Writing
        LDRB    R0, [R2, #FlpDCBbgnd]
        TEQ     R0, #0
        baddr   R0, FlpWriteFIQ_FG, EQ
        baddr   R0, FlpWriteFIQ_BG, NE
        B       %FT39

35
        ; Reading
        LDRB    R0, [R2, #FlpDCBcdb+9]  ; Else get read/verify
        TEQS    R0, #&FF                ; Verifying?
        baddr   R0, FlpVerifyFIQ, EQ    ; Yes then use verify FIQ routine
        BEQ     %FT39

        LDRB    R0, [R2, #FlpDCBbgnd]
        TEQ     R0, #0
        baddr   R0, FlpReadFIQ_FG, EQ
        baddr   R0, FlpReadFIQ_BG, NE

39


        ; Switch to _32 mode with IRQs and FIQs off
        ; Note must switch interrupts off before switching mode as
        ; there can be an interrupt after the msr instruction
        ; but before the following instruction.
        ; For non-32-bit processors this section reads:
        ; NOP
        ; Push "r1"
        ; ORR   r1, r1, #number
        ; NOP
        ; ORR   r1, r1, #number
        ; NOP
        MRS     r1, CPSR
        Push    "r1"
        ORR     r1, r1, #I32_bit :OR: F32_bit
        MSR     CPSR_c, r1
        ORR     r1, r1, #2_10000
        MSR     CPSR_c, r1
        NOP

        MOV     LR, #FiqVector          ; FIQ vector address

        ; Copy handler
40      LDR     R1, [R0], #4            ; Get opcode
        TEQS    R1, #0                  ; All done?
        STRNE   R1, [LR], #4            ; No then copy to FIQ area
        BNE     %BT40                   ; And repeat

        ; And switch back - this bit reads as follows for non-32-bit processors:
        ; Pull  "r1"
        ; NOP
        Pull    "r1"
        MSR     CPSR_c, r1

        ; Put DCBbuffer into place
        LDR     R1, [R2, #FlpDCBbuffer]
        STR     R1, [LR, #-4]

        ; Put txcount into place
        ADD     R1, R2, #FlpDCBtxbytes
        STR     R1, [LR], #4

 [ Debug10 :LOR: Debug10t
        LDR     r1, [r2, #FlpDCBtxbytes]
        DREG    r1, "Start txbytes="
 ]

        ; Patch up the areas needing 1xSectorSize
        LDRB    R1, [R2, #FlpDCBcdb+5]  ; Log2SectorSize-7
        MOV     LR, #1 :SHL: (7 - 6)    ; SHL 7 for the -7 above, SHL -6 for the immediate
                                        ; rotate in the instructions we're patching
        MOV     R1, LR, ASL R1

45      LDR     LR, [R0], #4           ; Address of instruction to patch up
        TEQS    LR, #0
        STRNEB  R1, [LR]
        BNE     %BT45

        ; Patch up the areas needing 2xSectorSize
        MOV     r1, r1, ASL #1

50      LDR     LR, [R0], #4           ; Address of instruction to patch up
        TEQS    LR, #0
        STRNEB  R1, [LR]
        BNE     %BT50

  [ StrongARM
        ;now that we have finished arsing about, synchronise with respect to modified code
        Push    "R0-R2,LR"
        MOV     R0,#FiqVector                 ;start virtual address
        MOV     R1,#FiqVectorMaxCode          ;worst case end virtual address (inclusive)
        BL      ADFSsync
        Pull    "R0-R2,LR"
  ]

; Setup FIQ registers
        ; Choose handler...

        LDR     R1, FlpDACK_TC          ; before R12 gets banked out

        WritePSRc I_bit + F_bit + FIQ_mode,LR,,R0 ; FIQ mode, FIQ/IRQ disabled
        NOP                             ; delay for mode change

        ADR     LR, %FT59

        MOV     R13, R1                 ; R13-> DMA data reg with TC
        LDRB    R10, [R2, #FlpDCBcdb+5]
        MOV     R11, #1 :SHL: 7
        MOV     R10, R11, ASL R10       ; R10 = SectorSize
        LDR     R12, [R2, #FlpDCBlength]; R12 = DCBlength (inc flags)
        TST     R12, #FlpDCBscatter
        BNE     %FT54

        ; non-scatter register initialisation
 [ FlpUseFIFO
        LDR     R8, [R2, #FlpDCBbuffer]         ; r8 set

        TST     R12, #FlpDCBread
        LDREQB  R9, [R8], #1                    ; r9 set
        BIC     R12, R12, #FlpDCBflags          ; r12 set

        ; SectorSize-1 in R10
        SUB     R10, R10, #1

        ; R11 = round up of R12 to a sector
        ADD     R11, R12, R10
        BIC     R11, R11, R10

        ; Process for termination at sector's end
        SUBS    R11, R11, #1                    ; r11 set
        SUBNE   R13, R13, #FlpDACK_TC_Offset    ; r13 set
 |
        BIC     R10, R12, #FlpDCBflags
        SUBS    R10, R10, #1
        SUBNE   R13, R13, #FlpDACK_TC_Offset
        LDR     R8, [R2, #FlpDCBbuffer]
        TST     R12, #FlpDCBread
        LDREQB  R9, [R8], #1
 ]
        B       %FT59

54
        TST     R12, #FlpDCBread
        BIC     R12, R12, #bit29 :OR: FlpDCBflags
        BNE     %FT55

        ; Writing
        LDRB    R8, [R2, #FlpDCBbgnd]
        TEQ     R8, #0
        BEQ     FIQSetupWrite_FG
        B       FIQSetupWrite_BG

55
        ; Reading
        LDRB    R8, [R2, #FlpDCBcdb+9]  ; Else get read/verify
        TEQS    R8, #&FF                ; Verifying?
        BEQ     FIQSetupVerify
        LDRB    R8, [R2, #FlpDCBbgnd]
        TEQ     R8, #0
        BEQ     FIQSetupRead_FG
        B       FIQSetupRead_BG

59

; Enable Data ReQuest FIQ's

 [ :LNOT:HAL
        MOV     R1, #IOC                ; R1-> IOC base address
        MOV     LR, #1:SHL:FlpDRQmaskbit; DRQ FIQ mask
        STRB    LR, [R1, #IOCFIQMSK]    ; Enable Data ReQuest FIQs
 ]
 | ; FloppyPCI
        ; up to SVC mode for SWI calls
        LDR     R0, [R2, #FlpDCBlength] ; Get transfer size and direction

        ; Ensure no transfers lingering
        BL      FlpDMATerminate

        TST     R0, #FlpDCBscatter
        BNE     %FT54

        Push    "R3,R4"
        ADR     R3, FlpDMAScatter

        LDR     R1, [R2, #FlpDCBbuffer]         ; R1 = buffer
        BIC     R4, R0, #FlpDCBflags            ; R4 = length

        STMIA   R3, {R1, R4}

        TST     R0, #FlpDCBread
        MOVEQ   R0, #1+8
        MOVNE   R0, #0
        LDR     R1, FlpDMAHandle
        BL      FlpDMAQueueTransfer
        Pull    "R3,R4"
        BVS     FlpHandlerData_DMAErr
        STR     R0, FlpDMATag
        B       %FT59

54
 [ Debug10d
        DREG    R0, "Cmd/length = "
        LDRB    R1, [R2, #FlpDCBbgnd]
        DREG    R1, "Background flag = ",, Byte
        LDRB    R1, [R2, #FlpDCBcdb+9]
        DREG    R1, "Command = ",, Byte
 ]
        ADR     LR, %FT59
        TST     R0, #FlpDCBread
        BIC     R0, R0, #bit29 :OR: FlpDCBflags
        BNE     %FT55

        ; Writing
        LDRB    R1, [R2, #FlpDCBbgnd]
        TEQ     R1, #0
        BEQ     DMASetupWrite_FG
        B       DMASetupWrite_BG

55
        ; Reading
        LDRB    R1, [R2, #FlpDCBcdb+9]  ; Else get read/verify
        TEQS    R1, #&FF                ; Verifying?
        BEQ     DMASetupVerify
        LDRB    R1, [R2, #FlpDCBbgnd]
        TEQ     R1, #0
        BEQ     DMASetupRead_FG
        B       DMASetupRead_BG

59
        SavePSR R0
 ]

 [ No32bitCode
        ORR     R1, R0, #I_bit          ; Ensure IRQ's disabled
 |
        ORR     R1, R0, #I32_bit        ; Ensure IRQ's disabled
 ]
        RestPSR R1,,c                   ; Restore CPU mode
        NOP

 [ HAL
  [ :LNOT:FloppyPCI
        Push    "R0,R2,R3,R9,R12"
        MOV     R0, #FlpDRQmaskbit
        sbaddr  R1, HAL_FIQEnable_routine
        MOV     LR, PC
        LDMIA   R1, {R9, PC}
        Pull    "R0,R2,R3,R9,R12"
   [ FloppyPodule
        LDR     R1, FlpDACK_TC
        SUB     R1, R1, #&400000
        MOV     LR, #1
        STRB    LR, [R1, #8]
   ]
  ]
 ]

        Push    "r0"

 [ Debug10s :LAND: {FALSE}
        LDR     lr, [r2, #FlpDCBlength]
        AND     lr, lr, #FlpDCBflags
        TEQ     lr, #FlpDCBscatter :OR: FlpDCBread
        BNE     %FT01
        ; Scatter reading...
        LDRB    lr, [r2, #FlpDCBcdb+9]
        TEQ     lr, #&ff
        BEQ     %FT01
        ; non-verify...
        LDRB    lr, [r2, #FlpDCBbgnd]
        TEQ     lr, #0
        BEQ     %FT01
        ; background...
        LDR     lr, [r2, #FlpDCBbuffer]
02
        LDMIA   lr, {r0,r1}
        DREG    r0, " �",cc
        DREG    r1, ",",cc
 [ FixTBSAddrs
        CMN     r0, #ScatterListNegThresh
        ADDCS   lr, lr, r0
        BCS     %BT02
 |
        TEQ     r0, #0
        ADDMI   lr, lr, r0
        BMI     %BT02
 ]
        ADD     lr, lr, #8
        TEQ     r1, #0
        BNE     %BT02
01
 ]

; Call FDC state system to execute the command

        MOV     R0, #FlpPhaseIRQ        ; Next phase is�awaiting IRQ
        STRB    R0, [R2, #FlpDCBphase]  ; Update DCB phase
        MOV     R0, #FlpEventCmd        ; Command request
        MOV     R1, R2                  ; R1->DCB
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpState            ; Call state system (R0,R1->V)
 [ Debug10d
        BVC     %FT01
        DLINE   "Error from FlpEventCmd"
01
 ]
        BVS     FlpHandlerData_BadComErr

        LDRB    LR, FlpDriveLock        ; Get lock state
        BIC     LR, LR, #bit2           ; Enable empty timer
        STRB    LR, FlpDriveLock        ; Update lock state


 [ Debug10s
        LDR     lr, [r2, #FlpDCBlength]
        AND     lr, lr, #FlpDCBflags
        TEQ     lr, #FlpDCBscatter :OR: FlpDCBread
        BNE     %FT01
        ; Scatter reading...
        LDRB    lr, [r2, #FlpDCBcdb+9]
        TEQ     lr, #&ff
        BEQ     %FT01
        ; non-verify...
        LDRB    lr, [r2, #FlpDCBbgnd]
        TEQ     lr, #0
        BEQ     %FT01
        ; background...
        LDR     lr, [r2, #FlpDCBbuffer]
02
        LDMIA   lr, {r0,r1}
        DREG    r0, " �",cc
        DREG    r1, ",",cc
 [ FixTBSAddrs
        CMN     r0, #ScatterListNegThresh
        ADDCS   lr, lr, r0
        BCS     %BT02
 |
        TEQ     r0, #0
        ADDMI   lr, lr, r0
        BMI     %BT02
 ]
        ADD     lr, lr, #8
        TEQ     r1, #0
        BNE     %BT02
01
 ]
        Pull    "lr"
 [ No32bitCode
        BIC     lr, lr, #F_bit          ; Return and enable FIQs if OK
 |
        BIC     lr, lr, #F32_bit
 ]
        RestPSR lr
        Pull    "R0,R1,PC"              ; Restore regs and return

FlpHandlerData_BadComErr
        MOV     R0, #BadComErr          ; Return bad command if error in FDC
        BL      FlpDqDCB                ; Terminate DCB if error occurred
        LDRB    LR, FlpDriveLock        ; Get lock state
        BIC     LR, LR, #bit2           ; Enable empty timer
        STRB    LR, FlpDriveLock        ; Update lock state
        Pull    "lr"
        RestPSR lr
        Pull    "R0,R1,PC"              ; Restore regs and return

FlpHandlerData_DMAErr
 [ :LNOT: NewErrors
        ORR     R0, R0, #ExternalErrorBit
 ]
        BL      FlpDqDCB
        Pull    "R0,R1,PC"

FlpHandlerData_SeekFault
        MOV     R0, #FlpErrSeekFault    ; Return seek fault if error
        BL      FlpDqDCB                ;   and terminate DCB (R0,R1->)
        Pull    "R0,R1,PC"              ;   and return

; Process IRQ message
60
        Push    "R0,R1,R3,LR"
        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    R0, #FlpPhaseIRQ        ; Phase is awaiting results?
        Pull    "R0,R1,R3,PC",NE        ; No then execute

 [ Debug10
        DREG    r2, "DCB="
 ]

; Command completed, disable FIQ's

 [ FloppyPCI
        MOV     R0, #0
        LDR     R1, FlpDMATag
        CMP     R1, #-1
        BEQ     %FT63
        BL      FlpDMAExamineTransfer
        MOVVS   R0, #0
        STR     R0, FlpDMACount
        BL      FlpDMATerminate
63

 |
  [ HAL
        Push    "R2,R9,R12"
        sbaddr  R1, HAL_FIQDisableAll_routine
        MOV     LR, PC
        LDMIA   R1, {R9, PC}
        Pull    "R2,R9,R12"
   [ FloppyPodule
        LDR     LR, FlpDACK_TC
        SUB     LR, LR, #&400000
        MOV     R0, #0
        STRB    R0, [LR, #8]
   ]
  |
        MOV     R1, #IOC                ; R1-> IOC base address
        MOV     R0, #0
        STRB    R0, [R1, #IOCFIQMSK]    ; Disable Data ReQuest FIQs
  ]
 ]
        MOV     R1, #FlpPhaseDone
        STRB    R1, [R2, #FlpDCBphase]

; Get '765 FDC results, R2->DCB

        MOV     R3, #7                  ; 7 result bytes
        ADD     R1, R2, #FlpDCBresults  ; R1-> result buffer

65      BL      Flp765read              ; Get result byte
        MOVVS   R0, #BadParmsErr        ; Bad parameters if can't read all results
        BVS     %FT70                   ; Jump if error
        STRB    R0, [R1], #1            ; Save result in DCB, R1++
        SUBS    R3, R3, #1              ; 1 less result
        BNE     %BT65                   ; Loop for all results

 [ Debug10v :LOR: Debug10 :LOR: Debug10t
        Push    "r0"
        LDRB    r0, [r2, #FlpDCBresults+0]
        BREG    r0,"ST0,ST1,ST2,C,H,R,N=",cc
        LDRB    r0, [r2, #FlpDCBresults+1]
        BREG    r0,",",cc
        LDRB    r0, [r2, #FlpDCBresults+2]
        BREG    r0,",",cc
        LDRB    r0, [r2, #FlpDCBresults+3]
        BREG    r0,",",cc
        LDRB    r0, [r2, #FlpDCBresults+4]
        BREG    r0,",",cc
        LDRB    r0, [r2, #FlpDCBresults+5]
        BREG    r0,",",cc
        LDRB    r0, [r2, #FlpDCBresults+6]
        BREG    r0,","
        LDR     r0, [r2, #FlpDCBtxbytes]
        DREG    r0, "End txbytes = "
        Pull    "r0"
 ]

  [ FlpUseVerify
        LDRB    R0, [R2, #FlpDCBcdb+9]
        TEQ     R0, #&FF
        BNE     %FT66
        BL      FlpController_TransferSize
    [ FloppyPCI
        STR     R1, FlpDMACount
    ]
66
  ]

; Advance command to where we're up to
        BL      FlpAdvanceTransfer

        LDRB    R0, [R2, #FlpDCBresults] ; Get ST0
        ANDS    R0, R0, #&C0            ; Test interrupt code or fault bits
        BNE     %FT80                   ; Jump if error

70
; DCB complete, R0= completion status

 [ Debug10
        DREG    r0,"DCB completed with RC "
 ]
        BL      FlpDqDCB                ; Terminate DCB (R0,R2->)
        Pull    "R0,R1,R3,PC"

; !!-Operation faulted-!!

80      LDRB    R1, [R2, #FlpDCBresults+1] ; Get ST1
 [ :LNOT: Debug10 :LOR: {TRUE}  ; Allow retry testing with write protected disk
        TSTS    R1, #bit1               ; Write protect?
        MOVNE   R0, #FlpDiscError       ; Yes, return FDC error
        BNE     %BT70                   ; And exit
 ]

; Check for sector not found on side 1, in case sector ID says head 0

        TSTS    R1, #bit2               ; Sector not found?
        LDRNEB  R0, [R2, #FlpDCBcdb+1]  ; Get drive/head data
        TSTNES  R0, #bit2               ; And head 1?
        BEQ     %FT81                   ; No then jump

        LDRB    R0, [R2, #FlpDCBcdb+3]  ; Get head number from sector ID
        TEQS    R0, #0                  ; H forced to 0?
        MOVEQ   R0, #1                  ; Restore H=1 if was 0
        MOVNE   R0, #0                  ; Else try H=0 for DFS and odd discs
        STRB    R0, [R2, #FlpDCBcdb+3]  ; Set head number for sector ID
        Pull    "R0,R1,R3,LR",NE        ; Restore regs
        BNE     FlpHandlerData_ExecuteCommand ; And retry operation with H=0

; Count down retries

81      LDRB    R0, [R2, #FlpDCBretries]
        SUBS    R0, R0, #1              ; Knock retry counter
        STRPLB  R0, [R2, #FlpDCBretries] ; Update it
        MOVMI   R0, #FlpDiscError       ; Error if retries exhausted
        BMI     %BT70                   ; And exit

 [ Debug10
        DREG    R0, "Retry# "
        DREG    R1, " ST1: "
 ]
        TSTS    R1, #bit4               ; Overrun?
        BEQ     %FT85                   ; No then jump

; Data overrun - inhibit video DMA

        LDR     LR, FlpMEMCstate
        TEQS    LR, #0                  ; MEMC_CR state saved?
 [ Debug10v :LOR: Debug10
        BNE     %FT810
        DLINE   "Data lost - inhibiting video DMA"
810
 ]
        BNE     %FT83

        ; Faff about in SVC mode to preserve flags etc
        WritePSRc SVC_mode + I_bit,lr,,r0
        NOP
        Push    "r0, lr"                ; SVC_lr
        MOV     r0, #MEMC_mystate
        MOV     r1, #MEMC_DMA_bits
        SWI     XOS_UpdateMEMC
        ORRVC   r0, r0, #bit31          ; ensures non-0
        STRVC   r0, FlpMEMCstate
        Pull    "r0, lr"                ; SVC_lr
        RestPSR r0,,c
        NOP
83
        Pull    "R0,R1,R3,LR"           ; Restore regs
        B       FlpHandlerData_ExecuteCommand ; And retry operation

; Just retry operation if no implied seek

85      LDRB    R0, [R2, #FlpDCBcdb+1]  ; Get head/drive/option bits
        TSTS    R0, #bit7               ; Implied seek?
        Pull    "R0,R1,R3,LR",EQ        ; No?, then restore regs
        BEQ     FlpHandlerData_ExecuteCommand ; And retry operation only

; Implied seek type DCB, try re-positioning head

        LDRB    LR, [R2, #FlpDCBresults+2] ; Get ST2
        TSTS    LR, #bit4               ; Wrong cylinder?
        LDRB    LR, [R2, #FlpDCBcdb+1]  ; Get drive
        AND     LR, LR, #3              ; Ignore head etc
        DrvRecPtr R1, LR
        MOVNE   LR, #PositionUnknown    ; Yes, force restore
        STRNE   LR, [R1, #HeadPosition]

        LDRB    LR, [R2, #FlpDCBtrack]  ; Get cylinder
        STRB    LR, [R2, #FlpDCBresults+7] ; Save track
        BNE     %FT87                   ; And jump

; Step in 2 tracks and retry operation

        LDR     R0, [R1, #DrvFlags]
        TSTS    R0, #MiscOp_PollChanged_40Track_Flag        ; 40 track?
        MOVNE   R0, #TrksPerSide/2      ; Yes, max track = tracks per side /2
        MOVEQ   R0, #TrksPerSide        ; Else max track
        ADD     LR, LR, #2              ; Try track+2
        CMPS    LR, R0                  ; At end of drive?
        SUBHS   LR, LR, #4              ; Yes, then try track-2
        STRB    LR, [R2, #FlpDCBtrack]  ; Write new track

; Request seek to new track

87      LDRB    LR, FlpDriveLock        ; Get lock state
        ORR     LR, LR, #bit0+bit2      ; Set command lock bit, inhibit empty
        STRB    LR, FlpDriveLock        ; Update lock state

        MOV     LR, #FlpPhaseRetry      ; New phase is retrying op
        STRB    LR, [R2, #FlpDCBphase]  ; Get current phase

        MOV     R1, R2                  ; Get->DCB
        MOV     R0, #FlpEventSeek
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpState            ; Call state system (R0,R1->R0,V)
        BVS     FlpHandlerData_SeekFault2

        TEQS    R0, #0                  ; Seek in progress?
        Pull    "R0,R1,R3,LR"
        MOVNE   PC, LR                  ; Yes then exit
        B       FlpHandlerData_SeekDone ; Else jump, seek done

FlpHandlerData_SeekFault2
        MOV     R0, #FlpErrSeekFault    ; Return seek fault if error
        BL      FlpDqDCB                ;   and terminate DCB (R0,R1->)
        Pull    "R0,R1,R3,PC"           ;   and return

; Process reset OK message
90
        Push    "LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    LR, #FlpPhaseReset      ; Phase is awaiting reset?
        Pull    "PC",NE                 ; No then exit

; Reset complete

        MOV     LR, #FlpPhaseDrv        ; Awaiting drive ready
        STRB    LR, [R2, #FlpDCBphase]  ; Update command phase
        Pull    "LR"
        B       %BT20                   ; Simulate drive ready

        LTORG

 [ FloppyPCI
; R0 = transfer size
; R2 -> DCB
DMASetupWrite_FG ROUT
        Push    "R3,R4,LR"
        MOV     R4, R0
        MOV     R0, #1+8
        B       %FT20

DMASetupRead_FG
        Push    "R3,R4,LR"
        MOV     R4, R0
        MOV     R0, #0+8

20      LDR     R3, [R2, #FlpDCBbuffer]
 [ Debug10d
        LDMIA   R3, {R1, R14}
        DREG    R1, "Scatter:",cc
        DREG    R14, ","
 ]
        LDR     R1, FlpDMAHandle
        BL      FlpDMAQueueTransfer
        STRVC   R0, FlpDMATag
        Pull    "R3,R4,PC",VC
        Pull    "R3,R4,LR"
        B       FlpHandlerData_DMAErr

DMASetupWrite_BG ROUT
        Push    "R3,R4,LR"
        MOV     R4, R0
        MOV     R0, #1+8
        B       %FT20

DMASetupRead_BG
        Push    "R3,R4,LR"
        MOV     R4, R0
        MOV     R0, #0+8

20      LDR     R3, [R2, #FlpDCBbuffer]
 [ Debug10d
        LDMIA   R3, {R1, R14}
        DREG    R1, "Scatter:",cc
        DREG    R14, ","
 ]
        BL      FlpLimitLengthToScatterList
        LDR     R1, FlpDMAHandle
        BL      FlpDMAQueueTransfer
        STRVC   R0, FlpDMATag
        Pull    "R3,R4,PC",VC
        Pull    "R3,R4,LR"
        B       FlpHandlerData_DMAErr


DMASetupVerify ROUT
        ASSERT  FlpUseVerify
        MOV     PC,LR
 |
; Entered in FIQ mode, FIQs and IRQs disabled
; R2 -> DCB
; R10 = SectorLength
; R12 = transfer size
; R13 -> controller DMA+TC
;
; Setup FIQ registers for foreground write transfer
FIQSetupWrite_FG ROUT
 [ FlpUseFIFO
        SUB     R10, R10, #1            ; SectorSize-1
        ADD     R11, R12, R10
        BIC     R11, R11, R10           ; transfer size rounded to a sector boundary
        LDR     R8, [R2, #FlpDCBbuffer]
        LDMIA   R8, {R8, R10}           ; Destination and length of scatter entry
        SUB     R10, R10, #1
        LDRB    R9, [R8], #1            ; byte to transfer
        SUB     R11, R11, #1
        SUB     R13, R13, #FlpDACK_TC_Offset
 |
        LDR     R11, [R2, #FlpDCBbuffer] ; Get buffer/scatter list pointer
        LDMIA   R11!, {R8, R10}
        LDRB    R9, [R8], #1
        SUBS    R12, R12, #1
        SUBNE   R13, R13, #FlpDACK_TC_Offset
 ]
 [ Debug10
        MOV     r1, #ScratchSpace
        STMIA   r1, {r8-r13}
        MRS     r1, CPSR
        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode
        Push    "r0,r2,lr"
        MOV     r2, #ScratchSpace
        LDR     r0, [r2, #0]
        DREG    r0, "SetupWrite_FG->(",cc
        LDR     r0, [r2, #4]
        DREG    r0, ",",cc
        LDR     r0, [r2, #8]
        DREG    r0, ",",cc
        LDR     r0, [r2, #12]
        DREG    r0, ",",cc
        LDR     r0, [r2, #16]
        DREG    r0, ",",cc
        LDR     r0, [r2, #20]
        DREG    r0, ",",cc
        DLINE   ")"
        Pull    "r0,r2,lr"
        MSR     CPSR_c, r1
 ]
        MOV     PC, LR
FIQSetupWrite_BG ROUT
        ; Well, actually it's for the '665 controller

        ; Set up EOT length in R11
        SUB     R11, R12, #1

        LDR     R12, [R2, #FlpDCBbuffer]
        LDR     R8, [R12]               ; r8 now set
        LDR     R9, [R12, #4]
        CMP     R9, R10                 ; SectorSize
        BHI     %FT50

        ; 1xSectorSize in this sector's entry - find the next sector's entry
        LDR     R9, [R12, #8]!
 [ FixTBSAddrs
        CMN     R9, #ScatterListNegThresh
        ADDCS   R12, R12, R9
 |
        TEQ     R9, #0
        ADDMI   R12, R12, R9
 ]
        LDR     R9, [R12, #4]
        CMP     R9, #0
50
        ; If HI then more than 1 sector
        SUBLS   R11, R10, #1            ; terminate at this sector's end
                                        ; r11 now set
        MOV     r12, #1                 ; r12 now set
        SUB     R13, R13, #FlpDACK_TC_Offset ; r13 now set
        LDRB    R9, [R8], #1
 [ Debug10 :LOR: Debug10t
        MOV     r1, #ScratchSpace
        STMIA   r1, {r8-r13}
        MRS     r1, CPSR
        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode
        Push    "r0,r2,lr"
        MOV     r2, #ScratchSpace
        LDR     r0, [r2, #0]
        DREG    r0, "SetupWrite_BG->(",cc
        LDR     r0, [r2, #4]
        DREG    r0, ",",cc
        LDR     r0, [r2, #8]
        DREG    r0, ",",cc
        LDR     r0, [r2, #12]
        DREG    r0, ",",cc
        LDR     r0, [r2, #16]
        DREG    r0, ",",cc
        LDR     r0, [r2, #20]
        DREG    r0, ",",cc
        DLINE   ")"
        Pull    "r0,r2,lr"
        MSR     CPSR_c, r1
 ]
        MOV     PC, LR
FIQSetupVerify ROUT
 [ FlpUseVerify
        MOV     R12, #0                 ; No data transfer so implicitly none left
 |
        SUB     R10, R10, #1
        ADD     R11, R12, R10
        BIC     R11, R11, R10           ; round up to sector boundary
        SUB     R11, R11, #1
        SUB     R13, R13, #FlpDACK_TC_Offset ; r13 now set
 ]
 [ Debug10
        MOV     r1, #ScratchSpace
        STMIA   r1, {r8-r13}
        MRS     r1, CPSR
        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode
        Push    "r0,r2,lr"
        MOV     r2, #ScratchSpace
        LDR     r0, [r2, #0]
        DREG    r0, "SetupVerify->(",cc
        LDR     r0, [r2, #4]
        DREG    r0, ",",cc
        LDR     r0, [r2, #8]
        DREG    r0, ",",cc
        LDR     r0, [r2, #12]
        DREG    r0, ",",cc
        LDR     r0, [r2, #16]
        DREG    r0, ",",cc
        LDR     r0, [r2, #20]
        DREG    r0, ",",cc
        DLINE   ")"
        Pull    "r0,r2,lr"
        MSR     CPSR_c, r1
 ]
        MOV     PC, LR
FIQSetupRead_FG ROUT
 [ FlpUseFIFO
        SUB     R10, R10, #1            ; SectorSize-1
        ADD     R11, R12, R10
        BIC     R11, R11, R10           ; transfer size rounded to a sector boundary
        LDR     R8, [R2, #FlpDCBbuffer]
        LDMIA   R8, {R8, R10}           ; Destination and length of scatter entry
        SUB     R11, R11, #1
        SUB     R13, R13, #FlpDACK_TC_Offset
 |
        LDR     R11, [R2, #FlpDCBbuffer] ; Get buffer/scatter list pointer
        LDMIA   R11!, {R8, R10}
        SUBS    R12, R12, #1
        SUBNE   R13, R13, #FlpDACK_TC_Offset
 ]
 [ Debug10
        MOV     r1, #ScratchSpace
        STMIA   r1, {r8-r13}
        MRS     r1, CPSR
        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode
        Push    "r0,r2,lr"
        MOV     r2, #ScratchSpace
        LDR     r0, [r2, #0]
        DREG    r0, "SetupRead_FG->(",cc
        LDR     r0, [r2, #4]
        DREG    r0, ",",cc
        LDR     r0, [r2, #8]
        DREG    r0, ",",cc
        LDR     r0, [r2, #12]
        DREG    r0, ",",cc
        LDR     r0, [r2, #16]
        DREG    r0, ",",cc
        LDR     r0, [r2, #20]
        DREG    r0, ",",cc
        DLINE   ")"
        Pull    "r0,r2,lr"
        MSR     CPSR_c, r1
 ]
        MOV     PC, LR
FIQSetupRead_BG ROUT
        ; Well, actually it's for the '665 controller

        ; Set up EOT length in R11
        SUB     R11, R12, #1

        LDR     R12, [R2, #FlpDCBbuffer]
        LDR     R8, [R12]               ; r8 now set
        LDR     R9, [R12, #4]
        CMP     R9, R10                 ; SectorSize
        BHI     %FT50

        ; 1xSectorSize in this sector's entry - find the next sector's entry
        LDR     R9, [R12, #8]!
 [ FixTBSAddrs
        CMN     R9, #ScatterListNegThresh
        ADDCS   R12, R12, R9
 |
        TEQ     R9, #0
        ADDMI   R12, R12, R9
 ]
        LDR     R9, [R12, #4]
        CMP     R9, #0
50
        ; If HI then more than 1 sector
        SUBLS   R11, R10, #1            ; terminate at this sector's end
                                        ; r11 now set
        MOV     r12, #1                 ; r12 now set
        SUB     R13, R13, #FlpDACK_TC_Offset ; r13 now set

 [ Debug10 :LOR: Debug10t
        MOV     r1, #ScratchSpace
        STMIA   r1, {r8-r13}
        MRS     r1, CPSR
        MSR     CPSR_c, #F32_bit+I32_bit+SVC32_mode
        Push    "r0,r2,lr"
        MOV     r2, #ScratchSpace
        LDR     r0, [r2, #0]
        DREG    r0, "SetupRead_BG->(",cc
        LDR     r0, [r2, #4]
        DREG    r0, ",",cc
        LDR     r0, [r2, #8]
        DREG    r0, ",",cc
        LDR     r0, [r2, #12]
        DREG    r0, ",",cc
        LDR     r0, [r2, #16]
        DREG    r0, ",",cc
        LDR     r0, [r2, #20]
        DREG    r0, ",",cc
        MOV     r0, #FlpReadThisRover - FlpReadFIQ_BG + FiqVector
        LDR     r0, [r0]
        DREG    r0, ",Rover=",cc
        DLINE   ")"
        Pull    "r0,r2,lr"
        MSR     CPSR_c, r1
 ]
        MOV     PC, LR
 ]

        LTORG

; -----------------------------------------------------------------------
; FlpAdvanceTransfer
;
; In
;       r2 -> DCB
;
; Out
;       Transfer advanced to restart/completion point.
;
FlpAdvanceTransfer ROUT
        Push    "r0,lr"

        LDR     r0, [r2, #FlpDCBlength]
        TST     r0, #FlpDCBscatter
        JumpAddress lr,FlpATRet,forward
        BEQ     FlpAdvanceNonScatterTransfer

        ; Scatter transfer
        LDRB    r0, [r2, #FlpDCBbgnd]
        TEQ     r0, #0
        BEQ     FlpAdvanceForegroundTransfer
        BNE     FlpAdvanceBackgroundTransfer

FlpATRet
        ; Move restart results to command
        LDRB    r1, [r2, #FlpDCBresults+3]      ; C
        STRB    r1, [r2, #FlpDCBcdb+2]
        LDRB    r1, [r2, #FlpDCBresults+4]      ; H
        STRB    r1, [r2, #FlpDCBcdb+3]
        LDRB    r1, [r2, #FlpDCBresults+6]      ; N
        STRB    r1, [r2, #FlpDCBcdb+5]
        LDRB    r1, [r2, #FlpDCBresults+5]      ; R
 [ FlpUseVerify
        LDRB    lr, [r2, #FlpDCBcdb+9]
        LDRB    r0, [r2, #FlpDCBcdb+4]          ; r0 = original R
 ]
        STRB    r1, [r2, #FlpDCBcdb+4]          ; r1 = final R

 [ FlpUseVerify
        TEQ     lr, #&FF
        BNE     %FT01
; For verify, need to decrement sector count
        LDRB    lr, [r2, #FlpDCBcdb+8]
        ADD     lr, lr, r0
        SUB     lr, lr, r1
        STRB    lr, [r2, #FlpDCBcdb+8]
01
 ]

        Pull    "r0,pc"

; -----------------------------------------------------------------------
; FlpAdvanceNonScatterTransfer
;
; In
;       r2 -> DCB
;
; Out
;       Transfer advanced to restart/completion point.
;
; As advance transfer, but does foreground specific parts only
;
FlpAdvanceNonScatterTransfer ROUT
        Push    "r0,r1,r3,lr"

 [ FloppyPCI
        LDR     r0, FlpDMACount
 |
        WritePSRc I_bit + F_bit + FIQ_mode,r1,,r3

        ; r0 = bytes left to transfer
        MOV     r0, r12

        RestPSR r3

        CMP     r0, #0
        MOVMI   r0, #0

        ; r0 = bytes transfered
        LDR     r1, [r2, #FlpDCBlength]
        BIC     r1, r1, #FlpDCBflags
        SUB     r0, r1, r0
 ]

 [ Debug10
        DREG    r0, "Advance transfer by "
 ]

        LDR     r1, [r2, #FlpDCBlength]
        SUB     r1, r1, r0
        STR     r1, [r2, #FlpDCBlength]
 [ Debug10
        DREG    r1, "DCBlength now ",cc
 ]
        LDR     r1, [r2, #FlpDCBtxbytes]
        ADD     r1, r1, r0
        STR     r1, [r2, #FlpDCBtxbytes]
 [ Debug10
        DREG    r1, ", txbytes now ",cc
 ]
        LDR     r1, [r2, #FlpDCBbuffer]
        ADD     r1, r1, r0
        STR     r1, [r2, #FlpDCBbuffer]
 [ Debug10
        DREG    r1, " and DCBbuffer now "
 ]

        Pull    "r0,r1,r3,pc"

; -----------------------------------------------------------------------
; FlpAdvanceForegroundTransfer
;
; In
;       r2 -> DCB
;
; Out
;       Transfer advanced to restart/completion point.
;
; As advance transfer, but does foreground specific parts only
;
FlpAdvanceForegroundTransfer ROUT
        Push    "r0,r1,r3,lr"

 [ FloppyPCI
        LDR     r0, FlpDMACount
 |
        WritePSRc I_bit + F_bit + FIQ_mode,r0,,r3

        ; r0 = bytes left to transfer
        MOV     r0, r12

        RestPSR r3

 [ Debug10t
        DREG    r0, "Bytes left="
 ]
        CMP     r0, #0
        MOVMI   r0, #0

        ; r0 = bytes transfered
        LDR     r1, [r2, #FlpDCBlength]
        BIC     r1, r1, #FlpDCBflags
        SUB     r0, r1, r0
 ]

        ; Determine how many sectors have been transfered from results
        BL      FlpController_TransferSize

        ; Advance not more than the finished sector's worth
        CMP     r0, r1
        MOVHI   r0, r1

        BL      FlpAdvanceScatter
        Pull    "r0,r1,r3,pc"


; -----------------------------------------------------------------------
; FlpAdvanceBackgroundTransfer
;
; In
;       r2 -> DCB
;
; Out
;       Transfer advanced to restart/completion point.
;
; As advance transfer, but does background specific parts only
;
FlpAdvanceBackgroundTransfer ROUT
        Push    "r0,r1,lr"

        ; Pick up scatter we're certain about and adjust DCB
 [ FloppyPCI
        LDR     r0, FlpDMACount
        BL      FlpController_TransferSize
 [ Debug10t
        DREG    r0, "transfer routine's transfered "
        DREG    r1, "controller's transfered "
 ]

        ; Advance not more than the finished sector's worth
        CMP     r0, r1
        MOVHI   r0, r1

        BL      FlpAdvanceScatter
 |
        LDR     lr, [r2, #FlpDCBlength]
        ; Well, actually it's for the '665
        WritePSRc I_bit + F_bit + FIQ_mode,r0,,r1
        MOV     r0, r12
        RestPSR r1
 [ Debug10s :LAND: {FALSE}
        NOP
        LDR     lr, [r2, #FlpDCBbuffer]
        Push    "lr"
 ]
        TEQ     r0, #1
        STRNE   r0, [r2, #FlpDCBbuffer]
 [ Debug10t
        DREG    r0, "Scatter pointer at end is "
 ]

        ; Work amount definitely transfered
        LDR     r0, [r2, #FlpDCBtxgobytes]
        LDR     r1, [r2, #FlpDCBtxbytes]
        SUB     r0, r1, r0

        ; Check if there's more...
        BL      FlpController_TransferSize
 [ Debug10t
        DREG    r0, "transfer routine's transfered "
        DREG    r1, "controller's transfered "
 ]

        ; Reduce Length by amount transfered by transfer routine
        LDR     lr, [r2, #FlpDCBlength]
        SUB     lr, lr, r0
        STR     lr, [r2, #FlpDCBlength]
 [ Debug10t
        DREG    lr, "DCBlength is now "
 ]

        ; If controller's transfered more, then advance by that amount
        CMP     r0, r1
        SUBLO   r0, r1, r0
 [ Debug
        SavePSR lr
        Push    "lr"
        BLO     %FT01
        DLINE   "NO BACKGROUND SCATTER ADVANCE"
01
        MRS     lr, CPSR
        TST     lr, #I32_bit
        BNE     %FT02
        DLINE   "IRQs ENABLED WHILST ADVANCING SCATTER LIST"
02
        TEQ     r0, #1024
        BEQ     %FT03
        DREG    r0, "SCATTER ADVANCE ISN'T EXACTLY ONE SECTOR:"
03
        Pull    "lr"
        RestPSR lr
 ]
        BLLO    FlpAdvanceScatter                  ; There's more the controller's taken
 ]

 [ Debug10s :LAND: {FALSE}
        Pull    "r0"
        LDR     r1, [r2, #FlpDCBbuffer]
        DREG    r0,,cc
        DREG    r1,"->",cc
10
        LDR     lr, [r0, #0]
        DREG    lr, " (",cc
        LDR     lr, [r0, #4]
        DREG    lr, ",",cc
        DLINE   ")",cc
        TEQ     r0, r1
        BEQ     %FT20
        LDR     lr, [r0, #0]
 [ FixTBSAddrs
        CMN     lr, #ScatterListNegThresh
        ADDCS   r0, r0, lr
        ADDCC   r0, r0, #8
 |
        TEQ     lr, #0
        ADDMI   r0, r0, lr
        ADDPL   r0, r0, #8
 ]
        TEQ     r0, r1
        B       %BT10
20
        DLINE   ""
 ]

        Pull    "r0,r1,pc"


; -----------------------------------------------------------------------
; FlpAdvanceScatter
;
; In
;       r0 = length to advance by
;       r2 -> DCB
;
; Out
;       Scatter and transfer counts advanced by amount specified
;
FlpAdvanceScatter ROUT
        Push    "r0,r1,r3,r4,r5,lr"
 [ Debug10
        DREG    r0, "Advance scatter by "
 ]

        ; Advance txbytes
        LDR     r1, [r2, #FlpDCBtxbytes]
        ADD     r1, r1, r0
        STR     r1, [r2, #FlpDCBtxbytes]
 [ Debug10
        DREG    r1, "txbytes now ",cc
 ]

        ; Reduce Length
        LDR     r1, [r2, #FlpDCBlength]
        SUB     r1, r1, r0
        STR     r1, [r2, #FlpDCBlength]
 [ Debug10
        DREG    r1, " and DCBlength now "
 ]

        ; Advance scatter list
        LDR     r1, [r2, #FlpDCBbuffer]
        LDRB    r5, [r2, #FlpDCBbgnd]
        B       %FT20
10
        ; Disable IRQs
;        MOV     lr, pc
;        TST     lr, #I_bit
;        TEQEQP  lr, #I_bit

        ; Obtain scatter
        LDMIA   r1, {r3, r4}
 [ Debug10s
        DREG    r3,"^",cc
        DREG    r4,",",cc
 ]

        ; Is scatter > amount left?
        CMP     r4, r0

        ; If scatter > amount left then reduce by amount left and amount left is 0
        ADDHI   r3, r3, r0
        SUBHI   r4, r4, r0
        MOVHI   r0, #0
 [ Debug10s
        BLS     %FT01
        DREG    r3,"v",cc
        DREG    r4,",",cc
01
 ]
        STMHIIA r1, {r3, r4}

        ; else scatter <= amount left so use scatter entry and reduce amount left
        ADDLS   r3, r3, r4
        SUBLS   r0, r0, r4
        MOVLS   r4, #0
 [ Debug10s
        BHI     %FT01
        DREG    r3,"w",cc
        DREG    r4,",",cc
01
 ]
        STMLSIA r1!, {r3, r4}

        ; Restore IRQs to old state
;        TEQP    pc, lr
15
        ; Check for wrapping in bg transfers
        TEQ     r5, #0
        BEQ     %FT20
        LDR     r3, [r1]
 [ FixTBSAddrs
        CMN     r3, #ScatterListNegThresh
        ADDCS   r1, r1, r3
 |
        TEQ     r3, #0
        ADDMI   r1, r1, r3
 ]
20
        CMP     r0, #0
        BHI     %BT10

        STR     r1, [r2, #FlpDCBbuffer]

        Pull    "r0,r1,r3,r4,r5,pc"


; -----------------------------------------------------------------------
; FlpLimitLengthToScatterList
;
; In
;       r3 -> background scatter list
;       r4 = length
;
; Out
;       r4 = min(list length, input r4)
;

FlpLimitLengthToScatterList
        Push    "R3,R5,LR"
        MOV     R14, #0
10      LDR     R5, [R3, #0]
 [ FixTBSAddrs
        CMN     R5, #ScatterListNegThresh
        ADDHS   R3, R5, R3
 |
        TEQ     R5, #0
        ADDMI   R3, R5, R3
 ]
        LDR     R5, [R3, #4]
        TEQ     R5, #0
        BEQ     %FT90
        ADD     R14, R14, R5
        CMP     R14, R4
        ADDLS   R3, R3, #8
        BLO     %BT10
90      CMP     R14, R4
        MOVLO   R4, R14
        Pull    "R3,R5,PC"

; -----------------------------------------------------------------------
; FlpController_TransferSize
;
; In
;       r2 -> DCB
;
; Out
;       r1 = amount controller transfered [(end sector-start sector)*sector size]
;
FlpController_TransferSize ROUT
        Push    "r3,lr"

        ; If advanced to a different track return DCBlength instead
        LDRB    r3, [r2, #FlpDCBresults+4]      ; H!=H?
        LDRB    lr, [r2, #FlpDCBcdb+3]
        TEQ     r3, lr
        LDREQB  r3, [r2, #FlpDCBresults+3]      ; OR C!=C?
        LDREQB  lr, [r2, #FlpDCBcdb+2]
        TEQEQ   r3, lr
        LDRNE   r1, [r2, #FlpDCBlength]
        BICNE   r1, r1, #FlpDCBflags
        Pull    "r3,pc",NE

        ; Else size of transfer is size of sector difference between start and end
        LDRB    r1, [r2, #FlpDCBresults+5]      ; end sector number
        LDRB    r3, [r2, #FlpDCBcdb+4]          ; start sector number
        SUB     r1, r1, r3

        LDRB    r3, [r2, #FlpDCBcdb+5]
        ADD     r3, r3, #7
        MOV     r1, r1, ASL r3                  ; sectors worth of bytes
        Pull    "r3,pc"

; -----------------------------------------------------------------------

 [ FloppyPCI

FlpDMATerminate ROUT
        Push    "R0-R2,LR"
        LDR     R1, FlpDMATag
        CMP     R1, #-1
        BEQ     %FT99
        MRS     R2, CPSR
        ORR     R1, R2, #3
        MSR     CPSR_c, R1
        Push    "LR"
        MOV     R0, #0
        LDR     R1, FlpDMATag
        CMP     R1, #-1
        SWINE   XDMA_TerminateTransfer
        Pull    "LR"
        MSR     CPSR_c, R2
99
        Pull    "R0-R2,PC"

FlpDMAQueueTransfer ROUT
 [ Debug10d
        DREG    R0,"DMA_QueueTransfer(",cc
        DREG    R1,",",cc
        DREG    R2,",",cc
        DREG    R3,",",cc
        DREG    R4,",",cc
        DLINE   ")"
 ]
        CMP     R4, #0
        MOVEQ   R0, #-1
        MOVEQ   PC, LR
        Push    "R10,LR"
        MRS     R10, CPSR
        ORR     R14, R10, #3
        MSR     CPSR_c, R14
        Push    "LR"
        SWI     XDMA_QueueTransfer
        Pull    "LR"
        MSR     CPSR_c, R10
        Pull    "R10,PC"

FlpDMAExamineTransfer ROUT
        Push    "R4,LR"
        MRS     R4, CPSR
        ORR     R14, R4, #3
        MSR     CPSR_c, R14
        Push    "LR"
        SWI     XDMA_ExamineTransfer
        Pull    "LR"
        MSR     CPSR_c, R4
        Pull    "R4,PC"
 ]

;-----------------------------------------------------------------------;
; FlpHandlerReadID                                                      ;
;       Message handler for ReadID type FDC command.                    ;
;       Reads the next sector ID if buffer size is 0 or as many from the;
;       specified track that fit into the buffer, starting with the     ;
;       first sector after the index pulse and stopping at the next     ;
;       index pulse.  Each ID requires 4 bytes and is arranged:         ;
;                                                                       ;
;               Cylinder No., Head No, Sector No., Sector Size          ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Message                                                    ;
;       R1 = Parameter                                                  ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpHandlerReadID ROUT
 [ No32bitCode
        Push    "LR"
        BL      %FT00
        Pull    "PC",,^
 |
        Push    "R6,LR"
        MRS     R6, CPSR
        BL      %FT00
        MSR     CPSR_cf, R6
        Pull    "R6,PC"
 ]
00
        CMPS    R0, #FlpEventIRQ        ; FDC interrupt?
        BEQ     %FT60                   ; Yes then jump
        CMPS    R0, #FlpMsgIP           ; Drive ready index pulse?
        BEQ     %FT20                   ; Yes then jump
        CMPS    R0, #FlpMsgSeekDone     ; Seek complete?
        BEQ     %FT30                   ; Yes then jump
        CMPS    R0, #FlpMsgStart        ; Initialise?
        BEQ     %FT10                   ; Yes then jump
        CMPS    R0, #FlpMsgResetOK      ; Reset complete?
        BEQ     %FT80                   ; Yes then jump
        CMPS    R0, #FlpMsgError        ; Fatal error?
        BEQ     %FT05                   ; Yes then jump
        CMPS    R0, #FlpMsgESC          ; Escape?
        MOVNE   PC, LR                  ; No then return

; Handle escape message

        Push    "LR"
        LDRB    LR, [R2, #FlpDCBesc]    ; Get escape enable flag
        TEQS    LR, #0                  ; Escapes enabled?
        Pull    "LR"
        MOVNE   PC, LR                  ; No then exit

; Handle error message, R1= error code
05
        Push    "R0,LR"
        LDRB    LR, [R2, #FlpDCBphase]
        TEQS    LR, #FlpPhaseIdle       ; Idle phase?
        BLNE    Flp765reset             ; No then reset FDC

        MOV     LR, #0
        STR     LR, [R2, #FlpDCBlength] ; No data transferred
        TEQ     R1, #FlpErrTimeOut      ; Command timed out?
        MOVEQ   R0, #FlpErrNoIDs        ; Yes then no IDs
        MOVNE   R0, R1                  ; Else get error code
        BL      FlpDqDCB                ; Terminate DCB (R0,R2->)
        Pull    "R0,PC"


; Process initialization message, R2->DCB
10
        Push    "R0,R1,LR"
        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    R0, #FlpPhaseIdle       ; Idle phase?
        Pull    "R0,R1,PC",NE           ; No then exit

; Select requested drive

        SETPSR  I_bit, LR               ; Disable IRQ's

        LDRB    R1, [R2, #FlpDCBcdb+1]  ; Get drive select
        AND     R1, R1, #3              ; Retain drive select bits
        MOV     R0, #FlpEventDrvSel     ; Drive select event
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpDrive            ; Call drive state system (R0,R1->R0)

        MOV     LR, #FlpPhaseDrv        ; Next phase is awaiting drive ready
        STRB    LR, [R2, #FlpDCBphase]  ; Update phase
        TSTS    R0, #MiscOp_PollChanged_Empty_Flag+MiscOp_PollChanged_Ready_Flag ; Drive empty or ready?
        Pull    "R0,R1,PC",EQ           ; No then restore regs and wait

        TSTS    R0, #MiscOp_PollChanged_Empty_Flag          ; Drive empty?
        MOVNE   R0, #DriveEmptyErr      ; Yes, drive empty error
        BLNE     FlpDqDCB               ;   then terminate DCB (R0,R2->)
        Pull    "R0,R1,LR"
        MOVNE   PC, LR                  ;   then exit

; Drive is ready, fall thru to drive ready message

 [ No32bitCode
        TEQP    LR, #0                  ; Restore IRQ state
 |
        RestPSR R6                      ; Restore IRQ state
 ]

; Process drive ready message (index pulse), R2->DCB
20
        Push    "LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
        TEQS    LR, #FlpPhaseIRQip      ; Expecting IP or IRQ?
        Pull    "LR",EQ                 ; Yes restore regs
        BEQ     %FT75                   ; And jump

        TEQS    LR, #FlpPhaseIP         ; Awaiting IP?
        Pull    "LR",EQ                 ; Yes restore regs
        BEQ     %FT40                   ; And jump

        TEQS    LR, #FlpPhaseDrv        ; Phase is awaiting drive ready?
        Pull    "LR"
        MOVNE   PC, LR                  ; No then exit

; Ensure '765 FDC has completed reset

        Push    "R0,R1,LR"
        MOV     LR, #FlpPhaseReset      ; Assume waiting for reset
        STRB    LR, [R2, #FlpDCBphase]  ; Update phase
        baddr   R0, FlpStateReset       ; Reset state address
        LDR     LR, FlpState            ; Get current FDC state
        CMPS    LR, R0                  ; Currently reset?
        Pull    "R0,R1,PC",EQ           ; Yes then wait

; Lock the drive during execution

        LDRB    LR, FlpDriveLock        ; Get lock state
        ORR     LR, LR, #bit0+bit2      ; Set command lock bit, inhibit empty
        STRB    LR, FlpDriveLock        ; Update lock state

; Implied seek required?

        LDRB    R0, [R2, #FlpDCBcdb+1]  ; Get drive/head/implied seek
        TSTS    R0, #bit7               ; Implied seek?
        Pull    "R0,R1,LR",EQ           ; No, then restore regs
        BEQ     %FT40                   ;   and jump, issue command

; Request seek to required track

        MOV     LR, #FlpPhaseSeek       ; Next phase is waiting for seek done
        STRB    LR, [R2, #FlpDCBphase]  ; Update command phase
        MOV     R1, R2                  ; Get->DCB
        MOV     R0, #FlpEventSeek
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpState            ; Call state system (R0,R1->V)

        MOVVS   R0, #FlpErrSeekFault    ; Return seek fault if error
        BLVS    FlpDqDCB                ;   and terminate DCB (R0,R1->)
        Pull    "R0,R1,PC",VS           ;   and return

        TEQS    R0, #0                  ; Seek in progress?
        Pull    "R0,R1,LR"
        MOVNE   PC, LR                  ; Yes then exit


; Process seek done message, R2->DCB
30
        Push    "LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
        TEQS    LR, #FlpPhaseSeek       ; Phase is awaiting seek done?
        Pull    "PC",NE                 ;�No then exit

; Ensure ReadID starts immediately after an index pulse.

        LDR     LR, [R2, #FlpDCBlength] ; Get buffer size
        TEQS    LR, #0                  ; Zero?
        MOVNE   LR, #FlpPhaseIP         ; No, next phase is awaiting IP
        STRNEB  LR, [R2, #FlpDCBphase]  ; Update DCB phase
        Pull    "LR"
        MOVNE   PC, LR                  ; No, exit - wait for IP

; Issue ReadID command
40
        Push    "R0,R1,LR"
        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        TEQS    R0, #FlpPhaseIRQip      ; IRQ or IP phase
        MOVNE   R0, #FlpPhaseIRQ        ; No then goto IRQ phase
        STRNEB  R0, [R2, #FlpDCBphase]  ; And update phase

        LDRB    LR, FlpDriveLock        ; Get lock state
        BIC     LR, LR, #bit2           ; Enable empty timer
        STRB    LR, FlpDriveLock        ; Update lock state

        MOV     LR, #2                  ; 2 byte command
        STRB    LR, [R2, #FlpDCBcmdLen] ; Write command length

        MOV     R0, #FlpEventCmd        ; Command request
        MOV     R1, R2                  ; R1->DCB
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpState            ; Call state system (R0,R1->V)
        MOVVS   R0, #BadComErr          ; Return bad command if error in FDC
        BLVS    FlpDqDCB                ; Terminate DCB if error occurred
        Pull    "R0,R1,PC"              ; Restore regs


; Process IRQ message
60
        Push    "R0,R1,R3,LR"
        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        TEQS    R0, #FlpPhaseIRQ        ; Phase is awaiting results?
        TEQNES  R0, #FlpPhaseIRQip      ; Or awaiting IRQ or IP
        TEQNES  R0, #FlpPhaseDone       ; Or done
        Pull    "R0,R1,R3,PC",NE        ; No then exit

; Command completed, get '765 FDC results, R2->DCB

        MOV     R3, #7                  ; 7 result bytes
        ADD     R1, R2, #FlpDCBresults  ; Yes R1-> result buffer

65      BL      Flp765read              ; Get result byte
        MOVVS   R0, #BadParmsErr        ; Bad parameters if can't read all results
        BVS     %FT69                   ; Jump if error
        STRB    R0, [R1], #1            ; Save result in DCB, R1++
 [ {FALSE}    ; LA trigger for debugging IDE interaction
        CMPS    R3, #2                  ; Next byte is last?
        LDREQ   LR, FlpBase             ; FDC register base (&3F0 in PC/AT)
        LDREQB  LR, [LR, #FlpStatusA]   ; Yes, read CnTbase + &FC0
 ]
        SUBS    R3, R3, #1              ; 1 less result
        BNE     %BT65                   ; Loop for all results

; Check for errors

        LDRB    R0, [R2, #FlpDCBresults] ; Get ST0
        TSTS    R0, #&C0                ; Bad completion?
        BNE     %FT70                   ; Yes then jump

        LDR     R0, [R2, #FlpDCBlength] ; Get buffer size
        TEQS    R0, #0                  ; Zero?
        BEQ     %FT69                   ; Yes then exit

; Copy sector ID to buffer

        MOV     R3, #4                  ; 4 sector ID bytes
        ADD     R0, R2, #FlpDCBresults+3 ; R0-> ID bytes
        LDR     R1, [R2, #FlpDCBbuffer] ; R1-> buffer address
67      LDRB    LR, [R0], #1            ; Get ID, R0++
        STRB    LR, [R1], #1            ; Copy it, R1++
        SUBS    R3, R3, #1
        BNE     %BT67                   ; For all bytes

        STR     R1, [R2, #FlpDCBbuffer] ; Save new buffer ptr

        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        TEQS    R0, #FlpPhaseDone       ; Read all track?
        MOVEQ   R0, #0                  ; Yes then no errors
        BEQ     %FT69                   ; And then exit

        MOV     R0, #FlpPhaseIRQip      ; Next phase is�awaiting IRQ or IP
        STRB    R0, [R2, #FlpDCBphase]  ; Update DCB phase

; Update buffer size remaining

        LDR     R0, [R2, #FlpDCBlength]
        SUBS    R0, R0, #4              ; Decrement length
        STR     R0, [R2, #FlpDCBlength] ; Update length
        Pull    "R0,R1,R3,LR",HI        ; Restore regs if more left
        BHI     %BT40                   ; And read next ID

        MOV     R0, #0                  ; Else all done, no error
69      BL      FlpDqDCB                ; Terminate DCB (R0,R2->)
        Pull    "R0,R1,R3,PC"           ; And exit

; Retry faulty operation

70      LDRB    R0, [R2, #FlpDCBretries]
        SUBS    R0, R0, #1              ; Knock retry counter
        STRPLB  R0, [R2, #FlpDCBretries] ; Update it
        MOVMI   R0, #FlpDiscError       ; Error if retries exhausted
        BMI     %BT69                   ; And exit

 [ Debug10
        DREG    R0, "ReadID retry# ",cc
        DREG    R1, " ST1: "
 ]
        MOV     LR, #FlpPhaseSeek
        STRB    LR, [R2, #FlpDCBphase]  ; Change to seek phase
        Pull    "R0,R1,R3,LR"           ; Restore regs
        B       %BT30                   ; Retry operation

; End of track index pulse received
75
        Push    "LR"
        MOV     LR, #FlpPhaseDone
        STRB    LR, [R2, #FlpDCBphase]  ; Goto done phase
        Pull    "PC"                    ; Exit


; Process reset OK message
80
        Push    "LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    LR, #FlpPhaseReset      ; Phase is awaiting reset?
        Pull    "PC",NE                 ; No then exit

; Reset complete

        MOV     LR, #FlpPhaseDrv        ; Awaiting drive ready
        STRB    LR, [R2, #FlpDCBphase]  ; Update command phase
        Pull    "LR"
        B       %BT20                   ; Simulate drive ready



;-----------------------------------------------------------------------;
; FlpHandlerSeek                                                        ;
;       Message handler for seek and recalibrate commands.              ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Message                                                    ;
;       R1 = Parameter                                                  ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpHandlerSeek  ROUT
 [ No32bitCode
        Push    "LR"
        BL      %FT00
        Pull    "PC",,^
 |
        Push    "R6,LR"
        MRS     R6, CPSR
        BL      %FT00
        MSR     CPSR_cf, R6
        Pull    "R6,PC"
 ]
00
        CMPS    R0, #FlpEventIRQ        ; FDC interrupt?
        BEQ     %FT60                   ; Yes then jump
        CMPS    R0, #FlpMsgIP           ; Drive ready index pulse?
        BEQ     %FT20                   ; Yes then jump
        CMPS    R0, #FlpMsgStart        ; Initialise?
        BEQ     %FT10                   ; Yes then jump
        CMPS    R0, #FlpMsgResetOK      ; Reset complete?
        BEQ     %FT80                   ; Yes then jump
        CMPS    R0, #FlpMsgError        ; Fatal error?
        MOVNE   PC, LR                  ; No then return

; Handle error message, R1= error code

        Push    "R0,LR"
        TEQS    R1, #DriveEmptyErr      ; Drive empty error?
        LDREQB  LR, [R2, #FlpDCBtimeOut]
        TEQEQS  LR, #0                  ; And no timeout?
        Pull    "R0,PC",EQ              ; Yes ignore it

        LDRB    LR, [R2, #FlpDCBphase]
        TEQS    LR, #FlpPhaseIdle       ; Idle phase?
        BLNE    Flp765reset             ; No then reset FDC

        MOV     R0, R1                  ; Get error code
        BL      FlpDqDCB                ; Terminate DCB (R0,R2->)
        Pull    "R0,PC"


; Process initialization message, R2->DCB
10
        Push    "R0,R1,LR"
        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    R0, #FlpPhaseIdle       ; Idle phase?
        Pull    "R0,R1,PC",NE           ; No then exit

; Select requested drive

        SETPSR  I_bit, lr               ; Disable IRQ's

        LDRB    R1, [R2, #FlpDCBcdb+1]  ; Get drive select
        AND     R1, R1, #3              ; Retain drive select bits
        MOV     R0, #FlpEventDrvSel     ; Drive select event
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpDrive            ; Call drive state system (R0,R1->R0)

        MOV     LR, #FlpPhaseDrv        ; Next phase is awaiting drive ready
        STRB    LR, [R2, #FlpDCBphase]  ; Update phase

        LDRB    LR, [R2, #FlpDCBtimeOut]
        TEQS    LR, #0                  ; Timeout's disabled?
        Pull    "R0,R1,LR",EQ
        BEQ     %FT20                   ; Yes then jump

        TSTS    R0, #MiscOp_PollChanged_Empty_Flag+MiscOp_PollChanged_Ready_Flag ; Drive empty or ready?
        Pull    "R0,R1,PC",EQ           ; No then restore regs and wait

        TSTS    R0, #MiscOp_PollChanged_Empty_Flag          ; Drive empty?
        MOVNE   R0, #DriveEmptyErr      ; Yes, drive empty error
        BLNE     FlpDqDCB               ;   then terminate DCB (R0,R2->)
        Pull    "R0,R1,LR"
        MOVNE   PC, LR                  ;   then exit

; Drive is ready, fall thru to drive ready message


; Process drive ready message (index pulse), R2->DCB
20
        Push    "LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
        TEQS    LR, #FlpPhaseDrv        ; Phase is awaiting drive ready?
        Pull    "LR"
        MOVNE   PC, LR                  ; No then exit

; Ensure '765 FDC has completed reset

        Push    "R0,R1,LR"
        SETPSR  I_bit, LR               ; Ensure IRQ's disabled
        MOV     LR, #FlpPhaseReset      ; Assume waiting for reset
        STRB    LR, [R2, #FlpDCBphase]  ; Update phase
        baddr   R0, FlpStateReset       ; Reset state address
        LDR     LR, FlpState            ; Get current FDC state
        CMPS    LR, R0                  ; Currently reset?
        Pull    "R0,R1,LR"
        MOVEQ   PC, LR                  ; Yes then wait

; Lock the drive during execution
25
        Push    "R0,R1,LR"
        SETPSR  I_bit, LR               ; Ensure IRQ's disabled
        LDRB    LR, FlpDriveLock        ; Get lock state
        ORR     LR, LR, #bit0+bit2      ; Set command lock bit, inhibit empty
        STRB    LR, FlpDriveLock        ; Update lock state

        LDRB    R0, [R2, #FlpDCBselect] ; Get clock requested
        BL      Flp765specify           ; Set drive step rate

        MOV     R0, #FlpPhaseIRQ        ; Goto IRQ phase
        STRB    R0, [R2, #FlpDCBphase]  ; Update phase

        LDRB    LR, [R2, #FlpDCBcdb]    ; Get command
        TEQS    LR, #FlpCmdRecal        ; Recalibrate?
        MOVEQ   LR, #2                  ; Yes 2 byte command
        MOVNE   LR, #3                  ; Else 3 byte seek command
        STRB    LR, [R2, #FlpDCBcmdLen] ; Write command length

        MOV     R0, #FlpEventCmd        ; Command request
        MOV     R1, R2                  ; R1->DCB
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpState            ; Call state system (R0,R1->V)
        MOVVS   R0, #BadComErr          ; Return bad command if error in FDC
        BLVS    FlpDqDCB                ; Terminate DCB if error occurred

        Pull    "R0,R1,PC"              ; Restore regs


; Process IRQ message
60
        Push    "R0,R1,R3,LR"
        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        TEQS    R0, #FlpPhaseIRQ        ; Phase is awaiting results?
        Pull    "R0,R1,R3,PC",NE        ; No then exit

; Seek/restore completed, get '765 FDC results, R2->DCB

        BL      FlpIRQstatus            ; Request interrupt status (->R0,R1,V)
        MOVVS   R0, #FlpErrFDC          ; FDC error if VS
        BVS     %FT69                   ; Jump if error

        LDRB    LR, FlpDrvNum           ; Get current drive
        AND     LR, LR, #3              ; 0..3
        DrvRecPtr R3, LR                ; Get ->  current drive record

; Check for errors

        TSTS    R1, #&C0                ; Bad completion?
        ORRNE   R0, R0, #PositionUnknown ; Yes then ensure restore next
 [ {FALSE}
        DREG    R1, "Seek ST0: ",cc
        DREG    R0, " PCN: "
 ]
        STR     R0, [R3, #HeadPosition] ; Save new head position
        STRB    R0, [R2, #FlpDCBresults+1] ; Save PCN
        STRB    R1, [R2, #FlpDCBresults] ; Save ST0
        BNE     %FT70                   ; Jump if error

        MOV     R0, #0                  ; Else no error
69      BL      FlpDqDCB                ; Terminate DCB (R0,R2->)
        Pull    "R0,R1,R3,PC"

; Retry faulty operation

70      LDRB    R0, [R2, #FlpDCBretries]
        SUBS    R0, R0, #1              ; Knock retry counter
        STRPLB  R0, [R2, #FlpDCBretries] ; Update it
        MOVMI   R0, #FlpDiscError       ; Error if retries exhausted
        BMI     %BT69                   ; And exit

 [ Debug10
        DREG    R0, "Seek Retry# ",cc
        DREG    R1, " ST0: "
 ]
        Pull    "R0,R1,R3,LR"
        B       %BT25                   ; Else retry operation


; Process reset OK message
80
        Push    "LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    LR, #FlpPhaseReset      ; Phase is awaiting reset?
        Pull    "LR"
        MOVNE   PC, LR                  ; No then exit
        B       %BT25                   ; Simulate drive ready


;-----------------------------------------------------------------------;
; FlpHandlerDrv                                                         ;
;       Message handler for sense drive status type FDC command         ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Message                                                    ;
;       R1 = Parameter                                                  ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpHandlerDrv   ROUT
 [ No32bitCode
        Push    "LR"
        BL      %FT00
        Pull    "PC",,^
 |
        Push    "R6,LR"
        MRS     R6, CPSR
        BL      %FT00
        MSR     CPSR_cf, R6
        Pull    "R6,PC"
 ]
00
        CMPS    R0, #FlpMsgIP           ; Index pulse?
        BEQ     %FT20                   ; Yes then jump
        CMPS    R0, #FlpMsgSeekDone     ; Seek complete?
        BEQ     %FT30                   ; Yes then jump
        CMPS    R0, #FlpMsgStart        ; Initialise?
        BEQ     %FT10                   ; Yes then jump
        CMPS    R0, #FlpMsgResetOK      ; Reset complete?
        BEQ     %FT80                   ; Yes then jump
        CMPS    R0, #FlpMsgError        ; Fatal error?
        MOVNE   PC, LR                  ; No then return

; Handle error message, R1= error code

        TEQS    R1, #DriveEmptyErr      ; Drive empty error?
        MOVNE   PC, LR                  ; No then exit

        Push    "LR"
        LDRB    LR, [R2, #FlpDCBphase]
        TEQS    LR, #FlpPhaseDrv        ; Awaiting drive ready?
        Pull    "LR"
        MOVNE   PC, LR                  ; No then exit
        B       FlpGetDrvStatus         ; Get status and terminate DCB


; Process initialization message, R2->DCB
10
        Push    "R0,R1,LR"
        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    R0, #FlpPhaseIdle       ; Idle phase?
        Pull    "R0,R1,PC",NE           ; No then exit

        SETPSR  I_bit,LR                ; Disable IRQ's

; Select requested drive

        LDRB    R1, [R2, #FlpDCBcdb+1]  ; Get drive select
        AND     R1, R1, #3              ; Retain drive select bits
        MOV     R0, #FlpEventDrvSel     ; Drive select event
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpDrive            ; Call drive state system (R0,R1->R0)

        STR     R0, [R2, #FlpDCBresults+4] ; Save drive status
        LDRB    LR, [R2, #FlpDCBcdb+1]  ; Get drive/head/implied seek
        TSTS    LR, #bit7               ; Implied seek?
        BLEQ    FlpGetDrvStatus         ; No, then get status
        Pull    "R0,R1,PC",EQ           ;   And restore regs and exit

        TSTS    R0, #MiscOp_PollChanged_Ready_Flag          ; Drive ready?
        BNE     %FT15                   ; Yes then jump
        TSTS    R0, #MiscOp_PollChanged_Empty_Flag          ; Drive empty?
        BLNE    FlpGetDrvStatus         ; Yes then get status
        Pull    "R0,R1,PC",NE           ;  and exit

; Check state of disk change from drive

15      MOV     R1, R0                  ; Save drive status
        BL      FlpGetDskChng           ; Read disk changed (->R0)
        TSTS    R0, #FlpDIRchanged      ; Disk changed from drive?
        BLEQ    FlpGetDrvStatus         ; No then get status
        Pull    "R0,R1,PC",EQ           ;  and exit, not changed
        MOV     R0, R1                  ; Restore drive status
 [ Debug10
        DLINE   "DskChng detected ",cc
 ]

; Drive reports changed

        LDRB    LR, FlpDriveLock        ; Get lock state
        ORR     LR, LR, #bit0+bit2      ; Set command lock bit
        STRB    LR, FlpDriveLock        ; Update lock state

        MOV     LR, #FlpPhaseDrv        ; Phase is awaiting drive ready
        STRB    LR, [R2, #FlpDCBphase]  ; Update command phase
        TSTS    R0, #MiscOp_PollChanged_Ready_Flag          ; Drive ready?
        Pull    "R0,R1,LR"
        MOVEQ   PC, LR                  ; No then wait exit


; Process index pulse message, R2->DCB
20
        Push    "R0,R1,LR"
        LDRB    R0, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    R0, #FlpPhaseDrv        ; Phase is awaiting drive ready?
        Pull    "R0,R1,PC",NE           ; No then exit

; Ensure '765 FDC has completed reset

        SETPSR  I_bit,LR                ; Disable IRQ's
        baddr   R0, FlpStateReset       ; Reset state address
        LDR     LR, FlpState            ; Get current FDC state
        TEQS    LR, R0                  ; Currently reset?
        MOVEQ   LR, #FlpPhaseReset      ; Yes then awaiting reset
        STREQB  LR, [R2, #FlpDCBphase]  ;   and update phase
        Pull    "R0,R1,PC",EQ           ;   and wait

; Attempt to reset disk changed signal by step pulse

        MOV     LR, #FlpCCR500K
        STRB    LR, [R2, #FlpDCBselect] ; Use 500K clock
        MOV     LR, #FlpPhaseSeek       ; Next phase is waiting for seek done
        STRB    LR, [R2, #FlpDCBphase]  ; Update command phase
        MOV     LR, #FlpDCBread
        STR     LR, [R2, #FlpDCBlength] ; Read mode - no settling

        MOV     LR, #1
25      STRB    LR, [R2, #FlpDCBtrack]  ; Request track 1
        MOV     R1, R2                  ; Get->DCB
        MOV     R0, #FlpEventSeek
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpState            ; Call state system (R0,R1->V)
        BLVS    FlpGetDrvStatus         ; If error terminate DCB (R0,R1->)
        Pull    "R0,R1,PC",VS           ;   and return

        TEQS    R0, #0                  ; Seek in progress
        Pull    "R0,R1,LR"
        MOVNE   PC, LR                  ; Yes then exit


; Process seek done message, R2->DCB
30
        Push    "R0,R1,LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
        TEQS    LR, #FlpPhaseSeek       ; Phase is awaiting seek done?
        Pull    "R0,R1,PC",NE

        LDRB    LR, [R2, #FlpDCBtrack]  ; Get track
        TEQS    LR, #0                  ; On track 0
        MOVNE   LR, #0
        BNE     %BT25                   ; No then seek track 0

        LDRB    R0, [R2, #FlpDCBcdb+1]
        AND     R0, R0, #3              ; Get drive number
        DrvRecPtr R1, R0                ; R1-> drive record
        BL      FlpGetDskChng           ; Read disk changed status (->R0)
        TSTS    R0, #FlpDIRchanged      ; Disk still changed from drive?
        LDR     R0, [R1, #DrvFlags]     ; Get drive flags
        BNE     %FT35                   ; Yes then jump

 [ Debug10
        DLINE   "DskChng Reset"
 ]
        BIC     R0, R0, #MiscOp_PollChanged_MaybeChanged_Flag+MiscOp_PollChanged_NotChanged_Flag+MiscOp_PollChanged_Empty_Flag+MiscOp_PollChanged_Ready_Flag
        ORR     R0, R0, #MiscOp_PollChanged_ChangedWorks_Flag+MiscOp_PollChanged_Changed_Flag ; Show changed works
        STR     R0, [R1, #DrvFlags]     ; Update drive flags
        BL      FlpGetDrvStatus         ; Get drive status

        MOV     LR, #PositionUnknown
        STR     LR, [R1, #HeadPosition] ; Force restore
        Pull    "R0,R1,PC"              ; Exit

; Can't reset disk changed
35
 [ {TRUE}
; Report empty whenever disk changed won't clear

        BIC     R0, R0, #MiscOp_PollChanged_NotChanged_Flag+MiscOp_PollChanged_Changed_Flag+MiscOp_PollChanged_MaybeChanged_Flag ; Reset not changed
        ORR     R0, R0, #MiscOp_PollChanged_Empty_Flag      ; Set drive empty
        STR     R0, [R1, #DrvFlags]     ; And update drive flags
 |
; Report empty only when disk changed works but won't clear

        TSTS    R0, #MiscOp_PollChanged_ChangedWorks_Flag   ; Does change work?
        BICNE   R0, R0, #MiscOp_PollChanged_NotChanged_Flag+MiscOp_PollChanged_Changed_Flag ; Yes reset not changed
        ORRNE   R0, R0, #MiscOp_PollChanged_Empty_Flag      ; And set drive empty
        STRNE   R0, [R1, #DrvFlags]     ; And update drive flags
 ]

 [ Debug10
        TSTS    R0, #MiscOp_PollChanged_Empty_Flag
        BEQ     %FT40
        DLINE   "DskChng not reset, drive empty"
40
 ]
        BL      FlpGetDrvStatus         ; Get drive status
        Pull    "R0,R1,PC"              ; And exit


; Process reset OK message
80
        Push    "LR"
        LDRB    LR, [R2, #FlpDCBphase]  ; Get current phase
        CMPS    LR, #FlpPhaseReset      ; Phase is awaiting reset?
        Pull    "PC",NE                 ; No then exit

        MOV     LR, #FlpPhaseDrv        ; Yes, now awaiting drive ready
        STRB    LR, [R2, #FlpDCBphase]  ; Update command phase
        Pull    "LR"
        B       %BT20                   ; And retry


;-----------------------------------------------------------------------;
; FlpGetDrvStatus                                                       ;
;       Issue Sense Drive Interrupt command and read results            ;
;                                                                       ;
; Input:                                                                ;
;       R2 -> DCB                                                       ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpGetDrvStatus ROUT                    ; Get drives status
        Push    "R0,R1,R6,LR"
        SavePSR R6
        ADD     R1, R2, #FlpDCBcdb      ; R1-> command block
        MOV     R0, #2                  ; 2 bytes
        BL      Flp765BlkWr             ; Issue command (R0,R1->V)
        MOVVS   R0, #&FF
        BLVC    Flp765read              ; Get result byte (->R0)
        STRB    R0, [R2, #FlpDCBresults] ; And return results

; Get drive density

        BL      FlpMediaID              ; Get MediaID (->R0)
        LDRB    LR, [R2, #FlpDCBcdb+1]
        AND     LR, LR, #3              ; Get drive number
        DrvRecPtr R1, LR                ; R1-> drive record
        LDR     LR, [R1, #DrvFlags]     ; Get drive flags
        TSTS    R0, #FlpHiDensity       ; Hi density?
        ORRNE   LR, LR, #MiscOp_PollChanged_HiDensity_Flag  ; Yes set hi density bit
        BICEQ   LR, LR, #MiscOp_PollChanged_HiDensity_Flag  ; Else reset hi density bit
        ORREQ   LR, LR, #MiscOp_PollChanged_DensityWorks_Flag ; And show density works
        LDR     R0, [R2, #FlpDCBresults+4] ; Get drive state on entry
        STR     LR, [R2, #FlpDCBresults+4] ; Return them

; Get disk changed state

        TSTS    LR, #MiscOp_PollChanged_MaybeChanged_Flag+MiscOp_PollChanged_Changed_Flag ; Maybe/is changed?
        BICNE   LR, LR, #MiscOp_PollChanged_MaybeChanged_Flag+MiscOp_PollChanged_Changed_Flag ; Yes then reset is/maybe
        ORRNE   LR, LR, #MiscOp_PollChanged_NotChanged_Flag ;   and set not changed
        STR     LR, [R1, #DrvFlags]     ; Update drive flags

; Restore drive state

 [ Debug10
        DREG    R0,"Drive state was:"
 ]
        AND     R0, R0, #MiscOp_PollChanged_Ready_Flag+MiscOp_PollChanged_Empty_Flag
        TEQS    R0, #MiscOp_PollChanged_Ready_Flag          ; Was drive ready?
        BEQ     %FT10                   ; Yes then jump, leave drive on

        ANDS    R1, LR, #MiscOp_PollChanged_Ready_Flag+MiscOp_PollChanged_Empty_Flag ; Drive now not ready nor empty?
        TEQNES  R1, #MiscOp_PollChanged_Ready_Flag+MiscOp_PollChanged_Empty_Flag ; Or changed not reset?
        BNE     %FT05                   ; No then jump

; Turn off drives that are neither ready nor empty or won't reset changed

        MOV     R1, #-1                 ; Turn drives off now
        MOV     R0, #FlpEventDrvSel     ; Drive select event
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpDrive            ; Call drive state system (R0,R1->R0)
        B       %FT10

; Set timeout for drive off for empty or ready drives

05      TSTS    LR, #MiscOp_PollChanged_Ready_Flag          ; Is drive ready?
        MOVNE   LR, #1
        STRNEB  LR, FlpDriveIP          ; Yes, then turn off in 1 rev
        MOVEQ   LR, #5                  ; Else set small timeout
        STREQB  LR, FlpMotorTimer       ; To turn motors off

10      MOV     R0, #0                  ; No error
        BL      FlpDqDCB                ; Terminate DCB (R0,R2->)
        RestPSR R6,,f
        Pull    "R0,R1,R6,PC"           ; And exit


;-----------------------------------------------------------------------;
; FlpHandlerImm                                                         ;
;       Handle messages for immediate type FDC commands                 ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Message                                                    ;
;       R1 = Parameter                                                  ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None                                                            ;
;_______________________________________________________________________;
;
FlpHandlerImm   ROUT
        CMPS    R0, #FlpMsgStart        ; Initialise?
        BEQ     %FT10                   ; Yes then jump
        CMPS    R0, #FlpMsgError        ; Error?
        MOVNE   PC, LR                  ; No then return

; Handle error message, R1= error code

        Push    "R0,R1,LR"
        MOV     R0, R1                  ; Get error code
        BL      FlpDqDCB                ; Terminate DCB (R0,R2->)
        Pull    "R0,R1,PC"

; Process initialization message, R2->DCB
10
        Push    "R0,R1,LR"
 [ Debug10
        DLINE   "FlpHandlerNoIRQ: Iniz"
 ]
        MOV     R0, #FlpEventCmd        ; Command request
        MOV     R1, R2                  ; R1->DCB
        MOV     LR, PC                  ; Setup return link
        LDR     PC, FlpState            ; Call state system (R0,R1->V)

; Return command completion status

        MOVVS   R0, #BadComErr          ; Return bad command if error in FDC
        MOVVC   R0, #0                  ; Else return good command
        BL      FlpDqDCB                ; Terminate DCB (R0,R2->)
        Pull    "R0,R1,PC"              ; Restore regs and return


;-----------------------------------------------------------------------;
; FlpAddDCB                                                             ;
;       Add a DCB to the active queue                                   ;
;                                                                       ;
; Input:                                                                ;
;       R1 -> DCB                                                       ;
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
; '765 command type lookup table
;
FlpMsgTable
        DCD     0                       ; &00, Illegal
        DCD     0                       ; &01, Illegal
        DCD     FlpHandlerData-org      ; &02, Read track
        DCD     FlpHandlerImm-org       ; &03, Specify
        DCD     FlpHandlerDrv-org       ; &04, Sense drive status
        DCD     FlpHandlerData-org      ; &05, Write sectors
        DCD     FlpHandlerData-org      ; &06, Read sectors
        DCD     FlpHandlerSeek-org      ; &07, Recalibrate
        DCD     FlpHandlerImm-org       ; &08, Sense interrupt status
        DCD     FlpHandlerData-org      ; &09, Write deleted data
        DCD     FlpHandlerReadID-org    ; &0A, Read sector ID
        DCD     0                       ; &0B, Illegal
        DCD     FlpHandlerData-org      ; &0C, Read deleted data
        DCD     FlpHandlerData-org      ; &0D, Format track
        DCD     FlpHandlerImm-org       ; &0E, Dump registers (665)
        DCD     FlpHandlerSeek-org      ; &0F, Seek
        DCD     FlpHandlerImm-org       ; &10, Version
        DCD     FlpHandlerData-org      ; &11, Scan equal
        DCD     FlpHandlerImm-org       ; &12, Perpendicular mode (665)
        DCD     FlpHandlerImm-org       ; &13, Configure (665)
        DCD     FlpHandlerImm-org       ; &14, Lock (665)
        DCD     0                       ; &15, Illegal
        DCD     FlpHandlerData-org      ; &16, Verify sectors (665)
        DCD     FlpHandlerImm-org       ; &17, Powerdown mode (665)
        DCD     0                       ; &18, Illegal
        DCD     FlpHandlerData-org      ; &19, Scan low or equal
        DCD     0                       ; &1A, Illegal
        DCD     0                       ; &1B, Illegal
        DCD     0                       ; &1C, Illegal
        DCD     FlpHandlerData-org      ; &1D, Scan high or equal
        DCD     0                       ; &1E, Illegal
        DCD     0                       ; &1F, Illegal
        ALIGN

FlpAddDCB       ROUT
        Push    "R2,LR"

; Lookup type of command

        LDRB    LR, [R1, #FlpDCBcdb]    ; Get command code
 [ Debug10
        DREG    LR, "Add DCB with command "
 ]
        BIC     LR, LR, #FlpCmdMT + FlpCmdFM + FlpCmdSK ; Ignore option bits
        MOV     LR, LR, LSL #2          ; Word entries
        baddr   R2, FlpMsgTable         ; R2-> lookup table
        LDR     R2, [R2, LR]            ; Get address
        CMPS    R2, #0                  ; Unsupported command type?
        MOVEQ   R0, #BadParmsErr        ; Yes, then bad parameters
        MOVNE   R0, #FlpDCBpending      ; Else set pending status
        STR     R0, [R1, #FlpDCBstatus] ; Write status to DCB
        BNE     %FT05
        SETV
        Pull    "R2,PC"                 ; Restore regs and return with error
05

 [ Debug10
        DLINE   "Command vetted OK"
 ]

; Get address of message handler for command type found

        baddr   R0, org                 ; Base address of module
        ADD     R2, R2, R0              ; Relocate handler entry
        STR     R2, [R1, #FlpDCBhandler] ; Set message handler for new DCB

; Initialise reserved data areas

        MOV     LR, #0
        STR     LR, [R1, #FlpDCBlink]   ; Mark new end of chain
        MOV     LR, #FlpPhaseIdle
        STRB    LR, [R1, #FlpDCBphase]  ; Set current DCB phase to idle

; Find end of current DCB chain

        sbaddr  R0, FlpDCBqueue         ; Get start of chain
10      LDR     LR, [R0]                ; Get pointer to next DCB
        CMPS    LR, #0                  ; At end of queue?
        ADDNE   R0, LR, #FlpDCBlink     ; NO, get address of ptr to next DCB
        BNE     %BT10                   ; Loop until reached end of queue

        STR     R1, [R0]                ; Add new DCB to end of chain

 [ Debug10
        DLINE   "Command added to command chain OK"
 ]

; Send "start processing" message to top of queue DCB

        MOV     R0, #FlpMsgStart
 [ Debug10s :LAND: {FALSE}
        DLINE   " Add ",cc
 ]
        BL      FlpMessage              ; Send start process message
 [ Debug10
        DLINE   "Command started"
 ]

        MOV     R0, #0                  ; No error
        CLRV
        Pull    "R2,PC"                 ; Return, no error


;-----------------------------------------------------------------------;
; FlpDqDCB                                                              ;
;       DeQueue a DCB                                                   ;
;                                                                       ;
; Input:                                                                ;
;       R0 = Final return code                                          ;
;       R2 -> DCB to remove                                             ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       None                                                            ;
;                                                                       ;
; Modifies:                                                             ;
;       None, preserves flags                                           ;
;_______________________________________________________________________;
;
FlpDqDCB        ROUT
        Push    "R0,R1,R4,LR"
        SavePSR R4
        LDR     R1, FlpDCBqueue         ; Get top of chain
        TEQS    R1, #0                  ; Any DCB's queued?
        BNE     %FT00
        RestPSR R4,,f
        Pull    "R0,R1,R4,PC"           ; No then exit
00
; Unlock the drive

        LDRB    LR, FlpDriveLock        ; Get lock state
        BIC     LR, LR, #bit0+bit2      ; Clear command lock bit & empty
        STRB    LR, FlpDriveLock        ; Update command lock state

; Remove DCB at top of queue

        LDR     LR, [R1, #FlpDCBlink]   ; Get pointer to second DCB in queue
        STR     LR, FlpDCBqueue         ; Remove top of queue
        STR     R0, [R1, #FlpDCBstatus] ; Set final status

        ;Check whether R0=DriveEmptyErr
        CMP     R0, #DriveEmptyErr
        BNE     %FT01
        ;If so, check whether it should be NoFloppy error, and change if so
        SWI     XPortable_Status
        BVS     %FT01
        TST     R0, #PortableStatus_PrinterFloppy
        BNE     %FT01
        ADRL    R0, NoFloppyErrBlk
        BL      copy_error              ;Convert the token into an error string
 [ :LNOT:NewErrors
        ORR     R0, R0, #ExternalErrorBit
 ]
        STR     R0, [R1, #FlpDCBstatus] ; Set final status (again!)

; Restore MEMC state if it has been changed

01      LDR     R0, FlpMEMCstate
        TEQS    R0, #0                  ; MEMC state saved?
 [ Debug10v
        BEQ     %FT01
        DLINE   "Re-enabling video DMA"
01
 ]

        BEQ     %FT05
        Push    "r1"
        WritePSRc SVC_mode + I_bit,lr,,r1
        NOP
        Push    "r1,lr"
        MOV     r1, #0
        STR     r1, FlpMEMCstate
        MOV     r1, #MEMC_DMA_bits
        BIC     r0, r0, #bit31
        SWI     XOS_UpdateMEMC
        Pull    "r1,lr"
        RestPSR r1
        Pull    "r1"
05

; Call post routine for DCB removed

        LDR     LR, [R1, #FlpDCBpost]   ; Get post routine address
        TEQS    LR, #0                  ; Valid?
        BEQ     %FT10                   ; No then jump

        Push    "SB"
        LDR     R0, [R1, #FlpDCBstatus] ; Get completion�status
        LDR     SB, [R1, #FlpDCBsb]     ; Yes, then set SB for post routine
        MOV     LR, PC                  ;   Set return address
        LDR     PC, [R1, #FlpDCBpost]   ;   Call post routine (R0,R1,SB->)
        Pull    "SB"

; Send "start processing" message to new top of DCB queue

10      MOV     R0, #FlpMsgStart
 [ Debug10s :LAND: {FALSE}
        DLINE   " Dq ",cc
 ]
        BL      FlpMessage              ; Send start process message
        RestPSR R4,,f
        Pull    "R0,R1,R4,PC"


        LTORG

        END
