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
; > Sources.ListFonts

;--------------------------------------------------------------------------------

; The Font Manager accesses all fonts via Font$Path and Font$Prefix
; The default is *SetMacro Font$Path <Font$Prefix>.
;
; Under the new system the Font Manager buffers the results of a
; Font_ListFonts, and also uses the buffered results in Font_FindFont to
; find a font without looking through the entire path.
;
; *FontInstall adds a font directory on the front of the path
; *FontLibrary makes Font$Prefix point to it.
; The <Font$Prefix> directory is always on the front of the path, but such a
; directory is temporary in the sense that there is only one of them.
;
; The Font Manager keeps a list of prefix elements from Font$Path, plus a
; list of font blocks which reference the prefix blocks.  When Font$Path
; changes, the Font Manager removes references to fonts which use deleted
; prefixes, and rescans any new font prefixes.
;
; Font_ListFonts returns first occurence only of each font, returning the
; font name as well as the identifier (by looking in <prefix>.Messages<country>),
; and can also be made to return a hierarchical font menu.
;
; Font_DecodeMenu converts a menu selection in that menu to a font id/name.

;--------------------------------------------------------------------------------

; In    R0 -> parameter list (font prefix(es) or null)
;       R1 = number of parameters
; Out   Font$Path altered so that this prefix is on the front

FontInstall_Code Entry "R0,R1,R12"

        LDR     R12,[R12]

        TEQ     R1,#0                           ; *FontInstall => rescan all font stuff
        BEQ     rescanfontcat

        BL      addtofontpath                   ; in R0 -> stuff to add
98      BLVC    try_listfonts_recache
99
        STRVS   R0,[sp]
        EXIT

rescanfontcat
        MOV     R0,#0
        BL      rescanprefix                    ; mark all prefixes to be rescanned
        B       %BT98

;...........................................................................

; In    R0 -> prefix element to remove from font$path

FontRemove_Code Entry "R0,R1,R12"

        LDR     R12,[R12]

        BL      removefromfontpath
        BLVC    try_listfonts_recache

        STRVS   R0,[sp]
        EXIT

;...........................................................................

; In    R0 -> parameter list (font directory or null)
;       R1 = number of parameters
; Out   Font$Path altered so that this prefix is on the front

FontLibrary_Code Entry "R0,R1,R12"

        LDR     R12,[R12]

01      LDRB    R14,[R0],#1
        CMP     R14,#" "
        BEQ     %BT01
        SUB     R0,R0,#1                        ; R0 -> first non-space character

        BL      rescanprefix                    ; mark this one to be rescanned (if previously present)

        MOV     R1,R0                           ; R1 -> start of string
02      LDRB    R14,[R0],#1
        CMP     R14,#terminator
        BCS     %BT02
        SUB     R0,R0,#1
        SUB     R2,R0,R1                        ; R2 = length of string

        ADR     R0,str_fontprefix               ; R0 -> variable name
        MOV     R3,#0                           ; R3 = 0 <=> first call
        MOV     R4,#VarType_String
        SWI     XOS_SetVarVal

        ADRVC   R0,str_fontprefix_ref           ; R0 -> "<Font$Prefix>."
        BLVC    addtofontpath                   ; add on the front of Font$Path
        BLVC    try_listfonts_recache

        STRVS   R0,[sp]
        EXIT

str_fontprefix          DCB     "Font$$Prefix", 0
str_fontprefix_ref      DCB     "<Font$$Prefix>.", 0
                        ALIGN

;...........................................................................

; In    R0 -> new element(s) to add on the front of Font$Path
; Out   Font$Path (macro) set to [R0..],<old unexpanded value>
;       Duplicate and null elements are eliminated (1st occurrence takes priority)
;       R0 corrupt

addtofontpath Entry "R1-R3"

        BL      addelement              ; R1 -> start, R2 -> end, R3 -> path stuff
        BLVC    setfontpath

        EXIT

;...........................................................................

; In    R0 -> element(s) to remove from Font$Path
; Out   Font$Path (macro) set to <old unexpanded value minus [R0]>
;       R0 corrupt

removefromfontpath Entry "R1-R3"

        BL      addelement              ; R1 -> start, R2 -> end, R3 -> path stuff
        MOVVC   R1,R3                   ; R1 -> section after new stuff
        BLVC    setfontpath

        EXIT

;...........................................................................

; In    R0 -> element(s) to add to Font$Path
; Out   R1 -> start of buffer containing [R0..],<old font$path>
;       R2 -> end of string + 1
;       R3 -> where <old font$path> was added
;       R0 corrupt

addelement Entry "R4"

; first append the existing value (unexpanded) of Font$Path to the new element(s)

        ADR     R1,wrchblk
        MOV     R2,#?wrchblk-1                  ; allow 1 for extra terminator

05      LDRB    R14,[R0],#1                     ; Module command table flags ensure this string cannot be null
        CMP     R14,#" "
        BEQ     %BT05
        SUB     R0,R0,#1                        ; R0 -> first non-space character
        BCC     %FT20                           ; if nothing to copy, just read font$path

10      LDRB    R14,[R0],#1
        CMP     R14,#" "
        BLS     %FT15                           ; ctrl-char or space terminated
        SUBS    R2,R2,#1
        STRGTB  R14,[R1],#1                     ; must leave at least 1 extra byte
        BGT     %BT10

90      BL      xerr_buffoverflow
        EXIT

15      SUBS    R2,R2,#1
        BLE     %BT90
        MOV     R14,#","                        ; append ","
        STRB    R14,[R1],#1

        ADR     R3,wrchblk                      ; check each "," is preceded by a "." or ":" for a valid path
