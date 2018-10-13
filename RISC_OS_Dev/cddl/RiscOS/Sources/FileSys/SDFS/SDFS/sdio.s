;
; CDDL HEADER START
;
; The contents of this file are subject to the terms of the
; Common Development and Distribution License (the "Licence").
; You may not use this file except in compliance with the Licence.
;
; You can obtain a copy of the licence at
; cddl/RiscOS/Sources/FileSys/SDFS/SDFS/LICENCE.
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
        GET     System
        GET     FSNumbers
        GET     NewErrors
        GET     SDIO
        GET     APCS/$APCS

        EXPORT  sdio_op_fg_nodata
        EXPORT  sdio_op_fg_data

        AREA    |Asm$$Code|, CODE, READONLY

        ; Wrapper for SWI SDIO_Op for foreground non-data-transfer operations
sdio_op_fg_nodata ROUT
        FunctionEntry "v1-v2"
        MOV     v2, a4
        MOV     a4, #0
        MOV     v1, #0
        SWI     XSDIO_Op
        MOVVC   r0, #0
        Return  "v1-v2"

        ; Wrapper for SWI SDIO_Op for foreground data-transfer operations
sdio_op_fg_data ROUT
        FunctionEntry "v1-v2"
        ADD     lr, sp, #4*3
        LDMIA   lr, {v1-v2,ip}
        SWI     XSDIO_Op
        MOVVC   r0, #0
        STR     r4, [ip]
        Return  "v1-v2"

        END
