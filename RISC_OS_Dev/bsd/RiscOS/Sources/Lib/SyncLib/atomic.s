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

        GET     ListOpts
        GET     Macros
        GET     System
        GET     CPU/Arch
        GET     APCS/$APCS
        GET     hdr/init
        GET     hdr/vars

Strex_Succeeded *       0
Strex_Failed    *       1

        AREA    |Asm$$Code|, CODE, READONLY

        IF (SupportARMv6 :LAND: NoARMv6) :LOR: (SupportARMK :LAND: NoARMK) ; i.e. run-time detection is required
        EXPORT  atomic_init
atomic_init ROUT
      [ zM
        StaticBaseFromSL a4
      ]
      [ SupportARMv6 :LAND: NoARMv6
        ADR     a2, atomic_update_uniproc
        ADR     a3, atomic_process_uniproc
        TST     a1, #CPU_Exclusive
        ADRNE   a2, atomic_update_smp
        ADRNE   a3, atomic_process_smp
        Store   a2, a4, update_fn, ip
        Store   a3, a4, process_fn, ip
      ]
      [ SupportARMK :LAND: NoARMK
        ADR     a2, atomic_update_byte_uniproc
        TST     a1, #CPU_ExclusiveB
        ADRNE   a2, atomic_update_byte_smp
        Store   a2, a4, update_byte_fn, ip
      ]
        Return  , LinkNotStacked
        ENDIF


        IF :LNOT: SupportARMv6
atomic_update * atomic_update_uniproc
atomic_process * atomic_process_uniproc
        ELIF :LNOT: NoARMv6
atomic_update * atomic_update_smp
atomic_process * atomic_process_smp
        ELSE
atomic_update ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, update_fn, ip
atomic_process ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, process_fn, ip
        ENDIF

        IF :LNOT: SupportARMK
atomic_update_byte * atomic_update_byte_uniproc
        ELIF :LNOT: NoARMv6
atomic_update_byte * atomic_update_byte_smp
        ELSE
atomic_update_byte ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, update_byte_fn, ip
        ENDIF


        IF NoARMv6

atomic_update_uniproc ROUT
        ; Let's not worry about ARM2 support
        SWP     a1, a1, [a2]
        Return  , LinkNotStacked

atomic_process_uniproc ROUT
        FunctionEntry "v1-v3"
        MOV     ip, a1
        MOV     v1, a3
        MRS     v2, CPSR
        ORR     a4, v2, #I32_bit
        MSR     CPSR_c, a4 ; IRQs now disabled
        LDR     a1, [a3]
        MOV     v3, a1
        MOV     lr, pc
        MOV     pc, ip
        STR     a1, [v1]
        MSR     CPSR_c, v2
        MOV     a1, v3
        Return  "v1-v3"

        ENDIF

        IF NoARMK

atomic_update_byte_uniproc ROUT
        ; Let's not worry about ARM2 support
        SWPB    a1, a1, [a2]
        Return  , LinkNotStacked

        ENDIF


        IF SupportARMv6

atomic_update_smp ROUT
        MOV     a3, a1
01      LDREX   a1, [a2]
        STREX   a4, a3, [a2]
        TEQ     a4, #Strex_Failed
        BEQ     %B01 ; another exclusive access happened between LDREX and STREX
        Return  , LinkNotStacked

atomic_process_smp ROUT
        FunctionEntry "v1-v4"
        MOV     v3, a3
        MOV     v2, a2
        MOV     v1, a1
        ; The process function may affect the state of the exclusive monitor,
        ; so we must perform the LDREX-STREX in one go afterwards (manually
        ; checking [v3] for any changes that happened during the function call)
01      LDR     a1, [v3]
        MOV     a2, v2
        MOV     v4, a1
        BLX     v1 ; any CPU that has LDREX will have BLX too
        LDREX   a2, [v3]
        TEQ     a2, v4
        STREXEQ ip, a1, [v3]
        TEQEQ   ip, #Strex_Succeeded
        BNE     %B01 ; another exclusive access happened between LDR and STREX
        MOV     a1, v4
        Return  "v1-v4"

        ENDIF

        IF SupportARMK

atomic_update_byte_smp ROUT
        MOV     a3, a1
01      LDREXB  a1, [a2]
        STREXB  a4, a3, [a2]
        TEQ     a4, #Strex_Failed
        BEQ     %B01 ; another exclusive access happened between LDREXB and STREXB
        Return  , LinkNotStacked

        ENDIF


        IF (SupportARMv6 :LAND: NoARMv6) :LOR: (SupportARMK :LAND: NoARMK)

        AREA    |Asm$$Data|, DATA

      [ SupportARMv6 :LAND: NoARMv6
update_fn
        DCD     0
process_fn
        DCD     0
      ]
      [ SupportARMK :LAND: NoARMK
update_byte_fn
        DCD     0
      ]

        ENDIF


        EXPORT  atomic_update
        EXPORT  atomic_update_byte
        EXPORT  atomic_process


        END
