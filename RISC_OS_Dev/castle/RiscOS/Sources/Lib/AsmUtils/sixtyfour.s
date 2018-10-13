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
; sixtyfour.s
;
; Author: SBrodie
;

        GET   Hdr:ListOpts
        GET   Hdr:Macros
        GET   Hdr:System
        GET   Hdr:Machine.<Machine>
        GET   Hdr:APCS.<APCS>

; Long multiplier ----------------------------------------
; Taken from Acorn Assembler manual.
; extern u_int64_t *ui64_multiply_uu(u_int64_t *, unsigned, unsigned);

        AREA    |AsmUtils$$SixtyFour1$$Code|, CODE, READONLY, PIC
        EXPORT ui64_multiply_uu
ui64_multiply_uu
        FunctionEntry
        MOVS    lr, a2, LSR #16
        BIC     a2, a2, lr, LSL #16
        MOV     ip, a3, LSR #16
        BIC     a3, a3, ip, LSL #16
        MUL     a4, a2, a3
        MUL     a3, lr, a3
        MUL     a2, ip, a2
        MULNE   lr, ip, lr
        ADDS    a2, a2, a3
        ADDCS   lr, lr, #&10000
        ADDS    a4, a4, a2, LSL #16
        ADC     lr, lr, a2, LSR #16
        STMIA   a1, {a4, lr}
        Return

        AREA    |AsmUtils$$SixtyFour2$$Code|, CODE, READONLY, PIC
        EXPORT ui64_multiply_u64u64
; extern u_int64_t *ui64_multiply_u64u64(u_int64_t *res, u_int64_t *a, u_int64_t *b);
res_lo  RN      v1
res_hi  RN      v2
a_lo    RN      v3
a_hi    RN      v4
b_lo    RN      v5
b_hi    RN      ip
zero    RN      a4
tmp     RN      lr

ui64_multiply_u64u64
        FunctionEntry "v1-v5"
        LDMIA   a2, {a_lo, a_hi}
        LDMIA   a3, {b_lo, b_hi}
        MOV     res_lo, #0
        MOV     res_hi, #0
        MOV     zero, #0
10
        MOVS    b_hi, b_hi, LSR #1
        MOVS    b_lo, b_lo, RRX
        BCC     %FT20
        ADDS    res_lo, res_lo, a_lo
        ADC     res_hi, res_hi, a_hi
20
        MOVS    a_lo, a_lo, LSL #1
        ADCS    a_hi, zero, a_hi, LSL #1
        TEQEQ   a_lo, zero
        ORRNES  tmp, b_hi, b_lo
        BNE     %BT10
        STMIA   a1, {res_lo, res_hi}
        Return  "v1-v5"

        AREA    |AsmUtils$$SixtyFour3$$Code|, CODE, READONLY, PIC
; extern u_int64_t *ui64_subtract_u64u64(u_int64_t *, const u_int64_t *, const u_int64_t *);
; extern int64_t *si64_subtract_s64s64(int64_t *, const int64_t *, const int64_t *);
        EXPORT ui64_subtract_u64u64
        EXPORT si64_subtract_s64s64
ui64_subtract_u64u64
si64_subtract_s64s64
        LDMIA   a3, {a4, ip}
        LDMIA   a2, {a2, a3}
        SUBS    a2, a2, a4
        SBC     a3, a3, ip
        STMIA   a1, {a2, a3}
        Return  ,LinkNotStacked

        AREA    |AsmUtils$$SixtyFour4$$Code|, CODE, READONLY, PIC
; extern u_int64_t *ui64_add_u64u64(u_int64_t *, const u_int64_t *, const u_int64_t *);
; extern int64_t *si64_add_s64s64(int64_t *, const int64_t *, const int64_t *);
        EXPORT ui64_add_u64u64
        EXPORT si64_add_s64s64
ui64_add_u64u64
si64_add_s64s64
        LDMIA   a3, {a4, ip}
        LDMIA   a2, {a2, a3}
        ADDS    a2, a2, a4
        ADC     a3, a3, ip
        STMIA   a1, {a2, a3}
        Return  ,LinkNotStacked

        AREA    |AsmUtils$$SixtyFour5$$Code|, CODE, READONLY, PIC
; extern u_int64_t *ui64_add(u_int64_t *, unsigned long);
; extern int64_t *si64_add(int64_t *, unsigned long);
        EXPORT  ui64_add
        EXPORT  si64_add
ui64_add
si64_add
        LDMIA   a1, {a3, a4}
        ADDS    a3, a3, a2
        ADC     a4, a4, #0
        STMIA   a1, {a3, a4}
        Return  ,LinkNotStacked

        AREA    |AsmUtils$$SixtyFour6a$$Code|, CODE, READONLY, PIC
; extern u_int64_t *ui64_create2(u_int64_t *, unsigned long, unsigned long);
; extern u_int64_t *ui64_create(u_int64_t *, unsigned long);
        EXPORT  ui64_create
        EXPORT ui64_create2
ui64_create
        MOV     a3, #0
ui64_create2
        STMIA   a1, {a2, a3}
        Return  ,LinkNotStacked

        AREA    |AsmUtils$$SixtyFour6b$$Code|, CODE, READONLY, PIC
; extern int64_t *si64_create2(int64_t *, unsigned long, long);
; extern int64_t *si64_create(int64_t *, unsigned long);
        EXPORT  si64_create
        EXPORT  si64_create2
si64_create
        MOV     a3, a2, ASR #31         ; sign extension
si64_create2
        STMIA   a1, {a2, a3}
        Return  ,LinkNotStacked


        AREA    |AsmUtils$$SixtyFour7a$$Code|, CODE, READONLY, PIC
; extern u_int64_t *ui64_shift_right(u_int64_t *, unsigned);
        EXPORT  ui64_shift_right
ui64_shift_right
        LDMIA   a1, {a3, a4}
        RSB     ip, a2, #32
        MOV     a3, a3, LSR a2
        ORR     a3, a3, a4, LSL ip
        MOV     a4, a4, LSR a2
        STMIA   a1, {a3, a4}
        Return  ,LinkNotStacked

        AREA    |AsmUtils$$SixtyFour7b$$Code|, CODE, READONLY, PIC
; extern int64_t *si64_shift_right(int64_t *, unsigned);
        EXPORT  si64_shift_right
si64_shift_right
        LDMIA   a1, {a3, a4}
        RSB     ip, a2, #32
        MOV     a3, a3, LSR a2
        ORR     a3, a3, a4, LSL ip
        MOV     a4, a4, ASR a2
        STMIA   a1, {a3, a4}
        Return  ,LinkNotStacked

        AREA    |AsmUtils$$SixtyFour8$$Code|, CODE, READONLY, PIC
; extern unsigned long ui64_value(const u_int64_t *);
; extern long si64_value(const int64_t *);
; extern unsigned int ui64_value_as_int(const u_int64_t *);
; extern int si64_value_as_int(const int64_t *);
        EXPORT  ui64_value
        EXPORT  si64_value
        EXPORT  ui64_value_as_int
        EXPORT  si64_value_as_int
ui64_value
si64_value
ui64_value_as_int
si64_value_as_int
        LDR     a1, [a1, #0]
        Return  ,LinkNotStacked

        END
