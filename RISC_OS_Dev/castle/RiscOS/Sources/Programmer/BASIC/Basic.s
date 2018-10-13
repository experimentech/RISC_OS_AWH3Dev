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
;> Basic

   [ :DEF: VFPAssembler
VFPDataResourceFile
        = "Resources:$.Resources.BASIC.VFPData",0
        ALIGN
   ]

MODULEMAIN
        WritePSRc USR_mode,R1           ; IRQs+FIQs on, USR26/32 mode
        SWI     OS_GetEnv
      [ FPOINT=2
        MOV     R2,R1
        MOV     R0,#VFPSupport_Context_UserMode+VFPSupport_Context_AppSpace
        MOV     R1,#32
        SWI     XVFPSupport_CheckContext
        MOVVS   R0,#VFPSupport_Context_UserMode+VFPSupport_Context_AppSpace
        MOVVS   R1,#16                  ; 32 registers not available, try 16
        SWIVS   VFPSupport_CheckContext
        MOV     R6,R0
        MOV     R7,R1
        SUB     R1,R2,R0
        SUB     R1,R1,#VARS
        SUBS    R1,R1,#VFPCONTEXT+256
      |
        SUB     R1,R1,#VARS
        SUBS    R1,R1,#FREE+256
      ]
        BPL     MAIN
        ADR     R0,SEVEREERROR
        MOV     R1,#0                   ;global messages
        MOV     R2,#0                   ;internal buffer
        SWI     XMessageTrans_ErrorLookup
        SWI     OS_GenerateError
        SWI     OS_Exit
SEVEREERROR
        DCD     ErrorBase_BASIC + &FF
        DCB     "NoStore",0
        ALIGN

