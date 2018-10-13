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
 [ Support1772

; >Adfs15
; Driver code for 1772/9793 based floppy disk controller
; Change record
; =============
;
; LR  - Lawrence Rust, Cambridge Beacon
; MJS - Mike Stephens
;
;
; 08-Mar-91  14:08  LVR
; Merge winchester and floppy driver code
;
; 12-Mar-91  10:00  LVR
; Flp1772format releases FIQ's if parameter errors found
; RetryFloppyOp seeks correct track with 40 track disks
;
; 16-Mar-91  15:55  JSR
; Fix DoFloppyCallAfter to correctly handle the CPU mode
; Fix indentation to be 8-space based
; Alter debugging to be DREG/DLINE based
;
; 18-Mar-91  12:02  LVR
; Mount now reads all sector ID's in a 200mS period and discards
; all duplicate ID's found from the end of the buffer.
; Made disc change reset by write conditional upon A1 (not A500)
;
; 28-May-91  09:43  LVR
; Fixed Mount bug always reading from drive 0
;
; 07-Jan-92  16:45  LVR
; Fixed "read track" operation so that data overruns (often encountered
; on discs formatted by A5000) do not cause screen blanking, instead
; the operation is aborted and faulted.
;
; 14-Apr-92 14:11  LVR
; Background operations now use End register to ensure that sectors longer
; than expected do not overwrite memory.  The 1772 does not check sector
; size field of sector ID!!  NotDRQ recoded to update End register for
; background transfers.
;
; 28-Apr-92 14:08  LVR
; Fix bug in background transfers when screen blanking invoked
;
; 27-02-96 MJS
; StrongARM changes for modifying code
;
         GBLL  FlpMultiFS
FlpMultiFS     SETL {TRUE} ; Include MultiFS code

        MACRO
        FIQOFF  $lab
        DCD     ($lab.Fiq-(FiqHandlers)) :SHR: 2
        MEND

FiqHandlers  ;table of offsets of start of FIQ handlers
        FIQOFF  Verify
        FIQOFF  ReadSecs
        FIQOFF  WriteSecs
        FIQOFF  ReadTrack

        FIQOFF  WriteTrack
        FIQOFF  Seek            ;also used for step ops
        FIQOFF  Restore
        FIQOFF  StepIn

        FIQOFF  StepOut
        FIQOFF  StepInVerify
        FIQOFF  StepOutVerify
 ALIGN

;*** These FIQ handlers must follow on from each other in DiscOp number order
; *** TMD 04-Jul-90 - I don't believe the above comment, only the offsets above must be in DiscOp number order

VerifyFiq
        LDRB    Temp, [IOCfiq, #IOCFIQSTA]

        MOVS    Temp, Temp, LSR #(IoDrqBitNo+1) ;C=1 <=> DRQ
        LDRCSB  Temp, [FDC, #FdcData]           ;if DRQ read byte to clear FIQ
        TEQCSS  Ram, End
        ADDHI   Ram, Ram, #1                    ;count byte if DRQ and not done

        retfiq  CS
;BAL     NotDrq          added when copied down
 &      0       ;end mark

ReadSecsFiq
        LDRB    Temp, [IOCfiq,#IOCFIQSTA]

        MOVS    Temp, Temp, LSR #(IoDrqBitNo+1)     ;C=1 <=> DRQ
        LDRCSB  Temp, [FDC,#FdcData]
        TEQS    Ram, End
        STRHIB  Temp, [Ram],#1                    ;if DRQ and not done save byte

        retfiq  CS
;BAL     NotDrq          added when copied down
 &      0       ;end mark

WriteSecsFiq
        LDRB    Temp, [IOCfiq,#IOCFIQSTA]

        MOVS    Temp, Temp, LSR #(IoDrqBitNo+1) ;C=1 <=> DRQ
        EORS    Temp, Ram, End                  ;is all done ? (if so Temp=0)
        LDRHIB  Temp, [Ram], #1                 ;get byte if DRQ and not done
        STRCSB  Temp, [FDC, #FdcData]           ;if DRQ write byte (or 0)

        retfiq  CS
;BAL     NotDrq          added when copied down
 &      0       ;end mark

; ReadTrackFiq is used for the read track operation
ReadTrackFiq
        LDRB    Temp, [IOCfiq,#IOCFIQSTA]

        TSTS    Temp, #IoDrqBit                   ;Z=0 <=> DRQ
        LDRNEB  Temp, [FDC,#FdcData]              ;get byte if DRQ
        STRNEB  Temp, [Ram],#1                    ;if DRQ save byte
        retfiq  NE

;BAL     NotDrq          added when copied down
 &      0       ;end mark

WriteTrackFiq
        LDRB    Temp, [IOCfiq,#IOCFIQSTA]
 [ fix_3
        MOVS    Temp, Temp, LSR #(IoDrqBitNo+1) ;C=1 <=> DRQ
        EORS    Temp, Ram, End                  ;is all done ?
        MOVEQ   Temp, #&4E                      ; (if so pad with gap4 value)
        LDRHIB  Temp, [Ram], #1                 ;get byte if DRQ and not done
        STRCSB  Temp, [FDC, #FdcData]           ;if DRQ write byte (or &4E)

        retfiq  CS
 |
        TSTS    Temp, #IoDrqBit                   ;Z=0 <=> DRQ
        LDRNEB  Temp, [Ram], #1                   ;get next byte if DRQ
        STRNEB  Temp, [FDC, #FdcData]             ;if DRQ write byte

        retfiq  NE
 ]
SeekFiq
RestoreFiq
StepInFiq
StepOutFiq
StepInVerifyFiq
StepOutVerifyFiq
;BAL    NotDrq          added when copied down
 &      0       ;end mark

EndFiqHandlers
        ASSERT  EndFiqHandlers-FiqHandlers<&400

;*** end of copy down FIQ handlers


; =============
; RetryFloppyOp
; =============
;
; On entry
;  R1 = DiscOp (bits 0-7)
;  R2 = Disc Address (in bytes), top 3 bits = drive, START AT SECTOR BOUNDARY
;  R3 = Ram Start or ptr to scatter block
;  R4 = Number of bytes to transfer
;  R5 -> disc rec
;  R6 retries 0-&FF, bit 31 set <=> mount

; On exit
; IF error V set, R0 result
;  R1   preserved
;  R2   Incremented by amount transferred
;  R3   Incremented appropriately
;  R4   Untransferred bytes

RetryFloppyOp ROUT
        Push    "R0,R6-R11,LR"
 [ Debug1
        DREG    R1, "RetryFloppyOp(",cc
        DREG    R2, ",",cc
        DREG    R3, ",",cc
        DREG    R4, ",",cc
        DREG    R5, ",",cc
        DREG    R6, ",",cc
        DLINE   ")"
 ]
        CLRPSR  F_bit :OR: I_bit, LR            ;enable FIQ, IRQ

        TSTS    R1, #DiscOp_Op_BackgroundOp_Flag
        MOVEQ   LR, #1
        MOVNE   LR, #2
        TSTS    R6, #bit31
        MOVNE   LR, #0
        STRB    LR, FiqCtr

        MOV     R7, #FiqStackBase + DiscAdd
        TSTS    R1, #DiscOp_Op_ScatterList_Flag

        ASSERT  RamStart       = DiscAdd + 4
        ASSERT  RamLength      = RamStart + 4
        ASSERT  FRetries       = RamLength + 4
        ASSERT  FloppyRetryCtr = FRetries + 1
        ASSERT  DMAold         = FloppyRetryCtr + 2
        ASSERT  ScatterBlk     = DMAold + 1

        BIC     R6, R6, #&FF000000
        ORR     R6, R6, #MEMC_mystate :SHL: (24-DMAshift)
        STMIA   R7!,{R2-R4,R6}
        STMEQIA R7,{R3,R4}
        MOVNE   R7, R3

        MOV     R11,#FiqStackBase + DiscOp
        ASSERT  Remains = DiscOp + 4
        ASSERT  DiscRec = Remains + 4
        ASSERT  ScatterPtr = DiscRec + 4
        STMIA   R11,{R1,R4,R5,R7}
        MOV     R11, #FiqStackBase

        TSTS    R1, #DiscOp_Op_IgnoreEscape_Flag ;check for escape
        BLEQ    CheckEscape             ;(->R0,Z)
 [ Debug1
        BNE     %FT01
        DLINE   "***ESCAPE***"
01
 ]
        BEQ     AbortOp


;R1 DiscOp
;R2 Disc Address
;R4 Length
;R5 -> Disc Record
;R7 -> Scatter block (constructed or supplied)

        MOV     R3, R2, LSR #29         ;drive 0-3
        BIC     R8, R2, #DiscBits       ;byte add part
        MOV     R2, R1
        AND     R9, R1, #DiscOp_Op_Mask ;Only leave disc op bits
        CMPS    R9, #UnusedFloppyOp
 [ Debug
        BLS     %FT01
        DLINE   "Op out of range"
01
 ]
        BHI     BadFloppyOp
        DrvRecPtr  R6,R3
        STR     R6, [R11,#DrvRec]

        LDRB    LR, [R5,#SectorSize]
 [ Debug1r
        DREG    LR,"Sector size:"
 ]
        MOV     R0, R8, LSR LR          ;whole sectors
        SUBS    R8, R8, R0, LSL LR      ;spare bytes

 [ Debug
        BEQ     %FT01
        DLINE   "Not start at sec boundary"
01
 ]
        BNE     BadFloppyOp

        LDRB    R1, [R5,#SecsPerTrk]
 [ Debug1r
        DREG    R1,"SecsPerTrk:"
 ]
        BL      Divide
        ASSERT  ReadTrkOp=WriteTrkOp-1
        CMPS    R9, #ReadTrkOp          ;C=1 <=> Track operation
        RSBHIS  LR, R9, #WriteTrkOp
        MOVS    R8, R1                  ;remainder is sector
 [ Debug
        BLS     %FT01
        DLINE   "Not trk start"
01
 ]
        BHI     BadFloppyOp               ;Track ops must start at sector 0

        ; Check density is one we understand
        LDRB    lr, [r5, #Density]
 [ Debug1r
        DREG    LR,"Density:"
 ]
        TEQ     lr, #Single
        TEQNE   lr, #Double
 [ Debug
        BEQ     %FT01
        DLINE   "Not known density"
01
 ]
        BNE     BadFloppyOp

        ; Write track pre-processing
        TEQS    R9, #WriteTrkOp
        BNE     %FT05

        ; If length outside 0 to nominal track length*2 then replace with nominal track length
        LDR     R10, =3125              ; Bytes per track, single density
        LDRB    LR, [R5, #Density]
        MUL     R10, LR, R10            ; Bytes per track
        TEQS    R4, #0                  ; Zero length?
        MOVEQ   R4, R10                 ; Yes, then use nom. track length
        CMPS    R4, R10, LSL #1         ; R4 > 2* track?
        MOVHI   R4, R10                 ; Yes, then use nom. track length
        TST     r2, #DiscOp_Op_ScatterList_Flag
        STREQ   R4, [r7, #4]            ; Ensure artificial scatter is kept up-to-date
05

 [ FlpMultiFS
        LDRB    LR, [R5, #LowSector]
 [ Debug1r
        DREG    LR,"LowSector:"
 ]
        TSTS    LR, #bit6               ; Sequenced sides?
        MOVNE   R10, #1                 ; Yes, assume 1 head
        LDREQB  R10,[R5,#Heads]         ; Else get head count
 |
        LDRB    R10,[R5,#Heads]
 ]
 [ Debug1r
        DREG    R10,"Heads:"
 ]
        MOVS    R10,R10,LSR #1          ;C=1 <=> no side interleave
        MOVCC   R9, R0, LSR #1
        ANDCC   R10,R0, #1
        MOVCS   R9, R0

 [ FlpMultiFS
        TSTS    LR, #bit7               ; Double step?
        ADDNE   R9, R9, R9              ; Yes, double track no.
        BIC     LR, LR, #bit7+bit6      ; Get low sector no.
        ADD     R8, R8, LR              ; Offset sector no.
 ]


; R2  Disc Op
; R3  drive 0-3
; R4  length
; R5  -> disc record
; R6  -> drive record
; R7  -> scatter list
; R8  sector
; R9  track
; R10 head
; R11 FIQ stack

;If heads=1 & track>=TrksPerSide then use other side, for old ADFS format
        CMPCSS  R9, #TrksPerSide
        MOVCS   R10,#1                  ;head=1
        SUBCS   R9, R9, #TrksPerSide    ;amend Trk no.

 [ Debug1
        DLINE   "**Drive  |Sector  |Head    |Dest Track"
        DREG    R3,,cc
        DREG    R8,,cc
        DREG    R10,,cc
        DREG    R9
 ]

        MOV     R0, R3
        BL      SelectFloppy

        MOV     R0, #0                  ;Disable motor timer
        STRB    R0, MotorTimer

        LDRB    LR, [R6, #DrvFlags]     ;IF disc changed doesn't work
        TSTS    LR, #MiscOp_PollChanged_ChangedWorks_Flag
        BNE     %FT10
        LDRB    LR, DiscLatchCopy       ;AND motor is off
        TSTS    LR, #MotorBit
        LDRNE   LR, [R6, #DrvSequenceNum]
        ADDNE   LR, LR, #1              ;Increment drive sequence number
        STRNE   LR, [R6, #DrvSequenceNum]
10
        LDRB    LR, StepRates
        MOV     R0, R3, LSL #1          ;0 2 4 6
        MOV     LR, LR, LSR R0          ;pick out step bits for this drive
        AND     LR, LR, #3
        STRB    LR, [R11,#StepRate]

 [ Debug1
        Push    "r0"
        MOV     r0, lr
        DREG    r0,"*step rate bits="
        Pull    "r0"
 ]

;write to disc latch
;Not Reset Disc Changed bit     = 1  => not reset
;Motor bits                     = 00 => start motor and drive light on
;side                           as appropriate

        ASSERT  SideBit=1 :SHL: 4
        MOV     R0, R10, LSL #4               ;side bit
        EOR     R0, R0, #SideBit :OR: NotResetDiscChangedBit
        MOV     R1, #SideBit :OR: MotorBits :OR: NotResetDiscChangedBit
        BL      WrDiscLatch

        LDRB    LR, [R5,#Density]
        CMPS    LR, #Double
        MOVHS   R0, #DoubleBits :OR: FdcResetBit
        MOVLO   R0, #SingleBits :OR: FdcResetBit
        MOV     R1, #DensityBits :OR: FdcResetBit
        BL      WrSharedLatch

        MOV     R1, #IoChip
        ADD     R1, R1, #FdcAddress-IoChip
        MOV     LR, #FdcAbort           ;kill any FDC Op
        STRB    LR, [R1,#FdcCommand]

;COPY DOWN FIQ HANDLER
        AND     R0, R2, #DiscOp_Op_Mask
        baddr   R3, FiqHandlers
        LDRB    R11, [R3,R0]
        ADD     R3, R3, R11, LSL #2
        MOV     LR, #FiqVector
15
        LDR     R11, [R3],#4
        TEQS    R11, #0
        STRNE   R11, [LR],#4
        BNE     %BT15

 [ FIQ32bit

; in 32 bit mode we can't branch up to ROM, so use LDR PC instead

        LDR     R3, LDRPCInst           ; load instruction LDR PC, [PC, #-4]
        STR     R3, [LR], #4
        ADRL    R3, NotDrq
 |
        ADRL    R3, NotDrq-8             ;construct BAL NotDrq
        SUB     R3, R3, LR
        MOV     R3, R3, LSR #2
        ORR     R3, R3, #BalOpHi
 ]

        STR     R3, [LR],#4

  [ StrongARM
        ;now that we have finished arsing about, synchronise with respect to modified code
        Push    "R0-R2,LR"
        MOV     R0,#FiqVector            ;start virtual address
        SUB     R1,LR,#4                 ;end virtual address (inclusive)
        BL      ADFSsync
        Pull    "R0-R2,LR"
  ]

        MOV     R11,#FiqStackBase

        CMPS    R0, #Param1Op
        MOVHS   R9, #0                  ;dest track=0 for restore or step

        STRB    R8, Sector
        STRB    R8, StartSector

        LDR     LR, [R6, #HeadPosition]
        TEQS    LR, #PositionUnknown    ;if head position unknown must do restore first
        MOVEQ   R0, #RestoreOp

        RSBS    R3, R0, #FirstHeadMoveOp-1      ;IF transfer op
        TEQCS   LR, R9                          ;AND on wrong track
        MOVHI   R0, #SeekOp                     ;THEN seek to correct track first

        TEQS    R0, #SeekOp             ;do seek to 0 as restore
        TEQEQS  R9, #0
        MOVEQ   R0, #RestoreOp
        STR     R0, [R11,#SubDiscOp]    ;for FIQ

        ADRL    LR, FdcOps
        LDRB    R0, [LR,R0]             ;look up FDC Command for operation
        AND     R3, R2, #DiscOp_Op_Mask

 [ FlpMultiFS
        TEQS    R0, #FdcReadAddress     ; Read address command?
        TSTEQS  R2, #DiscOp_Op_AltDefectList_Flag ; And alt defect bit clear
        ORREQ   R0, R0, #bit5           ; Yes, convert read address to read track
 ]

        CMPS    R3, #FirstHeadMoveOp
        BLO     %FT20
        TSTS    R0, #NotType1Bit :OR: VerifyBit
        BNE     %FT20
        TSTS    R2, #DiscOp_Op_IgnoreTimeout_Flag
        BNE     %FT40   ;dont wait for ready if type 1, no verify, no time out

;wait for drive to go ready optionally timeout after 1s
20
 [ Debug1
        DLINE   "*starting drive wait"
 ]
        MOV     R3, #1*100      ;Timeout after 1s
        STRB    R3, Counter
25
        TSTS    R2, #DiscOp_Op_IgnoreEscape_Flag
        BLEQ    CheckEscape
 [ Debug1
        BNE     %FT01
        DLINE   "***ESCAPE***"
01
 ]
        BEQ     %FT30           ;escape abort
        TSTS    R2, #DiscOp_Op_IgnoreTimeout_Flag
        LDREQB  R3, Counter
        TEQEQS  R3, #0
        ASSERT  DriveEmptyErr<&100
        MOVEQ   R0, #DriveEmptyErr
 [ Debug1
        BNE     %FT01
        DLINE   "***TIMEOUT***"
01
 ]
30
        STREQ   R0, [R11,#Result]
        BEQ     AbortOp         ;timeout abort
        MOV     LR, #IOC
        LDRB    LR, [LR,#IOCControl]
        TSTS    LR, #ReadyBit
        BEQ     %BT25
 [ Debug1
        DLINE   "*drive ready"
 ]

        TEQS    R0, #FdcWriteSec
        TEQNES  R0, #FdcWriteTrk
        BNE     %FT40

        CMPS    R9, #PrecompTrk
        BICHS   R0, R0, #NotPrecompBit
40

        TSTS    R2, #DiscOp_Op_BackgroundOp_Flag
        TOGPSR  Z_bit, LR               ;IF background op
        MOVEQS  LR, R4                  ; with no foreground part clear wait flag
        MOVNE   LR, #-1                 ;ELSE set foregound wait flag
        STR     LR, [R11,#Result]
        TSTS    R0, #NotType1Bit
        LDREQB  LR, [R11,#StepRate]
        LDRNEB  LR, HeadSettle
        ORR     R0, R0, LR              ;set appropriate sub options
        MOV     R3, SB

        WritePSRc FIQ_mode, Ram         ;use Ram as temp reg
        NOP                             ;delay for mode change

        LDMIA   R7, {Ram,End}
        TEQS    R2, R2, LSR #BackBitNo+1        ;HI (C=1,Z=0) <=> Background op
        CMPLSS  R4, End                 ; If foreground compare amount left with scatter chunk
        ADDLS   End,Ram,R4
        ADDHI   End,Ram,End

        MOV     SB, R3                  ;static base
        MOV     IOCfiq, #IOC
        ADD     FDC,IOCfiq,#FdcAddress-IOC

        WritePSRc SVC_mode,LR
        NOP                             ;delay for mode change

 [ Debug1
        Push    "r3,r4"
        WritePSRc FIQ_mode,r3
        NOP                             ;delay for mode change
        MOV     r3, Ram
        MOV     r4, End
        WritePSRc SVC_mode,lr
        NOP                             ;delay for mode change
        DREG    r3, "(Ram,End)=(",cc
        DREG    r4, ",",cc
        DLINE   ")"
        Pull    "r3,r4"
        DLINE   "*wait until FDC not busy ... "
 ]
45
        LDRB    LR, [R1,#FdcData]       ;clear any spurious DRQs
        STRB    LR, [R1,#FdcData]
        LDRB    LR, [R1,#FdcStatus]
        TSTS    LR, #BusyBit
        BNE     %BT45

 [ Debug1
        DLINE   "*done"
 ]

        MOV     R3, #IoChip
        MOV     LR, #FdcFiqMaskBits
        STRB    LR, [R3, #FiqMask]      ;enable FIQs

 [ FlpMultiFS
        LDRB    LR, [R5, #LowSector]
        TSTS    LR, #bit7               ; Double stepping?
        TSTNES  R0, #NotType1Bit        ; And not a head move op?
        LDR     LR, [R6, #HeadPosition]
        MOVNE   LR, LR, LSR #1          ; Yes then log track= phys_track/2
 |
        LDR     LR, [R6, #HeadPosition]
 ]

 [ Debug1
        Push    "r0"
        DLINE   "*Command |Cur Trk |Sector  |Dest Trk"
        DREG    R0,,cc
        MOV     r0, lr
        DREG    r0,,cc
        DREG    R8,,cc
        DREG    R9
        Pull    "r0"
 ]
        STRB    LR, [R1,#FdcTrack]      ;Track reg := current track
        STRB    R9, [R1,#FdcData]       ;required track to Data reg, for seek
        STRB    R8, [R1,#FdcSector]     ;write sector reg

        ASSERT  DestTrack = FdcOp + 1
        ORR     LR, R0, R9, LSL #8
        ASSERT  Head = DestTrack +1
        ORR     LR, LR, R10,LSL #16
        STR     LR, [R11,#FdcOp]
        STRB    R0, [R1,#FdcCommand]    ;Issue command

50
        LDR     R0, [R11,#Result]       ;poll until fiq handler clears busy
        CMPS    R0, #-1
        BEQ     %BT50

 [ Debug1
        Push    "r0"
        DREG    R0,,cc
        DLINE   "<-Result"
        LDRB    r0, [R1,#FdcStatus]
        DREG    r0,,cc
        DLINE   "<-FDCstatus"
        LDR     r0, [R11,#ScatterPtr]
        DREG    r0,"*Scatter ptr="
        Pull    "r0"
 ]

;calc return values
        ADD     R1, R11, #DiscOp
        ASSERT  Remains = DiscOp + 4
        LDMIA   R1, {R1,R4}
        LDR     R2, [R11,#DiscAdd]

        TSTS    R1, #DiscOp_Op_BackgroundOp_Flag ;IF background op
        TSTNES  R4, #bit31              ;convert -ve remains
        MOVNE   R4, #0                  ;to 0

        LDR     LR, [R11,#RamLength]
        SUB     LR, LR, R4              ;amount transferred
        ADD     R2, R2, LR              ;end disc address
        TSTS    R1, #DiscOp_Op_ScatterList_Flag
        LDREQ   R3, [R11,#RamStart]
        ADDEQ   R3, R3, LR
        LDRNE   R3, [R11,#ScatterPtr]
        LDR     R0, [R11,#Result]

RetryBack
        BL      DecFiq                  ;release foreground use of fiq workspace
 [ Debug1
        DLINE   "*result  discop   disc add ram ptr  left"
        DREG    r0,,cc
        DREG    r1,,cc
        DREG    r2,,cc
        DREG    r3,,cc
        DREG    r4
 ]
        BL      SetVOnR0
        STRVS   R0, [SP]
        Pull    "R0,R6-R11,PC"

BadFloppyOp
        MOV     R0, #BadParmsErr        ;result code for Bad Parms
AbortOp
        STR     R0, [R11,#Result]
        LDR     LR, [R11,#DiscOp]
        TSTS    LR, #DiscOp_Op_BackgroundOp_Flag
        BLNE    DoFloppyCallAfter
        MOV     LR, #MotorTimeOut+1
        STRB    LR, MotorTimer          ;Unlock & restart motor timer
        B       RetryBack

 [ FIQ32bit

; this instruction is copied down into FIQ code

LDRPCInst
        LDR     PC, LDRPCAddr           ; load PC from next word
LDRPCAddr
 ]

 LTORG

FdcOps
 =       FdcReadSec      ;for verify
 =       FdcReadSec
 =       FdcWriteSec
 [ FlpMultiFS
 =       FdcReadAddress
 |
 =       FdcReadTrk
 ]

 =       FdcWriteTrk
 =       FdcSeek
 =       FdcRestore
 =       FdcStepIn

 =       FdcStepOut
 =       FdcStepInVerify
 =       FdcStepOutVerify
 ALIGN

FiqMasks
 =       RnfBit :OR: CrcBit :OR: LostBit                ;0 Verify
 =       RnfBit :OR: CrcBit :OR: LostBit                ;1 Read sectors
 =       WProtBit :OR: RnfBit :OR: CrcBit :OR: LostBit  ;2 Write sectors
 =       RnfBit :OR: CrcBit :OR: LostBit                ;3 Read track

 =       WProtBit :OR: RnfBit :OR: CrcBit :OR: LostBit  ;4 Write track
 =       RnfBit :OR: CrcBit                             ;5 Seek
 =       RnfBit :OR: CrcBit :OR: Track0Bit              ;6 Restore
 =       RnfBit :OR: CrcBit                             ;7 Step in

 =       RnfBit :OR: CrcBit                             ;8 Step out
 =       RnfBit :OR: CrcBit                             ;9 Step in with verify
 =       RnfBit :OR: CrcBit                             ;A Step out with verify
 ALIGN


NotDrq  ROUT
        ASSERT  SP = IOCfiq
        MOV     SP, #FiqStackBase + FiqDump
        STMIA   SP, {R0-R7,LR}
        LDMDB   SP!,{R2-R7}
;R2 DriveRec
;R3 SubDiscOp
;R4 DiscOp
;R5 Remains
;R6 DiscRec
;R7 ScatterPtr

        LDRB    R0, [FDC,#FdcStatus]            ;Read FDC Status
        TEQS    R3, #RestoreOp
        EOREQ   R0, R0, #Track0Bit

        baddr   LR, FiqMasks
        LDRB    LR, [LR, R3]
        ANDS    R0, R0, LR
        BNE     FiqError

        CMPS    R3, #Param3Op
        BHS     %FT15                   ;sub op not Verify, ReadSecs or WriteSecs

        LDMIA   R7, {R0,R1}             ;get (address,length)
        SUB     R0, Ram, R0             ;RAM ptr increase this sector
        SUBS    R5, R5, R0              ;decr foreground amount left
        SUBLTS  R5,R5,R5                ; Max(0,R5)
        STR     R5, [SP,#Remains]
        STREQ   R5, [SP,#Result]        ;once foreground part complete release wait
        SUBS    LR, R1, R0              ;reduce amount left in this scatter chunk

        STMIA   R7!,{Ram,LR}            ;update (address,length) pair
        BEQ     %FT03                   ; Jump if scatter chunk exhausted

        TSTS    R4, #DiscOp_Op_BackgroundOp_Flag
        CMPEQ   R5,#0                   ; Foreground op completed?
        BEQ     %FT60                   ; Yes then jump, all done
        BNE     %FT15                   ; Else transfer some more

; Scatter chunk exhausted
03
        LDMIA   R7, {Ram,End}           ;pick up next address length pair
        TSTS    R4, #DiscOp_Op_BackgroundOp_Flag ; Background operation?
        BNE     %FT05                   ; Yes then jump

        CMPS    R5, #0                  ;more left ?
        STREQ   R7, [SP,#ScatterPtr]    ; No then save scatter ptr
        BEQ     %FT60                   ; And jump, all done
05
 [ FixTBSAddrs
        CMN     Ram,#ScatterListNegThresh;if reached end of buffer pairs
        ADDCS   R7, R7, Ram             ;then wrap back to start
        LDMCSIA  R7, {Ram,End}
 |
        TEQS    Ram, #0                 ;if reached end of buffer pairs
        ADDMI   R7, R7, Ram             ;then wrap back to start
        LDMMIIA  R7, {Ram,End}
 ]
        STR     R7, [SP,#ScatterPtr]
        SUBS    R0, End, #0             ;finished when reach zero length pair
        BEQ     %FT50

        TEQS    R4, R4, LSR #BackBitNo+1        ;HI (C=1,Z=0) <=> Background op
        CMPLSS  R5, End                 ; If foreground, compare amount left with scatter chunk
        ADDLS   End,Ram,R5
        ADDHI   End,Ram,End

; More data to transfer, R5= foreground remaining, Ram, End updated
15
        TSTS    R4, #DiscOp_Op_IgnoreEscape_Flag
        BNE     %FT20                   ;if ignoring escapes
        LDR     LR, ptr_ESC_Status
        LDRB    LR, [LR]
        TSTS    LR, #EscapeBit
        MOVNE   R0, #IntEscapeErr
        BNE     FiqEscape

20
        AND     R4, R4, #DiscOp_Op_Mask
        CMPS    R3, #FirstHeadMoveOp
        BLO     %FT25

;HERE IF SUCCESSFUL HEAD MOVE OP

        ASSERT  FdcAddress :MOD: 256 = 0
        LDRB    LR, [SP, #FdcOp]
        TSTS    LR, #VerifyBit
        MOVEQ   LR, #SettleBit
        MOVNE   LR, #0
        STRB    LR, HeadSettle          ;pending head settle unless had verify bit set

        LDRB    R0, [FDC, #FdcTrack]
        STR     R0, [R2, #HeadPosition] ;remember new head position

        SUBS    LR, R3, R4
        STREQ   LR, [SP, #Result]
        BEQ     %FT60                   ;finished if sub op = main op

        LDRB    R1, [SP,#DestTrack]
        TEQS    R0, R1                  ;if not at dest track
        MOVNE   R4, #SeekOp             ;then seek there first

 [ FlpMultiFS
        BNE     Recommand               ; Jump if seeking

        LDRB    LR, [R6, #LowSector]
        TSTS    LR, #bit7               ; Double stepping?
        MOVNE   LR, R0, LSR #1          ; Yes, logical track = phys_track/2
        STRNEB  LR, [FDC, #FdcTrack]    ; And tell FDC
 ]

        B       Recommand


;HERE IF SUCCESSFUL TRANSFER OP
25
        MOV     LR, #0
        STRB    LR, HeadSettle                  ;clear any pending head settle
        STRB    LR, [SP, #FloppyRetryCtr]       ;restart retry counter

 [ FlpMultiFS
        LDRB    R0, [SP, #FdcOp]        ; Get last command
        AND     R0, R0, #&F0            ; Ignore option bits
        TEQS    R0, #FdcReadAddress:AND:&F0 ; Read address command?
        BNE     %FT27                   ; No then jump

; Last operation was read address

        SUB     Ram, Ram, #2            ; Drop CRC bytes
        LDR     R0, [R7]                ; Get start address
        SUB     R0, Ram, R0             ; Calc bytes read
        CMPS    R0, #4                  ; 1st sector ID?
        MOVLS   R0, #21                 ; Yes set 1 rev timeout
        STRLSB  R0, Counter             ; And start timer
        LDRHIB  R0, Counter             ; Else read counter
        CMPS    R0, #0                  ; Timed out?
        BHI     Recommand               ; No, then read more ID's

; Calculate sectors per track for read address operation

        LDR     End, [R7]               ; Get start address
        LDR     Temp, [End]             ; Get 1st ID read
        MOV     LR, Ram                 ; Save buffer ptr
26
        LDR     R0, [Ram, #-4]!         ; Get last ID
        TEQS    Temp, R0                ; Duplicate ID?
        BNE     %BT26                   ; No then jump

        TEQS    Ram, End                ; Any duplicates found?
        MOVEQ   Ram, LR                 ; No, then use all ID's
        SUB     End, Ram, End           ; ID bytes read
        MOV     End, End, LSR #2        ; /4 to get sector ID's
        STRB    End, [R6, #SecsPerTrk]  ; Update sectors per track
        MOV     LR, #0
27
 ]
        CMPS    R4, #Param3Op
 [ Debug3
        BLO     %FT00
        DREG    Ram,"RdTrk Ram:"
00
 ]
        STRHS   LR, [SP, #Result]       ;must have completed if ReadTrk or WriteTrk
        BHS     %FT60

        LDRB    R1, Sector
        LDRB    R0, [R6, #SecsPerTrk]

 [ FlpMultiFS
        LDRB    LR, [R6, #LowSector]
        BIC     LR, LR, #bit7+bit6      ; Get 1st sector no.
        ADD     R0, R0, LR              ; Find last sector
        ADD     R1, R1, #1              ; Next sector
        CMPS    R1, R0                  ; More sectors on this track ?
        MOVHS   R1, LR                  ; No, start from LowSector
 |
        ADD     R1, R1, #1
        CMPS    R1, R0                  ;are there more sectors on this track ?
        MOVHS   R1, #0
 ]

        STRB    R1, [FDC,#FdcSector]    ;Update sector reg if more
        STRB    R1, Sector
        BLO     Recommand               ;still on same track
; CMPS   R4, #WriteSecsOp        ;1.2 ms delay if about to
; MOVEQ  R0, #FloppyEraseDelay*2 ;(change heads OR step in ) after write
; BLEQ   SmallDelay              ;(R0)

        LDRB    R5, [SP,#Head]
        ASSERT  SideBit=1 :SHL: 4
        MOV     R0, R5, LSL #4
        MOV     R1, #SideBit

        LDR     R3, [R2,#HeadPosition]

 [ FlpMultiFS
        LDRB    LR, [R6, #LowSector]
        TSTS    LR, #bit6               ; Sequenced sides?
        MOVNE   R7, #1                  ; Yes, assume 1 head
        LDREQB  R7,[R6,#Heads]          ; Else get head count
 |
        LDRB    R7, [R6,#Heads]
 ]
        CMPS    R7, #1                  ; Sequenced sides?
        BNE     %FT30                   ; No, jump

 [ FlpMultiFS
        TSTS    LR, #bit7               ; Double step?
        STRNEB  R3, [FDC, #FdcTrack]    ; Yes, ensure physical track no.
        ADDNE   R3, R3, #2              ; And track+=2
        ADDEQ   R3, R3, #1              ; Else track++
        CMPS    R3, #TrksPerSide        ; End of side
        BLHS    WrDiscLatch             ; Yes, toggle side (R0,R1) NEEDS SB SET UP
        MOVHS   R5, #1                  ; head := 1
        MOVHS   R3, #0                  ; track := 0
        MOVHS   R4, #RestoreOp          ; restore
        MOVLO   R4, #SeekOp             ; Else seek
 |
        ADD     R3, R3, #1              ;inc track
        TEQS    R3, #TrksPerSide        ;if end of side
        BLEQ    WrDiscLatch             ; toggle side (R0,R1) NEEDS SB SET UP
        MOVEQ   R5, #1                  ; head := 1
        MOVEQ   R3, #0                  ; track := 0
        MOVEQ   R4, #RestoreOp          ; restore
        MOVNE   R4, #StepInOp           ;else step in
 ]
        B       %FT35

30
        EORS    R5, R5, #1              ; Toggle side
        BL      WrDiscLatch             ; Set side (R0,R1) NEEDS SB SET UP

 [ FlpMultiFS
        BNE     %FT35                   ; Side 1? yes then jump
        LDRB    LR, [R6, #LowSector]
        TSTS    LR, #bit7               ; Double step?
        STRNEB  R3, [FDC, #FdcTrack]    ; Yes, ensure physical track no.
        ADDNE   R3, R3, #2              ; And track+=2
        MOVNE   R4, #SeekOp             ; And seek, rely on skew for head settle
        ADDEQ   R3, R3, #1              ; Else increment track
        MOVEQ   R4, #StepInOp           ; And step in, rely on skew for head settle
 |
        ADDEQ   R3, R3, #1              ; If back to side 0 then increment track and
        MOVEQ   R4, #StepInOp           ; step in, rely on skew for head settle
 ]

35
        STRB    R5, [SP,#Head]          ;update head
        STRB    R3, [SP,#DestTrack]     ;update track

Recommand
;R2 drive rec
;R4 next sub disc op
        STR     R4, [SP, #SubDiscOp]
        LDR     R3, [R2, #HeadPosition]
        baddr   R0, FdcOps
        LDRB    R0, [R0,R4]

 [ FlpMultiFS
        TEQS    R4, #ReadTrkOp          ; Read track command?
        LDREQ   LR, [SP, #DiscOp]       ; Yes get discop
        TSTEQS  LR, #DiscOp_Op_AltDefectList_Flag ; And alt defect bit clear
        ORREQ   R0, R0, #bit5           ; Yes, convert read address to read track
 ]

        CMPS    R3, #PrecompTrk         ;IF at or beyond precomp track, C=1
        TSTCSS  R0, #NotPrecompBit      ;AND write, Z=0
        BICHI   R0, R0, #NotPrecompBit  ;then apply pre comp

 [ Debug0
        Push    "r0"
        LDRB    r0, [FDC, #FdcTrack]
        DREG    r0, "Trk ",cc
        Pull    "r0"
 ]
        TSTS    R0, #NotType1Bit
        LDREQB  LR, [SP, #DestTrack]
        STREQB  LR, [FDC, #FdcData]     ;for seek
        LDREQB  LR, [SP, #StepRate]     ;step rate bits for head move ops
        LDRNEB  LR, HeadSettle          ;settle bits for transfer ops
        ORR     R0, R0, LR
        STRB    R0, [SP, #FdcOp]
 [ Debug0
        DREG    R0,"OP"
 ]
        STRB    R0, [FDC,#FdcCommand]   ;recommand if more
        ADD     LR, SP, #FiqDump
        LDMIA   LR, {R0-R7,LR}
        MOV     IOCfiq, #IOC
 retfiq

FiqError
        LDMIA   R7, {Ram,End}           ;set up Ram, End for retry
 [ {TRUE}                               ; Fix for RiscOS 3.10 background blanking bug
        TEQS    R4, R4, LSR #BackBitNo+1        ;HI (C=1,Z=0) <=> Background op
        CMPLSS  R5, End                 ; If foreground compare amount left with scatter chunk
        ADDLS   End,Ram,R5
        ADDHI   End,Ram,End
 |
        CMPS    End, R5                 ;End not needed for background ops
        MOVHI   End, R5
        ADD     End, Ram, End
 ]
;R0 error status
;R2 DriveRec
;R3 SubDiscOp
;R4 DiscOp
;R6 DiscRec
 [ Debug0
        DREG    r0,,cc
 ]
        MOV     LR, #SettleBit
        STRB    LR, HeadSettle          ;set pending head settle after error

        CMPS    R3, #FirstHeadMoveOp    ;C=1 <=> Head move op
        MOVCS   LR, #PositionUnknown   ;Head position unknown after head movement error
        STRCS   LR, [R2, #HeadPosition]

        ASSERT  DiscOp_Op_IgnoreEscape_Flag < &100   ;to preserve C
        TSTS    R4, #DiscOp_Op_IgnoreEscape_Flag
        AND     R4, R4, #DiscOp_Op_Mask

        BNE     %FT45                   ;if ignoring escapes
        LDR     LR, ptr_ESC_Status
        LDRB    LR, [LR]
        ASSERT  EscapeBit<&100  ;to preserve C
        TSTS    LR, #EscapeBit
        MOVNE   R0, #IntEscapeErr
        BNE     FiqEscape

45
        BCS     HeadMoveError

;here if data transfer/verify error
        TSTS    R0, #WProtBit           ;write protect is not classified as a
        MOVNE   R0, #WriteProtErr       ;disc error but treated separately
        BNE     %FT48

        TSTS    R0, #LostBit
        BNE     LostData

 [ Debug0
        DLINE   "T"
 ]
        LDRB    R1, [SP, #FloppyRetryCtr]
        LDRB    LR, [SP, #FRetries]
        CMPS    R1, LR
        BHS     FatalFloppyError        ;retries exhausted
        ADD     R1, R1, #1
 [ Debug0
        DREG    r1,,cc
 ]
        STRB    R1, [SP,#FloppyRetryCtr]
        ANDS    R1, R1, #3
 [ Debug0
        BNE     %FT01
        DLINE   "="
01
 ]
        BEQ     Recommand               ;Retry 0 mod 4 - repeat command

        CMPS    R1, #2                  ;Retry 3 mod 4 - restore then seek back
 [ Debug0
        BLS     %FT01
        DLINE   "R"
01
 ]
        BHI     RestoreRecommand

        MOVLO   R4, #StepInVerifyOp     ;Retry 1 mod 4 - step in then retry
        MOVEQ   R4, #StepOutVerifyOp    ;Retry 2 mod 4 - step out then retry
 [ Debug0
        BHS     %FT01
        DLINE   ">"
01
        BNE     %FT02
        DLINE   "<"
02
 ]
 [ FlpMultiFS
        LDR     R5, [R2,#HeadPosition]
        STRB    R5, [FDC, #FdcTrack]    ; Ensure log. and phys track no. same
 |
        LDRB    R5, [FDC, #FdcTrack]
 ]
        TEQS    R5, #0                  ;don't try to step out beyond track 0
        MOVEQ   R4, #StepInVerifyOp
        CMPS    R5, #TrksPerSide-1
        MOVHS   R4, #StepOutVerifyOp    ;don't try to step in beyond last track
        B       Recommand

HeadMoveError
 [ Debug0
        DLINE   "H"
 ]
        CMPS    R3, #RestoreOp          ;IF sub op = restore
        CMPNES  R4, #FirstHeadMoveOp    ;OR main op is head movement type
        BHS     FatalFloppyError        ;THEN fatal error
RestoreRecommand
        MOV     R4, #RestoreOp
        B       Recommand

LostData
 [ FlpMultiFS
        LDRB    LR, [SP, #FdcOp]        ; Get last command
        AND     LR, LR, #&F0            ; Ignore option bits
        TEQS    LR, #FdcReadTrk:AND:&F0 ; Read track command?
        BEQ     FatalFloppyError        ; Yes then return error, no blanking
 ]
        MOV     LR, #0
        LDR     R1, [LR, #MEMC_CR_SoftCopy]
        AND     R3, R1, #MEMC_DMA_bits
        TEQS    R3, #MEMC_mystate
        BEQ     Recommand
        BIC     R1, R1, #MEMC_DMA_bits
        ORR     R1, R1, #MEMC_mystate
        MOV     R3, R3, LSR #DMAshift
        STR     R1, [LR, #MEMC_CR_SoftCopy]
        STR     R1, [R1]
        LDRB    R1, [SP, #DMAold]               ;note state to restore if first time
        TEQS    R1, #MEMC_mystate :SHR: DMAshift
        STREQB  R3, [SP, #DMAold]
        B       Recommand

FatalFloppyError
;R0 error code
        LDR     R1, [SP, #DiscAdd]
        LDR     LR, [SP, #RamLength]
        ADD     R1, R1, LR              ;end of foregound transfer if completed
        LDR     LR, [SP, #Remains]
        SUB     R1, R1, LR              ;disc address where error occurred

 [ NewErrors
        ! 1, "Need NewErrors case for 1772 driver"
 |
        MOV     R0, R0, LSL #24
        ORR     R0, R0, #DiscErrorBit
        ORR     R0, R0, R1, LSR #8
 ]
48
FiqEscape
        LDR     LR, [SP, #Result]
        CMPS    LR, #-1                 ;EQ <=> in foreground part
        STREQ   R0, [SP, #Result]

        LDR     LR, [SP, #DiscOp]
        TSTS    LR, #DiscOp_Op_BackgroundOp_Flag
        BEQ     %FT60

;COMPLETION OF OP WITH BACKGROUND BIT SET
        LDR     R7, [SP,#ScatterPtr]
50
        MOV     R1, R7
55                      ;loop to search for end of background scatter pairs
        LDR     R2, [R1,#8]!
 [ FixTBSAddrs
        CMN     R2, #ScatterListNegThresh
        BCC     %BT55
 |
        TEQS    R2, #0
        BPL     %BT55
 ]
        ADD     R1, R1, R2

 [ {TRUE}               ;marking process complete now done on FIQ downgrade
        STMDB   SP, {R0,R1,R7}
 |
        TEQS    R0, #0
        STREQ   R0, [R1, #-4]   ;if success set status word in control block to 0
        STMNEDB  R1, {R0,R7}    ;else set error word, status word -> failed pair
 ]

        MOV     R0, #IOC
        LDRB    LR, [R0,#IOCIRQMSKA]    ;background op complete Downgrade to IRQ
        ORR     LR, LR, #FiqDowngradeBit
        STRB    LR, [R0,#IOCIRQMSKA]
        STRB    LR, FiqDowngrade        ;flag that ADFS created Downgrade

60
        MOV     LR, #MotorTimeOut+1
        STRB    LR, MotorTimer          ;Unlock & restart motor timer
        MOV     R0, #IOC
        ASSERT  FdcAddress :MOD: &100=0
        STRB    FDC, [R0, #IOCFIQMSK]   ;Disable all FIQS
        MOV     R0, #0
        LDRB    R1, [SP, #DMAold]
        TEQS    R1, #MEMC_mystate :SHR: DMAshift
        LDRNE   R2, [R0, #MEMC_CR_SoftCopy]
        BICNE   R2, R2, #MEMC_DMA_bits
        ORRNE   R2, R2, R1, LSL #DMAshift
        STRNE   R2, [R2]
        STRNE   R2, [R0, #MEMC_CR_SoftCopy]
        ADD     LR, SP, #FiqDump
        LDMIA   LR, {R0-R7,LR}
 retfiq


; ======
; DecFiq
; ======

;called in SVC mode

DecFiq ROUT
        Push    "R0,R1,SB,LR"
        WritePSRc I_bit :OR: SVC_mode,LR,,R1    ;disable IRQ to prevent reentrance
        LDRB    LR, FiqCtr
        SUBS    LR, LR, #1
        STRB    LR, FiqCtr
        CLRPSR  I_bit,R0,EQ                     ;re-enable IRQs now if about to release
        LDREQ   R0, FiqRelease
        LDREQ   SB, FileCorePrivate
        MOV     LR, PC          ;set return link
        MOVEQ   PC, R0
        RestPSR R1,,cf          ;will return here
        Pull    "R0,R1,SB,PC"


; IIIIIIIIIIIIIIIII
; DoFloppyCallAfter
; IIIIIIIIIIIIIIIII

;called in IRQ mode

DoFloppyCallAfter
        Push    "R0,R1,SB,LR"
        WritePSRc I_bit :OR: SVC_mode,LR,,R1    ;go to SVC mode from IRQ mode
        NOP                                     ;keep IRQs disabled as may need to
                                        ;release FIQ before restart
        MOV     R0, LR                          ; Preserve SVC_R14
        BL      DecFiq

        ADD     SB, SB, # :INDEX: FileCorePrivate
        MOV     LR, PC          ;set return link
        ASSERT  FloppyCallAfter = FileCorePrivate + 4
        LDMIA   SB, {SB,PC}

        MOV     LR, R0          ;will return here - restore SVC_R14
        RestPSR R1,,cf          ; return to callers mode (not necessarily IRQ mode)
        NOP
        Pull    "R0,R1,SB,PC"


; >>>>>>>>>
; IrqVentry
; >>>>>>>>>

IrqVentry
        Push    "R0,R1,LR"
        LDRB    LR, FiqDowngrade
        TSTS    LR, #FiqDowngradeBit
        MOVNE   R0, #IOC                ;dont need to disable FIQ since ADFS owns FIQ
        LDRNEB  LR, [R0,#IOCIRQMSKA]    ;and isnt going to modify IOCIRQMSKA again
        TSTNES  LR, #FiqDowngradeBit
        Pull    "R0,R1,PC",EQ
        BIC     LR, LR, #FiqDowngradeBit
        STRB    LR, [R0,#IOCIRQMSKA]
        STRB    LR, FiqDowngrade
 [ {TRUE}               ;marking process complete now done on FIQ downgrade
        MOV     R0, #FiqStackBase
        LDMDB   R0, {R0,R1,LR}
        TEQS    R0, #0
        STREQ   R0, [R1, #-4]   ;if success set status word in control block to 0
        STMNEDB  R1, {R0,LR}    ;else set error word, status word -> failed pair
 ]
 [ Debug1
 MOV R0,PC
 DREG R0,"IrqVentry PC="
 ]
        BL      DoFloppyCallAfter
        Pull    "R0,R1,LR,PC"           ; Return to caller's caller!!!


; ===========
; WrDiscLatch
; ===========

; CALLED FROM FIQ WITH R13 FIQ stack
; write to floppy control latch

; new = ( old BIC R1 ) EOR R0

WrDiscLatch ROUT
        Push    "R6,R7,LR"
        LDRB    R6, DiscLatchCopy
        BIC     R6, R6, R1
        EOR     R6, R6, R0
        LDR     R7, =DiscLatch
 [ {FALSE}
        ASSERT :LNOT: FIQ32bit               ; this bit trashes the flags, which we're
                                             ; not putting back anymore
        TEQS    PC, PC, LSR #2
        BCC     %FT01
        DREG    R0,,cc
        DREG    R1,,cc
        DREG    R6,,cc
        DLINE   "WrDiscLatch"
01
 ]
        STRB    R6, [R7]
        STRB    R6, DiscLatchCopy
        Pull    "R6,R7,PC"              ; don't use ^ in FIQ mode!

        LTORG

; ==========
; SmallDelay
; ==========

; CALLED FROM FIQ WITH R13 FIQ STACK
; delay for R0/2 micro secs, max 5ms ie half of 100Hz timer period

SmallDelay
        Push    "R0-R3,R6,R7,LR"
        SETPSR  F_bit :OR: I_bit,R2,,R3 ;disable FIQ,IRQ
        ASSERT  Timer0Period = 20000
        MOV     R2,     #Timer0Period :AND: &FF
        ORR     R2, R2, #Timer0Period :AND: &FF00
        MOV     R1, #IoChip
        STRB    R1, [R1,#Timer0LR]      ;latch output
        LDRB    R6, [R1,#Timer0CL]
        LDRB    R7, [R1,#Timer0CH]
        ORR     R6, R6, R7, LSL #8      ;start time
        SUBS    R0, R6, R0
        ADDMI   R0, R0, R2              ;end time
10
        STRB    R1, [R1,#Timer0LR]      ;latch output
        LDRB    R6, [R1,#Timer0CL]
        LDRB    R7, [R1,#Timer0CH]
        ORR     R6, R6, R7,LSL #8       ;current time
        SUBS    R6, R6, R0
        ADDMI   R6, R6, R2              ;time left modulo Timer 0 period
        CMPS    R6, R2, LSR #1
        BLO     %BT10                   ;loop until elapsed
        RestPSR R3,,cf
        Pull    "R0-R3,R6,R7,PC"


; >>>>>>>>>
; MyTickerV
; >>>>>>>>>

; 100 Hz entry

MyTickerV ROUT
        Push    "R0-R1,LR"
        LDRB    R0, Counter
        SUBS    R0, R0, #1
        STRPLB  R0, Counter

;Decrement motor timer unless timed out or in use
        ASSERT  :INDEX:MotorTimer :MOD: 4 = 0
        ASSERT  MotorLock=MotorTimer+1
        LDR     R1, MotorTimer
        CMPS    R1, #&100
        Pull    "R0-R1,PC",HS
        TEQS    R1, #2          ;if about to timeout deselect drive
        MOVEQ   R0, #&FF        ;this will turn motor off etc
        BLEQ    SelectFloppy
        SUBS    LR, R1, #1
        STRGTB  LR, MotorTimer

        Pull    "R0-R1,PC"


; ============
; SelectFloppy
; ============

; Select floppy drive - will turn motor off etc if a different drive was in use

; entry R0 = drive 0 to 3, or &FF select no drive

SelectFloppy ROUT
        Push    "R0-R3,LR"
        SETPSR  I_bit,LR,,R3            ;disable IRQ stops motor timer
        MOV     R2, R0

        LDRB    R1, SelectedFloppy
        TEQS    R1, R2
        BEQ     %FT10                   ;IF not changing drive

        MOV     R0, #Delay15or30msBit
        STRB    R0, HeadSettle
        LDRB    R0, MotorTimer
        CMPS    R0, #1
        BLO     %FT10

        CMPS    R1, #4
        BHS     %FT05

        DrvRecPtr  R0, R1

        LDRB    LR, [R0,#DrvFlags]      ;if disc changed doesn't work inc seq num
        TSTS    LR, #MiscOp_PollChanged_ChangedWorks_Flag
        LDREQ   LR, [R0,#DrvSequenceNum]
        ADDEQ   LR, LR, #1
        STREQ   LR, [R0,#DrvSequenceNum]
05
        MOV     R0, #MotorBits          ;  Turn motor off
        MOV     R1, #MotorBits
        BL      WrDiscLatch
        MOV     R0, #1                  ;set motor timer timed out
        STRB    R0, MotorTimer          ;FI
10
        B       SelectCommon

; ================
; TempSelectFloppy
; ================

TempSelectFloppy
        Push    "R0-R3,LR"
        SavePSR R3
 [ Debug4
        DREG    R0,,cc
        DLINE   "TempSelectFloppy"
 ]
        MOV     R2, R0
SelectCommon
        MOV     R0, #&FF
        STRB    R0, SelectedFloppy
        MOV     R0, #Drive0             ;select drive by latch
        MOV     R0, R0, LSL R2          ;still works if R2=&FF
        EOR     R0, R0, #DriveBits
        MOV     R1, #DriveBits
        BL      WrDiscLatch
        STRB    R2, SelectedFloppy
        RestPSR R3,,cf
        Pull    "R0-R3,PC"


; =============
; WrSharedLatch
; =============

; latch := ( latch BIC R1 ) EOR R0, all regs preserved

WrSharedLatch ROUT
        Push    "R2-R4,LR"
 [ Debug1 :LOR: Debug2
        DREG    R0,"*Latch set=",cc
        DREG    R1,"*Latch mask=",cc
 ]
        SETPSR  I_bit,LR,,R4            ;disable IRQ
        LDR     R3, =LatchBSoftCopy
        LDRB    R2, [R3]
        BIC     R2, R2, R1
        EOR     R2, R2, R0
        LDR     LR, =SharedLatch
        STRB    R2, [LR]
        STRB    R2, [R3]
 [ Debug1 :LOR: Debug2
        DREG    R2,"*Latch now="
 ]
        RestPSR R4,,cf
        Pull    "R2-R4,PC"

        LTORG

; ==========
; OldDoMount
; ==========

;entry
; R1 drive
; R2 disc address
; R3 -> buffer
; R4 length
; R5 -> disc rec to fill in for floppies

;exit R0,V internal error

OldDoMount ROUT
 [ FlpMultiFS
        Push    "R0-R9,LR"
        SUB     SP, SP, #MountBufferSize ; buffer for readtrackop

        LDRB    R6, [R5,#Density]       ; Get suggested density

; Build a temporary discrec to identify the disc

        ASSERT  SectorSize=0
        ASSERT  SecsPerTrk=1
        ASSERT  Heads=2
        ASSERT  Density=3
        LDR     LR, =&0002050A
        STR     LR, [R5]                ; Assume 5*1K sectors, 2 heads

        DrvRecPtr R7, R1
        MOV     LR, #PositionUnknown
        STR     LR, [R7, #HeadPosition] ; Force restore

        LDRB    R8, FloppyMountRetries
        TEQS    R6, #0                  ; Density unknown
        MOVEQ   R6, #Double             ; Yes, try double
30      STRB    R6, [R5,#Density]       ; Density to try
        MOV     R1, #ReadTrkOp :OR: DiscOp_Op_IgnoreEscape_Flag :OR: DiscOp_Op_AltDefectList_Flag ; Read ID's
        Push    "R2-R4,R6"
        MOV     R6, #bit31              ; 0 retries OR mount flag
        AND     R2, R2, #DiscBits       ; Force read from track 0
        ADD     R3, SP, #4*4            ; To buffer on stack
        MOV     R4, #MountBufferSize
        BL      RetryFloppyOp
        Pull    "R2-R4,R6"
        BVC     %FT40                   ; Jump if read ok

        EOR     R6, R6, #Double :EOR: Single  ; Try single/double alternate
        TEQS    R0, #DriveEmptyErr      ;don't try other density if Time out
        SUBNES  R8, R8, #1              ;count retries
        BHS     %BT30                   ;loop if more tries
        BL      SetV
        B       %FT50                   ;couldn't read FS map

; Fill in disc record, (sectors per track updated by RetryFloppyOp)

40
        MOV     r0, sp
        BL      DetermineTrackParameters

; Perform any data read requested

        LDRB    R6, FormatFlag
        TEQS    R6, #0
        LDREQB  R6, FloppyMountRetries
        ORR     R6, R6, #bit31          ; Set mount bit
        MOV     R1, #ReadSecsOp :OR: DiscOp_Op_IgnoreEscape_Flag
        SUBS    R0, R4, #0              ; Any data to read?
        BLNE    RetryFloppyOp           ; Yes then call

50
        ADD     SP, SP, #MountBufferSize
        STRVS   R0, [SP]
        Pull    "R0-R9,PC"
 |

        Push    "R0-R9,LR"

        ASSERT  SectorSize=0
        ASSERT  SecsPerTrk=1
        ASSERT  Heads=2
        ASSERT  Density=3
;use the block in which the disc rec will be returned to build a temporary disc
;rec to identify the disc
        LDR     LR, =&0002050A
        STR     LR, [R5]
        DrvRecPtr  R7, R1
        MOV     LR, #PositionUnknown
        STR     LR, [R7, #HeadPosition] ;to force restore
        LDRB    R8, FormatFlag
        TEQS    R8, #0
        LDREQB  R8, FloppyMountRetries
        MOV     R6, #Double
30
        STRB    R6, [R5,#Density]
        MOV     R1, #ReadSecsOp :OR: DiscOp_Op_IgnoreEscape_Flag
        Push    "R2-R4,R6"
        MOV     R6, #bit31      ;0 retries OR mount flag
        BL      RetryFloppyOp
        Pull    "R2-R4,R6"
        BVC     %FT40
        TEQS    R0, #DriveEmptyErr      ;don't try other density if Time out
        SUBNES  R8, R8, #1              ;count retries
        BNE     %BT30                   ;loop if more tries
        BL      SetV
        B       %FT50                   ;couldn't read FS map
40
;now fill in disc record

;the sector size of the disc is found by looking at the number of sectors read.
;This is messy but saves a read address command.
        LDRB    R0, Sector
        LDRB    LR, StartSector
        SUB     R0, R0, LR
        ADD     R0, R0, #1
        TEQS    R0, R4, LSR #8  ;IF 256 byte sectors
        ASSERT  SectorSize=0
        ASSERT  SecsPerTrk=1
        ASSERT  Heads=2
        ASSERT  Density=3
;use the block in which the disc rec will be returned to build a temporary disc
;rec to identify the disc
        LDREQ   LR, =&02011008
        STREQ   LR, [R5]

        MOVEQ   R0, #L_Root
        MOVEQ   LR, #L_Size
        MOVNE   R0, #D_Root
        MOVNE   LR, #D_Size
        STR     R0, [R5, #RootDir]
        STR     LR, [R5, #DiscSize]     ; V=0
 [ BigDisc
        MOV     LR, #0
        STR     LR, [R5, #DiscSize2]
 ]
50
        STRVS   R0, [SP]
        Pull    "R0-R9,PC"
 ]

        LTORG

; ================
; OldDoPollChanged
; ================

; Examine and act on disc changed signal for floppy drive

;entry
; R1 drive 0-3
; R2 sequence number

;exit
; R2 new sequence number
; R3 status bits

OldDoPollChanged ROUT
        Push    "R0,R1,R4-R9,LR"
 [ Debug4
        DLINE   "*Enter CheckChange"
 ]
        SETPSR  I_bit,LR,,R1    ;disable IRQ to prevent motor timeout
        Push    R1
        DrvRecPtr  R4,R1
        LDRB    R5, [R4,#DrvFlags]
        LDR     R6, [R4,#DrvSequenceNum]
        LDRB    R7, SelectedFloppy
        MOV     R0, R1
        BL      TempSelectFloppy
        LDRB    R8, MotorTimer
        CMPS    R8, #1          ;remember if motor was on
        MOVEQ   R0, #0
        MOVEQ   R1, #MotorBits
        BLEQ    WrDiscLatch     ;floppy selected with motor on before test
        BL      %FT95                   ;Poll Changed  corrupts R0,R1,R9
        BNE     %FT10

; Disk change line not asserted.  If non-functional, DiscOp bumps
; the sequence number at motor off to ensure "changed" on next poll

 [ Debug4
        DREG    r6, "ADFS internal sequence number "
 ]

        TSTS    R5, #MiscOp_PollChanged_ChangedWorks_Flag           ; Does disk change work?
        MOVNE   R3, #MiscOp_PollChanged_Changed_Flag                ; Yes then assume changed
        MOVEQ   R3, #MiscOp_PollChanged_MaybeChanged_Flag           ; Else maybe changed
        TEQS    R2, R6                          ; Out of sequence?
        MOVEQ   R3, #MiscOp_PollChanged_NotChanged_Flag             ; No then not changed
        MOV     R2, R6                          ; Return our sequence number
        B       %FT20

10
        ORR     R5, R5, #MiscOp_PollChanged_ChangedWorks_Flag :OR: MiscOp_PollChanged_EmptyWorks_Flag
        ADD     R2, R6, #1
        STR     R2, [R4,#DrvSequenceNum]

        TSTS    R5, #ResetChangedByStep
        BNE     %FT12
 [ Debug4
        DLINE   "*reset changed by write"
 ]
        MOV     R0, #NotResetDiscChangedBit     ;Take Not Reset disc changed line
        MOV     R1, #NotResetDiscChangedBit
        BL      WrDiscLatch                     ;HI
        MOV     R0, #0
        BL      WrDiscLatch                     ;LO
        MOV     R0, #NotResetDiscChangedBit
        BL      WrDiscLatch                     ;HI
        BL      %FT95                           ;Poll Changed  corrupts R0,R1,R9
        ORREQ   R5, R5, #ResetChangedByWrite
        BEQ     %FT18
        TSTS    R5, #ResetChangedByWrite
        BNE     %FT18
12

 [ Debug4
        DLINE   "*reset changed by step"
 ]
        MOV     R0, #DoubleBits :OR: FdcResetBit
        MOV     R1, #DensityBits :OR: FdcResetBit
        BL      WrSharedLatch
        LDR     R1, =FdcAddress

        MOV     R0, #FdcAbort           ;kill any FDC Op
        STRB    R0, [R1,#FdcCommand]
        MOV     R0, #32*2
        BL      SmallDelay              ;32 micro sec delay

14                              ;wait for FDC not busy
        LDRB    LR, [R1,#FdcStatus]
        TSTS    LR, #BusyBit
        BNE     %BT14

        LDR     R9, [R4,#HeadPosition]
        CMPS    R9, #0
        CMPNES  R9, #PositionUnknown
        MOVEQ   R0, #FdcStepIn
        MOVNE   R0, #FdcStepOut

        ASSERT  PositionUnknown :AND: &FF = 0
        STRB    R9, [R1,#FdcTrack]

        STRB    R0, [R1,#FdcCommand]
        MOV     R0, #IoChip
15                              ;wait for command completion
        LDRB    LR, [R0,#IOCFIQSTA]
        TSTS    LR, #IoFloppyIrqBit
        BEQ     %BT15

16                              ;wait for FDC not busy
        LDRB    LR, [R1,#FdcStatus]
        TSTS    LR, #BusyBit
        BNE     %BT16

        MOVS    R9, R9
        ADDEQ   R9, R9, #1
        ASSERT  PositionUnknown :AND: bit31 = bit31
        SUBPL   R9, R9, #1
        STR     R9, [R4,#HeadPosition]

        BL      %FT95                   ;Poll Changed  corrupts R0,R1,R9
        ORREQ   R5, R5, #ResetChangedByStep

18
        MOVEQ   R3, #MiscOp_PollChanged_Changed_Flag
        MOVNE   R3, #MiscOp_PollChanged_Empty_Flag
        STRB    R5, [R4,#DrvFlags]
20
        AND     LR, R5, #MiscOp_PollChanged_ChangedWorks_Flag :OR: MiscOp_PollChanged_EmptyWorks_Flag
        ORR     R3, R3, LR

        CMPS    R8, #1
        MOVEQ   R0, #MotorBits
        MOVEQ   R1, R0
        BLEQ    WrDiscLatch     ;if motor was off turn it off again
        MOV     R0, R7
        BLPL    TempSelectFloppy
        Pull    "R1"
        RestPSR R1,,cf
        Pull    "R0,R1,R4-R9,PC"


95                      ;POLL CHANGED SIGNAL, NE <=> changed corrupts R0,R1
        MOV     R0, #IoChip
        LDRB    R1, [R0,#IoIrqBStatus]
        TSTS    R1, #DiscChangedBit
 [ Debug4
        BNE     %FT01
        DLINE   "*Not Changed"
        B       %FT02
01
        DLINE   "*Changed"
02
 ]
        MOV     PC, LR


; ===========
; OldDoLockDrive
; ===========

;entry
; R1 drive

OldDoLockDrive ROUT
        Push    "R0-R2,LR"
        SETPSR  I_bit,LR,,R2    ;disable IRQ
        MOV     R0, R1
        BL      SelectFloppy
        MOV     R0, #0          ;Turn motor on
        MOV     R1, #MotorBits
        BL      WrDiscLatch
        MOV     LR, #MotorTimeOut+1
        LDRB    R0, MotorTimer
        TEQS    R0, #1
        STREQB  LR, MotorTimer
        STRB    LR, MotorLock
        RestPSR R2,,cf
        Pull    "R0-R2,PC"


; =============
; OldDoUnlockDrive
; =============

;entry
; R1 drive

OldDoUnlockDrive ROUT
        Push    "LR"
        MOV     LR, #0
        STRB    LR, MotorLock
        Pull    "PC"


;-----------------------------------------------------------------------;
; Flp1772format                                                         ;
;       Construct track image from disc format specification and write  ;
;       the track                                                       ;
;                                                                       ;
; Input:                                                                ;
;       R2 = disc address (sector/track aligned), top 3 bits = drive    ;
;       R3 = 0                                                          ;
;       R4 -> Disk format specification                                 ;
;       R12 = SB                                                        ;
;                                                                       ;
; Output:                                                               ;
;       R0 = preserved, VC, No error                                    ;
;          = Error code, VS                                             ;
;                                                                       ;
; Modifies:                                                             ;
;       R5,R6,R7,R8, flags except V                                     ;
;_______________________________________________________________________;
;
Flp1772format   ROUT
        Push    "R0-R4,LR"

; Calc. Log2 sector size

        LDR     R0, [R4, #DoFormatSectorSize] ; Get sector size
        TSTS    R0, #&7F                ; Check not odd size
        BLNE    FlpForceErr             ; Force error
        BNE     %FT90                   ; Error exit

        MOV     R1, #7                  ; Log2 of smallest sector size
10      MOVS    LR, R0, LSR R1
        BLCS    FlpForceErr             ; Error if not power of 2
        BCS     %FT90                   ; Error exit
        TEQS    LR, #1                  ; R0 = 2^R1?
        ADDNE   R1, R1, #1              ; No then try next power of 2
        BNE     %BT10                   ; And repeat

; Construct a disc record, R1= Log2 sector size

 [ Debug30
        DREG    R1, "Log2 Size ",cc
 ]
        sbaddr  R5, FlpDCB              ; Use disk control block space
        STRB    R1, [R5, #SectorSize]

        LDRB    R6, [R4, #DoFormatDensity]
        STRB    R6, [R5, #Density]
 [ Debug30
        DREG    R6, " Density ",cc
 ]
        TEQS    R6, #Single
        TEQNES  R6, #Double             ; Single or double density?
        BLNE    FlpForceErr             ; No, then force error
        BNE     %FT90                   ; Error exit

        LDRB    R0, [R4, #DoFormatSectorsPerTrk] ; Sectors per track
        STRB    R0, [R5, #SecsPerTrk]

        LDRB    R0, [R4, #DoFormatOptions]
        TSTS    R0, #FormatDoubleStep   ; Double stepping
        MOVNE   LR, #bit7               ; Yes set double step bit in LowSector
        MOVEQ   LR, #0
        TSTS    R0, #FormatSequenceSides ; Sequenced sides?
        ORRNE   LR, LR, #bit6           ; Yes set sequenced sides bit
        STRB    LR, [R5, #LowSector]
        MOVNE   LR, #1                  ; And 1 head
        MOVEQ   LR, #2                  ; Else 2 heads
        STRB    LR, [R5, #Heads]
 [ Debug30
        DREG    LR, " Heads ",cc
 ]

; Construct a track image

        MOV     R3, #ScratchSpace       ; Use system space for track image
        TSTS    R0, #FormatIndexMark    ; Index mark wanted?
        BEQ     %FT20                   ; No then jump

; Construct index address mark

 [ Debug30
        DLINE   " IAM",cc
 ]
        TEQS    R6, #Single
        MOVNE   R1, #80                 ; MFM 80 bytes &4E
        MOVNE   R0, #&4E
        MOVEQ   R1, #40                 ; FM 40 bytes &FF
        MOVEQ   R0, #&FF
        BL      FlpFillBuff             ; Add gap5 (R0,R1,R3->R3)
        MOVNE   R1, #12                 ; MFM 12 bytes 0
        MOVEQ   R1, #6                  ; FM 6 bytes 0
        MOV     R0, #0
        BL      FlpFillBuff             ; Add sync (R0,R1,R3->R3)
        MOVNE   R1, #3
        MOVNE   R0, #&F6                ; MFM write 3*&C2
        BLNE    FlpFillBuff             ; MFM IAM (R0,R1,R3->R3)
        MOV     R0, #&FC
        STRB    R0, [R3], #1            ; IAM

; Insert Gap1

20      LDR     R1, [R4, #DoFormatGap1] ; Get gap1 size
        TEQS    R6, #Single
        MOVNE   R0, #&4E                ; MFM data
        MOVEQ   R0, #&FF                ; FM gap1 data
        BL      FlpFillBuff             ; Gap1 (R0,R1,R3->R3)

; Lay done all sectors requested

        LDRB    R7, [R4, #DoFormatSectorsPerTrk]
 [ Debug30
        DREG    R7, " SPT ",cc
 ]
        ADD     R8, R4, #DoFormatSectorList ; R8-> Start of ID list

; Insert ID address mark

30      TEQS    R6, #Single             ; MFM?
        MOVNE   R1, #12                 ; MFM 12 bytes 0
        MOVEQ   R1, #6                  ; FM 6 bytes 0
        MOV     R0, #0
        BL      FlpFillBuff             ; Sync (R0,R1,R3->R3)
        MOVNE   R1, #3
        MOVNE   R0, #&F5                ; MFM write 3*&A1
        BLNE    FlpFillBuff             ; MFM ID address mark (R0,R1,R3->R3)
        MOV     R0, #&FE
        STRB    R0, [R3], #1            ; ID address mark

; Insert sector ID

        LDR     R0, [R8], #4            ; Get next sector ID
        STRB    R0, [R3], #1            ; C
        MOV     R0, R0, LSR #8
        STRB    R0, [R3], #1            ; H
        MOV     R0, R0, LSR #8
        STRB    R0, [R3], #1            ; R
        MOV     R0, R0, LSR #8
        STRB    R0, [R3], #1            ; N
        MOV     R0, #&F7
        STRB    R0, [R3], #1            ; CRC
        STRB    R0, [R3], #1            ; CRC

; Insert gap2

        MOVNE   R1, #22
        MOVNE   R0, #&4E                ; MFM 22 bytes of &4E
        MOVEQ   R1, #11
        MOVEQ   R0, #&FF                ; FM 11 bytes of &FF
        BL      FlpFillBuff             ; Gap2 (R0,R1,R3->R3)

; Insert data address mark

        MOVNE   R1, #12                 ; MFM 12 bytes 0
        MOVEQ   R1, #6                  ; FM 6 bytes 0
        MOV     R0, #0
        BL      FlpFillBuff             ; Sync (R0,R1,R3->R3)
        MOVNE   R1, #3
        MOVNE   R0, #&F5                ; MFM write 3*&A1
        BLNE    FlpFillBuff             ; MFM data address mark (R0,R1,R3->R3)
        MOV     R0, #&FB
        STRB    R0, [R3], #1            ; Data address mark

; Insert data

        LDR     R1, [R4, #DoFormatSectorSize]
        LDRB    R0, [R4, #DoFormatFillValue]
        BL      FlpFillBuff             ; Fill data (R0,R1,R3->R3)
        MOV     R0, #&F7
        STRB    R0, [R3], #1            ; CRC
        STRB    R0, [R3], #1            ; CRC

; Insert gap3

        LDR     R1, [R4, #DoFormatGap3]
        MOVNE   R0, #&4E
        MOVEQ   R0, #&FF
        BL      FlpFillBuff             ; Gap3 (R0,R1,R3->R3)

; Repeat for all sectors

        SUBS    R7, R7, #1              ; Decr sector count
        BHI     %BT30                   ; Repeat for all sectors

; Add a short gap4

        MOV     R1, #&10
        BL      FlpFillBuff             ; Gap4 (R0,R1,R3->R3)

; Format the track

        MOV     R8, #ScratchSpace
        SUB     R4, R3, R8              ; Track length
        MOV     R3, R8                  ; Track buffer start
 [ Debug30
        DREG    R4, " Length "
 ]
        LDR     R1, [SP, #4]            ; Restore write track op
        LDRB    R6, FloppyRetries       ; Retries
        MOV     R0, #0
        BL      RetryFloppyOp           ; Write the track

90      BL      SetVOnR0
        STRVS   R0, [SP]
        Pull    "R0-R4,PC"


FlpFillBuff     ROUT                    ; Write track image (R0,R1,R3->R3)
        Push    "R0-R2"
        SavePSR R2
10      SUBS    R1, R1, #1              ; Decr count
        STRHSB  R0, [R3], #1            ; Write to buffer if space
        BHI     %BT10                   ; Jump if more
        RestPSR R2,,f
        Pull    "R0-R2"
        MOV     PC, LR


FlpForceErr     ROUT                    ; Release FIQ's, error exit
        Push    "LR"
        MOV     R0, #BadParmsErr
        MOV     LR, #1
        STRB    LR, FiqCtr
        BL      DecFiq                  ; Release FIQ's (preserves flags)
        Pull    "PC"

 ]

        END
