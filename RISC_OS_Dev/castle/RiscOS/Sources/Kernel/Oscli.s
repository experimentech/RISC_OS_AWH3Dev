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
        TTL     => Oscli - main Oscli code and system commands.

;
;mjs performance enhancements for Ursula (ChocolateOscli)
;
Oscli_CHashValMask        *       &1f                  ;32-wide Command hashing, for commands within kernel
Oscli_MHashValMask        *       &ff                  ;256-wide Module hashing, for command groups in other modules
                                                       ; - kernel cmd hashed tables must be reorganised if Oscli_CHashValMask is changed
                                                       ; - UtilityModule MUST be first in module chain, if hashing in use


        MACRO
$l      CheckUID $reg, $tmp
$l      LDR      $tmp, =ZeroPage
        LDR      $tmp, [$tmp, #OscliCBbotUID]
        CMP      $reg, $tmp
        MEND
; exits with HI if buffer OK.

;******************************************************************************
; redirection utility routines

; In:   R10 points at filename, V clear
;       R1 is type

; Out:  R0, R1, R12 corrupted, redirection done, flags preserved (or V set)

doredirect ROUT
           EntryS "R1, R2"
60         LDRB    R0, [R10], #1
           CMP     R0, #" "
           BEQ     %BT60
           MOV     R2, R1
           LDR     R1, =RedirectBuff
61         CMP     R0, #" "             ; we know it's terminated by space
           STRNEB  R0, [R1], #1
           LDRNEB  R0, [R10], #1
           BNE     %BT61
           SUB     R10, R10, #1
           MOV     R0, #13
           STRB    R0, [R1]
           LDR     R1, =RedirectBuff
           LDR     R0, =ZeroPage
           ASSERT  (ZeroPage :AND: 255) = 0
           CMP     R2, #&40
           LDREQB  R1, [R0, #RedirectInHandle]
           LDRNEB  R1, [R0, #RedirectOutHandle]
           STREQB  R0, [R0, #RedirectInHandle]
           STRNEB  R0, [R0, #RedirectOutHandle]
         [ ZeroPage <> 0
           MOV     R0, #0
         ]
           CMP     R1, #0
           SWINE   XOS_Find             ; close any previous File
           MOV     R12, R1              ; don't really care if handle was invalid
           LDR     R1, =RedirectBuff
           ORR     R0, R2, #open_mustopen + open_nodir
           SWI     XOS_Find             ; Open the File
           BVS     abort_redirect       ; bad name etc
           CMP     R0, #0               ; worked?
           BEQ     %FT63
           CMP     R2, #&40
           LDR     R1, =ZeroPage
           STREQB  R0, [R1, #RedirectInHandle]
           BEQ     %FT00
           STRNEB  R0, [R1, #RedirectOutHandle]
           MOVNE   R0, #WrchV
           ADRNEL  R1, RedirectWrch
           CMP     R12, #0              ; Ensure only vectored the once
           MOVEQ   R2, #0
           SWIEQ   XOS_Claim
           BVS     abort_redirect       ; Claim will leave "Sysheap full" msg.
00
           LDR     R2, [stack, #Proc_RegOffset]
           CMP     R2, #&C0
           EXITS   NE

; >> file, so move to EOF

           LDR     R1, =ZeroPage
           LDRB    R1, [R1, #RedirectOutHandle]
           MOV     R0, #2               ; read extent
           SWI     XOS_Args
           MOVVC   R0, #1               ; write ptr
           SWIVC   XOS_Args
           EXITS   VC

           B       abort_redirect

           MakeErrorBlock   RedirectFail

63         ADR     R0, ErrorBlock_RedirectFail
         [ International
           BL      TranslateError
         ]
abort_redirect                          ; current error set
           EXITVS


ParseRDNSpec        ROUT
; In : R11 points at string to test.
; Out : EQ/NE for "is it a rdnspec?". V always clear.
; If EQ : R11 points after filename
;         R10 points at start of filename
;         R1=&40 => redirect input,
;           =&80 => redirect output,
;           =&C0 => redirect & append output
         MOV        R1, #&40
01       LDRB       R10, [R11], #1
         CMP        R10, #" "
         BEQ        %BT01               ; skip leading spaces
         CMP        R10, #"<"
         BEQ        %FT04
         CMP        R10, #">"
         MOVNE      PC, lr
         MOV        R1, #&80
         LDRB       R10, [R11], #1
         CMP        R10, #">"
         MOVEQ      R1, #&C0
04       LDREQB     R10, [R11], #1
         CMP        R10, #" "
         MOVNE      PC, lr
         SUB        R10, R11, #1        ; filename start ptr
         Push      "R0"
02       LDRB       R0, [R11], #1
         CMP        R0, #" "
         BGT        %BT02
         Pull      "R0"
         MOV        PC, lr              ; it's EQ if had space at end.

         MakeErrorBlock StackFull

OscliStackFull
         ADR        R0, ErrorBlock_StackFull
       [ International
         BL         TranslateError
       |
         SETV                           ; In place of TranslateError
       ]
         Pull      "pc"

;******************************************************************************
; Main OSCLI code

VecOsCli ROUT

; first check for rheum on the stack.
; Oscli will have pushed 5 registers when it calls module code : let's
; guarantee 256 bytes (=64 registers) for the module code
; so check half a K left, leaving 236 bytes for any interrupt processing.

         CheckSpaceOnStack  512, OscliStackFull, R10

         Push      "R0-R2"      ; lr on stack from caller

; first skip * and space

01       LDRB       R10, [R0], #1
         CMP        R10, #" "
         CMPNE      R10, #"*"
         BEQ        %BT01
         CMP        R10, #"%"
         LDREQB     R10, [R0]           ; fixed 29-Mar-89; was LDREQ
         CMP        R10, #13
         CMPNE      R10, #10
         CMPNE      R10, #0
         CMPNE      R10, #"|"
         Pull      "R0-R2, PC", EQ   ; V clear return

; now check for redirection.
; Redirection setter ::= "{ " [ >= 1 Redirection spec] "}"
; where
; Redirection spec ::=  "> "filename" " | "< "filename" " | ">> "filename" "
; Also check terminator in first LongCLISize chars.
         SUB        R11, R0, #1
         MOV        R1, #0
         ADD        R2, R0, #LongCLISize
02       LDRB       R10, [R11], #1
         CMP        R11, R2
         BEQ        OscliLineTooLong
         CMP        R10, #13
         CMPNE      R10, #10
         CMPNE      R10, #0
         BEQ        %FT58
         CMP        R10, #""""
         EOREQ      R1, R1, R10
         CMP        R10, #"{"
         CMPEQ      R1, #0
         BNE        %BT02
         Push      "R11"
         LDRB       R10, [R11], #1
         CMP        R10, #" "
         BLEQ       ParseRDNSpec
         Pull      "R11", NE
         BNE        %BT02
60       BL         ParseRDNSpec
         BEQ        %BT60
         CMP        R10, #"}"
         Pull      "R11"
         BNE        %BT02
; R11 points 1 char after {
         Push      "R5, R6"
         BL         GetOscliBuffer    ; get a buffer
         SUB        R0, R0, #1
         MOV        R2, #0
50       LDRB       R10, [R0], #1
         CMP        R0, R11
         STRNEB     R10, [R5, R2]
         ADDNE      R2, R2, #1
         BNE        %BT50

61       BL         ParseRDNSpec
         BLEQ       doredirect
         BVS        RedirectionError  ; close any redirection set up
         BEQ        %BT61

53       LDRB       R10, [R11], #1
         CMP        R10, #" "
         BEQ        %BT53
         SUB        R11, R11, #1

52       LDRB       R10, [R11], #1
         STRB       R10, [R5, R2]
         ADD        R2, R2, #1
         CMP        R2, #OscliBuffSize
         BEQ        %FT51
         CMP        R10, #13
         CMPNE      R10, #10
         CMPNE      R10, #0
         BNE        %BT52
         MOV        R2, R6           ; buffer UID
         ADD        R0, R5, #1        ; point after 1st char.
         Pull      "R5, R6"
         B          %FT03

51       MOV       R2, R6            ; longer than 256
         ADR       R0, ErrorBlock_OscliLongLine
       [ International
         BL        TranslateError
       |
         SETV
       ]
RedirectionError
         BL        ReleaseBuff
         BL        OscliTidy        ; shut down the redirection just done.
         Pull     "R5, R6"
OscliFailure
         STR       R0, [stack]
         SETV
         Pull     "R0-R2, PC"

OscliLineTooLong
         ADR       R0, ErrorBlock_OscliLongLine
       [ International
         BL        TranslateError
       ]
         B         OscliFailure
         MakeErrorBlock  OscliLongLine

58       MOV       R2, #-1     ; naff buffer UID.
; Redirection dealt with. R0 points after 1st ch command
03
         Push     "R2"        ; save buffer UID

; now check for filing system name as prefix
         Push     "R3"
         MOV       R3, #0     ; j.i.c. fileswitch is dead!!
         SUB       R1, R0, #1
         MOV       R0, #FSControl_StarMinus
         SWI       XOS_FSControl

; here we have:
; V set if -nafffsname encountered
; VC: R2 = -1 if no fs name found
;     R3 = 0 if no specials encountered

         BVS       letmodprefatit
         CMP       R3, #0
         BEQ       letmodprefatit
         Pull     "R3"
         Push     "R2"        ; save "temp FS set" indicator
         ADR       R0, ErrorBlock_NoOscliSpecials
       [ International
         BL        TranslateError
       |
         SETV
       ]
         B         OscliExit
         MakeErrorBlock NoOscliSpecials

letmodprefatit
         Pull     "R3"
         Push     "R2"        ; save "temp FS set" indicator
         BL        CheckForModuleAsPrefix
         BVS       OscliExit

; special char checks
pfssss   LDRB      R10, [R1], #1
         CMP       R10, #" "
         BEQ       pfssss
         SUB       R0, R1, #1
         CMP       R2, #-1
         RSBLT     R11, R2, #0
         Push     "R2",LT
         BLT       OnlyOneModuleWanted

         CMP       R10, #"/"
         BEQ       %FT06

; see if skip macro expansion
         CMP       R10, #"%"
         LDREQB    R10, [R0], #1
         BEQ       %FT05

         CMP       R10, #"."    ; fudge .
         BEQ       %FT07

; try macro expansion : if find it, expand into a buffer.
; Also scan for parameters while expanding.
; R0 ptr to command, R10 first char.
; If success : Recursively call OSCLI for each line in expansion.

      Push  "R0, R3-R6"

  [ Oscli_QuickAliases
    ;
    ;at least make a vague attempt not to run like a drain - since we can do a binary
    ;chop search for an exactly known var name, do this unless command is abbreviated
    ;
      ADR    R6,AliasStr_QA
      LDR    R3,=AliasExpansionBuffer      ; construct the alias name here
      MOV    R5,#6
oqa_loop1                                  ; bung in "ALIAS$"
      LDRB   R4,[R6],#1
      STRB   R4,[R3],#1
      SUBS   R5,R5,#1
      BNE    oqa_loop1
      MOV    R6,R0
      ADRL   R2, Up_ItAndTerm_Check_Table
oqa_loop2                                  ; bung in command, upper cased
      LDRB   R4,[R6],#1
      CMP    R4,#&80                       ; char in table ?
      LDRCCB R4,[R2,R4]
      STRB   R4,[R3],#1
      CMP    R4,#0
      BNE    oqa_loop2
      LDRB   R4,[R3,#-2]                   ; pick up last char of command
      CMP    R4,#"."
      BEQ    oqa_treacletime               ; it's abbreviated, go to slow code
      LDR    R3,=AliasExpansionBuffer
      Push   "r6,r7"
      BL     VarFindIt_QA                  ; quick binary chop type stuff
      Pull   "r6,r7",EQ
      BEQ    oqa_quicksilvertime_noalias   ; no alias - carry on
;found alias
      MOV    R0,#-1                        ; special, VarFindIt skipping call (r5,r6,r7 from VarFindIt_QA)
      MOV    R1,R3                         ; output buffer
      MOV    R2,#LongCLISize
      MOV    R3,#0
      MOV    R4,#VarType_Expanded
      SWI    XOS_ReadVarVal                ; expand it
      Pull   "r6,r7"
      SUB    R6,R6,#1                      ; arg ptr
      B      oqa_quicksilvertime_alias
oqa_treacletime
;
  ] ;Oscli_Quickaliases

    [ International
      LDR    R3,=ZeroPage
      LDRB   R6,[R3,#ErrorSemaphore]            ; We are about to get lots of buffer overflow errors,
      SUB    R6,R6,#1
      STRB   R6,[R3,#ErrorSemaphore]
    ]
      MOV    R6, R0
      MOV    R3, #:LEN: "Alias$"
31    SUB    R3, R3, #:LEN: "Alias$"
      MOV    R2, #-1        ; negative length means just look for it.
      ADRL   R0, AliasStr
      SWI    XOS_ReadVarVal
      CMP    R2, #0         ; V always set anyway
   [ International
    [ ZeroPage = 0
      LDREQB R0,[R2,#ErrorSemaphore]
      ADDEQ  R0,R0,#1
      STREQB R0,[R2,#ErrorSemaphore]
    |
      LDREQ  R3,=ZeroPage
      LDREQB R0,[R3,#ErrorSemaphore]
      ADDEQ  R0,R0,#1
      STREQB R0,[R3,#ErrorSemaphore]
    ]
   ]
      BEQ    %FT10

      ADD   R3, R3, #:LEN: "Alias$"

; match $R6 with $R3

      MOV   R1, #0                         ; offset
32    LDRB  R4, [R6, R1]
      LDRB  R5, [R3, R1]
      CMP   R4, #&80                       ; in table ?
      ADRCCL R2, Up_ItAndTerm_Check_Table
      LDRCCB R4, [R2, R4]
      CMP   R4, #" "
      CMPLE R5, #" "
      BLE   %FT33
      UpperCase R5, R2
      CMP   R4, R5
      ADDEQ R1, R1, #1
      BEQ   %BT32
      CMP   R1, #0
      BEQ   %BT31                        ; failed
      CMP   R5, #" "
      BLE   %BT31
      CMP   R4, #"."
      BNE   %BT31
      ADD   R1, R1, #1
33
; success : copy name, read value

    [ International
      LDR   R4,=ZeroPage
      LDRB  R0,[R4,#ErrorSemaphore]
      ADD   R0,R0,#1
      STRB  R0,[R4,#ErrorSemaphore]     ; We can go back to translating errors.
    ]

      SUB   R3, R3, #:LEN: "Alias$"
99    LDR   R0, =AliasExpansionBuffer
      ADD   R6, R6, R1                       ; save arglist ptr
      MOV   R4, #0
34    LDRB  R5, [R3], #1
      STRB  R5, [R0, R4]
      ADD   R4, R4, #1
      CMP   R5, #0
      BNE   %BT34
      MOV   R1, R0               ; output buffer same as input!
      MOV   R2, #LongCLISize
      MOV   R3, #0
      MOV   R4, #VarType_Expanded
      SWI   XOS_ReadVarVal
  [ Oscli_QuickAliases
oqa_quicksilvertime_alias
  ]
      BVS   AliasOscliTooLong
      MOV   R3, #13
      STRB  R3, [R1, R2]

      MOV    R3, R1
      MOV    R0, R6              ; arglist
      MOV    R4, R2              ; no of chars got.
      BL     GetOscliBuffer      ; gives buffer ptr in R5, ID in R6
      MOV    R1, R5
      MOV    R2, #OscliBuffSize
      MOV    R5, #0
      SWI    XOS_SubstituteArgs32
      BVS    AliasOscliTooLong

; Whew! Now ready to recursively call OSCLI with all lines in the buffer.
      MOV    R0, R1
      ADD    R2, R1, R2
43    SWI    XOS_CLI
      BVS    %FT46
      CheckUID R6, R1    ; check buffer still valid.
      BLS    FailInAlias
44    LDRB   R1, [R0], #1
      CMP    R1, #13
      CMPNE  R1, #10
      CMPNE  R1, #0
      BNE    %BT44
      CMP    R0, R2
      BLO    %BT43
      MOV    R2, R6
      BL     ReleaseBuff ; release buffer, UID in R2
      Pull  "R0, R3-R6"
      CLRV
      B      OscliExit

      MakeErrorBlock  OscliTooHard

FailInAlias
      CheckUID R2, R1
      BLGT   ReleaseBuff
      ADR    R0, ErrorBlock_OscliTooHard
    [ International
      BL     TranslateError
    ]
46    STR    R0, [stack]
      Pull  "R0, R3-R6"
      SETV
      B      OscliExit

AliasOscliTooLong
      MOV    R2, R6            ; buffer UID
      BL     ReleaseBuff
      Pull  "R0, R3-R6"
      ADRL   R0, ErrorBlock_OscliLongLine
    [ International
      BL     TranslateError
    |
      SETV
    ]
      B      OscliExit

      LTORG

  [ Oscli_QuickAliases
AliasStr_QA = "ALIAS$", 0
  ]
AliasStr = "Alias$*", 0
AliasDot = "Alias$.", 0
      ALIGN

  [ Oscli_QuickAliases
oqa_quicksilvertime_noalias
  ]
10  ; Failed macro expansion.
         Pull   "R0, R3-R6"

; try for system command first.
05       LDRB      R1, [R0]                     ; quick check for . tho
         CMP       R1, #"."
         BEQ       PercentDot

  [ Oscli_HashedCommands
         BL        Oscli_cmd_hashsum            ; => hash value in r1
         LDR       r2,=ZeroPage
         STR       r1,[r2,#Oscli_CmdHashSum]
       [ ZeroPage <> 0
         MOV       r2,#0                        ; Must be zero for oscli_hlist_loop. Not entirely sure why!
       ]
         CMP       r1,#0
         BEQ       oscli_sysabbrevation
         BL        SysCommsHashedLookup
         B         oscli_syslook_done
oscli_sysabbrevation
  ]
         ADRL      R1, SysCommsModule
         MOV       R2, #SCHCTab-SysCommsModule
         SEC                                    ; carry set means sys module
         BL        ModCommsLookUp
oscli_syslook_done
         BCS       OscliExit

  [ Oscli_HashedCommands
         ;now try UtilityModule, if non-abbreviated command
         Push      "R2"
         LDR       r2,=ZeroPage
         LDR       r1,[r2,#Oscli_CmdHashSum]
         CMP       r1,#0
         Pull      "R2",EQ
         BEQ       oscli_modabbreviation
         BL        UtilCommsHashedLookup
         ADDCS     stack, stack, #4                  ;discard R2
         BCS       OscliExit
         ;now try list of modules on hash value
         LDR       r2,=ZeroPage
         LDR       r1,[r2,#Oscli_CmdHashSum]
         AND       r1,r1,#Oscli_MHashValMask
         LDR       r11,[r2,#Oscli_CmdHashLists]
         CMP       r11,#0
         LDRNE     r11,[r11,r1,LSL #2]
         CMPNE     r11,#0
         BEQ       %FT75
         Push      "r3,r4"
         ADD       r3,r11,#8
         LDR       r4,[r11,#4]
         ADD       r4,r4,#1
oscli_hlist_loop
         SUBS      r4,r4,#1
         Pull      "r3,r4",EQ
         BEQ       %FT75
         LDR       R2,[stack,#2*4]
         CMP       R2, #0
         Pull      "r3,r4",MI
         BMI       OneModule_Failed
         LDR       R11,[R3],#4
         LDR       R1, [R11, #Module_code_pointer]
         LDR       R2, [R1, #Module_HC_Table]
         CMP       R2, #0
         BEQ       oscli_hlist_loop
         LDR       R12, [R11, #Module_incarnation_list] ; preferred life
         ADD       R12, R12, #Incarnation_Workspace
         CLC
         BL        ModCommsLookUp
         BCC       oscli_hlist_loop
         Pull      "r3,r4"
         ADD       stack,stack,#4
         B         OscliExit
oscli_modabbreviation
  ] ;Oscli_HashedCommands

; now try looking round the modules.
         LDR       R11, =ZeroPage+Module_List
         Push     "R2"
74       LDR       R2, [stack]
         CMP       R2, #0
         BMI       OneModule_Failed
         LDR       R11, [R11, #Module_chain_Link]
         CMP       R11, #0
         BEQ       %FT75
OnlyOneModuleWanted
         LDR       R1, [R11, #Module_code_pointer]
         LDR       R2, [R1, #Module_HC_Table]
         CMP       R2, #0
         BEQ       %BT74
         LDR       R12, [R11, #Module_incarnation_list] ; preferred life
         ADD       R12, R12, #Incarnation_Workspace
         CLC
         BL        ModCommsLookUp
         BCC       %BT74
         ADD       stack, stack, #4           ; discard R2
         B         OscliExit

75
  ; not in a module : try for current filing system command
         STR       R0, [stack]                 ; pull R2, push R0
         MOV       R0, #FSControl_ReadModuleBase
         SWI       XOS_FSControl
         Pull     "R0"
         CMP       R1, #0
         BEQ       NoFSCommands                  ; no selected FS!
         MOV       R12, R2                       ; module's workspace ptr
         LDR       R2, [R1, #Module_HC_Table]
         CMP       R2, #0
         BEQ       SecondaryFSCTab
         ORR       R2, R2, #&80000000            ; FS command needed flag
         CLC
         BL        ModCommsLookUp
         BCC       SecondaryFSCTab
         B         OscliExit

SecondaryFSCTab
         Push     "R0"
         MOV       R0, #FSControl_ReadSecondaryModuleBase
         SWI       XOS_FSControl
         Pull     "R0"
         MOVVS     R1, #0
         CMP       R1, #0
         BEQ       NoFSCommands
         MOV       R12, R2                       ; module's workspace ptr
         LDR       R2, [R1, #Module_HC_Table]
         CMP       R2, #0
         BEQ       NoFSCommands
         ORR       R2, R2, #&80000000            ; FS command needed flag
         CLC
         BL        ModCommsLookUp
         BCC       NoFSCommands
         B         OscliExit

NoFSCommands
         MOV       R1, #Service_UKCommand
         BL        Issue_Service
         CMP       R1, #0
         BNE       UKCNotClaimed
         CMP       R0, #0                        ; any error?
         SETV      NE                            ; V clear if EQ
         B         OscliExit

OneModule_Failed
         ADD       stack, stack, #4
         ADRL      R0, ErrorBlock_BadCommand
      [  International
         BL        TranslateError
      |
         SETV
      ]
         B         OscliExit

UKCNotClaimed
         MOV       R1, R0
DoFSCV_Run
         MOV       R0, #FSControl_Run
71       SWI       XOS_FSControl
OscliExit
         Pull     "R2"
         SavePSR   R1
         Push     "R0"
         CMP       R2, #0                        ; -ve means no FS selected.
         MOVGE     R0, #FSControl_RestoreCurrent
         SWIGE     XOS_FSControl
         Pull     "R0"

         Pull     "R2"
         CMP       R2, #-1
         BEQ       %FT80
         BL        ReleaseBuff
         BL        RemoveOscliCharJobs  ; shut down redirection
80       TST       R1, #V_bit
         BNE       %FT81
         CLRV
         Pull     "R0-R2, pc"
81
         SETV
         ADD       sp, sp, #4
         Pull     "R1-R2, pc"

06       ADD       R1, R0, #1       ; */ so skip the /, do RUN reason code
         B         DoFSCV_Run

07
         Push     "R0, R3-R6"
         MOV       R6, R0
         ADRL      R0, AliasDot
         MOV       R3, #0
         MOV       R2, #-1         ; negative length means just look for it.
         SWI       XOS_ReadVarVal
         CMP       R2, #0          ; V always set anyway
         MOVNE     R1, #1          ; index to step past .
         BNE       %BT99
         Pull     "R0, R3-R6"
PercentDot                        ; entry for *%.
         ADD       R1, R0, #1
         MOV       R0, #FSControl_Cat   ; *., skip .
         B         %BT71

;***************************************************************************

  [ Oscli_HashedCommands
;
; - routine to compute hash value for unabbreviated commands
; - does not apply mask to hash value (since different hash widths are
;   required in different cases)
;
; hash value = sum of all chars of command, excluding terminator, all
;              chars being processed through Up_ItAndTerm_Check_Table
;
; entry:
; R0 -> command
; exit:
; R1 =  hash value, or 0 if invalid (abbreviation encountered)
;
Oscli_cmd_hashsum ROUT
         Push   "r0,r2-r3,lr"
         MOV    r1,#0
         ADRL   r2, Up_ItAndTerm_Check_Table
         B      %FT15
10
         ADD    r1,r1,r3
15
         LDRB   r3,[r0],#1
         CMP    r3,#&80
         LDRCCB r3,[r2,r3]
         CMP    r3,#"."
         BEQ    %FT30
         CMP    r3,#0
         BNE    %BT10
20
         Pull   "r0,r2-r3,PC"
30
         MOV    r1,#0
         Pull   "r0,r2-r3,PC"
;
;special entry of ModCommsLookUp, for hashed lookup of commands in SysCommsModule
;entry: R0 -> command, r1 = hash value of command
;
SysCommsHashedLookup ROUT
         Push   "R0, R2-R10, lr"
;
;first a fudge, to allow old syntax (no space before first, numeric, parameter)
;for *fx, *key, *opt and *tv - look for '&' or a numeric char at R0 + 2, 3 or 4
;
         MOV    R4, #2
schl_fudgeloop
         LDRB   R2, [R0,R4]
         CMP    R2, #' '
         BLS    schl_nofudge
         CMP    R2, #'&'
         BEQ    schl_fudge
         CMP    R2, #'0'
         BLO    schl_nofudgesofar
         CMP    R2, #'9'
         BLS    schl_fudge
schl_nofudgesofar
         ADD    R4, R4, #1
         CMP    R4, #4
         BLS    schl_fudgeloop
schl_nofudge
         ADRL   R2, SysCoHashedCmdTab
         AND    R4, R1,#Oscli_CHashValMask  ;hash value, masked for command hashing
         LDR    R2, [R2, R4, LSL #2]        ;command list for this hash value
         ADRL   R1, SysCommsModule
         CMP    R2, #1                      ;set carry if valid table entry
         BCS    ModCommsLookUp_AltEntry     ;note: carry set to indicate sys module
         Pull   "R0, R2-R10, pc"            ;bail if null hash table entry (with carry clear to indicate failure)         
schl_fudge
         ADRL   R1, SysCommsModule
         ADRL   R2, SHC_fudgeulike
         SUB    R2, R2, R1                          ;fudge command list (offset)
         SEC                                        ;carry set means sys module
         B      ModCommsLookUp_AltEntry

;
;special entry of ModCommsLookUp, for hashed lookup of commands in UtilityMod
;entry: R0 -> command, r1 = hash value of command
;

UtilCommsHashedLookup ROUT
         Push   "R0, R2-R10, lr"
         ADRL   R2, UtilHashedCmdTab
         AND    R4, R1,#Oscli_CHashValMask  ;hash value, masked for command hashing
         LDR    R2, [R2, R4, LSL #2]        ;command list for this hash value
         ADRL   R1, UtilityMod
         TEQ    R2, #0,2                    ;check R2 and clear carry
         BNE    ModCommsLookUp_AltEntry
         Pull   "R0, R2-R10, pc"            ;bail if null hash table entry
;
  ] ;Oscli_HashedCommands

;***************************************************************************

; Routine to look through a module table for a command, and call it.
; Set up R12 yourself if needed.
; R0 points at command to find
; R1 points at module
; R2 offset of command table : top bit set for "want FS command"
; C set means allow messy matching, i.e. it's the system command table

; Return C set if found and called, V flag from code called
; Might not return if module starts up as current object.

ModCommsLookUp ROUT
         Push   "R0, R2-R10, lr"
  [ Oscli_HashedCommands
ModCommsLookUp_AltEntry
  ]
         MOV     R4, #0   ; want all flags clear
         TEQ     R2, #0   ; don't corrupt C!
         MOVMI   R4, #FS_Command_Flag
         BICMI   R2, R2, #&80000000
         BL      FindItem
         BLCS    %FT05
         CLC                      ; clears C and V
         Pull   "R0, R2-R10, PC"
05
         Push    r4               ; save pointer in case needed for syntax mess

; check number of arguments, error with syntaxmessage if naff.

         ADD     R2, R2, R1       ; get R2 back to pointer.
         ADD     R0, R0, R3       ; point at terminator.
09       LDRB    R4, [R0], #1
         CMP     R4, #" "        ; skip spaces.
         BEQ     %BT09
         MOV     R3, R1          ; hang on to module ptr.
         MOV     R1, #0          ; no of parms.
         MOV     R7, #-1         ; flag for buffer got for GSTRANSing

         MOV     R6, R0
         SUB     R0, R0, #1

; Now we have :
; R0 -> commtail, ready for module
; R1 number of parameters
; R2 -> info block for command
; R3 -> module
; R4 current char
; R5 execute offset
; R6 working commtail ptr
; R7 -1 or buffer UID
; R8 becomes gstrans map
; R9 may be a workin gstrans map copy
; R10 may be a working buffer ptr for copying

         LDRB    R8, [R2, #5]    ; get gstrans_map
         MOVS    R9, R8
         BEQ     nogstransingta

         Push   "R2, R5, R6"
         BL      GetOscliBuffer
         MOV     R0, R5          ; buffer ptr
         MOV     R7, R6          ; buffer UID
         MOV     R10, #0         ; buffer offset for copying
         Pull   "R2, R5, R6"

nogstransingta
         CMP     R4, #13         ; check for more to scan
         CMPNE   R4, #10
         CMPNE   R4, #0
         BEQ     %FT12

         MOVS    R9, R9, LSR #1
         BCC     stripnextparm

    ; gstrans next ; scan afterwards for naffchars
         Push   "R0-R2"

         ADD     R1, R0, R10                  ; buffer pointer
         RSB     R2, R10, #OscliBuffSize      ; room left
         ORR     R2, R2, #GS_Spc_term

         SUB     R0, R6, #1                   ; parameter pointer
         SWI     XOS_GSTrans
         BCS     buffer_overflowed_oh_bother
         BVS     bad_string

         CMP     R2, #0
         BEQ     preversion_detectified       ; empty expansions are naff
         ADD     R10, R10, R2
         ADD     R6, R1, R2
nastycharscan
         LDRB    R2, [R1], #1
         CMP     R2, #&7F
         CMPNE   R2, #" "
         BLE     preversion_detectified
         CMP     R1, R6
         BLO     nastycharscan

         MOV     R6, R0
         Pull   "R0-R2"
         B       next_parameter

preversion_detectified
         ADR     R0, ErrorBlock_BadParmString
       [ International
         BL      TranslateError
       ]
         B       pgstcomm
buffer_overflowed_oh_bother
         ADRL    R0, ErrorBlock_OscliLongLine
       [ International
         BL      TranslateError
       ]
         B       pgstcomm
bad_string
         ADR     R0, ErrorBlock_BadParmString
       [ International
         BL      TranslateError
       ]
pgstcomm
         STR     R0, [stack]
         MOV     R2, R7
         BL      ReleaseBuff
         Pull   "R0-R2, r4"
         B       unpleasantness_in_ModCommsLookUp

         MakeErrorBlock   BadParmString

AddCharForGSTP
         CMP     R8, #0
         MOVEQ   PC, lr
         CMP     R10, #OscliBuffSize
         STRLTB  R4, [R0, R10]
         ADDLT   R10, R10, #1
         MOVLT   PC, lr
         Push   "R0-R2"
         B       buffer_overflowed_oh_bother

stripnextparm
         Push   "R11"
         CMP     R4, #""""
         MOVEQ   R11, #&80000000
         ORREQ   R1, R1, R11
         MOVNE   R11, #0
stripnextchar
         BL      AddCharForGSTP
         LDRB    R4, [R6], #1
         CMP     R4, #""""
         EOREQ   R1, R1, R11
         CMP     R4, #" "
         TSTEQ   R1, #&80000000
         BEQ     parmfinished
         CMP     R4, #13
         CMPNE   R4, #10
         CMPNE   R4, #0
         BNE     stripnextchar
parmfinished
         BIC     R1, R1, #&80000000
         Pull   "R11"

next_parameter
         MOV     R4, #" "
         BL      AddCharForGSTP
         SUB     R6, R6, #1

30       LDRB    R4, [R6], #1
         CMP     R4, #" "
         BEQ     %BT30

         ADD     R1, R1, #1
         B       nogstransingta  ; next parameter

  ; parameters counted : check number

12       BL      AddCharForGSTP   ; terminate the copy

         BIC     R1, R1, #&80000000
         LDR     R4, [R2, #4]
         MOV     R6, R4, LSR #16  ; max no parms
         AND     R6, R6, #&FF
         AND     R4, R4, #&FF     ; min no parms
         CMP     R1, R4
         CMPGE   R6, R1
         BLT     %FT11

   ; checks finished : call the man.

         Push   "R7"              ; j.i.c. module writer can't read

         MOV     lr, PC           ; make link
         ADD     PC, R3, R5       ; and call

         Pull   "R2, r4"
         BL      ReleaseBuff      ; discard buffer got for GSTRANSing

         MRS     R10, CPSR
         ORR     R10, R10, #C_bit ; set C carefully
         MSR     CPSR_f, R10
         STRVS   R0, [stack]
         Pull   "R0, R2-R10, pc"

; Return a command syntax error.  First issue Service_SyntaxError for translation
11
 [ International                  ; Internationalize syntax error messages
         Pull    "r4"             ; r4-> command string in module
         MOV     r1, #Service_SyntaxError ; r2->info block for command, r3->module
         BL      Issue_Service    ; Issue SyntaxError service for possible translation
         CMP     r1, #0           ; Service claimed?
         BEQ     unpleasantness_in_ModCommsLookUp ; Yes then r0-> error block

         Push    "r4"             ; Save -> command string
 ]

         LDR     r4, [r2, #4]
         MOV     r7, r2
         BL      GetOscliBuffer   ; get space for error
         MOV     R2, #ErrorNumber_BadNoParms
         STR     R2, [R5]
         LDR     R2, [R7, #8]
         CMP     R2, #0
         ADREQ   R0, %FT13        ; default error message
         ADDNE   R0, R2, R3       ; point at message
         ORREQ   r4, r4, #International_Help
         TST     r4, #International_Help
         ADREQL  r4, MOSdictionary
         BEQ     %FT37
         MOV     r7, r0
         SUB     sp, sp, #16
         LDR     r2, [r3, #-4]
         LDR     r0, [r3, #Module_MsgFile]
         TST     r0, #12,2
         CMPEQ   r0, #1
         CMPCS   r2, r0
         MOVLS   r0, #0
         BLS     %FT33
         ADD     r1, r3, r0
         MOV     r2, #0
         MOV     r0, sp
         SWI     XMessageTrans_OpenFile
         MOVVS   r0, #0
33       MOV     r1, r7
         MOV     r7, r0           ; Message file data block
         MOV     r2, #0
         SWI     XMessageTrans_Lookup
         ADDVS   r2, r0, #4
         SWI     XMessageTrans_Dictionary
         ADDVS   r2, r0, #4
         MOV     r4, r0
         MOV     r0, r2
         LDR     r2, [sp, #16]
         ADD     r1, r5, #4
         BL      expandsyntaxmessage
         MOVS    r0, r7           ; Close iff message file was used
         SWINE   XMessageTrans_CloseFile
         ADD     sp, sp, #16
         Pull    r2
         B       %FT39
37
         Pull    r2
         ADD     r1, r5, #4
         BL      expandsyntaxmessage
39
         MOV     r0, r5

unpleasantness_in_ModCommsLookUp
         STR     R0, [stack]
         MSR     CPSR_f, #V_bit+C_bit
         Pull   "R0, R2-R10, PC"
13
         DCB     "NumParm", 0

         ALIGN

expandsyntaxmessage
         LDRB    R3, [R0], #1
         CMP     r3, #TokenEscapeChar
         BEQ     esm_tok
         STRB    R3, [R1], #1
         CMP     R3, #0
         BNE     expandsyntaxmessage
         SUB     r1, r1, #1
         MOV     pc, lr

esm_tok  LDRB    r3, [r0], #1
         Push   "r0, lr"
         CMP     r3, #Token0    ; Token0 => use R2
         MOVEQ   r0, r2
         BEQ     esm001
         MOV     r0, r4
esmlp    SUBS    r3, r3, #1
         LDRNEB  r14, [r0]      ; ECN: Use R14 instead of R4 as using R4 corrupts
         ADDNE   r0, r0, r14    ; the dictionary pointer thus disallowing recursive tokens
         BNE     esmlp
         ADD     r0, r0, #1
esm001   BL      expandsyntaxmessage
         Pull   "r0, lr"
         B       expandsyntaxmessage

;---------------------------------------------------------------------------
; routine to just find a keyword in a table that has the flags specified.
; R0 points at command to find
; R1 points at module
; R2 offset of command table
; R4 word to EOR with flags : demand 0 result for match
; C set means allow messy matching, i.e. it's the system command table
; Uses R2-R5

; Return C set if found : R5 is execute offset, R3 length of string
; R2 is offset of execute offset of field found
; r4 is command pointer

FindItem ROUT
         Push   "R4, R6, R7"
         MRS     R7, CPSR         ; to remember C flag (32-bit clean)
         ADD     R2, R2, R1
         LDRB    R4, [R2]
         CMP     R4, #0
         BEQ     FindItem_EOTab
05       MOV     R3, #0           ; offset
01       LDRB    R4, [R0, R3]
         LDRB    R5, [R2, r3]
         CMP     R4, #&80         ; in table ?
         ADRCC   R6, Up_ItAndTerm_Check_Table
         LDRCCB  R4, [R6, R4]
         CMP     R4, #32
         CMPLE   R5, #32
         BLE     %FT04           ; matched, and we're at the terminator
         UpperCase R5, R6
         CMP     R4, R5
         ADDEQ   R3, R3, #1
         BEQ     %BT01
         CMP     R4, #"."        ; success if abbreviation
         BEQ     %FT02
         TST     R7, #C_bit      ; C flag on entry
         BEQ     %FT07           ; nomatch
         CMP     R5, #32
         BGT     %FT07
         CMP     R4, #"A"
         RSBGES  R6, R4, #"Z"
         BLT     %FT04             ; matched, at terminator
07       LDRB    R5, [R2], #1
         CMP     R5, #32
         BGT     %BT07             ; skip to terminator
         ADD     R2, R2, #3
         BIC     R2, R2, #3        ; ALIGN
06       ADD     R2, R2, #16       ; !!! DEPENDANT ON TABLE FORMAT!!!
         LDRB    R5, [R2]
         CMP     R5, #0
         BNE     %BT05
FindItem_EOTab
         Pull   "R4, R6, R7"
         CLC
         MOV     PC, lr            ; back with not found.

Up_ItAndTerm_Check_Table
; Table to uppercase and test for terminators for passed * commands
;      0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
   =   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0     ; 0
   =   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0     ; 1
   =   0 , "!", 0 , "#" , 0, 0, 0, "'", "(", ")", "*" , "+", 0 , "-", ".", "/"    ; 2
   =  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", 0, ";", 0 , "=", 0 , "?"    ; 3
   =  "@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"    ; 4
   =  "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "[", 0, "]", 0, "_"    ; 5
   =  "`", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"    ; 6
   =  "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "{", 0 , "}", "~", 0     ; 7

;  WHILE . < Up_ItAndTerm_Check_Table+256 ; top bit stuff done by CMP #&80
;   = . - Up_ItAndTerm_Check_Table
;  WEND                            ; entry for chars > 127 = char

02       CMP     R5, #32          ; only success if $R2 not terminated.
         BLE     %BT07
         ADD     R3, R3, #1       ; skip .
04       MOV     r6, r2
         ADD     r2, r2, r3
08       LDRB    R5, [R2], #1
         CMP     R5, #0
         BNE     %BT08            ; demand NULL terminator
         ADD     R2, R2, #3
         BIC     R2, R2, #3       ; ALIGN
         LDR     R5, [R2, #4]     ; get information word

         AND     R5, R5, #&C0000000 :AND::NOT:Help_Is_Code_Flag
                                  ; clear param numbers/low flags.
         LDR     R4, [stack]
         EORS    R5, R5, R4
         BNE     %BT06            ; flags don't match

         LDR     R5, [R2]         ; get Execute offset
         CMP     R5, #0
         BEQ     %BT06            ; not a command
         STR     r6, [stack]      ; return r4
         Pull   "R4, R6, R7"
         SUB     R2, R2, R1       ; get back to offset.
         SEC
         MOV     PC, lr

;****************************************************************************
; variegated routines
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

OscliInit
; circular buffer initialisation :
;  botUID := topUID := 0 ; currend := circbuffstart
; Redirection handles := 0
         LDR        R0, =ZeroPage
       [ ZeroPage = 0
         STR        R0, [R0, #OscliCBbotUID]
         STR        R0, [R0, #OscliCBtopUID]
       |
         MOV        R1, #0
         STR        R1, [R0, #OscliCBbotUID]
         STR        R1, [R0, #OscliCBtopUID]
       ]
         LDR        R1, =OscliCircBuffStart
         STR        R1, [R0, #OscliCBcurrend]
         ASSERT     (ZeroPage :AND: 255) = 0
         STRB       R0, [R0, #RedirectInHandle]
         STRB       R0, [R0, #RedirectOutHandle]
         MOV        PC, R14

; buffer is valid if botUID < UID


; GetOscliBuffer used in module handler to get error buffers - saves workspace!

GetOscliBuffer ROUT
 ; return ptr in R5 to next buffer in Oscli's circular job
 ; UID in R6
 ; corrupts R2

; currend +:= 256
      LDR    R2, =ZeroPage
      LDR    R5, [R2, #OscliCBcurrend]
      ADD    R5, R5, #OscliBuffSize

; IF currend >= circbufflimit
;  THEN currend := circbuffstart
      LDR    R6, =OscliCircBuffLimit
      CMP    R5, R6
      LDRHS  R5, =OscliCircBuffStart
      STR    R5, [R2, #OscliCBcurrend]

; topUID +:= 1
      LDR    R6, [R2, #OscliCBtopUID]
      ADD    R6, R6, #1
      STR    R6, [R2, #OscliCBtopUID]
; IF topUID > botUID + noBuffers
; THEN botUID +:= 1
      LDR    R5, [R2, #OscliCBbotUID]
      SUB    R2, R6, R5
      CMP    R2, #OscliNoBuffs
      LDR    R2, =ZeroPage
      ADDGE  R5, R5, #1
      STRGE  R5, [R2, #OscliCBbotUID]

; RETURN currend, topUID
      LDR    R5, [R2, #OscliCBcurrend]
      MOV    PC, lr


ReleaseBuff ; take UID in R2, check whether can step back topUID
     EntryS "R1-R4"
     LDR    R1, =ZeroPage
     LDR    R3, [R1, #OscliCBtopUID]
     LDR    R4, [R1, #OscliCBbotUID]
; IF UID = topUID AND topUID <> botUID
     CMP    R3, R4
     EXITS  EQ
     CMP    R2, R3
     EXITS  NE
; THEN $(
;    topUID -:= 1
     SUB    R3, R3, #1
     STR    R3, [R1, #OscliCBtopUID]

;    IF currend = circbuffstart THEN currend := circbufflimit
     LDR    R3, [R1, #OscliCBcurrend]
     LDR    R4, =OscliCircBuffStart
     CMP    R3, R4
     LDREQ  R3, =OscliCircBuffLimit
; currend -:= 256
     SUB    R3, R3, #OscliBuffSize
     STR    R3, [R1, #OscliCBcurrend]
     EXITS

        LTORG                   ; needed now not at top level

OscliRestoreFS
    Push    "R0, lr"
    MOV      R0, #FSControl_RestoreCurrent
    SWI      XOS_FSControl
    Pull    "R0, PC"

OscliTidy    ROUT  ; shut down redirection, restore permanent FS
     Push   "lr"
     BL      RemoveOscliCharJobs
     BL      OscliRestoreFS
     Pull   "PC"

RemoveOscliCharJobs ROUT
     Push   "R0-R2, lr"
     ; Release WrchV before attempting to close the file handles. This protects
     ; against output going missing if it happens during the close operation(s)
     ; E.g. if we're running in a task window and the output device uses
     ; OS_UpCall 6, our WrchV hook may be left installed when control is
     ; returned to the Wimp: https://www.riscosopen.org/tracker/tickets/420
     MOV     R2, #0
     MOV     R0, #WrchV
     ADR     R1, RedirectWrch
     SWI     XOS_Release
   [ ZeroPage <> 0
     LDR     R2, =ZeroPage
   ]
     LDRB    R1, [R2, #RedirectInHandle]
     CMP     R1, #0
     MOVNE   R0, #0
     STRNEB  R0, [R2, #RedirectInHandle]
     SWINE   XOS_Find
     LDRB    R1, [R2, #RedirectOutHandle]
     CMP     R1, #0
     MOVNE   R0, #0 ; May have got error (discarded)
     STRNEB  R0, [R2, #RedirectOutHandle]
     SWINE   XOS_Find
     CLRV
     Pull   "R0-R2, PC"

RedirectWrch ROUT
     Push   "R1"
     LDR     R1, =ZeroPage
     LDRB    R1, [R1, #RedirectOutHandle]
     SWI     XOS_BPut
     Pull   "R1, pc", VC
     BL      RemoveOscliCharJobs
     SETV
     Pull   "R1, pc"

; **************************************************************************
;
;       SWI OS_ChangeRedirection - Read/write redirection handles
;
; in:   R0 = new input  handle (0 => not redirected, -1 => leave alone)
;       R1 = new output handle (0 => not redirected, -1 => leave alone)
;
; out:  R0 = old input  handle (0 => not redirected)
;       R1 = old output handle (0 => not redirected)
;

ChangeRedirection ROUT
        LDR     R12, =ZeroPage
        LDRB    R10, [R12, #RedirectInHandle]
        LDRB    R11, [R12, #RedirectOutHandle]

; do input handle

        CMP     R0, #&100               ; if out of range then just read
        STRCCB  R0, [R12, #RedirectInHandle]

; do output handle

        CMP     R1, #&100               ; if out of range then just read
        BCS     %FT40

        STRB    R1, [R12, #RedirectOutHandle]
        CMP     R1, #1                  ; CS <=> (R1 non-zero)
        TEQ     R11, #0                 ; NE <=> (R11 non-zero)
        BHI     %FT40                   ; [both non-zero, skip]

        BCS     %FT30                   ; [just R1 non-zero, so claim]
        BEQ     %FT40                   ; [both zero, skip]

; R11 non-zero, R1 zero, so release vector

        Push    "R0-R2, lr"             ; set up registers for claim or release
        MOV     R0, #WrchV
        ADR     R1, RedirectWrch
        MOV     R2, #0
        SWI     XOS_Release
        STRVS   R0, [sp, #0*4]
        Pull    "R0-R2, lr"
        ORRVS   lr, lr, #V_bit
        ExitSWIHandler VS
        B       %FT40

; R11 zero, R1 non-zero, so claim vector

30
        Push    "R0-R2, lr"
        MOV     R0, #WrchV
        ADR     R1, RedirectWrch
        MOV     R2, #0
        SWI     XOS_Claim
        STRVS   R0, [sp, #0*4]
        Pull    "R0-R2, lr"
        ORRVS   lr, lr, #V_bit
        ExitSWIHandler VS

40
        MOV     R0, R10
        MOV     R1, R11
        ExitSWIHandler

;**************************************************************************
; Module selection
;  Entered with V set if FileSwitch found a - : must get module or give error
;  R2 >= 0 if filing system selected: do nothing
;  R1 -> command prefix
;  Out: R1 updated
;    R2 = -1: no module
;    R2 = -<larger>:  R2 is selected module node
;         Selected prefix also preferred

CheckForModuleAsPrefix ROUT
     EntryS "R0-R6"
     ADDVS   R1, R1, #1         ; skip -
     MOVVS   R2, #"-"
     BVS     %FT02
     CMP     R2, #-1
     BNE     %FT01
     MOV     R2, #":"           ; terminators for lookup

02   ADR     R5, %FT10
     STR     R1, [stack, #Proc_RegOffset + 4]
03   LDRB    R3, [R1], #1
     UpperCase R3, R4
     LDRB    R4, [R5], #1
     CMP     R3, R4
     BEQ     %BT03
     CMP     R4, #0
     LDRNE   R1, [stack, #Proc_RegOffset + 4]
     SUBEQ   R1, R1, #1
     MOV     R6, R1
     LDR     R1, =AliasExpansionBuffer
05   LDRB    R3, [R6], #1
     CMP     R3, #"."           ; disallow abbreviations: they're confusing!
     CMPNE   R3, #" "
     BLE     %FT01
     CMP     R3, R2
     STRNEB  R3, [R1], #1
     BNE     %BT05

     MOV     R3, #0
     STRB    R3, [R1]

     MOV     R0, #ModHandReason_LookupName
     LDR     R1, =AliasExpansionBuffer
     SWI     XOS_Module
     BVS     %FT01
     MOV     R2, R1
     LDR     R1, =AliasExpansionBuffer
     MOV     R0, #ModHandReason_MakePreferred
     SWI     XOS_Module

     LDR     R0, =ZeroPage+Module_List
04   LDR     R0, [R0]
     SUBS    R2, R2, #1
     BPL     %BT04
     MOV     R1, R6                 ; point at rest of command line.
     RSB     R2, R0, #0
     STR     R1, [stack, #Proc_RegOffset + 4]
     STR     R2, [stack, #Proc_RegOffset + 8]
     EXITS   VC

01
     EXITS                           ; return fileswitch error if set
10
     =      "MODULE#",0
     ALIGN

     LTORG

     END
