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
; VFP/SIMD Assembler
; (C)2011 TBA Software
; 0.02 - 5th July 2011 - Alan Peters

; Known issues:
;   register quad instead of double/single eg Q0-Q1 instead of D0-D3 or S0-S7
;   AL condition code option not supported on all SIMD unconditional instructions
;   Writeback flag option on variations of VLDx/VSTx with offset register specified

; Potential enhancements:
;   possibly syntax tables could be simplified based on A7.4 (ARM p290)
;     however detailed encoding variations still remain as this is only structural
;     and could end up creating many more bitfield varations instead (!)
;   multiple data-type syntax variations
;     could allow register number immediates without the <type># prefix

 [ :DEF: VFPAssembler

; ************************
; ** Import Data Macros **
; ************************

        INCLUDE ./VFPMacros.hdr
        INCLUDE ./VFPData.s

        GBLL    EnableVFPDebug
EnableVFPDebug  SETL {FALSE}

; ************************
; ** Define Code Macros **
; ************************
; (see end of code for get of VFPMacro / VFPData for defining data-tables)

; ** Make register into a Ptr **
; (add on VFPtable to the value present)

        MACRO
$Label  VFP_Ptr $Reg,$Temp
$Label  LDR     $Temp,[R12,#VFPWS_Tables]
        ADD     $Reg,$Reg,$Temp
        MEND

; ** Find Non Space Character **

        MACRO
$Label  VFP_FindAEChar $Reg
$Label
1       LDRB    $Reg,[AELINE],#1
        TEQ     $Reg,#" "
        BEQ     %b1
        SUB     AELINE,AELINE,#1
        MEND

        MACRO
$Label  VFP_FindAEChar1 $Reg
$Label
1       LDRB    $Reg,[AELINE],#1
        TEQ     $Reg,#" "
        BEQ     %b1
        MEND

        ; LDRH $dest,[$base,#$offset]
        ; optional TEQ $dest,#0 (will corrupt C)
        MACRO
$Label  VFP_LDRH$cond $dest,$base,$offset,$temp,$teq0
$Label
        ASSERT $dest <> $temp
        ASSERT ("$teq0" = "") :LOR: ("$teq0" = "S")
  [ NoARMv4
        ; We can't rely on ARMv4 features (i.e. LDRH)
        ; Use LDRB for simplicity
        LDRB$cond   $temp, [$base, #$offset+1]
        LDRB$cond   $dest, [$base, #$offset]
        ORR$cond.$teq0 $dest, $dest, $temp, LSL #8
  |
        ; We can just use LDRH
        LDR$cond.H  $dest, [$base, #$offset]
      [ "$teq0" <> ""
        TEQ$cond    $dest, #0
      ]
  ]
        MEND       

; ** Generate Error **
; $Number  = error number
; $Message = error message text

        MACRO
$Label  VFP_Error $Number,$Message
$Label  ADD     R13,R12,#VFPWS
        LDMFD   R13!,{R0-R12,R14}
        ADR     R14,%FT10
        B       MSGERR
10      DCD     $Number
        DCB     "$Message"
        DCB     0
        ALIGN
        MEND

        MACRO
$Label  VFP_BASICError $Error
$Label  ADD     R13,R12,#VFPWS
        LDMFD   R13!,{R0-R12,R14}
        B       $Error
        MEND

      [ EnableVFPDebug
        MACRO
$Label  VFP_Debug $Message
$Label  STMFD   R13!,{R0-R12,R14}
        ADR     R0,%f11
        SWI     XOS_Write0
        B       %f12
11      DCB     "$Message"
        DCB     13,10,0
        ALIGN
12      LDMFD   R13!,{R0-R12,R14}
        MEND

        MACRO
$Label  VFP_DebugStr $Reg
$Label  STMFD   R13!,{R0-R12,R14}
        MOV     R0,$Reg
        SWI     XOS_Write0
        SWI     XOS_NewLine
        LDMFD   R13!,{R0-R12,R14}
        MEND

        MACRO
$Label  VFP_DebugReg $Reg
$Label  STMFD   R13!,{R0-R12,R14}
        MOV     R0,$Reg
        ADD     R1,R12,#VFPWS_Debug
        MOV     R2,#16
        SWI     XOS_ConvertHex8
        SWI     XOS_Write0
        SWI     XOS_NewLine
        LDMFD   R13!,{R0-R12,R14}
        MEND

        MACRO
$Label  VFP_DebugChar $Reg
$Label  STMFD   R13!,{R0-R12,R14}
        MOV     R0,$Reg
        SWI     XOS_WriteC
        SWI     XOS_NewLine
        LDMFD   R13!,{R0-R12,R14}
        MEND
      |
        MACRO
$Label  VFP_Debug $Message
$Label
        MEND

        MACRO
$Label  VFP_DebugStr $Reg
$Label
        MEND

        MACRO
$Label  VFP_DebugReg $Reg
$Label
        MEND

        MACRO
$Label  VFP_DebugChar $Reg
$Label
        MEND
      ]

; **************************
; ** Define VFP Workspace **
; **************************

; data within workspace block
                        ^   0

VFPWS_OptionStart       #   8                   ; ptr to start of option in pattern (0) and AELINE (4)
VFPWS_DT                #   4                   ; data-type char  (F/S/U/I)
VFPWS_DTSize            #   4                   ; data-type size
VFPWS_DTIndex           #   4                   ; data-type index (offset in dt-filter list)
VFPWS_RegInc            #   4                   ; last reg number when inc list
VFPWS_RegType           #   4                   ; register type (QDSR)
VFPWS_RegID             #   4                   ; register ID   (dmntu)
VFPWS_RegBase           #   4                   ; base register number (for inc lists etc)
VFPWS_RawRegCount       #   4                   ; raw register count
                                                
VFPWS_immshift          #   4                   ; immediate shift right when encoding
                                                
VFPWS_OpData            #   (40*4)              ; current op variable values
VFPWS_Debug             #   16                  ; for use in debugging
VFPWS_Tables            #   4                   ; local copy of pointer to tables
VFPWS                   #   0                   ; total WS size

; *********************************************
; **                                         **
; ** Main VFP Entry Point from Existing Code **
; **                                         **
; *********************************************

; Entry
;            R10 = V char
;   AELINE (R11) = ptr to char after 'V' character

; Internal
;            R12 = ptr to workspace (allocated on stack)
;    R12 + VFPWS = entry parameters (R0-R12,R14) on stack

; From here we see if we can match a VFP instruction
; if not we branch back to VFPReturn with all registers intact
; on success we branch to CASMICHK
; Entry
;    R1 = word to write out
;   R10 = next char in line
;   R11 = (AELINE) ptr to char after one in R10
;    all others preserved from initial branch to VFPEntry
;
; on error
; we restore stack + all registers and branch to appropriate error handler
;    such as ERSYNT for a syntax error
;
; currently errors in ASMEXPR may cause problems due to stack...
;   maybe a possible existing bug due to stacked registers in ASMEXPR itself!
;   MSG (error reporting) is a horrible piece of code containing some very odd things!

VFPEntry ROUT
        STMFD   R13!,{R0-R12,R14}               ; preserve all registers
        BL      VFPGet4Char                     ; pick up first 4 chars
        B       %FT10
VFPEntryVDUP               
        STMFD   R13!,{R0-R12,R14}               ; preserve all registers
        LDR     R0, =&50554456                  ; "VDUP", AELINE at "P"
10
        SUB     R13,R13,#VFPWS                  ; allocate workspace
        MOV     R12,R13                         ; store workspace ptr (replaces LINE as not reqd)
                                                
        MOV     R2,#0                           ; clear the workspace to zero
        MOV     R1,#VFPWS
VFPent1
        SUBS    R1,R1,#4
        STRPL   R2,[R12,R1]
        BPL     VFPent1

        ; get data tables ptr
        LDR     R2,[ARGP,#VFPTABLES]
        STR     R2,[R12,#VFPWS_Tables]

        ; match first 4 chars against table
        BL      VFPCheck4Char

        ; do a full match of the syntax string
        BL      VFPMatchSyntax

        ; we should be at the end of the instruction here
        VFP_FindAEChar R0                       ; next char
        TEQ     R0,#13                          ; eol?
        TEQNE   R0,#":"                         ; or : ?
        TEQNE   R0,#";"                         ; or comment ?
        TEQNE   R0,#"\\"
        TEQNE   R0,#TREM
        BNE     VFPError_Trailing               ; if not, report error...

        ; encode any extra parameters
        BL      VFPParams                       ; encode params

        ; do the encoding!
        BL      VFPEncoding                     ; generate the encoded instruction into R0

        ADD     R13,R12,#VFPWS                  ; free workspace
        STR     R0,[R13,#1*4]                   ; store instruction (R0) as R1 for exit
        STR     AELINE,[R13,#11*4]              ; store new AELINE (R11) ptr
        LDMFD   R13!,{R0-R12,R14}               ; restore all registers

        LDRB    R10,[AELINE],#1                 ; get next char
        B       CASMICHK                        ; and assemble the instruction in R1...

        ; Get out of here as not an instruction (called from anywhere for speed)

VFPExit
        ADD     R13,R12,#VFPWS                  ; force stack reset
        LDMFD   R13!,{R0-R12,R14}               ; restore all registers
        B       VFPReturn                       ; continue looking for other instructions...

VFPError_Syntax
      [ EnableVFPDebug
        VFP_Error 0,"VFP syntax error"
      |
        VFP_BASICError ERSYNT                   ; syntax error
      ]
VFPError_Trailing
      [ EnableVFPDebug
        VFP_Error 0,"VFP unexpected trailing characters"
      |
        VFP_BASICError ERSYNT                   ; syntax error
      ]
VFPError_RegNumber
      [ EnableVFPDebug
        VFP_Error 0,"VFP bad register number"
      |
        VFP_BASICError ERASS3                   ; bad register
      ]                                         
VFPError_Internal                               
        VFP_BASICError EVFPSIL                  ; VFP internal mismatch
VFPError_ScalarRange                            
        VFP_BASICError EVFPSCR                  ; VFP scalar offset out of range
VFPError_ScalarChange                           
        VFP_BASICError EVFPSCC                  ; VFP scalar must not change in register list
VFPError_RegListCount                           
        VFP_BASICError EVFPRLC                  ; VFP register list count limit exceeded
VFPError_RegOfstAlign                           
        VFP_BASICError EVFPRIA                  ; VFP register offset immediate must be word aligned
VFPError_RegOfstRange                           
        VFP_BASICError ERASS2A                  ; label out of range
VFPError_ImmRange                               
        VFP_BASICError ERASS2                   ; bad immediate constant

VFPError_FPImmRange
        ; Produce a friendly error message for any unrepresentable FP constants
        ; In: R1 = 32bit constant
        ; [R12,#VFPWS_DT] valid
        LDRB    R0,[R12,#VFPWS_DT]
        CMP     R0,#"F"
        BNE     VFPError_ImmRange               ; Not a float; produce regular error
        ; Round R1 to the nearest expressible constant
        ; First check exponent
        AND     R2,R1,#&80000000
        MOV     R0,R1,LSL #1
        CMP     R0,#&7c000000
        MOVLO   R0,#&7c000000
        LDR     R3,=&83F00000
        CMP     R0,R3
        MOVHI   R0,R3
        ORR     R0,R2,R0,LSR #1
        ; Mantissa
        MOVS    R0,R0,ROR #19                   ; C set if need to round up
        MOV     R0,R0,LSL #19                   ; Get rid of low bits of mantissa, and shift everything to correct place
        ADDCS   R0,R0,#&80000                   ; Round up. Any mantissa overflow will roll into exponent, causing that to increment
        ; However, rounding up may have pushed the exponent over the limit
        CMP     R0,#&42000000
        CMPNE   R0,#&C2000000
        SUBEQ   R0,R0,#&80000                   ; Take it back down again
        ; Now convert to strings
        VFP_Debug "FPImmRange"
        VFP_DebugReg R0
        VFP_DebugReg R1
        STMFD   R13!,{R0-R1}
        ADD     R14,R12,#VFPWS                  ; ptr to our register store
        LDMIA   R14,{R0-R10}                    ; reload R0-R10
        LDR     R12,[R14,#12*4]                 ; load R12

        ; Convert rounded value to string
        BL      VFP_SP_to_FACC
        LDR     R4,[ARGP,#INTVAR]
        MOV     R5,#0
        MOV     TYPE,#-1
        BL      FCONFP
        ; Copy into OUTPUT for safe keeping
        MOV     R5,#0
        STRB    R5,[TYPE]
        ADD     R0,ARGP,#OUTPUT
        ADD     R1,ARGP,#STRACC
        BL      strcpy

        ; Convert original value to string
        BL      VFP_SP_to_FACC
        LDR     R4,[ARGP,#INTVAR]
        MOV     R5,#0
        MOV     TYPE,#-1
        BL      FCONFP
        ; Copy into OUTPUT+256 for safe keeping (MSG uses STRACC for building the error block)
        MOV     R5,#0
        STRB    R5,[TYPE]
        ADD     R0,ARGP,#OUTPUT+256
        ADD     R1,ARGP,#STRACC
        BL      strcpy

        ; Now generate error
        ADD     R4,ARGP,#OUTPUT+256
        ADD     R5,ARGP,#OUTPUT
        B       EVFPFPIMM

        LTORG

; *********************************
; ** Get 4 chars from input line **
; *********************************
; first char is a 'V'
; Exit
; R0 = 4 chars found

VFPGet4Char ROUT
        MOV     R0,#"V"
        MOV     R2,#24
VFPg4c1
        LDRB    R1,[AELINE],#1
        ASCII_UpperCase R1,R3
        ORR     R0,R0,R1,ROR R2
        SUBS    R2,R2,#8
        BNE     VFPg4c1
        MOV     R15,R14

; ** Check 4 Char Code against Table **
; Exit
; R3 = ptr to first syntax entry for this op-code

VFPCheck4Char
        LDR     R2,[R12,#VFPWS_Tables]
        LDR     R3,[R2,#8]
        ADD     R1,R2,R3
VFPc4c1
        LDMIA   R1!,{R2-R3}
        TEQ     R2,#0
        BEQ     VFPExit
        TEQ     R0,R2
        BNE     VFPc4c1
        MOV     R15,R14

; ***********************
; ** Full Syntax Match **
; ***********************

; Entry
; R3 = offset to first entry in syntax table

; Define Flags
VFPms_Skip    EQU 1
VFPms_RegList EQU 1:SHL:1
VFPms_Option  EQU 1:SHL:2

VFPms_Quad    EQU 1:SHL:4
VFPms_SkipOR  EQU 1:SHL:5
VFPms_OR      EQU 1:SHL:6
VFPms_DT      EQU 1:SHL:7

VFPms_immneg  EQU 1:SHL:8
VFPms_imm6    EQU 1:SHL:9
VFPms_imm4    EQU 1:SHL:10
VFPms_immpm   EQU 1:SHL:11

VFPms_immmask EQU 2_1111:SHL:8

VFPMatchSyntax
        STR     R14,[R13,#-4]!                  ; preserve link
        MOV     R10,R3                          ; R10 = syntax table offset
        VFP_Ptr R10,R0                          ; make into ptr
VFPms_synloop
        VFP_LDRH R9,R10,VFP_syn_pattern,R0,S    ; get pattern offset
        BEQ     VFPError_Syntax                 ; if end of list, syntax error as 4 chars matched, but pattern doesnt

        MOV     R8,#0                           ; R8 = flags
        VFP_Ptr R9,R0                           ; make pattern ptr
        LDR     AELINE,[R12,#VFPWS+(11*4)]      ; reset AELINE to start of string
        SUB     AELINE,AELINE,#1                ; move back to include the 'V'
VFPms_chrloop
        LDRB    R0,[R9],#1                      ; get next char from pattern
        TEQ     R0,#0                           ; end of string?
        BEQ     VFPms_patmatch                  ; if yes, we have pattern matched...
        BL      VFPmsChar                       ; process this character
        BEQ     VFPms_chrloop                   ; if ok, then loop...
VFPms_synnext
        ADD     R10,R10,#VFP_syn                ; skip to next syntax
        B       VFPms_synloop                   ; move on to next syntax variation as no good!
VFPms_patmatch
        ; check for extra trailing chars
        ; this might generate a syntax error, for now it just fails the pattern match
        ; (possibly a pattern could be a subset of another one?)

        VFP_FindAEChar R1                       ; get next char
        TEQ     R1,#":"                         ; end of statement?
        TEQNE   R1,#13                          ; end of line?
        TEQNE   R1,#";"                         ; comment?
        TEQNE   R1,#"\\"
        TEQNE   R1,#TREM
        BNE     VFPms_synnext                   ; if not, doesn't match so move on to next syntax

        ; matched so exit gracefully!
        LDR     R15,[R13],#4                    ; restore & exit...

        ; **********************************************
        ; ** Process Character(s) from Pattern String **
        ; **********************************************
VFPmsChar
        TEQ     R0,#"}"                         ; close brace?
        BEQ     VFPmsc_endoption                ; if yes, end of optional...
        TEQ     R0,#"|"                         ; pipe?
        BEQ     VFPmsc_endoptionOR              ; if yes, end option with OR condition
                                                
        TST     R8,#VFPms_Skip+VFPms_SkipOR     ; skipping?
        BNE     VFPmsc_match                    ; if yes, return a match as skipping...
                                                
        TEQ     R0,#"{"                         ; open brace?
        BEQ     VFPmsc_startoption              ; if yes, start of optional
                                                
        TEQ     R0,#"<"                         ; less than?
        BEQ     VFPmsc_opcode                   ; if yes, start of op-code
                                                
        TEQ     R0,#" "                         ; space?
        BEQ     VFPmsc_space                    ; if yes, skip spaces
        TEQ     R0,#","                         ; comma?
        BEQ     VFPmsc_comma                    ; if yes, skip spaces, comma, and spaces...
                                                
        TEQ     R0,#"("                         ; open bracket?
        BEQ     VFPmsc_openbracket              ; if yes, start of reglist...
        TEQ     R0,#")"                         ; close bracket?
        BEQ     VFPmsc_closebracket             ; if yes, end of reglist...
                                                
        TEQ     R0,#"\\"                        ; slash?
        LDREQB  R0,[R9],#1                      ; if yes, get the next char unfiltered

        LDRB    R1,[AELINE],#1                  ; get next char from input

        TEQ     R1,#TVDU                        ; expand tokenised VDU
        TEQEQ   R0,#"V"
        LDREQB  R2,[R9,#0]
        TEQEQ   R2,#"D"
        LDREQB  R2,[R9,#1]
        TEQEQ   R2,#"U"
        ADDEQ   R9,R9,#2
        BEQ     VFPmsc_match
20
        ASCII_UpperCase R0,R2                   ; make upper case R0
        ASCII_UpperCase R1,R2                   ; make upper case R1

        TEQ     R0,R1                           ; equal chars?
        BNE     VFPmsc_nomatch                  ; if not, this string doesn't match...

        ; match so return EQ
VFPmsc_match
        MOVS    R0,#0                           ; ensure equal status
        MOV     R15,R14                         ; if yes, exit as all is ok!

        ; no match so return NE
VFPmsc_nomatch
        SUB     R9,R9,#1
        TST     R8,#VFPms_Option                ; optional section?
        ORRNE   R8,R8,#VFPms_Skip               ; if yes, set skip flag
        BNE     VFPmsc_match                    ;   and return match as still ok
VFPmsc_nomatchexit                              
        MOVS    R0,#1                           ; set NE flag
        MOV     R15,R14                         ; exit...

        ; ** Start Optional Section **
VFPmsc_startoption
        ORR     R8,R8,#VFPms_Option             ; set optional flag
        SUB     R0,R9,#1                        ; store ptr to start of option in pattern
        STR     R0    ,[R12,#VFPWS_OptionStart+0]
        STR     AELINE,[R12,#VFPWS_OptionStart+4] ; store ptr to start of option in input line
        B       VFPmsc_match                    ; return match...

        ; ** End of Optional Section with OR condition **
VFPmsc_endoptionOR
        TST     R8,#VFPms_Skip                  ; skip set?
        LDRNE   AELINE,[R12,#VFPWS_OptionStart+4] ; if yes, reset input line as didn't match
        ORREQ   R8,R8,#VFPms_SkipOR             ; else,   set skip OR as don't need this option...
        ORR     R8,R8,#VFPms_OR                 ; set OR flag
        BIC     R8,R8,#VFPms_Skip               ; clear skip flag (but leave option flag)
        B       VFPmsc_match                    ; continue matching the new option...

        ; ** End of Optional Section **
VFPmsc_endoption
        LDRB    R0,[R9]                         ; get next char
        TEQ     R0,#"~"                         ; repeat char?
        BNE     VFPmsc_eo1                      ; if not, jump to skip check...

        ; with ~ we repeat until it doesn't match (i.e until skip is set)

        ADD     R9,R9,#1                        ; skip the repeat char
        TST     R8,#VFPms_Skip                  ; skip set?
        LDREQ   R9,[R12,#VFPWS_OptionStart+0]   ; if not, reset pattern to start of option

VFPmsc_eo1
        TST R8,#VFPms_Skip                      ; skip set?
        LDRNE   AELINE,[R12,#VFPWS_OptionStart+4] ; if yes, reset input line as didn't match

        TST     R8,#VFPms_OR                    ; an OR in this optional?
        TSTNE   R8,#VFPms_Skip                  ; if yes, skipping?
        BNE     VFPmsc_nomatchexit              ; if yes, problem as nothing has been hit (i.e. SkipOR set)

        BIC     R8,R8,#VFPms_Option+VFPms_Skip+VFPms_SkipOR+VFPms_OR
        B       VFPmsc_match                    ; return match...

        ; ** Skip Spaces **
VFPmsc_space
        VFP_FindAEChar R1                       ; find next non-space char
        B       VFPmsc_match                    ; return match...

VFPmsc_comma
        VFP_FindAEChar R1                       ; find next non-space char
        TEQ     R1,#","                         ; matching comma in input?
        BNE     VFPmsc_nomatch                  ; if not, return no match
        ADD     AELINE,AELINE,#1                ; skip the comma
        VFP_FindAEChar R1                       ; skip any more spaces
        B       VFPmsc_match                    ; return match...

        ; ** Start of Register List **
VFPmsc_openbracket
        VFP_FindAEChar R1
        TEQ     R1,#"{"                         ; open brace?
        ADDEQ   AELINE,AELINE,#1                ; if yes, consume the char
        ORREQ   R8,R8,#VFPms_RegList            ; if yes, start of register list
        B       VFPmsc_match                    ; match...

VFPmsc_closebracket
        VFP_FindAEChar R1
        TEQ     R1,#"}"                         ; close brace?
        BNE     VFPmsc_cb1                      ; if not, check if was reqd
        ADD     AELINE,AELINE,#1                ; consume the char
        ; bracket specified on line
        TST     R8,#VFPms_RegList               ; reglist set?
        BEQ     VFPmsc_nomatch                  ; if not, no match
        BIC     R8,R8,#VFPms_RegList            ; end of reg list
        B       VFPmsc_match                    ; match...

        ; no bracket specified on line
VFPmsc_cb1
        TST     R8,#VFPms_RegList               ; reg list set?
        BNE     VFPmsc_nomatch                  ; if yes, no match... (wrong number of reg for pattern etc)
        LDR     R2,[R12,#VFPWS_RawRegCount]     ; get raw reg count (1-n)
        CMP     R2,#2                           ; 2 or more?
        BGE     VFPmsc_nomatch                  ; if yes, report missing bracket
        BIC     R8,R8,#VFPms_RegList            ; end of reg list
        B       VFPmsc_match                    ; match...

        ; ** Start of Op-code **
VFPmsc_opcode
        STR     R14,[R13,#-4]!                  ; preserve link
        BL      VFPop_read                      ; read op-code
        BLEQ    VFPop_process                   ; if ok, process op-code
        LDR     R14,[R13],#4                    ; restore link
        BNE     VFPmsc_nomatch                  ; NE = no match...
        B       VFPmsc_match                    ; EQ = match...

        ; ***************************************
        ; ** Read Op-Code from Pattern into R0 **
        ; ***************************************
        ; Exit
        ; R0 = up to 4 chars of op-code (from between the <>)
VFPop_read
        MOV     R0,#0                           ; init output to 0
        MOV     R2,#0                           ; bit shift - start at 0
vfpop_r1
        LDRB    R1,[R9,R2,LSR#3]                ; get next byte from input
        TEQ     R1,#">"                         ; end of data?
        MOVEQ   R15,R14                         ; if yes, exit
        ORR     R0,R0,R1,LSL R2                 ; add byte into output
        ADD     R2,R2,#8                        ; inc shift by 8 bits
        TEQ     R2,#32                          ; all 4 bytes complete?
        BNE     vfpop_r1                        ; if not, loop...
        MOV     R15,R14                         ; exit...

        ; **************************
        ; ** Process Op-Code Read **
        ; **************************
VFPop_process
        STR     R14,[R13,#-4]!                  ; preserve link
                                                
        TEQ     R0,#"c"                         ; c = condition code
        BEQ     VFPop_condition                 ; ...
                                                
        LDR     R1,vfpopp_dt                    ; dt = data-type
        TEQ     R0,R1                           ; ...
        BEQ     VFPop_datatype                  ; ...
                                                
        LDR     R1,vfpopp_size                  ; size = data-type size
        TEQ     R0,R1                           ; ...
        BEQ     VFPop_size                      ; ...
                                                
        LDR     R1,vfpopp_spec                  ; spec = special register
        TEQ     R0,R1                           ; ...
        BEQ     VFPop_spec                      ; ...
                                                
        LDR     R1,vfpopp_lbl                   ; lbl = label (for VLDR/VSTR)
        TEQ     R0,R1                           ; ...
        BEQ     VFPop_label                     ; ...
                                                
        TEQ     R0,#"@"                         ; @ = alignment (VLDx,VSTx)
        BEQ     VFPop_align                     ; ...
                                                
        TEQ     R0,#"!"                         ; ! = writeback flag
        BEQ     VFPop_writeback                 ; ...
                                                
        AND     R1,R0,#255                      ; extract char 1

        VFP_Debug "extract char 1"
        VFP_DebugReg R0

        TEQ     R1,#"Q"                         ; Q/D/S/R =  register
        TEQNE   R1,#"D"                         ; ...
        TEQNE   R1,#"S"                         ; ...
        TEQNE   R1,#"R"                         ; ...
        BEQ     VFPop_register                  ; ...

        TEQ     R1,#"#"                         ; # = immediate
        BEQ     VFPop_immediate                 ; ...
VFPopp_nomatch
        MOVS    R0,#1                           ; set NE
        LDR     R15,[R13],#4                    ; exit (no match)
VFPopp_match
        MOVS    R0,#0                           ; set EQ
        LDR     R15,[R13],#4                    ; exit (match)

vfpopp_dt      DCB "dt",0,0
vfpopp_size    DCB "size"
vfpopp_spec    DCB "spec"
vfpopp_lbl     DCB "lbl",0

        ; ****************************
        ; ** Process Condition Code **
        ; ****************************
VFPop_condition
        MOV     R0,#2_1110                      ; default AL condition
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_cond*4)] ; store in Op_cond

        ADD     R9,R9,#2                        ; skip 'c>'
        LDRB    R0,[AELINE,#0]                  ; get next 2 chars of input
        LDRB    R1,[AELINE,#1]                  ; ...
        BIC     R0,R0,#32                       ; upper case
        BIC     R1,R1,#32                       ; ...
        ORR     R0,R0,R1,LSL#8                  ; ...
        ADR     R2,VFPop_condtab                ; ptr to table
VFPop_cond1
        LDR     R3,[R2],#4                      ; get word from table
        TEQ     R3,#0                           ; end?
        BEQ     VFPopp_nomatch                  ; if yes, no match...
        MOV     R1,R3,LSL#16                    ; extract 2 bytes to compare
        CMP     R1,R0,LSL#16                    ; compares with 2 bytes from input?
        BNE     VFPop_cond1                     ; if not, no match...
        MOV     R1,R3,LSR#16                    ; extract condition value byte
        STR     R1,[R12,#VFPWS_OpData+(VFP_Op_cond*4)] ; store into cond variable

        ADD     AELINE,AELINE,#2                ; consume the 2 chars used
        B       VFPopp_match                    ; match!...

VFPop_condtab
        DCB     "EQ",2_0000,0
        DCB     "NE",2_0001,0
        DCB     "CS",2_0010,0
        DCB     "HS",2_0010,0
        DCB     "CC",2_0011,0
        DCB     "LO",2_0011,0
        DCB     "MI",2_0100,0
        DCB     "PL",2_0101,0
        DCB     "VS",2_0110,0
        DCB     "VC",2_0111,0
        DCB     "HI",2_1000,0
        DCB     "LS",2_1001,0
        DCB     "GE",2_1010,0
        DCB     "LT",2_1011,0
        DCB     "GT",2_1100,0
        DCB     "LE",2_1101,0
        DCB     "AL",2_1110,0
        DCD     0

        ; ***********************
        ; ** Process Data-Type **
        ; ***********************
VFPop_datatype
        ADD     R9,R9,#3                        ; skip 'dt>'
        ORR     R8,R8,#VFPms_DT                 ; set DT flag (DT+size)
                                                
VFPop_dt1                                       
        LDRB    R0,[AELINE]                     ; load data-type type ID
        ASCII_UpperCase R0,R1
        TEQ     R0,#"I"                         ; I - integer
        TEQNE   R0,#"S"                         ; S - signed integer
        TEQNE   R0,#"U"                         ; U - unsigned integer
        TEQNE   R0,#"F"                         ; F - float
        TEQNE   R0,#"D"                         ; D - double float (!)
        TEQNE   R0,#"P"                         ; P - polynomial
        ADDEQ   AELINE,AELINE,#1                ; if match, use the char
        BEQ     VFPop_dt2                       ;   , skip...
                                                
        TST     R8,#VFPms_DT                    ; required dt specifier?
        BNE     VFPopp_nomatch                  ; if yes, no match...
                                                
        CMP     R0,#"0"                         ; digit?
        BLT     VFPopp_nomatch                  ; if not, no match...
        CMP     R0,#"9"                         
        BGT     VFPopp_nomatch                  
                                                
VFPop_dt2                                       
        BL      VFPop_readdtsize                ; read dt size and validate
        BNE     VFPopp_nomatch                  ; if NE, no match...
                                                
        B       VFPopp_match                    ; match!...

        ; **************************************
        ; ** Process Data-Type with Size Only **
        ; **************************************
VFPop_size
        ADD     R9,R9,#5                        ; skip 'size>'
        BIC     R8,R8,#VFPms_DT                 ; clear DT flag (size only)
        B       VFPop_dt1

        ; ** Read Data-type Size from input String
        ; Entry
        ; AELINE = ptr to first char of size
        ; R0     = data-type specifier (or space if size only)
        ; R10    = ptr to syntax lookup
        ; Exit
        ; Op_size, Op_size1, Op_esize, Op_imm3, Op_F, Op_U, all populated
VFPop_readdtsize
        STMFD   R13!,{R0-R7,R14}                ; preserve registers
        MOV     R4,R0                           ; transfer data-type for later

        LDRB    R0,[AELINE,#0]                  ; load 2 bytes of size
        LDRB    R1,[AELINE,#1]                  ; ...

        TEQ     R0,#"."                         ; convert . into space
        MOVEQ   R0,#" "                         ; ...
        TEQ     R0,#" "                         ; first char is space?
        MOVEQ   R1,#" "                         ; if yes, 2nd char must be space
        ADDNE   AELINE,AELINE,#1                ; if not, consume 1st char

        TEQ     R1,#"."                         ; convert . into space
        MOVEQ   R1,#" "                         ; ...
        TEQ     R1,#" "                         ; second char is space?
        ADDNE   AELINE,AELINE,#1                ; if not, consume 2nd char

        TEQ     R4,#"F"                         ; F and two spaces?
        TEQEQ   R0,#" "                         ; ...
        TEQEQ   R1,#" "                         ; ...
        MOVEQ   R0,#"3"                         ; if yes, equals F32
        MOVEQ   R1,#"2"                         ; , ...

        TEQ     R4,#"D"                         ; D and two spaces?
        TEQEQ   R0,#" "                         ; ...
        TEQEQ   R1,#" "                         ; ...
        MOVEQ   R4,#"F"                         ; if yes, equals F64
        MOVEQ   R0,#"6"                         ; , ...
        MOVEQ   R1,#"4"                         ; , ...

        ORR     R0,R0,R1,LSL#8                  ; join 2 byte size string into R0

        VFP_LDRH R3,R10,VFP_syn_datatype,R2,S   ; load data-type list ptr
        BEQ     VFPop_rdts_nomatch              ; paraniod check for error in tables
        VFP_Ptr R3,R2                           ; make into ptr
        MOV     R5,#0                           ; clear index counter

VFPop_rdts_lp
        LDR     R1,[R3],#4                      ; load data-type list entry
        TEQ     R1,#0                           ; end of list?
        BEQ     VFPop_rdts_nomatch              ; if yes, no match...
        BL      VFPop_rdts_comp                 ; compare the two types
        ADDNE   R5,R5,#1                        ; if not, inc counter
        BNE     VFPop_rdts_lp                   ; loop...

        TEQ     R1,#64                          ; set-up L flag
        MOVEQ   R0,#1                           ; ... when size is 64
        MOVNE   R0,#0
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_L*4)]

        TEQ     R4,#"U"                         ; set up U flag
        MOVEQ   R0,#1                           ; ... when U data-type
        MOVNE   R0,#0
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_U*4)]

        TEQ     R4,#"F"                         ; set up F flag
        MOVEQ   R0,#1                           ; ...  when F data-type
        MOVNE   R0,#0
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_F*4)]

        TEQ     R4,#"F"                         ; set up sz = 1 when F64
        TEQEQ   R1,#64
        MOVEQ   R0,#1
        STREQ   R0,[R12,#VFPWS_OpData+(VFP_Op_sz*4)]

        TEQ     R4,#"F"                         ; set up sz = 0 when F32
        TEQEQ   R1,#32                                     
        MOVEQ   R0,#0
        STREQ   R0,[R12,#VFPWS_OpData+(VFP_Op_sz*4)]       

        STR     R1,[R12,#VFPWS_DTSize]          ; store data-type size
        STR     R4,[R12,#VFPWS_DT]              ; store data-type char
        STR     R5,[R12,#VFPWS_DTIndex]         ; store data-type index

        MOV     R3,R1

        ; set-up flags for particular data-type size
        TEQ     R3,#8                           ; size 8
        MOVEQ   R0,#2_00
        MOVEQ   R1,#2_001
        MOVEQ   R2,#2_10

        TEQ     R3,#16                          ; size 16
        MOVEQ   R0,#2_01                        
        MOVEQ   R1,#2_010                       
        MOVEQ   R2,#2_01                        
                                                
        TEQ     R3,#32                          ; size 32
        MOVEQ   R0,#2_10                        
        MOVEQ   R1,#2_100                       
        MOVEQ   R2,#2_00                        
                                                
        TEQ     R3,#64                          ; size 64
        MOVEQ   R0,#2_11
        MOVEQ   R1,#0
        MOVEQ   R2,#0

        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_size*4)]  ; store Op_size
        SUB     R0,R0,#1                                ; calc size1
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_size1*4)] ; store Op_size1
        STR     R1,[R12,#VFPWS_OpData+(VFP_Op_imm3*4)]  ; store Op_imm3
        STR     R2,[R12,#VFPWS_OpData+(VFP_Op_esize*4)] ; store Op_esize

        MOVS    R0,#0                           ; set match
        LDMFD   R13!,{R0-R7,R15}                ; restore & exit...

VFPop_rdts_nomatch
        MOVS    R0,#1                           ; set no match
        LDMFD   R13!,{R0-R7,R15}                ; restore & exit...

        ; ************************
        ; ** Compare Data-types **
        ; ************************
        ; allows for variations on p285 of ARM
        ; Entry
        ; R4 = data-type in input string (space if size only)
        ; R0 = two bytes from input string for size (second is space if unused eg "S8 " or "S16")
        ; R1 = word from data-type table (byte0=data-type, bytes1-2=size string, byte3=binary size)
        ; Exit
        ; R1 = binary size extracted from byte3 of input R1
VFPop_rdts_comp
        AND     R6,R1,#&FF                      ; extract data-type specifier
        BIC     R7,R1,#&FF000000                ; extract size string
        MOV     R7,R7,LSR#8                     ; ...
        MOV     R1,R1,LSR#24                    ; extract binary size
                                                
        TEQ     R4,#"P"                         ; would be P32?
        TEQEQ   R1,#32                          
        BEQ     VFPop_rdts_cmp_nomatch          ; if yes, not a valid datatype
        TEQ     R4,#"P"                         ; would be P64?
        TEQEQ   R1,#64                          
        BEQ     VFPop_rdts_cmp_nomatch          ; if yes, not a valid datatype
                                                
        MOV     R2,R4                           ; data-type to use for comparision (=input as default)
                                                
        TEQ     R6,#"I"                         ; size is Int?
        BNE     VFPop_rdts_c1                   ; if not, skip...
        TEQ     R2,#"S"                         ; convert S or U into I for comparison
        TEQNE   R2,#"U"
        MOVEQ   R2,#"I"

VFPop_rdts_c1
        TEQ     R6,#" "                         ; space in type so can be any data-type in input?
        TEQNE   R2,R6                           ; if not, data-types match?
        TEQEQ   R0,R7                           ; if yes, size strings match?
        MOV     R15,R14                         ; return EQ/NE status...

VFPop_rdts_cmp_nomatch
        MOVS    R0,#1
        MOV     R15,R14

        ; ******************************
        ; ** Process Special Register **
        ; ******************************
        ; Exit
        ; Op_spec populated with register encoding
VFPop_spec
        ADD     R9,R9,#5                        ; skip 'spec>'
                                                
        LDRB    R0,[AELINE],#1                  ; extract 4 chars
        LDRB    R1,[AELINE],#1                  
        LDRB    R2,[AELINE],#1                  
        LDRB    R3,[AELINE],#1                  
        BIC     R0,R0,#32                       ; upper case
        BIC     R1,R1,#32                        
        BIC     R2,R2,#32                        
        BIC     R3,R3,#32                        
        ORR     R0,R0,R1,LSL#8                  ; combine into a word
        ORR     R0,R0,R2,LSL#16                 
        ORR     R0,R0,R3,LSL#24                 
        LDRB    R1,[AELINE],#1                  ; extract 5th char
        CMP     R1,#'a'
        BICHS   R1,R1,#32                       ; upper case
        MOV     R1,R1,LSL#24                    ; shift ready for comparison
                                                
        ADR     R4,VFPop_spectab                ; table of special register names
VFPop_spec1                                     
        LDMIA   R4!,{R2-R3}                     ; load next entry
        TEQ     R2,#0                           ; end of list?
        BEQ     VFPopp_nomatch                  ; if yes, no match...
        TEQ     R0,R2                           ; match word 0
        TEQEQ   R1,R3,LSL#24                    ; ... and byte 4?
        BNE     VFPop_spec1                     ; if not, loop...

        MOV     R3,R3,LSR#8                     ; extract encoding
        STR     R3,[R12,#VFPWS_OpData+(VFP_Op_spec*4)] ; store encoding in Op_spec
        B       VFPopp_match                    ; match!...

VFPop_spectab
        DCB     "FPSID",2_0000,0,0
        DCB     "FPSCR",2_0001,0,0
        DCB     "MVFR2",2_0101,0,0
        DCB     "MVFR1",2_0110,0,0
        DCB     "MVFR0",2_0111,0,0
        DCB     "FPEXC",2_1000,0,0
        DCD     0

        ; *******************
        ; ** Process Label **
        ; *******************
        ; <lbl> used as offset in VLDR and VSTR instructions
VFPop_label
        ADD     R9,R9,#4                        ; skip "lbl>"

        BL      VFPop_expr                      ; read expression

        ADD     R2,R12,#VFPWS                   ; get stacked registers ptr
        LDR     R2,[R2,#8*4]                    ; get ARGP from stack
        LDR     R1,[R2,#ASSPC]                  ; get assembly PC
        ADD     R1,R1,#8                        ; add 8 to match ARM PC
        SUBS    R0,R0,R1                        ; calc offset from PC

        MOVPL   R1,R0                           ; get ABS(offset)
        RSBMI   R1,R0,#0

        MOVPL   R2,#1                           ; set U=1 when +
        MOVMI   R2,#0                           ; set U=0 when -

        TST     R1,#2_11                        ; word aligned?
        BNE     VFPError_RegOfstAlign           ; if not, alignment error...
        CMP     R1,#1024                        ; out of range?
        BGE     VFPError_RegOfstRange           ; if yes, range error...

        STR     R2,[R12,#VFPWS_OpData+(VFP_Op_U*4)]   ; store U
        MOV     R1,R1,LSR#2                           ; encoded value is in words
        STR     R1,[R12,#VFPWS_OpData+(VFP_Op_imm*4)] ; store imm
        MOV     R0,#15                                ; Vn = R15
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_Vn*4)]  ; store Vn

        B       VFPopp_match                    ; match...

        ; ***********************
        ; ** Process Alignment **
        ; ***********************
        ; @<expr>] used within VLDx and VSTx instructions
        ; Exit
        ; Op_align populated with alignment encoding
VFPop_align
        ADD     R9,R9,#2                        ; skip '@>'

        LDRB    R1,[AELINE],#1                  ; get char from input
        TEQ     R1,R0                           ; "@"?
        BNE     VFPopp_nomatch                  ; if not, no match...

        LDRB    R1,[AELINE]                     ; check next char
        TEQ     R1,#"]"                         ; "]" end of string?
        BEQ     VFPopp_nomatch                  ; if not, no match...

        BL      VFPop_expr                      ; read expression for alignment

        VFP_LDRH R4,R10,VFP_syn_align,R1,S      ; alignment list ptr
        BEQ     VFPopp_nomatch                  ; if not specified, no match...
        VFP_Ptr R4,R1                           ; turn into ptr

VFPop_ali0
        LDR     R1,[R4],#4                      ; load number of alignments
        TEQ     R1,#0                           ; no more to check?
        BEQ     VFPopp_nomatch                  ; if yes, no match....

        TEQ     R1,#1                           ; only 1?
        MOVEQ   R5,#0                           ; if yes, use this one
        LDRNE   R5,[R12,#VFPWS_DTIndex]         ; else,   load data-type index (0 based)

        CMP     R5,R1                           ; enough alignments? (paranoid check)
        BGE     VFPError_Internal               ; if not, internal error...

        ADD     R5,R5,#1                        ; inc by 1 to make zero the one we want
                                                
VFPop_ali1                                      
        LDR     R1,[R4],#4                      ; load next entry in list
        TEQ     R1,#0                           ; end of list?
        BEQ     VFPop_ali0                      ; if yes, no match...
        SUBS    R5,R5,#1                        ; use this entry?
        BNE     VFPop_ali1                      ; if not, loop...
                                                
        BIC     R2,R1,#&FF0000                  ; clear out encoding bits
        TEQ     R2,R0                           ; match the alignment?
        BNE     VFPop_ali1                      ; if not, loop...
                                                
        MOV     R0,R1,LSR#16                    ; get alignment encoding
        AND     R0,R0,#255
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_align*4)] ; store in Op_align

        B       VFPopp_match                    ; match!...

        ; *************************************
        ; ** Process Optional Writeback Flag **
        ; *************************************
        ; Exit
        ; Op_Rm & Op_W populated
VFPop_writeback
        ADD     R9,R9,#2                        ; skip '!>' in pattern
                                                
        VFP_Debug "Writeback test"              
                                                
        LDRB    R0,[AELINE]                     ; load char from input
        MOV     R1,#2_1111                      ; default no-wb Rm value
        MOV     R2,#0                           ; default no-wb flag
                                                
        TEQ     R0,#"!"                         ; ! present?
        MOVEQ   R1,#2_1101                      ; if yes, set wb Rm value
        MOVEQ   R2,#1                           ; , set wb flag
        ADDEQ   AELINE,AELINE,#1                ; , and skip ! char

        STR     R1,[R12,#VFPWS_OpData+(VFP_Op_Vm*4)] ; store Op_Rm value
        STR     R2,[R12,#VFPWS_OpData+(VFP_Op_W*4)]  ; store Op_W value

        B       VFPopp_match                    ; match...

        ; **********************
        ; **                  **
        ; ** Process Register **
        ; **                  **
        ; **********************
        ; Entry
        ; R1 = char from pattern string (QDRS)

; define flags
VFPop_reg_plus EQU 1
VFPop_reg_inc  EQU 2

VFPop_register
        ADD     R9,R9,#1                        ; skip reg 'QDSR' char
        VFP_FindAEChar1 R0                      ; get next non-space from input
        ASCII_UpperCase R0,R4
                                                
        VFP_Debug "register"                    
        VFP_DebugReg R1                         
        VFP_DebugReg R0                         
                                                
        STR     R1,[R12,#VFPWS_RegType]         ; store reg type in temp storage
                                                
        TEQ     R1,#"R"                         ; ARM core register
        TEQNE   R0,R1                           ; if not, matches reg char?
        BNE     VFPopp_nomatch                  ; if not, no match...
                                                
        LDRB    R0,[R9],#1                      ; load register ID
        TEQ     R0,#"d"                         ; validate against dmntu
        TEQNE   R0,#"m"                         
        TEQNE   R0,#"n"                         
        TEQNE   R0,#"t"                         
        TEQNE   R0,#"u"                         
        BNE     VFPopp_nomatch                  ; if no match...
        STR     R0,[R12,#VFPWS_RegID]           ; store register ID

        MOV     R4,#0                           ; R4 - flags
        MOV     R6,#1                           ; R6 - reg count
        BL      VFPop_reg_number                ; get reg number R5
        BLEQ    VFPop_reg_options               ; if ok, process options
        BNE     VFPopp_nomatch                  ; else , no match...
        BL      VFPop_reg_store                 ; store values
        B       VFPopp_match                    ; match...

        ; ** Store Register Details **
        ; R10 = syntax
        ; R9  = pattern
        ; R8  = flags
        ; R6  = reg count
        ; R5  = reg number
        ; R4  = reg flags
VFPop_reg_store
        VFP_Debug "reg store"
        VFP_DebugReg R6

        ; validate regcount
        LDR     R1,[R12,#VFPWS_RegType]         ; reg type
        MOV     R2,#16                          ; max register count
        TEQ     R1,#"S"                         ; can have 32 singles, 16 everything else
        MOVEQ   R2,#32

        TST     R4,#VFPop_reg_inc               ; inc "?" register list
        BEQ     VFPop_rst1                      ; if not, skip...

        ; when reginc max register number is in dt filter position 0
        ; (avoided having another list for a few exceptional cases)

        VFP_LDRH R3,R10,VFP_syn_datatype,R0,S   ; syntax data-type
        BEQ     VFPop_rst1                      ; if not set, skip...
        VFP_Ptr R3,R0                           ; make a ptr
        LDR     R2,[R3]                         ; load data-type entry 0
        MOV     R2,R2,LSR#24                    ; extract size

VFPop_rst1
        CMP     R6,R2                           ; reg count out of range?
        BGT     VFPError_RegListCount           ; if yes, report error...

        TST     R8,#VFPms_RegList               ; reg list set?
        BEQ     VFPop_rst2                      ; if not, skip...

        ; encode and store regcount
        TEQ     R1,#"D"                         ; double word?
        MOVEQ   R0,R6,LSL#1                     ; if yes, count is double
        MOVNE   R0,R6                           ; else  , count is single
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_regcount*4)] ; store encoded value in Op_regcount
        STR     R6,[R12,#VFPWS_RawRegCount]                ; store raw reg count



VFPop_rst2
        ; exit if part of + list
        TST     R4,#VFPop_reg_plus              ; reg is in a list?
        MOVNE   R15,R14                         ; if yes, exit...

        ; store base register number
        STR     R5,[R12,#VFPWS_RegBase]         ; store base register number
        STR     R5,[R12,#VFPWS_RegInc]

        ; encode register number and store
        MOV     R3,#0                           ; R7 - reg data store
        LDR     R0,[R12,#VFPWS_RegID]           ; get reg 'id'
        TEQ     R0,#"d"                         ; d = Vd
        ADDEQ   R3,R12,#VFPWS_OpData + (VFP_Op_Vd*4)
        TEQ     R0,#"m"                         ; m = Vm
        ADDEQ   R3,R12,#VFPWS_OpData + (VFP_Op_Vm*4)
        TEQ     R0,#"n"                         ; n = Vn
        ADDEQ   R3,R12,#VFPWS_OpData + (VFP_Op_Vn*4)
        TEQ     R0,#"t"                         ; t = Rt
        ADDEQ   R3,R12,#VFPWS_OpData + (VFP_Op_Rt*4)
        TEQ     R0,#"u"                         ; u = Ru
        ADDEQ   R3,R12,#VFPWS_OpData + (VFP_Op_Ru*4)
        TEQ     R3,#0                           ; paranoid check
        BEQ     VFPError_Internal

        MOV     R0,R5                           ; default register number encoding
        TEQ     R1,#"S"                         ; single type?
        MOVEQ   R0,R5,LSR#1                     ; if yes, alter encoding to bits [04321]
        ORREQ   R0,R0,R5,LSL#4                  ; , ...
        ANDEQ   R0,R0,#2_11111                  ; , ...
        TEQ     R1,#"Q"                         ; quad type?
        MOVEQ   R0,R5,LSL#1                     ; if yes, alter encoding (n*2)
        STR     R0,[R3]                         ; store encoded register number

        ; set Q flag
        MOV     R0,#0                           ; default Q=0
        TEQ     R1,#"Q"                         ; data-type Q?
        MOVEQ   R0,#1                           ; if yes, Q=1
        TSTNE   R8,#VFPms_Quad                  ; else  , Q unset?
        STREQ   R0,[R12,#VFPWS_OpData+(VFP_Op_Q*4)] ; if yes, store Q flag
        ORR     R8,R8,#VFPms_Quad               ; set Q seen flag

        MOV     R15,R14                         ; exit...

        ; ** Get Register Number **
        ; Entry
        ; R1 = register type
        ; Exit
        ; R5 = register number
VFPop_reg_number
        MOV     R3,R1                           ; transfer register type QDSR
                                                
        TEQ     R3,#"R"                         ; ARM register?
        BEQ     VFPop_rn_ARM                    ; if yes, process it...

        ; quad word F64 safety check to ensure correct syntax is found
        TEQ     R3,#"Q"                         ; when register is quad
        LDREQB  R0,[R12,#VFPWS_DT]              ; data-type can not be F64
        TEQEQ   R0,#"F"                            
        LDREQB  R0,[R12,#VFPWS_DTSize]             
        TEQEQ   R0,#64                             
        BEQ     VFPop_rn_nomatch                ; if it is, no match...

        LDRB    R0,[AELINE],#1                  ; get next char
        TEQ     R0,#"#"                         ; prefixing expression?
        BEQ     VFPop_rn_expr                   ; if yes, get register number from expression

        TEQ     R3,#"S"                         ; stack ptr? (SP)
        TEQEQ   R0,#"P"
        BEQ     VFPop_rn_nomatch                ; if yes, no match as ARM register

        CMP     R0,#"0"                         ; digit?
        RSBGES  R2,R0,#"9"
        BLT     VFPError_RegNumber              ; if not, invalid register number
        SUB     R5,R0,#"0"                      ; convert to binary

        LDRB    R1,[AELINE]                     ; get next char
        CMP     R1,#"0"                         ; digit?
        RSBGES  R2,R1,#"9"
        ADDGE   AELINE,AELINE,#1                ; if yes, consume the next char
        MOVGE   R0,#10                          ; multiply first digit by 10
        MULGE   R5,R0,R5                        ; ...
        SUBGE   R1,R1,#"0"                      ; and add second digit
        ADDGE   R5,R5,R1                        ; ...
VFPop_rn_range
        ; check range of register number
        TEQ     R3,#"Q"                         ; Q
        TEQNE   R3,#"R"                         ; or R
        MOVEQ   R0,#16                          ; is 0-15

        TEQ     R3,#"D"                         ; D
        TEQNE   R3,#"S"                         ; or S
        MOVEQ   R0,#32                          ; is 0-31

        CMP     R5,#0                           ; out of range?
        BLT     VFPError_RegNumber              ; if yes, report error...
        CMP     R5,R0                           ; out of range?
        BGE     VFPError_RegNumber              ; if yes, report error...

VFPop_rn_match
        MOVS    R0,#0
        MOV     R15,R14
VFPop_rn_nomatch
        MOVS    R0,#1
        MOV     R15,R14

        ; Get Register Number Expression
VFPop_rn_expr
        STR     R14,[R13,#-4]!                  ; preserve link
        BL      VFPop_expr                      ; parse expression
        LDR     R14,[R13],#4                    ; restore link
        MOV     R5,R0                           ; transfer register number
        B       VFPop_rn_range                  ; validate register number

        ; ** Handle ARM register number **
VFPop_rn_ARM
        STR     R14,[R13,#-4]!                  ; preserve link
        SUB     AELINE,AELINE,#1                ; make sure we point at the "R"
        ; copes with R0-R15, PC,LR,SP, and expressions returning 0-15
        BL      VFPop_ARMgetreg                 ; get register number
        MOV     R5,R0                           ; transfer reg number
        LDR     R14,[R13],#4                    ; restore link
        B       VFPop_rn_range                  ; check range...

        ; ****************************************
        ; ** Process all Variations and Options **
        ; ****************************************
        ; R6 = reg count
        ; R5 = reg number
        ; R4 = reg flags
VFPop_reg_options
        STR     R14,[R13,#-4]!                  ; preserve

VFPop_ro_reglist
        LDRB    R0,[R9]                         ; get next char in pattern
        TEQ     R0,#"+"                         ; + char? (inc list?)
        BNE     VFPop_ro1                       ; if not, skip...

        VFP_Debug "Plus"

VFPop_ro_plus
        ADD     R9,R9,#1                        ; consume the +

        ORR     R4,R4,#VFPop_reg_plus           ; set flag that plus is present

        LDRB    R0,[R9],#1                      ; get inc offset
        TEQ     R0,#"?"                         ; ? inc list?
        ORREQ   R4,R4,#VFPop_reg_inc            ; if yes, set inc list flag
        LDREQ   R1,[R12,#VFPWS_RegInc]          ; , get inc reg number
        ADDEQ   R1,R1,#1                        ; , inc by 1
        LDRNE   R1,[R12,#VFPWS_RegBase]         ; else  , load base reg number
        ADDNE   R1,R1,R0                        ; , add offset specified
        SUBNE   R1,R1,#"0"                      ; , (as binary)

        TEQ     R5,R1                           ; expected register?
        BNE     VFPop_ro_nomatch                ; if not, no match...

        TEQ     R0,#"?"                         ; inc reg?
        STREQ   R1,[R12,#VFPWS_RegInc]          ; if yes, store new inc value

        LDR     R6,[R12,#VFPWS_RegBase]         ; load base reg number
        SUB     R6,R1,R6                        ; calc regcount
        ADD     R6,R6,#1

        VFP_DebugReg R6

VFPop_ro1
        LDRB    R0,[R9]                         ; get next char from pattern
        TEQ     R0,#"-"                         ; - char?
        BEQ     VFPop_ro_endofrange             ; if yes, end of range...
        TEQ     R0,#"["                         ; [ char?
        BEQ     VFPop_ro_scalar                 ; if yes, scalar...

        LDRB    R0,[AELINE]                     ; get next char from line
        TEQ     R0,#"["                         ; scalar bracket when not in pattern?
        BEQ     VFPop_ro_nomatch                ; if yes, no match...
VFPop_ro_match
        LDRB    R0,[R9],#1                      ; skip over trailing ">"
        TEQ     R0,#">"                         ; safety check that all is well
        BNE     VFPError_Internal
        MOVS    R0,#0                           ; set EQ status
        LDR     R15,[R13],#4                    ; exit...
VFPop_ro_nomatch
        MOVS    R0,#1                           ; set NE status
        LDR     R15,[R13],#4                    ; exit...

        ; ** Process End of Register Range **
VFPop_ro_endofrange
        ADD     R9,R9,#1                        ; skip "-" char
        LDR     R0,[R12,#VFPWS_RegBase]         ; load base register
        CMP     R5,R0                           ; check this is higher?
        BLT     VFPError_RegNumber              ; if not, report error...

        SUB     R6,R5,R0                        ; calc offset
        ADD     R6,R6,#1
        ORR     R4,R4,#VFPop_reg_plus           ; set plus flag to stop overwrite of base reg number
        B       VFPop_ro_match                  ; matched!

        ; ** Process Scalar Register Offset **
VFPop_ro_scalar
        LDRB    R0,[AELINE],#1                  ; get char from line
        TEQ     R0,#"["                         ; "[" char?
        BNE     VFPop_ro_nomatch                ; if not, no match...

        ADD     R9,R9,#1                        ; skip "[" char

        LDRB    R0,[R9],#1                      ; next char in pattern
        TEQ     R0,#"]"                         ; "]" char? (otherwise must be "x")
        BEQ     VFPop_ro_noscalar               ; if yes, handle no scalar offset...

        LDRB    R0,[AELINE]                     ; get next char in input
        TEQ     R0,#"]"                         ; no scalar offset?
        BEQ     VFPop_ro_nomatch                ; if yes, no match with this pattern...

        MOV     R2,#31                          ; max offset

        ADD     R9,R9,#1                        ; skip "]"
        LDRB    R0,[R9]                         ; check for range specifier in pattern

        CMP     R0,#"0"                         ; 0-9?
        RSBGES  R1,R0,#"9"                              
        SUBGE   R2,R0,#"0"                              
        ADDGE   R9,R9,#1                                

        ASCII_UpperCase R0,R1

        CMP     R0,#"A"                                   
        RSBGES  R1,R0,#"F"                                
        SUBGE   R2,R0,#("A") - 10                         
        ADDGE   R9,R9,#1                                  

        CMP     R5,R2                           ; register out of range?
        BGT     VFPError_RegNumber              ; if yes, report...

        VFP_Debug "scalar offset"

        BL      VFPop_expr                      ; read expression into R0

        MOV     R2,#0                           ; range for scalar
        LDR     R1,[R12,#VFPWS_DTSize]          ; get data-type size
        TEQ     R1,#32                          ; 32 = 0-1
        MOVEQ   R2,#1
        TEQ     R1,#16                          ; 16 = 0-3
        MOVEQ   R2,#3
        TEQ     R1,#8                           ;  8 = 0-7
        MOVEQ   R2,#7

        CMP     R0,#0                           ; validate low range
        BLT     VFPError_ScalarRange            ; if out, report error
        CMP     R0,R2                           ; validate high range
        BGT     VFPError_ScalarRange            ; if out, report error

        TST     R4,#VFPop_reg_plus              ; this reg is part of a list?
        LDRNE   R1,[R12,#VFPWS_OpData+(VFP_Op_x*4)] ; if yes, get existing scalar offset
        TEQNE   R0,R1                           ; has it changed?
        BNE     VFPError_ScalarChange           ; if yes, report error...

        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_x*4)] ; store Op_x value

VFPop_ro_noscalar
        VFP_FindAEChar1 R0                      ; find next non-space char
        TEQ     R0,#"]"                         ; "]" char?
        BNE     VFPop_ro_nomatch                ; if not, no match...
        B       VFPop_ro_match                  ; match...

        ; ******************************
        ; ** Get ARM Register into R0 **
        ; ******************************
        ; valiated later so expression just returns what it found
VFPop_ARMgetreg
        STMFD   R13!,{R1-R5,R14}                ; preserve
                                                
        LDRB    R1,[AELINE],#1                  ; get next char
        LDRB    R2,[AELINE],#1                  ; get next char
        ASCII_UpperCase R1,R3                   ; upper case R1
        ASCII_UpperCase R2,R3                   ; upper case R2

        VFP_DebugChar R1
        VFP_DebugChar R2

        TEQ     R1,#"P"                         ; PC?
        TEQEQ   R2,#"C"                         ; ...
        MOVEQ   R0,#15                          ; if yes, R15
        BEQ     VFPop_agr_exit                  ; exit...

        TEQ     R1,#"L"                         ; LR?
        TEQEQ   R2,#"R"                         ; ...
        MOVEQ   R0,#14                          ; if yes, R14
        BEQ     VFPop_agr_exit                  ; exit...

        TEQ     R1,#"S"                         ; SP?
        TEQEQ   R2,#"P"                         ; ...
        MOVEQ   R0,#13                          ; if yes, R13
        BEQ     VFPop_agr_exit                  ; exit...

        TEQ     R1,#"R"                         ; "R"?
        BNE     VFPop_agr_expr                  ; if not, expression...
        TEQ     R2,#"1"                         ; 1?
        BEQ     VFPop_agr_R1                    ; if yes, check for R1x...

        CMP     R2,#"0"                         ; 0-9?
        BLT     VFPop_agr_expr                  ; if not, expression...
        CMP     R2,#"9"
        BGT     VFPop_agr_expr

        SUB     R0,R2,#"0"                      ; get reg number
VFPop_agr_exit
        LDMFD   R13!,{R1-R5,R15}                ; exit...

        ; starts with R1
VFPop_agr_R1
        MOV     R0,#1                           ; reg 1
        LDRB    R3,[AELINE]                     ; get 3rd char
        CMP     R3,#"0"                         ; < "0"
        BLT     VFPop_agr_exit                  ; if yes, exit...
        CMP     R3,#"5"                         ; > "5"
        BGT     VFPop_agr_exit                  ; if yes, exit...
        SUB     R0,R3,#"0"-10                   ; get 2nd digit value + 10
        ADD     AELINE,AELINE,#1                ; consume the 3rd char
        B       VFPop_agr_exit                  ; exit...

        ; parse expression
VFPop_agr_expr
        SUB     AELINE,AELINE,#2                ; go back to start of input
        BL      VFPop_expr                      ; parse expression
        B       VFPop_agr_exit                  ; exit...

        ; *********************************
        ; ** Evaluate Expression into R0 **
        ; *********************************
VFPop_expr
        STMFD   R13!,{R1-R10,R12,R14}           ; preserve registers
        ADD     R14,R12,#VFPWS                  ; ptr to our register store
        LDMIA   R14,{R0-R10}                    ; reload R0-R10
        LDR     R12,[R14,#12*4]                 ; load R12
        BL      ASMEXPR                         ; parse expression
        SUB     AELINE,AELINE,#1                ; go back a char as it parses one extra
        LDMFD   R13!,{R1-R10,R12,R14}           ; restore registers
        MOV     R15,R14                         ; exit...

        ; *****************************
        ; **                         **
        ; ** Process Immediate Value **
        ; **                         **
        ; *****************************
VFPop_immediate
        ADD     R9,R9,#1                        ; skip # char

        LDRB    R0,[AELINE],#1                  ; ensure # in input
        TEQ     R0,#"#"                         ; ...
        BNE     VFPopp_nomatch                  ; if not, no match...

        BIC     R8,R8,#VFPms_immmask            ; clear all bit flags

        MOV     R0,#0                           ; init
        STR     R0,[R12,#VFPWS_immshift]        ; clear shift
        MOV     R7,#0                           ; clear number of bits
        MOV     R6,#1                           ; clear max
        MOV     R5,#1                           ; clear min

        BL      VFPop_imm_bits                  ; read bits from pattern

        BL      VFPop_imm_encode                ; encode the value
        BNE     VFPopp_nomatch                  ; if NE, no match...

        B       VFPopp_match                    ; match...

        ; ***********************************
        ; ** Calc Number of Bits and Flags **
        ; ***********************************
VFPop_imm_bits
        LDRB    R0,[R9],#1
        TEQ     R0,#"c"
        BEQ     VFPop_imm_c
        TEQ     R0,#"d"
        BEQ     VFPop_imm_d
        TEQ     R0,#"e"
        BEQ     VFPop_imm_e
        TEQ     R0,#"f"
        BEQ     VFPop_imm_f
        TEQ     R0,#"g"
        BEQ     VFPop_imm_g
        TEQ     R0,#"h"
        BEQ     VFPop_imm_h

        TEQ     R0,#"+"                         ; +- ?
        ORREQ   R8,R8,#VFPms_immpm              ; if yes, set the +- flag
        ADDEQ   R9,R9,#2                        ; , skip +- chars
        TEQ     R0,#"-"                         ; - ?
        ORREQ   R8,R8,#VFPms_immneg             ; if yes, set neg flag (stores -value when encoding)
        ADDEQ   R9,R9,#1                        ; , skip - char

        LDRB    R0,[R9,#-1]                     ; read 1st char
        SUB     R0,R0,#"0"                      ; make binary
        LDRB    R1,[R9]                         ; read 2nd char
        CMP     R1,#"0"                         ; digit?
        RSBGES  R2,R1,#"9"
        ADDGE   R9,R9,#1                        ; if yes, skip 2nd char
        MOVGE   R2,#10                          ; , 1st char * 10
        MULGE   R0,R2,R0                        ; , ...
        SUBGE   R1,R1,#"0"                      ; , make 2nd binary
        ADDGE   R0,R0,R1                        ; , add 2nd char

        MOV     R7,R0                           ; store number of bits
        MOV     R6,R6,LSL R7                    ; set max to 1<<bits
        TST     R8,#VFPms_immpm                 ; +- ?
        MOVEQ   R5,#0                           ; if not, min is zero
        RSBNE   R5,R6,#0                        ; else  , min is - 1<<bits
        SUB     R6,R6,#1                        ; reduce max by 1

        ; look for factor/shift (only shift used - 29/06)

VFPop_imm_fsr
        LDRB    R0,[R9]                         ; load id
        TEQ     R0,#"s"                         ; shift?
        MOVNE   R15,R14                         ; if not, exit...
        ADD     R9,R9,#1                        ; skip 's'
        LDRB    R1,[R9],#1                      ; load value
        SUB     R1,R1,#"0"                      ; make binary
        STR     R1,[R12,#VFPWS_immshift]        ; store shift
        MOV     R15,R14                         ; exit...

VFPop_imm_c
        BIC     R8,R8,#VFPms_imm6               ; clear imm6 flag
        MOV     R7,#6                           ; bits = 6
        MOV     R6,#32                          ; max  = 32
        MOV     R5,#1                           ; min  = 1
        B       VFPop_imm_fsr                   ; look for fsr option...

VFPop_imm_d
        ORR     R8,R8,#VFPms_imm6               ; set imm6 flag
        LDR     R7,[R12,#VFPWS_OpData+(VFP_Op_size*4)] ; load dt size op value
        ADD     R7,R7,#3                        ; bits = dt size + 3
        MOV     R6,R6,LSL R7                    ; max  = 1<<bits
        MOV     R5,#1                           ; min  = 1
        B       VFPop_imm_fsr                   ; look for fsr option...
                                                
VFPop_imm_e                                     
        ORR     R8,R8,#VFPms_imm6               ; set imm6 flag
        LDR     R7,[R12,#VFPWS_OpData+(VFP_Op_size*4)] ; load dt size op value
        ADD     R7,R7,#2                        ; bits = dt size + 2
        MOV     R6,R6,LSL R7                    ; max = 1<<bits
        MOV     R5,#1                           ; min = 1
        B       VFPop_imm_fsr                   ; look for fsr option

VFPop_imm_f
        ORR     R8,R8,#VFPms_imm4               ; set imm4 flag
        LDR     R7,[R12,#VFPWS_OpData+(VFP_Op_size*4)] ; load dt size op value
        ADD     R7,R7,#3                        ; bits = dt size + 3
        MOV     R6,R6,LSL R7                    ; max = 1<<bits
        TEQ     R7,#4                           ; 4 bits?
        MOVEQ   R5,#0                           ; if yes, min = 0 (p895 ARM)
        MOVNE   R5,#1                           ; else  , min = 1
        B       VFPop_imm_fsr                   ; look for fsr option

VFPop_imm_g
        ORR     R8,R8,#VFPms_imm6               ; set imm6 flag
        LDR     R7,[R12,#VFPWS_OpData+(VFP_Op_size*4)] ; load dt size op value
        ADD     R7,R7,#3                        ; bits = dt size + 3
        RSB     R6,R6,R6,LSL R7                 ; max = (1<<bits)-1
        MOV     R5,#0                           ; min = 0
        B       VFPop_imm_fsr                   ; look for fsr option

VFPop_imm_h
        ORR     R8,R8,#VFPms_imm6               ; set imm6 flag
        LDR     R7,[R12,#VFPWS_OpData+(VFP_Op_size*4)] ; load dt size op value
        ADD     R7,R7,#3                        ; bits = dt size + 3
        RSB     R6,R6,R6,LSL R7                 ; max = (1<<bits)-1
        MOV     R5,#1                           ; min = 1
        B       VFPop_imm_fsr                   ; look for fsr option

        ; *******************************
        ; ** Encode the Immediate Read **
        ; *******************************
        ; R4 = immediate value supplied
        ; R5 = min
        ; R6 = max
        ; R7 = bits
        ; R8 = flags
VFPop_imm_encode
        STR     R14,[R13,#-4]!                  ; preserve link

        VFP_Debug "VFPop_imm_encode"
        VFP_DebugReg R5
        VFP_DebugReg R6
        VFP_DebugReg R7
        VFP_DebugReg R8

        TEQ     R7,#32                          ; all 32 bits?
        BEQ     VFPop_imm_enc_32bit             ; if yes, special encoding for full 32bit range of values

        BL      VFPop_expr                      ; read the constant value specified
        MOV     R4,R0                           ; store for later
        VFP_DebugReg R4

        CMP     R4,R5                           ; below min?
        BLT     VFPop_imm_enc_nomatch           ; if yes, no match...
        CMP     R4,R6                           ; above max?
        BGT     VFPop_imm_enc_nomatch           ; if yes, no match...

        LDR     R2,[R12,#VFPWS_immshift]        ; apply left shift
        MOV     R4,R4,LSL R2                    ; ...

        TST     R8,#VFPms_immpm                 ; plus/minus range?
        BNE     VFPop_imm_enc_regoffset         ; must be a register offset

        TST     R8,#VFPms_immneg                ; negate?
        MOVEQ   R0,R4                           ; if not, use value as is
        MVNNE   R0,R4                           ; else  , negate value
        RSB     R1,R4,#0                        ; calc imn  (0-imm)
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_imm*4)] ; store imm
        STR     R1,[R12,#VFPWS_OpData+(VFP_Op_imn*4)] ; store imn

        BL      VFPop_imm6                      ; encode imm6 if reqd
        BL      VFPop_imm4                      ; encode imm4 if reqd

VFPop_imm_enc_match
        LDRB    R0,[R9],#1                      ; read next char in pattern
        TEQ     R0,#">"                         ; must be ">"
        BNE     VFPError_Internal               ; if not, internal error...

        MOVS    R0,#0                           ; set EQ
        LDR     R15,[R13],#4                    ; exit...

VFPop_imm_enc_nomatch
        MOVS    R0,#1                           ; set NE
        LDR     R15,[R13],#4                    ; exit...

        ; ** Encode Register +- offset **
VFPop_imm_enc_regoffset
        MOVS    R0,R4                           ; value = ABS(value)
        RSBMI   R0,R0,#0                        ; ...
        MOVMI   R1,#0                           ; + U=0
        MOVPL   R1,#1                           ; - U=1
        STR     R1,[R12,#VFPWS_OpData+(VFP_Op_U*4)] ; store U flag
        TST     R0,#2_11                        ; word aligned?
        BNE     VFPError_RegOfstAlign           ; if not report error...
        MOV     R0,R0,LSR#2                     ; get offset in words
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_imm*4)] ; store in Op_imm
        B       VFPop_imm_enc_match             ; match...

        ; ** Encode '32bit' Value, filtering to opcmode **
VFPop_imm_enc_32bit
        MOV     R5,#0                           ; clear opcmode value

        LDRB    R0,[R12,#VFPWS_DT]
        LDRB    R1,[R12,#VFPWS_DTSize]

        VFP_Debug "VFPop_imm_enc_32bit"
        VFP_DebugReg R0
        VFP_DebugReg R1

        CMP     R0,#"F"
        BEQ     VFPop_ie32_f3264                ; Parse float immediate
        CMP     R1,#64
        BEQ     VFPop_ie32_i64                  ; Parse 64bit int immediate

        ; full 32bit number available
        BL      VFPop_expr                      ; read expression into R0

        TST     R8,#VFPms_immneg                ; negate?
        MVNNE   R0,R0                           ; if yes, negate the value read

        VFP_DebugReg R0

        MOVS    R1,R0                           ; R1 = ABS(R0)
        RSBMI   R1,R1,#0                        ; ...
        LDR     R2,[R12,#VFPWS_DTSize]          ; get dt size
        TEQ     R2,#0                           ; set?
        BEQ     VFPop_ie32_1                    ; if not, skip...

        CMP     R2,#16                          ; dt is 16 bits or less?
        MOVLE   R3,#1                           ; if yes, 1<<bits
        MOVLE   R3,R3,LSL R2                    ; , is max
        CMPLE   R3,R1                           ; , out of range?
        BLE     VFPError_ImmRange               ; if yes, report error...

VFPop_ie32_1
        TEQ     R2,#8                           ; 8 bits?
        ANDEQ   R0,R0,#255                      ; ensure 8 bits repeated
        ORREQ   R0,R0,R0,LSL#8                  ; ...
        ORREQ   R0,R0,R0,LSL#16                 ; ...
        TEQ     R2,#16                          ; 16 bits?
        MOVEQ   R0,R0,LSL#16                    ; ensure 16 bits repeated
        ORREQ   R0,R0,R0,LSR#16                 ; ...

        BL      VFPop_ie32_try                  ; Try and match a standard type

        B       VFPError_ImmRange               ; immediate out of range...

VFPop_ie32_try
        VFP_DebugReg R0
        VFP_DebugReg R2

        ADR     R2,VFPop_ie32tab                ; table entry 0
        BICS    R3,R0,#&FF                      ; b3=0,b2=0,b1=0
        ADDNE   R2,R2,#8                        ; table entry 1
        BICNES  R3,R0,#&FF00                    ; b3=0,b2=0,b0=0
        ADDNE   R2,R2,#8                        ; table entry 2
        BICNES  R3,R0,#&FF0000                  ; b3=0,b1=0,b0=0
        ADDNE   R2,R2,#8                        ; table entry 3
        BICNES  R3,R0,#&FF000000                ; b2=0,b1=0,b0=0
        BEQ     VFPop_ie32_ok                   ; if found, process...
                                                
        ADD     R2,R2,#8                        ; table entry 4
        AND     R3,R0,#&00FF                    ; b3=0,b2=b0,b1=0
        ORR     R3,R3,R3,LSL#16                 ; ...
        TEQ     R0,R3                           ; ...
        BEQ     VFPop_ie32_ok                   ; if found, process...
                                                
        ADD     R2,R2,#8                        ; table entry 5
        AND     R3,R0,#&FF00                    ; b3=b1, b2=0,b0=0
        ORR     R3,R3,R3,LSL#16                 ; ...
        TEQ     R0,R3                           ; ...
        BEQ     VFPop_ie32_ok                   ; if found, process...
                                                
        ADD     R2,R2,#8                        ; table entry 6
        AND     R3,R0,#&FF00                    ; b3=0,b2=0,b0=255
        ORR     R3,R3,#&00FF                    ; ...
        TEQ     R3,R0                           ; ...
        BEQ     VFPop_ie32_ok                   ; if found, process...
                                                
        ADD     R2,R2,#8                        ; table entry 7
        AND     R3,R0,#&FF0000                  ; b3=0,b1=255,b0=255
        ORR     R3,R3,#&00FF00                  ; ...
        ORR     R3,R3,#&0000FF                  ; ...
        TEQ     R3,R0                           ; ...
        BEQ     VFPop_ie32_ok                   ; if found, process...
                                                
        ADD     R2,R2,#8                        ; table entry 8
        AND     R3,R0,#&FF                      ; b3=b2=b1=b0
        ORR     R3,R3,R3,LSL#8                  ; ...
        ORR     R3,R3,R3,LSL#16                 ; ...
        TEQ     R3,R0                           ; ...
        BEQ     VFPop_ie32_ok                   ; if found, process...

        MOV     PC,LR

        ; matched an encoding
        ; R2 = ptr to opcmode entry to match
VFPop_ie32_ok
        MOV     R4,R0                           ; transfer value to store

        ; match opcmode string to table
        VFP_LDRH R6,R10,VFP_syn_encoding,R0,S   ; get encoding offset
        BEQ     VFPop_imm_enc_nomatch           ; paranoid check
        VFP_Ptr R6,R0                           ; make ptr
        VFP_LDRH R6,R6,VFP_enc_opcmodelist,R0,S ; get opcmode offset
        BEQ     VFPop_imm_enc_nomatch           ; if not set, no match...
        VFP_Ptr R6,R0                           ; make ptr
VFPop_ie32_opc1
        LDR     R0,[R6,#0]                      ; get first word
        TEQ     R0,#0                           ; 0?
        BEQ     VFPop_imm_enc_nomatch           ; if yes, no match...
        MOV     R3,#0                           ; init offset
        MOV     R5,#0                           ; init opcmode
VFPop_ie32_opc2
        LDRB    R0,[R2,R3]                      ; get byte from table
        LDRB    R1,[R6,R3]                      ; get byte from opcmode list
        TEQ     R0,#"x"                         ; x
        TEQNE   R1,#"x"                         ; or x?
        TEQNE   R0,R1                           ; or equal?
        ADDNE   R6,R6,#8                        ; if not, no match so next entry
        BNE     VFPop_ie32_opc1                 ; , loop...
                                                
        MOV     R5,R5,LSL#1                     ; shift opcmode left
        TEQ     R0,#"1"                         ; 1?
        TEQNE   R1,#"1"                         ; or 1?
        ORREQ   R5,R5,#1                        ; if yes, set current bit
                                                
        ADD     R3,R3,#1                        ; inc offset
        CMP     R3,#5                           ; more?
        BLT     VFPop_ie32_opc2                 ; if yes, loop...

        VFP_DebugStr R6
        VFP_DebugStr R2
        VFP_DebugReg R4
        VFP_DebugReg R5
        VFP_Debug ""

        ; matched!
        LDRB    R0,[R2,#6]                      ; load byte to use
        MOV     R0,R0,LSL#3                     ; turn into bit shift
        MOV     R4,R4,LSR R0                    ; get byte from number
        AND     R4,R4,#&FF                      ; ensure 1 byte

        ; store value found
        ; R4 = value to store
        ; R5 = opcmode
VFPop_ie32_store
        ;TST    R8,#VFPms_immneg                          ; negate reqd?
        ;MVNNE  R4,R4                                     ; if yes, imm=NOT(imm)
        STR     R4,[R12,#VFPWS_OpData+(VFP_Op_imm*4)]     ; store Op_imm
        STR     R5,[R12,#VFPWS_OpData+(VFP_Op_opcmode*4)] ; store Op_opcmode
        B       VFPop_imm_enc_match

        ; opcmode table for each encoding variation for 32bit constants
        ; <5 byte opcmode>,0, <byte to use>, 0
VFPop_ie32tab  DCB "x000x",0 ,0,0
        DCB     "x001x",0 ,1,0
        DCB     "x010x",0 ,2,0
        DCB     "x011x",0 ,3,0
        DCB     "x100x",0 ,0,0
        DCB     "x101x",0 ,1,0
        DCB     "x1100",0 ,1,0
        DCB     "x1101",0 ,2,0
        DCB     "01110",0 ,0,0

        ; encode 64bit integer from integer or string
VFPop_ie32_i64
        STMFD   R13!,{R2-R10,R12,R14}           ; preserve registers
        ADD     R14,R12,#VFPWS                  ; ptr to our register store
        LDMIA   R14,{R0-R10}                    ; reload R0-R10
        LDR     R12,[R14,#12*4]                 ; load R12
        BL      EXPR                            ; get expression
        TEQ     TYPE,#0
        BEQ     VFPop_ie32_i64_string           ; parse string
        BLMI    INTEGB
        MOV     R1,#0                           ; treat as unsigned? Will provide most compatability with string parsing. But means the only supported non-string constant will be 0?
VFPop_ie32_i64_int
        SUB     AELINE,AELINE,#1                ; go back a char as it parses one extra
        LDMFD   R13!,{R2-R10,R12,R14}           ; restore registers

        VFP_Debug "VFPop_ie32_i64_int"
        VFP_DebugReg R0
        VFP_DebugReg R1

        ; If this isn't a NEON instruction, it must be a VFP instruction
        ; Make sure we only try matching op 0 cmode 1111, as that's the only encoding supported for VFP
        VFP_LDRH R4,R10,VFP_syn_encoding,R5,S   ; get encoding offset
        BEQ     VFPop_imm_enc_nomatch           ; paranoid check
        VFP_Ptr R4,R5                           ; make ptr
        VFP_LDRH R4,R4,VFP_enc_flags,R5
        TST     R4,#VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2
        BEQ     VFPop_ie32_i64_try_01111

        TEQ     R0,R1
        BLEQ    VFPop_ie32_try                  ; Try matching one of the main patterns

        ; Try op 1, cmode 1110
        MOV     R4,#0
        MOV     R5,#0
        TST     R1,#&FF000000
        ORRNE   R4,R4,#128
        ORRNE   R5,R5,#&FF000000
        TST     R1,#&FF0000
        ORRNE   R4,R4,#64
        ORRNE   R5,R5,#&FF0000
        TST     R1,#&FF00
        ORRNE   R4,R4,#32
        ORRNE   R5,R5,#&FF00
        TST     R1,#&FF
        ORRNE   R4,R4,#16
        ORRNE   R5,R5,#&FF
        TEQ     R1,R5
        BNE     VFPop_ie32_i64_try_01111
        MOV     R5,#0
        TST     R0,#&FF000000
        ORRNE   R4,R4,#8
        ORRNE   R5,R5,#&FF000000
        TST     R0,#&FF0000
        ORRNE   R4,R4,#4
        ORRNE   R5,R5,#&FF0000
        TST     R0,#&FF00
        ORRNE   R4,R4,#2
        ORRNE   R5,R5,#&FF00
        TST     R0,#&FF
        ORRNE   R4,R4,#1
        ORRNE   R5,R5,#&FF
        TEQ     R0,R5
        MOVEQ   R5,#2_11110
        BEQ     VFPop_ie32_store

VFPop_ie32_i64_try_01111
        ; Try op 0, cmode 1111 (floating point constants)
        CMP     R0,R1                           ; Must be 32bit value
        MOVEQS  R0,R0,LSL #13                   ; Low bits must be clear
        BNE     VFPError_FPImmRange
        MOV     R4,#0
        TST     R1,#&80000000
        MOVNE   R4,#128
        AND     R0,R1,#&7E000000
        CMP     R0,#&3E000000
        ORREQ   R4,R4,#64
        CMPNE   R0,#&40000000
        BNE     VFPError_FPImmRange
        AND     R0,R1,#&01F80000
        ORR     R4,R4,R0,LSR #19
        MOV     R5,#2_01111
        B       VFPop_ie32_store

        ; Parse string to int
VFPop_ie32_i64_string
        MOV     R0,#&90000000                   ; read 64bit + check term chars
        STRB    R0,[CLEN]
        ADD     R1,ARGP,#STRACC
        LDR     R4,=&45444957                   ; "WIDE"
        SWI     OS_ReadUnsigned
        MOV     R0,R2
        MOV     R1,R3
        B       VFPop_ie32_i64_int

        LTORG

        ; encode 32/64bit float from fp value
VFPop_ie32_f3264
        STMFD   R13!,{R2-R10,R12,R14}           ; preserve registers
        ADD     R14,R12,#VFPWS                  ; ptr to our register store
        LDMIA   R14,{R0-R10}                    ; reload R0-R10
        LDR     R12,[R14,#12*4]                 ; load R12
        BL      EXPR                            ; get expression
        TEQ     TYPE,#0
        BEQ     ERTYPENUM
        BLPL    IFLT
        ; Convert to single precision
        [       FPOINT=0
        ASSERT  FACCX=R1
        SUBS    FACCX,FACCX,#2
        BLE     VFPop_ie32_f_small
        MOV     R1,FACCX,LSL #23
        ORR     R1,R1,FSIGN
        BIC     FACC,FACC,#&80000000
        ORR     R1,R1,FACC,LSR #8       ; XXX No rounding
        ; Branch back up to main pattern matching code
        MOV     R0,R1
        B       VFPop_ie32_i64_int
VFPop_ie32_f_small
        RSB     FACCX,FACCX,#9
        MOV     R1,FACC,LSR FACCX
        ORR     R1,R1,FSIGN
        ELIF    FPOINT=1
        STFS    FACC,[SP,#-4]!
        LDR     R1,[SP],#4
        ELIF    FPOINT=2
        ASSERT  FACC = 0
        FCVTSD  S0,FACC
        FPSCRCheck R1
        FMRS    R1,S0
        |
        !       1, "Unknown FPOINT setting"
        ]
        ; Branch back up to main pattern matching code
        MOV     R0,R1
        B       VFPop_ie32_i64_int


        ; *****************
        ; ** Encode imm6 **
        ; *****************
        ; R7 (bits) = 3,4,5 or 6
VFPop_imm6
        TST     R8,#VFPms_imm6                  ; create imm6?
        MOVEQ   R15,R14                         ; if not, exit...
        MOV     R0,#1                           ; imm6l =
        MOV     R0,R0,LSL R7                    ; 1<<bits
        RSB     R1,R4,R0,LSL #1                 ; imn OR 1<<bits
        ORR     R0,R0,R4                        ; imm OR 1<<bits
        AND     R1,R1,#2_111111                 ; make sure 6 bits max
        AND     R0,R0,#2_111111                 ; make sure 6 bits max
        STR     R1,[R12,#VFPWS_OpData+(VFP_Op_imm6r*4)] ; store imm6r
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_imm6l*4)] ; store imm6l
        MOV     R15,R14                         ; exit...

        ; *****************
        ; ** Encode imm4 **
        ; *****************
VFPop_imm4
        TST     R8,#VFPms_imm4                  ; create imm4?
        MOVEQ   R15,R14                         ; if not, exit...
        MOV     R0,#1                           ; imm4 =
        MOV     R0,R0,LSL R7                    ; 1<<bits
        SUB     R0,R0,R4                        ; - imm
        STR     R0,[R12,#VFPWS_OpData+(VFP_Op_imm4*4)] ; store imm4
        MOV     R15,R14                         ; exit...

        ; **************************************
        ; **                                  **
        ; ** Populate any Optional Parameters **
        ; **                                  **
        ; **************************************
        ; Entry
        ; R10 = syntax lookup
VFPParams
        STR     R14,[R13,#-4]!                  ; preserve link

        VFP_LDRH R9,R10,VFP_syn_params,R0,S     ; load params
        BEQ     VFPpars_exit                    ; if not set, exit...
        VFP_Ptr R9,R0                           ; make into ptr
VFPpars1
        LDR     R0,[R9,#0]                      ; end of param lists?
        TEQ     R0,#0                           ; ...
        BEQ     VFPpars_exit                    ; if yes, exit...

        LDRB    R8,[R9,#VFP_par_bitfields]      ; load bitfields count
        TEQ     R8,#0                           ; paranoid check!
        BEQ     VFPpars_next                    ; ...
        TEQ     R8,#1                           ; one bitfield?
        MOVEQ   R0,#0                           ; if yes, use it
        LDRNE   R0,[R12,#VFPWS_DTIndex]         ; else  , use datatype index
        CMP     R0,R8                           ; paranoid range check!
        BGE     VFPError_Internal               ; ...

        ADD     R7,R9,#VFP_par                  ; skip params header
        ADD     R7,R7,R0,LSL#VFP_bfshift        ; calc ptr to reqd bitfield
        BL      VFPBitField                     ; process bitfield

        LDRB    R1,[R9,#VFP_par_opnumber]       ; load op number
        CMP     R1,#VFP_OpCount                 ; paranoid range check!
        BGE     VFPError_Internal               ; ...
        ADD     R1,R12,R1,LSL#2                 ; get op data store ptr
        STR     R0,[R1,#VFPWS_OpData]           ; store value into op

VFPpars_next
        ADD     R9,R9,#VFP_par                  ; skip VFP_pararmlist header
        ADD     R9,R9,R8,LSL#VFP_bfshift        ; skip all bitfields
        B       VFPpars1                        ; loop to next entry...

VFPpars_exit
        LDR     R15,[R13],#4

        ; **********************
        ; ** Process Bitfield **
        ; **********************
        ; Entry
        ; R7 = ptr to bitfield record
        ; Exit
        ; R0 = bitfield value
VFPBitField
        LDR     R0,[R7,#VFP_bf_constant]        ; base constant
        LDR     R3,[R7,#VFP_bf_args]            ; bitfield args ptr
        TEQ     R3,#0                           ; set?
        MOVEQ   R15,R14                         ; if not, exit...
        VFP_Ptr R3,R1                           ; calc args ptr
VFPbf1
        LDR     R1,[R3]                         ; next entry
        TEQ     R1,#0                           ; end of list?
        MOVEQ   R15,R14                         ; if yes, exit...

        LDRB    R1,[R3,#VFP_bfa_opnumber]       ; op number
        ADD     R1,R12,R1,LSL#2                 ; calc op data store ptr
        LDR     R1,[R1,#VFPWS_OpData]           ; load op value

        LDRB    R2,[R3,#VFP_bfa_bitmask]        ; bit mask
        AND     R1,R1,R2                        ; extract required bits

        LDRB    R2,[R3,#VFP_bfa_shift]          ; left shift
        ANDS    R2,R2,#31                       ; ... (-1=31 etc)
        RSBNE   R2,R2,#32                       ; make right shift for ROR
        ORR     R0,R0,R1,ROR R2                 ; or extracted bits into constant

        ADD     R3,R3,#VFP_bfa                  ; move to next bitfield arg
        B       VFPbf1                          ; loop...

        ; ****************************
        ; **                        **
        ; ** Encode The Output Word **
        ; **                        **
        ; ****************************
        ; Entry
        ; R10 = syntax lookup
        ; Exit
        ; R0  = instruction!
VFPEncoding
        STR     R14,[R13,#-4]!                  ; preserve link
        VFP_LDRH R7,R10,VFP_syn_encoding,R0,S   ; get encoding offset
        BEQ     VFPError_Internal               ; if not set, internal error...
        VFP_Ptr R7,R0                           ; make ptr
        ADD     R7,R7,#VFP_enc                  ; skip encoding header
        BL      VFPBitField                     ; process bitfield
        LDR     R15,[R13],#4                    ; restore & exit...

      [ EnableVFPDebug
        ; ***********************************************
        ; ** Display contents of all ops for debugging **
        ; ***********************************************
VFPDebugOps
        STMFD   R13!,{R0-R6,R14}

        LDR     R1,[R12,#VFPWS+8*4]
        LDRB    R0,[R1,#BYTESM]
        TST     R0,#OPT_errors
        BEQ     VFPdbop_exit

        ADD     R4,R12,#VFPWS_OpData
        MOV     R5,#0
        ADR     R6,VFPdbop_table
VFPdbop1
        MOV     R0,R6
        SWI     XOS_Write0
        MOV     R0,#"-"
        SWI     XOS_WriteC
        MOV     R0,R5
        ADD     R1,R12,#VFPWS_Debug
        MOV     R2,#16
        SWI     XOS_ConvertHex2
        SWI     XOS_Write0
        MOV     R0,#"-"
        SWI     XOS_WriteC
        LDR     R0,[R4],#4
        ADD     R1,R12,#VFPWS_Debug
        MOV     R2,#16
        SWI     XOS_ConvertHex8
        SWI     XOS_Write0
        SWI     XOS_NewLine

        ADD     R6,R6,#16
        ADD     R5,R5,#1
        CMP     R5,#VFP_OpCount
        BLT     VFPdbop1

VFPdbop_exit
        LDMFD   R13!,{R0-R6,R15}

VFPdbop_table
        DCB     "VFP_Op_a       ",0
        DCB     "VFP_Op_align   ",0
        DCB     "VFP_Op_cond    ",0
        DCB     "VFP_Op_E       ",0
        DCB     "VFP_Op_esize   ",0
        DCB     "VFP_Op_F       ",0
        DCB     "VFP_Op_ia      ",0
        DCB     "VFP_Op_imm     ",0
        DCB     "VFP_Op_imm3    ",0
        DCB     "VFP_Op_imm4    ",0
        DCB     "VFP_Op_imm6l   ",0
        DCB     "VFP_Op_imm6r   ",0
        DCB     "VFP_Op_imn     ",0
        DCB     "VFP_Op_L       ",0
        DCB     "VFP_Op_len     ",0
        DCB     "VFP_Op_op      ",0
        DCB     "VFP_Op_opc     ",0
        DCB     "VFP_Op_opc2    ",0
        DCB     "VFP_Op_opcmode ",0
        DCB     "VFP_Op_P       ",0
        DCB     "VFP_Op_Q       ",0
        DCB     "VFP_Op_regcount",0
        DCB     "VFP_Op_Rt      ",0
        DCB     "VFP_Op_Ru      ",0
        DCB     "VFP_Op_sf      ",0
        DCB     "VFP_Op_size    ",0
        DCB     "VFP_Op_size1   ",0
        DCB     "VFP_Op_spec    ",0
        DCB     "VFP_Op_sx      ",0
        DCB     "VFP_Op_sz      ",0
        DCB     "VFP_Op_T       ",0
        DCB     "VFP_Op_type    ",0
        DCB     "VFP_Op_U       ",0
        DCB     "VFP_Op_Vd      ",0
        DCB     "VFP_Op_Vm      ",0
        DCB     "VFP_Op_Vmx     ",0
        DCB     "VFP_Op_Vn      ",0
        DCB     "VFP_Op_W       ",0
        DCB     "VFP_Op_x       ",0
      ]

VFP_SP_to_FACC
        ; Pop a single-precision float off the stack and load into FACC
      [ FPOINT=0
        ; Convert to 5-byte
        LDR     FACC,[R13],#4
        AND     FSIGN,FACC,#&80000000
        MOV     FACCX,FACC,LSR #23
        ANDS    FACCX,FACCX,#&FF
        MOV     FACC,FACC,LSL #8
        BEQ     VFP_SP_to_FACC_small
        ORR     FACC,FACC,#&80000000
        ADD     FACCX,FACCX,#2
        MOV     PC,LR
VFP_SP_to_FACC_small
        ; Denormalised number
        TST     FACC,#&40000000
        MOVNE   FACC,FACC,LSL #1
        MOVNE   FACCX,#2
        MOVNE   PC,LR
        TST     FACC,#&20000000
        MOVNE   FACC,FACC,LSL #2
        MOVNE   FACCX,#1
        MOVEQ   FACC,FACC,LSL #3
        ; FACCX already 0 for EQ case
        MOV     PC,LR
        ELIF    FPOINT=1
        LDFS    FACC,[SP],#4
        MOV     PC,LR
        ELIF    FPOINT=2
        ASSERT  FACC = 0
        FLDS    S0,[SP],#4
        FCVTDS  FACC,S0
        MOV     PC,LR
      ]

strcpy  ; Copy null-terminated string from R1 to R0
        ; Corrupts R1-R2, returns ptr to terminator in R0
        LDRB    R2,[R1],#1
        CMP     R2,#0
        STRB    R2,[R0],#1
        BNE     strcpy
        SUB     R0,R0,#1
        MOV     PC,LR

 ] ; :DEF: VFPAssembler

; Include the next part of the code
        LNK     Lexical.s
