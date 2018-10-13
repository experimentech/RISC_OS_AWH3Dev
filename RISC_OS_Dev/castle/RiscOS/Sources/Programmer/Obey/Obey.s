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
; > Sources.Obey

;;----------------------------------------------------------------------------
;; Obey module (for *Obeying text files)
;;
;; Change List
;; -----------
;; 31-Mar-88    0.01    File created
;;  5-Apr-88    0.02    Allow recursive use of *Obey
;;  8-Apr-88    0.03    Put tab into title string
;;  9-Apr-88    0.04    Make *Obey shut down automatically on channel errors
;;  7-Jul-88    0.05    Start conversion towards multi-application
;; 13-Jul-88    0.06    Finished conversion towards multi-application
;; 08-Aug-88    0.07    Allow escape inside obey files
;; 14-Sep-88    0.07    Improve debugging information
;; 20-Oct-88    0.08    Change to use new Make procedure
;; 27-Sep-89    0.09    Fix bug: C run-time error handler without exit handler
;; 29-Sep-89    0.10    Fix bug: *Obey from within BASIC goes wrong
;;  5-Oct-89    0.11    Fix bug: OS_Claim doesn't preserve flags
;; 31-Oct-89    0.12    Fix bug: Used R12 to set up error handler as marker
;;  9-May-90    0.13    Fix bug: R1 corrupted in Service_NewApplication
;; 21-May-91    0.20    Added internationalisation and verbose and caching to 0.13.
;; 22-May-91            Fix bug: When the exit handler is called it may not be in SVC mode!
;; 22-May-91    0.21    Fix bug: above fix assumed R12 valid on chance of modes!
;; 22-May-91    0.22    Ooopsy doopsy logging in source I got it wrong.
;; 01-Jun-91            Fix bug: Fixed lack of stack in exit handler to not go to SVC mode, but allocate stack.
;; 01-Jun-91    0.23    Fix bug: Ensure that handle is closed on the file when executed.
;; 03-Jun-91    0.24    Fix bug: Handles restarting cached files after quiting applications.
;; 02-Jul-91    0.25    Fix bug: remove nastystring stripping of appended extra args, use
;;                              OS_SubstituteArgs flag instead. Fixes ~ on end of filename
;;                              causes address exception bug.
;;                      Fix syntax of *Obey command - there *must*not* be
;;                              any space between the -c and the -v
;;                      Fix BuffOflow tag to BufOFlo
;; 24-Jan-95    0.34    OM SPECIAL VERSION: -m flag allows caching from a block of memory
;;                      instead of a file.
;; 05-Aug-99    0.36    Ursula long command and service call tables merged.
;;----------------------------------------------------------------------------

        AREA    |Obey$$Code|, CODE, READONLY, PIC

Module_BaseAddr

                GET     hdr:ListOpts
                GET     hdr:Macros
                GET     hdr:System
                GET     hdr:ModHand
                GET     hdr:Services
                GET     hdr:UpCall
                GET     hdr:Proc

                GET     hdr:FSNumbers
                GET     hdr:HighFSI
                GET     hdr:NewErrors
                GET     hdr:EnvNumbers
                GET     hdr:NdrDebug
                GET     hdr:MsgTrans

                GET     VersionASM

                GBLL    debugxx
                GBLL    debugcommand
                GBLL    debugopen
                GBLL    debugmode
                GBLL    debugexit

                GBLL    hostvdu
                GBLL    internat

debug           SETL    false    ; global switch for debugging
debugxx         SETL    false    ; general stuff
debugcommand    SETL    false   ; command line decoding
debugopen       SETL    false   ; opening and caching of file blocks
debugmode       SETL    false   ; checking for SVC mode on EXIT handler
debugexit       SETL    false   ; checking exit handler

hostvdu         SETL    true
internat        SETL    true :LAND: Module_Version >=20        ; should we internationalise

                 GBLL    LongCommandLines
LongCommandLines SETL    {TRUE}             ;introduced for Ursula

  [ LongCommandLines
LongCLISize      *       1024     ;long command line length
LongPNameSize    *        512     ;long pathname length (for obey$dir)
  ]

;;----------------------------------------------------------------------------
;; Module header
;;----------------------------------------------------------------------------

        ASSERT  (.=Module_BaseAddr)

        DCD     0                               ; Start
        DCD     0                               ; Init
        DCD     Die- Module_BaseAddr
        DCD     Service- Module_BaseAddr
        DCD     Title- Module_BaseAddr
        DCD     Helpstr- Module_BaseAddr
        DCD     Helptable- Module_BaseAddr
        DCD     0
        DCD     0
        DCD     0
        DCD     0
      [ International_Help=0 :LOR: debug
        DCD     0
      |
        DCD     Messages_File- Module_BaseAddr
      ]
      [ :LNOT: No32bitCode
        DCD     Module_Flags- Module_BaseAddr
      ]

Title   DCB     "Obey",0
Helpstr DCB     "Obey",9,9,"$Module_MajorVersion ($Module_Date)"
      [ Module_MinorVersion <> ""
        DCB     " $Module_MinorVersion"
      ]
      [ debug
        DCB     " Development version"
      ]
        DCB     0
        ALIGN

      [ :LNOT: No32bitCode
Module_Flags
        DCD     ModuleFlag_32bit
      ]

