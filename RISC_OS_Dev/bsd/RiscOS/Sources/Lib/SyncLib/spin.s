;
; Copyright (c) 2011, Ben Avison
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
        GET     hdr/barrier
        GET     hdr/cpuevent
        GET     hdr/init
        GET     hdr/vars

; Layout of spinlock_t

                ^       0, a1
Mutex           #       4
SavedCPSR       #       4

Mutex_Locked    *       0
Mutex_Unlocked  *       1

Strex_Succeeded *       0
Strex_Failed    *       1

        AREA    |Asm$$Code|, CODE, READONLY

        IF SupportARMv6 :LAND: NoARMv6 ; i.e. run-time detection is required
        EXPORT  spin_init
spin_init ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        ADR     a2, spin_lock_uniproc
        ADR     a3, spin_unlock_uniproc
        TST     a1, #CPU_Exclusive
        ADRNE   a2, spin_lock_smp
        ADRNE   a3, spin_unlock_smp
        Store   a2, a4, lock_fn, ip
        Store   a3, a4, unlock_fn, ip
        Return  , LinkNotStacked
        ENDIF


        IF :LNOT: SupportARMv6
spin_lock * spin_lock_uniproc
spin_unlock * spin_unlock_uniproc
        ELIF :LNOT: NoARMv6
spin_lock * spin_lock_smp
spin_unlock * spin_unlock_smp
        ELSE
spin_lock ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, lock_fn, ip
spin_unlock ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, unlock_fn, ip
        ENDIF


        IF NoARMv6

spin_lock_uniproc ROUT
        MRS     a2, CPSR
        ORR     a3, a2, #I32_bit
        MSR     CPSR_c, a3 ; IRQs now disabled
        STR     a2, SavedCPSR
        Return  , LinkNotStacked

spin_unlock_uniproc ROUT
        LDR     a2, SavedCPSR
        MSR     CPSR_c, a2
        Return  , LinkNotStacked

        ENDIF


        IF SupportARMv6

spin_lock_smp ROUT
        MRS     a2, CPSR
        CPSID   i ; IRQs now disabled
        MOV     a3, #Mutex_Locked
        ASSERT  :INDEX: Mutex = 0 :LAND: :BASE: Mutex = a1
01      LDREX   a4, [a1]
        TEQ     a4, a3
        CPUEventWaitEQ ; already locked: sleep this CPU, the unlocking CPU will wake us
        STREXNE a4, a3, [a1]
        TEQNE   a4, #Strex_Failed
        BEQ     %B01 ; was already locked, or someone pipped us to the post, so try again
        Barrier ; ensure locking is seen by all CPUs before we start using the SavedCPSR field
        STR     a2, SavedCPSR
        Return  , LinkNotStacked

spin_unlock_smp ROUT
        LDR     a2, SavedCPSR
        MOV     a3, #Mutex_Unlocked
        Barrier ; ensure no other cores see the lock released before we can read SavedCPSR
        STR     a3, Mutex
        BarrierSync ; ensure mutex unlock is visible to other CPUs before we wake them
        CPUEventSend ; wake any CPUs that are sleeping on this lock
        MSR     CPSR_c, a2
        Return  , LinkNotStacked

        ENDIF


        IF SupportARMv6 :LAND: NoARMv6

        AREA    |Asm$$Data|, DATA

lock_fn
        DCD     0
unlock_fn
        DCD     0

        ENDIF


        EXPORT  spin_lock
        EXPORT  spin_unlock


        END
