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
; > Wimp10

;;-----------------------------------------------------------------------------
;; Icon border plotting routines / Window Border plotting routines
;;-----------------------------------------------------------------------------

;;-----------------------------------------------------------------------------
;; getborder - attempt to parse the validation string for the border number
;; and the highlight value.
;;
;; in   R1 = icon flags
;;      R3 -> validation string
;; out  R0 = border number to be used (always valid!)
;;      [border_type] => type of border to plot
;;      [border_highlight] => border highlight colour
;;-----------------------------------------------------------------------------

getborder EntryS "R2,R4-R5"

        Debug   bo,"getborder: icon flags, vstring, caller ",R1,R3,R14

        MOV     R4,#border_normal
        MOV     R5,#sc_midlightgrey     ; default values

        TST     R1,#if_text
        TSTNE   R1,#if_indirected
        BEQ     %FT11                   ; if not indirected + text then ignore
;
        AcceptLoosePointer_NegOrZero R3,-1
        CMP     R3,R3,ASR #31           ; is there a validation specified?
        BEQ     %10                     ; if not valid then skip
        MOV     R2,#WimpValidation_Border
        BL      findcommand
        BNE     %10                     ; if not present then skip
;
        BL      getnumber               ; get the border number
        MOV     R4,R0                   ; Defaults to zero
;
        LDRB    R14,[R3],#1             ; and then the next character
        TEQ     R14,#","
        BLEQ    getnumber               ; if its a comma, ie. following number get the highlight colour
        MOVEQ   R5,R0
10
        [ slabinout
        CMP     R4,#border_slabout
        BNE     %FT11
        TST     R1,#if_sprite
        BEQ     %FT11
        LDR     R4,two_sprite_save
;        EOR     R4,R4,R1                ; have flags been muddled with?
        TST     R4,#is_inverted
        MOVNE   R4,#border_slabin
        MOVEQ   R4,#border_slabout
        ]
11
        CMP     R4, #border_max         ; trap undefined cases immediately
        MOVHS   R4, #border_normal
        STR     R4,border_type
        STR     R5,border_highlight     ; setup the border + its highlight colour

        Debug   bo,"type,highlight",R4,R5

        MOV     R0,R4                   ; => border being used
        EXITS


;;-----------------------------------------------------------------------------
;; Adjust a set of co-ordinates based on the border size specified in R0.
;;
;; in   R0 = border type
;;      R1 = flags for icon
;;      x0-y1 => bounding box to be adjusted
;; out  R0 corrupt
;;      x0-y0 => snapped to inside of bounding box
;;-----------------------------------------------------------------------------

adjustforborder Entry "R1"

        TST     R1,#if_border           ; does the icon have a border?
        EXIT    EQ                      ; return if not

        TEQ     R0,#border_editable
        TEQNE   R0,#border_normal       ; this icons need an extra pixel removing
        LDREQ   R14,dx
        ADDEQ   x0,x0,R14
        SUBEQ   x1,x1,R14
        LDREQ   R14,dy
        ADDEQ   y0,y0,R14
        SUBEQ   y1,y1,R14               ; adjust by a single pixel borderness

        ADR     R1,sizetables
        LDRB    R0,[R1,R0]              ; get adjustment factor
        BL      adjust_bbox             ; snap to grid and then adjust by value in R0

        EXIT                            ; haven't corrupted C or V

sizetables      =  0,4,4,8,8,4,12,8

        ASSERT  ?sizetables =border_max


;;-----------------------------------------------------------------------------
;; various slab plotting routines.
;;
;; in   R1 = flags for icon
;;      x0-y1 => bounding box of the icon
;; out  -
;;-----------------------------------------------------------------------------

plot_slabin
        ADR     R3,ct_in
        B       plot_slab               ; draw 'slabbed in' region

plot_slabout
        ADR     R3,ct_out
        B       plot_slab               ; draw 'slabbed out' region

plot_editable Entry

        BL      plot_slabin             ; first slab
        ADR     R3,ct_grey
        BL      plot_slab

      [ TrueIcon2
        BL      icon_fg
        BL      hollowrectangle
      |
        TST     R1,#is_shaded           ; Icon disabled?
        BNE     %FT10                   ; Yes then no black border

        MOV     R0,#sc_black
        BL      int_setcolour           ; then a rectangle that is in black
        BL      hollowrectangle
10
      ]
        LDR     R0,dx
        ADD     x0,x0,R0
        SUB     x1,x1,R0
        LDR     R0,dy
        ADD     y0,y0,R0
        SUB     y1,y1,R0                ; acount for missing single pixel border (black jobbie)

        EXIT

plot_ridge Entry

        ADR     R3,ct_outshallow        ; ridge is made from two slabs, slab out and then in
        BL      plot_slab
        ADR     R3,ct_inshallow
        BL      plot_slab

        EXIT

plot_channel Entry

        ADR     R3,ct_inshallow         ; channel made from two slabs, slab in, slab out
        BL      plot_slab
        ADR     R3,ct_outshallow
        BL      plot_slab

        EXIT

plot_default Entry

        BL      plot_slabin             ; slab in
        ADR     R3,ct_cream
        BL      plot_slab               ; cream moat

        BL      plot_action             ; followed by an action button

        EXIT

plot_action

        TST     R1,#is_inverted
        BEQ     plot_slabout            ; action buttons are simply slabbed out
        BNE     plot_slabin



;;-----------------------------------------------------------------------------
;; plot_slab - plot a slab around the specified region using a colour table
;; supplied.
;;
;; in   R3 -> colour table
;;      x0-y1 co-ordinates to put the slab at
;; out  x0-y1 updated to reflect new bounding box
;;      R0-R3 preserved
;;-----------------------------------------------------------------------------

plot_slab Entry "R0-R4"

        BL      snap_coords             ; ensure snapped to a nice boundary

      [ fixslabalignment
        SUB     x1,x1,#1
        SUB     y1,y1,#1                ; adjust x1 and y1 to be inclusive

        ASSERT  :INDEX:dy - :INDEX:dx = 4
        ADR     R14,dx
        LDMIA   R14,{R0,R4}             ; get dx and dy
        TEQ     R0,#2
        TEQEQ   R4,#4
        BEQ     plot_slab_24

        CMP     R0,R4
        MOVLT   R4,R0                   ; R4 = smaller of dx and dy

        BL      render_bbox             ; plot first rectangle (at given coordinates)

        MOV     R0,#1
        BL      adjust_bbox             ; adjust the bounding box to cover reduced area

        CMP     R4,#1
        BLEQ    render_bbox             ; then fill again (but only if EX0 or EY0)

        MOV     R0,#1
        BL      adjust_bbox             ; adjust again
        BL      render_bbox             ; then fill again

        MOVEQ   R0,#1
        BLEQ    adjust_bbox             ; fill final line if hires
        BLEQ    render_bbox

        MOVEQ   R0,#1
        MOVNE   R0,#2
        BL      adjust_bbox             ; and finally return with adjust bounding box

        ADD     x1,x1,#1                ; adjust X1,Y1 to be exclusive again
        ADD     y1,y1,#1
      |
        LDR     R0,dx                   ; adjust X1,Y1 not to be inclusive
        SUB     x1,x1,R0
        LDR     R1,dy
        SUB     y1,y1,R0

        BL      render_bbox             ; plot first rectangle (at given coordinates)
        MOV     R0,#2
        BL      adjust_bbox             ; adjust the bounding box to cover reduced area

        BL      render_bbox             ; then fill again
        MOV     R0,#2
        BL      adjust_bbox             ; and finally return with adjust bounding box

        LDR     R0,dx                   ; adjust X1,Y1 not to be inclusive
        ADD     x1,x1,R0
        LDR     R1,dy
        ADD     y1,y1,R0
      ]

        EXIT

      [ fixslabalignment

;; special case of plot_slab for good, old-fashioned rectangular pixel modes.
;; It draws the bottom left and top right corners a bit more nicely
plot_slab_24
        MOV     R0,#2
        BL      adjust_bbox             ; draw inner line first
        BL      render_bbox
        MOV     R0,#-2
        BL      adjust_bbox
        BL      render_bbox             ; then outer line
        MOV     R0,#4
        BL      adjust_bbox             ; adjust final bounding box
        ADD     x1,x1,#1
        ADD     y1,y1,#1                ; restore original x1,y1
        EXIT
      ]


;;-----------------------------------------------------------------------------
;; snap_coords - snap coordinates to suitable OS unit boundaries for this
;;
;; in   x0-y1 => co-ordinates to align to a nice boundary
;; out  x0-y1 => co-ordinates having been aligned
;;-----------------------------------------------------------------------------

snap_coords
        LDR     R0,dx_1
        BIC     x0,x0,R0                ; align X0 back to nice grid point
      [ :LNOT:fixslabalignment
        ADD     x1,x1,R0
      ]
        BIC     x1,x1,R0                ; align X1 out to the next grid point

        LDR     R0,dy_1
        BIC     y0,y0,R0                ; align Y0 back to nice grid point
      [ :LNOT:fixslabalignment
        ADD     y1,y1,R0
      ]
        BIC     y1,y1,R0                ; align Y1 out to the next grid point

        MOV     PC,LR


;;-----------------------------------------------------------------------------
;; adjust_bbox - adjust all four co-ordinates by the specified value.
;;
;; in   R0 = adjustment factor in OS_Units
;;      x0-y1 => co-ordinates to massarge
;; out  x0-y1 => co-ordinates suitable tinkered with
;;-----------------------------------------------------------------------------

adjust_bbox ROUT
        ADD     x0,x0,R0                ; adjust x0,y0
        ADD     y0,y0,R0
        SUB     x1,x1,R0                ; adjust x1,y1
        SUB     y1,y1,R0
        MOV     PC,LR                   ; have preserved flags


;;-----------------------------------------------------------------------------
;; render_bbox - draw a rectangle around the specified co-ordinates, using the
;; byte array of colours for each of the four sides.
;;
;; in   R3 -> colour table (array)
;;      R4-R7 co-ordinates x0-y1.
;; out  -
;;-----------------------------------------------------------------------------

render_bbox EntryS "R3"

        MOV     R0,#4
        MOV     R1,x0
        MOV     R2,y0
        SWI     XOS_Plot                ; attempt to move to the bottom left

        MOV     R1,x1
        BL      render_line             ; plot along the bottom
        MOV     R2,y1
        BL      render_line             ; then up the right
        MOV     R1,x0
        BL      render_line             ; back across the top
        MOV     R2,y0
        BL      render_line             ; and then down back to the start

        EXITS                           ; must preserve flags

;..............................................................................

; render_line - plot line to specified user co-ordinates

; in    R1,R2 = co-ordinates
;       R3 -> byte containing colour to be used
; out   R3 -> next colour byte to be used

render_line Entry

      [ TrueIcon2
        LDR     R0, [R3], #4            ; get the line colour to be used
        LDR     R0, [wsptr, R0]
        Push    "R2-R4"
        LDR     R3, ditheringflag       ; set foreground
        MOV     R4, #0                  ; overwrite colour
        SWI     XColourTrans_SetGCOL
        Pull    "R2-R4"
      |
        LDRB    R0,[R3],#1              ; get the line colour to be used
        BL      int_setcolour           ; convert from the Wimp colour to suitable for screen
      ]
        MOV     R0,#&25
        SWI     XOS_Plot                ; and then plot the relevant line section

        EXIT


;;-----------------------------------------------------------------------------
;; Define constants relating to the borders.
;;-----------------------------------------------------------------------------

  [ TrueIcon2

ct_in
ct_inshallow    DCD     :INDEX: truefacecolour, :INDEX: truefacecolour, :INDEX: trueoppcolour,  :INDEX: trueoppcolour
ct_out
ct_outshallow   DCD     :INDEX: trueoppcolour,  :INDEX: trueoppcolour,  :INDEX: truefacecolour, :INDEX: truefacecolour
ct_cream
ct_grey         DCD     :INDEX: truewellcolour, :INDEX: truewellcolour, :INDEX: truewellcolour, :INDEX: truewellcolour

  |

    [ NCErrorBox
ct_in           = sc_darkgrey,      sc_darkgrey,      sc_verydarkgrey,  sc_verydarkgrey
ct_out          = sc_verydarkgrey,  sc_verydarkgrey,  sc_darkgrey,      sc_darkgrey
    |
ct_in           = sc_white,         sc_white,         sc_middarkgrey,   sc_middarkgrey
ct_out          = sc_middarkgrey,   sc_middarkgrey,   sc_white,         sc_white
    ]
ct_inshallow    = sc_white,         sc_white,         sc_lightgrey,     sc_lightgrey
ct_outshallow   = sc_lightgrey,     sc_lightgrey,     sc_white,         sc_white
ct_cream        = sc_cream,         sc_cream,         sc_cream,         sc_cream
ct_grey         = sc_verylightgrey, sc_verylightgrey, sc_verylightgrey, sc_verylightgrey

                ALIGN
  ]

;;-----------------------------------------------------------------------------
;; Handle replaceable window gadgets, this is simply a set of sprites which
;; can be used to replace all the window bits and bobs within the system.
;;
;; Tools are allowed to give two states; normal + pressed, though for some the
;; pressed state is omitted (eg. the scroll bar wells).
;;
;; All gadgets must be defined with the same palette and same mode, mixing is not
;; allowed.  Sprites are allowed to have mode suffix to allow different
;; EX EY factors to be supported.
;;
;; Tools sprite designers can optionally provide a set of precalculated translation
;; tables to map the toolsprites onto the standard 16 Wimp colours. Each table is
;; containerised as a sprite, but really it's just a translation table in disguise.
;;-----------------------------------------------------------------------------

tablebasename
        DCB     "table_1?", 0           ; Like background tiles, table_<wimpcolour>
        ALIGN

;;-----------------------------------------------------------------------------
;; Define the list of sprites and its workspace for the caching block.
;;
;; The table describes the sprite name and which information is important, such
;; as its width + depth.
;;
;;-----------------------------------------------------------------------------

spritetable

        ^ 0
        AddIcon back,,"bicon", back_width, title_height
        AddIcon close,,"cicon", close_width, title_height
        AddIcon toggle,,"ticon", vscroll_width, title_height
        AddIcon toggle1,,"ticon1", vscroll_width, title_height
        AddIcon size,,"sicon", vscroll_width, hscroll_height
      [ IconiseButton
        AddIcon iconise,,"iicon", iconise_width, title_height
      ]

        AddIcon up,,"uicon", vscroll_width, up_height
        AddIcon down,,"dicon", vscroll_width, down_height
        AddIcon right,,"ricon", right_width, hscroll_height
        AddIcon left,,"licon", left_width, hscroll_height

        AddIcon tbarlcap,,,title_left,title_height
        AddIcon tbarmidt,,,title_sectionwidth,title_topheight
        AddIcon tbarmidb,,,title_sectionwidth,title_bottomheight
        AddIcon tbarrcap,,,title_right,title_height

        AddIcon vwelltcap,no,,vscroll_width,vscroll_top
        AddIcon vwellt,no,,vscroll_width,vscroll_topfill

        AddIcon vbart,,,vscroll_width,vscroll_blobtop
        AddIcon vbarmid,,,vscroll_width,vscroll_blobfill
        AddIcon vbarb,,,vscroll_width,vscroll_blobbottom

        AddIcon vwellb,no,,vscroll_width,vscroll_bottomfill
        AddIcon vwellbcap,no,,vscroll_width,vscroll_bottom

        AddIcon hwelllcap,no,,hscroll_left,hscroll_height
        AddIcon hwelll,no,,hscroll_leftfill,hscroll_height

        AddIcon hbarl,,,hscroll_blobleft,hscroll_height
        AddIcon hbarmid,,,hscroll_blob,hscroll_height
        AddIcon hbarr,,,hscroll_blobright,hscroll_height

        AddIcon hwellr,no,,hscroll_rightfill,hscroll_height
        AddIcon hwellrcap,no,,hscroll_right,hscroll_height

      [ hvblip
        AddIcon hblip,,,hscroll_blipwidth,hscroll_height
        AddIcon vblip,,,vscroll_width,vscroll_blipheight
      ]

