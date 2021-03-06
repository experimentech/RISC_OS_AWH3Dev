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
        TTL     > Debugger.s.Debugger - ARM/RISC OS debugger (principally for machine code)

; Authors:      Roger Wilson (Brazil version)
;               Andrew F. Powis (Arthur version)
;               Stuart K. Swales (Arthur fixes/enhancements)
;               Tim Dobson (Adjusting headers, ARM600 variant)
;               Alan Glover (fixes/enhancements, ARM6/ARM7 instructions)
;               William Turner (StrongARM compatibility)
;               Kevin Bracey (ARMv4+5, Thumb, fixes/enhancements, 32-bit)
;               Steve Revill (Slight changes to ADR and SWI disassembly)
;               Ben Avison (halfword, doubleword and unaligned word support)

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:PublicWS
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:EnvNumbers
        GET     Hdr:Proc
        GET     Hdr:VduExt
        GET     Hdr:Tokens
        GET     Hdr:MsgTrans
        GET     Hdr:FPEmulator
        GET     Hdr:ResourceFS
        GET     Hdr:OsBytes
        GET     Hdr:CPU.FPA
        GET     Hdr:CPU.Arch
        GET     Hdr:OSRSI6
        GET     Hdr:VFPSupport
        GET     Hdr:HighFSI
        GET     Hdr:FileTypes
        GET     Hdr:OSMisc
        GET     Hdr:HALEntries

        GET     Hdr:Debugger
        GET     hdr.ExcDump

        GET     VersionASM

        GET     Hdr:Debug

                GBLL    debug
debug           SETL    {FALSE}

                GBLL    StrongARM
StrongARM       SETL    {TRUE}

                GBLL    WarnSArev2
WarnSArev2      SETL    {FALSE}         ; Warn about hitting the SA revision 2 STM^ bug

                GBLL    WarnARMv5
WarnARMv5       SETL    {TRUE}          ; Indicate ARMv5 or later instructions

                GBLL    WarnARMv5E
WarnARMv5E      SETL    {TRUE}          ; Indicate ARMv5E or later instructions

                GBLL    WarnXScaleDSP
WarnXScaleDSP   SETL    {TRUE}          ; Indicate XScale DSP instructions

                GBLL    WarnARMv6
WarnARMv6       SETL    {TRUE}          ; Indicate ARMv6 or later instructions

                GBLL    WarnARMv6K
WarnARMv6K      SETL    {TRUE}          ; Indicate ARMv6K or later instructions

                GBLL    WarnARMv6T2
WarnARMv6T2     SETL    {TRUE}          ; Indicate ARMv6T2 or later instructions

                GBLL    WarnARMv7
WarnARMv7       SETL    {TRUE}          ; Indicate ARMv7 or later instructions

                GBLL    WarnARMv7VE
WarnARMv7VE     SETL    {TRUE}          ; Indicate ARMv7VE or later instructions

                GBLL    WarnARMv7MP
WarnARMv7MP     SETL    {TRUE}          ; Indicate ARMv7MP or later instructions

                GBLL    WarnARMv8
WarnARMv8       SETL    {TRUE}          ; Indicate ARMv8 or later instructions

                GBLL    Thumbv6
Thumbv6         SETL    {FALSE}         ; Thumb v6 (incomplete)

                GBLL    CirrusDSP
CirrusDSP       SETL    {FALSE}         ; Cirrus' Maverick Crunch (incomplete)

                GBLL    Piccolo
Piccolo         SETL    {FALSE}         ; ARM's 16 bit DSP (incomplete)

                GBLL    XScaleDSP
XScaleDSP       SETL    {TRUE}          ; XScale multimedia extensions

                GBLL    UseCVFPNEON
UseCVFPNEON     SETL    {TRUE}          ; Use the C VFP/NEON disassembler

 [ :LNOT: :DEF: international_help
                GBLL    international_help
international_help SETL {TRUE}          ; Default to RISC OS 3.60+ internationalisation
 ]

 [ :LNOT: :DEF: standalone
                GBLL    standalone
standalone      SETL    {FALSE}
 ]


; Continue not up to much

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Debug global workspace

                ^       0, wp

; Breakpoint code section - keep layout same as RelocatedCode section

nbreakpoints    *       16

BreakCodeStart  #       nbreakpoints*8  ; Breakpoint entry code segments
                #       4*6             ; Save other registers before JMP
BreakCodeEnd    #       0               ; End of copied area

; Areas accessed pc relative by relocated breakpoint code

TrapStore       #       4               ; Store for breakpoint id
Registers       #       4*17            ; Register dump area
pc_register     *       Registers + 4*15 ; dumped pc
psr_register    *       Registers + 4*16 ; dumped psr
r12Store        #       4               ; r12 for breakpoint code
JumpStore       #       4               ; address of breakpoint code in ROM

Breaklist       #       nbreakpoints*8  ; List of addresses, old data

OldExceptionDumpArea #  4               ; Old exception register dump area

WindowWidth     #       4
BytesPerLine    #       4

Mistake         #       4               ;potential error number

OldAddress      #       4               ;address of last instruction
OldThumbAddress #       4               ;address of last Thumb instruction
OldThumbInst    #       4               ; last Thumb instruction disassembled
PhysAddrWrd     #       4

MessageFile_Block #     16              ; File handle for MessageTrans
MessageFile_Open  #     4               ; Opened message file flag

SysIs32bit      #       1               ; non-zero if on a 32-bit system
                #       3

ptr_DebuggerSpace #     4
MOVPCInstr      #       4

; SAR
DisOpts         #       4               ; Disassembler options
DisOpt_APCS     *       2_1             ; Use APCS register names (when set)
DisOpt_v6       *       2_10            ; Use 'v6' rather than 'sb'
DisOpt_v7       *       2_100           ; Use 'v7' rather than 'sl'
DisOpt_v8       *       2_1000          ; Use 'v8' rather than 'fp'
DisOpt_sp       *       2_10000         ; Use 'SP' rather than 'R13'
DisOpt_lr       *       2_100000        ; Use 'LR' rather than 'R14'
DisRegLabels    *       @               ; Pointers to register name strings
DisReg_R0       #       4
DisReg_R1       #       4
DisReg_R2       #       4
DisReg_R3       #       4
DisReg_R4       #       4
DisReg_R5       #       4
DisReg_R6       #       4
DisReg_R7       #       4
DisReg_R8       #       4
DisReg_R9       #       4
DisReg_R10      #       4
DisReg_R11      #       4
DisReg_R12      #       4
DisReg_R13      #       4
DisReg_R14      #       4
DisReg_R15      #       4
DisReg_F        #       1               ; Prefix char for FP registers
DisReg_C        #       1               ; Prefix char for Co-pro registers
                #       1
                #       1

 [ UseCVFPNEON
CRelocOffset    #       4               ; Relocation offset used by C code
 ]

DumpBuffer      #       4
DumpBufferLen   #       4
ExceptionBusy   #       4               ; Tracks state of exception dump code to avoid re-entry:
                                        ; 0 -> idle
                                        ; 1 -> stage 1 busy
                                        ; 2 -> stage 2 busy
ROMDebugSymbols #       4
ROMBaseAddr     #       4
DumpOptions     #       4
DumpOption_HAL_Raw        * 1
DumpOption_HAL_Annotated  * 2
DumpOption_File_Raw       * 4
DumpOption_File_Annotated * 8
DumpOption_Collect        * 16          ; Collect but don't report
DumpOptions_Default       * 0           ; Default options to use on module init
DumpOptionsStr  #       44              ; Big enough for longest string

StringBuffer    #       160             ; Temp string buffer. Big enough to
                                        ; hold a disassembled instruction
                                        ; and a full register set + three instrs
 ASSERT (?StringBuffer :AND: 2_11)=0
TotalSpace      *       :INDEX: @

; List of mistakes

                ^       1
Mistake_PlingHat #      1
Mistake_Banked  #       1
Mistake_SWICDP  #       1
Mistake_MUL     #       1
Mistake_R15shift #      1
Mistake_R15     #       1
Mistake_PCwriteback #   1
Mistake_BytePC  #       1
Mistake_StorePC #       1
Mistake_Unpred  #       1
Mistake_RdRn    #       1
Mistake_RmRn    #       1
Mistake_RdLoRdHi #      1
Mistake_RdLoRm  #       1
Mistake_RdHiRm  #       1
Mistake_Rninlist #      1
Mistake_RdRm    #       1
Mistake_STMHat  #       1
Mistake_ARMv5   #       1
Mistake_ARMv5E  #       1
Mistake_ARMv6   #       1
Mistake_ARMv6K  #       1
Mistake_ARMv6T2 #       1
Mistake_ARMv7   #       1
Mistake_ARMv7VE #       1
Mistake_ARMv7MP #       1
Mistake_BaseOdd #       1
Mistake_XScaleDSP #     1
Mistake_ARMv8   #       1

                ^       -1
Potential_SWICDP #      -1
Potential_Banked #      -1
Potential_Banked_Next # -1
Potential_SWICDP_Next # -1

; Overlaid workspace

ExeBufLen       *       4+4+4+?Registers

                ^       :INDEX: StringBuffer, wp
CoreBuffer      #       16              ; Enough for a line of bytes
 ASSERT ?StringBuffer >= ?CoreBuffer

                ^       :INDEX: StringBuffer, wp
ExecuteBuffer   #       ExeBufLen
 ASSERT ?StringBuffer >= ?ExecuteBuffer

; Internal flags
Command_64bitData *     1 :SHL: 0

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Useful constants

