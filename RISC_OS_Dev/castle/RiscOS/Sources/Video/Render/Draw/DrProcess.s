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
; > DrawMod.sources.DrProcess

;----------------------------------------------------------------------------
;
; The Draw processing routines
;
;----------------------------------------------------------------------------

                GBLL    tracetransform
tracetransform  SETL    {FALSE}

                GBLL    tracethicken
tracethicken    SETL    {FALSE}

                GBLL    tracedash
tracedash       SETL    {FALSE}

; Change the path to floating point
; =================================
;   Not yet implemented

process_float
        ADR     R0,ErrorBlock_UnimplementedDraw
        STMDB   sp!, {lr}
        BL      CopyError
        LDMIA   sp!, {lr}
        ErrorReturn

; Transform the path
; ==================

process_transform

        CLRV
        [       tracetransform
        Push    "R0-R11,LR"
        SWI     OS_WriteS
        DCB     "Transform",13,10,0
        ALIGN
        MOV     R3,#0
dumploop4
        LDR     R0,[R13,R3]
        ADR     R1,dumpno4
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     " "
dumpno4
        DCB     "00000000",0
        ALIGN
        ADD     R3,R3,#4
        TST     R3,#15
        SWIEQ   OS_NewLine
        CMP     R3,#48
        BLO     dumploop4
        SWI     OS_NewLine
        Pull    "R0-R11,LR"
        ]

        Push    "newX,newY,LR"
        ADD     PC,PC,type,LSL #2
        MOV     PC,#0                   ;Should never happen!
        B       process_transform_end   ;endpathET - pass down
        B       process_transform_init  ;startpathET - initialise & pass down
        B       process_transform_one   ;movetoET - transform one point
        B       process_transform_one   ;specialmovetoET - transf. one point
        B       process_transform_two   ;closewithgapET - transf. two points
        B       process_transform_two   ;closewithlineET - transf. two points
        B       process_transform_four  ;beziertoET - transform four points
        NOP                             ;gaptoET - transform two points
process_transform_two                   ;linetoET - transform two points
        ADR     R14,beforetransform     ;Try to use cached transformed point
        LDMIA   R14,{newX,newY}
        CMP     oldX,newX               ;Note these compares clear V if
        CMPEQ   oldY,newY               ;  EQ is set
        ADREQ   R14,aftertransform
        LDMEQIA R14,{oldX,oldY}
        MOVNE   newX,oldX
        MOVNE   newY,oldY
        BLNE    process_transform_point
        Pull    "oldY,LR,PC",VS         ;Error return, preserve r0 (oldX)
        MOVNE   oldX,newX
        MOVNE   oldY,newY
        LDMFD   R13,{newX,newY}         ;Recover newX,newY from stack
process_transform_one
        ADR     R14,beforetransform
        STMIA   R14,{newX,newY}
        BL      process_transform_point
        Pull    "oldY,LR,PC",VS
        ADR     R14,aftertransform
        STMIA   R14,{newX,newY}
process_transform_pass
        CallNextRoutine
        Pull    "oldX,oldY,PC",VC       ;Return, moving newX/Y to oldX/Y
        Pull    "oldY,LR,PC"            ;Error return, preserve r0 (oldX)

process_transform_end
        CallNextRoutine
	; when sending the endpathET down the chain we need to
	; take care to preserve r0 on our way up because it is
	; the SWI return value
	Pull    "oldY,LR,PC"            ;Return, preserving r0 (oldX)

process_transform_init
        MOV     t1,#0                   ;Initialise transform cache to say
        MOV     t2,#0                   ;  that (0,0) transforms to (e,f) -
        LDR     newX,matrix             ;  this is not particularly likely
        ADD     R14,newX,#16            ;  to be used, but is easier than
        LDMIA   R14,{t3,t4}             ;  keeping a "cache valid" flag.
        ADR     R14,beforetransform
        STMIA   R14,{t1,t2,t3,t4}
        ASSERT  t1 < t2
        ASSERT  t2 < t3
        ASSERT  t3 < t4
        ASSERT  aftertransform = beforetransform+8
        LDMIA   newX,{t2,t3,t4,newX}    ;Get matrix elements
        SSmultD newX,t2,t1,t2           ;Check sign of determinant and change
                                        ;  'userspacewinding' to -1 if it is
        SSmultD t3,t4,t3,t4             ;  negative.
        SUBS    t1,t1,t3
        SBCS    t2,t2,t4
        MOVLT   R14,#-1
        STRLT   R14,userspacewinding
        B       process_transform_pass

process_transform_four
        MOV     newX,t1
        MOV     newY,t2
        BL      process_transform_point
        MOVVC   t1,newX
        MOVVC   t2,newY
        MOVVC   newX,t3
        MOVVC   newY,t4
        BLVC    process_transform_point
        MOVVC   t3,newX
        MOVVC   t4,newY
        BVC     process_transform_two
        Pull    "oldY,LR,PC"

; Subroutine to transform the point held in newX,newY and put the result in
; newX,newY. Preserves all other registers. Generates an error on overflow.

process_transform_point
        Push    "oldX,oldY,t1,t2,t3,t4,type,LR"
        LDR     type,matrix
        LDMIA   type!,{t2,t3,t4}        ;2^16*a,2^16*b,2^16*c into t2,t3,t4
        SSmultD t2,newX,oldX,oldY       ;2^16*a*X into oldX,oldY
        SSmultD t4,newY,t1,t2           ;2^16*c*Y into t1,t2
        ADDS    oldX,oldX,t1            ;2^16*a*X + 2^16*c*Y into oldX,oldY
        ADCS    oldY,oldY,t2
        BVS     process_transform_overflow
        SSmultD t3,newX,t1,t2           ;2^16*b*X into t1,t2
        LDMIA   type,{t3,t4,type}       ;2^16*d,e,f into t3,t4,type
        SSmultD t3,newY,newX,newY       ;2^16*d*Y into newX,newY
        ADDS    t1,t1,newX              ;2^16*b*X + 2^16*d*newY into t1,t2
        ADCS    t2,t2,newY
        BVS     process_transform_overflow
        MOVS    newX,oldX,LSR #16       ;a*X + c*Y into newX,t3
        ORR     newX,newX,oldY,LSL #16
        MOV     t3,oldY,ASR #16
        ADCS    newX,newX,t4            ;Add in e and rounding correction
        ADC     t3,t3,t4,ASR #31        ;  - will not overflow
        MOVS    newY,t1,LSR #16         ;b*X + d*Y into newY,t4
        ORR     newY,newY,t2,LSL #16
        MOV     t4,t2,ASR #16
        ADCS    newY,newY,type          ;Add in f and rounding correction
        ADC     t4,t4,type,ASR #31      ;  - will not overflow
        CMP     t3,newX,ASR #31         ;Check for signed single precision
        CMPEQ   t4,newY,ASR #31         ;  overflow
        Pull    "oldX,oldY,t1,t2,t3,t4,type,PC",EQ      ;Return with VC if OK
