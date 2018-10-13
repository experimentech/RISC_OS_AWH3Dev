;
; Copyright (c) 2012, Ben Avison
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;     * Redistributions of source code must retain the above copyright
;       notice, this list of conditions and the following disclaimer.
;     * Redistributions in binary form must reproduce the above copyright
;       notice, this list of conditions and the following disclaimer in the
;       documentation and/or other materials provided with the distribution.
;     * Neither the name of the copyright holder nor the names of their
;       contributors may be used to endorse or promote products derived from
;       this software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;

        EXPORT  synclib_init

        EXTERN  atomic_init
        EXTERN  barrier_init
        EXTERN  cpuevent_init
        EXTERN  spin_init
        EXTERN  spinrw_init

        GET     ListOpts
        GET     Macros
        GET     System
        GET     CPU/Arch
        GET     APCS/$APCS
        GET     hdr/init

        AREA    |Asm$$Code|, CODE, READONLY

; LDREX/STREX are available in arch v6 or later.
; LDREXB/STREXB are available in arch v6K or later.
; CP15DMB and CP15DSB may be available in any v6 CPU - need to test at runtime.
;   They are deprecated in favour of the new instructions in ARMv7.
; DMB and DSB instructions are available in arch v7 or later.
; SEV and WFE are available in arch v6K or later, but also act as NOPs on v6T2.
;
; ID_ISAR3[15:12] for LDREX(B)/STREX(B)
; ID_ISAR3[27:24] for SEV/WFE
; ID_MMFR2[23:20] for CP15 barrier operations
; ID_ISAR4[19:16] for barrier instructions (DMB/DSB/ISB)
; ID_ISAR4[20:23] for LDREXB/STREXB

synclib_init ROUT
        FunctionEntry "v1"
        MOV     v1, #0
        ; Read Main ID register
        MRC     p15, 0, r0, c0, c0, 0
        ANDS    r1, r0, #(1:SHL:19):OR:(&F:SHL:12)
        TEQNE   r1, #7:SHL:12
        ; EQ => ARM7 or earler CPU, none of which have any of the fancy new instructions
        BEQ     %F90
        ANDS    r1, r0, #&F:SHL:16
        CMP     r1, #7:SHL:16
        ; EQ => ARMv6, LO => < ARMv6, HI => use CPUID scheme
        ORREQ   v1, v1, #CPU_Exclusive
        BLS     %F90
        ; Read ID_ISAR3 register to determine if LDREX/STREX/SEV/WFE are available
        MRC     p15, 0, r0, c0, c2, 3
        TST     r0, #&F :SHL: 12
        ORRNE   v1, v1, #CPU_Exclusive
        TST     r0, #&E :SHL: 12 ; LDREXD implies LDREXB
        ORRNE   v1, v1, #CPU_ExclusiveB
        TST     r0, #&F :SHL: 24
        ORRNE   v1, v1, #CPU_Events
        ; Read ID_MMFR2 to determine if CP15 barrier operations are available
        MRC     p15, 0, r0, c0, c1, 6
        AND     r0, r0, #&F :SHL: 20
        CMP     r0, #&1 :SHL: 20
        ORRHS   v1, v1, #CPU_CP15DSB
        ORRHI   v1, v1, #CPU_CP15DMB
        ; Read ID_ISAR4 register to determine if LDREXB or barrier instructions are available
        MRC     p15, 0, r0, c0, c2, 4
        TST     r0, #&F :SHL: 16
        ORRNE   v1, v1, #CPU_Barriers
        TST     r0, #&F :SHL: 20
        ORRNE   v1, v1, #CPU_ExclusiveB
90
      [ (SupportARMv6 :LAND: NoARMv6) :LOR: (SupportARMK :LAND: NoARMK)
        MOV     a1, v1
        BL      atomic_init
      ]
      [ SupportARMv6 :LAND: NoARMv6
        MOV     a1, v1
        BL      spin_init
        MOV     a1, v1
        BL      spinrw_init
      ]
      [ SupportARMv6 :LAND: NoARMv7
        MOV     a1, v1
        BL      barrier_init
      ]
      [ SupportARMK :LAND: NoARMK
        MOV     a1, v1
        BL      cpuevent_init
      ]
        Return  "v1"

        END
