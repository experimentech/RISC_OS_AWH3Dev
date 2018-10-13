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
 [ retainsel
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r4 -> old directory viewer
;       r7 -> new directory viewer

; For each object in the new directory, look it up in the old directory
; and copy across its selection state

CopySelectionStateAcross Entry "r1, r3, r5, r6"

        LDR     r3, [r7, #d_nfiles]     ; r3 = no of files to do
        CMP     r3, #0
        EXIT    EQ                      ; [nothing in this new viewer]
                                        ; eg. everything's been deleted

        LDR     r6, [r7, #d_dirname]
        ADD     r5, r7, #d_headersize   ; first fileinfo^

90      LDR     r1, [r5, #df_fileptr]
 [ not_16bit_offsets
        ADD     r1, r6, r1              ; leafname^
 |
        ADD     r1, r6, r1, LSR #16     ; leafname^
 ]
        BL      CopySelectionStateForFile

        SUBS    r3, r3, #1
        ADDNE   r5, r5, #df_size        ; next fileinfo^
        BNE     %BT90

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 -> new file leafname
;       r4 -> old dirviewer block
;       r5 -> new fileinfo block

; Loop over files in old dirviewer, see if any match

CopySelectionStateForFile Entry "r2, r3, r6, r8"

        LDR     r3, [r4, #d_nfiles]     ; r3 = no of files to do
        CMP     r3, #0
        EXIT    EQ                      ; [nothing in this old viewer]
                                        ; rarer: nothing there to start with

        LDR     r6, [r4, #d_dirname]
        ADD     r8, r4, #d_headersize   ; first fileinfo^

90      LDR     r2, [r8, #df_fileptr]
 [ not_16bit_offsets
        ADD     r2, r6, r2              ; leafname^
 |
        ADD     r2, r6, r2, LSR #16     ; leafname^
 ]
        BL      strcmp

        LDREQB  r14, [r8, #df_state]    ; Copy over state byte
        STREQB  r14, [r5, #df_state]
        EXIT    EQ

        SUBS    r3, r3, #1
        ADDNE   r8, r8, #df_size        ; next fileinfo^
        BNE     %BT90

        EXIT
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r4 -> dirviewer block

InitSelection ROUT

        STR     r4, sel_dir

        LDR     r2, [r4, #d_dirnamestore] ; r2 -> dirname
        STR     r2, sel_dirname

        LDR     r3, [r4, #d_nfiles]
        ADD     r3, r3, #1              ; will be adjusted below
        STR     r3, sel_filenumber

        ADD     r5, r4, #d_headersize - df_size ; ditto
        STR     r5, sel_fileblock

; .............................................................................
; Out   NE: r5 = Nowt if nothing doing
;       EQ: selection set up
;           r2 -> selected leafname
;           r3  = selected file number
;           r4 -> selected dirviewer block
;           r5 -> selected fileinfo block

GetSelection Entry

        LDR     r3, sel_filenumber
        LDR     r4, sel_dir
        LDR     r5, sel_fileblock

10      SUBS    r3, r3, #1
        BLE     %FA90

        ADD     r5, r5, #df_size

        LDRB    r14, [r5, #df_state]    ; Is it selected ?
        TST     r14, #dfs_selected
        BEQ     %BT10

; Found one

        STR     r3, sel_filenumber
        STR     r5, sel_fileblock

        LDR     r2, sel_dirname
 [ debugsel
 DREG r5,"Returing selection: ",cc
 DSTRING r2,", dirname ",cc
 ]
        LDR     r14, [r5, #df_fileptr]
        LDR     r2, [r4, #d_filenames]
 [ not_16bit_offsets
        ADD     r2, r2, r14            ; r2 -> leafname
 |
        ADD     r2, r2, r14, LSR #16    ; r2 -> leafname
 ]
        STR     r2, sel_leafname

        BL      FindFileType
;      [ version >= 143
;        LDRB    r14,[r5,#df_type]
;        TEQ     r14,#dft_partition
;        MOVEQ   r3,#filetype_directory
;      ]
        STR     r3, sel_filetype
 [ debugsel
 DSTRING r2,", leafname ",cc
 DREG r3,", filetype ",cc
 ]

        LDR     r3, sel_filenumber
 [ debugsel
 DREG r3,", file number "
 ]

        CMP     r0, r0                  ; EQ
        EXIT


90      addr    r2, anull
        STR     r2, sel_leafname

        MOV     r14, #-2
        STR     r14, sel_filetype

 [ debugsel
 DLINE "No selection found"
 ]
        MOVS    r5, #Nowt               ; NE
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; The WasSelection functions are used when a Message_FilerDevicePath is
; received, meaning that we have to copy/move all the files that we
; unselected when we originally sent a DataLoad message.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r4 -> dirviewer block

InitWasSelection ROUT

        STR     r4, sel_dir

        LDR     r2, [r4, #d_dirnamestore] ; r2 -> dirname
        STR     r2, sel_dirname

        LDR     r3, [r4, #d_nfiles]
        ADD     r3, r3, #1              ; will be adjusted below
        STR     r3, sel_filenumber

        ADD     r5, r4, #d_headersize - df_size ; ditto
        STR     r5, sel_fileblock


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Find the next file that WAS selected.
;
; Out   NE: r5 = Nowt if nothing doing
;       EQ: selection set up
;           r2 -> selected leafname
;           r3  = selected file number
;           r4 -> selected dirviewer block
;           r5 -> selected fileinfo block

GetWasSelection Entry

        LDR     r3, sel_filenumber
        LDR     r4, sel_dir
        LDR     r5, sel_fileblock

10      SUBS    r3, r3, #1              ; Check if there's...
        BLE     %FA90                   ; ...no more files in this dirviewer
        ADD     r5, r5, #df_size        ; Move to the next file in the viewer
        LDRB    r14, [r5, #df_state]    ; Is it (was it) selected ?
        TST     r14, #dfs_wasselected
        BEQ     %BT10                   ; No? Try next.

        ; Found one
        STR     r3, sel_filenumber
        STR     r5, sel_fileblock
        LDR     r2, sel_dirname
        LDR     r14, [r5, #df_fileptr]
        LDR     r2, [r4, #d_filenames]
 [ not_16bit_offsets
        ADD     r2, r2, r14             ; r2 -> leafname
 |
        ADD     r2, r2, r14, LSR #16    ; r2 -> leafname
 ]
        STR     r2, sel_leafname
        BL      FindFileType
        STR     r3, sel_filetype
        LDR     r3, sel_filenumber
        CMP     r0, r0                  ; EQ
        EXIT


90      ; No more files in this dirviewer
        addr    r2, anull
        STR     r2, sel_leafname
        MOV     r14, #-2
        STR     r14, sel_filetype
        MOVS    r5, #Nowt               ; NE
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ClearAllWasSelections
;
; Unmark any wasselected files in the current dir viewer
;
;  In: r4 -> dirviewer block
;
; Out: All registers preserved.

ClearAllWasSelections Entry "r0-r2"

        LDR     r4, was_seldir
        LDR     r1, [r4, #d_nfiles]
        ADD     r0, r4, #d_headersize
01
        CMP     r1, #0
        BEQ     %FT10

        LDRB    r2, [r0, #df_state]
        BIC     r2, r2, #dfs_wasselected
        STRB    r2, [r0, #df_state]
        ADD     r0, r0, #df_size
        SUB     r1, r1, #1
        B       %BT01
10
        MOV     r0, #0
        STR     r0, was_seldir
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r2 -> command to append things to
;
; Out   r1 -> dirnamebuffer containing command+dirname+leafname

PutSelNamesInBuffer Entry "r3"

        LDR     r1, dirnamebuffer
        BL      strcpy                  ; Including spaces
        LDR     r2, sel_dirname
        BL      strcat_excludingspaces
        LDR     r2, sel_leafname
        BL      AppendLeafnameToDirname
        EXIT

        END