process_transform_overflow
        ADR     R0,ErrorBlock_TransformOverflow
        BL      CopyError
        Pull    "oldY,t1,t2,t3,t4,type,LR,PC"

        MakeInternatErrorBlock TransformOverflow,,M10

; A macro to take the average of two signed values in registers and put it
; into a third.

        MACRO
$label  SignedAverage   $dest,$source1,$source2
$label  ADDS            $dest,$source1,$source2
        MOV             $dest,$dest,ASR #1
        EORVS           $dest,$dest,#&80000000
        MEND

; Flatten the path
; ================

process_flatten
        Push    "LR"
        [       beziertoET > startpathET
        CMP     type,#beziertoET        ;EQ and CS if beziertoET
        TEQNE   type,#startpathET       ;EQ and CC if startpathET
        BNE     process_flatten_pass    ;Otherwise nothing to do
        BCC     process_flatten_init    ;Initialise if startpathET
        |
        CMP     type,#startpathET       ;EQ and CS if startpathET
        TEQNE   type,#beziertoET        ;EQ and CC if beziertoET
        BNE     process_flatten_pass    ;Otherwise nothing to do
        BCS     process_flatten_init    ;Initialise if startpathET
        ]
        BL      process_flatten_bezier
        Pull    "PC"

process_flatten_init
        LDR     R14,flatness
        MOVS    R14,R14,LSL #2                  ;Modify flatness
        MOVEQ   R14,#2:SHL:(coord_shift+2)      ;Apply default
        STR     R14,flatlimit
process_flatten_pass
        CallNextRoutine
        Pull    "PC"

process_flatten_bezier
        Push    "LR"
process_flatten_again

; We've got a Bezier curve. We want to decide whether to bisect it. First,
; to avoid overflow problems, we bisect any Bezier whose bounding box is
; more than &2A000000 in size. Otherwise, we calculate flatnesses:
;   flatness1 = | 3*cont1 - 2*lastpoint - newpoint |
;   flatness2 = | 3*cont2 - lastpoint - 2*newpoint |
; Compare these with the flatness limit. If they are both under it,
; approximate the Bezier with a straight line. If either is above it,
; bisect and try again with each half.
;   Note that we use the Chicago metric here - much quicker and not much
; less efficient than normal metric.

        MOV     R8,oldX
        MOV     R14,oldX
        CMP     R8,cont1X
        MOVGT   R8,cont1X
        MOVLT   R14,cont1X
        CMP     R8,cont2X
        MOVGT   R8,cont2X
        CMP     R14,cont2X
        MOVLT   R14,cont2X
        CMP     R8,newX
        MOVGT   R8,newX
        CMP     R14,newX
        MOVLT   R14,newX
        SUB     R14,R14,R8
        CMP     R14,#&2A000000
        BHI     process_flatten_needsbisecting

        MOV     R8,oldY
        MOV     R14,oldY
        CMP     R8,cont1Y
        MOVGT   R8,cont1Y
        MOVLT   R14,cont1Y
        CMP     R8,cont2Y
        MOVGT   R8,cont2Y
        CMP     R14,cont2Y
        MOVLT   R14,cont2Y
        CMP     R8,newY
        MOVGT   R8,newY
        CMP     R14,newY
        MOVLT   R14,newY
        SUB     R14,R14,R8
        CMP     R14,#&2A000000
        BHI     process_flatten_needsbisecting

        ADD     R8,cont1X,cont1X,LSL #1 ;R8 = type is used as scratch reg.
        SUB     R8,R8,oldX,LSL #1
        SUBS    R8,R8,newX
        RSBMI   R8,R8,#0
        ADD     R14,cont1Y,cont1Y,LSL #1
        SUB     R14,R14,oldY,LSL #1
        SUBS    R14,R14,newY
        ADDPL   R8,R8,R14
        SUBMI   R8,R8,R14
        LDR     R14,flatlimit
        CMP     R8,R14
        BGT     process_flatten_needsbisecting

        ADD     R8,cont2X,cont2X,LSL #1
        SUB     R8,R8,newX,LSL #1
        SUBS    R8,R8,oldX
        RSBMI   R8,R8,#0
        ADD     R14,cont2Y,cont2Y,LSL #1
        SUB     R14,R14,newY,LSL #1
        SUBS    R14,R14,oldY
        ADDPL   R8,R8,R14
        SUBMI   R8,R8,R14
        LDR     R14,flatlimit
        CMP     R8,R14
        BGT     process_flatten_needsbisecting

; This Bezier curve is flat enough to be approximated by a line.

        MOV     type,#linetoET  ;Change type to "line" - other regs OK
        CallNextRoutine
        Pull    "PC"

process_flatten_needsbisecting

; This Bezier curve needs to be bisected and recursively worked on.

        Push    "newX,newY"
        BL      averageone
        Push    "newX,newY"
        BL      averagetwo
        Push    "newX,newY"
        BL      averagethree
        BL      process_flatten_bezier  ;Do first half
        Pull    "cont1X,cont1Y,cont2X,cont2Y,newX,newY"
        BVC     process_flatten_again   ;If first half OK, do second
        Pull    "PC"                    ;Pass first half errors back

averagethree
        SignedAverage   cont1X,oldX,cont1X
        SignedAverage   cont1Y,oldY,cont1Y
averagetwo
        SignedAverage   cont2X,cont1X,cont2X
        SignedAverage   cont2Y,cont1Y,cont2Y
averageone
        SignedAverage   newX,cont2X,newX
        SignedAverage   newY,cont2Y,newY
        MOV             PC,LR

