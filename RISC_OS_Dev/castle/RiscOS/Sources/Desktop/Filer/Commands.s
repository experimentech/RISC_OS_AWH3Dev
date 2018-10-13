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
        MACRO
        UseDesk
        LDR     wp, [r12]               ; Can't do anything if not started
        LDR     r14, mytaskhandle       ; Don't allow queueing outside the wimp
        CMP     r14, #0
        BLLE    UseDesktopError
        EXIT    VS
        MEND

        MACRO
        ReadArgs $name,$regs,$size,$deskchk,$errtok
$name._Code
        Entry "$regs",$size
        ; Ensure Filer is initialised
 [ $deskchk
        UseDesk
 |
        LDR     wp, [r12]
 ]
        ; Set up and perform an OS_ReadArgs into stack allocated space
        MOV     r1, r0
        ADRL    r0, $name._Accept
        MOV     r2, sp
        MOV     r3, #$size
        SWI     XOS_ReadArgs
        BVC     %FT10

        Push    "r1"
        LDR     r1, [r0]
        LDR     r14, =ErrorNumber_BadParameters
        TEQ     r14, r1
        LDRNE   r14, =ErrorNumber_ArgRepeated
        TEQNE   r14, r1
        LDRNE   r14, =ErrorNumber_BuffOverflow
        TEQNE   r14, r1
        Pull    "r1"
        EXIT    NE

        ADR     r0, ErrorBlock_$name._Syntax
        BL      LookupError
        EXIT

ErrorBlock_$name._Syntax
        DCD     ErrorNumber_Syntax
        DCB     "$errtok",0
        ALIGN
10
        MEND

Filer_OpenDir_Accept
        DCB     "dir=directory/A/G,"
        DCB     "x0=topleftx,y1=toplefty,w=width,h=height,"
        DCB     "li=largeicons/S,si=smallicons/S,fi=fullinfo/S,"
        DCB     "sn=sortbyname/S,ss=sortbysize/S,st=sortbytype/S,"
        DCB     "sd=sortbydate/S,rs=reversesort/S,ns=numericalsort/S"
        DCB     0

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Had *command to enter Filer, so start up via module handler

