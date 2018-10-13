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
; > Wimp09

;;-----------------------------------------------------------------------------
;; Claim a block big enough for the RMA sprite pool area, then attempt to
;; map the RMA against the ROM working out the difference.
;;
;; Then claim the block so that it is big enough fill in both areas, build
;; the list and then sort it.  Using the OS_HeapSort SWI.
;;
;; in   [baseofsprites] = current RAM sprite area
;;      [baseofromsprites] = current ROM sprite area
;;      [list_at] = address of sorted list / =0 if none
;;      [listsize] = size of sorted list / =0 if none
;;      [addtoolstolist] = 0 if not to / >0 then add tool sprites pool (if present)
;;      [tool_areaCB] = valid control block for adding tool sprites (if required)
;; out  [list_at] = base of sorted list / =0 if none
;;      [list_size] = size of sorted list (aligned to boundary)
;;      [list_end] = real end of list used when scanning for sprite
;;-----------------------------------------------------------------------------

alignvalue      * 64                    ; *MUST* be a Log2 value

        ASSERT  list_size=list_at+4

makespritelist Entry   "R0-R4,R8-R9"

        LDRB    R3,addtoolstolist
        TEQ     R3,#0                   ; should I add the tool sprites?
        LDRNE   R0,=SpriteReason_ReadAreaCB +&100
        ADRNEL  R1,tool_areaCB
        SWINE   XOS_SpriteOp            ; Yes then decode the RAM based control block
;
        MOV     R8,R3
        Debuga  sprite,"Sprite count for Tools =",R8
;
        LDR     R0,=SpriteReason_ReadAreaCB +&100
        LDR     R1,baseofromsprites
        SWI     XOS_SpriteOp            ; attempt to get number of ROM sprites
;
        ADD     R8,R8,R3                ; add to growing total
        Debuga  sprite,", ROM =",R3
;
        LDRB    R3,addtoolstolist
        TEQ     R3,#0                   ; Adding tool sprites?
        LDREQ   R0,=SpriteReason_ReadAreaCB +&100
        LDREQ   R1,baseofsprites        ; base of RAM area
        SWIEQ   XOS_SpriteOp            ; No then include iconsprites
;
        Debug   sprite,", RAM =",R3
;
        ADD     R3,R8,R3                ; total number of sprites to be obtained
        ADD     R3,R3,#alignvalue -1
        BICS    R3,R3,#alignvalue -1    ; align to nice boundary
        BLEQ    freelist                ; un allocate the list (if null)
        BEQ     %FT60                   ; exit - if null (flag as so)
;
        LDR     R2,list_size
        CMP     R2,R3,LSL #2            ; is the current buffer big enough?
        BHS     %FT10                   ; if not then skip the new cliam
;
        BL      freelist                ; release the current list
;
        MOV     R0,#ModHandReason_Claim
        MOV     R3,R3,ASL #2
        BL     XROS_Module              ; attempt to claim

        DebugE  sprite,"Cant allocate list buffer "

        BVS     %FT60                   ; and fall back if failed to get required memory
;
        Debug   sprite,"list buffer allocated at, size:",R2,R3
;
        ADRL    R0,list_at
        STMIA   R0,{R2,R3}              ; store bounds of the list away
