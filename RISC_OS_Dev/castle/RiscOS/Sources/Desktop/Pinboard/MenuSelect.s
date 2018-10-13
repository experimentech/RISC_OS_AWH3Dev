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
; s.MenuSelect
;
; Handle menu selections

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; menu_selection
;
; In: r1 -> 256 byte block returned by Wimp_Poll, of which...
;                r1+0 item in main menu which was selected
;                r1+4 item in first submenu which was selected
;                r1+8 item in second submenu which was selected
;                etc.
;
; Out: registers may be corrupted - returning to wimp poll.

menu_selection ROUT

        Push    "LR"

        Debug   pi,"Menu selection"

        ADR     r1,PointerInfo
        SWI     XWimp_GetPointerInfo
        Pull    "PC",VS
        ADR     r1,dataarea

        LDR     r14,CurrentMenu
        TEQ     r14,#Menu_Pinboard
        BEQ     pinboard_menu_selection
        TEQ     r14,#Menu_TinyDirs
        BEQ     tinydirs_menu_selection
        TEQ     r14,#Menu_TinyDirsIcon
        BEQ     tinydirs_icon_menu_selection

        Pull    "PC"

reopen_tinydirs_icon_menu

        Debug   pi,"Reopen tinydirs icon menu"

        LDR     r14,PointerInfo+8
        Debug   pi,"buttons ",r14
        TST     r14,#1
        BNE     TinyDirsIcon_Menu
        Pull    "PC"

tinydirs_icon_menu_selection ROUT

        ADR     r2,reopen_tinydirs_icon_menu
        Push    "r2"

        LDR     r14,[r1]
        ADD     PC,PC,R14,ASL #2
        Pull    "PC"
        B       QuitTinyDirs

