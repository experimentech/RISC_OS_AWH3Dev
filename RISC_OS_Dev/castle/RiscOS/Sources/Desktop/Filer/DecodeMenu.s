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
r
        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 -> wimp_eventstr in userdata

DecodeMenu Entry

        MOV     r14, #1                 ; Allow menu to be reopened if EXTend
        STRB    r14, menu_reopen        ; was used to select menu item
                                        ; Individual items may override this

        LDR     r0, sel_whandle         ; If this has changed, we can do nowt
        TEQ     r0, #Nowt
 [ debug
 BNE %FT00
 DLINE "Selection handle has been zapped in the background. Goodbye"
00
 ]
        EXIT    EQ


        BL      FindDir
        EXIT    NE                      ; [Waarg! Dir has vanished]


        BL      InitSelection           ; Doesn't matter if no selection here


        ADR     r2, userdata
 [ debug
 LDR r14, [r2]
 DREG r14, "menu_select: selections ",cc
 LDR r14, [r2, #4]
 DREG r14, ", ",cc
 LDR r14, [r2, #8]
 DREG r14, ", "
 ]

; Clicked in main dirviewer menu

        LDR     r14, [r2]               ; Top level despatch
 [ hastiny
        CMP     r14, #mo_main_tiny
        BEQ     DecodeMenu_Tiny
 ]

 [ :LNOT: actionwind
        CMP     r14, #mo_main_count
        BEQ     DecodeMenu_Count
 ]

 [ AddSetDirectory
        CMP     r14, #mo_main_setdir
        BEQ     DecodeMenu_SetDir
 ]

        CMP     r14, #mo_main_refresh
        BEQ     DecodeMenu_Refresh

        CMP     r14, #mo_main_openparent
        BEQ     DecodeMenu_OpenParent

        ;CMP     r14, #mo_main_newdir
        ;BEQ     DecodeMenu_NewDir

        CMP     r14, #mo_main_selectall
        BEQ     DecodeMenu_SelectAll

        CMP     r14, #mo_main_clearsel
        BEQ     DecodeMenu_ClearSel

        LDR     r0, [r2, #4]            ; All subsequent ones don't like
        CMP     r0, #-1                 ; having their 'menu =>' entries
        EXIT    EQ                      ; selected. Also want r0 = subselection

        CMP     r14, #mo_main_filexxx
        BEQ     DecodeMenu_File

 [ version >= 117
 |
  [ version >= 114
        CMP     r14, #mo_main_find
        BEQ     DecodeMenu_Find
  ]
 ]

        CMP     r14, #mo_main_options
        BEQ     DecodeMenu_Options

        CMP     r14, #mo_main_display
        EXIT    NE                      ; [ignore spurious selections]

; .............................................................................
; In    r0 = subselection

DecodeMenu_Display ROUT ; NOENTRY

 [ debug
 DLINE "Display menu select"
 ]
 ASSERT mo_display_sortname > mo_display_fullinfo
 [ actionwind
  [ version >= 116
  |
        CMP     r0, #mo_display_showaction
        BEQ     DecodeMenu_ShowAction
  ]
 ]
;        LDRB    r2, [r4, #d_viewmode]
;        CMP     r0, #mo_display_sortname ; first sorting entry in menu
;        BICLT   r2, r2, #db_displaymode
;        ORRLT   r2, r2, r0, LSL #dbb_displaymode
;        SUBGE   r0, r0, #mo_display_sortname ; reduce sort mode to 0..3
;        BICGE   r2, r2, #db_sortmode
;        ORRGE   r2, r2, r0, LSL #dbb_sortmode

        LDRB    r2, [r4, #d_viewmode]
        CMP     r0, #mo_display_sortorder ; toggle sort order
        EOREQ   r2, r2, #db_sortorder
        MOVEQ   r0, #-1
        CMP     r0, #mo_display_sortnumeric ; toggle numeric order
        EOREQ   r2, r2, #db_sortnumeric
        MOVEQ   r0, #-1
        CMP     r0, #mo_display_sortname ; first sorting entry in menu
        BICLO   r2, r2, #db_displaymode
        ORRLO   r2, r2, r0, LSL #dbb_displaymode
        SUBGE   r0, r0, #mo_display_sortname ; reduce sort mode to 0..3
        BICGE   r2, r2, #db_sortmode
        ORRGE   r2, r2, r0, LSL #dbb_sortmode

        MOV     r3, #sorting_cmos_bits :OR: display_cmos_bits

 [ OptionsAreInRAM
        STRB    r2, layout_options
 |
       [ (version < 135) :LOR: (version >= 136)
        BL      WriteCMOSBits           ; keep this mode from now on
       ]
 ]

        LDRB    r14, [r4, #d_viewmode]
        CMP     r2, r14
        EXIT    EQ                      ; no change

        STRB    r2, [r4, #d_viewmode]

        MOV     r1, r4                  ; r1 -> dirviewer block
        BL      SortDir                 ; just in case

        BL      ForceReopen
        EXIT                            ; Leave selection unaffected

 [ actionwind
  [ version >= 116
  |
; .............................................................................
DecodeMenu_ShowAction ROUT ; NOENTRY
        SUB     sp, sp, #ms_data+4

        MOV     r14, #0                  ; yourref = 0 -> start of sequence
        STR     r14, [sp, #ms_yourref]

        MOV     r14, #1                 ; control bring windows to front
        STR     r14, [sp, #ms_data + 0]

        LDR     r14, =Message_FilerControlAction
        STR     r14, [sp, #ms_action]

        MOV     r1, #ms_data + 4

        STR     r1, [sp, #ms_size]

        MOV     r0, #User_Message
        MOV     r1, sp
        MOV     r2, #0                  ; Broadcast it
        MOV     r3, #0                  ; icon handle

        SWI     XWimp_SendMessage

        ADD     sp, sp, #ms_data+4
        EXIT
  ]
 ]


 [ OptionsAreInRAM
; .............................................................................
; DecodeMenu_Options
;
; Ursula version does not use CMOS
;
; In    r0 = subselection

DecodeMenu_Options ROUT ; NOENTRY

        LDRB    r2, fileraction_options

        CMP     r0, #mo_options_confirm ; Invert current sense
        EOREQ   r2, r2, #Action_OptionConfirm
        CMP     r0, #mo_options_verbose
        EOREQ   r2, r2, #Action_OptionVerbose
        CMP     r0, #mo_options_force
        EOREQ   r2, r2, #Action_OptionForce
        CMP     r0, #mo_options_newer
        EOREQ   r2, r2, #Action_OptionNewer
        CMP     r0, #mo_options_confirmdeletes
        EOREQ   r2, r2, #Action_OptionConfirmDeletes
        CMP     r0, #mo_options_faster
        EOREQ   r2, r2, #Action_OptionFaster

        CMP     r0, #mo_options_confirmdeletes
        BICEQ   r2, r2, #Action_OptionConfirm
        CMP     r0, #mo_options_confirm
        BICEQ   r2, r2, #Action_OptionConfirmDeletes

        STRB    r2, fileraction_options

        ; Depending on the new state of Verbose, send a FilerControlAction message
        SUB     sp, sp, #ms_data+4
        MOV     r14, #0                  ; yourref = 0 -> start of sequence
        STR     r14, [sp, #ms_yourref]
        TST     r2, #Action_OptionVerbose
        MOVEQ   r14, #2                 ; control close windows
        MOVNE   r14, #1                 ; control bring windows to front
        STR     r14, [sp, #ms_data + 0]
        LDR     r14, =Message_FilerControlAction
        STR     r14, [sp, #ms_action]
        MOV     r1, #ms_data + 4
        STR     r1, [sp, #ms_size]
        MOV     r0, #User_Message
        MOV     r1, sp
        MOV     r2, #0                  ; Broadcast it
        MOV     r3, #0                  ; icon handle
        SWI     XWimp_SendMessage

        ADD     sp, sp, #ms_data+4
        EXIT                            ; Leave selection unaffected
 ]


 [ :LNOT: OptionsAreInRAM
; .............................................................................
; DecodeMenu_Options
;
; Pre-ursula function to decode Options menu and update CMOS.
;
; In    r0 = subselection

DecodeMenu_Options ROUT ; NOENTRY

 [ debug
 DLINE "Options menu select"
 ]
        BL      ReadCMOSBits
        MOV     r2, r3

        CMP     r0, #mo_options_confirm ; Invert current sense
        EOREQ   r2, r2, #confirm_cmos_bit

        CMP     r0, #mo_options_verbose
        EOREQ   r2, r2, #verbose_cmos_bit

 [ actionwind
        CMP     r0, #mo_options_force
        EOREQ   r2, r2, #force_cmos_bit

        CMP     r0, #mo_options_newer
        EOREQ   r2, r2, #newer_cmos_bit
 ]

 [ actionwind
        MOV     r3, #verbose_cmos_bit :OR: confirm_cmos_bit :OR: force_cmos_bit :OR: newer_cmos_bit
 |
        MOV     r3, #verbose_cmos_bit :OR: confirm_cmos_bit
 ]
        BL      WriteCMOSBits           ; keep this mode from now on
        EXIT    VS

        SUB     sp, sp, #ms_data+4

        MOV     r14, #0                  ; yourref = 0 -> start of sequence
        STR     r14, [sp, #ms_yourref]

        TST     r2, #verbose_cmos_bit
        MOVEQ   r14, #2                 ; control close windows
        MOVNE   r14, #1                 ; control bring windows to front
        STR     r14, [sp, #ms_data + 0]

        LDR     r14, =Message_FilerControlAction
        STR     r14, [sp, #ms_action]

        MOV     r1, #ms_data + 4

        STR     r1, [sp, #ms_size]

        MOV     r0, #User_Message
        MOV     r1, sp
        MOV     r2, #0                  ; Broadcast it
        MOV     r3, #0                  ; icon handle

        SWI     XWimp_SendMessage

        ADD     sp, sp, #ms_data+4

        EXIT                            ; Leave selection unaffected
 ]



 [ version >= 117
 |
  [ version >= 114
; .............................................................................

DecodeMenu_Find ROUT ; NOENTRY
        MOV     r0, #Filer_Action_Memory_Others
        BL      StartActionWindow
        BVS     %FT01
        TEQ     r0, #0
      [ version >= 138
        ADRLEQ  r0,ErrorBlock_Global_NoRoom
        BLEQ    LookupError
        EXIT    VS
      |
        BEQ     %FT01
      ]
        ADRL    r1, anull
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT01
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedFile
        BVS     %FT01
        ADRL    r1, ms_writeable_leafname
        BL      strlen
        ADD     r4, r3, #1
        MOV     r3, r1
        MOV     r1, #Action_Find
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        SWI     XFilerAction_SendStartOperation
01
   [ clearsel_find
        MOV     r2, #Nowt
        BL      ClearAllSelections
   ]
        EXIT
  ]
 ]

 [ version >= 138
ErrorBlock_Global_NoRoom
        DCD     0
        DCB     "NoMem",0
        ALIGN
 ]

; .............................................................................
; In    r0 = subselection

DecodeMenu_File ROUT ; NOENTRY

 [ debug
 DLINE "File menu select"
 ]
        CMP     r0, #mo_file_count      ; Despatch at this level
        BEQ     DecodeMenu_File_Count

        CMP     r0, #mo_file_delete
        BEQ     DecodeMenu_File_Delete

        CMP     r0, #mo_file_help
        BEQ     DecodeMenu_File_Help

 [ stamp_option
        CMP     r0, #mo_file_stamp
        BEQ     DecodeMenu_File_Stamp
 ]

        LDR     r14, [r2, #8]           ; All subsequent ones don't like
        CMP     r14, #-1                ; having their 'menu =>' entries
        EXIT    EQ                      ; selected

 [ settype
        CMP     r0, #mo_file_settype
        BEQ     DecodeMenu_File_SetType
 ]
 [ version >= 113
        CMP     r0, #mo_file_find
        BEQ     DecodeMenu_File_Find
 ]

        CMP     r0, #mo_file_rename
        BEQ     DecodeMenu_File_Rename

 [ version >= 117
        CMP     r0, #mo_file_access
        BEQ     DecodeMenu_File_Access
 ]

 [ version >= 113
        EXIT
 |

        CMP     r0, #mo_file_copy
        EXIT    NE                      ; [ignore spurious selections]

; .............................................................................
; Copy xxx as zzz in same dir

DecodeMenu_File_Copy ROUT ; NOENTRY

  [ actionwind
      [ version >= 138                  ; Check if configuration calls for filer_action
        MOV     R0,#&A1
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0
        TST     R2,#InteractiveCopyCMOSBit
        MOVNE   r0,#0
        MOVEQ   r0, #Filer_Action_Memory_CopyRename
        BLEQ    StartActionWindow
      |
      [ version >= 113
        MOV     r0, #Filer_Action_Memory_CopyRename
      ]
        BL      StartActionWindow
      ]
        BVS     %FT01
        TEQ     r0, #0
        BEQ     %FT01
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT01
        BL      SendSelectedFiles
        BVS     %FT01
        ADR     r1, ms_writeable_leafname
        BL      strlen
        ADD     r4, r3, #1
        MOV     r3, r1
        MOV     r1, #Action_CopyLocal
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        SWI     XFilerAction_SendStartOperation
        B       %FT99

01      ;
        CLRV
  ]

        addr    r2, star_copy_prefix    ; 'Copy menudir.leafname menudir.newname opt1 opt2'
        BL      PutSelNamesInBuffer
        addr    r2, aspace              ; +space
        BL      strcat
        LDR     r2, sel_dirname         ; +dirname
        BL      strcat_excludingspaces
        ADR     r2, ms_writeable_leafname ; +newleafname
        BL      AppendLeafnameToDirname
        addr    r2, star_copy_postfix   ; +static options
        BL      strcat
        addr    r2, copydrag_postfix    ; +dynamic options
        BL      strcat
        BL      AppendConfirmAndVerbose

        MOV     r0, r1
        addr    r1, copy_commandtitle
        BL      DoOSCLIInBoxLookup      ; SMC: look up command window title

99      ;
  [ clearsel_file_copy
        MOV     r2, #Nowt               ; That may force a recache of this dir so we may as well
        BL      ClearAllSelections      ; remove all selections
  ]
        EXIT
 ]

; .............................................................................
; Rename xxx as zzz in same dir

DecodeMenu_File_Rename ROUT ; NOENTRY

        ; Is force on?
        [ OptionsAreInRAM
        LDRB    r3, fileraction_options
        TST     r3, #Action_OptionForce
        |
        BL      ReadCMOSBits
        TST     r3, #force_cmos_bit
        ]
        BEQ     %FT10

        ; Is the file locked?
        LDR     r4, sel_fileblock
        LDR     r5, [r4, #df_attr]
        TST     r5, #locked_attribute
        BNE     %FT20

10      ; File isn't locked or force is off - it's your problem now
        ADR     r2, star_rename_prefix  ; 'Rename menudir.leafname menudir.newname'
        BL      PutSelNamesInBuffer
        addr    r2, aspace              ; +space
        BL      strcat
        LDR     r2, sel_dirname         ; +dirname
        BL      strcat_excludingspaces
        ADRL    r2, ms_writeable_leafname ; +newleafname
        BL      AppendLeafnameToDirname

        MOV     r0, r1
        ADR     r1, rename_commandtitle
        BL      DoOSCLIInBoxLookup      ; SMC: look up command window title

 [ clearsel_file_rename
        MOV     r2, #Nowt               ; That may force a recache of this dir so we may as well
        BL      ClearAllSelections      ; remove all selections
 ]
        EXIT

20      ; Force on and file is locked - its time to do some faffing

        ; Drop the access - don't care if it fails
        ADRL    r2, anull
        BL      PutSelNamesInBuffer
        MOV     r0, #OSFile_WriteAttr
        BIC     r5, r5, #locked_attribute
        SWI     XOS_File

        ; Do the rename - error box produced by this
        MOV     r0, r1
        BL      strlen
        ADD     r1, r1, r3
        ADD     r1, r1, #1
        LDR     r2, sel_dirname
        BL      strcpy_excludingspaces
        ADRL    r2, ms_writeable_leafname ; +newleafname
        BL      AppendLeafnameToDirname
        MOV     r2, r1
        MOV     r1, r0
        MOV     r0, #FSControl_Rename
        SWI     XOS_FSControl
        MOVVS   r6, r0

        ; Put the access back
        MOV     r1, r2
        MOV     r0, #OSFile_WriteAttr
        ORR     r5, r5, #locked_attribute
        BVS     %FT30
        SWI     XOS_File
        CLRV                            ; Ignore any error
        EXIT
30
        SWI     XOS_File
        MOV     r0, r6                  ; Propagate the rename error
        SETV
        EXIT

rename_commandtitle
        DCB     "TRename", 0

star_rename_prefix
        DCB     "Rename ",0
        ALIGN

 [ version >= 117
; .............................................................................
; Set the access of an object

DecodeMenu_File_Access  ROUT ; NOENTRY
      [ debugaccess
        DLINE   "Set access"
      ]

        LDR     r0, [r2, #8]
        TEQ     r0, #mo_file_access_locked
        LDREQ   r6, =&ffff0000 :AND: :NOT: (locked_attribute:SHL:16) :AND: :NOT: (write_attribute:SHL:16) :AND: :NOT: (public_write_attribute:SHL:16) :OR: locked_attribute
        MOVEQ   r7, #Action_OptionRecurse
        BEQ     %FT10
        TEQ     r0, #mo_file_access_unlocked
        LDREQ   r6, =&ffff0000 :AND: :NOT: (locked_attribute:SHL:16) :AND: :NOT: (write_attribute:SHL:16) :OR: write_attribute
        MOVEQ   r7, #Action_OptionRecurse
        BEQ     %FT10
        TEQ     r0, #mo_file_access_publicread
        LDREQ   r6, =&ffff0000 :AND: :NOT: (public_read_attribute:SHL:16) :OR: public_read_attribute
        MOVEQ   r7, #Action_OptionRecurse
        BEQ     %FT10
        TEQ     r0, #mo_file_access_nopublicread
        LDREQ   r6, =&ffff0000 :AND: :NOT: (public_read_attribute:SHL:16) :AND: :NOT: (public_write_attribute:SHL:16)
        MOVEQ   r7, #Action_OptionRecurse
        BEQ     %FT10
        EXIT

10      ; Set the access from the menu
        LDR     r0, sel_whandle         ; If this has changed, we can do nowt
        TEQ     r0, #Nowt
        BEQ     %FT95                   ; We may have to kill menu tree though!

        BL      FindDir
        BLEQ    InitSelection
        BNE     %FT96                   ; [Waarg! Dir/Sel vanished, kill tree]

        STR     r6, userdata
      [ version >= 138                  ; Check if configuration calls for filer_action
        MOV     R0,#&A1
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0
        TST     R2,#InteractiveCopyCMOSBit
        MOVNE   r0,#0
        MOVEQ   r0, #Filer_Action_Memory_Others
        BLEQ    StartActionWindow
      |
        MOV     r0, #Filer_Action_Memory_Others
        BL      StartActionWindow
      ]
        BVS     %FT70
        TEQ     r0, #0
        BEQ     %FT70
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT70
        BL      SendSelectedFiles
        BVS     %FT70
        MOV     r1, #Action_Setting_Access
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        ORR     r2, r2, r7
        ADR     r3, userdata
        MOV     r4, #4
        SWI     XFilerAction_SendStartOperation
        B       %FT95
70      ;
        CLRV
      [ debugaccess
        DLINE   "Do by steam"
      ]

90      ; Filer Action window failed, do it by steam
        TEQ     r5, #Nowt
        BEQ     %FT95                   ; [finished]

      [ debugaccess
        DLINE   "Found selection"
      ]

        LDRB    r14, [r5, #df_type]     ; Only apply to right object types
        TEQ     r14, r7
;        BNE     %FT94

      [ debugaccess
        DLINE   "Object types match"
      ]

 [ clearsel_file_access
        BL      ClearSelectedItem       ; Only clear selected items we're using
                                        ; Can do this here; not a CommandWindow
 ]
        ;wsaddr  r1, dirnamebuffer, VC
        LDRVC   r1, dirnamebuffer
        LDRVC   r2, sel_dirname
        BLVC    strcpy_excludingspaces
        LDRVC   r2, sel_leafname
        BLVC    AppendLeafnameToDirname

      [ version >= 148
        Push    "r1-r4"
        MOVVC   r0, #OSFile_ReadInfo
        SWIVC   XOS_File
        Pull    "r1-r4"                 ; r5 = old access setting.

 [ debugaccess
        DREG    r5,"Old access is "
        DREG    r6,"Mask "
 ]
      ]

        MOVVC   r0, #OSFile_WriteAttr
      [ version >= 148
        MOVVC   r14,r6,LSR #16          ; Bits to ignore
        ANDVC   r5,r5,r14               ; Correct in bits to ignore, 0 in others
        BICVC   r14,r6,r14              ; Bottom 16 bits are access to set (Clear all bits to ignore)
        MOVVC   r14,r14,ASL #16
        EORVC   r5,r5,r14,LSR #16
 [ debugaccess
        DREG    r5,"New access is "
 ]
      |
        MOVVC   r5, r6                  ; THIS IS NOT GOOD (RM)
      ]
        SWIVC   XOS_File
        BVS     %FT96                   ; [error, kill menu tree]

94      BL      GetSelection
        B       %BT90

 [ version >= 118
95      ; Its easy to recreate the menus
        EXIT
 |
95      ; Drop through to nobble everything so that we don't have
        ; to mess about redoing the menu ticks dynamically.
 ]
96      BL      NobbleMenuSelection     ; Remove context sensitive selection
        MOV     r0, #0
        STRB    r0, menu_reopen
        EXIT                            ; Accumulates V, r0 preserving
 ]

 [ version >= 113
; .............................................................................
; Find object in selection

DecodeMenu_File_Find    ROUT ; NOENTRY

        MOV     r0, #Filer_Action_Memory_Others
        BL      StartActionWindow
        BVS     %FT01
        TEQ     r0, #0
      [ version >= 138
        ADREQL  r0,ErrorBlock_Global_NoRoom
        BLEQ    LookupError
        EXIT    VS
      |
        BEQ     %FT01
      ]
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT01
        BL      SendSelectedFiles
        BVS     %FT01
      [ version >= 155
        ADRL    r1, ms_writeable_findname
      |
        ADRL    r1, ms_writeable_leafname
      ]
        BL      strlen
        ADD     r4, r3, #1
        MOV     r3, r1
        MOV     r1, #Action_Find
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        SWI     XFilerAction_SendStartOperation
01
  [ clearsel_file_find
        MOV     r2, #Nowt
        BL      ClearAllSelections
  ]
        EXIT
 ]

; .............................................................................
; Delete xxx in this dir

DecodeMenu_File_Delete ROUT ; NOENTRY

 [ actionwind
      [ version >= 138                  ; Check if configuration calls for filer_action
        MOV     R0,#&A1
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0
        TST     R2,#InteractiveCopyCMOSBit
        MOVNE   r0,#0
        MOVEQ   r0, #Filer_Action_Memory_Others
        BLEQ    StartActionWindow
      |
      [ version >= 113
        MOV     r0, #Filer_Action_Memory_Others
      ]
        BL      StartActionWindow
      ]
        BVS     %FT01
        TEQ     r0, #0
        BEQ     %FT01
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT01
        BL      SendSelectedFiles
        BVS     %FT01
        MOV     r1, #Action_Deleting
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        MOV     r3, #0
        MOV     r4, #0
        SWI     XFilerAction_SendStartOperation
        B       %FT99

01      ;
        CLRV
 ]

        ADR     r0, delete_commandtitle
        BL      messagetrans_lookup     ; SMC: look up command window title
        SWI     XWimp_CommandWindow
        EXIT    VS

        MOV     r7, #0                  ; Close command window with prompt

05      CMP     r5, #Nowt
        BEQ     %FT90                   ; [finished]

        ADR     r2, star_wipe_prefix    ; 'Wipe menudirname.leafname opt'
        BL      PutSelNamesInBuffer
        addr    r2, aspace              ; +space
        BL      strcat
        ADR     r2, star_wipe_postfix
        BL      strcat
 [ version >= 114
        BL      AppendConfirmVerboseAndForce
 |
        BL      AppendConfirmAndVerbose
 ]

        MOVVC   r0, r1
        SWIVC   XOS_CLI
        BVS     %FT50

        BL      GetSelection
        B       %BT05


50      BL      LocalReportError
        MOV     r7, #-1                 ; Close command window without prompt

90      MOV     r0, r7
        SWI     XWimp_CommandWindow

99      ;
 [ clearsel_file_delete
        MOV     r2, #Nowt               ; That may force a recache of this dir so we may as well
        BL      ClearAllSelections      ; remove all selections
 ]
        EXIT


delete_commandtitle
        DCB     "TDelete", 0

star_wipe_prefix
        DCB     "Wipe ",0

star_wipe_postfix
        DCB     "R", 0                  ; Don't alter F(orce)
                                        ; CMOS set for C(onfirm),V(erbose)


count_commandtitle
        DCB     "TCount", 0

star_count_prefix
        DCB     "Count ", 0

star_count_postfix
        DCB     "~CRV", 0

        ALIGN

; .............................................................................
; Count xxx in this dir

DecodeMenu_File_Count ROUT ; NOENTRY

 [ actionwind
      [ version >= 138                  ; Check if configuration calls for filer_action
        MOV     R0,#&A1
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0
        TST     R2,#InteractiveCopyCMOSBit
        MOVNE   r0,#0
        MOVEQ   r0, #Filer_Action_Memory_Others
        BLEQ    StartActionWindow
      |
      [ version >= 113
        MOV     r0, #Filer_Action_Memory_Others
      ]
        BL      StartActionWindow
      ]
        BVS     %FT01
        TEQ     r0, #0
        BEQ     %FT01
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT01
        BL      SendSelectedFiles
        BVS     %FT01
        MOV     r1, #Action_Counting
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        MOV     r3, #0
        MOV     r4, #0
        SWI     XFilerAction_SendStartOperation
        B       %FT99

01      ;
        CLRV
 ]
        ADR     r0, count_commandtitle
        BL      messagetrans_lookup     ; SMC: look up command window title
        SWI     XWimp_CommandWindow
        EXIT    VS

        MOV     r7, #0                  ; Close command window with prompt

05      CMP     r5, #Nowt
        BEQ     %FT90                   ; [finished]

        ADR     r2, star_count_prefix   ; 'Count dirname.leafname opt'
        BL      PutSelNamesInBuffer
        addr    r2, aspace              ; +space
        BL      strcat
        ADR     r2, star_count_postfix
        BL      strcat

        MOV     r0, r1
        SWI     XOS_CLI
        BVS     %FT50

        BL      GetSelection
        B       %BT05


50      BL      LocalReportError
        MOV     r7, #-1                 ; Close command window without prompt

90      MOV     r0, r7
        SWI     XWimp_CommandWindow

99      ;
 [ clearsel_file_count
        MOV     r2, #Nowt               ; That may force a recache of this dir so we may as well
        BL      ClearAllSelections      ; remove all selections
 ]
        EXIT

 [ stamp_option
; .............................................................................
; Stamp files

DecodeMenu_File_Stamp ROUT ; NOENTRY
      [ version >= 113
        MOV     r0, #Filer_Action_Memory_Others
      ]
        BL      StartActionWindow
        EXIT    VS
        TEQ     r0, #0
      [ version >= 138
        ADREQL  r0,ErrorBlock_Global_NoRoom
        BLEQ    LookupError
        EXIT    VS
      |
        EXIT    EQ
      ]
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        EXIT    VS
        BL      SendSelectedFiles
        EXIT    VS
        MOV     r1, #Action_Stamping
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        MOV     r4, #0
        SWI     XFilerAction_SendStartOperation
        EXIT    VS

  [ clearsel_file_stamp
        MOV     r2, #Nowt
        BL      ClearAllSelections      ; This is preferred to leaving
                                        ; selection around >>>a186<<<
  ]
        EXIT
 ]

 [ settype
; .............................................................................
; Set file type

DecodeMenu_File_SetType ROUT ; NOENTRY
        MOV     r0, #FSControl_FileTypeFromString
        ADR     r1, ms_writeable_filetype
        SWI     XOS_FSControl
        EXIT    VS
 [ actionwind
      [ version >= 138                  ; Check if configuration calls for filer_action
        Push    "r1-r2"
        MOV     R0,#&A1
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0
        TST     R2,#InteractiveCopyCMOSBit
        Pull    "r1-r2"
        MOVNE   r0,#0
        MOVEQ   r0, #Filer_Action_Memory_Others
        BLEQ    StartActionWindow
      |
      [ version >= 113
        MOV     r0, #Filer_Action_Memory_Others
      ]
        BL      StartActionWindow
      ]
        BVS     %FT01

        TEQ     r0, #0
        BEQ     %FT01

        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT01

        BL      SendSelectedFiles
        BVS     %FT01

        STR     r2, userdata
        MOV     r1, #Action_Setting_Type
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        ADR     r3, userdata
        MOV     r4, #4
        SWI     XFilerAction_SendStartOperation
        B       %FT95
01
        CLRV                            ; Can't use filer action, fall back to command window mode
 ]
        STR     r2, userdata            ; Retain decoded type
        ADR     r0, settype_commandtitle
        BL      messagetrans_lookup     ; SMC: look up command window title
        SWI     XWimp_CommandWindow
        EXIT    VS

        MOV     r7, #0                  ; Close command window with prompt
        MOV     r6, r5                  ; Keep a copy of the type and selection

05      CMP     r5,#Nowt
        BEQ     %FT90                   ; [finished]

        LDRB    r14, [r5, #df_type]     ; Only set filetype on files
        TEQ     r14, #dft_file
      [ version >=143  :LAND: version<150
        TEQNE   r14,#dft_partition      ; And on partitions.
      ]
        BNE     %FT49

        ADR     r2, star_settype_prefix ; 'SetType dirname.leafname type'
        BL      PutSelNamesInBuffer
        addr    r2, aspace              ; +space
        BL      strcat
        ADR     r2, ms_writeable_filetype ; +newtype
        BL      strcat

        MOV     r0, r1
        SWI     XOS_CLI
        BVS     %FT50

49      BL      GetSelection
        B       %BT05

50      BL      LocalReportError
        MOV     r7, #-1                 ; Close command window without prompt

90      MOV     r0, r7
        SWI     XWimp_CommandWindow
        MOV     r5, r6                  ; Restore start of selection

95      CMP     r5,#Nowt
        BEQ     %FT99                   ; [finished]

        LDRB    r14, [r5, #df_type]     ; Set filetype only applies to files
        TEQ     r14, #dft_file
        BEQ     %FT97
        BL      GetSelection
        B       %BT95

97      LDR     r14, userdata           ; Stamp the cached copy of the first found file in the selection.
        MOV     r14, r14, LSL#8         ; This is needed because a right click on the menu will recreate the menu
        ORR     r14, r14, #&FC000001    ; before the dir has been recached after a wimp poll, leaving it out of sync
        ORR     r14, r14, #&03F00000    ; with the copy on disc. The time stamp is set to &01xxxxxxxx just incase the
        STR     r14, [r5, #df_load]     ; file was previously unstamped, it's proper value will be recached later.
99
 [ clearsel_file_settype
        MOV     r2, #Nowt               ; That may force a recache of this dir so we may as well
        BL      ClearAllSelections      ; remove all selections
 ]
        EXIT


settype_commandtitle
        DCB     "TType", 0

star_settype_prefix
        DCB     "SetType ",0
        ALIGN
 ]

; .............................................................................
; Run !Help for application

DecodeMenu_File_Help ROUT ; NOENTRY

05      CMP     r5, #Nowt
        BEQ     %FT90                   ; [finished]

        MOV     r14, #Nowt              ; Don't close any dirs when we run this
        STR     r14, dirtoclose

        addr    r2, anull               ; 'dirname.leafname'
        BL      PutSelNamesInBuffer

        addr    r2, plinghelp           ; +!Help
        LDR     r3, [r5, #df_helptype]
        MOV     r4, #0                  ; Broadcast
        MOV     r5, #0                  ; ihandle irrelevant
        BL      SendDataOpenMessage
        BVS     %FT90

        BL      GetSelection
        B       %BT05

90
 [ clearsel_file_help
        MOV     r2, #Nowt               ; That may force a recache of this dir so we may as well
        BL      ClearAllSelections      ; remove all selections
 ]
        EXIT

; .............................................................................
; In    r0 = subselection

DecodeMenu_NewDir ROUT ; NOENTRY

         LDR    r1, newdirbox_text
         ADR    r2, cdir_click_name
         BL     strcpy
         BL     click_newdir_click

         EXIT

cdir_click_name DCB "Directory",0

; .............................................................................
; Count the given directory

 [ :LNOT: actionwind
DecodeMenu_Count ROUT ; NOENTRY

 [ debug
 DLINE "Count menu select"
 ]
        ;ADR     r1, dirnamebuffer       ; 'Count menudir opt'
        LDR     r1, dirnamebuffer       ; 'Count menudir opt'
        addr    r2, star_count_prefix
        BL      strcpy
        LDR     r2, sel_dirname
        BL      strcat_excludingspaces
        addr    r2, aspace
        BL      strcat
        addr    r2, star_count_postfix
        BL      strcat

        MOV     r0, r1
        addr    r1, count_commandtitle
        BL      DoOSCLIInBoxLookup      ; SMC: look up command window title
        EXIT                            ; Leave selection around
 ]

; .............................................................................

DecodeMenu_ClearSel ROUT ; NOENTRY

        MOV     r2, #Nowt               ; Clear 'em all everywhere
        BL      ClearAllSelections

        MOVVC   r14, #0                 ; We have cleared the selections
        STRVCB  r14, menu_causedselection
        EXIT

; .............................................................................

DecodeMenu_SelectAll ROUT ; NOENTRY

        MOV     r2, r4                  ; Clear 'em all elsewhere
        BL      ClearAllSelections
        EXIT    VS

        MOV     r14, #0                 ; WE have caused this selection
        STRB    r14, menu_causedselection

        LDR     r3, [r4, #d_nfiles]
        TEQ     r3, #0
        EXIT    EQ                      ; [no files that could need updating]

        ADD     r5, r4, #d_headersize

20      LDRB    r14, [r5, #df_state]
 [ debug
 DREG r5,"Looking at file "
 ]
        TST     r14, #dfs_selected
        BEQ     %FT40                   ; [not already selected]

        SUBS    r3, r3, #1
        ADDNE   r5, r5, #df_size
        BNE     %BT20                   ; Process next file

        EXIT


; Got mods in this directory, so will have to redraw it

30      LDRB    r14, [r5, #df_state]
 [ debug
 DREG r5,"Looking at file "
 ]
        TST     r14, #dfs_selected
        TEQNE   R3,#1                   ; last file?
        BNE     %FT50                   ; [already selected]

40      ORR     r14, r14, #dfs_selected ; ep for above
        STRB    r14, [r5, #df_state]
 [ debug
 DREG r5, "deselecting file "
 ]
        TEQ     R3,#1
        MOVEQ   R14,#2
        MOVNE   R14,#1
        STR     R14,redraw_all
        BL      UpdateFile
        MOVVS   R14,#0
        STRVS   R14,redraw_all
        EXIT    VS

50      SUBS    r3, r3, #1              ; Run over rest of files. VClear
        ADDNE   r5, r5, #df_size
        BNE     %BT30                   ; Process next file

        MOV     R14,#0
        STR     R14,redraw_all
        EXIT

; .............................................................................

DecodeMenu_OpenParent ROUT ; NOENTRY

 [ debug
 DLINE "Open parent menu select"
 ]
        MOV     r14, #0                 ; silly to allow reopen as menu will
        STRB    r14, menu_reopen        ; probably be on top of a different dir

        MOV     r7, r4

        LDR     r0, [r7, #d_handle]
        BL      GetWindowCoords         ; r3,r4 := abscoords of window top left
        EXIT    VS

        LDR     r14, dvoffsetx          ; open some distance from child
        SUB     r3, r3, r14
        LDR     r14, dvoffsety
        SUB     r4, r4, r14

 [ version < 139
        LDR     r14, [r7, #d_filesystem]
        STR     r14, setplusfilesystem
 ]

        LDR     r1, [r7, #d_dirnamestore] ; r1 -> dirname
        ADR     r0, TempString          ; Make a dirprefix from it
        BL      SGetString
        EXIT    VS

        LDR     r1, TempString
        BL      ExtractDirprefix        ; Strip off a leafname
        MOVNE   r5, #0                  ; Open with default width
        MOVNE   r8, #0                  ; Open with default displaymode
        BLNE    OpenDir                 ; EQ -> no parent to open
        EXIT                            ; (should have been caught before now)


 [ hastiny
; .............................................................................

DecodeMenu_Tiny ROUT ; NOENTRY

 [ debug
 DLINE "Tiny menu select"
 ]
        MOV     r14, #0                 ; silly to allow reopen as menu will
        STRB    r14, menu_reopen        ; probably be on top of a different dir

        BL      MakeTinyDir
        EXIT
 ]

; .............................................................................

 [ AddSetDirectory

DecodeMenu_SetDir
        ;ADR     r1, dirnamebuffer
        LDR     r1, dirnamebuffer
        ADR     r2, DirCommand
        BL      strcpy_advance
        LDR     r2, [r4, #d_dirnamestore]
        BL      strcpy_advance
        ;ADR     r0, dirnamebuffer
        LDR     r0, dirnamebuffer
        SWI     XOS_CLI
        EXIT

DirCommand
        DCB     "Dir ",0
        ALIGN
 ]

DecodeMenu_Refresh
        MOV     r14, #&FF
        STRB    r14, [r4, #d_unsure]    ; mark this dirviewer as dirty
        LDR     r14, poll_word
        ORR     r14, r14, #poll_word_upcall_waiting
        STR     r14, poll_word          ; Poke the foreground application
        EXIT

        END