Desktop_Filer_Code Entry
 [ version >= 113
        LDR     wp, [r12]
        LDR     r14, mytaskhandle
        CMP     r14, #-1
        BLNE    UseDesktopError
        EXIT    VS
 ]

        MOV     r0, #ModHandReason_Enter
        addr    r1, Filer_TitleString
        SWI     XOS_Module
        EXIT

 [ openat
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Get an integer from a ReadArgs vector
;
; In    r2 -> vector
;       r4 = parameter offset
;
; Out   EQ set if value not present r1=0
;       NE otherwise and
;       r1 contains value

readargs_getint Entry   "r0,r2,r4,r5"

        ; Check for parameter present
        LDR     r1, [r2, r4]
        TEQ     r1, #0
        EXIT    EQ

        ; Check for negative
        LDRB    r5, [r1]
        TEQ     r5, #"-"
        ADDEQ   r1, r1, #1      ; advance past it

        ; If present, convert it and accept any answer
        MOV     r0, #10         ; Base 10
        MOV     r2, #0          ; Don't care much
        SWI     XOS_ReadUnsigned
        CLRV                    ; Ignore any error

        TEQ     r5, #"-"        ; was it minus?
        RSBEQ   r2, r2, #0      ; neg it

        MOV     r1, r2
        MOVS    r14, #1         ; Clear the Z flag
        EXIT
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; In    r0-r6 trashable
;
; Format of a directory request
;

                ^       0
dirreq_link     #       4       ; Next request
dirreq_closeflags #     0       ; flags for CloseDir
dirreq_x0       #       4       ; Window location
dirreq_filetype #       0
dirreq_y1       #       4
dirreq_w        #       4
dirreq_h        #       4
dirreq_reason   #       1       ; Type of request (open, close, run, boot etc)
dirreq_viewmode #       1       ; View mode (for open)
dirreq_dirname  #       0
dirreq_size     *       :INDEX: @

drr_open        *       0
drr_close       *       1
drr_run         *       2
drr_boot        *       3

; Fields in the ReadArgs output vector
                ^       0
fopendir_dir    #       4
fopendir_x0     #       4
fopendir_y1     #       4
fopendir_w      #       4
fopendir_h      #       4
fopendir_li     #       4
fopendir_si     #       4
fopendir_fi     #       4
fopendir_sn     #       4
fopendir_ss     #       4
fopendir_st     #       4
fopendir_sd     #       4
fopendir_rs     #       4
fopendir_ns     #       4

        ReadArgs Filer_OpenDir,"r9",1024,{TRUE},SFLROPD
        MOV     r9, #drr_open

        ; Get pointer to directory name
        LDR     r1, [r2, #fopendir_dir]

        ; Get length of string
        LDRB    r3, [r1]
        LDRB    r14, [r1, #1]
        ORR     r3, r3, r14, LSL #8
        MOV     r5, r3          ; Hold length for later

        ; Add size of header
        ADD     r3, r3, #dirreq_size + 1 ; for terminator

        ; Claim a that size chunk
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        EXIT    VS
        MOV     r3, r2

    ; Fill in the fields

      ; x0 field
        MOV     r2, sp
        MOV     r4, #fopendir_x0
        BL      readargs_getint
        BEQ     %FT10
        STR     r1, [r3, #dirreq_x0]

      ; y1 field
        MOV     r4, #fopendir_y1
        BL      readargs_getint
        BEQ     %FT10
        STR     r1, [r3, #dirreq_y1]

      ; w field
        MOV     r4, #fopendir_w
        BL      readargs_getint
        BEQ     %FT20
        CMP     r1, #0                  ; if negative
        MOVLT   r1, #0                  ; then use default
        STR     r1, [r3, #dirreq_w]

      ; h field
        MOV     r4, #fopendir_h
        BL      readargs_getint
        BEQ     %FT20
        CMP     r1, #0                  ; if negative
        MOVLT   r1, #0                  ; then use default
        STR     r1, [r3, #dirreq_h]
        B       %FT30

10      STR     r1, [r3, #dirreq_x0]
        STR     r1, [r3, #dirreq_y1]
20      STR     r1, [r3, #dirreq_w]
        STR     r1, [r3, #dirreq_h]


30      ; Get the display switches
        MOV     r0, #0
        LDR     r1, [r2, #fopendir_fi]
        MOVS    r1, r1
        MOVNE   r0, #1 :SHL: dbu_displaymode :OR: db_dm_fullinfo :SHL: dbb_displaymode

        LDR     r1, [r2, #fopendir_si]
        MOVS    r1, r1
        MOVNE   r0, #1 :SHL: dbu_displaymode :OR: db_dm_smallicon :SHL: dbb_displaymode

        LDR     r1, [r2, #fopendir_li]
        MOVS    r1, r1
        MOVNE   r0, #1 :SHL: dbu_displaymode :OR: db_dm_largeicon :SHL: dbb_displaymode

        ; Get the sorting switches
        MOV     r4, #0
        LDR     r1, [r2, #fopendir_sd]
        MOVS    r1, r1
        MOVNE   r4, #1 :SHL: dbu_sortmode :OR: db_sm_date :SHL: dbb_sortmode

        LDR     r1, [r2, #fopendir_st]
        MOVS    r1, r1
        MOVNE   r4, #1 :SHL: dbu_sortmode :OR: db_sm_type :SHL: dbb_sortmode

        LDR     r1, [r2, #fopendir_ss]
        MOVS    r1, r1
        MOVNE   r4, #1 :SHL: dbu_sortmode :OR: db_sm_size :SHL: dbb_sortmode

        LDR     r1, [r2, #fopendir_sn]
        MOVS    r1, r1
        MOVNE   r4, #1 :SHL: dbu_sortmode :OR: db_sm_name :SHL: dbb_sortmode

        LDR     r1, [r2, #fopendir_rs]
        MOVS    r1, r1
        MOVNE   r4, #1 :SHL: dbu_sortmode :OR: 1 :SHL: dbb_sortorder

        LDR     r1, [r2, #fopendir_ns]
        MOVS    r1, r1
        MOVNE   r4, #1 :SHL: dbu_sortmode :OR: 1 :SHL: dbb_sortnumeric

        ; combine the two flags and store them
        ORR     r0, r0, r4
        STRB    r0, [r3, #dirreq_viewmode]

        ; Zero byte beyond end of dirname to terminate string
        ; This must be done after reading other parameters, as it
        ; may corrupt them.
        LDR     r1, [r2, #fopendir_dir]
        ADD     r1, r1, #2      ; move past length 2 bytes
        MOV     r14, #0
        STRB    r14, [r1, r5]   ; Stick a zero on the end

        MOV     r2, r1
        ADD     r1, r3, #dirreq_dirname
        BL      strcpy

        BL      Queue_Request_To_Self
        EXIT

; .............................................................................

Filer_CloseDir_Code Entry

        UseDesk

      [ debugclosedir
        DSTRING r0,"Filer_CloseDir "
      ]
        MOV     r1, r0
        MOV     r2, #0
        BL      Queue_CloseDir_Request_To_Self

        EXIT

; .............................................................................

Filer_Run_Accept
        DCB     "shift=s/S,noshift=ns/S,"
        DCB     "/A"
        DCB     0

        ALIGN

; Fields in the ReadArgs output vector
                ^       0,sp
frun_shift      #       4
frun_noshift    #       4               ; default, therefore no-op
frun_fsp        #       4


        ReadArgs Filer_Run,"r9,r12",256,{TRUE},SFLRRUN

        ; The [No]Shift switch is mutually exclusive
        LDR     r1, frun_shift
        LDR     r2, frun_noshift
        ANDS    r2, r2, r1
        ADRNE   r0, ErrorBlock_Filer_Run_Syntax
        BLNE    LookupError
        EXIT    VS
        
        ; Find the object type of the object
        LDR     r1, frun_fsp
        MOV     r0, #OSFile_ReadInfo
        SWI     XOS_File                ; r1 preserved
        EXIT    VS

        ; Ensure the object was found
        CMP     r0, #object_nothing
        ADREQ   r0, ErrorBlock_Global_NotFound
        MOVEQ   r4, r1
        BLEQ    LookupError
        EXIT    VS

        ; Get the file type from the info
        BL      FindFileType_FromInfo

        LDR     r1, frun_shift
        TEQ     r1, #0
        BEQ     %FT35

        MOV     r0, #&81
        MOV     r1, #&FF
        MOV     r2, #&FF
        SWI     XOS_Byte                ; Get SHIFT state (r1=&FF => SHIFT pressed)

        CMP     r1, #&FF
        BNE     %FT35
        CMP     r3, #filetype_directory
        CMPNE   r3, #filetype_application
        LDRNE   r3, =&FFF               ; SHIFTed file => text file
        BNE     %FT35

        LDR     r0, frun_fsp
        FRAMLDR r12
        BL      Filer_OpenDir_Code      ; SHIFTed dir/app => *Filer_OpenDir <dir>
        EXIT

35
        MOV     r8, r3
        LDR     r1, frun_fsp

        ; Find size of block required
        BL      strlen
        ADD     r3, r3, #dirreq_size + 1 ; for terminator

        ; Claim a that size chunk
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        EXIT    VS
        MOV     r3, r2

        ; Copy the filename into the block
        MOV     r2, r1
        ADD     r1, r3, #dirreq_dirname
        BL      strcpy

        STR     r8, [r3, #dirreq_filetype]
        MOV     r9, #drr_run
        BL      Queue_Request_To_Self

        ; If DATAOPEN is bounced then we don't wan't an old window handle hanging around
        MOV     r0, #0
        STR     r0, windowhandle

        EXIT

ErrorBlock_Global_NotFound
        DCD     ErrorNumber_FileNotFound
        DCB     "NoFile",0
        ALIGN

Filer_Boot_Code Entry "r9"
        MOV     r9, #drr_boot
        UseDesk

        MOV     r1, r0
        BL      nul_terminate
        BL      SussPlingApplic_GivenName
        EXIT    VC
        LDR     r2, [r0]
        LDR     r14, =ErrorNumber_WimpBadOp
        TEQ     r2, r14
        BEQ     %FT10
        LDR     r14, =ErrorNumber_WimpNoTasks
        TEQ     r2, r14
        BEQ     %FT10
        ; Any other errors are the caller's problem!
        EXIT

10
        ; Queue the action for when the wimp will let us do
        ; the biz.
        CLRV
        BL      strlen

        ; Add size of header
        ADD     r3, r3, #dirreq_size + 1 ; for terminator

        ; Claim a that size chunk
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        EXIT    VS
        MOV     r3, r2

        MOV     r2, r1
        ADD     r1, r3, #dirreq_dirname
        BL      strcpy_excludingspaces

        BL      Queue_Request_To_Self
        EXIT

; -----------------------------------------------------------------------
;
; Queue_Request_To_Self
;
; In
;  r3 = filled in request to be queued (RMAlloced)
;  r9 = reason code for request
;
; Out
;  request queued with reason code filled in
;
Queue_Request_To_Self Entry

        ; Fill in reason code
        STRB    r9, [r3, #dirreq_reason]

        ; Attach it to the queue
        MOV     r14, #Nowt
        STR     r14, [r3, #dirreq_link]
        LDR     r14, DirRequestEndLink
        STR     r3, [r14]
        ADD     r3, r3, #dirreq_link
        STR     r3, DirRequestEndLink

        ; Poke the application just in case...
        LDR     r3, poll_word
        ORR     r3, r3, #poll_word_command_waiting
        STR     r3, poll_word

        EXIT

; -----------------------------------------------------------------------
;
; Queue_CloseDir_Request_To_Self
;
; In
;  r1 = pointer to space or ctrl/char-terminated directory name
;  r2 = flags:
;       bit     meaning when set
;       0       don't canonicalise before queueing
;       1-31    unused - set to 0
;
; Out
;  VSet and error possible
;  queued request has 'don't canonicalise on reception' flag set
;
Queue_CloseDir_Request_To_Self Entry "r0-r5,r9"

        TST     r2, #1
        BNE     %FT10

        ; Canonicalise the path before use
        MOV     r0, #FSControl_CanonicalisePath
        ADR     r2, userdata
        MOV     r3, #0
        MOV     r4, #0
        MOV     r5, #userdata_size
        SWI     XOS_FSControl
      [ version < 145
        BVS     %FT90
      ]

        ADRVC   r1, userdata

10
 [ debugclosedir
        DSTRING r1, "Queue CloseDir on "
 ]
        ; Claim block of required size
        BL      strlen_excludingspaces

        ; Add size of header
        ADD     r3, r3, #dirreq_size + 1 ; for terminator

        ; Claim a that size chunk
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        BVS     %FT90

        ; Fill the block in
        MOV     r3, r2

        MOV     r2, r1
        ADD     r1, r3, #dirreq_dirname
        BL      strcpy_excludingspaces

        MOV     r0, #1
        STR     r0, [r3, #dirreq_closeflags]

        ; queue it
        MOV     r9, #drr_close
        BL      Queue_Request_To_Self

90
        STRVS   r0, [sp]
        EXIT

; .............................................................................

Filer_Truncation_Accept
        DCB     "LargeIconDisplay=LID/E,SmallIconDisplay=SID/E,FullInfoDisplay=FID/E"
        DCB     0

        ALIGN

        ReadArgs Filer_Truncation,"",36,{FALSE},SFLRTRU

        ; Deal with LargeIconDisplay switch
        LDR     r1, [r2]
        CMP     r1, #0
        BEQ     %FT20
        ADD     r1, r1, #1
        LDW     r3, r1, r4, r5
        CMP     r3, #0
        MOVLE   r3, #4096
        CMP     r3, #68
        MOVLT   r3, #68
        STR     r3, largeicon_truncation

20      ; Deal with SmallIconDisplay switch
        LDR     r1, [r2, #4]
        CMP     r1, #0
        BEQ     %FT30
        ADD     r1, r1, #1
        LDW     r3, r1, r4, r5
        CMP     r3, #0
        MOVLE   r3, #4096
        CMP     r3, #48
        MOVLT   r3, #48
        STR     r3, smallicon_truncation

30      ; Deal with FullInfoDisplay switch
        LDR     r1, [r2, #8]
        CMP     r1, #0
        EXIT    EQ
        ADD     r1, r1, #1
        LDW     r3, r1, r4, r5
        CMP     r3, #0
        MOVLE   r3, #4096
        CMP     r3, #48
        MOVLT   r3, #48
        STR     r3, fullinfo_truncation

        EXIT

; .............................................................................

Filer_Options_Accept
        DCB     "ConfirmAll/S,"
        DCB     "ConfirmDeletes/S,"
        DCB     "Verbose/S,"
        DCB     "Force/S,"
        DCB     "Newer/S,"
        DCB     "Faster/S"
      [ debugcmds
        DCB     ",Query/S"
      ]
        DCB     0

        ALIGN

        ReadArgs Filer_Options,"",28,{FALSE},SFLROPT

      [ debugcmds
        ; Check if Query switch was specified, in which case skip all others
        LDR     r1, [r2,#24]
        CMP     r1, #0
        BNE     %FT10
      ]
        ; Start with no options set
        MOV     r3, #0
        ; Is ConfirmDeletes switch present?
        LDR     r1, [r2, #4]
        CMP     r1, #0
        ORRNE   r3, r3, #Action_OptionConfirmDeletes
        BICNE   r3, r3, #Action_OptionConfirm
        ; Is Confirm switch present?
        LDR     r1, [r2]
        CMP     r1, #0
        ORRNE   r3, r3, #Action_OptionConfirm
        BICNE   r3, r3, #Action_OptionConfirmDeletes
        ; Is Verbose switch present?
        LDR     r1, [r2, #8]
        CMP     r1, #0
        ORRNE   r3, r3, #Action_OptionVerbose
        ; Is Force switch present?
        LDR     r1, [r2, #12]
        CMP     r1, #0
        ORRNE   r3, r3, #Action_OptionForce
        ; Is Newer switch present?
        LDR     r1, [r2, #16]
        CMP     r1, #0
        ORRNE   r3, r3, #Action_OptionNewer
        ; Is Faster switch present?
        LDR     r1, [r2, #20]
        CMP     r1, #0
        ORRNE   r3, r3, #Action_OptionFaster
        ; Store the options
        STRB    r3, fileraction_options
        EXIT

      [ debugcmds
10      ; Print current status of the options
        LDRB    r2, fileraction_options
        WRLN    " "
        WRLN    "Current state of options is:"
        STRIM   "Confirm all    : "
        TST     r2, #Action_OptionConfirm
        BL      writeyesorno
        STRIM   "Confirm deletes: "
        TST     r2, #Action_OptionConfirmDeletes
        BL      writeyesorno
        STRIM   "Verbose        : "
        TST     r2, #Action_OptionVerbose
        BL      writeyesorno
        STRIM   "Force          : "
        TST     r2, #Action_OptionForce
        BL      writeyesorno
        STRIM   "Newer          : "
        TST     r2, #Action_OptionNewer
        BL      writeyesorno
        STRIM   "Faster         : "
        TST     r2, #Action_OptionFaster
        BL      writeyesorno
        WRLN    " "
        EXIT

writeyesorno Entry
        BEQ     writeno
        WRLN    "Yes"
        EXIT
writeno
        WRLN    "No"
        EXIT
      ]

; .............................................................................

Filer_Layout_Accept
        DCB     "LargeIcons=LI/S,"
        DCB     "SmallIcons=SI/S,"
        DCB     "FullInfo=FI/S,"
        DCB     "SortByName=SBN/S,"
        DCB     "SortByType=SBT/S,"
        DCB     "SortBySize=SBS/S,"
        DCB     "SortByDate=SBD/S,"
        DCB     "ReverseSort=RS/S,"
        DCB     "NumericalSort=NS/S"
        DCB     0
        ALIGN

        ReadArgs Filer_Layout,"",64,{FALSE},SFLRLAY

        MOV     r3, #(db_sm_name :SHL: dbb_sortmode) :OR: \
                     (db_dm_largeicon :SHL: dbb_displaymode)

        ; Small icons?
        LDR     r1, [r2, #4]
        CMP     r1, #0
        MOVGT   r3, #db_dm_smallicon :SHL: dbb_displaymode

        ; Full Info?
        LDR     r1, [r2, #8]
        CMP     r1, #0
        MOVGT   r3, #db_dm_fullinfo :SHL: dbb_displaymode

        ; Sort by type?
        LDR     r1, [r2, #16]
        CMP     r1, #0
        ORRGT   r3, r3, #db_sm_type :SHL: dbb_sortmode

        ; Sort by size?
        LDR     r1, [r2, #20]
        CMP     r1, #0
        ORRGT   r3, r3, #db_sm_size :SHL: dbb_sortmode 

        ; Sort by date?
        LDR     r1, [r2, #24]
        CMP     r1, #0
        ORRGT   r3, r3, #db_sm_date :SHL: dbb_sortmode 

        ; Reverse sort?
        LDR     r1, [r2, #28]
        CMP     r1, #0
        ORRGT   r3, r3, #db_sortorder

        ; Numerical sort?
        LDR     r1, [r2, #32]
        CMP     r1, #0
        ORRGT   r3, r3, #db_sortnumeric

        STRB    r3, layout_options

        EXIT

; .............................................................................
Filer_DClickHold_Accept
        DCB     "DClickHold=DCH/E"
        DCB     0
        ALIGN

        ReadArgs Filer_DClickHold,"",32,{FALSE},SFLRDCH

        MOV     r3, #0

        LDR     r1, [r2, #0]
        CMP     r1, #0
        BEQ     %FT10

        ADD     r1, r1, #1
        LDW     r3, r1, r4, r5
        CMP     r3, #0
        MOVLE   r3, #0

10
        STR     r3, dclickhold_delay

        EXIT

        END