QuitTinyDirs
        LDR     r0,Pinboard_options
        BIC     r0,r0,#PinboardOption_TinyDirs
        STR     r0,Pinboard_options

        LDR     r0,TinyDirs_Handle
        CMP     r0,#0
        Pull    "PC",LT

        ADR     r1,dataarea
        STR     r0,[r1,#4]
        MOV     r0,#-2
        STR     r0,[r1]
        SWI     XWimp_DeleteIcon

        MOV     r0,#-1
        STR     r0,TinyDirs_Handle
        Pull    "lr"
        Pull    "PC"

reopen_tinydirs_menu

        Debug   pi,"Reopen tinydirs menu"

        LDR     r14,PointerInfo+8
        Debug   pi,"buttons ",r14
        TST     r14,#1
        BNE     recreate_iconbar_menu
        Pull    "PC"

tinydirs_menu_selection ROUT

        ADR     r2,reopen_tinydirs_menu
        Push    "r2"

        LDR     r14,[r1]
        ADD     PC,PC,R14,ASL #2
        Pull    "PC"

        B       SelectAllIconbar        ; 1
        B       ClearIconbarSelection   ; 2
        B       RemoveIconbarSelection  ; 3
        B       OpenParent              ; 4

SelectAllIconbar ROUT
        Debug   pi,"SelectAllIconbar"

        MOV     r0,#-2
        BL      SelectFileIcons
        Pull    "PC"

ClearIconbarSelection

        Debug   pi,"CleariconbarSelection"
        MOV     r0,#-2
        BL      DeselectFileIcons
        Pull    "PC"

RemoveIconbarSelection
        Debug   pi,"Remove Iconbar"

        MOV     r0,#-2
        BL      RemoveIcons

        Pull    "PC"

OpenParent      ROUT

        LDR     r5,[r1,#4]

        MOV     r0,#-2
        ADR     r1,dataarea
        MOV     r2,#is_selected
        MOV     r3,#is_selected
        SWI     XWimp_WhichIcon
        Pull    "PC",VS

01
        LDR     r2,[r1],#4
        MOV     r1,#-2
        BL      FindIcon
        BNE     %BT01

        ADR     r1,dataarea
        ADR     r0,OpenParent_command
        BL      Copy_r0r1

        ADD     r0,r2,#ic_path
        BL      Copy_r0r1

        MOV     r2,#-1
        ADR     r0,dataarea
02
        LDRB    r14,[r0],#1
        CMP     r14,#"."
        SUBEQ   r2,r0,#1
        CMP     r14,#32
        BGE     %BT02

        MOV     r0,#0
        CMP     r2,#-1
        STRNEB  r0,[r2]

        ADR     r0,dataarea
        DebugS  td,"Command is ",r0
        SWI     XOS_CLI

        Pull    "PC"

OpenParent_command      DCB     "Filer_OpenDir ",0
                        ALIGN


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; reopen_pinboard_menu
;
; Called after dealing with a menu selection, to reopen the menu if a
; right mouse click was used on the selection.

reopen_pinboard_menu

        Debug   pi,"Reopen pinboard menu"

        LDR     r14,PointerInfo+8
        Debug   pi,"buttons ",r14
        TST     r14,#1
        BNE     recreate_pinboard_menu
        Pull    "PC"


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; pinboard_menu_selection
;
; Deal with selections from the pinboard menu
;
; In: r1 -> Wimp_Poll block, specifically R1+0 contains the number of the
;           item in the main pinboard menu which was selected.

pinboard_menu_selection

        ADR     r2,reopen_pinboard_menu ; Make sure this function is called when we've dealt with
        Push    "r2"                    ; selection, so that menu is reopened if Right button was used

        LDR     r14,[r1]
        ADD     PC,PC,R14,ASL #2
        Pull    "PC"

        B       selection_menu_selection ; 0
        B       selectall_menu_selection ; 1
        B       ClearSelection           ; 2
        B       OpenConfigure            ; 3
        B       Save                     ; 4
        [ show_backdrop_options
        B       MakeBackdrop             ; 5
        B       RemoveBackdrop           ; 6
        ]


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; selectall_menu_selection
;
; Deal with a selection from the Select all submenu.
;
; In: r1 -> Wimp_Poll bloc, specifically, R1 + 4 contains the number of
;           the item selected from the Select all submenu.

selectall_menu_selection

        LDR     r14, [r1, #4]
        ADD     pc, pc, r14, ASL #2
        B       SelectAll                ; -1 - Just a click on SelectAll without moving to the menu

        B       SelectAllFiles           ; 0 - Select files
        B       SelectAllWindows         ; 1 - Select windows
        B       SelectAll                ; 2


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; selection_menu_selection
;
; Deal with a selection from the Selection submenu.
;
; In: r1 -> Wimp_Poll bloc, specifically, R1 + 4 contains the number of
;           the item selected from the Selection submenu.

selection_menu_selection

        LDR     r14, [r1, #4]
        ADD     pc, pc, r14, ASL #2
        Pull    "pc"

        B      Tidy                     ; 0
        B      OpenSelection            ; 1 - Open
        B      Remove                   ; 2
        B      HelpFromApp              ; 3


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OpenConfigure
;
; The 'Configure...' option was selected.
; Open the configure plugin for the Pinboard, if present.

OpenConfigure

        ADR     R0,OpenCfgCmd                   ; (FG) -> command to run Pinboard plugin
        SWI     XWimp_StartTask                 ; (FG) start command as a task
        Pull    "PC"                            ; (FG) say bye bye

OpenCfgPath     DCB "BootResources$$Path",0
OpenCfgCmd      DCB "IfThere BootResources:Configure.!PinSetup Then Filer_Run BootResources:Configure.!PinSetup",0
                ALIGN


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Tidy
;
; The 'Tidy' option was selected.

Tidy
        Debug   pi,"Tidy"

        LDR     r0, Pinboard_options
        ORR     r0, r0, #PinboardFlag_UseWindowList
        STR     r0, Pinboard_options
        BL      tidy_icons

        LDR     r0, Pinboard_options
        BIC     r0, r0, #PinboardFlag_UseWindowList
        STR     r0, Pinboard_options
        BL      tidy_icons

        ;MOV     r0,r5
        LDR     r0,backdrop_handle
        MOV     r1,#-1
        MOV     r2,#-1
        MOV     r3,#&80000
        MOV     r4,#&80000
        SWI     XWimp_ForceRedraw

        Pull    "PC"


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Remove
        Debug   pi,"Remove"

        LDR     r0,backdrop_handle
        BL      RemoveIcons

        Pull    "PC"

SelectAll

        Debug   pi,"SelectAll"

        LDR     r0,backdrop_handle
        BL      SelectAllIcons
        Pull    "PC"

SelectAllFiles

        LDR     r0, backdrop_handle
        BL      DeselectAllIcons
        LDR     r0, backdrop_handle
        BL      SelectFileIcons
        Pull    "PC"

SelectAllWindows

        LDR     r0, backdrop_handle
        BL      DeselectAllIcons
        LDR     r0, backdrop_handle
        BL      SelectWindowIcons
        Pull    "PC"

ClearSelection

        Debug   pi,"ClearSelection"
        LDR     r0,backdrop_handle
        BL      DeselectAllIcons
        Pull    "PC"

MakeBackdrop

        Debug   pi,"MakeBackdrop"

        LDR     r5,[r1,#4]

        LDR     r0,backdrop_handle
        ADR     r1,dataarea
        MOV     r2,#is_selected
        MOV     r3,#is_selected
        SWI     XWimp_WhichIcon
        Pull    "PC",VS

        LDR     r2,[r1]
        LDR     r1,backdrop_handle
        BL      FindIcon
        Pull    "PC",NE

        ADR     r1,dataarea
        ADR     r0,backdrop_command
        BL      Copy_r0r1

        ADD     r0,r2,#ic_path
        BL      Copy_r0r1

        ADR     r0,dataarea
        MOV     r1,#"s"
        TEQ     r5,#1
        MOVEQ   r1,#"c"
        TEQ     r5,#2
        MOVEQ   r1,#"t"
        STRB    r1,[r0,#10]
        DebugS  pi,"Command is ",r0
        SWI     XOS_CLI
        BVC     %FT01

        Push    "r0"                    ; Preserve error
        LDR     r0,backdrop_handle
        MOV     r1,#0
        MOV     r2,#0
        MOV     r3,#&80000
        MOV     r4,#&80000
        SWI     XWimp_ForceRedraw
        Pull    "r0"
        SETV

01
        Pull    "PC"

RemoveBackdrop
        BL      ClearBackdrop
        Pull    "PC"

Save
        BL      IntSave_KeyPressed
        Debug   pi,"Save"
        Pull    "PC"


backdrop_command        DCB     "Backdrop -? ",0
        ALIGN


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OpenSelection
;
; Called when user clicks on Selection->Open to open all selected windows/files

OpenSelection

        BL      OpenWindows
        BL      OpenFiles
        BL      ClearSelection
        Pull    "pc"


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OpenWindows
;
; Open all selected iconised windows on the backdrop

OpenWindows Entry

01
        ADR     r1, dataarea
        LDR     r7, iconized_ptr
02
        CMP     r7, #0                   ; Have we reached end of list?
        EXIT    EQ
        LDR     r0, [r7, #ic_window]     ; Get handle of window which this icon is in
        LDR     r2, backdrop_handle
        CMP     r0, r2                   ; Check it's the backdrop
        BNE     %FT05

        STR     r0, [r1]
        LDR     r0, [r7, #ic_icon]
        STR     r0, [r1, #4]
        SWI     XWimp_GetIconState       ; Get state of the icon
        EXIT    VS

        LDR     r0, [r1, #24]
        TST     r0, #is_selected         ; Check it's selected
        BEQ     %FT05
        BL      reopen_window            ; If it is, reopen the window. Go back and start again from
        ;LDR     r0, Window_Icons
        ;SUB     r0, r0, #1               ; Update number of window icons
        ;STR     r0, Window_Icons
        ;LDR     r0, Windows_Selected
        ;SUB     r0, r0, #1
        ;STR     r0, Windows_Selected

        B       %BT01                    ; first icon (because list has changed).

05
        LDR     r7, [r7, #ic_next]       ; Get next icon
        B       %BT02


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OpenFiles
;
; Open all selected files on the backdrop

OpenFiles Entry

        LDR     r7, Icon_list

02
        CMP     r7, #0                   ; is this the last icon?
        EXIT    EQ
        LDR     r0, [r7, #ic_window]
        LDR     r2, backdrop_handle
        CMP     r0, r2                   ; check icon is on backdrop
        BNE     %FT05

        ADR     r1, dataarea
        STR     r0, [r1]
        LDR     r0, [r7, #ic_icon]
        STR     r0, [r1, #4]
        SWI     XWimp_GetIconState       ; get icon's state
        EXIT    VS

        LDR     r0, [r1, #24]
        TST     r0, #is_selected         ; check if icon is selected
        BEQ     %FT05

        ; Filer_Run the file
        ADR     r1, dataarea
        ADR     r0, FilerRunCom          ; Filer_Run
        BL      Copy_r0r1
        ADD     r0, r7, #ic_path         ; filename
        BL      Copy_r0r1
        ADR     r0, dataarea
        SWI     XOS_CLI
        EXIT    VS

05
        LDR     r7, [r7, #ic_next]
        B       %BT02

FilerRunCom        DCB     "Filer_Run -Shift ",0
                   ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; HelpFromApp
;
; Where the icon is an !app,get help on it by seeing if anyone will open its !Help

HelpFromApp
        ROUT
        LDR     r7, Icon_list
        ADR     r1, dataarea
        LDR     r2, backdrop_handle
        STR     r2, [r1, #0]
05
        CMP     r7, #0                   ; is this the last icon?
        Pull    "PC",EQ
        LDR     r0, [r7, #ic_window]
        CMP     r0, r2
        BNE     %FT08                    ; not on the backdrop
        LDR     r0, [r7, #ic_icon]
        STR     r0, [r1, #4]
        SWI     XWimp_GetIconState
        LDR     r0, [r1, #8+16]
        TST     r0, #is_selected         ; see if we've got the one selected icon
        BEQ     %FT08

        ; Filer_Run the file
        ADR     r1, dataarea
        ADR     r0, FilerRunCom          ; Filer_Run
        BL      Copy_r0r1
        ADD     r0, r7, #ic_path         ; filename
        BL      Copy_r0r1
        ADR     r0, plinghelp            ; append help filename
        BL      Copy_r0r1
        ADR     r0, dataarea
        SWI     XOS_CLI
        CLRV                             ; if someone managed to delete the file in the time it took
                                         ; to open the menu,then we'll not worry about it
        B       ClearSelection
08
        LDR     r7, [r7, #ic_next]
        B       %BT05

plinghelp       DCB     ".!Help",0
                ALIGN

        LNK     Tidy.s
