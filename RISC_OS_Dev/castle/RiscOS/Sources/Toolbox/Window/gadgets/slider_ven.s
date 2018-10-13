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
; Title:   s.slider_ven
; Purpose: slider veneers
; Author:  NK
; History: 11-Apr-94: NK : Created
;

r0      RN      0
r1      RN      1
r2      RN      2
r3      RN      3

r4      RN      4
r5      RN      5
r6      RN      6
r7      RN      7
r8      RN      8
r9      RN      9

r10     RN     10
r11     RN     11
r12     RN     12
r13     RN     13

sl      RN     10
fp      RN     11
ip      RN     12
sp      RN     13
lr      RN     14
pc      RN     15
      
XWimp_SendMessage * &600e7

        ^ 0,ip
button  #       4
window  #       4
icon    #       4
sent    #       4


        EXPORT  |slider_draw|
        EXPORT  |_slider_draw|
        EXPORT  |_slider_move|
        EXPORT  |_slider_remove|
        EXPORT  |get_sl|

        AREA    |C$$Code|, CODE, READONLY

slider_draw
|_slider_move|
        STMDB   sp!,{r0-r3,lr}
        LDR     r0,[ip,#12]                     ; has last one been dealt with?
        TEQ     r0,#0
        BNE     end
; construct a mouse event!
        SUB     sp,sp,#20
        STR     r2,[sp]                         ; maxx
        STR     r1,[sp,#4]                      ; miny
        ADD     r1,sp,#8
        LDMIA   ip,{r0,r2,r3}
        STMIA   r1,{r0,r2,r3}
        MOV     r0,#6                           ; mouse click
        LDR     r2,[ip,#4]
        SUB     r1,r1,#8
        SWI     XWimp_SendMessage
        ADD     sp,sp,#20
        MOV     r0,#1
        STR     r0,[ip,#12]
end
        LDMIA   sp!,{r0-r3,pc} 

get_sl                     
        MOV     R0,R10

|_slider_draw|
|_slider_remove| 
        MOV     pc,lr

        END

