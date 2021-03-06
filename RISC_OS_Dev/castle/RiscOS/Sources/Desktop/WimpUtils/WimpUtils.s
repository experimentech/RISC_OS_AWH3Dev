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
; > Sources.WimpUtils

;;----------------------------------------------------------------------------
;; Patch module for Wimp 2.00
;;
;; Change List
;; -----------
;;  5-Jan-89    0.01    File created
;;  6-Jan-89            Check for Wimp being killed/reloaded, and Service_Reset
;;              0.02    Change name to WindowUtils
;;  9-Jan-89    0.03    Preserve R5 over calls to checkforwimp
;;  9-Mar-89    0.04    Don't worry about Wimp changing depth
;;                      IRQUtils can alter contents of Wimp's OSCopy
;;
;; Actions:
;;      Module claims workspace iff "Window Manager 2.00 (09 Sep 1988)" present
;;          Stores Wimp's code address and private word contents
;;      Intercepts OS_ChangeDynamicArea:
;;          On entry OS_ChangeEnvironment is called with R0=CAOPointer,R1=0
;;          The result is stored in wwww_CAOpointer and oldCAOpointer
;;      Intercepts Service_MemoryMoved:
;;          On exit from OS_ChangeDynamicArea:
;;              OS_ChangeEnvironment is called with R1=oldCAOpointer
;;      Intercepts OS_ChangeEnvironment:
;;          If R0=CAOPointer, R1=Wimp's code base, then
;;              unless we are inside OS_ChangeEnvironment
;;              or wwww_CAOpointer = Wimp's code base (in Wimp_StartTask)
;;              - the call is suppressed (ie. it has no effect)
;;
;;----------------------------------------------------------------------------

Module_BaseAddr

        GET     Hdr:ListOpts
        OPT     OptP1List
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:File
        GET     Hdr:NewErrors
        GET     Hdr:EnvNumbers
        GET     Hdr:NewSpace
        GET     Hdr:NdrDebug

        GET     Version

        GBLL    debugxx
        GBLL    hostvdu

debug   SETL    false
debugxx SETL    false
hostvdu SETL    true


;;----------------------------------------------------------------------------
;; Module header
;;----------------------------------------------------------------------------

        ASSERT  (.=Module_BaseAddr)

        DCD     0                               ; Start
        DCD     Init           - Module_BaseAddr
        DCD     Die            - Module_BaseAddr
        DCD     Service        - Module_BaseAddr
        DCD     Title          - Module_BaseAddr
        DCD     Helpstr        - Module_BaseAddr
        DCD     0                               ; Helptable
        DCD     0                               ; MySWIBase
        DCD     0                               ; SWIdecode
        DCD     0                               ; SWInames
        DCD     0
        DCD     0
        DCD     0

Title   DCB     "WindowUtils",0
Helpstr DCB     "Window Utils",9,"$VString ($Date)",0
        ALIGN

;;----------------------------------------------------------------------------
;; Workspace
;;----------------------------------------------------------------------------

                ^       0,R12

wimpbase        #       4
wimpword        #       4
oldCAOpointer   #       4

RAM_SWIEntry            #       12      ; 3 instructions for getting R12 back
OScopy_ChangeDynamic    #       4       ; this must follow immediately
oldOScopy_ChangeDynamic #       4       ; the one the Wimp calls

workareasize    *       :INDEX:@


wwww_CAOpointer *       &220            ; offset to Wimp's copy


;;----------------------------------------------------------------------------
;; Code
;;----------------------------------------------------------------------------

; This module must appear later in the module chain than the Wimp
; This is because it needs to get onto ChangeEnvironment and ChangeDynamic
; Assumes that on *RMTidy, modules are soft-killed in reverse order

Init            ROUT
        Push    "R1-R4,LR"
;
; only claim workspace if Wimp 2.00 is loaded
;
        Debuga  xx,"Init: "
        BL      checkforwimp            ; R3,R4 = wimpbase, wimpword
        Pull    "R1-R4,PC",NE
;
; claim workspace to put the answers in
;
        Push    "R3"
        MOV     R0,#ModHandReason_Claim ; workspace is always reclaimed
        MOV     R3,#workareasize        ; even on *RMTidy
        SWI     XOS_Module
        Pull    "R3"

        STRVC   R2,[R12]
        MOVVC   R12,R2
        STRVC   R3,wimpbase
        STRVC   R4,wimpword

        BLVC    claimvectors

        Pull    "R1-R4,PC"              ; must report error


