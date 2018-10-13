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
;**************************************************************************
;* CDFSFiler - source
;**************************************************************************

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Services
        GET     Hdr:ModHand
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:NewErrors
        GET     Hdr:Wimp
        GET     Hdr:WimpSpace
        GET     Hdr:Messages
        GET     Hdr:Sprite
        GET     Hdr:VduExt
        GET     Hdr:Variables
        GET     Hdr:Proc
        GET     Hdr:ShareD
        GET     Hdr:MsgMenus
        GET     Hdr:MsgTrans
        GET     Hdr:ResourceFS
        GET     Hdr:CDROM
        GET     Hdr:CDErrors
        GET     Hdr:CDFS
        GET     Hdr:Hourglass

        GET     Hdr:HostFS
        GET     Hdr:NdrDebug
        GET     Hdr:DDVMacros

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Local header
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        GET     hdr.Icons
        GET     VersionASM

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Options
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                        GBLL    CheckConfiguredDrives   ; don't start up if conf.drives=0
CheckConfiguredDrives   SETL    {TRUE}

                        GBLL    ReadCDIDiscs            ; read CDI discs and change icon if TRUE
ReadCDIDiscs            SETL    {FALSE}

                        GBLL    UseConfigureToConfigure ; no configuration option in the menu
UseConfigureToConfigure SETL    {TRUE}

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Debugging options
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        GBLL    hostvdu
hostvdu SETL    true

        GBLL    debug
debug   SETL    false

startup SETD    false
click   SETD    false
media   SETD    false
service SETD    false
menus   SETD    false

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Register names
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; sp            RN      r13                ; FD stack
; wp            RN      r12

scy             RN      r11
scx             RN      r10
y1              RN      r9
x1              RN      r8
y0              RN      r7
x0              RN      r6
cy1             RN      r5                 ; Order important for LDMIA
cx1             RN      r4
cy0             RN      r3
cx0             RN      r2

; r0,r1 not named

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Macro definitions
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        MACRO
$label  FixDCB  $n, $string
        ASSERT  ((:LEN:"$string")<$n)
$label  DCB     "$string"
        LCLA    cnt
cnt     SETA    $n-:LEN:"$string"
        WHILE   cnt>0
        DCB     0
cnt     SETA    cnt-1
        WEND
        MEND

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Constants
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

TAB                         * 9
LF                          * 10
CR                          * 13
space                       * 32
delete                      * 127
icon_bar_height             * 134

                            ^ &4BE00
Message_CDFSFilerOpenPlayer # 1 

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Data structure offsets
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; format of icon description blocks

                ^       -1
icb_validation  #       1                  ; "S" for validation string
icb_drivetype   #       12                 ; first byte is "h" or "f"
                ^       0                  
icb_drivenumber #       4                  ; ":nn",0

; format of disc name blocks (fixed size, held in main workspace)

                ^       0
drv_number      #       4                  ; ":nn",0
drv_iconblock   #       4                  
drv_namelen     #       1                  ; length of ":discname"
drv_name        #       32                 ; "discname",0
drv_reserved    #       23                 ;to pad to 64 bytes
drv_size        #       0                  
drv_shift       *       6
        ASSERT  drv_size = (1 :SHL: drv_shift)
        ASSERT  (drv_iconblock :AND: 3) = 0

len_colon       *       0                  ; don't include ":" in discname
len_mediaprefix *       :LEN:"CDFS::"-len_colon

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Workspace allocation
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                ^       0, wp
mywimpversion   #       4                  ; another wimp version
 [ Module_Version >= 213                   
loop            #       4                  
 ]                                         
                                           
mytaskhandle    #       4                  ; id so we can kill ourselves
FilerHandle     #       4                  ; id so we can contact Filer
privateword     #       4                  
wimpversion     #       4                  
privatesprites  #       4                  ; the private player icons
                                           
 [ Module_Version > 201                    
messagedata     #       4                  
 ]                                         
                                           
mousedata       #       0                  
mousex          #       4                  
mousey          #       4                  
buttonstate     #       4                  
windowhandle    #       4                  
iconhandle      #       4                  
menuhandle      #       4                  
msgbounces      #       4
                                           
ndrives         *       28                 ; allow for drives 0..27
iconbaricons    #       ndrives*4          ; associate icon handle with index
discnames       #       ndrives*drv_size   ; associate index with drive spec.
activeplayers   #       4                  ; how many players actually playing
matchedindex    #       4                  ; index of last icon matched
                                           
; FIXME MENU (modify after menu)           
 [ UseConfigureToConfigure
ROOT_MENU_ITEMS *       5
 |
ROOT_MENU_ITEMS *       6
 ]

ram_menustart   #       0
m_cdromdisc     #       m_headersize + mi_size*ROOT_MENU_ITEMS
 [ :LNOT: UseConfigureToConfigure
m_configure     #       m_headersize + mi_size*2
 ] 
m_sharedisc     #       m_headersize + mi_size*2
 [ :LNOT: UseConfigureToConfigure
m_buffers       #       m_headersize + mi_size*8
m_drives        #       m_headersize + mi_size*1
 ]
ram_menuend     #       0
 [ :LNOT: UseConfigureToConfigure
mb_drives       #       4                  ; aligned, with room for terminator
mb_buffers      #       4                  ; aligned, with room for terminator
 ]                                           
menudrive       #       4                  ; the disc name block of the last-opened menu
sharewindrive   #       4                  ; the disc name block of the share window
volumewindrive  #       4                  ; the disc name block of the volume window
                                           
dragging        #       4                  ; flag to say whether we're dragging the volume bar
draggingvolume  #       4                  ; for optimisation when dragging
                                           
cd_namedisc     #       4                  ; for indirect data

;-----------------------------------       
; structures for access                    
;-----------------------------------       
                                           
sharebufferind          #       4          
sharewin_handle         #       4          ; Window handle

buffershare             #       96
buffertemp              #       96
buffertemp2             #       96
m_tempdisc              #       32
m_tempdisc2             #       32
sharename               #       32
bufferlen               #       4
bufferlen2              #       4

;-----------------------------------
; structures for volume
;-----------------------------------

volumebufferind         #       4
volumewin_handle        #       4
volume_title_text       #       4
volume_title_length     #       4
CurrentVolumeDrive      #       4
OldVolumeSetting        #       4

playerstate_playing     *       0
playerstate_paused      *       1          ; bits 0-3 are old status from CD_AudioStatus
playerstate_reserved0   *       2
playerstate_complete    *       3
playerstate_reserved1   *       4
playerstate_notasked    *       5
playerstate_unused0     *       16         ; bits 4-7 are misc private status bits
playerstate_unused1     *       32
playerstate_halted      *       64
playerstate_exists      *       128
playerstate_listposn    *       8          ; bits 8-15 are where we are in the track list
                                           ; allow for 254 tracks,an entry of 255 terminates the list
playerstate_timer       *       16         ; bits 15-23 are the SS part of the time,to reduce flicker
playerstate_track       *       24         ; bits 24-31 are the current track number,to reduce flicker

playerstate_list        #       4*ndrives  ; what the player is doing
player_playlists        #       4*ndrives  ; pointers to 99 byte lists in the RMA (redbook CD spec says 99 is your limit)

;-----------------------------------
; misc buffers
;-----------------------------------

        AlignSpace      16

dirnamebuffer           #       &100
userdata                #       &400
stackbot                #       &200
stacktop                #       0

 [ Module_Version >= 213
sprite_name_list        #     12*ndrives   ; icons for each drive
 ]


CDFSFiler_WorkspaceSize *  :INDEX: @

 ! 0, "CDFSFiler workspace is ":CC:(:STR:(:INDEX:@)):CC:" bytes"


driveno *       m_cdromdisc + m_title + :LEN:"CDFS:"


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Module header
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        AREA    |CDFSFiler$$Code|, CODE, READONLY, PIC

Module_BaseAddr

        DCD     CDFSFiler_Start        -Module_BaseAddr
        DCD     CDFSFiler_Init         -Module_BaseAddr
        DCD     CDFSFiler_Die          -Module_BaseAddr
        DCD     CDFSFiler_Service      -Module_BaseAddr
        DCD     CDFSFiler_TitleString  -Module_BaseAddr
        DCD     CDFSFiler_HelpString   -Module_BaseAddr
        DCD     CDFSFiler_CommandTable -Module_BaseAddr
        DCD     0
        DCD     0
        DCD     0
        DCD     0
 [ International_Help <> 0
        DCD     str_messagefile        -Module_BaseAddr
 |
        DCD     0
 ]
        DCD     CDFSFiler_ModuleFlags  -Module_BaseAddr

CDFSFiler_HelpString
        DCB     "CDFSFiler"
        DCB     TAB
        DCB     "$Module_HelpVersion", 0

 [ International_Help <> 0
Desktop_CDFSFiler_Help
        DCB     "HCFLDCF",0
Desktop_CDFSFiler_Syntax
        DCB     "SCFLDCF",0
 |
Desktop_CDFSFiler_Help
        DCB   "The CDFSFiler provides the CDFS icons on the icon bar, and "
        DCB   "uses the Filer to display CDFS directories.",13,10
        DCB   "Do not use *Desktop_CDFSFiler, use *Desktop instead.",0

Desktop_CDFSFiler_Syntax  DCB   "Syntax: *Desktop_"       ; drop through!
 ]

CDFSFiler_TitleString     DCB   "CDFSFiler", 0

 [ Module_Version > 201
CDFSFiler_Banner          DCB   "CDFS Filer", 0
 ]

                          ALIGN

CDFSFiler_ModuleFlags
        DCD     ModuleFlag_32bit

CDFSFiler_CommandTable
              ; Name                   Max Min Flags

CDFSFiler_StarCommand
        Command Desktop_CDFSFiler,     0,  0,  International_Help


        DCB     0                       ; End of table


;-----------------------------------------------
; Where the player sprites are stashed
;-----------------------------------------------

spritefile = "CDFSFiler:Player", 0

        ALIGN
;-----------------------------------------------

        LTORG