; Split excessively long edges
; ============================

process_longedgeprotect
        Push    "LR"
        TEQ     type,#beziertoET
        CMPNE   type,#closewithgapET-1  ;Now HI <=> an edge element type
        ASSERT  closewithlineET = closewithgapET+1
        ASSERT  beziertoET = closewithlineET+1
        ASSERT  gaptoET = beziertoET+1
        ASSERT  linetoET = gaptoET+1
        BLS     process_longedge_pass
        BL      process_longedge_edge
        Pull    "PC"

process_longedge_edge
        Push    "LR"
process_longedge_again

; We've got an edge. Determine ABS(deltaX), ABS(deltaY). Bisect if either
; exceeds &20000000 (probably rather too conservative, but it doesn't
; really matter).

        SUBS    t1,newX,oldX
        RSBLT   t1,t1,#0
        SUBS    t2,newY,oldY
        RSBLT   t2,t2,#0
        CMP     t1,#&20000000
        CMPLO   t2,#&20000000
        BHS     process_longedge_needsbisecting
process_longedge_pass
        CallNextRoutine
        Pull    "PC"

process_longedge_needsbisecting
;
; This edge needs to be bisected and recursively worked on.
;
        Push    "newX,newY,type"
        SignedAverage   newX,oldX,newX
        SignedAverage   newY,oldY,newY
        CMP     type,#closewithlineET   ;Don't close subpath with 1st half
        ADDLS   type,type,#gaptoET-closewithgapET
        ASSERT  closewithlineET > closewithgapET
        ASSERT  gaptoET > closewithlineET
        ASSERT  linetoET > closewithlineET
        ASSERT  gaptoET-closewithgapET = linetoET-closewithlineET
        BL      process_longedge_edge   ;Do first half
        Pull    "newX,newY,type"
        BVC     process_longedge_again  ;If first half OK, do second
        Pull    "PC"                    ;Pass first half errors back

; Thicken the path, non-zero width
; ================================

; Flags used in joincapstate

jc_subpathexists        EQU     2_1     ;Current subpath exists
jc_subpathstarted       EQU     2_10    ;Current subpath has started
jc_initialvalid         EQU     2_100   ;initialvertex/offset are valid
jc_finalvalid           EQU     2_1000  ;finaloffset is valid

process_thicken

        CLRV
        [       tracethicken
        Push    "R0-R11,LR"
        SWI     OS_WriteS
        DCB     "Thicken",13,10,0
        ALIGN
        MOV     R3,#0
dumploop2
        LDR     R0,[R13,R3]
        ADR     R1,dumpno2
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     " "
dumpno2
        DCB     "00000000",0
        ALIGN
        ADD     R3,R3,#4
        TST     R3,#15
        SWIEQ   OS_NewLine
        CMP     R3,#48
        BLO     dumploop2
        SWI     OS_NewLine
        Pull    "R0-R11,LR"
        ]

        Push    "LR"
        ADD     PC,PC,type,LSL #2
        MOV     PC,#0                   ;Should never happen!
        B       process_thicken_final   ;endpathET - complete caps & pass on
        B       process_thicken_init    ;startpathET - initialise & pass down
        B       process_thicken_capinit ;movetoET - complete caps & restart
        B       process_thicken_capinit ;specialmovetoET - ditto
        B       process_thicken_capoff  ;closewithgapET - complete caps
        B       process_thicken_closel  ;closewithlineET - join, make a
                                        ;  rectangle around the line and a
                                        ;  possible final join
        B       pathnotflat2            ;beziertoET - error
        B       process_thicken_gap     ;gaptoET - generates cap
        BL      process_thickensegment  ;linetoET - join, make a rectangle
        Pull    "PC"                    ;  around the line and return

process_thicken_gap
        BL      process_thickengap
        Pull    "PC"

process_thicken_capinit
        BL      process_unclosedjoin
        LDR     R14,joincapstate
        ORR     R14,R14,#jc_subpathexists
        STR     R14,joincapstate
        MOV     oldX,newX
        MOV     oldY,newY
        Pull    "PC"

process_thicken_capoff
        BL      process_unclosedjoin
        MOV     oldX,newX
        MOV     oldY,newY
        Pull    "PC"

process_thicken_closel
        BL      process_thickensegment
        BLVC    process_closedjoin
        Pull    "PC"

process_thicken_final
        BL      process_unclosedjoin
        BVC     process_thicken_pass
        Pull    "PC"

process_thicken_init
        LDR     t1,thickness            ;Calculate circle control value
        MOV     t3,#&4600               ;Multiplier is 2*(SQR(2)-1)/3 =
        ORR     t3,t3,#&B1              ;  0.46B14446; 0.46B1 accurate enough
        MOV     t2,t1,ASR #16
        BIC     t1,t1,t2,ASL #16
        MUL     t1,t3,t1
        MOV     t1,t1,LSR #16
        MLA     t1,t3,t2,t1
        STR     t1,circlecontrol
        MOV     t1,#0
        STR     t1,joincapstate
process_thicken_pass
        CallNextRoutine
        Pull    "PC"

; Subroutine to finish an unclosed segment, drawing final caps as
; appropriate. Updates joincapstate.

process_unclosedjoin
        LDR     t3,joincapstate
        SUBS    t4, t4, t4              ; t4:=0, V clear
        STR     t4,joincapstate
        TST     t3,#jc_subpathexists
        Return  EQ
        TST     t3,#jc_subpathstarted
        BEQ     process_drawonlycap
        TST     t3,#jc_initialvalid
        BEQ     process_unclosedjoin_noinit
        Push    "oldX,oldY,LR"
        ADR     t4,initialvertex
        LDMIA   t4,{oldX,oldY,t1,t2}
        ASSERT  oldX < oldY
        ASSERT  oldY < t1
        ASSERT  t1 < t2
        ASSERT  initialoffset = initialvertex + 8
        BL      process_drawtrailingcap
        Pull    "oldY,LR,PC",VS
        Pull    "oldX,oldY,LR"
process_unclosedjoin_noinit
        TST     t3,#jc_finalvalid
        BNE     process_drawleadingcap
        NoErrorReturn

; Subroutine to finish a closed segment, drawing final joins or caps as
; appropriate. Updates joincapstate.

