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
        TTL     => SysComms , the system commands file: Load save dump etc.

TAB      *      9
FSUTtemp RN     r10

         GBLS   UtilRegs        ; Save the same set so we can common up exits
UtilRegs SETS   "r7-r10"        ; Sam will preserve r0-r6 on module star entry

AnyNoParms  *   &FF0000         ; Between 0 and 255 parameters: all flags clear


SysCommsModule ROUT

Module_BaseAddr SETA SysCommsModule

        &       0               ; No Start entry
        &       0               ; Not initialised
        &       0
        &       0
        &       0
        &       SysTitle-SysCommsModule
        &       SCHCTab-SysCommsModule
        &       0
        &       0
        &       0
        &       0
 [ International_Help <> 0
        &       MessageFileName-SysCommsModule
 |
        &       0
 ]

SysTitle
        = "$SystemName", 9
   [ :LEN: "$SystemName" < 8
        =  9
   ]
        =  "$VersionNo", 0

  [ Oscli_HashedCommands
;
;***WARNING*** if commands are added or changed, SysCoHashedCmdTab MUST be updated correspondingly
;
  ]
SCHCTab ; Alphabetically ordered so it's easier to find stuff

        Command Append,  1,  1, International_Help
        Command Build,   1,  1, International_Help
        Command Close,   0,  0, International_Help
        Command Create,  4,  1, International_Help
        Command Delete,  1,  1, International_Help
        Command Dump,    3,  1, International_Help
        Command Exec,    1,  0, International_Help
        Command FX,      5,  1, International_Help    ; 1-3 parms, but up to 2 commas may be there
        Command GO,    255,  0, International_Help
HelpText
        Command Help,  255,  0, International_Help
        Command Key,   255,  1, International_Help
        Command Load,    2,  1, International_Help ; Fudge order for compatibility (*L.)
        Command List,    3,  1, International_Help
        Command Opt,     2,  0, International_Help
        Command Print,   1,  1, International_Help
        Command Quit,    0,  0, International_Help
        Command Remove,  1,  1, International_Help
        Command Save,    6,  2, International_Help ; *SAVE Fn St + Le Ex Lo (compatibility)
        Command Shadow,  1,  0, International_Help
        Command Spool,   1,  0, International_Help
        Command SpoolOn, 1,  0, International_Help
        Command TV,      3,  0, International_Help
        Command Type,    3,  1, International_Help ; -file fred -tabexpand
        =       0

  [ Oscli_HashedCommands
;
; - Hashing table is 32 wide
; - Hashing function is:
;
;      hash = (sum of all chars of command, each upper-cased) & 0x1f
;
; - Order of commands in each hashed list is alphabetical

; Table MUST be reorganised if hashing function changed, or command set altered
;
           ALIGN
SysCoHashedCmdTab
;
;     ! 0,"SysCoHashedCmdTab at ":CC::STR:(SysCoHashedCmdTab)
;
;First, 1 word per table entry, giving offset to hashed list on each hash value
;
           DCD       SHC_hash00 - SysCommsModule
           DCD       0                            ;null list on this hash value
           DCD       SHC_hash02 - SysCommsModule
           DCD       SHC_hash03 - SysCommsModule
           DCD       0
           DCD       SHC_hash05 - SysCommsModule
           DCD       SHC_hash06 - SysCommsModule
           DCD       0
           DCD       0
           DCD       SHC_hash09 - SysCommsModule
           DCD       SHC_hash0A - SysCommsModule
           DCD       0
           DCD       0
           DCD       SHC_hash0D - SysCommsModule
           DCD       SHC_hash0E - SysCommsModule
           DCD       SHC_hash0F - SysCommsModule
           DCD       SHC_hash10 - SysCommsModule
           DCD       0
           DCD       0
           DCD       SHC_hash13 - SysCommsModule
           DCD       SHC_hash14 - SysCommsModule
           DCD       0
           DCD       SHC_hash16 - SysCommsModule
           DCD       0
           DCD       SHC_hash18 - SysCommsModule
           DCD       0
           DCD       0
           DCD       0
           DCD       SHC_hash1C - SysCommsModule
           DCD       0
           DCD       SHC_hash1E - SysCommsModule
           DCD       0
;
; Now the hashed lists
;
SHC_hash00
        Command Load,    2,  1, International_Help ; Fudge order for compatibility (*L.)
        =   0
        ALIGN
SHC_hash02
        Command Type,    3,  1, International_Help ; -file fred -tabexpand
        =   0
        ALIGN
SHC_hash03
        Command Quit,    0,  0, International_Help
        =   0
        ALIGN
SHC_hash05
        Command Exec,    1,  0, International_Help
        =   0
        ALIGN
SHC_hash06
        Command Shadow,  1,  0, International_Help
        =   0
        ALIGN
SHC_hash09
        Command Help,  255,  0, International_Help
        Command Key,   255,  1, International_Help
        =   0
        ALIGN
SHC_hash0A
        Command SpoolOn, 1,  0, International_Help
        Command TV,      3,  0, International_Help
        =   0
        ALIGN
SHC_hash0D
        Command Print,   1,  1, International_Help
        Command Spool,   1,  0, International_Help
        =   0
        ALIGN
SHC_hash0E
        Command Remove,  1,  1, International_Help
        =   0
        ALIGN
SHC_hash0F
        Command Save,    6,  2, International_Help ; *SAVE Fn St + Le Ex Lo (compatibility)
        =   0
        ALIGN
SHC_hash10
        Command Build,   1,  1, International_Help
        =   0
        ALIGN
SHC_hash13
        Command Delete,  1,  1, International_Help
        Command Opt,     2,  0, International_Help
        =   0
        ALIGN
SHC_hash14
        Command Create,  4,  1, International_Help
        =   0
        ALIGN
SHC_hash16
        Command Close,   0,  0, International_Help
        Command Dump,    3,  1, International_Help
        Command GO,    255,  0, International_Help
        =   0
        ALIGN
SHC_hash18
        Command Append,  1,  1, International_Help
        =   0
        ALIGN
SHC_hash1C
        Command List,    3,  1, International_Help
        =   0
        ALIGN
SHC_hash1E
        Command FX,      5,  1, International_Help    ; 1-3 parms, but up to 2 commas may be there
        =   0
        ALIGN

;now a small table to fudge around need for old syntax for *fx etc (ie.
;allow zero spaces between command and first, numeric, parameter)
;
SHC_fudgeulike
        Command FX,      5,  1, International_Help    ; 1-3 parms, but up to 2 commas may be there
        Command Key,   255,  1, International_Help
        Command Opt,     2,  0, International_Help
        Command TV,      3,  0, International_Help
        =   0
        ALIGN

  ] ;Oscli_HashedCommands

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Most help and syntax messages go together to save ALIGNing wastage

        GET       s.MosDict
        GET       s.TokHelpSrc

GO_Syntax   * Module_BaseAddr
Help_Syntax * Module_BaseAddr

        ALIGN                   ; Just the one, please !

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

HelpBufferSize * 512

Help_Code ROUT       ; got R0 ptr to commtail, R1 no parameters
        Push    "r7, lr"