Helptable
 [ debug
        Command Obey,255,0,0                               ; *Obey cancels the current obey file
 |
        Command Obey,255,0,International_Help              ; *Obey cancels the current obey file
 ]
        DCB     0
        ALIGN

 [ International_Help=0 :LOR: debug
Obey_Help       DCB     "*Obey executes a file of *commands, "
                DCB     "performing argument substitution on each line"
                DCB     ".  Prefixing the filename with -v causes each line to be "
                DCB     "echoed before execution, -c causes the file to be cached and executed from memory"
                DCB     13, 10
Obey_Syntax     DCB     "Syntax: *Obey [[-v][-c][-m] [<filename> [<parameters>]]]",0
 |
Messages_File   DCB     "Resources:Resources.Obey.Messages",0
Obey_Help       DCB     "HOBYOBY", 0
Obey_Syntax     DCB     "SOBYOBY", 0
 ]
                ALIGN


;;----------------------------------------------------------------------------
;; Workspace
;;----------------------------------------------------------------------------

  [ LongCommandLines
wk_buflen       *       LongCLISize
  |
wk_buflen       *       256
  ]

                ^       0
wk_link         #       4
wk_exit         #       8       ; Where the exit handler code will live
wk_exitproc     #       4       ; Address in module of real code
wk_flags        #       4
wk_fl_live      *       1:SHL:0 ; Set <=> live, ie there is another line in the file to be processed
wk_fl_useexit   *       1:SHL:1 ; Set <=> OS_Exit has been used to finish a command in this obey file
                                ;   ie when exiting this obey file, OS_Exit should be used
wk_fl_verbose   *       1:SHL:2 ; Set <=> verbose flag specified
wk_fl_cache     *       1:SHL:3 ; Set <=> cache flag set
wk_fl_ResFS     *       1:SHL:4 ; Set <=> cache block is in resourceFS
wk_fl_memory    *       1:SHL:5 ; Set <=> cache "file" from memory into RMA
wk_private      #       4       ; Back pointer to private word
wk_handle       #       4
wk_oldquitR1    #       4
wk_oldquitR2    #       4
wk_olderrorR1   #       4
wk_olderrorR2   #       4
wk_olderrorR3   #       4
wk_cacheblock   #       4       ; cache block in memory (=0 if none, -1 if pending)
wk_ptr          #       4       ; index into cache block
wk_ext          #       4       ; extent of cache block
               [ :LNOT:debug
wk_stack        #       4*8     ; maximum stack of eight registers
               |
wk_stack        #       4*64    ; 64 register stack if debugging
               ]
wk_stacktop     #       0
wk_parameters   #       wk_buflen
wk_inputcom     #       wk_buflen
wk_outputcom    #       wk_buflen
wk_end          #       0

              [ internat
                ! 0, "Internationalised version"
              ]

;;----------------------------------------------------------------------------
;; Code
;;----------------------------------------------------------------------------

; On Service_Reset, discard all blocks in chain

svc_reset
        Push    "R0-R2,R11,LR"
        LDR     R11,[R12]
        TEQ     R11,#0
