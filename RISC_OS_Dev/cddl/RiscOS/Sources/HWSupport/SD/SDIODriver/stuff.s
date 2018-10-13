;
; CDDL HEADER START
;
; The contents of this file are subject to the terms of the
; Common Development and Distribution License (the "Licence").
; You may not use this file except in compliance with the Licence.
;
; You can obtain a copy of the licence at
; cddl/RiscOS/Sources/HWSupport/SD/SDIODriver/LICENCE.
; See the Licence for the specific language governing permissions
; and limitations under the Licence.
;
; When distributing Covered Code, include this CDDL HEADER in each
; file and include the Licence file. If applicable, add the
; following below this CDDL HEADER, with the fields enclosed by
; brackets "[]" replaced with your own identifying information:
; Portions Copyright [yyyy] [name of copyright owner]
;
; CDDL HEADER END
;
; Copyright 2012 Ben Avison.  All rights reserved.
; Use is subject to license terms.
;

        GET     ListOpts
        GET     Macros
        GET     APCS/$APCS

        EXPORT  stuff_read
        EXPORT  stuff_write

        AREA    |Asm$$Code|, CODE, READONLY

; a1 -> RAM
; a2 -> data port
; a3 = number of bytes to read
stuff_read ROUT
        FunctionEntry "v1-v6"
        TST     a3, #31
        BLNE    %F50
01      LDR     a4, [a2]
        LDR     v1, [a2]
        LDR     v2, [a2]
        LDR     v3, [a2]
        LDR     v4, [a2]
        LDR     v5, [a2]
        LDR     v6, [a2]
        LDR     lr, [a2]
        STMIA   a1!, {a4, v1-v6, lr}
        SUBS    a3, a3, #32
        BNE     %B01
        Return  "v1-v6"

        ; Do initial words until a multiple of 8 remain
50      LDR     a4, [a2]
        STR     a4, [a1], #4
        SUBS    a3, a3, #4
        Return  "v1-v6",, EQ ; all done
        TST     a3, #31
        BNE     %B50
        MOV     pc, lr


; a1 -> data port
; a2 -> RAM
; a3 = number of bytes to write
stuff_write ROUT
        FunctionEntry "v1-v6"
        TST     a3, #31
        BLNE    %F50
01      LDMIA   a2!, {a4, v1-v6, lr}
        STR     a4, [a1]
        STR     v1, [a1]
        STR     v2, [a1]
        STR     v3, [a1]
        STR     v4, [a1]
        STR     v5, [a1]
        STR     v6, [a1]
        STR     lr, [a1]
        SUBS    a3, a3, #32
        BNE     %B01
        Return  "v1-v6"

        ; Do initial words until a multiple of 8 remain
50      LDR     a4, [a2], #4
        STR     a4, [a1]
        SUBS    a3, a3, #4
        Return  "v1-v6",, EQ ; all done
        TST     a3, #31
        BNE     %B50
        MOV     pc, lr


        END