TAB             *       9
LF              *       10
CR              *       13
space           *       " "
quote           *       """"
colon           *       ":"
delete          *       &7F
ampersand       *       "&"

; Useful macros

; AddChar - Add a character (possibly conditionally) to the disassembly
;           eg  AddChar "B",NE
        MACRO
        AddChar   $c,$cond
        MOV$cond  R10,#"$c"
        STR$cond.B R10,[R0],#1
        MEND

; AddStr - Add a string (possibly conditionally) to the disassembly,
;          optionally adding the ARM condition field - eg
;              AddStr BX_string,,conds
        MACRO
        AddStr  $c,$cond,$conds,$two
        ADR$cond R10,$c
        [ "$conds" <> ""
          BL$cond  SaveStringConditions$two
        |
          BL$cond  SaveString
        ]
        MEND

; TestBit - check to see if a bit is set, and add one of two characters
;           depending on that bit. Needn't add a character in both
;           or indeed either case; exits with Z bit set appropriately.
;              eg    TestBit 24,"L"
        MACRO
        TestBit $bit,$set,$unset
        TSTS    R4,#1:SHL:$bit
        [ "$set" <> "" :LAND: "$unset" <> ""
        MOVEQ   R10,#"$unset"
        MOVNE   R10,#"$set"
        STRB    R10,[R0],#1
        |
          [ "$set" <> ""
          AddChar "$set",NE
          ]
          [ "$unset" <> ""
          AddChar "$unset",EQ
          ]
        ]
        MEND

; TestStr - check to see if a bit is set, and add one of two strings
;           depending on that bit. Needn't add a string in both
;           cases. Optionally add the ARM condition field. eg
;                  TestStr 20,Ldr,Str,conds
        MACRO
        TestStr $bit,$set,$unset,$conds,$two
        TSTS    R4,#1:SHL:$bit
        [ "$set" <> "" :LAND: "$unset" <> ""
        ADREQ   R10,$unset
        ADRNE   R10,$set
          [ "$conds" <> ""
          BL    SaveStringConditions$two
          |
          BL    SaveString
          ]
        |
          [ "$set" <> ""
          AddStr   $set,NE,$conds
          ]
          [ "$unset" <> ""
          AddStr   $unset,EQ,$conds
          ]
        ]
        MEND

ARM_Addr_Mask * &FC000000 ; local mask to avoid knocking off byte offsets

        AREA    |!|, CODE, READONLY, PIC

        ENTRY

Module_BaseAddr

        DCD     0
        DCD     Debug_Init - Module_BaseAddr
        DCD     Debug_Die - Module_BaseAddr
        DCD     Debug_Service - Module_BaseAddr
        DCD     Debug_Title - Module_BaseAddr
        DCD     Debug_HelpStr - Module_BaseAddr
        DCD     Debug_HC_Table - Module_BaseAddr
        DCD     Module_SWISystemBase + DebuggerSWI * Module_SWIChunkSize
        DCD     Debug_SWI_Code - Module_BaseAddr
        DCD     Debug_SWI_Name - Module_BaseAddr
        DCD     0
 [ international_help
        DCD     message_filename - Module_BaseAddr
 |
        DCD     0
 ]
 [ :LNOT: No32bitCode
        DCD     Debug_Flags - Module_BaseAddr
 ]

Debug_Title ; share with
Debug_SWI_Name
        DCB     "Debugger", 0           ; SWI class
        DCB     "Disassemble", 0        ; +0
        DCB     "DisassembleThumb", 0   ; +1
        DCB     0

Debug_HelpStr
        DCB     "Debugger", TAB, "$Module_MajorVersion ($Module_Date)"
 [ Module_MinorVersion <> ""
        DCB     " $Module_MinorVersion"
 ]
        DCB     0
        ALIGN

 [ :LNOT: No32bitCode
Debug_Flags
        DCD     ModuleFlag_32bit
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

Debug_Init Entry

        IMPORT  __RelocCode
        BL      __RelocCode

        LDR     r2, [r12]               ; Hard or soft init ?
        TEQ     r2, #0
        BNE     %FT00

; Hard init

        LDR     r3, =TotalSpace         ; Claim module workspace
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        EXIT    VS                      ; 'No room' good enough error

        STR     r2, [r12]

00      MOV     wp, r2


        ADRL    r0, RelocatedCodeStart  ; fwd ref
        MOV     r3, #BreakCodeEnd - BreakCodeStart
01      SUBS    r3, r3, #4              ; Move breakpoint code to RAM
        LDRPL   r1, [r0, r3]
        STRPL   r1, [r2, r3]
        BPL     %BT01

 [ StrongARM
        MOV     r0, #1
        MOV     r1, r2
        ADD     r2, r1, #(nbreakpoints*8)
        SWI     XOS_SynchroniseCodeAreas
 ]

        ADRL    r14, BreakTrap          ; Address of breakpoint code in ROM
        STR     r14, JumpStore          ; fwd ref
        STR     wp, r12Store            ; A good idea to initialise it

        ADR     r1, Breaklist           ; Clear breakpoint list
        MOV     r3, #nbreakpoints
        MOV     r14, #-1
10      STR     r14, [r1], #8           ; Only need to zap address field
        SUBS    r3, r3, #1
        BNE     %BT10

        ADR     r1, Registers           ; Clear register dump area
        MOV     r3, #17
        MOV     r14, #0
        STR     r14, MessageFile_Open
        STR     r14, ROMDebugSymbols
        STR     r14, ROMBaseAddr
20      STR     r14, [r1], #4
        SUBS    r3, r3, #1
        BNE     %BT20

        MOV     r0, #ExceptionDumpArea  ; Change exception register dump area
        ADR     r1, Registers
        SWI     XOS_ChangeEnvironment
        STRVC   r1, OldExceptionDumpArea

        EXIT    VS

    [ UseCVFPNEON
        ADR     R3, Module_BaseAddr
        IMPORT  |!$$Base|
        LDR     R0, =|!$$Base|
        SUB     R3, R3, R0              ;Calculate relocation offset. Should be zero for ROM builds, but calculate anyway just in case we've been manually loaded or something.
        STR     R3, CRelocOffset
    ]

        MOV     r3, #0
        STR     R3, Mistake
        STR     R3, OldAddress          ;Init vars for dodgy code detection
        STR     R3, OldThumbAddress
        STR     R3, OldThumbInst
        STR     R3, PhysAddrWrd
        MRS     R3, CPSR
        ANDS    R3, R3, #2_11100        ; non-zero if in a 32-bit mode
        STRB    R3, SysIs32bit
        BEQ     %FT40

; Find DebuggerSpace

        MOV     R0, #6
        MOV     R1, #0
        MOV     R2, #OSRSI6_DebuggerSpace
        SWI     XOS_ReadSysInfo
        MOVVS   R2, #0
        CMP     R2, #0
        LDREQ   R2, =Legacy_DebuggerSpace
        STR     R2, ptr_DebuggerSpace
        ASSERT  nbreakpoints*8 <= ?Legacy_DebuggerSpace

; Calculate MOVPCInstr
; This whole section could do with some checks to make sure DebuggerSpace and DebuggerSpace_Size are acceptable

        LDR     R0, ptr_DebuggerSpace
        MOV     R1, #32 ; ROR amount
        LDR     R2, =&E3A0F000 ; MOV PC,#0
25
        CMP     R0, #256
        MOVHS   R0, R0, LSR #2
        SUBHS   R1, R1, #2
        BHS     %BT25

        ORR     R2, R2, R0
        ORR     R2, R2, R1, LSL #7
        STR     R2, MOVPCInstr

; MakeBranch modifies MOVPCInstr by just adding the breakpoint number * 2
; So 2 :ROR: R1 is the number of bytes between each branch

        MOV     R3, #2
        MOV     R3, R3, ROR R1

; Fill in the zero page branch table

        LDR     R4, ptr_DebuggerSpace
        ASSERT  nbreakpoints = 16
        ADD     R0, R4, R3, LSL #4
        LDR     R1, =&E51FF004          ; LDR PC,[PC,#-4]
        ADR     R2, BreakCodeStart + (nbreakpoints-1)*8
30      SUB     R0, R0, R3
        STMIA   R0, {R1, R2}
        SUB     R2, R2, #8
        CMP     R0, R4
        BHI     %BT30

 [ StrongARM
        MOV     r1, r0
        MOV     r0, #1
        ASSERT  nbreakpoints = 16
        ADD     r2, r1, r3, LSL #4
        SWI     XOS_SynchroniseCodeAreas
        CLRV
 ]

; 

40
        ; Find ROM
        MOV     r0, #ModHandReason_LookupName
        ADRL    r1, Where_UMod
        SWI     XOS_Module
        BVS     %FT42
        MOV     r4, r3, LSR #20
        MOV     r4, r4, LSL #20
        STR     r4, ROMBaseAddr

        ; Find ROM debug symbols
        MOV     r0, #15
        MOV     r1, #0
41
        SWI     XOS_ReadSysInfo
        MOVVS   r1, #0
        CMP     r1, #0
        BEQ     %FT42
        CMP     r2, #ExtROMFooter_DebugSymbols
        CMPEQ   r3, #4
        BNE     %BT41
        LDW     r0, r1, r2, r3
        ADD     r0, r0, r4
        STR     r0, ROMDebugSymbols
42

        ; SAR
        MOV     R3, #0
        STR     R3, DisOpts
        BL      create_codevar
        BL      init_codevar

	[ standalone
	BLVC    declareresourcefsfiles
	]

        MOV     R3, #DumpOptions_Default
        STR     R3, DumpOptions
        BLVC    ExcDump_CodeVar_Init
      [ DumpOptions_Default <> 0
        BLVC    ExcDump_Init
      ]

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    no registers trashable

        ALIGN
Debug_ServiceTable
        DCD     0
        DCD     Debug_ServiceBody - Module_BaseAddr
        DCD     Service_Reset                   ; &27
      [ standalone
        DCD     Service_ResourceFSStarting      ; &60
      ]
        DCD     0

        DCD     Debug_ServiceTable - Module_BaseAddr
Debug_Service ROUT
        MOV     r0, r0
        TEQ     r1, #Service_Reset
      [ standalone
	TEQNE   R1,#Service_ResourceFSStarting
      ]
        MOVNE   pc, lr

Debug_ServiceBody
      [ standalone
        TEQ     R1,#Service_ResourceFSStarting
        BEQ     serviceresourcefsstarting
      ]
        Entry   "r0, r1"
        LDR     wp, [r12]
        MOV     r0, #ExceptionDumpArea          ; Set exception dump area
        ADR     r1, Registers
        SWI     XOS_ChangeEnvironment
        STRVC   r1, OldExceptionDumpArea
        EXIT

      [ standalone
; ResourceFS has been reloaded - redeclare resource files
; In    R2 -> address to call
;       R3 -> workspace for ResourceFS module

serviceresourcefsstarting
        Push    "R0,LR"
        BL      Resources
        MOV     LR,PC                   ; LR -> return address
        MOV     PC,R2                   ; R2 -> address to call
        Pull    "R0,PC"
      ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r6 trashable

Debug_Die Entry

        LDR     wp, [r12]

        BL      ExcDump_CodeVar_Shutdown

        BL      SwapAllBreakpoints      ; Be nice

        MOV     r0, #ExceptionDumpArea  ; Restore old exception dump area
        MOV     r1, #0                  ; if current one is us
        SWI     XOS_ChangeEnvironment
        ADR     r14, Registers
        TEQS    r14, r1
        MOVEQ   r0, #ExceptionDumpArea
        LDREQ   r1, OldExceptionDumpArea
        SWIEQ   XOS_ChangeEnvironment
        LDR     r0, MessageFile_Open
        TEQS    r0, #0
        ADRNE   r0, MessageFile_Block
        SWINE   XMessageTrans_CloseFile
        MOV     r0, #0
        STR     r0, MessageFile_Open

        ; SAR
        BL      destroy_codevar

      [ standalone
        BL      Resources
        SWI     XResourceFS_DeregisterFiles ; ignore errors
      ]

        CLRV
        EXIT                            ; Don't refuse to die

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                        (No. of Parameters)
Debug_HC_Table ; Name       Max  Min Flags

      [ international_help
ihflag  * International_Help
      |
ihflag  * 0
      ]
        Command BreakClr,    1,   0, ihflag
        Command BreakList,   0,   0, ihflag
        Command BreakSet,    1,   1, ihflag
        Command Continue,    0,   0, ihflag
        Command Debug,       0,   0, ihflag
        Command InitStore,   1,   0, ihflag
        Command Memory,      5,   1, ihflag ; P B R + R
        Command MemoryA,     4,   1, ihflag ; P B R V
        Command MemoryI,     7,   1, ihflag ; P T A +/- B + C
        Command ShowRegs,    0,   0, ihflag
        Command ShowFPRegs,  0,   0, ihflag
      [ SupportARMV
        Command ShowVFPRegs, 2,   0, ihflag
      ]
        Command Where,       1,   0, ihflag
        DCB     0                       ; end of table

        GET     TokHelpSrc
        ALIGN

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Debug_SWI_Code Entry "r9"

        LDR     wp, [r12]
        TEQ     R11,#0
        BEQ     swi00
        TEQ     R11,#1
        BEQ     swi01

        ADR     R0,ErrorBlock_ModuleBadSWI
        BL      CopyErrorP1

        EXIT

        MakeInternatErrorBlock ModuleBadSWI,,BadSWI

swi00
        LDR     R14,Mistake

        CMPS    R14,#Potential_Banked_Next  ;potential error if a banked access occurs (after LDM)
        MOVEQ   R14,#Potential_Banked
        CMPS    R14,#Potential_SWICDP_Next  ;potential error if a SWI occurs (after coproc)
        MOVEQ   R14,#Potential_SWICDP

        STR     R14,Mistake

        MOV     R9, R1
        BL      Instruction

        LDR     R14,Mistake

        CMPS    R14,#Potential_Banked
        CMPNES  R14,#Potential_SWICDP
        MOVEQ   R14,#0

        STREQ   R14,Mistake

        EXIT

swi01
        MOV     R9,R1
        BL      ThumbInstruction

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Memory_Error
        DCD     ErrorNumber_Syntax
        DCB     "SDBGMEM", 0
        ALIGN


Memory_Code Entry "r6-r11",8

        MOV     R6,#"B"
        BL      MemoryCommon

        ADR     r2, Memory_Error
        MOV     r10, #0 ; arguments can only be 32-bit
        BL      GetCommandParms
        BLVS    CopyErrorR2
        EXIT    VS

        TST     r8, #secondparm
        ADDEQ   r7, r9, #256            ; [no second parameter]

        TEQS    r7, r9                  ; If same, ensure we do one byte/word
        ADDEQ   r7, r7, r6

        BL      SwapAllBreakpoints

        MOV     r0, #VduExt_WindowWidth
        MOV     r1, #-1
        Push    "r0, r1"
        MOV     r0, sp
        MOV     r1, sp
        SWI     XOS_ReadVduVariables
        Pull    "r0, r1"
        STR     r0, WindowWidth

        CMPS    r0, #8+2+3*32+3+1*32
        MOVHS   r14, #32
        MOVLO   r14, #16
        STR     r14, BytesPerLine

        MOV     r11, #0                 ; Force header on first row

05 ; Loop displaying memory

        SWI     XOS_ReadEscapeState
        BCS     %FT95

        TST     r11, #15
        BLEQ    MemoryHeader

        BLVC    DisplayHexWord_R9       ; address

        SWIVC   XOS_WriteI+space
        SWIVC   XOS_WriteI+colon
        BVS     %FT90

        LDR     r8, BytesPerLine
        TST     r6, #&C
        MOVNE   r8, r8, LSR #2          ; words or double-words per line
        TST     r6, #&A
        MOVNE   r8, r8, LSR #1          ; half-words or double-words per line

        MOV     r0, r9

10
        CMP     r6, #8
        BEQ     %FT25
        CMP     r6, #2
        BHI     %FT20
        BEQ     %FT15

        MOV     r2, #8-4                ; byte

        SWI     XOS_WriteI+space        ; Display byte
        BVS     %FT90

        CMP     r0, r7
        BCS     %FT50                   ; [ended, so blank. DO NOT READ BYTE]

        Push    "r1"
        BL      do_readB
        MOV     r10, r1
        ADD     r0, r0, #1
        Pull    "r1"
        B       %FA30

15      MOV     r2, #16-4

        SWI     XOS_WriteI+space
        SWIVC   XOS_WriteI+space
        BVS     %FT90

        CMP     r0, r7
        BCS     %FT50                   ; [ended, so blank. DO NOT READ HWORD]

        Push    "r1"
        BL      do_readH
        MOV     r10, r1
        ADD     r0, r0, #2
        Pull    "r1"
        B       %FA30

20
        MOV     r2, #32-4
        SWI     XOS_WriteS              ; Display word
        DCB     "    ", 0
        ALIGN
        BVS     %FT90

        CMP     r0, r7
        BCS     %FT50                   ; [ended, so blank. DO NOT READ WORD]

        Push    "r1"
        BL      do_readW
        MOV     r10, r1
        ADD     r0, r0, #4
        Pull    "r1"
        B       %FA30

25      MOV     r2, #64-4

        SWI     XOS_WriteS              ; Display word
        DCB     "        ", 0
        ALIGN
        BVS     %FT90

        CMP     r0, r7
        BCS     %FT50                   ; [ended, so blank. DO NOT READ DWORD]

        Push    "r1"
        ADD     r1, sp, #4
        BL      do_readD
        MOV     r10, r1
        ADD     r0, r0, #8
        Pull    "r1"

30      BLVC    DisplayHex
        B       %FA60


50      BLVC    Blank                   ; Output r2 spaces

60      BVS     %FT90

        SUBS    r8, r8, #1              ; Loop if not done whole line
        BNE     %BT10                   ; Even if ended in middle, were padding

        BL      SpaceColonSpace
        BVS     %FT90

        SUB     r2, r7, r9              ; nchars to print this row

        LDR     r14, BytesPerLine
        CMP     r2, r14
        MOVHS   r2, r14

        CMPS    r2, #0                  ; VClear
        BLNE    DisplayCharacters
        SWIVC   XOS_NewLine
        BVS     %FT90

        ADD     r11, r11, #1            ; Another line gone by

        LDR     r14, BytesPerLine
        ADD     r9, r9, r14             ; More bytes per line done

        CMPS    r9, r7
        BLO     %BT05


90      BL      SwapAllBreakpoints
        EXIT

95      BL      AckEscape
        B       %BT90

; in all these cases, if the OS_Memory call fails, we assume
; the system is an IOMD-based non-HAL system, where the 512MB
; of physical address space is mapped in at &80000000.

; in: r0 = address, r1 -> buffer to hold (double-word) data
do_readD ROUT
        Push    "r0-r3, r14"
        LDR     r14, PhysAddrWrd
        TEQ     r14, #0
        BNE     %FT50
        LDRD    r2, [r0]         ;read to r2,r3
        STMIA   r1, {r2,r3}
        Pull    "r0-r3, pc"
50
        MOV     r1, r0
        MOV     r0, #14
        SWI     XOS_Memory       ;access physical address
        BICVS   r2, r1, #&E0000000
        ORRVS   r2, r2, #&80000000
        LDR     lr, [sp, #4]
        LDRD    r0, [r2]         ;read from logical mapping into r0,r1
        STMIA   lr, {r0,r1}
        MOVVC   r0, #15
        MOVVC   r1, r3
        SWIVC   XOS_Memory       ;release physical address
        ADDS    r1, r2, #0       ;clear V
        Pull    "r0-r3, pc"

; in: r0 = address, out: r1 = (word) data
do_readW ROUT
        Push    "r0,r2-r3, r14"
        LDR     r14, PhysAddrWrd
        TEQ     r14, #0
        LDREQ   r1, [r0]
        Pull    "r0,r2-r3, pc",EQ
        MOV     r1, r0
        MOV     r0, #14
        SWI     XOS_Memory       ;access physical address
        BICVS   r2, r1, #&E0000000
        ORRVS   r2, r2, #&80000000
        LDR     r2, [r2]         ;read from logical mapping
        MOVVC   r0, #15
        MOVVC   r1, r3
        SWIVC   XOS_Memory       ;release physical address
        ADDS    r1, r2, #0       ;clear V
        Pull    "r0,r2-r3, pc"

; in: r0 = address, out: r1 = (half-word) data
do_readH ROUT
        Push    "r0,r2-r3, r14"
        LDR     r14, PhysAddrWrd
        TEQ     r14, #0
        BNE     %FT50
        LDRH    r1, [r0]
        Pull    "r0,r2-r3, pc"
50
        MOV     r1, r0
        MOV     r0, #14
        SWI     XOS_Memory       ;access physical address
        BICVS   r2, r1, #&E0000000
        ORRVS   r2, r2, #&80000000
        LDRH    r2, [r2]         ;read from logical mapping
        MOVVC   r0, #15
        MOVVC   r1, r3
        SWIVC   XOS_Memory       ;release physical address
        ADDS    r1, r2, #0       ;clear V
        Pull    "r0,r2-r3, pc"

; in: r0 = address, out: r1 = (byte) data
do_readB ROUT
        Push    "r0,r2-r3, r14"
        LDR     r14, PhysAddrWrd
        TEQ     r14, #0
        LDREQB  r1, [r0]
        Pull    "r0,r2-r3, pc",EQ
        MOV     r1, r0
        MOV     r0, #14
        SWI     XOS_Memory       ;access physical address
        BICVS   r2, r1, #&E0000000
        ORRVS   r2, r2, #&80000000
        LDRB    r2, [r2]         ;read from logical mapping
        MOVVC   r0, #15
        MOVVC   r1, r3
        SWIVC   XOS_Memory       ;release physical address
        ADDS    r1, r2, #0       ;clear V
        Pull    "r0,r2-r3, pc"

; in: r0 = address, r1 -> buffer holding (double-word) data
do_writeD ROUT
        Push    "r0-r3, r14"
        LDR     r14, PhysAddrWrd
        TEQ     r14, #0
        BNE     %FT50
        LDMIA   r1, {r2,r3}
        STRD    r2, [r0]         ;write from r2,r3
        Pull    "r0-r3, pc"
50
        MOV     r1, r0
        MOV     r0, #14
        SWI     XOS_Memory       ;access physical address
        BICVS   r2, r1, #&E0000000
        ORRVS   r2, r2, #&80000000
        LDR     lr, [sp, #4]
        LDMIA   lr, {r0,r1}
        STRD    r0, [r2]         ;store from r0,r1 into logical mapping
        MOVVC   r0, #15
        MOVVC   r1, r3
        SWIVC   XOS_Memory       ;release physical address
        ADDS    r0, r0, #0       ;clear V
        Pull    "r0-r3, pc"

; in: r0 = address, r1 = (word) data
do_writeW ROUT
        Push    "r0-r3, r14"
        LDR     r14, PhysAddrWrd
        TEQ     r14, #0
        STREQ   r1, [r0]
        Pull    "r0-r3, pc",EQ
        MOV     r1, r0
        MOV     r0, #14
        SWI     XOS_Memory       ;access physical address
        BICVS   r2, r1, #&E0000000
        ORRVS   r2, r2, #&80000000
        LDR     r1, [sp, #4]
        STR     r1, [r2]         ;write to logical mapping
        MOVVC   r0, #15
        MOVVC   r1, r3
        SWIVC   XOS_Memory       ;release physical address
        ADDS    r0, r0, #0       ;clear V
        Pull    "r0-r3, pc"

; in: r0 = address, r1 = (half-word) data
do_writeH ROUT
        Push    "r0-r3, r14"
        LDR     r14, PhysAddrWrd
        TEQ     r14, #0
        BNE     %FT50
        STRH    r1, [r0]
        Pull    "r0-r3, pc"
50
        MOV     r1, r0
        MOV     r0, #14
        SWI     XOS_Memory       ;access physical address
        BICVS   r2, r1, #&E0000000
        ORRVS   r2, r2, #&80000000
        LDR     r1, [sp, #4]
        STRH    r1, [r2]         ;write to logical mapping
        MOVVC   r0, #15
        MOVVC   r1, r3
        SWIVC   XOS_Memory       ;release physical address
        ADDS    r0, r0, #0       ;clear V
        Pull    "r0-r3, pc"

; in: r0 = address, r1 = (byte) data
do_writeB ROUT
        Push    "r0-r3, r14"
        LDR     r14, PhysAddrWrd
        TEQ     r14, #0
        STREQB  r1, [r0]
        Pull    "r0-r3, pc",EQ
        MOV     r1, r0
        MOV     r0, #14
        SWI     XOS_Memory       ;access physical address
        BICVS   r2, r1, #&E0000000
        ORRVS   r2, r2, #&80000000
        LDR     r1, [sp, #4]
        STRB    r1, [r2]         ;write to logical mapping
        MOVVC   r0, #15
        MOVVC   r1, r3
        SWIVC   XOS_Memory       ;release physical address
        ADDS    r0, r0, #0       ;clear V
        Pull    "r0-r3, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SpaceColonSpace Entry

        SWI     XOS_WriteI+space
        SWIVC   XOS_WriteI+colon
        SWIVC   XOS_WriteI+space
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

MemoryHeader Entry

        SWI     XOS_NewLine
        EXIT    VS
        BL      message_writes
        DCB     "M22", 0                ; "Address  :"
        ALIGN
        EXIT    VS

        ; Use the system control register to check whether we're using rotated or unaligned loads. Safer than attempting an actual unaligned load, because alignment faults may be turned on!
        ; Unfortunately, in ARMv5 and below, any unused bits of the system control register have undefined values.
        ; So we must first check if we're on ARMv6/v7 (where the 'U' bit was first introduced), and then check if the bit is set :(
        MRC     p15,0,r0,c0,c0,0
        ANDS    lr, r0, #&0000F000 ; EQ = ARM 3/6
        TEQNE   lr, #&00007000 ; EQ = ARM 7
        BEQ     %FT40 ; Old CPU, so must be rotated load
        AND     lr, r0, #&000F0000 ; Get architecture number
        TEQ     lr, #&00070000 ; ARMv6?
        TEQNE   lr, #&000F0000 ; ARMv7+?
        BNE     %FT40 ; Old CPU, so must be rotated load
        MRC     p15, 0, r0, c1, c0, 0
        TST     r0, #1:SHL:22 ; 'U' bit
        BEQ     %FT40                   ; pre-ARMv6 style rotated load
                                        ; else ARMv7-style unaligned load
        CMP     r6, #4
        ADRHI   r0, DoubleWords_Unaligned
        ADREQ   r0, Words_Unaligned
        CMP     r6, #2
        ADREQ   r0, HalfWords_Unaligned
        ADRLO   r0, Bytes
        ADR     lr, %FT70
        MOV     pc, r0
40
        CMP     r6, #4
        ADRHI   r0, DoubleWords
        ADREQ   r0, Words
        CMP     r6, #2
        ADREQ   r0, HalfWords
        ADRLO   r0, Bytes
        ADR     lr, %FT70
        MOV     pc, r0
70
        BL      SpaceColonSpace
        EXIT    VS

        LDR     r14, BytesPerLine       ; Doing in 32 ?
        CMPS    r14, #32
        ADREQ   r0, %FT85
        SWIEQ   XOS_Write0

        ADRVC   r0, %FT80
        BLVC    message_write0
        MOVVC   r11, #0
        SWIVC   XOS_NewLine
        EXIT

80
        DCB     "M23"                   ; "   ASCII Data"

85
        DCB     "        ", 0           ; Otherwise centre in field of 32
;                01234567

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Print header in right order dependent on r9
; As of ARMv7, non-word-aligned loads will abort, but maybe that will change in future?

DoubleWords_Unaligned Entry "r1, r9, r10, r11"

        LDR     r11, BytesPerLine
        MOV     r1, #16
        ADR     r10, Unaligned_Header+46-16

10      SWI     XOS_WriteS
        DCB     "        ", 0
        ALIGN
        ANDVC   r9, r9, #&F
        SUBVC   r0, r10, r9, LSL #1
        SWIVC   XOS_WriteN
        EXIT    VS

        ADD     r9, r9, #8

        SUBS    r11, r11, #8
        BNE     %BT10
        EXIT

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Print header in right order dependent on r9

Words_Unaligned Entry "r1, r9, r10, r11"

        LDR     r11, BytesPerLine
        MOV     r1, #8
        ADR     r10, Unaligned_Header+46-8

10      SWI     XOS_WriteS
        DCB     "    ", 0
        ALIGN
        ANDVC   r9, r9, #&F
        SUBVC   r0, r10, r9, LSL #1
        SWIVC   XOS_WriteN
        EXIT    VS

        ADD     r9, r9, #4

        SUBS    r11, r11, #4
        BNE     %BT10
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Print header in right order dependent on r9

HalfWords_Unaligned Entry "r1, r9, r10, r11"

        LDR     r11, BytesPerLine
        MOV     r1, #4
        ADR     r10, Unaligned_Header+46-4

10      SWI     XOS_WriteS
        DCB     "  ", 0
        ALIGN
        ANDVC   r9, r9, #&F
        SUBVC   r0, r10, r9, LSL #1
        SWIVC   XOS_WriteN
        EXIT    VS

        ADD     r9, r9, #2

        SUBS    r11, r11, #2
        BNE     %BT10
        EXIT


Unaligned_Header
        DCB     " 6 5 4 3 2 1 0 F E D C B A 9 8 7 6 5 4 3 2 1 0"
        ALIGN
        
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Print header in right order dependent on r9
; Behaviour if non-half-word aligned is unpredictable
; XScale seems to ignore bit 0 of the address, so let's reflect that

HalfWords Entry "r9, r10, r11"

        LDR     r11, BytesPerLine
        MOV     r1, #4
        ADR     r10, Unaligned_Header+46-4

10      SWI     XOS_WriteS
        DCB     "  ", 0
        ALIGN
        ANDVC   r9, r9, #&F
        BICVC   r0, r9, #1
        SUBVC   r0, r10, r0, LSL #1
        SWIVC   XOS_WriteN
        EXIT    VS

        ADD     r9, r9, #2

        SUBS    r11, r11, #2
        BNE     %BT10
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Print header in right order dependent on r9
; Behaviour if non-word- or non-double-word- (on an implementation-defined basis) aligned is unpredictable
; XScale seems to ignore the bottom two address bits and fails to carry from bit 2 to 3, so let's reflect that

DoubleWords Entry "r1, r9, r10, r11"

        LDR     r11, BytesPerLine
        MOV     r1, #16
        TST     r9, #4
        ADREQ   r10, Unaligned_Header+46-16
        ADRNE   r10, BrokenXScale_Header+32-16

10      SWI     XOS_WriteS
        DCB     "        ", 0
        ALIGN
        ANDVC   r0, r9, #8
        SUBVC   r0, r10, r0, LSL #1
        SWIVC   XOS_WriteN
        EXIT    VS

        ADD     r9, r9, #8

        SUBS    r11, r11, #8
        BNE     %BT10
        EXIT

BrokenXScale_Header
        DCB     " F E D C F E D C 7 6 5 4 7 6 5 4"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Print header in right order dependent on r9

Words Entry "r1, r9, r10, r11"

        LDR     r11, BytesPerLine
        MOV     r1, #8
        ADR     r10, Words_Header+14-8

10      SWI     XOS_WriteS
        DCB     "    ", 0
        ALIGN
        ANDVC   r0, r9, #3
        SUBVC   r0, r10, r0, LSL #1
        ANDVC   lr, r9, #&C
        ADDVC   r0, r0, lr, LSL #2
        SWIVC   XOS_WriteN
        EXIT    VS

        ADD     r9, r9, #4

        SUBS    r11, r11, #4
        BNE     %BT10
        EXIT

Words_Header
        DCB     " 2 1 0 3 2 1 0", 0, 0
        DCB     " 6 5 4 7 6 5 4", 0, 0
        DCB     " A 9 8 B A 9 8", 0, 0
        DCB     " E D C F E D C", 0, 0

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Count from r9 to r9+15 modulo 16 along the top

Bytes Entry "r9, r10, r11"

        LDR     r11, BytesPerLine

10      SWI     XOS_WriteI+space
        SWI     XOS_WriteI+space
        MOVVC   r2, #4-4
        ANDVC   r10, r9, #&F
        BLVC    DisplayHex
        EXIT    VS

        ADD     r9, r9, #1

        SUBS    r11, r11, #1
        BNE     %BT10
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Fill remaining space with 1 + r2/4 blanks

; In    r2 = number of blanks to go (multiple of 4)

Blank Entry

10      SWI     XOS_WriteI+space
        EXIT    VS

        SUBS    r2, r2, #4
        BPL     %BT10
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; in    r12 to be indirected
;       r0 -> string
;       r6 = character to check for

; Out   r1 -> string
;       r6 = 1, 2, 4 or 8 if r6 = 'B' on entry, else r6 = 1 or 4 depending on whether 'r6' present
;       any matching flag is skipped
;       r0 corrupt

MemoryCommon Entry

        LDR     wp, [r12]

        MOV     r1, r0

        MOV     r0, #0
        STR     r0, PhysAddrWrd
        BL      MemoryPhys

        BL      SkipSpaces              ; check for 'r6',space
        TEQ     r6, #'B'
        BNE     %FT20
        TEQ     r0, #'B'
        TEQNE   r0, #'b'
        MOVEQ   r6, #1
        TEQ     r0, #'H'
        TEQNE   r0, #'h'
        MOVEQ   r6, #2
        TEQ     r0, #'D'
        TEQNE   r0, #'d'
        MOVEQ   r6, #8
        TEQNE   r6, #2
        TEQNE   r6, #1
        B       %FT25
20      TEQ     r0, r6                  ; Check upper case
        ADDNE   r6, r6, #"a"-"A"
        TEQNE   r0, r6                  ; Check lower case
        MOVEQ   r6, #1
25      ; Valid character must also be followed by space
        LDREQB  r0, [r1, #1]
        TEQEQ   r0, #space
        ADDEQ   r1, r1, #2              ; skip flag character and space if match
        MOVNE   r6, #4                  ; default to 4 in case of no match

        LDR     r0, PhysAddrWrd
        TEQ     r0, #0
        BLEQ    MemoryPhys

        EXIT

;if we see we are doing a physical access, do cache flush to minimise
;possible confusion for user (eg. looking at memory via physical address
;that could otherwise be seen as different to view via logical address,
;if writeback data cache)
;
MemoryPhys ROUT
        ; check for 'P',space,
        Push    "r0, r14"
        BL      SkipSpaces
        TEQ     r0, #"p"
        TEQNE   r0, #"P"
        LDREQB  r0, [r1, #1]
        TEQEQ   r0, #space
        Pull    "r0, pc",NE
        MOV     r0, #1
        STR     r0, PhysAddrWrd
        ADD     r1, r1, #2
        MOV     r0, #&80000001   ; flush cache(s)
        SWI     XOS_MMUControl
        Pull    "r0, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

MemoryA_Code Entry "r6-r11", 8+8

        MOV     R6,#"B"
        BL      MemoryCommon

        ADR     r2, MemoryA_Error
        TEQ     r6, #8
        MOVNE   r10, #0
        MOVEQ   r10, #Command_64bitData
        ADD     r11, sp, #8
        BL      GetCommandParms
        EXIT    VS

        TST     r8, #&FF00              ; had operator ?
        BNE     %FT99                   ; [not permitted here]

        BL      SwapAllBreakpoints

        TST     r8, #secondparm
        BEQ     Interactive             ; [no second parameter]

; Simple command, not interactive

        CMP     r6, #8
        BEQ     mai_doubleword
        CMP     r6, #2
        BLO     mai_byte
        BEQ     mai_halfword

mai_word
        MOV     r2, #32-4
        Push    "r1"
        MOV     r0, r9
        BL      do_readW
        MOV     r4, r1
        MOV     r1, r7
        BL      do_writeW
        BL      do_readW
        MOV     r5, r1
        ADR     r0, %FT40
        Pull    "r1"
        B       mai_cont

mai_doubleword
        MOV     r2, #64-4
        MOV     r4, sp     ; buffer for old value
        ADD     r5, sp, #8 ; buffer for new value
        Push    "r1"
        MOV     r1, r4
        MOV     r0, r9
        BL      do_readD
        MOV     r1, r5
        BL      do_writeD
        BL      do_readD
        ADR     r0, %FT43
        Pull    "r1"
        B       mai_cont

mai_halfword
        MOV     r2, #16-4
        Push    "r1"
        MOV     r0, r9
        BL      do_readH
        MOV     r4, r1
        MOV     r1, r7
        BL      do_writeH
        BL      do_readH
        MOV     r5, r1
        ADR     r0, %FT42
        Pull    "r1"
        B       mai_cont

mai_byte
        MOV     r2, #8-4
        Push    "r1"
        MOV     r0, r9
        BL      do_readB
        MOV     r4, r1
        MOV     r1, r7
        BL      do_writeB
        BL      do_readB
        MOV     r5, r1
        ADR     r0, %FT41
        Pull    "r1"
mai_cont
        BL      message_write0

        BLVC    DisplayHexWord_R9

        ADRVC   r0, %FT44
        BLVC    message_write0

        MOVVC   r10, r4
        BLVC    DisplayHex

        ADRVC   r0, %FT45
        BLVC    message_write0

        MOVVC   r10, r5
        BLVC    DisplayHex

        SWIVC   XOS_NewLine

        BL      SwapAllBreakpoints
        EXIT

40
        DCB     "M24", 0                ; "Word at &"
41
        DCB     "M25", 0                ; "Byte at &"
42
        DCB     "M75", 0                ; "Half-word at &"
43
        DCB     "M76", 0                ; "Double-word at &"
44
        DCB     "M26", 0                ; " was &"
45
        DCB     "M27", 0                ; " altered to &"
        ALIGN

99      ADR     r0, MemoryA_Error
        BL      CopyError
        EXIT


MemoryA_Error
        DCD     ErrorNumber_Syntax
        DCB     "SDBGMMA", 0
        ALIGN

; .............................................................................

Interactive ROUT

        SUB     sp, sp, #256            ; Use buffer on stack
        MOV     r8, r6                  ; 1 or 4, initial step +ve

10
        CMPS    r8, #0
        MOVGE   r0, #"+"
        MOVLT   r0, #"-"
        SWI     XOS_WriteC
        SWIVC   XOS_WriteI+space

        BLVC    DisplayHexWord_R9

        BLVC    MarkPC

        BVS     %FT90
        Push    "r0, r1"
        MOV     r0, r9
        ADR     lr, %FT20             ; they don't return using MOVS
        ADD     r1, sp, #8+256        ; buffer for old value if dword
        CMP     r6, #4
        BHI     do_readD
        BEQ     do_readW
        CMP     r6, #2
        BEQ     do_readH
        BLO     do_readB
20
        MOV     r10, r1
        Pull    "r0, r1"
        MOVVC   r2, r6
        BLVC    DisplayCharacters

        BLVC    MarkBreakpoints

        BVS     %FT90
        CMP     r6, #4
        MOVHI   r2, #64-4
        MOVEQ   r2, #32-4
        CMP     r6, #2
        MOVEQ   r2, #16-4
        MOVLO   r2, #8-4
        BLVC    DisplayHex

        SWIVC   XOS_WriteI+space
        SWIVC   XOS_WriteI+colon
        SWIVC   XOS_WriteI+space

        BVS     %FT90
        CMP     r6, #4
        BEQ     %FT40                   ; Disassemble ARM
        CMP     r6, #2
        BNE     %FT50                   ; Don't disassemble for bytes or double-words
                                        ; Else disassemble Thumb
        Push    "r1"
        MOV     r0, r9
        BL      do_readH
        MOV     r0, r1
        Pull    "r1"
        MOVVC   r1, r9
        SWIVC   XDebugger_DisassembleThumb
        MOVVC   r0, r1
        SWIVC   XOS_Write0
        B       %FT50
40

        BVS     %FT48
        Push    "r1"
        MOV     r0, r9
        BL      do_readW
        MOV     r0, r1
        Pull    "r1"
48
        MOVVC   r1, r9
        SWIVC   XDebugger_Disassemble
        MOVVC   r0, r1
        SWIVC   XOS_Write0

50      SWIVC   XOS_NewLine
        ADRVC   r0, %FT96
        BLVC    message_write0

        MOVVC   r0, sp
        MOVVC   r1, #255
        MOVVC   r2, #space
        MOVVC   r3, #&FF
        SWIVC   XOS_ReadLine
        BVS     %FT90
        BCS     %FT95

        MOV     r1, sp
        BL      SkipSpaces
        ADDCC   r9, r9, r8              ; No parm, just advance in current dirn
        MOVCC   r7,r9

        BCC     %BT10

        TEQ     r0, #"+"
        MOVEQ   r8, r6                  ; Change to +ve step
        BEQ     %BT10

        TEQ     r0, #"-"
        RSBEQ   r8, r6, #0              ; Change to -ve step
        BEQ     %BT10

        CMP     r0, #"."                ; End interactive
        BEQ     %FT90                   ; VClear

        ADR     r0, ErrorBlock_Debug_InvalidValue
        BL      CopyError
        Push    "r8"
        CMP     r6, #8
        MOVEQ   r10, #Command_64bitData ; r11 should still be set up from entry to MemoryA_Code
        MOVNE   r10, #0
        BL      ReadOneParm             ; r7 := parm, r8 state
        Pull    "r8"
        BVS     %FT90

        CMP     r6, #8
        BEQ     int_doubleword
        CMP     r6, #2
        BLO     int_byte
        BEQ     int_halfword

int_word
        Push    "r0, r1"
        MOV     r0, r9
        MOV     r1, r7
        BL      do_writeW
        BL      do_readW
        MOV     r10, r1
        Pull    "r0, r1"
        MOV     r2, #32-4
        B       %FT70

int_doubleword
        Push    "r0, r1"
        MOV     r0, r9
        ADD     r1, sp, #8+256+8      ; buffer for new value
        BL      do_writeD
        BL      do_readD
        MOV     r10, r1
        Pull    "r0, r1"
        MOV     r2, #64-4
        B       %FT70

int_halfword
        Push    "r0, r1"
        MOV     r0, r9
        MOV     r1, r7
        BL      do_writeH
        BL      do_readH
        MOV     r10, r1
        Pull    "r0, r1"
        MOV     r2, #16-4
        B       %FT70

int_byte
        Push    "r0, r1"
        MOV     r0, r9
        MOV     r1, r7
        BL      do_writeB
        BL      do_readB
        MOV     r10, r1
        Pull    "r0, r1"
        MOV     r2, #8-4
70

        SWI     XOS_WriteS
        DCB     "                  . ", 0
        ALIGN

        BLVC    DisplayHex
        SWIVC   XOS_NewLine
        BVC     %BT10


90      ADD     sp, sp, #256
        BL      SwapAllBreakpoints
        EXIT

95      BL      AckEscape
        B       %BT90


        MakeInternatErrorBlock Debug_InvalidValue, NOALIGN, M46

96
        DCB     "M29", 0                ; "  Enter new value : "
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

BreakSet_Code Entry "r6-r11"

        LDR     wp, [r12]

        MOV     r1, r0
        MOV     r10, #0 ; arguments can only be 32-bit
        BL      ReadFirstParm           ; r7 := parm
        EXIT    VS

        TST     r8, #parmfollowed
        BNE     BreakSetError0

        LDRB    r4, SysIs32bit
        BIC     r7, r7, #3              ; Can only set at word address
        TEQ     r4, #0
        BNE     %FT05

        CMP     r7, #&04000000          ; Can only set in bottom 64M (has to
                                        ; construct a branch)
        BHS     BreakSetError1

05      ADR     r4, Breaklist           ; Check for breakpoint already in list
        MOV     r3, #(nbreakpoints-1)*8
10      LDR     r1, [r4, r3]
        TEQ     r1, r7
        BEQ     %FT40                   ; [already allocated, but ensure there]
        SUBS    r3, r3, #8              ; each breakpoint entry is 8 bytes
        BPL     %BT10

        MOV     r3, #(nbreakpoints-1)*8 ; Allocate breakpoint
20      LDR     r1, [r4, r3]
        CMP     r1, #-1
        BEQ     %FT30                   ; [free slot found]
        SUBS    r3, r3, #8
        BPL     %BT20

        ADR     r0, ErrorBlock_Debug_NoRoom
        BL      CopyError
        B       %FA90


30 ; Store breakpoint address and old contents, r3 = breakpoint number*8

        MOV     r1, r7
        STR     r1, [r4, r3]            ; breakpoint address
        LDR     r0, [r1]
        ADD     r14, r4, #4
        STR     r0, [r14, r3]           ; old data

40 ; Place branch at breakpoint address, r3 = breakpoint number*8, r1 valid

        LDRB    r0, SysIs32bit
        TEQ     r0, #0
        ADREQ   r0, BreakCodeStart
        ADDEQ   r0, r0, r3              ; each code entry is 8 bytes too
        BLEQ    MakeBranch
        BLNE    MakeMOVPC
        STR     r2, [r1]
 [ StrongARM
        ;Do the IMB thingy here, for the replaced instruction
        MOV     r0, #1          ;Ranged IMB
        MOV     r2, r1
        SWI     XOS_SynchroniseCodeAreas
 ]
        EXIT


BreakSetError0
        ADR     r0, BreakSet_Error
        BL      CopyError

90      EXIT


BreakSetError1
        ADR     r0, ErrorBlock_Debug_BadBreakpoint
        BL      CopyError
        B       %BA90


BreakSet_Error
        DCD     ErrorNumber_Syntax
        DCB     "SDBGBST", 0
        ALIGN

        MakeInternatErrorBlock Debug_NoRoom,,M48
        MakeInternatErrorBlock Debug_BadBreakpoint,,M50

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

BreakList_Code Entry "r6-r11"

        LDR     wp, [r12]

        ADR     r4, Breaklist           ; Any breakpoints to display ?
        MOV     r3, #(nbreakpoints-1)*8
10      LDR     r1, [r4, r3]
        CMP     r1, #-1
        BNE     %FT20                   ; [yes, starting at r3]
        SUBS    r3, r3, #8
        BPL     %BT10

        BL      message_writes
        DCB     "M31", 0                ; "No breakpoints set"
        SWIVC   XOS_NewLine
        ALIGN
        EXIT


20 ; Display list

        BL      message_writes
        DCB     "M32", 0                ; "Address     Old data"
        ALIGN
        SWIVC   XOS_NewLine
        EXIT    VS

30      CMP     r1, #-1
        BEQ     %FT60                   ; [no breakpoint entry here]

        MOV     r10, r1
        BL      DisplayHexWord          ; r10 = breakpoint address
        EXIT    VS

        SWI     XOS_WriteS
        DCB     "    ", 0
        ALIGN

        ADDVC   r14, r4, #4
        LDRVC   r10, [r14, r3]
        BLVC    DisplayHexWord          ; r10 = old data
        EXIT    VS

        LDRB    r0, SysIs32bit
        TEQ     r0, #0
        ADREQ   r0, BreakCodeStart      ; Check still B debugger
        ADDEQ   r0, r0, r3              ; each code entry is 8 bytes too
        BLEQ    MakeBranch              ; r1 from up there
        BLNE    MakeMOVPC
        LDR     r14, [r1]
        TEQS    r14, r2
        BEQ     %FT50                   ; [breakpoint present and correct]

        MOV     r14, #-1                ; Clear faulty breakpoint entry
        STR     r14, [r4, r3]           ; Only need to zap address field

        BL      message_writes
        DCB     "M33", 0 ; No newline   ; " : bad breakpoint; cleared."
        ALIGN

50      SWIVC   XOS_NewLine
        EXIT    VS

60      SUBS    r3, r3, #8
        LDRPL   r1, [r4, r3]
        BPL     %BT30

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

BreakClr_Error
        DCD     ErrorNumber_Syntax
        DCB     "SDBGBCL", 0
        ALIGN


BreakClr_Code Entry "r6-r11"

        LDR     wp, [r12]

        MOV     r1, r0
        ADR     r0, BreakClr_Error
        MOV     r10, #0 ; arguments can only be 32-bit
        BL      ReadOneParm             ; r7 := parm, r8 state
        BLVS    CopyError
        EXIT    VS

        LDRB    r4, SysIs32bit
        TEQ     r4, #0
        BICEQ   r7, r7, #ARM_CC_Mask    ; Can only set at word address in 64M

        ADR     r4, Breaklist
        MOV     r3, #(nbreakpoints-1)*8

        TST     r8, #hasparm
        BEQ     %FT50                   ; [no parm, so prompt]

; Clear particular breakpoint

10      LDR     r1, [r4, r3]
        TEQS    r1, r7
        BEQ     %FT20                   ; [found]
        SUBS    r3, r3, #8
        BPL     %BT10

        ADR     r0, ErrorBlock_Debug_BreakNotFound
        BL      CopyError
        EXIT


20      BL      ClearBreakpoint         ; uses r1,r3,r4
        EXIT


50 ; Clear all breakpoints

        BL      message_writes
        DCB     "M35", 0                ; "Clear all breakpoints? [Y/N]"
        ALIGN

        SWIVC   XOS_Confirm             ; So sexy, huh ? Returns lowercase char
        EXIT    VS
        BLCS    AckEscape
        SWIVC   XOS_NewLine
        EXIT    VS

        ;TEQ     r0, #"y"
        EXIT    NE                      ; [anything else -> go home]


60      LDR     r1, [r4, r3]
        CMP     r1, #-1
        BLNE    ClearBreakpoint         ; uses r1,r3,r4

        SUBS    r3, r3, #8
        BPL     %BT60

        BL      message_writes
        DCB     "M36", 0                ; "All breakpoints cleared"
        ALIGN
        SWIVC   XOS_NewLine
        EXIT


        MakeInternatErrorBlock Debug_BreakNotFound,,M45

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 = breakpoint address
;       r3 = breakpoint number*8
;       r4 -> Breaklist

ClearBreakpoint Entry "r0-r2, r10"

        MOV     r14, #-1                ; Always clear breakpoint entry
        STR     r14, [r4, r3]           ; Only need to zap address field

        LDRB    r0, SysIs32bit
        TEQ     r0, #0
        ADREQ   r0, BreakCodeStart      ; Check that breakpoint was valid
        ADDEQ   r0, r0, r3              ; Each code entry is 8 bytes too
        BLEQ    MakeBranch
        BLNE    MakeMOVPC
        LDR     r14, [r1]
        TEQS    r14, r2
        ADDEQ   r14, r4, #4             ; breakpoint was good, so put data back
        LDREQ   r14, [r14, r3]
        STREQ   r14, [r1]
 [ StrongARM
        ;Do the IMB thingy here
        MOV     r0, #1                  ;Ranged IMB
        MOV     r2, r1
        SWI     XOS_SynchroniseCodeAreas
 ]
        EXIT    EQ

        BL      message_writes
        DCB     "M37", 0                ; "Bad breakpoint at &"
        ALIGN
        MOVVC   r10, r1
;        BICVC   R10,R10,#ARM_CC_Mask
        BLVC    DisplayHexWord
        EXIT    VS
        BL      message_writes
        DCB     "M38", 0                ; "; cleared."
        ALIGN
        SWIVC   XOS_NewLine
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Continue_Code Entry "r6-r11"

        LDR     wp, [r12]

        LDRB    r4, SysIs32bit
        TEQ     r4, #0

        LDR     r14, pc_register        ; Get pc from exception dump
        BICEQ   r14, r14, #ARM_CC_Mask

        ADR     r4, Breaklist           ; Check breakpoint list for pc
        MOV     r3, #(nbreakpoints-1)*8
10      LDR     r1, [r4, r3]
        TEQS    r1, r14
        MOVEQ   r5, #0                  ; [found]
        BEQ     %FT20
        SUBS    r3, r3, #8
        BPL     %BT10

 [ debug
 DLINE "Not continuing from any of current breakpoints"
 ]
        ADR     r0, Registers
        B       %FT90                   ; Continue with this state



20 ; Check branch at breakpoint

        LDRB    r0, SysIs32bit
        TEQ     r0, #0

        ADREQ   r0, BreakCodeStart
        ADDEQ   r0, r0, r3
        BLEQ    MakeBranch
        BLNE    MakeMOVPC
        LDR     r14, [r1]
        TEQ     r14, r2
        BNE     ContinueError1          ; [not kosher]

        BL      message_writes
        DCB     "M39", 0                ; "Continue from breakpoint set at &"
        ALIGN

        MOVVC   r10, r1
;        BICVC   R10,R10,#ARM_CC_Mask
        BLVC    DisplayHexWord
        EXIT    VS

        SWI     XOS_NewLine
        EXIT    VS
        BL      message_writes
        DCB     "M40", 0                ; "Execute out of line? [Y/N] "
        ALIGN

        SWIVC   XOS_Confirm             ; So sexy, huh ? Returns lowercase char
        EXIT    VS                      ; (which for Internationalisation's sake
        BLCS    AckEscape               ; we now ignore, and use the Carry flag
        SWIVC   XOS_NewLine             ; return instead!)
        EXIT    VS

        ;TEQ     r0, #"y"
        EXIT    NE

; Execute instruction out-of-line

        Push    "r1, r3, r4"
        ADR     r8, ExecuteBuffer+12
        ADR     r9, Registers
        LDRB    r0, SysIs32bit
        TEQ     r0, #0
        LDMIA   r9!, {r0-r7}            ; Get + Store first 8 registers
        STMIA   r8!, {r0-r7}
        LDMIA   r9!, {r0-r6}            ; Get next 7 registers
        LDREQ   r14, pc_register
        ANDEQ   r14, r14, #ARM_CC_Mask
        ADR     r7, ExecuteBuffer
        ORREQ   r7, r7, r14             ; dumped pc -> ExecBuffer +mode +flags
        STMIA   r8!, {r0-r7}
        LDRNE   r0, [r9, #4]            ; do CPSR for 32-bit
        STRNE   r0, [r8]
        Pull    "r1, r3, r4"

; See if we can do any better for pc relatives in this version

        ADR     r8, ExecuteBuffer
        ADD     r14, r4, #4
        LDR     r14, [r14, r3]          ; Copy instruction(old data)into buffer
 [ debug
 DREG r14,"Instruction to execute out of line is "
 ]
        AND     r0, r14, #&0F000000     ; If it's a Bxx, correct for new loc'n
        TEQ     r0,      #&0A000000
        LDREQB  r0, SysIs32bit
        TEQEQ   r0, #0                  ; only works for 26-bit, probably
        MOVEQ   r0, r14, LSL #8
        ADDEQ   r0, r0, r1, LSL #6      ; r0 = destination of branch-8
 [ debug
 BNE %FT00
 MOV r0, r0, LSR #6
 DREG r0,"continuing a branch, destination-8 = "
 MOV r0, r0, LSL #6
00
 ]
        SUBEQ   r0, r0, r8, LSL #6
        ANDEQ   r2, r14, #&FF000000     ; Copy condition codes + instruction
        ORREQ   r14, r2, r0, LSR #8     ; Munge back together
 [ debug
 BNE %FT00
 DREG r14,"replacing instruction with "
00
 ]
        STR     r14, ExecuteBuffer

        LDR     r14, =&E51FF004         ; LDR PC,[PC,#-4]
        STR     r14, ExecuteBuffer+4
        ADD     r14, r1, #4             ; address of next instruction in
        STR     r14, ExecuteBuffer+8    ; real program
 [ StrongARM
        ;Best IMB the ExecuteBuffer here
        MOV     r0, #1                  ; Guess what? It's a ranged sync
        ADR     r1, ExecuteBuffer
        ADD     r2, r1, #ExeBufLen
        SWI     XOS_SynchroniseCodeAreas
 ]
        ADR     r0, ExecuteBuffer+12    ; and drop into ...


90 ; Nice simple continuation. r0 -> register state to continue with

 [ :LNOT: No26bitCode
        LDRB    r14, SysIs32bit
        TEQ     r14, #0
        BNE     Continue32

        LDR     r14_svc, [r0, #15*4]
        ANDS    r14_svc, r14_svc, #SVC_mode
        BEQ     %FT95                   ; [user mode harder]

        TEQP    r14_svc, #F_bit + I_bit ; Enter correct mode, ints off
        NOP
        LDMIA   r0, {r0-pc}^            ; Restore int state, r0 never banked


95      MOV     r14_svc, r0
        LDMIA   r14_svc, {r0-r12, r13_usr, r14_usr}^
        NOP
        LDR     r14_svc, [r14_svc, #15*4]
        MOVS    pc, r14_svc             ; Jump to instruction in right mode
 ]

Continue32

        LDR     r14_svc, [r0, #16*4]
        TST     r14_svc, #2_01111
        BEQ     %FT97                   ; [user mode harder]

        TST     r14_svc, #2_11100
        ORREQ   r1, r14_svc, #&10+F32_bit+I32_bit ; convert 26-bit modes to 32-bit form
        ORRNE   r1, r14_svc, #F32_bit+I32_bit ; otherwise, just ints off
        MSR     CPSR_c, r1              ; Enter correct mode, ints off
        MSR     SPSR_cxsf, r14_svc      ; Set up SPSR ready for return
        LDMIA   r0, {r0-pc}^            ; Restore int state, r0 never banked

97
        MRS     r14_svc, CPSR
        ORR     r14_svc, r14_svc, #I32_bit
        MSR     CPSR_c, r14_svc         ; IRQs off for SPSR use

        LDR     r14_svc, [r0, #16*4]
        MSR     SPSR_cxsf, r14_svc      ; Set up SPSR ready for return

        MOV     r14_svc, r0
        LDMIA   r14_svc, {r0-r12, r13_usr, r14_usr}^
        NOP
        LDR     r14_svc, [r14_svc, #15*4]
        MOVS    pc, r14_svc             ; Jump to instruction in right mode



ContinueError1
        MOV     r14, #-1
        STR     r14, [r4, r3]           ; Only need to zap address field
        BL      message_writes
        DCB     "M41", 0                ; "Bad breakpoint at &"
        ALIGN
        MOVVC   r10, r1
        BLVC    DisplayHexWord
        EXIT    VS
        BL      message_writes
        DCB     "M42", 0                ; "; cleared."
        ALIGN
        SWIVC   XOS_NewLine
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Debug_Code

        LDR     wp, [r12]

; .............................................................................

Debug_Code_Common Entry "r6-r11"

10
        BL      message_writes
        DCB     "M43", 0                ; "Debug*"
        ALIGN

        ADRVC   r0, StringBuffer
        MOVVC   r1, #?StringBuffer-1
        MOVVC   r2, #space
        MOVVC   r3, #255
        SWIVC   XOS_ReadLine
        EXIT    VS
        BCS     %FT50

        SWIVC   XOS_CLI

40      BLVS    PrintError
        B       %BT10

50      BL      AckEscape

        TEQ     r1, #0                  ; Any chars read ?
        EXIT    EQ                      ; VSet, return error

        SWI     XOS_NewLine             ; Need to print a NewLine as we
        SETV                            ; didn't terminate the Iine with CR/LF
        B       %BT40

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

AckEscape Entry "r1, r2"

        MOV     r0, #OsByte_AcknowledgeEscape
        SWI     XOS_Byte

        ADRVC   r0, ErrorBlock_Escape
        BLVC    CopyError
        EXIT

        MakeInternatErrorBlock Escape,,Escape

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

PrintError Entry

        ADD     r0, r0, #4
        SWI     XOS_Write0
        SWIVC   XOS_NewLine
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r10 = number to be displayed
;       r2 = starting bit position

; Out   r0 corrupt if error

DisplayHex Entry "r0, r2"

        CMP     r2, #32
        BHS     %FT20
10      MOV     r0, r10, LSR r2
        AND     r0, r0, #15
        CMPS    r0, #9
        ORRLS   r0, r0, #"0"
        ADDHI   r0, r0, #"A"-10
        SWI     XOS_WriteC
        STRVS   r0, [sp]
        EXIT    VS

        SUBS    r2, r2, #4
        BPL     %BT10
        EXIT

20      ; 9 or more digits to display, so we must have received a buffer pointer in r10 instead
        Push    "r10"
        LDR     r10, [r10, #4] ; MSW first
        SUB     r2, r2, #32
        BL      DisplayHex
        LDRVC   r10, [sp]
        LDRVC   r10, [r10] ; then LSW
        MOVVC   r2, #28
        BLVC    DisplayHex
        Pull    "r10"
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   r10 corrupt

DisplayHexWord_R9

        MOV     r10, r9

; .............................................................................

DisplayHexWord Entry "r2"

        MOV     r2, #32-4
        BL      DisplayHex
        EXIT

; .............................................................................

DisplayHexHalfword Entry "r2"

        MOV     r2, #16-4
        BL      DisplayHex
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r9 -> core
;       r2 = number of chars to print
;       r6 = access size

; Out   VS: r0 -> error
;       VC: all preserved

DisplayCharacters Entry "r0-r2, r4-r5, r9", 8  ; "r0-r3, r9"

        ADD     r2, r9, r2
10
        MOV     r0, r9
        MOV     r1, sp
        CMP     r6, #8
        ADREQ   lr, %FT14
        BEQ     do_readD
        CMP     r6, #2
        ADR     lr, %FT15
        BLO     do_readB
        BEQ     do_readH
        BHI     do_readW
        
14      LDMIA   r1, {r1,r5}
15      ADD     r9, r9, r6
        MOV     r4, r1
        MOV     r1, r6
20      AND     r0, r4, #&FF
        CMPS    r0, #delete
        CMPNES  r0, #space-1
        MOVLS   r0, #"."
        SWI     XOS_WriteC
        STRVS   r0, [sp]
        EXIT    VS
        TEQ     r1, #5
        MOVEQ   r4, r5
        MOVNE   r4, r4, LSR #8
        SUBS    r1, r1, #1
        BNE     %BT20

        CMP     r9, r2
        BLO     %BT10
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r4, r5 = data to display
;       r6 = number of chars to print (1-8)

; Out   VS: r0 -> error
;       VC: all preserved

DisplayCharactersR ALTENTRY
        MOV     r9, #0
        MOV     r2, r6
        B       %BT15

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r8 = number to display

DisplayDecimalNumber Entry "r0-r2"

        SUB     sp, sp, #16
        MOV     r0, r8
        MOV     r1, sp
        MOV     r2, #16
        SWI     XOS_BinaryToDecimal

        ADD     r2, r2, r1
10      LDRB    r0, [r1], #1
        SWI     XOS_WriteC
        BVS     %FT90
        CMPS    r1, r2
        BLT     %BT10

90      ADD     sp, sp, #16
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r9 = address to consider

MarkBreakpoints Entry "r2, r3"

        ADR     r2, Breaklist
        MOV     r3, #(nbreakpoints-1)*8
10      LDR     r14, [r2, r3]
        TEQS    r14, r9
        MOVEQ   r0, #"*"                ; [found]
        BEQ     %FT50
        SUBS    r3, r3, #8
        BPL     %BT10
        MOV     r0, #":"                ; [not found]

50      SWI     XOS_WriteI+space
        SWIVC   XOS_WriteC
        SWIVC   XOS_WriteI+space
        EXIT

; .............................................................................

MarkPC ALTENTRY

        LDRB    r0, SysIs32bit
        LDR     r14, pc_register
        TEQ     r0, #0
        BICEQ   r14, r14, #ARM_CC_Mask
        TEQS    r14, r9
        MOVEQ   r0, #"<"                ; [found]
        MOVNE   r0, #":"                ; [not found]

        B       %BT50                   ; Share some code

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Swap old data back into core, remembering our branches

SwapAllBreakpoints EntryS "r1-r5"

        ADR     r4, Breaklist
        ADD     r5, r4, #4              ; r5 -> old data list to index on
        MOV     r3, #(nbreakpoints-1)*8
10      LDR     r1, [r4, r3]
        CMP     r1, #-1
        LDRNE   r2,  [r1]               ; Get our branch
        LDRNE   r14, [r5, r3]           ; Get old data
        STRNE   r2,  [r5, r3]
        STRNE   r14, [r1]
        SUBS    r3, r3, #8
        BPL     %BT10
        EXITS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Code to be relocated into RAM at initialise time

RelocatedCodeStart ROUT

        GBLA    count
count   SETA    0
        WHILE   count < nbreakpoints
        STR     r14, Registers_ROM+14*4 ; Dump current r14 directly
        BL      ClaimBreak              ; pc relative, into RAM code really
count   SETA    count + 1
        WEND

ClaimBreak
        STR     r14, TrapStore_ROM      ; Save id of breakpoint
        ADR     r14, Registers_ROM
        STMIA   r14, {r0-r12}           ; Save registers 0 to 13 in dump area
        STR     r13, [r14, #13*4]       ; R13 saved seperately due to STM {sp} deprecation :(
        LDR     wp, r12Store_ROM
        LDR     pc, JumpStore_ROM       ; Jump to debugger with correct wp

RelocatedCodeEnd ; End of relocated code - next instruction is a patched branch
                 ; to the debugger

 ASSERT RelocatedCodeEnd-RelocatedCodeStart = BreakCodeEnd-BreakCodeStart

TrapStore_ROM   *       (TrapStore - BreakCodeStart) + RelocatedCodeStart
Registers_ROM   *       (Registers - BreakCodeStart) + RelocatedCodeStart
r12Store_ROM    *       (r12Store  - BreakCodeStart) + RelocatedCodeStart
JumpStore_ROM   *       (JumpStore - BreakCodeStart) + RelocatedCodeStart

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; A breakpoint has been hit

BreakTrap ROUT
        MOV     r4, #0
        MRS     r4, CPSR
        TST     r4, #2_11100
        BNE     BreakTrap32

        SWI     XOS_EnterOS             ; And why not too!

        LDR     r1, TrapStore
        AND     r3, r1, #ARM_CC_Mask    ; Save mode and flags
        BIC     r1, r1, #ARM_CC_Mask
        ADR     r0, BreakCodeStart      ; Calculate Breakpoint number we hit
        SUB     r0, r1, r0
        SUB     r0, r0, #8
        ADR     r1, Breaklist
        LDR     r10, [r1, r0]

        LDRB    r2, SysIs32bit
        TEQ     r2, #0

        ORREQ   r10, r10, r3            ; recombine pc+psr for a 26-bit dump
        STREQ   r10, pc_register

        STRNE   r10, pc_register        ; separate pc+psr for a 32-bit dump
        STRNE   r4, psr_register

        BIC     R10,R10,#ARM_CC_Mask

BreakTrapCommonExit
        BL      message_writes
        DCB     "M44", 0
        ALIGN

        BLVC    DisplayHexWord          ; Tee hee, nowhere to go if VS! <<<
        SWIVC   XOS_NewLine

        BLVC    ShowRegs_Code_Common
        BLVC    Debug_Code_Common

        SWI     XOS_NewLine
        SWI     XOS_Exit


; When we're hit in a 32-bit mode
BreakTrap32

        SWI     XOS_EnterOS             ; And why not too!

        LDR     r1, TrapStore
        ADR     r0, BreakCodeStart      ; Calculate Breakpoint number we hit
        SUB     r0, r1, r0
        SUB     r0, r0, #8
        ADR     r1, Breaklist
        LDR     r10, [r1, r0]

        LDRB    r2, SysIs32bit
        TEQ     r2, #0

        BICEQ   r2, r10, #ARM_CC_Mask   ; keep r10 whole for message
        ANDEQ   r4, r4, #ARM_CC_Mask    ; although we can't put it in the dump
        ORREQ   r2, r2, r4
        STREQ   r2, pc_register         ; combine pc+psr for a 26-bit dump

        STRNE   r10, pc_register        ; separate pc+psr for a 32-bit dump
        STRNE   r4, psr_register

        B       BreakTrapCommonExit


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 -> string
;       r2 -> error to generate if naff syntax (ie. no p1, trailing op or junk)

GetCommandParms_R0

        MOV     r1, r0

; .............................................................................
; In    r1 -> string
;       r2 -> error to generate if naff syntax (ie. no p1, trailing op or junk)
;       r10 = flags: Command_64bitData => arg2 (if present) must be returned in buffer
;       r11 = buffer to hold 64-bit arg2 data if found

; Decodes string of form <addr|reg> [[+|-] <addr|reg>]

; Out   r9 = parm1
;       r8 = parm state
;       r7 = parm2

hasparm         *       2_001
parmfollowed    *       2_010
secondparm      *       2_100

; a         -> a, X
; a b       -> a, b
; a + b     -> a, a+b
; a - b     -> a-b, a
; a + b + c -> a+b, a+b+c
; a - b + c -> a-b, a-b+c

GetCommandParms Entry "r2"

 [ debug
 DSTRING r1, "Command tail "
        BL      %FT00
 DREG r9, "p1 ",cc
 DREG r7, " p2 ",cc
 DREG r8, " state ",,Byte
        EXIT

00
        Entry
 ]

        MOV     r10, r10, LSL #1        ; only the last parameter can be 64-bit
        BL      ReadFirstParm           ; r7 := parm
        EXIT    VS

        TST     r8, #hasparm
        BEQ     %FT99                   ; [no parm1, so it's bad news]

        MOV     r9, r7                  ; r9 := parm1

        TST     r8, #parmfollowed
        EXIT    EQ                      ; [no parm2]

        ORR     r8, r8, #secondparm

        TEQ     r0, #"+"
        TEQNE   r0, #"-"
        BNE     %FT50

        ORR     r8, r8, r0, LSL #8      ; has '+' or '-', so skip it
        ADD     r1, r1, #1

50
        MOV     r10, r10, LSR #1        ; restore the Command_64bitData flag if appropriate
        BL      ReadParm                ; r7 := parm2
        EXIT    VS

        TST     r8, #hasparm            ; [no second parm when there should be]
        BEQ     %FT99                   ; [ie. after operator]

        MOVS    r14, r8, LSR #8
        BEQ     %FT80                   ; [no operator]

        TEQ     r14, #"+"               ; addition ?
        ADDEQ   r7, r9, r7              ; -> a, a+b
        SUBNE   r14, r9, r7             ; subtraction then
        MOVNE   r7, r9
        MOVNE   r9, r14                 ; -> a-b, a

        TST     r8, #parmfollowed
        EXIT    EQ                      ; [no second operator]

        TEQ     r0, #"+"                ; so we can *mi base -offset1 +offset2
        BNE     %FT99                   ;        or *mi base +offset1 +offset2

        Push    "r7, r14"               ; save r7, first operator
        ADD     r1, r1, #1              ; skip '+'
        BL      ReadParm                ; r7 := parm3
        Pull    "r1, r14"
        EXIT    VS

        TEQ     r14, #"+"               ; it does work, honest ...
        MOVEQ   r9, r1                  ; a, a+b -> a+b, a+b+c
        ADD     r7, r9, r7              ; a-b, a -> a-b, a-b+c

                                        ; and fall into ...

80      TST     r8, #parmfollowed
        EXIT    EQ                      ; [no trailing non-blank muck]


99      LDR     r0, [sp]
        SETV
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 -> string
;       r10 = flags: Command_64bitData => arg2 (if present) must be returned in buffer
;       r11 = buffer to hold 64-bit arg2 data if found

; Out   r7 = value of parm
;       r8 = parm state
;       r0 = next ~space char

ReadFirstParm ROUT

        MOV     r8, #0                  ; nowt so far

; .............................................................................

ReadParm Entry "r2"

 [ debug
 DSTRING r1, "ReadParm "
        BL      %FT00
 DREG r7, "parm ",cc
 DREG r8, ", state "
        EXIT

00
        Entry
 ]
        BIC     r8, r8, #hasparm + parmfollowed ; in all cases

        BL      SkipSpaces
        EXIT    LO

        ORR     r0, r0, #&20            ; Cheap and nasty lowercase

        TEQ     r0, #"r"
        BEQ     %FT50                   ; register

        LDRB    r7, SysIs32bit

        TEQ     r0, #"p"
        BNE     %FT20
        MOV     r0, #"c"                ; Expect 'c'
        TEQ     r7, #0
        LDR     r7, pc_register
        BICEQ   r7, r7, #ARM_CC_Mask    ; knock off psr bits for "pc" but not for "r15"
        B       %FT60

20      TEQ     r0, #"l"
        BNE     %FT30
        MOV     r0, #"r"                ; Expect 'r'
        TEQ     r7, #0
        LDR     r7, Registers + 14*4
        BICEQ   r7, r7, #ARM_CC_Mask    ; knock off psr bits for "lr" but not for "r14"
        B       %FT60

30      TEQ     r0, #"s"
        MOVEQ   r0, #"p"                ; Expect 'p'
        LDREQ   r7, Registers + 13*4
        BEQ     %FT60

        TEQ     r0, #"w"
        MOVEQ   r0, #"p"                ; Expect 'p'
        LDREQ   r7, Registers + 12*4
        BEQ     %FT60


40
        TST     r10, #Command_64bitData
        BNE     %FA47
        MOV     r0, #16                 ; allow any term, read hex
        SWI     XOS_ReadUnsigned
        MOVVC   r7, r2

45      EXIT    VS

        BL      SkipSpaces
        ORR     r8, r8, #hasparm
        ORRCS   r8, r8, #parmfollowed
        EXIT

47      Push    "r1,r3,r4"
        MOV     r0, #16
        ORR     r0, r0, #1 :SHL: 28
        LDR     r4, =&45444957
        SWI     XOS_ReadUnsigned        ; do a 64-bit read to r2,r3
        TST     r4, #1 :SHL: 28         ; old OS with no 64-bit read?
        MOVEQ   r0, #16
        LDREQ   r1, [sp]
        MOVEQ   r3, #0
        SWIEQ   XOS_ReadUnsigned        ; then try again, reading a 32-bit number
        STMIA   r11, {r2,r3}
        MOV     r7, #0
        ADD     sp, sp, #4
        Pull    "r3,r4"
        B       %BA45


50      ADD     r1, r1, #1
        MOV     r0, #(2_001 :SHL: 29) + 10 ; allow any term, read decimal, rest
        MOV     r2, #15
        SWI     XOS_ReadUnsigned

        ADRVC   r14, Registers
        LDRVC   r7, [r14, r2, LSL #2]   ; load register n from dump
        TST     r10, #Command_64bitData
        MOV     lr, #0
        STMNEIA r11, {r7,lr}
        B       %BA45


60      LDRB    r14, [r1, #1]
        ORR     r14, r14, #&20          ; Cheap and nasty lowercase
        TEQ     r14, r0                 ; Expected ?
        BNE     %BT40                   ; give error from ReadUnsniged

        TST     r10, #Command_64bitData
        MOV     lr, #0
        STMNEIA r11, {r7,lr}
        ADD     r1, r1, #2              ; skip 'pc'
        B       %BA45                   ; and skip spaces

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 -> string
;       r0 -> error to generate if parmfollowed
;       r10 = flags: Command_64bitData => arg2 (if present) must be returned in buffer
;       r11 = buffer to hold 64-bit arg2 data if found

; Out   r7, r8 from ReadFirstParm

ReadOneParm Entry "r0"

        BL      ReadFirstParm           ; r7 := parm
        EXIT    VS

        TST     r8, #parmfollowed
        LDRNE   r0, [sp]
        SETV    NE
        STRVS   r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 -> string

; Out   r0 = first non-space char
;       flags from CMP r0, #space for eol detection. (LO -> r0 = CtrlChar)

SkipSpaces ROUT

10      LDRB    r0, [r1], #1
        CMPS    r0, #space
        BEQ     %BT10
        SUB     r1, r1, #1      ; Leave r1 -> ~space
        MOV     pc, lr          ; r0 = first ~space

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = branch destination
;       r1 = branch location (ie. where it is executed)

; Out   r2 = branch instruction

MakeBranch ROUT

        SUB     r2, r0, r1
        SUB     r2, r2, #8
        MOV     r2, r2, ASR #2
        BIC     r2, r2, #&FF000000
        ORR     r2, r2, #&EA000000      ; BAL instruction
 [ debug
 DREG r0,"Branch instruction to get to ",cc
 DREG r1," from ",cc
 DREG r2," is "
 ]
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r3 = breakpoint number*8

; Out   r2 = instruction
MakeMOVPC ROUT
        LDR     r2, MOVPCInstr
        ADD     r2, r2, r3, LSR #2
        MOV     pc, lr


lookup_r10 Entry r0-r7
        BL      open_messagefile
        STRVS   r0, [sp]
        EXIT    VS
        MOV     r1, r10
        ADR     r0, MessageFile_Block
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_Lookup
        STRVS   r0, [sp]
        EXIT    VS
        MOV     r10, r2
        EXIT

message_writes
        Entry   r0-r7
        SUB     r0, lr, pc              ; processor independent
        ADD     r0, pc, r0              ; extraction of pc from lr
        SUB     r0, r0, #4
        MOV     r2, r0
10      LDRB    r1, [r2], #1
        TEQS    r1, #0
        BNE     %B10
        SUB     r2, r2, r0
        ADD     r2, r2, #3
        BIC     r2, r2, #3
        ADD     lr, lr, r2
        STR     lr, [sp, #8 * 4]
        B       message_write0_tail

message_write0 Entry r0-r7
message_write0_tail
        BL      open_messagefile
        STRVS   r0, [sp]
        EXIT    VS
        MOV     r1, r0
        ADR     r0, MessageFile_Block
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_Lookup
        STRVS   r0, [sp]
        EXIT    VS
10      LDRB    r0, [r2], #1
        CMPS    r0, #32
        SWIHS   XOS_WriteC
        STRVS   r0, [sp]
        EXIT    VS
        BCS     %B10
        EXIT

CopyErrorP1 Entry r1-r7
        BL      open_messagefile
        EXIT    VS
        ADRL    R4,Debug_Title
        B       CopyError0

CopyErrorR2
        MOV     R0,R2

CopyError Entry r1-r7
        BL      open_messagefile
        EXIT    VS
        MOV     R4, #0
CopyError0
        ADR     R1, MessageFile_Block
        ADR     R2, StringBuffer
        MOV     R3, #?StringBuffer
        MOV     R5, #0
        MOV     R6, #0
        MOV     R7, #0
        SWI     XMessageTrans_ErrorLookup
        EXIT

message_filename
        DCB     "Resources:$.Resources.Debugger.Messages", 0

        ALIGN

open_messagefile Entry r0-r2
        LDR     r0, MessageFile_Open
        CMPS    r0, #0                  ; clears V
        EXIT    NE
        ADR     R0, MessageFile_Block
        ADR     R1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        STRVS   r0, [sp]
        EXIT    VS
        MOV     r0, #1
        STR     r0, MessageFile_Open
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    [ SupportARMV 
ShowVFPRegs_Code ROUT

        Entry

        LDR     wp, [r12]

        ; Check arguments
        MOV     r1, r0
        BL      SkipSpaces
        BLO     %FT50

        ADD     r1, r1, #1
        LDRB    r2, [r1], #1
        BIC     r0, r0, #32
        CMP     r2, #32
        BGT     %FT99
        TEQ     r0, #"A"                ; A -> at
        BEQ     %FT10
        TEQ     r0, #"E"                ; E -> exception
        BEQ     %FT50
        TEQ     r0, #"C"                ; C -> current
        BNE     %FT99
        SWI     XVFPSupport_ActiveContext
        MOVVC   r1, r0
        BLVC    ShowThisVFPContext
        EXIT

10
        ; Show context at specific address
        BL      SkipSpaces
        BLO     %FT99
        MOV     r0, #16
        SWI     XOS_ReadUnsigned
        MOVVC   r0, r2
        MOVVC   r1, r2
        BLVC    ShowThisVFPContext
        EXIT

50
        ; Show exception context
        MOV     r0, #VFPSupport_ExceptionDump_GetDump+VFPSupport_ExceptionDump_GetContext
        SWI     XVFPSupport_ExceptionDump
        EXIT    VS
        MOV     r2, r0                  ; Remember in case of error
        BL      ShowThisVFPContext
        ; Preseve any error over free call
        SavePSR r3
        MOV     r4, r0
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        RestPSR r3
        MOV     r0, r4
        EXIT

99      ADR     r0, ShowVFPRegs_Error
        BL      CopyError
        EXIT


ShowVFPRegs_Error
        DCD     ErrorNumber_Syntax
        DCB     "SDBGSVR", 0
        ALIGN


ShowThisVFPContext ROUT
        ; r0 = context
        ; r1 = address to say it came from
        Entry   "r6-r11"

        MOV     r6, r0
        
        BL      message_writes
        DCB     "V00", 0                ; "VFP context &"
        ALIGN

        MOVVC   r10, r1
        BLVC    DisplayHexWord
        SWIVC   XOS_NewLine

        MOVVC   r1, #VFPSupport_ExamineContext_Serialise
        SWIVC   XVFPSupport_ExamineContext
        EXIT    VS

        MOV     r11, r1

        BL      message_writes
        DCB     "V01", 0                ; "Context flags &"
        ALIGN
        MOVVC   r10, r0
        BLVC    DisplayHexWord
        SWIVC   XOS_NewLine
        EXIT    VS

        ; Parse the dump descriptor block
10
        LDR     r0, [r3], #4
        CMP     r0, #-1
        EXIT    EQ
        MOV     r4, r0, LSR #16
        BIC     r0, r0, r4, LSL #16
        CMP     r0, #VFPSupport_Field_FPSCR
        BEQ     %FT20
        CMP     r0, #VFPSupport_Field_FPEXC
        BEQ     %FT30
        CMP     r0, #VFPSupport_Field_FPINST
        ADREQ   r0, fpinst
        BEQ     %FT40
        CMP     r0, #VFPSupport_Field_FPINST2
        ADREQ   r0, fpinst2
        BEQ     %FT40
        CMP     r0, #VFPSupport_Field_FSTMX
        BEQ     %FT50
        CMP     r0, #VFPSupport_Field_RegDump
        BEQ     %FT60
        ; Some unknown field - skip it
        B       %BT10

20
        ; FPSCR display
        ADREQ   r0, FPSCRList
        SWI     XOS_Write0
        LDRVC   r10, [r6, r4]
        BLVC    DisplayHexWord
        EXIT    VS
        MOV     r4, r0
        BL      ShowVFPFlags
        EXIT    VS

        ; Show rounding mode
        ANDVC   r0, r10, #FPSCR_RMODE_MASK
        ADRVC   r1, RMODEList
        ADDVC   r0, r1, r0, LSR #FPSCR_RMODE_SHIFT-2
        BLVC    message_write0
        EXIT    VS
        ; Show vector length & stride
        BL      message_writes
        DCB     "V09", 0                ; "Vector length "
        ALIGN
        EXIT    VS
      [ NoARMT2
        AND     r0, r10, #FPSCR_LEN_MASK
        MOV     r0, r0, LSR #FPSCR_LEN_SHIFT
      |
        ASSERT  FPSCR_LEN_MASK = (7<<FPSCR_LEN_SHIFT)
        UBFX    r0, r10, #FPSCR_LEN_SHIFT, #3
      ]
        AND     r1, r10, #FPSCR_STRIDE_MASK
        ; The only valid encodings are 0 and 3, corresponding to stride 1 and 2
        MOVS    r1, r1, LSR #FPSCR_STRIDE_SHIFT
        TEQNE   r1, #3
        BNE     %FT25
        ; Nonzero stride with zero length is invalid
        TEQ     r1, #3
        TEQEQ   r0, #0
        BEQ     %FT25
        ; Nonzero stride with length field > 3 is invalid
        CMP     r1, #0
        CMPHI   r0, #3
        BHI     %FT25
        ; For double precision operations a nonzero stride with length field > 1 is invalid, but we can't check for that as we don't know what the user's doing
        ADD     r0, r0, #"1"            ; Convert to actual length
        SWI     XOS_WriteC
        EXIT    VS
        BL      message_writes
        DCB     "V10", 0                ; " stride "
        ALIGN
        EORVC   r0, r1, #1+"0"          ; 0 -> "1", 3 -> "2"
        SWIVC   XOS_WriteC
        SWIVC   XOS_WriteI+","

24
        ; Remainder can be handled by ShowVFPFlags
        BLVC    ShowVFPFlags
        BVC     %BT10
        EXIT

25
        BL      message_writes
        DCB     "V02", 0
        ALIGN
        B       %BT24

30
        ; FPEXC display
        ADREQ   r0, FPEXCList
        SWI     XOS_Write0
        LDRVC   r10, [r6, r4]
        BLVC    DisplayHexWord
        EXIT    VS
        MOV     r4, r0
        BL      ShowVFPFlags
        EXIT    VS

        ; Show remaining iterations, but only if field is valid
        ; DEX+VV set or EX set
        TST     r10, #FPEXC_DEX
        TSTNE   r10, #FPEXC_VV
        TSTEQ   r10, #FPEXC_EX
        BEQ     %FT35

        BL      message_writes
        DCB     "V11", 0                ; "Remaining iterations: "
        ALIGN
      [ NoARMT2
        AND     r0, r10, #FPEXC_VECITR_MASK
        MOV     r0, r0, LSR #FPEXC_VECITR_SHIFT
      |
        ASSERT  FPEXC_VECITR_MASK = 7<<FPEXC_VECITR_SHIFT
        UBFX    r0, r10, #FPEXC_VECITR_SHIFT, #3
      ]
        ADD     r0, r0, #"1"
        ASSERT  ("0" :AND: 8)=0
        BIC     r0, r0, #8
        SWI     XOS_WriteC
        SWIVC   XOS_NewLine
        EXIT    VS

35
        BL      ShowVFPFlags
        BVC     %BT10
        EXIT        

40
        SWI     XOS_Write0
        LDRVC   r10, [r6, r4]
        BLVC    DisplayHexWord
        SWIVC   XOS_WriteI+32
        ; The contents of the FPINST registers should be instructions, so let's
        ; be useful and show the disassembly
        MOVVC   r0, r10
        MOVVC   r1, #0
        SWIVC   XDebugger_Disassemble
        MOVVC   r0, r1
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        BVC     %BT10
        EXIT

50
        BL      message_writes
        DCB     "V03", 0                ; "FSTMX format word = "
        ALIGN
        LDRVC   r10, [r6, r4]
        BLVC    DisplayHexWord
        SWIVC   XOS_NewLine
        BVC     %BT10
        EXIT

60
        BL      message_writes
        DCB     "M17", 0
        ALIGN
        ADDVC   r10, r6, r4
        BLVC    DisplayHexWord
        EXIT    VS
        BL      message_writes
        DCB     "M18", 0
        ALIGN
        EXIT    VS
        ; Display register dump as doubleword registers, two columns 
        MOV     r0, #0
        MOV     r1, r10
61
        SWI     XOS_NewLine
62
        EXIT    VS
        CMP     r0, r11
        BNE     %FT63
        TST     r0, #1
        SWINE   XOS_NewLine
        EXIT    VS
        B       %BT10
63
        SWI     XOS_WriteI+"D"
        MOVVC   r8, r0
        BLVC    DisplayDecimalNumber
        EXIT    VS
        CMP     r0, #10
        SWILT   XOS_WriteI+32
        EXIT    VS
        SWI     XOS_WriteS
        DCB     " = &", 0
        ALIGN
        LDR     r10, [r1, #4]
        BL      DisplayHexWord
        LDR     r10, [r1], #8
        BLVC    DisplayHexWord
        EXIT    VS
        ADD     r0, r0, #1
        TST     r0, #1
        BEQ     %BT61
        SWI     XOS_WriteI+32
        B       %BT62

ShowVFPFlags    ROUT
        ; In: R4 -> flags list
        ;     R10 = value
        ; Out: R0 = corrupt or error
        ;      R4 updated
        Entry   "r1,r2,r8"
        MOV     r1, #1
10
        LDRB    r2, [r4], #1
        TEQ     r2, #255
        EXIT    EQ
        TEQ     r2, #254
        BEQ     %FT30
        TEQ     r2, #253
        BEQ     %FT40
20
        LDRB    r0, [r4], #1
        TEQ     r0, #0
        BEQ     %BT10
        TST     r10, r1, LSL r2
        ORREQ   r0, r0, #32
        SWI     XOS_WriteC
        BVC     %BT20
        EXIT

30
        MOV     r0, r4
        BL      message_write0
        ADDVC   r4, r4, #4
        BVC     %BT10
        EXIT

40
        SWI     XOS_NewLine
        BVC     %BT10
        EXIT

        MACRO
        VFPRegBit $bits, $name
        LCLA    bit
        LCLA    mask
mask    SETA    $bits
count   SETA    0
        WHILE   (mask :AND: 1)=0 :LAND: (mask > 0)
mask    SETA    mask :SHR: 1
count   SETA    count + 1
        WEND
        DCB     count
        DCB     "$name"
        DCB     0
        MEND                

FPSCRList
        DCB "FPSCR = ", 0
        DCB 254, "V12", 0 ; "Flags:"
        VFPRegBit FPSCR_N, " N"
        VFPRegBit FPSCR_Z, "Z"
        VFPRegBit FPSCR_C, "C"
        VFPRegBit FPSCR_V, "V"
        VFPRegBit FPSCR_QC, "Q"
        DCB 253
        DCB 254, "V13", 0 ; "Options: "
        DCB 255
        
        VFPRegBit FPSCR_AHP, " AHP"
        VFPRegBit FPSCR_DN, " DN"
        VFPRegBit FPSCR_FZ, " FZ"
        DCB 253
        DCB 254, "V14", 0 ; "Enabled exceptions:"
        VFPRegBit FPSCR_IDE, " ID"
        VFPRegBit FPSCR_IXE, " IX"
        VFPRegBit FPSCR_UFE, " UF"
        VFPRegBit FPSCR_OFE, " OF"
        VFPRegBit FPSCR_DZE, " DZ"
        VFPRegBit FPSCR_IOE, " IO"
        DCB 253
        DCB 254, "V15", 0 ; "Cumulative exceptions:"
        VFPRegBit FPSCR_IDC, " ID"
        VFPRegBit FPSCR_IXC, " IX"
        VFPRegBit FPSCR_UFC, " UF"
        VFPRegBit FPSCR_OFC, " OF"
        VFPRegBit FPSCR_DZC, " DZ"
        VFPRegBit FPSCR_IOC, " IO"
        DCB 253
        DCB 255
        ALIGN

FPEXCList
        DCB "FPEXC = ", 0
        DCB 254, "V12", 0 ; "Flags:"
        VFPRegBit FPEXC_EX, " EX"
        VFPRegBit FPEXC_EN, " EN"
        VFPRegBit FPEXC_DEX, " DEX"
        VFPRegBit FPEXC_FP2V, " FP2V"
        VFPRegBit FPEXC_VV, " VV"
        VFPRegBit FPEXC_TFV, " TFV"
        DCB 253
        DCB 255

        DCB 254, "V16", 0 ; "Pending/potential exceptions:"
        VFPRegBit FPEXC_IDF, " ID"
        VFPRegBit FPEXC_IXF, " IX"
        VFPRegBit FPEXC_UFF, " UF"
        VFPRegBit FPEXC_OFF, " OF"
        VFPRegBit FPEXC_DZF, " DZ"
        VFPRegBit FPEXC_IOF, " IO"
        DCB 253
        DCB 255
        ALIGN

RMODEList
        DCB "V04", 0
        DCB "V05", 0
        DCB "V06", 0
        DCB "V07", 0
        ALIGN

fpinst  DCB "FPINST  = ", 0
        ALIGN
fpinst2 DCB "FPINST2 = ", 0
        ALIGN
    ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Where_Error
        DCD     ErrorNumber_Syntax
        DCB     "SDBGWHR", 0

Where_UMod
        DCB     "UtilityModule", 0
        ALIGN

Where_Code Entry "r6-r11"

        LDR     wp, [r12]

        MOV     r1, r0
        ADR     r0, Where_Error
        MOV     r10, #0                 ; arguments can only be 32-bit
        BL      ReadOneParm             ; r7 := parm, r8 state
        BLVS    CopyError
        EXIT    VS

        TST     r8, #hasparm
        LDREQ   r7, pc_register         ; Use exception PC if no parms
        LDREQB  r0, SysIs32bit
        TEQEQ   r0, #0
        BICEQ   r7, r7, #ARM_CC_Mask

        BL      message_writes
        DCB     "M15", 0                ; "Address &"
        ALIGN

        MOVVC   r10, r7
        BLVC    DisplayHexWord
        SWIVC   XOS_WriteI+space
        EXIT    VS

        BL      Where_Util
        EXIT    VS

        CMP     r7, #-1
        BNE     %FT85
        ; Say "is <somewhere vague>"
        BL      message_write0
        B       %FT88
85
        ; Say "is at offset &xx in <some area> 'detail'"
        ; => r0 -> area name token
        ;    r7 = offset
        ;    r8 -> detail string
        BL      message_writes
        DCB     "M21", 0
        ALIGN
        MOVVC   r10, r7
        BLVC    DisplayHexWord
        SWIVC   OS_WriteI+space
        BLVC    message_write0
        TEQ     r8, #0                  ; NULL details? V preserved
        BEQ     %FT88

        SWIVC   OS_WriteI+space
        SWIVC   OS_WriteI+"'"
        MOVVC   r0, r8
        SWIVC   OS_Write0
        SWIVC   OS_WriteI+"'"
88
        SWIVC   OS_NewLine
        EXIT


; In:
; r7 = address
; Out:
; r0 -> area name token
; r7 = offset
; r8 -> detail string
; offset is -1 if unsure of location
Where_Util      ROUT
        Entry "r1-r6,r9-r11"
        MOV     r8, #0                  ; No details

        ; Applications sometimes go pop
        MOV     r0, #-1
        SWI     XOS_ReadDynamicArea
        ADD     r2, r2, r0
        CMP     r7, r0
        CMPCS   r2, r7
        SUBHI   r7, r7, r0              ; Offset
        ADRHI   r0, Where_AppSlot       ; In the app slot
        BHI     %FT85

        ; Anything in the MB below UtilityModule is Kernel (might include HAL)
        MOV     r0, #ModHandReason_LookupName
        ADR     r1, Where_UMod
        SWI     XOS_Module
        MOV     r9, r3, LSR #20
        CMP     r7, r9, LSL #20
        CMPCS   r3, r7
        SUBHI   r7, r7, r9, LSL #20
        ADRHI   r0, Where_Kernel        ; In the kernel
        BHI     %FT85

        ; Scan the module chain
        MOV     r1, #0
        MOV     r2, #0
10
        MOV     r0, #ModHandReason_GetNames
        SWI     XOS_Module
        BVS     %FT20

        LDR     r0, [r3, #-4]           ; Load the module size word
        SUB     r0, r0, #4              ; Size word includes itself. Remove that.
        ADD     r0, r3, r0
        CMP     r7, r3
        CMPCS   r0, r7
        ADRHI   r0, Where_Module        ; Is within that module
        SUBHI   r7, r7, r3              ; Offset
        LDRHI   r8, [r3, #Module_TitleStr] 
        ADDHI   r8, r8, r3              ; Detail
        BHI     %FT85
        B       %BT10
20
        ; Perhaps in ROM in a gap not occupied by a module
        MOV     r3, #8
        ORR     r0, r3, #3:SHL:8        ; ROM
        SWI     XOS_Memory
        TEQ     r1, #0
        ORREQ   r0, r3, #5:SHL:8        ; else Soft ROM
        SWIEQ   XOS_Memory

        MUL     r3, r1, r2              ; Amount of ROM
        ADD     r3, r3, r9, LSL #20     ; End of ROM
        CMP     r7, r9, LSL #20
        CMPCS   r3, r7
        SUBHI   r7, r7, r9, LSL #20
        ADRHI   r0, Where_ROM           ; Somewhere in ROM
        BHI     %FT85
30
        ; Dynamic and system areas
        MOV     r0, #20                 ; If this subreason's not supported then
        MOV     r1, r7                  ; it's just a more vague report
        SWI     XOS_DynamicArea
        BVS     %FT40

        CMP     r0, #1                  ; Dynamic area or system area?
        BHI     %FT40

        ADREQ   r0, Where_SysWksp       ; In some system workspace
        BEQ     %FT80

        MOV     r10, r7
        MOV     r0, #2
        SWI     XOS_DynamicArea
        EXIT    VS

        SUB     r7, r10, r3             ; Offset
                                        ; Detail in r8 already
        ADR     r0, Where_DynArea       ; In a dynamic area
        B       %FT85
40
        ; Does is exist at all?
        MOV     r0, r7
        ADD     r1, r7, #4
        SWI     XOS_ValidateAddress
        ADRCS   r0, Where_NotMapped     ; C set, is not RAM
        ADRCC   r0, Where_Unknown       ; Somewhere, but not sure where
80
        MOV     r7, #-1
        MOV     r8, #0
85
        EXIT

Where_Unknown   DCB     "M28", 0 ; vague
Where_NotMapped DCB     "M30", 0 ; vague
Where_ROM       DCB     "M34", 0 ; offset
Where_Module    DCB     "M47", 0 ; offset+detail
Where_AppSlot   DCB     "M88", 0 ; offset
Where_DynArea   DCB     "M89", 0 ; offset+detail
Where_Kernel    DCB     "M95", 0 ; offset
Where_SysWksp   DCB     "M96", 0 ; vague
        ALIGN

; In:
; r0 = address
; r1 -> result buffer (area name, offset, detail string)
        EXPORT  Where_Util_FromC
Where_Util_FromC ROUT
        Entry   "r1,r7,r8,r10"
        SUB     r12, sl, #:INDEX:CRelocOffset
        MOV     r7, r0
        BL      Where_Util
        ADDVS   r0, r0, #4
        MOVVS   r7, #-1
        MOVVS   r8, #0
        FRAMLDR r1
        BVS     %FT50
        MOVS    r10, r0
        BEQ     %FT50
        BL      lookup_r10
        ADDVS   r10, r0, #4 
        MOV     r0, r10
50        
        STMIA   r1, {r0,r7,r8}
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


        LTORG

      [ standalone
declareresourcefsfiles
        Entry "r0"

        BL      Resources
        SWI     XResourceFS_RegisterFiles   ; ignore errors
        CLRV
        EXIT

        IMPORT  Resources
      ]

 [ debug
        InsertDebugRoutines
 ]

        GET     ARM.s
        GET     ARMv6.s
        GET     FP.s
      [ UseCVFPNEON
        GET     CGlue.s
      |
        GET     VFP.s
      ]
        GET     CirrusDSP.s
        GET     Piccolo.s
        GET     XScaleDSP.s
        GET     Thumb.s
        GET     CodeVar.s
        GET     ExceptionDump.s

        END
