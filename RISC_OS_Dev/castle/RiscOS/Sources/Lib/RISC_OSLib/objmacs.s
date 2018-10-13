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
;;; h_objmacro.s
;;; Copyright (C) Advanced RISC Machines Ltd., 1991

;;; RCS $Revision: 4.2 $
;;; Checkin $Date: 2011-09-24 14:51:57 $
;;; Revising $Author: jlee $

 [ :LNOT: :DEF: LDM_MAX
        GBLA    LDM_MAX
LDM_MAX SETA    16
 ]

 [ :LNOT: :DEF: make
        GBLS    make
make    SETS    "all"
 ]

 [ :LNOT: :DEF: FPIS
        GBLA    FPIS
FPIS    SETA    2
 ]

        GBLL    FPE2
FPE2    SETL    FPIS=2

        GBLS    VBar
        GBLS    UL
        GBLS    XXModuleName

VBar    SETS    "|"
UL      SETS    "_"

        GET     h_la_obj.s

        MACRO
        Module  $name
XXModuleName SETS UL:CC:"$name":CC:UL
        MEND

        MACRO
$Label  Variable $Size
        LCLS    Temps
        LCLA    Tempa
 [ "$Size"=""
Tempa   SETA    1
 |
Tempa   SETA    $Size
 ]
Temps   SETS    VBar:CC:XXModuleName:CC:"$Label":CC:VBar
        KEEP    $Temps
        ALIGN
O_$Label *      .-StaticData
$Temps  %       &$Tempa*4
        MEND

        MACRO
$Label  ExportedVariable $Size
        LCLS    Temps
        LCLA    Tempa
 [ "$Size"=""
Tempa   SETA    1
 |
Tempa   SETA    $Size
 ]
Temps   SETS    VBar:CC:"$Label":CC:VBar
        EXPORT  $Temps
        ALIGN
O_$Label *      .-StaticData
$Temps  %       &$Tempa*4
        MEND

        MACRO
$Label  ExportedWord $Value
        LCLS    Temps
Temps   SETS    VBar:CC:"$Label":CC:VBar
        EXPORT  $Temps
        ALIGN
O_$Label *      .-StaticData
$Temps   &      $Value
        MEND

        MACRO
$Label  ExportedVariableByte $Size
        LCLS    Temps
        LCLA    Tempa
 [ "$Size"=""
Tempa   SETA    1
 |
Tempa   SETA    $Size
 ]
Temps   SETS    VBar:CC:"$Label":CC:VBar
        EXPORT  $Temps
O_$Label *      .-StaticData
$Temps  %       &$Tempa
        MEND

        MACRO
$Label  VariableByte $Size
        LCLS    Temps
        LCLA    Tempa
 [ "$Size"=""
Tempa   SETA    1
 |
Tempa   SETA    $Size
 ]
Temps   SETS    VBar:CC:XXModuleName:CC:"$Label":CC:VBar
        KEEP    $Temps
O_$Label *      .-StaticData
$Temps  %       &$Tempa
        MEND

        MACRO
$Label  InitByte $Value
$Label  =        $Value
        MEND

        MACRO
$Label  InitWord $Value
$Label  &        $Value
        MEND

        MACRO
$Label  Keep    $Arg
        LCLS    Temps
$Label  $Arg
Temps   SETS    VBar:CC:XXModuleName:CC:"$Label":CC:VBar
        KEEP    $Temps
$Temps
        MEND


        MACRO
        PopFrame  $Regs,$Caret,$CC,$Base
        LCLS    BaseReg
 [ "$Base" = ""
BaseReg SETS    "fp"
 |
BaseReg SETS    "$Base"
 ]
        LCLA    count
        LCLS    s
        LCLS    ch
s       SETS    "$Regs"
count   SETA    1
        WHILE   s<>""