16      LDRB    R14,[R3],#1
        TEQ     R14,#","
        BNE     %FT17
        LDRB    R14,[R3,#-2]                    ; no danger of underflowing the buffer as prefix is known non-null by now
        TEQ     R14,#"."
        TEQNE   R14,#":"
        TEQNE   R14,#","                        ; silently pass ",," entries
        BEQ     %FT17
        ADR     R0,ErrorBlock_FontNoPathDot
        BL      MyGenerateError
        EXIT
        MakeErrorBlock FontNoPathDot

17      TEQ     R3,R1
        BNE     %BT16

20      ADR     R0,str_fontpath                 ; R0 -> "Font$Path"
        MOV     R3,#0                           ; R3=0 => first occurrence
        MOV     R4,#VarType_Macro               ; R4<>4 => return unexpanded form
        SWI     XOS_ReadVarVal
        TEQ     R2,#0                           ; if error is "Variable not found"
        CLRV    EQ                              ; treat as null string
        EXIT    VS

        MOV     R14,#0                          ; stick in terminator
        STRB    R14,[R1,R2]

; now eliminate any element which also occurs earlier in the string

        MOV     R4,R1                           ; R4 -> original beginning of Font$Path

        ADR     R1,wrchblk                      ; R1 = input pointer
        ADR     R2,wrchblk                      ; R2 = output pointer
        ADD     R3,R1,#?wrchblk                 ; R3 > R2 => R4 not encountered yet

        DebugS  path2,"New Font$$Path with duplicates =",R1

25      TEQ     R1,R4                           ; if input ptr = start of Font$Path
        MOVEQ   R3,R2                           ; set R3 = start of output Font$Path

        LDRB    R14,[R1]                        ; skip null elements
        TEQ     R14,#","
        ADDEQ   R1,R1,#1
        BEQ     %BT25

        TEQ     R14,#0                          ; stop now if reached end
        BEQ     %FT55

        ADR     R0,wrchblk                      ; now start scanning all earlier strings

30      CMP     R0,R2                           ; continue till all earlier strings done
        BHS     %FT45                           ; copy string if no match
        BL      strcmp_nocase_comma             ; R0 -> end of string+1, EQ => match
        BNE     %BT30                           ; continue till match found or no more strings
35
        DebugS  path2,"Skip element:",R1
40      LDRB    R14,[R1],#1                     ; skip this element, including the terminator
        TEQ     R14,#0
        TEQNE   R14,#","
        BNE     %BT40
        B       %FT55
45
        DebugS  path2,"Copy element:",R1
50      LDRB    R14,[R1],#1                     ; copy this element, including the terminator
        STRB    R14,[R2],#1
        TEQ     R14,#0
        TEQNE   R14,#","
        BNE     %BT50

55      TEQ     R14,#0                          ; continue until terminator reached
        BNE     %BT25

; tidy up: R1 -> start of string, R3 -> start of original bit, R2 -> terminator

        ADR     R1,wrchblk                      ; R1 -> start of string

        CMP     R2,R1
        SUBHI   R2,R2,#1                        ; R2 -> terminator of string
        MOV     R14,#0
        STRB    R14,[R2]                        ; make sure it IS terminated!

        CMP     R3,R2                           ; R3 -> start of original section
        MOVHI   R3,R2

        Debug   path2,"addelement exit: R1,R2,R3 =",R1,R2,R3
        DebugS  path,"New font$$path =",R1

        EXIT

;................................................................................

; In    R1 -> start of font$path string (unexpanded)
;       R2 -> terminator of font$path string
; Out   Font$Path (macro) set to string

setfontpath Entry "R2-R4"

        ADR     R0,str_fontpath                 ; R0 -> variable name
        SUB     R2,R2,R1                        ; R2 = length of string
        MOV     R3,#0                           ; R3 = 0 => first call
        MOV     R4,#VarType_Macro               ; R4 = variable type
        SWI     XOS_SetVarVal

        EXIT

str_fontpath    DCB     "Font$$Path", 0
                ALIGN

;................................................................................

; In    R0 -> prefix to watch out for (0 => mark all prefixes)
;       [lf_prefixhead] -> list of prefix blocks
; Out   scan bit of relevant prefix blocks is unset

rescanprefix Entry "R0-R2"

        DebugS  path2,"rescanprefix ",R0

        LDR     R2,lf_prefixhead
        B       %FT02

01      TEQ     R0,#0
        ADDNE   R1,R2,#lfpr_prefix
        BLNE    strcmp_nocase
      [ debugpath
        BNE     %FT00
        Debug   path,"rescan prefix block at",R2
00
      ]
        LDREQB  R14,[R2,#lfpr_flags]
        BICEQ   R14,R14,#lfprf_scanned
        STREQB  R14,[R2,#lfpr_flags]

        LDR     R2,[R2,#lfpr_link]
02      CMP     R2,#0
        BNE     %BT01

        EXIT

;................................................................................

; In    R0,R1 -> strings to compare (terminated by "," or 0)
; Out   R0 -> one after terminator of string
;       EQ => strings match, NE => they don't

strcmp_nocase_comma Entry "R1,R6,R7"

        DebugS  path2,"strcmp_nocase_comma: ",R0
        DebugS  path2,"                   : ",R1

01      LDRB    R6,[R0],#1
        LDRB    R7,[R1],#1
        TEQ     R6,#","
        MOVEQ   R6,#0
        TEQ     R7,#","
        MOVEQ   R7,#0
        LowerCase R6,R14                ; should use Territory module
        LowerCase R7,R14
        CMP     R6,R7
        BNE     %FT02                   ; strings not equal
        TEQ     R6,#0
        BNE     %BT01
        EXIT                            ; EQ => strings match

02      TEQ     R6,#0
        TEQNE   R6,#","
        LDRNEB  R6,[R0],#1
        BNE     %BT02

        CMP     PC,#0                   ; set NE
        EXIT                            ; NE => strings don't match

;--------------------------------------------------------------------------------

; SWI Font_ListFonts (&40091)
; In:   R2 bits 0..15 = counter (0 on first call)
;       R2 bits 16..31 = 0 => old-style: treat R2 as bits 16,18 set, R3 = 40
;          bit 16 = 1 => return font identifier in [R1..] or return size
;          bit 17 = 1 => return font name in [R4..] or return size
;          bit 18 = 1 => return strings terminated with 13, else 0
;          bit 19 = 1 => return font menu in [R1..] and [R4..] or return sizes
;          bit 20 = 1 => put "System font" at head of menu
;          bit 21 = 1 => tick font indicated by R6
;          bit 22 = 1 => scan list of encodings, rather than list of fonts
;          bits 23..31 reserved (must be 0)
;          NB: R2 bit 19 = 0 => R2 bits 20,21 = 0
;              R2 bit 19 = 1 => R2 bits 16,17 = 0
;       If R2 bits 16 or 19 set:
;          R1 = 0 => return size of buffer
;             <>0 => R1 -> buffer for font identifier or menu
;          R3 = size of buffer in R1 (if R1 <> 0)
;       If R2 bit 17 or 19 set:
;          R4 = 0 => return size of buffer
;             <>0 => R4 -> buffer for font name or menu indirected data
;          R5 = size of buffer in R4 (if R4 <> 0)
;       If R2 bit 21 set:
;          R6 -> identifier of font/encoding to tick (also ticks submenu parent)
;          R6=1 => tick "System font"
;          R6=0 => don't tick anything
;
; Out:  R2 = -1 => no more font names/identifiers
;                  font identifier/name is invalid in this case
;                  font menu preserves R2 and does it all in one go
;       R2 = counter/flags for next time
;       If R2 bit 16 or 19 set on entry:
;          If R1<>0 on entry, then [R1..] = font identifier or menu
;          R3 = size of buffer required (if menu, 0 => no entries in menu)
;       If R2 bit 17 or 19 set on entry:
;          If R4<>0 on entry, then [R4..] = font name or menu data
;          R5 = size of buffer required
;
;       If R2 bit 19 set on entry then R2 is preserved on exit.  Note that
;       in this case Font_ListFonts need only be called once to measure the
;       length of buffer required, and once more to construct the actual
;       menu.
;
;       If R2 bit 19 set, bit 20 clear, then R3=0 on exit => null menu.
;
;       If R2 bits 16..31 are clear on entry, then this is treated as though
;       R2 bits 16 and 18 were set and R3=40 on entry.
;       On exit R2 = R2+1 (bits 16..31 clear) or R2=-1.
;
; Errors:
;       "Buffer overflow" (R3 or R5 were too small)
;       "Bad parameters" (R2 flag bits invalid)
;       If an error is returned, R2=-1 (listfonts terminated)


lfbitshift       *      16
lfbit_returnid   *      1 :SHL: 16
lfbit_returnname *      1 :SHL: 17
lfbit_returncr   *      1 :SHL: 18
lfbit_returnmenu *      1 :SHL: 19
lfbit_systemfont *      1 :SHL: 20
lfbit_tickfont   *      1 :SHL: 21
lfbit_encodings  *      1 :SHL: 22
lfbit_reserved   *      -1 :SHL: 23

lfincrement      *      1 :SHL: (32-lfbitshift)

SWIFont_ListFonts Entry "R0-R12"

      [ debugpath
        Debuga  path, "Font_ListFonts: R1,R2,R3,R4,R5,R6 =",R1,R2,R3,R4,R5
        CMP     R6,#&8000
        BCC     %FT00
        DebugS  path," ",R6
        B       %FT101
00
        Debug   path,"",R6
101
      ]

        MOVS    R14,R2,LSR #lfbitshift
        ORREQ   R2,R2,#lfbit_returnid :OR: lfbit_returncr
        MOVEQ   R3,#40                          ; size of buffer is implicit

        TST     R2,#lfbit_returnmenu
        LDREQ   R14,=lfbit_returnmenu :OR: lfbit_systemfont :OR: lfbit_tickfont :OR: lfbit_reserved
; Comment from Chris: shouldn't ^that^ OR statement include lfbit_encodings?

        LDRNE   R14,=lfbit_returnid :OR: lfbit_returnname :OR: lfbit_reserved
        TST     R2,R14
        BLNE    xerr_badparameters

        BLVC    try_listfonts_recache           ; recache font list if necessary
        BVS     %FT99

        TST     R2,#lfbit_returnmenu
        BNE     lfreturnmenu

; skip first n font names (duplicates automatically skipped in getnextnewfont)

        Debug   path2,"Font_ListFonts: munged R2,R1,R3,R4,R5 =",R2,R1,R3,R4,R5

        BL      getfirstfont                    ; R7 -> first font block
        MOVS    R6,R2,LSL #32-lfbitshift        ; R6 = no of fonts to skip << 32-lfbitshift
01      BLGT    getnextnewfont                  ; R7 -> next font block if R6 > 0
        TEQ     R7,#0
        MOVEQ   R2,#-1
        BEQ     %FT99                           ; EQ => no more fonts
        SUBS    R6,R6,#lfincrement
        BGT     %BT01                           ; R6 may end up 0 or -lfincrement

      [ debugpath
        Debuga  path,"Return font block at",R7
        LDR     R0,[R7,#lff_identaddr]
        DebugS  path," ",R0
      ]

; see if we should return the font id

        TST     R2,#lfbit_returnid
        BEQ     %FT02
        LDR     R0,[R7,#lff_identaddr]  ; R0 -> font identifier
        BL      count_R0                ; R6 = length of string+1
        LDR     R14,[sp,#2*4]
        MOVS    R14,R14,LSR #lfbitshift
        STRNE   R6,[sp,#3*4]            ; if new-style, R3 on exit = actual size of buffer

        TEQ     R1,#0                   ; just count?
        BEQ     %FT02

        CMP     R6,R3                   ; was the buffer size OK?
        BGT     err_lfbuffoverflow

        Debuga  path2,"Copy font id from,to,length",R0,R1,R6
        DebugS  path2,": ",R0

11      LDRB    R14,[R0],#1
        STRB    R14,[R1],#1
        SUBS    R6,R6,#1
        BNE     %BT11

        TST     R2,#lfbit_returncr      ; should this be <cr>-terminated?
        MOVNE   R14,#cr
        STRNEB  R14,[R1,#-1]

; see if we should return the font name

02      TST     R2,#lfbit_returnname
        BEQ     %FT03
        LDR     R0,[R7,#lff_nameaddr]   ; R0 -> font name
        BL      count_R0                ; R6 = length of string+1
        STR     R6,[sp,#5*4]            ; R5 on exit = actual size of buffer

        TEQ     R4,#0                   ; just count?
        BEQ     %FT03

        CMP     R6,R5                   ; was the buffer size OK?
        BGT     err_lfbuffoverflow

        Debuga  path2,"Copy font name from,to,length",R0,R4,R6
        DebugS  path2,": ",R0

12      LDRB    R14,[R0],#1
        STRB    R14,[R4],#1
        SUBS    R6,R6,#1
        BNE     %BT12

        TST     R2,#lfbit_returncr      ; should this be <cr>-terminated?
        MOVNE   R14,#cr
        STRNEB  R14,[R4,#-1]

03      ADD     R2,R2,#1                ; get next font next time

99      MOVVS   R2,#-1                  ; terminate on error
        SavePSR R3                      ; save flags

        LDR     R14,[sp,#2*4]
        MOVS    R14,R14,LSR #lfbitshift ; if old-style caller,
        TSTEQ   R2,#1 :SHL: 31          ; and R2 <> -1
        BICEQ   R2,R2,#lfbit_returnid :OR: lfbit_returncr
                                        ; must return with bits 16..31 clear, since R3=40 is implicit on next call
        STR     R2,[sp,#2*4]

        RestPSR R3,,f                   ; restore flags
        PullS   "$Proc_RegList"
        LTORG


; Create font menu from the list of fonts
; Pass 1: create top-level menu of family names
; Pass 2: create submenus for all those and modify the existing menu


lfreturnmenu

;  Added by Chris Murray:
;
;  This finds out what version of the Wimp is running so we can use indirected menu
;  titles if we need to and the Wimp is new enough.

        MOV     R0,#WimpSysInfo_WimpVersion
        SWI     XWimp_ReadSysInfo       ; try to read current version of Wimp running
        MOVVS   R0,#0                   ; if can't read, don't try to use indirected titles
        BVS     %FT01
        LDR     R14,cleverwimpversion   ; get minimum Wimp version that supports it
        CMP     R0,R14                  ; is it new enough to support indirected menu titles?
        MOVLT   R0,#0                   ; no  => don't use indirected menu titles
        MOVGE   R0,#mtf_indirectable    ; yes => use indirected menu titles if we need to
01      STR     R0,lf_menutitleflags    ; save result for later
        CLRV                            ; clear error condition

        MOVS    R14,R2,LSL #32-lfbitshift
        BLNE    xerr_badparameters      ; must start from the beginning
        BVS     %BT99

        MOV     R8,#0                   ; R8,R9 = sizes of menu buffers so far
        MOV     R9,#0

        TST     R2,#lfbit_systemfont    ; if no "System Font" entry,
        BLEQ    getfirstfont            ; and there are no other fonts
        TEQEQ   R7,#0                   ; return R3=0 (null menu)
        BEQ     lfmenu_done

; scan the list of fonts, creating the top-level menu of family names

        ADRL    R10,msg_null            ; R10 -> previous font family name (none)

        MOV     R14,#0
        STR     R14,lf_menuparent       ; main menu has no parent
        ADR     R0,msg_fontlist
        BL      LookupR0
        BL      count_R0
;<<        MOV     R6,#?msg_fontlist
        BL      lfmenu_newmenu          ; R11 -> top level menu (called "Font List")
        BVS     %BT99

        TST     R2,#lfbit_systemfont
        ADRNE   R0,msg_systemfont       ; R0 -> font name of font to add
        BLNE    LookupR0
        BLNE    count_R0                ; R6 = length of string+1
        MOVNE   R7,#0                   ; R7 = 0 => this is not a real font
        BLNE    lfmenu_newitem          ; R10 -> family name of previous font
        BVS     %BT99

        BL      getfirstfont            ; R7 -> first font/encoding block (looks at R2)
        B       lfmenu_pass1_end

lfmenu_pass1
        LDR     R0,[R7,#lff_nameaddr]
        BL      strcmp_dot              ; EQ => R0,R10 match up to "." or 0
        MOVNE   R10,R0
        BLNE    lfmenu_newitem          ; R6 = number of bytes to copy
        BVS     %BT99

        BL      getnextnewfont          ; R7 -> next distinct font
lfmenu_pass1_end
        TEQ     R7,#0
        BNE     lfmenu_pass1
        BL      lfmenu_lastitem         ; mark previous item as the last one

; now repeat the process, this time constructing the submenus

        LDR     R14,[sp,#1*4]           ; R10 -> head of main menu
        ADD     R14,R14,#m_headersize
        TST     R2,#lfbit_systemfont
        ADDNE   R14,R14,#mi_size        ; skip "System font" if present
        STR     R14,lf_menuparent       ; for filling in submenu links
        ADREQ   R10,msg_null
        ADRNE   R0,msg_systemfont
        BLNE    LookupR0
        MOVNE   R10,R0                  ; -> correct name

        BL      getfirstfont            ; R7 -> first font/encoding block
        B       lfmenu_pass2_end

lfmenu_pass2
        LDR     R0,[R7,#lff_nameaddr]
        BL      strcmp_dot              ; EQ => R0,R10 match up to "." or 0
        BEQ     %FT45                   ; R6 = length of section up to and including the first "."

        BL      lfmenu_lastitem         ; if first submenu, just re-marks main menu
        MOV     R10,R0                  ; R10 -> new family name
        BL      lfmenu_newmenu
        BVS     %BT99

        LDR     R14,lf_menuparent       ; increment menu parent for next submenu
        ADD     R14,R14,#mi_size
        STR     R14,lf_menuparent

45      ADD     R0,R0,R6                ; skip family name
        LDRB    R14,[R0,#-1]            ; if end of name, put "(Regular)" in menu
        TEQ     R14,#0
        ADREQL  R0,msg_regular          ; R0 -> "(Regular)"
        BLEQ    LookupR0
        TEQNE   R1,#0
        LDRNE   R14,lf_menuparent       ; only link in submenu if any entries are not "(Regular)"
        STRNE   R11,[R14,#mi_submenu-mi_size]
        BL      count_R0                ; R6 = length of [R0..] + 1
        BL      lfmenu_newitem          ; R6 = number of bytes to copy
        BVS     %BT99

        BL      getnextnewfont
lfmenu_pass2_end
        TEQ     R7,#0
        BNE     lfmenu_pass2
        BL      lfmenu_lastitem

lfmenu_done
        STR     R8,[sp,#3*4]
        STR     R9,[sp,#5*4]
        B       %BT99

err_lfbuffoverflow
        BL      xerr_buffoverflow
        B       %BT99


msg_fontlist    DCB     "FontList:Font List",0
msg_systemfont  DCB     "SystemFont:System font"
msg_null        DCB     0
msg_regular     DCB     "Regular:(Regular)",0
                ALIGN

;.......................................................................

xerr_badparameters ROUT
        ADR     R0,ErrorBlock_FontBadParameters
        B       MyGenerateError
        MakeInternatErrorBlock FontBadParameters,,"BadParm"

;.......................................................................

; In    R2 and lfbit_encodings => which type of block to search for
;       [listfonts_head] -> list of font/encoding blocks
; Out   R7 -> first font/encoding block in list of the appropriate type

getfirstfont EntryS "R2"

        TST     R2,#lfbit_encodings
        MOVEQ   R2,#lfff_encoding
        MOVNE   R2,#0                   ; R2 = flag setting NOT to search for

        LDR     R7,listfonts_head

01      TEQ     R7,#0                   ; R7=0 => none present
        EXITS   EQ

        LDR     R14,[R7,#lff_flags]     ; if flags match R2, don't return this
        AND     R14,R14,#lfff_encoding
        TEQ     R14,R2
        LDRNE   R14,[R7,#lff_nameaddr]  ; if name starts with "/", don't return it either
        LDRNEB  R14,[R14]
        TEQNE   R14,#"/"
        LDREQ   R7,[R7,#lff_link]
        BEQ     %BT01

        EXITS                           ; R7 -> first font/encoding block

;.......................................................................

; In    R7 -> font/encoding block
; Out   R7 -> next font/encoding block in list which has a different identifier

getnextnewfont Entry "R0-R2"

        LDR     R2,[R7,#lff_flags]      ; look for another with the same type
        AND     R2,R2,#lfff_encoding

        LDR     R0,[R7,#lff_identaddr]

01      LDR     R7,[R7,#lff_link]
        TEQ     R7,#0
        EXIT    EQ

        LDR     R1,[R7,#lff_flags]      ; loop until type is same as last one
        AND     R1,R1,#lfff_encoding
        TEQ     R1,R2
        BNE     %BT01

        LDR     R1,[R7,#lff_identaddr]
        BL      strcmp_nocase

        LDRNE   R14,[R7,#lff_nameaddr]  ; if name starts with "/", don't return this one
        LDRNEB  R14,[R14]
        TEQNE   R14,#"/"

        BEQ     %BT01                   ; loop until identifier different and name doesn't start with "/"

        EXIT

;.......................................................................

; In    R0 -> menu title string
;       R6 = length of string + 1
;       R1,R4 -> buffers for menu and data (0 => just count)
;       If R1<>0, [lf_menuparent] -> parent menu item (0 => none)
;       If R1,R4<>0: R3,R5 = maximum allowed buffer size
;       R8,R9 = buffer sizes so far
; Out   R11 -> menu header (if R1<>0)
;       [R1..], [R4..] updated if R1,R4<>0
;       parent menu item updated if R1,R4<>0
;       R8,R9 updated
;       Error if R1,R4<>0 and R8>R3 or R9>R5

lfmenu_newmenu Entry "R0,R6"            ; NB: same Proc_RegList as lfmenu_newitem

        Debug   path2,"New menu: menu (size), data (size) =",R1,R8,R4,R9
        Debuga  path,"Menu title =",R6
        DebugS  path,"",R0

        ADD     R8,R8,#m_headersize     ; no indirected data

        LDR     R14,lf_menutitleflags
        CMP     R6,#12+1                ; is menu title length too big for menu block?
        BICLE   R14,R14,#mtf_indirected ; no, it will fit so don't use indirected menu title
        BLE     %FT28

; (length of string + 1) > 12+1 => we would like to use indirected titles...

        TST     R14,#mtf_indirectable   ; are we allowed to use indirected menu titles?
        BICEQ   R14,R14,#mtf_indirected ; no  - disable indirected menu titles
        ORRNE   R14,R14,#mtf_indirected ; yes - enable  indirected menu titles
        ADDNE   R9,R9,R6                ;       and take space from indirected data buffer
28      STR     R14,lf_menutitleflags   ; save flags for later

        CMP     R1,#0
        EXIT    EQ

        MOV     R11,R1                  ; R11 -> current menu

        LDR     R14,lf_menutitleflags
        TST     R14,#mtf_indirected     ; if we're using indirected menu titles, make sure
        CMPNE   R9,R5                   ; we've enough memory
        BGT     lfmenu_newmenuerr

        CMP     R8,R3                   ; only R8 needs checking
        BGT     lfmenu_newmenuerr

        LDR     R14,lf_menutitleflags
        TST     R14,#mtf_indirected     ; use indirected menu title?
        BEQ     %FT30                   ; no

        STR     R4,[R1],#4              ; yes, set pointer to indirected menu title
        MOV     R14,#0                  ; set unused remaining words to zero
        STR     R14,[R1],#4
        STR     R14,[R1],#4
        Push    "R6"
29      LDRB    R14,[R0],#1             ; copy string
        STRB    R14,[R4],#1
        SUBS    R6,R6,#1
        BNE     %BT29
        TST     R2,#lfbit_returncr
        MOVEQ   R14,#0                  ; put in terminator
        MOVNE   R14,#cr
        STRB    R14,[R4,#-1]
        Pull    "R6"
        B   %FT32

; copy font name into non-indirected menu title...

30
        Push    "R6"
        CMP     R6,#12                  ; max chars in menu header
        MOVGT   R6,#12                  ; limit to 12

31      LDRB    R14,[R0],#1             ; menu title is not indirected
        STRB    R14,[R1],#1
        SUBS    R6,R6,#1
        BNE     %BT31
        Pull    "R6"
        CMP     R6,#12
        BGT     %FT32                   ; if length > 12 then can't terminate

        TST     R2,#lfbit_returncr
        MOVEQ   R14,#0                  ; put in terminator
        MOVNE   R14,#cr
        STRB    R14,[R1,#-1]
32
        ADD     R1,R11,#12
        ASSERT  m_headersize-12 = 4*4
        Push    "R0,R2,R3,R4"           ; 4 registers
        LDR     R0,menucolours          ; m_ti_fg_colour etc.
        MOV     R2,R6,LSL #4
        SUB     R2,R2,#16*3-12          ; m_itemwidth
        MOV     R3,#44                  ; m_itemheight
        MOV     R4,#0                   ; m_verticalgap
        STMIA   R1!,{R0,R2,R3,R4}
        Pull    "R0,R2,R3,R4"

        EXIT

menucolours     DCB     7,2,7,0         ; title fg,bg, work fg,bg
                ALIGN

cleverwimpversion
        DCD     cleverwimp              ; min. Wimp version that gives indirected menu titles

;.......................................................................

; In    R0 -> item string
;       R2 = flags as on entry to Font_ListFonts
;       If R2 and lfbit_tickfont, [sp,#6*4] -> identifier to check against
;       R7 -> font block this relates to
;       R6 = length of string + 1
;       R11 -> menu header
;       [lf_menuparent] -> one after the parent menu item (or 0 => no parent)
;       R1,R4 -> buffers for menu and data (0 => just count)
;       If R1,R4<>0: R3,R5 = maximum allowed buffer size
;       R8,R9 = buffer sizes so far
; Out   menu item added, header updated (width)
;       [R1..], [R4..] updated if R1,R4<>0
;       R8,R9 updated
;       Error if R1,R4<>0 and R8>R3 or R9>R5

        ASSERT  Proc_RegList = "R0,R6"

lfmenu_newitem Entry "R0,R6"            ; NB: same Proc_RegList as lfmenu_newmenu

        Debuga  path,"New item: addr,data,strlen+1",R1,R4,R6
        DebugS  path,", string =",R0

        ADD     R8,R8,#mi_size
        ADD     R9,R9,R6

        CMP     R1,#0
        EXIT    EQ

        CMP     R8,R3
        CMPLE   R9,R5
        BGT     lfmenu_newitemerr

        ASSERT  mi_size = 6*4
        Push    "R0,R2-R5,R9"           ; we need R0,R2-R6 for item (R6 preserved anyway), and R9 for comparefontid

        MOV     R0,R6,LSL #4
        ADD     R0,R0,#12-16            ; R0 = string length*16+12
        LDR     R14,[R11,#m_itemwidth]
        CMP     R14,R0
        MOVLT   R14,R0
        STRLT   R14,[R11,#m_itemwidth]

        EOR     R14,R2,#lfbit_tickfont
        TST     R14,#lfbit_tickfont     ; NE => don't tick the font regardless
        BNE     %FT41

        Push    "R1"

        LDR     R1,[sp,#1*4+6*4+3*4+6*4] ; R1 -> tickfont name

        Debug   path,"lfmenu_newitem: R1,R7 =",R1,R7

        TST     R2,#lfbit_encodings
        MOVEQ   R9,#0                   ; R9 = flags for comparefontid
        MOVNE   R9,#lfff_encoding

        TEQ     R1,#1
        TEQEQ   R7,#0                   ; R1=1 and R7=0 => tick system font
        BEQ     %FT40
        CMP     R1,#&8000               ; values 0,2..&7FFF are reserved (don't match currently)
        CMPHS   R7,#1                   ; R7 must also be non-zero
        LDRHS   R0,[R7,#lff_identaddr]  ; R0 -> name of this font
        BLHS    comparefontid           ; EQ => this font/encoding should be ticked
40
        Pull    "R1"

41      MOVEQ   R0,#mi_it_tick          ; item flags (ticked if EQ, unticked if NE)
        MOVNE   R0,#0

        LDR     R2,lf_menuparent        ; if there's a parent, tick that too
        TEQ     R2,#0                   ; NB: parent ptr will have been updated by now
        TEQNE   R0,#0                   ; NB: tick parent if ANY child ticked
        LDRNE   R14,[R2,#mi_itemflags - mi_size]
        ORRNE   R14,R14,R0
        STRNE   R14,[R2,#mi_itemflags - mi_size]

; now we can set the 'title indirected' bit if necessary...

        LDR     R14,lf_menutitleflags   ; if Wimp supports indirected menu titles and menu title is
        TST     R14,#mtf_indirectable   ; indirected then set the 'title indirected' bit in the first
        TSTNE   R14,#mtf_indirected     ; menu item's flags
        ORRNE   R0,R0,#mi_it_indirecttitle

        MOV     R2,#-1                  ; submenu
        LDR     R3,=if_text :OR: if_indirected :OR: (7 :SHL: ifb_fcol) :OR: (0 :SHL: ifb_bcol)
     ;; MOV     R4,R4                   ; R4 -> buffer (correct already)
        MOV     R5,#-1                  ; R5 = validation string
     ;; MOV     R6,R6                   ; R6 = buffer size (correct already)
        STMIA   R1!,{R0,R2-R6}

        Pull    "R0,R2-R5,R9"

31      LDRB    R14,[R0],#1
        STRB    R14,[R4],#1
        SUBS    R6,R6,#1
        BNE     %BT31

        TST     R2,#lfbit_returncr
        MOVEQ   R14,#0                  ; put in terminator
        MOVNE   R14,#cr
        STRB    R14,[R4,#-1]

        CLRV
        EXIT

lfmenu_newmenuerr
lfmenu_newitemerr
        BL      xerr_buffoverflow
        EXIT
        LTORG

;.......................................................................

; In    R1 -> next menu item, or 0 => just counting
; Out   previous item marked as last if R1<>0

lfmenu_lastitem Entry

        TEQ     R1,#0
        LDRNE   R14,[R1,#mi_itemflags - mi_size]
        ORRNE   R14,R14,#mi_it_lastitem
        STRNE   R14,[R1,#mi_itemflags - mi_size]

        EXIT

;.......................................................................

; In    R0 -> string
; Out   R6 = length of string including terminator

count_R0 EntryS ""

        MOV     R6,R0

01      LDRB    R14,[R6],#1
        TEQ     R14,#0
        TEQNE   r14,#10
        TEQNE   r14,#13
        BNE     %BT01

        SUB     R6,R6,R0
        EXITS

;.......................................................................

; In    R0,R10 -> strings to compare
; Out   R6 = length of [R0..] up to and including the first "." or terminator
;       EQ => strings match up to the first dot (each contains one), or they match up to the terminator

strcmp_dot Entry "R7,R10"

        MOV     R14,R0

01      LDRB    R6,[R14],#1
        LDRB    R7,[R10],#1
        TEQ     R6,#"."                 ; treat "." as a terminator
        MOVEQ   R6,#0
        TEQ     R7,#"."                 ; for either string
        MOVEQ   R7,#0
        TEQ     R6,R7
        BNE     %FT02
        TEQ     R6,#0
        BNE     %BT01

        SUB     R6,R14,R0               ; R6 = length of string so far
        EXIT                            ; EQ => strings match

02      TEQ     R6,#"."                 ; search for first "." in [R0..]
        TEQNE   R6,#0
        LDRNEB  R6,[R14],#1
        BNE     %BT02

        SUBS    R6,R14,R0               ; R6 = length of string plus terminator
        EXIT                            ; NE => strings don't match

;.......................................................................

; In    R0,R1 -> strings to compare (0-terminated)
; Out   EQ => strings match (case insensitive)
;       LT => [R0] is earlier alphabetically

strcmp_nocase Entry "R0,R1"

        BL      strcmp_nocase_advance

        EXIT

;.......................................................................

; In    R0,R1 -> strings to compare (0-terminated)
; Out   EQ => strings match (case insensitive)
;       LT => [R0] is earlier alphabetically

strcmp_nocase_advance Entry "R6,R7"

01      LDRB    R6,[R0],#1
        LDRB    R7,[R1],#1
        LowerCase R6,R14                ; should use Territory module
        LowerCase R7,R14
        CMP     R6,R7
        EXIT    NE                      ; LT => [R0..] earlier, GT => [R1..] earlier
        TEQ     R6,#0
        BNE     %BT01
        EXIT                            ; EQ => strings match

;-----------------------------------------------------------------------

; In    <Font$Path> = current setting of font path
;       [lf_prefixhead] -> previous list of font prefixes
; Out   If different, fonts recached and Service_FontsChanged issued

try_listfonts_recache PEntry ListFonts, "R1-R4"

        BL      decodefontpath          ; R2 -> list of font prefixes
        PExit   VS

; if path identical, just call listfonts_recache (just scan unscanned prefixes)

        MOV     R4,#0                   ; flag => list was different

        LDR     R3,lf_prefixhead        ; R3 -> existing list
        Debug   path2,"try_listfonts_recache: old,new =",R3,R2
        TEQ     R2,R3
        BEQ     go_listfonts_recache

; go through existing list, removing references to fonts no longer present
; also copy flags of those prefixes that already existed

        Push    "R2"                    ; [sp] -> new list

        B       %FT05                   ; R3 -> old list

01      LDR     R2,[sp]

02      TEQ     R2,#0
        BEQ     %FT03

        Debug   path2,"Compare prefixes at",R2,R3

        ADD     R1,R2,#lfpr_prefix
        ADD     R0,R3,#lfpr_prefix
        BL      strcmp_nocase
        LDRNE   R2,[R2,#lfpr_link]
        BNE     %BT02

        LDRB    R14,[R3,#lfpr_flags]    ; copy flags (whether scanned)
        STRB    R14,[R2,#lfpr_flags]
        BL      updateprefixrefs        ; alter references from R3 to R2
        B       %FT04

03      MOV     R4,#1                   ; font list has changed
        BL      deleteprefixrefs        ; delete font blocks referencing R3

04      LDR     R3,[R3,#lfpr_link]
05      TEQ     R3,#0
        BNE     %BT01

; delete old prefix chain and install new one

        BL      deleteprefixblocks
        Pull    "R2"
        STR     R2,lf_prefixhead

; re-sort existing font blocks - the prefix order might have changed

        BL      sortfontblocks

; now rescan those prefixes that haven't been already

go_listfonts_recache
        BL      listfonts_recache       ; only looks in unscanned prefixes
                                        ; R4 = R4 + number of prefixes scanned

; issue service call if any prefixes had to be rescanned

        SavePSR LR
        Push    "R1,LR"
        TEQ     R4,#0
        MOVNE   R1,#Service_FontsChanged
        SWINE   XOS_ServiceCall
        Pull    "R1,LR"
        RestPSR LR,,f

        PExit

;.......................................................................

; In    <Font$Path> = current setting of font path
; Out   R2 -> linked list of prefix blocks representing this path
;       R2 = [lf_prefixhead] => path was the same

fontpathname    DCB     "<Font$$Path>",0
                ALIGN

decodefontpath Entry "R1,R3-R7"

        ASSERT  ?lf_fontname >= 256 :LAND: ?wrchblk >= 256

        ADR     R0,fontpathname
        wsaddr  R1,lf_fontname
        MOV     R2,#?lf_fontname
        SWI     XOS_GSTrans             ; R1 -> output string (0-terminated), R2 = length (excluding terminator)
        EXIT    VS
        BCS     err_overflow

; first do a quick check to see if the path is the same as before

        LDR     R5,lf_prefixhead

11      LDRB    R14,[R1],#1             ; check for null prefix elements (to be ignored)
        TEQ     R14,#" "                ; skip spaces
        TEQNE   R14,#","                ; and null elements
        BEQ     %BT11

        TEQ     R14,#"."                ; if prefix = ".", ignore it
        BNE     %FT14
        MOV     R6,R1                   ; R6 -> string so far
13      LDRB    R14,[R1],#1
        TEQ     R14,#" "
        BEQ     %BT13                   ; R14 = next non-space character
        TEQ     R14,#","
        TEQNE   R14,#0                  ; if terminator,
        BEQ     %BT11                   ; skip to the next prefix
        MOV     R1,R6                   ; R1 -> original character (".")

14      SUB     R1,R1,#1                ; R1 -> first relevant character of prefix element

        TEQ     R5,#0                   ; no more in list => check for end of string
        BEQ     %FT16

        ADD     R0,R5,#lfpr_prefix
12      LDRB    R3,[R1],#1              ; get next byte from <Font$Path>
        TEQ     R3,#" "                 ; skip spaces
        BEQ     %BT12
        TEQ     R3,#","
        MOVEQ   R3,#0
        LDRB    R4,[R0],#1              ; get next byte from prefix block
        TEQ     R3,R4                   ; do case-sensitive comparison (it's easier)
        BNE     go_decodefontpath
        TEQ     R4,#0
        BNE     %BT12

        SUB     R1,R1,#1                ; R1 -> terminator from this element ("," or 0)
        LDR     R5,[R5,#lfpr_link]      ; loop until all done
        B       %BT11

16      LDRB    R14,[R1]                ; have we also reached the terminator in the string?
        CMP     R14,#0
      [ debugpath
        BNE     go_decodefontpath
        Debug   path,"<Font$Path> unchanged"
      ]
        LDREQ   R2,lf_prefixhead        ; same list as before if so
        EXIT    EQ

; if path different, construct the relevant prefix blocks

go_decodefontpath
        wsaddr  R1,lf_fontname
        MOV     R5,#0                   ; R5 = head of list so far
                                        ; R6 = tail (not needed yet)
01      ADR     R3,wrchblk
        MOV     R4,#?wrchblk

02      LDRB    R7,[R1],#1              ; R7 = next character
        TEQ     R7,#" "
        BEQ     %BT02                   ; ignore spaces
        SUBS    R4,R4,#1
        BEQ     err_overflow
        STRB    R7,[R3],#1
        TEQ     R7,#","                 ; stop on "," or 0
        TEQNE   R7,#0
        BNE     %BT02

        RSBS    R3,R4,#?wrchblk-1       ; R3 = length of prefix excluding terminator
        BEQ     %FT04                   ; ignore null prefixes

        TEQ     R3,#1                   ; also ignore "." (ie. null Font$Prefix)
        LDREQB  R14,wrchblk
        TEQEQ   R14,#"."
        BEQ     %FT04

        MOV     R0,#ModHandReason_Claim
        ADD     R3,R3,#lfpr_prefix+1    ; allow for header and terminator
        SWI     XOS_Module
        BVS     err_tidy                ; delete all blocks claimed so far and exit

        MOV     R14,#0                  ; initialise prefix block
        STR     R14,[R2,#lfpr_link]
        STRB    R14,[R2,#lfpr_flags]
        ADR     R3,wrchblk
        ADD     R4,R2,#lfpr_prefix
03      LDRB    R14,[R3],#1             ; copy prefix over
        TEQ     R14,#","
        MOVEQ   R14,#0
        TEQNE   R14,#0
        STRB    R14,[R4],#1
        BNE     %BT03

        Debug   path2,"Prefix head,tail =",R5,R6

        TEQ     R5,#0                   ; if head null, set head and tail to this block
        MOVEQ   R5,R2
        STRNE   R2,[R6,#lfpr_link]      ; link into chain
        MOV     R6,R2                   ; and update tail pointer

        Debuga  path2,"New prefix block at",R2
        Debug   path2,", head,tail =",R5,R6

04      TEQ     R7,#0                   ; continue until no more elements
        BNE     %BT01

        MOV     R2,R5                   ; R2 -> list of prefix blocks

        Debug   path2,"New prefix list head =",R2

        EXIT

err_overflow
        BL      xerr_buffoverflow
        EXIT

err_tidy
        Push    "R0"
05      MOVS    R2,R5
        BNE     %FT06
        LDR     R5,[R2,#lfpr_link]
        Debug   path2,"Tidy prefix block at",R2
        MOV     R0,#ModHandReason_Free
        SWI     XOS_Module              ; ignore errors when freeing
        B       %BT05
06
        SETV
        Pull    "R0,$Proc_RegList,PC"

;.......................................................................

; In    [lf_prefixhead] -> linked list of prefix blocks
; Out   [lf_prefixhead] = 0, blocks freed

deleteprefixblocks Entry "R1"

        wsaddr  R1,lf_prefixhead
        BL      deletelinkedblocks

        EXIT

;.......................................................................

; In    R1 -> head of linked list of prefix blocks
; Out   [R1]=0, blocks freed

deletelinkedblocks EntryS "R0-R2"

        Debug   path2,"deletelinkedblocks: head =",R1

        ASSERT  lff_link = lfpr_link

        LDR     R2,[R1]                 ; R2 -> first item in list
        TEQ     R2,#0
        EXITS   EQ

        MOV     R14,#0
        STR     R14,[R1]                ; list = null

05      LDR     R1,[R2,#lfpr_link]
        MOV     R0,#ModHandReason_Free
        SWI     XOS_Module              ; ignore errors when freeing
        MOVS    R2,R1
        BNE     %BT05

        EXITS

;.......................................................................

; In    R3 -> prefix block to delete references to
;       [listfonts_head] -> linked list of font blocks
; Out   font blocks which reference R3 are deleted

deleteprefixrefs EntryS "R0,R2,R4-R5"

        Debug   path2,"deleteprefixrefs: prefix at",R3

        ADR     R4,listfonts_head - lff_link
        LDR     R5,[R4,#lff_link]
        B       %FT02

01      LDR     R5,[R2,#lff_link]       ; R5 -> next block (before freeing this one!)
        LDR     R14,[R2,#lff_prefixaddr]
        TEQ     R14,R3
        STREQ   R5,[R4,#lff_link]       ; make previous block point to next
        MOVNE   R4,R2                   ; R4 -> previous block (update if this one isn't being deleted)

      [ debugpath
        BNE     %FT00
        Debug   path2,"Delete font block referencing prefix",R2,R3
00
      ]
        MOVEQ   R0,#ModHandReason_Free
        SWIEQ   XOS_Module

02      MOVS    R2,R5
        BNE     %BT01

        EXITS

;.......................................................................

; In    R3 -> prefix block to alter references to
;       R2 -> new prefix block which replaces R3
;       [listfonts_head] -> linked list of font blocks
; Out   font blocks which reference R3 are altered to reference R2

updateprefixrefs EntryS "R4"

        Debug   path2,"updateprefixrefs: old,new",R3,R2

        LDR     R4,listfonts_head
        B       %FT02

01      LDR     R14,[R4,#lff_prefixaddr]
        TEQ     R14,R3
        STREQ   R2,[R4,#lff_prefixaddr]

        LDR     R4,[R4,#lff_link]
02      TEQ     R4,#0
        BNE     %BT01

        EXITS

;.......................................................................

; In    [lf_prefixhead] -> list of prefixes
;       [listfonts_head] -> list of known fonts
;       R4 = initial count of number of recaches
; Out   unscanned prefixes are rescanned and marked scanned
;       new font blocks created, and all font blocks resorted
;       R4 = R4 + number of prefixes rescanned

listfonts_recache EntryS "R1-R3"

        LDR     R3,lf_prefixhead
        TEQ     R3,#0
        EXITS   EQ

01      LDRB    R14,[R3,#lfpr_flags]
        TST     R14,#lfprf_scanned
        ADDEQ   R4,R4,#1                ; increment R4 => another prefix scanned
        BLEQ    listfonts_scanprefix
        BVS     %FT02
        LDR     R3,[R3,#lfpr_link]
        TEQ     R3,#0
        BNE     %BT01

        EXITS

02      ADD     R2,R0,#4                ; R2 -> original error message
        MOV     R1,#0                   ; no font name available
        ADR     R0,ErrorBlock_FontBadPrefix
        BL      XError_with_fontname_and_error
        EXIT
        MakeErrorBlock FontBadPrefix

;.......................................................................

; In    R3 -> prefix block of prefix to scan
; Out   [R3,#lfpr_flags] set => block has been scanned
;       New font blocks created as discovered

listfonts_scanprefix Entry "R1-R9"

      [ debugpath
        Debuga  path,"Scan prefix block at",R3
        ADD     R1,R3,#lfpr_prefix
        DebugS  path," ",R1
      ]

; R8 -> stack pointer on entry (sp is restored from it on exit)

        MOV     R8,sp                   ; R8 = stack pointer (in case of error)

; try to open the appropriate message file

        ADD     R0,R3,#lfpr_prefix      ;  in: R0 -> prefix
        BL      openmessagefile         ; out: R0 -> message file descriptor (if no error)
        BVS     lf_scanprefix_the_hard_way

        Debug   path,"Opened message file with descriptor",R0

        MOV     R9, R0                  ; R9 -> file descriptor (in case of error)

        ADR     R1,str_fonttoken        ; R1 -> "Font_*"
        MOV     R2,#lfff_symfont        ; fixed font encoding
        BL      enumerate_msgs

        ADRVC   R1,str_lfonttoken       ; R1 -> "LFont_*"
        MOVVC   R2,#lfff_langfont       ; font encoding depends on alphabet
        BLVC    enumerate_msgs

        ADRVC   R1,str_encodingtoken    ; R1 -> "Encoding_*"
        MOVVC   R2,#lfff_encoding       ; this is an encoding, not a font
        BLVC    enumerate_msgs

        ADRVC   R1,str_bencodingtoken   ; R1 -> "BEncoding_*"
        MOVVC   R2,#lfff_baseencoding   ; this is a base encoding, not a font
        BLVC    enumerate_msgs

        MOV     R2, R0
        SavePSR R3
        MOV     R0, R9
        SWI     XMessageTrans_CloseFile ; close message file regardless of error state
        MOVVC   R0, R2
        RestPSR R3, VC, f

        B       %FT99                   ; re-sorts font blocks and sets scanned bit

str_fonttoken      DCB  "Font_*",0      ; fonts which don't vary with alphabet
str_lfonttoken     DCB  "LFont_*",0     ; fonts which do vary with alphabet
str_encodingtoken  DCB  "Encoding_*",0  ; encodings
str_bencodingtoken DCB  "BEncoding_*",0 ; base encodings

str_IntMetrics     DCB  "IntMetrics",0  ; filename to look for inside font directories
str_Encodings      DCB  "Encodings",0   ; name of encodings directory

                ALIGN

;................................................................................

; no message file present - we must scan the directory structure recursively
; ignore VS on entry

; structure of items put on stack to act as workspace

                ^       0
scan_nameptr    #       4               ; pointer to name in lf_namebuffer
scan_flags      #       4               ; what kind of an object does this represent?
scan_counter    #       4               ; counter for OS_GBPB next time
scan_nextname   #       4               ; pointer to next name in buffer
scan_namecount  #       4               ; number of names remaining in buffer
scan_buffer     #       256             ; buffer for OS_GBPB
scan_size       #       0


; NB: R8 = sp on entry to this code - the stack pointer is restored from it
;     R8 is also used to access the original prefix block, stored in [sp,#2*4]

lf_scanprefix_the_hard_way

        ADRL    R9,lf_fontname          ; R9 -> name being built up

        ADDS    R7,R8,#0                ; R7 -> workspace so far (descending) - and clears V
        ADD     R0,R3,#lfpr_prefix      ; R0 -> input buffer
        MOV     R1,R9                   ; R1 -> where to append this element
        BL      scandir_open            ; R7 -> block on stack for scanning this directory
        BVS     %FT99

        LDRB    R14,[R9]                ; if prefix starts with ".", ignore it!
        TEQ     R14,#"."                ; copes with null <Font$Prefix>
        BEQ     %FT99

; read names from the relevant prefix, recursing into subdirectories

gogetnextlf
        BL      scandir_next            ; R1 -> next object name found in directory, R0 = type (0 => finished)
        BVS     %FT99

        ASSERT  (object_nothing < object_file) :LAND: (object_directory > object_file)
        CMP     R0,#object_file         ; LT => finished, EQ => file, GT => directory
        BLT     golf_recurseout
        BGT     golf_recursein

; if we're scanning 'Encodings', just create encoding block
; otherwise check for 'IntMetrics' and 'IntMetr<n>'

        LDR     R14,[R7,#scan_flags]
        TST     R14,#lfff_encoding
        BNE     golf_addencblock

        MOV     R0,R1                   ; R0 -> test string
        ADR     R1,str_IntMetrics       ; R1 -> match string
        BL      strcmp_trailingdigits   ; EQ => strings match, no digits, GT => match with digits, LT => no match
        LDRGE   R14,[R7,#scan_flags]
        ORREQ   R14,R14,#lfff_symfont
        ORRGT   R14,R14,#lfff_langfont
        STRGE   R14,[R7,#scan_flags]
        B       gogetnextlf

; add block for an encoding file

golf_addencblock
        MOV     R0,R1                           ; R0 -> object name to add
        LDR     R1,[R7,#scan_nameptr]           ; R1 -> where to add object name
        BL      scandir_open

        LDRVC   R2,[R8,#scan_nameptr-2*scan_size] ; R2 -> start of name (one level further in than fonts)
        LDRVC   R3,[R7,#scan_nameptr]             ; R3 -> end of name
        MOVVC   R0,#lfff_encoding                 ; R0 = flags for this block
        BLVC    scandir_addblock

        BLVC    scandir_close                   ; remove this block (it was only temporary)
        BVC     gogetnextlf
        BVS     %FT99

; create a new block on stack for this subdirectory, and start scanning it

golf_recursein
        MOV     R0,R1                           ; R0 -> directory name
        LDR     R1,[R7,#scan_nameptr]           ; R1 -> where to copy it to
        BL      scandir_open
        BVS     %FT99

        LDR     R14,[R7,#scan_flags+scan_size]  ; inherit 'encoding' attribute from parent
        TST     R14,#lfff_encoding              ; this allows subdirectories within the "Encodings" directory
        STRNE   R14,[R7,#scan_flags]
        BNE     %FT01

        LDR     R0,[R8,#scan_nameptr-scan_size] ; see if we are about to scan the encodings directory
        ADR     R1,str_Encodings
        BL      strcmp_nocase
        MOVEQ   R14,#lfff_encoding
        STREQ   R14,[R7,#scan_flags]

01      LDR     R1,[R7,#scan_nameptr]           ; append "." onto directory name to obtain prefix
        MOV     R14,#"."
        STRB    R14,[R1],#1
        STR     R1,[R7,#scan_nameptr]

        B       gogetnextlf

; finished scanning directory - if IntMetrics or IntMetr<n> found, create font block

golf_recurseout
        LDR     R0,[R7,#scan_flags]             ; see if this produced anything useful
        BICS    R0,R0,#lfff_encoding
        LDRNE   R3,[R7,#scan_nameptr]
        SUBNE   R3,R3,#1                        ; ignore "." on the end
        LDRNE   R2,[R8,#scan_nameptr-scan_size]
        BLNE    scandir_addblock
        BVS     %FT99

        BL      scandir_close           ; go up a level
        CMP     R7,R8                   ; continue unless this was the base level
        BLO     gogetnextlf

; finished (with or without error) - restore stack and sort the blocks that have been added

99      MOV     sp,R8                   ; restore stack pointer

        LDRVC   R3,[sp,#2*4]            ; R3 -> original prefix block
        LDRVCB  R14,[R3,#lfpr_flags]
        ORRVC   R14,R14,#lfprf_scanned  ; mark 'scanned' if no errors
        STRVCB  R14,[R3,#lfpr_flags]

        BL      sortfontblocks          ; resort fonts even if error

        EXIT

;..............................................................................

; In    R0 -> string being tested
;       R1 -> string to match with
; Out   EQ => strings match exactly (case insensitive)
;       GT => R1 is a leading substring of R2, followed by decimal digits
;       LT => no match

strcmp_trailingdigits Entry "R0-R3"

      [ debugpath2
        DebugS  path2,"Test string :",R0
        DebugS  path2,"Match string:",R1
        BL      dbg00
        MOVLT   R14,#-1
        MOVEQ   R14,#0
        MOVGT   R14,#1
        Debug   path2,"Result =",R14
        EXIT
dbg00   ALTENTRY
      ]

        MOV     R3,R0

        BL      strcmp_nocase_advance   ; R1,R2 -> point at which scan terminated
        EXIT    EQ                      ; matched already

01      LDRB    R14,[R0],#1             ; see if all the other characters are digits
        CMP     R14,#32
        BLE     %FT02

        CMP     R14,#"0"
        RSBGES  R14,R14,#"9"            ; GE => this is a digit, LT => it isn't
        BGE     %BT01
        EXIT    LT

02      LDRB    R14,[R1]                ; did we reach the end of the match string?
        TEQ     R14,#0
        SUBNE   R0,R0,R3
        TEQNE   R0,#10+1                ; or was the total length 10 characters (R0 is past terminator)?

        MOVEQ   R0,#1
        MOVNE   R0,#-1
        CMP     R0,#0                   ; LT => no match, GT => match with trailing digits

        EXIT

;..............................................................................

; In    R0 -> object name to append onto main name
;       R1 -> end of name (ie. where to append this bit)
;       R7 -> previous buffer on stack
; Out   R7 -> new buffer on stack, name copied to main buffer

scandir_open ROUT

      [ debugbrk
        TEQ     R7,sp
        BreakPt "R7 should = sp here!", NE
      ]

        DebugS  path2,"scandir_open:",R0

        MOV     R7,sp,LSL #12
        MOV     R7,R7,LSR #12                   ; R7 = space remaining on stack
        CMP     R7,#scan_size + 256
        BLT     xerr_buffoverflow               ; LR set up here so this will return to the caller

        SUB     sp,sp,#scan_size
        MOV     R7,sp

        Entry   "R0,R1"

01      LDRB    R14,[R0],#1
        STRB    R14,[R1],#1
        TEQ     R14,#0
        BNE     %BT01

        SUB     R1,R1,#1                        ; R1 -> name terminator
        STR     R1,[R7,#scan_nameptr]           ; where to stick new names
        MOV     R14,#0
        STR     R14,[R7,#scan_flags]
        STR     R14,[R7,#scan_counter]
        STR     R14,[R7,#scan_namecount]        ; no objects in buffer yet

        CLRV
        EXIT

;..............................................................................

; In    R7 -> previous buffer on stack
;       sp = R7
; Out   R7 -> next buffer up
;       sp = R7

scandir_close ROUT

      [ debugbrk
        TEQ     R7,sp
        BreakPt "R7 should = sp here!", NE
      ]

        ADD     R7,R7,#scan_size
        MOV     sp,R7

        MOV     PC,LR

;..............................................................................

; In    R7 -> block on stack of this level
;       R9 -> start of pathname to scan
;       [R7,#scan_nameptr] -> end of pathname to scan
; Out   R0 = type of next object in directory (0 => directory finished)
;       R1 -> object name (if R0 <> 0)

scandir_next Entry "R2-R10"

03      LDR     R2,[R7,#scan_namecount]
        SUBS    R2,R2,#1
        BLT     %FT01

        STR     R2,[R7,#scan_namecount]
        LDR     R1,[R7,#scan_nextname]          ; R1 -> next object definition
        LDR     R0,[R1],#4                      ; R0 = object type, R1 -> name

        MOV     R2,R1
02      LDRB    R14,[R2],#1                     ; scan to end of name to set up nextname for next time
        CMP     R14,#0
        BNE     %BT02
        ADD     R2,R2,#3 + 16                   ; point to type field of next object
        BIC     R2,R2,#3
        STR     R2,[R7,#scan_nextname]

        DebugS  path2,"scandir_next returns:",R1

        EXIT

; no more names in buffer - we must call OS_GBPB to read some more

01      LDR     R4,[R7,#scan_counter]           ; if counter < 0, we've finished
        CMP     R4,#0
        MOVLT   R0,#0
        EXIT    LT

        LDR     R2,[R7,#scan_nameptr]
        LDRB    R10,[R2,#-1]                    ; R10 = last character of pathname
        TEQ     R10,#"."
        MOV     R14,#0
        STREQB  R14,[R2,#-1]                    ; strip terminating dot if present
        STRNEB  R14,[R2,#0]                     ; else just provide terminator

        DebugS  path2,"Look in directory",R9

        MOV     R0,#OSGBPB_ReadDirEntriesInfo
        MOV     R1,R9                           ; R1 -> directory name
        ADD     R2,R7,#scan_buffer              ; R2 -> buffer space (on stack)
        MOV     R3,#?scan_buffer                ; R3 = number of names to read (as many as possible!)
        MOV     R5,#?scan_buffer                ; R5 = buffer size
        MOV     R6,#0                           ; R6=0 => match all names
        SWI     XOS_GBPB
        EXIT    VS                              ; error!

        LDR     R14,[R7,#scan_nameptr]
        STRB    R10,[R14,#-1]                   ; restore last character of name

        STR     R3,[R7,#scan_namecount]         ; R3 = number of names read
        ADD     R2,R2,#16
        STR     R2,[R7,#scan_nextname]          ; nextname -> type field of first object
        STR     R4,[R7,#scan_counter]
        B       %BT03                           ; now try again

;..............................................................................

; In    R0 = flags for new block
;       R2 -> start of id/name
;       R3 -> end of id/name
;       R8 -> stack frame of caller
;       [R8,#2*4] -> prefix block address
; Out   makefontcatblock called with parameters derived from those given

scandir_addblock Entry "R1-R5"

; Bug fix by Chris Murray:
;
; The flags suggest a font was found but it could be null if we've already scanned
; its parent directory earlier, so we must check the font name's length to see if
; anything was really produced.

        SUBS    R3,R3,R2                ; R3 = length of font identifier
        EXIT    LE                      ; oops, nothing left

        LDR     R1,[R8,#2*4]            ; R1 -> prefix block addr
        MOV     R4,R2                   ; R4 -> name (identical)
        MOV     R5,R3

        BL      makefontcatblock        ; added to start of font list

        EXIT                            ; can return errors

;..............................................................................

; In    R0 -> prefix
;       [territory] = territory number
; Out   R0 -> message file descriptor of "<prefix>Message<territory>"

openmessagefile Entry "r1,r2", 256      ; frame size = 256 bytes

        MOV     r1, sp
        BL      copy_r0r1               ; r1 -> character after end of prefix

        LDR     r2, territory           ; r2 = current territory number
        ADR     r0, str_fontnames       ; leafname of file containing font names
        BL      copy_r0r1_suffixR2      ; copy [r0] to [r1], appending decimal suffix

        ADRVC   r0, lf_messagedesc      ; r0 -> listfonts message descriptor
        MOVVC   r1, sp                  ; r1 -> filename
        MOVVC   r2, #0                  ; r2 = 0 => I don't want a local copy
        DebugS  path2,"MessageTrans_OpenFile ", r1
        SWIVC   XMessageTrans_OpenFile

        EXIT                            ; frame automatically removed

str_fontnames   DCB     "Messages", 0
                ALIGN

;................................................................................

; In    R0 -> leafname
;       R1 -> destination buffer
;       R2 = number to put on the end as a decimal suffix
; Out   [R1..] = leafname<n>, where <n> is the decimal representation of R2
;       If the total length would be > 10, trailing characters from the leafname are suppressed

copy_r0r1_suffixR2 EntryS "R0-R3", 12   ; buffer on stack for number buffer

        CMP     R2,#0                   ; R2 < 0 => no suffix
        BLT     %FT10

        MOV     R0,R2                   ; R0 = number to convert
        MOV     R1,sp                   ; R1 -> output buffer
        MOV     R2,#10                  ; R2 = buffer size (max 10 chars)
        SWI     XOS_ConvertCardinal4
        BVS     %FT99

        SUB     R1,R1,R0                ; R1 = length of number
        RSB     R3,R1,#10               ; R3 = space left for leafname

        ADD     R14,sp,#Proc_RegOffset
        LDMIA   R14,{R0,R1}             ; recover parameters

01      LDRB    R14,[R0],#1             ; copy main part of leafname
        TEQ     R14,#0
        STRNEB  R14,[R1],#1
        SUBNES  R3,R3,#1
        BNE     %BT01

        MOV     R0,sp                   ; R0 -> number on stack

10      BL      copy_r0r1               ; copy suffix or original leafname
        EXITS

99      STRVS   R0,[sp,#Proc_RegOffset]
        EXIT    VS

;................................................................................

; In    R1 -> wildcarded token to match with
;       R2 = flags to put into resulting blocks
;       R3 -> prefix block of prefix to scan
;       R0 = R9 = message file descriptor
; Out   set of font/encoding blocks created

enumerate_msgs Entry "R1-R8"

        MOV     R8, R2                  ; R8 = original flags
        MOV     R4, #0                  ; R4 = place marker (0 for first call)
enum_msgs
        LDR     R1, [sp, #0*4]          ; R1 -> token to match with
        ADR     R2, lf_tempbuffer       ; R2 -> output buffer
        MOV     R3, #?lf_tempbuffer     ; R3 = buffer size
        SWI     XMessageTrans_EnumerateTokens
        BVS     done_enum

        MOVS    R1, R2                  ; R1 -> token found
        BEQ     done_enum

        DebugS  path2,"Message token enumerated ",R1

; skip prefix (must end in underscore)

01      LDRB    R14,[R2],#1             ; afterwards R2 -> font ID
        SUB     R3,R3,#1                ;            R3 = length of font ID without terminator
        TEQ     R14,#"_"
        BNE     %BT01

        Push    "R2, R3, R4"            ; save ID addr,size and place marker

        ADR     R2, lf_tempbuffer2
        MOV     R3, #?lf_tempbuffer2
        MOV     R4, #0
        MOV     R5, #0
        MOV     R6, #0
        MOV     R7, #0
        SWI     XMessageTrans_Lookup
        ADDVS   sp, sp, #3 * 4          ; correct stack
        BVS     done_enum

        MOV     R5, R3                  ; if result = "", ID and name are identical
        MOV     R4, R2

        Pull    "R2, R3"                ; R2,R3 -> identifier

; Patch by Chris Murray to prefix base encodings with a "/" character...

        TST     R8,#lfff_baseencoding   ; have we just looked up a base encoding?
        MOVEQ   R0,R8                   ; no,  so R0 = original flags
        MOVNE   R0,#lfff_encoding       ; yes, so R0 = encoding (forget it was a base encoding)
        MOVNE   R14,#"/"                ;      prefix token with a "/"
        STRNEB  R14,[R2,#-1]!           ;
        ADDNE   R3,R3,#1                ;      increment length

; End of patch.

        TEQ     R5,#0                   ; does name = "" ?
        MOVEQ   R4,R2                   ; if so, use id
        MOVEQ   R5,R3

        LDR     R1, [sp, #1*4 + 2*4]    ; R1 -> prefix block (R3 on entry to listfonts_scanprefix)
        BL      makefontcatblock        ; R2,R3 -> identifer, R4,R5 -> name
        MOVVC   R0, R9                  ; restore R0

        Pull    "R4"                    ; restore placeholder
        BVC     enum_msgs

done_enum
        EXIT

;..............................................................................

; In    R0 = flags to put into new block
;       R1 -> prefix block
;       R2 -> font identifier
;       R3 = length of font identifier (no terminator)
;       R4 -> font name
;       R5 = length of font name (no terminator)
; Out   R2 -> new font block, linked into chain
;       R0 corrupt

makefontcatblock Entry "R3-R9"

        MOV     R8,R0                   ; R8 = flags to put into block (NOT NEEDED!?)

      [ debugpath2
        MOV     R14,#0
        STRB    R14,[R2,R3]
        STRB    R14,[R4,R5]
        Debug   path2,"makefontcatblock: prefix block at",R1
        TEQ     R2,R4
        BNE     %FT100
        DebugS  path2,"                  font id/name =",R2
        B       %FT101
100
        DebugS  path2,"                  font id   =",R2
        DebugS  path2,"                  font name =",R4
101
      ]

; Added by C.Murray to find default font in family (ends with "*")

        SUB     R14,R5,#1               ; R14 -> last character in font name
        LDRB    R14,[R4,R14]            ; R14 =  last character in font name
        TEQ     R14,#"*"                ; is it the 'default font' character?
        MOVNE   R8,R0                   ; no,  so just use original flags
        ORREQ   R8,R0,#lfff_default     ; yes, so set 'default' bit in flags and
        SUBEQS  R5,R5,#1                ; shrink length to ignore the "*"
        MOVEQ   R4,R2                   ; EQ => fontname was just "*" so use
        MOVEQ   R5,R3                   ;       the font identifier

; End of patch.

        MOV     R6,R2                   ; R6 -> font identifier
        MOV     R7,R3                   ; R7 = length

        ADD     R3,R5,#lff_size + 1     ; allow for header and terminator
        TEQ     R2,R4                   ; if identifier and name not the same,
        ADDNE   R3,R3,R7                ; allow for separate strings
        ADDNE   R3,R3,#1                ; (and another terminator)

        MOV     R0,#ModHandReason_Claim
        SWI     XOS_Module
        EXIT    VS

        LDR     R14,listfonts_head
        STR     R14,[R2,#lff_link]
        STR     R8,[R2,#lff_flags]      ; R8 = flags to store in block
        STR     R1,[R2,#lff_prefixaddr]

        ADD     R3,R2,#lff_size
        STR     R3,[R2,#lff_nameaddr]

        TEQ     R4,R6
        BLNE    copyR4R5toR3            ; copy name only if different

        MOVEQ   R0,#0                   ; territory 0 => name same as id
        LDRNE   R0,territory
        STR     R0,[R2,#lff_territory]

        STR     R3,[R2,#lff_identaddr]
        MOV     R4,R6
        MOV     R5,R7
        BL      copyR4R5toR3            ; copy identifier (may also be name)

        STR     R2,listfonts_head

        Debug   path2,"New font/encoding block at",R2

        CLRV
        EXIT

;..............................................................................

; In    R4 -> input string
;       R5 = length (no terminator)
;       R3 -> output buffer
; Out   [R3..] = string plus terminator (0), R3 updated

copyR4R5toR3 EntryS "R4,R5"

11      LDRB    R14,[R4],#1
        STRB    R14,[R3],#1
        SUBS    R5,R5,#1
        BNE     %BT11
        MOV     R14,#0                  ; stick in terminator
        STRB    R14,[R3],#1

        EXITS

;..............................................................................

; In    [listfonts_head] -> font blocks, unordered
; Out   [listfonts_head] -> font blocks, ordered alphabetically and by font prefix

sortfontblocks EntryS "R0-R4,R8"

01      MOV     R8,#0                   ; flag => swaps have occurred

        ADR     R2,listfonts_head - lff_link
        Debug   path2,"sortfontblocks: &listfonts_head =",R2

        LDR     R3,[R2,#lff_link]       ; R3 -> block #1
        TEQ     R3,#0
        BEQ     %FT10                   ; finished if no more

02      LDR     R4,[R3,#lff_link]       ; R4 -> block #2
        TEQ     R4,#0
        BEQ     %FT10                   ; finished if no more

        LDR     R0,[R3,#lff_nameaddr]
        LDR     R1,[R4,#lff_nameaddr]
        BL      strcmp_nocase           ; first compare font names
        BLT     sortf_less
        BGT     sortf_greater

        LDR     R0,[R3,#lff_prefixaddr] ; if names equal, compare prefix addrs
        LDR     R1,[R4,#lff_prefixaddr]

        LDR     R14,lf_prefixhead
03      TEQ     R14,R0
        BEQ     sortf_less
        TEQ     R14,R1
        BEQ     sortf_greater
        LDR     R14,[R14,#lfpr_link]
      [ debugbrk
        TEQ     R14,#0
        BreakPt "Prefix not found",EQ
      ]
        B       %BT03

sortf_greater
        LDR     R0,[R4,#lff_link]       ; swap blocks over
        STR     R4,[R2,#lff_link]
        STR     R3,[R4,#lff_link]
        STR     R0,[R3,#lff_link]
        MOV     R8,#1
        MOV     R2,R4                   ; R2 -> previous block, R3 -> block #1
        B       %BT02

sortf_less
        MOV     R2,R3                   ; R2 -> previous block
        MOV     R3,R4                   ; R3 -> block #1
        B       %BT02

10      TEQ     R8,#0                   ; were any blocks swapped?
        BNE     %BT01

        EXITS                           ; must preserve flags (and error state)

;---------------------------------------------------------------------------------

; SWI Font_DecodeMenu (&400A0)
; In    R0 = flags: bit 0 set => this is an encoding menu
;                         clr => this is a font menu
;                   bits 1..31 reserved (must be 0)
;       R1 -> menu definition
;       R2 -> menu selections (word array)
;       R3 -> buffer to contain answer (0 => just return size)
;       R4 = size of buffer (if R3<>0)
; Out   R2 -> rest of menu selections (if R3<>0 on entry)
;       [R3..] = string to pass to Font_FindFont (if R3<>0 on entry)
;       R4 = size of buffer required to hold output string
;          = 0 => no font selected

dcd_encoding    *       1 :SHL: 0
dcd_reserved    *       -1 :SHL: 1

SWIFont_DecodeMenu Entry "R0-R9"

        Debug   path,"Font_DecodeMenu",R0,R1,R2,R3,R4

        ANDS    R9,R0,#dcd_encoding     ; R9=0 if looking for non-encodings
        MOVNE   R9,#lfff_encoding       ; R9=lfff_encoding if looking for encodings

        BICS    R14,R0,#:NOT:dcd_reserved
        BLNE    xerr_badparameters

        BLVC    try_listfonts_recache   ; ensure font list is up-to-date
        BVS     %FT80

; construct a name representing the menu selection

        MOV     R6,#0                   ; R6 = size of output buffer so far
        MOV     R8,#0                   ; R8 = default font to use if no exact match

        ADR     R0,fontfilename         ; R0 -> output buffer
        BL      getmenuitem             ; updates [R0..],R0,R1,R2, LT => no selection
        BLT     %FT80

        LDR     R1,[R1,#m_headersize+mi_submenu]
        BL      getmenuitem

        MOV     R14,#0                  ; terminate properly
        STRB    R14,[R0,#-1]

; search the list of known fonts for a match

      [ debugpath
        ADR     R0,fontfilename
        DebugS  path,"DecodeMenu: search for ",R0
      ]

        LDR     R7,listfonts_head
        B       %FT03

01      LDR     R14,[R7,#lff_flags]     ; see if the type matches that requested
        AND     R14,R14,#lfff_encoding
        TEQ     R14,R9
        ADREQ   R0,fontfilename         ; R0 -> string representing menu selection
        LDREQ   R10,[R7,#lff_nameaddr]  ; R10 -> string representing this font
      [ debugpath2
        BNE     %FT00
        Debuga  path2,"next font: R7 =",R7
        Debug   path2,", strcmp_dot",R0,R10
        DebugS  path2,"name 1:",R0
        DebugS  path2,"name 2:",R10
00
      ]
        BLEQ    strcmp_dot              ; R6 = string length up to & including "."
        BNE     %FT02

        Debug   path2,"match: R6 =",R6

        ADD     R0,R0,R6                ; R0 -> rest of name from menu
        ADD     R10,R10,R6              ; R10 -> rest of this name

        DebugS  path2,"rest of name ",R0
        DebugS  path2,"         and ",R10

        LDRB    R14,[R0,#-1]            ; if main menu item selected, choose default from submenu
        TEQ     R14,#0
        BNE     %FT05

        TEQ     R8,#0                   ; R8 = first font in family if no other default
        MOVEQ   R8,R7

        LDR     R14,[R7,#lff_flags]     ; the default one should be marked
        TST     R14,#lfff_default
        BNE     decodemenu_found
        B       %FT02

05      LDRB    R14,[R10,#-1]           ; if font has no suffix, see if "(Regular)" was selected
        TEQ     R14,#0
        Push    "R0", EQ
        addr    R0,msg_regular, EQ
        BLEQ    LookupR0                ; ensure that r1 -> decoded token
        MOVEQ   R1,R0
        Pull    "R0", EQ                ; ensure that r0 is preserved.
        MOVNE   R1,R10
        BL      strcmp_nocase           ; compare rest of font name or "(Regular)"
        BEQ     decodemenu_found

02      LDR     R7,[R7,#lff_link]
03      TEQ     R7,#0
        BNE     %BT01

        MOVS    R7,R8                   ; see if we matched the family name but there was no default
        BNE     decodemenu_found

        ADR     R1,fontfilename         ; R1 -> font name, R9 = flags ("Font not found" or "Encoding not found")
        BL      XError_fontnotfound

80      STRVC   R2,[sp,#2*4]            ; R2 on exit => rest of menu selection list
        STRVC   R6,[sp,#4*4]            ; R4 on exit = buffer size required
        Debug   path2,"DecodeMenu returns R2,R4 =",R2,R6
        PullS   "$Proc_RegList"

; found block matching menu string - fill in buffer / count size as appropriate

decodemenu_found
        MOV     R6,#1                   ; R6 = buffer size so far (allow for terminator)

        BL      output_R7_toR3R6        ; update R3,R6 for \F<ident>[\f<t> <name>]

        B       %BT80

;.................................................................................

; In    R0 -> output buffer
;       R1 -> menu header
;       R2 -> list of menu selections
; Out   [R0..] = menu item string terminated by "."
;       R0 -> byte after "."
;       R1 -> menu item - m_headersize
;       R2 -> remainder of menu selection list
;       LT => no item selected

getmenuitem Entry "R6"

        LDR     R14,[R2]

        Debug   path2,"getmenuitem: R0,R1,R2,[R2] =",R0,R1,R2,R14

        CMP     R14,#-1
        EXIT    EQ                      ; -1 => no menu selection

        ADD     R2,R2,#4                ; update menu selection pointer

        ASSERT  mi_size = 24
        ADD     R14,R14,R14,LSL #1
        ADD     R1,R1,R14,LSL #3        ; R1 += 24 * R14

        LDR     R14,[R1,#m_headersize+mi_iconflags]
        TST     R14,#if_indirected
        ADDEQ   R6,R1,#m_headersize+mi_icondata
        LDRNE   R6,[R1,#m_headersize+mi_icondata+ii_buffer]

        Debuga  path2,"getmenuitem: copy from",R6
        Debug   path2," to",R0

01      LDRB    R14,[R6],#1             ; R6 -> input string
        CMP     R14,#" "
        MOVLT   R14,#"."                ; terminate with "."
        STRB    R14,[R0],#1
        BGE     %BT01

        CMP     R14,R14                 ; EQ => menu item was copied
        EXIT

;..............................................................................

; Call the territory manager to find out the territory number and alphabet identifier
; If SWI not known, defaults to territory 1 (UK) and alphabet 'Latin1'
; Out   [territory] = territory number
;       [territory_alphabet..] is not set up here - getalphabet_R1 does it dynamically
;

readterritory Entry "R0-R2"

        BL      closemessagefile        ; sets [messagefile] to 0

        ADR     R0,messagefilehandle
        ADR     R1,messagefilename
        MOV     R2,#0                   ; this 'fix' corrupted R2 (now stacks R0-R2, -Chris).
        SWI     XMessageTrans_OpenFile  ; "SWI not known" => MessageTrans not loaded
        STRVC   R0,messagefile
     ;; BLVS    check_nosuchswi         ; needs to check for file not found and filing system not present etc.
     ;; BVS     %FT99                   ; so let's just do our own thing whatever

        SWI     XTerritory_Number
        STRVC   R0,territory

; This is now done in getalphabet_R1 (as needed)
;        MOVVC   R0,#-1
;        SWIVC   XTerritory_AlphabetIdentifier
;        ADRVC   R1,territory_alphabet
;        BLVC    copy_r0r1

        MOVVC   R0,#-1
        SWIVC   XTerritory_WriteDirection
        STRVC   R0,territory_writedir
        EXIT    VC

; if error while trying to read territory info, check for "SWI not known" and provide defaults if so

        ; Don't give up if Territory Manager returns an error

        MOV     R0,#1                   ; default territory is "UK"
        STR     R0,territory

        MOV     R0,#0
        STR     R0,territory_writedir

; This is now done in getalphabet_R1
;        ADR     R0,str_Latin1           ; max length is 10 chars plus terminator
;        ADR     R1,territory_alphabet
;        BL      copy_r0r1

        CLRV
        EXIT

99      STR     R0,[sp]                 ; error exit
        EXIT

messagefilename DCB     "Resources:$.Resources.Fonts.Messages", 0

str_Latin1      DCB     "Latin1", 0

        ALIGN

;.................................................................................

; Check current alphabet number, re-reading alphabet identifier if it's changed
; Exit: R1 -> alphabet identifier (in [territory_alphabet..])

OSByte_Alphabet * 71

getalphabet_R1 EntryS "R0,R2-R5"

        MOV     R0,#OSByte_Alphabet
        MOV     R1,#127                 ; read current alphabet number
        SWI     XOS_Byte
        BVS     %FT01

        MOVS    R3,R1
        BEQ     %FT01                   ; invalid response

        LDR     R14,LastAlphabet
        CMP     R0,R14
        BEQ     %FT90

        STR     R1,LastAlphabet

        MOV     R1,#Service_International
        MOV     R2,#Inter_ANoToANa      ; translate from alphabet number to name
        ADR     R4,territory_alphabet
        MOV     R5,#?territory_alphabet
        SWI     XOS_ServiceCall
        BVS     %FT01
        TEQ     R1,#0
        BNE     %FT01
        CMP     R5,#?territory_alphabet
        STRLTB  R1,[R4,R5]              ; terminate the returned string

90      ADR     R1,territory_alphabet
        EXITS

01      MOV     R0,#-1
        STR     R0,LastAlphabet

        ADR     R0,str_Latin1           ; max length is 10 chars plus terminator
        ADR     R1,territory_alphabet
        BL      copy_r0r1

        B       %BT90

;.................................................................................

; In    [messagefile] -> message file, or 0 => not open
; Out   [messagefile] = 0, message file closed if was open
;       errors are ignored (otherwise you can get into horrible loops)

closemessagefile EntryS "R0"

        LDR     R0,messagefile
        TEQ     R0,#0
        MOVNE   R14,#0
        STRNE   R14,messagefile
        SWINE   XMessageTrans_CloseFile

        EXITS

;.................................................................................

; In    R0 -> error block
;       VS
; Out   VC => error was "SWI not known"

check_nosuchswi Entry "R1"

        LDR     R1,[R0]
        LDR     R14,=ErrorNumber_NoSuchSWI
        TEQ     R1,R14
        CLRV    EQ

        EXIT
        LTORG

str_field_id    DCB     "\\F", 0        ; font identifier
str_field_nm    DCB     "\\f", 0        ; font name
str_field_encid DCB     "\\E", 0        ; encoding identifier
str_field_encnm DCB     "\\e", 0        ; encoding name
str_space       DCB     " "             ; separator after territory number
                ALIGN

        ASSERT  ?str_field_id = 3       ; watch out for new Aasm!!!
        ASSERT  ?str_field_nm = 3       ; (it converts C escape sequences)
        ASSERT  ?str_field_encid = 3
        ASSERT  ?str_field_encnm = 3

;.................................................................................

; In    R7 -> font/encoding block
;       R3 -> output buffer, or 0 => just count size
;       R6 = buffer size required so far (including terminator)
; Out   If R3<>0, [R3..] = "\F<ident>\f<t> <name>" (or \E and \e)
;       R6 = extra buffer space required

output_R7_toR3R6 Entry ""

        LDR     R14,[R7,#lff_flags]     ; get correct prefix (\F or \E)
        TST     R14,#lfff_encoding
        ADREQ   R0,str_field_id
        ADRNE   R0,str_field_encid
        BL      output_R0_toR3R6        ; updates R3 and R6

        LDRVC   R0,[R7,#lff_identaddr]  ; if identifier and name are the same, it's easy
        BLVC    output_R0_toR3R6        ; updates R3 and R6
        EXIT    VS

; now output "\f<t> <name>" or "\e<t> <encname>" if name is different

        LDR     R1,[R7,#lff_nameaddr]
        TEQ     R0,R1
        EXIT    EQ

        LDR     R14,[R7,#lff_flags]     ; get correct prefix (\F or \E)
        TST     R14,#lfff_encoding
        ADREQ   R0,str_field_nm
        ADRNE   R0,str_field_encnm
        BL      output_R0_toR3R6        ; updates R3 and R6

        LDRVC   R0,[R7,#lff_territory]  ; territory number of this name
        ADRVC   R1,tempbuffer
        MOVVC   R2,#12
        SWIVC   XOS_ConvertCardinal4
        BLVC    output_R0_toR3R6        ; output territory number

        ADRVC   R0,str_space
        BLVC    output_R0_toR3R6        ; we need a separator so name can contain digits

        LDRVC   R0,[R7,#lff_nameaddr]
        BLVC    output_R0_toR3R6        ; output name

        EXIT

;.................................................................................

; In    R0 -> source string
;       R3 -> output buffer, or 0 => just count size
;       R4 = buffer size (if R3<>0)
;       R6 = output buffer size so far, including terminator)
; Out   If R3<>0, [R3..] contains a copy of the string
;       R6 updated
;       R0 -> terminator of source string

output_R0_toR3R6 Entry "R0,R5"          ; preserve R0 (for Font_DecodeMenu)
        DebugS  path2,"output_R0: ",R0

        SUB     R5,R6,#1                ; allow for terminator just about to be added
        BL      count_R0                ; R6 = length of string + 1
        ADD     R6,R5,R6                ; R6 = total length so far (including terminator)
        CMP     R3,#0
        EXIT    EQ                      ; exit if just counting

        CMP     R6,R4
        BLGT    xerr_buffoverflow
        STRVS   R0,[sp]
        EXIT    VS

01      LDRB    R14,[R0],#1             ; copy string if R3<>0, and update R6 regardless
        CMP     R14,#32                 ; V clear
        STRGEB  R14,[R3],#1
        BGE     %BT01

        MOV     R14,#0                  ; always terminate with 0
        STRB    R14,[R3]

        EXIT

        END
