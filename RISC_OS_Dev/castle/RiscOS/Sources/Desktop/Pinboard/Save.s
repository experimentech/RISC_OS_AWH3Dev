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
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; s.Save
; Save pinboard menu handling.
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


Save_KeyPressed ROUT
        Push    "LR"

        LDR     r0,[r1,#24]
        CMP     r0,#13
        BEQ     %FT00
        SWI     XWimp_ProcessKey
        Pull    "PC"
00
        MOV     r0, #4                  ; fake a select click

IntSave_KeyPressed

; Scan for a '.' in the filename

        Push    "r0"
        LDR     r0,save_filename_address
01
        LDRB    r14,[r0],#1
        CMP     r14,#"."
        BEQ     %FT02
        CMP     r14,#32
        BGE     %BT01

        ADD     sp,sp,#4
        ADR     r0,ErrorBlock_PinboardNoDot
        BL      msgtrans_errorlookup
        Pull    "PC"

02
        Debug   sa,"Dot is at ",r14
        LDR     r1,save_filename_address

        BL      DoSave
        ADDVS   sp,sp,#4
        Pull    "PC",VS

        Pull    "r0"
        TEQ     r0, #1                  ; was it an adjust click?
        MOVNE   r1,#-1
        SWINE   XWimp_CreateMenu
        Pull    "PC"


ErrorBlock_PinboardNoDot
        DCD     0
        DCB     "NoDot",0
        ALIGN



save_click      ROUT

        Debug   sa,"Save click ",r2
        CMP     r0,#&40
        BEQ     save_drag

        CMP     r2,#0                   ; icon of the OK button
        ANDEQS  r14,r0,#2               ; ignore menu button
        BEQ     IntSave_KeyPressed
        Pull    "PC"

save_drag       ROUT

        Debug   sa,"Save drag"

        ADR     r1,dataarea
        LDR     r2,saveas_handle
        STR     r2,[r1]
        MOV     r0,#3
        STR     r0,[r1,#4]
        SWI     XWimp_GetIconState
        Pull    "PC",VS

        ADD     R14,R1,#8
        LDMIA   R14,{R6-R9}             ; x0 - y1 of icon

        ADRL    R1,(dataarea+40)
        STR     R2,[R1]                 ; R2 = window handle (store it baby!)

        SWI     XWimp_GetWindowState
        Pull    "PC",VS

        ADD     r14,r1,#4
        LDMIA   r14,{r0-r3}
        ADD     r6,r6,r0              ; Scrren coords.
        ADD     r8,r8,r0
        ADD     r7,r7,r3
        ADD     r9,r9,r3

        Push    "R0-R2"
        MOV     R0,#OsByte_ReadCMOS
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte                ; R2 = CMOS byte allocated to FileSwitch
        MOVVS   R2,#0
        TST     R2,#1:SHL:1             ; Is 'drag a sprite' enabled?
        Pull    "R0-R2"
        BEQ     %FT10                   ; obviously not!

        Push    "R6-R9"                 ; R6-R9 contain icon position
        MOV     R3,SP                   ; R3 -> pushed coordinates
        ADRL    R2,(dataarea+28)        ; R2 -> sprite name to use (from icon data)
        MOV     R1,#1                   ; R1 =1 => sprite in Wimp sprite pool

        MOV     R0,#DS_HJustify_Centre :OR: DS_VJustify_Centre :OR: DS_BoundTo_Screen :OR: DS_Bound_Pointer :OR: DS_DropShadow_Present
        SWI     XDragASprite_Start
        ADD     SP,SP,#4*4              ; balance out the stack
        B       %FT20                   ; then exit 'cos finished the drag start

10      LDR     r0,saveas_handle
        ADR     r1,dataarea
        MOV     r2,#5
        STMIA   r1,{r0,r2,r6-r9}

        SUB     r3,r8,r6
        SUB     r4,r9,r7
        ADR     r0, bounding_box
        LDMIA   r0, {r6-r9}
        SUB     r6, r6, r3 ,LSR #1
        SUB     r7, r7, r4 ,LSR #1
        ADD     r8, r8, r3, LSR #1  ; half x size.
        ADD     r9, r9, r4, LSR #1  ; half y size.
        ADR     r1,dataarea
        ADD     r14,r1,#6*4
        STMIA   r14,{r6-r9}

        Debug   sa,"Calling wimp_dragbox ",r1

        SWI     XWimp_DragBox

        Pull    "PC",VS

        Debug   sa,"Wimp_DragBox returned"
20
        MOV     r0,#DragType_Save
        STR     r0,DragType

        BL      Claim_Focus

        Debug   sa,"Save drag exits"

      [ debugsa
        Pull    "LR"
        Debug   sa,"LR is ",r14
        MOV     PC,LR
      ]

        Pull    "PC"

Save_DragEnd    ROUT

        SWI     XDragASprite_Stop

        ADR     r1,dataarea
        SWI     XWimp_GetPointerInfo
        Pull    "PC",VS

        LDMIA   r1,{r4,r5}
        ADD     r14,r1,#12
        LDMIA   r14,{r2,r3}

        MOV     r0,#Message_DataSave
        STR     r0,[r1,#ms_action]
        MOV     r0,#252
        STR     r0,[r1,#ms_size]
        MOV     r6,#0
        STR     r6,[r1,#ms_yourref]
        LDR     r7,=FileType_Obey
        ADD     r14,r1,#ms_data
        STMIA   r14!,{r2,r3,r4,r5,r6,r7}       ; Window, icon , x , y

        LDR     r0,save_filename_address
        MOV     r4,r0
01
        LDRB    r5,[r0],#1
        CMP     r5,#"."
        MOVEQ   r4,r0
        CMP     r5,#32
        BGE     %BT01

; r4 -> Leafname

        MOV     r0,r4
        MOV     r1,r14
        BL      Copy_r0r1


        ADR     r1,dataarea
        ADD     r14,r1,#44
        DebugS  sa,"Leafname is ",r14
        MOV     r0,#18                       ; r2,r3 are icon / window handles
        Debug   sa,"Icon,Window ",r2,r3
        SWI     XWimp_SendMessage

        Pull    "PC"

Save_DataSaveAck        ROUT

        DebugS  sa,"Filename is ",r14

        ADD     r1,r1,#44
        BL      DoSave

        ADR     r1,dataarea
        LDR     r0,[r1,#8]
        STR     r0,[r1,#12]
        MOV     r0,#Message_DataLoad
        STR     r0,[r1,#ms_action]
        MOV     r0,#18
        LDR     r2,[r1,#4]
        SWI     XWimp_SendMessage
        Pull    "PC",VS

        ADR     r1,dataarea
        ADD     r2,r1,#44                       ; SMC: point to file name
        LDR     r3,[r1,#36]
        CMP     r3,#-1                          ; Check for unsafe file eg. <Wimp$Scrap>
        MOVNE   r0,r2                           ; SMC: only copy if not unsafe
        LDRNE   r1,save_filename_address
        BLNE    Copy_r0r1

        MOVVC   r1,#-1
        SWIVC   XWimp_CreateMenu

        Pull    "PC"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DoSave
;
; Save a Pinboard Obey file
;
; In: r1 -> filename
; Out: r0 corrupt

DoSave  ROUT
        Entry   "r1-r9"

        MOV     r8, r1                          ; r8 -> filename

        ; Get substrings of Boot:
        ADR     r0, BootPathVar
        ADR     r1, dest_directory
        MOV     r2, #?dest_directory
        MOV     r3, #0
        MOV     r4, #VarType_Expanded
        SWI     XOS_ReadVarVal
        MOV     r0, #0
        STRVCB  r0, [r1, r2]                    ; FSName::Drive.$.![Arm]Boot.[,OtherStuff]...
        BVS     %FT20
10
        LDRB    lr, [r1, r0]
        CMP     lr, #','
        BEQ     %FT20
        CMP     lr, #' '
        ADDHI   r0, r0, #1
        BHI     %BT10
20
        STR     r0, save_boot_length            ; FSName::Drive.$.![Arm]Boot.
        STR     r0, save_boothat_length
        SUBS    r0, r0, #2
        BMI     %FT40
30
        LDRB    lr, [r1, r0]
        CMP     lr, #'.'
        BEQ     %FT40
        STR     r0, save_boothat_length         ; FSName::Drive.$.
        SUBS    r0, r0, #1
        BPL     %BT30
40
        ; Open file to write
        MOV     r0, #open_write :OR: open_pathbits :OR: open_mustopen :OR: open_nodir
        MOV     r1, r8
        SWI     XOS_Find
        EXIT    VS
        MOV     r9, r0                          ; r9 = file handle

        ; Write a 'Pinboard' command
        MOV     r0, r9
        ADR     r1, PinboardCommand
        BL      PutString
        ADR     r1, NL
        BL      PutString

        ; Write *Pin commands for each icon
        BL      write_pin_commands

        ; Close the file, set it's type and exit
        MOV     r0, #0
        MOV     r1, r9
        SWI     XOS_Find

        MOV     r0, #OSFile_SetType
        MOV     r1, r8
        LDR     r2,=FileType_Obey
        SWI     XOS_File
        EXIT


PinboardCommand DCB "Pinboard",0
TinyDirsCommand DCB "X AddTinyDir ", 0          ; ignore errors so that entering the desktop
PinCommand      DCB "X Pin ", 0                 ; doesn't result in scores of error boxes
BootPathVar     DCB "Boot$$Path", 0
BootSubst       DCB "Boot:", 0
BootHatSubst    DCB "Boot:^.", 0
Space           DCB " ", 0
NL              DCB 10, 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; TryMatchBoot[Hat]
;
; Look for a match in the first <n> characters of a pin or addtinydir name
;
; In: r0 = filehandle of output
;     r1 = null terminated string to try for a match
;
; Out: r1 = adjusted if match made, and prefix string written to filehandle
;      all other regs preserved

TryMatchBoot Entry "r2-r5"
        LDR     r3, save_boot_length
        ADR     r4, BootSubst
        B       %FT10
TryMatchBootHat ALTENTRY
        LDR     r3, save_boothat_length
        ADR     r4, BootHatSubst
10
        TEQ     r3, #0
        EXIT    EQ                              ; Boot$Path unset, no match
        ADR     r2, dest_directory

        LDRB    r5, [r1, r3]
        LDRB    lr, [r2, r3]
        Push    "r0, r3, r5, lr"
        MOV     r5, #0
        STRB    r5, [r1, r3]                    ; Trim string for compare
        STRB    r5, [r2, r3]                    ; Trim Boot$Path for compare

        MOV     r0, #-1
        MOV     r3, #Collate_IgnoreCase
        SWI     XTerritory_Collate
        CMP     r0, #0
        Pull    "r0, r3, r5, lr"
        STRB    r5, [r1, r3]                    ; Restore
        STRB    lr, [r2, r3]                    ; Restore
        EXIT    NE                              ; No match (or error)

        MOV     r2, r1
        MOV     r1, r4
        BL      PutString
        ADD     r1, r2, r3                      ; Adjust to string remainder
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; write_pin_commands
;
; Output Pin commands to a file for each icon on the backdrop
;
; In: r0 = filehandle of output
;
; Out: all regs preserved

write_pin_commands Entry "r1-r3"
        ; Loop through all the icons and write Pin commands for each one.
        ADR     r2,Icon_list
02
        LDR     r2,[r2]
        CMP     r2,#0
        EXIT    EQ
        LDR     r3,[r2,#ic_window]
        CMP     r3,#iconbar_whandle
        ADREQ   r1,TinyDirsCommand
        ADRNE   r1,PinCommand
        BL      PutString
        EXIT    VS

        ADD     r1,r2,#ic_path
        BL      TryMatchBoot
        ADD     lr,r2,#ic_path
        TEQ     lr,r1                           ; Was there a substitution?
        BLEQ    TryMatchBootHat                 ; No, so try the smaller substring
        BL      PutString
        EXIT    VS

        CMP     r3,#iconbar_whandle
        BEQ     %FT03                           ; AddTinyDir has no x,y

        ADR     r1,Space
        BL      PutString
        EXIT    VS

        Push    "r0-r2"
        ADR     r1,ConversionSpace
        LDR     r0,[r2,#ic_x]
        MOV     r2,#256
        SWI     XOS_ConvertInteger4
        STRVS   r0,[sp]
        Pull    "r0-r2"
        EXIT    VS
        ADR     r1,ConversionSpace
        BL      PutString
        EXIT    VS

        ADRL    r1,Space
        BL      PutString
        EXIT    VS

        Push    "r0-r2"
        ADR     r1,ConversionSpace
        LDR     r0,[r2,#ic_y]
        MOV     r2,#256
        SWI     XOS_ConvertInteger4
        STRVS   r0,[sp]
        Pull    "r0-r2"
        EXIT    VS
        ADR     r1,ConversionSpace
        BL      PutString
        EXIT    VS
03
        ADRL    r1,NL
        BL      PutString
        EXIT    VS

        B       %BT02


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; PutString
;
; Write a NULL terminated string to a file
;
; In: r0 = file handle
;     r1 -> string to write
;
; Out: All registers preserved

PutString       ROUT
        EntryS  "r0-r2"

        MOV     r2,r1
        MOV     r1,r0
01
        LDRB    r0,[r2],#1
        CMP     r0,#0
        EXITS   EQ
        SWI     XOS_BPut
        STRVS   r0,[sp]
        EXIT    VS
        B       %BT01

        LNK     Backdrop.s
