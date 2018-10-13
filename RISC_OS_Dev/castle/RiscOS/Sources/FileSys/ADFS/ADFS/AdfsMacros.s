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
; >AdfsMacros

; Change record
; =============
;
; CDP - Christopher Partington, Cambridge Systems Design
;
;
; 09-Mar-92  14:18  CDP
; Added macro pcadr.
;
; 03-Aug-02  18:15  KJB
; Removed lots of unused macros (most have equivalents in standard header files)
;
;*End of change record*


        MACRO
        SetBorder  $r,$g,$b,$cond
        Push    "R0,R1",$cond
        LDR$cond R0, =VIDC
        MOV$cond R1, #bit30
        ORR$cond R1, R1, #$g * 16 + $r
        ORR$cond R1, R1, #$b * 256
        STR$cond R1, [R0]
        Pull    "R0,R1",$cond
        MEND


        MACRO
$lab    retfiq   $cc
$lab    SUB$cc.S PC, LR, #4
        MEND


;do an operation with 16 bit width const as an 8 bit width if possible
        MACRO
$lab    Try8    $op,$dreg,$sreg,$const
        LCLA    bit
        LCLA    bits8
        WHILE   ($const:MOD:(1:SHL:(bit+2))=0) :LAND: bit<24
bit     SETA    bit+2
        WEND
        ASSERT  $const :SHR: bit < &10000
bits8   SETA    $const :AND: ( &FF :SHL: bit )
$lab    $op     $dreg,$sreg,#bits8
        [ $const<>bits8
bits8   SETA    $const :AND: ( &FF :SHL: ( bit+8 ) )
        $op     $dreg,$dreg,#bits8
        ]
        MEND


;put address of $dest in $reg
;        MACRO
;$lab    addr    $reg,$dest,$cond
;        ASSERT  $reg<>PC
;        ASSERT  ($dest-{PC}-8)<&10000
;$lab    ADD$cond $reg,PC,#($dest-{PC}-8) :AND: &FF
;        ADD$cond $reg,$reg,#($dest-{PC}-4) :AND: &FF00
;        MEND


        GBLA    boff
        MACRO
$lab    baddr   $reg,$dest,$cond
        ASSERT  $reg<>PC
boff    SETA    {PC}+8-($dest)
        ASSERT  boff<&10000
$lab    Try8    SUB$cond,$reg,PC,(boff)
        MEND


;put absolute address of $sboff in $reg
        MACRO
$lab    sbaddr  $reg,$sboff,$cond
$lab    Try8    ADD$cond,$reg,SB,(:INDEX:$sboff)
        MEND


        MACRO
$l      Text    $str
$l      =       "$str",0
        ALIGN
        MEND


        MACRO
$lab    aw      $size           ;allocate word aligned
        ASSERT  {VAR} :MOD: 4=0
$lab    #       $size
        MEND


        MACRO
$lab    a4      $size           ;allocate word aligned register relative
        ASSERT  (:INDEX: {VAR}) :MOD: 4=0
$lab    #       $size
        MEND


        MACRO
$lab    bit     $bitnum
$lab    *       1 :SHL: ($bitnum)
        MEND


        MACRO
        getSB
        LDR     SB, [SB]
        MEND


        MACRO
        Align16 $base
        ASSERT  (.-($base)) :MOD: 4 = 0
        WHILE   (.-($base)) :MOD: 16 <> 0
        MOV     R0, R0
        WEND
        MEND


;FOLLOWING MACROS ONLY FOR DEBUG

        MACRO
        mess    $cond,$s1,$s2,$s3,$s4,$s5
 [ {TRUE}
        B$cond  %F11
        BAL     %F21
11
        Push    "R0,R1,LR"
        BL      Mess1

        [ :LNOT: IrqDebug
        BNE     %FT15           ;skip if IRQ thread
        ]

        SWI     OS_WriteS
 [ "$s1"="NL"
 = CR,LF
 |
 = "$s1"
 ]
 [ "$s2"=""
 |
  [ "$s2"="NL"
  = CR,LF
  |
  = "$s2"
  ]
  [ "$s3"=""
  |
   [ "$s3"="NL"
   = CR,LF
   |
   = "$s3"
   ]
   [ "$s4"=""
   |
    [ "$s4"="NL"
    = CR,LF
    |
    = "$s4"
    ]
    [ "$s5"=""
    |
     [ "$s5"="NL"
     = CR,LF
     |
     = "$s5"
     ]
    ]
   ]
  ]
 ]
        =       0
        ALIGN
        [ SpoolOff
        BL      SpoolOn
        ]
        Pull    "LR"
15
        RestPSR R0
        NOP                     ;delay in case mode change
        Pull    "R0,R1,LR"
21
 ]
        MEND

        MACRO
        wrhex   $reg,$cond
        Push    "R0-R4,LR",$cond
        MOV$cond R2,$reg
        BL$cond PHEX
        Pull    "R0-R4,LR",$cond
        MEND


        MACRO
        Tword   $reg,$cond
        Push    "R0-R3,LR",$cond
        MOV$cond R2,$reg
        BL$cond TubeWrHexWord
        Pull    "R0-R3,LR",$cond
        MEND


        MACRO
        regdump $cond
        mess    $cond,"R0       R1       R2       R3       R4       R5       R6       R7",NL
        wrhex   R0, $cond
        wrhex   R1, $cond
        wrhex   R2, $cond
        wrhex   R3, $cond
        wrhex   R4, $cond
        wrhex   R5, $cond
        wrhex   R6, $cond
        wrhex   R7, $cond
        mess    $cond,NL,"R8       R9       R10      R11      R12      R13      R14      R15",NL
        wrhex   R8, $cond
        wrhex   R9, $cond
        wrhex   R10,$cond
        wrhex   R11,$cond
        wrhex   R12,$cond
        wrhex   R13,$cond
        wrhex   R14,$cond
        wrhex   R15,$cond
        mess    $cond,NL
        MEND


        END