01
        MOVNE   R0,#ModHandReason_Free
        MOVNE   R2,R11
        LDRNE   R11,[R2,#wk_link]
        SWINE   XOS_Module
        TEQ     R11,#0
        BNE     %BT01
        MOV     R14,#0
        STR     R14,[R12]
        Pull    "R0-R2,R11,PC"

;.............................................................................

        ASSERT Service_Reset < Service_NewApplication

ServiceTable
        DCD     0                               ;flags word
        DCD     UrsulaService - Module_BaseAddr ;offset to handler (skip pre-rejection)
        DCD     Service_Reset                   ;service 1
        DCD     Service_NewApplication          ;service 2
        DCD     0                               ;terminator
        DCD     ServiceTable - Module_BaseAddr  ;anchor (offset to table)
Service
        MOV     R0,R0                           ;magic instruction for Ursula format
        TEQ     R1,#Service_Reset
        TEQNE   R1,#Service_NewApplication
        MOVNE   PC,LR
UrsulaService
        TEQ     R1,#Service_Reset
        BEQ     svc_reset
;
; Here we see if we can find a block for this application
; (identified by quit handler), with its file closed
; (so exhausted), in which case we restore the previous quit handler
; and remove our block.
;
; The following case is nasty:
;
;       *BASIC
;       *Obey fred
;               *run <application program>
;               *<more stuff>
;
; When the application starts up inside the obey file, BASIC's UpCall handler
; gets an UpCall_NewApplication and resets the quit handler to its parent.
; The Obey module must get in first (using UpCallV), and remove its handlers
; temporarily.  It then puts them back when it gets the Service_NewApplication.

        LDR     r1, [r12]
        TEQ     r1, #0
        MOV     r1, #Service_NewApplication     ; NB: MOV not MOVEQ!
        MOVEQ   pc, lr                  ; Just return if module inactive

        Push    "r0-r3,r11,lr"

        LDR     r11, [r12]              ; r11 -> first block

; look for a block with "undone" handlers

01      LDR     r14, [r11, #wk_oldquitR1]
        CMP     r14, #-1
        BNE     %FT02

        Debug   xx,"Restoring handlers"

        MOV     r0,#ExitHandler
        ADD     r1, r11, #wk_exit       ; Where to
        MOV     r2, r12                 ; R12 --> private word
        SWI     XOS_ChangeEnvironment
        STRVC   r1, [r11, #wk_oldquitR1]
        STRVC   r2, [r11, #wk_oldquitR2]

        MOVVC   r0, #ErrorHandler
        MOVVC   r1, r11                  ;
        MOVVC   r2, r11                  ; R11 --> block
        MOVVC   r3, r11                  ;
        SWIVC   XOS_ChangeEnvironment
        STRVC   r1, [r11, #wk_olderrorR1]
        STRVC   r2, [r11, #wk_olderrorR2]
        STRVC   r3, [r11, #wk_olderrorR3]

02      LDR     r11, [r11, #wk_link]
        CMP     r11, #0
        BNE     %BT01

10
; now check for this being the last line of the Obey file

     [ debugexit
        Debug   exit,"EXIT: calling FindExit:"
     ]
        BL      FindExit
        TEQ     r11, #0
        Pull    "r0-r3,r11,pc", EQ      ; block not found
     [ debugexit
        Debug   exit,"EXIT: found exit handler"
     ]

        LDR     r0, [r11, #wk_flags]
        TST     r0, #wk_fl_live
        Pull    "r0-r3,r11,pc", NE      ; block alive - leave it alone

      [ debugxx
        BNE     %FT00
        Debug   xx,"Starting application on last line of Obey file: "
00
      ]
        BL      exit                    ; Kill block if so
        B       %BT10                   ; go round for the next level up

;.............................................................................

; I assume here that the upcall vector is called BEFORE the upcall handler

upcallhandler
        TEQ     r0, #UpCall_NewApplication
        MOVNE   pc, lr

        Push    "r0-r3,r11,lr"

        Debug   xx,"UpCall_NewApplication"

        BL      FindExit                ; assume we have error and exit handlers
        CMP     r11, #0
        Pull    "r0-r3,r11,pc", EQ

        Debug   xx,"Removing handlers temporarily"

        MOV     r0, #ExitHandler        ; temporarily remove my handlers
        LDR     r1, [r11, #wk_oldquitR1]
        LDR     r2, [r11, #wk_oldquitR2]
        SWI     XOS_ChangeEnvironment

        MOV     r0, #ErrorHandler
        LDR     r1, [r11, #wk_olderrorR1]
        LDR     r2, [r11, #wk_olderrorR2]
        LDR     r3, [r11, #wk_olderrorR3]
        SWI     XOS_ChangeEnvironment

        MOV     r14, #-1                ; mark as temporarily removed
        STR     r14, [r11, #wk_oldquitR1]

        CLRV
        Pull    "r0-r3,r11,pc"

;.............................................................................

; Find a block with the current quit handler in it
;
; Entry:- r12 points to private word
;         r13 = stack pointer
;         r14 = return address
;
; Exit:-  r11 = pointer to block, or zero if none exists
;         All other registers preserved

FindExit ROUT

        Push    "r0-r3, lr"

        MOV     r0, #ExitHandler
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        SWI     XOS_ChangeEnvironment

        Debug   xx,"Current exit handler at",R1

        SUB     r1, r1, #wk_exit        ; Point to block

        SUB     r11, r12, #wk_link
10      LDR     r11, [r11, #wk_link]
        TEQ     r11, #0                 ; If zero we've failed to find block
        TEQNE   r11, r1                 ; Have we got it?
        BNE     %b10                    ; Loop if not

        Pull    "r0-r3, pc"             ; Return if not there or found

;.............................................................................

; Find a block with the current error handler in it
;
; Entry:- r12 points to private word
;         r13 = stack pointer
;         r14 = return address
;
; Exit:-  r11 = pointer to block, or zero if none exists
;         All other registers preserved

FindError ROUT

        Push    "r0-r3, lr"

        MOV     r0, #ErrorHandler
        MOV     r1, #0                  ; error handler points to block start
        MOV     r2, #0
        MOV     r3, #0
        SWI     XOS_ChangeEnvironment

        Debug   xx,"Current error handler at",R1

        SUB     r11, r12, #wk_link
10      LDR     r11, [r11, #wk_link]
        TEQ     r11, #0                 ; If zero we've failed to find block
        TEQNE   r11, r1                 ; Have we got it?
        BNE     %b10                    ; Loop if not

        Pull    "r0-r3, pc"             ; Return if not there or found

;-----------------------------------------------------------------------------

; Deal with errors not caught by application
;
; Entry:- r12 = private word pointer
;         r13 = stack pointer
;         r14 = return address
;
; Exit:-  All registers preserved

errorhandler ROUT

      [ debugxx
        ADD     R0,R0,#4
        DebugS  xx,"Error generated:",R0
        SUB     R0,R0,#4
      ]
        Debug   xx,"r10 into error handler ",r10

        Push    "r11,lr"

10      BL      FindError               ; Have we a current block?
        TEQ     r11, #0                 ; (ie. is error handler set?)
        BLNE    exit                    ; Delete it if so
        BNE     %b10                    ; Loop until no current block

        Debug   xx, "Error handler returning..."
        Debug   xx,"r10 out of error handler ",r10

        Pull    "r11,pc"                ; Finished

exithandler     ROUT                    ; called when "*Obey" executed
        Push    "r11,lr"

        Debug   xx,"OS_Exit called"

10      BL      FindExit                ; Have we a current block?
        TEQ     r11, #0                 ; (ie. is exit handler set?)
        BLNE    exit                    ; Delete it if so
        BNE     %b10                    ; Loop until no current block

        CLRV
        Pull    "r11,pc"                ; Finished

;-----------------------------------------------------------------------------
;
; Close down the specified *Obey file, and remove the block from the chain
; If the obey block isn't current then stuff starts to go wrong so make
; sure it is the current obey block.
;
; Entry:-
;       r11 -> obey block to exit
;       r12 = wk_private
;
; Exit:-  All registers and flags preserved
;
; ---- This assumes obey nested only I believe
; ---- Further, it won't work if the quit handler has been
; ---- tampered with by an old style SetEnv (which passes in r2 = 0)

exit    ROUT

        EntryS  "R0-R3"
        BL      exitsub
        EXITS                   ; ignore errors

; -------------------------------------------------------------------------------
;
; exitsub
;
; Entry
;   r11 -> obey block to exit
;   r12 = wk_private
; Exit
;   loads of registers corrupted (r0-r3)
;   very little stack used (5 words = 1 here + 4 for close_file)
;   block exited

exitsub ROUT
        TEQ     r11, #0
        MOVEQ   pc, lr
        Push    "lr"
;
        Debug   xx,"Killing Obey block:",R11
;
        BL      close_file
;
        MOV     r0, #ExitHandler
        LDR     r1, [r11, #wk_oldquitR1]
        LDR     r2, [r11, #wk_oldquitR2]
        Debug   xx,"Exit: restoring exit handler:",R1,R2
        SWI     XOS_ChangeEnvironment
;
        MOV     r0, #ErrorHandler
        LDR     r1, [r11, #wk_olderrorR1]
        LDR     r2, [r11, #wk_olderrorR2]
        LDR     r3, [r11, #wk_olderrorR3]
        Debug   xx,"Exit: restoring error handler:",R1,R2,R3
        SWI     XOS_ChangeEnvironment
;
        MOV     r0, #ModHandReason_Free
        MOV     r2, r11
        LDR     r11, [r2, #wk_link]     ; delete link from chain
;
; Now search for previous block
; If parent block not found, this block is not allocated !!!
;
        SUB     lr, r12, #wk_link
10
        LDR     r1, [lr, #wk_link]
        TEQ     r1, r2                  ; See if [r12] is current pointer
        MOVNE   lr, r1
        BNE     %b10                    ; Loop until
        Debug   xx, "Exit: closing up x into y:", r11, r12
        STR     r11, [lr, #wk_link]     ; Close chain
        SWI     XOS_Module
        Debug   xx, "Exit: block freed"
;
        LDR     lr, [r12]
        TEQ     lr, #0                  ; See if final instance
        BNE     %FT70

        ; No more blocks chained, so remove ourselves from ErrorV and UpCallV
        MOV     r0, #ErrorV
        ADRL    r1, errorhandler
        MOV     r2, r12
        SWI     XOS_Release
     [ debugxx
        Debug   xx, "Exit: errorhandler released"
     ]

        MOV     r0, #UpCallV
        addr    r1, upcallhandler
        MOV     r2, r12
        SWI     XOS_Release
      [ debugxx
        Debug   xx, "Exit: upcallhandler released"
      ]
;
70
        Debug   xx, "Exit: exitsub returning..."
        Pull    "pc"

;-----------------------------------------------------------------------------

Die
        Push    "LR"
;
        LDR     R14,[R12]               ; am I obeying any files?
        TEQ     R14,#0

      [ internat
        ADRNE   R0, ErrorBlock_CantKill
        BLNE    LookupError             ; look up error
      |
        XError  CantKill,NE
      ]
        Pull    "PC"

      [ internat
ErrorBlock_CantKill
        & ErrorNumber_CantKill
        = "ModInUs", 0
        ALIGN
      |
        MakeErrorBlock  CantKill
      ]

;-----------------------------------------------------------------------------

; Grab a block from the RMA, to be used for remembering old quit handler etc.
; Entry:  R12 --> private word
; Exit:   R11 --> new block
;         [R11,#wk_link] --> previous block
;         [R12] --> new block
;         quit handler installed, and old one remembered
;

enter
        Push    "R1-R3,LR"

        MOV     R0,#ModHandReason_Claim
        LDR     R3,=wk_end
        SWI     XOS_Module
        Pull    "R1-R3,PC",VS
        MOV     r11, #0
        STR     r11, [r2, #wk_flags]    ; block not live, not useexit, not verbose and not cache

        LDR     R11,[R12]
        STR     R11,[R2,#wk_link]       ; remember previous block
        STR     R12,[R2,#wk_private]    ; remember private pointer
        TEQ     r11, #0                 ; see if first instance (for ErrorV)
        MOV     R11,R2
        STR     R11,[R12]               ; remember private w/s

        MOV     R14,#0
        STR     R14,[R11,#wk_handle]    ; no file handle yet
        STR     R14,[R11,#wk_cacheblock]
        STR     R14,[R11,#wk_ptr]
        STR     R14,[R11,#wk_ext]
        BNE     %FT01

        ; It's the first obey file, so claim UpCallV and ErrorV
        MOV     R0,#ErrorV
        ADRL    R1,errorhandler
        MOV     R2,R12
        SWI     XOS_Claim               ; Claim error vector on first instance

        MOVVC   R0,#UpCallV             ; I don't think the flags are preserved!
        addr    R1,upcallhandler,VC
        MOVVC   R2,R12
        Debug   xx,"Claiming UpCall handler:",R0,R1,R2
        SWIVC   XOS_Claim               ; Claim upcall vector on first instance

01
        BVS     %FT02
        ADR     r0, WkExitHandler       ; Where from
        ADD     r1, r11, #wk_exit       ; Where to
        LDMIA   r0, {r0, r2}            ; Two words
        STMIA   r1, {r0, r2}
        MOV     r0, #1
        ADD     r2, r1, #4
        SWI     XOS_SynchroniseCodeAreas
        ADR     r0, MyExitHandler        
        STR     r0, [r11, #wk_exitproc] ; Put the right address in the rma
        MOV     R0,#ExitHandler
        MOV     R2,R12                  ; R12 --> private word
        SWI     XOS_ChangeEnvironment
        STRVC   R1,[R11,#wk_oldquitR1]
        STRVC   R2,[R11,#wk_oldquitR2]

; NB: we must set up our own error handler purely as a marker
;     THIS IS NEVER CALLED! - the ErrorV code removes the handler first

        MOVVC   R0,#ErrorHandler
        MOVVC   R1,R11                  ;
        MOVVC   R2,R11                  ; R11 --> block !!!
        MOVVC   R3,R11                  ;
        SWIVC   XOS_ChangeEnvironment
        STRVC   R1,[R11,#wk_olderrorR1]
        STRVC   R2,[R11,#wk_olderrorR2]
        STRVC   R3,[R11,#wk_olderrorR3]
;
02
        Debuga  xx,"New Obey block:",R11
;
        BLVS    exit                    ; lose block if errors occur now
;
        Pull    "R1-R3,PC"

        LTORG

;-----------------------------------------------------------------------------

WkExitHandler
        ADR     r12, .-4                ; Assumed placed starting second word
        LDR     pc, [r12, #wk_exitproc] ; Go to the real code

MyExitHandler ROUT
        MOV     r11, r12
        LDR     r12, [r11, #wk_private]
        ADD     sp, r11, #wk_stacktop   ; setup a useable stack pointer (very small stack!)

        LDR     r14, [r11, #wk_flags]
        ORR     r14, r14, #wk_fl_useexit
        STR     r14, [r11, #wk_flags]   ; quit handler has been invoked and hence quit handler
                                        ; should be used when finishing this obey file
        TST     r14, #wk_fl_live
        BNE     loop1                   ; Next command if block not dead

        BL      exitsub                 ; deallocate workspace
        SWI     OS_Exit

;-----------------------------------------------------------------------------

; Entry: R0 --> parameters
;        R1 = number of parameters

  [ LongCommandLines
    ;avoid the exceedingly naff method of XOS_CLI to *Set Obey$Dir, since it
    ;is needlessly slow (use XOS_SetVarVal instead)
    ;
obeydir_name DCB "Obey$$Dir",0
        ALIGN
  |
obeydir DCB     "Set Obey$$Dir    "
        ASSERT  (.-obeydir)=16
  ]

csdname DCB     "@",0
        ALIGN

Obey_Code ROUT
;
; Entry:- r12 points to private word
;
        CMP     R1,#0                   ; *Obey alone is different
      [ debugxx
        BNE     %FT00
        Debug   xx,"*Obey alone ==> close all obey files"
00
      ]
        BEQ     exithandler             ; Remove all current blocks and return
;
        Push    "R7-R11,LR"
;
        MOV     R1,R0                   ; R1 --> parameter list
;
        BL      enter                   ; R11 --> new block
        Pull    "R7-R11,PC",VS

        LDR     r0, [r11, #wk_flags]
        ORR     r0, r0, #wk_fl_live
        STR     r0, [r11, #wk_flags]    ; Block now live
;
        BL      decode_commands
;
        BL      open_file               ; attempt to open it then
        BLVS    exit                    ; free block etc.
        Pull    "R7-R11,PC",VS
;
; now scan to the end of the filename, and copy the rest of the parameters
;
        MOV     R2,R1
01
        LDRB    R14,[R1],#1
        CMP     R14,#32
        BHI     %BT01
        SUB     R3,R1,#1                ; remember for later
02
        LDRB    R14,[R1,#-1]!
        TEQ     R14,#"."
        BEQ     %FT03
        CMP     R1,R2
        BGT     %BT02
        ADR     R2,csdname              ; can't allow null directory name!
        ADD     R1,R2,#1

03
  [ LongCommandLines
        SUB     sp, sp, #LongPNameSize  ; create local workspace
        MOV     R4, sp
        MOV     R5, #LongPNameSize
  |
        SUB     sp,sp,#256              ; create local workspace
        ADR     R14,obeydir
        LDMIA   R14,{R4-R7}             ; 16 bytes
        STMIA   sp,{R4-R7}
        ADD     R4,sp,#16
        MOV     R5,#256-16
  ]
04
        SUBS    R5,R5,#1                ; ensure stack isn't corrupted!
      [ internat
        ADRLE   R0,ErrorBlock_BuffOverflow
        BLLE    LookupError
      |
        XError  BuffOverflow,LE
      ]
        BVS     %FT44
        CMP     R2,R1
        LDRCCB  R14,[R2],#1             ; copy pathname (filename exluding leaf)
        STRCCB  R14,[R4],#1
        BCC     %BT04
        MOV     R14,#0
        STRB    R14,[R4]
;
  [ LongCommandLines
        Push    "R1-R4"
        ADR     R0, obeydir_name        ; -> var name
        ADD     R1, sp, #4*4            ; -> value (allowing for Push of 4 regs)
        MOV     R2, #0                  ; length irrelevant for R4=0
        MOV     R3, #0                  ; context
        MOV     R4, #0                  ; value is string, to be GSTrans'd
        SWI     XOS_SetVarVal
        Pull    "R1-R4"
44
        ADD     sp, sp, #LongPNameSize
  |
        MOV     R0,sp                   ; *Set Obey$Dir <parent dir>
        SWI     XOS_CLI
44
        ADD     sp,sp,#256
  ]

        BLVS    exit                    ; free block etc.
        Pull    "R7-R11,PC",VS
;
        MOV     R1,R3                   ; R1 --> parameters
        ADD     R2,R11,#wk_parameters
        MOV     R3,#wk_buflen
05
        SUBS    R3,R3,#1
      [ internat
        ADRLE   R0,ErrorBlock_BuffOverflow
        BLLE    LookupError
      |
        XError  BuffOverflow,LE
      ]
        BVS     loopreturn
        LDRB    R14,[R1],#1
        STRB    R14,[R2],#1
        CMP     R14,#32
        BCS     %BT05
;
; now execute *commands in turn from the file
; do parameter substitution from the original parameter list,
; and watch out for abortions such as:
;       Service_NewApplication
;       OS_Exit
;       OS_GenerateError
;
loop1
        SWI     XOS_ReadEscapeState
        BCC     noesc
;
        MOV     R0,#126                 ; acknowledge escape
        SWI     XOS_Byte
;
      [ internat
        ADR     R0,ErrorBlock_Escape
        BL      LookupError
      |
        XError  Escape
      ]
;
        B       loopreturn

      [ internat
ErrorBlock_Escape
        & ErrorNumber_Escape
        = "Escape", 0
        ALIGN
      |
        MakeErrorBlock Escape
      ]
noesc
;
; Places where a return is made by Pull must be modified to take account
; of the fact that that a quit may have occurred, in which case
; the stack etc. is invalid and there is no return address.
;
  [ LongCommandLines
        LDR     R2,=wk_inputcom
        ADD     R2,R11,R2
  |
        ADD     R2,R11,#wk_inputcom
  ]
        MOV     R3,#wk_buflen
        LDR     r1, [r11, #wk_handle]
        CMP     r1, #0
        BEQ     getline1
getline0
        SWI     XOS_BGet
        BVS     abortonbget
        MOVCS   r0, #0
        SUBS    r3, r3, #1
        BLE     Block_Overflow_Error
        CMP     r0, #9
        MOVEQ   r0, #" "
        CMP     r0, #" "
        STRHSB  r0, [r2], #1
        BHS     getline0
        B       getline3
getline1
        ADD     r0, r11, #wk_cacheblock
        LDMIA   r0, {r1, r4, lr}        ; -> block, ptr, size
getline2
        CMP     r4, lr
        LDRLOB  r0, [r1, r4]
        ADDLO   r4, r4, #1
        MOVHS   r0, #0
        SUBS    r3, r3, #1
        BLE     Block_Overflow_Error
        CMP     r0, #9
        MOVEQ   r0, #" "
        CMP     r0, #" "
        STRHSB  r0, [r2], #1
        BHS     getline2
        STR     r4, [r11, #wk_ptr]
getline3
;
;
  [ LongCommandLines
        LDR     R3,=wk_inputcom
        ADD     R3,R11,R3               ; R3 --> template string
  |
        ADD     R3,R11,#wk_inputcom     ; R3 --> template string
  ]
        SUB     R4,R2,R3                ; R4 = length (no terminator)
;
  [ LongCommandLines
        LDR     R1,=wk_outputcom
        ADD     R1,R11,R1               ; R1 --> result buffer
  |
        ADD     R1,R11,#wk_outputcom    ; R1 --> result buffer
  ]
        MOV     R2,#wk_buflen           ; R2 = length
        ADD     R0,R11,#wk_parameters   ; argument list
        TEQ     PC,PC
        BEQ     %FT20
        ORR     r0, r0, #&80000000      ; "don't append unsubstituted args" flag
        SWI     XOS_SubstituteArgs
        BVC     %FT25
        BVS     loopreturn
20      MOV     r5, #&80000000          ; "don't append unsubstituted args" flag
        SWI     XOS_SubstituteArgs32
        BVS     loopreturn

25      ; nul-terminate the string
        MOV     r0, #0
        SUB     r2, r2, #1
        STRB    r0, [r1, r2]

;
      [ debugxx
        MOV     R14,#0
        LDR     R14,[R14,#&FF8]
        Debuga  xx,"Domain",R14
        MOV     R14,sp
        Debuga  xx," sp",R14
        ADD     R0,R11,#wk_outputcom
        DebugS  xx,": ",R0
      ]
;
; Now see if file exhausted
;
        BL      get_eof
        BVS     loopreturn
        TEQ     R2, #0                  ; NE => EOF
        BEQ     %f95

        BL      close_file              ; ensure that stream is closed

        ; Mark block as dead so that app start will remove it as it is
        ; no longer required at that stage. Must keep block around
        ; for CLIs which don't copy the command line.
        LDR     lr, [r11, #wk_flags]
        BIC     lr, lr, #wk_fl_live
        STR     lr, [r11, #wk_flags]    ; file now dead (no more to read)
95

        LDR     r0, [r11,#wk_flags]
        AND     r0, r0, #wk_fl_verbose
        CMP     r0,#0                   ; clears the V flag!
        BEQ     %FT96                   ; if verbose =0 then don't echo!

        SWI     OS_WriteS               ; print Obey: <foo>\n
        = "Obey: ", 0
        ALIGN
  [ LongCommandLines
        LDRVC   R0,=wk_outputcom
        ADDVC   R0,R11,R0
  |
        ADDVC   R0,R11,#wk_outputcom
  ]
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
96
  [ LongCommandLines
        LDRVC   R0,=wk_outputcom
        ADDVC   R0,R11,R0
  |
        ADDVC   R0,R11,#wk_outputcom
  ]
        SWIVC   XOS_CLI                 ; stack must be at the same level!!
;
      [ debugxx
        MOV     R14,#0
        LDR     R14,[R14,#&FF8]
        Debuga  xx,"Domain",R14
        MOV     R14,sp
        Debuga  xx," sp",R14
        Debug   xx," - control returned from XOS_CLI"
      ]
;
; Only arrive here if last command was not an application start
;
; THIS IS NECESSARY - Please don't remove it.
; Consider the case where *Obey is executed within an obey file. In
; this case the block will have been freed so we must not continue
; accessing it.
;
; What we must discover is whether an error within the OS_CLI
; has effectively killed the block.
;
; Check if our block's still around as it might have been removed
; by a *Obey command
;
        SUB     r14, r12, #wk_link
97
        LDR     r14, [r14, #wk_link]
        TEQ     r14, #0
        SWIEQ   OS_Exit                 ; reached end of list and didn't find our block
        TEQ     r14, r11
        BNE     %BT97
;
        BVS     loopreturn              ; exit with error and block
;
        ; Check if still live and loop if we are
        LDR     lr, [r11, #wk_flags]
        TST     lr, #wk_fl_live
        BNE     loop1

loopreturn
;
; Return from finished obey file. May have error to return.
;
; First determine how to return
;
        LDR     r7, [r11, #wk_flags]
        BIC     r7, r7, #wk_fl_live
        STR     r7, [r11, #wk_flags]    ; Block dead
        TST     r7, #wk_fl_useexit      ; See if exit handler should be used for exiting
        BEQ     returntocaller

        SWIVS   OS_GenerateError
        SWI     OS_Exit                 ; Use OS_Exit if so

Block_Overflow_Error
        ADR     R0,ErrorBlock_BuffOverflow
        BL      LookupError
        B       loopreturn

;
; Now check if I own the current quit handler
;
returntocaller
      [ No32bitCode
        Push    "r0-r3,pc"              ; preserve flags (V bit in particular)
      |
        MRS     r14, CPSR
        Push    "r0-r3,r14"
      ]
        MOV     r0, #ExitHandler
        MOV     r1, #0                  ; No change
        MOV     r2, #0
        MOV     r3, #0
        SWI     XOS_ChangeEnvironment   ; read the current handler
        SUB     r1, r1, #wk_exit        ; Point to potential workspace start
        TEQ     r1, r11                 ; See if it's mine
        Pull    "r0-r3,r7"
        BLEQ    exit                    ; close file etc. if so
      [ No32bitCode
        TEQP    r7,#0                   ; restore V bit
      |
        MSR     CPSR_f, r7
      ]
        Pull    "R7-R11,PC"             ; return to caller (I hope!)

      [ internat
ErrorBlock_BuffOverflow
        & ErrorNumber_BuffOverflow
        = "BufOFlo", 0
        ALIGN
      |
        MakeErrorBlock BuffOverflow
      ]

abortonbget
        LDR     R1,[R0]
        TEQ     R1,#ErrorNumber_Channel
        BNE     loopreturn
        SUBS    R0,R0,R0                ; MOV R0,#0 : CLRV
        STR     R0,[R11,#wk_handle]
        B       loopreturn              ; (close down quietly)

; ----------------------------------------------------------------------------
;
; Decode commands.
;
; R1 -> command line to be scanned, R11 -> record to update.
;
; Looks for -v or -c to add caching to the record, has to be careful if -v-c
; has a space midway as this invalidates the command and should be assumed
; to be a filename.  If -Valid-Nonvalid this is also ignored as it could be
; the prefix to a filing system (single character, although still valid).
;
; Can assume that the command line pointed to has leading spaces stripped.
;

decode_commands ROUT

        Push    "R0,R2-R3,LR"

        DebugS  command, "decoding command line ", r1
        Debug   command, "record to fill in at", r11

        MOV     R0,R1                   ; -> command line
        MOV     R3,#-1                  ; flag to indicate things are valid
00
        LDRB    LR,[R0]                 ; must be a "-" followed.
        TEQ     LR,#"-"
        BNE     %80

        LDRB    LR,[R0,#2]
        TEQ     LR,#"-"
        TEQNE   LR,#" "
        BNE     %80                     ; if not valid reset the pointer and return

        LDRB    R2,[R0,#1]
        LowerCase R2,LR                 ; convert to suitable character
        TEQ     R2,#"c"
        TEQNE   R2,#"v"                 ; cache of verbose?
        TEQNE   R2,#"m"                 ; or memory-based?
        BNE     %80

        LDR     lr, [r11, #wk_flags]
        TEQ     R2,#"c"
        ORREQ   lr, lr, #wk_fl_cache
        TEQ     R2,#"v"
        ORREQ   lr, lr, #wk_fl_verbose
        TEQ     R2,#"m"
        ORREQ   lr, lr, #wk_fl_memory
        STR     lr, [r11, #wk_flags]

        ADD     R0,R0,#2                ; skip to next command sequence
        B       %00                     ; loop back until all checked
80
        MOV     R1,R0                   ; -> line to be used
85
        LDRB    LR,[R1]
        CMP     LR,#32                  ; is this a valid character?
        ADDEQ   R1,R1,#1
        BEQ     %85                     ; no, its a space so loop again

        Pull    "R0,R2-R3,PC"

; ----------------------------------------------------------------------------
;
; Handle file related IO operations.
;
; r1 -> filename to be opened/loaded, r11 -> record for object.
;
; if wk_fl_cache set in wk_flags then file is cached, else simply opened
; if wk_fl_memory set in wk_flags, then the "filename" is really the address of
;    a 0-terminated block of memory.  This is cached into a block of RMA.
;
; This routine will try and open the file if the cache block is =0, otherwise
; =-1 then it will attempt to create a block of RMA and then read it in.
;

open_file ROUT

        Push    "R1-R6,LR"

        LDR     r0,  [r11, #wk_flags]   ; Was the command -m address
        TST     r0, #wk_fl_memory
        BNE     cache_memory

        MOV     R0,#OSFind_ReadFile
        SWI     XOS_Find                ; r1 -> filename so attempt to open
        Pull    "R1-R6,PC", VS
        MOV     r6, r0
        MOV     r1, r6
        MOV     r0, #FSControl_ReadFSHandle
        SWI     XOS_FSControl
        BVS     not_resourcefs
        CMP     r2, #fsnumber_resourcefs
        BNE     not_resourcefs          ; ResourceFS -> try 'cache' it

        ; It's a resourceFS file, hence store its base address
        LDR     lr, [r11, #wk_flags]
        ORR     lr, lr, #wk_fl_ResFS
        STR     lr, [r11, #wk_flags]
        STR     r1, [r11, #wk_cacheblock]
        LDR     r0, [r1, #-4]
        SUB     r0, r0, #4
        STR     r0, [r11, #wk_ext]
        MOV     r1, r6
        B       cache_close_file

not_resourcefs
        LDR     r0, [r11, #wk_flags]
        TST     r0, #wk_fl_cache
        BNE     cache_file              ; '-c', try cache it

ret_no_err
        STR     r6,[r11,#wk_handle]
        CLRV
        Pull    "R1-R6,PC"

cache_memory
        ; R1 -> start of numeric string giving address of "file"
        MOV     R0, #10
        ORR     R0, R0, #1:SHL:31
        SWI     OS_ReadUnsigned
        Pull    "R1-R6,PC",VS
        ; Now R2 is the address of the "file", so count it (assume 0 termination)
        MOV     LR, R2                  ; pointer
00
        LDRB    R1, [LR], #1
        TEQ     R1, #0                  ; terminator reached?
        BNE     %BT00
        SUB     LR, LR, #1              ; Don't count the null

        MOV     R4, R2                  ; keep original pointer handy
        SUB     R3, LR, R2              ; get length
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        Pull    "R1-R6,PC",VS           ; can't continue if no RMA

        ; Now copy the data across.  Remember to store the address of the cache block
        STR     r3, [r11, #wk_ext]
        STR     r2, [r11, #wk_cacheblock]
01
        LDRB    lr, [r4], #1
        TEQ     lr, #0
        STRNEB  lr, [r2], #1
        BNE     %BT01

        Pull    "R1-R6,PC"

cache_file
        ; Attempt to cache the file - resort to uncached
        ; on most errors, except if the GBPB fails.
        MOV     r0, #OSArgs_ReadEXT
        MOV     r1, r6
        SWI     XOS_Args
        BVS     ret_no_err              ; May not be an error (pipe:gunge)
        MOV     r0, #ModHandReason_Claim
        MOV     r3, r2
        SWI     XOS_Module
        BVS     ret_no_err              ; May be able to continue - only a memory shortage
        MOV     r6, r2
        STR     r3, [r11, #wk_ext]
        MOV     r0, #OSGBPB_ReadFromPTR
        SWI     XOS_GBPB
        BVS     ret_err                 ; Bad news if can't read file
        STR     r6, [r11, #wk_cacheblock]
cache_close_file
        MOV     r0, #0
        SWI     XOS_Find
        Pull    "R1-R6,PC"
ret_err
        Push    "R0"
        MOV     r0, #ModHandReason_Free
        MOV     r2, r6
        SWI     XOS_Module
        MOV     r0, #0
        SWI     XOS_Find
        MOV     r0, r5
        SETV
        Pull    "R0-R6,PC"

; ----------------------------------------------------------------------------
;
; Ensure that the file is correctly closed.
;
; r11 -> file record to be closed.
;

close_file ROUT
        Push    "R0-R2,LR"

        MOV     R0,#0
        LDR     R1,[R11,#wk_handle]
        TEQ     R1,#0                   ; is a file object opened?
        STRNE   R0,[R11,#wk_handle]
        SWINE   XOS_Find                ; attempt to close it then

        LDR     R2,[R11,#wk_cacheblock]
        CMP     R2,#0                   ; is it valid?
        Pull    "R0-R2,PC", EQ
        LDR     r1, [r11, #wk_flags]    ; Don't free if ResourceFS block
        TST     r1, #wk_fl_ResFS
        MOV     R0,#0
        STR     R0,[R11,#wk_cacheblock] ; yes, so stomp handle and release it!
        MOVEQ   R0,#ModHandReason_Free
        SWIEQ   XOS_Module

        Pull    "R0-R2,PC"


; ----------------------------------------------------------------------------
;
; Get EOF, r2 =0 if not EOF, else <>0.
;
; Can corrupt R2 and R1.
;

get_eof ROUT
;
        Push    "LR"

        LDR     R1,[R11,#wk_handle]
        TEQ     R1,#0                   ; is it a read of the EOF?
        BEQ     %10
;
        MOV     R0,#OSArgs_EOFCheck     ; get the EOF into R2
        SWI     XOS_Args
;
        Pull    "PC"                    ; return flags as required
10
        ADD     R1,R11,#wk_ptr
        LDMIA   R1,{R1,R2}              ; get ptr and ext
        CMP     R1,R2
        MOVLO   R2,#0                   ; if not EOF, ie. PTR<>EXT then return R2=0
        MOVHS   R2, #-1                 ; if EOF then return r2<>0. Note 0 size files!
;
        CLRV                            ; ensure that V clear on return
        Pull    "PC"
;

      [ internat

; ----------------------------------------------------------------------------
;
; Lookup error, r0 -> error block to lookup.  Returns with
; r0 -> error block and V set.
;

LookupError ROUT

        Push    "R1-R7,LR"

        MOV     R1,#0                   ; use global area
        MOV     R2,#0
        ADDR    R4,Title                ; -> title string
        MOV     R5,#0
        MOV     R6,#0
        MOV     R7,#0                   ; no substitution for %1..%3
        SWI     XMessageTrans_ErrorLookup

        Pull    "R1-R7,PC"

      ]

      [ debug
        InsertNDRDebugRoutines
      ]

        END