10
        LDR     R3,list_at              ; R3 -> buffers to store names pointers at

        Debug   sprite,"Start of sprite list: ",R3

        LDRB    R0,addtoolstolist
        TEQ     R0,#0                   ; Adding tool sprites?
        BNE     %FT25                   ; Yes then jump, don't include RAM icon sprites

        LDR     R0,baseofsprites
        LDR     R1,[R0,#saFirst]
        ADD     R1,R1,R0                ; R1 -> first sprite in area
        LDR     R2,[R0,#saNumber]       ; R2 = count for number of sprites
;
        Debug   sprite,"RAM sprites; first, count =",R1,R2
;
20      SUBS    R2,R2,#1
        STRPL   R1,[R3],#4              ; store a pointer away
        LDRPL   R0,[R1,#spNext]
        ADDPL   R1,R1,R0                ; advance to the next sprite
        BPL     %BT20                   ; looping until finished
;
        Debug   sprite,"End of RAM sprite list =",R3
;
25      LDR     R0,baseofromsprites
        LDR     R1,[R0,#saFirst]
        ADD     R1,R1,R0                ; R1 -> start of ROM pool
        LDR     R2,[R0,#saNumber]       ; R2 = counter for number of sprites in area
;
        Debug   sprite,"ROM sprites; first, count =",R1,R2
30
        SUBS    R2,R2,#1                ; decrease counter
        STRPL   R1,[R3],#4              ; store another pointer away
        LDRPL   R0,[R1,#spNext]
        ADDPL   R1,R1,R0                ; advance to next
        BPL     %BT30                   ; looping until finished (bla de bla)
;
        LDRB    R2,addtoolstolist
        TEQ     R2,#0                   ; add the tools area to the list of sprites
        BEQ     %FT35
;
        ADRL    R0,tool_areaCB
        LDR     R1,[R0,#saFirst]
        ADD     R1,R1,R0
        LDR     R2,[R0,#saNumber]
;
        Debug   sprite,"Tool sprites; first, count =",R1,R2
31
        SUBS    R2,R2,#1                ; have we finished copying the pointers yet?
        STRPL   R1,[R3],#4
        LDRPL   R0,[R1,#spNext]
        ADDPL   R1,R1,R0                ; advance to next sprite
        BPL     %BT31                   ; until finished
35
        Debug   sprite,"End of entire list =",R3
;
; Now perform a Heap Sort of the list.
;
        Push    "R3"                    ; storing the top limit away
        LDR     R1,list_at              ; start of list
        SUB     R0,R3,R1
        MOV     R0,R0,ASR #2            ; number of items in list
      [ debugsprprior
        ADRL    R2,checkspritenames     ; comparison routine
      |
        ADR     R2,checkspritenames     ; comparison routine
      ]
        MOV     R3,WsPtr

        Debug   sprite,"HeapSort: Items, At, Checker =",R0,R1,R2

        TST     R1,#2_111:SHL:29        ; high address?
        BNE     %FA37
        SWI     XOS_HeapSort            ; attempt to sort the list
        B       %FA39
37      Push    "R7"
        MOV     R7,#0
        SWI     XOS_HeapSort32          ; use new SWI with 32-bit address
        Pull    "R7"

39      Pull    "R3"                    ; restore original boundary for the list

; Now attempt to remove duplicates by simply scanning down the list from start to
; end.  This we do by checking first to see if we have reached the end, if we
; have then we can exit.  Otherwise we get two pointers if they are the
; same then we block the entire list back down assuming that the first name
; compared is the

      [ SpritePriority
        LDR     R8,baseofhisprites
      |
        LDR     R8,baseofsprites
      ]
        LDR     R9,[R8,#saEnd]
        LDR     R2,list_at              ; start of the list to be scanned

        Debug   sprite,"HeapSort done, scan the list for duplicates"

40      SUB     R4,R3,R2
        CMP     R4,#8                   ; have we finished yet?
        STRLO   R3,list_end             ; setup the chopping end
        EXIT    LO

        LDMIA   R2,{R0,R1}
        BL      checkspritenames        ; are the two sprite names the same?
        ADDNE   R2,R2,#4
        BNE     %BT40                   ; loop back until all finished

 [ debugsprite
        ADD     R14,R0,#spName
        DebugS  sprite,"Duplicate:",R14,12
 ]
        SUB     R14,R0,R8               ; is first sprite in the RAM low area? (or high-priority if SpritePriority true)
        CMP     R14,R9
        ADDCC   R2,R2,#4                ; advance past entry if inside the RAM area, otherwise copy next name over current

      [ SpritePriority
        LDR     R4,[R2]                 ; note address of sprite being removed from list
      ]
        MOV     R0,R2                   ; start to copy from
50      CMP     R0,R3                   ; have we finished yet?
        SUBEQ   R3,R3,#4
        BEQ     %FT55                   ; looping until all copied (modify the end pointer as required)

        LDR     R1,[R0,#4]
        STR     R1,[R0],#4              ; copy it down
        B       %BT50                   ; loop until the list has been moved

55
      [ SpritePriority
        LDR     R0, preferredpool
        TEQ     R0, #0
        DebugIf EQ, sprprior, "RAM sprites preferred"
        BEQ     %BT40                   ; don't do anything if RAM sprites have priority

        Push    "R8,R9"
        LDR     R8, baseofsprites       ; see if the removed sprite was in the RAM sprite area
        LDR     R9, [R8, #saEnd]
        SUB     R0, R4, R8
        CMP     R0, R9
        Pull    "R8,R9", HS
      [ debugsprprior
        ADDHS   R4, R4, #spName
        DebugSIf HS, sprprior, "This removed sprite was not in RAM area: ", R4, 12
      ]
        BHS     %BT40                   ; don't do anything if removed sprite wasn't in the RAM sprite area

        Push    "R2,R5"
        LDR     R5, [R4, #spNext]       ; size of sprite (== amount to shift later pointers down by)
      [ debugsprprior
        Debug   sprprior, "Deleting sprite from RAM area: addr, size =", R4, R5
        ADD     R4, R4, #spName
        DebugS  sprprior, "- name = ", R4, 12
        SUB     R4, R4, #spName
      ]
        MOV     R0, #512
        ORR     R0, R0, #SpriteReason_DeleteSprite
        MOV     R1, R8
        MOV     R2, R4
        SWI     XOS_SpriteOp            ; delete the unnecessary sprite
    [ windowsprite
      [ ThreeDPatch
        MOV     R0,#0                   ; RAM pointers are now stale
        BL      reset_all_tiling_sprites
      |
        MOV     R0,#-1                  ; RAM pointers are now stale
        STR     R0,tiling_sprite
      ]
    ]
        LDR     R2, list_at             ; go back to beginning of list
56      CMP     R2, R3                  ; have we finished yet?
        Pull    "R2,R5,R8,R9", EQ
        BEQ     %BT40                   ; go back to check next pair of sprites

        LDR     R0, [R2]
        SUB     R1, R0, R8
        CMP     R1, R9
        ADDHS   R2, R2, #4
        BHS     %BT56                   ; this sprite wasn't in the RAM area, so won't have been affected by the deletion
        CMP     R0, R4
        ADDLO   R2, R2, #4
        BLO     %BT56                   ; this sprite was below the deleted sprite, so again no action is required
        SUB     R0, R0, R5
      [ debugsprprior
        ADD     R0, R0, #spName
        DebugS  sprprior, "Realigned sprite:", R0, 12
        SUB     R0, R0, #spName
      ]
        STR     R0, [R2]                ; move pointer down
        ADD     R2, R2, #4
        B       %BT56                   ; check next pointer
      |
        B       %BT40                   ; go back to check next pair of sprites
      ]

60      MOV     R0,#-1
        STR     R0,list_at              ; flag as no valid list setup
        STR     R0,list_size
        EXIT

;..............................................................................

; Compare the two sprite names, ensuring case insensitive and truncating
; at the twelth character

; in    R0 -> sprite to compare
;       R1 -> sprite to compare against
; out   NE/EQ GT/LT CS/CC

checknames Entry "R0-R4"
        B       %FT05

checkspritenames ALTENTRY

        ADD     R0,R0,#spName           ; ensure pointing at the sprite names
        ADD     R1,R1,#spName
05      MOV     R2,#12                  ; maximum string length = 12 characters

10      LDRB    R3,[R0],#1
        LDRB    R4,[R1],#1              ; get characters
        CMP     R3,#32
        MOVLE   R3,#0
        CMP     R4,#32
        MOVLE   R4,#0                   ; convert to terminators if required
        ASCII_LowerCase R3,LR
        ASCII_LowerCase R4,LR           ; ensure that the characters are lower case
        CMP     R3,R4                   ; and that they match
        EXIT    NE                      ; returning if not the same
;
        TEQ     R3,#0                   ; is it the end of the strings?
        SUBNES  R2,R2,#1
        BNE     %BT10                   ; loop back if still characters pending
;
        CMP     R3,R4                   ; compare the final characters
        EXIT


;;-----------------------------------------------------------------------------
;; Free list - attempt to release the list memory if currently allocated.
;;
;; in   [list_at] >0 then release block
;; out  [list_at] [list_size] = 0
;;-----------------------------------------------------------------------------

freelist EntryS  "R0-R2"

        Debug   sprite,"Calling to free sprite list",#list_at
;
        LDR     R2,list_at
        CMP     R2,R2,ASR #31           ; is the list memory allocated?
        MOVNE   R0,#ModHandReason_Free
        BLNE    XROS_Module              ; yes, so release it (ignore errors)
;
        MOV     R2,#0
        STR     R2,list_at
        STR     R2,list_size            ; mark as released
;
        EXITS


;;-----------------------------------------------------------------------------
;; Locate a sprite name setting its pointers to meaningful values.  This routine
;; attempts to binary chop the sprite list created by calling "makespritelist".
;;
;; Based on the algorithm in Knuth; Sorting/Searching, pp 407
;;
;; in   [spritename] --> sprite name
;; out  R2 -> sprite, VS/VC if not found/found
;;-----------------------------------------------------------------------------

getspriteaddr Entry "R0-R1,R3-R5"

        LDR     R0,spritename           ; get pointer to name to compare against
;
        LDR     R2,list_at              ; base of sprite pointerrs
        CMP     R2,R2,ASR #31           ; this may be 0 (not initialised) or -1 (no room)
        BEQ     %FT20
        LDR     R3,list_end
        SUB     R3,R3,R2
        SUB     R3,R3,#4
        MOV     R3,R3,ASR #2            ; u = size of list
        MOV     R4,#0                   ; l = 0

10      CMP     R4,R3                   ; if l>u then not found
        BGT     %FT20
;
        ADD     R5,R4,R3
        MOV     R5,R5,ASR #1            ; i = (l+u) /2
;
        LDR     R1,[R2,R5,ASL #2]
        ADD     R1,R1,#spName
;
        BL      checknames
        ADDGT   R4,R5,#1                ; if [R0]>[R1] l = i + 1
        SUBLT   R3,R5,#1                ; if [R0]<[R1] l = i - 1
        BNE     %BT10
;
        LDR     R2,[R2,R5,ASL #2]       ; R2 -> sprite found !!!
        CLRV
        EXIT
20
        MOV     R2,#0                   ;
        SETV                            ; else return 'cos not found V set!
        EXIT


;;-----------------------------------------------------------------------------
;; Handle the opening of the messages file - check first to see if it has
;; already been opened.
;;
;; in   -
;; out  R0 -> 16 byte block for messages (may already be open)
;;-----------------------------------------------------------------------------

GetMessages ROUT

        Push    "R1-R2,LR"
;
        LDR     R0,messages
        CMP     R0,#0                   ; is it open yet?
        BNE     %FT10
;
        ADRL    R0,message_block
        ADR     R1,messfsp
        MOV     R2,#0                   ; let MessageTrans do caching
        SWI     XMessageTrans_OpenFile
        ADRVCL  R0,message_block
        STRVC   R0,messages             ; pointer to messages block

        Debug   err,"Message block @",R0
10
        Pull    "R1-R2,PC"

messfsp = "WindowManager:Messages",0
        ALIGN


;;-----------------------------------------------------------------------------
;; Handle losing the messages file if its already opened.
;;-----------------------------------------------------------------------------

LoseMessages ROUT

        Push    "R0,LR"
;
        LDR     R0,messages
        CMP     R0,#0                   ; is it already open? (clears V)
        SWINE   XMessageTrans_CloseFile
        STRVS   R0,[SP]
;
        MOV     R14,#0
        STR     R14,messages            ; flag as lost (always!)
;
        Pull    "R0,PC"


;;-----------------------------------------------------------------------------
;; QuickLookup - look up token (no buffer), parameters in R4-R7 are optional
;;
;; in   R0 -> token to lookup
;; out  R0 -> text found
;;      R1 = length of text found
;;-----------------------------------------------------------------------------
QuickLookup
        Entry   "R2,R3"
        MOV     R1,R0
        MOV     R2,#0
        MOV     R3,#0
        BL      GetMessages             ; open messages if required
        SWI     XMessageTrans_Lookup
        MOVVC   R0,R2
        MOVVC   R1,R3
        EXIT

;;-----------------------------------------------------------------------------
;; LookupToken - resolve token into user specified buffer (with parameters)
;;
;; in   R0 -> token to lookup
;;      R2 -> buffer
;;      R3 = length of buffer
;;      R4 -> %0 substitution
;;      R5-R7 assumed to be zero
;;-----------------------------------------------------------------------------

LookupToken Entry "R1-R7"

        MOV     R1,R0                   ; -> token to be used
        B       %FA10

;;------------------------------------------------------------------------------
;; LookupToken1 - lookup token into user specified buffer
;;
;; in   R0 -> token to lookup
;;      R2 -> buffer
;;      R3 = length of buffer
;;------------------------------------------------------------------------------

LookupToken1 ALTENTRY

        MOV     R1,R0
        MOV     R4,#0                   ; justincase!
        MOV     R5,#0
10      MOV     R6,#0
        MOV     R7,#0
        BL      GetMessages             ; open messages if required
        SWI     XMessageTrans_Lookup
        EXIT


;;-----------------------------------------------------------------------------
;; Lookup an error block expanding and then return.
;;
;; in   R0 -> error block
;; out  R0 -> error block and overflow set
;;-----------------------------------------------------------------------------

ErrorLookup ROUT

        Push    "R0-R7,LR"
;
        BL      GetMessages             ; attempt to open the file
        ADDVS   sp,sp,#4
        BVS     %FT10                   ; reporting any errors in the process
;
        MOV     R1,R0                   ; R1 -> control block
        Pull    "R0"                    ; R0 -> error block
        MOV     R2,#0
        MOV     R4,#0                   ; no parameters
        MOV     R5,#0
        MOV     R6,#0
        MOV     R7,#0

 [ debugerr
        Debuga  err,"WimpErrorLookup,r0,r1",R0,R1
        ADD     R14, R0, #4
        DebugS  err," Token:",R14
 ]
        SWI     XMessageTrans_ErrorLookup
10
        Pull    "R1-R7,PC"              ; look it up and then return


;------------------------------------------------------------------------------
; Constants required for message checking routines
;------------------------------------------------------------------------------

messcheck_version       * 284


;;-----------------------------------------------------------------------------
;; Wimp_AddMessages
;;
;; This SWI will add a null terminated list of messages to the list of
;; accepted messages on the current task.  This is really only any use for
;; tasks which know about Wimp >= 284.
;;
;; in   R0 -> list of messages / =0 for none
;; out  -
;;-----------------------------------------------------------------------------

SWIWimp_AddMessages

        MyEntry "AddMessages"

        Debug   msgsel,"Wimp_AddMessages: list ->",R0

        MOVS    R3,R0
        BEQ     ExitWimp                ; if no messages to add then exit

        LDR     R4,taskhandle           ; currently active task

        LDR     R0,[WsPtr,R4]           ; -> task record
        LDR     R0,[R0,#task_wimpver]
        LDR     R1,=messcheck_version
        CMP     R0,R1                   ; is it worth adding to the list?
        BLHS    addmessages

        B       ExitWimp

;..............................................................................

; Add a list of messages to the messages to the internal task handle specified,
; in doing so we may actually have to allocate a block.
;
; The routine attempts to add the messages at the end and then perform
; a heap sort.  Having first checked for duplicates, this is not a speed
; critical operation (ie. not called on null-event).

; in    R3 -> list of messages / null terminated
;       R4 = internal task handle to add messages to / assumed to be valid
; out   -

addmessages Entry "R0-R7"

        Debug   msgsel,"add messages: list, task =",R3,R4

        MOV     R5,#0
10      LDR     R6,[R3,R5]
        TEQ     R6,#0                   ; end of the list encountered?
        ADDNE   R5,R5,#4
        BNE     %BT10                   ; loop back until finished scanning

        CMP     R5,#0                   ; is there any messages to add?
        EXIT    EQ                      ; if not then return without doing anything

        Debug   msgsel,"size of messages list =",R5

; R5 = size of messages list to add / create

        LDR     R4,[WsPtr,R4]           ; get pointer to the task block

        LDR     R2,[R4,#task_messages]
        CMP     R2,#nullptr
        EXIT    EQ                      ; the real fix for the AddMessages-to-task-that-already-wants-them bug
        CMP     R2,#0
        BNE     addmoremessages         ; add to the list if non-zero, create new block

        Push    "R3"
        MOV     R3,R5                   ; size of list to create
        MOV     R0,#ModHandReason_Claim
        BL     XROS_Module              ; attempt to allocate
        Pull    "R3"
        EXIT    VS

        Debug   msgsel,"new message buffer: size, at =",R5,R2

        STR     R2,[R4,#task_messages]
        STR     R5,[R4,#task_messagessize]
        Push    "R2,R5"

20      LDR     R6,[R3],#4
        TEQ     R6,#0
        STRNE   R6,[R2],#4              ; copy a message number
        BNE     %BT20                   ; loop back until all checked

        Pull    "R2,R6"
        B       sortmessages            ; ensure they are sorted

;..............................................................................

; add more to the current list - extend the current block by R5 and then
; attempt to add the messages at the end removing duplicates, once
; done shrink the block down to a real size.

; in    R3 -> list of messages to be added
;       R4 -> task record
;       R5 = number of words to append

addmoremessages
        LDR     R1,[R4,#task_messagessize]
        LDR     R2,[R4,#task_messages]  ; current list information

 [ RO4 :LAND: false ; This is too late to do this fix; if the app wants all messages, the the Wimp hasn't allocated a
                    ; messages list, and so addmoremessages doesn't get called. Interestingly, this fix is undone in
                    ; the patches to 4.02...
; MB FIX
; If the current message list has only the 0 terminator in it then the application wants all messages.
; So, don't bother adding these new messages as that will stop all other messages getting through.
	LDR	R14,[R2,#0]
	TEQ	R14,#0
	EXIT	EQ
; end MB FIX
 ]

        Push    "R3"
        MOV     R0,#ModHandReason_ExtendBlock
        MOV     r3, r5                  ;  jb/ma 4/1/06 r5 is already the extra space required
        BL     XROS_Module              ; attempt to extend it
        Pull    "R3"                    ; preserve the list pointer
        EXIT    VS

        Debug   msgsel,"extended message block at, size =",R2,R1

        MOV     R6,R1                   ; extending boundary  (old message size)

30      LDR     R7,[R3],#4              ; get a value from the list
        TEQ     R7,#0
        BEQ     %FT50

        Debug   msgsel,"adding message (check for duplicate) =",R7

        MOV     R0,R1                   ; index to check entries by

40      SUBS    R0,R0,#4
        STRMI   R7,[R2,R6]
        ADDMI   R6,R6,#4                ; add in at the end if end reached
        BMI     %BT30

        LDR     R14,[R2,R0]             ; get a message number
        CMP     R14,R7                  ; does it already exist
        BNE     %BT40                   ; loop back until found
        B       %BT30                   ; if it doesn't then try another entry

50      ADD     r3,r1,r5                ; jb/ma 18/1/06 total needed + claimed
        SUBS    r3,r6,r3                ; jb/ma 18/1/06 actual less above
                                        ; so give back any not needed
        MOVNE   R0,#ModHandReason_ExtendBlock
        BLNE   XROS_Module              ; reduce back to a meaningful size
        EXIT    VS

        Debug   msgsel,"after block truncate: at, change =,size =",R2,R3,R6

        STR     R2,[R4,#task_messages]  ; update to contain new size
        STR     R6,[R4,#task_messagessize] ; jb/ma 4/1/06 this is the actual size
                                           ; r3 is only the change in size

sortmessages
        Debug   msgsel,"sort list at, size =",R2,R6

        MOV     R0,R6,LSR #2            ; size of the list to be sorted
        MOV     R1,R2                   ; -> list to be sorted
        MOV     R2,#0                   ; sorting unsigned integers
        TST     R1,#2_111:SHL:29
        BNE     %FT55
        SWI     XOS_HeapSort
        B       %FT57
55      MOV     R7,#0
        SWI     XOS_HeapSort32
57
        Debug   msgsel,"list sorted and ready to rock and roll"

        EXIT


;;-----------------------------------------------------------------------------
;; Wimp_RemoveMessages
;;
;; Attempt to remove a set of messages being accepted by a task, no errors
;; are generated for unknown messages.  This call only applies to tasks
;; with a version >= 284.
;;
;; in   R0 -> list of messages / =0 for none
;; out  -
;;-----------------------------------------------------------------------------

SWIWimp_RemoveMessages

        MyEntry "RemoveMessages"

        Debug   msgsel,"Wimp_RemoveMessages: list at =",R0

        MOVS    R3,R0                   ; is there a messages list?
        CMPNE   R3,#nullptr
        BEQ     ExitWimp                ; exit if there is no list supplied

        LDR     R4,taskhandle

        LDR     R0,[WsPtr,R4]           ; -> task that is currently active
        LDR     R0,[R0,#task_wimpver]   ; = version number known by this task
        LDR     R1,=messcheck_version
        CMP     R0,R1                   ; is the tasks version number valid for this call?
        BLHS    removemessages

        B       ExitWimp

;..............................................................................

; remove the list of messages at R3 using internal handle of R4.

; in    R3 -> list of messages (will be non-zero)
;       R4 = internal task handle
; out   -

removemessages Entry "R1-R2,R4-R8"

        Debug   msgsel,"Selective remove task, list at =",R3,R4

        LDR     R4,[WsPtr,R4]           ; -> task block

        LDR     R2,[R4,#task_messages]
        CMP     R2,R2,ASR #31           ; are there any messages listed?
                                        ; (or does the task need to continue to receive all messages anyway?)
        LDRNE   R6,[R4,#task_messagessize]
        CMPNE   R6,#0
        EXIT    EQ                      ; if no messages then return

        Debug   msgsel,"selective remove list, size =",R2,R6

; R2 -> messages list
; R6 = size of the list to be scanned

10      MOV     R7,#0                   ; index into the list

        LDR     R8,[R3],#4              ; get message to be removed
        CMP     R8,#0
        BEQ     %FT40                   ; when end of list reached then reduce block size

        Debug   msgsel,"scan to remove message =",R8

; R7 = index into list of messages being scanned
; R8 = message to be removed

20      CMP     R7,R6                   ; have we reached the end of the list yet?
        BGE     %BT10                   ; loop back as finished scanning

        LDR     R0,[R2,R7]              ; get message we are looking at
        CMP     R0,R8                   ; remove this one?
        ADDNE   R7,R7,#4
        BNE     %BT20                   ; loop back until all checked

        Debug   msgsel,"message found at offset =",R7

30      CMP     R7,R6                   ; have we finished yet?
        ADDLT   R14,R7,#4
        LDRLT   R0,[R2,R14]
        STRLT   R0,[R2,R7]              ; copy the next message into the current slot
        ADDLT   R7,R7,#4                ; advance the pointer
        BLT     %BT30                   ; loop back until all checked

        Debug   msgsel,"message removed: new list size =",R6

        SUB     R6,R6,#4
        B       %BT10                   ; and try again until whole list scanned
40
        LDR     R3,[R4,#task_messagessize]  ; old size
        STR     R6,[R4,#task_messagessize]  ; new size
        SUBS    r3,r6,r3                ; jb/ma 4/1/06 check what we did not use
                                        ; and give back any unused

        MOVNE   R0,#ModHandReason_ExtendBlock
        BLNE    XROS_Module              ; attempt to reduce the block size
        STRVC   R2,[R4,#task_messages]  ; and then store updated block pointer

        Debug   msgsel,"after extend block: size of list =",R2,R6

        EXIT


;;-----------------------------------------------------------------------------
;; Remove all messages allocated to this task - flagging as removed.
;;
;; in   R5 = internal task handle
;; out  -
;;-----------------------------------------------------------------------------

removeallmessages Entry "R0,R2,R4-R5"

        Debug   msgsel,"remove all messages for task =",R5

        LDR     R5,[WsPtr,R5]           ; -> task record to be modified

        LDR     R2,[R5,#task_messages]
        CMP     R2,R2,ASR #31           ; is there a list attached
        MOVNE   R0,#ModHandReason_Free
        BLNE   XROS_Module              ; attempt to release it

        MOV     R2,#-1                  ; flag as no list of messages
        STR     R2,[R5,#task_messages]
        MOV     R2,#0
        STR     R2,[R5,#task_messagessize]

        CLRV
        EXIT


;;------------------------------------------------------------------------------
;; Scan to see if a message is active for the specified task.  This routine
;; must scan using the internal task handle specified and see if we can
;; broadcast to it.
;;
;; The routine takes the destination task handle and looks to see if it
;; has a messages list attached, if the pointer to this list is -1 (default)
;; then it is assumed that all messages are passed through (old style task)
;; otherwise it attempts to binary chop the list to find the required
;; message.
;;
;; in   R2 -> message block
;;      R3 -> task block (known to be alive)
;;      R5 = external task handle
;; out  R5 = R5 AND msf_broadcast
;;              IF R5 =0 on entry or message is not supported
;;------------------------------------------------------------------------------

checkformessage

        Entry   "R0-R4"

        LDR     R0,[R3,#task_messages]
        LDR     R1,[R3,#task_messagessize]
        CMP     R0,#nullptr             ; are all messages enabled?
        EXIT    EQ                      ; yes, so send all of them

        Debug   msgsel,"into check for message; block at, task, external =",R2,R3,R5

        LDR     R2,[R2,#ms_action +msb_size]
        TEQ     R2,#Message_Quit        ; message quit is always allowed
        EXIT    EQ                      ; so always return ....

        TEQ     R0,#0                   ; duff list characteristics?
        TEQNE   R1,#0
        ANDEQ   R5,R5,#msf_broadcast
        EXIT    EQ                      ; if so then return flaging as don't broadcast - quit already trapped!

        Debug   msgsel,"list at, size, msg =",R0,R1,R2

        SUB     R1,R1,#4
        MOV     R1,R1,LSR #2            ; R1 = size of list
        MOV     R3,#0                   ; R3 = l = 0

10      CMP     R1,R3                   ; end of list reached?
        ANDLT   R5,R5,#msf_broadcast
        EXIT    LT                      ; yes, so mark as not to be sent and then return

        ADD     R4,R1,R3
        MOV     R4,R4,LSR #1            ; get the mid point

        LDR     R14,[R0,R4,LSL #2]      ; get the message at this location
        CMP     R14,R2
        SUBGT   R1,R4,#1
        ADDLT   R3,R4,#1                ; adjust based on result, if equal then don't bother
        BNE     %BT10                   ; looping whilst not found

        Debug   msgsel,"message found =",R14,R2

        EXIT


        END
