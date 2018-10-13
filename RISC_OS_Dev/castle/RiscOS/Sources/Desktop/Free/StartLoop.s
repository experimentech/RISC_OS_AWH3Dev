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
; > s.StartLoop

; -----------------------------------------------------------------------------
;      Application title and 'TASK' word store
taskidentifier  DCB     "TASK"
                ALIGN

; -----------------------------------------------------------------------------
;       Set up error blocks

        MakeInternatErrorBlock WimpNotPresent,,NoWimp     ; "Window Manager not present"

ErrorOldWimp
        SWI     XWimp_CloseDown
        SWI     XOS_WriteI+4            ; just in case (old Wimp!)
        ADR     r0, ErrorBlock_WimpNotPresent
        MOV     r1, #0
        BL      LookupError

ErrorNoWimp
        SWI     OS_GenerateError        ; can't use Wimp to report error!

CloseWimp

        EntryS  "r0"
        LDR     r0, mytaskhandle        ; Get task handle
        LDR     r1, taskidentifier
        SWI     XWimp_CloseDown
        EXITS

; -----------------------------------------------------------------------------
template_file   DCB     "Free:Templates",0
                ALIGN
window_name     DCB     "Free",0
                ALIGN
task_token      DCB     "Title",0
                ALIGN
title_prefix    DCB     "FSP",0
                ALIGN
units_token     DCB     "bytes",0
                ALIGN
MessagesList    DCD     Message_Quit
                DCD     0