process_closedjoin
        LDR     t3,joincapstate
        SUBS    t4, t4, t4              ; t4:=0, V clear
        STR     t4,joincapstate
        TST     t3,#jc_subpathexists
        Return  EQ
        TST     t3,#jc_subpathstarted
        BEQ     process_drawonlycap
        TST     t3,#jc_initialvalid
        BEQ     process_closedjoin_noinit
        ADR     t4,initialoffset
        LDMIA   t4,{t1,t2}
        TST     t3,#jc_finalvalid
        BNE     process_drawjoin
        B       process_drawtrailingcap
process_closedjoin_noinit
        TST     t3,#jc_finalvalid
        BNE     process_drawleadingcap
        NoErrorReturn

; Subroutine to possibly draw a cap at oldX,oldY, then move to newX,newY.
; Updates join and cap variables and oldX, oldY; corrupts t1, t2, t3, t4,
; newX, newY, type.

process_thickengap
        Push    "newX,newY,LR"
        CLRV
        LDR     type,joincapstate
        TST     type,#jc_subpathstarted ;If subpath not started, start it
        ORREQ   type,type,#jc_subpathstarted
        TSTNE   type,#jc_finalvalid     ;Produce leading cap if necessary
        BLNE    process_drawleadingcap
        BIC     type,type,#jc_finalvalid
        STR     type,joincapstate
        Pull    "oldX,oldY,PC",VC       ;Return with surreptitious move of
                                        ;  original newX/Y into oldX/Y
        Pull    "oldY,LR,PC"
        ASSERT  oldX = R0

; Subroutine to possibly draw a cap or join at oldX,oldY, then draw a
; rectangle of width thickness around the line from oldX,oldY to newX,newY.
; Updates join and cap variables and oldX, oldY; corrupts t1, t2, t3, t4,
; newX, newY, type.
;   The rectangle is in fact drawn as a hexagon, with vertices at the
; original endpoints of the edge and at the corners of the rectangle. This
; is necessary in order to ensure that any joins match up perfectly with
; the rectangle, no matter what subsequent transformations are done to the
; vertices.

process_thickensegment
        Push    "LR"
        SUB     t1,oldY,newY            ;First calculate a normal vector to
        SUB     t2,newX,oldX            ;  the line
        ORRS    t3,t1,t2                ;Return immediately if segment has
        Pull    "PC",EQ                 ;  zero length
        LDR     t3,thickness            ;Change to a normal vector of length
        BL      measurealongvector      ;  equal to the line's thickness
        MOV     t1,t1,ASR #1            ;Produce half thickness
        MOV     t2,t2,ASR #1
        LDR     type,joincapstate       ;What is the current join/cap state?
        TST     type,#jc_subpathstarted ;If at start of subpath, store where
        ADREQ   R14,initialvertex       ;  the subpath's start and offset are
        STMEQIA R14,{oldX,oldY,t1,t2}
        ASSERT  oldX < oldY
        ASSERT  oldY < t1
        ASSERT  t1 < t2
        ASSERT  initialoffset = initialvertex + 8
        ORREQ   type,type,#jc_subpathstarted+jc_initialvalid
        BEQ     process_thickensegment_first
        TST     type,#jc_finalvalid     ;Join or cap required?
        BNE     process_thickensegment_join
        BL      process_drawtrailingcap
        B       process_thickensegment_common
process_thickensegment_join
        BL      process_drawjoin
process_thickensegment_common
        Pull    "PC",VS
process_thickensegment_first
        ADR     R14,finaloffset
        STMIA   R14,{t1,t2}
        ORR     type,type,#jc_finalvalid
        STR     type,joincapstate
        SUB     t3,newX,t1              ;Offset line to right by half
        SUB     t4,newY,t2              ;  thickness
        SUB     t1,oldX,t1
        SUB     t2,oldY,t2
        Push    "oldX,oldY,t1,t2,t3,t4,newX,newY"
        RSB     t1,t1,oldX,ASL #1       ;Now offset line by precisely the
        RSB     t2,t2,oldY,ASL #1       ;  same amount to the left
        RSB     oldX,t3,newX,ASL #1
        RSB     oldY,t4,newY,ASL #1
        Push    "oldX,oldY,t1,t2"
        MOV     type,#movetoET          ;Move to first point
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#40
        Pull    "PC",VS
        MOV     type,#linetoET          ;Line to second point
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#32
        Pull    "PC",VS
        MOV     type,#linetoET          ;Line to third point
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#24
        Pull    "PC",VS
        MOV     type,#linetoET          ;Line to fourth point
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#16
        Pull    "PC",VS
        MOV     type,#linetoET          ;Line to fifth point
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#8
        Pull    "PC",VS
        MOV     type,#linetoET          ;Line to sixth point
        CallNextRoutine
        Pull    "newX,newY"
        Pull    "PC",VS
        MOV     type,#closewithlineET   ;And close the rectangle, putting
        CallNextRoutine                 ;  original newX,newY into oldX,oldY
        Pull    "PC"

; Subroutine to draw a leading cap at oldX,oldY, with orientation defined by
; finaloffset. Preserves oldX,oldY,t1,t2,t3,t4,newX,newY,type unless an error
; occurs. Assumes circlecontrol has already been set up.

process_drawleadingcap
        Push    "oldX,oldY,t1,t2,t3,t4,newX,newY,type,LR"
        ADR     R14,finaloffset
        LDMIA   R14,{t1,t2}
        RSB     t1,t1,#0                ;Reverse orientation to trailing cap
        RSB     t2,t2,#0
        MOV     t4,#1                   ;Signal leading cap
        B       process_drawcap

; Subroutine to draw a trailing cap at oldX,oldY, with orientation defined
; by t1,t2. Preserves oldX,oldY,t1,t2,t3,t4,newX,newY,type unless an error
; occurs. Assumes circlecontrol has already been set up.

process_drawtrailingcap
        Push    "oldX,oldY,t1,t2,t3,t4,newX,newY,type,LR"
        MOV     t4,#2                   ;Signal trailing cap
process_drawcap
        ADR     R14,currentoffset
        STMIA   R14,{t1,t2}
        LDR     type,joinsandcaps
        LDRB    t3,[type,t4]            ;Pick up correct cap type
        ADD     t4,t4,#1                ;Generate 1/4 offset to parameter
        CMP     t3,#4                   ;Cap type in range? If so, branch
        ADDLO   PC,PC,t3,LSL #2         ;  via table to correct routine
        B       badcaporjoin
        B       process_nocap
        B       process_drawcircle
        B       process_drawsquarecap
