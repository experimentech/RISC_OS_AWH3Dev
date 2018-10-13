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
; s.Messages
;
; Handle incoming Wimp messages.

message_bounced
        Push    "LR"

        LDR     r0, [r1,#ms_action]
        LDR     r14, =Message_WindowInfo
        TEQ     r0,r14
        BEQ     bounced_WindowInfo

        Pull    "PC"

message_received

        Push    "LR"

        LDR     r0, [r1,#ms_action]             ; Get message action.

        LDR     r14,=Message_ModeChange
        TEQ     r0, r14
        BEQ     ModeChange

        LDR     r14,=Message_FontChanged
        TEQ     r0, r14
        BEQ     FontChanged

      [ :LNOT: ursulawimp
        LDR     r14,=Message_PaletteChange
        TEQ     r0, r14
        BEQ     PaletteChange
      ]
        LDR     r14,=Message_FilerSelection
        TEQ     r0, r14
        BEQ     FilerSelection

        TEQ     r0,#Message_DataLoad
        BEQ     DataLoad

        TEQ     r0,#Message_DataSaveAck
        BEQ     DataSaveAck

        LDR     r14,=Message_FilerDevicePath
        TEQ     r0,r14
        BEQ     FilerDevicePath

        LDR     r14,=Message_MenusDeleted
        TEQ     r0,r14
        BEQ     MenuDeleted

        LDR     r14, =Message_IconizeAt
        TEQ     r0, r14
        BEQ     IconizeAt

        LDR     r14, =Message_Iconize
        TEQ     r0, r14
        BEQ     Iconize

        LDR     r14, =Message_WindowInfo
        TEQ     r0, r14
        BEQ     WindowInfo

        LDR     r14, =Message_TaskNameIs
        TEQ     r0, r14
        BEQ     got_task_name

        LDR     r14, =Message_WindowClosed
        TEQ     r0, r14
        BEQ     close_window

        LDR     r14, =Message_TaskCloseDown
        TEQ     r0, r14
        BEQ     close_task

        LDR     r14, =Message_HelpRequest
        TEQ     r0, r14
        BEQ     HelpRequest

        LDR     r14, =Message_ToggleBackdrop
        TEQ     r0, r14
        BEQ     ToggleBackdrop

        TEQ     r0,#Message_Quit
        Pull    "PC",NE

        BL      FreeIconList
        BL      FreeBufferedList
        LDR     r0,mytaskhandle
        LDR     r1,taskidentifier
        SWI     XWimp_CloseDown
        MOV     r0,#0
        STR     r0,mytaskhandle
        SWI     XOS_Exit

        Pull    "PC"

DataLoad ROUT

        Debug   pi,"Data load "

      [ debugpi
        LDR     r14,[r1,#ms_size]
        ADD     r14,r1,r14
        SUB     r14,r14,#8
        LDMIA   r14,{r0,r14}
        Debug   pi,"x,y = ",r0,r14
      ]

        LDR     r0,[r1,#20]                     ; Window handle
        CMP     r0,#0
        BLT     IconbarDataLoad                 ; Iconbar !

        MOV     r0,#FSControl_CanonicalisePath
        ADD     r1,r1,#44               ; -> path
        ADR     r2,dataarea
        MOV     r3,#0
        MOV     r4,#0
        MOV     r5,#256
        SWI     XOS_FSControl
        Pull    "PC",VS
        DebugS  pi,"Full Path is : ",r2
        RSB     r3,r5,#&100
        ADD     r3,r3,#1

        LDR     r6,NextPosition
        LDR     r7,NextPosition+4

        LDR     r1,backdrop_handle
        Debug   pi,"backdrop handle is ",r1
        BL      GetMonotonicID
        MOV     r0,#BufferReason_Remove
        BL      BufferIcon
        MOV     r0,#BufferReason_AddAtXY
        BL      BufferIcon

        ADD     r6,r6,#grid_x_spacing
        LDR     r14,DragBBox+8
        CMP     r6,r14
        LDRGE   r6,DragBBox
        SUBGE   r7,r7,#grid_y_spacing
        STR     r6,NextPosition
        STR     r7,NextPosition+4

        Pull    "PC"

IconbarDataLoad

        MOV     r0,#FSControl_CanonicalisePath
        ADD     r1,r1,#44               ; -> path
        ADR     r2,dataarea
        MOV     r3,#0
        MOV     r4,#0
        MOV     r5,#256
        SWI     XOS_FSControl
        Pull    "PC",VS
        DebugS  pi,"Full Path is : ",r2
        RSB     r3,r5,#&100
        ADD     r3,r3,#1

        MOV     r1,#-2
        BL      GetMonotonicID
        MOV     r0,#BufferReason_Remove
        BL      BufferIcon
        MOV     r0,#BufferReason_AddNewTinyDir
        BL      BufferIcon

        Pull    "PC"


ToggleBackdrop  ROUT

        MOV     R0,#User_Message_Acknowledge ; =19
        LDR     R3,[R1,#ms_myref]       ;
        LDR     R2,[R1,#ms_taskhandle]  ;
        STR     R3,[R1,#ms_yourref]     ;
        SWI     XWimp_SendMessage       ; acknowledge message

        STR     R2,[R1,#ms_taskhandle]  ; restore as ack screwed it
        LDR     R0,[R1,#ms_size]        ; get message size
        LDR     R2,[R1,#ms_data]        ; get flags
        CMP     R0,#&18                 ; is msg >= 24 bytes, ie flags present?
        MOVLT   R2,#0                   ; if not, assume 0

        ADD     R1,R1,#128              ; use upper half of wimp data block
        LDR     R0,backdrop_handle      ; get window handle of backdrop
        STR     R0,[R1,#u_handle]       ; pop window handle in block
        SWI     XWimp_GetWindowState    ; get state of backdrop
        LDR     R14,[R1,#u_bhandle]     ; get handle to open behind
        CMP     R14,#-1                 ; is it -1, ie backdrop at front?
        MOVNE   R14,#-2                 ; if not, pretend it's at back

        AND     R2,R2,#3                ; isolate bottom two bits of flags
        ADD     R2,R2,#1                ; convert flags to something that's
        AND     R2,R2,#3                ; easier to use (0,1,2,3 -> 1,2,3,0)
        CMP     R2,#1                   ;
        EOREQ   R14,R14,#1              ; toggle -2 <-> -1
        RSBHI   R14,R2,#1               ; convert %10 to -1, %11 to -2
        BLO     %FT01                   ; just notify, skip code to move backdrop

        CMP     R14,#-1                 ; is backdrop to be moved to front?
        LDR     R0,[R1,#u_wflags]       ; get flags for backdrop window
        BICEQ   R0,R0,#wf_backwindow    ; if to front, clear background stack bit
        ORRNE   R0,R0,#wf_backwindow    ; if to back, set background stack bit
        STR     R0,[R1,#u_wflags]       ; write flags for backdrop window back
        STR     R14,[R1,#u_bhandle]     ; write handle to open behind back

        LDR     R2,taskidentifier       ; magic word "TASK"
        MOV     R3,#-1                  ; -1 =>
        MOV     R4,#1                   ; bit 0 set =>
        SWI     XWimp_OpenWindow        ; open backdrop window in new position

01      SUB     R1,R1,#128              ; reset to start of wimp data block
        MOV     R2,#&18                 ; message size
        RSB     R3,R14,#0               ;
        LDR     R4,[R1,#ms_myref]       ;
        STR     R2,[R1,#ms_size]        ;
        STR     R3,[R1,#ms_data]        ;
        STR     R4,[R1,#ms_yourref]     ;

        MOV     R0,#User_Message        ; =17
        LDR     R2,[R1,#ms_taskhandle]  ;
        SWI     XWimp_SendMessage       ;

        Pull    "PC"


FilerSelection  ROUT

        ADD     r14,r1,#ms_data
        LDMIA   r14,{r0-r10}
        Debug   pi,"Filer selection BBOX: ",r0,r1,r2,r3
        Debug   pi,"Item width, height: ",r4,r5
        Debug   pi,"Display mode: ",r6
        Debug   pi,"Selection BBOX: ",r7,r8,r9,r10

  [ truncate_filenames
        ; Shrink dragbox to size it will be on pinboard (ie. column width in
        ; dir viewers is likely to be greater than column width in pinboard)
        Push    "r6-r10"
        SUB     r8, r2, r0              ; What is width of drag box?
        DivRem  r9, r8, r4, r10         ; Divide this by column width (from FilerSelection message)...
        CMP     r8, #0                  ; (check for remainder)
        ADDGT   r9, r9, #1              ; ...to get number of columns.
        MOV     r10, #grid_x_spacing
        MUL     r6, r10, r9             ; Multiply this by Pinboard's column width to get new box width

        ; Now we move the box, so that the icon where the drag started (the initiating
        ; icon) appears underneath the pointer on the pinboard.
        LDR     r7, [r14, #44]          ; r7 = mouse x
        SUB     r8, r7, r0              ; r8 = mouse x - x1
        DivRem  r9, r8, r4, r10, norem  ; r9 = column number of initiating icon
        MOV     r4, #grid_x_spacing     ; new item width
        MUL     r8, r9, r4
        SUB     r0, r7, r8              ; new x1 (nearly!)
        SUB     r0, r0, r4, LSR #1      ; minus half column width to centre gives new x1
        ADD     r2, r0, r6              ; new x2
        Pull    "r6-r10"
  ]

; for small icon /full into, drag box will be wildly out.
        TST     r6,#3
        SUBNE   r14,r2,r0
        MOVNE   r14,r14, ASR #1
        SUBNE   r14,r14,#68+12

        ADDNE   r2,r2,r14
        ADDNE   r0,r0,r14
        ADDNE   R1,r1,#16
        ADDNE   r3,r3,#16

        ; Subtract grid_y_spacing from each y co-ord.
        SUB     r1, r1, #grid_y_spacing
        SUB     r3, r3, #grid_y_spacing

        ; Ensure box isn't off screen
        Push    "r4, r5"
        LDR     r5, Screen_x1
        SUB     r4, r2, r0
        CMP     r0, #0                 ; if x1<0
        MOVLT   r2, r4                 ;   then x2 = bbox_width
        MOVLT   r0, #0                 ;    and x1 = 0
        CMP     r2, r5                 ; if x2>screen_width
        SUBGT   r0, r5, r4             ;   then x1 = screen_width - bbox_width
        MOVGT   r2, r5                 ;    and x2 = screen_width

        LDR     r5, icon_bar_height
        SUB     r5, r5, #grid_y_spacing
        SUB     r4, r3, r1
        CMP     r1, r5                 ; if y1<icon_bar_height
        ADDLT   r3, r5, r4             ;   then y2 = icon_bar_height + bbox_height
        MOVLT   r1, r5                 ;    and y1 = icon_bar_height
        LDR     r5, Screen_y1
        SUB     r5, r5, #grid_y_spacing
        CMP     r3, r5                 ; if y2>screen_height
        SUBGT   r1, r5, r4             ;   then y1 = screen_height - bbox_height
        MOVGT   r3, r5                 ;    and y2 = screen_height
        Pull    "r4, r5"

        ADR     r14,DragBBox
        STMIA   r14,{r0-r3}

        ADR     r14,NextPosition
        STMIA   r14,{r0,r3}                     ; x0,y1 of next position

        Pull    "pc"

FilerDevicePath
        ADD     r0,r1,#20
        B       Int_DataSaveAck

DataSaveAck     ROUT
        Debug   pi,"DataSaveAck received."

        MOV     r0,#DragType_NoDrag
        LDR     r14,DragType
        STR     r0,DragType
        TEQ     r14,#DragType_Save
        BEQ     Save_DataSaveAck

; Now that we have the directory to send to, start sending the files.

        ADD     r0,r1,#44
        ADR     r1,dest_directory
        BL      Copy_r0r1

00
        LDRB    r14,[r1],#-1
        CMP     r14,#"."
        BNE     %BT00
        MOV     r14,#0
        STRB    r14,[r1,#1]

Int_DataSaveAck

        LDR     r10,Icon_list
01
        CMP     r10,#0
        Pull    "PC",EQ

        LDR     r3,DragWindow
        ADR     r1,dataarea
        LDR     r0,[r10,#ic_window]      ; Not in drag window.
        TEQ     r0,r3
        BNE     %FT10

        LDR     r0,[r10,#ic_icon]
        STR     r3,[r1]
        STR     r0,[r1,#4]
        SWI     XWimp_GetIconState
        Pull    "PC",VS

        LDR     r0,[r1,#24]
        TST     r0,#selected
        BEQ     %FT10                   ; Not selected

        MOV     r0,#0
        STR     r0,[r1,#8]
        CMP     r3,#0
        MOVGT   r0,#is_selected
        MOVLT   r0,#selected
        STR     r0,[r1,#12]
        SWI     XWimp_SetIconState      ; Deselect

        CMP     r3,#0
        LDRGE   r0,Pinboard_Selected
        LDRLE   r0,TinyDirs_Selected
        SUB     r0,r0,#1
        STRGE   r0,Pinboard_Selected
        STRLE   r0,TinyDirs_Selected
        Debug   pi,"Selected icons = ",r0

; Check for recursive copy

        MOV     r0,#-1
        SWI     XTerritory_UpperCaseTable
        Pull    "PC",VS
        MOV     r14,r0

        ADD     r0,r10,#ic_path
        ADR     r1,dest_directory
        DebugS  pi,"Source: ",r0
        DebugS  pi,"Dest: ",r1
02
        LDRB    r3, [r0], #1    ;       Source char
        LDRB    r3, [r14, r3]
        LDRB    r4, [r1], #1    ;       Dest char
        LDRB    r4, [r14, r4]
        CMP     r3,#32
        BLE     %FT03
        CMP     r3,r4
        BEQ     %BT02
        B       %FT04
03
        Debug   pi,"Check terminating char ",r4
        CMP     r4,#"."
        CMPNE   r4,#32
        ADRLE   r0,ErrorBlock_Pinboard_CopyRecursive
        BLLE    msgtrans_errorlookup
        Pull    "PC",VS

04
        Debug   pi,"Copy not recursive"
        BL      read_copy_options
        Debug   pi,"Copy options read"

; Check free RAM. If less than 64k then there is not enough for a FilerAction task to do the copying
        MOV     r0, #-1
        MOV     r1, #-1
        SWI     XWimp_SlotSize
        Pull    "PC",VS

        Debug   pi,"Next slot is ",r1

; If not enough for FilerAction then *COPY
        CMP     r1, #Filer_Action_Memory_CopyRename
        BLT     do_copy

        Debug   pi,"Enough memory"

; Check configuration bit, do * copy if no interactive filer copy.
        MOV     r0,#OsByte_ReadCMOS
        MOV     r1,#FileSwitchCMOS
        SWI     XOS_Byte
        TST     R2,#4
        BNE     do_copy

        Debug   pi,"Configuration OK"

; Start FilerAction
        ADR     r0, FilerAction_command
        SWI     XWimp_StartTask
        Pull    "PC",VS
        CMP     r0, #0
        BEQ     do_copy

        Debug   pi,"Filer action started"

; Select source directory
        MOV     r8, r0
        ADD     r0, r10, #ic_path
        ADR     r1, dataarea
        BL      Copy_r0r1

        ADR     r14,dataarea
        MOV     r3,r14
05
        LDRB    r2,[r14],#1
        CMP     r2,#"."
        SUBEQ   r3,r14,#1
        CMP     r2,#32
        BGT     %BT05

        MOV     r0,#0
        STRB    r0,[r3],#1              ; Get just the directory name.

        MOV     r0, r8
        ADR     r1, dataarea
        DebugS  pi,"Source directory: ",r1
        SWI     XFilerAction_SendSelectedDirectory

; Select source file
        MOV     r1, r3
        DebugS  pi,"source file: ",r1
        SWI     XFilerAction_SendSelectedFile

; Perform the copy
; r1 = reason code, r2 = options, r3 -> destination directory, r4 = length of destination directory name

        MOV     r1, #Action_Copying
        LDR     r2, filer_action_copy_options
        ADR     r3, dest_directory
        MOV     r4, r3
06
        LDRB    r5, [r4], #1
        CMP     r5, #32
        BGT     %BT06
        SUB     r4, r4, r3
        MOV     r0,r8
        SWI     XFilerAction_SendStartOperation

10
        LDR     r10,[r10,#ic_next]
        B       %BT01

do_copy                                 ; There isn't enough memory to invoke FIlerAct or FilerAct is disabled
                                        ; by configuration.

        ADR     r0, Copy_command
        SWI     XWimp_CommandWindow
        Pull    "PC",VS

        ADR     r0, dataarea            ; Copy *copy command to dataarea
        ADR     r1, Copy_command
        BL      Copy_r1r0

        ADD     r1, r10, #ic_path       ; Append filename
        BL      Copy_r1r0

        MOV     r2, #" "                ; Change null terminator to space
        STRB    r2, [r0],#1
        ADR     r1, dest_directory
        BL      Copy_r1r0

; Append leafname
        MOV     r2, #"."
        STRB    r2, [r0],#1


        ADD     r3, r10, #ic_path
        MOV     r4,r3
11
        LDRB    r14,[r3],#1
        CMP     r14,#"."
        MOVEQ   r4,r3
        CMP     r14,#32
        BGT     %BT11

        MOV     r1, r4
        BL      Copy_r1r0


        MOV     r2, #" "                ; Append options
        STRB    r2, [r0],#1
        ADR     r1, copy_options
        BL      Copy_r1r0


        ADR     r0, dataarea            ; Do the copy
        SWI     XOS_CLI
        BVS     %FT20

        MOV     r0, #0
        SWI     XWimp_CommandWindow
        Pull    "PC",VS

        B       %BT10

20
        BL      ReportError
        MOV     r0,#-1
        SWI     XWimp_CommandWindow
        Pull    "PC"

FilerAction_command
        DCB     "Filer_action",0
Copy_command
        DCB     "Copy "
        ALIGN

        MakeErrorBlock  Pinboard_CopyRecursive
        ALIGN

IntMenuDeleted
        Push    "LR"
MenuDeleted
        ; Abort any pending drag operation
        LDR     R0, DragType
        TEQ     R0, #DragType_NoDrag
        BEQ     MenuNoDrag
        ; Abort the drag and restore input focus
        MOV     R0, #DragType_NoDrag
        STR     R0, DragType
        BL      Restore_Focus
        SWI     XDragASprite_Stop
MenuNoDrag

        LDR     r8,soft_selection_window
        CMP     r8,#0
        Debug   me,"Soft selection window is ",r8
        Pull    "PC",EQ

        ADRGT   r0,Pinboard_Selected
        ADRLT   r0,TinyDirs_Selected
        LDR     r1,[r0]
        SUBS    r1,r1,#1
        MOVMIS  r1,#0
        STREQ   r1,[r0]

        ADR     r1,dataarea
        STR     r8,[r1]
        LDR     r14,soft_selection_icon
        Debug   me,"icon is ",r14
        STR     r14,[r1,#4]
        MOV     r14,#0
        STR     r14,[r1,#8]
        CMP     r8,#0
        MOVLT   r14,#selected
        MOVGT   r14,#is_selected
        STR     r14,[r1,#12]
        SWI     XWimp_SetIconState
        Pull    "PC",VS

        ;------ We've de-selected the soft-selected icon, now reset all
        ; (FG)  related variables. No need to check _what_ was selected.

        MOV     r14,#0
        STR     r14,soft_selection_window
        STR     r14,soft_selection_icon         ; (FG)
        STR     r14,Pinboard_Selected           ; (FG)
        STR     r14,TinyDirs_Selected           ; (FG)
        STR     r14,Windows_Selected            ; (FG)

        Pull    "PC"


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Handle Message_IconizeAt

IconizeAt
        LDR     r0, [r1, #28]
        STR     r0, IconizeAtX

        LDR     r0, [r1, #32]
        STR     r0, IconizeAtY

        LDR     r0, [r1, #36]
        STR     r0, IconizeAtFlags

        Pull    "PC"


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Handle Message_Iconize

Iconize

        LDR     r0,Pinboard_options
        TST     r0,#PinboardOption_NoIconize
        Pull    "PC",NE

        LDR      R0, [r1,#ms_myref]
        STR      R0, [r1,#ms_yourref]
        MOV      R0, #19                ; Ack the message.
        LDR      R2, [r1,#ms_taskhandle]
        SWI      XWimp_SendMessage
        Pull     "PC",VS

        LDR      r3,[r1,#ms_data]
        STR      r3,iconized_window     ; Save window handle.

        LDR      r2,[r1,#ms_data+4]
        STR      r2,iconized_task       ; Save task id.

        MOV      r0,#0
        STRB     r0,[r1,#ms_data+8+10]  ; Truncate title string to 10 chars.

        ADD      r0,r1,#ms_data+8       ; Save the title string
        ADR      r1,window_title
        BL       Copy_r0r1

        ADR      r1,dataarea
        MOV      r0,#ms_data+4          ; Send WindowInfo message.
        STR      r0,[r1]                ; one word of data.
        MOV      r0,#0
        STR      r0,[r1,#ms_myref]
        STR      r0,[r1,#ms_yourref]
        LDR      r0,=Message_WindowInfo
        STR      r0,[r1,#ms_action]
        STR      r3,[r1,#ms_data]

        MOV      r0,#18                 ; Recorded message.
        SWI      XWimp_SendMessage

        Pull     "PC"

WindowInfo     ROUT

        Debug   ic,"Got WindowInfo"

        LDR     r0,[r1,#ms_size]
        CMP     r0,#24
        BGT     %FT01                ; Size > 24 this is a reply to my request.

        LDR     r0,[r1,#ms_taskhandle]
        LDR     r2,mytaskhandle

        CMP     r0,r2                ;  Did I send it ?
        LDRNE   r0,Pinboard_options
        ORRNE   r0,r0,#PinboardOption_NoIconize
        STRNE   r0,Pinboard_options
        BLNE    ReopenWindows        ; Someone else sent it , reopen all windows

        Pull    "PC"

01
        MOV      r0,#0
        STRB     r0,[r1,#ms_data+16+10]       ; Force terminator after 10 chars.
        ADD      r0,r1,#ms_data+16            ; Save the title string
        ADR      r1,window_title
        BL       Copy_r0r1

        ADR      r1,dataarea
        B        got_task_name                ; pretend it's a TaskNameIs message.

bounced_WindowInfo

        Debug    ic,"Bounced windowinfo"

        MOV       R0,#ms_data+4               ; Get task name (for sprite_name)
        STR       R0,[R1]
        MOV       R0,#0
        STR       r0,[r1,#ms_myref]
        STR       r0,[r1,#ms_yourref]
        LDR       r0,=Message_TaskNameRq
        STR       r0,[r1,#ms_action]
        LDR       R0,iconized_task
        STR       r0,[r1,#ms_data]
        MOV       r0,#17
        MOV       r2,#0                       ; Broadcast.
        SWI       XWimp_SendMessage

        Pull     "PC"

 [ iconise_to_iconbar
w_iconbar_flags DCD &1700310b
 ]
w_icon_flags    DCD &4000a50b
;w_icon_flags    DCD &4700A50B

icon_sprite   DCB  "ic_",0
default_icon  DCB  "ic_?",0

       ASSERT (?default_icon)<15

       ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; write_colour_valid
;
; Poke a colour validation string in

 [ technicolour_text
write_colour_valid
        ; r1 -> block
        ; r2 = foreground colour
        ; r3 = background colour
        Push    "r0,r2,lr"

        MOV     r0,#'C'
        STRB    r0,[r1],#1

        MOV     r0,r2,LSR #8
        MOV     r2,#10
        SWI     XOS_ConvertHex6

        MOV     r0,#'/'
        STRB    r0,[r1],#1

        MOV     r0,r3,LSR #8
        MOV     r2,#10
        SWI     XOS_ConvertHex6               ; creates part of a validation string Cbbggrr/bbggrr
                                              ; which requires Window Manager 3.98 or later
        Pull    "r0,r2,pc"

write_icon_valid_string
        ; r0 -> spritename
        ; r1 -> block to contain valid string
        Push    "r0-r3,lr"

        LDR     r2,foreground_colour
        LDR     r3,background_colour
        BL      write_colour_valid
        MOV     r2, r0
        ADR     r0, write_icon_selected
        BL      Copy_r0r1                     ; append some more validation
        MOV     r0, r2
        BL      Copy_r0r1                     ; now append the spritename

        Pull    "r0-r3,pc"

write_icon_selected
        DCB     "/////AAAAAA/000000;S",0
        ALIGN
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; got_task_name
;
; We've got a name for the window we're iconising.

got_task_name
       ; Allocate buffer space
       MOV      r3, #w_block_size
       MOV      r0, #ModHandReason_Claim
       SWI      XOS_Module
       Pull     "PC",VS

       ; Delete duplicate icons.
       Push     "r0-r11"
       LDR      r5, iconized_window
       BL       Int_close_window
       Pull     "r0-r11"

       ; Fill info
       MOV      r0,#-1
       STR      r0,[r2,#w_icon_handle]

 [ technicolour_text
       ADR      r0,icon_sprite
       ADD      r1,r2,#w_valid_string
       BL       write_icon_valid_string
 |
       MOV      r0,#"S"
       STR      r0,[r2,#w_sprite_prefix]

       ADR      r0,icon_sprite            ; copy sprite prefix
       ADD      r1,r2,#w_sprite_name
       BL       Copy_r0r1
 ]

       ADR      r1,dataarea
       ADD      r3,r1,#ms_data+8
       ADD      r0,r2,#w_sprite_name      ;  and task name.
       MOV      r4,#?icon_sprite-1

01
       LDRB     r5,[r3],#1
       CMP      r5,#&20                   ; Up to space or terminator.
       BLE      %FT02
       STRB     r5,[r0,r4]
       ADD      r4,r4,#1
       CMP      r4,#14                    ; or 13 characters.
       BLT      %BT01

02     MOV      r5,#0                     ; Store zero terminator.
       STRB     r5,[r0,r4]

       MOV     r11, r2

       ADD     r2,  r2,#w_sprite_name
       MOV     r0,  #SpriteReason_ReadSpriteSize
       SWI     XWimp_SpriteOp
       ADDVS   r1, r11, #w_sprite_name
       ADRVS   r0, default_icon
       BLVS    Copy_r0r1

       ; Read window info.
       ADR      r1,dataarea
       LDR      r0,iconized_window
       STR      r0,[r1]
       STR      r0,[r11,#w_window_handle]
       SWI      XWimp_GetWindowState

       ADD      r1,r1,#4
       LDMIA    r1,{r3-r8}
       Debug    ic,"window pos ",r3,r4,r5,r6,r7,r8
       ADD      r1,r11,#w_window_pos
       STMIA    r1,{r3-r8}

       Debug    ic,"window pos ",r3,r4,r5,r6,r7,r8

       LDR      r0,iconized_task
       STR      r0,[r11,#w_task]

       ADR      r0,window_title           ; Copy window title.
       ADD      r1,r11,#w_window_title
       BL       Copy_r0r1

       ; Open window with -3
       ADR      r1,dataarea
       MOV      r0,#-3
       STR      r0,[r1,#28]

       MOV      r0,#2     ; Open window
       LDR      r2,iconized_task
       SWI      XWimp_SendMessage

       Debug    ic,"Sent open request"


; Get position
 [ iconise_to_iconbar
       LDR      lr, IconizeAtFlags
       TST      lr, #IconizeAtFlag_ShiftCloseIcon
       BNE      %FT08
       LDR      lr, Pinboard_options
       TST      lr, #PinboardOption_IconiseToIconBar
       BNE      %FT00
08
 ]
       ; x co-ord
       LDR      r0,[r11,#w_window_pos]
       ADD      r0,r0,#grid_x_spacing :SHR: 1
       SUB      r0, r0, #34
       STR      r0,iconize_x

       ; y co-ord
       LDR      r1,[r11,#w_window_pos+12]
       SUB      r1,r1,#grid_y_spacing :SHR: 1
       STR      r1,iconize_y

       ; First see if shift+close was used to do the iconising. If so, ignore corner settings.
       LDR      r0, IconizeAtFlags
       TST      r0, #IconizeAtFlag_ShiftCloseIcon
       BNE      %FT09

       ; Are we using the corner settings? If so, get the position the icon will go in.
       TST      lr, #PinboardOption_UseWinToCorner
       Push     "lr"
       BLNE     get_iconise_position
       Pull     "lr"

       ; If using a corner, or the iconbar, then skip ahead.
       TST      lr, #PinboardOption_UseWinToCorner
       BNE      %FT00
       TST      lr, #PinboardOption_IconiseToIconBar
       BNE      %FT00

09     ; We're iconising to the pointer, either because this was set or because the iconising
       ; was done by Shift clicking on the close icon of a window.
       LDR      r0, IconizeAtX     ; If there's a value waiting from a Message_IconizeAt
       CMP      r0, #-1            ; then use that,
       BEQ      %FT00              ; otherwise use the default position (so skip ahead)
       STR      r0, iconize_x
       LDR      r0, IconizeAtY
       STR      r0, iconize_y

00
       ; Peform bounds check on iconize_x and iconize_y
       LDR      r0, iconize_x
       CMP      r0, #0
       MOVLT    r0, #0
       LDR      r1, Screen_x1
       SUB      r1, r1, #grid_x_spacing - 8
       CMP      r0, r1
       MOVGT    r0, r1
       STR      r0, iconize_x

       LDR      r0, iconize_y
       CMP      r0, #0
       MOVLT    r0, #0
       LDR      r1, Screen_y1
       SUB      r1, r1, #grid_y_spacing - 8
       CMP      r0, r1
       MOVGT    r0, r1
       STR      r0, iconize_y

       ; Reset the IconizeAt copy
       MOV     r0, #-1
       STR     r0, IconizeAtX
       STR     r0, IconizeAtY

       ADD     r2, r11, #w_sprite_name

       MOV     r0, #SpriteReason_ReadSpriteSize
       SWI     XWimp_SpriteOp

       ADD     r9,r11,#w_window_title
       ADD     r10,r11,#w_sprite_prefix

; Valid registers r6 = sprite mode, r3,r4 = sprite width,height, r9->icon name,r10->sprite name,r11->icon
; Adjust to get OS units
       MOVVC   r0, r6                          ; creation mode of sprite
       MOVVC   r1, #VduExt_XEigFactor
       SWIVC   XOS_ReadModeVariable
       MOVVC   r5, r3, LSL r2
       MOVVC   r3, #0
       MOVVC   r1, #VduExt_YEigFactor
       SWIVC   XOS_ReadModeVariable
       Pull    "PC",VS
       MOV     r6, r4, LSL r2
       ADD     r6, r6, #36
       MOV     r4, #0
       MOV     r3, #0

       ; Check length of name
       MOV     R0,#1
       MOV     R1,R9
       Push    "R2"
       MOV     R2,#0
       SWI     XWimp_TextOp
       Pull    "R2"
       CMP     R5,R0
       MOVLT   R5,R0

       ; Get flags and name
       ADR     r1, dataarea
       LDR     r0, backdrop_handle

 [ iconise_to_iconbar
       LDR     lr, Pinboard_options
       TST     lr, #PinboardOption_IconiseToIconBar
       SUBNE   r6, r6, #16
       MOVNE   r4, #-16
 ]

        STMIA   r1!, {r0,r3,r4,r5,r6}
 [ iconise_to_iconbar
        LDRNE   r6, w_iconbar_flags
        LDREQ   r6, w_icon_flags
 |
        LDR     r6, w_icon_flags
 ]
 [ technicolour_text
        ADD     r10, r11, #w_valid_string
 |
        ADD     r10, r11, #w_sprite_prefix
 ]
        MOV     r14, #32
        STMIA   r1!, {r6,r9,r10,r14}

        ; Create the icon
        ADR     r1,dataarea             ; create iconbar entry

 [ iconise_to_iconbar
        ; Deal with Iconise to Iconbar
        ; Ignore if Shift + Close clicked
        LDR     lr, IconizeAtFlags
        TST     lr, #IconizeAtFlag_ShiftCloseIcon
        BNE     %FT01

        ; Ignore if  not Iconise to Iconbar
        LDR     lr, Pinboard_options
        TST     lr, #PinboardOption_IconiseToIconBar
        BEQ     %FT01

        ; Okay, it's Iconise to Iconbar
        LDR     r0, Iconbar_Icons
        ADD     r0, r0, #1
        STR     r0, Iconbar_Icons
        MOV     r0, #-2
        STR     r0, [r1]
 [ technicolour_text
        ADD     r0,r11,#w_sprite_prefix
        STR     r0, [r1,#28]            ; change the validation string to skip the C command
 ]
        B       %FT10
01
 ]

        LDR     r0,backdrop_handle
        STR     r0,[r1],#4
        LDMIA   r1,{r3-r6}
        LDR     r9,iconize_y
        LDR     r8,icon_bar_height
        CMP     r8,r9
        MOVGT   r9,r8
        LDR     r8,iconize_x

        ; Check if we're iconising to the close icon
        LDR     r3, IconizeAtFlags
        TST     r3, #IconizeAtFlag_ShiftCloseIcon
        BNE     %FT02
        TSTEQ   lr, #PinboardOption_UseWinToCorner
        BEQ     %FT02

        ; We're iconising to a corner - centre icon.
        Push    "r0-r1"
        MOV     r3, r8
        MOV     r4, r9
        MOV     r0, #grid_x_spacing
        SUBS    r1, r0, r5
        ADDS    r3, r3, r1, ASR #1
        Pull    "r0-r1"
        B       %FT04

02      ; Tweak x positioning of the icon if we're iconising to the close icon
        Debug   ic,"r3 x y",r3,r8,r9
        ADD     r3,r3,r8
        SUBS    r3,r3,r5, LSR #1
        MOVCC   r3,#0
        ADD     r4,r4,r9

04
        ADD     r5,r3,r5
        ADD     r6,r6,r9
        LDR     r8,w_icon_flags
        Debug   ic,"Lock to grid ",r3
        ;BL      lock_to_grid
        Debug   ic,"Lock to grid returned"

        STMIA   r1,{r3-r6,r8}
        Debug   ic,"Bounding box is ",r3,r4,r5,r6
        SUB     r1,r1,#4
10
        LDR     r8, [r1]
        Push    "r8"          ; stick the window handle (backdrop or iconbar) on stack

        SWI     XWimp_CreateIcon
        ADRVC   r1,dataarea
        STRVC   r0,[r1,#4]
        MOVVC   r8,#0
        STRVC   r8,[r1,#8]
        STRVC   r8,[r1,#12]
        MOVVC   r8,r0
        SWIVC   XWimp_SetIconState

        Pull    "r0"                     ; get window handle back off stack.
        STR     r0, [r11, #w_icon_id]    ; store window handle
        STRVC   r8, [r11,#w_icon_handle] ; store icon handle

        ; Reset IconizeAtFlags
        MOV     r0, #Default_IconizeAtFlags
        STR     r0, IconizeAtFlags

        ; (r11=Pointer) Link to list.
        LDR     r0,iconized_ptr
        STR     r0,[r11,#w_next_ptr]
        CMP     r0,#0                    ; If next exsists link to it.
        STRNE   r11,[r0,#w_prev_ptr]
        STR     r11,iconized_ptr         ;  First on the list.
        MOV     r0,#0
        STR     r0,[r11,#w_prev_ptr]     ; No previous.

       ; Install icon (Zoom ?)
 [ drag_on_iconise
        ADR     r1, dataarea
        LDR     r2, [r1, #4]            ; Get back icon handle.
        SWI     XWimp_GetPointerInfo
        LDMVCIA r1, {r10,r11}           ; Get current pointer position.
        BVC     Iconized_Drag           ; Start drag.
 ]
        LDR     r0, Window_Icons
        ADD     r0, r0, #1
        STR     r0, Window_Icons
        Pull    "PC"


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Int_close_window

Int_close_window                  ; fake close window ( r5=handle )
        Push    "LR"
        B       close_window_entry


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; close_window

close_window
        LDR     R0, [r1,#ms_myref]
        STR     R0, [r1,#ms_yourref]
        MOV     R0, #19                ; Ack the message.
        LDR     R2, [r1,#ms_taskhandle]
        SWI     XWimp_SendMessage
        Pull    "PC",VS

        LDR     r5,[r1,#ms_data]


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; close_window_entry

close_window_entry
        Push    "R7"

        Debug   ic,"window closed ",r5

01      BL      find_window

        CMP     r7,#0
        Pull    "R7,PC",EQ
        BL      delete_window      ; Preserves r5.
        B       %BT01


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; close_task

close_task

        LDR     r5,[r1,#ms_taskhandle]

        Debug   ic,"Task close ",r5

01      BL      find_task
        CMP     r7,#0
        Pull    "PC",EQ
        BL      delete_window      ; Preserves r5.
        B       %BT01


        LNK     Help.s
