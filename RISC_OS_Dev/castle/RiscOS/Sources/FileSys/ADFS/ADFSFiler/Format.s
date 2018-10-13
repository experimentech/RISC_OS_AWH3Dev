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
; > s.Format
;
; Handle interactive format /verify.
;
;


        MACRO
$lab    bit     $bitnum
$lab    *       1 :SHL: ($bitnum)
        MEND


        MACRO
$lab    aw      $size           ;allocate word aligned
        ASSERT  {VAR} :MOD: 4=0
$lab    #       $size
        MEND

bit6    bit 6
bit7    bit 7

                ^       0
SectorSize      # 1
SecsPerTrk      # 1
Heads           # 1     ;1 for old adfs floppy format
Density         # 1     ;1/2/4 single double quad

;only those above needed for low level drivers

LinkBits        # 1
BitSize         # 1     ;log2 bytes for each bit in map, 0 for old format
RAskew          # 1     ;track to track sector skew for random access
BootOpt         # 1     ;boot option for this disc
LowSector       # 1     ;b0-5= lowest sector ID, b6= sequence sides, b7= double step
Zones           # 1     ;# zones in map
ZoneSpare       # 2     ;# bits in zones after 0 which are not map bits
        ASSERT  (ZoneSpare :MOD: 4)=2
RootDir         aw 4
DiscSize        aw 4

DiscStruc       # 0     ;above entries (except BootOpt) define disc structure

DiscId          aw 2
DiscName        # 10
DiscType        aw 4
DiscSizeHi      aw 4    ;bytes 36-40
DiscRecSig      # 0     ;above entries form signature of disc

DiscFlags       # 1
FloppyFlag      bit 0
NeedNewIdFlag   bit 1
AltMapFlag      bit 5
OldMapFlag      bit 6
OldDirFlag      bit 7   ;set <=> old small dirs


;entries below must be valid even when disc rec is not in use
Priority        # 1     ;0 DISC REC UNUSED
                        ;1 to # floppies -> floppy priority level
                        ;&FF good winnie
DiscsDrv        # 1     ;0-7 => drive in, 8 => not in drive, OR DISC REC UNUSED
DiscUsage       # 1     ;tasks using this disc, if >0 disc cant be forgotten
SzDiscRec       # 0

;default last word of disc record
;DiscFlags      0  FLOPPIES NEED NeedNewIdFlag SET INITIALLY
;Priority       0
;DiscsDrv       8
;DiscUsage      0
DefDiscRecEnd   * &00080000



FormatState_Ready       *       0
FormatState_Format      *       1
FormatState_Formatting  *       2
FormatState_VerifyReady *       3
FormatState_Verify      *       4
FormatState_Verifying   *       5
FormatState_Paused      *       6
FormatState_Resume      *       7
FormatState_OK          *       8
FormatState_SetPause    *       9

NextStateTable
        DCD     1       ; Ready       -> Format
        DCD     6       ; Format      -> Paused
        DCD     6       ; Formatting  -> Paused
        DCD     4       ; VerifyReady -> Verify
        DCD     6       ; Verify      -> Paused
        DCD     6       ; Verifying   -> Paused
        DCD     7       ; Paused      -> Resume
        DCD     0       ; This case cannot happen as state is restored to the saved state.
        DCD     0       ; This should never happen as the window gets closed.


StateButtonTextTable
        DCD     BFToken - StateButtonTextTable  ; Ready       ==  "Format"
        DCD     BPToken - StateButtonTextTable  ; Format      ==  "Pause"
        DCD     BPToken - StateButtonTextTable  ; Formatting  ==  "Pause"
        DCD     BVToken - StateButtonTextTable  ; VerifyReady ==  "Verify"
        DCD     BPToken - StateButtonTextTable  ; Verify      ==  "Pause"
        DCD     BPToken - StateButtonTextTable  ; Verifying   ==  "Pause"
        DCD     BRToken - StateButtonTextTable  ; Paused      ==  "Resume"
        DCD     0       ; This case cannot happen as state is restored to the saved state.


FormatDriveToken        DCB     "Drv",0
FormatNameMessage       DCB     "DefName",0
ReadyMessage            DCB     0,"FormRdy",0
InsertDisc              DCB     1,"InsDisc",0
DLNoRoomMessage         DCB     1,"DLSpace",0
FormattingMessage       DCB     0,"Forming",0
VerifyMessage           DCB     0,"Vering",0
DefectToken             DCB     1,"Defect",0
VerifyReadyMessage      DCB     0,"VReady",0
VerifyCompleteMessage   DCB     0,"VOK",0
FormatCompleteMessage   DCB     0,"FOK",0
VerifyCompleteDefectsMessage   DCB     1,"VENDD",0
VerifyCompleteDefectsSingle    DCB     1,"VENDS",0
FormatCompleteDefectsMessage   DCB     1,"FENDD",0
FormatCompleteDefectsSingle    DCB     1,"FENDS",0
FormatFailMessage       DCB     1,"FmtFail",0
BPToken                 DCB     "BP",0
BFToken                 DCB     "BF",0
BRToken                 DCB     "BR",0
TFToken                 DCB     "TF",0
TVToken                 DCB     "TV",0
BVToken                 DCB     "BV",0
BOKToken                DCB     "BOK",0
                        ALIGN
ADFSPrefix              DCB     "$FSTitle::0",0             ; Picked up as 2 words
DismountCommand         DCB     "$FSTitle:DISMOUNT :n",0    ; Picked up as  5 words.
                        ALIGN

        ^       0                       ; Block format for format /verify windows
fw_next         #       4               ; Next block in list
fw_prev         #       4               ; Previous block in list
fw_handle       #       4               ; Window handle
fw_format       #       4               ; Number of format in format list
                                        ; If Version >= 40
                                        ; This is a pointer to the format description block.
fw_drive        #       4               ; Drive number
fw_state        #       4               ; Current state of format / verify
fw_savedstate   #       4               ; Saved state when paused.
fw_firststate   #       4               ; First state of this window, used to tell verify windows
                                        ; apart from format windows.
fw_discname     #       4               ; Pointer to disc name in fw_indirectdata
fw_defects      #       4               ; Number of defects found during verify.
fw_currenttrack #       4               ; Next track to be formatted
fw_currenttrack_high #  4               ; high word of next track (verify only)
fw_numberoftracks #     4               ; Last track to be formatted + 1
fw_numberoftracks_high # 4              ; high word of last track (verify only)
fw_bytespersector #     4
fw_bytespertrack  #     4
fw_currentdefect  #     4
fw_currentaddress #     4
fw_bytestoverify  #     4
fw_MaxFormatBarLength # 4

; OSS fw_formatspec to fw_defectlist (inclusive) is used as the buffer
; for the window data so don't move things around too much. This amount
; memory (520+256+64+64 = 904) is so far above the size needed (384 in
; the english version) that no checking is performed.
fw_windowbuffer #       0
fw_formatspec   #       64              ; Format specification block
fw_discrecord   #       64              ; Disc record.
fw_formatrecord #       256             ; Format specification block
;was 520 - now 516 to cater for adding terminator in maximum case
fw_defectlist   #       520             ; Defect list for this window
fw_windowbuffer_size    *       @-fw_windowbuffer

; OSS Indirect data for window comes here, added to the total size.
fw_indirectdata #       0               ; Indirected data for window
        ASSERT  fw_next=0
fw_block_size   *       @-fw_next

;---------------------------------------------------------------------

