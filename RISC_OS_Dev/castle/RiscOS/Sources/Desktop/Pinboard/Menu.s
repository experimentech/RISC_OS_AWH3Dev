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
; s.Menu
;
; Handle the menus.
;
Menu_Pinboard           *       1
Menu_TinyDirs           *       2
Menu_TinyDirsIcon       *       3


        ^ :INDEX:menu_store, workspace

tinydirs_menu_layout    #       28+24*4
rom_tinydirs_menu
tinydirs_menu_layout    Menu    T1
tm_selectall            Item    M11
tm_clearselection       Item    M12
tm_removeselection      Item    M13
tm_openparent           Item    M14
        DCB 0

        ^ :INDEX:menu_store, workspace

tinydirs_icon_menu_layout    #       28+24*1
rom_tinydirs_icon_menu
tinydirs_icon_menu_layout    Menu    T2
;tim_info                Item    M21, tinydirs_menu_layout
tim_quit                Item    M22, tinydirs_menu_layout
        DCB 0

        ^ :INDEX:menu_store, workspace

pinboard_menu_offset    *       0

 [ show_backdrop_options
pinboard_menu_size      *       28+24*7         ; (FG) size of menu with backdrop options
 |
pinboard_menu_size      *       28+24*5         ; (FG) size of menu without backdrop options
 ]

pinboard_menu_layout    #       pinboard_menu_size
rom_pinboard_menu
pinboard_menu_layout    Menu    T3
pm_selection            Item    M31, selection_menu_layout
pm_selectall            Item    M33, selectall_menu_layout
pm_clear_selection      Item    M34
pm_configure            Item    M35
pm_save                 Item    M36
 [ show_backdrop_options
pm_backdrop             Item    M37, backdrop_menu_layout
pm_nobackdrop           Item    M38
 ]
        DCB 0

backdrop_menu_offset    *       pinboard_menu_offset + pinboard_menu_size
backdrop_menu_size      *       28+24*3
backdrop_menu_layout    #       backdrop_menu_size
rom_backdrop_menu
backdrop_menu_layout    Menu    T4
bm_scaled               Item    M41
bm_tiled                Item    M42
bm_centred              Item    M43
        DCB 0

selection_menu_offset   *       backdrop_menu_offset + backdrop_menu_size
selection_menu_size     *       28+24*4
selection_menu_layout   #       selection_menu_size
rom_selection_menu
selection_menu_layout   Menu    T9
se_tidy                 Item    M91
se_open                 Item    M92
se_remove               Item    M93
se_helpapp              Item    M94
        DCB 0

selectall_menu_offset   *       selection_menu_offset + selection_menu_size
selectall_menu_size     *       28+24*3
selectall_menu_layout   #       selectall_menu_size
rom_selectall_menu
selectall_menu_layout   Menu    T10
sa_files                Item    M101
sa_windows              Item    M102
sa_windowsandfiles      Item    M103
        DCB 0

totalmenusize           *       selectall_menu_offset + selectall_menu_size

 ! 0, "Menu data size is ":CC:(:STR:(totalmenusize)):CC:" bytes"

        ALIGN


create_menu          ROUT

; r1 = window
; r2 = icon
; r10 = x
; r11 = y

        Debug   pi,"Create menu w,i",r1,r2

        Push    "r1-r11"
        BL      IntMenuDeleted
        Pull    "r1-r11"

        LDR     r14,backdrop_handle
        TEQ     r1,r14
        BEQ     create_pinboard_menu
        CMP     r1,#-2
        Pull    "PC",NE

 [ iconise_to_iconbar
        ;LDR     lr, Pinboard_options
        ;TST     lr, #PinboardOption_IconiseToIconBar
        ;BEQ     %FT00

        Push    "r6,r7"
        MOV     r6, r2
        BL      find_iconized
        TEQ     r7, #0
        Pull    "r6,r7"
        Pull    "PC",NE
00
 ]

