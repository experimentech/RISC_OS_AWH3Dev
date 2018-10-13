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
; Symbols for assembler list options
; Copyright (C) Acorn Computers Ltd., 1988

 [ {FALSE}
OptList * 1:SHL:0
OptNoList * 1:SHL:1
OptPage * 1:SHL:2
OptReset * 1:SHL:3
OptSets * 1:SHL:4
OptNoSets * 1:SHL:5
OptExpand * 1:SHL:6
OptNoExpand * 1:SHL:7
OptMacros * 1:SHL:8
OptNoMacros * 1:SHL:9
OptP1List * 1:SHL:10
OptNoP1List * 1:SHL:11
OptControl * 1:SHL:12
OptNoControl * 1:SHL:13

 GBLA OldOpt

OldOpt SETA {OPT}
 OPT OptNoList+OptNoP1List

 ]

; Standard register names (both cases)

R0      RN      0
R1      RN      1
R2      RN      2
R3      RN      3
R4      RN      4
R5      RN      5
R6      RN      6
R7      RN      7
R8      RN      8
R9      RN      9
R10     RN      10
R11     RN      11
R12     RN      12
R13     RN      13
R14     RN      14
LR      RN      14
LK      RN      LR
R15     RN      15
PC      RN      15
PSR     RN      15

r0      RN      R0
r1      RN      R1
r2      RN      R2
r3      RN      R3
r4      RN      R4
r5      RN      R5
r6      RN      R6
r7      RN      R7
r8      RN      R8
r9      RN      R9
r10     RN      R10
r11     RN      R11
r12     RN      R12
r13     RN      R13
r14     RN      R14
lr      RN      LR
lk      RN      LR
r15     RN      R15
pc      RN      PC
psr     RN      PSR

f0      FN      0
f1      FN      1
f2      FN      2
f3      FN      3
f4      FN      4
f5      FN      5
f6      FN      6
f7      FN      7

F0      FN      f0
F1      FN      f1
F2      FN      f2
F3      FN      f3
F4      FN      f4
F5      FN      f5
F6      FN      f6
F7      FN      f7

; names for registers from the calling standard
a1      RN      R0
a2      RN      R1
a3      RN      R2
a4      RN      R3
v1      RN      R4
v2      RN      R5
v3      RN      R6
v4      RN      R7
v5      RN      R8
v6      RN      R9


A1      RN      a1
A2      RN      a2
A3      RN      a3
A4      RN      a4
V1      RN      v1
V2      RN      v2
V3      RN      v3
V4      RN      v4
V5      RN      v5
V6      RN      v6
fp      RN      R11
ip      RN      R12
sp      RN      R13
sl      RN      R10
FP      RN      fp
IP      RN      ip
SP      RN      sp
SL      RN      sl


; OPT OldOpt

 END