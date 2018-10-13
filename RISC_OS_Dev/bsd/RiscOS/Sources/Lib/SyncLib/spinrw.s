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
        GET     hdr/barrier
        GET     hdr/cpuevent
        GET     hdr/init
        GET     hdr/vars

; Layout of spinrwlock_t

                ^       0, a1
Mutex           #       4 ; controls access to the spinrwlock structure itself
SavedCPSR       #       4
Counter         #       4 ; see below
Pollword        #       4 ; so we can support UpCall 6

Mutex_Locked    *       0
Mutex_Unlocked  *       1

; The counter word is treated as 2 fields:
; bit 0 set => write lock is held
; bits 1-31 = - number of read locks held (this is so moving to/from 0 locks
;                                          can be detected using the C flag)
; If the lock is not held at all, the word has value 0
Counter_Write   *       1:SHL:0
Counter_Read    *       1:SHL:1

Strex_Succeeded *       0
Strex_Failed    *       1

Bool_False      *       0
Bool_True       *       1

        AREA    |Asm$$Code|, CODE, READONLY

        IF SupportARMv6 :LAND: NoARMv6 ; i.e. run-time detection is required
        EXPORT  spinrw_init
spinrw_init ROUT
        FunctionEntry "v1-v2"
      [ zM
        StaticBaseFromSL lr
      ]
        TST     a1, #CPU_Exclusive
        ADREQ   a1, spinrw_write_try_lock_uniproc
        ADREQ   a2, spinrw_write_lock_uniproc
        ADREQ   a3, spinrw_write_sleep_lock_uniproc
        ADREQ   a4, spinrw_write_unlock_uniproc
        ADREQ   v1, spinrw_read_lock_uniproc
        ADREQ   v2, spinrw_read_unlock_uniproc
        ADRNE   a1, spinrw_write_try_lock_smp
        ADRNE   a2, spinrw_write_lock_smp
        ADRNE   a3, spinrw_write_sleep_lock_smp
        ADRNE   a4, spinrw_write_unlock_smp
        ADRNE   v1, spinrw_read_lock_smp
        ADRNEL  v2, spinrw_read_unlock_smp
        Store   a1, lr, write_try_lock_fn, ip
        Store   a2, lr, write_lock_fn, ip
        Store   a3, lr, write_sleep_lock_fn, ip
        Store   a4, lr, write_unlock_fn, ip
        Store   v1, lr, read_lock_fn, ip
        Store   v2, lr, read_unlock_fn, ip
        Return  "v1-v2"
        ENDIF


        IF :LNOT: SupportARMv6
spinrw_write_try_lock   * spinrw_write_try_lock_uniproc
spinrw_write_lock       * spinrw_write_lock_uniproc
spinrw_write_sleep_lock * spinrw_write_sleep_lock_uniproc
spinrw_write_unlock     * spinrw_write_unlock_uniproc
spinrw_read_lock        * spinrw_read_lock_uniproc
spinrw_read_unlock      * spinrw_read_unlock_uniproc
        ELIF :LNOT: NoARMv6
spinrw_write_try_lock   * spinrw_write_try_lock_smp
spinrw_write_lock       * spinrw_write_lock_smp
spinrw_write_sleep_lock * spinrw_write_sleep_lock_smp
spinrw_write_unlock     * spinrw_write_unlock_smp
spinrw_read_lock        * spinrw_read_lock_smp
spinrw_read_unlock      * spinrw_read_unlock_smp
        ELSE
spinrw_write_try_lock ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, write_try_lock_fn, ip
spinrw_write_lock ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, write_lock_fn, ip
spinrw_write_sleep_lock ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, write_sleep_lock_fn, ip
spinrw_write_unlock ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, write_unlock_fn, ip
spinrw_read_lock ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, read_lock_fn, ip
spinrw_read_unlock ROUT
      [ zM
        StaticBaseFromSL a4
      ]
        Load    pc, a4, read_unlock_fn, ip
        ENDIF


; There is a fair amount of similarity between the uniprocessor and SMP versions
; of these functions. To keep things manageable, build them using repetetive
; assembly. Uniprocessor version is in pass 1, SMP version is in pass 2.

        MACRO
