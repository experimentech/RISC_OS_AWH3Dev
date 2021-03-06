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
; MultiFS formatting support for ADFS

; Syntax:
; *Format <drive> [<format> [<name>]] [Y]
; <format> can be one of:
;   .
;   .
;   .
; the default format is FileCore E format
; <name> is the disc's name
; Y, if present, will cause the confirmation of the format
; to be skipped.


FH0     DCB     "FH0", 0 ; Intro
FH1     DCB     "FH1", 0 ; Default is E
FH2     DCB     "FH2", 0 ; Default is F
FH3     DCB     "FH3", 0 ; Syntax
        ALIGN

HelpFormat ROUT
        Push    "lr"
        getSB
        baddr   r0, FH0
        BL      message_gswrite0
        BVS     %FT90
        MOV     r0, #0
        MOV     r1, #Service_DisplayFormatHelp
        SWI     XOS_ServiceCall
        TEQ     r0, #0
        SETV    NE
        baddr   r0, FH2, VC
 [ Support1772
        LDR     lr, MachineID
        TEQ     lr, #MachHas1772
        baddr   r0, FH1, EQ
 ]
        BLVC    message_gswrite0
        baddr   r0, FH3, VC
        BLVC    message_gswrite0

90
        MOV     r0, #0
        Pull    "pc"

;---------------
; CheckDiscName
;
; In
;   r1->disc name
; Out
;   r0 corrupt V and error possible

CheckDiscName ROUT
        Push    "r1,r3,lr"
        MOV     r3, #0
        MOV     r0, r1
10
        LDRB    lr, [r0], #1
        TEQ     lr, #"@"
        TEQNE   lr, #"#"
        TEQNE   lr, #"$"
        TEQNE   lr, #"%"
        TEQNE   lr, #"^"
        TEQNE   lr, #"&"
        TEQNE   lr, #"*"
        TEQNE   lr, #"\\"
        TEQNE   lr, #":"
        TEQNE   lr, #""""
        TEQNE   lr, #"."
        BEQ     %FT90
        TEQ     lr, #0
        ADDNE   r3, r3, #1
        BNE     %BT10

        CMP     r3, #2
        RSBHSS  lr, r3, #NameLen
        Pull    "r1,r3,pc",HS

90
        ; Bad disc name
        baddr   r0, BadNameErrBlk
        BL      copy_error
        SETV
        Pull    "r1,r3,pc"

;
; The sequence of events in *Format is as follows:
;
; *  Process the command line, including identifying the format
; *  Zero out a defect pool
; *  For each track:
;       Repeat
;          Format the track
;          Verify the non-bad sectors on the track
;          Add any new bad sectors to the defect pool
;       Until no new bad sectors added to the defect pool
; *  Open the newly formatted disc as a file
; *  LayoutStructure into this file

FormatReadArgsString
        DCB     "/A,,,,", 0
        ALIGN

MaxDefects      *       128

; Format local variables
        ^       0, sp
FormatDrive     #       1
ConfirmThis     #       1
FirstDefectOnTrack #    1
GottenError     # 1
AcceptedFormat  #       4
AcceptedA       #       4
AcceptedB       #       4
LayoutSWI       #       4
LayoutParam     #       4
FormatDiscName  #       4
OldDefectEnd    #       4
TrackDefects    #       4
CopyErrorBlock  #       256
FormatDiscRecord #      SzDiscRec
FormatParamBlk  #       SzFormatBlock
DoFormatBlk     #       DoFormatSectorList + 256*4
ReadArgsArea    #       128
ScatterList     #       256*4
DefectPool      #       MaxDefects*4 + 4
SzFormatVars    *       :INDEX:{VAR} + 15 :AND: :NOT: 15

FormatTrack     DCB     "FC0",0
MapOutDefect    DCB     "FC1",0
FormatDetails   DCB     "FC2",0
FormatTracksTot DCB     "FC3",0
DefaultFormatE  DCB     "E", 0
DefaultFormatF  DCB     "F", 0
ImageNameTplt   DCB     "adfs::0", 0
FormDate        DCB     "%24_%mi_%w3", 0
        ALIGN

