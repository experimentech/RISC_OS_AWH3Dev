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
;
; This routine was generated by Norcroft RISC OS ARM C vsn 3.51 [Feb 13 1991]
; and then hand-hacked by Daffy to go into User mode for the duration of the
; routine.  The original source code was:-
;
; #include <math.h>
;
; /* Take an integer repesenting -1000 * tan(a).
;  * Return an integer representing int(100 * a) where
;  * a is in degrees.
;  */
;
; int get_angle (int val)
; {
;     double angle = 5729.58 * atan(((double) val) / -1000.0);
;     return (int) angle;
; }
;
; The lines added are flagged with the comment XXX

        AREA |C$$code|, CODE, READONLY

        EXPORT  get_angle
get_angle
        MOV     a3, lr                       ; XXX
        FLTD    f0, a1
        LDFS    f1, =5729.57795              ; 100*180/pi
        DVFD    f0, f0, f1
        ATND    f0, f0
        LDFS    f1, =-1000
        MUFD    f0, f0, f1
        FIXZ    a1, f0
        MOV     pc, a3                       ; XXX

        END
