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

        AREA    |Asm$$Code|, CODE, READONLY

        IF SupportARMv6 :LAND: NoARMv7 ; i.e. run-time detection is required
        EXPORT  barrier_init
barrier_init ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        ADR     a2, barrier_nop
        ADR     a3, barrier_sync_nop
        TST     a1, #CPU_CP15DMB
        ADRNE   a2, barrier_cp15
        TST     a1, #CPU_CP15DSB
        ADRNE   a3, barrier_sync_cp15
        TST     a1, #CPU_Barriers
        ADRNE   a2, barrier_instr
        ADRNE   a3, barrier_sync_instr
        Store   a2, a4, barrier_fn, ip
        Store   a3, a4, sync_fn, ip
        Return  , LinkNotStacked
        ENDIF


        IF :LNOT: SupportARMv6
barrier * barrier_nop
barrier_sync * barrier_sync_nop
        ELIF :LNOT: NoARMv7
barrier * barrier_instr
barrier_sync * barrier_sync_instr
        ELSE ; SupportARMv6 :LAND: NoARMv7
barrier ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, barrier_fn, ip
barrier_sync ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, sync_fn, ip
        ENDIF

        IF NoARMv7
barrier_nop
barrier_sync_nop
        Return  , LinkNotStacked
        ENDIF

        IF SupportARMv6 :LAND: NoARMv7
barrier_cp15
        MCR     p15, 0, r0, c7, c10, 5
        Return  , LinkNotStacked
barrier_sync_cp15
        MCR     p15, 0, r0, c7, c10, 4
        Return  , LinkNotStacked
        ENDIF

        IF SupportARMv6
barrier_instr
        DMB
        Return  , LinkNotStacked
barrier_sync_instr
        DSB
        Return  , LinkNotStacked
        ENDIF


        IF SupportARMv6 :LAND: NoARMv7

        AREA    |Asm$$Data|, DATA

barrier_fn
        DCD     0
sync_fn
        DCD     0

        ENDIF


        EXPORT  barrier
        EXPORT  barrier_sync


        END