copyofRAMcode
        SUB     R12,PC,#:INDEX:RAM_SWIEntry+8
        LDR     PC,[PC,#-4]
        ASSERT  (.-copyofRAMcode = 8)
        ASSERT  (OScopy_ChangeDynamic-RAM_SWIEntry = 12)


; In    R12 -> workspace (non-zero)
; Out   OS_ChangeDynamicArea and OS_ChangeEnvironment intercepted
;       If error, 

claimvectors    ROUT
        Push    "R1-R4,LR"

        MOV     R14,#0
        STR     R14,oldCAOpointer       ; for preserving over OS_ChangeDynamic
;
; get onto OS_ChangeEnvironment first (can give error - don't do other one)
;
        MOV     R0,#ChangeEnvironmentV
        ADR     R1,ChangeEnvCode        ; investigate handler changes
        MOV     R2,R12
        SWI     XOS_Claim
        Pull    "R1-R4,PC",VS
;
; get onto OS_ChangeDynamicArea
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
        LDRNE   R14,[R4,#OScopy_ChangeDynamic-RAM_SWIEntry]
        STRNE   R14,oldOScopy_ChangeDynamic     ; remember one after Wimp!

        Pull    "R1-R4,PC"


Die     ROUT
        Push    "R1-R4,R12,LR"
;
        LDR     R12,[R12]
        TEQ     R12,#0
        Pull    "R1-R4,R12,PC",EQ,^       ; nothing to do
;
; attempt to get off OS_ChangeDynamicArea
;
        LDR     R1,=SvcTable + 4 * OS_ChangeDynamicArea
        ADR     R14,RAM_SWIEntry
        LDR     R2,[R1]
        TEQ     R2,R14                    ; we can only get off this
        LDREQ   R14,OScopy_ChangeDynamic  ; if top of the chain
        STREQ   R14,[R1]
;
; if not top of list, see if we might be chained in underneath
; assuming OS_ChangeDynamic owner is Wimp, check its old OS copy
; can't call checkforwimp 'cos module handler can't do it !!!
;
        LDRNE   R1,oldOScopy_ChangeDynamic
        TEQNE   R2,R1
        LDRNE   R14,[R2,#OScopy_ChangeDynamic-RAM_SWIEntry]
        TEQNE   R14,R1                  ; we may be completely bypassed
        XError  CantKill,NE             ; which would be OK
        Pull    "R1-R4,R12,PC",VS       ; (otherwise be paranoid)

        MOV     R0,#ChangeEnvironmentV
        ADR     R1,ChangeEnvCode
        MOV     R2,R12
        SWI     XOS_Release

        MOV     R0,#ModHandReason_Free  ; free workspace even on *RMTidy
        MOV     R2,R12
        SWI     XOS_Module
        LDR     R12,[sp,#4*4]
        MOV     R14,#0                  ; mark workspace deleted
        STR     R14,[R12]
;
        Pull    "R1-R4,R12,PC",,^       ; no errors allowed
        LTORG

        MakeErrorBlock CantKill


; In    R12 undefined (ie. no workspace can be assumed)
; Out   Z set => wimp is present,
;                R3,R4 = address of wimp code base and work area
;       Z unset => wimp not present,
;                R3,R4 undefined

checkforwimp    ROUT
        Push    "R1-R2,R5,LR"

        MOV     R1,#0                   ; module number
        MOV     R2,#0                   ; incarnation number
01
        MOV     R0,#ModHandReason_GetNames
        SWI     XOS_Module
      [ debugxx
        BVC     %FT00
        Debug   xx,"Wimp not present"
00
      ]
        Pull    "R1-R2,R5,LR",VS        ; V set => end of list
        BICVSS  PC,LR,#Z_bit            ; Z unset => wimp not found

        Push    "R1,R2"

        LDR     R14,[R3,#Module_HelpStr]
        ADD     R1,R3,R14
        ADR     R2,matchname            ; check for "Window Manager" etc
02
        LDRB    R0,[R1],#1
        LDRB    R14,[R2],#1
        TEQ     R0,R14
        BNE     %FT03
        TEQ     R0,#0
        BNE     %BT02
03
        Pull    "R1,R2"
        BNE     %BT01

        Debug   xx,"Wimp is present"

        Pull    "R1-R2,R5,PC"           ; Z set => wimp found

matchname       DCB     "Window Manager",9,"2.00 (09 Sep 1988)",0
                ALIGN


; Only allow the Wimp to set CAOPointer to itself if:
;     (a) Wimp_StartTask is being called (wimpword+wwww_CAOpointer = R1)
;  or (b) OS_ChangeDynamicArea is being called (oldCAOpointer <> 0)

ChangeEnvCode   ROUT
        Push    "R0-R2,LR"

        TEQ     R0,#CAOPointer          ; is this the Wimp trying it on?
        LDREQ   R14,wimpbase
        TEQEQ   R1,R14
        LDREQ   R14,oldCAOpointer       ; are we inside OS_ChangeDynamic?
        TEQEQ   R14,#0                  ; (this is 0 elsewhere)
        Pull    "R0-R2,PC",NE,^

        Debuga  xx,"OS_ChangeEnvironment: R0,R1 =",R0,R1
        Debuga  xx,": "
        BL      checkforwimp_same       ; check it hasn't moved
        Pull    "R0-R2,PC",NE,^         ; give up if anything's changed

        Debuga  xx,"Wimp hasn't moved: "

        LDR     R2,wimpword
        LDR     R14,[R2,#wwww_CAOpointer]
        TEQ     R1,R14
      [ debugxx
        BNE     %FT01
        Debug   xx,"allow CAOpointer -> wimp (Wimp_StartTask)"
        B       %FT02
01
        Debug   xx,"disallow CAOpointer -> wimp (Wimp_Initialise)"
02
      ]
        MOVNE   R1,#0                   ; R1=0 => just read value
        STRNE   R1,[sp,#1*4]

        Pull    "R0-R2,PC",,^


; Out   Z set => wimp is still in the module chain, and hasn't moved

checkforwimp_same ROUT
        Push    "R3,R4,LR"

        BL      checkforwimp            ; verify that Wimp is still loaded
        LDREQ   R14,wimpbase
        TEQEQ   R3,R14
        LDREQ   R14,wimpword            ; paranoid - check it hasn't moved
        TEQEQ   R4,R14
  ;;    LDREQ   R14,OScopy_ChangeDynamic
  ;;    LDREQ   R14,[R14,#OScopy_ChangeDynamic-RAM_SWIEntry]
  ;;    LDREQ   R0,oldOScopy_ChangeDynamic ; and it hasn't changed 'depth'
  ;;    TEQEQ   R14,R0
        MOVNE   R14,#-1
        STRNE   R14,wimpbase            ; stop intercepting this
        MOVNE   R14,#0
        STRNE   R14,oldCAOpointer

        Pull    "R3,R4,PC"              ; Z set => state is all the same


; On entry to OS_ChangeDynamicArea,
;     call OS_ChangeEnvironment and copy into wimp's workspace
;     also remember it for restoring on exit (Service_MemoryMoved)

My_ChangeDynamic ROUT
        Push    "R0-R3,LR"              ; R12 -> workspace

        Debuga  xx,"OS_ChangeDynamicArea: "
        BL      checkforwimp_same       ; verify that Wimp is still loaded
        Pull    "R0-R3,LR",NE           ; go to the OS directly
        LDRNE   PC,oldOScopy_ChangeDynamic

        Debuga  xx,"Wimp hasn't moved: "

        MOV     R0,#CAOPointer
        MOV     R1,#0
        SWI     XOS_ChangeEnvironment   ; assume no errors

        LDR     R2,wimpword
        Debug   xx,"OS_ChangeDynamic: CAO, w/s =",R1,R2
        TEQ     R2,#0
        STRNE   R1,[R2,#wwww_CAOpointer]        ; correct value
        STRNE   R1,oldCAOpointer                ; for restoring afterwards

        Pull    "R0-R3,LR"
        LDR     PC,OScopy_ChangeDynamic


; This module must get the service AFTER the Wimp gets it
; On Service_MemoryMoved, restore CAOPointer to correct value

Service ROUT
        LDR     R12,[R12]               ; no action if dormant
        TEQ     R12,#0
        MOVEQS  PC,LR

        TEQ     R1,#Service_Reset
        BEQ     svc_reset

        TEQ     R1,#Service_MemoryMoved
        MOVNES  PC,LR

        Push    "R0-R3,LR"

        MOV     R0,#CAOPointer          ; no effect if oldCAOpointer = 0
        LDR     R1,oldCAOpointer
        Debug   xx,"Restoring CAO pointer to",R1
        SWI     XOS_ChangeEnvironment   ; reset this

        MOV     R14,#0
        STR     R14,oldCAOpointer       ; make sure these are paired

        Pull    "R0-R3,PC",,^

svc_reset
        Push    "R0,LR"                 ; must have workspace here
        BL      claimvectors
        Pull    "R0,PC",,^              ; no errors in Service_Reset

      [ debug
        InsertNDRDebugRoutines
      ]

        END