; OSS Common function used at the start of Format and Verify to allocate
; memory, read in the template, create the window and link it into
; the chain of windows.

; Entry:        nothing
; Exit:         r0 corrupted
;               r1-r7 preserved
;               r8 -> data block
; Error:        V set, r0 -> error block

format_verify_get_memory Entry "r1-r7"  ; Do not stack r0 or r8
      [ SDFS
        ADRL    r1, str_templatefile_sdfs
        SWI     XWimp_OpenTemplate
      |
      [ SCSI
        ; ADFSFiler may not be present on all systems - so check for a copy of the templates in SCSIFiler's resources before falling back on the ADFSFiler copy that's traditionally used
        ADRL    r1, str_templatefile_scsi
        SWI     XWimp_OpenTemplate
        ADRVSL  r1, str_templatefile
        SWIVS   XWimp_OpenTemplate
      |
        ADRL    r1, str_templatefile
        SWI     XWimp_OpenTemplate
      ]
      ]
        EXIT    VS

        MOV     r1, #-1
        MOV     r4, #-1
        ADRL    r5, w_format
        MOV     r6, #0
        BL      load_template           ; Get size required for template.
        BVS     format_verify_get_memory_error_close

        MOV     r0,#ModHandReason_Claim
        ADD     r3, r2, #fw_block_size  ; Add indirected data size.
        SWI     XOS_Module              ; Claim space for data.
        BVS     format_verify_get_memory_error_close
        MOV     r8, r2                  ; Data block in r8.

        LDRB    r4, driveno+1
        SUB     r4, r4, #"0"
        STR     r4, [r8, #fw_drive]     ; Store drive number.

        LDR     r0, FormatWindows       ; Link new block to list of windows.
        STR     r8, FormatWindows
        STR     r0, [r8, #fw_next]
        TEQ     r0, #0
        STRNE   r8, [r0, #fw_prev]
        MOV     r1, #0
        STR     r1, [r8, #fw_prev]

        STR     r1, [r8, #fw_defectlist]        ; Zero out defects.
        STR     r1, [r8, #fw_defects]
        STR     r1, [r8, #fw_handle]            ; Zero out window handle.

        ADD     r1, r8, #fw_windowbuffer
        ADD     r2, r8, #fw_indirectdata
        ADD     r3, r8, r3                      ; Indirect limit = pointer + size
        MOV     r4, #-1
        ADRL    r5, w_format
        MOV     r6, #0
        BL      load_template
        BVS     format_verify_get_memory_error_free_close

; Get max size of bar, and mark bar as deleted.

        ADD     r1, r1, #w_icons + (3*i_size)   ; Third icon is bar.
        LDR     r0, [r1, #i_bbx0]               ; Icon's x0
        LDR     r2, [r1, #i_bbx1]               ; Icon's x1
        SUB     r2, r2, r0
        SUB     r2, r2, #8                      ; for border
        STR     r2, [r8, #fw_MaxFormatBarLength]
       [ debug
        dreg    r2,"Max format bar length is "
       ]

        SWI     XWimp_CloseTemplate
        ADDVC   r1, r8, #fw_windowbuffer
        SWIVC   XWimp_CreateWindow
        BVS     format_verify_get_memory_error_free
        STR     r0, [r8, #fw_handle]
        EXIT


; OSS Error handling routines.

format_verify_get_memory_error_free_close
        MOV     r6, r0
        SWI     XWimp_CloseTemplate
        MOV     r0, r6
        SETV
; ** Drop through **

format_verify_get_memory_error_free
        PullEnv                                 ; Unstacks Entry stuff.
        Push    "lr"                            ; Get lr back on stack.
        MOV     r2, r8                          ; Get data block into r2.
        B       format_verify_error_delete_window ; Assumes a stacked lr.

format_verify_get_memory_error_close
        MOV     r6, r0
        SWI     XWimp_CloseTemplate
        MOV     r0, r6
        SETV
        EXIT

;---------------------------------------------------------------------


; SetBar
; Entry:
;       r0 = Window handle
;       r1 = New length of bar
;       r2 = New colour of bar
SetBar ROUT
        Push    "r0-r4,LR"

      [ debugfo
        dreg    r1,"set bar"
      ]

        ADR     r1,userdata
        STR     r0,[r1]
        MOV     r0,#4
        STR     r0,[r1,#4]
        SWI     XWimp_GetIconState
        SWIVC   XWimp_DeleteIcon        ; Delete bar icon.
        BVS     %FT01

        LDR     r14,[sp,#2*4]           ; Get colour on entry
        MOV     r14,r14,LSL #4
        STRB    r14,[r1,#19+8]          ; Icon's background colour

        LDR     r14,[sp,#1*4]           ; R14=length
        LDR     r3,[r1,#8]              ; Get x0 of icon
        ADD     r3,r3,r14               ; r3 = new x1 of icon
        LDR     r4,[r1,#16]             ; r4 = old x1 of icon
        STR     r3,[r1,#16]             ; Store new icon X1
        LDR     r2,[r1,#16+8]           ; Get icon flags.
        BIC     r2,r2,#is_deleted       ; make sure it isn't deleted.
        STR     r2,[r1,#16+8]           ; store flags back.
        LDR     r2,[r1]
        STR     r2,[r1,#4]!             ; Store window handle, and increment r1
        SWI     XWimp_CreateIcon        ; Create the new icon
        BVS     %FT01

        CMP     r3,r4                   ; Is new length longer?
        Pull    "r0-r4,PC",EQ           ; They are equal !
        MOVLT   r1,r3
        MOVGE   r1,r4
        MOVLT   r3,r4
        LDR     r0,[sp,#0*4]            ; r0 = Window handle.
        ADRL    r14,userdata+4
        LDR     r2,[r14,#4+4]            ; r2 = y0
        LDR     r4,[r14,#12+4]           ; r4 = y1
        SWI     XWimp_ForceRedraw
01
        STRVS   r0,[sp]
        Pull    "r0-r4,PC"

;-------------------------------------------------------------------
;Report
;Entry: r0 -> Message token for message to be reported.
;             First byte of message is a flag:      0 = Normal text.
;                                               Non 0 = Inverted text
;       r1 -> argument (if any)
;       r2 =  Window handle
; Exit:
;       Message reported in icon.
;       [userdata] corrupted.
;
Report  ROUT
        Push    "r0-r3,LR"

      [ debug
        DREG    r14,"REPORT r14="
      ]

        ADR     r1,userdata
        STR     r2,[r1]                 ; Store window handle
        MOV     r0,#5                   ; Get state of message icon
        STR     r0,[r1,#4]
        SWI     XWimp_GetIconState
        BVS     %FT01

        ADR     r1,userdata
        LDR     r2,[r1,#36]             ; Buffer length of icon
        LDR     r1,[r1,#28]             ; Buffer pointer
       [ debug
        dreg    r2,"Buffer length "
        dreg    r1,"Buffer address "
       ]
        LDR     r0,[SP]                 ; Get message token.
        ADD     r0,r0,#1                ; Skip flag byte
        LDR     r3,[SP,#1*4]            ; Pointer to argument
        BL      lookuptoken             ; Look the token up.
        BVS     %FT01

        ADR     r1,userdata
        LDR     r0,[sp]                 ; Get pointer to token
        LDRB    r0,[r0]                 ; Get flag
        CMP     r0,#0                   ; Is it 0 ?
        MOVEQ   r2,#&17000000           ; bg = grey, fg = black
        MOVNE   r2,#&71000000           ; bg = black, fg = grey1
        ORRNE   r2, r2, #&20
        STR     r2,[r1,#8]
        MOV     r2,#&FF000000
        ORR     r2, r2, #&20
        STR     r2,[r1,#12]
        SWI     XWimp_SetIconState      ; Reflect changes on screen.

01
        STRVS   r0,[sp]
        Pull    "r0-r3,PC"

;-------------------------------------------------------------------
;SetButton
;Entry:
;      r0 -> Message token for message to be put in icon.
;      r1 -> Argument (if any)
;      r2 =  Window handle.
;      r3 =  Icon number to set (must be indirected !)
; Exit:
;       Message put in icon.
;       [userdata] corrupted.
;
SetButton  ROUT
        Push    "r0-r3,LR"

      [ debug
        dline   "SetButton"
      ]
        ADR     r1,userdata
        STR     r2,[r1]                 ; Store window handle
        STR     r3,[r1,#4]              ; and icon number
        SWI     XWimp_GetIconState      ; Get current state.
        BVS     %FT01

        ADR     r1,userdata
        LDR     r2,[r1,#36]             ; r2 = Buffer length
        LDR     r1,[r1,#28]             ; r1 = Buffer pointer
        LDR     r0,[SP]                 ; r0 -> token
        LDR     r3,[SP,#1*4]            ; Get argument.
        BLVC    lookuptoken             ; Go lookup token.
        BVS     %FT01

        ADR     r1,userdata
        MOV     r0,#0
        STR     r0,[r1,#8]
        STR     r0,[r1,#12]
        SWI     XWimp_SetIconState      ; Reflect changes on  screen.

01
        STRVS   r0,[sp]
        Pull    "r0-r3,PC"

        LTORG

;-------------------------------------------------------------------
;SetTitle
;Entry:
;   r0 -> Message token for message to be put in window title.
;   r1 -> Argument
;   r2 -> Window handle
;Exit:
;      Message put in title.
;      [userdata] corrupted.
;
;*NOTE*
;       THIS MUST BE CALLED BEFORE THE WINDOW IS OPENED.
;
SetTitle  ROUT
        Push    "r0-r3,LR"


        ADR     r1,userdata
        STR     r2,[r1]                 ; Window handle
        ORR     r1,r1,#1                ; Get window block only.
        SWI     XWimp_GetWindowInfo

        ADR     r1,userdata
        LDRVC   r2,[r1,#84]             ; Buffer length of title
        LDRVC   r1,[r1,#76]             ; Buffer pointer of title
        LDRVC   r0,[SP]                 ; r0 = Pointer to token
        LDRVC   r3,[SP,#1*4]            ; r3 = Pointer to argument
        BLVC    lookuptoken             ; Go look the token up.

        STRVS   r0,[sp]
        Pull    "r0-r3,PC"

        LTORG

;-----------------------------------------------------------------

Format_GoFormat
; in:   r5 = pointer to format descriptor block as returned by
;              Service_EnumerateFormats

        BL      format_verify_get_memory
        Pull    "PC", VS

        STR     r5, [r8, #fw_format]
        MOV     r0, #FormatState_Ready
        STR     r0, [r8, #fw_state]
        STR     r0, [r8, #fw_firststate]

        LDR     r1, [r5, #4]            ; r1 -> Menu text for this format
        LDR     r2, [r8, #fw_handle]
        ADRL    r0, TFToken             ; r0 = title token.
        BL      SetTitle

        LDRVC   r3, [r8, #fw_drive]
        ADDVC   r3, r3, #"0"            ; Set drive number
        ADRVC   r1, userdata+&100       ; SetButton corrupts [userdata]
        STRVC   r3, [r1]
        ADRVCL  r0, FormatDriveToken
        MOVVC   r3, #0                  ; Icon 0 is drive number
        STRVC   r3, sectorop            ; make sure verify portion doesn't work in big disc mode accidentally
        BLVC    SetButton

        ADRVCL  r0,ReadyMessage         ; Display welcome message
        BLVC    Report

        ADRVCL  r0,BFToken              ; Set action button to "Format"
        MOVVC   r3,#6
        BLVC    SetButton

        ADRVC   r1,userdata
        STRVC   r2,[r1]                 ; Window handle
        MOVVC   r0,#2                   ; Icon 2
        STRVC   r0,[r1,#4]
        MOVVC   r0,#&f :SHL: 12         ; Set button type to writable
        STRVC   r0,[r1,#8]
        STRVC   r0,[r1,#12]
        SWIVC   XWimp_SetIconState

        SWIVC   XWimp_GetIconState
        LDRVC   r3, [r1, #28]           ; Indirected icon at +20 icon data.
        STRVC   r3, [r8, #fw_discname]  ; Store pointer to disc name.


        ; Set default disc name....

        ; Get time format
        ADRVCL  r0,FormatNameMessage
        ADRVC   r1,userdata
        MOVVC   r2,#50
        BLVC    lookuptoken

        ; Get 5 byte time
        ADRVCL  r1,userdata+60
        MOVVC   r0,#3
        STRVCB  r0,[r1]
        MOVVC   r0,#14
        SWIVC   XOS_Word

        ; Fill in name
        MOVVC   r0,#-1
        ADRVCL  r1,userdata+60
        LDRVC   r2,[r8,#fw_discname]
        MOVVC   r3,#11
        SUBVC   r4,r1,#60
        SWIVC   XTerritory_ConvertDateAndTime

        LDRVC   r0,[r8, #fw_handle]
        MOVVC   r1,#0
        MOVVC   r2,#7
        BLVC    SetBar                  ; Set bar to 0 length

        ADRVC   r1,userdata
        STRVC   r0,[r1]
        SWIVC   XWimp_GetWindowState
        MOVVC   r0,#-1
        STRVC   r0,[r1,#28]
        SWIVC   XWimp_OpenWindow

; OSS Need to free up window if error. From this point on the window is
; open so the state machine works - the memory gets freed when the user
; closes the window.
        MOVVS   r2, r8
        BVS     format_verify_error_delete_window

        LDR     r0,FormatState
        LDR     r4,[r8,#fw_drive]
        MOV     r1,#1
        MOV     r4,r1,ASL r4
        ORR     r0,r0,r4
        STR     r0,FormatState
        Pull    "PC"

        LTORG

;-------------------------------------------------------------------
;
;FindWindow
;Entry:
;      r0 = Window handle
;Exit
;      r0 preserved
;      r2 -> Window Block
;      Z set if found.
;
FindWindow ROUT
        Push    "LR"

        ADRL    r2,FormatWindows-fw_next
01
        LDR     r2,[r2,#fw_next]
        CMP     r2,#1
        Pull    "PC",LT
        LDR     r14,[r2,#fw_handle]
        TEQ     r0,r14
        BNE     %BT01

        Pull    "PC"


; OSS New routine to free memory if we get an error BEFORE the
; window has been displayed. What used to happen was that since there was
; no window up it would never get closed and hence would not get freed.
; This was provoked by trying to verify with no disk in the drive.

format_verify_error_delete_window ROUT   ; lr is already stacked on entry
        Push    "r0"                    ; Preserve error
        ADR     lr, ver_ret
        Push    "lr"                    ; This lr returns to us
        B       int_close_window
ver_ret SETV
        Pull    "r0, pc"                ; Return to original stacked lr


Format_CloseWindow
        Push    "LR"

        LDR     r0,[r1]                 ; Find window block
        BL      FindWindow
        Pull    "PC",NE                 ; Not our window

int_close_window                        ; Assumes stacked LR.

; OSS Delete the window - we don't want it hanging around until the task
; is killed (ie. never).

        ADR     r1, userdata
        LDR     r0, [r2, #fw_handle]
        STR     r0, [r1]
        SWI     XWimp_DeleteWindow

        LDR     r1,[r2,#fw_state]       ; Dismount if closing Format prematurely
        TEQ     r1,#FormatState_Paused
        LDREQ   r1,[r2,#fw_savedstate]
        TEQ     r1,#FormatState_Format
        TEQNE   r1,#FormatState_Formatting
        LDREQ   r1,[r2,#fw_drive]
        BLEQ    DismountDrive

        LDR     r0, [r2,#fw_prev]
        LDR     r14,[r2,#fw_next]

        CMP     r0,#0                   ; Unlink block from list
        STRNE   r14,[r0,#fw_next]
        STREQ   r14,FormatWindows
        CMP     r14,#0
        STRNE   r0,[r14,#fw_prev]

        LDR     r0,FormatState          ; Reset FormatState
        MOV     r14,#1
        LDR     r1,[r2,#fw_drive]       ; Clear this drive's bit
        MOV     r14,r14,ASL r1
        BIC     r0,r0,r14
        STR     r0,FormatState

        MOV     r0,#ModHandReason_Free  ; Free this RMA block
        SWI     XOS_Module

        Pull    "PC"

DismountDrive                           ; r1 = drive number
        Push    "r0-r5,lr"
        ADRL    r2,DismountCommand
        ADR     r0,userdata
        LDMIA   r2,{r2,r3,r4,r5,r14}
        STMIA   r0,{r2,r3,r4,r5,r14}
        ADD     r1,r1,#"0"
        STRB    r1,[r0,#15]
        SWI     XOS_CLI
        Pull    "r0-r5,pc"

NameTooShort
        DCD     42
        DCB     "DNShort", 0
        ALIGN

Format_MouseClick
        CMP     r4,#6                   ; Is it the action button ?
        Pull    "PC",NE

        MOV     r0,r3
        BL      FindWindow
        Pull    "PC",NE                 ; Not our window

      [ debugfo
        dline   "Format_MouseClick"
      ]
        ; Check the disc name's OK
        LDR     r14, [r2, #fw_state]
        TEQ     r14, #FormatState_Ready
        BNE     %FT01

        LDR     r0, [r2, #fw_discname]
        LDRB    r14, [r0, #0]
        CMP     r14, #" "
        LDRHIB  r14, [r0, #1]
        CMPHI   r14, #" "
        ADRLS   r0, NameTooShort
        BLLS    lookuperror
        Pull    "PC",VS
01

        LDR     r14,[r2,#fw_state]
      [ debugfo
        dreg    r14,"current state = "
      ]

        TEQ     r14,#FormatState_OK
        BEQ     int_close_window
        LDR     r5, [r2,#fw_savedstate] ; In case we need it later
      [ debugfo
        dreg    r5,"saved state = "
      ]
        TEQ     r14,#FormatState_Paused ; Unless it is paused
        STRNE   r14,[r2,#fw_savedstate] ; Save old state.
        MOV     r14,r14,ASL #2
        ADRL    r1,NextStateTable
        LDR     r14,[r1,r14]            ; Get new state

        TEQ     r14,#FormatState_Resume ; Is the new state Resume?
        MOVEQ   r14,r5
        STR     r14,[r2,#fw_state]
      [ debugfo
        dreg    r14,"restored state = "
      ]

        MOV     r8,r2
        MOV     r14,r14,ASL #2
        ADRL    r1,StateButtonTextTable ; Get button text for this state
        LDR     r14,[r1,r14]
        LDR     r2,[r8,#fw_handle]      ; r2 = Window handle
        ADD     r0,r1,r14               ; r0 -> Token for button
        MOV     r3,#6                   ; Action is icon 6
        BL      SetButton               ; Set button text.

        LDR     r14,[r8,#fw_state]
        TEQ     r14,#FormatState_Verifying
        TEQNE   r14,#FormatState_Verify
        Pull    "PC",NE

        ADRL    r0,VerifyMessage
        LDR     r2,[r8,#fw_handle]
        BL      Report

        Pull    "PC"


Format_NullEvent        ROUT
        Push    "LR"

        ADRL    r1,FormatWindows-fw_next        ; Search for an active window
01
        BVC     %FT02
      [ debugfo
        dline   "Format_NullEvent handling error"
      ]
        Push    "r0"
        LDR     r2,[r1,#fw_state]
        TEQ     r2,#FormatState_OK
        ADREQL  r0,BOKToken
        BEQ     %FT10
        STR     r2,[r1,#fw_savedstate]
        MOV     r2,#FormatState_Paused
        STR     r2,[r1,#fw_state]
        ADRL    r0,BRToken
10
        LDR     r2,[r1,#fw_handle]
        MOV     r3,#6
        BL      SetButton
        SETV
        Pull    "r0,PC"
02
        LDR     r1,[r1,#fw_next]
        CMP     r1,#0
        Pull    "PC",EQ                         ; No more active windows.

        ADR     lr,%BT01
        LDR     r2,[r1,#fw_state]
        ADD     PC,PC,r2,ASL #2
        MOV     r0,r0

        B       %BT01                           ; Ready         Do nothing
        B       StartFormat                     ; Format
        B       FormatTrack                     ; Formatting
        B       %BT01                           ; Verify ready
        B       StartVerify                     ; Verify
        B       VerifyTrack                     ; Verifying
        B       %BT01                           ; Paused
        B       %BT01                           ; Resume
        B       %BT01                           ; Press OK
        B       SetPause                        ; SetPause caused by external events.

SetPause        ROUT
        Push    "r1,LR"

        MOV     r2,#FormatState_Paused
        STR     r2,[r1,#fw_state]
        ADRL    r0,BRToken
        LDR     r2,[r1,#fw_handle]
        MOV     r3,#6
        BL      SetButton

        Pull    "r1,PC"

StartFormat     ROUT
        Push    "R1,LR"

        MOV     r8,r1

        ADR     r1,userdata
        MOV     r0,#":"
        STRB    r0,[r1]
        LDR     r0,[r8,#fw_drive]
        ADD     r0,r0,#"0"
        STRB    r0,[r1,#1]
        MOV     r0,#0
        STRB    r0,[r1,#2]
        BL      GetMediaName_nochecks   ; r1 -> "adfs::discname"
        BLVC    dismountit              ; If we get a name the dismount it
        BVC     %FT01                   ;   and start format
        LDRB    r1,[r0]                 ; Otherwise, check for disc error or unformatted disc
      [ debugfo
        dreg    r1,"Error returned = "
      ]
        TEQ     r1,#&9A                 ; &9A = Unformatted disc
        TEQNE   r1,#&C7                 ; &C7 = Disc error
        BEQ     %FT01                   ; If any of the above then no need to dismount
        SETV
        Pull    "r1,PC"                 ; Otherwise, don't start until disc can be dismounted
01
      [ :LNOT: SCSI :LAND: :LNOT: SDFS
        LDR     r3,[r8,#fw_format]

        ADD     r0,r8,#fw_formatspec
        LDR     r1,=XADFS_VetFormat
        LDR     r2,[r8,#fw_drive]
        LDR     r11,[r3,#12]
        LDR     r3,[r3,#16]
        BL      DoSWI
        Pull    "r1,PC",VS
      ]

        ADRL    r0,FormattingMessage
        LDR     r2,[r8,#fw_handle]
        BL      Report

        ADD     r0,r8,#fw_formatspec
        ADD     r2,r8,#fw_discrecord
        ADD     r4,r8,#fw_formatrecord

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
        STR     r3, [r2, #DiscId]
        STR     r3, [r2, #DiscId + 4]
        STR     r3, [r2, #DiscId + 4]

        MOV     r14,#FormatState_Formatting
        STR     r14,[r8,#fw_state]

        MOV     r14,#0
        STR     r14,[r8,#fw_currenttrack]
        LDR     r14,[r8,#fw_formatspec+24]
        STR     r14,[r8,#fw_numberoftracks]


        ADR     r1,userdata
        LDR     r0,[r8,#fw_handle]
        STR     r0,[r1]
        MOV     r0,#2
        STR     r0,[r1,#4]
        MOV     r0,#1 :SHL: 22      ; get ready to set bit 22,clear others
        STR     r0,[r1,#8]
        MOV     r0,#&f :SHL: 12     ; Set button type to never
        ORR     r0,r0,#1 :SHL: 22   ; shade the disc title icon
        STR     r0,[r1,#12]
        SWI     XWimp_SetIconState
        Pull    "r1,PC",VS

        ADR     r1,userdata
        SWI     XWimp_GetCaretPosition
        LDR     r0,[r1]
        LDR     r1,[r8,#fw_handle]
        TEQ     r0,r1
        Pull    "r1,PC",NE

        MOV     r0,#-1
        MOV     r1,#-1
        SWI     XWimp_SetCaretPosition
        Pull    "r1,PC"


        LTORG


FormatTrack     ROUT
        Push    "r1,LR"

        MOV     r8,r1

        LDR     r1,[r8,#fw_currenttrack]
        ADD     r0,r8,#fw_formatspec
        ADD     r4,r8,#fw_formatrecord
        BL      ConstructDoFormatIdList
        MOV     r1,#4
        MOV     r3,#0
        LDR     r14,[r8,#fw_drive]
        MOV     r14,r14,ASL #29
        ORR     r2,r2,r14
        SWI     X$SWIPrefix._DiscOp
        Pull    "r1,PC",VS

        LDR     r4,[r8,#fw_currenttrack]
        ADD     r4,r4,#1
        STR     r4,[r8,#fw_currenttrack]
        LDR     r5,[r8,#fw_numberoftracks]
        LDR     r14,[r8, #fw_MaxFormatBarLength]
        MUL     r14,r4,r14
        DivRem  r1,r14,r5,r7,norem
        LDR     r0,[r8,#fw_handle]
        MOV     r2,#11
        BL      SetBar
        CMP     r4,r5
        Pull    "r1,PC",NE

; Disc has been formatted, lay down the structure

        ADR     r1,userdata
        LDR     r0,[r8,#fw_handle]
        STR     r0,[r1]
        MOV     r0,#2
        STR     r0,[r1,#4]
        SWI     XWimp_GetIconState
        Pull    "r1,PC",VS

        LDR     r5,[r1,#28]             ; Pointer to name buffer
        MOV     r14,r5                  ; Null terminate it.
01
        LDRB    r1,[r14],#1
        CMP     r1,#31
        BGT     %BT01
        MOV     r1,#0
        STRB    r1,[r14,#-1]            ; Null terminate.

        ADRL    r14,ADFSPrefix
        LDMIA   r14,{r2,r3}
        ADR     r1, userdata
        STMIA   r1, {r2,r3}
        LDR     r0,[r8,#fw_drive]
        ADD     r0,r0,#"0"
        STRB    r0,[r1,#6]
        MOV     r0,#&C0
        SWI     XOS_Find
        Pull    "r1,PC",VS
        MOV     r3,r0

        LDR     r0,[r8,#fw_format]

        LDR     r11,[r0,#20]
        LDR     r0,[r0,#24]
        MOV     r1,#DefectList_End
        STR     r1,[r8,#fw_defectlist]
        ADD     r1,r8,#fw_defectlist
        MOV     r2,r5
        BL      DoSWI
        Push    "r0",VS                         ; save error
        MOV     r0,#0
        MOV     r1,r3
        BVC     %FT10
        SWI     XOS_Find                        ; stop disc spinning
        ADRL    r0,FormatFailMessage
        LDR     r2,[r8,#fw_handle]
        BL      Report
        MOV     r0,#FormatState_OK
        STR     r0,[r8,#fw_state]
        SETV
        Pull    "r0,r1,PC"
10
        SWI     XOS_Find
        Pull    "r1,PC",VS

        MOV     r14,#FormatState_Verify         ; Go verify it.
        STR     r14,[r8,#fw_state]

        ADRL    r0,VerifyMessage
        LDR     r2,[r8,#fw_handle]
        BL      Report

        LDR     r1,[r8,#fw_drive]
        BL      DismountDrive

        Pull    "r1,PC"


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
        STR     lr, [r4, #DoFormatGap1]

        ; Now we've got to fill in the sector numbers

        ; Offset to the first sector on the track is combination of side and track skew
        LDRB    r7, [r2, #0]    ; cylinder
        LDRB    r6, [r0, #FormatTrackTrackSkew]
        ; Sign extend the skew
        MOV     r6, r6, ASL #24
        MOV     r6, r6, ASR #24
        MUL     r7, r6, r7              ; Skew for tracks

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

        ; Construct disc address of track in r2
        LDR     lr, [r0, #FormatSectorSize]
        LDRB    r2, [r0, #FormatSectorsPerTrk]
        MUL     r2, lr, r2              ; Bytes per track
        LDR     lr, [r0, #FormatTracksToFormat]
        LDRB    r5, [r0, #FormatOptions]
        AND     r5, r5, #FormatOptSidesMask
        TEQ     r5, #FormatOptSide1Only
        ADDEQ   r1, r1, lr              ; Track as understood by DiscOp
        MUL     r2, r1, r2              ; Byte offset of start of track

        Pull    "r0-r1,r3-r7,pc"

;-------------------------------------------------------------------

Format_GoVerify
        BL      format_verify_get_memory
        Pull    "PC", VS

        ;call ADFS_MiscOp to find out whether this ADFS understands sector addressing.
        ;If it does, I have to deal with bigger discs and two word defect entries.

        ;IMPORTANT: as written this code will adapt automatically to the type of ADFS
        ;which is running; it will use sector addressing if it is supported and old
        ;byte addressing when it isn't. At some point in the future the routines
        ;specific to byte addressing should be removed.

        MOV     r0, #MiscOp_ReadInfo
        SWI     X$SWIPrefix._MiscOp       ; returns R0->data block

        LDRVC   r0, [r0, #Create_Flags]   ; fetch the flags
        ANDVC   r0, r0, #CreateFlag_BigDiscSupport
        SUBVSS  r0, r0, r0                ; if we failed substitute zero and clear V
        STR     r0, sectorop              ; non-zero if this ADFS is SectorOp capable

        Debug   ag,"Set sectorop flag to",r0

        MOV     r0, #FormatState_VerifyReady
        STR     r0, [r8, #fw_state]
        STR     r0, [r8, #fw_firststate]

        MOV     r1, #0                  ; r1 = no parameter for title
        LDR     r2, [r8, #fw_handle]
        ADRL    r0,TVToken              ; r0 = title token.
        BL      SetTitle

        LDRVC   r3, [r8, #fw_drive]
        ADDVC   r3,r3,#"0"              ; Set drive number
        ADRVC   r1,userdata+&100        ; SetButton corrupts [userdata]
        STRVC   r3,[r1]
        ADRVCL  r0,FormatDriveToken
        MOVVC   r3,#0                   ; Icon 0 is drive number
        BLVC    SetButton

        ADRVCL  r0,VerifyMessage        ; Display welcome message
        BLVC    Report

        ADRVCL  r0,BPToken              ; Set action button to "Pause"
        MOVVC   r3,#6
        BLVC    SetButton

        ADRVC   r1,userdata
        STRVC   r2,[r1,#0]
        MOVVC   r0,#2
        STRVC   r0,[r1,#4]
        SWIVC   XWimp_GetIconState
        LDRVC   r1,[r1,#24+8]
        LDRVC   r0,=&00003252           ; "R2"
        STRVC   r0,[r1]
        ADRVC   r1,userdata
        MOVVC   r0,#2_0001 :SHL: 28     ; Get ready to set the background colour
        STRVC   r0,[r1,#8]
        MOVVC   r0,#&f :SHL: 12         ; Set button type to never
        ORRVC   r0,r0,#2_1111 :SHL: 28  ; background colour 1
        STRVC   r0,[r1,#12]
        SWIVC   XWimp_SetIconState

        ADRVCL  r1,ADFSPrefix
        LDMVCIA r1,{r0,r14}
        ADRVC   r1,userdata
        STMVCIA r1,{r0,r14}

        LDRVC   r0,[r8,#fw_drive]
        ADDVC   r0,r0,#"0"
        STRVCB  r0,[r1,#6]
        MOVVC   r0,#0
        STRVCB  r0,[r1,#7]

        ADDVC   r1,r1,#5
 [ debugfo :LOR: debugag
        dstring r1, "disc is "
 ]
        BLVC    GetMediaName_nochecks   ; r1 -> "adfs::discname"
        BVS     %FT01

        Push    "r1"
        ADR     r1,userdata+&100
        LDR     r0,[r8,#fw_handle]
        STR     r0,[r1]
        MOV     r0,#2
        STR     r0,[r1,#4]
        SWI     XWimp_GetIconState
        ADDVS   sp,sp,#4
        BVS     %FT01

        ADR     r1,userdata+&100
        LDR     r14,[r1,#28]
        Pull    "r1"
        ADD     r1,r1,#6
11
        LDRB    r3,[r1],#1
        STRB    r3,[r14],#1
        CMP     r3,#32
        BGE     %BT11

        ADR     r1,userdata+&100
        MOV     r0,#0
        STR     r0,[r1,#8]
        STR     r0,[r1,#12]
        SWI     XWimp_SetIconState

        ADRVC   r1,userdata
        STRVC   r2,[r1]
        SWIVC   XWimp_GetWindowState
        MOVVC   r0,#-1
        STRVC   r0,[r1,#28]
        SWIVC   XWimp_OpenWindow
01
; OSS Need to free up window if error. From this point on the window is
; open so the state machine works - the memory gets freed when the user
; closes the window.
        MOVVS   r2, r8
        BVS     format_verify_error_delete_window

        LDR     r0,FormatState
        LDR     r4,[r8,#fw_drive]
        MOV     r1,#1
        MOV     r4,r1,ASL r4
        ORR     r0,r0,r4
        STR     r0,FormatState

        Pull    "LR"                    ; FALL THROUGH
        MOV     r1,r8


StartVerify

        Push    "r1,LR"

        MOV     r8,r1

        LDR     r0,[r8,#fw_handle]
        MOV     r1,#0
        MOV     r2,#7
        BL      SetBar

        ADRL    r0,ADFSPrefix
        ADR     r1,userdata
        LDMIA   r0,{r2,r3}
        STMIA   r1,{r2,r3}
        LDR     r0,[r8,#fw_drive]
        ADD     r0,r0,#"0"
        STRB    r0,[r1,#6]

        ; now a chance to turn off the fancy stuff if we're dealing with a DOSFS disc

        MOV     r0, #5
        SWI     XOS_File

        MOVVS   r0, #3                  ; set to 3 if anything went wrong
        EORS    r0, r0, #3              ; set EQ if = 3, and zero r0
        STREQ   r0, sectorop            ; and if eq change the flag to zero

        ADD     r2,r8,#fw_defectlist
        MOV     r5,#512                 ; buffer is actually 520 long, but
                                        ; the last 8 are for the terminator
        LDR     r0,sectorop
        CMP     r0,#CreateFlag_BigDiscSupport

        MOVNE   r0,#41                  ; read defect list as single words
        MOVEQ   r0,#56                  ; read defect list as word pairs

        Debug   ag,"reading defect list using reason code",r0

        Push    "r1"

        SWI     XOS_FSControl           ; Read defect list.

        [ debugag
        BVC     %FT91
        DLINE   "Got an error from FSControl 41/56"
91
        ]

        Pull    "r1",VS                 ; may get an error if the defect list built from map data
        Pull    "r1,PC",VS              ; exceeds our space or the disc is so knackered the
                                        ; call fails with a "disc not formatted" error!
                                        ; As the window is open just return to the NullEvent hander

        ; if it was the new style call, I need to terminate it for use here
        ; (the new call also modifies R1 to return the number of pairs)

        LDR     r0,sectorop
        CMP     r0,#CreateFlag_BigDiscSupport

        MOVEQ   r1,r1,LSL #3            ; change number of pairs into number of bytes
        MOVEQ   lr,#DefectList_End
        STREQ   lr,[r2,r1]              ; store terminator in first word
        ADDEQ   r1,r1,#4
        STREQ   lr,[r2,r1]              ; and in second word

        Pull    "r1"

      [ debugfo
        dline   "read defect list"
      ]

        ADD     r0,r1,#5
        ADD     r1,r8,#fw_discrecord
        SWI     X$SWIPrefix._DescribeDisc ; Get disc record.
        Pull    "r1,PC",VS

        MOV     r0,#0
        STR     r0,[r8,#fw_currenttrack]
        STR     r0,[r8,#fw_currenttrack_high]

        LDR     r0,[r8,#fw_discrecord+16]       ; Disc size in bytes (low)
        LDR     r4,[r8,#fw_discrecord+36]       ; Disc size in bytes (high)

        Debug   ag,"disc size high/low",r4,r0

        LDRB    r1,[r8,#fw_discrecord+0]        ; Log2SectorSize
        LDRB    r2,[r8,#fw_discrecord+1]        ; Sectors in track
        MOV     r3,#1
        MOV     r3,r3,ASL r1                    ; Bytes per sector
        STR     r3,[r8,#fw_bytespersector]

        Debug   ag,"bytes per sector",r3

        MUL     r3,r2,r3                        ; Bytes in track
        STR     r3,[r8,#fw_bytespertrack]
        STR     r3,[r8,#fw_bytestoverify]

        Debug   ag,"bytespertrack",r3

        STMFD   r13!,{r0,r2-r9}                 ; need lots of registers for the divide coming up!

        ;r0: disc size low
        ;r4: disc size high
        ;r3: bytes per track
        ;result to r1

        MOV     r2,#0                           ; used as top word of bytes per track
        mextralong_divide r1,r14,r0,r4,r3,r2,r7,r8,r9 ; r1,r14 = tracks in disc
        LDMFD   r13!,{r0,r2-r9}

        Debug   ag,"number of tracks high/low",r14,r1

        STR     r1,[r8,#fw_numberoftracks]
        STR     r14,[r8,#fw_numberoftracks_high]

        MOV     r0,#FormatState_Verifying
        STR     r0,[r8,#fw_state]

        ADD     r0,r8,#fw_defectlist
        STR     r0,[r8,#fw_currentdefect]       ; set up pointer to defect list

        MOV     r0,#0
        STR     r0,[r8,#fw_currentaddress]      ; this may be a byte offset (old style)
                                                ; or a sector number (new style). In general we simply
                                                ; take whatever is returned from the (Sector)DiscOp call
                                                ; The only time it becomes important is when a defect is
                                                ; encountered, which is always presented to the user in
                                                ; bytes.
        Pull    "r1,PC"
VerifyTrack
        Push    "r1,LR"

        Debug   ag,"in verifytrack"

        MOV     r8,r1

        LDR     r2,[r8,#fw_currentaddress]
        LDR     r14,[r8,#fw_drive]
        MOV     r14,r14,ASL #29
        ORR     r2,r2,r14                       ; put the drive number into place
        MOV     r1,#0
        MOV     r3,#0
        LDR     r4,[r8,#fw_bytestoverify]
        TEQ     r4,#0                           ; may have got error on last sector of a track
      [ debugfo :LOR: debugag
        dreg    r2,"ADFS_DiscOp r2 = ",cc
        dreg    r4,", r4 = "
      ]
        BEQ     %FT80
        LDR     r0,sectorop
        CMP     r0,#CreateFlag_BigDiscSupport
        BEQ     %FT78
        SWI     X$SWIPrefix._DiscOp             ; call DiscOp or SectorDiscOp depending on the ADFS type
        B       %FT80
78      SWI     X$SWIPrefix._SectorDiscOp
80      BIC     r2,r2,#7 :SHL: 29               ; take the drive number off again
        BVS     %FT01

        ; r4 (bytes left to verify) should be 0 after successful DiscOp
      [ debugfo :LOR: debugag
        dreg    r4,"DiscOp OK, bytes left to verify = "
      ]

NextVerify
; r2 must be the address at which to start the next DiscOp (bytes or sector address)
; r4 must be the number of bytes left to verify on the current track (probably 0 if nothing went wrong)

        STR     r2,[r8,#fw_currentaddress]
      [ debugfo :LOR: debugag
        dreg    r2,"next verify from "
      ]

        LDR     r3,[r8,#fw_currenttrack]
        CMP     r4,#0
        BNE     %FT83
        LDR     r4,[r8,#fw_currenttrack_high]
        ADDS    r3,r3,#1
        ADC     r4,r4,#0
        STR     r3,[r8,#fw_currenttrack]
        STR     r4,[r8,#fw_currenttrack_high]
        Debug   ag,"new currenttrack hi/lo",r4,r3
        MOVS    r4, #0                         ; get the EQ flag back for the Pull NE later
        LDR     r4,[r8,#fw_bytespertrack]
83
        STR     r4,[r8,#fw_bytestoverify]
      [ debugfo
        dreg    r4,"bytes to verify = "
      ]

        Pull    "r1,PC",NE                      ; still on the same track

        LDR     r5,[r8,#fw_numberoftracks]

        ;r1 = r14/r5. r7 corrupt, r14=remainder

        STMFD   r13!,{r0,r2-r10}

        ;multiply max length by current track, then divide by max track

        LDR     r14,[r8,#fw_MaxFormatBarLength]
        MOV     r9,#0                            ; high word of length

        LDR     r7,[r8,#fw_currenttrack]
        LDR     r10,[r8,#fw_currenttrack_high]

        mextralong_multiply r5,r6,r7,r10,r14,r9  ;r5 is low result, r6 is high result

        LDR     r7,[r8,#fw_numberoftracks]
        LDR     r10,[r8,#fw_numberoftracks_high]

        Debug   ag,"dividing hi/lo",r6,r5
        Debug   ag,"by hi/lo",r10,r7

        mextralong_divide r1,r14,r5,r6,r7,r10,r2,r3,r4 ;r1 is result

        Debug   ag,"divide result r14/r1",r14,r1

        LDMFD   r13!,{r0,r2-r10}

        LDR     r0,[r8,#fw_handle]
        MOV     r2,#10
        BL      SetBar

        CMP     r3,r5
        Pull    "r1,PC",NE

; End of verify
        LDR     r1,[r8,#fw_defects]
        TEQ     r1,#0
        LDR     r2,[r8,#fw_firststate]
        BNE     %FT10
        TEQ     r2,#FormatState_Ready
        ADREQL  r0,FormatCompleteMessage
        ADRNEL  r0,VerifyCompleteMessage
        B       %FT20
10
        TEQ     r1,#1
        BNE     %FT15
        TEQ     r2,#FormatState_Ready
        ADREQL  r0,FormatCompleteDefectsSingle
        ADRNEL  r0,VerifyCompleteDefectsSingle
        B       %FT20
15
        TEQ     r2,#FormatState_Ready
        ADREQL  r0,FormatCompleteDefectsMessage
        ADRNEL  r0,VerifyCompleteDefectsMessage
        Push    "r0,r2"
        MOV     r0,r1
        ADR     r1,userdata+&100
        MOV     r2,#20
        SWI     XOS_ConvertCardinal4
        STRVS   r0,[sp]
        Pull    "r0,r2"
        Pull    "r1,PC",VS
        ADR     r1,userdata+&100
20
        TEQ     r2,#FormatState_Ready
        BNE     %FT30
        Push    "r0-r3"
        ADRL    r1,ADFSPrefix
        LDMIA   r1,{r0,r2}
        ADR     r1,userdata
        STMIA   r1,{r0,r2}
        LDR     r0,[r8,#fw_drive]
        ADD     r0,r0,#"0"
        STRB    r0,[r1,#6]                      ; fill in the drive number
        ADD     r3,r8,#fw_defectlist
21
        LDR     r0,sectorop
        CMP     r0,#CreateFlag_BigDiscSupport
        BNE     %FT22

23
        [ debugag
        DREG    r3,"Defect list pointer "
        ]
        LDR     r2,[r3],#4                      ; fetch the low word of the defect list
        LDR     r0,[r3],#4                      ; and the high word
        TEQ     r2,#DefectList_End              ; check the low word for the magic value
        TEQEQ   r0,#DefectList_End              ; and the high word
        Pull    "r0-r3",EQ
        BEQ     %FT30

        Push    "r3"                            ; save the defect list pointer
        MOV     r3,r0                           ; move the high word into place
        MOV     r0,#57                          ; FSControl_AddDefect64, but I'm doing this before it exists!
        [ debugag
        DREG    r2,"mapping out, low "
        DREG    r3,"mapping out, high "
        ]
        SWI     XOS_FSControl
        Pull    "r3"                            ; get the defect list pointer back
        BVC     %BT23
        [ debugag
        DLINE   "!!!!! OS_FSControl 57 gave an error !!!!!"
        ]
        B       %FT31

22
        LDR     r2,[r3],#4                      ; fetch the first word
        TEQ     r2,#DefectList_End              ; is it the magic terminator
        Pull    "r0-r3",EQ                      ; it is: recover registers...
        BEQ     %FT30                           ;        ... and out
        MOV     r0,#FSControl_AddDefect         ; else add it as a defect
        SWI     XOS_FSControl
        BVC     %BT22                           ; and go round again providing nothing went wrong
31
        Pull    "r0-r3"                         ; If add defect fails, simulate desktop verify
        ADRL    r0,VerifyCompleteDefectsMessage
30
        LDR     r2,[r8,#fw_handle]
        BL      Report
        Pull    "r1,PC",VS
        ADRL    r0,BOKToken
        MOV     r3,#6
        BL      SetButton
        Pull    "r1,PC",VS

        MOV     r0,#FormatState_OK
        STR     r0,[r8,#fw_state]
        Pull    "r1,PC"

11
        Pull    "r1,PC"

01
        ; It is only a defect if it is a disc error
        LDR     r14,[r0]
       [ debugfo
        DREG    r14,"error is "
        DLINE   "Compare with &100108c7"
       ]
        LDR     r1,=   &FFFFF
        AND     r14,r14,r1
        LDR     r1,=&108c7
        CMP     r14,r1
        SETV    NE
        Pull    "r1,PC",VS

      [ debugfo
        dreg    r2,"defect found at "
      ]

        ; more complications caused by two word defects now...
        LDR     r0,sectorop
        CMP     r0,#CreateFlag_BigDiscSupport
        BNE     %FT05                                  ; go and take the easy option...

        [ debugag
        DREG    r2,"Disc error at "
        ]

        ; r2 is presently a sector address; need to turn it into a byte address

        MOV     r9,r2                                  ; save the sector address for later

        LDR     r0,[r8,#fw_bytespersector]             ; bytes per sector low
        MOV     r1,#0                                  ; bytes per sector high

        MOV     r4,#0                                  ; use as top word for sector address

        mextralong_multiply r14,r5,r0,r1,r2,r4

        MOV     r2,r14                                 ; defect address low
        MOV     r4,r5                                  ; defect address high

        [ debugag
        DREG    r2,"defect low "
        DREG    r4,"defect high "
        ]

        LDR     r0,[r8,#fw_currentdefect]
06
        LDR     r1,[r0]                                ; defect from list (low)
        LDR     lr,[r0,#4]                             ; defect from list (high)

        ;need to continue if r4r2 > lrr1

        SUBS    r5,r1,r2
        SBCS    r6,lr,r4                               ; do the test by subtracting the defect we just found
                                                       ; from the one in the list. if the defect is larger
        ADDMI   r0,r0,#8                               ; than the one in the list then we'll have a negative
        BMI     %BT06                                  ; result with MI set

        ; and now set EQ if they are (single word code used a CMP and got this for free!)
        CMP     r1,r2
        CMPEQ   lr,r4

        STR     r0,[r8,#fw_currentdefect]              ; update the defect list pointer

        MOV     r10,r4                                 ; save the byte address (high)

        ADD     r9,r9,#1                               ; next sector
        LDR     r0,[r8,#fw_currentaddress]             ; where we read from
        STR     r9,[r8,#fw_currentaddress]             ; where to restart
        SUB     r9,r9,r0                               ; number of sectors done/to skip
        LDR     r0,[r8,#fw_bytespersector]
        MUL     lr,r0,r9                               ; convert to number of bytes
        LDR     r4,[r8,#fw_bytestoverify]
        SUB     r4,r4,lr                               ; and modify the total

        LDREQ   r2,[r8,#fw_currentaddress]

        [ debugag
        DREG    r2,"about to restart from!!!"
        ]

        BEQ     NextVerify                             ; this is from the address comparison above

        MOV     r9,r2                                  ; save the byte address (low)

        LDR     r14,[r8,#fw_defects]
        ADD     r14,r14,#1
        STR     r14,[r8,#fw_defects]

        MOV     r2,r9
        MOV     r1,r10

        ;defect address is now r1r2 (bytes)

        TEQ     r14,#FormatState_Ready
        BNE     %FT50
        LDR     r14,[r8,#fw_currentdefect]
        STR     r2,[r14],#4
        STR     r1,[r14],#4
        MOV     r0,#DefectList_End
        STR     r0,[r14]
        STR     r0,[r14,#4]
        STR     r14,[r8,#fw_currentdefect]
50

        MOV     r9,r1                                 ; save the defect byte address (high)
        MOV     r10,r2                                ; save the defect byte address (low)

        ADR     r1,userdata+&100

        CMP     r9,#0                                 ; only convert the high word for display
        BEQ     %FT51                                 ; if it is non-zero

        MOV     r0,r9
        MOV     r2,#20
        SWI     XOS_ConvertHex8
        Pull    "r1,pc",VS

        ADRL    r1,userdata+&108
51
        MOV     r0,r10
        MOV     r2,#20
        SWI     XOS_ConvertHex8
        Pull    "r1,PC",VS

        ADR     r1,userdata+&100
        ADRL    r0,DefectToken
        LDR     r2,[r8,#fw_handle]
        BL      Report
        Pull    "r1,PC",VS

        LDR     r0,[r8,#fw_state]
        STR     r0,[r8,#fw_savedstate]
        MOV     r0,#FormatState_Paused
        STR     r0,[r8,#fw_state]

        ADRL    r0,BRToken
        LDR     r2,[r8,#fw_handle]
        MOV     r3,#6
        BL      SetButton

        ; fw_currentaddress already set up
        STR     r4, [r8, #fw_bytestoverify]

        Pull    "r1,pc"

;////////////////////////////////////////////////////////////////////////////

05
        LDR     r0,[r8,#fw_currentdefect]               ; Skip known defects
02
        LDR     r1,[r0]
        CMP     r1,r2
        ADDLT   r0,r0,#4
        BLT     %BT02
        STR     r0,[r8,#fw_currentdefect]

        LDR     r0,[r8,#fw_bytespersector]
        ADD     r2,r2,r0                                ; r2 now byte address for next sector after error
        LDR     r0,[r8,#fw_currentaddress]
        SUB     r0,r2,r0                                ; r0 number of bytes verified successfully
        LDR     r4,[r8,#fw_bytestoverify]
        SUB     r4,r4,r0                                ; and reduce the total

        BEQ     NextVerify

      [ debugfo
        dline   "not a known defect"
      ]

        MOV     r5,r2           ; save currentaddress for next DiscOp (r4 is safe)

        LDR     r14,[r8,#fw_defects]
        ADD     r14,r14,#1
        STR     r14,[r8,#fw_defects]

        LDR     r0,[r8,#fw_bytespersector]
        SUB     r0,r2,r0
        LDR     r14,[r8,#fw_firststate]
        TEQ     r14,#FormatState_Ready
        BNE     %FT50
        LDR     r14,[r8,#fw_currentdefect]
        STR     r0,[r14],#4
        MOV     r1,#DefectList_End
        STR     r1,[r14]
        STR     r14,[r8,#fw_currentdefect]
50
        ADR     r1,userdata+&100

        MOV     r2,#20
        SWI     XOS_ConvertHex8
        Pull    "r1,PC",VS

        ADR     r1,userdata+&100
        ADRL    r0,DefectToken
        LDR     r2,[r8,#fw_handle]
        BL      Report
        Pull    "r1,PC",VS

        LDR     r0,[r8,#fw_state]
        STR     r0,[r8,#fw_savedstate]
        MOV     r0,#FormatState_Paused
        STR     r0,[r8,#fw_state]

        ADRL    r0,BRToken
        LDR     r2,[r8,#fw_handle]
        MOV     r3,#6
        BL      SetButton

        STR     r5, [r8, #fw_currentaddress]    ; set up for when verify is continued
        STR     r4, [r8, #fw_bytestoverify]

        Pull    "r1,pc"

 [ debug                                        ; NDRDebugroutines are fetched in s.backup
        InsertDebugRoutines
        InsertHostDebugRoutines
 ]
        LNK     s.Backup
