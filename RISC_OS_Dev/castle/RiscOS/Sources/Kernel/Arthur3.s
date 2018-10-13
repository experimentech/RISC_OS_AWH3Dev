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
        TTL     => Arthur3

; the IF command

IF_Code    ROUT
        Push    "R2, lr"
        LDR     R2, =GeneralMOSBuffer
01
        LDRB    R1, [R0], #1
        STRB    R1, [R2], #1
        CMP     R1, #10
        CMPNE   R1, #13
        CMPNE   R1, #0
        BEQ     NoTHEN
        CMP     R1, #" "
        BNE     %BT01
        LDRB    R1, [R0]
        CMP     R1, #"t"
        CMPNE   R1, #"T"
        BNE     %BT01
        LDRB    R1, [R0, #1]
        CMP     R1, #"h"
        CMPNE   R1, #"H"
        BNE     %BT01
        LDRB    R1, [R0, #2]
        CMP     R1, #"e"
        CMPNE   R1, #"E"
        BNE     %BT01
        LDRB    R1, [R0, #3]
        CMP     R1, #"n"
        CMPNE   R1, #"N"
        BNE     %BT01
        LDRB    R1, [R0, #4]
        CMP     R1, #" "
        CMPNE   R1, #13
        CMPNE   R1, #10
        CMPNE   R1, #0
        BNE     %BT01
        MOV     R1, #13
        STRB    R1, [R2, #-1]
        ADD     R0, R0, #4              ; skip THEN
        Push    "R0"
        LDR     R0, =GeneralMOSBuffer
        MOV     R2, #-1    ; integers only mate
        SWI     XOS_EvaluateExpression
        BVS     WantInteger
        Pull    "R1"
        CMP     R2, #0
        BEQ     %FT02                   ; false
        LDR     R2, =GeneralMOSBuffer
03
        LDRB    R0, [R1], #1
        STRB    R0, [R2], #1
        CMP     R0, #10
        CMPNE   R0, #13
        CMPNE   R0, #0
        BEQ     %FT04
        CMP     R0, #" "
        BLEQ    %FT05
        BNE     %BT03
04
        MOV     R0, #13
        STRB    R0, [R2, #-1]
        LDR     R0, =GeneralMOSBuffer
07
        SWI     XOS_CLI
06
        Pull    "R2, PC"

05
        LDRB    R0, [R1]
        CMP     R0, #"e"
        CMPNE   R0, #"E"
        MOVNE   PC, lr
        LDRB    R0, [R1, #1]
        CMP     R0, #"l"
        CMPNE   R0, #"L"
        MOVNE   PC, lr
        LDRB    R0, [R1, #2]
        CMP     R0, #"s"
        CMPNE   R0, #"S"
        MOVNE   PC, lr
        LDRB    R0, [R1, #3]
        CMP     R0, #"e"
        CMPNE   R0, #"E"
        MOVNE   PC, lr
        LDRB    R0, [R1, #4]
        CMP     R0, #" "
        CMPNE   R1, #13
        CMPNE   R1, #10
        CMPNE   R1, #0
        MOV     PC, lr

02
        LDRB    R0, [R1], #1
        CMP     R0, #10
        CMPNE   R0, #13
        CMPNE   R0, #0
        BEQ     %BT06
        CMP     R0, #" "
        BLEQ    %BT05
        BNE     %BT02
        ADD     R0, R1, #4
        B       %BT07

NoTHEN  ROUT
        ADR     R0, %FT01
      [ International
        BL      TranslateError
      ]
IfError
        SETV
        Pull    "R2, pc"
01
        &       ErrorNumber_Syntax
        =       "NoThen:There is no THEN", 0
        ALIGN

WantInteger ROUT
        CMP     R1, #0
        Pull    "R1"
        BNE     %FT10
        SETV
        Pull    "R2, pc"               ; integer returned, so leave expranal error there
10
        ADR     R0, %FT01
      [ International
        BL      TranslateError
      ]
        B       IfError
01
        &       ErrorNumber_Syntax
        =       "IsString:Expression is a string", 0
        ALIGN

;************************************************************************
; the expression analysis SWI

; truth values
Expr_True  *  -1
Expr_False *   0

; Type symbols

type_Integer  * 0
type_String   * 1
type_Operator * 2

; operators :
; single char syms have their ascii value
op_Bra     * "("   ; 40
op_Ket     * ")"   ; 41
op_Times   * "*"   ; 42
op_Plus    * "+"   ; 43
op_Minus   * "-"   ; 45
op_Divide  * "/"   ; 47
op_LT      * "<"   ; 60
op_EQ      * "="   ; 61
op_GT      * ">"   ; 62

; now fill in some gaps

op_NE      * 44    ; <>
op_STR     * 46    ; STR
op_GE      * 48    ; >=
op_LE      * 49    ; <=
op_RShift  * 50    ; >>
op_LShift  * 51    ; <<
op_AND     * 52    ; AND
op_OR      * 53    ; OR
op_EOR     * 54    ; EOR
op_NOT     * 55    ; NOT
op_Right   * 56    ; RIGHT
op_Left    * 57    ; LEFT
op_MOD     * 58    ; MOD
op_Bottom  * 59
op_VAL     * 63    ; VAL
op_LRShift * 64    ; >>>
op_LEN     * 65    ; LEN

; TMD 12-Sep-89 - add separate tokens for monadic versions of + and -

op_UnaryPlus * 66  ; unary plus
op_UnaryMinus * 67 ; unary minus

; so 40-67 inclusive is filled.

        MACRO
$label  ePush   $reglist
        LCLS    temps
        LCLL    onereg
temps   SETS    "$reglist"
onereg  SETL    {TRUE}
        WHILE   onereg :LAND: :LEN: temps > 0
        [ temps :LEFT: 1 = "," :LOR: temps :LEFT: 1 = "-"
onereg  SETL    {FALSE}
        ]
temps   SETS    temps :RIGHT: (:LEN: temps - 1)
        WEND
      [ onereg
$label  STR     $reglist, [R11, #-4]!
      |
$label  STMFD   R11!, {$reglist}
      ]
        CMP     R11, R10
        BLE     StackOFloErr
        MEND

        MACRO
$label  ePull   $reglist, $writeback, $cc
        LCLS    temps
        LCLL    onereg
temps   SETS    "$reglist"
onereg  SETL    {TRUE}
        WHILE   onereg :LAND: :LEN: temps > 0
        [ temps :LEFT: 1 = "," :LOR: temps :LEFT: 1 = "-"
onereg  SETL    {FALSE}
        ]
temps   SETS    temps :RIGHT: (:LEN: temps - 1)
        WEND
    [ onereg
      [ "$writeback" = ""
        LDR$cc     $reglist, [R11], #4
      |
        LDR$cc     $reglist, [R11]
      ]
    |
      [ "$writeback" = ""
        LDM$cc.FD  R11!, {$reglist}
      |
        LDM$cc.FD  R11, {$reglist}
      ]
    ]
        MEND

;*************************************************************************
; SWI EvalExp.
; In  : R0 -> string
;       R1 -> buffer
;       R2 maxchars
; Out : R0 unchanged.
;       IF R1 = 0, R2 is an integer
;       IF R1<>0, buffer has a string, length in R2.
;       V set if bad expression, buffer overflow
;*************************************************************************

ExprBuffOFlo ROUT
        ADRL    R0, ErrorBlock_BuffOverflow
      [ International
        BL      TranslateError
      ]
        STR     R0, [stack]
        Pull    "R0-R4, lr"
        B       SLVK_SetV

ReadExpression ROUT
        Push    "R0-R4, lr"
        CLRPSR  I_bit, R12    ; interrupts on, ta.
        LDR     R12, =ExprWSpace
        STR     R13, ExprSVCstack
        LDR     R1, =ExprBuff
        MOV     R2, #LongCLISize
        ORR     R2, R2, #(1 :SHL: 30) :OR: (1 :SHL: 31)
        SWI     XOS_GSTrans   ; No | transformation, no " or space termination.
                              ; so can never go wrong!
        BCS     ExprBuffOFlo
        MOV     R0, #13
        STRB    R0, [R1, R2]

        LDR     R11, =ExprStackStart
        LDR     R10, =ExprStackLimit
        MOV     R0, #0
        STRB    R0, exprBracDif
        MOV     R0, #type_Operator
        MOV     R2, #op_Bottom
        STRB    R2, tos_op
        STMFD   R11!, {R0, R2}  ; push "bottom"

; All set : now chug round items.

01
        BL      GetFactor
        CMP     R0, #type_Operator
        BNE     %BT01

        CMP     R2, #op_Ket
        BNE     %FT02
        LDRB    R3, exprBracDif
 [ {TRUE}                       ; TMD 11-Sep-89 - save an instruction
        SUBS    R3, R3, #1
        BCC     BadBraErr
 |
        CMP     R3, #0
        BEQ     BadBraErr
        SUB     R3, R3, #1
 ]
        STRB    R3, exprBracDif

03
        LDRB    R3, tos_op
        CMP     R3, #op_Bra
        BEQ     %FT55
        BL      compile_top_op
        B       %BT03
55
        ePull   "R0, R2"
        CMP     R0, #type_Operator
        BEQ     MissingOpErr
        CMP     R0, #type_String
        BLEQ    Pull_String
        Push    "R0, R2"
        ePull   "R0, R2"
        CMP     R0, #type_Operator
        BNE     MissingOrErr    ; discard "("
        ePull   "R0, R2", No
        CMP     R0, #type_Operator
        BNE     MissingOrErr
        STRB    R2, tos_op      ; reset tosop
        Pull    "R0, R2"
        CMP     R0, #type_String
        BLEQ    Push_String
        ePush   "R0, R2"        ; move temp result down.
        B       %BT01

02
        CMP     R2, #op_Bra
        LDREQB  R3, exprBracDif
        ADDEQ   R3, R3, #1
        STREQB  R3, exprBracDif ; bracdif +:= 1

; TMD 12-Sep-89 - now check for unary plus or minus

        CMP     R2, #op_Plus                    ; if EQ then CS
        TEQNE   R2, #(op_Minus :SHL: 2),2       ; if EQ then CC
        ePull   "R0, R4", No, EQ                ; if +/- and top item is op
        TEQEQ   R0, #type_Operator, 0           ; then it's unary plus/minus
        BNE     %FT10                           ; else normal

        MOVCS   R2, #op_UnaryPlus               ; CS => unary plus
        MOVCC   R2, #op_UnaryMinus              ; CC => unary minus
10

;  WHILE lp (tos.op) > rp (itemtype) DO compile.top.op ()

        ADR     R4, rightprectab-op_Bra
        LDRB    R4, [R4, R2]
04
        ADR     R0, leftprectab-op_Bra
        LDRB    R3, tos_op
        LDRB    R0, [R0, R3]
        CMP     R0, R4
        BLE     %FT75
        BL      compile_top_op
        B       %BT04
75
        MOV     R0, #type_Operator
        ePush   "R0, R2"        ;  push (operator)
        STRB    R2, tos_op
        CMP     R2, #op_Bottom
        BNE     %BT01

; check proper expr, return it.
; should have bum/result/bum on stack.

        ePull   "R0, R2"        ; this one's forced to be bottom
        ePull   "R0, R2"
        CMP     R0, #type_Operator
        BEQ     MissingOpErr
        CMP     R0, #type_String
        BLEQ    Pull_String
        Push    "R0, R2"
        ePull   "R0, R2"
        CMP     R0, #type_Operator ; if an op's there, it has to be bottom
        Pull    "R1, R2"
        BNE     MissingOpErr

        Pull    "R0, R3, R4"    ; original R1, R2 -> R3, R4
        CMP     R1, #type_Integer
        Pull    "R3, R4, lr", EQ
        ExitSWIHandler EQ
        CMP     R4, R2
        BGE     ExprBuffOK
        MOV     R2, R4          ; no chars to move.
        ADRL    R0, BufferOFloError
        LDR     lr, [stack, #4*2]
        ORR     lr, lr, #V_bit
        STR     lr, [stack, #4*2]
ExprBuffOK
        MOV     R1, R3
        LDR     R4, =exprSTRACC ; get ptr to it.
        Push    "R2"
06
        SUBS    R2, R2, #1
        LDRPLB  R3, [R4, R2]
        STRPLB  R3, [R1, R2]
        BPL     %BT06
        Pull    "R2-R4, lr"
        ExitSWIHandler

leftprectab
;    Bra  Ket  Time Plus NE   Minu STR  Divi GE   LE   RShi LShift
   = 2,   1,   8,   7,   6,   7,   9,   8,   6,   6,   6,   6
;    AND  OR   EOR  NOT  Righ Left MOD  Bott LT   EQ   GT   VAL LRSh
   = 5,   4,   4,   9,   9,   9,   8,   1,   6,   6,   6,   9,  6
;    LEN  Un+  Un-
   = 9,   9,   9

rightprectab
;    Bra  Ket  Time Plus NE   Minu STR  Divi GE   LE   RShi LShift
   = 11,  0,   7,   6,   5,   6,   10,  7,   5,   5,   5,   5
;    AND  OR   EOR  NOT  Righ Left MOD  Bott LT   EQ   GT   VAL LRSh
   = 4,   3,   3,   10,  10,  10,  7,   1,   5,   5,   5,   10, 5
;    LEN  Un+  Un-
   = 10,  10,  10

    ALIGN

;*****************************************************************************

compile_top_op ROUT
; corrupts the flags
        Push    "R2-R4, lr"
        ePull   "R0, R2"
        CMP     R0, #type_Operator
        BEQ     MissingOpErr            ; everybody needs a rhs op
        CMP     R0, #type_String
        BLEQ    Pull_String
        ePull   "R3, R4"                ; must be tosop
        CMP     R3, #type_Operator
        BNE     MissingOrErr

        SUB     R4, R4, #op_Bra
        ADR     R3, Operator_Dispatch
        LDR     R4, [R3, R4, LSL #2]
        ADD     PC, R3, R4

DispatchReturn
        ePull   "R3, R4", No            ; pull with no writeback
        CMP     R3, #type_Operator
        BNE     MissingOrErr
        STRB    R4, tos_op
        CMP     R0, #type_String
        BLEQ    Push_String
        ePush   "R0, R2"                ; temp val -> stack

        Pull    "R2-R4, PC"

; the routines in this table are entered with one operand popped,
; any other op on stack ready to pop.
; Return with temp val set up (R0, R2 and maybe exprSTRACC)
; Can use R0, R2-R4 as reqd

Operator_Dispatch
        &       Bra_Code - Operator_Dispatch
        &       0  ;  Ket_Code - Operator_Dispatch - can't happen
        &       Times_Code - Operator_Dispatch
        &       Plus_Code - Operator_Dispatch
        &       NE_Code - Operator_Dispatch
        &       Minus_Code - Operator_Dispatch
        &       STR_Code - Operator_Dispatch
        &       Divide_Code - Operator_Dispatch
        &       GE_Code - Operator_Dispatch
        &       LE_Code - Operator_Dispatch
        &       RShift_Code - Operator_Dispatch
        &       LShift_Code - Operator_Dispatch
        &       AND_Code - Operator_Dispatch
        &       OR_Code - Operator_Dispatch
        &       EOR_Code - Operator_Dispatch
        &       NOT_Code - Operator_Dispatch
        &       Right_Code - Operator_Dispatch
        &       Left_Code - Operator_Dispatch
        &       MOD_Code - Operator_Dispatch
        &       0   ; Bottom_Code - Operator_Dispatch - can't happen
        &       LT_Code - Operator_Dispatch
        &       EQ_Code - Operator_Dispatch
        &       GT_Code - Operator_Dispatch
        &       VAL_Code - Operator_Dispatch
        &       LRShift_Code- Operator_Dispatch
        &       LEN_Code- Operator_Dispatch
        &       UnPlus_Code- Operator_Dispatch
        &       UnMinus_Code- Operator_Dispatch

;**************************************************************************
; dispatch  routines

;--------------------------------------------------------------------------
; monadic operators

VAL_Code    ROUT  ; VAL string (VAL integer is NOP)
UnPlus_Code ROUT  ; + integer (same code as VAL)
        CMP     R0, #type_String
        BLEQ    StringToInteger
        B       DispatchReturn

STR_Code ROUT  ; STR integer (STR string is NOP)
        CMP     R0, #type_Integer
        BLEQ    IntegerToString
        B       DispatchReturn

LEN_Code ROUT  ; LEN string
        CMP     R0, #type_Integer
        BLEQ    IntegerToString
        MOV     R0, #type_Integer   ; and R2 is length!
        B       DispatchReturn

NOT_Code     ROUT  ; NOT integer
        CMP     R0, #type_String
        BLEQ    StringToInteger
        MVN     R2, R2
        B       DispatchReturn

UnMinus_Code ROUT ; - integer
        CMP     R0, #type_String
        BLEQ    StringToInteger
        RSB     R2, R2, #0
        B       DispatchReturn

;--------------------------------------------------------------------------
; diadic plus

Plus_Code       ROUT  ; integer+integer ; string+string
        ePull   "R3, R4"
;       CMP     R3, #type_Operator      ; can't be operator as unary plus
;       BEQ     %FT01                   ; is separately dispatched now
        CMP     R0, #type_String
        BEQ     %FT02
        CMP     R3, #type_String
        BLEQ    PullStringToInteger     ; in R4
        ADD     R2, R2, R4
        B       DispatchReturn

02
        CMP     R3, #type_String
        BEQ     %FT03
        BL      StringToInteger
        ADD     R2, R2, R4
        B       DispatchReturn

03
        ADD     R0, R2, R4
        CMP     R0, #LongCLISize
        BGE     StrOFloErr
        LDR     R3, =exprSTRACC
        Push    "R0"                    ; new length
        ADD     R0, R3, R0
        ADD     R3, R3, R2
  ; copy R2 bytes from --(R3) to --(R0)
04
        SUBS    R2, R2, #1
        LDRGEB  R4, [R3, #-1]!
        STRGEB  R4, [R0, #-1]!
        BGE     %BT04
; R0-exprSTRACC is no of chars in stacked string
        LDR     R3, =exprSTRACC
        SUB     R0, R0, R3
05
        SUBS    R0, R0, #1
        LDRGEB  R2, [R11], #1
        STRGEB  R2, [R3], #1
        BGE     %BT05
        ADD     R11, R11, #3
        BIC     R11, R11, #3            ; realign stack
        Pull    "R2"
        MOV     R0, #type_String
        B       DispatchReturn

Minus_Code    ROUT  ; integer-integer
;       ePull   "R3, R4", No            ; can't be unary minus - this is
;       CMP     R3, #type_Operator      ; separately dispatched now
;       BEQ     %FT01
        BL      TwoIntegers
        SUB     R2, R4, R2
        B       DispatchReturn

;---------------------------------------------------------------------------
; integer pair only : maths

Times_Code   ROUT  ; integer*integer
        BL      TwoIntegers
        MOV     R3, R2
        MUL     R2, R4, R3              ; get R3*R4->R2
        B       DispatchReturn

MOD_Code     ROUT  ; integer MOD integer
        Push    "R5"
        MOV     R5, #&80000000
        B       DivModCommon

Divide_Code  ROUT  ; integer/integer
        Push    "R5"
        MOV     R5, #0
DivModCommon
        BL      TwoIntegers             ; want R4/R2
        CMP     R2, #0
        Pull    "R5", EQ
        BEQ     DivZeroErr
        RSBMI   R2, R2, #0
        EORMIS  R5, R5, #1
        EORMI   R5, R5, #1              ; oops-wanted MOD, ignore this sign
        CMP     R4, #0
        EORMI   R5, R5, #1
        RSBMI   R4, R4, #0
        DivRem  R3, R4, R2, R0          ; R3 := R4 DIV R2; R4 := R4 REM R2
        MOVS    R5, R5, LSL #1          ; CS if MOD, NE if -ve
        MOVCS   R2, R4
        MOVCC   R2, R3
        RSBNE   R2, R2, #0
        MOV     R0, #type_Integer
        Pull    "R5"
        B       DispatchReturn

;---------------------------------------------------------------------------
; integer pair only : logical

AND_Code ROUT                   ; integer AND integer
        BL      TwoIntegers
        AND     R2, R2, R4
        B       DispatchReturn

OR_Code ROUT                    ; integer OR integer
        BL      TwoIntegers
        ORR     R2, R2, R4
        B       DispatchReturn

EOR_Code ROUT                   ; integer EOR integer
        BL      TwoIntegers
        EOR     R2, R2, R4
        B       DispatchReturn

;----------------------------------------------------------------------------
; mixed operands

Right_Code ROUT                 ; string RIGHT integer
        CMP     R0, #type_Integer
        BLNE    StringToInteger
        MOV     R4, R2
        ePull   "R0, R2"
        CMP     R0, #type_String
        BNE     %FT01
        BL      Pull_String
02   ; string in stracc, R2 chars available, R4 chars wanted.
        CMP     R2, R4
        BLO     DispatchReturn  ; ignore if R4 -ve or bigger than available
        LDR     R0, =exprSTRACC
        ADD     R3, R0, R2
        SUB     R3, R3, R4      ; mov from R3 to R0, R4 bytes
03
        LDRB    R2, [R3], #1
        SUBS    R4, R4, #1
        STRGEB  R2, [R0], #1
        BGE     %BT03
        LDR     R2, =exprSTRACC
        SUB     R2, R0, R2  ; get length back.
        MOV     R0, #type_String
        B       DispatchReturn

01
        CMP     R0, #type_Operator
        BEQ     MissingOpErr
        BL      IntegerToString
        B       %BT02

Left_Code ROUT                  ; string LEFT integer
        CMP     R0, #type_Integer
        BLNE    StringToInteger
        MOV     R4, R2
        ePull   "R0, R2"
        CMP     R0, #type_String
        BNE     %FT01
        BL      Pull_String
02
        CMP     R4, R2
        MOVLO   R2, R4          ; only use new length if +ve and < current length
        B       DispatchReturn

01
        CMP     R0, #type_Operator
        BEQ     MissingOpErr
        BL      IntegerToString
        B       %BT02

;-----------------------------------------------------------------------
; relational operators

EQ_Code ROUT                    ; integer = integer ; string = string
        BL      Comparison
        MOVEQ   R2, #Expr_True
        MOVNE   R2, #Expr_False
        B       DispatchReturn

NE_Code ROUT                    ; integer<>integer ; string<>string
        BL      Comparison
        MOVNE   R2, #Expr_True
        MOVEQ   R2, #Expr_False
        B       DispatchReturn

GT_Code ROUT                    ; integer > integer ; string>string
        BL      Comparison
        MOVGT   R2, #Expr_True
        MOVLE   R2, #Expr_False
        B       DispatchReturn

LT_Code ROUT                    ; integer < integer ; string<string
        BL      Comparison
        MOVLT   R2, #Expr_True
        MOVGE   R2, #Expr_False
        B       DispatchReturn

GE_Code ROUT                    ; integer >= integer ; string>=string
        BL      Comparison
        MOVGE   R2, #Expr_True
        MOVLT   R2, #Expr_False
        B       DispatchReturn

LE_Code ROUT                    ; integer <= integer ; string<=string
        BL      Comparison
        MOVLE   R2, #Expr_True
        MOVGT   R2, #Expr_False
        B       DispatchReturn

;--------------------------------------------------------------------------
; shift operators

RShift_Code ROUT                ; integer >> integer
        BL      TwoIntegers
        CMP     R2, #0
        RSBLT   R2, R2, #0
        BLT     NegRShift
NegLShift
        CMP     R2, #32
        MOVGE   R2, R4, ASR #31 ; sign extend all through
        MOVLT   R2, R4, ASR R2
        B       DispatchReturn

LRShift_Code ROUT               ; integer >>> integer
        BL      TwoIntegers
        CMP     R2, #0
        RSBLT   R2, R2, #0
        BLT     NegRShift
        CMP     R2, #32
        MOVGE   R2, #0
        MOVLT   R2, R4, LSR R2
        B       DispatchReturn

LShift_Code ROUT                ; integer << integer
        BL      TwoIntegers
        CMP     R2, #0
        RSBLT   R2, R2, #0
        BLT     NegLShift
NegRShift
        CMP     R2, #32
        MOVGE   R2, #0
        MOVLT   R2, R4, LSL R2
        B       DispatchReturn

;---------------------------------------------------------------------------
; Support routines :

TwoIntegers   ROUT
        Push    "lr"
        CMP     R0, #type_String
        BLEQ    StringToInteger
        ePull   "R3, R4"
        CMP     R3, #type_Operator
        BEQ     MissingOpErr
        CMP     R3, #type_String
        BLEQ    PullStringToInteger
        Pull    "PC"

Comparison    ROUT
        Push    "lr"
        ePull   "R3, R4"
        CMP     R3, #type_Operator
        BEQ     MissingOpErr
        CMP     R0, #type_String
        BEQ     %FT01
        CMP     R3, #type_String
        BLEQ    PullStringToInteger
        CMP     R4, R2
        Pull    "PC"

01
        CMP     R3, #type_String
        BEQ     %FT02
        BL      StringToInteger
        CMP     R4, R2
        Pull    "PC"

02
        MOV     R3, R11
        ADD     R11, R11, R4
        ADD     R11, R11, #3
        BIC     R11, R11, #3
;    $R3, length R4 against $exprSTRACC, length R2
        Push    "R1, R2, R4, R5"
        CMP     R2, R4
        MOVGT   R2, R4                  ; minm length -> R2
        LDR     R0, =exprSTRACC
03
        SUBS    R2, R2, #1
        BLT     %FT04
        LDRB    R1, [R0], #1
        LDRB    R5, [R3], #1
        CMP     R5, R1
        BEQ     %BT03
        MOV     R0, #type_Integer
        Pull    "R1, R2, R4, R5, PC"

04
        Pull    "R1, R2, R4, R5"
        CMP     R4, R2
        MOV     R0, #type_Integer
        Pull    "PC"

StringToInteger ROUT
        Push    "R1, R3, R4, lr"
        LDR     R1, =exprSTRACC
        ADD     R3, R1, R2              ; end pointer to check all string used.
        MOV     R0, #13
        STRB    R0, [R1, R2]            ; force terminator in
01
        LDRB    R0, [R1], #1
        CMP     R0, #" "
        BEQ     %BT01
        MOV     R4, #0
        CMP     R0, #"-"
        MOVEQ   R4, #-1
        CMPNE   R0, #"+"
        SUBNE   R1, R1, #1
        MOV     R0, #10
        SWI     XOS_ReadUnsigned
02
        LDRB    R0, [R1], #1
        CMP     R0, #" "
        BEQ     %BT02
        SUB     R1, R1, #1
        CMP     R1, R3
        BNE     BadIntegerErr
        MOV     R0, #type_Integer
        CMP     R4, #0
        RSBNE   R2, R2, #0
        Pull    "R1, R3, R4, PC"

IntegerToString ROUT
        Push    "R1, lr"
        MOV     R0, R2
        LDR     R1, =exprSTRACC
        MOV     R2, #LongCLISize
        SUB     R2, R2, #1
        SWI     XOS_BinaryToDecimal
        MOV     R0, #type_String
        Pull    "R1, PC"

PullStringToInteger ROUT        ; corrupts exprSTRACC
        Push    "R0, R2, lr"
        MOV     R2, R4
        BL      Pull_String
        BL      StringToInteger
        MOV     R4, R2
        MOV     R3, #type_Integer
        Pull    "R0, R2, PC"

;******************************************************************************

GetFactor ROUT
; return type in R0
; if operator, R2 has op_xxx
; if integer/string, it has been pushed
; R1 updated, R2 corrupted.

10
        LDRB    R0, [R1], #1
        CMP     R0, #" "
        BEQ     %BT10

        CMP     R0, #13
        BNE     %FT11
        MOV     R2, #op_Bottom
        MOV     R0, #type_Operator
        MOV     PC, lr

31
        CMP     R0, #"@"-1      ; chars >= "@" are OK
        BGT     %FT32
        CMP     R0, #" "        ; chars <= " " always terminate
        MOVLE   PC, lr
        Push    "R2, R3"
        ADR     R2, terminatename_map-"!"
        LDRB    R3, [R2, R0]    ; termination map for " " < char < "@"
        CMP     R3, #0
        Pull    "R2, R3"
        MOVEQ   PC, lr
32
        STRB    R0, [R3], #1
        MOV     PC, lr          ; return with GT for OK, LE for naff

terminatename_map       ; 1 means character allowed
        ;  !  "  #  $  %  &  '  (  )  *  +  ,  -  .  /  0  1  2  3  4  5  6  7  8  9  :  ;  <  =  >  ?
        =  1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1
        ALIGN

11
        CMP     R0, #"&"        ; hex number?
        CMPNE   R0, #"0"
        RSBGTS  R2, R0, #"9"
        BGE     %FT03           ; got to get a number.

        CMP     R0, #""""
        BEQ     %FT04           ; string.

  ; look for operator
        Push    "R3"
        ADR     R2, operator_table
20
        LDRB    R3, [R2], #1
        CMP     R3, #0          ; end of table?
        BEQ     %FT30
        CMP     R0, R3
        BEQ     %FT21
22
        LDRB    R3, [R2], #1
        CMP     R3, #0
        BNE     %BT22
        ADD     R2, R2, #1      ;   skip op_xxx
        B       %BT20
21
        Push    "R1"
24
        LDRB    R3, [R2], #1
        CMP     R3, #0
        BEQ     %FT23
        LDRB    R0, [R1], #1
        CMP     R0, R3
        BEQ     %BT24
        Pull    "R1"
        LDRB    R0, [R1, #-1]
        B       %BT22
23
        Pull    "R3"            ; junk R1
        Pull    "R3"
        LDRB    R2, [R2]
        MOV     R0, #type_Operator
        MOV     PC, lr          ; got an operator.

30
        LDR     R3, =exprSTRACC
 ; assume variable name : try and read it.
        Push    "lr"
        BL      %BT31           ; check R0 for allowed in name, insert.
        BLE     NaffItemErr
33
        LDRB    R0, [R1], #1
        BL      %BT31
        BGT     %BT33
        SUB     R1, R1, #1
        MOV     R0, #13
        STRB    R0, [R3], #1
 ; potential name in exprSTRACC
        Push    "R1, R4"
        LDR     R0, =exprSTRACC
        MOV     R2, #-1         ; just test for existence first
        MOV     R3, #0
        MOV     R4, #0          ; no expansion
        SWI     XOS_ReadVarVal
        CMP     R2, #0
        BEQ     NaffItemErr
        LDR     R1, =exprSTRACC ; overwrite name with value
        MOV     R0, R1          ; overwritten by VSet return
        MOV     R2, #LongCLISize
        SUB     R2, R2, #1
        MOV     R3, #0
        CMP     R4, #VarType_Macro
        MOVEQ   R4, #VarType_Expanded
        SWI     XOS_ReadVarVal
        BVS     StrOFloErr
        CMP     R4, #VarType_Number
        LDREQ   R2, [R1]
        MOVEQ   R0, #type_Integer
        BLNE    Push_String
        MOVNE   R0, #type_String
        ePush   "R0, R2"
        Pull    "R1, R4, lr"
        Pull    "R3"
        MOV     PC, lr

operator_table
        =       "("    , 0, op_Bra
        =       ")"    , 0, op_Ket
        =       "+"    , 0, op_Plus
        =       "-"    , 0, op_Minus
        =       "*"    , 0, op_Times
        =       "/"    , 0, op_Divide
        =       "="    , 0, op_EQ
        =       "<>"   , 0, op_NE
        =       "<="   , 0, op_LE
        =       "<<"   , 0, op_LShift
        =       "<"    , 0, op_LT
        =       ">="   , 0, op_GE
        =       ">>>"  , 0, op_LRShift
        =       ">>"   , 0, op_RShift
        =       ">"    , 0, op_GT
        =       "AND"  , 0, op_AND
        =       "OR"   , 0, op_OR
        =       "EOR"  , 0, op_EOR
        =       "NOT"  , 0, op_NOT
        =       "RIGHT", 0, op_Right
        =       "LEFT" , 0, op_Left
        =       "MOD"  , 0, op_MOD
        =       "STR"  , 0, op_STR
        =       "VAL"  , 0, op_VAL
        =       "LEN"  , 0, op_LEN
        =       0
        ALIGN

03
        SUB     R1, R1, #1      ; point at string start
        Push    "lr"
        MOV     R0, #10
        SWI     XOS_ReadUnsigned
        LDRVS   R13, ExprSVCstack
        BVS     BumNumber2      ; already messagetransed, so don't do it again MED-01583
        MOV     R0, #type_Integer
        ePush   "R0, R2"
        Pull    "PC"

ExprErrCommon
BumNumber
        LDR     R13, ExprSVCstack
      [ International
        BL      TranslateError
      ]
BumNumber2
        STR     R0, [stack]
        Pull    "R0-R4, lr"
        MOV     R1, #0          ; haven't put anything in buffer
        B       SLVK_SetV
BadStringErr
        ADRL    R0, ErrorBlock_BadString
        B       ExprErrCommon
Bra_Code
BadBraErr
        ADR     R0, ErrorBlock_BadBra
        B       ExprErrCommon
        MakeErrorBlock BadBra
StackOFloErr
        ADR     R0, ErrorBlock_StkOFlo
        B       ExprErrCommon
        MakeErrorBlock StkOFlo
MissingOpErr
        ADR     R0, ErrorBlock_MissOpn
        B       ExprErrCommon
        MakeErrorBlock MissOpn
MissingOrErr
        ADR     R0, ErrorBlock_MissOpr
        B       ExprErrCommon
        MakeErrorBlock MissOpr
BadIntegerErr
        ADR     R0, ErrorBlock_BadInt
        B       ExprErrCommon
        MakeErrorBlock BadInt
StrOFloErr
        ADR     R0, ErrorBlock_StrOFlo
        B       ExprErrCommon
        MakeErrorBlock StrOFlo
NaffItemErr
        ADR     R0, ErrorBlock_NaffItm
        B       ExprErrCommon
        MakeErrorBlock NaffItm
DivZeroErr
        ADR     R0, ErrorBlock_DivZero
        B       ExprErrCommon
        MakeErrorBlock DivZero

04
        LDR     R2, =exprSTRACC
05
        LDRB    R0, [R1], #1
        CMP     R0, #13
        CMPNE   R0, #10
        CMPNE   R0, #0
        BEQ     BadStringErr
        CMP     R0, #""""
        BEQ     %FT06
07
        STRB    R0, [R2], #1    ; can't overflow - comes from buffer
        B       %BT05

06
        LDRB    R0, [R1], #1
        CMP     R0, #""""
        BEQ     %BT07
        SUB     R1, R1, #1
        LDR     R0, =exprSTRACC
        SUB     R2, R2, R0      ; length to R2
        Push    "lr"
        BL      Push_String
        ePush   "R0, R2"
        Pull    "PC"

Push_String  ROUT
        Push    "R2, R3"
        SUBS    R2, R2, #1
        BMI     %FT02
        BIC     R2, R2, #3
        LDR     R0, =exprSTRACC
01
        LDR     R3, [R0, R2]
        ePush   "R3"
        SUBS    R2, R2, #4
        BGE     %BT01
02
        Pull    "R2, R3"
        MOV     R0, #type_String
        MOV     PC, lr

Pull_String ROUT
        CMP     R2, #0
        MOVEQ   PC, lr
        Push    "R0, R2, R3"
        LDR     R0, =exprSTRACC
01
        ePull   "R3"
        STR     R3, [R0], #4
        SUBS    R2, R2, #4
        BGT     %BT01
        Pull    "R0, R2, R3"
        MOV     PC, lr

        LTORG

;*****************************************************************************

; Configure and Status

; The configuration table : some types and macros first.

ConType_NoParm  * 1
ConType_Field   * 2
ConType_Special * 3
ConType_Size    * 4

; Type Special has another table :
; code to set it
; code to show it
; string to print for Configure listing.
; Keep table position as offset from table entry

        MACRO
        Config_Special   $name
        =       ConType_Special, "$name", 0
        ALIGN
        &       Config_$name._table - .
        MEND

; Table offset :
Config_Special_SetCode  * 0
Config_Special_ShowCode * 4
Config_Special_String   * 8

; Type NoParm  : *con. name
; put $value into bits $bitoff to $bitoff+$fwidth in byte $byteoff

        MACRO
        Config_NoParm   $name, $bitoff, $fwidth, $bytoff, $value
        =       ConType_NoParm, "$name", 0
        ALIGN
        =       $bitoff, $fwidth, $bytoff, $value
        MEND

; Type Field   : *con. name number
; read value & put into bits $bitoff to $bitoff+$fwidth in byte $byteoff

        MACRO
        Config_Field   $name, $bitoff, $fwidth, $bytoff
        =       ConType_Field, "$name", 0
        ALIGN
        =       $bitoff, $fwidth, $bytoff, 0
        MEND

; Type Size   : *con. name number|nK
; read value & put into bits $bitoff to $bitoff+$fwidth in byte $byteoff

        MACRO
$l      Config_Size   $name, $bitoff, $fwidth, $bytoff
        =       ConType_Size, "$name", 0
        ALIGN
$l      =       $bitoff, $fwidth, $bytoff, 0
        MEND

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; now the table

Config_Table
        Config_Special  Baud
AlternateBoot
        Config_NoParm   Boot,           4, 0, DBTBCMOS, 1
AlternateNoBoot
        Config_NoParm   NoBoot,         4, 0, DBTBCMOS, 0
        Config_Special  Cache
AlternateCaps
        Config_NoParm   Caps,           3, 2, StartCMOS, 4
AlternateNoCaps
        Config_NoParm   NoCaps,         3, 2, StartCMOS, 2
ExpandShCaps
        Config_NoParm   ShCaps,         3, 2, StartCMOS, 1
EndListCapsFrig
AlternateNum
        Config_NoParm   Num,            7, 0, StartCMOS, 0
AlternateNoNum
        Config_NoParm   NoNum,          7, 0, StartCMOS, 1
        Config_Field    Data,           5, 2, DBTBCMOS
        Config_Field    Delay,          0, 7, KeyDelCMOS
        Config_Field    DumpFormat,     0, 4, PrintSoundCMOS
        Config_Size     FontSize,       0, 7, FontCMOS
FontSizeFrig
        Config_Special  Ignore
        Config_Field    Language,       0, 7, LanguageCMOS
AlternateLoud
        Config_NoParm   Loud,           1, 0, DBTBCMOS, 1
        Config_Special  Mode
        Config_Special  MonitorType
        Config_Special  MouseStep
        Config_Special  MouseType
        Config_Field    Print,          5, 2, PSITCMOS
        Config_Size     PrinterBufferSize, 0, 7, PrinterBufferCMOS
PrinterBufferFrig
AlternateQuiet
        Config_NoParm   Quiet,          1, 0, DBTBCMOS, 0
        Config_Size     RamFSSize,      0, 6, RAMDiscCMOS
        Config_Field    Repeat,         0, 7, KeyRepCMOS
        Config_Size     RMASize,        0, 6, RMASizeCMOS
        Config_Size     ScreenSize,     0, 6, ScreenSizeCMOS
ScreenSizeFrig
AlternateScroll
        Config_NoParm   Scroll,         3, 0, DBTBCMOS, 0
AlternateNoScroll
        Config_NoParm   NoScroll,       3, 0, DBTBCMOS, 1
        Config_Size     SpriteSize,     0, 6, SpriteSizeCMOS
        Config_Special  Sync
        Config_Size     SystemSize,     0, 5, SysHeapCMOS
        Config_Special  TV
        Config_Special  WimpMode
        =       0

ShCapsString = "ShiftCaps", 0

        ALIGN

ExpandFrig * 8    ; see code that shows NoParm options.
ExpandTab
        &       ExpandShCaps    - ExpandFrig-.
        &       ShCapsString    - .-1
        &       0

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        MACRO
        Config_Special_Table $name, $text
Config_$name._table
        B       Config_$name._setcode
        B       Config_$name._showcode
        =       "$text", 0
        ALIGN
        MEND

        ALIGN
        Config_Special_Table Baud, "<D>"
        Config_Special_Table Cache, "On|Off"
        Config_Special_Table TV, "[<D> [[,] <D>]]"
        Config_Special_Table Mode, "<D> | Auto"
        Config_Special_Table Ignore, "[<D>]"
        Config_Special_Table MouseStep, "<D>"
        Config_Special_Table MouseType, "<D>"
        Config_Special_Table MonitorType, "<D> | EDID | Auto"
        Config_Special_Table Sync, "<D> | Auto"
        Config_Special_Table WimpMode, "<D> | Auto"

;*****************************************************************************
; Lookup : R0 -> option
;   Exit : R2 -> table entry, EQ for not found
;          R0 stepped on

FindOption Entry "r1, r3-r5"
        ADRL    r2, Config_Table+1
04
        MOV     r1, #0                         ; offset
01
        LDRB    r3, [r0, r1]
        LDRB    r4, [r2, r1]
        CMP     r3, #32
        CMPLE   r4, #32
        BLE     %FT02
        UpperCase r3, r5
        UpperCase r4, r5
        CMP     r3, r4
        ADDEQ   r1, r1, #1
        BEQ     %BT01
        CMP     r3, #"."
        TOGPSR  Z_bit, r3                       ; invert EQ/NE
        CMPNE   r1, #0
        ADDNE   r1, r1, #1                      ; skip .
        BNE     %FT02
03
        LDRB    r1, [r2], #1
        CMP     r1, #0
        BNE     %BT03
        ADD     r2, r2, #7                      ; skip infoword
        BIC     r2, r2, #3
        LDRB    r1, [r2], #1
        CMP     r1, #0
        BNE     %BT04
        EXIT                                    ; failure exit

02
        ADD     r0, r0, r1                      ; point at char after option
        SUBS    r2, r2, #1
        EXIT                                    ; return with success

;****************************************************************************
;
; Configure
; IF noparms OR parm=. THEN list options : issue service call : finish listing
;                      ELSE lookup parm1 : doit
;    IF notfound THEN issue service

Configure_Help ROUT
        Push    "r0, lr"
        ADR     r0, %FT01
        MOV     r1, #Status_Keyword_Flag
        B       KeyHelpCommon
01
        DCB     "HUTMCON", 0
        ALIGN

Configure_Code  ROUT
        Push    "lr"
        CMP     r1, #0          ; noparms?
        MOVEQ   r3, #0
        BEQ     ListAll         ; go listem.
        BL      FindOption
        BEQ     %FT01
        LDRB    r4, [r2], #1
03
        LDRB    r1, [r2], #1
        CMP     r1, #0
        BNE     %BT03
        ADD     r2, r2, #3
        BIC     r2, r2, #3
        LDR     r1, [r2]
        CMP     r4, #ConType_Size
        BEQ     ReadSizeParm

        CMP     r4, #ConType_Field
        ASSERT  ConType_Special > ConType_Field
; if special dispatch it
        ADDGT   r1, r1, r2                              ; point at node
        ADDGT   pc, r1, #Config_Special_SetCode         ; call it
; if noparm get value
        MOVLT   r2, r1, LSR #24
        BLEQ    ReadNumParm
        BVS     BadConParm
BaudEntry
        BL      ConfigCheckEOL
        Pull    "pc", VS
IgnoreEntry
        MOV     r0, r1                  ; info word
        BL      ReadByte                ; current byte into R1

        MOV     r3, r0, LSR #8
        AND     r3, r3, #&FF            ; get fwidth
        MOV     r4, #2
        MOV     r4, r4, LSL r3
        SUB     r4, r4, #1              ; get mask/maximum value
        CMP     r2, r4
        BHI     ConParmTooBig

        AND     r3, r0, #&FF            ; get bitoff
        BIC     r1, r1, r4, LSL r3      ; clear bits in correct position
        ORR     r2, r1, r2, LSL r3      ; OR in new bits

        MOV     r1, r0, LSR #16         ; get bytoff
        AND     r1, r1, #&FF
        MOV     r0, #WriteCMOS
        SWI     XOS_Byte                ; and set it. Assume this clears V!

        Pull    "pc" 

BadConParm
        MOV     r0, #1
        B       ConfigGenErr
BadConParmError
        &       ErrorNumber_Syntax
        =       "NotNumeric:Numeric parameter needed", 0
        ALIGN

ConParmTooBig
        MOV     r0, #2
        B       ConfigGenErr
ConParmTooBigError
        &       ErrorNumber_Syntax
        =       "ConParmTooBig:Configure parameter too big", 0
        ALIGN
01
        LDR     r12, =ZeroPage+Module_List
conoptloop
        LDR     r12, [r12]
        CMP     r12, #0
        BEQ     conoptservice
        LDR     r1, [r12, #Module_code_pointer]
        LDR     r2, [r1, #Module_HC_Table]
        CMP     r2, #0
        BEQ     conoptloop
        MOV     r4, #Status_Keyword_Flag
        BL      FindItem
        BCC     conoptloop              ; next module
        ADD     r0, r0, r3              ; point at commtail
        LDR     r12, [r12, #Module_incarnation_list]    ; preferred life
        ADDS    r12, r12, #Incarnation_Workspace        ; clear V
        Push    "r1-r6"

StKey_SkipSpaces
        LDRB    r4, [r0], #1
        CMP     r4, #" "
        BEQ     StKey_SkipSpaces
        SUB     r0, r0, #1

        MOV     lr, pc
        ADD     pc, r1, r5            ; call im
        Pull    "r1-r6"
        Pull    "pc", VC
ConfigGenErr
        CMP     r0, #3
        BHI     ExitConfig
        ADREQL  r0, Config2manyparms
        CMP     r0, #2
        ADREQ   r0, ConParmTooBigError
        CMP     r0, #1
        ADRLO   r0, BadConOptError
        ADREQ   r0, BadConParmError
      [ International
        BL      TranslateError
      ]
ExitConfig
        SETV
        Pull    "pc"

conoptservice
        MOV     r1, #Service_UKConfig
        BL      Issue_Service
        CMP     r1, #0
        BNE     BadConOpt
        CMP     r0, #0
        BGE     ConfigGenErr
        Pull    "pc"                    ; TBS means OK: note CMP has cleared V

BadConOpt
        MOV     r0, #0
        B       ConfigGenErr
BadConOptError
        &       ErrorNumber_Syntax
        =       "BadConOpt:Configure option not recognised", 0
        ALIGN

ReadNumParm Entry "r1"
10
        LDRB    r2, [r0], #1
        CMP     r2, #" "
        BEQ     %BT10
        SUB     r1, r0, #1
        MOV     r0, #10                 ; set base
        SWI     XOS_ReadUnsigned
        EXIT    VS
        MOV     r0, r1
        LDRB    r1, [r0]
        CMP     r1, #" "
        SETV    GT
        EXIT

; read a number or Auto
; returns R2 = number or -1 for Auto
;         R0 -> terminator

ReadNumAuto Entry "r1,r3,r4"
10
        LDRB    r2, [r0], #1
        CMP     r2, #" "
        BEQ     %BT10
        SUB     r1, r0, #1
        ADR     r3, AutoString          ; string to match against
        MOV     r4, #0                  ; no other terminators for $R1
        BL      Module_StrCmp           ; out: EQ => match, r1 -> terminator
                                        ;      NE => no match, r1 preserved
                                        ;      r3 corrupted in both cases
        MOVEQ   r2, #-1
        BEQ     %FT20
        MOV     r0, #10                 ; set base
        SWI     XOS_ReadUnsigned
        EXIT    VS
20
        MOV     r0, r1
        LDRB    r1, [r0]
        CMP     r1, #" "
        SETV    GT
        EXIT

AutoString
        =       "Auto", 0
dotstring
        =       ".", 0
        ALIGN

ReadSizeParm ROUT
        Push    "r1, r8"
        MOV     r8, r2
02
        LDRB    r2, [r0], #1
        CMP     r2, #" "
        BEQ     %BT02
        SUB     r1, r0, #1
        MOV     r0, #10                 ; set base
        SWI     XOS_ReadUnsigned
        Pull    "r1, r8", VS
        BVS     BadConParm
        MOV     r0, r1
        LDRB    r1, [r0]
        CMP     r1, #" "
        BLE     %FT01
        CMP     r1, #"k"
        CMPNE   r1, #"K"
        Pull    "r1, r8", NE
        BNE     BadConParm
        ADRL    r14, PrinterBufferFrig-4
        TEQ     r8, r14                 ; if printer buffer size
        TEQEQ   r2, #1                  ; and 1K
        MOVEQ   r2, #0                  ; then use zero (default)
        ADRL    r14, FontSizeFrig-4     ; point at info word for fontsize
        TEQ     r8, r14                 ; if fontsize
        MOVEQ   r8, #4*1024             ; then use 4K (lucky it's a pagesize!)
        LDRNE   r8, =ZeroPage           ; else use pagesize units
        LDRNE   r8, [r8, #Page_Size]
        ADRL    r14, PageShifts-1
        LDRB    r14, [r14, r8, LSR #12]
        SUB     r14, r14, #10           ; *1024
        MOV     r8, r8, LSR #10         ; /1024
        SUB     r8, r8, #1
        ADD     r2, r2, r8
        BIC     r2, r2, r8              ; round up to nearest pagesize
        MOV     r2, r2, LSR r14         ; divide parm by pagesize
        ADD     r0, r0, #1              ; point past "K" for EOL checking
01
        Pull    "r1, r8"
        B       BaudEntry

;*****************************************************************************
; Status
; list all options matched : allow . and <terminator> to match all
; issue service

Status_Code     ROUT
        Push    "lr"
        CMP     r1, #0          ; noparms?
        MOVEQ   r3, #1
        BEQ     ListAll         ; go listemall
        CMP     r1, #1
        BNE     %FT01
        BL      FindOption
        BEQ     %FT01
        MOV     r3, #2
        BL      ListOneConfig
        Pull    "pc"

01
        LDR     r6, =ZeroPage+Module_List
statoptloop
        LDR     r6, [r6]
        CMP     r6, #0
        BEQ     statoptservice
        LDR     r1, [r6, #Module_code_pointer]
        LDR     r2, [r1, #Module_HC_Table]
        CMP     r2, #0
        BEQ     statoptloop
        MOV     r4, #Status_Keyword_Flag
        BL      FindItem
        BCC     statoptloop             ; next module
        MOV     r0, #1
        LDR     r12, [r6, #Module_incarnation_list]
        ADD     r12, r12, #Incarnation_Workspace
        Push    "r0-r6"
        MOV     lr, pc
        ADD     pc, r1, r5              ; call im
        STRVS   r0, [sp]
        Pull    "r0-r6, pc"

statoptservice
        MOV     r1, #Service_UKStatus
        BL      Issue_Service
        CMP     r1, #0
        Pull    "pc", EQ
        ADR     r0, %FT03
      [ International
        BL      TranslateError
      |
        SETV
      ]
        Pull    "pc"
03
        &       ErrorNumber_Syntax
        =       "BadStat:Bad status option", 0
        ALIGN

;*****************************************************************************

; routine to list everything : on entry R3 = 0 means entered from configure
;                                          = 1   "     "      "   status
;                                       lr stacked for return

ListAll ROUT
        MOV     r0, #117                ; Read current VDU status
        SWI     XOS_Byte                ; Won't fail
        Push    "r1"

      [ International
        SWI     XOS_WriteI+14
        BL      WriteS_Translated
        =       "Config:Configuration",0
        ALIGN
        SWIVC   XOS_WriteI+" "
      |
        SWI     XOS_WriteS
        =       14, "Configuration ", 0 ; paged mode on.
        ALIGN
      ]
        Pull    "r1, pc", VS            ; Wrch can fail
        CMP     r3, #0
        ADREQ   r0, %FT06
        ADRNE   r0, %FT08
      [ International
        BL      Write0_Translated
      |
        SWI     XOS_Write0
      ]
        SWIVC   XOS_NewLine
        SWIVC   XOS_NewLine
        Pull    "r1, pc", VS

        ADRL    r2, Config_Table
02
        ADRL    r4, AlternateCaps
        CMP     r4, r2
        CMPEQ   r3, #1
        BEQ     FrigCapsList
        LDRB    r4, [r2]
        CMP     r4, #0
        BLNE    ListOneConfig
        Pull    "r1, pc", VS
        BNE     %BT02

10
        ADRL    r0, dotstring           ; match all
        Push    "r3, r7"
        LDR     r7, =ZeroPage+Module_List
listallmloop
        LDR     r7, [r7]
        CMP     r7, #0
        BEQ     listallservice
        LDR     r1, [r7, #Module_code_pointer]
        LDR     r2, [r1, #Module_HC_Table]
        CMP     r2, #0
        BEQ     listallmloop
listalltryfind
        MOV     r4, #Status_Keyword_Flag
        BL      FindItem
        BCC     listallmloop            ; next module
        LDR     r0, [stack]             ; pick up r3
        LDR     r12, [r7, #Module_incarnation_list]
        ADD     r12, r12, #Incarnation_Workspace
        Push    "r0-r6"
        MOV     lr, pc
        ADD     pc, r1, r5              ; call im
        Pull    "r0-r6"
        ADD     r2, r2, #16             ; step to next field
        ADRL    r0, dotstring
        B       listalltryfind

      [ International
06
        =       "Options:options:",0
08
        =       "Status:status:",0
      |
06
        =       "options:",0
08
        =       "status:",0
      ]
        ALIGN

listallservice
        Pull    "r3, r7"
        CMP     r3, #0
        MOVEQ   r1, #Service_UKConfig
        MOVNE   r1, #Service_UKStatus
        MOV     r0, #0                  ; indicate list wanted
        BL      Issue_Service
        CMP     r3, #0
      [ International
        BEQ     %FT20
        BL      GSWriteS_Translated
        =       "STail:|J|MUse *Configure to set the options.|J|M",0
        ALIGN
        B       %FT30
20
        BL      GSWriteS_Translated
        =       "CTail1:|J|MWhere:|J|MD is a decimal number, a hexadecimal number preceded by &,|J|M"
        =       "or the base followed by underscore, followed|J|M",0
        ALIGN
        BL      GSWriteS_Translated
        =       "CTail2:by digits in the given base.|J|MItems within [ ] are optional.|J|M"
        =       "Use *Status to display the current settings.|J|M",0
        ALIGN
30
      |
        ADRNE   r0, statuslastline
        ADREQ   r0, configlastline
        SWI     XOS_Write0
      ]
        Pull    "r1"
        Pull    "pc", VS                ; return error if set
        TST     r1, #5
        SWIEQ   XOS_WriteI+15  ; paged mode off
        Pull    "pc"

      [ :LNOT: International
statuslastline
        =       10,13, "Use *Configure to set the options.", 10,13,0
configlastline
        =       10,13, "Where:", 10,13
        =       "D is a decimal number, " ;, 10,13
        =       "a hexadecimal number preceded by &, ", 10,13
        =       "or the base followed by underscore, followed", 10,13
        =       "by digits in the given base.", 10,13
        =       "Items within [ ] are optional.", 10,13
        =       "Use *Status to display the current settings.", 10,13, 0
        ALIGN
      ]

FrigCapsList
        MOV     r3, #2
        BL      ListOneConfig
        Pull    "r1, pc", VS
        MOV     r3, #1
        ADRL    r2, EndListCapsFrig
        B       %BT02

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; routine to list one item :
; R3 = 0 means entered from configure
;    = 1   "     "      "   status
;    = 2   "     "      "   status <item>
; R2 points at the item, stepped to next on exit
; Preserves flags

ListOneConfig   ROUT
        EntryS
        LDRB    r4, [r2]
        CMP     r4, #ConType_Field
        CMPNE   r4, #ConType_Size
        CMPNE   r3, #0
        BNE     %FT20

        ADD     r0, r2, #1
        SWI     XOS_Write0
        BVS     ExitShow
        SUB     r1, r0, r2      ; get length
        ADD     r2, r0, #3      ; skip terminator
        BIC     r2, r2, #3      ; and align

        CMP     r4, #ConType_NoParm
        BEQ     %FT07
04
        SWI     XOS_WriteI+" "
        BVS     ExitShow
        ADD     r1, r1, #1
        CMP     r1, #12
        BLS     %BT04

        CMP     r3, #0
        BNE     %FT30

        CMP     r4, #ConType_Size
        ADREQ   r0, %FT42
        BEQ     %FT43

        CMP     r4, #ConType_Field
        ASSERT  ConType_Special > ConType_Field
        ADREQ   r0, %FT05
        LDRGT   r0, [r2]
        ADDGT   r0, r0, r2                      ; point at node
        ADDGT   r0, r0, #Config_Special_String  ; point at string
43
        SWI     XOS_Write0
07
        ADD     r2, r2, #4
ExitShow
        SWIVC   XOS_NewLine
11
        EXITV
05
        =       "<D>", 0
42
        =       "<D>[K]", 0

; status bits :

        ALIGN
20
        ADD     r0, r2, #1              ; got to do *status on a NoParm or Special
21
        LDRB    r1, [r0], #1
        CMP     r1, #0                  ; step past name
        BNE     %BT21
        ADD     r0, r0, #3
        BIC     r0, r0, #3              ; align
        LDR     r1, [r0]                ; get info word.
        CMP     r4, #ConType_Special
        ADDEQ   r1, r1, r0              ; point at node
        ADDEQ   pc, r1, #Config_Special_ShowCode

; if CRbytevalue = infowordvalue then print something

        MOV     r4, r0                  ; hang on to it
        MOV     r0, r1
        BL      GetValue
        MOV     r1, r1, LSR #24         ; value.
        CMP     r0, r1
        BNE     %FT10                   ; check for *Status <Item>

; first see if expansion needed

        ADRL    r0, ExpandTab
22
        LDR     r1, [r0], #8
        CMP     r1, #0
        BEQ     %FT23
        ADD     r1, r1, r0              ; get real address
        CMP     r1, r2
        BNE     %BT22
        LDR     r2, [r0, #-4]!
14
        ADD     r2, r2, r0              ; new string
23
        ADD     r2, r2, #1

; now write chars with space between lowercase then upper

        MOV     r1, #1                  ; indicate uppercase last
24
        LDRB    r0, [r2], #1
        CMP     r0, #0
        BEQ     %FT25
        CMP     r0, #"Z"                ; uppercase if LE
        CMPLE   r1, #0
        SWILE   XOS_WriteI+" "
        BVS     ExitShow
        CMP     r0, #"Z"
        MOVLE   r1, #1
        MOVGT   r1, #0
        SWI     XOS_WriteC
        BVC     %BT24

25
        ADDVC   r2, r4, #4
        B       ExitShow

30
        LDR     r0, [r2], #4            ; got to do *status for Field
        CMP     r4, #ConType_Size
        MOV     r4, r2
        BL      GetValue
        BEQ     %FT31
        BL      PrintR0
        B       ExitShow
31
        Push    "r8, r9"
        ADRL    r8, FontSizeFrig
        CMP     r4, r8
        LDRNE   r8, =ZeroPage
        LDRNE   r8, [r8, #Page_Size]
        MOVEQ   r8, #4*1024
        ADRL    r9, PageShifts-1
        LDRB    r9, [r9, r8, LSR #12]
        SUB     r9, r9, #10
        MOVS    r0, r0, LSL r9          ; size in K
        BNE     %FT35
        ADRL    r8, PrinterBufferFrig   ; if zero and PrinterBufferSize, then 1K
        TEQ     r8, r2
        MOVEQ   r0, #1
        BEQ     %FT35
        ADRL    r8, ScreenSizeFrig      ; if zero and it's ScreenSize, then call OS_ReadSysInfo to find appropriate amount
        TEQ     r8, r2
        BNE     %FT35
        SWI     XOS_ReadSysInfo         ; proper screen size (r0=0) on entry
        MOV     r0, r0, LSR #10
35
        Pull    "r8, r9"
        BL      PrintR0
        SWIVC   XOS_WriteI+"K"
        B       ExitShow

10
        CMP     r3, #2
        ADDNE   r2, r4, #4
        BNE     %BT11

; R0 is the value set : can corrupt R3 as this is the do-one entry

        MOV     r3, r0
        ADRL    r0, AlternateTab        ; look for option really set
12
        LDR     r1, [r0], #8            ; better find a match!
        ADD     r1, r1, r0              ; get real address
        CMP     r1, r2
        BNE     %BT12
        LDR     r2, [r0, #-4]!
        ADD     r2, r2, r0              ; translation table
        LDR     r0, [r2, r3, LSL #2]
        B       %BT14                   ; go print it

AlternateTab
        &       AlternateBoot - ExpandFrig-.
        &       %FT91 -.
        &       AlternateNoBoot - ExpandFrig-.
        &       %FT91 -.
        &       AlternateCaps - ExpandFrig-.
        &       %FT92 -.
        &       AlternateNoCaps - ExpandFrig-.
        &       %FT92 -.
        &       ExpandShCaps - ExpandFrig-.
        &       %FT92 -.
        &       AlternateNum - ExpandFrig-.
        &       %FT93 -.
        &       AlternateNoNum - ExpandFrig-.
        &       %FT93 -.
        &       AlternateLoud - ExpandFrig-.
        &       %FT95 -.
        &       AlternateQuiet - ExpandFrig-.
        &       %FT95 -.
        &       AlternateScroll - ExpandFrig-.
        &       %FT96 -.
        &       AlternateNoScroll - ExpandFrig-.
        &       %FT96 -.

91
        &       AlternateNoBoot -%BT91
        &       AlternateBoot   -%BT91
92
        &       ShCapsString    -%BT92-1
        &       ShCapsString    -%BT92-1
        &       AlternateNoCaps -%BT92
        &       AlternateNoCaps -%BT92
        &       AlternateCaps   -%BT92
        &       AlternateCaps   -%BT92
        &       AlternateCaps   -%BT92
        &       AlternateCaps   -%BT92
93
        &       AlternateNum   -%BT93
        &       AlternateNoNum -%BT93
95
        &       AlternateQuiet -%BT95
        &       AlternateLoud  -%BT95
96
        &       AlternateScroll   -%BT96
        &       AlternateNoScroll -%BT96

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; read byte from CMOS RAM : info word in R0, byte -> R1

ReadByte Entry  "r0, r2"
        MOV     r1, r0, LSR #16         ; get bytoff
        AND     r1, r1, #&FF
        MOV     r0, #ReadCMOS
        SWI     XOS_Byte
        MOV     r1, r2
        EXIT

; take infoword in R0, return value in R0

GetValue EntryS "r1"
        BL      ReadByte                ; now extract the value
        AND     r14, r0, #&FF           ; get bitoff
        MOV     r1, r1, LSR r14         ; throw away low bits
        MOV     r0, r0, LSR #8
        AND     r0, r0, #&FF            ; get fwidth
        RSB     r0, r0, #31             ; number of positions to shift up to remove unwanted bits
        MOV     r1, r1, LSL r0          ; shift up...
        MOV     r0, r1, LSR r0          ; ...then down again
        EXITS

PrintR0 Entry   "r1, r2"
        CMP     r0, #-1
        BNE     %FT10
        ADRL    r0, AutoString
        SWI     XOS_Write0
        EXIT
10
        SUB     sp, sp, #32
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertInteger4
        SWIVC   XOS_Write0
        ADD     sp, sp, #32
        EXIT

NoString =      "No ", 0
        ALIGN

ConfigCheckEOL  ROUT
        LDRB    r3, [r0], #1
        CMP     r3, #" "
        BEQ     ConfigCheckEOL
        CMP     r3, #13
        CMPNE   r3, #10
        CMPNE   r3, #0
        MOVEQ   pc, lr
        ADR     R0, Config2manyparms
      [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
      |
        SETV
      ]
        MOV     pc, lr

Config2manyparms
        &       ErrorNumber_Syntax
        =       "Config2manyparms:Too many parameters"

;*************************************************************************

IgnoreBitoff *  1

Config_TV_setcode ROUT
        LDRB    r2, [r0], #1
        CMP     r2, #" "
        BEQ     Config_TV_setcode
        SUB     r1, r0, #1
        MOV     r0, #10                 ; set base
        SWI     XOS_ReadUnsigned
        BVS     %FT01
        CMP     r2, #3
        SUBGT   r0, r2, #252
        CMPGT   r0, #3
        BHI     BadConOpt
        CMP     r2, #3
        ANDGT   r2, r2, #7              ; top bit set in field means 252-255
        Push    "r2"
        MOV     r0, #0
03
        LDRB    r2, [r1], #1
        CMP     r2, #" "
        BEQ     %BT03
        CMP     r2, #","
        CMPEQ   r0, #0
        MOVEQ   r0, #","
        BEQ     %BT03
        SUB     r1, r1, #1
        Push    "r0"
        MOV     r0, #10
        SWI     XOS_ReadUnsigned
        Pull    "r0"
        BVC     %FT04
        CMP     r0, #0
        Pull    "r0", NE
        BNE     BadConOpt
04
        CMP     r2, #1
        Pull    "r0"
        BHI     ConParmTooBig
        ORR     r2, r2, r0, LSL #1
01
        MOV     r0, r1
        LDR     r1, %FT02
        B       BaudEntry
02
        =       4, 3, MODETVCMOS, 0

Config_TV_showcode
        MOV     r4, r0
        SWI     XOS_WriteS
        =       "TV         ", 0
        ALIGN
        MOVVC   r0, #ReadCMOS
        MOVVC   r1, #MODETVCMOS
        SWIVC   XOS_Byte
        MOVVC   r2, r2, LSL #24
        MOVVC   r0, r2, ASR #29         ; get signed TV shift
        ANDVC   r0, r0, #&FF
        BLVC    PrintR0
        SWIVC   XOS_WriteI+","
        MOVVC   r0, r2, LSR #28
        ANDVC   r0, r0, #1              ; interlace bit
        BLVC    PrintR0
        ADD     r2, r4, #4
        B       ExitShow

Config_Ignore_setcode ROUT
        LDRB    r2, [r0], #1
        CMP     r2, #" "
        BEQ     Config_Ignore_setcode
        SUB     r1, r0, #1
        MOV     r0, #10                 ; set base
        SWI     XOS_ReadUnsigned
        MOV     r0, r1
        Push    "r2"
        ADR     lr, %FT03
        Push    lr                      ; return reg for BaudEntry
        MOVVS   r2, #1
        MOVVC   r2, #0                  ; if number had clear noignore
        LDR     r1, %FT01
        B       BaudEntry               ; pseudo-BL
03
        Pull    "r2"                    ; set to 0 if noignore, but we don't care!
        LDR     r1, %FT02
        B       IgnoreEntry
01
        =       IgnoreBitoff, 0, PSITCMOS, 0
02
        =       0, 7, PigCMOS, 0

Config_Ignore_showcode
        MOV     r4, r0
        MOV     r0, #ReadCMOS
        MOV     r1, #PSITCMOS
        SWI     XOS_Byte
        TST     r2, # 1 :SHL: IgnoreBitoff
        ADRNE   r0, NoString
        SWINE   XOS_Write0
        BVS     ExitShow
        SWI     XOS_WriteS
        =       "Ignore", 0
        ALIGN
        BVS     ExitShow
        ADDNE   r2, r4, #4
        BNE     ExitShow
        MOV     r1, #PigCMOS
        SWI     XOS_Byte
        SWI     XOS_WriteS
        =       "     ", 0
        ALIGN
        MOV     r1, #PigCMOS
        SWIVC   XOS_Byte
        MOVVC   r0, r2
        BLVC    PrintR0
        ADD     r2, r4, #4
        B       ExitShow

Config_Mode_setcode  ROUT
Config_WimpMode_setcode ROUT
        ADR     r1, ModeCMOSTable
ConfigMultiField ROUT
        BL      ReadNumAuto
        BVS     BadConParm
        CMP     r2, #-1
        LDR     r14, [r1], #4                   ; get auto number
        MOVEQ   r2, r14                         ; if auto number then replace by auto value
        LDR     r14, [r1], #4                   ; get maximum value
        CMPNE   r2, r14                         ; if not auto then check maximum value
        BHI     ConParmTooBig
        BL      ConfigCheckEOL
        BVS     ExitConfig
        MOV     r0, r1
        BL      WriteMultiField
        Pull    "pc"                            ; was already stacked by *Configure

ModeCMOSTable
        &       256                             ; Auto value
        &       255                             ; maximum valid number
;               address, mask from bit 0, shift to 1st bit in value, shift to 1st bit in CMOS
 [ {TRUE} ; mode = wimpmode
        =       WimpModeCMOS,   &FF, 0, 0       ; normal bits here
        =       Mode2CMOS,      &01, 8, 4       ; mode auto bit
        ASSERT  WimpModeAutoBit = 16
 |
        =       MODETVCMOS,     &0F, 0, 0       ; bits 0 to 3 here
        =       VduCMOS,        &01, 4, 1       ; bit 4 here
        =       Mode2CMOS,      &0F, 5, 0       ; bits 5 to 7, and auto bit here
 ]
        =       0
        ALIGN

; Write a number of CMOS RAM bit fields from a value

; in:   r0 -> table
;       r2 -> value to split
;
; out:  -

WriteMultiField Entry "r0-r5"
        MOV     r3, r0                  ; pointer to where we're at in table
        MOV     r4, r2                  ; value
10
        LDRB    r1, [r3], #1
        TEQ     r1, #0
        EXIT    EQ
        MOV     r0, #ReadCMOS
        SWI     XOS_Byte
        LDRB    r0, [r3], #1            ; r0 = mask
        LDRB    r5, [r3], #1            ; r5 = shift to 1st bit in value
        LDRB    r14, [r3], #1           ; r14 = shift to 1st bit in CMOS
        BIC     r2, r2, r0, LSL r14     ; knock out previous bits
        AND     r5, r0, r4, LSR r5      ; get new bits, at bottom of byte
        ORR     r2, r2, r5, LSL r14     ; form new CMOS value
        MOV     r0, #WriteCMOS
        SWI     XOS_Byte
        B       %BT10

; Read a value formed by merging a number of CMOS RAM bit fields

; in:   r0 -> table
; out:  r0 = value

ReadMultiField Entry "r1-r6"
        LDR     r6, [r0, #4]            ; get maximum value allowed
        ADD     r3, r0, #2*4            ; pointer to where we're at in table (skip auto, max)
        MOV     r4, #0                  ; cumulative value
10
        LDRB    r1, [r3], #1
        TEQ     r1, #0
        BEQ     %FT20
        MOV     r0, #ReadCMOS
        SWI     XOS_Byte
        LDRB    r0, [r3], #1            ; r0 = mask
        LDRB    r5, [r3], #1            ; r5 = shift to 1st bit in value
        LDRB    r14, [r3], #1           ; r14 = shift to 1st bit in CMOS
        AND     r2, r0, r2, LSR r14     ; get relevant bits in bottom of byte
        ORR     r4, r4, r2, LSL r5      ; merge new bits with value
        B       %BT10
20
        CMP     r4, r6                  ; if within range
        MOVLS   r0, r4                  ; then return that value
        MOVHI   r0, #-1                 ; else return -1 indicating Auto
        EXIT

Config_Mode_showcode ROUT
        MOV     r4, r0
        ADR     r0, ModeSpacedString
ModeWimpModeShowCode
        SWI     XOS_Write0
        BVS     %FT10
        BL      Read_Configd_Mode
        BL      PrintR0
10
        ADD     r2, r4, #4
        B       ExitShow

ModeSpacedString
        =       "Mode       ", 0
WimpModeSpacedString
        =       "WimpMode   ", 0
        ALIGN

Config_WimpMode_showcode ROUT
        MOV     r4, r0
        ADR     r0, WimpModeSpacedString
        B       ModeWimpModeShowCode

Read_Configd_Mode Entry
        ADR     r0, ModeCMOSTable
        BL      ReadMultiField
        EXIT

Config_Baud_setcode  ROUT
        BL      ReadNumParm
        BVS     BadConParm
        CMP     r2, #8
        BGT     ConParmTooBig
        SUBS    r2, r2, #1
        MOVMI   r2, #6
        LDR     r1, %FT01               ; set up info word
        B       BaudEntry
01
        =       2, 2, PSITCMOS, 0

Config_Baud_showcode
        MOV     r4, r0
        SWI     XOS_WriteS
        =       "Baud       ", 0
        ALIGN
        LDRVC   r0, %BT01               ; get infoword
        BLVC    GetValue
        ADDVC   r0, r0, #1
        BLVC    PrintR0
        ADD     r2, r4, #4
        B       ExitShow

Config_Cache_setcode ROUT
        LDRB    r2, [r0], #1
        CMP     r2, #" "
        BEQ     Config_Cache_setcode
        SUB     r0, r0, #1
        BL      Cache_Opt_Parse
        MOVS    r1, r1
        BMI     BadConOpt
        MOVNE   r4, #&20                ; CMOS flag for 'Off'
        MOVEQ   r4, #0                  ; CMOS flag for 'On'
        MOVVC   r0, #ReadCMOS
        MOVVC   r1, #SystemSpeedCMOS
        SWIVC   XOS_Byte
        BICVC   r2, r2, #&20
        ORRVC   r2, r2, r4
        MOVVC   r0, #WriteCMOS
        SWIVC   XOS_Byte
        Pull    "pc"
        
Config_Cache_showcode
        MOV     r4, r0
        SWI     XOS_WriteS
        =       "Cache      ", 0
        ALIGN
        MOVVC   r0, #ReadCMOS
        MOVVC   r1, #SystemSpeedCMOS
        SWIVC   XOS_Byte
        BVS     %FT11
        TST     r2, #&20                ; clear = enable
        ADREQ   r0, %FT12
        ADRNE   r0, %FT13
        SWI     XOS_Write0
11      ADD     r2, r4, #4
        B       ExitShow
12
        =       "On", 0
13
        =       "Off", 0
        ALIGN        

Config_MouseStep_setcode ROUT
        LDRB    r2, [r0], #1
        CMP     r2, #" "
        BEQ     Config_MouseStep_setcode
        CMP     r2, #"-"
        Push    "r2"
        SUBNE   r1, r0, #1
        MOV     r0, #10                 ; set base
        SWI     XOS_ReadUnsigned
        Pull    "r0"
        BVS     BadConParm
        CMP     r0, #"-"
        RSBEQ   r2, r2, #0
        CMP     r2, #0
        BEQ     BadConOpt
        CMP     r2, #-128
        BLT     BadConOpt
        CMP     r2, #127
        BGT     ConParmTooBig
        MOV     r0, r1
        LDR     r1, %FT02
        B       BaudEntry
02
        =       0, 7, MouseStepCMOS, 0

Config_MouseStep_showcode ROUT
        MOV     r4, r0
        SWI     XOS_WriteS
        =       "MouseStep  ", 0
        ALIGN
        MOVVC   r0, #ReadCMOS
        MOVVC   r1, #MouseStepCMOS
        SWIVC   XOS_Byte
        BVS     %FT01
        MOVS    r2, r2, LSL #24
        MOVNE   r0, r2, ASR #24  ; get sign extended byte
        MOVEQ   r0, #1
        BL      PrintR0
01      ADD     r2, r4, #4
        B       ExitShow

Config_MouseType_setcode ROUT
        LDRB    r2, [r0], #1
        CMP     r2, #" "
        BEQ     Config_MouseType_setcode
        SUB     r1, r0, #1
        MOV     r0, #10          ; set base
        SWI     XOS_ReadUnsigned
        BVS     BadConParm
        CMP     r2, #&100
        BCS     ConParmTooBig
        MOV     r4, r1
        MOV     r0, #1
        MOV     r1, r2
        SWI     XOS_Pointer
        MOV     r0, r4
        LDR     r1, %FT01
        B       BaudEntry
01
        =       0, 7, MouseCMOS, 0

Config_MouseType_showcode
        MOV     r4, r0
        SWI     XOS_WriteS
        =       "MouseType  ", 0
        ALIGN
        LDRVC   r0, %BT01
        BLVC    GetValue
        BLVC    PrintR0
        ADD     r2, r4, #4
        B       ExitShow

Config_MonitorType_setcode
10
        LDRB    r2, [r0], #1
        CMP     r2, #" "
        BEQ     %BT10
        SUB     r1, r0, #1
        ADR     r3, MonitorTypeNameEDID ; string to match against
        MOV     r4, #0                  ; no other terminators for $R1
        BL      Module_StrCmp           ; out: EQ => match, r1 -> terminator
                                        ;      NE => no match, r1 preserved
                                        ;      r3 corrupted in both cases
        LDREQB  r3, [r1]
        MOVNE   r0, r1
        ADR     r1, MonitorTypeCMOSTable
        BNE     %FT20
        CMP     r3, #" "
        BGT     BadConParm
        MOV     r2, #MonitorTypeEDID :SHR: MonitorTypeShift
        MOV     r4, r2
        B       %FT30
20
        BL      ReadNumAuto
        BVS     BadConParm
        MOV     r4, r2                          ; save value to store in current monitortype
        CMP     r2, #-1
        LDR     r14, [r1], #4                   ; get auto number
        MOVEQ   r2, r14                         ; if auto number then replace by auto value
        LDR     r14, [r1], #4                   ; get maximum value
        CMPNE   r2, r14                         ; if not auto then check maximum value
        BHI     ConParmTooBig
        BL      ConfigCheckEOL
        BVS     ExitConfig
30
        LDR     r0, =ZeroPage+VduDriverWorkSpace+CurrentMonitorType
        STR     r4, [r0]                        ; update current value

        MOV     r0, r1
        BL      WriteMultiField
        Pull    "pc"                            ; was already stacked by *Configure

        LTORG

MonitorTypeCMOSTable
        DCD     MonitorTypeAuto :SHR: MonitorTypeShift          ; value for Auto
        DCD     MonitorTypeEDID :SHR: MonitorTypeShift          ; maximum valid number
;               address, mask from bit 0, shift to 1st bit in value, shift to 1st bit in CMOS
        =       VduCMOS,        MonitorTypeBits :SHR: MonitorTypeShift, 0, MonitorTypeShift
        =       0

MonitorTypeNameEDID
        DCB     "EDID", 0
        ALIGN

Config_MonitorType_showcode ROUT
        MOV     r4, r0
        SWI     XOS_WriteS
        =       "MonitorType ", 0
        ALIGN
        BVS     %FT20
        BL      Read_Configd_MonitorType
        TEQ     r0, #MonitorTypeEDID :SHR: MonitorTypeShift
        BNE     %FT10
        ADR     r0, MonitorTypeNameEDID
        SWI     XOS_Write0
        B       %FT20
10
        BL      PrintR0
20
        ADD     r2, r4, #4
        B       ExitShow

Read_Configd_MonitorType Entry
        ADR     r0, MonitorTypeCMOSTable
        BL      ReadMultiField
        EXIT

Config_Sync_setcode
        ADR     r1, SyncCMOSTable
        B       ConfigMultiField

SyncCMOSTable
        &       3       ; Auto value
        &       1       ; maximum valid number
;               address, mask from bit 0, shift to 1st bit in value, shift to 1st bit in CMOS
        =       VduCMOS, 1, 0, 0
        =       VduCMOS, 1, 1, 7
        =       0
        ALIGN

Config_Sync_showcode ROUT
        MOV     r4, r0
        SWI     XOS_WriteS
        =       "Sync       ", 0
        ALIGN
        BVS     %FT10
        BL      Read_Configd_Sync
        BL      PrintR0
10
        ADD     r2, r4, #4
        B       ExitShow

Read_Configd_Sync Entry
        ADR     r0, SyncCMOSTable
        BL      ReadMultiField
        EXIT

        END