ch        SETS    s:LEFT:1
s         SETS    s:RIGHT:(:LEN:s-1)
          [ ch = ","
count       SETA    count+1
          |
            [ ch = "-"
              ! 1, "Can't handle register list including '-'"
            ]
          ]
        WEND
 [ LDM_MAX < count
        LCLA    r
        LCLS    subs
s       SETS    "$Regs"
subs    SETS    ""
r       SETA    0
        SUB     ip, $BaseReg, #4*&$count
        WHILE   s<>""
ch        SETS    s:LEFT:1
s         SETS    s:RIGHT:(:LEN:s-1)
          [ ch = ","
r           SETA    r+1
            [ r >= LDM_MAX
              LDM$CC.FD ip!,{$subs}
subs          SETS    ""
r             SETA    0
            |
subs          SETS    subs:CC:ch
            ]
          |
            [ ch = "-"
              ! 1, "Push can't handle register list including '-'"
            |
subs          SETS    subs:CC:ch
            ]
          ]
        WEND
        LDM$CC.FD   ip,{$subs}$Caret
 |
   [ (count = 1) :LAND: ("$Caret"="")
        LDR$CC      $Regs,[$BaseReg,#-4]
   |
        LDM$CC.DB   $BaseReg, {$Regs}$Caret
   ]
 ]
        MEND

        MACRO
        Pop     $Regs,$Caret,$CC,$Base
        LCLS    BaseReg
 [ "$Base" = ""
BaseReg SETS    "sp"
 |
BaseReg SETS    "$Base"
 ]
 [ LDM_MAX < 16
        LCLA    r
        LCLS    s
        LCLS    subs
        LCLS    ch
s       SETS    "$Regs"
subs    SETS    ""
r       SETA    0
        WHILE   s<>""
ch        SETS    s:LEFT:1
s         SETS    s:RIGHT:(:LEN:s-1)
          [ ch = ","
r           SETA    r+1
            [ r >= LDM_MAX
              LDM$CC.FD   $BaseReg!,{$subs}
subs          SETS    ""
r             SETA    0
            |
subs          SETS    subs:CC:ch
            ]
          |
            [ ch = "-"
              ! 1, "Can't handle register list including '-'"
            |
subs          SETS    subs:CC:ch
            ]
          ]
        WEND
        LDM$CC.FD   $BaseReg!,{$subs}$Caret
 |
        LCLS   temps
        LCLL   onereg
temps   SETS   "$Regs"
onereg  SETL   "$Caret" = ""
        WHILE  onereg :LAND: :LEN: temps > 0
        [ temps :LEFT: 1 = "," :LOR: temps :LEFT: 1 = "-"
onereg  SETL   {FALSE}
        ]
temps   SETS   temps :RIGHT: (:LEN: temps - 1)
        WEND
        [ onereg
        LDR$CC      $Regs, [$BaseReg], #4
        |
        LDM$CC.FD   $BaseReg!, {$Regs}$Caret
        ]
 ]
        MEND

        MACRO
        Return  $UsesSb, $ReloadList, $Base, $CC
        LCLS    Temps
Temps   SETS    "$ReloadList"
 [ "$UsesSb" <> "" :LAND: make="shared-library"
   [ Temps = ""
Temps   SETS    "sb"
   |
Temps   SETS    Temps:CC:", sb"
   ]
 ]

 [ {CONFIG} = 26
   [ "$Base" = "LinkNotStacked" :LAND: "$ReloadList"=""
          MOV$CC.S pc, lr
   |
     [ Temps <> ""
Temps   SETS    Temps :CC: ","
     ]
     [ "$Base" = "fpbased"
       PopFrame "$Temps.fp,sp,pc",^,$CC
     |
       Pop      "$Temps.pc",^,$CC
     ]
   ]
 |
   [ "$Base" = "LinkNotStacked" :LAND: "$ReloadList"=""
          MOV$CC pc, lr
   |
     [ Temps <> ""
Temps   SETS    Temps :CC: ","
     ]
     [ "$Base" = "fpbased"
       PopFrame "$Temps.fp,sp,pc",,$CC
     |
       Pop      "$Temps.pc",,$CC
     ]
   ]
 ]
        MEND

        MACRO
        PushA   $Regs,$Base
        ; Push registers on an empty ascending stack, with stack pointer $Base
        ; (no default for $Base, won't be sp)
 [ LDM_MAX < 16
        LCLA    r
        LCLS    s
        LCLS    subs
        LCLS    ch
s       SETS    "$Regs"
subs    SETS    ""
r       SETA    0
        WHILE   s<>""
ch        SETS    s:LEFT:1
s         SETS    s:RIGHT:(:LEN:s-1)
          [ ch = ","
r           SETA    r+1
            [ r >= LDM_MAX
              STMIA   $Base!,{$subs}
subs          SETS    ""
r             SETA    0
            |
subs          SETS    subs:CC:ch
            ]
          |
            [ ch = "-"
              ! 1, "Can't handle register list including '-'"
            |
subs          SETS    subs:CC:ch
            ]
          ]
        WEND
        STMIA   $Base!,{$subs}
 |
        LCLS   temps
        LCLL   onereg
temps   SETS   "$Regs"
onereg  SETL   {TRUE}
        WHILE  onereg :LAND: :LEN: temps > 0
        [ temps :LEFT: 1 = "," :LOR: temps :LEFT: 1 = "-"
onereg  SETL   {FALSE}
        ]
temps   SETS   temps :RIGHT: (:LEN: temps - 1)
        WEND
        [ onereg
        STR     $Regs, [$Base], #4
        |
        STMIA   $Base!, {$Regs}
        ]
 ]
        MEND

        MACRO
        PopA    $Regs,$Base
        ; Pop registers from an empty ascending stack, with stack pointer $Base
        ; (no default for $Base, won't be sp)
 [ LDM_MAX < 16
        LCLA    n
        LCLA    r
        LCLS    s
        LCLS    subs
        LCLS    ch
s       SETS    "$Regs"
n       SETA    :LEN:s
subs    SETS    ""
r       SETA    0
        WHILE   n<>0
n         SETA    n-1
ch        SETS    s:RIGHT:1
s         SETS    s:LEFT:n
          [ ch = ","
r           SETA    r+1
            [ r >= LDM_MAX
              LDMDB   $Base!,{$subs}
subs          SETS    ""
r             SETA    0
            |
subs          SETS    ch:CC:subs
            ]
          |
            [ ch = "-"
              ! 1, "Can't handle register list including '-'"
            |
subs          SETS    ch:CC:subs
            ]
          ]
        WEND
        LDMDB   $Base!,{$subs}
 |
        LCLS   temps
        LCLL   onereg
temps   SETS   "$Regs"
onereg  SETL   {TRUE}
        WHILE  onereg :LAND: :LEN: temps > 0
        [ temps :LEFT: 1 = "," :LOR: temps :LEFT: 1 = "-"
onereg  SETL   {FALSE}
        ]
temps   SETS   temps :RIGHT: (:LEN: temps - 1)
        WEND
        [ onereg
        LDR     $Regs, [$Base,#-4]!
        |
        LDMDB   $Base!, {$Regs}
        ]
 ]
        MEND

        MACRO
        Push    $Regs, $Base
        LCLS    BaseReg
 [ "$Base" = ""
BaseReg SETS    "sp"
 |
BaseReg SETS    "$Base"
 ]
 [ LDM_MAX < 16
        LCLA    n
        LCLA    r
        LCLS    s
        LCLS    subs
        LCLS    ch
s       SETS    "$Regs"
n       SETA    :LEN:s
subs    SETS    ""
r       SETA    0
        WHILE   n<>0
n         SETA    n-1
ch        SETS    s:RIGHT:1
s         SETS    s:LEFT:n
          [ ch = ","
r           SETA    r+1
            [ r >= LDM_MAX
              STMFD   $BaseReg!,{$subs}
subs          SETS    ""
r             SETA    0
            |
subs          SETS    ch:CC:subs
            ]
          |
            [ ch = "-"
              ! 1, "Can't handle register list including '-'"
            |
subs          SETS    ch:CC:subs
            ]
          ]
        WEND
        STMFD   $BaseReg!,{$subs}
 |
        LCLS   temps
        LCLL   onereg
temps   SETS   "$Regs"
onereg  SETL   {TRUE}
        WHILE  onereg :LAND: :LEN: temps > 0
        [ temps :LEFT: 1 = "," :LOR: temps :LEFT: 1 = "-"
onereg  SETL   {FALSE}
        ]
temps   SETS   temps :RIGHT: (:LEN: temps - 1)
        WEND
        [ onereg
        STR     $Regs, [$BaseReg,#-4]!
        |
        STMFD   $BaseReg!, {$Regs}
        ]
 ]
        MEND

        MACRO
        FunctionEntry $UsesSb, $SaveList, $MakeFrame
        LCLS    Temps
        LCLS    TempsC
Temps   SETS    "$SaveList"
TempsC  SETS    ""
 [ Temps <> ""
TempsC SETS Temps :CC: ","
 ]

 [ "$UsesSb" <> "" :LAND: make="shared-library"
   [ "$MakeFrame" = ""
        MOV     ip, sb  ; intra-link-unit entry
        Push    "$TempsC.sb,lr"
        MOV     sb, ip
   |
        MOV     ip, sb  ; intra-link-unit entry
        Push    "sp,lr,pc"
        ADD     lr, sp, #8
        Push    "$TempsC.sb,fp"
        MOV     fp, lr
        MOV     sb, ip
   ]
 |
   [ "$MakeFrame" = ""
        Push    "$TempsC.lr"
   |
        MOV     ip, sp
        Push    "$TempsC.fp,ip,lr,pc"
        SUB     fp, ip, #4
   ]
 ]
        MEND

        END