process_drawtrianglecap
        LDR     type,[type,t4,LSL #2]   ;Pick up parameter
        ADD     newX,oldX,t1            ;Triangular caps in fact have SIX
        ADD     newY,oldY,t2            ;  vertices, to ensure a perfect
        Push    "oldX,oldY,newX,newY"   ;  join with the "rectangle" around
        SUB     newX,oldX,t1            ;  the line.
        SUB     newY,oldY,t2
        Push    "newX,newY"
        MOV     newY,type,LSR #16       ;Isolate length multiplier
        BIC     type,type,newY,LSL #16  ;  and width multiplier
        SSmultD newY,t2,t3,t4           ;2^8*(l.mult.)*(offsetY) into t3,t4
        MOV     t3,t3,LSR #7            ;Take out 2^7 factor and put in t3
        ORR     t3,t3,t4,LSL #25
        SSmultD newY,t1,t4,newX         ;2^8*(l.mult.)*(offsetX) into t4,newX
        MOV     t4,t4,LSR #7            ;Take out 2^7 factor and put in t4
        ORR     t4,t4,newX,LSL #25
        SSmultD type,t1,newX,newY       ;2^8*(w.mult.)*(offsetX) into newX/Y
        MOV     t1,newX,LSR #7          ;Take out 2^7 factor and put in t1
        ORR     t1,t1,newY,LSL #25
        SSmultD type,t2,newX,newY       ;2^8*(w.mult.)*(offsetY) into newX/Y
        MOV     t2,newX,LSR #7          ;Take out 2^7 factor and put in t2
        ORR     t2,t2,newY,LSL #25
        SUB     newX,oldX,t1            ;Generate left side vertex
        SUB     newY,oldY,t2
        SUB     t3,oldX,t3              ;Generate apex of triangle
        ADD     t4,oldY,t4
        ADD     t1,oldX,t1              ;Generate right side vertex
        ADD     t2,oldY,t2
        Push    "t1,t2,t3,t4,newX,newY"
        ADD     type,R13,#40
        LDMIA   type,{newX,newY}
        MOV     type,#movetoET
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#40
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        MOV     type,#linetoET
process_lastfivepoints
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#32
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        MOV     type,#linetoET
process_lastfourpoints
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#24
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        MOV     type,#linetoET
process_lastthreepoints
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#16
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        MOV     type,#linetoET
        CallNextRoutine
        Pull    "newX,newY"
        ADDVS   R13,R13,#8
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        MOV     type,#linetoET
        CallNextRoutine
        Pull    "newX,newY"
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
process_closecaporjoin
        MOV     type,#closewithlineET
        CallNextRoutine
        Pull    "oldX,oldY,t1,t2,t3,t4,newX,newY,type,PC",VC
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC"
        ASSERT  oldX = R0

process_drawsquarecap
        MOV     newX,oldX               ;Note square caps in fact have FIVE
        MOV     newY,oldY               ;  vertices, again to ensure perfect
        SUB     t3,oldX,t1              ;  matching
        SUB     t4,oldY,t2
        Push    "t3,t4,newX,newY"
        ADD     oldX,oldX,t1
        ADD     oldY,oldY,t2
        SUB     t3,t3,t2
        ADD     t4,t4,t1
        ADD     t1,t3,t1,ASL #1
        ADD     t2,t4,t2,ASL #1
        Push    "oldX,oldY,t1,t2,t3,t4"
        MOV     type,#movetoET
        B       process_lastfivepoints

; Subroutine to draw a unoriented cap at oldX,oldY. Will not produce anything
; unless both cap styles are the same and are unoriented. Preserves oldX,
; oldY,t1,t2,t3,t4,newX,newY,type unless an error occurs. Assumes
; circlecontrol has already been set up.

process_drawonlycap
        Push    "oldX,oldY,t1,t2,t3,t4,newX,newY,type,LR"
        LDR     type,joinsandcaps
        LDRB    t3,[type,#1]
        CMP     t3,#1
        LDREQB  t3,[type,#2]
        CMPEQ   t3,#1
        BEQ     process_drawcircle
process_nocap
        CLRV
        Pull    "oldX,oldY,t1,t2,t3,t4,newX,newY,type,PC"

; Subroutine to draw a join at oldX,oldY, with orientations defined by t1,t2
; and finaloffset. Preserves oldX,oldY,t1,t2,t3,t4,newX,newY,type unless an
; error occurs. Assumes circlecontrol has already been set up.

process_drawjoin
        Push    "oldX,oldY,t1,t2,t3,t4,newX,newY,type,LR"
        ADR     R14,finaloffset
        LDMIA   R14,{t3,t4}
        MOV     newX,oldX
        MOV     newY,oldY
        LDR     type,joinsandcaps
        LDRB    type,[type]
        CMP     type,#3
        ADDLO   PC,PC,type,LSL #2
        B       badcaporjoin
        B       process_mitredjoin
        B       process_drawcircle
        BL      process_findopenside
process_beveljoin
        ADD     t1,newX,t1
        ADD     t2,newY,t2
        ADD     t3,newX,t3
        ADD     t4,newY,t4
        Push    "t1,t2,t3,t4,newX,newY"
        ASSERT  t1 < t2
        ASSERT  t2 < t3
        ASSERT  t3 < t4
        ASSERT  t4 < newX
        ASSERT  newX < newY
        MOV     type,#movetoET
        B       process_lastthreepoints

; For the moment, mitred joins are done by a somewhat crude technique: we
; know that the intersection point should lie on the line (relative to the
; common endpoint) from (0,0) to the midpoint M of P = (t1,t2) and Q =
; (t3,t4); furthermore, by similar triangles it is readily apparent that the
; intersection point is in fact (ABS(Q)/ABS(M))^2 times M. As the mitre ratio
; is equal to ABS(Q)/ABS(M), this also gives us an easy way of checking
; against the mitre limit.
;   The crudity in this approach lies in the fact that the errors it produces
; are comparatively large: the error in calculating the intersection point is
; equal to the mitre ratio squared times the error in calculating M. This
; could cause problems for mitre ratios much in excess of 10. More accurate
; techniques still based on working from P and Q can reduce the error to
; O(mitre limit), but these involve rather more complicated calculations and
; do not seem worthwhile at present. (Yet more accurate techniques, based on
; knowing the true direction vectors of the lines, could make the errors
; negligible, but these involve yet more calculation and also disrupt the
; structure of this code.)
;   Doing these calculations requires double precision arithmetic in almost
; all cases. For simplicity, we use it in all cases!
;   One other note: the floating point version of this algorithm should be
; able to make use of the technique used here without any significant
; accuracy problems.

process_mitredjoin
        BL      process_findopenside
        LDR     type,joinsandcaps
        LDR     type,[type,#4]          ;Get 2^16 * mitre limit into type
        CMP     type,#&10000            ;Check in range - error if not
      [ Module_Version >103
        BLT     badcaporjoin
      |
        BLO     badcaporjoin
      ]
        Push    "t1,t2,t3,t4,newX,newY"
        ADD     t1,t1,t3                ;t1+t3 into t1
        ADD     t2,t2,t4                ;t2+t4 into t2
        SSmultD t1,t1,oldX,oldY         ;(t1+t3)^2 into oldX,oldY
        SSmultD t2,t2,newX,newY         ;(t2+t4)^2 into newX,newY
        ADDS    newX,newX,oldX          ;(t1+t3)^2 + (t2+t4)^2 into newX,newY
        ADC     newY,newY,oldY
        LDR     t4,thickness
        SSmultD t4,t4,oldX,oldY         ;thickness^2 into oldX,oldY
        MOV     t4,oldY,LSL #16         ;Put 2^16 * thickness^2 into t3,t4
        ORR     t4,t4,oldX,LSR #16
        MOV     t3,oldX,LSL #16
        BL      arith_DSdivD
        DCB     t3,type,t3,0            ;thickness^2 / mitre limit into t3,t4
        MOV     t4,t4,LSL #16           ;Repeat the division
        ORR     t4,t4,t3,LSR #16
        MOV     t3,t3,LSL #16
        BL      arith_DSdivD
        DCB     t3,type,t3,0            ;thickness^2/(mitre limit)^2 in t3,t4
        SUBS    R14,t3,newX             ;Compare with sum of squares
        SBC     R14,t4,newY
        Pull    "t1,t2,t3,t4,newX,newY",HS      ;Use HS to ensure newX,newY
        BHS     process_beveljoin               ;  not zero
        BL      arith_DSmultD
        DCB     oldX,t2,t3,0            ;thickness^2 * (t2+t4) into t3,t4
        BL      arith_DSmultD
        DCB     oldX,t1,t1,0            ;thickness^2 * (t1+t3) into t1,t2
        BL      arith_DDdivS
        DCB     t1,newX,t1,0            ;Twice mitre point X into t1
        BL      arith_DDdivS
        DCB     t3,newX,t2,0            ;Twice mitre point Y into t2
        MOV     t1,t1,ASR #1            ;Take out final factors of two
        MOV     t2,t2,ASR #1
        Pull    "oldX,oldY,t3,t4,newX,newY"
        ADD     oldX,newX,oldX
        ADD     oldY,newY,oldY
        ADD     t1,newX,t1
        ADD     t2,newY,t2
        ADD     t3,newX,t3
        ADD     t4,newY,t4
        Push    "oldX,oldY,t1,t2,t3,t4,newX,newY"
        MOV     type,#movetoET
        B       process_lastfourpoints

process_drawcircle
        LDR     t1,thickness            ;Move to (oldX+thickness/2, oldY)
        ADD     newX,oldX,t1,ASR #1
        MOV     newY,oldY
        MOV     type,#movetoET
        CallNextRoutine
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        LDR     t1,thickness            ;Draw first quadrant
        SUB     newX,oldX,t1,ASR #1
        ADD     newY,oldY,t1,ASR #1
        LDR     t1,circlecontrol
        MOV     t4,newY
        ADD     t3,newX,t1
        ADD     t2,oldY,t1
        MOV     t1,oldX
        MOV     type,#beziertoET
        CallNextRoutine
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        LDR     t1,thickness            ;Draw second quadrant
        SUB     newX,oldX,t1,ASR #1
        SUB     newY,oldY,t1,ASR #1
        LDR     t1,circlecontrol
        ADD     t4,newY,t1
        MOV     t3,newX
        MOV     t2,oldY
        SUB     t1,oldX,t1
        MOV     type,#beziertoET
        CallNextRoutine
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        LDR     t1,thickness            ;Draw third quadrant
        ADD     newX,oldX,t1,ASR #1
        SUB     newY,oldY,t1,ASR #1
        LDR     t1,circlecontrol
        MOV     t4,newY
        SUB     t3,newX,t1
        SUB     t2,oldY,t1
        MOV     t1,oldX
        MOV     type,#beziertoET
        CallNextRoutine
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        LDR     t1,thickness            ;Draw fourth quadrant
        ADD     newX,oldX,t1,ASR #1
        ADD     newY,oldY,t1,ASR #1
        LDR     t1,circlecontrol
        SUB     t4,newY,t1
        MOV     t3,newX
        MOV     t2,oldY
        ADD     t1,oldX,t1
        MOV     type,#beziertoET
        CallNextRoutine
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC",VS
        MOV     newX,oldX
        MOV     newY,oldY
        B       process_closecaporjoin

; Subroutine to swap (t1,t2) with (t3,t4) and negate both of them if (t3,t4)
; to clockwise of (t1,t2). Preserves all other registers.

process_findopenside
        Push    "type,LR"
        ADD     R14,t1,#&B400             ;If absolute values of all operands
        CMP     R14,#2*&B400              ;  are less than or equal to &B400,
        ADDLS   R14,t2,#&B400             ;  single precision arithmetic is
        CMPLS   R14,#2*&B400              ;  sufficient. Otherwise, branch to
        ADDLS   R14,t3,#&B400             ;  double precision code
        CMPLS   R14,#2*&B400
        ADDLS   R14,t4,#&B400
        CMPLS   R14,#2*&B400
        BHI     process_findopenside_dp
        MUL     type,t2,t3
        MUL     R14,t1,t4
        CMP     R14,type
process_findopenside_common
        Pull    "type,PC",GE
        MOV     R14,t1
        RSB     t1,t3,#0
        RSB     t3,R14,#0
        MOV     R14,t2
        RSB     t2,t4,#0
        RSB     t4,R14,#0
        Pull    "type,PC"
process_findopenside_dp
        Push    "t1,t2,t3,t4"
        SSmultD t3,t2,t1,t2                     ;t2*t3 into (t1,t2)
        LDR     t3,[R13,#0]                     ;Original t1 into t3
        SSmultD t3,t4,t3,t4                     ;t4*original t1 into (t3,t4)
        SUBS    t1,t3,t1
        SBCS    t2,t4,t2
        Pull    "t1,t2,t3,t4"
        B       process_findopenside_common

badcaporjoin
        ADR     R0,ErrorBlock_BadCapsOrJoins
        BL      CopyError
        Pull    "oldY,t1,t2,t3,t4,newX,newY,type,LR,PC"

        MakeInternatErrorBlock  BadCapsOrJoins,,M09

; Subroutine to measure a given distance along a vector
;
; Entry:  t1 contains the vector's X co-ordinate.
;         t2 contains the vector's Y co-ordinate.
;         t3 contains the desired length - its absolute value is used.
;
; Exit:   If vector is (0,0), t1 and t2 contain zero whatever the requested
;           length was. Otherwise t1 and t2 contain modified X and Y
;           co-ordinates.
;         t3, t4 corrupt.
;         All other registers preserved.

measurealongvector
        CLRV
        TEQ     t2,#0           ;Is vector horizontal?
        BEQ     measurealong_horiz
        TEQ     t1,#0           ;Is vector vertical?
        BEQ     measurealong_vert
        TEQ     t3,#0           ;If length zero wanted, solution is easy
        MOVEQ   t1,#0
        MOVEQ   t2,#0
        Return  EQ
        Push    "type,LR"
        RSBMIS  t3,t3,#0        ;Watch out for &80000000
        MOVMI   t3,#&7FFFFFFF   ;If &80000000, replace by &7FFFFFFF to avoid
                                ;  possible problems

; Have disposed of the trivial cases now - i.e. this requires some real work!
;   A useful trick at this stage is to halve the length of the given vector
; until both of its components are less than twice the requested length -
; this does not lose much accuracy and substantially reduces the number of
; cases where overflow is likely to happen.

        MOV     type,#0         ;Change co-ordinates to absolute values,
        TEQ     t1,#0           ;  remembering their signs
        ORRMI   type,type,#1
        RSBMI   t1,t1,#0
        TEQ     t2,#0
        ORRMI   type,type,#2
        RSBMI   t2,t2,#0

measurealong_shrinkloop
        CMP     t1,t3,LSL #1    ;Shrink vector until sufficiently small
        CMPLO   t2,t3,LSL #1
        MOVHS   t1,t1,LSR #1
        MOVHS   t2,t2,LSR #1
        BHS     measurealong_shrinkloop

        BL      measurevector   ;Length of t1,t2 into t4

; Now we have to decide whether overflow is likely to occur.

        CMP     t1,#&10000
        CMPLS   t2,#&10000
        CMPLS   t3,#&10000
        BHI     measurealong_dp

; Single precision is OK - get on with it...

        MUL     R14,t3,t1       ;Multiply existing co-ordinates by required
        MUL     t1,t3,t2        ;  length

        DivRem2 t2,t1,t4,t3     ;Divide results by original length
        DivRem2 t1,R14,t4,t3

measurealong_common
        TST     type,#1         ;Restore signs of co-ordinates
        RSBNE   t1,t1,#0
        TST     type,#2
        RSBNE   t2,t2,#0

        Pull    "type,PC"

; Double precision version of the above.

measurealong_dp
        Push    "oldX,oldY,newX,newY"
        SSmultD t1,t3,oldX,oldY ;t1*t3 into oldX,oldY
        SSmultD t2,t3,newX,newY ;t2*t3 into newX,newY
        BL      arith_DSdivS
        DCB     oldX,t4,t1,0    ;(t1*t3)/length of (t1,t2) into t1
        BL      arith_DSdivS
        DCB     newX,t4,t2,0    ;(t2*t3)/length of (t1,t2) into t2
        Pull    "oldX,oldY,newX,newY"
        B       measurealong_common

measurealong_horiz
        CMP     t1,#0           ;If vector is (0,0), leave it alone
        MOVGT   t1,t3           ;If (t1,0) with t1 positive, we want (t3,0)
        RSBLT   t1,t3,#0        ;If (t1,0) with t1 negative, we want (-t3,0)
        Return

measurealong_vert
        CMP     t2,#0           ;If vector is (0,0), leave it alone
        MOVGT   t2,t3           ;If (0,t2) with t2 positive, we want (0,t3)
        RSBLT   t2,t3,#0        ;If (0,t2) with t2 negative, we want (0,-t3)
        Return

; Subroutine to measure the length of a vector. On entry, t1,t2 hold the
; vector. On exit, t4 holds the length. Double precision arithmetic is used
; where appropriate. All registers apart from t4 and R14 are preserved.

measurevector
        Push    "t2,LR"
        MOVS    t2,t2
        RSBMI   t2,t2,#0
        MOVS    t4,t1
        RSBMI   t4,t4,#0
        CMP     t2,#&B500
        CMPLS   t4,#&B500
        BHI     measurevector_dp

; Single precision is OK - get on with it...

        MUL     R14,t2,t2       ;Add squares of co-ordinates to produce
        MLA     R14,t4,t4,R14   ;  squared length of vector

; Calculate length of current vector by taking square root.
; During this calculation, R14 holds current value, t4 holds result bits,
; t2 holds current bit.

        MOV     t2,#&40000000
        MOV     t4,#0
measurevector_sqrtloop
        ADD     t4,t4,t2
        CMP     R14,t4
        SUBHS   R14,R14,t4
        ADDHS   t4,t4,t2
        SUBLO   t4,t4,t2
        MOV     t4,t4,LSR #1
        MOVS    t2,t2,LSR #2
        BNE     measurevector_sqrtloop
        Pull    "t2,PC"

measurevector_dp
        Push    "oldX,oldY,t1"
        SSmultD t2,t2,oldX,oldY         ;t2^2 into oldX,oldY
        SSmultD t4,t4,t1,t2             ;t4^2 into t1,t2
        ADDS    t1,t1,oldX
        ADC     t2,t2,oldY              ;Sum of squares into t1,t2
        BL      arith_DsqrtS
        DCB     t1,t4,0,0               ;Length into t4
        Pull    "oldX,oldY,t1,t2,PC"
        ASSERT  oldX < oldY
        ASSERT  oldY < t1
        ASSERT  t1 < t2

; Thicken the path, zero width
; ============================

process_zerothicken
        Push    "LR"
        TEQ     R8,#movetoET            ;Simply change all "winding" subpaths
        MOVEQ   R8,#specialmovetoET     ;  to "non-winding" ones, and pass
        CallNextRoutine                 ;  the results down
        Pull    "PC"

; Dash the path
; =============

process_dash

        [       tracedash
        Push    "R0-R11,LR"
        SWI     OS_WriteS
        DCB     "Dash",13,10,0
        ALIGN
        MOV     R3,#0
dumploop3
        LDR     R0,[R13,R3]
        ADR     R1,dumpno3
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     " "
dumpno3
        DCB     "00000000",0
        ALIGN
        ADD     R3,R3,#4
        TST     R3,#15
        SWIEQ   OS_NewLine
        CMP     R3,#48
        BLO     dumploop3
        SWI     OS_NewLine
        Pull    "R0-R11,LR"
        ]

        Push    "LR"
        ADD     PC,PC,type,LSL #2
        MOV     PC,#0                   ;Should never happen!
        B       process_dash_pass       ;endpathET - pass down
        B       process_dash_init       ;startpathET - initialise & pass down
        B       process_dash_start      ;movetoET - restart dash pattern
        B       process_dash_start      ;specialmovetoET - restart dash pat.
        B       process_dash_pass       ;closewithgapET - pass down
        B       process_dash_line       ;closewithlineET - dash the line
        B       pathnotflat2            ;beziertoET - error
        B       process_dash_gap        ;gaptoET - advance dash pattern
process_dash_line                       ;linetoET - dash the line
        Push    "newX,newY,type"
        SUB     t1,newX,oldX
        SUB     t2,newY,oldY
        BL      measurevector
        ADR     R14,dashstate
        LDMIA   R14,{t1,t2,t3}
        ASSERT  dashindex = dashstate+4
        ASSERT  dashdistance = dashstate+8
        CMP     t3,t4                   ;All within current dash?
        BHI     process_dash_linedone   ;Exit loop if so
        EOR     t1,t1,#linetoET:EOR:gaptoET
                                        ;Change state,
        ADD     t2,t2,#1                ;  advance to next dash element,
        LDR     type,dashptr
        LDR     R14,[type,#-4]          ;  wrapping round if necessary,
        CMP     t2,R14
        MOVHS   t2,#0
        LDR     R14,[type,t2,LSL #2]    ;  get next dash element's length,
        ADR     type,dashstate          ;Store changed dash state
        STMIA   type,{t1,t2,R14}
        ASSERT  dashindex = dashstate+4
        ASSERT  dashdistance = dashstate+8
        EOR     type,t1,#linetoET:EOR:gaptoET   ;Recover original state
        SUB     t1,newX,oldX            ;Calculate end of dash or gap,
        SUB     t2,newY,oldY
        BL      measurealongvector
        ADD     newX,t1,oldX
        ADD     newY,t2,oldY
        CallNextRoutine                 ;  pass it down for further work,
        Pull    "newX,newY,type"        ;  recover original line type & end,
        BVC     process_dash_line       ;  and repeat if no error
        Pull    "PC"                    ;Pass errors back to caller
process_dash_linedone
        SUB     t3,t3,t4                ;Reduce distance still to be done
        STMIA   R14,{t1,t2,t3}          ;Save updated dash info
        ASSERT  dashindex = dashstate+4
        ASSERT  dashdistance = dashstate+8
        Pull    "newX,newY,type"
        CMP     type,#closewithlineET
        ASSERT  closewithlineET > closewithgapET
        ASSERT  closewithlineET < gaptoET
        ASSERT  closewithlineET < linetoET
        MOVHI   type,t1                 ;If not closing, do gap or line
        SUBLS   type,t1,#gaptoET-closewithgapET
                                        ;If closing, close with gap or line
        CallNextRoutine
        Pull    "PC"

process_dash_init
        LDR     R14,dashptr             ;Advance dash pattern pointer to
        ADD     R14,R14,#8              ;  a more convenient place
        STR     R14,dashptr
        B       process_dash_pass

process_dash_start
        Push    "type"
        MOV     t1,#linetoET            ;Initial dashstate
        MOV     t2,#0                   ;Initial dashindex
        LDR     type,dashptr
        LDR     t3,[type]               ;Initial dashdistance
        LDR     t4,[type,#-8]           ;Distance to advance pattern
        B       process_advancedash

process_dash_gap
        Push    "type"
        SUB     t1,newX,oldX
        SUB     t2,newY,oldY
        BL      measurevector
        ADR     R14,dashstate
        LDMIA   R14,{t1,t2,t3}
        ASSERT  dashindex = dashstate+4
        ASSERT  dashdistance = dashstate+8
        LDR     type,dashptr
process_advancedash
        SUBS    t3,t3,t4                ;All within current dash?
        BHI     process_advancedone     ;Update distance and continue if so
        RSB     t4,t3,#0                ;Otherwise calculate distance to go,
        EOR     t1,t1,#linetoET:EOR:gaptoET     ;  change state,
        ADD     t2,t2,#1                ;  advance to next dash element,
        LDR     t3,[type,#-4]           ;  wrapping round if necessary,
        CMP     t2,t3
        MOVHS   t2,#0
        LDR     t3,[type,t2,LSL #2]     ;  get next dash element's length,
        B       process_advancedash     ;  and repeat.
process_advancedone
        ADR     R14,dashstate           ;Save updated dash info
        STMIA   R14,{t1,t2,t3}
        ASSERT  dashindex = dashstate+4
        ASSERT  dashdistance = dashstate+8
        Pull    "type"
process_dash_pass
        CallNextRoutine
        Pull    "PC"

        LNK     DrOutput.s