; this must always be the *LAST* sprite in the list!

        AddIcon blank,no,"blicon",vscroll_width,hscroll_height

        ALIGN

toolcachesize   * :INDEX: @


;;-----------------------------------------------------------------------------
;; Attempt to build a list of the active icons within the system, this is used
;; for scanning through and replacing the various gadgets.  We attempt to
;; setup the caching list.
;;
;; NB: The tool sprites temporarily become part of the list of active
;;     sprites - avoid *IconSpriting any borders files.
;;
;; in   [tool_list] -> current tool list / =0 for none
;;      [tool_area] -> tool sprite area / =0 for none (don't build list)
;;      [dx/dy] => pixel sizes
;;      [xborder/yborder] = default border sizes to be used
;; out  [tool_list] -> new tool list
;;      [tool_plotparams] => suitable plotting parameters for sprites
;;      ... lots of others redefined to make plotting work
;;-----------------------------------------------------------------------------

maketoollist EntryS "R1-R11"

        Debug   tools,"Make tool list called =>",#tool_area,#tool_list,R14

        [ debugnk
        MOV R0,SP
        Debug   nk,"Make tool list called =>",#tool_area,#tool_list,R14,R0
        ]
;
        LDRB    R0,yborder
        LDRB    R1,xborder
        BL      default_params          ; default the parameters to border sizes

; if no list defined then drop back to a set of defaults for the current set
; of VDU style glyphs.


        LDR     R2,tool_area            ; still none?

        Debug   nk,"Tool area",R2

        TEQ     R2,#0
        BEQ     %FT45                   ; No then jump

      [ ToolTables

; look for any custom translation tables

        SUB     R13,R13,#12             ; space for "table_99"+0
        MOV     R4,#0                   ; bitmap of found wimp colours
        MOV     R5,#15                  ; wimp colour loop counter
        ADRL    R6,ttt_masterset
02
        ADR     R0,tablebasename
        MOV     R1,R13
        BL      copy0
        CMP     R5,#10                  ; numbery bit
        ADDCS   R0,R5,#'0' - 10
        STRCSB  R0,[R1,#-1]!
        ADDCC   R0,R5,#'0'
        STRCCB  R0,[R1,#-2]!
        MOV     R0,#0
        STRB    R0,[R1,#1]              ; terminate

        LDR     R0,=&100+SpriteReason_SelectSprite
        ADRL    R1,tool_areaCB
        MOV     R2,R13
        SWI     XOS_SpriteOp
        MOVVC   R0,#1                   ; hit
        ORRVC   R4,R4,R0,LSL R5
        LDRVC   R1,[R2,#spImage]
        ADDVC   R2,R2,R1
        MOVVS   R2,#0                   ; miss
        STR     R2,[R6,R5,LSL #2]       ; start of containerised 256x4 translation table

        SUBS    R5,R5,#1
        BPL     %BT02

; consider the results

        ADD     R13,R13,#12
        MOVS    R0,R4,LSL #16
        BEQ     %FT05                   ; we aint got naffin

        TST     R4,#1:SHL:2
        BLEQ    freetoolarea
        BEQ     %FT45                   ; need 'table_2' for tinting, can't use these tools
05
      ]
;..............................................................................
;
; attempt to work out the sizes of the various sprites and their modifications to
; the existing borders.

; work out which suffix to apply to sprite names

        MOV     R6,#1
        MOV     R10,#'0'

        MOV     R0,#-1
        MOV     R1,#VduExt_XEigFactor
        SWI     XOS_ReadModeVariable
        ADD     R5,R10,R6,LSL R2

        MOV     R1,#VduExt_YEigFactor
        SWI     XOS_ReadModeVariable
        ADD     R6,R10,R6,LSL R2

      [ :LNOT: Sprites11
        TEQ     R5,#'1'
        TEQNE   R6,#'1'
        MOVEQ   R5,#'2'
        MOVEQ   R6,#'2'                 ; '1y' or 'x1' -> '22'
      ]
        TEQ     R6,#'2'
        TEQNE   R6,#'4'
        TEQEQ   R5,#'2'
        BNE     %FT05                   ; if not '22' or '24' then no mono alternative suffix

        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable
        TEQ     R2,#0
        BNE     %FT05                   ; not mono
        TEQ     R6,#'4'
        MOVEQ   R5,#'0'
        MOVEQ   R6,#0                   ; '24' -> '0'
        MOVNE   R6,#'3'                 ; '22' -> '23'
05
        ORR     R10,R5,R6,LSL #8        ; combine to make a postfix
;
; now attempt to sort out the sprites to be used
;
        MOV     R0,#-1
        STRB    R0,addtoolstolist       ; flag as adding tools into the list
        BL      freelist
;
        MOV     R0,#area_Wimp
        STR     R0,thisCBptr            ; reference to the Wimps sprite block
;
        LDR     R2,tool_list
        LDR     R3,=toolcachesize       ; -> list / size
;
        TEQ     R2,#0                   ; has the list buffer been setup yet?
        BNE     %FT07
        ADRL    R14,tool_list_backup
        LDR     R2,[R14]                ; this is a constant size so try and reuse
        CMP     R2,#0
        STRNE   R2,tool_list

        Debug   nk,"Tool list Backup",R2

        BNE     %FT07

        MOV     R0,#ModHandReason_Claim
        BL      XROS_Module
        STRVC   R2,tool_list
        ADRVCL  R14,tool_list_backup
        STRVC   R2,[R14]

        EXITS   VS                      ; return if it fails to claim
;
07
        MOV     R0,#0
        MOV     R1,#0                   ; Set tool sizes to 0 == undefined
        STRB    R1,spritecachevalid
        BL      default_params

        ADD     R3,R3,R2                ; -> end of list
        ADRL    R8,spritetable          ; -> list of sprite names
        MOV     R9,R2                   ; -> list to fill in
10
        SUBS    R14,R3,R9
        BEQ     %FT40                   ; finished the list so tidy up and exit
;
        Debuga  tools,"Block pointer =",R9
        DebugS  tools,", name ",R8
;
        SUB     SP,SP,#16               ; allocate some space for the name
        MOV     R4,SP
;
        STR     R4,spritename           ; -> buffer to be used
        STR     R4,lengthflags
15
        LDRB    R14,[R8],#1
        TEQ     R14,#0
        STRNEB  R14,[R4],#1
        BNE     %BT15                   ; copy sprite name to a RAM buffer
;
        ADD     R8,R8,#3
        BIC     R8,R8,#3                ; align name pointer to word boundary
;
        STRB    R10,[R4]
        MOVS    R14,R10,LSR #8
        STRB    R14,[R4,#1]
        MOVNE   R14,#0
        STRNEB  R14,[R4,#2]             ; attach a suitable postfix

        ; this uses different approach to cut down on 'sprite not found'

        LDRB    R14,spritecachevalid
        TEQ     R14,#0
        BNE     %FT04
        BL      cachespriteaddress      ; try with postfix
        BVC     %FT07                   ; list exists and postfixed sprite found

        LDR     R14,list_at
        CMP     R14,R14,ASR #31
        BEQ     %FT03
        BL      cachetoolspriteaddress  ; list exists, try other or no postfixes
        B       %FT07

03      MOV     R14,#1
        STRB    R14,spritecachevalid    ; remember there's no list for next toolsprite
04      LDR     R14,thisCBptr
        Push    "R14"
        ADRL    R14,tool_areaCB
        STR     R14,thisCBptr
        BL      cachespriteaddress
        BLVS    cachetoolspriteaddress
        Pull    "R14"
        STR     R14,thisCBptr
07
        ADD     SP,SP,#16
        ADDVS   R8,R8,#4*2
        BVS     %FT30                   ; if not found then skip
;
        Debug   tools,"Found at",R2
;
        Push    "R2-R3"
;
        MOV     R0,#SpriteReason_ReadSpriteSize +&200
        LDR     R1,tool_area
        SWI     XOS_SpriteOp            ; assume it works as sprite already found
;
        SUBS    R3,R3,#1
        MOVMI   R3,#0
        SUBS    R4,R4,#1
        MOVMI   R4,#0                   ; always returns an extra pixel - unhelpful!
;
      [ TrueIcon3
        ; If these are the ROM toolsprites, assume all tools are unmasked
        LDR     R0,ROMstart
        LDR     R14,ROMend
        CMP     R1,R0
        CMPHS   R14,R1
        BHS     %FT66
      ]
;
        TEQ     R5,#1
        LDREQ   R5,[sp]
        ORREQ   R5,R5,#1
        STREQ   R5,[sp]                 ; store mask status
66
        MOV     R0,R6
        MOV     R1,#VduExt_XEigFactor
        SWI     XOS_ReadModeVariable
        MOVCC   R5,R3,LSL R2            ; get OS unit width
        MOVCC   R1,#VduExt_YEigFactor
        SWICC   XOS_ReadModeVariable
        MOVCC   R4,R4,LSL R2            ; get OS unit height
        MOVCS   R0,#0
        STRCS   R0,[SP]                 ; if mode invalid then sprite not found
        ADDCS   R8,R8,#4*2
        BCS     %FT20
;
        LDMIA   R8!,{R0,R1}             ; offsets to modifing the width / height suitably
        Debug   tools,"Offsets to modify (width,height) =>",R0,R1,R5,R4
;
        CMP     R0,#0
        LDRGT   R2,[wsptr,R0]           ; update the width if its bigger
        CMPGT   R5,R2
        STRGT   R5,[wsptr,R0]
;
        CMP     R1,#0
        LDRGT   R2,[wsptr,R1]           ; update the height if its bigger
        CMPGT   R4,R2
        STRGT   R4,[wsptr,R1]
20
        Pull    "R2-R3"
30      STR     R2,[R9],#4
        B       %BT10                   ; loop back until entire list as been scanned

; Set default sizes for undefined tools

40
      [ UTF8
        BL      read_current_alphabet
        BEQ     %FT88
      ]
        LDR     LR,back_width
        TEQ     LR,#0                   ; Back tool defined?
        ADREQL  R0,initvdustring2
        MOVEQ   R1,#endvdustring2-initvdustring2
        SWIEQ   XOS_WriteN              ; No then re-define glyphs
88
        LDRB    R1,yborder
        LDR     LR,title_height
        TEQ     LR,#0
        STREQ   R1,title_height
        LDR     LR,up_height
        TEQ     LR,#0
        STREQ   R1,up_height
        LDR     LR,down_height
        TEQ     LR,#0
        STREQ   R1,down_height
        LDR     LR,hscroll_height
        TEQ     LR,#0
        STREQ   R1,hscroll_height
;
        LDRB    R1,xborder
        LDR     LR,vscroll_width
        TEQ     LR,#0
        STREQ   R1,vscroll_width
        LDR     LR,back_width
        TEQ     LR,#0
        STREQ   R1,back_width
        LDR     LR,close_width
        TEQ     LR,#0
        STREQ   R1,close_width
      [ IconiseButton
        LDR     LR,iconise_width
        TEQ     LR,#0
        STREQ   R1,iconise_width
      ]
        LDR     LR,left_width
        TEQ     LR,#0
        STREQ   R1,left_width
        LDR     LR,right_width
        TEQ     LR,#0
        STREQ   R1,right_width

        MOV     R0,#0
        STRB    R0,addtoolstolist       ; remake list without tools present
        BL      freelist
;
; calculate a suitable pixel translation table for for the sprites,
; assume that R2 -> suitable sprite which describes the characteristics
; of all the other sprites being plotted.
;
        BIC     R2,R2,#1                ; strip our mask bit
        STR     R2,spritename
        MOV     R2,#0
        STR     R2,lengthflags          ; [spritename] is absolute
      [ TrueIcon3
        STRB    R2,tinted_tool          ; tinting off, incase the last window drawn was
                                        ; tinted before dropping to the CLI for *TOOLSPRITES
      ]
;
        BL      freetooltrans           ; release tool translation table
        BL      cachetoolspritedata     ; attempt to build a suitable pixtrans table
;
        BVC     %FT42
        ; a failure here usually means that we can't even allocate a pix table
        ; due to lack of memory. We have to free the lot!
        BL      freetoolarea
        EXITS
42
      [ Medusa
        MOV     R1, #8+32               ; Plot masked with wide tables by default
      |
        MOV     R1, #8                  ; Plot masked by default
      ]
      [ fastborders
        LDRB    R0,tsprite_needsfactors ; do we need to do translation
        TEQ     R0,#0
        LDREQ   R0,=&200+SpriteReason_PutSpriteUserCoords
        LDRNE   R0,=&200+SpriteReason_PutSpriteScaled
        ADRNEL  R2,tool_scalingblk
        LDRNE   R3,tpixtable_at
        MOVEQ   R3,#0
      |
        LDR     R0,=&200+SpriteReason_PutSpriteScaled
      [ TrueIcon3
        LDR     R14, tool_area
        LDR     R2, ROMstart
        LDR     R3, ROMend
        CMP     R14, R2
        CMPHS   R3, R14
      [ Medusa
        MOVHS   R1, #0+32               ; pretend ROM toolsprites are unmasked
      |
        MOVHS   R1, #0
      ]
      ]
        ADRL    R2,tool_scalingblk
        LDR     R3,tpixtable_at
      ]
;
        ASSERT  tool_maskop = tool_plotop+4
        ASSERT  tool_scaling = tool_maskop+4
        ASSERT  tool_transtable = tool_scaling+4
        ASSERT  ?tool_scalingblk = 4*4
;
        ADRL    R14,tool_plotparams
        STMIA   R14,{R0-R3}             ; setup a parameter block
;
      [ :LNOT: fastborders
        TEQ     R3,#0                   ; not needed with fastborders set
      ]
      [ ChildWindows
        ADR     R14,tsprite_factors
        LDMIA   R14,{R3,R4,R5,R6}
        ADRL    R14,tool_scalingblk
        STMIA   R14,{R3,R4,R5,R6}        ; take a copy of the scaling block (even if the tools don't always need it)
      |
      [ fastborders
        ADRNE   R14,tsprite_factors
        LDMNEIA R14,{R3,R4,R5,R6}
        STMNEIA R2,{R3,R4,R5,R6}        ; take a copy of the scaling block
      |
        ADR     R14,tsprite_factors
        LDMIA   R14,{R3,R4,R5,R6}
        STMIA   R2,{R3,R4,R5,R6}        ; take a copy of the scaling block
      ]
      ]

;
; calculate values + an OS unit for correct tessalation.
;
45      LDR     R0,title_height
        LDR     R1,dy
        ADD     R0,R0,R1
        STR     R0,title_height1        ; title_height1 = dy + title_height
;
        LDR     R0,hscroll_height
        ADD     R0,R0,R1
        STR     R0,hscroll_height1      ; hscroll_height1 = dx + hscroll_height
;
        LDR     R1,dx
        LDR     R0,vscroll_width
        ADD     R0,R0,R1
        STR     R0,vscroll_width1       ; vscroll_width1 = dx + vscroll_width
;
; now work out the information needed for the scroll bars.
;
        LDR     R0,left_width
        LDR     R1,xypixelsize
        ADD     R14,R0,R1,LSL #1
        STRB    R14,scroll_mxborder     ; gap at start of a horizontal scroll bar
;
        LDR     R0,up_height
        ADD     R14,R0,R1,LSL #1
        STRB    R14,scroll_myborder     ; gap at start of vertical scroll bar
;
        MOV     R14,R1,LSL #1
        STRB    R14,scroll_endmargin    ; border at end of scroll bars
;
 [ True
;        ADD     R14,R1,R1,LSL #4
        ADD     R14,R1,#32              ; 32 os units for scrollbar
 |
        ADD     R14,R1,R1,LSL #1
 ]
        STRB    R14,scroll_minlength    ; when min length gets imposed
;
        LDRB    R1,scroll_endmargin
        ADD     R14,R14,R1,LSL #1
        STRB    R14,scroll_minxbar
        STRB    R14,scroll_minybar      ; min length of scroll bars
;
        MOV     R14,#8                  ; this one is constant = defines distance of non-changing borders
        STRB    R14,scroll_sidemargin
;
        EXITS
        LTORG

;..............................................................................
; cachetoolspriteaddress
;
; [spritename], [thisCBptr], [lengthflags] as for cachespriteaddress
; in:  R4 -> resolution suffix                                               
;      R10 = first suffix tried (and failed)
; out: R2 -> sprite

cachetoolspriteaddress
        Push    "R14"
        MOV     R14,#&FF
        AND     R5,R14,R10
        AND     R6,R14,R10,LSR #8
        SUBS    R5,R5,#'0'
        SUB     R6,R6,#'0'
        MOVEQ   R5,#2
        MOVEQ   R6,#8                   ; pretend '0' was '28' so we try '24' next
        TEQ     R6,#3
        MOVEQ   R6,#4                   ; pretend '23' was '24' so we try '22' next

05      CMP     R5,R6
        MOVLO   R5,R5,LSL#1
        MOVHI   R6,R6,LSL#1
        BNE     %FT06                   ; after rectangular pixels, try next squarer version

        TEQ     R5,#1
        MOVEQ   R5,#2
        MOVEQ   R6,#2                   ; after '11', try '22'
        MOVNE   R5,#-'0'                ; after any other square pixels, try without suffix

06      ADD     R14,R5,#'0'
        STRB    R14,[R4]
        ADD     R14,R6,#'0'
        STRB    R14,[R4,#1]
        BL      cachespriteaddress
        Pull    "PC", VC                ; success
        TEQ     R5,#0
        BPL     %BT05                   ; try next suffix
        Pull    "PC"                    ; total failure, exit with V set

;..............................................................................

; defaultparams - modify the default parameters ready for further calculations

; in    R0 = vertical size to be stored
;       R1 = horizontal size to be stored
; out   -

default_params
        STR     R0,title_height         ; height based parameters
        STR     R0,up_height
        STR     R0,down_height
        STR     R0,hscroll_height
;
        STR     R1,vscroll_width        ; width based paramaters
        STR     R1,back_width
        STR     R1,close_width
      [ IconiseButton
        STR     R1,iconise_width
      ]
        STR     R1,left_width
        STR     R1,right_width
;
        MOV     R0,#0
        STR     R0,title_sectionwidth   ; reset constants for the title bar
        STR     R0,title_left
        STR     R0,title_right
        STR     R0,title_topheight
        STR     R0,title_bottomheight
;
        STR     R0,vscroll_top          ; and vscroll
        STR     R0,vscroll_topfill
        STR     R0,vscroll_blobtop
        STR     R0,vscroll_blobfill
        STR     R0,vscroll_blobbottom
        STR     R0,vscroll_bottomfill
        STR     R0,vscroll_bottom
;
        STR     R0,hscroll_left         ; finally the hscroll
        STR     R0,hscroll_leftfill
        STR     R0,hscroll_blobleft
        STR     R0,hscroll_blob
        STR     R0,hscroll_blobright
        STR     R0,hscroll_rightfill
        STR     R0,hscroll_right
;
      [ hvblip
        STR     R0,hscroll_blipwidth
        STR     R0,vscroll_blipheight
      ]

        MOV     PC,LR

  [ ToolTables
;;-----------------------------------------------------------------------------
;; make an active set of translation tables from the master set for this mode
;;
;; in    [ttt_masterset] have master tables, at least 'table_2' must exist
;; out   [ttt_activeset] updated
;;       V set R0 -> error, else corrupt
;;------------------------------------------------------------------------------

mastertoactive ROUT
        Push    "R1-R8,LR"
        ADRL    R6,ttt_masterset
        MOV     R1,#0
        MOV     R0,#15
05
        LDR     R14,[R6,R0,LSL #2]
        TEQ     R14,#0
        ADDNE   R1,R1,#1
        SUBS    R0,R0,#1
        BPL     %BT05

        LDR     R5,log2bpp              ; bpp 0,1,2,3,4,5
        CMP     R5,#4
        MOVCC   R7,#256*1
        MOVEQ   R7,#256*2
        MOVHI   R7,#256*4               ; => bytes per table entry
        MUL     R3,R1,R7                ; => bytes for all the tables present

        LDRHI   R14,modeflags
        ASSERT  ModeFlag_DataFormatSub_RGB > 8
        ANDHI   R14,R14,#ModeFlag_DataFormatSub_RGB
        ORRHI   R5,R14,R5               ; force table creation for RGB (but not BGR) 32bpp
        
        LDR     R2,ttt_activeset_at
        TEQ     R2,#0
        BEQ     %FT15                   ; none claimed yet

        CMP     R5,#5
        LDRNE   R14,ttt_activeset_size
        MOVEQ   R14,#0                  ; 32bpp BGR, no copies needed, force a free
        CMP     R14,R3
        BCS     %FT20                   ; big enough
10
        MOV     R14,#0
        STR     R14,ttt_activeset_at
        MOV     R0,#ModHandReason_Free
        BL      XROS_Module             ; too small, free old one
15
        CMP     R5,#5
        BEQ     %FT20                   ; 32bpp BGR, no copies needed, skip the claim
        MOV     R0,#ModHandReason_Claim
        STR     R3,ttt_activeset_size
        BL      XROS_Module
        Pull    "R1-R8,PC",VS
        STR     R2,ttt_activeset_at
20
        ADRL    R4,ttt_activeset
        MOV     R3,#15                  ; for each master table present, generate user table
25
        ; R1=colour number to convert (0-255)
        ; R2->base of storage for active set tables
        ; R3=wimp colour (0-15)
        ; R4->table of active set pointers
        ; R5=log2bpp
        ; R6->table of master pointers
        ; R7=size of 1 active set table in bytes
        ; R8->base of master table for this wimp colour
        LDR     R8,[R6,R3,LSL #2]
        CMP     R8,#0                   ; master table absent?
        CMPNE   R5,#5                   ; or 32bpp BGR mode?
        STREQ   R8,[R4,R3,LSL #2]
        BEQ     %FT35

        MOV     R1, #255
30
        LDR     R0,[R8,R1,LSL #2]
        MOV     R0,R0,ROR #24           ; xBGR->BGRx
        SWI     XColourTrans_ReturnColourNumber
        CMP     R5,#4                   ; 32bpp is 4B/entry, 16bpp is 2B/entry, others are 1
        STRCCB  R0,[R2,R1]
        ADDEQ   R14,R2,R1,LSL #1
        STREQB  R0,[R14,#0]
        MOVEQ   R0,R0,LSR #8
        STREQB  R0,[R14,#1]
        STRHI   R0,[R2,R1,LSL #2]
        SUBS    R1,R1,#1
        BPL     %BT30

        STR     R2,[R4,R3,LSL #2]       ; point at the table just made
        ADD     R2,R2,R7                ; move storage along
35
        SUBS    R3,R3,#1                ; next wimp colour
        BPL     %BT25

        CLRV
        Pull    "R1-R8,PC"

;;-----------------------------------------------------------------------------
;; colour match the tool to a standard colour
;;
;; in    R1 = &BBGGRR00 true colour (or 4 bit wimp colour when not TrueIcon3)
;; out   R7 -> translation table to use
;;------------------------------------------------------------------------------

colourmatchtool
        Push    "R2-R3,LR"
        ADRL    R3,ttt_activeset
        LDR     R7,[R3,#ttt_table2]     ; Presence of 'table_2' implies custom translations
        TEQ     R7,#0
        LDREQ   R7,tool_transtable      ; Use generic translation table
        Pull    "R2-R3,PC",EQ

        STR     R1,ttt_lastlookup       ; remember last request incase ColourTrans invalidates everything
    [ TrueIcon3
        BL      getpalpointer           ; R14 -> active 16 entry palette
        MOV     R2,#15
10
        LDR     R7,[R14,R2,LSL #2]
        TEQ     R1,R7
        BNE     %FT15
        LDR     R7,[R3,R2,LSL #2]
        TEQ     R7,#0
        Pull    "R2-R3,PC",NE           ; Is a standard colour & have a custom translation
15
        SUBS    R2,R2,#1
        BPL     %BT10

        LDRB    R2,tinted_tool          ; Non standard, or no table, maybe tint it?
        TEQ     R2,#0
        LDREQ   R7,[R3,#ttt_table2]     ; Not a tinting candidate, use 'table_2'
        Pull    "R2-R3,PC",EQ

        Push    "R0-R1"                 ; Make a temporary tinting table

      [ Medusa
        LDR     R1,log2bpp              ; bpp 0,1,2,3,4,5
        CMP     R1,#4
        MOVCC   R1,#256*1
        MOVEQ   R1,#256*2
        MOVHI   R1,#256*4               ; => bytes per table entry
      |
        MOV     R1,#256
      ]
        LDR     R2,tpixtable_at
        LDR     R3,tpixtable_size
        TEQ     R2,#0
        BEQ     %FT20
        CMP     R3,R1                   ; Is what's there already big enough?
        BCS     %FT25
        MOV     R0,#0
        STR     R0,tpixtable_at
        MOV     R0,#ModHandReason_Free
        BL      XROS_Module
20
        MOV     R3,R1
        MOV     R0,#ModHandReason_Claim
        BL      XROS_Module
        MOVVS   R7,#0                   ; Out of memory, and no tpixtable! Use nothing
        Pull    "R0-R3,PC",VS
25
        STR     R2,tpixtable_at
        STR     R2,tool_transtable
        STR     R3,tpixtable_size

        ADRL    R3,ttt_masterset
        LDR     R7,[R3,#ttt_table2]     ; Use master 'table_2' as basis

        MOV     R1,#255
        LDR     R3,log2bpp
        ; R1=colour number to convert (0-255)
        ; R2->base of tinted translation table
        ; R3=log2bpp
        ; R7->base of master table 2
30
        LDR     R0,[R7,R1,LSL #2]       ; solid (0) -> transparent (255)
        MOV     R0,R0,ROR #24           ; &AABBGGRR -> &BBGGRRAA
        BL      bgr0_to_y
        ORR     R0,R0,R0,LSL #8         ; &0000YYYY
        ORR     R0,R0,R0,LSL #16        ; &YYYYYYYY
        BL      tintfunc
        SWI     XColourTrans_ReturnColourNumber
      [ Medusa
        CMP     R3,#4                   ; 32bpp is 4B/entry, 16bpp is 2B/entry, others are 1
        STRCCB  R0,[R2,R1]
        ADDEQ   R14,R2,R1,LSL #1
        STREQB  R0,[R14,#0]
        MOVEQ   R0,R0,LSR #8
        STREQB  R0,[R14,#1]
        STRHI   R0,[R2,R1,LSL #2]
      |
        STRB    R0,[R2,R1]              ; No wide translation tables
      ]
        SUBS    R1,R1,#1
        BPL     %BT30

        MOV     R7,R2                   ; Use table just made
        Pull    "R0-R3,PC"
    |
        LDR     R7,[R3,R1,LSL #2]       ; Direct lookup wimp colour
        TEQ     R7,#0
        LDREQ   R7,[R3,#ttt_table2]     ; No specific table, use 'table_2'
        Pull    "R2-R3,PC"
    ]
  ]

;;-----------------------------------------------------------------------------
;; free the tool sprites list (if defined)
;;
;; in    [tool_list] -> list / =0 for undefined
;; out   [tool_list] = 0
;;------------------------------------------------------------------------------

freetoollist ROUT
        Push    "R0,R2,LR"

        [ false
; don't free the area as its size is constant, just mark as invalid.
        MOV     R0,#ModHandReason_Free
        LDR     R2,tool_list            ; -> tool list
        TEQ     R2,#0
        BLNE   XROS_Module              ; release it (ignorning errors)
        ]
;
        MOV     R2,#0
        STR     R2,tool_list            ; free the tool list
        CLRV
        Pull    "R0,R2,PC"


;;-----------------------------------------------------------------------------
;; Free the translation table associated with the tool plotting routines.
;;
;; in   [tpixtable_at] -> table / =0 for none
;; out  [tpixtable_at] = 0 (block released)
;;-----------------------------------------------------------------------------

freetooltrans ROUT

        MOV     R1,R14
;
        LDR     R2,tpixtable_at
        CMP     R2,#0                   ; has a table been defined yet?
        MOVNE   R0,#ModHandReason_Free
        BLNE   XROS_Module              ; if so then release - ignore errors
;
        MOV     R0,#0
        STR     R0,tpixtable_at
        STR     R0,tool_transtable
      [ ToolTables
        LDR     R2,ttt_activeset_at
        STR     R0,ttt_activeset_at
        CMP     R2,#0                   ; have translation tables been supplied in the tool sprites?
        MOVNE   R0,#ModHandReason_Free
        BLNE   XROS_Module
      ]
;
        CLRV
        MOV     PC,R1


;;-----------------------------------------------------------------------------
;; Set tools area, and do accompanying service call
;;
;; in   R1 = value to set tool_area to
;;-----------------------------------------------------------------------------

settoolarea Entry "R1-R2"
        STR     R1,tool_area
        MOV     R2,R1                   ; R2 -> new tool area
        LDR     R1,=Service_WimpToolSpritesChanged
        SWI     XOS_ServiceCall
        EXIT
        LTORG


;;-----------------------------------------------------------------------------
;; Free tools area, this attempts to free the tools area owned, even if none
;; is owned the areaCB is reset back to the default 16 byte block.
;;
;; in   [tool_area] -> tool area / =0 undefined
;;      [tool_list] -> tool list / =0 undefined
;; out  R0 corrupt!
;;      [tool_list] = 0
;;      [tool_area] = 0
;;      [tool_areaCB] = default for no sprite pool
;;-----------------------------------------------------------------------------

freetoolarea EntryS "R1-R4"

        Debug   tools,"Free tool areas =",#tool_list,#tool_area
;
        MOV     R0,#ModHandReason_Free
;
        LDR     R2,tool_area
        CMP     R2,#0                   ; is there a tools area already?
        BEQ     %FT01

        LDR     R14,ROMstart            ; it may have started life in ROM
        LDR     R4,ROMend
        CMP     R2,R14
        CMPHS   R4,R2

        BLLO    XROS_Module             ; attempt to free the buffer (ignore errors)
;
01      MOV     R1,#0
        BL      settoolarea             ; flag as being released
;
        BL      freetoollist            ; release the tool list (used for finding the sprites)
        BL      freetooltrans           ; release translation tables
;
        ADRL    R0,romsprites
        LDMIA   R0,{R1,R2,R3,R4}
        ADRL    R0,tool_areaCB
        STMIA   R0,{R1,R2,R3,R4}        ; setup default block header
;
        EXITS


;;-----------------------------------------------------------------------------
;; *ToolSprites [<fsp>]
;;
;; Attempt to load a new set of borders for the windows, this routine
;; attempt to locate the sprite file.  If its in ResourceFS then we bind directly
;; to it.
;;-----------------------------------------------------------------------------

ToolSprites_Code Entry "R0"

        LDR     wsptr,[R12]
;
        CMP     R1,#0                   ; any parameters specified, if not then back to old glyphs
        MOVEQ   R0,#0
        BL      int_toolsprites         ; otherwise load a different set of the doofers
        BLVC    maketoollist            ; setup the tool list
;
        STRVS   R0,[SP]
        EXIT

;..............................................................................

; load the specified sprite file as a set of window borders.

; in    R0 -> filename to be opened / =0 for default
; out   sprites loaded / link setup

int_toolsprites Entry "R1-R6"

        MOVS    R1,R0                   ; if null then use default tools
        ADREQ   R1,default_tools
;
        DebugS  tools,"ToolSprites =",R1
;
        MOV     R0,#OSFind_ReadFile
        SWI     XOS_Find                ; open the file
        EXIT    VS
;
        MOV     R5,R0                   ; R5 = handle
;
        MOV     R0,#OSArgs_ReadEXT
        MOV     R1,R5
        SWI     XOS_Args                ; get the size of the file
        MOVVC   R6,R2                   ; keep the size somewhere safe
;
        MOVVC   R0,#FSControl_ReadFSHandle
        MOVVC   R1,R5
        SWIVC   XOS_FSControl           ; get the FS handle (ie. its address)
        BVS     %FT90                   ; close the file - reporting the error
;
        Debug   tools,"Handle, Size, FSHandle, FSInfo =",R5,R6,R1,R2
;
        AND     R2,R2,#&FF              ; extract the filing system handle
        TEQ     R2,#fsnumber_resourcefs
        BNE     %FT10                   ; not a ResourceFS so read into memory
;
; R1 -> files memory address (must be accessable)
; R5 = file handle
; R6 = size of the file
;
        Debug   tools,"Binding to ResourceFS block"
05
        BL      freetoolarea            ; release the existing area
        BL      settoolarea             ; -> tools in ResourcesFS
;
        ADD     R6,R6,#4
        LDMIA   R1!,{R7-R9}             ; get the next set of bytes
;
        ADD     R6,R6,#4
        ADRL    R0,tool_areaCB
        SUB     R8,R1,R0                ; offset to first sprite (CB +8)
        SUB     R14,R6,#16
        ADD     R9,R8,R14               ; offset to free area (CB +12)
;
        Debug   tools,"Area size, Count, First, Last, Real =",R6,R7,R8,R9,R1
        Debug   tools,"tool_areaCB =>",R0
;
        ASSERT  SpriteAreaCBsize = 4*4
        STMIA   R0,{R6-R9}              ; store control block
        B       %FT90                   ; and then close up shop

; handle loading the tools from RMA, this involves claiming a suitable
; block and then loading into it.

10      MOV     R0,#ModHandReason_Claim
        MOV     R3,R6
        BL     XROS_Module
        BVS     %FT90                   ; if the claim failed then return
;
        Debug   tools,"RMA buffer at =",R2
;
        Push    "R2"
        MOV     R0,#OSGBPB_ReadFromGiven
        MOV     R1,R5
        MOV     R4,#0
        SWI     XOS_GBPB                ; read from the given block into memory
        Pull    "R2"
;
        MOVVC   R1,R2
        BVC     %BT05                   ; attempt to allocate the area if it worked
;
        DebugE  tools,"Cannot load into the RMA"
;
        SavePSR R14
        Push    "R0,R14"
        MOV     R0,#ModHandReason_Free
        BL     XROS_Module              ; free up the temporary block
        Pull    "R0,R14"
        RestPSR R14,,f                  ; restore flags
90
        SavePSR R14
        Push    "R0,R14"
        MOV     R0,#0
        MOV     R1,R5
        SWI     XOS_Find                ; attempt to close the file
        Pull    "R0,R14"
        RestPSR R14,,f                  ; restoring the flags word
;
        EXIT

default_tools
        = "WindowManager:Tools",0
        ALIGN


;;-----------------------------------------------------------------------------
;; Handle the modification of a tool icon, this includes clicks and releases.
;;
;; If select/adjust have been released then attempt to de-select the tool
;; icon - if defined, otherwise attempt to highlight it.
;;
;; in   R0,R1 = mouse co-ordinates
;;      R2 = button state
;;      R4 = icon handle
;;      R6 = button attributes
;;      R7 = mouse flag
;;      R8 = old button state
;;      handle = window handle
;;      [border_iconselected] = tool handle (if applicable)
;;      [border_windowselected] = window handle of tool window
;; out  [border_iconselected] / [border_windowselected] can be modified
;;-----------------------------------------------------------------------------

modifytool

        TST     R2,#button_left+button_right
        BEQ     modifytool_release      ; if either of the buttons released then tidy

        ; flow down into handling clicked on icons

;..............................................................................

; handle the selection of a tool, first check to see if there is a suitable
; sprite for highlighting the icon, otherwise ignore it.

modifytool_clicked

        Entry   "R0,R1,x0-y1,cx0-cy1"

        LDR     R14,border_iconselected
        TEQ     R14,R4
        LDREQ   R14,border_windowselected
        TEQEQ   R14,handle              ; check for auto-repeat gadgets (avoids flicker!)
        EXIT    EQ

; Release any pressed gadget in case ptr moves off of it

        LDR     R14, border_iconselected
        CMP     R14, #nullptr           ; Anything pressed?
        BLNE    modifytool_release      ; Yes then release the gadget

        CMP     R4 ,#windowicon_back    ; Window border gadget selected?
        EXIT    GT                      ; No then ignore it

; Only press gadgets on select/adjust leading edge

        EOR     R14, R8, R2             ; find changed buttons
        AND     R14, R14, R2            ; find pressed buttons
        TST     R14,#button_left+button_right
        EXIT    EQ                      ; if not start of press then ignore

      [ PushBothBars
        Push    "R14"
      ]
; Unslab any slabbed-in action button
        Push    "R0-R2,handle"
        LDR     handle, border_windowselected
        CMP     handle, #nullptr
        BEQ     %FT01
        LDR     R0, border_iconselected
        CMP     R0, #nullptr
        BLE     %FT01
        MOV     R1, #0
        MOV     R2, #is_inverted
        BL      int_set_icon_state
        MOV     R0, #nullptr
        STR     R0, border_windowselected
        STR     R0, border_iconselected
01
        Pull    "R0-R2,handle"

        ADRL    R2,glyphs_selected
        LDRB    R2,[R2,R4]
        TEQ     R2,#0                   ; is it possible for this glyph to have an alternate state?
      [ PushBothBars
        ADDEQ   sp, sp, #4*1
      ]
        EXIT    EQ                      ; nope, so return
        LDR     R3,tool_list
        TEQ     R3,#0                   ; is there a glyph list?
        BNE     %FT05
        Push    "R2"                    ; R2 corrupted :-(
        BL      restore_tool_list       ; if not, try to get one again
        Pull    "R2"
        LDR     R3,tool_list
        TEQ     R3,#0
05      LDRNE   R3,[R3,R2]
        TEQNE   R3,#0                   ; does the glyph have a second state cached?
      [ PushBothBars
        ADDEQ   sp, sp, #4*1
      ]
        EXIT    EQ                      ; return 'cos not allowed to toggle the state
;
; scroll bars are a special case - so handle seperately
;
      [ PushBothBars
        Pull    "R14"                   ; check to see if an adjust click on a scrollbar
        AND     R14, R14, #button_right
        CMP     R4, #windowicon_verticalbar
        CMPNE   R4, #windowicon_horizbar
        TEQEQ   R14, #button_right
        LDREQ   R14, [handle, #w_flags] ; but only for windows with two scrollbars!
        MVNEQ   R14, R14
        TSTEQ   R14, #wf_icon5 :OR: wf_icon7
      ]
        Debug   tools2,"Tool selected, handle =",R4,handle
;
      [ PushBothBars
        BEQ     modify_bothscroll
      ]
        CMP     R4,#windowicon_verticalbar
        BEQ     modify_vscroll
        CMP     R4,#windowicon_horizbar
        BEQ     modify_hscroll
10
        STR     R4,border_iconselected  ; flag as this icon / window selected
        STR     handle,border_windowselected
        BL      invalidate_glyph        ; ensure it gets redrawn
;
        EXIT

;..............................................................................

; cope with checking thepointer position in relation to the blob area on
; a scroll bar.

      [ PushBothBars
modify_bothscroll
        CMP     R4, #windowicon_horizbar
        BEQ     %FT01

        BL      getvscrollcoords
        Debug   tools2,"v scroll? x,y, x0,cy0,x1,cy1 =>",R0,R1,x0,cy0,x1,cy1
;
        CMP     R0,x1                   ; is it within the scroll blob?
        CMPLT   R1,cy1
        CMPLT   x0,R0
        CMPLT   cy0,R1
        EXIT    GE                      ; if not then return now
;
        Debug   tools2,"hit v scroll!"
        B       %FT02
01
        BL      gethscrollcoords
        Debug   tools2,"h scroll? x,y, x0,cy0,x1,cy1 =>",R0,R1,x0,cy0,x1,cy1
;
        CMP     R0,cx1                  ; is it within the scroll blob?
        CMPLT   R1,y1
        CMPLT   cx0,R0
        CMPLT   y0,R1
        EXIT    GE                      ; no so give up on this object
;
        Debug   tools2,"hit h scroll!"
02
        MOV     R4, #windowicon_bothbars
        STR     R4, border_iconselected
        STR     handle, border_windowselected
        MOV     R4, #windowicon_verticalbar
        BL      invalidate_glyph
        MOV     R4, #windowicon_horizbar
        BL      invalidate_glyph
        EXIT
      ]

modify_vscroll

        BL      getvscrollcoords
        Debug   tools2,"v scroll? x,y, x0,cy0,x1,cy1 =>",R0,R1,x0,cy0,x1,cy1
;
        CMP     R0,x1                   ; is it within the scroll blob?
        CMPLT   R1,cy1
        CMPLT   x0,R0
        CMPLT   cy0,R1
        EXIT    GE                      ; if not then return now
;
        Debug   tools2,"hit v scroll!"

        MOV     R4,#windowicon_verticalbar
        B       %BT10


modify_hscroll

        BL      gethscrollcoords
        Debug   tools2,"h scroll? x,y, x0,cy0,x1,cy1 =>",R0,R1,x0,cy0,x1,cy1
;
        CMP     R0,cx1                  ; is it within the scroll blob?
        CMPLT   R1,y1
        CMPLT   cx0,R0
        CMPLT   y0,R1
        EXIT    GE                      ; no so give up on this object
;
        Debug   tools2,"hit h scroll!"

        MOV     R4,#windowicon_horizbar
        B       %BT10

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; the buttons have been released so check to see if we need to redraw any of
; the window tools, ie. was the previously selected tool one of ours.

modifytool_release Entry "R4,handle"

        LDR     handle,border_windowselected
        CMP     handle,#nullptr
        EXIT    EQ
;
        LDR     R4,border_iconselected
        CMP     R4,#windowicon_back
        EXIT    GT                      ; exit if not the correct sort of icon
;
        MOV     R0,#nullptr             ; flag as no icon currently selected
        STR     R0,border_iconselected
        STR     R0,border_windowselected
;
      [ PushBothBars
        CMP     R4, #windowicon_bothbars
        MOVEQ   R4, #windowicon_verticalbar
        BLEQ    invalidate_glyph        ; preserves flags
        MOVEQ   R4, #windowicon_horizbar
      ]
        BL      invalidate_glyph        ; ensure returned back to its original state

        MOV     R4, #0
        STRB    R4, autorepeating       ; BJGA bugfix - deactivate autorepeat redraw optimisation
;
        EXIT


;;-----------------------------------------------------------------------------
;; Mark a window gadget invalid - redrawn at next opertunity.
;;
;; in   R4 = glyph handle
;;      handle = window handle
;; out  -
;;-----------------------------------------------------------------------------

invalidate_glyph EntryS "R0-R9"

        Debug   tools2,"invalidate glyph called =",R4,handle
;
        ADR     R0,iconposn_table
        LDRB    R0,[R0,R4]              ; get the value for icon posn
        BL      calc_w_iconposn         ; mark bounding box for icon invalid
        BL      checkredrawhandle
        BL      visibleportion_x0y0x1y1
      [ false
        BL      markinvalidrects
        BL      losewindowrects
      |
        ; Actually, lets do this immediately
        BL      int_redraw_window
invglp  EXIT    VS
        TEQ     R0,#0
        EXITS   EQ
        BL      int_get_rectangle
        B       invglp
      ]
;
        EXITS

; table to convert -ve icon handle to posn values

        [ IconiseButton
        = iconposn_iconise
        ]
        = 0
        = iconposn_hscroll
        = iconposn_hscroll
        = iconposn_hscroll
        = iconposn_resize
        = iconposn_vscroll
        = iconposn_vscroll
        = iconposn_vscroll
        = iconposn_toggle
        = iconposn_title
        = iconposn_close
        = iconposn_back
        = 0
iconposn_table

        ALIGN


;;------------------------------------------------------------------------------
;; Glyph tables, used for highlighting icons - deciding if highlightable.
;;------------------------------------------------------------------------------

        [ IconiseButton
        = tool_iconise
        ]
        = 0                             ; outer frame!
        = tool_right
        = 0                             ; horizontal scroll bar
        = tool_left
        = tool_size
        = tool_down
        = 0                             ; vertical scroll bar
        = tool_up
        = 0                             ; toggle is a special case
        = 0                             ; title bar
        = tool_close
        = tool_back
        = 0                             ; work area
glyphs_normal

        [ IconiseButton
        = tool_piconise
        ]
        = 0                             ; outer frame - special case
        = tool_pright
        = tool_phbarl
        = tool_pleft
        = tool_psize
        = tool_pdown
        = tool_pvbart
        = tool_pup
        = tool_ptoggle                  ; value not used, but non-0 to indicate highlightable
        = tool_ptbarlcap
        = tool_pclose
        = tool_pback
        = 0                             ; work area
glyphs_selected

        ALIGN


;;-----------------------------------------------------------------------------
;; Handle plotting a window gadget - given its icon handle plot it, if the
;; gadget is highlighted then the glyph is plotted differently, it assumes
;; there is an alternate state otherwise the flags would not indicate
;; the new bits.
;;
;; in   R2 = icon handle
;;      handle = window handle
;;      x0-y0 => region to plot the glyph into
;; out  EQ/NE if not plotted / plotted
;;-----------------------------------------------------------------------------

plot_windowglyph Entry "R0-R9"

        Debug   tools2,"plot_windowglyph: type, x0,y0,x1,y1 =>",R2,x0,y0,x1,y1
;
        Debug   tools2,"Clip =",#clipx0,#clipy0,#clipx1,#clipy1
;
        ADR     R14,clipx0
        LDMIA   R14,{R0,R1,R3,r4}
        CMP     x0,R3
        CMPLT   y0,R4
        CMPLT   R0,x1
        CMPLT   R1,y1
        BGE     plot_plotted            ; if outside the region then return
;
        LDR     R14,border_iconselected
        TEQ     R14,R2
        LDREQ   R14,border_windowselected
        TEQEQ   R14,handle              ; is it me or somebody else?
        ADREQL  R14,glyphs_selected
        ADRNEL  R14,glyphs_normal       ; -> selection table for the glyph
        LDRB    R14,[R14,R2]            ; = offset into tool list block

        LDR     R2,tool_list
        TEQ     R2,#0                   ; Tool list present?
        LDRNE   R2,[R2,R14]             ; = address of sprite to be plotted
        TEQNE   R2,#0
      [ debugtools
        BNE     %FT00
        Debug   tools2,"No toolsprite type", R2
00
      ]
        EXIT    EQ                      ; if not defined then return - do via VDU 5
;
; Allow toolsprites to be transparent (to show the colour through, if required)
;
        TST     R2,#1
        BLNE    solidrectangle          ; corrupts flags :-(
        TST     R2,#1
        BLNE    hollowrectangle        ; suitable rectangles
;
        MOV     R3,x0
        MOV     R4,y0                   ; x,y co-ordinates to plot at
;
        ADRL    R0,tool_plotparams
        LDMIA   R0,{R0,R5,R6,R7}        ; parameters to plot using
    [ ToolTables
      [ TrueIcon3
        LDR     R1,truetitlecolour
      |
        LDRB    R1,titlecolour
      ]
        BL      colourmatchtool
    ]
        Debug   tools2,"SpriteOp =",R0,R1,R2,R3,R4,R5
        BL      Tool_SpriteOp

plot_plotted
        CMP     PC,#0                   ; ensure returns NE!
        EXIT                            ; return indicating it was plotted


;;-----------------------------------------------------------------------------
;; Plot a scaled window gadget - for up and down arrows when scrollbar gets small
;; This routine frigs the tool_plotparams, and then restores them
;; in   R2 = icon handle
;;      R0 = height of original object
;;      handle = window handle
;;      x0,y0,x1,y1 => region to plot the glyph into
;; out  EQ/NE if not plotted / plotted
;;-----------------------------------------------------------------------------

      [ ChildWindows

plot_windowglyph_vscaled  Entry "R0,R1,cx0,cy0,cx1,cy1,y0,y1"

        ADD     R0,R0,#2                        ; urg - stored heights are all 1 pixel too small (assume toolsprite at 2x2 os/pix)

        ; frig scale factors so we can plot the thing scaled

        ADRL    R1,tool_scalingblk
        LDMIA   R1,{cx0,cy0,cx1,cy1}

        SUB     R14,y1,y0
        MUL     cy0,R14,cy0
        MUL     cy1,R0,cy1

        Push    "cx0,cy0,cx1,cy1"
        MOV     R1,SP                           ; R1 -> new scaling block (on stack)

        LDR     R2,tool_plotparams + 0          ; sprite reason code
        LDR     R3,tool_plotparams + 8          ; pointer to factors
        Push    "R2,R3"

        BIC     R2,R2,#&FF
        ORR     R2,R2,#SpriteReason_PutSpriteScaled
        STR     R2,tool_plotparams + 0
        STR     R1,tool_plotparams + 8          ; must have to scale it for this call

        ASSERT  R2 = cx0
        LDR     R2,[SP,#8*4]                    ; restore R2 from stacked cx0 on entry
        MOV     R1,R2                           ; for plot_windowglyph_clipped (later)
        BL      plot_windowglyph

        Pull    "R2,R3"
        STR     R2,tool_plotparams + 0          ; sprite reason code
        STR     R3,tool_plotparams + 8          ; pointer to factors

        ADD     SP,SP,#4*4                      ; correct stack

        ; now we must explicitly plot the top and bottom row, to avoid dropouts
        ; this involves messing with the clipping region (urg)

        Push    "x0,y0,x1,y1"
        Pull    "cx0,cy0,cx1,cy1"               ; copy x0,y0,x1,y1 to cx0,cy0,cx1,cy1 (for clip window)

        LDR     R14,dy
        Push    "y1,R14"

        ADD     cy1,cy0,R14
        ADD     y1,y0,R0
        BL      plot_windowglyph_clipped        ; plot bottom pixel row

        Pull    "y1,R14"

        MOV     cy1,y1
        SUB     cy0,cy1,R14
        SUB     y0,y1,R0
        BL      plot_windowglyph_clipped        ; plot top pixel row

        EXIT                                    ; flags on exit are as from plot_windowglyph
      ]


;;-----------------------------------------------------------------------------
;; Plot a scaled window gadget - for up and down arrows when scrollbar gets small
;; This routine frigs the tool_plotparams, and then restores them
;; in   R2 = icon handle
;;      R0 = height of original object
;;      handle = window handle
;;      x0,y0,x1,y1 => region to plot the glyph into
;; out  EQ/NE if not plotted / plotted
;;-----------------------------------------------------------------------------

      [ ChildWindows

plot_windowglyph_hscaled  Entry "R0,R1,cx0,cy0,cx1,cy1,x0,x1"

        ADD     R0,R0,#2                        ; urg - stored widths are all 1 pixel too small (assume toolsprite at 2x2 os/pix)

        ADRL    R1,tool_scalingblk
        LDMIA   R1,{cx0,cy0,cx1,cy1}

        SUB     R14,x1,x0
        MUL     cx0,R14,cx0
        MUL     cx1,R0,cx1

        Push    "cx0,cy0,cx1,cy1"
        MOV     R1,SP                           ; R1 -> new factors on stack

        LDR     R2,tool_plotparams + 0          ; sprite reason code
        LDR     R3,tool_plotparams + 8          ; pointer to factors
        Push    "R2,R3"

        BIC     R2,R2,#&FF
        ORR     R2,R2,#SpriteReason_PutSpriteScaled
        STR     R2,tool_plotparams + 0
        STR     R1,tool_plotparams + 8          ; must have to scale it for this call

        ASSERT  R2 = cx0
        LDR     R2,[SP,#8*4]                    ; restore R2 from stacked cx0 on entry
        MOV     R1,R2                           ; for plot_windowglyph_clipped (later)
        BL      plot_windowglyph

        Pull    "R2,R3"
        STR     R2,tool_plotparams + 0          ; sprite reason code
        STR     R3,tool_plotparams + 8          ; pointer to factors

        ADD     SP,SP,#4*4                      ; correct stack

        ; now we must explicitly plot the top and bottom row, to avoid dropouts
        ; this involves messing with the clipping region (urg)

        Push    "x0,y0,x1,y1"
        Pull    "cx0,cy0,cx1,cy1"               ; copy x0,y0,x1,y1 to cx0,cy0,cx1,cy1 (for clip window)

        LDR     R14,dx
        Push    "x1,R14"

        ADD     cx1,cx0,R14
        ADD     x1,x0,R0
        BL      plot_windowglyph_clipped        ; plot left-hand pixel row

        Pull    "x1,R14"

        MOV     cx1,x1
        SUB     cx0,cx1,R14
        SUB     x0,x1,R0
        BL      plot_windowglyph_clipped        ; plot right-hand pixel row

        EXIT                                    ; flags on exit are as from plot_windowglyph
      ]


;;-----------------------------------------------------------------------------
;; Plot a clipped window gadget - for getting the end pixels correct
;; in   R1 = icon handle
;;      x0,y0 = coordinate to plot at (bottom-left)
;;      cx0,cy0,cx1,cy1 = desired clip rectangle (will be further clipped)
;;      handle = window handle
;; out  flags preserved
;;-----------------------------------------------------------------------------

      [ ChildWindows

plot_windowglyph_clipped  EntryS "R0,R1,cx0,cy0,cx1,cy1,x0,y0,x1,y1"

        ADR     R14,clipx0
        LDMIA   R14,{x0,y0,x1,y1}

        Push    "x0,y0,x1,y1"

        max     x0,cx0
        max     y0,cy0
        min     x1,cx1
        min     y1,cy1

        CMP     x0,x1
        CMPLT   y0,y1
        ADDGE   SP,SP,#4*4
        EXITS   GE                              ; forget it if this is a null clip window

        BL      graphicswindow                  ; set to x0,y0,x1,y1

        ADD     R14,SP,#Proc_RegOffset+10*4
        LDMIA   R14,{x0,y0,x1,y1}               ; recover original x0,y0,x1,y1

        MOVVC   R2,R1
        BLVC    plot_windowglyph

        Pull    "x0,y0,x1,y1"
        BL      graphicswindow                  ; restore graphics window

        EXITS
      ]


;;-----------------------------------------------------------------------------
;; Plot a gadget using the tools cached pixtrans information.
;;
;; in   R2 -> sprite to be plotted (assumed to be valid)
;;      x0-y1 contain the bounding box for the icon
;; out  all preserved - including PSR
;;-----------------------------------------------------------------------------

draw_spriteglyph EntryS "R0-R7"

        ADR     R0,clipx0
        LDMIA   R0,{R0,R1,R3,r4}
        CMP     x0,R3
        CMPLT   y0,R4
        CMPLT   R0,x1
        CMPLT   R1,y1
        EXITS   GE                      ; ignore if not plottable
;
      [ TrueIcon3
        TST     R2, #1
        BLNE    solidrectangle          ; corrupts flags :-(
        TST     R2, #1
        BLNE    hollowrectangle         ; plot the borders of the gadget
      |
        BL      solidrectangle
        BL      hollowrectangle         ; plot the borders of the gadget
      ]
;
        MOV     R3,x0
        MOV     R4,y0                   ; x,y co-ordinates to plot at
;
        ADRL    R0,tool_plotparams
        LDMIA   R0,{R0,R5,R6,R7}        ; get the tool information
    [ ToolTables
      [ TrueIcon3
        LDR     R1,truetitlecolour
      |
        LDRB    R1,titlecolour
      ]
        BL      colourmatchtool
    ]
        BL      Tool_SpriteOp
;
        EXITS


;;-----------------------------------------------------------------------------
;; plot title bar - sprite, plot the title bar, using the sprites as required
;;
;; in   R3 = window flags
;;      R4 -> sprite pool information
;;      clipX0-Y1 = current clip region
;;      x0-y1 = bounding box of title bar
;;      handle -> window defn (must be valid!)
;; out  -
;;-----------------------------------------------------------------------------

dofunkytitlebar EntryS "R0-R11"

        Debug   tools2,"into 'dofunkytitlebar'",x0,y0,x1,y1
;
        ADR     cx0,clipx0
        LDMIA   cx0,{cx0,cy0,cx1,cy1}   ; get the clip region
        CMP     x0,cx1
        CMPLT   y0,cy1
        CMPLT   cx0,x1
        CMPLT   cy0,y1                  ; do we need to plot our bits?
        EXITS   GE
;
        ADR     R14,oldclipx0
        STMIA   R14,{cx0,cy0,cx1,cy1}   ; push old clip region away
;
        Push    "x0-y1"
        max     x0,cx0
        max     y0,cy0
        min     x1,cx1
        min     y1,cy1                  ; get the bounding box - clipped
        BL      graphicswindow          ; and then apply it
        Pull    "x0-y1"
;
        [       {FALSE} ;calculated by entry code now
        LDR     R1,[handle,#w_titleflags]
        ORR     R1,R1,#if_border:OR:if_filled
        LDREQB  R2,fontforeground
        ORREQ   R1,R1,R2,LSL #ib_fcol
        LDREQB  R2,fontbackground
        ORREQ   R1,R1,R2,LSL #ib_bcol
        ]
        ADD     R2,handle,#w_title
        Push    "R1"                    ; push the flags for use later on
;
      [ TrueIcon3
      [ true
        Push    "R0"
        LDR     R0, title_topheight
        LDR     R14, title_bottomheight
        ADD     R0, R0, R14
        ADD     R0, R0, #4              ; compensate for the fact that both topheight and bottomheight have been reduced by
                                        ; one sprite pixel (not even one screen pixel) - difficult to do properly at this stage
        LDR     R14, title_height
        CMP     R0, R14                 ; if there's a gap between tbatmidt and tbarmidb, we always need to fill in the background
        TEQGE   R0, R0                  ; if they overlapped, treat them as though they fitted perfectly, and check for mask
        Pull    "R0"
        LDREQ   R14, tool_list
        LDREQ   R14, [R14, #tool_tbarmidt]
        TSTEQ   R14, #1                 ; is title bar solid?
       |
        LDR     R14, tool_list
        LDR     R14, [R14, #tool_tbarmidt]
        TST     R14, #1                 ; is title bar solid?
      ]
        BICNE   R1,R1,#if_sprite:OR:if_text
        BLNE    drawicon_system         ; get the background / border plotted for the icon
      |
        BIC     R1,R1,#if_sprite:OR:if_text
        BL      drawicon_system         ; get the background / border plotted for the icon
      ]
;
        LDR     R2,dy
        SUB     y1,y1,R2
        LDR     R2,title_topheight
        SUB     y1,y1,R2                ; adjust to include the top height
;
        MOV     R3,x0
        MOV     R4,y0                   ; x,y co-ordinates to plot title sprites at
;
        ADRL    R0,tool_plotparams
        LDMIA   R0,{R0,R5,R6,R7}        ; R0,R5-R7 => sprite op information
    [ ToolTables
      [ TrueIcon3
        LDR     R1,truetitlecolour
      |
        LDRB    R1,titlecolour
      ]
        BL      colourmatchtool
    ]
        LDR     R1,tool_list            ; -> list of the glyphs
        Push    "R10,R11"               ; preserve these - they are important
;
; is it our window that is highlighted?
;
        LDR     R2,border_windowselected
        CMP     R2,handle
        LDREQ   R2,border_iconselected
        CMPEQ   R2,#windowicon_title    ; if its our window + the title bar then ... oh no!
        ASSERT  (tool_ptbarlcap-tool_tbarlcap) = (tool_ptbarmidb-tool_tbarmidb)
        ASSERT  (tool_ptbarlcap-tool_tbarlcap) = (tool_ptbarmidt-tool_tbarmidt)
        ASSERT  (tool_ptbarlcap-tool_tbarlcap) = (tool_ptbarrcap-tool_tbarrcap)
        ADDEQ   R1,R1,#tool_ptbarlcap-tool_tbarlcap
;
        LDR     R2, [R1,#tool_tbarlcap]
        LDR     R14,[R1,#tool_tbarrcap]
        ORRS    R2,R2,R14
        LDREQ   R14,[R1,#tool_tbarmidb]
        ORREQS  R2,R2,R14
        LDREQ   R14,[R1,#tool_tbarmidt]
        ORREQS  R2,R2,R14
        BEQ     %FT20                   ; none of the sprites exist, reduce flicker by not bothering

;
; prep the registers ready for advancing along the title bar - hut.. one.. two.. three.. four..
;
        LDR     R10,title_sectionwidth  ; width of the title bar sections
        LDR     R11,dx
        ADD     R10,R10,R11             ; including an extra pixel!
;
; title bar so attempt to plot the surround
;
        LDR     R2,[R1,#tool_tbarlcap]
        BL      Tool_SpriteOp
        LDR     R2,title_left           ; plot the left hand edge
        ADD     R3,R3,R2
        ADD     R3,R3,R11               ; and then advance ready for next section
10
        CMP     R3,x1                   ; have we finished yet?
        BGT     %FT15                   ; yes, so exit
;
        LDR     R2,[R1,#tool_tbarmidb]
        BL      Tool_SpriteOp            ; ... bottom
;
        Push    "R4"
        LDR     R2,[R1,#tool_tbarmidt]
        MOV     R4,y1
        BL      Tool_SpriteOp
        Pull    "R4"                    ; ... top
;
        ADD     R3,R3,R10
        B       %BT10
15
        LDR     R2,title_right
        SUB     R3,x1,R2
        SUB     R3,R3,R11               ; move back from right edge to plot right cap
        LDR     R2,[R1,#tool_tbarrcap]
        BL      Tool_SpriteOp
20
        Pull    "R10-R11"               ; all done so balance the stack
;
        ADR     x0,oldclipx0
        LDMIA   x0,{x0-y1}
        BL      graphicswindow          ; restore rectangle to original
;
        Pull    "R1"
;
        ADD     x0,sp,#Proc_RegOffset+sp_x0
        LDMIA   x0,{x0,y0,x1,y1}
;
      [ TrueIcon2 :LAND: :LNOT: TrueIcon3
        LDR     R2, [handle, #w_flags]
        TST     R2, #ws_hasfocus
        LDREQB  R2, [handle, #w_tbcol]
        LDRNEB  R2, [handle, #w_tbcol2]
        STRB    R2, work_back_colour    ; this is where mungetruecolours looks for font background if unfilled
      ]
        BIC     R1,R1,#if_border:OR:if_filled
        ADD     R2,handle,#w_title

; account for the caps at each end of title bar
        ADD     x0,x0,#4
        SUB     x1,x1,#4
        CMP     x0,x1
        MOVGT   x0,x1

        BL      drawicon_system         ; slap the text onto the title bar
;
        EXITS


;;-----------------------------------------------------------------------------
;; Plot funky scroll bars, these routines attempt to plot the current
;; scroll bars using sprites.  The sprites make up the entire scroll bar
;; with sections for the top bottom and middle blob.
;;
;; in   tools_at / R0 -> sprite list for gadgets (assume non-zero)
;;      x0-y1 => bounding box of outside scroll region
;;      cx0-cy1 => bounding box of inner scroll region (the blob)
;;      clipx0-clipy1 => defined clip region
;;      handle => window defn for the window being redrawn
;; out  -
;;-----------------------------------------------------------------------------


; frame description for finding scroll information from the stack

        ^ 4*2
sp_cx0  # 4                             ; stacked bounding box of total area
sp_cy0  # 4
sp_cx1  # 4
sp_cy1  # 4
sp_x0   # 4                             ; stacked bounding box of main area
sp_y0   # 4
sp_x1   # 4
sp_y1   # 4

sp_hand # 4                             ; = handle for window


;;-----------------------------------------------------------------------------
;; Plot the vertical scroll bar
;;-----------------------------------------------------------------------------

dofunkyvscroll EntryS "R0-R11"
;
        Debug   tools2,"into 'dofunkyvscroll'",x0,y0,x1,y1
        Debug   scroll,"dofunkyvscroll",x0,y0,x1,y1
;
        ADR     cx0,clipx0
        LDMIA   cx0,{cx0,cy0,cx1,cy1}   ; get the clip region
        CMP     x0,cx1
        CMPLT   y0,cy1
        CMPLT   cx0,x1
        CMPLT   cy0,y1                  ; do we need to plot our bits?
        EXITS   GE
;
        ADR     R14,oldclipx0
        STMIA   R14,{cx0,cy0,cx1,cy1}   ; push old clip region away
;
      [ :LNOT: TrueIcon3                ; don't think this is actually necessary
        BL      hollowrectangle         ; plot the border for the graphic
      ]
;
        max     x0,cx0
        max     y0,cy0
        min     x1,cx1
        min     y1,cy1                  ; clip the two together
        ADRL    R14,tool_scrollclip
        STMIA   R14,{x0,y0,x1,y1}       ; push clip region for scroll bar

        Debug   scroll,"tool_scrollclip",x0,y0,x1,y1
;
        ADRL    R0,tool_plotparams
        LDMIA   R0,{R0,R5,R6,R7}        ; get the plotting parameters
    [ ToolTables
      [ TrueIcon3
        LDR     R1,truescoutcolour
      |
        LDRB    R1,[handle,#w_scouter]
      ]
        BL      colourmatchtool
    ]
;
        LDR     R1,dy                   ; single pixel at screen resolution
        LDR     R3,[sp,#Proc_RegOffset+sp_x0]
        LDR     R10,tool_list           ; -> tool sprite list
;
; plot the bottom section of the scroll bar
;
        LDR     R4,[sp,#Proc_RegOffset+sp_y0]
        LDR     R11,[sp,#Proc_RegOffset+sp_cy0]
        BL      set_vclip               ; define the clip region for this section
        BLE     %FT20

        LDR     R2,[R10,#tool_vwellbcap]
        BL      Tool_SpriteOp            ; Plot if unclipped
        LDR     R14,vscroll_bottom
        ADD     R4,R4,R14
        ADD     R4,R4,R1                ; plot the end of the block
        LDR     R2,[R10,#tool_vwellb]
        BL      set_vclip
        BLE     %FT20
        BL      Tool_SpriteOpTiled
  [ CanTileManually
        ; Plot manually if OS_SpriteOp 65 failed
        BVC     %FT20
10
        CMP     R4,R11
        BLLE    Tool_SpriteOp
        LDRLE   R14,vscroll_bottomfill
        ADDLE   R4,R4,R14
        ADDLE   R4,R4,R1
        BLE     %BT10                   ; fill in the top section
  ]
;
; now plot the top section of the scroll bar
;
20      LDR     R4,[sp,#Proc_RegOffset+sp_cy1]
        LDR     R11,[sp,#Proc_RegOffset+sp_y1]
        BL      set_vclip               ; set the clipping region
        BLE     %FT20                   ; Jump if not visible
;
        LDR     R2,[R10,#tool_vwelltcap]
        LDR     R4,[sp,#Proc_RegOffset+sp_y1]
        LDR     R14,vscroll_top
        SUB     R4,R4,R14
        SUB     R4,R4,R1
        BL      Tool_SpriteOp            ; plot the top shell
;
        LDR     R2,[R10,#tool_vwellt]
        MOV     R11,R4
        LDR     R4,[sp,#Proc_RegOffset+sp_cy1]
        BL      set_vclip
        BLE     %FT20
        MOV     R4,R11
        BL      Tool_SpriteOpTiled
  [ CanTileManually
        ; Plot manually if OS_SpriteOp 65 failed
        BVC     %FT20
        LDR     R11,[sp,#Proc_RegOffset+sp_cy1]
10
        CMP     R4,R11
        LDRGE   R14,vscroll_topfill
        SUBGE   R4,R4,R14
        SUBGE   R4,R4,R1
        BLGE    Tool_SpriteOp            ; plot a section
        BGE     %BT10                   ; loop back until all plotted
  ]
;
; plot the scroll sausage
;
20      LDR     R4,[sp,#Proc_RegOffset+sp_cy0]         ; min
        LDR     R11,[sp,#Proc_RegOffset+sp_cy1]        ; max
        BL      set_vclip               ; define the clip region
        BLE     %FT40                   ; Jump if all fixed
;
; now decide which routine to call to plot the sausage bits
;
        LDR     R2,[sp,#Proc_RegOffset+sp_hand]
    [ ToolTables
        Push    "R1"
      [ TrueIcon3
        LDR     R1,truescincolour
      |
        LDRB    R1,[R2,#w_scinner]
      ]
        BL      colourmatchtool
        Pull    "R1"
    ]
      [ PushBothBars
        LDR     R14, border_iconselected
        CMP     R14, #windowicon_verticalbar
        CMPNE   R14, #windowicon_bothbars
        LDREQ   R14, border_windowselected
        TEQEQ   R14, R2                 ; is it our window thats selected?
      |
        LDR     R14,border_windowselected
        TEQ     R14,R2                  ; is it our window thats selected?
        LDREQ   R14,border_iconselected
        CMPEQ   R14,#windowicon_verticalbar
      ]
        ASSERT  (tool_pvbarb-tool_vbarb) = (tool_pvbarmid-tool_vbarmid)
        ASSERT  (tool_pvbarb-tool_vbarb) = (tool_pvbart-tool_vbart)
      [ hvblip
        ASSERT  (tool_pvbarb-tool_vbarb) = (tool_pvblip-tool_vblip)
      ]
        ADDEQ   R10,R10,#tool_pvbarb-tool_vbarb

; now plot the scroll sausage bit in the middle

20      LDR     R2,[R10,#tool_vbarb]
        BL      Tool_SpriteOp
        LDR     R14,vscroll_blobbottom
        ADD     R4,R4,R14
        ADD     R4,R4,R1                ; base of the area
;
        LDR     R2,[R10,#tool_vbarmid]
        BL      set_vclip
        BLE     %FT20
        BL      Tool_SpriteOpTiled
  [ CanTileManually
        ; Plot manually if OS_SpriteOp 65 failed
        BVC     %FT20
10
        CMP     R4,R11
        BLLE    Tool_SpriteOp
        LDRLE   R14,vscroll_blobfill
        ADDLE   R4,R4,R14
        ADDLE   R4,R4,R1
        BLE     %BT10                   ; loop back until blob section plotted
  ]
;
20      LDR     R4,[sp,#Proc_RegOffset+sp_cy0]
        LDR     R11,[sp,#Proc_RegOffset+sp_cy1]
        BL      set_vclip               ; restore clip region
        LDR     R14,vscroll_blobtop
        SUB     R4,R11,R14
        SUB     R4,R4,R1
        LDR     R2,[R10,#tool_vbart]
        BL      Tool_SpriteOp            ; and put the end cap on
;
      [ hvblip
;
        LDR     R10,[R10,#tool_vblip]
        TEQ     R10,#0                  ; is there a vertical blip on this scroll bar?
        BEQ     %FT40
;
        LDR     R4,[sp,#Proc_RegOffset+sp_cy0]
        LDR     R2,vscroll_blobbottom
        ADD     R2,R2,R1
        ADD     R4,R4,R2                ; Y0 of the scroll bar blob section
;
        LDR     R14,[sp,#Proc_RegOffset+sp_cy1]
        LDR     R2,vscroll_blobtop
        ADD     R2,R2,R1
        SUB     R14,R14,R2              ; Y1 of the scroll blob section
;
        LDR     R2,vscroll_blipheight
        SUB     R14,R14,R4
        SUB     R14,R14,R2              ; total length that we can play with - blip height
;
        ADD     R4,R4,R14,ASR #1        ; work out actual co-ordinate to plot blip at (assuming bottom left)
        LDR     R2,dy_1                 ; then align to sensible boundaries
        ADD     R4,R4,R2
        BIC     R4,R4,R2
;
        MOV     R2,R10
        BL      Tool_SpriteOp            ; plot the blip at the correct position
      ]
40
        ADR     x0,oldclipx0
        LDMIA   x0,{x0,y0,x1,y1}
        BL      graphicswindow          ; restore the clip rectangle
;
        EXITS


;..............................................................................

; set vertical clip points (and region).

; in    R4 = min
;       R11 = max
; out
;       LE = all rectangle clipped
;       GT = rectangle ok to draw

set_vclip Entry "R0,R4,x0-y1,R11"

        Debug   scroll,"set_vclip: min, max",R4,R11

        ADRL    R0,tool_scrollclip
        LDMIA   R0,{x0-y1}              ; get the current bars clipping region
;
        max     y0,R4
        min     y1,R11                  ; adjust by the new values

        Debug   scroll,"set window",x0,y0,x1,y1

        BL      graphicswindow          ; adjust the graphics window

        CMP     y1,y0
        EXIT


;;------------------------------------------------------------------------------
;; Plot the horizontal scroll bar
;;------------------------------------------------------------------------------

dofunkyhscroll EntryS "R0-R11"
;
        Debug   tools2,"into 'dofunkyhscroll'",x0,y0,x1,y1
        Debug   scroll,"dofunkyhscroll",x0,y0,x1,y1
;
        ADR     cx0,clipx0
        LDMIA   cx0,{cx0,cy0,cx1,cy1}   ; get the clip region
        CMP     x0,cx1
        CMPLT   y0,cy1
        CMPLT   cx0,x1
        CMPLT   cy0,y1                  ; do we need to plot our bits?
        EXITS   GE
;
        ADR     R14,oldclipx0
        STMIA   R14,{cx0,cy0,cx1,cy1}   ; push old clip region away
;
      [ :LNOT: TrueIcon3                ; don't think this is actually necessary
        BL      hollowrectangle         ; plot the border for the graphic
      ]
;
        max     x0,cx0
        max     y0,cy0
        min     x1,cx1
        min     y1,cy1                  ; clip the two together
        ADRL    R14,tool_scrollclip
        STMIA   R14,{x0,y0,x1,y1}       ; push clip region for scroll bar
;
        ADRL    R0,tool_plotparams
        LDMIA   R0,{R0,R5,R6,R7}        ; get the plotting parameters
    [ ToolTables
      [ TrueIcon3
        LDR     R1,truescoutcolour
      |
        LDRB    R1,[handle,#w_scouter]
      ]
        BL      colourmatchtool
    ]
;
        LDR     R1,dx                   ; single pixel at screen resolution
        LDR     R4,[sp,#Proc_RegOffset+sp_y0]
        LDR     R10,tool_list           ; -> tool sprite list
;
; plot the left hand side of the bar
;
        LDR     R3,[sp,#Proc_RegOffset+sp_x0]
        LDR     R11,[sp,#Proc_RegOffset+sp_cx0]
        BL      set_hclip               ; set the clip region for this section
        BLE     %FT15
;
        LDR     R2,[R10,#tool_hwelllcap]
        BL      Tool_SpriteOp
        LDR     R14,hscroll_left
        ADD     R3,R3,R14
        ADD     R3,R3,R1
;
        LDR     R2,[R10,#tool_hwelll]
        BL      set_hclip
        BLE     %FT15
        BL      Tool_SpriteOpTiled
  [ CanTileManually
        ; Plot manually if OS_SpriteOp 65 failed
        BVC     %FT15
10
        CMP     R3,R11                  ; have we finished plotting the blanking section
        BLLE    Tool_SpriteOp
        LDRLE   R14,hscroll_leftfill
        ADDLE   R3,R3,R14
        ADDLE   R3,R3,R1
        BLE     %BT10                   ; loop filling in the base area
  ]
;
; plot the right hand side of the bar
;
15      LDR     R3,[sp,#Proc_RegOffset+sp_cx1]
        LDR     R11,[sp,#Proc_RegOffset+sp_x1]
        BL      set_hclip               ; set the horizontal clip region
        BLE     %FT25
;
        LDR     R2,[R10,#tool_hwellrcap]
        LDR     R3,[sp,#Proc_RegOffset+sp_x1]
        LDR     R14,hscroll_right
        SUB     R3,R3,R14
        SUB     R3,R3,R1
        BL      Tool_SpriteOp            ; put the scroll blob
;
        LDR     R2,[R10,#tool_hwellr]
        MOV     R11,R3
        LDR     R3,[sp,#Proc_RegOffset+sp_cx1]
        BL      set_hclip
        BLE     %FT25
        MOV     R3,R11
        BL      Tool_SpriteOpTiled
  [ CanTileManually
        ; Plot manually if OS_SpriteOp 65 failed
        BVC     %FT25
        LDR     R11,[sp,#Proc_RegOffset+sp_cx1]
20      CMP     R3,R11
        LDRGE   R14,hscroll_rightfill
        SUBGE   R3,R3,R14
        SUBGE   R3,R3,R1
        BLGE    Tool_SpriteOp
        BGE     %BT20
  ]
;
; plot the scroll blob section
;
25      LDR     R3,[sp,#Proc_RegOffset+sp_cx0]         ; setup the region to plot the blob
        LDR     R11,[sp,#Proc_RegOffset+sp_cx1]
        BL      set_hclip
        BLE     %FT50
;
; first attempt to decide if the block is selected or not?
;
        LDR     R2,[sp,#Proc_RegOffset+sp_hand]
    [ ToolTables
        Push    "R1"
      [ TrueIcon3
        LDR     R1,truescincolour
      |
        LDRB    R1,[R2,#w_scinner]
      ]
        BL      colourmatchtool
        Pull    "R1"
    ]
      [ PushBothBars
        LDR     R14, border_iconselected
        CMP     R14, #windowicon_horizbar
        CMPNE   R14, #windowicon_bothbars
        LDREQ   R14, border_windowselected
        TEQEQ   R14, R2                 ; is it our window thats selected?
      |
        LDR     R14,border_windowselected
        CMP     R14,R2
        LDREQ   R14,border_iconselected
        CMPEQ   R14,#windowicon_horizbar
      ]
        ASSERT  (tool_phbarl-tool_hbarl) = (tool_phbarmid-tool_hbarmid)
        ASSERT  (tool_phbarl-tool_hbarl) = (tool_phbarr-tool_hbarr)
      [ hvblip
        ASSERT  (tool_phbarl-tool_hbarl) = (tool_phblip-tool_hblip)
      ]
        ADDEQ   R10,R10,#tool_phbarl-tool_hbarl

; handle plotting the horizontal scroll sausage

        LDR     R2,[R10,#tool_hbarl]

        Debug   scroll,"tool_phbarl",R2

        BL      Tool_SpriteOp
        LDR     R14,hscroll_blobleft
        ADD     R3,R3,R14
        ADD     R3,R3,R1
;
        LDR     R2,[R10,#tool_hbarmid]
        BL      set_hclip
        BLE     %FT40
        BL      Tool_SpriteOpTiled
  [ CanTileManually
        ; Plot manually if OS_SpriteOp 65 failed
        BVC     %FT40
38
        CMP     R3,R11
        BLLT    Tool_SpriteOp
        LDRLT   R14,hscroll_blob
        ADDLT   R3,R3,R14
        ADDLT   R3,R3,R1
        BLT     %BT38
  ]
;
40      LDR     R3,[sp,#Proc_RegOffset+sp_cx0]         ; setup the region to plot the blob
        LDR     R11,[sp,#Proc_RegOffset+sp_cx1]
        BL      set_hclip               ; restore clip region
        LDR     R2,[R10,#tool_hbarr]

        Debug   scroll,"tool_phbarr",R2

        LDR     R14,hscroll_blobright
        SUB     R3,R11,R14
        SUB     R3,R3,R1,LSR #1         ; Round
        BL      Tool_SpriteOp
;
      [ hvblip
;
        LDR     R10,[R10,#tool_hblip]
        TEQ     R10,#0                  ; is there a vertical blip on this scroll bar?
        BEQ     %FT50
;
        LDR     R3,[sp,#Proc_RegOffset+sp_cx0]
        LDR     R2,hscroll_blobleft
        SUB     R2,R2,R1
        ADD     R3,R3,R2                ; X0 of the scroll bar blob section
;
        LDR     R14,[sp,#Proc_RegOffset+sp_cx1]
        LDR     R2,hscroll_blobright
        SUB     R2,R2,R1
        SUB     R14,R14,R2              ; X1 of the scroll blob section
;
        LDR     R2,hscroll_blipwidth
        SUB     R14,R14,R3
        SUB     R14,R14,R2              ; total length that we can play with - blip width
;
        ADD     R3,R3,R14,ASR #1        ; work out actual co-ordinate to plot blip at (assuming bottom left)
        LDR     R2,dx_1                 ; then align to sensible boundaries
        SUB     R3,R3,R2
        BIC     R3,R3,R2
;
        MOV     R2,R10
        BL      Tool_SpriteOp            ; plot the blip at the correct position

      ]
50
        ADR     x0,oldclipx0
        LDMIA   x0,{x0,y0,x1,y1}
        BL      graphicswindow          ; restore the clip rectangle
;
        EXITS

;..............................................................................

; set the clip region between two horizontal points.

; in    R3 = start point
;       R11 = end point
; out
;       LE = all rectangle clipped
;       GT = rectangle ok to draw

set_hclip Entry "R0,R3,x0-y1,R11"

        ADRL    R0,tool_scrollclip
        LDMIA   R0,{x0-y1}              ; get the current bars clipping region
;
        max     x0,R3
        min     x1,R11                  ; adjust by the new values
        BL      graphicswindow          ; adjust the graphics window
;
        CMP     x1,x0
        EXIT


;;-----------------------------------------------------------------------------
;; Functions to handle the processing of fancy font text.  The new Window
;; Manager looks for the following system variables to describe which fonts
;; should be used:
;;
;;   Wimp$Font          = font name, including encoding, matrix
;;   Wimp$FontSize      = font size in (1/16)pt both horizontal and vertical
;;   Wimp$FontWidth     = font width, if required
;;
;; If we cannot find the font then we will attempt to revert back to VDU 5
;; handling, without reporting an error.
;;-----------------------------------------------------------------------------

      [ outlinefont

;;-----------------------------------------------------------------------------
;; Find the font and setup the font handle in our workspace.  If the font
;; size variable is not defined then default to a sensible size, if the font
;; name variable is not defined, or we fail to get the font from it then
;; leave the font handle as zero, but return no error!
;;-----------------------------------------------------------------------------

fname   =       "Wimp$Font", 0
fsize   =       "Wimp$FontSize", 0
fwidth  =       "Wimp$FontWidth", 0
        ALIGN

FindFont Entry  "R0-R10"
        TraceK  font, "FindFont"
        TraceNL font

        ;Attempt to lose the font is already claimed
        BL      LoseFont

        SUB     sp, sp, #44             ;44 = ALIGN (Font_NameLimit)

        MOV     R0,#ReadCMOS
        MOV     R1,#DesktopFeaturesCMOS
        SWI     XOS_Byte
        AND     R2,R2,#&1E
        MOV     R2,R2, LSR #1
        TEQ     R2,#1                   ; system font
        BNE     %FT50
        MOV     R0,#0
        STR     R0,systemfont
        SETV
        B       afterfindingfont

50      ;Allocate a buffer big enough for the font name and setup a pointer
        ;       to it
        MOV     R6, SP

        TEQ     R2,#0                   ; wimp$font
        BEQ     FindFont_get_font_size

        ; is the font the same as the last one we looked for ?
        ADRL    R14,fontnamebuffer
        LDRB    R8,[R14]
        TEQ     R8,R2
        ADDEQ   R6,R14,#1
        BEQ     fontinR6

        STRB    R2,[R14]

        SUB     R8,R2,#1                ; R8 is counter into rom fonts

        SUB     SP,SP,#256
        MOV     R2,SP                   ; buffer
        MOV     R5,#256

        MOV     R9,R6                   ; where to put it
        ADR     R1,starting_dir
        Push    "R6"
        MOV     R10,SP                  ; keep track of stack for fast rewind
        BL      recurse_down_fonts

; need R6->font name before finding the font

        Pull    "R6"

        ; copy font name into our buffer
        ADRL    R14,fontnamebuffer
        Push    R6
50
        LDRB    R7,[R6],#1
        STRB    R7,[R14,#1]!
        CMP     R7,#31
        BGE     %BT50
        Pull    R6

        ADD     SP,SP,#256              ; get rid of buffer

fontinR6
        MOV     R7,#192                 ; 12 point
        MOV     R8,#192
        B       FindFont_find_WIMP_font

recurse_down_fonts                      ; (R1=directory)

        Push    "R1,R4,lr"                 ; these are 'local'

        SUB     SP,SP,#256              ; make room for local string

        MOV     R4,#0
        MOV     R7,#-1
recurse_l1
        MOV     R0,#10
        MOV     R3,#1
        ADR     R6,int_metric
        SWI     XOS_GBPB
        TEQ     R4,R7
        TEQNE   R3,#1
        BNE     recurse_l1

        TEQ     R3,#1                   ; found ...Intmetric*, must be a font
        BNE     recurse_l1l2
        SUBS    R8,R8,#1
        BNE     recurse_l1l2

; copy font name to R9
        ADD     R0,R1,#18               ; jump resources:$.fonts.
copy_l1_loop
        LDRB    R14,[R0],#1
        STRB    R14,[R9],#1
        CMP     R14,#31
        BGT     copy_l1_loop
        SUB     SP,R10,#12
        Pull    "R1,R4,PC"
; now recurse down sub directories

recurse_l1l2
        MOV     R4,#0

recurse_l2
        MOV     R0,#12
        MOV     R3,#1
        ADR     R6,star_char
        SWI     XOS_GBPB
        TEQ     R3,#0
        BEQ     recurse_end
        LDR     R14,[R2,#20]
        TEQ     R14,#4096                       ; is it a directory?
        BNE     recurse_notadir
; need to copy new directory name onto stack
        MOV     R0,SP
        Push    "R1"
recurse_l2_loop
        LDRB    R14,[R1],#1
        CMP     R14,#31
        STRGTB  R14,[R0],#1                     ; must be GT as we're appending
        BGT     recurse_l2_loop
        MOV     R14,#"."
        STRB    R14,[R0],#1
        ADD     R1,R2,#24                       ; sub dir name
recurse_l3_loop
        LDRB    R14,[R1],#1
        STRB    R14,[R0],#1
        CMP     R14,#31
        BGT     recurse_l3_loop
        ADD     R1,SP,#4
        BL      recurse_down_fonts
        Pull    "R1"
recurse_notadir
        TEQ     R4,R7                          ; finished enumeration?
        BNE     recurse_l2
recurse_end
        ADD     SP,SP,#256
        Pull    "R1,R4,PC"


int_metric
        DCB     "IntMetric"
star_char
        DCB     "*",0,0
starting_dir
        DCB     "Resources:$.Fonts",0
        ALIGN


FindFont_get_font_size TraceL font
        ADRL    R0, fsize
        MOV     R1, R6
        MOV     R2, #4
        MOV     R3, #0
        MOV     R4, #VarType_Number
        SWI     XOS_ReadVarVal
        TEQ     R4, #VarType_String     ; convert from string if necessary
        BLEQ    string_to_number        ;
        TEQ     R4, #VarType_Number
        MOVNE   R7, #192        ;use 12pt if not a number
        BNE     FindFont_font_size_read
        MOVVS   R7, #192        ;use 12pt (no such variable)
        LDRVC   R7, [R1]        ;use variable if no error and a number
FindFont_font_size_read
        TraceK  font, "FindFont: font size*16/pt "
        TraceD  font, R7
        TraceNL font

FindFont_get_font_width TraceL font
        ADR     R0, fwidth
        MOV     R1, R6
        MOV     R2, #4
        MOV     R3, #0
        MOV     R4, #VarType_Number
        SWI     XOS_ReadVarVal
        TEQ     R4, #VarType_String     ; convert from string if necessary
        BLEQ    string_to_number        ;
        TEQ     R4, #VarType_Number
        MOVNE   R8, R7   ;use size if the variable isn't a number
        BNE     FindFont_font_width_read
        MOVVS   R8, R7   ;use size if error (no such variable)
        LDRVC   R8, [R1] ;use variable if no error and a number
FindFont_font_width_read
        TraceK  font, "FindFont: font width*16/pt "
        TraceD  font, R8
        TraceNL font

FindFont_get_font_name_on_stack TraceL font
        ADR     R0, fname
        MOV     R1, R6
        MOV     R2, #40
        MOV     R3, #0
        MOV     R4, #VarType_Expanded
        SWI     XOS_ReadVarVal
        BVS     afterfindingfont         ;return null font if variable not found/too long
        TEQ     R2, #0
        SETV    EQ
        BVS     afterfindingfont         ;return null font if we didn't get any characters
        MOV     R0, #:CHR: 0
        STRB    R0, [R1, R2]            ; terminate the string
        TraceK  font, "FindFont: font name '"
        TraceS  font, R6
        TraceK  font, "'"
        TraceNL font

FindFont_find_WIMP_font TraceL font
        MOV     R1, R6                  ; -> font name
        MOV     R2, R8
        MOV     R3, R7                  ; x/y point sizes
        MOV     R4, #0
        MOV     R5, #0                  ; x/y resolutions
        SWI     XFont_FindFont
afterfindingfont
        MOVVS   R0,#0
        MOVVS   R7,#192
        MOVVS   R8,#192                 ; still going to find symbol font- need size
        STR     R0, systemfont          ; storing the handle if it worked

; now cache the size of the font
        SWIVC   XFont_ReadInfo
        STRVC   R4,systemfonty1
        STRVC   R2,systemfonty0
        SUBVC   R1,R3,R1                ; width
        STRVC   R1,systemfontwidth
        CLRV

      [ UTF8
; now cache the defined symbol characters (speeds up pushfontstring)
        Push    "R11"
        MOV     R3, R0
        BL      measure_symbols
        STR     R11, systemfont_wimpsymbol_map
        Pull    "R11"
      ]

        BL     measure_ellipsis         ; and work out what it is in this alphabet

        [ true
; now resize iconbar icons
        MOV     R2,#1
        STRB    R2,iconbar_needs_rs
;        BL      resizeiconbaricons
        ]

;now tell everyone

        MOV     R2,R0
        MOV     R14,#ms_data+4
        STR     R14,[sp,#-(ms_data+4)]!
;
        MOV     R0,#User_Message        ; broadcasting a user message
        MOV     R1,sp
        STR     R2,[R1,#ms_data]        ; data = font handle
        MOV     R2,#0
        STR     R2,[R1,#ms_yourref]     ; no your ref
;
        LDR     R14,=Message_FontChanged
        STR     R14,[R1,#ms_action]
;
        BL      int_sendmessage_fromwimp
        ADD     sp,sp,#(ms_data+4)

FontMessageEnd

        TraceK  font, "FindFont: WIMP font handle "
        TraceX  font, R0
        TraceNL font

        ;Balance the stack before continuing
FindFont_WIMP_font_found
        ADD     sp, sp, #44

FindFont_find_symbol_font TraceL font
        ;Always find the symbol font: it's needed by "real" scalable icons.
        ADR     R1, wimpsymbol          ; -> font name
        MOV     R2, R8
        MOV     R3, R7                  ; x/y point sizes
        MOV     R4, #0
        MOV     R5, #0                  ; x/y resolutions
        SWI     XFont_FindFont
        STRVC   R0, symbolfont          ; storing the handle if it worked
        TraceK  font, "FindFont: symbol font handle "
        TraceX  font, R0
        TraceNL font

FindFontEnd

        CLRV
        EXIT

wimpsymbol = "WIMPSymbol", 0
        ALIGN

;;-----------------------------------------------------------------------------
;; string_to_number
;; Used only by font routines above to get dimensions from *Set variables
;; Entry: R1 pointer to string
;; Exit:  R1 points to number, R4 is VarType_Number
;; R0,R2 corrupted
;;-----------------------------------------------------------------------------

string_to_number
        Push    "LR"                    ;calling a SWI
        MOV     R0,#10
        MOV     R4,R1                   ;R1 corrupted by SWI
        SWI     XOS_ReadUnsigned
        MOV     R1,R4
        MOVVC   R4,#VarType_Number
        STRVC   R2,[R1]
        Pull    "PC"


;;-----------------------------------------------------------------------------
;; Lose fonts, only performed if non-zero.
;;-----------------------------------------------------------------------------

LoseFont EntryS "R0"
        TraceK  font, "LoseFont"
        TraceNL font

        ;Lose the WIMP font
        LDR     R0, systemfont
        TEQ     R0, #0                  ; is the system font defined
        BEQ     %FT05
        SWI     XFont_LoseFont          ; if it is then lose it
        MOV     R0, #0
        STR     R0, systemfont
05
        [       debug :LAND: debugfont
        BEQ     LoseFont_lost_WIMP_font
        ]
        TraceK  font, "LoseFont: lost WIMP font handle"
        TraceNL font
LoseFont_lost_WIMP_font

        ;Lose the symbol font
        LDR     R0, symbolfont
        TEQ     R0, #0                  ; is the symbol font defined
        BEQ     %FT10
        SWI     XFont_LoseFont          ; if it is then lose it
        MOV     R0, #0
        STR     R0, symbolfont
10
        [       debug :LAND: debugfont
        BEQ     LoseFont_lost_symbol_font
        ]
        TraceK  font, "LoseFont: lost symbol font handle"
        TraceNL font
LoseFont_lost_symbol_font

        EXITS


      ]

;;-----------------------------------------------------------------------------
;; Tool_SpriteOp
;; Perform an OS_SpriteOp on a tool from the tool_area
;; Entry: R0 reason code (b9 set)
;;        R2-R7 as required by the respective reason code
;; Exit:  R0,R1 preserved
;;        R2-R7 as returned by the respective reason code
;;-----------------------------------------------------------------------------

Tool_SpriteOp
        EntryS  "R0,R1"
        BL      Tool_SpriteOpCommon
        EXITS

Tool_SpriteOpTiled
        Entry   "R0,R1"
        LDR     R0,=SpriteReason_TileSpriteScaled+512 ; Regardless of op, make op tiled
        BL      Tool_SpriteOpCommon
        EXIT

Tool_SpriteOpCommon
        Push    "lr"
        LDRB    R1,tsprite_needsregen
        TEQ     R1,#0
        BEQ     %FT05
        Push    "R2"
        Debug tools,"Need regen",R7
        BL      restore_tool_list        ; ensure tool list valid, get 1st sprite entry
        BL      recache_tools_trans      ; make new tpixtable from 1st sprite entry
        Pull    "R2"
        LDR     R7,tool_transtable       ; reload new table
        Debug tools,"Regen     ",R7
        MOV     R1,#0
        STRB    R1,tsprite_needsregen
05
        LDR     R1,tool_area             ; R1 is quite often wrong!
        BIC     R2,R2,#1                 ; flag of masked
        SWI     XOS_SpriteOp
        Pull    "pc"

;;----------------------------------------------------------------------------
;; Mode-independent sprite code
;; Entry:  [spritename] --> sprite name
;;         [thisCBptr] --> sprite area
;;         [lengthflags] ==> is R2 a name ptr or a sprite ptr?
;; Exit:   R3,R4 = sprite size (pixels)
;;         mode data set up if different input mode from last time
;;----------------------------------------------------------------------------

cachetoolspritedata
        Entry   "R1-R2,R5-R7"

        MOV     R2,#1
        STRB    R2,selecttable_crit     ; entering critical period for pixtable

        LDR     R2,lengthflags
        CMP     R2,#0                   ; absolute pointer?
        LDR     R2,spritename
        BLNE    cachespriteaddress
        MOVVC   R0,#&200+SpriteReason_ReadSpriteSize
        SWIVC   XOS_SpriteOp            ; read information about the sprite
        BVS     %FT92
;
; R2 -> sprite in area
;
        LDR     R7,[R2,#spImage]
        LDR     R14,[R2,#spTrans]
        CMP     R7,R14                  ; min(image,trans)
        MOVHI   R7,R14

        LDR     R1,tpixtable_at
        CMP     R1,#0                   ; is a pixtable defined?
        BEQ     %FT10

      [ TrueIcon3
        LDRB    R14, tinted_tool
        TEQ     R14, #0                 ; if it's tinted, we must recalculate the table
        BNE     %FT10
      ]
      [ ToolTables
        ADRL    R14,ttt_masterset
        LDR     R14,[R14,#ttt_table2]   ; if it's a custom set, we must recalculate the table
        TEQ     R14,#0
        BNE     %FT10
      ]

        TEQ     R7,#spPalette           ; does it have a palette?
        LDREQ   R14,tsprite_lastmode
        TEQEQ   R6,R14                  ; no, so have we already cached this information?
        STREQ   R1,tool_transtable      ; repoint at the pixtable
        BEQ     %FT92

10      MOV     R0,R6                   ; R0 = mode of sprite

        TEQ     R7,#spPalette
        MOVNE   R6,#-1                  ; if it has a palette then corrupt last mode
      [ TrueIcon3
        LDRB    R14, tinted_tool
        TEQ     R14, #0                 ; if we're generating a tinted table, corrupt last mode too
        MOVNE   R6, #-1
      ]
        STR     R6,tsprite_lastmode

        Push    "R2,R3-R4"              ; R2 -> sprite, R3,R4 = height / width

        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable
        STRVC   R2,tsprite_log2bpp      ; get the depth of the sprite

        MOVVC   R1,#VduExt_XEigFactor
        SWIVC   XOS_ReadModeVariable
        STRVC   R2,tsprite_log2px       ; get the X scaling factor (pixels => OS units)

        MOVVC   R1,#VduExt_YEigFactor
        SWIVC   XOS_ReadModeVariable
        STRVC   R2,tsprite_log2py       ; get the Y scaling factor (pixels => OS units)

        MOVVC   R1,#VduExt_ModeFlags
        SWIVC   XOS_ReadModeVariable
        STRVC   R2,tsprite_modeflags    ; get the mode flags

        MOVVC   R1,#VduExt_NColour
        SWIVC   XOS_ReadModeVariable
        STRVC   R2,tsprite_ncolour      ; get the ncolour
      [ ToolTables
        BLVC    mastertoactive          ; remap any custom translation tables
      ]
        Pull    "R2,R3-R4",VS
        BVS     %FT92

        LDR     R6,log2bpp
        MOV     LR,#ModeFlag_DataFormat_Mask
        TEQ     R6,#3
        ORRNE   LR,LR,#ModeFlag_64k     ; try and avoid false positives on 64K flag caused by 8bpp full palette flag.
        LDRNE   R1,tsprite_ncolour
        LDRNE   R5,ncolour
        TEQNE   R1,R5                   ; ncolour differs? (only check if not 8bpp to try and avoid 63/255 false positives)
        LDREQ   R1,modeflags
        LDREQ   R2,tsprite_modeflags
        ANDEQ   R2,R2,LR
        ANDEQ   R1,R1,LR
        TEQEQ   R1,R2                   ; any colour space conversion or alpha blending needed?
        LDREQ   R1,tsprite_lastmode
        TSTEQ   R2,#ModeFlag_DataFormatSub_Alpha ; does it have an alpha channel?
        TSTEQ   R1,#&80000000           ; does it have an alpha mask?
        LDR     R1,tsprite_log2bpp
        TEQEQ   R1,R6                   ; bpp differs?
        LDR     R0,tsprite_log2px
        LDR     R5,log2px
        TEQEQ   R0,R5
        LDR     R1,tsprite_log2py
        LDR     R6,log2py
        TEQEQ   R1,R6                   ; any special scaling?
        MOVEQ   R14,#0
        MOVNE   R14,#-1
        STRB    R14,tsprite_needsfactors       ; may be modified later

        ADR     r2,tsprite_factors
        BL      rationalisefactors

        Pull    "R1"                    ; R1 -> sprite
        MOV     R2,#-1
        MOV     R3,#-1                  ; convert to the current mode
      [ Medusa
        MOV     R5,#(1:SHL:0) :OR: 1:SHL:1 :OR: 1:SHL:4 ; Use mode's palette if sprite has none, make wide table
      |
        MOV     R5,#(1:SHL:0)
      ]
;
; we must now attempt to cope with the dilemma of sorting out the correct
; mapping table for the sprite.
;
; in earlier versions of the Window Manager it made no attempt to cope
; with different depth sprites other than 1,2 or 4BPP so we will break
; new ground and go boldly where no larma has been parping before.
;
        LDR     R14,tsprite_log2bpp

        Debug   ic,"Sprite bpp, palette",R14,R7

        CMP     R14,#3                  ; is it 8,16 or 32BPP?
        CMPLT   R7,#(spPalette+4)       ; or does it have a palette?
        BLT     %FT02

        LDR     R0,baseofromsprites     ; might have 8+ bpp sprites in ROM now
        LDR     R4,[R0,#saEnd]
        ADD     R4,R0,R4                ; R4 -> end of ROM sprite area
        CMP     R1,R0
        CMPHS   R4,R1                   ; is sprite in ROM?
        LDRLO   R0,baseofsprites        ; no, use RAM sprite area      ; 320nk Medusa fix
        B       %FT10
;
; sprite is in a depth less than 8BPP so take the current palette and munge
; it based on the translation table defined in workspace
;

02
        LDR     R0,[R1,#spMode]         ; R0 = mode of sprite
        ADRL    R1,temppaltable         ; R1 -> temporary palette area
        Push    "R0-R3,R5"

        BL      getpalpointer           ; R14 -> palette to be used

        LDR     R4,tsprite_log2bpp
        CMP     R4,#1
        ADRLTL  R4,transtable1          ; R4 => translation 1BPP
        ADREQL  R4,transtable2          ;       translation 2BPP
        ADRGTL  R4,transtable4          ;       translation 4BPP
        MOV     R5,#15

05      LDRB    R3,[R4,R5]              ; get index into real palette
        LDR     R3,[R14,R3,LSL #2]
        BIC     R3,R3,#&000000FF        ; R3 = &BBGGRR00
        STR     R3,[R1,R5,LSL #2]
        SUBS    R5,R5,#1
        BPL     %BT05                   ; loop back copying the data

        Pull    "R0-R3,R5"
10
      [ ToolTables
        ADRL    R14,ttt_masterset
        LDR     R14,[R14,#ttt_table2]   ; are these sprites using custom translations?
        TEQ     R14,#0
        BEQ     %FT15

        LDR     R1,ttt_lastlookup
        BL      colourmatchtool         ; redo the last lookup
        MOV     R14,R7
        B       %FT45                   ; skip the generic table generation
15
      ]
        MOV     R4,#0                   ; R4 =0 read table size
      [ TrueIcon3
        SWI     XColourTrans_GenerateTable ; ensure wide table flag is obeyed
      |
        SWI     XColourTrans_SelectTable
      ]
        BVS     %FT90                   ; exit

        LDR     R14,tpixtable_at
        TEQ     R14,#0                  ; does the pixtable exist?
        LDRNE   R14,tpixtable_size
        CMP     R14,R4                  ; is it big enough?
        BHS     %FT20

        Push    "R0-R3"

        LDR     R2,tpixtable_at
        CMP     R2,#0                   ; is there a pixel table defined yet?
        MOVNE   R0,#ModHandReason_Free
        BLNE    XROS_Module              ; free it if there is - ignoring errors

        MOV     R2,#0
        STR     R2,tpixtable_size
        STR     R2,tpixtable_at         ; mark as the pix table has been released

        MOV     R0,#ModHandReason_Claim
        MOV     R3,R4
        BL      XROS_Module              ; attempt to claim a new buffer big enough
        STRVC   R2,tpixtable_at
        STRVC   R3,tpixtable_size       ; store pointer and define the size

        STRVS   R0,[SP]
        Pull    "R0-R3"
        BVS     %FT90                   ; return if it errors

20      MOV     R6,R4                   ; R6 = size of table generated (first time)
        LDR     R4,tpixtable_at

        Debug   ic,"Sprite src mode, src pptr, dest mode, dest pptr",R0,R1,R2,R3

      [ TrueIcon3
        Push    "R6,R7"
        LDRB    R6, tinted_tool
        ORR     R5, R5, R6
        MOV     R6, wsptr
        ADR     R7, tintfunc
        SWI     XColourTrans_GenerateTable
        Pull    "R6,R7"
      |
        SWI     XColourTrans_SelectTable
      ]
        BVS     %FT90                   ; return if not important

        CMP     R6,#256
        BHI     %FT40                   ; if its greater than 8bpp then we can ignore it (was GT)

35      SUBS    R6,R6,#1                ; decrease the index into the table
        BMI     %FT90                   ; return if end of the world reached

        LDRB    R14,[R4,R6]
        TEQ     R14,R6                  ; colour number = index? (1:1 mapped)
        BEQ     %BT35
40
        LDR     R14,tpixtable_at        ; use that now
45
        STR     R14,tool_transtable
        MOV     R14,#-1
        STRB    R14,tsprite_needsfactors; mark as needing translation
90
        Pull    "R3-R4"
92
        MOV     R14, #0
        STRB    R14, selecttable_crit   ; passed the critical moment for pixtable

        EXIT

    [ TrueIcon3
;------------------------------------------------------------------------------
; Routine called to process a palette entry to "tint" a tool sprite
; Maps greys on to title bar foreground-background scale
; White - rgb_lightgrey - Black   --->   White - [truetitlecolour] - [truetitlefg]
;
; In:   R0 = input palette entry
; Out:  R0 = modified palette entry
;       all other registers preserved
;------------------------------------------------------------------------------
tintfunc Entry "R1-R8"

        MOV     R8, #&FF
        MOV     R3, R0, LSR #24         ; blue component
        AND     R2, R8, R0, LSR #16     ; green component
        AND     R1, R8, R0, LSR #8      ; red component

        TEQ     R1, R2
        TEQEQ   R2, R3
        EXIT    NE                      ; leave colours alone

        LDR     R4, truetitlecolour
        AND     R2, R8, R4, LSR #8      ; title background red component
        AND     R3, R8, R4, LSR #16     ; title background green component
        MOV     R4, R4, LSR #24         ; title background blue component

        CMP     R1, #&BB
        BLT     %FT02

        ; bright shades: blend to white
        SUB     R1, R8, R1              ; distance of source from white

        SUB     R2, R8, R2              ; R2 = distance from white
        MUL     R0, R1, R2              ; scale up by new size
        DivRem  R2, R0, #&44, R14,norem ; scale down by old size
        SUB     R2, R8, R2              ; make relative to white again

        SUB     R3, R8, R3
        MUL     R0, R1, R3
        DivRem  R3, R0, #&44, R14, norem
        SUB     R3, R8, R3

        SUB     R4, R8, R4
        MUL     R0, R1, R4
        DivRem  R4, R0, #&44, R14, norem
        SUB     R4, R8, R4

        B       %FT01

02      ; dark shades: blend between foreground and background
        LDR     R7, truetitlefg
        AND     R5, R8, R7, LSR #8      ; title foreground red component
        AND     R6, R8, R7, LSR #16     ; title foreground green component
        MOV     R7, R7, LSR #24         ; title foreground blue component

        RSB     R1, R1, #&BB            ; distance of source from Wimp grey 2

        SUBS    R5, R2, R5              ; R5 = total distance between bg and fg
        BEQ     %FT10                   ; just in case fg=bg (!)
        RSBLT   R5, R5, #0              ; R5 = |R5|
        SavePSR R8                      ; remember flags for later
        MUL     R0, R1, R5              ; scale up by new size
        DivRem  R5, R0, #&BB, R14,norem ; scale down by old size
        RestPSR R8,,f                   ; restore flags
        ADDLT   R2, R2, R5              ; make relative to new background
        SUBGT   R2, R2, R5              ;   (accounting for the sign of R2-R5 above)
10
        SUBS    R6, R3, R6
        BEQ     %FT10
        RSBLT   R6, R6, #0
        SavePSR R8
        MUL     R0, R1, R6
        DivRem  R6, R0, #&BB, R14, norem
        RestPSR R8,,f
        ADDLT   R3, R3, R6
        SUBGT   R3, R3, R6
10
        SUBS    R7, R4, R7
        BEQ     %FT10
        RSBLT   R7, R7, #0
        SavePSR R8
        MUL     R0, R1, R7
        DivRem  R7, R0, #&BB, R14, norem
        RestPSR R8,,f
        ADDLT   R4, R4, R7
        SUBGT   R4, R4, R7
10
01      ; recombine RGB from R2, R3, R4
        MOV     R0, R2, LSL #8
        ORR     R0, R0, R3, LSL #16
        ORR     R0, R0, R4, LSL #24

        EXIT
    ]

;;-----------------------------------------------------------------------------
;; restore_tool_list
;; Get a valid tool list from the backup (which is never freed to save bashing the RMA)
;; Entry: -
;; Exit:  R2 -> first sprite in the tools list
;;-----------------------------------------------------------------------------

restore_tool_list
        ADRL    R2,tool_list_backup
        LDR     R2,[R2]                 ; tool list pointer
        STR     R2,tool_list
        LDR     R2,[R2]                 ; get first tool, we assume that this is representitive
        MOV     PC, LR

 [ TrueIcon3
;;-----------------------------------------------------------------------------
;; recache_tools_trans
;; Regenerate the pixel translation tables for the tool sprites
;; In: R2 -> sprite representative of one in the tool_list
;;-----------------------------------------------------------------------------

recache_tools_trans
        Push    "R0-R4,R14"

        BIC     R2,R2,#1
        STR     R2,spritename
        MOV     R2,#0
        STR     R2,lengthflags          ; flag it's a sprite address (not a name)

        MOV     R14,#0
        STR     R14,tool_transtable     ; might move during cachetoolspritedata so kill it

        BL      cachetoolspritedata     ; this sets up the tool pixtable area

        CLRV                            ; clear errors
        Pull    "R0-R4,PC"
 ]

        LTORG

        END