; -----------------------------------------------------------------------------
;       Start up the wimp task for Free
Start
        LDR     r12, [r12]              ; get workspace pointer

        ADRL    r0, ErrorBlock_CantStartFree
        MOV     r1, #0
        MOV     r2, #0
        ADRL    r4, Title
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0

        LDR     r14, mytaskhandle       ; abort if not responding to desktop starting stuff
        CMP     r14, #-1
        SWINE   XMessageTrans_ErrorLookup
        SWIVS   OS_GenerateError

        ADRL    sp, stacktop            ; STACK IS NOW VALID!

        ADR     r0, units_token
        BL      Lookup_InPlace
        MOVVC   r4, r0
        ADRVS   r4, units_token         ; the token happens to be the english default too
        ADR     r0, message_bytes
        MOV     r3, #?message_bytes-1
        BL      copy_r0r4r3_space       ; cache the 'bytes' suffix

        ADR     r0,task_token
        BL      Lookup_InPlace
        SWIVS   OS_GenerateError
        MOV     r2,r0

        LDR     r0, =310                ; We know about wimp 3.10 and have a messages list
        LDR     r1, taskidentifier
        ADR     r3, MessagesList
        SWI     XWimp_Initialise
        LDR     r3, =310                ; Wimp version number that we want.
        CMP     r0,r3                   ; needs Wimp with Wimp_PollWord, draggable iconbar icons
                                        ; and Iconize and close window messages.
        BCC     ErrorOldWimp

        STR     r1, mytaskhandle        ; Store task handle

        ADR     r1, template_file       ; Load in the templates
        SWI     XWimp_OpenTemplate
        BLVS    CloseWimp
        SWIVS   OS_GenerateError

        ADR     r1, windowarea                ; Get template for window into memory.
        LDR     r2, =indirected_data_offset
        ADD     r2,r2,r12
        ADD     r3, r2, #?indirected_data
        MOV     r4, #-1                     ; No font array
        ADR     r5, window_name             ; Name of window.
        MOV     r6, #0                      ; Search from first template.
        SWI     XWimp_LoadTemplate
        BLVS    CloseWimp
        SWIVS   OS_GenerateError

        SWIVC   XWimp_CloseTemplate


        ADR     r1,windowarea+88
        LDR     r0,[r1,#-4]
        Debug   xx,"number of icons is: ",r0

        ADD     r1,r1,#icon_SizeBar :SHL: icon_shift
        LDR     r0,[r1,#8]
        LDR     r1,[r1,#0]
        SUB     r0,r0,r1
        STR     r0,full_bar                 ; Size of 100% Bar.

        Debug   xx,"Full bar size is ",r0

        MOV     r0,#0
        STR     r0,poll_word

; -----------------------------------------------------------------------------
;       Wimp polling routine
repollwimp
        BVC     %FT01
        Push    "r0"
        ADRL    R0,task_token
        MOV     r2,r0                   ; Just in case !
        BL      Lookup_InPlace
        ADDVS   sp,sp,#4
        MOVVC   r2,r0
        Pull    "r0",VC
        MOV     R1,#6                   ; Cancel box
        SWI     XWimp_ReportError

01

; Call Wimp_Poll.
        MOV     R0, #&31
        ORR     R0, R0, #&400000        ; Poll word (low priority)
        ADR     r3, poll_word
        ADR     R1,dataarea
        SWI     XWimp_Poll              ; can't call non-X form
        BVS     repollwimp

; Call the appropriate routine using a fast jump table
        ADR     LR,repollwimp
        CMP     R0,#(endjptable-jptable)/4
        ADDCC   PC,PC,R0,ASL #2
        MOV     PC,LR
jptable
        MOV     PC,LR                   ;  0  null reason
        MOV     PC,LR                   ;  1  redraw window
        B       open_window             ;  2  open window
        B       close_window            ;  3  close window
        MOV     PC,LR                   ;  4  pointer leaving window
        MOV     PC,LR                   ;  5  pointer entering window
        MOV     PC,LR                   ;  6  mouse click.
        MOV     PC,LR                   ;  7  drag box complete
        MOV     PC,LR                   ;  8
        MOV     PC,LR                   ;  9  menu_select
        MOV     PC,LR                   ; 10
        MOV     PC,LR                   ; 11
        MOV     PC,LR                   ; 12
        B       update_windows          ; 13  poll word non-zero
        MOV     PC,LR                   ; 14
        MOV     PC,LR                   ; 15
        MOV     PC,LR                   ; 16
        B       message_received        ; 17
        B       message_received_ack    ; 18
        MOV     PC,LR                   ; 19
endjptable

; -----------------------------------------------------------------------------
open_window
        SWI     Wimp_OpenWindow
        MOV     PC,LR

; -----------------------------------------------------------------------------
close_window_from_block
        EntryS  "r1-r5"

        ADR     r1,dataarea
        LDR     r2,[r5,#window_handle]
        STR     r2,[r1]

        B       int_close_window
close_window
        ALTENTRY
int_close_window
        SWI     Wimp_DeleteWindow       ; 14 Jul 92 OSS Used to be Close

        ADR     r0,windows_ptr
01
        LDR     r0,[r0,#next_ptr]
        CMP     r0,#0
        EXIT    EQ

        LDR     r2,[r0,#window_handle]
        LDR     r14,[r1]
        CMP     r14,r2
        BNE     %BT01

        LDR     r1,[r0,#next_ptr]
        LDR     r2,[r0,#prev_ptr]
        CMP     r1,#0
        STRNE   r2,[r1,#prev_ptr]
        CMP     r2,#0
        STRNE   r1,[r2,#next_ptr]
        STREQ   r1,windows_ptr            ; Unlinked from list.

        MOV     r5,r0

        LDR     r2,[r0,#window_discname]
        MOV     r0,#ModHandReason_Free
        SWI     XOS_Module
        EXIT    VS

        Debug   xx,"Freed space"

        MOV     r0,#ModHandReason_Free
        MOV     r2,r5
        SWI     XOS_Module
        EXIT    VS

        Debug   xx,"Freed block."

        EXITS

; -----------------------------------------------------------------------------
; This is called when the poll word is non-zero, it scans the window list
; to find out which windows are to be updated, and updates them.
;

icon_shift           *  5

update_windows

        Push    "LR"

        Debug   xx,"Poll word non zero"

        MOV     r3,#0
        STR     r3, poll_word           ; Clear poll word.

        ADR     r5,windows_ptr
updatelp
        LDR     r5,[r5,#next_ptr]
updatelp1
        CMP     r5,#0
        Pull    "PC",EQ            ; Updated all windows.

        LDR     r0,[r5,#window_update]
        CMP     r0,#0
        BEQ     updatelp           ; Unchanged.

        Debug   xx,"Window updated."

        LDR     r0,[r5,#window_handle]
        CMP     r0,#-1
        BNE     just_update        ; Window already exists.

        Debug   xx,"New window"

        LDR     r0,[r5,#window_namelength]

        ADD     r3,r0,#60          ; Get length
        ADD     r3,r3,#&100
        MOV     r0,#ModHandReason_Claim
        SWI     XOS_Module         ; Claim space to hold name. + 3 sizes.
        Pull    "PC",VS

        ADRL    r0,title_prefix
        LDR     r4,[r5,#window_device]
        BL      Lookup
        Pull    "PC",VS
        ADD     r3,r3,#1
        STR     r3,[r5,#window_namelength]
        Debug   xx,"Length returned from lookup is ",r3

        ADR     r1,windowarea+72   ; Point at title data
        STR     r2,[r1]            ; Set it to point at name.
        STR     r2,[r5,#window_discname]
        LDR     r0,[r5,#window_namelength]
        STR     r0,[r1,#8]         ; Length of name.
        Debug   xx,"title length is ",r0
        ADR     r1,windowarea+88
        ADD     r2,r2,r0           ; Start of first data area.
        STR     r2,[r1,#20+icon_Size :SHL: icon_shift]
        ADD     r2,r2,#20          ; Start of second data area.
        STR     r2,[r1,#20+icon_Free :SHL: icon_shift]
        ADD     r2,r2,#20          ; Start of third data area.
        STR     r2,[r1,#20+icon_Used :SHL: icon_shift]


        MOV     r0,#-1             ;init the cached values so they'll always change the first time
        STR     r0,[r5,#window_size_lo]
        STR     r0,[r5,#window_free_lo]
        STR     r0,[r5,#window_used_lo]
        STR     r0,[r5,#window_size_hi]
        STR     r0,[r5,#window_free_hi]
        STR     r0,[r5,#window_used_hi]
  [ fix_silly_sizes
        MOV     r0,#'?' :SHL: 24
        STR     r0,[r5,#used_ascii]
        STR     r0,[r5,#free_ascii]
        STR     r0,[r5,#size_ascii]
  ]

        ; Centre window on mouse pointer
        ADR     r1,dataarea
        ADR     r2,windowarea
        SWI     XWimp_GetPointerInfo
        ADR     r2,windowarea
        LDR     r3,[r2,#w_wax0]
        LDR     r4,[r2,#w_wax1]
        SUB     r4,r4,r3
        LDR     r0,[r1]
        SUB     r3,r0,r4,LSR #1    ; Mouse pos - 1/2 window size
        ADD     r4,r4,r3
        STR     r3,[r2,#w_wax0]
        STR     r4,[r2,#w_wax1]

        LDR     r3,[r2,#w_way0]
        LDR     r4,[r2,#w_way1]
        SUB     r4,r4,r3
        LDR     r0,[r1,#4]
        SUB     r3,r0,r4,LSR #1    ; Mouse pos - 1/2 window size
      [ {TRUE}
        MOV     r0,#-2
        STR     r0,[r1]
        SWI     XWimp_GetWindowState
        LDR     r0,[r1,#16]        ; top of icon bar
        ADD     r0,r0,#4
        CMP     r3,r0
        MOVLT   r3,r0              ; ensure we're clear of the icon bar
      ]
        ADD     r4,r4,r3
        STR     r3,[r2,#w_way0]
        STR     r4,[r2,#w_way1]

        ADR     r1,windowarea
        SWI     XWimp_CreateWindow ; Create the window
        Pull    "PC",VS
        STR     r0,[r5,#window_handle]

        Debug   xx,"Window created."


just_update                        ; Window has changed, update it.

        Debug   xx,"Update window"

        LDR     r0,[r5,#window_update]
        TST     r0,#1 :SHL: 30
        BEQ     %FT01

        ADR     r1,dataarea
        LDR     r0,[r5,#window_handle]
        STR     r0,[r1]
        LDR     r5,[r5,#next_ptr]
        BL      close_window
        B       updatelp1

01      TST     r0,#1 :SHL: 31
        MOV     r0,#0
        STR     r0,[r5,#window_update]
        BEQ     %FT01

        Debug   xx,"Open at front"

        LDR     r0,[r5,#window_handle]
        ADR     r1,dataarea
        STR     r0,[r1]
        SWI     XWimp_GetWindowState
        Pull    "PC",VS
        ADR     r1,dataarea
        MOV     r0,#-1
        STR     r0,[r1,#28]        ; Open at front.
        SWI     XWimp_OpenWindow
        Pull    "PC",VS

        Debug   xx,"Window re-opened"

01
        ;amg: first, we try to treat this as a 64 bit aware filing system. If this fails,
        ;we then use the 32 bit getspace reason code, but still need to mangle it into the
        ;internal 64 bit layout.

        ;data layout
        ;old 00 size    new 00 size low
        ;    04 free        04 size high
        ;    08 used        08 free low
        ;                   0c free high
        ;                   10 used low
        ;                   14 used high

        MOV     r0,#0
        STR     r0,[r5,#no_change]

        MOV     r0,#FreeReason_GetSpace64
        LDR     r1,[r5,#window_fs]
        ADR     r2,dataarea
        LDR     r3,[r5,#window_device]
        BL      CallEntry

        ; if there was an error, R0 will NOT be zero.

        CMP     r0,#0                    ; if successful R0 zeroed as well as filling in the block
        BEQ     %FT09

        MOV     r0,#FreeReason_GetSpace
        BL      CallEntry                ; [r2] = Size, Free , Used
        Push    "r0",VS
        BLVS    close_window_from_block
        Pull    "r0,PC",VS

        ;move the data returned into the new layout

        LDMIB   r2,{r1,r6}
        STR     r1,[r2,#8]               ; move free to free_low
        STR     r6,[r2,#16]              ; move used to used_low
        MOV     r0,#0
        STR     r0,[r2,#4]
        STR     r0,[r2,#12]
        STR     r0,[r2,#20]              ; zero the high words

09
   [ fix_silly_sizes
        ; R0, R1, R6, R7 Corruptable
        LDMIA   r2, {r0,r1,r6,r7}        ; r0=size.l, r1=size.h, r6=free.l, r7=free.h
        ; check free size
        CMP     r7,r1
        CMPEQ   r6,r0                    ; Free > Size ::= fault
        MOVHI   r7,#-1
        STRHI   r7,[r2,#12]
        STRHI   r7,[r2,#8]

        ; check used size
        ADD     r6,r2,#16
        LDMIA   r6, {r6,r7}              ; r6=used.l, r6=used.h
        CMP     r7,r1
        CMPEQ   r6,r0                    ; Used > Size ::= fault
        MOVHI   r7,#-1
        STRHI   r7,[r2,#20]
        STRHI   r7,[r2,#16]
   |
        LDMIA   r2, {r0,r1}              ; r0=size.l, r1=size.h
   ]
        ADD     lr,r5,#window_size_lo
        LDMIA   lr,{r6,r7}
        CMP     r7,r1
        CMPEQ   r6,r0
        BEQ     %FT01                    ; Size unchanged

        STR     r13,[r5,#no_change]      ; set the flag to indicate that the textual fields need rewriting

        LDR     r0,[r2,#4]               ; Size high
        LDR     r1,[r5,#window_size_hi]
        ;r0 =new_size_high, r1=old_size_high

        STR     r0,[r5,#window_size_hi]  ; store size high in window block

        ;r7 =new_size_low, r6=old_size_low

        LDR     r6,[r5,#window_size_lo]
        LDR     r7,[r2,#0]
        STR     r7,[r5,#window_size_lo]  ; and size low

        ;r8 = size_low, r2 = size_high

        LDR     r8,[r2,#0]

        LDR     r2,[r2,#4]

        ;r0 new size high
        ;r1 old size high
        ;r2 size high
        ;r6 old size low
        ;r7 new size low
        ;r8 size low

        MOV     r3,#icon_SizeBar
        BL      set_bar
        Pull    "PC",VS

        LDR     r0,[r5,#window_size_lo]
        LDR     r1,[r5,#window_size_hi]
        BL      create_size_word
        STR     r0,[r5,#size_ascii]

        ; the actual call to set_text is saved until later now

01
        ADR     r2,dataarea
        LDR     r0,[r2,#8]               ; Free
        LDR     r1,[r5,#window_free_lo]
        CMP     r0,r1
        BNE     %FT02
        LDR     r0,[r2,#12]
        LDR     r1,[r5,#window_free_hi]
        CMP     r0,r1
        BEQ     %FT01                    ; Size Unchanged.
02
        STR     r13,[r5,#no_change]     ; set flag to indicate the ascii fields need reconsidering

        LDR     r0,[r2,#12]
        LDR     r1,[r5,#window_free_hi]
        ;r0=new_free_hi, r1=old_free_hi

        STR     r0,[r5,#window_free_hi]

        ;r7=new_free_lo, r6=old_free_lo

        LDR     r6,[r5,#window_free_lo]
        LDR     r7,[r2,#8]
        STR     r7,[r5,#window_free_lo]

        ;r8=size_lo, r2=size_hi

        LDR     r8,[r2,#0]
        LDR     r2,[r2,#4]

        ;r0 new free high
        ;r1 old free high
        ;r2 size high
        ;r6 old free low
        ;r7 new free low
        ;r8 size low

        MOV     r3,#icon_FreeBar
        BL      set_bar                  ; r0 - New size  r1 - Old size r2 - Total size , r3 - icon number.
        Pull    "PC",VS

        LDR     r0,[r5,#window_free_lo]
        LDR     r1,[r5,#window_free_hi]
        BL      create_size_word
        STR     r0,[r5,#free_ascii]

01
        ADR     r2,dataarea
        LDR     r0,[r2,#16]               ; Used
        LDR     r1,[r5,#window_used_lo]
        CMP     r0,r1
        BNE     %FT02
        LDR     r0,[r2,#20]
        LDR     r1,[r5,#window_used_hi]
        CMP     r0,r1
        BEQ     %FT01                    ; Size Unchanged.
02
        STR     r13,[r5,#no_change]      ; set flag to indicate that ascii values need fixing

        LDR     r0,[r2,#20]
        LDR     r1,[r5,#window_used_hi]

        ;r0=new_used_hi, r1=old_used_hi

        STR     r0,[r5,#window_used_hi]

        ;r7=new_used_lo, r6=old_free_lo

        LDR     r6,[r5,#window_used_lo]
        LDR     r7,[r2,#16]
        STR     r7,[r5,#window_used_lo]

        ;r8=size_lo, r2=size_hi

        LDR     r8,[r2,#0]
        LDR     r2,[r2,#4]

        ;r0 new used high
        ;r1 old used high
        ;r2 size high
        ;r6 old used low
        ;r7 new used low
        ;r8 size low

        MOV     r3,#icon_UsedBar
        BL      set_bar                  ; r0 - New size  r1 - Old size r2 - Total size , r3 - icon number.
        Pull    "PC",VS

        LDR     r0,[r5,#window_used_lo]
        LDR     r1,[r5,#window_used_hi]
        BL      create_size_word
        STR     r0,[r5,#used_ascii]

01
        LDR     r0,[r5,#no_change]
        TEQ     r0,#0
        BEQ     %FT02

        ; we do need to check, round, and then update the ascii fields

        ; (check the three values are all of the same magnitude, if so, apply rounding)
        ; then call modified set_text for each one...


        ; check whether all three are the same units
        LDR     r0,[r5,#used_ascii]
        LDR     r1,[r5,#free_ascii]
        LDR     r2,[r5,#size_ascii]

        MOV     lr,r0,LSR #24
        CMP     lr,r1,LSR #24
        CMPEQ   lr,r2,LSR #24
        BNE     %FT02

        ; When all the same units, include a safety check in case it doesn't
        ; add up due to rounding errors, most notably when used+free=size-1
        ; Errors of >1 of the unit are assumed to be deliberate (eg user free space
        ; being less than available free space on whole disc etc)
        SUB     r1,r2,r0
        ORR     r1,r1,lr,LSL #24
        LDR     r0,[r5,#free_ascii]
        SUB     r0,r1,r0                 ; r0 := size-used-free
        CMP     r0,#2
        STRLT   r1,[r5,#free_ascii]      ; out by one so override
02
        LDR     r0,[r5,#used_ascii]
        MOV     r3,#icon_Used
        BL      set_text

        LDR     r0,[r5,#free_ascii]
        MOV     r3,#icon_Free
        BL      set_text

        LDR     r0,[r5,#size_ascii]
        MOV     r3,#icon_Size
        BL      set_text
02
        B       updatelp

;------------------------------------------------------------------------------
; Entry r0 = value (low)
;       r1 = value (high)
;
; Exit  r0 = coded value - top byte is the ASCII character for that size, remaining bytes are
;            the size in those units.
;       r1 = corrupted

create_size_word ROUT
  [ fix_silly_sizes
        CMP     r0,#-1
        CMPEQ   r1,#-1
        MOVEQ   r0,#"?":SHL:24
        MOVEQ   pc, lr                  ; it's a silly size, mark as such
  ]
        Push    "r10,lr"

        MOV     r10, #0                 ; SI unit index
20
        CMP     r1, #1
        CMPCC   r0, #4096               ; Keep dividing until < 4096
        BCC     %FT30
        MOV     r14, r1, LSL #22
        MOV     r1, r1, LSR #10
        MOVS    r0, r0, LSR #10
        ORR     r0, r14, r0
        ADCS    r0, r0, #0              ; Round up lost bit
        ADC     r1, r1, #0
        ADD     r10, r10, #1            ; Next 10^3 up
        B       %BT20
30
        ADR     r14,create_prefixes
        LDRB    r14,[r14,r10]
        ORR     r0,r0,r14,LSL #24       ; Compact representation

        Pull    "r10,pc"

create_prefixes
        DCB     " kMGTPE"               ; units/kilo/mega/giga/tera/peta/exa
        ALIGN

;------------------------------------------------------------------------------
; set_bar
; set bar size.
; Entry:
;       r0 - New   wotsit high
;       r1 - Old   wotsit high
;       r2 - Total size high
;       r3 - Icon number
;       [r5] - window block.
;       r6 - Old   wotsit low
;       r7 - New   wotsit low
;       r8 - Total size low
set_bar ROUT

        ;r9,r10,r11 are working registers for the sums
        Push   "r0-r11,LR"

        ;amg: On closer inspection this actually does not use the old size at all!

        ;calc is new_wotsit * bar_length, then divide by total_size
        ;        r0:r7                                   r2:r8
        ;result in r4
        ;save r3,r5, can trash r9-r11 and r1/r6

        ;first a check for divide by zero
        MOV     r4, r2
        ORRS    r4, r4, r8
        BEQ     %FT50                   ; so take zero as the result

        MOV     r9,#0
        LDR     r10,full_bar

        mextralong_multiply r11,r1,r10,r9,r7,r0
        mextralong_divide r4,r9,r11,r1,r8,r2,r10,r6,r0

        ;ok r4 is the result, and r9 has the top bits (must be zero!)

        LDR    r10,full_bar             ; now a safety check to determine whether the bar is too long
        CMP    r4,r10                   ; (eg for nfs where the used space can exceed the total space
        MOVGT  r4,r10                   ; because of soft and hard limits to partition size)
50
        ADR    r1,dataarea+40
        LDR    r0,[r5,#window_handle]
        STR    r0,[r1]
        STR    r3,[r1,#4]
        SWI    XWimp_GetIconState
        ADDVS  sp,sp,#4
        Pull   "r1-r11,PC",VS

        ADR    r1,dataarea+40
        LDR    r6,[r1,#8+8]      ; Old x1.
        LDR    r14,[r1,#8]       ; x0
        ADD    r14,r14,r4        ; New x1
        STR    r14,[r1,#8+8]     ; Store it.

        Debug  xx,"delete icon"


        SWI    XWimp_DeleteIcon  ; Delete icon.
        ADDVS  sp,sp,#4
        Pull   "r1-r11,PC",VS

        Debug  xx,"create icon"

        ADR    r1,dataarea+44
        LDR    r0,[r5,#window_handle]
        STR    r0,[r1]
        SWI    XWimp_CreateIcon
        ADDVS  sp,sp,#4
        Pull   "r1-r11,PC",VS

        Debug  xx,"force redraw"

        LDR    r0,[r5,#window_handle]
        LDR    r2,[r1,#8]        ; Min y.
        LDR    r4,[r1,#16]       ; Max y.
        CMP    r6,r14
        MOVLE  r1,r6
        MOVLE  r3,r14
        MOVGT  r1,r14
        MOVGT  r3,r6
        SUB    r1,r1,#4
        SWI    XWimp_ForceRedraw
        ADDVS  sp,sp,#4
        Pull   "r1-r11,PC",VS

        Debug  xx,"Set bar returns"

        Pull   "r0-r11,PC"

;------------------------------------------------------------------------------
; set_text
;
; r0 - Size in coded form (top byte = ascii character for power, rest is value at that exponent)
; r3 - Icon number
; [r5] - window block.
set_text
        Push    "r0-r4,r6,LR"

        ADR     r1,dataarea+20
        LDR     r14,[r5,#window_handle]
        STR     r14,[r1,#gi_handle]
        STR     r3,[r1,#gi_iconhandle]
        SWI     XWimp_GetIconState
        ADDVS   sp,sp,#4
        Pull    "r1-r4,r6,PC",VS
                                     
        LDR     r1,[r1,#gi_iconblock+i_data+ii_buffer]  ; Get pointer to buffer
        Debug   xx,"Got state"       

        LDR     r0, [sp]               ; recover r0 after Wimp corrupted it
        MOV     r4,r0,LSR #24

   [ fix_silly_sizes
        TEQ     r4,#"?"
        STREQB  r4,[r1],#1
        MOVEQ   r4,#" "
        STREQB  r4,[r1],#1
        BEQ     %FT33
   ]

        MOV     r2,#20
        SWI     XOS_ConvertCardinal2
        ADDVS   sp,sp,#4
        Pull    "r1-r4,r6,PC",VS

        Debug   xx,"Converted number"

        MOV     r2,#' '
        STRB    r2,[r1],#1             ; Space
        TEQ     r4,#' '
        STRNEB  r4,[r1],#1             ; Power of 10
33
        ADR     r4,message_bytes       ; 'bytes' and a null
        MOV     r0,r1
        BL      copy_r0r4_null

        ADR     r1,dataarea+20
        ASSERT  (si_handle=gi_handle):LAND:(si_iconhandle=gi_iconhandle)
        MOV     r0,#0
        STR     r0,[r1,#si_eorword]
        STR     r0,[r1,#si_clearword]
        SWI     XWimp_SetIconState

        Debug   xx,"Set state, returning."

        Pull    "r0-r4,r6,PC"

;------------------------------------------------------------------------------
; CallEntry - Call the FS entry by the FS number in r1.
;
CallEntry
        Push    "r5,LR"

        Debug   xx,"Call entry"

        ADR     r5,fs_list
01
        LDR     r5,[r5,#fs_next]
        CMP     r5,#0
        ADREQL  r0,ErrorBlock_UnknownFileSystem
        MOVEQ   r1,#0
        BLEQ    LookupError
        Pull    "r5,PC",VS

        Debug   xx,"Known FS"

        LDR     r14,[r5,#fs_number]
        CMP     r14,r1
        BNE     %BT01

        MOV     r14,r5
        Pull    "r5"
        Push    "r12"
        LDR     R12,[r14,#fs_r12]
        Push    "PC"
        LDR     PC,[r14,#fs_entry]        ; Get entry point
        NOP
        Pull    "r12"
        Pull    "PC"
;------------------------------------------------------------------------------
; AddEntry - Add the FS entry in r0 for the FS number in r1 to the list.
;
AddEntry
        Push    "r0-r6,LR"

        MOV     r4,r1
        MOV     r5,r0
        MOV     r6,r2

        MOV     r3,#fs_block_size
        MOV     r0,#ModHandReason_Claim
        SWI     XOS_Module          ; Claim block.
        ADDVS   sp,sp,#4
        Pull    "r1-r5,PC",VS

        LDR     r0,fs_list
        STR     r0,[r2,#fs_next]
        CMP     r0,#0
        STRNE   r2,[r0,#fs_prev]
        MOV     r0,#0
        STR     r0,[r2,#fs_prev]
        STR     r2,fs_list          ; Linked to list

        STR     r4,[r2,#fs_number]
        STR     r5,[r2,#fs_entry]
        STR     r6,[r2,#fs_r12]

        Debug   xx,"Added entry for FS #",r4

        Pull    "r0-r6,PC"

RemoveEntry     ROUT
        Push    "r0-r6,LR"

        LDR     r4,fs_list
01
        CMP     r4,#0
        Pull    "r0-r6,PC",EQ       ; Not found.

        LDR     r14,[r4,#fs_number]
        TEQ     r14,r0
        LDREQ   r14,[r4,#fs_entry]
        TEQEQ   r14,r1
        LDREQ   r14,[r4,#fs_r12]
        TEQEQ   r14,r2
        LDRNE   r4,[r4,#fs_next]
        BNE     %BT01

        LDR     r5,[r4,#fs_prev]
        LDR     r6,[r4,#fs_next]
        CMP     r5,#0
        STRNE   r6,[r5,#fs_next]
        STREQ   r6,fs_list
        CMP     r6,#0
        STRNE   r5,[r6,#fs_prev]

        MOV     r0,#ModHandReason_Free
        MOV     r2,r4
        SWI     XOS_Module
        STRVS   r0,[sp]
        Pull    "r0-r6,PC"

        LNK     Messages.s