; first pass round a service call to let wally user code do things.
        MOV     r2, r1
        MOV     r1, #Service_Help
        BL      Issue_Service
        CMP     r1, #0
        Pull    "r7, pc", EQ

        CMP     r2, #0
        MOVNE   r6, r0
        addr    r6, HelpText, EQ

        MOV     r0, #117                ; Read current VDU status
        SWI     XOS_Byte                ; Won't fail
        SWI     XOS_WriteI+14           ; paged mode on.
        Pull    "r7, pc", VS            ; Wrch can fail

        Push    "r1"                    ; Save page mode state
        MOV     r0, r6
        MOV     r7, #0                  ; anyhelpdoneyet flag

DoHelpOnNextKeyWord
; now look at syscomms module.
        addr    r1, SysCommsModule
        BL      ShowHelpInModule
        BVS     %FT67

; now try looking round the modules.
        LDR      R2, =ZeroPage+Module_List
11      LDR      R2, [R2]
        CMP      R2, #0
        BEQ      tryagainstmodulename
        LDR      R1, [R2, #Module_code_pointer]
        LDR      R12, [R2, #Module_incarnation_list]
        ADD      R12, R12, #Incarnation_Workspace
        BL       ShowHelpInModule
        BVS      %FT67
        B        %BT11

tryagainstmodulename
        Push     "r0"
        MOV       r1, #0
        MOV       r2, #0
tamn_loop
        MOV       r0, #ModHandReason_GetNames
        SWI       XOS_Module
        Pull      r0, VS
        BVS       %FT02
        LDR       r0, [stack]      ; kword ptr
        Push     "r1, r2"
        LDR       r4, [r3, #Module_TitleStr]
        CMP       r4, #0
        BEQ       tamn_notit
        ADD       r4, r4, r3
        MOV       R5, #0           ; offset
tamn_chk
        LDRB      R1, [R0, R5]
        LDRB      R2, [R4, R5]
        CMP       R1, #32
        CMPLE     R2, #32
        BLE       tamn_dojacko    ; matched at terminator
        UpperCase R1, R6
        UpperCase R2, R6
        CMP       R1, R2
        ADDEQ     R5, R5, #1
        BEQ       tamn_chk
        RSBS      R2, R2, #33     ; only if not terminated
        CMPLE     R1, #"."        ; success if abbreviation
        BNE       tamn_notit
tamn_dojacko
        BL        ModuleJackanory
        STRVS     r0, [stack, #2*4]
tamn_notit
        Pull     "r1, r2"
        Pull      r0, VS
        BVS       %FT67
        CMP       r2, #0
        ADDNE     r1, r1, #1
        MOVNE     r2, #0
        B         tamn_loop

02      LDRB      R1, [R0], #1
        CMP       R1, #"."
        CMPNE     R1, #" "
        BGT       %BT02
        CMP       R1, #" "
        BLT       %FT67
66      LDRB      R1, [R0], #1
        CMP       R1, #" "
        BEQ       %BT66
        SUBGT     R0, R0, #1
        BGT       DoHelpOnNextKeyWord
67      BLVC      testnohelpdone
        Pull     "R1"
        MRS       r6, CPSR
        TST       R1, #5
        SWIEQ     XOS_WriteI+15  ; paged mode off
        MSR       CPSR_f, r6     ; restore V state
        Pull     "r7, PC"

testnohelpdone
        CMP       r7, #0
        MOVNE     pc, lr
        MOV       r7, lr
      [ International
        BL        WriteS_Translated
        =         "NoHelp:No help found.",10,13,0
        ALIGN
      |
        SWI       XOS_WriteS
        =         "No help found.",10,13,0
        ALIGN
      ]
        MOV       pc, r7

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ModuleJackanory   ROUT      ; give summary of info in module @ r3
        Push     "r0, lr"
        CheckSpaceOnStack HelpBufferSize+256, modjack_noroom, r6
        SUB       stack, stack, #HelpBufferSize
        MOV       r2, r3
        LDR       r3, [r2, #Module_TitleStr]
        CMP       r3, #0
        ADDNE     r3, r3, r2
        ADREQL    r3, NoRIT
        BL        PrintMatch
        BVS       %FT99
        LDR       r3, [r2, #Module_HelpStr]
        CMP       r3, #0
        BEQ       nohstring
        STMDB     sp!, {r2, r3}
        LDR       r2, =ZeroPage                 ; Try our message file before Global.
        LDR       r0, [r2, #KernelMessagesBlock]
        TEQ       r0, #0
        ADDNE     r0, r2, #KernelMessagesBlock+4
        ADRL      r1, modjack_hstr
      [ ZeroPage <> 0
        MOV       r2, #0
      ]
        SWI       XMessageTrans_Lookup
        SWIVC     XMessageTrans_Dictionary
        MOVVC     r1, r0
        MOVVC     r0, r2
        SWIVC     XOS_PrettyPrint
        SWIVC     XOS_WriteI + 32
        LDMIA     sp!, {r2, r3}
        ADDVC     r0, r2, r3
        SWIVC     XOS_PrettyPrint
        BVS       %FT99
nohstring
        MOV       r3, stack                ; buffer address
        MOV       r1, #0                   ; flags for commands
        ADRL      r0, modjack_comms
        BL        OneModuleK_Lookup
        MOVVC     r1, #FS_Command_Flag
        ADRVCL    r0, modjack_filecomms
        BLVC      OneModuleK_Lookup
        MOVVC     r1, #Status_Keyword_Flag
        ADRVCL    r0, modjack_confs
        BLVC      OneModuleK_Lookup
        MOVVC     r1, #-1
        ADRVCL    r0, modjack_aob
        BLVC      OneModuleK_Lookup
99      ADD       stack, stack, #HelpBufferSize
        SWIVC     XOS_NewLine
98      STRVS     r0, [stack]
        Pull     "r0, PC"
modjack_noroom
        ADRL      r0, ErrorBlock_StackFull
      [ International
        BL        TranslateError
      |
        SETV
      ]
        B         %BT98

OneModuleK_Lookup
        STMDB   sp!, {r1-r3, lr}
        MOV     r1, r0
        LDR     r2, =ZeroPage                   ; Try our message file before Global.
        LDR     r0, [r2, #KernelMessagesBlock]
        TEQ     r0, #0
        ADDNE   r0, r2, #KernelMessagesBlock+4
      [ ZeroPage <> 0
        MOV     r2, #0
      ]
        SWI     XMessageTrans_Lookup
        MOVVC   r0, r2
        LDMIA   sp!, {r1-r3, lr}
        MOVVS   pc, lr
        B       OneModuleK

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Print match header, keyword @ r3

PrintMatch      ROUT
      [ International
        Push   "r0-r4, lr"
        SWI     XOS_ReadEscapeState
        BLCS    AckEscape
        BVS     %FT99
        SWI     XOS_WriteI+CR
        MOVVC   r4,r3
        BL      WriteS_Translated_UseR4
        =       "HelpFound:==> Help on keyword %0",0
        ALIGN
        SWIVC   XOS_NewLine
99      STRVS   R0, [stack]
        MOV     R7, #1
        Pull   "r0-r4, PC"
      |
        Push   "r0-r2, lr"
        SWI     XOS_ReadEscapeState
        BLCS    AckEscape
        ADRVC   r0, HelpMatchString
        MOV     r2, r3
        SWIVC   XOS_PrettyPrint    ; print matched keyword
        SWIVC   XOS_NewLine
        STRVS   R0, [stack]
        MOV     R7, #1
        Pull   "r0-r2, PC"

HelpMatchString =  CR, "==> Help on keyword ",TokenEscapeChar,Token0, 0
        ALIGN
      ]

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ShowHelpInModule  ROUT    ; take module ptr in R1, give relevant help.

        Push   "R2-R6, lr"

        LDR     R2, [R1, #Module_HC_Table]
        CMP     R2, #0
        Pull   "R2-R6, PC", EQ

        ADD     R2, R1, R2        ; point at table
fujjnulltables
        LDRB    R5, [R2]
        CMP     R5, #0
        BNE     %FT21
        Pull   "R2-R6, PC"       ; finished

21      MOV     R3, #0           ; offset
22      LDRB    R4, [R0, R3]
        LDRB    R5, [R2, R3]
        CMP     R4, #32
        CMPLE   R5, #32
        BLE     %FT25           ; matched at terminator
        UpperCase R4, R6
        UpperCase R5, R6
        CMP     R4, R5
        ADDEQ   R3, R3, #1
        BEQ     %BT22
        RSBS    R5, R5, #33       ; only if not terminated
        CMPLE   R4, #"."          ; success if abbreviation
        BEQ     %FT25
        ADD     R2, R2, R3
23      LDRB    R5, [R2], #1
        CMP     R5, #32
        BGT     %BT23             ; skip to terminator
        ADD     R2, R2, #3
        BIC     R2, R2, #3        ; ALIGN
24      ADD     R2, R2, #16
        B       fujjnulltables

25      ADD     R2, R2, R3
        SUB     R3, R2, R3        ; hang on to keyword ptr
28      LDRB    R5, [R2], #1
        CMP     R5, #0
        BNE     %BT28           ; demand null terminator
        ADD     R2, R2, #3
        BIC     R2, R2, #3        ; ALIGN

        LDR     R5, [R2, #12]    ; get help offset
        CMP     R5, #0
        BEQ     %BT24          ; no help.

        BL      PrintMatch           ; r3 -> keyword
        Pull   "R2-R6, PC", VS

        LDR     R6, [R2, #4]     ; get info word
        TST     R6, #Help_Is_Code_Flag
        BNE     CallHelpKeywordCode

        Push   "R0-r3"
        TST     R6, #International_Help
        BEQ     %FT35
        SUB     sp, sp, #16
        LDR     r2, [r1, #-4]
        LDR     r0, [r1, #Module_MsgFile]
        TST     r0, #12,2
        CMPEQ   r0, #1
        CMPCS   r2, r0
        MOVLS   r0, #0
        BLS     %FT29
        ADD     r1, r1, r0
        MOV     r2, #0
        MOV     r0, sp
        SWI     XMessageTrans_OpenFile
        MOVVS   r0, #0
29      MOV     r6, r0
        LDR     r1, [sp, #16 + 1 * 4]
        ADD     r1, r5, r1
        MOV     r2, #0
        SWI     XMessageTrans_Lookup
        ADDVS   r2, r0, #4
        SWI     XMessageTrans_Dictionary
        MOVVS   r0, #0
        MOV     r1, r0
        MOV     r0, r2
        LDR     r2, [sp, #16 + 3 * 4]
        SWI     XOS_PrettyPrint         ; Error check not done yet
        SWI     XOS_NewLine
        MOV     r0, r6
        LDR     r2, [sp, #16 + 2 * 4]
        LDR     R5, [r2, #8]
        CMP     R5, #0
        BEQ     %FT30                   ; Should print default message?
        LDR     r1, [sp, #16 + 1 * 4]
        ADD     r1, r5, r1
        MOV     r2, #0
        SWI     XMessageTrans_Lookup
        ADDVS   r2, r0, #4
        SWI     XMessageTrans_Dictionary
        MOVVS   r0, #0
        MOV     r1, r0
        MOV     r0, r2
        LDR     r2, [sp, #16 + 3 * 4]
        SWI     XOS_PrettyPrint         ; No Error check!!!
        SWI     XOS_NewLine
30      MOVS    r0, r6
        SWINE   XMessageTrans_CloseFile
        ADD     sp, sp, #16
        Pull    "R0-R3"
        B       %BT24

35      ADD     R0, R5, R1
        MOV     r1, #0
        MOV     r2, r3
        SWI     XOS_PrettyPrint
        SWIVC   XOS_NewLine
        STRVS   R0, [stack]
        Pull   "R0-r3"
        Pull   "R2-R6, PC", VS
        B       %BT24

helpnostack
        ADRL    R0, ErrorBlock_StackFull
      [ International
        BL      TranslateError
      |
        SETV
      ]
        Pull   "R2-R6, pc"

CallHelpKeywordCode
        CheckSpaceOnStack HelpBufferSize+256, helpnostack, R6
        SUB     stack, stack, #HelpBufferSize
        Push   "R0-R2, R12"     ; code allowed to corrupt R1-R6, R12
        MOV     R2, R1
        ADD     R0, stack, #4*4
        MOV     R1, #HelpBufferSize
        MOV     lr, PC          ; R12 set by our caller
        ADD     PC, R5, R2
        BVS     hkc_threwawobbly
        CMP     R0, #0
        MOVNE   r1, #0
        SWINE   XOS_PrettyPrint
        SWIVC   XOS_NewLine
hkc_threwawobbly
        STRVS   R0, [stack]
        Pull   "R0-R2, R12"
        ADD     stack, stack, #HelpBufferSize
        BVC     %BT24
        Pull   "R2-R6, PC"

;**************************************************************************

GO_Code ROUT
        Push  "R7, lr"
        MOV    R4, R0
        BL     SPACES
        CMP    R5, #13
        TEQNE  R5, #";"
        MOVLS  R7, #AppSpaceStart
        BCC    GOEX
        BEQ    GOEX0
        BL     ReadHex
        MOVVS  R7, #AppSpaceStart
        BL     SPACES
GOEX0   TEQ    R5, #";"
        BLEQ   SPACES
GOEX    SUB    R1, R4, #1
        MOV    R0, #FSControl_StartApplication
        MOV    R2, R7
        ADR    R3, GOSMUDGE
        SWI    XOS_FSControl
        Pull  "R7, PC", VS

        LDR    sp_svc, =SVCSTK ; remove supervisor stuff
        WritePSRc 0, R14       ; in to user mode
        MOV    PC, R7

GOSMUDGE = "GO ", 0
         ALIGN

ReadHex Push    "R0-R2, lr"
        MOV      R0, #16
        SUB      R1, R4, #1
        SWI      XOS_ReadUnsigned
        MOV      R4, R1
        MOV      R7, R2
        Pull    "R0-R2, PC"

SPACES  LDRB R5, [R4], #1
        TEQ R5, #" "
        BEQ SPACES
        MOV PC, R14

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Close_Code Entry

        MOV    R0, #0
        MOV    R1, #0
        SWI    XOS_Find
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

FX_Code Entry

        MOV     R1, #0
        MOV     R2, #0
        Push    "R1-R2"         ; Put optional parms (default 0, 0) on stack
        MOV     R1, R0
        MOV     R0, #10
        SWI     XOS_ReadUnsigned
        Push    "R2"            ; Pulled as R0 when OSByte called
        BVS     %FT90
        BL      %FT10

TV_EntryPoint

        MOV     R0, #10
        SWI     XOS_ReadUnsigned
        BVS     %FT90
        STR     R2, [stack, #4]
        BL      %FT10
        MOV     R0, #10
        SWI     XOS_ReadUnsigned
        BVS     %FT90
        STR     R2, [stack, #8]

        BL      %FT10                ; check for EOL: goes to 05 if end
        ADR     R0, ErrorBlock_TooManyParms
      [ International
        BL      TranslateError
      |
        SETV
      ]
90      ADD     sp, sp, #12    ; Error before we'd pulled r0-r2 for osbyte
        EXIT

        MakeErrorBlock  TooManyParms

05
        Pull    "R0-R2"
        SWI     XOS_Byte
        EXIT

; Skip leading spaces and optional comma

10      LDRB    R2, [R1], #1
        CMP     R2, #" "
        BEQ     %BT10
        CMP     R2, #","
        MOVEQ   PC, lr         ; Let ReadUnsigned strip leading spaces.
        CMP     R2, #CR
        CMPNE   R2, #LF
        CMPNE   R2, #0
        BEQ     %BT05          ; Terminated command, so execute the osbyte
        SUB     R1, R1, #1     ; Back to first char
        MOV     PC, lr


TV_Code ALTENTRY ; must be same as FX_Code !

        MOV     R1, #144        ; OSBYTE number
        MOV     R2, #0
        MOV     R14, #0
        Push   "R1, R2, lr"
        MOV     R1, R0
        B       TV_EntryPoint


Shadow_Code Entry

        CMP     R1, #0
        MOV     R1, R0
        MOV     R0, #10 + (1:SHL:30)
        SWINE   XOS_ReadUnsigned
        MOVEQ   R2, #0
        EXIT    VS
        BL      CheckEOL
        BNE     ShadowNaff
        MOV     R0, #114
        MOV     R1, R2
        SWI     XOS_Byte
        EXIT

ShadowNaff
        ADRL    R0, ErrorBlock_BadNumb
      [ International
        BL      TranslateError
      |
        SETV
      ]
        EXIT

CheckEOL
        LDRB    R0, [R1], #1
        CMP     R0, #" "
        CMPNE   R0, #13
        CMPNE   R0, #10
        CMPNE   R0, #0
        MOV     PC, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Key_Code Entry

        SUB     sp, sp, #32
        MOV     R1, R0
        MOV     r6, sp
        LDR     R2, %FT02               ; Load 'Key$'
        STR     R2, [R6], #4
        MOV     R0, #10 + (1 :SHL: 29)  ; default base
        MOV     R2, #15                 ; maximum key
        SWI     XOS_ReadUnsigned
        BVS     %FT90
        CMP     R2, #10
        MOVGE   R4, #"1"
        STRGEB  R4, [R6], #1
        SUBGE   R2, R2, #10
        ADD     R2, R2, #"0"
        STRB    R2, [R6]
        MOV     R2, #0
        STRB    R2, [R6, #1]
        MOV     R0, sp
        MOV     R3, #0
        MOV     R4, #VarType_String
        SWI     XOS_SetVarVal

80      ADD     sp, sp, #32
        EXIT

90      ADR     r0, ErrorBlock_BadKey
      [ International
        BL      TranslateError
      |
        SETV    ; It needs setting here !
      ]
        B       %BT80

        MakeErrorBlock BadKey
02
        DCB     "Key$"                  ; Must be aligned
        ALIGN

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Exec, Spool and SpoolOn share a common body

Exec_Code Entry "$UtilRegs"

        MOV     r3, #&40        ; OPENIN exec
        MOV     r4, #198        ; r0b for osbyte exec
        B       %FT01


Spool_Code ALTENTRY

        MOV     r3, #&80        ; OPENOUT spool
        B       %FT00


SpoolOn_Code ALTENTRY

        MOV     r3, #&C0        ; OPENUP spoolon

00      MOV     r4, #199        ; r0b for osbyte spool/spoolon

01      MOV     r5, r0          ; Save filename^
        MOV     r6, r1          ; Save n parms

        MOV     r0, r4          ; Read old exec/spool handle
        MOV     r1, #0          ; Write 0 as handle; we may be just closing
        MOV     r2, #0          ; and keep zero if open error (cf. RUN)
        SWI     XOS_Byte        ; Won't cause error
        BL      CloseR1
        EXIT    VS

        CMP     r6, #0          ; No filename present ?
        EXIT    EQ              ; ie. just closing down exec/spool ?

        MOV     r1, r5          ; -> filename
        MOV     r0, r3          ; OPENIN exec/OPENUP spoolon/OPENOUT spool
        BL      OpenFileWithWinge
        EXIT    VS

        CMP     r3, #&C0        ; Doing SPOOLON ? VClear
        BLEQ    MoveToEOF       ; PTR#r1:= EXT#r1

        MOV     r0, r4          ; Write new exec/spool handle (r1)
        MOV     r2, #0
        SWIVC   XOS_Byte        ; May have got error in moving to EOF
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; List, Print and Type share a common body

listopt   RN    r2
lastchar  RN    r3
linecount RN    r4
charcount RN    r5

lnum      *     2_01    ; Line numbers
type      *     2_10    ; GSREAD format ?

filterprinting  * 2_10000000            ; Bits controlling printing
linenumbering   * 2_01000000
expandtabs      * 2_00100000

forcetbsrange   * 2_00001000
allowtbschar    * 2_00000100
unprintangle    * 2_00000010
unprinthex      * 2_00000001
unprintdot      * 2_00000001

Print_Code Entry "$UtilRegs"

        MOV     listopt, #0             ; No line numbers, raw ASCII
        B       %FT01


List_Code ALTENTRY

        MOV     listopt, #(filterprinting + linenumbering)
        MOV     linecount, #0
        B       %FT00


TypeArgs = "File/A,TabExpand/S",0
        ALIGN

Type_Code ALTENTRY

        MOV     listopt, #filterprinting

00      MOV     r6, r1                  ; no. params
        BL      ReadGSFormat            ; Read configured GSFormat bits
        EXIT    VS                      ; I2C could be faulty ! File not open
        ORR     listopt, listopt, r1

        CMP     r6, #1
        BEQ     %FT01
        Push   "R2, R3"
        MOV     R1, R0                  ; args given
        ADR     R0, TypeArgs
        LDR     R2, =ArgumentBuffer
        MOV     R3, #LongCLISize
        SWI     XOS_ReadArgs
        Pull   "R2, R3", VS
        EXIT    VS
        LDR     R0, [R2, #4]            ; tabflag
        CMP     R0, #0
        LDR     R0, [R2, #0]            ; filename ptr
        Pull   "R2, R3"
        ORRNE   listopt, listopt, #expandtabs

01      MOV     lastchar, #0            ; Reset NewLine indicator

        MOV     r1, r0                  ; Point to filename
        MOV     r0, #&40                ; han := OPENIN <filename>
        BL      OpenFileWithWinge
        EXIT    VS

10      SWI     XOS_ReadEscapeState     ; Won't cause error
        BCS     CloseThenAckEscape

        MOV     charcount, #0           ; No characters printed this line

        SWI     XOS_BGet                ; Get first character of line
        BVS     UtilityExitCloseR1
        BCS     UtilityExitCloseR1      ; EOF ?

        TST     listopt, #linenumbering ; Do we want to print the line number ?
        BLNE    LineNumberPrint
        BVS     UtilityExitCloseR1

; Doing ASCII (print) or GSREAD (type, list) ?

30      TST     listopt, #filterprinting
        BEQ     %FT35

; GSREAD format printing

        CMP     r0, #CR                 ; CR and LF both line terminators
        CMPNE   r0, #LF
        BEQ     %FT70

        CMP     r0, #TAB
        BNE     %FT31
        TST     listopt, #expandtabs
        BEQ     %FT31

; simple tab expansion: 8 spaces
        SWI     XOS_WriteS
        =      "        ",0
        ALIGN
        B       %FT32

31      MOV     lastchar, r0
        CMP     r0, #""""               ; Don't display quotes in GSREAD though
        CMPNE   r0, #"<"                ; Or left angle
        BEQ     %FT35
        BL      PrintCharInGSFormat

32      BVC     %FT40

35      SWIVC   XOS_WriteC
        BVS     UtilityExitCloseR1
        ADD     charcount, charcount, #1

40      SWI     XOS_ReadEscapeState     ; Won't cause error
        BCS     CloseThenAckEscape

        SWI     XOS_BGet                ; Get another character on this line
        BVS     UtilityExitCloseR1
        BCC     %BT30                   ; Loop if not EOF

50      TST     listopt, #filterprinting
        SWINE   XOS_NewLine             ; Terminate with NewLine if not *Print
        B       UtilityExitCloseR1


; Hit LF or CR in GSFormat mode, decide whether to give a NewLine or not

70      CMP     r0, lastchar            ; NewLine if same as last time eg LF,LF
        SWIEQ   XOS_NewLine
        BVS     UtilityExitCloseR1
        BEQ     %BT10                   ; Loop back and do another line

        CMP     lastchar, #CR           ; Don't give another NewLine if we've
        CMPNE   lastchar, #LF           ; had CR, LF or LF, CR
        MOVEQ   lastchar, #0            ; Reset NewLine indicator so more will
        BEQ     %BT40                   ; Loop and do more chars in this line

        MOV     lastchar, r0            ; Save char forcing this NewLine
        SWI     XOS_NewLine             ; Do NewLine then another line
        BVC     %BT10
        B       UtilityExitCloseR1

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Dump_Code Entry "$UtilRegs"

        MOV     r7, r1                  ; Remember nparms
        MOV     r8, r0                  ; Remember filename^ for below
        MOV     r1, r0                  ; -> filename

        MOV     r0, #&40                ; han := OPENIN <filename>
        BL      OpenFileWithWinge
        EXIT    VS                      ; File not yet open
        MOV     r9, r1                  ; Save handle

        MOV     r0, #OSFile_ReadWithType
        MOV     r1, r8                  ; Restore filename^
        SWI     XOS_File                ; Must exist and be a file now
        MOVVS   r1, r9                  ; Restore handle in case of error/exit
        BVS     UtilityExitCloseR1

        TEQ     r0, #object_nothing     ; It opened a moment ago, assume stream
                                        ; like file (or broken FS). Rely on EOF.
        MOVEQ   r6, #0
        MOVEQ   r4, #-1

        CMP     r4, #0                  ; Zero length ?
        BEQ     UtilityExitCloseR1      ; Nothing to do then ! VClear

        MOV     r5, r9                  ; Standard place for handle below

; Default display at load addr of file (r2) unless special

        BL      ReadGSFormat            ; Only interested in some bits
        BVS     UtilityExitCloseR1
        AND     r10, r1, #forcetbsrange + allowtbschar

        CMP     r6, #-1                 ; Unstamped file ?
        MOVNE   r2, #0                  ; Display start = 0
        MOV     r3, #0                  ; Default PTR# = 0
                                        ; Funny order 'cos of ReadOptionalLoadAndExec

        CMP     r7, #1                  ; Only filename specified ?
        BEQ     %FA10                   ; If so, use loadaddr and ptr=0

        MOV     r1, r8                  ; Get back filename^
        BL      SkipToSpace             ; Over the filename
        BL      ReadOptionalLoadAndExec ; Abuse ! r3 := start, r2 := disp start
        MOVVS   r1, r5
        BVS     UtilityExitCloseR1

        ADD     r2, r3, r2              ; Display offset = disparm/loadaddr+ptr

10      Swap    r2, r3                  ; r2 := start, r3 := disp start
        CMP     r2, r4                  ; Is ptr > ext ? VClear
        MOVHS   r1, r5
        BLHS    SetErrorOutsideFile

        MOVVC   r0, #OSArgs_SetPTR
        MOVVC   r1, r5
        SWIVC   XOS_Args                ; PTR#r1 := start offset
        MOVVC   r7, #0

        BLVC    ReadWindowWidth
        BVS     UtilityExitCloseR1

        SUB     r9, r0, #12+1           ; -ExtraFields (address and separators)
        MOV     r9, r9, LSR #2   ; Two nibbles, one space and one char per byte

        Push    r10                     ; Save format bits
        MOV     r10, #(1 :SHL: 31)      ; Move 1 bit down until not zero
12      MOVS    r10, r10, LSR #1
        MOVEQ   r9, #1                  ; Always 1 byte per line at least
        BEQ     %FT15
        TST     r10, r9                 ; Mask against r9 (byte count)
        BEQ     %BT12                   ; Not hit yet ?

        AND     r9, r9, r10, LSR #1     ; Take the bit one lower down
        ORR     r9, r9, r10             ; And the bit we matched. Yowzay !

15      MOV     r1, r5                  ; Get handle back
        Pull    r10                     ; Get format back


        SUB     sp, sp, #256            ; Need temp frame now

; Main Dump loop

30      SWI     XOS_ReadEscapeState     ; Won't cause error
        ADDCS   sp, sp, #256
        BCS     CloseThenAckEscape

; Get line of data (r9 bytes). Keep track of how many bytes were read in r4

        MOV     r2, sp                  ; Temp buffer
        MOV     r4, #0
35      SWI     XOS_BGet                ; Fall out of loop if EOF
        BVS     UtilityExitCloseR1_256
        STRCCB  r0, [r2, r4]
        ADDCC   r4, r4, #1
        CMPCC   r4, r9
        BCC     %BT35

        CMP     r4, #0                  ; No bytes to do this line ?
        BEQ     UtilityExitCloseR1_256

; Must preserve r4 till end for testing

        ANDS    r7, r7, #15             ; Print title every 16 lines of data
        BNE     %FT54


      [ International
        SWI     XOS_NewLine
        BL      WriteS_Translated
        DCB     "Address:Address  :",0
        ALIGN
      |
        SWI     XOS_WriteS              ; Print title start
        DCB     LF, CR
        DCB     "Address  :", 0
        ALIGN
      ]
        BVS     UtilityExitCloseR1_256

        MOV     r8, #0
50      ADD     r0, r3, r8              ; Print byte == LSB of
        SWI     XOS_WriteI+" "          ; display across page
        BLVC    HexR0Byte
        BVS     UtilityExitCloseR1_256
        ADD     r8, r8, #1
        CMP     r8, r9
        BNE     %BT50

        CMP     r9, #11                 ; No room to print title end ?
        BLO     %FT52                   ; VClear

        SWI     XOS_WriteS
        DCB     " : ", 0
        ALIGN
        BVS     UtilityExitCloseR1_256

        SUB     r8, r9, #10             ; Centre 'ASCII data' over data
        MOVS    r8, r8, LSR #1
51      SUBS    r8, r8,#1               ; VClear
        SWI     XOS_WriteI+" "
        BVS     UtilityExitCloseR1_256
        BPL     %BT51

      [ International
        BL      WriteS_Translated
        DCB     "ASCII:ASCII data",0
        ALIGN
      |
        SWI     XOS_WriteS
        DCB     "ASCII data", 0
        ALIGN
      ]

52      SWIVC   XOS_NewLine
        SWIVC   XOS_NewLine

54      MOVVC   r0, r3                  ; Print start of line address
        BLVC    HexR0LongWord
        SWIVC   XOS_WriteI+" "
        SWIVC   XOS_WriteI+":"
        BVS     UtilityExitCloseR1_256

; Print line of data in hex

        MOV     r5, #0
55      LDRB    r0, [r2, r5]
        SWI     XOS_WriteI+" "
        BVS     UtilityExitCloseR1_256
        CMP     r5, r4                  ; Byte valid ?
        SWICS   XOS_WriteI+" "
        BVS     UtilityExitCloseR1_256
        SWICS   XOS_WriteI+" "
        BVS     UtilityExitCloseR1_256
        BLCC    HexR0Byte               ; Alters C, so do last
        BVS     UtilityExitCloseR1_256
        ADD     r5, r5, #1
        CMP     r5, r9
        BCC     %BT55

        SWI     XOS_WriteS
        DCB     " : ", 0
        ALIGN
        BVS     UtilityExitCloseR1_256

; Print line of data in ASCII

        MOV     r5, #0
65      LDRB    r0, [r2, r5]
        TST     r10, #forcetbsrange     ; Forcing into 00..7F ?
        BICNE   r0, r0, #&80
        TST     r10, #allowtbschar
        BEQ     %FT66
        CMP     r0, #&80                ; Print tbs unmolested
        BHS     %FT67
66      CMP     r0, #" "                ; Space through twiddle are valid
        RSBGES  r14, r0, #&7E
        MOVLT   r0, #"."
67      SWI     XOS_WriteC
        BVS     UtilityExitCloseR1_256
        ADD     r5, r5, #1
        CMP     r5, r4
        BCC     %BT65

        SWI     XOS_NewLine
        BVS     UtilityExitCloseR1_256
        ADD     r7, r7, #1              ; Increment line count
        ADD     r3, r3, r9              ; Increment display address by r9 bytes
        CMP     r4, r9                  ; Loop till we couldn't fill a line
        BEQ     %BT30

; .............................................................................

UtilityExitCloseR1_256

        ADD     sp, sp, #256            ; Kill temp frame

; .............................................................................

UtilityExitCloseR1

        BL      CloseR1                 ; Accumulates V

        Pull    "$UtilRegs, pc"         ; Back to *Command handler

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Append and Build share a common body

Append_Code Entry "$UtilRegs"

        MOV     r1, r0          ; -> filename
        MOV     r0, #&C0        ; OPENUP
        B       %FT01


Build_Code ALTENTRY

        MOV     r1, r0          ; -> filename
        MOV     r0, #&80        ; OPENOUT

01      BL      OpenFileWithWinge
        EXIT    VS

        SUB     sp, sp, #256

        MOV     r5, r1          ; Save handle for later
        BL      MoveToEOF       ; Can do this anyhow as ext#(openout)=0

        MOV     linecount, #0

10      BLVC    LineNumberPrint ; Escape is tested for on OS_ReadLine.Err below
        BVS     UtilityExitCloseR1_256

        MOV     r0, sp             ; Get a line from Joe Punter
        MOV     r1, #256-1         ; -1 for terminator
        MOV     r2, #" "
        MOV     r3, #&FF
        SWI     XOS_ReadLine32
        MOVVS   r1, r5
        BVS     UtilityExitCloseR1_256
        MOV     r3, #CR                 ; Terminate source string
        STRB    r3, [r0, r1]
        MOVCC   FSUTtemp, #0            ; Ended with ESCAPE ?
        MOVCS   FSUTtemp, #-1
        MOVCS   r0, #&7E                ; Ack. ESCAPE, not error
        SWICS   XOS_Byte
        BVS     UtilityExitCloseR1_256

        MOV     r2, sp                  ; r2 -> buffer to translate
        MOV     r1, r5                  ; Get handle back
18      LDRB    r0, [r2], #1            ; Put all the spaces out ourselves !
        CMP     r0, #" "                ; VClear
        SWIEQ   XOS_BPut
        BVS     UtilityExitCloseR1_256
        BEQ     %BT18

        SUB     r0, r2, #1         ; r0 -> past spaces, rest to translate
        MOV     r2, #(1 :SHL: 31)  ; No quote funnies, don't end on space, do |
        SWI     XOS_GSInit

20      SWIVC   XOS_GSRead              ; Get a char
        MOVVS   R1, R5
        BVS     UtilityExitCloseR1_256
        BCS     %FT30                   ; End of string ?
        MOV     r3, r0                  ; Save GSState
        MOV     r0, r1                  ; Char from GSRead
        MOV     r1, r5                  ; Get handle back
        SWI     XOS_BPut
        BVS     UtilityExitCloseR1_256
        MOV     r0, r3                  ; Restore GSState
        B       %BT20                   ; And loop

30      CMP     FSUTtemp, #0            ; Did we read ESCAPE ? VClear
        MOV     r1, r5                  ; In any case, we want r1 handle
        MOV     r0, #CR                 ; If not, stick a CR on eoln
        SWIEQ   XOS_BPut
        BEQ     %BT10                   ; Finished if ESCAPE was pressed
                                        ; Catch error back there too

        SWIVC   XOS_NewLine

        B       UtilityExitCloseR1_256

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OSFile routines: Load, Save, Create, Delete and Remove

Load_Code Entry "$UtilRegs"

        MOV     r7, r0                  ; -> filename
        CMP     r1, #1                  ; Just filename (1 parm) ?
        MOVEQ   r3, #&FF                ; Load at its own address if so
        BEQ     %FT90

        BL      SkipNameAndReadAddr
        EXIT    VS
        BLCS    SetErrorBadAddress      ; Must check for trailing junk
        MOVVC   r3, #0                  ; Got load address from command line

90      MOVVC   r0, #OSFile_Load
        ORRVC   r3, r3, #1<<31          ; Do OS_SynchroniseCodeAreas after load
        MOVVC   r1, r7                  ; Get filename^ back
        SWIVC   XOS_File
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Save_Error
        DCD       ErrorNumber_Syntax
      [ International
        DCB       "BadSav:Bad parameters for *Save", 0
      ]
        ALIGN

Save_Code Entry "$UtilRegs"

        BL      SkipNameAndReadAddr
        EXIT    VS

        MOV     r4, r2          ; Got start address
        BL      SkipSpaces
        MOV     r5, r0          ; Preserve state
        CMP     r0, #"+"        ; Is it a +<length> parm ?
        ADDEQ   r1, r1, #1      ; Skip '+' then
        BLEQ    SkipSpaces      ; And any trailing spaces
        BL      ReadAtMost8Hex  ; Read a word anyway
        EXIT    VS

        CMP     r5, #"+"
        MOVNE   r5, r2          ; <end addr> ?
        ADDEQ   r5, r2, r4      ; Form <end addr> := <start addr> + <length>
        MOV     r2, r4          ; r2, r3 := both r4 by default
        MOV     r3, r4
        BL      ReadOptionalLoadAndExec
        SETV    CS
        ADRVS   R0, Save_Error  ; If there's anything on the end, it's an error
      [ International
        BLVS    TranslateError
      ]
        MOVVC   r0, #OSFile_Save
        MOVVC   r1, r7          ; Get filename^ back
        SWIVC   XOS_File
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Create_Code Entry "r1, $UtilRegs"

        CMP     r1, #1                  ; Filename only -> length 0, dated
        MOVEQ   r7, r0                  ; Filename^
        MOVEQ   r2, #0                  ; Will be copied to r5 in a bit
        BLNE    SkipNameAndReadAddr
        EXIT    VS
        MOV     r5, r2                  ; Got length, put in as end address
        MOV     r4, #0                  ; So start addr shall be .. 0 !

        LDR     r14, [sp]               ; No load, exec -> datestamp FFD
        CMP     r14, #3
        MOVLO   r0, #OSFile_CreateStamp
        LDRLO   r2, =&FFFFFFFD          ; Only bottom 12 bits are of interest
        MOVHS   r0, #OSFile_Create      ; Makes it an immediate constant
        MOVHS   r2, #0                  ; Load/Exec default to 0
        MOVHS   r3, #0
        BLHS    ReadOptionalLoadAndExec

        MOVVC   r1, r7                  ; Get filename^ back
        SWIVC   XOS_File
        EXIT

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Delete and Remove share a common body

Delete_Code Entry

        MOV     r6, #0                  ; Give error if file doesn't exist
        B       %FT01                   ; Use a reg. not affected by OSFile !

Remove_Code ALTENTRY

        MOV     r6, #-1                 ; Don't winge

01      MOV     r1, r0                  ; -> filename
        MOV     r0, #OSFile_Delete
        SWI     XOS_File
        EXIT    VS

        ASSERT  object_nothing = 0
        CMP     r0, r6                  ; Are we going to winge ?
        MOVEQ   r0, #OSFile_MakeError   ; Give pretty error now, says Tutu
        MOVEQ   r2, #object_nothing
        SWIEQ   XOS_File
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Gosh, doesn't use UtilRegs !!!

Opt_Code Entry

        MOV     r3, #0                  ; Default parms are 0, 0
        MOV     r4, #0
        CMP     r1, #0                  ; No parms ? VClear
        BEQ     %FT50

        MOV     r1, r0
        MOV     r0, #10                 ; Default base 10, allow naff term ','
        SWI     XOS_ReadUnsigned        ; Read first parm
        EXIT    VS
        MOV     r3, r2

        BL      FS_SkipSpaces           ; Try getting another parm anyway
        BCC     %FT50                   ; End of the line

        TEQ     r0, #","                ; commas too !
        ADDEQ   r1, r1, #1
        BLEQ    FS_SkipSpaces
        CMP     r0, #space              ; Anything here ?
        BEQ     %FT99

        MOV     r0, #(1 :SHL: 31) + 10  ; Default base 10, no bad terms
        SWI     XOS_ReadUnsigned        ; Read second parm
        MOVVC   r4, r2

50      MOVVC   r0, #FSControl_Opt
        MOVVC   r1, r3
        MOVVC   r2, r4
        SWIVC   XOS_FSControl
        EXIT

99      ADR     r0, SyntaxError_StarOpt
      [ International
        BL      TranslateError
      |
        SETV
      ]
        EXIT


SyntaxError_StarOpt
        DCD     ErrorNumber_Syntax
        DCB     "OptErr:Syntax: *Opt [<x> [[,] <y>]]", 0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;              H o r r i b l e   l i t t l e   s u b r o u t i n e s
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Variegated output routines

HexR0LongWord Entry "r0"

        MOV     r0, r0, ROR #16
        BL      HexR0Word
        MOVVC   r0, r0, ROR #32-16
        BLVC    HexR0Word
        STRVS   r0, [sp]
        EXIT


HexR0Word Entry "r0"

        MOV     r0, r0, ROR #8
        BL      HexR0Byte
        MOVVC   r0, r0, ROR #32-8
        BLVC    HexR0Byte
        STRVS   r0, [sp]
        EXIT


HexR0Byte Entry "r0"

        MOV     r0, r0, ROR #4
        BL      HexR0Nibble
        MOVVC   r0, r0, ROR #32-4
        BLVC    HexR0Nibble
        STRVS   r0, [sp]
        EXIT


HexR0Nibble Entry "r0"

        AND     r0, r0, #15
        CMP     r0, #10
        ADDCC   r0, r0, #"0"
        ADDCS   r0, r0, #"A"-10
        SWI     XOS_WriteC
        STRVS   r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SkipSpaces ROUT

10      LDRB    r0, [r1], #1
        CMP     r0, #" "        ; Leave r1 -> ~space
        BEQ     %BT10
        SUB     r1, r1, #1
        CLRV
        MOV     pc, lr          ; r0 = first ~space. Can't really fail


SkipToSpace Entry

10      LDRB    lr, [r1], #1
        CMP     lr, #&7F
        CMPNE   lr, #" "        ; Leave r1 -> space or CtrlChar
        BHI     %BT10
        SUB     r1, r1, #1
        CLRV
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 -> string

; Out   flags from CMP r0, #space for eol detection

FS_SkipSpaces ROUT

10      LDRB    r0, [r1], #1
        CMP     r0, #space      ; Leave r1 -> ~space
        BEQ     %BT10
        SUB     r1, r1, #1
        MOV     pc, lr          ; r0 = first ~space

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = open mode
;       r1 -> filename

; Out   VC: r0 = r1 = handle
;       VS: r0 -> error (FilingSystemError or 'NotFound')

OpenFileWithWinge Entry

        ORR     r0, r0, #(open_mustopen :OR: open_nodir) ; Saves us code here
        SWI     XOS_Find
        MOVVC   r1, r0
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; PTR#handle := EXT#handle

; In    r1 = handle to use

; Out   VC: PTR moved
;       VS: r0 -> Filing System Error

MoveToEOF Entry "r0, r2"

        MOV     r0, #OSArgs_ReadEXT
        SWI     XOS_Args
        MOVVC   r0, #OSArgs_SetPTR
        SWIVC   XOS_Args
        STRVS   r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CloseThenAckEscape

        BL      CloseR1

        BL      AckEscape
        Pull    "$UtilRegs, pc"         ; Common exit - back to MOS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 = handle to close, or 0 means don't do anything

; Out   VC: file closed, or nothing done
;       VS: r0 -> Filing System Error, or VSet on entry

CloseR1 EntryS "r0"

        CMP     r1, #0                  ; Is there a handle to close ? VClear
        MOVNE   r0, #0                  ; CLOSE#han
        SWINE   XOS_Find
        EXITS   VC                      ; Accumulate V

        STR     r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Increment then print a line number in decimal

LineNumberPrint Entry "r0-r1"

        ADD     linecount, linecount, #1 ; r0 := ++linecount
        MOV     r0, linecount
        MOV     r1, #1                  ; Print leading spaces
        BL      PrintR0Decimal
        SWIVC   XOS_WriteI+" "
        STRVS   r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = number to print
;       r1 = 0 -> strip spaces
;            1 -> print leading spaces

; Number gets printed RJ in a field of 4 if possible, or more as necessary

PrintR0Decimal Entry "r0-r3"

        SUB     sp, sp, #32
        MOV     r3, r1                  ; Save flag
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_BinaryToDecimal     ; No errors from this
        CMP     r3, #0                  ; If not doing spaces or >= 4 chars
        CMPNE   r2, #4                  ; in the number, son't print any

        ADRLT   r0, %FT98-1             ; Point to right amount of spaces
        ADDLT   r0, r0, r2
        SWILT   XOS_Write0

10      LDRVCB  r0, [r1], #1
        SWIVC   XOS_WriteC
        BVS     %FT99
        SUBS    r2, r2, #1
        BNE     %BT10

99      ADD     sp, sp, #32
        STRVS   r0, [sp]
        EXIT

98
        DCB     "   ", 0                ; Three spaces, null
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Read configured GS string format
;
; Out   r1 = bits read from CMOS ram

ReadGSFormat Entry "r0, r2"

        MOV     r0, #ReadCMOS
        MOV     r1, #PrintSoundCMOS
        SWI     XOS_Byte
        ANDVC   r1, r2, #2_1111         ; Mask out all but my bits
        STRVS   r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0b = char to print using current listopt

; Out   r0 corrupt

PrintCharInGSFormat Entry "r1, listopt"

        AND     r0, r0, #&FF    ; Just in case
        TST     listopt, #forcetbsrange ; Forcing tbs into 00..7F ?
        BIC     listopt, listopt, #forcetbsrange
        BICNE   r0, r0, #&80            ; Take top bit out if so

        CMP     r0, #" "        ; Do we need to do this at all ?
        RSBGES  r14, r0, #&7E
        BLT     %FT10           ; LT if not in range &20-&7E
        CMP     r0, #"|"        ; Solidus ? VClear
        CMPNE   r0, #""""       ; Quote ?
        CMPNE   r0, #"<"        ; Left angle ?
        SWINE   XOS_WriteC      ; Nope, so let's print the char and exit
        EXIT    VS
        EXIT    NE


10      TST     listopt, #allowtbschar  ; International format bit ?
        BIC     listopt, listopt, #allowtbschar
        BEQ     %FT15
        CMP     r0, #&80
        BHS     %FT45                   ; Print tbs char and exit

15      TST     listopt, #unprintangle  ; Angle bracket format ?
        BNE     %FT50

        TST     listopt, #unprintdot    ; Doing unprintable dot format (2_01) ?
        BEQ     %FT16

        CMP     r0, #" "                ; Only space to twiddle are printable
        RSBGES  r14, r0, #&7E
        MOVLT   r0, #"."                ; All others are dot
        B       %FT45                   ; Print char and exit


; Normal BBC GSREAD format (2_00)

16      CMP     r0, #&80                ; Deal with tbs first
        BIC     r0, r0, #&80
        BLO     %FT17
        SWI     XOS_WriteI+"|"
        SWIVC   XOS_WriteI+"!"
        EXIT    VS

17      CMP     r0, #&7F                ; Delete ? -> |?. VClear
        MOVEQ   r0, #"?"
        CMPNE   r0, #""""               ; Quote ? -> |"
        CMPNE   r0, #"|"                ; Solidus ? -> ||
        SWIEQ   XOS_WriteI+"|"
        EXIT    VS
        CMP     r0, #&1F                ; CtrlChar ? -> |<char+@>. VClear
        ADDLS   r0, r0, #"@"
        SWILS   XOS_WriteI+"|"

45      SWI     XOS_WriteC              ; Used from above
        EXIT


50 ; Angle bracket format, either hex (2_11) or decimal (2_10)

        SWI     XOS_WriteI+"<"
        TST     listopt, #unprinthex
        BNE     %FT60
        MOV     r1, #0                  ; Strip leading spaces
        BLVC    PrintR0Decimal
        SWIVC   XOS_WriteI+">"
        EXIT


60      SWIVC   XOS_WriteI+"&"
        BLVC    HexR0Byte
        SWIVC   XOS_WriteI+">"
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 -> filename. Used by most MOS OSFile routines for initial decoding

; Out   r1 -> past address read
;       r2 = address read
;       r7 = initial filename^
;       VS : failed to read address, r0 -> error
;       CS : text present comes immediately after address

SkipNameAndReadAddr Entry

        MOV     r7, r0          ; Save filename^
        MOV     r1, r0          ; -> filename
        BL      SkipToSpace     ; Over the filename
        BL      SkipSpaces      ; To the address
        BL      ReadAtMost8Hex  ; Go read it Floyd !
        LDRVCB  r0, [r1]        ; Anything on the end ?
        CMPVC   r0, #" "+1      ; CtrlChar + space ok
        EXIT                    ; VC/VS from readhex or VC, CC/CS from CMP

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r2, r3 = load/exec addresses to use if none provided. r1 -> string

; Out   r2, r3 conditionally updated, r1 updated, past any trailing spaces
;       VS if failed, error ('Bad Address' or whatever) set
;       CS if something comes afterwards ...

ReadOptionalLoadAndExec Entry "r0, FSUTtemp"

        MOV     FSUTtemp, r2    ; Save initial value

        BL      SkipSpaces
        CMP     r0, #" "        ; No more parms ?
        EXIT    LO              ; VClear, r2, r3 unaffected

        BL      ReadAtMost8Hex
        BVS     %FT99
        MOV     r3, r2
        MOV     r2, FSUTtemp
        BL      SkipSpaces
        CMP     r0, #" "        ; No more parms ?
        EXIT    LO              ; VClear, r2 unaffected, r3 updated

        BL      ReadAtMost8Hex
        BLVC    SkipSpaces      ; Anything on the end ?
        CMPVC   r0, #" "
99      STRVS   r0, [sp]
        EXIT                    ; VC/VS from readhex or VC, CC/CS from CMP

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Read a hex (default) address from a string

; In    r1 -> string

; Out   VC: r1 -> first char not used in building number, r2 = number
;       VS: error ('Bad Address') set

ReadAtMost8Hex Entry "r0, r3-r4"

        MOV     R0, #16                 ; default base, don't trap bad terms
        SWI     XOS_ReadUnsigned
        STRVS   r0, [sp]
        EXIT                    ; VClear -> good hex number / VSet -> bad

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Set various errors: VSet always on exit

SetErrorBadAddress

        ADR     r0, ErrorBlock_BadAddress
      [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
      ]
        RETURNVS

        MakeErrorBlock BadAddress


SetErrorOutsideFile

        ADR     r0, ErrorBlock_OutsideFile
      [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
      ]
        RETURNVS

        MakeErrorBlock OutsideFile


SetErrorEscape

        ADR     r0, ErrorBlock_Escape
      [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
      ]
        RETURNVS

        MakeErrorBlock Escape

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

AckEscape
        Push   "r1-r2, lr"
        MOV     r0, #&7E
        SWI     XOS_Byte

        BLVC    SetErrorEscape          ; Only set ESCAPE error if no override
        Pull    "r1-r2, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        END