;-----------------------------------------------------------------
; Set the 'CDFSFiler$Path' variable
;-----------------------------------------------------------------

        [ Module_Version > 201

CDFSFiler_Init  Entry "r1-r5"

; initialise CDFSFiler$Path if not already done

        Debug   startup, "CDFSFiler_Init"

        ADR     r0, Path
        MOV     r2, #-1
        MOV     r3, #0
        MOV     r4, #VarType_Expanded
        SWI     XOS_ReadVarVal          ; returns R2=0 if doesn't exist
        CMP     r2, #0                  ; clears V as well!

        ADREQ   r0, Path
        ADREQ   r1, PathDefault
        MOVEQ   r2, #?PathDefault
        MOVEQ   r3, #0
        MOVEQ   r4, #VarType_String
        SWIEQ   XOS_SetVarVal
        EXIT

Path            DCB     "CDFSFiler$$Path"
                DCB     0
PathDefault     DCB     "Resources:$.Resources.CDFSFiler."
                DCB     0
                ALIGN

        ]


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Had *command to enter CDFSFiler, so start up via module handler


        [ Module_Version > 201


Desktop_CDFSFiler_Code Entry

        Debug   startup, "Desktop_CDFSFiler_Code"

        LDRB    r14,[r0]
        CMP     r14,#32
        TEQGE   r14,r14
        MOVEQ   r2,r0
        BEQ     %FT00

        LDR     r14, [r12]
        CMP     r14, #0
        BLE     %FT01


        LDR     r14, [r14, #:INDEX:mytaskhandle]
        CMP     r14, #0

        MOV     r2,r0

00
        MOVEQ   r0, #ModHandReason_Enter
        ADREQL  r1, CDFSFiler_TitleString
        SWIEQ   XOS_Module
01
        BL      MkCantStartError
        EXIT


ErrorBlock_CantStartCDFSFiler
        DCD     0
        DCB     "UseDesk", 0
        ALIGN

        |                  ;  Old way

Desktop_CDFSFiler_Code Entry

        LDR     r14, [r12]
        CMP     r14, #0
        BLE     %FT01

        LDR     r14, [r14, #:INDEX:mytaskhandle]
        CMP     r14, #0
        MOVEQ   r0, #ModHandReason_Enter
        ADREQ   r1, CDFSFiler_TitleString
        SWIEQ   XOS_Module
01
        ADR     r0, ErrorBlock_CantStartCDFSFiler
        CMP     r0, #&80000000
        CMNVC   r0, #&80000000 ; SETV
        EXIT

ErrorBlock_CantStartCDFSFiler
        DCD     0
        DCB     "Use *Desktop to start CDFSFiler", 0
        ALIGN


        ] ; Old RISC OS 2 way




; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ServiceTable

        DCD     0
        DCD     ServiceUrsula - Module_BaseAddr
        DCD     Service_Reset
        DCD     Service_StartFiler
        DCD     Service_StartedFiler
        DCD     Service_FilerDying
      [ Module_Version > 201
        DCD     Service_MessageFileClosed
      ]
        DCD     0
        DCD     ServiceTable - Module_BaseAddr
CDFSFiler_Service ROUT

        MOV     r0,r0
        TEQ     r1, #Service_Reset
      [ Module_Version > 201
        TEQNE   r1, #Service_MessageFileClosed
      ]
        TEQNE   r1, #Service_FilerDying
        TEQNE   r1, #Service_StartFiler
        TEQNE   r1, #Service_StartedFiler
        MOVNE   pc, lr

ServiceUrsula
        TEQ     r1, #Service_Reset            ; &27
        BEQ     CDFSFiler_Service_Reset

      [ Module_Version > 201
        TEQ     r1, #Service_MessageFileClosed ; &5e
        BEQ     CDFSFiler_Service_MessageFileClosed
      ]

        TEQ     r1, #Service_FilerDying       ; &4f
        BEQ     CDFSFiler_Service_FilerDying

        TEQ     r1, #Service_StartFiler       ; &4b
        BEQ     CDFSFiler_Service_StartFiler

        TEQ     r1, #Service_StartedFiler     ; &4c
        MOVNE   pc, lr
        ; Drop through to...


CDFSFiler_Service_StartedFiler Entry

        Debug   startup, "CDFSFiler_Service_StartedFiler"

        LDR     r14, [r12]              ; cancel 'don't start' flag
        CMP     r14, #0
        MOVLT   r14, #0
        STRLT   r14, [r12]

        EXIT

CDFSFiler_Service_StartFiler Entry "r0-r3"

        Debug   startup, "CDFSFiler_Service_StartFiler"

        LDR     r2, [r12]
        CMP     r2, #0
        EXIT    NE                      ; don't claim service unless = 0

 [ CheckConfiguredDrives
        SWI     XCDFS_GetNumberOfDrives ; Try to get number of configured drives.
        EXIT    VS                      ; Give up if it fails
        TEQ     r0, #0                  ; or no drives configured.
        EXIT    EQ
 ]

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =CDFSFiler_WorkspaceSize
        SWI     XOS_Module
        MOVVS   r2, #-1                 ; avoid looping
        STR     r2, [r12]
        EXIT    VS

        MOV     r0, #0

        [ Module_Version > 201
        STR     r0, [r2, #:INDEX:messagedata]
        STR     r0, [r2, #:INDEX:privatesprites]
        ]

        STR     r0, [r2, #:INDEX:mytaskhandle]
        STR     r12, [r2, #:INDEX:privateword]
        LDR     r0, [sp]
        STR     r0, [r2, #:INDEX:FilerHandle]

        PullEnv
        ADRL    r0, CDFSFiler_StarCommand
        MOV     r1, #0                  ; Claim service
        MOV     pc, lr


CDFSFiler_Service_Reset Entry "r0-r6"

        LDR     r2, [r12]               ; cancel 'don't start' flag
        CMP     r2, #0
        MOVLT   r2, #0
        STRLT   r2, [r12]

        MOVGT   wp, r2
        MOVGT   r0, #0                  ; Wimp has already gone bye-bye
        STRGT   r0, mytaskhandle
        BLGT    freeworkspace

        EXIT


      [ Module_Version > 201
CDFSFiler_Service_MessageFileClosed Entry "r0-r2,r12"

        LDR     r12, [r12]              ; are we active?
        CMP     r12, #0
        EXIT    LE

        Debug   service,"Service_MessageFileClosed r0=",r0

        [ Module_Version >=236
        ADRL    r1, driveno+1           ; preserve drive number across menu creation
        LDRB    r2, [r1]
        ]

        BL      CopyMenus               ; re-open message file etc.

        [ Module_Version >= 236
        STRB    r2, [r1]
        ]

        EXIT
      ]

        LTORG

CDFSFiler_Die ROUT

CDFSFiler_Service_FilerDying Entry "r0-r6"

        LDR     wp, [r12]
        BL      freeworkspace

        CMP     r0, #0                 ; Sorry, but no can do errors here
        EXIT



; ------------------------------------------------------------------------------

; Corrupts r0-r6

freeworkspace ROUT

        CMP     wp, #0                 ; clears V
        MOVLE   pc, lr

        MOV     r6, lr                 ; can't use stack on exit if USR mode

        LDR     r0, mytaskhandle
        CMP     r0, #0
        LDRGT   r1, taskidentifier
        SWIGT   XWimp_CloseDown        ; ignore errors from this

        LDR     r2, privatesprites
        TEQ     r2, #0
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module

        MOV     r3, #ndrives-1
        ADRL    r1, player_playlists
05
        LDR     r2, [r1, r3, LSL#2]    ; release any track listings
        TEQ     r2, #0
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
        SUBS    r3, r3, #1
        BPL     %BT05

        [ Module_Version > 201
        BL      deallocatemessagedata   ; well actually we can until we free
        ]


        MOV     r2, r12
        LDR     r12, privateword
        MOV     r14, #0                ; reset flag word anyway
        STR     r14, [r12]
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        MOV     pc, r6

taskidentifier
        DCB     "TASK"                 ; Picked up as a word
        ALIGN


;-------------------------------------------
; Added for RISC OS 3
;-------------------------------------------

 [ Module_Version > 201

MessagesList    DCD     Message_HelpRequest
                DCD     Message_MenuWarning
                DCD     Message_WindowClosed
                DCD     Message_CDFSFilerOpenPlayer
                DCD     0
 ]

;-------------------------------------------

CloseDownAndExit ROUT

        BL      freeworkspace
        SWI     OS_Exit

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                   CDFSFiler application entry point
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ErrorAbort
        MOV     r1, #2_010              ; 'Cancel' button
        BL      ReportError             ; stack is still valid here

Abort
        Debug   startup, "Abort"

        BL      freeworkspace           ; exits with r12 --> private word
        MOV     r0, #-1
        STR     r0, [r12]               ; marked so doesn't loop

        SWI     OS_Exit

;------------------------------------------------------------
; Get text from the messages file
;------------------------------------------------------------

        [ Module_Version > 201

MkCantStartError
        MOV     r8, lr
        ADR     r0, ErrorBlock_CantStartCDFSFiler
        MOV     r1, #0
        MOV     r2, #0
        addr    r4, CDFSFiler_TitleString
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
        MOV     pc, r8

        ]

;------------------------------------------------------------

w_share         DCB     "Share",0                 ; menu handle
                DCD     0,0,0
                ALIGN
w_volume        DCB     "Configure",0,0,0
                ALIGN

b_playout       DCB "Scd_pyo",0
                ALIGN
b_playin        DCB "Scd_pyi",0
                ALIGN
b_pauseout      DCB "Scd_pso",0
                ALIGN
b_pausein       DCB "Scd_psi",0
                ALIGN

;------------------------------------------------------------

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; OSS New function to copy template name onto the stack and then call
; Wimp_LoadTemplate since the wimp may over-write the name. We were
; lucky to get away with this previously.

; In    r1 -> user block to put template
;       r2 -> core to put indirected icons for template
;       r3 -> end of this core
;       r4 -> font reference array
;       r5 -> name of relevant entry
;       r6 = position to search from

load_template Entry , 16                ; 16 bytes of stack for name
        MOV     lr, sp
        Push    "r1, r2"
        MOV     r1, lr
        MOV     r2, r5
        BL      strcpy
        MOV     r5, r1                  ; And use this name instead
        Pull    "r1, r2"
        SWI     XWimp_LoadTemplate
        EXIT


CDFSFiler_Start ROUT

        LDR     wp, [r12]

        CMP     wp, #0

;----------------------------------------------
; Get an error message from the 'Messages' file
;----------------------------------------------

        [ Module_Version > 201
        BLLE    MkCantStartError                         ; New way
        SWIVS   OS_GenerateError                         ;
        |
        ADRLE   r0, ErrorBlock_CantStartCDFSFiler        ; Old way
        SWILE   OS_GenerateError                         ;
        ]

;----------------------------------------------

        ADRL    sp, stacktop            ; STACK IS NOW VALID!

        LDR     r0, mytaskhandle        ; close any previous incarnation
        CMP     r0, #0
        LDRGT   r1, taskidentifier
        SWIGT   XWimp_CloseDown         ; ignore errors from this

;--------------------------------------------------
; We know about wimp 3.00 and have a messages list.
;--------------------------------------------------

        [ Module_Version > 201
        MOV     r0, #300                 ; NEW - know about wimp 3.00 and have a messages list.
        LDR     r1, taskidentifier
        BL      MkBannerIn_userdata

        ADRVC   r3, MessagesList
        SWIVC   XWimp_Initialise
        STRVC   r0, wimpversion
        STRVC   r1, mytaskhandle
        |
        MOV     r0, #200                 ; OLD - latest known Wimp version number
        LDR     r1, taskidentifier
        addr    r2, CDFSFiler_Banner
        SWI     XWimp_Initialise
        STRVC   r0, wimpversion
        STRVC   r1, mytaskhandle
        ]

;--------------------------------------------------

        BLVC    CopyMenus               ; copy menus into ram
        BVS     ErrorAbort

        ADR     r1, iconbaricons        ; initialise all icon handles to -1
        ADRL    r3, player_playlists    ; initialise all playlists to non existant
        ADRL    r4, playerstate_list    ; scan the drives and mark as exists
        MOV     r2, #0                  ; (used in AddToIconBar)
01      MOV     r14, #-1
        STR     r14, [r1], #4
        MOV     r14, #0
        STR     r14, [r3], #4
        MOV     r0, r2
        BL      MakeCDFSblockinR7       ; drive exist?
        MOV     r14, #playerstate_halted
        ORRVC   r14, r14, #playerstate_exists
        STR     r14, [r4], #4
        ADD     r2, r2, #1
        TEQ     r2, #ndrives
        BNE     %BT01

        ADRL    r1, spritefile
        MOV     r0, #OSFile_ReadNoPath
        SWI     XOS_File
        TEQ     r0, #0
        BEQ     Abort                   ; someone hid the player sprites,so give up
        MOV     r0, #ModHandReason_Claim
        ADD     r3, r4, #16
        SWI     XOS_Module
        BVS     ErrorAbort
        STR     r2, privatesprites
        STR     r3, [r2, #saEnd]
        MOV     r3, #0

        STR     r3, activeplayers       ; there are no active players
        STR     r3, dragging            ; and we're not dragging

        STR     r3, [r2, #saNumber]
        MOV     r3, #16
        STR     r3, [r2, #saFirst]
        STR     r3, [r2, #saFree]

        MOV     r1, r2
        ADRL    r2, spritefile
        MOV     r0, #SpriteReason_LoadSpriteFile
        ORR     r0, r0, #256            ; load player sprites in
        SWI     XOS_SpriteOp
        BVS     ErrorAbort

        BL      SetUpIconBar
        BVS     ErrorAbort              ; frees workspace but marks it invalid

        LDR     R14,iconbaricons        ; give up if no drives (or error)
        CMP     R14,#-1
        BEQ     Abort

        ADRL    R1,str_templatefile
        SWI     XWimp_OpenTemplate
        BVS     ErrorAbort

; OSS Ask the Wimp how much memory we need for share window.
        MOV     r1,#-1
        MOV     r4,#-1
        ADR     r5,w_share
        MOV     r6,#0
        BL      load_template           ; get size required for template
        BVS     TemplateErrorAbort

        Push    r2

; Now ask the Wimp how much memory we need for player window.
        MOV     r1,#-1
        MOV     r4,#-1
        ADR     r5,w_volume
        MOV     r6,#0
        BL      load_template           ; get size required for template
        Pull    r4
        BVS     TemplateErrorAbort

        ADD     r3, r2, r4

; OSS Claim memory for the indirected data.
        MOV     r0,#ModHandReason_Claim
        SWI     XOS_Module
        BVS     TemplateErrorAbort
        STR     r2,sharebufferind
        ADD     r4, r2, r4
        STR     r4, volumebufferind

; OSS Now load the template and create the window - the main window buffer
; is in userdata as it can be thrown away as soon as the window has been
; created.
        ADR     r1,userdata
        ADD     r3,r2,r3                ; Add size to pointer to give limit
        MOV     r4,#-1
        ADR     r5,w_share
        MOV     r6,#0
        BL      load_template
        SWIVC   XWimp_CreateWindow
        STRVC   r0,sharewin_handle
        BVS     TemplateErrorAbort
        ADR     r1, userdata
        LDR     r2, volumebufferind
        ADR     r5, w_volume
        MOV     r6, #0
        BL      load_template           ; r3,r4 preserved from above
        LDR     r0, privatesprites
        STR     r0, [r1, #64]           ; use local sprite pool in the player window
        SWIVC   XWimp_CreateWindow
        STRVC   r0, volumewin_handle
        BVS     TemplateErrorAbort

        ADRL    lr, userdata+72
        LDMIA   lr, {r1-r3}
        STR     r1, volume_title_text
        STR     r3, volume_title_length
        SWI     XWimp_CloseTemplate
        BVS     ErrorAbort

        B       %FT01

TemplateErrorAbort

        Push    "r0"
        SWI     XWimp_CloseTemplate
        Pull    "r0"
        CMP     r0, #&80000000
        CMNVC   r0, #&80000000 ; SETV
        B       ErrorAbort
01

        BL      check_access

; ..........................................................................
; The main polling loop!

repollwimp ROUT

        MOVVS   r1, #2_001              ; 'Ok' button
        BLVS    ReportError
        BVS     ErrorAbort              ; error from reporterror!

        MOV     r2, #64                 ; used as a test later (can't play a CD within 64cs of power on!)
        LDR     r1, activeplayers
        TEQ     r1, #0
        SWINE   XOS_ReadMonotonicTime
        TEQ     r1, #0
        ADDNE   r2, r0, #50             ; about half a second sleep
        LDR     r1, dragging
        TEQ     r1, #0
        MOVNE   r2, #0                  ; emulate Wimp_Poll
        TEQ     r2, #64                 ; enable null events?
        MOVNE   r0, #pointerchange_bits ; enable null events if a player is active or dragging volume
        MOVEQ   r0, #pointerchange_bits + null_bit
        ADRL    r1, userdata
        SWI     XWimp_PollIdle
        BVS     repollwimp

; In    r1 -> wimp_eventstr
        CMP     r0, #Open_Window_Request
        BNE     %FT02
        SWI     XWimp_OpenWindow
        B       repollwimp
02
        CMP     r0, #Redraw_Window_Request
        LDREQ   lr, [r1]
        LDREQ   r2, volumewin_handle
        TEQEQ   lr, r2
        BEQ     event_redraw_volume

        ADR     lr, repollwimp

        CMP     r0, #Mouse_Button_Change
        BEQ     event_mouse_click

 [ Module_Version >= 236
        CMP     r0, #Key_Pressed
        BEQ     event_key_pressed
 ]

        CMP     r0, #Menu_Select
        BEQ     event_menu_select

        CMP     r0, #User_Message
        CMPNE   r0, #User_Message_Recorded
        BEQ     event_user_message

        CMP     r0, #User_Drag_Box
        BEQ     event_drag_box

        CMP     r0, #Close_Window_Request
        BEQ     event_window_shut

        CMP     r0, #0
        BEQ     event_null

        B       repollwimp


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


event_drag_box
        MOV     r1, #0
        STR     r1, dragging
        SWI     XWimp_DragBox
        B       repollwimp

event_null
        Push    "lr"
        ADRL    r3, playerstate_list
        MOV     r2, #ndrives-1
02
        LDR     r0, [r3, r2, LSL#2]
        TST     r0, #playerstate_exists
        BLNE    player_service    ; go see if anything interesting happened 
        STR     r0, [r3, r2, LSL#2]
        SUBS    r2, r2, #1
        BPL     %BT02
05
        LDR     r0, dragging
        TEQ     r0, #0
        Pull    "pc",EQ           ; we got here because of the half second heartbeat not a drag
        ADRL    r1, userdata
        SWI     XWimp_GetPointerInfo
        LDR     r0, [r1]
        B       event_volume_bar  ; as though we'd clicked on it again

 [ Module_Version >= 236

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_key_pressed
; =================

; In    r1 -> wimp_eventstr
;             [r1, #0]  window handle
;             [r1, #4]  icon handle (-1 if none)
;             [r1, #8]  x offset of caret
;             [r1, #12] y offset of caret
;             [r1, #16] caret height and flags
;             [r1, #20] index of caret into string (if in an icon)
;             [r1, #24] character code of key pressed (word not byte)

; Out   all regs may be corrupted - going back to PollWimp

event_key_pressed
        LDR     r0, [r1]                ; Make sure it's the share window.
        LDR     r2, sharewin_handle
        TEQ     r0, r2
        MOVNE   pc, lr

        LDR     r0, [r1, #24]           ; If Return pressed then share.
        TEQ     r0, #13
        BEQ     GoShare_disc

        Entry                           ; Otherwise, process key.
        SWI     XWimp_ProcessKey
        EXIT

 ]

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_mouse_click
; =================

; In    r1 -> wimp_eventstr
;             [r1, #0]  pointer x
;             [r1, #4]          y
;             [r1, #8]  new button state
;             [r1, #12] window handle (-1 if background/icon bar)
;             [r1, #16] icon handle (-1 if none)

; Out   all regs may be corrupted - going back to PollWimp

event_mouse_click  Entry

        LDMIA   r1, {r0-r4}             ; set mousex, mousey, buttonstate
        ADR     r14, mousedata          ; windowhandle, iconhandle
        STMIA   r14, {r0-r4}

        LDR     lr, volumewin_handle
        TEQ     r3, lr
        BEQ     event_volume_window_click

        CMP     r3, #iconbar_whandle    ; window handle of icon bar
        BNE     Share_MouseClick        ; could be share window

        TST     r2, #button_left :OR: button_right ; select or adjust ?
        BNE     click_select_iconbar

        TST     r2, #button_middle      ; menu ?
        BNE     click_menu_iconbar

        EXIT

Share_MouseClick

        CMP     r4,#5                   ; Is it the cancel button ?
        BNE     %FT01

        ADR     r1, userdata            ; close share window
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        SWI     XWimp_CloseWindow
        B       %FT99
01
        CMP     r4, #3
        PullEnv EQ
        BEQ     GoShare_disc
99
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_volume_window_click
; =========================
;
; In    r0 =  pointer x
;       r1 =          y
;       r2 =  new button state
;       r3 =  window handle (-1 if background/icon bar)
;       r4 =  icon handle (-1 if none)
;
; This deals with mouse button clicks on the volume window
;

event_volume_window_click

      TST       r2, #button_left :OR: button_right ; select or adjust ?
      EXIT      EQ

      TEQ       r4, # VOLUME__PLAY
      BEQ       event_player_play

      TEQ       r4, # VOLUME__STOP
      BEQ       event_player_stop

      TEQ       r4, # VOLUME__PAUSE
      BEQ       event_player_pause

      TEQ       r4, # VOLUME__EJECT
      BEQ       event_player_eject

      TEQ       r4, # VOLUME__SKIPFWD
      MOVEQ     r5, # +1
      BEQ       event_player_skip

      TEQ       r4, # VOLUME__SKIPBACK
      MOVEQ     r5, # -1
      BEQ       event_player_skip

      TEQ       r4, # VOLUME__SHUFFLE
      BEQ       event_player_shuffle

      TEQ       r4, # VOLUME__DRAW_BAR
      MOVEQ     r14, #&80000000
      STREQ     r14, draggingvolume
      BEQ       event_volume_bar

      EXIT

;--------------------------------------------------
event_window_shut
; In    r1 -> wimp_eventstr
;             [r1, #0]  window handle
;
; Closes the player window,and stores the volume setting
;
;--------------------------------------------------

      LDR     r0, [r1]                ; Make sure it's the player window.
      LDR     r2, volumewin_handle
      TEQ     r0, r2
      BNE     repollwimp
      SWI     XWimp_CloseWindow 

; Set the current volume
      LDR     r0, CurrentVolumeDrive
      BL      get_volume_level
      MOVVS   r0, #0
      STR     r0, OldVolumeSetting

      LDR     r3, activeplayers
      SUBS    r3, r3, #1
      MOVMI   r3, #0
      STR     r3, activeplayers
      
      B       repollwimp              ; we only have one window with a close button,so close it


;--------------------------------------------------
event_volume_bar
; In    r0 =  pointer x
;       r1 =          y
;       r2 =  new button state
;       r3 =  window handle (-1 if background/icon bar)
;       r4 =  icon handle (-1 if none)
;
; This deals with clicks on the volume bar
;
;--------------------------------------------------

      MOV       r5, r0

      ADRL      r1, userdata
      LDR       r2, volumewin_handle
      STR       r2, [ r1 ]
      SWI       XWimp_GetWindowState
      EXIT      VS

      LDR       r2, [ r1, # 4 ]             ; min. x
      LDR       r3, [ r1, # 20 ]            ; scroll x
      SUB       r6, r3, r2                  ; work area x coord of screen origin
      LDR       r2, [ r1, # 16 ]            ; max. y
      LDR       r3, [ r1, # 24 ]            ; scroll y
      SUB       r7, r3, r2                  ; work area y coord of screen origin

      ADD       r2, r5, r6                  ; work area x coord of pointer

; r2 = x position in bar icon

; Get the width of the icon
      MOV       r3, # VOLUME__DRAW_BAR
      STR       r3, [ r1, # 4 ]

      SWI       XWimp_GetIconState
      LDR       r3, [ r1, # 8 + 8 ]         ; max x of slider
      LDR       r4, [ r1, # 8 + 0 ]         ; min x of slider
      SUB       r3, r3, r4

      SUBS      r2, r2, r4
      MOVLT     r2, # 0

; r2 = r2 * MAX_VOLUME (or close enough)
      MOV       r2, r2, LSL # 16

; r4 = r2 / icon width
      DivRem    r4, r2, r3, r14, norem

; make sure that min.(0) and max.(&ffff) values not exceeded
      CMP       r4, # 0
      MOVLT     r4, # 0
      CMP       r4, # &10000
      MOVGE     r4, # &ffffffff
      MOVGE     r4, r4, LSR # 16

      LDR       r14, draggingvolume
      TEQ       r4, r14
      EXIT      EQ
      STR       r4, draggingvolume

      LDR       r0, CurrentVolumeDrive
      MOV       r1, r4
      BL        set_volume_level

; ensure the pointer is constrained
      ADRL      r1, userdata
      ADD       lr, r1, #8
      LDMIA     lr, {r2-r5}                 ; still contains work area coords of slider icon
      SUB       r2, r2, r6
      SUB       r3, r3, r7
      SUB       r4, r4, r6
      SUB       r5, r5, r7
      ADD       lr, r1, #24
      STMIA     lr, {r2-r5}                 ; store screen coords of icon
      LDR       r2, volumewin_handle
      MOV       r3, #7                      ; drag type 7 = drag point
      STMIA     r1, {r2, r3}
      SWI       XWimp_DragBox

      MOV       r1, #1
      STR       r1, dragging

; Redraw the bar
      ADRL      r1, userdata
      LDR       r2, volumewin_handle
      MOV       r3, # VOLUME__DRAW_BAR
      MOV       r4, # 0
      MOV       r5, # 0
      STMIA     r1, { r2, r3, r4, r5 }

      SWI       XWimp_SetIconState

      EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_player_skip
;
; In: r5 = signed delta to apply

event_player_skip
      LDR       r0, CurrentVolumeDrive

      ADRL      r2, player_playlists
      ADD       r2, r2, r0, LSL#2
      LDR       r3, [r2]                       ; now we have the pointer to the list of tracks

      ADRL      r2, playerstate_list
      ADD       r2, r2, r0, LSL#2
      LDR       r1, [r2]
      BIC       r1, r1, #playerstate_halted    ; mark as playing incase the drive lies
      STR       r1, [r2]
      ASSERT    playerstate_listposn = 8
      AND       r1, r1, #&0000FF00
      MOV       r1, r1, LSR#8                  ; current offset within the list

      ADDS      r5, r1, r5
      MOVMI     r5, #0

      BL        MakeCDFSblockinR7
      LDRB      r0, [r3, r5]
      TEQ       r0, #255
      BEQ       event_player_stop

      STRB      r5, [r2, #1]                   ; note new list position
      MOV       r1, #254
      SWI       XCD_PlayTrack
      B         repollwimp

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_player_play
;

event_player_play
      LDR       r0, CurrentVolumeDrive
      BL        MakeCDFSblockinR7
      SWI       XCD_AudioStatus
      CMP       r0, #playerstate_playing
      BEQ       repollwimp                     ; pressing it twice wont make it play any quicker
      CMP       r0, #playerstate_paused
      BEQ       event_player_pause             ; was paused,unpause it
      LDR       r0, CurrentVolumeDrive
      ADRL      r2, player_playlists
      ADD       r2, r2, r0, LSL#2
      LDR       r3, [r2]                       ; now we have the pointer to the list of tracks

      ADRL      r2, playerstate_list
      ADD       r2, r2, r0, LSL#2
      LDR       r1, [r2]
      BIC       r1, r1, #playerstate_halted    ; mark as playing incase the drive lies
      STR       r1, [r2]
      ASSERT    playerstate_listposn = 8
      AND       r1, r1, #&0000FF00
      MOV       r1, r1, LSR#8                  ; current offset within the list
10
      LDRB      r0, [r3, r1]
      TEQ       r0, #255
      BEQ       repollwimp                     ; no audio tracks left to play
15
      MOV       r1, #254
      SWI       XCD_PlayTrack
      LDR       r3, activeplayers
      ADD       r3, r3, #1
      STR       r3, activeplayers
      B         repollwimp                     ; CD_PlayTrack shouldn't return an error
                                               ; as the playlist only contains valid audio tracks

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_player_eject
;

event_player_eject
      LDR     r0, CurrentVolumeDrive
      BL      MakeCDFSblockinR7
      SWI     XCD_OpenDrawer                   ; returns an error if the drawer was locked,someone will report this later
      B       repollwimp

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_player_pause
;

event_player_pause
      LDR       r0, CurrentVolumeDrive
      BL        MakeCDFSblockinR7
      SWI       XCD_AudioStatus
      ASSERT    (playerstate_paused-playerstate_playing = 1) :LAND: (playerstate_playing = 0)
      CMP       r0, #2
      BCS       repollwimp                     ; only interested if it's playing or paused
      EOR       r0, r0, #1                     ; toggle the pause state (0=>playing 1=>paused)
      SWI       XCD_AudioPause 
      B         repollwimp

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_player_stop
;

event_player_stop
      LDR       r0, CurrentVolumeDrive
      ADRL      r1, playerstate_list
      LDR       r2, [r1, r0, LSL#2]
      ORR       r2, r2, #playerstate_halted
      STR       r2, [r1, r0, LSL#2]            ; stop it advancing by a track in 0.5s time
      BL        MakeCDFSblockinR7
      SWI       XCD_StopDisc                   ; not too worried if this fails
      CLRV                                     ; could be a forced stop
      B         repollwimp 

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_player_shuffle
;

event_player_shuffle
      LDR       r0, CurrentVolumeDrive
      ADRL      r5, player_playlists
      LDR       r1, [r5, r0, LSL#2]
      TEQ       r1, #0                         ; no playlist
      BEQ       repollwimp
      LDRB      r2, [r1, #0]
      TEQ       r2, #255                       ; playlist,but empty
      LDRNEB    r2, [r1, #1]
      TEQ       r2, #255                       ; only one entry,not worth shuffling
      BEQ       repollwimp                     

      ; here's how it all works
      ; make space on the stack for the new track listing,and do newtracklist[]=0
      ; find out how many *audio* tracks there are,subtract 1,becomes num_of_tracks
      ; i=0
      ;   pick up the track number in slot tracklist[i]
      ;   repeat
      ;     r=rand(num_of_tracks)
      ;   until newtracklist[r] = 0
      ;   newtracklist[r]=tracklist[i]
      ;   i++
      ; tracklist[]=newtracklist[]

      ; get num_of_tracks
      MOV       r4, #2                         ; already known to be at least 2 tracks
05
      LDRB      r0, [r1, r4]
      TEQ       r0, #255
      ADDNE     r4, r4, #1
      BNE       %BT05 
      SUB       r4, r4, #1

      ; newtracklist[]=0
      SUB       r13, r13, #100
      MOV       r6, #24
      MOV       r7, #0
10
      STR       r7, [r13, r6, LSL#2]
      SUBS      r6, r6, #1
      BPL       %BT10

      ; r4 = num_of_tracks
      ; r1 -> original track list
      ; r7 = i
      ; r3 -> new track list
      ; r6 = temp
      MOV       r3, r13
15
      BL        rand
      LDRB      r6, [r3, r0]
      TEQ       r6, #0
      BNE       %BT15
      ; found an empty destination
      LDRB      r6, [r1, r7]
      STRB      r6, [r3, r0]
      ADD       r7, r7, #1
      CMP       r7, r4
      BLS       %BT15

      MOV       r6, #24
20
      LDR       r7, [r13, r6, LSL#2]
      STR       r7, [r1, r6, LSL#2]
      SUBS      r6, r6, #1
      BPL       %BT20

      ADD       r13, r13, #100
      MOV       r7, #255
      ADD       r4, r4, #1
      STRB      r7, [r1, r4]
      BL        updateplaylist
      CLRV
      B         repollwimp 

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; rand - lame randomiser
; 
; in  r1 -> track listing (used as some more seed)
;     r4 =  value not to exceed
; out r0 =  0 <= r0 <= entry r4
;
rand  ROUT
      Push      "r2-r3"
      ADD       r2, r1, #4
      SWI       XOS_ReadMonotonicTime
      MOV       r0, r0, LSL#6                  ; as we'll call this lots of times in succession 
05                                             ; move the rapidly changing part up a bit
      MOV       r3, #1
      SWI       XOS_CRC
      AND       r3, r0, #127                   ; increase the likelyhood of a match
      CMP       r3, r4
      MOVHI     r3, r0, LSR#8                  ; have another go with the other 8 bits
      ANDHI     r3, r3, #127
      CMPHI     r3, r4
      BHI       %BT05
      MOV       r0, r3
      Pull      "r2-r3"
      MOV       pc, lr

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_redraw_volume
; =========================
;
; In
;       void
; Out
;       void
;
; This draws the volume bar
;

event_redraw_volume


      LDR       r0, CurrentVolumeDrive
      BL        get_volume_level
      MOVVS     r0, # 0
      MOV       r2, r0

      ADRL      r1, userdata
      LDR       r0, volumewin_handle
      STR       r0, [ r1 ]
      SWI       XWimp_RedrawWindow           ; r1 -> buffer and window handle
      TEQ       r0, # 0
      BEQ       repollwimp                   ; nothing to redraw (so why call me ?)
      BVS       repollwimp

; r1-> redraw block
; r2 = current volume level

ERV_Loop

; Get icon information
      Push      "r1"
      ADRL      r3, userdata + 128
      LDR       r0, volumewin_handle
      MOV       r14, # VOLUME__DRAW_BAR
      STMIA     r3, { r0, r14 }
      MOV       r1, r3
      SWI       XWimp_GetIconState
      BVS       ERV_ErrorInLoop
      Pull      "r1"


; Find x
;x = (( icon.box.x1 - icon.box.x0 ) * settings[ a ] ) / 100 + icon.box.x0 ;

; r1-> redraw block
; r2 = current volume level
; r3 -> icon info
; r4 = x

      LDR       r4, [ r3, # 8 + 8 ]      ; max icon x
      LDR       r5, [ r3, # 8 + 0 ]      ; min icon x
      SUB       r4, r4, r5               ; = icon width
      MUL       r4, r2, r4
      MOV       r4, r4, LSR # 16
      ADD       r4, r4, r5

; draw_bar
;#define draw_bar( x0, y0, x1, y1 )
; os_swi3( XOS_Plot, 68, x0 + 1, y0 + 1 ) ;
; os_swi3( XOS_Plot, 0x65, x1, y1 - 2);

      Push      "r1-r6"

; move
      LDR       r5, [ r1, # 20 ]         ; window scroll x
      LDR       r14, [ r1, # 4 ]         ; window min x
      SUB       r5, r14, r5

; r5 = (r.box.x0-r.scx)

      LDR       r0, [ r1, # 16 ]         ; window max. y
      LDR       r7, [ r1, # 24 ]         ; window scroll y
      SUB       r6, r0, r7

; r6 = (r.box.y1-r.scy)


; move to bottom right

      LDR       r1, [ r3, # 8 + 8 ]      ; max. x
      ADD       r1, r1, r5
      SUB       r1, r1, # 1

      LDR       r2, [ r3, # 8 + 4 ]      ; min. y
      ADD       r2, r2, r6

      MOV       r0, # 68
      SWI       XOS_Plot

; plot white rectangle to top of slider

      MOV       r0, #0
      SWI       XWimp_SetColour

      ADD       r1, r4, r5

      LDR       r2, [ r3, # 8 + 12 ]     ; max. y
      ADD       r2, r2, r6
      SUB       r2, r2, # 1

      MOV       r0, # &65
      SWI       XOS_Plot

; plot grey rectangle to bottom of slider, unless slider is 0 length

      MOV       r0, # BC__CENTRE
      SWI       XWimp_SetColour

      LDR       r1, [ r3, # 8 + 0 ]      ; min. x
      TEQ       r1, r4
      ADDNE     r1, r1, r5

      LDRNE     r2, [ r3, # 8 + 4 ]      ; min. y
      ADDNE     r2, r2, r6

      MOVNE     r0, # &65
      SWINE     XOS_Plot


      Pull      "r1-r6"


ERV_ErrorInLoop
      SWI       XWimp_GetRectangle
      TEQ       r0, # 0
      BNE       ERV_Loop

      B         repollwimp



;--------------------------------------------------
get_volume_level
;
; In
;       r0 = CD-ROM drive number
; Out
;       r0 = volume level (0 to 0xffff)
;      if error then Vset r0->error block
;
; This deals with clicks on the volume bar
;
;--------------------------------------------------

      Push      "r1-r2, lr"
      BL        MakeCDFSblockinR7
      SUB       r1, r7, #64

      MOV       r0, # 0
      MOV       r2, # 0
      STMIA     r1, { r0, r2 }

      SWI       XCD_GetAudioParms
      Pull      "r1-r2, pc", VS

      LDMIA     r1, { r0, r2 }

; Take the highest channel
      CMP       r2, r0
      MOVGT     r0, r2

      CMP       r0, #0 ; CLRV
      Pull      "r1-r2, pc"


;--------------------------------------------------
set_volume_level
;
; In
;       r0 = CD-ROM drive number
;       r1 = volume level
; Out
;       void, all regs preserved
;
;
; This sets the volume level
;
;--------------------------------------------------

      Push      "r0-r7, r14"

      MOV       r6, r1

      SWI       XCDFS_ConvertDriveToDevice
      BVS       SVL_End

      MOV       r0, r1

; r1 = composite device id, or -1 if not found
      CMP       r0, #-1
      BEQ       SVL_End

; What is the volume ?
      ADRL      r7, userdata + 64
      AND       r2, r0, #2_00000111    ; device id

      AND       r3, r0, #2_00011000    ; card
      MOV       r3, r3, LSR #3

      AND       r4, r0, #2_11100000    ; LUN
      MOV       r4, r4, LSR #5

      MOV       r5, r0, LSL #16        ; drive type
      MOV       r5, r5, LSR #24

      STMIA     r7, { r2, r3, r4, r5 }


      SUB       r1, r7, #64

      MOV       r14, r6
      MOV       r0, # 0
      STMIA     r1, { r6, r14 }
      SWI       XCD_SetAudioParms

SVL_End
      CMP       r0, #0 ; CLRV
      Pull      "r0-r7, pc"

;--------------------------------------------------
; Poll a drive to see if something interesting happened
;--------------------------------------------------
; In:  R0 = playerstate for the drive in R2
;      R2 = drive number
;      R3-> playerstate_list
; Out: R1-R3 preserved
;      stacked R0 will be written back to the list
;      R4 trashed
;
player_service
        Push    "r0-r3,r5,lr"

        MOV     r4, r0
        MOV     r0, r2
        BL      MakeCDFSblockinR7

        SWI     XCD_DriveReady
        TEQ     r0, #0
        BEQ     %FT06

        ; the CD was removed,so panic
        ADRL    r5, player_playlists
        LDR     r0, [r5, r2, LSL#2]
        TEQ     r0, #0
        MOVNE   r5, #-1
        STRNE   r5, [r0]            ; clear the playlist if there is one

        ADRL    r5, playerstate_list
        LDR     r1, [r5, r2, LSL#2]
        ASSERT  playerstate_listposn = 8
        ASSERT  playerstate_track = 24
        ANDS    r0, r1, #&FF000000  
        BEQ     %FT07               ; already pending a rescan
        BIC     r1, r1, #&0000FF00  ; rewind to the playlist start
        BIC     r1, r1, #&FF000000  ; mark the CD as needing rescanning
        ORR     r1, r1, #playerstate_halted
        BL      updateplaylist
        STR     r1, [r13, #0]       ; and make that consistent too
        MOV     r0, #playerstate_notasked
        B       %FT07

06
        ; there is a disc in the drive,see if we're pending a rescan
        ASSERT  playerstate_track = 24
        ANDS    r0, r4, #&FF000000
        BNE     %FT07
        MOV     r1, r2
        BL      createplaylist
        BL      updateplaylist      ; force an update
        ADRL    r5, playerstate_list
        ORR     r4, r4, #&FF000000  ; mark the CD as scanned,but unplayed
        STR     r4, [r13, #0]       ; make sure it gets updated later
07
        ; see if anything exciting is happening
        SWI     XCD_AudioStatus
        TEQ     r0, #playerstate_playing
        BNE     %FT11               ; not playing so leave the time alone

        LDR     r1, CurrentVolumeDrive
        TEQ     r1, r2              ; only bother updating the displayed drive
        BNE     %FT11

        Push    "r0"
        ADRL    r1, userdata
        MOV     r0, #64             ; Find the current LBA
        SWI     XCD_ReadSubChannel
        BVS     %FT10
        MOV     r0, #0              ; LBA mode
        LDR     r1, [r1] 

        SWI     XCD_ConvertToMSF
        MOVVS   r1, #0              ; conversion failed
08
        MOV     r3, r1, LSR#8
        AND     r2, r3, #&FF
        ASSERT  playerstate_timer = 16
        MOV     r0, r4, LSR#16
        AND     r0, r0, #&FF
        TEQ     r0, r2
        BEQ     %FT10               ; seconds count didn't change so skip

        MOV     r0, r3, LSR#8       ; minutes
        ADRL    r1, userdata
        CMP     r0, #10
        MOV     r2, #'0'            ; doubles as a buffer length!
        STRCCB  r2, [r1], #1        ; pad with leading zero
        SWI     XOS_ConvertCardinal1

        MOV     r0, #':'
        STRB    r0, [r1], #1

        AND     r0, r3, #255
        STRB    r0, [r13,#6]
        CMP     r0, #10
        MOV     r2, #'0'
        STRCCB  r2, [r1], #1        ; pad with leading zero
        SWI     XOS_ConvertCardinal1

        LDR     r0, volumewin_handle
        MOV     r4, #VOLUME__TIMER
        ADRL    r1, userdata
        BL      change_icon_text

        BL      updateplaylist
        ASSERT  playerstate_track = 24
        STRB    r0, [r13, #7]       ; last seen track 
10      
        Pull    "r0"
11
        LDR     r1, [r13, #0]
        AND     r1, r1, #&F
        CMP     r1, r0
        BEQ     %FT15               ; drive status unchanged so leave buttons alone
        MOV     r5, r0              ; needed later

        ; the last play request finishing
        CMP     r5, #playerstate_complete
        LDR     r4, [r13, #8]       ; remind ourselves of the drive number
        LDREQ   r1, [r13, #0]
        TSTEQ   r1, #playerstate_halted
        BNE     %FT12

        ADRL    r2, player_playlists
        ADD     r2, r2, r4, LSL#2
        LDR     r3, [r2]            ; now we have the pointer to the list of tracks

        ASSERT  playerstate_listposn = 8
        AND     r1, r1, #&0000FF00
        MOV     r1, r1, LSR#8       ; current offset within the list
        ADD     r1, r1, #1          ; next
        LDRB    r0, [r3, r1]
        TEQ     r0, #255
        BEQ     %FT12               ; end of playlist,no action
        STRB    r1, [r13, #1]       ; stash the new playlist offset
        MOV     r1, #254
        SWI     XCD_PlayTrack
        MOV     r5, #playerstate_playing 

12
        LDR     r1, CurrentVolumeDrive
        TEQ     r1, r4
        BNE     %FT14               ; only update the buttons if this is the displayed drive

13
        ; the drive is paused
        CMP     r5, #playerstate_paused
        MOV     r4, #VOLUME__PAUSE
        LDR     r1, volumewin_handle
        ADREQL  r0, b_pausein
        ADRNEL  r0, b_pauseout
        BL      change_icon_sprite

        ; the drive is playing
        CMP     r5, #playerstate_playing
        MOV     r4, #VOLUME__PLAY
        ADREQL  r0, b_playin
        ADRNEL  r0, b_playout
        CMP     r5, #playerstate_paused
        ADREQL  r0, b_playin
        BL      change_icon_sprite

14
        LDRB    r4, [r13, #0]
        BIC     r4, r4, #&F
        ORR     r4, r5, r4
        STRB    r4, [r13, #0]       ; stash the new drive state

15
        CLRV
        Pull    "r0-r3,r5,pc"

;--------------------------------------------------
; Different way of opening filer directory
;--------------------------------------------------

      [ Module_Version >= 201
FilerOpenDirCommand     DCB     "%Filer_OpenDir ",0
      ]

; ..........................................................................
; We get here if the user has double-clicked on a FS icon

; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

;
      [ Module_Version >= 213
photo_disc_sprite = "Spcddisc", 0
audio_disc_sprite = "Sacddisc", 0
      ]
       ALIGN

click_select_iconbar ROUT

        Debug   click, "click_select_iconbar"

        BL      matchdriveicon          ; r1 -> drive spec, eg. :4

        DebugS  click, "drive spec = ", r1

;--------------------------
; Make into the normal icon
;--------------------------
; r4 = icon number on icon bar
      [ Module_Version >= 213
        ADRL    r0, iconspritename
        MOV     r2, r1
        MOV     r1, #-2
        BL      change_icon_sprite
        MOV     r1, r2

;-------------------------------
; Try to get the disc name
;-------------------------------

        SWI     XHourglass_On

        BL      GetMediaName            ; r1 -> media name

      [ debugclick
        ADDVS   r0, r0, #4
        DebugSIf VS,click,"Error from GetMediaName: ",r0
        SUBVS   r0, r0, #4
      ]

        BVC     open_dir

        Debug   click, "GetMediaName returned error"

;---------------------------------------------------------------------------------------------
;
; on entry:
;           r0 -> error block
; on exit:
;
;---------------------------------------------------------------------------------------------

 [ {TRUE}
; Not good enough just to remember the pointer as MessageTrans reuses its error
; buffers and we could get a completely different error. We must copy the error
; into our workspace.
        Push    "r1"
        ADR     r1, dirnamebuffer       ; Use as temporary error buffer
        LDR     r14, [r0], #4
        STR     r14, [r1], #4
10
        LDRB    r14, [r0], #1
        STRB    r14, [r1], #1
        TEQ     r14, #0
        BNE     %BT10
        Pull    "r1"
 |
; Remember the error pointer
        Push    "r0"
 ]

;-------------------------------
; Is the CD in the drive audio ?
;-------------------------------

        Push    "r1"

; What is the drive number ?
        LDR     r1, matchedindex
        SWI     XCDFS_GetNumberOfDrives

; Could have 0 drives configured !
        TEQ     r0, #0
        SUBNE   r0, r0, r1
        SUBNE   r0, r0, #1

        SWI     XCDFS_ConvertDriveToDevice
        MOVVC   r0, r1
        Pull    "r1"
        BVS     not_audio

; r1 = composite device id, or -1 if not found
        CMP     r0, #-1
        BEQ     not_audio

; Is track 0 audio ?
        Push    "r1-r7"

        ADRL    r7, userdata + 64
        AND     r2, r0, #2_00000111    ; device id

        AND     r3, r0, #2_00011000    ; card
        MOV     r3, r3, LSR #3

        AND     r4, r0, #2_11100000    ; LUN
        MOV     r4, r4, LSR #5

        MOV     r5, r0, LSL #16        ; drive type
        MOV     r5, r5, LSR #24

        STMIA   r7, { r2, r3, r4, r5 }

        MOV     r0, #1

        SUB     r1, r7, #64

        SWI     XCD_EnquireTrack

        Pull    "r1-r7"

        BVS     not_audio

        LDRB    r0, userdata + 4
        TST     r0, #1
        BNE     not_audio

        addr    r0, audio_disc_sprite ; if zero then audio
        MOV     r1, #-2
        BL      change_icon_sprite

; Play from track 1 to the end of the disc
        MOV     r0, #1
        MOV     r1, #&ff
        ADRL    r7, userdata + 64
        SWI     XCD_PlayTrack

        SWI     XHourglass_Off

        CMP     r0, #0 ; CLRV

 [ {FALSE}
        ; No longer store the error on the stack.
        Pull    "r0"
 ]

        EXIT


not_audio ; - so must be an error

        SWI     XHourglass_Off

 [ {TRUE}
        ; Error is now copied to our workspace.
        ADR     r0, dirnamebuffer
 |
        Pull    "r0"
 ]
        CMP     r0, #&80000000
        CMNVC   r0, #&80000000 ; SETV
        EXIT

       | ; old boring way
        BLVC    GetMediaName            ; r1 -> media name
        EXIT    VS

      ]


 [ Module_Version >= 213

; This is the pathame that indicates that it is a photocd
photocd_filename = ".$.PHOTO_CD.INFO/PCD", 0

  [ ReadCDIDiscs
CDI_filename     = ".$.MPEGAV", 0
  ]
  ALIGN

open_dir

  [ ReadCDIDiscs

;-------------------------------
; Is the CD in the drive CD-I ?
;-------------------------------

; At this point the hourglass has already been turned on once

; r1 -> 'CDFS::FRED
        Push    "r1-r5"

        MOV     r2, r1                 ; 'CDFS::FRED'
        ADRL    r1, userdata
        BL      strcpy_advance

        ADRL    r2, CDI_filename       ; 'CDFS::FRED.$.MPEGAV'
        BL      strcpy_advance

        MOV     r0, # 5                ; see PRM p850
        ADRL    r1, userdata
        SWI     XOS_File

        Pull    "r1-r5"

; Was the object a directory (or even an error) ?
        TEQ     r0, # 2
        BNE     DiscCheck_NotCDI

        ADR     r0, cdi_disc_sprite
        MOV     r2, r1
        MOV     r1, #-2
        BL      change_icon_sprite
        MOV     r1, r2

        SWI     XHourglass_Off

;-------------------------
; Display the file viewer
;-------------------------
        B       OpenDirectoryViewer

cdi_disc_sprite   = "Scdidisc", 0
 ALIGN

DiscCheck_NotCDI

  ]

;-------------------------------------
; Is this a photo cd ?
;-------------------------------------

; At this point the hourglass has been turned on once

; r1 -> 'CDFS::FRED
        Push    "r1"

        MOV     r2, r1                 ; 'CDFS::FRED'
        ADRL    r1, userdata
        BL      strcpy_advance

        ADRL    r2, photocd_filename   ; 'CDFS::FRED.$.PHOTO_CD.INFO/PCD'
        BL      strcpy_advance

        MOV     r0, #&40 + 2_0111   ; see PRM p881
        ADRL    r1, userdata
        SWI     XOS_Find

; not photoCD
        BVS     DiscCheck_NotPhotoCD

        TEQ     r0, #0
        BEQ     DiscCheck_NotPhotoCD


; Is PhotoCD - so close the file
        MOV     r1, r0
        MOV     r0, #0
        SWI     XOS_Find

; Display the photocd icon
        ADRL    r0, photo_disc_sprite
        MOV     r1, #-2
        BL      change_icon_sprite


DiscCheck_NotPhotoCD

        SWI     XHourglass_Off

        Pull    "r1"
 ]

;-------------------------------------
; Try to open dir using Filer
;-------------------------------------

; on entry: r1 -> CDFS::FRED

OpenDirectoryViewer

      [ Module_Version > 201
        Push    "r1"
        ADRL    r1,userdata
        ADRL    r2,FilerOpenDirCommand
        BL      strcpy_advance
        Pull    "r2"
        BL      strcpy_advance
        ADR     r2, dotdollar
        BL      strcpy_advance
        ADRL    r0, userdata
        SWI     XOS_CLI
      |
        LDR     r0, =Message_FilerOpenDir
        BL      messagetoFiler
      ]

;-------------------------------------

        EXIT

;-----------------------------------------------------------------------------------------------
; change_icon_sprite
;
; on entry:
;          r0 -> sprite name
;          r1 = window handle
;          r4 = icon number
;          'matchedindex' = drive number
; on exit:
;          r0 corrupted
;
;    This changes the sprite for one pointed to in r0.
;
;-----------------------------------------------------------------------------------------------

      [ Module_Version >= 213
change_icon_sprite ROUT
        
        Push    "r0-r4, r14"

        MOV     r2, r0

; Find out where the text should be written to
        Push    "r0, r2, r3"
        MOV     r0, r1
        SUB     r1, sp, #4*12
        MOV     r2, r4
        MOV     r3, #0
        MOV     r4, #0
        STMIA   r1, { r0, r2, r3, r4 }
        SWI     XWimp_GetIconState

        ADD     r4, r1, #4+4
        LDR     r1, [ r1, #8 + 20 + 4 ]
        Pull    "r0, r2, r3"

; Write the Ssprite name
        BL      strcpy

; Update the icon
        LDR     r0, [r4, #-8]                 ; get back the window handle
        LDMIA   r4, { r1, r2, r3, r4 }
        
        SWI     XWimp_ForceRedraw

        Pull    "r0-r4, pc", AL


       ] ; only version 2.13 or greater

;-----------------------------------------------------------------------------------------------
; change_icon_text
;
; on entry:
;          r0 = window handle
;          r1 ->string to use
;          r4 = icon number
; on exit:
;          r0 corrupted
;
;    This changes the text in an icon
;
;-----------------------------------------------------------------------------------------------
change_icon_text

        Push    "r1,r3,lr"
        ADR     r1, userdata+&100
        STR     r0, [r1,#0]
        STR     r4, [r1,#4]
        SWI     XWimp_GetIconState
        Pull    "r1,r3,pc",VS

        ADR     r1,userdata+&100
        LDR     r14,[r1,#28]

        LDR     r1, [sp,#0]
11
        LDRB    r3, [r1], #1
        STRB    r3, [r14], #1
        CMP     r3, #32
        BGE     %BT11

        ADR     r1, userdata+&100
        MOV     r0, #0
        STR     r0, [r1, #8]
        STR     r0, [r1, #12]
        SWI     XWimp_SetIconState

        Pull    "r1,r3,pc"

;-----------------------------------------------------------------------------------------------
;
; In    r4 = drive number

messagetoPlayer
        SUB     sp, sp, #128            ; make temp frame for message
        LDR     r0, =Message_CDFSFilerOpenPlayer
        STR     r0, [sp, #message_action]
        STR     r4, [sp, #message_data] ; drive number
        MOV     r2, #0                  ; reserved flags
        STR     r2, [sp, #message_data + 4]
        STR     r2, [sp, #message_yourref]
        MOV     r0, #28
        STR     r0, [sp, #message_size]

        MOV     r0, #User_Message_Recorded
        MOV     r1, sp                   
        SWI     XWimp_SendMessage       ; broadcast it
        ADD     sp, sp, #128            ; free temp frame
        MOV     pc, lr

;-----------------------------------------------------------------------------------------------
;
; In    r0 = message action
;       r1 -> media name

messagetoFiler Entry

        SUB     sp, sp, #256            ; make temp frame for message
        STR     r0, [sp, #message_action]
        MOV     r2, r1
        ADD     r1, sp, #message_data
        MOV     r14, #37                ; FileSystem = CDFS
        STR     r14, [r1], #4
        MOV     r14, #0                 ; bitset = 0
        STR     r14, [r1], #4
        BL      strcpy_advance
        ADR     r2, dotdollar
        BL      strcpy_advance
        ADD     r1, r1, #1
        ADR     r2, dollar
        BL      strcpy_advance
        ADD     r1, r1, #1
        TST     r1, #3                  ; word aligned end ?
        ADDNE   r1, r1, #3              ; round up to word size
        BICNE   r1, r1, #3
        SUB     r1, r1, sp
        STR     r1, [sp, #message_size]
        MOV     r0, #User_Message_Recorded
        MOV     r1, sp
        LDR     r2, FilerHandle         ; send it to the Filer
        SWI     XWimp_SendMessage
        ADD     sp, sp, #256            ; free temp frame
        EXIT


dotdollar       DCB     "."             ; share $ with ...
dollar          DCB     "$", 0          ; directory title
                ALIGN


; Offsets of fields in a message block

                ^       0
message_size    #       4
message_task    #       4               ; thandle of sender - filled by Wimp
message_myref   #       4               ; filled in by Wimp
message_yourref #       4               ; filled in by Wimp
message_action  #       4
message_hdrsize *       @
message_data    #       0               ; words of data to send

; ..........................................................................
; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_menu_iconbar ROUT

        Debug   menus,"click_menu_iconbar"

        BL      matchdriveicon          ; r1 -> drive number (eg. :0)
        EXIT    VS
        STR     r1, menudrive

 [ :LNOT: UseConfigureToConfigure

     ;put the drive's number into its buffer
        SWI     XCDFS_GetNumberOfDrives
        ADRL    r1, mb_drives
        MOV     r2, #4
        SWI     OS_ConvertCardinal1

     ;tick appropriate buffers item and clear all the others
        ADRL    r1, m_buffers + m_headersize

        SWI     XCDFS_GetBufferSize
        MOV     r2, #0

01      LDRB    r14, [r1]
        CMP     r2, r0
        ORREQ   r14, r14, #1
        ANDNE   r14, r14, #254
        STRB    r14, [r1]
        ADD     r1, r1, #24
        ADD     r2, r2, #1
        CMP     r2, #8
        BNE     %BT01
 ]
        MOV     r0, #ModHandReason_LookupName    ; call OS_Module 18 to check if ShareD
        ADR     r1, Sharemodule                  ; module has been loaded; if not, then
        SWI     XOS_Module                       ; shade share entry in the ADFS menu
        LDRVS   r14, m_cdromdisc+m_headersize+mi_size*mo_cd_sharedisc+mi_iconflags
        ORRVS   r14, r14, #is_shaded
        STRVS   r14, m_cdromdisc+m_headersize+mi_size*mo_cd_sharedisc+mi_iconflags

        ; see if someone's locked this drive (hence you can't eject it)
        LDR     r1, menudrive
        ADD     r1, r1, #drv_number + 1 ; skip the ':'
        MOV     r0, #10
        SWI     XOS_ReadUnsigned
        MOV     r0, r2
        BL      MakeCDFSblockinR7
        SWIVC   XCD_IsDrawerLocked
        MOVS    r0, r0
        LDR     r14, m_cdromdisc+m_headersize+mi_size*mo_cd_eject+mi_iconflags
        ORRNE   r14, r14, #is_shaded
        BICEQ   r14, r14, #is_shaded
        STR     r14, m_cdromdisc+m_headersize+mi_size*mo_cd_eject+mi_iconflags

        ADRL    r1, m_cdromdisc
        BL      CreateMenu
        EXIT

Sharemodule     DCB     "ShareFS"                ; module for sparrow share module
                DCB     0
                ALIGN

; Entry:  R4 = icon handle (in icon bar)
; Exit:   R1 --> drive spec for this drive

matchdriveicon  Entry "r2"

        Debug   menus,"matchdriveicon"

        MOV     r2, #ndrives
        ADR     r1, iconbaricons
01
        LDR     r14, [r1], #4
        TEQ     r14, r4
        RSBEQ   r2, r2, #ndrives
        STREQ   r2, matchedindex            ; needed for namedisc
        ASSERT  drv_number = 0
        ADREQ   r1, discnames + drv_number
        ADDEQ   r1, r1, r2, LSL #drv_shift
        LDREQB  r14, [r1, #drv_number+1]    ; initialise drive # (for menu)
        STREQB  r14, driveno+1
        LDREQB  r14, [r1, #drv_number+2]    ; second digit (if any)
        STREQB  r14, driveno+2

        [ Module_Version > 201
        MOVEQ   r14, #0
        STREQB  r14, driveno + 3
        ]

        EXIT    EQ                          ; r1 -> drive spec
        SUBS    r2, r2, #1
        BNE     %BT01

;---------------------------------------
; Lookup error tag in Messages file
;---------------------------------------

        [ Module_Version > 201
        ADR     r0, err_noicon
        BL      lookuperror
        |
        ADR     r0, err_noicon              ; OLD way of erroring
        CMP     r0, #&80000000
        CMNVC   r0, #&80000000 ; SETV
        ]

        EXIT

;---------------------------------------
; Lookup error tag in Messages file
;---------------------------------------

 [ Module_Version > 201

err_noicon
        DCD     0
        DCB     "UI",0
        ALIGN

 |

err_noicon
        DCD     0
        DCB     "Unknown iconbar icon",0
        ALIGN
 ]

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; A menu is created with the title above the x,y values you feed it, with
; the top left hand corner being at the x,y position

CreateMenu Entry "r2, r3"

        STR     r1, menuhandle
        LDR     r2, mousex
        SUB     r2, r2, #4*16
        MOV     r3, #96 + ROOT_MENU_ITEMS*44        ; FIXME MENU (96 + n*44) to clear icon bar
        SWI     XWimp_CreateMenu
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

;----------------------------------------------------------------
; This is the new way to build menus up from the 'messages' file
;----------------------------------------------------------------

rom_menustart ; Note - must be defined bottom up

; icon bar menu for CDFS discs

m_cdromdisc     Menu     "T00"
mo_cd_dismount  Item     "M00"
mo_cd_eject     Item     "M04"
 [ :LNOT: UseConfigureToConfigure
mo_cd_configure Item     "M01",m_configure
 ]
mo_cd_sharedisc Item     "M02",m_sharedisc     ; ,X
mo_cd_volume    Item     "M03"
mo_cd_free      Item     "M05"

 [ :LNOT: UseConfigureToConfigure
m_configure     Menu     "T01"
mo_cf_buffers   Item     "M10",m_buffers
mo_cf_drives    Item     "M11",m_drives        ; ,X
 ]

m_sharedisc     Menu     "T02"
mo_cf_nshare    Item     "M20"
mo_cf_shared    Item     "M21"
 [ :LNOT: UseConfigureToConfigure
m_buffers       Menu     "T03"
mo_bf_1         Item     "M30"
mo_bf_2         Item     "M31"
mo_bf_3         Item     "M32"
mo_bf_4         Item     "M33"
mo_bf_5         Item     "M34"
mo_bf_6         Item     "M35"
mo_bf_7         Item     "M36"
mo_bf_8         Item     "M37"

m_drives        Menu     "T04"
mo_dr_drives    Item     "BNK",,W       ; mb_drives,3,2,,X,mv_configure
 ]
                DCB      0         ; terminator

rom_menuend

mv_configure    DCB     "A1234567890", 0    ; allow numbers only
                ALIGN                       ; must come AFTER menus


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CopyMenus
; =========

; Copy menu structures into ram, relocating as we go

;--------------------------------------------------------------
; New way of making international menus - RISC OS 3 ONLY
;--------------------------------------------------------------

CopyMenus Entry "r1-r11"

        Debug   menus,"CopyMenus"

 [ :LNOT: UseConfigureToConfigure 
        ADRL    r1, mb_drives                 ; fill in writeable fields now
        ADR     r2, mv_configure
        MOV     r3, #3                        ; allow only 3 characters
        ADRL    r14, m_drives + m_headersize + 0*mi_size + mi_icondata
        STMIA   r14, {r1-r3}
 ]
        BL      allocatemessagedata             ; if not already done

        LDRVC   r0, messagedata
        ADRVC   r1, rom_menustart
        ADRVCL  r2, ram_menustart
        MOVVC   r3, #ram_menuend-ram_menustart
        SWIVC   XMessageTrans_MakeMenus
        EXIT    ; return current V bit

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_menu_select
; =================

; In    r1 -> wimp_eventstr

; Out   all regs may be corrupted - going back to PollWimp

event_menu_select Entry

        MOV     r2, r1                  ; r2 -> menu selection list
        LDR     r1, menuhandle          ; r1 = menu handle
        BL      DecodeMenu

        ADRVCL  r1, userdata            ; check for right-hand button
        SWIVC   XWimp_GetPointerInfo
        EXIT    VS

        LDR     R14, userdata+8         ; get button state
        TST     R14, #&01
        LDRNE   R1, menuhandle
        LDRNE   R2, mousex
        SUBNE   R2, R2, #4*16
        MOVNE   R3, #96 + ROOT_MENU_ITEMS*44
        SWINE   XWimp_CreateMenu        ; here we go again!

        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In     r1 = menu handle
;        r2 -> list of selections

DecodeMenu Entry

decodelp
        LDR     r14, [r2], #4            ; r1 = selection no
        ADD     pc, pc, r14, LSL #2
        EXIT

        B       go_cd_dismount
        B       go_cd_eject
      [ :LNOT: UseConfigureToConfigure
        B       go_cd_configure
      ]
        B       go_cd_share
        B       go_cd_volume
        B       go_cd_free

go_cd_free
        ADRL    r1, userdata
        ADR     r2, freespace
        BL      strcpy
        ADD     r1, r1, #:LEN:"Showfree -FS CDFS "
        LDR     r2, menudrive
        ADD     r2, r2, #drv_number+1    ; skip the colon
        LDRB    r0, [r2], #1
        STRB    r0, [r1], #1
        LDRB    r0, [r2]
        STRB    r0, [r1]
        ADRL    r0, userdata

        SWI     XOS_CLI

        EXIT

go_cd_volume

; Set up interactive help
        LDR     r1, menudrive
        STR     r1, volumewindrive

; What is the drive number ?
        LDR     r1, matchedindex
        SWI     XCDFS_GetNumberOfDrives
        BVS     GCV_Error

; Could have 0 drives configured !
        TEQ     r0, #0
        SUBNE   r0, r0, r1
        SUBNE   r0, r0, #1
        MOV     r4, r0

; r4 = drive number

; Make sure that there is a drive there
        SWI     XCDFS_ConvertDriveToDevice
        BVS     GCV_Error

        CMP     r1, # -1
        ADREQL  r0, EH__Driver_NoDrive
        BEQ     GCV_LookupError

; Shout a message to anyone who might want to override the built in player

        BL      messagetoPlayer
        MOV     r0, #2
        STR     r0, msgbounces          ; when zero,give up and use the internal one
        EXIT

go_cd_volume_unclaimed

; The user message bounced
        LDR     r4, [r1, #message_data]
        LDR     r0, msgbounces
        SUBS    r0, r0, #1
        BEQ     go_cd_volume_internal        ; two strikes and you're out

        STR     r0, msgbounces

; Let's have a go at running the external player
        MOV     r5, r4
        ADR     r0, playervariable
        MOV     r2, #-1
        MOV     r3, #0
        MOV     r4, #3
        SWI     XOS_ReadVarVal
        TEQ     r2, #0
        MOV     r4, r5
        BEQ     go_cd_volume_internal       ; no player variable so skip straight to the internal one

        ADR     r0, playervariablerun
        SWI     XWimp_StartTask
        BL      messagetoPlayer             ; having run something,try messaging to it again
 
        CLRV
        EXIT

go_cd_volume_internal
        
; Remember the volume if need to cancel
        MOV     r0, r4
        BL      get_volume_level
        BVS     GCV_Error

        MOV     r5, r0

; Get the current window state
        LDR     r0, volumewin_handle
        ADRL    r1, userdata + 64
        STR     r0, [ r1 ]
        SWI     XWimp_GetWindowState
        BVS     GCV_Error

; Close the window first
        SWI     XWimp_CloseWindow

; Remember which drive it belongs to
        MOV     r0, r4
        STR     r0, CurrentVolumeDrive
        STR     r5, OldVolumeSetting

; Take a look at whether there's anything we can play on the disc
        Push    "lr"
        BL      MakeCDFSblockinR7
        Pull    "lr"
        BVS     GCV_Error

        LDR     r0, volumewin_handle
        ADRL    r1, userdata + 64
        STR     r0, [ r1 ]
        SWI     XWimp_GetWindowState
        BVS     GCV_Error

; Put the drive number into the title bar
        LDR     r3, volume_title_text
        LDR     r5, volume_title_length
        ADD     r3, r3, r5
        SUB     r3, r3, # 3

        LDRB    r5, driveno + 1
        STRB    r5, [ r3 ], # 1
        LDRB    r5, driveno + 2
        STRB    r5, [ r3 ], # 1
        MOV     r5, # 0
        STRB    r5, [ r3 ], # 1

; Make the window over the iconbar - y

        MOV     r4, r1
        ADRL    r1, userdata
        SWI     XWimp_GetPointerInfo

        LDR     r2, [ r4, # 4 + 12 ]        ; maximum y
        LDR     r3, [ r4, # 4 + 4 ]         ; minimum y
        SUB     r2, r2, r3
        ADD     r2, r2, #icon_bar_height+2  ; like display manager does
        STR     r2, [ r4, # 4 + 12 ]
        STR     r3, [ r4, # 4 + 4 ]

; x

        LDR     r2, [ r4, # 4 + 8 ]         ; maximum x
        LDR     r3, [ r4, # 4 + 0 ]         ; minimum x
        SUB     r2, r2, r3
        LDR     r3, [ r1, # 0 ]             ; mouse x
        SUBS    r3, r3, #64                 ; offset 64 like the style guide says
        MOVLT   r3, # 0
        ADD     r2, r2, r3
        STR     r2, [ r4, # 4 + 8 ]
        STR     r3, [ r4, # 4 + 0 ]

        MOV     r1, r4

; Open the window and push it to the front
        MOV     r14, # -1
        STR     r14, [ r1, # 28 ]
        SWI     XWimp_OpenWindow
        BVS     GCV_Error

        LDR     r0, activeplayers
        ADD     r0, r0, #1
        STR     r0, activeplayers

        LDR     r0, CurrentVolumeDrive
        ADRL    r1, playerstate_list
        LDR     r2, [r1, r0, LSL#2]
        ORR     r2, r2, #&F                 ; invalidate the status bits
        STR     r2, [r1, r0, LSL#2]

        ANDS    r14, r2, #&FF000000         ; see if the disc has ever been seen,or is pending rescan
        TEQNE   r14, #&FF000000
        MOVEQ   r1, r0
        BLEQ    createplaylist

        EXIT

playervariablerun
                DCB     "Run <CDFSFiler$$Player>",13
                ALIGN
playervariable  DCB     "CDFSFiler$$Player",0
                ALIGN

; r0->error block
GCV_LookupError
        BL      lookuperror
GCV_Error
        MOV     r1, #2_010              ; Cancel button
        BL      ReportError
        CMP     r0, #0 ;CLRV
        EXIT

go_cd_dismount
        ; need to deduce which iconbar icon we refer to
        LDR     r1, menudrive
        ADD     r1, r1, #drv_number + 1 ; skip the ':'
        MOV     r0, #10
        SWI     XOS_ReadUnsigned
        ADR     r4, iconbaricons
        LDR     r4, [r4, r2, LSL#2]
        ADRL    r0, iconspritename
        MOV     r1, #-2
        BL      change_icon_sprite      ; go back to the default icon

        ADRL    r1, driveno             ; re-read media name
        BL      GetMediaName_nochecks   ; r1 -> "CDFS::discname"
        BLVC    dismountit
        B       GoUnShare_CD

        EXIT

go_cd_eject
        LDR     r1, menudrive
        ADD     r1, r1, #drv_number + 1 ; skip the ':'
        MOV     r0, #10
        SWI     XOS_ReadUnsigned
        MOVVC   r0, r2
        BLVC    MakeCDFSblockinR7
        SWIVC   XCD_OpenDrawer          ; could return an error if the drawer was locked,someone will report this later
        EXIT

 [ :LNOT: UseConfigureToConfigure
go_cd_configure
        LDR     r14, [r2], #4           ;first submenu item
        ADD     pc, pc, r14, LSL #2
        EXIT

        B       go_cf_buffers
        B       go_cf_drives

go_cf_buffers
        LDR     r0, [r2]               ;second submenu item
        SWI     XCDFS_SetBufferSize

     ; tick appropriate buffers item and clear all the others
        ADRL    r1, m_buffers
        ADD     r1, r1, #m_headersize
        MOV     r2, #0

01      LDRB    r14, [r1]
        CMP     r2, r0
        ORREQ   r14, r14, #1
        ANDNE   r14, r14, #254
        STRB    r14, [r1]
        ADD     r1, r1, #24
        ADD     r2, r2, #1
        CMP     r2, #8
        BNE     %BT01
        EXIT

go_cf_drives
        MOV     r1, #1
        MOV     r0, r1, LSL #29
        ADD     r0, r0, #10
        ADRL    r1, mb_drives
        MOV     r2, #28
        SWI     XOS_ReadUnsigned
        BVS     %FT01
        MOV     r0, r2
        SWI     XCDFS_SetNumberOfDrives
        EXIT

01      MOV     r1, #2
        addr    r2, CDFSFiler_Banner
        SWI     Wimp_ReportError
        EXIT
 ]

go_cd_share
        LDR     r14, [r2], #4           ;first submenu item
        ADD     pc, pc, r14, LSL #2
        EXIT

        B       go_cf_nshare
        B       go_cf_shared

go_cf_nshare
        B       GoUnShare_CD
        EXIT

go_cf_shared
        B       open_sharewin
        EXIT

CDFScolon       DCB     "CDFS:",0
                ALIGN

dismount        DCB     "Dismount n ",0         ; NB space still needed
                ALIGN
                  
freespace       DCB     "Showfree -FS CDFS n ",0; NB space still needed
                ALIGN


;----------------------------------------

; In    r1 -> "CDFS::discname"
; Out   dismounted, and any dirs 'CDFS::discname' closed

dismountit Entry "r1"

        LDR     r0, =Message_FilerCloseDir
        BL      messagetoFiler

        [ Module_Version >= 212
        ; cause an event so that the filer closes it's windows before I *dismount
        MOV     r3, r0
        MOV     r0, #0
        ADRL    r1, userdata
        SWI     XWimp_Poll
        MOV     r0, r3
        ]

        ADR     r3, dismount
        BL      copycommand
        SUB     r1, r1, #2              ; r1 -> original drive number
        LDR     r2, [sp]                ; r2 -> "CDFS::discname"
        ADD     r2, r2, #:LEN:"CDFS::"  ; r2 -> discname
        BL      strcpy
        ADRL    r0, userdata
        SWI     XOS_CLI

        EXIT

; In    [driveno+1] = drive number
;       r3 -> prototype command
; Out   [userdata..] = "CDFS:<command> <drive no>"
;       r1 -> terminator (drive number inserted at [r1,#-2])

copycommand Entry
        ADRL    r1, userdata
        ADR     r2, CDFScolon
        BL      strcpy_advance
        MOV     r2, r3
        BL      strcpy_advance
        LDRB    r14, driveno+1          ; get drive number
        STRB    r14, [r1,#-2]
        EXIT


;----------------------------------------
;
;      Here we go with share code!
;
;----------------------------------------

        MACRO
$l      checkac     $path, $action
$l      ADR         r1, $path
        MOV         r0, $action
        SWI         XOS_File
        MEND

        MACRO
$l      createf     $path, $action
$l      MOV         r0, $action
        ADR         r1, $path
        SWI         XOS_Find
        MEND

open_sharewin
        LDR     r1, menudrive
        STR     r1, sharewindrive         ; set up interactive help

        MOV     r11, #0

        ADRL    r1, driveno               ; re-read media name
        BL      GetMediaName ;_nochecks   ; returns with r1 -> "CDFS::discname"
        ADD     r1, r1, #:LEN:"CDFS::"    ; r1 -> discname

        LDR     r0, sharewin_handle
        MOV     r4, #1
        BL      change_icon_text
        
        MOV     r7, #0                   ; Flag no file open

        checkac Accpath, #17
        CMP     r0, #2
        BNE     %FT05
        checkac  fname1, #17
        CMP     r0, #1                   ; r0 = 1 -> file exists
        BNE     %FT05
        createf fname1, #&C3
        MOV     r7, r0                   ; save file handle

        MOV     r4, #0                   ; initialize buffer to 0
        ADRL    r5, buffertemp
        STRB    r4, [r5]
        MOV     r9, r5
        MOV     r4, #&0A                 ; newline char
        MOV     r6, #" "                 ; space char
04
        MOV     r1, r7                   ; get first byte from sharecd file
        SWI     XOS_BGet
        BCS     %FT05

        ADRL    r1, driveno              ; read media name
        ADD     r1, r1, #1
        LDRB    r2, [r1]
        CMP     r0, r2                   ; is the drive?
        BNE     %FT06
02
        MOV     r1, r7
        SWI     XOS_BGet
        BCS     %FT05
        SWI     XOS_BGet
        BCS     %FT05
02
        SWI     XOS_BGet
        CMP     r0, r6
        BNE     %BT02
        STRB    r0, [r5, #-1]
01
        SWI     XOS_BGet
        CMP     r0, r4
        BEQ     %FT98
        STRB    r0, [r5], #1
        B       %BT01
98
        MOV     r3, #0
        STRB    r3, [r5]
        Push    "r1"                     ; insert in icon #1 the name of the disc
        ADR     r1, userdata+&100
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        MOV     r0, #2
        STR     r0, [r1,#4]
        SWI     XWimp_GetIconState
        ADDVS   sp, sp, #4
        BVS     %FT05
        ADR     r1,userdata+&100
        LDR     r14,[r1,#28]
        Pull    "r1"
11
        LDRB    r3, [r9], #1
        CMP     r3, #" "
        STRGEB  r3, [r14], #1
        ADD     r11, r11, #1
        BGE     %BT11

        ADR     r1, userdata+&100
        MOV     r0, #0
        STR     r0, [r1, #8]
        STR     r0, [r1, #12]
        SWI     XWimp_SetIconState
        B       %FT05
06
        MOV     r1, r7
        SWI     XOS_BGet
        BCS     %FT05
        CMP     r0, r4
        BNE     %BT06
        B       %BT04
05
        CMP     r11, #0
        BNE     %FT01

        ADRL    r1, driveno               ; re-read media name
        BL      GetMediaName ;_nochecks   ; returns with r1 -> "CDFS::discname"
        ADD     r1, r1, #:LEN:"CDFS::"    ; r1 -> discname

        MOV     r3, r1                  ; r3->string to copy.
        ADR     r1, userdata+&100
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        MOV     r0, #2
        STR     r0, [r1, #4]
        SWI     XWimp_GetIconState
        BVS     %FT01

        LDR     r4, [r1, #28]           ; r4->indirect data
        LDR     r14, [r1, #36]          ; r14 = length of indirect data

        ADD     r5, r4, #1              ; So we can work out string length for Wimp_SetCaretPosition.
11
        LDRB    r0, [r3], #1
        CMP     r0, #" "                ; If byte to copy is not terminator
        SUBGTS  r14, r14, #1            ;   then reduce count.
        MOVLE   r0, #0                  ; If byte to copy was terminator or count has reached 0 then terminate.
        STRB    r0, [r4], #1
        BGT     %BT11
        SUB     r5, r4, r5              ; r5 = string length for Wimp_SetCaretPosition

        ADR     r1, userdata+&100
        MOV     r0, #0
        STR     r0, [r1, #8]
        STR     r0, [r1, #12]
        SWI     XWimp_SetIconState
01
        ADR     r1, userdata            ; open share window
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        SWI     XWimp_GetWindowState
        MOVVC   r0,#-1
        STRVC   r0, [r1,#28]
        SWIVC   XWimp_OpenWindow

        LDRVC   r0, sharewin_handle     ; give it the caret
        MOVVC   r1, #2
        MOVVC   r4, #-1
        SWIVC   XWimp_SetCaretPosition

        MOVS    r1, r7                  ; close file ShareCD (if open)
        MOVNE   r0, #0
        SWINE   XOS_Find

        EXIT

GoUnShare_CD
        LDR     r14, m_cdromdisc+m_headersize+mi_size*mo_cd_sharedisc+0
        BIC     r14, r14, #mi_it_tick
        STR     r14, m_cdromdisc+m_headersize+mi_size*mo_cd_sharedisc+0

        ADR     r1, userdata+&100       ; get icon #2 indirect data (shared name)
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        MOV     r0, #2
        STR     r0, [r1,#4]
        SWI     XWimp_GetIconState
        LDR     r3, [r1, #28]           ; Indirected icon at +20 icon data
        MOV     r1, r3
        SWI     XShareD_StopShare       ; calls shared_stopshare

     ;   MOVVS   r1, #2_001              ; 'Ok' button
     ;   BLVS    ReportError             ; error if shared_createshare fails
     ;   BVS     ErrorAbort              ; error from reporterror!

        ADR     r1, userdata            ; close share window
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        SWI     XWimp_CloseWindow

        B       delete_entry

        EXIT


delete_entry                            ; delete the entry in sharecd file when the disc is unshared
        checkac Accpath, #17

        CMP     r0, #2
        BNE     %FT03

        checkac  fname1, #17
        CMP     r0, #1                  ; r0 = 1 -> file exists
        BNE     %FT03

        createf fname1, #&C3
        MOV     r7, r0                   ; save file handle

        createf tname1, #&83             ; create temporary file (temp)
        MOV     r8, r0                   ; save file handle

        MOV     r4, #&0A                 ; newline char
04
        MOV     r1, r7                   ; get first byte from sharecd file
        SWI     XOS_BGet
        BCS     %FT05

        ADRL    r1, driveno              ; read media name
        ADD     r1, r1, #1
        LDRB    r2, [r1]
        CMP     r0, r2                   ; is the drive?
        BNE     %FT01
02
        MOV     r1, r7
        SWI     XOS_BGet                 ; get the related string ad store in
        BCS     %FT05                    ; buffertemp
        CMP     r0, #&0A
        BNE     %BT02
        B       %BT04  ; 6 (FT)
01
        MOV     r1, r8
        SWI     XOS_BPut
06      MOV     r1, r7
        SWI     XOS_BGet
        BCS     %FT05
        CMP     r0, r4
        BNE     %BT01
        MOV     r1, r8
        SWI     XOS_BPut
        B       %BT04
05
        MOV     r0, #0                   ; close file
        MOV     r1, r7
        SWI     XOS_Find

        MOV     r0, #0                   ; close file
        MOV     r1, r8
        SWI     XOS_Find

        checkac fname1, #6               ; delete old sharecd file

        createf fname1, #&83             ; create new sharecd file (empty so far)
        MOV     r7, r0                   ; save file handle

        createf tname1, #&43             ; open temp file to read from
        MOV     r8, r0                   ; save file handle

07      MOV     r1, r8
        SWI     XOS_BGet
        BCS     %FT08
        MOV     r1, r7
        SWI     XOS_BPut
        B       %BT07
08
        MOV     r0, #0                   ; close file
        MOV     r1, r8
        SWI     XOS_Find

        checkac tname1, #6               ; delete temp file

        MOV     r0, #0                   ; close file
        MOV     r1, r7
        SWI     XOS_Find
03
        EXIT

check_access Entry
        checkac Accpath, #17
        CMP     r0, #2
        BLEQ    check_sharefile
        CMP     r0, #0 ; CLRV
        EXIT

check_sharefile Entry
        checkac fname1, #17
        CMP     r0, #1
        BLEQ    issue_shares
        EXIT

Dpath   DCB     "<AccessCD$$dir>"
        DCB     0
        ALIGN

Accpath DCB     "<AccessCDS$$dir>"
        DCB     0
        ALIGN

tname   DCB     "<AccessCD$$dir>.temp"
        DCB     0
        ALIGN

tname1  DCB     "<AccessCDS$$dir>.temp"
        DCB     0
        ALIGN

fname   DCB     "<AccessCD$$dir>.sharecd"
        DCB     0
        ALIGN

fname1  DCB     "<AccessCDS$$dir>.sharecd"
        DCB     0
        ALIGN

        LTORG

GoShare_disc
        Entry
        checkac Accpath, #17
        CMP     r0, #2
        BNE     %FT03
        checkac fname1, #17
        CMP     r0, #1                   ; r0 = 1 -> file exists
        BEQ     %FT66

        ; create sharecd file
        createf fname1, #&83
        MOV     r7, r0                   ; save file handle
        ADRL    r1, driveno              ; re-read media name
        ADD     r1, r1, #1
        MOV     r4, #0
        ADRL    r0, buffershare
        STRB    r4, [r0]
        MOV     r2, r1
        ADRL    r1, buffershare          ; buffershare -> drive number
        BL      strcat
        MOV     r2, #" "
        ADRL    r1, buffershare
        STRB    r2, [r1, #1]

        MOV     r2, #0
        ADRL    r1, buffershare
        STRB    r2, [r1, #2]

        ADRL    r1, driveno              ; re-read media name
        BL      GetMediaName ;_nochecks  ; returns with r1 -> "CDFS::discname"
        ADD     r1, r1, #:LEN:"CDFS::"   ; r1 -> discname

        MOV     r2, r1
        ADRL    r1, buffershare
        BL      strcat

        BL      strlen

        MOV     r3, #" "
        STRB    r3, [r1, r2]!

        MOV     r3, #0
        STRB    r3, [r1, #1]

        ADR     r1, userdata+&100
        LDR     r0, sharewin_handle      ; get icon #2 indirect data (shared name)
        STR     r0, [r1]
        MOV     r0, #2
        STR     r0, [r1,#4]
        SWI     XWimp_GetIconState
        LDR     r3, [r1, #28]            ; Indirected icon at +20 icon data

        MOV     r2, r3
        ADRL    r1, buffershare
        BL      strcat

        BL      strlen
        ADD     r2, r2, #1
        STR     r2, bufferlen            ; lenght of the string + return char (strlen + 1)

        MOV     r4, #&0A
        SUB     r2, r2, #1
        STRB    r4, [r1, r2]

        MOV     r0, #2
        MOV     r2, r1
        MOV     r1, r7
        LDR     r3, bufferlen
        SWI     XOS_GBPB

        MOVVS   r1, #2_001               ; 'Ok' button
        BLVS    ReportError
        BVS     ErrorAbort               ; error from reporterror!

        MOV     r0, #0                   ; close file
        MOV     r1, r7
        SWI     XOS_Find
        B       %FT03
66
        ; Update sharecd file
        createf fname1, #&C3
        MOV     r7, r0
        createf tname1, #&83
        MOV     r8, r0

        MOV     r4, #0                   ; initialize buffer to 0
        ADRL    r5, buffertemp
        STRB    r4, [r5]
        MOV     r4, #&0A                 ; newline char
04
        MOV     r1, r7                   ; get first byte from sharecd file
        SWI     XOS_BGet
        BCS     %FT05

        ADRL    r1, driveno              ; read media name
        ADD     r1, r1, #1
        LDRB    r2, [r1]
        CMP     r0, r2                   ; is the drive?
        BNE     %FT01
02
        MOV     r1, r7
        STRB    r0, [r5], #1             ; if the drive number is the same then
        SWI     XOS_BGet                 ; get the related string ad store in
        BCS     %FT05                    ; buffertemp
        CMP     r0, #&0A
        BNE     %BT02
        MOV     r0,#0
        STRB    r0,[r5]
        B       %BT04
01
        MOV     r1, r8
        SWI     XOS_BPut
06      MOV     r1, r7
        SWI     XOS_BGet
        BCS     %FT05
        CMP     r0, r4
        BNE     %BT01
        MOV     r1, r8
        SWI     XOS_BPut
        B       %BT04
05
        BL      unshare_previous

        MOV     r0, #0                   ; close file
        MOV     r1, r7
        SWI     XOS_Find

        MOV     r0, #0                   ; close file
        MOV     r1, r8
        SWI     XOS_Find

        checkac fname1, #6               ; delete old sharecd file
        createf fname1, #&83             ; create new sharecd file (empty so far)
        MOV     r7, r0                   ; save file handle
        createf tname1, #&43             ; open temp file to read from
        MOV     r8, r0                   ; save file handle
07
        MOV     r1, r8
        SWI     XOS_BGet
        BCS     %FT08
        MOV     r1, r7
        SWI     XOS_BPut
        B       %BT07
08
        MOV     r0, #0                   ; close file
        MOV     r1, r8
        SWI     XOS_Find

        checkac tname1, #6                ; delete temp file

        MOV     r0, #0                   ; close file
        MOV     r1, r7
        SWI     XOS_Find
03
        ADR     r1, userdata+&100       ; get icon #2 indirect data (shared name)
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        MOV     r0, #2
        STR     r0, [r1,#4]
        SWI     XWimp_GetIconState
        LDR     r3, [r1, #28]           ; Indirected icon at +20 icon data
        MOV     r1, r3                  ; r3 -> indirect_data of icon #2

        MOV     r7, #0                  ; check str lenght
05      LDRB    r14, [r1], #1
        CMP     r14, #&20
        ADDHS   r7, r7, #1              ; r7 -> str lenght
        BHS     %BT05

        ADRL    r1, driveno             ; read media name
        BL      GetMediaName ;_nochecks ; returns with r1 -> "CDFS::discname"
        ADD     r1, r1, #:LEN:"CDFS::"  ; r1 -> discname
        MOV     r5, r1

        MOV     r4, #0                  ; check str lenght
05      LDRB    r14, [r1], #1
        CMP     r14, #0
        ADDNE   r4, r4, #1              ; r4 -> str lenght
        BNE     %BT05

        CMP     r4, r7                  ; have the 2 string the same lenght?
        BNE     %FT99

        MOV     r1, r3                  ; they have the same lenght: now let's cmp them
        BL      strcmp
        CMP     r2, #0                  ; r2 <> 0 -> strings are different
        BNE     %FT99

        ADR     r1, userdata+&100       ; get icon #1 indirect data (shared name)
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        MOV     r0, #1
        STR     r0, [r1,#4]
        SWI     XWimp_GetIconState
        LDR     r3, [r1, #28]           ; Indirected icon at +20 icon data

        ADRL    r1, driveno             ; read media name
        BL      GetMediaName ;_nochecks ; returns with r1 -> "CDFS::discname"
        MOV     r8, r1
        SUB     r1, r1, #0              ; r1 -> original drive number
        ADD     r1, r1, #:LEN:"CDFS::"  ; r1 -> discname
02
        LDRB    r6, [r1], #1
        TEQ     r6, #0
        BNE     %BT02
        SUB     r1, r1, #1
        ADR     r2, dotdollar1
        BL      strcpy_advance

        MOV     r0, #16                 ; r0 -> 16 (bit 4 set to 1 -> -CDROM option set)
        MOV     r2, r8
        MOV     r1, r3
        SWI     XShareD_CreateShare     ; calls shared_createshare
        B       %FT98
99
        ADR     r1, userdata+&100            ; get icon #2 indirect data (shared name)
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        MOV     r0, #2
        STR     r0, [r1,#4]
        SWI     XWimp_GetIconState
        LDR     r3, [r1, #28]           ; Indirected icon at +20 icon data

        ADRL    r1, driveno             ; read media name
        BL      GetMediaName ;_nochecks   ; returns with r1 -> "CDFS::discname"
        MOV     r8, r1
        SUB     r1, r1, #0              ; r1 -> original drive number
        ADD     r1, r1, #:LEN:"CDFS::"  ; r1 -> discname
02
        LDRB    r6, [r1], #1
        TEQ     r6, #0
        BNE     %BT02

        ADR     r2, dotdollar1
        BL      strcpy_advance

        MOV     r0, #16                 ; r0 -> 16 (bit 4 set to 1 -> -CDROM option set)
        MOV     r2, r8
        MOV     r1, r3
        SWI     XShareD_CreateShare     ; calls shared_createshare
98
     ;  tick share entry
        LDR     r14, m_cdromdisc+m_headersize+mi_size*mo_cd_sharedisc+0
        ORR     r14,r14,#mi_it_tick
        STR     r14, m_cdromdisc+m_headersize+mi_size*mo_cd_sharedisc+0

        ADR     r1, userdata            ; close share window
        LDR     r0, sharewin_handle
        STR     r0, [r1]
        SWI     XWimp_CloseWindow

        EXIT

issue_shares Entry "r0-r12"
        createf fname1, #&43
        MOV     r7, r0
        MOV     r4, #&0A
        MOV     r6, #" "
        MOV     r3, #0
        ADRL    r5, buffershare
        STRB    r3, [r5]
        ADRL    r8, buffertemp
        STRB    r3, [r8]
99
        MOV     r1, r7
        SWI     XOS_BGet
        BCS     %FT05
        SWI     XOS_BGet
        BCS     %FT05
02
        SWI     XOS_BGet
        STRB    r0, [r5], #1
        CMP     r0, r6
        BNE     %BT02
        STRB    r3, [r5, #-1]
01
        SWI     XOS_BGet
        CMP     r0, r4
        BEQ     %FT98
        STRB    r0, [r8], #1
        B       %BT01
98
        STRB    r3, [r8]
        ADRL    r2, drivecd
        ADRL    r4, buffertemp2
        STRB    r3, [r4]
        MOV     r1, r4
03
        LDRB    r6, [r2], #1
        STRB    r6, [r4], #1
        CMP     r6, r3
        BNE     %BT03

        ADRL    r2, buffershare
        BL      strcat
        MOV     r3, r1
02
        LDRB    r6, [r1], #1
        TEQ     r6, #0
        BNE     %BT02

        SUB     r1, r1, #1
        ADR     r2, dotdollar1
        BL      strcpy_advance
        MOV     r2, r3
        ADRL    r1, buffertemp

        MOV     r0, #16                 ; r0 -> 16 (bit 4 set to 1 -> -CDROM option set)
        SWI     XShareD_CreateShare       ; calls shared_createshare

        MOVVS   r1, #2_001              ; 'Ok' button
        BLVS    ReportError             ; error if shared_createshare fails
        BVS     ErrorAbort              ; error from reporterror!

     ;  tick share entry
        LDR     r14, m_cdromdisc+m_headersize+mi_size*mo_cd_sharedisc+0
        ORR     r14,r14,#mi_it_tick
        STR     r14, m_cdromdisc+m_headersize+mi_size*mo_cd_sharedisc+0

        B       %BT99
05
        MOV     r0, #0                   ; close file
        MOV     r1, r7
        SWI     XOS_Find

        EXIT

dotdollar1      DCB     "."             ; share $ with ...
dollar1         DCB     "$", 0          ; directory title
                ALIGN

drivecd         DCB     "CDFS::"
                DCB     0
                ALIGN

unshare_previous  Entry "r0-r12"
        MOV     r6, #" "
        MOV     r3, #0                  ; initialize buffer to 0
        ADRL    r9, m_tempdisc
        STRB    r3, [r9]
        MOV     r11, #0
01
        LDRB    r10, [r5,#-1]!
        CMP     r10, r6
        ADDNE   r11, r11, #1
        BEQ     %FT02
        STRB    r10, [r9], #1
        B       %BT01
02
        MOV     r3, #0                  ; initialize buffer to 0
        ADRL    r4, m_tempdisc2
        STRB    r3, [r4]
        MOV     r6, r4
        MOV     r3, r11
04
        LDRB    r10, [r9,#-1]!
        CMP     r3, #0
        BEQ     %FT03
        STRB    r10, [r4], #1
        SUB     r3, r3, #1
        B       %BT04
03
        MOV     r0, #0
        MOV     r1, r6
        SWI     XShareD_StopShare        ; calls shared_createshare

;        MOVVS   r1, #2_001              ; 'Ok' button
;        BLVS    ReportError             ; error if shared_createshare fails
;        BVS     ErrorAbort              ; error from reporterror!
01
        MOV     r0, #0
        STRB    r0, [r4]

        ADRL    r1, driveno              ; re-read media name
        ADD     r1, r1, #1
        MOV     r4, #0
        ADRL    r0, buffertemp2
        STRB    r4, [r0]
        MOV     r2, r1
        ADRL    r1, buffertemp2          ; buffertemp2 -> drive number
        BL      strcat

        MOV     r2, #" "
        ADRL    r1, buffertemp2
        STRB    r2, [r1, #1]

        MOV     r2, #0
        ADRL    r1, buffertemp2
        STRB    r2, [r1, #2]

        ADRL    r1, driveno             ; re-read media name
        BL      GetMediaName ;_nochecks   ; returns with r1 -> "CDFS::discname"
        ADD     r1, r1, #:LEN:"CDFS::"  ; r1 -> discname

        MOV     r2, r1
        ADRL    r1, buffertemp2
        BL      strcat

        BL      strlen

        MOV     r3, #" "
        STRB    r3, [r1, r2]!

        MOV     r3, #0
        STRB    r3, [r1, #1]

        ADR     r1, userdata+&100
        LDR     r0, sharewin_handle     ; get icon #2 indirect data (shared name)
        STR     r0, [r1]
        MOV     r0, #2
        STR     r0, [r1,#4]
        SWI     XWimp_GetIconState
        LDR     r3, [r1, #28]           ; Indirected icon at +20 icon data

        MOV     r2, r3
        ADRL    r1, buffertemp2
        BL      strcat

        BL      strlen
        ADD     r2, r2, #1
        STR     r2, bufferlen2           ; lenght of the string + return char (strlen + 1)

        MOV     r4, #&0A
        SUB     r2, r2, #1
        STRB    r4, [r1, r2]
        ADD     r2, r2, #1
        MOV     r4, #0
        STRB    r4, [r1, r2]

        MOV     r0, #2
        MOV     r2, r1
        MOV     r1, r8
        LDR     r3, bufferlen2
        SWI     XOS_GBPB

        MOVVS   r1, #2_001              ; 'Ok' button
        BLVS    ReportError
        BVS     ErrorAbort              ; error from reporterror!

        EXIT

strcmp  Entry
01      LDRB    r10, [r1], #1
        LDRB    r14, [r5], #1
        CMP     r10, #0
        BNE     %FT02
        CMP     r14, #0
        MOVEQ   r2, #0
        BEQ     %FT99
02
        CMP     r14, r10
        BEQ     %BT01
        MOV     r2, #1
99
        EXIT


; A couple of procedure to tick and check sharedisc submenu
; In    r1 -> menu

EncodeMenu Entry "r0, r1"

        ADD     r1, r1, #m_headersize     ; skip menu header

01      LDR     r0, [r1, #mi_itemflags]

        BIC     r0, r0, #mi_it_tick       ; ensure all unticked to start with
        STR     r0, [r1, #mi_itemflags]

        LDR     r14, [r1, #mi_iconflags]!
        BIC     r14, r14, #is_shaded      ; ensure none greyed out
        STR     r14, [r1], #(mi_size - mi_iconflags)

        TST     r0, #mi_it_lastitem       ; last item in menu?
        BEQ     %BT01                     ; [no]

        EXIT

; In    r1 -> menu
;       r2 = item to tick
; Out   item marked as ticked, flags preserved

TickMenu Entry "r1, r2"
        ADD     r1, r1, #m_headersize + mi_itemflags ; skip menu header
                                          ; and item fields before itemflags
   ASSERT mi_size = 24
        ADD     r2, r2, r2, LSL #1        ; *3
        LDR     r14, [r1, r2, LSL #3]     ; *24
        ORR     r14, r14, #mi_it_tick     ; 'tick' corresponding entry
        STR     r14, [r1, r2, LSL #3]
        EXIT

; In    r1 -> menu
;       r2 = item to untick
; Out   item marked as ticked, flags preserved
UnTickMenu Entry "r1, r2"
        ADD     r1, r1, #m_headersize + mi_itemflags ; skip menu header
                                          ; and item fields before itemflags
   ASSERT mi_size = 24
        ADD     r2, r2, r2, LSL #1        ; *3
        LDR     r14, [r1, r2, LSL #3]     ; *24
        BIC     r14, r14, #mi_it_tick     ; 'tick' corresponding entry
        STR     r14, [r1, r2, LSL #3]
        EXIT

;----------------------------------------
;----------------------------------------
;----------------------------------------

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In     r1 -> drive spec eg. :0

; Out    r1 -> media name (in dirnamebuffer) - "CDFS::discname"

GetMediaName Entry "r1-r3"

getmedialoop

        BL      GetMediaName_nochecks

        DebugS  media,"GetMediaName returning ",r1

        STR     r1, [sp]                ; ensure r1 correct on return

        BL      checkambiguous
        EXIT    VC
        EXIT    NE                      ; V set, so don't worry about Z

;*************
; Ambiguous disc name error !
;*************

; generate suitable warning message for the user

;****** Dismount drive number 'x'  This bit works fine '*cdfs:dismount 0'

        addr    r3, dismount
        BL      copycommand             ; dismount by drive number
        ADRL    r0, userdata
        SWI     XOS_CLI
        EXIT    VS

;***** *dismount cdfs::discname - this closes all of the windows on desktop

        LDR     r1, [sp]                ; dismount by disc name (inc. dirs)


;---------------------------------
; Dismount the drive by name
;---------------------------------

        [ Module_Version > 201
        BL      dismountit_byname
        |
        BL      dismountit
        ]

;---------------------------------

        ADRL    r1, driveno
        B       getmedialoop            ; try again!


      [ Module_Version > 201
dismountit_byname       Entry "r1"

        ADRL    r3, dismount
        BL      copycommand
        SUB     r1, r1, #2              ; r1 -> original drive number
        LDR     r2, [sp]                ; r2 -> "cdfs::discname"
        ADD     r2, r2, #:LEN:"cdfs::"  ; r2 -> discname
        BL      strcpy
        ADRL    r0, userdata

        SWI     XOS_CLI
        EXIT

      ]


      ; NOEXIT


checkambiguous Entry "r1-r5"

        MOVVC   r0, #OSFile_ReadInfo    ; see if we get "ambiguous disc name"
        SWIVC   XOS_File
;        TEQVC   r0, r0                  ; ensure Z set!
        TEQVC   pc, #0
        EXIT    VC

        LDR     r14, [r0]               ; check error number
        LDR     r2, =&1089E             ; "ambiguous disc name"
        TEQ     r14, r2
        EXIT

GetMediaName_nochecks Entry "r1-r7"

; Build up a buffer of 'CDFS::x.$'


; 'CDFS:'
        ADRL    r1, dirnamebuffer
        addr    r2, CDFScolon
        BL      strcpy_advance

; 'CDFS::'
        addr    r2, CDFScolon + (?CDFScolon) - 1
        BL      strcpy_advance

; 'CDFS::xxxx'
        LDR     r2, [ sp ]
        BL      strcpy_advance

; 'CDFS::xxxx.$'
        addr    r2, dotdollar
        BL      strcpy_advance

; Get the canonical disc name
        MOV     r5, #&80
        ADD     r2, r1, #2
        ADRL    r1, dirnamebuffer
        MOV     r0, #37
        MOV     r3, #0
        MOV     r4, #0

        SWI     XOS_FSControl

; Terminate the disc name to give 'CDFS::xxxxx' from 'CDFS::xxxxx.$'
        MOV     r14, #0
        RSBVC   r5, r5, #&80 - 2
        STRVCB  r14, [ r2, r5 ]
        STRVSB  r14, [r2, #-4]
        MOVVS   r2, r1

; Return a pointer to the name
        STR     r2, [ sp ]

        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   cx0, cy0 = coords of mouse pointer
;       other regs corrupt

GetPointerInfo ROUT

        Push    "r1, r2-r6, lr"         ; poke pointer info into stack

        ADD     r1, sp, #4
        SWI     XWimp_GetPointerInfo
        LDMVCIA r1, {cx0, cy0}

        LDR     r1, [sp], #6*4          ; Restore r1, kill temp frame
        Pull    "pc"

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Set up icon bar entries for CDFS
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   much corruption

        LTORG

        [ Module_Version > 201
ic_player0
 = ":0",0,0,":1",0,0,":2",0,0,":3",0,0,":4",0,0,":5",0,0,":6",0,0,":7",0,0,":8",0,0,":9",0,0
 = ":10",0,":11",0,":12",0,":13",0,":14",0,":15",0,":16",0,":17",0,":18",0
 = ":19",0,":20",0,":21",0,":22",0,":23",0,":24",0,":25",0,":26",0,":27",0

        |

ic_player0
 = ":0",0,":1",0,":2",0,":3",0,":4",0,":5",0,":6",0,":7",0,":8",0,":9",0
 = ":10",0,":11",0,":12",0,":13",0,":14",0,":15",0,":16",0,":17",0,":18",0
 = ":19",0,":20",0,":21",0,":22",0,":23",0,":24",0,":25",0,":26",0,":27",0

        ]

SetUpIconBar Entry

        SWI     XCDFS_GetNumberOfDrives
        MOVS    r2, r0
        BNE     dont_worry   ;don't worry if there is at least one drive
        SWI     XCDFS_ConvertDriveToDevice
        BVS     dont_worry

        CMP     r1, #-1  ;if there is at least one drive...
        MOVNE   r2, #1   ;...then set up one icon

dont_worry

        [ Module_Version > 201

        addr    r1, ic_player0 - 4         ; r1->:<drive number>,0
        ADD     r1, r1, r2, LSL #2

        |

        addr    r1, ic_player0 - 3         ; r1->:<drive number>,0
        ADD     r14, r2, r2, ASL #1
        ADD     r1, r1, r14
        SUBS    r14, r2, #10
        ADDGT   r1, r1, r14

        ]


        MOV     r4, #-1

more_drives
        ADD     r4, r4, #1             ; r4 = icon handle index
        CMP     r4, r2
        EXIT    GE

       [ Module_Version >= 213
        STR     r4, loop
       ]

;-------- AddToIconBar routine

        Push   "r1-r2"

        ADD     r2, r1, #icb_drivenumber    ; for later
        [ icb_drivenumber<>0
        ADD     r1, r1, #icb_drivenumber
        ]
        ADD     r3, r1, #len_mediaprefix    ;r3 -> disc name (colon incl)

        ADR     r5, discnames
        ADD     r5, r5, r4, LSL #drv_shift
        ADD     r1, r5, #drv_number
        BL      strcpy                      ; copy in drive number

        ADD     r1, r5, #drv_number
        BL      strlen
        STRB    r2, [r5, #drv_namelen]

        ADR     r2, iconbaricons          ; r2 -> iconbaricons
        LDR     r3, [r2, r4, LSL #2]!     ; r2 -> [icon to open next to]
        ADR     r1, cddiscname

;-----------------------------
;        BL      AllocateIcon              ; r5 -> drive number/name
;
;AllocateIcon Entry "r1-r5, x0, y0, x1, y1"
;-----------------------------
        Push    "r1-r5,x0,y0,x1,y1"

        MOV     r2, r1
        MOV     r0, #SpriteReason_ReadSpriteSize
        SWI     XWimp_SpriteOp                ; r3, r4 = pixel size

        MOVVC   r0, r6                        ; creation mode of sprite

        MOVVC   r1, #VduExt_XEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   x0, #0
        ADDVC   x1, x0, r3, LSL r2            ; pixel size depends on sprite

        MOVVC   r1, #VduExt_YEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   y0, #20                       ; sprite baseline
        ADDVC   y1, y0, r4, LSL r2
        MOVVC   y0, #-16                      ; text baseline

       ; EXIT    VS
        BVS     %FT11

        ASSERT  x0 > r5
        LDMIA   sp,{r1-r5}                    ; we need r1 and r5

        LDRB    r4, [r5, #drv_namelen]        ; include name in icon
        CMP     x1, r4, LSL #4                ; 16 OS units per char
        MOVLT   x1, r4, LSL #4

        ADRL    r14, userdata
        MOV     r0, #-2                       ; lhs of icon bar
        STMIA   r14!, {r0, x0, y0, x1, y1}    ; window handle, icon coords
        LDR     r0, iconbariconflags          ; r0 = icon flags
        ADD     r2, r5, #drv_number           ; r2 -> drive number
;        ADD     r3, r1, #icb_validation       ; r3 -> validation string

;----------------------------------------------------------------------------------
; Need to build up a sprite name so that it can be changed for photocd, or audio cd
;----------------------------------------------------------------------------------
; r4 = drive number
       [ Module_Version >= 213
        LDR     r1, loop
        ADRL    r3, sprite_name_list
        ADD     r3, r3, r1, LSL #3
        ADD     r3, r3, r1, LSL #2
        Push    "r0-r3, r14"
        MOV     r1, r3
        ADR     r2, iconspritename
        BL      strcpy
        Pull    "r0-r3, r14"
       |
        ADR     r3, iconspritename           ; r3->"Scddisc"
       ]
;----------------------------------------------------------------------------------

        STMIA   r14, {r0, r2-r4}              ; r4 = length of text


        ADRL    r1, userdata
        LDR     r14, wimpversion      ; if Wimp version 2.21 or later,
        CMP     r14, #221
        BLT     %FT01
        LDMIA   sp, {r0, r2-r4}       ; check previous icon handle
        LDR     r0, [r2]              ; [r2] = previous handle
        CMP     r0, #0                ; if creating for the first time,
        RSBLTS  r14, r4, #0           ; if this is not the first icon,
        LDRLT   r0, [r2, #-4]         ; open to right of previous icon
        MOVLT   r14, #-4              ; -4 => open to right of icon
        MOVGE   r14, #-3              ; -3 => open to left of icon / iconbar
        STR     r14, [r1, #u_handle]
01
        SWI     XWimp_CreateIcon

11
        Pull    "r1-r5, x0, y0, x1, y1"

;---------------
;;;;;;;;;;;;
        STRVC   r0, [r2]                  ; save new handle

        Pull    "r1-r2"   ; r3 and r5 corrupted

        EXIT    VS


        [ Module_Version > 201

        SUB     r1, r1, #4          ; Move to next icon def

        |

;        ADD     r1, r1, #3         ; Move to next icon def
;        SUB     r5, r2, r4
;        CMP     r5, #11
        SUB     r1, r1, #3
        CMP     r4, #10
;        ADDGE   r1, r1, #1
        SUBGE   r1, r1, #1


        ]

        B       more_drives

iconspritename = "S"            ; ALLOW TO RUN ON
cddiscname = "cddisc",0
 ALIGN

iconbariconflags
        DCD     &1700310B       ; text
                                ; sprite
                                ; h-centred
                                ; indirected
                                ; button type 3
                                ; fcol 7, bcol 1

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strcat
; ======
;
; Concatenate two strings

; In    r1, r2 -> CtrlChar/r3 terminated strings

; Out   new string in r1 = "r1" :CC: "r2" :CC: 0

strcat Entry "r1-r3"

        MOV     r3, #space-1

05      LDRB    r14, [r1], #1           ; Find where to stick the appendage
        CMP     r14, #delete            ; Order, you git!
        CMPNE   r14, r3
        BHI     %BT05
        SUB     r1, r1, #1              ; Point back to the term char

10      LDRB    r14, [r2], #1           ; Copy from *r2++
        CMP     r14, #delete            ; Order, you git!
        CMPNE   r14, r3                 ; Any char <= r3 is a terminator
        MOVLS   r14, #0                 ; Terminate dst with 0
        STRB    r14, [r1], #1           ; Copy to *r1++
        BHI     %BT10

        EXIT

; ..........................................................................
;
; strcpy
; ======
;
; Copy a string and terminate with 0

; In    r1 -> dest area, r2 -> CtrlChar / r3 terminated src string

strcpy ALTENTRY

        MOV     r3, #space-1            ; terminate on ctrl-char
        B       %BT10

strcpy_space ALTENTRY

        MOV     r3, #space              ; terminate on space or ctrl-char
        B       %BT10


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strcpy_advance
; ==============

; In    r1 -> dest string
;       r2 -> source string

; Out   r1 -> terminating null

strcpy_advance Entry "r2"

10      LDRB    r14, [r2], #1           ; Copy from *r2++
        CMP     r14, #delete            ; Order, you git!
        CMPNE   r14, #space-1           ; Any char < space is a terminator
        MOVLS   r14, #0                 ; Terminate dst with 0
        STRB    r14, [r1], #1           ; Copy to *r1++
        BHI     %BT10

        SUB     r1, r1, #1
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strlen
; ======
;
; Return the length of a null-terminated string

; In    r1 -> null terminated string

; Out   r2 length

strlen Entry "r1"

        MOV     r2, #0
05      LDRB    r14, [r1], #1
        CMP     r14, #0
        ADDNE   r2, r2, #1
        BNE     %BT05

        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_user_message (and _recorded)
; ==================

; In    r1 -> wimp_eventstr
;             [r1, #0]     block size
;             [r1, #12]    your ref
;             [r1, #16]    message action
;             [r1, #20...] message data

; Out   all regs may be corrupted - going back to PollWimp

event_user_message Entry

        LDR     r0, [r1, #message_action]

      [ Module_Version > 201
        LDR     r14, =Message_HelpRequest
        CMP     r0, r14
        BEQ     returnhelp
      ]

        LDR     r14, =Message_CDFSFilerOpenPlayer
        CMP     r0, r14
        BEQ     go_cd_volume_unclaimed

        CMP     r0, #Message_Quit
        EXIT    NE

        B       CloseDownAndExit
;       NOEXIT



        [ Module_Version > 201

; Token used by the XMessage_Lookup SWI for interactive help

cdi_tag               DCB "CDI", 0

dismount_tag          DCB "DIS", 0
share_tag             DCB "SHR", 0
volume_tag            DCB "VOL", 0
eject_tag             DCB "EJC", 0
free_tag              DCB "FRI", 0

 [ :LNOT: UseConfigureToConfigure
configure_tag         DCB "CON", 0
buffers_tag           DCB "BUF", 0
drives_tag            DCB "DRV", 0

configure_buffers_tag DCB "CBF", 0
configure_drives_tag  DCB "CDR", 0
 ]

notshare_tag          DCB "NSH", 0
sharep_tag            DCB "SHP", 0

sharewin_tag          DCB "SW", 0
sharewin1_tag         DCB "SW1", 0
sharewin2_tag         DCB "SW2", 0
sharewin3_tag         DCB "SW3", 0
sharewin5_tag         DCB "SW5", 0

volumewin_tag         DCB "VW", 0
volumewin0_tag        DCB "VW0", 0
volumewin1_tag        DCB "VW1", 0
volumewin2_tag        DCB "VW2", 0
volumewin3_tag        DCB "VW3", 0
volumewin4_tag        DCB "VW4", 0
volumewin7_tag        DCB "VW7", 0
volumewin9_tag        DCB "VW9", 0
volumewin11_tag       DCB "VW11", 0
volumewin13_tag       DCB "VW13", 0
volumewin15_tag       DCB "VW15", 0

         ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 -> message block containing help request
;       LR stacked
; Out   Message_HelpReply sent

returnhelp
        LDR     r4, matchedindex        ; preserve old values
        LDRB    r5, driveno+1
        Push    "r4, r5"

        LDR     r2, [r1, #ms_data + b_window]
        LDR     r3, [r1, #ms_data + b_icon]

        CMP     r2, #iconbar_whandle
        BNE     %FT01

        Push    "R1"
        MOV     r4, r3
        BL      matchdriveicon          ; must match: [matchedindex] = which one
        Pull    "R1"
        MOV     r0, #&FF                ; "HFF" is the token for the iconbar
        B       gothelpindex
01
        LDR     lr, sharewin_handle
        CMP     r2, lr
        BEQ     sharewin_help
        LDR     lr, volumewin_handle
        CMP     r2, lr
        BEQ     volumewin_help

        CMP     r3, #0                  ; if null icon, don't bother
        BLT     %FT99                   ; (avoid confusion with parent node)


; This bit loads the menu selections r2, r3 , r4 = menu selections

        MOV     r5, r1
        ADRL    r1, userdata + &80      ; r1 -> buffer for result
        MOV     r0, #1
        SWI     XWimp_GetMenuState

        BVS     %FT99

        LDMIA   r1, { r2, r3, r4 }

        MOV     r1, r5

        LDR     r0, menudrive
        ADD     r5, r0, #drv_number + 1 ; skip the ':'

; Which window ?
        CMP     r3, #-1
        BEQ     first_window_help

        CMP     r4, #-1
        BEQ     second_window_help

 [ :LNOT: UseConfigureToConfigure
; Third window : Buffer menu, or drive caret
third_window_help
        TEQ     r3, #0
        ADREQ   r0, configure_buffers_tag
        ADRNE   r0, configure_drives_tag
        MOV     r3, #0 ; no parameters
        ADD     r1, r1, #ms_data
        B       quick_peek
 ]

; First window  : Dismount, Configure =>
first_window_help
 [ UseConfigureToConfigure
        CMP     r2, #4
        ADREQ   r0, free_tag
        CMP     r2, #3
        ADREQ   r0, volume_tag
        ADRCC   r0, share_tag
        CMP     r2, #1
        ADREQ   r0, eject_tag
        ADRCC   r0, dismount_tag
 |
        CMP     r2, #5
        ADREQ   r0, free_tag
        ADRCC   r0, volume_tag
        CMP     r2, #3
        ADREQ   r0, share_tag
        ADRCC   r0, configure_tag
        CMP     r2, #1
        ADREQ   r0, eject_tag
        ADRCC   r0, dismount_tag
 ]

        MOV     r3, r5 ; parameter 0 (when used) is drive number
        ADD     r1, r1, #ms_data
        B       quick_peek

; Second window : Buffers =>, Drives =>
second_window_help
        TEQ     r2, #2
 [ UseConfigureToConfigure
        BEQ     %FT01
 |
        BNE     %FT01
        TEQ     r3, #0
        ADREQ   r0, buffers_tag
        ADRNE   r0, drives_tag
        MOV     r3, #0 ; no parameters
        ADD     r1, r1, #ms_data
        B       quick_peek
 ]
01
        TEQ     r3, #0
        ADREQ   r0, notshare_tag
        ADRNE   r0, sharep_tag
        MOV     r3, r5 ; parameter 0 is drive number
        ADD     r1, r1, #ms_data
        B       quick_peek

;------------------------------------------------------------------------------------
; Display help for the share window
;------------------------------------------------------------------------------------

sharewin_help
        ADRL    r0, sharewin_tag
        TEQ     r3, #1
        ADREQL  r0, sharewin1_tag
        TEQ     r3, #2
        ADREQL  r0, sharewin2_tag
        TEQ     r3, #3
        ADREQL  r0, sharewin3_tag
        TEQ     r3, #5
        ADREQL  r0, sharewin5_tag
        ADD     r1, r1, #ms_data        ; r1 -> data field of message
        LDR     r3, sharewindrive
        ADD     r3, r3, #drv_number + 1 ; skip the ':'
        B       quick_peek

;------------------------------------------------------------------------------------
; Display help for the player window
;------------------------------------------------------------------------------------

volumewin_help
        ADRL    r0, volumewin_tag
        TEQ     r3, #0
        ADREQL  r0, volumewin0_tag
        TEQ     r3, #1
        ADREQL  r0, volumewin1_tag
        TEQ     r3, #2
        ADREQL  r0, volumewin2_tag
        TEQ     r3, #3
        ADREQL  r0, volumewin3_tag
        TEQ     r3, #4
        ADREQL  r0, volumewin4_tag
        TEQ     r3, #9
        ADREQL  r0, volumewin9_tag
        TEQ     r3, #13
        ADREQL  r0, volumewin13_tag
        TEQ     r3, #15
        ADREQL  r0, volumewin15_tag
        TEQ     r3, #11
        ADREQL  r0, volumewin11_tag
        TEQ     r3, #7
        TEQNE   r3, #8
        ADREQL  r0, volumewin7_tag
        ADD     r1, r1, #ms_data        ; r1 -> data field of message
        LDR     r3, volumewindrive
        ADD     r3, r3, #drv_number + 1 ; skip the ':'
        B       quick_peek

;------------------------------------------------------------------------------------
; Display help for the icon on the icon bar, 'This is the CD-ROM drive xx icon ...'
;------------------------------------------------------------------------------------

gothelpindex

        ADRVCL  r3, userdata + &80     ; r3 -> parameter 0 (drive name)

        LDRVCB  r0, driveno + 1
        LDRVCB  r2, driveno + 2

        STRVCB  r0, [ r3, #0 ]
        STRVCB  r2, [ r3, #1 ]
        TEQVC   r2, #0
        MOVNE   r2, #0
        STRVCB  r2, [ r3, #2 ]

        ADRVC   r0, cdi_tag             ; r0 -> "CDI" token
        ADDVC   r1, r1, #ms_data        ; r1 -> data field of message

;------------------------------------------------------------------------------------
; Send back a help message for icon on icon bar or menus
;------------------------------------------------------------------------------------

quick_peek

        MOVVC   r2, #256-ms_data        ; r2 = buffer size

        BLVC    lookuptoken             ; on exit r2 = length of string (ex. 0)

        ADDVC   r2, r2, #4 + ms_data    ; include terminator
        BICVC   r2, r2, #3

SendHelpMessage

        STRVC   r2, [r1, #ms_size-ms_data]!
        LDRVC   r14, [r1, #ms_myref]
        STRVC   r14, [r1, #ms_yourref]
        LDRVC   r14, =Message_HelpReply
        STRVC   r14, [r1, #ms_action]
        MOVVC   r0, #User_Message
        LDRVC   r2, [r1, #ms_taskhandle]
        SWIVC   XWimp_SendMessage
99
        Pull    "r4, r5"                ; restore static data
        STR     r4, matchedindex
        STRB    r5, driveno+1

        EXIT

        ]


;..............................................................................

; In    r0 -> token string
;       r1 -> buffer to copy message into
;       r2 = size of buffer (including terminator)
;       r3 -> parameter 0
;       [messagedata] -> message file descriptor (0 => not yet loaded)
; Out   message file loaded if not already loaded
;       [r1..] = message, terminated by 0
;       r2 = size of string, including the terminator

        [ Module_Version > 201
str_messagefile DCB     "CDFSFiler:Messages", 0           ;  "<CDFSFilerCompile$Dir>.Messages", 0
str_templatefile DCB     "CDFSFiler:Templates", 0
        ]

                ALIGN


lookuptoken Entry "r0-r7"

        BL      allocatemessagedata             ; r0 -> file desc on exit

        LDMVCIA sp, {r1-r4}
        MOVVC   r5, #0                          ; parameters 1..3 not used
        MOVVC   r6, #0
        MOVVC   r7, #0

        SWIVC   XMessageTrans_Lookup

        STRVC   r3, [sp, #2*4]                  ; r2 on exit = string length
99
        STRVS   r0, [sp]
        EXIT

lookuperror Entry "r0-r7"

        BL      allocatemessagedata             ; r0 -> file desc on exit

        MOVVC   r1, r0
        LDRVC   r0, [sp]
        MOVVC   r2, #0
        MOVVC   r4, #0
        MOVVC   r5, #0                          ; parameters 1..3 not used
        MOVVC   r6, #0
        MOVVC   r7, #0
        SWIVC   XMessageTrans_ErrorLookup

        STR     r0, [sp]
        EXIT


;..............................................................................

; In    [messagedata] -> message file desc (0 => not yet opened)
; Out   r0 = [messagedata] -> message file desc (opened if not already open)

allocatemessagedata Entry "r1, r2"

        LDR     r0, messagedata
        CMP     r0, #0
        EXIT    NE

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #16
        SWI     XOS_Module

        STRVC   r2, messagedata

        MOVVC   r0, r2
        ADRVC   r1, str_messagefile
        MOVVC   r2, #0                          ; no user buffer
        SWIVC   XMessageTrans_OpenFile

        BLVS    deallocatemessagedata           ; preserves error state

        LDRVC   r0, messagedata
        EXIT

;..............................................................................

; In    [messagedata] -> message file desc, or = 0 if not loaded
; Out   [messagedata] = 0, OS_Module (Free) called if required, error preserved

deallocatemessagedata Entry "r0,r2"

        LDR     r2, messagedata
        MOVS    r0, r2
        EXIT    EQ

        MOV     r14, #0
        STR     r14, messagedata

        SWI     XMessageTrans_CloseFile         ; tell the MessageTrans module

        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        EXIT



; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 = state for ReportError
; Out   r1 = 1 (OK) or 2 (Cancel)

ReportError Entry "r2"


;----------------------------------------------------
; Get title from 'Messages' file
;----------------------------------------------------

        [ Module_Version > 201
        BL      MkBannerIn_userdata
        SWI     XWimp_ReportError
        |
        addr    r2, CDFSFiler_Banner
        SWI     XWimp_ReportError
        ]

        EXIT

;----------------------------------------------------
;
; In  Nothing
; Out Updates the playlist and details icons to show what's happening
;     Low byte of R0 on exit is the current track

updateplaylist
      Push      "r0-r6,lr"

      ; work out where we were 0.5s ago
      LDR       r0, CurrentVolumeDrive
      ADRL      r1, player_playlists
      LDR       r5, [r1, r0, LSL#2]    ; address of the playlist for this drive
      TEQ       r5, #0
      Pull      "r0-r6,pc",EQ          ; not yet had cause to scan this drive
      ADRL      r1, playerstate_list
      LDR       r6, [r1, r0, LSL#2]    ; the player state
      ASSERT    playerstate_listposn = 8
      Push      "r6"
      AND       r6, r6, #&0000FF00
      MOV       r6, r6, LSR#8          ; current offset in the track list

      ; read the drive status
      BL        MakeCDFSblockinR7
      SWI       XCD_AudioStatus
      SUB       r13, r13, #4
      MOVVS     r4, #0                 ; no track
      BVS       %FT10
      ASSERT    (playerstate_paused-playerstate_playing = 1) :LAND: (playerstate_playing = 0)
      CMP       r0, #playerstate_paused
      LDRHIB    r0, [r5, r6]
      BHI       %FT05                  ; it's not playing so the LBA will be rubbish
      ADRL      r1, userdata
      MOV       r0, #64                ; Find the current LBA
      SWI       XCD_ReadSubChannel
      LDRB      r0, [r1, #9]           ; what track are we on
05
      ; convert r0 to a string
      MOV       r4, r0
      MOV       r1, r13
      MOV       r2, #4
      SWI       XOS_ConvertCardinal1
      CLRV
10
      ; the current track is now in r4
      LDRB      r2, [r13, #7]          ; last seen track
      TEQ       r4, r2
      STRNEB    r4, [r13, #8]
      ADDEQ     r13, r13, #8
      BEQ       %FT40                  ; no change

      ; an error leads to "no disc",an empty playlist leads to "no audio",otherwise "track %0"
      ADRVC     r0, trackstring
      LDRB      r1, [r5, #0]
      TEQ       r1, #255               ; ie.the playlist contained no entries
      ADREQ     r0, noaudiostring
      MOVVS     r0, #255
      STRVSB    r0, [r5, #0]           ; empty the playlist
      ADRVS     r0, nodiscstring       ; this message overrides the above   
      ; update the details box
      ADRL      r1, userdata
      MOV       r2, #64
      MOVVS     r3, #0
      MOVVC     r3, r13
      BL        lookuptoken
      LDR       r0, volumewin_handle
      MOV       r4, #VOLUME__DETAILS
      BL        change_icon_text

      ADD       r13, r13, #4
      Pull      "r6"

      ASSERT    playerstate_listposn = 8
      AND       r6, r6, #&0000FF00
      MOV       r6, r6, LSR#8          ; current offset in the track list
      SUB       r13, r13, #128

      LDRB      r0, [r5, #0]           ; pick up the 0th track in the list
      TEQ       r0, #255
      MOVEQ     r1, r13
      BEQ       %FT35                  ; no audio tracks

      LDRB      r0, [r5, r6]           ; pick up the current playlist track number
      LDRB      r1, [r13, #128]        ; current track (goes back in R0 eventually)
      TEQ       r0, r1
      BEQ       %FT25

      ; playlist lost sync with CD drive,resync
      MOV       r6, #0
15
      LDRB      r0, [r5, r6]
      TEQ       r0, #255
      BNE       %FT20
      MOV       r6, #-1
      LDR       r1, CurrentVolumeDrive
      BL        MakeCDFSblockinR7
      BL        createplaylist         ; current playing track is not in the playlist,try again
20
      TEQ       r0, r1
      ADDNE     r6, r6, #1
      BNE       %BT15
      ADRL      r3, playerstate_list
      LDR       r1, CurrentVolumeDrive
      ADD       r1, r3, r1, LSL#2
      ASSERT    playerstate_listposn = 8
      STRB      r6, [r1, #1]           ; naughty poke corrected list position over 
25
      MOV       r3, r6
      MOV       r1, r13
      MOV       r2, #126   
30
      ; non empty playlist processing
      LDRB      r0, [r5, r3]           ; pick up the R3th track in the list
      TEQ       r0, #255
      BEQ       %FT35
      SWINE     XOS_ConvertCardinal1
      BVS       %FT35                  ; ran out of buffer
      MOV       r0, #space
      STRB      r0, [r1],#1
      ADD       r3, r3, #1
      CMP       r3, #99
      BCC       %BT30
35
      ; terminate the string,whether it contains anything or not
      MOV       r0, #0
      STRB      r0, [r1]
      MOV       r1, r13
      LDR       r0, volumewin_handle
      MOV       r4, #VOLUME__PLAYLIST
      BL        change_icon_text
      ADD       r13, r13, #128

40
      CLRV
      Pull      "r0-r6,pc"

nodiscstring    DCB     "DrEmpty",0
noaudiostring   DCB     "NoAudio",0
trackstring     DCB     "TrackNo",0
                ALIGN

;----------------------------------------------------
;
; In  r1 = drive to create playlist for
;     r7 = cdfs block
; Out A new playlist in RMA
;     or error if couldn't get any RMA
;

createplaylist
        Push    "r0-r5,lr"
        ADRL    r4, player_playlists
        LDR     r2, [r4, r1, LSL#2]
        CMP     r2, #0
        MOVEQ   r0, #ModHandReason_Claim
        MOVEQ   r3, #100                    ; room for all the tracks you could ever want on a redbook CD
        SWIEQ   XOS_Module
        ADDVS   r13, r13, #4
        Pull    "r1-r5,pc",VS

        STR     r2, [r4, r1, LSL#2]         ; where the playlist is

        SUB     sp, sp, #8
        MOV     r4, #1                      ; count in r4 incase r0 points to an err
        MOV     r5, #0
        MOV     r1, sp
10
        MOV     r0, r4
        SWI     XCD_EnquireTrack            ; get track info
        LDRVC   r3, [sp, #4]
        MOVVS   r3, #-1
        ANDS    r3, r3, #1                  ; isolate audio bit
        STREQB  r4, [r2, r5]
        ADDEQ   r5, r5, #1
        ADD     r4, r4, #1
        CMP     r4, #100
        BNE     %BT10
        MOV     r4, #255
        STRB    r4, [r2, r5]                ; mark the end of playlist
        ADDS    sp, sp, #8

        Pull    "r0-r5,pc"

;----------------------------------------------------
;
; In  r0= drive number as seen by the user (0..27)
; Out r7->area in userdata+64 area suitable for CD_SWIs
;  or r0->error and V=1 if error
;
MakeCDFSblockinR7
      Push      "r1-r7, r14"
      SWI       XCDFS_ConvertDriveToDevice
      Pull      "r1-r7, pc", VS
      MOV       r0, r1

; r1 = composite device id, or -1 if not found
      CMP       r0, #-1
      ADREQ     r0, EH__Driver_NoDrive
      Pull      "r1-r7, r14", EQ
      BEQ       lookuperror            ; find error and return to caller

      ADRL      r7, userdata + 64
      AND       r2, r0, #2_00000111    ; device id

      AND       r3, r0, #2_00011000    ; card
      MOV       r3, r3, LSR #3

      AND       r4, r0, #2_11100000    ; LUN
      MOV       r4, r4, LSR #5

      MOV       r5, r0, LSL #16        ; drive type
      MOV       r5, r5, LSR #24

      STMIA     r7, { r2, r3, r4, r5 }
      Pull      "r1-r6" 
      ADD       sp, sp, #4             ; make sure r7 makes it back
      Pull      "pc"

EH__Driver_NoDrive      DCD CDFSDRIVERERROR__NO_DRIVE
                         =  "NoDrive", 0
 ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out r2->userdata
Banner  DCB "Banner", 0
        ALIGN

MkBannerIn_userdata Entry "r0,r1,r3"

        ADR     r0, Banner
        ADRL    r1, userdata
        MOV     r2, #?userdata
        MOV     r3, #0
        BL      lookuptoken

        ADRVCL  r2, userdata
        STRVS   r0, [sp]
        EXIT



; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 [ debug
        InsertNDRDebugRoutines
 ]

        END