DoFormat ROUT
        Push    "r0-r11,lr"

        ; Convert r12 to statics pointer
        getSB

        ; Get stack space for formatting
        SUB     sp, sp, #SzFormatVars

        ; Confirm off by default, DiscName is not present
        MOV     lr, #0
        STR     lr, FormatDiscName
        STRB    lr, ConfirmThis
        STRB    lr, GottenError

        ; Read the args
        MOV     r1, r0
        ADR     r0, FormatReadArgsString
        ADRL    r2, ReadArgsArea
        MOV     r3, #?ReadArgsArea
        SWI     XOS_ReadArgs
        BVS     %FT96

        ; Find out which disc need formatting

        LDR     r1, ReadArgsArea + 0*4

        ; Skip a : if present
        LDRB    r0, [r1]
        TEQS    r0, #":"
        ADDEQ   r1, r1, #1

        ; check the drive
        BL      ParseAnyDrive           ;(R1->R0,R1,V)
        BVS     %FT96                   ; bad drive

        ; Check drive is a floppy
        LDRB    lr, Floppies
        CMPS    r0, lr
        baddr   r0, BadDriveErrBlk,HS
        BHS     %FT97                    ; bad drive number

        ; Save drive number
        STRB    r0, FormatDrive

        ; Pointer to first and last unparsed fields
        ADRL    r7, ReadArgsArea + 1*4
        ADRL    r6, ReadArgsArea + 4*4

        ; Find the last unparsed field
        LDR     r0, [r6]
        TEQ     r0, #0
        LDREQ   r0, [r6, #-4]!
        TEQEQ   r0, #0
        LDREQ   r0, [r6, #-4]!
        TEQEQ   r0, #0
        LDREQ   r0, [r6, #-4]!
        TEQEQ   r0, #0

        ; No extra fields at all - default to E format
        SUBEQ   r6, r6, #4              ; To make sure params left = 0
        BEQ     %FT04

        ; Try to identify the 2nd field as a format in all circumstances
        LDR     r0, [r7]
        MOV     r1, #Service_IdentifyFormat
        SWI     XOS_ServiceCall
        BVS     %FT96

        ; Was the service serviced, indicating that the 2nd field was a format?
        ; If not then its a bad format.
        TEQ     r1, #Service_Serviced
        baddr   r0, BadFormatErrBlk, NE
        BNE     %FT97

        ; 2nd field was a format
        LDR     r0, ReadArgsArea + 1*4
        STR     r0, AcceptedFormat
        ADD     r7, r7, #4
        B       %FT06

04
 [ Support1772
        LDR     lr, MachineID
        TEQ     lr, #MachHas1772
 [ Debug30
 BNE    %FT01
 DLINE  "Defaulting to E format"
 ]
        baddr   r0, DefaultFormatE, EQ
        BEQ     %FT05
 ]
 [ Debug30
 DLINE  "Defaulting to F format"
 ]
        ; Default to F format
        baddr   r0, DefaultFormatF
05      STR     r0, AcceptedFormat
        MOV     r1, #Service_IdentifyFormat
        SWI     XOS_ServiceCall
        BVS     %FT96

        TEQ     r1, #Service_Serviced
        BEQ     %FT06

        ; "E", the default format wasn't picked up
        baddr   r0, BadFormatErrBlk
        B       %FT97

06
        STR     r2, AcceptedA
        STR     r3, AcceptedB
        STR     r4, LayoutSWI
        STR     r5, LayoutParam

        SUB     lr, r6, r7
        CMP     lr, #0*4
        BLE     %FT08           ; Yes, signed LE

        ; Two parameters left: must be disc name and Y - if not Y then a bad command
        LDR     r1, [r6]
        BL      IsStringYes
        baddr   r0, BadComErrBlk, NE
        BNE     %FT97

        MOV     r0, #1
        STRB    r0, ConfirmThis
        LDR     r1, [r7]
        B       %FT10

08
        ; 0 or 1 parameter left
        BLT     %FT15           ; Yes, signed LT

        ; 1 parameter left - if Y take it as the Y parameter, otherwise the disc name
        LDR     r1, [r6]
        BL      IsStringYes
        MOVEQ   r0, #1
        STREQB  r0, ConfirmThis
        BEQ     %FT15

        ; Last parameter wasn't Y, so it must be the disc's name
10
        STR     r1, FormatDiscName
        B       %FT20

15
        ; No disc name specified - invent one
        ADRL    r1, ReadArgsArea        ; Unused by now
        BL      ReadTimeDate
        Push    "r7,r8"
        MOV     r0, sp
        MOV     r2, #10
        baddr   r3, FormDate
        SWI     XOS_ConvertDateAndTime
        ADD     sp, sp, #2*4
        ADRL    r1, ReadArgsArea
        STR     r1, FormatDiscName

20
        LDR     r1, FormatDiscName
        BL      CheckDiscName
        BVS     %FT96

        ; Retrieve the format paramaters
        LDR     r2, AcceptedA
        LDR     r3, AcceptedB
        LDR     r4, LayoutSWI
        LDR     r5, LayoutParam

; R2 = SWI number to call to obtain raw disc format information
; R3 = Parameter in R3 to use when calling disc format SWI
; R4 = SWI number to call to lay down disc structure
; R5 = Parameter in R0 to use when calling disc structure SWI
; FormatDiscName is NULL or points to the disc name
; ConfirmThis is non-0 if confirm has been pre-yesed
; FormatDrive is drive to be formatted

 [ Debug30
 DREG   r2, "<FS>_DiscFormat = "
 DREG   r3, "   ....(",cc
 DLINE  ")"
 DREG   r4, "<FS>_LayoutStructure = "
 DREG   r5, "   ....(",cc
 DLINE  ")"
 Push   "r0"
 LDR    r0, FormatDiscName + 4
 DSTRING r0, "Disc name "
 DREG   r0, "Confirm this is "
 LDRB   r0, FormatDrive + 4
 DREG   r0, "Format drive is "
 Pull   "r0"
 ]

        ; Save these in local variables
        STR     r4, LayoutSWI
        STR     r5, LayoutParam

        ; Construct the parameters and vet them using the SWI provided
        MOV     r11, r2                 ; <MultiFS>_DiscFormat
        ADR     r0, FormatParamBlk      ; format spec block
        LDR     r1, =XADFS_VetFormat
        LDRB    r2, FormatDrive         ; drive number
        BL      CallASWI
        BVS     %FT96

 [ Debug30
 DLINE  "Format now vetted"
 ]
        ; Tell the user about the format
        LDR     r5, AcceptedFormat
        LDR     r6, FormatDiscName
        LDRB    lr, FormatDrive
        ADD     lr, lr, #"0"
        Push    "lr"                    ; Includes \0-terminator for free
        MOV     r4, sp
        baddr   r0, FormatDetails
        BL      message_gswrite03
        ADD     sp, sp, #4
        BVS     %FT96

        ; Don't bother confirming if Y option specified.
        LDRB    lr, ConfirmThis
        TEQ     lr, #0
        BNE     %FT30

        BL      Confirm                 ;(->R0,Z,V)
        BNE     %FT96

30
        ; Tell the user how many tracks are going to get formatted
        LDR     r0, FormatParamBlk + FormatTracksToFormat
        SUB     sp, sp, #12
        MOV     r1, sp
        MOV     r2, #12
        SWI     XOS_ConvertCardinal4
        ADDVS   sp, sp, #12
        BVS     %FT96

        MOV     r4, sp
        baddr   r0, FormatTracksTot
        BL      message_gswrite01
        ADD     sp, sp, #12
        BVS     %FT96

        ; *Dismount the disc (avoids FileCore embarasment)
        LDRB    r0, FormatDrive
        BL      DismountDiscByNumber

        ; OK, now we do the physical format.
        ; Formatting works as follows:
        ; Zero out a defect list (held in scratch space). This defect list will
        ;    be used to accumulate all defects seen during the verify stages.
        ; For each track:
        ;    Repeat
        ;       Format the track
        ;       Verify the non-bad sectors on the track
        ;       Add any new bad sectors to the defect pool
        ;    Until no new bad sectors added to the defect pool

        ; Zero out the defects list
        ADRL    r11, DefectPool
        MOV     lr, #bit29
        STR     lr, [r11]

        ; Fill in the records
        ADR     r0, FormatParamBlk
        ADR     r2, FormatDiscRecord
        ADR     r4, DoFormatBlk
        BL      ConstructDoFormatRecord

        ; Track counter
        MOV     r10, #0

        ; Register allocation throughout the loop:
        ; r11 - Defect pool end pointer
        ; r10 - track counter

        ; Start the Format/Verify sequence

35
        ; Update visual track count
        SUB     sp, sp, #12
        ADD     r0, r10, #1
        MOV     r1, sp
        MOV     r2, #12
        SWI     XOS_ConvertCardinal4
        baddr   r0, FormatTrack, VC
        MOVVC   r4, sp
        BLVC    message_gswrite01
        ADD     sp, sp, #12
        BVS     %FT95

        ; r11 - Defect pool end pointer
        ; r10 - track counter

        ; Mark down indication of which defect we're up to
        MOV     lr, #1
        STRB    lr, FirstDefectOnTrack

        ; Start of defects for this track
        STR     r11, TrackDefects

40
        ; Old defect end before format/verify sequence on this track
        STR     r11, OldDefectEnd

        ; Construct DoFormat record and disc address of track start
        ADR     r0, FormatParamBlk
        MOV     r1, r10
        ADR     r4, DoFormatBlk
        BL      ConstructDoFormatIdList
 [ Debug30
 Push   "r0,r1"
 DLINE  "Defect pool:",cc
 ADRL   r1, DefectPool+8
 B %FT02
01
 DREG   r0," ",cc
02
 LDR    r0, [r1], #4
 TST    r0, #&20000000
 BEQ    %BT01
 DLINE  ""
 Pull   "r0,r1"
 ]

        ; Construct scatter list of all non-bad sectors on this track
        ADRL    r0, ScatterList
        LDR     r3, FormatParamBlk + FormatSectorSize
        LDRB    r1, FormatParamBlk + FormatSectorsPerTrk
        MOV     r5, r2          ; sector address
        LDR     r7, =&20000000-1 ; end marker value
        LDR     r8, TrackDefects; Bad sector list rover
        MOV     r6, #0          ; Number of bytes to verify

45
        LDR     lr, [r8]
        CMP     lr, r7          ; Check for list end
        CMPLO   lr, r5
        ADDLO   r8, r8, #4      ; Good bad block is LT this block
        BLO     %BT45           ; So go onto next bad block

        STRNE   r5, [r0], #4    ; sector address for use during verify phase
        ADDNE   r6, r6, #1
        ADD     r5, r5, r3
        SUBS    r1, r1, #1
        BNE     %BT45           ; Loop if more sectors on this track

        ; Format this track
        ADRL    r5, FormatDiscRecord
        MOV     r1, #DiscOp_WriteTrk
        MOV     r3, #0
        LDRB    lr, FormatDrive
 [ UseDiscOp64
        Push    "r2,r3"
        Push    "lr"
        MOV     r2, sp
 [ Debug30
 DREG   r1,"XADFS_DiscOp64(",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DREG   r5,",",cc
 DLINE  ")"
 ]
        SWI     XADFS_DiscOp64
        LDR     lr, [sp, #0]
        LDR     r2, [sp, #4]
        ORR     r2, r2, lr, ASL #(32-3)
        ADD     sp, sp, #12
 |
        ORR     r2, r2, lr, ASL #(32-3)
        ORR     r1, r1, r5, ASL #6
 [ Debug30
 DREG   r1,"XADFS_DiscOp(",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DLINE  ")"
 ]
        SWI     XADFS_DiscOp
 ]
        BVS     %FT98

        ; r11 - Defect pool end pointer
        ; r10 - track counter
        ; r9 = (sector) scatter list rover
        ; r8 = previous bad sector on this track - used for retry counting
        ; r7 = retry count
        ; r6 = number of non-bad sectors which need verifying
        ADRL    r9, ScatterList

        MOV     r8, #-1

50
        ; No more sectors to verify?
 [ Debug30
 DREG   r6, "Sectors left to verify "
 ]
        CMP     r6, #0
        BLS     %FT70

        ; Construct the next contiguous section of verify to do
        LDR     r2, [r9], #4
        MOV     r4, r2
        LDR     r3, FormatParamBlk + FormatSectorSize

55
        ADD     r4, r4, r3

        ; If not more sectors done with the accumulation
        SUBS    r6, r6, #1
        BLS     %FT57

        ; Check for another sector accumulating
        LDR     lr, [r9]
        TEQ     r4, lr
        ADDEQ   r9, r9, #4
        BEQ     %BT55

57
        ; Convert end address to length
        SUB     r4, r4, r2

60
        ; Verify this part of this track
        ADRL    r5, FormatDiscRecord
        MOV     r1, #DiscOp_Verify
        LDRB    lr, FormatDrive
 [ UseDiscOp64
        STR     lr, [sp, #-12]!
        STR     r2, [sp, #4]
        MOV     r2, #0
        STR     r2, [sp, #8]
        MOV     r2, sp
 [ Debug30
 DREG   r1,"XADFS_DiscOp64(",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DREG   r5,",",cc
 DLINE  ")"
 ]
        SWI     XADFS_DiscOp64
        LDR     lr, [sp, #0]
        LDR     r2, [sp, #4]
        ORR     r2, r2, lr, ASL #(32-3)
        ADD     sp, sp, #12
 |
        ORR     r2, r2, lr, ASL #(32-3) ; Start disc address
        ORR     r1, r1, r5, ASL #6
 [ Debug30
 DREG   r1,"XADFS_DiscOp(",cc
 DREG   r2,",",cc
 DREG   r3,",",cc
 DREG   r4,",",cc
 DLINE  ")"
 ]
        SWI     XADFS_DiscOp
 ]
 [ Debug30
 DREG   r1, "....->(",cc
 DREG   r2, ",",cc
 DREG   r3, ",",cc
 DREG   r4, ",",cc
 DLINE  ")"
 ]

        BVC     %BT50                   ; Move to next sector for verifying

        ; Error during verify
        LDRB    lr, [r0]
        TEQ     lr, #DiscErr
        BNE     %FT98

        ; Disc error during verify - map out as a bad block
        TEQ     r2, r8
        MOV     r8, r2

        ; If stopped on a different sector, reset the retry countdown
        LDRNEB  r7, FloppyDefectRetries

        ; Check if we've run out of retries and give it another go if more
        ; retries left
        SUBS    r7, r7, #1
        BHS     %BT60

        ; Inform the user of the defect

        ; NewLine if first defect after Formatting... message
        LDRB    lr, FirstDefectOnTrack
        TEQ     lr, #0
        SWINE   XOS_NewLine
        BVS     %FT95
        MOV     lr, #0
        STRB    lr, FirstDefectOnTrack

        Push    "r4"
        ADD     r4, r0, #4
        baddr   r0, MapOutDefect
        BL      message_gswrite01
        Pull    "r4"
        BVS     %FT95

        ; Add the defect to the defect list before the current
        ; high water mark defect
        ADD     r11, r11, #4            ; One more defect

        ; Check we've not had too many defects
        ADRL    lr, DefectPool + ?DefectPool
        CMP     r11, lr
        baddr   r0, TooManyDefects2ErrBlk, HS
        SETV    HS
        BVS     %FT90

        MOV     r0, r11
        BIC     r2, r2, #DiscBits
        ADRL    r3, DefectPool-4        ; -4 to get end to happen with r0 before the list start
65
        LDR     lr, [r0, #-4]!          ; shuffle up the defects above it
        CMP     lr, r2
 [ Debug30
 Push   "r1"
 MOV    r1, lr
 DREG   r1, "Shuffling up ",cc
 DREG   r0, " from location "
 Pull   "r1"
 ]
        STRHI   lr, [r0, #4]            ; Move this up if its higher than the new defect
        CMPHI   r0, r3                  ; Check for before start of list
        BHI     %BT65
        STR     r2, [r0, #4]            ; store our defect

 [ Debug30
 Push   "r0,r1"
 DLINE  "Defect pool:",cc
 ADRL   r1, DefectPool+8
 B %FT02
01
 DREG   r0," ",cc
02
 LDR    r0, [r1], #4
 TST    r0, #&20000000
 BEQ    %BT01
 DLINE  ""
 Pull   "r0,r1"
 ]

        ; Skip this sector, it's now a defect
        LDR     lr, FormatParamBlk + FormatSectorSize
        ADD     r2, r2, lr
        SUBS    r4, r4, lr

        ; Continue verifying this track to the next defect
        BNE     %BT60           ; More of this section of verifying to do - non-zero bytes left
        B       %BT50           ; Move to next section to verify - zero bytes left

 [ Debug30
        LTORG
 ]

70
        ; Verified all sectors on this track

        ; If more defects found reformat this track
        LDR     lr, OldDefectEnd
        TEQ     lr, r11
        BNE     %BT40

        ; Finished formatting that track - move onto the next track

        ADD     r10, r10, #1
        LDR     lr, FormatParamBlk + FormatTracksToFormat
        CMP     r10, lr
        BLO     %BT35

        ; Physical format now layed out with defect list constructed


        ; Newline to indicate finished formatting track sequence and to tidy up the display
        LDRB    lr, FirstDefectOnTrack
        TEQ     lr, #0
        SWINE   XOS_NewLine
        BVS     %FT95

        ; Open the disc as an image to layout a structure
        SUB     sp, sp, #?ImageNameTplt + 3 :AND: :NOT: 3
        MOV     r0, sp
        baddr   r1, ImageNameTplt
80
        LDRB    lr, [r1], #1
        STRB    lr, [r0], #1
        TEQ     lr, #0
        BNE     %BT80

        LDRB    r1, FormatDrive + (?ImageNameTplt + 3 :AND: :NOT: 3)
        ORR     r1, r1, #"0"
        STRB    r1, [r0, #-2]           ; -1 is \0-terminator, -2 is the 0 of adfs::0

        MOV     r0, #open_update :OR: open_mustopen :OR: open_nodir :OR: open_nopath
        MOV     r1, sp
 [ Debug30
 DREG   r0, "XOS_Find(",cc
 DSTRING r1, ",",cc
 DREG   r2,",",cc
 DLINE  ")"
 ]
        SWI     XOS_Find
        ADD     sp, sp, #?ImageNameTplt + 3 :AND: :NOT: 3
        BVS     %FT95

        ; Slap a layout down into that image
        MOV     r3, r0
        LDR     r0, LayoutParam
        ADRL    r1, DefectPool
        LDR     r2, FormatDiscName
        LDR     r11, LayoutSWI
 [ Debug30
 DREG   r11, "CallASWI:",cc
 DREG   r0, "(",cc
 DREG   r1, ",",cc
 DREG   r2, ",",cc
 DREG   r3, ",",cc
 DLINE  ")"
 ]
 [ {TRUE}
        BL      CallASWI
 ]
 [ Debug30
 BVC    %FT01
 ADD r0,r0,#4
 DSTRING r0,"Error:"
01
 ]
        MOVVC   r4, #0
        BLVS    FormatCopyError
        MOVVS   r4, r0

        ; Close the file
        MOV     r0, #0
        MOV     r1, r3
 [ Debug30
 DREG   r0, "XOS_Find(",cc
 DREG   r1, ",",cc
 DLINE  ")"
 ]
        SWI     XOS_Find
        BLVS    FormatCopyError
        BVS     %FT95

        MOVS    r0, r4
        SETV    NE
        BVS     %FT95

        ; Hey presto! One disc formatted.

90
        BLVS    copy_error
        BLVS    FormatCopyError
95
 [ Debug30
        DLINE   "Tidy up at end of format...Dismount"
 ]
        Push    "r0"

        LDRB    r0, FormatDrive + 1*4
        BL      DismountDiscByNumber

        Pull    "r0"

        BVC     %FT96

        ; Generate a RAM error block
        baddr   r0, BadFormatErrBlk
        BL      copy_error

        ; Copy the error we want into it
        MOV     r2, r0
        ADR     r1, CopyErrorBlock
        LDR     lr, [r1], #4
        STR     lr, [r2], #4
 [ Debug30
        DSTRING r1, "Copy error block string is "
 ]
92
        LDRB    lr, [r1], #1
        STRB    lr, [r2], #1
        TEQ     lr, #0
        BNE     %BT92

 [ Debug30
        DLINE   "Tidy up at end of format...translate escape"
        ADD     r0, r0, #4
        DSTRING r0,"Error text:"
        SUB     r0, r0, #4
 ]
        ; Translate Escape errors to Escape: disc going to be duff type error
        LDRB    lr, [r0]
        TEQ     lr, #ExtEscapeErr
        baddr   r0, FormatEscErrBlk, EQ
        BLEQ    copy_error
        SETV

96
 [ Debug30
        DLINE   "Tidy up at end of format...quit"
 ]
        ; Error (or confirm answer=No)
        ADD     sp, sp, #SzFormatVars
        STRVS   r0, [sp]

        Pull    "r0-r11, pc"

97
 [ Debug30
        DLINE   "Tidy up at end of format...error exit without dismount"
 ]
        ; Internally generated error exit without dismount
        BL      copy_error
        SETV
        B       %BT96

98
 [ Debug30
        DLINE   "Tidy up at end of format...error exit"
        ADD     r0, r0, #4
        DSTRING r0,"Error text:"
        SUB     r0, r0, #4
 ]
        BL      FormatCopyError

        ; Error from DiscOps - NewLine if first error on track to tidy up display
        LDRB    lr, FirstDefectOnTrack
        TEQ     lr, #0
        SWINE   XOS_NewLine
        SETV
        B       %BT95

FormatCopyError ROUT
        Push    "r1-r3,lr"
        SavePSR r3

        ; Don't overwrite errors we don't want to
        LDRB    lr, GottenError+4*4
        TEQ     lr, #0
        BNE     %FT99

        MOV     lr, #&ff
        STRB    lr, GottenError+4*4

        ADR     r1, CopyErrorBlock+4*4
        LDR     r2, [r0], #4
        STR     r2, [r1], #4
10
        LDRB    r2, [r0], #1
        STRB    r2, [r1], #1
        TEQ     r2, #0
        BNE     %BT10

99
        RestPSR r3,,f
        Pull    "r1-r3,pc"

        LTORG

; ===========
; IsStringYes
; ===========

; entry: r1 -> string

; exit: EQ if string is 'Y' or 'y'

IsStringYes ROUT
        Push    "lr"
        LDRB    lr, [r1, #1]
        TEQ     lr, #0
        Pull    "pc",NE
        LDRB    lr, [r1, #0]
        TEQ     lr, #"y"
        TEQNE   lr, #"Y"
        Pull    "pc"

; ====================
; DismountDiscByNumber
; ====================

; entry: r0 = disc number

; exit: ADFS:Dismount :<n> command executed, all regs and flags preserved

DismountStr DCB "ADFS:Dismount :0", 0
        ALIGN

DismountDiscByNumber ROUT
        Push    "r0-r3,lr"
        SavePSR r3
        SUB     sp, sp, #?DismountStr + 3 :AND: :NOT: 3

        ; Copy dismount command to stack frame
        MOV     r1, sp
        ADR     r2, DismountStr
10
        LDRB    lr, [r2], #1
        STRB    lr, [r1], #1
        TEQ     lr, #0
        BNE     %BT10

        ; Fill in required disc number
        ADD     r0, r0, #"0"
        STRB    r0, [r1, #-2]   ; -1 is \0-terminator, -2 is 0 of :0

        ; Execute the command
        MOV     r0, sp
 [ Debug30
 DSTRING r0, "Dismount command:"
 ]
        SWI     XOS_CLI

        ADD     sp, sp, #?DismountStr + 3 :AND: :NOT: 3
        RestPSR r3,,f
        Pull    "r0-r3, pc"

; ========
; CallASWI
; ========

; entry: r11 = SWI number
;       other regs parameters to SWI

; exit:  As per SWI

CallASWI ROUT
  [ StrongARM
    ;use OS_CallASWI - avoids need for dynamic code

        Push    "r10,lr"
        MOV     r10,r11      ; OS_CallASWI uses r10 for SWI number
        SWI     XOS_CallASWI
        Pull    "r10,pc"

  |

        Push    "r0,r1,r11,lr"
 [ Debug30
 DREG   r11,"SWI ",cc
 DREG   r0, "(",cc
 DREG   r1, ",",cc
 DREG   r2, ",",cc
 DREG   r3, ",",cc
 DLINE  ")"
 ]
        ; Construct
        ; SWI <the swi>
        ; MOV pc, r11
        ; on the stack
        SUB     sp, sp, #2*4
        ADR     r0, SwiTemplate
        LDMIA   r0, {r0,r1}
        ORR     r0, r0, r11
        STMIA   sp, {r0,r1}

        ; restore r0 and r1
        ADD     r11, sp, #2*4
        LDMIA   r11, {r0,r1}

        ; Call the code of the stack (standard BL sp, but lr is r11 in this case)
        MOV     r11, pc
        MOV     pc, sp

        ; Drop the instructions on the stack, and r0, r1 in
        ADD     sp, sp, #2*4 + 2*4

 [ Debug30
 DLINE  "...SWI returns"
 ]

        Pull    "r11,pc"

SwiTemplate
        SWI     Auto_Error_SWI_bit
        MOV     pc, r11

 ] ; StrongARM / not StrongARM


; =======================
; ConstructDoFormatRecord
; =======================

; entry r0 = pointer to MultiFS format spec block
;       r1 = track number within format: 0..n for all options (side 1 only included)
;       r2 = pointer to disc record
;       r4 = pointer to DoFormat structure to fill in

; exit: records filled in.

ConstructDoFormatRecord ROUT
        Push    "r0,r2-r5,lr"

        LDR     r3, [r0, #FormatSectorSize]
        STR     r3, [r4, #DoFormatSectorSize]
        LDR     r3, [r0, #FormatGap3]
        STR     r3, [r4, #DoFormatGap3]
        LDRB    r3, [r0, #FormatSectorsPerTrk]
        STRB    r3, [r4, #DoFormatSectorsPerTrk]
        LDRB    r3, [r0, #FormatDensity]
        STRB    r3, [r4, #DoFormatDensity]
        LDRB    r3, [r0, #FormatOptions]
        STRB    r3, [r4, #DoFormatOptions]
        LDRB    r3, [r0, #FormatFillValue]
        STRB    r3, [r4, #DoFormatFillValue]
        LDR     r3, [r0, #FormatTracksToFormat]
        LDRB    r5, [r0, #FormatOptions]
        AND     r5, r5, #FormatOptSidesMask
        TEQ     r5, #FormatOptInterleaveSides
        TEQNE   r5, #FormatOptSequenceSides
        MOVEQ   r3, r3, LSR #1
        STR     r3, [r4, #DoFormatCylindersPerDrive]
        MOV     r3, #0
        STR     r3, [r4, #DoFormatReserved0]
        STR     r3, [r4, #DoFormatReserved1]
        STR     r3, [r4, #DoFormatReserved2]

        ; Log2 the sector size
        LDR     r3, [r0, #FormatSectorSize]
        MOV     lr, #0
10
        MOVS    r3, r3, LSR #1
        ADDNE   lr, lr, #1
        BNE     %BT10
        STRB    lr, [r2, #SectorSize]

        LDRB    r3, [r0, #FormatSectorsPerTrk]
        STRB    r3, [r2, #SecsPerTrk]

        ; Heads is 2 for interleave sides variety only
        TEQ     r5, #FormatOptInterleaveSides
        MOVEQ   r3, #2
        MOVNE   r3, #1
        STRB    r3, [r2, #Heads]

        LDRB    r3, [r0, #FormatDensity]
        STRB    r3, [r2, #Density]

        ASSERT  LinkBits:MOD:4 = 0
        ASSERT  BitSize = LinkBits+1
        ASSERT  RAskew = BitSize+1
        ASSERT  BootOpt = RAskew+1
        MOV     r3, #0
        STR     r3, [r2, #LinkBits]

        ; EQ still set for interleave sides
        LDRB    r3, [r0, #FormatLowSector]
        ORRNE   r3, r3, #bit6
        LDRB    lr, [r0, #FormatOptions]
        TST     lr, #FormatOptDoubleStep
        ORRNE   r3, r3, #bit7
        STRB    r3, [r2, #LowSector]

        MOV     r3, #0
        STR     r3, [r2, #RootDir]

        ; Calculate amount being formatted
        LDRB    r3, [r2, #SecsPerTrk]
        LDRB    lr, [r2, #SectorSize]
        MOV     r3, r3, ASL lr
        LDR     lr, [r0, #FormatTracksToFormat]
        MUL     r3, lr, r3

        ; If Side0 or Side1 only then double to get the disc size
        TEQ     r5, #FormatOptSide0Only
        TEQNE   r5, #FormatOptSide1Only
        ADDEQ   r3, r3, r3

        STR     r3, [r2, #DiscSize]

        MOV     r3, #0
 [ BigDisc
        STR     r3, [r2, #DiscSize2]
 ]
        STR     r3, [r2, #DiscId]
        STR     r3, [r2, #DiscId + 4]
        STR     r3, [r2, #DiscId + 4]

        Pull    "r0,r2-r5,pc"

; =======================
; ConstructDoFormatIdList
; =======================

; entry r0 = pointer to MultiFS format spec block
;       r1 = track number within format: 0..n for all options (side 1 only included)
;       r4 = pointer to DoFormat structure to fill in

; exit: buffer filled in.
;       r2 = disc address of start of track

ConstructDoFormatIdList ROUT
        Push    "r0-r1,r3-r7,lr"

        ; Get the format sides option
        LDRB    r5, [r0, #FormatOptions]
        AND     r5, r5, #FormatOptSidesMask

        ; Construct cylinder MOD 256
        LDR     lr, [r0, #FormatTracksToFormat]
        TEQ     r5, #FormatOptInterleaveSides
        MOVEQ   r3, r1, LSR #1
        TEQ     r5, #FormatOptSide0Only
        TEQNE   r5, #FormatOptSide1Only
        MOVEQ   r3, r1
        TEQ     r5, #FormatOptSequenceSides
        BNE     %FT10
        CMP     r1, lr, LSR #1
        MOVLO   r3, r1
        SUBHS   r3, r1, lr, LSR #1
10
        AND     r3, r3, #&ff

        ; Construct head
        TEQ     r5, #FormatOptInterleaveSides
        ANDEQ   lr, r1, #1
        ORREQ   r3, r3, lr, ASL #8
;       TEQ     r5, #FormatSide0Only
;       <do nothing - side = 0>
        TEQ     r5, #FormatOptSide1Only
        ORREQ   r3, r3, #1 :SHL: 8
        TEQ     r5, #FormatOptSequenceSides
        BNE     %FT20
        CMP     r1, lr, LSR #1
        ORRHS   r3, r3, #1 :SHL: 8
20

        ; Construct sector size
        LDR     lr, [r0, #FormatSectorSize]
        MOV     lr, lr, LSR #7
30
        MOVS    lr, lr, LSR #1
        ADDNE   r3, r3, #1 :SHL: 24
        BNE     %BT30

        ; Having constructed this:
        ; ss00hhcc
        ; in r3, store SectorsPerTrk lots of r3 in the sector ID buffer
        ADD     r2, r4, #DoFormatSectorList

        LDRB    lr, [r0, #FormatSectorsPerTrk]
        B       %FT45
40
        STR     r3, [r2, lr, ASL #2]
45
        SUBS    lr, lr, #1
        BPL     %BT40

        ; Having r3 = ss00hhcc, extract the hh value to decide which gap we should use
        TST     r3, #&ff00
        LDREQ   lr, [r0, #FormatGap1Side0]
        LDRNE   lr, [r0, #FormatGap1Side1]
 [ Debug31
        MOV r7, lr
        DREG r7, "gap1 = "
 ]
        STR     lr, [r4, #DoFormatGap1]

        ; Now we've got to fill in the sector numbers

        ; Offset to the first sector on the track is combination of side and track skew
        LDRB    r7, [r2, #0]    ; cylinder
        LDRB    r6, [r0, #FormatTrackTrackSkew]
 [ Debug31
        DREG    r6, "skew=",cc
        DREG    r7, " C=",cc
 ]
        ; Sign extend the skew
        MOV     r6, r6, ASL #24
        MOV     r6, r6, ASR #24
        MUL     r7, r6, r7              ; Skew for tracks
 [ Debug31
        DREG    r7, " TS=",cc
 ]

        ; Add track track skew if on head 1 on an interleaved sided disc
        TEQ     r5, #FormatOptInterleaveSides
        LDREQB  lr, [r2, #1]    ; head
        TEQEQ   lr, #1
        LDREQB  lr, [r0, #FormatSideSideSkew]
        ; Sign extend the skew
        MOVEQ   lr, lr, ASL #24
        MOVEQ   lr, lr, ASR #24
        ADDEQ   r7, r7, lr

        ; Bring start sector offset positive
        LDRB    r5, [r0, #FormatSectorsPerTrk]
        TEQ     r7, #0
50
        ADDMIS  r7, r7, r5
        BMI     %BT50

        ; Convert r2 to pointer to first sector number
        ADD     r2, r2, #2

        ; Lay out sectors starting at sector number 1
        LDRB    r5, [r0, #FormatSectorsPerTrk]
        MOV     r6, #1
 [ Debug31
        DREG    r7, " TSa="
 ]
        B       %FT60

55
        ; Bring the offset back into range
        CMP     r7, r5
        SUBHS   r7, r7, r5
        BHS     %BT55

        ; Check this sector slot hasn't been used yet
        LDRB    lr, [r2, r7, ASL #2]
        TEQ     lr, #0
        ADDNE   r7, r7, #1
        BNE     %BT55

        ; Use this sector slot
        STRB    r6, [r2, r7, ASL #2]
        ADD     r6, r6, #1              ; Move to next sector number

        LDRB    lr, [r0, #FormatInterleave]
        ADD     r7, r7, lr
        ADD     r7, r7, #1

60
        CMP     r6, r5
        BLS     %BT55

        ; Now convert the sector numbers for the lowsector value
        B       %FT70
65
        LDRB    r6, [r2, r5, ASL #2]
        LDRB    lr, [r0, #FormatLowSector]
        ADD     r6, r6, lr
        SUB     r6, r6, #1
        STRB    r6, [r2, r5, ASL #2]
70
        SUBS    r5, r5, #1
        BPL     %BT65

 [ Debug31
        Push    "r0,r2,r5,r6"
        BIC     r2, r2, #3
        LDRB    r5, [r0, #FormatSectorsPerTrk]
        MOV     r6, #0
01
        LDR     r0, [r2, r6, ASL #2]
        DREG    r0,",",cc
        ADD     r6, r6, #1
        CMP     r6, r5
        BLO     %BT01
        DLINE   ""
        Pull    "r0,r2,r5,r6"
 ]

        ; Construct disc address of track in r2
        LDR     lr, [r0, #FormatSectorSize]
        LDRB    r2, [r0, #FormatSectorsPerTrk]
        MUL     r2, lr, r2              ; Bytes per track
        LDR     lr, [r0, #FormatTracksToFormat]
        LDRB    r5, [r0, #FormatOptions]
        AND     r5, r5, #3 :SHL: 2
        TEQ     r5, #FormatOptSide1Only
        ADDEQ   r1, r1, lr              ; Track as understood by DiscOp
        MUL     r2, r1, r2              ; Byte offset of start of track

        Pull    "r0-r1,r3-r7,pc"

        END