$label  MetaLock  $origpsr, $locked_const, $tmp
$label
     [ "$origpsr" <> ""
        MRS     $origpsr, CPSR
      [ variant = "smp"
        CPSID   i ; IRQs now disabled
      |
        ORR     $tmp, $origpsr, #I32_bit
        MSR     CPSR_c, $tmp ; IRQs now disabled
      ]
     ]
      [ variant = "smp"
        ASSERT  :INDEX: Mutex = 0 :LAND: :BASE: Mutex = a1
01      LDREX   $tmp, [a1]
        TEQ     $tmp, $locked_const
        ; this mutex is never locked for more than a few instructions, so
        ; we won't bother with event signalling here
        STREXNE $tmp, $locked_const, [a1]
        TEQNE   $tmp, #Strex_Failed
        BEQ     %BT01 ; was already locked, or someone pipped us to the post, so try again
        Barrier
      ]
        MEND

        MACRO
$label  MetaUnlock  $restpsr, $unlocked_const
      [ variant = "smp"
        Barrier
        STR     $unlocked_const, Mutex
      ]
      [ "$restpsr" <> ""
        MSR     CPSR_c, $restpsr
      ]
        MEND

        MACRO
$label  Pause
      [ variant = "uniproc"
; Some of these routines enable and disable interrupts in a tight loop.
; For some processors in this category, it is not enough simply to enable and
; then immediately disable interrupts. For example, an Intel application note
; for the SA-110 says:
;      "If an instruction enables interrupts, then this does not take effect for
;       2 cycles after the CPSR is modified. If an instruction disables
;       interrupts, then this takes effect immediately. As such, the processor
;       only acts on interrupts if interrupts have been enabled for at least 2
;       consecutive cycles."
; The routine supplied by RISC OS's OS_PlatformFeatures goes further than this,
; doing 5 NOPs. To err on the side of caution, we do the same here, though for
; the sake of simplicity, we do them inline and for any CPU in this category.
        MOV     r0, r0
        MOV     r0, r0
        MOV     r0, r0
        MOV     r0, r0
        MOV     r0, r0
      |
; Make sure any important pending writes are flushed before we go to sleep (the
; write buffer may not drain while we're asleep). This is significant because
; we only use Pause after a failed lock attempt; we need to make sure the
; MetaUnlock is flushed otherwise the owner of the spinrw may become stuck
; on MetaLock when he tries to release the spinrw. (This behaviour has been
; observed on Cortex-A53)
; For other cases we assume the MetaUnlock will be flushed naturally within a
; reasonable timeframe. However, spending some time doing some experimentation
; and benchmarking would be wise.
; If natural flushing is proven to take too long, it might be wise to move all
; the barrier and CPUEventSend calls to just before the PSR is restored, to
; make sure a pending IRQ doesn't cause them to be subjected to an extra delay.
        BarrierSync
        CPUEventWait
      ]
        MEND

        GBLS    variant
variant SETS    "uniproc"

        WHILE    variant <> "finished"
 [ (variant = "uniproc" :LAND: NoARMv6) :LOR: (variant = "smp" :LAND: SupportARMv6)

spinrw_write_try_lock_$variant ROUT
        MOV     a3, #Mutex_Unlocked
        MOV     a4, #Mutex_Locked
        MetaLock a2, a4, ip
        LDR     ip, Counter
        TEQ     ip, #0
        BNE     %FA50
        ASSERT  Mutex_Unlocked = Counter_Write
        ASSERT  :BASE: SavedCPSR = a1 :LAND: :INDEX: SavedCPSR = 4
        ASSERT  Counter = SavedCPSR + 4 :LAND: Pollword = Counter + 4
        STMIB   a1, {a2-a4}
;        STR     a2, SavedCPSR
;        STR     a3, Counter
;        STR     a4, Pollword
        MetaUnlock , a3
        MOV     a1, #Bool_True
        Return  , LinkNotStacked
50
        MetaUnlock a2, a3
        MOV     a1, #Bool_False
        Return  , LinkNotStacked

spinrw_write_lock_$variant ROUT
        MOV     a3, #Mutex_Unlocked
        MOV     a4, #Mutex_Locked
10      MetaLock a2, a4, ip
        LDR     ip, Counter
        TEQ     ip, #0
        BNE     %FA50
        ASSERT  Mutex_Unlocked = Counter_Write
        ASSERT  :BASE: SavedCPSR = a1 :LAND: :INDEX: SavedCPSR = 4
        ASSERT  Counter = SavedCPSR + 4 :LAND: Pollword = Counter + 4
        STMIB   a1, {a2-a4}
;        STR     a2, SavedCPSR
;        STR     a3, Counter
;        STR     a4, Pollword
        MetaUnlock , a3
        Return  , LinkNotStacked
50
        MetaUnlock a2, a3
        Pause
        B       %BA10

spinrw_write_sleep_lock_$variant ROUT
        FunctionEntry
        MOV     a3, #Mutex_Unlocked
        MOV     a4, #Mutex_Locked
10      MetaLock a2, a4, ip
        LDR     ip, Counter
        TEQ     ip, #0
        BNE     %FA50
        ASSERT  Mutex_Unlocked = Counter_Write
        ASSERT  :BASE: SavedCPSR = a1 :LAND: :INDEX: SavedCPSR = 4
        ASSERT  Counter = SavedCPSR + 4 :LAND: Pollword = Counter + 4
        STMIB   a1, {a2-a4}
;        STR     a2, SavedCPSR
;        STR     a3, Counter
;        STR     a4, Pollword
        MetaUnlock , a3
        Return
50
        MetaUnlock a2, a3
        Push    "r0"
        ADR     r1, Pollword
        MOV     r0, #6
        SWI     XOS_UpCall
        Pull    "r0"
        B       %BA10

spinrw_write_unlock_$variant ROUT
        MOV     a3, #Mutex_Unlocked
        MOV     a4, #Mutex_Locked
        MetaLock , a4, ip
        LDR     ip, SavedCPSR
        ASSERT  Mutex_Locked = 0
        STR     a4, Counter
        STR     a3, Pollword
        MetaUnlock ip, a3
      [ variant = "smp"
        BarrierSync
        CPUEventSend
      ]
        Return  , LinkNotStacked

spinrw_read_lock_$variant ROUT
        MOV     a3, #Mutex_Unlocked
        MOV     a4, #Mutex_Locked
10      MetaLock a2, a4, ip
        LDR     ip, Counter
        TST     ip, #Counter_Write
        BNE     %FA50
        SUBS    ip, ip, #Counter_Read ; borrow / C clear means was unlocked
        STR     ip, Counter
        STRCC   a4, Pollword
        MetaUnlock a2, a3
        Return  , LinkNotStacked
50
        MetaUnlock a2, a3
        Pause
        B       %BA10

spinrw_read_unlock_$variant ROUT
        MOV     a3, #Mutex_Unlocked
        MOV     a4, #Mutex_Locked
        MetaLock a2, a4, ip
        LDR     ip, Counter
        ADDS    ip, ip, #Counter_Read ; C set means is now unlocked
        STR     ip, Counter
        STRCS   a3, Pollword
        MetaUnlock a2, a3 ; preserves flags
      [ variant = "smp"
        BarrierSyncCS ; preserves flags
        CPUEventSendCS
      ]
        Return  , LinkNotStacked

 ]
 [ variant = "uniproc"
variant SETS    "smp"
 |
variant SETS    "finished"
 ]
        WEND


        IF SupportARMv6 :LAND: NoARMv6

        AREA    |Asm$$Data|, DATA

write_try_lock_fn
        DCD     0
write_lock_fn
        DCD     0
write_sleep_lock_fn
        DCD     0
write_unlock_fn
        DCD     0
read_lock_fn
        DCD     0
read_unlock_fn
        DCD     0

        ENDIF


        EXPORT  spinrw_write_try_lock
        EXPORT  spinrw_write_lock
        EXPORT  spinrw_write_sleep_lock
        EXPORT  spinrw_write_unlock
        EXPORT  spinrw_read_lock
        EXPORT  spinrw_read_unlock


        END
