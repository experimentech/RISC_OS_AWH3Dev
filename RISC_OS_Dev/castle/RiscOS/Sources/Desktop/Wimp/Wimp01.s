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

;;-----------------------------------------------------------------------------
;; Register names
;;-----------------------------------------------------------------------------

wsptr           RN      R12
userblk         RN      R11             ; rectlinks
handle          RN      R10             ; rectcoords
rectlinks       RN      R11             ; userblk
rectcoords      RN      R10             ; handle

y1              RN      R9
x1              RN      R8
y0              RN      R7
x0              RN      R6

cy1             RN      R5
cx1             RN      R4
cy0             RN      R3
cx0             RN      R2

ur_pollmask     RN      R0
ur_reasoncode   RN      R0
ur_userblk      RN      R1

                ^       0
u_cw0           #       0               ; start of create data
u_handle        #       4
u_ow0           #       0               ; start of open data
u_wax0          #       4
u_way0          #       4
u_wax1          #       4
u_way1          #       4
u_scx           #       4
u_scy           #       4
u_bhandle       #       4
u_ow1           #       0
              [ ChildWindows
u_flags         #       4               ; for supplying new window flags (new form of Wimp_OpenWindow)

                ^       u_ow1
              ]
u_scroll        #       8               ; x,y scroll-offsets (for user scroll)



;;-----------------------------------------------------------------------------
;; Macro definitions
;;-----------------------------------------------------------------------------

        MACRO