OSESCR  MOV     R11,R11,LSL #1
        AND     R11,R11,#&80
        MOV     R12,#VARS
        STRB    R11,[R12,#ESCFLG]
OSESCRT MOV     PC,R14
OSERRR                                 ;called by System Error Handler
        MOV     R14,#VARS
        ; Additional code to recover r12 after error IF it was saved
        LDRB    R14,[R14,#MEMM]        ;get MEMM flags
        TST     R14,#2                 ;is r12 saved flag on?
        MOV     R14,#VARS              ;get value of ARGP (again)
        LDRNE   LINE,[R14,#R12STORE]   ;yes, so safe to recover r12
        ADD     R14,R14,#STRACC        ;used for error buffer
        ADD     R14,R14,#4             ;skip PC to -> error number
        B       MSGERR
OSUPCR  CMP     R0,#256
        MOVNE   PC,R14
PUTBACKHAND
        STMFD   SP!,{R0-R3,R14}
        LDR     R1,[R12,#TRACEFILE-OLDERR] ;tracefile handle
        TEQ     R1,#0
        MOV     R0,#0
        STR     R0,[R12,#TRACEFILE-OLDERR] ;kill handle!
        SWINE   XOS_Find
      [ FPOINT=2
        LDR     R0,=VFPCONTEXT-OLDERR
        ADD     R0,R12,R0
        MOV     R1,#0
        SWI     XVFPSupport_DestroyContext
      ]
        MOV     R0,#6
        LDMIA   R12!,{R1,R2,R3}
        SWI     XOS_ChangeEnvironment
        MOV     R0,#9
        LDMIA   R12!,{R1,R2}
        SWI     XOS_ChangeEnvironment
        MOV     R0,#11
        LDMIA   R12!,{R1,R2}
        SWI     XOS_ChangeEnvironment
        MOV     R0,#16
        LDMIA   R12!,{R1,R2}
        SWI     XOS_ChangeEnvironment
        LDMFD   SP!,{R0-R3,PC}

        GBLL    ONLYEMPTY
ONLYEMPTY SETL  {FALSE}

MOVEMEMORY
        TEQ     R0,#0                   ;ignore grows (ie ok to do)
        MOVPL   PC,R14
        STMFD   SP!,{R0,R2-R8,R14}
 [ {FALSE}
        SWI     OS_WriteS
        =       "Service_Memory(",0
        MOV     R1,#VARS+STRACC
        ADD     R1,R1,#128
        MOV     R2,#128
        SWI     OS_ConvertInteger4
        SWI     OS_Write0
        SWI     OS_WriteI+")"
        SWI     OS_NewLine
;       MOV     R1,#0
;       LDMFD   SP!,{R0,R2-R8,PC}
 ]
        MOV     ARGP,#VARS
        LDRB    R0,[ARGP,#MEMM]
        LDR     R1,[ARGP,#INSTALLLIST]
        LDR     R4,[ARGP,#MEMLIMIT]
        LDR     R5,[ARGP,#HIMEM]
        ; Change from MEMM as a byte flag x01 to a bit flag x01
        TST     R0,#1                   ;is "move memory" *bit* set?
        MOVEQ   R1,#0                   ;no
        LDMEQFD SP!,{R0,R2-R8,PC}       ;if not, refuse move
        TEQ     R1,#0                   ;any installed libraries?
        MOVNE   R1,#0                   ;no
        LDMNEFD SP!,{R0,R2-R8,PC}       ;if not, refuse move
        MOV     R0,#14
        MOV     R1,#0
        MOV     R2,#0
        MOV     R3,#0
        SWI     XOS_ChangeEnvironment   ;read end of application space
        TEQ     R1,R4                   ;are we using whole application space?
        TEQEQ   R1,R5                   ;and is HIMEM at the top of it?
        MOVNE   R1,#0
        LDMNEFD SP!,{R0,R2-R8,PC}       ;if not, not in a position to surrender memory.
        LDR     R4,[ARGP,#DIMLOCAL]     ;are there any DIM LOCALs in use?
        SUB     SP,SP,#4
        STMIA   SP,{SP}^                ;get user mode stack pointer
        TEQ     R4,#0
        MOVNE   R1,#0                   ;yes. refuse to move the stack
        LDR     R5,[SP],#4
        LDMNEFD SP!,{R0,R2-R8,PC}
        LDR     R4,[ARGP,#HIMEM]
        SUBS    R5,R4,R5                ;amount of space on stack
 [ ONLYEMPTY
        MOVNE   R1,#0
        LDMNEFD SP!,{R0,R2-R8,PC}       ;if stack not empty, refuse
 ]
        LDR     R6,[ARGP,#FSA]
        ADD     R2,R6,#1024
        ADD     R2,R2,R5                ;FSA+1024+amount of space on stack
        LDR     R14,[SP,#0]
        ADDS    R0,R1,R14               ;new end address
        MOVMI   R1,#0                   ;if end address is negative, we've wrapped below 0,
        LDMMIFD SP!,{R0,R2-R8,PC}       ; or gone higher than we cancope with
MOVEMEMORYOK
        SUB     R7,R0,#&8000            ;new slot
        CMP     R2,R0
        MOVHS   R1,#0
        LDMHSFD SP!,{R0,R2-R8,PC}       ;if going too small, refuse
        WritePSRc USR_mode,R3           ;change down to user mode (is this safe???)
;first move the stack down
 [ :LNOT:ONLYEMPTY
; code lifted from ENDCHANGE1 in Stmt
MOVEMEM1
        LDR     R3,[SP],#4
        STR     R3,[R6],#4              ;R6=FSA
        CMP     SP,R4                   ;R4=HIMEM
        BCC     MOVEMEM1
 ]
;change memory size
        SUB     R7,R0,SP                ;remember difference - how far the world moved!
        MOV     SP,R0
        STR     SP,[ARGP,#MEMLIMIT]
        STR     SP,[ARGP,#HIMEM]
;move stack back up again
 [ :LNOT:ONLYEMPTY
        LDR     R1,[ARGP,#FSA]
MOVEMEM2
        LDR     R3,[R6,#-4]!
        STR     R3,[SP,#-4]!
        CMP     R6,R1
        BHI     MOVEMEM2
;patch self references on the stack
        ADD     R4,ARGP,#LOCALARLIST-4
        LDR     R0,[ARGP,#ERRSTK]
        ADD     R0,R0,R7
        STR     R0,[ARGP,#ERRSTK]
MOVEMEMLOCALAR
        LDR     R3,[R4,#4]              ;next field
        TEQ     R3,#0
        BEQ     MOVEMEMLOCALARDONE
        ADD     R3,R3,R7                ;alter reference to stack
        STR     R3,[R4,#4]
        MOV     R4,R3
        LDR     R5,[R4,#8]              ;address of owner
        LDR     R6,[R5]
        ADD     R6,R6,R7                ;move owner's idea of where we are
        ADD     R1,R4,#16               ;check it's pointing at us
        CMP     R6,R1
        STREQ   R6,[R5]
        B       MOVEMEMLOCALAR
MOVEMEMLOCALARDONE
 ]
        SWI     OS_EnterOS
        MOV     R1,#Service_Memory      ;not claimed
        LDMFD   SP!,{R0,R2-R8,PC}

OSQUITR LDR     R1,[R12,#TRACEFILE-OLDERR] ;tracefile handle
        TEQ     R1,#0
        MOV     R0,#0
        STR     R0,[R12,#TRACEFILE-OLDERR] ;kill handle!
        SWINE   XOS_Find                   ;close
      [ FPOINT=2
        LDR     R0,=VFPCONTEXT-OLDERR
        ADD     R0,R12,R0
        MOV     R1,#0
        SWI     XVFPSupport_DestroyContext
      ]
        MOV     R0,#6
        LDMIA   R12!,{R1,R2,R3}
        SWI     XOS_ChangeEnvironment
        MOV     R0,#9
        LDMIA   R12!,{R1,R2}
        SWI     XOS_ChangeEnvironment
        MOV     R0,#11
        LDMIA   R12!,{R1,R2}
        SWI     XOS_ChangeEnvironment
        MOV     R0,#16
        LDMIA   R12!,{R1,R2}
        SWI     XOS_ChangeEnvironment
        ASSERT  OS_Exit_ABEX = OLDERR + 9*4
        LDMIA   R12!,{R1,R2}
        ADR     R0,EXITERR
        SWI     OS_Exit
MYNAME  =       "ARW!"
EXITERR DCD     ErrorBase_BASIC + &FE
        DCB     "BASIC program exceeded return code limit",0
        ALIGN
        LTORG
MAIN    MOV     ARGP,#VARS
        ;Create the SWI 0              ;MOV PC, R14 in the SWICODE data area
        ;and    then do a SYNCHRONISECODEAREAS, ranged.
        MOV     R0, #&EF000000         ;SWI 0
        LDR     R2, OSESCRT            ;A handy MOV PC,LR
        ADD     R1, ARGP, #SWICODE
        STMIA   R1,{R0,R2}
        ADD     R2, R1, #8             ;Size of SWICODE area
        MOV     R0, #1
        SWI     XOS_SynchroniseCodeAreas
 [ FPOINT=1 :LOR: FPOINT=2             ;only necessary for FPOINT=2 since we still rely on FPA for some ops
        MOV     R0,#&70000
        WFS     R0
 ]
 [ :DEF: VFPAssembler
        ; Find the VFP/NEON assembler data tables
        ; Deliberately not using X SWIs; the file should exist!
        MOV     R0,#&4F
        ADR     R1,VFPDataResourceFile
        SWI     OS_Find
        MOV     R3,R0
        MOV     R1,R0
        MOV     R0,#21
        SWI     OS_FSControl
        STR     R1,[ARGP,#VFPTABLES]
        MOV     R0,#0
        MOV     R1,R3
        SWI     OS_Find
 ]
 [ FPOINT=2
        ; Set up VFP context
        MOV     R0,#VFPSupport_Context_UserMode+VFPSupport_Context_AppSpace+VFPSupport_CreateContext_Activate
        MOV     R1,R7
        ADD     R2,ARGP,#VFPCONTEXT
        MOV     R3,#0
        SWI     VFPSupport_CreateContext
        ; Check for interesting features
        MOV     R0,#VFPSupport_Features_Misc
        SWI     XVFPSupport_Features
        ASSERT  VFPSupport_MiscFeature_VFPVectors_HW = VFPFLAG_Vectors
        ASSERT  VFPFLAG_Vectors < 4 ; if we got back an error pointer, we want the flag to be zero
        AND     R7,R0,#VFPFLAG_Vectors
        MOV     R0,#VFPSupport_Features_SystemRegs
        SWI     VFPSupport_Features ; No X bit, this reason code has been around forever
        TST     R2,#&F000
        ORRNE   R7,R7,#VFPFLAG_NEON
        STR     R7,[ARGP,#VFPFLAGS]
 ]
        ADRL    R0,MSGATLINE
        STR     R0,[ARGP,#ERRXLATE]
        ADD     R9,ARGP,#OLDERR
        MOV     R0,#6
        ADR     R1,OSERRR
        MOV     R2,#0
        ADD     R3,ARGP,#STRACC
        SWI     XOS_ChangeEnvironment
        STMIA   R9!,{R1,R2,R3}
        MOV     R0,#9
        ADR     R1,OSESCR
        MOV     R2,#0
        SWI     XOS_ChangeEnvironment
        STMIA   R9!,{R1,R2}
        MOV     R0,#11
        ADR     R1,OSQUITR
        ADD     R2,ARGP,#OLDERR
        SWI     XOS_ChangeEnvironment
        STMIA   R9!,{R1,R2}
        MOV     R0,#16
        ADR     R1,OSUPCR
        ADD     R2,ARGP,#OLDERR
        SWI     XOS_ChangeEnvironment
        STMIA   R9!,{R1,R2}
 [ FPOINT=2
        ADD     R0,ARGP,#VFPCONTEXT
        ADD     R0,R0,R6
        STR     R0,[ARGP,#FREEPTR]
 |
        ADD     R0,ARGP,#FREE          ;lomem
 ]
        STR     R0,[ARGP,#PAGE]
        SWI     OS_GetEnv
        MOV     SP,R1                  ;get himem limit
        STR     SP,[ARGP,#HIMEM]
        STR     SP,[ARGP,#MEMLIMIT]
        MOV     R0,#0
        STR     R0,[ARGP,#ERRLIN]
        STR     R0,[ARGP,#ERRNUM]
        STR     R0,[ARGP,#ESCWORD]
        STR     R0,[ARGP,#LOCALARLIST]
        STR     R0,[ARGP,#INSTALLLIST]
        STR     R0,[ARGP,#TRACEFILE]
        STR     R0,[ARGP,#TALLY]
        STR     R0,[ARGP,#DIMLOCAL]
        STRB    R0,[ARGP,#LISTOP]
        STRB    R0,[ARGP,#MEMM]
        MVN     R0,#0
        STR     R0,[ARGP,#WIDTHLOC]
        STRB    R0,[ARGP,#BYTESM]
        MOV     R0,#10
        ORR     R0,R0,#&900
        STR     R0,[ARGP,#INTVAR]      ;set @%
        LDR     R0,[ARGP,#SEED]
        LDRB    R1,[ARGP,#SEED+4]
        ORRS    R0,R0,R1,LSL #31       ;gets bottom bit
        LDREQ   R0,MYNAME
        STREQ   R0,[ARGP,#SEED]
        ADR     R0,REPSTR
        ADD     R2,ARGP,#ERRORS
ENTRYL  LDRB    R1,[R0],#1
        STRB    R1,[R2],#1
        TEQ     R1,#0
        BNE     ENTRYL
        BL      FROMAT
        BL      SETFSA
        BL      ORDERR
        ADD     LINE,ARGP,#STRACC
        LDR     SP,[ARGP,#HIMEM]
        MOV     R0,#0
;to stop pops getting carried away
        STMFD   SP!,{R0-R9}
        STR     SP,[ARGP,#ERRSTK]
;see if there's a name waiting to be read in
        SWI     OS_GetEnv
        ADD     R3,ARGP,#CALLEDNAME
ENTRE1  LDRB    R2,[R0],#1
        STRB    R2,[R3],#1
        TEQ     R2,#0
        BEQ     CLRSTKTITLE
        CMP     R2,#" "
        BHI     ENTRE1
        MOV     R2,#0
        STRB    R2,[R3,#-1]
ENTRE2  LDRB    R2,[R0],#1
        CMP     R2,#" "
        BEQ     ENTRE2
        MOV     R9,#2                  ;set to chain
        CMP     R2,#"-"
        BEQ     ENTRYKEYW
        BL      TITLE
        TEQ     R2,#0
        BEQ     CLRSTK
        TEQ     R2,#"@"
        BNE     ENTRYF
        MOV     R9,#0                  ;no chain
ENTRYCONT
        BL      RDHEX                  ;incore text file
        MOV     R6,R5
        TEQ     R2,#","
        BNE     BADIPHEX
        BL      RDHEX
        TEQ     R2,#0
        BNE     BADIPHEX
        CMP     R5,R6
        BLS     BADIPHEX
        MOV     R1,R6
        MOV     R7,R6
        BL      LOADFILEINCORE
ENTRYFINAL
        TST     R9,#2
        BEQ     FSASET
        LDRB    R0,[ARGP,#CALLEDNAME]
        TEQ     R0,#0
        BNE     RUNNER                 ;not QUIT so just run
 [ CHECKCRUNCH=1
        BL      CRUNCHCHK
        BEQ     RUNNER
 ]
        MOV     R0,#SAFECRUNCH
        LDR     R1,[ARGP,#PAGE]
        BL      CRUNCHROUTINE
        STR     R2,[ARGP,#TOP]
        B       RUNNER
 [ CHECKCRUNCH=1
CRUNCHCHK
        STMFD   SP!,{R0,R1,R2,R3,R4,R14}
        ADR     R0,CRUNCHSTR
        MOV     R1,#-1
        MOV     R2,#-1
        MOV     R3,#0
        MOV     R4,#0
        SWI     XOS_ReadVarVal
        TEQ     R2,#0                  ;if zero, variable DOES NOT exist (EQ status)
        LDMFD   SP!,{R0,R1,R2,R3,R4,PC}
CRUNCHSTR
        =       "BASIC$$Crunch"
        =       0
        ALIGN
 ]
TITLE   STMFD   SP!,{R0-R12,R14}
        SWI     OS_WriteS
REPSTR  =       "ARM BBC BASIC V"
 [ FPOINT=1
        =       "I (FPA)"
 ELIF FPOINT=2
        =       "I (VFP)"
 ]
        =       " (C) Acorn 1989",10,13,0
 [ RELEASEVER=0
        SWI     OS_WriteS
        =       " a ",0
        BL      PATOUT
        =       &3F,&61,&D1,&BF,&B0,&B9,&B6,&E2
        =       &00,&80,&80,&3C,&47,&C6,&CE,&78
        =       &00,&00,&1E,&33,&73,&3F,&03,&06
        =       &00,&1E,&33,&3E,&F8,&0F,&00,&00
        =       &01,&07,&0C,&38,&E0,&80,&00,&00
        =       &C0,&60,&20,&00,&00,&00,&00,&00
        SWI     OS_WriteS
        =       "prog",10,13,0
 ]
        LDR     R1,[ARGP,#HIMEM]
        LDR     R0,[ARGP,#PAGE]
        ADD     R0,R0,#4               ;to agree with value for END (=LOMEM)
        SUB     R1,R1,R0
 [ OWNERRORS=1
        SWI     OS_WriteS
        =       10,13,"Starting with ",0
        MOV     R0,R1
        MOV     R7,#0
        BL      CARDINALPRINT
        SWI     OS_WriteS
        =       " bytes free.",10,13,0
        BL      NLINE
 |
        MOV     R0,#22
        BL      MSGPRNCXX
 ]
        LDMFD   SP!,{R0-R12,PC}
ENTRYKEYW
        BL      RDCOMCH
        CMP     R2,#"H"
        BEQ     ENTRYKEYW2
        CMP     R2,#"L"
        BEQ     ENTRYKEYW3
        CMP     R2,#"Q"
        BEQ     ENTRYKEYW4
        CMP     R2,#"C"
        BL      RDCOMCHER
        CMP     R2,#"H"
        BL      RDCOMCHER
        CMP     R2,#"A"
        BL      RDCOMCHER
        CMP     R2,#"I"
        BL      RDCOMCHER
        CMP     R2,#"N"
        BL      RDCOMCHER
        CMP     R2,#" "
        BNE     ENTRYUNK
ENTRYCHAIN
        BL      TITLE
ENTRYCHAIN1
        CMP     R2,#" "
        LDREQB  R2,[R0],#1
        BEQ     ENTRYCHAIN1
        TEQ     R2,#0
        BEQ     CLRSTK
        TEQ     R2,#"@"
        BEQ     ENTRYCONT
ENTRYF  ADD     R4,ARGP,#STRACC
ENTRF1  STRB    R2,[R4],#1
        LDRB    R2,[R0],#1
        CMP     R2,#" "
        BHI     ENTRF1
        MOV     R5,#13
        STRB    R5,[R4],#1
;OK have set up name in STRACC. Call internals of TEXTLOAD
        BL      LOADFILEFINAL
        B       ENTRYFINAL
ENTRYKEYW4
        BL      RDCOMCH
        CMP     R2,#"U"
        BL      RDCOMCHER
        CMP     R2,#"I"
        BL      RDCOMCHER
        CMP     R2,#"T"
        BL      RDCOMCHER
        CMP     R2,#" "
        BNE     ENTRYUNK
        MOV     R1,#0                  ;set QUIT flag
        STRB    R1,[ARGP,#CALLEDNAME]
        B       ENTRYCHAIN1
ENTRYKEYW3
        BL      RDCOMCH
        CMP     R2,#"O"
        BL      RDCOMCHER
        CMP     R2,#"A"
        BL      RDCOMCHER
        CMP     R2,#"D"
        BL      RDCOMCHER
        CMP     R2,#" "
        BNE     ENTRYUNK
        MOV     R9,#0
        B       ENTRYCHAIN
ENTRYKEYW2
        BL      RDCOMCH
        CMP     R2,#"E"
        BL      RDCOMCHER
        CMP     R2,#"L"
        BL      RDCOMCHER
        CMP     R2,#"P"
        BL      RDCOMCHER
        BL      TITLE
 [ OWNERRORS=1
        SWI     OS_WriteS
        =       "$Name. -help activated (use HELP at the > prompt for more help):",10,13,0
 |
      [ FPOINT=2
        MOV     R0,#27
      |
        MOV     R0,#17+FPOINT
      ]
        BL      MSGPRNXXX
 ]
        B       ENTRYHELP
ENTRYUNK
        BL      TITLE
 [ OWNERRORS=1
        SWI     OS_WriteS
        =       "Unknown keyword.",10,13,10,13,0
        ALIGN
 |
        MOV     R0,#19
        BL      MSGPRNXXX
 ]
ENTRYHELP
 [ OWNERRORS=1
        SWI     OS_WriteS
        =       "$Name. [-chain] <filename> to run a file (text/tokenised).",10,13
        =       "$Name. -quit <filename> to run a file (text/tokenised) and quit when done.",10,13
        =       "$Name. -load <filename> to start with a file (text/tokenised).",10,13
        =       "$Name. @xxxxxxxx,xxxxxxxx to start with in-core text/tokenised program.",10,13
        =       "$Name. -chain @xxxxxxxx,xxxxxxxx to run in-core text/tokenised program.",10,13,0
 |
      [ FPOINT=2
        MOV     R0,#28
      |
        MOV     R0,#20+FPOINT
      ]
        BL      MSGPRNXXX
 ]
        B       FSASET
RDHEX   MOV     R5,#0
        MOV     R4,#32-4
RDHEX1  LDRB    R2,[R0],#1
        CMP     R2,#"0"
        BCC     BADIPHEX
        CMP     R2,#"9"+1
        BCC     RDHEX2
        CMP     R2,#"A"
        BCC     BADIPHEX
        CMP     R2,#"F"+1
        BCS     BADIPHEX
        SUB     R2,R2,#"A"-"9"-1
RDHEX2  AND     R2,R2,#&F
        ORR     R5,R5,R2,LSL R4
        SUBS    R4,R4,#4
        BPL     RDHEX1
        LDRB    R2,[R0],#1
        MOV     PC,R14
RDCOMCHER
        BNE     ENTRYUNK
RDCOMCH LDRB    R2,[R0],#1
        CMP     R2,#"a"
        BICCS   R2,R2,#" "
        MOV     PC,R14
NEW     BL      DONES
        BL      FROMAT
FSASET  BL      SETFSA
        B       CLRSTK
CLRSTKTITLE
        BL      TITLE
CLRSTK  MOV     ARGP,#VARS
        ADD     LINE,ARGP,#STRACC
        LDR     R0,[ARGP,#HIMEM]
        BL      POPLOCALAR
        LDR     SP,[ARGP,#HIMEM]
        MOV     R0,#0
        STMFD   SP!,{R0-R9}            ;to stop pops getting carried away
        STRB    R0,[ARGP,#MEMM]
        MVN     R0,#0
        STRB    R0,[ARGP,#BYTESM]
        STR     SP,[ARGP,#ERRSTK]
        BL      ORDERR
        LDRB    R0,[ARGP,#CALLEDNAME]
        CMP     R0,#0
        SWIEQ   OS_Exit
        BL      FLUSHCACHE
        SWI     OS_WriteI+">"
        BL      INLINE                 ;R1=STRACC
        BL      SETVAR
        BL      MATCH
        ADD     LINE,ARGP,#OUTPUT
        BL      SPTSTN
        BNE     DC
        STR     SMODE,[SP,#-4]!
        MOV     R4,R0
        BL      INSRT
        LDR     SMODE,[SP],#4
        CMP     SMODE,#&1000
        BCC     WARNC
 [ OWNERRORS=1
        SWI     OS_WriteS
        =       "Warning: unmatched ()",10,13,0
        ALIGN
 |
        MOV     R0,#0
        BL      MSGPRNXXX
 ]
WARNC   TST     SMODE,#256
        BEQ     WARNQ
 [ OWNERRORS=1
        SWI     OS_WriteS
        =       "Warning: line number too big",10,13,0
        ALIGN
 |
        MOV     R0,#1
        BL      MSGPRNXXX
 ]
WARNQ   AND     SMODE,SMODE,#255
        TEQ     SMODE,#1
        BNE     FSASET
 [ OWNERRORS=1
        SWI     OS_WriteS
        =       "Warning: unmatched """,10,13,0
        ALIGN
 |
        MOV     R0,#2
        BL      MSGPRNXXX
 ]
        B       FSASET
DC      MOV     R3,#255
        STRB    R3,[R2]                ;limit end of immmediate mode line
        CMP     R10,#TESCCOM
        BNE     DISPAT
        LDRB    R10,[LINE],#1
        CMP     R10,#TTWOCOMMLIMIT
        BCS     ERSYNT
        SUBS    R4,R10,#&8E
        BCC     ERSYNT
        LDR     R4,[PC,R4,LSL #2]
        ADD     PC,PC,R4
AJ2     *       .+4
        &       APPEND-AJ2
        &       AUTO-AJ2
        &       CRUNCH-AJ2
        &       DELETE-AJ2
        &       EDIT-AJ2
        &       HELP-AJ2
        &       LIST-AJ2
        &       LOAD-AJ2
        &       LVAR-AJ2
        &       NEW-AJ2
        &       OLD-AJ2
        &       RENUM-AJ2
        &       SAVE-AJ2
        &       TEXTLOAD-AJ2
        &       TEXTSAVE-AJ2
        &       MISTAK-AJ2             ;was TWIN
        &       MISTAK-AJ2             ;was TWINO
        &       INSTALL-AJ2
DOSTAR  MOV     R0,LINE                ;do oscli
        BL      OSCLIREGS
        MOV     R14,#3                 ;set MEMM with move & r12 flags
        STR     LINE,[ARGP,#R12STORE]  ;save r12
        STRB    R14,[ARGP,#MEMM]
        SWI     OS_CLI
        MOV     R14,#0
        STRB    R14,[ARGP,#MEMM]
        B       REM
GOTLTEND2
        CMP     R10,#TELSE
        BNE     ERSYNT
        BL      STORE
DATA
DEF
REM     LDRB    R10,[LINE],#1
        CMP     R10,#13
        BEQ     CRLINE
        LDRB    R10,[LINE],#1
        CMP     R10,#13
        BNE     REM
        B       CRLINE
GOTLTEND1
        CMP     R10,#13
        BNE     GOTLTEND2
        BL      STORE
        LDRB    R10,[LINE],#3
        CMP     R10,#&FF
        BEQ     CLRSTK                 ;check for program end
        LDR     R4,[ARGP,#ESCWORD]     ;check for exceptional conditions
        CMP     R4,#0
        BEQ     STMT                   ;nothing exceptional
        BL      DOEXCEPTION
        B       STMT
ENDIF
ENDCA
DONXTS  LDRB    R10,[LINE],#1
DONEXT  CMP     R10,#" "
        BEQ     DONXTS
        CMP     R10,#":"
        BEQ     STMT
        CMP     R10,#13
        BEQ     CRLINE
        CMP     R10,#TELSE
        BEQ     REM
        B       ERSYNT
MINUSBC BL      EXPR
        TEQ     TYPE,#0
        BEQ     ERTYPEINT
        RSBPL   IACC,IACC,#0
 [ FPOINT=0
        BPL     PLUSBC
        TEQ     FACC,#0
        EORNE   FSIGN,FSIGN,#&80000000
 ELIF FPOINT=1
        RSFMID  FACC,FACC,#0
 ELIF FPOINT=2
        FNEGD   FACC,FACC
 |
        ! 1, "Unknown FPOINT setting"
 ]
        B       PLUSBC
GOTLT2  CMP     R10,#"-"
        TEQCC   R10,#"+"
        BNE     MISTAK
ATGOTLT2
        LDRB    R10,[AELINE],#1
        TEQ     R10,#"="
        BNE     MISTAK
        BCS     MINUSBC
        BL      EXPR
PLUSBC  BL      AEDONE
        LDMFD   SP!,{R4,R5}
        CMP     R5,#TFPLV
        BEQ     PLUSBCFP
        BCS     PLUSBCSTRING
        BL      INTEGY
        MOV     R7,IACC
        MOV     IACC,R4
        MOV     TYPE,R5
        BL      VARIND
        ADD     IACC,IACC,R7
        BL      STOREANINT
NXT     CMP     R10,#":"
        BEQ     STMT
        CMP     R10,#13
        BNE     REM                    ;if not CR, then ELSE
CRLINE  LDRB    R10,[LINE],#3
        CMP     R10,#&FF
        BEQ     CLRSTK                 ;check for program end
        LDR     R4,[ARGP,#ESCWORD]     ;check for exceptional conditions
        CMP     R4,#0
        BEQ     STMT                   ;nothing exceptional
        BL      DOEXCEPTION
        B       STMT
PLUSBCSTRING
        CMP     R5,#256
        BCS     ARRAYPLUSBC
        TEQ     TYPE,#0
        BNE     ERTYPESTR
        ADD     R0,ARGP,#STRACC
        SUBS    R1,CLEN,R0
        BEQ     NXT                    ;nothing to be added!
        MOV     R7,R1                  ;keep additional length
        MOV     AELINE,R4              ;original address used by SPUSH
        BL      SPUSHLARGE             ;push string to be added
        MOV     IACC,AELINE            ;original address
        CMP     R5,#128                ;check source type
        BL      VARNOTNUM              ;TYPE=0 currently!
        ADD     SP,SP,#4               ;discard length on stack
        ADD     R6,ARGP,#STRACC
        SUB     R6,CLEN,R6
        ADD     R6,R7,R6               ;new length
        CMP     R6,#256
        BCS     ERLONG
PLUSBCLP
        LDRB    R6,[SP],#1
        STRB    R6,[CLEN],#1
        SUBS    R7,R7,#1
        BNE     PLUSBCLP
        ADD     SP,SP,#3
        BIC     SP,SP,#3
        MOV     R4,AELINE
        BL      STSTOR                 ;TYPE still 0
        B       NXT
PLUSBCFP

        BL      FLOATY
 [ FPOINT=0
        MOV     TYPE,R4
        BL      FTOW
        BL      F1LDA
        BL      FADDW
        BL      F1STA
 ELIF FPOINT=1
        LDFD    F1,[R4]
        ADFD    FACC,F1,FACC
        STFD    FACC,[R4]
 ELIF FPOINT=2
        FLDD    D1,[R4]
        FADDD   FACC,D1,FACC
        FPSCRCheck R14
        FSTD    FACC,[R4]
 |
        ! 1, "Unknown FPOINT setting"
 ]
        B       NXT
LETSTNOTCACHE
        MOV     AELINE,LINE
        BL      LVNOTCACHE
        BLEQ    GOTLTCREATE            ;taken if EQ (note tricky DONEXT call)
GOTLT   STMFD   SP!,{IACC,TYPE}
GOTLT1  LDRB    R10,[AELINE],#1
        CMP     R10,#" "
        BEQ     GOTLT1
        CMP     R10,#"="
        BNE     GOTLT2
        CMP     TYPE,#256
        BCC     EXPRSTORESTMT
        B       LETARRAY
LETSTCACHEARRAY
        SUB     AELINE,AELINE,#TFP
        BL      ARLOOKCACHE
        BNE     GOTLT
        B       MISTAK
LETST   AND     R1,LINE,#CACHEMASK
        ADD     R1,ARGP,R1,LSL #CACHESHIFT
        LDMIA   R1,{IACC,R1,R4,TYPE}
        CMP     R4,LINE
        BNE     LETSTNOTCACHE
        CMN     R1,#1
        ADD     AELINE,LINE,R1
        BMI     LETSTCACHEARRAY
        STMFD   SP!,{IACC,TYPE}
LETSTSPACE
        LDRB    R10,[AELINE],#1
        CMP     R10,#" "
        BEQ     LETSTSPACE
        CMP     R10,#"="
        BNE     GOTLT2                 ;cannot possibly be array stuff
EXPRSTORESTMT
        BL      EXPR
        MOV     LINE,AELINE
        CMP     R10,#":"
        BNE     GOTLTEND1
        BL      STORE
STMT    LDRB    R10,[LINE],#1
; CMP R10,#" "
; BEQ STMT
;go to value of token in R10, using r4
DISPAT  LDR     R4,[PC,R10,LSL #2]
        ADD     PC,PC,R4
AJ      *       .+4
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       CRLINE-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       STMT-AJ
        &       LETSTNOTCACHE-AJ
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       LETSTNOTCACHE-AJ       ; 24 '$'
        &       LETST-AJ               ; 25 '%'
        &       LETST-AJ               ; 26 '&'
        &       LETST-AJ               ; 27 '''
        &       LETST-AJ               ; 28 '('
        &       LETST-AJ               ; 29 ')'
        &       DOSTAR-AJ
        &       LETST-AJ               ; 2B '+'
        &       LETST-AJ               ; 2C ','
        &       LETST-AJ               ; 2D '-'
        &       LETST-AJ               ; 2E '.'
        &       LETST-AJ               ; 2F '/'
        &       LETST-AJ               ; 30 '0'
        &       LETST-AJ               ; 31 '1'
        &       LETST-AJ               ; 32 '2'
        &       LETST-AJ               ; 33 '3'
        &       LETST-AJ               ; 34 '4'
        &       LETST-AJ               ; 35 '5'
        &       LETST-AJ               ; 36 '6'
        &       LETST-AJ               ; 37 '7'
        &       LETST-AJ               ; 38 '8'
        &       LETST-AJ               ; 39 '9'
        &       STMT-AJ
        &       LETST-AJ               ; 3B ';'
        &       LETST-AJ               ; 3C '<'
        &       FNRET-AJ
        &       LETST-AJ               ; 3E '>'
        &       LETSTNOTCACHE-AJ       ; 3F '?'
        &       ASSIGNAT-AJ
        &       LETST-AJ               ; 41 'A'
        &       LETST-AJ               ; 42 'B'
        &       LETST-AJ               ; 43 'C'
        &       LETST-AJ               ; 44 'D'
        &       LETST-AJ               ; 45 'E'
        &       LETST-AJ               ; 46 'F'
        &       LETST-AJ               ; 47 'G'
        &       LETST-AJ               ; 48 'H'
        &       LETST-AJ               ; 49 'I'
        &       LETST-AJ               ; 4A 'J'
        &       LETST-AJ               ; 4B 'K'
        &       LETST-AJ               ; 4C 'L'
        &       LETST-AJ               ; 4D 'M'
        &       LETST-AJ               ; 4E 'N'
        &       LETST-AJ               ; 4F 'O'
        &       LETST-AJ               ; 50 'P'
        &       LETST-AJ               ; 51 'Q'
        &       LETST-AJ               ; 52 'R'
        &       LETST-AJ               ; 53 'S'
        &       LETST-AJ               ; 54 'T'
        &       LETST-AJ               ; 55 'U'
        &       LETST-AJ               ; 56 'V'
        &       LETST-AJ               ; 57 'W'
        &       LETST-AJ               ; 58 'X'
        &       LETST-AJ               ; 59 'Y'
        &       LETST-AJ               ; 5A 'Z'
        &       ASS-AJ                 ; 5B '['
        &       LETST-AJ               ; 5C '\\'
        &       LETST-AJ               ; 5D ']'
        &       LETST-AJ               ; 5E '^'
        &       LETST-AJ               ; 5F '_'
        &       LETST-AJ               ; 60 '`'
        &       LETST-AJ               ; 61 'a'
        &       LETST-AJ               ; 62 'b'
        &       LETST-AJ               ; 63 'c'
        &       LETST-AJ               ; 64 'd'
        &       LETST-AJ               ; 65 'e'
        &       LETST-AJ               ; 66 'f'
        &       LETST-AJ               ; 67 'g'
        &       LETST-AJ               ; 68 'h'
        &       LETST-AJ               ; 69 'i'
        &       LETST-AJ               ; 6A 'j'
        &       LETST-AJ               ; 6B 'k'
        &       LETST-AJ               ; 6C 'l'
        &       LETST-AJ               ; 6D 'm'
        &       LETST-AJ               ; 6E 'n'
        &       LETST-AJ               ; 6F 'o'
        &       LETST-AJ               ; 70 'p'
        &       LETST-AJ               ; 71 'q'
        &       LETST-AJ               ; 72 'r'
        &       LETST-AJ               ; 73 's'
        &       LETST-AJ               ; 74 't'
        &       LETST-AJ               ; 75 'u'
        &       LETST-AJ               ; 76 'v'
        &       LETST-AJ               ; 77 'w'
        &       LETST-AJ               ; 78 'x'
        &       LETST-AJ               ; 79 'y'
        &       LETST-AJ               ; 7A 'z'
        &       ERSYNT-AJ
        &       LETSTNOTCACHE-AJ       ; |
        &       ERSYNT-AJ
        &       ERSYNT-AJ
        &       OTHER-AJ
        &       ERSYNT-AJ              ; AND
        &       ERSYNT-AJ              ; DIV
        &       ERSYNT-AJ              ; EOR
        &       ERSYNT-AJ              ; MOD
        &       ERSYNT-AJ              ; OR
        &       LERROR-AJ
        &       LINEST-AJ
        &       CURSOFF-AJ
        &       ERSYNT-AJ              ; STEP
        &       ERSYNT-AJ              ; SPC
        &       ERSYNT-AJ              ; TAB
        &       REM-AJ                 ; ELSE
        &       ERSYNT-AJ              ; THEN
        &       ERSYNT-AJ              ; 8D
        &       ERSYNT-AJ              ; OPENU

        &       LPTR-AJ
        &       LPAGE-AJ
        &       LTIME-AJ
        &       LLOMEM-AJ
        &       LHIMEM-AJ

        &       ERSYNT-AJ              ; ABS
        &       ERSYNT-AJ              ; ACS
        &       ERSYNT-AJ              ; ADC
        &       ERSYNT-AJ              ; ASC
        &       ERSYNT-AJ              ; ASN
        &       ERSYNT-AJ              ; ATN
        &       ERSYNT-AJ              ; BBGET
        &       ERSYNT-AJ              ; COS
        &       ERSYNT-AJ              ; COUNT
        &       ERSYNT-AJ              ; DEG
        &       ERSYNT-AJ              ; ERL
        &       ERSYNT-AJ              ; ERR
        &       ERSYNT-AJ              ; EVAL
        &       ERSYNT-AJ              ; EXP
        &       LEXT-AJ                ; EXT
        &       ERSYNT-AJ              ; FALSE
        &       ERSYNT-AJ              ; FN
        &       ERSYNT-AJ              ; GET
        &       ERSYNT-AJ              ; INKEY
        &       ERSYNT-AJ              ; INSTR
        &       ERSYNT-AJ              ; INT
        &       ERSYNT-AJ              ; LEN
        &       ERSYNT-AJ              ; LN
        &       ERSYNT-AJ              ; LOG
        &       ERSYNT-AJ              ; NOT
        &       ERSYNT-AJ              ; OPENI
        &       ERSYNT-AJ              ; OPENO
        &       ERSYNT-AJ              ; PI
        &       ERSYNT-AJ              ; POINT
        &       ERSYNT-AJ              ; POS
        &       ERSYNT-AJ              ; RAD
        &       ERSYNT-AJ              ; RND
        &       ERSYNT-AJ              ; SGN
        &       ERSYNT-AJ              ; SIN
        &       ERSYNT-AJ              ; SQR
        &       ERSYNT-AJ              ; TAN
        &       ERSYNT-AJ              ; TO
        &       ERSYNT-AJ              ; TRUE
        &       ERSYNT-AJ              ; USR
        &       ERSYNT-AJ              ; VAL
        &       ERSYNT-AJ              ; VPOS
        &       ERSYNT-AJ              ; CHRD
        &       ERSYNT-AJ              ; GETD
        &       ERSYNT-AJ              ; INKED
        &       LLEFTD-AJ
        &       LMIDD-AJ
        &       LRIGHTD-AJ
        &       ERSYNT-AJ              ; STRD
        &       ERSYNT-AJ              ; STRND
        &       ERSYNT-AJ              ; EOF

        &       ERSYNT-AJ              ;functions disallowed
        &       ERSYNT-AJ              ;commands disallowed
        &       TWOSTMT-AJ             ;two byte statements

        &       WHEN-AJ
        &       ERSYNT-AJ              ;OF
        &       ENDCA-AJ
        &       ELSE2-AJ
        &       ENDIF-AJ
        &       ENDWH-AJ
        &       LPTR-AJ
        &       LPAGE-AJ
        &       LTIME-AJ
        &       LLOMEM-AJ
        &       LHIMEM-AJ
        &       SOUND-AJ
        &       BBPUT-AJ
        &       CALL-AJ
        &       CHAIN-AJ
        &       CLEAR-AJ
        &       CLOSE-AJ
        &       CLG-AJ
        &       CLS-AJ
        &       DATA-AJ
        &       DEF-AJ
        &       DIM-AJ
        &       DRAW-AJ
        &       END-AJ
        &       ENDPR-AJ
        &       ENVEL-AJ
        &       FOR-AJ
        &       GOSUB-AJ
        &       GOTO-AJ
        &       GCOL-AJ
        &       IF-AJ
        &       INPUT-AJ
        &       LET-AJ
        &       LOCAL-AJ
        &       MODES-AJ
        &       MOVE-AJ
        &       NEXT-AJ
        &       ON-AJ
        &       VDU-AJ
        &       PLOT-AJ
        &       PRINT-AJ
        &       PROC-AJ
        &       READ-AJ
        &       REM-AJ
        &       REPEAT-AJ
        &       REPORT-AJ
        &       RESTORE-AJ
        &       RETURN-AJ
        &       RUN-AJ
        &       STOP-AJ
        &       COLOUR-AJ
        &       TRACE-AJ
        &       UNTIL-AJ
        &       WIDTH-AJ
        &       OSCL-AJ
TWOSTMT LDRB    R10,[LINE],#1
        CMP     R10,#TTWOSTMTLIMIT
        BCS     ERSYNT
        SUBS    R4,R10,#&8E
        BCC     ERSYNT
        LDR     R4,[PC,R4,LSL #2]
        ADD     PC,PC,R4
AJ3     *       .+4
        &       CASE-AJ3
        &       CIRCLE-AJ3
        &       FILL-AJ3
        &       ORGIN-AJ3
        &       PSET-AJ3
        &       RECT-AJ3
        &       SWAP-AJ3
        &       WHILE-AJ3
        &       WAIT-AJ3
        &       DOMOUSE-AJ3
        &       QUIT-AJ3
        &       SYS-AJ3
        &       INSTALLBAD-AJ3
        &       LIBRARY-AJ3
        &       DOTINT-AJ3
        &       ELLIPSE-AJ3
        &       BEATS-AJ3
        &       TEMPO-AJ3
        &       VOICES-AJ3
        &       VOICE-AJ3
        &       STEREO-AJ3
        &       OVERLAY-AJ3

;clear text
FROMAT  MOV     R0,#13
        LDR     R1,[ARGP,#PAGE]
        STRB    R0,[R1],#1
        MOV     R0,#&FF
        STRB    R0,[R1],#1             ;post index to get value for TOP
        STR     R1,[ARGP,#TOP]
        MOV     R0,#0
        STR     R0,[ARGP,#TRCNUM]
        MOV     PC,R14
SETFSA  LDR     R0,[ARGP,#TOP]
        ADD     R0,R0,#3
        BIC     R0,R0,#3
        STR     R0,[ARGP,#LOMEM]
        STR     R0,[ARGP,#FSA]
        MOV     R6,#0
        ADD     R1,ARGP,#FREELIST
        ADD     R2,R1,#256
SETFREEL
        STR     R6,[R1],#4
        CMP     R1,R2
        BCC     SETFREEL
        MOV     R6,R14                 ;save return address
        BL      SETVAR
        MOV     R14,R6
SETVAL  ADD     R1,ARGP,#PROCPTR
        ADD     R2,R1,#(FNPTR+4-PROCPTR)
        MOV     R0,#0
        STR     R0,[ARGP,#LIBRARYLIST]
        STR     R0,[ARGP,#OVERPTR]
SETVRL  STR     R0,[R1],#4
        TEQ     R1,R2
        BNE     SETVRL
        ADD     R1,ARGP,#VCACHE
        ADD     R2,R1,#CACHESIZE*16
SETCACHE0
        STR     R0,[R1],#4
        TEQ     R1,R2
        BNE     SETCACHE0
        MOV     PC,R14
SETVAR  LDR     R0,[ARGP,#PAGE]
        STR     R0,[ARGP,#DATAP]
        MOV     PC,R14
FLUSHCACHE
        ADD     R1,ARGP,#VCACHE+CACHECHECK
        MOV     R0,#0
        ADD     R2,R1,#CACHESIZE*16
FLUSHCACHE1
        STR     R0,[R1],#16
        TEQ     R1,R2
        BNE     FLUSHCACHE1
        MOV     PC,R14
;empty any cache entry which lies in the range R4 to AELINE
;Uses R5, R6, R7 and R10
;Must preserve PSR flags
PURGECACHE
        STR     R14,[SP,#-4]!
        SavePSR R14
        MOV     R5,#0
        SUB     R10,AELINE,R4
        CMP     R10,#256
        BCS     PURGECACHEB1
;algorithm 1: kill entries that might be matched
 [ (CACHEMASK :AND: 1) = 1
;bottom bit valid
        MOV     R6,R4
PURGECACHEA1
        AND     R7,R6,#CACHEMASK
        ADD     R7,ARGP,R7,LSL #CACHESHIFT
        LDR     R10,[R7,#CACHECHECK]
        CMP     R10,R6
        STREQ   R5,[R7,#CACHECHECK]
        ADD     R6,R6,#1
        CMP     R6,AELINE
        BLE     PURGECACHEA1
 |
        BIC     R6,R4,#1
PURGECACHEA1
        AND     R7,R6,#CACHEMASK
        ADD     R7,ARGP,R7,LSL #CACHESHIFT
        LDR     R10,[R7,#CACHECHECK]
        CMP     R10,R6
        ADD     R6,R6,#1
        CMPNE   R10,R6
        STREQ   R5,[R7,#CACHECHECK]
        ADD     R6,R6,#1
        CMP     R6,AELINE
        BLE     PURGECACHEA1
 ]
        RestPSR R14,,f
        LDR     PC,[SP],#4
;algorithm 2: go through whole cache killing entries in range
PURGECACHEB1
        ADD     R6,ARGP,#VCACHE+CACHECHECK
        ADD     R7,R6,#CACHESIZE*16
PURGECACHEB2
        LDR     R10,[R6],#16
        CMP     R10,R4
        CMPCS   AELINE,R10
        STRCS   R5,[R6,#-16]
        CMP     R6,R7
        BNE     PURGECACHEB2
        RestPSR R14,,f
        LDR     PC,[SP],#4
;create error message (R14->entry in ErrorMsgs,LINE->address of statement in error)
MSG     SUB     R3,R14,PC              ;remove mode and flags
        ADD     R3,PC,R3
        SUB     R3,R3,#4               ;byte error
        ADD     R9,ARGP,#STRACC
        LDRB    R2,[R3],#1             ;move error number
        STR     R2,[R9]
        LDRB    R0,[R3],#1             ;unique error number
 [ OWNERRORS=1
        ADD     R14,R9,#4              ;copy my error message
MSGBYTE LDRB    R2,[R3],#1
        STRB    R2,[R14],#1
        CMP     R2,#0
        BNE     MSGBYTE
 |
        SUB     SP,SP,#8
        ADD     R1,SP,#1               ;gap for 'E'
        MOV     R2,#7
        SWI     XOS_ConvertCardinal1
        MOV     R14,#"E"
        STRB    R14,[R0,#-1]!
        ADD     R1,R9,#4
        MOV     R3,#252
        BL      MSGXLATE               ;lookup the foreign one
        ADD     SP,SP,#8
 ]
;make internal errors visible to Service_Error watchers
        STMFD   SP!,{R4-R5,R9}
        BL      OSCLIREGS              ;show some leg
        LDR     R1,=ErrorBase_BASIC
        LDRB    R14,[R9]
        ORR     R1,R1,R14
        STR     R1,[R9]                ;make errnum system unique
        MOV     R0,R9
        MOV     R1,#Service_Error
        SWI     XOS_ServiceCall
        STR     R14,[R9]               ;put back our errnum
        LDMFD   SP!,{R4-R5,R14}
MSGERR  MOV     ARGP,#VARS             ;cardinal error from outside world
        MOV     R7,R14                 ;keep error pointer
        MOV     R14,#0
        STRB    R14,[ARGP,#MEMM]       ;clear MEMM (and r12) flags
        BL      FLUSHCACHE
      [ FPOINT=2
        ; Reset FP context
        ADD     R0,ARGP,#VFPCONTEXT
        MOV     R1,#0
        SWI     XVFPSupport_ChangeContext
        FMXR    FPSCR,R1
      ]
        MOV     R0,#&DA
        MOV     R1,#0
        MOV     R2,#0
        SWI     OS_Byte
        MOV     R0,#&7E
        SWI     OS_Byte
        MOV     R0,#0
;try to figure out where the error happened
        CMP     LINE,#AppSpaceStart    ;must be in application space
        MVNLO   R0,#0                  ;otherwise ERL:=-1
        BLO     MSG1
        SUB     LINE,LINE,#2           ;seems a good idea
        LDR     R1,[ARGP,#PAGE]        ;OK: find good base to start search
        LDR     R2,[ARGP,#LIBRARYLIST]
        BL      MSGSEARCHLIST          ;check list of LIBRARYs. May inc r1
        LDR     R2,[ARGP,#INSTALLLIST]
        BL      MSGSEARCHLIST          ;check list of INSTALLs. May inc r1
        LDR     R2,[ARGP,#OVERPTR]
        TEQ     R2,#0                  ;check list of OVERLAYs. May inc r1
        BEQ     MSG0START
        ADD     R3,R2,#12
        CMP     R3,LINE                ;test if prog start < error pos: true=CC
        CMPCC   R1,R3                  ;test if prog start > previous prog start: true=CC
        MOVCC   R1,R3                  ;keep r3 if prog start < error pos and prog start > previous start
;r1 = highest program section start (of ALL sections) below LINE ptr
;Now search from that pointer to end of that program section...
MSG0START
        MOV     AELINE,R1              ;keep pointer to start of program section
MSG0    CMP     R1,LINE                ;is this line > error line?
        BHI     MSG1                   ;yes, so go use last ERL
        LDRB    R2,[R1,#1]
        CMP     R2,#&FF                ;at end of program?
        MVNEQ   R0,#1                  ;yes, so ERL:=-2
        BEQ     MSG1
        LDRB    R0,[R1,#2]
        ADD     R0,R0,R2,LSL #8        ;r0 = line number
        LDRB    R2,[R1,#3]             ;line length
        ADD     R1,R1,R2               ;move ptr to next line
        B       MSG0
MSG1    STR     R0,[ARGP,#ERRLIN]      ;store ERL
        ADD     R1,ARGP,#ERRORS
        ADD     R4,R1,#255             ;end of error buffer
        ADR     LINE,ERRHAN            ; -> default error handler
        LDR     R0,[R7],#4
        STR     R0,[ARGP,#ERRNUM]      ;store ERR
        CMP     R0,#0                  ;is ERR = 0 ?
        LDRNE   LINE,[ARGP,#ERRORH]    ;no,  so use last error handler
        STREQ   LINE,[ARGP,#ERRORH]    ;yes, save default error handler
MSGA    LDRB    R0,[R7],#1             ;copy error message ...
        TEQ     R0,#0
        STRNEB  R0,[R1],#1             ;... to error buffer
        BNE     MSGA                   ;save error message
        LDR     R2,[ARGP,#PAGE]
        CMP     R2,AELINE
        BEQ     MSGLIBRARYDONE         ;not in a strange bit
;look for REM [>] <name> in first line of LIBRARY, INSTALL or OVERLAY
        ADD     AELINE,AELINE,#4
        BL      AESPAC
        CMP     R10,#TREM
        BNE     MSGLIBRARYDONE         ;no REM statement found
        BL      AESPAC
        CMP     R10,#">"
        BLEQ    AESPAC
        CMP     R10,#13
        BEQ     MSGLIBRARYDONE         ;empty
        BL      MSGADDONENDSPC
        MOV     R3,#"i"                ;add 'in "library name"' to error
        BL      MSGADDONEND
        MOV     R3,#"n"
        BL      MSGADDONEND
        BL      MSGADDONENDSPC
        MOV     R3,#""""
        BL      MSGADDONEND
        MOV     R3,R10
MSGLIBRARYNAME
        BL      MSGADDONEND            ;copy name of Library
        LDRB    R3,[AELINE],#1
        CMP     R3,#" "
        BCS     MSGLIBRARYNAME         ;HI if " " is end of insert
        MOV     R3,#""""
        BL      MSGADDONEND
MSGLIBRARYDONE
        STRB    R0,[R1]                ;write in last 0
; BL SETVAR                                       ;****CHANGE
        LDR     R0,[ARGP,#ERRSTK]
        LDR     R1,[ARGP,#MEMLIMIT]
        CMP     R0,R1                  ;is error stack ptr in basic mem?
        BHS     MSGSPE                 ;no, so no hope - give error
        CMP     R0,SP                  ;is error stack ptr > current sp?
        LDRLO   SP,[ARGP,#ERRSTK]      ;no, reset to last error handler
        B       MSGSP1                 ;and try to continue...
MSGSPE                                 ;raise nasty error and end
 [ OWNERRORS=1
        SWI     OS_WriteS
        =       "Attempt to use badly nested error handler (or corrupt R13).",10,13,0
        ALIGN
 |
        MOV     R0,#3
        BL      MSGPRNXXX
 ]
MSGSP2  LDR     R1,[ARGP,#HIMEM]
        SUB     R1,R1,#10*4
        STR     R1,[ARGP,#ERRSTK]
        ADR     LINE,ERRHAN
        STR     LINE,[ARGP,#ERRORH]
MSGSP1  BL      POPLOCALAR             ;clean up removed local string arrays
        LDR     SP,[ARGP,#ERRSTK]
        B       STMT                   ;continue from LINE
MSGXLATE
        STMFD   SP!,{R0-R3,R14}
        SUB     SP,SP,#4*4             ;a MessageTrans structure
        MOV     R2,#0
        STRB    R2,[R1]                ;null result by default
        ADRL    R1,Basic_MessageFile
        MOV     R0,SP
        SWI     XMessageTrans_OpenFile
        BVS     MSGXLDONE
        LDR     R1,[SP,#(4*4)+0]       ;entry R0
        LDR     R2,[SP,#(4*4)+4]       ;entry R1
        SWI     XMessageTrans_Lookup
        MOVVS   R0,SP
        SWI     XMessageTrans_CloseFile
MSGXLDONE
        ADD     SP,SP,#4*4
        LDMFD   SP!,{R0-R3,PC}
MSGADDONENDSPC
        MOV     R3,#" "
MSGADDONEND
        CMP     R1,R4
        STRCCB  R3,[R1],#1
        MOV     PC,R14
MSGSEARCHLIST                          ;check entries in LIBRARY, INSTALL or OVERLAY lists
;exit r1 = highest program section start below LINE ptr ** SO FAR **
        TEQ     R2,#0                  ;end of list
        MOVEQ   PC,R14
        ADD     R3,R2,#4               ;start of prog
        LDR     R2,[R2]                ;next link
        CMP     R3,LINE                ;test if prog start < error pos: true=CC
        CMPCC   R1,R3                  ;test if prog start > previous prog start: true=CC
        MOVCC   R1,R3                  ;keep r3 if prog start < error pos and prog start > previous start
        B       MSGSEARCHLIST
INLINE  ADD     R0,ARGP,#STRACC
        MOV     R1,#238
        MOV     R2,#" "
        MOV     R3,#255
        SWI     OS_ReadLine
        BCS     ESCAPE
        ADD     R1,ARGP,#STRACC
        B       CTALLY
NLINE   SWI     OS_NewLine
CTALLY  MOV     R2,#0
        STR     R2,[ARGP,#TALLY]
        MOV     PC,R14

ORDERR  ADR     R0,ERRHAN              ;reset error handler to use default
        STR     R0,[ARGP,#ERRORH]
        MOV     PC,R14
ERRHAN  ; TRACE OFF:
        ; IF QUIT ERROR EXT ERR,REPORT$ ELSE RESTORE:IF ERL CALL!ERRXLATE:PRINT$STRACC ELSE REPORT:PRINT
        ; END
        =       TTRACE,TOFF,":"
        =       TIF,TESCSTMT,TQUIT,TERROR,TEXT,TERR,",",TREPORT,"$"
        =       TELSE,TRESTORE,":",TIF,TERL,TCALL,"!&",:STR:(VARS+ERRXLATE):RIGHT:4,":"
        =       TPRINT,"$&",:STR:(VARS+STRACC):RIGHT:4,TELSE,TREPORT,":",TPRINT,13,0,0,0
        =       TEND,13
        ALIGN
;remove from line number in r4 to line number in r5
REMOVE  MOV     R0,R4
        STR     R14,[SP,#-4]!
        BL      FNDLNO
        MOV     R6,R1
        ADD     R0,R5,#1               ;next line plus one
        BL      FNDLNONEXT             ;continue from where we are now
        CMP     R1,R6
        LDRLS   PC,[SP],#4               ;very easy
        LDR     R0,[ARGP,#TOP]
REMOVL  LDRB    R2,[R1],#1             ;pick up a byte from high up
        STRB    R2,[R6],#1             ;put it low down
        CMP     R1,R0
        BNE     REMOVL
        STR     R6,[ARGP,#TOP]
        LDR     PC,[SP],#4
INSERT  STR     R14,[SP,#-4]!              ;insert at end of text
        LDR     R1,[ARGP,#TOP]
        SUB     R1,R1,#2               ;address of cr
        B       INSRTS
;insert the line whose number is in R4, whose first char is ptd to by LINE
INSRT   STR     R14,[SP,#-4]!
        MOV     R5,R4
        BL      REMOVE
        LDRB    R0,[LINE]
        CMP     R0,#13
        LDREQ   PC,[SP],#4
        MOV     R0,R4
        BL      FNDLNO                 ;get position to R1
        LDRB    R0,[ARGP,#LISTOP]
        TEQ     R0,#0
        BEQ     INSRTS
        BL      SPACES
        SUB     LINE,LINE,#1
INSRTS  MOV     AELINE,LINE
LENGTH  LDRB    R0,[AELINE],#1
        CMP     R0,#13
        BNE     LENGTH
        SUB     AELINE,AELINE,#1
TRALSP  LDRB    R0,[AELINE,#-1]!
        CMP     AELINE,LINE
        BLS     TRALEX
        CMP     R0,#" "
        BEQ     TRALSP
TRALEX  MOV     R0,#13
        STRB    R0,[AELINE,#1]!
        SUB     R6,AELINE,LINE         ;raw length 0..n
        ADD     R6,R6,#4               ;length as desired
        CMP     R6,#256
        BCS     ERLINELONG
        LDR     R2,[ARGP,#TOP]
        ADD     R3,R2,R6               ;calc new TOP
        STR     R3,[ARGP,#TOP]
MOVEUP  LDRB    R0,[R2,#-1]!
        STRB    R0,[R3,#-1]!
        TEQ     R2,R1
        BNE     MOVEUP
        STRB    R4,[R1,#2]
        MOV     R5,R4,LSR #8
        STRB    R5,[R1,#1]             ;lo and hi bytes of line number
        STRB    R6,[R1,#3]!            ;length
INSLP1  LDRB    R0,[LINE],#1
        STRB    R0,[R1,#1]!
        CMP     R0,#" "
        BEQ     INSLP1
        TEQ     R0,#13
        LDREQ   PC,[SP],#4
        TEQ     R0,#TELSE
        MOVEQ   R0,#TELSE2
        STREQB  R0,[R1]
INSLP2  LDRB    R0,[LINE],#1
        STRB    R0,[R1,#1]!
        TEQ     R0,#13
        BNE     INSLP2
        LDR     PC,[SP],#4
 [ RELEASEVER=0
PATOUT  SUB     R2,R14,PC
        ADD     R2,PC,R2
        SUB     R2,R2,#4
        BL      PATA
        BL      PATA
        BL      PATA
        BL      PATA
        BL      PATA
        BL      PATA
        SWI     OS_WriteI+23
        SWI     OS_WriteI+" "
        MOV     R1,#8
        BL      ZEROX                  ;8 zeroes
        MOV     PC,R2
PATA    LDR     R0,[R2],#4
        SWI     OS_WriteI+23
        SWI     OS_WriteI+" "
        SWI     OS_WriteC
        MOV     R0,R0,ROR #8
        SWI     OS_WriteC
        MOV     R0,R0,ROR #8
        SWI     OS_WriteC
        MOV     R0,R0,ROR #8
        SWI     OS_WriteC
        LDR     R0,[R2],#4
        SWI     OS_WriteC
        MOV     R0,R0,ROR #8
        SWI     OS_WriteC
        MOV     R0,R0,ROR #8
        SWI     OS_WriteC
        MOV     R0,R0,ROR #8
        SWI     OS_WriteC
        SWI     OS_WriteI+" "
        MOV     PC,R14
 ]

        LNK     fp.s
