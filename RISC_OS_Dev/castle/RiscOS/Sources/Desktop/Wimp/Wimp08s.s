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
; > s.Wimp08s


; This is the current source code - s.Wimp08 is old source code - see
; comments at top of s.Wimp08
;
; mjs
;
;;----------------------------------------------------------------------------
;; Switcher routines
;;----------------------------------------------------------------------------

; Wimp delegates task memory management to kernel, via OS_AMBControl

; Wimp_SlotSize
; Wimp_ClaimFreeMemory
; Wimp_TransferBlock
;
; findpages             look for application memory & set up free pool
; testapplication       see if the application space is in use
; restorepages          put the rest of the pages back after the current slot
; allocateslot          transfer pages from free pool to a slot array
; deallocateslot        transfer pages from a slot array to free pool
; mapslotin             map pages in a slot into application space
; mapslotout            map pages in a slot out of the way
;
; initdynamic           intercept SWI table entry
; resetdynamic          unintercept SWI table entry
; My_ChangeDynamic      stack the applications to fill up application space
;-----------------------------------------------------------------------------

; Data structures:
; task table -> task block (or task_unused if task dead)
; task block -> slot block for task
; freepool -> slot block for free pool (with room for all pages)
; slot block = { page, addr, protection }* -1 -1
;              (suitable for OS_ReadMemMapEntries and OS_FindMemMapEntries)
; freepoolbase, orig_applicationspacesize delimit the free pool

;-----------------------------------------------------------------------------


; Set/Read current Wimp slot size
; Entry:  R0 = new 'current' slot size in bytes (<0 ==> no change)
;         R1 = new 'next' slot size in bytes (<0 ==> no change)
; Exit:   R0 = actual 'current' slot size
;         R1 = actual 'next' slot size
;         R2 = total amount of free memory 'owned' by the Wimp
;              if R2 < R1, the next slot will not be allocated in full
;              when no tasks are running, R2 will be 0
;         if R0>=0 on entry, pages may be remapped and MemoryLimit changed


SWIWimp_SlotSize  ROUT
        MyEntry "SlotSize"

   Debug mjs2,"Wimp_SlotSize",R0,R1
;
        MOV     R4,R0                   ; R4 = new current slot size
;
        MOV     R2,R1                   ; R2 = proposed slot size
        SWI     XOS_ReadMemMapInfo
        CMP     R2,#-1                  ; if -ve, just read current value
        LDREQ   R3,slotsize
        BEQ     %FT01
        ADD     R2,R2,R0                ; R2 = (R2+size-1) DIV size * size
        SUB     R2,R2,#1
        DivRem  R3,R2,R0,R14,norem
        STR     R3,slotsize             ; [slotsize] = no of pages
01
        Push    "R0-R1"
    [ ShrinkableAreas
        MOV     R0, #5
        MOV     R1, #-1
        SWI     XOS_DynamicArea         ; memory in free pool + shrinkable
    |
        MOV     R0,#6
        SWI     XOS_ReadDynamicArea
        MOV     R2,R1                   ; memory in free pool
    ]
        Pull    "R0-R1"

        MUL     R1,R3,R0                ; R1 = next slot size
        STMIA   SP,{R1,R2}              ; ensure calling task gets new values

;
; transfer pages between current slot and free pool
; on exit R0 = actual current slot size (whether or not memory could be moved)
;
        CMP     R4,#-1                  ; R4 = proposed new current slot size
        BEQ     returnmemsize           ; done if just reading

        MOV     R0,#ApplicationSpaceSize
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        MOV     R3,R1                   ; R3 --> end of current slot
        MOV     R0,#MemoryLimit
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        TEQ     R1,R3
        BNE     returnmemsize           ; cannot change slot size
;
        LDR     R0,pagesize             ; R0 = page size
        SUB     R14,R0,#1
        ADD     R4,R4,R14
        BIC     R4,R4,R14               ; round up to nearest page boundary
;
        LDR     R5,taskhandle           ; obtain R5 --> task block
        LDR     R5,[wsptr,R5]
        TST     R5,#task_unused
        LDRNE   R5,pendingtask
        TST     R5,#task_unused
        BNE     returnmemsize           ; no current task (?)
