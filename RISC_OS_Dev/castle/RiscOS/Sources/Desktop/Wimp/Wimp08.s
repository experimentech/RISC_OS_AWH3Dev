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
; > s.Wimp08


; ***** WARNING *****
;
; This file contains old code, which is retained only for compiling Wimps to
; run on old kernels (before RO 3.70). The code contains some known bugs
; (eg. Wimp_TransferBlock).
;
; s.Wimp08s contains the current code, which is much more efficient and
; cleaner for task memory management. This works with all ARMs supported by
; the current kernel. It is *not* just for StrongARM, despite previous comments
; made here.
;
; UseAMBControl should be {TRUE} (to use current code), except when compiling
; to run on old kernels.
;
; Any bug fixes *must* be made in s.Wimp08s (and are probably not worth
; replicating here).
;
; mjs
;


 [ :LNOT: KernelLocksFreePool
; These magic addresses are no longer in the PublicWS header - indeed, they are
; no longer fixed addresses since Tungsten. Fortunately, the relevant code was
; moved to the kernel in Ursula, so for all OSes that need them, the addresses
; can be considered to be constant.
                    ^ &01F033FC
SvcTable            #      &400

                    ^ &01F037FC
BranchToSWIExit     #         4           ; from SWI despatcher
 ]


        GBLS    LoadWimp08s

 [ UseAMBControl

LoadWimp08s SETS "GET s.Wimp08s"

 |

LoadWimp08s SETS ""

    ! 0, ""
    ! 0, "********* Building old variant of Wimp (UseAMBControl {FALSE})"
    ! 0, "*WARNING* This is only sensible for Wimps running on old kernels"
    ! 0, "********* (before RISC OS 3.70). Old variant is slow and buggy."
    ! 0, ""

 ]

        $LoadWimp08s

;;----------------------------------------------------------------------------
;; Switcher routines
;;----------------------------------------------------------------------------