$lab    CheckAllWindows $message
$lab
      [ debugcheck :LAND: debug
        Push    "LR,PC"
        BL      checkallwindows
        BNE     %FT01
        Debug   check,"**** Bad window data found [ $message ] ****"
01
        LDR     R14,[SP,#4]
        TEQP    R14,#0
        LDR     LR,[SP],#8
      ]
        MEND

        MACRO
$lab    AddIcon $name,$pressable,$sprite,$width,$height
        int_AddIcon $name, $sprite, $width, $height
      [ "$pressable"=""
        [ "$sprite"=""
          int_AddIcon "p$name", $sprite, $width, $height
        |
          int_AddIcon "p$name", "p$sprite", $width, $height
        ]
      ]
        MEND

        MACRO
$lab    int_AddIcon $n,$s,$w,$h
      [ "$s"=""
        = "$n",0
      |
        = "$s",0
      ]
        ALIGN
      [ "$w"=""
        & &0
      |
        & :INDEX:$w
      ]
      [ "$h"=""
        & &0
      |
        & :INDEX:$h
      ]

tool_$n                         # 4

        MEND


        MACRO
$l      CallFilter $name,$nohandle
        Push    "R2,R11,wsptr"
 [ "$nohandle" = ""
        LDR     R2,taskhandle           ; handle of calling task
 ]
        ADRL    R11,$name.WP            ; address the vector table
        MOV     LR,PC                   ; setup suitable return address
        LDMIA   R11,{wsptr,PC}          ; call the filter
        Pull    "R2,R11,wsptr"          ; restore pushed registers
        MEND


        MACRO
$l      Hex     $rd,$rs
$l      SUB     $rd,$rs,#"0"
        CMP     $rd,#10
        SUBCS   $rd,$rd,#"A"-"9"-1
        MEND

        MACRO
$label  CLI     $command
$label
        Push    "R0,R14"
        ADR     R0,%FT01
        SWI     XOS_CLI
        B       %FT02
01
        DCB     "$command",13
        ALIGN
02
        Pull    "R0,R14"
        MEND

        MACRO
        pullx   $list
        LDMFD   R13,{$list}
        MEND

        MACRO
$lab    MyEntry $string
$lab
      [ debugtask2
        Push    "R0"
        TEQ     pc,pc
        LDRNE   R0, [sp, #(1 + 11 + 2 + 4) * 4]
        LDREQ   R0, [sp, #(1 + 11 + 2 + 3) * 4]   ; get return address from stack - skip:
                                                  ; 1 word:   for storing R0 here
                                                  ; 11 words: registers stored by generic Wimp SWI code
                                                  ; 2 words:  for Wimp re-entrancy
                                                  ; 1 word:   return address (in kernel SWI despatcher)
                                                  ; 1 word:   used by kernel - caller R9 (only for 26-bit OSes)
                                                  ; 1 word:   used by kernel - caller flags
                                                  ; 1 word:   used by kernel - SWI number
        SUB     R0, R0, #4 ; we actually want the previous instruction
        Debug   task2,"$string called by, from:",#taskhandle,R0
        Pull    "R0"
      ]
        MEND

        MACRO
$label  Plot    $pcode,$x,$y
$label
      [ "$x" <> "R1"
       [ "$y" = "R1"
        MOV     R2,R1
       ]
        MOV     R1,$x
      ]
      [ "$y" <> "R2" :LAND: "$y" <> "cx0" :LAND: :LNOT: ( "$x" <> "R1" :LAND: "$y" = "R1" )
        MOV     R2,$y
      ]
        MOV     R0,#$pcode
        SWI     XOS_Plot
        MEND

        MACRO
        Coords  $x,$y
        Coord   $x
        Coord   $y
        MEND

        GBLS    coordstemp

        MACRO
        Coord   $x
      [ "$x":LEFT:1 = "#"
coordstemp SETS "$x":RIGHT:(:LEN:"$x"-1)
        SWI     XOS_WriteI+($coordstemp:AND:&FF)
        SWI     XOS_WriteI+(($coordstemp:SHR:8):AND:&FF)
      |
        MOV     R0,$x
        SWI     XOS_WriteC
        MOV     R0,$x,LSR #8
        SWI     XOS_WriteC
      ]
        MEND

        MACRO
        Abs     $to,$from,$cc
        SUB$cc  $to,$from,#1
        MEND

        MACRO
$lab    Rel     $to,$from,$cc
$lab    ADD$cc  $to,$from,#1
        MEND

        MACRO
        SetRectPtrs
        ADRL    rectlinks,rlinks
        ADRL    rectcoords,rectarea
        MEND

        MACRO
        max     $a,$b
        CMP     $a,$b
        MOVLT   $a,$b
        MEND

        MACRO
        min     $a,$b
        CMP     $a,$b
        MOVGT   $a,$b
        MEND

        MACRO
        getxy   $r,$x,$y
        ADD     R14,rectcoords,$r,ASL #2
        LDMIA   R14,{$x.0,$y.0,$x.1,$y.1}
        MEND

        MACRO
        putxy   $r,$x,$y
        ADD     R14,rectcoords,$r,ASL #2
        STMIA   R14,{$x.0,$y.0,$x.1,$y.1}
        MEND

        MACRO
$label  ALIGNHASH  $m
      [ ((:INDEX:@):AND:($m-1))<>0
$label  #          $m-((:INDEX:@):AND:($m-1))
      |
$label  #          0
      ]
        MEND

        MACRO
        strw    $r1,$r2,$off
        STRB    $r1,[$r2,#$off]
        MOV     R14,$r1,LSR #8
        STRB    R14,[$r2,#$off+1]
        MEND

swf_alive       *       2_0001  ; bit set => check that task is alive
swf_checklimit  *       2_1000  ; if < checklimit, check R1 on entry

        MACRO
$lab    MySWI   $swiname
        ASSERT  MySWIBase+(.-jptable)/4 = $swiname
        GBLA    xflg_$swicnt
      [ (("$lab":CC:" "):LEFT:1)="x"
xflg_$swicnt    SETA    0         ; task doesn't have to be initialised
      |
xflg_$swicnt    SETA    swf_alive ; swi not allowed unless task is initialised
      ]
      [ ((" ":CC:"$lab"):RIGHT:1)<>"p"     ; check pointer if "p" present
xflg_$swicnt    SETA    xflg_$swicnt + swf_checklimit
      ]
swicnt  SETA    swicnt+1
        B       SWI$swiname
        MEND

        MACRO
$lab    BreakPt
$lab    MOV     PC,#0
        MEND

;
; Entry: $reg = handle of task to page in
; Exit:  [taskhandle] = $reg
;        $reg, [flagword] = flags for task
;        userblk = R1 on entry to Wimp_Poll of this task
;

        MACRO
$lab    Task    $reg,$cc,$dbg
$lab
      [ debugsw
        B$cc    %FT01
        B       %FT02
01
        Debuga  sw,"$dbg: "
02
      ]
        STR$cc  $reg,newtaskhandle      ; copied to [taskhandle] by subroutine
        BL$cc   pageintask              ; may do memory paging
        MEND

;-----------------------------------------------------

        MACRO
$lab    Dump    $file,$reg,$size
        Push    "R0-R5,LR"
        MOV     R0,#OSFile_Save
        ADR     R1,%FT01
      [ $reg=sp
        ADD     R4,$reg,#7*4            ; skip stacked registers
      |
        MOV     R4,$reg
      ]
        ADD     R5,R4,#$size
        SWI     XOS_File
        CLRV                            ; just in case
        Pull    "R0-R5,LR"
        B       %FT02
01
        DCB     "$file",0
        ALIGN
02
        MEND

        MACRO
$label  MyXError   $errsym, $c1, $c2
$label  ADR$c1$c2  R0,ErrorBlock_$errsym
        BL$c1      ErrorLookup
        MEND

;;-----------------------------------------------------------------------------
;; Workspace allocation
;;-----------------------------------------------------------------------------

cr      *       13
lf      *       10

FALSE   *       0
TRUE    *       1

 [ RO4
;;-----------------------------------------------------------------------------
;; 3D Patch definitions
;;-----------------------------------------------------------------------------

					^	0
TileInfo_SpritePtr			#	4
TileInfo_SpriteAreaPtr			#	4
TileInfo_TranslationTablePtr		#	4
TileInfo_ScaleFactors			#	4*4
TileInfo_Width				#	4
TileInfo_Height				#	4
TileInfo				*	@

 [ false
					; default to everything on
ThreeDFlags_Default			*	&FFFFFFFF :AND::NOT: (ThreeDFlags_NoFontBlending :OR: ThreeDFlags_FullIconClipping)
 |
                                        ; you have to be kidding - use sane defaults
ThreeDFlags_Default                     *       ThreeDFlags_RemoveIconBackgrounds :OR: \
                                                ThreeDFlags_NoFontBlending
ThreeDFlags_All                         *       :NOT: ThreeDFlags_NoFontBlending
 ]
ThreeDFlags_Use3DBorders		*	1<<0	; note, flag bit positions are exposed via Wimp_ReadSysInfo
ThreeDFlags_UseAlternateMenuTexture	*	1<<1
ThreeDFlags_Fully3DIconBar		*	1<<2
ThreeDFlags_RemoveIconBackgrounds	*	1<<3
ThreeDFlags_TexturedMenus		*	1<<4
ThreeDFlags_NoIconBgInTransWindows	*	1<<5
ThreeDFlags_NoFontBlending		*	1<<6
ThreeDFlags_FullIconClipping		*	1<<7    ; we're just ignoring this flag
ThreeDFlags_WindowOutlineOver           *       1<<8

arrowIconWidth_No3D     *       24
arrowIconWidth_3D       *       32
 ]

No_Reason                       *       0
Redraw_Window_Request           *       1
Open_Window_Request             *       2
Close_Window_Request            *       3
Pointer_Leaving_Window          *       4
Pointer_Entering_Window         *       5
Mouse_Click                     *       6
User_Dragbox                    *       7
Key_Pressed                     *       8
Menu_Select                     *       9
Scroll_Request                  *       10
max_oldreason                   *       11      ; old apps don't know better

Lose_Caret                      *       11
Gain_Caret                      *       12
PollWord_NonZero                *       13      ; Wimp 2.23 onwards

User_Message                    *       17
User_Message_Recorded           *       18
User_Message_Acknowledge        *       19
max_reason                      *       20

 [ :LNOT: UTF8  ; we've done away with this kludge!
Key_PressedOldData              *       &FF     ; This is never seen outside the wimp.
 ]


border_normal                   *       0
border_slabout                  *       1
border_slabin                   *       2
border_ridge                    *       3
border_channel                  *       4
border_action                   *       5
border_defaultaction            *       6
border_editable                 *       7
border_max                      *       8


masknewcodes  *  ((1:SHL:max_reason)-1):EOR:((1:SHL:max_oldreason)-1)


null_bit          *     1 :SHL: No_Reason
redraw_bit        *     1 :SHL: Redraw_Window_Request
open_bit          *     1 :SHL: Open_Window_Request             ; can't be suppressed
close_bit         *     1 :SHL: Close_Window_Request            ; can't be suppressed
ptrleaving_bit    *     1 :SHL: Pointer_Leaving_Window
ptrentering_bit   *     1 :SHL: Pointer_Entering_Window
buttonchange_bit  *     1 :SHL: Mouse_Click
userdrag_bit      *     1 :SHL: User_Dragbox                    ; can't be suppressed
keypress_bit      *     1 :SHL: Key_Pressed
menuselect_bit    *     1 :SHL: Menu_Select                     ; can't be suppressed
scroll_bit        *     1 :SHL: Scroll_Request                  ; can't be suppressed
losecaret_bit     *     1 :SHL: Lose_Caret
gaincaret_bit     *     1 :SHL: Gain_Caret
pollword_bit      *     1 :SHL: PollWord_NonZero
message_bit       *     1 :SHL: User_Message
messagerec_bit    *     1 :SHL: User_Message_Recorded
messagebounce_bit *     1 :SHL: User_Message_Acknowledge

button_left     *       4
button_middle   *       2
button_right    *       1

mf_oldcoords    *       2_000000000001

mf_waitrepeat   *       2_000000001000
mf_waitclick    *       2_000000010000
mf_waitdrag     *       2_000000100000
mf_waitrelease  *       2_000001000000
mf_wait2clicks  *       2_000010000000
mf_waitremove   *       2_000100000000                  ; unhighlight if gone
mf_pending      *       2_000111111000
mf_pendingexceptdrag *  mf_pending:AND:(:NOT:mf_waitdrag)
mfb_setflags    *       3                       ; bit no. of pending bits


default_doubleclick_movelimit   *       32              ; chicago dist. (OS coords)
default_drag_movelimit          *       32
default_doubleclick_timelimit   *       10              ; centiseconds/10
default_drag_timelimit          *       default_doubleclick_timelimit / 2
default_automenudelay           *       10
default_menudragdelay           *       10
default_iconbarspeed            *       4   ; 200 OS units / sec
default_iconbaraccel            *       3   ; 100 OS units / sec^2
default_autofrontdelay          *       5
default_autoscrolldelay         *       5

drag_posn       *       1               ; system dragging routines
drag_size       *       2               ; all terminate when buttons released
drag_hscroll    *       3               ; ditto
drag_vscroll    *       4               ; ditto
drag_user       *       5               ; drag user box (fixed size)
drag_user2      *       6               ; drag user box (variable size)
drag_user3      *       7               ; drag point (nothing displayed)
drag_subr_posn  *       8               ; user subr, fixed size box
drag_subr_size  *       9               ; user subr, variable size box
drag_subr_posn2 *       10              ; doesn't stop when buttons released
drag_subr_size2 *       11              ; doesn't stop when buttons released
drag_scrollboth *       12              ; drag both scroll bars

 [ Autoscr
dragf_anchor    *       2_00000001      ; anchor rubber boxes to work area
dragf_clip      *       2_00000010      ; clip dragbox by window visible rectangles
 ]

getrect_firstrect       * 2_000001
getrect_updating        * 2_000010
getrect_redrawing       * 2_000100
getrect_noicons         * 2_001000
 [ Twitter
getrect_twitter         * 2_010000
 ]
 [ Autoscr
getrect_keepdragbox     * 2_100000
 ]

                        ^ -1
windowicon_workarea     # -1            ; -1
windowicon_back         # -1            ; -2
windowicon_close        # -1            ; -3
windowicon_title        # -1            ; -4
windowicon_toggle       # -1            ; -5
windowicon_up           # -1            ; -6
windowicon_verticalbar  # -1            ; -7    includes well area
windowicon_down         # -1            ; -8
windowicon_resize       # -1            ; -9
windowicon_left         # -1            ; -10
windowicon_horizbar     # -1            ; -11   includes well area
windowicon_right        # -1            ; -12
windowicon_outerframe   # -1            ; -13
windowicon_iconise	# -1		; -14
 [ PushBothBars
windowicon_bothbars     # -1            ; -15   for when both scrollbars are pushed in
 ]

iconposn_back           * 1
iconposn_close          * 2
iconposn_title          * 3
iconposn_toggle         * 4
iconposn_vscroll        * 5
iconposn_resize         * 6
iconposn_hscroll        * 7
iconposn_iconise	* 8

maxrects        *       512

bignum          *       &0FFFFFFF
nullptr         *       -1
nullptr2        *       -2

sz_scrleft      *       0
sz_scrright     *       1280
sz_scrbot2      *       0
sz_scrbot       *       0               ; was 96 (to allow for icon bar)
sz_scrtop       *       1024


; contents of task word if task is dead

task_unused       *     1:SHL:31


;------------------------;
; Task data block format ;
;------------------------;

                  ^     0
task_flagword     #     4                       ; flag word on entry to Poll
task_slotptr      #     4                       ; if switched, block of pages
task_wimpver      #     4                       ; R0 on entry to Wimp_Initialise
task_pollword     #     4                       ; R3 on entry to Wimp_Poll(Idle)
task_fpblock      #     4                       ; FP register save block
              [ Swapping
task_file         #     4                       ; File handle for swap file.
task_filename     #     4                       ; File name for swap file.
task_extent       #     4                       ; File extent / Slot size.
task_swapped      *     1:SHL:31                ; bit 31 set if swapped out.
              ]
task_windows      #     4                       ; Number of open windows.
task_priority     #     4                       ; Priority for swap out.
	      [ debugtask4
task_eventtime    #     4
              ]

task_messages     #     4                       ; messages list / =-1 for all
task_messagessize #     4                       ; size of the list

priority_iconbar  *     1:SHL:0   ;1
priority_old      *     1:SHL:1   ;2
priority_pollword *     1:SHL:2   ;4
priority_idle     *     1:SHL:3   ;8
priority_windows  *     1:SHL:4   ;16
priority_null     *     1:SHL:5   ;32
priority_top      *     1:SHL:20

task_environment  #     4*3*MaxEnvNumber        ; environment pointers
task_registers    #     4*17                    ; USR register set
task_vfpcontext   #     4                       ; VFPSupport context ID
task_datasize     #     0

; extra bits for Wimp_Poll - not stored in task_flagword

flag_fpsavebit    *     24                      ; save/restore FP registers
flag_pollfastbit  *     23                      ; look at poll word before messages
flag_pollwordbit  *     22                      ; there is a poll word in R3

; top bits of flag word are version number of task
; then the 'poll idle' bit, and then bits 0..19 (the event mask)

flag_versionbit   *     21                      ; one above flag_pollidle
flag_pollidlebit  *     20                      ; not part of version number

             ASSERT     max_reason <= flag_versionbit

flag_fpsave       *     1 :SHL: flag_fpsavebit
flag_pollfast     *     1 :SHL: flag_pollfastbit
flag_pollword     *     1 :SHL: flag_pollwordbit
flag_version      *     1 :SHL: flag_versionbit
flag_pollidle     *     1 :SHL: flag_pollidlebit

flag_allowed      *     flag_pollword :OR: flag_pollfast :OR: flag_fpsave

; structures for storing the messsge list

                ^       0               ; Linked list of messages.
ml_next         #       4               ; Next message
ml_prev         #       4               ; Previous message
ml_message      #       4               ; Message number.
ml_task         #       4               ; Pointer to first task on list.
ml_size         #       0

        ASSERT  ml_next=0

                ^       0               ; Linked list of tasks for each message.
mlt_next        #       4               ; Next task.
mlt_prev        #       4               ; Previous task on list.
mlt_task        #       4               ; Task handle.
mlt_size        #       0

        ASSERT  mlt_next=0

;------------------------;
; FP register save block ;
;------------------------;

                ^       0
fp_status       #       4
fp_reg0         #       12              ; stored in extended precision
fp_reg1         #       12
fp_reg2         #       12
fp_reg3         #       12
fp_reg4         #       12
fp_reg5         #       12
fp_reg6         #       12
fp_reg7         #       12
fp_size         #       0

F0      FN      0       ; register name symbols for FP register saving
F1      FN      1
F2      FN      2
F3      FN      3
F4      FN      4
F5      FN      5
F6      FN      6
F7      FN      7

C_runtime_status   *    &70000  ; suitable value for C run-time environment

;------------------------------;
; Rectangle list head pointers ;
;------------------------------;

                ^       0
freerects       #       4               ; rectangle data
invalidrects    #       4
              [ ChildWindows
oldinvalidrects #       4
              ]
oldwindowrects  #       4
windowrects     #       4
borderrects     #       4
torects         #       4
firstfreerect   #       0


                ^       0
icd_list        #       4               ; iconbar data
icd_middle      #       4
icd_extent      #       4
icd_width       #       4
icd_widthoffset #       4
icd_size        #       0

iconbargap      *       16
iconbarsepgap   *       64

                ^       0
icb_link        #       4               ; format of iconbar blocks in heap
icb_iconhandle  #       4
icb_taskhandle  #       4
icb_priority    #       4
icb_defwidth    #       4               ; default width
icb_size        #       0

sysflags_dragbits   *   2_00001111      ; enable instant dragging
sysflags_nobeep     *   2_00010000      ; disable beep on error
sysflags_offscreen  *   2_00100000      ; allow windows to go off-screen
sysflags_nobounds   *   2_01000000      ; allow windows to go off-screen in all directions.
sysflags_automenu   *   2_10000000      ; auto open submenus

; Two-way linked list definitions

        ; List header
                ^       0
lh_forwards     #       4
lh_indicator    #       4
lh_backwards    #       4
lh_size         #       0

        ; List link
                ^       0
ll_forwards     #       4
ll_backwards    #       4
ll_size         #       0


                ^       0,R12

wsorigin        #       0

tempworkspace   #       8*4             ; can be used easily

vduoutput       #       0
log2px          #       4
log2py          #       4
log2bpp         #       4
scrx0           #       4               ; converted to OS units
scry0           #       4
scrx1           #       4
scry1           #       4
textxsize       #       4               ; converted to OS units
textysize       #       4
modeflags       #       4
ncolour         #       4

rotatecounter   #       4               ; modified rotdotdash routine

romspr_suffix   #       4               ; <x><y> or "23"

dx              #       4
dy              #       4
dx_1            #       4
dy_1            #       4
xypixelsize     #       4

xborder         #       1
yborder         #       1
xborder1        #       1
yborder1        #       1
scroll_minlength    #   1
scroll_sidemargin   #   1
scroll_endmargin    #   1
scroll_mxborder     #   1
scroll_myborder     #   1
scroll_minxbar      #   1
scroll_minybar      #   1
fontforeground      #   1
fontbackground      #   1
continueflag    #       1               ; for changing extent while dragging
;fpemulator_flag #      1
iconbar_needs_rs    #   1
reentrancyflag  #       1
old_escape      #       1

       ALIGNHASH 4

 [ ThreeDPatch
truemenuborderfacecolour        # 4
truemenuborderoppcolour         # 4	; colours to use for menu borders
truewindowborderfacecolour      # 4
truewindowborderoppcolour	# 4	; colours to use for window borders
truewindowoutlinecolour         # 4     ; colour to use for window outline
 ]
 [ TrueIcon1
truefgcolour    #       4               ; for 24-bit colour icons
truebgcolour    #       4
 ]
 [ TrueIcon2
truebgcolour2   #       4               ; background colour for selected R5/R6 icons
truewellcolour  #       4               ; well colour for R6 icons
truefacecolour  #       4               ; 3D plinth colour facing light source
trueoppcolour   #       4               ; 3D plinth colour opposite light source
 [ TrueSelectionColours
trueselfgcolour	#	4		; selected foreground colour
trueselbgcolour	#	4		; selected background colour
 |
                #       4               ; reserved, in case 7 icon colours are specified!
 ]
 ]
redrawhandle    #       4
iconhandle      #       4
getrectflags    #       4
mouseflags      #       4
dragtype        #       4
draghandle      #       4
dragtask        #       4
dragoldx        #       4
dragoldy        #       4
dragx0          #       4
dragy0          #       4
dragx1          #       4
dragy1          #       4
dragoffx0       #       4
dragoffy0       #       4
dragoffx1       #       4
dragoffy1       #       4
dragwsptr       #       4               ; for user-supplied subroutines
dragsubr_on     #       4               ; for user-supplied subroutines
dragsubr_off    #       4               ; for user-supplied subroutines
dragsubr_move   #       4               ; for user-supplied subroutines
 [ Autoscr
dragflags       #       4               ; as passed to Wimp_DragBox in R3
 ]

drg_on          *       dragsubr_on   - dragwsptr
drg_off         *       dragsubr_off  - dragwsptr
drg_move        *       dragsubr_move - dragwsptr

wimpswiintercept        #       4       ; Wimp_Extend SWI intercepter
plotsprCB               #       4       ; backdrop tiling CB

        ALIGNHASH  16
; these have moved!
RAM_SWIEntry            #       12      ; 3 instructions for getting R12 back
OScopy_ChangeDynamic    #       4       ; this must follow immediately
longjumpSP              #       4       ; for cutting out the middle-man
ROMstart                #       4       ; ROM base address
ROMend                  #       4       ; ROM end address (inclusive)

        ALIGNHASH  16			; missing HASH! JRC 25 Jul 1997
clipx0          #       4
clipy0          #       4
clipx1          #       4
clipy1          #       4
spaceinicon     #       4               ; for displaying scrollable icons
text_width      #       4
text_y0         #       4
text_y1         #       4

temp_text_height #      4               ; 320nk textwidth now gets height
                                        ; as well as width (Wimp_04)
        [ slabinout
two_sprite_save #       4               ; save flags for two sprite icons
        ]
spritecachevalid #      0               ; uses same adr as below
auto_menu_flag  #       1               ; flag to keep track of auto width
autorepeating   #       1
        [ TrueIcon3
tinted_enable   #       1               ; 1:SHL:2 => tinting enabled for current set of toolsprites
tinted_window   #       1               ; 1:SHL:2 => tinting enabled for this window (ie nonstandard colours)
tinted_tool     #       1               ; 1:SHL:2 => tinting enabled for this tool
        |
work_back_colour #      1               ; background colour of current window
        ]
errorbox_open   #       1
        ALIGNHASH 4
        [ windowsprite
	 [ ThreeDPatch
ThreeDFlags	#	4
MenuIsColourMenu #	4
arrowIconWidth  #       1
        ALIGNHASH 4
	 |
tiling_sprite   #       4
tile_pixtable   #       4
tile_temptab    #       4
	 ]
        ]

oldclipx0       #       16              ; really x0,y0,x1,y1
hascaret        #       4               ; 0 ==> this icon has the caret
careticonaddr   #       4               ; address of icon with caret
caretx          #       4               ; caret posn relative to text itself
caretscrollx    #       4               ; text offset due to caret
areaCBptr       #       4
thisCBptr       #       4
spritename      #       4               ; ptr to sprite name (or header)
spritenamebuf   #       12              ; buffer for sprite name itself
validationstring  #     4
lengthflags     #       4
linespacing     #       4               ; for formattable text icons

xoffset         #       4               ; used by block-copy code
yoffset         #       4
oldlink         #       4
errorhandle     #       4               ; handle of error window
backwindow      #       4               ; handle of background window (if any)
backwindowhandle  #     4               ; handle of 'new' bg window
commandhandle   #       4               ; handle of 'command' window
commandflag     #       4               ; is a command window pending?

              [ :LNOT: NewErrorSystem
highlighted_colour      #       4       ; colour of OK box initially
unhighlighted_colour    #       4       ; colour of Cancel box initially
              ]

iconbarhandle   #       4
iconbarheight   #       4
iconbarleft     #       icd_size
iconbarright    #       icd_size

dotdashrate     *       5
initdotdash1    *       &FC
tempdotdash     *       ((initdotdash1:SHL:1):AND:&FF):OR:(initdotdash1:SHR:7)
initdotdash2    *       initdotdash1:EOR:tempdotdash
dragflag        #       1
dragaction      #       1
addtoolstolist  #       1               ; if non-zero then rotate and reset
dotdash1        #       1
dotdash2        #       1
dotdash         #       1
              [ :LNOT: TrueIcon3
titlecolour     #       1
              ]
repeatdelay     #       1               ; for auto-repeating icons
repeatrate      #       1
repeatlimit     #       1
gcolaction      #       1               ; used by Wimp_SetColour
sysflags        #       1               ; actions on moving windows (drag?)
memoryOK        #       1               ; flag for ChangeDynamicArea
modechanged     #       1               ; flag set on mode change
sprite_needsfactors  #  1               ; otherwise 1:1 scaling for this mode
sprite_needsfactors2 #  1               ; initial needsfactors guess
tsprite_needsfactors #  1               ; otherwise 1:1 scaling for this mode
tsprite_needsregen   #  1               ; need to recalculate the tool sprite pixtrans
selecttable_crit     #  1               ; ignore invalidate cache service calls if we're the cause
              [ ChildWindows
openspending    #       1               ; whether we're in the middle of a set of opens
              ]

        ALIGNHASH   4

oldfxstatus     #       13              ; *FX 4
                                        ; *FX 219
                                        ; *FX 221..228
                                        ; *FX 9..10
                                        ; *FX 229

              [ mousecache
recacheposn     #       1               ; non-zero then re-cache mouse information (x,y,b and time changed!)
              ]


        ALIGNHASH   4

                #       14*4            ; FD stack for Wimp_ReportError
errorstack      #       0

mousexpos       #       4
mouseypos       #       4
mousebuttons    #       4
              [ mousecache
mousetime       #       4
              ]
mouseblk        #       12
oldbuttons      #       4
mousexrel       #       4
mouseyrel       #       4
leftborder      #       4

pending_time    #       8
pending_x       #       4
pending_y       #       4
pending_buttons #       4
pending_window  #       4
pending_icon    #       4
timeblk         #       4               ; NB overlaid with next word!
temp            #       4

writeabledir    #       4               ; Direction of writeable icons.
reversedmenu    #       4               ; Flag for reversed menus.
externalcreate  #       4               ; True if menu is a result of a SWI call.
                [       outlinefont
systemfont      #       4               ; WIMP font handle, if claimed
symbolfont      #       4               ; WIMP symbol font handle, if claimed
currentfont     #       4               ; the font in force on entry to the WIMP, if needed
currentbg       #       4               ; its background colour
currentfg       #       4               ; its foreground colour
currentoffset   #       4               ; its colour offset
                ]

                [ SpritePriority
preferredpool   #       4               ; 1 => ROM, 0 => RAM
baseoflosprites #       4               ; base of low priority common sprite pool
baseofhisprites #       4               ; base of high priority common sprite pool
                ]
baseofsprites   #       4               ; base of common sprite pool (in RAM)
baseofromsprites  #     4               ; base of ROM sprite pool (in Resources:)

oldCAOpointer   #       4               ; used in OS_ChangeDynamicArea
handlerword     #       4               ; flag word ==> has handler changed?
parentquithandler   #   4               ; quit handler when application starts
freepool        #       4               ; stack of free pages (words)
freepoolbase    #       4               ; base address of free memory
freepoolpages   #       4               ; no of pages in free pool
pendingtask     #       4               ; task block pending deletion
                                        ; (in Wimp_Poll)
orig_memorylimit           #  4
orig_applicationspacesize  #  4
oldapplimit     #       4               ; used in ChangeDynamicArea code
pagesize        #       4
npages          #       4
slotsize        #       4               ; default slot size
currentmode     #       4

taskhandle      #       4               ; task currently paged-in
newtaskhandle   #       4               ; temporary location for pageintask
polltaskhandle  #       4               ; task handle on entry to Wimp_Poll
menutaskhandle  #       4               ; task handle of menu owner
nulltaskhandle  #       4               ; for cycling null events
singletaskhandle   #    4               ; single = taskhandle if 1-tasking
createwindowtaskhandle # 4              ; if <= 0, this is used to fill in w_taskhandle (else current taskhandle is used)
inithandle      #       4               ; "owner" slot if [freepool] = -1
taskcount       #       4               ; number of active tasks
tasknumber      #       4               ; global task number (monotonic)
taskSP          #       4               ; pointer into parent task stack
wimpquithandler #       12              ; how to get out of the Wimp!!
oldcallback     #       12              ; previous callback handler

flagword        #       4               ; flag word for current task
;latestwimp     #       4

ptrwindow       #       4               ; where the mouse was last seen
ptrtask         #       4               ; original owner of ptrwindow
borderlinked    #       4
isborderok      #       4
;ishscroll      #       4
;isvscroll      #       4
;heapfreeptr    #       4

headpointer     #       4               ; for message passing

sender          #       4
myref           #       4

maxmenus        *       8
whichmenu       #       4
menus_temporary #       4               ; if set, Wimp_Poll kills the menus
menuhandle      #       4
menuiconwidth   #       4
menuiconheight  #       4
menuiconspacing #       4
menuSP          #       4
menuhandles     #       4*maxmenus      ; handle of relevant window
menudata        #       4*maxmenus      ; ptrs to menu definitions (-1 if dial)
menuselections  #       4*maxmenus      ; selection index in each menu

crf_vdu5caret   *       &01000000
crf_invisible   *       &02000000
crf_usercolour  *       &04000000
crf_realcolour  *       &08000000

crb_colourshift *       16              ; use bits 16-23 for caret colour

caretdata       #       28              ; window,icon,x,y coords,height,index
                                        ; [caretdata+24]=caretscrollx (the definitive copy)
oldcaretwindow  #       4
menucaretwindow #       4
menucareticon   #       4
oldcaretdata    #       24              ; preserves caret data over menus
hotkeyptr       #       4               ; pointer into window stack
menuscrolly     #       4

 [ UseAMBControl
appspacesize    #       4               ; size of current application slot
 ]

 [ CnP
ghostcaretdata  #       28              ; window,icon,x,y coords,height,index
                                        ; [ghostcaretdata+24]=ghostcaretscrollx
selectionwindow #       4               ; external handle of the window that has the unshaded selection (or -1 if none)
font_cs_list    #       4               ; for pointing to font control sequence list during pushfontstring
 ]

 [ UTF8
keystring_buflen #      1               ; number of bytes in keystring_buffer (see below)
keyprocess_buflen #     1               ; number of bytes in keyprocess_buffer (see below)
keyin_buffer    #       6               ; filled from kernel buffer, for the sake of identifying incoming UTF-8 sequences
keyin_buflen    #       1               ; number of bytes in keyin_buffer
keyout_buffer   #       5               ; for outputting multi-byte UTF-8 characters as hotkey sequences
keyout_buflen   #       1               ; number of bytes in keyout_buffer

alphabet        #       1               ; for storing the current alphabet
        ALIGNHASH 4
systemfont_wimpsymbol_map #     4       ; for use in pushfontstring
 ]

 [ Autoscr
; main autoscrolling variables
autoscr_state           #       4       ; flags word
autoscr_handle          #       4       ; window being scrolled
autoscr_pz_x0           #       4       ; pause zone sizes
autoscr_pz_y0           #       4
autoscr_pz_x1           #       4
autoscr_pz_y1           #       4
autoscr_user_pause      #       4       ; minimum pause time (cs), or -1 to use default
autoscr_user_rout       #       4       ; user routine, or < &8000 to use Wimp-supplied
autoscr_user_wsptr      #       4       ; user routine workspace (if above >= &8000)

autoscr_pause           #       4       ; minimum pause time (cs) (explicit if default)
autoscr_rout            #       4       ; routine (user or Wimp)
autoscr_wsptr           #       4       ; workspace (user or Wimp)
autoscr_next_t          #       4       ; time when to start autoscrolling, or when next to update
autoscr_last_t          #       4       ; time of last update
autoscr_last_x          #       4       ; position of mouse at last examination
autoscr_last_y          #       4
autoscr_old_ptr_colours #     3*4       ; used when restoring pointer after autoscroll pointer use
autoscr_old_ptr_number  #       1
autoscr_default_pause   #       1       ; derived from CMOS (ds)
autoscr_scrolling       #       1       ; used to determine next setting of flag bit 8
autoscr_pausing         #       1       ; used to determine whether timer is dirty, also a "don't re-enter" flag

autoscr_speed_factor    *       5       ; -log2 of number of pointer offsets to scroll per centisecond
autoscr_update_delay    *       8       ; hardwired minimum interval between updates (cs)
                                        ; is necessary to ensure null events have a chance to be seen
        ALIGNHASH   4
autoscr_END             #       0
 ]

 [ ClickSubmenus
clicksubmenuenable      #       1       ; nonzero => functionality enabled
submenuopenedbyclick    #       1       ; nonzero => submenu should be held open
 ]

 [ IconiseButton
iconisebutton           #       1       ; nonzero => add iconise button
 ]

 [ StickyEdges
stickyedges             #       1       ; nonzero => interpret "force on screen" as sticky
 ]

 [ BounceClose
buttontype              #       1       ; nonzero => buttons are release-type
 ]

 [ SpritesA
alphaspriteflag         #       1       ; nonzero => *iconsprites looks for alpha sprites
 ]
checkedcolourmapping    #       1       ; nonzero => we've checked for colour mapping support in SpriteExtend (and generated the tables)

 [ PoppingIconBar
popiconbar              #       1       ; nonzero => enable autofronting
        ALIGNHASH   4
popiconbar_pause        #       4       ; configured pause time (cs)
 ]

        ALIGNHASH   4

inversecolourmap        #       4       ; pointer to colour mapping descriptors and LUTs used for true colour sprite shading & inversion

 [ MultiClose
nextwindowtoiconise     #       4       ; pointer through window stack so far
 ]

 [ TrueIcon3
truetitlefg     #       4               ; title foreground and window frame colour
truetitlebg     #       4               ; title background colour
trueworkfg      #       4               ; work area foreground colour
trueworkbg      #       4               ; work area background colour
truescoutcolour #       4               ; scroll bar outer colour
truescincolour  #       4               ; scroll bar inner colour
truetitlebg2    #       4               ; title background colour when highlighted for input focus
truetitlecolour #       4               ; independent of input focus status
   [ TrueSelectionColours
		#	4		; spare word because of selected icon bg
   ]
 ]

 [ SwitchingToSprite
switchtospr_current     #       4       ; -> sprite (or 0 for screen) that VDU output is switched to
switchtospr_correctfor  #       4       ; -> sprite (or 0 for screen) that Wimp is set up for
 ]

iconbar_scroll_speed    #       4
iconbar_scroll_accel    #       4

systemfontwidth #       4
systemfonty0    #       4
systemfonty1    #       4

ellipsiswidth   #       4
ellipsis        #       4

tempiconblk     #       48              ; for creating icons for menus
                                        ; also used for int_open_window
                                        ; and system drag boxes
tf_hdr          *       16
tf_indexsize    *       24
tf_log2fontsize *       4               ; actually font size = 3*2^4
tf_fontsize     *       3*(1:SHL:tf_log2fontsize)


templatehdr     #       tf_hdr
fontbindings    #       256

filehandle      #       4
fileaddress     #       4
filelength      #       4

templateindex   #       4
userfreeptr     #       4
userfreeend     #       4
userfontcounts  #       4

PollTaskPtr     #       4               ; -> last entry in PollTaskList

              [ NKmessages1
lastpointer     #       4               ; end of message queue (NK's optimise)
              ]

lastmode_x1     #       4               ; (xwindlimit+1) * px for previous mode
lastmode_y1     #       4               ; (ywindlimit+1) * py for previous mode
forceflags      #       4               ; for putting windows back

ditheringflag   #       4               ; flag to control dithering

sprite_lastmode #       4
sprite_log2bpp  #       4               ; for mode-independent sprite plotting
sprite_log2px   #       4
sprite_log2py   #       4
sprite_modeflags #      4
sprite_ncolour   #      4
tsprite_lastmode #      4
tsprite_log2bpp  #      4               ; for mode-independent toolsprite plotting
tsprite_log2px   #      4
tsprite_log2py   #      4
tsprite_modeflags #     4
tsprite_ncolour   #     4
           ALIGNHASH    16
sprite_factors  #       16
tsprite_factors #       16

physpaltable    #       4*16            ; secondary palette table (disconnected from Wimp jobbie)
temppaltable    #       4*16            ; temporary store for a palette
usephyspaltable #       4               ; use the physical palette table

transtable1     #       2               ; 1bpp mapping from wimp -> sprite pixels
transtable2     #       4               ; 2bpp     ---------- "" ------------
transtable4     #       16              ; 4bpp     ---------- "" ------------
        ALIGNHASH       16

selecttable_args #      4*8             ; parameters used for the last sprite select table call
selecttable_lastmode #  4
selecttable_lastpalptr # 4

pixtable_at     #       4
pixtable_size   #       4               ; size and position of pixtrans table currently setup

list_at         #       4               ; head of sprite cache list
list_size       #       4               ; size of buffer claimed
list_end        #       4               ; end of list used for chop

tpixtable_at    #       4
tpixtable_size  #       4               ; size and position of tool pixtrans table currently setup

        [ windowsprite :LAND: :LNOT: ThreeDPatch
tile_sc_block   #       16
tile_log2px     #       4
tile_log2py     #       4
tile_width      #       4
tile_height     #       4
        ]

; bits for internationalised Wimp

message_block   #       4*4             ; 16 bytes for message trans
messages        #       4               ; =0 then no messages / -> messages block

; bits for portable speed control

; see 321nk later
IdlePerSec      #       4               ; amount of time spent in idle mode
 [ Stork
WimpPortableFlags #     4               ;
PowerSave * &01000000
 |
WimpPortableFlag #      4               ; non-zero then portable module present
 ]

last_fg_gcol    #       4
last_bg_gcol    #       4

; filters registered using Wimp_RegisterFilter

prefilterWP     #       4               ; pre-poll filter
prefilter       #       4
postfilterWP    #       4               ; post-poll filter
postfilter      #       4
copyfilterWP    #       4               ; block copy filter
copyfilter      #       4
rectanglefilterWP #     4               ; get-rectangle filter
rectanglefilter   #     4
postrectfilterWP #     4               ; post-get-rectangle filter
postrectfilter   #     4
posticonfilterWP #     4               ; post-icon-draw filter
posticonfilter   #     4

; bits for icon borders

border_type     #       4               ; border slab type => 0 => normal
border_highlight #      4               ; highlight colour to be applied

border_iconselected #   4               ; icon that is currently selected
border_windowselected # 4               ; window selected

tool_area       #       4               ; -> sprite area owned by tool managing routines (may be in resources:)
tool_areaCB     #       SpriteAreaCBsize

tool_list       #       4               ; -> list of sprites in area / =0 if not valid yet
tool_list_backup #      4               ; backup copy of tool_list

; tool plotting information

tool_plotparams #       0
tool_plotop     #       4               ; sprite op to plot sprites with
tool_maskop     #       4
tool_scaling    #       4               ; -> scaling block (may not be used)
tool_transtable #       4               ; -> translation table (may not be used)
 [ ToolTables
ttt_masterset   #       16*4            ; -> user supplied tool translation tables (one per wimp colour)
ttt_activeset   #       16*4            ; -> reprocessed for this mode
ttt_activeset_at #      4
ttt_activeset_size #    4
ttt_lastlookup  #       4               ; most recent colour match
ttt_table2      *       2*4
 ]
tool_scrollclip #       4*4             ; clip region used for plotting scroll bars
tool_scalingblk #       4*4             ; scaling block used for painting glyphs

; tool size information

title_height    #       4               ; title height = close, toggle, back
title_height1   #       4
vscroll_width   #       4               ; vscroll height = left, right, resize
vscroll_width1  #       4
hscroll_height  #       4               ; hscroll width = toggle, up, down, resize
hscroll_height1 #       4

back_width      #       4               ; width of the back box
close_width     #       4               ; width of the close box
 [ IconiseButton
iconise_width	#	4		; width of the iconise button
 ]

left_width      #       4               ; width of the left arrow
right_width     #       4               ; width of the right arrow

up_height       #       4               ; up arrow height
down_height     #       4               ; down arrow height

; bits for iny-outy type scroll blobs - yucky!

vscroll_top             # 4             ; height in OS units
vscroll_topfill         # 4
vscroll_blobtop         # 4
vscroll_blobfill        # 4
vscroll_blobbottom      # 4
vscroll_bottomfill      # 4
vscroll_bottom          # 4

hscroll_left            # 4             ; width in OS units
hscroll_leftfill        # 4
hscroll_blobleft        # 4
hscroll_blob            # 4
hscroll_blobright       # 4
hscroll_rightfill       # 4
hscroll_right           # 4

title_left              # 4             ; width in OS units
title_right             # 4

title_sectionwidth      # 4             ; width of sections in OS units
title_topheight         # 4             ; height of units in OS units
title_bottomheight      # 4

                      [ hvblip
vscroll_blipheight      # 4             ; width an height of scroll bar blobs
hscroll_blipwidth       # 4
                      ]

; some other bits of misc data for configuration and caret saving

drag_movelimit             #       1
doubleclick_movelimit      #       1
              ALIGNHASH    4
drag_timelimit             #       4
doubleclick_timelimit      #       4
automenu_timelimit         #       4
menudragdelay              #       4
automenu_timeouttime       #       4
automenu_inactivetimeout   #       4

savedcaretdata             #      24    ; holds caretdata from start of key handling process
savedvalidation            #       4
savedcharcode              #       4

; bits to do with pointer tracking

old_icon        #       4
old_window      #       4
special_pointer #       4
pointer_sprite  #       12

 [ KeyboardMenus
lastxpos        #       4               ; stop mouse highlighting menus unless it moves
lastypos        #       4
 ]

 [ AutoHourglass
hourglass_delay	*	100		; delay before showing hourglass for "dodgy apps", in 1/100 secs
hourglass_status #      4               ; autohourglass status (0 => no hourglass or WrchV routine, 1 => just routine,
 ]                                      ;                       2 => routine is on vector & hourglass is pending or active)

        ALIGNHASH       64

 [ UTF8
keystring_buffer #      256             ; for queuing Key$n bytes
keyprocess_buffer #     256             ; for queuing multiple key-originating Wimp_ProcessKey calls
                                        ; byte format is the same as bytes read from kernel keyboard buffer
 ]

        ALIGNHASH       64

        [ NewErrorSystem
errorbuttonsize * 256
errorbuttons    #       errorbuttonsize ; this is used to copy button labels
buttontextsize  * 24
oktext          #       0               ; SMC: now lookup text for buttons (OK same as Continue)
conttext        #       buttontextsize
quittext        #       buttontextsize
progerrsaveblk  #       4 * 4           ; caller R0-R3, stored while the "may have gone wrong" window is displayed
errbut_y0_def   #       4               ; bottom of default action button, read from "Continue"
errbut_y1_def   #       4               ; top of default action button, read from "Continue"
errbut_fl_def   #       4               ; icon flags of default action button, read from "Continue"
errbut_va_def   #       4               ; validation string of default action button, read from "Continue"
errbut_w_def    #       4               ; width of default action button, read from "Continue"
errbut_y0       #       4               ; bottom of action button, read from "Cancel"
errbut_y1       #       4               ; top of action button, read from "Cancel"
errbut_fl       #       4               ; icon flags of action button, read from "Cancel"
errbut_va       #       4               ; validation string of action button, read from "Cancel"
errbut_w        #       4               ; width of action button, read from "Cancel"
errapp_x0       #       4               ; LHS of application sprite
errtype_x0      #       4               ; LHS of error type sprite
errmess_x0      #       4               ; LHS of error message icon
        [ StretchErrorText
linecount       #       4               ; flags counting and returns number of lines required for error message
errmess_maxlines    *   7               ; maximum number of lines to allow for error message
errmess_increment   *   48              ; step size (in OS units) to increase error box size by when enlarging
        ]
maxno_error_buttons *   8               ; maximum number of action buttons (needs this many Additional buttons in template)
        ]

paltable        #       4 * 16          ; one word per colour
othercolours    #       4 * 4           ; border & mouse colours

        [ NewErrorSystem
watchdogarea    #       4
watchdogerror   #       4
watchdogerrtxt  #       244
watchdogtaskno  #       4
watchdogtask    #       4
watchdogcodew   #       4
        ]

iconbar_scroll_start_time #	4	; time icon bar started scrolling
iconbar_scroll_start_scx  #	4	; and where it started from
MaxSlowIdleEvents       #       4       ; 321nk added for PowerUtils incorporation
MaxFastIdleEvents       #       4
Threshold       *       &600

	[ PoppingIconBar
iconbar_pop_time	#	4
iconbar_pop_state	#	4
pop_Back	* 0
pop_Delaying	* 1
pop_Front	* 2
pop_HeldByMenu	* 3
        [ :LNOT: OldStyleIconBar
pop_Front2      * 4 ; held by virtue of Shift-F12
        ]
	]

        [ ChildWindows
newparent       #       4               ; parameter for Wimp_OpenWindow
newalignflags   #       4               ; parameter for Wimp_OpenWindow
oldactivewinds  #       lh_size         ; used for deferred opening
openingwinds    #       lh_size         ; ditto
heldoverwinds   #       4               ; singly-linked list for windows that are optimized out
        ]

activewinds     #       lh_size         ; Forwards is top to bottom of stack
allwinds        #       lh_size

        ; Braindead Panic Redraw handling
BPR_indication  #       4
BPR_gotfullarea *       0               ; Rect area has become full from a no problem situation
BPR_panicnow    *       1               ; Rect area become full again - enter brain dead mode
BPR_nullrectops *       1               ; This or below means rectangle ops do nothing
BPR_notatall    *       2               ; No problems with full rectangle areas
BPR_1sttry      *       3               ; After a rect area full try redrawing whole screen
BPR_continuelevel *     4               ; HS this means continuing BPR
; Other values indicate BPR_panicnow and are the next window to redraw braindeadwise

ptr_IRQsema     #       4               ; Pointer to kernel's IRQsema
ptr_DomainId    #       4               ; Pointer to kernel's DomainId
        [ DynamicAreaWCF
wcfda           #       4
        ]

rlinks          #       4*maxrects
                #       -4*firstfreerect        ; this data not used
rectarea        #       16*maxrects
rectend         #       0

registerbuffer  #       4*17

           ALIGNHASH    64

maxtasks        *       128

taskstack       #       maxtasks * 4    ; each task can only be in it once!
taskpointers    #       maxtasks * 4    ; pointers to task data blocks
maxtaskhandle   *       :INDEX:@

PollTasks       #       maxtasks * 4    ; Packed list of tasks with pollwords

errorbuffer     #       256             ; used by error handler

errordynamic    *       errorbuffer+4   ; put these after stashed PC
errordynamicsize *      ?errorbuffer-4
stackspace      #       0               ; temporary stack for debugging!

copyerror       #       240             ; copy of error block
greys_mode       #      1               ; last grey mode.
last_greys      #       1               ; previous greys mode
freepoolinuse	#	1
misc		#	1
save_context    #       4
fontnamebuffer  #       60              ; used to store last ROM font.

        [ PoppingIconBar :LAND: OldStyleIconBar
iconbar_pop_previous	#	4	; where to go back to
        ]

        [ DebugMemory
memory_claims   #       8               ; build a list of mem claims for debugging
        ]

 ALIGNHASH 4

inverselookup   #       1024            ; what colour numbers to use when EOR'ing an area

       [ LongCommandLines
path_buffer     #       1024            ; for building Sprites<x><y> pathnames
taskbuffer      #       1024            ; command which starts a task
       |
path_buffer     #       256             ; for building Sprites<x><y> pathnames
taskbuffer      #       256             ; command which starts a task
       ]

errortitle      #       1024            ; for building up 'Error from ...'
errortitend     #       0

 ALIGNHASH 4

	[ ThreeDPatch
tile_sprites	 #	TileInfo * 16
menu_tile_sprite #	TileInfo
temp_tile_sprite #	TileInfo
	]

              [ Swapping
swapping        #       4               ; Is there a swap path ? if so, the length of the path.
swapsize        #       4               ; Must be together (returned from ReadSysInfo )
swapused        #       4
                ASSERT  swapsize=swapping+4
                ASSERT  swapused=swapsize+4
swap_filename   #       4               ; File name for next swap file.
swap_path       #       256             ; Path name for swap files.
              ]

              [ NCErrorBox
ptrshlflag	#	4		; Pointer shape and linkage flag (saved here during
					; ReportError) JRC 25 Jul 1997
ptrsuspenddata  #       12              ; To store x,y,b last generated by IconHigh
ptrsuspendflag  #       4               ; 0 => normal
                                        ; 1 => waiting for mouse move generated by IconHigh
                                        ; 2 => waiting for next mouse move *not* generated by IconHigh
ptrpreserveflag #       4               ; 0 => position pointer over default error button on box start
                                        ; 1 => don't move pointer on box start
              ]

              [ ErrorServiceCall
errorbuttonoldhandlers # 3*3*4          ; old environment handlers to restore afterwards
              ]

selecttable_lastpal # 1024              ; Last sprite palette used with selecttable

maxwork         *       :INDEX:@

                ! 0,    "Free pool              = R12+&" :CC: :STR: :INDEX: freepool
                ! 0,    "#pixtable_at           = R12+&" :CC: :STR: :INDEX: pixtable_at
                ! 0,    "#pixtable_size         = R12+&" :CC: :STR: :INDEX: pixtable_size
                ! 0,    "#tpixtable_at          = R12+&" :CC: :STR: :INDEX: tpixtable_at
                ! 0,    "#tpixtable_size        = R12+&" :CC: :STR: :INDEX: tpixtable_size
                ! 0,    "#list_at               = R12+&" :CC: :STR: :INDEX: list_at
                ! 0,    "#list_size             = R12+&" :CC: :STR: :INDEX: list_size
                ! 0,    "#list_end              = R12+&" :CC: :STR: :INDEX: list_end
                ! 0,    "#allwinds              = R12+&" :CC: :STR: :INDEX: allwinds
                ! 0,    "Task Pointers          = R12+&" :CC: :STR: :INDEX: taskpointers
                ! 0,    "Filter bits            = R12+&" :CC: :STR: :INDEX: prefilterWP
 [ PoppingIconBar
                ! 0,    "#iconbar_pop_state     = R12+&" :CC: :STR: :INDEX: iconbar_pop_state
 ]
 [ CnP
                ! 0,    "#ghostcaretdata        = R12+&" :CC: :STR: :INDEX: ghostcaretdata
                ! 0,    "#selectionwindow       = R12+&" :CC: :STR: :INDEX: selectionwindow
 ]
 [ Autoscr
                ! 0,    "#dragtype              = R12+&" :CC: :STR: :INDEX: dragtype
                ! 0,    "#dragflags             = R12+&" :CC: :STR: :INDEX: dragflags
                ! 0,    "#autoscr_state         = R12+&" :CC: :STR: :INDEX: autoscr_state
 ]


                ! 0,    "Workspace used               &":CC::STR:maxwork:CC:" bytes."


;;-----------------------------------------------------------------------------
;; Format of data in a window definition
;;-----------------------------------------------------------------------------

;; For Aquarius, keep the data from the guard to w_cw0 constant !!!

                ^       0
w_guardword     #       4               ; guard word when policing window handles
w_guardword_valid       *       &646e6957       ; "Wind"
w_taskhandle    #       4               ; handle of task which created window

              [ :LNOT: ChildWindows
w_active_link   #       ll_size         ; this has moved!
              ]
w_all_link      #       ll_size
w_icons         #       4               ; Points to window's block of icons

              [ togglebits
w_togglewidth   #       4               ; width of previous work area if toggled2 is set
w_toggleheight  #       4               ; height of previous work area if toggled2 is set
              ]
              [ Mode22
w_origflags     #       4
              ]

              [ CnP
w_seldata       #       32              ; selection icon, x offset, width, y offset, height+flags, low,high indexes
              ]                         ; [w_seldata+28] = w_selscrollx

              [ ChildWindows
w_bwax0         #       4               ; previous position/size (for toggling)
w_bway0         #       4
w_bwax1         #       4
w_bway1         #       4
w_bscx          #       4               ; previous x,y scroll positions
w_bscy          #       4
w_bbhandle      #       4               ; previous window it was behind

w_alignflags    #       4               ; auto-alignment with parent window

w_opening_link  #       ll_size         ; for the list of windows being opened, and the block-copy rectangles
w_xoffset       #       4
w_yoffset       #       4
w_oldwindowrects  #     4               ; list of rectangles to be block-copied for this window

w_old_data      #       0               ; start of old version of current position

w_old_children  #       lh_size         ; children of this window (chained by w_active_link)
w_old_link      #       ll_size

w_old_parent    #       4               ; parent of this window (if any)

w_old_x0        #       4
w_old_y0        #       4               ; 'current' position, ie. the most-recently-displayed
w_old_x1        #       4               ; these are used for collecting up Wimp_OpenWindows
w_old_y1        #       4

w_old_wax0      #       4               ; x,y coordinates of work area
w_old_way0      #       4               ; (ie. corners)
w_old_wax1      #       4               ;
w_old_way1      #       4
w_old_scx       #       4               ; x,y scroll positions
w_old_scy       #       4               ; (between wex0/y0 and wex1/y1)

w_old_bhandle   #       4               ; not used, but keeps the structures in line

w_old_flags     #       4               ; status of window (open/closed etc.)

w_old_end       #       0

w_new_data      #       0               ; start of new version of current position

w_children      #       lh_size         ; children of this window (chained by w_active_link)
w_active_link   #       ll_size         ; this has moved!

w_parent        #       4               ; parent of this window (if any)
              ]
w_x0            #       4               ; bounding box of window
w_y0            #       4               ; (including outline)
w_x1            #       4               ;
w_y1            #       4               ;

              [ :LNOT: ChildWindows     ; this has moved!
w_bwax0         #       4               ; previous position/size
w_bway0         #       4
w_bwax1         #       4
w_bway1         #       4
w_bscx          #       4               ; previous x,y scroll positions
w_bscy          #       4
w_bbhandle      #       4               ; previous window it was behind
              ]

w_st0           #       0       ; start of 'status' section
w_cw0           #       0       ; start of Create_Window section
w_ow0           #       0       ; start of Open_Window section

w_wax0          #       4               ; x,y coordinates of work area
w_way0          #       4               ; (ie. corners)
w_wax1          #       4               ;
w_way1          #       4
w_scx           #       4               ; x,y scroll positions
w_scy           #       4               ; (between wex0/y0 and wex1/y1)
w_bhandle       #       4               ; handle of window above this one

w_ow1           #       0       ; end of Open_Window section

w_flags         #       4               ; status of window (open/closed etc.)

w_new_end       #       0

w_st1           #       0       ; end of 'status' section

w_tfcol         #       1               ; title foreground colour
w_tbcol         #       1               ; title background colour
w_wfcol         #       1               ; work area foreground colour
w_wbcol         #       1               ; work area background colour
w_scouter       #       1               ; scroll bar outer portion
w_scinner       #       1               ; scroll bar inner portion
w_tbcol2        #       1               ; colour if window has input focus
 [ TrueIcon3
w_flags2        #       1               ; secondary flags
 |
                #       1               ; reserved
 ]
w_wex0          #       4               ; work area extent
w_wey0          #       4               ; (x0,y0,x1,y1)
w_wex1          #       4
w_wey1          #       4
w_titleflags    #       4
w_workflags     #       4               ; icon flags for 'work area'
w_areaCBptr     #       4               ; sprite area CB ptr (<=0 ==> system)
w_minx          #       2               ; minimum x size (0 ==> use title)
w_miny          #       2               ; minimum y size
w_title         #       12              ; title (max 11 chars, then <cr>)
w_nicons        #       4               ; no. of icons following


w_cw1           #       0       ; end of Create_Window section

w_size          #       0       ; end of window data

      [ ChildWindows
        ASSERT  (w_old_end - w_old_data) = (w_new_end - w_new_data)
      ]
      [ CnP
                ! 0,    "Selection data      = handle+&" :CC: :STR: :INDEX: w_seldata
      ]

; standard colour numbers

sc_white              * &0
sc_verylightgrey      * &1
sc_lightgrey          * &2
sc_midlightgrey       * &3
sc_middarkgrey        * &4
sc_darkgrey           * &5
sc_verydarkgrey       * &6
sc_black              * &7
sc_darkblue           * &8
sc_yellow             * &9
sc_lightgreen         * &A
sc_red                * &B
sc_cream              * &C
sc_darkgreen          * &D
sc_orange             * &E
sc_lightblue          * &F

rgb_white             * &FFFFFF00
rgb_verylightgrey     * &DDDDDD00 ; Unused
rgb_lightgrey         * &BBBBBB00
rgb_midlightgrey      * &99999900
rgb_middarkgrey       * &77777700
rgb_darkgrey          * &55555500 ; Unused
rgb_verydarkgrey      * &33333300 ; Unused
rgb_black             * &00000000
rgb_darkblue          * &99440000 ; Unused
rgb_yellow            * &00EEEE00 ; Unused
rgb_lightgreen        * &00CC0000 ; Unused
rgb_red               * &0000DD00 ; Unused
rgb_cream             * &BBEEEE00 ; Unused
rgb_darkgreen         * &00885500 ; Unused
rgb_orange            * &00BBFF00 ; Unused
rgb_lightblue         * &FFBB0000 ; Unused

; bit masks for flags/status

wf_title        *       2_00000000000000000000000000000001
wf_moveable     *       2_00000000000000000000000000000010
wf_vscroll      *       2_00000000000000000000000000000100
wf_hscroll      *       2_00000000000000000000000000001000
wf_autoredraw   *       2_00000000000000000000000000010000
wf_isapane      *       2_00000000000000000000000000100000
wf_nochecks     *       2_00000000000000000000000001000000
wf_nobackquit   *       2_00000000000000000000000010000000
wf_userscroll1  *       2_00000000000000000000000100000000      ; auto-repeat
wf_userscroll2  *       2_00000000000000000000001000000000      ; debounced
wf_userscroll   *       2_00000000000000000000001100000000
wf_realcolours  *       2_00000000000000000000010000000000
wf_backwindow   *       2_00000000000000000000100000000000
wf_grabkeys     *       2_00000000000000000001000000000000
wf_onscreen     *       2_00000000000000000010000000000000      ; override sysflags_offscreen
wf_rubbery_wex1 *       2_00000000000000000100000000000000      ; extent can stretch to the right
wf_rubbery_wey0 *       2_00000000000000001000000000000000      ; extent can stretch downwards

ws_open         *       2_00000000000000010000000000000000
ws_top          *       2_00000000000000100000000000000000
ws_toggled      *       2_00000000000001000000000000000000
ws_toggling     *       2_00000000000010000000000000000000
ws_hasfocus     *       2_00000000000100000000000000000000
              [ :LNOT: ChildWindows
ws_system       *       2_00000000000111110000000000000000
ws_status       *       2_00000000000000110000000000000000      ; calc_w_status
              ]

ws_onscreenonce *       2_00000000001000000000000000000000      ; cancelled after open_window
ws_toggled2     *       2_00000000010000000000000000000000      ; used for storing important toggle

              [ ChildWindows
ws_system       *       2_00000000011111110000000000000000

wf_inborder     *       2_00000000100000000000000000000000      ; child window can overlap parent's border
              ]

wf_icon1        *       2_00000001000000000000000000000000
wf_icon2        *       2_00000010000000000000000000000000
wf_icon3        *       2_00000100000000000000000000000000
wf_icon4        *       2_00001000000000000000000000000000
wf_icon5        *       2_00010000000000000000000000000000
wf_icon6        *       2_00100000000000000000000000000000
wf_icon7        *       2_01000000000000000000000000000000
wf_iconbits     *       2_01111111000000000000000000000000
wf_newformat    *       2_10000000000000000000000000000000

              [ TrueIcon3
wf2_truecolour          *       2_00000001      ; use title validation string colours
                                                ; (implies w_title+4 is always used as validation string pointer, unless
                                                ; already in use as spriteareaCB ptr, or part of non-indirected string)
              ]
wf2_extscrollreq        *       2_00000010      ; used by RISC OS 4.32
wf2_reserved            *       2_00001100      ; these bits are (erroneously) set in ResEd's window-object prototype
                                                ; so we can't use them
	      [ ThreeDPatch
wf2_no3Dborder		*	2_00000100	; this window must never be given a 3D border
wf2_force3Dborder	*	2_00001000	; this window must always be given a 3D border
              ]
wf2_shadedhelp          *       2_00010000      ; return shaded icons in GetPointerInfo, so they can have interactive help

              [ ChildWindows

; alignment options for each item

al_s            *       0               ; align with scrolling element
al_0            *       1               ; align with left/bottom
al_1            *       2               ; align with right/top
al_reserved     *       3               ; not used (yet)

al_mask         *       3

alf_setflags    *       1 :SHL: 0       ; set this bit to alter the window's flags

als_x0          *       16              ; bit numbers (shift the above by these)
als_y0          *       18
als_x1          *       20
als_y1          *       22
als_scx         *       24
als_scy         *       26

alm_x0          *       ( al_mask :SHL: als_x0 )
alm_y0          *       ( al_mask :SHL: als_y0 )
alm_x1          *       ( al_mask :SHL: als_x1 )
alm_y1          *       ( al_mask :SHL: als_y1 )
alm_scx         *       ( al_mask :SHL: als_scx )
alm_scy         *       ( al_mask :SHL: als_scy )

al0_x0          *       ( al_0 :SHL: als_x0 )
al0_y0          *       ( al_0 :SHL: als_y0 )
al0_x1          *       ( al_0 :SHL: als_x1 )
al0_y1          *       ( al_0 :SHL: als_y1 )
al0_scx         *       ( al_0 :SHL: als_scx )
al0_scy         *       ( al_0 :SHL: als_scy )

              ]

;;-----------------------------------------------------------------------------
;; Format of data in an icon definition
;;-----------------------------------------------------------------------------

                ^       0
i_bbx0          #       4               ; bounding box (x0,y0,x1,y1)
i_bby0          #       4
i_bbx1          #       4               ; if sprite, get size instead
i_bby1          #       4
i_flags         #       4
i_data          #       12      ; up to 12 bytes of text/sprite name etc.

i_size          #       0       ; size of icon data

i_shift         *       5
             ASSERT     (i_size = 1:SHL:i_shift)

; bit masks for flags

if_text         *       2_00000000000000000000000000000001
if_sprite       *       2_00000000000000000000000000000010
if_border       *       2_00000000000000000000000000000100
if_hcentred     *       2_00000000000000000000000000001000
if_vcentred     *       2_00000000000000000000000000010000
if_filled       *       2_00000000000000000000000000100000
if_fancyfont    *       2_00000000000000000000000001000000
if_funnyicon    *       2_00000000000000000000000010000000
if_indirected   *       2_00000000000000000000000100000000
if_rjustify     *       2_00000000000000000000001000000000
if_canadjust    *       2_00000000000000000000010000000000
if_halfsize     *       2_00000000000000000000100000000000

if_buttontype   *       2_00000000000000001111000000000000
if_esg          *       2_00000000000111110000000000000000
if_esg2         *       2_00000000000011110000000000000000   ; all but top bit
if_numeric      *       2_00000000000100000000000000000000   ; Just top bit

; bit masks for status

is_inverted     *       2_00000000001000000000000000000000
is_shaded       *       2_00000000010000000000000000000000
is_deleted      *       2_00000000100000000000000000000000

; foreground and background colours

if_fcol         *       2_00001111000000000000000000000000
if_bcol         *       2_11110000000000000000000000000000
if_shadecols    *       2_00100010111111111111111111111111

; bit positions of various fields

ib_buttontype   *       12
ib_esg          *       16
ib_fcol         *       24
ib_bcol         *       28
ib_fontno       *       24              ; overlaid

; button types

ibt_never           *   0               ; never report
ibt_always          *   1               ; always report
ibt_autorepeat      *   2               ; button clicked (auto-repeat)
ibt_click           *   3               ; button clicked (debounced)
ibt_clickrelease    *   4               ; select if clicked, report if released
ibt_click2          *   5               ; select if clicked, report if 2 clicks
ibt_dclick          *   6               ; as for (3), but can also drag
ibt_dclickrelease   *   7               ; as for (4), but can also drag
ibt_dclick2         *   8               ; as for (5), but can also drag
ibt_menuicon        *   9               ; select when hover over, notify on click
ibt_rdclick2        *   10              ; as for (8), but reports for 1 click also
ibt_clicksel        *   11              ; select and notify on click, but can also drag
ibt_dwritable       *   14              ; writable gains caret, but can also drag
ibt_writeable       *   15              ; writable gains caret

erf_okbox       *       1 :SHL: 0
erf_cancelbox   *       1 :SHL: 1
erf_htcancel    *       1 :SHL: 2
erf_dontwait    *       1 :SHL: 3
erf_omiterror   *       1 :SHL: 4
erf_poll        *       1 :SHL: 5       ; leave error window open
erf_pollexit    *       1 :SHL: 6       ; close error window
erf_nobeep      *       1 :SHL: 7       ; don't beep (Wimp 2.28 onwards)
erf_newtype	*	1 :SHL: 8	; new style error report (Wimp 3.21 onwards)
erf_errortype	*	7 :SHL: 9	; error type (new style only)
 [ true
erf_describe	*	1 :SHL: 23	; used internally
erf_ocontcode_shift           * 24
erf_ocontcode   *      15 :SHL: erf_ocontcode_shift   ; return code to use for Continue in "omen" window (0 => return 1)
erf_ocancelcode_shift         * 28
erf_ocancelcode *      15 :SHL: erf_ocancelcode_shift ; return code to use for Cancel in "omen" window (0 => exit handler)
 |
erf_describe	*	1 :SHL: 31	; used internally
 ]

erb_errortype	*	9

;;------------------------------------------------------------------------------
;; Things to do with swapping of tasks to disc
;;------------------------------------------------------------------------------

               [ Swapping

swapping_version   *  286         ; First version in which swapping is implemented.
                                  ; So that it can be changed.
               ]


;;-----------------------------------------------------------------------------
;; RM header information
;;-----------------------------------------------------------------------------

        ASSERT  (.=Module_BaseAddr)

        ENTRY

MySWIBase       *       Module_SWISystemBase + WimpSWI * Module_SWIChunkSize

        DCD     Start          - Module_BaseAddr
        DCD     Init           - Module_BaseAddr
        DCD     Die            - Module_BaseAddr
        DCD     Service        - Module_BaseAddr
        DCD     Title          - Module_BaseAddr
        DCD     Helpstr        - Module_BaseAddr
        DCD     Helptable      - Module_BaseAddr
        DCD     MySWIBase
        DCD     Wimp_SWIdecode - Module_BaseAddr
        DCD     Wimp_SWInames  - Module_BaseAddr
        DCD     0
 [ international_help
        DCD     messfsp        - Module_BaseAddr
 |
        DCD     0
 ]
        DCD     Flags          - Module_BaseAddr

Title   =       "WindowManager",0
Helpstr =       "Window Manager",9,"$Module_HelpVersion"
        [ DebugMemory
        = " Memory debugging enabled"
        ]
      [ debug
        =       " Development version"
      ]
      [ standalone
        =       "  (Stand alone)"
      ]
	=	module_postfix
        =       0

 [ :LNOT: international_help

IconSprites_Help        DCB     "*IconSprites loads a sprite file into the "
                        DCB     "Wimp's common sprite pool",cr
IconSprites_Syntax      DCB     "Syntax: *IconSprites <filename>",0

Pointer_Help            DCB     "*Pointer turns the mouse pointer on/off",cr
Pointer_Syntax          DCB     "Syntax: *Pointer [0|1]",0

ToolSprites_Help        DCB     "*ToolSprites loads a sprite file to use as window borders",cr
ToolSprites_Syntax      DCB     "Syntax: *ToolSprites <filename>",0

WimpFlagsC_Help
        DCB     "*Configure WimpFlags sets the default actions "
        DCB     "when dragging windows, as follows:",cr
        DCB     "bit 0 set: continuous window movement",cr
        DCB     "bit 1 set: continuous window resizing",cr
        DCB     "bit 2 set: continuous horizontal scroll",cr
        DCB     "bit 3 set: continuous vertical scroll",cr
        DCB     "bit 4 set: don't beep when error box appears",cr
        DCB     "bit 5 set: allow windows to go partly off screen",cr
        DCB     "bit 6 set: allow windows to go partly off screen in all directions",cr
        DCB     "bit 7 set: open submenus automatically",cr

WimpFlagsC_Syntax
        DCB     "Syntax: *Configure WimpFlags <number>",0

WimpDragDelayC_Help
        DCB     "*Configure WimpDragDelay sets the delay in 1/10 second units after a single click "
        DCB     "after which a drag is started.",cr

WimpDragDelayC_Syntax
        DCB     "Syntax: *Configure WimpDragDelay <delay>",0

WimpFontC_Help
        DCB     "*Configure WimpFont sets the font to be used within the desktop for icons and menus. "
        DCB     "0 means use Wimp$* and 1 means use system font. 2-15 refer to a ROM font.",cr

WimpFontC_Syntax
        DCB     "Syntax: *Configure WimpFont <font number>",0

WimpDragMoveC_Help
        DCB     "*Configure WimpDragMove sets the distance in OS units that the "
        DCB     "pointer has to move after a single click for a drag to be started.",cr

WimpDragMoveC_Syntax
        DCB     "Syntax: *Configure WimpDragMove <distance>",0

WimpDoubleClickDelayC_Help
        DCB     "*Configure WimpDoubleClickDelay sets the time in 1/10 second units after a single click "
        DCB     "during which a double click is accepted.",cr

WimpDoubleClickDelayC_Syntax
        DCB     "Syntax: *Configure WimpDoubleClickDelay <delay>",0

WimpDoubleClickMoveC_Help
        DCB     "*Configure WimpDoubleClickMove sets the distance in OS units that the "
        DCB     "pointer has to move after a single click for a double click to be cancelled.",cr

WimpDoubleClickMoveC_Syntax
        DCB     "Syntax: *Configure WimpDoubleClickMove <distance>",0

WimpAutoMenuDelayC_Help
        DCB     "*Configure WimpAutoMenuDelay sets the time in 1/10 second units that the pointer "
        DCB     "has to stay over a non leaf menu entry before the submenu is automatically opened "
        DCB     "if WimpFlags bit 7 is set.",cr

WimpAutoMenuDelayC_Syntax
        DCB     "Syntax: *Configure WimpAutoMenuDelay <delay>",0

WimpMenuDragDelayC_Help
        DCB     "*Configure WimpMenuDragDelay sets the time in 1/10 second units for which menu "
        DCB     "activity is disabled after a menu has been automatically opened. This enables the "
        DCB     " pointer to move over other menu entries without cancelling the submenu.",cr

WimpMenuDragDelayC_Syntax
        DCB     "Syntax: *Configure WimpMenuDragDelay <delay>",0

WimpPalette_Help        DCB     "Used to activate a Wimp palette file.",cr
WimpPalette_Syntax      DCB     "Syntax: *WimpPalette <filename>",0

WimpSlot_Help   DCB     "Change the size of application space"
                DCB     ", or the amount of application space allocated to the next task to run."
                DCB     cr

WimpSlot_Syntax DCB     "Syntax: *WimpSlot [[-min] <size>[K]] [[-max] <size>[K]] [[-next] <size>[K]]"
                DCB     0

WimpTask_Help   DCB     "Start up a new task (from within a task)",cr
WimpTask_Syntax DCB     "Syntax: *WimpTask <*command>",0

Wimp_SetMode_Help   DCB "Change the current Wimp screen mode"
                    DCB " without affecting the configured value.",cr
Wimp_SetMode_Syntax DCB "Syntax: *WimpMode <number>"
        [ Medusa
                DCB     " | <specifier string>"
        ]
        DCB     0

WimpWriteDir_Help       DCB "Change the direction for writeable icons.",cr
                        DCB " 0 - Same direction as the configured territory.",cr
                        DCB " 1 - Opposite direction to the configured territory.",cr
WimpWriteDir_Syntax     DCB "Syntax: *WimpWriteDir 0|1",0

WimpKillSprite_Help     DCB "Remove a sprite from the wimp sprite pool.",cr
WimpKillSprite_Syntax   DCB "Syntax: *WimpKillSprite <spritename>",0

        [ Autoscr
WimpAutoScrollDelayC_Help       DCB "*Configure WimpAutoScrollDelay sets the time in 1/10 second units "
                                DCB "that the pointer has to stay over the edge of a window before it starts scrolling. "
                                DCB "This only applies in certain circumstances.",cr
WimpAutoScrollDelayC_Syntax     DCB "Syntax: *Configure WimpAutoScrollDelay <delay>",0
        ]
        [ PoppingIconBar
WimpAutoFrontDelayC_Help        DCB "*Configure WimpAutoFrontDelay sets the time in 1/10 second units "
                                DCB "that the pointer has to stay at the bottom of the screen before "
                                DCB "the icon bar is brought to the front.",cr
WimpAutoFrontDelayC_Syntax      DCB "Syntax: *Configure WimpAutoFrontDelay <delay>",0
        ]

WimpIconBarSpeedC_Help          DCB "*Configure WimpIconBarSpeed sets the initial scrolling speed of the icon bar "
                                DCB "in OS units per second.",cr
WimpIconBarSpeedC_Syntax        DCB "Syntax: *Configure WimpIconBarSpeed <speed>",0

WimpIconBarAccelerationC_Help   DCB "*Configure WimpIconBarAcceleration sets the acceleration rate of an icon bar scroll "
                                DCB "in OS units per second per second.",cr
WimpIconBarAccelerationC_Syntax DCB "Syntax: *Configure WimpIconBarAcceleration <rate>",0

        [ IconiseButton
WimpIconiseButtonC_Help         DCB "*Configure WimpIconiseButton sets whether an iconise button is added to "
                                DCB "top-level windows.",cr
WimpIconiseButtonC_Syntax       DCB "Syntax: *Configure WimpIconiseButton On|Off",0
        ]
        [ PoppingIconBar
WimpAutoFrontIconBarC_Help      DCB "*Configure WimpAutoFrontIconBar sets whether the icon bar is brought to the front "
                                DCB "when the pointer is held at the bottom of the screen.",cr
WimpAutoFrontIconBarC_Syntax    DCB "Syntax: *Configure WimpAutoFrontIconBar On|Off",0
        ]
        [ SpritePriority
WimpSpritePrecedenceC_Help      DCB "*Configure WimpSpritePrecedence sets whether ROM sprites have priority over "
                                DCB "RAM sprites or vice versa.",cr
WimpSpritePrecedenceC_Syntax    DCB "Syntax: *Configure WimpSpritePrecedence RAM|ROM",0
        ]
        [ StickyEdges
WimpStickyEdgesC_Help           DCB "*Configure WimpStickyEdges sets whether 'force on screen' directions can be "
                                DCB "overridden by pushing a window 'hard' enough.",cr
WimpStickyEdgesC_Syntax         DCB "Syntax: *Configure WimpStickyEdges On|Off",0
        ]
        [ BounceClose
WimpButtonTypeC_Help            DCB "*Configure WimpButtonType sets whether the back, close, iconise and toggle-size icons "
                                DCB "act when you click on them or when you release the mouse button afterwards.",cr
WimpButtonTypeC_Syntax          DCB "Syntax: *Configure WimpButtonType Click|Release",0
        ]
        [ ClickSubmenus
WimpClickSubmenuC_Help          DCB "*Configure WimpClickSubmenu sets whether clicking on a menu item that has an attached "
                                DCB "submenu will cause the attached submenu to be opened.",cr
WimpClickSubmenuC_Syntax        DCB "Syntax: *Configure WimpClickSubmenu On|Off",0
        ]
	[ ThreeDPatch
WimpVisualFlags_Help		DCB "*WimpVisualFlags changes some aspects of the visual appearance of the desktop.",cr
				DCB "-3DWindowBorders",cr
				DCB "   Give all menus and dialogue boxes a 3D border.",cr
				DCB "-TexturedMenus",cr
				DCB "   Give all menus a textured background.",cr
				DCB "-UseAlternateMenuBg",cr
				DCB "   Use a different background tile for menus.",cr
				DCB "-RemoveIconBoxes",cr
				DCB "   Remove the filled box from behind the text in text+sprite icons.",cr
				DCB "-NoIconBoxesInTransWindows",cr
				DCB "   Remove the filled box from icons on windows similar to the pinboard.",cr
				DCB "-Fully3DIconBar",cr
				DCB "   Make the iconbar have a full 3D border.",cr
				DCB "-FontBlending",cr
				DCB "   Use font blending in icons.",cr
				DCB "-WindowOutlineOver",cr
				DCB "   Plot the window outline over the tool icons.",cr
				DCB "-All",cr
				DCB "   Turn all flags on.",cr
				DCB "-WindowBorderFaceColour <&RRGGBB>",cr
				DCB "   Set the colour of the top left portion of the window border.",cr
				DCB "-WindowBorderOppColour <&RRGGBB>",cr
				DCB "   Set the colour of the bottom right portion of the window border.",cr
				DCB "-MenuBorderFaceColour <&RRGGBB>",cr
				DCB "   Set the colour of the top left portion of the menu border.",cr
				DCB "-MenuBorderOppColour <&RRGGBB>",cr
				DCB "   Set the colour of the bottom right portion of the menu border.",cr
                                DCB "-WindowOutlineColour <&RRGGBB>",cr
                                DCB "   Set the colour of the window outline.",cr
WimpVisualFlags_Syntax		DCB "Syntax: *WimpVisualFlags <options>",0
	]
                        ALIGN

 |
IconSprites_Help        DCB     "HWNMICS",0
IconSprites_Syntax      DCB     "SWNMICS",0

Pointer_Help            DCB     "HWNMPTR",0
Pointer_Syntax          DCB     "SWNMPTR",0

ToolSprites_Help        DCB     "HWNMTSP",0
ToolSprites_Syntax      DCB     "SWNMTSP",0

WimpFlagsC_Help
        DCB     "HWNMCWF",0
WimpFlagsC_Syntax
        DCB     "SWNMCWF",0

WimpDragDelayC_Help
        DCB     "HWNMWDD",0
WimpDragDelayC_Syntax
        DCB     "SWNMWDD",0

WimpFontC_Help
        DCB     "HWNMFON",0
WimpFontC_Syntax
        DCB     "SWNMFON",0

WimpDragMoveC_Help
        DCB     "HWNMWDM",0
WimpDragMoveC_Syntax
        DCB     "SWNMWDM",0

WimpDoubleClickDelayC_Help
        DCB     "HWNMDCD",0
WimpDoubleClickDelayC_Syntax
        DCB     "SWNMDCD",0

WimpDoubleClickMoveC_Help
        DCB     "HWNMDCM",0
WimpDoubleClickMoveC_Syntax
        DCB     "SWNMDCM",0

WimpAutoMenuDelayC_Help
        DCB     "HWNMAMD",0
WimpAutoMenuDelayC_Syntax
        DCB     "SWNMAMD",0

WimpMenuDragDelayC_Help
        DCB     "HWNMMDD",0
WimpMenuDragDelayC_Syntax
        DCB     "SWNMMDD",0

WimpPalette_Help        DCB     "HWNMWP",0
WimpPalette_Syntax      DCB     "SWNMWP",0

WimpSlot_Help   DCB     "HWNMWS",0
WimpSlot_Syntax DCB     "SWNMWS",0

WimpTask_Help   DCB     "HWNMWT",0
WimpTask_Syntax DCB     "SWNMWT",0

Wimp_SetMode_Help   DCB "HWNMWM",0
Wimp_SetMode_Syntax DCB "SWNMWM",0

WimpWriteDir_Help       DCB "HWNMWWD",0
WimpWriteDir_Syntax     DCB "SWNMWWD",0

WimpKillSprite_Help     DCB "HWNMKS",0
WimpKillSprite_Syntax   DCB "SWNMKS",0

        [ Autoscr
WimpAutoScrollDelayC_Help       DCB "HWNMASD",0
WimpAutoScrollDelayC_Syntax     DCB "SWNMASD",0
        ]
        [ PoppingIconBar
WimpAutoFrontDelayC_Help        DCB "HWNMAFD",0
WimpAutoFrontDelayC_Syntax      DCB "SWNMAFD",0
        ]

WimpIconBarSpeedC_Help          DCB "HWNMIBS",0
WimpIconBarSpeedC_Syntax        DCB "SWNMIBS",0

WimpIconBarAccelerationC_Help   DCB "HWNMIBA",0
WimpIconBarAccelerationC_Syntax DCB "SWNMIBA",0

        [ IconiseButton
WimpIconiseButtonC_Help         DCB "HWNMICB",0
WimpIconiseButtonC_Syntax       DCB "SWNMICB",0
        ]
        [ PoppingIconBar
WimpAutoFrontIconBarC_Help      DCB "HWNMAF",0
WimpAutoFrontIconBarC_Syntax    DCB "SWNMAF",0
        ]
        [ SpritePriority
WimpSpritePrecedenceC_Help      DCB "HWNMSPP",0
WimpSpritePrecedenceC_Syntax    DCB "SWNMSPP",0
        ]
        [ StickyEdges
WimpStickyEdgesC_Help           DCB "HWNMSE",0
WimpStickyEdgesC_Syntax         DCB "SWNMSE",0
        ]
        [ BounceClose
WimpButtonTypeC_Help            DCB "HWNMBT",0
WimpButtonTypeC_Syntax          DCB "SWNMBT",0
        ]
        [ ClickSubmenus
WimpClickSubmenuC_Help          DCB "HWNMCSM",0
WimpClickSubmenuC_Syntax        DCB "SWNMCSM",0
        ]
	[ ThreeDPatch
WimpVisualFlags_Help		DCB "HWNMVF",0
WimpVisualFlags_Syntax		DCB "SWNMVF",0
	]
                        ALIGN

 ]

Flags
        [ No32bitCode
        DCD     0
        |
        DCD     ModuleFlag_32bit
        ]
        [ international_help
i_h_flag      * International_Help
        |
i_h_flag      * 0
        ]
        
Helptable
        Command IconSprites,            1,1,                       i_h_flag
        Command Pointer,                1,0,                       i_h_flag
        Command ToolSprites,            1,0,                       i_h_flag
        [ Medusa
        Command WimpMode,               255,1,                     i_h_flag,Wimp_SetMode
        |
        Command WimpMode,               1,1,                       i_h_flag,Wimp_SetMode
        ]
        Command WimpPalette,            1,1,                       i_h_flag
        Command WimpSlot,               6,1,                       i_h_flag
        Command WimpTask,               255,1,                     i_h_flag
        Command WimpWriteDir,           1,1,                       i_h_flag
        Command WimpKillSprite,         1,1,                       i_h_flag
        Command WimpFlags,              1,1,Status_Keyword_Flag:OR:i_h_flag,WimpFlagsC
        Command WimpFont,               1,1,Status_Keyword_Flag:OR:i_h_flag,WimpFontC
        Command WimpDragDelay,          1,1,Status_Keyword_Flag:OR:i_h_flag,WimpDragDelayC
        Command WimpDragMove,           1,1,Status_Keyword_Flag:OR:i_h_flag,WimpDragMoveC
        Command WimpDoubleClickDelay,   1,1,Status_Keyword_Flag:OR:i_h_flag,WimpDoubleClickDelayC
        Command WimpDoubleClickMove,    1,1,Status_Keyword_Flag:OR:i_h_flag,WimpDoubleClickMoveC
        Command WimpAutoMenuDelay,      1,1,Status_Keyword_Flag:OR:i_h_flag,WimpAutoMenuDelayC
        Command WimpMenuDragDelay,      1,1,Status_Keyword_Flag:OR:i_h_flag,WimpMenuDragDelayC
        Command WimpIconBarSpeed,       1,1,Status_Keyword_Flag:OR:i_h_flag,WimpIconBarSpeedC
        Command WimpIconBarAcceleration,1,1,Status_Keyword_Flag:OR:i_h_flag,WimpIconBarAccelerationC
        [ SpritePriority
        Command WimpSpritePrecedence,   1,1,Status_Keyword_Flag:OR:i_h_flag,WimpSpritePrecedenceC
        ]
        [ BounceClose
        Command WimpButtonType,         1,1,Status_Keyword_Flag:OR:i_h_flag,WimpButtonTypeC
        ]
        [ IconiseButton
        Command WimpIconiseButton,      1,1,Status_Keyword_Flag:OR:i_h_flag,WimpIconiseButtonC
        ]
        [ StickyEdges
        Command WimpStickyEdges,        1,1,Status_Keyword_Flag:OR:i_h_flag,WimpStickyEdgesC
        ]
        [ PoppingIconBar
        Command WimpAutoFrontIconBar,   1,1,Status_Keyword_Flag:OR:i_h_flag,WimpAutoFrontIconBarC
        Command WimpAutoFrontDelay,     1,1,Status_Keyword_Flag:OR:i_h_flag,WimpAutoFrontDelayC
        ]
        [ Autoscr
        Command WimpAutoScrollDelay,    1,1,Status_Keyword_Flag:OR:i_h_flag,WimpAutoScrollDelayC
        ]
        [ ClickSubmenus
        Command WimpClickSubmenu,       1,1,Status_Keyword_Flag:OR:i_h_flag,WimpClickSubmenuC
        ]
        [ ThreeDPatch
        Command WimpVisualFlags,        255,0,                     i_h_flag
        ]
        DCB     0
        ALIGN

;............................................................................


WimpWriteDir_Code
        Push    "LR"

        MOV     R1,R0                   ; R1 -> string form of number
        MOV     R0,#10                  ; R0 = default base
        SWI     XOS_ReadUnsigned
        Pull    "PC",VS
        CMP     R2,#1
        Pull    "PC",HI
        MOV     r0,#-1
        SWI     XTerritory_WriteDirection
        MOVVS   R0,#WriteDirection_LeftToRight
        TST     R0,#WriteDirection_RightToLeft
        SUBNE   R2,R2,#1
        LDR     R12,[R12]               ; get workspace pointer!
        STR     R2,writeabledir

        Pull    "PC"

;............................................................................


WimpTask_Code
        Push    "LR"

        LDR     wsptr,[R12]             ; wsptr -> workspace
        LDR     R14,taskhandle
        LDR     R14,[wsptr,R14]
        TST     R14,#task_unused        ; if already a Wimp task,
        BEQ     %FT01                   ; no need to initialise temporarily

        MOV     R2,R0                   ; R2 -> parameters
        MOV     R0,#ModHandReason_Enter
        ADRL    R1,Title
        BL     XROS_Module

        Pull    "PC"                    ; in case it returned!
01
        SWI     XWimp_StartTask         ; R0 --> parameters
        Pull    "PC"

; must actually enter the module in order to start a task!
; NB: there is no workspace (or stack) here!

Start
        MOV     R3,R0                   ; R3 -> parameters

        MOV     R0,#200                 ; initialise temporarily
        LDR     R1,taskid3
        ADR     R2,str_tmp
        SWI     Wimp_Initialise

        MOV     R0,R3
        SWI     Wimp_StartTask          ; use normal error handler

        SWI     OS_Exit                 ; also does a closedown

taskid3 DCB     "TASK"
str_tmp DCB     "<temporary>", 0
        ALIGN

;............................................................................

Wimp_SetMode_Code
        Push    "LR"

        [ true
        Push    "R12"
        LDR     R12,[R12]
        ADRL    R14,greys_mode
        LDRB    R1,[R14]
        STRB    R1,[R14,#1]             ; last time
        MOV     R1,#0
        STRB    R1,[R14]                ; assume not a grey mode at first
        Pull    "R12"
        ]

        MOV     R1,R0                   ; R1 -> string form of number
        MOV     R0,#10                  ; R0 = default base
        SWI     XOS_ReadUnsigned
        [ Medusa
        BVS     setmode_from_specifier
        |
        Pull    "PC",VS
        ]

        LDR     R12,[R12]               ; get workspace pointer!
        CMP     R2,#255
        BHI     bad_param_exit2
        LDR     R14,currentmode         ; only set the mode if different
        Debug   xx,"*WimpMode: old,new =",R14,R2
        CMP     R2,R14
        MOVNE   R0,R2
        SWINE   XWimp_SetMode

        Pull    "PC"

        [ Medusa
setmode_from_specifier
; R1 -> string
     [ {TRUE}
        ; See if the OS can handle the conversion for us
        MOV     R0,#ScreenModeReason_ModeStringToSpecifier
        SUB     SP,SP,#ModeSelector_MaxSize
        MOV     R2,SP
        MOV     R3,#ModeSelector_MaxSize
        SWI     XOS_ScreenMode
        ADDVS   SP,SP,#ModeSelector_MaxSize
        BVS     setmode_from_specifier_manual
        MOV     R0,SP
        SWI     XWimp_SetMode
        ; TODO anything extra here?
        ADD     SP,SP,#ModeSelector_MaxSize
        Pull    "PC"
setmode_from_specifier_manual
     ]
        MOV     R0,#-1
        LDR     R12,[R12]
        Push    "R12"
        MOV     R12,SP                  ; R12 not required yet
        Push    "R0"                    ; end of params
        [ DoubleHeightVDU4
	MOV	R3, #VduExt_ModeFlags
	MOV	R4, #1			; get back to this  (it's [R12, #-16])
	MOV	R5, #VduExt_ScrBRow
	MOV	R6, #-1			; get back to this too... ([R12, #-8])
	Push	"R3-R6"
        ]
; use R4-R6 for xres,yres,bpp, R3 frame rate
        MOV     R4,#-1
        MOV     R5,#-1
        MOV     R6,#-1                  ; must specify these
        MOV     R3,#-1
scan_for_param
        LDRB    R0,[R1],#1
        CMP     R0,#32
        BLO     scan_ended
        BEQ     scan_for_param
        CMP     R0,#","
        BEQ     scan_for_param
        ASCII_UpperCase R0,R14          ; this is safe
        CMP     R0,#"E"
        BEQ     get_eig_factors
        CMP     R0,#"X"
        BEQ     get_xres
        CMP     R0,#"Y"
        BEQ     get_yres
        CMP     R0,#"C"
        BEQ     get_colours
        CMP     R0,#"G"
        BEQ     get_greys
        CMP     R0,#"F"
        BEQ     get_frame
; oh dear, user error
bad_param_exit
        MOV     SP,R12
        Pull    "R12"
        ]

bad_param_exit2
;R12 needed by error lookup
        MyXError        BadParameters
        Pull    "PC"
        ; SMC: use international error block as "BadParameters" token did not exist
        MakeInternatErrorBlock  BadParameters,,BadParm

        [ Medusa
get_eig_factors
        LDRB    R0,[R1],#1
        ASCII_UpperCase R0,R14
        CMP     R0,#"X"                  ; only EX EY allowed
        MOVEQ   R0,#VduExt_XEigFactor
        CMP     R0,#"Y"
        MOVEQ   R0,#VduExt_YEigFactor
        CMPNE   R0,#VduExt_XEigFactor
        BNE     bad_param_exit
        Push    "R0"
        MOV     R0,#&2000000a           ; base 10
        MOV     R2,#3                   ; only allow 0-3 (note OS can cope with 4)
        SWI     XOS_ReadUnsigned
        BVS     bad_param_exit
        Pull    "R0"
        Push    "R0,R2"
	[ DoubleHeightVDU4
	TEQ	R0,#VduExt_XEigFactor	; squirrel this away...
	STREQ	R2,[R12,#-16]
	STRNE	R2,[R12,#-8]
	]
        B       scan_for_param

get_xres
        CMP     R4,#-1
        BNE     bad_param_exit                  ; only one x allowed
        SWI     XOS_ReadUnsigned
        BVS     bad_param_exit
        MOV     R4,R2
        B       scan_for_param

get_yres
        CMP     R5,#-1
        BNE     bad_param_exit                  ; only one y allowed
        SWI     XOS_ReadUnsigned
        BVS     bad_param_exit
        MOV     R5,R2
        B       scan_for_param

get_frame
        SWI     XOS_ReadUnsigned
        BVS     bad_param_exit
        MOV     R3,R2
        B       scan_for_param

get_colours
        CMP     R6,#-1
        BNE     bad_param_exit                  ; only one C or G allowed
; only 2,4,16,64,256,32T,32K,16M are valid
        SWI     XOS_ReadUnsigned
        BVS     bad_param_exit
        MOV     R0,#-1
        CMP     R2,#2
        MOVEQ   R0,#0                           ; 1bpp
        CMP     R2,#4
        MOVEQ   R0,#1                           ; 2bpp
        CMP     R2,#256
;        MOVEQ   R0,#3                           ; NCol
;        MOVEQ   R2,#255
;        Push    "R0,R2",EQ
        CMPNE   R2,#64
        MOVEQ   R0,#3                           ; 8bpp
        CMP     R0,#-1
        MOVNE   R6,R0
        BNE     scan_for_param
        LDRB    R0,[R1]
        ASCII_UpperCase R0,R14
        CMP     R2,#16
        BNE     %FT05
        CMP     R0,#"M"
        ADDEQ   R1,R1,#1
        MOVEQ   R6,#5                           ; 32bpp (16M)
        MOVNE   R6,#2                           ; 4bpp  (16)
        B       scan_for_param
5
        CMP     R2,#32
        BNE     bad_param_exit
        ; must be either T or K
        CMP     R0,#"T"
        CMPNE   R0,#"K"
        BNE     bad_param_exit
        ADD     R1,R1,#1                        ; move it along
        MOV     R6,#4                           ; 16bpp
        B       scan_for_param

get_greys
        CMP     R6,#-1
        BNE     bad_param_exit                  ; only one C or G allowed
        SWI     XOS_ReadUnsigned
        BVS     bad_param_exit
        CMP     R2,#16
        MOV     R6,#3+128                         ; 8bpp (+128 makes the palette get hit later)
        MOVEQ   R6,#2+128                         ; 4bpp
        CMPNE   R2,#256
        CMPNE   R2,#4
        CMPNE   R2,#2
        BNE     bad_param_exit
        CMP     R2,#4
        MOVEQ   R6,#1
        CMP     R2,#2
        MOVEQ   R6,#0                             ; no palette munging so not +128
        CMP     R2,#256
        MOVEQ   R0,#3                           ; NCol
        MOVEQ   R2,#255
        Push    "R0,R2",EQ                      ; must be set for 256 greys
        MOVEQ   R0,#0                           ; ModeFlags
        MOVEQ   R2,#128
        Push    "R0,R2",EQ                      ; must be set for 256 greys

        B       scan_for_param

scan_ended
        CMP     R4,#-1
        CMPNE   R5,#-1
        CMPNE   R6,#-1
        BEQ     bad_param_exit          ; all must be supplied
        Push    "R3"                    ; frame rate
        TST     R6,#128
        BICNE   R6,R6,#128              ; greys required
        Push    "R4-R6"                 ; xres, yres bpp
        ORRNE   R6,R6,#128
        MOVEQ   R6,#0
        MOV     R0,#1                   ; mode selector flags
        Push    "R0"

	[ DoubleHeightVDU4
	; Need to establish what XEigFactor and YEigFactor are
	LDR	R0,[R12,#-8]
	CMP	R0,#-1
	BNE	%FT01
	CMP	R5, R4, LSR #1		; is yres >= xres/2?
	MOVHS	R0,#1
	MOVLO	R0,#2
01	LDR	R14,[R12,#-16]
	; is yeig(R0) > xeig(R14), don't double height
	CMP	R0,R14
	MOVHI	R0,#0
	MOVHI	R14,R5,LSR #3
	MOVLS	R0,#ModeFlag_DoubleVertical
	MOVLS	R14,R5,LSR #4
	SUB	R14,R14,#1
	STR	R0,[R12,#-16]		; store the mode flags
	STR	R14,[R12,#-8]		; store the text height
	]
        MOV     R0,SP
        Push    R12
        LDR     R12,[R12]               ; the R12 that was saved on the stack
        ADRL    R14,greys_mode
        STRB    R6,[R14]
        SWI     XWimp_SetMode           ; may update greys_mode
        Pull    R12,VS                  ; SMC: only pull R12 if VS, need R12=wsptr to load greys_mode below
        BVS     exit_setmode

        ADRL    R14,greys_mode          ; SMC: get possibly updated greys_mode
        LDRB    R6,[R14]
        TST     R6,#128
        Pull    R12                     ; SMC: get back R12->old top of stack
        BEQ     exit_setmode

        MOV     SP,R12
        NOP
        Pull    "R12"

        BL      recalc_greys_palette
; palette changed so send message
        SWI       XColourTrans_InvalidateCache
        [ false
; as we haven't done the wimp palette, no need
        MOV     R14,#ms_data            ; size of block
        STR     R14,[sp,#-ms_data]!
        MOV     R0,#User_Message
        MOV     R1,sp
        MOV     R2,#0
        STR     R2,[R1,#ms_yourref]
        MOV     R14,#Message_PaletteChange
        STR     R14,[R1,#ms_action]
        SWI     XWimp_SendMessage
        ADD     sp,sp,#ms_data          ; correct stack
        ]
        Pull    "PC"

recalc_greys_palette
        Push    "R0-R9,lr"
        ADRL    R14,greys_mode
        LDRB    R6,[R14]
        TEQ     R6,#128+3
        BEQ     set_greys256
        [ false
set_grey_palette
        ; must splat the palette for the grey scales
        SUB     SP,SP,#80
        MOV     R1,SP
        SWI     XWimp_ReadPalette
        ; preserves border and pointer colours
        MOV     R0,#8
        ADD     R1,R1,#32               ; jump first 8 colours
        ADR     R2,greys_16
5
        LDR     R14,[R2],#4
        STR     R14,[R1],#4
        SUBS    R0,R0,#1
        BNE     %BT5
        MOV     R1,SP
        SWI     XWimp_SetPalette
        |
        ; must set palette directly
set_grey_palette

        Push    "R9"
        MOV     R9,#&23                 ; PaletteV
        MOV     R0,#8                   ; start at colour 8
        MOV     R1,#16
        MOV     R4,#2                   ; set palette, R4 becomes zero on return
5
        Push    "R0-R5,R9"
        ADR     R2,greys_16
        SUB     R2,R2,#32
        LDR     R2,[R2,R0, LSL #2]
        MOV     R3,R2
        SWI     XOS_CallAVector
        Pull    "R0-R5,R9"
        Pull    "R9",VS
        BVS     exit_setmodegreys
        ADD     R0,R0,#1

        CMP     R0,#16
        BNE     %BT5
        Pull    "R9"
        ]

exit_setmodegreys
        Pull    "R0-R9,PC"



exit_setmode
        MOV     SP,R12
        Pull    "R12,PC"

set_greys256
        ; must set palette directly
        Push    "R9"
        MOV     R9,#&23                 ; PaletteV
        MOV     R0,#0
        MOV     R1,#16
        MOV     R2,#0
        MOV     R3,R2
        LDR     R5,=&01010100
        MOV     R4,#2                   ; set palette, R4 becomes zero on return
5
        Push    "R0-R5,R9"
        SWI     XOS_CallAVector
        Pull    "R0-R5,R9"
        Pull    "R9",VS
        BVS     exit_setmode
        ADD     R0,R0,#1
        ADD     R2,R2,R5
        MOV     R3,R2
        CLRV                            ; clear overflow for R0>127
        CMP     R0,#256
        BNE     %BT5
        Pull    "R9"

        [ false
        B       set_grey_palette         ; update wimp palette
        ]

        [ false
; now set wimp palette with first 16 colours (! is this logical captain?)
        SUB     SP,SP,#80
        MOV     R1,SP
        SWI     XWimp_ReadPalette
        ; preserves border and pointer colours
        MOV     R0,#16
        LDR     R2,=&01010100
        MOV     R3,#0
5
        STR     R3,[R1],#4
        ADD     R3,R3,R2
        SUBS    R0,R0,#1
        BNE     %BT5
        MOV     R1,SP
        SWI     XWimp_SetPalette

        ]

        B       exit_setmodegreys


greys_16
        DCD     &10101000,&c0c0c000,&60606000,&20202000
        DCD     &e0e0e000,&40404000,&a0a0a000,&80808000
        ]

;----------------------------------------------------------------------------

; *IconSprites <filename>
; In:   R0 -> parameters
;       R1 = number of parameters (1)
; Out:  R0-R6 may be corrupted
; call Wimp_SpriteOp (11 = merge) to add sprites to the common sprite area
; tries "<filename>23" if hi-res mono, and/or "<filename>22" if 2x2 OS units

IconSprites_Code
        Push    "R7-R9,LR"
        LDR     wsptr,[R12]
;
      [ :LNOT: Medusa
        Push    "R0"
        MOV     R0,#ModHandReason_RMADesc
        SWI     XOS_Module
        MOV     R9,R3                   ; how much free RMA there was before merging
        Pull    "R0"
      ]
        MOV     R8,R0                   ; R8 -> original filename
        MOV     R5,R0                   ; R5 = position at which to insert system variable
01      LDRB    LR,[R0],#1              ; skip leading space
        TEQ     LR,#' '
        BEQ     %BT01
02      TEQ     LR,#'.'                 ; remember last '.' or ':'
        TEQNE   LR,#':'
        MOVEQ   R5,R0
        CMP     LR,#' '
        LDRHIB  LR,[R0],#1
        BHI     %BT02
        SUB     R7,R0,R8                ; length of original string incl terminator
        ADD     R7,R7,#IconThemeSysVarLen + 3
        BIC     R7,R7,#3                ; R7 = length to allocate for string with inserted system variable
        SUB     SP,SP,R7

        MOV     R0,R8
        MOV     R3,SP
03      LDRB    LR,[R0]                 ; skip leading spaces
        TEQ     LR,#' '
        ADDEQ   R0,R0,#1
        BEQ     %BT03
04      TEQ     R0,R5                   ; if at appropriate position
        BNE     %FT06
        ADR     R2,IconThemeSysVar
        MOV     R4,#IconThemeSysVarLen
05      LDRB    LR,[R2],#1              ; then insert system variable
        STRB    LR,[R3],#1
        SUBS    R4,R4,#1
        BNE     %BT05
06      LDRB    LR,[R0],#1              ; copy rest of string as is, including terminator
        STRB    LR,[R3],#1
        CMP     LR,#' '
        BHI     %BT04

        MOV     R3,SP                   ; R3 -> pathname with system variable inserted
01      LDRB    R5,romspr_suffix
        LDRB    R6,romspr_suffix+1
        SUB     R5,R5,#'0'
        SUB     R6,R6,#'0'
        SUB     sp,sp,#4
02
      [ SpritesA
        CMP     R5,R6
        LDREQB  R0,alphaspriteflag
        CMPEQ   R0,#255
        MOVEQ   R5,#'A'-'0'             ; Try alpha before square pixels
      ]
025
        ADD     R14,R5,R6,LSL #8
        ADD     R14,R14,#'0'
        ADD     R14,R14,#'0':SHL:8
        STR     R14,[sp]
        MOV     R0,sp
        MOV     R1,R3
        BL      getspritefname          ; R1 -> <filename><x><y><bpp>
        MOV     R2,R1                   ; R2 -> filename
;
        MOV     R0,#SpriteReason_MergeSpriteFile
        SWI     XWimp_SpriteOp
        BVC     %FT03

      [ SpritesA
        CMP     R5,#'A'-'0'
        MOVEQ   R5,R6
        BEQ     %BT025                  ; Try square pixels if alpha failed
      ]

        TEQ     R6,#3
        MOVEQ   R6,#2
        BEQ     %BT02                   ; after Sprites23, try Sprites22

        CMP     R5,R6
        MOVLO   R5,R5,LSL#1
        MOVHI   R6,R6,LSL#1
        BNE     %BT02                   ; after rectangular pixels, try next squarer version

      [ Sprites11
        TEQ     R5,#1
        MOVEQ   R5,#2
        MOVEQ   R6,#2
        BEQ     %BT02                   ; after Sprites11, try Sprites22
      ]

      [ SpritesA
        LDRB    R0,alphaspriteflag
        CMP     R0,#0
        BEQ     %FT029
        MOV     R14,#'A'
        STR     R14,[sp]
        MOV     R0,sp
        MOV     R1,R3
        BL      getspritefname
        MOV     R2,R1
        MOV     R0,#SpriteReason_MergeSpriteFile
        SWI     XWimp_SpriteOp          ; try just <filename>A before falling back to the original
        BVC     %FT03
029
      ]

        MOV     R2,R3                   ; R2 -> original filename
        MOV     R0,#SpriteReason_MergeSpriteFile
        SWI     XWimp_SpriteOp
03      ADD     sp,sp,#4

        TEQ     R3,R8                   ; were we trying with the system variable inserted?
        ADDNE   SP,SP,R7                ; yes, so junk stack frame
        BVC     %FT04
        BEQ     %FT95                   ; no, and an error, so give up
        MOV     R3,R8                   ; yes, and an error, so try again without the system variable
        B       %BT01
04

 [ windowsprite
  [ ThreeDPatch
	MOV	R0,#0
	BL	reset_all_tiling_sprites
  |
        MOV     R0,#-1
        STR     R0,tiling_sprite
  ]
 ]

      [ :LNOT: Medusa                   ; Medusa uses DA
        MOV     R0,#1                   ; The merge might have bumped up the RMA while both sets of sprites
        MOV     R1,#-&10000000          ; were loaded. Try and shrink RMA.
        SWI     XOS_ChangeDynamicArea   ; -256M will give "Unable to move memory"
        MOV     R0,#1
        MOV     R1,R9                   ; Put back the same amount of free space as on entry
        SWI     XOS_ChangeDynamicArea   ; May fail if APPSPACE is in use, that's ok.
        CLRV                            
      ]
95
        Pull    "R7-R9,PC"

IconThemeSysVar = "<Wimp$IconTheme>"
IconThemeSysVarLen * . - IconThemeSysVar
        ALIGN

;............................................................................

; In    R0 -> suffix to add to filename
;       R1 -> sprite filename
; Out   R1 -> <filename><suffix>
;       R2 -> start of suffix as added to filename

getspritefname
        Push    "R0,LR"

        ADRL    R2, path_buffer         ; watchdogerrtxt isn't big enough for long pathnames, and was getting
                                        ; overwritten by the new Service_SwitchingOutputToSprite handler

01      LDRB    R14,[R1],#1             ; skip leading spaces
        CMP     R14,#" "
        BEQ     %BT01
02      CMP     R14,#32                 ; stop on space or ctrl-char
        STRHIB  R14,[R2],#1
        LDRHIB  R14,[R1],#1
        BHI     %BT02

        MOV     R1,R2
        BL      copy0                   ; copy from R0 to R1

        ADRL    R1, path_buffer
        DebugS  xx,"getspritefname: ",R1

        Pull    "R0,PC"

;............................................................................

; Entry:  R0 = sprite reason code
;         all other regs except R1 set up as normal for OS_SpriteOp
; Exit:   operation performed on RAM / ROM sprite areas
; Error:  "Bad parameter passed to Wimp in R0" if attempt to write to sprites
;

SWIWimp_SpriteOp
;        MyEntry "SpriteOp"

        AND     R0,R0,#&FF              ; just in case!
        TEQ     R0,#SpriteReason_MergeSpriteFile
        BEQ     %FT01
        TEQ     R0,#SpriteReason_SetPointerShape
        BEQ     %FT02
        TEQ     R0,#99                  ; fast find
        BEQ     dospriteop
        CMP     R0,#SpriteReason_BadReasonCode
        BHS     err_badR0
;
        ADR     R1,spritebits           ; disallow all other write operations
        MOV     R14,R0,LSR #5
        LDR     R1,[R1,R14,LSL #2]
        AND     R14,R0,#31
        MOVS    R1,R1,LSL R14           ; top bit is now set/unset accordingly
        BMI     err_badR0

dospriteop
        MOV     R1,#1
        STR     R1,thisCBptr
        STR     R1,lengthflags
        STR     R2,spritename
        LDR     R1,list_at
        TEQ     R1,#0
        BEQ     dospriteopnext          ; no list yet.
        TEQ     R0,#36                  ; set pointer shape
        BEQ     dospriteopnext
        Push    "R2"                    ; needs preserving
        BL      getspriteaddr
        STRVC   R2,spritename
        Pull    "R2"
        MOVVC   R1,#0
        STRVC   R1,lengthflags          ; use pointer
        BVS     sprite_not_found
        TEQ     R0,#99                  ; fast sprite existence
        BEQ     ExitWimp
dospriteopnext
        TEQ     R0,#99
        MOVEQ   R0,#SpriteReason_ReadSpriteSize
        MOV     R1,#1                   ; incase daft routines expect it
        BL      wimp_SpriteOp
        STMIA   sp, {R1-R10}            ; return correct results to caller
        B       ExitWimp

01      BL      int_merge_sprites
        B       ExitWimp

02      TST     R3,#1:SHL:5             ; is it trying to set up the palette?
        MOVEQ   R3,#1                   ; don't program the border colour
        BLEQ    setmousepalette         ; palette defaults to central version
        MOV     R0,#SpriteReason_SetPointerShape
        LDMIA   sp,{R1-R7}
        B       dospriteop

spritebits   ;    0       8      16      24     31
        DCD     2_11100000011000111000000001110111
        DCD     2_11010010001011110000001001101101
        DCD     2_10111111111111111111111111111111
        ASSERT  SpriteReason_BadReasonCode < 96

sprite_not_found
        ADR     R0,SpriteDoesntExist
        BL      ErrorLookup
        B       ExitWimp

SpriteDoesntExist
        DCD     134
        DCB     "BadSprite",0
        ALIGN


;............................................................................

; Entry:  R2 --> sprite file name
;         [baseofsprites] = current RAM sprite area pointer
; Exit:   [baseofsprites] = new RAM sprite area pointer (area extended)

int_merge_sprites
        Push    "R1-R5,LR"              ; R2 on stack = filename ptr
;
        DebugS  spr,"File name is ",r2

        MOV     R1,R2
        MOV     R0,#OSFile_ReadInfo
        SWI     XOS_File                ; R4 = file length
        Debug   spr,"File size is ",r4
        Debug   spr,"Object type is ",r0
        TEQ     R0,#object_file         ; must be a file (NB doesn't affect V)
        MOVNE   R2,#object_nothing
        MOVNE   R0,#OSFile_MakeError    ; state which file is missing
        SWINE   XOS_File
        BVS     %FT98
;
        MOV     R2,R2,LSL # 12
        MOV     R2,R2,LSR # 20
        LDR     R14,=FileType_Squash
        TEQ     R2,R14
        BEQ     %FT99
;
        LDR     R2,baseofsprites

        MOVVC   R0,#ModHandReason_ExtendBlock
        MOVVC   R3,R4                   ; extend by enough to cover new file
        BLVC    allocatespritememory
        STRVC   R2,baseofsprites        ; do this now just in case !!!
      [ SpritePriority
        BVS     %FT06
        LDR     R1, preferredpool
        TEQ     R1, #0 ; preserves V
        STREQ   R2, baseofhisprites
        STRNE   R2, baseoflosprites
06
      ]

        DebugE  spr,"Extending sprite block"
      [ debugspr
        BVS     %FT55
        Debug   spr,"baseofsprites (1)  ",r2
55
      ]
;
        LDRVC   R14,[R2,#saEnd]
        ADDVC   R14,R14,R3
        STRVC   R14,[R2,#saEnd]

        [ debugnk
        ADD     R1,R14,R2
        SUB     R1,R1,#4
        Debug   nk,"End of sprite area",R1
        LDR     R0,[R1]
        STR     R0,[R1]
        MOV     R0,R1
        SWI     XOS_ValidateAddress
        BCC     %FT01
        Debug   nk,"Oh dear ",R1
        ]
01
        MOVVC   R1,R2
        LDRVC   R2,[sp,#1*4]            ; R2 --> file name
        MOVVC   R0,#SpriteReason_MergeSpriteFile
        ADDVC   R0,R0,#&100
      [ debugspr
        BVS     %FT55
        Debug   spr,"(1) r0 r1 r2  ",r0,r1,r2
55
      ]
        SWIVC   XOS_SpriteOp

        Debug   nk,"Returned from merge ",R0
;
        LDRVC   R14,[R1,#saFree]        ; compact area down now
        LDRVC   R0,[R1,#saEnd]
        STRVC   R14,[R1,#saEnd]
        SUBVC   R3,R14,R0               ; R3 = amount to change size by
        LDRVC   R2,baseofsprites
      [ debugspr
        BVS     %FT55
        Debug   spr,"(2) r0 r1 r14 r2  ",r0,r1,r14,r2
55
      ]
        MOVVC   R0,#ModHandReason_ExtendBlock
        BLVC    allocatespritememory
        STRVC   R2,baseofsprites
      [ SpritePriority
        BVS     %FT06
        LDR     R1, preferredpool
        TEQ     R1, #0 ; preserves V
        STREQ   R2, baseofhisprites
        STRNE   R2, baseoflosprites
06
      ]
      [ debugspr
        BVS     %FT55
        Debug   spr,"baseofsprites (2)  ",r2
55
      ]
;
        MOVVC   R1,#Service_WimpSpritesMoved
        LDRVC   R2,baseofromsprites     ; R2 -> ROM area
        LDRVC   R3,baseofsprites        ; R3 -> RAM area
        SWIVC   XOS_ServiceCall
;
        BLVC    freelist                ; mark sprite cache list as invalid
;
98
        Pull    "R1-R5,PC"

99
        MyXError        WimpBadSprites
        Pull    "R1-R5,PC"

        MakeErrorBlock  WimpBadSprites

;............................................................................

; Exit:  R0 --> common sprite area (ROM)
;        R1 --> common sprite area (RAM)

SWIWimp_BaseOfSprites
;        MyEntry "BaseOfSprites"

        LDR     R0,baseofromsprites
        LDR     R1,baseofsprites
        STR     R1,[sp,#0*4]            ; overwrite stacked value
        B       ExitWimp


;-----------------------------------------------------------------------------
; Initialisation - claim work area
;-----------------------------------------------------------------------------

WimpVarPath     DCB     "WindowManager$Path", 0
WimpDefPath     DCB     "Resources:$.Resources.Wimp."
                DCB     0
WimpVarTheme    DCB     "Wimp$IconTheme", 0
WimpDefTheme    DCB     UserIF :CC: "."
                DCB     0
                ALIGN

Init
        Push    "R0-R12,LR"

; open debugging file

      [ debug :LAND: :LNOT: hostvdu :LAND: :LNOT: pdebug_module
        Debug_Open "<Wimp$Debug>1"
      ]

; initialise WindowManager$Path if not already done

        ADR     R0, WimpVarPath
        MOV     R2, #-1
        MOV     R3, #0
        MOV     R4, #VarType_String     ; Do not expand, to bypass a bug in OS_ReadVarVal
        SWI     XOS_ReadVarVal          ; returns R2=0 if doesn't exist
        CMP     R2, #0                  ; clears V as well!

        ADREQ   R0, WimpVarPath
        ADREQ   R1, WimpDefPath
        MOVEQ   R2, #?WimpDefPath
        MOVEQ   R3, #0
        MOVEQ   R4, #VarType_String
        SWIEQ   XOS_SetVarVal
        BVS     exitinit1

; initialise Wimp$IconTheme to the build UserIF if not set by the user

        ADR     R0, WimpVarTheme
        MOV     R2, #-1
        MOV     R3, #0
        MOV     R4, #VarType_String     ; Do not expand, to bypass a bug in OS_ReadVarVal
        SWI     XOS_ReadVarVal          ; returns R2=0 if doesn't exist
        CMP     R2, #0                  ; clears V as well!

        ADREQ   R0, WimpVarTheme
        ADREQ   R1, WimpDefTheme
        MOVEQ   R2, #?WimpDefTheme
        MOVEQ   R3, #0
        MOVEQ   R4, #VarType_String
        SWIEQ   XOS_SetVarVal           ; Ignore error

; claim workspace

        LDR     R2,[R12]                ; load from private word
        CMP     R2,#0
        BNE     gotwork                 ; no need to reclaim block
;
        LDR     R3,=maxwork
        MOV     R0,#ModHandReason_Claim
        SWI     XOS_Module
        BVS     errcantclaim
        STR     R2,[R12]

; need to claim save area for when something else (eg. font manager) switches
; output.
        Push    "R0-R3"
        MOV     wsptr,R2

        [ DebugMemory
        ADRL    R0,memory_claims
        MOV     R2,#-1
        STR     R2,[R0,#4]
        STR     R2,[R0]
        MOV     R2,#0
        STRB    R2,reentrancyflag

        ]

        MOV     R0,#SpriteReason_ReadSaveAreaSize
        MOV     R2,#0
        SWI     XOS_SpriteOp                    ; get size of area
        MOVVC   R0,#ModHandReason_Claim
        BLVC    XROS_Module
        MOVVC   R0,#0
        STRVC   R0,[R2]
        MOVVS   R2,#0
        ADRL    R14,save_context
        STR     R2,[R14]
        Pull    "R0-R3"

gotwork
        MOV     wsptr,R2

        MOV     R0,#6
        MOV     R1,#0
        MOV     R2,#OSRSI6_IRQsema
        SWI     XOS_ReadSysInfo
        MOVVS   R2,#0
        CMP     R2,#0
        LDREQ   R2,=Legacy_IRQsema
        STR     R2,ptr_IRQsema
        MOV     R0,#6
        MOV     R2,#OSRSI6_DomainId
        SWI     XOS_ReadSysInfo
        MOVVS   R2,#0
        CMP     R2,#0
        LDREQ   R2,=Legacy_DomainId
        STR     R2,ptr_DomainId

        MOV     R1, #0
        STR     R1, messages            ; no messsages open, in case of error lookups
      [ DynamicAreaWCF
        BL      initwcfda
      ]
;
        BL      initptrs                ; also claims ChangeEnvironmentV
;
        SWI     XOS_ReadMemMapInfo      ; R0 = page size, R1 = number of pages
        MOV     R1,#DefaultNextSlot
        DivRem  R2,R1,R0,R14,norem      ; R2 = number of pages for 640k (or whatever)
        STR     R2,slotsize
;
 [ DontCheckModeOnInit
        MOV     r0, #-1
        STR     r0, currentmode
 |
        BL      read_current_configd_mode
 ]
;
        ; Read WimpFlags
        MOV     R0,#ReadCMOS
        MOV     R1,#WimpFlagsCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0
        STRB    R2,sysflags
;
        ; Read WimpDragDelay
        MOV     R0,#ReadCMOS
        MOV     R1,#WimpDragTimeCMOS
        SWI     XOS_Byte
        [ false
        EORVC   R0,R2,#default_drag_timelimit
        |
        ANDVC   R3, R2, #&0F
        EORVC   R3, R3, #default_drag_timelimit
        MOVVC   R1, #WimpDragMoveLimitCMOS
        SWIVC   XOS_Byte
        ANDVC   R4, R2, #1 :SHL: 0
        MOVVC   R0, R3, LSL R4
        TEQ     R4, #0 ; preserves V
        ADDNE   R0, R0, R0, LSL #2
        ]
        MOVVS   R0,#default_drag_timelimit
        ADD     R0,R0,R0,ASL #2        ; R0*5
        MOV     R0,R0,ASL #1           ; R0*10
        STR     R0,drag_timelimit
;
        ; Read WimpDoubleClickDelay
        MOV     R0,#ReadCMOS
        MOV     R1,#WimpDoubleClickTimeCMOS
        SWI     XOS_Byte
        [ false
        EORVC   R0,R2,#default_doubleclick_timelimit
        |
        ANDVC   R3, R2, #&0F
        EORVC   R3, R3, #default_doubleclick_timelimit
        MOVVC   R1, #WimpDoubleClickMoveLimitCMOS
        SWIVC   XOS_Byte
        ANDVC   R4, R2, #1 :SHL: 0
        MOVVC   R0, R3, LSL R4
        TEQ     R4, #0 ; preserves V
        ADDNE   R0, R0, R0, LSL #2
        ]
        MOVVS   R0,#default_doubleclick_timelimit
        ADD     R0,R0,R0,ASL #2        ; R0*5
        MOV     R0,R0,ASL #1           ; R0*10
        STR     R0,doubleclick_timelimit
;
        ; Read WimpDragMove
        MOV     R0,#ReadCMOS
        MOV     R1,#WimpDragMoveLimitCMOS
        SWI     XOS_Byte
        [ true
        ANDVC   R2, R2, #&7C
        ]
        EORVC   R0,R2,#default_drag_movelimit
        MOVVS   R0,#default_drag_movelimit
        STRB    R0,drag_movelimit
;
        ; Read WimpDoubleClickMove
        MOV     R0,#ReadCMOS
        MOV     R1,#WimpDoubleClickMoveLimitCMOS
        SWI     XOS_Byte
        [ true
        ANDVC   R2, R2, #&7C
        ]
        EORVC   R0,R2,#default_doubleclick_movelimit
        MOVVS   R0,#default_doubleclick_movelimit
        STRB    R0,doubleclick_movelimit
;
        ; Read WimpAutoMenuDelay
        MOV     R0,#ReadCMOS
        MOV     R1,#WimpAutoSubMenuTimeCMOS
        SWI     XOS_Byte
        [ false
        MOVVS   R0,#0
        ADDVC   R0,R2,R2,ASL #2        ; R0*5
        MOVVC   R0,R0,ASL #1           ; R0*10
        |
        ANDVC   R0, R2, #&0F
        EORVC   R0, R0, #default_automenudelay
        TST     R2, #1 :SHL: 4 ; preserves V
        ADDNE   R0, R0, R0, LSL #2
        MOVNE   R0, R0, LSL #1
        MOVVS   R0, #default_automenudelay
        ADD     R0, R0, R0, LSL #2
        MOV     R0, R0, LSL #1
        ]
        STR     R0,automenu_timelimit
;
        ; Read WimpMenuDragDelay
        MOV     R0,#ReadCMOS
        MOV     R1,#WimpMenuDragDelayCMOS
        SWI     XOS_Byte
        [ false
        MOVVS   R0,#0
        ADDVC   R0,R2,R2,ASL #2        ; R0*5
        MOVVC   R0,R0,ASL #1           ; R0*10
        |
        ANDVC   R0, R2, #&0F
        EORVC   R0, R0, #default_menudragdelay
        TST     R2, #1 :SHL: 4 ; preserves V
        ADDNE   R0, R0, R0, LSL #2
        MOVNE   R0, R0, LSL #1
        MOVVS   R0, #default_menudragdelay
        ADD     R0, R0, R0, LSL #2
        MOV     R0, R0, LSL #1
        ]
        STR     R0,menudragdelay
;
        ; Read WimpIconBarSpeed
        ADR     R3, iconbarlogtable
        MOV     R0, #ReadCMOS
        MOV     R1, #WimpAutoSubMenuTimeCMOS
        SWI     XOS_Byte
        MOVVC   R2, R2, LSR #5
        EORVC   R2, r2, #default_iconbarspeed
        MOVVS   R2, #default_iconbarspeed
        LDR     R0, [R3, R2, LSL#2]
        STR     R0, iconbar_scroll_speed
;
        ; Read WimpIconBarAcceleration
        MOV     R0, #ReadCMOS
        MOV     R1, #WimpMenuDragDelayCMOS
        SWI     XOS_Byte
        MOVVC   R2, R2, LSR #5
        EORVC   R2, r2, #default_iconbaraccel
        MOVVS   R2, #default_iconbaraccel
        LDR     R0, [R3, R2, LSL#2]
        STR     R0, iconbar_scroll_accel
;
        ; Read WimpSpritePrecedence
      [ SpritePriority
        MOV     R0, #ReadCMOS
        MOV     R1, #DesktopFeaturesCMOS
        SWI     XOS_Byte
        TST     R2, #1 :SHL: 5 ; preserves V
        MOVEQ   R0, #0
        MOVNE   R0, #1
        MOVVS   R0, #0
        STR     R0, preferredpool
      ]
;
        ; ReadWimpButtonType
      [ BounceClose
        MOV     R0, #ReadCMOS
        MOV     R1, #DesktopFeaturesCMOS
        SWI     XOS_Byte
        TST     R2, #1 :SHL: 6 ; preserves V
        MOVEQ   R0, #0
        MOVNE   R0, #1
        MOVVS   R0, #0
        STRB    R0, buttontype
      ]
;
        ; Read WimpIconiseButton
      [ IconiseButton
        MOV     R0, #ReadCMOS
        MOV     R1, #WimpDragMoveLimitCMOS
        SWI     XOS_Byte
        TST     R2, #1 :SHL: 7 ; preserves V
        MOVEQ   R0, #0
        MOVNE   R0, #1
        MOVVS   R0, #0
        STRB    R0, iconisebutton
      ]
;
        ; ReadWimpStickyEdges
      [ StickyEdges
        MOV     R0, #ReadCMOS
        MOV     R1, #DesktopFeaturesCMOS
        SWI     XOS_Byte
        TST     R2, #1 :SHL: 6 ; preserves V
        MOVEQ   R0, #0
        MOVNE   R0, #1
        MOVVS   R0, #0
        STRB    R0, stickyedges
      ]
;
        ; Read WimpAutoFrontIconBar
      [ PoppingIconBar
        MOV     R0, #ReadCMOS
        MOV     R1, #WimpDoubleClickMoveLimitCMOS
        SWI     XOS_Byte
        TST     R2, #1 :SHL: 7 ;preserves V
        MOVEQ   R0, #1
        MOVNE   R0, #0
        MOVVS   R0, #1
        STRB    R0, popiconbar
;
        ; Read WimpAutoFrontDelay
        MOV     R0, #ReadCMOS
        MOV     R1, #WimpDoubleClickTimeCMOS
        SWI     XOS_Byte
        MOVVC   R3, R2, LSR #4
        EORVC   R3, R3, #default_autofrontdelay
        MOVVC   R1, #WimpDoubleClickMoveLimitCMOS
        SWIVC   XOS_Byte
        TST     R2, #1 :SHL: 1 ;preserves V
        MOVEQ   R0, R3
        MOVNE   R0, R3, LSL #1
        ADDNE   R0, R0, R0, LSL #2
        MOVVS   R0, #default_autofrontdelay
        ADD     R0, R0, R0, LSL #2
        MOV     R0, R0, LSL #1
        STR     R0, popiconbar_pause
      ]
;
        ; Read WimpAutoScrollDelay
      [ Autoscr
        MOV     R0, #ReadCMOS
        MOV     R1, #WimpDragTimeCMOS
        SWI     XOS_Byte
        MOVVC   R3, R2, LSR #4
        EORVC   R3, R3, #default_autoscrolldelay
        MOVVC   R1, #WimpDragMoveLimitCMOS
        SWIVC   XOS_Byte
        TST     R2, #1 :SHL: 1 ;preserves V
        MOVEQ   R0, R3
        MOVNE   R0, R3, LSL #1
        ADDNE   R0, R0, R0, LSL #2
        MOVVS   R0, #default_autofrontdelay
        STRB    R0, autoscr_default_pause ; not *10
      ]
;
        ; Read WimpClickSubmenu
      [ ClickSubmenus
        MOV     R0, #ReadCMOS
        MOV     R1, #Misc1CMOS
        SWI     XOS_Byte
        TST     R2, #1 :SHL: 0 ; preserves V
        MOVEQ   R0, #0
        MOVNE   R0, #1
        MOVVS   R0, #0
        STRB    R0, clicksubmenuenable
      ]
;
      [ ThreeDPatch
	; set up the 3dpatch configuration
	MOV	R0,#ThreeDFlags_Default
	STR	R0,ThreeDFlags
	LDR	R0,=rgb_white
	STR	R0,truemenuborderfacecolour
	STR	R0,truewindowborderfacecolour
	LDR	R0,=rgb_midlightgrey
	STR	r0,truemenuborderoppcolour
	LDR	R0,=rgb_middarkgrey
	STR	r0,truewindowborderoppcolour
	LDR	R0,=rgb_black
	STR	r0,truewindowoutlinecolour
      [ true
        MOV     R0,#arrowIconWidth_No3D
      |
        MOV     R0,#arrowIconWidth_3D
      ]
        STRB    R0,arrowIconWidth
      ]
;
        ADRL    R14,paltable            ; initialise palette
        ADR     R11,emergencypalette
        LDMIA   R11!,{R1-R10}
        STMIA   R14!,{R1-R10}
        LDMIA   R11,{R1-R10}
        STMIA   R14,{R1-R10}
;
        BL      initphyspalmap          ; initialise bits for colour mappings
;
        MOV     R0,#ModHandReason_Claim
        MOV     R3,#SpriteAreaCBsize    ; 16, I believe!
        BL      allocatespritememory
        MOVVS   R2,#nullptr
        STR     R2,baseofsprites        ; NB this is null if error occurs
      [ SpritePriority
        LDR     R1, preferredpool
        TEQ     R1, #0 ; preserves V
        STREQ   R2, baseofhisprites
        STRNE   R2, baseoflosprites
      ]
        STRVC   R3,[R2,#saEnd]
        STRVC   R3,[R2,#saFirst]
        STRVC   R3,[R2,#saFree]
        MOVVC   R14,#0                  ; no sprites defined
        STRVC   R14,[R2,#saNumber]
;
        ADRVC   R0,str_wimpcom
        ADRVC   R1,CommandWindow_var
        MOVVC   R2,#CommandWindow_varsize
        MOVVC   R3,#0
        MOVVC   R4,#VarType_Code
        SWIVC   XOS_SetVarVal
;
        BL      defaultfilters          ; reset the filter handlers + broadcast service
;
        MOV     R0,#0
        STR     R0,automenu_inactivetimeout
;
        STRB    R0,selecttable_crit     ; don't mind losing it on an invalidate cache service call
        STRB    R0,tsprite_needsregen   ; doesn't because there isn't one

        STR     R0,pixtable_at          ; no pixel translation table
        STR     R0,pixtable_size

        STR     R0,tpixtable_at         ; no tool pixel translation table
        STR     R0,tpixtable_size
        [ ToolTables
        STR     R0,ttt_activeset_at     ; no custom translation tables
        STR     R0,ttt_activeset_size
        ]
        STR     R0,list_at
        STR     R0,list_size            ; mark to indicate now list present
        STR     R0,filehandle
        STR     R0,fileaddress          ; reset the file address / handle (faults on template load!)
        STR     R0,tool_list
        STR     R0,tool_area
        STR     R0,tool_transtable      ; no tool sprites / tool sprites list
        STRB    R0,errorbox_open        ; the error box is not displayed
        STRB    R0,iconbar_needs_rs     ; check iconbar icon sizes
        [ NewErrorSystem
        STR     R0,watchdogcodew
        ]
        ADRL    R14,tool_list_backup
        STR     R0,[R14]
;        ADRL    R14,wimpmodebefore
;        STR     R0,[R14]
        ADRL    R14,greys_mode
        STR     R0,[R14]                ; splats misc
        [ NewErrorSystem
        STR     R0,watchdogarea         ; 'watchdog' isn't active
        ]
        [ StretchErrorText
        STR     R0,linecount
        ]
        STR     R0,wimpswiintercept
        STR     R0,plotsprCB
	[ PoppingIconBar
	STR	R0,iconbar_pop_state
	]
        [ TrueIcon3
        MOV     R0, #1:SHL:2
        STRB    R0, tinted_enable
        MOV     R0, #0
        STRB    R0, tinted_window
        STRB    R0, tinted_tool
        ]
        [ windowsprite
	 [ ThreeDPatch						
	MOV	R0,#0                   ; initialise all the tile sprite info blocks
	BL      reset_all_tiling_sprites
         |
        MOV     R0,#-1
        STR     R0,tiling_sprite        ; no tile sprite
        MOV     R0,#0
        STR     R0,tile_pixtable
         ]
        ]
        STRB    R0,checkedcolourmapping
        STR     R0,inversecolourmap
;
        BL      freetoolarea            ; tidy the tool area
;
        BL      declareresourcefsfiles  ; trap service call to pick them up
        BL      recalcmodevars
;
exitinit1
        STRVS   R0,[sp]                 ; bodge stack if error
        Pull    "R0-R12,PC"
        LTORG

errcantclaim
        MyXError WimpNoClaim

        STR     R0,[sp]                ; bodge stack on error
        Pull    "R0-R12,PC"
        MakeErrorBlock  WimpNoClaim

iconbarlogtable
        DCD     0, 20, 50, 100, 200, 500, 1000, 2000, -1

 [ SpritesA
checkalphasprites
        Entry   "R0-R2"
        ; Check if the kernel + SpriteExtend understand alpha masked sprites
        ; If they do, assume everything else is OK and that we can render them
        LDR     R0, testalphaspritemode
        MOV     R1, #VduExt_NColour
        SWI     XOS_ReadModeVariable
        CMP     R2, #1
        MOVNE   R0, #0
        BNE     %FT50
        LDR     R0, =SpriteReason_CheckSpriteArea+512
        ADR     R1, testalphaspritearea
        ADR     R2, testalphasprite
        SWI     XOS_SpriteOp
        MOVVS   R0, #0
        MOVVC   R0, #255
50
        STRB    R0, alphaspriteflag
        EXIT

testalphaspritearea
        DCD     &44
        DCD     1
        DCD     &10
        DCD     &44
testalphasprite
        DCD     &34
        DCD     &61 ; 'a'
        DCD     0
        DCD     0
        DCD     0   ; width
        DCD     0   ; height
        DCD     0   ; left bit
        DCD     0   ; right bit
        DCD     &2C ; image offset
        DCD     &30 ; mask offset
testalphaspritemode
        DCD     &80000001+(90<<1)+(90<<14)+(1<<27) ; 1bpp + alpha mask
        ; Image & mask data can just be any old garbage
 ]

;.................................................................................

; Declare resource files to ResourceFS
; This causes a Service_ResourceFSStarted, which is then trapped

fontinstall = "%FontInstall", 0
        ALIGN

declareresourcefsfiles
        Push    "R0,LR"

        ADRL    R0,resourcefsfiles
        SWI     XResourceFS_RegisterFiles   ; ignore errors
        ADR     R0, fontinstall
        SWI     XOS_CLI                     ; ensure WIMPSymbol has been seen
        BL      getromsprites

        CLRV
        Pull    "R0,PC"


;.................................................................................
;
; Entry:  R3 = amount of memory to claim
; Exit:   R2 --> new block
;         bodgeblk is thrown away if present.

claimblock
        Push    "LR"
        MOV     R0,#ModHandReason_Claim
        BL     XROS_Module
        DebugE  rma,"Claim failed:"
        Pull    "PC"

claim
        Push    "LR"
        BL      release                 ; also sets R2 = wsptr
        SWI     XOS_Claim
        Pull    "PC"

release
        EntryS  "R0-R1"
01
        MOV     R2,wsptr
        SWI     XOS_Release             ; release until bored
        BVC     %BT01
        EXITS

;.................................................................................

str_wimpcom     DCB     "Wimp$State", 0
                ALIGN

emergencypalette
        GET     !Palette.s

;.................................................................................

Die
        Push    "R0-R3,R12,LR"
        LDR     wsptr,[R12]
;
        LDR     R14,taskcount

        Debug   die,"WimpDie: taskcount",R14

        TEQ     R14,#0                  ; Any tasks?
        MyXError WimpCantKill,NE        ; Yes then error
        ADDVS   SP,SP,#4                ; And drop R0
        Pull    "R1-R3,R12,PC",VS
;
        Debug   die,"Deregister resources"

        ADRL    R0,resourcefsfiles
        SWI     XResourceFS_DeregisterFiles ; ignore errors
;
        BL      deallocateptrs          ; doesn't deallocate sprites
                                        ; does deallocate ALL windows

    [ :LNOT: KernelLocksFreePool
        BL      resetdynamic
    ]
    [ DynamicAreaWCF
        BL      destroywcfda
    ]

;
        MOV     R0,#ModHandReason_Free
        LDR     R2,baseofsprites
        BL      allocatespritememory         ; release the RAM sprite pool
;
        BL      freetoolarea
;
; Don't try freeing the command and error windows, its already happened.
;
        MOV     R0,#ChangeEnvironmentV
        ADRL    R1,ChangeEnvCode
        BL      release
;
        ADR     R0,str_wimpcom
        ADR     R1,CommandWindow_var
        MOV     R2,#-1
        MOV     R3,#0
        MOV     R4,#VarType_Code        ; must use this to destroy code vars
        SWI     XOS_SetVarVal
;
        BL      LoseMessages            ; just incase messages still open (unlikely)
;
        ADRL    R0,svc_callback
        MOV     R1,WsPtr
        SWI     XOS_RemoveCallBack      ; remove possible callback routine (may have been granted!)
;

        Debug   opn,"---- Debug closing down ----"

        Debug_Close

        CLRV                            ; no errors allowed here!
        Pull    "R0-R3,R12,PC"

        MakeErrorBlock WimpCantKill

;;-----------------------------------------------------------------------------
;; Command Window code variable
;;-----------------------------------------------------------------------------

CommandWindow_var
        MOV     PC,LR                   ; entry point for write op
        Push    "LR"                    ; entry point for read op

        MOV     R0,#WimpSysInfo_DesktopState
        SWI     XWimp_ReadSysInfo
        Pull    "PC",VS

        CMP     R0,#0                   ; R0=0 => "command" state

        ADREQ   R0,str_commands
        ADRNE   R0,str_desktop

        LDRB    R2,[R0],#1
        Pull    "PC"

str_commands    DCB     ?str_commands2
str_commands2   DCB     "commands"
str_desktop     DCB     ?str_desktop2
str_desktop2    DCB     "desktop"
                ALIGN

CommandWindow_varsize   *       . - CommandWindow_var

;;----------------------------------------------------------------------------
;; Neil's debugging routines
;;----------------------------------------------------------------------------

      [ debug
        InsertNDRDebugRoutines
      ]

        LTORG


;;-----------------------------------------------------------------------------
;; Service call handling
;;-----------------------------------------------------------------------------

ServiceTable
        DCD     0                               ; flags word
        DCD     Service2 - Module_BaseAddr
        [ :LNOT: UseAMBControl
        DCD     Service_Memory                  ; &11   ;
        ]                                               ;
        DCD     Service_Reset                   ; &27   ;
        DCD     Service_NewApplication          ; &2A   ;
        DCD     Service_ModeChange              ; &46   ;
        DCD     Service_MemoryMoved             ; &4E   ; must be in ascending order
        DCD     Service_ResourceFSStarted       ; &59   ;
        DCD     Service_ResourceFSDying         ; &5A   ;
        DCD     Service_ResourceFSStarting      ; &60   ;
        [ :LNOT: Medusa
        DCD     Service_ValidateAddress         ; &6D   ;
        ]
        [ SwitchingToSprite
        DCD     Service_SwitchingOutputToSprite ; &72   ;
        ]
        DCD     Service_InvalidateCache         ; &82   ;
        DCD     Service_ModeChanging            ; &89   ;
        [ Medusa :LAND: :LNOT: UseAMBControl            ;
        DCD     Service_PagesSafe               ; &8F   ;
        ]
        DCD     Service_ModeFileChanged         ; &94   ;
        DCD     0                               ; terminator

        DCD     ServiceTable - Module_BaseAddr
Service
        MOV     R0, R0                          ; flag service table to aware kernels

        ; Quick reject code for old kernels
        [ :LNOT: UseAMBControl
        TEQ     R1, #Service_Memory
        TEQNE   R1, #Service_Reset
        |
        TEQ     R1, #Service_Reset
        ]
        TEQNE   R1, #Service_NewApplication
        TEQNE   R1, #Service_ModeChange
        TEQNE   R1, #Service_MemoryMoved
        TEQNE   R1, #Service_ResourceFSStarted
        TEQNE   R1, #Service_ResourceFSDying
        TEQNE   R1, #Service_ResourceFSStarting
        [ :LNOT: Medusa
        TEQNE   R1, #Service_ValidateAddress
        ]
        [ SwitchingToSprite
        TEQNE   R1, #Service_SwitchingOutputToSprite
        ]
        TEQNE   R1, #Service_InvalidateCache
        TEQNE   R1, #Service_ModeChanging
        [ Medusa :LAND: :LNOT: UseAMBControl
        TEQNE   R1, #Service_PagesSafe
        ]
        TEQNE   R1, #Service_ModeFileChanged
        MOVNE   PC, LR

Service2
        LDR     wsptr,[R12]
        Debug   sv,"Wimp has received service call",R1
;

        [ debugnk
        TEQ     R1,#&68
        BNE     %FT01
        Push    "R0,lr"
        TraceS  nk,R2
        MOV     R0,#10
        BL      trace_char
        Pull    "R0,lr"
01
        TEQ     R1,#6
        BNE     %FT01
        Push    "R0,lr"
        LDR     lr,[R0]
        Debug   nk,"Error Number ",lr
        ADD     lr,R0,#4
        TraceS  nk,lr
        MOV     R0,#10
        BL      trace_char
        Pull    "R0,lr"
01
        ]
      [ debugvalid
        TEQ     R1,#Service_ValidateAddress
        BNE     %FT01
        Debug   valid,"Service validate address: r2,r3",r2,r3
01
      ]


      [ :LNOT: Medusa
        TEQ     R1,#Service_ValidateAddress
        BEQ     ValidateAddress
      ]
        TEQ     R1,#Service_NewApplication
        BEQ     newapplication

    [ :LNOT: UseAMBControl                      ; not our responsibility any more!
        TEQ     R1,#Service_Memory
        BEQ     servicememory
    ]
        TEQ     R1,#Service_MemoryMoved
        BEQ     servicememorymoved
      [ Medusa :LAND: :LNOT: UseAMBControl
        TEQ     R1,#Service_PagesSafe
        BEQ     servicepagessafe                ; in wimp08, screen resize etc.
      ]

      [ SwitchingToSprite
        TEQ     R1, #Service_SwitchingOutputToSprite
        BEQ     switchingtosprite
      ]
        TEQ     R1,#Service_ModeChange
        BEQ     recalcmodevars
        TEQ     R1,#Service_ResourceFSStarting  ; redeclare resource files
        BEQ     serviceresourcefsstarting
        TEQ     R1,#Service_ResourceFSStarted   ; re-link to sprite file
        BEQ     getromsprites
        TEQ     R1,#Service_ResourceFSDying
        BEQ     loseromsprites
        TEQ     R1,#Service_InvalidateCache     ; ColourTrans changed palette
        BEQ     invalidatecache
        TEQ     R1,#Service_ModeChanging
        BEQ     releasewrchvpremodechange
        TEQ     R1, #Service_ModeFileChanged
        BEQ     servicemodefilechanged
        TEQ     R1,#Service_Reset
        MOVNE   PC,LR

        Push    "LR"                    ; called on Service_Reset
      [ Medusa :LAND: :LNOT: DontCheckModeOnInit
        ; Reset currentmode on Service_Reset
        ; This allows us to get the correct mode in the case of a GraphicsV
        ; driver overriding the result of OS_ReadSysInfo 1 (as the driver
        ; probably wasn't initialised at the time we first read the mode)
        BL      read_current_configd_mode
      ]
        BL      deallocateptrs
        BL      initptrs                ; re-initialise window stack etc.
        BL      defaultfilters          ; re-register the filter routines
        Pull    "PC"

        [ :LNOT: Medusa
ValidateAddress
        Debug   valid,"Validate address ",r2,r3
        Push    "LR"
        LDRB    r14,memoryOK                            ; BUGFIX: NRaine 6-Aug-96 (should be unconditional)
        TST     r14,#mem_claimed
        Pull    "PC",EQ
        LDR     r14,freepoolbase
        Debug   valid,"First address is",r14
        CMP     r2,r14
        Pull    "PC",LO
        LDR     r14,orig_applicationspacesize
        Debug   valid,"Last address is ",r14
        CMP     r3,r14
        Pull    "PC",HS
        MOV     r1,#0
        Pull    "PC"
        ]

; ResourceFS has been reloaded - redeclare resource files
; In    R2 -> address to call
;       R3 -> workspace for ResourceFS module

serviceresourcefsstarting
        Push    "R0,LR"
        ADRL    R0,resourcefsfiles
        MOV     LR,PC                   ; LR -> return address
        MOV     PC,R2                   ; R2 -> address to call
        Pull    "R0,PC"

; A new MDF was loaded, this might have improved the kernel's idea
; of what the configured 'auto' mode achievable is, recache currentmode

servicemodefilechanged
        Push    "LR"
        LDR     LR,taskcount
        TEQ     LR,#0                   ; but only if we're outside the desktop
        BLEQ    read_current_configd_mode
        Pull    "PC"

; try to locate ROM sprite area - if not found, refuse to start up!
; this MUST be in Resources:, as we need to use it directly

getromsprites
        Push    "R0-R6,LR"
;
        LDR     R0,currentmode
        SWI     XOS_CheckModeValid              ; get the REAL mode number!
        CMP     R0,#-1                  ; if mode does not exist,
        MOVEQ   R0,R1                   ; try to use substitute mode
        CMP     R0,#-2                  ; if R1 = -2, we're stuck!
        LDREQ   R0,currentmode          ; (just give up and use the original)
;
        MOV     R4,#1

        MOV     R1,#VduExt_XEigFactor
        SWI     XOS_ReadModeVariable
        MOV     R5,R4,LSL R2                    ; R5 = char 0 - '0'

        MOV     R1,#VduExt_YEigFactor
        SWI     XOS_ReadModeVariable
        MOV     R6,R4,LSL R2                    ; R6 = char 1 - '0'

	MOV	R1,#VduExt_Log2BPP
	SWI	XOS_ReadModeVariable

        TEQ     R5,#2  				; 2x2 OS unit, 1bpp
        TEQEQ   R6,#2
        TEQEQ   R2,#0
        MOVEQ   R6,#3

      [ :LNOT: Sprites11
        TEQ     R5,#1
        TEQNE   R6,#1
        MOVEQ   R5,#2
        MOVEQ   R6,#2                           ; '1y' or 'x1' -> '22'
      ]

      [ SpritesA
        BL      checkalphasprites
        TEQ     R5,#2
        TEQEQ   R6,#3                           
        MOVEQ   R0,#0
        STREQB  R0,alphaspriteflag              ; Completely ignore alpha sprites in mode 23
      ]

        ADD     R14,R5,R6,LSL #8
        ADD     R14,R14,#'0'
        ADD     R14,R14,#'0':SHL:8

        ASSERT  ((:INDEX:romspr_suffix) :AND: 3) = 0
        STR     R14,romspr_suffix
;
        SUB     sp,sp,#4
01
      [ SpritesA
        CMP     R5,R6
        LDREQB  R0,alphaspriteflag
        CMPEQ   R0,#255
        MOVEQ   R5,#'A'-'0'             ; Try alpha before square pixels
      ]
02      ADD     R14,R5,R6,LSL #8
        ADD     R14,R14,#'0'
        ADD     R14,R14,#'0':SHL:8
        STR     R14,[sp]
        MOV     R0,sp

        ADR     R1,spritesfname
        BL      getspritefname          ; R1 -> <filename><x><y><bpp>
                                        ; R2 -> terminator
        MOV     R0,#OSFind_ReadFile
        SWI     XOS_Find
;
        BVC     %FT04

      [ SpritesA
        CMP     R5,#'A'-'0'
        MOVEQ   R5,R6
        BEQ     %BT02                   ; Try square pixels if alpha failed
      ]

        TEQ     R6,#3
        MOVEQ   R6,#2
        BEQ     %BT01                   ; after Sprites23, try Sprites22

        CMP     R5,R6
        MOVLO   R5,R5,LSL#1
        MOVHI   R6,R6,LSL#1
        BNE     %BT01                   ; after rectangular pixels, try next squarer version

      [ Sprites11
        TEQ     R5,#1
        MOVEQ   R5,#2
        MOVEQ   R6,#2
        BEQ     %BT01                   ; after Sprites11, try Sprites22
      ]

      [ SpritesA
        LDRB    R0,alphaspriteflag
        CMP     R0,#0
        BEQ     %FT03
        MOV     R14,#'A'
        STR     R14,[sp]
        MOV     R0,sp
        ADR     R1,spritesfname
        BL      getspritefname
        MOV     R0,#OSFind_ReadFile
        SWI     XOS_Find                ; try just <filename>A before falling back to the original
        BVC     %FT04
03
      ]

        ADR     R1,spritesfname         ; R1 -> original filename
        MOV     R0,#OSFind_ReadFile     ; try again!
        SWI     XOS_Find
04      ADD     sp,sp,#4
        BVS     %FT99                   ; error!
;
        MOV     R3,R0                   ; save external file handle
;
        MOV     R0,#FSControl_ReadFSHandle
        MOV     R1,R3
        SWI     XOS_FSControl
;
        AND     R2,R2,#&FF
        TEQ     R2,#fsnumber_resourcefs
      [ SpritePriority
        BNE     %FT06
        SUB     R2,R1,#4                ; R2 -> sprite area (including size)
        STR     R2,baseofromsprites
        LDR     R1, preferredpool
        TEQ     R1, #0 ; preserves V
        STREQ   R2, baseoflosprites
        STRNE   R2, baseofhisprites
06
      |
        SUBEQ   R2,R1,#4                ; R2 -> sprite area (including size)
        STREQ   R2,baseofromsprites
      ]
;
        MOV     R0,#0
        MOV     R1,R3
        SWI     XOS_Find                ; close file
99
        BLVS    loseromsprites          ; don't return error - just lose sprites
        CLRV
        Pull    "R0-R6,PC"

spritesfname    DCB     "WindowManager:Sprites", 0
                ALIGN

loseromsprites
        Push    "R1,LR"
        Debug   ub,"lose ROM sprites"
        ADRL    R14,romsprites
        STR     R14,baseofromsprites
      [ SpritePriority
        LDR     R1, preferredpool
        TEQ     R1, #0 ; preserves V
        STREQ   R14, baseoflosprites
        STRNE   R14, baseofhisprites
      ]
        Pull    "R1,PC"

  [ SwitchingToSprite
; Service_SwitchingOutputToSprite: cache limited graphics parameters

switchingtosprite
        Entry
        STR     R4, switchtospr_current     ; remember where output is switched to now
        TEQ     R4, #0                      ; if switching to screen
        BLEQ    switchingtosprite_recache   ; then make sure parameters are correct
        EXIT

switchingtosprite_recache
; recaches graphics parameters iff switchtospr_correctfor <> switchtospr_current
        Entry   "R0,R5-R6"
        LDR     R0, switchtospr_current
        LDR     R14, switchtospr_correctfor
        TEQ     R0, R14
        EXIT    EQ
        STR     R0, switchtospr_correctfor
        BL      readvduvars2            ; including new screen/sprite size etc.
        BLVC    calcborders             ; to set up dx, dy
        EXIT
  ]

; Service_ModeChange: cache new graphics parameters

recalcmodevars
        Push    "LR"
        BL      readvduvars2            ; including new screen size etc.
        BLVC    calcborders

        Push    R0
        ADRL    R0,inverselookup
        MOV     LR,#-1
        STR     LR,[R0]                 ; force recache
        [ windowsprite
	 [ ThreeDPatch
	MOV	R0,#0
	BL	reset_all_tiling_sprites
	 |
        STR     lr,tiling_sprite        ; force re cache
         ]
        ]
        Pull    R0

        [ false
        ADRL    R14,greys_mode
        LDR     R14,[R14]
        TEQ     R14,#0
        BLNE    recalc_greys_palette
        ]
        Pull    "PC"

; Service_ModeChanging: get off wrchv if necessary

releasewrchvpremodechange
        Push    "LR"
; medusa may require the write character vector to be reset.

        LDR     R14,commandflag
        TST     R14,#cf_suspended
        Pull    "PC",NE

        TEQ     R14,#cf_pending
        Pull    "PC",NE

        Push    "R0-R2"
        MOV     R0,#WrchV               ; get off the vector now!
        ADRL    R1,mywrch
        MOV     R2,wsptr
        SWI     XOS_Release

        MOV     R14,#cf_active
        STR     R14,commandflag

        Pull    "R0-R2,PC"


; Service_InvalidateCache: Mark all cached palette data as invalid

invalidatecache
        Push    "R0,R2,LR"
        LDRB    R2,selecttable_crit     ; avoid discarding the table when we know
        CMP     R2,#0                   ; that it is still valid
        Pull    "R0,R2,PC", NE

        LDR     R2,pixtable_at
        CMP     R2,#0                   ; has a pixtable been setup?
        MOVNE   R0,#ModHandReason_Free
        BLNE    XROS_Module             ; attempt to release - ignore errors

        MOV     R2,#0
        STR     R2,pixtable_at          ; mark the pixtable as being zapped!

        MOV     R2,#-1                  ; and the PixTrans mode
        STR     R2,sprite_lastmode

      [ ThreeDPatch
; MB - must add invalidating of new tile pixel tables here
      |
        LDR     R2,tile_temptab
        ORR     R2,R2,#1
        STR     R2,tile_temptab
      ]

        LDR     R2,tpixtable_at
        CMP     R2,#0                   ; has a tool pixtable been setup?
        MOVNE   R0,#ModHandReason_Free
        BLNE    XROS_Module             ; attempt to release - ignore errors

        MOV     R2,#0
        STR     R2,tpixtable_at         ; mark the tool pixtable as being zapped!
        STR     R2,tool_transtable

        MOV     R2,#-1                  ; and the tool PixTrans mode
        STR     R2,tsprite_lastmode

        STRB    R2,tsprite_needsregen   ; re-calcuate border based information

        Pull    "R0,R2,PC"

;
; Entry:  R2 = new CAO pointer
; Exit:   set flag to indicate whether application uses absolute w/s
;         NB: BASIC looks like a module, but uses application workspace
;

newapplication
        Push    "R0-R3,LR"
;
        Debuga  task1,"New CAO pointer =",R2
;
        MOV     R14,#0                  ; reset when application is run
        STR     R14,handlerword
;
        MOV     R0,#ExitHandler
        MOV     R1,#0
        MOV     R2,#0
        MOV     R3,#0
        SWI     XOS_ChangeEnvironment
        STR     R1,parentquithandler    ; for checking later
        Debug   task1,", Parent quit handler =",R1
;
        Pull    "R0-R3,PC"

;
; ChangeEnvironment monitoring
; Set bits in [handlerword] whenever a handler is modified
;

ChangeEnvCode
        Push    "R1,LR"
;
        TEQ     R1,#0           ; if the handler is being modified,
        MOVNE   R14,#1          ; set the corresponding bit in [handlerword]
        LDRNE   R1,handlerword
        ORRNE   R1,R1,R14,LSL R0   ; assume < 32 handlers
        STRNE   R1,handlerword
;
        Pull    "R1,PC"         ; pass it on!


UpCallCode	ROUT
        TEQ     R0,#UpCall_MediaSearchEnd
        BEQ     finishupcall                        ; this comes round if it works!
	TEQ	R0,#UpCall_MediaSearchEndMessage
        BEQ     finishupcall_withmessage            ; this comes round if it works!

        TEQ     R0,#UpCall_MediaNotPresent
        TEQNE   R0,#UpCall_MediaNotKnown
        MOVNE   PC,LR                   ; Pass it on


; In    r1 = fs number
;       r2 -> media name, or = -1 => r6 -> message
;       r3 = device number (-1 for irrelevant)
;       r4 = iteration number (so we can 'reverse poll' if required)
;       r5 = timeout between reverse polls (large if not wanted)
;       r6 -> media type (eg. 'disc' for FileCore) (if r2 <> -1)
;          = -1 for disc (if r2 <> -1)
;          -> complete message to display (if r2 = -1)

; Note  PRM p1-179 says that r2 may be -1 if irrelevant, the comment above
;       said it may be 0. Both were wrong. We take advantage of the
;       documentation to provide slightly modified behaviour, since no-one
;       can have been relying on r2 = -1 working before.

        Push    "R1-R6"         ; no need to stash LR (we'll claim vector)

      [ :LNOT: Medusa
        CMP     R6,#0                   ; bodge for old FileCores
        ADRMIL	R6,disc
        MOVMI   R5,#bignum              ; long timeout if R6 invalid
      ]

        SUB     sp,sp,#32
;
        MOV     r0, #FSControl_ReadFSName
        ADRL    r2, errorbuffer         ; r2 = buffer
        MOV     r3, #256                ; r3 = length
        LDR     r1, [sp,#32+0*4]        ; r1 = fs number
        SWI     XOS_FSControl
        SUBS    r2, sp, #0              ; CLRV, r2 -> buffer.
;
        Push    "r4"
        MOVVS   r4, #0
        ADRVCL  r4, errorbuffer         ; -> string of messages
        ADR     r0, messagefrom
        MOV     r3, #32
        BL      LookupToken
        Pull    "r4"
;
        SUBS    r2, sp, #0              ; CLRV, r2 -> buffer.
;
        Push    "R2-R5"
	LDR	r5, [sp, #32+1*4+4*4]	; media name or -1
	CMP	r5, #-1
	BEQ	%04

        ADRL    R2,errorbuffer
        MOV     R3,#252
        MOV     R14,#0                  ; error number
        STR     R14,[R2],#4
;
        ADRL    R0,ensuredisc           ; "Please insert %0 '%1'"
        MOV     R4,R6			; media type
;
        BL      LookupToken             ; resolve into suitable string

	B	%05
04
	;Just use the message provided (copied into the same buffer)
      [ false
	ADRL    r2, errorbuffer
	ADD	r2, r2, #4		;don't care about error number
06	LDRB	lr, [r6], #1		;read from given message
	STRB	lr, [r2], #1		;write to error buffer
	TEQ	lr, #0			;NUL-terminated
	BNE	%06
      |
	ADRL    r2, errorbuffer
	ADD	r3, r2, #251		;r3 holds the end address of the error buffer
	ADD	r2, r2, #4		;don't care about error number
06	LDRB	lr, [r6], #1		;read from given message
	TEQ	lr, #0			;NUL-terminated
	TEQNE	lr, #10			;test for end of line searching too far
	TEQNE	lr, #13			;test for cr
	TEQNE 	r2, r3			;test end of buffer
	STRNEB	lr, [r2], #1		;write to error buffer
	BNE	%06

	MOV	lr, #0			;ensure always NUL-terminated
	STRB	lr, [r2]
      ]
05
        Pull    "R2-R5"
;
        SWI     XOS_ReadMonotonicTime
        MOV     R4,R0

01      ADRL    R0,errorbuffer
        MOV     R1,#erf_okbox:OR:erf_cancelbox:OR:erf_omiterror:OR:erf_poll
        CMP     R5,#bignum
        BICCS   R1,R1,#erf_poll         ; don't poll if timeout too long
	Debug	upcall, "+Wimp_ReportError: flags", R1
        SWI     XWimp_ReportError
	Debug	upcall, "-Wimp_ReportError: button", R1
        TEQ     R1,#0                   ; if no decision made, loop & timeout
        BNE     %FT02

        SWI     XOS_ReadMonotonicTime
        SUB     R0,R0,R4
        CMP     R0,R5
        BCC     %BT01                   ; unsigned comparison

        MOV     R0,#UpCall_Claimed      ; get ADFS to try again
        B       %FT03

02      TEQ     R1,#erf_okbox
        MOVEQ   R0,#UpCall_Claimed      ; UpCall processed
        MOVNE   R0,#UpCall_Invalid
03
        ADD     sp,sp,#32               ; correct stack
        Pull    "R1-R6,PC"              ; Claim vector

finishupcall
        Push    "R0-R1"
;
        MOV     R1,#erf_okbox:OR:erf_pollexit   ; select 'OK'
        SWI     XWimp_ReportError
;
        [ No32bitCode
        MOV     R14,#0
        ]
        MRS     R14,CPSR
        TST     R14,#2_11100
        Pull    "R0-R1,PC",EQ,^         ; claim vector
        CLRV
        Pull    "R0-R1,PC"

finishupcall_withmessage
        Push    "R0-R3"
;
	;Just use the message provided (copied into the same buffer)
	ADRL    r2, errorbuffer
	ADD	r3, r2, #251		;r3 holds the end address of the error buffer
	ADD	r2, r2, #4		;don't care about error number
01	LDRB	lr, [r1], #1		;read from given message
	TEQ	lr, #0			;NUL-terminated
	TEQNE	lr, #10			;test for end of line searching too far
	TEQNE	lr, #13			;test for cr
	TEQNE 	r2, r3			;test end of buffer
	STRNEB	lr, [r2], #1		;write to error buffer
	BNE	%01

	MOV	lr, #0			;ensure always NUL-terminated
	STRB	lr, [r2]

	ADRL	R0, errorbuffer
	SUB	R0, r2, r0
	Debug	upcall,"string size",R0
	ADRL	R0, errorbuffer
        MOV     R1,#erf_okbox:OR:erf_poll   		; Draw the Box
        SWI     XWimp_ReportError
        MOV     R1,#erf_okbox:OR:erf_pollexit   	; Request the Box Removed
        SWI     XWimp_ReportError
;
        [ No32bitCode
        MOV     R14,#0
        ]
        MRS     R14,CPSR
        TST     R14,#2_11100
        Pull    "R0-R3,PC",EQ,^         ; claim vector
        CLRV
        Pull    "R0-R3,PC"

messagefrom DCB "MF", 0
ensuredisc  DCB "ID", 0                  ; followed by media type (eg. 'disc')
disc        DCB "disc", 0               ; cheat

        ALIGN

;
; Free resources currently used by Wimp
; NB:  task blocks etc. are not valid, so are simply discarded
;      don't bother to rewrite pointers - done later in 'initptrs'
; Doesn't reset the common sprite pool (only done in Die)
;

deallocateptrs	ROUT
        Push    "R0-R5,LR"
;
; release block used for holding pixtrans tables
;
        MOV     R0,#ModHandReason_Free
        MOV     R1,#0                   ; reset pointers to zero
;
        LDR     R2,pixtable_at
        CMP     R2,#0
        BLNE    XROS_Module              ; release the pixtrans table (ignore errors)
;
        LDR     R2,fileaddress
        CMP     R2,#0
        BLNE    XROS_Module              ; release the template loading buffer (ignore errors)
;
        LDR     R2,inversecolourmap
        CMP     R2,#0
        BLNE    XROS_Module             ; release colour mapping tables
;
        STR     R1,pixtable_at
        STR     R1,pixtable_size
        STR     R1,filehandle
        STR     R1,fileaddress          ; tag as free'd
        STR     R1,inversecolourmap
        STRB    R1,checkedcolourmapping ; ensure we check again before we try using the duff pointer
;
        BL      freelist                ; de-allocate list buffer (for sprite cache)
        BL      freetoolarea
;
        [ mousecache
        MOV     R0,#TickerV             ; tidy the mouse handler
        ADRL    R1,MouseCallEveryHandler
        BL      release
        ]
      [ NewErrorSystem
        [ WatchdogTimer
        ADRL    R0,BreakWatchdogHandler
        MOV     R1,WsPtr
        SWI     XOS_RemoveTickerEvent
        |
        MOV     R0,#EventV
        ADRL    R1,BreakWatchdogHandler
        MOV     R2,WsPtr
        SWI     XOS_Release                     ; stop calls to watchdog on events
         [ false
        MOV     R0,#13
        MOV     R1,#Event_Keyboard              ; disable keyboard events
        SWI     XOS_Byte
05
         ]
        ]
      ]
;
      [ outlinefont
        BL      LoseFont
      ]
;
; delete window blocks
;
        B       %FT02

01      LDR     R5,[R2,#ll_backwards]

        ; Delink window
        STR     R4,[R5,#ll_forwards]
        STR     R5,[R4,#ll_backwards]

        ; Discard it after translating link address to window address
        SUB     R2,R2,#w_all_link

        Debug   opn,"**** Discarding window on wimp dying ****",R2

        BL      discard_window
02
        ; Get first window in list, is it the header?
      [ ChildWindows                            ; make this unconditional when merging sources back in
        LDR     R2,allwinds+lh_forwards         ; BUGFIX: NRaine 2-Aug-96: discard ALL windows, not just the open ones!
      |                                         ;         It actually breaks otherwise, since w_all_link is used (see above)
        LDR     R2,activewinds+lh_forwards
      ]
        LDR     R4,[R2,#ll_forwards]
        CMP     R4,#nullptr
        BNE     %BT01
;
; delete the message queue
;
        BL      deletemessagequeue              ; also done when last task dies
;
; delete task blocks and associated slots
;
        ADRL    R4,taskpointers
        MOV     R5,#maxtasks
01
        LDR     R2,[R4],#4
        TST     R2,#task_unused
        BNE     %FT11
        LDR     R2,[R2,#task_slotptr]
        Debug   mjs2," wimp01 (1) slotptr to free",R2
        CMP     R2,#nullptr
      [ UseAMBControl
        MOVNE   R0,#1   ;deallocate reason code
        SWINE   XOS_AMBControl
      |
        MOVNE   R0,#ModHandReason_Free
        BLNE   XROS_Module                      ; free block (ignoring errors)
      ]
        LDR     R2,[R4,#-4]
        MOV     R0,#ModHandReason_Free
        BL     XROS_Module              ; free block (ignoring errors)
11
        SUBS    R5,R5,#1
        BNE     %BT01
;
      [ :LNOT: Medusa
        LDR     R2,freepool
        CMP     R2,#nullptr2
        MOVLO   R0,#ModHandReason_Free
        BLLO   XROS_Module
      ]
;
        BL      deletependingtask
;
; delete both sets of iconbar entries
;
        ADRL    R1,iconbarleft
        BL      killiconbar
        ADRL    R1,iconbarright
        BL      killiconbar

;
        Pull    "R0-R5,PC"


deletependingtask
        Push    "R0-R2,LR"
;
        LDR     R2,pendingtask
        CMP     R2,#0
        BMI     %FT01
        LDR     R2,[R2,#task_slotptr]   ; delete slot block
        Debug   mjs2," wimp01 (2) slotptr to free",R2
        CMP     R2,#nullptr
      [ UseAMBControl
        MOVNE   R0,#1   ;deallocate reason code
        SWINE   XOS_AMBControl
      |
        MOVNE   R0,#ModHandReason_Free
        BLNE   XROS_Module
      ]
        LDR     R2,pendingtask          ; and task block (in that order)
        MOV     R0,#ModHandReason_Free
        BL     XROS_Module
        MOV     R14,#nullptr
        STR     R14,pendingtask
01
        CLRV
        Pull    "R0-R2,PC"


killiconbar
        Push    "LR"
        LDR     R2,[R1,#icd_list]
01
        CMP     R2,#nullptr
        BEQ     %FT02
        LDR     R4,[R2,#icb_link]
        MOV     R0,#ModHandReason_Free
        BL     XROS_Module              ; free block (ignoring errors)
        MOV     R2,R4
        B       %BT01
02
        MOV     R14,#nullptr
        STR     R14,[R1,#icd_list]
;
        Pull    "PC"


deletemessagequeue
        Push    "R0-R3,LR"
;
        LDR     R1,headpointer
01
        CMP     R1,#nullptr
        BEQ     %FT02
        MOV     R0,#ModHandReason_Free  ; free block (ignoring errors)
        MOV     R2,R1
        LDR     R1,[R1,#msb_link]       ; do this first!!!
        BL     XROS_Module
        B       %BT01
02
        MOV     R14,#nullptr
        STR     R14,headpointer
      [ NKmessages1
        STR     R14,lastpointer
      ]
;
        CLRV
        Pull    "R0-R3,PC"              ; ignore errors


vduinput
        DCD     VduExt_XEigFactor
        DCD     VduExt_YEigFactor
        DCD     VduExt_Log2BPP
        DCD     -1

        ASSERT  (scrx0-vduoutput)=12
vduinput2
        DCD     VduExt_XEigFactor
        DCD     VduExt_YEigFactor
        DCD     VduExt_Log2BPP
      [ SwitchingToSprite
        DCD     0                     ; dummies - these are zeroed later
        DCD     0                     ;
        DCD     VduExt_XWindLimit
        DCD     VduExt_YWindLimit
      |
        DCD     VduExt_GWLCol
        DCD     VduExt_GWBRow
        DCD     VduExt_GWRCol
        DCD     VduExt_GWTRow
      ]
        DCD     VduExt_TCharSpaceX
        DCD     VduExt_TCharSpaceY
        DCD     VduExt_ModeFlags      ; for checking for hi-res mono modes
        DCD     VduExt_NColour
        DCD     -1


readvduvars2
        Push    "R0-R4,LR"

        ADR     R0,vduinput2
        ADR     R1,vduoutput
        SWI     XOS_ReadVduVariables
        ADRVC   R0,scrx0
        LDMVCIA R0,{R1-R6}              ; plus text x,y size
        LDR     R14,log2px
      [ SwitchingToSprite
        MOV     R1, #0
      |
        MOV     R1,R1,ASL R14
      ]
        ADD     R3,R3,#1                ; make exclusive
        MOV     R3,R3,ASL R14
        MOV     R5,R5,ASL R14
        LDR     R14,log2py
      [ SwitchingToSprite
        MOV     R2, #0
      |
        MOV     R2,R2,ASL R14
      ]
        ADD     R4,R4,#1                ; make exclusive
        MOV     R4,R4,ASL R14
        MOV     R6,R6,ASL R14
        STMVCIA R0,{R1-R6}
        BVS     leavereadvduvars2       ; return if errors

        MOV     R0,#ReadCMOS
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0                   ; if errored then must read location as 0!
        CLRV    VS                      ; ignore any errors

        TST     R2,#WimpDitherDesktopCMOSBit
        MOV     R2,#0
        ORRNE   R2,R2,#1:SHL:8          ; dithering enabled - thats rather dangerous isn't it!
        STR     R2,ditheringflag

leavereadvduvars2
        STRVS   R0,[sp]
        Pull    "R0-R4,PC"

readvduvars
        Push    "R0,R1,LR"
        ADR     R0,vduinput
        ADR     R1,vduoutput
        SWI     XOS_ReadVduVariables
        STRVS   R0,[sp]
        Pull    "R0,R1,PC"

calcborders
        Push    "R1-R10,LR"
;
; relocate the ROM sprites for this mode!
;
        BL      getromsprites           ; re-address the ROM sprites
;
        LDR     R14,log2px
        MOV     R1,#1
        MOV     R1,R1,ASL R14
        STR     R1,dx
        SUB     R14,R1,#1
        STR     R14,dx_1
;
        LDR     R14,log2py
        MOV     R1,#1
        MOV     R1,R1,ASL R14
        STR     R1,dy
        SUB     R14,R1,#1
        STR     R14,dy_1
;
; calculate basic characteristics used for the scroll bars
;
        LDR     R14,dx
        LDR     R1,dy
        CMP     R1,R14
        MOVLT   R1,R14                  ; R1 = maximum pixel size
        STR     R1,xypixelsize
;
        MOV     R14,#40                 ; always 40 OS units!
;
        STRB    R14,xborder
        STRB    R14,yborder
;
        LDR     R1,dx
        ADD     R1,R14,R1
        STRB    R1,xborder1             ; xborder1 = xborder + dx
        LDR     R1,dy
        ADD     R1,R14,R1
        STRB    R1,yborder1             ; yborder1 = yborder + dy
;
        Pull    "R1-R10,PC"

;;-----------------------------------------------------------------------------
;; The Wimp SWI - all calls to the Wimp come through here
;;
;; Entry:  R11 = SWI number within chunk
;;         R12 --> private word
;;         R1 --> user buffer (parameter block)
;; Exit :  R0 = reason code
;;         R1 --> parameter block (modified)
;;-----------------------------------------------------------------------------

;;-----------------------------------------------------------------------------
;; Handle the SWI decoding for the Window Manager
;;-----------------------------------------------------------------------------

Wimp_SWIdecode
        Push    "LR"
;
      [ debugints
       [ No32bitCode
        MOV     R14,#I_bit
        TST     R14,PC
       |
        MOV     R14,CPSR
        TST     R14,#I32_bit
       ]
        BEQ     %FT00
        Debug   ints,"Ints enabled: SWI number =",R11
00
      ]
        CLRPSR  I_bit, R14                      ; re-enable interrupts
;
        LDR     wsptr,[R12]                     ; wsptr --> workspace
        LDR     R14,longjumpSP
        STR     R14,[sp,#-4]!                   ; stash these for re-entrancy!
        LDR     R14,polltaskhandle
        STR     R14,[sp,#-4]!
;
        Push    "R1-R11"
        STR     sp,longjumpSP
        LDR     R14,taskhandle                  ; in case of incorrect swaps ..
        STR     R14,polltaskhandle              ; .. the caller is put back!
;
        LDR     R14,[wsptr,R14]                 ; check whether this SWI can
        TST     R14,#task_unused                ; be called without Wimp_Init
        ADR     R14,flagtable
        LDRB    R14,[R14,R11]
        TSTNE   R14,#swf_alive
        BNE     jporg                           ; error if not initialised
        CMP     R14,#swf_checklimit
        CMPLO   R1,#ApplicationStart
        BLO     err_badpointer

        [       outlinefont
        MOV     R14, #0
        STR     R14, currentfont
        ]
        LDR     R14,wimpswiintercept
        TEQ     R14,#0
        MOVNE   PC,R14
callaswi
        CMP     R11,#maxnewswi
        ADDCC   R14,R11,#(jptable-jporg-4)/4    ; bodge factor
        MOVCC   userblk,R1                      ; get userblk (--> parameters)
        ADDCC   PC,PC,R14,ASL #2                ; go!
jporg
        MyXError  WimpBadOp
        B       ExitWimp_noswitch
        MakeErrorBlock WimpBadOp
err_badpointer
        MyXError  WimpBadPtrInR1
        B       ExitWimp_noswitch
        MakeErrorBlock WimpBadPtrInR1

ExitWimp
        LDR     R14,polltaskhandle      ; ensure no illegal task swaps occur!
        Task    R14,,"ExitWimp"

ExitWimp_noswitch
   ;    MOVVS   R14,#nullptr            ; CAN'T CLEAR THIS JUST BECAUSE V SET!
   ;    STRVS   R14,redrawhandle
;
        Pull    "R1-R11"
return
        LDR     R14,[sp],#4
        STR     R14,polltaskhandle
        LDR     R14,[sp],#4
        STR     R14,longjumpSP

        [       outlinefont
        ;Restore the current font and font colours that were in force on
        ;       entry, if they've been changed. Preserve flags while doing
        ;       this.
        Debug   exit, "ExitWimp: restoring font and font colours"
        [ No32bitCode
        Push    "R0-R3,PC"
        |
        MRS     R14,CPSR
        Push    "R0-R3,R14"
        ]
        LDR     R0, currentfont
        TEQ     R0, #0
        BEQ     ExitWimp_restored_font_colours
        LDR     R1,systemfont
        TEQ     R1,R0
        BEQ     %FT05                           ; its ours ! No need to call the SWI
        LDR     R1, currentbg
        LDR     R2, currentfg
        LDR     R3, currentoffset
        Debug   exit, "ExitWimp: calling Font_SetFontColours"
        SWI     XFont_SetFontColours
05
        MOV     R0, #0
        STR     R0, currentfont
ExitWimp_restored_font_colours
        Pull    "R0-R3,LR"
        [ No32bitCode
        TEQP    PC, LR
        |
        MSR     CPSR_f, LR
        ]
        |
        [ :LNOT:No32bitCode
        MRS     LR, CPSR
        ]
        ]

        [ :LNOT:No32bitCode
        ; LR contains CPSR
        TST     LR, #2_11100
        Pull    "PC",NE          ; 32-bit exit (just pass V back)
        ]

        Pull    "PC",VC,^        ; exit immediately

        DebugE  err,"Wimp SWI error"
        Debug   err,"SWI #, task",R11,#taskhandle

        Pull    "PC",VS

ExitWimp2
        LDR     R14,polltaskhandle      ; ensure no illegal task swaps occur!
        Task    R14,,"ExitWimp2"
;
        ADD     sp,sp,#6*4              ; leave R1-R6 as on exit
        Pull    "R7-R11"
        B       return

;
; jump table - contains branches to entry points
;

        GBLA    swicnt                  ; for dealing with flagtable
swicnt  SETA    0

jptable
x       MySWI   Wimp_Initialise         ; 0       ; Wimp_Init not necessary
p       MySWI   Wimp_CreateWindow       ; 1       ; check for owner window
p       MySWI   Wimp_CreateIcon         ; 2       ; check for owner window
p       MySWI   Wimp_DeleteWindow       ; 3       ; check for owner window
p       MySWI   Wimp_DeleteIcon         ; 4       ; check for owner window
p       MySWI   Wimp_OpenWindow         ; 5       ; check for owner window
p       MySWI   Wimp_CloseWindow        ; 6       ; check for owner window
xp      MySWI   Wimp_Poll               ; 7       ; Wimp_Init not necessary; check for owner window
p       MySWI   Wimp_RedrawWindow       ; 8       ; check for owner window
p       MySWI   Wimp_UpdateWindow       ; 9       ; check for owner window
p       MySWI   Wimp_GetRectangle       ; 10      ; check for owner window
xp	MySWI   Wimp_GetWindowState     ; 11      ; Wimp_Init not necessary; check for owner window
xp	MySWI   Wimp_GetWindowInfo      ; 12      ; Wimp_Init not necessary; check for owner window
p       MySWI   Wimp_SetIconState       ; 13      ; check for owner window
p       MySWI   Wimp_GetIconState       ; 14      ; check for owner window
xp	MySWI   Wimp_GetPointerInfo     ; 15      ; Wimp_Init not necessary; check for owner window
        MySWI   Wimp_DragBox            ; 16
        MySWI   Wimp_ForceRedraw        ; 17
        MySWI   Wimp_SetCaretPosition   ; 18
p       MySWI   Wimp_GetCaretPosition   ; 19      ; check for owner window
        MySWI   Wimp_CreateMenu         ; 20
        MySWI   Wimp_DecodeMenu         ; 21
p       MySWI   Wimp_WhichIcon          ; 22      ; check for owner window
p       MySWI   Wimp_SetExtent          ; 23      ; check for owner window
x       MySWI   Wimp_SetPointerShape    ; 24      ; Wimp_Init not necessary
xp      MySWI   Wimp_OpenTemplate       ; 25      ; Wimp_Init not necessary; check for owner window
x       MySWI   Wimp_CloseTemplate      ; 26      ; Wimp_Init not necessary
x       MySWI   Wimp_LoadTemplate       ; 27      ; Wimp_Init not necessary
        MySWI   Wimp_ProcessKey         ; 28
x       MySWI   Wimp_CloseDown          ; 29      ; Wimp_Init not necessary
        MySWI   Wimp_StartTask          ; 30
x       MySWI   Wimp_ReportError        ; 31      ; Wimp_Init not necessary
p       MySWI   Wimp_GetWindowOutline   ; 32
xp      MySWI   Wimp_PollIdle           ; 33      ; Wimp_Init not necessary; check for owner window
p       MySWI   Wimp_PlotIcon           ; 34
x       MySWI   Wimp_SetMode            ; 35      ; Wimp_Init not necessary
x       MySWI   Wimp_SetPalette         ; 36      ; Wimp_Init not necessary
xp      MySWI   Wimp_ReadPalette        ; 37      ; Wimp_Init not necessary; check for owner window
x       MySWI   Wimp_SetColour          ; 38      ; Wimp_Init not necessary
p       MySWI   Wimp_SendMessage        ; 39      ; check for owner window
        MySWI   Wimp_CreateSubMenu      ; 40
x       MySWI   Wimp_SpriteOp           ; 41      ; Wimp_Init not necessary
x       MySWI   Wimp_BaseOfSprites      ; 42      ; Wimp_Init not necessary
        MySWI   Wimp_BlockCopy          ; 43      ; check for owner window
x       MySWI   Wimp_SlotSize           ; 44      ; Wimp_Init not necessary
x       MySWI   Wimp_ReadPixTrans       ; 45      ; Wimp_Init not necessary
x       MySWI   Wimp_ClaimFreeMemory    ; 46      ; Wimp_Init not necessary
x       MySWI   Wimp_CommandWindow      ; 47      ; Wimp_Init not necessary
x       MySWI   Wimp_TextColour         ; 48      ; Wimp_Init not necessary
x       MySWI   Wimp_TransferBlock      ; 49      ; Wimp_Init not necessary
x       MySWI   Wimp_ReadSysInfo        ; 50      ; Wimp_Init not necessary
        MySWI   Wimp_SetFontColours     ; 51
p       MySWI   Wimp_GetMenuState       ; 52      ; check for owner window
x       MySWI   Wimp_RegisterFilter     ; 53      ; Wimp_Init not necessary
        MySWI   Wimp_AddMessages        ; 54
        MySWI   Wimp_RemoveMessages     ; 55
x       MySWI   Wimp_SetColourMapping   ; 56      ; Wimp_Init not necessary
        MySWI   Wimp_TextOp             ; 57      ; 320nk
x       MySWI   Wimp_SetWatchdogState   ; 58      ; Wimp_Init not necessary      ; 322
x       MySWI   Wimp_Extend             ; 59      ; Wimp_Init not necessary
        MySWI   Wimp_ResizeIcon         ; 60
 [ Autoscr
x       MySWI   Wimp_AutoScroll         ; 61      ; checks done later
 ]

endjptable
maxnewswi   *   (endjptable-jptable)/4

flagtable
swicnt  SETA    0
        WHILE   swicnt < maxnewswi
        DCB     xflg_$swicnt            ; flags for a given SWI
swicnt  SETA    swicnt+1
        WEND
        [ false
        WHILE   swicnt < 64
        DCB     0
swicnt  SETA    swicnt+1
        WEND
        ]
        ; all 'new' SWI's may be used without wimp_initalise
        DCB     16,16,16,16

        ALIGN

Wimp_SWInames
        DCB     "Wimp",0                ; prefix
        DCB     "Initialise",0
        DCB     "CreateWindow",0
        DCB     "CreateIcon",0
        DCB     "DeleteWindow",0
        DCB     "DeleteIcon",0
        DCB     "OpenWindow",0
        DCB     "CloseWindow",0
        DCB     "Poll",0
        DCB     "RedrawWindow",0
        DCB     "UpdateWindow",0
        DCB     "GetRectangle",0
        DCB     "GetWindowState",0
        DCB     "GetWindowInfo",0
        DCB     "SetIconState",0
        DCB     "GetIconState",0
        DCB     "GetPointerInfo",0
        DCB     "DragBox",0
        DCB     "ForceRedraw",0
        DCB     "SetCaretPosition",0
        DCB     "GetCaretPosition",0
        DCB     "CreateMenu",0
        DCB     "DecodeMenu",0
        DCB     "WhichIcon",0
        DCB     "SetExtent",0
        DCB     "SetPointerShape",0
        DCB     "OpenTemplate",0
        DCB     "CloseTemplate",0
        DCB     "LoadTemplate",0
        DCB     "ProcessKey",0
        DCB     "CloseDown",0

        DCB     "StartTask",0
        DCB     "ReportError",0
        DCB     "GetWindowOutline",0
        DCB     "PollIdle",0
        DCB     "PlotIcon",0
        DCB     "SetMode",0
        DCB     "SetPalette",0
        DCB     "ReadPalette",0
        DCB     "SetColour",0
        DCB     "SendMessage",0
        DCB     "CreateSubMenu",0
        DCB     "SpriteOp",0
        DCB     "BaseOfSprites",0
        DCB     "BlockCopy",0
        DCB     "SlotSize",0
        DCB     "ReadPixTrans",0
        DCB     "ClaimFreeMemory",0
        DCB     "CommandWindow",0
        DCB     "TextColour",0
        DCB     "TransferBlock",0
        DCB     "ReadSysInfo",0
        DCB     "SetFontColours",0

        DCB     "GetMenuState",0
        DCB     "RegisterFilter",0
        DCB     "AddMessages",0

        DCB     "RemoveMessages",0
        DCB     "SetColourMapping",0

        DCB     "TextOp",0
        DCB     "SetWatchdogState",0
        DCB     "Extend",0
        DCB     "ResizeIcon",0

        DCB     "AutoScroll",0

        DCB     0
        ALIGN


;;-----------------------------------------------------------------------------
;; Wimp_ReadSysInfo - return information given specfic index
;;
;; in   R0 = index
;; out  R0 = value (depends on R0 on entry)
;;      R1 = value (depends on R0 on entry)
;;-----------------------------------------------------------------------------

SWIWimp_ReadSysInfo
        MyEntry "ReadSysInfo"
;
        CMP     R0,#(err_badR0-%00)/4
        ADDCC   PC,PC,R0,LSL #2         ; yeehaa its valid so despatch
        B       err_badR0               ; otherwise return
00
        B       sysinfo_TaskCount       ; 0 = task count
        B       sysinfo_WimpMode        ; 1 = current wimp mode
        B       sysinfo_SpriteSuffix    ; 2 = suffix for icon sprites
        B       sysinfo_DesktopState    ; 3 = state of the desktop
        B       sysinfo_WriteDir        ; 4 = write direction
        B       sysinfo_CurrentTask     ; 5 = return current task
        B       sysinfo_Swapping        ; 6 = swapping information / error if not swapping version
        B       sysinfo_Version         ; 7 = Get wimp version
        B       sysinfo_SystemFont      ; 8 = Get system font handle
        B       sysinfo_ToolSprites     ; 9 = ToolSpriteCB
        B       sysinfo_IconBarInt      ; 10= Iconbar info             (Internal)
        B       sysinfo_appspace        ; 11= App space size           
        B       sysinfo_messages        ; 12= message queue            (Internal)
        B       sysinfo_memclaim        ; 13= list of memory claims    (Internal)
        B       sysinfo_transtables     ; 14= tool plotting info       (Internal)
	B	err_badR0               ; 15= iconise button           (Internal)
	B       sysinfo_baseofsprites   ; 16= low/high priority sprite areas
	B       sysinfo_pausedelay      ; 17= drag-and-drop scroll startup delay
        B       err_badR0               ; 18= ?                        (ROL)
        B       err_badR0               ; 19= priority sprite area     (ROL)
        B       err_badR0               ; 20= special highlight colour (ROL)
        B       err_badR0               ; 21= text selection behaviour (ROL)
        B       err_badR0               ; 22= caret colour             (ROL)
        B       sysinfo_dragging        ; 23= mouse drag delay
        B       sysinfo_doubleclicks    ; 24= double click delay
        B       sysinfo_automenus       ; 25= auto menu open settings
        B       sysinfo_iconbar         ; 26= iconbar speed and acceleration
        B       err_badR0               ; 27= screen edge notification (ROL)
        B       sysinfo_3Dpatch         ; 28= visual flags
        B       sysinfo_alphasprites    ; 29= alpha sprites

err_badR0
        MyXError  WimpBadSysInfo
        B       ExitWimp
        MakeErrorBlock WimpBadSysInfo

;..............................................................................

sysinfo_TaskCount
        LDR     R0,taskcount            ; R0 = number of active tasks
        B       ExitWimp

sysinfo_WimpMode
        LDR     R0,currentmode          ; R0 = current desktop mode
        B       ExitWimp

sysinfo_SpriteSuffix
        ADR     R0,romspr_suffix
        B       ExitWimp

sysinfo_DesktopState
        LDR     R0,taskcount
        CMP     R0,#0                   ; R0=0 => Wimp inactive
        LDRNE   R0,commandflag
        EORNES  R0,R0,#cf_active        ; R0=0 => command window active
        MOVNE   R0,#1                   ; R0=1 => desktop vdu state set
        B       ExitWimp

sysinfo_WriteDir
        LDR     R0,writeabledir         ; R0 = write direction
        B       ExitWimp

sysinfo_CurrentTask
        LDR     R0,taskhandle           ; R0 = task handle
        LDR     R1,[wsptr,R0]           ; R1 -> task record
        TEQ     R1,#task_unused
;
        LDRNE   R1,[R1,#task_wimpver]   ; if used slot then return handle + wimp ver known
        STRNE   R1,[SP,#4*0]
        BLNE    fulltaskhandle
        MOVNE   R0,R14
        MOVEQ   R0,#0                   ; setup meaningful task handle =0 if none, else current
;
        B       ExitWimp

sysinfo_Swapping
      [ Swapping
        ADR     R0,swapping
        B       ExitWimp
      |
        B       err_badR0
      ]

sysinfo_Version
        LDR     R0,=Module_Version
        B       ExitWimp
        LTORG
        
sysinfo_SystemFont
      [ outlinefont
        LDR     R0,systemfont           ; zero if no font, cf spec
        LDR     R1,symbolfont
        B       sysinfo_exitR0R1
      |
        B       err_badR0
      ]

sysinfo_ToolSprites
        ADRL    R0,tool_areaCB
        B       ExitWimp

sysinfo_IconBarInt
        ADRL    R0,iconbarhandle
        MOV     R1,#w_icons
        MOV     R2,#w_nicons
        ADRL    R3,iconbarleft
        ADRL    R4,iconbarright
        STMIA   sp,{R1-R4}
        B       ExitWimp

sysinfo_dragging
        LDRB    R0,drag_movelimit
        LDR     R1,drag_timelimit
sysinfo_exitR0R1
        STR     R1,[sp]
        B       ExitWimp

sysinfo_doubleclicks
        LDRB    R0,doubleclick_movelimit
        LDR     R1,doubleclick_timelimit
        B       sysinfo_exitR0R1

sysinfo_3Dpatch
      [ ThreeDPatch
        LDR     R0,ThreeDFlags
        B       ExitWimp
      |
        B       err_badR0
      ]

sysinfo_iconbar
        LDR     R0,iconbar_scroll_speed
        LDR     R1,iconbar_scroll_accel
        B       sysinfo_exitR0R1

sysinfo_automenus
        LDR     R0,automenu_timelimit
        LDR     R1,menudragdelay
        B       sysinfo_exitR0R1
                
sysinfo_appspace
        LDR     R0,orig_applicationspacesize
        B       ExitWimp

sysinfo_messages
        ADR     R0,headpointer
      [ NKmessages1
        ADRL    R1,lastpointer
        B       sysinfo_exitR0R1
      |
        B       ExitWimp
      ]

sysinfo_memclaim
      [ DebugMemory
        ADRL    R0,memory_claims
        LDR     R0,[R0]
      ]
        B       ExitWimp

sysinfo_transtables
        LDR     R0,tpixtable_at
        ADRL    R2,tool_plotparams
        LDR     R1,[R2]
        STMIA   sp,{R1-R2}
        B       ExitWimp

sysinfo_baseofsprites
      [ SpritePriority
        LDR     R0, baseoflosprites
        LDR     R1, baseofhisprites
	B	sysinfo_exitR0R1
      |
        B       err_badR0
      ]

sysinfo_pausedelay
      [ Autoscr
        LDRB    R0, autoscr_default_pause
        ADD     R0, R0, R0, LSL #2  ; * 5
        MOV     R0, R0, LSL #1      ; * 10
	B	ExitWimp
      |
        B       err_badR0
      ]

sysinfo_alphasprites
        ; Bit 0: Alpha-masked sprites supported by OS/Wimp and will be looked
        ;        for by IconSprites, Wimp_Extend 13, etc.
        ; Bits 1-31: reserved
      [ SpritesA
        LDRB    R0, alphaspriteflag
        ANDS    R0, R0, #255
        MOVNE   R0, #1
      |
        MOV     R0, #0
      ]
        B       ExitWimp

;;-----------------------------------------------------------------------------
;; Command Window handling
;;-----------------------------------------------------------------------------
;
; Entry:  R0 --> title string for window
;                (open command window if anything is sent via WrchV)
;         R0 = 1 ==> treat command window as open without displaying it
;         R0 = 0 ==> close command window, and get off WrchV, prompting
;         R0 < 0 ==> close command window, and get off WrchV, quietly
;

                ^       0
cf_dormant      #       1
cf_pending      #       1
cf_active       #       1
cf_wimpdoingvdu	*	1 :SHL: 6	; set by various wimp routines
cf_suspended    *       1 :SHL: 7       ; set by ADFS UpCall handler

SWIWimp_CommandWindow
        MyEntry "CommandWindow"
;
        BL      int_commandwindow
        B       ExitWimp

int_commandwindow
        Push    "R7,LR"                 ; save R7 to help Poll code
;
        Debuga  co,"Wimp_CommandWindow: R0=",R0
;
        LDR     handle,commandhandle    ; if this doesn't exist,
        BL      checkhandle             ; give up now!
        Pull    "R7,PC",VS
;
        AcceptLoosePointer_Neg R0,-1
        CMP     R0, R0, ASR #31
        BEQ     releasewrch             ; R0 = 0 or -1 ==> remove window
        CMP     R0,#1
        BEQ     treatasactive           ; R0 = 1 ==> treat as open
;
        LDR     R14,[handle,#w_titleflags]
        ORR     R14,R14,#if_indirected          ; force indirection
        STR     R14,[handle,#w_titleflags]
;
        STR     R0,[handle,#w_title+0]
        MOV     R14,#-1
        STR     R14,[handle,#w_title+4]         ; no validation string
        MOV     R14,#1
        STR     R14,[handle,#w_title+8]         ; length 1 will do
;
 [ true
        BL      resizecommandwindow
 ]
;
        BL      commandtextwindow       ; do this now so text width correct
;                                       ; NB must be done BEFORE OS_Claim!
        MOV     R0,#WrchV
        ADR     R1,mywrch
        MOV     R2,wsptr
        SWI     XOS_Claim
        Debug   co," - Claimed wrchV"
;
        BL      restorekeys_withescape  ; bodge about with singletaskhandle
;
        MOV     R14,#cf_pending
        STR     R14,commandflag         ; command window pending
;
        Debug   co," - Command window pending"
;
        Pull    "R7,PC"


treatasactive
        Debug   co," - Treat command window as active"
;
        MOV     R0,#WrchV
        ADR     R1,mywrch
        MOV     R2,wsptr
        SWI     XOS_Release
        CLRV                            ; ignore errors
;
        BL      restorekeys_withescape  ; set up key codes, as for normal case
;
        MOV     R14,#cf_active
        STR     R14,commandflag
        Pull    "R7,PC"


restorekeys_withescape
        Push    "LR"
;
        LDR     R14,singletaskhandle    ; FORCE escape to be re-enabled
        Push    "R14"
        MOV     R14,#nullptr
        STR     R14,singletaskhandle
        BL      restorekeycodes         ; restore escape etc. temporarily
        Pull    "R14"
        STR     R14,singletaskhandle
;
        Pull    "PC"

resetkeys_withescape
        Push    "LR"
;
        LDR     R14,singletaskhandle    ; FORCE escape to be re-disabled
        Push    "R14"
        MOV     R14,#nullptr
        STR     R14,singletaskhandle
        BL      resetkeycodes           ; also re-disable escape after temporary restoration
        Pull    "R14"
        STR     R14,singletaskhandle
;
        Pull    "PC"

execcom2 DCB	"Exec",0
	ALIGN

releasewrch
        Debug   co," - Turn off command window"
;
        LDR     R14,commandflag
        TEQ     R14,#cf_dormant
        Pull    "R7,PC",EQ                 ; nothing to do!
;
        Push    "R0,R14"
;
        MOV     R14,#cf_dormant         ; not in a command window any more!
        STR     R14,commandflag
        ADR     R0,execcom2             ; cancel exec file (just in case)
        SWI     XOS_CLI                 ; cf. Wimp_ReportError
        ADRL    R3,tempiconblk
        BL      resetkeys_withescape    ; back to normal
        MOV     R0,#WrchV                       ; doesn't matter if released
        ADR     R1,mywrch                       ;                    already!
        MOV     R2,wsptr
        SWI     XOS_Release
;
        Pull    "R0,R14"
        CMP     R14,#cf_active          ; clears V
        BNE     closit                  ; just in case!!!
;
 [ :LNOT: NoCommandPrompt		; always do this quietly
;
        CMP     R0,#-1                  ; R0 = -1 ==> do this quietly
;
        BEQ     %FT01

        Push    "r2,r3"
        SWI     XOS_NewLine
;
        ADR     r0,pressspace
        ADRL    r2,errorbuffer
        MOV     r3,#256
        BL      LookupToken1            ; get command line to be used
;
        ADRL    r0,errorbuffer
        SWI     XOS_Write0
        SWI     XOS_NewLine
        Pull    "r2,r3"
;
        BL      waitforkey
01
;
 ] ;	:LNOT: NoCommandPrompt
;
        SWI     XOS_WriteI+5            ; get rid of cursor!
closit
        BL      int_close_window        ; handle --> window
        Pull    "R7,PC"

pressspace      DCB     "Space",0
                ALIGN

; Exit:  R1 = &1B ==> escape pressed, 0 ==> mouse click, else key code

waitforkey
        Push    "LR"
;
        BL      flushkbdmouse
11
        BL      powersave_tick
        BL      pollforkey
        BEQ     %BT11
;
        Pull    "PC"

; Out   Z=0 ==> result in R1, else carry on polling

pollforkey
        Push    "R2,R3,LR"

        Debug   err,"PollForKey"

        LDR     R3,mousebuttons         ; 'old' button state
        BL      getmouseposn
        BICS    R14,R2,R3
        MOVNE   R1,#0                   ; 0 ==> mouse click did it
        Debug   err,"Mouse?"
        Pull    "R2,R3,PC",NE
;
        Debug   err,"No mouse press"
        MOV     R0,#&81                 ; read key with 0 time limit
        MOV     R1,#0
        MOV     R2,#0
        SWI     XOS_Byte
;
        TEQ     R1,#&FF
        Debug   err,"Key ?"
        Pull    "R2,R3,PC",LS           ; EQ or CC
        Debug   err,"No key !"
;
        MOV     R0,#124                 ; clear escape condition
        SWI     XOS_Byte
        MOVS    R1,#&1B                 ; Z=0
;
        Pull    "R2,R3,PC"


flushkbdmouse
        Push    "R1-R3,LR"
;
        MOV     R0,#15                  ; flush keyboard buffer
        MOV     R1,#1
        SWI     XOS_Byte
;
        MOV     R0,#21                  ; flush mouseahead buffer
        MOV     R1,#9
        SWI     XOS_Byte
;
        BL      getmouseposn            ; read initial button state
;
        Pull    "R1-R3,PC"

; if a character is printed, activate the command window

mywrch
        Push    "R0-R11,LR"
;
; ignore chars if suspended (Upcall handler does this), or if its
; us doing the VDU!
;
        LDR     R14,commandflag
        TST     R14,#cf_suspended:OR:cf_wimpdoingvdu
        Pull    "R0-R11,PC",NE
;
        Debug   co,"Activate command window"
;
        MOV     R0,#WrchV               ; get off the vector now!
        ADR     R1,mywrch
        MOV     R2,wsptr
        SWI     XOS_Release
;
        MOV     R14,#cf_active
        STR     R14,commandflag

; optimisation - if first char is 22 (mode change),
; don't bother about window cos it'll be overwritten anyway

        LDR     R0,[sp]
        TEQ     R0,#22
        TEQNE   R0,#16                  ; clear G area, oh ma god, FM reentrancy!!!
        Pull    "R0-R11,PC",EQ

; open command window and explicitly redraw it (no Wimp_Polls)

        LDR     R0,commandhandle
        Abs     handle,R0
        ADD     R14,handle,#w_wax0
        LDMIA   R14,{R1-R6}
        MOV     R7,#-1                  ; open at top
;
        Push    "R0-R7"
        MOV     userblk,sp
        BL      int_open_window

        Debug   opn, "Calling int_flush_opens to open command window"
      [ ChildWindows
        BLVC    int_flush_opens         ; flush this before calling visibleouterportion
      ]

        ADRL    userblk,tempiconblk
        BLVC    visibleouterportion     ; handle --> window definition already
        BLVC    int_redraw_window
        BVS     %FT02
01
        TEQ     R0,#0                   ; redraw window now, cos there
        BEQ     %FT02                   ; won't be any Wimp_Poll calls!
        BL      int_get_rectangle
        BVC     %BT01
02
        ADD     sp,sp,#8*4              ; correct stack

; set up corresponding text window and colours

        BL      commandtextwindow       ; VDU 28,x0,y0,x1,y1 etc.
        SWI     XOS_WriteI+4
;
        LDRB    R0,[handle,#w_wfcol]
        BIC     R0,R0,#&80
        SWI     XWimp_TextColour
;
        LDRB    R0,[handle,#w_wbcol]
        ORR     R0,R0,#&80
        SWI     XWimp_TextColour
;
        SWI     XOS_WriteI+12
        SWI     XOS_WriteI+15           ; scroll mode off!
;
        Pull    "R0-R11,PC"             ; pass on the character

 [ true
resizecommandwindow
        Push    "R1,cx0-cy1,handle,LR"
        LDR     cy1,scry1
        LDR     R0,textysize
        ADD     cy1,cy1,R0
        BIC     cy1,cy1,R0              ; ensure top aligned if odd number of rows
        MOV     R1,cy1,LSR #1
        SUB     R1,R1,cy1,LSR #4
        ADD     R1,R1,cy1,LSR #6
        SUB     R1,R1,cy1,LSR #8        ; 0.45 * screen height (or pretty close to)
        DivRem  cy0,R1,R0,R14,norem
        BIC     cy0,cy0,#1              ; round down to even number of rows
        MUL     cy0,R0,cy0              ; scale back to OS units
        CMP     cy0,#1024
        MOVHI   cy0,#1024               ; cap at 1024 OS units

        LDR     cx1,scrx1
        BIC     cx1,cx1,R0              ; ensure left aligned if odd number of columns
        LDR     R0,textxsize
        SUB     R1,cx1,cx1,LSR #2       ; 0.75 * screen width
        DivRem  cx0,R1,R0,R14,norem
        BIC     cx0,cx0,#1              ; round down to even number of columns
        MUL     cx0,R0,cx0              ; scale back to OS units
        CMP     cx0,#1280
        MOVHI   cx0,#1280               ; cap at 1280 OS units

        LDR     R0,commandhandle
        Abs     handle,R0
        MOV     R14,#-12                ; 12 pixels above first line
        SUB     R14,R14,cy0             ; min extent
        STR     cx0,[handle,#w_wex1]
        STR     R14,[handle,#w_wey0]

        MOV     cy1,cy1,LSR #1          ; centre
        MOV     cx1,cx1,LSR #1
        MOV     R1,cy0,LSR #1
        MOV     R0,cx0,LSR #1
        SUB     cy0,cy1,R1
        ADD     cy1,cy1,R1
        SUB     cx0,cx1,R0
        ADD     cx1,cx1,R0
        ADD     cy1,cy1,#12             ; 12 pixels above first line
        ADD     R0,handle,#w_wax0
        STMIA   R0,{cx0-cy1}
        Pull    "R1,cx0-cy1,handle,PC"
 ]

commandtextwindow
        Push    "R1-R11,LR"
;
        LDR     R0,commandhandle
        Abs     handle,R0
        ADD     handle,handle,#w_wax0
;
        SWI     XOS_WriteI+28           ; define text window
        LDR     cy1,scry1
        SUB     cy1,cy1,#1
        MOV     R1,#4                   ; number of coords to do
01
        TST     R1,#1
        LDREQ   cx0,textxsize           ; depends on mode (chars not scaled)
        LDRNE   cx0,textysize
        LDR     x0,[handle],#4          ; get window coords in turn
        RSBNE   x0,x0,cy1
        SUB     cx1,cx0,#1
        TST     R1,#2                   ; ensure text window entirely contained
        ADDEQ   x0,x0,cx1               ; within Wimp window
        SUBNE   x0,x0,cx1               ; (NB y-coords are upside-down)
        DivRem  R0,x0,cx0,R14,norem
        SWI     XOS_WriteC
        SUBS    R1,R1,#1
        BNE     %BT01
;
        ADR     R0,scrollprot           ; turn on the 'scroll protect' bit
        MOV     R1,#endscrollprot-scrollprot
        SWI     XOS_WriteN
;
        Pull    "R1-R11,PC"

scrollprot      DCB     4                       ; VDU 4
                DCB     23, 1,0,  0,0,0,0,0,0,0 ; turn cursor off
                DCB     23,16,1,&FE,0,0,0,0,0,0 ; enable scroll protect
endscrollprot
                ALIGN

;;-----------------------------------------------------------------------------
;; *POINTER  -  calls internal SWI
;;-----------------------------------------------------------------------------

;
; Turn mouse pointer on/off
; If turning it on, also set up the mouse pointer data
;

Pointer_Code
        Push    "R0-R12,LR"
        LDR     R12,[R12]
;
        CMP     R1,#0
        BEQ     Pointer1_Code
        LDRB    R1,[R0]
        CMP     R1,#"0"
        BEQ     Pointer0_Code
        CMP     R1,#"1"
        BEQ     Pointer1_Code
        CMP     R1,#"2"
        BEQ     Pointer2_Code
;
        MyXError  WimpBadPointer
;
exitswi
        STRVS   R0,[sp]
        Pull    "R0-R12,PC"

        MakeErrorBlock WimpBadPointer

; Internal routines to set up the pointer shape
; These use the palette inside the sprite, rather than the WimpPalette

doubleptr_on
        EntryS  "R0,R2,R3"

        ADR     R2,ptr_double
        B       %FT01

doubleptr_off
        ALTENTRY

        ADR     R2,ptr_default
01
        BL      testptrshape
        MOVEQ   R3,#1                   ; program pointer shape, number and palette
        MOVNE   R3,#&61
        BL      setptr_shape

        EXITS                           ; ignore errors

testptrshape
        Push    "R0-R2,LR"

        MOV     R0,#&6A                 ; set/read pointer shape no
        MOV     R1,#127                 ; this is invalid, so won't be set
        SWI     XOS_Byte                ; R1 := actual shape number
        CMP     R1,#1

        Pull    "R0-R2,PC"              ; Z set => current shape = 1

; In    R2 -> pointer shape name
;       R3 = shape number to set, plus flags

setptr_shape
        Push    "R0-R7,LR"

        MOV     R0,#SpriteReason_SetPointerShape
      [ Autoscr
        LDR     R14, autoscr_state      ; don't reprogram pointer if autoscrolling is enabled
        TST     R14, #af_enable
        ORRNE   R3, R3, #&10
      ]
        MOV     R4,#0                   ; active point at top-left
        MOV     R5,#0
        MOV     R6,#0
        MOV     R7,#0
        SWI     XWimp_SpriteOp          ; take from Wimp's sprite area(s)

        STRVS   R0,[sp]
        Pull    "R0-R7,PC"

ptr_double      DCB     "ptr_double",0          ; now moved so that starterrorbox_draw can access ptr_default
ptr_default     DCB     "ptr_default",0
                ALIGN


; set up mouse pointer shape

Pointer1_Code
        BL      readvduvars2            ; including screen size

        ADRVC   R2,ptr_default
        MOVVC   R3,#1                   ; program shape 1, set ptr and palette
        BLVC    setptr_shape            ; active point at top-left
        BLVC    clearpointerwindow
        B       exitswi

Pointer0_Code
        MOV     R0,#0
        BL      int_set_pointer_shape

Pointer2_Code
        B       exitswi


;
; Set_Pointer_Shape
; Entry:  R0 = shape number (1-4), or 0 ==> turn pointer off
;         R1 --> shape data
;         R2,R3 = width, height (pixels)
;         R4,R5 = active point (pixels from top-left)
;

SWIWimp_SetPointerShape
        MyEntry "SetPointerShape"

        BL      int_set_pointer_shape
        B       ExitWimp

int_set_pointer_shape
        Push    "LR"
;
        CMP     R0,#0
        AcceptLoosePointer_Neg R1,nullptr,NE,R14
        CMPNE   R1,#nullptr             ; null pointer if = -1
        BEQ     justsetshape
;
        Push    "R0-R5"
        SUB     sp,sp,#12
        MOV     R14,#0
        STRB    R14,[sp,#2+0]           ; reason code 0 ==> set shape
        STRB    R0,[sp,#2+1]            ; shape number
        MOV     R14,R2,ASR #2           ; 4 pixels per byte
        STRB    R14,[sp,#2+2]           ; width (bytes)
        STRB    R3,[sp,#2+3]            ; height (pixels)
        STRB    R4,[sp,#2+4]            ; active point X
        STRB    R5,[sp,#2+5]            ; active point Y
        STR     R1,[sp,#2+6]            ; word-aligned (I hope!)
        MOV     R0,#&15
        ADD     R1,sp,#2                ; to allow word-alignment of ptr
        SWI     XOS_Word
        ADD     sp,sp,#12
        STRVS   R0,[sp]
        Pull    "R0-R5"
        Pull    "PC",VS
;
justsetshape
        MOV     R1,R0                   ; pointer shape
        MOV     R2,#0                   ; pointer linked to mouse
        MOV     R0,#&6A
        SWI     XOS_Byte
        Pull    "PC"


;;-----------------------------------------------------------------------------
;; Rectangle handling routines: intrect, subrect, addrect, addtolist
;;-----------------------------------------------------------------------------

;;------------------------------------
;; Intrect - take a list and a rectangle and produce the intersection
;;
;; Entry :  cx0,cy0,cx1,cy1 = rectangle to clip to
;;          R0 = index of source link pointer
;;          R1 = index of dest. link pointer
;;-------------------------------------

intrect
        Push    "R0,R1,userblk,handle,LR"
        SetRectPtrs
;
        LDR     R14,dx_1                ; ensure coords are aligned to pixels
        BIC     cx0,cx0,R14
        BIC     cx1,cx1,R14
        LDR     R14,dy_1
        BIC     cy0,cy0,R14
        BIC     cy1,cy1,R14
;
        Push    R1                      ; destination list
;
        MOV     R1,R0
        B       endintrect
intrectlp
        getxy   R1,x,y
        max     x0,cx0
        max     y0,cy0
        min     x1,cx1
        min     y1,cy1
        BL      addtolist                       ; add x0,y0,x1,y1 to list
endintrect
        LDR     R1,[rectlinks,R1]
        CMP     R1,#nullptr
        BNE     intrectlp
;
        Pull    R0
        BL      assign                  ; switch to destination list
;
        Pull    "R0,R1,userblk,handle,PC"

;;-----------------------------------------------
;; subrect - take a list and a rectangle and produce the non-intersection
;;
;; Entry :  cx0,cy0,cx1,cy1 = rectangle to clip to
;;          R0 = index of source head link pointer
;;          R1 = index of destination head link pointer
;;------------------------------------------------

subwindowrect
        MOV     R0,#windowrects
        MOV     R1,R0

subrect
;        Debug   opn, "subrect: called with R0,R1,cx0-cy1 =", R0, R1, cx0, cy0, cx1, cy1
        Push    "R0,R1,userblk,handle,LR"
        SetRectPtrs
;
        Push    R1                      ; R1 --> destination list
        BL      addsub                  ; used also by addrect
        Pull    R0
        BL      assign
;
        Pull    "R0,R1,userblk,handle,PC"


;;-----------------------------------------------
;; addrect - take a list and a rectangle and add them together
;;
;; Entry :  cx0,cy0,cx1,cy1 = rectangle to add in
;;          R0 = index of source head link pointer
;;          R1 = index of destination head link pointer
;;------------------------------------------------

addrect
        Push    "R0,R1,userblk,handle,LR"
        SetRectPtrs
;
        Push    R1                      ; R1 --> destination list
        BL      addsub                  ; get non-intersecting part
        Push    "cx0,cy0,cx1,cy1"
        Pull    "x0,y0,x1,y1"
        BL      addtolist               ; then add the rectangle itself
        Pull    R0
        BL      assign
;
        Pull    "R0,R1,userblk,handle,PC"

;;---------------------------
;; addsub - used by both of the above routines
;; Entry :  R0 --> item under consideration
;;          cx0,cy0,cx1,cy1 = rectangle to (not) clip to
;; Exit :   'torects' list updated
;;---------------------------

addsub
        Push    LR
;
        LDR     R14,dx_1                ; ensure coords are aligned to pixels
        BIC     cx0,cx0,R14
        BIC     cx1,cx1,R14
        LDR     R14,dy_1
        BIC     cy0,cy0,R14
        BIC     cy1,cy1,R14
;
        MOV     R1,R0
        B       endaddsublp
addsublp
        ADD     R0,rectcoords,R1,ASL #2
;
        LDMIA   R0,{x0,y0,x1,y1}
        min     y0,cy0                  ; x0,min(y0,cy0),x1,min(y1,cy0)
        min     y1,cy0
        BL      addtolist
;
        LDMIA   R0,{x0,y0,x1,y1}        ; x0,max(y0,cy1),x1,max(y1,cy1)
        max     y0,cy1
        max     y1,cy1
        BL      addtolist
;
        LDMIA   R0,{x0,y0,x1,y1}
        max     y0,cy0                  ; y0 <- max(y0,cy0)
        min     y1,cy1                  ; y1 <- min(y1,cy1)
;
        min     x0,cx0                  ; min(x0,cx0),y0,min(x1,cx0),y1
        min     x1,cx0
        BL      addtolist
;
        LDR     x0,[R0,#0]
        LDR     x1,[R0,#8]
        max     x0,cx1                  ; max(x0,cx1),y0,max(x1,cx1),y1
        max     x1,cx1
        BL      addtolist
;
endaddsublp
        LDR     R1,[rectlinks,R1]
        CMP     R1,#nullptr
        BNE     addsublp
;
        Pull    PC


;;---------------------------------------------------------
;; addtolist - megaroutine that optimises the rectangle combinations
;;
;; Entry :  x0,y0,x1,y1 = rectangle to be added in
;;          rectlinks, rectcoords already set up
;; Exit :   'torects' list updated (and optimised)
;;          all registers preserved
;;---------------------------------------------------------

addtolist
        Push    "cx0,cy0,cx1,cy1,LR"
;
        LDR     R14,BPR_indication
        CMP     R14,#BPR_nullrectops
      [ debugbpr
        BHI     %FT00
        Debug   bpr,"addtolist skipping rectangles reason:",R14
00
      ]
        Pull    "cx0,cy0,cx1,cy1,PC",LS ; In a no rectangle ops situation
;
        ADR     R14,scrx0
        LDMIA   R14,{cx0,cy0,cx1,cy1}
        max     x0,cx0                  ; watch out for screen boundary!
        max     y0,cy0
        min     x1,cx1
        min     y1,cy1
;
        CMP     x0,x1
        CMPLT   y0,y1
        Pull    "cx0,cy0,cx1,cy1,PC",GE ; null rectangle
;
        Push    "R0,R1,x0,y0,x1,y1"
;
addtotop
        MOV     R0,#torects             ; 'previous' link
        LDR     R1,[rectlinks,R0]
        CMP     R1,#nullptr
        BEQ     addtoend                ; done with all rectangles
;
addtolp
        getxy   R1,cx,cy
;
        CMP     x0,cx0
        CMPEQ   x1,cx1
        BNE     tryaddtoy
;
        CMP     y0,cy1
        MOVEQ   y0,cy0
        BEQ     addtogotcha
        CMP     y1,cy0
        MOVEQ   y1,cy1
        BEQ     addtogotcha
tryaddtoy
        CMP     y0,cy0
        CMPEQ   y1,cy1
        BNE     trynextaddto
;
        CMP     x0,cx1
        MOVEQ   x0,cx0
        BEQ     addtogotcha
        CMP     x1,cx0
        MOVEQ   x1,cx1
        BNE     trynextaddto
;
; delete old rectangle from list, and feed new one in at top
;
addtogotcha
        LDR     R14,[rectlinks,R1]
        STR     R14,[rectlinks,R0]              ; link(R0)=link(R1)
        LDR     R14,[rectlinks,#freerects]
        STR     R14,[rectlinks,R1]              ; link(R1)=link(free)
        STR     R1,[rectlinks,#freerects]       ; link(free)=R1
        B       addtotop                        ; add new x0,y0,x1,y1
                                                ; (N.B. cannot be null)
;
trynextaddto
        MOV     R0,R1                           ; remember previous link
        LDR     R1,[rectlinks,R1]
        CMP     R1,#nullptr
        BNE     addtolp
;
; now all we can do is to stuff the new rectangle on the end
;
addtoend
        BL      newrect                         ; coords are x0,y0,x1,y1
        CMP     R1, #nullptr
        STRNE   R1,[rectlinks,R0]               ; link(R0)=R1
;
        Pull    "R0,R1,x0,y0,x1,y1"
        Pull    "cx0,cy0,cx1,cy1,PC"

;;------------------------------------
;; loserects - add list of rectangles to the free list
;; Entry :  R0 = index of head pointer
;;          rectlinks, rectcoords already set up
;;------------------------------------

losewindowrects
        MOV     R0,#windowrects

loserects
        EntryS  "R0,R1,userblk,handle"
        SetRectPtrs
;
        LDR     R1,[rectlinks,R0]               ; R1=link(R0)
        MOV     R14,#nullptr
        STR     R14,[rectlinks,R0]              ; link(R0)=#nullptr
        CMP     R1,#nullptr
        BEQ     endloserects
;
loserectslp
        LDR     R0,[rectlinks,R1]               ; R0=link(R1)
        LDR     R14,[rectlinks,#freerects]
        STR     R14,[rectlinks,R1]              ; link(R1)=link(free)
        STR     R1,[rectlinks,#freerects]       ; link(free)=R1
        MOV     R1,R0                           ; R1 = R0
        CMP     R1,#nullptr
        BNE     loserectslp
endloserects
;
        EXITS                                   ; must preserve flags

;;-------------------------------------
;; assign - move 'torects' list to one pointed to by R0
;;-------------------------------------

      [ ChildWindows
assign_set      ROUT
        Push    "userblk,handle,LR"
        SetRectPtrs
        BL      assign
        Pull    "userblk,handle,PC"
      ]

; NB: This version assumes that SetRectPtrs has already been called

assign
        TEQ     R0,#torects                     ; same list!
        MOVEQ   PC,LR
;
        Push    LR
;
        BL      loserects                       ; preserves R0
        LDR     R14,[rectlinks,#torects]
        STR     R14,[rectlinks,R0]              ; link(R0)=link(torects)
        MOV     R14,#nullptr
        STR     R14,[rectlinks,#torects]        ; link(torects)=#nullptr
;
        Pull    PC

;;------------------------------------------
;; copyrects - copy a set of rectangles
;; Entry :  R0 = source index
;;          R1 = destination index
;; Exit  :  rectangles copied
;;------------------------------------------

      [ ChildWindows

copyrects  Entry  "R0-R2,x0,y0,x1,y1,handle,userblk"

        Debug   opn,"copyrects from/to",R0,R1

        SetRectPtrs

        MOV     R0,R1
        BL      loserects

        LDR     R0,[SP]
        MOV     R2,R1

01      LDR     R0,[rectlinks,R0]
        CMP     R0,#nullptr
        BEQ     %FT90

        getxy   R0,x,y

        Debug   opn,"copying rectangle",x0,y0,x1,y1

        BL      newrect
        CMP     R1,#nullptr
        STRNE   R1,[rectlinks,R2]
        MOVNE   R2,R1
        BNE     %BT01
90
        EXIT
      ]

;;------------------------------------------
;; newrect - get a space from the free list
;; Entry :  x0,y0,x1,y1 = coords to put into entry
;; Exit :   R1 --> new entry
;;                 or nullptr if no rectangle to be had
;;          coords and link are set up
;;          all other registers preserved
;;------------------------------------------

newrect
        Push    LR
;
        LDR     R1,[rectlinks,#freerects]       ; R1=link(free)
        CMP     R1,#nullptr
        BEQ     errnorects
        LDR     R14,[rectlinks,R1]
        STR     R14,[rectlinks,#freerects]      ; link(free)=link(R1)
        MOV     R14,#nullptr
        STR     R14,[rectlinks,R1]              ; link(R1)=#nullptr
;
        putxy   R1,x,y
;
        Pull    PC

errnorects
        BL      initrectptrs                    ; help!
        ; BPR_indication:
        ; 1sttry   -> panicnow
        ; notatall -> gotfullarea
        ; Others shouldn't arrive here, but leave alone anyway
        LDR     R14,BPR_indication
        TEQ     R14,#BPR_1sttry
        MOVEQ   R14,#BPR_panicnow
        TEQ     R14,#BPR_notatall
        MOVEQ   R14,#BPR_gotfullarea
        Debug   bpr,"BPR indication after norect:",R14
        STR     R14,BPR_indication
        MOV     R1,#nullptr
        Pull    PC

;;-----------------------------------------------------------------------
;; listrects - print rectangle list to debug output
;; Entry: R0 = index of header of list to print
;;-----------------------------------------------------------------------

      [ debugopn
listrects
        Entry   "x0-y1, handle, userblk"
        SetRectPtrs
        Debug   opn, "Rectangle list", R0
        B       %FT02
01
        getxy   R0, x, y
        Debug   opn, "Link / x0-y1 =", R0, x0, y0, x1, y1

02      LDR     R0, [rectlinks, R0]
        CMP     R0, #nullptr
        BNE     %BT01
        EXITS
      ]

;;-----------------------------------------------------------------------
;; Zap all rectangle lists and invalidate whole screen
;;-----------------------------------------------------------------------

BPR_startintelligentredraw
        Push    LR
        Debug   bpr,"Starting intelligent redraw"
        MOV     R14,#BPR_1sttry
        STR     R14,BPR_indication
        BL      BPR_invalidatewholescreen
        Pull    PC

BPR_invalidatewholescreen
        Push    LR
        BL      initrectptrs
        ADR     R14,scrx0
        LDMIA   R14,{cx0,cy0,cx1,cy1}
        BL      markinvalid_cx0cy0cx1cy1
        Pull    PC

;;-----------------------------------------------------------------------
;; visibleportion - find rectangle list (visible) for a given window
;;-----------------------------------------------------------------------

      [ Twitter
visibleoutertwitter

        Push    "lr"
        BL      checktwitter
        Pull    "lr"
        ADDNE   r0, handle, #w_x0
        LDMNEIA r0, {x0,y0,x1,y1}
        SUBNE   y0, y0, #2
        ADDNE   y1, y1, #2
        BNE     visibleportion_x0y0x1y1
        ; if twitter not required then drop through to visibleouterportion
      ]

visibleouterportion
        ADD     R0,handle,#w_x0
        B       visibleportion

 [ ThreeDPatch
visibleinnerportion_3D
        ADD     R0,handle,#w_wax0
      [ ChildWindows
        Push    "R1,LR"
        BL      visibleportion_3D
        MOV     R1,#0
        BL      subtract_children       ; don't include children of this window
        Pull    "R1,PC"
      ]

visibleportion_3D
        LDMIA   R0,{x0,y0,x1,y1}        ; get relevant coordinates
	ADD	x0,x0,#4
	ADD	y0,y0,#4
	SUB	x1,x1,#4
	SUB	y1,y1,#4
	B	visibleportion_x0y0x1y1
 ]

visibleinnerportion
        ADD     R0,handle,#w_wax0
      [ ChildWindows
        Push    "R1,LR"
        BL      visibleportion
        MOV     R1,#0
        BL      subtract_children       ; don't include children of this window
        Pull    "R1,PC"
      ]

visibleportion
        LDMIA   R0,{x0,y0,x1,y1}        ; get relevant coordinates

visibleportion_x0y0x1y1
      [ ChildWindows
        Push    "cx0,cy0,cx1,cy1,handle,userblk,LR"
      |
        Push    "cx0,cy0,cx1,cy1,LR"
      ]

        Debug   child,"visibleportion_x0y0x1y1",handle,x0,y0,x1,y1
;
        ADR     R14,scrx0
        LDMIA   R14,{cx0,cy0,cx1,cy1}
;
        LDR     R1,[handle,#w_flags]
;
; create a one-rectangle list in windowrects
;
      [ :LNOT: ChildWindows
        Push    "userblk,handle"
      ]
        SetRectPtrs
;
        max     x0,cx0                  ; off-screen bits are invisible
        max     y0,cy0
        min     x1,cx1
        min     y1,cy1                  ; need this cos not using 'addtolist'
;
        CMP     x0,x1
        CMPLT   y0,y1
        MOVGE   R1,#nullptr
        BGE     vispor1                 ; null list if rectangle is null
;
        TST     R1,#ws_open             ; R1 still = status
        MOVEQ   R1,#nullptr
        BLNE    newrect                 ; coords are x0,y0,x1,y1
;
vispor1
        BL      losewindowrects
        STR     R1,[rectlinks,R0]

      [ :LNOT: ChildWindows
        Pull    "userblk,handle"
        CMP     R1,#nullptr
        Pull    "cx0,cy0,cx1,cy1,PC",EQ ; done if not in stack
      |
        CMP     R1,#nullptr
        Pull    "cx0,cy0,cx1,cy1,handle,userblk,PC",EQ ; done if not in stack
        Pull    "cx0,cy0,cx1,cy1,handle,userblk,LR"
        ; drop through

; go through windows above this one, knocking them out
; In    handle -> window definition
;       [rectlinks,#windowrects] = rectangle(s) so far
; Out   [rectlinks,#windowrects] = visible parts of original set

visible_knockout        ROUT

        Push    "cx0,cy0,cx1,cy1,handle,userblk,LR"

40      LDR     R0,[handle,#w_flags]
        TST     R0,#wf_inborder
        MOVEQ   R0,#nullptr
        LDRNE   R0,[handle,#w_parent]
        CMPNE   R0,#nullptr
        ADDNE   R0,R0,#w_wax0                   ; we'll need to clip non-border siblings to this

        LDR     R2,[handle,#w_active_link + ll_backwards]

41      LDR     R3,[R2,#ll_backwards]
        CMP     R3,#nullptr
        BEQ     %FT45

        Push    "R0,R2,R3"

        CMP     R0,#nullptr
        LDRNE   userblk,[R2,#w_flags-w_active_link]

        ADD     R14,R2,#w_x0-w_active_link
        LDMIA   R14,{cx0,cy0,cx1,cy1}

        BEQ     %FT42

        TST     userblk,#wf_inborder
        BNE     %FT42

        LDMIA   R0,{x0,y0,x1,y1}
        max     cx0,x0
        max     cy0,y0
        min     cx1,x1
        min     cy1,y1
42
        Debug   child,"subtract sibling",cx0,cy0,cx1,cy1
        MOV     R0,#windowrects
        MOV     R1,R0
        BL      subrect
        Pull    "R0,R2,R3"

        MOV     R2,R3
        B       %BT41

45      LDR     userblk,[handle,#w_flags]       ; keep window flags

        LDR     handle,[handle,#w_parent]
        CMP     handle,#nullptr
        BEQ     %FT50

        ; check whether the parent window is closed

        LDR     R14,[handle,#w_flags]
        TST     R14,#ws_open
        BEQ     %FT70

        ; clip window list to the parent's work area or outline

        TST     userblk,#wf_inborder
        ADDNE   R14,handle,#w_x0                ; clip to outer box if allowed to overlap border
        ADDEQ   R14,handle,#w_wax0              ; clip to work area otherwise
        LDMIA   R14,{cx0,cy0,cx1,cy1}
        Debug   child,"clip to parent work area",cx0,cy0,cx1,cy1
        MOV     R0,#windowrects
        MOV     R1,R0
        BL      intrect

        ; now continue by knocking out the siblings of the parent

        B       %BT40

70      BL      losewindowrects                 ; parent closed => so is child

50
        Pull    "cx0,cy0,cx1,cy1,handle,userblk,PC"
      |
        ADRL    R3,activewinds+lh_forwards-ll_forwards
        ADD     R2,handle,#w_active_link        ; Translate to link's address for end check
visporlp
        LDR     R3,[R3,#ll_forwards]
        CMP     R3,R2                           ; Has end been reached (address of active_link is same)
        Pull    "cx0,cy0,cx1,cy1,PC",EQ
;
        Push    "R2,R3"
        ADD     R14,R3,#w_x0-w_active_link
        LDMIA   R14,{cx0,cy0,cx1,cy1}
        MOV     R1,R0
        BL      subrect
        Pull    "R2,R3"
        B       visporlp
      ]

;;-----------------------------------------------------------------------
;; oldvisibleportion - find old visible rectangle list for a given window
;;-----------------------------------------------------------------------

      [ ChildWindows

      [ Twitter
oldvisibleoutertwitter

        Push    "lr"
        BL      checktwitter
        Pull    "lr"
        ADDNE   r0, handle, #w_old_x0
        LDMNEIA r0, {x0,y0,x1,y1}
        SUBNE   y0, y0, #2
        ADDNE   y1, y1, #2
        BNE     oldvisibleportion_x0y0x1y1
        ; if twitter not required then drop through to oldvisibleouterportion
      ]

oldvisibleouterportion
        ADD     R0,handle,#w_old_x0
        B       oldvisibleportion

oldvisibleinnerportion
        ADD     R0,handle,#w_old_wax0

        Push    "R1,LR"
        BL      oldvisibleportion
        MOV     R1,#0                   ; subtract all children
        BL      oldsubtract_children    ; don't include children of this window
        Pull    "R1,PC"

oldvisibleportion
        LDMIA   R0,{x0,y0,x1,y1}        ; get relevant coordinates

oldvisibleportion_x0y0x1y1
        Push    "cx0,cy0,cx1,cy1,handle,userblk,LR"

        Debug   child,"oldvisibleportion_x0y0x1y1",handle,x0,y0,x1,y1

        ADR     R14,scrx0
        LDMIA   R14,{cx0,cy0,cx1,cy1}

        LDR     R1,[handle,#w_old_flags]

; create a one-rectangle list in windowrects

        SetRectPtrs

        max     x0,cx0                  ; off-screen bits are invisible
        max     y0,cy0
        min     x1,cx1
        min     y1,cy1                  ; need this cos not using 'addtolist'

        CMP     x0,x1
        CMPLT   y0,y1
        MOVGE   R1,#nullptr
        BGE     %FT01                   ; null list if rectangle is null

        TST     R1,#ws_open             ; R1 still = status
        MOVEQ   R1,#nullptr
        BLNE    newrect                 ; coords are x0,y0,x1,y1

01      BL      losewindowrects
        STR     R1,[rectlinks,R0]

        CMP     R1,#nullptr
        Pull    "cx0,cy0,cx1,cy1,handle,userblk,PC",EQ ; done if not in stack
        Pull    "cx0,cy0,cx1,cy1,handle,userblk,LR"
        ; drop through

; go through windows above this one, knocking them out
; In    handle -> window definition
;       [rectlinks,#windowrects] = rectangle(s) so far
; Out   [rectlinks,#windowrects] = visible parts of original set

oldvisible_knockout     ROUT

        Push    "cx0,cy0,cx1,cy1,handle,userblk,LR"

40      LDR     R0,[handle,#w_old_flags]
        TST     R0,#wf_inborder
        MOVEQ   R0,#nullptr
        LDRNE   R0,[handle,#w_old_parent]
        CMPNE   R0,#nullptr
        ADDNE   R0,R0,#w_old_wax0                ; we'll need to clip non-border siblings to this

        LDR     R2,[handle,#w_old_link + ll_backwards]

41      LDR     R3,[R2,#ll_backwards]
        CMP     R3,#nullptr
        BEQ     %FT45

        Push    "R0,R2,R3"

        CMP     R0,#nullptr
        LDRNE   userblk,[R2,#w_old_flags-w_old_link]

        ADD     R14,R2,#w_old_x0-w_old_link
        LDMIA   R14,{cx0,cy0,cx1,cy1}

        BEQ     %FT42

        TST     userblk,#wf_inborder
        BNE     %FT42

        LDMIA   R0,{x0,y0,x1,y1}
        max     cx0,x0
        max     cy0,y0
        min     cx1,x1
        min     cy1,y1
42
        Debug   child,"subtract sibling",cx0,cy0,cx1,cy1
        MOV     R0,#windowrects
        MOV     R1,R0
        BL      subrect
        Pull    "R0,R2,R3"

        MOV     R2,R3
        B       %BT41

45      LDR     userblk,[handle,#w_old_flags]

        LDR     handle,[handle,#w_old_parent]
        CMP     handle,#nullptr
        BEQ     %FT50

        ; check whether the parent window was closed

        LDR     R14,[handle,#w_old_flags]
        TST     R14,#ws_open
        BEQ     %FT70

        ; clip window list to the parent's work area or outline

        TST     userblk,#wf_inborder
        ADDNE   R14,handle,#w_old_x0            ; clip to parent's outline if child can go in border
        ADDEQ   R14,handle,#w_old_wax0          ; clip to parent's work area otherwise
        LDMIA   R14,{cx0,cy0,cx1,cy1}
        Debug   child,"clip to parent work area",cx0,cy0,cx1,cy1
        MOV     R0,#windowrects
        MOV     R1,R0
        BL      intrect

        ; now continue by knocking out the siblings of the parent

        B       %BT40

70      BL      losewindowrects                 ; parent closed => so is child

50
        Pull    "cx0,cy0,cx1,cy1,handle,userblk,PC"
      ]

;;--------------------------------------------------------------------------
;; subtract_children - remove child windows' outer rectangles from windowrects
;; In:  R1 = 0 => subtract all child windows
;;      R1 = wf_inborder => subtract border children only
;;      handle -> parent window
;;      [windowrects] set up (already within work area of parent)
;; Out: [windowrects] updated
;;--------------------------------------------------------------------------

      [ ChildWindows

subtract_children ROUT

        Push    "cx0,cy0,cx1,cy1,handle,LR"

        Debug   child,"Subtract children",handle

        LDR     handle,[handle,#w_children+lh_forwards]

10      LDR     R14,[handle,#ll_forwards]
        CMP     R14,#nullptr                                    ; Has end been reached?
        BEQ     %FT20

        LDR     cx0,[handle,#w_flags - w_active_link]
        AND     cx0,cx0,R1                                      ; don't do it if R1<>0 and bit not set
        TEQ     cx0,R1
        ADDEQ   R14,handle,#w_x0 - w_active_link
        LDMEQIA R14,{cx0,cy0,cx1,cy1}
        Debug   child,"Subtracting child window rectangle",handle,cx0,cy0,cx1,cy1
        Push    "R1"
        BLEQ    subwindowrect
        Pull    "R1"

        LDR     handle,[handle,#ll_forwards]
        B       %BT10
20
        Pull    "cx0,cy0,cx1,cy1,handle,PC"

;...........................................................................

; In    R1 = 0 => subtract all child windows
;       R1 = wf_inborder => subtract border children only
;       handle -> parent window
;       windowrects = rectangle list to subtract children from (already less than work area)
; Out   unclipped old outer rectangles of relevant children subtracted from rectangle list
;       we assume there's no need to clip the child rectangles, as the rectangle list is already clipped to it

oldsubtract_children ROUT

        Push    "cx0,cy0,cx1,cy1,handle,LR"

        Debug   child,"Old Subtract children",handle

        LDR     handle,[handle,#w_old_children+lh_forwards]

10      LDR     R14,[handle,#ll_forwards]
        CMP     R14,#nullptr                             ; Has end been reached?
        BEQ     %FT20

        LDR     cx0,[handle,#w_old_flags - w_old_link]
        AND     cx0,cx0,R1                                      ; don't do it if R1<>0 and bit not set
        TEQ     cx0,R1
        ADDEQ   R14,handle,#w_old_x0 - w_old_link
        LDMEQIA R14,{cx0,cy0,cx1,cy1}
        Debug   child,"Subtracting OLD child window rectangle",handle,cx0,cy0,cx1,cy1
        Push    "R1"
        BLEQ    subwindowrect
        Pull    "R1"

        LDR     handle,[handle,#ll_forwards]
        B       %BT10
20
        Pull    "cx0,cy0,cx1,cy1,handle,PC"

;...........................................................................

; In    handle -> parent window
;       R0 = rectangle list to subtract children from
; Out   clipped new outer rectangles of OPENING children subtracted from rectangle list
;       R1 corrupted
; Note: We must also deal with opening grandchildren, where the windows in between aren't in the opening list
;       This causes problems, as we could otherwise end up with overlapping rectangles to be copied
; Note: If a parent is opening/closing, all descendents are removed from the opening list in remove_children

subtract_openingchildren ROUT

        Push    "cx0,cy0,cx1,cy1,x0,y0,x1,y1,handle,userblk,LR"

        Debug   child,"Subtract opening children",handle

        MOV     R1,R0                                   ; modify same rectangle list
        MOV     userblk,handle                          ; userblk -> original window

        LDR     handle, openingwinds + lh_forwards
10
        ASSERT  ll_forwards = 0
        LDR     R14,[handle],#-w_opening_link
        CMP     R14,#nullptr                            ; Has end been reached?
        BEQ     %FT20

        LDR     R2,[handle,#w_parent]
        B       %FT14

12      LDR     R14,[R2,#w_opening_link + ll_forwards]
        TEQ     R14,#0
        BNE     %FT15                                   ; if intervening window is opening anyway, we can ignore this one

        LDR     R2,[R2,#w_parent]

14      CMP     R2,userblk
        BEQ     %FT25

        CMP     R2,#nullptr
        BNE     %BT12

15      LDR     handle,[handle,#w_opening_link + ll_forwards]
        B       %BT10
20
        Pull    "cx0,cy0,cx1,cy1,x0,y0,x1,y1,handle,userblk,PC"

; we've found a child window in the opening list that's a descendent of the window in question

25
        Push    "handle"

        ADD     R14,handle,#w_x0
        LDMIA   R14,{cx0,cy0,cx1,cy1}                   ; cx0,cy0,cx1,cy1 = outline of child

27      LDR     R14,[handle,#w_flags]
        TST     R14,#wf_inborder                        ; if child can live in parent's border,
        LDR     handle,[handle,#w_parent]
        ADDNE   R14,handle,#w_x0
        ADDEQ   R14,handle,#w_wax0
        LDMIA   R14,{x0,y0,x1,y1}                       ; x0,y0,x1,y1 = work area or outline of parent

        max     cx0,x0
        max     cy0,y0
        min     cx1,x1
        min     cy1,y1

        CMP     handle,userblk                          ; keep clipping to intervening windows
        BNE     %BT27

        Pull    "handle"

        Debug   child,"Subtracting opening child window rectangle",handle,cx0,cy0,cx1,cy1
     [ true                                             ; BJGA bugfix
        CMP     cx0, cx1                                ; optimise out these cases -
        CMPLT   cy0, cy1                                ; they are unnecessary, and can cause intermittent bugs
        BLLT    subrect
     |
        BL      subrect
     ]

        LDR     handle,[handle,#w_opening_link + ll_forwards]
        B       %BT10

;...........................................................................

; In    handle -> parent window
;       R0 = rectangle list to subtract children from
; Out   clipped old outer rectangles of OPENING children subtracted from rectangle list
;       R1 corrupted

oldsubtract_openingchildren ROUT

        Push    "cx0,cy0,cx1,cy1,x0,y0,x1,y1,handle,userblk,LR"

        Debug   child,"Old Subtract opening children",handle

        MOV     R1,R0                                   ; modify same rectangle list
        MOV     userblk,handle                          ; userblk -> original window

        LDR     handle, openingwinds + lh_forwards
10
;      [ debugopn
;        Push    "R0, R1, rectcoords, rectlinks"
;        SetRectPtrs
;        MOV     R0, #borderrects
;        LDR     R0, [rectlinks, R0]
;        LDR     R1, [sp, #2*4] ; get handle from stack
;        Debug   opn, "oldsubtract_openingchildren: next handle, borderrects =", R1, R0
;        Pull    "R0, R1, rectcoords, rectlinks"
;      ]
        ASSERT  ll_forwards = 0
        LDR     R14,[handle],#-w_opening_link
        CMP     R14,#nullptr                            ; Has end been reached?
        BEQ     %FT20

        LDR     R2,[handle,#w_old_parent]
        B       %FT14

12      LDR     R14,[R2,#w_opening_link + ll_forwards]
        TEQ     R14,#0                                  ; shouldn't that be CMP R14, #nullptr?  BJGA Apr98
        BNE     %FT15                                   ; if intervening window is opening anyway, we can ignore this one

        LDR     R2,[R2,#w_old_parent]

14      ; handle = valid handle from openingwinds
        ; R2     = handle's old parent / old ancestor
;      [ debugopn
;        Push    "R0, R1, rectcoords, rectlinks"
;        SetRectPtrs
;        MOV     R0, #borderrects
;        LDR     R0, [rectlinks, R0]
;        LDR     R1, [sp, #2*4] ; get handle from stack
;        Debug   opn, "oldsubtract_openingchildren: borderrects, handle, ancestor =", R0, R1, R2
;        Pull    "R0, R1, rectcoords, rectlinks"
;      ]
        CMP     R2,userblk
        BEQ     %FT25

        CMP     R2,#nullptr
        BNE     %BT12

15      LDR     handle,[handle,#w_opening_link + ll_forwards]
        B       %BT10
20
;      [ debugopn
;        Push    "R0, rectcoords, rectlinks"
;        SetRectPtrs
;        MOV     R0, #borderrects
;        LDR     R0, [rectlinks, R0]
;        Debug   opn, "oldsubtract_openingchildren: opening list scan complete, borderrects =", R0
;        Pull    "R0, rectcoords, rectlinks"
;      ]
        Pull    "cx0,cy0,cx1,cy1,x0,y0,x1,y1,handle,userblk,PC"

; we've found a child window in the opening list that's a descendent of the window in question

25
;      [ debugopn
;        Push    "R0, R1, rectcoords, rectlinks"
;        SetRectPtrs
;        MOV     R0, #borderrects
;        LDR     R0, [rectlinks, R0]
;        LDR     R1, [sp, #2*4] ; get handle from stack
;        Debug   opn, "oldsubtract_openingchildren: found a descendent, borderrects, handle =", R0, R1
;        Pull    "R0, R1, rectcoords, rectlinks"
;      ]
        Push    "handle"

        ADD     R14,handle,#w_old_x0
        LDMIA   R14,{cx0,cy0,cx1,cy1}                   ; cx0,cy0,cx1,cy1 = outline of child

27      LDR     R14,[handle,#w_old_flags]
        TST     R14,#wf_inborder                        ; if child can live in parent's border,
        LDR     handle,[handle,#w_old_parent]
        ADDNE   R14,handle,#w_old_x0
        ADDEQ   R14,handle,#w_old_wax0
        LDMIA   R14,{x0,y0,x1,y1}                       ; x0,y0,x1,y1 = work area or outline of parent

        max     cx0,x0
        max     cy0,y0
        min     cx1,x1
        min     cy1,y1

        CMP     handle,userblk                          ; keep clipping to intervening windows
        BNE     %BT27

        Pull    "handle"

        Debug   child,"Old Subtracting opening child window rectangle",handle,cx0,cy0,cx1,cy1
;      [ debugopn
;        Push    "R0, rectcoords, rectlinks"
;        SetRectPtrs
;        MOV     R0, #borderrects
;        LDR     R0, [rectlinks, R0]
;        Debug   opn, "oldsubtract_openingchildren: before subrect, borderrects =", R0
;        Pull    "R0, rectcoords, rectlinks"
;      ]
     [ true                                             ; BJGA bugfix
        CMP     cx0, cx1                                ; optimise out these cases -
        CMPLT   cy0, cy1                                ; they are unnecessary, and can cause intermittent bugs
        BLLT    subrect
     |
        BL      subrect
     ]
;      [ debugopn
;        Push    "R0, rectcoords, rectlinks"
;        SetRectPtrs
;        MOV     R0, #borderrects
;        LDR     R0, [rectlinks, R0]
;        Debug   opn, "oldsubtract_openingchildren: after subrect,  borderrects =", R0
;        Pull    "R0, rectcoords, rectlinks"
;      ]

        LDR     handle,[handle,#w_opening_link + ll_forwards]
        B       %BT10
      ]

;;--------------------------------------------------------------------------
;; invalidportion - get rectangle(s) within window that need updating
;; assume that any windows above this one have already been processed
;;--------------------------------------------------------------------------

invalidouterportion ROUT
        ADD     R0,handle,#w_x0
        B       invalidportion

invalidinnerportion
        ADD     R0,handle,#w_wax0

invalidportion
        LDMIA   R0,{cx0,cy0,cx1,cy1}
        MOV     R0,#invalidrects
        MOV     R1,#windowrects         ; R0,R1 = source/dest. lists
        B       intrect

;
; markvalid - having processed this window, mark its area as valid
;

markvalid
        ADD     R0,handle,#w_x0
        LDMIA   R0,{cx0,cy0,cx1,cy1}
        MOV     R0,#invalidrects
        MOV     R1,R0
        B       subrect

;
; markinvalid - add window rectangle to the invalid list
;

markinvalid
        ADD     R0,handle,#w_x0
        LDMIA   R0,{cx0,cy0,cx1,cy1}
markinvalid_cx0cy0cx1cy1
        MOV     R0,#invalidrects
        MOV     R1,R0
        B       addrect


;;----------------------------------------------------------------------------
;; markinvalidrects - add 'windowrects' list to the invalid list
;;----------------------------------------------------------------------------

markinvalidrects  ROUT
        EntryS  "R0,R1,userblk,handle"
    [ ChildWindows
        MOV     R0,#invalidrects
      [ false   ; I don't think we actually need this one after all
        B       %FT01

markoldinvalidrects
        ALTENTRY
        MOV     R0,#oldinvalidrects
01
      ]
    ]
        SetRectPtrs

        MOV     R1,#windowrects
        B       endaddrectslp
addrectslp
        Push    R1
        getxy   R1,cx,cy
      [ :LNOT: ChildWindows
        MOV     R0,#invalidrects
      ]
        MOV     R1,R0                           ; dest. = source
        BL      addrect
        Pull    R1
endaddrectslp
        LDR     R1,[rectlinks,R1]               ; get first rectangle
        CMP     R1,#nullptr
        BNE     addrectslp

        EXITS                                   ; must preserve flags

;;------------------------------------------
;; subtract one rectangle list from another
;; Entry :  R0 --> first list
;;          R1 --> second list
;; Exit :   R0 --> (R0)-(R1)
;;------------------------------------------

subrects
        Push    "R0,R1,userblk,handle,LR"
        SetRectPtrs
;
        B       endsubrectslp
subrectslp
        Push    "R0,R1"
        getxy   R1,cx,cy
        MOV     R1,R0                           ; dest. = source
        BL      subrect
        Pull    "R0,R1"
endsubrectslp
        LDR     R1,[rectlinks,R1]               ; get first rectangle
        CMP     R1,#nullptr
        BNE     subrectslp
;
        Pull    "R0,R1,userblk,handle,PC"

;;------------------------------------------
;; intersect one rectangle list with another
;; Entry :  R0 --> first list
;;          R1 --> second list
;; Exit :   R0 --> (R0) int (R1)
;;------------------------------------------

intrects
        Push    "R0,R1,userblk,handle,LR"
        SetRectPtrs
;
        B       endintrectslp
intrectslp
        Push    "R0,R1"
        getxy   R1,cx,cy
        MOV     R1,#torects                     ; add list to 'torects'
        BL      intrect
        Pull    "R0,R1"
endintrectslp
        LDR     R1,[rectlinks,R1]               ; get first rectangle
        CMP     R1,#nullptr
        BNE     intrectslp
;
        BL      assign                          ; move list to right place
;
        Pull    "R0,R1,userblk,handle,PC"

;------------------------------------------------------------------------------
; in    R0 -> source string (null terminated)
;       R1 -> destination buffer
; out   R0,R1 -> after strings
;------------------------------------------------------------------------------

copy0
        Push    "LR"
01
        LDRB    R14,[R0],#1
        STRB    R14,[R1],#1
        CMP     R14,#32
        BHS     %BT01

        SUB     R1,R1,#1
;
        Pull    "PC"

;------------------------------------------------------------------------------
; in    R0 -> string
; out   R0 -> terminator
;       R1 = length of string including terminator
;------------------------------------------------------------------------------

count0
        Push    "LR"
        MOV     R1,R0
01
        LDRB    R14,[R1],#1
        CMP     R14,#32
        BHS     %BT01

        SUB     R1,R1,R0
;
        Pull    "PC"

WimpKillSprite_Code
        Push    "r12,LR"
        LDR     r12,[r12]
        STR     R0,spritename
        MOV     R0,#1
        STR     R0,thisCBptr
        STR     R0,lengthflags
        MOV     R0,#SpriteReason_DeleteSprite
        BL      wimp_SpriteOp

        [ windowsprite
	 [ ThreeDPatch
        MOVVC   R0,#0
	BLVC	reset_all_tiling_sprites
	 |
        MOVVC   R0,#-1
        STRVC   R0,tiling_sprite
         ]
        ]
        BLVC    freelist                ; mark list invalid

        [ false
        BVS     %FT02
        MOV     R14,#ms_data            ; message block size
        STR     R14,[sp,#-ms_data]!
        MOV     R14,#0                  ; your_ref
        STR     R14,[sp,#ms_yourref]
        LDR     R14,=Message_IconsChanged
        STR     R14,[sp,#ms_action]
        MOV     R0,#User_Message
        MOV     R1,sp
        MOV     R2,#0                   ; broadcast message
        BL      int_sendmessage_fromwimp
        ADD     sp,sp,#ms_data
        CLRV                            ; ignore errors
02
        ]
        Pull    "r12,PC"

 [ ThreeDPatch

	ROUT
00
	DCB	"3DWindowBorders=3DWB/S,TexturedMenus=TM/S,UseAlternateMenuBg=UAMB/S,RemoveIconBoxes=RIB/S,"
	DCB	"NoIconBoxesInTransWindows=NIBITW/S,Fully3DIconBar=F3DIB/S,All=A/S,"
	DCB	"WindowBorderFaceColour=WBFC/E,WindowBorderOppColour=WBOC/E,"
	DCB	"MenuBorderFaceColour=MBFC/E,MenuBorderOppColour=MBOC/E,"
	DCB	"NoFontBlending=NFB/S,FontBlending=FB/S,"
	DCB     "WindowOutlineColour=WOC/E,WindowOutlineOver=WOO/S",0
	ALIGN

WimpVisualFlags_Code
	Push	"r12,lr"
	LDR	r12,[r12]

	TEQ	r1,#0
	MOVEQ   r1,# :NOT: ThreeDFlags_All
	STREQ	r1,ThreeDFlags		; if no options are supplied then turn everything off
	MOVEQ   lr,#arrowIconWidth_No3D
	STREQB  lr,arrowIconWidth
	Pull	"r12,pc",EQ

	SUB	sp,sp,#256
	MOV	r1,r0
	ADR	r0,%BT00
	MOV	r2,sp
	MOV	r3,#256
	SWI	XOS_ReadArgs
	ADDVS	sp,sp,#256
	Pull	"r12,pc",VS

	MOV	r2,# :NOT: ThreeDFlags_All
	LDR	r1,[sp,#0]
	TEQ	r1,#0
	ORRNE	r2,r2,#ThreeDFlags_Use3DBorders
	MOVEQ   lr,#arrowIconWidth_No3D
	MOVNE   lr,#arrowIconWidth_3D
	STRB    lr,arrowIconWidth
	LDR	r1,[sp,#4]
	TEQ	r1,#0
	ORRNE	r2,r2,#ThreeDFlags_TexturedMenus
	LDR	r1,[sp,#8]
	TEQ	r1,#0
	ORRNE	r2,r2,#ThreeDFlags_UseAlternateMenuTexture
	LDR	r1,[sp,#12]
	TEQ	r1,#0
	ORRNE	r2,r2,#ThreeDFlags_RemoveIconBackgrounds
	LDR	r1,[sp,#16]
	TEQ	r1,#0
	ORRNE	r2,r2,#ThreeDFlags_NoIconBgInTransWindows
	LDR	r1,[sp,#20]
	TEQ	r1,#0
	ORRNE	r2,r2,#ThreeDFlags_Fully3DIconBar
;	LDR	r1,[sp,#44]
;	TEQ	r1,#0
;	ORRNE	r2,r2,#ThreeDFlags_NoFontBlending ; bit is already set!
	LDR	r1,[sp,#48]
	TEQ	r1,#0
	BICNE	r2,r2,#ThreeDFlags_NoFontBlending

	LDR	r1,[sp,#56]
	TEQ	r1,#0
	ORRNE	r2,r2,#ThreeDFlags_WindowOutlineOver

	LDR	r1,[sp,#28]		; window border face colour
	BL	%FT02
	LDRNE	r0,=rgb_white
	STR	r0,truewindowborderfacecolour

	LDR	r1,[sp,#32]		; window border opposite colour
	BL	%FT02
	LDRNE	r0,=rgb_middarkgrey
	STR	r0,truewindowborderoppcolour

	LDR	r1,[sp,#36]		; menu border face colour
	BL	%FT02
	LDRNE	r0,=rgb_white
	STR	r0,truemenuborderfacecolour

	LDR	r1,[sp,#40]		; menu border opposite colour
	BL	%FT02
	LDRNE	r0,=rgb_midlightgrey
	STR	r0,truemenuborderoppcolour

	LDR	r1,[sp,#52]		; window outline colour
	BL	%FT02
	LDRNE	r0,=rgb_black
	STR	r0,truewindowoutlinecolour

	LDR	r1,[sp,#24]		; all
	TEQ	r1,#0
	MOVNE	r2,#ThreeDFlags_All
	MOVNE   lr,#arrowIconWidth_3D
	STRNEB  lr,arrowIconWidth

01	ADD	sp,sp,#256
	STR	r2,ThreeDFlags

	Pull	"r12,pc"

02	; subroutine
	; r1 = ptr to int returned from OS_ReadArgs
	; returns, r0 = 24 bit RGB value
	; EQ if it is valid
	Push	"lr"
	TEQ	r1,#0
	BNE	%FT03
	TEQ	pc,#0
	Pull	"pc"

03	LDRB	r0,[r1],#1
	TEQ	r0,#0                   ; type = integer
	Pull	"pc",NE

	LDRB	lr,[r1,#2]
	MOV	r0,lr,LSL #8
	LDRB	lr,[r1,#1]
	ORR	r0,r0,lr,LSL #16
	LDRB	lr,[r1,#0]
	ORR	r0,r0,lr,LSL #24

	TEQ	r0,r0
	Pull	"pc"
 ]

        END