;
        LDR     R2,[R5,#task_slotptr]   ; R2 --> slot (if any)
        CMP     R2,#nullptr
        BLEQ    getnullslot
        STRVC   R2,[R5,#task_slotptr]   ; R2 --> slot
        BVS     ExitWimp                ; exit if unable to claim block

        MOV     R1,R4,LSR #12           ;no. of (4k) pages
        MOV     R0,#2                   ;grow/shrink reason code
        SWI     XOS_AMBControl
        BVS     ExitWimp
        CMP     R2,#0
        MOVEQ   R2,#nullptr
        STR     R2,[R5,#task_slotptr]
        MOV     R1,R1,LSL #12           ;no. of bytes
        CMP     R1,R3,LSL #12           ;did no. of pages change?
        BEQ     returnmemsize
        MOV     R5,R1                   ;for message
        ADR     lr, returnmemsize
        B       sendmemmessage

; SafeChangeDynamic
; if running under Medusa then the CAO needs to be moved high, otherwise
; the CDA call will fail.
; Entry : R4 number of bytes to move (signed), R0-R3 possibly corrupt
; Exit  : R1 number of bytes actually moved (unsigned)
SafeChangeDynamic
        Push    "lr"
        MOV     R0,#15
        ADR     R1,SafeChangeDynamic
        SWI     XOS_ChangeEnvironment
        BVS     %FT03                   ; can't change cao, try and shift memory anyway.
        MOV     R2,R1
        MOV     R0,#6                   ; freepool
        MOV     R1,R4                   ; number of bytes to alter free pool by
        SWI     XOS_ChangeDynamicArea
        Push    "R1"
        MOV     R1,R2
        MOV     R0,#15
        SWI     XOS_ChangeEnvironment   ; put cao back where it was.
        Pull    "R1,PC"
03
        MOV     R0,#6                   ; freepool
        MOV     R1,R4                   ; number of bytes to alter free pool by
        SWI     OS_ChangeDynamicArea
04
        Pull    "PC"

;
; send round a broadcast, to be picked up by the Switcher
; NB this can only be done if the task is alive (otherwise it has no handle)
;
sendmemmessage
        Push    "lr"
        STR     R1,appspacesize
        LDR     R14,taskhandle
        LDR     R14,[wsptr,R14]
        TST     R14,#task_unused

    Debug mjs2,"sendmemmessage R1,R5",R1,R5
;
        ASSERT  ms_data=20
        MOVEQ   R0,#28                  ; 28 byte block
        MOVEQ   R3,#0                   ; your ref
        LDREQ   R4,=Message_SlotSize
        LDREQ   R6,[sp,#1*4]            ; next slot size (already on stack)
        Push    "R0-R6"
        MOVEQ   R0,#User_Message        ; don't bother getting reply
        MOVEQ   R1,sp
        MOVEQ   R2,#0                   ; broadcast
        BLEQ    int_sendmessage         ; fills in sender, myref
        ADD     sp,sp,#28
        Pull    "pc"

returnmemsize
    Debug mjs2,"returnmemsize R1",R1
        MOV     R0,#MemoryLimit         ; may not actually be full slot size
        MOV     R1,#0                   ; (eg. if Twin is running above)
        SWI     XOS_ChangeEnvironment
    Debug mjs2,"  returnmemsize R1",R1
        SUBVC   R0,R1,#ApplicationStart ; R0 = actual slot size
    Debug mjs2,"  returnmemsize R0,R1",R0,R1
        B       ExitWimp
        LTORG

getnullslot
   Push  "R0-R1,LR"
   MOV   R0,#0  ;reason code 0 (allocate)
   MOV   R1,#0  ;0 pages
   SWI   XOS_AMBControl
   Debug mjs2,"getnullslot, slot handle =",R2
   STRVS R0,[SP]
   Pull  "R0-R1,PC"

servicememorymoved
  ; If OS_ChangeDynamicArea claims some or all of the application slot (ie if Service_Memory
  ; isn't claimed or UpCall_MovingMemory was claimed) then we need to issue Message_SlotSize
  ; to keep the Switcher up-to-date.
        Push    "R0-R6,LR"
        MOV     R0,#ApplicationSpaceSize
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        LDR     R0,appspacesize
        SUB     R1,R1,#ApplicationStart
        TEQ     R1,R0
        Pull    "R0-R6,PC", EQ
        LDR     R0,slotsize
        MOV     R5,R1
        MOV     R0,R0,LSL #12
        Push    "R0"
        BL      sendmemmessage
        ADD     SP,SP,#4
        Pull    "R0-R6,PC"

;
; Claim free memory pages
; Entry:  R0 = 0 for release, 1 for claim
;         R1 = length required
; Exit:   R1 = length available
;         R2 = start address
;         R2 = 0 means memory could not be claimed (no need to release)
; Can't:  if not enough free memory
;         if claimed already
;         if in the middle of a remapping operation
;

mem_remapped    *       2_0001
mem_claimed     *       2_0010

wimparea
        DCB     "Wimp"
        ALIGN

SWIWimp_ClaimFreeMemory  ROUT
        MyEntry "ClaimFreeMemory"
        Debug wcf, "Wimp_ClaimFreeMemory -> R0,R1", R0, R1
;
        CMP     R0,#0
        BNE     %FT01
; free
        MOV     R0,#0
        ADRL    R14,freepoolinuse
        STRB    R0,[R14]
  [ KernelLocksFreePool
        MOV     R0,#10
        ORR     R0,R0,#&100
        MOV     R1,#0
        SWI     XOS_Memory                              ; release wimp lock
        CLRV                                            ; Assume errors can be ignored (SWI not implemented in recent kernels)
  ]
        B       ExitWimp
01
; claim
        ADRL    R10,freepoolinuse
        LDRB    R0,[R10]
        TEQ     R0,#0
        MOVNE   R0,#0
        STRNE   R0,[SP]
        STRNE   R0,[SP,#4]
        BNE     ExitWimp                                ; already 'claimed'
  [ DynamicAreaWCF
        LDR     R14,wcfda
        TEQ     R14,#0
        BNE     %FT50
  ]
        MOV     R9,R1                                   ; preserve the amount asked for
        MOV     R0,#2
        MOV     R1,#6
        SWI     XOS_DynamicArea
        MOVVC   R0,R3
        MOVVC   R1,R2
        MOVVS   R0,#0                                   ; Shouldn't happen
        MOVVS   R1,#0
        TST     R4,#1:SHL:20                            ; Physical memory pool?
        MOVNE   R0,#0                                   ; Assume no logical mapping
        MOVNE   R1,#0

        CMP     R9,R1                                   ; set HI if R9 <0 or R9>R1
        MOVHI   R0,#0
        BHI     %FT10
  [ KernelLocksFreePool
        Push    "r0-r1"
        MOV     R0,#10
        ORR     R0,R0,#&100
        MOV     R1,#1
        SWI     XOS_Memory                              ; set wimp lock
        Pull    "r0-r1"
        MOVVS   R0,#0                                   ; just claim no memory available on error
        MOVVS   R1,#0
        BVS     %FT10
  ]
08
        MOV     R2,#1
        STRB    R2,[R10]                                ; mark free pool in use

10
        CLRV
        STR     R0,[SP,#4]                              ; return values
        STR     R1,[SP]
        Debug wcf, "<- R1,R2", R1, R0
        B       ExitWimp

 [ DynamicAreaWCF
wcfda_maxsize * 4 :SHL: 20 ; Considering the call has been deprecated since RISC OS 3.5, 4MB seems a reasonable limit

50
        ; Wimp_ClaimFreeMemory 'claim' operation, called from above
        MOV     R9,R1                                   ; preserve the amount asked for
        MOV     R0,#5
        MOV     R1,#-1
        SWI     XOS_DynamicArea                         ; get total free memory
55
        MOVVS   R0,#0
        MOVVS   R1,#0
        BVS     %BT10
        Debug wcf, "total free mem: ", R2
        CMP     R2,#wcfda_maxsize
        MOVHI   R2,#wcfda_maxsize
        CMP     R9,R2
        MOVHI   R0,#0
        MOVHI   R1,R2
        BHI     %BT10
        ; Grow the DA so it's at least R9 size
        LDR     R0,wcfda
        SWI     XOS_ReadDynamicArea
        BVS     %BT55
        Debug wcf, "current DA size: ", R1
        CMP     R1,R9
        BHS     %BT08
        MOV     R2,R0
        LDR     R0,wcfda
        SUB     R1,R9,R1
        Debug wcf, "growing by: ", R1
        SWI     XOS_ChangeDynamicArea
        Debug wcf, "actual grow: ", R1
        DebugIf VS, wcf, "error!"
        BVS     %BT55
        MOV     R0,R2
        MOV     R1,R9
        B       %BT08

initwcfda ROUT
        Entry   "R0-R8"
        MOV     R0,#0
        STR     R0,wcfda
        ; Check if WCF DA is needed
        ; Is free pool a PMP?
        MOV     R0,#2
        MOV     R1,#6
        SWI     XOS_DynamicArea
        EXIT    VS
        TST     R4,#1:SHL:20
        BNE     %FT50
      [ KernelLocksFreePool
        ; Can free pool be locked?
        LDR     R0,=10+&100
        MOV     R1,#1
        SWI     XOS_Memory
        LDRVC   R0,=10+&100
        MOVVC   R1,#0
        SWIVC   XOS_Memory
        BVS     %FT50
      ]
        EXIT
50
        ; DA required
        ADRL    R0,wimpareastring       ; Look up name for Wimp dynamic area.
        ADR     R2,errorbuffer          ; Use safe place for temporary string (copied by OS_DynamicArea).
        MOV     R3,#256
        BL      LookupToken1
        MOVVC   R8,R2
        ADRVSL  R8,wimpareastring       ; If look up fails then create something anyway.

        MOV     R0,#0
        MOV     R1,#-1
        MOV     R2,#0
        MOV     R3,#-1
        LDR     R4,=2 + (1:SHL:9)       ; SVC only, shrinkable (note that we don't shrink automatically, so just let the OS deal with it), user-draggable (should be fine, shouldn't be locked at any time when a drag is possible)
        MOV     R5,#wcfda_maxsize
        ADR     R6,wcfda_handler
        ADRL    R7,freepoolinuse
        SWI     XOS_DynamicArea
        STRVC   R1,wcfda
        EXIT

destroywcfda ROUT
        Entry  "R0-R1"
        LDR    R1,wcfda
        MOV    R0,#0
        CMP    R1,#0
        STR    R0,wcfda
        MOV    R0,#1
        SWI    XOS_DynamicArea
        EXIT

wcfda_handler ROUT
        CMP    R0,#4
        BNE    %FT90
        ; TestShrink entry
        ; Allow shrinking if not locked
        LDRB   R3,[R12]
        CMP    R3,#0
        MOVEQ  R3,R4
        MOVNE  R3,#0
        MOV    PC,LR
90
        MOV    R0,#0
        SETV   GT
        MOV    PC,LR

wimpareastring
        DCB     "WCF",0
        ALIGN

 ]

;
wimp_area_handler
        CLRV
        TST     R0,#1
        MOVNE   PC,lr                   ; not insterested in postshrink/grow
        SETV
; must be a pre shrink/grow, allow this if it was caused by the claim above
        Push    R0
        LDRB    R0,memoryOK
        TEQ     R0,#0
        Pull    R0
        CLRV    NE
        MOVVC   PC,lr
        CMP     R0,#2
        MOVEQ   R3,#0
        MOV     R0,#0
        SETV
        MOV     PC,lr

;
; Transfer memory from one application to another
; Entry:  R0 = task handle of source
;         R1 --> source buffer
;         R2 = task handle of destination
;         R3 --> destination buffer
;         R4 = buffer length
;         buffer addresses and length are byte-aligned (not nec. word-aligned)
;         the buffer addresses are validated to ensure they are in range
; Errors: "Invalid task handle"
;         "Wimp transfer out of range"
;
; note that we use tempworkspace here

SWIWimp_TransferBlock  ROUT
        MyEntry "TransferBlock"
;
  Debug mjs4,"&&&Wimp_TransferBlock",R0,R1,R2,R3,R4
        Push    "R0-R4"
        MOV     R0,#MemoryLimit         ; force this field to be up-to-date
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        LDR     R14,taskhandle
  Debug mjs4,"&&& taskhandle,MemoryLimit",R14,R1
        TEQ     R14,#0
        LDRNE   R14,[wsptr,R14]
        CMPNE   R14,#0
        STRGT   R1,[R14,#task_environment+12*MemoryLimit]
        LDMIA   SP,{R0-R4}                      ; leave them on the stack
;
  Debug mjs4,"&&& validtask_alive",R2
        BL      validtask_alive
        MOVVC   R7,R6                   ; R7 --> dest task block
        MOVVC   R2,R0
        Push    "R5"
  Debug mjs4,"&&& validtask_alive",R2
        BLVC    validtask_alive         ; R6 --> source task block
        BVC     %FT05
medusa_exit_trb
        ADD     SP,SP,#4                ; the push above was non-conditional
medusa_exit_trb2
        ADD     SP,SP,#20
        SETV                            ; want an error
        B       ExitWimp
;
05
        SUBS    R10,R4,#0               ; length must != 0
        BNE     %FT07                   ; ignore zero length now!
        ADD     SP,SP,#24
        ; no error so don't set V
        B       ExitWimp

07
        BLT     err_badtransfer
        CMP     R1,#ApplicationStart    ; buffer start >= &8000
        CMPHS   R3,#ApplicationStart
        BLO     err_badtransfer
        SUB     R8,R1,#ApplicationStart ; assuming app space...
        SUB     R9,R3,#ApplicationStart ; ... R8,R9 = offsets into domain
  Debug mjs4,"&&& offsets R8,R9",R8,R9
;
        LDR     R11,orig_applicationspacesize
;
        CMP     R1,R11                  ; not in application space?
        ADDHS   R8,R8,#ApplicationStart ; make absolute again
        BHS     %FT11
        LDR     R14,[R6,#task_environment+12*MemoryLimit]
  Debug mjs4,"&&& source memlimit",R14
        ADD     R0,R1,R4
        CMP     R0,R14
        BHI     err_badtransfer
11
        CMP     R3,R11                  ; not in application space?
        ADDHS   R9,R9,#ApplicationStart ; make absolute again
        BHS     %FT01
        LDR     R14,[R7,#task_environment+12*MemoryLimit]
  Debug mjs4,"&&& dest memlimit",R14
        ADD     R2,R3,R4
        CMP     R2,R14
        BHI     err_badtransfer
01
;
; map all slots into memory space, copy the data, then unmap them
; NOTE: make sure the slots are mapped out before exitting!!!
;
        MOV     R0,#ApplicationSpaceSize
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment   ; R1 --> end of current slot
;

; orignal calling values are still on the stack
        TEQ     R6,R7                   ; are the tasks the same?
        BEQ     %FT02
        CMP     R10,#7*1024*1024
        BLT     %FT02
; ok we're doing a BIG transfer, so split it up
        MOV     R10,#7*1024*1024        ; 7 meg, leave a bit of breathing space
        Push    "R1"                    ; save end-of-current-slot
        ADD     R0,SP,#8
        LDMIA   R0,{R0-R4}              ; original parameters for Wimp_TransferBlock
        ADD     R1,R1,#7*1024*1024      ; we'll carry on but only do 7 megs worth
        ADD     R3,R3,#7*1024*1024      ; then recall the routine, but starting 7 meg
        SUB     R4,R4,#7*1024*1024      ; further on.
        SWI     XWimp_TransferBlock
        Pull    "R1"                    ; restore end-of-current-slot
; this will cycle through as many times as required
02
; now if the ammount to copy+ R1 > app space, or 2* copy if neither task is the current task
; then part or all of current task must be paged out.
  Debug mjs4,"&&& alleged end of current slot (R1)",R1
        MOV     R0,R1
        LDR     R1,taskhandle
        LDR     R2,pagesize
        LDR     R4,[SP]                 ; task handle
        TEQ     R1,R4
        BEQ     onetask_currentr4       ; one of the tasks is the current task
        TEQ     R1,R5
        BEQ     onetask_currentr5
        CMP     R8,R11
        ADDLO   R0,R0,R10
        ADDLO   R0,R0,R2                ; just in case copy is over a page
        CMP     R9,R11
        ADDLO   R0,R0,R10
        ADDLO   R0,R0,R2
        LDR     R14,orig_applicationspacesize
        CMP     R0,R14
        BLO     %FT03

; since the copy must take place in application space (on ARM 3 its the only place! and on
; ARM 600 a level 2 page table would be required- 24K) we have to make some room by paging
; out part of the current task. For simplicity, we page the whole of the task out on the
; assumption that it is only rare circumstances that will bring us here. It's also
; potentially dangerous paging out bits of the current task, eg. if an exception occurs
; the Environment may point to somewhere that we've paged a different bit of memory to.
; Another complication with selective paging of the current task is that the bit we choose
; to page out may be required in the copy, obviously we need to do more work to make sure
; we don't fall over in these situations.
makespacefromct
  Debug mjs4,"&&& makespacefromct"
        Push    "R1"                    ; save task handle
        BL      mapslotout              ; map out CT
        MOV     R0,#0
        STR     R0,taskhandle
        ADD     R0,SP,#8                ; skipping just-pushed R1 and pushed R5 for Medusa...
        LDMIA   R0,{R0-R4}              ; ...restore R0-R4 from stack for recursive call
        SWI     XWimp_TransferBlock     ; do it again, only this time there is no current task
        Pull    "R1"
        STR     R1,taskhandle           ; return to how it all was
        BL      mapslotin
        ADD     SP,SP,#24
        B       ExitWimp

; this is potentially dodgy as the bit we want to map out of the way may actually be in
; the transfer range

onetask_currentr5
  Debug mjs4,"&&& onetask_currentr5 R4,R5,R8,R11",R4,R5,R8,R11
        TEQ     R5,R4
        BEQ     %FT03
        CMP     R8,R11                  ; we only need to woryy about space if the copy
                                        ; is actually in the tasks app space
        BLO     onetaskcurrent
        B       %FT03

onetask_currentr4
  Debug mjs4,"&&& onetask_currentr4 R4,R5,R9,R11",R4,R5,R9,R11
        TEQ     R5,R4
        BEQ     %FT03
        CMP     R9,R11

onetaskcurrent
        ADDLO   R0,R0,R10
        ADDLO   R0,R0,R2                ; just in case copy is over a page
  Debug mjs4,"&&& onetask_current R0,R2,R10",R0,R2,R10
        LDR     R14,orig_applicationspacesize
        CMP     R0,R14

        BLO     %FT03
        B       makespacefromct


03
        MOV     R0,#ApplicationSpaceSize
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment   ; R1 --> end of current slot
  Debug mjs4,"&&& end of current slot",R1
        Pull    "R4"
        ADD     SP,SP,#20               ; will always be original values on stack
        MOV     R2,#0
        STR     R2,tempworkspace+4      ; indicate mapenoughslot
        STR     R2,tempworkspace+12     ;  not used yet
        MOV     R2,R1
        LDR     R3,taskhandle
        CMP     R8,R11                  ; do we need it paged in ?
        BHS     %FT04
        TEQ     R3,R5
        ADDEQ   R8,R8,#ApplicationStart
        BEQ     %FT04
        LDR     R0,[R6,#task_slotptr]
        MOV     R1,R8
        MOV     R8,R2
        STR     R1,tempworkspace        ; save domain offset for later mapping-out use of mapenoughslot
        STR     R10,tempworkspace+4     ; save length for later mapping-out use of mapenoughslot
        BL      mapenoughslot
        ADD     R8,R8,R0
04
        CMP     R9,R11
        BHS     %FT06
        TEQ     R3,R4
        ADDEQ   R9,R9,#ApplicationStart
        BEQ     %FT06
        LDR     R0,[R7,#task_slotptr]
        MOV     R1,R9
        MOV     R9,R2
        STR     R1,tempworkspace+8      ; save domain offset for later mapping out use of mapenoughslot
        STR     R10,tempworkspace+12    ; save length for later mapping out ue of mapenoughslot
        BL      mapenoughslot           ; page in only whats required for the copy
        ADD     R9,R9,R0
06
;
; copy data in the correct order, in case source task = destination
;
        TST     R8,#3
        TSTEQ   R9,#3
        TSTEQ   R10,#3
        BEQ     wordcopy                ; word aligned, yipee!!!

        CMP     R8,R9
        BHS     %FT02
        ADD     R8,R8,R10
        ADD     R9,R9,R10
01
        LDRB    R14,[R8,#-1]!           ; descending copy if source < dest
        STRB    R14,[R9,#-1]!
        SUBS    R10,R10,#1
        BNE     %BT01
        B       %FT03
02
        LDRB    R14,[R8],#1             ; ascending copy if source >= dest
        STRB    R14,[R9],#1
        SUBS    R10,R10,#1
        BNE     %BT02
03
        LDR     R2,taskhandle           ; page out the bits we paged in, unless CT
        TEQ     R2,R5
        BEQ     %FT05
        LDR     R0,[R6,#task_slotptr]
        CMP     R0,#-1
        LDRNE   R10,tempworkspace+4     ; saved length (0 if no mapping done)
        TEQNE   R10,#0
        LDRNE   R1,tempworkspace        ; saved domain offset
        MOVNE   R2,#-1                  ; map out
   Debug mjs4,"putative page out R0,R1,R2,R10",R0,R1,R2,R10
        BLNE    mapenoughslot
05
        LDR     R2,taskhandle           ; page out the bits we paged in, unless CT
        TEQ     R2,R4
        BEQ     %FT10
        LDR     R0,[R7,#task_slotptr]
        CMP     R0,#-1
        LDRNE   R10,tempworkspace+12    ; saved length (0 if no mapping done)
        TEQNE   R10,#0
        LDRNE   R1,tempworkspace+8      ; saved domain offset
        MOVNE   R2,#-1                  ; map out
   Debug mjs4,"putative page out R0,R1,R2,R10",R0,R1,R2,R10
        BLNE    mapenoughslot
10
        B       ExitWimp

wordcopy
        CMP     R8,R9
        BHS     %FT02
        ADD     R8,R8,R10
        ADD     R9,R9,R10
01
        LDR     R14,[R8,#-4]!           ; descending copy if source < dest
        STR     R14,[R9,#-4]!
        SUBS    R10,R10,#4
        BNE     %BT01
        B       %BT03
02
        LDR     R14,[R8],#4             ; ascending copy if source >= dest
        STR     R14,[R9],#4
        SUBS    R10,R10,#4
        BNE     %BT02
        B       %BT03

; maps only the pages that are required for the copy to address R2, slot R0, length R10
; domain offset R1, note that R2 = -1 means map out
;
; exit: R0 is offset from page boundary, R2 (if not -1) updated to next mappable address

mapenoughslot
        Push    "R0-R1,R3-R5,LR"

   Debug mjs4,">mapenoughslot",R0,R1,R2,R10

        LDR     R4,pagesize
        SUB     R4,R4,#1

        AND     R5,R1,R4         ;offset from page
        STR     R5,[SP]          ;R0 on return
        ADD     R5,R5,R10
        ADD     R5,R5,R4
        BIC     R5,R5,R4         ;no. of pages required x pagesize
        MOV     R5,R5,LSR #12    ;no. of (4k) pages

        BIC     R1,R1,R4         ;start of map (page boundary)

        MOV     R3,R1,LSR #12    ;offset in (4k) pages to start of map
        MOV     R1,R2            ;start address
        MOV     R2,R0            ;handle
        MOV     R0,#3
        ORR     R0,R0,#&100      ;reason code 3, plus bit 8 set (mapsome)
        MOV     R4,R5            ;no. of pages to map
        SWI     XOS_AMBControl
        BVS     err_badtransfer2

        CMP     R1,#-1
        MOVEQ   R2,R1
        ADDNE   R2,R1,R4,LSL #12 ;R2 return
   Debug mjs4," <mapenoughslot",R2

        Pull    "R0-R1,R3-R5,PC"

err_badtransfer2
        MyXError        WimpBadSlot
        B               medusa_exit_trb2         ; task handle no longer on stack
        MakeErrorBlock  WimpBadSlot

err_badtransfer
        MyXError  WimpBadTransfer
        B         medusa_exit_trb
        MakeErrorBlock WimpBadTransfer


;
; free pool set up on entry (unless application memory is already in use)
;   order of pages in the free pool is unimportant
;
; Read in table of all OS pages
; work out which ones are in application space
; put them into free pool list
;
; Data structures:
; slot table:  list of 3-word entries (as passed to OS_ReadMemMapEntries)
; free pool:   list of 3-word entries (enough room for all pages in machine)
;              pages are used as in a LIFO stack, with lower addresses last
;
; Exit:  if application space used, [freepool] = -1
;                              else [freepool] --> free pool block
;

findpages       ROUT
        Push    "R1-R11,LR"
;
        MOV     R14,#nullptr
        STR     R14,freepool            ; lock application memory
        LDR     R14,taskhandle
        STR     R14,inithandle          ; this task slot "owns" the memory
;
        SWI     XOS_ReadMemMapInfo      ; R0 = page size, R1 = no of pages
        Pull    "R1-R11,PC",VS
        STR     R0,pagesize
        STR     R1,npages               ; used later
;
; under the Medusa kernel, try and shrink app space by as much as possible

        MOV     R0,#6                   ; free pool
        MOV     R1,#&3FFFFFFF           ; try and shrink app space
        SWI     XOS_ChangeDynamicArea
; this sets up memory limit/ app space size as well
        MOV     R0,#-1
        SWI     XOS_ReadDynamicArea
        ADDVC   R5,R0,R2
        STRVC   R5,orig_applicationspacesize
        STRVC   R5,appspacesize

        CLRV

        Pull    "R1-R11,PC"
;01
;
;;
;; if application space in use, we can't construct a free pool
;; but we must still read orig_memorylimit and orig_applicationspacesize
;;
;
;        MOV     R0,#ApplicationSpaceSize
;        MOV     R1,#0
;        SWI     XOS_ChangeEnvironment
;        MOVVC   R3,R1                           ; R3 --> real end of memory
;        STRVC   R3,orig_applicationspacesize
;;
;        MOVVC   R0,#MemoryLimit
;        MOVVC   R1,#0
;        SWIVC   XOS_ChangeEnvironment
;        STRVC   R1,orig_memorylimit
;;
;;
;        TEQ     R1,R3                   ; preserves V
;        Pull    "R1-R11,PC",NE          ; these must be equal on entry
;;
;        BLVC    testapplication         ; CC ==> space is in use
;        Pull    "R1-R11,PC",VS
;        Pull    "R1-R11,PC",CC          ; we'll get back to this later if used
;
;;
;; allocate a "free pool" block, with 12 bytes per page
;;
;        LDR     R3,npages
;        MOV     R3,R3,LSL #2            ; multiply by 12
;        ADD     R3,R3,R3,LSL #1
;        ADD     R3,R3,#4                ; leave room for terminator
;        BL      claimblock
;        STRVC   R2,freepool
;;
;; construct free pool array by calling OS_FindMemMapEntries
;;
;        MOVVC   R1,#ApplicationStart
;        STRVC   R1,freepoolbase         ; base address of free pages
;
;        LDRVC   R1,orig_applicationspacesize
;        BLVC    findfreepool
;        MOVVC   R1,#2                   ; protect against USR mode access
;        BLVC    setslotaccess
;;
;; I don't know what this is doing here!
;;
;        MOVVC   R14,#0
;        STRVCB  R14,memoryOK            ; it's had it by now anyway!
;;
;; now protect all these pages, keeping them just below orig_memlimit
;; and set MemoryLimit small
;;
;        MOVVC   R1,#ApplicationStart
;        BLVC    setmemsize              ; sets ACTUAL handlers (current task)
;;
;        LDRVC   R0,freepool
;        SWIVC   XOS_SetMemMapEntries
;
;        Pull    "R1-R11,PC"


; In    R1 = application space size (one after end of free pool)
;       R2 -> free pool page table
;       [freepoolbase] = start of free pool
; Out   free pool table filled in (lowest address last in list)
;       [freepoolbase] updated if less than application space size
;       [freepoolpages] set up


findfreepool    ROUT
        Push    "R1-R5,LR"


        LDR     R3,freepoolbase
        CMP     R3,R1
        MOVHI   R3,R1
        STRHI   R3,freepoolbase

        MOV     R4,#0                   ; R4 = no of pages so far
        MOV     R0,#0                   ; R0 = probable page no (don't know)
        LDR     R5,pagesize
01      SUB     R1,R1,R5                ; R1 = address of next page
        CMP     R1,R3
        STMHSIA R2!,{R0,R1,R14}         ; page no, address, access (undefined)
        ADDHS   R4,R4,#1
        BHS     %BT01
        STR     R4,freepoolpages
        MOV     R14,#-1
        STR     R14,[R2]                ; terminator

        LDR     R0,[sp,#1*4]
        SWI     XOS_FindMemMapEntries   ; find relevent pages

        Pull    "R1-R5,PC"

; In    R1 = page protection level required
;       R2 -> slot block
; Out   page protection level set, array updated
;       R0 corrupted

setslotaccess   ROUT
        Push    "R2,LR"

01      LDR     R14,[R2],#12            ; unless terminator,
        CMP     R14,#0
        STRGE   R1,[R2,#-4]             ; fill in access field
        BGE     %BT01

        LDR     R0,[sp]
        SWI     XOS_SetMemMapEntries

        Pull    "R2,PC"

;
; testapplication
; works out whether application space is in use
; Entry: [orig_memorylimit] = upper bound of memory used by application
;                             if &8000, then application space is not in use
; Exit:  CC ==> memory in use
;
; Method:
;    1. If CAO pointer < MemoryLimit, then application memory is in use.
;    2. If MemoryLimit < ApplicationSpaceSize, then memory (probably) in use.
;       (catches situations where CAO isn't set, e.g. when *WimpTask creates a
;        temp task and so CAO == our module)
;    3. Issue Service_Memory: R0 = large - if anyone objects, memory is in use
;

ApplicationStart  *  &8000
IsAnybodyThere    *  -64*&100000        ; large negative number
                                        ; NB: this number is checked for by ShellCLI
testapplication ROUT
        Push    "R1-R4,LR"
;
        LDR     R1,orig_applicationspacesize    ; watch out for Twin etc!
        BL      readCAOpointer                  ; use OS_ChangeEnvironment
        CMP     R2,R1                           ; below memorylimit?
        Pull    "R1-R4,PC",CC
;
        MOV     R0,#ApplicationSpaceSize
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        MOV     R4,R1
        MOV     R0,#MemoryLimit
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        CMP     R1,R4
        Pull    "R1-R4,PC",CC           ; MemoryLimit < ApplicationSpaceSize
;
  Debug mjs3,"testapplication routine issueing Service_Memory"
        MOV     R1,#Service_Memory
      [ false
        MOV     R0,#IsAnybodyThere      ; 64 megabytes should be enough!
      |
        ; Oh no it isn't!
        TEQ     PC,PC                   ; don't want yet another build option if we can avoid it
        MOVNE   R0,#IsAnybodyThere      ; on 26-bit machines, use 64 megs for compatibility
        MOVEQ   R0,#1:SHL:31            ; on 32-bit machines, use most negative possible number
      ]
        SWI     XOS_ServiceCall
        CMPVC   R1,#1                   ; CC ==> service was claimed
;
        Pull    "R1-R4,PC"


; Out   R2 = CAO pointer (read using OS_ChangeEnvironment)

readCAOpointer  ROUT
        Push    "R0-R3,LR"

        MOV     R0,#CAOPointer
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        STR     R1,[sp,#2*4]

        Pull    "R0-R3,PC"              ; assume no errors

;
; restorepages
; put back the free pool when the last task dies - do not disturb current stuff
; Entry:  all tasks dead
;         use OS_ChangeEnvironment to set/read end of application memory
;         free pool block indicates remaining spare pages
; Exit:   all pages replaced in application space
;         memorylimit increased if appropriate
;         free pool block released
;

restorepages    ROUT
        Push    "R1-R7,LR"
;
        BL      deletependingtask       ; not interested in this task

        MOV     R4,#&C0000000           ; shrink freepool as much as we can
        BL      SafeChangeDynamic
        Pull    "R1-R7,PC"
;                                       ; just add to the pages present
        LDR     R6,freepool
        CMP     R6,#nullptr2
        BHS     go_restorememlimit      ; NB: orig_ values MUST BE CORRECT!
;
        MOV     R0,#MemoryLimit
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment   ; R1 = current memory limit
;
; free pool is already in the right place - just set access bits to 0
;
        LDR     R2,freepool
        MOV     R1,#0                   ; 0 => USR mode read/write access
        BL      setslotaccess           ; R2 -> free pool still

        MOV     R14,#nullptr2           ; application space NOT in use by Wimp
        STR     R14,freepool            ; NB only applies if not used on entry
        MOV     R0,#ModHandReason_Free
        BL     XROS_Module              ; ignore errors from here

go_restorememlimit
        BL      restorememlimit
;
        Pull    "R1-R7,PC"

restorememlimit ROUT
        EntryS
        MOV     R0,#MemoryLimit
        LDR     R1,orig_memorylimit
        SWI     XOS_ChangeEnvironment
        MOV     R0,#ApplicationSpaceSize
        LDR     R1,orig_applicationspacesize
        SWI     XOS_ChangeEnvironment
        EXITS                           ; must preserve flags

;
; allocateslot
; take pages from the free pool, and construct a page array block
; Entry:  [taskhandle] = current task
;         [slotsize] = max no of pages to use in new slot
; Exit:   taskhandle->task_slotptr --> block (suitable for OS_SetMemMapEntries)
;         pages transferred from the free pool to the slot
;         [freepoolbase] updated
;         slot size = 0 if no free pool (ie. all used up)
;         MemoryLimit updated to reflect the amount of memory available
;
allocateslot    ROUT
       Push    "R0-R4,LR"
       LDR     R1,slotsize ;no. of pages
    Debug mjs2,"allocateslot",R1
       MOV     R0,#0       ;reason code 0 (allocate)
       SWI     XOS_AMBControl
       BVC     %FT01
       BL      setdefaulthandlers
       Pull    "R0-R4,PC"
01
       CMP     R2,#0
       MOVEQ   R2,#nullptr
    Debug mjs2,"  allocateslot pages,slotptr",R1,R2
       LDR     R1,taskhandle
       LDR     R1,[wsptr,R1]
       STR     R2,[R1,#task_slotptr]
       Pull    "R0-R4,PC"


;
; Entry:  R2 --> slot block
;         R5 = number of pages required
; Exit:   R1 = amount of memory transferred
;         slot block, [freepoolbase], free pool sp updated
;         pages are not actually mapped in yet, and addresses are un-initialised
;

mapfromfreepool ROUT
        Push    "R2-R7,LR"
;
        LDR     R7,freepoolpages        ; R7 = number of pages in free pool
        SUB     R14,R7,R5
        STR     R14,freepoolpages       ; update [freepoolpages]

        ADD     R7,R7,R7,LSL #1
        LDR     R14,freepool
        ADD     R7,R14,R7,LSL #2        ; R7 -> terminator of free pool

        MOV     R4,#0                   ; R4 = page protection level (always 0)
01      SUBS    R5,R5,#1
        LDRPL   R0,[R7,#-12]!           ; R0 = page no
        STMPLIA R2!,{R0,R3,R4}          ; page no, address (uninit), access
        BPL     %BT01

        MOV     R14,#-1
        STR     R14,[R2]                ; slot block terminator
        STR     R14,[R7]                ; free pool terminator
;
; update [freepoolbase] and R1
;
        LDR     R0,pagesize             ; R0 = page size
        LDR     R5,[sp,#3*4]
        MUL     R1,R0,R5                ; R1 = amount of memory transferred
        LDR     R14,freepoolbase
        ADD     R14,R14,R1              ; update [freepoolbase]
        STR     R14,freepoolbase
;
        Pull    "R2-R7,PC"

;
; setmemsize
; sets up MemoryLimit and ApplicationSpaceSize for (polltaskhandle) task
; NB: these values apply to the CALLING task (so OS_ChangeEnvironment is used)
; Entry:  R1 = new memorylimit / applicationspacesize
; Exit:   OS_ChangeEnvironment used to change OS versions of these variables
;         if task is alive, its copies are also updated
;         R1 = old memorylimit
;

setmemsize      ROUT
        Push    "LR"
        MOV     R0,#ApplicationSpaceSize
        Push    "R1"
        SWI     XOS_ChangeEnvironment
        MOVVC   R0,#MemoryLimit
        Pull    "R1"
        SWIVC   XOS_ChangeEnvironment
        Pull    "PC"

;
; deallocateslot
; returns pages from a used slot to the free pool
; Entry:  [taskhandle] = current task
; Exit:   slot block deallocated (if any)
;         taskhandle->task_slotptr = null
;         pages put back into free pool (NB block never needs extension)
;
deallocateslot  ROUT
        Push    "R1-R2,LR"

   Debug mjs2,"deallocateslot"
        LDR     R14,taskhandle
        LDR     R1,[wsptr,R14]          ; R1 --> task block
        LDR     R2,[R1,#task_slotptr]

        CMP     R2,#nullptr
        MOVNE   R14,#nullptr
        STRNE   R14,[R1,#task_slotptr]
        BEQ     %FT03

        MOV     R0,#1       ;deallocpages reason code
        SWI     XOS_AMBControl
03
        CLRV
        Pull    "R1-R2,PC"

;
; Entry:  R2 --> slot block
; Exit:   pages mapped into free pool etc. (maptofreepool called)
;         slot block deallocated
;
deallocate      ROUT
        Push    "R0,LR"
        CMP     R2,#nullptr
        Pull    "R0,PC",EQ              ;return if invalid slot pointer

   Debug mjs2,"deallocate"

        MOV     R0,#1      ;deallocate reason code (not from App space)
        SWI     XOS_AMBControl
        STRVS   R0,[SP]
        Pull    "R0,PC"

;;
;; Entry:  R2 --> slot block
;; Exit:   pages mapped to base of free pool
;;         page numbers put into free pool (lowest page last)
;;         [freepoolbase] updated
;;
;
;maptofreepool   ROUT
;        Push    "R1-R7,LR"
;;
;        CMP     R2,#nullptr
;        Pull    "R1-R7,PC",EQ           ; no block!
;;
;
;        LDR     R6,freepool
;        LDR     R7,freepoolpages        ; R7 = number of pages in free pool
;        ADD     R6,R6,R7,LSL #2
;        ADD     R6,R6,R7,LSL #3         ; R6 -> terminators of free pool
;        MOV     R0,R6                   ; R0 -> block for OS_SetMemMapEntries
;
;        LDR     R1,pagesize
;        LDR     R4,freepoolbase         ; R4 -> next address
;        MOV     R5,#2                   ; R5 = protection level
;01      LDR     R3,[R2],#12             ; R3 = page number
;        CMP     R3,#nullptr
;        SUBNE   R4,R4,R1
;        STMNEIA R6!,{R3,R4,R5}          ; page number, address, protection level
;        ADDNE   R7,R7,#1
;        BNE     %BT01
;
;
;        STR     R4,freepoolbase
;        STR     R7,freepoolpages
;        MOV     R14,#-1
;        STR     R14,[R6]                ; terminator
;
;
;        SWI     XOS_SetMemMapEntries
;
;        Pull    "R1-R7,PC"              ; don't alter memorylimit

;
; mapslotin
; all pages in a slot are put into the application space (&8000)
; Entry:  [taskhandle] = current task
; Exit:   pages mapped in
;         handlers (eg. MemoryLimit) are also set up from task data
;

mapslotin       ROUT
        Push    "R1-R4,LR"
;
        LDR     R14,taskhandle
        LDR     R1,[wsptr,R14]          ; R1 --> task block
        CMP     R1,#0
        Pull    "R1-R4,PC",LE           ; task is dead (shouldn't happen)
;
        LDR     R0,[R1,#task_slotptr]
        CMP     R0,#nullptr             ; no slot allocated
        BLNE    mapin                   ; (corrupts R2)
;

        LDR     R14,taskhandle
        LDR     R4,[wsptr,R14]          ; NB task cannot be dead
        ADD     R4,R4,#task_environment
;
        LDR     R14,[R4,#12*ApplicationSpaceSize]
        SUB     R14,R14,#ApplicationStart
        STR     R14,appspacesize
;
        MOV     R0,#0                   ; handler number
01
        LDMIA   R4!,{R1-R3}             ; restore task handler data
        SWI     XOS_ChangeEnvironment
        ADD     R0,R0,#1
        CMP     R0,#MaxEnvNumber
        BCC     %BT01
;
        Pull    "R1-R4,PC"

;
; Entry:  R0 --> block suitable for passing to OS_SetMemMapEntries
; Exit:   the pages in the block are mapped into the application area
;
mapin   ROUT
        Push    "R0-R2,LR"
        MOV     R2,R0                ;handle
        MOV     R0,#3                ;reason code 3 (mapslot)
        MOV     R1,#ApplicationStart
        SWI     XOS_AMBControl
        STRVS   R0,[SP]
        Pull    "R0-R2,PC"

; Entry:  R0 --> page map block
;         R2 --> start address of place to map pages to
; Exit:   R2 --> after the memory

mapslot         ROUT
        Push    "R1,R3,LR"
;
        LDR     R3,pagesize
        MOV     R1,R0
01
        LDR     R14,[R1],#4
        CMP     R14,#0
        STRGE   R2,[R1],#8              ; next page
        ADDGE   R2,R2,R3
        BGE     %BT01
;
        SWI     XOS_SetMemMapEntries
;
        Pull    "R1,R3,PC"

;
; mapslotout
; all pages in a slot are put out of the way
; Entry:  [taskhandle] = current task
; Exit:   pages mapped out
;

mapslotout      ROUT
        Push    "R1-R6,LR"
;
        LDR     R14,taskhandle
        LDR     R6,[wsptr,R14]          ; R6 --> task block
        CMP     R6,#0
        Pull    "R1-R6,PC",LE           ; task is dead already
;
;
        ADD     R5,R6,#task_environment
        MOV     R0,#0
01
        TEQ     R0,#EscapeHandler       ; we must replace these now,
        TEQNE   R0,#EventHandler        ; since they are dangerous!
        TEQNE   R0,#UpCallHandler
        MOVNE   R1,#0
        MOVNE   R2,#0
        MOVNE   R3,#0
        SWIEQ   XOS_ReadDefaultHandler  ; replace with 'kosher' handlers
        SWI     XOS_ChangeEnvironment   ; set, and read original settings
        STMIA   R5!,{R1-R3}             ; old data
        ADD     R0,R0,#1
        CMP     R0,#MaxEnvNumber
        BCC     %BT01
;
        LDR     R0,[R6,#task_slotptr]
        CMP     R0,#nullptr             ; R0 --> slot block
        BLNE    mapout                  ; NB do this afterwards!
;
        Pull    "R1-R6,PC"

;
; Entry:  R0 --> block suitable for passing to OS_SetMemMapEntries
; Exit:   all pages referenced in the block are mapped out of the way
;
mapout  ROUT
        Push    "R0-R2,LR"
        MOV     R2,R0                ;handle
        MOV     R0,#3                ;reason code 3 (mapslot)
        MOV     R1,#-1               ;map out
        SWI     XOS_AMBControl
        STRVS   R0,[SP]
        Pull    "R0-R2,PC"


;;----------------------------------------------------------------------------
;; *WimpSlot command (for changing amount of application space)
;;----------------------------------------------------------------------------

                ^       0
vec_min         #       4               ; fields in output vector
vec_max         #       4
vec_next        #       4

ss_outputvec    *       &100


Keydef  DCB     "min,max,next", 0       ; -min no longer compulsory
        ALIGN

WimpSlot_Code   ROUT
        Push    "R11,R12,LR"
        LDR     wsptr,[R12]
        MOV     R11,sp                  ; remember stack for later
;
        SUB     sp,sp,#ss_outputvec     ; local workspace
;
; scan the comand line by calling OS_ReadArgs
;
        MOV     R1,R0                   ; R1 = input string
        ADR     R0,Keydef               ; R0 = key definition string
        MOV     R2,sp                   ; R2 = output vector
        MOV     R3,#ss_outputvec        ; R3 = max output vector length
        SWI     XOS_ReadArgs
        BVS     %FT99
;
; scan the resulting vector for known fields
;
        MOV     R0,#MemoryLimit
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        SUB     R3,R1,#ApplicationStart ; R3 = current amount of memory
;
        LDR     R1,[sp,#vec_min]
        CMP     R1,#0
        BEQ     %FT01
        BL      getminmax               ; R0 = min memory
        BVS     %FT99
        CMP     R0,R3
        BLS     %FT01
;
        Push    "R0"                    ; R0 = new current slot size
        MOV     R1,#-1                  ; leave next slot alone
        SWI     XWimp_SlotSize
        Pull    "R1"
        BVS     %FT99
        CMP     R0,R1                   ; R0=actual size, R1=required size
        BLO     err_notenoughmemory
        MOV     R3,R0                   ; R3 = new amount of memory
01
        LDR     R1,[sp,#vec_max]
        CMP     R1,#0
        BEQ     %FT02
        BL      getminmax               ; R0 = max memory
        BVS     %FT99
        CMP     R0,R3
        MOVLO   R1,#-1                  ; leave next slot alone
        SWILO   XWimp_SlotSize
02
        LDR     R1,[sp,#vec_next]
        CMP     R1,#0
        BEQ     %FT99
        BL      getminmax               ; R0 = new next slot size
        MOVVC   R1,R0
        MOVVC   R0,#-1                  ; leave current slot alone
        SWIVC   XWimp_SlotSize
99
        MOV     sp,R11
        Pull    "R11,R12,PC"

err_notenoughmemory
        MOV     R0,R1,ASR #10           ; R0 = size in K
;
        SUB     SP,SP,#32               ; allocate buffer big enough
;
        MOV     R1,SP
        MOV     R2,#20
        SWI     XOS_BinaryToDecimal     ; convert to a string
        ADDVS   SP,SP,#32
        BVS     %BT99                   ; (exit if it errored)
;
        MOV     R0,#0
        STRB    R0,[R1,R2]              ; terminate the string
;
        Push    "R4,R5"
;
        MOV     R4,R1                   ; -> string to use
        MOV     R5,#0

        MOV     R3,#errordynamicsize-4
        ADRL    R2,errordynamic+4       ; -> buffer to fill in
        ADR     R0,errmem
        BL      LookupToken
;
        Pull    "R4,R5"
        ADD     SP,SP,#32               ; balance the stack
;
        ADRL    R0,errordynamic
        LDR     R1,=ErrorNumber_ChDynamNotAllMoved
        STR     R1,[R0]
;
        SETV
        B       %BT99                   ; exit having setup the error block

  [ STB
errmem  DCB     "ErrMemS",0             ; simple message
  |
errmem  DCB     "ErrMem",0              ; original one
  ]
        ALIGN

;
; Entry:  R1 --> string
; Exit:   R0 = parameter value (number)
; Errors: "Bad number"
;

getminmax       ROUT
        Push    "R1-R3,LR"
;
        MOV     R0,#10
        SWI     XOS_ReadUnsigned
        Pull    "R1-R3,PC",VS
;
        LDRB    R3,[R1]
        ASCII_UpperCase R3, R14
        TEQ     R3,#"K"                 ; if terminator is "K" or "k",
        ADDEQ   R1,R1,#1
        MOVEQ   R2,R2,LSL #10           ; multiply by 1024
        TEQ     R3,#"M"                 ; if terminator is "M" or "m",
        ADDEQ   R1,R1,#1
        MOVEQ   R2,R2,LSL #20           ; multiply by 1048576
        TEQ     R3,#"G"                 ; if terminator is "G" or "g",
        ADDEQ   R1,R1,#1
        MOVEQ   R2,R2,LSL #30           ; multiply by 1073741824
;
        LDRB    R14,[R1]                ; check terminator
        RSBS    R14,R14,#" "+1          ; ensure GT set if OK
        MyXError BadNumb,LE
;
        MOVVC   R0,R2                   ; R0 = answer
        Pull    "R1-R3,PC"
        MakeInternatErrorBlock BadNumb,,BadParm

  [ :LNOT: KernelLocksFreePool

;;----------------------------------------------------------------------------
;; Stuff to deal with OS_ChangeDynamicArea
;;----------------------------------------------------------------------------

;
; intercept OS_ChangeDynamicArea
;

initdynamic     ROUT
        Push    "R1-R4,LR"
;
        ADR     R0,RAM_SWIEntry
        LDR     R1,copyofRAMcode+0
        LDR     R2,copyofRAMcode+4
        ADR     R3,My_ChangeDynamic
        LDR     R14,=SvcTable + 4 * OS_ChangeDynamicArea
        LDR     R4,[R14]                        ; R4 = old SWI entry
        TEQ     R4,R0
        Pull    "R1-R4,PC",EQ             ; if already in, forget it!

        STMIA R0,{R1-R4}
        STR   R0,[R14]                        ; R0 = RAM_SWIEntry
;
    ;StrongARM
    ;synchronise with respect to modified code at RAM_SWIEntry
        MOV     R1,R0                           ; start address
        ADD     R2,R1,#4                        ; end address (inclusive) for 2 words (other 2 are addresses)
        MOV     R0,#1                           ; means R1,R2 specify range
        SWI     XOS_SynchroniseCodeAreas        ; do the necessary

        Pull    "R1-R4,PC"

copyofRAMcode
        SUB     R12,PC,#:INDEX:RAM_SWIEntry+8
        LDR     PC,[PC,#-4]
        ASSERT  (.-copyofRAMcode = 8)
        ASSERT  (OScopy_ChangeDynamic-RAM_SWIEntry = 12)

resetdynamic    ROUT

        Push    "R1,LR"
;
        LDR     R1,=SvcTable + 4 * OS_ChangeDynamicArea
        LDR     R14,OScopy_ChangeDynamic
        STR     R14,[R1]
;
        Pull    "R1,PC"
        LTORG


;----------------------------------------------------------------------------
; OS_ChangeDynamicArea
; Entry:  R0 = area to move (0=system heap, 1=RMA, 2=screen)
;         R1 = amount to move (+ve ==> take away from application space)
; Exit:   R1 = amount actually moved
; Errors: not all bytes moved (0 moved if R1 was +ve)
;
;  if freepool < 0 or CAO pointer <> Wimp,
;  then just pass it on
;  else if not enough free pool memory, grab some from current slot
;       map all pages into the application space
;       reset ApplicationSpaceSize/MemoryLimit to their original values
;       branch to the OS code
;-----------------------------------------------------------------------------

        LTORG

My_ChangeDynamic  ROUT
        Push    "R0-R5,LR"
        ADRL    R14,freepoolinuse
        LDRB    R2,[R14]
        TEQ     R2,#0
        BEQ     goto_osentry
; free pool is in use by WCF, must trap with 'memory cannot be moved'
        MOV     R1,#0
        ADD     SP,SP,#8
        MyXError ChDynamNotAllMoved

        Pull    "R2-R5,lr"
        ORR     lr,lr,#V_bit
        LDR     PC,=BranchToSWIExit

goto_osentry
        Pull    "R0-R5,LR"
        LDR     PC,OScopy_ChangeDynamic

  ] ; :LNOT: KernelLocksFreePool

        MakeInternatErrorBlock ChDynamNotAllMoved,,ErrNoMv
        LTORG

        END