; THIS FILE IS SUPERSEDED BY s.Wimp08s

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
; servicememory         accept/refuse to allow memory to be moved
; servicememorymoved    unstack the applications and recover!
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
; Entry:  R0 = new 'current' slot size in bytes (-1 ==> no change)
;         R1 = new 'next' slot size in bytes (-1 ==> no change)
; Exit:   R0 = actual 'current' slot size
;         R1 = actual 'next' slot size
;         R2 = total amount of free memory 'owned' by the Wimp
;              if R2 < R1, the next slot will not be allocated in full
;              when no tasks are running, R2 will be 0
;         if R0>=0 on entry, pages may be remapped and MemoryLimit changed


      [ :LNOT: UseAMBControl

SWIWimp_SlotSize  ROUT
        MyEntry "SlotSize"
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
        DivRem  R3,R2,R0, R14
        STR     R3,slotsize             ; [slotsize] = no of pages
01
        LDR     R2,orig_applicationspacesize
        LDR     R14,freepoolbase
        SUB     R2,R2,R14               ; R2 = total free memory
        [ Medusa
        Push    "R0-R1"
         [ ShrinkableAreas
        Push    r3                      ; get round r3 corruption for now
        MOV     r0, #5
        MOV     r1, #-1
        SWI     XOS_DynamicArea
        Pull    r3
         |
        MOV     R0,#6
        SWI     XOS_ReadDynamicArea     ; memory in free pool
        MOV     R2,R1
         ]
        Pull    "R0-r1"
        ]
        MUL     R1,R3,R0                ; R1 = next slot size

        [ false                         ; MED-00946
        CMP     R1,R2
        MOVGT   R1,R2                   ; can't be more memory in next than freepool
        ]

        STMIA   sp,{R1,R2}              ; ensure calling task gets new values
;
; transfer pages between current slot and free pool
; on exit R0 = actual current slot size (whether or not memory could be moved)
;
        CMP     R4,#-1                  ; R4 = proposed new current slot size
; under Medusa [freepool] has no meaning
        BEQ     returnmemsize
        [ :LNOT:Medusa
        LDR     R14,freepool
        CMP     R14,#0
        BLT     returnmemsize
        ]

;
        MOV     R0,#ApplicationSpaceSize
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        MOV     R3,R1                   ; R3 --> end of current slot
        MOV     R0,#MemoryLimit
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        TEQ     R1,R3
        BNE     returnmemsize           ; fixed - memory cannot be paged
;
        LDR     R0,pagesize             ; R0 = page size
        SUB     R14,R0,#1
        ADD     R4,R4,R14
        BIC     R4,R4,R14               ; round up to nearest page boundary
        SUB     R4,R3,R4
        SUB     R4,R4,#ApplicationStart ; R4 = amount to transfer into pool
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
        STRVC   R2,[R5,#task_slotptr]
        BVS     ExitWimp                ; exit if unable to claim block
;
        LDR     R0,pagesize             ; R0 = page size
        MOV     R1,#0
01
        LDR     R14,[R2],#12
        CMP     R14,#0
        ADDGE   R1,R1,R0                ; R1 = total amount of memory in slot
        BGE     %BT01
        SUB     R2,R2,#12               ; R2 --> terminator of slot block
;
        CMP     R4,#0
        BEQ     returnmemsize           ; don't bother with message if same size

        [ Medusa
        Push    "R0-R3"
; there may be more memory in the slot than memory limit, app space suggest.
        ADD     R1,R1,#ApplicationStart
        MOV     R0,#0
        Push    "R1"
        SWI     XOS_ChangeEnvironment
        Pull    "R1"
        MOV     R0,#14
        SWI     XOS_ChangeEnvironment

; if running under Medusa then the CAO needs to be moved to the module area, otherwise
; the CDA call will fail.
        MOV     R0,#15
        MOV     R1,#&08000000
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
        Pull    "R1"
        CMP     R1,#0
        Pull    "R0-R3",EQ
        BEQ     returnmemsize           ; no change
        CMP     R4,#0                   ; sets conditionals for below
        MOV     R4,R1
        Pull    "R0-R3"
        B       %FT04
03
        MOV     R0,#6                   ; freepool
        MOV     R1,R4                   ; number of bytes to alter free pool by
        SWI     OS_ChangeDynamicArea
        CMP     R1,#0
        Pull    "R0-R3",EQ
        BEQ     returnmemsize           ; no change
        CMP     R4,#0                   ; sets conditionals for below
        MOV     R4,R1
        Pull    "R0-R3"
04
        |
        RSBLT   R4,R4,#0
; R4 now positive, flags reflect actual change
        ]
        BLT     growapp
;
; shrink application space by R4 bytes (already a whole number of pages)
;
shrinkapp
        CMP     R4,R1                   ; always move as much as possible
        MOVGT   R4,R1
;
        MOV     R3,R2                   ; R3 --> terminator
;
        CMP     R4,#0
01
        SUBGT   R2,R2,#12
        SUBGT   R1,R1,R0                ; used later for OS_ChangeEnvironment
        SUBGTS  R4,R4,R0
        BGT     %BT01
;
        [ :LNOT:Medusa
	BL	maptofreepool
        ]

        MOV     R14,#-1
        STR     R14,[R2]                ; terminator
;
        LDR     R14,[R5,#task_slotptr]
        CMP     R2,R14
        BHS     %FT01
;
        MOV     R2,R14                  ; if null block, delete it!
        MOV     R0,#ModHandReason_Free
        BL     XROS_Module
        MOV     R2,#nullptr
        B       %FT02
01
        SUB     R3,R2,R3                ; R3 = amount to change block by (-ve)
        MOV     R0,#ModHandReason_ExtendBlock
        LDR     R2,[R5,#task_slotptr]
        BL     XROS_Module
02
        STRVC   R2,[R5,#task_slotptr]
        [ Medusa
        MOV     R5,R1                           ; used in the switcher message
        B       sendmemmessage

; SafeChangeDynamic
; if running under Medusa then the CAO needs to be moved high, otherwise
; the CDA call will fail.
; Entry : R4 number of bytes to move (signed), R0-R3 possibly corrupt
; Exit  : R1 number of bytes actually moved (unsigned)
SafeChangeDynamic
        Push    "lr"
        MOV     R0,#15
        MOV     R1,#&08000000
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
; grow an app under the medusa kernel
; R4 is byte change, R2 is slot terminator, R0 page size, R5 task pointer, R1 is slot size
;

growapp
        TEQ     R4,#0
        BEQ     returnmemsize                   ; this takes account of the case where the
                                                ; slot cannot grow due to memory constraints.
        Push    "R0,R1,R4"
        MOV     R3,#0
01
        ADD     R3,R3,#12
        SUBS    R4,R4,R0
        BNE     %BT01
; need to extend slot ptr by R3
        LDR     R2,[R5,#task_slotptr]
        MOV     R0,#ModHandReason_ExtendBlock
        BL      XROS_Module
        BVC     %FT03
; oh, dear we need to shrink the app by one page size and try again
        MOV     R0,#6
        LDR     R1,[SP]
        Push    "R0-R4"
        MOV     R4,R1
        BL      SafeChangeDynamic
        Pull    "R0-R4"
;        SWI     XOS_ChangeDynamicArea

; alert alert, something quite awful has happened
; you know, i used to wonder what sort of bozzos put comments in like these, now
; i understand...
        ADDVS   SP,SP,#12               ; skip rubbish
        BVS     ExitWimp
        Pull    "R0,R1,R4"
        SUB     R4,R4,R0
        B       growapp                 ; try again with smaller slot.

03
        STR     R2,[R5,#task_slotptr]
        Pull    "R0,R1,R4"
        MOV     R3,#ApplicationStart
        Push    "R4"
        MOV     R4,R1
        LDR     R0,pagesize
        MOV     R1,#0
; first R1 bytes (original slot) probably have the correct page number
        CMP     R4,#0
        BEQ     %FT06
05
        ADD     R2,R2,#4
        STR     R3,[R2],#8                      ; address
        ADD     R3,R3,R0
        SUBS    R4,R4,R0
        BNE     %BT05
06
; next R4 bytes are new and so we have no idea what page number they are, set them to zero.
        Pull    "R4"
        CMP     R4,#0
        BEQ     %FT09
07
        Push    "R2"
08
        STR     R1,[R2],#4                      ; page no.
        STR     R3,[R2],#4                      ; address
        STR     R1,[R2],#4                      ; protection
        ADD     R3,R3,R0
        SUBS    R4,R4,R0
        BNE     %BT08
        MOV     R0,#-1
        STR     R0,[R2]

        Pull    "R0"
        SWI     XOS_FindMemMapEntries           ; only find entries for new pages

09

        SUB     R5,R3,#ApplicationStart          ; used in message to switcher
       | ; Medusa
	B	setcurslot


;
; grow application space by R4 bytes (already a whole number of pages)
;
growapp
        LDR     R3,orig_applicationspacesize
        LDR     R14,freepoolbase
        SUB     R3,R3,R14               ; R3 = amount of memory available
        CMP     R4,R3
;
        MOVGT   R4,R3                   ; max amount moveable
;
;
        Push    "R1,R2,R4"
;
        MOV     R3,#0
01
        SUBS    R4,R4,R0
        ADDGE   R3,R3,#12
        BGT     %BT01
;
        LDR     R2,[R5,#task_slotptr]
        MOV     R1,R2
        MOV     R0,#ModHandReason_ExtendBlock
        BL      XROS_Module
        STRVC   R2,[R5,#task_slotptr]
        SUBVC   R14,R2,R1               ; amount block has moved by
        MOVVC   R6,R2                   ; R6 --> new block
;
        Pull    "R1,R2,R4"
        BVS     ExitWimp                ; nothing updated yet, so just exit
;
        ADD     R2,R2,R14               ; R2 --> end of block (moved!)
;
        LDR     R3,orig_applicationspacesize  ; DO IT AGAIN!!!
        LDR     R14,freepoolbase              ; - may have changed !!!
        SUB     R3,R3,R14               ; R3 = amount of memory available
        CMP     R4,R3
        MOVGT   R4,R3                   ; max amount moveable
;
        LDR     R0,pagesize
        DivRem  R5,R4,R0, R14           ; R5 = number of pages to move
        MOV     R3,R1                   ; R3 = size of slot so far
        BL      mapfromfreepool         ; on exit R1 = memory transferred
;
        MOV     R0,R6                   ; R0 --> new slot block
        BL      mapin                   ; map in whole slot (corrupts R2)
;
        ADD     R1,R1,R3                ; R1 = total memory in new slot

setcurslot
        MOV     R5,R1                   ; R5 = current slot size (for later)
        ADD     R1,R1,#ApplicationStart
        BL      setmemsize              ; R1 = end of memory for slot
      ] ; Medusa
;
; send round a broadcast, to be picked up by the Switcher
; NB this can only be done if the task is alive (otherwise it has no handle)
;
sendmemmessage
        LDR     R14,taskhandle
        LDR     R14,[wsptr,R14]
        TST     R14,#task_unused
;
        ASSERT  ms_data=20
        MOVEQ   R0,#28                  ; 28 byte block
        MOVEQ   R3,#0                   ; your ref
        LDREQ   R4,=Message_SlotSize
        LDREQ   R6,[sp,#0*4]            ; next slot size (already on stack)
        Push    "R0-R6"
        MOVEQ   R0,#User_Message        ; don't bother getting reply
        MOVEQ   R1,sp
        MOVEQ   R2,#0                   ; broadcast
        BLEQ    int_sendmessage         ; fills in sender, myref
        ADD     sp,sp,#28

returnmemsize
        MOV     R0,#MemoryLimit         ; may not actually be full slot size
        MOV     R1,#0                   ; (eg. if Twin is running above)
        SWI     XOS_ChangeEnvironment
        SUBVC   R0,R1,#ApplicationStart ; R0 = actual slot size
        B       ExitWimp
        LTORG

getnullslot
        Push    "LR"
        MOV     R3,#4                   ; we need 2 terminators
        BL      claimblock
        MOVVC   R14,#-1                 ; terminator
        STRVC   R14,[R2]
        Pull    "PC"

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
 [ :LNOT: FreePoolWCF
wimpareastring
        DCB     "WDA",0                 ; SMC: add WDA:Wimp Dynamic Area to Wimp.Messages file.
 ]
        ALIGN

SWIWimp_ClaimFreeMemory  ROUT
        MyEntry "ClaimFreeMemory"
;
        [ Medusa
        [ :LNOT: FreePoolWCF
        MOV     R5,R1
        LDR     R1,wimparea
        ]
        CMP     R0,#0
        BNE     %FT01
; free
        [ FreePoolWCF
        MOV     R0,#0
        ADRL    R14,freepoolinuse
        STRB    R0,[R14]
        B       ExitWimp
        |
        MOV     R0,#1
        STRB    R0,memoryOK
        MOV     R0,R1
        MOV     R1,#-&8000000                   ; shrink area
        SWI     XOS_ChangeDynamicArea
        MOV     R0,#0
        STRB    R0,memoryOK
        CLRV
        B       ExitWimp
        ]
01
; claim
        [ FreePoolWCF
        ADRL    R4,freepoolinuse
        LDRB    R0,[R4]
        TEQ     R0,#0
        |
        MOV     R0,R1
        SWI     XOS_ReadDynamicArea
        TEQ     R1,#0
        ]
        MOVNE   R0,#0
        STRNE   R0,[SP]
        STRNE   R0,[SP,#4]
        BNE     ExitWimp                              ; already 'claimed'
        [ FreePoolWCF
        MOV     R5,R1                                   ; preserve the amount asked for
        MOV     R0,#6
        SWI     XOS_ReadDynamicArea
        MOVVS   R0,#0                                   ; Shouldn't happen
        MOVVS   R1,#0

        CMP     R5,R1                                   ; set HI if R5 <0 or R5>R1
        MOVHI   R0,#0
        MOVLS   R2,#1
        STRLSB  R2,[R4]                                 ; mark free pool in use

        STR     R0,[SP,#4]                              ; return values
        STR     R1,[SP]
        B       ExitWimp

        [ false

        CMP     R5,#0                                   ; asked for -ve amount
        CMPGE   R1,R5                                   ; not enough ?
        MOVLT   R3,R1
        MOVLT   R4,#0                                   ; no address as claim 'failed'
        BLT     %FT01
05
        CLRV
        MOV     R1,#1
        STRB    R1,[R4]                                ; mark free pool as in use
        MOV     R0,#6
        SWI     XOS_ReadDynamicArea
        MOVVS   R4,#0                                   ; shouldn't happen
        MOVVC   R3,R1
        MOVVC   R4,R0                                   ; start address of free pool
        B       %FT01
        ]

        |
        MOV     R1,#1
        STRB    R1,memoryOK
        MOV     R1,R5
        CMP     R1,#0
        SETV    LT
        LDRVC   R0,wimparea
        SWIVC   XOS_ChangeDynamicArea
        MOV     R4,#0
        STRB    R4,memoryOK
        MOVVS   R0,#6                           ; freepool, just size!!!
        LDRVC   R0,wimparea                     ; our area
        MOV     R2,#0
        CLRV
        SWI     XOS_ReadDynamicArea
        TEQ     R2,#0
        MOV     R3,R1
        MOVNE   R4,R0                           ; no start if claim failed
        CLRV

        B       %FT01
        ]
02
        ]

        TEQ     R0,#0
        LDRB    R5,memoryOK             ; always load R5
        BICEQ   R5,R5,#mem_claimed
        STREQB  R5,memoryOK
        BEQ     ExitWimp
;
        MOV     R3,#0                   ; R3=0  no memory available
        MOV     R4,#0                   ; R4=0  can't claim
;
        TEQ     R5,#0
        BNE     %FT01                   ; can't claim (nasty business going on)
;
        LDR     R14,freepool
        CMP     R14,#nullptr2
        BHS     %FT01                   ; can't claim (no free pool)
;
        LDR     R3,orig_applicationspacesize
        LDR     R4,freepoolbase
        SUB     R3,R3,R4                ; R3 = length available
;
        ADD     R14,R3,#1
        CMP     R1,R14                  ; C=1 ==> too long!
        MOVCS   R4,#0                   ; address = 0 if carry set
        ORRCC   R5,R5,#mem_claimed
        STRCCB  R5,memoryOK
01
        STMIA   sp,{R3,R4}              ; R1,R2 on return = length,addr
        B       ExitWimp

      [ Medusa
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
      ]
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

SWIWimp_TransferBlock  ROUT
        MyEntry "TransferBlock"
;
        Push    "R0-R4"
        MOV     R0,#MemoryLimit         ; force this field to be up-to-date
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        LDR     R14,taskhandle
        LDR     R14,[wsptr,R14]
        CMP     R14,#0
        STRGT   R1,[R14,#task_environment+12*MemoryLimit]
        [ Medusa
        LDMIA   SP,{R0-R4}                      ; leave them on the stack
        |
        Pull    "R0-R4"
        ]
;
        BL      validtask_alive
        MOVVC   R7,R6                   ; R7 --> dest task block
        MOVVC   R2,R0
        [ Medusa
        Push    "R5"
        ]
        BLVC    validtask_alive         ; R6 --> source task block
        BVC     %FT05
medusa_exit_trb
        [ Medusa
        ADD     SP,SP,#4                ; the push above was non-conditional
        ]
medusa_exit_trb2
        [ Medusa
        ADD     SP,SP,#20
        SETV                            ; want an error
        ]
        B       ExitWimp
;
05
        SUBS    R10,R4,#0               ; length must be >= 0
        BNE     %FT07                   ; ignore zero length now!
        [ Medusa
        ADD     SP,SP,#24
        ; no error so don't set V
        ]
        B       ExitWimp

07
        BLT     err_badtransfer
	CMP	R1,#ApplicationStart    ; buffer start >= &8000
	CMPHS	R3,#ApplicationStart
	BLO	err_badtransfer
        SUB     R8,R1,#ApplicationStart ; assuming app space...
        SUB     R9,R3,#ApplicationStart ; ... R8,R9 = offsets into domain
;
        [ Medusa :LAND: sixteenmeg
        MOV     R11,#16*1024*1024
        |
        LDR     R11,orig_applicationspacesize
        ]
;
        CMP     R1,R11                  ; not in application space?
        ADDHS   R8,R8,#ApplicationStart ; make absolute again
        BHS     %FT11
        LDR     R14,[R6,#task_environment+12*MemoryLimit]
        ADD     R0,R1,R4
        CMP     R0,R14
        BHI     err_badtransfer
11
        CMP     R3,R11                  ; not in application space?
        ADDHS   R9,R9,#ApplicationStart ; make absolute again
        BHS     %FT01
        LDR     R14,[R7,#task_environment+12*MemoryLimit]
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

        [ Medusa
; orignal calling values are still on the stack
        TEQ     R6,R7                   ; are the tasks the same?
        BEQ     %FT02
        CMP     R10,#7*1024*1024
        BLT     %FT02
; ok we're doing a BIG transfer, so split it up
        MOV     R10,#7*1024*1024        ; 7 meg, leave a bit of breathing space
	Push	"R1"			; save end-of-current-slot
        ADD     R0,SP,#8
        LDMIA   R0,{R0-R4}
        ADD     R1,R1,#7*1024*1024      ; we'll carry on but only do 7 megs worth
        ADD     R3,R3,#7*1024*1024      ; then recall the routine, but starting 7 meg
        SUB     R4,R4,#7*1024*1024      ; further on.
        SWI     XWimp_TransferBlock
	Pull	"R1"			; restore end-of-current-slot
; this will cycle through as many times as required
02
; now if the ammount to copy+ R1 > app space, or 2* copy if neither task is the current task
; then part or all of current task must be paged out.
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
        ADDLO   R0,R0,R10
        [ sixteenmeg
        CMP     R0,#16*1024*1024
        |
        LDR     R14,orig_applicationspacesize
        CMP     R0,R14
        ]
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
        Push    "R1"                    ; save task handle
        BL      mapslotout              ; map out CT
        MOV     R0,#0
        STR     R0,taskhandle
        ADD     R0,SP,#8
        LDMIA   R0,{R0-R4}
        SWI     XWimp_TransferBlock     ; do it again, only this time there is no current task
        Pull    "R1"
        STR     R1,taskhandle           ; return to how it all was
        BL      mapslotin
        ADD     SP,SP,#24
        B       ExitWimp

; this is potentially dodgy as the bit we want to map out of the way may actually be in
; the transfer range

onetask_currentr5
        TEQ     R5,R4
        BEQ     %FT03
        CMP     R8,R11                  ; we only need to woryy about space if the copy
                                        ; is actually in the tasks app space
        BLO     onetaskcurrent
        B       %FT03

onetask_currentr4
        TEQ     R5,R4
        BEQ     %FT03
        CMP     R9,R11

onetaskcurrent
        ADDLO   R0,R0,R10
        ADDLO   R0,R0,R2                ; just in case copy is over a page
        [ sixteenmeg
        CMP     R0,#16*1024*1024
        |
        LDR     R14,orig_applicationspacesize
        CMP     R0,R14
        ]

        BLO     %FT03
        B       makespacefromct


03
        MOV     R0,#ApplicationSpaceSize
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment   ; R1 --> end of current slot

        Pull    "R4"
        ADD     SP,SP,#20               ; will always be original values on stack
        MOV     R2,R1
        LDR     R3,taskhandle
        CMP     R8,R11                  ; do we need it paged in ?
        BHS     %FT04
        CMP     R3,R5
        ADDEQ   R8,R8,#ApplicationStart
        BEQ     %FT04
        LDR     R0,[R6,#task_slotptr]
        MOV     R1,R8
        MOV     R8,R2
        BL      mapenoughslot
        ADD     R8,R8,R0
04
        CMP     R9,R11
        BHS     %FT06
        CMP     R3,R4
        ADDEQ   R9,R9,#ApplicationStart
        BEQ     %FT06
        LDR     R0,[R7,#task_slotptr]
        MOV     R1,R9
        MOV     R9,R2
        BL      mapenoughslot           ; page in only whats required for the copy
        ADD     R9,R9,R0
06
        |
        BL      rackupslots             ; In: R1= bit; Out: trashes R0-R4
;
        CMP     R8,R11
        LDRLO   R14,[R6,#task_slotptr]  ; must be a slot here if address valid
        LDRLO   R14,[R14,#4]            ; get address of first page
        ADDLO   R8,R8,R14               ; R8 --> source buffer
;
        CMP     R9,R11
        LDRLO   R14,[R7,#task_slotptr]  ; must be a slot here if address valid
        LDRLO   R14,[R14,#4]            ; get address of first page
        ADDLO   R9,R9,R14               ; R9 --> destination buffer
        ]
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
        [ Medusa
        LDR     R2,taskhandle           ; page out the bits we paged in, unless CT
        CMP     R2,R5
        BEQ     %FT05
        LDR     R0,[R6,#task_slotptr]
        CMP     R0,#-1
        BLNE    mapout
05
        CMP     R2,R4
        BEQ     %FT10
        LDR     R0,[R7,#task_slotptr]
        CMP     R0,#-1
        BLNE    mapout
10
        |
        BL      unrackslots
        ]
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

        [ Medusa
mapenoughslot
; maps only the pages that are required for the copy to address R2, slot R0, length R10
; domain offset R1
        Push    "R0-R1,R3-R5,lr"
        LDR     R3,pagesize
        SUB     R3,R3,#1
        BIC     R1,R1,R3
        ADD     R3,R3,#1
; find start of block
01
        CMP     R1,#0
        BEQ     %FT05
02
        LDR     R14,[R0],#12
        CMP     R14,#0
        BLT     err_badtransfer2
        SUBS    R1,R1,R3
        BNE     %BT02
; R0 now points to start of slot that is involved in the copy
05
        MOV     R4,R0
        LDR     R1,[SP,#4]              ; domain offset again
        SUB     R5,R3,#1
        AND     R1,R1,R5                ; offset from page
        STR     R1,[SP]                 ; R0 on return
        ADD     R1,R1,R10
        ADD     R1,R1,R5
        BIC     R1,R1,R5                ; no. of pages required x pagesize
09
        LDR     R14,[R4],#12
        CMP     R14,#0
        BLT     err_badtransfer2
        SUBS    R1,R1,R3
        BNE     %BT09
        LDR     R5,[R4]                 ; temporarily shorten the slot block
        MOV     R14,#-1                 ; this way we don't need to make a new block
        STR     R14,[R4]                ; which may require memory we don't have.
        BL      mapslot
        STR     R5,[R4]                 ; put it back as it was
        Pull    "R0-R1,R3-R5,PC"

err_badtransfer2
        MyXError        WimpBadSlot
        B               medusa_exit_trb2         ; task handle no longer on stack
        MakeErrorBlock  WimpBadSlot

        ]

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

        [ Medusa
        MOV     R0,#6                   ; free pool
        MOV     R1,#&10000000           ; try and shrink app space
        SWI     XOS_ChangeDynamicArea
; this sets up memory limit/ app space size as well
        [ :LNOT: sixteenmeg
        MOV     R0,#-1
        SWI     XOS_ReadDynamicArea
        ADDVC   R5,R0,R2
        STRVC   R5,orig_applicationspacesize
         [ :LNOT: FreePoolWCF
; create dynamic area for Wimp_ClaimFreeMemory
        ADRL    R0,wimpareastring       ; Look up name for Wimp dynamic area.
        ADR     R2,errorbuffer          ; Use safe place for temporary string (copied by OS_DynamicArea).
        MOV     R3,#256
        BL      LookupToken1
        MOVVC   R8,R2
        ADRVSL  R8,wimpareastring       ; If look up fails then create something anyway.

        MOV     R0,#0
        LDR     R1,wimparea
        MOV     R2,#0
        MOV     R3,#-1
        MOV     R4,#128                 ; not dragable
        MOV     R5,#-1
        ADRL    R6,wimp_area_handler
        MOV     R7,R12
        SWI     XOS_DynamicArea
; ignore errors
         ]
        ]

        CLRV

        Pull    "R1-R11,PC"
01
        |
;
; if application space in use, we can't construct a free pool
; but we must still read orig_memorylimit and orig_applicationspacesize
;

        MOV     R0,#ApplicationSpaceSize
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        MOVVC   R3,R1                           ; R3 --> real end of memory
        STRVC   R3,orig_applicationspacesize
;
        MOVVC   R0,#MemoryLimit
        MOVVC   R1,#0
        SWIVC   XOS_ChangeEnvironment
        STRVC   R1,orig_memorylimit
;
;
        TEQ     R1,R3                   ; preserves V
        Pull    "R1-R11,PC",NE          ; these must be equal on entry
;
        BLVC    testapplication         ; CC ==> space is in use
        Pull    "R1-R11,PC",VS
        Pull    "R1-R11,PC",CC          ; we'll get back to this later if used

;
; allocate a "free pool" block, with 12 bytes per page
;
        LDR     R3,npages
        MOV     R3,R3,LSL #2            ; multiply by 12
        ADD     R3,R3,R3,LSL #1
        ADD     R3,R3,#4                ; leave room for terminator
        BL      claimblock
        STRVC   R2,freepool
;
; construct free pool array by calling OS_FindMemMapEntries
;
        MOVVC   R1,#ApplicationStart
        STRVC   R1,freepoolbase         ; base address of free pages

        LDRVC   R1,orig_applicationspacesize
        BLVC    findfreepool
        MOVVC   R1,#2                   ; protect against USR mode access
        BLVC    setslotaccess
;
; I don't know what this is doing here!
;
        MOVVC   R14,#0
        STRVCB  R14,memoryOK            ; it's had it by now anyway!
;
; now protect all these pages, keeping them just below orig_memlimit
; and set MemoryLimit small
;
        MOVVC   R1,#ApplicationStart
        BLVC    setmemsize              ; sets ACTUAL handlers (current task)
;
        LDRVC   R0,freepool
        SWIVC   XOS_SetMemMapEntries

        Pull    "R1-R11,PC"

        ]


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
;    2. Issue Service_Memory: R0 = large - if anyone objects, memory is in use
;

ApplicationStart  *  &8000
IsAnybodyThere    *  -64*&100000        ; large negative number
                                        ; NB: this number is checked for by ShellCLI
testapplication ROUT
        Push    "R1-R3,LR"
;
        [ Medusa :LAND: sixteenmeg
        MOV     R1,#16*1024*1024                ; boo hiss
        |
        LDR     R1,orig_applicationspacesize    ; watch out for Twin etc!
        ]
        BL      readCAOpointer                  ; use OS_ChangeEnvironment
        CMP     R2,R1                           ; below memorylimit?
        Pull    "R1-R3,PC",CC
;
        MOV     R1,#Service_Memory
        MOV     R0,#IsAnybodyThere      ; 64 megabytes should be enough!
        SWI     XOS_ServiceCall
        CMPVC   R1,#1                   ; CC ==> service was claimed
;
        Pull    "R1-R3,PC"


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

        [ Medusa
        MOV     R4,#-&10000000            ; shrink freepool as much as we can
        BL      SafeChangeDynamic
        Pull    "R1-R7,PC"
        ]
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
        [ Medusa
01
        Push    "R0-R4,lr"
        MOV     R0,#14
        MOV     R1,#ApplicationStart
        SWI     XOS_ChangeEnvironment
        MOV     R0,#0
        MOV     R1,#ApplicationStart
        SWI     XOS_ChangeEnvironment
        LDR     R0,slotsize
        LDR     R3,pagesize
        MUL     R1,R3,R0                ; usually R0 < R3
        MOV     R0,#6
        RSB     R1,R1,#0                ; shrinking free pool
        SWI     XOS_ChangeDynamicArea
        [ false
        MOVVS   R4,#0
        STRVS   R4,slotsize
        ]
;        ADDVS   SP,SP,#4
;        Pull    "R1-R4,PC",VS          sadly this may 'succeed' but return an error
        CLRV
        CMP     R1,#0
;        SETV    EQ
;hmmm no error block...
;       Pull    "R0-R4,PC",VS           ; couldn't allocate any memory
        BNE     %FT01
nomemoryinslot
        [ false
        MOV     R0,#0
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment
        MOV     R0,#14
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment   ; reset env
        ]
        BL      setdefaulthandlers
        Pull    "R0-R4,PC"
nomemoryinslot2
        MOV     R0,#15
        Pull    R1
        SWI     XOS_ChangeEnvironment   ; reset env
        Pull    "R0-R4,PC"
01
        Push    R1
        MOV     R0,#15
        MOV     R1,#ApplicationStart
        SWI     XOS_ChangeEnvironment   ; lower the cao so that claiming RMA doesn't lose pages
        Pull    R14
        Push    R1
        MOV     R1,R14

; R1 is actual allocation
        DivRem  R4,R1,R3,R14
        ADD     R4,R4,R4, LSL #1        ; x3
        MOV     R4,R4, LSL #2           ; x4
        ADD     R3,R4,#4
02
        TEQ     R3,#0
        BEQ     nomemoryinslot2
        MOV     R0,#ModHandReason_Claim
        BL      XROS_Module
; R2 is block or error
        BVC     %FT03
        [ false
        LDR     lr,pagesize
        MOV     R0,#6
        MOV     R1,lr

        SWI     XOS_ChangeDynamicArea   ; grow free pool by a page
        |
        Push    "R0-R4"
        LDR     R4,pagesize
        BL      SafeChangeDynamic
        Pull    "R0-R4"
        ]

        SUB     R3,R3,#12
        B       %BT02
03
        MOV     R0,#15
        Pull    R1
        Push    "R2-R3"
        SWI     XOS_ChangeEnvironment   ; reset cao
        Pull    "R2-R3"

        LDR     lr,pagesize             ; SWI will have corrupted this
        ADD     R4,R2,R3                ; end of block
        SUB     R4,R4,#4
        Push    "r2"
        MOV     R3,#ApplicationStart
        MOV     R0,#0
04
        STR     R0,[R2],#4
        STR     R3,[R2],#4
        STR     R0,[R2],#4              ; set protection level.
        ADD     R3,R3,lr
        CMP     R2,R4
        BLO     %BT04
        MOV     R0,#-1
        STR     R0,[R2]
        Pull    "R0"
        SWI     XOS_FindMemMapEntries
        LDRVC   R1,taskhandle
        LDRVC   R1,[wsptr,R1]
        STRVC   R0,[R1,#task_slotptr]
        STR     R0,[SP]                 ; just in case anything uses this

        Pull    "R0-R4,PC"

99
        ]

        Push    "R1-R7,LR"
;
        LDRB    R14,memoryOK            ; if free space in use, can't allocate
        TEQ     R14,#0
        MOVNE   R7,#0
        LDREQ   R7,freepoolpages        ; number of pages in free pool
;
        LDR     R5,slotsize             ; max no of pages
        CMP     R5,R7

        MOVGT   R5,R7                   ; now R5 = actual no of pages to use
        CMP     R5,#0
        MOVLE   R1,#ApplicationStart
        BLE     gosetmemsize            ; no pages allocated
;
; allocate a heap block of the correct size
;
        ADD     R3,R5,R5,LSL #1         ; R3 = 3 * no of pages
        MOV     R3,R3,LSL #2            ; R3 = 12 * no of pages
        ADD     R3,R3,#4                ; leave room for terminator
        BL      claimblock
        Pull    "R1-R7,PC",VS
;
; NB: pages may have been remapped because of that call - check here!
;
        LDR     R7,freepoolpages        ; R7 = number of free pages
        CMP     R5,R7

        MOVGT   R5,R7                   ; now R5 = actual no of pages to use

;
; construct block by transferring pages from the free pool
; R2 --> new block, R5 = no of pages, R6-->free pool, R7 = free pool sp
;
        LDR     R14,taskhandle          ; must be a live task!
        LDR     R1,[wsptr,R14]          ; R1 --> task block
        STR     R2,[R1,#task_slotptr]
;
        BL      mapfromfreepool         ; R5 = number of pages to grab
        ADD     R1,R1,#ApplicationStart ; R1 --> end of application memory
;
        MOV     R0,R2
        BL      mapin                   ; map pages in (corrupts R2)

gosetmemsize

        LDR     R14,freepool            ;; Wimp 1.89o onwards
        CMP     R14,#nullptr            ;;
        LDREQ   R0,taskhandle           ;; if this is the "owner" slot,
        LDREQ   R14,inithandle          ;; it can have the application memory
        CMPEQ   R0,R14                  ;;
        BLEQ    restorememlimit         ;; (preserves flags)
        BLNE    setmemsize              ;; otherwise it gets none.
;
        Pull    "R1-R7,PC"

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
;
        LDR     R14,taskhandle
        LDR     R1,[wsptr,R14]          ; R1 --> task block
        LDR     R2,[R1,#task_slotptr]
        CMP     R2,#nullptr
        MOVNE   R14,#nullptr
        STRNE   R14,[R1,#task_slotptr]
        [ Medusa
        BEQ     %FT03
01
; first find out how much memory is really in the slot
        Push    "R2-R3"
        MOV     R0,#0
        LDR     R1,pagesize
02
        LDR     R14,[R2],#12
        CMP     R14,#-1
        ADDNE   R0,R0,R1
        BNE     %BT02
; R0 bytes in slot, update environment
        ADD     R1,R0,#ApplicationStart
        MOV     R0,#0
        Push    "R1"
        SWI     XOS_ChangeEnvironment
        LDR     R1,[SP]
        MOV     R0,#14
        SWI     XOS_ChangeEnvironment
        Pull    "R1"
        Push    "R4"
        SUB     R4,R1,#ApplicationStart
        BL      SafeChangeDynamic
        Pull    "R4"
        Pull    "R2-R3"
        CLRV
        MOV     R0,#ModHandReason_Free
        BL     XROS_Module              ; free the slot
03
        |
        BLNE    deallocate              ; R2 --> block to deallocate from
        ]
;
        CLRV
        Pull    "R1-R2,PC"

;
; Entry:  R2 --> slot block
; Exit:   pages mapped into free pool etc. (maptofreepool called)
;         slot block deallocated
;

deallocate      ROUT
        Push    "LR"
        [ Medusa
        CMP     R2,#nullptr
        Pull    "PC",EQ                 ; return if invalid slot pointer
        Push    "R0-R4"
        BL      mapslotout              ; map current task out of the way
        LDR     R0,pagesize
        MOV     R1,#0
        MOV     R3,R2
01
        LDR     R14,[R3],#12
        CMP     R14,#-1
        ADDNE   R1,R1,R0
        BNE     %BT01
; R1 is now size of block in bytes
        ADD     R1,R1,#ApplicationStart
        MOV     R0,#0
        Push    "R1"
        SWI     XOS_ChangeEnvironment   ; set up suitable environment
        MOV     R3,R1
        Pull    "R1"
        MOV     R0,#14
        SWI     XOS_ChangeEnvironment
        MOV     R4,R1
        MOV     R0,R2
        Push    "R2-R4"
        BL      mapin                   ; map in area to be free'd
        MOV     R4,#&10000000
        BL      SafeChangeDynamic
        Pull    "R2-R4"
        CLRV
        MOV     R0,#ModHandReason_Free
        BL     XROS_Module              ; free the slot
45
        MOV     R1,R4
        MOV     R0,#14
        SWI     XOS_ChangeEnvironment   ; return environment to how it was
        MOV     R1,R3
        MOV     R0,#0
        SWI     XOS_ChangeEnvironment
        BL      mapslotin               ; put current task back
        Pull    "R0-R4,PC"
50
        |
        BL      maptofreepool
        CMP     R2,#nullptr
        MOVNE   R0,#ModHandReason_Free
        BLNE   XROS_Module
        Pull    "PC"
        ]

;
; Entry:  R2 --> slot block
; Exit:   pages mapped to base of free pool
;         page numbers put into free pool (lowest page last)
;         [freepoolbase] updated
;

maptofreepool   ROUT
        Push    "R1-R7,LR"
;
        CMP     R2,#nullptr
        Pull    "R1-R7,PC",EQ           ; no block!
;

        LDR     R6,freepool
        LDR     R7,freepoolpages        ; R7 = number of pages in free pool
        ADD     R6,R6,R7,LSL #2
        ADD     R6,R6,R7,LSL #3         ; R6 -> terminators of free pool
        MOV     R0,R6                   ; R0 -> block for OS_SetMemMapEntries

        LDR     R1,pagesize
        LDR     R4,freepoolbase         ; R4 -> next address
        MOV     R5,#2                   ; R5 = protection level
01      LDR     R3,[R2],#12             ; R3 = page number
        CMP     R3,#nullptr
        SUBNE   R4,R4,R1
        STMNEIA R6!,{R3,R4,R5}          ; page number, address, protection level
        ADDNE   R7,R7,#1
        BNE     %BT01

        STR     R4,freepoolbase
        STR     R7,freepoolpages
        MOV     R14,#-1
        STR     R14,[R6]                ; terminator

        SWI     XOS_SetMemMapEntries

        Pull    "R1-R7,PC"              ; don't alter memorylimit

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
        CMP     R0,#nullptr              ; no slot allocated
        BLNE    mapin                   ; (corrupts R2)
;
        LDR     R14,taskhandle
        LDR     R4,[wsptr,R14]          ; NB task cannot be dead
        ADD     R4,R4,#task_environment
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
        MOV     R2,#ApplicationStart

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
        Push    "R1-R3,LR"
;
        MOV     R2,#-1                  ; map out of the way
        LDR     R3,pagesize
        MOV     R1,R0
01
        LDR     R14,[R1],#4
        CMP     R14,#0
        STRGE   R2,[R1],#8              ; next page
        BGE     %BT01
;
        SWI     XOS_SetMemMapEntries
;
        Pull    "R1-R3,PC"


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
errmem  DCB     "ErrMemS",0		; simple message
  |
errmem  DCB     "ErrMem",0		; original one
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


;;----------------------------------------------------------------------------
;; Stuff to deal with OS_ChangeDynamicArea
;;----------------------------------------------------------------------------

;
; intercept OS_ChangeDynamicArea
;

initdynamic     ROUT
        [ :LNOT: FreePoolWCF
        [ Medusa
         [ true
        Push    "R0-R2,lr"
        MOV     R0,#6
        SWI     XOS_ReadDynamicArea             ; is there a kernel free pool
        Pull    "R0-R2,lr"
        MOVVC   PC,lr
        CLRV
        |
        MOV     PC,lr
         ]
        ]
        ]
        Push    "R1-R4,LR"
;
        ADR     R0,RAM_SWIEntry
        LDR     R1,copyofRAMcode+0
        LDR     R2,copyofRAMcode+4
        ADR     R3,My_ChangeDynamic
        LDR     R14,=SvcTable + 4 * OS_ChangeDynamicArea
        LDR     R4,[R14]                        ; R4 = old SWI entry
        TEQ     R4,R0                           ; if already in, forget it!
        STMNEIA R0,{R1-R4}
        STRNE   R0,[R14]                        ; R0 = RAM_SWIEntry

        ; synchronise with respect to modified code at RAM_SWIEntry

        MOVNE   R1,R0                           ; start address
        ADDNE   R2,R1,#4                        ; end address (inclusive) for 2 words (other 2 are addresses)
        MOVNE   R0,#1                           ; means R1,R2 specify range
        SWINE   XOS_SynchroniseCodeAreas        ; do the necessary

        Pull    "R1-R4,PC"

copyofRAMcode
        SUB     R12,PC,#:INDEX:RAM_SWIEntry+8
        LDR     PC,[PC,#-4]
        ASSERT  (.-copyofRAMcode = 8)
        ASSERT  (OScopy_ChangeDynamic-RAM_SWIEntry = 12)

resetdynamic    ROUT
       [ :LNOT: FreePoolWCF
        [ Medusa
        MOV    PC,lr
        ]
       ]

        Push    "R1,LR"
;
; happy note for StrongARM - this is not a code modification (vector address change only)
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
        [ Medusa :LAND: FreePoolWCF
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

        MakeInternatErrorBlock ChDynamNotAllMoved,,ErrNoMv
        LTORG
05
        ]
;
; if freepool>0, the Wimp MUST be in control
;
        LDR     R14,freepool
        CMP     R14,#nullptr2
        BHS     goto_osentry
;
        LDR     R14,ptr_IRQsema         ; if in IRQ, forget it!
        LDR     R14,[R14]
        TEQ     R14,#0
        BNE     goto_osentry
;
        LDRB    R14,memoryOK            ; check for re-entrancy
        TST     R14, #mem_remapped
        BNE     goto_osentry            ; shouldn't ever happen

        TST     R14, #mem_claimed       ; if free memory claimed
        BNE     noslot                  ; then continue, but trap it in Service_Memory
;
; work out if the current free pool is sufficient to meet the demand
; if not, see whether the current application would like to give some up
;
        LDR     R14,freepoolpages       ; R14 = number of free pages
        LDR     R0,pagesize
        MUL     R14,R0,R14              ; R14 = free memory
        LDR     R1,[sp,#4]
        SUBS    R14,R14,R1              ; R14 = extra needed (if -ve)
        BGE     noslot
        SUB     R0,R0,#1                ; round to next lower page boundary
        BIC     R0,R14,R0               ; assume pagesize = 2^n
;
        BL      readCAOpointer          ; OS_ChangeEnvironment -> R2
        LDR     R14,orig_applicationspacesize
        CMP     R2,R14
        BCC     noslot                  ; can't do it
        ADRL    R14,Module_BaseAddr
        TEQ     R2,R14
        BEQ     %FT02                   ; OK if Wimp active - don't even ask!
;
        MOV     R1,#Service_Memory      ; R0 = amount to change area by
        SWI     XOS_ServiceCall
        CMP     R1,#0                   ; clear V!
        BEQ     noslot                  ; can't do it
02
        Push    "R0"                    ; amount to move (-ve)
        MOV     R0,#ApplicationSpaceSize
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment   ; R1 = size of current slot
        Pull    "R0"
        SUB     R1,R1,#ApplicationStart ; convert from end address to SIZE
        ADDS    R0,R1,R0                ; R0 = new slot size (if -ve, ignore)
        MOVGE   R1,#-1
        SWIGE   XWimp_SlotSize          ; I hope this works!
noslot
;
; map all slots into application space
;
        MOV     R0,#CAOPointer          ; Wimp active during OS_ChangeDynamic
        ADRL    R1,Module_BaseAddr
        SWI     XOS_ChangeEnvironment
        STR     R1,oldCAOpointer        ;; MUST RESTORE CAOPOINTER !!!
;
; swap total memory limits with local ones
;
        MOV     R0,#MemoryLimit
        LDR     R1,orig_memorylimit
        SWI     XOS_ChangeEnvironment
        STR     R1,orig_memorylimit             ; swap these over
;
        MOV     R0,#ApplicationSpaceSize
        LDR     R1,orig_applicationspacesize
        STR     R1,oldapplimit                  ; used later
        SWI     XOS_ChangeEnvironment
        STR     R1,orig_applicationspacesize    ; swap these over
;
; map all slots into the area above the current one
;
        BL      rackupslots             ; R1 --> address to start from
                                        ; current task is left alone
;
; free pool is already present at the top end of the memory
; check that we now have a contiguous block of memory
;

        LDRB    R14,memoryOK
        ORR     R14,R14,#mem_remapped   ; set flag for Service_Memory
        STRB    R14,memoryOK

goto_osentry
        Pull    "R0-R5,LR"
        LDR     PC,OScopy_ChangeDynamic

;
; Entry:  R1 --> address to start putting slots at
; Exit:   all slots mapped into application space, not overlapping
;         R2 --> end address of slots
;         R0,R1,R3,R4 trashed
;
rackupslots     ROUT
        Push    "LR"
;
        MOV     R2,R1                           ; start mapping from here
        ADRL    R1,taskpointers
        LDR     R3,taskhandle           ; this one's been done already
        ADD     R3,wsptr,R3
        MOV     R4,#maxtasks
01
        TEQ     R1,R3                   ; is this the current task?
        LDR     R14,[R1],#4             ; NB always increment R1
        TEQNE   R14,#task_unused
        LDRNE   R0,[R14,#task_slotptr]
        MOVEQ   R0,#nullptr
        CMP     R0,#nullptr
        BLNE    mapslot                 ; updates [R0..], R2
        SUBS    R4,R4,#1
        BNE     %BT01
;
        Pull    "PC"

;
; Entry:  all slots mapped into application space, consecutively
; Exit:   all slots except the current one are mapped out
;         R0-R4 trashed
;

unrackslots     ROUT
        Push    "LR"
;
        ADRL    R1,taskpointers
        LDR     R3,taskhandle           ; leave this one alone
        ADD     R3,wsptr,R3
        MOV     R4,#maxtasks
01
        TEQ     R1,R3                   ; is this the current task?
        LDR     R14,[R1],#4             ; NB always increment R1
        TEQNE   R14,#task_unused
        LDRNE   R0,[R14,#task_slotptr]
        MOVEQ   R0,#nullptr
        CMP     R0,#nullptr
        BLNE    mapout
        SUBS    R4,R4,#1
        BNE     %BT01
;
        Pull    "PC"

        [ Medusa
;-----------------------------------------------------------------------------
; Service_PagesSafe interception
; Entry:  R2    No. of pages to move
;         R3    page list before move
;         R4    page list after move
;-----------------------------------------------------------------------------
        DCB     "PagesSafe"
        ALIGN

servicepagessafe
        Push    "R0-r8,lr"
;        SWI     &107                    ; beep when this happens
        MOV     R0,#0
        ADD     R5,R2,#1
        MOV     R8,R4
        MOV     R4,R3
01
        SUBS    R5,R5,#1
        BEQ     %FT09
        LDR     R6,[R4],#12
        CMP     R6,#-1
        BEQ     %FT09
        LDR     R7,[R8],#12              ; 3-word entries
        MOV     R0,#-1
        ADRL    R3,taskpointers
03
        ADD     R0,R0,#1
        CMP     R0,#maxtasks
        BEQ     %FT11
        LDR     R2,[R3,R0, LSL #2]
        TEQ     R2,#task_unused
        BEQ     %BT03
        LDR     R2,[R2,#task_slotptr]
        CMP     R2,#-1
        BEQ     %BT03
05
        LDR     R1,[R2],#12
        CMP     R1,#-1
        BEQ     %BT03
        CMP     R1,R6
        BNE     %BT05
        STR     R7,[R2,#-12]
        B       %BT01
09
        Pull    "R0-R8,PC"
11
; just in case 1-tasking & task isn't in the list
        LDR     R0,taskhandle
        LDR     R2,singletaskhandle
        CMP     R0,R2
        BNE     %BT01
        LDR     R0,pendingtask
        CMP     R0,#1
        BLT     %BT01
        LDR     R2,[R0,#task_slotptr]
        CMP     R2,#-1
        BEQ     %BT01
13
        LDR     R1,[R2],#12
        CMP     R1,#-1
        BEQ     %BT01
        CMP     R1,R6
        BNE     %BT13
        STR     R7,[R2,#-12]
        B       %BT01
        ]


;-----------------------------------------------------------------------------
; Service_Memory interception
; Entry:  R0 = amount application space would be altered by
;         R2 = CAO pointer
;-----------------------------------------------------------------------------

servicememory   ROUT
        [ Medusa
         [ true
        Push    "R0-R2,lr"
        MOV     R0,#6
        SWI     XOS_ReadDynamicArea             ; is there a kernel free pool
        Pull    "R0-R2,lr"
;        BVC     medusaaboutto
        MOVVC   PC,lr
        CLRV
        |
        MOV     PC,lr
         ]
        ]
        Push    "R0-R3,LR"
;
        Debug   dy,"Service_Memory: CAO pointer, amount to move =",R2,R0
;
        LDR     R14,freepool            ;; Wimp 1.89o onwards
        CMP     R14,#nullptr            ;;
        BNE     %FT01                   ;; only allow paging if
        LDR     R14,taskhandle          ;; the "owner" slot is active
        LDR     R1,inithandle           ;;
        TEQ     R1, R14                 ;; TMD: actually do the comparison!
        BNE     serviceclaim            ;;
01
        LDRB    R14, memoryOK           ; if free memory has been claimed
        TST     R14, #mem_claimed       ; then refuse to move memory
        BNE     serviceclaim

        ADRL    R14,Module_BaseAddr
        TEQ     R2,R14                  ; are we in control?
        Pull    "R0-R3,PC",NE
        TEQ     R0,#IsAnybodyThere      ; if this is the Wimp, allow it
        Pull    "R0-R3,PC",EQ
;
        LDR     R14,freepool            ; is there a free pool?
        CMP     R14,#nullptr2
        Pull    "R0-R3,PC",EQ           ; freepool=-2 ==> OK (not running)
        CMP     R14,#nullptr
        LDRNEB  R14,memoryOK            ; if not remapped already, stop this!
        TSTNE   R14,#mem_remapped       ; (usually because memory claimed)
        BEQ     serviceclaim
;
        LDR     R1,oldapplimit          ; orig_applicationspacesize is wrong
        LDR     R0,[sp]                 ; (has been swapped with local one)
        ADD     R0,R1,R0                ; proposed new end-of-memory
        LDR     R14,freepoolbase
        CMP     R0,R14
        Pull    "R0-R3,PC",CS

serviceclaim
        MOV     R14,#0
        STR     R14,[sp,#1*4]           ; claim service if not enough memory
        Pull    "R0-R3,PC"

      [ Medusa
        [ {FALSE}
medusaaboutto

        Push    "R0,lr"

        ADRL    R0,Module_BaseAddr
        TEQ     R0,R2
        Pull    "R0,PC",NE
        LDR     R0,inithandle
        LDR     R14,taskhandle
        TEQ     R0,R14
        MOVNE   R1,#0

        Pull    "R0,PC"
        ]


medusaservicemem
        ; page may have been taken out of application space
        ; the slot block must be updated.
        Push    "R0-R3,lr"
        ; first check pending task

        LDR     R14,pendingtask
        MOVS    R0,R14,ASR #31
        LDREQ   R0,[R14,#task_slotptr]
        CMP     R0,#nullptr
        SWINE   XOS_FindMemMapEntries
        BNE     %FT05

        LDR     R14,taskhandle
        CMP     R14,#0
        Pull    "R0-R3,PC",EQ

        LDR     R14,[wsptr,R14]
        MOVS    R0,R14,ASR #31
        LDREQ   R0,[R14,#task_slotptr]
        CMP     R0,#nullptr
        SWINE   XOS_FindMemMapEntries
05
        Pull    "R0-R3,PC"
      ]

;-----------------------------------------------------------------------------
; Service_MemoryMoved interception
; Put pages back into their proper positions
;-----------------------------------------------------------------------------

servicememorymoved  ROUT
        [ Medusa
         [ true
        Push    "R0-R2,lr"
        MOV     R0,#6
        SWI     XOS_ReadDynamicArea             ; is there a kernel free pool
        Pull    "R0-R2,lr"
        BVC     medusaservicemem

        CLRV
        |
        MOV     PC,lr
         ]
        ]
        Push    "R0-R7,R10-R11,LR"
;
        LDR     R14,ptr_IRQsema         ; if in IRQ, forget it!
        LDR     R14,[R14]
        TEQ     R14,#0
        Pull    "R0-R7,R10-R11,PC",NE
;
        TEQP    PC,#SVC_mode            ; enable interrupts (bug in MOS)
;
        LDR     R14,freepool            ; no messing about if no free pool
        CMP     R14,#nullptr2
        Pull    "R0-R7,R10-R11,PC",EQ   ; Wimp not involved at all
        BLO     %FT01                   ; Wimp has a free pool to maintain
;
        LDR     R0,taskhandle                ;; Wimp 1.89o onwards
        LDR     R14,inithandle               ;;
        TEQ     R0,R14                       ;; update these if "owner" slot
        Pull    "R0-R7,R10-R11,PC",NE        ;; is being altered
;                                            ;;
        MOV     R0,#ApplicationSpaceSize     ;; restorepages uses these later
        MOV     R1,#0                        ;;
        SWI     XOS_ChangeEnvironment        ;;
        STRVC   R1,orig_applicationspacesize ;;
        MOV     R0,#MemoryLimit              ;;
        MOV     R1,#0                        ;;
        SWI     XOS_ChangeEnvironment        ;;
        STRVC   R1,orig_memorylimit          ;;
                                             ;;
        Pull    "R0-R7,R10-R11,PC"           ;;

01
        LDRB    R14,memoryOK            ; if not remapped, forget it
        TST     R14,#mem_remapped
        Pull    "R0-R7,R10-R11,PC",EQ
;
; restore correct CAO pointer (forced to be Wimp during OS_ChangeDynamic)
;
        MOV     R0,#CAOPointer
        LDR     R1,oldCAOpointer
        SWI     XOS_ChangeEnvironment   ; ignore errors
;
; scan all slots to see if the memory has moved
;
        ADRL    R5,taskpointers
        MOV     R4,#maxtasks
01
        LDR     R14,[R5],#4
        MOVS    R0,R14,ASR #31          ; R0 = 0 (OK) or -1 (no slot)
        LDREQ   R0,[R14,#task_slotptr]
        CMP     R0,#nullptr
        SWINE   XOS_FindMemMapEntries   ; R10 --> new map, R0 --> slot
        SUBS    R4,R4,#1                ; clears V
        BNE     %BT01
;
; don't forget the 'pending' slot
;
        LDR     R14,pendingtask         ;; this was missing in Risc OS 2.00
        MOVS    R0,R14,ASR #31          ;;
        LDREQ   R0,[R14,#task_slotptr]  ;; essential for screen remapping
        CMP     R0,#nullptr             ;;
        SWINE   XOS_FindMemMapEntries   ;;
;
; restore the current orig_applicationspacesize/memorylimit for this slot
;
        BL      restorememlimit
        LDR     R3,oldapplimit
        STR     R1,orig_memorylimit             ; these must be equal
        STR     R1,orig_applicationspacesize
;
; reconstruct the free slot by entering the expected addresses
; note that sometimes more than just the free pool will have been removed
;
        LDR     R2,freepool             ; R1 -> end of memory, R2 -> free slot
        BL      findfreepool            ; fills in free pool

        MOV     R1,#2                   ; no USR mode read/write
        BL      setslotaccess
;
; map out all applications except the current one
; NB: this is important so that pages cannot coincide later
;
        BL      unrackslots
;
        LDRB    R14,memoryOK
        BIC     R14,R14,#mem_remapped   ; should be alright again now!
        STRB    R14,memoryOK
;
        Pull    "R0-R7,R10-R11,PC"

      ]


;;----------------------------------------------------------------------------
;; Resource files
;;----------------------------------------------------------------------------

romsprites
        DCD     16,0,16,16              ; null area just in case

resourcefsfiles
      [ standalone:LOR:RegisterMessages
        ResourceFile    $MergedMsgs,     Resources.Wimp.Messages
      ]
      [ standalone:LOR:RegisterTemplates
      [ NewErrorSystem
        ResourceFile    Resources.<Locale>.<System>.Template3D,   Resources.Wimp.Templates  ; AMcC 18-Oct-94 was Template3D
        |
        ResourceFile    Resources.<Locale>.<System>.Templates,    Resources.Wimp.Templates
      ]
      ]
      [ standalone:LOR:RegisterTools3D
        ResourceFile    Resources.<Locale>.<System>.Tools3d,      Resources.Wimp.Tools
      ]
      [ standalone:LOR:RegisterTools2D
        ResourceFile    Resources.<Locale>.<System>.Tools,        Resources.Wimp.Tools
      ]
      [ RegisterSprites
        ResourceFile    Resources.<Locale>.<System>.Sprites,      Resources.Wimp.Sprites
      ]
      [ RegisterSprites22
        ResourceFile    Resources.<Locale>.<System>.Sprites22,    Resources.Wimp.Sprites22
      ]
        [ RegisterWIMPSymbolFont
        ResourceFile    Resources.!WIMPSym.WIMPSymbol.Encoding,   Fonts.WIMPSymbol.Encoding
        ResourceFile    Resources.!WIMPSym.WIMPSymbol.f240x120,   Fonts.WIMPSymbol.f240x120
        ResourceFile    Resources.!WIMPSym.WIMPSymbol.IntMetrics, Fonts.WIMPSymbol.IntMetrics
        ResourceFile    Resources.!WIMPSym.WIMPSymbol.Outlines,   Fonts.WIMPSymbol.Outlines
        ]
      [ :LNOT: NoDarwin
        [ RealDarwin
        ResourceFile    Resources.!Darwin.Darwin.f240x120,    Fonts.Darwin.Medium.f240x120
        ResourceFile    Resources.!Darwin.Darwin.IntMetrics,  Fonts.Darwin.Medium.IntMetrics
        |
        ResourceFile    Resources.!Homerton.homerton.IntMetric0,  Fonts.Darwin.Medium.IntMetric0
        ResourceFile    Resources.!Homerton.homerton.Outlines0, Fonts.Darwin.Medium.Outlines0
        ]
      ]
        [ standalone :LAND: false
        ResourceFile    Resources.desktop,      Resources.Desktop.Messages
        ]
        DCD     0

        END