create_iconbar_menu      ROUT

        LDR     r14,TinyDirs_Handle
        CMP     r2,r14
        BEQ     TinyDirsIcon_Menu



        LDR     r14,TinyDirs_Selected
        CMP     r14,#0
        BNE     %FT01

        Debug   pi,"No selected icons, do soft selection"

        STR     r1,soft_selection_window
        STR     r2,soft_selection_icon

        MOV     r14,r1
        ADR     r1,dataarea
        STR     r14,[r1]
        STR     r2,[r1,#4]
        MOV     r14,#is_selected
        STR     r14,[r1,#8]
        STR     r14,[r1,#12]
        SWI     XWimp_SetIconState
        Pull    "PC",VS

        MOV     r14,#1
        STR     r14,TinyDirs_Selected

recreate_iconbar_menu
01
        ADR     r0, message_file_block + 4
        ADRL    r1, rom_tinydirs_menu
        ADRL    r2, tinydirs_menu_layout
        MOV     r3, #menu_space
        SWI     XMessageTrans_MakeMenus
        Pull    "PC",VS

        LDR     r0,TinyDirs_Selected
        CMP     r0,#1                                   ; Is there more than one selected icon ?
                                                        ; Grey out the 'open parent entry'  if so

        LDR     r14,menu_store+28+tm_openparent*24+8          ;
        ORRNE   r14,r14,#is_shaded
        BICEQ   r14,r14,#is_shaded
        STR     r14,menu_store+28+tm_openparent*24+8

        LDR     r14,menu_store+28+tm_clearselection*24+8          ;
        ORRLT   r14,r14,#is_shaded
        BICGE   r14,r14,#is_shaded
        STR     r14,menu_store+28+tm_clearselection*24+8
        LDR     r14,menu_store+28+tm_removeselection*24+8          ;
        ORRLT   r14,r14,#is_shaded
        BICGE   r14,r14,#is_shaded
        STR     r14,menu_store+28+tm_removeselection*24+8
        BLE     %FT01

        ADR     r0,message_file_block+4                 ; Change to remove selection if more than
        ADRL    r1,remove_selection_token               ; one selected icon.
        ADRL    r2,menu_store+400
        MOV     r3,#menu_space-400
        SWI     XMessageTrans_Lookup
        Pull    "PC",VS


        MOV     r1,#12
        ADD     r1, r1, r3, LSL #4
        LDR     r4, menu_store+16
        CMP     r1, r4
        STRGT   r1, menu_store+16

        DebugS  pi,"String is ",r2
        CMP     r2,#0
        STR     r2,menu_store+28+tm_removeselection*24+12
        ADD     r3,r3,#1
        STR     r3,menu_store+28+tm_removeselection*24+20
        MOV     r2,#0
        STR     r2,menu_store+28+tm_removeselection*24+16

        LDR     r14,menu_store+28+tm_removeselection*24+8
        ORR     r14,r14,#if_indirected
        STR     r14,menu_store+28+tm_removeselection*24+8



01
        ADR     r1,menu_store
        SUB     r2,r10,#144
        MOV     r3,#96+4*44
        SWI     XWimp_CreateMenu

        MOV     r14,#Menu_TinyDirs
        STR     r14,CurrentMenu

        Pull    "PC"


TinyDirsIcon_Menu       ROUT

        ADR     r0, message_file_block + 4
        ADRL    r1, rom_tinydirs_icon_menu
        ADRL    r2, tinydirs_icon_menu_layout
        MOV     r3, #menu_space
        SWI     XMessageTrans_MakeMenus
        Pull    "PC",VS

        ADR     r1,menu_store
        SUB     r2,r10,#64
        MOV     r3,#96+1*44
        SWI     XWimp_CreateMenu

        MOV     r14,#Menu_TinyDirsIcon
        STR     r14,CurrentMenu

        Pull    "PC"

create_pinboard_menu ROUT

        Debug   pi,"Create pinboard menu"

        CMP     r2,#-1
        BEQ     %FT01

        Debug   pi,"Menu on an icon"

        MOV     R6,R2
        BL      find_iconized
        CMP     r7,#0
        BEQ     %FT01

        Push    "r1,r2"                         ; (FG) preserve these registers
        MOV     r0,#OsByte_ScanKeyboard         ; If an iconized window check for Shift to produce app. menu.
        MOV     r1,#&80
        SWI     XOS_Byte
        CMP     r1,#&FF
        Pull    "r1,r2"                         ; (FG) restore these registers
        BEQ     app_menu

01
        LDR     r14,Pinboard_Selected           ; (FG) no of filer-icons selected
        LDR     r0, Windows_Selected            ; (FG) no of iconized windows selected
        CMP     r14,#0                          ; (FG) any filer-icons selected?
        CMPEQ   r0,#0                           ; (FG) or any iconized windows?
        BNE     %FT01                           ; (FG) if so, skip soft-selection

        ;------ Nothing selected, see if there's an icon at the position clicked.
        ; (FG)  If so, soft-select it.

        Push    "r1,r2"                         ; (FG) keep these registers safe
        BL      FindIconBoth                    ; (FG) look through both lists for our icon
        Pull    "r1,r2"                         ; (FG) restore registers
        BNE     %FT01                           ; (FG) no icon found, skip soft-selection

        Debug   pi,"No selected icons, do soft selection"

        MOV     R14,R0                          ; (FG) keep type of icon safe, 1 = iconized window, 2 = filer-icon

        STR     r1,soft_selection_window
        STR     r2,soft_selection_icon

        MOV     r0,r1                           ; (FG)
        ADR     r1,dataarea                     ; (FG)
        STR     r0,[r1]                         ; (FG)
        STR     r2,[r1,#4]                      ; (FG)
        MOV     r0,#is_selected                 ; (FG)
        STR     r0,[r1,#8]                      ; (FG)
        STR     r0,[r1,#12]                     ; (FG)
        SWI     XWimp_SetIconState
        Pull    "PC",VS

        MOV     r0,#1                           ; (FG) say there's 1 icon selected
        CMP     R14,#1                          ; (FG) is it an iconized window?
        STREQ   r0,Windows_Selected             ; (FG) if so, an iconized window is selected
        STRHI   r0,Pinboard_Selected            ; (FG) if not, a filer-icon is selected

recreate_pinboard_menu
01
        ADR     r0, message_file_block + 4
        ADRL    r1, rom_backdrop_menu
        ADRL    r2, backdrop_menu_layout
        MOV     r3, #menu_space
        SWI     XMessageTrans_MakeMenus
        Pull    "PC",VS

        ADR     r0, message_file_block + 4
        ADRL    r1, rom_selection_menu
        ADRL    r2, selection_menu_layout
        MOV     r3, #menu_space
        SWI     XMessageTrans_MakeMenus
        Pull    "PC",VS

        ADR     r0, message_file_block + 4
        ADRL    r1, rom_selectall_menu
        ADRL    r2, selectall_menu_layout
        MOV     r3, #menu_space
        SWI     XMessageTrans_MakeMenus
        Pull    "PC",VS

        ADR     r0, message_file_block + 4
        ADRL    r1, rom_pinboard_menu
        ADR     r2, menu_store
        MOV     r3, #menu_space
        SWI     XMessageTrans_MakeMenus
        Pull    "PC",VS

        LDR     r14,saveas_handle                       ; Point save entry at save box.
        STR     r14,menu_store+28+pm_save*24+4

        Push    "r4"
        ADRL    r0, OpenCfgPath
        MOV     r2, #-1
        MOV     r3, #0
        MOV     r4, #VarType_Expanded
        SWI     XOS_ReadVarVal                          ; Has !Boot been run (to have a !PinSetup)
        Pull    "r4"
        TEQ     r2, #0
        LDR     r14, menu_store+28+pm_configure*24+8
        ORREQ   r14, r14, #is_shaded                    ; Shade the 'Configure...' entry
        BICNE   r14, r14, #is_shaded
        STR     r14, menu_store+28+pm_configure*24+8

        LDR     r0, Window_Icons
        LDR     r14, Iconbar_Icons
        SUB     r0, r0, r14
        LDR     r14,Pinboard_Icons
        ADDS    r14, r14, r0                            ; Are there any icons on the pinboard ?

        LDR     r14, menu_store+28+pm_selectall*24+8
        ORREQ   r14, r14, #is_shaded
        BICNE   r14, r14, #is_shaded
        STR     r14, menu_store+28+pm_selectall*24+8

        LDR     r0,Pinboard_Selected
        LDR     r14, Windows_Selected
        ADDS    r0, r0, r14                             ; Are there any selected icons on the pinboard ?

        LDR     r14, menu_store+28+pm_selection*24+8
        ORREQ   r14, r14, #is_shaded
        BICNE   r14, r14, #is_shaded
        STR     r14, menu_store+28+pm_selection*24+8

        LDR     r14,menu_store+28+pm_clear_selection*24+8       ; Shade 'Clear Selection' if no selected icons.
        ORREQ   r14,r14,#is_shaded
        BICNE   r14,r14,#is_shaded
        STR     r14,menu_store+28+pm_clear_selection*24+8

 [ show_backdrop_options
        CMP     r0,#1                                   ; Is there more than one selected icon ?
        LDR     r14,menu_store+28+pm_backdrop*24+8      ; Shade 'Make Backdrop' if not 1 icon selected.
        ORRNE   r14,r14,#is_shaded
        BICEQ   r14,r14,#is_shaded
        STR     r14,menu_store+28+pm_backdrop*24+8

        BNE     %FT03

        LDR     r0,backdrop_handle
        ADR     r1,dataarea
        MOV     r2,#is_selected
        MOV     r3,#is_selected
        SWI     XWimp_WhichIcon
        Pull    "PC",VS


        LDR     r2,[r1]
        LDR     r1,backdrop_handle
        Debug   pi,"Find icon ",r1,r2
        BL      FindIcon                                ; r2 -> Icon block or 0 if not found.
        BNE     %FT01

        Debug   pi,"Icon found."

        LDR     r2,[r2,#ic_filetype]
        LDR     r14,=&ff9
        TEQ     r2,r14
        BEQ     %FT03

        LDR     r14, =&C85
        TEQ     r2, r14
        BEQ     %FT03

01
        LDR     r14,menu_store+28+pm_backdrop*24+8      ; Shade 'Make Backdrop' if selected icon is not a sprite.
        ORR     r14,r14,#is_shaded
        STR     r14,menu_store+28+pm_backdrop*24+8

03
        LDR     r0,backdrop_options
        TST     r0,#bd_OptionActive
        LDR     r14,menu_store+28+pm_nobackdrop*24+8    ; Shade 'Remove backdrop' if no backdrop.
        ORREQ   r14,r14,#is_shaded
        BICNE   r14,r14,#is_shaded
        STR     r14,menu_store+28+pm_nobackdrop*24+8
 ]

        ; Shade Selection->Remove if any windows are selected
        LDR     r0, Windows_Selected
        LDR     r14, menu_store + selection_menu_offset + 28 + se_remove*24+8
        CMP     r0, #0
        ORRNE   r14, r14, #is_shaded
        BICEQ   r14, r14, #is_shaded
        STR     r14, menu_store + selection_menu_offset + 28 + se_remove*24+8

        ; Shade Selection->Help unless it's an app,AND has help,AND its on the backdrop,AND is the only thing selected
        LDR     r14, menu_store + selection_menu_offset + 28 + se_helpapp*24+8
        ORR     r14, r14, #is_shaded                    ; in most cases it will be shaded
        LDR     r0, Pinboard_Selected
        TEQ     r0, #1
        BNE     %FT09
        Push    "r7"
        LDR     r7, Icon_list
        ADR     r1, dataarea
        LDR     r2, backdrop_handle
        STR     r2, [r1, #0]
05
        CMP     r7, #0                                  ; that's odd,we searched the whole list and never found it
        BEQ     %FT08
        LDR     r0, [r7, #ic_window]
        CMP     r0, r2
        BNE     %FT07                                   ; not on the backdrop
        LDR     r0, [r7, #ic_icon]
        STR     r0, [r1, #4]
        SWI     XWimp_GetIconState
        LDR     r0, [r1, #8+16]
        TST     r0, #is_selected                        ; see if we've got the one selected icon
        BEQ     %FT07
        LDR     r0, [r7, #ic_filetype]
        CMP     r0, #&2000
        BNE     %FT08                                   ; disappointing,it wasn't an app
        Push    "r4-r6,r14"
        ADD     r0, r7, #ic_path                        ; filename
        BL      Copy_r0r1
        ADRL    r0, plinghelp                           ; append help filename
        BL      Copy_r0r1
        ADR     r1, dataarea
        MOV     r0, #OSFile_ReadWithTypeNoPath
        SWI     XOS_File
        Pull    "r4-r6,r14"
        TEQ     r0, #0
        BICNE   r14, r14, #is_shaded                    ; has a !help file of some form
        B       %FT08
07
        LDR     r7, [r7, #ic_next]
        B       %BT05
08
        Pull    "r7"
09
        STR     r14, menu_store + selection_menu_offset + 28 + se_helpapp*24+8
        CLRV

        ; Shade 'Select all->Windows' if no windows on backdrop
        LDR     r0, Window_Icons
        LDR     r14, Iconbar_Icons
        SUB     r0, r0, r14
        LDR     r14, menu_store + selectall_menu_offset + 28 + sa_windows*24+8
        CMP     r0, #0
        ORREQ   r14, r14, #is_shaded
        BICNE   r14, r14, #is_shaded
        STR     r14, menu_store + selectall_menu_offset + 28 + sa_windows*24+8

        ; Shade 'Select all->Files' if no files on backdrop
        LDR     r0, Pinboard_Icons
        LDR     r14, menu_store + selectall_menu_offset + 28 + sa_files*24+8
        CMP     r0, #0
        ORREQ   r14, r14, #is_shaded
        BICNE   r14, r14, #is_shaded
        STR     r14, menu_store + selectall_menu_offset + 28 + sa_files*24+8

        ; Shade 'Select all->Windows and files' if there's either no files or no windows
        LDR     r0, Pinboard_Icons
        CMP     r0, #0
        LDRNE   r0, Window_Icons
        LDR     r14, menu_store + selectall_menu_offset + 28 + sa_windowsandfiles*24+8
        CMP     r0, #0
        ORREQ   r14, r14, #is_shaded
        BICNE   r14, r14, #is_shaded
        STR     r14, menu_store + selectall_menu_offset + 28 + sa_windowsandfiles*24+8

        ADR     r1,menu_store
        SUBS    r2,r10,#64
        MOVMI   r2,#0
        MOV     r3,r11
        SWI     XWimp_CreateMenu

        MOV     r14,#Menu_Pinboard
        STR     r14,CurrentMenu

        Pull    "PC"

; ----------------------------------------------------------------------------------------------------------------------
; app_menu, send menu message to application.
;
app_menu
        ADR     r1,dataarea
        MOV     r2,r10
        MOV     r3,r11
        MOV     r4,#2
        LDR     r5,[r7,#w_window_handle]
        MOV     r6,#-1
        STMIA   r1,{r2-r6}
        MOV     r0,#6      ; fake mouse event
        LDR     r2,[r7,#w_task]
        SWI     XWimp_SendMessage

        Pull    "PC"

remove_selection_token  DCB     "M34s",0
        ALIGN

        LNK     MenuSelect.s
