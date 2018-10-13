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

        IF SupportARMK :LAND: NoARMK ; i.e. run-time detection is required
        EXPORT  cpuevent_init
cpuevent_init ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        ADR     a2, cpuevent_send_nop
        ADR     a3, cpuevent_wait_nop
        TST     a1, #CPU_Events
        ADRNE   a2, cpuevent_send_instr
        ADRNE   a3, cpuevent_wait_instr
        Store   a2, a4, send_fn, ip
        Store   a3, a4, wait_fn, ip
        Return  , LinkNotStacked
        ENDIF


        IF :LNOT: SupportARMK
cpuevent_send * cpuevent_send_nop
cpuevent_wait * cpuevent_wait_nop
        ELIF :LNOT: NoARMK
cpuevent_send * cpuevent_send_instr
cpuevent_wait * cpuevent_wait_instr
        ELSE ; SupportARMK :LAND: NoARMK
cpuevent_send ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, send_fn, ip
cpuevent_wait ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, wait_fn, ip
        ENDIF

        IF NoARMK
cpuevent_send_nop
cpuevent_wait_nop
        Return  , LinkNotStacked
        ENDIF

        IF SupportARMK
cpuevent_send_instr
        SEV
        Return  , LinkNotStacked
cpuevent_wait_instr
        WFE
        Return  , LinkNotStacked
        ENDIF


        IF SupportARMK :LAND: NoARMK

        AREA    |Asm$$Data|, DATA

send_fn
        DCD     0
wait_fn
        DCD     0

        ENDIF


        EXPORT  cpuevent_send
        EXPORT  cpuevent_wait


        END
