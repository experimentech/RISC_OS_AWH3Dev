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
        SUBT    > Sources.CtrlUtils

; FSControl utilities:

; Facilities for constructing full paths
; Facilities for doing catalogues/examines/infos and *accesses
; Facilities for starting up catalogues etc.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_ConstructFullPathWithoutFSAndSpecial
;
; In    r1 -> tail for directory
;       r2 -> buffer to construct path into
;       r3 = size of buffer
;       r6 = scb^/special field^
;       fscb^
;
; Out
;       r2 advanced to end of string in buffer
;       r3 reduced by length of string inserted, will be sent
;               negative to correct value for full string
;       r4 = special field^ for root fs
;       r5 = root fscb^
;
int_ConstructFullPathWithoutFSAndSpecial Entry
        TEQ     fscb, #Nowt
        BEQ     %FT10
        LDRB    r14, [fscb, #fscb_info]
        TEQ     r14, #0
        BNE     %FT10
        Push    "r1,r6,fscb"
        LDR     fscb, [r6, #:INDEX:scb_fscb]
        LDR     r1, [r6, #:INDEX:scb_path]
        LDR     r6, [r6, #:INDEX:scb_special]
        BL      int_ConstructFullPathWithoutFSAndSpecial
        LDR     r1, [sp]
        LDRB    r1, [r1]
        TEQ     r1, #0
        ADRNE   r1, %FT90                       ; . between path elements, only if next piece of path is non-""
        BLNE    %FT50
        Pull    "r1,r6,fscb"
        BL      %FT50                           ; <path>
        EXIT
10
        ; Got to a real filing system - construct the starting gubbins
        MOV     r4, r6
        MOV     r5, fscb
        CMP     r1, #0
        BLNE    %FT50                           ; <path>
        EXIT

50      ; Secure copy a string into the buffer - always accumulate the length, but
        ; not necessarily copy the string
        Push    "lr"
        RSB     r3, r3, #0
        BL      strlen_accumulate
        RSBS    r3, r3, #0
        Swap    r1, r2, GT
        BLGT    strcpy_advance
        Swap    r1, r2, GT
        Pull    "pc"

90
        DCB     ".", 0
        ALIGN
;
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_ConstructPathWithoutFS
;
; In    r1 -> tail for directory
;       r2 -> buffer to construct path into
;       r3 = size of buffer
;       r6 = scb^/special field^
;       fscb^
;
; Out   r2 advanced to end of string in buffer
;       r3 reduced by length of string inserted, will be sent
;               negative to correct value for full string
;       r4 = special field^ for root fs
;       r5 = root fscb^
;
int_ConstructPathWithoutFS Entry "r1,r2,r3"

        ; Get to root FS and special
        MOV     r3, #0
        BL      int_ConstructFullPathWithoutFSAndSpecial

        LDMIB   sp, {r2,r3}

        ; #<special>:
        TEQ     r4, #NULL
        TEQNE   r4, #Nowt
        ADRNE   r1, %FT80
        BLNE    %FT50
        MOVNE   r1, r4
        BLNE    %FT50
        ADRNE   r1, %FT85
        BLNE    %FT50

        ; <rest of path>
        LDR     r1, [sp]
        BL      int_ConstructFullPathWithoutFSAndSpecial

        ; Store the return values
        STMIB   sp, {r2,r3}

        EXIT

50      ; Secure copy a string into the buffer - always accumulate the length, but
        ; not necessarily copy the string
        Push    "lr"
        RSB     r3, r3, #0
        BL      strlen_accumulate
        RSBS    r3, r3, #0
        Swap    r1, r2, GT
        BLGT    strcpy_advance
        Swap    r1, r2, GT
        Pull    "pc"

80
        DCB     "#", 0
85
        DCB     ":", 0
        ALIGN

;
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_ConstructFullPath
;
; In    r1 -> tail for directory
;       r2 -> buffer to construct path into
;       r3 = size of buffer
;       r6 = scb^/special field^
;       fscb^
;
; Out   r2 advanced to end of string in buffer
;       r3 reduced by length of string inserted, will be sent
;               negative to correct value for full string
;
int_ConstructFullPath Entry "r1,r2,r3,r4,r5"

        ; Get to root FS and special
        MOV     r3, #0
        BL      int_ConstructPathWithoutFS

        LDMIB   sp, {r2,r3}

        TEQ     r5, #Nowt
        BEQ     %FT10

        ; <fs>
        ADD     r1, r5, #fscb_name
        BL      %FT50

10
        ; : (if no special)
        TEQ     r4, #NULL
        TEQNE   r4, #Nowt
        ADREQ   r1, %FT85
        BLEQ    %FT50

        ; <rest of path>
        LDR     r1, [sp]
        BL      int_ConstructPathWithoutFS

        ; Store the return values
        STMIB   sp, {r2,r3}

        EXIT

50      ; Secure copy a string into the buffer - always accumulate the length, but
        ; not necessarily copy the string
        Push    "lr"
        RSB     r3, r3, #0
        BL      strlen_accumulate
        RSBS    r3, r3, #0
        Swap    r1, r2, GT
        BLGT    strcpy_advance
        Swap    r1, r2, GT
        Pull    "pc"

80
        DCB     "#", 0
85
        DCB     ":", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_ConstructFullPathWithError
;
; In    r1 -> tail for directory
;       r2 -> buffer to construct path into
;       r3 = size of buffer
;       r6 = scb^/special field^
;       fscb^
;
; Out   r2 advanced to end of string in buffer
;       r3 reduced by length of string inserted, will be sent
;               negative to correct value for full string
;       Buffer overflow error generated if r3<0 at the end
;
int_ConstructFullPathWithError Entry
        BL      int_ConstructFullPath
        CMP     r3, #0
        addr    r0, ErrorBlock_BuffOverflow, LT
        BLLT    CopyError
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_ConstructFullPathOnStack
;
; In    r1 -> tail
;       r6 = scb/special
;       fscb^
;
; Out
;       stack dropped by enough and hole filled in with path
;
int_ConstructFullPathOnStack Entry "r2,r3,r7"
        MOV     r7, sp
        MOV     r2, #ARM_CC_Mask
        MOV     r3, #0
        BL      int_ConstructFullPath
        RSB     r3, r3, #3+1            ; 3 for round-up, 1 for \0-terminator
        BIC     r3, r3, #3
        SUB     sp, sp, r3
        MOV     r2, sp
        BL      int_ConstructFullPath
        LDMIA   r7, {$Proc_RegList,pc}

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_CatExTitle
;
; In    r1 -> tail for directory
;       r6 = scb^/special field^
;       fscb^ set
;
MaxFilenameSpace * StaticName_length
int_CatExTitle Entry "r0-r5,fscb"
 [ debugcontrol
 DSTRING r1, "CatExTitle tail is "
 DREG r6, "scb^/special field^ is "
 DREG fscb, "fscb is "
 ]
        MOV     r5, sp
        BL      int_ConstructFullPathOnStack

        BL      faff_boot_option_startup_given
        BLVC    int_ReadBootOptionGiven
        MOVVS   sp, r5
        BVS     %FT95

        AND     r2, r2, #3
        TEQ     r2, #0
        ADREQ   r0, dirdotspace0
        TEQ     r2, #1
        ADREQ   r0, dirdotspace1
        TEQ     r2, #2
        ADREQ   r0, dirdotspace2
        TEQ     r2, #3
        ADREQ   r0, dirdotspace3

        MOV     r4, sp
        BL      message_write01
        MOV     sp, r5
        BVS     %FT95

        BL      XOS_NewLine_CopyError

        ; Convert to the root non-MultiFS
        BLVC    fscbscbTofscb
        MOVVC   fscb, r2

 [ debugcontrol
 DREG fscb, "Root fscb is "
 ]

        ; Current directory
        ADRVC   r0, csdspace
        ADRVC   r1, csdspaceu
        MOVVC   r2, #Dir_Current
        BLVC    DisplayDirectoryPath
        BLVC    XOS_NewLine_CopyError

        ; Current directory
        ADRVC   r0, libdotspace
        ADRVC   r1, libdotspaceu
        MOVVC   r2, #Dir_Library
        BLVC    DisplayDirectoryPath
        BLVC    XOS_NewLine_CopyError

        ; User root directory
        ADRVC   r0, urdspace
        ADRVC   r1, urdspaceu
        MOVVC   r2, #Dir_UserRoot
        BLVC    DisplayDirectoryPath
        BLVC    XOS_NewLine_CopyError

        EXIT

90
        ; Not enough stack for cat title
        addr    r0, ErrorBlock_NotEnoughStackForFSEntry
        BL      CopyError
        EXIT

95
        BL      CopyErrorExternal
        EXIT


dirdotspace0    DCB     "DDS0", 0
dirdotspace1    DCB     "DDS1", 0
dirdotspace2    DCB     "DDS2", 0
dirdotspace3    DCB     "DDS3", 0
csdspace        DCB     "CSDS", 0
csdspaceu       DCB     "CSDSU", 0
libdotspace     DCB     "LDS", 0
libdotspaceu    DCB     "LDSU", 0
urdspace        DCB     "URDS", 0
urdspaceu       DCB     "URDSU", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_CatExBody
;
; In    r0 = 0 for Cat, 1 for Ex, 2 for FileInfo
;       r1 -> path tail to supply to fs
;       r2 -> Wildcard to match names to
;       r6 = special field/scb^
;       fscb^
;
; Out   Directory catalogued

 [ CatExLong

; When long file names are in use, we vary the width of columns according to
; the length of the longest filename.  We also adjust the width for the length
; of the file name; we scan the directory twice.  The first time, we simply
; look at the length of the longest name.

CatExMinWidth   *       12              ; minimum amount to allocate for a name (8+'/'+3)

 ]

CatSpaceAdjustForNFS * -36
 [ CatExLong
CatSpace * 320
CatStringSpace * 400
 |
CatSpace * 280
CatStringSpace * 100
 ]

CatExBodyFrame  RN 9
        ^       0, CatExBodyFrame
CatExBody_EntryCount    # 4
CatExBody_ScreenWidth   # 4
CatExBody_LPos          # 4
CatExBody_PreGap        # 4
CatExBody_ItemsLeft     # 4
CatExBody_EntryRover    # 4
 [ CatExLong
CatExBody_EntryWidth    # 4     ; the width, in characters, of the longest filename to be displayed
 ]
CatExBody_FrameSize * :INDEX: @
CatExBody_CatExType     # 4     ; R0In
CatExBody_PathTail      # 4     ; R1In
CatExBody_WildCard      # 4     ; R2In
CatExBody_R3In          # 4
CatExBody_R4In          # 4
CatExBody_R5In          # 4
CatExBody_Special       # 4     ; R6In
CatExBody_R7In          # 4
CatExBody_R8In          # 4
CatExBody_R9In          # 4

CatExBody_WindBlock
        DCD     VduExt_WindowWidth
        DCD     -1

 [ CatExLong
CatExMaxWidthStr        = "FileSwitch$$NameWidth",0
        ALIGN
 ]

 [ CatExLong
int_CatExBody Entry "r0-r9", CatExBody_FrameSize
 |
int_CatExBody Entry "r0-r9", CatExBody_FrameSize
 ]
        MOV     CatExBodyFrame, sp
        SUB     sp, sp, #CatSpace + CatStringSpace

 [ debugcontrol
        DREG    r0, "int_CatExBody rc",cc
        DSTRING r1, " on ",cc
        DSTRING r2, " with wildcard "
 ]

        MOV     lr, #0
        STR     lr, CatExBody_EntryCount
        STR     lr, CatExBody_LPos
        STR     lr, CatExBody_PreGap

 [ CatExLong
        STR     lr, CatExBody_EntryWidth        ; store the initial maximum width of an entry
 ]
        ADR     r0, CatExBody_WindBlock
        ADR     r1, CatExBody_ScreenWidth
        SWI     XOS_ReadVduVariables
        BVS     %FT80

 [ CatExLong

; *** Here we scan the dir entries, to find the longest name.  Boring, but someone
;     has to do it.

        MOV     r4, #0          ; we don't need to use the stack frame so much here
05
        ; Read another set of directory entries
        MOV     r0, #fsfunc_ReadDirEntriesInfo
        LDR     r1, CatExBody_PathTail
        ADD     r2, sp, #CatStringSpace
        MOV     r3, #CatSpace + CatSpaceAdjustForNFS
        MOV     r5, #CatSpace + CatSpaceAdjustForNFS
        LDR     r6, CatExBody_Special

 [ debugcontrol
 DSTRING r1,"ReadDirEntriesInfo(",cc
 DREG r2,",",cc
 DREG r3,",",cc
 DREG r4,",",cc
 DREG r5,",",cc
 DREG r6,",",cc
 DLINE ")"
 ]
        BL      CallFSFunc_Given
 [ debugcontrol
 DREG r3,"...->(",cc
 DREG r4,",",cc
 DLINE ")"
 ]

        BVS     %FT85

        ; Where no items read?
        TEQ     r3, #0
        BEQ     %FT07

        MOV     r5, r3                          ; r5 used to count down entries in buffer

        ADD     r1, sp, #CatStringSpace         ; point r1 at the buffer

        LDR     r2, CatExBody_EntryWidth        ; width of an entry

        ADD     r1, r1, #&14                    ; point at string
06
        ; deal with another entry

        BL      strlen                          ; (r1->r3) get length of the string

        CMP     r3, r2                          ; is this name longer than the longest?
        MOVHI   r2, r3                          ; if so, then set new longest

        ADD     r1, r1, r3                      ; ptr to next entry
        ADD     r1, r1, #3+1+&14                ; and terminator and round to word, then onto string
        BIC     r1, r1, #3

        SUBS    r5, r5, #1                      ;

        BNE     %BT06                           ; if not then back round loop

        STR     r2, CatExBody_EntryWidth        ; store (maybe updated) width of entry

        CMP     r4, #-1                         ; go to the next stage
        BEQ     %FT08

        B       %BT05                           ; do some more entries

07
        ; No items read

        ; Was it the end?
        CMP     r4, #-1
        BEQ     %FT08                           ; if it was the end, then we can go to the next stage

        ; Wasn't end, so must be buffer overflow
        addr    r0, ErrorBlock_BuffOverflow
        BL      CopyError
        B       %FT85


08
        ; the next stage

        ; find out if there's a system variable with the entry width

        SUB     sp, sp, #16
        MOV     r2, #15
        MOV     r1, sp
        MOV     r3, #0
        MOV     r4, #3                          ; we want to convert it to a string (so that Macros will be sorted)

        ADR     r0, CatExMaxWidthStr            ; variable name

        SWI     XOS_ReadVarVal                  ; get the variable back

 [ debugcontrol
        DREG    r1, "ptr: "
 ]

        MOVVS   r2, #255                        ; maximum limit
        BVS     %FT09                           ; variable not found or too long - ignore it

        CMPS    r4, #1

        LDREQ   r2, [sp]
        BEQ     %FT09


        ; convert its value

        MOV     r0, #0                          ; terminate the string
        STRB    r0, [sp, r2]                    ;

        MOV     r0, #10+(1<<30)                 ; base 10, restrict range 0-255
        MOV     r1, sp

 [ debugcontrol
        DSTRING r1, "string: "
 ]

        SWI     XOS_ReadUnsigned                ; get the value

 [ debugcontrol
        DREG    r2, "converted to: "
 ]

        MOVVS   r2, #255

09      ; here, r2 should contain the max width, or zero
        ADD     sp, sp, #16

        CMPS    r2, #255
        MOVHI   r2, #255

        MOVS    r2, r2
        MOVMI   r2, #12

 [ debugcontrol
        DREG    r2, "init width: "
 ]


        LDR     r3, CatExBody_EntryWidth        ; get the width

        ; now compare screen with and entry width

        LDR     r0, CatExBody_ScreenWidth       ; width of screen

        LDR     r14, CatExBody_CatExType

        TEQ     r14, #0
        SUBEQ   r0, r0, #21-12
        TEQ     r14, #1
        SUBEQ   r0, r0, #63-12
        TEQ     r14, #2
        SUBEQ   r0, r0, #68-12

 [ debugcontrol
        DREG    r0, "width available from screen "

 ]
;       MOV     lr, #&6000
;       STMIA   lr, {r0,r2,r3}

        CMPS    r3, r0
        MOVGT   r3, r0

        CMPS    r3, r2                          ; set the min width
        MOVGT   r3, r2

        CMPS    r3, #CatExMinWidth              ; and if it's <12, make it 12
        MOVLT   r3, #CatExMinWidth

        STR     r3, CatExBody_EntryWidth        ; and now we have a width!

;       STR     r3, [lr, #12]

 [ debugcontrol
 DREG r3, "CatExBody_EntryWidth: "
 ]

        ; now that we've worked out the width, we do the whole thing
        ; again.  we should really optimise for the case where there's
        ; only one batch!

 ]

	MOV	r4, #0
	STR	r4, CatExBody_EntryCount

10
        ; Read another set of directory entries
        MOV     r0, #fsfunc_ReadDirEntriesInfo
        LDR     r1, CatExBody_PathTail
        ADD     r2, sp, #CatStringSpace
        MOV     r3, #CatSpace + CatSpaceAdjustForNFS
        LDR     r4, CatExBody_EntryCount
        MOV     r5, #CatSpace + CatSpaceAdjustForNFS
        LDR     r6, CatExBody_Special
 [ debugcontrol
 DSTRING r1,"ReadDirEntriesInfo(",cc
 DREG r2,",",cc
 DREG r3,",",cc
 DREG r4,",",cc
 DREG r5,",",cc
 DREG r6,",",cc
 DLINE ")"
 ]
        BL      CallFSFunc_Given
 [ debugcontrol
 DREG r3,"...->(",cc
 DREG r4,",",cc
 DLINE ")"
 ]
        BVS     %FT85

        STR     r4, CatExBody_EntryCount
        STR     r3, CatExBody_ItemsLeft

        ; Where no items read?
        TEQ     r3, #0
        BEQ     %FT75


        ADD     r1, sp, #CatStringSpace
20
        ; Fill the buffer on the stack

        ; pick out load, execute, length, Attributes, objecttype, advancing r1 to the object name
        LDMIA   r1!, {r2,r3,r4,r5,r6}
        STR     r1, CatExBody_EntryRover

        ; Is it a match?
        MOV     r0, r2
        LDR     r2, CatExBody_WildCard
        BL      WildMatch
        MOV     r2, r0
        BNE     %FT33

        LDR     r8, CatExBody_CatExType         ; r0 as passed in
        TEQ     r8, #2
        BNE     %FT25
        LDR     lr, [fscb, #fscb_info]
        TST     lr, #fsinfo_fileinfo
        BEQ     %FT25

        ; Filing system gets given FileInfo
        MOV     r7, sp
        BL      strlen
        MOV     r0, r1
        LDR     r1, CatExBody_PathTail
        BL      strlen_accumulate
        ADD     r3, r3, #1+1+3
        BIC     r3, r3, #3
        SUB     sp, sp, r3
        MOV     r2, r1
        MOV     r1, sp
        BL      strcpy_advance
        MOV     r2, #"."
        STRB    r2, [r1], #1
        MOV     r2, r0
        BL      strcpy_advance
        MOV     r0, #fsfunc_FileInfo
        MOV     r1, sp
        LDR     r6, CatExBody_Special
 [ debugcontrol
        DREG    r0, "Use filing system:",cc
        DSTRING r1,",",cc
        DSTRING r6,","
 ]
        BL      CallFSFunc_Given
        MOV     sp, r7
        BVS     %FT85
        B       %FT33

25
        MOV     r0, r6                          ; objecttype
        MOV     r6, sp                          ; Buffer start
        ADD     r7, r6, #CatStringSpace         ; Buffer end

        BL      AdjustObjectTypeReMultiFS
 [ CatExLong
        Push    "r10"
        LDR     r10, CatExBody_EntryWidth       ; get the width of the entry
  [ debugcontrol
        DREG    r10, "Width being used: "
  ]
 ]
        BL      int_CatExItem
 [ CatExLong
        Pull    "R10"
 ]
        BVS     %FT80

        ; Get width of string to output
        MOV     r1, sp
        BL      strlen

        ; Column width in r0
        LDR     r14, CatExBody_CatExType

 [ CatExLong
        LDR     r0, CatExBody_EntryWidth
        TEQ     r14, #0
        ADDEQ   r0, r0, #21-12
        TEQ     r14, #1
        ADDEQ   r0, r0, #63-12
        TEQ     r14, #2
        ADDEQ   r0, r0, #68-12
 |
        TEQ     r14, #0
        MOVEQ   r0, #21                 ; Cat column width
        TEQ     r14, #1
        MOVEQ   r0, #63                 ; Ex column width
        TEQ     r14, #2
        MOVEQ   r0, #68                 ; FileInfo column width
 ]

        ; r6{Spacing going to be needed} =
        ;       ((r7{position across line} + r8{at end of entry} + r0{column width} - 1)/r0{column width})*r0{column width} - r7{position across line}
        LDR     r7, CatExBody_LPos
        LDR     r8, CatExBody_PreGap
        ADD     r6, r7, r8
        ADD     r6, r6, r0
        SUB     r6, r6, #1
        DivRem  r5, r6, r0, r14, norem
        MUL     r6, r0, r5
        SUB     r6, r6, r7

        ; r5{new position if printed on this line} = r6{spacing} + r3{width} + r7{current position}
        ADD     r5, r6, r3
        ADD     r5, r5, r7

        ; If following a name and overflow a line, then do a line feed
        TEQ     r8, #0
        LDR     lr, CatExBody_ScreenWidth
        CMPNE   r5, lr
        BLS     %FT30
        SWI     XOS_NewLine
        BVS     %FT80
        MOV     r7, #0  ; position
        MOV     r8, #0  ; after an entry
        MOV     r6, #0  ; spacing

30
        ; position += spacing + width
        ADD     r7, r7, r6
        ADD     r7, r7, r3

        ; Spew out the spacing
        BL      SpewSpaces

        ; Display the item
        MOVVC   r0, sp
        SWIVC   XOS_Write0
        BVS     %FT80

        ; At end of item indicator (is inter-item gap)
        MOV     r8, #1

        STR     r7, CatExBody_LPos
        STR     r8, CatExBody_PreGap

33
        ; Advance to the next item (skip over the name and round up to a word)
        LDR     r1, CatExBody_EntryRover
        ADD     r3, r1, #1 + 3          ; 1 for the nul terminator, 3 for the rounding
        BL      strlen_accumulate
        BIC     r1, r3, #3

        ; Any more items in this batch?
        LDR     r3, CatExBody_ItemsLeft
        SUBS    r3, r3, #1
        STR     r3, CatExBody_ItemsLeft
        BNE     %BT20

        LDR     r4, CatExBody_EntryCount
        CMP     r4, #-1
        BNE     %BT10

50
        ; Successful completion of the body - tidy up the display

        ; If not at start of line, get to the start of line
        LDR     r8, CatExBody_PreGap
        TEQ     r8, #0
        SWINE   XOS_NewLine
        BVS     %FT80

        B       %FT85

75
        ; No items read

        ; Was it the end?
        LDR     r4, CatExBody_EntryCount
        CMP     r4, #-1
        BEQ     %BT50

        ; Wasn't end, so must be buffer overflow
        addr    r0, ErrorBlock_BuffOverflow
        BL      CopyError
        B       %FT85

80
        ; External error - copy it
        BL      CopyErrorExternal

85
        MOV     sp, CatExBodyFrame
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SpewSpaces
;
; In    r6 = number of spaces to spew
;
; Out   spaces spewed (r0, VS error return mechanism)
;
SpewSpaces Entry "r6"
        B       %FT20
10
        SWI     XOS_WriteI+space
        EXIT    VS
20
        SUBS    r6, r6, #1
        BPL     %BT10
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_CatExItem
;
; In    r0 = object type
;       r1 ->name
;       r2 = load address
;       r3 = execute address
;       r4 = length
;       r5 = attributes
;       r6 = Buffer start
;       r7 = buffer end (beyond end of usable buffer space)
;       r8 = number of control string:
;               0 - CatFormat
;               1 - ExFormat
;               2 - FileInfoFormat

 [ CatExLong
;       r10 = width of a filename field
 ]
;
; Out   r0, VS error return mechanism

CatFormat       DCB "Cat",0
ExFormat        DCB "Ex",0
FileInfoFormat  DCB "FileInfo",0
        ALIGN

 [ CatExLong
int_CatExItem Entry     "r0-r9"
 |
int_CatExItem Entry     "r0-r9"
 ]
        TEQ     r8, #0
        ADREQ   r0, CatFormat
        TEQ     r8, #1
        ADREQ   r0, ExFormat
        TEQ     r8, #2
        ADREQ   r0, FileInfoFormat
        BL      message_lookup
        BVS     %FT40

        MOV     r8, r0
        LDR     r0, [sp, #Proc_LocalStack + 0*4]

        LDRB    r9, [r8], #1
        CMP     r9, #" "
        BHI     %FT20
        B       %FT30

10
        ; Space between items
        MOV     r0, #space
        BL      int_StuffByteIntoBuffer

20
 [ debugcontrol
        DREG    r9, "Stuffing a number "
 ]

        ; Place the text of this item into the buffer
        LDR     r0, [sp, #Proc_LocalStack + 0*4]        ; r0 in
        TEQ     r9, #"0"
        BLEQ    int_StuffFilenameIntoBuffer
        TEQ     r9, #"1"
        BLEQ    int_StuffAttsIntoBuffer
        TEQ     r9, #"2"
        BLEQ    int_StuffLoadExecIntoBuffer
        TEQ     r9, #"3"
        BLEQ    int_StuffFileSizeIntoBuffer
        TEQ     r9, #"4"
        BLEQ    int_StuffExactLoadExecIntoBuffer
        TEQ     r9, #"5"
        BLEQ    int_StuffExactFileSizeIntoBuffer

        BVS     %FT40

        ; Advance to next item
        LDRB    r9, [r8], #1
        CMP     r9, #space
        BHI     %BT10

30
        ; Terminate the buffer
        MOV     r0, #0
        BL      int_StuffByteIntoBuffer

40
        STRVS   r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffFilenameIntoBuffer
;
; In    r1 ->name
;       r6 = buffer
;       r7 = buffer end (beyond end of usable buffer space)

 [ CatExLong
;       r10 = width of field
 ]
;
; Out   r6 advanced or error (r0,VS errors)
;
int_StuffFilenameIntoBuffer Entry "r3"
 [ CatExLong
  [ debugcontrol
	DREG	r10, "stuffing width: "
  ]
        MOV     r3, r10
        BL      int_StuffRPaddedMaybeTruncatedStringIntoBuffer
 |
        MOV     r3, #12
        BL      int_StuffRPaddedStringIntoBuffer
 ]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffAttsIntoBuffer
;
; In    r0 = object type
;       r5 = attributes
;       r6 = buffer
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
int_StuffAttsIntoBuffer Entry "r0,r3", 8
        MOV     r3, sp

        ; D
        TST     r0, #object_directory
        MOVNE   r0, #"D"
        STRNEB  r0, [r3], #1

        ; L
        TST     r5, #locked_attribute
        MOVNE   r0, #"L"
        STRNEB  r0, [r3], #1

        ; W
        TST     r5, #write_attribute
        MOVNE   r0, #"W"
        STRNEB  r0, [r3], #1

        ; R/
        TST     r5, #read_attribute
        MOVNE   r0, #"R"
        STRNEB  r0, [r3], #1
        MOV     r0, #"/"
        STRB    r0, [r3], #1

        ; W
        TST     r5, #public_write_attribute
        MOVNE   r0, #"W"
        STRNEB  r0, [r3], #1

        ; R
        TST     r5, #public_read_attribute
        MOVNE   r0, #"R"
        STRNEB  r0, [r3], #1

        MOV     r0, #0
        STRB    r0, [r3], #1

        MOV     r3, #7
        MOV     r1, sp
        BL      int_StuffRPaddedStringIntoBuffer

        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffLoadExecIntoBuffer
;
; In    r0 = object type
;       r2 = load address
;       r3 = execute address
;       r6 = Buffer start
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
ExDateFormat DCB "ExDt",0
ExLoadExecFormat DCB "ExLdEx",0
        ALIGN

int_StuffLoadExecIntoBuffer Entry "r4,r5"
        ADR     r4, ExDateFormat
        ADR     r5, ExLoadExecFormat
        BL      int_GenStuffLoadExecIntoBuffer
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffExactLoadExecIntoBuffer
;
; In    r0 = object type
;       r2 = load address
;       r3 = execute address
;       r6 = Buffer start
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
FileInfoDateFormat DCB "FileInDt",0
FileInfoLoadExecFormat DCB "FileInLdEx",0
        ALIGN

int_StuffExactLoadExecIntoBuffer Entry "r4,r5"
        ADR     r4, FileInfoDateFormat
        ADR     r5, FileInfoLoadExecFormat
        BL      int_GenStuffLoadExecIntoBuffer
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_GenStuffLoadExecIntoBuffer
;
; In    r0 = object type
;       r2 = load address
;       r3 = execute address
;       r4 = tag of date format
;       r5 = tag of load+exec format
;       r6 = Buffer start
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
DirText DCB "Dr",0
        ALIGN

int_GenStuffLoadExecIntoBuffer Entry "r0-r4",24

        ; Is it a directory?
        TST     r0, #object_directory
        BEQ     %FT10

        ; It's a directory - output "Directory"
        ADR     r0, DirText
        BL      message_lookup
        MOVVC   r1, r0
        B       %FT20

10
        ; Handling of files
        BL      IsFileTyped
        addr    r1, anull, NE   ; No text in the type field if untyped
        BNE     %FT20

        ; It's typed - display type then date
        BL      ExtractFileType
        BL      DecodeFileType
        BVS     %FT90

        STMVCIA sp, {r2,r3}
        MOVVC   r1, #0
        STRVCB  r1, [sp, #8]
        MOVVC   r1, sp

20
        ; Copy the type to the type field
        MOVVC   r3, #9
        BLVC    int_StuffRPaddedStringIntoBuffer
        MOVVC   r0, #space
        BLVC    int_StuffByteIntoBuffer
        BVS     %FT90

        LDR     r2, [sp, #Proc_LocalStack + 2*4]
        LDR     r3, [sp, #Proc_LocalStack + 3*4]
        BL      IsFileTyped
        BNE     %FT40

        ; Display the date. Reverse order of words to correct byte ordering of date
        STR     r3, [sp, #0*4]
        STR     r2, [sp, #1*4]

        MOV     r0, r4
        BL      message_lookup
        BVS     %FT90

 [ debugcontrol
        DSTRING r0,"Looked up date format OK:"
 ]

        ; faff faff faff: copy the string to be nul-terminated
        MOV     r1, r0
        BL      strlen
        ADD     r4, r3, #1 + 3
        BIC     r4, r4, #3
        SUB     sp, sp, r4
        MOV     r2, r1
        MOV     r1, sp
        BL      strcpy          ; nul terminates

        MOV     r3, r1
        ADD     r0, sp, r4
        MOV     r1, r6
        SUB     r2, r7, r6
        SWI     XOS_ConvertDateAndTime
        ADD     sp, sp, r4
        MOVVC   r6, r1

        B       %FT90

40
        ; It's untyped - display as hex

        ; Convert the hex numbers into text
        MOV     r0, r2
        MOV     r1, sp
        MOV     r2, #12
        SWI     XOS_ConvertHex8
        MOVVC   r0, r3
        ADDVC   r1, sp, #12
        MOVVC   r2, #12
        SWIVC   XOS_ConvertHex8

        ; Now stuff the buffer with the hex numbers
        MOVVC   r0, r5
        MOVVC   r1, r6
        SUBVC   r2, r7, r6
        MOVVC   r4, sp
        ADDVC   r5, sp, #12
        BLVC    message_lookup22_into_buffer
        MOVVC   r6, r1

90
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffFileSizeIntoBuffer
;
; In    r4 = length
;       r6 = Buffer start
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
int_StuffFileSizeIntoBuffer Entry "r0-r2"
        MOV     r0, r4
        MOV     r1, r6
        SUB     r2, r7, r6
        SWI     XOS_ConvertFixedFileSize
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        MOVVC   r6, r1
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffExactFileSizeIntoBuffer
;
; In    r4 = length
;       r6 = Buffer start
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
int_StuffExactFileSizeIntoBuffer Entry "r0-r2"
        MOV     r0, r4
        MOV     r1, r6
        SUB     r2, r7, r6
        SWI     XOS_ConvertHex8
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        MOVVC   r6, r1
        EXIT

 [ {FALSE}
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffLPaddedStringIntoBuffer
;
; In    r1 ->name
;       r3 = required width
;       r6 = buffer
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
; Stuffs the name into the buffer padded to width
;
int_StuffLPaddedStringIntoBuffer Entry "r3"
        BL      strlen_accumulate
        RSBS    r3, r3, #0
        MOVLO   r3, #0
        BL      int_StuffSpacesIntoBuffer
        EXIT    VS
        BL      int_StuffStringIntoBuffer
        EXIT
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffRPaddedStringIntoBuffer
;
; In    r1 ->name
;       r3 = required width
;       r6 = buffer
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
; Stuffs the name into the buffer padded to width
;
int_StuffRPaddedStringIntoBuffer Entry "r3"
        RSB     r3, r3, #0
        BL      strlen_accumulate
        BL      int_StuffStringIntoBuffer
        EXIT    VS
        RSBS    r3, r3, #0
        MOVHI   r3, #0
        BL      int_StuffSpacesIntoBuffer
        EXIT

 [ CatExLong
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffRPaddedMaybeTruncatedStringIntoBuffer
;
; In    r1 ->name
;       r3 = required width
;       r6 = buffer
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
; Stuffs the name into the buffer padded to width.  If the string's
; longer than the buffer width, it truncates it.
;
int_StuffRPaddedMaybeTruncatedStringIntoBuffer Entry "r3,r4"
        MOV     r4, r3
        BL      strlen                  ; string length in R3
        CMP     r3, r4
        BHI     %FT10
        SUB     r3, r3, r4
        BL      int_StuffStringIntoBuffer
        EXIT    VS
        RSBS    r3, r3, #0
        MOVHI   r3, #0
        BL      int_StuffSpacesIntoBuffer
        EXIT

10
        MOV     r3, r4
        BL      int_StuffRTruncatedStringIntoBuffer
        EXIT
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffSpacesIntoBuffer
;
; In    r1 ->name
;       r3 = required number of spaces
;       r6 = buffer
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced or error (r0,VS errors)
;
; Stuffs the given number of spaces into the buffer
;
int_StuffSpacesIntoBuffer Entry "r0,r3"
        MOV     r0, #space
        B       %FT20
10
        BL      int_StuffByteIntoBuffer
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT    VS
20
        SUBS    r3, r3, #1
        BGE     %BT10           ; Signed
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffStringIntoBuffer
;
; In    r1 = string (ctrl char terminated)
;       r6 = Buffer start
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced by string length, or error (r0,VS)
;       terminator not placed into buffer
;
int_StuffStringIntoBuffer Entry "r0,r1"
        B       %FT20
10
        BL      int_StuffByteIntoBuffer
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT    VS
20
        LDRB    r0, [r1], #1
        CMP     r0, #space-1
        TEQHI   r0, #delete
        BHI     %BT10
        EXIT

 [ CatExLong
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffRTruncatedStringIntoBuffer
;
; In    r1 = string (ctrl char terminated)
;       r3 = number of characters to print (including '...')
;       r6 = Buffer start
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced by string length, or error (r0,VS)
;       terminator not placed into buffer
;
int_StuffRTruncatedStringIntoBuffer Entry "r0,r1,r3"
        SUB     r3, r3, #3
        B       %FT20
10
        BL      int_StuffByteIntoBuffer
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT    VS
20
        SUBS    r3, r3, #1
        BMI     %FT30
        LDRB    r0, [r1], #1
        CMP     r0, #space-1
        TEQHI   r0, #delete
        BHI     %BT10
        EXIT

30 ; just termination to deal with
        MOV     r0, #'.'
        BL      int_StuffByteIntoBuffer
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT    VS
        MOV     r0, #'.'
        BL      int_StuffByteIntoBuffer
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT    VS
        MOV     r0, #'.'
        BL      int_StuffByteIntoBuffer
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT

 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; int_StuffByteIntoBuffer
;
; In    r0 = byte
;       r6 = Buffer start
;       r7 = buffer end (beyond end of usable buffer space)
;
; Out   r6 advanced by 1, or error (r0,VS)
;
int_StuffByteIntoBuffer Entry "r0"
        CMP     r6, r7
        STRLOB  r0, [r6], #1
        EXIT    LO
        addr    r0, ErrorBlock_BuffOverflow
        BL      copy_error
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Process_WildPathnameMustExist
;
; In    r1 -> Wildcarded pathname
;
; Out   r0 = object type of 1st of the objects
;       r1 -> Pathtail for object or directory for enumeration as appropriate
;       r2 = load address of the 1st of the objects
;       r3 = execute address of the 1st of the objects
;       r4 = length of the 1st of the objects
;       r5 = attributes of the 1st of the objects
;       r6 = scb^/special field^
;       r7 = NULL or wildcard for enumeration
;       fscb^
;
; PassedFilename, FullFilename and SpecialField are the relevant locations
; for the various parts after processing.
;
; Will generate an error if the object doesn't exist
;
Process_WildPathnameMustExist Entry
        BL      Process_WildPathname
        EXIT    VS
        TEQ     r0, #object_nothing
        EXIT    NE
        LDR     r1, PassedFilename
        BL      SetMagicPlainNotFound
        BL      JunkFileStrings
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Process_WildPathname
;
; In    r1 -> Wildcarded pathname
;
; Out   r0 = object type of 1st of the objects
;       r1 -> Pathtail for object or directory for enumeration as appropriate
;       r2 = load address of the 1st of the objects
;       r3 = execute address of the 1st of the objects
;       r4 = length of the 1st of the objects
;       r5 = attributes of the 1st of the objects
;       r6 = scb^/special field^
;       r7 = NULL or wildcard for enumeration
;       fscb^
;
; PassedFilename, FullFilename and SpecialField are the relevant locations
; for the various parts after processing.
;
Process_WildPathname ALTENTRY

        ADR     r0, PassedFilename
        MOV     r2, #NULL
        addr    r3, anull
        ADR     r4, FullFilename
        MOV     r5, #0
        ADR     r6, SpecialField
        BL      TopPath_DoBusinessToPath
        EXIT    VS

        ; Reject case with no filing system
        TEQ     fscb, #Nowt
        LDREQ   r1, PassedFilename
        BLEQ    SetMagicPlainNotFound
        BLVS    JunkFileStrings
        EXIT    VS

        ; Is it an absolute directory?
        Push    "r0,r3"
        BL      strlen
        SUB     r3, r3, #1
        LDRB    r0, [r1, r3]
        BL      IsAbsolute
        Pull    "r0,r3"
        BEQ     %FT70

        ; It's a non-absolute, check the source leaf for wildness

        LDR     r7, PassedFilename
 [ debugutil
        DSTRING r7, "PassedFilename = "
 ]
        Push    "r1,r3"
        MOV     r1, r7
        BL      strlen
        ADD     r8, r7, r3
        Pull    "r1,r3"

10
        LDRB    r14, [r8], #-1
        TEQ     r14, #"*"
        TEQNE   r14, #"#"
        BEQ     %FT30
        TEQ     r14, #"."
        TEQNE   r14, #":"       ; blah:blah or blah::blah, neither of which are wildcards
        BEQ     %FT70
        CMP     r8, r7
        BHS     %BT10
        B       %FT70

20
        ; A wildcard char has been found, continue and see whether it's a leaf name
        ; or just a wierd disc name.
        LDRB    r14, [r8], #-1
        TEQ     r14, #"."
        BEQ     %FT40
        TEQ     r14, #":"
        BNE     %FT30
        CMP     r8, r7
        BLO     %FT70           ; It's just :<wierd disc name>
        LDRB    r14, [r8]
        TEQ     r14, #":"
        BEQ     %FT70           ; It's <thing>::<wierd disc name>
        MOV     r14, #":"
        B       %FT40           ; It's <thing>:<wildcard>
30
        CMP     r8, r7
        BHS     %BT20
40
        ; Confirmed wildleaf found with r8 before string or before preceding . or :
        TEQ     r14, #"."
        TEQNE   r14, #":"
        ADDEQ   r7, r8, #2
        ADDNE   r7, r8, #1

        ; Chop off the leaf from the path tail
        BL      strlen
        ADD     r8, r1, r3
50
        LDRB    r14, [r8, #-1]!
        TEQ     r14, #"."
        MOVEQ   r14, #0
        STREQB  r14, [r8]
        EXIT    EQ
        CMP     r8, r1
        BHI     %BT50

        ; If haven't come to a ., but have come to start of string
        ; then must be tail for MultiFS, so chop it there.
        MOV     r14, #0
        STRB    r14, [r8]
        EXIT

70
        ; It's an absolute or non-wildcard, so
        ; let's do it singularly
        MOV     r7, #NULL
        EXIT

        END
